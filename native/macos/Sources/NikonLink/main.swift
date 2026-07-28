import AppKit
import Foundation
import WebKit

private struct BridgeReply: Encodable {
    let ok: Bool
    let result: AnyEncodable?
    let error: String?
    let code: String?

    static func success(_ value: [String: Any] = [:]) -> BridgeReply {
        BridgeReply(ok: true, result: AnyEncodable(value), error: nil, code: nil)
    }

    static func failure(_ message: String, code: String = "NATIVE_ERROR") -> BridgeReply {
        BridgeReply(ok: false, result: nil, error: message, code: code)
    }
}

private struct AnyEncodable: Encodable {
    private let encodeValue: (Encoder) throws -> Void

    init(_ value: Any) {
        encodeValue = { encoder in
            var container = encoder.singleValueContainer()
            switch value {
            case let value as String: try container.encode(value)
            case let value as Bool: try container.encode(value)
            case let value as Int: try container.encode(value)
            case let value as Double: try container.encode(value)
            case let value as [String: Any]: try container.encode(value.mapValues(AnyEncodable.init))
            case let value as [Any]: try container.encode(value.map(AnyEncodable.init))
            case is NSNull: try container.encodeNil()
            default: try container.encode(String(describing: value))
            }
        }
    }

    func encode(to encoder: Encoder) throws { try encodeValue(encoder) }
}

private enum CameraError: LocalizedError {
    case command(String)
    case noCamera
    case wrongCamera(String)
    case noImage

    var errorDescription: String? {
        switch self {
        case .command(let value): return value
        case .noCamera: return "没有检测到 Nikon Z8。请用 USB 数据线直连，并关闭 NX Tether 等占用相机的软件。"
        case .wrongCamera(let value): return "检测到 \(value)，当前安装包仅按 Nikon Z8 验证。"
        case .noImage: return "相机没有返回可用的 JPEG 图像。"
        }
    }
}

private final class GPhotoCamera {
    private let resources = Bundle.main.resourceURL!
    private var connected = false
    private var liveView = false
    private var settings: [String: Any] = [
        "width": 1024,
        "height": 680,
        "frameRate": 3,
        "exposureTime": 0.008,
        "aperture": 4.0,
        "iso": 400,
        "exposureCompensation": 0.0,
        "focusMode": "single-shot",
        "whiteBalanceMode": "continuous",
        "exposureMode": "manual"
    ]

    private var executable: URL {
        let bundled = resources.appendingPathComponent("bin/gphoto2")
        return FileManager.default.isExecutableFile(atPath: bundled.path)
            ? bundled
            : URL(fileURLWithPath: "/opt/homebrew/bin/gphoto2")
    }

    private func run(_ arguments: [String], timeout: TimeInterval = 45) throws -> String {
        let process = Process()
        let output = Pipe()
        process.executableURL = executable
        process.arguments = ["--quiet"] + arguments
        process.standardOutput = output
        process.standardError = output
        var environment = ProcessInfo.processInfo.environment
        environment["CAMLIBS"] = resources.appendingPathComponent("camlibs").path
        environment["IOLIBS"] = resources.appendingPathComponent("iolibs").path
        environment["DYLD_LIBRARY_PATH"] = resources.appendingPathComponent("lib").path
        process.environment = environment
        try process.run()

        let deadline = Date().addingTimeInterval(timeout)
        while process.isRunning && Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }
        if process.isRunning {
            process.terminate()
            throw CameraError.command("相机操作超时，请重新连接 Z8。")
        }
        let data = output.fileHandleForReading.readDataToEndOfFile()
        let text = String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        guard process.terminationStatus == 0 else {
            throw CameraError.command(text.isEmpty ? "Z8 返回了错误状态。" : text)
        }
        return text
    }

    func connect() throws -> [String: Any] {
        let detected = try run(["--auto-detect"])
        guard detected.localizedCaseInsensitiveContains("nikon") else { throw CameraError.noCamera }
        guard detected.localizedCaseInsensitiveContains("z8") else {
            let name = detected.split(separator: "\n").last.map(String.init) ?? "其他 Nikon 相机"
            throw CameraError.wrongCamera(name)
        }
        _ = try run(["--summary"])
        connected = true
        return [
            "device": ["id": "04b0:0451", "label": "Nikon Z8", "transport": "USB/PTP"],
            "capabilities": [
                "exposureTime": ["min": 0.000125, "max": 30.0],
                "aperture": ["min": 1.2, "max": 22.0],
                "iso": ["min": 64, "max": 25600],
                "exposureCompensation": ["min": -5.0, "max": 5.0],
                "focusMode": ["single-shot", "continuous", "manual"],
                "whiteBalanceMode": ["continuous", "manual"],
                "exposureMode": ["continuous", "manual"]
            ],
            "settings": settings
        ]
    }

    func startLiveView() throws {
        guard connected else { throw CameraError.noCamera }
        liveView = true
    }

    func stopLiveView() { liveView = false }

    private func imageResult(prefix: String, preview: Bool) throws -> [String: Any] {
        guard connected else { throw CameraError.noCamera }
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("NikonLink", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let stem = "\(prefix)-\(UUID().uuidString)"
        let target = folder.appendingPathComponent("\(stem).%C")
        let args = preview
            ? ["--capture-preview", "--filename", target.path, "--force-overwrite"]
            : ["--capture-image-and-download", "--filename", target.path, "--force-overwrite"]
        _ = try run(args, timeout: preview ? 15 : 60)
        let files = (try? FileManager.default.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: nil
        )) ?? []
        let image = files
            .filter { $0.lastPathComponent.hasPrefix(stem) }
            .sorted { $0.pathExtension.lowercased() == "jpg" && $1.pathExtension.lowercased() != "jpg" }
            .first
        guard let image, let data = try? Data(contentsOf: image), !data.isEmpty else {
            throw CameraError.noImage
        }
        try? FileManager.default.removeItem(at: image)
        return [
            "dataUrl": "data:image/jpeg;base64,\(data.base64EncodedString())",
            "width": 1024,
            "height": 680,
            "name": image.lastPathComponent
        ]
    }

    func preview() throws -> [String: Any] {
        guard liveView else { throw CameraError.command("实时取景尚未开启。") }
        return try imageResult(prefix: "preview", preview: true)
    }

    func capture() throws -> [String: Any] {
        try imageResult(prefix: "capture", preview: false)
    }

    func setParameter(name: String, value: Any) throws -> [String: Any] {
        let key: String
        let formatted: String
        switch name {
        case "exposureTime":
            key = "shutterspeed"
            let number = (value as? NSNumber)?.doubleValue ?? 0.008
            formatted = number < 1 ? "1/\(Int((1 / number).rounded()))" : String(number)
        case "aperture":
            key = "f-number"
            formatted = String(describing: value)
        case "iso":
            key = "iso"
            formatted = String(Int((value as? NSNumber)?.doubleValue ?? 400))
        case "exposureCompensation":
            key = "exposurecompensation"
            formatted = String(describing: value)
        case "whiteBalanceMode":
            key = "whitebalance"
            formatted = String(describing: value) == "continuous" ? "Automatic" : "Manual"
        case "focusMode":
            key = "focusmode"
            let mode = String(describing: value)
            formatted = mode == "continuous" ? "Continuous-servo AF" : mode == "manual" ? "Manual" : "Single-servo AF"
        case "exposureMode":
            key = "expprogram"
            formatted = String(describing: value) == "manual" ? "M" : "P"
        default:
            throw CameraError.command("Z8 不支持此参数：\(name)")
        }
        _ = try run(["--set-config", "\(key)=\(formatted)"])
        settings[name] = value
        return ["value": value, "settings": settings]
    }

    func disconnect() {
        stopLiveView()
        connected = false
    }
}

private final class NativeBridge: NSObject, WKScriptMessageHandler {
    weak var webView: WKWebView?
    private let camera = GPhotoCamera()
    private let cameraQueue = DispatchQueue(label: "com.tauber.nikonlink.camera", qos: .userInitiated)

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard
            let body = message.body as? [String: Any],
            let id = body["id"] as? String,
            let method = body["method"] as? String
        else { return }
        let params = body["params"] as? [String: Any] ?? [:]

        cameraQueue.async { [weak self] in
            guard let self else { return }
            let reply: BridgeReply
            do {
                let result: [String: Any]
                switch method {
                case "connect": result = try self.camera.connect()
                case "startLiveView":
                    try self.camera.startLiveView()
                    result = [:]
                case "stopLiveView":
                    self.camera.stopLiveView()
                    result = [:]
                case "getLiveViewFrame": result = try self.camera.preview()
                case "capture": result = try self.camera.capture()
                case "setParameter":
                    guard let name = params["name"] as? String, let value = params["value"] else {
                        throw CameraError.command("参数格式无效。")
                    }
                    result = try self.camera.setParameter(name: name, value: value)
                case "disconnect":
                    self.camera.disconnect()
                    result = [:]
                default: throw CameraError.command("未知操作：\(method)")
                }
                reply = .success(result)
            } catch {
                reply = .failure(error.localizedDescription)
            }
            self.respond(id: id, reply: reply)
        }
    }

    private func respond(id: String, reply: BridgeReply) {
        let encoder = JSONEncoder()
        guard
            let replyData = try? encoder.encode(reply),
            let replyJSON = String(data: replyData, encoding: .utf8),
            let idData = try? JSONEncoder().encode(id),
            let idJSON = String(data: idData, encoding: .utf8)
        else { return }
        DispatchQueue.main.async { [weak self] in
            self?.webView?.evaluateJavaScript("window.NikonNativeBridge._resolve(\(idJSON), \(replyJSON));")
        }
    }
}

private final class AppDelegate: NSObject, NSApplicationDelegate, WKNavigationDelegate {
    private var window: NSWindow!
    private var bridge: NativeBridge!

    func applicationDidFinishLaunching(_ notification: Notification) {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        bridge = NativeBridge()
        configuration.userContentController.add(bridge, name: "nikonNative")

        let webView = WKWebView(frame: .zero, configuration: configuration)
        bridge.webView = webView
        webView.navigationDelegate = self
        webView.setValue(false, forKey: "drawsBackground")

        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1440, height: 920),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Nikon Link"
        window.titlebarAppearsTransparent = true
        window.minSize = NSSize(width: 980, height: 680)
        window.contentView = webView
        window.center()
        window.makeKeyAndOrderFront(nil)

        guard let webRoot = Bundle.main.resourceURL?.appendingPathComponent("Web"),
              let index = URL(string: "index.html", relativeTo: webRoot) else { return }
        webView.loadFileURL(index, allowingReadAccessTo: webRoot)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

let application = NSApplication.shared
private let delegate = AppDelegate()
application.delegate = delegate
application.setActivationPolicy(.regular)
application.run()
