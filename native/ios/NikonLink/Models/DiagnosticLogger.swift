import Foundation
import UIKit

final class DiagnosticLogger {
    static let shared = DiagnosticLogger()

    let directoryURL: URL

    private let queue = DispatchQueue(
        label: "com.tauber.nikonlink.ios.diagnostics",
        qos: .utility
    )
    private let sessionID = String(UUID().uuidString.prefix(8))
    private let maxFileBytes: UInt64 = 5 * 1024 * 1024
    private let retentionDays = 14
    private let issueLogLimit = 2_500

    private init() {
        let library = FileManager.default.urls(
            for: .libraryDirectory,
            in: .userDomainMask
        )[0]
        directoryURL = library
            .appendingPathComponent("Logs", isDirectory: true)
            .appendingPathComponent("ZENCHE", isDirectory: true)
        queue.sync {
            try? FileManager.default.createDirectory(
                at: directoryURL,
                withIntermediateDirectories: true
            )
            removeExpiredLogs()
        }
    }

    func startSession() {
        let device = UIDevice.current
        info(
            "app",
            "会话启动；版本=\(appVersion())；系统=\(device.systemName) "
                + "\(device.systemVersion)；设备=\(device.model)"
        )
    }

    func info(_ category: String, _ message: @autoclosure () -> String) {
        write(level: "INFO", category: category, message: message())
    }

    func warning(_ category: String, _ message: @autoclosure () -> String) {
        write(level: "WARN", category: category, message: message())
    }

    func error(_ category: String, _ message: @autoclosure () -> String) {
        write(level: "ERROR", category: category, message: message())
    }

    func githubIssueURL() -> URL? {
        let device = UIDevice.current
        let body = """
        ## 问题描述

        请描述发生了什么，以及如何复现。

        ## 环境

        - 平台：\(device.systemName) \(device.systemVersion)
        - 设备：\(redact(device.model))
        - 帧澈 ZENCHE：\(appVersion())
        - 会话：\(sessionID)

        ## 最近诊断日志（已脱敏）

        ```text
        \(recentText(maxCharacters: issueLogLimit))
        ```

        > 提交前请检查以上内容；不要填写密码、令牌或相机序列号。
        """
        var components = URLComponents(
            string: "https://github.com/Tauber01/ZENCHE/issues/new"
        )
        components?.queryItems = [
            URLQueryItem(name: "title", value: "[iOS/iPadOS] "),
            URLQueryItem(name: "body", value: body)
        ]
        return components?.url
    }

    func recentText(maxCharacters: Int) -> String {
        queue.sync {
            let files = logFiles().sorted {
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

    private func write(level: String, category: String, message: String) {
        queue.async { [weak self] in
            guard let self else { return }
            do {
                try FileManager.default.createDirectory(
                    at: self.directoryURL,
                    withIntermediateDirectories: true
                )
                var target = self.dailyLogURL()
                if self.fileSize(target) >= self.maxFileBytes {
                    let rotated = self.directoryURL.appendingPathComponent(
                        "ZENCHE-\(self.filenameTimestamp())-"
                            + "\(self.sessionID).log"
                    )
                    try? FileManager.default.moveItem(at: target, to: rotated)
                    target = self.dailyLogURL()
                }
                let cleanCategory = self.singleLine(self.redact(category))
                let cleanMessage = String(self.redact(message).prefix(32_768))
                    .replacingOccurrences(of: "\n", with: "\n    ")
                let entry = "\(self.timestamp()) [\(level)] "
                    + "[\(self.sessionID)] [\(cleanCategory)] "
                    + "\(cleanMessage)\n"
                let data = Data(entry.utf8)
                if !FileManager.default.fileExists(atPath: target.path) {
                    try data.write(to: target, options: .atomic)
                } else {
                    let handle = try FileHandle(forWritingTo: target)
                    defer { try? handle.close() }
                    try handle.seekToEnd()
                    try handle.write(contentsOf: data)
                    try handle.synchronize()
                }
            } catch {
                NSLog("ZENCHE diagnostics write failed: %@", error.localizedDescription)
            }
        }
    }

    private func dailyLogURL() -> URL {
        directoryURL.appendingPathComponent(
            "ZENCHE-\(dateFormatter("yyyy-MM-dd").string(from: Date())).log"
        )
    }

    private func logFiles() -> [URL] {
        ((try? FileManager.default.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )) ?? []).filter { $0.pathExtension.lowercased() == "log" }
    }

    private func removeExpiredLogs() {
        let cutoff = Date().addingTimeInterval(
            -TimeInterval(retentionDays * 24 * 60 * 60)
        )
        for file in logFiles() where modificationDate(file) < cutoff {
            try? FileManager.default.removeItem(at: file)
        }
    }

    private func modificationDate(_ url: URL) -> Date {
        (try? url.resourceValues(
            forKeys: [.contentModificationDateKey]
        ).contentModificationDate) ?? .distantPast
    }

    private func fileSize(_ url: URL) -> UInt64 {
        let attributes = try? FileManager.default.attributesOfItem(
            atPath: url.path
        )
        return (attributes?[.size] as? NSNumber)?.uint64Value ?? 0
    }

    private func redact(_ value: String) -> String {
        var result = value.replacingOccurrences(
            of: NSHomeDirectory(),
            with: "<APP_HOME>"
        )
        let patterns = [
            #"(?i)((?:token|key|password|secret|serial(?: number)?|serialnumber|username)\s*[:=]\s*)\S+"#
        ]
        for pattern in patterns {
            guard let expression = try? NSRegularExpression(pattern: pattern) else {
                continue
            }
            result = expression.stringByReplacingMatches(
                in: result,
                range: NSRange(result.startIndex..., in: result),
                withTemplate: "$1<REDACTED>"
            )
        }
        return result
    }

    private func appVersion() -> String {
        let version = Bundle.main.object(
            forInfoDictionaryKey: "CFBundleShortVersionString"
        ) as? String ?? "unknown"
        let build = Bundle.main.object(
            forInfoDictionaryKey: "CFBundleVersion"
        ) as? String ?? "unknown"
        return "\(version) (\(build))"
    }

    private func timestamp() -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: Date())
    }

    private func filenameTimestamp() -> String {
        dateFormatter("yyyy-MM-dd-HHmmss").string(from: Date())
    }

    private func dateFormatter(_ format: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = format
        return formatter
    }

    private func singleLine(_ value: String) -> String {
        value.replacingOccurrences(
            of: #"\s+"#,
            with: " ",
            options: .regularExpression
        )
    }
}
