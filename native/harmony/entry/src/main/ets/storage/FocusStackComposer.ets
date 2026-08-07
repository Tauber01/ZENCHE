import { fileIo as fs } from '@kit.CoreFileKit';
import { image } from '@kit.ImageKit';

/** E7 焦点合成结果：写入路径 + 参与融合帧数 + 跳过损坏帧数。 */
export class FocusStackComposerResult {
  readonly path: string;
  readonly sourcesUsed: number;
  readonly skippedFrames: number;

  constructor(path: string, sourcesUsed: number, skippedFrames: number) {
    this.path = path;
    this.sourcesUsed = sourcesUsed;
    this.skippedFrames = skippedFrames;
  }
}

/** E7 焦点包围合成：把不同对焦距离的序列帧合成一张全清晰 JPEG。
 *  算法（五端同构，纯 CPU 逐像素）：
 *   1. 全局亮度归一——以首帧平均亮度为基准，每帧 scale = clamp(mean0/mean_i, 0.5, 2.0)
 *      （手持微抖/曝光微差的包围帧亮度归一；亚像素位移对齐工程量过大，列入 backlog）。
 *   2. 清晰度测度——3×3 拉普拉斯核（全 8 邻域中心 8）作用于归一亮度，取绝对响应。
 *   3. 逐像素融合——取 |lap| 最大帧的 RGBA（×scale 归一），边界 1px 取首帧。
 *  内存优化：两遍式逐帧融合，峰值仅 2 帧像素 + 全局 best 数组（不保留全部帧）。
 *  损坏帧跳过并计数，不整批失败；进度回调 + 取消检查。
 *  TBC-awaiting-hardware（合成结果依赖真实包围序列，需实机验证）。 */
export class FocusStackComposer {
  /**
   * 逐帧合成。isCancelled 返回 true 时中止并抛 Error('已取消')；
   * onProgress 报告 (已处理帧数, 总帧数)。
   */
  async compose(
    frames: Array<string>,
    outputPath: string,
    isCancelled: () => boolean,
    onProgress?: (done: number, total: number) => void
  ): Promise<FocusStackComposerResult> {
    if (frames.length === 0) {
      throw new Error('请至少选择一帧。');
    }
    // 首帧尺寸作为统一画布（包围帧同尺寸；异尺寸按 aspect-fit 黑底绘制）。
    const canvas: Array<number> | undefined = await this.firstFrameSize(frames);
    if (canvas === undefined) {
      throw new Error('所选帧均无法解码，未生成合成图。');
    }
    const width: number = Math.max(2, canvas[0]);
    const height: number = Math.max(2, canvas[1]);

    // 全局 best 数组（RGBA + 拉普拉斯响应）。
    const bestRgba: Uint8Array = new Uint8Array(width * height * 4);
    const bestLap: Float32Array = new Float32Array(width * height);
    bestLap.fill(-1);
    let skipped: number = 0;
    let sourcesUsed: number = 0;
    let referenceMean: number = 0;

    for (let index: number = 0; index < frames.length; index++) {
      if (isCancelled()) {
        throw new Error('已取消');
      }
      const rgba: Uint8Array | undefined = await this.decodeFrameToRgba(
        frames[index],
        width,
        height
      );
      if (rgba === undefined) {
        skipped++;
        if (onProgress !== undefined) {
          onProgress(index + 1, frames.length);
        }
        continue;
      }
      // 亮度（BT.601 全范围整数近似）+ 平均亮度。
      const luminance: Float32Array = new Float32Array(width * height);
      let sum: number = 0;
      for (let p: number = 0; p < width * height; p++) {
        const offset: number = p * 4;
        const r: number = rgba[offset];
        const g: number = rgba[offset + 1];
        const b: number = rgba[offset + 2];
        const y: number = (77 * r + 150 * g + 29 * b) / 255;
        luminance[p] = y;
        sum += y;
      }
      const mean: number = sum / (width * height);

      if (sourcesUsed === 0) {
        // 首帧：作为融合基准（scale=1），平均亮度作为归一基准。
        referenceMean = mean;
        bestRgba.set(rgba);
        for (let y: number = 1; y < height - 1; y++) {
          for (let x: number = 1; x < width - 1; x++) {
            const p: number = y * width + x;
            bestLap[p] = Math.abs(
              8 * luminance[p]
              - luminance[p - width] - luminance[p + width]
              - luminance[p - 1] - luminance[p + 1]
              - luminance[p - width - 1] - luminance[p - width + 1]
              - luminance[p + width - 1] - luminance[p + width + 1]
            );
          }
        }
      } else {
        // 亮度归一（手持微抖/曝光微差）。
        const scale: number = Math.max(
          0.5,
          Math.min(2.0, mean === 0 ? 1.0 : referenceMean / mean)
        );
        const normalized: Float32Array = new Float32Array(width * height);
        for (let p: number = 0; p < width * height; p++) {
          normalized[p] = luminance[p] * scale;
        }
        for (let y: number = 1; y < height - 1; y++) {
          for (let x: number = 1; x < width - 1; x++) {
            const p: number = y * width + x;
            const lap: number = Math.abs(
              8 * normalized[p]
              - normalized[p - width] - normalized[p + width]
              - normalized[p - 1] - normalized[p + 1]
              - normalized[p - width - 1] - normalized[p - width + 1]
              - normalized[p + width - 1] - normalized[p + width + 1]
            );
            if (lap > bestLap[p]) {
              bestLap[p] = lap;
              const offset: number = p * 4;
              bestRgba[offset] = this.clampByte(rgba[offset] * scale);
              bestRgba[offset + 1] = this.clampByte(rgba[offset + 1] * scale);
              bestRgba[offset + 2] = this.clampByte(rgba[offset + 2] * scale);
              bestRgba[offset + 3] = 255;
            }
          }
        }
      }
      sourcesUsed++;
      if (onProgress !== undefined) {
        onProgress(index + 1, frames.length);
      }
    }

    if (sourcesUsed < 2) {
      throw new Error(`可合成帧不足（成功解码 ${sourcesUsed} 帧，焦点合成需要至少 2 帧）。`);
    }

    // 合成图 → JPEG 写出。
    let packer: image.ImagePacker | undefined = undefined;
    let pixelMap: image.PixelMap | undefined = undefined;
    try {
      pixelMap = await image.createPixelMap(bestRgba.buffer, {
        size: { width: width, height: height },
        srcPixelFormat: image.PixelMapFormat.RGBA_8888,
        pixelFormat: image.PixelMapFormat.RGBA_8888,
        editable: true
      });
      packer = image.createImagePacker();
      const packed: ArrayBuffer = await packer.packing(pixelMap, {
        format: 'image/jpeg',
        quality: 92
      });
      const file = fs.openSync(outputPath, fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE | fs.OpenMode.TRUNC);
      fs.writeSync(file.fd, packed);
      fs.closeSync(file);
    } finally {
      if (pixelMap !== undefined) {
        pixelMap.release();
      }
      if (packer !== undefined) {
        packer.release();
      }
    }
    return new FocusStackComposerResult(outputPath, sourcesUsed, skipped);
  }

  private clampByte(value: number): number {
    return Math.max(0, Math.min(255, Math.round(value)));
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

  /** 解码单帧并绘制到统一画布（aspect-fit 黑底），返回 RGBA8888。失败返回 undefined。 */
  private async decodeFrameToRgba(
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
      return this.rgbaToCanvas(
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

  /** RGBA 源 → aspect-fit 黑底画布（与 Apple/Android 端画布语义对齐，最近邻）。 */
  private rgbaToCanvas(
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
    return canvasRgba;
  }
}
