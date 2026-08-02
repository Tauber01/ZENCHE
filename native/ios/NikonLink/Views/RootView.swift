import AVFoundation
import AVKit
import CoreImage
import Foundation
import Photos
import SwiftUI
import UniformTypeIdentifiers
import UIKit

private enum RuntimeLocalization {
    private static let tables: [String: [String: String]] = [
        "en": loadTable(language: "en"),
        "ja": loadTable(language: "ja")
    ]

    static func text(_ source: String, locale: Locale) -> String {
        let identifier = locale.identifier.lowercased()
        let language = identifier.hasPrefix("ja")
            ? "ja"
            : identifier.hasPrefix("en") ? "en" : "zh-Hans"
        guard language != "zh-Hans", let table = tables[language] else {
            return source
        }
        if let exact = table[source] {
            return exact
        }
        return table.keys
            .filter {
                $0.count > 1
                    && !$0.contains("%")
                    && source.contains($0)
            }
            .sorted { $0.count > $1.count }
            .reduce(source) { partial, key in
                partial.replacingOccurrences(of: key, with: table[key] ?? key)
            }
    }

    private static func loadTable(language: String) -> [String: String] {
        guard
            let path = Bundle.main.path(forResource: language, ofType: "lproj"),
            let bundle = Bundle(path: path),
            let url = bundle.url(
                forResource: "Localizable",
                withExtension: "strings"
            ),
            let data = try? Data(contentsOf: url),
            let plist = try? PropertyListSerialization.propertyList(
                from: data,
                options: [],
                format: nil
            ),
            let table = plist as? [String: String]
        else {
            return [:]
        }
        return table
    }
}

private struct RuntimeLocalizedText: View {
    @Environment(\.locale) private var locale
    let source: String

    init(_ source: String) {
        self.source = source
    }

    var body: some View {
        Text(RuntimeLocalization.text(source, locale: locale))
    }
}

private enum IPalette {
    private static func dynamic(light: Int, dark: Int) -> Color {
        Color(uiColor: UIColor { traits in
            let rgb = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(
                red: CGFloat((rgb >> 16) & 0xff) / 255,
                green: CGFloat((rgb >> 8) & 0xff) / 255,
                blue: CGFloat(rgb & 0xff) / 255,
                alpha: 1
            )
        })
    }

    static let paper = dynamic(light: 0xE9EDF2, dark: 0x131519)
    static let paperSecondary = dynamic(light: 0xE4E9EF, dark: 0x23272E)
    static let surface = dynamic(light: 0xF8FAFC, dark: 0x1B1E24)
    static let surfaceRaised = dynamic(light: 0xFFFFFF, dark: 0x23272E)
    static let ink = dynamic(light: 0x171C26, dark: 0xECEEF2)
    static let muted = dynamic(light: 0x5A616C, dark: 0x9AA1AD)
    static let rule = dynamic(light: 0xCFD6DF, dark: 0x3E4249)
    static let cobalt = dynamic(light: 0x1673E6, dark: 0x2E86E0)
    static let cobaltSoft = dynamic(light: 0xDCEAFD, dark: 0x14293E)
    static let video = dynamic(light: 0xD8323A, dark: 0xFF5257)
    static let videoSoft = dynamic(light: 0xFBE2E3, dark: 0x3A1B1E)
    static let positive = dynamic(light: 0x1FA869, dark: 0x35C97B)
    static let graphite = Color(red: 10 / 255, green: 11 / 255, blue: 13 / 255)
    static let readoutGlow = Color(red: 107 / 255, green: 174 / 255, blue: 255 / 255)
    static let shadow = Color.black.opacity(0.18)
}

private let afdianURL = URL(string: "https://www.ifdian.net/a/Tauber")!
private let zencheWebsiteURL = URL(string: "https://zenche.top")!

private struct SplashView: View {
    var onComplete: () -> Void
    @State private var markScale: CGFloat = 0.01
    @State private var markOpacity: Double = 0
    @State private var textOpacity: Double = 0

    var body: some View {
        ZStack {
            IPalette.paper.ignoresSafeArea()
            VStack(spacing: 28) {
                ZStack {
                    RoundedRectangle(cornerRadius: 24)
                        .fill(
                            LinearGradient(
                                colors: [IPalette.cobalt, IPalette.cobalt.opacity(0.82)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 80, height: 80)
                        .scaleEffect(markScale)
                        .opacity(markOpacity)
                    Text("Z")
                        .font(.system(size: 42, weight: .heavy))
                        .foregroundStyle(.white)
                        .scaleEffect(markScale)
                        .opacity(markOpacity)
                }
                VStack(spacing: 6) {
                    Text("帧澈 ZENCHE")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(IPalette.ink)
                    Text("Capture · Connect · Flow")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(IPalette.muted)
                }
                .opacity(textOpacity)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.65)) {
                markScale = 1
                markOpacity = 1
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation(.easeOut(duration: 0.5)) {
                    textOpacity = 1
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
                onComplete()
            }
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("dismissedLaunchAnnouncementVersion")
    private var dismissedAnnouncementVersion = ""
    @State private var showingLaunchAnnouncement = false
    @State private var doNotRemindForCurrentVersion = false
    @State private var showSplash = true

    private static var appVersion: String {
        Bundle.main.object(
            forInfoDictionaryKey: "CFBundleShortVersionString"
        ) as? String ?? "1.3.1"
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                IPalette.paper
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    AppHeader()
                    Divider().overlay(IPalette.rule)

                    if proxy.size.width >= 820 {
                        HStack(spacing: 0) {
                            SideNavigation()
                            Divider().overlay(IPalette.rule)
                            CurrentPage()
                        }
                    } else {
                        CurrentPage()
                        Divider().overlay(IPalette.rule)
                        BottomNavigation(
                            bottomInset: proxy.safeAreaInsets.bottom
                        )
                    }

                }
            }
        }
        .overlay {
            if showSplash {
                SplashView {
                    withAnimation(.easeInOut(duration: 0.6)) {
                        showSplash = false
                    }
                }
            }
        }
        .sheet(isPresented: $model.showingConnection) {
            ConnectionSheet()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $model.showingSettings) {
            AppSettingsSheet()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingLaunchAnnouncement) {
            LaunchAnnouncementSheet(
                version: Self.appVersion,
                doNotRemind: $doNotRemindForCurrentVersion
            ) {
                if doNotRemindForCurrentVersion {
                    dismissedAnnouncementVersion = Self.appVersion
                }
                showingLaunchAnnouncement = false
            }
            .interactiveDismissDisabled()
            .presentationDetents([.large])
            .presentationCornerRadius(28)
        }
        .onAppear {
            model.updater.checkAutomaticallyIfNeeded()
            showingLaunchAnnouncement =
                dismissedAnnouncementVersion != Self.appVersion
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                DiagnosticLogger.shared.info("app", "应用进入前台")
                model.camera.refreshDevices()
                model.camera.resume()
            } else {
                DiagnosticLogger.shared.info("app", "应用离开前台")
                model.camera.suspend()
                model.wireless.stop()
            }
        }
    }
}

private struct AppHeader: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        Group {
            if horizontalSizeClass == .compact {
                HStack(spacing: 10) {
                    brand
                    Spacer(minLength: 8)
                    connectionButton
                    settingsButton
                }
            } else {
                HStack(spacing: 12) {
                    brand
                    Spacer(minLength: 8)
                    connectionButton
                    settingsButton
                }
            }
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 68)
        .background(IPalette.surface)
        .overlay(alignment: .bottom) {
            Rectangle().fill(IPalette.rule).frame(height: 0.5)
        }
        .shadow(color: IPalette.shadow.opacity(0.45), radius: 10, y: 3)
    }

    private var brand: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 13)
                    .fill(
                        LinearGradient(
                            colors: [IPalette.cobalt, IPalette.cobalt.opacity(0.82)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Text("Z")
                    .font(.system(size: 24, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
            }
            .frame(width: 44, height: 44)
            .shadow(color: IPalette.cobalt.opacity(0.18), radius: 8, y: 4)

            VStack(alignment: .leading, spacing: 2) {
                Text("帧澈 ZENCHE")
                    .font(.headline)
                Text("Capture · Connect · Flow")
                    .font(.caption)
                    .foregroundStyle(IPalette.muted)
            }
        }
    }

    private var connectionButton: some View {
        Button {
            model.showingConnection = true
        } label: {
            HStack(spacing: 7) {
                Circle()
                    .fill(connectionColor)
                    .frame(width: 8, height: 8)
                RuntimeLocalizedText(model.camera.state.title)
                    .lineLimit(1)
            }
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 12)
            .frame(minHeight: 44)
            .background(connectionColor.opacity(0.10), in: Capsule())
            .overlay {
                Capsule()
                    .stroke(connectionColor.opacity(0.24), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    private var settingsButton: some View {
        Button {
            model.showingSettings = true
        } label: {
            Image(systemName: "gearshape")
                .font(.system(size: 17, weight: .semibold))
                .frame(width: 44, height: 44)
                .background(IPalette.paperSecondary, in: Circle())
                .overlay {
                    Circle().stroke(IPalette.rule, lineWidth: 0.5)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("打开设置"))
    }

    private var connectionColor: Color {
        switch model.camera.state {
        case .ready: return IPalette.positive
        case .connecting: return .orange
        case .failed: return .red
        case .disconnected: return .secondary
        }
    }
}

private struct SideNavigation: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 9)
                    .fill(
                        LinearGradient(
                            colors: [IPalette.cobalt, IPalette.cobalt.opacity(0.82)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 34, height: 34)
                Text("Z")
                    .font(.system(size: 16, weight: .heavy))
                    .foregroundStyle(.white)
            }
            .padding(.bottom, 10)
            groupLabel("创作")
            navigationButton(.capture)
            navigationButton(.monitor)
            navigationButton(.editor)
            Divider().padding(.vertical, 6)
            groupLabel("管理")
            navigationButton(.library)
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 16)
        .frame(width: 108)
        .background(IPalette.paperSecondary)
    }

    private func groupLabel(_ title: String) -> some View {
        Text(LocalizedStringKey(title))
            .font(.caption2.monospaced().weight(.semibold))
            .foregroundStyle(IPalette.muted)
            .frame(width: 78, alignment: .leading)
            .padding(.leading, 4)
    }

    private func navigationButton(_ section: AppSection) -> some View {
        let active = model.section == section
        let accent = section == .monitor ? IPalette.video : IPalette.cobalt
        return Button {
            model.section = section
        } label: {
            VStack(spacing: 7) {
                Image(systemName: section.icon)
                    .font(.system(size: 20, weight: active ? .semibold : .medium))
                Text(
                    LocalizedStringKey(
                        section == .library ? "分支" : section.rawValue
                    )
                )
                    .font(.caption.weight(active ? .semibold : .medium))
            }
            .foregroundStyle(active ? accent : IPalette.muted)
            .frame(width: 82, height: 64)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(active ? IPalette.surface : .clear)
                    .shadow(
                        color: active ? IPalette.shadow.opacity(0.65) : .clear,
                        radius: 7,
                        y: 3
                    )
            )
            .overlay(alignment: .leading) {
                Capsule()
                    .fill(active ? accent : .clear)
                    .frame(width: 3, height: 28)
                    .offset(x: 3)
            }
        }
        .buttonStyle(.plain)
    }
}

private struct BottomNavigation: View {
    @EnvironmentObject private var model: AppModel
    let bottomInset: CGFloat

    var body: some View {
        HStack {
            ForEach(AppSection.allCases) { section in
                let accent = section == .monitor ? IPalette.video : IPalette.cobalt
                Button {
                    model.section = section
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: section.icon)
                            .font(.system(size: 18, weight: model.section == section ? .semibold : .medium))
                        Text(
                            LocalizedStringKey(
                                section == .library
                                    ? "分支"
                                    : section.rawValue
                            )
                        )
                            .font(.caption2)
                    }
                    .foregroundStyle(model.section == section ? accent : IPalette.muted)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 48)
                    .background(
                        model.section == section
                            ? accent.opacity(0.10)
                            : Color.clear,
                        in: RoundedRectangle(cornerRadius: 14)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .offset(y: min(bottomInset * 0.38, 14))
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(IPalette.surface)
        .overlay(alignment: .top) {
            Rectangle().fill(IPalette.rule).frame(height: 0.5)
        }
    }
}

private struct CurrentPage: View {
    @EnvironmentObject private var model: AppModel

    @ViewBuilder
    var body: some View {
        switch model.section {
        case .capture: CapturePage()
        case .monitor: MonitorPage()
        case .editor: ImageEditorPage()
        case .library: LibraryPage()
        }
    }
}

private enum EditorAdjustmentSection: String, CaseIterable, Identifiable {
    case light = "光线"
    case color = "色彩"
    case detail = "细节"
    case effects = "效果"
    case geometry = "几何"
    case aiTools = "AI 工具"

    var id: String { rawValue }
}

private enum AiImageMode: String, CaseIterable, Identifiable {
    case edit = "AI 修图"; case generate = "AI 生图"
    var id: String { rawValue }
}
private enum AiAspectRatio: String, CaseIterable, Identifiable {
    case square = "1:1"; case landscape = "16:9"; case portrait = "9:16"
    case fourThree = "4:3"; case threeTwo = "3:2"
    var id: String { rawValue }
    var size: String {
        switch self {
        case .square: "1024x1024"; case .landscape: "1792x1024"; case .portrait: "1024x1792"
        case .fourThree: "1365x1024"; case .threeTwo: "1536x1024"
        }
    }
}
private enum AiResolution: String, CaseIterable, Identifiable {
    case k1 = "1K"; case k2 = "2K"; case k4 = "4K"
    var id: String { rawValue }
}

final class ActivationManager {
    private static let ak = "ai_activated"; private static let dk = "ai_device_id"
    static var isActivated: Bool {
        UserDefaults.standard.bool(forKey: ak)
    }
    static var deviceId: String {
        if let e = UserDefaults.standard.string(forKey: dk), !e.isEmpty { return e }
        let id = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        UserDefaults.standard.set(id, forKey: dk); return id
    }
    static func verifyAndActivate(code: String) -> Bool {
        let t = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return false }
        let p = t.components(separatedBy: "-")
        guard p.count >= 4, p[0] == "ZENCHE", p[1] == "AI" else { return false }
        let exp = p.last ?? "19700101"
        let df = DateFormatter(); df.dateFormat = "yyyyMMdd"
        if let ed = df.date(from: exp), ed < Date() { return false }
        let did = deviceId
        let sigPart = p[2..<(p.count - 1)].joined(separator: "-")
        guard let sig = Data(base64Encoded: sigPart), let pk = publicKey else { return false }
        let payload = "\(did):\(exp):a1b2c3d4e5f6"
        guard let pd = payload.data(using: .utf8) else { return false }
        var err: Unmanaged<CFError>?
        let ok = SecKeyVerifySignature(pk, .rsaSignatureMessagePKCS1v15SHA256, pd as CFData, sig as CFData, &err)
        if ok {
            UserDefaults.standard.set(true, forKey: ak)
            UserDefaults.standard.set(did, forKey: dk)
            UserDefaults.standard.set(t, forKey: "ai_activation_code")
        }
        return ok
    }
    static var savedCode: String? {
        UserDefaults.standard.string(forKey: "ai_activation_code")
    }
    private static var publicKey: SecKey? {
        let k = ["MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAngqgOi5fjajCPusMNsfB","FdMmWywGAwrL5bA+JK/uW+Mf/YDs5hQopYcxoDiSY2yQnGmGSo8XJ4apYLVH1bDt","PFGGj+TxfFNLGicPJzGkRKY7UVQHvlYPNiCBRPWgFw0gCNArqoHDXoTLj4q8C5MZ","9kZPv9qWeMZ5A5m5q8n2KjYfN8vLz5XH2LdPm9QaW7RzVYfJbGvKRhJzL3NxP8","+ZzVjQmzHjKlK2Qw9MkPvN7J2GXYxHdVfRjQ8GvKzL5XgP3XjH9mQz5YzQdGhN","VbKzYxHV9fHjGkJzX8DfNzVbYzGdRmNkQzNxGkPvMkHjKjYzJ2L5NxP8iQzvQ","MjQzRwIDAQAB"].joined()
        guard let d = Data(base64Encoded: k) else { return nil }
        return SecKeyCreateWithData(d as CFData, [kSecAttrKeyClass as String: kSecAttrKeyClassPublic, kSecAttrKeyType as String: kSecAttrKeyTypeRSA, kSecAttrKeySizeInBits as String: 2048] as CFDictionary, nil)
    }
}

private final class AiImageService {
    private static var serverURL: String {
        UserDefaults.standard.string(forKey: "aiServerURL") ?? "http://101.34.255.115:8787"
    }
    private static var endpoint: URL? {
        URL(string: "\(serverURL.trimmingCharacters(in: .whitespacesAndNewlines))/v1/ai")
    }
    func generate(prompt: String, src: Data?, size: String, activationCode: String, deviceId: String) async throws -> Data {
        guard let url = Self.endpoint else { throw AiError.invalidEndpoint }
        var body: [String: Any] = [
            "activationCode": activationCode,
            "deviceId": deviceId,
            "prompt": prompt,
            "size": size
        ]
        if let s = src { body["image"] = s.base64EncodedString() }
        var r = URLRequest(url: url); r.httpMethod = "POST"
        r.setValue("application/json", forHTTPHeaderField: "Content-Type")
        r.timeoutInterval = 60; r.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, resp) = try await URLSession.shared.data(for: r)
        guard let hr = resp as? HTTPURLResponse else { throw AiError.networkError }
        guard (200..<300).contains(hr.statusCode) else {
            if hr.statusCode == 403 { throw AiError.invalidActivationCode }
            if hr.statusCode == 502 { throw AiError.serverUnavailable }
            if hr.statusCode == 429 { throw AiError.rateLimited }
            throw AiError.serverError(hr.statusCode)
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let arr = json["data"] as? [[String: Any]], let f = arr.first else { throw AiError.noImageReturned }
        if let b64 = f["b64_json"] as? String, let d = Data(base64Encoded: b64) { return d }
        if let u = f["url"] as? String, let url = URL(string: u) { let (d,_) = try await URLSession.shared.data(from: url); return d }
        throw AiError.noImageReturned
    }
}

enum AiError: LocalizedError {
    case missingActivation, invalidActivationCode, invalidEndpoint, networkError, serverError(Int), rateLimited, noImageReturned, serverUnavailable
    var errorDescription: String? {
        switch self {
        case .missingActivation: "请先在设置中输入激活码解锁 AI 功能"
        case .invalidActivationCode: "激活码无效或已过期，请联系开发者"
        case .invalidEndpoint: "API 端点地址无效"
        case .networkError: "网络连接失败"
        case .serverError(let c): "AI 服务返回错误（\(c)）"
        case .rateLimited: "请求太频繁，请稍后重试"
        case .noImageReturned: "AI 未返回有效图片"
        case .serverUnavailable: "AI 服务暂不可用，请稍后重试"
        }
    }
}

private enum EditorCropRatio: String, CaseIterable, Identifiable {
    case original = "原始比例"
    case square = "1:1"
    case fourThree = "4:3"
    case threeTwo = "3:2"
    case sixteenNine = "16:9"

    var id: String { rawValue }

    var value: CGFloat? {
        switch self {
        case .original: nil
        case .square: 1
        case .fourThree: 4 / 3
        case .threeTwo: 3 / 2
        case .sixteenNine: 16 / 9
        }
    }
}

private enum EditorPreset: String, CaseIterable, Identifiable {
    case original = "原始"
    case natural = "自然增强"
    case portrait = "人像柔和"
    case landscape = "风光通透"
    case monochrome = "高反差黑白"

    var id: String { rawValue }
}

private struct EditorAIAnalysis {
    let meanLuma: Double
    let contrast: Double
    let shadowRatio: Double
    let highlightRatio: Double
    let saturation: Double
    let red: Double
    let green: Double
    let blue: Double
    let detail: Double

    var summaryKey: String {
        if meanLuma < 0.38 {
            return "检测到画面偏暗，已提亮阴影并保护高光"
        }
        if meanLuma > 0.64 || highlightRatio > 0.08 {
            return "检测到画面偏亮，已回收高光并恢复层次"
        }
        if contrast < 0.16 {
            return "检测到动态范围偏平，已增强层次与色彩"
        }
        return "曝光均衡，已优化色彩与细节"
    }
}

private struct ProfessionalEditSettings {
    var exposure = 0.0
    var contrast = 0.0
    var highlights = 0.0
    var shadows = 0.0
    var whites = 0.0
    var blacks = 0.0
    var temperature = 0.0
    var tint = 0.0
    var vibrance = 0.0
    var saturation = 0.0
    var texture = 0.0
    var clarity = 0.0
    var sharpening = 0.0
    var noiseReduction = 0.0
    var dehaze = 0.0
    var vignette = 0.0
    var rotation = 0
    var flipHorizontal = false
    var flipVertical = false
    var cropRatio = EditorCropRatio.original

    mutating func resetTone() {
        let geometry = (
            rotation,
            flipHorizontal,
            flipVertical,
            cropRatio
        )
        self = ProfessionalEditSettings()
        rotation = geometry.0
        flipHorizontal = geometry.1
        flipVertical = geometry.2
        cropRatio = geometry.3
    }

    mutating func apply(_ preset: EditorPreset) {
        resetTone()
        switch preset {
        case .original:
            break
        case .natural:
            contrast = 8
            highlights = -18
            shadows = 16
            whites = 8
            blacks = -8
            vibrance = 14
            texture = 8
            clarity = 6
            sharpening = 24
            noiseReduction = 8
        case .portrait:
            contrast = -4
            highlights = -24
            shadows = 18
            temperature = 7
            tint = 4
            vibrance = 10
            texture = -12
            clarity = -6
            sharpening = 16
            noiseReduction = 22
            vignette = -8
        case .landscape:
            contrast = 12
            highlights = -28
            shadows = 14
            whites = 12
            blacks = -14
            vibrance = 24
            saturation = 5
            texture = 16
            clarity = 18
            sharpening = 30
            dehaze = 12
            vignette = -10
        case .monochrome:
            contrast = 22
            highlights = -18
            shadows = 12
            whites = 10
            blacks = -22
            saturation = -100
            texture = 12
            clarity = 24
            sharpening = 28
            vignette = -14
        }
    }

    mutating func applyAI(
        _ analysis: EditorAIAnalysis,
        intensity: Double
    ) {
        resetTone()
        let amount = max(0.35, min(1, intensity))
        let targetExposure = max(
            -0.8,
            min(0.8, log2(0.48 / max(0.08, analysis.meanLuma)) * 0.68)
        )
        exposure = targetExposure * amount
        contrast = max(
            -8,
            min(24, (0.20 - analysis.contrast) * 130)
        ) * amount
        highlights = -max(
            6,
            min(48, analysis.highlightRatio * 360 + max(0, analysis.meanLuma - 0.55) * 70)
        ) * amount
        shadows = max(
            6,
            min(46, analysis.shadowRatio * 330 + max(0, 0.44 - analysis.meanLuma) * 75)
        ) * amount
        whites = max(-8, min(14, (0.58 - analysis.meanLuma) * 28)) * amount
        blacks = -max(4, min(18, (0.21 - analysis.contrast) * 55 + 5)) * amount
        temperature = max(-18, min(18, (analysis.blue - analysis.red) * 95)) * amount
        let greenExcess = analysis.green - (analysis.red + analysis.blue) / 2
        tint = max(-14, min(14, greenExcess * 85)) * amount
        vibrance = max(4, min(26, (0.30 - analysis.saturation) * 95 + 6)) * amount
        saturation = max(-4, min(8, (0.22 - analysis.saturation) * 28)) * amount
        texture = max(4, min(16, (0.075 - analysis.detail) * 170 + 7)) * amount
        clarity = max(3, min(18, (0.19 - analysis.contrast) * 70 + 6)) * amount
        sharpening = max(14, min(34, (0.08 - analysis.detail) * 210 + 20)) * amount
        noiseReduction = max(6, min(30, analysis.shadowRatio * 120 + max(0, 0.38 - analysis.meanLuma) * 42 + 6)) * amount
        dehaze = max(0, min(16, (0.18 - analysis.contrast) * 75)) * amount
    }
}

private struct ImageEditorPage: View {
    @EnvironmentObject private var model: AppModel
    @State private var selectedItemID: LibraryItem.ID?
    @State private var selectedSection = EditorAdjustmentSection.light
    @State private var settings = ProfessionalEditSettings()
    @State private var selectedPreset = EditorPreset.original
    @State private var showingOriginal = false
    @State private var status = "请选择文件库中的照片"
    @State private var isSaving = false
    @State private var aiIntensity = 0.72
    @State private var aiSummaryKey = "等待分析当前照片"
    @State private var settingsBeforeAI: ProfessionalEditSettings?
    @State private var aiAnalysis: EditorAIAnalysis?
    @State private var copiedAISettings: ProfessionalEditSettings?
    private let context = CIContext()
    @State private var aiMode = AiImageMode.edit
    @State private var aiPrompt = ""
    @State private var aiRatio = AiAspectRatio.square
    @State private var aiResolution = AiResolution.k1
    @State private var aiResultImage: UIImage?
    @State private var aiIsGenerating = false
    private let aiService = AiImageService()

    private var photos: [LibraryItem] {
        model.library.items.filter {
            !$0.isVideo
                && Self.editableExtensions.contains(
                    $0.url.pathExtension.lowercased()
                )
        }
    }

    private static let editableExtensions: Set<String> = [
        "jpg", "jpeg", "png", "heic", "heif", "tif", "tiff", "bmp"
    ]

    private var selectedItem: LibraryItem? {
        photos.first { $0.id == selectedItemID }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                PageTitle(
                    title: selectedSection == .aiTools ? "AI 工具" : "专业显影",
                    subtitle: selectedSection == .aiTools
                        ? "基于 nano-banana-2 模型的 AI 修图与生图"
                        : "分组调整光线、色彩、细节、效果与几何；始终保留原文件。"
                )
                if selectedSection == .aiTools { aiToolsToolbar } else { editorToolbar }
                preview
                sectionSelector
                if selectedSection == .aiTools {
                    aiToolsPanel
                } else {
                    aiWorkbench
                    adjustmentPanel
                }
                if selectedSection != .aiTools { editorFooter }
            }
            .padding(20)
        }
        .onAppear {
            selectInitialPhoto()
        }
        .onChange(of: selectedItemID) {
            resetAdjustments()
            status = selectedItem == nil
                ? "请选择文件库中的照片"
                : "调整不会覆盖原文件"
        }
    }

    private var aiToolsToolbar: some View {
        HStack(spacing: 10) {
            Picker("编辑照片", selection: $selectedItemID) {
                Text("选择照片").tag(nil as LibraryItem.ID?)
                ForEach(photos) { item in Text(item.filename).tag(item.id as LibraryItem.ID?) }
            }.pickerStyle(.menu).frame(maxWidth: 340, alignment: .leading)
            Spacer()
            if aiResultImage != nil {
                Button { aiResultImage = nil } label: {
                    Label("清除结果", systemImage: "xmark.circle")
                }.buttonStyle(.bordered)
            }
        }
    }

    private var aiToolsPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Label("AI 创作", systemImage: "sparkles")
                        .font(.headline)
                    Text("联网生成与修图 · 结果保存为新文件")
                        .font(.caption)
                        .foregroundStyle(IPalette.muted)
                }
                Spacer()
                Text(ActivationManager.isActivated ? "已解锁" : "需要激活")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(ActivationManager.isActivated ? IPalette.positive : IPalette.muted)
                    .padding(.horizontal, 10)
                    .frame(minHeight: 28)
                    .background(
                        ActivationManager.isActivated ? IPalette.positive.opacity(0.12) : IPalette.paperSecondary,
                        in: Capsule()
                    )
            }
            HStack(spacing: 8) {
                ForEach(AiImageMode.allCases) { mode in
                    Button {
                        aiMode = mode
                        aiResultImage = nil
                    } label: {
                        Label(mode.rawValue, systemImage: mode == .edit ? "wand.and.stars" : "photo.badge.plus")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(aiMode == mode ? IPalette.cobalt : IPalette.surface)
                    .foregroundStyle(aiMode == mode ? Color.white : IPalette.ink)
                }
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("提示词").font(.subheadline.weight(.semibold))
                TextField(aiMode == .edit ? "输入修图描述…" : "输入生图描述…", text: $aiPrompt, axis: .vertical)
                    .lineLimit(3...6).textFieldStyle(.roundedBorder)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("快捷预设").font(.caption.weight(.semibold))
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 6)], alignment: .leading, spacing: 6) {
                    ForEach(aiPresets, id: \.0) { preset in
                        Button {
                            aiPrompt = preset.1
                            status = "已应用预设 · \(preset.0)"
                        } label: {
                            Text(preset.0).font(.caption).lineLimit(1)
                                .frame(maxWidth: .infinity).frame(minHeight: 30)
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("宽高比").font(.caption).foregroundStyle(IPalette.muted)
                    Picker("宽高比", selection: $aiRatio) {
                        ForEach(AiAspectRatio.allCases) { r in Text(r.rawValue).tag(r) }
                    }.pickerStyle(.menu)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("分辨率").font(.caption).foregroundStyle(IPalette.muted)
                    Picker("分辨率", selection: $aiResolution) {
                        ForEach(AiResolution.allCases) { r in Text(r.rawValue).tag(r) }
                    }.pickerStyle(.menu)
                }
                Spacer()
            }
            HStack {
                Button { generateAi() } label: {
                    Label(aiIsGenerating ? "正在生成…" : "生成", systemImage: "sparkles")
                }.buttonStyle(.borderedProminent)
                .disabled(aiPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || aiIsGenerating || (selectedItem == nil && aiMode == .edit))
                if aiResultImage != nil {
                    Button { saveAiResult() } label: {
                        Label(isSaving ? "正在保存…" : "保存到文件库", systemImage: "square.and.arrow.down")
                    }.buttonStyle(.borderedProminent).disabled(isSaving)
                }
                Spacer()
            }
            Text(aiIsGenerating ? "正在调用 AI 模型…" : status)
                .font(.caption.monospaced())
                .foregroundStyle(IPalette.muted)
                .lineLimit(2)
        }
        .padding(18).background(IPalette.surface, in: RoundedRectangle(cornerRadius: 14))
        .overlay { RoundedRectangle(cornerRadius: 14).stroke(IPalette.rule) }
    }

    private var aiPresets: [(String, String)] {
        if aiMode == .edit {
            return [
                ("一键美颜", "对照片中的人物进行自然美颜：柔化皮肤、去除瑕疵、提亮肤色、轻微瘦脸，保持自然真实质感，不过度处理。"),
                ("自然增强", "增强照片的自然色彩与光影：提升饱和度与对比度，保留真实细节，使画面更通透清晰。"),
                ("胶片质感", "为照片添加复古胶片质感：轻微颗粒、柔和对比、温暖色调，类似柯达 Portra 胶片的色彩风格。"),
                ("日系清新", "调整为日系清新风格：低对比度、偏亮高调、冷色调、干净通透，画面清新柔和。"),
                ("黑白大片", "转换为高反差黑白摄影风格：增强明暗对比、保留细节纹理，营造经典黑白大片质感。"),
                ("复古暖调", "添加复古暖调风格：整体偏暖黄色调、轻微褪色、柔和光线，怀旧氛围。"),
                ("天空增强", "增强画面中的天空：让蓝天更通透湛蓝、云朵更立体，同时保持地面细节自然。"),
                ("美食诱人", "增强美食照片的诱人质感：提升色彩饱和度、增强光泽细节，让食物看起来更美味。")
            ]
        } else {
            return [
                ("人像写真", "professional portrait photography, studio lighting, sharp focus, shallow depth of field, high detail"),
                ("风光大片", "breathtaking landscape photography, golden hour, dramatic sky, high dynamic range, ultra detailed"),
                ("城市夜景", "city night photography, neon lights, long exposure, reflections, vibrant urban atmosphere"),
                ("产品展示", "professional product photography, clean studio background, soft lighting, high detail")
            ]
        }
    }
    private var aiWorkbench: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Label("AI 智能修图 · 工作台", systemImage: "sparkles")
                    .font(.headline)
                Text("设备端 · 照片不会上传")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(IPalette.cobalt)
                    .padding(.horizontal, 8)
                    .frame(minHeight: 26)
                    .background(IPalette.cobaltSoft, in: Capsule())
                Spacer()
                Text("\(Int(aiIntensity * 100))%")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(IPalette.muted)
            }
            Text(LocalizedStringKey(aiSummaryKey))
                .font(.subheadline)
                .foregroundStyle(IPalette.muted)
            if let aiAnalysis {
                HStack(spacing: 8) {
                    aiMetric("曝光", value: aiAnalysis.meanLuma, suffix: "%")
                    aiMetric("动态范围", value: aiAnalysis.contrast, suffix: "%")
                    aiMetric("色彩", value: aiAnalysis.saturation, suffix: "%")
                    aiMetric("细节", value: aiAnalysis.detail, suffix: "%")
                }
            }
            HStack(spacing: 12) {
                Image(systemName: "circle.lefthalf.filled")
                    .foregroundStyle(IPalette.muted)
                Slider(value: $aiIntensity, in: 0.35...1, step: 0.05)
                    .accessibilityLabel("AI 强度")
                Image(systemName: "circle.fill")
                    .foregroundStyle(IPalette.cobalt)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    Button {
                        analyzeAI()
                    } label: {
                        Label("分析画面", systemImage: "waveform.path.ecg")
                    }
                    .buttonStyle(.bordered)
                    .disabled(selectedItem == nil)
                    Button {
                        applyAIEnhancement()
                    } label: {
                        Label("智能优化", systemImage: "wand.and.stars")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(selectedItem == nil)
                    Button {
                        undoAIEnhancement()
                    } label: {
                        Label("撤销 AI", systemImage: "arrow.uturn.backward")
                    }
                    .buttonStyle(.bordered)
                    .disabled(settingsBeforeAI == nil)
                    Button {
                        copiedAISettings = settings
                        status = "已复制 AI 调整，可应用到下一张照片"
                    } label: {
                        Label("复制 AI", systemImage: "doc.on.doc")
                    }
                    .buttonStyle(.bordered)
                    .disabled(settingsBeforeAI == nil)
                    Button {
                        guard let copiedAISettings else { return }
                        settings = copiedAISettings
                        selectedPreset = .original
                        showingOriginal = false
                        status = "已粘贴 AI 调整"
                    } label: {
                        Label("粘贴 AI", systemImage: "doc.on.clipboard")
                    }
                    .buttonStyle(.bordered)
                    .disabled(copiedAISettings == nil || selectedItem == nil)
                    Text("本地处理 · 可继续微调")
                        .font(.caption)
                        .foregroundStyle(IPalette.muted)
                }
            }
        }
        .padding(16)
        .background(IPalette.cobaltSoft.opacity(0.6), in: RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(IPalette.cobalt.opacity(0.32))
        }
    }

    private func aiMetric(_ title: String, value: Double, suffix: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(LocalizedStringKey(title))
                .font(.caption2)
                .foregroundStyle(IPalette.muted)
            Text("\(Int(max(0, min(1, value)) * 100))\(suffix)")
                .font(.caption.monospacedDigit().weight(.semibold))
                .foregroundStyle(IPalette.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 9)
        .frame(minHeight: 44)
        .background(IPalette.surface.opacity(0.72), in: RoundedRectangle(cornerRadius: 8))
    }

    private var editorToolbar: some View {
        HStack(spacing: 10) {
            Picker("编辑照片", selection: $selectedItemID) {
                Text("选择照片").tag(nil as LibraryItem.ID?)
                ForEach(photos) { item in
                    Text(item.filename)
                        .tag(item.id as LibraryItem.ID?)
                }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: 340, alignment: .leading)

            Menu {
                ForEach(EditorPreset.allCases) { preset in
                    Button(LocalizedStringKey(preset.rawValue)) {
                        selectedPreset = preset
                        settings.apply(preset)
                        settingsBeforeAI = nil
                        aiSummaryKey = "等待分析当前照片"
                        showingOriginal = false
                        status = "已应用预设 · \(preset.rawValue)"
                    }
                }
            } label: {
                Label(selectedPreset.rawValue, systemImage: "camera.filters")
            }
            .buttonStyle(.bordered)

            Spacer()

            Button {
                showingOriginal.toggle()
            } label: {
                Label(
                    showingOriginal ? "返回调整" : "查看原图",
                    systemImage: "circle.lefthalf.filled"
                )
            }
            .buttonStyle(.bordered)
        }
    }

    private var preview: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 18)
                .fill(IPalette.graphite)
            if selectedSection == .aiTools, let ai = aiResultImage {
                Image(uiImage: ai).resizable().scaledToFit().padding(12)
            } else if let image = renderedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .padding(12)
            } else {
                ContentUnavailableView(
                    "选择一张照片开始编辑",
                    systemImage: "slider.horizontal.3",
                    description: Text(
                        "视频与暂不支持解码的 RAW 文件不会进入编辑列表。"
                    )
                )
                .foregroundStyle(.white, IPalette.muted)
            }
            if selectedSection != .aiTools {
                Text(showingOriginal ? "原图" : "调整后")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .frame(minHeight: 30)
                    .background(.black.opacity(0.58))
                    .clipShape(Capsule())
                    .padding(12)
            } else if aiResultImage != nil {
                Text("AI 生成")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .frame(minHeight: 30)
                    .background(.black.opacity(0.58))
                    .clipShape(Capsule())
                    .padding(12)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 300, idealHeight: 460, maxHeight: 560)
    }

    private var sectionSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(EditorAdjustmentSection.allCases) { section in
                    Button(LocalizedStringKey(section.rawValue)) {
                        selectedSection = section
                    }
                    .buttonStyle(
                        EditorSectionButtonStyle(
                            selected: selectedSection == section
                        )
                    )
                }
            }
        }
    }

    @ViewBuilder
    private var adjustmentPanel: some View {
        VStack(spacing: 12) {
            switch selectedSection {
            case .light:
                editorSlider(
                    title: "曝光",
                    value: $settings.exposure,
                    range: -2...2,
                    step: 0.05,
                    formatter: { String(format: "%+.2f EV", $0) }
                )
                standardSlider("对比度", value: $settings.contrast)
                standardSlider("高光", value: $settings.highlights)
                standardSlider("阴影", value: $settings.shadows)
                standardSlider("白色色阶", value: $settings.whites)
                standardSlider("黑色色阶", value: $settings.blacks)
            case .color:
                standardSlider("色温", value: $settings.temperature)
                standardSlider("色调", value: $settings.tint)
                standardSlider("自然饱和度", value: $settings.vibrance)
                standardSlider("饱和度", value: $settings.saturation)
            case .detail:
                standardSlider("纹理", value: $settings.texture)
                standardSlider("清晰度", value: $settings.clarity)
                editorSlider(
                    title: "锐化",
                    value: $settings.sharpening,
                    range: 0...100,
                    step: 1,
                    formatter: { "\(Int($0))" }
                )
                editorSlider(
                    title: "降噪",
                    value: $settings.noiseReduction,
                    range: 0...100,
                    step: 1,
                    formatter: { "\(Int($0))" }
                )
            case .effects:
                standardSlider("去雾", value: $settings.dehaze)
                standardSlider("暗角", value: $settings.vignette)
            case .geometry:
                geometryControls
            case .aiTools:
                EmptyView()
            }
        }
        .padding(16)
        .background(
            IPalette.surface,
            in: RoundedRectangle(cornerRadius: 16)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(IPalette.rule)
        }
    }

    private func standardSlider(
        _ title: String,
        value: Binding<Double>
    ) -> some View {
        editorSlider(
            title: title,
            value: value,
            range: -100...100,
            step: 1,
            formatter: { String(format: "%+.0f", $0) }
        )
    }

    private var geometryControls: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("裁切比例")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Picker("裁切比例", selection: $settings.cropRatio) {
                    ForEach(EditorCropRatio.allCases) { ratio in
                        Text(ratio.rawValue).tag(ratio)
                    }
                }
                .pickerStyle(.menu)
            }
            HStack(spacing: 8) {
                Button {
                    settings.rotation = (settings.rotation + 90) % 360
                } label: {
                    Label("旋转 90°", systemImage: "rotate.right")
                }
                Button {
                    settings.flipHorizontal.toggle()
                } label: {
                    Label("水平翻转", systemImage: "arrow.left.and.right")
                }
                Button {
                    settings.flipVertical.toggle()
                } label: {
                    Label("垂直翻转", systemImage: "arrow.up.and.down")
                }
            }
            .buttonStyle(.bordered)
        }
    }

    private var editorFooter: some View {
        HStack(spacing: 12) {
            Button("全部重置") {
                resetAdjustments()
            }
            .buttonStyle(.bordered)
            Text(status)
                .font(.caption.monospaced())
                .foregroundStyle(IPalette.muted)
            Spacer()
            Button {
                saveCopy()
            } label: {
                Label(
                    isSaving ? "正在保存…" : "保存高质量副本",
                    systemImage: "square.and.arrow.down"
                )
            }
            .buttonStyle(.borderedProminent)
            .disabled(selectedItem == nil || isSaving)
        }
    }

    private var renderedImage: UIImage? {
        guard let selectedItem else { return nil }
        let source =
            CIImage(contentsOf: selectedItem.url)
            ?? UIImage(contentsOfFile: selectedItem.url.path)
                .flatMap { CIImage(image: $0) }
        guard var output = source else { return nil }

        if !showingOriginal {
            output = applyTonePipeline(to: output)
        }
        if !showingOriginal {
            output = applyGeometry(to: output)
        }
        let extent = output.extent.integral
        guard let cgImage = context.createCGImage(output, from: extent) else {
            return nil
        }
        return UIImage(cgImage: cgImage)
    }

    private func applyTonePipeline(to source: CIImage) -> CIImage {
        var output = source

        output = filtered(
            "CIExposureAdjust",
            image: output,
            values: [kCIInputEVKey: settings.exposure]
        )
        output = filtered(
            "CITemperatureAndTint",
            image: output,
            values: [
                "inputNeutral": CIVector(x: 6500, y: 0),
                "inputTargetNeutral": CIVector(
                    x: 6500 + settings.temperature * 24,
                    y: settings.tint * 1.5
                )
            ]
        )
        output = filtered(
            "CIHighlightShadowAdjust",
            image: output,
            values: [
                "inputHighlightAmount":
                    max(0, min(2, 1 + settings.highlights / 100)),
                "inputShadowAmount": settings.shadows / 100
            ]
        )
        output = filtered(
            "CIVibrance",
            image: output,
            values: ["inputAmount": settings.vibrance / 100]
        )

        let combinedContrast =
            settings.contrast / 100
            + settings.dehaze / 260
            + settings.clarity / 420
        let combinedSaturation =
            settings.saturation / 100
            + settings.dehaze / 500
        output = filtered(
            "CIColorControls",
            image: output,
            values: [
                kCIInputContrastKey: max(0, 1 + combinedContrast),
                kCIInputSaturationKey: max(0, 1 + combinedSaturation)
            ]
        )

        let gain = max(0.4, 1 + settings.whites / 260)
        let lift = settings.blacks / 850
        let tintShift = settings.tint / 1800
        output = filtered(
            "CIColorMatrix",
            image: output,
            values: [
                "inputRVector": CIVector(x: gain, y: 0, z: 0, w: 0),
                "inputGVector": CIVector(x: 0, y: gain, z: 0, w: 0),
                "inputBVector": CIVector(x: 0, y: 0, z: gain, w: 0),
                "inputBiasVector": CIVector(
                    x: lift + tintShift,
                    y: lift - tintShift,
                    z: lift + tintShift,
                    w: 0
                )
            ]
        )

        if settings.texture > 0 {
            output = filtered(
                "CIUnsharpMask",
                image: output,
                values: [
                    kCIInputRadiusKey: 1.2,
                    kCIInputIntensityKey: settings.texture / 140
                ]
            )
        } else if settings.texture < 0 {
            let extent = output.extent
            output = filtered(
                "CIGaussianBlur",
                image: output,
                values: [
                    kCIInputRadiusKey: -settings.texture / 75
                ]
            )
            .cropped(to: extent)
        }
        if settings.clarity > 0 {
            output = filtered(
                "CIUnsharpMask",
                image: output,
                values: [
                    kCIInputRadiusKey: 8,
                    kCIInputIntensityKey: settings.clarity / 180
                ]
            )
        }
        if settings.sharpening > 0 {
            output = filtered(
                "CISharpenLuminance",
                image: output,
                values: [
                    kCIInputSharpnessKey: settings.sharpening / 70
                ]
            )
        }
        if settings.noiseReduction > 0 {
            output = filtered(
                "CINoiseReduction",
                image: output,
                values: [
                    "inputNoiseLevel":
                        0.02 + settings.noiseReduction / 1250,
                    "inputSharpness":
                        max(0, 0.4 - settings.noiseReduction / 300)
                ]
            )
        }
        if settings.vignette != 0 {
            output = filtered(
                "CIVignette",
                image: output,
                values: [
                    kCIInputIntensityKey: -settings.vignette / 45,
                    kCIInputRadiusKey:
                        min(output.extent.width, output.extent.height) * 0.75
                ]
            )
        }
        return output
    }

    private func filtered(
        _ name: String,
        image: CIImage,
        values: [String: Any]
    ) -> CIImage {
        guard let filter = CIFilter(name: name) else { return image }
        filter.setValue(image, forKey: kCIInputImageKey)
        values.forEach { filter.setValue($0.value, forKey: $0.key) }
        return filter.outputImage ?? image
    }

    private func applyGeometry(to source: CIImage) -> CIImage {
        var output = source
        if settings.rotation != 0 {
            output = output.transformed(
                by: CGAffineTransform(
                    rotationAngle:
                        CGFloat(settings.rotation) * .pi / 180
                )
            )
            output = normalized(output)
        }
        if settings.flipHorizontal {
            output = output.transformed(
                by: CGAffineTransform(scaleX: -1, y: 1)
            )
            output = normalized(output)
        }
        if settings.flipVertical {
            output = output.transformed(
                by: CGAffineTransform(scaleX: 1, y: -1)
            )
            output = normalized(output)
        }
        if let ratio = settings.cropRatio.value {
            let extent = output.extent
            var width = extent.width
            var height = width / ratio
            if height > extent.height {
                height = extent.height
                width = height * ratio
            }
            let crop = CGRect(
                x: extent.midX - width / 2,
                y: extent.midY - height / 2,
                width: width,
                height: height
            )
            output = output.cropped(to: crop)
            output = normalized(output)
        }
        return output
    }

    private func normalized(_ image: CIImage) -> CIImage {
        let extent = image.extent
        return image.transformed(
            by: CGAffineTransform(
                translationX: -extent.minX,
                y: -extent.minY
            )
        )
    }

    private func editorSlider(
        title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double,
        formatter: @escaping (Double) -> String
    ) -> some View {
        HStack(spacing: 12) {
            Text(LocalizedStringKey(title))
                .font(.subheadline.weight(.semibold))
                .frame(width: 84, alignment: .leading)
            Slider(value: value, in: range, step: step)
            Text(formatter(value.wrappedValue))
                .font(.caption.monospacedDigit())
                .foregroundStyle(IPalette.muted)
                .frame(width: 68, alignment: .trailing)
        }
        .frame(minHeight: 44)
    }

    private func selectInitialPhoto() {
        if let selected = model.library.selectedItem,
           photos.contains(where: { $0.id == selected.id }) {
            selectedItemID = selected.id
        } else if selectedItem == nil {
            selectedItemID = photos.first?.id
        }
    }

    private func generateAi() {
        guard !aiPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { status = "请输入提示词"; return }
        guard ActivationManager.isActivated else { status = "请先在设置中输入激活码解锁 AI 功能"; return }
        guard let code = ActivationManager.savedCode, !code.isEmpty else { status = "请先在设置中输入激活码解锁 AI 功能"; return }
        let src: Data? = aiMode == .edit ? selectedItem.flatMap { try? Data(contentsOf: $0.url) } : nil
        if aiMode == .edit, src == nil { status = "请先选择一张照片用于 AI 修图"; return }
        aiIsGenerating = true; status = "正在调用 AI 模型…"
        Task {
            do {
                let d = try await aiService.generate(prompt: aiPrompt, src: src, size: aiRatio.size, activationCode: code, deviceId: ActivationManager.deviceId)
                let img = UIImage(data: d)
                await MainActor.run {
                    aiResultImage = img; aiIsGenerating = false
                    status = img != nil ? "生成完成" : "无法解码 AI 返回的图片"
                }
            } catch {
                await MainActor.run { aiIsGenerating = false; status = error.localizedDescription }
            }
        }
    }

    private func saveAiResult() {
        guard let img = aiResultImage, let data = img.jpegData(compressionQuality: 0.95) else { status = "没有可保存的 AI 结果"; return }
        isSaving = true
        let fn = "ai_\(aiMode == .edit ? "edited" : "generated").jpg"
        if let saved = model.library.saveEditedImage(data, originalFilename: fn) {
            selectedItemID = saved.path; status = "已保存 AI 结果 · \(saved.lastPathComponent)"
        } else { status = model.library.message }
        isSaving = false
    }

    private func resetAdjustments() {
        settings = ProfessionalEditSettings()
        selectedPreset = .original
        showingOriginal = false
        settingsBeforeAI = nil
        aiSummaryKey = "等待分析当前照片"
        aiAnalysis = nil
    }

    private func analyzeAI() {
        guard let selectedItem,
              let source = CIImage(contentsOf: selectedItem.url),
              let analysis = analyzeForAI(source)
        else {
            status = "无法分析当前照片"
            return
        }
        aiAnalysis = analysis
        aiSummaryKey = analysis.summaryKey
        status = "画面分析完成 · 可应用 AI 建议"
    }

    private func applyAIEnhancement() {
        guard let selectedItem,
              let source = CIImage(contentsOf: selectedItem.url),
              let analysis = aiAnalysis ?? analyzeForAI(source)
        else {
            status = "无法分析当前照片"
            return
        }
        settingsBeforeAI = settings
        settings.applyAI(analysis, intensity: aiIntensity)
        selectedPreset = .original
        showingOriginal = false
        aiSummaryKey = analysis.summaryKey
        aiAnalysis = analysis
        status = "AI 优化已应用 · 可继续微调"
    }

    private func undoAIEnhancement() {
        guard let previous = settingsBeforeAI else { return }
        settings = previous
        settingsBeforeAI = nil
        aiSummaryKey = "已撤销 AI 优化"
        status = "已恢复 AI 优化前的参数"
    }

    private func analyzeForAI(_ source: CIImage) -> EditorAIAnalysis? {
        let size = 96
        let normalizedSource = normalized(source)
        guard normalizedSource.extent.width > 0,
              normalizedSource.extent.height > 0
        else { return nil }
        let sample = normalizedSource.transformed(
            by: CGAffineTransform(
                scaleX: CGFloat(size) / normalizedSource.extent.width,
                y: CGFloat(size) / normalizedSource.extent.height
            )
        )
        var pixels = [UInt8](repeating: 0, count: size * size * 4)
        pixels.withUnsafeMutableBytes { buffer in
            guard let address = buffer.baseAddress else { return }
            context.render(
                sample,
                toBitmap: address,
                rowBytes: size * 4,
                bounds: CGRect(x: 0, y: 0, width: size, height: size),
                format: .RGBA8,
                colorSpace: CGColorSpaceCreateDeviceRGB()
            )
        }

        var lumas = [Double](repeating: 0, count: size * size)
        var red = 0.0
        var green = 0.0
        var blue = 0.0
        var saturation = 0.0
        var shadows = 0.0
        var highlights = 0.0
        for index in 0..<(size * size) {
            let offset = index * 4
            let r = Double(pixels[offset]) / 255
            let g = Double(pixels[offset + 1]) / 255
            let b = Double(pixels[offset + 2]) / 255
            let luma = r * 0.2126 + g * 0.7152 + b * 0.0722
            lumas[index] = luma
            red += r
            green += g
            blue += b
            saturation += max(r, g, b) - min(r, g, b)
            if luma < 0.10 { shadows += 1 }
            if luma > 0.90 { highlights += 1 }
        }
        let count = Double(size * size)
        let mean = lumas.reduce(0, +) / count
        let variance = lumas.reduce(0) { partial, value in
            partial + pow(value - mean, 2)
        } / count
        var detail = 0.0
        for y in 0..<size {
            for x in 1..<size {
                let index = y * size + x
                detail += abs(lumas[index] - lumas[index - 1])
            }
        }
        return EditorAIAnalysis(
            meanLuma: mean,
            contrast: sqrt(variance),
            shadowRatio: shadows / count,
            highlightRatio: highlights / count,
            saturation: saturation / count,
            red: red / count,
            green: green / count,
            blue: blue / count,
            detail: detail / Double(size * (size - 1))
        )
    }

    private func saveCopy() {
        let wasShowingOriginal = showingOriginal
        showingOriginal = false
        guard let selectedItem,
              let renderedImage,
              let data = renderedImage.jpegData(compressionQuality: 0.95)
        else {
            showingOriginal = wasShowingOriginal
            status = "无法渲染当前照片"
            return
        }
        isSaving = true
        if let saved = model.library.saveEditedImage(
            data,
            originalFilename: selectedItem.filename
        ) {
            selectedItemID = saved.path
            status = "已保存高质量副本 · \(saved.lastPathComponent)"
            resetAdjustments()
        } else {
            status = model.library.message
            showingOriginal = wasShowingOriginal
        }
        isSaving = false
    }
}

private struct EditorSectionButtonStyle: ButtonStyle {
    let selected: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(selected ? .white : IPalette.ink)
            .padding(.horizontal, 16)
            .frame(minHeight: 44)
            .background(
                selected ? IPalette.cobalt : IPalette.surface,
                in: Capsule()
            )
            .overlay {
                Capsule().stroke(
                    selected ? Color.clear : IPalette.rule
                )
            }
            .opacity(configuration.isPressed ? 0.72 : 1)
    }
}

private struct CapturePage: View {
    @EnvironmentObject private var model: AppModel
    @State private var showingFullscreen = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                PageTitle(
                    title: "照片拍摄",
                    subtitle: "会话、曝光、对焦与交付按拍摄流程组织。"
                )

                CaptureSessionCard()
                CameraStage {
                    showingFullscreen = true
                }
                ExposureReadoutRail()
                CaptureActionBar()
                CaptureParameterDeck()
                ShootingTaskCard()
            }
            .padding(20)
        }
        .fullScreenCover(isPresented: $showingFullscreen) {
            ImmersiveCameraView(mode: .photo)
        }
    }
}

private struct CameraStage: View {
    @EnvironmentObject private var model: AppModel
    var openFullscreen: (() -> Void)?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.black)

            if model.camera.state == .ready {
                CameraPreview(
                    session: model.camera.session,
                    focusHandler: { model.camera.focus(at: $0) }
                )
                .clipShape(RoundedRectangle(cornerRadius: 20))

                if model.section == .monitor,
                   let overlay = model.camera.monitorOverlay {
                    Image(decorative: overlay, scale: 1)
                        .resizable()
                        .scaledToFill()
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .allowsHitTesting(false)
                }

                if model.showGrid {
                    GridOverlay()
                        .stroke(Color.white.opacity(0.45), lineWidth: 0.7)
                        .allowsHitTesting(false)
                }
                if model.showSafeGuide {
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.yellow.opacity(0.65), style: StrokeStyle(lineWidth: 1, dash: [7]))
                        .padding(30)
                        .allowsHitTesting(false)
                }
            } else {
                VStack(spacing: 13) {
                    Image(systemName: "camera.viewfinder")
                        .font(.system(size: 46, weight: .light))
                        .foregroundStyle(IPalette.muted)
                    Text("等待相机画面")
                        .font(.title3.weight(.semibold))
                    Text("iPad 可接 UVC；iPhone 使用本机镜头。")
                        .font(.subheadline)
                        .foregroundStyle(IPalette.muted)
                        .multilineTextAlignment(.center)
                    Button("选择相机") {
                        model.showingConnection = true
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(30)
                .foregroundStyle(Color.white)
            }
        }
        .aspectRatio(16 / 10, contentMode: .fit)
        .overlay(alignment: .topLeading) {
            HStack(spacing: 7) {
                Circle()
                    .fill(model.camera.state == .ready ? Color.green : Color.red)
                    .frame(width: 7, height: 7)
                RuntimeLocalizedText(model.camera.deviceName)
                    .textCase(.uppercase)
                    .font(.caption2.monospaced().weight(.semibold))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .foregroundStyle(Color.white)
            .background(.black.opacity(0.55), in: Capsule())
            .padding(12)
        }
        .overlay(alignment: .topTrailing) {
            if let openFullscreen {
                Button(action: openFullscreen) {
                    Label("全屏", systemImage: "arrow.up.left.and.arrow.down.right")
                        .labelStyle(.iconOnly)
                        .font(.system(size: 16, weight: .semibold))
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.borderedProminent)
                .tint(.black.opacity(0.62))
                .foregroundStyle(.white)
                .padding(12)
                .accessibilityLabel("打开全屏取景")
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if model.section == .monitor, model.camera.state == .ready {
                Text("系统视频 · \(model.camera.activeVideoSpecLabel)")
                .font(.caption2.monospaced().weight(.semibold))
                .foregroundStyle(.white.opacity(0.78))
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(.black.opacity(0.55), in: Capsule())
                .padding(12)
            }
        }
    }
}

private struct ExposureReadoutRail: View {
    @EnvironmentObject private var model: AppModel

    private var connected: Bool { model.camera.state == .ready }
    private var modeValue: String {
        guard connected else { return "—" }
        return model.camera.exposureModeIsCustom ? "M" : "AUTO"
    }
    private var shutterValue: String {
        guard connected else { return "—" }
        return String(format: "%.1f°", model.camera.shutterAngle)
    }
    private var apertureValue: String {
        guard connected, model.camera.lensAperture > 0 else { return "—" }
        return String(format: "f/%.1f", model.camera.lensAperture)
    }
    private var isoValue: String {
        connected ? "\(Int(model.camera.exposureISO.rounded()))" : "—"
    }
    private var compensationValue: String {
        connected ? String(format: "%+.1f EV", model.camera.exposureBias) : "—"
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                cell(
                    "来源",
                    connected
                        ? (model.camera.isExternalCamera ? "UVC" : "SYSTEM")
                        : "—"
                )
                divider
                cell("模式", modeValue)
                divider
                cell(
                    "快门",
                    shutterValue,
                    writable: model.camera.supportsCustomExposure
                )
                divider
                cell("光圈", apertureValue)
                divider
                cell(
                    "ISO",
                    isoValue,
                    writable: model.camera.supportsCustomExposure
                )
                divider
                cell(
                    "曝光",
                    compensationValue,
                    writable: model.camera.supportsExposureBias,
                    minWidth: 118
                )
            }
            .padding(.horizontal, 8)
        }
        .frame(height: 82)
        .background(IPalette.graphite, in: RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.09))
            .frame(width: 1, height: 42)
    }

    private func cell(
        _ label: String,
        _ value: String,
        writable: Bool = false,
        minWidth: CGFloat = 96
    ) -> some View {
        let active = connected && writable
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                Text(LocalizedStringKey(label))
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.48))
                if connected && !writable && label != "来源" && label != "模式" {
                    Text(LocalizedStringKey("自动"))
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color.white.opacity(0.55))
                }
            }
            Text(connected ? value : "—")
                .font(.system(size: 22, weight: .semibold, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(active ? IPalette.readoutGlow : Color.white.opacity(0.88))
                .lineLimit(1)
        }
        .frame(minWidth: minWidth, alignment: .leading)
        .padding(.horizontal, 14)
    }
}

private enum ImmersiveCameraMode {
    case photo
    case video

    var title: String {
        self == .photo ? "照片" : "视频"
    }

    var accent: Color {
        self == .photo ? .blue : .red
    }
}

private struct ImmersiveCameraView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var showsParameters = true
    @State private var showsMoreParameters = false
    @State private var sensorLandscape: Bool?
    let mode: ImmersiveCameraMode

    var body: some View {
        GeometryReader { proxy in
            let landscape =
                sensorLandscape ?? (proxy.size.width > proxy.size.height)
            ZStack {
                Color.black.ignoresSafeArea()
                if model.camera.state == .ready {
                    CameraPreview(
                        session: model.camera.session,
                        focusHandler: { model.camera.focus(at: $0) }
                    )
                    .ignoresSafeArea()
                    if mode == .video,
                       let overlay = model.camera.monitorOverlay {
                        Image(decorative: overlay, scale: 1)
                            .resizable()
                            .scaledToFill()
                            .ignoresSafeArea()
                            .allowsHitTesting(false)
                    }
                } else {
                    ContentUnavailableView(
                        "等待相机画面",
                        systemImage: "camera.viewfinder",
                        description: Text("关闭全屏后连接相机并开启实时取景。")
                    )
                    .foregroundStyle(.white)
                }

                if model.showGrid {
                    GridOverlay()
                        .stroke(Color.white.opacity(0.42), lineWidth: 0.7)
                        .allowsHitTesting(false)
                }
                if model.showSafeGuide {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(
                            Color.yellow.opacity(0.72),
                            style: StrokeStyle(lineWidth: 1, dash: [8])
                        )
                        .padding(landscape ? 96 : 52)
                        .allowsHitTesting(false)
                }

                ImmersiveFocusReticle()
                    .stroke(Color.yellow.opacity(0.82), lineWidth: 2)
                    .frame(width: 82, height: 82)
                    .allowsHitTesting(false)

                if landscape {
                    VStack {
                        topBar
                        Spacer()
                        parameterBar
                        exposureReadout
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)

                    HStack {
                        leftRail
                        Spacer()
                        rightRail
                    }
                    .padding(.horizontal, 18)
                } else {
                    VStack {
                        portraitTopBar
                        Spacer()
                        parameterBar
                        exposureReadout
                        portraitCaptureShelf
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)

                    HStack {
                        leftRail
                        Spacer()
                    }
                    .padding(.leading, 14)
                    .padding(.bottom, 208)
                }
            }
            .preferredColorScheme(.dark)
        }
        .onAppear {
            UIDevice.current.beginGeneratingDeviceOrientationNotifications()
            updateSensorOrientation()
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: UIDevice.orientationDidChangeNotification
            )
        ) { _ in
            updateSensorOrientation()
        }
        .onDisappear {
            UIDevice.current.endGeneratingDeviceOrientationNotifications()
        }
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            Button {
                dismiss()
            } label: {
                Label("退出全屏", systemImage: "chevron.down")
                    .labelStyle(.iconOnly)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(ImmersiveControlStyle())

            HStack(spacing: 7) {
                Circle()
                    .fill(model.camera.state == .ready ? Color.green : Color.red)
                    .frame(width: 7, height: 7)
                RuntimeLocalizedText(model.camera.deviceName)
                    .lineLimit(1)
            }
            .font(.caption.monospaced().weight(.semibold))
            .padding(.horizontal, 12)
            .frame(height: 44)
            .background(.black.opacity(0.54), in: Capsule())

            Spacer()

            RuntimeLocalizedText(
                mode == .video
                    ? "\(model.camera.isRecording ? "● REC" : "系统视频") · \(model.camera.activeVideoSpecLabel)"
                    : "照片实时取景 · JPEG"
            )
                .font(.caption2.monospaced().weight(.semibold))
                .padding(.horizontal, 12)
                .frame(height: 44)
                .background(.black.opacity(0.54), in: Capsule())
        }
    }

    private var portraitTopBar: some View {
        HStack(spacing: 10) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "house")
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(ImmersiveControlStyle())
            .accessibilityLabel("退出全屏")

            HStack(spacing: 7) {
                Circle()
                    .fill(model.camera.state == .ready ? Color.green : Color.red)
                    .frame(width: 7, height: 7)
                RuntimeLocalizedText(model.camera.deviceName)
                    .lineLimit(1)
            }
            .font(.caption2.monospaced().weight(.semibold))
            .padding(.horizontal, 10)
            .frame(height: 44)
            .background(.black.opacity(0.58), in: Capsule())

            Spacer()

            Text(mode == .video ? model.camera.activeVideoSpecLabel : "JPEG")
                .font(.caption2.monospaced().weight(.bold))
                .padding(.horizontal, 10)
                .frame(height: 44)
                .background(.black.opacity(0.58), in: Capsule())
        }
    }

    private var leftRail: some View {
        VStack(spacing: 12) {
            Text(mode == .photo ? "M" : "\(Int(model.camera.activeFrameRate))P")
                .font(.title2.weight(.bold))
                .frame(width: 52, height: 52)
                .background(.black.opacity(0.58), in: RoundedRectangle(cornerRadius: 12))

            Button {
                model.camera.setZoomFactor(max(1, model.camera.zoomFactor - 0.5))
            } label: {
                Image(systemName: "minus.magnifyingglass")
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(ImmersiveControlStyle())
            .disabled(model.camera.maxZoomFactor <= 1)

            Text(String(format: "%.1f×", model.camera.zoomFactor))
                .font(.body.monospacedDigit())
                .frame(width: 58, height: 44)
                .background(.black.opacity(0.58), in: Capsule())

            Button {
                model.camera.setZoomFactor(
                    min(model.camera.maxZoomFactor, model.camera.zoomFactor + 0.5)
                )
            } label: {
                Image(systemName: "plus.magnifyingglass")
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(ImmersiveControlStyle())
            .disabled(model.camera.maxZoomFactor <= 1)
        }
        .foregroundStyle(.white)
    }

    private var rightRail: some View {
        VStack(spacing: 12) {
            RuntimeLocalizedText(mode.title)
                .font(.headline)
                .foregroundStyle(mode.accent)
            captureButton

            Button {
                model.showGrid.toggle()
            } label: {
                Image(systemName: "grid")
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(ImmersiveControlStyle(active: model.showGrid))

            Button {
                model.showSafeGuide.toggle()
            } label: {
                Image(systemName: "viewfinder")
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(ImmersiveControlStyle(active: model.showSafeGuide))
        }
    }

    private var portraitCaptureShelf: some View {
        VStack(spacing: 6) {
            RuntimeLocalizedText(mode.title)
                .font(.caption.weight(.bold))
                .foregroundStyle(mode.accent)
            HStack(spacing: 24) {
                Button {
                    model.showGrid.toggle()
                } label: {
                    Image(systemName: "grid")
                        .frame(width: 52, height: 52)
                }
                .buttonStyle(ImmersiveControlStyle(active: model.showGrid))

                captureButton

                Button {
                    model.showSafeGuide.toggle()
                } label: {
                    Image(systemName: "viewfinder")
                        .frame(width: 52, height: 52)
                }
                .buttonStyle(
                    ImmersiveControlStyle(active: model.showSafeGuide)
                )
            }
        }
        .padding(.top, 4)
    }

    private var captureButton: some View {
        Button {
            if mode == .video {
                model.camera.toggleVideoRecording()
            } else {
                model.camera.capturePhoto()
            }
        } label: {
            ZStack {
                Circle()
                    .fill(mode.accent)
                    .frame(width: 76, height: 76)
                Circle()
                    .stroke(.white.opacity(0.88), lineWidth: 3)
                    .frame(width: 88, height: 88)
                Image(
                    systemName: mode == .photo
                        ? "camera.fill"
                        : model.camera.isRecording ? "stop.fill" : "circle.fill"
                )
                    .font(.title2)
                    .foregroundStyle(.white)
            }
            .frame(width: 96, height: 96)
        }
        .buttonStyle(.plain)
        .disabled(
            model.camera.state != .ready
                || (mode == .video && !model.camera.supportsMovieRecording)
        )
        .accessibilityLabel(
            mode == .photo
                ? "拍摄照片"
                : model.camera.isRecording ? "停止录制" : "开始录制"
        )
    }

    private var exposureReadout: some View {
        HStack(spacing: 18) {
            Text(mode == .video
                 ? String(format: "%.1f°", model.camera.shutterAngle)
                 : "EV")
            Text(mode == .video
                 ? "ISO \(Int(model.camera.exposureISO.rounded()))"
                 : String(format: "%+.1f", model.camera.exposureBias))
            if model.camera.lensAperture > 0 {
                Text(String(format: "F%.1f", model.camera.lensAperture))
            }
        }
        .font(.body.monospaced().weight(.semibold))
        .foregroundStyle(.white.opacity(0.86))
        .padding(.horizontal, 16)
        .frame(height: 44)
        .background(.black.opacity(0.54), in: Capsule())
    }

    private var parameterBar: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Button {
                    showsParameters.toggle()
                } label: {
                    Label(
                        showsParameters ? "收起参数" : "展开参数",
                        systemImage: showsParameters ? "chevron.down" : "chevron.up"
                    )
                    .font(.caption.weight(.semibold))
                    .frame(minWidth: 96, minHeight: 44)
                }
                .buttonStyle(ImmersiveControlStyle())

                if showsParameters {
                    Button {
                        showsMoreParameters.toggle()
                    } label: {
                        Label(
                            showsMoreParameters ? "收起更多" : "更多参数",
                            systemImage: showsMoreParameters
                                ? "slider.horizontal.2.square.on.square"
                                : "slider.horizontal.3"
                        )
                        .font(.caption.weight(.semibold))
                        .frame(minWidth: 96, minHeight: 44)
                    }
                    .buttonStyle(
                        ImmersiveControlStyle(active: showsMoreParameters)
                    )
                }
            }

            if showsParameters {
                ScrollView(.horizontal, showsIndicators: false) {
                    primaryParameterControls
                    .padding(.horizontal, 2)
                }
                if showsMoreParameters {
                    ScrollView(.horizontal, showsIndicators: false) {
                        secondaryParameterControls
                            .padding(.horizontal, 2)
                    }
                    .transition(.opacity)
                }
            }
        }
        .disabled(model.camera.state != .ready)
        .padding(.bottom, 10)
    }

    @ViewBuilder
    private var primaryParameterControls: some View {
        HStack(spacing: 8) {
            if mode == .video {
                ImmersiveParameterStepper(
                    title: "快门角度",
                    value: String(format: "%.1f°", model.camera.shutterAngle),
                    enabled: model.camera.supportsCustomExposure,
                    lockedReason: "当前设备不支持自定义曝光",
                    decrease: { adjustVideoShutterAngle(-1) },
                    increase: { adjustVideoShutterAngle(1) }
                )
            } else {
                ImmersiveParameterStepper(
                    title: "曝光补偿",
                    value: String(format: "%+.1f EV", model.camera.exposureBias),
                    enabled: model.camera.supportsExposureBias,
                    lockedReason: "当前设备未开放曝光补偿",
                    decrease: { adjustExposureBias(-1) },
                    increase: { adjustExposureBias(1) }
                )
            }
            ImmersiveParameterStepper(
                title: "ISO",
                value: "\(Int(model.camera.exposureISO.rounded()))",
                enabled: model.camera.supportsCustomExposure,
                lockedReason: "当前设备未开放自定义 ISO",
                decrease: { adjustVideoISO(-1) },
                increase: { adjustVideoISO(1) }
            )
            ImmersiveParameterStepper(
                title: "光圈",
                value: model.camera.lensAperture > 0
                    ? String(format: "F%.1f", model.camera.lensAperture)
                    : "—",
                enabled: false,
                lockedReason: "AVFoundation 将镜头光圈报告为只读",
                decrease: {},
                increase: {}
            )
        }
    }

    @ViewBuilder
    private var secondaryParameterControls: some View {
        HStack(spacing: 8) {
            ImmersiveParameterStepper(
                title: "焦点位置",
                value: "微调",
                enabled: model.camera.state == .ready,
                lockedReason: "当前设备不支持焦点步进",
                decrease: { model.camera.moveFocus(-1) },
                increase: { model.camera.moveFocus(1) }
            )
            ImmersiveParameterStepper(
                title: "变焦",
                value: String(format: "%.1f×", model.camera.zoomFactor),
                enabled: model.camera.maxZoomFactor > 1,
                lockedReason: "当前设备没有可调变焦范围",
                decrease: { adjustZoom(-1) },
                increase: { adjustZoom(1) }
            )
            if mode == .video {
                ImmersiveParameterStepper(
                    title: "尺寸/帧率",
                    value: model.camera.activeVideoSpecLabel,
                    enabled: model.camera.state == .ready,
                    lockedReason: "当前设备没有可切换的视频规格",
                    decrease: { adjustVideoSpec(-1) },
                    increase: { adjustVideoSpec(1) }
                )
                ImmersiveParameterStepper(
                    title: "峰值对焦",
                    value: model.camera.focusPeakingEnabled ? "开启" : "关闭",
                    enabled: true,
                    decrease: {
                        model.camera.setFocusPeakingEnabled(false)
                    },
                    increase: {
                        model.camera.setFocusPeakingEnabled(true)
                    }
                )
                ImmersiveParameterStepper(
                    title: "假色曝光",
                    value: model.camera.falseColorEnabled ? "开启" : "关闭",
                    enabled: true,
                    decrease: {
                        model.camera.setFalseColorEnabled(false)
                    },
                    increase: {
                        model.camera.setFalseColorEnabled(true)
                    }
                )
            }
        }
    }

    private func adjustVideoShutterAngle(_ direction: Int) {
        let values = [
            45.0, 60.0, 72.0, 90.0, 108.0, 120.0, 144.0, 150.0,
            172.8, 180.0, 216.0, 240.0, 270.0, 300.0, 324.0, 360.0
        ]
        let current = values.enumerated().min {
            abs($0.element - model.camera.shutterAngle)
                < abs($1.element - model.camera.shutterAngle)
        }?.offset ?? 4
        let next = min(max(current + direction, 0), values.count - 1)
        model.camera.setVideoShutterAngle(values[next])
    }

    private func adjustVideoISO(_ direction: Int) {
        let values = [
            64, 80, 100, 125, 160, 200, 250, 320, 400, 500, 640,
            800, 1000, 1250, 1600, 2000, 2500, 3200, 4000, 5000,
            6400, 8000, 10000, 12800, 16000, 20000, 25600, 32000,
            40000, 51200, 64000, 80000, 102400
        ]
            .filter {
                Float($0) >= model.camera.minISO
                    && Float($0) <= model.camera.maxISO
            }
        guard !values.isEmpty else { return }
        let current = values.enumerated().min {
            abs(Float($0.element) - model.camera.exposureISO)
                < abs(Float($1.element) - model.camera.exposureISO)
        }?.offset ?? 0
        let next = min(max(current + direction, 0), values.count - 1)
        model.camera.setVideoISO(Float(values[next]))
    }

    private func adjustExposureBias(_ direction: Int) {
        let requested = model.camera.exposureBias + Float(direction) / 3
        model.camera.setExposureBias(
            min(max(requested, model.camera.minExposureBias), model.camera.maxExposureBias)
        )
    }

    private func adjustZoom(_ direction: Int) {
        model.camera.setZoomFactor(
            min(
                max(1, model.camera.zoomFactor + CGFloat(direction) * 0.5),
                model.camera.maxZoomFactor
            )
        )
    }

    private func adjustVideoSpec(_ direction: Int) {
        let values = MonitorVideoSpec.allCases
        guard let current = values.firstIndex(of: model.monitorVideoSpec) else {
            return
        }
        let next = min(max(current + direction, 0), values.count - 1)
        model.setMonitorVideoSpec(values[next])
    }

    private func updateSensorOrientation() {
        let orientation = UIDevice.current.orientation
        if orientation.isLandscape {
            sensorLandscape = true
        } else if orientation.isPortrait {
            sensorLandscape = false
        }
    }
}

private struct ImmersiveFocusReticle: Shape {
    func path(in rect: CGRect) -> Path {
        let arm = min(rect.width, rect.height) * 0.24
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY + arm))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX + arm, y: rect.minY))
        path.move(to: CGPoint(x: rect.maxX - arm, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + arm))
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY - arm))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + arm, y: rect.maxY))
        path.move(to: CGPoint(x: rect.maxX - arm, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - arm))
        return path
    }
}

private struct ImmersiveParameterStepper: View {
    let title: String
    let value: String
    var enabled = true
    var lockedReason: String?
    let decrease: () -> Void
    let increase: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Button(action: decrease) {
                Image(systemName: "minus")
                    .frame(width: 44, height: 44)
            }
            VStack(spacing: 1) {
                Text(LocalizedStringKey(title))
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.64))
                Text(value)
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .frame(width: 58)
            Button(action: increase) {
                Image(systemName: "plus")
                    .frame(width: 44, height: 44)
            }
        }
        .buttonStyle(ImmersiveControlStyle())
        .padding(2)
        .background(.black.opacity(0.54), in: RoundedRectangle(cornerRadius: 10))
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.48)
        .accessibilityHint(enabled ? "" : (lockedReason ?? "当前不可调整"))
    }
}

private struct ImmersiveControlStyle: ButtonStyle {
    var active = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.white)
            .background(
                active ? Color.blue.opacity(0.78) : Color.black.opacity(0.58),
                in: RoundedRectangle(cornerRadius: 12)
            )
            .opacity(configuration.isPressed ? 0.68 : 1)
    }
}

private struct CaptureActionBar: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) {
                captureButton
                guideToggles
            }
            VStack(spacing: 12) {
                captureButton
                guideToggles
            }
        }
    }

    private var captureButton: some View {
        Button {
            model.camera.capturePhoto()
        } label: {
            Label("拍摄", systemImage: "camera.fill")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
        }
        .buttonStyle(.borderedProminent)
        .disabled(model.camera.state != .ready)
    }

    private var guideToggles: some View {
        HStack(spacing: 10) {
            Toggle("网格", isOn: $model.showGrid)
                .toggleStyle(.button)
            Toggle("安全框", isOn: $model.showSafeGuide)
                .toggleStyle(.button)
        }
        .fixedSize(horizontal: true, vertical: false)
    }
}

private struct CaptureParameterDeck: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("拍摄控制")
                .font(.headline)

            Label("曝光", systemImage: "camera.aperture")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(IPalette.muted)
            VStack(alignment: .leading, spacing: 9) {
                HStack {
                    Label("曝光补偿", systemImage: "plusminus")
                    Spacer()
                    Text(String(format: "%+.1f EV", model.camera.exposureBias))
                        .monospacedDigit()
                        .foregroundStyle(.blue)
                }
                Slider(
                    value: Binding(
                        get: { Double(model.camera.exposureBias) },
                        set: { model.camera.setExposureBias(Float($0)) }
                    ),
                    in: Double(model.camera.minExposureBias)...Double(model.camera.maxExposureBias),
                    step: 0.1
                )
                .disabled(model.camera.state != .ready || !model.camera.supportsExposureBias)
            }

            Divider()
            Label("对焦与构图", systemImage: "viewfinder")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(IPalette.muted)
            VStack(alignment: .leading, spacing: 9) {
                HStack {
                    Label("本机镜头变焦", systemImage: "plus.magnifyingglass")
                    Spacer()
                    Text(String(format: "%.1f×", model.camera.zoomFactor))
                        .monospacedDigit()
                        .foregroundStyle(.blue)
                }
                Slider(
                    value: Binding(
                        get: { Double(model.camera.zoomFactor) },
                        set: { model.camera.setZoomFactor(CGFloat($0)) }
                    ),
                    in: 1...max(1.1, Double(model.camera.maxZoomFactor)),
                    step: 0.1
                )
                .disabled(model.camera.state != .ready || model.camera.maxZoomFactor <= 1)
            }

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 110), spacing: 10)],
                alignment: .leading,
                spacing: 10
            ) {
                CapabilityChip(
                    title: "点按对焦",
                    available: model.camera.supportsFocusPoint
                )
                CapabilityChip(
                    title: "曝光控制",
                    available: model.camera.supportsExposureBias
                )
            }

        }
        .padding(18)
        .background(IPalette.surface, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(IPalette.rule, lineWidth: 0.5))
        .shadow(color: IPalette.shadow, radius: 12, y: 6)
    }
}

private struct ShootingTaskCard: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("拍摄自动化")
                .font(.headline)
            Text("间隔、包围与 B 门任务集中管理")
                .font(.subheadline)
                .foregroundStyle(IPalette.muted)
            Picker("任务类型", selection: $model.shootingTaskKind) {
                ForEach(ShootingTaskKind.allCases) { kind in
                    Text(kind.rawValue).tag(kind)
                }
            }
            .pickerStyle(.segmented)
            Stepper(
                "张数 · \(model.shootingTaskCount)",
                value: $model.shootingTaskCount,
                in: 1...999
            )
            Stepper(
                model.shootingTaskKind == .bulb
                    ? "曝光时长 · \(model.shootingTaskInterval) 秒"
                    : "间隔 · \(model.shootingTaskInterval) 秒",
                value: $model.shootingTaskInterval,
                in: 1...3600
            )
            if model.shootingTaskKind == .exposureBracket
                || model.shootingTaskKind == .focusBracket {
                Stepper(
                    model.shootingTaskKind == .exposureBracket
                        ? "包围步长 · \(model.shootingTaskStep) EV"
                        : "焦点步长 · \(model.shootingTaskStep)",
                    value: $model.shootingTaskStep,
                    in: 1...3
                )
            }
            RuntimeLocalizedText(model.shootingTaskStatus)
                .font(.caption.monospaced())
                .foregroundStyle(IPalette.muted)
            Button {
                if model.shootingTaskRunning {
                    model.cancelShootingTask()
                } else {
                    model.startShootingTask()
                }
            } label: {
                Label(
                    model.shootingTaskRunning ? "取消任务" : "开始任务",
                    systemImage: model.shootingTaskRunning
                        ? "xmark.circle.fill"
                        : "camera.badge.clock"
                )
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(model.camera.state != .ready && !model.shootingTaskRunning)
        }
        .padding(18)
        .background(IPalette.surface, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(IPalette.rule, lineWidth: 0.5))
        .shadow(color: IPalette.shadow, radius: 12, y: 6)
    }
}

private struct CapabilityChip: View {
    let title: String
    let available: Bool

    var body: some View {
        HStack(spacing: 5) {
            Image(
                systemName: available
                    ? "checkmark.circle.fill"
                    : "minus.circle"
            )
            RuntimeLocalizedText(title)
        }
            .font(.caption.weight(.medium))
            .foregroundStyle(available ? Color.green : Color.secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Color.white.opacity(0.05), in: Capsule())
    }
}

private struct MonitorPage: View {
    @EnvironmentObject private var model: AppModel
    @State private var showingFullscreen = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                PageTitle(
                    title: "视频监看",
                    subtitle: "系统视频设备预览、监看参数与输出规格。",
                    accent: IPalette.video
                )
                CameraStage {
                    showingFullscreen = true
                }
                MonitorRecordingBar()
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 280), spacing: 14)],
                    alignment: .leading,
                    spacing: 14
                ) {
                    MonitorParameterDeck()
                    MonitorOutputDeck()
                }
            }
            .padding(20)
        }
        .fullScreenCover(isPresented: $showingFullscreen) {
            ImmersiveCameraView(mode: .video)
        }
    }
}

private struct MonitorRecordingBar: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Button {
            model.camera.toggleVideoRecording()
        } label: {
            Label(
                model.camera.isRecording ? "停止录制" : "开始录制",
                systemImage: model.camera.isRecording ? "stop.fill" : "record.circle"
            )
            .font(.headline)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
        }
        .buttonStyle(.borderedProminent)
        .tint(.red)
        .disabled(
            model.camera.state != .ready
                || !model.camera.supportsMovieRecording
        )
    }
}

private struct MonitorParameterDeck: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("参数调节")
                .font(.headline)
            Text("按当前视频设备公开的能力调整。")
                .font(.subheadline)
                .foregroundStyle(IPalette.muted)

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("快门角度", systemImage: "circle.lefthalf.filled")
                    Spacer()
                    Text(String(format: "%.1f° · %.0fp", model.camera.shutterAngle, model.camera.activeFrameRate))
                        .monospacedDigit()
                        .foregroundStyle(.red)
                }
                Picker(
                    "快门角度",
                    selection: Binding(
                        get: {
                            let options = [45.0, 90.0, 144.0, 172.8, 180.0, 270.0, 360.0]
                            return options.min {
                                abs($0 - model.camera.shutterAngle)
                                    < abs($1 - model.camera.shutterAngle)
                            } ?? 180
                        },
                        set: { model.camera.setVideoShutterAngle($0) }
                    )
                ) {
                    ForEach([45.0, 90.0, 144.0, 172.8, 180.0, 270.0, 360.0], id: \.self) {
                        Text(String(format: "%.1f°", $0)).tag($0)
                    }
                }
                .pickerStyle(.segmented)
                .disabled(model.camera.state != .ready || !model.camera.supportsCustomExposure)
                if !model.camera.supportsCustomExposure {
                    Text("当前设备未通过 AVFoundation 提供自定义曝光；快门角度和 ISO 保持只读。")
                        .font(.caption)
                        .foregroundStyle(IPalette.muted)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("ISO 感光度", systemImage: "camera.metering.center.weighted")
                    Spacer()
                    Text("ISO \(Int(model.camera.exposureISO.rounded()))")
                        .monospacedDigit()
                        .foregroundStyle(.red)
                }
                Slider(
                    value: Binding(
                        get: { Double(model.camera.exposureISO) },
                        set: { model.camera.setVideoISO(Float($0)) }
                    ),
                    in: Double(model.camera.minISO)...Double(
                        max(model.camera.minISO + 1, model.camera.maxISO)
                    ),
                    step: 1
                )
                .disabled(model.camera.state != .ready || !model.camera.supportsCustomExposure)
            }

            LabeledContent {
                Text(
                    model.camera.lensAperture > 0
                        ? String(format: "f/%.1f", model.camera.lensAperture)
                        : "—"
                )
                .monospacedDigit()
            } label: {
                Label("光圈", systemImage: "camera.aperture")
            }
            Text("AVFoundation 仅公开当前镜头光圈读数，不允许应用直接改写；请在镜头或相机端调整。")
                .font(.caption)
                .foregroundStyle(IPalette.muted)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("曝光补偿", systemImage: "plusminus")
                    Spacer()
                    Text(String(format: "%+.1f EV", model.camera.exposureBias))
                        .monospacedDigit()
                        .foregroundStyle(.blue)
                }
                Slider(
                    value: Binding(
                        get: { Double(model.camera.exposureBias) },
                        set: { model.camera.setExposureBias(Float($0)) }
                    ),
                    in: Double(model.camera.minExposureBias)...Double(model.camera.maxExposureBias),
                    step: 0.1
                )
                .disabled(model.camera.state != .ready || !model.camera.supportsExposureBias)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("本机镜头变焦", systemImage: "plus.magnifyingglass")
                    Spacer()
                    Text(String(format: "%.1f×", model.camera.zoomFactor))
                        .monospacedDigit()
                        .foregroundStyle(.blue)
                }
                Slider(
                    value: Binding(
                        get: { Double(model.camera.zoomFactor) },
                        set: { model.camera.setZoomFactor(CGFloat($0)) }
                    ),
                    in: 1...max(1.1, Double(model.camera.maxZoomFactor)),
                    step: 0.1
                )
                .disabled(model.camera.state != .ready || model.camera.maxZoomFactor <= 1)
            }

            HStack {
                Toggle("取景网格", isOn: $model.showGrid)
                Spacer()
                Toggle("安全区域辅助线", isOn: $model.showSafeGuide)
            }
            .toggleStyle(.switch)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 16))
    }
}

private struct MonitorOutputDeck: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("系统视频输出")
                .font(.headline)

            Picker(
                "输出编码偏好",
                selection: Binding(
                    get: { model.monitorVideoCodec },
                    set: { model.setMonitorVideoCodec($0) }
                )
            ) {
                ForEach(MonitorVideoCodec.allCases) { codec in
                    Text(codec.label).tag(codec)
                }
            }

            Picker(
                "采集画面尺寸/帧频",
                selection: Binding(
                    get: { model.monitorVideoSpec },
                    set: { model.setMonitorVideoSpec($0) }
                )
            ) {
                ForEach(MonitorVideoSpec.allCases) { spec in
                    Text(spec.label).tag(spec)
                }
            }

            Toggle(
                "峰值对焦",
                isOn: Binding(
                    get: { model.camera.focusPeakingEnabled },
                    set: { model.camera.setFocusPeakingEnabled($0) }
                )
            )
            Toggle(
                "假色曝光",
                isOn: Binding(
                    get: { model.camera.falseColorEnabled },
                    set: { model.camera.setFalseColorEnabled($0) }
                )
            )

            VStack(alignment: .leading, spacing: 6) {
                scopeRow("R", value: model.camera.redHistogram, color: .red)
                scopeRow("G", value: model.camera.greenHistogram, color: .green)
                scopeRow("B", value: model.camera.blueHistogram, color: .blue)
                scopeRow("波形", value: model.camera.waveform, color: .primary)
                scopeRow("矢量", value: model.camera.vectorscope, color: .primary)
                Text("峰值覆盖 · \(model.camera.peakingCoverage)%")
                    .font(.caption.monospaced())
                    .foregroundStyle(IPalette.muted)
            }
            .padding(12)
            .background(Color.black.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))

            Text("画面尺寸/帧频会切换 AVFoundation 的采集格式；编码仅保存为输出偏好，不改变实时取景输入，也不会修改 Nikon 机身的视频文件类型。")
                .font(.caption)
                .foregroundStyle(IPalette.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 16))
    }

    private func scopeRow(_ label: String, value: String, color: Color) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(label)
                .font(.caption.weight(.bold))
                .foregroundStyle(color)
                .frame(width: 30, alignment: .leading)
            Text(value)
                .font(.caption2.monospaced())
                .lineLimit(1)
                .minimumScaleFactor(0.55)
        }
    }
}

private struct CaptureSessionCard: View {
    @EnvironmentObject private var model: AppModel
    @State private var name = "未命名会话"
    @State private var namingTemplate = "{session}_{date}_{counter}"
    @State private var creator = ""
    @State private var rights = ""
    @State private var rating = 0
    @State private var dualBackupEnabled = true

    var body: some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: 12) {
                TextField("项目名称", text: $name)
                TextField("命名模板", text: $namingTemplate)
                    .font(.body.monospaced())
                HStack {
                    TextField("创作者", text: $creator)
                    TextField("版权", text: $rights)
                }
                Stepper("默认评级 · \(rating) 星", value: $rating, in: 0...5)
                Toggle("双目标备份", isOn: $dualBackupEnabled)
                Text("支持 {session}、{date}、{counter}、{camera}；RAW + JPEG 使用同一基础文件名，并写入 XMP 与 SHA-256 清单。")
                    .font(.caption)
                    .foregroundStyle(IPalette.muted)
                HStack {
                    RuntimeLocalizedText(model.captureWorkflow.status)
                        .font(.caption.monospaced())
                        .foregroundStyle(IPalette.muted)
                    Spacer()
                    Button(model.captureWorkflow.isActive ? "结束会话" : "开始会话") {
                        toggleSession()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(.top, 12)
        } label: {
            Label(
                "拍前会话与交付",
                systemImage: model.captureWorkflow.isActive
                    ? "folder.badge.gearshape"
                    : "folder.badge.plus"
            )
            .font(.headline)
        }
        .padding(18)
        .background(IPalette.surface, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(IPalette.rule, lineWidth: 0.5))
        .shadow(color: IPalette.shadow, radius: 12, y: 6)
        .onAppear(perform: loadConfiguration)
    }

    private func loadConfiguration() {
        let configuration = model.captureWorkflow.configuration
        name = configuration.name
        namingTemplate = configuration.namingTemplate
        creator = configuration.creator
        rights = configuration.rights
        rating = configuration.rating
        dualBackupEnabled = configuration.dualBackupEnabled
    }

    private func toggleSession() {
        if model.captureWorkflow.isActive {
            model.captureWorkflow.end()
            return
        }
        do {
            try model.captureWorkflow.begin(
                CaptureSessionConfiguration(
                    name: name,
                    namingTemplate: namingTemplate,
                    creator: creator,
                    rights: rights,
                    rating: rating,
                    dualBackupEnabled: dualBackupEnabled
                )
            )
        } catch {
            model.statusMessage = "无法开始拍摄会话：\(error.localizedDescription)"
        }
    }
}

private struct UserLibraryBranch: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var children: [UserLibraryBranch]

    init(id: UUID = UUID(), name: String, children: [UserLibraryBranch] = []) {
        self.id = id
        self.name = name
        self.children = children
    }
}

@MainActor
private final class LibraryBranchStore: ObservableObject {
    @Published private(set) var branches: [UserLibraryBranch] = []
    @Published private(set) var expandedIDs: Set<UUID> = []
    @Published private(set) var assignments: [String: UUID] = [:]

    private static let storageKey = "zenche.library.user-branches"
    private static let assignmentStorageKey =
        "zenche.library.file-branch-assignments"

    init() {
        if let data = UserDefaults.standard.data(
            forKey: Self.storageKey
        ),
        let saved = try? JSONDecoder().decode(
            [UserLibraryBranch].self,
            from: data
        ) {
            branches = saved
            expandedIDs = Set(saved.map(\.id))
        }
        if let data = UserDefaults.standard.data(
            forKey: Self.assignmentStorageKey
        ),
        let saved = try? JSONDecoder().decode(
            [String: UUID].self,
            from: data
        ) {
            assignments = saved
        }
    }

    func addBranch(named rawName: String, parentID: UUID?) {
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        let branch = UserLibraryBranch(name: name)
        if let parentID {
            var updated = branches
            guard insert(branch, under: parentID, in: &updated) else {
                return
            }
            branches = updated
            expandedIDs.insert(parentID)
        } else {
            branches.append(branch)
        }
        expandedIDs.insert(branch.id)
        persist()
    }

    func toggle(_ id: UUID) {
        if expandedIDs.contains(id) {
            expandedIDs.remove(id)
        } else {
            expandedIDs.insert(id)
        }
    }

    func branchID(for itemID: String) -> UUID? {
        assignments[itemID]
    }

    func assign(_ itemID: String, to branchID: UUID?) {
        if let branchID {
            assignments[itemID] = branchID
            expandedIDs.insert(branchID)
        } else {
            assignments.removeValue(forKey: itemID)
        }
        persistAssignments()
    }

    func deleteBranch(_ id: UUID) {
        var updated = branches
        guard let removed = removeBranch(id, from: &updated) else {
            return
        }
        let removedIDs = branchIDs(in: removed)
        branches = updated
        expandedIDs.subtract(removedIDs)
        assignments = assignments.filter {
            !removedIDs.contains($0.value)
        }
        persist()
        persistAssignments()
    }

    private func insert(
        _ branch: UserLibraryBranch,
        under parentID: UUID,
        in nodes: inout [UserLibraryBranch]
    ) -> Bool {
        for index in nodes.indices {
            if nodes[index].id == parentID {
                nodes[index].children.append(branch)
                return true
            }
            if insert(branch, under: parentID, in: &nodes[index].children) {
                return true
            }
        }
        return false
    }

    private func removeBranch(
        _ id: UUID,
        from nodes: inout [UserLibraryBranch]
    ) -> UserLibraryBranch? {
        if let index = nodes.firstIndex(where: { $0.id == id }) {
            return nodes.remove(at: index)
        }
        for index in nodes.indices {
            if let removed = removeBranch(id, from: &nodes[index].children) {
                return removed
            }
        }
        return nil
    }

    private func branchIDs(in branch: UserLibraryBranch) -> Set<UUID> {
        branch.children.reduce(into: Set([branch.id])) { ids, child in
            ids.formUnion(branchIDs(in: child))
        }
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(branches) else { return }
        UserDefaults.standard.set(data, forKey: Self.storageKey)
    }

    private func persistAssignments() {
        guard let data = try? JSONEncoder().encode(assignments) else { return }
        UserDefaults.standard.set(data, forKey: Self.assignmentStorageKey)
    }
}

private struct LibraryBranchRow: View {
    @ObservedObject var store: LibraryBranchStore
    let branch: UserLibraryBranch
    let depth: Int
    let items: [LibraryItem]
    let selectedItemID: LibraryItem.ID?
    let addChild: (UserLibraryBranch) -> Void
    let deleteBranch: (UserLibraryBranch) -> Void
    let selectItem: (LibraryItem) -> Void
    let previewItem: (LibraryItem) -> Void
    @State private var isDropTarget = false

    private var assignedItems: [LibraryItem] {
        items.filter { store.branchID(for: $0.id) == branch.id }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Button {
                    store.toggle(branch.id)
                } label: {
                    HStack(spacing: 10) {
                        Image(
                            systemName: store.expandedIDs.contains(branch.id)
                                ? "chevron.down"
                                : "chevron.right"
                        )
                        .frame(width: 28)
                        Label(branch.name, systemImage: "folder")
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)
                        Spacer()
                        Text("\(assignedItems.count) 文件")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(IPalette.muted)
                    }
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(
                    store.expandedIDs.contains(branch.id)
                        ? "收起 \(branch.name)"
                        : "展开 \(branch.name)"
                )
                Button {
                    addChild(branch)
                } label: {
                    Image(systemName: "folder.badge.plus")
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("在 \(branch.name) 下新建分支")
                Button(role: .destructive) {
                    deleteBranch(branch)
                } label: {
                    Image(systemName: "trash")
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("删除分支 \(branch.name)")
            }
            .frame(minHeight: 52)
            .padding(.leading, CGFloat(depth) * 16)
            .background(
                isDropTarget
                    ? IPalette.cobaltSoft
                    : IPalette.paperSecondary.opacity(
                        depth == 0 ? 0.64 : 0.36
                    ),
                in: RoundedRectangle(cornerRadius: 10)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .stroke(
                        isDropTarget ? IPalette.cobalt : IPalette.rule,
                        lineWidth: isDropTarget ? 2 : 0.5
                    )
            }
            .dropDestination(for: String.self) { itemIDs, _ in
                guard !itemIDs.isEmpty else { return false }
                itemIDs.forEach { store.assign($0, to: branch.id) }
                return true
            } isTargeted: {
                isDropTarget = $0
            }

            if store.expandedIDs.contains(branch.id) {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(assignedItems) { item in
                        LibraryBranchFileRow(
                            item: item,
                            selected: selectedItemID == item.id,
                            depth: depth + 1,
                            selectItem: selectItem,
                            previewItem: previewItem
                        )
                    }
                    if assignedItems.isEmpty && branch.children.isEmpty {
                        Text("拖动文件到这里")
                            .font(.caption)
                            .foregroundStyle(IPalette.muted)
                            .padding(.leading, CGFloat(depth + 1) * 16 + 44)
                            .frame(minHeight: 32, alignment: .leading)
                    }
                    ForEach(branch.children) { child in
                        LibraryBranchRow(
                            store: store,
                            branch: child,
                            depth: depth + 1,
                            items: items,
                            selectedItemID: selectedItemID,
                            addChild: addChild,
                            deleteBranch: deleteBranch,
                            selectItem: selectItem,
                            previewItem: previewItem
                        )
                    }
                }
                .overlay(alignment: .leading) {
                    Rectangle()
                        .fill(IPalette.rule)
                        .frame(width: 1)
                        .padding(.leading, CGFloat(depth + 1) * 16 + 20)
                }
            }
        }
    }
}

private struct LibraryBranchFileRow: View {
    let item: LibraryItem
    let selected: Bool
    let depth: Int
    let selectItem: (LibraryItem) -> Void
    let previewItem: (LibraryItem) -> Void

    private var thumbnail: UIImage? {
        guard !item.isVideo else { return nil }
        return UIImage(contentsOfFile: item.url.path)
    }

    var body: some View {
        HStack(spacing: 10) {
            Group {
                if item.isVideo {
                    ZStack {
                        IPalette.graphite
                        Image(systemName: "play.fill")
                            .foregroundStyle(.white)
                    }
                } else if let thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .scaledToFill()
                } else {
                    ZStack {
                        IPalette.paperSecondary
                        Image(systemName: "photo")
                            .foregroundStyle(IPalette.cobalt)
                    }
                }
            }
            .frame(width: 68, height: 48)
            .clipShape(RoundedRectangle(cornerRadius: 7))
            Text(item.filename)
                .font(.caption.monospaced())
                .lineLimit(1)
            Spacer()
            Image(systemName: "line.3.horizontal")
                .foregroundStyle(IPalette.muted)
                .accessibilityHidden(true)
        }
        .padding(.leading, CGFloat(depth) * 16 + 28)
        .padding(.trailing, 12)
        .frame(minHeight: 58)
        .background(
            selected ? IPalette.cobaltSoft : IPalette.surface,
            in: RoundedRectangle(cornerRadius: 9)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 9)
                .stroke(selected ? IPalette.cobalt : IPalette.rule)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            selectItem(item)
        }
        .onTapGesture(count: 2) {
            selectItem(item)
            previewItem(item)
        }
        .draggable(item.id) {
            Label(item.filename, systemImage: "arrow.up.and.down.and.arrow.left.and.right")
                .font(.caption.weight(.semibold))
                .padding(10)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
        }
        .accessibilityHint("长按并拖动到其他分支")
    }
}

private struct LibraryPage: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @StateObject private var branchStore = LibraryBranchStore()
    @State private var showingCloudImporter = false
    @State private var showingCloudGuide = false
    @State private var showingBranchCreator = false
    @State private var branchDraft = ""
    @State private var branchParentID: UUID?
    @State private var branchParentName = "帧澈 ZENCHE 文件库"
    @State private var branchPendingDeletion: UserLibraryBranch?
    @State private var mobileBranchDrawerExpanded = false
    @State private var previewItem: LibraryItem?
    @State private var systemPreviewItem: SystemAlbumItem?
    @State private var systemAlbumItems: [SystemAlbumItem] = []
    @State private var systemAlbumStatus = "正在读取系统相册…"
    @State private var systemAlbumExpanded = true
    @State private var systemPhotosExpanded = true
    @State private var systemVideosExpanded = true
    @State private var wirelessExpanded = false
    @State private var uncategorizedExpanded = true
    @State private var localPhotosExpanded = true
    @State private var localVideosExpanded = true
    @State private var unclassifiedDropTargeted = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    PageTitle(
                        title: "分支文件库",
                        subtitle: "\(model.library.items.count) 个本地文件 · 拖动整理，不改动原文件"
                    )
                    Spacer()
                    Button {
                        Task { await loadSystemAlbum() }
                    } label: {
                        Label("刷新相册", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.bordered)
                    Button {
                        showingCloudGuide = true
                    } label: {
                        Label("链接网盘", systemImage: "externaldrive.connected.to.line.below")
                    }
                    .buttonStyle(.bordered)
                }

                branchWorkspace
                DisclosureGroup(isExpanded: $systemAlbumExpanded) {
                    if systemAlbumItems.isEmpty {
                        ContentUnavailableView(
                            "系统相册暂不可见",
                            systemImage: "photo.on.rectangle",
                            description: Text("允许照片访问后，照片和视频会直接显示在文件页，无需先导入。")
                        )
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 180)
                    } else {
                        DisclosureGroup(
                            "照片 · \(systemAlbumItems.filter { !$0.isVideo }.count)",
                            isExpanded: $systemPhotosExpanded
                        ) {
                            systemAlbumGrid(systemAlbumItems.filter { !$0.isVideo })
                        }
                        DisclosureGroup(
                            "视频 · \(systemAlbumItems.filter(\.isVideo).count)",
                            isExpanded: $systemVideosExpanded
                        ) {
                            systemAlbumGrid(systemAlbumItems.filter(\.isVideo))
                        }
                    }
                    Text("系统相册内容保持在原位置；帧澈 ZENCHE 只读取缩略图和预览。")
                        .font(.caption)
                        .foregroundStyle(IPalette.muted)
                } label: {
                    Label(
                        "系统相册 · \(systemAlbumItems.count)",
                        systemImage: "photo.on.rectangle"
                    )
                    .font(.headline)
                }

                DisclosureGroup(isExpanded: $wirelessExpanded) {
                    WirelessTransferCard()
                } label: {
                    Label("无线传输", systemImage: "antenna.radiowaves.left.and.right")
                        .font(.headline)
                }
            }
            .padding(20)
        }
        .task {
            await loadSystemAlbum()
        }
        .fileImporter(
            isPresented: $showingCloudImporter,
            allowedContentTypes: [
                .image,
                .movie,
                UTType(filenameExtension: "nef") ?? .data,
                UTType(filenameExtension: "nrw") ?? .data
            ],
            allowsMultipleSelection: true
        ) { result in
            if case .success(let urls) = result {
                model.library.importFiles(urls)
            }
        }
        .sheet(isPresented: $showingCloudGuide) {
            CloudDriveGuideView {
                showingCloudGuide = false
                DispatchQueue.main.async {
                    showingCloudImporter = true
                }
            }
        }
        .alert(
            "新建分支",
            isPresented: $showingBranchCreator
        ) {
            TextField("分支名称", text: $branchDraft)
            Button("取消", role: .cancel) {}
            Button("创建") {
                branchStore.addBranch(
                    named: branchDraft,
                    parentID: branchParentID
                )
            }
            .disabled(
                branchDraft.trimmingCharacters(
                    in: .whitespacesAndNewlines
                ).isEmpty
            )
        } message: {
            Text("将在“\(branchParentName)”下创建可继续展开的节点。")
        }
        .confirmationDialog(
            "删除分支？",
            isPresented: Binding(
                get: { branchPendingDeletion != nil },
                set: {
                    if !$0 {
                        branchPendingDeletion = nil
                    }
                }
            ),
            titleVisibility: .visible
        ) {
            Button("删除分支", role: .destructive) {
                if let branchPendingDeletion {
                    branchStore.deleteBranch(branchPendingDeletion.id)
                }
                branchPendingDeletion = nil
            }
            Button("取消", role: .cancel) {
                branchPendingDeletion = nil
            }
        } message: {
            Text(
                "将同时删除“\(branchPendingDeletion?.name ?? "")”下的子分支；其中的文件会回到“未分类”，原文件不受影响。"
            )
        }
        .fullScreenCover(item: $previewItem) { item in
            LibraryLargePhotoView(item: item)
        }
        .fullScreenCover(item: $systemPreviewItem) { item in
            SystemAlbumPreviewView(item: item)
        }
    }

    private func beginCreatingBranch(parent: UserLibraryBranch?) {
        branchParentID = parent?.id
        branchParentName = parent?.name ?? "帧澈 ZENCHE 文件库"
        branchDraft = ""
        showingBranchCreator = true
    }

    private var unclassifiedItems: [LibraryItem] {
        model.library.items.filter {
            branchStore.branchID(for: $0.id) == nil
        }
    }

    @ViewBuilder
    private var branchWorkspace: some View {
        if horizontalSizeClass == .compact {
            VStack(alignment: .leading, spacing: 10) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        mobileBranchDrawerExpanded.toggle()
                    }
                } label: {
                    HStack(spacing: 12) {
                        Image(
                            systemName: mobileBranchDrawerExpanded
                                ? "chevron.down"
                                : "chevron.right"
                        )
                        .frame(width: 28)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("分支抽屉")
                                .font(.headline)
                            Text(
                                "\(branchStore.branches.count) 个根分支 · \(unclassifiedItems.count) 个未分类文件"
                            )
                            .font(.caption)
                            .foregroundStyle(IPalette.muted)
                        }
                        Spacer()
                        Image(systemName: "square.stack.3d.up.fill")
                            .foregroundStyle(IPalette.cobalt)
                    }
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if mobileBranchDrawerExpanded {
                    branchWorkspaceContent
                        .transition(
                            .opacity.combined(with: .move(edge: .top))
                        )
                }
            }
            .padding(12)
            .background(
                IPalette.surface,
                in: RoundedRectangle(cornerRadius: 16)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .stroke(IPalette.cobalt.opacity(0.28))
            }
        } else {
            branchWorkspaceContent
        }
    }

    private var branchWorkspaceContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                Image(systemName: "point.3.connected.trianglepath.dotted")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 54, height: 54)
                    .background(IPalette.cobalt, in: RoundedRectangle(cornerRadius: 15))
                VStack(alignment: .leading, spacing: 3) {
                    Text("分支工作台")
                        .font(.title3.weight(.bold))
                    Text("长按文件并拖到任意分支；拖回“未分类”即可移出分支。")
                        .font(.subheadline)
                        .foregroundStyle(IPalette.muted)
                }
                Spacer()
                Button {
                    beginCreatingBranch(parent: nil)
                } label: {
                    Label("新建分支", systemImage: "folder.badge.plus")
                }
                .buttonStyle(.borderedProminent)
            }

            if branchStore.branches.isEmpty {
                Text("先建立项目、客户或拍摄日分支，再把本地文件拖入；文件仍保留在原始存储位置。")
                    .font(.subheadline)
                    .foregroundStyle(IPalette.muted)
                    .padding(.vertical, 8)
            } else {
                ForEach(branchStore.branches) { branch in
                    LibraryBranchRow(
                        store: branchStore,
                        branch: branch,
                        depth: 0,
                        items: model.library.items,
                        selectedItemID: model.library.selectedItemID,
                        addChild: { beginCreatingBranch(parent: $0) },
                        deleteBranch: {
                            branchPendingDeletion = $0
                        },
                        selectItem: {
                            model.library.selectedItemID = $0.id
                        },
                        previewItem: {
                            model.library.selectedItemID = $0.id
                            previewItem = $0
                        }
                    )
                }
            }

            if let selected = model.library.selectedItem {
                HStack {
                    Text(selected.filename)
                        .font(.caption.monospaced())
                        .lineLimit(1)
                    Spacer()
                    ShareLink(item: selected.url) {
                        Label("分享", systemImage: "square.and.arrow.up")
                    }
                    Button(role: .destructive) {
                        branchStore.assign(selected.id, to: nil)
                        model.library.deleteSelected()
                    } label: {
                        Label("删除", systemImage: "trash")
                    }
                }
                .buttonStyle(.bordered)
            }

            DisclosureGroup(
                "未分类 · \(unclassifiedItems.count)",
                isExpanded: $uncategorizedExpanded
            ) {
                if unclassifiedItems.isEmpty {
                    ContentUnavailableView(
                        "未分类已清空",
                        systemImage: "checkmark.circle",
                        description: Text("拍摄、导入或无线接收的新文件会先显示在这里。")
                    )
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 150)
                } else {
                    DisclosureGroup(
                        "照片 · \(unclassifiedItems.filter { !$0.isVideo }.count)",
                        isExpanded: $localPhotosExpanded
                    ) {
                        localLibraryGrid(unclassifiedItems.filter { !$0.isVideo })
                    }
                    DisclosureGroup(
                        "视频 · \(unclassifiedItems.filter(\.isVideo).count)",
                        isExpanded: $localVideosExpanded
                    ) {
                        localLibraryGrid(unclassifiedItems.filter(\.isVideo))
                    }
                }
            }
            .padding(10)
            .background(
                unclassifiedDropTargeted
                    ? IPalette.cobaltSoft
                    : IPalette.paperSecondary,
                in: RoundedRectangle(cornerRadius: 12)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        unclassifiedDropTargeted
                            ? IPalette.cobalt
                            : IPalette.rule,
                        lineWidth: unclassifiedDropTargeted ? 2 : 1
                    )
            }
            .dropDestination(for: String.self) { itemIDs, _ in
                guard !itemIDs.isEmpty else { return false }
                itemIDs.forEach { branchStore.assign($0, to: nil) }
                return true
            } isTargeted: {
                unclassifiedDropTargeted = $0
            }
        }
        .padding(16)
        .background(IPalette.surface, in: RoundedRectangle(cornerRadius: 18))
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 2)
                .fill(IPalette.cobalt)
                .frame(width: 4)
                .padding(.vertical, 18)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .stroke(IPalette.cobalt.opacity(0.22), lineWidth: 1)
        }
    }

    @ViewBuilder
    private func systemAlbumGrid(_ items: [SystemAlbumItem]) -> some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 140), spacing: 12)],
            spacing: 12
        ) {
            ForEach(items) { item in
                SystemAlbumThumbnail(item: item)
                    .onTapGesture(count: 2) {
                        systemPreviewItem = item
                    }
                    .accessibilityHint("双击查看大图或播放视频")
            }
        }
    }

    @ViewBuilder
    private func localLibraryGrid(_ items: [LibraryItem]) -> some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 150), spacing: 12)],
            spacing: 12
        ) {
            ForEach(items) { item in
                LibraryThumbnail(
                    item: item,
                    selected: model.library.selectedItemID == item.id
                )
                .onTapGesture {
                    model.library.selectedItemID = item.id
                }
                .onTapGesture(count: 2) {
                    model.library.selectedItemID = item.id
                    previewItem = item
                }
                .draggable(item.id) {
                    Label(
                        item.filename,
                        systemImage: "arrow.up.and.down.and.arrow.left.and.right"
                    )
                    .font(.caption.weight(.semibold))
                    .padding(10)
                    .background(
                        .regularMaterial,
                        in: RoundedRectangle(cornerRadius: 10)
                    )
                }
                .accessibilityHint("长按并拖动到分支")
            }
        }
    }

    @MainActor
    private func loadSystemAlbum() async {
        var status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        if status == .notDetermined {
            status = await withCheckedContinuation { continuation in
                PHPhotoLibrary.requestAuthorization(for: .readWrite) {
                    continuation.resume(returning: $0)
                }
            }
        }
        guard status == .authorized || status == .limited else {
            systemAlbumItems = []
            systemAlbumStatus = "未获得相册读取权限"
            return
        }

        let options = PHFetchOptions()
        options.fetchLimit = 80
        options.sortDescriptors = [
            NSSortDescriptor(key: "creationDate", ascending: false)
        ]
        let assets = PHAsset.fetchAssets(with: options)
        var loaded: [SystemAlbumItem] = []
        assets.enumerateObjects { asset, _, _ in
            loaded.append(SystemAlbumItem(asset: asset))
        }
        systemAlbumItems = loaded
        systemAlbumStatus = status == .limited
            ? "已显示允许访问的 \(loaded.count) 项"
            : "最近 \(loaded.count) 项"
    }
}

private struct SystemAlbumItem: Identifiable {
    let asset: PHAsset

    var id: String { asset.localIdentifier }
    var isVideo: Bool { asset.mediaType == .video }
    var name: String {
        PHAssetResource.assetResources(for: asset).first?.originalFilename
            ?? (isVideo ? "系统视频" : "系统照片")
    }
}

private struct SystemAlbumThumbnail: View {
    let item: SystemAlbumItem
    @State private var thumbnail: UIImage?

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            ZStack(alignment: .bottomTrailing) {
                if let thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .scaledToFill()
                } else {
                    Color.black
                    Image(systemName: item.isVideo ? "video.fill" : "photo")
                        .font(.title)
                        .foregroundStyle(IPalette.muted)
                }
                if item.isVideo {
                    Label(
                        durationLabel(item.asset.duration),
                        systemImage: "play.fill"
                    )
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 5)
                    .background(.black.opacity(0.68), in: Capsule())
                    .padding(7)
                }
            }
            .frame(height: 116)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 12))

            Text(item.name)
                .font(.caption2.monospaced())
                .lineLimit(1)
        }
        .padding(7)
        .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 15))
        .task(id: item.id) {
            PHImageManager.default().requestImage(
                for: item.asset,
                targetSize: CGSize(width: 420, height: 320),
                contentMode: .aspectFill,
                options: nil
            ) { image, _ in
                if let image {
                    thumbnail = image
                }
            }
        }
    }

    private func durationLabel(_ duration: TimeInterval) -> String {
        let seconds = max(0, Int(duration.rounded()))
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}

private struct SystemAlbumPreviewView: View {
    @Environment(\.dismiss) private var dismiss
    let item: SystemAlbumItem
    @State private var image: UIImage?
    @State private var player: AVPlayer?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if item.isVideo {
                if let player {
                    VideoPlayer(player: player)
                        .ignoresSafeArea()
                        .onAppear { player.play() }
                } else {
                    ProgressView("正在载入视频…")
                        .tint(.white)
                        .foregroundStyle(.white)
                }
            } else if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .padding(12)
            } else {
                ProgressView("正在载入照片…")
                    .tint(.white)
                    .foregroundStyle(.white)
            }

            VStack {
                HStack {
                    Button {
                        player?.pause()
                        dismiss()
                    } label: {
                        Label("关闭", systemImage: "xmark")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.black.opacity(0.66))
                    Spacer()
                    Text("系统相册 · \(item.name)")
                        .font(.caption.monospaced())
                        .lineLimit(1)
                        .padding(.horizontal, 12)
                        .frame(height: 38)
                        .background(.black.opacity(0.62), in: Capsule())
                }
                Spacer()
            }
            .foregroundStyle(.white)
            .padding()
        }
        .task {
            if item.isVideo {
                PHImageManager.default().requestPlayerItem(
                    forVideo: item.asset,
                    options: nil
                ) { playerItem, _ in
                    if let playerItem {
                        player = AVPlayer(playerItem: playerItem)
                    }
                }
            } else {
                PHImageManager.default().requestImage(
                    for: item.asset,
                    targetSize: CGSize(width: 2400, height: 2400),
                    contentMode: .aspectFit,
                    options: nil
                ) { loaded, _ in
                    image = loaded
                }
            }
        }
    }
}

private struct CloudDriveProvider: Identifiable {
    let name: String
    let note: String
    let url: URL
    var id: String { name }

    static let domestic: [CloudDriveProvider] = [
        .init(name: "百度网盘", note: "安装客户端后，从系统文件选择器或“下载”目录选择。", url: URL(string: "https://pan.baidu.com/")!),
        .init(name: "阿里云盘", note: "支持移动端与桌面端；先把照片下载到设备或同步目录。", url: URL(string: "https://www.alipan.com/")!),
        .init(name: "腾讯微云", note: "从微云导出到“文件”，再回到 帧澈 ZENCHE 选择。", url: URL(string: "https://www.weiyun.com/")!),
        .init(name: "夸克网盘", note: "安装夸克或桌面客户端，把照片下载到本机后选择。", url: URL(string: "https://pan.quark.cn/")!),
        .init(name: "迅雷云盘", note: "通过迅雷客户端下载到设备，再从系统文件选择器加入。", url: URL(string: "https://pan.xunlei.com/")!),
        .init(name: "115", note: "在 115 的“存储”中下载文件，再从 帧澈 ZENCHE 选择。", url: URL(string: "https://115.com/")!)
    ]
}

private struct CloudDriveGuideView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    let chooseFiles: () -> Void

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("帧澈 ZENCHE 不代管网盘账号或密码。请先在对应客户端登录，再通过系统文件选择器安全读取照片与视频。")
                        .font(.subheadline)
                }
                Section("国内主流网盘") {
                    ForEach(CloudDriveProvider.domestic) { provider in
                        Button {
                            openURL(provider.url)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "externaldrive.connected.to.line.below")
                                    .frame(width: 32, height: 32)
                                    .background(Color.accentColor.opacity(0.14), in: RoundedRectangle(cornerRadius: 8))
                                VStack(alignment: .leading, spacing: 3) {
                                    RuntimeLocalizedText(provider.name)
                                        .font(.headline)
                                    RuntimeLocalizedText(provider.note)
                                        .font(.caption)
                                        .foregroundStyle(IPalette.muted)
                                        .multilineTextAlignment(.leading)
                                }
                                Spacer()
                                Image(systemName: "arrow.up.right")
                                    .foregroundStyle(IPalette.muted)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                Section("连接步骤") {
                    Label("安装并登录所选网盘客户端", systemImage: "1.circle")
                    Label("把照片或视频下载到设备，或启用文件提供器", systemImage: "2.circle")
                    Label("点击下方按钮，多选文件加入 帧澈 ZENCHE 文件库", systemImage: "3.circle")
                }
            }
            .navigationTitle("链接网盘")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("选择文件并加入", action: chooseFiles)
                }
            }
        }
    }
}

private struct LibraryLargePhotoView: View {
    @Environment(\.dismiss) private var dismiss
    let item: LibraryItem
    @State private var player: AVPlayer?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if item.isVideo {
                if let player {
                    VideoPlayer(player: player)
                        .ignoresSafeArea()
                        .onAppear { player.play() }
                } else {
                    ProgressView("正在载入视频…")
                        .tint(.white)
                }
            } else if let image = UIImage(contentsOfFile: item.url.path) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .padding(12)
            } else {
                ContentUnavailableView(
                    "无法显示大图",
                    systemImage: "photo.badge.exclamationmark",
                    description: Text(item.filename)
                )
            }

            VStack {
                HStack {
                    Button {
                        player?.pause()
                        dismiss()
                    } label: {
                        Label("关闭", systemImage: "xmark")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.black.opacity(0.65))
                    Spacer()
                    ShareLink(item: item.url) {
                        Label("分享到社交平台", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.borderedProminent)
                }
                Spacer()
                Text(item.filename)
                    .font(.caption.monospaced())
                    .foregroundStyle(.white)
                    .padding(8)
                    .background(.black.opacity(0.65), in: Capsule())
            }
            .padding()
        }
        .task {
            if item.isVideo {
                player = AVPlayer(url: item.url)
            }
        }
    }
}

private struct LibraryThumbnail: View {
    let item: LibraryItem
    let selected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Group {
                if item.isVideo {
                    ZStack {
                        Color.black
                        Image(systemName: "play.rectangle.fill")
                            .font(.largeTitle)
                            .foregroundStyle(.white.opacity(0.78))
                    }
                } else if let image = UIImage(contentsOfFile: item.url.path) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    Image(systemName: "photo")
                        .font(.largeTitle)
                        .foregroundStyle(IPalette.muted)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(height: 125)
            .clipped()
            .background(IPalette.graphite)
        .foregroundStyle(Color.white.opacity(0.82))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            Text(item.filename)
                .font(.caption2.monospaced())
                .lineLimit(1)
                .padding(.horizontal, 3)
        }
        .padding(7)
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(selected ? Color.accentColor.opacity(0.16) : Color.white.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 15)
                .stroke(selected ? Color.accentColor : .clear, lineWidth: 1.5)
        )
    }
}

private struct WirelessTransferCard: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        SettingsCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Label("多协议无线图片收件箱", systemImage: "wifi")
                        .font(.headline)
                    Spacer()
                    Circle()
                        .fill(model.wireless.isRunning ? Color.green : Color.secondary)
                        .frame(width: 8, height: 8)
                    RuntimeLocalizedText(
                        model.wireless.isRunning ? "接收中" : "已停止"
                    )
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(IPalette.muted)
                }

                RuntimeLocalizedText(model.wireless.status)
                    .font(.subheadline)
                    .foregroundStyle(IPalette.muted)

                if model.wireless.isRunning {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("FTP/PASV  \(model.wireless.hostAddress):\(WirelessTransferServer.port)")
                            .font(.body.monospaced().weight(.semibold))
                            .textSelection(.enabled)
                        Text("HTTP 上传  http://\(model.wireless.hostAddress):\(WirelessTransferServer.httpPort)/upload/文件名")
                            .font(.caption.monospaced())
                            .textSelection(.enabled)
                        Text("WebDAV  http://\(model.wireless.hostAddress):\(WirelessTransferServer.httpPort)/")
                            .font(.caption.monospaced())
                            .textSelection(.enabled)
                        Text("用户名 / 密码：\(WirelessTransferServer.username) / \(WirelessTransferServer.password)")
                            .font(.caption.monospaced())
                            .textSelection(.enabled)
                    }
                }

                Button {
                    if model.wireless.isRunning {
                        model.wireless.stop()
                    } else {
                        model.wireless.refreshAddress()
                        model.wireless.start()
                    }
                } label: {
                    Label(
                        model.wireless.isRunning ? "停止接收" : "开启无线接收",
                        systemImage: model.wireless.isRunning
                            ? "stop.fill"
                            : "antenna.radiowaves.left.and.right"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(model.wireless.isRunning ? .red : .accentColor)

                Text("相机端可使用 FTP/PASV；手机、电脑和自动化工具可使用 HTTP PUT/POST 或 WebDAV PUT。接收完成后照片会直接进入上方文件库。HTTP 请求需提供 Content-Length；服务只在 帧澈 ZENCHE 位于前台时运行。")
                    .font(.caption)
                    .foregroundStyle(IPalette.muted)
            }
        }
    }
}

private struct AppSettingsSheet: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @State private var showingLogs = false
    @State private var showingDonation = false
    @State private var activationCode = ""
    @State private var activationStatus = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    SettingsCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("语言", systemImage: "globe")
                                .font(.headline)
                            Picker("界面语言", selection: $model.language) {
                                ForEach(AppLanguage.allCases) { language in
                                    Text(language.displayName).tag(language)
                                }
                            }
                            .pickerStyle(.segmented)
                            Text("语言更改会立即应用，并在下次启动时保留。")
                                .font(.subheadline)
                                .foregroundStyle(IPalette.muted)
                        }
                    }

                    SettingsCard {
                        Toggle(isOn: $model.autoSaveToPhotos) {
                            Label("拍摄后自动存入“照片”", systemImage: "photo.badge.plus")
                        }
                    }

                    UpdateSettingsCard(updater: model.updater)

                    SettingsCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("诊断日志", systemImage: "doc.text.magnifyingglass")
                                .font(.headline)
                            Text("按日写入、5 MB 滚动并保留 14 天；查询与上传前会自动脱敏。")
                                .font(.subheadline)
                                .foregroundStyle(IPalette.muted)
                            ViewThatFits(in: .horizontal) {
                                HStack(spacing: 10) {
                                    logButtons
                                }
                                VStack(spacing: 10) {
                                    logButtons
                                }
                            }
                            FastFeedbackCallout {
                                UIApplication.shared.open(afdianURL)
                            }
                        }
                    }

                    SettingsCard {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "key.fill").font(.system(size: 18, weight: .semibold)).foregroundStyle(IPalette.cobalt)
                                .frame(width: 36, height: 36).background(IPalette.cobaltSoft).clipShape(RoundedRectangle(cornerRadius: 8))
                            VStack(alignment: .leading, spacing: 4) {
                                Text("AI 功能激活").font(.system(size: 15, weight: .bold))
                                Text("AI 修图与生图功能需购买激活码解锁，次数由 AI 服务统一统计。").font(.system(size: 12)).foregroundStyle(IPalette.muted)
                                if ActivationManager.isActivated {
                                    Text("状态：已激活").font(.caption.weight(.semibold)).foregroundStyle(Color.green)
                                }
                            }
                            Spacer()
                        }
                        VStack(alignment: .leading, spacing: 10) {
                            Button {
                                UIApplication.shared.open(zencheWebsiteURL)
                            } label: {
                                Label("前往官网兑换密钥", systemImage: "globe")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)

                            Text("复制设备 ID 后，前往 zenche.top 使用兑换码兑换绑定当前设备的激活密钥。")
                                .font(.caption)
                                .foregroundStyle(IPalette.muted)
                                .fixedSize(horizontal: false, vertical: true)

                            Text("没有兑换码？在爱发电购买兑换码")
                                .font(.system(size: 13, weight: .semibold))

                            if let image = UIImage(named: "wechat-donation") {
                                Button {
                                    UIApplication.shared.open(afdianURL)
                                } label: {
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(maxWidth: 280)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(IPalette.rule, lineWidth: 0.5)
                                        )
                                }
                                .buttonStyle(.plain)
                                .frame(maxWidth: .infinity)
                                .accessibilityLabel("在爱发电购买兑换码")
                            }

                            Button("在爱发电购买兑换码") {
                                UIApplication.shared.open(afdianURL)
                            }
                            .buttonStyle(.bordered)
                            .frame(maxWidth: .infinity)

                            Text("兑换码仅用于 AI 云服务次数，帧澈本体保持免费开源。")
                                .font(.caption2)
                                .foregroundStyle(IPalette.muted)
                        }
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("我的设备 ID")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(IPalette.muted)
                                Spacer()
                                Button("复制") {
                                    UIPasteboard.general.string = ActivationManager.deviceId
                                    activationStatus = "设备 ID 已复制，可前往官网兑换密钥"
                                }
                                .buttonStyle(.bordered)
                            }
                            Text(ActivationManager.deviceId)
                                .font(.caption.monospaced())
                                .foregroundStyle(IPalette.ink)
                                .textSelection(.enabled)
                            Text("每个激活密钥绑定当前设备，请复制上面的设备 ID 并前往官网兑换。")
                                .font(.caption)
                                .foregroundStyle(IPalette.muted)
                        }
                        SecureField("输入激活码", text: $activationCode).textFieldStyle(.roundedBorder)
                        HStack {
                            Spacer()
                            if !activationStatus.isEmpty { Text(activationStatus).font(.caption).foregroundStyle(IPalette.muted) }
                            Button("购买激活码") { if let url = URL(string: "https://www.ifdian.net/a/Tauber") { UIApplication.shared.open(url) } }.buttonStyle(.bordered)
                            Button("激活") {
                                let c = activationCode.trimmingCharacters(in: .whitespacesAndNewlines)
                                guard !c.isEmpty else { activationStatus = "请输入激活码"; return }
                                activationStatus = ActivationManager.verifyAndActivate(code: c) ? "激活成功！" : "激活码无效"
                                if activationStatus.hasPrefix("激活成功") { activationCode = "" }
                            }.buttonStyle(.borderedProminent)
                        }
                    }

                    SettingsCard {
                        HStack(spacing: 14) {
                            Image(systemName: "cup.and.saucer.fill")
                                .font(.title2)
                                .foregroundStyle(.orange)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("喜欢 帧澈 ZENCHE？")
                                    .font(.headline)
                                Text("请作者喝杯奶茶，支持后续维护与新机型适配。")
                                    .font(.subheadline)
                                    .foregroundStyle(IPalette.muted)
                            }
                            Spacer()
                            Button("请作者喝奶茶") {
                                showingDonation = true
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.orange)
                        }
                    }

                    SettingsCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("隐私", systemImage: "lock.shield")
                                .font(.headline)
                            Text("帧澈 ZENCHE 不上传照片，也不包含分析服务。只有你点击上传并在 GitHub 确认时，预览中的脱敏日志才会发送。")
                                .font(.subheadline)
                                .foregroundStyle(IPalette.muted)
                        }
                    }
                }
                .padding(20)
            }
            .background(IPalette.paper)
            .navigationTitle(
                RuntimeLocalization.text("设置", locale: locale)
            )
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
        .sheet(isPresented: $showingLogs) {
            DiagnosticLogViewer()
        }
        .sheet(isPresented: $showingDonation) {
            DonationSheet()
                .presentationCornerRadius(28)
        }
    }

    @ViewBuilder
    private var logButtons: some View {
        Button {
            showingLogs = true
        } label: {
            Label("查询最近日志", systemImage: "doc.text")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)

        Button {
            DiagnosticLogger.shared.info("diagnostics", "用户打开 GitHub Issue 提交页")
            guard let url = DiagnosticLogger.shared.githubIssueURL() else {
                model.statusMessage = "无法生成 GitHub Issue 地址"
                return
            }
            UIApplication.shared.open(url)
        } label: {
            Label("上传脱敏日志", systemImage: "arrow.up.doc")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
    }
}

private struct UpdateSettingsCard: View {
    @ObservedObject var updater: UpdateController

    var body: some View {
        SettingsCard {
            VStack(alignment: .leading, spacing: 12) {
                Toggle(isOn: $updater.automaticallyChecksForUpdates) {
                    Label("自动检查更新", systemImage: "arrow.triangle.2.circlepath")
                        .font(.headline)
                }

                Text("当前版本 \(updater.currentVersion) · 优先通过 Mirror酱检查更新，无可用 CDN 下载地址时自动回退 GitHub Releases。")
                    .font(.subheadline)
                    .foregroundStyle(IPalette.muted)

                SecureField(
                    "Mirror酱 CDK（可选）",
                    text: $updater.mirrorChyanCDK
                )
                .textContentType(.password)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(.horizontal, 12)
                .frame(height: 42)
                .background(IPalette.paper)
                .clipShape(RoundedRectangle(cornerRadius: 8))

                HStack {
                    Text("CDK 保存在系统钥匙串中，不会写入诊断日志。")
                        .font(.caption)
                        .foregroundStyle(IPalette.muted)
                    Spacer()
                    Button("打开 Mirror酱") {
                        updater.openMirrorChyan()
                    }
                    .buttonStyle(.borderless)
                }

                HStack(spacing: 10) {
                    RuntimeLocalizedText(updater.statusText)
                        .font(.caption)
                        .foregroundStyle(IPalette.muted)
                    Spacer()
                    if updater.isChecking {
                        ProgressView()
                    }
                    Button("检查更新") {
                        updater.checkForUpdates()
                    }
                    .buttonStyle(.bordered)
                    .disabled(updater.isChecking)
                    if updater.availableVersion != nil {
                        Button("获取更新") {
                            updater.openAvailableUpdate()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
        }
    }
}

private struct DiagnosticLogViewer: View {
    @Environment(\.dismiss) private var dismiss
    @State private var logText = DiagnosticLogger.shared.recentText(maxCharacters: 12_000)

    var body: some View {
        NavigationStack {
            ScrollView {
                Text(logText)
                    .font(.caption.monospaced())
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(18)
            }
            .background(IPalette.paper)
            .navigationTitle("最近诊断日志")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("刷新") {
                        logText = DiagnosticLogger.shared.recentText(maxCharacters: 12_000)
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }
}

private struct FastFeedbackCallout: View {
    let openAfdian: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "bolt.horizontal.circle.fill")
                    .font(.title2)
                    .foregroundStyle(IPalette.cobalt)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text("快速问题反馈")
                        .font(.headline)
                    Text("公开问题可继续在 GitHub 免费提交；在爱发电赞助后，可获取快速问题反馈渠道。")
                        .font(.subheadline)
                        .foregroundStyle(IPalette.muted)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("官方 QQ 群：165315727")
                        .font(.subheadline.monospacedDigit().weight(.bold))
                        .foregroundStyle(IPalette.cobalt)
                        .textSelection(.enabled)
                }
            }
            Button {
                openAfdian()
            } label: {
                Label("打开爱发电", systemImage: "arrow.up.right")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(IPalette.cobaltSoft, in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(IPalette.cobalt.opacity(0.18), lineWidth: 0.5)
        )
    }
}

private struct DonationSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 14) {
                        Image(systemName: "heart.fill")
                            .font(.title2)
                            .foregroundStyle(IPalette.cobalt)
                            .frame(width: 48, height: 48)
                            .background(
                                IPalette.cobaltSoft,
                                in: RoundedRectangle(cornerRadius: 14)
                            )
                        VStack(alignment: .leading, spacing: 3) {
                            Text("爱发电赞助")
                                .font(.title2.bold())
                            Text("扫描二维码，或打开爱发电主页支持项目。")
                                .font(.subheadline)
                                .foregroundStyle(IPalette.muted)
                        }
                    }

                    FastFeedbackCallout {
                        UIApplication.shared.open(afdianURL)
                    }

                    if let image = UIImage(named: "wechat-donation") {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 440)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(IPalette.rule, lineWidth: 0.5)
                            )
                    } else {
                        ContentUnavailableView(
                            "二维码未找到",
                            systemImage: "qrcode",
                            description: Text("请重新安装 帧澈 ZENCHE 后再试。")
                        )
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("软件功能永久免费，赞助为自愿行为。")
                        Text("赞助不会解锁软件功能，也不影响公开 Issue 的处理。")
                    }
                    .font(.caption)
                    .foregroundStyle(IPalette.muted)
                }
                .padding(20)
            }
            .background(IPalette.paper)
            .navigationTitle("爱发电赞助")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }
}

private struct LaunchAnnouncementSheet: View {
    let version: String
    @Binding var doNotRemind: Bool
    let close: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(spacing: 12) {
                        Image(systemName: "sparkles.rectangle.stack.fill")
                            .font(.title2)
                            .foregroundStyle(Color.accentColor)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("本次更新")
                                .font(.title3.bold())
                            HStack(spacing: 4) {
                                Text("当前版本")
                                Text(version)
                            }
                            .font(.caption.monospaced())
                            .foregroundStyle(IPalette.muted)
                        }
                    }

                    Text("• AI 修图与 AI 生图工作台统一优化：编辑页默认进入“专业显影”，可明确切换“AI 工具”；保留快捷预设、比例、分辨率、保存到文件库。\n• 恢复设备码系统：每个激活密钥绑定当前设备，服务器计数 AI 云服务次数；帧澈本体继续免费开源。\n• 新增官网入口：复制设备 ID 后前往 https://zenche.top 兑换绑定当前设备的激活密钥。\n• 新增“在爱发电购买兑换码”提示、二维码与购买入口；只认官方官网和应用内爱发电入口，谨防诈骗。\n• 设置页移除可编辑的“AI 服务器”窗口，但继续兼容读取历史配置；Sony / Canon / Nikon 相机适配保持不变。\n• iOS / iPadOS、Android、HarmonyOS、macOS、Windows 五端同步更新。")
                    .font(.subheadline)
                    .lineSpacing(5)

                    VStack(alignment: .leading, spacing: 8) {
                        Label("谨防诈骗", systemImage: "exclamationmark.shield.fill")
                            .font(.headline)
                            .foregroundStyle(.red)
                        Text("帧澈 ZENCHE 是开源免费项目。任何声称“进群领取软件”或要求付费购买软件的人都是骗子，请勿转账。")
                        .font(.subheadline.weight(.semibold))
                        .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.red.opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: 14))

                    VStack(alignment: .leading, spacing: 10) {
                        Label("爱发电赞助", systemImage: "heart.fill")
                            .font(.headline)
                            .foregroundStyle(IPalette.cobalt)
                        Text("如果本项目对你有帮助，欢迎自愿打赏；软件功能永久免费。")
                            .font(.subheadline)
                            .foregroundStyle(IPalette.muted)
                        FastFeedbackCallout {
                            UIApplication.shared.open(afdianURL)
                        }
                        if let image = UIImage(named: "wechat-donation") {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(maxHeight: 340)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                    }
                    .padding(16)
                    .background(IPalette.surface, in: RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(IPalette.rule, lineWidth: 0.5)
                    )

                    Button {
                        doNotRemind.toggle()
                    } label: {
                        HStack(spacing: 10) {
                            Image(
                                systemName: doNotRemind
                                    ? "checkmark.square.fill"
                                    : "square"
                            )
                            .font(.title3)
                            Text("不再提醒（软件更新后仍会显示）")
                                .font(.subheadline)
                            Spacer()
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    Button("关闭公告", action: close)
                        .buttonStyle(.borderedProminent)
                        .frame(maxWidth: .infinity)
                }
                .padding(20)
            }
            .background(IPalette.paper)
            .navigationTitle("更新公告")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("关闭公告", action: close)
                }
            }
        }
    }
}

private struct SettingsCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(IPalette.surface, in: RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(IPalette.rule, lineWidth: 0.5))
    }
}

private struct ConnectionSheet: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("系统视频设备")
                            .font(.headline)

                        if model.camera.availableDevices.isEmpty {
                            ContentUnavailableView(
                                "未发现相机",
                                systemImage: "video.slash",
                                description: Text("请连接外接 UVC 设备，或检查系统相机权限。")
                            )
                            .frame(maxWidth: .infinity)
                        } else {
                            ForEach(model.camera.availableDevices) { device in
                                ConnectionOption(
                                    icon: device.isExternal
                                        ? "cable.connector"
                                        : device.position == .front
                                            ? "camera.rotate"
                                            : "camera",
                                    title: device.name,
                                    subtitle: device.detail,
                                    selected: model.camera.selectedDeviceID == device.id
                                ) {
                                    model.camera.connect(deviceID: device.id)
                                }
                            }
                        }

                        if AVCaptureDevice.authorizationStatus(for: .video) == .denied {
                            Button {
                                guard let url = URL(string: UIApplication.openSettingsURLString) else {
                                    return
                                }
                                UIApplication.shared.open(url)
                            } label: {
                                Label("在系统设置中允许相机访问", systemImage: "gear")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Image(systemName: "camera.aperture")
                                .font(.title2)
                                .foregroundStyle(.yellow)
                            Text("Nikon USB / PTP")
                                .font(.headline)
                            Spacer()
                            Text("等待授权接口")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.yellow)
                        }
                        Text("iOS 没有向普通应用开放通用 USB/PTP 相机控制。要控制 帧澈 ZENCHE 已适配的 EXPEED 6 / 7 相机并下载原图，需要 Nikon 提供 iOS 协议授权或官方 SDK。这里不会把普通视频连接伪装成 Nikon 原生控制。")
                            .font(.subheadline)
                            .foregroundStyle(IPalette.muted)
                    }
                    .padding(16)
                    .background(Color.yellow.opacity(0.075), in: RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.yellow.opacity(0.22), lineWidth: 1)
                    )

                    if model.camera.state == .ready {
                        VStack(alignment: .leading, spacing: 7) {
                            Label(model.camera.deviceName, systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .font(.headline)
                            Text(
                                model.camera.isExternalCamera
                                ? "已通过 AVFoundation 使用外接视频设备"
                                : "正在使用本机镜头"
                            )
                            .font(.subheadline)
                            .foregroundStyle(IPalette.muted)
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.green.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
                    }
                }
                .padding(20)
            }
            .background(IPalette.paper)
            .navigationTitle("选择相机")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
                if model.camera.state == .ready {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("断开", role: .destructive) {
                            model.camera.disconnect()
                        }
                    }
                }
            }
            .onAppear {
                model.camera.refreshDevices()
            }
        }
    }
}

private struct ConnectionOption: View {
    let icon: String
    let title: String
    let subtitle: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.title2)
                    .frame(width: 38)
                VStack(alignment: .leading, spacing: 4) {
                    Text(LocalizedStringKey(title))
                        .font(.headline)
                    Text(LocalizedStringKey(subtitle))
                        .font(.subheadline)
                        .foregroundStyle(IPalette.muted)
                }
                Spacer()
                Image(systemName: selected ? "checkmark.circle.fill" : "chevron.right")
                    .foregroundStyle(selected ? Color.green : Color.secondary)
            }
            .padding(16)
            .background(
                selected ? Color.green.opacity(0.08) : Color.white.opacity(0.055),
                in: RoundedRectangle(cornerRadius: 16)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct PageTitle: View {
    let title: String
    let subtitle: String
    var accent = IPalette.cobalt

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Capsule()
                .fill(accent)
                .frame(width: 4, height: 38)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 5) {
                Text(LocalizedStringKey(title))
                    .font(.system(size: 29, weight: .bold))
                    .foregroundStyle(IPalette.ink)
                Text(LocalizedStringKey(subtitle))
                    .font(.subheadline)
                    .foregroundStyle(IPalette.muted)
            }
        }
    }
}

private struct GridOverlay: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        for fraction in [CGFloat(1.0 / 3.0), CGFloat(2.0 / 3.0)] {
            path.move(to: CGPoint(x: rect.width * fraction, y: 0))
            path.addLine(to: CGPoint(x: rect.width * fraction, y: rect.height))
            path.move(to: CGPoint(x: 0, y: rect.height * fraction))
            path.addLine(to: CGPoint(x: rect.width, y: rect.height * fraction))
        }
        return path
    }
}

private struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    let focusHandler: (CGPoint) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(focusHandler: focusHandler)
    }

    func makeUIView(context: Context) -> PreviewSurface {
        let view = PreviewSurface()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        let recognizer = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleTap(_:))
        )
        view.addGestureRecognizer(recognizer)
        return view
    }

    func updateUIView(_ uiView: PreviewSurface, context: Context) {
        uiView.previewLayer.session = session
        context.coordinator.focusHandler = focusHandler
    }

    static func dismantleUIView(_ uiView: PreviewSurface, coordinator: Coordinator) {
        uiView.gestureRecognizers?.forEach(uiView.removeGestureRecognizer)
        uiView.previewLayer.session = nil
    }

    final class Coordinator: NSObject {
        var focusHandler: (CGPoint) -> Void

        init(focusHandler: @escaping (CGPoint) -> Void) {
            self.focusHandler = focusHandler
        }

        @objc func handleTap(_ recognizer: UITapGestureRecognizer) {
            guard let surface = recognizer.view as? PreviewSurface else { return }
            let point = recognizer.location(in: surface)
            focusHandler(surface.previewLayer.captureDevicePointConverted(fromLayerPoint: point))
        }
    }
}

private final class PreviewSurface: UIView {
    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }

    var previewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard let connection = previewLayer.connection else { return }
        let angle: CGFloat
        switch window?.windowScene?.interfaceOrientation {
        case .landscapeLeft: angle = 90
        case .landscapeRight: angle = 270
        case .portraitUpsideDown: angle = 180
        default: angle = 0
        }
        if connection.isVideoRotationAngleSupported(angle) {
            connection.videoRotationAngle = angle
        }
    }
}
