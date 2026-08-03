import Combine
import Foundation
import Photos
import SwiftUI
import UIKit
import UniformTypeIdentifiers

enum AppLanguage: String, CaseIterable, Identifiable {
    case simplifiedChinese = "zh-Hans"
    case english = "en"
    case japanese = "ja"

    static let storageKey = "appLanguage"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .simplifiedChinese: return "简体中文"
        case .english: return "English"
        case .japanese: return "日本語"
        }
    }

    var locale: Locale {
        Locale(identifier: rawValue)
    }
}

enum AppSection: String, CaseIterable, Identifiable {
    case capture = "照片"
    case monitor = "视频"
    case editor = "编辑"
    case devices = "我的设备"
    case library = "文件"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .capture: return "camera.fill"
        case .monitor: return "video.fill"
        case .editor: return "slider.horizontal.3"
        case .library: return "folder.fill"
        case .devices: return "camera.badge.clock.fill"
        }
    }
}

struct RememberedCameraDevice: Codable, Identifiable, Equatable {
    let id: String
    var name: String
    var vendor: String
    var transport: String
    var lastConnectedAt: Date

    var imageAssetName: String {
        let normalized = "\(vendor) \(name)".lowercased()
        if normalized.contains("sony") { return "camera_sony" }
        if normalized.contains("canon") { return "camera_canon" }
        return "camera_nikon"
    }
}

@MainActor
final class RememberedDeviceStore: ObservableObject {
    @Published private(set) var devices: [RememberedCameraDevice] = []

    private let defaults: UserDefaults
    private let storageKey = "rememberedCameraDevices.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        guard let data = defaults.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode(
                [RememberedCameraDevice].self,
                from: data
              ) else {
            return
        }
        devices = decoded.sorted { $0.lastConnectedAt > $1.lastConnectedAt }
    }

    func remember(id: String, name: String, transport: String) {
        guard !id.isEmpty, !name.isEmpty else { return }
        let vendor: String
        let normalized = name.lowercased()
        if normalized.contains("sony") {
            vendor = "Sony"
        } else if normalized.contains("canon") {
            vendor = "Canon"
        } else if normalized.contains("nikon") {
            vendor = "Nikon"
        } else {
            vendor = "Camera"
        }
        let record = RememberedCameraDevice(
            id: id,
            name: name,
            vendor: vendor,
            transport: transport,
            lastConnectedAt: Date()
        )
        devices.removeAll { $0.id == id }
        devices.insert(record, at: 0)
        if devices.count > 12 {
            devices.removeLast(devices.count - 12)
        }
        persist()
    }

    func forget(_ device: RememberedCameraDevice) {
        devices.removeAll { $0.id == device.id }
        persist()
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(devices) else { return }
        defaults.set(data, forKey: storageKey)
    }
}

enum ShootingTaskKind: String, CaseIterable, Identifiable {
    case interval = "间隔拍摄"
    case exposureBracket = "曝光包围"
    case focusBracket = "焦点包围"
    case bulb = "B 门计时"

    var id: String { rawValue }
}

struct LibraryItem: Identifiable, Hashable {
    let url: URL
    let createdAt: Date

    var id: String { url.path }
    var filename: String { url.lastPathComponent }
    var isVideo: Bool {
        ["mov", "mp4", "m4v"].contains(url.pathExtension.lowercased())
    }
}

@MainActor
final class MediaLibrary: ObservableObject {
    @Published private(set) var items: [LibraryItem] = []
    @Published var selectedItemID: LibraryItem.ID?
    @Published var message = ""

    private let fileManager = FileManager.default
    private let directory: URL
    let workflow: CaptureWorkflow
    private let supportedExtensions: Set<String> = [
        "jpg", "jpeg", "heic", "heif", "png", "tif", "tiff", "nef", "nrw",
        "mov", "mp4", "m4v"
    ]

    init() {
        let documents = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let preferredDirectory = documents.appendingPathComponent(
            "ZENCHE",
            isDirectory: true
        )
        let legacyDirectory = documents.appendingPathComponent(
            "Nikon" + " Link",
            isDirectory: true
        )
        if !fileManager.fileExists(atPath: preferredDirectory.path),
           fileManager.fileExists(atPath: legacyDirectory.path) {
            try? fileManager.moveItem(
                at: legacyDirectory,
                to: preferredDirectory
            )
        }
        directory = preferredDirectory
        workflow = CaptureWorkflow(rootDirectory: preferredDirectory)
        try? fileManager.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: nil
        )
        reload()
    }

    var selectedItem: LibraryItem? {
        items.first { $0.id == selectedItemID }
    }

    var storageDirectory: URL {
        directory
    }

    @discardableResult
    func saveCapture(
        _ data: Data,
        fileExtension: String,
        location: CaptureLocation? = nil
    ) -> URL? {
        let safeExtension = fileExtension.lowercased() == "heic" ? "heic" : "jpg"

        do {
            let url = try workflow.store(
                data: data,
                originalFilename: "capture.\(safeExtension)",
                cameraName: "iOS Camera",
                location: location
            )
            DiagnosticLogger.shared.info(
                "capture",
                "照片已保存；文件=\(url.lastPathComponent)；大小=\(data.count)"
            )
            reload()
            selectedItemID = url.path
            message = "照片已保存到 帧澈 ZENCHE 文件库"
            return url
        } catch {
            DiagnosticLogger.shared.error(
                "capture",
                "保存照片失败：\(error.localizedDescription)"
            )
            message = "保存失败：\(error.localizedDescription)"
            return nil
        }
    }

    @discardableResult
    func saveCameraStorageObject(
        _ data: Data,
        filename: String,
        cameraName: String
    ) -> URL? {
        do {
            let url = try workflow.store(
                data: data,
                originalFilename: filename,
                cameraName: cameraName
            )
            reload()
            selectedItemID = url.path
            message = "已从相机下载 \(filename)"
            DiagnosticLogger.shared.info(
                "camera-storage",
                "机内文件已保存；源=\(filename)；文件=\(url.lastPathComponent)；大小=\(data.count)"
            )
            return url
        } catch {
            message = "保存机内文件失败：\(error.localizedDescription)"
            DiagnosticLogger.shared.error("camera-storage", message)
            return nil
        }
    }

    @discardableResult
    func saveRecordedVideo(at temporaryURL: URL) -> URL? {
        do {
            let destination = try workflow.adoptTemporaryRecording(
                from: temporaryURL,
                cameraName: "iOS Camera"
            )
            reload()
            selectedItemID = destination.path
            message = "视频已保存到 帧澈 ZENCHE 文件库"
            DiagnosticLogger.shared.info(
                "recording",
                "视频已保存；文件=\(destination.lastPathComponent)"
            )
            return destination
        } catch {
            DiagnosticLogger.shared.error(
                "recording",
                "保存视频失败：\(error.localizedDescription)"
            )
            message = "视频保存失败：\(error.localizedDescription)"
            return nil
        }
    }

    func importFiles(_ urls: [URL]) {
        var imported = 0
        var pairNames: [String: String] = [:]
        for sourceURL in urls {
            do {
                let pairKey = sourceURL.deletingPathExtension()
                    .lastPathComponent
                    .lowercased()
                let reservedBase = pairNames[pairKey]
                    ?? workflow.reserveBaseName(cameraName: "Imported")
                pairNames[pairKey] = reservedBase
                _ = try workflow.importFile(
                    from: sourceURL,
                    cameraName: "Imported",
                    reservedBaseName: reservedBase
                )
                imported += 1
            } catch {
                DiagnosticLogger.shared.error(
                    "library",
                    "导入文件失败：\(error.localizedDescription)"
                )
                message = "部分文件导入失败：\(error.localizedDescription)"
            }
        }
        reload()
        if imported > 0 {
            message = "已导入 \(imported) 个文件"
        }
    }

    func importPhotoData(_ data: Data, fileExtension: String = "jpg") {
        let normalizedExtension = supportedExtensions.contains(
            fileExtension.lowercased()
        ) ? fileExtension.lowercased() : "jpg"
        do {
            let destination = try workflow.store(
                data: data,
                originalFilename: "album.\(normalizedExtension)",
                cameraName: "System Album"
            )
            reload()
            selectedItemID = destination.path
            message = "照片已从机主相册加入文件库"
        } catch {
            DiagnosticLogger.shared.error(
                "library",
                "相册照片导入失败：\(error.localizedDescription)"
            )
            message = "相册照片导入失败：\(error.localizedDescription)"
        }
    }

    @discardableResult
    func saveEditedImage(
        _ data: Data,
        originalFilename: String
    ) -> URL? {
        do {
            let destination = try workflow.store(
                data: data,
                originalFilename: "edited.jpg",
                cameraName: "Editor"
            )
            reload()
            selectedItemID = destination.path
            message = "已保存编辑副本 · \(destination.lastPathComponent)"
            DiagnosticLogger.shared.info(
                "editor",
                "编辑副本已保存；来源=\(originalFilename)；文件=\(destination.lastPathComponent)"
            )
            return destination
        } catch {
            DiagnosticLogger.shared.error(
                "editor",
                "保存编辑副本失败：\(error.localizedDescription)"
            )
            message = "保存编辑副本失败：\(error.localizedDescription)"
            return nil
        }
    }

    @discardableResult
    func replaceEditedImage(
        _ data: Data,
        at sourceURL: URL,
        originalFilename: String
    ) -> URL? {
        do {
            let destination = try workflow.replace(
                data: data,
                at: sourceURL,
                originalFilename: originalFilename,
                cameraName: "Editor"
            )
            reload()
            selectedItemID = destination.path
            message = "已替换原图 · \(destination.lastPathComponent)"
            DiagnosticLogger.shared.info(
                "editor",
                "AI 修图已原子替换原图；文件=\(destination.lastPathComponent)"
            )
            return destination
        } catch {
            DiagnosticLogger.shared.error(
                "editor",
                "替换原图失败：\(error.localizedDescription)"
            )
            message = "替换原图失败：\(error.localizedDescription)"
            return nil
        }
    }

    func deleteSelected() {
        guard let selectedItem else { return }
        do {
            try fileManager.removeItem(at: selectedItem.url)
            selectedItemID = nil
            reload()
            message = "文件已删除"
        } catch {
            DiagnosticLogger.shared.error(
                "library",
                "删除文件失败：\(error.localizedDescription)"
            )
            message = "删除失败：\(error.localizedDescription)"
        }
    }

    func saveToSystemPhotos(_ url: URL, completion: @escaping (String) -> Void) {
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else {
                DispatchQueue.main.async {
                    completion("未获得“照片”写入权限")
                }
                return
            }

            PHPhotoLibrary.shared().performChanges {
                let request = PHAssetCreationRequest.forAsset()
                let resourceType: PHAssetResourceType = [
                    "mov", "mp4", "m4v"
                ].contains(url.pathExtension.lowercased()) ? .video : .photo
                request.addResource(with: resourceType, fileURL: url, options: nil)
            } completionHandler: { success, error in
                DispatchQueue.main.async {
                    completion(
                        success
                        ? "已保存到系统照片库"
                        : "系统照片库保存失败：\(error?.localizedDescription ?? "未知错误")"
                    )
                }
            }
        }
    }

    func reload() {
        let keys: Set<URLResourceKey> = [.contentModificationDateKey, .creationDateKey]
        let enumerator = fileManager.enumerator(
            at: directory,
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

        items = urls
            .filter { supportedExtensions.contains($0.pathExtension.lowercased()) }
            .map { url in
                let values = try? url.resourceValues(forKeys: keys)
                return LibraryItem(
                    url: url,
                    createdAt: values?.creationDate ?? values?.contentModificationDate ?? .distantPast
                )
            }
            .sorted { $0.createdAt > $1.createdAt }
    }
}

@MainActor
final class AppModel: ObservableObject {
    @Published var section: AppSection = .capture
    @Published var showingConnection = false
    @Published var showingSettings = false
    @Published var autoSaveToPhotos = false
    @Published var showGrid = false
    @Published var showSafeGuide = false
    @Published var monitorVideoVendor: MonitorVideoVendor = .system
    @Published var monitorVideoCodec: MonitorVideoCodec = .automatic
    @Published var monitorNLogEnabled = false
    @Published var monitorVideoLog: MonitorVideoLog = .off
    @Published var monitorVideoSpec: MonitorVideoSpec = .automatic
    @Published var monitorNikonCloudPresetID: String?
    @Published var shootingTaskKind: ShootingTaskKind = .interval
    @Published var shootingTaskCount = 5
    @Published var shootingTaskInterval = 3
    @Published var shootingTaskStep = 1
    @Published var shootingTaskRunning = false
    @Published var shootingTaskStatus = "尚未开始拍摄任务"
    @Published var statusMessage = "选择相机后即可开始"
    @Published var language: AppLanguage {
        didSet {
            UserDefaults.standard.set(
                language.rawValue,
                forKey: AppLanguage.storageKey
            )
        }
    }

    let camera: CameraService
    let wifiCamera: WifiCameraService
    let bluetoothRemote: BluetoothRemoteService
    let locationTagging: LocationTaggingService
    let library: MediaLibrary
    let rememberedDevices: RememberedDeviceStore
    var captureWorkflow: CaptureWorkflow { library.workflow }
    let wireless: WirelessTransferServer
    let updater: UpdateController
    private var subscriptions: Set<AnyCancellable> = []
    private var shootingTask: Task<Void, Never>?
    private var taskCaptureContinuation: CheckedContinuation<URL, Error>?

    init() {
        language = AppLanguage(
            rawValue: UserDefaults.standard.string(
                forKey: AppLanguage.storageKey
            ) ?? ""
        ) ?? .simplifiedChinese

        if let rawCodec = UserDefaults.standard.string(
            forKey: "monitorVideoCodec"
        ), let codec = MonitorVideoCodec(rawValue: rawCodec) {
            monitorVideoCodec = codec
        }
        if let rawVendor = UserDefaults.standard.string(
            forKey: "monitorVideoVendor"
        ), let vendor = MonitorVideoVendor(rawValue: rawVendor) {
            monitorVideoVendor = vendor
        }
        if let rawLog = UserDefaults.standard.string(
            forKey: "monitorVideoLog"
        ), let log = MonitorVideoLog(rawValue: rawLog) {
            monitorVideoLog = log
            monitorNLogEnabled = log == .nlog
        }
        if let rawSpec = UserDefaults.standard.string(
            forKey: "monitorVideoSpec"
        ), let spec = MonitorVideoSpec(rawValue: rawSpec) {
            monitorVideoSpec = spec
        }
        let camera = CameraService()
        let wifiCamera = WifiCameraService()
        let bluetoothRemote = BluetoothRemoteService()
        let locationTagging = LocationTaggingService()
        let library = MediaLibrary()
        let updater = UpdateController()
        let rememberedDevices = RememberedDeviceStore()
        self.camera = camera
        self.wifiCamera = wifiCamera
        self.bluetoothRemote = bluetoothRemote
        self.locationTagging = locationTagging
        self.library = library
        self.updater = updater
        self.rememberedDevices = rememberedDevices
        wireless = WirelessTransferServer(directory: library.storageDirectory) { [weak library] url in
            library?.reload()
            library?.selectedItemID = url.path
            library?.message = "已无线接收 \(url.lastPathComponent)"
        }
        if !availableRecordingCodecs.contains(monitorVideoCodec) {
            monitorVideoCodec = availableRecordingCodecs.first ?? .automatic
        }
        if !availableVideoLogs.contains(monitorVideoLog) {
            monitorVideoLog = .off
            monitorNLogEnabled = false
        }
        camera.setRecordingCodec(monitorVideoCodec)

        camera.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &subscriptions)
        wifiCamera.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &subscriptions)
        bluetoothRemote.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &subscriptions)
        locationTagging.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &subscriptions)
        camera.$state
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                guard let self, state == .ready else { return }
                self.camera.setMonitorVideoSpec(
                    self.monitorVideoSpec
                )
            }
            .store(in: &subscriptions)
        camera.$state
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                guard let self,
                      state == .ready,
                      let deviceID = self.camera.selectedDeviceID,
                      self.camera.isExternalCamera else {
                    return
                }
                self.rememberedDevices.remember(
                    id: deviceID,
                    name: self.camera.deviceName,
                    transport: "系统视频 · 外接"
                )
            }
            .store(in: &subscriptions)
        library.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &subscriptions)
        rememberedDevices.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &subscriptions)
        library.workflow.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &subscriptions)
        wireless.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &subscriptions)
        updater.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &subscriptions)
        wireless.$isRunning
            .receive(on: DispatchQueue.main)
            .sink { isRunning in
                UIApplication.shared.isIdleTimerDisabled = isRunning
            }
            .store(in: &subscriptions)
        wireless.$status
            .dropFirst()
            .sink { status in
                if status.contains("失败") || status.contains("错误") {
                    DiagnosticLogger.shared.error("wireless", status)
                } else {
                    DiagnosticLogger.shared.info("wireless", status)
                }
            }
            .store(in: &subscriptions)

        camera.onPhotoCaptured = { [weak self] data, fileExtension in
            Task { @MainActor in
                guard let self,
                      let url = self.library.saveCapture(
                          data,
                          fileExtension: fileExtension,
                          location: self.locationTagging.snapshot()
                      ) else {
                    return
                }
                self.statusMessage = "拍摄完成 · \(url.lastPathComponent)"
                if self.autoSaveToPhotos {
                    self.library.saveToSystemPhotos(url) { [weak self] message in
                        self?.statusMessage = message
                    }
                }
                self.taskCaptureContinuation?.resume(returning: url)
                self.taskCaptureContinuation = nil
            }
        }

        camera.onVideoRecorded = { [weak self] temporaryURL in
            Task { @MainActor in
                guard let self,
                      let url = self.library.saveRecordedVideo(at: temporaryURL)
                else {
                    return
                }
                self.statusMessage = "外录完成 · \(url.lastPathComponent)"
                if self.autoSaveToPhotos {
                    self.library.saveToSystemPhotos(url) { [weak self] message in
                        self?.statusMessage = message
                    }
                }
            }
        }

        camera.onMessage = { [weak self] message in
            if message.contains("失败") || message.contains("错误") {
                DiagnosticLogger.shared.error("camera", message)
            } else {
                DiagnosticLogger.shared.info("camera", message)
            }
            Task { @MainActor in
                self?.statusMessage = message
                if message.contains("拍摄失败"),
                   let continuation = self?.taskCaptureContinuation {
                    self?.taskCaptureContinuation = nil
                    continuation.resume(
                        throwing: CaptureTaskError.captureFailed(message)
                    )
                }
            }
        }

        bluetoothRemote.onShutter = { [weak self] in
            Task { @MainActor in
                self?.capturePhoto(source: "蓝牙遥控")
            }
        }
        wifiCamera.onShutterTriggered = { [weak self] in
            self?.statusMessage = "Wi‑Fi 快门已触发 · 原图保存在相机卡内"
        }
    }

    var isCaptureReady: Bool {
        camera.state == .ready || wifiCamera.isConnected
    }

    var hasAnyCameraConnection: Bool {
        camera.state == .ready || wifiCamera.isConnected
    }

    var connectionTitle: String {
        if wifiCamera.isConnected {
            return "Wi‑Fi 已连接"
        }
        return camera.state.title
    }

    func capturePhoto(source: String = "界面") {
        locationTagging.refresh()
        if camera.state == .ready {
            statusMessage = source == "蓝牙遥控"
                ? "已收到蓝牙快门 · 正在拍摄…"
                : "正在拍摄…"
            camera.capturePhoto()
        } else if wifiCamera.isConnected {
            statusMessage = source == "蓝牙遥控"
                ? "已收到蓝牙快门 · 正在通过 Wi‑Fi 触发…"
                : "正在通过 Wi‑Fi 触发快门…"
            wifiCamera.capture()
        } else {
            statusMessage = "请先连接系统相机或 Wi‑Fi 相机"
            showingConnection = true
        }
    }

    func disconnectAllCameras() {
        if camera.state == .ready {
            camera.disconnect()
        }
        wifiCamera.disconnect()
    }

    func setMonitorVideoCodec(_ codec: MonitorVideoCodec) {
        monitorVideoCodec = codec
        UserDefaults.standard.set(codec.rawValue, forKey: "monitorVideoCodec")
        camera.setRecordingCodec(codec)
        statusMessage = codec == .automatic
            ? "视频录制规格由输出目标自动选择"
            : "视频录制规格 · \(codec.label)"
    }

    var availableRecordingCodecs: [MonitorVideoCodec] {
        switch monitorVideoVendor {
        case .system:
            return MonitorVideoCodec.allCases.filter { $0.requiredBodyVendor == nil }
        case .nikon:
            return [.h264, .hevc, .proRes422HQ, .proResRAW, .nRaw]
        case .sony:
            return MonitorVideoCodec.allCases.filter { $0.requiredBodyVendor == .sony }
        case .canon:
            return MonitorVideoCodec.allCases.filter { $0.requiredBodyVendor == .canon }
        }
    }

    var availableVideoLogs: [MonitorVideoLog] {
        MonitorVideoLog.allCases.filter {
            $0 == .off || $0.vendor == monitorVideoVendor
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
        camera.setMonitorNikonCloudPreset(preset)
        statusMessage = preset.map {
            "尼康云创监看 · \($0.name) · 照片/视频 · SDR 近似"
        } ?? "尼康云创监看已关闭"
    }

    func setMonitorVideoVendor(_ vendor: MonitorVideoVendor) {
        monitorVideoVendor = vendor
        UserDefaults.standard.set(vendor.rawValue, forKey: "monitorVideoVendor")
        if !availableRecordingCodecs.contains(monitorVideoCodec) {
            setMonitorVideoCodec(availableRecordingCodecs.first ?? .automatic)
        }
        if !availableVideoLogs.contains(monitorVideoLog) {
            setMonitorVideoLog(.off)
        }
    }

    func setMonitorVideoLog(_ log: MonitorVideoLog) {
        monitorVideoLog = log
        monitorNLogEnabled = log == .nlog
        UserDefaults.standard.set(log.rawValue, forKey: "monitorVideoLog")
        camera.setVideoLog(log)
        statusMessage = "Log / Picture Profile · \(log.label)"
    }

    func setMonitorNLogEnabled(_ enabled: Bool) {
        setMonitorVideoLog(enabled ? .nlog : .off)
    }

    func setMonitorVideoSpec(_ spec: MonitorVideoSpec) {
        monitorVideoSpec = spec
        UserDefaults.standard.set(spec.rawValue, forKey: "monitorVideoSpec")
        camera.setMonitorVideoSpec(spec)
    }

    func startShootingTask() {
        guard camera.state == .ready, !shootingTaskRunning else {
            statusMessage = "连接相机后才能开始拍摄任务"
            return
        }
        shootingTask?.cancel()
        let kind = shootingTaskKind
        let count = max(1, min(999, shootingTaskCount))
        let interval = max(1, min(3600, shootingTaskInterval))
        let step = max(1, min(3, shootingTaskStep))
        let originalBias = camera.exposureBias
        shootingTaskRunning = true
        shootingTaskStatus = "\(kind.rawValue)准备中"
        shootingTask = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                var total = kind == .bulb ? 1 : count
                if kind == .exposureBracket, total.isMultiple(of: 2) {
                    total += 1
                }
                for index in 0..<total {
                    try Task.checkCancellation()
                    if kind == .exposureBracket {
                        let center = total / 2
                        let requested =
                            originalBias + Float(index - center) * Float(step)
                        camera.setExposureBias(requested)
                        try await Task.sleep(for: .milliseconds(350))
                    }
                    if kind == .focusBracket, index > 0 {
                        camera.moveFocus(step)
                        try await Task.sleep(for: .milliseconds(350))
                    }
                    if kind == .bulb {
                        camera.setTimedExposure(seconds: Double(interval))
                        try await Task.sleep(for: .milliseconds(500))
                    }
                    let url = try await captureForTask()
                    shootingTaskStatus =
                        "\(kind.rawValue) · \(index + 1)/\(total) · \(url.lastPathComponent)"
                    statusMessage = shootingTaskStatus
                    if kind == .interval, index + 1 < total {
                        try await Task.sleep(for: .seconds(interval))
                    }
                }
                if kind == .exposureBracket {
                    camera.setExposureBias(originalBias)
                }
                shootingTaskRunning = false
                shootingTaskStatus = "\(kind.rawValue)已完成"
                statusMessage = shootingTaskStatus
            } catch is CancellationError {
                if kind == .exposureBracket {
                    camera.setExposureBias(originalBias)
                }
                shootingTaskRunning = false
                shootingTaskStatus = "拍摄任务已取消"
                statusMessage = shootingTaskStatus
            } catch {
                if kind == .exposureBracket {
                    camera.setExposureBias(originalBias)
                }
                shootingTaskRunning = false
                shootingTaskStatus = "拍摄任务失败"
                statusMessage = error.localizedDescription
            }
        }
    }

    func cancelShootingTask() {
        shootingTask?.cancel()
        shootingTask = nil
        taskCaptureContinuation?.resume(throwing: CancellationError())
        taskCaptureContinuation = nil
        shootingTaskStatus = "正在取消拍摄任务…"
    }

    private func captureForTask() async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            taskCaptureContinuation = continuation
            camera.capturePhoto()
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(20))
                guard let self,
                      let pending = self.taskCaptureContinuation else {
                    return
                }
                self.taskCaptureContinuation = nil
                pending.resume(throwing: CaptureTaskError.timeout)
            }
        }
    }
}

private enum CaptureTaskError: LocalizedError {
    case captureFailed(String)
    case timeout

    var errorDescription: String? {
        switch self {
        case .captureFailed(let message): return message
        case .timeout: return "相机未在 20 秒内返回照片"
        }
    }
}
