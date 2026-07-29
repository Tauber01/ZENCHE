import { PhotoLibrary } from '../storage/PhotoLibrary';
import {
  FTP_PORT,
  WirelessFtpServer
} from './WirelessFtpServer';
import {
  HTTP_PORT,
  WirelessHttpServer
} from './WirelessHttpServer';

export type WirelessStatusCallback = (status: string) => void;
export type WirelessFileCallback = (path: string) => void;

export class WirelessTransferServer {
  private ftp: WirelessFtpServer;
  private http: WirelessHttpServer;
  private statusCallback: WirelessStatusCallback;
  private running: boolean = false;

  constructor(
    library: PhotoLibrary,
    statusCallback: WirelessStatusCallback,
    fileCallback: WirelessFileCallback
  ) {
    this.statusCallback = statusCallback;
    this.ftp = new WirelessFtpServer(
      library,
      (status: string): void => this.publishStatus(status),
      fileCallback
    );
    this.http = new WirelessHttpServer(
      library,
      (status: string): void => this.publishStatus(status),
      fileCallback
    );
  }

  get isRunning(): boolean {
    return this.running;
  }

  get localAddress(): string {
    return this.ftp.localAddress;
  }

  async start(): Promise<void> {
    if (this.running) {
      return;
    }
    await this.ftp.start();
    try {
      await this.http.start();
    } catch (error) {
      await this.ftp.stop();
      throw new Error(
        error instanceof Error
          ? error.message
          : 'HTTP / WebDAV 无线接收启动失败。'
      );
    }
    this.running = true;
    this.statusCallback('等待 FTP / HTTP / WebDAV 图片');
  }

  async stop(): Promise<void> {
    this.running = false;
    await this.http.stop();
    await this.ftp.stop();
    this.statusCallback('无线收件箱未开启');
  }

  private publishStatus(status: string): void {
    if (
      status === '等待相机无线传输' ||
      status === '无线收件箱未开启'
    ) {
      if (this.running) {
        this.statusCallback('等待 FTP / HTTP / WebDAV 图片');
      }
      return;
    }
    this.statusCallback(status);
  }
}

export { FTP_PORT, HTTP_PORT };
