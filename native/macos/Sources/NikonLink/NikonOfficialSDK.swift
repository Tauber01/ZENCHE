import Foundation
import Combine

@_silgen_name("ZencheProbeNikonRemoteSDK")
private func probeNikonRemoteSDK(
    _ output: UnsafeMutablePointer<CChar>?,
    _ capacity: Int
) -> Int32

@_silgen_name("ZencheProbeNikonImageSDK")
private func probeNikonImageSDK(
    _ output: UnsafeMutablePointer<CChar>?,
    _ capacity: Int
) -> Int32

private struct NikonSDKDevice: Decodable, Identifiable {
    let id: UInt32
    let name: String
    let available: Bool
    let version: String
}

private struct NikonRemoteSDKProbe: Decodable {
    let loaded: Bool
    let initialized: Bool
    let errorCode: Int64
    let message: String
    let devices: [NikonSDKDevice]
}

private struct NikonImageSDKProbe: Decodable {
    let loaded: Bool
    let initialized: Bool
    let errorCode: Int64
    let message: String
}

private enum NikonSDKProbeKind: String {
    case remote
    case image
}

private struct NikonSDKProbeOutcome<Result> {
    let result: Result?
    let failure: String?
}

final class NikonOfficialSDKService: ObservableObject {
    @Published private(set) var remoteLoaded = false
    @Published private(set) var remoteReady = false
    @Published private(set) var imageLoaded = false
    @Published private(set) var imageReady = false
    @Published private(set) var remoteProbeSuppressed = false
    @Published private(set) var imageProbeSuppressed = false
    @Published private(set) var remoteDetail = "等待检测"
    @Published private(set) var imageDetail = "等待检测"
    @Published private(set) var devices: [String] = []
    @Published private(set) var hasAvailableDevice = false
    @Published private(set) var isRefreshing = false

    private let queue = DispatchQueue(
        label: "com.tauber.nikonlink.nikon-official-sdk",
        qos: .userInitiated
    )

    var statusSummary: String {
        if remoteReady && imageReady {
            return "Remote SDK 2.0.0 与 Image SDK 1.46.0 已就绪"
        }
        if remoteReady && imageLoaded && imageProbeSuppressed {
            return "Remote SDK 2.0.0 已就绪 · Image SDK 兼容模式"
        }
        if remoteLoaded && remoteProbeSuppressed {
            return "官方 SDK 已安装 · 厂商运行时隔离模式"
        }
        if remoteLoaded || imageLoaded {
            return "官方 SDK 已安装，部分组件初始化失败"
        }
        return "官方 SDK 运行库未载入"
    }

    func refresh(allowRemoteProbe: Bool) {
        guard !isRefreshing else { return }
        isRefreshing = true
        if allowRemoteProbe {
            remoteDetail = "正在重新检测…"
        }
        imageDetail = "正在重新检测…"
        queue.async { [weak self] in
            guard let self else { return }
            // Nikon's Remote SDK and Sony CrSDK both bundle native worker
            // runtimes. Loading them into the same app process can corrupt the
            // main run-loop finalizer and cause an uncaught SIGSEGV. Keep the
            // optional Nikon status probes out of process whenever CrSDK ships
            // with the app. Camera vendor detection and Nikon PTP connectivity
            // do not depend on these status probes.
            let sonyRuntimeInstalled = FileManager.default.fileExists(
                atPath: Bundle.main.bundlePath +
                    "/Contents/Frameworks/libCr_Core.dylib"
            )
            let isolateRemoteProbe = sonyRuntimeInstalled
            let isolateImageProbe = sonyRuntimeInstalled ||
                ProcessInfo.processInfo.operatingSystemVersion.majorVersion >= 26
            self.installRemoteConfiguration()
            let remoteOutcome: NikonSDKProbeOutcome<NikonRemoteSDKProbe>?
            if allowRemoteProbe {
                remoteOutcome = isolateRemoteProbe
                    ? self.performIsolatedProbe(
                        kind: .remote,
                        as: NikonRemoteSDKProbe.self
                    )
                    : NikonSDKProbeOutcome(
                        result: self.performProbe(
                            function: probeNikonRemoteSDK,
                            as: NikonRemoteSDKProbe.self
                        ),
                        failure: nil
                    )
            } else {
                remoteOutcome = nil
            }
            let imageOutcome: NikonSDKProbeOutcome<NikonImageSDKProbe> =
                isolateImageProbe
                    ? self.performIsolatedProbe(
                        kind: .image,
                        as: NikonImageSDKProbe.self
                    )
                    : NikonSDKProbeOutcome(
                        result: self.performProbe(
                            function: probeNikonImageSDK,
                            as: NikonImageSDKProbe.self
                        ),
                        failure: nil
                    )
            let imageRuntimeInstalled = FileManager.default.fileExists(
                atPath: Bundle.main.bundlePath +
                    "/Contents/Frameworks/libImgSDK.dylib"
            )
            DispatchQueue.main.async {
                self.remoteProbeSuppressed = remoteOutcome == nil
                self.imageProbeSuppressed = false
                if let remote = remoteOutcome?.result {
                    self.remoteLoaded = remote.loaded
                    self.remoteReady = remote.initialized
                    self.remoteDetail = remote.initialized
                        ? (remote.devices.isEmpty
                            ? "SDK 已就绪 · 未发现空闲尼康相机"
                            : "SDK 已发现 \(remote.devices.count) 台尼康相机")
                        : "初始化失败 · 错误码 \(remote.errorCode)"
                    self.devices = remote.devices.map { device in
                        let availability = device.available ? "可连接" : "正被占用"
                        let version = device.version.isEmpty
                            ? ""
                            : " · \(device.version)"
                        return "\(device.name) · \(availability)\(version)"
                    }
                    self.hasAvailableDevice = remote.devices.contains {
                        $0.available
                    }
                } else if let remoteOutcome {
                    self.remoteLoaded = FileManager.default.fileExists(
                        atPath: Bundle.main.bundlePath +
                            "/Contents/MacOS/TypeCommon Module.bundle"
                    )
                    self.remoteReady = false
                    self.devices = []
                    self.hasAvailableDevice = false
                    self.remoteDetail = remoteOutcome.failure ??
                        (self.remoteLoaded
                            ? "Remote SDK 探测失败"
                            : "Remote SDK 运行库未找到")
                } else {
                    self.remoteLoaded = FileManager.default.fileExists(
                        atPath: Bundle.main.bundlePath +
                            "/Contents/MacOS/TypeCommon Module.bundle"
                    )
                    self.remoteReady = false
                    self.remoteDetail = self.remoteLoaded
                        ? "SDK 已安装 · 断开当前 USB 会话后可重新检测"
                        : "Remote SDK 运行库未找到"
                    self.devices = []
                    self.hasAvailableDevice = false
                }
                if let image = imageOutcome.result {
                    self.imageLoaded = image.loaded
                    self.imageReady = image.initialized
                    self.imageDetail = image.initialized
                        ? "NEF / NRW 引擎已完成官方初始化"
                        : "初始化失败 · 错误码 \(image.errorCode)"
                } else {
                    self.imageLoaded = imageRuntimeInstalled
                    self.imageReady = false
                    self.imageDetail = imageOutcome.failure ??
                        (imageRuntimeInstalled
                            ? "Image SDK 探测失败"
                            : "Image SDK 运行库未找到")
                }
                self.isRefreshing = false
            }
        }
    }

    private func performIsolatedProbe<Result: Decodable>(
        kind: NikonSDKProbeKind,
        as type: Result.Type
    ) -> NikonSDKProbeOutcome<Result> {
        guard let executableDirectory = Bundle.main.executableURL?
            .deletingLastPathComponent()
        else {
            return NikonSDKProbeOutcome(
                result: nil,
                failure: "独立探测器路径不可用"
            )
        }
        let helper = executableDirectory.appendingPathComponent(
            "ZENCHE-NikonSDKProbe",
            isDirectory: false
        )
        guard FileManager.default.isExecutableFile(atPath: helper.path) else {
            return NikonSDKProbeOutcome(
                result: nil,
                failure: "独立探测器未安装"
            )
        }

        let process = Process()
        let output = Pipe()
        process.executableURL = helper
        process.arguments = [kind.rawValue]
        process.currentDirectoryURL = Bundle.main.resourceURL
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        let finished = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in finished.signal() }
        do {
            try process.run()
        } catch {
            return NikonSDKProbeOutcome(
                result: nil,
                failure: "独立探测器启动失败 · \(error.localizedDescription)"
            )
        }
        guard finished.wait(timeout: .now() + 20) == .success else {
            process.terminate()
            _ = finished.wait(timeout: .now() + 2)
            return NikonSDKProbeOutcome(
                result: nil,
                failure: "官方 SDK 探测超时"
            )
        }
        guard process.terminationStatus == 0 else {
            return NikonSDKProbeOutcome(
                result: nil,
                failure: process.terminationReason == .uncaughtSignal
                    ? "官方 SDK 探测进程异常退出"
                    : "官方 SDK 探测器返回错误 \(process.terminationStatus)"
            )
        }
        let data = output.fileHandleForReading.readDataToEndOfFile()
        do {
            return NikonSDKProbeOutcome(
                result: try decodeProbeOutput(type, from: data),
                failure: nil
            )
        } catch {
            return NikonSDKProbeOutcome(
                result: nil,
                failure: "官方 SDK 探测结果无效"
            )
        }
    }

    private func decodeProbeOutput<Result: Decodable>(
        _ type: Result.Type,
        from data: Data
    ) throws -> Result {
        let decoder = JSONDecoder()
        if let result = try? decoder.decode(type, from: data) {
            return result
        }
        guard let output = String(data: data, encoding: .utf8),
              let marker = output.range(
                of: "{\"loaded\":",
                options: .backwards
              )
        else {
            throw DecodingError.dataCorrupted(
                .init(codingPath: [], debugDescription: "Missing probe JSON")
            )
        }
        return try decoder.decode(
            type,
            from: Data(output[marker.lowerBound...].utf8)
        )
    }

    private func performProbe<Result: Decodable>(
        function: (UnsafeMutablePointer<CChar>?, Int) -> Int32,
        as type: Result.Type
    ) -> Result? {
        var buffer = [CChar](repeating: 0, count: 32_768)
        let result = buffer.withUnsafeMutableBufferPointer { pointer in
            function(pointer.baseAddress, pointer.count)
        }
        guard result == 0 else { return nil }
        let data = Data(String(cString: buffer).utf8)
        return try? JSONDecoder().decode(type, from: data)
    }

    private func installRemoteConfiguration() {
        guard let resources = Bundle.main.resourceURL?
            .appendingPathComponent("NikonSDK/Remote/Config", isDirectory: true),
              FileManager.default.fileExists(atPath: resources.path)
        else { return }
        let destination = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Preferences/Nikon/NXTether", isDirectory: true)
        do {
            try FileManager.default.createDirectory(
                at: destination,
                withIntermediateDirectories: true
            )
            for name in [
                "DC_PTP_Config.config",
                "MaidLayer.config",
                "RangeValue.config"
            ] {
                let source = resources.appendingPathComponent(name)
                let target = destination.appendingPathComponent(name)
                if FileManager.default.fileExists(atPath: target.path) {
                    try FileManager.default.removeItem(at: target)
                }
                try FileManager.default.copyItem(at: source, to: target)
            }
        } catch {
            DiagnosticLogger.shared.warning(
                "nikon-sdk",
                "官方 Remote SDK 配置安装失败：\(error.localizedDescription)"
            )
        }
    }
}
