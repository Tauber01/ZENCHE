import AppKit
import AVKit
import Darwin
import Foundation
import Photos
import SwiftUI
import UniformTypeIdentifiers

private struct SupportedCamera: Equatable {
    let name: String
    let productID: Int
    let detectionTokens: [String]
    let minimumISO: Int
    let maximumISO: Int

    static let all = [
        SupportedCamera(
            name: "Nikon Z7",
            productID: 0x0442,
            detectionTokens: ["nikon z7", "nikon z 7"],
            minimumISO: 64,
            maximumISO: 25600
        ),
        SupportedCamera(
            name: "Nikon Z6",
            productID: 0x0443,
            detectionTokens: ["nikon z6", "nikon z 6"],
            minimumISO: 100,
            maximumISO: 51200
        ),
        SupportedCamera(
            name: "Nikon Z50",
            productID: 0x0444,
            detectionTokens: ["nikon z50", "nikon z 50"],
            minimumISO: 100,
            maximumISO: 51200
        ),
        SupportedCamera(
            name: "Nikon D780",
            productID: 0x0446,
            detectionTokens: ["nikon d780", "nikon d 780"],
            minimumISO: 100,
            maximumISO: 51200
        ),
        SupportedCamera(
            name: "Nikon D6",
            productID: 0x0447,
            detectionTokens: ["nikon d6", "nikon d 6"],
            minimumISO: 100,
            maximumISO: 102400
        ),
        SupportedCamera(
            name: "Nikon Z5",
            productID: 0x0448,
            detectionTokens: ["nikon z5", "nikon z 5"],
            minimumISO: 100,
            maximumISO: 51200
        ),
        SupportedCamera(
            name: "Nikon Z7II",
            productID: 0x044b,
            detectionTokens: [
                "nikon z7 2", "nikon z7 ii", "nikon z7ii", "nikon z 7ii"
            ],
            minimumISO: 64,
            maximumISO: 25600
        ),
        SupportedCamera(
            name: "Nikon Z6II",
            productID: 0x044c,
            detectionTokens: [
                "nikon z6 2", "nikon z6 ii", "nikon z6ii", "nikon z 6ii"
            ],
            minimumISO: 100,
            maximumISO: 51200
        ),
        SupportedCamera(
            name: "Nikon Z fc",
            productID: 0x044f,
            detectionTokens: ["nikon zfc", "nikon z fc"],
            minimumISO: 100,
            maximumISO: 51200
        ),
        SupportedCamera(
            name: "Nikon Z9",
            productID: 0x0450,
            detectionTokens: ["nikon z9", "nikon z 9"],
            minimumISO: 64,
            maximumISO: 25600
        ),
        SupportedCamera(
            name: "Nikon Z8",
            productID: 0x0451,
            detectionTokens: ["nikon z8", "nikon z 8"],
            minimumISO: 64,
            maximumISO: 25600
        ),
        SupportedCamera(
            name: "Nikon Z30",
            productID: 0x0452,
            detectionTokens: ["nikon z30", "nikon z 30"],
            minimumISO: 100,
            maximumISO: 51200
        ),
        SupportedCamera(
            name: "Nikon Z f",
            productID: 0x0453,
            detectionTokens: ["nikon zf", "nikon z f"],
            minimumISO: 100,
            maximumISO: 64000
        ),
        SupportedCamera(
            name: "Nikon Z6III",
            productID: 0x0454,
            detectionTokens: ["nikon z6 iii", "nikon z6iii", "nikon z6 3"],
            minimumISO: 100,
            maximumISO: 64000
        ),
        SupportedCamera(
            name: "Nikon Z50II",
            productID: 0x0455,
            detectionTokens: [
                "nikon z50 2", "nikon z50 ii", "nikon z50ii", "nikon z50_2"
            ],
            minimumISO: 100,
            maximumISO: 51200
        ),
        SupportedCamera(
            name: "Nikon Z5II",
            productID: 0x0456,
            detectionTokens: ["nikon z5 2", "nikon z5 ii", "nikon z5ii"],
            minimumISO: 100,
            maximumISO: 64000
        ),
        SupportedCamera(
            name: "Nikon ZR",
            productID: 0x0457,
            detectionTokens: ["nikon zr", "nikon z r"],
            minimumISO: 100,
            maximumISO: 51200
        )
    ]

    static var summary: String {
        all.map { $0.name.replacingOccurrences(of: "Nikon ", with: "") }
            .joined(separator: " · ")
    }

    static func matching(detection: String) -> SupportedCamera? {
        let normalized = detection
            .lowercased()
            .replacingOccurrences(of: ":", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
        return all.compactMap { camera -> (camera: SupportedCamera, length: Int)? in
            let length = camera.detectionTokens
                .filter { normalized.contains($0) }
                .map(\.count)
                .max()
            guard let length else { return nil }
            return (camera, length)
        }
        .max { $0.length < $1.length }?
        .camera
    }

    static func matching(productID: Int) -> SupportedCamera? {
        all.first { $0.productID == productID }
    }

    static func isoOptions(for cameraName: String?) -> [Int] {
        let profile = all.first { $0.name == cameraName }
        let minimum = profile?.minimumISO ?? 100
        let maximum = profile?.maximumISO ?? 64000
        return [
            64, 80, 100, 125, 160, 200, 250, 320, 400, 500, 640,
            800, 1000, 1250, 1600, 2000, 2500, 3200, 4000, 5000,
            6400, 8000, 10000, 12800, 16000, 20000, 25600, 32000,
            40000, 51200, 64000, 80000, 102400
        ].filter { $0 >= minimum && $0 <= maximum }
    }
}

private enum CameraError: LocalizedError {
    case command(String)
    case timeout(String)
    case thermal(String)
    case liveViewBusy(String)
    case noCamera
    case wrongCamera(String)
    case noImage

    var errorDescription: String? {
        switch self {
        case .command(let value): return value
        case .timeout(let value):
            return "\(value) 的 PTP 会话超时。帧澈 ZENCHE 已尝试复位 USB 连接，请重新连接相机。"
        case .thermal(let value):
            return "\(value) 温度过高，已停止实时取景。请关闭相机并等待冷却后再试。"
        case .liveViewBusy(let value):
            return "\(value) 正在处理拍摄操作，已暂停实时取景。请等待存储卡写入、间隔拍摄或长曝光结束后再开启。"
        case .noCamera:
            return "没有检测到支持的 Nikon 相机（\(SupportedCamera.summary)）。请使用 USB 数据线直连，并关闭 NX Tether 等占用相机的软件。"
        case .wrongCamera(let value):
            return "检测到 \(value)，当前版本支持 \(SupportedCamera.summary)。"
        case .noImage:
            return "相机没有返回可用的 JPEG 图像。"
        }
    }
}

private final class GPhotoCamera {
    private struct CommandResult {
        let status: Int32
        let output: String
    }

    private let resources = Bundle.main.resourceURL!
    private let logger = DiagnosticLogger.shared
    private var connected = false
    private var liveView = false
    private var movieRecording = false
    private var activeProcess: Process?
    private var liveViewProcess: Process?
    private var liveViewOutput: Pipe?
    private var liveViewErrors: Pipe?
    private var liveViewDecoder = MJPEGFrameDecoder()
    private var liveViewStartedAt: Date?
    private var lastPreviewAt: Date?
    private var previewReadAttempts = 0
    private var previewFrameWindowStartedAt: Date?
    private var previewFramesInWindow = 0
    private var liveViewErrorBuffer = Data()
    private(set) var profile: SupportedCamera?
    private(set) var parameterWritable: [String: Bool] = [:]
    private var parameterConfigKeys: [String: [String]] = [:]

    var isLiveViewActive: Bool { liveView }

    private var cameraName: String {
        profile?.name ?? "Nikon 相机"
    }

    private var executable: URL {
        let bundled = resources.appendingPathComponent("bin/gphoto2")
        return FileManager.default.isExecutableFile(atPath: bundled.path)
            ? bundled
            : URL(fileURLWithPath: "/opt/homebrew/bin/gphoto2")
    }

    private var processEnvironment: [String: String] {
        var environment = ProcessInfo.processInfo.environment
        environment["CAMLIBS"] = resources.appendingPathComponent("camlibs").path
        environment["IOLIBS"] = resources.appendingPathComponent("iolibs").path
        environment["DYLD_LIBRARY_PATH"] = resources.appendingPathComponent("lib").path
        environment["LC_ALL"] = "C"
        return environment
    }

    private func execute(
        _ arguments: [String],
        timeout: TimeInterval,
        guardUSBClaim: Bool
    ) throws -> CommandResult {
        let command = diagnosticCommandName(arguments)
        let isPreviewCommand = arguments.contains("--capture-preview")
        let startedAt = Date()
        if !isPreviewCommand {
            logger.debug(
                "gphoto",
                "执行 \(command)；超时=\(Int(timeout)) 秒；USB保护=\(guardUSBClaim)"
            )
        }
        let process = Process()
        let output = Pipe()
        process.executableURL = executable
        process.arguments = ["--quiet"] + arguments
        process.standardOutput = output
        process.standardError = output
        process.environment = processEnvironment
        if let filenameIndex = arguments.firstIndex(of: "--filename"),
           arguments.indices.contains(filenameIndex + 1) {
            process.currentDirectoryURL = URL(
                fileURLWithPath: arguments[filenameIndex + 1]
            ).deletingLastPathComponent()
        } else {
            process.currentDirectoryURL = FileManager.default.temporaryDirectory
        }
        if guardUSBClaim {
            releaseSystemPTPCamera()
        }
        do {
            try process.run()
        } catch {
            logger.error(
                "gphoto",
                "无法启动 \(command)：\(error.localizedDescription)"
            )
            throw error
        }
        activeProcess = process
        defer {
            if activeProcess === process {
                activeProcess = nil
            }
        }

        if guardUSBClaim {
            let claimDeadline = Date().addingTimeInterval(0.35)
            while process.isRunning && Date() < claimDeadline {
                releaseSystemPTPCamera()
                Thread.sleep(forTimeInterval: 0.01)
            }
        }
        let deadline = Date().addingTimeInterval(timeout)
        while process.isRunning && Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }
        if process.isRunning {
            _ = Darwin.kill(process.processIdentifier, SIGKILL)
            process.waitUntilExit()
            let data = output.fileHandleForReading.readDataToEndOfFile()
            let text = String(decoding: data, as: UTF8.self)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            logger.error(
                "gphoto",
                "\(command) 超时；耗时=\(elapsed(from: startedAt)) 秒；输出=\(text.isEmpty ? "<无>" : text)"
            )
            throw CameraError.timeout(cameraName)
        }
        let data = output.fileHandleForReading.readDataToEndOfFile()
        let text = String(decoding: data, as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let result = CommandResult(
            status: process.terminationStatus,
            output: text
        )
        if result.status != 0 {
            logger.error(
                "gphoto",
                "\(command) 失败；状态=\(result.status)；耗时=\(elapsed(from: startedAt)) 秒；输出=\(text.isEmpty ? "<无>" : text)"
            )
        } else if !isPreviewCommand {
            logger.debug(
                "gphoto",
                "\(command) 完成；耗时=\(elapsed(from: startedAt)) 秒"
            )
        }
        return result
    }

    private func run(
        _ arguments: [String],
        timeout: TimeInterval = 45,
        reclaimUSB: Bool = true
    ) throws -> String {
        for attempt in 0..<2 {
            let result: CommandResult
            do {
                result = try execute(
                    arguments,
                    timeout: timeout,
                    guardUSBClaim: reclaimUSB
                )
            } catch let error as CameraError {
                if attempt == 0, reclaimUSB, case .timeout = error {
                    logger.warning(
                        "camera",
                        "\(diagnosticCommandName(arguments)) 超时，准备复位 USB 后重试"
                    )
                    resetUSBConnection()
                    continue
                }
                throw error
            }
            if result.status == 0 {
                return result.output
            }
            if isThermalFailure(result.output) {
                throw CameraError.thermal(cameraName)
            }
            if attempt == 0,
               reclaimUSB,
               isUSBClaimFailure(result.output)
                || isPTPTimeoutFailure(result.output) {
                let reason = isUSBClaimFailure(result.output)
                    ? "USB/PTP 接口被占用"
                    : "PTP 会话超时"
                logger.warning(
                    "camera",
                    "\(diagnosticCommandName(arguments)) 检测到\(reason)，准备第 2 次尝试"
                )
                if isPTPTimeoutFailure(result.output) {
                    resetUSBConnection()
                }
                continue
            }
            throw CameraError.command(userFacingError(for: result.output))
        }
        throw CameraError.command("\(cameraName) 返回了错误状态。")
    }

    private func resetUSBConnection() {
        logger.warning("usb", "开始复位相机 USB/PTP 连接")
        _ = try? execute(
            ["--reset"],
            timeout: 8,
            guardUSBClaim: true
        )
        Thread.sleep(forTimeInterval: 0.5)
    }

    private func diagnosticCommandName(_ arguments: [String]) -> String {
        if arguments.contains("--auto-detect") { return "检测相机" }
        if arguments.contains("--summary") { return "读取相机摘要" }
        if arguments.contains("--capture-preview") { return "获取实时取景帧" }
        if arguments.contains("--capture-image-and-download") { return "拍摄并下载" }
        if arguments.contains("--wait-event-and-download=20s") { return "B 门拍摄并下载" }
        if arguments.contains("--reset") { return "复位 USB/PTP" }
        if let index = arguments.firstIndex(of: "--set-config"),
           arguments.indices.contains(index + 1) {
            let setting = arguments[index + 1]
                .split(separator: "=", maxSplits: 1)
                .first
                .map(String.init) ?? "未知参数"
            return "设置相机参数 \(setting)"
        }
        return arguments.first ?? "gphoto2"
    }

    private func elapsed(from date: Date) -> String {
        String(format: "%.2f", Date().timeIntervalSince(date))
    }

    private func isPTPTimeoutFailure(_ output: String) -> Bool {
        let normalized = output.lowercased()
        return normalized.contains("ptp timeout")
            || normalized.contains("timeout reading from or writing to the port")
            || normalized.contains("error (-10")
    }

    private func isThermalFailure(_ output: String) -> Bool {
        let normalized = output.lowercased()
        return normalized.contains("temperature too high")
            || normalized.contains("温度过高")
    }

    private func isUSBClaimFailure(_ output: String) -> Bool {
        let normalized = output.lowercased()
        return normalized.contains("could not claim interface")
            || normalized.contains("could not claim the usb device")
            || normalized.contains("unable to claim usb")
            || normalized.contains("无法获取 usb 设备的控制权")
            || normalized.contains("error (-53")
            || normalized.contains("错误 (-53")
    }

    private func userFacingError(for output: String) -> String {
        guard !output.isEmpty else {
            return "\(cameraName) 返回了错误状态。"
        }
        if isUSBClaimFailure(output) {
            return """
            \(cameraName) 的 USB/PTP 接口仍被其他程序占用。帧澈 ZENCHE 已尝试释放 \
            macOS 相机服务；请退出“照片”“图像捕捉”、NX Tether 和 Camera Control \
            Pro，重新插拔相机后再连接。
            """
        }
        if isPTPTimeoutFailure(output) {
            return "\(cameraName) 的 PTP 会话超时。请重新连接相机。"
        }
        return output
    }

    private func releaseSystemPTPCamera() {
        let expectedCount = proc_listallpids(nil, 0)
        guard expectedCount > 0 else { return }
        var pids = [pid_t](
            repeating: 0,
            count: Int(expectedCount) + 32
        )
        let count = proc_listallpids(
            &pids,
            Int32(pids.count * MemoryLayout<pid_t>.stride)
        )
        guard count > 0 else { return }

        for pid in pids.prefix(Int(count)) {
            var name = [CChar](repeating: 0, count: Int(MAXPATHLEN))
            guard proc_name(pid, &name, UInt32(name.count)) > 0 else {
                continue
            }
            let processName = String(cString: name)
            if processName == "ptpcamerad" || processName == "PTPCamera" {
                if Darwin.kill(pid, SIGKILL) == 0 {
                    logger.info(
                        "usb",
                        "已停止占用相机接口的 macOS 服务 \(processName)"
                    )
                }
            }
        }
    }

    private func detectedUSBProfile() -> SupportedCamera? {
        let process = Process()
        let output = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/system_profiler")
        process.arguments = ["SPUSBDataType", "-json"]
        process.standardOutput = output
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return nil }
            let data = output.fileHandleForReading.readDataToEndOfFile()
            let root = try JSONSerialization.jsonObject(with: data)
            return findUSBProfile(in: root)
        } catch {
            return nil
        }
    }

    private func findUSBProfile(in value: Any) -> SupportedCamera? {
        if let dictionary = value as? [String: Any] {
            let vendor = hexValue(dictionary["vendor_id"])
            let product = hexValue(dictionary["product_id"])
            if vendor == 0x04b0 {
                if let product,
                   let match = SupportedCamera.matching(productID: product) {
                    return match
                }
                let descriptor = dictionary.values
                    .compactMap { $0 as? String }
                    .joined(separator: " ")
                if let match = SupportedCamera.matching(detection: descriptor) {
                    return match
                }
            }
            for child in dictionary.values {
                if let match = findUSBProfile(in: child) { return match }
            }
        } else if let array = value as? [Any] {
            for child in array {
                if let match = findUSBProfile(in: child) { return match }
            }
        }
        return nil
    }

    private func hexValue(_ value: Any?) -> Int? {
        guard let text = value as? String,
              let range = text.range(
                of: #"0x[0-9a-fA-F]+"#,
                options: .regularExpression
              ) else {
            return nil
        }
        return Int(text[range].dropFirst(2), radix: 16)
    }

    func connect() throws -> SupportedCamera {
        logger.info("camera", "开始连接相机")
        let detected = try run(["--auto-detect"], reclaimUSB: false)
        let matchedProfile =
            SupportedCamera.matching(detection: detected)
            ?? detectedUSBProfile()
        guard let matchedProfile else {
            if !detected.localizedCaseInsensitiveContains("nikon"),
               !detected.localizedCaseInsensitiveContains("ptp class camera") {
                logger.error("camera", "连接失败：未检测到支持的相机")
                throw CameraError.noCamera
            }
            let name = detected.split(separator: "\n").last.map(String.init) ?? "其他 Nikon 相机"
            logger.error("camera", "连接失败：检测到不支持的相机 \(name)")
            throw CameraError.wrongCamera(name)
        }
        profile = matchedProfile
        _ = try run(["--summary"])
        connected = true
        refreshParameterCapabilities()
        logger.info("camera", "已连接 \(matchedProfile.name)")
        return matchedProfile
    }

    private func refreshParameterCapabilities() {
        let keys: [String: [String]] = [
            "exposureTime": ["shutterspeed2", "shutterspeed"],
            "videoExposureTime": [
                "movieshutterspeed",
                "shutterspeed",
                "shutterspeed2"
            ],
            "aperture": ["f-number"],
            "iso": ["iso"],
            "exposureCompensation": ["exposurecompensation"],
            "whiteBalanceMode": ["whitebalance"],
            "focusMode": ["focusmode", "liveviewaffocus"],
            "exposureMode": ["expprogram"],
            "pictureControl": ["picturecontrol", "activepicctrlitem", "d200"]
        ]
        var result: [String: Bool] = [:]
        var writableKeys: [String: [String]] = [:]
        for (name, candidates) in keys {
            var discovered: [Bool] = []
            for key in candidates {
                guard let output = try? run(["--get-config", key]) else {
                    continue
                }
                let readOnly = output
                    .split(separator: "\n")
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .first { $0.lowercased().hasPrefix("readonly:") }
                if let readOnly {
                    let isReadOnly =
                        readOnly.split(separator: ":").last?
                        .trimmingCharacters(in: .whitespaces) != "0"
                    discovered.append(isReadOnly)
                    if !isReadOnly {
                        writableKeys[name, default: []].append(key)
                    }
                }
            }
            if discovered.contains(false) {
                result[name] = true
            }
        }
        parameterWritable = result
        parameterConfigKeys = writableKeys
    }

    func parameterCapabilitySnapshot() -> [String: Bool] {
        parameterWritable
    }

    func startLiveView() throws {
        guard connected else { throw CameraError.noCamera }
        liveView = true
        do {
            try startLiveViewProcessIfNeeded()
            logger.info("liveview", "已启动持续实时取景会话")
        } catch {
            liveView = false
            throw error
        }
    }

    func stopLiveView() {
        if liveView {
            logger.info("liveview", "正在停止持续实时取景会话")
        }
        liveView = false
        stopLiveViewProcess()
    }

    private func startLiveViewProcessIfNeeded() throws {
        if let liveViewProcess, liveViewProcess.isRunning {
            return
        }
        stopLiveViewProcess()

        let process = Process()
        let output = Pipe()
        let errors = Pipe()
        process.executableURL = executable
        process.arguments = [
            "--quiet",
            "--capture-movie",
            "--stdout"
        ]
        process.standardOutput = output
        process.standardError = errors
        process.environment = processEnvironment
        process.currentDirectoryURL = FileManager.default.temporaryDirectory

        releaseSystemPTPCamera()
        do {
            try process.run()
        } catch {
            logger.error(
                "liveview",
                "无法启动持续实时取景进程：\(error.localizedDescription)"
            )
            throw error
        }

        liveViewProcess = process
        liveViewOutput = output
        liveViewErrors = errors
        liveViewDecoder.reset()
        liveViewErrorBuffer.removeAll(keepingCapacity: true)
        liveViewStartedAt = Date()
        lastPreviewAt = nil
        previewReadAttempts = 0
        previewFrameWindowStartedAt = Date()
        previewFramesInWindow = 0

        let claimDeadline = Date().addingTimeInterval(0.35)
        while process.isRunning && Date() < claimDeadline {
            releaseSystemPTPCamera()
            Thread.sleep(forTimeInterval: 0.01)
        }
        guard process.isRunning else {
            let error = liveViewProcessError()
            clearLiveViewProcess()
            throw error
        }
        logger.info(
            "liveview",
            "持续实时取景进程已就绪；PID=\(process.processIdentifier)"
        )
    }

    private func stopLiveViewProcess() {
        guard let process = liveViewProcess else {
            clearLiveViewProcess()
            return
        }

        if process.isRunning {
            process.interrupt()
            let deadline = Date().addingTimeInterval(1.5)
            while process.isRunning && Date() < deadline {
                discardAvailableLiveViewOutput()
                appendAvailableLiveViewErrors()
                Thread.sleep(forTimeInterval: 0.02)
            }
        }
        if process.isRunning {
            _ = Darwin.kill(process.processIdentifier, SIGKILL)
        }
        process.waitUntilExit()

        let errorText = readLiveViewErrors()
        if process.terminationStatus != 0,
           process.terminationReason != .uncaughtSignal,
           !errorText.isEmpty {
            logger.warning(
                "liveview",
                "持续实时取景进程结束；状态=\(process.terminationStatus)；输出=\(errorText)"
            )
        }
        clearLiveViewProcess()
    }

    private func discardAvailableLiveViewOutput() {
        guard let output = liveViewOutput else { return }
        var descriptor = pollfd(
            fd: output.fileHandleForReading.fileDescriptor,
            events: Int16(POLLIN),
            revents: 0
        )
        var chunksRead = 0
        while chunksRead < 8,
              Darwin.poll(&descriptor, 1, 0) > 0,
              descriptor.revents & Int16(POLLIN) != 0 {
            guard readAvailableLiveViewChunk(from: output) != nil else {
                break
            }
            chunksRead += 1
            descriptor.revents = 0
        }
    }

    private func appendAvailableLiveViewOutput() {
        guard let output = liveViewOutput else { return }
        var descriptor = pollfd(
            fd: output.fileHandleForReading.fileDescriptor,
            events: Int16(POLLIN),
            revents: 0
        )
        var chunksRead = 0
        while chunksRead < 8,
              Darwin.poll(&descriptor, 1, 0) > 0,
              descriptor.revents & Int16(POLLIN) != 0 {
            guard let data = readAvailableLiveViewChunk(from: output) else {
                break
            }
            liveViewDecoder.append(data)
            chunksRead += 1
            descriptor.revents = 0
        }
    }

    private func appendAvailableLiveViewErrors() {
        guard let errors = liveViewErrors else { return }
        var descriptor = pollfd(
            fd: errors.fileHandleForReading.fileDescriptor,
            events: Int16(POLLIN),
            revents: 0
        )
        var chunksRead = 0
        while chunksRead < 8,
              Darwin.poll(&descriptor, 1, 0) > 0,
              descriptor.revents & Int16(POLLIN) != 0 {
            guard let data = readAvailableLiveViewChunk(from: errors) else {
                break
            }
            liveViewErrorBuffer.append(data)
            if liveViewErrorBuffer.count > 256 * 1024 {
                liveViewErrorBuffer.removeFirst(
                    liveViewErrorBuffer.count - 256 * 1024
                )
            }
            chunksRead += 1
            descriptor.revents = 0
        }
    }

    private func readAvailableLiveViewChunk(from output: Pipe) -> Data? {
        var data = Data(count: 64 * 1024)
        let bytesRead = data.withUnsafeMutableBytes { buffer in
            Darwin.read(
                output.fileHandleForReading.fileDescriptor,
                buffer.baseAddress,
                buffer.count
            )
        }
        guard bytesRead > 0 else { return nil }
        data.count = bytesRead
        return data
    }

    private func recordDeliveredPreviewFrame(_ frame: Data) {
        previewFramesInWindow += 1
        guard let startedAt = previewFrameWindowStartedAt else {
            previewFrameWindowStartedAt = Date()
            return
        }
        let duration = Date().timeIntervalSince(startedAt)
        guard duration >= 10 else { return }
        let framesPerSecond = Double(previewFramesInWindow) / duration
        logger.debug(
            "liveview",
            "显示帧率=\(String(format: "%.1f", framesPerSecond)) fps；最近帧=\(frame.count) 字节；缓存=\(liveViewDecoder.bufferedByteCount) 字节"
        )
        previewFrameWindowStartedAt = Date()
        previewFramesInWindow = 0
    }

    private func clearLiveViewProcess() {
        try? liveViewOutput?.fileHandleForReading.close()
        try? liveViewErrors?.fileHandleForReading.close()
        liveViewProcess = nil
        liveViewOutput = nil
        liveViewErrors = nil
        liveViewDecoder.reset()
        liveViewErrorBuffer.removeAll(keepingCapacity: true)
        liveViewStartedAt = nil
        lastPreviewAt = nil
        previewReadAttempts = 0
        previewFrameWindowStartedAt = nil
        previewFramesInWindow = 0
    }

    private func readLiveViewErrors() -> String {
        appendAvailableLiveViewErrors()
        var data = liveViewErrorBuffer
        if let errors = liveViewErrors {
            data.append(errors.fileHandleForReading.readDataToEndOfFile())
        }
        return String(decoding: data, as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func liveViewProcessError() -> CameraError {
        let output = readLiveViewErrors()
        if isThermalFailure(output) {
            return .thermal(cameraName)
        }
        if isShootingOperationFailure(output) {
            return .liveViewBusy(cameraName)
        }
        if output.isEmpty {
            return .command("\(cameraName) 的实时取景进程意外结束。")
        }
        return .command(userFacingError(for: output))
    }

    private func isShootingOperationFailure(_ output: String) -> Bool {
        output.localizedCaseInsensitiveContains(
            "processing of shooting operation"
        )
    }

    private func readPreviewFrame() throws -> Data {
        guard liveView else {
            throw CameraError.command("实时取景尚未开启。")
        }
        try startLiveViewProcessIfNeeded()
        guard let process = liveViewProcess,
              let output = liveViewOutput else {
            throw CameraError.command("\(cameraName) 的实时取景进程未启动。")
        }

        let timeout: TimeInterval = previewReadAttempts == 0 ? 8 : 3
        previewReadAttempts += 1
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            appendAvailableLiveViewOutput()
            appendAvailableLiveViewErrors()
            if let frame = liveViewDecoder.latestFrame() {
                let firstFrame = lastPreviewAt == nil
                lastPreviewAt = Date()
                recordDeliveredPreviewFrame(frame)
                if firstFrame {
                    let startupTime = liveViewStartedAt.map {
                        String(format: "%.2f", Date().timeIntervalSince($0))
                    } ?? "未知"
                    logger.info(
                        "liveview",
                        "收到首帧；耗时=\(startupTime) 秒；大小=\(frame.count) 字节"
                    )
                }
                return frame
            }

            if !process.isRunning {
                let error = liveViewProcessError()
                logger.error(
                    "liveview",
                    "持续实时取景进程意外结束：\(error.localizedDescription)"
                )
                clearLiveViewProcess()
                throw error
            }

            var descriptor = pollfd(
                fd: output.fileHandleForReading.fileDescriptor,
                events: Int16(POLLIN | POLLHUP | POLLERR),
                revents: 0
            )
            let remaining = max(0, deadline.timeIntervalSinceNow)
            let waitMilliseconds = Int32(
                min(200, max(1, Int(remaining * 1_000)))
            )
            let ready = Darwin.poll(&descriptor, 1, waitMilliseconds)
            if ready < 0 {
                if errno == EINTR { continue }
                throw CameraError.command(
                    "读取 \(cameraName) 实时取景数据失败。"
                )
            }
            if ready == 0 { continue }

            if descriptor.revents & Int16(POLLIN) != 0 {
                if let data = readAvailableLiveViewChunk(from: output) {
                    liveViewDecoder.append(data)
                }
            }
        }

        logger.warning(
            "liveview",
            "等待实时取景帧超时；进程运行=\(process.isRunning)；缓存=\(liveViewDecoder.bufferedByteCount) 字节"
        )
        throw CameraError.noImage
    }

    private func performWithoutLiveView<T>(
        _ operation: () throws -> T
    ) throws -> T {
        let shouldResume = liveView
        if shouldResume {
            stopLiveViewProcess()
            Thread.sleep(forTimeInterval: 0.2)
        }
        defer {
            if shouldResume {
                Thread.sleep(forTimeInterval: 0.2)
                do {
                    try startLiveViewProcessIfNeeded()
                } catch {
                    logger.error(
                        "liveview",
                        "独占相机操作后恢复实时取景失败：\(error.localizedDescription)"
                    )
                }
            }
        }
        return try operation()
    }

    private func imageData(
        prefix: String,
        preview: Bool,
        bulbSeconds: Int? = nil
    ) throws -> Data {
        guard connected else { throw CameraError.noCamera }
        if preview && !liveView {
            throw CameraError.command("实时取景尚未开启。")
        }
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("ZENCHE", isDirectory: true)
        try FileManager.default.createDirectory(
            at: folder,
            withIntermediateDirectories: true
        )
        let stem = "\(prefix)-\(UUID().uuidString)"
        let target = folder.appendingPathComponent(
            preview ? "\(stem).jpg" : "\(stem).%C"
        )
        let arguments: [String]
        let timeout: TimeInterval
        if preview {
            arguments = ["--capture-preview", "--filename", target.path, "--force-overwrite"]
            timeout = 6
        } else if let bulbSeconds {
            let duration = max(1, min(bulbSeconds, 900))
            arguments = [
                "--filename", target.path,
                "--force-overwrite",
                "--set-config", "bulb=1",
                "--wait-event=\(duration)s",
                "--set-config", "bulb=0",
                "--wait-event-and-download=20s"
            ]
            timeout = TimeInterval(duration + 45)
        } else {
            arguments = [
                "--filename", target.path,
                "--force-overwrite",
                "--capture-image-and-download"
            ]
            timeout = 60
        }
        let commandOutput = try run(arguments, timeout: timeout)
        let files = try FileManager.default.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: nil
        )
        let candidateFiles = files.filter {
            $0.lastPathComponent.contains(stem)
        }
        guard let image = candidateFiles
            .sorted(by: {
                $0.pathExtension.lowercased() == "jpg"
                    && $1.pathExtension.lowercased() != "jpg"
            })
            .first,
            let data = try? Data(contentsOf: image),
            !data.isEmpty
        else {
            let candidates = candidateFiles
                .map {
                    $0.pathExtension.isEmpty
                        ? "<无扩展名>"
                        : $0.pathExtension
                }
                .joined(separator: ", ")
            logger.error(
                preview ? "liveview" : "capture",
                "命令成功但未找到可用图像；候选文件=\(candidates.isEmpty ? "<无>" : candidates)；gphoto输出=\(commandOutput.isEmpty ? "<无>" : commandOutput)"
            )
            throw CameraError.noImage
        }
        for candidate in candidateFiles {
            try? FileManager.default.removeItem(at: candidate)
        }
        if !preview {
            logger.info("capture", "已从相机接收照片；大小=\(data.count) 字节")
        }
        return data
    }

    func preview() throws -> Data {
        try readPreviewFrame()
    }

    func capture(bulbSeconds: Int? = nil) throws -> Data {
        try performWithoutLiveView {
            try imageData(
                prefix: "capture",
                preview: false,
                bulbSeconds: bulbSeconds
            )
        }
    }

    func startMovieRecording() throws {
        guard connected else { throw CameraError.noCamera }
        guard !movieRecording else { return }
        try performWithoutLiveView {
            _ = try run(["--set-config", "movie=1"])
            movieRecording = true
        }
        logger.info("recording", "已开始向 \(cameraName) 存储卡录制视频")
    }

    func stopMovieRecording() throws {
        guard connected else { throw CameraError.noCamera }
        guard movieRecording else { return }
        try performWithoutLiveView {
            _ = try run(["--set-config", "movie=0"])
            movieRecording = false
        }
        logger.info("recording", "已停止 \(cameraName) 视频录制")
    }

    func setParameter(name: String, value: Any) throws {
        try performWithoutLiveView {
            try setParameterWithoutLiveView(name: name, value: value)
        }
    }

    func moveFocus(_ signedStep: Int) throws {
        guard connected else { throw CameraError.noCamera }
        guard liveView else {
            throw CameraError.command("焦点步进仅能在实时取景开启时使用。")
        }
        let normalized = max(-3, min(3, signedStep))
        guard normalized != 0 else { return }
        let amount: Int
        switch abs(normalized) {
        case 1: amount = 128
        case 2: amount = 512
        default: amount = 1024
        }
        let value = normalized < 0 ? -amount : amount
        try performWithoutLiveView {
            _ = try run([
                "--set-config",
                "viewfinder=1",
                "--set-config",
                "manualfocusdrive=\(value)"
            ])
        }
    }

    private func setShutterConfig(
        name: String,
        formatted: String
    ) throws {
        let fallbackKeys = name == "videoExposureTime"
            ? ["movieshutterspeed", "shutterspeed", "shutterspeed2"]
            : ["shutterspeed2", "shutterspeed"]
        let candidates = parameterConfigKeys[name].flatMap {
            $0.isEmpty ? nil : $0
        } ?? fallbackKeys
        var finalError: Error?
        for key in candidates {
            do {
                _ = try run(["--set-config", "\(key)=\(formatted)"])
                logger.info(
                    "settings",
                    "快门设置成功；config=\(key)；video=\(name == "videoExposureTime")"
                )
                return
            } catch {
                finalError = error
            }
        }
        throw CameraError.command(
            "\(cameraName) 当前没有可写的\(name == "videoExposureTime" ? "视频" : "照片")快门配置。"
                + "请确认相机处于 M/S 模式，且未在机身菜单中锁定曝光参数。"
                + (finalError.map { "（\($0.localizedDescription)）" } ?? "")
        )
    }

    private func setParameterWithoutLiveView(
        name: String,
        value: Any
    ) throws {
        guard connected else { throw CameraError.noCamera }
        let key: String
        let formatted: String
        switch name {
        case "exposureTime", "videoExposureTime":
            let number = (value as? NSNumber)?.doubleValue ?? 0.008
            let shutterValue = number < 1
                ? "1/\(Int((1 / number).rounded()))"
                : String(number)
            try setShutterConfig(name: name, formatted: shutterValue)
            return
        case "aperture":
            key = "f-number"
            formatted = String(describing: value)
        case "iso":
            key = "iso"
            formatted = String(Int((value as? NSNumber)?.doubleValue ?? 400))
        case "exposureCompensation":
            key = "exposurecompensation"
            let thirds = Int(
                (((value as? NSNumber)?.doubleValue ?? 0) * 3).rounded()
            )
            formatted = thirds.isMultiple(of: 3)
                ? String(thirds / 3)
                : String(format: "%.3f", Double(thirds) / 3)
        case "whiteBalanceMode":
            key = "whitebalance"
            formatted = String(describing: value) == "continuous" ? "Automatic" : "Preset"
        case "focusMode":
            let mode = String(describing: value)
            let stillValue = mode == "continuous"
                ? "Continuous-servo AF"
                : mode == "manual" ? "Manual" : "Single-servo AF"
            let liveViewValue = mode == "continuous"
                ? "Continuous-servo AF"
                : mode == "manual" ? "Manual Focus (selection)" : "Single-servo AF"
            var finalError: Error?
            for attempt in [
                "focusmode=\(stillValue)",
                "liveviewaffocus=\(liveViewValue)"
            ] {
                do {
                    _ = try run(["--set-config", attempt])
                    return
                } catch {
                    finalError = error
                }
            }
            throw finalError ?? CameraError.command("\(cameraName) 不支持远程切换对焦模式。")
        case "exposureMode":
            let mode = String(describing: value)
            if mode == "bulb" {
                _ = try run(["--set-config", "expprogram=M"])
                return
            }
            key = "expprogram"
            switch mode {
            case "manual": formatted = "M"
            case "aperturePriority": formatted = "A"
            case "shutterPriority": formatted = "S"
            default: formatted = "P"
            }
        case "pictureControl":
            let modes = [
                "standard": ("Standard", "1"),
                "neutral": ("Neutral", "2"),
                "vivid": ("Vivid", "3"),
                "monochrome": ("Monochrome", "4"),
                "portrait": ("Portrait", "5"),
                "landscape": ("Landscape", "6"),
                "flat": ("Flat", "7"),
                "auto": ("Auto", "8")
            ]
            let selected = modes[String(describing: value)] ?? modes["standard"]!
            let attempts = [
                "picturecontrol=\(selected.0)",
                "activepicctrlitem=\(selected.1)",
                "d200=\(selected.1)"
            ]
            var finalError: Error?
            for attempt in attempts {
                do {
                    _ = try run(["--set-config", attempt])
                    return
                } catch {
                    finalError = error
                }
            }
            throw finalError ?? CameraError.command("\(cameraName) 不支持“设定优化校准”远程设置。")
        default:
            throw CameraError.command("\(cameraName) 不支持此参数：\(name)")
        }
        _ = try run(["--set-config", "\(key)=\(formatted)"])
        if name == "exposureMode" {
            refreshParameterCapabilities()
        }
    }

    private func parameterDisplayName(_ name: String) -> String {
        [
            "exposureTime": "快门速度",
            "videoExposureTime": "视频快门速度",
            "aperture": "光圈",
            "iso": "ISO",
            "exposureCompensation": "曝光补偿",
            "whiteBalanceMode": "白平衡",
            "focusMode": "对焦模式",
            "exposureMode": "拍摄模式",
            "pictureControl": "优化校准"
        ][name] ?? "参数"
    }

    func disconnect() {
        logger.info("camera", "正在断开相机")
        if movieRecording {
            try? stopMovieRecording()
        }
        stopLiveView()
        if let activeProcess, activeProcess.isRunning {
            _ = Darwin.kill(activeProcess.processIdentifier, SIGKILL)
        }
        connected = false
        movieRecording = false
        profile = nil
        parameterWritable = [:]
        parameterConfigKeys = [:]
        logger.info("camera", "相机已断开")
    }
}

private struct PhotoRecord: Identifiable, Hashable {
    let url: URL
    let createdAt: Date
    var id: URL { url }
    var name: String { url.lastPathComponent }
    var isVideo: Bool {
        ["mov", "mp4", "m4v"].contains(url.pathExtension.lowercased())
    }
}

private enum AppSection: String, CaseIterable, Identifiable {
    case capture = "照片"
    case monitor = "视频"
    case library = "文件与传输"

    var id: String { rawValue }
    var icon: String {
        switch self {
        case .capture: return "camera.aperture"
        case .monitor: return "movieclapper.fill"
        case .library: return "photo.on.rectangle.angled"
        }
    }
}

private enum MonitorVideoProfile: String, CaseIterable, Identifiable {
    case source
    case hd720
    case hd1080

    var id: String { rawValue }

    var label: String {
        switch self {
        case .source: return "实时取景原始尺寸"
        case .hd720: return "1280 × 720"
        case .hd1080: return "1920 × 1080"
        }
    }

    var targetSize: NSSize? {
        switch self {
        case .source: return nil
        case .hd720: return NSSize(width: 1280, height: 720)
        case .hd1080: return NSSize(width: 1920, height: 1080)
        }
    }
}

private enum ShootingTaskKind: String, CaseIterable, Identifiable {
    case interval = "间隔拍摄"
    case exposureBracket = "曝光包围"
    case focusBracket = "焦点包围"
    case bulb = "B 门计时"

    var id: String { rawValue }
}

private final class CameraModel: ObservableObject {
    @Published var connected = false
    @Published var connecting = false
    @Published var liveViewEnabled = false
    @Published var capturing = false
    @Published var videoRecording = false
    @Published var frame: NSImage?
    @Published var photoFrame: NSImage?
    @Published var status = "未连接"
    @Published var detail = "USB/PTP · 支持 \(SupportedCamera.summary)"
    @Published var cameraName: String?
    @Published var section: AppSection = .capture
    @Published var photos: [PhotoRecord] = []
    @Published var selectedPhoto: PhotoRecord?
    @Published var errorMessage: String?
    @Published var iso = 400
    @Published var aperture = 4.0
    @Published var shutter = 0.008
    @Published var compensation = 0.0
    @Published var focusMode = "single-shot"
    @Published var whiteBalance = "continuous"
    @Published var exposureMode = "manual"
    @Published var parameterWritable: [String: Bool] = [:]
    @Published var bulbSeconds = 5
    @Published var pictureControl = "standard"
    @Published var zebraEnabled = false
    @Published var zebraThreshold = 95.0
    @Published var zebraMask: NSImage?
    @Published var lutEnabled = false
    @Published var lutName: String?
    @Published var monitorVideoProfile: MonitorVideoProfile = .source
    @Published var videoFrameRate = 30.0
    @Published var videoShutterAngle = 180.0
    @Published var focusPeakingEnabled = false
    @Published var falseColorEnabled = false
    @Published var redHistogram = "—"
    @Published var greenHistogram = "—"
    @Published var blueHistogram = "—"
    @Published var waveform = "—"
    @Published var vectorscope = "—"
    @Published var peakingCoverage = 0
    @Published var shootingTaskKind: ShootingTaskKind = .interval
    @Published var shootingTaskCount = 5
    @Published var shootingTaskInterval = 3
    @Published var shootingTaskStep = 1
    @Published var shootingTaskRunning = false
    @Published var shootingTaskProgress = "尚未开始拍摄任务"

    private let camera = GPhotoCamera()
    private let logger = DiagnosticLogger.shared
    private let cameraQueue = DispatchQueue(
        label: "com.tauber.nikonlink.camera",
        qos: .userInitiated
    )
    private let previewProcessingQueue = DispatchQueue(
        label: "com.tauber.nikonlink.preview-processing",
        qos: .userInteractive
    )
    private let previewProcessingLock = NSLock()
    private var previewToken = UUID()
    private var pendingPreview: (token: UUID, image: NSImage)?
    private var previewProcessingActive = false
    private var previewLUT: ColorCubeLUT?
    private var sourceFrame: NSImage?
    private var lastPreviewError: String?
    private var previewFailureCount = 0
    private var shootingTaskToken = UUID()
    private let photoDirectory: URL
    lazy var captureWorkflow = CaptureWorkflow(rootDirectory: photoDirectory)
    lazy var wirelessTransfer = WirelessTransferServer(
        directory: photoDirectory
    ) { [weak self] _ in
        self?.reloadPhotos()
        self?.selectedPhoto = self?.photos.first
    }

    var activeCameraName: String {
        cameraName ?? "Nikon 相机"
    }

    init() {
        let pictures = FileManager.default.urls(
            for: .picturesDirectory,
            in: .userDomainMask
        ).first ?? FileManager.default.homeDirectoryForCurrentUser
        let preferredDirectory = pictures.appendingPathComponent(
            "ZENCHE",
            isDirectory: true
        )
        let legacyDirectory = pictures.appendingPathComponent(
            "Nikon" + " Link",
            isDirectory: true
        )
        if !FileManager.default.fileExists(atPath: preferredDirectory.path),
           FileManager.default.fileExists(atPath: legacyDirectory.path) {
            try? FileManager.default.moveItem(
                at: legacyDirectory,
                to: preferredDirectory
            )
        }
        photoDirectory = preferredDirectory
        try? FileManager.default.createDirectory(
            at: photoDirectory,
            withIntermediateDirectories: true
        )
        if let savedProfile = UserDefaults.standard.string(
            forKey: "monitorVideoProfile"
        ), let profile = MonitorVideoProfile(rawValue: savedProfile) {
            monitorVideoProfile = profile
        }
        let savedFrameRate = UserDefaults.standard.double(forKey: "videoFrameRate")
        if savedFrameRate > 0 {
            videoFrameRate = savedFrameRate
        }
        let savedShutterAngle = UserDefaults.standard.double(forKey: "videoShutterAngle")
        if savedShutterAngle > 0 {
            videoShutterAngle = savedShutterAngle
        }
        shutter = videoShutterAngle / (360 * videoFrameRate)
        reloadPhotos()
    }

    func connect() {
        guard !connecting else { return }
        logger.info("workflow", "用户请求连接相机")
        connecting = true
        status = "正在连接"
        detail = "正在检测 \(SupportedCamera.summary)…"
        cameraQueue.async { [weak self] in
            guard let self else { return }
            do {
                let profile = try self.camera.connect()
                let capabilities = self.camera.parameterCapabilitySnapshot()
                self.logger.info(
                    "workflow",
                    "连接流程完成；相机=\(profile.name)；实时取景=等待用户开启"
                )
                DispatchQueue.main.async {
                    self.connected = true
                    self.connecting = false
                    self.liveViewEnabled = false
                    self.cameraName = profile.name
                    self.status = profile.name
                    self.parameterWritable = capabilities
                    self.detail = "USB/PTP 已连接 · 机身快门可用"
                }
            } catch {
                self.logger.error(
                    "workflow",
                    "连接流程失败：\(error.localizedDescription)"
                )
                DispatchQueue.main.async {
                    self.connected = false
                    self.connecting = false
                    self.status = "未连接"
                    self.detail = "USB/PTP · 连接失败"
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    func disconnect() {
        logger.info("workflow", "用户请求断开相机")
        previewToken = UUID()
        clearPendingPreviewProcessing()
        liveViewEnabled = false
        videoRecording = false
        cameraQueue.async { [weak self] in
            self?.camera.disconnect()
        }
        connected = false
        frame = nil
        photoFrame = nil
        cameraName = nil
        parameterWritable = [:]
        status = "未连接"
        detail = "USB/PTP · 支持 \(SupportedCamera.summary)"
    }

    func toggleLiveView() {
        guard connected else {
            errorMessage = "请先连接支持的 Nikon 相机。"
            return
        }
        if liveViewEnabled {
            logger.info("workflow", "用户关闭实时取景")
            previewToken = UUID()
            clearPendingPreviewProcessing()
            liveViewEnabled = false
            cameraQueue.async { [weak self] in self?.camera.stopLiveView() }
        } else {
            logger.info("workflow", "用户开启实时取景")
            cameraQueue.async { [weak self] in
                guard let self else { return }
                do {
                    try self.camera.startLiveView()
                    DispatchQueue.main.async {
                        self.liveViewEnabled = true
                        self.startPreviewLoop()
                    }
                } catch {
                    self.logger.error(
                        "liveview",
                        "开启实时取景失败：\(error.localizedDescription)"
                    )
                    DispatchQueue.main.async {
                        self.errorMessage = error.localizedDescription
                    }
                }
            }
        }
    }

    private func startPreviewLoop() {
        let token = UUID()
        previewToken = token
        lastPreviewError = nil
        previewFailureCount = 0
        pullPreview(token: token)
    }

    private func pullPreview(token: UUID) {
        guard token == previewToken, connected, liveViewEnabled else { return }
        cameraQueue.async { [weak self] in
            guard let self, token == self.previewToken else { return }
            let pullStartedAt = Date()
            do {
                let data = try self.camera.preview()
                let image = autoreleasepool { NSImage(data: data) }
                let nextFrameDelay = max(
                    0,
                    (1.0 / 30.0) - Date().timeIntervalSince(pullStartedAt)
                )
                let recoveredFrom = self.lastPreviewError
                self.lastPreviewError = nil
                self.previewFailureCount = 0
                if let recoveredFrom {
                    self.logger.info(
                        "liveview",
                        "实时取景已恢复；上次错误=\(recoveredFrom)"
                    )
                }
                DispatchQueue.main.async {
                    guard token == self.previewToken else { return }
                    if let image {
                        self.photoFrame = image
                        self.enqueuePreviewProcessing(image, token: token)
                    }
                    if self.detail.hasPrefix("实时取景重试") {
                        self.detail = "USB/PTP · 原生连接"
                    }
                    DispatchQueue.main.asyncAfter(
                        deadline: .now() + nextFrameDelay
                    ) {
                        self.pullPreview(token: token)
                    }
                }
            } catch {
                let message = error.localizedDescription
                self.previewFailureCount += 1
                let thermalFailure = (error as? CameraError).map {
                    if case .thermal = $0 { return true }
                    return false
                } ?? false
                let busyFailure = (error as? CameraError).map {
                    if case .liveViewBusy = $0 { return true }
                    return false
                } ?? false
                let repeatedFailure = self.previewFailureCount >= 5
                let shouldStop =
                    thermalFailure
                    || (busyFailure && self.previewFailureCount >= 3)
                    || repeatedFailure
                if shouldStop {
                    self.logger.warning(
                        "liveview",
                        "连续失败 \(self.previewFailureCount) 次，停止自动重试"
                    )
                    self.camera.stopLiveView()
                }
                if message != self.lastPreviewError {
                    self.lastPreviewError = message
                    self.logger.error(
                        "liveview",
                        "实时取景取帧失败：\(message)"
                    )
                }
                let summary = message
                    .split(whereSeparator: \.isNewline)
                    .map {
                        $0.trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                    .first {
                        !$0.isEmpty
                            && !$0.hasPrefix("***")
                            && !$0.hasPrefix("For debugging")
                    }
                    .map { String($0.prefix(90)) }
                    ?? "相机未返回画面"
                DispatchQueue.main.async {
                    guard token == self.previewToken else { return }
                    if shouldStop {
                        self.previewToken = UUID()
                        self.liveViewEnabled = false
                        self.detail = thermalFailure
                            ? "相机温度过高 · 实时取景已停止"
                            : "实时取景已暂停 · 请检查相机状态"
                        self.errorMessage = message
                        return
                    }
                    self.detail = "实时取景重试 · \(summary)"
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                        self.pullPreview(token: token)
                    }
                }
            }
        }
    }

    func capture() {
        guard connected else {
            errorMessage = "请先连接支持的 Nikon 相机。"
            return
        }
        guard !capturing else { return }
        logger.info("workflow", "用户请求拍摄")
        capturing = true
        detail = "正在触发 \(activeCameraName) 快门…"
        cameraQueue.async { [weak self] in
            guard let self else { return }
            do {
                let duration = self.exposureMode == "bulb" ? self.bulbSeconds : nil
                let data = try self.camera.capture(bulbSeconds: duration)
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyyMMdd_HHmmss"
                let filename = "NIKON_\(formatter.string(from: Date())).JPG"
                let url = try self.captureWorkflow.store(
                    data: data,
                    originalFilename: filename,
                    cameraName: self.activeCameraName
                )
                self.logger.info(
                    "capture",
                    "照片已保存；文件=\(url.lastPathComponent)；大小=\(data.count) 字节"
                )
                let image = NSImage(data: data)
                DispatchQueue.main.async {
                    self.capturing = false
                    self.detail = "拍摄完成 · 已保存到本地照片库"
                    if let image {
                        self.photoFrame = image
                    }
                    self.reloadPhotos()
                    self.selectedPhoto = self.photos.first
                }
                if let image {
                    self.previewProcessingQueue.async {
                        let output = self.processedPreview(from: image)
                        DispatchQueue.main.async {
                            self.frame = output.image
                            self.zebraMask = output.zebraMask
                        }
                    }
                }
            } catch {
                self.logger.error(
                    "capture",
                    "拍摄失败：\(error.localizedDescription)"
                )
                DispatchQueue.main.async {
                    self.capturing = false
                    self.detail = "拍摄失败"
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    func startShootingTask() {
        guard connected else {
            errorMessage = "请先连接支持的 Nikon 相机。"
            return
        }
        guard !shootingTaskRunning else { return }
        let token = UUID()
        shootingTaskToken = token
        let kind = shootingTaskKind
        let count = max(1, min(999, shootingTaskCount))
        let interval = max(1, min(3600, shootingTaskInterval))
        let step = max(1, min(3, shootingTaskStep))
        let originalCompensation = compensation
        shootingTaskRunning = true
        shootingTaskProgress = "\(kind.rawValue)准备中"
        cameraQueue.async { [weak self] in
            guard let self else { return }
            do {
                var total = kind == .bulb ? 1 : count
                if kind == .exposureBracket {
                    total = max(3, count | 1)
                }
                if kind == .focusBracket, !self.camera.isLiveViewActive {
                    try self.camera.startLiveView()
                    DispatchQueue.main.async {
                        self.liveViewEnabled = true
                        self.startPreviewLoop()
                    }
                }
                for index in 0..<total {
                    guard token == self.shootingTaskToken else {
                        throw CancellationError()
                    }
                    if kind == .exposureBracket {
                        let center = total / 2
                        let offset = Double(index - center) * Double(step)
                        try self.camera.setParameter(
                            name: "exposureCompensation",
                            value: originalCompensation + offset
                        )
                    }
                    if kind == .focusBracket, index > 0 {
                        try self.camera.moveFocus(step)
                    }
                    let bulbSeconds = kind == .bulb ? interval : nil
                    let data = try self.camera.capture(
                        bulbSeconds: bulbSeconds
                    )
                    let url = try self.captureWorkflow.store(
                        data: data,
                        originalFilename: "capture.jpg",
                        cameraName: self.activeCameraName
                    )
                    DispatchQueue.main.async {
                        self.photoFrame = NSImage(data: data)
                        self.shootingTaskProgress =
                            "\(kind.rawValue) · \(index + 1)/\(total) · \(url.lastPathComponent)"
                        self.reloadPhotos()
                        self.selectedPhoto = self.photos.first
                    }
                    if kind == .interval, index + 1 < total {
                        for _ in 0..<(interval * 10) {
                            guard token == self.shootingTaskToken else {
                                throw CancellationError()
                            }
                            Thread.sleep(forTimeInterval: 0.1)
                        }
                    }
                }
                if kind == .exposureBracket {
                    try? self.camera.setParameter(
                        name: "exposureCompensation",
                        value: originalCompensation
                    )
                }
                DispatchQueue.main.async {
                    self.shootingTaskRunning = false
                    self.shootingTaskProgress = "\(kind.rawValue)已完成"
                    self.detail = self.shootingTaskProgress
                }
            } catch is CancellationError {
                if kind == .exposureBracket {
                    try? self.camera.setParameter(
                        name: "exposureCompensation",
                        value: originalCompensation
                    )
                }
                DispatchQueue.main.async {
                    self.shootingTaskRunning = false
                    self.shootingTaskProgress = "拍摄任务已取消"
                }
            } catch {
                if kind == .exposureBracket {
                    try? self.camera.setParameter(
                        name: "exposureCompensation",
                        value: originalCompensation
                    )
                }
                DispatchQueue.main.async {
                    self.shootingTaskRunning = false
                    self.shootingTaskProgress = "拍摄任务失败"
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    func cancelShootingTask() {
        shootingTaskToken = UUID()
        shootingTaskProgress = "正在取消拍摄任务…"
    }

    func toggleMovieRecording() {
        guard connected else {
            errorMessage = "请先连接支持的 Nikon 相机。"
            return
        }
        guard !capturing else { return }
        let shouldStop = videoRecording
        capturing = true
        detail = shouldStop ? "正在停止视频录制…" : "正在开始视频录制…"
        cameraQueue.async { [weak self] in
            guard let self else { return }
            do {
                if shouldStop {
                    try self.camera.stopMovieRecording()
                } else {
                    try self.camera.startMovieRecording()
                }
                DispatchQueue.main.async {
                    self.capturing = false
                    self.videoRecording = !shouldStop
                    self.detail = shouldStop
                        ? "视频已停止并保存到相机存储卡"
                        : "● REC · 正在录制到相机存储卡"
                }
            } catch {
                self.logger.error(
                    "recording",
                    "视频录制切换失败：\(error.localizedDescription)"
                )
                DispatchQueue.main.async {
                    self.capturing = false
                    self.detail = "视频录制操作失败"
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    func reloadPhotos() {
        let keys: Set<URLResourceKey> = [.creationDateKey, .contentModificationDateKey]
        let enumerator = FileManager.default.enumerator(
            at: photoDirectory,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsHiddenFiles]
        )
        var urls: [URL] = []
        while let url = enumerator?.nextObject() as? URL {
            if url.pathComponents.contains("Backup") {
                if (try? url.resourceValues(
                    forKeys: [.isDirectoryKey]
                ).isDirectory) == true {
                    enumerator?.skipDescendants()
                }
                continue
            }
            urls.append(url)
        }
        photos = urls
            .filter {
                [
                    "jpg", "jpeg", "png", "nef", "heif", "heic", "tif", "tiff",
                    "mov", "mp4", "m4v"
                ]
                    .contains($0.pathExtension.lowercased())
            }
            .map { url in
                let values = try? url.resourceValues(forKeys: keys)
                return PhotoRecord(
                    url: url,
                    createdAt: values?.creationDate ?? values?.contentModificationDate ?? .distantPast
                )
            }
            .sorted { $0.createdAt > $1.createdAt }
    }

    func deleteSelectedPhoto() {
        guard let selectedPhoto else { return }
        do {
            try FileManager.default.trashItem(at: selectedPhoto.url, resultingItemURL: nil)
            self.selectedPhoto = nil
            reloadPhotos()
        } catch {
            logger.error(
                "library",
                "照片移到废纸篓失败：\(error.localizedDescription)"
            )
            errorMessage = "无法移到废纸篓：\(error.localizedDescription)"
        }
    }

    func importPhotos(from urls: [URL]) {
        var imported = 0
        var pairNames: [String: String] = [:]
        for source in urls {
            let pairKey = source.deletingPathExtension()
                .lastPathComponent
                .lowercased()
            let reservedBase = pairNames[pairKey] ?? captureWorkflow
                .reserveBaseName(cameraName: activeCameraName)
            pairNames[pairKey] = reservedBase
            do {
                _ = try captureWorkflow.importFile(
                    from: source,
                    cameraName: activeCameraName,
                    reservedBaseName: reservedBase
                )
                imported += 1
            } catch {
                logger.error(
                    "library",
                    "从网盘导入失败：\(error.localizedDescription)"
                )
            }
        }
        reloadPhotos()
        selectedPhoto = photos.first
        detail = imported > 0
            ? "已从网盘加入 \(imported) 张照片"
            : "没有可加入文件库的照片"
    }

    func openOwnerAlbum() {
        guard let photosApp = NSWorkspace.shared.urlForApplication(
            withBundleIdentifier: "com.apple.Photos"
        ) else {
            errorMessage = "找不到系统“照片”应用。"
            return
        }
        NSWorkspace.shared.openApplication(
            at: photosApp,
            configuration: NSWorkspace.OpenConfiguration()
        ) { _, error in
            if let error {
                DispatchQueue.main.async {
                    self.errorMessage =
                        "无法打开机主相册：\(error.localizedDescription)"
                }
            }
        }
    }

    func revealLibrary() {
        NSWorkspace.shared.activateFileViewerSelecting([photoDirectory])
    }

    func canAdjustExposureParameter(_ name: String) -> Bool {
        let modeAllows: Bool
        switch name {
        case "exposureTime", "videoExposureTime":
            modeAllows = exposureMode == "manual" || exposureMode == "shutterPriority"
        case "aperture":
            modeAllows = exposureMode == "manual"
                || exposureMode == "aperturePriority"
                || exposureMode == "bulb"
        case "iso":
            modeAllows = true
        case "exposureCompensation":
            modeAllows = exposureMode == "program"
                || exposureMode == "aperturePriority"
                || exposureMode == "shutterPriority"
        case "bulbDuration":
            modeAllows = exposureMode == "bulb"
        default:
            modeAllows = true
        }
        return modeAllows && parameterWritable[name] != false
    }

    func exposureLockReason(_ name: String) -> String? {
        guard !canAdjustExposureParameter(name) else { return nil }
        if parameterWritable[name] == false {
            return "相机固件报告为只读"
        }
        let mode = [
            "program": "P",
            "manual": "M",
            "aperturePriority": "A",
            "shutterPriority": "S",
            "bulb": "M（B门）"
        ][exposureMode] ?? exposureMode
        return "\(mode) 拍摄模式下由相机控制"
    }

    func setZebraEnabled(_ enabled: Bool) {
        zebraEnabled = enabled
        if !enabled { zebraMask = nil }
        refreshPreviewProcessing()
    }

    func setZebraThreshold(_ threshold: Double) {
        zebraThreshold = max(70, min(100, threshold))
        if zebraEnabled { refreshPreviewProcessing() }
    }

    func setLUTEnabled(_ enabled: Bool) {
        lutEnabled = enabled && previewLUT != nil
        refreshPreviewProcessing()
    }

    func setFocusPeakingEnabled(_ enabled: Bool) {
        focusPeakingEnabled = enabled
        refreshPreviewProcessing()
    }

    func setFalseColorEnabled(_ enabled: Bool) {
        falseColorEnabled = enabled
        refreshPreviewProcessing()
    }

    func setMonitorVideoProfile(_ profile: MonitorVideoProfile) {
        monitorVideoProfile = profile
        UserDefaults.standard.set(profile.rawValue, forKey: "monitorVideoProfile")
        detail = "监看显示尺寸 · \(profile.label)"
        refreshPreviewProcessing()
    }

    func setVideoFrameRate(_ rate: Double) {
        videoFrameRate = rate
        UserDefaults.standard.set(rate, forKey: "videoFrameRate")
        setVideoShutterAngle(videoShutterAngle)
    }

    func setVideoShutterAngle(_ angle: Double) {
        videoShutterAngle = angle
        UserDefaults.standard.set(angle, forKey: "videoShutterAngle")
        shutter = angle / (360 * videoFrameRate)
        guard connected else {
            detail = "视频曝光 · \(angle.formatted())° · \(Int(videoFrameRate)) fps"
            return
        }
        applyParameter(
            "videoExposureTime",
            value: shutter,
            label: "快门角度 \(angle.formatted())°"
        )
    }

    func importLUT(from url: URL) {
        detail = "正在导入 LUT…"
        previewProcessingQueue.async { [weak self] in
            guard let self else { return }
            let accessing = url.startAccessingSecurityScopedResource()
            defer {
                if accessing { url.stopAccessingSecurityScopedResource() }
            }
            do {
                let lut = try ColorCubeLUT(contentsOf: url)
                self.previewLUT = lut
                let output = self.sourceFrame.map { source in
                    (
                        image: lut.applying(to: source) ?? source,
                        zebraMask: self.zebraEnabled
                            ? PreviewProcessor.zebraMask(
                                for: source,
                                threshold: self.zebraThreshold
                            )
                            : nil
                    )
                }
                DispatchQueue.main.async {
                    self.lutName = lut.title
                    self.lutEnabled = true
                    self.detail = "LUT 已载入 · 仅用于监看"
                    if let output {
                        self.frame = output.image
                        self.zebraMask = output.zebraMask
                    }
                }
            } catch {
                self.logger.error(
                    "monitor",
                    "LUT 导入失败：\(error.localizedDescription)"
                )
                DispatchQueue.main.async {
                    self.detail = "LUT 导入失败"
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    func clearLUT() {
        previewProcessingQueue.async { [weak self] in
            guard let self else { return }
            self.previewLUT = nil
            let output = self.sourceFrame.map { self.processedPreview(from: $0) }
            DispatchQueue.main.async {
                self.lutName = nil
                self.lutEnabled = false
                if let output {
                    self.frame = output.image
                    self.zebraMask = output.zebraMask
                }
            }
        }
    }

    func applyParameter(_ name: String, value: Any, label: String) {
        guard connected else {
            errorMessage = "连接支持的 Nikon 相机后才能调整参数。"
            return
        }
        guard canAdjustExposureParameter(name) else {
            errorMessage = "\(label)不可调整：\(exposureLockReason(name) ?? "相机当前未开放此参数")。"
            return
        }
        detail = "正在设置 \(label)…"
        cameraQueue.async { [weak self] in
            guard let self else { return }
            do {
                try self.camera.setParameter(name: name, value: value)
                let capabilities = self.camera.parameterCapabilitySnapshot()
                DispatchQueue.main.async {
                    if name == "exposureMode" {
                        self.exposureMode = String(describing: value)
                    }
                    self.parameterWritable = capabilities
                    self.detail = "\(label)已应用"
                }
            } catch {
                let capabilities = self.camera.parameterCapabilitySnapshot()
                self.logger.error(
                    "settings",
                    "\(label)设置失败：\(error.localizedDescription)"
                )
                DispatchQueue.main.async {
                    self.parameterWritable = capabilities
                    self.detail = "\(label)设置失败"
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func enqueuePreviewProcessing(_ image: NSImage, token: UUID) {
        previewProcessingLock.lock()
        pendingPreview = (token, image)
        let shouldStart = !previewProcessingActive
        if shouldStart {
            previewProcessingActive = true
        }
        previewProcessingLock.unlock()
        guard shouldStart else { return }
        previewProcessingQueue.async { [weak self] in
            self?.processNextPendingPreview()
        }
    }

    private func processNextPendingPreview() {
        previewProcessingLock.lock()
        let pending = pendingPreview
        pendingPreview = nil
        previewProcessingLock.unlock()

        if let pending, pending.token == previewToken {
            let output = autoreleasepool {
                processedPreview(from: pending.image)
            }
            DispatchQueue.main.async { [weak self] in
                guard let self, pending.token == self.previewToken else {
                    return
                }
                self.frame = output.image
                self.zebraMask = output.zebraMask
            }
        }

        previewProcessingLock.lock()
        let shouldContinue = pendingPreview != nil
        if !shouldContinue {
            previewProcessingActive = false
        }
        previewProcessingLock.unlock()
        if shouldContinue {
            previewProcessingQueue.async { [weak self] in
                self?.processNextPendingPreview()
            }
        }
    }

    private func clearPendingPreviewProcessing() {
        previewProcessingLock.lock()
        pendingPreview = nil
        previewProcessingLock.unlock()
    }

    private func processedPreview(from image: NSImage) -> (image: NSImage, zebraMask: NSImage?) {
        sourceFrame = image
        let graded = lutEnabled
            ? previewLUT?.applying(to: image) ?? image
            : image
        let monitored = ProfessionalMonitor.process(
            graded,
            focusPeaking: focusPeakingEnabled,
            falseColor: falseColorEnabled
        )
        DispatchQueue.main.async { [weak self] in
            self?.redHistogram = monitored.redHistogram
            self?.greenHistogram = monitored.greenHistogram
            self?.blueHistogram = monitored.blueHistogram
            self?.waveform = monitored.waveform
            self?.vectorscope = monitored.vectorscope
            self?.peakingCoverage = monitored.peakingCoverage
        }
        let display = monitorVideoProfile.targetSize.flatMap {
            PreviewProcessor.resampledImage(
                monitored.image,
                fitting: $0
            )
        } ?? monitored.image
        let zebra = zebraEnabled
            ? PreviewProcessor.zebraMask(for: image, threshold: zebraThreshold)
            : nil
        return (display, zebra)
    }

    private func refreshPreviewProcessing() {
        previewProcessingQueue.async { [weak self] in
            guard let self, let sourceFrame = self.sourceFrame else { return }
            let output = self.processedPreview(from: sourceFrame)
            DispatchQueue.main.async {
                self.frame = output.image
                self.zebraMask = output.zebraMask
            }
        }
    }

    func shutdown() {
        logger.info("app", "正在停止相机与传输服务")
        previewToken = UUID()
        clearPendingPreviewProcessing()
        wirelessTransfer.stop()
        camera.disconnect()
    }
}

private enum Palette {
    static let paper = Color(red: 0.965, green: 0.973, blue: 0.988)
    static let paperSecondary = Color(red: 0.937, green: 0.953, blue: 0.976)
    static let surface = Color(red: 0.992, green: 0.996, blue: 1.0)
    static let ink = Color(red: 0.075, green: 0.09, blue: 0.12)
    static let muted = Color(red: 0.36, green: 0.40, blue: 0.47)
    static let cobalt = Color(red: 0.02, green: 0.35, blue: 0.82)
    static let cobaltSoft = Color(red: 0.88, green: 0.93, blue: 1.0)
    static let video = Color(red: 0.82, green: 0.12, blue: 0.16)
    static let videoSoft = Color(red: 1.0, green: 0.90, blue: 0.91)
    static let graphite = Color(red: 0.045, green: 0.055, blue: 0.075)
    static let rule = Color.black.opacity(0.10)
    static let shadow = Color(red: 0.05, green: 0.09, blue: 0.16).opacity(0.10)
}

private struct NativeButtonStyle: ButtonStyle {
    var primary = false
    var accent = Palette.cobalt

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(primary ? Color.white : Palette.ink)
            .padding(.horizontal, 16)
            .frame(minHeight: 40)
            .background(
                primary
                    ? accent
                    : (
                        configuration.isPressed
                            ? Palette.paperSecondary
                            : Palette.surface
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: 11))
            .overlay {
                RoundedRectangle(cornerRadius: 11)
                    .stroke(
                        primary ? Color.clear : Palette.rule,
                        lineWidth: 1
                    )
            }
            .shadow(
                color: primary ? accent.opacity(0.25) : Color.clear,
                radius: primary ? 9 : 0,
                y: primary ? 4 : 0
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

private struct PreviewStage: View {
    @ObservedObject var model: CameraModel
    var compact = false
    var showsMonitorEffects = false
    var openFullscreen: (() -> Void)?
    var monitoring = false

    var body: some View {
        let previewFrame = showsMonitorEffects ? model.frame : model.photoFrame
        ZStack {
            Palette.graphite
            if let frame = previewFrame {
                Image(nsImage: frame)
                    .resizable()
                    .interpolation(.medium)
                    .scaledToFit()
                if showsMonitorEffects,
                   model.zebraEnabled,
                   let zebraMask = model.zebraMask {
                    Image(nsImage: zebraMask)
                        .resizable()
                        .scaledToFit()
                        .allowsHitTesting(false)
                }
            } else {
                VStack(spacing: 14) {
                    Image(systemName: "camera.aperture")
                        .font(.system(size: compact ? 38 : 54, weight: .light))
                    RuntimeLocalizedText(
                        model.connected
                            ? "等待实时取景画面"
                            : "连接支持的 Nikon 相机后开启实时取景"
                    )
                        .font(.system(size: 15, weight: .medium))
                }
                .foregroundStyle(Color.white.opacity(0.48))
            }
            VStack {
                HStack {
                    Label(
                        model.liveViewEnabled ? "LIVE" : "NO SOURCE",
                        systemImage: "circle.fill"
                    )
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(model.liveViewEnabled ? Color.red : Color.white.opacity(0.5))
                    Spacer()
                    Text("\(model.cameraName ?? SupportedCamera.summary) · USB/PTP")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Color.white.opacity(0.64))
                }
                if showsMonitorEffects,
                   model.zebraEnabled || (model.lutEnabled && model.lutName != nil) {
                    HStack(spacing: 8) {
                        if model.zebraEnabled {
                            Text("条纹 \(Int(model.zebraThreshold))")
                        }
                        if model.lutEnabled, let lutName = model.lutName {
                            Text("LUT · \(lutName)")
                                .lineLimit(1)
                        }
                        Spacer()
                    }
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.78))
                }
                Spacer()
                HStack {
                    RuntimeLocalizedText(shutterLabel)
                    Text("F\(model.aperture, specifier: "%.1f")")
                    Text("ISO \(model.iso)")
                    Spacer()
                    Text(
                        showsMonitorEffects
                            ? "JPEG实时取景 · \(model.monitorVideoProfile.label)"
                            : "照片实时取景 · JPEG"
                    )
                }
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(Color.white.opacity(0.78))
            }
            .padding(16)
        }
        .aspectRatio(16 / 10, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.12), radius: 16, y: 6)
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        }
        .overlay(alignment: .topTrailing) {
            if let openFullscreen {
                Button(action: openFullscreen) {
                    Label(
                        "全屏",
                        systemImage: "arrow.up.left.and.arrow.down.right"
                    )
                }
                .buttonStyle(NativeButtonStyle())
                .padding(14)
            }
        }
    }

    private var shutterLabel: String {
        if showsMonitorEffects {
            return model.videoShutterAngle.formatted() + "°"
        }
        if model.exposureMode == "bulb" { return "B门" }
        if model.shutter < 1 {
            return "1/\(Int((1 / model.shutter).rounded()))"
        }
        return String(format: "%.1fs", model.shutter)
    }
}

private struct ImmersiveMacCameraView: View {
    @ObservedObject var model: CameraModel
    @State private var showsParameters = true
    let monitoring: Bool
    let close: () -> Void

    var body: some View {
        GeometryReader { proxy in
            let edgeLayout = proxy.size.width > proxy.size.height
                ? AnyLayout(HStackLayout())
                : AnyLayout(VStackLayout())
            ZStack {
            Color.black.ignoresSafeArea()
            if let frame = monitoring ? model.frame : model.photoFrame {
                Image(nsImage: frame)
                    .resizable()
                    .interpolation(.medium)
                    .scaledToFit()
                    .ignoresSafeArea()
                if monitoring,
                   model.zebraEnabled,
                   let zebraMask = model.zebraMask {
                    Image(nsImage: zebraMask)
                        .resizable()
                        .scaledToFit()
                        .allowsHitTesting(false)
                }
            } else {
                ContentUnavailableView(
                    "等待相机画面",
                    systemImage: "camera.viewfinder",
                    description: Text("连接相机并开启实时取景后即可全屏监看。")
                )
                .foregroundStyle(.white)
            }

            ImmersiveMacFocusReticle()
                .stroke(Color.yellow.opacity(0.82), lineWidth: 2)
                .frame(width: 84, height: 84)
                .allowsHitTesting(false)

            VStack {
                HStack(spacing: 12) {
                    Button {
                        close()
                    } label: {
                        Label("退出全屏", systemImage: "chevron.down")
                    }
                    .buttonStyle(ImmersiveMacButtonStyle())

                    Label(
                        model.liveViewEnabled ? "LIVE" : "NO SOURCE",
                        systemImage: "circle.fill"
                    )
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(
                        model.liveViewEnabled ? Color.red : Color.white.opacity(0.58)
                    )
                    .padding(.horizontal, 14)
                    .frame(height: 44)
                    .background(.black.opacity(0.58), in: Capsule())
                    Spacer()
                    Text("\(model.cameraName ?? SupportedCamera.summary) · USB/PTP")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .padding(.horizontal, 14)
                        .frame(height: 44)
                        .background(.black.opacity(0.58), in: Capsule())
                }
                Spacer()
                immersiveParameterBar
                HStack(spacing: 20) {
                    RuntimeLocalizedText(shutterLabel)
                    Text("F\(model.aperture, specifier: "%.1f")")
                    Text("ISO \(model.iso)")
                    Text(monitoring ? "\(Int(model.videoFrameRate))P" : "JPEG")
                }
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.88))
                .padding(.horizontal, 18)
                .frame(height: 44)
                .background(.black.opacity(0.58), in: Capsule())
            }
            .padding(20)

            edgeLayout {
                VStack(spacing: 12) {
                    Text(model.exposureMode.uppercased())
                        .font(.system(size: 22, weight: .bold))
                        .frame(width: 64, height: 56)
                        .background(.black.opacity(0.58), in: RoundedRectangle(cornerRadius: 12))
                    Text("USB\nPTP")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .multilineTextAlignment(.center)
                        .frame(width: 64, height: 56)
                        .background(.black.opacity(0.58), in: RoundedRectangle(cornerRadius: 12))
                }
                Spacer()
                VStack(spacing: 12) {
                    Text(
                        monitoring && model.videoRecording
                            ? "● REC"
                            : monitoring ? "视频" : "照片"
                    )
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(monitoring ? Palette.video : Palette.cobalt)
                    Button {
                        if monitoring {
                            model.toggleMovieRecording()
                        } else {
                            model.capture()
                        }
                    } label: {
                        ZStack {
                            if monitoring && model.videoRecording {
                                RoundedRectangle(cornerRadius: 13)
                                    .fill(Palette.video)
                                    .frame(width: 54, height: 54)
                            } else {
                                Circle()
                                    .fill(monitoring ? Palette.video : Palette.cobalt)
                                    .frame(width: 76, height: 76)
                            }
                            Circle()
                                .stroke(.white.opacity(0.88), lineWidth: 3)
                                .frame(width: 88, height: 88)
                            if !monitoring {
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 23, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                        }
                        .frame(width: 96, height: 96)
                    }
                    .buttonStyle(.plain)
                    .disabled(!model.connected || model.capturing)
                    .help(
                        monitoring
                            ? model.videoRecording ? "停止录制" : "开始录制"
                            : "拍摄照片"
                    )

                    Button {
                        model.toggleLiveView()
                    } label: {
                        RuntimeLocalizedText(
                            model.liveViewEnabled ? "停止取景" : "开启取景"
                        )
                    }
                    .buttonStyle(ImmersiveMacButtonStyle())
                }
            }
            .padding(.horizontal, 24)
            .padding(
                .vertical,
                proxy.size.width > proxy.size.height ? 0 : 108
            )
            }
        }
        .preferredColorScheme(.dark)
        .onExitCommand(perform: close)
    }

    @ViewBuilder
    private var immersiveParameterBar: some View {
        VStack(spacing: 8) {
            Button {
                showsParameters.toggle()
            } label: {
                RuntimeLocalizedText(
                    showsParameters ? "收起参数" : "展开参数"
                )
            }
            .buttonStyle(ImmersiveMacButtonStyle())
            if showsParameters {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        if monitoring {
                            parameterControl(
                                "快门角度",
                                model.videoShutterAngle.formatted() + "°",
                                parameter: "videoExposureTime",
                                decrease: { adjustVideoShutterAngle(-1) },
                                increase: { adjustVideoShutterAngle(1) }
                            )
                            ImmersiveMacParameterControl(
                                title: "帧率",
                                value: "\(Int(model.videoFrameRate)) fps",
                                decrease: { adjustVideoFrameRate(-1) },
                                increase: { adjustVideoFrameRate(1) }
                            )
                        } else {
                            parameterControl(
                                "快门",
                                shutterLabel,
                                parameter: "exposureTime",
                                decrease: { adjustPhotoShutter(-1) },
                                increase: { adjustPhotoShutter(1) }
                            )
                        }
                        parameterControl(
                            "光圈",
                            "F\(model.aperture.formatted())",
                            parameter: "aperture",
                            decrease: { adjustAperture(-1) },
                            increase: { adjustAperture(1) }
                        )
                        parameterControl(
                            "ISO",
                            "\(model.iso)",
                            parameter: "iso",
                            decrease: { adjustISO(-1) },
                            increase: { adjustISO(1) }
                        )
                        parameterControl(
                            "曝光补偿",
                            String(format: "%+.1f EV", model.compensation),
                            parameter: "exposureCompensation",
                            decrease: { adjustCompensation(-1) },
                            increase: { adjustCompensation(1) }
                        )
                        parameterControl(
                            "白平衡",
                            model.whiteBalance == "continuous" ? "自动" : "预设",
                            parameter: "whiteBalanceMode",
                            decrease: { setWhiteBalance("continuous") },
                            increase: { setWhiteBalance("manual") }
                        )
                        parameterControl(
                            "对焦",
                            model.focusMode == "continuous" ? "AF-C" : "AF-S",
                            parameter: "focusMode",
                            decrease: { setFocusMode("single-shot") },
                            increase: { setFocusMode("continuous") }
                        )
                    }
                    .padding(.horizontal, 2)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func parameterControl(
        _ title: String,
        _ value: String,
        parameter: String,
        decrease: @escaping () -> Void,
        increase: @escaping () -> Void
    ) -> some View {
        ImmersiveMacParameterControl(
            title: title,
            value: value,
            enabled: model.canAdjustExposureParameter(parameter),
            lockedReason: model.exposureLockReason(parameter),
            decrease: decrease,
            increase: increase
        )
    }

    private let shutterOptions: [Double] = [
        1.0 / 8000, 1.0 / 6400, 1.0 / 5000, 1.0 / 4000,
        1.0 / 3200, 1.0 / 2500, 1.0 / 2000, 1.0 / 1600,
        1.0 / 1250, 1.0 / 1000, 1.0 / 800, 1.0 / 640,
        1.0 / 500, 1.0 / 400, 1.0 / 320, 1.0 / 250,
        1.0 / 200, 1.0 / 160, 1.0 / 125, 1.0 / 100,
        1.0 / 80, 1.0 / 60, 1.0 / 50, 1.0 / 40,
        1.0 / 30, 1.0 / 25, 1.0 / 20, 1.0 / 15,
        1.0 / 13, 1.0 / 10, 1.0 / 8, 1.0 / 6,
        1.0 / 5, 1.0 / 4, 1.0 / 3, 1.0 / 2, 1.0
    ]
    private let apertureOptions = [
        1.2, 1.4, 1.6, 1.8, 2.0, 2.2, 2.5, 2.8, 3.2, 3.5,
        4.0, 4.5, 5.0, 5.6, 6.3, 7.1, 8.0, 9.0, 10.0, 11.0,
        13.0, 14.0, 16.0, 18.0, 20.0, 22.0
    ]
    private let frameRateOptions = [24.0, 25.0, 30.0, 50.0, 60.0]
    private let shutterAngleOptions = [
        45.0, 60.0, 72.0, 90.0, 108.0, 120.0, 144.0, 150.0,
        172.8, 180.0, 216.0, 240.0, 270.0, 300.0, 324.0, 360.0
    ]

    private func adjacentValue(
        in values: [Double],
        current: Double,
        offset: Int
    ) -> Double {
        guard !values.isEmpty else { return current }
        let nearest = values.indices.min {
            abs(values[$0] - current) < abs(values[$1] - current)
        } ?? 0
        return values[max(0, min(values.count - 1, nearest + offset))]
    }

    private func adjustVideoShutterAngle(_ offset: Int) {
        model.setVideoShutterAngle(
            adjacentValue(
                in: shutterAngleOptions,
                current: model.videoShutterAngle,
                offset: offset
            )
        )
    }

    private func adjustVideoFrameRate(_ offset: Int) {
        model.setVideoFrameRate(
            adjacentValue(
                in: frameRateOptions,
                current: model.videoFrameRate,
                offset: offset
            )
        )
    }

    private func adjustPhotoShutter(_ offset: Int) {
        let value = adjacentValue(
            in: shutterOptions,
            current: model.shutter,
            offset: offset
        )
        model.shutter = value
        model.applyParameter("exposureTime", value: value, label: "快门")
    }

    private func adjustAperture(_ offset: Int) {
        let value = adjacentValue(
            in: apertureOptions,
            current: model.aperture,
            offset: offset
        )
        model.aperture = value
        model.applyParameter("aperture", value: value, label: "光圈")
    }

    private func adjustISO(_ offset: Int) {
        let values = SupportedCamera.isoOptions(for: model.cameraName)
        guard !values.isEmpty else { return }
        let nearest = values.indices.min {
            abs(values[$0] - model.iso) < abs(values[$1] - model.iso)
        } ?? 0
        let value = values[max(0, min(values.count - 1, nearest + offset))]
        model.iso = value
        model.applyParameter("iso", value: value, label: "ISO")
    }

    private func adjustCompensation(_ offset: Int) {
        let value = max(-5, min(5, model.compensation + Double(offset) / 3))
        model.compensation = value
        model.applyParameter(
            "exposureCompensation",
            value: value,
            label: "曝光补偿"
        )
    }

    private func setWhiteBalance(_ value: String) {
        model.whiteBalance = value
        model.applyParameter("whiteBalanceMode", value: value, label: "白平衡")
    }

    private func setFocusMode(_ value: String) {
        model.focusMode = value
        model.applyParameter("focusMode", value: value, label: "对焦模式")
    }

    private var shutterLabel: String {
        if monitoring {
            return model.videoShutterAngle.formatted() + "°"
        }
        if model.exposureMode == "bulb" { return "B门" }
        if model.shutter < 1 {
            return "1/\(Int((1 / model.shutter).rounded()))"
        }
        return String(format: "%.1fs", model.shutter)
    }
}

private struct ImmersiveMacFocusReticle: Shape {
    func path(in rect: CGRect) -> Path {
        let arm = min(rect.width, rect.height) * 0.24
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY + arm))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX + arm, y: rect.minY))
        path.move(to: CGPoint(x: rect.maxX - arm, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + arm))
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY - arm))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + arm, y: rect.maxY))
        path.move(to: CGPoint(x: rect.maxX - arm, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - arm))
        return path
    }
}

private struct ImmersiveMacParameterControl: View {
    let title: String
    let value: String
    var enabled = true
    var lockedReason: String?
    let decrease: () -> Void
    let increase: () -> Void

    var body: some View {
        VStack(spacing: 5) {
            Text(LocalizedStringKey(title))
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white.opacity(0.62))
            HStack(spacing: 5) {
                Button(action: decrease) {
                    Image(systemName: "minus")
                        .frame(width: 44, height: 44)
                }
                Text(value)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .frame(minWidth: 72)
                Button(action: increase) {
                    Image(systemName: "plus")
                        .frame(width: 44, height: 44)
                }
            }
            .buttonStyle(.plain)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(.black.opacity(0.64), in: RoundedRectangle(cornerRadius: 12))
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.48)
        .help(enabled ? title : (lockedReason ?? "\(title)当前不可调整"))
    }
}

private final class ImmersiveMacWindowController:
    NSWindowController,
    NSWindowDelegate
{
    private var closeAfterLeavingFullScreen = false

    init(model: CameraModel, monitoring: Bool) {
        let screenFrame = NSScreen.main?.frame
            ?? NSRect(x: 0, y: 0, width: 1280, height: 800)
        let window = NSWindow(
            contentRect: screenFrame,
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        super.init(window: window)
        window.title = monitoring
            ? "帧澈 ZENCHE · 视频全屏监看"
            : "帧澈 ZENCHE · 照片全屏取景"
        window.backgroundColor = .black
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.contentView = NSHostingView(
            rootView: ImmersiveMacCameraView(
                model: model,
                monitoring: monitoring,
                close: { [weak self] in self?.requestClose() }
            )
        )
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func present() {
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        window?.toggleFullScreen(nil)
    }

    func requestClose() {
        guard let window else { return }
        if window.styleMask.contains(.fullScreen) {
            guard !closeAfterLeavingFullScreen else { return }
            closeAfterLeavingFullScreen = true
            window.toggleFullScreen(nil)
        } else {
            window.close()
        }
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        guard sender.styleMask.contains(.fullScreen) else { return true }
        requestClose()
        return false
    }

    func windowDidExitFullScreen(_ notification: Notification) {
        guard closeAfterLeavingFullScreen else { return }
        closeAfterLeavingFullScreen = false
        DispatchQueue.main.async { [weak self] in
            self?.window?.close()
        }
    }

    func windowWillClose(_ notification: Notification) {
        ImmersiveMacWindowStore.release(self)
    }
}

private enum ImmersiveMacWindowStore {
    private static var controllers:
        [ObjectIdentifier: ImmersiveMacWindowController] = [:]

    static func retain(_ controller: ImmersiveMacWindowController) {
        controllers[ObjectIdentifier(controller)] = controller
    }

    static func release(_ controller: ImmersiveMacWindowController) {
        controllers.removeValue(forKey: ObjectIdentifier(controller))
    }
}

private func showMacImmersiveWindow(
    model: CameraModel,
    monitoring: Bool
) {
    let controller = ImmersiveMacWindowController(
        model: model,
        monitoring: monitoring
    )
    ImmersiveMacWindowStore.retain(controller)
    controller.present()
}

private struct ImmersiveMacButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .frame(minHeight: 44)
            .background(.black.opacity(0.58), in: RoundedRectangle(cornerRadius: 12))
            .opacity(configuration.isPressed ? 0.68 : 1)
    }
}

private struct TopBar: View {
    @ObservedObject var model: CameraModel
    @Binding var showConnection: Bool
    @Binding var showSettings: Bool

    var body: some View {
        HStack(spacing: 16) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 13).fill(Palette.graphite)
                    Text("Z")
                        .font(.system(size: 20, weight: .heavy))
                        .foregroundStyle(.white)
                }
                .frame(width: 44, height: 44)
                .shadow(color: Palette.cobalt.opacity(0.18), radius: 8, y: 4)
                VStack(alignment: .leading, spacing: 1) {
                    Text("帧澈 ZENCHE")
                        .font(.system(size: 18, weight: .bold))
                    Text("Capture · Connect · Flow")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Palette.muted)
                }
            }
            Button {
                if model.connected { model.disconnect() }
                else { showConnection = true }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: model.connected ? "camera.fill" : "camera")
                        .foregroundStyle(model.connected ? Color.green : Palette.cobalt)
                    VStack(alignment: .leading, spacing: 1) {
                        RuntimeLocalizedText(model.status)
                            .font(.system(size: 14, weight: .bold))
                        RuntimeLocalizedText(model.detail)
                            .font(.system(size: 11))
                            .foregroundStyle(Palette.muted)
                            .lineLimit(1)
                    }
                }
                .frame(width: 245, alignment: .leading)
            }
            .buttonStyle(NativeButtonStyle())

            Spacer()

            Button {
                showSettings = true
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 17, weight: .semibold))
            }
            .buttonStyle(NativeButtonStyle())
            .help(Text("设置"))
        }
        .padding(.horizontal, 20)
        .frame(height: 76)
        .background(Palette.surface)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Palette.rule).frame(height: 1)
        }
        .shadow(color: Palette.shadow.opacity(0.55), radius: 12, y: 4)
    }
}

private struct Sidebar: View {
    @ObservedObject var model: CameraModel

    var body: some View {
        VStack(spacing: 6) {
            groupLabel("创作")
            navigationButton(.capture)
            navigationButton(.monitor)
            Divider()
                .padding(.vertical, 8)
            groupLabel("管理")
            navigationButton(.library)
            Spacer()
        }
        .padding(.vertical, 18)
        .frame(width: 104)
        .background(Palette.paperSecondary)
        .overlay(alignment: .trailing) {
            Rectangle().fill(Palette.rule).frame(width: 1)
        }
    }

    private func groupLabel(_ title: String) -> some View {
        Text(LocalizedStringKey(title))
            .font(.system(size: 10, weight: .semibold, design: .monospaced))
            .foregroundStyle(Palette.muted)
            .frame(width: 72, alignment: .leading)
            .padding(.leading, 4)
    }

    private func navigationButton(_ section: AppSection) -> some View {
        let active = model.section == section
        let accent = section == .monitor ? Palette.video : Palette.cobalt
        return Button {
            withAnimation(.easeInOut(duration: 0.18)) {
                model.section = section
            }
        } label: {
            VStack(spacing: 6) {
                Image(systemName: section.icon)
                    .font(.system(size: 19, weight: active ? .semibold : .regular))
                Text(LocalizedStringKey(section.rawValue))
                    .font(.system(size: 12, weight: active ? .semibold : .medium))
            }
            .foregroundStyle(active ? accent : Palette.muted)
            .frame(width: 80, height: 66)
            .background(
                RoundedRectangle(cornerRadius: 15)
                    .fill(active ? Palette.surface : Color.clear)
                    .shadow(
                        color: active ? Palette.shadow.opacity(0.7) : .clear,
                        radius: 7,
                        y: 3
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 15)
                    .stroke(active ? accent.opacity(0.25) : Color.clear, lineWidth: 1.5)
            )
            .overlay(alignment: .leading) {
                Capsule()
                    .fill(active ? accent : .clear)
                    .frame(width: 3, height: 28)
                    .offset(x: 3)
            }
        }
        .buttonStyle(.plain)
    }
}

private struct WorkspaceHeading: View {
    let title: String
    let subtitle: String
    var accent = Palette.cobalt

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Capsule()
                .fill(accent)
                .frame(width: 4, height: 42)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 6) {
                RuntimeLocalizedText(title)
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(Palette.ink)
                RuntimeLocalizedText(subtitle)
                    .foregroundStyle(Palette.muted)
            }
        }
    }
}

private struct CaptureView: View {
    @ObservedObject var model: CameraModel
    @Binding var showConnection: Bool

    var body: some View {
        HStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    WorkspaceHeading(
                        title: "照片拍摄",
                        subtitle: "快门、曝光、对焦、白平衡与拍摄模式集中在当前页面。"
                    )
                    PreviewStage(model: model) {
                        showMacImmersiveWindow(model: model, monitoring: false)
                    }
                    HStack {
                        Button {
                            model.toggleLiveView()
                        } label: {
                            RuntimeLocalizedText(
                                model.liveViewEnabled
                                    ? "停止实时取景"
                                    : "开启实时取景"
                            )
                        }
                        .buttonStyle(NativeButtonStyle())
                        Spacer()
                        Button {
                            if model.connected { model.capture() }
                            else { showConnection = true }
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "camera.shutter.button.fill")
                                RuntimeLocalizedText(
                                    model.capturing ? "拍摄中…" : "拍摄"
                                )
                            }
                            .frame(minWidth: 120)
                        }
                        .buttonStyle(NativeButtonStyle(primary: true))
                        .disabled(model.capturing)
                    }
                    ShootingTaskPanel(model: model)
                }
                .padding(28)
            }
            .frame(minWidth: 520)
            ParameterInspector(model: model)
                .frame(width: 330)
        }
    }
}

private struct ShootingTaskPanel: View {
    @ObservedObject var model: CameraModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("拍摄任务")
                .font(.system(size: 19, weight: .bold))
            Picker("任务类型", selection: $model.shootingTaskKind) {
                ForEach(ShootingTaskKind.allCases) { kind in
                    Text(kind.rawValue).tag(kind)
                }
            }
            .pickerStyle(.segmented)
            HStack {
                Stepper(
                    "张数 \(model.shootingTaskCount)",
                    value: $model.shootingTaskCount,
                    in: 1...999
                )
                Stepper(
                    model.shootingTaskKind == .bulb
                        ? "曝光 \(model.shootingTaskInterval) 秒"
                        : "间隔 \(model.shootingTaskInterval) 秒",
                    value: $model.shootingTaskInterval,
                    in: 1...3600
                )
                if model.shootingTaskKind == .exposureBracket
                    || model.shootingTaskKind == .focusBracket {
                    Stepper(
                        "步长 \(model.shootingTaskStep)",
                        value: $model.shootingTaskStep,
                        in: 1...3
                    )
                }
                Spacer()
                Button(
                    model.shootingTaskRunning ? "取消任务" : "开始任务"
                ) {
                    if model.shootingTaskRunning {
                        model.cancelShootingTask()
                    } else {
                        model.startShootingTask()
                    }
                }
                .buttonStyle(
                    NativeButtonStyle(
                        primary: true,
                        accent: model.shootingTaskRunning ? .red : Palette.cobalt
                    )
                )
                .disabled(!model.connected && !model.shootingTaskRunning)
            }
            RuntimeLocalizedText(model.shootingTaskProgress)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(Palette.muted)
        }
        .padding(18)
        .background(Palette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(Palette.rule, lineWidth: 1)
        }
        .shadow(color: Palette.shadow, radius: 12, y: 6)
    }
}

private struct ParameterInspector: View {
    @ObservedObject var model: CameraModel
    @Environment(\.locale) private var locale

    private let shutterOptions: [(String, Double)] = [
        ("1/8000", 0.000125), ("1/1000", 0.001), ("1/250", 0.004),
        ("1/125", 0.008), ("1/60", 0.0167), ("1/15", 0.0667), ("1 秒", 1.0)
    ]
    private var isoOptions: [Int] {
        SupportedCamera.isoOptions(for: model.cameraName)
    }
    private let apertureOptions = [1.4, 2.0, 2.8, 4.0, 5.6, 8.0, 11.0, 16.0, 22.0]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("照片设置")
                    .font(.system(size: 21, weight: .bold))

                    nativeControl(
                        "快门速度",
                        lockedReason: model.exposureLockReason("exposureTime")
                    ) {
                        Picker(
                            "",
                            selection: Binding(
                                get: { model.shutter },
                                set: { value in
                                    model.shutter = value
                                    model.applyParameter(
                                        "exposureTime",
                                        value: value,
                                        label: "快门速度"
                                    )
                                }
                            )
                        ) {
                            ForEach(shutterOptions, id: \.1) { option in
                                Text(option.0).tag(option.1)
                            }
                        }
                        .disabled(
                            !model.connected
                                || !model.canAdjustExposureParameter("exposureTime")
                        )
                    }
                    nativeControl(
                        "光圈",
                        lockedReason: model.exposureLockReason("aperture")
                    ) {
                        Picker(
                            "",
                            selection: Binding(
                                get: { model.aperture },
                                set: { value in
                                    model.aperture = value
                                    model.applyParameter("aperture", value: value, label: "光圈")
                                }
                            )
                        ) {
                            ForEach(apertureOptions, id: \.self) { value in
                                Text("F\(value, specifier: "%.1f")").tag(value)
                            }
                        }
                        .disabled(
                            !model.connected
                                || !model.canAdjustExposureParameter("aperture")
                        )
                    }
                    nativeControl("ISO感光度") {
                        Picker(
                            "",
                            selection: Binding(
                                get: { model.iso },
                                set: { value in
                                    model.iso = value
                                    model.applyParameter("iso", value: value, label: "ISO感光度")
                                }
                            )
                        ) {
                            ForEach(isoOptions, id: \.self) { value in
                                Text("\(value)").tag(value)
                            }
                        }
                        .disabled(!model.connected)
                    }
                    nativeControl(
                        "曝光补偿",
                        lockedReason: model.exposureLockReason("exposureCompensation")
                    ) {
                        HStack {
                            Slider(
                                value: Binding(
                                    get: { model.compensation },
                                    set: { model.compensation = $0 }
                                ),
                                in: -5...5,
                                step: 1.0 / 3.0
                            )
                            Text("\(model.compensation, specifier: "%+.1f") EV")
                                .font(.system(size: 12, design: .monospaced))
                                .frame(width: 62)
                        }
                        .disabled(
                            !model.connected
                                || !model.canAdjustExposureParameter("exposureCompensation")
                        )
                        Button("应用曝光补偿") {
                            model.applyParameter(
                                "exposureCompensation",
                                value: model.compensation,
                                label: "曝光补偿"
                            )
                        }
                        .buttonStyle(.link)
                        .disabled(
                            !model.connected
                                || !model.canAdjustExposureParameter("exposureCompensation")
                        )
                    }
                    nativeControl("对焦模式") {
                        Picker(
                            "",
                            selection: Binding(
                                get: { model.focusMode },
                                set: { value in
                                    model.focusMode = value
                                    model.applyParameter("focusMode", value: value, label: "对焦模式")
                                }
                            )
                        ) {
                            Text("AF-S 单次AF").tag("single-shot")
                            Text("AF-C 连续AF").tag("continuous")
                            Text("MF 手动对焦").tag("manual")
                        }
                        .pickerStyle(.menu)
                        .disabled(!model.connected)
                    }
                    nativeControl("拍摄模式") {
                        Picker(
                            "",
                            selection: Binding(
                                get: { model.exposureMode },
                                set: { value in
                                    model.applyParameter(
                                        "exposureMode",
                                        value: value,
                                        label: "拍摄模式"
                                    )
                                }
                            )
                        ) {
                            Text("P").tag("program")
                            Text("S").tag("shutterPriority")
                            Text("A").tag("aperturePriority")
                            Text("M").tag("manual")
                            Text("M · B门").tag("bulb")
                        }
                        .pickerStyle(.segmented)
                        .disabled(!model.connected)
                    }
                    if model.exposureMode == "bulb" {
                        nativeControl("B门曝光时长（由应用控制）") {
                            Picker("B门曝光时长", selection: $model.bulbSeconds) {
                                Text("1 秒").tag(1)
                                Text("2 秒").tag(2)
                                Text("5 秒").tag(5)
                                Text("10 秒").tag(10)
                                Text("30 秒").tag(30)
                                Text("60 秒").tag(60)
                            }
                            .labelsHidden()
                            .disabled(!model.connected)
                        }
                    }
                    nativeControl("设定优化校准") {
                        Picker(
                            "",
                            selection: Binding(
                                get: { model.pictureControl },
                                set: { value in
                                    model.pictureControl = value
                                    model.applyParameter(
                                        "pictureControl",
                                        value: value,
                                        label: "设定优化校准"
                                    )
                                }
                            )
                        ) {
                            Text("自动").tag("auto")
                            Text("标准").tag("standard")
                            Text("自然").tag("neutral")
                            Text("鲜艳").tag("vivid")
                            Text("单色").tag("monochrome")
                            Text("人像").tag("portrait")
                            Text("风景").tag("landscape")
                            Text("平面").tag("flat")
                        }
                        .disabled(!model.connected)
                    }
            }
            .padding(24)
        }
        .background(Palette.surface)
        .overlay(alignment: .leading) {
            Rectangle().fill(Palette.rule).frame(width: 1)
        }
    }

    private func nativeControl<Content: View>(
        _ title: String,
        lockedReason: String? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 6) {
                Text(LocalizedStringKey(title))
                if let lockedReason {
                    HStack(spacing: 4) {
                        Image(systemName: "lock.fill")
                        RuntimeLocalizedText(lockedReason)
                    }
                        .font(.system(size: 10, weight: .medium))
                        .help(
                            RuntimeLocalization.text(
                                lockedReason,
                                locale: locale
                            )
                        )
                }
                Spacer()
            }
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Palette.muted)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 15)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Palette.rule).frame(height: 1)
        }
    }
}

private struct MonitorView: View {
    @ObservedObject var model: CameraModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    WorkspaceHeading(
                        title: "视频监看",
                        subtitle: "\(model.cameraName ?? SupportedCamera.summary) · 视频取景与本地监看处理",
                        accent: Palette.video
                    )
                    Spacer()
                    Button {
                        model.toggleMovieRecording()
                    } label: {
                        RuntimeLocalizedText(
                            model.videoRecording ? "停止录制" : "开始录制"
                        )
                    }
                    .buttonStyle(
                        NativeButtonStyle(
                            primary: true,
                            accent: Palette.video
                        )
                    )
                    .disabled(!model.connected || model.capturing)
                    Button {
                        model.toggleLiveView()
                    } label: {
                        RuntimeLocalizedText(
                            model.liveViewEnabled
                                ? "停止实时取景"
                                : "开启实时取景"
                        )
                    }
                    .buttonStyle(
                        NativeButtonStyle(
                            primary: !model.liveViewEnabled,
                            accent: Palette.video
                        )
                    )
                }

                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: 20) {
                        PreviewStage(
                            model: model,
                            showsMonitorEffects: true
                        ) {
                            showMacImmersiveWindow(model: model, monitoring: true)
                        }
                            .frame(minWidth: 520)
                        MonitorControlDeck(model: model)
                            .frame(width: 320)
                    }
                    VStack(alignment: .leading, spacing: 20) {
                        PreviewStage(
                            model: model,
                            showsMonitorEffects: true
                        ) {
                            showMacImmersiveWindow(model: model, monitoring: true)
                        }
                        MonitorControlDeck(model: model)
                    }
                }
            }
            .padding(28)
        }
    }
}

private struct MonitorControlDeck: View {
    @ObservedObject var model: CameraModel
    @State private var showLUTImporter = false

    private var isoOptions: [Int] {
        SupportedCamera.isoOptions(for: model.cameraName)
    }
    private let apertureOptions = [1.4, 2.0, 2.8, 4.0, 5.6, 8.0, 11.0, 16.0, 22.0]
    private let frameRateOptions = [24.0, 25.0, 30.0, 50.0, 60.0]
    private let shutterAngleOptions = [45.0, 90.0, 144.0, 172.8, 180.0, 270.0, 360.0]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 14) {
                Text("视频曝光三要素")
                    .font(.system(size: 19, weight: .bold))
                Text("优先使用快门角度；应用会按当前帧率换算为曝光时间并写入相机。")
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.muted)

                Picker(
                    "视频帧率",
                    selection: Binding(
                        get: { model.videoFrameRate },
                        set: { model.setVideoFrameRate($0) }
                    )
                ) {
                    ForEach(frameRateOptions, id: \.self) { value in
                        Text("\(Int(value)) fps").tag(value)
                    }
                }

                Picker(
                    "快门角度",
                    selection: Binding(
                        get: { model.videoShutterAngle },
                        set: { model.setVideoShutterAngle($0) }
                    )
                ) {
                    ForEach(shutterAngleOptions, id: \.self) { value in
                        Text(value.formatted() + "°").tag(value)
                    }
                }
                .disabled(
                    model.connected
                        && !model.canAdjustExposureParameter("videoExposureTime")
                )

                Picker(
                    "光圈",
                    selection: Binding(
                        get: { model.aperture },
                        set: { value in
                            model.aperture = value
                            model.applyParameter("aperture", value: value, label: "光圈")
                        }
                    )
                ) {
                    ForEach(apertureOptions, id: \.self) { value in
                        Text("F\(value, specifier: "%.1f")").tag(value)
                    }
                }
                .disabled(
                    !model.connected
                        || !model.canAdjustExposureParameter("aperture")
                )

                Picker(
                    "ISO感光度",
                    selection: Binding(
                        get: { model.iso },
                        set: { value in
                            model.iso = value
                            model.applyParameter("iso", value: value, label: "ISO感光度")
                        }
                    )
                ) {
                    ForEach(isoOptions, id: \.self) { value in
                        Text("\(value)").tag(value)
                    }
                }
                .disabled(!model.connected)

                Picker(
                    "白平衡",
                    selection: Binding(
                        get: { model.whiteBalance },
                        set: { value in
                            model.whiteBalance = value
                            model.applyParameter(
                                "whiteBalanceMode",
                                value: value,
                                label: "白平衡"
                            )
                        }
                    )
                ) {
                    Text("自动").tag("continuous")
                    Text("手动预设").tag("manual")
                }
                .disabled(!model.connected)

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("曝光补偿")
                        Spacer()
                        Text("\(model.compensation, specifier: "%+.1f") EV")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(Palette.video)
                    }
                    Slider(
                        value: $model.compensation,
                        in: -5...5,
                        step: 1.0 / 3.0
                    )
                    Button("应用曝光补偿") {
                        model.applyParameter(
                            "exposureCompensation",
                            value: model.compensation,
                            label: "曝光补偿"
                        )
                    }
                    .buttonStyle(.link)
                    .disabled(
                        !model.connected
                            || !model.canAdjustExposureParameter("exposureCompensation")
                    )
                }
            }
            .padding(18)

            Divider()

            VStack(alignment: .leading, spacing: 14) {
                Text("监看输出")
                    .font(.system(size: 19, weight: .bold))

                Picker(
                    "监看显示尺寸",
                    selection: Binding(
                        get: { model.monitorVideoProfile },
                        set: { model.setMonitorVideoProfile($0) }
                    )
                ) {
                    ForEach(MonitorVideoProfile.allCases) { profile in
                        RuntimeLocalizedText(profile.label).tag(profile)
                    }
                }

                Picker("实时取景格式", selection: .constant("jpeg")) {
                    Text("JPEG（相机输出）").tag("jpeg")
                }
                .disabled(true)

                Text("Nikon PTP 返回 JPEG 实时取景帧。监看显示尺寸仅处理本地预览，不会改变机身的视频文件类型或画面尺寸。")
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(18)

            Divider()

            VStack(alignment: .leading, spacing: 14) {
                Text("监看辅助")
                    .font(.system(size: 19, weight: .bold))

                Toggle(
                    "加亮显示条纹图案",
                    isOn: Binding(
                        get: { model.zebraEnabled },
                        set: { model.setZebraEnabled($0) }
                    )
                )
                .toggleStyle(.switch)

                HStack {
                    Slider(
                        value: Binding(
                            get: { model.zebraThreshold },
                            set: { model.setZebraThreshold($0) }
                        ),
                        in: 70...100,
                        step: 1
                    )
                    Text("\(Int(model.zebraThreshold)) IRE")
                        .font(.system(size: 12, design: .monospaced))
                        .frame(width: 58)
                }
                .disabled(!model.zebraEnabled)

                Toggle(
                    "峰值对焦",
                    isOn: Binding(
                        get: { model.focusPeakingEnabled },
                        set: { model.setFocusPeakingEnabled($0) }
                    )
                )
                .toggleStyle(.switch)

                Toggle(
                    "假色曝光",
                    isOn: Binding(
                        get: { model.falseColorEnabled },
                        set: { model.setFalseColorEnabled($0) }
                    )
                )
                .toggleStyle(.switch)

                VStack(alignment: .leading, spacing: 5) {
                    monitorScope("R", model.redHistogram, .red)
                    monitorScope("G", model.greenHistogram, .green)
                    monitorScope("B", model.blueHistogram, .blue)
                    monitorScope("波形", model.waveform, Palette.ink)
                    monitorScope("矢量", model.vectorscope, Palette.ink)
                    Text("峰值覆盖 · \(model.peakingCoverage)%")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Palette.muted)
                }
                .padding(10)
                .background(Palette.paper)
                .clipShape(RoundedRectangle(cornerRadius: 8))

                Toggle(
                    "应用本地 LUT",
                    isOn: Binding(
                        get: { model.lutEnabled },
                        set: { model.setLUTEnabled($0) }
                    )
                )
                .toggleStyle(.switch)
                .disabled(model.lutName == nil)

                HStack {
                    Button("导入 .cube") {
                        showLUTImporter = true
                    }
                    .buttonStyle(.link)
                    if model.lutName != nil {
                        Button("移除 LUT") {
                            model.clearLUT()
                        }
                        .buttonStyle(.link)
                    }
                }
                RuntimeLocalizedText(
                    model.lutName
                        ?? "尚未导入；LUT 只影响视频监看，不写入原片。"
                )
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(18)
        }
        .background(Palette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(Palette.rule, lineWidth: 1)
        }
        .fileImporter(
            isPresented: $showLUTImporter,
            allowedContentTypes: [UTType(filenameExtension: "cube") ?? .data],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first { model.importLUT(from: url) }
            case .failure(let error):
                model.errorMessage = "无法打开 LUT：\(error.localizedDescription)"
            }
        }
    }

    private func monitorScope(
        _ label: String,
        _ value: String,
        _ color: Color
    ) -> some View {
        HStack(spacing: 7) {
            Text(label)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(color)
                .frame(width: 28, alignment: .leading)
            Text(value)
                .font(.system(size: 10, design: .monospaced))
                .lineLimit(1)
                .minimumScaleFactor(0.55)
        }
    }
}

private struct CaptureSessionPanel: View {
    @ObservedObject var workflow: CaptureWorkflow
    @State private var expanded = true
    @State private var name = "未命名会话"
    @State private var namingTemplate = "{session}_{date}_{counter}"
    @State private var creator = ""
    @State private var rights = ""
    @State private var rating = 0
    @State private var dualBackupEnabled = true

    var body: some View {
        DisclosureGroup("拍摄会话", isExpanded: $expanded) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    TextField("项目名称", text: $name)
                    TextField("命名模板", text: $namingTemplate)
                        .font(.system(.body, design: .monospaced))
                }
                HStack {
                    TextField("创作者", text: $creator)
                    TextField("版权", text: $rights)
                    Stepper("评级 \(rating) 星", value: $rating, in: 0...5)
                    Toggle("双目标备份", isOn: $dualBackupEnabled)
                }
                Text("命名支持 {session}、{date}、{counter}、{camera}；RAW + JPEG 自动配对，并生成 XMP 与 SHA-256 清单。")
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.muted)
                HStack {
                    RuntimeLocalizedText(workflow.status)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(Palette.muted)
                    Spacer()
                    Button(workflow.isActive ? "结束会话" : "开始会话") {
                        toggleSession()
                    }
                    .buttonStyle(NativeButtonStyle(primary: true))
                }
            }
            .padding(.top, 10)
        }
        .font(.system(size: 19, weight: .bold))
        .onAppear(perform: loadConfiguration)
    }

    private func loadConfiguration() {
        let configuration = workflow.configuration
        name = configuration.name
        namingTemplate = configuration.namingTemplate
        creator = configuration.creator
        rights = configuration.rights
        rating = configuration.rating
        dualBackupEnabled = configuration.dualBackupEnabled
    }

    private func toggleSession() {
        if workflow.isActive {
            workflow.end()
        } else {
            do {
                try workflow.begin(
                    CaptureSessionConfiguration(
                        name: name,
                        namingTemplate: namingTemplate,
                        creator: creator,
                        rights: rights,
                        rating: rating,
                        dualBackupEnabled: dualBackupEnabled
                    )
                )
            } catch {
                NSSound.beep()
            }
        }
    }
}

private struct LibraryView: View {
    @ObservedObject var model: CameraModel
    @State private var confirmDelete = false
    @State private var showCloudImporter = false
    @State private var showCloudGuide = false
    @State private var largePhoto: PhotoRecord?
    @State private var systemLargePhoto: SystemMacAlbumItem?
    @State private var systemAlbum: [SystemMacAlbumItem] = []
    @State private var systemAlbumStatus = "正在读取系统相册…"
    @State private var systemExpanded = true
    @State private var systemPhotosExpanded = true
    @State private var systemVideosExpanded = true
    @State private var localExpanded = true
    @State private var localPhotosExpanded = true
    @State private var localVideosExpanded = true
    @State private var wirelessExpanded = true

    private let columns = [
        GridItem(.adaptive(minimum: 180, maximum: 260), spacing: 16)
    ]

    var body: some View {
        HSplitView {
            VStack(spacing: 0) {
                HStack {
                WorkspaceHeading(
                    title: "文件与传输",
                    subtitle: "\(model.photos.count) 个本地文件 · 无线照片自动入库"
                )
                Spacer()
                Button("刷新相册") {
                    Task { await loadSystemAlbum() }
                }
                    .buttonStyle(NativeButtonStyle())
                Button("链接网盘") { showCloudGuide = true }
                    .buttonStyle(NativeButtonStyle())
                if let selectedPhoto = model.selectedPhoto {
                    ShareLink(item: selectedPhoto.url) {
                        Label("分享到社交平台", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(NativeButtonStyle(primary: true))
                }
                Button("在访达中显示") { model.revealLibrary() }
                    .buttonStyle(NativeButtonStyle())
                Button("移到废纸篓") { confirmDelete = true }
                    .buttonStyle(NativeButtonStyle())
                    .disabled(model.selectedPhoto == nil)
            }
            .padding(24)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    CaptureSessionPanel(workflow: model.captureWorkflow)

                    DisclosureGroup(
                        "系统相册 · \(systemAlbum.count)",
                        isExpanded: $systemExpanded
                    ) {
                        if systemAlbum.isEmpty {
                            ContentUnavailableView(
                                "系统相册暂不可见",
                                systemImage: "photo.on.rectangle",
                                description: Text("允许照片访问后，照片和视频会直接显示在文件页。")
                            )
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 180)
                        } else {
                            DisclosureGroup(
                                "照片 · \(systemAlbum.filter { !$0.isVideo }.count)",
                                isExpanded: $systemPhotosExpanded
                            ) {
                                systemAlbumGrid(systemAlbum.filter { !$0.isVideo })
                            }
                            DisclosureGroup(
                                "视频 · \(systemAlbum.filter(\.isVideo).count)",
                                isExpanded: $systemVideosExpanded
                            ) {
                                systemAlbumGrid(systemAlbum.filter(\.isVideo))
                            }
                        }
                    }
                    .font(.system(size: 19, weight: .bold))

                    DisclosureGroup(
                        "帧澈 ZENCHE 文件库 · \(model.photos.count)",
                        isExpanded: $localExpanded
                    ) {
                        if model.photos.isEmpty {
                            ContentUnavailableView(
                                "还没有联机拍摄文件",
                                systemImage: "photo.on.rectangle.angled",
                                description: Text("文件将保存在“图片/帧澈 ZENCHE”。")
                            )
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 180)
                        } else {
                            DisclosureGroup(
                                "照片 · \(model.photos.filter { !$0.isVideo }.count)",
                                isExpanded: $localPhotosExpanded
                            ) {
                                localPhotoGrid(model.photos.filter { !$0.isVideo })
                            }
                            DisclosureGroup(
                                "视频 · \(model.photos.filter(\.isVideo).count)",
                                isExpanded: $localVideosExpanded
                            ) {
                                localPhotoGrid(model.photos.filter(\.isVideo))
                            }
                        }
                    }
                    .font(.system(size: 19, weight: .bold))
                }
                .padding(24)
            }
            }
            .frame(minWidth: 560)
            VStack(alignment: .leading, spacing: 0) {
                DisclosureGroup(
                    "无线传输 · FTP / HTTP / WebDAV",
                    isExpanded: $wirelessExpanded
                ) {
                    TransferView(model: model)
                }
                .font(.system(size: 17, weight: .bold))
                .padding(18)
            }
            .frame(minWidth: 380, idealWidth: 440, maxWidth: 520)
        }
        .alert("将照片移到废纸篓？", isPresented: $confirmDelete) {
            Button("取消", role: .cancel) {}
            Button("移到废纸篓", role: .destructive) {
                model.deleteSelectedPhoto()
            }
        } message: {
            RuntimeLocalizedText(model.selectedPhoto?.name ?? "")
        }
        .fileImporter(
            isPresented: $showCloudImporter,
            allowedContentTypes: [
                .image,
                .movie,
                UTType(filenameExtension: "nef") ?? .data,
                UTType(filenameExtension: "nrw") ?? .data
            ],
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case .success(let urls):
                model.importPhotos(from: urls)
            case .failure(let error):
                model.errorMessage =
                    "无法从网盘导入照片：\(error.localizedDescription)"
            }
        }
        .sheet(item: $largePhoto) { photo in
            LargePhotoView(photo: photo)
        }
        .sheet(item: $systemLargePhoto) { item in
            SystemMacAlbumPreview(item: item)
        }
        .sheet(isPresented: $showCloudGuide) {
            MacCloudDriveGuide {
                showCloudGuide = false
                DispatchQueue.main.async {
                    showCloudImporter = true
                }
            }
        }
        .task {
            await loadSystemAlbum()
        }
    }

    @ViewBuilder
    private func systemAlbumGrid(_ items: [SystemMacAlbumItem]) -> some View {
        LazyVGrid(columns: columns, spacing: 16) {
            ForEach(items) { item in
                SystemMacAlbumThumbnail(item: item)
                    .onTapGesture(count: 2) {
                        systemLargePhoto = item
                    }
            }
        }
    }

    @ViewBuilder
    private func localPhotoGrid(_ items: [PhotoRecord]) -> some View {
        LazyVGrid(columns: columns, spacing: 16) {
            ForEach(items) { photo in
                Button {
                    model.selectedPhoto = photo
                } label: {
                    VStack(alignment: .leading, spacing: 9) {
                        if photo.isVideo {
                            ZStack {
                                Rectangle().fill(Palette.graphite)
                                Image(systemName: "play.rectangle.fill")
                                    .font(.system(size: 34))
                                    .foregroundStyle(.white.opacity(0.78))
                            }
                            .frame(height: 132)
                        } else if let image = NSImage(contentsOf: photo.url) {
                            Image(nsImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(height: 132)
                                .clipped()
                        } else {
                            Rectangle()
                                .fill(Palette.graphite)
                                .frame(height: 132)
                        }
                        Text(photo.name)
                            .font(.system(size: 12, weight: .semibold))
                            .lineLimit(1)
                        Text(
                            photo.createdAt.formatted(
                                date: .abbreviated,
                                time: .shortened
                            )
                        )
                        .font(.system(size: 11))
                        .foregroundStyle(Palette.muted)
                    }
                    .padding(10)
                    .background(Palette.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay {
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                model.selectedPhoto == photo
                                    ? Palette.cobalt : Palette.rule,
                                lineWidth: model.selectedPhoto == photo ? 2 : 1
                            )
                    }
                }
                .buttonStyle(.plain)
                .simultaneousGesture(
                    TapGesture(count: 2).onEnded {
                        model.selectedPhoto = photo
                        largePhoto = photo
                    }
                )
            }
        }
    }

    @MainActor
    private func loadSystemAlbum() async {
        var status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        if status == .notDetermined {
            status = await withCheckedContinuation { continuation in
                PHPhotoLibrary.requestAuthorization(for: .readWrite) {
                    continuation.resume(returning: $0)
                }
            }
        }
        guard status == .authorized || status == .limited else {
            systemAlbum = []
            systemAlbumStatus = "未获得相册读取权限"
            return
        }
        let options = PHFetchOptions()
        options.fetchLimit = 80
        options.sortDescriptors = [
            NSSortDescriptor(key: "creationDate", ascending: false)
        ]
        let assets = PHAsset.fetchAssets(with: options)
        var items: [SystemMacAlbumItem] = []
        assets.enumerateObjects { asset, _, _ in
            items.append(SystemMacAlbumItem(asset: asset))
        }
        systemAlbum = items
        systemAlbumStatus = status == .limited
            ? "已显示允许访问的 \(items.count) 项"
            : "最近 \(items.count) 项"
    }
}

private struct SystemMacAlbumItem: Identifiable {
    let asset: PHAsset

    var id: String { asset.localIdentifier }
    var isVideo: Bool { asset.mediaType == .video }
    var name: String {
        PHAssetResource.assetResources(for: asset).first?.originalFilename
            ?? (isVideo ? "系统视频" : "系统照片")
    }
}

private struct SystemMacAlbumThumbnail: View {
    let item: SystemMacAlbumItem
    @State private var thumbnail: NSImage?

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            ZStack(alignment: .bottomTrailing) {
                if let thumbnail {
                    Image(nsImage: thumbnail)
                        .resizable()
                        .scaledToFill()
                } else {
                    Rectangle().fill(Palette.graphite)
                    Image(systemName: item.isVideo ? "video.fill" : "photo")
                        .font(.system(size: 30))
                        .foregroundStyle(.white.opacity(0.62))
                }
                if item.isVideo {
                    Label(durationLabel, systemImage: "play.fill")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 5)
                        .background(.black.opacity(0.68), in: Capsule())
                        .padding(7)
                }
            }
            .frame(height: 132)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 10))
            Text(item.name)
                .font(.system(size: 12, weight: .semibold))
                .lineLimit(1)
            RuntimeLocalizedText(
                item.isVideo ? "系统视频 · 双击播放" : "系统照片 · 双击查看"
            )
                .font(.system(size: 11))
                .foregroundStyle(Palette.muted)
        }
        .padding(10)
        .background(Palette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(Palette.rule, lineWidth: 1)
        }
        .task(id: item.id) {
            PHImageManager.default().requestImage(
                for: item.asset,
                targetSize: NSSize(width: 520, height: 360),
                contentMode: .aspectFill,
                options: nil
            ) { image, _ in
                if let image {
                    thumbnail = image
                }
            }
        }
    }

    private var durationLabel: String {
        let seconds = max(0, Int(item.asset.duration.rounded()))
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}

private struct SystemMacAlbumPreview: View {
    @Environment(\.dismiss) private var dismiss
    let item: SystemMacAlbumItem
    @State private var image: NSImage?
    @State private var player: AVPlayer?

    var body: some View {
        VStack(spacing: 14) {
            HStack {
                Button("关闭") {
                    player?.pause()
                    dismiss()
                }
                .buttonStyle(NativeButtonStyle())
                Spacer()
                Text("系统相册 · \(item.name)")
                    .font(.system(size: 12, design: .monospaced))
                    .lineLimit(1)
            }
            if item.isVideo {
                if let player {
                    VideoPlayer(player: player)
                        .onAppear { player.play() }
                } else {
                    ProgressView("正在载入视频…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else if let image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ProgressView("正在载入照片…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding(18)
        .frame(minWidth: 760, minHeight: 560)
        .background(Color.black)
        .foregroundStyle(.white)
        .task {
            if item.isVideo {
                PHImageManager.default().requestPlayerItem(
                    forVideo: item.asset,
                    options: nil
                ) { playerItem, _ in
                    if let playerItem {
                        player = AVPlayer(playerItem: playerItem)
                    }
                }
            } else {
                PHImageManager.default().requestImage(
                    for: item.asset,
                    targetSize: NSSize(width: 2400, height: 2400),
                    contentMode: .aspectFit,
                    options: nil
                ) { loaded, _ in
                    image = loaded
                }
            }
        }
    }
}

private struct MacCloudDriveProvider: Identifiable {
    let name: String
    let note: String
    let url: URL
    var id: String { name }

    static let domestic: [MacCloudDriveProvider] = [
        .init(name: "百度网盘", note: "安装客户端后，从下载或同步目录选择。", url: URL(string: "https://pan.baidu.com/")!),
        .init(name: "阿里云盘", note: "支持 macOS 桌面端；先下载或同步媒体。", url: URL(string: "https://www.alipan.com/")!),
        .init(name: "腾讯微云", note: "从微云客户端把文件下载到访达。", url: URL(string: "https://www.weiyun.com/")!),
        .init(name: "夸克网盘", note: "使用桌面客户端下载到本机目录。", url: URL(string: "https://pan.quark.cn/")!),
        .init(name: "迅雷云盘", note: "通过迅雷客户端下载后从访达选择。", url: URL(string: "https://pan.xunlei.com/")!),
        .init(name: "115", note: "在“存储”中下载文件后从访达选择。", url: URL(string: "https://115.com/")!)
    ]
}

private struct MacCloudDriveGuide: View {
    @Environment(\.dismiss) private var dismiss
    let chooseFiles: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("链接网盘")
                        .font(.system(size: 26, weight: .bold))
                    Text("账号和密码始终由网盘客户端管理。")
                        .foregroundStyle(Palette.muted)
                }
                Spacer()
                Button("关闭") { dismiss() }
                    .buttonStyle(NativeButtonStyle())
            }
            ScrollView {
                VStack(spacing: 10) {
                    ForEach(MacCloudDriveProvider.domestic) { provider in
                        Button {
                            NSWorkspace.shared.open(provider.url)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "externaldrive.connected.to.line.below")
                                    .font(.system(size: 20))
                                    .foregroundStyle(Palette.cobalt)
                                    .frame(width: 40, height: 40)
                                    .background(Palette.cobaltSoft)
                                    .clipShape(RoundedRectangle(cornerRadius: 9))
                                VStack(alignment: .leading, spacing: 3) {
                                    RuntimeLocalizedText(provider.name)
                                        .font(.system(size: 14, weight: .bold))
                                    RuntimeLocalizedText(provider.note)
                                        .font(.system(size: 12))
                                        .foregroundStyle(Palette.muted)
                                }
                                Spacer()
                                Image(systemName: "arrow.up.right")
                                    .foregroundStyle(Palette.muted)
                            }
                            .padding(12)
                            .background(Palette.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay {
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Palette.rule)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            Text("步骤：安装并登录网盘客户端 → 下载/同步照片或视频 → 选择文件并加入 帧澈 ZENCHE 文件库。")
                .font(.system(size: 12))
                .foregroundStyle(Palette.muted)
            Button("选择文件并加入", action: chooseFiles)
                .buttonStyle(NativeButtonStyle(primary: true))
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(22)
        .frame(width: 620, height: 640)
        .background(Palette.paper)
    }
}

private struct LargePhotoView: View {
    @Environment(\.dismiss) private var dismiss
    let photo: PhotoRecord
    @State private var player: AVPlayer?

    var body: some View {
        VStack(spacing: 14) {
            HStack {
                Button("关闭") { dismiss() }
                    .buttonStyle(NativeButtonStyle())
                Spacer()
                Text(photo.name)
                    .font(.system(size: 12, design: .monospaced))
                    .lineLimit(1)
                Spacer()
                ShareLink(item: photo.url) {
                    Label("分享到社交平台", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(NativeButtonStyle(primary: true))
            }
            if photo.isVideo {
                if let player {
                    VideoPlayer(player: player)
                        .onAppear { player.play() }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.black)
                } else {
                    ProgressView("正在载入视频…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else if let image = NSImage(contentsOf: photo.url) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black)
            } else {
                ContentUnavailableView(
                    "无法显示大图",
                    systemImage: "photo.badge.exclamationmark",
                    description: Text("文件已安全保存在 帧澈 ZENCHE 文件库。")
                )
            }
        }
        .padding(18)
        .frame(minWidth: 760, minHeight: 560)
        .background(Palette.paper)
        .task {
            if photo.isVideo {
                player = AVPlayer(url: photo.url)
            }
        }
    }
}

private struct TransferView: View {
    @ObservedObject var model: CameraModel
    @ObservedObject private var wireless: WirelessTransferServer

    init(model: CameraModel) {
        self.model = model
        _wireless = ObservedObject(wrappedValue: model.wirelessTransfer)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text("无线传输").font(.system(size: 34, weight: .bold))
                Text("通过 FTP、HTTP 或 WebDAV，把 JPEG、NEF 或 HEIF 直接发送到 帧澈 ZENCHE；接收完成后会自动进入文件库。")
                    .foregroundStyle(Palette.muted)
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 12),
                        GridItem(.flexible(), spacing: 12)
                    ],
                    spacing: 12
                ) {
                    statusCard(
                        icon: "internaldrive",
                        title: "本地照片库",
                        value: "\(model.photos.count) 个文件"
                    )
                    statusCard(
                        icon: wireless.isRunning ? "wifi" : "wifi.slash",
                        title: "无线收件箱",
                        value: wireless.status
                    )
                }

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("多协议无线图片接收").font(.title3.bold())
                            Text("适用于相机直连热点或同一可信局域网")
                                .foregroundStyle(Palette.muted)
                        }
                        Spacer()
                        Button {
                            if wireless.isRunning {
                                wireless.stop()
                            } else {
                                wireless.refreshAddress()
                                wireless.start()
                            }
                        } label: {
                            RuntimeLocalizedText(
                                wireless.isRunning
                                    ? "停止接收"
                                    : "开启无线接收"
                            )
                        }
                        .buttonStyle(NativeButtonStyle(primary: !wireless.isRunning))
                    }

                    Divider()
                    transferRow("服务器类型", "FTP")
                    transferRow("服务器地址", wireless.hostAddress)
                    transferRow("端口", "\(WirelessTransferServer.port)")
                    transferRow("用户名", WirelessTransferServer.username)
                    transferRow("密码", WirelessTransferServer.password)
                    transferRow("PASV 模式", "开启")
                    Divider()
                    transferRow(
                        "HTTP 上传",
                        "http://\(wireless.hostAddress):\(WirelessTransferServer.httpPort)/upload/文件名"
                    )
                    transferRow(
                        "WebDAV",
                        "http://\(wireless.hostAddress):\(WirelessTransferServer.httpPort)/"
                    )

                    Text("相机端选择 FTP 并开启 PASV；HTTP/WebDAV 使用相同账号的 Basic Auth，PUT/POST 请求需提供 Content-Length。首次启动时请允许 macOS 接受传入网络连接。")
                        .font(.system(size: 13))
                        .foregroundStyle(Palette.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(20)
                .background(Palette.surface)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay {
                    RoundedRectangle(cornerRadius: 14).stroke(Palette.rule)
                }

                HStack {
                    Button("刷新网络地址") { wireless.refreshAddress() }
                        .buttonStyle(NativeButtonStyle())
                    Button("打开保存位置") { model.revealLibrary() }
                        .buttonStyle(NativeButtonStyle())
                }
            }
            .padding(28)
        }
    }

    private func transferRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(LocalizedStringKey(title))
                .foregroundStyle(Palette.muted)
            Spacer()
            RuntimeLocalizedText(value)
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .multilineTextAlignment(.trailing)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
        }
    }

    private func statusCard(icon: String, title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 15) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundStyle(Palette.cobalt)
            Text(LocalizedStringKey(title)).font(.headline)
            RuntimeLocalizedText(value)
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(Palette.muted)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14).stroke(Palette.rule)
        }
    }
}

private struct SplashView: View {
    var onComplete: () -> Void
    @State private var markScale: CGFloat = 0.01
    @State private var markOpacity: Double = 0
    @State private var textOpacity: Double = 0

    var body: some View {
        ZStack {
            Palette.paper.ignoresSafeArea()
            VStack(spacing: 28) {
                ZStack {
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Palette.graphite)
                        .frame(width: 80, height: 80)
                        .scaleEffect(markScale)
                        .opacity(markOpacity)
                    Text("Z")
                        .font(.system(size: 42, weight: .heavy))
                        .foregroundStyle(.white)
                        .scaleEffect(markScale)
                        .opacity(markOpacity)
                }
                VStack(spacing: 6) {
                    Text("帧澈 ZENCHE")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(Palette.ink)
                    Text("Capture · Connect · Flow")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Palette.muted)
                }
                .opacity(textOpacity)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.65)) {
                markScale = 1
                markOpacity = 1
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation(.easeOut(duration: 0.5)) {
                    textOpacity = 1
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
                onComplete()
            }
        }
    }
}

private struct ConnectionSheet: View {
    @ObservedObject var model: CameraModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("连接相机").font(.system(size: 24, weight: .bold))
                    Text("原生 USB/PTP · 不使用浏览器视频接口")
                        .foregroundStyle(Palette.muted)
                }
                Spacer()
                Button("关闭") { dismiss() }
                    .buttonStyle(.plain)
            }
            HStack(spacing: 16) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(Palette.cobalt)
                    .frame(width: 54, height: 54)
                    .background(Palette.cobaltSoft)
                    .clipShape(RoundedRectangle(cornerRadius: 11))
                VStack(alignment: .leading, spacing: 3) {
                    Text("Nikon Z 系列原生 USB")
                        .font(.system(size: 17, weight: .bold))
                    Text(SupportedCamera.summary)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Palette.cobalt)
                    Text("联机拍摄、参数控制、实时监看和文件传输")
                        .foregroundStyle(Palette.muted)
                }
                Spacer()
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Palette.cobalt)
            }
            .padding(16)
            .background(Palette.cobaltSoft.opacity(0.55))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            Text("请打开相机，使用支持数据传输的 USB 线直连，并退出 NX Tether。")
                .font(.system(size: 13))
                .foregroundStyle(Palette.muted)
            HStack {
                Spacer()
                Button("取消") { dismiss() }
                    .buttonStyle(NativeButtonStyle())
                Button {
                    model.connect()
                    dismiss()
                } label: {
                    RuntimeLocalizedText(
                        model.connecting
                            ? "正在连接…"
                            : "连接 Nikon 相机"
                    )
                }
                .buttonStyle(NativeButtonStyle(primary: true))
                .disabled(model.connecting)
            }
        }
        .padding(26)
        .frame(width: 560)
        .background(Palette.paper)
    }
}

private struct RootView: View {
    @ObservedObject var model: CameraModel
    @StateObject private var updater = UpdateController()
    @AppStorage("appLanguage") private var languageRaw = "zh-Hans"
    @AppStorage("dismissedLaunchAnnouncementVersion")
    private var dismissedAnnouncementVersion = ""
    @State private var showConnection = false
    @State private var showSettings = false
    @State private var showLaunchAnnouncement = false
    @State private var doNotRemindForCurrentVersion = false
    @State private var showSplash = true

    private static var appVersion: String {
        Bundle.main.object(
            forInfoDictionaryKey: "CFBundleShortVersionString"
        ) as? String ?? "1.1.0"
    }

    var body: some View {
        VStack(spacing: 0) {
            TopBar(
                model: model,
                showConnection: $showConnection,
                showSettings: $showSettings
            )
            HStack(spacing: 0) {
                Sidebar(model: model)
                Group {
                    switch model.section {
                    case .capture:
                        CaptureView(model: model, showConnection: $showConnection)
                    case .monitor:
                        MonitorView(model: model)
                    case .library:
                        LibraryView(model: model)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .animation(.easeInOut(duration: 0.22), value: model.section)
            }
            HStack {
                HStack(spacing: 5) {
                    Image(
                        systemName: model.connected
                            ? "link"
                            : "link.badge.plus"
                    )
                    RuntimeLocalizedText(model.status)
                }
                Spacer()
                RuntimeLocalizedText(model.detail)
                Spacer()
                Text("本次照片 · \(model.photos.count) 张")
            }
            .font(.system(size: 11, weight: .medium, design: .monospaced))
            .foregroundStyle(Color.white.opacity(0.72))
            .padding(.horizontal, 18)
            .frame(height: 32)
            .background(Palette.graphite)
        }
        .background(Palette.paper)
        .overlay {
            if showSplash {
                SplashView {
                    withAnimation(.easeInOut(duration: 0.6)) {
                        showSplash = false
                    }
                }
            }
        }
        .environment(
            \.locale,
            InterfaceLanguage(rawValue: languageRaw)?.locale
                ?? InterfaceLanguage.simplifiedChinese.locale
        )
        .sheet(isPresented: $showConnection) {
            ConnectionSheet(model: model)
        }
        .sheet(isPresented: $showSettings) {
            SettingsSheet(
                updater: updater,
                languageRaw: $languageRaw
            )
        }
        .sheet(isPresented: $showLaunchAnnouncement) {
            LaunchAnnouncementSheet(
                version: Self.appVersion,
                doNotRemind: $doNotRemindForCurrentVersion
            ) {
                if doNotRemindForCurrentVersion {
                    dismissedAnnouncementVersion = Self.appVersion
                }
                showLaunchAnnouncement = false
            }
            .interactiveDismissDisabled()
        }
        .onAppear {
            updateWindowTitle()
            updater.checkAutomaticallyIfNeeded()
            showLaunchAnnouncement =
                dismissedAnnouncementVersion != Self.appVersion
        }
        .onChange(of: languageRaw) { _, _ in
            updateWindowTitle()
        }
        .alert(
            "帧澈 ZENCHE",
            isPresented: Binding(
                get: { model.errorMessage != nil },
                set: { if !$0 { model.errorMessage = nil } }
            )
        ) {
            Button("打开日志") {
                DiagnosticLogger.shared.info(
                    "diagnostics",
                    "用户从错误提示打开日志目录"
                )
                NSWorkspace.shared.open(
                    DiagnosticLogger.shared.directoryURL
                )
                model.errorMessage = nil
            }
            Button("好") { model.errorMessage = nil }
        } message: {
            RuntimeLocalizedText(model.errorMessage ?? "")
        }
    }

    private func updateWindowTitle() {
        let title = languageRaw == InterfaceLanguage.simplifiedChinese.rawValue
            ? "帧澈 ZENCHE"
            : "ZENCHE"
        NSApp.mainWindow?.title = title
    }
}

private final class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow!
    private let model = CameraModel()

    func applicationDidFinishLaunching(_ notification: Notification) {
        DiagnosticLogger.shared.startSession()
        let root = RootView(model: model)
        let hostingView = NSHostingView(rootView: root)
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1440, height: 900),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "帧澈 ZENCHE"
        window.titlebarAppearsTransparent = true
        window.minSize = NSSize(width: 1040, height: 700)
        window.contentView = hostingView
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        print("帧澈 ZENCHE native SwiftUI ready")
    }

    func applicationWillTerminate(_ notification: Notification) {
        model.shutdown()
        DiagnosticLogger.shared.endSession()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

let application = NSApplication.shared
private let delegate = AppDelegate()
application.delegate = delegate
application.setActivationPolicy(.regular)
application.run()
