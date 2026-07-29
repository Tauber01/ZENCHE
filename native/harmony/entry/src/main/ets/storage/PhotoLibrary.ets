import { common } from '@kit.AbilityKit';
import { fileIo as fs } from '@kit.CoreFileKit';

const SUPPORTED_EXTENSIONS: Array<string> = [
  '.jpg',
  '.jpeg',
  '.nef',
  '.nrw',
  '.heif',
  '.heic',
  '.tif',
  '.tiff'
];

export class PhotoItem {
  readonly name: string;
  readonly path: string;
  readonly size: number;
  readonly modifiedAt: number;

  constructor(name: string, path: string, size: number, modifiedAt: number) {
    this.name = name;
    this.path = path;
    this.size = size;
    this.modifiedAt = modifiedAt;
  }

  get detail(): string {
    const date: Date = new Date(this.modifiedAt);
    return `${formatBytes(this.size)} · ${date.getFullYear()}-${pad(
      date.getMonth() + 1
    )}-${pad(date.getDate())} ${pad(date.getHours())}:${pad(
      date.getMinutes()
    )}`;
  }
}

export class IncomingPhotoFile {
  readonly destination: string;
  private temporaryPath: string;
  private file?: fs.File;
  private written: number = 0;

  constructor(destination: string) {
    this.destination = destination;
    this.temporaryPath = `${destination}.${Date.now()}.part`;
    this.file = fs.openSync(
      this.temporaryPath,
      fs.OpenMode.CREATE |
      fs.OpenMode.READ_WRITE |
      fs.OpenMode.TRUNC
    );
  }

  get length(): number {
    return this.written;
  }

  append(bytes: Uint8Array): void {
    if (this.file === undefined) {
      throw new Error('无线接收文件已经关闭。');
    }
    let offset: number = 0;
    while (offset < bytes.length) {
      const remaining: Uint8Array = bytes.slice(offset);
      const count: number = fs.writeSync(this.file.fd, remaining.buffer);
      if (count <= 0) {
        throw new Error('无法继续写入无线接收文件。');
      }
      offset += count;
      this.written += count;
    }
  }

  commit(): string {
    if (this.file === undefined) {
      throw new Error('无线接收文件已经关闭。');
    }
    if (this.written === 0) {
      this.abort();
      throw new Error('相机发送了空文件。');
    }
    fs.fsyncSync(this.file.fd);
    fs.closeSync(this.file);
    this.file = undefined;
    fs.renameSync(this.temporaryPath, this.destination);
    return this.destination;
  }

  abort(): void {
    if (this.file !== undefined) {
      try {
        fs.closeSync(this.file);
      } catch (error) {
      }
      this.file = undefined;
    }
    if (fs.accessSync(this.temporaryPath)) {
      try {
        fs.unlinkSync(this.temporaryPath);
      } catch (error) {
      }
    }
  }
}

export class PhotoLibrary {
  readonly directoryPath: string;

  constructor(context: common.UIAbilityContext) {
    this.directoryPath = `${context.filesDir}/photos`;
    this.ensureDirectory();
  }

  list(): Array<PhotoItem> {
    this.ensureDirectory();
    const items: Array<PhotoItem> = [];
    const names: Array<string> = fs.listFileSync(this.directoryPath);
    names.forEach((name: string) => {
      const lower: string = name.toLowerCase();
      const supported: boolean = SUPPORTED_EXTENSIONS.some(
        (extension: string) => lower.endsWith(extension)
      );
      if (!supported) {
        return;
      }
      const path: string = `${this.directoryPath}/${name}`;
      const stat: fs.Stat = fs.statSync(path);
      items.push(new PhotoItem(name, path, stat.size, stat.mtime));
    });
    return items.sort((left: PhotoItem, right: PhotoItem) =>
      right.modifiedAt - left.modifiedAt
    );
  }

  saveCapture(jpeg: Uint8Array): string {
    const now: Date = new Date();
    const filename: string =
      `NIKON_${now.getFullYear()}${pad(now.getMonth() + 1)}${pad(
        now.getDate()
      )}_${pad(now.getHours())}${pad(now.getMinutes())}${pad(
        now.getSeconds()
      )}_${String(now.getMilliseconds()).padStart(3, '0')}.JPG`;
    return this.saveReceived(filename, jpeg);
  }

  saveReceived(remoteName: string, bytes: Uint8Array): string {
    const incoming: IncomingPhotoFile = this.beginReceive(remoteName);
    try {
      incoming.append(bytes);
      return incoming.commit();
    } catch (error) {
      incoming.abort();
      throw error;
    }
  }

  beginReceive(remoteName: string): IncomingPhotoFile {
    this.ensureDirectory();
    const filename: string = this.safeFilename(remoteName);
    return new IncomingPhotoFile(this.uniqueDestination(filename));
  }

  remove(item: PhotoItem): void {
    fs.unlinkSync(item.path);
  }

  read(item: PhotoItem): Uint8Array {
    const file: fs.File = fs.openSync(item.path, fs.OpenMode.READ_ONLY);
    try {
      const stat: fs.Stat = fs.statSync(item.path);
      const buffer: ArrayBuffer = new ArrayBuffer(stat.size);
      fs.readSync(file.fd, buffer);
      return new Uint8Array(buffer);
    } finally {
      fs.closeSync(file);
    }
  }

  private uniqueDestination(filename: string): string {
    const initial: string = `${this.directoryPath}/${filename}`;
    if (!fs.accessSync(initial)) {
      return initial;
    }
    const dot: number = filename.lastIndexOf('.');
    const stem: string = dot > 0 ? filename.substring(0, dot) : filename;
    const extension: string = dot > 0 ? filename.substring(dot) : '';
    return `${this.directoryPath}/${stem}_${Date.now()}${extension}`;
  }

  private safeFilename(remoteName: string): string {
    const normalized: string = remoteName
      .replaceAll('\\', '/')
      .replaceAll('\0', '_');
    const segments: Array<string> = normalized.split('/');
    const source: string = segments[segments.length - 1].trim();
    const cleaned: string = source.replace(/[<>:"|?*]/g, '_');
    return cleaned.length === 0 || cleaned === '.' || cleaned === '..'
      ? `NIKON_${Date.now()}.JPG`
      : cleaned;
  }

  private ensureDirectory(): void {
    if (!fs.accessSync(this.directoryPath)) {
      fs.mkdirSync(this.directoryPath);
    }
  }
}

function pad(value: number): string {
  return String(value).padStart(2, '0');
}

function formatBytes(bytes: number): string {
  if (bytes <= 0) {
    return '0 B';
  }
  const units: Array<string> = ['B', 'KB', 'MB', 'GB'];
  let value: number = bytes;
  let index: number = 0;
  while (value >= 1024 && index < units.length - 1) {
    value /= 1024;
    index++;
  }
  return `${value.toFixed(index === 0 ? 0 : 1)} ${units[index]}`;
}
