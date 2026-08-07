import { ExternalVideoRecorder, ExternalRecordingResult } from './ExternalVideoRecorder';

class LivePhotoRingFrame {
  readonly jpeg: Uint8Array;
  readonly timestamp: number;

  constructor(jpeg: Uint8Array, timestamp: number) {
    this.jpeg = jpeg;
    this.timestamp = timestamp;
  }
}

/** 内存环形取景帧缓冲 + 快门切片（E5 live 图，路线 B）：
 *  取景开启时常开入环（只保留最近 maxSeconds 帧），快门触发时把
 *  最近 N 秒帧写为 Motion-JPEG AVI，与照片共用 reservedBaseName 配对入库。
 *  TBC-awaiting-hardware（实机取景帧率/码率待验证）。 */
export class LivePhotoClipRecorder {
  private armedValue: boolean = false;
  private ring: Array<LivePhotoRingFrame> = [];
  private frameRateValue: number = 10;
  private maxSecondsValue: number = 3.0;
  private lastAppendAt: number = 0;

  get isArmed(): boolean {
    return this.armedValue;
  }

  arm(frameRate: number, maxSeconds: number): void {
    this.armedValue = true;
    this.frameRateValue = Math.max(1, Math.min(120, Math.round(frameRate)));
    this.maxSecondsValue = Math.max(0.5, Math.min(30, maxSeconds));
    this.ring = [];
    this.lastAppendAt = 0;
  }

  disarm(): void {
    this.armedValue = false;
    this.ring = [];
    this.lastAppendAt = 0;
  }

  /** 按帧率节流入环；超过 maxSeconds 的旧帧被淘汰。 */
  append(jpeg: Uint8Array): void {
    if (!this.armedValue || jpeg.byteLength === 0) {
      return;
    }
    const now: number = Date.now();
    if (
      this.lastAppendAt > 0 &&
      now - this.lastAppendAt < 1000 / this.frameRateValue
    ) {
      return;
    }
    this.lastAppendAt = now;
    this.ring.push(new LivePhotoRingFrame(jpeg, now));
    const cutoff: number = now - this.maxSecondsValue * 1000;
    while (this.ring.length > 0 && this.ring[0].timestamp < cutoff) {
      this.ring.shift();
    }
  }

  /** 把最近 maxSeconds 帧写为 AVI 切片；环为空返回 undefined。
   *  复用 ExternalVideoRecorder 的 AVI 写入逻辑（字节级同构五端）。 */
  captureSlice(target: string): ExternalRecordingResult | undefined {
    if (!this.armedValue || this.ring.length === 0) {
      return undefined;
    }
    const frames: Array<Uint8Array> = this.ring.map(
      (frame: LivePhotoRingFrame): Uint8Array => frame.jpeg
    );
    const recorder: ExternalVideoRecorder = new ExternalVideoRecorder();
    try {
      recorder.start(target, this.frameRateValue);
      frames.forEach((frame: Uint8Array): void => {
        // throttle=false：切片回放帧为内存已有帧，快速写入不得被
        // 实时取景的帧率节流丢弃（否则 AVI 只剩第一帧）。
        recorder.appendJpeg(frame, false);
      });
      return recorder.stopIfRecording();
    } catch (error) {
      recorder.abort();
      throw new Error(
        error instanceof Error ? error.message : String(error)
      );
    }
  }
}
