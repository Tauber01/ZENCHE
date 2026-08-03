import AppKit
import CryptoKit
import Foundation
import Security

private struct MirrorChyanResponse: Decodable {
    let code: Int
    let msg: String
    let data: MirrorChyanVersion?
}

private struct MirrorChyanVersion: Decodable {
    let versionName: String
    let downloadURL: URL?
    let sha256: String?
    let updateType: String?

    enum CodingKeys: String, CodingKey {
        case versionName = "version_name"
        case downloadURL = "url"
        case sha256
        case updateType = "update_type"
    }
}

private struct MirrorChyanServiceError: LocalizedError {
    let code: Int
    let message: String

    var errorDescription: String? {
        "MirrorChyan \(code): \(message)"
    }

    var fallbackStatus: String {
        switch code {
        case 7001:
            return "Mirror酱 CDK 已过期，已回退 GitHub"
        case 7002:
            return "Mirror酱 CDK 无效，已回退 GitHub"
        case 7003:
            return "Mirror酱今日下载额度已用完，已回退 GitHub"
        case 7004:
            return "Mirror酱 CDK 与资源不匹配，已回退 GitHub"
        case 7005:
            return "Mirror酱 CDK 已被停用，已回退 GitHub"
        case 8001:
            return "Mirror酱资源尚未配置，已回退 GitHub"
        default:
            return "Mirror酱暂不可用，已回退 GitHub"
        }
    }
}

private struct GitHubRelease: Decodable {
    struct Asset: Decodable {
        let name: String
        let browserDownloadURL: URL

        enum CodingKeys: String, CodingKey {
            case name
            case browserDownloadURL = "browser_download_url"
        }
    }

    let tagName: String
    let htmlURL: URL
    let assets: [Asset]

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case htmlURL = "html_url"
        case assets
    }
}

private struct SelfHostedAnnouncement: Decodable {
    let title: String?
    let body: String?

    var text: String? {
        let values: [String] = [title, body].compactMap { value -> String? in
            guard let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return nil
            }
            return value
        }
        return values.isEmpty ? nil : values.joined(separator: "：")
    }
}

private struct SelfHostedUpdate: Decodable {
    let schemaVersion: Int
    let product: String
    let version: String
    let url: URL?
    let sha256: String?
    let releaseURL: URL?
    let updateType: String?
    let announcement: SelfHostedAnnouncement?

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case product
        case version
        case url
        case sha256
        case releaseURL = "release_url"
        case updateType = "update_type"
        case announcement
    }
}

struct AvailableUpdate {
    let version: String
    let releasePage: URL
    let downloadURL: URL?
    let sha256: String?
}

@MainActor
final class UpdateController: ObservableObject {
    static let repositoryURL = URL(string: "https://github.com/Tauber01/ZENCHE")!
    private static let defaultMirrorChyanResourceID = "ZENCHE"
    private static let mirrorChyanResourceID =
        ProcessInfo.processInfo.environment[
            "ZENCHE_MIRRORCHYAN_RESOURCE_ID"
        ]?.trimmingCharacters(in: .whitespacesAndNewlines)
            .nilIfEmpty ?? defaultMirrorChyanResourceID
    private static let latestReleaseAPI = URL(
        string: "https://api.github.com/repos/Tauber01/ZENCHE/releases/latest"
    )!
    private static let defaultSelfHostedUpdateEndpoint = URL(
        string: "https://zenche.top/api/update"
    )!
    private static let releasesURL = URL(
        string: "https://github.com/Tauber01/ZENCHE/releases"
    )!
    private static let automaticUpdateKey = "NikonLink.automaticallyChecksForUpdates"
    private static let keychainService = "com.tauber.nikonlink.mirrorchyan"
    private static let keychainAccount = "cdk"

    @Published var automaticallyChecksForUpdates: Bool {
        didSet {
            UserDefaults.standard.set(
                automaticallyChecksForUpdates,
                forKey: Self.automaticUpdateKey
            )
        }
    }
    @Published var mirrorChyanCDK: String {
        didSet {
            Self.saveMirrorChyanCDK(
                mirrorChyanCDK.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        }
    }
    @Published private(set) var isChecking = false
    @Published private(set) var isDownloading = false
    @Published private(set) var statusText = "尚未检查更新"
    @Published private(set) var availableUpdate: AvailableUpdate?
    @Published private(set) var downloadedInstaller: URL?

    var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
            ?? "1.5.1"
    }

    init() {
        if UserDefaults.standard.object(forKey: Self.automaticUpdateKey) == nil {
            automaticallyChecksForUpdates = true
        } else {
            automaticallyChecksForUpdates = UserDefaults.standard.bool(
                forKey: Self.automaticUpdateKey
            )
        }
        mirrorChyanCDK = Self.loadMirrorChyanCDK()
    }

    func checkAutomaticallyIfNeeded() {
        guard automaticallyChecksForUpdates else { return }
        checkForUpdates(silent: true)
    }

    func checkForUpdates(silent: Bool = false) {
        guard !isChecking else { return }
        isChecking = true
        if !silent {
            statusText = "正在检查更新…"
        }

        Task {
            defer { isChecking = false }
            do {
                let update = try await fetchSelfHostedUpdate()
                applySelfHostedUpdate(update)
            } catch {
                do {
                    let version = try await fetchMirrorChyanVersion()
                    if version.updateType?.lowercased() == "incremental" {
                        let release = try await fetchGitHubRelease()
                        applyGitHubRelease(release)
                    } else {
                        applyMirrorChyanVersion(version)
                    }
                } catch {
                    let fallbackStatus = (error as? MirrorChyanServiceError)?
                        .fallbackStatus ?? "Mirror酱暂不可用，已回退 GitHub"
                    DiagnosticLogger.shared.warning(
                        "update",
                        "Mirror酱检查失败，准备回退 GitHub：\(error.localizedDescription)"
                    )
                    do {
                        let release = try await fetchGitHubRelease()
                        applyGitHubRelease(
                            release,
                            fallbackStatus: fallbackStatus
                        )
                    } catch {
                        if !silent {
                            statusText = "检查失败，请确认网络后重试"
                        }
                        DiagnosticLogger.shared.error(
                            "update",
                            "检查更新失败：\(error.localizedDescription)"
                        )
                    }
                }
            }
        }
    }

    func downloadUpdate() {
        guard let update = availableUpdate, !isDownloading else { return }
        guard let downloadURL = update.downloadURL else {
            NSWorkspace.shared.open(update.releasePage)
            return
        }

        isDownloading = true
        statusText = "正在下载 \(update.version)…"
        Task {
            defer { isDownloading = false }
            do {
                let (temporaryURL, response) = try await URLSession.shared.download(
                    from: downloadURL
                )
                guard let response = response as? HTTPURLResponse,
                      (200..<300).contains(response.statusCode) else {
                    throw URLError(.badServerResponse)
                }
                if let expected = update.sha256?.lowercased(),
                   !expected.isEmpty {
                    let data = try Data(
                        contentsOf: temporaryURL,
                        options: .mappedIfSafe
                    )
                    let actual = SHA256.hash(data: data)
                        .map { String(format: "%02x", $0) }
                        .joined()
                    guard actual == expected else {
                        throw UpdateIntegrityError()
                    }
                }

                let downloads = FileManager.default.urls(
                    for: .downloadsDirectory,
                    in: .userDomainMask
                ).first!
                let suggestedFilename = response.suggestedFilename
                    ?? Self.defaultInstallerFilename(version: update.version)
                let filename = suggestedFilename.lowercased().hasSuffix(".dmg")
                    ? suggestedFilename
                    : Self.defaultInstallerFilename(version: update.version)
                let destination = Self.availableDestination(
                    in: downloads,
                    filename: filename
                )
                try FileManager.default.moveItem(
                    at: temporaryURL,
                    to: destination
                )
                downloadedInstaller = destination
                statusText = "更新已下载，打开安装包即可完成更新"
                NSWorkspace.shared.open(destination)
            } catch is UpdateIntegrityError {
                statusText = "更新包校验失败，已停止安装"
            } catch {
                statusText = "下载失败，请稍后重试"
            }
        }
    }

    func openDownloadedInstaller() {
        guard let downloadedInstaller else { return }
        NSWorkspace.shared.open(downloadedInstaller)
    }

    func openReleasePage() {
        NSWorkspace.shared.open(
            availableUpdate?.releasePage ?? Self.repositoryURL
        )
    }

    func openMirrorChyan() {
        NSWorkspace.shared.open(Self.mirrorChyanWebsiteURL)
    }

    private func fetchSelfHostedUpdate() async throws -> SelfHostedUpdate {
        let endpoint = ProcessInfo.processInfo.environment[
            "ZENCHE_UPDATE_ENDPOINT"
        ]?.trimmingCharacters(in: .whitespacesAndNewlines)
        let baseURL = URL(string: endpoint ?? "") ?? Self.defaultSelfHostedUpdateEndpoint
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)!
        components.queryItems = (components.queryItems ?? []) + [
            URLQueryItem(name: "platform", value: "macos"),
            URLQueryItem(name: "arch", value: Self.mirrorChyanArchitecture),
            URLQueryItem(name: "current_version", value: currentVersion),
            URLQueryItem(name: "channel", value: "stable")
        ]
        var request = URLRequest(url: components.url!)
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("ZENCHE-macOS/\(currentVersion)", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let response = response as? HTTPURLResponse,
              (200..<300).contains(response.statusCode) else {
            throw URLError(.badServerResponse)
        }
        let update = try JSONDecoder().decode(SelfHostedUpdate.self, from: data)
        guard update.schemaVersion == 1,
              update.product.caseInsensitiveCompare("ZENCHE") == .orderedSame else {
            throw URLError(.cannotParseResponse)
        }
        return update
    }

    private func applySelfHostedUpdate(_ update: SelfHostedUpdate) {
        let version = Self.normalizedVersion(update.version)
        guard Self.isNewer(version, than: currentVersion) else {
            availableUpdate = nil
            downloadedInstaller = nil
            statusText = "已是最新版本"
            return
        }
        availableUpdate = AvailableUpdate(
            version: version,
            releasePage: update.releaseURL ?? Self.releasesURL,
            downloadURL: update.updateType?.lowercased() == "incremental"
                ? nil
                : update.url,
            sha256: update.sha256
        )
        downloadedInstaller = nil
        let announcement = update.announcement?.text
        statusText = ["发现新版本 \(version)", announcement]
            .compactMap { $0 }
            .joined(separator: " · ")
    }

    private func fetchMirrorChyanVersion() async throws -> MirrorChyanVersion {
        var components = URLComponents(
            string: "https://mirrorchyan.com/api/resources/"
                + "\(Self.mirrorChyanResourceID)/latest"
        )!
        var queryItems = [
            URLQueryItem(
                name: "current_version",
                value: "v\(currentVersion)"
            ),
            URLQueryItem(name: "user_agent", value: "ZENCHE_macOS"),
            URLQueryItem(name: "os", value: "macos"),
            URLQueryItem(name: "arch", value: Self.mirrorChyanArchitecture),
            URLQueryItem(name: "channel", value: "stable")
        ]
        let cdk = mirrorChyanCDK.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        if !cdk.isEmpty {
            queryItems.append(URLQueryItem(name: "cdk", value: cdk))
        }
        components.queryItems = queryItems

        var request = URLRequest(url: components.url!)
        request.timeoutInterval = 20
        request.setValue(
            "ZENCHE-macOS/\(currentVersion)",
            forHTTPHeaderField: "User-Agent"
        )
        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(
            MirrorChyanResponse.self,
            from: data
        )
        guard response.code == 0, let version = response.data else {
            throw MirrorChyanServiceError(
                code: response.code,
                message: response.msg
            )
        }
        return version
    }

    private func fetchGitHubRelease() async throws -> GitHubRelease {
        var request = URLRequest(url: Self.latestReleaseAPI)
        request.timeoutInterval = 20
        request.setValue(
            "application/vnd.github+json",
            forHTTPHeaderField: "Accept"
        )
        request.setValue(
            "ZENCHE-macOS/\(currentVersion)",
            forHTTPHeaderField: "User-Agent"
        )
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let response = response as? HTTPURLResponse,
              (200..<300).contains(response.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(GitHubRelease.self, from: data)
    }

    private func applyMirrorChyanVersion(_ update: MirrorChyanVersion) {
        let version = Self.normalizedVersion(update.versionName)
        guard Self.isNewer(version, than: currentVersion) else {
            availableUpdate = nil
            downloadedInstaller = nil
            statusText = "已是最新版本"
            return
        }

        availableUpdate = AvailableUpdate(
            version: version,
            releasePage: Self.releasesURL,
            downloadURL: update.downloadURL,
            sha256: update.sha256
        )
        downloadedInstaller = nil
        statusText = "发现新版本 \(version)"
    }

    private func applyGitHubRelease(
        _ release: GitHubRelease,
        fallbackStatus: String? = nil
    ) {
        let version = Self.normalizedVersion(release.tagName)
        guard Self.isNewer(version, than: currentVersion) else {
            availableUpdate = nil
            downloadedInstaller = nil
            statusText = ["已是最新版本", fallbackStatus]
                .compactMap { $0 }
                .joined(separator: " · ")
            return
        }

        let downloadURL = release.assets.first {
            $0.name.hasSuffix(Self.installerSuffix)
        }?.browserDownloadURL
        availableUpdate = AvailableUpdate(
            version: version,
            releasePage: release.htmlURL,
            downloadURL: downloadURL,
            sha256: nil
        )
        downloadedInstaller = nil
        statusText = ["发现新版本 \(version)", fallbackStatus]
            .compactMap { $0 }
            .joined(separator: " · ")
    }

    private static var installerSuffix: String {
        #if arch(arm64)
        return "-macOS-arm64.dmg"
        #elseif arch(x86_64)
        return "-macOS-x86_64.dmg"
        #else
        return ".dmg"
        #endif
    }

    private static var mirrorChyanArchitecture: String {
        #if arch(arm64)
        return "arm64"
        #else
        return "x64"
        #endif
    }

    private static var mirrorChyanWebsiteURL: URL {
        var components = URLComponents(
            string: "https://mirrorchyan.com/zh/projects"
        )!
        components.queryItems = [
            URLQueryItem(name: "rid", value: mirrorChyanResourceID),
            URLQueryItem(name: "source", value: "zenche_macos_settings")
        ]
        return components.url!
    }

    private static func defaultInstallerFilename(version: String) -> String {
        "ZENCHE-\(version)\(installerSuffix)"
    }

    private static func loadMirrorChyanCDK() -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(
            query as CFDictionary,
            &item
        ) == errSecSuccess,
        let data = item as? Data,
        let value = String(data: data, encoding: .utf8) else {
            return ""
        }
        return value
    }

    private static func saveMirrorChyanCDK(_ value: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount
        ]
        if value.isEmpty {
            SecItemDelete(query as CFDictionary)
            return
        }

        let data = Data(value.utf8)
        let attributes: [String: Any] = [
            kSecValueData as String: data
        ]
        if SecItemUpdate(
            query as CFDictionary,
            attributes as CFDictionary
        ) == errSecItemNotFound {
            var newItem = query
            newItem[kSecValueData as String] = data
            newItem[kSecAttrAccessible as String] =
                kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            SecItemAdd(newItem as CFDictionary, nil)
        }
    }

    private static func normalizedVersion(_ value: String) -> String {
        value.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
    }

    private static func isNewer(_ candidate: String, than current: String) -> Bool {
        candidate.compare(current, options: .numeric) == .orderedDescending
    }

    private static func availableDestination(in directory: URL, filename: String) -> URL {
        let fileManager = FileManager.default
        let candidate = directory.appendingPathComponent(filename)
        guard !fileManager.fileExists(atPath: candidate.path) else {
            let base = (filename as NSString).deletingPathExtension
            let ext = (filename as NSString).pathExtension
            var index = 2
            while true {
                let numberedName = ext.isEmpty
                    ? "\(base) \(index)"
                    : "\(base) \(index).\(ext)"
                let numberedURL = directory.appendingPathComponent(
                    numberedName
                )
                if !fileManager.fileExists(atPath: numberedURL.path) {
                    return numberedURL
                }
                index += 1
            }
        }
        return candidate
    }
}

private struct UpdateIntegrityError: Error {}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
