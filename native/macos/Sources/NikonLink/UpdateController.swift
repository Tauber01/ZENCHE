import AppKit
import Foundation

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

struct AvailableUpdate {
    let version: String
    let releasePage: URL
    let downloadURL: URL?
}

@MainActor
final class UpdateController: ObservableObject {
    static let repositoryURL = URL(string: "https://github.com/Tauber01/NikonLink")!
    private static let latestReleaseAPI = URL(
        string: "https://api.github.com/repos/Tauber01/NikonLink/releases/latest"
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
    @Published private(set) var isDownloading = false
    @Published private(set) var statusText = "尚未检查更新"
    @Published private(set) var availableUpdate: AvailableUpdate?
    @Published private(set) var downloadedInstaller: URL?

    var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
            ?? "0.8.0"
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
                    "NikonLink/\(currentVersion)",
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
                    availableUpdate = nil
                    statusText = "已是最新版本"
                    return
                }

                let downloadURL = release.assets.first {
                    $0.name.hasSuffix(Self.installerSuffix)
                }?.browserDownloadURL
                availableUpdate = AvailableUpdate(
                    version: version,
                    releasePage: release.htmlURL,
                    downloadURL: downloadURL
                )
                statusText = "发现新版本 \(version)"
            } catch {
                if !silent {
                    statusText = "检查失败，请确认网络后重试"
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

                let downloads = FileManager.default.urls(
                    for: .downloadsDirectory,
                    in: .userDomainMask
                ).first!
                let destination = Self.availableDestination(
                    in: downloads,
                    filename: downloadURL.lastPathComponent
                )
                try FileManager.default.moveItem(at: temporaryURL, to: destination)
                downloadedInstaller = destination
                statusText = "更新已下载，打开安装包即可完成更新"
                NSWorkspace.shared.open(destination)
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
        NSWorkspace.shared.open(availableUpdate?.releasePage ?? Self.repositoryURL)
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

    private static func normalizedVersion(_ value: String) -> String {
        value.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
    }

    private static func isNewer(_ candidate: String, than current: String) -> Bool {
        candidate.compare(current, options: .numeric) == .orderedDescending
    }

    private static func availableDestination(in directory: URL, filename: String) -> URL {
        let fileManager = FileManager.default
        let candidate = directory.appendingPathComponent(filename)
        guard fileManager.fileExists(atPath: candidate.path) else { return candidate }

        let base = (filename as NSString).deletingPathExtension
        let ext = (filename as NSString).pathExtension
        var index = 2
        while true {
            let numberedName = ext.isEmpty
                ? "\(base) \(index)"
                : "\(base) \(index).\(ext)"
            let numberedURL = directory.appendingPathComponent(numberedName)
            if !fileManager.fileExists(atPath: numberedURL.path) {
                return numberedURL
            }
            index += 1
        }
    }
}
