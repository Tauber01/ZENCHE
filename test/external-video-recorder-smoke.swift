import Foundation

@main
struct ExternalVideoRecorderSmokeTest {
    static func main() throws {
        guard CommandLine.arguments.count == 3 else {
            throw SmokeTestError.usage
        }
        let frame = try Data(
            contentsOf: URL(fileURLWithPath: CommandLine.arguments[1])
        )
        let destination = URL(fileURLWithPath: CommandLine.arguments[2])
        let recorder = ExternalVideoRecorder()
        try recorder.start(at: destination, frameRate: 30)
        try recorder.append(jpeg: frame)
        Thread.sleep(forTimeInterval: 0.04)
        try recorder.append(jpeg: frame)
        guard let result = try recorder.stopIfRecording(),
              result.frames == 2,
              result.bytes > UInt64(frame.count * 2) else {
            throw SmokeTestError.invalidResult
        }
        print("\(result.frames) frames · \(result.bytes) bytes")
    }
}

private enum SmokeTestError: Error {
    case usage
    case invalidResult
}
