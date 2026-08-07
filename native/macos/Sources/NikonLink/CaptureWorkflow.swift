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
        self.configuration = normalized(configuration)
        isActive = true
        counter = 1
        try ensureSessionDirectories()
        persist()
        status = "会话进行中 · \(self.configuration.name)"
    }

    func end() {
        isActive = false
        persist()
        status = "拍摄会话已结束"
    }

    func reserveBaseName(cameraName: String, date: Date = Date()) -> String {
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

    @discardableResult
    func store(
        data: Data,
        originalFilename: String,
        cameraName: String,
        reservedBaseName: String? = nil,
        location: CaptureLocation? = nil,
        pairedWithFilename: String? = nil
    ) throws -> URL {
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

    /// E5 live 图：把快门切片 AVI 以照片同 base 存入会话，
    /// XMP sidecar 写配对标记（指向配对照片），双备份/SHA-256 全复用。
    /// TBC-awaiting-hardware。
    @discardableResult
    func storeLivePhotoClip(
        from sourceURL: URL,
        baseName: String,
        pairedPhotoFilename: String,
        cameraName: String
    ) throws -> URL {
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

    /// E6 延时合成：把渲染好的 MP4 以新 base 存入会话，
    /// 复用 finalize 全套（XMP sidecar/双备份/SHA-256 清单）。
    /// TBC-awaiting-hardware。
    @discardableResult
    func storeTimelapseVideo(
        from sourceURL: URL,
        cameraName: String
    ) throws -> URL {
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

    @discardableResult
    func replace(
        data: Data,
        at destination: URL,
        originalFilename: String,
        cameraName: String
    ) throws -> URL {
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
        replaceChecksumEntry(for: destination)
        status = "已替换原图 · \(destination.lastPathComponent)"
        return destination
    }

    @discardableResult
    func importFile(
        from source: URL,
        cameraName: String,
        reservedBaseName: String? = nil
    ) throws -> URL {
        let scoped = source.startAccessingSecurityScopedResource()
        defer {
            if scoped {
                source.stopAccessingSecurityScopedResource()
            }
        }
        let data = try Data(contentsOf: source)
        return try store(
            data: data,
            originalFilename: source.lastPathComponent,
            cameraName: cameraName,
            reservedBaseName: reservedBaseName
        )
    }

    func reserveExternalRecording(
        cameraName: String,
        extension fileExtension: String = "avi"
    ) throws -> URL {
        try ensureSessionDirectories()
        let normalized = fileExtension.lowercased() == "avi" ? "avi" : "avi"
        return uniqueURL(
            in: primaryDirectory,
            base: reserveBaseName(cameraName: cameraName),
            extension: normalized
        )
    }

    func completeExternalRecording(at url: URL) throws {
        let values = try url.resourceValues(forKeys: [.fileSizeKey])
        guard (values.fileSize ?? 0) > 0 else {
            throw CocoaError(.fileReadCorruptFile)
        }
        try finalize(url, location: nil)
        status = "外录已写入会话 · \(url.lastPathComponent)"
    }

    private func finalize(
        _ primary: URL,
        location: CaptureLocation?,
        pairedWithFilename: String? = nil
    ) throws {
        if isActive || location != nil || pairedWithFilename != nil {
            let xmp = xmpSidecar(
                for: primary.lastPathComponent,
                location: location,
                pairedWithFilename: pairedWithFilename
            )
            let sidecar = primary
                .deletingPathExtension()
                .appendingPathExtension("xmp")
            try xmp.write(to: sidecar, atomically: true, encoding: .utf8)
            if isActive, let backupDirectory {
                let backup = backupDirectory
                    .appendingPathComponent(primary.lastPathComponent)
                try? fileManager.removeItem(at: backup)
                try fileManager.copyItem(at: primary, to: backup)
                let backupSidecar = backup
                    .deletingPathExtension()
                    .appendingPathExtension("xmp")
                try? fileManager.removeItem(at: backupSidecar)
                try fileManager.copyItem(at: sidecar, to: backupSidecar)
            }
            if isActive, let sessionRoot {
                let digest = SHA256.hash(data: try Data(contentsOf: primary))
                    .map { String(format: "%02x", $0) }
                    .joined()
                let manifest = sessionRoot.appendingPathComponent(
                    "checksums.sha256"
                )
                let line = "\(digest)  Primary/\(primary.lastPathComponent)\n"
                if fileManager.fileExists(atPath: manifest.path),
                   let handle = try? FileHandle(forWritingTo: manifest) {
                    try handle.seekToEnd()
                    try handle.write(contentsOf: Data(line.utf8))
                    try handle.close()
                } else {
                    try line.write(
                        to: manifest,
                        atomically: true,
                        encoding: .utf8
                    )
                }
            }
        }
    }

    private func replaceChecksumEntry(for primary: URL) {
        guard let sessionRoot else { return }
        let manifest = sessionRoot.appendingPathComponent("checksums.sha256")
        guard let data = try? Data(contentsOf: primary) else { return }
        let digest = SHA256.hash(data: data)
            .map { String(format: "%02x", $0) }
            .joined()
        let relative = "Primary/\(primary.lastPathComponent)"
        let lines = (try? String(contentsOf: manifest, encoding: .utf8))?
            .split(separator: "\n", omittingEmptySubsequences: true)
            .map(String.init)
            .filter { !$0.hasSuffix("  \(relative)") } ?? []
        try? (lines + ["\(digest)  \(relative)"])
            .joined(separator: "\n")
            .appending("\n")
            .write(to: manifest, atomically: true, encoding: .utf8)
    }

    private func xmpSidecar(
        for filename: String,
        location: CaptureLocation?,
        pairedWithFilename: String? = nil
    ) -> String {
        let title = xmlEscaped(configuration.name)
        let creator = xmlEscaped(configuration.creator)
        let rights = xmlEscaped(configuration.rights)
        let gps = location.map(gpsAttributes) ?? ""
        let pairing = pairedWithFilename.map {
            "\n              xmp:Label=\"live-photo\"\n              dc:relation=\"\(xmlEscaped($0))\""
        } ?? ""
        return """
        <?xpacket begin="" id="W5M0MpCehiHzreSzNTczkc9d"?>
        <x:xmpmeta xmlns:x="adobe:ns:meta/">
          <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
            <rdf:Description rdf:about=""
              xmlns:xmp="http://ns.adobe.com/xap/1.0/"
              xmlns:dc="http://purl.org/dc/elements/1.1/"
              xmlns:exif="http://ns.adobe.com/exif/1.0/"
              xmp:Rating="\(configuration.rating)"\(gps)\(pairing)>
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
