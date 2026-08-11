import Foundation
import Security
import UIKit

private struct MirrorChyanResponse: Decodable {
    let code: Int
    let msg: String
    let data: MirrorChyanVersion?
}

private struct MirrorChyanVersion: Decodable {
    let versionName: String
    let downloadURL: URL?
    let updateType: String?

    enum CodingKeys: String, CodingKey {
        case versionName = "version_name"
        case downloadURL = "url"
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
    let tagName: String
    let htmlURL: URL

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case htmlURL = "html_url"
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

@MainActor
final class UpdateController: ObservableObject {
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
    private static let repositoryURL = URL(
        string: "https://github.com/Tauber01/ZENCHE"
    )!
    private static let automaticUpdateKey = "NikonLink.automaticallyChecksForUpdates"
    private static let installIdKey = "NikonLink.anonymousInstallId"
    private static let keychainService = "com.tauber.nikonlink.mirrorchyan"
    private static let keychainAccount = "cdk"

    /// E1: 匿名安装 ID——首次生成 UUID 存 UserDefaults，与激活码/设备码无关，
    /// 仅用于服务器匿名用量统计（服务端只存 sha256 前 12 位指纹）。
    private static func anonymousInstallId() -> String {
        if let existing = UserDefaults.standard.string(forKey: Self.installIdKey),
           !existing.isEmpty {
            return existing
        }
        let id = UUID().uuidString
        UserDefaults.standard.set(id, forKey: Self.installIdKey)
        return id
    }

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
    @Published private(set) var statusText = "尚未检查更新"
    @Published private(set) var availableVersion: String?
    private var releaseURL: URL?

    var currentVersion: String {
        Bundle.main.object(
            forInfoDictionaryKey: "CFBundleShortVersionString"
        ) as? String ?? "1.5.13"
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
                    applyMirrorChyanVersion(version)
                } catch {
                    let fallbackStatus = (error as? MirrorChyanServiceError)?
                        .fallbackStatus ?? "Mirror酱暂不可用，已回退 GitHub"
                    DiagnosticLogger.shared.warning(
                        "update",
                        "Mirror酱检查失败，准备回退 GitHub：\(error.localizedDescription)"
                    )
                    do {
                        let release = try await fetchGitHubRelease()
                        applyGitHubRelease(release, fallbackStatus: fallbackStatus)
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

    func openAvailableUpdate() {
        UIApplication.shared.open(releaseURL ?? Self.releasesURL)
    }

    func openProjectPage() {
        UIApplication.shared.open(Self.repositoryURL)
    }

    func openMirrorChyan() {
        UIApplication.shared.open(Self.mirrorChyanWebsiteURL)
    }

    private func fetchSelfHostedUpdate() async throws -> SelfHostedUpdate {
        let endpoint = ProcessInfo.processInfo.environment[
            "ZENCHE_UPDATE_ENDPOINT"
        ]?.trimmingCharacters(in: .whitespacesAndNewlines)
        let baseURL = URL(string: endpoint ?? "") ?? Self.defaultSelfHostedUpdateEndpoint
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)!
        components.queryItems = (components.queryItems ?? []) + [
            URLQueryItem(name: "platform", value: "ios"),
            URLQueryItem(name: "arch", value: "arm64"),
            URLQueryItem(name: "current_version", value: currentVersion),
            URLQueryItem(name: "channel", value: "stable"),
            URLQueryItem(name: "installId", value: Self.anonymousInstallId())
        ]
        var request = URLRequest(url: components.url!)
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("ZENCHE-iOS/\(currentVersion)", forHTTPHeaderField: "User-Agent")
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
            availableVersion = nil
            releaseURL = nil
            statusText = "已是最新版本"
            return
        }
        availableVersion = version
        releaseURL = update.updateType?.lowercased() == "incremental"
            ? Self.releasesURL
            : update.url ?? update.releaseURL ?? Self.releasesURL
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
            URLQueryItem(name: "user_agent", value: "ZENCHE_iOS"),
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
            "ZENCHE-iOS/\(currentVersion)",
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
            "ZENCHE-iOS/\(currentVersion)",
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
            availableVersion = nil
            releaseURL = nil
            statusText = "已是最新版本"
            return
        }

        availableVersion = version
        releaseURL = update.updateType?.lowercased() == "incremental"
            ? Self.releasesURL
            : update.downloadURL ?? Self.releasesURL
        statusText = "发现新版本 \(version)"
    }

    private func applyGitHubRelease(
        _ release: GitHubRelease,
        fallbackStatus: String
    ) {
        let version = Self.normalizedVersion(release.tagName)
        guard Self.isNewer(version, than: currentVersion) else {
            availableVersion = nil
            releaseURL = nil
            statusText = "已是最新版本 · \(fallbackStatus)"
            return
        }

        availableVersion = version
        releaseURL = release.htmlURL
        statusText = "发现新版本 \(version) · \(fallbackStatus)"
    }

    private static var mirrorChyanWebsiteURL: URL {
        var components = URLComponents(
            string: "https://mirrorchyan.com/zh/projects"
        )!
        components.queryItems = [
            URLQueryItem(name: "rid", value: mirrorChyanResourceID),
            URLQueryItem(name: "source", value: "zenche_ios_settings")
        ]
        return components.url!
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
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
