import Foundation

struct MJPEGFrameDecoder {
    private static let startMarker = Data([0xff, 0xd8])
    private static let endMarker = Data([0xff, 0xd9])
    private static let maximumBufferedBytes = 16 * 1024 * 1024

    private(set) var bufferedByteCount = 0
    private var buffer = Data()

    mutating func append(_ data: Data) {
        guard !data.isEmpty else { return }
        buffer.append(data)
        bufferedByteCount = buffer.count
    }

    mutating func nextFrame() -> Data? {
        guard let start = buffer.range(of: Self.startMarker)?.lowerBound else {
            discardGarbageBeforeStartMarker()
            return nil
        }

        if start > buffer.startIndex {
            buffer.removeSubrange(buffer.startIndex..<start)
        }
        guard buffer.count >= 4 else {
            bufferedByteCount = buffer.count
            return nil
        }

        let searchStart = buffer.index(buffer.startIndex, offsetBy: 2)
        guard let end = buffer.range(
            of: Self.endMarker,
            in: searchStart..<buffer.endIndex
        )?.upperBound else {
            trimOversizedIncompleteFrame()
            bufferedByteCount = buffer.count
            return nil
        }

        let frame = Data(buffer[buffer.startIndex..<end])
        buffer.removeSubrange(buffer.startIndex..<end)
        bufferedByteCount = buffer.count
        return frame
    }

    mutating func latestFrame() -> Data? {
        var latest: Data?
        while let frame = nextFrame() {
            latest = frame
        }
        return latest
    }

    mutating func reset() {
        buffer.removeAll(keepingCapacity: true)
        bufferedByteCount = 0
    }

    private mutating func discardGarbageBeforeStartMarker() {
        guard buffer.count > 1 else {
            bufferedByteCount = buffer.count
            return
        }
        let keepTrailingFF = buffer.last == 0xff
        buffer.removeAll(keepingCapacity: true)
        if keepTrailingFF {
            buffer.append(0xff)
        }
        bufferedByteCount = buffer.count
    }

    private mutating func trimOversizedIncompleteFrame() {
        guard buffer.count > Self.maximumBufferedBytes else { return }
        let suffix = buffer.suffix(Self.maximumBufferedBytes)
        buffer = Data(suffix)
    }
}
