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
    case library = "文件"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .capture: return "camera.fill"
        case .monitor: return "video.fill"
        case .library: return "folder.fill"
        }
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
    func saveCapture(_ data: Data, fileExtension: String) -> URL? {
        let safeExtension = fileExtension.lowercased() == "heic" ? "heic" : "jpg"

        do {
            let url = try workflow.store(
                data: data,
                originalFilename: "capture.\(safeExtension)",
                cameraName: "iOS Camera"
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
    func saveRecordedVideo(at temporaryURL: URL) -> URL? {
        do {
            let data = try Data(contentsOf: temporaryURL)
            let destination = try workflow.store(
                data: data,
                originalFilename: "recording.mov",
                cameraName: "iOS Camera"
            )
            try? fileManager.removeItem(at: temporaryURL)
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
    @Published var monitorVideoCodec: MonitorVideoCodec = .automatic
    @Published var monitorVideoSpec: MonitorVideoSpec = .automatic
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
    let library: MediaLibrary
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
        if let rawSpec = UserDefaults.standard.string(
            forKey: "monitorVideoSpec"
        ), let spec = MonitorVideoSpec(rawValue: rawSpec) {
            monitorVideoSpec = spec
        }

        let camera = CameraService()
        let library = MediaLibrary()
        let updater = UpdateController()
        self.camera = camera
        self.library = library
        self.updater = updater
        wireless = WirelessTransferServer(directory: library.storageDirectory) { [weak library] url in
            library?.reload()
            library?.selectedItemID = url.path
            library?.message = "已无线接收 \(url.lastPathComponent)"
        }

        camera.objectWillChange
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
        library.objectWillChange
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
                      let url = self.library.saveCapture(data, fileExtension: fileExtension) else {
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
                self.statusMessage = "录制完成 · \(url.lastPathComponent)"
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
    }

    func setMonitorVideoCodec(_ codec: MonitorVideoCodec) {
        monitorVideoCodec = codec
        UserDefaults.standard.set(codec.rawValue, forKey: "monitorVideoCodec")
        statusMessage = codec == .automatic
            ? "输出编码由输出目标自动选择；不改变实时取景输入"
            : "输出编码偏好 · \(codec.label)；不改变实时取景输入"
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
