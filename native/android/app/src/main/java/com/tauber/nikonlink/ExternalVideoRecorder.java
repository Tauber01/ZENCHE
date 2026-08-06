package com.tauber.nikonlink;

import android.graphics.BitmapFactory;

import java.io.File;
import java.io.IOException;
import java.io.RandomAccessFile;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.List;

/**
 * Streams camera live-view JPEG frames into a seekable Motion-JPEG AVI file.
 * The format is deliberately codec-free: USB/PTP cameras already return JPEG
 * frames and Android can play the resulting AVI without retaining a recording
 * in memory first.
 */
final class ExternalVideoRecorder implements AutoCloseable {
    static final class Result {
        final File file;
        final int frames;
        final long bytes;

        Result(File file, int frames, long bytes) {
            this.file = file;
            this.frames = frames;
            this.bytes = bytes;
        }
    }

    private static final class IndexEntry {
        final long offset;
        final int size;

        IndexEntry(long offset, int size) {
            this.offset = offset;
            this.size = size;
        }
    }

    private final List<IndexEntry> index = new ArrayList<>();
    private RandomAccessFile output;
    private File target;
    private int requestedFrameRate;
    private int width;
    private int height;
    private int largestFrame;
    private long startedAtNanos;
    private long lastFrameAtNanos;
    private long riffSizeOffset;
    private long totalFramesOffset;
    private long streamLengthOffset;
    private long suggestedBufferOffset;
    private long streamSuggestedBufferOffset;
    private long moviSizeOffset;
    private long moviTypeOffset;
    private long moviDataOffset;

    synchronized boolean isRecording() {
        return target != null;
    }

    synchronized String targetName() {
        return target == null ? "" : target.getName();
    }

    synchronized void start(File file, int frameRate) throws IOException {
        if (isRecording()) throw new IOException("外录已经开始。");
        File parent = file.getParentFile();
        if (parent != null && !parent.exists() && !parent.mkdirs()) {
            throw new IOException("无法创建外录目录。");
        }
        target = file;
        requestedFrameRate = Math.max(1, Math.min(120, frameRate));
        width = 0;
        height = 0;
        largestFrame = 0;
        index.clear();
        startedAtNanos = System.nanoTime();
        lastFrameAtNanos = 0;
    }

    synchronized void appendJpeg(byte[] jpeg) throws IOException {
        appendJpeg(jpeg, true);
    }

    synchronized void appendJpeg(byte[] jpeg, boolean throttle) throws IOException {
        if (!isRecording() || jpeg == null || jpeg.length == 0) return;
        long now = System.nanoTime();
        long minimumSpacing = 1_000_000_000L / requestedFrameRate;
        if (throttle
                && lastFrameAtNanos != 0
                && now - lastFrameAtNanos < minimumSpacing) {
            return;
        }
        if (output == null) {
            BitmapFactory.Options bounds = new BitmapFactory.Options();
            bounds.inJustDecodeBounds = true;
            BitmapFactory.decodeByteArray(jpeg, 0, jpeg.length, bounds);
            if (bounds.outWidth <= 0 || bounds.outHeight <= 0) {
                throw new IOException("实时取景帧不是有效 JPEG。");
            }
            width = bounds.outWidth;
            height = bounds.outHeight;
            output = new RandomAccessFile(target, "rw");
            output.setLength(0);
            writeHeader();
        }
        long chunkOffset = output.getFilePointer();
        ascii("00dc");
        int32(jpeg.length);
        output.write(jpeg);
        if ((jpeg.length & 1) != 0) output.write(0);
        index.add(new IndexEntry(chunkOffset - moviTypeOffset, jpeg.length));
        largestFrame = Math.max(largestFrame, jpeg.length);
        lastFrameAtNanos = now;
    }

    synchronized Result stop() throws IOException {
        if (!isRecording()) throw new IOException("外录尚未开始。");
        File finished = target;
        target = null;
        if (output == null || index.isEmpty()) {
            if (output != null) output.close();
            output = null;
            if (finished.exists()) finished.delete();
            throw new IOException("没有收到可写入的实时取景帧。");
        }

        long indexStart = output.getFilePointer();
        ascii("idx1");
        int32(index.size() * 16);
        for (IndexEntry entry : index) {
            ascii("00dc");
            int32(0x10);
            int32(entry.offset);
            int32(entry.size);
        }
        long fileLength = output.getFilePointer();
        patchInt32(riffSizeOffset, fileLength - 8);
        patchInt32(totalFramesOffset, index.size());
        patchInt32(streamLengthOffset, index.size());
        patchInt32(suggestedBufferOffset, largestFrame);
        patchInt32(streamSuggestedBufferOffset, largestFrame);
        patchInt32(moviSizeOffset, 4 + indexStart - moviDataOffset);
        output.getFD().sync();
        output.close();
        output = null;
        index.clear();
        return new Result(finished, (int) ((fileLength - indexStart - 8) / 16), fileLength);
    }

    synchronized Result stopIfRecording() throws IOException {
        return isRecording() ? stop() : null;
    }

    synchronized void abort() {
        File abandoned = target;
        target = null;
        try {
            if (output != null) output.close();
        } catch (IOException ignored) {
        }
        output = null;
        index.clear();
        if (abandoned != null && abandoned.exists()) abandoned.delete();
    }

    @Override public void close() {
        abort();
    }

    private void writeHeader() throws IOException {
        ascii("RIFF");
        riffSizeOffset = output.getFilePointer();
        int32(0);
        ascii("AVI ");

        ascii("LIST");
        long hdrlSizeOffset = output.getFilePointer();
        int32(0);
        ascii("hdrl");
        long hdrlDataOffset = output.getFilePointer();

        ascii("avih");
        int32(56);
        int32(1_000_000 / requestedFrameRate);
        int32(0);
        int32(0);
        int32(0x10);
        totalFramesOffset = output.getFilePointer();
        int32(0);
        int32(0);
        int32(1);
        suggestedBufferOffset = output.getFilePointer();
        int32(0);
        int32(width);
        int32(height);
        int32(0); int32(0); int32(0); int32(0);

        ascii("LIST");
        long strlSizeOffset = output.getFilePointer();
        int32(0);
        ascii("strl");
        long strlDataOffset = output.getFilePointer();

        ascii("strh");
        int32(56);
        ascii("vids");
        ascii("MJPG");
        int32(0);
        int16(0); int16(0);
        int32(0);
        int32(1);
        int32(requestedFrameRate);
        int32(0);
        streamLengthOffset = output.getFilePointer();
        int32(0);
        streamSuggestedBufferOffset = output.getFilePointer();
        int32(0);
        int32(0xffffffffL);
        int32(0);
        int16(0); int16(0); int16(width); int16(height);

        ascii("strf");
        int32(40);
        int32(40);
        int32(width);
        int32(height);
        int16(1);
        int16(24);
        ascii("MJPG");
        int32((long) width * height * 3);
        int32(0); int32(0); int32(0); int32(0);

        long headerEnd = output.getFilePointer();
        patchInt32(strlSizeOffset, headerEnd - strlDataOffset + 4);
        patchInt32(hdrlSizeOffset, headerEnd - hdrlDataOffset + 4);
        output.seek(headerEnd);
        ascii("LIST");
        moviSizeOffset = output.getFilePointer();
        int32(0);
        moviTypeOffset = output.getFilePointer();
        ascii("movi");
        moviDataOffset = output.getFilePointer();
    }

    private void patchInt32(long offset, long value) throws IOException {
        long current = output.getFilePointer();
        output.seek(offset);
        int32(value);
        output.seek(current);
    }

    private void ascii(String value) throws IOException {
        output.write(value.getBytes(StandardCharsets.US_ASCII));
    }

    private void int16(long value) throws IOException {
        output.write((int) (value & 0xff));
        output.write((int) ((value >>> 8) & 0xff));
    }

    private void int32(long value) throws IOException {
        output.write((int) (value & 0xff));
        output.write((int) ((value >>> 8) & 0xff));
        output.write((int) ((value >>> 16) & 0xff));
        output.write((int) ((value >>> 24) & 0xff));
    }
}
