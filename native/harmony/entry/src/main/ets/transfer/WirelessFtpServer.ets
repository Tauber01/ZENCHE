import { BusinessError } from '@kit.BasicServicesKit';
import { wifiManager } from '@kit.ConnectivityKit';
import { socket } from '@kit.NetworkKit';
import {
  IncomingPhotoFile,
  PhotoLibrary
} from '../storage/PhotoLibrary';

const CONTROL_PORT: number = 2121;
const PASSIVE_PORT: number = 2122;
const USERNAME: string = 'nikonlink';
const PASSWORD: string = 'nikonlink';
const MAXIMUM_FILE_SIZE: number = 16 * 1024 * 1024 * 1024;

export type FtpStatusCallback = (status: string) => void;
export type FtpFileCallback = (path: string) => void;

class PassiveChannel {
  private server: socket.TCPSocketServer;
  private connection?: socket.TCPSocketConnection;
  private connectionResolver?: (connection: socket.TCPSocketConnection) => void;
  private connectionPromise: Promise<socket.TCPSocketConnection>;

  constructor() {
    this.server = socket.constructTCPSocketServerInstance();
    this.connectionPromise = new Promise<socket.TCPSocketConnection>(
      (resolve: (connection: socket.TCPSocketConnection) => void) => {
        this.connectionResolver = resolve;
      }
    );
  }

  async start(): Promise<void> {
    this.server.on(
      'connect',
      (connection: socket.TCPSocketConnection): void => {
        this.connection = connection;
        if (this.connectionResolver !== undefined) {
          this.connectionResolver(connection);
          this.connectionResolver = undefined;
        }
      }
    );
    await this.server.listen({
      address: '0.0.0.0',
      port: PASSIVE_PORT,
      family: 1
    });
  }

  async accept(): Promise<socket.TCPSocketConnection> {
    return this.connection ?? await this.connectionPromise;
  }

  async close(): Promise<void> {
    if (this.connection !== undefined) {
      try {
        await this.connection.close();
      } catch (error) {
      }
      this.connection = undefined;
    }
    try {
      await this.server.close();
    } catch (error) {
    }
  }
}

export class WirelessFtpServer {
  private library: PhotoLibrary;
  private statusCallback: FtpStatusCallback;
  private fileCallback: FtpFileCallback;
  private server?: socket.TCPSocketServer;
  private clients: Array<socket.TCPSocketConnection> = [];
  private running: boolean = false;

  constructor(
    library: PhotoLibrary,
    statusCallback: FtpStatusCallback,
    fileCallback: FtpFileCallback
  ) {
    this.library = library;
    this.statusCallback = statusCallback;
    this.fileCallback = fileCallback;
  }

  get isRunning(): boolean {
    return this.running;
  }

  get localAddress(): string {
    try {
      const value: number = wifiManager.getIpInfo().ipAddress;
      if (value === 0) {
        return '未检测到 Wi-Fi 地址';
      }
      return `${value & 0xff}.${(value >>> 8) & 0xff}.` +
        `${(value >>> 16) & 0xff}.${(value >>> 24) & 0xff}`;
    } catch (error) {
      return '未检测到 Wi-Fi 地址';
    }
  }

  async start(): Promise<void> {
    if (this.running) {
      return;
    }
    const server: socket.TCPSocketServer =
      socket.constructTCPSocketServerInstance();
    server.on(
      'connect',
      (connection: socket.TCPSocketConnection): void => {
        this.clients.push(connection);
        this.handleClient(connection);
      }
    );
    server.on('error', (error: BusinessError): void => {
      if (this.running) {
        this.statusCallback(`无线接收失败：${error.message}`);
      }
    });
    await server.listen({
      address: '0.0.0.0',
      port: CONTROL_PORT,
      family: 1
    });
    this.server = server;
    this.running = true;
    this.statusCallback('等待相机无线传输');
  }

  async stop(): Promise<void> {
    this.running = false;
    for (const client of this.clients) {
      try {
        await client.close();
      } catch (error) {
      }
    }
    this.clients = [];
    if (this.server !== undefined) {
      try {
        await this.server.close();
      } catch (error) {
      }
      this.server = undefined;
    }
    this.statusCallback('无线收件箱未开启');
  }

  private handleClient(client: socket.TCPSocketConnection): void {
    let pendingText: string = '';
    let acceptedUser: boolean = false;
    let authenticated: boolean = false;
    let passive: PassiveChannel | undefined;
    let commandQueue: Promise<void> = Promise.resolve();

    const sendReply = async (line: string): Promise<void> => {
      await client.send({
        data: `${line}\r\n`,
        encoding: 'UTF-8'
      });
    };

    const closePassive = async (): Promise<void> => {
      if (passive !== undefined) {
        await passive.close();
        passive = undefined;
      }
    };

    const processLine = async (line: string): Promise<void> => {
      const trimmed: string = line.trim();
      if (trimmed.length === 0) {
        return;
      }
      const separator: number = trimmed.indexOf(' ');
      const command: string = (
        separator < 0 ? trimmed : trimmed.substring(0, separator)
      ).toUpperCase();
      const argument: string =
        separator < 0 ? '' : trimmed.substring(separator + 1).trim();

      if (command === 'USER') {
        acceptedUser = argument.toLowerCase() === USERNAME;
        await sendReply(
          acceptedUser ? '331 Password required' : '530 Invalid user'
        );
        return;
      }
      if (command === 'PASS') {
        authenticated = acceptedUser && argument === PASSWORD;
        await sendReply(
          authenticated ? '230 Login successful' : '530 Login incorrect'
        );
        return;
      }
      if (command === 'QUIT') {
        await sendReply('221 Goodbye');
        await client.close();
        return;
      }
      if (command === 'NOOP') {
        await sendReply('200 OK');
        return;
      }
      if (command === 'SYST') {
        await sendReply('215 UNIX Type: L8');
        return;
      }
      if (command === 'FEAT') {
        await client.send({
          data: '211-Features\r\n EPSV\r\n PASV\r\n UTF8\r\n211 End\r\n',
          encoding: 'UTF-8'
        });
        return;
      }
      if (command === 'OPTS' || command === 'CLNT') {
        await sendReply('200 OK');
        return;
      }
      if (!authenticated) {
        await sendReply('530 Please login');
        return;
      }

      switch (command) {
        case 'PWD':
        case 'XPWD':
          await sendReply('257 "/" is current directory');
          break;
        case 'CWD':
        case 'CDUP':
          await sendReply('250 Directory changed');
          break;
        case 'MKD':
        case 'XMKD':
          await sendReply('257 Directory ready');
          break;
        case 'TYPE':
        case 'MODE':
        case 'STRU':
          await sendReply('200 Transfer mode set');
          break;
        case 'PASV':
        case 'EPSV':
          await closePassive();
          passive = new PassiveChannel();
          await passive.start();
          if (command === 'EPSV') {
            await sendReply(
              `229 Entering Extended Passive Mode (|||${PASSIVE_PORT}|)`
            );
          } else {
            const host: string = this.localAddress;
            if (!/^\d+\.\d+\.\d+\.\d+$/.test(host)) {
              await sendReply('425 IPv4 Wi-Fi address required');
              await closePassive();
              break;
            }
            await sendReply(
              `227 Entering Passive Mode (${host.replaceAll('.', ',')},` +
              `${Math.floor(PASSIVE_PORT / 256)},${PASSIVE_PORT % 256})`
            );
          }
          break;
        case 'STOR':
        case 'APPE':
          if (passive === undefined) {
            await sendReply('425 Use PASV first');
            break;
          }
          await sendReply('150 Opening binary connection');
          try {
            const dataConnection: socket.TCPSocketConnection =
              await passive.accept();
            const path: string = await this.receiveData(
              dataConnection,
              argument
            );
            await sendReply('226 Transfer complete');
            this.fileCallback(path);
          } catch (error) {
            await sendReply('451 Transfer failed');
          } finally {
            await closePassive();
          }
          break;
        case 'LIST':
        case 'NLST':
          if (passive === undefined) {
            await sendReply('425 Use PASV first');
            break;
          }
          await sendReply('150 Opening data connection');
          try {
            const listConnection: socket.TCPSocketConnection =
              await passive.accept();
            await listConnection.close();
            await sendReply('226 Directory send OK');
          } finally {
            await closePassive();
          }
          break;
        case 'REST':
          await sendReply('350 Restart position accepted');
          break;
        case 'SIZE':
        case 'MDTM':
          await sendReply('550 File unavailable');
          break;
        case 'PORT':
        case 'EPRT':
          await sendReply('502 Enable PASV mode on camera');
          break;
        default:
          await sendReply('502 Command not implemented');
          break;
      }
    };

    client.on('message', (info: socket.SocketMessageInfo): void => {
      pendingText += decodeUtf8(info.message);
      const lines: Array<string> = pendingText.split('\n');
      pendingText = lines.pop() ?? '';
      lines.forEach((line: string) => {
        commandQueue = commandQueue.then(async (): Promise<void> => {
          try {
            await processLine(line.replaceAll('\r', ''));
          } catch (error) {
            await sendReply('451 Command failed');
          }
        });
      });
    });
    client.on('close', (): void => {
      const index: number = this.clients.indexOf(client);
      if (index >= 0) {
        this.clients.splice(index, 1);
      }
      closePassive();
      if (this.running) {
        this.statusCallback('等待相机无线传输');
      }
    });
    sendReply('220 Nikon Link Wireless Inbox ready').then((): void => {
      this.statusCallback('相机已连接，等待图片');
    });
  }

  private receiveData(
    connection: socket.TCPSocketConnection,
    remoteName: string
  ): Promise<string> {
    const incoming: IncomingPhotoFile =
      this.library.beginReceive(remoteName);
    return new Promise<string>(
      (
        resolve: (path: string) => void,
        reject: (error: Error) => void
      ): void => {
        let total: number = 0;
        let settled: boolean = false;
        connection.on('message', (info: socket.SocketMessageInfo): void => {
          if (settled) {
            return;
          }
          const chunk: Uint8Array = new Uint8Array(info.message);
          total += chunk.length;
          if (total > MAXIMUM_FILE_SIZE) {
            settled = true;
            incoming.abort();
            reject(new Error('无线文件超过 16 GB 限制。'));
            connection.close();
            return;
          }
          try {
            incoming.append(chunk);
          } catch (error) {
            settled = true;
            incoming.abort();
            reject(new Error((error as BusinessError).message));
            connection.close();
          }
        });
        connection.on('error', (error: BusinessError): void => {
          if (!settled) {
            settled = true;
            incoming.abort();
            reject(new Error(error.message));
          }
        });
        connection.on('close', (): void => {
          if (settled) {
            return;
          }
          settled = true;
          if (total === 0) {
            incoming.abort();
            reject(new Error('相机发送了空文件。'));
            return;
          }
          try {
            resolve(incoming.commit());
          } catch (error) {
            incoming.abort();
            reject(new Error((error as BusinessError).message));
          }
        });
      }
    );
  }
}

function decodeUtf8(buffer: ArrayBuffer): string {
  const bytes: Uint8Array = new Uint8Array(buffer);
  let output: string = '';
  for (let index: number = 0; index < bytes.length; index++) {
    const value: number = bytes[index];
    if (value < 0x80) {
      output += String.fromCharCode(value);
    } else if (value < 0xe0 && index + 1 < bytes.length) {
      output += String.fromCharCode(
        ((value & 0x1f) << 6) | (bytes[++index] & 0x3f)
      );
    } else if (index + 2 < bytes.length) {
      output += String.fromCharCode(
        ((value & 0x0f) << 12) |
        ((bytes[++index] & 0x3f) << 6) |
        (bytes[++index] & 0x3f)
      );
    }
  }
  return output;
}

export const FTP_PORT: number = CONTROL_PORT;
