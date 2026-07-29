import Foundation
import UIKit

private struct GitHubRelease: Decodable {
    let tagName: String
    let htmlURL: URL

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case htmlURL = "html_url"
    }
}

@MainActor
final class UpdateController: ObservableObject {
    private static let latestReleaseAPI = URL(
        string: "https://api.github.com/repos/Tauber01/ZENCHE/releases/latest"
    )!
    private static let repositoryURL = URL(
        string: "https://github.com/Tauber01/ZENCHE"
    )!
    private static let automaticUpdateKey = "NikonLink.automaticallyChecksForUpdates"

    @Published var automaticallyChecksForUpdates: Bool {
        didSet {
            UserDefaults.standard.set(
                automaticallyChecksForUpdates,
                forKey: Self.automaticUpdateKey
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
        ) as? String ?? "0.8.3"
    }

    init() {
        if UserDefaults.standard.object(forKey: Self.automaticUpdateKey) == nil {
            automaticallyChecksForUpdates = true
        } else {
            automaticallyChecksForUpdates = UserDefaults.standard.bool(
                forKey: Self.automaticUpdateKey
            )
        }
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

                let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
                let version = Self.normalizedVersion(release.tagName)
                guard Self.isNewer(version, than: currentVersion) else {
                    availableVersion = nil
                    releaseURL = nil
                    statusText = "已是最新版本"
                    return
                }

                availableVersion = version
                releaseURL = release.htmlURL
                statusText = "发现新版本 \(version)"
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

    func openAvailableUpdate() {
        UIApplication.shared.open(releaseURL ?? Self.repositoryURL)
    }

    func openProjectPage() {
        UIApplication.shared.open(Self.repositoryURL)
    }

    private static func normalizedVersion(_ value: String) -> String {
        value.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
    }

    private static func isNewer(_ candidate: String, than current: String) -> Bool {
        candidate.compare(current, options: .numeric) == .orderedDescending
    }
}
