package com.tauber.nikonlink;

import java.io.File;
import java.util.ArrayDeque;
import java.util.ArrayList;
import java.util.Deque;
import java.util.List;

/**
 * 内存环形取景帧缓冲 + 快门切片（E5 live 图，路线 B）：
 * 取景开启时常开入环（只保留最近 maxSeconds 帧），快门触发时把
 * 最近 N 秒帧写为 Motion-JPEG AVI，与照片共用 reservedBaseName 配对入库。
 * TBC-awaiting-hardware（实机取景帧率/码率待验证）。
 */
final class LivePhotoClipRecorder {
    private static final class RingFrame {
        final byte[] data;
        final long timestampNanos;

        RingFrame(byte[] data, long timestampNanos) {
            this.data = data;
            this.timestampNanos = timestampNanos;
        }
    }

    private final Object gate = new Object();
    private boolean armed;
    private final Deque<RingFrame> ring = new ArrayDeque<>();
    private int frameRate = 10;
    private double maxSeconds = 3.0;
    private long lastAppendNanos;

    boolean isArmed() {
        synchronized (gate) {
            return armed;
        }
    }

    void arm(int frameRate, double maxSeconds) {
        synchronized (gate) {
            armed = true;
            this.frameRate = Math.max(1, Math.min(120, frameRate));
            this.maxSeconds = Math.max(0.5, Math.min(30, maxSeconds));
            ring.clear();
            lastAppendNanos = 0;
        }
    }

    void disarm() {
        synchronized (gate) {
            armed = false;
            ring.clear();
            lastAppendNanos = 0;
        }
    }

    /** 按帧率节流入环；超过 maxSeconds 的旧帧被淘汰。 */
    void append(byte[] jpeg) {
        synchronized (gate) {
            if (!armed || jpeg == null || jpeg.length == 0) return;
            long now = System.nanoTime();
            if (lastAppendNanos != 0
                    && now - lastAppendNanos < 1_000_000_000L / frameRate) {
                return;
            }
            lastAppendNanos = now;
            ring.addLast(new RingFrame(jpeg, now));
            long cutoff = now - (long) (1_000_000_000L * maxSeconds);
            while (!ring.isEmpty() && ring.peekFirst().timestampNanos < cutoff) {
                ring.removeFirst();
            }
        }
    }

    /** 把最近 maxSeconds 帧写为 AVI 切片；环为空返回 null。
     *  复用 ExternalVideoRecorder 的 AVI 写入逻辑（字节级同构五端）。 */
    ExternalVideoRecorder.Result captureSlice(File target) throws Exception {
        List<byte[]> frames;
        synchronized (gate) {
            if (!armed || ring.isEmpty()) return null;
            frames = new ArrayList<>(ring.size());
            for (RingFrame frame : ring) frames.add(frame.data);
        }
        ExternalVideoRecorder recorder = new ExternalVideoRecorder();
        try {
            recorder.start(target, frameRate);
            for (byte[] frame : frames) {
                // bypassThrottle：切片回放帧为内存已有帧，快速写入不得被
                // 实时取景的帧率节流丢弃（否则 AVI 只剩第一帧）。
                recorder.appendJpeg(frame, false);
            }
            return recorder.stopIfRecording();
        } catch (Exception error) {
            recorder.abort();
            throw error;
        }
    }
}
