import { socket } from '@kit.NetworkKit';
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

export class PtpIpCamera {
  private command?: PtpIpChannel;
  private event?: PtpIpChannel;
  private transaction: number = 1;
  private nameValue: string = 'PTP/IP Camera';

  get isConnected(): boolean {
    return this.command !== undefined;
  }

  get name(): string {
    return this.nameValue;
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
    if (command !== undefined) {
      await command.close();
    }
    if (event !== undefined) {
      await event.close();
    }
  }

  private async sendCommand(
    operation: number,
    transaction: number,
    parameters: Array<number>
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
    const response: PtpIpPacket = await command.receive();
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
