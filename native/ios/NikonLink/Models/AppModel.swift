import Combine
import Foundation
import Photos
import SwiftUI
import UIKit

enum ExperienceMode: String, CaseIterable, Identifiable {
    case simple = "普通"
    case professional = "专业"

    var id: String { rawValue }
}

enum AppSection: String, CaseIterable, Identifiable {
    case capture = "照片"
    case monitor = "视频"
    case library = "文件"
    case transfer = "传输"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .capture: return "camera.fill"
        case .monitor: return "video.fill"
        case .library: return "photo.on.rectangle.angled"
        case .transfer: return "arrow.up.arrow.down"
        }
    }
}

struct LibraryItem: Identifiable, Hashable {
    let url: URL
    let createdAt: Date

    var id: String { url.path }
    var filename: String { url.lastPathComponent }
}

@MainActor
final class MediaLibrary: ObservableObject {
    @Published private(set) var items: [LibraryItem] = []
    @Published var selectedItemID: LibraryItem.ID?
    @Published var message = ""

    private let fileManager = FileManager.default
    private let directory: URL
    private let supportedExtensions: Set<String> = [
        "jpg", "jpeg", "heic", "heif", "png", "tif", "tiff", "nef", "nrw"
    ]

    init() {
        let documents = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        directory = documents.appendingPathComponent("Nikon Link", isDirectory: true)
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
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss-SSS"
        let safeExtension = fileExtension.lowercased() == "heic" ? "heic" : "jpg"
        let url = directory
            .appendingPathComponent("NL-\(formatter.string(from: Date()))")
            .appendingPathExtension(safeExtension)

        do {
            try data.write(to: url, options: .atomic)
            reload()
            selectedItemID = url.path
            message = "照片已保存到 Nikon Link 文件库"
            return url
        } catch {
            message = "保存失败：\(error.localizedDescription)"
            return nil
        }
    }

    func importFiles(_ urls: [URL]) {
        var imported = 0
        for sourceURL in urls {
            let scoped = sourceURL.startAccessingSecurityScopedResource()
            defer {
                if scoped { sourceURL.stopAccessingSecurityScopedResource() }
            }

            var destination = directory.appendingPathComponent(sourceURL.lastPathComponent)
            if fileManager.fileExists(atPath: destination.path) {
                let stem = destination.deletingPathExtension().lastPathComponent
                let ext = destination.pathExtension
                destination = directory
                    .appendingPathComponent("\(stem)-\(UUID().uuidString.prefix(6))")
                    .appendingPathExtension(ext)
            }

            do {
                try fileManager.copyItem(at: sourceURL, to: destination)
                imported += 1
            } catch {
                message = "部分文件导入失败：\(error.localizedDescription)"
            }
        }
        reload()
        if imported > 0 {
            message = "已导入 \(imported) 个文件"
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
                request.addResource(with: .photo, fileURL: url, options: nil)
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
        let urls = (try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsHiddenFiles]
        )) ?? []

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
    @Published var mode: ExperienceMode = .simple
    @Published var section: AppSection = .capture
    @Published var showingConnection = false
    @Published var autoSaveToPhotos = false
    @Published var showGrid = false
    @Published var showSafeGuide = false
    @Published var monitorSupersampling = false
    @Published var monitorVideoCodec: MonitorVideoCodec = .automatic
    @Published var monitorVideoSpec: MonitorVideoSpec = .automatic
    @Published var statusMessage = "选择相机后即可开始"

    let camera: CameraService
    let library: MediaLibrary
    let wireless: WirelessTransferServer
    private var subscriptions: Set<AnyCancellable> = []

    init() {
        monitorSupersampling = UserDefaults.standard.bool(
            forKey: "monitorSupersampling"
        )
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
        self.camera = camera
        self.library = library
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
                    self.monitorVideoSpec,
                    supersampling: self.monitorSupersampling
                )
            }
            .store(in: &subscriptions)
        library.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &subscriptions)
        wireless.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &subscriptions)
        wireless.$isRunning
            .receive(on: DispatchQueue.main)
            .sink { isRunning in
                UIApplication.shared.isIdleTimerDisabled = isRunning
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
            }
        }

        camera.onMessage = { [weak self] message in
            Task { @MainActor in
                self?.statusMessage = message
            }
        }
    }

    func setMonitorSupersampling(_ enabled: Bool) {
        monitorSupersampling = enabled
        UserDefaults.standard.set(enabled, forKey: "monitorSupersampling")
        camera.setMonitorVideoSpec(monitorVideoSpec, supersampling: enabled)
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
        camera.setMonitorVideoSpec(spec, supersampling: monitorSupersampling)
    }
}
