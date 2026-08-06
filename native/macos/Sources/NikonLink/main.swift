import AppKit
import AVKit
import Combine
import CoreImage
import Darwin
import Foundation
import ImageIO
import Photos
import Security
import SwiftUI
import UniformTypeIdentifiers

private struct SupportedCamera: Equatable {
    let name: String
    let vendorName: String
    let vendorID: Int
    let productID: Int
    let detectionTokens: [String]
    let minimumISO: Int
    let maximumISO: Int

    static let supportedVendorIDs: Set<Int> = [0x04b0, 0x054c, 0x04a9]

    static let all = [
        // ── Nikon EXPEED 5 ──
        SupportedCamera(
            name: "Nikon D500",
            vendorName: "Nikon",
            vendorID: 0x04b0,
            productID: 0x043a,
            detectionTokens: ["nikon d500", "nikon d 500"],
            minimumISO: 100,
            maximumISO: 51200
        ),
        SupportedCamera(
            name: "Nikon D7500",
            vendorName: "Nikon",
            vendorID: 0x04b0,
            productID: 0x0445,
            detectionTokens: ["nikon d7500", "nikon d 7500"],
            minimumISO: 100,
            maximumISO: 51200
        ),
        SupportedCamera(
            name: "Nikon D850",
            vendorName: "Nikon",
            vendorID: 0x04b0,
            productID: 0x044a,
            detectionTokens: ["nikon d850", "nikon d 850"],
            minimumISO: 64,
            maximumISO: 25600
        ),
        // ── Nikon EXPEED 6 ──
        SupportedCamera(
            name: "Nikon Z7",
            vendorName: "Nikon",
            vendorID: 0x04b0,
            productID: 0x0442,
            detectionTokens: ["nikon z7", "nikon z 7"],
            minimumISO: 64,
            maximumISO: 25600
        ),
        SupportedCamera(
            name: "Nikon Z6",
            vendorName: "Nikon",
            vendorID: 0x04b0,
            productID: 0x0443,
            detectionTokens: ["nikon z6", "nikon z 6"],
            minimumISO: 100,
            maximumISO: 51200
        ),
        SupportedCamera(
            name: "Nikon Z50",
            vendorName: "Nikon",
            vendorID: 0x04b0,
            productID: 0x0444,
            detectionTokens: ["nikon z50", "nikon z 50"],
            minimumISO: 100,
            maximumISO: 51200
        ),
        SupportedCamera(
            name: "Nikon D780",
            vendorName: "Nikon",
            vendorID: 0x04b0,
            productID: 0x0446,
            detectionTokens: ["nikon d780", "nikon d 780"],
            minimumISO: 100,
            maximumISO: 51200
        ),
        SupportedCamera(
            name: "Nikon D6",
            vendorName: "Nikon",
            vendorID: 0x04b0,
            productID: 0x0447,
            detectionTokens: ["nikon d6", "nikon d 6"],
            minimumISO: 100,
            maximumISO: 102400
        ),
        SupportedCamera(
            name: "Nikon Z5",
            vendorName: "Nikon",
            vendorID: 0x04b0,
            productID: 0x0448,
            detectionTokens: ["nikon z5", "nikon z 5"],
            minimumISO: 100,
            maximumISO: 51200
        ),
        SupportedCamera(
            name: "Nikon Z7II",
            vendorName: "Nikon",
            vendorID: 0x04b0,
            productID: 0x044b,
            detectionTokens: [
                "nikon z7 2", "nikon z7 ii", "nikon z7ii", "nikon z 7ii"
            ],
            minimumISO: 64,
            maximumISO: 25600
        ),
        SupportedCamera(
            name: "Nikon Z6II",
            vendorName: "Nikon",
            vendorID: 0x04b0,
            productID: 0x044c,
            detectionTokens: [
                "nikon z6 2", "nikon z6 ii", "nikon z6ii", "nikon z 6ii"
            ],
            minimumISO: 100,
            maximumISO: 51200
        ),
        SupportedCamera(
            name: "Nikon Z fc",
            vendorName: "Nikon",
            vendorID: 0x04b0,
            productID: 0x044f,
            detectionTokens: ["nikon zfc", "nikon z fc"],
            minimumISO: 100,
            maximumISO: 51200
        ),
        SupportedCamera(
            name: "Nikon Z30",
            vendorName: "Nikon",
            vendorID: 0x04b0,
            productID: 0x0452,
            detectionTokens: ["nikon z30", "nikon z 30"],
            minimumISO: 100,
            maximumISO: 51200
        ),
        // ── Nikon EXPEED 7 ──
        SupportedCamera(
            name: "Nikon Z9",
            vendorName: "Nikon",
            vendorID: 0x04b0,
            productID: 0x0450,
            detectionTokens: ["nikon z9", "nikon z 9"],
            minimumISO: 64,
            maximumISO: 25600
        ),
        SupportedCamera(
            name: "Nikon Z8",
            vendorName: "Nikon",
            vendorID: 0x04b0,
            productID: 0x0451,
            detectionTokens: ["nikon z8", "nikon z 8"],
            minimumISO: 64,
            maximumISO: 25600
        ),
        SupportedCamera(
            name: "Nikon Z f",
            vendorName: "Nikon",
            vendorID: 0x04b0,
            productID: 0x0453,
            detectionTokens: ["nikon zf", "nikon z f"],
            minimumISO: 100,
            maximumISO: 64000
        ),
        SupportedCamera(
            name: "Nikon Z6III",
            vendorName: "Nikon",
            vendorID: 0x04b0,
            productID: 0x0454,
            detectionTokens: ["nikon z6 iii", "nikon z6iii", "nikon z6 3"],
            minimumISO: 100,
            maximumISO: 64000
        ),
        SupportedCamera(
            name: "Nikon Z50II",
            vendorName: "Nikon",
            vendorID: 0x04b0,
            productID: 0x0455,
            detectionTokens: [
                "nikon z50 2", "nikon z50 ii", "nikon z50ii", "nikon z50_2"
            ],
            minimumISO: 100,
            maximumISO: 51200
        ),
        SupportedCamera(
            name: "Nikon Z5II",
            vendorName: "Nikon",
            vendorID: 0x04b0,
            productID: 0x0456,
            detectionTokens: ["nikon z5 2", "nikon z5 ii", "nikon z5ii"],
            minimumISO: 100,
            maximumISO: 64000
        ),
        SupportedCamera(
            name: "Nikon ZR",
            vendorName: "Nikon",
            vendorID: 0x04b0,
            productID: 0x0457,
            detectionTokens: ["nikon zr", "nikon z r"],
            minimumISO: 100,
            maximumISO: 51200
        ),
        // ── Sony α ── (Product ID 0 means vendor wildcard)
        // Full-frame E-mount
        SupportedCamera(
            name: "Sony A1",
            vendorName: "Sony",
            vendorID: 0x054c,
            productID: 0x0000,
            detectionTokens: ["sony a1", "sony ilce-1", "sony a 1"],
            minimumISO: 100,
            maximumISO: 32000
        ),
        SupportedCamera(
            name: "Sony A1 II",
            vendorName: "Sony",
            vendorID: 0x054c,
            productID: 0x0000,
            detectionTokens: ["sony a1 ii", "sony a1 2", "sony a1ii", "sony a1 mk2", "sony ilce-1m2"],
            minimumISO: 100,
            maximumISO: 32000
        ),
        SupportedCamera(
            name: "Sony A9 III",
            vendorName: "Sony",
            vendorID: 0x054c,
            productID: 0x0000,
            detectionTokens: ["sony a9 iii", "sony a9 3", "sony a9iii", "sony ilce-9m3"],
            minimumISO: 100,
            maximumISO: 51200
        ),
        SupportedCamera(
            name: "Sony A7R V",
            vendorName: "Sony",
            vendorID: 0x054c,
            productID: 0x0000,
            detectionTokens: ["sony a7r v", "sony a7r 5", "sony ilce-7rm5", "sony a7rv"],
            minimumISO: 100,
            maximumISO: 32000
        ),
        SupportedCamera(
            name: "Sony A7 IV",
            vendorName: "Sony",
            vendorID: 0x054c,
            productID: 0x0000,
            detectionTokens: ["sony a7 iv", "sony a7 4", "sony ilce-7m4", "sony a7m4"],
            minimumISO: 100,
            maximumISO: 51200
        ),
        SupportedCamera(
            name: "Sony A7S III",
            vendorName: "Sony",
            vendorID: 0x054c,
            productID: 0x0000,
            detectionTokens: ["sony a7s iii", "sony a7s 3", "sony ilce-7sm3", "sony a7s3"],
            minimumISO: 80,
            maximumISO: 102400
        ),
        SupportedCamera(
            name: "Sony A7C II",
            vendorName: "Sony",
            vendorID: 0x054c,
            productID: 0x0000,
            detectionTokens: ["sony a7c ii", "sony a7c 2", "sony ilce-7cm2", "sony a7c2"],
            minimumISO: 100,
            maximumISO: 51200
        ),
        SupportedCamera(
            name: "Sony A7C R",
            vendorName: "Sony",
            vendorID: 0x054c,
            productID: 0x0000,
            detectionTokens: ["sony a7c r", "sony a7cr", "sony ilce-7cr"],
            minimumISO: 100,
            maximumISO: 32000
        ),
        SupportedCamera(
            name: "Sony ZV-E1",
            vendorName: "Sony",
            vendorID: 0x054c,
            productID: 0x0000,
            detectionTokens: ["sony zv-e1", "sony zve1", "sony zv e1"],
            minimumISO: 80,
            maximumISO: 102400
        ),
        // APS-C E-mount
        SupportedCamera(
            name: "Sony A6700",
            vendorName: "Sony",
            vendorID: 0x054c,
            productID: 0x0000,
            detectionTokens: ["sony a6700", "sony a 6700", "sony ilce-6700"],
            minimumISO: 100,
            maximumISO: 32000
        ),
        SupportedCamera(
            name: "Sony FX30",
            vendorName: "Sony",
            vendorID: 0x054c,
            productID: 0x0000,
            detectionTokens: ["sony fx30", "sony fx 30", "sony ilme-fx30"],
            minimumISO: 100,
            maximumISO: 32000
        ),
        SupportedCamera(
            name: "Sony ZV-E10 II",
            vendorName: "Sony",
            vendorID: 0x054c,
            productID: 0x0000,
            detectionTokens: ["sony zv-e10 ii", "sony zv e10 ii", "sony zv-e10 2", "sony zve10 ii", "sony zve10 2", "sony zve10m2"],
            minimumISO: 100,
            maximumISO: 32000
        ),
        // ── Canon EOS R ── (Product IDs: TODO — confirm with gphoto2 --auto-detect)
        SupportedCamera(
            name: "Canon EOS R1",
            vendorName: "Canon",
            vendorID: 0x04a9,
            productID: 0x0000,
            detectionTokens: ["canon eos r1", "canon r1", "eos r1"],
            minimumISO: 100,
            maximumISO: 102400
        ),
        SupportedCamera(
            name: "Canon EOS R3",
            vendorName: "Canon",
            vendorID: 0x04a9,
            productID: 0x0000,
            detectionTokens: ["canon eos r3", "canon r3", "eos r3"],
            minimumISO: 100,
            maximumISO: 102400
        ),
        SupportedCamera(
            name: "Canon EOS R5",
            vendorName: "Canon",
            vendorID: 0x04a9,
            productID: 0x0000,
            detectionTokens: ["canon eos r5", "canon r5", "eos r5"],
            minimumISO: 100,
            maximumISO: 51200
        ),
        SupportedCamera(
            name: "Canon EOS R5 Mark II",
            vendorName: "Canon",
            vendorID: 0x04a9,
            productID: 0x0000,
            detectionTokens: ["canon eos r5 mark ii", "canon eos r5 mk ii", "canon eos r5 mk2", "canon eos r5 2", "canon r5 mark ii", "canon r5 mk2", "eos r5 mark ii"],
            minimumISO: 100,
            maximumISO: 51200
        ),
        SupportedCamera(
            name: "Canon EOS R6 Mark II",
            vendorName: "Canon",
            vendorID: 0x04a9,
            productID: 0x0000,
            detectionTokens: ["canon eos r6 mark ii", "canon eos r6 mk ii", "canon r6 mark ii", "canon r6 mk2", "canon r6 2", "eos r6 mark ii"],
            minimumISO: 100,
            maximumISO: 102400
        ),
        SupportedCamera(
            name: "Canon EOS R7",
            vendorName: "Canon",
            vendorID: 0x04a9,
            productID: 0x0000,
            detectionTokens: ["canon eos r7", "canon r7", "eos r7"],
            minimumISO: 100,
            maximumISO: 12800
        ),
        SupportedCamera(
            name: "Canon EOS R8",
            vendorName: "Canon",
            vendorID: 0x04a9,
            productID: 0x0000,
            detectionTokens: ["canon eos r8", "canon r8", "eos r8"],
            minimumISO: 100,
            maximumISO: 102400
        ),
        SupportedCamera(
            name: "Canon EOS R10",
            vendorName: "Canon",
            vendorID: 0x04a9,
            productID: 0x0000,
            detectionTokens: ["canon eos r10", "canon r10", "eos r10"],
            minimumISO: 100,
            maximumISO: 12800
        ),
        SupportedCamera(
            name: "Canon EOS R50",
            vendorName: "Canon",
            vendorID: 0x04a9,
            productID: 0x0000,
            detectionTokens: ["canon eos r50", "canon r50", "eos r50"],
            minimumISO: 100,
            maximumISO: 12800
        ),
        SupportedCamera(
            name: "Canon EOS R100",
            vendorName: "Canon",
            vendorID: 0x04a9,
            productID: 0x0000,
            detectionTokens: ["canon eos r100", "canon r100", "eos r100"],
            minimumISO: 100,
            maximumISO: 12800
        ),
        // ── Canon DIGIC X (2025 补齐) ──
        SupportedCamera(
            name: "Canon EOS R6 Mark III",
            vendorName: "Canon",
            vendorID: 0x04a9,
            productID: 0x0000,
            detectionTokens: ["canon eos r6 mark iii", "canon eos r6 mk iii", "canon eos r6 iii", "canon eos r6 3", "canon r6 mark iii", "canon r6 iii", "canon r6 mk3", "eos r6 mark iii"],
            minimumISO: 100,
            maximumISO: 64000
        ),
        SupportedCamera(
            name: "Canon EOS R6",
            vendorName: "Canon",
            vendorID: 0x04a9,
            productID: 0x0000,
            detectionTokens: ["canon eos r6", "canon r6", "eos r6"],
            minimumISO: 100,
            maximumISO: 102400
        ),
        SupportedCamera(
            name: "Canon EOS R5 C",
            vendorName: "Canon",
            vendorID: 0x04a9,
            productID: 0x0000,
            detectionTokens: ["canon eos r5 c", "canon eos r5c", "canon r5 c", "canon r5c", "eos r5 c", "eos r5c"],
            minimumISO: 100,
            maximumISO: 51200
        ),
        SupportedCamera(
            name: "Canon EOS R50 V",
            vendorName: "Canon",
            vendorID: 0x04a9,
            productID: 0x0000,
            detectionTokens: ["canon eos r50 v", "canon eos r50v", "canon r50 v", "canon r50v", "eos r50 v", "eos r50v"],
            minimumISO: 100,
            maximumISO: 32000
        ),
    ]

    static var summary: String {
        all.map { $0.name }
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

    static func matching(productID: Int, vendorID: Int) -> SupportedCamera? {
        all.first {
            $0.vendorID == vendorID
                && $0.productID != 0
                && $0.productID == productID
        }
    }

    static func matchingVendor(vendorID: Int) -> SupportedCamera? {
        switch vendorID {
        case 0x054c:
            return SupportedCamera(
                name: "Sony " + "α USB/PTP",
                vendorName: "Sony",
                vendorID: vendorID,
                productID: 0,
                detectionTokens: [],
                minimumISO: 100,
                maximumISO: 102400
            )
        case 0x04a9:
            return SupportedCamera(
                name: "Canon " + "EOS USB/PTP",
                vendorName: "Canon",
                vendorID: vendorID,
                productID: 0,
                detectionTokens: [],
                minimumISO: 100,
                maximumISO: 102400
            )
        default:
            return nil
        }
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
            return "没有检测到支持的相机（\(SupportedCamera.summary)）。请使用 USB 数据线直连，并关闭 NX Tether 等占用相机的软件。"
        case .wrongCamera(let value):
            return "检测到 \(value)，但当前版本尚未适配。请在兼容性文档中确认机型。"
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

    private struct StorageObjectLocation {
        let folder: String
        let index: Int
        let filename: String
    }

    private let resources = Bundle.main.resourceURL!
    private let logger = DiagnosticLogger.shared
    private let sonyOfficialSDK = SonyOfficialSDKService.shared
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
    private var storageObjects: [UInt32: StorageObjectLocation] = [:]

    var isLiveViewActive: Bool { liveView }
    var isMovieRecording: Bool { movieRecording }

    private var cameraName: String {
        profile?.name ?? "相机"
    }

    private var executable: URL {
        let bundled = resources.appendingPathComponent("bin/gphoto2")
        return FileManager.default.isExecutableFile(atPath: bundled.path)
            ? bundled
            : URL(fileURLWithPath: "/opt/homebrew/bin/gphoto2")
    }

    private var nikonPTPControlExecutable: URL {
        resources.appendingPathComponent("bin/zenche-nikon-ptp")
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
        // gphoto2's quiet list format contains only absolute paths. Storage
        // management also needs each folder-local file index for download and
        // deletion, plus size and delete-permission flags, so preserve the
        // detailed listing for this command only.
        process.arguments = (arguments.contains("--list-files") ? [] : ["--quiet"])
            + arguments
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
            if isBusyFailure(result.output) {
                if isManualFocusDriveCommand(arguments) {
                    if try waitUntilDeviceReady(timeout: 8) {
                        logger.info(
                            "camera",
                            "手动对焦步进返回相机忙；等待 DeviceReady 成功，视为步进已完成"
                        )
                        return ""
                    }
                    // gphoto2 starts Nikon's MFDrive before waiting for its
                    // completion. Do not replay the command after a timeout,
                    // or a slow camera could receive the same lens movement
                    // twice.
                    throw CameraError.command(
                        "\(cameraName) 的焦点步进仍在执行，请稍后再试。"
                    )
                }
                return try retryBusy(
                    arguments,
                    result: result,
                    timeout: timeout
                )
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

    func listStorage() throws -> CameraStorageSnapshot {
        guard connected else { throw CameraError.noCamera }
        guard !sonyOfficialSDK.isConnected else {
            throw CameraError.command(
                "Sony 官方 SDK 会话暂不开放机内文件枚举；请改用 USB/PTP 或 Wi‑Fi/PTP‑IP 连接管理存储卡。"
            )
        }
        return try performWithoutLiveView {
            let output = try run(["--recurse", "--list-files"], timeout: 120)
            var currentFolder = "/"
            var nextHandle: UInt32 = 1
            var locations: [UInt32: StorageObjectLocation] = [:]
            var items: [CameraStorageItem] = []
            let folderPattern = try NSRegularExpression(
                pattern: "folder ['\\\"]([^'\\\"]+)['\\\"]",
                options: [.caseInsensitive]
            )
            let filePattern = try NSRegularExpression(
                pattern: "^#([0-9]+)\\s+(.+?)\\s+([a-z-]+)\\s+([0-9]+(?:\\.[0-9]+)?)\\s*(B|KB|MB|GB)\\b",
                options: [.caseInsensitive]
            )
            let outputLines = output.split(whereSeparator: \.isNewline)
            for rawLine in outputLines {
                let line = String(rawLine).trimmingCharacters(in: .whitespaces)
                let lineRange = NSRange(line.startIndex..<line.endIndex, in: line)
                if let match = folderPattern.firstMatch(in: line, range: lineRange),
                   let range = Range(match.range(at: 1), in: line) {
                    currentFolder = String(line[range])
                    continue
                }
                guard let match = filePattern.firstMatch(in: line, range: lineRange),
                      let indexRange = Range(match.range(at: 1), in: line),
                      let filenameRange = Range(match.range(at: 2), in: line),
                      let flagsRange = Range(match.range(at: 3), in: line),
                      let amountRange = Range(match.range(at: 4), in: line),
                      let unitRange = Range(match.range(at: 5), in: line),
                      let fileIndex = Int(line[indexRange]) else {
                    continue
                }
                let filename = String(line[filenameRange])
                let flags = String(line[flagsRange]).lowercased()
                let amount = Double(line[amountRange]) ?? 0
                let multiplier: Double
                switch String(line[unitRange]).uppercased() {
                case "GB": multiplier = 1_073_741_824
                case "MB": multiplier = 1_048_576
                case "KB": multiplier = 1_024
                default: multiplier = 1
                }
                let byteCount = UInt64(max(0, min(amount * multiplier, Double(UInt64.max))))
                let handle = nextHandle
                nextHandle &+= 1
                locations[handle] = StorageObjectLocation(
                    folder: currentFolder,
                    index: fileIndex,
                    filename: filename
                )
                items.append(
                    CameraStorageItem(
                        handle: handle,
                        storageID: 1,
                        format: 0,
                        filename: filename,
                        sizeBytes: byteCount,
                        width: 0,
                        height: 0,
                        capturedAt: "—",
                        isProtected: !flags.contains("d")
                    )
                )
            }
            storageObjects = locations
            logger.info(
                "camera-storage",
                "已解析相机文件列表；输出行=\(outputLines.count)；文件=\(items.count)；目录=\(Set(locations.values.map(\.folder)).count)"
            )
            let reportedFiles = outputLines.contains { rawLine in
                let line = String(rawLine).trimmingCharacters(in: .whitespaces)
                if line.hasPrefix("#") || line.hasPrefix("/") {
                    return true
                }
                return line.range(
                    of: #"There (?:is|are) [1-9][0-9]* files? in folder"#,
                    options: [.regularExpression, .caseInsensitive]
                ) != nil
            }
            if reportedFiles && items.isEmpty {
                throw CameraError.command(
                    "相机返回了文件列表，但当前版本无法识别其格式；请导出诊断日志后重试。"
                )
            }
            let usedBytes = items.reduce(UInt64(0)) { partial, item in
                let addition = partial.addingReportingOverflow(item.sizeBytes)
                return addition.overflow ? UInt64.max : addition.partialValue
            }
            return CameraStorageSnapshot(
                volumes: [
                    CameraStorageVolume(
                        id: 1,
                        name: "相机存储卡",
                        capacityBytes: usedBytes,
                        freeBytes: 0,
                        freeImages: 0,
                        isReadOnly: false
                    )
                ],
                items: items
            )
        }
    }

    func storageThumbnail(handle: UInt32) throws -> Data {
        try storageData(handle: handle, thumbnail: true)
    }

    func storageObject(handle: UInt32) throws -> Data {
        try storageData(handle: handle, thumbnail: false)
    }

    private func storageData(handle: UInt32, thumbnail: Bool) throws -> Data {
        guard connected else { throw CameraError.noCamera }
        guard let location = storageObjects[handle] else {
            throw CameraError.command("机内文件列表已变化，请刷新后重试。")
        }
        return try performWithoutLiveView {
            let suffix = thumbnail ? "jpg" : URL(fileURLWithPath: location.filename).pathExtension
            let destination = FileManager.default.temporaryDirectory
                .appendingPathComponent("zenche-storage-\(UUID().uuidString).\(suffix.isEmpty ? "bin" : suffix)")
            defer { try? FileManager.default.removeItem(at: destination) }
            _ = try run(
                [
                    "--folder", location.folder,
                    thumbnail ? "--get-thumbnail" : "--get-file", String(location.index),
                    "--filename", destination.path,
                    "--force-overwrite"
                ],
                timeout: thumbnail ? 45 : 180
            )
            return try Data(contentsOf: destination)
        }
    }

    func deleteStorageObject(handle: UInt32) throws {
        guard connected else { throw CameraError.noCamera }
        guard let location = storageObjects[handle] else {
            throw CameraError.command("机内文件列表已变化，请刷新后重试。")
        }
        try performWithoutLiveView {
            _ = try run(
                ["--folder", location.folder, "--delete-file", String(location.index)],
                timeout: 90
            )
            storageObjects.removeValue(forKey: handle)
        }
    }

    private func retryBusy(
        _ arguments: [String],
        result: CommandResult,
        timeout: TimeInterval
    ) throws -> String {
        let name = diagnosticCommandName(arguments)
        for busyAttempt in 1...3 {
            logger.warning(
                "camera",
                "\(name) 检测到相机正忙，等待后重试（第 \(busyAttempt)/3 次）；输出=\(result.output.isEmpty ? "<无>" : result.output)"
            )
            Thread.sleep(forTimeInterval: 0.4)
            let retry = try execute(
                arguments,
                timeout: timeout,
                guardUSBClaim: false
            )
            if retry.status == 0 {
                logger.info(
                    "camera",
                    "\(name) 忙后重试成功（第 \(busyAttempt) 次）"
                )
                return retry.output
            }
            if isThermalFailure(retry.output) {
                throw CameraError.thermal(cameraName)
            }
            if !isBusyFailure(retry.output) {
                throw CameraError.command(
                    userFacingError(for: retry.output)
                )
            }
        }
        logger.warning(
            "camera",
            "\(name) 重试 3 次后相机仍忙，放弃本次操作"
        )
        throw CameraError.command(
            "\(cameraName) 正在处理拍摄操作（存储卡写入、间隔拍摄或长曝光），暂时无法响应。请稍后重试。"
        )
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

    private func isBusyFailure(_ output: String) -> Bool {
        let normalized = output.lowercased()
        return normalized.contains("busy")
            || normalized.contains("i/o in progress")
            || normalized.contains("io in progress")
            || normalized.contains("error (-110")
            || normalized.contains("processing of shooting operation")
            || normalized.contains("相机正忙")
            || normalized.contains("正在处理拍摄操作")
    }

    private func isManualFocusDriveCommand(_ arguments: [String]) -> Bool {
        guard let index = arguments.firstIndex(of: "--set-config"),
              arguments.indices.contains(index + 1) else {
            return false
        }
        return arguments[index + 1]
            .lowercased()
            .hasPrefix("manualfocusdrive=")
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
            if let vendor,
               SupportedCamera.supportedVendorIDs.contains(vendor) {
                if let product,
                   let match = SupportedCamera.matching(
                    productID: product,
                    vendorID: vendor
                   ) {
                    return match
                }
                let descriptor = dictionary.values
                    .compactMap { $0 as? String }
                    .joined(separator: " ")
                if let match = SupportedCamera.matching(detection: descriptor) {
                    return match
                }
                if let match = SupportedCamera.matchingVendor(vendorID: vendor) {
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
            let detectedLower = detected.lowercased()
            if !detectedLower.contains("ptp class camera") {
                logger.error("camera", "连接失败：未检测到支持的相机")
                throw CameraError.noCamera
            }
            let name = detected.split(separator: "\n").last.map(String.init) ?? "其他相机"
            logger.error("camera", "连接失败：检测到不支持的相机 \(name)")
            throw CameraError.wrongCamera(name)
        }
        if matchedProfile.vendorName == "Sony" {
            let saveDirectory = FileManager.default.temporaryDirectory
                .appendingPathComponent("ZENCHE/SonySDK", isDirectory: true)
            let sdkModel = try sonyOfficialSDK.connect(
                saveDirectory: saveDirectory
            )
            let officialProfile =
                SupportedCamera.matching(detection: "Sony \(sdkModel)")
                ?? matchedProfile
            profile = officialProfile
            connected = true
            refreshParameterCapabilities()
            logger.info(
                "sony-sdk",
                "已通过 Sony Camera Remote SDK 2.02.00 连接 \(sdkModel)"
            )
            return officialProfile
        }
        profile = matchedProfile
        _ = try run(["--summary"])
        connected = true
        refreshParameterCapabilities()
        logger.info("camera", "已连接 \(matchedProfile.name)")
        return matchedProfile
    }

    private func refreshParameterCapabilities() {
        let vendor = profile?.vendorName ?? "Nikon"
        if vendor == "Sony", sonyOfficialSDK.isConnected {
            parameterWritable = [
                "exposureTime": true,
                "videoExposureTime": true,
                "aperture": true,
                "iso": true,
                "exposureCompensation": true,
                "whiteBalanceMode": false,
                "focusMode": false,
                "exposureMode": false,
                "pictureControl": false,
                "videoCodec": true,
                "videoLog": true
            ]
            parameterConfigKeys = [:]
            return
        }
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
            "pictureControl": ["picturecontrol", "activepicctrlitem", "d200"],
            "videoCodec": vendor == "Sony"
                ? ["fileformatmovie", "moviefileformat", "d241"]
                : vendor == "Canon"
                    ? []
                    : ["moviefiletype", "movfiletype", "d0af"],
            "videoLog": vendor == "Sony"
                ? ["pictureprofile", "d23f"]
                : vendor == "Canon"
                    ? ["canonloggamma", "eos_canonloggamma", "d176"]
                    : ["movielogsetting", "movielogoutput", "d0bf", "d0bb"]
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
        if vendor == "Canon" {
            result["videoCodec"] = false
        }
        parameterWritable = result
        parameterConfigKeys = writableKeys
    }

    func parameterCapabilitySnapshot() -> [String: Bool] {
        parameterWritable
    }

    func startLiveView() throws {
        guard connected else { throw CameraError.noCamera }
        if sonyOfficialSDK.isConnected {
            _ = try sonyOfficialSDK.liveViewImage()
            liveView = true
            logger.info("sony-sdk", "已启动官方 SDK 实时取景")
            return
        }
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
        if sonyOfficialSDK.isConnected { return }
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

    @discardableResult
    private func waitUntilDeviceReady(
        timeout: TimeInterval = 4
    ) throws -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        var attempt = 0
        while Date() < deadline {
            attempt += 1
            do {
                let output = try execute(
                    ["--get-config", "shutterspeed"],
                    timeout: 5,
                    guardUSBClaim: false
                )
                if output.status == 0, !isBusyFailure(output.output) {
                    if attempt > 1 {
                        logger.info(
                            "camera",
                            "相机已就绪；就绪探测第 \(attempt) 次成功"
                        )
                    }
                    return true
                }
            } catch {
                // The camera may reject PTP commands while it is still busy.
            }
            Thread.sleep(forTimeInterval: 0.15)
        }
        logger.warning(
            "camera",
            "相机就绪等待超时（\(timeout) 秒），继续执行操作"
        )
        return false
    }

    private func performWithoutLiveView<T>(
        _ operation: () throws -> T
    ) throws -> T {
        let shouldResume = liveView
        if shouldResume {
            stopLiveViewProcess()
            Thread.sleep(forTimeInterval: 0.2)
            try waitUntilDeviceReady()
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
        if sonyOfficialSDK.isConnected {
            return try sonyOfficialSDK.liveViewImage()
        }
        return try readPreviewFrame()
    }

    func capture(bulbSeconds: Int? = nil) throws -> Data {
        if sonyOfficialSDK.isConnected {
            return try sonyOfficialSDK.capture()
        }
        return try performWithoutLiveView {
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
        if sonyOfficialSDK.isConnected {
            try sonyOfficialSDK.setMovieRecording(true)
            movieRecording = true
            logger.info("sony-sdk", "已通过官方 SDK 开始视频录制")
            return
        }
        try performWithoutLiveView {
            _ = try run(["--set-config", "movie=1"])
            movieRecording = true
        }
        logger.info("recording", "已开始向 \(cameraName) 存储卡录制视频")
    }

    func stopMovieRecording() throws {
        guard connected else { throw CameraError.noCamera }
        guard movieRecording else { return }
        if sonyOfficialSDK.isConnected {
            try sonyOfficialSDK.setMovieRecording(false)
            movieRecording = false
            logger.info("sony-sdk", "已通过官方 SDK 停止视频录制")
            return
        }
        try performWithoutLiveView {
            _ = try run(["--set-config", "movie=0"])
            movieRecording = false
        }
        logger.info("recording", "已停止 \(cameraName) 视频录制")
    }

    func setParameter(name: String, value: Any) throws {
        if sonyOfficialSDK.isConnected {
            try sonyOfficialSDK.setParameter(name: name, value: value)
            return
        }
        try performWithoutLiveView {
            try setParameterWithoutLiveView(name: name, value: value)
        }
    }

    /// gphoto2 exposes Nikon's manual-focus PTP operation as a signed range.
    /// libgphoto2 maps the signed magnitude to Nikon's direction and amount;
    /// Error (-110) means the camera is still handling an earlier operation.
    private func manualFocusDriveValue(for signedStep: Int) -> String {
        let normalized = max(-3, min(3, signedStep))
        let amount: Int
        switch abs(normalized) {
        case 1: amount = 128
        case 2: amount = 512
        default: amount = 1024
        }
        return String(normalized < 0 ? -amount : amount)
    }

    private func performManualFocusDrive(_ signedStep: Int) throws {
        let normalized = max(-3, min(3, signedStep))
        guard normalized != 0 else { return }

        // The persistent --capture-movie process is stopped by
        // performWithoutLiveView. Re-enable the camera viewfinder in its own
        // transaction before issuing the focus-drive operation so the Nikon
        // PTP endpoint has time to leave the live-view transition state.
        _ = try run(["--set-config", "viewfinder=1"])
        try waitUntilDeviceReady(timeout: 4)
        _ = try run([
            "--set-config",
            "manualfocusdrive=\(manualFocusDriveValue(for: normalized))"
        ])
    }

    func focus(signedStep: Int) throws {
        guard connected else { throw CameraError.noCamera }
        guard liveView else {
            throw CameraError.command("焦点步进仅能在实时取景开启时使用。")
        }
        let normalized = max(-3, min(3, signedStep))
        if sonyOfficialSDK.isConnected {
            throw CameraError.command(
                "Sony Camera Remote SDK 当前未开放本机型的相对焦点步进。"
            )
        }
        try performWithoutLiveView {
            // Keep the AF-mode write and manual drive in one exclusive camera
            // session. This avoids stopping and restarting live view between
            // the two commands when a user taps the monitor.
            try setParameterWithoutLiveView(
                name: "focusMode",
                value: "single-shot"
            )
            try performManualFocusDrive(normalized)
        }
    }

    func moveFocus(_ signedStep: Int) throws {
        guard connected else { throw CameraError.noCamera }
        guard liveView else {
            throw CameraError.command("焦点步进仅能在实时取景开启时使用。")
        }
        let normalized = max(-3, min(3, signedStep))
        guard normalized != 0 else { return }
        if sonyOfficialSDK.isConnected {
            throw CameraError.command(
                "Sony Camera Remote SDK 当前未开放本机型的相对焦点步进。"
            )
        }
        try performWithoutLiveView {
            try performManualFocusDrive(normalized)
        }
    }

    func triggerAutoFocus() throws {
        guard connected else { throw CameraError.noCamera }
        if sonyOfficialSDK.isConnected {
            try sonyOfficialSDK.triggerAutofocus()
            return
        }
        try performWithoutLiveView {
            try setParameterWithoutLiveView(name: "focusMode", value: "single-shot")
            _ = try run(["--set-config", "autofocus=1"])
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
        case "videoCodec":
            let codec = String(describing: value)
            if profile?.vendorName == "Sony" {
                let sonyRaw = [
                    "sonyXavcHs8k": "10",
                    "sonyXavcHs4k": "11",
                    "sonyXavcS4k": "8",
                    "sonyXavcSHd": "9",
                    "sonyXavcSi4k": "14",
                    "sonyXavcSiHd": "15"
                ][codec]
                let sonyLabels = [
                    "sonyXavcHs8k": ["XAVC HS 8K"],
                    "sonyXavcHs4k": ["XAVC HS 4K"],
                    "sonyXavcS4k": ["XAVC S 4K"],
                    "sonyXavcSHd": ["XAVC S HD"],
                    "sonyXavcSi4k": ["XAVC S-I 4K"],
                    "sonyXavcSiHd": ["XAVC S-I HD"]
                ][codec] ?? []
                guard let sonyRaw else {
                    throw CameraError.command("Sony 不支持所选视频录制规格。")
                }
                try setFirstConfigValue(
                    name: name,
                    fallbackKeys: ["fileformatmovie", "moviefileformat", "d241"],
                    values: [sonyRaw] + sonyLabels,
                    unsupportedMessage: "\(cameraName) 当前固件不支持所选 XAVC 规格的远程切换。"
                )
                return
            }
            if profile?.vendorName == "Canon" {
                throw CameraError.command(
                    "\(cameraName) 未报告可写的佳能录制格式属性；" +
                    "规格已展示，请在机身中选择 RAW、XF-HEVC S 或 XF-AVC S。"
                )
            }
            let raw = [
                "h264": "0",
                "h265": "2",
                "proRes422HQ": "4",
                "proResRAW": "5",
                "nRaw": "3"
            ][codec] ?? "0"
            let labels = [
                "h264": ["H.264", "H264", "MP4"],
                "h265": ["H.265", "HEVC"],
                "proRes422HQ": ["ProRes 422 HQ", "Apple ProRes 422 HQ"],
                "proResRAW": ["ProRes RAW HQ", "Apple ProRes RAW HQ"],
                "nRaw": ["N-RAW", "NEV"]
            ][codec] ?? []
            try setFirstConfigValue(
                name: name,
                fallbackKeys: ["moviefiletype", "movfiletype", "d0af"],
                values: labels + [raw],
                unsupportedMessage: "\(cameraName) 当前固件不支持所选视频编码的远程切换。"
            )
            return
        case "videoLog", "nLog":
            let logProfile = name == "nLog"
                ? (((value as? Bool) ?? (String(describing: value) == "true"))
                    ? "nlog" : "off")
                : String(describing: value)
            if profile?.vendorName == "Sony" {
                let raw = [
                    "off": "0",
                    "sonySLog2": "7",
                    "sonySLog3Cine": "8",
                    "sonySLog3": "9",
                    "sonyHlg": "10"
                ][logProfile]
                guard let raw else {
                    throw CameraError.command("Sony 不支持所选 Log / Picture Profile。")
                }
                try setFirstConfigValue(
                    name: "videoLog",
                    fallbackKeys: ["pictureprofile", "d23f"],
                    values: [raw],
                    unsupportedMessage: "\(cameraName) 当前模式不支持所选 Picture Profile。"
                )
                return
            }
            if profile?.vendorName == "Canon" {
                let raw = [
                    "off": "0",
                    "canonLog": "1",
                    "canonLog2": "2",
                    "canonLog3": "3"
                ][logProfile]
                guard let raw else {
                    throw CameraError.command("Canon 不支持所选 Canon Log 曲线。")
                }
                try setFirstConfigValue(
                    name: "videoLog",
                    fallbackKeys: ["canonloggamma", "eos_canonloggamma", "d176"],
                    values: [raw],
                    unsupportedMessage: "\(cameraName) 当前固件未开放 Canon Log 远程切换。"
                )
                return
            }
            let enabled = logProfile != "off"
            try setNikonNLog(enabled)
            return
        default:
            throw CameraError.command("\(cameraName) 不支持此参数：\(name)")
        }
        _ = try run(["--set-config", "\(key)=\(formatted)"])
        if name == "exposureMode" {
            refreshParameterCapabilities()
        }
    }

    private func setNikonNLog(_ enabled: Bool) throws {
        guard FileManager.default.isExecutableFile(
            atPath: nikonPTPControlExecutable.path
        ) else {
            throw CameraError.command("Nikon N-Log 控制组件未安装。")
        }
        releaseSystemPTPCamera()
        let process = Process()
        let output = Pipe()
        process.executableURL = nikonPTPControlExecutable
        process.arguments = ["set-nlog", enabled ? "on" : "off"]
        process.standardOutput = output
        process.standardError = output
        process.environment = processEnvironment
        try process.run()
        process.waitUntilExit()
        let message = String(
            data: output.fileHandleForReading.readDataToEndOfFile(),
            encoding: .utf8
        )?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard process.terminationStatus == 0 else {
            throw CameraError.command(
                message.isEmpty
                    ? "\(cameraName) 拒绝了 N-Log 设置。"
                    : message
            )
        }
        logger.info(
            "settings",
            "Nikon ToneMode 设置成功；N-Log=\(enabled)；\(message)"
        )
    }

    private func setFirstConfigValue(
        name: String,
        fallbackKeys: [String],
        values: [String],
        unsupportedMessage: String
    ) throws {
        let keys = parameterConfigKeys[name].flatMap { $0.isEmpty ? nil : $0 }
            ?? fallbackKeys
        var finalError: Error?
        for key in keys {
            for value in values {
                do {
                    _ = try run(["--set-config", "\(key)=\(value)"])
                    return
                } catch {
                    finalError = error
                }
            }
        }
        throw CameraError.command(
            unsupportedMessage
                + (finalError.map { "（\($0.localizedDescription)）" } ?? "")
        )
    }

    func disconnect() {
        logger.info("camera", "正在断开相机")
        if movieRecording {
            try? stopMovieRecording()
        }
        stopLiveView()
        if sonyOfficialSDK.isConnected {
            sonyOfficialSDK.disconnect()
        }
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
        ["mov", "mp4", "m4v", "avi"].contains(
            url.pathExtension.lowercased()
        )
    }
}

private enum AppSection: String, CaseIterable, Identifiable {
    case capture = "拍照"
    case monitor = "视频"
    case editor = "编辑"
    case devices = "我的设备"
    case library = "分支"

    var id: String { rawValue }
    var icon: String {
        switch self {
        case .capture: return "camera.aperture"
        case .monitor: return "movieclapper.fill"
        case .editor: return "slider.horizontal.3"
        case .library: return "photo.on.rectangle.angled"
        case .devices: return "camera.badge.clock.fill"
        }
    }
}

private struct RememberedCameraDevice: Codable, Identifiable, Equatable {
    let id: String
    let name: String
    let vendor: String
    let transport: String
    let lastConnectedAt: Date

    var imageResourceName: String {
        let normalized = "\(vendor) \(name)".lowercased()
        if normalized.contains("sony") { return "camera-sony" }
        if normalized.contains("canon") { return "camera-canon" }
        return "camera-nikon"
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

private enum MonitorVideoCodec: String, CaseIterable, Identifiable {
    case h264
    case h265
    case proRes422HQ
    case proResRAW
    case nRaw
    case sonyXavcHs8k
    case sonyXavcHs4k
    case sonyXavcS4k
    case sonyXavcSHd
    case sonyXavcSi4k
    case sonyXavcSiHd
    case canonRaw
    case canonXfHevc422
    case canonXfHevc420
    case canonXfAvc422
    case canonXfAvc420

    var id: String { rawValue }

    var label: String {
        switch self {
        case .h264: return "H.264 / AVC · 8-bit"
        case .h265: return "H.265 / HEVC · 10-bit"
        case .proRes422HQ: return "Apple ProRes 422 HQ · 10-bit"
        case .proResRAW: return "Apple ProRes RAW HQ · 12-bit"
        case .nRaw: return "N-RAW · 12-bit NEV"
        case .sonyXavcHs8k: return "XAVC HS 8K · HEVC Long GOP"
        case .sonyXavcHs4k: return "XAVC HS 4K · HEVC Long GOP"
        case .sonyXavcS4k: return "XAVC S 4K · AVC Long GOP"
        case .sonyXavcSHd: return "XAVC S HD · AVC Long GOP"
        case .sonyXavcSi4k: return "XAVC S-I 4K · AVC Intra"
        case .sonyXavcSiHd: return "XAVC S-I HD · AVC Intra"
        case .canonRaw: return "RAW · 12-bit"
        case .canonXfHevc422: return "XF-HEVC S · 4:2:2 10-bit"
        case .canonXfHevc420: return "XF-HEVC S · 4:2:0 10-bit"
        case .canonXfAvc422: return "XF-AVC S · 4:2:2 10-bit"
        case .canonXfAvc420: return "XF-AVC S · 4:2:0 8-bit"
        }
    }

    var vendorName: String {
        switch self {
        case .sonyXavcHs8k, .sonyXavcHs4k, .sonyXavcS4k,
             .sonyXavcSHd, .sonyXavcSi4k, .sonyXavcSiHd:
            return "Sony"
        case .canonRaw, .canonXfHevc422, .canonXfHevc420,
             .canonXfAvc422, .canonXfAvc420:
            return "Canon"
        default:
            return "Nikon"
        }
    }

    var shortLabel: String {
        switch self {
        case .h264: return "H.264"
        case .h265: return "H.265"
        case .proRes422HQ: return "ProRes 422 HQ"
        case .proResRAW: return "ProRes RAW"
        case .nRaw: return "N-RAW"
        case .sonyXavcHs8k: return "XAVC HS 8K"
        case .sonyXavcHs4k: return "XAVC HS 4K"
        case .sonyXavcS4k: return "XAVC S 4K"
        case .sonyXavcSHd: return "XAVC S HD"
        case .sonyXavcSi4k: return "XAVC S-I 4K"
        case .sonyXavcSiHd: return "XAVC S-I HD"
        case .canonRaw: return "RAW"
        case .canonXfHevc422, .canonXfHevc420: return "XF-HEVC S"
        case .canonXfAvc422, .canonXfAvc420: return "XF-AVC S"
        }
    }
}

private enum MonitorVideoLog: String, CaseIterable, Identifiable {
    case off
    case nlog
    case sonySLog2
    case sonySLog3Cine
    case sonySLog3
    case sonyHlg
    case canonLog
    case canonLog2
    case canonLog3

    var id: String { rawValue }

    var vendorName: String {
        switch self {
        case .sonySLog2, .sonySLog3Cine, .sonySLog3, .sonyHlg: return "Sony"
        case .canonLog, .canonLog2, .canonLog3: return "Canon"
        case .nlog: return "Nikon"
        case .off: return ""
        }
    }

    var label: String {
        switch self {
        case .off: return "关闭 · SDR"
        case .nlog: return "N-Log"
        case .sonySLog2: return "PP7 · S-Log2"
        case .sonySLog3Cine: return "PP8 · S-Log3 / S-Gamut3.Cine"
        case .sonySLog3: return "PP9 · S-Log3 / S-Gamut3"
        case .sonyHlg: return "PP10 · HLG"
        case .canonLog: return "Canon Log"
        case .canonLog2: return "Canon Log 2"
        case .canonLog3: return "Canon Log 3"
        }
    }

    var shortLabel: String {
        switch self {
        case .off: return "SDR"
        case .sonySLog3Cine, .sonySLog3: return "S-Log3"
        default: return label.components(separatedBy: " · ").last ?? label
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
    @Published var localCameraConnected = false
    @Published var connecting = false
    @Published var liveViewEnabled = false
    @Published var capturing = false
    @Published var videoRecording = false
    @Published var videoRecordingStartedAt: Date?
    @Published var externalRecordToDevice = true
    private var previewAnalysisSequence = 0
    @Published var frame: NSImage?
    @Published var photoFrame: NSImage?
    @Published var status = "未连接"
    @Published var detail = "USB/PTP · 等待连接"
    @Published var cameraName: String?
    @Published var cameraVendor = "Nikon"
    @Published var rememberedDevices: [RememberedCameraDevice] = []
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
    @Published var monitorVideoCodec: MonitorVideoCodec = .h265
    @Published var monitorVideoLog: MonitorVideoLog = .off
    @Published var monitorNikonCloudPresetID: String?
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
    private let externalVideoRecorder = ExternalVideoRecorder()
    let localCamera = LocalCameraService()
    let wifiCamera = WifiCameraService()
    let bluetoothRemote = BluetoothRemoteService()
    let locationTagging = LocationTaggingService()
    let nikonOfficialSDK = NikonOfficialSDKService()
    let sonyOfficialSDK = SonyOfficialSDKService.shared
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
    private var connectivityObservers = Set<AnyCancellable>()
    private let photoDirectory: URL
    lazy var captureWorkflow = CaptureWorkflow(rootDirectory: photoDirectory)
    lazy var wirelessTransfer = WirelessTransferServer(
        directory: photoDirectory
    ) { [weak self] _ in
        self?.reloadPhotos()
        self?.selectedPhoto = self?.photos.first
    }

    var activeCameraName: String {
        if localCameraConnected { return localCamera.deviceName }
        return cameraName ?? "相机"
    }

    var hasAnyCameraConnection: Bool {
        connected || localCameraConnected || wifiCamera.isConnected
    }

    var captureReady: Bool {
        hasAnyCameraConnection && !capturing
    }

    func listCameraStorage() async throws -> CameraStorageSnapshot {
        if connected {
            return try await withCheckedThrowingContinuation { continuation in
                cameraQueue.async { [weak self] in
                    guard let self else {
                        continuation.resume(throwing: CameraError.noCamera)
                        return
                    }
                    do {
                        continuation.resume(returning: try self.camera.listStorage())
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
        if wifiCamera.isConnected {
            return try await wifiCamera.listStorage()
        }
        throw CameraError.command(
            localCameraConnected
                ? "系统摄像头不提供机内存储访问；请连接 USB/PTP 或 Wi‑Fi/PTP‑IP 相机。"
                : "请先连接支持 USB/PTP 或 Wi‑Fi/PTP‑IP 的相机。"
        )
    }

    func cameraStorageThumbnail(handle: UInt32) async throws -> Data {
        if connected {
            return try await withCheckedThrowingContinuation { continuation in
                cameraQueue.async { [weak self] in
                    guard let self else {
                        continuation.resume(throwing: CameraError.noCamera)
                        return
                    }
                    do {
                        continuation.resume(
                            returning: try self.camera.storageThumbnail(handle: handle)
                        )
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
        return try await wifiCamera.storageThumbnail(handle: handle)
    }

    func cameraStorageObject(handle: UInt32) async throws -> Data {
        if connected {
            return try await withCheckedThrowingContinuation { continuation in
                cameraQueue.async { [weak self] in
                    guard let self else {
                        continuation.resume(throwing: CameraError.noCamera)
                        return
                    }
                    do {
                        continuation.resume(
                            returning: try self.camera.storageObject(handle: handle)
                        )
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
        return try await wifiCamera.storageObject(handle: handle)
    }

    func deleteCameraStorageObject(handle: UInt32) async throws {
        if connected {
            return try await withCheckedThrowingContinuation { continuation in
                cameraQueue.async { [weak self] in
                    guard let self else {
                        continuation.resume(throwing: CameraError.noCamera)
                        return
                    }
                    do {
                        try self.camera.deleteStorageObject(handle: handle)
                        continuation.resume(returning: ())
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
        try await wifiCamera.deleteStorageObject(handle: handle)
    }

    @discardableResult
    func storeCameraStorageObject(
        _ data: Data,
        filename: String
    ) throws -> URL {
        let destination = try captureWorkflow.store(
            data: data,
            originalFilename: filename,
            cameraName: activeCameraName
        )
        reloadPhotos()
        selectedPhoto = photos.first { $0.url == destination }
        return destination
    }

    var connectionTitle: String {
        if connected { return status }
        if localCameraConnected { return localCamera.deviceName }
        if wifiCamera.isConnected { return wifiCamera.cameraName }
        return status
    }

    var connectionDetail: String {
        if connected { return detail }
        if localCameraConnected {
            return liveViewEnabled
                ? "本机摄像头 · 实时取景中"
                : "本机摄像头 · 可取景与拍照"
        }
        if wifiCamera.isConnected { return "Wi‑Fi/PTP‑IP 已连接 · 机身快门可用" }
        return wifiCamera.state == .connecting
            ? wifiCamera.status
            : detail
    }

    var availableVideoCodecs: [MonitorVideoCodec] {
        MonitorVideoCodec.allCases.filter { $0.vendorName == cameraVendor }
    }

    var availableVideoLogs: [MonitorVideoLog] {
        MonitorVideoLog.allCases.filter {
            $0 == .off || $0.vendorName == cameraVendor
        }
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
        if let savedCodec = UserDefaults.standard.string(
            forKey: "monitorVideoCodec"
        ), let codec = MonitorVideoCodec(rawValue: savedCodec) {
            monitorVideoCodec = codec
        }
        if let savedLog = UserDefaults.standard.string(
            forKey: "monitorVideoLog"
        ), let log = MonitorVideoLog(rawValue: savedLog) {
            monitorVideoLog = log
        } else if UserDefaults.standard.bool(forKey: "monitorNLogEnabled") {
            monitorVideoLog = .nlog
        }
        externalRecordToDevice = UserDefaults.standard.object(
            forKey: "externalRecordToDevice"
        ) == nil || UserDefaults.standard.bool(forKey: "externalRecordToDevice")
        let savedFrameRate = UserDefaults.standard.double(forKey: "videoFrameRate")
        if savedFrameRate > 0 {
            videoFrameRate = savedFrameRate
        }
        let savedShutterAngle = UserDefaults.standard.double(forKey: "videoShutterAngle")
        if savedShutterAngle > 0 {
            videoShutterAngle = savedShutterAngle
        }
        shutter = videoShutterAngle / (360 * videoFrameRate)
        wifiCamera.objectWillChange
            .sink { [weak self] in self?.objectWillChange.send() }
            .store(in: &connectivityObservers)
        localCamera.objectWillChange
            .sink { [weak self] in self?.objectWillChange.send() }
            .store(in: &connectivityObservers)
        localCamera.onMessage = { [weak self] message in
            self?.logger.info("local-camera", message)
            self?.detail = message
        }
        localCamera.onFrame = { [weak self] image in
            guard let self, self.localCameraConnected, self.liveViewEnabled else {
                return
            }
            self.photoFrame = image
            self.enqueuePreviewProcessing(image, token: self.previewToken)
        }
        localCamera.onJpegFrame = { [weak self] data in
            self?.appendExternalFrame(data)
        }
        bluetoothRemote.objectWillChange
            .sink { [weak self] in self?.objectWillChange.send() }
            .store(in: &connectivityObservers)
        locationTagging.objectWillChange
            .sink { [weak self] in self?.objectWillChange.send() }
            .store(in: &connectivityObservers)
        nikonOfficialSDK.objectWillChange
            .sink { [weak self] in self?.objectWillChange.send() }
            .store(in: &connectivityObservers)
        sonyOfficialSDK.objectWillChange
            .sink { [weak self] in self?.objectWillChange.send() }
            .store(in: &connectivityObservers)
        bluetoothRemote.onShutter = { [weak self] in
            self?.capture()
        }
        loadRememberedDevices()
        reloadPhotos()
    }

    func connect() {
        guard !connecting else { return }
        if localCameraConnected { disconnectLocalCamera() }
        logger.info("workflow", "用户请求连接相机")
        connecting = true
        status = "正在连接"
        detail = "正在检测 USB/PTP 相机…"
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
                    self.cameraVendor = profile.vendorName
                    self.rememberConnectedDevice(profile)
                    if !self.availableVideoCodecs.contains(self.monitorVideoCodec) {
                        self.monitorVideoCodec = self.availableVideoCodecs.first ?? .h265
                    }
                    if !self.availableVideoLogs.contains(self.monitorVideoLog) {
                        self.monitorVideoLog = .off
                    }
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

    func connectLocalCamera() {
        guard !connecting, !localCameraConnected else { return }
        if connected { disconnect() }
        if wifiCamera.isConnected { wifiCamera.disconnect() }
        connecting = true
        status = "正在连接"
        detail = "正在申请本机摄像头…"
        localCamera.connect { [weak self] result in
            guard let self else { return }
            self.connecting = false
            switch result {
            case .success(let name):
                self.localCameraConnected = true
                self.liveViewEnabled = false
                self.cameraName = name
                self.cameraVendor = "System"
                self.status = name
                self.detail = "本机摄像头 · 可取景与拍照"
                self.rememberLocalCamera(name)
            case .failure(let error):
                self.localCameraConnected = false
                self.status = "未连接"
                self.detail = "本机摄像头连接失败"
                self.errorMessage = error.localizedDescription
            }
        }
    }

    func disconnectLocalCamera() {
        finishExternalRecordingForDisconnect()
        previewToken = UUID()
        clearPendingPreviewProcessing()
        localCamera.stopLiveView()
        localCamera.disconnect()
        localCameraConnected = false
        liveViewEnabled = false
        frame = nil
        photoFrame = nil
        cameraName = nil
        cameraVendor = "Nikon"
        status = "未连接"
        detail = "USB/PTP · 等待连接"
    }

    func disconnect() {
        finishExternalRecordingForDisconnect()
        logger.info("workflow", "用户请求断开相机")
        previewToken = UUID()
        clearPendingPreviewProcessing()
        liveViewEnabled = false
        videoRecording = false
        videoRecordingStartedAt = nil
        cameraQueue.async { [weak self] in
            self?.camera.disconnect()
        }
        connected = false
        frame = nil
        photoFrame = nil
        cameraName = nil
        cameraVendor = "Nikon"
        parameterWritable = [:]
        status = "未连接"
        detail = "USB/PTP · 等待连接"
    }

    func reconnectRememberedDevice(_ device: RememberedCameraDevice) {
        if device.transport == "本机摄像头" {
            connectLocalCamera()
            return
        }
        if connected { disconnect() }
        connect()
    }

    func forgetRememberedDevice(_ device: RememberedCameraDevice) {
        rememberedDevices.removeAll { $0.id == device.id }
        persistRememberedDevices()
    }

    private func rememberConnectedDevice(_ profile: SupportedCamera) {
        let id = String(
            format: "%04x:%04x:%@",
            profile.vendorID,
            profile.productID,
            profile.name
        )
        let record = RememberedCameraDevice(
            id: id,
            name: profile.name,
            vendor: profile.vendorName,
            transport: "USB/PTP",
            lastConnectedAt: Date()
        )
        rememberedDevices.removeAll { $0.id == id }
        rememberedDevices.insert(record, at: 0)
        if rememberedDevices.count > 12 {
            rememberedDevices.removeLast(rememberedDevices.count - 12)
        }
        persistRememberedDevices()
    }

    private func rememberLocalCamera(_ name: String) {
        let record = RememberedCameraDevice(
            id: "macos-local-camera",
            name: name,
            vendor: "System",
            transport: "本机摄像头",
            lastConnectedAt: Date()
        )
        rememberedDevices.removeAll { $0.id == record.id }
        rememberedDevices.insert(record, at: 0)
        if rememberedDevices.count > 12 {
            rememberedDevices.removeLast(rememberedDevices.count - 12)
        }
        persistRememberedDevices()
    }

    private func loadRememberedDevices() {
        guard let data = UserDefaults.standard.data(
            forKey: "rememberedCameraDevices.v1"
        ), let decoded = try? JSONDecoder().decode(
            [RememberedCameraDevice].self,
            from: data
        ) else {
            return
        }
        rememberedDevices = decoded.sorted {
            $0.lastConnectedAt > $1.lastConnectedAt
        }
    }

    private func persistRememberedDevices() {
        guard let data = try? JSONEncoder().encode(rememberedDevices) else {
            return
        }
        UserDefaults.standard.set(data, forKey: "rememberedCameraDevices.v1")
    }

    func toggleLiveView() {
        if localCameraConnected {
            if liveViewEnabled {
                previewToken = UUID()
                clearPendingPreviewProcessing()
                localCamera.stopLiveView()
                liveViewEnabled = false
                detail = "本机摄像头 · 取景已停止"
            } else {
                previewToken = UUID()
                localCamera.startLiveView { [weak self] result in
                    guard let self else { return }
                    switch result {
                    case .success:
                        self.liveViewEnabled = true
                        self.detail = "本机摄像头 · 实时取景中"
                    case .failure(let error):
                        self.errorMessage = error.localizedDescription
                    }
                }
            }
            return
        }
        guard connected else {
            errorMessage = "请先连接支持的相机。"
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
                self.appendExternalFrame(data)
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
                    self.finishExternalRecordingForDisconnect()
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
        if localCameraConnected {
            guard !capturing else { return }
            capturing = true
            detail = "正在使用本机摄像头拍摄…"
            if locationTagging.enabled { locationTagging.refresh() }
            let captureLocation = locationTagging.snapshot()
            localCamera.capture { [weak self] result in
                guard let self else { return }
                switch result {
                case .success(let data):
                    do {
                        let formatter = DateFormatter()
                        formatter.dateFormat = "yyyyMMdd_HHmmss"
                        let filename = "ZENCHE_LOCAL_\(formatter.string(from: Date())).JPG"
                        let url = try self.captureWorkflow.store(
                            data: data,
                            originalFilename: filename,
                            cameraName: self.localCamera.deviceName,
                            location: captureLocation
                        )
                        let image = NSImage(data: data)
                        self.capturing = false
                        self.detail = "本机拍摄已保存 · \(url.lastPathComponent)"
                        self.photoFrame = image
                        self.reloadPhotos()
                        self.selectedPhoto = self.photos.first
                        if let image {
                            let output = self.processedPreview(from: image)
                            self.frame = output.image
                            self.zebraMask = output.zebraMask
                        }
                        if !self.liveViewEnabled { self.localCamera.stopLiveView() }
                    } catch {
                        self.capturing = false
                        self.errorMessage = error.localizedDescription
                    }
                case .failure(let error):
                    self.capturing = false
                    self.errorMessage = error.localizedDescription
                }
            }
            return
        }
        if !connected, wifiCamera.isConnected {
            guard !capturing else { return }
            capturing = true
            detail = "正在通过 Wi‑Fi 触发快门…"
            wifiCamera.onShutterTriggered = { [weak self] in
                self?.capturing = false
                self?.status = self?.wifiCamera.cameraName ?? "Wi‑Fi 相机"
                self?.detail = "Wi‑Fi 快门已触发 · 原片保存在相机卡内"
            }
            wifiCamera.capture()
            DispatchQueue.main.asyncAfter(deadline: .now() + 12) { [weak self] in
                guard let self, self.capturing, !self.connected else { return }
                self.capturing = false
                if !self.wifiCamera.isConnected {
                    self.errorMessage = self.wifiCamera.status
                }
            }
            return
        }
        guard connected else {
            errorMessage = "请先连接支持的相机。"
            return
        }
        guard !capturing else { return }
        logger.info("workflow", "用户请求拍摄")
        capturing = true
        detail = "正在触发 \(activeCameraName) 快门…"
        if locationTagging.enabled {
            locationTagging.refresh()
        }
        let captureLocation = locationTagging.snapshot()
        cameraQueue.async { [weak self] in
            guard let self else { return }
            do {
                let duration = self.exposureMode == "bulb" ? self.bulbSeconds : nil
                let data = try self.camera.capture(bulbSeconds: duration)
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyyMMdd_HHmmss"
                let filename = "ZENCHE_\(formatter.string(from: Date())).JPG"
                let url = try self.captureWorkflow.store(
                    data: data,
                    originalFilename: filename,
                    cameraName: self.activeCameraName,
                    location: captureLocation
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
            errorMessage = "请先连接支持的相机。"
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
        if locationTagging.enabled {
            locationTagging.refresh()
        }
        let taskLocation = locationTagging.snapshot()
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
                        cameraName: self.activeCameraName,
                        location: taskLocation
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
        guard connected || localCameraConnected else {
            errorMessage = "请先连接支持的相机或视频设备。"
            return
        }
        if localCameraConnected && !externalRecordToDevice {
            errorMessage = "本机摄像头视频需要开启“外录到当前智能设备”。"
            return
        }
        guard !capturing else { return }
        if !videoRecording, externalRecordToDevice, !liveViewEnabled {
            capturing = true
            detail = "正在开启实时取景以准备外录…"
            if localCameraConnected {
                localCamera.startLiveView { [weak self] result in
                    guard let self else { return }
                    self.capturing = false
                    switch result {
                    case .success:
                        self.liveViewEnabled = true
                        self.previewToken = UUID()
                        self.toggleMovieRecording()
                    case .failure(let error):
                        self.detail = "无法开始外录"
                        self.errorMessage = error.localizedDescription
                    }
                }
            } else {
                cameraQueue.async { [weak self] in
                    guard let self else { return }
                    do {
                        try self.camera.startLiveView()
                        DispatchQueue.main.async {
                            self.capturing = false
                            self.liveViewEnabled = true
                            self.startPreviewLoop()
                            self.toggleMovieRecording()
                        }
                    } catch {
                        DispatchQueue.main.async {
                            self.capturing = false
                            self.detail = "无法开始外录"
                            self.errorMessage = error.localizedDescription
                        }
                    }
                }
            }
            return
        }
        let shouldStop = videoRecording
        capturing = true
        detail = shouldStop ? "正在停止视频录制…" : "正在开始视频录制…"
        cameraQueue.async { [weak self] in
            guard let self else { return }
            do {
                if shouldStop {
                    var bodyError: Error?
                    if self.connected {
                        do {
                            try self.camera.stopMovieRecording()
                        } catch {
                            bodyError = error
                        }
                    }
                    if let result = try self.externalVideoRecorder
                        .stopIfRecording() {
                        try self.captureWorkflow.completeExternalRecording(
                            at: result.url
                        )
                        self.logger.info(
                            "external-recording",
                            "外录完成；文件=\(result.url.lastPathComponent)；" +
                                "帧数=\(result.frames)；大小=\(result.bytes)"
                        )
                    }
                    if let bodyError { throw bodyError }
                } else {
                    if self.externalRecordToDevice {
                        let target = try self.captureWorkflow
                            .reserveExternalRecording(
                                cameraName: self.activeCameraName
                            )
                        try self.externalVideoRecorder.start(
                            at: target,
                            frameRate: self.videoFrameRate
                        )
                    }
                    var bodyError: Error?
                    if self.connected {
                        do {
                            try self.camera.startMovieRecording()
                        } catch {
                            bodyError = error
                        }
                    }
                    if let bodyError,
                       !self.externalVideoRecorder.isRecording {
                        throw bodyError
                    }
                }
                DispatchQueue.main.async {
                    self.capturing = false
                    self.videoRecording = self.externalVideoRecorder.isRecording
                        || (self.connected && self.camera.isMovieRecording)
                    self.videoRecordingStartedAt = self.videoRecording ? Date() : nil
                    self.detail = self.videoRecording
                        ? self.externalVideoRecorder.isRecording
                            ? "● EXT REC · 正在外录到当前智能设备"
                            : "● REC · 正在录制到相机存储卡"
                        : "录制已停止 · 外录文件已保存到 ZENCHE 文件库"
                    if !self.videoRecording {
                        self.reloadPhotos()
                        self.selectedPhoto = self.photos.first
                    }
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

    func setExternalRecordToDevice(_ enabled: Bool) {
        guard !videoRecording else { return }
        externalRecordToDevice = enabled
        UserDefaults.standard.set(enabled, forKey: "externalRecordToDevice")
        detail = enabled
            ? "外录已开启 · 视频将写入 ZENCHE 文件库"
            : "外录已关闭 · PTP 相机仅记录到机身存储卡"
    }

    private func appendExternalFrame(_ data: Data) {
        guard externalVideoRecorder.isRecording else { return }
        do {
            try externalVideoRecorder.append(jpeg: data)
        } catch {
            logger.error(
                "external-recording",
                "外录写入失败：\(error.localizedDescription)"
            )
            do {
                if let result = try externalVideoRecorder.stopIfRecording() {
                    try captureWorkflow.completeExternalRecording(at: result.url)
                }
            } catch {
                externalVideoRecorder.abort()
            }
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.videoRecording = self.connected && self.camera.isMovieRecording
                if !self.videoRecording { self.videoRecordingStartedAt = nil }
                self.reloadPhotos()
                self.errorMessage = "外录已停止：\(error.localizedDescription)"
            }
        }
    }

    private func finishExternalRecordingForDisconnect() {
        do {
            if let result = try externalVideoRecorder.stopIfRecording() {
                try captureWorkflow.completeExternalRecording(at: result.url)
                logger.info(
                    "external-recording",
                    "连接结束，已安全保存外录：\(result.url.lastPathComponent)"
                )
                reloadPhotos()
            }
        } catch {
            externalVideoRecorder.abort()
            logger.error(
                "external-recording",
                "连接结束时无法完成外录：\(error.localizedDescription)"
            )
        }
        videoRecording = false
        videoRecordingStartedAt = nil
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
                    "mov", "mp4", "m4v", "avi"
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

    @discardableResult
    func saveEditedPhoto(
        _ data: Data,
        originalFilename: String
    ) -> URL? {
        do {
            let destination = try captureWorkflow.store(
                data: data,
                originalFilename: "edited.jpg",
                cameraName: "Editor"
            )
            reloadPhotos()
            selectedPhoto = photos.first { $0.url == destination }
            detail = "已保存编辑副本 · \(destination.lastPathComponent)"
            logger.info(
                "editor",
                "编辑副本已保存；来源=\(originalFilename)；文件=\(destination.lastPathComponent)"
            )
            return destination
        } catch {
            logger.error(
                "editor",
                "保存编辑副本失败：\(error.localizedDescription)"
            )
            errorMessage = "保存编辑副本失败：\(error.localizedDescription)"
            return nil
        }
    }

    @discardableResult
    func replaceEditedPhoto(
        _ data: Data,
        at sourceURL: URL,
        originalFilename: String
    ) -> URL? {
        do {
            let destination = try captureWorkflow.replace(
                data: data,
                at: sourceURL,
                originalFilename: originalFilename,
                cameraName: "Editor"
            )
            reloadPhotos()
            selectedPhoto = photos.first { $0.url == destination }
            detail = "已替换原图 · \(destination.lastPathComponent)"
            logger.info(
                "editor",
                "AI 修图已原子替换原图；文件=\(destination.lastPathComponent)"
            )
            return destination
        } catch {
            logger.error(
                "editor",
                "替换原图失败：\(error.localizedDescription)"
            )
            errorMessage = "替换原图失败：\(error.localizedDescription)"
            return nil
        }
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

    func setMonitorVideoCodec(_ codec: MonitorVideoCodec) {
        monitorVideoCodec = codec
        UserDefaults.standard.set(codec.rawValue, forKey: "monitorVideoCodec")
        applyParameter("videoCodec", value: codec.rawValue, label: "视频录制规格")
    }

    func setMonitorVideoLog(_ log: MonitorVideoLog) {
        monitorVideoLog = log
        UserDefaults.standard.set(log.rawValue, forKey: "monitorVideoLog")
        UserDefaults.standard.set(log == .nlog, forKey: "monitorNLogEnabled")
        applyParameter(
            "videoLog",
            value: log.rawValue,
            label: "Log / Picture Profile"
        )
    }

    func stepMonitorVideoCodec(_ direction: Int) {
        let values = availableVideoCodecs
        let index = values.firstIndex(of: monitorVideoCodec) ?? 1
        setMonitorVideoCodec(
            values[max(0, min(values.count - 1, index + direction))]
        )
    }

    func stepMonitorVideoLog(_ direction: Int) {
        let values = availableVideoLogs
        let index = values.firstIndex(of: monitorVideoLog) ?? 0
        setMonitorVideoLog(
            values[max(0, min(values.count - 1, index + direction))]
        )
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

    func triggerAutoFocus() {
        guard connected, liveViewEnabled else {
            errorMessage = "请先开启实时取景"
            return
        }
        cameraQueue.async { [weak self] in
            guard let self else { return }
            do {
                try self.camera.triggerAutoFocus()
                DispatchQueue.main.async { self.detail = "AF-ON 已触发" }
            } catch {
                DispatchQueue.main.async { self.errorMessage = "AF-ON 失败：\(error.localizedDescription)" }
            }
        }
    }

    func stepVideoFrameRate(_ direction: Int) {
        let values = [24.0, 25.0, 30.0, 50.0, 60.0]
        let index = values.enumerated().min { abs($0.element - videoFrameRate) < abs($1.element - videoFrameRate) }?.offset ?? 2
        setVideoFrameRate(values[max(0, min(values.count - 1, index + direction))])
    }

    func stepVideoShutter(_ direction: Int) {
        let values = [45.0, 90.0, 144.0, 172.8, 180.0, 270.0, 360.0]
        let index = values.enumerated().min { abs($0.element - videoShutterAngle) < abs($1.element - videoShutterAngle) }?.offset ?? 4
        setVideoShutterAngle(values[max(0, min(values.count - 1, index + direction))])
    }

    func stepISO(_ direction: Int) {
        let values = SupportedCamera.isoOptions(for: cameraName)
        guard !values.isEmpty else { return }
        let index = values.enumerated().min { abs($0.element - iso) < abs($1.element - iso) }?.offset ?? 0
        let next = values[max(0, min(values.count - 1, index + direction))]
        iso = next
        applyParameter("iso", value: next, label: "ISO感光度")
    }

    func focus(at point: CGPoint) {
        guard connected, liveViewEnabled else { return }
        let dx = point.x - 0.5
        let dy = point.y - 0.5
        let direction = abs(dx) >= abs(dy)
            ? Int((max(-3, min(3, dx * 8))).rounded())
            : Int((max(-3, min(3, dy * 8))).rounded())
        cameraQueue.async { [weak self] in
            guard let self else { return }
            do {
                try self.camera.focus(signedStep: direction)
                DispatchQueue.main.async {
                    self.detail = direction == 0
                        ? "已触发单次自动对焦"
                        : "焦点步进已完成（当前相机不支持二维对焦点）"
                }
            } catch {
                DispatchQueue.main.async { self.errorMessage = "对焦请求失败：\(error.localizedDescription)" }
            }
        }
    }

    func monitorImageRect(container: CGSize) -> CGRect {
        guard let frame = frame, frame.size.width > 0, frame.size.height > 0 else {
            return CGRect(origin: .zero, size: container)
        }
        let scale = min(container.width / frame.size.width, container.height / frame.size.height)
        let size = CGSize(width: frame.size.width * scale, height: frame.size.height * scale)
        return CGRect(x: (container.width - size.width) / 2, y: (container.height - size.height) / 2, width: size.width, height: size.height)
    }

    func focusNormalized(at point: CGPoint, in container: CGSize) -> CGPoint? {
        let rect = monitorImageRect(container: container)
        guard rect.contains(point), rect.width > 0, rect.height > 0 else { return nil }
        return CGPoint(x: min(max((point.x - rect.minX) / rect.width, 0), 1), y: min(max((point.y - rect.minY) / rect.height, 0), 1))
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

    var monitorNikonCloudPreset: NikonCloudPreset? {
        guard let monitorNikonCloudPresetID else { return nil }
        return NikonCloudPresetLibrary.presets.first {
            $0.id == monitorNikonCloudPresetID
        }
    }

    func setMonitorNikonCloudPreset(_ preset: NikonCloudPreset?) {
        monitorNikonCloudPresetID = preset?.id
        detail = preset.map {
            "尼康云创监看 · \($0.name) · 照片/视频 · SDR 近似"
        } ?? "尼康云创监看已关闭"
        refreshPreviewProcessing()
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
            errorMessage = "连接支持的相机后才能调整参数。"
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
        previewAnalysisSequence += 1
        let analyzeFrame = videoRecording
            ? previewAnalysisSequence % 6 == 0
            : previewAnalysisSequence % 3 == 0
        let visualProcessing = lutEnabled || focusPeakingEnabled
            || falseColorEnabled || zebraEnabled
            || monitorNikonCloudPreset != nil
        guard analyzeFrame || visualProcessing else {
            let display = monitorVideoProfile.targetSize.flatMap {
                PreviewProcessor.resampledImage(image, fitting: $0)
            } ?? image
            return (display, nil)
        }
        let graded = lutEnabled
            ? previewLUT?.applying(to: image) ?? image
            : image
        let monitored = ProfessionalMonitor.process(
            graded,
            focusPeaking: focusPeakingEnabled,
            falseColor: falseColorEnabled,
            nikonCloudPreset: monitorNikonCloudPreset
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
        wifiCamera.disconnect()
        localCamera.disconnect()
        bluetoothRemote.stop()
        locationTagging.setEnabled(false)
        camera.disconnect()
    }
}

/// 亮/暗双主题的中性校准工作台色板。每个 token 都是随有效外观解析的动态色，
/// 因此切换 `NSApp.appearance` 或系统外观时全局自动更新，调用点无需改动。
/// 实时画面井（graphite）在两种模式下都保持石墨黑，以保证色彩关键判断不受环境干扰。
private enum Palette {
    private static func dynamic(
        light: (Double, Double, Double),
        dark: (Double, Double, Double)
    ) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            let rgb = isDark ? dark : light
            return NSColor(srgbRed: rgb.0, green: rgb.1, blue: rgb.2, alpha: 1)
        })
    }

    private static func dynamicWhite(
        light: (Double, Double),
        dark: (Double, Double)
    ) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            let value = isDark ? dark : light
            return NSColor(white: value.0, alpha: value.1)
        })
    }

    // 中性层：应用底 / 面板与卡片 / 凹陷面
    static let paper = dynamic(
        light: (0.914, 0.929, 0.949), dark: (0.075, 0.082, 0.098))
    static let paperSecondary = dynamic(
        light: (0.894, 0.914, 0.937), dark: (0.137, 0.153, 0.180))
    static let surface = dynamic(
        light: (0.973, 0.980, 0.988), dark: (0.106, 0.118, 0.141))
    // 文字层
    static let ink = dynamic(
        light: (0.090, 0.110, 0.149), dark: (0.925, 0.933, 0.949))
    static let muted = dynamic(
        light: (0.353, 0.380, 0.424), dark: (0.604, 0.631, 0.678))
    // 语义强调：照片=校准蓝、视频=REC 红（填充值兼顾白字对比）
    static let cobalt = dynamic(
        light: (0.086, 0.451, 0.902), dark: (0.180, 0.525, 0.878))
    static let cobaltSoft = dynamic(
        light: (0.863, 0.918, 0.992), dark: (0.078, 0.161, 0.243))
    static let video = dynamic(
        light: (0.847, 0.196, 0.227), dark: (1.0, 0.322, 0.341))
    static let videoSoft = dynamic(
        light: (0.984, 0.886, 0.890), dark: (0.227, 0.106, 0.118))
    // 校准的“正常/已连接”绿，替代系统默认 Color.green
    static let positive = dynamic(
        light: (0.121, 0.663, 0.408), dark: (0.208, 0.788, 0.482))
    // 曝光读数轨在石墨井上的发光蓝数字（两模式一致，石墨背景恒定）
    static let readoutGlow = Color(
        red: 107.0 / 255.0,
        green: 174.0 / 255.0,
        blue: 1.0
    )
    // 实时画面井：两模式恒石墨黑
    static let graphite = dynamic(
        light: (0.039, 0.043, 0.051), dark: (0.039, 0.043, 0.051))
    static let studioCanvas = Color(
        red: 6.0 / 255.0, green: 9.0 / 255.0, blue: 13.0 / 255.0)
    static let studioPanel = Color(
        red: 21.0 / 255.0, green: 25.0 / 255.0, blue: 31.0 / 255.0)
    static let studioRaised = Color(
        red: 32.0 / 255.0, green: 36.0 / 255.0, blue: 43.0 / 255.0)
    static let studioRule = Color(
        red: 52.0 / 255.0, green: 58.0 / 255.0, blue: 67.0 / 255.0)
    static let studioGold = Color(
        red: 216.0 / 255.0, green: 182.0 / 255.0, blue: 83.0 / 255.0)
    // ===== v1.5.6 token 层（对齐 Android/Harmony/iOS TypeScale·SCOPE_*）=====
    // 示波器轨迹色（五端同名同值）
    static let scopeR = Color(red: 1, green: 0.19, blue: 0.16)          // #FF302A
    static let scopeG = Color(red: 0.16, green: 1, blue: 0.41)          // #28FF69
    static let scopeB = Color(red: 0.13, green: 0.25, blue: 1)          // #2240FF
    static let scopeAudio = Color(red: 76 / 255, green: 199 / 255, blue: 232 / 255) // #4CC7E8
    static let scopeBg = Color(red: 5 / 255, green: 10 / 255, blue: 15 / 255) // #050A0F
    // 专属语义色
    static let videoIdle = Color(red: 0.55, green: 0.03, blue: 0.03)    // 录制按钮未激活深红（与 iOS 同值）
    // 尼康云创深色卡（fig1 恒深面上的深蓝面）
    static let cloudBg = Color(red: 0.094, green: 0.141, blue: 0.204)
    static let cloudStroke = Color(red: 0.188, green: 0.306, blue: 0.439)
    // 白色系（对齐 Harmony WHITE_* / iOS whiteHi 等 alpha 档）
    static let whiteHi = Color.white.opacity(0.94)
    static let whiteMid = Color.white.opacity(0.88)
    static let whiteLo = Color.white.opacity(0.75)
    static let whiteDim = Color.white.opacity(0.60)
    static let whiteFaint = Color.white.opacity(0.56)
    static let whiteGhost = Color.white.opacity(0.45)
    static let whiteMist = Color.white.opacity(0.30)
    static let whiteWash = Color.white.opacity(0.06)
    // 黑遮罩（对齐 Harmony HUD_*：0.67/0.60/0.40/0.33/0.53/0.27）
    static let hudBg = Color.black.opacity(0.67)
    static let hudBgSoft = Color.black.opacity(0.60)
    static let hudBgMid = Color.black.opacity(0.40)
    static let hudBgDim = Color.black.opacity(0.33)
    static let hudBgDark = Color.black.opacity(0.53)
    static let hudShadow = Color.black.opacity(0.27)
    // fig2 编辑器 token（五端 1.5.5 统一常量，同名同值）：深灰工作台 /
    // 面板 / 浮层面 / 1px 分隔线 / 品牌橙（仅选中工具与示波器读数）/
    // 灰标签。固定深色，不随主题变化；无渐变无投影，直角平铺。
    static let editorBg = Color(
        red: 42.0 / 255.0, green: 42.0 / 255.0, blue: 46.0 / 255.0)
    static let editorPanel = Color(
        red: 51.0 / 255.0, green: 51.0 / 255.0, blue: 56.0 / 255.0)
    static let editorRaised = Color(
        red: 58.0 / 255.0, green: 58.0 / 255.0, blue: 64.0 / 255.0)
    static let editorRule = Color(
        red: 27.0 / 255.0, green: 27.0 / 255.0, blue: 31.0 / 255.0)
    static let editorAccent = Color(
        red: 232.0 / 255.0, green: 131.0 / 255.0, blue: 58.0 / 255.0)
    static let editorLabel = Color(
        red: 142.0 / 255.0, green: 142.0 / 255.0, blue: 147.0 / 255.0)
    // fig1 控制面 token（五端 1.5.5 统一常量）：近黑底 / 卡片 / 次级面 /
    // 灰标签 / 单一点亮黄绿 / 系统蓝。固定深色，不随主题变化。
    static let uiBackground = Color(
        red: 10.0 / 255.0, green: 11.0 / 255.0, blue: 13.0 / 255.0)
    static let uiCard = Color(
        red: 28.0 / 255.0, green: 28.0 / 255.0, blue: 30.0 / 255.0)
    static let uiSecondary = Color(
        red: 44.0 / 255.0, green: 44.0 / 255.0, blue: 46.0 / 255.0)
    static let uiLabel = Color(
        red: 142.0 / 255.0, green: 142.0 / 255.0, blue: 147.0 / 255.0)
    static let uiAccent = Color(
        red: 205.0 / 255.0, green: 220.0 / 255.0, blue: 57.0 / 255.0)
    static let uiBlue = Color(
        red: 10.0 / 255.0, green: 132.0 / 255.0, blue: 1.0)
    // 分隔线与投影：随主题切换明度
    static let rule = Color(nsColor: NSColor(name: nil) { appearance in
        let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        return isDark
            ? NSColor(white: 1, alpha: 0.12)
            : NSColor(srgbRed: 207.0 / 255.0, green: 214.0 / 255.0,
                      blue: 223.0 / 255.0, alpha: 1)
    })
    static let shadow = dynamicWhite(light: (0.05, 0.12), dark: (0.0, 0.46))
}

// ===== v1.5.6 TypeScale（design.md §78-79：每屏 ≤5 档，与 Android/Harmony/iOS 同值）=====
enum TypeScale {
    static let caption: CGFloat = 11     // 辅助说明/状态
    static let body: CGFloat = 12        // 正文/标签
    static let emphasis: CGFloat = 15    // 强调/卡片标题
    static let title: CGFloat = 18       // 区块标题
    static let display: CGFloat = 24     // 大数字/读数
    // v1.5.7 F1：页面级标题档（工作区页头/设置面板主标题等单屏唯一大标题）。
    // 与 display(24) 语义互补：display 是「大数字/读数」，heading 是「文字页面标题」；
    // 任一页面仍只用 ≤5 档（页面标题与正文/标签/读数组合不会同屏超过 5 档）。
    static let heading: CGFloat = 26     // 页面标题
}

private struct NativeButtonStyle: ButtonStyle {
    var primary = false
    var accent = Palette.cobalt

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: TypeScale.emphasis, weight: .semibold))
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

private struct NikonCloudMacMonitorPicker: View {
    @ObservedObject var model: CameraModel
    let darkAppearance: Bool
    @State private var showingPresetPicker = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Text("NP3")
                    .font(.system(size: TypeScale.caption, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.white)
                    .frame(width: 40, height: 40)
                    .background(Palette.cobalt, in: RoundedRectangle(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 2) {
                    Text("尼康云创监看")
                        .font(.system(size: TypeScale.emphasis, weight: .semibold))
                        .foregroundStyle(darkAppearance ? Color.white : Palette.ink)
                    Text(
                        verbatim: model.monitorNikonCloudPreset?.name
                            ?? String(localized: "已关闭")
                    )
                    .font(.system(size: TypeScale.caption))
                    .foregroundStyle(
                        darkAppearance
                            ? Color.white // v1.5.7 issue 655a0a14: 视频页云创卡文字改纯白
                            : Palette.muted
                    )
                    .lineLimit(1)
                }

                Spacer(minLength: 8)

                Button {
                    showingPresetPicker = true
                } label: {
                    Label("选择预设", systemImage: "slider.horizontal.3")
                        .lineLimit(1)
                }
                .buttonStyle(.borderedProminent)
                // v1.5.7 F1：readoutGlow 仅用于曝光读数，按钮 tint 用 cobalt（自带 dynamic dark 变体）
                .tint(Palette.cobalt)
                .disabled(NikonCloudPresetLibrary.presets.isEmpty)
            }

            Text("照片与视频实时生效 · SDR 近似 · 不写入原片")
                .font(.system(size: TypeScale.caption))
                .foregroundStyle(
                    darkAppearance
                        ? Color.white // v1.5.7 issue 655a0a14: 视频页云创卡说明改纯白
                        : Palette.muted
                )
        }
        .padding(12)
        .frame(minHeight: 72)
        .background(
            darkAppearance
                ? Palette.cloudBg
                : Palette.cobaltSoft,
            in: RoundedRectangle(cornerRadius: 14)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .stroke(
                    darkAppearance
                        ? Palette.cloudStroke
                        : Palette.cobalt.opacity(0.34)
                )
        }
        .sheet(isPresented: $showingPresetPicker) {
            NikonCloudMacMonitorPresetSheet(model: model)
        }
    }
}

private struct NikonCloudMacMonitorPresetSheet: View {
    @ObservedObject var model: CameraModel
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    private var filteredGroups: [NikonCloudPresetGroup] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return NikonCloudPresetLibrary.groups }
        return NikonCloudPresetLibrary.groups.compactMap { group in
            let presets = group.presets.filter {
                $0.name.localizedCaseInsensitiveContains(query)
            }
            return presets.isEmpty
                ? nil
                : NikonCloudPresetGroup(title: group.title, presets: presets)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Button {
                    model.setMonitorNikonCloudPreset(nil)
                    dismiss()
                } label: {
                    HStack {
                        Label("关闭云创监看", systemImage: "xmark.circle")
                        Spacer()
                        if model.monitorNikonCloudPresetID == nil {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Palette.cobalt)
                        }
                    }
                }

                ForEach(filteredGroups) { group in
                    Section(group.title) {
                        ForEach(group.presets) { preset in
                            Button {
                                model.setMonitorNikonCloudPreset(preset)
                                dismiss()
                            } label: {
                                HStack(spacing: 10) {
                                    Text(verbatim: preset.name)
                                        .foregroundStyle(Palette.ink)
                                    Spacer()
                                    if preset.hasCustomToneCurve {
                                        Text("CURVE")
                                            .font(.system(size: TypeScale.caption, weight: .semibold, design: .monospaced))
                                            .foregroundStyle(Palette.muted)
                                    }
                                    if model.monitorNikonCloudPresetID == preset.id {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(Palette.cobalt)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("尼康云创监看")
            .searchable(text: $searchText, prompt: "搜索云创预设")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
        }
        .frame(minWidth: 480, idealWidth: 520, minHeight: 520, idealHeight: 580)
        .background(Palette.surface)
    }
}

private struct ImmersiveMacCameraView: View {
    @ObservedObject var model: CameraModel
    @State private var showsParameters = true
    @State private var showsMoreParameters = false
    @State private var videoShutterMode = "angle"
    let monitoring: Bool
    let close: () -> Void

    var body: some View {
        GeometryReader { proxy in
            let edgeLayout = proxy.size.width > proxy.size.height
                ? AnyLayout(HStackLayout())
                : AnyLayout(VStackLayout())
            ZStack {
            Color.black.ignoresSafeArea()
            if let frame = (monitoring || model.monitorNikonCloudPreset != nil
                ? model.frame : model.photoFrame) {
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
                    .font(.system(size: TypeScale.caption, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.white) // v1.5.7 issue 655a0a14: 全屏监看 LIVE 红/灰状态字改纯白
                    .padding(.horizontal, 14)
                    .frame(height: 44)
                    .background(Palette.hudBgSoft, in: Capsule())
                    Spacer()
                    Text(
                        model.connected
                            ? "\(model.cameraName ?? "相机") · USB/PTP"
                            : model.localCameraConnected
                                ? "\(model.localCamera.deviceName) · SYSTEM"
                                : model.wifiCamera.isConnected
                                    ? "Wi‑Fi 相机 · PTP-IP"
                                    : "— · OFFLINE"
                    )
                        .font(.system(size: TypeScale.caption, weight: .semibold, design: .monospaced))
                        .padding(.horizontal, 14)
                        .frame(height: 44)
                        .background(Palette.hudBgSoft, in: Capsule())
                }
                immersiveTelemetryHUD
                Spacer()
                immersiveParameterBar
                HStack(spacing: 20) {
                    RuntimeLocalizedText(model.connected ? shutterLabel : "—")
                    Text(model.connected
                        ? String(format: "F%.1f", model.aperture)
                        : "—")
                    Text(model.connected ? "ISO \(model.iso)" : "—")
                    Text(model.hasAnyCameraConnection
                        ? (monitoring ? "\(Int(model.videoFrameRate))P" : "JPEG")
                        : "—")
                }
                .font(.system(size: TypeScale.emphasis, weight: .semibold, design: .monospaced))
                .foregroundStyle(Color.white) // v1.5.7 issue 655a0a14: 全屏监看读数改纯白
                .padding(.horizontal, 18)
                .frame(height: 44)
                .background(Palette.hudBgSoft, in: Capsule())
            }
            .padding(20)

            if proxy.size.width > proxy.size.height {
                VStack {
                    Spacer()
                    HStack {
                        immersiveScopeDock
                        Spacer()
                    }
                    .padding(.leading, 20)
                    .padding(.bottom, 174)
                }
            }

            edgeLayout {
                immersiveToolRail
                Spacer()
                VStack(spacing: 12) {
                    Text(
                        monitoring && model.videoRecording
                            ? "● REC"
                            : monitoring ? "视频" : "照片"
                    )
                        .font(.system(size: TypeScale.title, weight: .bold))
                        .foregroundStyle(Color.white) // v1.5.7 issue 655a0a14: 全屏监看标题不再用彩色
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
                                    .fill(monitoring ? Palette.video : Palette.uiAccent)
                                    .frame(width: 76, height: 76)
                            }
                            Circle()
                                .stroke(Palette.whiteMid, lineWidth: 3)
                                .frame(width: 88, height: 88)
                            if !monitoring {
                                Image(systemName: "camera.fill")
                                    .font(.system(size: TypeScale.title, weight: .bold))
                                    .foregroundStyle(.white) // v1.5.7 issue 655a0a14: 黄绿底激活钮黑字改白字
                            }
                        }
                        .frame(width: 96, height: 96)
                    }
                    .buttonStyle(.plain)
                    .disabled(
                        (monitoring
                            ? !(model.connected || (
                                model.localCameraConnected
                                    && model.externalRecordToDevice
                            ))
                            : !model.captureReady)
                            || model.capturing
                    )
                        .help(
                            monitoring
                                ? model.videoRecording ? "停止录制" : "开始录制"
                                : "拍摄照片"
                        )
                    Button {
                        model.triggerAutoFocus()
                    } label: {
                        Text("AF-ON")
                    }
                    .buttonStyle(ImmersiveMacButtonStyle())
                    .disabled(!model.connected || !model.liveViewEnabled)

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

    private var immersiveTelemetryHUD: some View {
        let connected = model.hasAnyCameraConnection
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 1) {
                telemetryCell(
                    "SOURCE",
                    model.connected
                        ? "USB/PTP"
                        : model.localCameraConnected ? "SYSTEM" : "OFFLINE"
                )
                telemetryCell(
                    "FORMAT",
                    connected
                        ? (monitoring ? "\(Int(model.videoFrameRate))P · VIDEO" : "PHOTO · JPEG")
                        : "—"
                )
                telemetryCell("SHUTTER", model.connected ? shutterLabel : "—")
                telemetryCell(
                    "IRIS",
                    model.connected ? String(format: "F%.1f", model.aperture) : "—"
                )
                telemetryCell("ISO", model.connected ? "\(model.iso)" : "—")
                telemetryCell(
                    "EV",
                    model.connected ? String(format: "%+.1f", model.compensation) : "—"
                )
                telemetryCell(
                    "STATE",
                    connected
                        ? (model.videoRecording ? "REC" : model.liveViewEnabled ? "LIVE" : "STBY")
                        : "OFFLINE"
                )
            }
            .background(Palette.uiSecondary)
        }
        .frame(height: 52)
        .clipShape(RoundedRectangle(cornerRadius: 5))
    }

    private func telemetryCell(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: TypeScale.caption, weight: .bold, design: .monospaced))
                .foregroundStyle(Color.white) // v1.5.7 issue 655a0a14: 全屏监看遥测标签改纯白
            Text(value)
                .font(.system(size: TypeScale.body, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white)
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .frame(minWidth: 100, maxHeight: .infinity, alignment: .leading)
        .background(Palette.uiCard.opacity(0.9))
    }

    private var immersiveScopeDock: some View {
        HStack(spacing: 6) {
            MacScopePlot(
                label: "RGB",
                traces: [
                    MacScopeTrace(value: model.redHistogram, color: Palette.scopeR),
                    MacScopeTrace(value: model.greenHistogram, color: Palette.scopeG),
                    MacScopeTrace(value: model.blueHistogram, color: Palette.scopeB)
                ],
                parade: false
            )
            .frame(width: 180, height: 80)
            MacAudioScopePlot(label: "AUDIO")
                .frame(width: 92, height: 80)
        }
        .padding(5)
        .background(Palette.uiBackground.opacity(0.9))
        .overlay {
            RoundedRectangle(cornerRadius: 5)
                .stroke(Palette.uiSecondary, lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 5))
        .allowsHitTesting(false)
    }

    private var immersiveToolRail: some View {
        VStack(spacing: 8) {
            Text(model.connected ? model.exposureMode.uppercased() : "—")
                .font(.system(size: TypeScale.title, weight: .bold, design: .monospaced))
                .frame(width: 64, height: 52)
                .background(Palette.uiCard.opacity(0.9))
            Text(model.connected ? "USB\nPTP" : "OFFLINE")
                .font(.system(size: TypeScale.caption, weight: .bold, design: .monospaced))
                .multilineTextAlignment(.center)
                .frame(width: 64, height: 48)
                .background(Palette.uiCard.opacity(0.9))
            if monitoring {
                Button {
                    model.setFocusPeakingEnabled(!model.focusPeakingEnabled)
                } label: {
                    Label("峰值", systemImage: "scope")
                        .labelStyle(.iconOnly)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(
                    ImmersiveMacButtonStyle(active: model.focusPeakingEnabled)
                )
                .disabled(!model.connected)
                Button {
                    model.setFalseColorEnabled(!model.falseColorEnabled)
                } label: {
                    Image(systemName: "circle.lefthalf.filled")
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(
                    ImmersiveMacButtonStyle(active: model.falseColorEnabled)
                )
                .disabled(!model.connected)
            }
        }
        .padding(6)
        .background(Palette.uiCard.opacity(0.68))
        .clipShape(RoundedRectangle(cornerRadius: 7))
    }

    @ViewBuilder
    private var immersiveParameterBar: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Button {
                    showsParameters.toggle()
                } label: {
                    RuntimeLocalizedText(
                        showsParameters ? "收起参数" : "展开参数"
                    )
                }
                .buttonStyle(ImmersiveMacButtonStyle())
                if showsParameters {
                    Button {
                        showsMoreParameters.toggle()
                    } label: {
                        Label {
                            RuntimeLocalizedText(
                                showsMoreParameters ? "收起更多" : "更多参数"
                            )
                        } icon: {
                            Image(systemName: "slider.horizontal.3")
                        }
                    }
                    .buttonStyle(ImmersiveMacButtonStyle())
                    .tint(showsMoreParameters ? Palette.uiAccent : nil)
                }
            }
            if showsParameters {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        if monitoring {
                            Picker("视频快门表示", selection: $videoShutterMode) {
                                Text("角度").tag("angle")
                                Text("速度").tag("speed")
                            }
                            .pickerStyle(.segmented)
                            .disabled(!model.connected)
                            parameterControl(
                                videoShutterMode == "angle" ? "快门角度" : "快门速度",
                                videoShutterMode == "angle"
                                    ? model.videoShutterAngle.formatted() + "°"
                                    : videoShutterSpeed,
                                parameter: "videoExposureTime",
                                decrease: {
                                    if videoShutterMode == "angle" { adjustVideoShutterAngle(-1) }
                                    else { adjustVideoShutterSpeed(-1) }
                                },
                                increase: {
                                    if videoShutterMode == "angle" { adjustVideoShutterAngle(1) }
                                    else { adjustVideoShutterSpeed(1) }
                                }
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
                    }
                    .padding(.horizontal, 2)
                }
                if showsMoreParameters {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            if monitoring {
                                ImmersiveMacParameterControl(
                                    title: "视频帧率",
                                    value: model.connected
                                        ? "\(Int(model.videoFrameRate)) fps"
                                        : "—",
                                    enabled: model.connected,
                                    lockedReason: model.connected ? nil : "请先连接相机",
                                    decrease: { adjustVideoFrameRate(-1) },
                                    increase: { adjustVideoFrameRate(1) }
                                )
                                parameterControl(
                                    "拍摄模式",
                                    model.exposureMode.uppercased(),
                                    parameter: "exposureMode",
                                    decrease: { adjustExposureMode(-1) },
                                    increase: { adjustExposureMode(1) }
                                )
                                ImmersiveMacParameterControl(
                                    title: "视频录制规格",
                                    value: model.connected
                                        ? model.monitorVideoCodec.label
                                        : "—",
                                    enabled: model.connected,
                                    lockedReason: model.connected ? nil : "请先连接相机",
                                    decrease: { model.stepMonitorVideoCodec(-1) },
                                    increase: { model.stepMonitorVideoCodec(1) }
                                )
                                ImmersiveMacParameterControl(
                                    title: "Log",
                                    value: model.connected
                                        ? model.monitorVideoLog.shortLabel
                                        : "—",
                                    enabled: model.connected,
                                    lockedReason: model.connected ? nil : "请先连接相机",
                                    decrease: { model.stepMonitorVideoLog(-1) },
                                    increase: { model.stepMonitorVideoLog(1) }
                                )
                            } else {
                                parameterControl(
                                    "拍摄模式",
                                    model.exposureMode.uppercased(),
                                    parameter: "exposureMode",
                                    decrease: { adjustExposureMode(-1) },
                                    increase: { adjustExposureMode(1) }
                                )
                            }
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
                            parameterControl(
                                "优化校准",
                                model.pictureControl == "neutral" ? "自然" : "标准",
                                parameter: "pictureControl",
                                decrease: { setPictureControl("neutral") },
                                increase: { setPictureControl("standard") }
                            )
                        }
                        .padding(.horizontal, 2)
                    }
                    .transition(.opacity)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var videoShutterSpeed: String {
        let seconds = model.videoShutterAngle / (360 * max(model.videoFrameRate, 1))
        return seconds < 1 ? "1/\(Int((1 / seconds).rounded()))" : String(format: "%.1fs", seconds)
    }

    private func adjustVideoShutterSpeed(_ direction: Int) {
        let values: [Double] = [
            1.0 / 8000.0, 1.0 / 4000.0, 1.0 / 2000.0,
            1.0 / 1000.0, 1.0 / 500.0, 1.0 / 250.0,
            1.0 / 125.0, 1.0 / 60.0, 1.0 / 30.0,
            1.0 / 15.0, 1.0 / 8.0, 1.0 / 4.0,
            1.0 / 2.0, 1.0
        ]
        let current = model.videoShutterAngle / (360 * max(model.videoFrameRate, 1))
        let index = values.enumerated().min { abs($0.element - current) < abs($1.element - current) }?.offset ?? 7
        let next = values[min(max(index + direction, 0), values.count - 1)]
        model.applyParameter("videoExposureTime", value: next, label: "快门速度")
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
            value: model.connected ? value : "—",
            enabled: model.connected && model.canAdjustExposureParameter(parameter),
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

    private func adjustExposureMode(_ offset: Int) {
        let values = [
            "program",
            "shutterPriority",
            "aperturePriority",
            "manual",
            "bulb"
        ]
        let current = values.firstIndex(of: model.exposureMode) ?? 3
        let next = max(0, min(values.count - 1, current + offset))
        model.exposureMode = values[next]
        model.applyParameter(
            "exposureMode",
            value: values[next],
            label: "拍摄模式"
        )
    }

    private func setPictureControl(_ value: String) {
        model.pictureControl = value
        model.applyParameter(
            "pictureControl",
            value: value,
            label: "优化校准"
        )
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
                .font(.system(size: TypeScale.caption, weight: .semibold))
                .foregroundStyle(Color.white) // v1.5.7 issue 655a0a14: 全屏参数标签改纯白
            HStack(spacing: 5) {
                Button(action: decrease) {
                    Image(systemName: "minus")
                        .frame(width: 44, height: 44)
                }
                Text(value)
                    .font(.system(size: TypeScale.body, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.white) // v1.5.7 issue 655a0a14: 激活态读数不再用 uiAccent
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
        .background(Palette.uiCard.opacity(0.9), in: RoundedRectangle(cornerRadius: 7))
        .overlay {
            RoundedRectangle(cornerRadius: 7)
                .stroke(
                    enabled ? Palette.uiAccent.opacity(0.48) : Palette.uiSecondary,
                    lineWidth: 1
                )
        }
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
    var active = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: TypeScale.emphasis, weight: .semibold))
            .foregroundStyle(Color.white) // v1.5.7 issue 655a0a14: 黄绿底激活钮黑字改白字
            .padding(.horizontal, 14)
            .frame(minHeight: 44)
            .background(
                active ? Palette.uiAccent : Palette.uiCard.opacity(0.88),
                in: RoundedRectangle(cornerRadius: 7)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 7)
                    .stroke(Palette.uiSecondary, lineWidth: 1)
            }
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
                    RoundedRectangle(cornerRadius: 13).fill(
                        LinearGradient(
                            colors: [Palette.cobalt, Palette.cobalt.opacity(0.82)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    Text("Z")
                        .font(.system(size: TypeScale.title, weight: .heavy))
                        .foregroundStyle(.white)
                }
                .frame(width: 44, height: 44)
                .shadow(color: Palette.cobalt.opacity(0.35), radius: 8, y: 4)
                VStack(alignment: .leading, spacing: 1) {
                    Text("帧澈 ZENCHE")
                        .font(.system(size: TypeScale.title, weight: .bold))
                    Text("Capture · Connect · Flow")
                        .font(.system(size: TypeScale.caption, weight: .medium))
                        .foregroundStyle(Palette.muted)
                }
            }
            Button {
                showConnection = true
            } label: {
                HStack(spacing: 10) {
                    Circle()
                        .fill(model.hasAnyCameraConnection ? Palette.positive : Palette.muted)
                        .frame(width: 8, height: 8)
                        .shadow(
                            color: model.hasAnyCameraConnection
                                ? Palette.positive.opacity(0.85) : .clear,
                            radius: 4
                        )
                    Image(systemName: model.hasAnyCameraConnection ? "camera.fill" : "camera")
                        .foregroundStyle(model.hasAnyCameraConnection ? Palette.positive : Palette.cobalt)
                    VStack(alignment: .leading, spacing: 1) {
                        RuntimeLocalizedText(model.connectionTitle)
                            .font(.system(size: TypeScale.emphasis, weight: .bold))
                        RuntimeLocalizedText(model.connectionDetail)
                            .font(.system(size: TypeScale.caption))
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
                    .font(.system(size: TypeScale.title, weight: .semibold))
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
            navigationButton(.editor)
            Divider()
                .padding(.vertical, 8)
            groupLabel("管理")
            navigationButton(.devices)
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
            .font(.system(size: TypeScale.caption, weight: .semibold, design: .monospaced))
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
                    .font(.system(size: TypeScale.title, weight: active ? .semibold : .regular))
                Text(LocalizedStringKey(section.rawValue))
                    .font(.system(size: TypeScale.body, weight: active ? .semibold : .medium))
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
                    .font(.system(size: TypeScale.heading, weight: .bold))
                    .foregroundStyle(Palette.ink)
                RuntimeLocalizedText(subtitle)
                    .foregroundStyle(Palette.muted)
            }
        }
    }
}

/// fig1 顶栏在 macOS 的落点：窗口级 TopBar 与侧栏保留（桌面导航骨架），
/// 页内只放居左标题「控制」与右侧圆钮（◉ 全屏取景、⋯ 更多）。
private struct ControlPageHeader: View {
    @ObservedObject var model: CameraModel
    @Binding var showConnection: Bool
    @Binding var showSettings: Bool

    var body: some View {
        HStack(spacing: 12) {
            Text("控制")
                .font(.system(size: TypeScale.title, weight: .bold))
                .foregroundStyle(.white)
            Spacer()
            Button {
                showMacImmersiveWindow(model: model, monitoring: false)
            } label: {
                controlBarButton("viewfinder")
            }
            .buttonStyle(.plain)
            .help(Text("打开全屏取景"))
            Menu {
                Button {
                    showConnection = true
                } label: {
                    Label("连接相机", systemImage: "cable.connector")
                }
                Divider()
                Button {
                    showSettings = true
                } label: {
                    Label("设置", systemImage: "gearshape")
                }
            } label: {
                controlBarButton("ellipsis")
            }
            .help(Text("更多"))
        }
        .frame(height: 44)
    }

    private func controlBarButton(_ symbol: String) -> some View {
        Image(systemName: symbol)
            .font(.system(size: TypeScale.emphasis, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 40, height: 40)
            .background(Palette.uiSecondary, in: Circle())
    }
}

/// fig1 status row: connection dot and state on the left, a tappable
/// transport capsule on the right, plus a red error line spelling out the
/// last connection failure (Wi-Fi 直接读 WifiCameraService.failed 的原因；
/// USB/本机复用 detail 里既有的失败文案，不新增状态)。
private struct ControlStatusRow: View {
    @ObservedObject var model: CameraModel
    var openConnection: () -> Void

    private var connecting: Bool {
        model.connecting || model.wifiCamera.state == .connecting ||
            model.wifiCamera.state.isReconnecting
    }

    private var wifiFailure: String? {
        if case .failed(let message) = model.wifiCamera.state { return message }
        return nil
    }

    private var failureText: String? {
        if let wifiFailure { return wifiFailure }
        guard !model.hasAnyCameraConnection, !connecting else { return nil }
        return model.detail.contains("失败") ? model.detail : nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                RuntimeLocalizedText(model.connectionTitle)
                    .font(.system(size: TypeScale.emphasis, weight: .semibold))
                    .foregroundStyle(.white)
                RuntimeLocalizedText(model.connectionDetail)
                    .font(.system(size: TypeScale.body))
                    .foregroundStyle(Palette.uiLabel)
                    .lineLimit(1)
                Spacer(minLength: 8)
                Button(action: openConnection) {
                    RuntimeLocalizedText(transportTitle)
                        .font(.system(size: TypeScale.body, weight: .semibold))
                        .foregroundStyle(capsuleTint)
                        .padding(.horizontal, 12)
                        .frame(height: 28)
                        .background(capsuleTint.opacity(0.14), in: Capsule())
                        .overlay {
                            Capsule()
                                .stroke(capsuleTint.opacity(0.4), lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)
                .help(Text("连接相机"))
            }
            if let failureText {
                RuntimeLocalizedText(failureText)
                    .font(.system(size: TypeScale.body, weight: .medium))
                    .foregroundStyle(.red)
                    .lineLimit(2)
            }
        }
    }

    private var statusColor: Color {
        if model.hasAnyCameraConnection { return Palette.positive }
        if connecting { return .orange }
        if failureText != nil { return .red }
        return Palette.uiLabel
    }

    private var transportTitle: String {
        if model.connected { return "USB/PTP" }
        if model.localCameraConnected { return "SYSTEM" }
        if model.wifiCamera.isConnected { return "Wi-Fi" }
        if connecting { return "正在连接" }
        if failureText != nil { return "重试" }
        return "待连接"
    }

    private var capsuleTint: Color {
        if model.hasAnyCameraConnection { return Palette.uiAccent }
        if failureText != nil { return .red }
        return Palette.uiLabel
    }
}

/// fig1 status cards: body, lens, storage (accent progress bar) and format,
/// laid out four across on the desktop window. Every value is sourced from
/// CameraModel or the file system; fields without a real source stay "—".
private struct ControlStatusCardGrid: View {
    @ObservedObject var model: CameraModel

    var body: some View {
        HStack(spacing: 10) {
            statusCard(
                icon: "camera",
                title: "机身",
                value: model.hasAnyCameraConnection ? model.activeCameraName : "—",
                subtitle: transportSubtitle
            )
            statusCard(
                icon: "camera.aperture",
                title: "镜头",
                value: model.connected
                    ? String(format: "F%.1f", model.aperture)
                    : "—",
                subtitle: model.connected
                    ? (model.focusMode == "continuous" ? "AF-C" : "AF-S")
                    : "—"
            )
            storageCard
            statusCard(
                icon: "rectangle.on.rectangle",
                title: "格式",
                value: model.hasAnyCameraConnection ? "\(Int(model.videoFrameRate))P · JPEG" : "—",
                subtitle: model.hasAnyCameraConnection
                    ? model.monitorVideoProfile.label
                    : "—"
            )
        }
    }

    private var transportSubtitle: String {
        if model.connected { return "USB/PTP" }
        if model.localCameraConnected { return "SYSTEM" }
        if model.wifiCamera.isConnected { return "Wi-Fi" }
        return "—"
    }

    private func statusCard(
        icon: String,
        title: String,
        value: String,
        subtitle: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: TypeScale.body, weight: .semibold))
                Text(LocalizedStringKey(title))
                    .font(.system(size: TypeScale.body, weight: .medium))
                Spacer(minLength: 2)
            }
            .foregroundStyle(Palette.uiLabel)
            Text(value)
                .font(.system(size: TypeScale.emphasis, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            RuntimeLocalizedText(subtitle)
                .font(.system(size: TypeScale.caption, weight: .medium))
                .foregroundStyle(Palette.uiLabel)
                .lineLimit(1)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.uiCard, in: RoundedRectangle(cornerRadius: 14))
    }

    private var storageCard: some View {
        let info = MacMonitorStorageInfo.current
        return VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                Image(systemName: "externaldrive")
                    .font(.system(size: TypeScale.body, weight: .semibold))
                    .foregroundStyle(Palette.uiAccent)
                Text("存储")
                    .font(.system(size: TypeScale.body, weight: .medium))
                    .foregroundStyle(Palette.uiLabel)
                Spacer(minLength: 2)
                Text("\(info.percentUsed)%")
                    .font(.system(size: TypeScale.caption, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Palette.uiLabel)
            }
            Text(info.freeDescription)
                .font(.system(size: TypeScale.emphasis, weight: .bold))
                .foregroundStyle(.white)
            ProgressView(value: Double(info.percentUsed), total: 100)
                .tint(Palette.uiAccent)
            Text("\(info.percentUsed)% 已用 · 本地缓存")
                .font(.system(size: TypeScale.caption, weight: .medium))
                .foregroundStyle(Palette.uiLabel)
                .lineLimit(1)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.uiCard, in: RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .stroke(Palette.uiAccent, lineWidth: 1)
        }
    }
}

/// fig1 parameter grid: adaptive 4–6 columns on the desktop window, 28pt
/// bold values with gray 12pt labels. 全部/编辑 toggles an edit mode whose
/// clicks hide tiles; the state is pure UI. A parameter the camera exposes
/// as read-only carries the system-blue auto badge (口径同旧读数轨的「自动」)。
private struct ControlParameterGrid: View {
    @ObservedObject var model: CameraModel
    @State private var editing = false
    @State private var hiddenTiles: Set<String> = []

    private struct Tile: Identifiable {
        let id: String
        let symbol: String
        let value: String
        let automatic: Bool
        /// 可写值读数发光（Readout glow #6BAEFF，design.md 0e0ab21）；
        /// 不可写/纯展示值用中性白。
        var glow: Bool = false
    }

    private var sourceText: String {
        if model.connected { return "USB/PTP" }
        if model.localCameraConnected { return "SYSTEM" }
        if model.wifiCamera.isConnected { return "Wi-Fi" }
        return "—"
    }

    private var shutterText: String {
        guard model.connected else { return "—" }
        if model.exposureMode == "bulb" { return "B门" }
        return model.shutter < 1
            ? "1/\(Int((1 / model.shutter).rounded()))"
            : String(format: "%.1fs", model.shutter)
    }

    private var tiles: [Tile] {
        [
            Tile(
                id: "来源",
                symbol: "cable.connector",
                value: model.hasAnyCameraConnection ? sourceText : "—",
                automatic: false
            ),
            Tile(
                id: "模式",
                symbol: "dial.medium",
                value: model.connected ? model.exposureMode.uppercased() : "—",
                automatic: false,
                glow: true
            ),
            Tile(
                id: "快门",
                symbol: "timer",
                value: shutterText,
                automatic: model.connected
                    && !model.canAdjustExposureParameter("exposureTime"),
                glow: model.connected
                    && model.canAdjustExposureParameter("exposureTime")
            ),
            Tile(
                id: "光圈",
                symbol: "camera.aperture",
                value: model.connected
                    ? String(format: "F%.1f", model.aperture)
                    : "—",
                automatic: model.connected
                    && !model.canAdjustExposureParameter("aperture"),
                glow: model.connected
                    && model.canAdjustExposureParameter("aperture")
            ),
            Tile(
                id: "ISO",
                symbol: "circle.lefthalf.filled",
                value: model.connected ? "\(model.iso)" : "—",
                automatic: model.connected
                    && !model.canAdjustExposureParameter("iso"),
                glow: model.connected
                    && model.canAdjustExposureParameter("iso")
            ),
            Tile(
                id: "曝光",
                symbol: "plusminus",
                value: model.connected
                    ? String(format: "%+.1f EV", model.compensation)
                    : "—",
                automatic: model.connected
                    && !model.canAdjustExposureParameter("exposureCompensation"),
                glow: model.connected
                    && model.canAdjustExposureParameter("exposureCompensation")
            ),
            Tile(
                id: "对焦",
                symbol: "viewfinder",
                value: model.connected
                    ? (model.focusMode == "continuous" ? "AF-C" : "AF-S")
                    : "—",
                automatic: false,
                glow: true
            )
        ]
    }

    private var visibleTiles: [Tile] {
        editing ? tiles : tiles.filter { !hiddenTiles.contains($0.id) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text("拍摄参数")
                    .font(.system(size: TypeScale.emphasis, weight: .bold))
                    .foregroundStyle(.white)
                Spacer()
                capsuleButton("全部", active: !editing) {
                    editing = false
                    hiddenTiles = []
                }
                capsuleButton("编辑", active: editing) {
                    editing.toggle()
                }
            }
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 150), spacing: 10)],
                spacing: 10
            ) {
                ForEach(visibleTiles) { tile in
                    parameterTile(tile)
                }
            }
        }
    }

    private func capsuleButton(
        _ title: String,
        active: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(LocalizedStringKey(title))
                .font(.system(size: TypeScale.body, weight: .semibold))
                .foregroundStyle(active ? Color.black : Color.white)
                .padding(.horizontal, 14)
                .frame(height: 30)
                .background(
                    active ? Palette.uiAccent : Palette.uiSecondary,
                    in: Capsule()
                )
        }
        .buttonStyle(.plain)
    }

    private func parameterTile(_ tile: Tile) -> some View {
        let hidden = hiddenTiles.contains(tile.id)
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: tile.symbol)
                    .font(.system(size: TypeScale.body, weight: .medium))
                Text(LocalizedStringKey(tile.id))
                    .font(.system(size: TypeScale.body, weight: .medium))
                Spacer(minLength: 2)
                if editing {
                    Image(
                        systemName: hidden
                            ? "plus.circle.fill"
                            : "minus.circle.fill"
                    )
                    .font(.system(size: TypeScale.emphasis))
                    .foregroundStyle(
                        hidden ? Palette.uiAccent : Palette.uiLabel
                    )
                } else if tile.automatic {
                    // v1.5.7 F1：单字母 "A" → 完整 "AUTO" 字面（对齐 iOS 曝光模式口径），
                    // 圆徽标改 Capsule；字号归 TypeScale.caption
                    Text("AUTO")
                        .font(.system(size: TypeScale.caption, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5)
                        .frame(height: 18)
                        .background(Palette.uiBlue, in: Capsule())
                }
            }
            .foregroundStyle(Palette.uiLabel)
            Text(tile.value)
                // 校准读数大字（曝光参数值），专属读数不受 TypeScale 5 档约束
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(tileValueColor(tile))
                .lineLimit(1)
                .minimumScaleFactor(0.55)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 92, alignment: .leading)
        .background(Palette.uiCard, in: RoundedRectangle(cornerRadius: 14))
        .opacity(editing && hidden ? 0.35 : 1)
        .contentShape(RoundedRectangle(cornerRadius: 14))
        .onTapGesture {
            guard editing else { return }
            if hidden {
                hiddenTiles.remove(tile.id)
            } else {
                hiddenTiles.insert(tile.id)
            }
        }
    }

    /// 读数值用色：可写值 Readout glow（#6BAEFF，0e0ab21 条款）；
    /// 相机接管值中性高对比白；未连接灰。
    private func tileValueColor(_ tile: Tile) -> Color {
        guard model.connected else { return Palette.uiLabel }
        if tile.glow { return Palette.readoutGlow }
        return Palette.whiteMid
    }
}

/// fig1 capture dock: library thumbnail, AF-ON, the accent-ringed shutter,
/// INT (scrolls to the shooting task panel) and the camera switcher. Every
/// action reuses the existing CameraModel entry points.
private struct ControlCaptureDock: View {
    @ObservedObject var model: CameraModel
    var openConnection: () -> Void
    var scrollToTasks: () -> Void

    var body: some View {
        HStack {
            libraryButton
            Spacer()
            afOnButton
            Spacer()
            shutterButton
            Spacer()
            intButton
            Spacer()
            switchCameraButton
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Palette.uiCard, in: RoundedRectangle(cornerRadius: 16))
    }

    private var libraryButton: some View {
        Button {
            model.section = .library
        } label: {
            VStack(spacing: 4) {
                ControlGalleryThumbnail(photo: model.photos.first)
                    .frame(width: 46, height: 46)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                Text("\(model.photos.count) 个文件")
                    .font(.system(size: TypeScale.caption, weight: .medium))
                    .foregroundStyle(Palette.uiLabel)
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
        .help(Text("文件"))
    }

    private var afOnButton: some View {
        Button {
            model.triggerAutoFocus()
        } label: {
            Text("AF-ON")
                .font(.system(size: TypeScale.emphasis, weight: .bold))
                .foregroundStyle(
                    model.connected && model.liveViewEnabled
                        ? Palette.uiAccent
                        : Palette.uiLabel
                )
                .padding(.horizontal, 14)
                .frame(height: 40)
                .overlay {
                    Capsule()
                        .stroke(
                            model.connected && model.liveViewEnabled
                                ? Palette.uiAccent
                                : Palette.uiSecondary,
                            lineWidth: 1.5
                        )
                }
        }
        .buttonStyle(.plain)
        .disabled(!model.connected || !model.liveViewEnabled)
    }

    private var shutterButton: some View {
        Button {
            if model.hasAnyCameraConnection { model.capture() }
            else { openConnection() }
        } label: {
            ZStack {
                Circle()
                    .stroke(Palette.uiAccent, lineWidth: 4)
                    .frame(width: 68, height: 68)
                Circle()
                    .fill(.white)
                    .frame(width: 54, height: 54)
            }
            .frame(width: 76, height: 76)
        }
        .buttonStyle(.plain)
        .disabled(model.capturing)
        .opacity(model.capturing ? 0.45 : 1)
        .help(Text("拍摄照片"))
    }

    private var intButton: some View {
        Button(action: scrollToTasks) {
            HStack(spacing: 5) {
                Image(systemName: "timer")
                    .font(.system(size: TypeScale.body, weight: .semibold))
                Text("INT")
                    .font(.system(size: TypeScale.emphasis, weight: .bold))
            }
            .foregroundStyle(Palette.uiAccent)
            .padding(.horizontal, 12)
            .frame(height: 40)
            .overlay {
                Capsule()
                    .stroke(Palette.uiAccent, lineWidth: 1.5)
            }
        }
        .buttonStyle(.plain)
        .help(Text("拍摄自动化"))
    }

    private var switchCameraButton: some View {
        Button(action: openConnection) {
            Image(systemName: "arrow.triangle.2.circlepath.camera")
                .font(.system(size: 17, weight: .medium)) // 图标尺寸，不受 TypeScale 约束
                .foregroundStyle(.white)
                .frame(width: 46, height: 46)
                .background(
                    Palette.uiSecondary,
                    in: RoundedRectangle(cornerRadius: 10)
                )
        }
        .buttonStyle(.plain)
        .help(Text("选择相机"))
    }
}

/// 缩略图在后台解码，避免在视图体里做同步磁盘 I/O。
private struct ControlGalleryThumbnail: View {
    let photo: PhotoRecord?
    @State private var image: NSImage?

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "photo.on.rectangle")
                    .font(.system(size: 17, weight: .medium)) // 图标尺寸，不受 TypeScale 约束
                    .foregroundStyle(Palette.uiLabel)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Palette.uiSecondary)
            }
        }
        .onAppear { reload() }
        .onChange(of: photo) { _, _ in reload() }
    }

    private func reload() {
        guard let photo, !photo.isVideo else {
            image = nil
            return
        }
        let url = photo.url
        DispatchQueue.global(qos: .userInitiated).async {
            let decoded = NSImage(contentsOf: url)
            DispatchQueue.main.async { image = decoded }
        }
    }
}

private struct CaptureView: View {
    @ObservedObject var model: CameraModel
    @Binding var showConnection: Bool
    @Binding var showSettings: Bool

    var body: some View {
        HStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        ControlPageHeader(
                            model: model,
                            showConnection: $showConnection,
                            showSettings: $showSettings
                        )
                        ControlStatusRow(model: model) { showConnection = true }
                        ControlStatusCardGrid(model: model)
                        ControlParameterGrid(model: model)
                        ControlCaptureDock(
                            model: model,
                            openConnection: { showConnection = true }
                        ) {
                            withAnimation {
                                proxy.scrollTo(
                                    "captureShootingTasks",
                                    anchor: .top
                                )
                            }
                        }
                        NikonCloudMacMonitorPicker(
                            model: model,
                            darkAppearance: true
                        )
                        CaptureSessionPanel(workflow: model.captureWorkflow)
                        ShootingTaskPanel(model: model)
                            .id("captureShootingTasks")
                    }
                    .padding(24)
                }
            }
            .frame(minWidth: 560)
            .background(Palette.uiBackground)
            ParameterInspector(model: model)
                .frame(width: 330)
        }
        // fig1 控制面恒为深色；强制深色让保留的旧面板在同一页内观感一致。
        .preferredColorScheme(.dark)
    }
}

private struct ShootingTaskPanel: View {
    @ObservedObject var model: CameraModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("拍摄自动化")
                .font(.system(size: TypeScale.title, weight: .bold))
                .foregroundStyle(.white)
            Text("间隔、包围与 B 门任务集中管理")
                .font(.system(size: TypeScale.body))
                .foregroundStyle(Palette.uiLabel)
            Text("任务类型")
                .font(.system(size: TypeScale.body, weight: .semibold))
                .foregroundStyle(.white)
            HStack(spacing: 6) {
                ForEach(ShootingTaskKind.allCases) { kind in
                    Button {
                        model.shootingTaskKind = kind
                    } label: {
                        Text(kind.rawValue)
                            .font(.system(size: TypeScale.body, weight: .semibold))
                            .foregroundStyle(
                                model.shootingTaskKind == kind
                                    ? Color.black : Color.white
                            )
                            .padding(.horizontal, 12)
                            .frame(height: 30)
                            .background(
                                model.shootingTaskKind == kind
                                    ? Palette.uiAccent : Palette.uiSecondary,
                                in: Capsule()
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            HStack {
                Stepper(value: $model.shootingTaskCount, in: 1...999) {
                    Text("张数 \(model.shootingTaskCount)")
                        .foregroundStyle(.white)
                }
                Stepper(value: $model.shootingTaskInterval, in: 1...3600) {
                    Text(
                        model.shootingTaskKind == .bulb
                            ? "曝光 \(model.shootingTaskInterval) 秒"
                            : "间隔 \(model.shootingTaskInterval) 秒"
                    )
                    .foregroundStyle(.white)
                }
                if model.shootingTaskKind == .exposureBracket
                    || model.shootingTaskKind == .focusBracket {
                    Stepper(value: $model.shootingTaskStep, in: 1...3) {
                        Text("步长 \(model.shootingTaskStep)")
                            .foregroundStyle(.white)
                    }
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
                .font(.system(size: TypeScale.body, design: .monospaced))
                .foregroundStyle(Palette.uiLabel)
        }
        .padding(18)
        .background(Palette.uiCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(Palette.rule, lineWidth: 1)
        }
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
                Text("拍摄控制")
                    .font(.system(size: TypeScale.title, weight: .bold))

                    Text("曝光")
                        .font(.system(size: TypeScale.emphasis, weight: .bold))
                        .foregroundStyle(Palette.muted)

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
                                .font(.system(size: TypeScale.body, design: .monospaced))
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
                    Divider()
                    Text("对焦与色彩")
                        .font(.system(size: TypeScale.emphasis, weight: .bold))
                        .foregroundStyle(Palette.muted)
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
                    nativeControl("白平衡") {
                        Picker(
                            "",
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
                            Text("预设手动").tag("manual")
                        }
                        .pickerStyle(.menu)
                        .disabled(!model.connected)
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
                        .font(.system(size: TypeScale.caption, weight: .medium))
                        .help(
                            RuntimeLocalization.text(
                                lockedReason,
                                locale: locale
                            )
                        )
                }
                Spacer()
            }
            .font(.system(size: TypeScale.emphasis, weight: .semibold))
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

private struct MacMonitorStorageInfo {
    let percentUsed: Int
    let freeDescription: String

    static var current: MacMonitorStorageInfo {
        let attributes = try? FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory())
        let total = (attributes?[.systemSize] as? NSNumber)?.doubleValue ?? 0
        let free = (attributes?[.systemFreeSize] as? NSNumber)?.doubleValue ?? 0
        let usedRatio = total > 0 ? min(1, max(0, (total - free) / total)) : 0
        return MacMonitorStorageInfo(
            percentUsed: Int((usedRatio * 100).rounded()),
            freeDescription: free > 0
                ? String(format: "%.1f GB", free / 1_073_741_824)
                : "—"
        )
    }
}

private struct MonitorView: View {
    @ObservedObject var model: CameraModel
    @State private var now = Date()
    @State private var focusPoint: CGPoint?
    private let timecodeTimer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    HStack {
                        Text(timecodeText)
                            .font(.system(size: proxy.size.width > 900 ? 42 : 30,
                                          weight: .semibold, design: .monospaced))
                            .monospacedDigit()
                            .foregroundStyle(Color.white)
                        Spacer()
                        Label(model.liveViewEnabled ? "LIVE" : "NO SOURCE", systemImage: "circle.fill")
                            .font(.system(size: TypeScale.body, weight: .bold, design: .monospaced))
                            .foregroundStyle(Color.white) // v1.5.7 issue 655a0a14: LIVE/NO SOURCE 红绿状态字改纯白
                    }
                    .padding(.horizontal, 26)
                    .padding(.vertical, 18)

                    ZStack(alignment: .topLeading) {
                        if let frame = model.frame {
                            Image(nsImage: frame)
                                .resizable()
                                .interpolation(.medium)
                                .scaledToFit()
                                .frame(maxWidth: .infinity)
                            if model.zebraEnabled, let zebra = model.zebraMask {
                                Image(nsImage: zebra)
                                    .resizable()
                                    .scaledToFit()
                                    .allowsHitTesting(false)
                            }
                        } else {
                            VStack(spacing: 12) {
                                Image(systemName: "camera.viewfinder")
                                    .font(.system(size: 46, weight: .light)) // 图标尺寸，不受 TypeScale 约束
                                Text(model.connected ? "等待实时取景画面" : "连接相机后开启实时取景")
                                    .font(.system(size: TypeScale.emphasis, weight: .medium))
                            }
                            .foregroundStyle(Color.white) // v1.5.7 issue 655a0a14: 视频页空态文字改纯白
                            .frame(maxWidth: .infinity, minHeight: 270)
                        }
                        Text("\(model.cameraName ?? "未连接") · USB/PTP")
                            .font(.system(size: TypeScale.caption, weight: .semibold, design: .monospaced))
                            .foregroundStyle(Color.white) // v1.5.7 issue 655a0a14: 视频页角标改纯白
                            .padding(12)
                        if let focusPoint {
                            ImmersiveMacFocusReticle()
                                .stroke(Color.yellow, lineWidth: 2)
                                .frame(width: 56, height: 56)
                                .position(focusPoint)
                                .allowsHitTesting(false)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .background(Palette.graphite)
                    .contentShape(Rectangle())
                    .gesture(SpatialTapGesture().onEnded { value in
                        let location = value.location
                        guard let normalized = model.focusNormalized(at: location, in: proxy.size) else {
                            model.detail = "请点击画面区域进行对焦"
                            return
                        }
                        let imageRect = model.monitorImageRect(container: proxy.size)
                        let displayPoint = CGPoint(
                            x: imageRect.minX + normalized.x * imageRect.width,
                            y: imageRect.minY + normalized.y * imageRect.height
                        )
                        focusPoint = displayPoint
                        model.focus(at: normalized)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                            if focusPoint == displayPoint { focusPoint = nil }
                        }
                    })

                    NikonCloudMacMonitorPicker(
                        model: model,
                        darkAppearance: true
                    )
                        .padding(.horizontal, 20)
                        .padding(.top, 10)

                    HStack(spacing: 14) {
                        monitorRGBWaveformCard(model)
                        Button {
                            model.toggleMovieRecording()
                        } label: {
                            ZStack {
                                Circle().fill(model.videoRecording ? Palette.video : Palette.videoIdle)
                                Circle().stroke(Color.white, lineWidth: 2)
                                Circle().fill(Palette.video).frame(width: 56, height: 56)
                            }
                            .frame(width: 108, height: 108)
                        }
                        .buttonStyle(.plain)
                        .disabled(
                            !(model.connected || (
                                model.localCameraConnected
                                    && model.externalRecordToDevice
                            )) || model.capturing
                        )
                        monitorAudioWaveformCard()
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)

                    HStack(spacing: 0) {
                        monitorReadout("帧率", "\(Int(model.videoFrameRate))")
                        monitorReadout("快门", model.connected ? "1/\(max(1, Int((1 / max(model.shutter, 0.0001)).rounded())))" : "—")
                        monitorReadout("光圈", model.connected ? String(format: "f/%.1f", model.aperture) : "—")
                        monitorReadout("ISO", model.connected ? "\(model.iso)" : "—")
                        monitorReadout("白平衡", model.connected ? (model.whiteBalance == "continuous" ? "自动" : "预设") : "—")
                        monitorReadout("编码", model.connected ? model.monitorVideoCodec.shortLabel : "—")
                        monitorReadout("色调", model.connected ? model.monitorVideoLog.shortLabel : "—")
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 14)

                    HStack(spacing: 28) {
                        monitorIconToggle("camera.aperture", title: "峰值", isOn: model.focusPeakingEnabled) { model.setFocusPeakingEnabled(!model.focusPeakingEnabled) }
                        monitorIconToggle("rectangle.on.rectangle", title: "LUT", isOn: model.lutEnabled) { model.setLUTEnabled(!model.lutEnabled) }
                        monitorIconToggle("circle.lefthalf.filled", title: "假色", isOn: model.falseColorEnabled) { model.setFalseColorEnabled(!model.falseColorEnabled) }
                        monitorIconToggle("circle.dashed", title: "斑马", isOn: model.zebraEnabled) { model.setZebraEnabled(!model.zebraEnabled) }
                        monitorIconToggle("viewfinder.circle", title: "AF-ON", isOn: false) {
                            model.triggerAutoFocus()
                        }
                        Button { model.toggleLiveView() } label: { Image(systemName: "rectangle.inset.filled") }
                            .buttonStyle(.plain)
                            .font(.system(size: 27, weight: .medium)) // 图标尺寸，不受 TypeScale 约束
                            .foregroundStyle(Color.white.opacity(0.9))
                            .help(model.liveViewEnabled ? "停止取景" : "开启取景")
                    }
                    .padding(.vertical, 18)

                    HStack(spacing: 8) {
                        MonitorMacStepper(title: "帧率", value: "\(Int(model.videoFrameRate))p", decrease: { model.stepVideoFrameRate(-1) }, increase: { model.stepVideoFrameRate(1) })
                        MonitorMacStepper(title: "快门", value: "\(model.videoShutterAngle.formatted())°", decrease: { model.stepVideoShutter(-1) }, increase: { model.stepVideoShutter(1) })
                        MonitorMacStepper(title: "编码", value: model.monitorVideoCodec.shortLabel, decrease: { model.stepMonitorVideoCodec(-1) }, increase: { model.stepMonitorVideoCodec(1) })
                        MonitorMacStepper(title: "Log", value: model.monitorVideoLog.shortLabel, decrease: { model.stepMonitorVideoLog(-1) }, increase: { model.stepMonitorVideoLog(1) })
                        MonitorMacStepper(title: "ISO", value: "\(model.iso)", decrease: { model.stepISO(-1) }, increase: { model.stepISO(1) })
                    }
                    .padding(.horizontal, 20)

                    HStack {
                        Spacer()
                        VStack(spacing: 5) {
                            Image(systemName: "iphone")
                                .font(.system(size: 28)) // 图标尺寸，不受 TypeScale 约束
                            Text(MacMonitorStorageInfo.current.freeDescription)
                                // 存储读数大字，专属读数不受 TypeScale 5 档约束
                                .font(.system(size: 25, weight: .bold, design: .monospaced))
                            ProgressView(
                                value: Double(MacMonitorStorageInfo.current.percentUsed),
                                total: 100
                            )
                            .tint(Palette.uiAccent)
                            Text("\(MacMonitorStorageInfo.current.percentUsed)% 已用 · 本地缓存")
                                .font(.system(size: TypeScale.caption, design: .monospaced))
                                .foregroundStyle(Color.white) // v1.5.7 issue 655a0a14: 视频页云创卡读数改纯白
                        }
                        .foregroundStyle(Color.white) // v1.5.7 issue 655a0a14: 视频页存储卡读数改纯白
                        .padding(.horizontal, 28)
                        .padding(.vertical, 14)
                        .background(Palette.uiCard)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        Spacer()
                    }
                    .padding(.vertical, 36)
                    .background(Palette.hudShadow)

                    MonitorControlDeck(model: model)
                        .padding(20)
                }
                .background(Palette.uiBackground)
            }
            .onReceive(timecodeTimer) { now = $0 }
        }
        .preferredColorScheme(.dark)
    }

    private var timecodeText: String {
        guard model.videoRecording, let started = model.videoRecordingStartedAt else {
            return "00:00:00:00"
        }
        let centiseconds = max(0, Int(now.timeIntervalSince(started) * 100))
        return String(format: "%02d:%02d:%02d:%02d",
                      centiseconds / 360000,
                      (centiseconds / 6000) % 60,
                      (centiseconds / 100) % 60,
                      centiseconds % 100)
    }

    private func monitorReadout(_ title: String, _ value: String) -> some View {
        VStack(spacing: 6) {
            Text(title).font(.system(size: TypeScale.caption, weight: .semibold)).foregroundStyle(Color.white) // v1.5.7 issue 655a0a14: 视频页读数标签改纯白
            Text(value).font(.system(size: TypeScale.title, weight: .bold, design: .monospaced)).monospacedDigit().foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity)
    }

    private func monitorRGBWaveformCard(_ model: CameraModel) -> some View {
        MacScopePlot(
            label: "RGB",
            traces: [
                MacScopeTrace(value: model.redHistogram, color: Palette.scopeR),
                MacScopeTrace(value: model.greenHistogram, color: Palette.scopeG),
                MacScopeTrace(value: model.blueHistogram, color: Palette.scopeB)
            ],
            parade: false
        )
        .frame(maxWidth: .infinity, minHeight: 86)
        .accessibilityLabel("RGB 波形")
    }

    private func monitorAudioWaveformCard() -> some View {
        MacAudioScopePlot(label: "AUDIO")
            .frame(maxWidth: .infinity, minHeight: 86)
            .accessibilityLabel("音频波形，无音频源，静音基线")
    }

    private func monitorIconToggle(_ icon: String, title: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: icon).font(.system(size: 25, weight: .medium)) // 图标尺寸，不受 TypeScale 约束
                Text(title).font(.system(size: TypeScale.caption, weight: .semibold))
            }
            .foregroundStyle(isOn ? Color.white : Color.white.opacity(0.9)) // v1.5.7 issue 655a0a14: 视频页工具钮激活态不再用 uiAccent 彩色
        }
        .buttonStyle(.plain)
    }
}

private struct MonitorMacStepper: View {
    let title: String
    let value: String
    let decrease: () -> Void
    let increase: () -> Void
    var body: some View {
        HStack(spacing: 4) {
            Button("−", action: decrease).buttonStyle(.plain)
            VStack(spacing: 2) { Text(title).font(.system(size: 9, weight: .semibold)).foregroundStyle(Color.white); Text(value).font(.system(size: TypeScale.body, design: .monospaced)).foregroundStyle(.white) }
            Button("+", action: increase).buttonStyle(.plain)
        }
        .padding(.horizontal, 7).frame(height: 40)
        .background(Palette.uiCard).clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private struct MonitorControlDeck: View {
    @ObservedObject var model: CameraModel
    @State private var showLUTImporter = false
    @State private var videoShutterMode = "angle"

    private var isoOptions: [Int] {
        SupportedCamera.isoOptions(for: model.cameraName)
    }
    private let apertureOptions = [1.4, 2.0, 2.8, 4.0, 5.6, 8.0, 11.0, 16.0, 22.0]
    private let frameRateOptions = [24.0, 25.0, 30.0, 50.0, 60.0]
    private let shutterAngleOptions = [45.0, 90.0, 144.0, 172.8, 180.0, 270.0, 360.0]

    /// 恒深面上的下拉控件：系统 popup 跟随窗口浅色外观会渲染黑字，
    /// 用 Menu 自绘，label 白字深底，与 fig1 恒深面一致。
    private func deckMenuPicker<T: Hashable>(
        current: T,
        options: [T],
        display: @escaping (T) -> String,
        apply: @escaping (T) -> Void,
        disabled: Bool = false
    ) -> some View {
        Menu {
            ForEach(options, id: \.self) { option in
                Button {
                    apply(option)
                } label: {
                    Text(display(option))
                }
            }
        } label: {
            HStack(spacing: 6) {
                Text(display(current))
                    .font(.system(size: TypeScale.body))
                    .foregroundStyle(disabled ? Color.white.opacity(0.55) : Color.white) // v1.5.7 issue 655a0a14: 禁用态低透明白、激活态纯白
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .semibold)) // 图标尺寸，不受 TypeScale 约束
                    .foregroundStyle(Color.white) // v1.5.7 issue 655a0a14: 视频页下拉箭头改纯白
            }
            .padding(.horizontal, 10)
            .frame(height: 30)
            .background(Palette.uiSecondary, in: RoundedRectangle(cornerRadius: 7))
        }
        .menuStyle(.borderlessButton)
        .disabled(disabled)
    }

    /// P/S/A/M 模式短标签：嵌套三元表达式提取为方法，
    /// 避免巨型 body 内联推断触发编译器超时。
    private func exposureModeLabel(_ mode: String) -> String {
        switch mode {
        case "program": return "P"
        case "shutterPriority": return "S"
        case "aperturePriority": return "A"
        default: return "M"
        }
    }

    /// 快门表示短标签：角度/速度 二选一文字。
    private func shutterModeLabel(_ mode: String) -> String {
        mode == "angle" ? "快门角度" : "快门速度"
    }

    /// 快门表示切换（角度/速度）胶囊按钮组。
    @ViewBuilder
    private var shutterModePicker: some View {
        HStack(spacing: 6) {
            ForEach(["angle", "speed"], id: \.self) { mode in
                Button {
                    videoShutterMode = mode
                } label: {
                    Text(shutterModeLabel(mode))
                        .font(.system(size: TypeScale.body, weight: .semibold))
                        .foregroundStyle(Color.white) // v1.5.7 issue 655a0a14: 黄绿底激活钮黑字改白字
                        .padding(.horizontal, 12)
                        .frame(height: 30)
                        .background(
                            videoShutterMode == mode ? Palette.uiAccent : Palette.uiSecondary,
                            in: Capsule()
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    /// 快门速度/角度选择：包在独立 @ViewBuilder 里以缩短 body 的
    /// 类型推断链（该闭包含三元表达式，混入巨型 body 会触发编译器超时）。
    @ViewBuilder
    private var shutterSection: some View {
        if videoShutterMode == "angle" {
            deckMenuPicker(
                current: model.videoShutterAngle,
                options: shutterAngleOptions,
                display: { $0.formatted() + "°" },
                apply: { model.setVideoShutterAngle($0) }
            )
        } else {
            let speedOptions: [Double] = [
                1.0 / 8000.0, 1.0 / 4000.0,
                1.0 / 2000.0, 1.0 / 1000.0,
                1.0 / 500.0, 1.0 / 250.0,
                1.0 / 125.0, 1.0 / 60.0,
                1.0 / 30.0, 1.0 / 15.0,
                1.0 / 8.0, 1.0 / 4.0,
                1.0 / 2.0, 1.0
            ]
            let speedDisplay: (Double) -> String = { value in
                value < 1
                    ? "1/\(Int((1 / value).rounded())) s"
                    : String(format: "%.1f s", value)
            }
            deckMenuPicker(
                current: model.shutter,
                options: speedOptions,
                display: speedDisplay,
                apply: { model.applyParameter("videoExposureTime", value: $0, label: "快门速度") }
            )
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 14) {
                Text("视频曝光三要素")
                    .font(.system(size: TypeScale.title, weight: .bold))
                    .foregroundStyle(.white)
                Text("优先使用快门角度；应用会按当前帧率换算为曝光时间并写入相机。")
                    .font(.system(size: TypeScale.body))
                    .foregroundStyle(Color.white) // v1.5.7 issue 655a0a14: 视频页说明文字改纯白

                HStack(spacing: 6) {
                    ForEach(["program", "shutterPriority", "aperturePriority", "manual"], id: \.self) { mode in
                        Button {
                            model.exposureMode = mode
                            model.applyParameter("exposureMode", value: mode, label: "拍摄模式")
                        } label: {
                            Text(exposureModeLabel(mode))
                                .font(.system(size: TypeScale.body, weight: .semibold))
                                .foregroundStyle(Color.white) // v1.5.7 issue 655a0a14: 黄绿底激活钮黑字改白字
                                .frame(width: 34, height: 30)
                                .background(
                                    model.exposureMode == mode ? Palette.uiAccent : Palette.uiSecondary,
                                    in: Capsule()
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }

                deckMenuPicker(
                    current: model.videoFrameRate,
                    options: frameRateOptions,
                    display: { "\(Int($0)) fps" },
                    apply: { model.setVideoFrameRate($0) }
                )

                shutterModePicker
                shutterSection
                .disabled(
                    model.connected
                        && !model.canAdjustExposureParameter("videoExposureTime")
                )

                deckMenuPicker(
                    current: model.monitorVideoCodec,
                    options: model.availableVideoCodecs,
                    display: { $0.label },
                    apply: { model.setMonitorVideoCodec($0) },
                    disabled: !model.connected || model.parameterWritable["videoCodec"] == false
                )

                deckMenuPicker(
                    current: model.monitorVideoLog,
                    options: model.availableVideoLogs,
                    display: { $0.label },
                    apply: { model.setMonitorVideoLog($0) },
                    disabled: !model.connected
                )

                Text(
                    model.cameraVendor == "Canon"
                        ? "显示 RAW、XF-HEVC S 与 XF-AVC S 官方规格；机身未报告可写格式属性时请在相机菜单中选择。Canon Log 会在固件开放配置项时写入。"
                        : "录制规格与 Log / Picture Profile 会按连接相机品牌写入；不支持的组合由机身明确拒绝。"
                )
                .font(.system(size: TypeScale.body))
                .foregroundStyle(Color.white) // v1.5.7 issue 655a0a14: 视频页说明文字改纯白

                deckMenuPicker(
                    current: model.aperture,
                    options: apertureOptions,
                    display: { (v: Double) in String(format: "F%.1f", v) },
                    apply: { value in
                        model.aperture = value
                        model.applyParameter("aperture", value: value, label: "光圈")
                    },
                    disabled: !model.connected
                        || !model.canAdjustExposureParameter("aperture")
                )

                deckMenuPicker(
                    current: model.iso,
                    options: isoOptions,
                    display: { "\($0)" },
                    apply: { value in
                        model.iso = value
                        model.applyParameter("iso", value: value, label: "ISO感光度")
                    },
                    disabled: !model.connected
                )

                deckMenuPicker(
                    current: model.whiteBalance,
                    options: ["continuous", "manual"],
                    display: { $0 == "continuous" ? "自动" : "手动预设" },
                    apply: { value in
                        model.whiteBalance = value
                        model.applyParameter(
                            "whiteBalanceMode",
                            value: value,
                            label: "白平衡"
                        )
                    },
                    disabled: !model.connected
                )

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("曝光补偿")
                            .foregroundStyle(.white)
                        Spacer()
                        Text("\(model.compensation, specifier: "%+.1f") EV")
                            .font(.system(size: TypeScale.body, design: .monospaced))
                            .foregroundStyle(Color.white) // v1.5.7 issue 655a0a14: 激活态读数不再用 uiAccent
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
                    .font(.system(size: TypeScale.title, weight: .bold))
                    .foregroundStyle(.white)

                deckMenuPicker(
                    current: model.monitorVideoProfile,
                    options: MonitorVideoProfile.allCases,
                    display: { $0.label },
                    apply: { model.setMonitorVideoProfile($0) }
                )

                HStack(spacing: 6) {
                    Text("实时取景格式")
                        .foregroundStyle(Color.white) // v1.5.7 issue 655a0a14: 视频页标签改纯白
                    Spacer()
                    Text("JPEG（相机输出）")
                        .font(.system(size: TypeScale.body))
                        .foregroundStyle(Color.white.opacity(0.55)) // v1.5.7 issue 655a0a14: 禁用态低透明白（仍白）
                }

                Toggle(
                    isOn: Binding(
                        get: { model.externalRecordToDevice },
                        set: { model.setExternalRecordToDevice($0) }
                    )
                ) {
                    Text("外录到当前智能设备")
                        .foregroundStyle(.white)
                }
                .disabled(model.videoRecording)

                Text("外录使用实时取景生成无声 Motion‑JPEG AVI，可与机身录制并行；照片始终直接写入当前设备。")
                    .font(.system(size: TypeScale.body))
                    .foregroundStyle(Color.white) // v1.5.7 issue 655a0a14: 视频页说明文字改纯白
                    .fixedSize(horizontal: false, vertical: true)

                Text("Nikon PTP 返回 JPEG 实时取景帧。监看显示尺寸仅处理本地预览，不会改变机身的视频文件类型或画面尺寸。")
                    .font(.system(size: TypeScale.body))
                    .foregroundStyle(Color.white) // v1.5.7 issue 655a0a14: 视频页说明文字改纯白
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(18)

            Divider()

            VStack(alignment: .leading, spacing: 14) {
                Text("监看辅助")
                    .font(.system(size: TypeScale.title, weight: .bold))
                    .foregroundStyle(.white)

                Toggle(
                    isOn: Binding(
                        get: { model.zebraEnabled },
                        set: { model.setZebraEnabled($0) }
                    )
                ) {
                    Text("加亮显示条纹图案")
                        .foregroundStyle(.white)
                }
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
                        .font(.system(size: TypeScale.body, design: .monospaced))
                        .foregroundStyle(Color.white) // v1.5.7 issue 655a0a14: 视频页读数改纯白
                        .frame(width: 58)
                }
                .disabled(!model.zebraEnabled)

                Toggle(
                    isOn: Binding(
                        get: { model.focusPeakingEnabled },
                        set: { model.setFocusPeakingEnabled($0) }
                    )
                ) {
                    Text("峰值对焦")
                        .foregroundStyle(.white)
                }
                .toggleStyle(.switch)

                Toggle(
                    isOn: Binding(
                        get: { model.falseColorEnabled },
                        set: { model.setFalseColorEnabled($0) }
                    )
                ) {
                    Text("假色曝光")
                        .foregroundStyle(.white)
                }
                .toggleStyle(.switch)

                VStack(alignment: .leading, spacing: 8) {
                    MacProfessionalScopeBoard(
                        red: model.redHistogram,
                        green: model.greenHistogram,
                        blue: model.blueHistogram
                    )
                    .frame(height: 210)
                    Text("峰值覆盖 · \(model.peakingCoverage)%")
                        .font(.system(size: TypeScale.caption, design: .monospaced))
                        .foregroundStyle(Color.white) // v1.5.7 issue 655a0a14: 视频页读数改纯白
                }
                .padding(8)
                .background(Color.black)
                .clipShape(RoundedRectangle(cornerRadius: 8))

                Toggle(
                    isOn: Binding(
                        get: { model.lutEnabled },
                        set: { model.setLUTEnabled($0) }
                    )
                ) {
                    Text("应用本地 LUT")
                        .foregroundStyle(.white)
                }
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
                    .font(.system(size: TypeScale.body))
                    .foregroundStyle(Color.white) // v1.5.7 issue 655a0a14: 视频页说明文字改纯白
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(18)
        }
        .background(Palette.uiCard)
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

}

private struct MacScopeTrace {
    let value: String
    let color: Color
}

private struct MacScopePlot: View {
    let label: String
    let traces: [MacScopeTrace]
    var parade = false

    var body: some View {
        VStack(spacing: 2) {
            Canvas { context, size in
                for (index, trace) in traces.enumerated() {
                    drawTrace(
                        context: &context,
                        size: size,
                        value: trace.value,
                        color: trace.color,
                        segment: parade ? index : nil,
                        seed: index + 1
                    )
                }
                drawGrid(context: &context, size: size)
            }
            .background(Palette.scopeBg)

            if parade {
                HStack(spacing: 0) {
                    Text("R").frame(maxWidth: .infinity)
                    Text("G").frame(maxWidth: .infinity)
                    Text("B").frame(maxWidth: .infinity)
                }
                .font(.system(size: TypeScale.caption, weight: .medium, design: .monospaced))
                .foregroundStyle(Palette.whiteMid)
                .frame(height: 11)
            } else {
                Text(label)
                    .font(.system(size: TypeScale.caption, weight: .medium, design: .monospaced))
                    .foregroundStyle(Palette.whiteMid)
                    .frame(maxWidth: .infinity)
                    .frame(height: 11)
            }
        }
        .background(Color.black)
    }

    private func drawGrid(context: inout GraphicsContext, size: CGSize) {
        let bounds = CGRect(
            x: 0.75,
            y: 0.75,
            width: max(1, size.width - 1.5),
            height: max(1, size.height - 1.5)
        )
        var guides = Path()
        for fraction in [0.25, 0.5, 0.75] {
            let y = bounds.minY + bounds.height * fraction
            guides.move(to: CGPoint(x: bounds.minX, y: y))
            guides.addLine(to: CGPoint(x: bounds.maxX, y: y))
        }
        if parade {
            for fraction in [1.0 / 3.0, 2.0 / 3.0] {
                let x = bounds.minX + bounds.width * fraction
                guides.move(to: CGPoint(x: x, y: bounds.minY))
                guides.addLine(to: CGPoint(x: x, y: bounds.maxY))
            }
        }
        context.stroke(guides, with: .color(Palette.whiteFaint), lineWidth: 0.72)
        var frame = Path()
        frame.addRect(bounds)
        context.stroke(frame, with: .color(Palette.whiteHi), lineWidth: 1.1)
    }

    private func drawTrace(
        context: inout GraphicsContext,
        size: CGSize,
        value: String,
        color: Color,
        segment: Int?,
        seed: Int
    ) {
        let horizontalInset = max(2, size.width * 0.009)
        let startX: CGFloat
        let width: CGFloat
        if let segment {
            let segmentWidth = size.width / 3
            startX = segmentWidth * CGFloat(segment) + horizontalInset
            width = max(1, segmentWidth - horizontalInset * 2)
        } else {
            startX = horizontalInset
            width = max(1, size.width - horizontalInset * 2)
        }
        let topInset = max(3, size.height * 0.035)
        let bottom = size.height - max(3, size.height * 0.035)
        let plotHeight = max(1, bottom - topInset)
        if let density = MacScopeLevels.density(value) {
            drawDensity(
                context: &context,
                density: density,
                color: color,
                startX: startX,
                width: width,
                top: topInset,
                height: plotHeight
            )
            return
        }
        let levels = MacScopeLevels.parse(value)
        guard levels.count > 1 else { return }
        let columns = min(220, max(56, Int(width / 1.35)))
        var envelope = Path()
        var haze = Path()
        var cloud = Path()
        var sparks = Path()

        for column in 0..<columns {
            let progress = CGFloat(column) / CGFloat(max(1, columns - 1))
            let sample = progress * CGFloat(levels.count - 1)
            let lower = min(levels.count - 1, Int(sample.rounded(.down)))
            let upper = min(levels.count - 1, lower + 1)
            let blend = sample - CGFloat(lower)
            let interpolated = levels[lower] + (levels[upper] - levels[lower]) * blend
            let ripple = (scopeNoise(column, 0, seed) - 0.5) * 0.075
            let level = min(1, max(0.04, interpolated + ripple))
            let x = startX + width * progress
            let envelopeY = topInset + plotHeight * (1 - (0.12 + level * 0.82))

            if column == 0 { envelope.move(to: CGPoint(x: x, y: envelopeY)) }
            else { envelope.addLine(to: CGPoint(x: x, y: envelopeY)) }

            let particles = 18 + Int(level * 28)
            for particle in 0..<particles {
                let distribution = scopeNoise(column, particle + 1, seed * 7)
                let depth = particle % 3 == 0
                    ? pow(distribution, 2.25)
                    : pow(distribution, 0.72)
                let jitterX = (scopeNoise(column, particle + 11, seed * 13) - 0.5) * 2.2
                let jitterY = (scopeNoise(column, particle + 29, seed * 17) - 0.5) * 2.4
                let y = min(bottom, max(topInset, envelopeY + (bottom - envelopeY) * depth + jitterY))
                let bright = (column + particle + seed) % 5 == 0
                let dot = bright ? CGFloat(1.12) : CGFloat(0.72)
                let rect = CGRect(x: x + jitterX - dot / 2, y: y - dot / 2, width: dot, height: dot)
                haze.addEllipse(in: rect.insetBy(dx: -0.55, dy: -0.55))
                if bright { sparks.addEllipse(in: rect) }
                else { cloud.addEllipse(in: rect) }
            }
        }

        context.drawLayer { layer in
            layer.blendMode = .plusLighter
            layer.fill(haze, with: .color(color.opacity(0.07)))
            layer.fill(cloud, with: .color(color.opacity(0.30)))
            layer.fill(sparks, with: .color(color.opacity(0.64)))
            layer.stroke(envelope, with: .color(color.opacity(0.14)), lineWidth: 3.2)
            layer.stroke(envelope, with: .color(color.opacity(0.62)), lineWidth: 0.72)
        }
    }

    private func drawDensity(
        context: inout GraphicsContext,
        density: MacScopeDensity,
        color: Color,
        startX: CGFloat,
        width: CGFloat,
        top: CGFloat,
        height: CGFloat
    ) {
        let cellWidth = width / CGFloat(density.columns)
        let cellHeight = height / CGFloat(density.rows)
        let dot = max(0.62, min(1.5, cellWidth * 0.72))
        var haze = Path()
        var cloud = Path()
        var sparks = Path()
        var envelope = Path()
        for column in 0..<density.columns {
            var firstRow: Int?
            for row in 0..<density.rows {
                let level = density.values[row * density.columns + column]
                guard level > 0 else { continue }
                if firstRow == nil { firstRow = row }
                let x = startX + (CGFloat(column) + 0.5) * cellWidth
                let y = top + (CGFloat(row) + 0.5) * cellHeight
                let intensity = CGFloat(level) / 15
                haze.addEllipse(in: CGRect(x: x - dot, y: y - dot, width: dot * 2, height: dot * 2))
                let core = dot * (0.46 + intensity * 0.38)
                if level >= 9 {
                    sparks.addEllipse(in: CGRect(x: x - core, y: y - core, width: core * 2, height: core * 2))
                } else if level >= 3 {
                    cloud.addEllipse(in: CGRect(x: x - core, y: y - core, width: core * 2, height: core * 2))
                }
            }
            if let row = firstRow {
                let point = CGPoint(
                    x: startX + (CGFloat(column) + 0.5) * cellWidth,
                    y: top + (CGFloat(row) + 0.5) * cellHeight
                )
                if envelope.isEmpty { envelope.move(to: point) }
                else { envelope.addLine(to: point) }
            }
        }
        context.drawLayer { layer in
            layer.blendMode = .plusLighter
            layer.fill(haze, with: .color(color.opacity(0.10)))
            layer.fill(cloud, with: .color(color.opacity(0.35)))
            layer.fill(sparks, with: .color(color.opacity(0.78)))
            layer.stroke(envelope, with: .color(color.opacity(0.22)), lineWidth: 2.8)
            layer.stroke(envelope, with: .color(color.opacity(0.72)), lineWidth: 0.68)
        }
    }

    private func scopeNoise(_ column: Int, _ particle: Int, _ seed: Int) -> CGFloat {
        let value = sin(Double((column + 1) * 17 + (particle + 3) * 31 + seed * 47) * 12.9898) * 43_758.5453
        return CGFloat(value - floor(value))
    }
}

private struct MacAudioScopePlot: View {
    let label: String

    var body: some View {
        VStack(spacing: 2) {
            Canvas { context, size in
                var guides = Path()
                for fraction in [0.25, 0.5, 0.75] {
                    let y = size.height * fraction
                    guides.move(to: CGPoint(x: 0, y: y))
                    guides.addLine(to: CGPoint(x: size.width, y: y))
                }
                var baseline = Path()
                baseline.move(to: CGPoint(x: 4, y: size.height / 2))
                baseline.addLine(to: CGPoint(x: size.width - 4, y: size.height / 2))
                let cyan = Palette.scopeAudio
                context.stroke(baseline, with: .color(cyan.opacity(0.22)), lineWidth: 5)
                context.stroke(baseline, with: .color(cyan.opacity(0.92)), lineWidth: 1)
                context.stroke(guides, with: .color(Palette.whiteFaint), lineWidth: 0.72)
                var frame = Path()
                frame.addRect(CGRect(x: 0.75, y: 0.75, width: max(1, size.width - 1.5), height: max(1, size.height - 1.5)))
                context.stroke(frame, with: .color(Palette.whiteHi), lineWidth: 1.1)
            }
            .background(Palette.scopeBg)
            Text(label)
                .font(.system(size: TypeScale.caption, weight: .semibold, design: .monospaced))
                .foregroundStyle(Palette.whiteMid)
                .frame(maxWidth: .infinity)
                .frame(height: 11)
        }
        .background(Color.black)
    }
}

private struct MacScopeDensity {
    let columns: Int
    let rows: Int
    let values: [Int]
}

private enum MacScopeLevels {
    private static let bars = Array("▁▂▃▄▅▆▇█")

    static func parse(_ value: String) -> [CGFloat] {
        let parsed = Array(value).compactMap { character -> CGFloat? in
            guard let index = bars.firstIndex(of: character) else { return nil }
            return CGFloat(index) / CGFloat(max(1, bars.count - 1))
        }
        return parsed.count > 1 ? parsed : [0.08, 0.08]
    }

    static func density(_ value: String) -> MacScopeDensity? {
        guard value.hasPrefix("S"),
              let colon = value.firstIndex(of: ":") else { return nil }
        let dimensions = value[value.index(after: value.startIndex)..<colon]
            .split(separator: "x", maxSplits: 1)
        guard dimensions.count == 2,
              let columns = Int(dimensions[0]),
              let rows = Int(dimensions[1]) else { return nil }
        let payload = value[value.index(after: colon)...]
        guard payload.count == columns * rows else { return nil }
        let values = payload.compactMap { Int(String($0), radix: 16) }
        guard values.count == columns * rows else { return nil }
        return MacScopeDensity(columns: columns, rows: rows, values: values)
    }
}

private struct MacProfessionalScopeBoard: View {
    let red: String
    let green: String
    let blue: String

    var body: some View {
        VStack(spacing: 1) {
            MacScopePlot(
                label: "RGB",
                traces: [
                    MacScopeTrace(value: red, color: Palette.scopeR),
                    MacScopeTrace(value: green, color: Palette.scopeG),
                    MacScopeTrace(value: blue, color: Palette.scopeB)
                ],
                parade: false
            )
        }
        .padding(4)
        .background(Color.black)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("专业波形图，RGB 三通道叠加")
    }
}

private struct CaptureSessionPanel: View {
    @ObservedObject var workflow: CaptureWorkflow
    @State private var expanded = false
    @State private var name = "未命名会话"
    @State private var namingTemplate = "{session}_{date}_{counter}"
    @State private var creator = ""
    @State private var rights = ""
    @State private var rating = 0
    @State private var dualBackupEnabled = true

    var body: some View {
        DisclosureGroup("拍前会话与交付", isExpanded: $expanded) {
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
                    .font(.system(size: TypeScale.body))
                    .foregroundStyle(Palette.uiLabel)
                HStack {
                    RuntimeLocalizedText(workflow.status)
                        .font(.system(size: TypeScale.body, design: .monospaced))
                        .foregroundStyle(Palette.uiLabel)
                    Spacer()
                    Button(workflow.isActive ? "结束会话" : "开始会话") {
                        toggleSession()
                    }
                    .buttonStyle(NativeButtonStyle(primary: true))
                }
            }
            .padding(.top, 10)
        }
        .font(.system(size: TypeScale.title, weight: .bold))
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

private struct MacLibraryBranch: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var children: [MacLibraryBranch]

    init(id: UUID = UUID(), name: String, children: [MacLibraryBranch] = []) {
        self.id = id
        self.name = name
        self.children = children
    }
}

@MainActor
private final class MacLibraryBranchStore: ObservableObject {
    @Published private(set) var branches: [MacLibraryBranch] = []
    @Published private(set) var expandedIDs: Set<UUID> = []
    @Published private(set) var assignments: [String: UUID] = [:]

    private static let storageKey = "zenche.library.user-branches"
    private static let assignmentStorageKey =
        "zenche.library.file-branch-assignments"

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.storageKey),
           let saved = try? JSONDecoder().decode(
            [MacLibraryBranch].self,
            from: data
           ) {
            branches = saved
            expandedIDs = Set(saved.map(\.id))
        }
        if let data = UserDefaults.standard.data(
            forKey: Self.assignmentStorageKey
        ),
        let saved = try? JSONDecoder().decode(
            [String: UUID].self,
            from: data
        ) {
            assignments = saved
        }
    }

    func addBranch(named rawName: String, parentID: UUID?) {
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        let branch = MacLibraryBranch(name: name)
        if let parentID {
            var updated = branches
            guard insert(branch, under: parentID, in: &updated) else {
                return
            }
            branches = updated
            expandedIDs.insert(parentID)
        } else {
            branches.append(branch)
        }
        expandedIDs.insert(branch.id)
        persist()
    }

    func toggle(_ id: UUID) {
        if expandedIDs.contains(id) {
            expandedIDs.remove(id)
        } else {
            expandedIDs.insert(id)
        }
    }

    func branchID(for photoPath: String) -> UUID? {
        assignments[photoPath]
    }

    func assign(_ photoPath: String, to branchID: UUID?) {
        if let branchID {
            assignments[photoPath] = branchID
            expandedIDs.insert(branchID)
        } else {
            assignments.removeValue(forKey: photoPath)
        }
        persistAssignments()
    }

    func deleteBranch(_ id: UUID) {
        var updated = branches
        guard let removed = removeBranch(id, from: &updated) else {
            return
        }
        let removedIDs = branchIDs(in: removed)
        branches = updated
        expandedIDs.subtract(removedIDs)
        assignments = assignments.filter {
            !removedIDs.contains($0.value)
        }
        persist()
        persistAssignments()
    }

    private func insert(
        _ branch: MacLibraryBranch,
        under parentID: UUID,
        in nodes: inout [MacLibraryBranch]
    ) -> Bool {
        for index in nodes.indices {
            if nodes[index].id == parentID {
                nodes[index].children.append(branch)
                return true
            }
            if insert(branch, under: parentID, in: &nodes[index].children) {
                return true
            }
        }
        return false
    }

    private func removeBranch(
        _ id: UUID,
        from nodes: inout [MacLibraryBranch]
    ) -> MacLibraryBranch? {
        if let index = nodes.firstIndex(where: { $0.id == id }) {
            return nodes.remove(at: index)
        }
        for index in nodes.indices {
            if let removed = removeBranch(id, from: &nodes[index].children) {
                return removed
            }
        }
        return nil
    }

    private func branchIDs(in branch: MacLibraryBranch) -> Set<UUID> {
        branch.children.reduce(into: Set([branch.id])) { ids, child in
            ids.formUnion(branchIDs(in: child))
        }
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(branches) else { return }
        UserDefaults.standard.set(data, forKey: Self.storageKey)
    }

    private func persistAssignments() {
        guard let data = try? JSONEncoder().encode(assignments) else { return }
        UserDefaults.standard.set(data, forKey: Self.assignmentStorageKey)
    }
}

private struct MacLibraryBranchRow: View {
    @ObservedObject var store: MacLibraryBranchStore
    let branch: MacLibraryBranch
    let depth: Int
    let photos: [PhotoRecord]
    let selectedPhoto: PhotoRecord?
    let addChild: (MacLibraryBranch) -> Void
    let deleteBranch: (MacLibraryBranch) -> Void
    let selectPhoto: (PhotoRecord) -> Void
    let previewPhoto: (PhotoRecord) -> Void
    @State private var isDropTarget = false

    private var assignedPhotos: [PhotoRecord] {
        photos.filter {
            store.branchID(for: $0.url.path) == branch.id
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Button {
                    store.toggle(branch.id)
                } label: {
                    HStack(spacing: 9) {
                        Image(
                            systemName: store.expandedIDs.contains(branch.id)
                                ? "chevron.down"
                                : "chevron.right"
                        )
                        .frame(width: 24)
                        Label(branch.name, systemImage: "folder")
                            .font(.system(size: TypeScale.emphasis, weight: .semibold))
                            .lineLimit(1)
                        Spacer()
                        Text("\(assignedPhotos.count) 文件")
                            .font(.system(size: TypeScale.caption, design: .monospaced))
                            .foregroundStyle(Palette.muted)
                    }
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(
                    store.expandedIDs.contains(branch.id)
                        ? "收起 \(branch.name)"
                        : "展开 \(branch.name)"
                )
                Button {
                    addChild(branch)
                } label: {
                    Image(systemName: "folder.badge.plus")
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
                .help("在 \(branch.name) 下新建分支")
                Button(role: .destructive) {
                    deleteBranch(branch)
                } label: {
                    Image(systemName: "trash")
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
                .help("删除分支 \(branch.name)")
            }
            .padding(.leading, CGFloat(depth) * 16)
            .padding(.horizontal, 8)
            .frame(minHeight: 44)
            .background(
                isDropTarget
                    ? Palette.cobaltSoft
                    : depth == 0
                        ? Palette.paperSecondary
                        : Palette.surface,
                in: RoundedRectangle(cornerRadius: 8)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(
                        isDropTarget ? Palette.cobalt : Palette.rule,
                        lineWidth: isDropTarget ? 2 : 1
                    )
            }
            .dropDestination(for: String.self) { paths, _ in
                guard !paths.isEmpty else { return false }
                paths.forEach { store.assign($0, to: branch.id) }
                return true
            } isTargeted: {
                isDropTarget = $0
            }

            if store.expandedIDs.contains(branch.id) {
                ForEach(assignedPhotos) { photo in
                    MacLibraryBranchFileRow(
                        photo: photo,
                        selected: selectedPhoto == photo,
                        depth: depth + 1,
                        selectPhoto: selectPhoto,
                        previewPhoto: previewPhoto
                    )
                }
                if assignedPhotos.isEmpty && branch.children.isEmpty {
                    Text("拖动文件到这里")
                        .font(.system(size: TypeScale.caption))
                        .foregroundStyle(Palette.muted)
                        .padding(.leading, CGFloat(depth + 1) * 16 + 42)
                        .frame(height: 28)
                }
                ForEach(branch.children) { child in
                    MacLibraryBranchRow(
                        store: store,
                        branch: child,
                        depth: depth + 1,
                        photos: photos,
                        selectedPhoto: selectedPhoto,
                        addChild: addChild,
                        deleteBranch: deleteBranch,
                        selectPhoto: selectPhoto,
                        previewPhoto: previewPhoto
                    )
                }
            }
        }
    }
}

private struct MacLibraryBranchFileRow: View {
    let photo: PhotoRecord
    let selected: Bool
    let depth: Int
    let selectPhoto: (PhotoRecord) -> Void
    let previewPhoto: (PhotoRecord) -> Void

    private var thumbnail: NSImage? {
        guard !photo.isVideo else { return nil }
        return NSImage(contentsOf: photo.url)
    }

    var body: some View {
        HStack(spacing: 9) {
            Group {
                if photo.isVideo {
                    ZStack {
                        Palette.graphite
                        Image(systemName: "play.fill")
                            .foregroundStyle(.white)
                    }
                } else if let thumbnail {
                    Image(nsImage: thumbnail)
                        .resizable()
                        .scaledToFill()
                } else {
                    ZStack {
                        Palette.paperSecondary
                        Image(systemName: "photo")
                            .foregroundStyle(Palette.cobalt)
                    }
                }
            }
            .frame(width: 72, height: 48)
            .clipShape(RoundedRectangle(cornerRadius: 7))
            Text(photo.name)
                .font(.system(size: TypeScale.caption, design: .monospaced))
                .lineLimit(1)
            Spacer()
            Image(systemName: "line.3.horizontal")
                .foregroundStyle(Palette.muted)
        }
        .padding(.leading, CGFloat(depth) * 16 + 22)
        .padding(.trailing, 10)
        .frame(minHeight: 56)
        .background(
            selected ? Palette.cobaltSoft : Palette.surface,
            in: RoundedRectangle(cornerRadius: 8)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(selected ? Palette.cobalt : Palette.rule)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            selectPhoto(photo)
        }
        .onTapGesture(count: 2) {
            selectPhoto(photo)
            previewPhoto(photo)
        }
        .draggable(photo.url.path) {
            Label(
                photo.name,
                systemImage: "arrow.up.and.down.and.arrow.left.and.right"
            )
            .font(.system(size: TypeScale.body, weight: .semibold))
            .padding(10)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 9))
        }
        .help("拖动到其他分支")
    }
}

private struct CameraStorageMacRow: View {
    @ObservedObject var model: CameraModel
    let item: CameraStorageItem
    @Binding var selected: Bool
    @State private var thumbnail: NSImage?

    var body: some View {
        HStack(spacing: 12) {
            Toggle("", isOn: $selected)
                .labelsHidden()
                .toggleStyle(.checkbox)
                .disabled(item.isProtected)
                .help(item.isProtected ? "受保护文件不能删除" : "选择文件")
            Group {
                if let thumbnail {
                    Image(nsImage: thumbnail)
                        .resizable()
                        .scaledToFill()
                } else {
                    Image(systemName: item.isVideo ? "video" : "photo")
                        .font(.system(size: TypeScale.title, weight: .medium))
                        .foregroundStyle(Palette.muted)
                }
            }
            .frame(width: 58, height: 44)
            .background(Palette.surface, in: RoundedRectangle(cornerRadius: 8))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(item.filename)
                        .font(.system(size: TypeScale.emphasis, weight: .semibold))
                        .lineLimit(1)
                    if item.isProtected {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 10)) // 图标尺寸，不受 TypeScale 约束
                            .foregroundStyle(Palette.muted)
                    }
                }
                Text(
                    "\(ByteCountFormatter.string(fromByteCount: Int64(clamping: item.sizeBytes), countStyle: .file)) · \(item.capturedAt)"
                )
                .font(.system(size: TypeScale.caption))
                .foregroundStyle(Palette.muted)
            }
            Spacer(minLength: 8)
        }
        .padding(.vertical, 7)
        .contentShape(Rectangle())
        .task(id: item.handle) {
            guard !item.isVideo else { return }
            if let data = try? await model.cameraStorageThumbnail(handle: item.handle) {
                thumbnail = NSImage(data: data)
            }
        }
    }
}

private struct LibraryView: View {
    @ObservedObject var model: CameraModel
    @StateObject private var branchStore = MacLibraryBranchStore()
    @State private var confirmDelete = false
    @State private var showCloudImporter = false
    @State private var showCloudGuide = false
    @State private var showBranchCreator = false
    @State private var branchDraft = ""
    @State private var branchParentID: UUID?
    @State private var branchParentName = "帧澈 ZENCHE 文件库"
    @State private var branchPendingDeletion: MacLibraryBranch?
    @State private var largePhoto: PhotoRecord?
    @State private var systemLargePhoto: SystemMacAlbumItem?
    @State private var systemAlbum: [SystemMacAlbumItem] = []
    @State private var systemAlbumStatus = "正在读取系统相册…"
    @State private var systemExpanded = true
    @State private var systemPhotosExpanded = true
    @State private var systemVideosExpanded = true
    @State private var uncategorizedExpanded = true
    @State private var localPhotosExpanded = true
    @State private var localVideosExpanded = true
    @State private var wirelessExpanded = true
    @State private var unclassifiedDropTargeted = false
    @State private var cameraStorageExpanded = false
    @State private var cameraStorageSnapshot = CameraStorageSnapshot.empty
    @State private var cameraStorageSelected: Set<UInt32> = []
    @State private var cameraStorageStatus = "连接相机后可查看存储卡中的照片和视频。"
    @State private var cameraStorageBusy = false
    @State private var confirmCameraStorageDelete = false

    private let columns = [
        GridItem(.adaptive(minimum: 180, maximum: 260), spacing: 16)
    ]

    var body: some View {
        HSplitView {
            VStack(spacing: 0) {
                HStack {
                WorkspaceHeading(
                    title: "分支文件库",
                    subtitle: "\(model.photos.count) 个本地文件 · 拖动整理，不改动原文件"
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
                    branchWorkspace
                    cameraStorageWorkspace
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
                    .font(.system(size: TypeScale.title, weight: .bold))

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
                .font(.system(size: TypeScale.title, weight: .bold))
                .padding(18)
            }
            .frame(minWidth: 380, idealWidth: 440, maxWidth: 520)
        }
        .alert("将照片移到废纸篓？", isPresented: $confirmDelete) {
            Button("取消", role: .cancel) {}
            Button("移到废纸篓", role: .destructive) {
                if let path = model.selectedPhoto?.url.path {
                    branchStore.assign(path, to: nil)
                }
                model.deleteSelectedPhoto()
            }
        } message: {
            RuntimeLocalizedText(model.selectedPhoto?.name ?? "")
        }
        .alert("从相机永久删除？", isPresented: $confirmCameraStorageDelete) {
            Button("取消", role: .cancel) {}
            Button("永久删除", role: .destructive) {
                Task { await deleteSelectedCameraStorageItems() }
            }
        } message: {
            Text("将删除相机存储卡中选中的 \(cameraStorageSelected.count) 个文件。此操作无法从帧澈 ZENCHE 恢复。")
        }
        .alert("新建分支", isPresented: $showBranchCreator) {
            TextField("分支名称", text: $branchDraft)
            Button("取消", role: .cancel) {}
            Button("创建") {
                branchStore.addBranch(
                    named: branchDraft,
                    parentID: branchParentID
                )
            }
            .disabled(
                branchDraft.trimmingCharacters(
                    in: .whitespacesAndNewlines
                ).isEmpty
            )
        } message: {
            Text("将在“\(branchParentName)”下创建可继续展开的节点。")
        }
        .confirmationDialog(
            "删除分支？",
            isPresented: Binding(
                get: { branchPendingDeletion != nil },
                set: {
                    if !$0 {
                        branchPendingDeletion = nil
                    }
                }
            )
        ) {
            Button("删除分支", role: .destructive) {
                if let branchPendingDeletion {
                    branchStore.deleteBranch(branchPendingDeletion.id)
                }
                branchPendingDeletion = nil
            }
            Button("取消", role: .cancel) {
                branchPendingDeletion = nil
            }
        } message: {
            Text(
                "将同时删除“\(branchPendingDeletion?.name ?? "")”下的子分支；其中的文件会回到“未分类”，原文件不受影响。"
            )
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
    private var cameraStorageWorkspace: some View {
        DisclosureGroup(
            "相机机内存储 · \(cameraStorageSnapshot.items.count)",
            isExpanded: $cameraStorageExpanded
        ) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 22, weight: .semibold)) // 图标尺寸，不受 TypeScale 约束
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(Palette.cobalt, in: RoundedRectangle(cornerRadius: 12))
                    VStack(alignment: .leading, spacing: 3) {
                        Text(cameraStorageCapacitySummary)
                            .font(.system(size: TypeScale.emphasis, weight: .semibold))
                        Text(cameraStorageStatus)
                            .font(.system(size: TypeScale.caption))
                            .foregroundStyle(Palette.muted)
                            .lineLimit(2)
                    }
                    Spacer()
                    if cameraStorageBusy {
                        ProgressView()
                            .controlSize(.small)
                    }
                    Button("刷新") {
                        Task { await refreshCameraStorage() }
                    }
                    .buttonStyle(NativeButtonStyle())
                    .disabled(cameraStorageBusy || !model.hasAnyCameraConnection)
                }

                HStack(spacing: 8) {
                    Button(cameraStorageSelected.count == selectableCameraStorageItems.count && !cameraStorageSelected.isEmpty ? "取消全选" : "全选") {
                        if cameraStorageSelected.count == selectableCameraStorageItems.count,
                           !cameraStorageSelected.isEmpty {
                            cameraStorageSelected.removeAll()
                        } else {
                            cameraStorageSelected = Set(selectableCameraStorageItems.map(\.handle))
                        }
                    }
                    .buttonStyle(NativeButtonStyle())
                    .disabled(selectableCameraStorageItems.isEmpty || cameraStorageBusy)
                    Button("下载到帧澈 · \(cameraStorageSelected.count)") {
                        Task { await downloadSelectedCameraStorageItems() }
                    }
                    .buttonStyle(NativeButtonStyle(primary: true))
                    .disabled(cameraStorageSelected.isEmpty || cameraStorageBusy)
                    Button("从相机删除") {
                        confirmCameraStorageDelete = true
                    }
                    .buttonStyle(NativeButtonStyle())
                    .disabled(cameraStorageSelected.isEmpty || cameraStorageBusy)
                    Spacer()
                }

                if cameraStorageSnapshot.items.isEmpty {
                    ContentUnavailableView(
                        model.hasAnyCameraConnection ? "没有可管理的文件" : "尚未连接相机",
                        systemImage: "externaldrive",
                        description: Text(cameraStorageStatus)
                    )
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 150)
                } else {
                    LazyVStack(spacing: 0) {
                        ForEach(cameraStorageSnapshot.items) { item in
                            CameraStorageMacRow(
                                model: model,
                                item: item,
                                selected: Binding(
                                    get: { cameraStorageSelected.contains(item.handle) },
                                    set: { selected in
                                        if selected && !item.isProtected {
                                            cameraStorageSelected.insert(item.handle)
                                        } else {
                                            cameraStorageSelected.remove(item.handle)
                                        }
                                    }
                                )
                            )
                            if item.id != cameraStorageSnapshot.items.last?.id {
                                Divider()
                            }
                        }
                    }
                }
            }
            .padding(.top, 12)
        }
        .font(.system(size: TypeScale.title, weight: .bold))
        .onChange(of: cameraStorageExpanded) { expanded in
            if expanded && cameraStorageSnapshot.items.isEmpty {
                Task { await refreshCameraStorage() }
            }
        }
    }

    private var selectableCameraStorageItems: [CameraStorageItem] {
        cameraStorageSnapshot.items.filter { !$0.isProtected }
    }

    private var selectedCameraStorageItems: [CameraStorageItem] {
        cameraStorageSnapshot.items.filter {
            cameraStorageSelected.contains($0.handle) && !$0.isProtected
        }
    }

    private var cameraStorageCapacitySummary: String {
        let snapshot = cameraStorageSnapshot
        guard snapshot.capacityBytes > 0, snapshot.freeBytes > 0 else {
            let size = snapshot.items.reduce(UInt64(0)) { $0 &+ $1.sizeBytes }
            return "已列出 \(snapshot.items.count) 个文件 · \(formatCameraStorageBytes(size))"
        }
        return "可用 \(formatCameraStorageBytes(snapshot.freeBytes)) / \(formatCameraStorageBytes(snapshot.capacityBytes))"
    }

    private func formatCameraStorageBytes(_ bytes: UInt64) -> String {
        ByteCountFormatter.string(
            fromByteCount: Int64(clamping: bytes),
            countStyle: .file
        )
    }

    @MainActor
    private func refreshCameraStorage() async {
        guard !cameraStorageBusy else { return }
        cameraStorageBusy = true
        cameraStorageStatus = "正在读取相机存储卡…"
        defer { cameraStorageBusy = false }
        do {
            cameraStorageSnapshot = try await model.listCameraStorage()
            let available = Set(selectableCameraStorageItems.map(\.handle))
            cameraStorageSelected.formIntersection(available)
            cameraStorageStatus = cameraStorageSnapshot.items.isEmpty
                ? "存储卡中没有可管理的照片或视频。"
                : "文件只在下载后进入帧澈文件库；删除操作会永久改动相机存储卡。"
        } catch {
            cameraStorageSnapshot = .empty
            cameraStorageSelected.removeAll()
            cameraStorageStatus = error.localizedDescription
        }
    }

    @MainActor
    private func downloadSelectedCameraStorageItems() async {
        let items = selectedCameraStorageItems
        guard !items.isEmpty, !cameraStorageBusy else { return }
        cameraStorageBusy = true
        var downloaded = 0
        defer { cameraStorageBusy = false }
        for item in items {
            do {
                cameraStorageStatus = "正在下载 \(downloaded + 1)/\(items.count) · \(item.filename)"
                let data = try await model.cameraStorageObject(handle: item.handle)
                try model.storeCameraStorageObject(data, filename: item.filename)
                downloaded += 1
            } catch {
                model.errorMessage = "下载 \(item.filename) 失败：\(error.localizedDescription)"
                break
            }
        }
        cameraStorageStatus = "已下载 \(downloaded) 个文件到帧澈文件库。"
    }

    @MainActor
    private func deleteSelectedCameraStorageItems() async {
        let items = selectedCameraStorageItems.sorted { $0.handle > $1.handle }
        guard !items.isEmpty, !cameraStorageBusy else { return }
        cameraStorageBusy = true
        var deleted = 0
        for item in items {
            do {
                cameraStorageStatus = "正在从相机删除 \(deleted + 1)/\(items.count)…"
                try await model.deleteCameraStorageObject(handle: item.handle)
                deleted += 1
            } catch {
                model.errorMessage = "删除 \(item.filename) 失败：\(error.localizedDescription)"
                break
            }
        }
        cameraStorageBusy = false
        cameraStorageSelected.removeAll()
        await refreshCameraStorage()
        cameraStorageStatus = "已从相机永久删除 \(deleted) 个文件。"
    }

    private func beginCreatingBranch(parent: MacLibraryBranch?) {
        branchParentID = parent?.id
        branchParentName = parent?.name ?? "帧澈 ZENCHE 文件库"
        branchDraft = ""
        showBranchCreator = true
    }

    private var unclassifiedPhotos: [PhotoRecord] {
        model.photos.filter {
            branchStore.branchID(for: $0.url.path) == nil
        }
    }

    @ViewBuilder
    private var branchWorkspace: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                Image(systemName: "point.3.connected.trianglepath.dotted")
                    .font(.system(size: 27, weight: .semibold)) // 图标尺寸，不受 TypeScale 约束
                    .foregroundStyle(.white)
                    .frame(width: 54, height: 54)
                    .background(Palette.cobalt, in: RoundedRectangle(cornerRadius: 14))
                VStack(alignment: .leading, spacing: 3) {
                    Text("分支工作台")
                        .font(.system(size: TypeScale.title, weight: .bold))
                    Text("把文件拖到任意分支；拖回“未分类”即可移出分支。")
                        .font(.system(size: TypeScale.body))
                        .foregroundStyle(Palette.muted)
                }
                Spacer()
                Button {
                    beginCreatingBranch(parent: nil)
                } label: {
                    Label("新建分支", systemImage: "folder.badge.plus")
                }
                .buttonStyle(NativeButtonStyle(primary: true))
            }

            if branchStore.branches.isEmpty {
                Text("先建立项目、客户或拍摄日分支，再把本地文件拖入；文件仍保留在原始存储位置。")
                    .font(.system(size: TypeScale.body))
                    .foregroundStyle(Palette.muted)
                    .padding(.vertical, 6)
            } else {
                ForEach(branchStore.branches) { branch in
                    MacLibraryBranchRow(
                        store: branchStore,
                        branch: branch,
                        depth: 0,
                        photos: model.photos,
                        selectedPhoto: model.selectedPhoto,
                        addChild: {
                            beginCreatingBranch(parent: $0)
                        },
                        deleteBranch: {
                            branchPendingDeletion = $0
                        },
                        selectPhoto: {
                            model.selectedPhoto = $0
                        },
                        previewPhoto: {
                            model.selectedPhoto = $0
                            largePhoto = $0
                        }
                    )
                }
            }

            DisclosureGroup(
                "未分类 · \(unclassifiedPhotos.count)",
                isExpanded: $uncategorizedExpanded
            ) {
                if unclassifiedPhotos.isEmpty {
                    ContentUnavailableView(
                        "未分类已清空",
                        systemImage: "checkmark.circle",
                        description: Text("拍摄、导入或无线接收的新文件会先显示在这里。")
                    )
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 140)
                } else {
                    DisclosureGroup(
                        "照片 · \(unclassifiedPhotos.filter { !$0.isVideo }.count)",
                        isExpanded: $localPhotosExpanded
                    ) {
                        localPhotoGrid(unclassifiedPhotos.filter { !$0.isVideo })
                    }
                    DisclosureGroup(
                        "视频 · \(unclassifiedPhotos.filter(\.isVideo).count)",
                        isExpanded: $localVideosExpanded
                    ) {
                        localPhotoGrid(unclassifiedPhotos.filter(\.isVideo))
                    }
                }
            }
            .font(.system(size: TypeScale.emphasis, weight: .semibold))
            .padding(12)
            .background(
                unclassifiedDropTargeted
                    ? Palette.cobaltSoft
                    : Palette.paperSecondary,
                in: RoundedRectangle(cornerRadius: 11)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 11)
                    .stroke(
                        unclassifiedDropTargeted
                            ? Palette.cobalt
                            : Palette.rule,
                        lineWidth: unclassifiedDropTargeted ? 2 : 1
                    )
            }
            .dropDestination(for: String.self) { paths, _ in
                guard !paths.isEmpty else { return false }
                paths.forEach { branchStore.assign($0, to: nil) }
                return true
            } isTargeted: {
                unclassifiedDropTargeted = $0
            }
        }
        .padding(18)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: 16))
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Palette.cobalt)
                .frame(width: 4)
                .padding(.vertical, 18)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(Palette.cobalt.opacity(0.24), lineWidth: 1)
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
                                    .font(.system(size: 34)) // 图标尺寸，不受 TypeScale 约束
                                    .foregroundStyle(Palette.whiteLo)
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
                            .font(.system(size: TypeScale.body, weight: .semibold))
                            .lineLimit(1)
                        Text(
                            photo.createdAt.formatted(
                                date: .abbreviated,
                                time: .shortened
                            )
                        )
                        .font(.system(size: TypeScale.caption))
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
                .draggable(photo.url.path) {
                    Label(
                        photo.name,
                        systemImage: "arrow.up.and.down.and.arrow.left.and.right"
                    )
                    .font(.system(size: TypeScale.body, weight: .semibold))
                    .padding(10)
                    .background(
                        .regularMaterial,
                        in: RoundedRectangle(cornerRadius: 9)
                    )
                }
                .help("拖动到分支")
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

private enum EditorAdjustmentSection: String, CaseIterable, Identifiable {
    case light = "光线"
    case color = "色彩"
    case wheels = "色轮"
    case curves = "曲线"
    case picker = "取色器"
    case masks = "蒙版"
    case detail = "细节"
    case effects = "效果"
    case geometry = "几何"
    case aiTools = "AI 工具"

    var id: String { rawValue }
}

/// fig2 工具条图标：16x16 视口线性单色描边几何，五端同一套坐标（与
/// Windows XAML Geometry 逐点一致），仅描边；颜色由调用方注入，随按钮
/// 选中态联动（未选中 EDITOR_LABEL 灰 / 选中 EDITOR_ACCENT 橙）。
private enum EditorToolIcon {
    case colorWheel, curve, mask, geometry, ai
}

private struct EditorToolIconShape: Shape {
    let icon: EditorToolIcon

    func path(in rect: CGRect) -> Path {
        var path = Path()
        switch icon {
        case .colorWheel:
            path.addEllipse(in: CGRect(x: 1.5, y: 1.5, width: 13, height: 13))
            path.move(to: CGPoint(x: 8, y: 8))
            path.addLine(to: CGPoint(x: 14, y: 8))
            path.move(to: CGPoint(x: 8, y: 8))
            path.addLine(to: CGPoint(x: 5, y: 2.8))
            path.move(to: CGPoint(x: 8, y: 8))
            path.addLine(to: CGPoint(x: 5, y: 13.2))
            path.addEllipse(in: CGRect(x: 7.3, y: 7.3, width: 1.4, height: 1.4))
        case .curve:
            path.move(to: CGPoint(x: 2, y: 13))
            path.addCurve(
                to: CGPoint(x: 9, y: 5),
                control1: CGPoint(x: 4.5, y: 11.5),
                control2: CGPoint(x: 5.5, y: 5.5)
            )
            path.addCurve(
                to: CGPoint(x: 14, y: 3.5),
                control1: CGPoint(x: 11.5, y: 4.6),
                control2: CGPoint(x: 12.5, y: 6.5)
            )
            path.addRect(CGRect(x: 8.2, y: 4.6, width: 1.6, height: 1.6))
            path.addRect(CGRect(x: 12.6, y: 6.6, width: 1.6, height: 1.6))
        case .mask:
            path.addRoundedRect(
                in: CGRect(x: 2, y: 2, width: 12, height: 12),
                cornerSize: CGSize(width: 1, height: 1)
            )
            path.addEllipse(in: CGRect(x: 5.5, y: 5.5, width: 5, height: 5))
        case .geometry:
            path.move(to: CGPoint(x: 3, y: 9.5))
            path.addLine(to: CGPoint(x: 7, y: 4))
            path.addLine(to: CGPoint(x: 11, y: 9.5))
            path.closeSubpath()
            path.addEllipse(in: CGRect(x: 10.5, y: 3.7, width: 3, height: 3))
            path.addRect(CGRect(x: 3, y: 11.5, width: 10, height: 2.5))
        case .ai:
            path.move(to: CGPoint(x: 8, y: 2))
            path.addLine(to: CGPoint(x: 9.3, y: 6.7))
            path.addLine(to: CGPoint(x: 14, y: 8))
            path.addLine(to: CGPoint(x: 9.3, y: 9.3))
            path.addLine(to: CGPoint(x: 8, y: 14))
            path.addLine(to: CGPoint(x: 6.7, y: 9.3))
            path.addLine(to: CGPoint(x: 2, y: 8))
            path.addLine(to: CGPoint(x: 6.7, y: 6.7))
            path.closeSubpath()
        }
        let scale = min(rect.width, rect.height) / 16
        return path.applying(CGAffineTransform(scaleX: scale, y: scale))
    }
}

private enum AiImageMode: String, CaseIterable, Identifiable {
    case edit = "AI 修图"
    case generate = "AI 生图"
    var id: String { rawValue }
}

private enum AiAspectRatio: String, CaseIterable, Identifiable {
    case square = "1:1"; case landscape = "16:9"; case portrait = "9:16"
    case fourThree = "4:3"; case threeTwo = "3:2"
    var id: String { rawValue }
    var size: String {
        switch self {
        case .square: return "1024x1024"
        case .landscape: return "1792x1024"
        case .portrait: return "1024x1792"
        case .fourThree: return "1365x1024"
        case .threeTwo: return "1536x1024"
        }
    }
}

private enum AiResolution: String, CaseIterable, Identifiable {
    case k1 = "1K"; case k2 = "2K"; case k4 = "4K"
    var id: String { rawValue }
}

final class ActivationManager {
    private static let activatedKey = "ai_activated"
    private static let deviceIdKey = "ai_device_id"
    private static let deviceIdKeychainService = "com.tauber.nikonlink.ai-device-id"
    private static let deviceIdKeychainAccount = "ai_device_id"
    private static let usageCountKey = "ai_usage_count"
    private static let serverRemainingKey = "ai_server_remaining"
    private static let activationStateKey = "ai_verified_activation_state"
    private static let maxUsage = 100
    private static let stableDeviceId: String = {
        if let existing = UserDefaults.standard.string(forKey: deviceIdKey),
           !existing.isEmpty {
            saveDeviceIdToKeychain(existing)
            return existing
        }
        if let existing = loadDeviceIdFromKeychain(), !existing.isEmpty {
            UserDefaults.standard.set(existing, forKey: deviceIdKey)
            return existing
        }
        let platform = IOServiceGetMatchingService(
            kIOMainPortDefault,
            IOServiceMatching("IOPlatformExpertDevice")
        )
        defer { IOObjectRelease(platform) }
        let serial = IORegistryEntryCreateCFProperty(
            platform,
            kIOPlatformSerialNumberKey as CFString,
            kCFAllocatorDefault,
            0
        )?.takeRetainedValue() as? String
        let id = serial ?? UUID().uuidString
        UserDefaults.standard.set(id, forKey: deviceIdKey)
        saveDeviceIdToKeychain(id)
        return id
    }()

    static var isActivated: Bool {
        if let state = UserDefaults.standard.dictionary(forKey: activationStateKey),
           let remaining = state["remaining"] as? Int,
           let code = state["code"] as? String,
           let boundDeviceId = state["deviceId"] as? String {
            return !code.isEmpty && boundDeviceId == deviceId && remaining > 0
        }
        guard UserDefaults.standard.bool(forKey: activatedKey) else { return false }
        return remainingUsage > 0
    }

    static var remainingUsage: Int {
        if let state = UserDefaults.standard.dictionary(forKey: activationStateKey),
           let remaining = state["remaining"] as? Int {
            return max(0, min(maxUsage, remaining))
        }
        if let server = UserDefaults.standard.object(forKey: serverRemainingKey) as? Int {
            return max(0, min(maxUsage, server))
        }
        return max(0, maxUsage - UserDefaults.standard.integer(forKey: usageCountKey))
    }

    static func updateServerRemaining(_ remaining: Int) {
        let bounded = max(0, min(maxUsage, remaining))
        let defaults = UserDefaults.standard
        if var state = defaults.dictionary(forKey: activationStateKey) {
            state["remaining"] = bounded
            state["activated"] = bounded > 0
            defaults.set(state, forKey: activationStateKey)
        }
        defaults.set(bounded, forKey: serverRemainingKey)
        if bounded <= 0 { defaults.set(false, forKey: activatedKey) }
    }

    static func recordUsageFallback() {
        let c = UserDefaults.standard.integer(forKey: usageCountKey) + 1
        UserDefaults.standard.set(c, forKey: usageCountKey)
        if let server = UserDefaults.standard.object(forKey: serverRemainingKey) as? Int {
            updateServerRemaining(server - 1)
        }
        if c >= maxUsage { UserDefaults.standard.set(false, forKey: activatedKey) }
    }

    static var deviceId: String {
        stableDeviceId
    }

    static func verify(code: String, deviceId: String) -> Bool {
        let t = code.trimmingCharacters(in: .whitespacesAndNewlines)
        let did = deviceId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty, !did.isEmpty else { return false }
        let parts = t.components(separatedBy: "-")
        guard parts.count >= 4, parts[0] == "ZENCHE", parts[1] == "AI" else { return false }
        let exp = parts.last ?? "19700101"
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.dateFormat = "yyyyMMdd"
        df.isLenient = false
        guard exp.count == 8,
              let ed = df.date(from: exp),
              df.string(from: ed) == exp,
              Calendar.current.startOfDay(for: ed) >= Calendar.current.startOfDay(for: Date())
        else { return false }
        let sigPart = parts[2..<(parts.count - 1)].joined(separator: "-")
        guard let sig = Data(base64Encoded: sigPart),
              let pk = publicKey else { return false }
        let payload = "\(did):\(exp):a1b2c3d4e5f6"
        guard let pdata = payload.data(using: .utf8) else { return false }
        var err: Unmanaged<CFError>?
        return SecKeyVerifySignature(
            pk,
            .rsaSignatureMessagePKCS1v15SHA256,
            pdata as CFData,
            sig as CFData,
            &err
        )
    }

    static func verifyAndActivate(code: String) -> Bool {
        let t = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard verify(code: t, deviceId: deviceId) else { return false }
        storeVerifiedActivation(code: t, remaining: maxUsage)
        return true
    }

    static func storeVerifiedActivation(code: String, remaining: Int) {
        let bounded = max(0, min(maxUsage, remaining))
        let defaults = UserDefaults.standard
        // Replace the authoritative state with one property-list write, then
        // mirror legacy keys for compatibility with earlier releases.
        defaults.set([
            "code": code.trimmingCharacters(in: .whitespacesAndNewlines),
            "deviceId": deviceId,
            "remaining": bounded,
            "activated": bounded > 0
        ], forKey: activationStateKey)
        defaults.set(code.trimmingCharacters(in: .whitespacesAndNewlines), forKey: "ai_activation_code")
        defaults.set(deviceId, forKey: deviceIdKey)
        defaults.set(maxUsage - bounded, forKey: usageCountKey)
        defaults.set(bounded, forKey: serverRemainingKey)
        defaults.set(bounded > 0, forKey: activatedKey)
    }

    static var savedCode: String? {
        if let state = UserDefaults.standard.dictionary(forKey: activationStateKey),
           let code = state["code"] as? String,
           !code.isEmpty {
            return code
        }
        return UserDefaults.standard.string(forKey: "ai_activation_code")
    }

    private static func loadDeviceIdFromKeychain() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: deviceIdKeychainService,
            kSecAttrAccount as String: deviceIdKeychainAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data
        else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private static func saveDeviceIdToKeychain(_ id: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: deviceIdKeychainService,
            kSecAttrAccount as String: deviceIdKeychainAccount
        ]
        let data = Data(id.utf8)
        if SecItemUpdate(
            query as CFDictionary,
            [kSecValueData as String: data] as CFDictionary
        ) == errSecItemNotFound {
            var item = query
            item[kSecValueData as String] = data
            item[kSecAttrAccessible as String] =
                kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            SecItemAdd(item as CFDictionary, nil)
        }
    }

    private static var publicKey: SecKey? {
        let k = [
            "MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAngqgOi5fjajCPusMNsfB",
            "FdMmWyzAGArL5bA+JK/uW+Md/YDtGvXjgSodev7VOQ9SPWqHUYA+XTpdyeCA+weL",
            "32JhFf+8+a28DjIp7RMv962m1qXJLtcdFbiBjWGDWF+itDJGUgR5OQbxV8xDd/kj",
            "c1ZT5ft7r2KwECUvwjKr9SAOWGJPK9oNmo9u2kW/6PbjpSEIhDH88FYloNWxpmdW",
            "XoQ2YYAfd5sKc0CNcBFdu2oEFGFHeUufbhgkZWtDPCS299W4TuWyTDfWPx4+Raap",
            "bcVF9RfFPa1uI7MpyrOqrGgSnuSC7HxY/B+NXm5rt4p3ZRaOzyKBiZEQ8Sg0XpKI",
            "3wIDAQAB"
        ].joined()
        guard let d = Data(base64Encoded: k) else { return nil }
        let a: [String: Any] = [
            kSecAttrKeyClass as String: kSecAttrKeyClassPublic,
            kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
            kSecAttrKeySizeInBits as String: 2048
        ]
        return SecKeyCreateWithData(d as CFData, a as CFDictionary, nil)
    }
}

enum AiRebindError: LocalizedError {
    case invalidEndpoint
    case responseTooLarge
    case malformedResponse
    case server(Int, String?)

    var errorDescription: String? {
        switch self {
        case .invalidEndpoint: return "设备码恢复地址无效"
        case .responseTooLarge: return "设备码恢复响应过大"
        case .malformedResponse: return "设备码恢复响应无效"
        case .server(let status, let message):
            if let message, !message.isEmpty { return message }
            return "设备码恢复服务返回错误（\(status)）"
        }
    }
}

enum AiRebindService {
    private static let endpoint = URL(string: "https://zenche.top/api/v1/ai/rebind")
    private static let maximumResponseBytes = 64 * 1024

    struct Result {
        let newCode: String
        let remaining: Int
    }

    static func rebind(
        oldCode: String,
        oldDeviceId: String,
        newDeviceId: String
    ) async throws -> Result {
        guard let endpoint else { throw AiRebindError.invalidEndpoint }
        let payload: [String: String] = [
            "activationCode": oldCode,
            "oldDeviceId": oldDeviceId,
            "newDeviceId": newDeviceId
        ]
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        var data = Data()
        data.reserveCapacity(4096)
        for try await byte in bytes {
            guard data.count < maximumResponseBytes else {
                throw AiRebindError.responseTooLarge
            }
            data.append(byte)
        }
        guard let http = response as? HTTPURLResponse else {
            throw AiRebindError.malformedResponse
        }
        let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard (200..<300).contains(http.statusCode) else {
            throw AiRebindError.server(http.statusCode, object?["error"] as? String)
        }
        guard let newCode = object?["newCode"] as? String,
              !newCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let remaining = object?["remaining"] as? Int,
              (0...100).contains(remaining)
        else { throw AiRebindError.malformedResponse }
        return Result(
            newCode: newCode.trimmingCharacters(in: .whitespacesAndNewlines),
            remaining: remaining
        )
    }
}

private final class AiImageService {
    private static let defaultServer = "http://101.34.255.115:8787"

    static var serverURL: String {
        UserDefaults.standard.string(forKey: "aiServerURL") ?? defaultServer
    }

    struct Request: Encodable {
        let activationCode: String
        let deviceId: String
        let prompt: String
        let size: String
        var image: String?
    }

    struct ImageData: Decodable { let b64_json: String?; let url: String? }
    struct ResponseData: Decodable { let data: [ImageData] }
    struct Result {
        let data: Data
        let remainingUsage: Int?
    }

    func generate(
        prompt: String,
        sourceImageData: Data?,
        sourceFilename: String?,
        size: String,
        activationCode: String,
        deviceId: String
    ) async throws -> Result {
        let base = Self.serverURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: base + "/v1/ai") else { throw AiServiceError.invalidEndpoint }
        var req = Request(activationCode: activationCode, deviceId: deviceId, prompt: prompt, size: size)
        if let src = sourceImageData, !src.isEmpty {
            let ext = (sourceFilename as NSString?)?.pathExtension.lowercased() ?? "jpg"
            let mime: String
            switch ext {
            case "png": mime = "image/png"
            case "heic", "heif": mime = "image/heic"
            case "tif", "tiff": mime = "image/tiff"
            case "bmp": mime = "image/bmp"
            default: mime = "image/jpeg"
            }
            req.image = "data:\(mime);base64,\(src.base64EncodedString())"
        }
        var r = URLRequest(url: url); r.httpMethod = "POST"
        r.setValue("application/json", forHTTPHeaderField: "Content-Type")
        r.timeoutInterval = 60; r.httpBody = try JSONEncoder().encode(req)
        let (data, resp) = try await URLSession.shared.data(for: r)
        guard let hr = resp as? HTTPURLResponse else { throw AiServiceError.networkError }
        guard (200..<300).contains(hr.statusCode) else {
            if hr.statusCode == 403 { throw AiServiceError.invalidActivation }
            if hr.statusCode == 502 { throw AiServiceError.aiServiceUnavailable }
            throw AiServiceError.serverError(hr.statusCode, "")
        }
        let result = try JSONDecoder().decode(ResponseData.self, from: data)
        guard let first = result.data.first else { throw AiServiceError.noImageReturned }
        let remaining = hr.value(forHTTPHeaderField: "X-ZENCHE-Remaining").flatMap(Int.init)
        if let b64 = first.b64_json, let img = Data(base64Encoded: b64) {
            return Result(data: img, remainingUsage: remaining)
        }
        if let u = first.url, let url = URL(string: u) {
            let (d, _) = try await URLSession.shared.data(from: url)
            return Result(data: d, remainingUsage: remaining)
        }
        throw AiServiceError.noImageReturned
    }
}

enum AiServiceError: LocalizedError {
    case missingActivation, invalidActivation, invalidEndpoint, networkError, serverError(Int, String), aiServiceUnavailable, noImageReturned
    var errorDescription: String? {
        switch self {
        case .missingActivation: return "请先在设置中输入激活码解锁 AI 功能"
        case .invalidActivation: return "激活码无效/过期/次数用完"
        case .invalidEndpoint: return "AI 服务器地址无效"
        case .networkError: return "网络连接失败，请检查网络后重试"
        case .serverError(let c, _): return "AI 服务返回错误（\(c)），请稍后重试"
        case .aiServiceUnavailable: return "AI 服务暂时不可用"
        case .noImageReturned: return "AI 未返回有效图片，请调整提示词后重试"
        }
    }
}

private enum EditorCropRatio: String, CaseIterable, Identifiable {
    case original = "原始比例"
    case square = "1:1"
    case fourThree = "4:3"
    case threeTwo = "3:2"
    case sixteenNine = "16:9"

    var id: String { rawValue }

    var value: CGFloat? {
        switch self {
        case .original: nil
        case .square: 1
        case .fourThree: 4 / 3
        case .threeTwo: 3 / 2
        case .sixteenNine: 16 / 9
        }
    }
}

private enum EditorPreset: String, CaseIterable, Identifiable {
    case original = "原始"
    case natural = "自然增强"
    case portrait = "人像柔和"
    case landscape = "风光通透"
    case monochrome = "高反差黑白"

    var id: String { rawValue }
}

private struct EditorAIAnalysis {
    let meanLuma: Double
    let contrast: Double
    let shadowRatio: Double
    let highlightRatio: Double
    let saturation: Double
    let red: Double
    let green: Double
    let blue: Double
    let detail: Double

    var summaryKey: String {
        if meanLuma < 0.38 {
            return "检测到画面偏暗，已提亮阴影并保护高光"
        }
        if meanLuma > 0.64 || highlightRatio > 0.08 {
            return "检测到画面偏亮，已回收高光并恢复层次"
        }
        if contrast < 0.16 {
            return "检测到动态范围偏平，已增强层次与色彩"
        }
        return "曝光均衡，已优化色彩与细节"
    }
}

private struct EditorCurvePoint: Equatable {
    var x: Double
    var y: Double

    static let defaults: [EditorCurvePoint] = [
        EditorCurvePoint(x: 0, y: 0),
        EditorCurvePoint(x: 0.25, y: 0.25),
        EditorCurvePoint(x: 0.5, y: 0.5),
        EditorCurvePoint(x: 0.75, y: 0.75),
        EditorCurvePoint(x: 1, y: 1)
    ]
}

private struct EditorMaskPoint: Equatable {
    var x: Double
    var y: Double
}

private enum EditorMaskBrushMode: String {
    case add = "添加"
    case subtract = "减去"
}

private struct EditorMaskStroke: Identifiable, Equatable {
    let id = UUID()
    var points: [EditorMaskPoint]
    var mode: EditorMaskBrushMode
    var size: Double
}

private struct EditorMaskLayer: Identifiable, Equatable {
    var id = UUID()
    var name: String
    var isVisible = true
    var type = "画笔"
    var amount = 100.0
    var feather = 50.0
    var invert = false
    var brushMode = EditorMaskBrushMode.add
    var brushSize = 18.0
    var strokes: [EditorMaskStroke] = []
    var exposure = 0.0
    var contrast = 0.0
    var highlights = 0.0
    var shadows = 0.0
    var temperature = 0.0
    var tint = 0.0
    var saturation = 0.0
    var clarity = 0.0
}

private let editorSmartMaskKernel = CIColorKernel(source: """
kernel vec4 zencheSmartMask(__sample pixel, float kind, vec2 origin, vec2 size) {
    vec2 uv = (destCoord() - origin) / max(size, vec2(1.0));
    float r = pixel.r;
    float g = pixel.g;
    float b = pixel.b;
    float luma = dot(pixel.rgb, vec3(0.2126, 0.7152, 0.0722));
    float chroma = max(r, max(g, b)) - min(r, min(g, b));
    vec2 centered = vec2((uv.x - 0.5) / 0.72, (uv.y - 0.48) / 0.82);
    float centerPrior = 1.0 - clamp(length(centered), 0.0, 1.0);
    float subject = clamp(centerPrior * 0.72 + chroma * 0.72 + abs(luma - 0.5) * 0.18, 0.0, 1.0);
    float topY = 1.0 - uv.y;
    float topPrior = clamp((0.76 - topY) / 0.62, 0.0, 1.0);
    float skyColor = clamp((b - r * 0.88) * 2.5 + (b - g * 0.78) * 1.6 + 0.18, 0.0, 1.0);
    float sky = topPrior * skyColor * smoothstep(0.18, 0.82, luma);
    float skin = smoothstep(0.02, 0.20, r - b) * smoothstep(-0.05, 0.16, r - g) * smoothstep(0.16, 0.78, luma);
    float person = clamp(skin * 0.78 + subject * centerPrior * 0.42, 0.0, 1.0);
    float value = subject;
    if (kind > 1.5 && kind < 2.5) value = sky;
    if (kind > 2.5 && kind < 3.5) value = 1.0 - subject;
    if (kind > 3.5 && kind < 4.5) value = person;
    if (kind > 4.5 && kind < 5.5) value = smoothstep(0.55, 0.88, luma);
    if (kind > 5.5) value = 1.0 - smoothstep(0.12, 0.48, luma);
    return vec4(value, value, value, 1.0);
}
""")

private struct ProfessionalEditSettings {
    var exposure = 0.0
    var contrast = 0.0
    var highlights = 0.0
    var shadows = 0.0
    var whites = 0.0
    var blacks = 0.0
    var temperature = 0.0
    var tint = 0.0
    var vibrance = 0.0
    var saturation = 0.0
    var texture = 0.0
    var clarity = 0.0
    var sharpening = 0.0
    var noiseReduction = 0.0
    var dehaze = 0.0
    var vignette = 0.0
    var lift = 0.0
    var gamma = 0.0
    var gain = 0.0
    var liftX = 0.0
    var liftY = 0.0
    var gammaX = 0.0
    var gammaY = 0.0
    var gainX = 0.0
    var gainY = 0.0
    var curveShadows = 0.0
    var curveMidtones = 0.0
    var curveHighlights = 0.0
    var curvePoints: [EditorCurvePoint] = EditorCurvePoint.defaults
    var maskType = "无"
    var maskAmount = 0.0
    var maskFeather = 50.0
    var maskInvert = false
    var maskExists = false
    var maskBrushMode = EditorMaskBrushMode.add
    var maskBrushSize = 18.0
    var maskStrokes: [EditorMaskStroke] = []
    var maskExposure = 0.0
    var maskContrast = 0.0
    var maskHighlights = 0.0
    var maskShadows = 0.0
    var maskTemperature = 0.0
    var maskTint = 0.0
    var maskSaturation = 0.0
    var maskClarity = 0.0
    var maskLayers: [EditorMaskLayer] = []
    var activeMaskLayerID: UUID?
    var nextMaskNumber = 1
    var pickedColorHex = "未取样"
    var rotation = 0
    var flipHorizontal = false
    var flipVertical = false
    var cropRatio = EditorCropRatio.original

    var activeMaskLayerIsVisible: Bool {
        guard let id = activeMaskLayerID,
              let layer = maskLayers.first(where: { $0.id == id })
        else { return false }
        return layer.isVisible
    }

    mutating func createMaskLayer(type: String = "画笔") {
        persistActiveMaskLayer()
        let layer = EditorMaskLayer(
            name: "\(String(localized: "蒙版")) \(nextMaskNumber)",
            type: type
        )
        nextMaskNumber += 1
        maskLayers.append(layer)
        loadMaskLayer(layer)
    }

    mutating func ensureMaskLayer() {
        if activeMaskLayerID == nil || !maskExists {
            createMaskLayer()
        }
    }

    mutating func selectMaskLayer(_ id: UUID) {
        guard id != activeMaskLayerID,
              let layer = maskLayers.first(where: { $0.id == id })
        else { return }
        persistActiveMaskLayer()
        loadMaskLayer(layer)
    }

    mutating func deleteActiveMaskLayer() {
        guard let id = activeMaskLayerID,
              let index = maskLayers.firstIndex(where: { $0.id == id })
        else { return }
        persistActiveMaskLayer()
        maskLayers.remove(at: index)
        if maskLayers.isEmpty {
            maskExists = false
            maskType = "无"
            maskStrokes.removeAll()
            activeMaskLayerID = nil
        } else {
            loadMaskLayer(maskLayers[min(index, maskLayers.count - 1)])
        }
    }

    mutating func setMaskLayerVisible(_ id: UUID, _ isVisible: Bool) {
        persistActiveMaskLayer()
        guard let index = maskLayers.firstIndex(where: { $0.id == id }) else {
            return
        }
        maskLayers[index].isVisible = isVisible
    }

    func displayedMaskLayer(_ layer: EditorMaskLayer) -> EditorMaskLayer {
        guard layer.id == activeMaskLayerID else { return layer }
        return maskLayerSnapshot(identity: layer)
    }

    func effectiveMaskLayers() -> [EditorMaskLayer] {
        maskLayers.map(displayedMaskLayer)
    }

    func activeDisplayedMaskLayer() -> EditorMaskLayer? {
        guard let id = activeMaskLayerID,
              let layer = maskLayers.first(where: { $0.id == id })
        else { return nil }
        return displayedMaskLayer(layer)
    }

    private mutating func persistActiveMaskLayer() {
        guard let id = activeMaskLayerID,
              let index = maskLayers.firstIndex(where: { $0.id == id })
        else { return }
        maskLayers[index] = maskLayerSnapshot(identity: maskLayers[index])
    }

    private func maskLayerSnapshot(
        identity: EditorMaskLayer
    ) -> EditorMaskLayer {
        EditorMaskLayer(
            id: identity.id,
            name: identity.name,
            isVisible: identity.isVisible,
            type: maskType,
            amount: maskAmount,
            feather: maskFeather,
            invert: maskInvert,
            brushMode: maskBrushMode,
            brushSize: maskBrushSize,
            strokes: maskStrokes,
            exposure: maskExposure,
            contrast: maskContrast,
            highlights: maskHighlights,
            shadows: maskShadows,
            temperature: maskTemperature,
            tint: maskTint,
            saturation: maskSaturation,
            clarity: maskClarity
        )
    }

    private mutating func loadMaskLayer(_ layer: EditorMaskLayer) {
        maskExists = true
        activeMaskLayerID = layer.id
        maskType = layer.type
        maskAmount = layer.amount
        maskFeather = layer.feather
        maskInvert = layer.invert
        maskBrushMode = layer.brushMode
        maskBrushSize = layer.brushSize
        maskStrokes = layer.strokes
        maskExposure = layer.exposure
        maskContrast = layer.contrast
        maskHighlights = layer.highlights
        maskShadows = layer.shadows
        maskTemperature = layer.temperature
        maskTint = layer.tint
        maskSaturation = layer.saturation
        maskClarity = layer.clarity
    }

    mutating func resetTone() {
        let geometry = (
            rotation,
            flipHorizontal,
            flipVertical,
            cropRatio
        )
        self = ProfessionalEditSettings()
        rotation = geometry.0
        flipHorizontal = geometry.1
        flipVertical = geometry.2
        cropRatio = geometry.3
    }

    mutating func apply(_ preset: EditorPreset) {
        resetTone()
        switch preset {
        case .original:
            break
        case .natural:
            contrast = 8
            highlights = -18
            shadows = 16
            whites = 8
            blacks = -8
            vibrance = 14
            texture = 8
            clarity = 6
            sharpening = 24
            noiseReduction = 8
        case .portrait:
            contrast = -4
            highlights = -24
            shadows = 18
            temperature = 7
            tint = 4
            vibrance = 10
            texture = -12
            clarity = -6
            sharpening = 16
            noiseReduction = 22
            vignette = -8
        case .landscape:
            contrast = 12
            highlights = -28
            shadows = 14
            whites = 12
            blacks = -14
            vibrance = 24
            saturation = 5
            texture = 16
            clarity = 18
            sharpening = 30
            dehaze = 12
            vignette = -10
        case .monochrome:
            contrast = 22
            highlights = -18
            shadows = 12
            whites = 10
            blacks = -22
            saturation = -100
            texture = 12
            clarity = 24
            sharpening = 28
            vignette = -14
        }
    }

    mutating func applyAI(
        _ analysis: EditorAIAnalysis,
        intensity: Double
    ) {
        resetTone()
        let amount = max(0.35, min(1, intensity))
        exposure = max(
            -0.8,
            min(0.8, log2(0.48 / max(0.08, analysis.meanLuma)) * 0.68)
        ) * amount
        contrast = max(-8, min(24, (0.20 - analysis.contrast) * 130)) * amount
        highlights = -max(
            6,
            min(48, analysis.highlightRatio * 360 + max(0, analysis.meanLuma - 0.55) * 70)
        ) * amount
        shadows = max(
            6,
            min(46, analysis.shadowRatio * 330 + max(0, 0.44 - analysis.meanLuma) * 75)
        ) * amount
        whites = max(-8, min(14, (0.58 - analysis.meanLuma) * 28)) * amount
        blacks = -max(4, min(18, (0.21 - analysis.contrast) * 55 + 5)) * amount
        temperature = max(-18, min(18, (analysis.blue - analysis.red) * 95)) * amount
        let greenExcess = analysis.green - (analysis.red + analysis.blue) / 2
        tint = max(-14, min(14, greenExcess * 85)) * amount
        vibrance = max(4, min(26, (0.30 - analysis.saturation) * 95 + 6)) * amount
        saturation = max(-4, min(8, (0.22 - analysis.saturation) * 28)) * amount
        texture = max(4, min(16, (0.075 - analysis.detail) * 170 + 7)) * amount
        clarity = max(3, min(18, (0.19 - analysis.contrast) * 70 + 6)) * amount
        sharpening = max(14, min(34, (0.08 - analysis.detail) * 210 + 20)) * amount
        noiseReduction = max(6, min(30, analysis.shadowRatio * 120 + max(0, 0.38 - analysis.meanLuma) * 42 + 6)) * amount
        dehaze = max(0, min(16, (0.18 - analysis.contrast) * 75)) * amount
    }
}

private struct ResolveEditorWorkbench<
    Media: View,
    CanvasArea: View,
    Tools: View
>: View {
    let media: Media
    let canvasArea: CanvasArea
    let tools: Tools

    init(
        @ViewBuilder media: () -> Media,
        @ViewBuilder canvasArea: () -> CanvasArea,
        @ViewBuilder tools: () -> Tools
    ) {
        self.media = media()
        self.canvasArea = canvasArea()
        self.tools = tools()
    }

    var body: some View {
        HStack(spacing: 1) {
            media.frame(width: 220)
            canvasArea.frame(maxWidth: .infinity)
            tools.frame(width: 320)
        }
        .padding(1)
        .background(Palette.editorRule)
        .overlay {
            Rectangle()
                .stroke(Palette.editorRule, lineWidth: 1)
        }
    }
}

private struct EditorMediaRail<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label {
                RuntimeLocalizedText("媒体池")
            } icon: {
                Image(systemName: "photo.stack")
            }
                .font(.system(size: TypeScale.caption, weight: .bold, design: .monospaced))
            Divider().overlay(Palette.editorRule)
            content
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxHeight: .infinity, alignment: .top)
        .foregroundStyle(.white)
        .background(Palette.editorPanel)
    }
}

private struct EditorToolRail<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(Palette.editorPanel)
    }
}

private struct EditorScopeDock: View {
    let traces: [MacScopeTrace]
    let hasSource: Bool
    let metrics: String?

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                RuntimeLocalizedText("编辑示波器")
                    .font(.system(size: TypeScale.caption, weight: .bold, design: .monospaced))
                    .foregroundStyle(Palette.editorLabel)
                RuntimeLocalizedText(hasSource ? "本地图像分析" : "暂无图像源")
                    .font(.system(size: TypeScale.caption, weight: .semibold, design: .monospaced))
                    .foregroundStyle(hasSource ? Palette.editorAccent : Palette.editorLabel)
                if let metrics {
                    Text(metrics)
                        .font(.system(size: TypeScale.caption, weight: .medium, design: .monospaced))
                        .foregroundStyle(Palette.editorLabel)
                        .lineLimit(1)
                }
            }
            .frame(width: 190, alignment: .leading)
            MacScopePlot(label: "RGB", traces: traces)
        }
        .padding(10)
        .background(Palette.editorPanel)
    }
}

/// Computes the same `S64x48:hex` RGB density payloads the monitor page uses,
/// from the current editor image (downsampled to ≤320 px wide). Mirrors
/// ProfessionalMonitor's accumulate + log1p normalization so the editor
/// waveform matches the video-page rendering contract exactly.
private enum MacEditorRGBDensity {
    static let columns = 64
    static let rows = 48

    static func compute(from image: NSImage) -> (red: String, green: String, blue: String)? {
        var proposed = CGRect(origin: .zero, size: image.size)
        guard let cgImage = image.cgImage(
            forProposedRect: &proposed,
            context: nil,
            hints: nil
        ) else { return nil }
        let sourceWidth = cgImage.width
        let sourceHeight = cgImage.height
        guard sourceWidth > 0, sourceHeight > 0 else { return nil }
        let width = min(320, sourceWidth)
        let height = max(1, width * sourceHeight / max(1, sourceWidth))
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let bitmapInfo = CGBitmapInfo.byteOrder32Big.rawValue
            | CGImageAlphaInfo.premultipliedLast.rawValue
        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: bitmapInfo
        ) else { return nil }
        context.interpolationQuality = .medium
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        var red = [Int](repeating: 0, count: columns * rows)
        var green = [Int](repeating: 0, count: columns * rows)
        var blue = [Int](repeating: 0, count: columns * rows)
        for y in 0..<height {
            for x in 0..<width {
                let offset = (y * width + x) * 4
                let r = Int(pixels[offset])
                let g = Int(pixels[offset + 1])
                let b = Int(pixels[offset + 2])
                let column = min(columns - 1, x * columns / max(1, width))
                accumulate(&red, column: column, value: r)
                accumulate(&green, column: column, value: g)
                accumulate(&blue, column: column, value: b)
            }
        }
        return (densityMap(red), densityMap(green), densityMap(blue))
    }

    private static func accumulate(_ buffer: inout [Int], column: Int, value: Int) {
        let row = rows - 1 - clamp8(value) * (rows - 1) / 255
        buffer[row * columns + column] += 1
    }

    private static func clamp8(_ value: Int) -> Int {
        min(255, max(0, value))
    }

    private static func densityMap(_ values: [Int]) -> String {
        let digits = Array("0123456789ABCDEF")
        let maximum = max(1, values.max() ?? 1)
        let divisor = log1p(Double(maximum))
        let payload = values.map { value -> Character in
            let level = Int((log1p(Double(value)) / divisor * 15).rounded())
            return digits[min(15, max(0, level))]
        }
        return "S\(columns)x\(rows):" + String(payload)
    }
}

private struct ImageEditorView: View {
    @ObservedObject var model: CameraModel
    @StateObject private var branchStore = MacLibraryBranchStore()
    @State private var selectedPhotoURL: URL?
    @State private var selectedSection = EditorAdjustmentSection.light
    @State private var settings = ProfessionalEditSettings()
    @State private var selectedPreset = EditorPreset.original
    @State private var selectedNikonCloudPresetID: String?
    @State private var showingOriginal = false
    @State private var status = "请选择文件库中的照片"
    @State private var isSaving = false
    @State private var aiIntensity = 0.72
    @State private var aiSummaryKey = "等待分析当前照片"
    @State private var settingsBeforeAI: ProfessionalEditSettings?
    @State private var aiAnalysis: EditorAIAnalysis?
    @State private var copiedAISettings: ProfessionalEditSettings?
    @State private var activeCurvePoint: Int?
    @State private var activeMaskStrokeID: UUID?
    @State private var suppressPresetApply = false
    @State private var pickerArmed = false
    private let context = CIContext()
    @State private var aiMode = AiImageMode.edit
    @State private var aiPrompt = ""
    @State private var aiManualPrompt = ""
    @State private var aiSelectedPresets: Set<String> = []
    @State private var aiRatio = AiAspectRatio.square
    @State private var aiResolution = AiResolution.k1
    @State private var aiResultImage: NSImage?
    @State private var aiIsGenerating = false
    private let aiService = AiImageService()

    private var photos: [PhotoRecord] {
        model.photos.filter {
            !$0.isVideo
                && Self.editableExtensions.contains(
                    $0.url.pathExtension.lowercased()
                )
        }
    }

    private static let editableExtensions: Set<String> = [
        "jpg", "jpeg", "png", "heic", "heif", "tif", "tiff", "bmp"
    ]

    private var selectedPhoto: PhotoRecord? {
        photos.first { $0.url == selectedPhotoURL }
    }

    private var selectedNikonCloudPreset: NikonCloudPreset? {
        guard let selectedNikonCloudPresetID else { return nil }
        return NikonCloudPresetLibrary.presets.first {
            $0.id == selectedNikonCloudPresetID
        }
    }

    private func editorMenuThumbnail(for photo: PhotoRecord) -> NSImage? {
        guard !photo.isVideo,
              let source = CGImageSourceCreateWithURL(photo.url as CFURL, nil) else {
            return nil
        }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: 96
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(
            source,
            0,
            options as CFDictionary
        ) else {
            return nil
        }
        // Give AppKit a physically small representation. A SwiftUI frame alone
        // does not prevent a Menu from measuring the source image's full size.
        return NSImage(cgImage: cgImage, size: NSSize(width: 48, height: 34))
    }

    @ViewBuilder
    private var editorPhotoPicker: some View {
        Menu {
            Button {
                selectedPhotoURL = nil
            } label: {
                Label("选择照片", systemImage: "photo.on.rectangle")
            }
            let unclassified = photos.filter {
                branchStore.branchID(for: $0.url.path) == nil
            }
            if !unclassified.isEmpty {
                Menu("未分类 · \(unclassified.count)") {
                    ForEach(unclassified) { photo in
                        editorPhotoMenuItem(photo)
                    }
                }
            }
            ForEach(branchStore.branches) { branch in
                editorBranchMenu(branch, depth: 0)
            }
        } label: {
            HStack(spacing: 8) {
                // Keep the Menu label text-only. AppKit-backed Menu labels do
                // not consistently honor a resizable NSImage's frame and can
                // paint the full source image across the workspace. The menu
                // rows below still provide bounded thumbnails.
                Image(systemName: "photo.on.rectangle")
                Text(selectedPhoto?.name ?? "选择照片")
                    .lineLimit(1)
            }
        }
    }

    @ViewBuilder
    private func editorPhotoMenuItem(_ photo: PhotoRecord) -> some View {
        Button {
            selectedPhotoURL = photo.url
        } label: {
            HStack(spacing: 8) {
                if let image = editorMenuThumbnail(for: photo) {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 48, height: 34)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                } else {
                    Image(systemName: "photo")
                        .frame(width: 48, height: 34)
                }
                Text(photo.name)
                    .lineLimit(1)
                if selectedPhotoURL == photo.url {
                    Image(systemName: "checkmark")
                }
            }
        }
    }

    private func editorBranchMenu(
        _ branch: MacLibraryBranch,
        depth: Int
    ) -> AnyView {
        let assigned = photos.filter {
            branchStore.branchID(for: $0.url.path) == branch.id
        }
        return AnyView(Menu("\(String(repeating: "  ", count: depth))分支 · \(branch.name) · \(assigned.count)") {
            if assigned.isEmpty && branch.children.isEmpty {
                Text("此分支暂无可编辑照片")
            }
            ForEach(assigned) { photo in
                editorPhotoMenuItem(photo)
            }
            ForEach(branch.children) { child in
                editorBranchMenu(child, depth: depth + 1)
            }
        })
    }

    var body: some View {
        VStack(spacing: 0) {
            editorHeader
            if selectedSection != .aiTools {
                nikonCloudPreviewNotice
            }
            GeometryReader { geometry in
                VStack(spacing: 1) {
                    ResolveEditorWorkbench {
                        EditorMediaRail {
                            editorPhotoPicker
                                .frame(maxWidth: .infinity, alignment: .leading)
                            RuntimeLocalizedText("可编辑照片")
                                .font(.system(size: TypeScale.caption, weight: .bold, design: .monospaced))
                                .foregroundStyle(Palette.whiteGhost)
                            Text("\(photos.count)")
                                .font(.system(size: TypeScale.display, weight: .semibold, design: .monospaced))
                            if let selectedPhoto {
                                Text(selectedPhoto.name)
                                    .font(.system(size: TypeScale.caption, design: .monospaced))
                                    .foregroundStyle(Palette.whiteDim)
                                    .lineLimit(4)
                            }
                            RuntimeLocalizedText("非破坏编辑 · 保存为高质量副本")
                                .font(.system(size: TypeScale.caption))
                                .foregroundStyle(Palette.whiteGhost)
                        }
                    } canvasArea: {
                        preview
                            .background(Palette.editorBg)
                    } tools: {
                        editorSummaryRail
                    }
                    .frame(maxHeight: .infinity)
                    HStack(spacing: 1) {
                        EditorToolRail {
                            editorColorPanel
                        }
                        EditorScopeDock(
                            traces: editorScopeTraces,
                            hasSource: selectedPhoto != nil,
                            metrics: editorScopeMetrics
                        )
                        .frame(width: 320)
                    }
                    .frame(height: 320)
                }
                .background(Palette.editorRule)
                .frame(
                    width: geometry.size.width,
                    height: geometry.size.height,
                    alignment: .topLeading
                )
            }
            .frame(minHeight: 560, idealHeight: 760)
        }
        .background(Palette.editorBg)
        // fig2 编辑器恒为深色；强制深色让沿用的动态 Palette 控件解析暗色变体。
        .preferredColorScheme(.dark)
        .onAppear {
            selectInitialPhoto()
        }
        .onChange(of: selectedPhotoURL) {
            aiResultImage = nil
            resetAdjustments()
            status = selectedPhoto == nil
                ? "请选择文件库中的照片"
                : "调整不会覆盖原文件"
        }
    }

    /// fig2 上带：深底标题栏，标题 + 副标题，1px 分隔底边。
    private var editorHeader: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    RuntimeLocalizedText(
                        selectedSection == .aiTools ? "AI 工具" : "专业显影"
                    )
                        .font(.system(size: TypeScale.emphasis, weight: .bold))
                        .foregroundStyle(.white)
                    RuntimeLocalizedText(
                        selectedSection == .aiTools
                            ? "基于 nano-banana-2 模型的 AI 修图与生图"
                            : "分组调整光线、色彩、细节、效果与几何；始终保留原文件。"
                    )
                        .font(.system(size: TypeScale.caption))
                        .foregroundStyle(Palette.editorLabel)
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 52)
            Rectangle()
                .fill(Palette.editorRule)
                .frame(height: 1)
        }
        .background(Palette.editorBg)
    }

    /// RGB density traces computed from the current editor image — the same
    /// source the preview renders (aiTools surfaces the AI result or original,
    /// every other section the rendered edit). Empty when no image is selected.
    private var editorScopeTraces: [MacScopeTrace] {
        let image: NSImage?
        if selectedSection == .aiTools {
            image = aiResultImage ?? (aiMode == .edit ? selectedOriginalImage : nil)
        } else {
            image = renderedImage
        }
        guard let image,
              let densities = MacEditorRGBDensity.compute(from: image) else { return [] }
        return [
            MacScopeTrace(value: densities.red, color: Palette.scopeR),
            MacScopeTrace(value: densities.green, color: Palette.scopeG),
            MacScopeTrace(value: densities.blue, color: Palette.scopeB)
        ]
    }

    /// Compact text form of the AI four metrics (mean luma / contrast /
    /// saturation / detail), kept beside the RGB waveform so the analysis
    /// readouts remain available on the editor page.
    private var editorScopeMetrics: String? {
        guard let aiAnalysis else { return nil }
        func percent(_ value: Double) -> String {
            "\(Int(max(0, min(1, value)) * 100))%"
        }
        return "曝光 \(percent(aiAnalysis.meanLuma)) · 动态 \(percent(aiAnalysis.contrast)) · 色彩 \(percent(aiAnalysis.saturation)) · 细节 \(percent(aiAnalysis.detail))"
    }

    private var aiToolsPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionSelector
                .padding(.horizontal, 18)
                .padding(.top, 16)
                .padding(.bottom, 12)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .center, spacing: 10) {
                        VStack(alignment: .leading, spacing: 3) {
                            Label("AI 创作", systemImage: "sparkles")
                                .font(.system(size: TypeScale.emphasis, weight: .semibold))
                            Text("修图覆盖原图 · 生图保存新文件")
                                .font(.system(size: TypeScale.caption))
                                .foregroundStyle(Palette.editorLabel)
                        }
                        Spacer()
                        Text(ActivationManager.isActivated ? "已解锁 · 剩余 \(ActivationManager.remainingUsage) 次" : "需要激活")
                            .font(.system(size: TypeScale.caption, weight: .semibold))
                            .foregroundStyle(ActivationManager.isActivated ? Palette.positive : Palette.muted)
                            .padding(.horizontal, 10)
                            .frame(minHeight: 26)
                            .background(
                                ActivationManager.isActivated ? Palette.positive.opacity(0.12) : Palette.paperSecondary,
                                in: Capsule()
                            )
                    }
                    HStack(spacing: 8) {
                        ForEach(AiImageMode.allCases) { mode in
                            Button {
                                aiMode = mode
                                aiResultImage = nil
                                composeAiPrompt()
                            } label: {
                                Label(mode.rawValue, systemImage: mode == .edit ? "wand.and.stars" : "photo.badge.plus")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(NativeButtonStyle(primary: aiMode == mode))
                        }
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("提示词").font(.system(size: TypeScale.body, weight: .semibold))
                        ZStack(alignment: .topLeading) {
                            if aiManualPrompt.isEmpty {
                                Text(aiMode == .edit ? "输入修图描述…（可补充）" : "输入生图描述…（可补充）")
                                    .font(.system(size: TypeScale.body))
                                    .foregroundStyle(Palette.editorLabel)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 8)
                            }
                            TextEditor(text: Binding(
                                get: { aiManualPrompt },
                                set: { aiManualPrompt = $0; composeAiPrompt() }
                            ))
                            .font(.system(size: TypeScale.body))
                            .frame(height: 80)
                            .scrollContentBackground(.hidden)
                        }
                        .frame(height: 80)
                        .overlay { RoundedRectangle(cornerRadius: 8).stroke(Palette.rule) }
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("可组合预设").font(.system(size: TypeScale.body, weight: .semibold)).foregroundStyle(Palette.editorLabel)
                            Spacer()
                            Button("清空") {
                                aiSelectedPresets.removeAll()
                                aiManualPrompt = ""
                                composeAiPrompt()
                            }.buttonStyle(NativeButtonStyle())
                        }
                        ForEach(aiModules, id: \.0) { module in
                            Text(module.0).font(.system(size: TypeScale.caption, weight: .semibold)).foregroundStyle(Palette.editorLabel)
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 6) {
                                    ForEach(module.1, id: \.self) { value in
                                        let key = "\(module.0):\(value)"
                                        Button(value) {
                                            let wasSelected = aiSelectedPresets.contains(key)
                                            aiSelectedPresets = aiSelectedPresets.filter { !$0.hasPrefix("\(module.0):") }
                                            if !wasSelected { aiSelectedPresets.insert(key) }
                                            composeAiPrompt()
                                        }
                                        .buttonStyle(NativeButtonStyle(primary: aiSelectedPresets.contains(key)))
                                        .frame(minHeight: 44)
                                    }
                                }
                            }
                        }
                        Text("最终提示词：\(aiPrompt.isEmpty ? "—" : aiPrompt)")
                            .font(.system(size: TypeScale.caption, design: .monospaced))
                            .foregroundStyle(Palette.editorLabel)
                            .lineLimit(3)
                    }
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("宽高比").font(.system(size: TypeScale.caption)).foregroundStyle(Palette.editorLabel)
                            Picker("宽高比", selection: $aiRatio) {
                                ForEach(AiAspectRatio.allCases) { r in Text(r.rawValue).tag(r) }
                            }.pickerStyle(.menu).frame(width: 110)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text("分辨率").font(.system(size: TypeScale.caption)).foregroundStyle(Palette.editorLabel)
                            editorMenuPicker(
                                current: aiResolution,
                                options: AiResolution.allCases,
                                display: { $0.rawValue },
                                apply: { aiResolution = $0 }
                            )
                            .frame(width: 90)
                        }
                        Spacer()
                    }
                }
                .padding(18)
            }
            Divider()
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Button { generateAi() } label: {
                        Label(aiIsGenerating ? "正在生成…" : "生成图像", systemImage: "sparkles")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(NativeButtonStyle(primary: true))
                    .disabled(aiPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || aiIsGenerating || (selectedPhoto == nil && aiMode == .edit))
                    if aiResultImage != nil {
                        Button { saveAiResult() } label: {
                            Label(isSaving ? "正在保存…" : "保存到文件库", systemImage: "square.and.arrow.down")
                        }.buttonStyle(NativeButtonStyle(primary: true)).disabled(isSaving)
                    }
                }
                Text(aiIsGenerating ? "正在调用 AI 模型…" : status)
                    .font(.system(size: TypeScale.caption, design: .monospaced))
                    .foregroundStyle(Palette.editorLabel)
                    .lineLimit(2)
            }
            .padding(14)
            .background(Palette.editorBg)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var aiModules: [(String, [String])] {
        var modules: [(String, [String])] = [
            ("主体", ["人像主体", "产品主体", "建筑主体", "风光主体", "食物主体"]),
            ("光线", ["柔和自然光", "电影感侧光", "金色时刻", "低调棚拍光", "夜景霓虹光"]),
            ("色彩", ["自然通透", "胶片暖调", "日系清新", "高反差黑白", "冷色城市"]),
            ("质感", ["保留真实皮肤纹理", "细节清晰", "轻微胶片颗粒", "柔和高光", "高动态范围"]),
            ("构图", ["浅景深", "干净背景", "对称构图", "环境叙事", "视觉焦点明确"])
        ]
        if aiMode == .edit {
            modules.append(("智能移除", [
                "去路人并自然补全背景",
                "去穿帮并移除摄影器材、工作人员、反光与杂物"
            ]))
            modules.append(("约束", [
                "保持人物身份和五官", "不改变产品形状", "不添加多余物体",
                "不过度磨皮", "保留自然阴影"
            ]))
        }
        return modules
    }

    private func composeAiPrompt() {
        var parts: [String] = []
        if !aiManualPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            parts.append(aiManualPrompt.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        for category in aiModules.map(\.0) {
            let values = aiSelectedPresets.filter { $0.hasPrefix("\(category):") }.map { String($0.dropFirst(category.count + 1)) }
            if !values.isEmpty { parts.append("\(category)：\(values.joined(separator: "、"))") }
        }
        aiPrompt = parts.joined(separator: "。")
    }

    /// fig2 中带右栏：照片编辑无节点图，落预设 / 尼康云创 / AI 摘要
    ///（同 Windows fbc74f2 右栏口径）。控件与回调原位搬迁，无逻辑改动。
    private var editorSummaryRail: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                editorMenuPicker(
                    current: selectedPreset,
                    options: EditorPreset.allCases,
                    display: { $0.rawValue },
                    apply: { selectedPreset = $0 }
                )
                .onChange(of: selectedPreset) {
                    guard !suppressPresetApply else { return }
                    selectedNikonCloudPresetID = nil
                    settings.apply(selectedPreset)
                    settingsBeforeAI = nil
                    aiSummaryKey = "等待分析当前照片"
                    showingOriginal = false
                    status = "已应用预设 · \(selectedPreset.rawValue)"
                }

                Menu {
                    Button {
                        suppressPresetApply = true
                        selectedNikonCloudPresetID = nil
                        settings.apply(.original)
                        selectedPreset = .original
                        showingOriginal = false
                        status = "尼康云创预览已关闭"
                        DispatchQueue.main.async { suppressPresetApply = false }
                    } label: {
                        Label("关闭云创预览", systemImage: "xmark.circle")
                    }
                    Divider()
                    ForEach(NikonCloudPresetLibrary.groups) { group in
                        Menu(group.title) {
                            ForEach(group.presets) { preset in
                                Button {
                                    applyNikonCloudPreset(preset)
                                } label: {
                                    HStack {
                                        Text(preset.name)
                                        if selectedNikonCloudPresetID == preset.id {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        }
                    }
                } label: {
                    Label(
                        selectedNikonCloudPreset?.name ?? "尼康云创",
                        systemImage: "cloud.sun"
                    )
                    .lineLimit(1)
                }
                .buttonStyle(NativeButtonStyle(primary: true))
                .disabled(NikonCloudPresetLibrary.presets.isEmpty)

                aiWorkbench
            }
            .padding(12)
        }
        .frame(maxHeight: .infinity)
        .background(Palette.editorPanel)
    }

    private var nikonCloudPreviewNotice: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Label("尼康云创预览", systemImage: "camera.filters")
                    .font(.system(size: TypeScale.body, weight: .semibold))
                    .foregroundStyle(.white)
                Text("内置 \(NikonCloudPresetLibrary.presets.count) 款 NP3")
                    .font(.system(size: TypeScale.caption, design: .monospaced))
                    .foregroundStyle(Palette.editorLabel)
                Spacer()
                Text("设备端 SDR 近似预览 · 相机与 NX Studio 成片可能不同")
                    .font(.system(size: TypeScale.caption))
                    .foregroundStyle(Palette.editorLabel)
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 36)
            Rectangle()
                .fill(Palette.editorRule)
                .frame(height: 1)
        }
        .background(Palette.editorRaised)
    }

    private var preview: some View {
        GeometryReader { proxy in
            let image = selectedSection == .aiTools
                ? (aiResultImage ?? (aiMode == .edit ? selectedOriginalImage : nil))
                : renderedImage
            let imageRect = editorImageRect(
                in: proxy.size,
                imageSize: image?.size
            )
            ZStack(alignment: .topLeading) {
                Rectangle()
                    .fill(Palette.graphite)
                if let image {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(14)
                } else {
                    ContentUnavailableView(
                        "选择一张照片开始编辑",
                        systemImage: "slider.horizontal.3",
                        description: Text(
                            "视频与暂不支持解码的 RAW 文件不会进入编辑列表。"
                        )
                    )
                    .foregroundStyle(.white, Palette.editorLabel)
                }
                if selectedSection == .masks,
                   settings.maskExists,
                   settings.activeMaskLayerIsVisible,
                   !showingOriginal {
                    maskStrokeOverlay(in: imageRect)
                }
                if selectedSection != .aiTools {
                    Text(showingOriginal ? "原图" : "调整后")
                        .font(.system(size: TypeScale.caption, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .frame(minHeight: 28)
                        .background(Palette.hudBgSoft)
                        .clipShape(Capsule())
                        .padding(12)
                } else if image != nil {
                    Text(aiResultImage != nil ? "AI 生成" : "原图")
                        .font(.system(size: TypeScale.caption, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .frame(minHeight: 28)
                        .background(Palette.hudBgSoft)
                        .clipShape(Capsule())
                        .padding(12)
                }
            }
            .coordinateSpace(name: "editorPreview")
            .contentShape(Rectangle())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .contentShape(Rectangle())
        .onTapGesture {
            if pickerArmed { sampleColorAtCenter() }
        }
    }

    private func editorImageRect(
        in container: CGSize,
        imageSize: CGSize?
    ) -> CGRect {
        let available = CGRect(origin: .zero, size: container).insetBy(
            dx: 14,
            dy: 14
        )
        guard let imageSize, imageSize.width > 0, imageSize.height > 0 else {
            return available
        }
        let scale = min(
            available.width / imageSize.width,
            available.height / imageSize.height
        )
        let size = CGSize(
            width: imageSize.width * scale,
            height: imageSize.height * scale
        )
        return CGRect(
            x: available.midX - size.width / 2,
            y: available.midY - size.height / 2,
            width: size.width,
            height: size.height
        )
    }

    @ViewBuilder
    private func maskStrokeOverlay(in imageRect: CGRect) -> some View {
        if let overlay = activeMaskOverlayImage {
            Image(nsImage: overlay)
                .resizable()
                .frame(width: imageRect.width, height: imageRect.height)
                .position(x: imageRect.midX, y: imageRect.midY)
                .allowsHitTesting(false)
        }
        Rectangle()
            .fill(Color.clear)
            .frame(width: imageRect.width, height: imageRect.height)
            .position(x: imageRect.midX, y: imageRect.midY)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(
                    minimumDistance: 0,
                    coordinateSpace: .named("editorPreview")
                )
                    .onChanged { gesture in
                        recordMaskPoint(
                            at: gesture.location,
                            imageRect: imageRect
                        )
                    }
                    .onEnded { _ in activeMaskStrokeID = nil }
            )
    }

    private func recordMaskPoint(at location: CGPoint, imageRect: CGRect) {
        guard selectedSection == .masks,
              settings.maskExists,
              settings.activeMaskLayerIsVisible,
              imageRect.contains(location),
              imageRect.width > 0,
              imageRect.height > 0
        else { return }
        let point = EditorMaskPoint(
            x: Double(min(max((location.x - imageRect.minX) / imageRect.width, 0), 1)),
            y: Double(min(max((location.y - imageRect.minY) / imageRect.height, 0), 1))
        )
        if let activeMaskStrokeID,
           let index = settings.maskStrokes.firstIndex(where: {
               $0.id == activeMaskStrokeID
           }) {
            settings.maskStrokes[index].points.append(point)
        } else {
            let stroke = EditorMaskStroke(
                points: [point],
                mode: settings.maskBrushMode,
                size: settings.maskBrushSize
            )
            settings.maskStrokes.append(stroke)
            activeMaskStrokeID = stroke.id
        }
        status = settings.maskBrushMode == .add
            ? "正在添加蒙版区域"
            : "正在减去蒙版区域"
    }

    private func sampleColorAtCenter() {
        guard let selectedPhoto,
              let source = CIImage(contentsOf: selectedPhoto.url),
              let cg = context.createCGImage(source, from: source.extent.integral)
        else { return }
        let image = NSImage(cgImage: cg, size: NSSize(width: cg.width, height: cg.height))
        guard let rep = NSBitmapImageRep(data: image.tiffRepresentation ?? Data()) else { return }
        let x = max(0, rep.pixelsWide / 2)
        let y = max(0, rep.pixelsHigh / 2)
        guard let sampled = rep.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB) else { return }
        let r = Int((sampled.redComponent * 255).rounded())
        let g = Int((sampled.greenComponent * 255).rounded())
        let b = Int((sampled.blueComponent * 255).rounded())
        settings.pickedColorHex = String(format: "#%02X%02X%02X", r, g, b)
        settings.temperature = Double(b - r) / 2.55
        settings.tint = max(-100, min(100, (Double(g) - Double(r + b) / 2) / 2.55))
        pickerArmed = false
        status = "已取样 \(settings.pickedColorHex) · 已微调色温/色调"
    }

    /// fig2 下带左栏：调色面板 —— 工具条五钮 + 参数区 + 状态行 + 操作行，
    /// 1px 分隔，直角平铺，无卡片包装。
    private var editorColorPanel: some View {
        VStack(spacing: 0) {
            editorToolStrip
            Rectangle()
                .fill(Palette.editorRule)
                .frame(height: 1)
            if selectedSection == .aiTools {
                aiToolsPanel
            } else {
                sectionSelector
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                ScrollView {
                    adjustmentPanel
                        .padding(.horizontal, 12)
                        .padding(.bottom, 8)
                }
            }
            Rectangle()
                .fill(Palette.editorRule)
                .frame(height: 1)
            editorStatusRow
            editorActionRow
        }
    }

    /// fig2 工具图标条：五枚图标+文字单色钮（图标 16pt 与文字同 tint），
    /// 品牌橙标记当前工具；点击只路由既有 selectedSection，无新增状态。
    private var editorToolStrip: some View {
        HStack(spacing: 8) {
            editorToolButton(.wheels, icon: .colorWheel)
            editorToolButton(.curves, icon: .curve)
            editorToolButton(.masks, icon: .mask)
            editorToolButton(.geometry, icon: .geometry)
            editorToolButton(.aiTools, icon: .ai)
            Spacer(minLength: 0)
            if selectedSection == .aiTools, aiResultImage != nil {
                Button { aiResultImage = nil } label: {
                    Label("清除结果", systemImage: "xmark.circle")
                }
                .buttonStyle(NativeButtonStyle())
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private func editorToolButton(
        _ section: EditorAdjustmentSection,
        icon: EditorToolIcon
    ) -> some View {
        let active = selectedSection == section
        let tint = active ? Palette.editorAccent : Palette.editorLabel
        return Button {
            selectedSection = section
        } label: {
            HStack(spacing: 6) {
                EditorToolIconShape(icon: icon)
                    .stroke(
                        tint,
                        style: StrokeStyle(
                            lineWidth: 1.4,
                            lineCap: .round,
                            lineJoin: .round
                        )
                    )
                    .frame(width: 16, height: 16)
                Text(LocalizedStringKey(section.rawValue))
                    .font(.system(size: TypeScale.caption, weight: .semibold))
                    .foregroundStyle(tint)
            }
            .padding(.horizontal, 12)
            .frame(minHeight: 30)
            .background(active ? Palette.editorRaised : Color.clear)
            .overlay {
                Rectangle()
                    .stroke(
                        active ? Palette.editorAccent : Color.clear,
                        lineWidth: 1
                    )
            }
        }
        .buttonStyle(.plain)
    }

    /// fig2 状态行：只读镜像既有 showingOriginal / status 状态，无新增状态。
    private var editorStatusRow: some View {
        HStack(spacing: 10) {
            RuntimeLocalizedText(
                showingOriginal ? "正在查看原图" : "调整不会覆盖原文件"
            )
                .font(.system(size: TypeScale.caption, design: .monospaced))
                .foregroundStyle(Palette.editorLabel)
            Spacer()
            Text(status)
                .lineLimit(1)
                .truncationMode(.middle)
                .font(.system(size: TypeScale.caption, design: .monospaced))
                .foregroundStyle(Palette.editorLabel)
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
    }

    private var editorActionRow: some View {
        HStack(spacing: 10) {
            Button {
                showingOriginal.toggle()
            } label: {
                Label(
                    showingOriginal ? "返回调整" : "查看原图",
                    systemImage: "circle.lefthalf.filled"
                )
            }
            .buttonStyle(NativeButtonStyle())
            Button("全部重置") {
                resetAdjustments()
            }
            .buttonStyle(NativeButtonStyle())
            Spacer()
            Button {
                saveCopy()
            } label: {
                Label(
                    isSaving ? "正在保存…" : "保存高质量副本",
                    systemImage: "square.and.arrow.down"
                )
            }
            .buttonStyle(NativeButtonStyle(primary: true))
            .disabled(selectedPhoto == nil || isSaving)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var aiWorkbench: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("AI 智能修图 · 工作台", systemImage: "sparkles")
                    .font(.system(size: TypeScale.emphasis, weight: .semibold))
                Text("设备端 · 照片不会上传")
                    .font(.system(size: TypeScale.caption, weight: .semibold))
                    .foregroundStyle(Palette.editorAccent)
                    .padding(.horizontal, 7)
                    .frame(minHeight: 22)
                    .background(Palette.editorBg)
                    .overlay {
                        Rectangle()
                            .stroke(Palette.editorAccent.opacity(0.5), lineWidth: 1)
                    }
                Spacer()
                Text("\(Int(aiIntensity * 100))%")
                    .font(.system(size: TypeScale.caption, design: .monospaced))
                    .foregroundStyle(Palette.editorLabel)
            }
            Text(LocalizedStringKey(aiSummaryKey))
                .font(.system(size: TypeScale.caption))
                .foregroundStyle(Palette.editorLabel)
                .fixedSize(horizontal: false, vertical: true)
            if let aiAnalysis {
                HStack(spacing: 6) {
                    aiMetric("曝光", value: aiAnalysis.meanLuma)
                    aiMetric("动态范围", value: aiAnalysis.contrast)
                    aiMetric("色彩", value: aiAnalysis.saturation)
                    aiMetric("细节", value: aiAnalysis.detail)
                }
            }
            Slider(value: $aiIntensity, in: 0.35...1, step: 0.05)
                .tint(Palette.editorAccent)
                .accessibilityLabel("AI 强度")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    Button {
                        analyzeAI()
                    } label: {
                        Label("分析画面", systemImage: "waveform.path.ecg")
                    }
                    .buttonStyle(NativeButtonStyle())
                    .disabled(selectedPhoto == nil)
                Button {
                    applyAIEnhancement()
                } label: {
                    Label("智能优化", systemImage: "wand.and.stars")
                }
                .buttonStyle(NativeButtonStyle(primary: true))
                .disabled(selectedPhoto == nil)
                Button {
                    undoAIEnhancement()
                } label: {
                    Image(systemName: "arrow.uturn.backward")
                }
                .buttonStyle(NativeButtonStyle())
                .help("撤销 AI")
                .disabled(settingsBeforeAI == nil)
                    Button {
                        copiedAISettings = settings
                        status = "已复制 AI 调整，可应用到下一张照片"
                    } label: {
                        Label("复制 AI", systemImage: "doc.on.doc")
                    }
                    .buttonStyle(NativeButtonStyle())
                    .disabled(settingsBeforeAI == nil)
                    Button {
                        guard let copiedAISettings else { return }
                        settings = copiedAISettings
                        selectedPreset = .original
                        selectedNikonCloudPresetID = nil
                        showingOriginal = false
                        status = "已粘贴 AI 调整"
                    } label: {
                        Label("粘贴 AI", systemImage: "doc.on.clipboard")
                    }
                    .buttonStyle(NativeButtonStyle())
                    .disabled(copiedAISettings == nil || selectedPhoto == nil)
                }
            }
        }
        .padding(12)
        .background(Palette.editorRaised)
        .overlay {
            Rectangle()
                .stroke(Palette.editorRule, lineWidth: 1)
        }
    }

    private func aiMetric(_ title: String, value: Double) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(LocalizedStringKey(title))
                .font(.system(size: TypeScale.caption))
                .foregroundStyle(Palette.editorLabel)
            Text("\(Int(max(0, min(1, value)) * 100))%")
                .font(.system(size: TypeScale.caption, weight: .semibold, design: .monospaced))
                .foregroundStyle(Palette.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 7)
        .frame(minHeight: 36)
        .background(Palette.editorBg)
    }

    private var sectionSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 5) {
                ForEach(EditorAdjustmentSection.allCases) { section in
                    Button(LocalizedStringKey(section.rawValue)) {
                        selectedSection = section
                    }
                    .buttonStyle(
                        EditorSectionButtonStyle(
                            selected: selectedSection == section
                        )
                    )
                }
            }
        }
    }

    @ViewBuilder
    private var adjustmentPanel: some View {
        VStack(spacing: 10) {
            switch selectedSection {
            case .light:
                editorSlider(
                    title: "曝光",
                    value: $settings.exposure,
                    range: -2...2,
                    step: 0.05,
                    formatter: { String(format: "%+.2f EV", $0) }
                )
                standardSlider("对比度", value: $settings.contrast)
                standardSlider("高光", value: $settings.highlights)
                standardSlider("阴影", value: $settings.shadows)
                standardSlider("白色色阶", value: $settings.whites)
                standardSlider("黑色色阶", value: $settings.blacks)
            case .color:
                standardSlider("色温", value: $settings.temperature)
                standardSlider("色调", value: $settings.tint)
                standardSlider("自然饱和度", value: $settings.vibrance)
                standardSlider("饱和度", value: $settings.saturation)
            case .wheels:
                colorWheelsControls
            case .curves:
                curvesControls
            case .picker:
                pickerControls
            case .masks:
                maskControls
            case .detail:
                standardSlider("纹理", value: $settings.texture)
                standardSlider("清晰度", value: $settings.clarity)
                editorSlider(
                    title: "锐化",
                    value: $settings.sharpening,
                    range: 0...100,
                    step: 1,
                    formatter: { "\(Int($0))" }
                )
                editorSlider(
                    title: "降噪",
                    value: $settings.noiseReduction,
                    range: 0...100,
                    step: 1,
                    formatter: { "\(Int($0))" }
                )
            case .effects:
                standardSlider("去雾", value: $settings.dehaze)
                standardSlider("暗角", value: $settings.vignette)
            case .geometry:
                geometryControls
            case .aiTools:
                EmptyView()
            }
        }
    }

private var colorWheelsControls: some View {
        VStack(spacing: 12) {
            Text("Lift / Gamma / Gain · 三向色轮").font(.system(size: TypeScale.caption)).foregroundStyle(Palette.editorLabel)
            HStack(spacing: 8) {
                colorWheel("阴影", color: .cyan, x: $settings.liftX, y: $settings.liftY)
                colorWheel("中间调", color: .purple, x: $settings.gammaX, y: $settings.gammaY)
                colorWheel("高光", color: .yellow, x: $settings.gainX, y: $settings.gainY)
            }
            Text("在圆盘内拖动色点调整对应范围").font(.system(size: TypeScale.caption)).foregroundStyle(Palette.editorLabel)
        }
    }

    private func colorWheel(_ title: String, color: Color, x: Binding<Double>, y: Binding<Double>) -> some View {
        VStack(spacing: 5) {
            GeometryReader { proxy in
                let size = min(proxy.size.width, proxy.size.height)
                let center = CGPoint(x: size / 2, y: size / 2)
                ZStack {
                    Circle().fill(Palette.graphite)
                    Circle().stroke(AngularGradient(colors: [.red, .yellow, .green, .cyan, .blue, .purple, .red], center: .center), lineWidth: 5)
                    Circle().stroke(color, lineWidth: 1).padding(7)
                    Circle().fill(color).frame(width: 12, height: 12)
                        .position(
                            x: center.x + CGFloat(x.wrappedValue / 100) * size * 0.38,
                            y: center.y - CGFloat(y.wrappedValue / 100) * size * 0.38
                        )
                }
                .contentShape(Circle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { gesture in
                            let dx = min(max((gesture.location.x - center.x) / (size * 0.38), -1), 1)
                            let dy = min(max((center.y - gesture.location.y) / (size * 0.38), -1), 1)
                            x.wrappedValue = min(max(dx * 100, -100), 100)
                            y.wrappedValue = min(max(dy * 100, -100), 100)
                        }
                )
            }
                .frame(width: 62, height: 62)
            Text(title).font(.system(size: TypeScale.caption, weight: .semibold))
            Text(String(format: "%+.0f, %+.0f", x.wrappedValue, y.wrappedValue)).font(.system(size: TypeScale.caption, design: .monospaced)).foregroundStyle(Palette.editorLabel)
        }.frame(maxWidth: .infinity)
    }

private var curvesControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            GeometryReader { proxy in
                ZStack {
                    Rectangle().fill(Palette.graphite)
                    Path { path in
                        let samples = stride(from: 0.0, through: 1.0, by: 1.0 / 48.0).map { x in
                            CGPoint(x: x * proxy.size.width, y: (1 - curveValue(x)) * proxy.size.height)
                        }
                        guard let first = samples.first else { return }
                        path.move(to: first)
                        for point in samples.dropFirst() { path.addLine(to: point) }
                    }.stroke(Palette.cobalt, lineWidth: 2)
                    Path { path in path.move(to: CGPoint(x: 0, y: proxy.size.height)); path.addLine(to: CGPoint(x: proxy.size.width, y: 0)) }.stroke(.white.opacity(0.25), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    ForEach(settings.curvePoints.indices, id: \.self) { index in
                        let point = settings.curvePoints[index]
                        Circle().fill(Palette.cobalt).frame(width: 10, height: 10)
                            .position(x: point.x * proxy.size.width, y: (1 - point.y) * proxy.size.height)
                    }
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { gesture in
                            let width = max(proxy.size.width, 1)
                            let height = max(proxy.size.height, 1)
                            let x = min(max(gesture.location.x / width, 0), 1)
                            let normalizedY = min(max(1 - gesture.location.y / height, 0), 1)
                            if activeCurvePoint == nil {
                                if let hit = settings.curvePoints.indices.min(by: { a, b in
                                    pow(settings.curvePoints[a].x - x, 2) + pow(settings.curvePoints[a].y - normalizedY, 2)
                                        < pow(settings.curvePoints[b].x - x, 2) + pow(settings.curvePoints[b].y - normalizedY, 2)
                                }), pow(settings.curvePoints[hit].x - x, 2) + pow(settings.curvePoints[hit].y - normalizedY, 2) < 0.035 * 0.035 {
                                    activeCurvePoint = hit
                                } else {
                                    settings.curvePoints.append(EditorCurvePoint(x: x, y: normalizedY))
                                    activeCurvePoint = settings.curvePoints.count - 1
                                }
                            }
                            if let activeCurvePoint, settings.curvePoints.indices.contains(activeCurvePoint) {
                                settings.curvePoints[activeCurvePoint] = EditorCurvePoint(x: x, y: normalizedY)
                            }
                        }
                        .onEnded { _ in activeCurvePoint = nil }
                )
            }
            .frame(height: 150)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            Text("点击任意位置新增控制点，拖动控制点调整曲线")
                .font(.system(size: TypeScale.caption)).foregroundStyle(Palette.editorLabel)
        }
    }

    private var pickerControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("在预览画面点击取样色彩，自动微调色温与色调").font(.system(size: TypeScale.caption)).foregroundStyle(Palette.editorLabel)
            Button { pickerArmed.toggle(); status = pickerArmed ? "取色器已启用，请点击预览画面" : "取色器已关闭" } label: {
                Label(pickerArmed ? "点击预览取色 · 再次关闭" : "取色器", systemImage: "eyedropper")
            }.buttonStyle(NativeButtonStyle(primary: pickerArmed))
            Text(settings.pickedColorHex).font(.system(size: TypeScale.body, design: .monospaced)).foregroundStyle(Palette.editorLabel)
        }
    }

    private var maskControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("蒙版列表")
                .font(.system(size: TypeScale.body, weight: .semibold))
            if settings.maskLayers.isEmpty {
                Text("暂无蒙版")
                    .font(.system(size: TypeScale.caption))
                    .foregroundStyle(Palette.editorLabel)
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            } else {
                VStack(spacing: 6) {
                    ForEach(settings.maskLayers) { layer in
                        let displayed = settings.displayedMaskLayer(layer)
                        HStack(spacing: 8) {
                            Button {
                                settings.selectMaskLayer(layer.id)
                                activeMaskStrokeID = nil
                                status = "已切换到 \(layer.name)"
                            } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(layer.name)
                                        .font(.system(size: TypeScale.body, weight: .semibold))
                                    Text(LocalizedStringKey(displayed.type))
                                        .font(.system(size: TypeScale.caption))
                                        .foregroundStyle(Palette.muted)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            Toggle("", isOn: Binding(
                                get: { layer.isVisible },
                                set: { visible in
                                    settings.setMaskLayerVisible(layer.id, visible)
                                    activeMaskStrokeID = nil
                                    status = visible ? "蒙版已显示" : "蒙版已隐藏"
                                }
                            ))
                            .labelsHidden()
                            .accessibilityLabel(layer.isVisible ? "隐藏蒙版" : "显示蒙版")
                        }
                        .padding(.horizontal, 10)
                        .frame(minHeight: 46)
                        .background(
                            settings.activeMaskLayerID == layer.id
                                ? Palette.cobalt.opacity(0.12)
                                : Palette.surface
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay {
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(
                                    settings.activeMaskLayerID == layer.id
                                        ? Palette.cobalt.opacity(0.45)
                                        : Color.clear,
                                    lineWidth: 1
                                )
                        }
                    }
                }
            }
            HStack(spacing: 8) {
                Button {
                    settings.createMaskLayer()
                    activeMaskStrokeID = nil
                    status = "蒙版已创建 · 在预览画面涂抹"
                } label: {
                    Label("创建蒙版", systemImage: "plus.square.on.square")
                }
                .buttonStyle(NativeButtonStyle(primary: !settings.maskExists))
                Button(role: .destructive) {
                    settings.deleteActiveMaskLayer()
                    activeMaskStrokeID = nil
                    status = "蒙版已删除"
                } label: {
                    Label("删除蒙版", systemImage: "trash")
                }
                .buttonStyle(NativeButtonStyle())
                .disabled(!settings.maskExists)
            }
            HStack(spacing: 8) {
                Button {
                    settings.ensureMaskLayer()
                    if settings.maskType == "无" {
                        settings.maskType = "画笔"
                    }
                    settings.maskBrushMode = .add
                    status = "添加蒙版画笔已启用"
                } label: {
                    Label("添加蒙版（画笔）", systemImage: "paintbrush.pointed")
                }
                .buttonStyle(NativeButtonStyle(primary: settings.maskExists && settings.maskBrushMode == .add))
                Button {
                    settings.ensureMaskLayer()
                    if settings.maskType == "无" {
                        settings.maskType = "画笔"
                    }
                    settings.maskBrushMode = .subtract
                    status = "减去蒙版画笔已启用"
                } label: {
                    Label("减去蒙版（画笔）", systemImage: "eraser")
                }
                .buttonStyle(NativeButtonStyle(primary: settings.maskExists && settings.maskBrushMode == .subtract))
            }
            Text("智能识别")
                .font(.system(size: TypeScale.caption, weight: .semibold))
                .foregroundStyle(Palette.editorLabel)
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 104), spacing: 8)],
                spacing: 8
            ) {
                ForEach(
                    ["智能主体", "智能天空", "智能背景", "智能人物", "智能亮部", "智能暗部"],
                    id: \.self
                ) { type in
                    Button(type) {
                        settings.ensureMaskLayer()
                        settings.maskType = type
                        settings.maskAmount = 100
                        settings.maskInvert = false
                        settings.maskStrokes.removeAll()
                        activeMaskStrokeID = nil
                        status = String(localized: "智能蒙版已创建 · 可继续添加或减去画笔")
                    }
                    .buttonStyle(NativeButtonStyle(primary: settings.maskType == type))
                }
            }
            editorMenuPicker(
                current: settings.maskType,
                options: ["无", "画笔", "线性渐变", "径向渐变", "智能主体", "智能天空", "智能背景", "智能人物", "智能亮部", "智能暗部"],
                display: { $0 },
                apply: { settings.maskType = $0 }
            )
            .onChange(of: settings.maskType) {
                settings.maskExists = settings.maskType != "无"
                if settings.maskExists && settings.maskAmount == 0 {
                    settings.maskAmount = 100
                }
            }
            editorSlider(title: "强度", value: $settings.maskAmount, range: 0...100, step: 1, formatter: { "\(Int($0))%" })
            editorSlider(title: "羽化", value: $settings.maskFeather, range: 0...100, step: 1, formatter: { "\(Int($0))" })
            editorSlider(title: "画笔大小", value: $settings.maskBrushSize, range: 4...64, step: 1, formatter: { "\(Int($0))" })
            Button {
                settings.maskInvert.toggle()
                status = settings.maskInvert ? "蒙版已反向" : "蒙版已恢复正向"
            } label: {
                Label("反向蒙版", systemImage: "circle.lefthalf.filled.inverse")
            }
            .buttonStyle(NativeButtonStyle(primary: settings.maskInvert))
            Divider()
            Text("蒙版内调整")
                .foregroundStyle(Palette.editorLabel)
                .font(.system(size: TypeScale.body, weight: .semibold))
            editorSlider(title: "曝光", value: $settings.maskExposure, range: -2...2, step: 0.05, formatter: { String(format: "%+.2f EV", $0) })
            standardSlider("对比度", value: $settings.maskContrast)
            standardSlider("高光", value: $settings.maskHighlights)
            standardSlider("阴影", value: $settings.maskShadows)
            standardSlider("色温", value: $settings.maskTemperature)
            standardSlider("色调", value: $settings.maskTint)
            standardSlider("饱和度", value: $settings.maskSaturation)
            standardSlider("清晰度", value: $settings.maskClarity)
            Text(settings.maskExists
                ? "蓝色显示当前蒙版覆盖；橡皮会擦除蓝色区域。"
                : "先创建蒙版，再选择添加或减去画笔。")
                .font(.system(size: TypeScale.caption))
                .foregroundStyle(Palette.editorLabel)
        }
    }

    private func standardSlider(
        _ title: String,
        value: Binding<Double>
    ) -> some View {
        editorSlider(
            title: title,
            value: value,
            range: -100...100,
            step: 1,
            formatter: { String(format: "%+.0f", $0) }
        )
    }

    private var geometryControls: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("裁切比例")
                .font(.system(size: TypeScale.body, weight: .semibold))
                .foregroundStyle(Palette.editorLabel)
            editorMenuPicker(
                current: settings.cropRatio,
                options: EditorCropRatio.allCases,
                display: { $0.rawValue },
                apply: { settings.cropRatio = $0 }
            )
            HStack(spacing: 6) {
                Button {
                    settings.rotation = (settings.rotation + 90) % 360
                } label: {
                    Image(systemName: "rotate.right")
                }
                Button {
                    settings.flipHorizontal.toggle()
                } label: {
                    Image(systemName: "arrow.left.and.right")
                }
                Button {
                    settings.flipVertical.toggle()
                } label: {
                    Image(systemName: "arrow.up.and.down")
                }
            }
            .buttonStyle(NativeButtonStyle())
            Text("旋转 90° · 水平翻转 · 垂直翻转")
                .font(.system(size: TypeScale.caption))
                .foregroundStyle(Palette.editorLabel)
        }
    }

    private var renderedImage: NSImage? {
        guard let selectedPhoto else { return nil }
        let source =
            CIImage(contentsOf: selectedPhoto.url)
            ?? NSImage(contentsOf: selectedPhoto.url)
                .flatMap {
                    CIImage(data: $0.tiffRepresentation ?? Data())
                }
        guard var output = source else { return nil }

        if !showingOriginal {
            output = applyTonePipeline(to: output)
            output = applyGeometry(to: output)
            output = applyingEditorMask(to: output)
        }
        let extent = output.extent.integral
        guard let cgImage = context.createCGImage(output, from: extent) else {
            return nil
        }
        return NSImage(
            cgImage: cgImage,
            size: NSSize(width: extent.width, height: extent.height)
        )
    }

    private var selectedOriginalImage: NSImage? {
        guard let selectedPhoto else { return nil }
        return NSImage(contentsOf: selectedPhoto.url)
    }

    private var activeMaskOverlayImage: NSImage? {
        guard let selectedPhoto,
              let layer = settings.activeDisplayedMaskLayer(),
              layer.isVisible,
              layer.type != "无",
              let source = CIImage(contentsOf: selectedPhoto.url)
                ?? NSImage(contentsOf: selectedPhoto.url).flatMap({ image in
                    CIImage(data: image.tiffRepresentation ?? Data())
                })
        else { return nil }
        let base = applyGeometry(to: applyTonePipeline(to: source))
        let extent = base.extent.integral
        guard let mask = editorMaskImage(
            source: base,
            extent: extent,
            layer: layer
        ) else { return nil }
        let blue = CIImage(color: CIColor(
            red: 22.0 / 255,
            green: 115.0 / 255,
            blue: 230.0 / 255,
            alpha: 0.58
        )).cropped(to: extent)
        let clear = CIImage(color: CIColor(
            red: 0,
            green: 0,
            blue: 0,
            alpha: 0
        )).cropped(to: extent)
        let overlay = filtered(
            "CIBlendWithMask",
            image: blue,
            values: [
                kCIInputBackgroundImageKey: clear,
                kCIInputMaskImageKey: mask
            ]
        )
        guard let cgImage = context.createCGImage(overlay, from: extent) else {
            return nil
        }
        return NSImage(
            cgImage: cgImage,
            size: NSSize(width: extent.width, height: extent.height)
        )
    }

    private func applyTonePipeline(to source: CIImage) -> CIImage {
        var output = source
        output = filtered(
            "CIExposureAdjust",
            image: output,
            values: [kCIInputEVKey: settings.exposure]
        )
        output = filtered(
            "CITemperatureAndTint",
            image: output,
            values: [
                "inputNeutral": CIVector(x: 6500, y: 0),
                "inputTargetNeutral": CIVector(
                    x: 6500 + settings.temperature * 24,
                    y: settings.tint * 1.5
                )
            ]
        )
        output = filtered(
            "CIHighlightShadowAdjust",
            image: output,
            values: [
                "inputHighlightAmount":
                    max(0, min(2, 1 + settings.highlights / 100)),
                "inputShadowAmount": settings.shadows / 100
            ]
        )
        output = filtered(
            "CIVibrance",
            image: output,
            values: ["inputAmount": settings.vibrance / 100]
        )
        let combinedContrast =
            settings.contrast / 100
            + settings.dehaze / 260
            + settings.clarity / 420
        let combinedSaturation =
            settings.saturation / 100
            + settings.dehaze / 500
        output = filtered(
            "CIColorControls",
            image: output,
            values: [
                kCIInputContrastKey: max(0, 1 + combinedContrast),
                kCIInputSaturationKey: max(0, 1 + combinedSaturation)
            ]
        )
        output = applyingGradingCube(to: output)
        if settings.curvePoints.count > 2 {
            let dimension = 16
            var cube = [Float]()
            cube.reserveCapacity(dimension * dimension * dimension * 4)
            for blue in 0..<dimension {
                for green in 0..<dimension {
                    for red in 0..<dimension {
                        let r = Double(red) / Double(dimension - 1)
                        let g = Double(green) / Double(dimension - 1)
                        let b = Double(blue) / Double(dimension - 1)
                        let luma = r * 0.2126 + g * 0.7152 + b * 0.0722
                        let delta = curveValue(luma) - luma
                        cube += [Float(max(0, min(1, r + delta))), Float(max(0, min(1, g + delta))), Float(max(0, min(1, b + delta))), 1]
                    }
                }
            }
            let cubeData = cube.withUnsafeBufferPointer { Data(buffer: $0) }
            output = filtered("CIColorCube", image: output, values: [
                "inputCubeDimension": dimension,
                "inputCubeData": cubeData
            ])
        }
        let gain = max(0.4, 1 + settings.whites / 260)
        let lift = settings.blacks / 850
        let tintShift = settings.tint / 1800
        output = filtered(
            "CIColorMatrix",
            image: output,
            values: [
                "inputRVector": CIVector(x: gain, y: 0, z: 0, w: 0),
                "inputGVector": CIVector(x: 0, y: gain, z: 0, w: 0),
                "inputBVector": CIVector(x: 0, y: 0, z: gain, w: 0),
                "inputBiasVector": CIVector(
                    x: lift + tintShift,
                    y: lift - tintShift,
                    z: lift + tintShift,
                    w: 0
                )
            ]
        )
        if settings.texture > 0 {
            output = filtered(
                "CIUnsharpMask",
                image: output,
                values: [
                    kCIInputRadiusKey: 1.2,
                    kCIInputIntensityKey: settings.texture / 140
                ]
            )
        } else if settings.texture < 0 {
            let extent = output.extent
            output = filtered(
                "CIGaussianBlur",
                image: output,
                values: [
                    kCIInputRadiusKey: -settings.texture / 75
                ]
            )
            .cropped(to: extent)
        }
        if settings.clarity > 0 {
            output = filtered(
                "CIUnsharpMask",
                image: output,
                values: [
                    kCIInputRadiusKey: 8,
                    kCIInputIntensityKey: settings.clarity / 180
                ]
            )
        }
        if settings.sharpening > 0 {
            output = filtered(
                "CISharpenLuminance",
                image: output,
                values: [
                    kCIInputSharpnessKey: settings.sharpening / 70
                ]
            )
        }
        if settings.noiseReduction > 0 {
            output = filtered(
                "CINoiseReduction",
                image: output,
                values: [
                    "inputNoiseLevel":
                        0.02 + settings.noiseReduction / 1250,
                    "inputSharpness":
                        max(0, 0.4 - settings.noiseReduction / 300)
                ]
            )
        }
        if settings.vignette != 0 {
            output = filtered(
                "CIVignette",
                image: output,
                values: [
                    kCIInputIntensityKey: -settings.vignette / 45,
                    kCIInputRadiusKey:
                        min(output.extent.width, output.extent.height) * 0.75
                ]
            )
        }
        return output
    }

    private func applyingEditorMask(
        to base: CIImage
    ) -> CIImage {
        settings.effectiveMaskLayers()
            .filter { $0.isVisible && $0.type != "无" }
            .reduce(base) { image, layer in
                applyingEditorMaskLayer(to: image, layer: layer)
            }
    }

    private func applyingEditorMaskLayer(
        to base: CIImage,
        layer: EditorMaskLayer
    ) -> CIImage {
        guard
              let mask = editorMaskImage(
                  source: base,
                  extent: base.extent.integral,
                  layer: layer
              )
        else { return base }
        var local = base
        if layer.exposure != 0 {
            local = filtered(
                "CIExposureAdjust",
                image: local,
                values: [kCIInputEVKey: layer.exposure]
            )
        }
        if layer.temperature != 0 || layer.tint != 0 {
            local = filtered(
                "CITemperatureAndTint",
                image: local,
                values: [
                    "inputNeutral": CIVector(x: 6500, y: 0),
                    "inputTargetNeutral": CIVector(
                        x: 6500 + layer.temperature * 24,
                        y: layer.tint * 1.5
                    )
                ]
            )
        }
        if layer.highlights != 0 || layer.shadows != 0 {
            local = filtered(
                "CIHighlightShadowAdjust",
                image: local,
                values: [
                    "inputHighlightAmount": max(
                        0,
                        min(2, 1 + layer.highlights / 100)
                    ),
                    "inputShadowAmount": layer.shadows / 100
                ]
            )
        }
        if layer.contrast != 0 || layer.saturation != 0 {
            local = filtered(
                "CIColorControls",
                image: local,
                values: [
                    kCIInputContrastKey: max(
                        0,
                        1 + layer.contrast / 100
                    ),
                    kCIInputSaturationKey: max(
                        0,
                        1 + layer.saturation / 100
                    )
                ]
            )
        }
        if layer.clarity > 0 {
            local = filtered(
                "CIUnsharpMask",
                image: local,
                values: [
                    kCIInputRadiusKey: 8,
                    kCIInputIntensityKey: layer.clarity / 180
                ]
            )
        } else if layer.clarity < 0 {
            local = filtered(
                "CIGaussianBlur",
                image: local,
                values: [kCIInputRadiusKey: -layer.clarity / 70]
            ).cropped(to: base.extent)
        }
        return filtered(
            "CIBlendWithMask",
            image: local,
            values: [
                kCIInputBackgroundImageKey: base,
                kCIInputMaskImageKey: mask
            ]
        )
    }

    private func editorMaskImage(
        source: CIImage,
        extent: CGRect,
        layer: EditorMaskLayer
    ) -> CIImage? {
        let width = max(1, Int(extent.width.rounded()))
        let height = max(1, Int(extent.height.rounded()))
        let colorSpace = CGColorSpaceCreateDeviceGray()
        guard let bitmap = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else { return nil }
        bitmap.setFillColor(gray: 0, alpha: 1)
        bitmap.fill(CGRect(x: 0, y: 0, width: width, height: height))
        if let gradient = CGGradient(
            colorsSpace: colorSpace,
            colors: [
                CGColor(gray: 1, alpha: 1),
                CGColor(gray: 0, alpha: 1)
            ] as CFArray,
            locations: [0, 1]
        ) {
            if layer.type == "线性渐变" {
                bitmap.drawLinearGradient(
                    gradient,
                    start: CGPoint(x: 0, y: height),
                    end: CGPoint(x: 0, y: 0),
                    options: []
                )
            } else if layer.type == "径向渐变" {
                bitmap.drawRadialGradient(
                    gradient,
                    startCenter: CGPoint(x: width / 2, y: height / 2),
                    startRadius: 0,
                    endCenter: CGPoint(x: width / 2, y: height / 2),
                    endRadius: CGFloat(min(width, height)) * 0.56,
                    options: [.drawsAfterEndLocation]
                )
            }
        }
        guard let cgMask = bitmap.makeImage() else { return nil }
        var mask = CIImage(cgImage: cgMask)
            .transformed(by: CGAffineTransform(
                translationX: extent.minX,
                y: extent.minY
            ))
        let smartKinds: [String: CGFloat] = [
            "智能主体": 1,
            "主体": 1,
            "智能天空": 2,
            "智能背景": 3,
            "智能人物": 4,
            "智能亮部": 5,
            "智能暗部": 6
        ]
        if let kind = smartKinds[layer.type],
           let smart = editorSmartMaskKernel?.apply(
               extent: extent,
               arguments: [
                   source,
                   kind,
                   CIVector(x: extent.minX, y: extent.minY),
                   CIVector(x: extent.width, y: extent.height)
               ]
           ) {
            mask = smart
        }
        if let additions = editorStrokeMaskImage(
            mode: .add,
            extent: extent,
            strokes: layer.strokes
        ) {
            mask = filtered(
                "CIMaximumCompositing",
                image: mask,
                values: [kCIInputBackgroundImageKey: additions]
            )
        }
        if let removals = editorStrokeMaskImage(
            mode: .subtract,
            extent: extent,
            strokes: layer.strokes
        ) {
            let inverseRemovals = filtered(
                "CIColorMatrix",
                image: removals,
                values: [
                    "inputRVector": CIVector(x: -1, y: 0, z: 0, w: 0),
                    "inputGVector": CIVector(x: 0, y: -1, z: 0, w: 0),
                    "inputBVector": CIVector(x: 0, y: 0, z: -1, w: 0),
                    "inputBiasVector": CIVector(x: 1, y: 1, z: 1, w: 0)
                ]
            )
            mask = filtered(
                "CIMultiplyCompositing",
                image: mask,
                values: [kCIInputBackgroundImageKey: inverseRemovals]
            )
        }
        if layer.feather > 0 {
            mask = filtered(
                "CIGaussianBlur",
                image: mask,
                values: [
                    kCIInputRadiusKey: max(
                        0.5,
                        layer.feather / 100
                            * Double(min(width, height)) * 0.03
                    )
                ]
            ).cropped(to: extent)
        }
        if layer.invert {
            mask = filtered(
                "CIColorMatrix",
                image: mask,
                values: [
                    "inputRVector": CIVector(x: -1, y: 0, z: 0, w: 0),
                    "inputGVector": CIVector(x: 0, y: -1, z: 0, w: 0),
                    "inputBVector": CIVector(x: 0, y: 0, z: -1, w: 0),
                    "inputBiasVector": CIVector(x: 1, y: 1, z: 1, w: 0)
                ]
            )
        }
        if layer.amount < 100 {
            let amount = max(0, layer.amount / 100)
            mask = filtered(
                "CIColorMatrix",
                image: mask,
                values: [
                    "inputRVector": CIVector(x: amount, y: 0, z: 0, w: 0),
                    "inputGVector": CIVector(x: 0, y: amount, z: 0, w: 0),
                    "inputBVector": CIVector(x: 0, y: 0, z: amount, w: 0)
                ]
            )
        }
        return mask
    }

    private func editorStrokeMaskImage(
        mode: EditorMaskBrushMode,
        extent: CGRect,
        strokes allStrokes: [EditorMaskStroke]
    ) -> CIImage? {
        let strokes = allStrokes.filter { $0.mode == mode }
        guard !strokes.isEmpty else { return nil }
        let width = max(1, Int(extent.width.rounded()))
        let height = max(1, Int(extent.height.rounded()))
        guard let bitmap = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else { return nil }
        bitmap.setFillColor(gray: 0, alpha: 1)
        bitmap.fill(CGRect(x: 0, y: 0, width: width, height: height))
        bitmap.setStrokeColor(gray: 1, alpha: 1)
        bitmap.setFillColor(gray: 1, alpha: 1)
        bitmap.setLineCap(.round)
        bitmap.setLineJoin(.round)
        for stroke in strokes {
            bitmap.setLineWidth(max(
                1,
                CGFloat(stroke.size) / 100 * CGFloat(min(width, height))
            ))
            guard let first = stroke.points.first else { continue }
            let start = CGPoint(
                x: CGFloat(first.x) * CGFloat(width),
                y: (1 - CGFloat(first.y)) * CGFloat(height)
            )
            bitmap.beginPath()
            bitmap.move(to: start)
            for point in stroke.points.dropFirst() {
                bitmap.addLine(to: CGPoint(
                    x: CGFloat(point.x) * CGFloat(width),
                    y: (1 - CGFloat(point.y)) * CGFloat(height)
                ))
            }
            bitmap.strokePath()
            if stroke.points.count == 1 {
                let radius = max(
                    0.5,
                    CGFloat(stroke.size) / 200 * CGFloat(min(width, height))
                )
                bitmap.fillEllipse(in: CGRect(
                    x: start.x - radius,
                    y: start.y - radius,
                    width: radius * 2,
                    height: radius * 2
                ))
            }
        }
        guard let image = bitmap.makeImage() else { return nil }
        return CIImage(cgImage: image).transformed(by: CGAffineTransform(
            translationX: extent.minX,
            y: extent.minY
        ))
    }

    private func filtered(
        _ name: String,
        image: CIImage,
        values: [String: Any]
    ) -> CIImage {
        guard let filter = CIFilter(name: name) else { return image }
        filter.setValue(image, forKey: kCIInputImageKey)
        values.forEach { filter.setValue($0.value, forKey: $0.key) }
        return filter.outputImage ?? image
    }

    private func curveValue(_ input: Double) -> Double {
        let x = min(max(input, 0), 1)
        let points = settings.curvePoints.sorted { $0.x < $1.x }
        guard points.count > 1 else { return x }
        if x <= points[0].x { return points[0].y }
        if x >= points[points.count - 1].x { return points[points.count - 1].y }
        let index = max(1, points.firstIndex { $0.x >= x } ?? 1)
        let p0 = points[max(0, index - 2)]
        let p1 = points[index - 1]
        let p2 = points[index]
        let p3 = points[min(points.count - 1, index + 1)]
        let t = (x - p1.x) / max(0.0001, p2.x - p1.x)
        let t2 = t * t
        let t3 = t2 * t
        let y = 0.5 * ((2 * p1.y) + (-p0.y + p2.y) * t + (2 * p0.y - 5 * p1.y + 4 * p2.y - p3.y) * t2 + (-p0.y + 3 * p1.y - 3 * p2.y + p3.y) * t3)
        return min(max(y, 0), 1)
    }

    private func applyingGradingCube(to image: CIImage) -> CIImage {
        let dimension = 16
        let cloudPreset = selectedNikonCloudPreset
        var cube = [Float]()
        cube.reserveCapacity(dimension * dimension * dimension * 4)
        for blue in 0..<dimension {
            for green in 0..<dimension {
                for red in 0..<dimension {
                    var r = Double(red) / Double(dimension - 1)
                    var g = Double(green) / Double(dimension - 1)
                    var b = Double(blue) / Double(dimension - 1)
                    let luma = r * 0.2126 + g * 0.7152 + b * 0.0722
                    let shadows = pow(1 - luma, 2)
                    let midtones = 1 - abs(luma * 2 - 1)
                    let highlights = pow(luma, 2)
                    let x = settings.liftX / 800 * shadows + settings.gammaX / 800 * midtones + settings.gainX / 800 * highlights
                    let y = settings.liftY / 800 * shadows + settings.gammaY / 800 * midtones + settings.gainY / 800 * highlights
                    r += x - y * 0.5
                    g += y - x * 0.5
                    b -= (x + y) * 0.5
                    if let cloudPreset {
                        let mixed = cloudPreset.applyingColorMixer(
                            red: r,
                            green: g,
                            blue: b
                        )
                        r = mixed.red
                        g = mixed.green
                        b = mixed.blue
                    }
                    cube += [Float(max(0, min(1, r))), Float(max(0, min(1, g))), Float(max(0, min(1, b))), 1]
                }
            }
        }
        return filtered("CIColorCube", image: image, values: [
            "inputCubeDimension": dimension,
            "inputCubeData": cube.withUnsafeBufferPointer { Data(buffer: $0) }
        ])
    }

    private func applyGeometry(to source: CIImage) -> CIImage {
        var output = source
        if settings.rotation != 0 {
            output = output.transformed(
                by: CGAffineTransform(
                    rotationAngle:
                        CGFloat(settings.rotation) * .pi / 180
                )
            )
            output = normalized(output)
        }
        if settings.flipHorizontal {
            output = output.transformed(
                by: CGAffineTransform(scaleX: -1, y: 1)
            )
            output = normalized(output)
        }
        if settings.flipVertical {
            output = output.transformed(
                by: CGAffineTransform(scaleX: 1, y: -1)
            )
            output = normalized(output)
        }
        if let ratio = settings.cropRatio.value {
            let extent = output.extent
            var width = extent.width
            var height = width / ratio
            if height > extent.height {
                height = extent.height
                width = height * ratio
            }
            output = output.cropped(
                to: CGRect(
                    x: extent.midX - width / 2,
                    y: extent.midY - height / 2,
                    width: width,
                    height: height
                )
            )
            output = normalized(output)
        }
        return output
    }

    private func normalized(_ image: CIImage) -> CIImage {
        let extent = image.extent
        return image.transformed(
            by: CGAffineTransform(
                translationX: -extent.minX,
                y: -extent.minY
            )
        )
    }

    /// fig2 恒深面上的下拉控件（同 MonitorControlDeck 机制）。
    private func editorMenuPicker<T: Hashable>(
        current: T,
        options: [T],
        display: @escaping (T) -> String,
        apply: @escaping (T) -> Void
    ) -> some View {
        Menu {
            ForEach(options, id: \.self) { option in
                Button {
                    apply(option)
                } label: {
                    Text(display(option))
                }
            }
        } label: {
            HStack(spacing: 6) {
                Text(display(current))
                    .font(.system(size: TypeScale.body))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .semibold)) // 图标尺寸，不受 TypeScale 约束
                    .foregroundStyle(Palette.editorLabel)
            }
            .padding(.horizontal, 10)
            .frame(height: 30)
            .background(Palette.editorRaised, in: RoundedRectangle(cornerRadius: 7))
        }
        .menuStyle(.borderlessButton)
    }

    private func editorSlider(
        title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double,
        formatter: @escaping (Double) -> String
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(LocalizedStringKey(title))
                    .font(.system(size: TypeScale.body, weight: .semibold))
                    .foregroundStyle(Palette.editorLabel)
                Spacer()
                Text(formatter(value.wrappedValue))
                    .font(.system(size: TypeScale.caption, design: .monospaced))
                    .foregroundStyle(Palette.editorLabel)
            }
            Slider(value: value, in: range, step: step)
                .tint(Palette.editorAccent)
        }
        .frame(minHeight: 46)
    }

    private func selectInitialPhoto() {
        if let selected = model.selectedPhoto,
           photos.contains(where: { $0.url == selected.url }) {
            selectedPhotoURL = selected.url
        } else if selectedPhoto == nil {
            selectedPhotoURL = photos.first?.url
        }
    }

    private func resetAdjustments() {
        settings = ProfessionalEditSettings()
        selectedPreset = .original
        selectedNikonCloudPresetID = nil
        showingOriginal = false
        settingsBeforeAI = nil
        aiSummaryKey = "等待分析当前照片"
        aiAnalysis = nil
    }

    private func analyzeAI() {
        guard let selectedPhoto,
              let source = CIImage(contentsOf: selectedPhoto.url),
              let analysis = analyzeForAI(source)
        else {
            status = "无法分析当前照片"
            return
        }
        aiAnalysis = analysis
        aiSummaryKey = analysis.summaryKey
        status = "画面分析完成 · 可应用 AI 建议"
    }

    private func applyAIEnhancement() {
        guard let selectedPhoto,
              let source = CIImage(contentsOf: selectedPhoto.url),
              let analysis = aiAnalysis ?? analyzeForAI(source)
        else {
            status = "无法分析当前照片"
            return
        }
        settingsBeforeAI = settings
        suppressPresetApply = true
        selectedPreset = .original
        settings.applyAI(analysis, intensity: aiIntensity)
        selectedNikonCloudPresetID = nil
        showingOriginal = false
        aiSummaryKey = analysis.summaryKey
        aiAnalysis = analysis
        status = "AI 优化已应用 · 可继续微调"
        DispatchQueue.main.async {
            suppressPresetApply = false
        }
    }

    private func applyNikonCloudPreset(_ preset: NikonCloudPreset) {
        suppressPresetApply = true
        selectedPreset = .original
        let tone = preset.tone
        settings.resetTone()
        settings.contrast = tone.contrast
        settings.highlights = tone.highlights
        settings.shadows = tone.shadows
        settings.whites = tone.whites
        settings.blacks = tone.blacks
        settings.saturation = tone.saturation
        settings.texture = tone.texture
        settings.clarity = tone.clarity
        settings.sharpening = tone.sharpening
        settings.liftX = preset.grading.lift.x
        settings.liftY = preset.grading.lift.y
        settings.gammaX = preset.grading.gamma.x
        settings.gammaY = preset.grading.gamma.y
        settings.gainX = preset.grading.gain.x
        settings.gainY = preset.grading.gain.y
        if preset.toneCurve.count > 1 {
            let denominator = Double(preset.toneCurve.count - 1)
            settings.curvePoints = preset.toneCurve.enumerated().map {
                EditorCurvePoint(
                    x: Double($0.offset) / denominator,
                    y: min(max($0.element, 0), 1)
                )
            }
        }
        selectedNikonCloudPresetID = preset.id
        settingsBeforeAI = nil
        aiAnalysis = nil
        aiSummaryKey = "等待分析当前照片"
        showingOriginal = false
        status = "尼康云创预览 · \(preset.name) · SDR 近似"
        DispatchQueue.main.async { suppressPresetApply = false }
    }

    private func undoAIEnhancement() {
        guard let previous = settingsBeforeAI else { return }
        settings = previous
        settingsBeforeAI = nil
        aiSummaryKey = "已撤销 AI 优化"
        status = "已恢复 AI 优化前的参数"
    }

    private func analyzeForAI(_ source: CIImage) -> EditorAIAnalysis? {
        let size = 96
        let normalizedSource = normalized(source)
        guard normalizedSource.extent.width > 0,
              normalizedSource.extent.height > 0
        else { return nil }
        let sample = normalizedSource.transformed(
            by: CGAffineTransform(
                scaleX: CGFloat(size) / normalizedSource.extent.width,
                y: CGFloat(size) / normalizedSource.extent.height
            )
        )
        var pixels = [UInt8](repeating: 0, count: size * size * 4)
        pixels.withUnsafeMutableBytes { buffer in
            guard let address = buffer.baseAddress else { return }
            context.render(
                sample,
                toBitmap: address,
                rowBytes: size * 4,
                bounds: CGRect(x: 0, y: 0, width: size, height: size),
                format: .RGBA8,
                colorSpace: CGColorSpaceCreateDeviceRGB()
            )
        }
        var lumas = [Double](repeating: 0, count: size * size)
        var red = 0.0
        var green = 0.0
        var blue = 0.0
        var saturation = 0.0
        var shadows = 0.0
        var highlights = 0.0
        for index in 0..<(size * size) {
            let offset = index * 4
            let r = Double(pixels[offset]) / 255
            let g = Double(pixels[offset + 1]) / 255
            let b = Double(pixels[offset + 2]) / 255
            let luma = r * 0.2126 + g * 0.7152 + b * 0.0722
            lumas[index] = luma
            red += r
            green += g
            blue += b
            saturation += max(r, g, b) - min(r, g, b)
            if luma < 0.10 { shadows += 1 }
            if luma > 0.90 { highlights += 1 }
        }
        let count = Double(size * size)
        let mean = lumas.reduce(0, +) / count
        let variance = lumas.reduce(0) { partial, value in
            partial + pow(value - mean, 2)
        } / count
        var detail = 0.0
        for y in 0..<size {
            for x in 1..<size {
                let index = y * size + x
                detail += abs(lumas[index] - lumas[index - 1])
            }
        }
        return EditorAIAnalysis(
            meanLuma: mean,
            contrast: sqrt(variance),
            shadowRatio: shadows / count,
            highlightRatio: highlights / count,
            saturation: saturation / count,
            red: red / count,
            green: green / count,
            blue: blue / count,
            detail: detail / Double(size * (size - 1))
        )
    }

    private func saveCopy() {
        let wasShowingOriginal = showingOriginal
        showingOriginal = false
        guard let selectedPhoto,
              let renderedImage,
              let cgImage = renderedImage.cgImage(
                forProposedRect: nil,
                context: nil,
                hints: nil
              )
        else {
            showingOriginal = wasShowingOriginal
            status = "无法渲染当前照片"
            return
        }
        let representation = NSBitmapImageRep(cgImage: cgImage)
        guard let data = representation.representation(
            using: .jpeg,
            properties: [.compressionFactor: 0.95]
        ) else {
            showingOriginal = wasShowingOriginal
            status = "无法编码编辑副本"
            return
        }
        isSaving = true
        if let saved = model.saveEditedPhoto(
            data,
            originalFilename: selectedPhoto.name
        ) {
            selectedPhotoURL = saved
            resetAdjustments()
            status = "已保存高质量副本 · \(saved.lastPathComponent)"
        } else {
            status = model.errorMessage ?? "保存编辑副本失败"
            showingOriginal = wasShowingOriginal
        }
        isSaving = false
    }

    private func generateAi() {
        guard !aiPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { status = "请输入提示词"; return }
        guard let code = ActivationManager.savedCode else { status = "请先在设置中输入激活码解锁 AI 功能"; return }
        let sourceFilename = aiMode == .edit ? selectedPhoto?.name : nil
        let src: Data?
        if aiMode == .edit {
            guard let photo = selectedPhoto,
                  let data = try? Data(contentsOf: photo.url),
                  !data.isEmpty else {
                status = "无法读取原图，未发送 AI 修图请求"
                return
            }
            src = data
        } else {
            src = nil
        }
        aiIsGenerating = true; status = "正在调用 AI 模型…"
        let sz = aiRatio.size
        let did = ActivationManager.deviceId
        Task {
            do {
                let result = try await aiService.generate(prompt: aiPrompt, sourceImageData: src, sourceFilename: sourceFilename, size: sz, activationCode: code, deviceId: did)
                let img = NSImage(data: result.data)
                await MainActor.run {
                    if let remaining = result.remainingUsage {
                        ActivationManager.updateServerRemaining(remaining)
                    } else {
                        ActivationManager.recordUsageFallback()
                    }
                    aiResultImage = img; aiIsGenerating = false
                    status = img != nil ? "生成完成" : "无法解码 AI 返回的图片"
                }
            } catch {
                await MainActor.run { aiIsGenerating = false; status = error.localizedDescription }
            }
        }
    }

    private func saveAiResult() {
        guard let img = aiResultImage, let cg = img.cgImage(forProposedRect: nil, context: nil, hints: nil) else { status = "没有可保存的 AI 结果"; return }
        let rep = NSBitmapImageRep(cgImage: cg)
        guard let data = rep.representation(using: .jpeg, properties: [.compressionFactor: 0.95]) else { status = "无法编码 AI 结果"; return }
        isSaving = true
        let saved: URL?
        if aiMode == .edit, let selectedPhoto {
            saved = model.replaceEditedPhoto(
                data,
                at: selectedPhoto.url,
                originalFilename: selectedPhoto.name
            )
        } else {
            saved = model.saveEditedPhoto(data, originalFilename: "ai_generated.jpg")
        }
        if let saved {
            selectedPhotoURL = saved; status = "已保存 AI 结果 · \(saved.lastPathComponent)"
        } else { status = model.errorMessage ?? "保存 AI 结果失败" }
        isSaving = false
    }
}

private struct EditorSectionButtonStyle: ButtonStyle {
    let selected: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: TypeScale.caption, weight: .semibold))
            .foregroundStyle(selected ? Palette.editorAccent : Palette.editorLabel)
            .padding(.horizontal, 10)
            .frame(minHeight: 30)
            .background(selected ? Palette.editorRaised : Color.clear)
            .overlay {
                Rectangle()
                    .stroke(
                        selected ? Palette.editorAccent : Color.clear,
                        lineWidth: 1
                    )
            }
            .opacity(configuration.isPressed ? 0.72 : 1)
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
                        .font(.system(size: 30)) // 图标尺寸，不受 TypeScale 约束
                        .foregroundStyle(Palette.whiteDim)
                }
                if item.isVideo {
                    Label(durationLabel, systemImage: "play.fill")
                        .font(.system(size: TypeScale.caption, design: .monospaced))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 5)
                        .background(Palette.hudBg, in: Capsule())
                        .padding(7)
                }
            }
            .frame(height: 132)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 10))
            Text(item.name)
                .font(.system(size: TypeScale.body, weight: .semibold))
                .lineLimit(1)
            RuntimeLocalizedText(
                item.isVideo ? "系统视频 · 双击播放" : "系统照片 · 双击查看"
            )
                .font(.system(size: TypeScale.caption))
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
                    .font(.system(size: TypeScale.body, design: .monospaced))
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
                        .font(.system(size: TypeScale.heading, weight: .bold))
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
                                    .font(.system(size: TypeScale.title))
                                    .foregroundStyle(Palette.cobalt)
                                    .frame(width: 40, height: 40)
                                    .background(Palette.cobaltSoft)
                                    .clipShape(RoundedRectangle(cornerRadius: 9))
                                VStack(alignment: .leading, spacing: 3) {
                                    RuntimeLocalizedText(provider.name)
                                        .font(.system(size: TypeScale.emphasis, weight: .bold))
                                    RuntimeLocalizedText(provider.note)
                                        .font(.system(size: TypeScale.body))
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
                .font(.system(size: TypeScale.body))
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
                    .font(.system(size: TypeScale.body, design: .monospaced))
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
    @ObservedObject private var wifiCamera: WifiCameraService
    @ObservedObject private var wireless: WirelessTransferServer

    init(model: CameraModel) {
        self.model = model
        _wifiCamera = ObservedObject(wrappedValue: model.wifiCamera)
        _wireless = ObservedObject(wrappedValue: model.wirelessTransfer)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text("无线传输").font(.system(size: TypeScale.heading, weight: .bold))
                Text("连接 Wi‑Fi PTP/IP 相机进行控制，或通过 FTP、HTTP 与 WebDAV 接收文件；接收完成后会自动进入文件库。")
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
                        icon: wifiCamera.isConnected ? "wifi" : "wifi.slash",
                        title: "Wi‑Fi 相机",
                        value: wifiCamera.status
                    )
                    statusCard(
                        icon: wireless.isRunning ? "wifi" : "wifi.slash",
                        title: "无线收件箱",
                        value: wireless.status
                    )
                }

                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Label("Wi‑Fi 相机 · PTP/IP", systemImage: "camera.fill")
                                .font(.title3.bold())
                            RuntimeLocalizedText(wifiCamera.status)
                                .foregroundStyle(
                                    wifiCamera.state.isReconnecting
                                        ? Color.orange
                                        : wifiCamera.isConnected
                                            ? Palette.positive : Palette.muted
                                )
                        }
                        Spacer()
                        Button(
                            wifiCamera.state.isReconnecting
                                ? "正在重连…"
                                : wifiCamera.isConnected ? "断开" : "连接"
                        ) {
                            wifiCamera.isConnected
                                ? wifiCamera.disconnect()
                                : wifiCamera.connect()
                        }
                        .buttonStyle(
                            NativeButtonStyle(primary: !wifiCamera.isConnected)
                        )
                        .disabled(
                            wifiCamera.state == .connecting ||
                                wifiCamera.state.isReconnecting
                        )
                    }

                    Divider()

                    Picker("连接模式", selection: $wifiCamera.connectionMode) {
                        ForEach(WifiConnectionMode.allCases) { mode in
                            RuntimeLocalizedText(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .disabled(
                        wifiCamera.isConnected || wifiCamera.state == .connecting
                    )

                    RuntimeLocalizedText(wifiCamera.connectionMode.guidance)
                        .font(.system(size: TypeScale.body))
                        .foregroundStyle(Palette.muted)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 10) {
                        TextField("相机 IP 地址", text: $wifiCamera.host)
                            .textFieldStyle(.roundedBorder)
                        TextField("端口", text: $wifiCamera.portText)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 120)
                    }
                }
                .padding(20)
                .background(Palette.surface)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay {
                    RoundedRectangle(cornerRadius: 14).stroke(Palette.rule)
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
                        .font(.system(size: TypeScale.body))
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
                .font(.system(size: TypeScale.emphasis, weight: .semibold, design: .monospaced))
                .multilineTextAlignment(.trailing)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
        }
    }

    private func statusCard(icon: String, title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 15) {
            Image(systemName: icon)
                .font(.system(size: TypeScale.display))
                .foregroundStyle(Palette.cobalt)
            Text(LocalizedStringKey(title)).font(.headline)
            RuntimeLocalizedText(value)
                .font(.system(size: TypeScale.body, design: .monospaced))
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
                        // Splash 品牌字母（Z 字标），品牌资产不受 TypeScale 5 档约束
                        .font(.system(size: 42, weight: .heavy))
                        .foregroundStyle(.white)
                        .scaleEffect(markScale)
                        .opacity(markOpacity)
                }
                VStack(spacing: 6) {
                    Text("帧澈 ZENCHE")
                        .font(.system(size: TypeScale.heading, weight: .bold))
                        .foregroundStyle(Palette.ink)
                    Text("Capture · Connect · Flow")
                        .font(.system(size: TypeScale.emphasis, weight: .medium))
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

private struct MyDevicesView: View {
    @ObservedObject var model: CameraModel
    private let columns = [
        GridItem(.adaptive(minimum: 300, maximum: 430), spacing: 18)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                WorkspaceHeading(
                    title: "我的设备",
                    subtitle: "管理连接过的相机，轻触即可快速重连"
                )

                if model.rememberedDevices.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "camera.badge.clock")
                            .font(.system(size: 46)) // 图标尺寸，不受 TypeScale 约束
                            .foregroundStyle(Palette.cobalt)
                        RuntimeLocalizedText("尚未连接过设备")
                            .font(.system(size: TypeScale.title, weight: .bold))
                        RuntimeLocalizedText("成功连接相机后会自动保存在这里。")
                            .foregroundStyle(Palette.muted)
                    }
                    .frame(maxWidth: .infinity, minHeight: 360)
                    .background(Palette.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .overlay {
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Palette.rule, lineWidth: 1)
                    }
                } else {
                    LazyVGrid(columns: columns, spacing: 18) {
                        ForEach(model.rememberedDevices) { device in
                            RememberedDeviceCard(
                                model: model,
                                device: device
                            )
                        }
                    }
                }
            }
            .padding(28)
        }
        .background(Palette.paper)
    }
}

private struct RememberedDeviceCard: View {
    @ObservedObject var model: CameraModel
    let device: RememberedCameraDevice

    private var current: Bool {
        model.connected && model.cameraName == device.name
    }

    private var image: NSImage? {
        guard let url = Bundle.main.url(
            forResource: device.imageResourceName,
            withExtension: "jpg"
        ) else {
            return nil
        }
        return NSImage(contentsOf: url)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Group {
                if let image {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    ZStack {
                        Palette.graphite
                        Image(systemName: "camera.fill")
                            .font(.system(size: 44)) // 图标尺寸，不受 TypeScale 约束
                            .foregroundStyle(Palette.whiteLo)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 190)
            .clipped()

            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    Text(device.name)
                        .font(.system(size: TypeScale.title, weight: .bold))
                        .lineLimit(1)
                    Spacer()
                    if current {
                        Label("当前已连接", systemImage: "checkmark.circle.fill")
                            .font(.system(size: TypeScale.caption, weight: .semibold))
                            .foregroundStyle(Palette.positive)
                    }
                }
                Label(
                    "\(device.vendor) · \(device.transport)",
                    systemImage: "cable.connector"
                )
                .font(.system(size: TypeScale.body))
                .foregroundStyle(Palette.muted)
                HStack(spacing: 4) {
                    RuntimeLocalizedText("最近连接")
                    Text("·")
                    Text(
                        device.lastConnectedAt.formatted(
                            date: .abbreviated,
                            time: .shortened
                        )
                    )
                }
                .font(.system(size: TypeScale.body, design: .monospaced))
                .foregroundStyle(Palette.muted)

                HStack(spacing: 10) {
                    Button {
                        model.reconnectRememberedDevice(device)
                    } label: {
                        Label("快速连接", systemImage: "bolt.horizontal.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(NativeButtonStyle(primary: true))
                    .disabled(current || model.connecting)

                    Button(role: .destructive) {
                        model.forgetRememberedDevice(device)
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(NativeButtonStyle())
                    .help(Text("忘记设备"))
                }
            }
            .padding(16)
        }
        .background(Palette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay {
            RoundedRectangle(cornerRadius: 20)
                .stroke(current ? Palette.positive : Palette.rule, lineWidth: 1)
        }
        .shadow(color: Palette.shadow.opacity(0.45), radius: 10, y: 4)
    }
}

private struct ConnectionSheet: View {
    @ObservedObject var model: CameraModel
    @ObservedObject private var nikonOfficialSDK: NikonOfficialSDKService
    @ObservedObject private var sonyOfficialSDK: SonyOfficialSDKService
    @Environment(\.dismiss) private var dismiss

    init(model: CameraModel) {
        self.model = model
        _nikonOfficialSDK = ObservedObject(
            wrappedValue: model.nikonOfficialSDK
        )
        _sonyOfficialSDK = ObservedObject(
            wrappedValue: model.sonyOfficialSDK
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("相机连接")
                        .font(.system(size: TypeScale.display, weight: .bold))
                    Text("本机摄像头、USB/PTP 与官方 SDK")
                        .foregroundStyle(Palette.muted)
                }
                Spacer()
                Button("关闭") { dismiss() }
                    .buttonStyle(.plain)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 16) {
                        Image(systemName: "web.camera.fill")
                            .font(.system(size: TypeScale.display))
                            .foregroundStyle(Palette.cobalt)
                            .frame(width: 48, height: 48)
                            .background(Palette.cobaltSoft)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        VStack(alignment: .leading, spacing: 3) {
                            Text("本机摄像头")
                                .font(.system(size: TypeScale.title, weight: .bold))
                            Text(
                                model.localCameraConnected
                                    ? "\(model.localCamera.deviceName) · 已连接"
                                    : "使用 Mac 内置或外接摄像头取景、拍照并保存到文件库"
                            )
                            .foregroundStyle(
                                model.localCameraConnected
                                    ? Palette.positive : Palette.muted
                            )
                        }
                        Spacer()
                        Button(model.localCameraConnected ? "断开" : "连接") {
                            model.localCameraConnected
                                ? model.disconnectLocalCamera()
                                : model.connectLocalCamera()
                        }
                        .buttonStyle(
                            NativeButtonStyle(primary: !model.localCameraConnected)
                        )
                        .disabled(model.connecting)
                    }
                    .padding(16)
                    .background(Palette.cobaltSoft.opacity(0.58))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .top, spacing: 14) {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: TypeScale.title))
                                .foregroundStyle(Palette.cobalt)
                                .frame(width: 48, height: 48)
                                .background(Palette.cobaltSoft)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            VStack(alignment: .leading, spacing: 4) {
                                Text("尼康官方 SDK")
                                    .font(.system(size: TypeScale.title, weight: .bold))
                                RuntimeLocalizedText(
                                    nikonOfficialSDK.statusSummary
                                )
                                .font(.system(size: TypeScale.body))
                                .foregroundStyle(Palette.muted)
                            }
                            Spacer()
                            HStack(spacing: 8) {
                                Button("重新检测") {
                                    nikonOfficialSDK.refresh(
                                        allowRemoteProbe: !model.connected
                                    )
                                }
                                .buttonStyle(NativeButtonStyle(primary: false))
                                .disabled(
                                    nikonOfficialSDK.isRefreshing || model.connected
                                )
                                .help(
                                    model.connected
                                        ? "断开当前 USB 会话后可重新检测"
                                        : "重新检测尼康官方 SDK 与空闲相机"
                                )
                                Button(model.connected ? "断开" : "连接") {
                                    model.connected
                                        ? model.disconnect()
                                        : model.connect()
                                }
                                .buttonStyle(
                                    NativeButtonStyle(primary: !model.connected)
                                )
                                .disabled(
                                    model.connecting ||
                                        nikonOfficialSDK.isRefreshing ||
                                        (!model.connected &&
                                            (!nikonOfficialSDK.remoteReady ||
                                                !nikonOfficialSDK.hasAvailableDevice))
                                )
                                .help(
                                    model.connected
                                        ? "断开当前相机会话"
                                        : nikonOfficialSDK.hasAvailableDevice
                                        ? "连接已检测到的尼康相机"
                                        : "请先重新检测可连接的尼康相机"
                                )
                            }
                        }
                        Divider()
                        sdkStatusRow(
                            title: "Remote SDK 2.0.0",
                            detail: nikonOfficialSDK.remoteDetail,
                            ready: nikonOfficialSDK.remoteReady
                        )
                        sdkStatusRow(
                            title: "Image SDK 1.46.0",
                            detail: nikonOfficialSDK.imageDetail,
                            ready: nikonOfficialSDK.imageReady ||
                                (nikonOfficialSDK.imageLoaded &&
                                    nikonOfficialSDK.imageProbeSuppressed)
                        )
                        ForEach(nikonOfficialSDK.devices, id: \.self) { device in
                            Label(device, systemImage: "camera.fill")
                                .font(.system(size: TypeScale.caption))
                                .foregroundStyle(Palette.muted)
                        }
                    }
                    .padding(16)
                    .background(Palette.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .top, spacing: 14) {
                            Image(systemName: "camera.aperture")
                                .font(.system(size: TypeScale.title))
                                .foregroundStyle(Palette.cobalt)
                                .frame(width: 48, height: 48)
                                .background(Palette.cobaltSoft)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            VStack(alignment: .leading, spacing: 4) {
                                Text("索尼官方 SDK")
                                    .font(.system(size: TypeScale.title, weight: .bold))
                                RuntimeLocalizedText(
                                    sonyOfficialSDK.statusSummary
                                )
                                .font(.system(size: TypeScale.body))
                                .foregroundStyle(Palette.muted)
                            }
                            Spacer()
                            Button("重新检测") {
                                sonyOfficialSDK.refresh(
                                    allowProbe: !model.connected
                                )
                            }
                            .buttonStyle(NativeButtonStyle(primary: false))
                            .disabled(sonyOfficialSDK.isRefreshing)
                        }
                        Divider()
                        sdkStatusRow(
                            title: "Camera Remote SDK 2.02.00",
                            detail: sonyOfficialSDK.detail,
                            ready: sonyOfficialSDK.ready
                        )
                        ForEach(sonyOfficialSDK.devices, id: \.self) { device in
                            Label(device, systemImage: "camera.fill")
                                .font(.system(size: TypeScale.caption))
                                .foregroundStyle(Palette.muted)
                        }
                        Text("连接即表示同意索尼 SDK 使用限制；帧澈独立提供产品支持。")
                            .font(.system(size: TypeScale.caption))
                            .foregroundStyle(Palette.muted)
                    }
                    .padding(16)
                    .background(Palette.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    HStack(spacing: 16) {
                        Image(systemName: "cable.connector")
                            .font(.system(size: TypeScale.display))
                            .foregroundStyle(Palette.cobalt)
                            .frame(width: 48, height: 48)
                            .background(Palette.cobaltSoft)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        VStack(alignment: .leading, spacing: 3) {
                            Text("USB / PTP")
                                .font(.system(size: TypeScale.title, weight: .bold))
                            Text(model.connected
                                ? "\(model.activeCameraName) · 已连接"
                                : "联机拍摄、参数控制、实时监看和文件传输")
                                .foregroundStyle(Palette.muted)
                        }
                        Spacer()
                        Button(model.connected ? "断开" : "连接") {
                            model.connected ? model.disconnect() : model.connect()
                        }
                        .buttonStyle(NativeButtonStyle(primary: !model.connected))
                        .disabled(model.connecting)
                    }
                    .padding(16)
                    .background(Palette.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                }
                .padding(.vertical, 2)
            }
        }
        .padding(26)
        .frame(width: 640, height: 650)
        .background(Palette.paper)
        .onAppear {
            // Only inspect packaged runtimes here. Initializing two vendors'
            // native SDKs concurrently can crash inside their worker runtimes.
            // The USB/PTP connect flow selects a vendor before loading its SDK.
            nikonOfficialSDK.refresh(allowRemoteProbe: false)
            sonyOfficialSDK.refresh(allowProbe: false)
        }
    }

    private func sdkStatusRow(
        title: String,
        detail: String,
        ready: Bool
    ) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: ready ? "checkmark.circle.fill" : "xmark.circle")
                .foregroundStyle(ready ? Palette.positive : Palette.muted)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: TypeScale.emphasis, weight: .semibold))
                RuntimeLocalizedText(detail)
                    .font(.system(size: TypeScale.caption))
                    .foregroundStyle(Palette.muted)
            }
        }
    }
}

private struct RootView: View {
    @ObservedObject var model: CameraModel
    @StateObject private var updater = UpdateController()
    @AppStorage("appLanguage") private var languageRaw = "zh-Hans"
    @AppStorage("appThemeMode") private var themeRaw = ThemeMode.system.rawValue
    @AppStorage("dismissedLaunchAnnouncementVersion")
    private var dismissedAnnouncementVersion = ""

    private var themeMode: ThemeMode {
        ThemeMode(rawValue: themeRaw) ?? .system
    }

    /// 将主题设置应用到 AppKit 全局外观，使所有动态色（Palette / SettingsPalette）
    /// 与非 SwiftUI 面板（NSSavePanel、菜单等）同步解析明/暗。
    private func applyAppearance() {
        NSApp.appearance = themeMode.appKitAppearance
    }

    @ViewBuilder
    private var currentWorkspace: some View {
        switch model.section {
        case .capture:
            CaptureView(
                model: model,
                showConnection: $showConnection,
                showSettings: $showSettings
            )
        case .monitor:
            MonitorView(model: model)
        case .editor:
            ImageEditorView(model: model)
        case .library:
            LibraryView(model: model)
        case .devices:
            MyDevicesView(model: model)
        }
    }
    @State private var showConnection = false
    @State private var showSettings = false
    @State private var showLaunchAnnouncement = false
    @State private var doNotRemindForCurrentVersion = false
    @State private var showSplash = true

    private static var appVersion: String {
        Bundle.main.object(
            forInfoDictionaryKey: "CFBundleShortVersionString"
        ) as? String ?? "1.5.3"
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
                // Keep exactly one workspace mounted while navigating. An
                // animated Group can retain the previous monitor view during
                // layout, causing its image to bleed behind the editor.
                currentWorkspace
                    .id(model.section)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            HStack {
                HStack(spacing: 5) {
                    Image(
                        systemName: model.hasAnyCameraConnection
                            ? "link"
                            : "link.badge.plus"
                    )
                    RuntimeLocalizedText(model.connectionTitle)
                        .lineLimit(1)
                }
                Spacer()
                RuntimeLocalizedText(model.connectionDetail)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: .infinity)
                Spacer()
                Text("文件库 · \(model.photos.count) 个文件")
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
            .font(.system(size: TypeScale.caption, weight: .medium, design: .monospaced))
            .foregroundStyle(Palette.whiteLo)
            .padding(.horizontal, 18)
            .frame(height: 32)
            .background(Palette.graphite)
            .accessibilityElement(children: .combine)
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
                languageRaw: $languageRaw,
                themeRaw: $themeRaw,
                bluetoothRemote: model.bluetoothRemote,
                locationTagging: model.locationTagging
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
        .preferredColorScheme(themeMode.colorScheme)
        .onAppear {
            applyAppearance()
            updateWindowTitle()
            updater.checkAutomaticallyIfNeeded()
            showLaunchAnnouncement =
                dismissedAnnouncementVersion != Self.appVersion
        }
        .onChange(of: languageRaw) { _, _ in
            updateWindowTitle()
        }
        .onChange(of: themeRaw) { _, _ in
            applyAppearance()
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
