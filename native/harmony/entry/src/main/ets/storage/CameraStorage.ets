export class CameraStorageVolume {
  readonly id: number;
  readonly name: string;
  readonly capacityBytes: number;
  readonly freeBytes: number;
  readonly freeImages: number;
  readonly readOnly: boolean;

  constructor(
    id: number,
    name: string,
    capacityBytes: number,
    freeBytes: number,
    freeImages: number,
    readOnly: boolean
  ) {
    this.id = id;
    this.name = name;
    this.capacityBytes = capacityBytes;
    this.freeBytes = freeBytes;
    this.freeImages = freeImages;
    this.readOnly = readOnly;
  }
}

export class CameraStorageItem {
  readonly handle: number;
  readonly storageId: number;
  readonly format: number;
  readonly filename: string;
  readonly sizeBytes: number;
  readonly width: number;
  readonly height: number;
  readonly capturedAt: string;
  readonly protectedObject: boolean;

  constructor(
    handle: number,
    storageId: number,
    format: number,
    filename: string,
    sizeBytes: number,
    width: number,
    height: number,
    capturedAt: string,
    protectedObject: boolean
  ) {
    this.handle = handle;
    this.storageId = storageId;
    this.format = format;
    this.filename = filename;
    this.sizeBytes = sizeBytes;
    this.width = width;
    this.height = height;
    this.capturedAt = capturedAt;
    this.protectedObject = protectedObject;
  }

  get isVideo(): boolean {
    const lower: string = this.filename.toLowerCase();
    return lower.endsWith('.mov') || lower.endsWith('.mp4')
      || lower.endsWith('.avi') || lower.endsWith('.m4v')
      || lower.endsWith('.mts') || lower.endsWith('.m2ts');
  }
}

export class CameraStorageSnapshot {
  readonly volumes: Array<CameraStorageVolume>;
  readonly items: Array<CameraStorageItem>;

  constructor(
    volumes: Array<CameraStorageVolume>,
    items: Array<CameraStorageItem>
  ) {
    this.volumes = volumes;
    this.items = items;
  }

  get capacityBytes(): number {
    let result: number = 0;
    this.volumes.forEach((volume: CameraStorageVolume): void => {
      result = Math.min(Number.MAX_SAFE_INTEGER, result + volume.capacityBytes);
    });
    return result;
  }

  get freeBytes(): number {
    let result: number = 0;
    this.volumes.forEach((volume: CameraStorageVolume): void => {
      result = Math.min(Number.MAX_SAFE_INTEGER, result + volume.freeBytes);
    });
    return result;
  }
}

class ParsedString {
  readonly value: string;
  readonly nextOffset: number;

  constructor(value: string, nextOffset: number) {
    this.value = value;
    this.nextOffset = nextOffset;
  }
}

export function parseStorageIds(data: Uint8Array): Array<number> {
  if (data.length < 4) {
    return [];
  }
  const count: number = Math.min(readU32(data, 0), Math.floor((data.length - 4) / 4));
  const result: Array<number> = [];
  for (let index: number = 0; index < count; index++) {
    result.push(readU32(data, 4 + index * 4));
  }
  return result;
}

export function parseStorageInfo(
  storageId: number,
  data: Uint8Array
): CameraStorageVolume {
  if (data.length < 26) {
    return new CameraStorageVolume(storageId, storageLabel(storageId), 0, 0, 0, false);
  }
  const accessCapability: number = readU16(data, 4);
  const capacity: number = readU64(data, 6);
  const free: number = readU64(data, 14);
  const freeImages: number = readU32(data, 22);
  const description: ParsedString = readPtpString(data, 26);
  const label: ParsedString = readPtpString(data, description.nextOffset);
  const name: string = label.value.length > 0
    ? label.value
    : description.value.length > 0 ? description.value : storageLabel(storageId);
  return new CameraStorageVolume(
    storageId,
    name,
    capacity,
    free,
    freeImages,
    accessCapability !== 0
  );
}

export function parseObjectInfo(
  handle: number,
  data: Uint8Array
): CameraStorageItem | undefined {
  if (data.length < 52) {
    return undefined;
  }
  const associationType: number = readU16(data, 42);
  const filename: ParsedString = readPtpString(data, 52);
  if (associationType !== 0 || filename.value.length === 0) {
    return undefined;
  }
  const capturedAt: ParsedString = readPtpString(data, filename.nextOffset);
  return new CameraStorageItem(
    handle,
    readU32(data, 0),
    readU16(data, 4),
    filename.value,
    readU32(data, 8),
    readU32(data, 26),
    readU32(data, 30),
    displayDate(capturedAt.value),
    readU16(data, 6) !== 0
  );
}

export function isObjectAssociation(data: Uint8Array): boolean {
  return data.length >= 52 && readU16(data, 42) !== 0;
}

function readPtpString(data: Uint8Array, offset: number): ParsedString {
  if (offset < 0 || offset >= data.length) {
    return new ParsedString('', data.length);
  }
  const count: number = data[offset];
  if (count === 0) {
    return new ParsedString('', offset + 1);
  }
  let value: string = '';
  const payloadCount: number = Math.max(0, count - 1);
  for (let index: number = 0; index < payloadCount; index++) {
    const charOffset: number = offset + 1 + index * 2;
    if (charOffset + 1 >= data.length) {
      break;
    }
    value += String.fromCharCode(readU16(data, charOffset));
  }
  return new ParsedString(
    value,
    Math.min(data.length, offset + 1 + count * 2)
  );
}

function displayDate(value: string): string {
  if (value.length < 8) {
    return '—';
  }
  let result: string = `${value.slice(0, 4)}-${value.slice(4, 6)}-${value.slice(6, 8)}`;
  if (value.length >= 15 && value.charAt(8) === 'T') {
    result += ` ${value.slice(9, 11)}:${value.slice(11, 13)}:${value.slice(13, 15)}`;
  }
  return result;
}

function storageLabel(id: number): string {
  return `存储卡 ${id.toString(16).toUpperCase().padStart(8, '0')}`;
}

function readU16(bytes: Uint8Array, offset: number): number {
  if (offset < 0 || offset + 2 > bytes.length) {
    return 0;
  }
  return bytes[offset] | (bytes[offset + 1] << 8);
}

function readU32(bytes: Uint8Array, offset: number): number {
  if (offset < 0 || offset + 4 > bytes.length) {
    return 0;
  }
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
