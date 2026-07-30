import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { fileIo as fs } from '@kit.CoreFileKit';

export class CaptureSessionConfiguration {
  name: string = '未命名会话';
  namingTemplate: string = '{session}_{date}_{counter}';
  creator: string = '';
  rights: string = '';
  rating: number = 0;
  dualBackupEnabled: boolean = true;
}

interface PersistedWorkflow {
  configuration: CaptureSessionConfiguration;
  active: boolean;
  counter: number;
}

export class CaptureWorkflow {
  private readonly rootDirectory: string;
  private readonly statePath: string;
  private configurationValue: CaptureSessionConfiguration =
    new CaptureSessionConfiguration();
  private activeValue: boolean = false;
  private counterValue: number = 1;
  private statusValue: string = '尚未开始拍摄会话';

  constructor(rootDirectory: string) {
    this.rootDirectory = rootDirectory;
    this.statePath = `${rootDirectory}/.capture-session.json`;
    this.load();
  }

  get configuration(): CaptureSessionConfiguration {
    const copy: CaptureSessionConfiguration =
      new CaptureSessionConfiguration();
    copy.name = this.configurationValue.name;
    copy.namingTemplate = this.configurationValue.namingTemplate;
    copy.creator = this.configurationValue.creator;
    copy.rights = this.configurationValue.rights;
    copy.rating = this.configurationValue.rating;
    copy.dualBackupEnabled = this.configurationValue.dualBackupEnabled;
    return copy;
  }

  get isActive(): boolean {
    return this.activeValue;
  }

  get status(): string {
    return this.statusValue;
  }

  begin(requested: CaptureSessionConfiguration): void {
    this.configurationValue = this.normalize(requested);
    this.activeValue = true;
    this.counterValue = 1;
    this.ensureDirectories();
    this.persist();
    this.statusValue = `会话进行中 · ${this.configurationValue.name}`;
  }

  end(): void {
    this.activeValue = false;
    this.persist();
    this.statusValue = '拍摄会话已结束';
  }

  reserveBaseName(cameraName: string): string {
    const now: Date = new Date();
    const date: string =
      `${now.getFullYear()}${pad(now.getMonth() + 1)}${pad(now.getDate())}_` +
      `${pad(now.getHours())}${pad(now.getMinutes())}${pad(now.getSeconds())}`;
    let value: string = this.configurationValue.namingTemplate
      .replaceAll('{session}', this.configurationValue.name)
      .replaceAll('{date}', date)
      .replaceAll('{counter}', String(this.counterValue).padStart(4, '0'))
      .replaceAll('{camera}', cameraName);
    this.counterValue++;
    this.persist();
    return sanitize(value);
  }

  async store(
    bytes: Uint8Array,
    originalFilename: string,
    cameraName: string,
    reservedBaseName?: string
  ): Promise<string> {
    this.ensureDirectories();
    const extension: string = fileExtension(originalFilename);
    const base: string = reservedBaseName === undefined
      ? this.reserveBaseName(cameraName)
      : sanitize(reservedBaseName);
    const destination: string = this.uniquePath(
      this.primaryDirectory(),
      base,
      extension
    );
    writeBytes(destination, bytes);
    await this.finalize(destination);
    this.statusValue =
      `已写入会话 · ${destination.substring(destination.lastIndexOf('/') + 1)}`;
    return destination;
  }

  async importFromUri(
    uri: string,
    originalFilename: string,
    cameraName: string,
    reservedBaseName?: string
  ): Promise<string> {
    const source: fs.File = fs.openSync(uri, fs.OpenMode.READ_ONLY);
    try {
      const stat: fs.Stat = fs.statSync(source.fd);
      const buffer: ArrayBuffer = new ArrayBuffer(stat.size);
      fs.readSync(source.fd, buffer);
      return await this.store(
        new Uint8Array(buffer),
        originalFilename,
        cameraName,
        reservedBaseName
      );
    } finally {
      fs.closeSync(source);
    }
  }

  private async finalize(primary: string): Promise<void> {
    if (!this.activeValue) {
      return;
    }
    const bytes: Uint8Array = readBytes(primary);
    const md = cryptoFramework.createMd('SHA256');
    await md.update({ data: bytes });
    const digest = await md.digest();
    const checksum: string = Array.from(digest.data)
      .map((value: number): string => value.toString(16).padStart(2, '0'))
      .join('');
    const sidecar: string = `${withoutExtension(primary)}.xmp`;
    writeText(sidecar, this.xmp(filename(primary)));
    const backupDirectory: string | undefined = this.backupDirectory();
    if (backupDirectory !== undefined) {
      fs.copyFileSync(primary, `${backupDirectory}/${filename(primary)}`);
      fs.copyFileSync(sidecar, `${backupDirectory}/${filename(sidecar)}`);
    }
    const manifest: string = `${this.sessionRoot()}/checksums.sha256`;
    const previous: string = fs.accessSync(manifest)
      ? fs.readTextSync(manifest)
      : '';
    writeText(
      manifest,
      `${previous}${checksum}  Primary/${filename(primary)}\n`
    );
  }

  private primaryDirectory(): string {
    return this.activeValue
      ? `${this.sessionRoot()}/Primary`
      : this.rootDirectory;
  }

  private backupDirectory(): string | undefined {
    return this.activeValue && this.configurationValue.dualBackupEnabled
      ? `${this.sessionRoot()}/Backup`
      : undefined;
  }

  private sessionRoot(): string {
    return `${this.rootDirectory}/Sessions/${sanitize(
      this.configurationValue.name
    )}`;
  }

  private ensureDirectories(): void {
    ensureDirectory(this.rootDirectory);
    if (!this.activeValue) {
      return;
    }
    ensureDirectory(`${this.rootDirectory}/Sessions`);
    ensureDirectory(this.sessionRoot());
    ensureDirectory(this.primaryDirectory());
    const backup: string | undefined = this.backupDirectory();
    if (backup !== undefined) {
      ensureDirectory(backup);
    }
  }

  private load(): void {
    if (!fs.accessSync(this.statePath)) {
      return;
    }
    try {
      const saved: PersistedWorkflow =
        JSON.parse(fs.readTextSync(this.statePath)) as PersistedWorkflow;
      this.configurationValue = this.normalize(saved.configuration);
      this.activeValue = saved.active;
      this.counterValue = Math.max(1, saved.counter);
      if (this.activeValue) {
        this.ensureDirectories();
        this.statusValue =
          `会话进行中 · ${this.configurationValue.name}`;
      }
    } catch (error) {
      this.activeValue = false;
    }
  }

  private persist(): void {
    const state: PersistedWorkflow = {
      configuration: this.configurationValue,
      active: this.activeValue,
      counter: this.counterValue
    };
    writeText(this.statePath, JSON.stringify(state, undefined, 2));
  }

  private normalize(
    value: CaptureSessionConfiguration
  ): CaptureSessionConfiguration {
    const result: CaptureSessionConfiguration =
      new CaptureSessionConfiguration();
    result.name = value.name.trim().length === 0
      ? '未命名会话'
      : value.name.trim();
    result.namingTemplate = value.namingTemplate.trim().length === 0
      ? '{session}_{date}_{counter}'
      : value.namingTemplate.trim();
    if (!result.namingTemplate.includes('{counter}')) {
      result.namingTemplate += '_{counter}';
    }
    result.creator = value.creator.trim();
    result.rights = value.rights.trim();
    result.rating = Math.max(0, Math.min(5, value.rating));
    result.dualBackupEnabled = value.dualBackupEnabled;
    return result;
  }

  private uniquePath(
    directory: string,
    base: string,
    extension: string
  ): string {
    let result: string = `${directory}/${base}.${extension}`;
    let suffix: number = 2;
    while (fs.accessSync(result)) {
      result = `${directory}/${base}_${suffix}.${extension}`;
      suffix++;
    }
    return result;
  }

  private xmp(mediaName: string): string {
    return `<?xpacket begin="" id="W5M0MpCehiHzreSzNTczkc9d"?>\n` +
      `<x:xmpmeta xmlns:x="adobe:ns:meta/"><rdf:RDF ` +
      `xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">` +
      `<rdf:Description rdf:about="" ` +
      `xmlns:xmp="http://ns.adobe.com/xap/1.0/" ` +
      `xmlns:dc="http://purl.org/dc/elements/1.1/" ` +
      `xmp:Rating="${this.configurationValue.rating}">` +
      `<dc:title><rdf:Alt><rdf:li xml:lang="x-default">` +
      `${xml(this.configurationValue.name)}</rdf:li></rdf:Alt></dc:title>` +
      `<dc:creator><rdf:Seq><rdf:li>` +
      `${xml(this.configurationValue.creator)}</rdf:li></rdf:Seq></dc:creator>` +
      `<dc:rights><rdf:Alt><rdf:li xml:lang="x-default">` +
      `${xml(this.configurationValue.rights)}</rdf:li></rdf:Alt></dc:rights>` +
      `<dc:description><rdf:Alt><rdf:li xml:lang="x-default">` +
      `${xml(mediaName)}</rdf:li></rdf:Alt></dc:description>` +
      `</rdf:Description></rdf:RDF></x:xmpmeta>\n` +
      `<?xpacket end="w"?>`;
  }
}

function ensureDirectory(path: string): void {
  if (!fs.accessSync(path)) {
    fs.mkdirSync(path);
  }
}

function writeBytes(path: string, bytes: Uint8Array): void {
  const file: fs.File = fs.openSync(
    path,
    fs.OpenMode.CREATE |
    fs.OpenMode.READ_WRITE |
    fs.OpenMode.TRUNC
  );
  try {
    fs.writeSync(file.fd, bytes.buffer);
    fs.fsyncSync(file.fd);
  } finally {
    fs.closeSync(file);
  }
}

function writeText(path: string, value: string): void {
  const file: fs.File = fs.openSync(
    path,
    fs.OpenMode.CREATE |
    fs.OpenMode.READ_WRITE |
    fs.OpenMode.TRUNC
  );
  try {
    fs.writeSync(file.fd, value);
    fs.fsyncSync(file.fd);
  } finally {
    fs.closeSync(file);
  }
}

function readBytes(path: string): Uint8Array {
  const file: fs.File = fs.openSync(path, fs.OpenMode.READ_ONLY);
  try {
    const stat: fs.Stat = fs.statSync(file.fd);
    const buffer: ArrayBuffer = new ArrayBuffer(stat.size);
    fs.readSync(file.fd, buffer);
    return new Uint8Array(buffer);
  } finally {
    fs.closeSync(file);
  }
}

function fileExtension(value: string): string {
  const dot: number = value.lastIndexOf('.');
  const extension: string = dot >= 0 ? value.substring(dot + 1) : 'jpg';
  const safe: string = extension.replace(/[^A-Za-z0-9]/g, '').toLowerCase();
  return safe.length === 0 ? 'jpg' : safe;
}

function filename(path: string): string {
  return path.substring(path.lastIndexOf('/') + 1);
}

function withoutExtension(path: string): string {
  const dot: number = path.lastIndexOf('.');
  return dot > path.lastIndexOf('/') ? path.substring(0, dot) : path;
}

function sanitize(value: string): string {
  let result: string = value.replace(/[\\/:?%*|"<>]/g, '_').trim();
  if (result.length === 0) {
    result = 'ZENCHE';
  }
  return result.length > 120 ? result.substring(0, 120) : result;
}

function xml(value: string): string {
  return value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&apos;');
}

function pad(value: number): string {
  return String(value).padStart(2, '0');
}
