import { fileIo as fs } from '@kit.CoreFileKit';

class AviIndexEntry {
  readonly offset: number;
  readonly size: number;

  constructor(offset: number, size: number) {
    this.offset = offset;
    this.size = size;
  }
}

export class ExternalRecordingResult {
  readonly path: string;
  readonly frames: number;
  readonly bytes: number;

  constructor(path: string, frames: number, bytes: number) {
    this.path = path;
    this.frames = frames;
    this.bytes = bytes;
  }
}

/** Streams PTP JPEG live-view frames into a seekable Motion-JPEG AVI. */
export class ExternalVideoRecorder {
  private target?: string;
  private output?: fs.RandomAccessFile;
  private frameRate: number = 30;
  private width: number = 0;
  private height: number = 0;
  private largestFrame: number = 0;
  private lastFrameAt: number = 0;
  private position: number = 0;
  private index: Array<AviIndexEntry> = [];
  private riffSizeOffset: number = 0;
  private totalFramesOffset: number = 0;
  private streamLengthOffset: number = 0;
  private suggestedBufferOffset: number = 0;
  private streamSuggestedBufferOffset: number = 0;
  private moviSizeOffset: number = 0;
  private moviTypeOffset: number = 0;
  private moviDataOffset: number = 0;

  get isRecording(): boolean {
    return this.target !== undefined;
  }

  start(path: string, frameRate: number): void {
    if (this.isRecording) {
      throw new Error('外录已经开始。');
    }
    this.target = path;
    this.frameRate = Math.max(1, Math.min(120, Math.round(frameRate)));
    this.width = 0;
    this.height = 0;
    this.largestFrame = 0;
    this.lastFrameAt = 0;
    this.position = 0;
    this.index = [];
  }

  appendJpeg(jpeg: Uint8Array): void {
    if (!this.isRecording || jpeg.byteLength === 0) {
      return;
    }
    const now: number = Date.now();
    if (
      this.lastFrameAt > 0 &&
      now - this.lastFrameAt < 1000 / this.frameRate
    ) {
      return;
    }
    if (this.output === undefined) {
      const dimensions: Array<number> = jpegDimensions(jpeg);
      this.width = dimensions[0];
      this.height = dimensions[1];
      this.output = fs.createRandomAccessFileSync(
        this.target as string,
        fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE | fs.OpenMode.TRUNC
      );
      this.writeHeader();
    }
    const chunkOffset: number = this.position;
    this.writeAscii('00dc');
    this.writeInt32(jpeg.byteLength);
    this.write(jpeg);
    if (jpeg.byteLength % 2 !== 0) {
      this.write(new Uint8Array([0]));
    }
    this.index.push(
      new AviIndexEntry(
        chunkOffset - this.moviTypeOffset,
        jpeg.byteLength
      )
    );
    this.largestFrame = Math.max(this.largestFrame, jpeg.byteLength);
    this.lastFrameAt = now;
  }

  stopIfRecording(): ExternalRecordingResult | undefined {
    return this.isRecording ? this.stop() : undefined;
  }

  stop(): ExternalRecordingResult {
    if (this.target === undefined) {
      throw new Error('外录尚未开始。');
    }
    const finished: string = this.target;
    this.target = undefined;
    if (this.output === undefined || this.index.length === 0) {
      this.closeOutput();
      if (fs.accessSync(finished)) {
        fs.unlinkSync(finished);
      }
      throw new Error('没有收到可写入的实时取景帧。');
    }
    const frames: number = this.index.length;
    const indexStart: number = this.position;
    this.writeAscii('idx1');
    this.writeInt32(frames * 16);
    this.index.forEach((entry: AviIndexEntry): void => {
      this.writeAscii('00dc');
      this.writeInt32(0x10);
      this.writeInt32(entry.offset);
      this.writeInt32(entry.size);
    });
    const fileLength: number = this.position;
    this.patchInt32(this.riffSizeOffset, fileLength - 8);
    this.patchInt32(this.totalFramesOffset, frames);
    this.patchInt32(this.streamLengthOffset, frames);
    this.patchInt32(this.suggestedBufferOffset, this.largestFrame);
    this.patchInt32(
      this.streamSuggestedBufferOffset,
      this.largestFrame
    );
    this.patchInt32(
      this.moviSizeOffset,
      4 + indexStart - this.moviDataOffset
    );
    fs.fsyncSync(this.output.fd);
    this.closeOutput();
    this.index = [];
    return new ExternalRecordingResult(finished, frames, fileLength);
  }

  abort(): void {
    const abandoned: string | undefined = this.target;
    this.target = undefined;
    this.closeOutput();
    this.index = [];
    if (abandoned !== undefined && fs.accessSync(abandoned)) {
      fs.unlinkSync(abandoned);
    }
  }

  private writeHeader(): void {
    this.writeAscii('RIFF');
    this.riffSizeOffset = this.position;
    this.writeInt32(0);
    this.writeAscii('AVI ');
    this.writeAscii('LIST');
    const hdrlSizeOffset: number = this.position;
    this.writeInt32(0);
    this.writeAscii('hdrl');
    const hdrlDataOffset: number = this.position;

    this.writeAscii('avih');
    this.writeInt32(56);
    this.writeInt32(Math.floor(1000000 / this.frameRate));
    this.writeInt32(0); this.writeInt32(0); this.writeInt32(0x10);
    this.totalFramesOffset = this.position;
    this.writeInt32(0);
    this.writeInt32(0); this.writeInt32(1);
    this.suggestedBufferOffset = this.position;
    this.writeInt32(0);
    this.writeInt32(this.width); this.writeInt32(this.height);
    this.writeInt32(0); this.writeInt32(0);
    this.writeInt32(0); this.writeInt32(0);

    this.writeAscii('LIST');
    const strlSizeOffset: number = this.position;
    this.writeInt32(0);
    this.writeAscii('strl');
    const strlDataOffset: number = this.position;
    this.writeAscii('strh');
    this.writeInt32(56);
    this.writeAscii('vids'); this.writeAscii('MJPG');
    this.writeInt32(0); this.writeInt16(0); this.writeInt16(0);
    this.writeInt32(0); this.writeInt32(1);
    this.writeInt32(this.frameRate); this.writeInt32(0);
    this.streamLengthOffset = this.position;
    this.writeInt32(0);
    this.streamSuggestedBufferOffset = this.position;
    this.writeInt32(0);
    this.writeInt32(0xffffffff); this.writeInt32(0);
    this.writeInt16(0); this.writeInt16(0);
    this.writeInt16(this.width); this.writeInt16(this.height);

    this.writeAscii('strf');
    this.writeInt32(40); this.writeInt32(40);
    this.writeInt32(this.width); this.writeInt32(this.height);
    this.writeInt16(1); this.writeInt16(24); this.writeAscii('MJPG');
    this.writeInt32(this.width * this.height * 3);
    this.writeInt32(0); this.writeInt32(0);
    this.writeInt32(0); this.writeInt32(0);
    const headerEnd: number = this.position;
    this.patchInt32(
      strlSizeOffset,
      headerEnd - strlDataOffset + 4
    );
    this.patchInt32(
      hdrlSizeOffset,
      headerEnd - hdrlDataOffset + 4
    );
    this.position = headerEnd;
    this.writeAscii('LIST');
    this.moviSizeOffset = this.position;
    this.writeInt32(0);
    this.moviTypeOffset = this.position;
    this.writeAscii('movi');
    this.moviDataOffset = this.position;
  }

  private patchInt32(offset: number, value: number): void {
    const current: number = this.position;
    this.position = offset;
    this.writeInt32(value);
    this.position = current;
  }

  private writeAscii(value: string): void {
    const bytes: Uint8Array = new Uint8Array(value.length);
    for (let index: number = 0; index < value.length; index++) {
      bytes[index] = value.charCodeAt(index) & 0xff;
    }
    this.write(bytes);
  }

  private writeInt16(value: number): void {
    this.write(new Uint8Array([
      value & 0xff,
      value >>> 8 & 0xff
    ]));
  }

  private writeInt32(value: number): void {
    this.write(new Uint8Array([
      value & 0xff,
      value >>> 8 & 0xff,
      value >>> 16 & 0xff,
      value >>> 24 & 0xff
    ]));
  }

  private write(bytes: Uint8Array): void {
    if (this.output === undefined) {
      throw new Error('外录文件尚未打开。');
    }
    this.output.setFilePointer(this.position);
    let offset: number = 0;
    while (offset < bytes.byteLength) {
      const remaining: Uint8Array = bytes.slice(offset);
      const count: number = this.output.writeSync(remaining.buffer);
      if (count <= 0) {
        throw new Error('无法继续写入外录文件。');
      }
      offset += count;
      this.position += count;
    }
  }

  private closeOutput(): void {
    if (this.output !== undefined) {
      try {
        this.output.close();
      } catch (error) {
      }
      this.output = undefined;
    }
  }
}

function jpegDimensions(jpeg: Uint8Array): Array<number> {
  if (
    jpeg.byteLength < 4 ||
    jpeg[0] !== 0xff ||
    jpeg[1] !== 0xd8
  ) {
    throw new Error('实时取景帧不是有效 JPEG。');
  }
  let offset: number = 2;
  while (offset + 8 < jpeg.byteLength) {
    while (offset < jpeg.byteLength && jpeg[offset] !== 0xff) offset++;
    while (offset < jpeg.byteLength && jpeg[offset] === 0xff) offset++;
    if (offset >= jpeg.byteLength) break;
    const marker: number = jpeg[offset++];
    if (marker === 0xd8 || marker === 0xd9) continue;
    if (offset + 1 >= jpeg.byteLength) break;
    const length: number = jpeg[offset] << 8 | jpeg[offset + 1];
    if (length < 2 || offset + length > jpeg.byteLength) break;
    const sof: boolean =
      (marker >= 0xc0 && marker <= 0xc3) ||
      (marker >= 0xc5 && marker <= 0xc7) ||
      (marker >= 0xc9 && marker <= 0xcb) ||
      (marker >= 0xcd && marker <= 0xcf);
    if (sof) {
      const height: number = jpeg[offset + 3] << 8 | jpeg[offset + 4];
      const width: number = jpeg[offset + 5] << 8 | jpeg[offset + 6];
      if (width > 0 && height > 0) return [width, height];
    }
    offset += length;
  }
  throw new Error('无法读取实时取景 JPEG 尺寸。');
}
