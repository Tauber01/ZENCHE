import { image } from '@kit.ImageKit';
import timelapse from 'libtimelapse.so';

/** E6 延时合成结果：写入路径 + 写入帧数 + 跳过损坏帧数。 */
export class TimelapseComposerResult {
  readonly path: string;
  readonly framesWritten: number;
  readonly skippedFrames: number;

  constructor(path: string, framesWritten: number, skippedFrames: number) {
    this.path = path;
    this.framesWritten = framesWritten;
    this.skippedFrames = skippedFrames;
  }
}

/** E6 延时合成：把序列帧（JPEG/PNG/HEIC/TIFF）按帧率编码为 H.264 MP4。
 *  Harmony 段走 native C++（libtimelapse.so）：API 21 下 ArkTS 低级编解码
 *  API（media.VideoEncoder/AVMuxer）已移除，native OH_VideoEncoder +
 *  OH_AVMuxer（@since 9-11）为唯一可行路径，与其他四端高级 API 方案不同。
 *  ArkTS 侧保留 image 解码 → aspect-fit 黑底画布 → RGBA→NV12（BT.601 全范围），
 *  编码/封装委托 native：createEncoder / feedFrame / finishEncoder / destroyEncoder。
 *  损坏帧跳过并计数，不整批失败；进度回调 + 取消检查。
 *  TBC-awaiting-hardware（编码器 buffer 模式行为依赖系统，需实机验证）。 */
export class TimelapseComposer {
  /**
   * 逐帧合成。isCancelled 返回 true 时中止并抛 Error('已取消')；
   * onProgress 报告 (已处理帧数, 总帧数)。
   */
  async compose(
    frames: Array<string>,
    outputPath: string,
    frameRate: number,
    isCancelled: () => boolean,
    onProgress?: (done: number, total: number) => void
  ): Promise<TimelapseComposerResult> {
    if (frames.length === 0) {
      throw new Error('请至少选择一帧。');
    }
    const fps: number = Math.max(1, Math.min(60, Math.round(frameRate)));

    // 首帧尺寸作为统一画布（延时连拍帧同尺寸；异尺寸按 aspect-fit 黑底绘制）。
    // YUV420 采样要求偶数宽高，奇数对齐到偶数。
    const canvas: Array<number> | undefined = await this.firstFrameSize(frames);
    if (canvas === undefined) {
      throw new Error('所选帧均无法解码，未生成视频。');
    }
    const width: number = Math.max(2, canvas[0] & ~1);
    const height: number = Math.max(2, canvas[1] & ~1);
    const bitRate: number = Math.max(
      1_000_000,
      Math.min(20_000_000, Math.floor(width * height * fps * 0.07))
    );

    let handle: number = 0;
    let skipped: number = 0;
    let ptsUs: number = 0;
    try {
      handle = timelapse.createEncoder(width, height, fps, bitRate, outputPath);
      if (handle < 0) {
        throw new Error('编码器初始化失败（错误码 ' + handle + '）。');
      }
      for (let index: number = 0; index < frames.length; index++) {
        if (isCancelled()) {
          throw new Error('已取消');
        }
        const nv12: Uint8Array | undefined = await this.decodeFrameToNv12(
          frames[index],
          width,
          height
        );
        if (nv12 === undefined) {
          skipped++;
          if (onProgress !== undefined) {
            onProgress(index + 1, frames.length);
          }
          continue;
        }
        const rc: number = timelapse.feedFrame(
          handle,
          nv12,
          Math.round(ptsUs)
        );
        if (rc < 0) {
          throw new Error('喂帧失败（错误码 ' + rc + '）。');
        }
        ptsUs += 1_000_000 / fps;
        if (onProgress !== undefined) {
          onProgress(index + 1, frames.length);
        }
      }
      const framesWritten: number = timelapse.finishEncoder(handle);
      if (framesWritten < 0) {
        throw new Error('收尾失败（错误码 ' + framesWritten + '）。');
      }
      return new TimelapseComposerResult(outputPath, framesWritten, skipped);
    } finally {
      if (handle !== 0) {
        // 取消/异常路径清理；正常路径 finishEncoder 已销毁会话，幂等返回。
        timelapse.destroyEncoder(handle);
      }
    }
  }

  /** 首帧尺寸；全部损坏返回 undefined。 */
  private async firstFrameSize(
    frames: Array<string>
  ): Promise<Array<number> | undefined> {
    for (const frame of frames) {
      try {
        const source: image.ImageSource = image.createImageSource(frame);
        const info: image.ImageInfo = await source.getImageInfo();
        source.release();
        if (info.size.width > 0 && info.size.height > 0) {
          return [info.size.width, info.size.height];
        }
      } catch (error) {
        // 单帧损坏，跳过。
      }
    }
    return undefined;
  }

  /** 解码单帧并绘制到统一画布（aspect-fit 黑底），转 NV12。
   *  失败返回 undefined（跳过计数）。 */
  private async decodeFrameToNv12(
    path: string,
    width: number,
    height: number
  ): Promise<Uint8Array | undefined> {
    let source: image.ImageSource | undefined = undefined;
    let pixelMap: image.PixelMap | undefined = undefined;
    try {
      source = image.createImageSource(path);
      const info: image.ImageInfo = await source.getImageInfo();
      pixelMap = await source.createPixelMap({
        desiredPixelFormat: image.PixelMapFormat.RGBA_8888,
        desiredSize: {
          width: info.size.width,
          height: info.size.height
        }
      });
      const rgba: ArrayBuffer = new ArrayBuffer(
        info.size.width * info.size.height * 4
      );
      await pixelMap.readPixelsToBuffer(rgba);
      return this.rgbaToNv12(
        new Uint8Array(rgba),
        info.size.width,
        info.size.height,
        width,
        height
      );
    } catch (error) {
      return undefined;
    } finally {
      if (pixelMap !== undefined) {
        pixelMap.release();
      }
      if (source !== undefined) {
        source.release();
      }
    }
  }

  /** RGBA 源 → aspect-fit 黑底画布 → NV12。源与画布等宽高时直拷，
   *  异尺寸时最近邻缩放绘制（与 Apple/Android 端画布语义对齐）。 */
  private rgbaToNv12(
    rgba: Uint8Array,
    sourceWidth: number,
    sourceHeight: number,
    width: number,
    height: number
  ): Uint8Array {
    // 统一画布：黑底。
    const canvasRgba: Uint8Array = new Uint8Array(width * height * 4);
    if (sourceWidth === width && sourceHeight === height) {
      canvasRgba.set(rgba);
    } else {
      const scale: number = Math.min(
        width / sourceWidth,
        height / sourceHeight
      );
      const fittedWidth: number = Math.max(1, Math.floor(sourceWidth * scale));
      const fittedHeight: number = Math.max(1, Math.floor(sourceHeight * scale));
      const offsetX: number = Math.floor((width - fittedWidth) / 2);
      const offsetY: number = Math.floor((height - fittedHeight) / 2);
      for (let y: number = 0; y < fittedHeight; y++) {
        const srcY: number = Math.min(
          sourceHeight - 1,
          Math.floor(y / scale)
        );
        for (let x: number = 0; x < fittedWidth; x++) {
          const srcX: number = Math.min(
            sourceWidth - 1,
            Math.floor(x / scale)
          );
          const srcOffset: number = (srcY * sourceWidth + srcX) * 4;
          const dstOffset: number =
            ((offsetY + y) * width + (offsetX + x)) * 4;
          canvasRgba[dstOffset] = rgba[srcOffset];
          canvasRgba[dstOffset + 1] = rgba[srcOffset + 1];
          canvasRgba[dstOffset + 2] = rgba[srcOffset + 2];
          canvasRgba[dstOffset + 3] = 255;
        }
      }
    }

    // RGBA → NV12（BT.601 全范围整数近似）。
    const nv12: Uint8Array = new Uint8Array(width * height * 3 / 2);
    let yIndex: number = 0;
    let uvIndex: number = width * height;
    for (let y: number = 0; y < height; y++) {
      for (let x: number = 0; x < width; x++) {
        const offset: number = (y * width + x) * 4;
        const r: number = canvasRgba[offset];
        const g: number = canvasRgba[offset + 1];
        const b: number = canvasRgba[offset + 2];
        nv12[yIndex++] = (77 * r + 150 * g + 29 * b) >> 8;
        if ((y & 1) === 0 && (x & 1) === 0) {
          nv12[uvIndex++] = ((-43 * r - 85 * g + 128 * b) >> 8) + 128;
          nv12[uvIndex++] = ((128 * r - 107 * g - 21 * b) >> 8) + 128;
        }
      }
    }
    return nv12;
  }
}
