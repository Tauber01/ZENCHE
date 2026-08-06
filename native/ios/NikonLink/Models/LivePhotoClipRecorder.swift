import Foundation

/// 内存环形取景帧缓冲 + 快门切片（E5 live 图，路线 B）：
/// 取景开启时常开入环（只保留最近 maxSeconds 帧），快门触发时把
/// 最近 N 秒帧写为 Motion-JPEG AVI，与照片共用 reservedBaseName 配对入库。
/// TBC-awaiting-hardware（实机取景帧率/码率待验证）。
final class LivePhotoClipRecorder {
    struct Slice {
        let url: URL
        let frames: Int
        let bytes: UInt64
    }

    private struct RingFrame {
        let data: Data
        let timestamp: TimeInterval
    }

    private let lock = NSLock()
    private var armed = false
    private var ring: [RingFrame] = []
    private var frameRate = 10
    private var maxSeconds = 3.0
    private var lastAppendTime: TimeInterval = 0

    var isArmed: Bool {
        lock.lock()
        defer { lock.unlock() }
        return armed
    }

    func arm(frameRate: Int, maxSeconds: Double) {
        lock.lock()
        defer { lock.unlock() }
        armed = true
        self.frameRate = max(1, min(120, frameRate))
        self.maxSeconds = max(0.5, min(30, maxSeconds))
        ring.removeAll(keepingCapacity: true)
        lastAppendTime = 0
    }

    func disarm() {
        lock.lock()
        defer { lock.unlock() }
        armed = false
        ring.removeAll(keepingCapacity: false)
        lastAppendTime = 0
    }

    /// 按帧率节流入环；超过 maxSeconds 的旧帧被淘汰。
    func append(jpeg: Data) {
        lock.lock()
        defer { lock.unlock() }
        guard armed, !jpeg.isEmpty else { return }
        let now = ProcessInfo.processInfo.systemUptime
        if lastAppendTime > 0,
           now - lastAppendTime < 1.0 / Double(frameRate) {
            return
        }
        lastAppendTime = now
        ring.append(RingFrame(data: jpeg, timestamp: now))
        let cutoff = now - maxSeconds
        while let first = ring.first, first.timestamp < cutoff {
            ring.removeFirst()
        }
    }

    /// 把最近 maxSeconds 帧写为 AVI 切片；环为空返回 nil。
    /// 复用 ExternalVideoRecorder 的 AVI 写入逻辑（字节级同构四端）。
    func captureSlice(to url: URL) throws -> Slice? {
        lock.lock()
        guard armed, !ring.isEmpty else {
            lock.unlock()
            return nil
        }
        let frames = ring.map(\.data)
        lock.unlock()

        let recorder = ExternalVideoRecorder()
        try recorder.start(at: url, frameRate: Double(frameRate))
        for frame in frames {
            try recorder.append(jpeg: frame)
        }
        guard let result = try recorder.stopIfRecording() else { return nil }
        return Slice(url: result.url, frames: result.frames, bytes: result.bytes)
    }
}
