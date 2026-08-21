import { connection, socket } from '@kit.NetworkKit';
import { BusinessError } from '@kit.BasicServicesKit';
import {
  CameraStorageItem,
  CameraStorageSnapshot,
  CameraStorageVolume,
  isObjectAssociation,
  parseObjectInfo,
  parseStorageIds,
  parseStorageInfo
} from '../storage/CameraStorage';

class PtpIpPacket {
  readonly type: number;
  readonly data: Uint8Array;

  constructor(type: number, data: Uint8Array) {
    this.type = type;
    this.data = data;
  }
}

/**
 * PtpIpChannel.receive 在限定时间内未收到完整 PTP/IP 包时抛出；
 * 事件 reader 据此区分“空转超时”（继续等）与真正的通道关闭/错误。
 */
class PtpIpReceiveTimeoutError extends Error {
}

class PtpIpResponseError extends Error {
  readonly response: number;

  constructor(response: number) {
    super(
      `相机拒绝了 PTP/IP 操作（0x${response.toString(16).padStart(4, '0')}）`
    );
    this.response = response;
  }
}

class PtpIpChannel {
  readonly tcp: socket.TCPSocket = socket.constructTCPSocketInstance();
  private buffer: Uint8Array = new Uint8Array(0);
  private packets: Array<PtpIpPacket> = [];
  private closed: boolean = false;
  private failureHandler?: (error: Error) => void;

  constructor() {
    this.tcp.on('message', (message: socket.SocketMessageInfo): void => {
      this.append(new Uint8Array(message.message));
    });
    this.tcp.on('close', (): void => {
      this.fail(new Error('PTP/IP TCP 通道已被远端关闭'));
    });
    this.tcp.on('error', (error: BusinessError): void => {
      this.fail(new Error(`PTP/IP TCP 通道错误：${error.message}`));
    });
  }

  setFailureHandler(handler: (error: Error) => void): void {
    this.failureHandler = handler;
  }

  async connect(
    host: string,
    port: number,
    netHandle?: connection.NetHandle
  ): Promise<void> {
    this.closed = false;
    if (netHandle !== undefined) {
      // 相机 Wi-Fi 常无互联网：蜂窝为默认网络时把 socket 显式绑定到相机
      // 网络（bindSocket 是 NetHandle 的方法，入参为 TCPSocket），避免
      // PTP/IP 流量走错出口。
      await netHandle.bindSocket(this.tcp);
    }
    await this.tcp.connect({
      address: {
        address: host,
        family: 1,
        port: port
      },
      timeout: 8000
    });
    await this.tcp.setExtraOptions({
      TCPNoDelay: true,
      socketTimeout: 12000
    });
  }

  async send(type: number, payload: Uint8Array): Promise<void> {
    if (this.closed) {
      throw new Error('PTP/IP 通道已关闭');
    }
    const packet: Uint8Array = new Uint8Array(payload.length + 8);
    writeU32(packet, 0, packet.length);
    writeU32(packet, 4, type);
    packet.set(payload, 8);
    await this.tcp.send({ data: packet.buffer });
  }

  async receive(timeoutMilliseconds: number = 12000): Promise<PtpIpPacket> {
    const attempts: number = Math.max(1, Math.ceil(timeoutMilliseconds / 10));
    for (let count: number = 0; count < attempts; count++) {
      if (this.packets.length > 0) {
        return this.packets.shift() as PtpIpPacket;
      }
      if (this.closed) {
        throw new Error('PTP/IP 通道已关闭');
      }
      await delay(10);
    }
    throw new PtpIpReceiveTimeoutError('相机未在限定时间内返回 PTP/IP 响应');
  }

  async close(): Promise<void> {
    this.closed = true;
    this.failureHandler = undefined;
    this.tcp.off('message');
    this.tcp.off('close');
    this.tcp.off('error');
    try {
      await this.tcp.close();
    } catch (error) {
    }
    this.buffer = new Uint8Array(0);
    this.packets = [];
  }

  private fail(error: Error): void {
    if (this.closed) {
      return;
    }
    this.closed = true;
    const handler: ((error: Error) => void) | undefined = this.failureHandler;
    if (handler !== undefined) {
      handler(error);
    }
  }

  private append(bytes: Uint8Array): void {
    const combined: Uint8Array = new Uint8Array(
      this.buffer.length + bytes.length
    );
    combined.set(this.buffer, 0);
    combined.set(bytes, this.buffer.length);
    this.buffer = combined;
    while (this.buffer.length >= 8) {
      const length: number = readU32(this.buffer, 0);
      if (length < 8 || length > 64 * 1024 * 1024) {
        this.buffer = new Uint8Array(0);
        return;
      }
      if (this.buffer.length < length) {
        return;
      }
      const data: Uint8Array = this.buffer.slice(0, length);
      this.packets.push(new PtpIpPacket(readU32(data, 4), data));
      this.buffer = this.buffer.slice(length);
    }
  }
}

/**
 * ArkTS 的 async 函数会在 await 处让出执行权；共享 command TCP 因此需要显式
 * 串行 gate，且锁必须覆盖请求、完整数据相位与最终响应。
 */
class PtpIpCommandGate {
  private tail: Promise<void> = Promise.resolve();
  private releaseCurrent: () => void = (): void => {};

  async acquire(): Promise<void> {
    let release: () => void = (): void => {};
    const previous: Promise<void> = this.tail;
    this.tail = new Promise<void>((resolve: () => void): void => {
      release = resolve;
    });
    await previous;
    this.releaseCurrent = release;
  }

  release(): void {
    const release: () => void = this.releaseCurrent;
    this.releaseCurrent = (): void => {};
    release();
  }
}

export enum CameraVendor {
  UNKNOWN = 0,
  NIKON = 1,
  CANON = 2,
  SONY = 3
}

export class PtpIpCamera {
  // ── E4 1.5.9：PTP/IP 取景 / 录像 / 参数（镜像 Android/iOS/Windows，
  // 字节级口径见 docs/PTPIP_PROTOCOL.md；全部 TBC-awaiting-hardware）──
  private static readonly NIKON_START_LIVE_VIEW: number = 0x9201;
  private static readonly NIKON_END_LIVE_VIEW: number = 0x9202;
  private static readonly NIKON_GET_LIVE_VIEW_IMAGE: number = 0x9203;
  private static readonly NIKON_START_MOVIE_RECORDING: number = 0x920a;
  private static readonly NIKON_END_MOVIE_RECORDING: number = 0x920b;
  private static readonly GET_DEVICE_PROP_DESC: number = 0x1014;
  private static readonly GET_DEVICE_PROP_VALUE: number = 0x1015;
  private static readonly SET_DEVICE_PROP_VALUE: number = 0x1016;
  private static readonly CANON_EOS_SET_PROP_VALUE_EX: number = 0x9110;
  private static readonly CANON_EOS_GET_VIEW_FINDER_DATA: number = 0x9153;
  private static readonly CANON_EVF_RECORD_STATUS: number = 0xd1b8;
  private static readonly CANON_EVF_MODE: number = 0xd1b1;
  private static readonly CANON_EVF_OUTPUT_DEVICE: number = 0xd1b0;
  private static readonly PROP_ISO: number = 0x500f;
  private static readonly PROP_F_NUMBER: number = 0x5007;
  private static readonly PROP_EXPOSURE_TIME: number = 0x500d;
  private static readonly RESPONSE_OK: number = 0x2001;
  private static readonly RESPONSE_SESSION_NOT_OPEN: number = 0x2003;
  private static readonly RESPONSE_INVALID_TRANSACTION_ID: number = 0x2004;
  private static readonly RESPONSE_SESSION_ALREADY_OPEN: number = 0x201e;
  private static readonly RESPONSE_OPERATION_NOT_SUPPORTED: number = 0x2005;
  private static readonly RESPONSE_DEVICE_PROP_NOT_SUPPORTED: number = 0x200a;
  private static readonly RESPONSE_DEVICE_BUSY: number = 0x2019;

  private command?: PtpIpChannel;
  private event?: PtpIpChannel;
  private pendingCommand?: PtpIpChannel;
  private pendingEvent?: PtpIpChannel;
  private readonly commandGate: PtpIpCommandGate = new PtpIpCommandGate();
  private readonly eventWriterGate: PtpIpCommandGate = new PtpIpCommandGate();
  private connectionGeneration: number = 0;
  private eventGeneration: number = 0;
  private probeResponseSequence: number = 0;
  private probeInProgress: boolean = false;
  private commandChannelFailure?: Error;
  // 本次会话 socket 绑定到的相机 Wi-Fi NetHandle（未绑定时为 undefined）。
  private boundNetHandle?: connection.NetHandle;
  private transaction: number = 1;
  private nameValue: string = 'PTP/IP Camera';
  private vendorValue: CameraVendor = CameraVendor.UNKNOWN;
  private liveViewValue: boolean = false;
  private movieRecordingValue: boolean = false;

  /** 本次会话实际绑定的相机 Wi-Fi NetHandle（未绑定时为 undefined）。 */
  get netHandle(): connection.NetHandle | undefined {
    return this.boundNetHandle;
  }

  get isConnected(): boolean {
    return this.command !== undefined && this.commandChannelFailure === undefined;
  }

  /**
   * 在 UI 发布“已连接”前确认命令通道未被初始化事务毒化，并以一次真实的
   * Probe（type 13/14）往返作为健康屏障；探测后再次校验命令通道，防止
   * 探测期间通道被关闭却仍发布为已连接。前置字段检查保持同步快速失败。
   */
  async assertHealthy(): Promise<void> {
    if (this.command === undefined) {
      throw new Error('请先连接 Wi‑Fi 相机');
    }
    // ArkTS 不允许 throw 类型为 Error | undefined 的字段；先取本地常量再抛。
    const failure: Error | undefined = this.commandChannelFailure;
    if (failure !== undefined) {
      throw failure;
    }
    // 心跳可能已在飞（连接后的参数刷新路径也会调用本方法）：probe 拒绝
    // 并发探测，而在飞的探测本身就是存活裁决，直接复用而不重复发 Probe。
    if (!this.probeInProgress) {
      await this.probe(3000);
    }
    if (this.command === undefined) {
      throw new Error('请先连接 Wi‑Fi 相机');
    }
    const postProbeFailure: Error | undefined = this.commandChannelFailure;
    if (postProbeFailure !== undefined) {
      throw postProbeFailure;
    }
  }

  /** 只有明确不影响会话健康的能力拒绝才允许 UI 降级继续。 */
  static isCapabilityFallbackError(error: Error): boolean {
    if (!(error instanceof PtpIpResponseError)) {
      return false;
    }
    return error.response === PtpIpCamera.RESPONSE_OPERATION_NOT_SUPPORTED ||
      error.response === PtpIpCamera.RESPONSE_DEVICE_PROP_NOT_SUPPORTED ||
      error.response === PtpIpCamera.RESPONSE_DEVICE_BUSY;
  }

  private static isDeviceBusyError(error: Error): boolean {
    return error instanceof PtpIpResponseError &&
      error.response === PtpIpCamera.RESPONSE_DEVICE_BUSY;
  }

  get name(): string {
    return this.nameValue;
  }

  get vendor(): CameraVendor {
    return this.vendorValue;
  }

  get isLiveView(): boolean {
    return this.liveViewValue;
  }

  get isMovieRecording(): boolean {
    return this.movieRecordingValue;
  }

  async connect(
    host: string,
    port: number,
    netHandle?: connection.NetHandle
  ): Promise<string> {
    const generation: number = ++this.connectionGeneration;
    await this.closePublishedConnection();
    this.ensureConnectionGeneration(generation);
    if (host.trim().length === 0 || port < 1 || port > 65535) {
      throw new Error('Wi‑Fi 相机地址或端口无效');
    }
    const command: PtpIpChannel = new PtpIpChannel();
    command.setFailureHandler((error: Error): void => {
      this.markCommandChannelFailed(command, generation, error);
    });
    this.pendingCommand = command;
    let event: PtpIpChannel | undefined;
    try {
      await command.connect(host.trim(), port, netHandle);
      this.ensureConnectionGeneration(generation);
      const initialization: Array<number> = [];
      for (let index: number = 0; index < 16; index++) {
        initialization.push(Math.floor(Math.random() * 256));
      }
      appendUtf16(initialization, 'ZENCHE HarmonyOS');
      appendU32(initialization, 0x00010000);
      await command.send(1, new Uint8Array(initialization));
      this.ensureConnectionGeneration(generation);
      const acknowledgment: PtpIpPacket = await command.receive();
      this.ensureConnectionGeneration(generation);
      if (acknowledgment.type !== 2 || acknowledgment.data.length < 28) {
        throw new Error('相机返回了无效的 PTP/IP 握手数据');
      }
      const connectionNumber: number = readU32(acknowledgment.data, 8);
      const announcedName: string = readUtf16(acknowledgment.data, 28);
      this.nameValue = announcedName.length > 0
        ? announcedName
        : 'PTP/IP Camera';

      event = new PtpIpChannel();
      this.pendingEvent = event;
      await event.connect(host.trim(), port, netHandle);
      this.ensureConnectionGeneration(generation);
      const eventInitialization: Uint8Array = new Uint8Array(4);
      writeU32(eventInitialization, 0, connectionNumber);
      await event.send(3, eventInitialization);
      this.ensureConnectionGeneration(generation);
      const eventAcknowledgment: PtpIpPacket = await event.receive();
      this.ensureConnectionGeneration(generation);
      if (eventAcknowledgment.type !== 4) {
        throw new Error('相机未确认 PTP/IP 事件通道');
      }
      if (this.pendingCommand !== command || this.pendingEvent !== event) {
        throw new Error('PTP/IP 连接已取消或被新会话取代');
      }
      this.pendingCommand = undefined;
      this.pendingEvent = undefined;
      this.command = command;
      this.event = event;
      this.boundNetHandle = netHandle;
      this.startEventReader(event);
      const response: number = await this.sendCommand(0x1002, 0, [1]);
      if (response !== 0x2001) {
        throw rejected(response);
      }
      this.ensureCommandSession(command, generation);
      this.transaction = 1;
      return this.nameValue;
    } catch (error) {
      await this.cleanupConnectAttempt(generation, command, event);
      throw new Error(
        error instanceof Error ? error.message : 'PTP/IP 连接失败'
      );
    }
  }

  async capture(): Promise<void> {
    if (this.command === undefined) {
      throw new Error('请先连接 Wi‑Fi 相机');
    }
    const response: number = await this.sendCommand(
      0x100E,
      this.transaction++,
      [0, 0]
    );
    if (response !== 0x2001) {
      throw rejected(response);
    }
  }

  async listStorage(): Promise<CameraStorageSnapshot> {
    const volumes: Array<CameraStorageVolume> = [];
    const items: Array<CameraStorageItem> = [];
    const storageIds: Array<number> = parseStorageIds(
      await this.commandWithData(0x1004, this.transaction++, [])
    );
    for (const storageId of storageIds) {
      volumes.push(parseStorageInfo(
        storageId,
        await this.commandWithData(0x1005, this.transaction++, [storageId])
      ));
      const pendingHandles: Array<number> = parseStorageIds(
        await this.commandWithData(
          0x1007,
          this.transaction++,
          [storageId, 0, 0xffffffff]
        )
      );
      const visitedHandles: Set<number> = new Set<number>();
      let pendingIndex: number = 0;
      while (pendingIndex < pendingHandles.length) {
        const handle: number = pendingHandles[pendingIndex++];
        if (visitedHandles.has(handle)) {
          continue;
        }
        visitedHandles.add(handle);
        const objectInfo: Uint8Array = await this.commandWithData(
          0x1008,
          this.transaction++,
          [handle]
        );
        if (isObjectAssociation(objectInfo)) {
          const children: Array<number> = parseStorageIds(
            await this.commandWithData(
              0x1007,
              this.transaction++,
              [storageId, 0, handle]
            )
          );
          children.forEach((child: number): void => {
            if (!visitedHandles.has(child)) {
              pendingHandles.push(child);
            }
          });
        } else {
          const item: CameraStorageItem | undefined = parseObjectInfo(
            handle,
            objectInfo
          );
          if (item !== undefined) {
            items.push(item);
          }
        }
      }
    }
    items.sort((left: CameraStorageItem, right: CameraStorageItem): number => {
      const byDate: number = right.capturedAt.localeCompare(left.capturedAt);
      return byDate !== 0 ? byDate : right.filename.localeCompare(left.filename);
    });
    return new CameraStorageSnapshot(volumes, items);
  }

  async getStorageThumbnail(handle: number): Promise<Uint8Array> {
    return this.commandWithData(0x100a, this.transaction++, [handle]);
  }

  async downloadStorageObject(handle: number): Promise<Uint8Array> {
    return this.commandWithData(0x1009, this.transaction++, [handle], 180000);
  }

  async deleteStorageObject(handle: number): Promise<void> {
    const response: number = await this.sendCommand(
      0x100b,
      this.transaction++,
      [handle, 0]
    );
    if (response !== 0x2001) {
      throw rejected(response);
    }
  }

  async disconnect(): Promise<void> {
    this.connectionGeneration++;
    await this.closePublishedConnection();
  }

  private async closePublishedConnection(): Promise<void> {
    this.eventGeneration++;
    const command: PtpIpChannel | undefined = this.command;
    const event: PtpIpChannel | undefined = this.event;
    const pendingCommand: PtpIpChannel | undefined = this.pendingCommand;
    const pendingEvent: PtpIpChannel | undefined = this.pendingEvent;
    this.command = undefined;
    this.event = undefined;
    this.pendingCommand = undefined;
    this.pendingEvent = undefined;
    this.transaction = 1;
    this.nameValue = 'PTP/IP Camera';
    this.vendorValue = CameraVendor.UNKNOWN;
    this.liveViewValue = false;
    this.movieRecordingValue = false;
    this.commandChannelFailure = undefined;
    this.boundNetHandle = undefined;
    const closes: Array<Promise<void>> = [];
    if (pendingCommand !== undefined) {
      closes.push(pendingCommand.close());
    }
    if (pendingEvent !== undefined && pendingEvent !== pendingCommand) {
      closes.push(pendingEvent.close());
    }
    if (command !== undefined && command !== pendingCommand &&
      command !== pendingEvent) {
      closes.push(command.close());
    }
    if (event !== undefined && event !== pendingCommand &&
      event !== pendingEvent && event !== command) {
      closes.push(event.close());
    }
    await Promise.all(closes);
  }

  private async cleanupConnectAttempt(
    generation: number,
    command: PtpIpChannel,
    event: PtpIpChannel | undefined
  ): Promise<void> {
    if (this.connectionGeneration === generation) {
      this.connectionGeneration++;
      this.eventGeneration++;
      if (this.command === command) {
        this.command = undefined;
      }
      if (this.event === event) {
        this.event = undefined;
      }
      if (this.pendingCommand === command) {
        this.pendingCommand = undefined;
      }
      if (this.pendingEvent === event) {
        this.pendingEvent = undefined;
      }
      this.transaction = 1;
      this.nameValue = 'PTP/IP Camera';
      this.vendorValue = CameraVendor.UNKNOWN;
      this.liveViewValue = false;
      this.movieRecordingValue = false;
      this.commandChannelFailure = undefined;
      this.boundNetHandle = undefined;
    }
    try {
      await command.close();
    } finally {
      if (event !== undefined) {
        await event.close();
      }
    }
  }

  private ensureConnectionGeneration(expectedGeneration: number): void {
    if (this.connectionGeneration !== expectedGeneration) {
      throw new Error('PTP/IP 连接已取消或被新会话取代');
    }
  }

  private ensureCommandSession(
    expectedCommand: PtpIpChannel,
    expectedGeneration: number
  ): void {
    if (this.command !== expectedCommand ||
      this.connectionGeneration !== expectedGeneration) {
      throw new Error('PTP/IP 会话已断开或被新会话取代');
    }
    if (this.commandChannelFailure !== undefined) {
      throw new Error(
        `PTP/IP 命令通道不可用：${this.commandChannelFailure.message}`
      );
    }
  }

  /**
   * PTP/IP event 通道保活：发送 ProbeRequest(type 13)，等待常驻 reader
   * 收到 ProbeResponse(type 14)。命令通道保持空闲，不与在途事务争抢响应。
   */
  async probe(timeoutMilliseconds: number = 3000): Promise<void> {
    const event: PtpIpChannel | undefined = this.event;
    if (this.command === undefined || event === undefined) {
      throw new Error('请先连接 Wi‑Fi 相机');
    }
    if (this.commandChannelFailure !== undefined) {
      throw new Error(
        `PTP/IP 命令通道不可用：${this.commandChannelFailure.message}`
      );
    }
    if (this.probeInProgress) {
      throw new Error('已有 PTP/IP 心跳探测正在进行');
    }
    this.probeInProgress = true;
    const generation: number = this.eventGeneration;
    const baseline: number = this.probeResponseSequence;
    const deadline: number = Date.now() + timeoutMilliseconds;
    try {
      await this.sendEventPacket(
        event,
        generation,
        13,
        new Uint8Array(0)
      );
      while (this.probeResponseSequence === baseline) {
        if (generation !== this.eventGeneration || this.event !== event ||
          this.command === undefined) {
          throw new Error('PTP/IP 事件通道已断开');
        }
        const remaining: number = deadline - Date.now();
        if (remaining <= 0) {
          throw new Error('PTP/IP 心跳探测超时');
        }
        await delay(Math.min(25, remaining));
      }
      if (generation !== this.eventGeneration || this.event !== event ||
        this.command === undefined) {
        throw new Error('PTP/IP 事件通道已断开');
      }
    } finally {
      this.probeInProgress = false;
    }
  }

  /**
   * 识别已连机型厂商：优先解析 GetDeviceInfo(0x1001) 数据段 Manufacturer
   * （ISO 15740；0x1002 实为 OpenSession，勿混），退回握手相机名启发式。
   * 结果按会话缓存（detectVendor 在 connect 后调用），断连清零。
   */
  async detectVendor(): Promise<CameraVendor> {
    if (this.vendorValue !== CameraVendor.UNKNOWN) {
      return this.vendorValue;
    }
    let resolved: CameraVendor = vendorForName(this.nameValue);
    try {
      const info: Uint8Array = await this.commandWithData(
        0x1001,
        this.transaction++,
        []
      );
      const manufacturer: string | undefined = deviceInfoManufacturer(info);
      if (manufacturer !== undefined && manufacturer.trim().length > 0) {
        resolved = vendorForManufacturer(manufacturer, resolved);
      }
    } catch (error) {
      if (!PtpIpCamera.isCapabilityFallbackError(error as Error)) {
        throw error instanceof Error ? error : new Error(String(error));
      }
      // 部分机型明确拒绝/不支持 0x1001 时可退回名称启发式；传输、超时、
      // 帧、transaction 与会话失效错误必须阻止 UI 发布假连接。
    }
    this.vendorValue = resolved;
    return resolved;
  }

  /** 开始实时取景（Nikon 0x9201 / Canon EOS 序列，TBC-awaiting-hardware）。 */
  async startLiveView(): Promise<void> {
    if (this.command === undefined) {
      throw new Error('请先连接 Wi‑Fi 相机');
    }
    if (this.liveViewValue) {
      return;
    }
    if (this.vendorValue === CameraVendor.CANON) {
      if (!(await this.canonOpenLiveView())) {
        throw new Error(
          `${this.nameValue} 未能确认进入佳能实时取景（机身未确认取景输出）。`
        );
      }
      return;
    }
    const response: number = await this.sendCommand(
      PtpIpCamera.NIKON_START_LIVE_VIEW,
      this.transaction++,
      []
    );
    if (response !== PtpIpCamera.RESPONSE_OK) {
      throw rejected(response);
    }
    this.liveViewValue = true;
  }

  /** 停止实时取景（尽力而为）。 */
  async stopLiveView(): Promise<void> {
    if (!this.liveViewValue || this.command === undefined) {
      this.liveViewValue = false;
      return;
    }
    if (this.vendorValue === CameraVendor.CANON) {
      try {
        // E4：佳能先关 PC 输出再关取景模式（TBC-awaiting-hardware）。
        await this.canonWriteEosProp(PtpIpCamera.CANON_EVF_OUTPUT_DEVICE, 0);
        await this.canonWriteEosProp(PtpIpCamera.CANON_EVF_MODE, 0);
      } catch (error) {
      }
      this.liveViewValue = false;
      return;
    }
    try {
      const response: number = await this.sendCommand(
        PtpIpCamera.NIKON_END_LIVE_VIEW,
        this.transaction++,
        []
      );
      if (response !== PtpIpCamera.RESPONSE_OK) {
        throw rejected(response);
      }
    } catch (error) {
    }
    this.liveViewValue = false;
  }

  /** 取一帧实时取景 JPEG（Nikon 0x9203 / Canon 0x9153 EOS dataset，TBC）。 */
  async getLiveViewFrame(): Promise<Uint8Array> {
    if (this.command === undefined) {
      throw new Error('请先连接 Wi‑Fi 相机');
    }
    if (!this.liveViewValue) {
      throw new Error('实时取景尚未开启。');
    }
    if (this.vendorValue === CameraVendor.CANON) {
      const raw: Uint8Array = await this.commandWithData(
        PtpIpCamera.CANON_EOS_GET_VIEW_FINDER_DATA,
        this.transaction++,
        [0x00200000, 0, 0]
      );
      return this.extractEosJpeg(raw);
    }
    return this.extractJpeg(await this.commandWithData(
      PtpIpCamera.NIKON_GET_LIVE_VIEW_IMAGE,
      this.transaction++,
      []
    ));
  }

  /** 开始录像（Nikon 0x920a / Canon EVFRecordStatus，TBC-awaiting-hardware）。 */
  async startMovieRecording(): Promise<void> {
    if (this.command === undefined) {
      throw new Error('请先连接 Wi‑Fi 相机');
    }
    if (this.movieRecordingValue) {
      return;
    }
    if (this.vendorValue === CameraVendor.CANON) {
      await this.startLiveView();
      await this.canonWriteEosProp(PtpIpCamera.CANON_EVF_RECORD_STATUS, 1);
      this.movieRecordingValue = true;
      return;
    }
    if (!this.liveViewValue) {
      await this.startLiveView();
    }
    const response: number = await this.sendCommand(
      PtpIpCamera.NIKON_START_MOVIE_RECORDING,
      this.transaction++,
      []
    );
    if (response !== PtpIpCamera.RESPONSE_OK) {
      throw rejected(response);
    }
    this.movieRecordingValue = true;
  }

  /** 停止录像（Nikon 0x920b / Canon EVFRecordStatus=0，TBC-awaiting-hardware）。 */
  async stopMovieRecording(): Promise<void> {
    if (this.command === undefined) {
      throw new Error('请先连接 Wi‑Fi 相机');
    }
    try {
      if (this.vendorValue === CameraVendor.CANON) {
        await this.canonWriteEosProp(PtpIpCamera.CANON_EVF_RECORD_STATUS, 0);
      } else {
        const response: number = await this.sendCommand(
          PtpIpCamera.NIKON_END_MOVIE_RECORDING,
          this.transaction++,
          []
        );
        if (response !== PtpIpCamera.RESPONSE_OK) {
          throw rejected(response);
        }
      }
    } finally {
      this.movieRecordingValue = false;
    }
  }

  /** 读取设备属性原始值（GetDevicePropValue 0x1015，data-in）。 */
  async readProperty(property: number): Promise<Uint8Array> {
    return this.commandWithData(
      PtpIpCamera.GET_DEVICE_PROP_VALUE,
      this.transaction++,
      [property]
    );
  }

  /** 读取设备属性描述符（GetDevicePropDesc 0x1014），校验可写性。 */
  async readPropertyDescriptor(property: number): Promise<Uint8Array> {
    return this.commandWithData(
      PtpIpCamera.GET_DEVICE_PROP_DESC,
      this.transaction++,
      [property]
    );
  }

  /** 写入设备属性（SetDevicePropValue 0x1016，data-out 相位）。 */
  async writeProperty(property: number, value: Uint8Array): Promise<void> {
    const response: number = await this.sendCommandWithDataOut(
      PtpIpCamera.SET_DEVICE_PROP_VALUE,
      this.transaction++,
      [property],
      value
    );
    if (response !== PtpIpCamera.RESPONSE_OK) {
      throw rejected(response);
    }
  }

  /** 佳能 EOS 扩展属性写入（0x9110，12 字节 LE 载荷，TBC-awaiting-hardware）。 */
  private async canonWriteEosProp(propCode: number, value: number): Promise<void> {
    const payload: Array<number> = [];
    appendU32(payload, 12);
    appendU32(payload, propCode);
    appendU32(payload, value);
    const response: number = await this.sendCommandWithDataOut(
      PtpIpCamera.CANON_EOS_SET_PROP_VALUE_EX,
      this.transaction++,
      [],
      new Uint8Array(payload)
    );
    if (response !== PtpIpCamera.RESPONSE_OK) {
      throw rejected(response);
    }
  }

  /**
   * 佳能 EOS 取景开启（对齐 libgphoto2 canon.c，TBC-awaiting-hardware）：
   * EVFMode 读当前值非 1 才写（Movie 模式 Busy 容忍）；EVFOutputDevice
   * 仅 (cur & ~1)==0 时写 2=PC（读失败回退无条件写）。返回是否确认进入取景态。
   */
  private async canonOpenLiveView(): Promise<boolean> {
    let confirmed: boolean = false;
    try {
      const mode: number = await this.readEosPropValue(
        PtpIpCamera.CANON_EVF_MODE
      );
      if (mode !== 1) {
        try {
          await this.canonWriteEosProp(PtpIpCamera.CANON_EVF_MODE, 1);
        } catch (busy) {
          if (!PtpIpCamera.isDeviceBusyError(busy as Error)) {
            throw busy instanceof Error ? busy : new Error(String(busy));
          }
          // 仅明确的 DeviceBusy 可按 Movie 模式已占用 EVF 有限容忍。
        }
      }
      confirmed = true;
    } catch (error) {
      if (!PtpIpCamera.isDeviceBusyError(error as Error)) {
        throw error instanceof Error ? error : new Error(String(error));
      }
    }
    try {
      let current: number;
      try {
        current = await this.readEosPropValue(
          PtpIpCamera.CANON_EVF_OUTPUT_DEVICE
        );
      } catch (readError) {
        if (!PtpIpCamera.isDeviceBusyError(readError as Error)) {
          throw readError instanceof Error
            ? readError
            : new Error(String(readError));
        }
        current = -1;
      }
      if (current < 0 || (current & ~1) === 0) {
        try {
          await this.canonWriteEosProp(PtpIpCamera.CANON_EVF_OUTPUT_DEVICE, 2);
        } catch (busy) {
          if (!PtpIpCamera.isDeviceBusyError(busy as Error)) {
            throw busy instanceof Error ? busy : new Error(String(busy));
          }
        }
      }
      confirmed = true;
    } catch (error) {
      if (!PtpIpCamera.isDeviceBusyError(error as Error)) {
        throw error instanceof Error ? error : new Error(String(error));
      }
    }
    this.liveViewValue = confirmed;
    return confirmed;
  }

  /**
   * EOS 属性读取：标准 GetDevicePropValue(0x1015)（gphoto2 对 EOS 属性读
   * 同样走标准通道；0x9114 实为 SetRemoteMode 非属性读）。UINT16 回 2B / UINT32 回 4B。
   */
  private async readEosPropValue(propCode: number): Promise<number> {
    const data: Uint8Array = await this.commandWithData(
      PtpIpCamera.GET_DEVICE_PROP_VALUE,
      this.transaction++,
      [propCode]
    );
    if (data.length < 2) {
      throw new Error('佳能属性读取返回长度不足。');
    }
    return data.length >= 4 ? readU32(data, 0) : readU16(data, 0);
  }

  /**
   * EOS dataset → 内嵌 JPEG 提取（对齐 libgphoto2
   * ptp_canon_eos_get_viewfinder_image）：多个 blob 依 [u32 len][u32 type][payload]
   * 排列；type 1=常规 JPEG、9=Movie 模式 JPEG、11=JPEG；其余 type 跳过 len 字节。
   */
  private extractEosJpeg(source: Uint8Array): Uint8Array {
    let offset: number = 0;
    while (offset + 8 <= source.length) {
      const len: number = readU32(source, offset);
      const type: number = readU32(source, offset + 4);
      if (len < 8 || offset + len > source.length) {
        break;
      }
      if (type === 1 || type === 9 || type === 11) {
        // 载荷为 JPEG；再经标记扫描兜底（部分机身载荷带前导头）。
        return this.extractJpeg(source.slice(offset + 8, offset + len));
      }
      offset += len;
    }
    throw new Error(
      `${this.nameValue} 返回的佳能取景数据中没有 JPEG 图像。`
    );
  }

  /** JPEG 标记扫描（FFD8/FFD9）。 */
  private extractJpeg(source: Uint8Array): Uint8Array {
    let start: number = -1;
    let end: number = -1;
    for (let index: number = 0; index < source.length - 1; index++) {
      if (start < 0 && source[index] === 0xff && source[index + 1] === 0xd8) {
        start = index;
      }
      if (start >= 0 && source[index] === 0xff && source[index + 1] === 0xd9) {
        end = index + 2;
      }
    }
    if (start < 0 || end <= start) {
      throw new Error(`${this.nameValue} 返回的数据中没有 JPEG 图像。`);
    }
    return source.slice(start, end);
  }

  /**
   * data-out 请求（DataPhaseInfo=2）：请求(type 6) → StartData(type 9,
   * 载荷 [TransactionID][TotalLength u64]) → EndData(type 12,
   * [TransactionID][数据]) → 响应(type 7)。
   * 用于 SetDevicePropValue(0x1016) 与 Canon EOS_SetDevicePropValueEx(0x9110)。
   */
  private async sendCommandWithDataOut(
    operation: number,
    transaction: number,
    parameters: Array<number>,
    data: Uint8Array
  ): Promise<number> {
    const expectedCommand: PtpIpChannel | undefined = this.command;
    if (expectedCommand === undefined) {
      throw new Error('请先连接 Wi‑Fi 相机');
    }
    const expectedGeneration: number = this.connectionGeneration;
    await this.commandGate.acquire();
    try {
      this.ensureCommandSession(expectedCommand, expectedGeneration);
      const request: Array<number> = [];
      appendU32(request, 2); // DataPhaseInfo=2（数据出）
      appendU16(request, operation);
      appendU32(request, transaction);
      parameters.forEach((value: number): void => appendU32(request, value));
      await expectedCommand.send(6, new Uint8Array(request));

      const startData: Array<number> = [];
      appendU32(startData, transaction);
      appendU64(startData, data.length);
      await expectedCommand.send(9, new Uint8Array(startData));

      const endData: Array<number> = [];
      appendU32(endData, transaction);
      for (let index: number = 0; index < data.length; index++) {
        endData.push(data[index]);
      }
      await expectedCommand.send(12, new Uint8Array(endData));

      const response: PtpIpPacket = await expectedCommand.receive();
      if (response.type !== 7 || response.data.length < 14 ||
        readU32(response.data, 10) !== (transaction >>> 0)) {
        throw new Error('相机返回了无效的 PTP/IP 响应');
      }
      const responseCode: number = readU16(response.data, 8);
      this.markSessionFatalResponse(
        expectedCommand,
        expectedGeneration,
        responseCode
      );
      return responseCode;
    } catch (error) {
      if (error instanceof PtpIpResponseError) {
        throw error;
      }
      const failure: Error = error instanceof Error
        ? error
        : new Error(String(error));
      this.markCommandChannelFailed(
        expectedCommand,
        expectedGeneration,
        failure
      );
      throw failure;
    } finally {
      this.commandGate.release();
    }
  }

  private async sendCommand(
    operation: number,
    transaction: number,
    parameters: Array<number>
  ): Promise<number> {
    return this.sendCommandWithTimeout(
      operation,
      transaction,
      parameters,
      undefined
    );
  }

  private async sendCommandWithTimeout(
    operation: number,
    transaction: number,
    parameters: Array<number>,
    timeoutMilliseconds: number | undefined
  ): Promise<number> {
    const expectedCommand: PtpIpChannel | undefined = this.command;
    if (expectedCommand === undefined) {
      throw new Error('请先连接 Wi‑Fi 相机');
    }
    const expectedGeneration: number = this.connectionGeneration;
    await this.commandGate.acquire();
    try {
      this.ensureCommandSession(expectedCommand, expectedGeneration);
      const payload: Array<number> = [];
      appendU32(payload, 1);
      appendU16(payload, operation);
      appendU32(payload, transaction);
      parameters.forEach((value: number): void => appendU32(payload, value));
      await expectedCommand.send(6, new Uint8Array(payload));
      const response: PtpIpPacket = await expectedCommand.receive(
        timeoutMilliseconds
      );
      if (response.type !== 7 || response.data.length < 14 ||
        readU32(response.data, 10) !== (transaction >>> 0)) {
        throw new Error('相机返回了无效的 PTP/IP 响应');
      }
      const responseCode: number = readU16(response.data, 8);
      this.markSessionFatalResponse(
        expectedCommand,
        expectedGeneration,
        responseCode
      );
      return responseCode;
    } catch (error) {
      if (error instanceof PtpIpResponseError) {
        throw error;
      }
      const failure: Error = error instanceof Error
        ? error
        : new Error(String(error));
      this.markCommandChannelFailed(
        expectedCommand,
        expectedGeneration,
        failure
      );
      throw failure;
    } finally {
      this.commandGate.release();
    }
  }

  private async commandWithData(
    operation: number,
    transaction: number,
    parameters: Array<number>,
    timeoutMilliseconds: number = 30000
  ): Promise<Uint8Array> {
    const expectedCommand: PtpIpChannel | undefined = this.command;
    if (expectedCommand === undefined) {
      throw new Error('请先连接 Wi‑Fi 相机');
    }
    const expectedGeneration: number = this.connectionGeneration;
    await this.commandGate.acquire();
    try {
      this.ensureCommandSession(expectedCommand, expectedGeneration);
      const payload: Array<number> = [];
      appendU32(payload, 1);
      appendU16(payload, operation);
      appendU32(payload, transaction);
      parameters.forEach((value: number): void => appendU32(payload, value));
      await expectedCommand.send(6, new Uint8Array(payload));
      const first: PtpIpPacket = await expectedCommand.receive(
        timeoutMilliseconds
      );
      if (first.type === 7) {
        if (first.data.length < 14 ||
          readU32(first.data, 10) !== (transaction >>> 0)) {
          throw new Error('相机返回了无效的 PTP/IP 响应');
        }
        const responseCode: number = readU16(first.data, 8);
        this.markSessionFatalResponse(
          expectedCommand,
          expectedGeneration,
          responseCode
        );
        throw rejected(responseCode);
      }
      if (first.type !== 9 || first.data.length < 20 ||
        readU32(first.data, 8) !== (transaction >>> 0)) {
        throw new Error('相机返回了无效的 PTP/IP 数据阶段');
      }
      const totalLengthLow: number = readU32(first.data, 12);
      const totalLengthHigh: number = readU32(first.data, 16);
      const unknownLength: boolean = totalLengthLow === 0xffffffff &&
        totalLengthHigh === 0xffffffff;
      const totalLength: number = unknownLength
        ? 0
        : readU64(first.data, 12);
      if (!unknownLength && totalLength > 512 * 1024 * 1024) {
        throw new Error('机内文件超过当前 512 MB 单文件传输上限');
      }
      const chunks: Array<Uint8Array> = [];
      let received: number = 0;
      while (true) {
        const packet: PtpIpPacket = await expectedCommand.receive(
          timeoutMilliseconds
        );
        if ((packet.type !== 10 && packet.type !== 12) ||
          packet.data.length < 12 ||
          readU32(packet.data, 8) !== (transaction >>> 0)) {
          throw new Error('相机返回了无效的 PTP/IP 文件数据包');
        }
        const chunk: Uint8Array = packet.data.slice(12);
        received += chunk.length;
        if (received > 512 * 1024 * 1024) {
          throw new Error('机内文件超过当前 512 MB 单文件传输上限');
        }
        if (!unknownLength && received > totalLength) {
          throw new Error('PTP/IP 数据超过 StartData 声明长度');
        }
        chunks.push(chunk);
        if (packet.type === 12) {
          break;
        }
      }
      if (!unknownLength && received !== totalLength) {
        throw new Error('PTP/IP EndData 长度与 StartData 声明不一致');
      }
      const response: PtpIpPacket = await expectedCommand.receive(
        timeoutMilliseconds
      );
      if (response.type !== 7 || response.data.length < 14 ||
        readU32(response.data, 10) !== (transaction >>> 0)) {
        throw new Error('相机没有完成 PTP/IP 文件事务');
      }
      const code: number = readU16(response.data, 8);
      this.markSessionFatalResponse(
        expectedCommand,
        expectedGeneration,
        code
      );
      if (code !== 0x2001) {
        throw rejected(code);
      }
      const result: Uint8Array = new Uint8Array(received);
      let offset: number = 0;
      chunks.forEach((chunk: Uint8Array): void => {
        result.set(chunk, offset);
        offset += chunk.length;
      });
      return result;
    } catch (error) {
      if (error instanceof PtpIpResponseError) {
        throw error;
      }
      const failure: Error = error instanceof Error
        ? error
        : new Error(String(error));
      this.markCommandChannelFailed(
        expectedCommand,
        expectedGeneration,
        failure
      );
      throw failure;
    } finally {
      this.commandGate.release();
    }
  }

  private markCommandChannelFailed(
    expectedCommand: PtpIpChannel,
    expectedGeneration: number,
    error: Error
  ): void {
    if (this.command === expectedCommand &&
      this.connectionGeneration === expectedGeneration) {
      this.commandChannelFailure = error;
    }
  }

  private markSessionFatalResponse(
    expectedCommand: PtpIpChannel,
    expectedGeneration: number,
    response: number
  ): void {
    if (response !== PtpIpCamera.RESPONSE_SESSION_NOT_OPEN &&
      response !== PtpIpCamera.RESPONSE_INVALID_TRANSACTION_ID &&
      response !== PtpIpCamera.RESPONSE_SESSION_ALREADY_OPEN) {
      return;
    }
    this.markCommandChannelFailed(
      expectedCommand,
      expectedGeneration,
      new Error(
        `PTP/IP 会话失效（响应 0x${response.toString(16).padStart(4, '0')}）`
      )
    );
  }

  private startEventReader(event: PtpIpChannel): void {
    const generation: number = ++this.eventGeneration;
    this.runEventReader(event, generation);
  }

  private async runEventReader(
    event: PtpIpChannel,
    generation: number
  ): Promise<void> {
    while (generation === this.eventGeneration && this.event === event) {
      try {
        const packet: PtpIpPacket = await event.receive(60000);
        if (generation !== this.eventGeneration || this.event !== event) {
          return;
        }
        if (packet.type === 13) {
          await this.sendEventPacket(
            event,
            generation,
            14,
            new Uint8Array(0)
          );
        } else if (packet.type === 14) {
          this.probeResponseSequence++;
        } else if (packet.type === 8) {
          // 事件包已完整排空；业务事件接入时在此分发。
        }
      } catch (error) {
        if (generation !== this.eventGeneration || this.event !== event) {
          return;
        }
        // PtpIpChannel.receive 的空转超时（PtpIpReceiveTimeoutError，
        // “相机未在限定时间内返回 PTP/IP 响应”）不代表链路死亡：心跳探测
        // 暂停而 reader 仍在运行时也会触发。记录后继续循环，存活裁决仍归
        // 心跳 probe；只有真正的关闭/错误才断开会话。
        if (error instanceof PtpIpReceiveTimeoutError) {
          continue;
        }
        await this.disconnect();
        return;
      }
    }
  }

  private async sendEventPacket(
    event: PtpIpChannel,
    generation: number,
    type: number,
    payload: Uint8Array
  ): Promise<void> {
    const expectedConnectionGeneration: number = this.connectionGeneration;
    await this.eventWriterGate.acquire();
    try {
      if (this.event !== event || this.eventGeneration !== generation ||
        this.connectionGeneration !== expectedConnectionGeneration) {
        throw new Error('PTP/IP 事件通道已断开或被新会话取代');
      }
      await event.send(type, payload);
    } finally {
      this.eventWriterGate.release();
    }
  }
}

function appendU16(values: Array<number>, value: number): void {
  values.push(value & 0xff, (value >>> 8) & 0xff);
}

function appendU32(values: Array<number>, value: number): void {
  values.push(
    value & 0xff,
    (value >>> 8) & 0xff,
    (value >>> 16) & 0xff,
    (value >>> 24) & 0xff
  );
}

function appendUtf16(values: Array<number>, text: string): void {
  for (let index: number = 0; index < text.length; index++) {
    appendU16(values, text.charCodeAt(index));
  }
  appendU16(values, 0);
}

function readU16(bytes: Uint8Array, offset: number): number {
  return bytes[offset] | (bytes[offset + 1] << 8);
}

function readU32(bytes: Uint8Array, offset: number): number {
  return (bytes[offset]
    | (bytes[offset + 1] << 8)
    | (bytes[offset + 2] << 16)
    | (bytes[offset + 3] << 24)) >>> 0;
}

function readU64(bytes: Uint8Array, offset: number): number {
  const low: number = readU32(bytes, offset);
  const high: number = readU32(bytes, offset + 4);
  return Math.min(Number.MAX_SAFE_INTEGER, high * 4294967296 + low);
}

function writeU32(bytes: Uint8Array, offset: number, value: number): void {
  bytes[offset] = value & 0xff;
  bytes[offset + 1] = (value >>> 8) & 0xff;
  bytes[offset + 2] = (value >>> 16) & 0xff;
  bytes[offset + 3] = (value >>> 24) & 0xff;
}

function readUtf16(bytes: Uint8Array, offset: number): string {
  let result: string = '';
  for (let index: number = offset; index + 1 < bytes.length; index += 2) {
    const value: number = readU16(bytes, index);
    if (value === 0) {
      break;
    }
    result += String.fromCharCode(value);
  }
  return result;
}

// ── E4 1.5.9：module-level helper（镜像 Android PtpIpCamera.java，
// 字节级口径见 docs/PTPIP_PROTOCOL.md；全部 TBC-awaiting-hardware）──

/** 小端 u64 追加（低 32 位在前，与 Android ByteWriter.u64 同构）。 */
function appendU64(values: Array<number>, value: number): void {
  appendU32(values, value & 0xffffffff);
  appendU32(values, Math.floor(value / 4294967296) & 0xffffffff);
}

/**
 * 从 offsetRef[0] 读取 PIMA 15740 PTP STR：u8 字符数（含 UTF-16 NUL）+
 * UTF-16LE code units。字符数为 0 表示空字符串。
 */
function readPtpString(
  bytes: Uint8Array,
  offsetRef: Array<number>
): string | undefined {
  let offset: number = offsetRef[0];
  if (offset >= bytes.length) {
    return undefined;
  }
  const characterCount: number = bytes[offset++];
  if (characterCount === 0) {
    offsetRef[0] = offset;
    return '';
  }
  const byteCount: number = characterCount * 2;
  if (byteCount > bytes.length - offset ||
    readU16(bytes, offset + byteCount - 2) !== 0) {
    return undefined;
  }
  let result: string = '';
  const textEnd: number = offset + byteCount - 2;
  while (offset < textEnd) {
    result += String.fromCharCode(readU16(bytes, offset));
    offset += 2;
  }
  offsetRef[0] = offset + 2;
  return result;
}

/**
 * GetDeviceInfo(0x1001) 数据段 Manufacturer 解析（PIMA 15740）：
 * StandardVersion(2)+VendorExtensionID(4)+VendorExtensionVersion(2)+
 * VendorExtensionDesc(PTP STR)+FunctionalMode(2)+五个 AUINT16
 * (u32 数量+u16 条目)+Manufacturer(PTP STR)。
 */
function deviceInfoManufacturer(bytes: Uint8Array): string | undefined {
  if (bytes.length < 8) {
    return undefined;
  }
  const offset: Array<number> = [8];
  if (readPtpString(bytes, offset) === undefined) {
    return undefined; // VendorExtensionDesc
  }
  if (offset[0] + 2 > bytes.length) {
    return undefined;
  }
  offset[0] += 2; // FunctionalMode
  for (let index: number = 0; index < 5; index++) {
    // Operations/Events/DeviceProperties/CaptureFormats/ImageFormats
    if (offset[0] + 4 > bytes.length) {
      return undefined;
    }
    const count: number = readU32(bytes, offset[0]);
    offset[0] += 4;
    if (count > Math.floor((bytes.length - offset[0]) / 2)) {
      return undefined;
    }
    offset[0] += count * 2;
  }
  return readPtpString(bytes, offset);
}

/** 按 Manufacturer 文本判定厂商（Android vendorForManufacturer 同构）。 */
function vendorForManufacturer(manufacturer: string, fallback: CameraVendor): CameraVendor {
  const text: string = manufacturer.toLowerCase();
  if (text.includes('nikon')) {
    return CameraVendor.NIKON;
  }
  if (text.includes('canon')) {
    return CameraVendor.CANON;
  }
  if (text.includes('sony')) {
    return CameraVendor.SONY;
  }
  return fallback;
}

/** 按握手相机名启发式判定厂商（Android vendorForName 同构）。 */
function vendorForName(name: string): CameraVendor {
  const text: string = name.toLowerCase();
  if (text.includes('nikon')) {
    return CameraVendor.NIKON;
  }
  if (text.includes('canon')) {
    return CameraVendor.CANON;
  }
  if (text.includes('sony') || text.includes('ilce') || text.includes('alpha')) {
    return CameraVendor.SONY;
  }
  return CameraVendor.UNKNOWN;
}

function rejected(response: number): Error {
  return new PtpIpResponseError(response);
}

function delay(milliseconds: number): Promise<void> {
  return new Promise<void>((resolve: () => void): void => {
    setTimeout(resolve, milliseconds);
  });
}
