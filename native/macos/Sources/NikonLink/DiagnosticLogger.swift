import Foundation

enum DiagnosticLogLevel: String {
    case debug = "DEBUG"
    case info = "INFO"
    case warning = "WARN"
    case error = "ERROR"
}

enum DiagnosticLogError: LocalizedError {
    case unavailable
    case exportFailed(String)

    var errorDescription: String? {
        switch self {
        case .unavailable:
            return "日志目录暂时不可用，请重新启动 Nikon Link 后再试。"
        case .exportFailed(let reason):
            return reason.isEmpty
                ? "无法创建诊断日志包。"
                : "无法创建诊断日志包：\(reason)"
        }
    }
}

final class DiagnosticLogger {
    static let shared = DiagnosticLogger()
    private static let issueURL =
        "https://github.com/Tauber01/NikonLink/issues/new"

    let directoryURL: URL

    private let queue = DispatchQueue(
        label: "com.tauber.nikonlink.diagnostics",
        qos: .utility
    )
    private let sessionID = String(UUID().uuidString.prefix(8))
    private let maxFileBytes: UInt64 = 5 * 1024 * 1024
    private let retentionDays = 14
    private var fileHandle: FileHandle?
    private var currentLogURL: URL?

    init(directoryURL customDirectoryURL: URL? = nil) {
        if let customDirectoryURL {
            directoryURL = customDirectoryURL
        } else {
            let library = FileManager.default.urls(
                for: .libraryDirectory,
                in: .userDomainMask
            ).first ?? FileManager.default.homeDirectoryForCurrentUser
            directoryURL = library
                .appendingPathComponent("Logs", isDirectory: true)
                .appendingPathComponent("Nikon Link", isDirectory: true)
        }

        queue.sync {
            prepareLogFile()
            removeExpiredLogs()
        }
    }

    func startSession() {
        let version =
            Bundle.main.object(
                forInfoDictionaryKey: "CFBundleShortVersionString"
            ) as? String ?? "unknown"
        let build =
            Bundle.main.object(
                forInfoDictionaryKey: "CFBundleVersion"
            ) as? String ?? "unknown"
        let system = ProcessInfo.processInfo.operatingSystemVersionString
        let architecture = machineArchitecture()
        info(
            "app",
            "会话启动；版本=\(version) (\(build))；系统=\(system)；架构=\(architecture)"
        )
    }

    func endSession() {
        info("app", "会话结束")
        flush()
    }

    func debug(_ category: String, _ message: @autoclosure () -> String) {
        write(level: .debug, category: category, message: message())
    }

    func info(_ category: String, _ message: @autoclosure () -> String) {
        write(level: .info, category: category, message: message())
    }

    func warning(_ category: String, _ message: @autoclosure () -> String) {
        write(level: .warning, category: category, message: message())
    }

    func error(_ category: String, _ message: @autoclosure () -> String) {
        write(level: .error, category: category, message: message())
    }

    func flush() {
        queue.sync {
            try? fileHandle?.synchronize()
        }
    }

    func exportArchive(to destination: URL) throws {
        flush()

        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: directoryURL.path) else {
            throw DiagnosticLogError.unavailable
        }

        let stagingRoot = fileManager.temporaryDirectory
            .appendingPathComponent(
                "NikonLink-Diagnostics-\(UUID().uuidString)",
                isDirectory: true
            )
        let staging = stagingRoot.appendingPathComponent(
            "NikonLink-Diagnostics",
            isDirectory: true
        )
        defer { try? fileManager.removeItem(at: stagingRoot) }

        do {
            try fileManager.createDirectory(
                at: staging,
                withIntermediateDirectories: true
            )
            let logs = try fileManager.contentsOfDirectory(
                at: directoryURL,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )
            for log in logs where log.pathExtension.lowercased() == "log" {
                try fileManager.copyItem(
                    at: log,
                    to: staging.appendingPathComponent(log.lastPathComponent)
                )
            }
            try diagnosticSummary().write(
                to: staging.appendingPathComponent("系统信息.txt"),
                atomically: true,
                encoding: .utf8
            )
        } catch {
            throw DiagnosticLogError.exportFailed(error.localizedDescription)
        }

        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }

        let process = Process()
        let output = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        process.arguments = [
            "-c", "-k", "--keepParent", "--norsrc",
            staging.path, destination.path
        ]
        process.standardOutput = output
        process.standardError = output
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            throw DiagnosticLogError.exportFailed(error.localizedDescription)
        }
        guard process.terminationStatus == 0 else {
            let data = output.fileHandleForReading.readDataToEndOfFile()
            let reason = String(decoding: data, as: UTF8.self)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            throw DiagnosticLogError.exportFailed(reason)
        }
        info("diagnostics", "已导出诊断日志包")
    }

    func githubIssueURL() -> URL? {
        let body = """
        ## 问题描述

        请描述发生了什么，以及如何复现。

        ## 环境

        - 平台：\(ProcessInfo.processInfo.operatingSystemVersionString)
        - 架构：\(machineArchitecture())
        - Nikon Link：\(appVersion())
        - 会话：\(sessionID)

        ## 最近诊断日志（已脱敏）

        ```text
        \(recentText(maxCharacters: 2_500))
        ```

        > 提交前请检查以上内容；不要填写密码、令牌或相机序列号。
        """
        var components = URLComponents(string: Self.issueURL)
        components?.queryItems = [
            URLQueryItem(name: "title", value: "[macOS] "),
            URLQueryItem(name: "body", value: body)
        ]
        return components?.url
    }

    func recentText(maxCharacters: Int) -> String {
        flush()
        return queue.sync {
            let files = ((try? FileManager.default.contentsOfDirectory(
                at: directoryURL,
                includingPropertiesForKeys: [.contentModificationDateKey],
                options: [.skipsHiddenFiles]
            )) ?? [])
                .filter { $0.pathExtension.lowercased() == "log" }
                .sorted {
                    modificationDate($0) > modificationDate($1)
                }

            var result = ""
            for file in files where result.count < maxCharacters {
                let remaining = maxCharacters - result.count
                guard let handle = try? FileHandle(forReadingFrom: file) else {
                    continue
                }
                defer { try? handle.close() }
                let length = (try? handle.seekToEnd()) ?? 0
                let byteLimit = UInt64(min(remaining * 4, 32_000))
                let start = length > byteLimit ? length - byteLimit : 0
                try? handle.seek(toOffset: start)
                let data = (try? handle.readToEnd()) ?? Data()
                var text = String(decoding: data, as: UTF8.self)
                if start > 0, let newline = text.firstIndex(of: "\n") {
                    text = String(text[text.index(after: newline)...])
                }
                if text.count > remaining {
                    text = String(text.suffix(remaining))
                }
                result = text + (result.isEmpty ? "" : "\n" + result)
            }
            return result.isEmpty ? "暂无日志。" : redact(result)
        }
    }

    private func write(
        level: DiagnosticLogLevel,
        category: String,
        message: String
    ) {
        queue.async { [weak self] in
            guard let self else { return }
            if self.fileHandle == nil {
                self.prepareLogFile()
            }
            self.rotateIfNeeded()

            let timestamp = self.timestamp()
            let cleanCategory = self.singleLine(self.redact(category))
            let cleanMessage = self.redact(message)
            let cappedMessage = String(cleanMessage.prefix(32_768))
                .replacingOccurrences(of: "\n", with: "\n    ")
            let entry = """
            \(timestamp) [\(level.rawValue)] [\(self.sessionID)] [\(cleanCategory)] \(cappedMessage)

            """
            guard let data = entry.data(using: .utf8) else { return }
            self.fileHandle?.write(data)
        }
    }

    private func prepareLogFile() {
        let fileManager = FileManager.default
        do {
            try fileManager.createDirectory(
                at: directoryURL,
                withIntermediateDirectories: true
            )
            let url = dailyLogURL()
            if !fileManager.fileExists(atPath: url.path) {
                fileManager.createFile(atPath: url.path, contents: nil)
            }
            let handle = try FileHandle(forWritingTo: url)
            handle.seekToEndOfFile()
            currentLogURL = url
            fileHandle = handle
        } catch {
            currentLogURL = nil
            fileHandle = nil
        }
    }

    private func rotateIfNeeded() {
        if currentLogURL != dailyLogURL() {
            try? fileHandle?.close()
            fileHandle = nil
            currentLogURL = nil
            prepareLogFile()
        }
        guard let currentLogURL,
              let attributes = try? FileManager.default.attributesOfItem(
                atPath: currentLogURL.path
              ),
              let size = attributes[.size] as? NSNumber,
              size.uint64Value >= maxFileBytes
        else {
            return
        }

        try? fileHandle?.close()
        fileHandle = nil
        let fileManager = FileManager.default
        let base = currentLogURL.deletingPathExtension()
        let rotated = base
            .appendingPathExtension(
                "\(timestampForFilename())-\(String(UUID().uuidString.prefix(6)))"
            )
            .appendingPathExtension("log")
        try? fileManager.moveItem(at: currentLogURL, to: rotated)
        prepareLogFile()
    }

    private func removeExpiredLogs() {
        let fileManager = FileManager.default
        let cutoff = Date().addingTimeInterval(
            -TimeInterval(retentionDays * 24 * 60 * 60)
        )
        guard let files = try? fileManager.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            return
        }
        for file in files where file.pathExtension.lowercased() == "log" {
            let modified = try? file.resourceValues(
                forKeys: [.contentModificationDateKey]
            ).contentModificationDate
            if let modified, modified < cutoff, file != currentLogURL {
                try? fileManager.removeItem(at: file)
            }
        }
    }

    private func redact(_ value: String) -> String {
        var result = value.replacingOccurrences(
            of: FileManager.default.homeDirectoryForCurrentUser.path,
            with: "<HOME>"
        )
        let patterns = [
            #"(?im)^(\s*(?:serial(?: number)?|serialnumber|owner name|artist|copyright|password|username)\s*[:=]\s*).*$"#,
            #"(?i)([?&](?:token|key|password|secret)=)[^&\s]+"#
        ]
        for pattern in patterns {
            guard let expression = try? NSRegularExpression(pattern: pattern) else {
                continue
            }
            let range = NSRange(result.startIndex..., in: result)
            result = expression.stringByReplacingMatches(
                in: result,
                range: range,
                withTemplate: "$1<REDACTED>"
            )
        }
        return result
    }

    private func singleLine(_ value: String) -> String {
        value.replacingOccurrences(
            of: #"\s+"#,
            with: " ",
            options: .regularExpression
        )
    }

    private func timestamp() -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: Date())
    }

    private func timestampForFilename() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HHmmss"
        return formatter.string(from: Date())
    }

    private func dailyLogURL() -> URL {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return directoryURL.appendingPathComponent(
            "NikonLink-\(formatter.string(from: Date())).log"
        )
    }

    private func machineArchitecture() -> String {
        var info = utsname()
        uname(&info)
        return withUnsafePointer(to: &info.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(cString: $0)
            }
        }
    }

    private func modificationDate(_ url: URL) -> Date {
        (try? url.resourceValues(
            forKeys: [.contentModificationDateKey]
        ).contentModificationDate) ?? .distantPast
    }

    private func appVersion() -> String {
        let version =
            Bundle.main.object(
                forInfoDictionaryKey: "CFBundleShortVersionString"
            ) as? String ?? "unknown"
        let build =
            Bundle.main.object(
                forInfoDictionaryKey: "CFBundleVersion"
            ) as? String ?? "unknown"
        return "\(version) (\(build))"
    }

    private func diagnosticSummary() -> String {
        let version =
            Bundle.main.object(
                forInfoDictionaryKey: "CFBundleShortVersionString"
            ) as? String ?? "unknown"
        let build =
            Bundle.main.object(
                forInfoDictionaryKey: "CFBundleVersion"
            ) as? String ?? "unknown"
        return """
        Nikon Link 诊断信息
        导出时间：\(timestamp())
        应用版本：\(version) (\(build))
        macOS：\(ProcessInfo.processInfo.operatingSystemVersionString)
        架构：\(machineArchitecture())
        会话编号：\(sessionID)

        日志默认保留 14 天。相机序列号、用户名路径和常见密钥字段已自动隐藏。
        """
    }
}
