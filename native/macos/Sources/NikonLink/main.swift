import AppKit
import Foundation
import SwiftUI

private struct SupportedCamera: Equatable {
    let name: String
    let productID: Int
    let detectionTokens: [String]

    static let all = [
        SupportedCamera(
            name: "Nikon Z8",
            productID: 0x0451,
            detectionTokens: ["nikon z8"]
        ),
        SupportedCamera(
            name: "Nikon Z f",
            productID: 0x0453,
            detectionTokens: ["nikon zf", "nikon z f"]
        ),
        SupportedCamera(
            name: "Nikon Z6III",
            productID: 0x0454,
            detectionTokens: ["nikon z6 iii", "nikon z6iii", "nikon z6 3"]
        ),
        SupportedCamera(
            name: "Nikon Z5II",
            productID: 0x0456,
            detectionTokens: ["nikon z5 2", "nikon z5 ii", "nikon z5ii"]
        )
    ]

    static let summary = "Z8 · Z f · Z6III · Z5II"

    static func matching(detection: String) -> SupportedCamera? {
        let normalized = detection
            .lowercased()
            .replacingOccurrences(of: ":", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
        return all.first { camera in
            camera.detectionTokens.contains { normalized.contains($0) }
        }
    }

    static func matching(productID: Int) -> SupportedCamera? {
        all.first { $0.productID == productID }
    }
}

private enum CameraError: LocalizedError {
    case command(String)
    case noCamera
    case wrongCamera(String)
    case noImage

    var errorDescription: String? {
        switch self {
        case .command(let value): return value
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
    private let resources = Bundle.main.resourceURL!
    private var connected = false
    private var liveView = false
    private(set) var profile: SupportedCamera?

    private var cameraName: String {
        profile?.name ?? "Nikon 相机"
    }

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
            throw CameraError.command("相机操作超时，请重新连接 \(cameraName)。")
        }
        let data = output.fileHandleForReading.readDataToEndOfFile()
        let text = String(decoding: data, as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard process.terminationStatus == 0 else {
            throw CameraError.command(text.isEmpty ? "\(cameraName) 返回了错误状态。" : text)
        }
        return text
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
            if vendor == 0x04b0,
               let product,
               let match = SupportedCamera.matching(productID: product) {
                return match
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
        let detected = try run(["--auto-detect"])
        let matchedProfile =
            SupportedCamera.matching(detection: detected)
            ?? detectedUSBProfile()
        guard let matchedProfile else {
            if !detected.localizedCaseInsensitiveContains("nikon"),
               !detected.localizedCaseInsensitiveContains("ptp class camera") {
                throw CameraError.noCamera
            }
            let name = detected.split(separator: "\n").last.map(String.init) ?? "其他 Nikon 相机"
            throw CameraError.wrongCamera(name)
        }
        profile = matchedProfile
        _ = try run(["--summary"])
        connected = true
        return matchedProfile
    }

    func startLiveView() throws {
        guard connected else { throw CameraError.noCamera }
        liveView = true
    }

    func stopLiveView() {
        liveView = false
    }

    private func imageData(prefix: String, preview: Bool) throws -> Data {
        guard connected else { throw CameraError.noCamera }
        if preview && !liveView {
            throw CameraError.command("实时取景尚未开启。")
        }
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("NikonLink", isDirectory: true)
        try FileManager.default.createDirectory(
            at: folder,
            withIntermediateDirectories: true
        )
        let stem = "\(prefix)-\(UUID().uuidString)"
        let target = folder.appendingPathComponent("\(stem).%C")
        let arguments = preview
            ? ["--capture-preview", "--filename", target.path, "--force-overwrite"]
            : ["--capture-image-and-download", "--filename", target.path, "--force-overwrite"]
        _ = try run(arguments, timeout: preview ? 15 : 60)
        let files = try FileManager.default.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: nil
        )
        guard let image = files
            .filter({ $0.lastPathComponent.hasPrefix(stem) })
            .sorted(by: {
                $0.pathExtension.lowercased() == "jpg"
                    && $1.pathExtension.lowercased() != "jpg"
            })
            .first,
            let data = try? Data(contentsOf: image),
            !data.isEmpty
        else {
            throw CameraError.noImage
        }
        try? FileManager.default.removeItem(at: image)
        return data
    }

    func preview() throws -> Data {
        try imageData(prefix: "preview", preview: true)
    }

    func capture() throws -> Data {
        try imageData(prefix: "capture", preview: false)
    }

    func setParameter(name: String, value: Any) throws {
        guard connected else { throw CameraError.noCamera }
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
            formatted = mode == "continuous"
                ? "Continuous-servo AF"
                : mode == "manual" ? "Manual" : "Single-servo AF"
        case "exposureMode":
            key = "expprogram"
            formatted = String(describing: value) == "manual" ? "M" : "P"
        default:
            throw CameraError.command("\(cameraName) 不支持此参数：\(name)")
        }
        _ = try run(["--set-config", "\(key)=\(formatted)"])
    }

    func disconnect() {
        stopLiveView()
        connected = false
        profile = nil
    }
}

private struct PhotoRecord: Identifiable, Hashable {
    let url: URL
    let createdAt: Date
    var id: URL { url }
    var name: String { url.lastPathComponent }
}

private enum ExperienceMode: String, CaseIterable, Identifiable {
    case simple = "普通"
    case professional = "专业"
    var id: String { rawValue }
}

private enum AppSection: String, CaseIterable, Identifiable {
    case capture = "拍摄"
    case monitor = "监看"
    case library = "文件"
    case transfer = "传输"

    var id: String { rawValue }
    var icon: String {
        switch self {
        case .capture: return "camera"
        case .monitor: return "display"
        case .library: return "photo.on.rectangle.angled"
        case .transfer: return "paperplane"
        }
    }
}

private final class CameraModel: ObservableObject {
    @Published var connected = false
    @Published var connecting = false
    @Published var liveViewEnabled = false
    @Published var capturing = false
    @Published var frame: NSImage?
    @Published var status = "未连接"
    @Published var detail = "USB/PTP · 支持 \(SupportedCamera.summary)"
    @Published var cameraName: String?
    @Published var mode: ExperienceMode = .simple
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

    private let camera = GPhotoCamera()
    private let cameraQueue = DispatchQueue(
        label: "com.tauber.nikonlink.camera",
        qos: .userInitiated
    )
    private var previewToken = UUID()
    private let photoDirectory: URL

    var activeCameraName: String {
        cameraName ?? "Nikon 相机"
    }

    init() {
        let pictures = FileManager.default.urls(
            for: .picturesDirectory,
            in: .userDomainMask
        ).first ?? FileManager.default.homeDirectoryForCurrentUser
        photoDirectory = pictures.appendingPathComponent("Nikon Link", isDirectory: true)
        try? FileManager.default.createDirectory(
            at: photoDirectory,
            withIntermediateDirectories: true
        )
        reloadPhotos()
    }

    func connect() {
        guard !connecting else { return }
        connecting = true
        status = "正在连接"
        detail = "正在检测 \(SupportedCamera.summary)…"
        cameraQueue.async { [weak self] in
            guard let self else { return }
            do {
                let profile = try self.camera.connect()
                var liveViewStarted = false
                do {
                    try self.camera.startLiveView()
                    liveViewStarted = true
                } catch {
                    liveViewStarted = false
                }
                let initialLiveView = liveViewStarted
                DispatchQueue.main.async {
                    self.connected = true
                    self.connecting = false
                    self.liveViewEnabled = initialLiveView
                    self.cameraName = profile.name
                    self.status = profile.name
                    self.detail = initialLiveView
                        ? "USB/PTP · 原生连接"
                        : "USB/PTP 已连接 · 实时取景需实机确认"
                    if initialLiveView {
                        self.startPreviewLoop()
                    }
                }
            } catch {
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
        previewToken = UUID()
        liveViewEnabled = false
        cameraQueue.async { [weak self] in
            self?.camera.disconnect()
        }
        connected = false
        frame = nil
        cameraName = nil
        status = "未连接"
        detail = "USB/PTP · 支持 \(SupportedCamera.summary)"
    }

    func toggleLiveView() {
        guard connected else {
            errorMessage = "请先连接支持的 Nikon 相机。"
            return
        }
        if liveViewEnabled {
            previewToken = UUID()
            liveViewEnabled = false
            cameraQueue.async { [weak self] in self?.camera.stopLiveView() }
        } else {
            cameraQueue.async { [weak self] in
                guard let self else { return }
                do {
                    try self.camera.startLiveView()
                    DispatchQueue.main.async {
                        self.liveViewEnabled = true
                        self.startPreviewLoop()
                    }
                } catch {
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
        pullPreview(token: token)
    }

    private func pullPreview(token: UUID) {
        guard token == previewToken, connected, liveViewEnabled else { return }
        cameraQueue.async { [weak self] in
            guard let self, token == self.previewToken else { return }
            do {
                let data = try self.camera.preview()
                let image = NSImage(data: data)
                DispatchQueue.main.async {
                    guard token == self.previewToken else { return }
                    if let image { self.frame = image }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                        self.pullPreview(token: token)
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    guard token == self.previewToken else { return }
                    self.detail = "实时取景正在重试"
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
        capturing = true
        detail = "正在触发 \(activeCameraName) 快门…"
        cameraQueue.async { [weak self] in
            guard let self else { return }
            do {
                let data = try self.camera.capture()
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyyMMdd_HHmmss"
                let filename = "NIKON_\(formatter.string(from: Date())).JPG"
                let url = self.photoDirectory.appendingPathComponent(filename)
                try data.write(to: url, options: .atomic)
                let image = NSImage(data: data)
                DispatchQueue.main.async {
                    self.capturing = false
                    self.detail = "拍摄完成 · 已保存到本地照片库"
                    if let image { self.frame = image }
                    self.reloadPhotos()
                    self.selectedPhoto = self.photos.first
                }
            } catch {
                DispatchQueue.main.async {
                    self.capturing = false
                    self.detail = "拍摄失败"
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    func reloadPhotos() {
        let keys: Set<URLResourceKey> = [.creationDateKey, .contentModificationDateKey]
        let urls = (try? FileManager.default.contentsOfDirectory(
            at: photoDirectory,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsHiddenFiles]
        )) ?? []
        photos = urls
            .filter { ["jpg", "jpeg", "png"].contains($0.pathExtension.lowercased()) }
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
            errorMessage = "无法移到废纸篓：\(error.localizedDescription)"
        }
    }

    func revealLibrary() {
        NSWorkspace.shared.activateFileViewerSelecting([photoDirectory])
    }

    func applyParameter(_ name: String, value: Any, label: String) {
        guard connected else {
            errorMessage = "连接支持的 Nikon 相机后才能调整参数。"
            return
        }
        detail = "正在设置 \(label)…"
        cameraQueue.async { [weak self] in
            guard let self else { return }
            do {
                try self.camera.setParameter(name: name, value: value)
                DispatchQueue.main.async {
                    self.detail = "\(label)已应用"
                }
            } catch {
                DispatchQueue.main.async {
                    self.detail = "\(label)设置失败"
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    func shutdown() {
        previewToken = UUID()
        camera.disconnect()
    }
}

private enum Palette {
    static let paper = Color(red: 0.965, green: 0.973, blue: 0.988)
    static let surface = Color.white
    static let ink = Color(red: 0.075, green: 0.09, blue: 0.12)
    static let muted = Color(red: 0.36, green: 0.40, blue: 0.47)
    static let cobalt = Color(red: 0.02, green: 0.35, blue: 0.82)
    static let cobaltSoft = Color(red: 0.88, green: 0.93, blue: 1.0)
    static let graphite = Color(red: 0.045, green: 0.055, blue: 0.075)
    static let rule = Color.black.opacity(0.10)
}

private struct NativeButtonStyle: ButtonStyle {
    var primary = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(primary ? Color.white : Palette.ink)
            .padding(.horizontal, 16)
            .frame(minHeight: 40)
            .background(primary ? Palette.cobalt : Palette.surface)
            .clipShape(RoundedRectangle(cornerRadius: 9))
            .overlay {
                RoundedRectangle(cornerRadius: 9)
                    .stroke(primary ? Color.clear : Palette.rule, lineWidth: 1)
            }
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}

private struct PreviewStage: View {
    @ObservedObject var model: CameraModel
    var compact = false

    var body: some View {
        ZStack {
            Palette.graphite
            if let frame = model.frame {
                Image(nsImage: frame)
                    .resizable()
                    .scaledToFit()
            } else {
                VStack(spacing: 14) {
                    Image(systemName: "camera.aperture")
                        .font(.system(size: compact ? 38 : 54, weight: .light))
                    Text(model.connected ? "等待实时取景画面" : "连接支持的 Nikon 相机开始监看")
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
                Spacer()
                if model.mode == .professional {
                    HStack {
                        Text("1/125")
                        Text("F\(model.aperture, specifier: "%.1f")")
                        Text("ISO \(model.iso)")
                        Spacer()
                        Text("JPEG · 1024×680 PREVIEW")
                    }
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.78))
                }
            }
            .padding(16)
        }
        .aspectRatio(16 / 10, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        }
    }
}

private struct TopBar: View {
    @ObservedObject var model: CameraModel
    @Binding var showConnection: Bool

    var body: some View {
        HStack(spacing: 16) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8).fill(Palette.graphite)
                    Text("N")
                        .font(.system(size: 20, weight: .heavy))
                        .foregroundStyle(.white)
                }
                .frame(width: 44, height: 44)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Nikon Link")
                        .font(.system(size: 18, weight: .bold))
                    Text("原生版")
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
                        Text(model.status).font(.system(size: 14, weight: .bold))
                        Text(model.detail)
                            .font(.system(size: 11))
                            .foregroundStyle(Palette.muted)
                            .lineLimit(1)
                    }
                }
                .frame(width: 245, alignment: .leading)
            }
            .buttonStyle(NativeButtonStyle())

            Spacer()

            Picker("操作模式", selection: $model.mode) {
                ForEach(ExperienceMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 190)

            Button {
                showConnection = true
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 17, weight: .semibold))
            }
            .buttonStyle(NativeButtonStyle())
        }
        .padding(.horizontal, 20)
        .frame(height: 74)
        .background(Palette.surface)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Palette.rule).frame(height: 1)
        }
    }
}

private struct Sidebar: View {
    @ObservedObject var model: CameraModel

    var body: some View {
        VStack(spacing: 8) {
            ForEach(AppSection.allCases) { section in
                Button {
                    model.section = section
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: section.icon).font(.system(size: 19))
                        Text(section.rawValue).font(.system(size: 12, weight: .medium))
                    }
                    .foregroundStyle(model.section == section ? Palette.cobalt : Palette.muted)
                    .frame(width: 72, height: 70)
                    .background(model.section == section ? Palette.cobaltSoft : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(.vertical, 16)
        .frame(width: 94)
        .background(Palette.surface)
        .overlay(alignment: .trailing) {
            Rectangle().fill(Palette.rule).frame(width: 1)
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
                    VStack(alignment: .leading, spacing: 6) {
                        Text("联机拍摄")
                            .font(.system(size: 34, weight: .bold))
                        Text(
                            model.mode == .simple
                                ? "只保留常用控制，连接相机即可拍摄。"
                                : "原生 USB/PTP 控制台 · 曝光、对焦与实时取景。"
                        )
                        .foregroundStyle(Palette.muted)
                    }
                    PreviewStage(model: model)
                    HStack {
                        Button(model.liveViewEnabled ? "停止实时取景" : "开启实时取景") {
                            model.toggleLiveView()
                        }
                        .buttonStyle(NativeButtonStyle())
                        Spacer()
                        Button {
                            if model.connected { model.capture() }
                            else { showConnection = true }
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "camera.shutter.button.fill")
                                Text(model.capturing ? "拍摄中…" : "拍摄")
                            }
                            .frame(minWidth: 120)
                        }
                        .buttonStyle(NativeButtonStyle(primary: true))
                        .disabled(model.capturing)
                    }
                }
                .padding(28)
            }
            .frame(minWidth: 520)
            ParameterInspector(model: model)
                .frame(width: 330)
        }
    }
}

private struct ParameterInspector: View {
    @ObservedObject var model: CameraModel

    private let shutterOptions: [(String, Double)] = [
        ("1/8000", 0.000125), ("1/1000", 0.001), ("1/250", 0.004),
        ("1/125", 0.008), ("1/60", 0.0167), ("1/15", 0.0667), ("1 秒", 1.0)
    ]
    private var isoOptions: [Int] {
        model.cameraName == "Nikon Z8"
            ? [64, 100, 200, 400, 800, 1600, 3200, 6400, 12800, 25600]
            : [100, 200, 400, 800, 1600, 3200, 6400, 12800, 25600, 51200, 64000]
    }
    private let apertureOptions = [1.4, 2.0, 2.8, 4.0, 5.6, 8.0, 11.0, 16.0, 22.0]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Text("拍摄设置").font(.system(size: 21, weight: .bold))
                    Spacer()
                    Text(model.mode == .simple ? "普通" : "PRO")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(Palette.cobalt)
                }

                if model.mode == .simple {
                    nativeControl("拍摄风格") {
                        Text("自然 · 自动曝光")
                            .foregroundStyle(Palette.muted)
                    }
                    nativeControl("自动对焦") {
                        Toggle(
                            "轻触画面选择主体",
                            isOn: Binding(
                                get: { model.focusMode != "manual" },
                                set: { enabled in
                                    model.focusMode = enabled ? "single-shot" : "manual"
                                    model.applyParameter(
                                        "focusMode",
                                        value: model.focusMode,
                                        label: "自动对焦"
                                    )
                                }
                            )
                        )
                        .toggleStyle(.switch)
                    }
                    nativeControl("保存位置") {
                        Button("打开 Nikon Link 照片库") {
                            model.revealLibrary()
                        }
                        .buttonStyle(.link)
                    }
                } else {
                    nativeControl("快门速度") {
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
                    }
                    nativeControl("光圈") {
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
                    }
                    nativeControl("ISO") {
                        Picker(
                            "",
                            selection: Binding(
                                get: { model.iso },
                                set: { value in
                                    model.iso = value
                                    model.applyParameter("iso", value: value, label: "ISO")
                                }
                            )
                        ) {
                            ForEach(isoOptions, id: \.self) { value in
                                Text("\(value)").tag(value)
                            }
                        }
                    }
                    nativeControl("曝光补偿") {
                        HStack {
                            Slider(
                                value: Binding(
                                    get: { model.compensation },
                                    set: { model.compensation = $0 }
                                ),
                                in: -5...5,
                                step: 0.3
                            )
                            Text("\(model.compensation, specifier: "%+.1f") EV")
                                .font(.system(size: 12, design: .monospaced))
                                .frame(width: 62)
                        }
                        Button("应用曝光补偿") {
                            model.applyParameter(
                                "exposureCompensation",
                                value: model.compensation,
                                label: "曝光补偿"
                            )
                        }
                        .buttonStyle(.link)
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
                            Text("AF-S").tag("single-shot")
                            Text("AF-C").tag("continuous")
                            Text("MF").tag("manual")
                        }
                        .pickerStyle(.segmented)
                    }
                    nativeControl("曝光模式") {
                        Picker(
                            "",
                            selection: Binding(
                                get: { model.exposureMode },
                                set: { value in
                                    model.exposureMode = value
                                    model.applyParameter(
                                        "exposureMode",
                                        value: value,
                                        label: "曝光模式"
                                    )
                                }
                            )
                        ) {
                            Text("P").tag("continuous")
                            Text("M").tag("manual")
                        }
                        .pickerStyle(.segmented)
                    }
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
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(title)
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
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text("实时监看").font(.system(size: 34, weight: .bold))
                    Text("\(model.cameraName ?? SupportedCamera.summary) · 原生 JPEG 实时取景")
                        .foregroundStyle(Palette.muted)
                }
                Spacer()
                Button(model.liveViewEnabled ? "停止监看" : "开始监看") {
                    model.toggleLiveView()
                }
                .buttonStyle(NativeButtonStyle(primary: !model.liveViewEnabled))
            }
            PreviewStage(model: model)
            Spacer()
        }
        .padding(28)
    }
}

private struct LibraryView: View {
    @ObservedObject var model: CameraModel
    @State private var confirmDelete = false

    private let columns = [
        GridItem(.adaptive(minimum: 180, maximum: 260), spacing: 16)
    ]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("文件管理").font(.system(size: 30, weight: .bold))
                    Text("\(model.photos.count) 个本地文件")
                        .foregroundStyle(Palette.muted)
                }
                Spacer()
                Button("在访达中显示") { model.revealLibrary() }
                    .buttonStyle(NativeButtonStyle())
                Button("移到废纸篓") { confirmDelete = true }
                    .buttonStyle(NativeButtonStyle())
                    .disabled(model.selectedPhoto == nil)
            }
            .padding(24)
            Divider()
            if model.photos.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 46))
                    Text("还没有联机拍摄文件").font(.headline)
                    Text("照片将保存在“图片/Nikon Link”。")
                        .foregroundStyle(Palette.muted)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(model.photos) { photo in
                            Button {
                                model.selectedPhoto = photo
                            } label: {
                                VStack(alignment: .leading, spacing: 9) {
                                    if let image = NSImage(contentsOf: photo.url) {
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
                        }
                    }
                    .padding(24)
                }
            }
        }
        .alert("将照片移到废纸篓？", isPresented: $confirmDelete) {
            Button("取消", role: .cancel) {}
            Button("移到废纸篓", role: .destructive) {
                model.deleteSelectedPhoto()
            }
        } message: {
            Text(model.selectedPhoto?.name ?? "")
        }
    }
}

private struct TransferView: View {
    @ObservedObject var model: CameraModel

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            Text("传输队列").font(.system(size: 34, weight: .bold))
            Text("联机拍摄完成后，JPEG 会直接进入 macOS 本地照片库。")
                .foregroundStyle(Palette.muted)
            HStack(spacing: 22) {
                statusCard(
                    icon: "internaldrive",
                    title: "本地照片库",
                    value: "\(model.photos.count) 个文件"
                )
                statusCard(
                    icon: "cable.connector",
                    title: "相机通道",
                    value: model.connected ? "USB/PTP 已连接" : "等待连接"
                )
            }
            Button("打开保存位置") { model.revealLibrary() }
                .buttonStyle(NativeButtonStyle(primary: true))
            Spacer()
        }
        .padding(28)
    }

    private func statusCard(icon: String, title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 15) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundStyle(Palette.cobalt)
            Text(title).font(.headline)
            Text(value)
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(Palette.muted)
        }
        .padding(20)
        .frame(width: 250, alignment: .leading)
        .background(Palette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14).stroke(Palette.rule)
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
                Button(model.connecting ? "正在连接…" : "连接 Nikon 相机") {
                    model.connect()
                    dismiss()
                }
                .buttonStyle(NativeButtonStyle(primary: true))
                .disabled(model.connecting)
            }
        }
        .padding(26)
        .frame(width: 560)
    }
}

private struct RootView: View {
    @ObservedObject var model: CameraModel
    @State private var showConnection = false

    var body: some View {
        VStack(spacing: 0) {
            TopBar(model: model, showConnection: $showConnection)
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
                    case .transfer:
                        TransferView(model: model)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            HStack {
                Label(model.status, systemImage: model.connected ? "link" : "link.badge.plus")
                Spacer()
                Text(model.detail)
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
        .sheet(isPresented: $showConnection) {
            ConnectionSheet(model: model)
        }
        .alert(
            "Nikon Link",
            isPresented: Binding(
                get: { model.errorMessage != nil },
                set: { if !$0 { model.errorMessage = nil } }
            )
        ) {
            Button("好") { model.errorMessage = nil }
        } message: {
            Text(model.errorMessage ?? "")
        }
    }
}

private final class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow!
    private let model = CameraModel()

    func applicationDidFinishLaunching(_ notification: Notification) {
        let root = RootView(model: model)
        let hostingView = NSHostingView(rootView: root)
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1440, height: 900),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Nikon Link"
        window.titlebarAppearsTransparent = true
        window.minSize = NSSize(width: 1040, height: 700)
        window.contentView = hostingView
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        print("Nikon Link native SwiftUI ready")
    }

    func applicationWillTerminate(_ notification: Notification) {
        model.shutdown()
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
