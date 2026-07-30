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
        reservedBaseName: String? = nil
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
        try finalize(destination)
        status = "已写入会话 · \(destination.lastPathComponent)"
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

    private func finalize(_ primary: URL) throws {
        let digest = SHA256.hash(data: try Data(contentsOf: primary))
            .map { String(format: "%02x", $0) }
            .joined()
        if isActive {
            let xmp = xmpSidecar(for: primary.lastPathComponent)
            let sidecar = primary
                .deletingPathExtension()
                .appendingPathExtension("xmp")
            try xmp.write(to: sidecar, atomically: true, encoding: .utf8)
            if let backupDirectory {
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
            if let sessionRoot {
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

    private func xmpSidecar(for filename: String) -> String {
        let title = xmlEscaped(configuration.name)
        let creator = xmlEscaped(configuration.creator)
        let rights = xmlEscaped(configuration.rights)
        return """
        <?xpacket begin="" id="W5M0MpCehiHzreSzNTczkc9d"?>
        <x:xmpmeta xmlns:x="adobe:ns:meta/">
          <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
            <rdf:Description rdf:about=""
              xmlns:xmp="http://ns.adobe.com/xap/1.0/"
              xmlns:dc="http://purl.org/dc/elements/1.1/"
              xmp:Rating="\(configuration.rating)">
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
