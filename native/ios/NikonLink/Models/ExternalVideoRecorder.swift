import Foundation

/// Streams JPEG live-view frames to a seekable Motion-JPEG AVI without a
/// vendor movie-download API or an in-memory recording buffer.
final class ExternalVideoRecorder {
    struct Result {
        let url: URL
        let frames: Int
        let bytes: UInt64
    }

    private struct IndexEntry {
        let offset: UInt64
        let size: Int
    }

    private let lock = NSLock()
    private var handle: FileHandle?
    private var target: URL?
    private var frameRate = 30
    private var width = 0
    private var height = 0
    private var largestFrame = 0
    private var lastFrameTime: TimeInterval = 0
    private var index: [IndexEntry] = []
    private var riffSizeOffset: UInt64 = 0
    private var totalFramesOffset: UInt64 = 0
    private var streamLengthOffset: UInt64 = 0
    private var suggestedBufferOffset: UInt64 = 0
    private var streamSuggestedBufferOffset: UInt64 = 0
    private var moviSizeOffset: UInt64 = 0
    private var moviTypeOffset: UInt64 = 0
    private var moviDataOffset: UInt64 = 0

    var isRecording: Bool {
        lock.lock()
        defer { lock.unlock() }
        return target != nil
    }

    func start(at url: URL, frameRate: Double) throws {
        lock.lock()
        defer { lock.unlock() }
        guard target == nil else {
            throw RecorderError.invalidState("外录已经开始。")
        }
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        target = url
        self.frameRate = max(1, min(120, Int(frameRate.rounded())))
        width = 0
        height = 0
        largestFrame = 0
        lastFrameTime = 0
        index.removeAll(keepingCapacity: true)
    }

    func append(jpeg: Data, bypassThrottle: Bool = false) throws {
        lock.lock()
        defer { lock.unlock() }
        guard target != nil, !jpeg.isEmpty else { return }
        let now = ProcessInfo.processInfo.systemUptime
        if !bypassThrottle,
           lastFrameTime > 0,
           now - lastFrameTime < 1.0 / Double(frameRate) {
            return
        }
        if handle == nil {
            (width, height) = try Self.jpegDimensions(jpeg)
            guard let target else { return }
            FileManager.default.createFile(atPath: target.path, contents: nil)
            handle = try FileHandle(forUpdating: target)
            try writeHeader()
        }
        guard let handle else { return }
        let chunkOffset = handle.offsetInFile
        writeASCII("00dc")
        writeInt32(UInt64(jpeg.count))
        handle.write(jpeg)
        if !jpeg.count.isMultiple(of: 2) {
            handle.write(Data([0]))
        }
        index.append(
            IndexEntry(
                offset: chunkOffset - moviTypeOffset,
                size: jpeg.count
            )
        )
        largestFrame = max(largestFrame, jpeg.count)
        lastFrameTime = now
    }

    func stopIfRecording() throws -> Result? {
        lock.lock()
        defer { lock.unlock() }
        return target == nil ? nil : try stopLocked()
    }

    func abort() {
        lock.lock()
        defer { lock.unlock() }
        let abandoned = target
        target = nil
        try? handle?.close()
        handle = nil
        index.removeAll(keepingCapacity: false)
        if let abandoned {
            try? FileManager.default.removeItem(at: abandoned)
        }
    }

    private func stopLocked() throws -> Result {
        guard let finished = target else {
            throw RecorderError.invalidState("外录尚未开始。")
        }
        target = nil
        guard let handle, !index.isEmpty else {
            try? self.handle?.close()
            self.handle = nil
            try? FileManager.default.removeItem(at: finished)
            throw RecorderError.invalidState("没有收到可写入的实时取景帧。")
        }
        let frameCount = index.count
        let indexStart = handle.offsetInFile
        writeASCII("idx1")
        writeInt32(UInt64(frameCount * 16))
        for entry in index {
            writeASCII("00dc")
            writeInt32(0x10)
            writeInt32(entry.offset)
            writeInt32(UInt64(entry.size))
        }
        let fileLength = handle.offsetInFile
        patchInt32(at: riffSizeOffset, value: fileLength - 8)
        patchInt32(at: totalFramesOffset, value: UInt64(frameCount))
        patchInt32(at: streamLengthOffset, value: UInt64(frameCount))
        patchInt32(at: suggestedBufferOffset, value: UInt64(largestFrame))
        patchInt32(
            at: streamSuggestedBufferOffset,
            value: UInt64(largestFrame)
        )
        patchInt32(
            at: moviSizeOffset,
            value: 4 + indexStart - moviDataOffset
        )
        handle.synchronizeFile()
        try handle.close()
        self.handle = nil
        index.removeAll(keepingCapacity: false)
        return Result(url: finished, frames: frameCount, bytes: fileLength)
    }

    private func writeHeader() throws {
        guard let handle else { return }
        writeASCII("RIFF")
        riffSizeOffset = handle.offsetInFile
        writeInt32(0)
        writeASCII("AVI ")
        writeASCII("LIST")
        let hdrlSizeOffset = handle.offsetInFile
        writeInt32(0)
        writeASCII("hdrl")
        let hdrlDataOffset = handle.offsetInFile

        writeASCII("avih")
        writeInt32(56)
        writeInt32(UInt64(1_000_000 / frameRate))
        writeInt32(0); writeInt32(0); writeInt32(0x10)
        totalFramesOffset = handle.offsetInFile
        writeInt32(0)
        writeInt32(0); writeInt32(1)
        suggestedBufferOffset = handle.offsetInFile
        writeInt32(0)
        writeInt32(UInt64(width)); writeInt32(UInt64(height))
        writeInt32(0); writeInt32(0); writeInt32(0); writeInt32(0)

        writeASCII("LIST")
        let strlSizeOffset = handle.offsetInFile
        writeInt32(0)
        writeASCII("strl")
        let strlDataOffset = handle.offsetInFile
        writeASCII("strh")
        writeInt32(56)
        writeASCII("vids"); writeASCII("MJPG")
        writeInt32(0); writeInt16(0); writeInt16(0); writeInt32(0)
        writeInt32(1); writeInt32(UInt64(frameRate)); writeInt32(0)
        streamLengthOffset = handle.offsetInFile
        writeInt32(0)
        streamSuggestedBufferOffset = handle.offsetInFile
        writeInt32(0)
        writeInt32(0xffff_ffff); writeInt32(0)
        writeInt16(0); writeInt16(0)
        writeInt16(UInt64(width)); writeInt16(UInt64(height))

        writeASCII("strf")
        writeInt32(40); writeInt32(40)
        writeInt32(UInt64(width)); writeInt32(UInt64(height))
        writeInt16(1); writeInt16(24); writeASCII("MJPG")
        writeInt32(UInt64(width * height * 3))
        writeInt32(0); writeInt32(0); writeInt32(0); writeInt32(0)
        let headerEnd = handle.offsetInFile
        patchInt32(
            at: strlSizeOffset,
            value: headerEnd - strlDataOffset + 4
        )
        patchInt32(
            at: hdrlSizeOffset,
            value: headerEnd - hdrlDataOffset + 4
        )
        handle.seek(toFileOffset: headerEnd)
        writeASCII("LIST")
        moviSizeOffset = handle.offsetInFile
        writeInt32(0)
        moviTypeOffset = handle.offsetInFile
        writeASCII("movi")
        moviDataOffset = handle.offsetInFile
    }

    private func patchInt32(at offset: UInt64, value: UInt64) {
        guard let handle else { return }
        let current = handle.offsetInFile
        handle.seek(toFileOffset: offset)
        writeInt32(value)
        handle.seek(toFileOffset: current)
    }

    private func writeASCII(_ value: String) {
        handle?.write(value.data(using: .ascii) ?? Data())
    }

    private func writeInt16(_ value: UInt64) {
        handle?.write(Data([
            UInt8(value & 0xff),
            UInt8((value >> 8) & 0xff)
        ]))
    }

    private func writeInt32(_ value: UInt64) {
        handle?.write(Data([
            UInt8(value & 0xff),
            UInt8((value >> 8) & 0xff),
            UInt8((value >> 16) & 0xff),
            UInt8((value >> 24) & 0xff)
        ]))
    }

    private static func jpegDimensions(_ data: Data) throws -> (Int, Int) {
        let bytes = [UInt8](data)
        guard bytes.count >= 4, bytes[0] == 0xff, bytes[1] == 0xd8 else {
            throw RecorderError.invalidFrame
        }
        var offset = 2
        while offset + 8 < bytes.count {
            while offset < bytes.count, bytes[offset] != 0xff { offset += 1 }
            while offset < bytes.count, bytes[offset] == 0xff { offset += 1 }
            guard offset < bytes.count else { break }
            let marker = bytes[offset]
            offset += 1
            if marker == 0xd8 || marker == 0xd9 { continue }
            guard offset + 1 < bytes.count else { break }
            let length = Int(bytes[offset]) << 8 | Int(bytes[offset + 1])
            guard length >= 2, offset + length <= bytes.count else { break }
            let isSOF = (0xc0...0xc3).contains(marker)
                || (0xc5...0xc7).contains(marker)
                || (0xc9...0xcb).contains(marker)
                || (0xcd...0xcf).contains(marker)
            if isSOF {
                let height = Int(bytes[offset + 3]) << 8
                    | Int(bytes[offset + 4])
                let width = Int(bytes[offset + 5]) << 8
                    | Int(bytes[offset + 6])
                if width > 0, height > 0 { return (width, height) }
            }
            offset += length
        }
        throw RecorderError.invalidFrame
    }
}

private enum RecorderError: LocalizedError {
    case invalidFrame
    case invalidState(String)

    var errorDescription: String? {
        switch self {
        case .invalidFrame: return "无法读取实时取景 JPEG 尺寸。"
        case .invalidState(let message): return message
        }
    }
}
