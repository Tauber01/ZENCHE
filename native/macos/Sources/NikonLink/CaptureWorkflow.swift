import Combine
import CryptoKit
import Foundation

struct CaptureSessionConfiguration: Codable, Equatable {
    var name = "未命名会话"
    var namingTemplate = "{session}_{date}_{counter}"
    var creator = ""
    var rights = ""
    var rating = 0
    var dualBackupEnabled = true
}

private final class ImportCancellationSignal: @unchecked Sendable {
    private let lock = NSLock()
    private var cancelled = false

    var isCancelled: Bool {
        lock.lock()
        defer { lock.unlock() }
        return cancelled
    }

    func cancel() {
        lock.lock()
        cancelled = true
        lock.unlock()
    }
}

/// The batch token and the workflow's state/finalization locks serialize every
/// import mutation. This narrow wrapper makes that audited ownership explicit
/// without declaring the UI-facing ObservableObject itself Sendable.
private final class ImportWorkflowReference: @unchecked Sendable {
    let workflow: CaptureWorkflow

    init(_ workflow: CaptureWorkflow) {
        self.workflow = workflow
    }
}

final class CaptureWorkflow: ObservableObject {
    @Published private(set) var configuration: CaptureSessionConfiguration
    @Published private(set) var isActive: Bool
    @Published private(set) var counter: Int
    @Published private(set) var status = "尚未开始拍摄会话"

    private let rootDirectory: URL
    private let defaults: UserDefaults
    private let fileManager = FileManager.default
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let stateLock = NSLock()
    private let finalizeLock = NSLock()
    private var importOperationToken: UUID?
    private var nonImportOperationToken: UUID?
    private let stateKey = "captureSessionConfiguration"
    private let activeKey = "captureSessionActive"
    private let counterKey = "captureSessionCounter"

    init(rootDirectory: URL, defaults: UserDefaults = .standard) {
        self.rootDirectory = rootDirectory
        self.defaults = defaults
        if let data = defaults.data(forKey: stateKey),
           let saved = try? decoder.decode(
               CaptureSessionConfiguration.self,
               from: data
           ) {
            configuration = saved
        } else {
            configuration = CaptureSessionConfiguration()
        }
        isActive = defaults.bool(forKey: activeKey)
        counter = max(1, defaults.integer(forKey: counterKey))
        if isActive {
            try? ensureSessionDirectories()
            status = "会话进行中 · \(configuration.name)"
        }
    }

    var sessionRoot: URL? {
        guard isActive else { return nil }
        return rootDirectory
            .appendingPathComponent("Sessions", isDirectory: true)
            .appendingPathComponent(
                sanitized(configuration.name),
                isDirectory: true
            )
    }

    var primaryDirectory: URL {
        sessionRoot?.appendingPathComponent("Primary", isDirectory: true)
            ?? rootDirectory
    }

    var backupDirectory: URL? {
        guard configuration.dualBackupEnabled else { return nil }
        return sessionRoot?.appendingPathComponent("Backup", isDirectory: true)
    }

    func begin(_ configuration: CaptureSessionConfiguration) throws {
        stateLock.lock()
        defer { stateLock.unlock() }
        guard importOperationToken == nil,
              nonImportOperationToken == nil else {
            throw ImportError.sessionLocked
        }
        self.configuration = normalized(configuration)
        isActive = true
        counter = 1
        try ensureSessionDirectories()
        persist()
        status = "会话进行中 · \(self.configuration.name)"
    }

    func end() {
        stateLock.lock()
        defer { stateLock.unlock() }
        guard importOperationToken == nil,
              nonImportOperationToken == nil else {
            status = "导入期间不能切换拍摄会话。"
            return
        }
        isActive = false
        persist()
        status = "拍摄会话已结束"
    }

    func reserveBaseName(cameraName: String, date: Date = Date()) -> String {
        stateLock.lock()
        defer { stateLock.unlock() }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        var value = configuration.namingTemplate
        value = value.replacingOccurrences(
            of: "{session}",
            with: configuration.name
        )
        value = value.replacingOccurrences(
            of: "{date}",
            with: formatter.string(from: date)
        )
        value = value.replacingOccurrences(
            of: "{counter}",
            with: String(format: "%04d", counter)
        )
        value = value.replacingOccurrences(
            of: "{camera}",
            with: cameraName
        )
        counter += 1
        persist()
        return sanitized(value)
    }

    func beginImportBatch() throws -> UUID {
        stateLock.lock()
        defer { stateLock.unlock() }
        guard importOperationToken == nil,
              nonImportOperationToken == nil else {
            throw ImportError.importInProgress
        }
        let token = UUID()
        importOperationToken = token
        return token
    }

    func endImportBatch(_ token: UUID) {
        stateLock.lock()
        if importOperationToken == token {
            importOperationToken = nil
        }
        stateLock.unlock()
    }

    private func validateImportBatch(_ token: UUID) throws {
        stateLock.lock()
        defer { stateLock.unlock() }
        guard importOperationToken == token else {
            throw ImportError.importInProgress
        }
    }

    /// Claims exclusive ownership of session/library mutations outside import.
    /// Composite operations keep the returned token for their entire lifetime
    /// and pass it through every store/finalize step.
    func beginNonImportOperation() throws -> UUID {
        stateLock.lock()
        defer { stateLock.unlock() }
        guard importOperationToken == nil,
              nonImportOperationToken == nil else {
            throw ImportError.sessionLocked
        }
        let token = UUID()
        nonImportOperationToken = token
        return token
    }

    func endNonImportOperation(_ token: UUID) {
        stateLock.lock()
        if nonImportOperationToken == token {
            nonImportOperationToken = nil
        }
        stateLock.unlock()
    }

    private func validateNonImportOperation(_ token: UUID) throws {
        stateLock.lock()
        defer { stateLock.unlock() }
        guard nonImportOperationToken == token,
              importOperationToken == nil else {
            throw ImportError.sessionLocked
        }
    }

    /// Moves a library file to the system Trash, then reconciles the exact
    /// session that owns it. A same-stem sidecar is retained while another
    /// media file still references it (for example a RAW + JPEG pair).
    func deleteLibraryFile(
        at primary: URL,
        operationToken: UUID
    ) throws {
        try validateNonImportOperation(operationToken)
        let normalizedPrimary = primary.standardizedFileURL
        guard isDescendant(normalizedPrimary, of: rootDirectory) else {
            throw CocoaError(.fileNoSuchFile)
        }

        let primaryDirectory = normalizedPrimary.deletingLastPathComponent()
        let sessionRoot = sessionRootOwning(normalizedPrimary)
        let sidecar = normalizedPrimary
            .deletingPathExtension()
            .appendingPathExtension("xmp")
        let backup = sessionRoot?
            .appendingPathComponent("Backup", isDirectory: true)
            .appendingPathComponent(normalizedPrimary.lastPathComponent)
        let backupSidecar = backup?
            .deletingPathExtension()
            .appendingPathExtension("xmp")
        let keepSharedSidecar = hasSameStemMediaSibling(
            as: normalizedPrimary,
            in: primaryDirectory
        )

        guard fileManager.fileExists(atPath: normalizedPrimary.path) else {
            throw CocoaError(.fileNoSuchFile)
        }
        try fileManager.trashItem(
            at: normalizedPrimary,
            resultingItemURL: nil
        )

        var failures: [Error] = []
        func attemptTrash(_ url: URL?) {
            guard let url,
                  fileManager.fileExists(atPath: url.path) else { return }
            do {
                try fileManager.trashItem(at: url, resultingItemURL: nil)
            } catch {
                failures.append(error)
            }
        }

        if let sessionRoot {
            let manifest = sessionRoot.appendingPathComponent("checksums.sha256")
            if fileManager.fileExists(atPath: manifest.path) {
                do {
                    let relative = "Primary/\(normalizedPrimary.lastPathComponent)"
                    let existing = try String(
                        contentsOf: manifest,
                        encoding: .utf8
                    )
                    let lines = existing
                        .split(separator: "\n", omittingEmptySubsequences: true)
                        .map(String.init)
                        .filter { !$0.hasSuffix("  \(relative)") }
                    let updated = lines.joined(separator: "\n")
                        .appending(lines.isEmpty ? "" : "\n")
                    try updated.write(
                        to: manifest,
                        atomically: true,
                        encoding: .utf8
                    )
                } catch {
                    failures.append(error)
                }
            }
        }

        attemptTrash(backup)
        if !keepSharedSidecar {
            attemptTrash(sidecar)
            attemptTrash(backupSidecar)
        }

        if !failures.isEmpty {
            throw LibraryDeletionError(failures: failures)
        }
    }

    private let libraryMediaExtensions: Set<String> = [
        "jpg", "jpeg", "png", "nef", "nrw", "arw", "cr2", "cr3",
        "heif", "heic", "tif", "tiff", "mov", "mp4", "m4v", "avi"
    ]

    private func isDescendant(_ candidate: URL, of root: URL) -> Bool {
        let rootComponents = root.standardizedFileURL.pathComponents
        let candidateComponents = candidate.standardizedFileURL.pathComponents
        return candidateComponents.count > rootComponents.count &&
            candidateComponents.prefix(rootComponents.count)
                .elementsEqual(rootComponents)
    }

    private func sessionRootOwning(_ primary: URL) -> URL? {
        let primaryDirectory = primary.deletingLastPathComponent()
        guard primaryDirectory.lastPathComponent == "Primary" else {
            return nil
        }
        let candidate = primaryDirectory.deletingLastPathComponent()
        guard candidate.deletingLastPathComponent().lastPathComponent == "Sessions",
              isDescendant(candidate, of: rootDirectory) else {
            return nil
        }
        return candidate
    }

    private func hasSameStemMediaSibling(
        as primary: URL,
        in directory: URL
    ) -> Bool {
        let stem = primary.deletingPathExtension().lastPathComponent
        let siblings = (try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )) ?? []
        return siblings.contains { sibling in
            sibling.standardizedFileURL != primary.standardizedFileURL &&
                sibling.deletingPathExtension().lastPathComponent == stem &&
                libraryMediaExtensions.contains(
                    sibling.pathExtension.lowercased()
                )
        }
    }

    struct LibraryDeletionError: LocalizedError {
        let failures: [Error]

        var errorDescription: String? {
            "文件已移到废纸篓，但有 \(failures.count) 个会话关联项未能同步。"
        }
    }

    private func withNonImportOperation<T>(
        token: UUID?,
        _ body: () throws -> T
    ) throws -> T {
        if let token {
            try validateNonImportOperation(token)
            return try body()
        }
        let ownedToken = try beginNonImportOperation()
        defer { endNonImportOperation(ownedToken) }
        return try body()
    }

    @discardableResult
    func store(
        data: Data,
        originalFilename: String,
        cameraName: String,
        reservedBaseName: String? = nil,
        location: CaptureLocation? = nil,
        pairedWithFilename: String? = nil,
        operationToken: UUID? = nil
    ) throws -> URL {
        try withNonImportOperation(token: operationToken) {
            try ensureSessionDirectories()
            let original = URL(fileURLWithPath: originalFilename)
            let fileExtension = original.pathExtension.isEmpty
                ? "jpg"
                : original.pathExtension.lowercased()
            let base = reservedBaseName
                ?? reserveBaseName(cameraName: cameraName)
            let destination = uniqueURL(
                in: primaryDirectory,
                base: base,
                extension: fileExtension
            )
            try data.write(to: destination, options: .atomic)
            try finalize(
                destination,
                location: location,
                pairedWithFilename: pairedWithFilename
            )
            status = "已写入会话 · \(destination.lastPathComponent)"
            return destination
        }
    }

    /// E5 live 图：把快门切片 AVI 以照片同 base 存入会话，
    /// XMP sidecar 写配对标记（指向配对照片），双备份/SHA-256 全复用。
    /// TBC-awaiting-hardware。
    @discardableResult
    func storeLivePhotoClip(
        from sourceURL: URL,
        baseName: String,
        pairedPhotoFilename: String,
        cameraName: String,
        operationToken: UUID? = nil
    ) throws -> URL {
        try withNonImportOperation(token: operationToken) {
            try ensureSessionDirectories()
            let destination = uniqueURL(
                in: primaryDirectory,
                base: "\(baseName)_live",
                extension: "avi"
            )
            if fileManager.fileExists(atPath: destination.path) {
                try? fileManager.removeItem(at: destination)
            }
            try fileManager.moveItem(at: sourceURL, to: destination)
            try finalize(
                destination,
                location: nil,
                pairedWithFilename: pairedPhotoFilename
            )
            status = "live 图视频已写入会话 · \(destination.lastPathComponent)"
            return destination
        }
    }

    /// E6 延时合成：把渲染好的 MP4 以新 base 存入会话，
    /// 复用 finalize 全套（XMP sidecar/双备份/SHA-256 清单）。
    /// TBC-awaiting-hardware。
    @discardableResult
    func storeTimelapseVideo(
        from sourceURL: URL,
        cameraName: String
    ) throws -> URL {
        try withNonImportOperation(token: nil) {
            try ensureSessionDirectories()
            let destination = uniqueURL(
                in: primaryDirectory,
                base: reserveBaseName(cameraName: cameraName),
                extension: "mp4"
            )
            if fileManager.fileExists(atPath: destination.path) {
                try? fileManager.removeItem(at: destination)
            }
            try fileManager.moveItem(at: sourceURL, to: destination)
            try finalize(destination, location: nil, pairedWithFilename: nil)
            status = "延时视频已写入会话 · \(destination.lastPathComponent)"
            return destination
        }
    }

    /// E7 焦点合成：把合成好的 JPEG 以新 base 存入会话，
    /// 复用 finalize 全套（XMP sidecar/双备份/SHA-256 清单），
    /// XMP 写 focus-stack 合成标记 + 源帧数。
    /// TBC-awaiting-hardware。
    @discardableResult
    func storeFocusStack(
        from sourceURL: URL,
        cameraName: String,
        stackSourceCount: Int
    ) throws -> URL {
        try withNonImportOperation(token: nil) {
            try ensureSessionDirectories()
            let destination = uniqueURL(
                in: primaryDirectory,
                base: reserveBaseName(cameraName: cameraName),
                extension: "jpg"
            )
            if fileManager.fileExists(atPath: destination.path) {
                try? fileManager.removeItem(at: destination)
            }
            try fileManager.moveItem(at: sourceURL, to: destination)
            try finalize(
                destination,
                location: nil,
                pairedWithFilename: nil,
                stackSourceCount: stackSourceCount
            )
            status = "焦点合成已写入会话 · \(destination.lastPathComponent)"
            return destination
        }
    }

    @discardableResult
    func replace(
        data: Data,
        at destination: URL,
        originalFilename: String,
        cameraName: String
    ) throws -> URL {
        try withNonImportOperation(token: nil) {
            try ensureSessionDirectories()
            let temporary = destination
                .deletingLastPathComponent()
                .appendingPathComponent(".replace-\(UUID().uuidString).tmp")
            try data.write(to: temporary, options: .atomic)
            do {
                if fileManager.fileExists(atPath: destination.path) {
                    _ = try fileManager.replaceItem(
                        at: destination,
                        withItemAt: temporary,
                        backupItemName: nil,
                        options: .usingNewMetadataOnly,
                        resultingItemURL: nil
                    )
                } else {
                    try fileManager.moveItem(at: temporary, to: destination)
                }
            } catch {
                try? fileManager.removeItem(at: temporary)
                throw error
            }
            try finalize(destination, location: nil)
            try replaceChecksumEntry(for: destination)
            status = "已替换原图 · \(destination.lastPathComponent)"
            return destination
        }
    }

    static let supportedImportExtensions: Set<String> = [
        "jpg", "jpeg", "png", "heic", "heif",
        "tif", "tiff", "nef", "nrw", "arw", "cr2", "cr3",
        "mov", "mp4", "m4v", "avi"
    ]

    enum ImportError: Error {
        case unsupportedExtension
        case emptySource
        case sourceInsideLibrary
        case sizeMismatch
        case cannotCreateTemp
        case importInProgress
        case sessionLocked
        case backupCollision
        case rollbackTargetNotFile
        case rollbackIncomplete
    }

    @discardableResult
    func importFile(
        from source: URL,
        cameraName: String,
        reservedBaseName: String? = nil,
        shouldCancel: () -> Bool = { false }
    ) throws -> URL {
        let token = try beginImportBatch()
        defer { endImportBatch(token) }
        return try importFileInBatch(
            from: source,
            cameraName: cameraName,
            reservedBaseName: reservedBaseName,
            importToken: token,
            shouldCancel: shouldCancel
        )
    }

    private func importFileInBatch(
        from source: URL,
        cameraName: String,
        reservedBaseName: String?,
        importToken: UUID,
        shouldCancel: () -> Bool
    ) throws -> URL {
        try validateImportBatch(importToken)
        guard !shouldCancel() else { throw CancellationError() }
        let scoped = source.startAccessingSecurityScopedResource()
        defer {
            if scoped {
                source.stopAccessingSecurityScopedResource()
            }
        }

        let fileExtension = source.pathExtension.lowercased()
        guard CaptureWorkflow.supportedImportExtensions.contains(fileExtension) else {
            throw ImportError.unsupportedExtension
        }

        let canonicalSource = source.standardizedFileURL.resolvingSymlinksInPath()
        let canonicalRoot = rootDirectory.standardizedFileURL
            .resolvingSymlinksInPath()
        var relationship = FileManager.URLRelationship.other
        try fileManager.getRelationship(
            &relationship,
            ofDirectoryAt: canonicalRoot,
            toItemAt: canonicalSource
        )
        if relationship == .contains || relationship == .same {
            throw ImportError.sourceInsideLibrary
        }

        let sourcePath = source.path
        let sourceSize = (try? fileManager.attributesOfItem(
            atPath: sourcePath
        )[.size] as? Int64) ?? 0
        guard sourceSize > 0 else {
            throw ImportError.emptySource
        }

        try ensureSessionDirectories()
        let base = reservedBaseName
            ?? reserveBaseName(cameraName: cameraName)
        let destination = uniqueURL(
            in: primaryDirectory,
            base: base,
            extension: fileExtension
        )
        let temp = primaryDirectory
            .appendingPathComponent(".zenche-import-\(UUID().uuidString).part")

        var published = false
        do {
            let sourceHandle = try FileHandle(forReadingFrom: source)
            defer { try? sourceHandle.close() }

            guard fileManager.createFile(
                atPath: temp.path,
                contents: nil,
                attributes: nil
            ) else {
                throw ImportError.cannotCreateTemp
            }
            let tempHandle = try FileHandle(forWritingTo: temp)
            defer { try? tempHandle.close() }

            let bufferSize = 256 * 1024
            while let chunk = try sourceHandle.read(upToCount: bufferSize),
                  !chunk.isEmpty {
                guard !shouldCancel() else { throw CancellationError() }
                try tempHandle.write(contentsOf: chunk)
            }
            guard !shouldCancel() else { throw CancellationError() }
            try tempHandle.synchronize()

            let finalSourceSize = (try? fileManager.attributesOfItem(
                atPath: sourcePath
            )[.size] as? Int64) ?? 0
            let tempSize = (try? fileManager.attributesOfItem(
                atPath: temp.path
            )[.size] as? Int64) ?? 0
            guard finalSourceSize == sourceSize,
                  tempSize == sourceSize else {
                throw ImportError.sizeMismatch
            }

            try fileManager.moveItem(at: temp, to: destination)
            published = true
            guard !shouldCancel() else { throw CancellationError() }
            try finalize(
                destination,
                location: nil,
                shouldCancel: shouldCancel,
                transactionalImport: true
            )
            return destination
        } catch {
            let originalError = error
            var cleanupErrors: [Error] = []

            do {
                try removeImportArtifact(
                    at: temp,
                    expectedParent: primaryDirectory
                )
            } catch {
                cleanupErrors.append(error)
            }
            if published {
                do {
                    try removeImportArtifact(
                        at: destination,
                        expectedParent: primaryDirectory
                    )
                } catch {
                    cleanupErrors.append(error)
                }
            }

            guard !cleanupErrors.isEmpty else {
                throw originalError
            }
            if let rollbackError = originalError as? ImportFinalizeRollbackError {
                throw ImportFinalizeRollbackError(
                    originalError: rollbackError.originalError,
                    rollbackErrors: rollbackError.rollbackErrors + cleanupErrors
                )
            }
            throw ImportFinalizeRollbackError(
                originalError: originalError,
                rollbackErrors: cleanupErrors
            )
        }
    }

    func importFileAsync(
        from source: URL,
        cameraName: String,
        reservedBaseName: String? = nil,
        importToken: UUID
    ) async throws -> URL {
        let cancellation = ImportCancellationSignal()
        let workflowReference = ImportWorkflowReference(self)
        return try await withTaskCancellationHandler(operation: {
            try Task.checkCancellation()
            return try await withCheckedThrowingContinuation { continuation in
                DispatchQueue.global(qos: .userInitiated).async {
                    do {
                        let url = try workflowReference.workflow.importFileInBatch(
                            from: source,
                            cameraName: cameraName,
                            reservedBaseName: reservedBaseName,
                            importToken: importToken,
                            shouldCancel: { cancellation.isCancelled }
                        )
                        continuation.resume(returning: url)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
        }, onCancel: {
            cancellation.cancel()
        })
    }

    func reserveExternalRecording(
        cameraName: String,
        extension fileExtension: String = "avi",
        operationToken: UUID
    ) throws -> URL {
        try withNonImportOperation(token: operationToken) {
            try ensureSessionDirectories()
            let normalized = fileExtension.lowercased() == "avi" ? "avi" : "avi"
            return uniqueURL(
                in: primaryDirectory,
                base: reserveBaseName(cameraName: cameraName),
                extension: normalized
            )
        }
    }

    func completeExternalRecording(
        at url: URL,
        operationToken: UUID
    ) throws {
        try withNonImportOperation(token: operationToken) {
            let values = try url.resourceValues(forKeys: [.fileSizeKey])
            guard (values.fileSize ?? 0) > 0 else {
                throw CocoaError(.fileReadCorruptFile)
            }
            try finalize(
                url,
                location: nil,
                transactionalImport: true
            )
            status = "外录已写入会话 · \(url.lastPathComponent)"
        }
    }

    private func finalize(
        _ primary: URL,
        location: CaptureLocation?,
        pairedWithFilename: String? = nil,
        stackSourceCount: Int? = nil,
        shouldCancel: () -> Bool = { false },
        transactionalImport: Bool = false
    ) throws {
        finalizeLock.lock()
        defer { finalizeLock.unlock() }
        if isActive || location != nil || pairedWithFilename != nil || stackSourceCount != nil {
            let xmp = xmpSidecar(
                for: primary.lastPathComponent,
                location: location,
                pairedWithFilename: pairedWithFilename,
                stackSourceCount: stackSourceCount
            )
            let sidecar = primary
                .deletingPathExtension()
                .appendingPathExtension("xmp")
            let snapshot = transactionalImport
                ? try importMetadataSnapshot(primary: primary, sidecar: sidecar)
                : nil
            do {
                try xmp.write(to: sidecar, atomically: true, encoding: .utf8)
                guard !shouldCancel() else { throw CancellationError() }
                if isActive, let backupDirectory {
                    let backup = backupDirectory
                        .appendingPathComponent(primary.lastPathComponent)
                    try copyFileAtomically(
                        from: primary,
                        to: backup,
                        shouldCancel: shouldCancel
                    )
                    let backupSidecar = backup
                        .deletingPathExtension()
                        .appendingPathExtension("xmp")
                    try copyFileAtomically(
                        from: sidecar,
                        to: backupSidecar,
                        shouldCancel: shouldCancel
                    )
                }
                if isActive, let sessionRoot {
                    let digest = try sha256Hex(
                        of: primary,
                        shouldCancel: shouldCancel
                    )
                    let manifest = sessionRoot.appendingPathComponent(
                        "checksums.sha256"
                    )
                    guard !shouldCancel() else { throw CancellationError() }
                    let line = "\(digest)  Primary/\(primary.lastPathComponent)\n"
                    try appendChecksumAtomically(line, to: manifest)
                }
            } catch {
                let originalError = error
                if let snapshot {
                    do {
                        try restoreImportMetadata(snapshot)
                    } catch let rollbackError as MetadataRollbackError {
                        throw ImportFinalizeRollbackError(
                            originalError: originalError,
                            rollbackErrors: rollbackError.failures
                        )
                    } catch {
                        throw ImportFinalizeRollbackError(
                            originalError: originalError,
                            rollbackErrors: [error]
                        )
                    }
                }
                throw originalError
            }
        }
    }

    private func replaceChecksumEntry(for primary: URL) throws {
        finalizeLock.lock()
        defer { finalizeLock.unlock() }
        guard let sessionRoot else { return }
        let manifest = sessionRoot.appendingPathComponent("checksums.sha256")
        let digest = try sha256Hex(of: primary)
        let relative = "Primary/\(primary.lastPathComponent)"
        let existing = fileManager.fileExists(atPath: manifest.path)
            ? try String(contentsOf: manifest, encoding: .utf8)
            : ""
        let lines = existing
            .split(separator: "\n", omittingEmptySubsequences: true)
            .map(String.init)
            .filter { !$0.hasSuffix("  \(relative)") }
        try (lines + ["\(digest)  \(relative)"])
            .joined(separator: "\n")
            .appending("\n")
            .write(to: manifest, atomically: true, encoding: .utf8)
    }

    private struct ImportMetadataSnapshot {
        let sidecar: URL
        let sidecarData: Data?
        let backup: URL?
        let backupSidecar: URL?
        let backupSidecarData: Data?
    }

    private struct MetadataRollbackError: LocalizedError {
        let failures: [Error]

        var errorDescription: String? {
            "元数据回滚有 \(failures.count) 个步骤失败。"
        }
    }

    private struct ImportFinalizeRollbackError: LocalizedError {
        let originalError: Error
        let rollbackErrors: [Error]

        var errorDescription: String? {
            let rollbackSummary = rollbackErrors
                .map { $0.localizedDescription }
                .joined(separator: "；")
            return "导入失败（\(originalError.localizedDescription)），" +
                "且文件回滚失败（\(rollbackSummary)）。"
        }
    }

    private func importMetadataSnapshot(
        primary: URL,
        sidecar: URL
    ) throws -> ImportMetadataSnapshot {
        let sidecarData = fileManager.fileExists(atPath: sidecar.path)
            ? try Data(contentsOf: sidecar)
            : nil
        let backup = isActive
            ? backupDirectory?.appendingPathComponent(primary.lastPathComponent)
            : nil
        if let backup,
           fileManager.fileExists(atPath: backup.path) {
            throw ImportError.backupCollision
        }
        let backupSidecar = backup?
            .deletingPathExtension()
            .appendingPathExtension("xmp")
        let backupSidecarData: Data?
        if let backupSidecar,
           fileManager.fileExists(atPath: backupSidecar.path) {
            backupSidecarData = try Data(contentsOf: backupSidecar)
        } else {
            backupSidecarData = nil
        }
        return ImportMetadataSnapshot(
            sidecar: sidecar,
            sidecarData: sidecarData,
            backup: backup,
            backupSidecar: backupSidecar,
            backupSidecarData: backupSidecarData
        )
    }

    private func restoreImportMetadata(
        _ snapshot: ImportMetadataSnapshot
    ) throws {
        var failures: [Error] = []
        func attempt(_ operation: () throws -> Void) {
            do {
                try operation()
            } catch {
                failures.append(error)
            }
        }
        if let backup = snapshot.backup {
            attempt { try removeRollbackFile(at: backup) }
        }
        attempt {
            try restoreFile(
                at: snapshot.backupSidecar,
                data: snapshot.backupSidecarData
            )
        }
        attempt {
            try restoreFile(at: snapshot.sidecar, data: snapshot.sidecarData)
        }
        if !failures.isEmpty {
            throw MetadataRollbackError(failures: failures)
        }
    }

    private func restoreFile(at url: URL?, data: Data?) throws {
        guard let url else { return }
        if let data {
            try data.write(to: url, options: .atomic)
        } else {
            try removeRollbackFile(at: url)
        }
    }

    private func removeRollbackFile(at url: URL) throws {
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(
            atPath: url.path,
            isDirectory: &isDirectory
        ) else { return }
        guard !isDirectory.boolValue else {
            throw ImportError.rollbackTargetNotFile
        }
        try fileManager.removeItem(at: url)
        if fileManager.fileExists(atPath: url.path) {
            throw ImportError.rollbackIncomplete
        }
    }

    private func removeImportArtifact(
        at url: URL,
        expectedParent: URL
    ) throws {
        let actualParent = url
            .deletingLastPathComponent()
            .standardizedFileURL
            .resolvingSymlinksInPath()
        let allowedParent = expectedParent
            .standardizedFileURL
            .resolvingSymlinksInPath()
        guard actualParent.path == allowedParent.path else {
            throw ImportError.rollbackTargetNotFile
        }
        try removeRollbackFile(at: url)
    }

    private func xmpSidecar(
        for filename: String,
        location: CaptureLocation?,
        pairedWithFilename: String? = nil,
        stackSourceCount: Int? = nil
    ) -> String {
        let title = xmlEscaped(configuration.name)
        let creator = xmlEscaped(configuration.creator)
        let rights = xmlEscaped(configuration.rights)
        let gps = location.map(gpsAttributes) ?? ""
        let pairing = pairedWithFilename.map {
            "\n              xmp:Label=\"live-photo\"\n              dc:relation=\"\(xmlEscaped($0))\""
        } ?? ""
        let stack = stackSourceCount.map {
            "\n              xmp:Label=\"focus-stack\"\n              xmp:FocusStackSources=\"\($0)\""
        } ?? ""
        return """
        <?xpacket begin="" id="W5M0MpCehiHzreSzNTczkc9d"?>
        <x:xmpmeta xmlns:x="adobe:ns:meta/">
          <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
            <rdf:Description rdf:about=""
              xmlns:xmp="http://ns.adobe.com/xap/1.0/"
              xmlns:dc="http://purl.org/dc/elements/1.1/"
              xmlns:exif="http://ns.adobe.com/exif/1.0/"
              xmp:Rating="\(configuration.rating)"\(gps)\(pairing)\(stack)>
              <dc:title><rdf:Alt><rdf:li xml:lang="x-default">\(title)</rdf:li></rdf:Alt></dc:title>
              <dc:creator><rdf:Seq><rdf:li>\(creator)</rdf:li></rdf:Seq></dc:creator>
              <dc:rights><rdf:Alt><rdf:li xml:lang="x-default">\(rights)</rdf:li></rdf:Alt></dc:rights>
              <dc:description><rdf:Alt><rdf:li xml:lang="x-default">\(xmlEscaped(filename))</rdf:li></rdf:Alt></dc:description>
            </rdf:Description>
          </rdf:RDF>
        </x:xmpmeta>
        <?xpacket end="w"?>
        """
    }

    private func gpsAttributes(_ location: CaptureLocation) -> String {
        let latitude = gpsCoordinate(location.latitude, positive: "N", negative: "S")
        let longitude = gpsCoordinate(location.longitude, positive: "E", negative: "W")
        let altitudeRef = location.altitude < 0 ? 1 : 0
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy:MM:dd"
        return """

              exif:GPSLatitude="\(latitude)"
              exif:GPSLongitude="\(longitude)"
              exif:GPSAltitude="\(String(format: "%.2f", abs(location.altitude)))"
              exif:GPSAltitudeRef="\(altitudeRef)"
              exif:GPSHPositioningError="\(String(format: "%.2f", max(0, location.horizontalAccuracy)))"
              exif:GPSDateStamp="\(formatter.string(from: location.capturedAt))"
        """
    }

    private func gpsCoordinate(
        _ value: Double,
        positive: String,
        negative: String
    ) -> String {
        let direction = value >= 0 ? positive : negative
        let absolute = abs(value)
        let degrees = Int(absolute)
        let minutes = (absolute - Double(degrees)) * 60
        return "\(degrees),\(String(format: "%.6f", minutes))\(direction)"
    }

    private func ensureSessionDirectories() throws {
        try fileManager.createDirectory(
            at: primaryDirectory,
            withIntermediateDirectories: true
        )
        if let backupDirectory {
            try fileManager.createDirectory(
                at: backupDirectory,
                withIntermediateDirectories: true
            )
        }
    }

    private func normalized(
        _ value: CaptureSessionConfiguration
    ) -> CaptureSessionConfiguration {
        var result = value
        result.name = result.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if result.name.isEmpty {
            result.name = "未命名会话"
        }
        if !result.namingTemplate.contains("{counter}") {
            result.namingTemplate += "_{counter}"
        }
        result.rating = max(0, min(5, result.rating))
        return result
    }

    private func uniqueURL(
        in directory: URL,
        base: String,
        extension: String
    ) -> URL {
        var result = directory
            .appendingPathComponent(base)
            .appendingPathExtension(`extension`)
        var suffix = 2
        while fileManager.fileExists(atPath: result.path) {
            result = directory
                .appendingPathComponent("\(base)_\(suffix)")
                .appendingPathExtension(`extension`)
            suffix += 1
        }
        return result
    }

    private func copyFileAtomically(
        from source: URL,
        to destination: URL,
        shouldCancel: () -> Bool
    ) throws {
        let temp = destination.deletingLastPathComponent()
            .appendingPathComponent(".zenche-backup-\(UUID().uuidString).part")
        defer { try? fileManager.removeItem(at: temp) }
        guard fileManager.createFile(
            atPath: temp.path,
            contents: nil,
            attributes: nil
        ) else {
            throw ImportError.cannotCreateTemp
        }
        let sourceHandle = try FileHandle(forReadingFrom: source)
        defer { try? sourceHandle.close() }
        let tempHandle = try FileHandle(forWritingTo: temp)
        defer { try? tempHandle.close() }
        let expectedSize = try source.resourceValues(forKeys: [.fileSizeKey])
            .fileSize ?? 0
        var copied = 0
        while let chunk = try sourceHandle.read(upToCount: 256 * 1024),
              !chunk.isEmpty {
            guard !shouldCancel() else { throw CancellationError() }
            try tempHandle.write(contentsOf: chunk)
            copied += chunk.count
        }
        guard !shouldCancel(), copied == expectedSize else {
            if shouldCancel() { throw CancellationError() }
            throw ImportError.sizeMismatch
        }
        try tempHandle.synchronize()
        try tempHandle.close()
        try sourceHandle.close()
        if fileManager.fileExists(atPath: destination.path) {
            _ = try fileManager.replaceItemAt(destination, withItemAt: temp)
        } else {
            try fileManager.moveItem(at: temp, to: destination)
        }
    }

    private func sha256Hex(
        of url: URL,
        shouldCancel: () -> Bool = { false }
    ) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hasher = SHA256()
        while let chunk = try handle.read(upToCount: 256 * 1024),
              !chunk.isEmpty {
            guard !shouldCancel() else { throw CancellationError() }
            hasher.update(data: chunk)
        }
        return hasher.finalize()
            .map { String(format: "%02x", $0) }
            .joined()
    }

    private func appendChecksumAtomically(
        _ line: String,
        to manifest: URL
    ) throws {
        let existing = fileManager.fileExists(atPath: manifest.path)
            ? try String(contentsOf: manifest, encoding: .utf8)
            : ""
        let temporary = manifest.deletingLastPathComponent()
            .appendingPathComponent(".zenche-manifest-\(UUID().uuidString).tmp")
        defer { try? fileManager.removeItem(at: temporary) }
        guard fileManager.createFile(
            atPath: temporary.path,
            contents: nil,
            attributes: nil
        ) else {
            throw ImportError.cannotCreateTemp
        }
        let handle = try FileHandle(forWritingTo: temporary)
        defer { try? handle.close() }
        try handle.write(contentsOf: Data((existing + line).utf8))
        try handle.synchronize()
        try handle.close()
        if fileManager.fileExists(atPath: manifest.path) {
            _ = try fileManager.replaceItemAt(manifest, withItemAt: temporary)
        } else {
            try fileManager.moveItem(at: temporary, to: manifest)
        }
    }

    private func persist() {
        defaults.set(isActive, forKey: activeKey)
        defaults.set(counter, forKey: counterKey)
        if let data = try? encoder.encode(configuration) {
            defaults.set(data, forKey: stateKey)
        }
    }

    private func sanitized(_ value: String) -> String {
        let invalid = CharacterSet(charactersIn: "/\\:?%*|\"<>")
        let components = value.components(separatedBy: invalid)
        let joined = components.joined(separator: "_")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return joined.isEmpty ? "ZENCHE" : String(joined.prefix(120))
    }

    private func xmlEscaped(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }
}
