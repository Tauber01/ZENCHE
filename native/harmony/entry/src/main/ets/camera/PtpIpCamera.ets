import { socket } from '@kit.NetworkKit';
import { util } from '@kit.ArkTS';
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

class PtpIpChannel {
  readonly tcp: socket.TCPSocket = socket.constructTCPSocketInstance();
  private buffer: Uint8Array = new Uint8Array(0);
  private packets: Array<PtpIpPacket> = [];

  constructor() {
    this.tcp.on('message', (message: socket.SocketMessageInfo): void => {
      this.append(new Uint8Array(message.message));
    });
  }

  async connect(host: string, port: number): Promise<void> {
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
      await delay(10);
    }
    throw new Error('相机未在限定时间内返回 PTP/IP 响应');
  }

  async close(): Promise<void> {
    this.tcp.off('message');
    try {
      await this.tcp.close();
    } catch (error) {
    }
    this.buffer = new Uint8Array(0);
    this.packets = [];
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

  private command?: PtpIpChannel;
  private event?: PtpIpChannel;
  private transaction: number = 1;
  private nameValue: string = 'PTP/IP Camera';
  private vendorValue: CameraVendor = CameraVendor.UNKNOWN;
  private liveViewValue: boolean = false;
  private movieRecordingValue: boolean = false;

  get isConnected(): boolean {
    return this.command !== undefined;
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

  async connect(host: string, port: number): Promise<string> {
    await this.disconnect();
    if (host.trim().length === 0 || port < 1 || port > 65535) {
      throw new Error('Wi‑Fi 相机地址或端口无效');
    }
    const command: PtpIpChannel = new PtpIpChannel();
    try {
      await command.connect(host.trim(), port);
      const initialization: Array<number> = [];
      for (let index: number = 0; index < 16; index++) {
        initialization.push(Math.floor(Math.random() * 256));
      }
      appendUtf16(initialization, 'ZENCHE HarmonyOS');
      appendU32(initialization, 0x00010000);
      await command.send(1, new Uint8Array(initialization));
      const acknowledgment: PtpIpPacket = await command.receive();
      if (acknowledgment.type !== 2 || acknowledgment.data.length < 28) {
        throw new Error('相机返回了无效的 PTP/IP 握手数据');
      }
      const connectionNumber: number = readU32(acknowledgment.data, 8);
      const announcedName: string = readUtf16(acknowledgment.data, 28);
      this.nameValue = announcedName.length > 0
        ? announcedName
        : 'PTP/IP Camera';

      const event: PtpIpChannel = new PtpIpChannel();
      await event.connect(host.trim(), port);
      const eventInitialization: Uint8Array = new Uint8Array(4);
      writeU32(eventInitialization, 0, connectionNumber);
      await event.send(3, eventInitialization);
      const eventAcknowledgment: PtpIpPacket = await event.receive();
      if (eventAcknowledgment.type !== 4) {
        throw new Error('相机未确认 PTP/IP 事件通道');
      }
      this.command = command;
      this.event = event;
      const response: number = await this.sendCommand(0x1002, 0, [1]);
      if (response !== 0x2001) {
        throw rejected(response);
      }
      this.transaction = 1;
      return this.nameValue;
    } catch (error) {
      await command.close();
      await this.disconnect();
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
    const command: PtpIpChannel | undefined = this.command;
    const event: PtpIpChannel | undefined = this.event;
    this.command = undefined;
    this.event = undefined;
    this.transaction = 1;
    this.nameValue = 'PTP/IP Camera';
    this.vendorValue = CameraVendor.UNKNOWN;
    this.liveViewValue = false;
    this.movieRecordingValue = false;
    if (command !== undefined) {
      await command.close();
    }
    if (event !== undefined) {
      await event.close();
    }
  }

  /**
   * 无副作用链路探测：GetDeviceInfo（0x1002），用于心跳保活。
   * 与在途命令同走 sendCommand（顺序 await，天然串行）；单次超时 3s。
   */
  async probe(timeoutMilliseconds: number = 3000): Promise<void> {
    if (this.command === undefined) {
      throw new Error('请先连接 Wi‑Fi 相机');
    }
    const response: number = await this.sendCommandWithTimeout(
      0x1002,
      0,
      [1],
      timeoutMilliseconds
    );
    if (response !== 0x2001) {
      throw rejected(response);
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
        [1]
      );
      const manufacturer: string | undefined = deviceInfoManufacturer(info);
      if (manufacturer !== undefined && manufacturer.trim().length > 0) {
        resolved = vendorForManufacturer(manufacturer, resolved);
      }
    } catch (error) {
      // 部分机型对 0x1001 直接回响应（无数据段），退回名称启发式。
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
      [],
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
          // Movie 模式 Busy 容忍。
        }
      }
      confirmed = true;
    } catch (error) {
      // 读取失败容忍。
    }
    try {
      let current: number;
      try {
        current = await this.readEosPropValue(
          PtpIpCamera.CANON_EVF_OUTPUT_DEVICE
        );
      } catch (readError) {
        current = -1; // 读失败回退无条件写
      }
      if (current < 0 || (current & ~1) === 0) {
        try {
          await this.canonWriteEosProp(PtpIpCamera.CANON_EVF_OUTPUT_DEVICE, 2);
        } catch (busy) {
          // 容忍。
        }
      }
      confirmed = true;
    } catch (error) {
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
   * 载荷 [前导 0][TransactionID][TotalLength u64][数据]，对齐 iOS/Windows
   * 事实标准，TBC-awaiting-hardware) → EndData(type 12) → 响应(type 7)。
   * 用于 SetDevicePropValue(0x1016) 与 Canon EOS_SetDevicePropValueEx(0x9110)。
   */
  private async sendCommandWithDataOut(
    operation: number,
    transaction: number,
    parameters: Array<number>,
    data: Uint8Array
  ): Promise<number> {
    const command: PtpIpChannel | undefined = this.command;
    if (command === undefined) {
      throw new Error('请先连接 Wi‑Fi 相机');
    }
    const request: Array<number> = [];
    appendU32(request, 2); // DataPhaseInfo=2（数据出）
    appendU16(request, operation);
    appendU32(request, transaction);
    parameters.forEach((value: number): void => appendU32(request, value));
    await command.send(6, new Uint8Array(request));

    const startData: Array<number> = [];
    appendU32(startData, 0);
    appendU32(startData, transaction);
    appendU64(startData, data.length);
    for (let index: number = 0; index < data.length; index++) {
      startData.push(data[index]);
    }
    await command.send(9, new Uint8Array(startData));

    const endData: Array<number> = [];
    appendU32(endData, 0);
    appendU32(endData, transaction);
    await command.send(12, new Uint8Array(endData));

    const response: PtpIpPacket = await command.receive();
    if (response.type !== 7 || response.data.length < 14) {
      throw new Error('相机返回了无效的 PTP/IP 响应');
    }
    return readU16(response.data, 8);
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
    const command: PtpIpChannel | undefined = this.command;
    if (command === undefined) {
      throw new Error('请先连接 Wi‑Fi 相机');
    }
    const payload: Array<number> = [];
    appendU32(payload, 1);
    appendU16(payload, operation);
    appendU32(payload, transaction);
    parameters.forEach((value: number): void => appendU32(payload, value));
    await command.send(6, new Uint8Array(payload));
    const response: PtpIpPacket = await command.receive(timeoutMilliseconds);
    if (response.type !== 7 || response.data.length < 14) {
      throw new Error('相机返回了无效的 PTP/IP 响应');
    }
    return readU16(response.data, 8);
  }

  private async commandWithData(
    operation: number,
    transaction: number,
    parameters: Array<number>,
    timeoutMilliseconds: number = 30000
  ): Promise<Uint8Array> {
    const command: PtpIpChannel | undefined = this.command;
    if (command === undefined) {
      throw new Error('请先连接 Wi‑Fi 相机');
    }
    const payload: Array<number> = [];
    appendU32(payload, 1);
    appendU16(payload, operation);
    appendU32(payload, transaction);
    parameters.forEach((value: number): void => appendU32(payload, value));
    await command.send(6, new Uint8Array(payload));
    const first: PtpIpPacket = await command.receive(timeoutMilliseconds);
    if (first.type === 7) {
      throw rejected(first.data.length >= 10 ? readU16(first.data, 8) : 0x2002);
    }
    if (first.type !== 9 || first.data.length < 20 ||
      readU32(first.data, 8) !== (transaction >>> 0)) {
      throw new Error('相机返回了无效的 PTP/IP 数据阶段');
    }
    const totalLength: number = readU64(first.data, 12);
    if (totalLength > 512 * 1024 * 1024) {
      throw new Error('机内文件超过当前 512 MB 单文件传输上限');
    }
    const chunks: Array<Uint8Array> = [];
    let received: number = 0;
    while (true) {
      const packet: PtpIpPacket = await command.receive(timeoutMilliseconds);
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
      chunks.push(chunk);
      if (packet.type === 12) {
        break;
      }
    }
    const response: PtpIpPacket = await command.receive(timeoutMilliseconds);
    if (response.type !== 7 || response.data.length < 14) {
      throw new Error('相机没有完成 PTP/IP 文件事务');
    }
    const code: number = readU16(response.data, 8);
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

/** 从 offsetRef[0] 起读一个 NUL 结尾 UTF-8 字符串（Android readUtf8 同构）。 */
function readUtf8(bytes: Uint8Array, offsetRef: Array<number>): string | undefined {
  const offset: number = offsetRef[0];
  if (offset >= bytes.length) {
    return undefined;
  }
  let end: number = offset;
  while (end < bytes.length && bytes[end] !== 0) {
    end++;
  }
  if (end >= bytes.length) {
    return undefined;
  }
  const text: string = new util.TextDecoder('utf-8').decodeToString(bytes.slice(offset, end));
  offsetRef[0] = end + 1;
  return text;
}

/**
 * GetDeviceInfo(0x1001) 数据段 Manufacturer 解析（UTF-8，布局见 PTPIP_PROTOCOL.md §4）：
 * StandardVersion(2)+VendorExtensionID(4)+VendorExtensionVersion(2)+
 * VendorExtensionDesc(UTF8)+FunctionalMode(2)+四个数组(各 2 字节长度+条目)+
 * ImageFormats(同上)+Manufacturer(UTF8)。
 */
function deviceInfoManufacturer(bytes: Uint8Array): string | undefined {
  if (bytes.length < 8) {
    return undefined;
  }
  const offset: Array<number> = [8];
  if (readUtf8(bytes, offset) === undefined) {
    return undefined; // VendorExtensionDesc
  }
  if (offset[0] + 2 > bytes.length) {
    return undefined;
  }
  offset[0] += 2; // FunctionalMode
  for (let index: number = 0; index < 4; index++) { // Operations/Events/DeviceProperties/CaptureFormats
    if (offset[0] + 2 > bytes.length) {
      return undefined;
    }
    const count: number = readU16(bytes, offset[0]);
    offset[0] += 2;
    if (offset[0] + count * 2 > bytes.length) {
      return undefined;
    }
    offset[0] += count * 2;
  }
  if (offset[0] + 2 > bytes.length) {
    return undefined;
  }
  const imageCount: number = readU16(bytes, offset[0]); // ImageFormats
  offset[0] += 2;
  if (offset[0] + imageCount * 2 > bytes.length) {
    return undefined;
  }
  offset[0] += imageCount * 2;
  return readUtf8(bytes, offset);
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
  return new Error(
    `相机拒绝了 PTP/IP 操作（0x${response.toString(16).padStart(4, '0')}）`
  );
}

function delay(milliseconds: number): Promise<void> {
  return new Promise<void>((resolve: () => void): void => {
    setTimeout(resolve, milliseconds);
  });
}
