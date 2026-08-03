import Foundation
import Combine

@_silgen_name("ZencheProbeSonyCameraRemoteSDK")
private func probeSonyCameraRemoteSDK(
    _ output: UnsafeMutablePointer<CChar>?,
    _ capacity: Int
) -> Int32

@_silgen_name("ZencheSonySDKConnect")
private func connectSonyCameraRemoteSDK(
    _ saveDirectory: UnsafePointer<CChar>?,
    _ modelOutput: UnsafeMutablePointer<CChar>?,
    _ modelCapacity: Int
) -> Int32

@_silgen_name("ZencheSonySDKDisconnect")
private func disconnectSonyCameraRemoteSDK() -> Int32

@_silgen_name("ZencheSonySDKGetLiveViewImage")
private func getSonyLiveViewImage(
    _ output: UnsafeMutablePointer<UInt8>?,
    _ capacity: Int,
    _ actualSize: UnsafeMutablePointer<Int>?
) -> Int32

@_silgen_name("ZencheSonySDKCapture")
private func captureSonyCameraRemoteSDK(
    _ output: UnsafeMutablePointer<CChar>?,
    _ capacity: Int
) -> Int32

@_silgen_name("ZencheSonySDKSetMovieRecording")
private func setSonyMovieRecording(_ recording: Bool) -> Int32

@_silgen_name("ZencheSonySDKAutofocus")
private func setSonyAutofocus(_ pressed: Bool) -> Int32

@_silgen_name("ZencheSonySDKSetProperty")
private func setSonyProperty(_ code: UInt32, _ value: UInt64) -> Int32

private struct SonySDKProbe: Decodable {
    struct Device: Decodable {
        let model: String
        let name: String?
        let connected: Bool
    }

    let loaded: Bool
    let initialized: Bool
    let version: UInt32
    let errorCode: UInt32?
    let devices: [Device]
}

enum SonyOfficialSDKError: LocalizedError {
    case operation(String, Int32)
    case missingImage

    var errorDescription: String? {
        switch self {
        case let .operation(operation, code):
            return "Sony Camera Remote SDK 执行“\(operation)”失败（错误码 \(code)）。"
        case .missingImage:
            return "Sony Camera Remote SDK 未返回有效图像。"
        }
    }
}

final class SonyOfficialSDKService: ObservableObject {
    static let shared = SonyOfficialSDKService()

    @Published private(set) var loaded = false
    @Published private(set) var ready = false
    @Published private(set) var detail = "等待检测"
    @Published private(set) var devices: [String] = []
    @Published private(set) var isRefreshing = false
    private(set) var isConnected = false

    private let queue = DispatchQueue(
        label: "com.tauber.nikonlink.sony-official-sdk",
        qos: .userInitiated
    )
    private let lock = NSLock()

    var statusSummary: String {
        if isConnected { return "Camera Remote SDK 2.02.00 正在控制索尼相机" }
        if ready { return "Camera Remote SDK 2.02.00 已就绪" }
        if loaded { return "官方 SDK 已安装，初始化或枚举失败" }
        return "官方 SDK 运行库未载入"
    }

    func refresh(allowProbe: Bool) {
        guard !isRefreshing else { return }
        isRefreshing = true
        queue.async { [weak self] in
            guard let self else { return }
            if !allowProbe || self.isConnected {
                DispatchQueue.main.async {
                    self.loaded = self.runtimeInstalled
                    self.ready = self.loaded
                    self.detail = self.loaded
                        ? "SDK 已安装 · 断开当前 USB 会话后可重新枚举"
                        : "Cr_Core 运行库未找到"
                    self.isRefreshing = false
                }
                return
            }
            var buffer = [CChar](repeating: 0, count: 32_768)
            let result = buffer.withUnsafeMutableBufferPointer { pointer in
                probeSonyCameraRemoteSDK(pointer.baseAddress, pointer.count)
            }
            let probe: SonySDKProbe? = result == 0
                ? try? JSONDecoder().decode(
                    SonySDKProbe.self,
                    from: Data(String(cString: buffer).utf8)
                )
                : nil
            DispatchQueue.main.async {
                self.loaded = probe?.loaded ?? self.runtimeInstalled
                self.ready = probe?.initialized ?? false
                self.devices = probe?.devices.map { device in
                    let connection = device.connected ? "已连接" : "可连接"
                    return "\(device.model) · \(connection)"
                } ?? []
                self.detail = self.ready
                    ? (self.devices.isEmpty
                        ? "SDK 已就绪 · 未发现空闲索尼相机"
                        : "SDK 已发现 \(self.devices.count) 台索尼相机")
                    : "初始化失败\(probe?.errorCode.map { " · 错误码 \($0)" } ?? "")"
                self.isRefreshing = false
            }
        }
    }

    func connect(saveDirectory: URL) throws -> String {
        lock.lock()
        defer { lock.unlock() }
        var model = [CChar](repeating: 0, count: 512)
        let result = saveDirectory.path.withCString { directory in
            model.withUnsafeMutableBufferPointer { output in
                connectSonyCameraRemoteSDK(
                    directory,
                    output.baseAddress,
                    output.count
                )
            }
        }
        guard result == 0 else {
            throw SonyOfficialSDKError.operation("连接相机", result)
        }
        isConnected = true
        return String(cString: model)
    }

    func disconnect() {
        lock.lock()
        defer { lock.unlock() }
        _ = disconnectSonyCameraRemoteSDK()
        isConnected = false
    }

    func liveViewImage() throws -> Data {
        lock.lock()
        defer { lock.unlock() }
        var required = 0
        _ = getSonyLiveViewImage(nil, 0, &required)
        guard required > 0 else { throw SonyOfficialSDKError.missingImage }
        var data = Data(count: required)
        var actual = required
        let result = data.withUnsafeMutableBytes { bytes in
            getSonyLiveViewImage(
                bytes.bindMemory(to: UInt8.self).baseAddress,
                bytes.count,
                &actual
            )
        }
        guard result == 0, actual > 0 else {
            throw SonyOfficialSDKError.operation("获取实时取景", result)
        }
        data.count = actual
        return data
    }

    func capture() throws -> Data {
        lock.lock()
        defer { lock.unlock() }
        var output = [CChar](repeating: 0, count: 4096)
        let result = output.withUnsafeMutableBufferPointer { pointer in
            captureSonyCameraRemoteSDK(pointer.baseAddress, pointer.count)
        }
        guard result == 0 else {
            throw SonyOfficialSDKError.operation("拍摄并传输", result)
        }
        let url = URL(fileURLWithPath: String(cString: output))
        guard let data = try? Data(contentsOf: url), !data.isEmpty else {
            throw SonyOfficialSDKError.missingImage
        }
        try? FileManager.default.removeItem(at: url)
        return data
    }

    func setMovieRecording(_ recording: Bool) throws {
        try check(
            setSonyMovieRecording(recording),
            operation: recording ? "开始视频录制" : "停止视频录制"
        )
    }

    func triggerAutofocus() throws {
        try check(setSonyAutofocus(true), operation: "AF-ON 按下")
        Thread.sleep(forTimeInterval: 0.12)
        try check(setSonyAutofocus(false), operation: "AF-ON 释放")
    }

    func setParameter(name: String, value: Any) throws {
        let property: UInt32
        let encoded: UInt64
        switch name {
        case "videoCodec":
            property = 295 // CrDeviceProperty_Movie_File_Format
            guard let mapped = [
                "sonyXavcHs8k": 4,
                "sonyXavcHs4k": 5,
                "sonyXavcS4k": 2,
                "sonyXavcSHd": 3,
                "sonyXavcSi4k": 8,
                "sonyXavcSiHd": 9
            ][String(describing: value)] else {
                throw SonyOfficialSDKError.operation("设置视频录制规格", -160)
            }
            encoded = UInt64(mapped)
        case "videoLog":
            property = 426 // CrDeviceProperty_PictureProfile
            guard let mapped = [
                "off": 0,
                "sonySLog2": 7,
                "sonySLog3Cine": 8,
                "sonySLog3": 9,
                "sonyHlg": 10
            ][String(describing: value)] else {
                throw SonyOfficialSDKError.operation("设置 Picture Profile", -161)
            }
            encoded = UInt64(mapped)
        case "aperture":
            property = 256
            encoded = UInt64((((value as? NSNumber)?.doubleValue ?? 4) * 100).rounded())
        case "iso":
            property = 260
            encoded = UInt64((value as? NSNumber)?.intValue ?? 400)
        case "exposureCompensation":
            property = 257
            let signed = Int64((((value as? NSNumber)?.doubleValue ?? 0) * 1000).rounded())
            encoded = UInt64(bitPattern: signed)
        case "exposureTime", "videoExposureTime":
            property = 259
            let seconds = max(0.000_001, (value as? NSNumber)?.doubleValue ?? 0.008)
            if seconds < 1 {
                encoded = UInt64((1 << 16) | Int((1 / seconds).rounded()))
            } else {
                encoded = UInt64((Int(seconds.rounded()) << 16) | 1)
            }
        default:
            throw SonyOfficialSDKError.operation("设置参数 \(name)", -162)
        }
        try check(
            setSonyProperty(property, encoded),
            operation: "设置参数 \(name)"
        )
    }

    private var runtimeInstalled: Bool {
        FileManager.default.fileExists(
            atPath: Bundle.main.bundlePath +
                "/Contents/Frameworks/libCr_Core.dylib"
        )
    }

    private func check(_ result: Int32, operation: String) throws {
        guard result == 0 else {
            throw SonyOfficialSDKError.operation(operation, result)
        }
    }
}
