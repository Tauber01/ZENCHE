package com.tauber.nikonlink;

import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.Paint;
import android.graphics.Rect;
import android.graphics.RectF;
import android.media.MediaCodec;
import android.media.MediaCodecInfo;
import android.media.MediaFormat;
import android.media.MediaMuxer;

import java.io.File;
import java.nio.ByteBuffer;
import java.util.List;
import java.util.concurrent.CancellationException;

/**
 * E6 延时合成：把序列帧（JPEG/PNG/HEIC/TIFF）按帧率编码为 H.264 MP4。
 * Android 用平台原生编码链：BitmapFactory 逐帧解码 → 统一画布（aspect-fit
 * 黑底）→ MediaCodec(H.264) + MediaMuxer(MP4)。损坏帧跳过并计数，不整批
 * 失败；进度回调 + 取消检查。
 * TBC-awaiting-hardware（编码器行为依赖系统，需实机验证）。
 */
final class TimelapseComposer {

    /** 排空循环的可变状态（trackIndex/muxerStarted 需跨调用保持）。 */
    private static final class MuxerState {
        int trackIndex = -1;
        boolean started;
    }

    static final class Options {
        final int frameRate;

        Options(int frameRate) {
            this.frameRate = frameRate; // 24/25/30
        }
    }

    static final class Result {
        final File file;
        final int framesWritten;
        final int skippedFrames;

        Result(File file, int framesWritten, int skippedFrames) {
            this.file = file;
            this.framesWritten = framesWritten;
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
            Options options,
            java.util.function.BooleanSupplier isCancelled,
            ProgressListener onProgress) throws Exception {
        if (frames == null || frames.isEmpty()) {
            throw new IllegalStateException("请至少选择一帧。");
        }
        int fps = Math.max(1, Math.min(60, options.frameRate));

        // 首帧尺寸作为统一画布（延时连拍帧同尺寸；异尺寸按 aspect-fit 黑底绘制）。
        // YUV420 采样要求偶数宽高，奇数对齐到偶数。
        int[] canvas = firstFrameSize(frames);
        if (canvas == null) {
            throw new IllegalStateException("所选帧均无法解码，未生成视频。");
        }
        int width = canvas[0] & ~1;
        int height = canvas[1] & ~1;
        if (width < 2) width = 2;
        if (height < 2) height = 2;

        int bitRate = Math.max(
                1_000_000,
                Math.min(20_000_000, (int) (width * height * fps * 0.07)));

        MediaCodec encoder = MediaCodec.createEncoderByType("video/avc");
        MediaMuxer muxer = null;
        try {
            MediaFormat format = MediaFormat.createVideoFormat(
                    "video/avc", width, height);
            format.setInteger(
                    MediaFormat.KEY_COLOR_FORMAT,
                    MediaCodecInfo.CodecCapabilities.COLOR_FormatYUV420Flexible);
            format.setInteger(MediaFormat.KEY_BIT_RATE, bitRate);
            format.setInteger(MediaFormat.KEY_FRAME_RATE, fps);
            format.setInteger(MediaFormat.KEY_I_FRAME_INTERVAL, 1);
            encoder.configure(format, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE);
            encoder.start();

            muxer = new MediaMuxer(
                    output.getAbsolutePath(),
                    MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4);
            MuxerState muxerState = new MuxerState();
            MediaCodec.BufferInfo info = new MediaCodec.BufferInfo();

            int written = 0;
            int skipped = 0;
            long ptsUs = 0;
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
                try {
                    byte[] yuv = argbToI420(frame, width, height);
                    feedFrame(encoder, yuv, ptsUs);
                    ptsUs += 1_000_000L / fps;
                    written++;
                } finally {
                    frame.recycle();
                }
                drainOutput(encoder, muxer, info, muxerState);
                if (onProgress != null) onProgress.onProgress(index + 1, frames.size());
            }

            // EOS
            int inputIndex = encoder.dequeueInputBuffer(10_000);
            if (inputIndex >= 0) {
                encoder.queueInputBuffer(
                        inputIndex, 0, 0, ptsUs, MediaCodec.BUFFER_FLAG_END_OF_STREAM);
            }
            drainOutput(encoder, muxer, info, muxerState);
            // 排空余量输出（EOS 之后编码器可能还有输出）
            drainOutput(encoder, muxer, info, muxerState);

            return new Result(output, written, skipped);
        } finally {
            try {
                encoder.stop();
            } catch (Exception ignored) {
            }
            encoder.release();
            if (muxer != null) {
                try {
                    muxer.stop();
                } catch (Exception ignored) {
                }
                muxer.release();
            }
        }
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
            BitmapFactory.Options options = new BitmapFactory.Options();
            Bitmap source = BitmapFactory.decodeFile(file.getAbsolutePath(), options);
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

    /** ARGB_8888 → I420（YUV420 planar），宽高必须为偶数。 */
    private static byte[] argbToI420(Bitmap bitmap, int width, int height) {
        int[] pixels = new int[width * height];
        bitmap.getPixels(pixels, 0, width, 0, 0, width, height);
        byte[] i420 = new byte[width * height * 3 / 2];
        int yIndex = 0;
        int uIndex = width * height;
        int vIndex = width * height + (width * height) / 4;
        for (int y = 0; y < height; y++) {
            for (int x = 0; x < width; x++) {
                int pixel = pixels[y * width + x];
                int r = (pixel >> 16) & 0xff;
                int g = (pixel >> 8) & 0xff;
                int b = pixel & 0xff;
                // BT.601 全范围整数近似
                i420[yIndex++] = (byte) ((77 * r + 150 * g + 29 * b) >> 8);
                if ((y & 1) == 0 && (x & 1) == 0) {
                    i420[uIndex++] = (byte) (((-43 * r - 85 * g + 128 * b) >> 8) + 128);
                    i420[vIndex++] = (byte) (((128 * r - 107 * g - 21 * b) >> 8) + 128);
                }
            }
        }
        return i420;
    }

    /** 单帧写入编码器输入缓冲。 */
    private static void feedFrame(
            MediaCodec encoder,
            byte[] yuv,
            long ptsUs) throws Exception {
        int inputIndex = encoder.dequeueInputBuffer(10_000);
        if (inputIndex >= 0) {
            ByteBuffer input = encoder.getInputBuffer(inputIndex);
            input.clear();
            input.put(yuv);
            encoder.queueInputBuffer(inputIndex, 0, yuv.length, ptsUs, 0);
        } else {
            throw new IllegalStateException("编码器输入缓冲不可用。");
        }
    }

    /** 排空编码器输出到 muxer。trackIndex/muxerStarted 用单元素数组作可变引用。 */
    private static void drainOutput(
            MediaCodec encoder,
            MediaMuxer muxer,
            MediaCodec.BufferInfo info,
            MuxerState state) throws Exception {
        while (true) {
            int outputIndex = encoder.dequeueOutputBuffer(info, 10_000);
            if (outputIndex == MediaCodec.INFO_TRY_AGAIN_LATER) {
                break;
            }
            if (outputIndex == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED) {
                state.trackIndex = muxer.addTrack(encoder.getOutputFormat());
                muxer.start();
                state.started = true;
                continue;
            }
            if (outputIndex < 0) {
                continue;
            }
            if (state.trackIndex < 0) {
                encoder.releaseOutputBuffer(outputIndex, false);
                continue;
            }
            ByteBuffer output = encoder.getOutputBuffer(outputIndex);
            if ((info.flags & MediaCodec.BUFFER_FLAG_CODEC_CONFIG) == 0
                    && state.started) {
                muxer.writeSampleData(state.trackIndex, output, info);
            }
            encoder.releaseOutputBuffer(outputIndex, false);
            if ((info.flags & MediaCodec.BUFFER_FLAG_END_OF_STREAM) != 0) {
                break;
            }
        }
    }
}
