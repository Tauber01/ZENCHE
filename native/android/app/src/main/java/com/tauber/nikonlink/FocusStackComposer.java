package com.tauber.nikonlink;

import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.Paint;
import android.graphics.RectF;

import java.io.File;
import java.io.FileOutputStream;
import java.util.List;
import java.util.concurrent.CancellationException;

/**
 * E7 焦点包围合成：把不同对焦距离的序列帧合成一张全清晰 JPEG。
 * 算法（五端同构，纯 CPU 逐像素）：
 *   1. 全局亮度归一——以首帧平均亮度为基准，每帧 scale = clamp(mean0/mean_i, 0.5, 2.0)
 *      （手持微抖/曝光微差的包围帧亮度归一；亚像素位移对齐工程量过大，列入 backlog）。
 *   2. 清晰度测度——3×3 拉普拉斯核（全 8 邻域中心 8）作用于归一亮度，取绝对响应。
 *   3. 逐像素融合——取 |lap| 最大帧的 ARGB（×scale 归一），边界 1px 取首帧。
 * 内存优化：两遍式逐帧融合，峰值仅 2 帧像素 + 全局 best 数组（不保留全部帧）。
 * 损坏帧跳过并计数，不整批失败；进度回调 + 取消检查。
 * TBC-awaiting-hardware（合成结果依赖真实包围序列，需实机验证）。
 */
final class FocusStackComposer {

    static final class Result {
        final File file;
        final int sourcesUsed;
        final int skippedFrames;

        Result(File file, int sourcesUsed, int skippedFrames) {
            this.file = file;
            this.sourcesUsed = sourcesUsed;
            this.skippedFrames = skippedFrames;
        }
    }

    interface ProgressListener {
        void onProgress(int done, int total);
    }

    /** 逐帧合成。isCancelled 返回 true 时中止并抛 CancellationException；
     *  onProgress 报告 (已处理帧数, 总帧数)。 */
    Result compose(
            List<File> frames,
            File output,
            java.util.function.BooleanSupplier isCancelled,
            ProgressListener onProgress) throws Exception {
        if (frames == null || frames.isEmpty()) {
            throw new IllegalStateException("请至少选择一帧。");
        }
        // 首帧尺寸作为统一画布（包围帧同尺寸；异尺寸按 aspect-fit 黑底绘制）。
        int[] canvas = firstFrameSize(frames);
        if (canvas == null) {
            throw new IllegalStateException("所选帧均无法解码，未生成合成图。");
        }
        int width = canvas[0];
        int height = canvas[1];
        if (width < 2) width = 2;
        if (height < 2) height = 2;

        int[] bestArgb = new int[width * height];
        float[] bestLap = new float[width * height];
        for (int i = 0; i < bestLap.length; i++) {
            bestLap[i] = -1f;
        }
        int skipped = 0;
        int sourcesUsed = 0;
        float referenceMean = 0;

        for (int index = 0; index < frames.size(); index++) {
            if (isCancelled.getAsBoolean()) {
                throw new CancellationException();
            }
            Bitmap frame = decodeFit(frames.get(index), width, height);
            if (frame == null) {
                skipped++;
                if (onProgress != null) onProgress.onProgress(index + 1, frames.size());
                continue;
            }
            int[] pixels = new int[width * height];
            frame.getPixels(pixels, 0, width, 0, 0, width, height);
            frame.recycle();

            float[] luminance = new float[width * height];
            double sum = 0;
            for (int p = 0; p < width * height; p++) {
                int argb = pixels[p];
                float r = (argb >> 16) & 0xff;
                float g = (argb >> 8) & 0xff;
                float b = argb & 0xff;
                float y = (77f * r + 150f * g + 29f * b) / 255f;
                luminance[p] = y;
                sum += y;
            }
            float mean = (float) (sum / (width * height));

            if (sourcesUsed == 0) {
                // 首帧：作为融合基准（scale=1），平均亮度作为归一基准。
                referenceMean = mean;
                System.arraycopy(pixels, 0, bestArgb, 0, pixels.length);
                for (int y = 1; y < height - 1; y++) {
                    for (int x = 1; x < width - 1; x++) {
                        int p = y * width + x;
                        bestLap[p] = Math.abs(
                                8 * luminance[p]
                                - luminance[p - width] - luminance[p + width]
                                - luminance[p - 1] - luminance[p + 1]
                                - luminance[p - width - 1] - luminance[p - width + 1]
                                - luminance[p + width - 1] - luminance[p + width + 1]);
                    }
                }
            } else {
                // 亮度归一（手持微抖/曝光微差）。
                float scale = (float) Math.max(
                        0.5, Math.min(2.0, mean == 0 ? 1.0 : referenceMean / mean));
                float[] normalized = new float[width * height];
                for (int p = 0; p < width * height; p++) {
                    normalized[p] = luminance[p] * scale;
                }
                for (int y = 1; y < height - 1; y++) {
                    for (int x = 1; x < width - 1; x++) {
                        int p = y * width + x;
                        float lap = Math.abs(
                                8 * normalized[p]
                                - normalized[p - width] - normalized[p + width]
                                - normalized[p - 1] - normalized[p + 1]
                                - normalized[p - width - 1] - normalized[p - width + 1]
                                - normalized[p + width - 1] - normalized[p + width + 1]);
                        if (lap > bestLap[p]) {
                            bestLap[p] = lap;
                            int argb = pixels[p];
                            int r = clampByte(((argb >> 16) & 0xff) * scale);
                            int g = clampByte(((argb >> 8) & 0xff) * scale);
                            int b = clampByte((argb & 0xff) * scale);
                            bestArgb[p] = 0xff000000 | (r << 16) | (g << 8) | b;
                        }
                    }
                }
            }
            sourcesUsed++;
            if (onProgress != null) onProgress.onProgress(index + 1, frames.size());
        }

        if (sourcesUsed < 2) {
            throw new IllegalStateException(
                    "可合成帧不足（成功解码 " + sourcesUsed + " 帧，焦点合成需要至少 2 帧）。");
        }

        Bitmap result = Bitmap.createBitmap(bestArgb, width, height, Bitmap.Config.ARGB_8888);
        try {
            FileOutputStream stream = new FileOutputStream(output);
            try {
                if (!result.compress(Bitmap.CompressFormat.JPEG, 92, stream)) {
                    throw new IllegalStateException("合成图编码失败。");
                }
            } finally {
                stream.close();
            }
        } finally {
            result.recycle();
        }
        return new Result(output, sourcesUsed, skipped);
    }

    private static int clampByte(float value) {
        return Math.max(0, Math.min(255, Math.round(value)));
    }

    /** 首帧尺寸；全部损坏返回 null。 */
    private int[] firstFrameSize(List<File> frames) {
        for (File file : frames) {
            BitmapFactory.Options bounds = new BitmapFactory.Options();
            bounds.inJustDecodeBounds = true;
            try {
                BitmapFactory.decodeFile(file.getAbsolutePath(), bounds);
            } catch (Exception ignored) {
                continue;
            }
            if (bounds.outWidth > 0 && bounds.outHeight > 0) {
                return new int[]{bounds.outWidth, bounds.outHeight};
            }
        }
        return null;
    }

    /** 解码单帧并绘制到统一画布（aspect-fit 黑底）。失败返回 null（跳过计数）。 */
    private Bitmap decodeFit(File file, int width, int height) {
        try {
            Bitmap source = BitmapFactory.decodeFile(file.getAbsolutePath());
            if (source == null) return null;
            try {
                Bitmap canvasBitmap = Bitmap.createBitmap(
                        width, height, Bitmap.Config.ARGB_8888);
                Canvas canvas = new Canvas(canvasBitmap);
                canvas.drawColor(Color.BLACK);
                // aspect-fit：等比缩放并居中。
                float scale = Math.min(
                        (float) width / source.getWidth(),
                        (float) height / source.getHeight());
                float fittedWidth = source.getWidth() * scale;
                float fittedHeight = source.getHeight() * scale;
                RectF destination = new RectF(
                        (width - fittedWidth) / 2f,
                        (height - fittedHeight) / 2f,
                        (width + fittedWidth) / 2f,
                        (height + fittedHeight) / 2f);
                canvas.drawBitmap(source, null, destination, new Paint(
                        Paint.FILTER_BITMAP_FLAG | Paint.ANTI_ALIAS_FLAG));
                return canvasBitmap;
            } finally {
                source.recycle();
            }
        } catch (Exception ignored) {
            return null;
        }
    }
}
