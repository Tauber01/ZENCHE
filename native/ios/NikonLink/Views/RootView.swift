import AVFoundation
import AVKit
import CoreImage
import Foundation
import Photos
import Security
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
    static let monitorBackground = Color(red: 4 / 255, green: 12 / 255, blue: 22 / 255)
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
        ) as? String ?? "1.5.1"
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                (model.section == .monitor && proxy.size.width < 820
                    ? IPalette.monitorBackground
                    : IPalette.paper)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // The compact monitor is a dedicated camera surface. Keep the
                    // existing header for the other pages, while letting monitor
                    // use the full portrait canvas shown in the native reference.
                    if !(model.section == .monitor && proxy.size.width < 820) {
                        AppHeader()
                        Divider().overlay(IPalette.rule)
                    }

                    if proxy.size.width >= 820 {
                        HStack(spacing: 0) {
                            SideNavigation()
                            Divider().overlay(IPalette.rule)
                            CurrentPage()
                        }
                        GlobalStatusBar(
                            bottomInset: proxy.safeAreaInsets.bottom
                        )
                    } else {
                        CurrentPage()
                        Divider().overlay(IPalette.rule)
                        BottomNavigation(bottomInset: 0)
                        GlobalStatusBar(
                            bottomInset: proxy.safeAreaInsets.bottom
                        )
                    }

                }
                .preferredColorScheme(
                    model.section == .monitor && proxy.size.width < 820 ? .dark : nil
                )
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
        HStack(spacing: horizontalSizeClass == .compact ? 8 : 12) {
            brand
            Spacer(minLength: horizontalSizeClass == .compact ? 2 : 8)
            connectionButton
            settingsButton
        }
        .padding(.horizontal, horizontalSizeClass == .compact ? 12 : 16)
        .frame(minHeight: horizontalSizeClass == .compact ? 60 : 68)
        .background(IPalette.surface)
        .overlay(alignment: .bottom) {
            Rectangle().fill(IPalette.rule).frame(height: 0.5)
        }
        .shadow(color: IPalette.shadow.opacity(0.28), radius: 8, y: 2)
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
            .frame(
                width: horizontalSizeClass == .compact ? 38 : 44,
                height: horizontalSizeClass == .compact ? 38 : 44
            )
            .shadow(color: IPalette.cobalt.opacity(0.18), radius: 8, y: 4)

            VStack(alignment: .leading, spacing: 2) {
                Text("帧澈 ZENCHE")
                    .font(
                        .system(
                            size: horizontalSizeClass == .compact ? 15 : 17,
                            weight: .bold
                        )
                    )
                    .lineLimit(1)
                if horizontalSizeClass != .compact {
                    Text("Capture · Connect · Flow")
                        .font(.caption)
                        .foregroundStyle(IPalette.muted)
                }
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
                RuntimeLocalizedText(model.connectionTitle)
                    .lineLimit(1)
            }
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, horizontalSizeClass == .compact ? 10 : 12)
            .frame(minHeight: horizontalSizeClass == .compact ? 40 : 44)
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
                .frame(
                    width: horizontalSizeClass == .compact ? 40 : 44,
                    height: horizontalSizeClass == .compact ? 40 : 44
                )
                .background(IPalette.paperSecondary, in: Circle())
                .overlay {
                    Circle().stroke(IPalette.rule, lineWidth: 0.5)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("打开设置"))
    }

    private var connectionColor: Color {
        if model.wifiCamera.isConnected { return IPalette.positive }
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
            navigationButton(.devices)
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
                RuntimeLocalizedText(section.rawValue)
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
        HStack(spacing: 4) {
            ForEach(AppSection.allCases) { section in
                let accent = section == .monitor
                    ? (model.section == .monitor ? IPalette.cobalt : IPalette.video)
                    : IPalette.cobalt
                Button {
                    model.section = section
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: section.icon)
                            .font(.system(size: 18, weight: model.section == section ? .semibold : .medium))
                        RuntimeLocalizedText(section.rawValue)
                            .font(.caption2)
                    }
                    .foregroundStyle(model.section == section ? accent : IPalette.muted)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 50)
                    .background(
                        model.section == section
                            ? accent.opacity(0.09)
                            : Color.clear,
                        in: RoundedRectangle(cornerRadius: 12)
                    )
                    .overlay(alignment: .top) {
                        Capsule()
                            .fill(model.section == section ? accent : .clear)
                            .frame(width: 22, height: 3)
                            .offset(y: -3)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(
                    model.section == section ? .isSelected : []
                )
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 7)
        .padding(.bottom, max(7, bottomInset))
        .background(model.section == .monitor ? Color.black : IPalette.surface)
        .overlay(alignment: .top) {
            Rectangle().fill(IPalette.rule).frame(height: 0.5)
        }
    }
}

private struct GlobalStatusBar: View {
    @EnvironmentObject private var model: AppModel
    let bottomInset: CGFloat

    private var connected: Bool {
        model.camera.state == .ready || model.wifiCamera.isConnected
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: connected ? "link" : "info.circle")
                .foregroundStyle(connected ? IPalette.positive : IPalette.muted)
            RuntimeLocalizedText(model.statusMessage)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("文件库 · \(model.library.items.count) 个文件")
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .foregroundStyle(IPalette.muted)
        }
        .font(.system(size: 11, weight: .medium, design: .monospaced))
        .foregroundStyle(IPalette.ink.opacity(0.8))
        .padding(.horizontal, 14)
        .padding(.top, 8)
        .padding(.bottom, max(8, bottomInset))
        // Keep the home indicator visible in the light capture shell while
        // still following the monitor's forced dark appearance automatically.
        .background(IPalette.surface)
        .overlay(alignment: .top) {
            Rectangle().fill(IPalette.rule).frame(height: 0.5)
        }
        .accessibilityElement(children: .combine)
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
        case .devices: MyDevicesPage()
        }
    }
}

private struct MyDevicesPage: View {
    @EnvironmentObject private var model: AppModel

    private let cardColumns = [
        GridItem(.adaptive(minimum: 280, maximum: 420), spacing: 16)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("我的设备")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(IPalette.ink)
                    Text("管理连接过的相机，轻触即可快速重连")
                        .foregroundStyle(IPalette.muted)
                }

                if model.rememberedDevices.devices.isEmpty {
                    ContentUnavailableView(
                        "尚未连接过设备",
                        systemImage: "camera.badge.clock",
                        description: Text("成功连接相机后会自动保存在这里。")
                    )
                    .frame(maxWidth: .infinity, minHeight: 360)
                    .background(
                        IPalette.surface,
                        in: RoundedRectangle(cornerRadius: 22)
                    )
                } else {
                    LazyVGrid(columns: cardColumns, spacing: 16) {
                        ForEach(model.rememberedDevices.devices) { device in
                            RememberedDeviceCard(device: device)
                        }
                    }
                }
            }
            .padding(22)
        }
        .background(IPalette.paper)
    }
}

private struct RememberedDeviceCard: View {
    @EnvironmentObject private var model: AppModel
    let device: RememberedCameraDevice

    private var isConnected: Bool {
        model.camera.state == .ready
            && model.camera.selectedDeviceID == device.id
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Image(device.imageAssetName)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .frame(height: 170)
                .clipped()
                .overlay(alignment: .topTrailing) {
                    Text(device.vendor)
                        .font(.caption2.monospaced().weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 6)
                        .background(.black.opacity(0.58), in: Capsule())
                        .padding(12)
                }

            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    Text(device.name)
                        .font(.headline)
                        .foregroundStyle(IPalette.ink)
                        .lineLimit(1)
                    Spacer()
                    if isConnected {
                        Label("当前已连接", systemImage: "checkmark.circle.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(IPalette.positive)
                    }
                }
                Label(device.transport, systemImage: "cable.connector")
                    .font(.subheadline)
                    .foregroundStyle(IPalette.muted)
                HStack(spacing: 4) {
                    Text("最近连接")
                    Text("·")
                    Text(
                        device.lastConnectedAt.formatted(
                            date: .abbreviated,
                            time: .shortened
                        )
                    )
                }
                .font(.caption.monospacedDigit())
                .foregroundStyle(IPalette.muted)

                HStack(spacing: 10) {
                    Button {
                        model.camera.connect(deviceID: device.id)
                    } label: {
                        Label(
                            model.camera.state == .connecting
                                ? "正在连接…"
                                : "快速连接",
                            systemImage: "bolt.horizontal.circle.fill"
                        )
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isConnected || model.camera.state == .connecting)

                    Button(role: .destructive) {
                        model.rememberedDevices.forget(device)
                    } label: {
                        Image(systemName: "trash")
                            .frame(width: 38, height: 34)
                    }
                    .buttonStyle(.bordered)
                    .accessibilityLabel(Text("忘记设备"))
                }
            }
            .padding(16)
        }
        .background(IPalette.surface, in: RoundedRectangle(cornerRadius: 20))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(isConnected ? IPalette.positive : IPalette.rule, lineWidth: 1)
        )
        .shadow(color: IPalette.shadow.opacity(0.45), radius: 10, y: 4)
    }
}

private enum EditorAdjustmentSection: String, CaseIterable, Identifiable {
    case light = "光线"
    case color = "色彩"
    case wheels = "色轮"
    case curves = "曲线"
    case picker = "取色器"
    case mask = "蒙版"
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
    private static let usageCountKey = "ai_usage_count"
    private static let serverRemainingKey = "ai_server_remaining"
    private static let activationStateKey = "ai_verified_activation_state"
    private static let maxUsage = 100
    private static let deviceIdKeychainService = "com.tauber.nikonlink.ai-device-id"
    private static let deviceIdKeychainAccount = "ai_device_id"
    private static let stableDeviceId: String = {
        if let existing = UserDefaults.standard.string(forKey: dk), !existing.isEmpty {
            saveDeviceIdToKeychain(existing)
            return existing
        }
        if let existing = loadDeviceIdFromKeychain(), !existing.isEmpty {
            UserDefaults.standard.set(existing, forKey: dk)
            return existing
        }
        let id = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        UserDefaults.standard.set(id, forKey: dk)
        saveDeviceIdToKeychain(id)
        return id
    }()
    static var isActivated: Bool {
        if let state = UserDefaults.standard.dictionary(forKey: activationStateKey),
           let remaining = state["remaining"] as? Int,
           let code = state["code"] as? String,
           let boundDeviceId = state["deviceId"] as? String {
            return !code.isEmpty && boundDeviceId == deviceId && remaining > 0
        }
        return UserDefaults.standard.bool(forKey: ak) && remainingUsage > 0
    }
    static var remainingUsage: Int {
        if let state = UserDefaults.standard.dictionary(forKey: activationStateKey),
           let remaining = state["remaining"] as? Int {
            return max(0, min(maxUsage, remaining))
        }
        if let server = UserDefaults.standard.object(forKey: serverRemainingKey) as? Int {
            return max(0, min(maxUsage, server))
        }
        return max(0, maxUsage - UserDefaults.standard.integer(forKey: usageCountKey))
    }
    static func updateServerRemaining(_ remaining: Int) {
        let bounded = max(0, min(maxUsage, remaining))
        let defaults = UserDefaults.standard
        if var state = defaults.dictionary(forKey: activationStateKey) {
            state["remaining"] = bounded
            state["activated"] = bounded > 0
            defaults.set(state, forKey: activationStateKey)
        }
        defaults.set(bounded, forKey: serverRemainingKey)
        if bounded <= 0 { defaults.set(false, forKey: ak) }
    }
    static func recordUsageFallback() {
        let count = UserDefaults.standard.integer(forKey: usageCountKey) + 1
        UserDefaults.standard.set(count, forKey: usageCountKey)
        if let server = UserDefaults.standard.object(forKey: serverRemainingKey) as? Int {
            updateServerRemaining(server - 1)
        }
        if count >= maxUsage { UserDefaults.standard.set(false, forKey: ak) }
    }
    static var deviceId: String {
        stableDeviceId
    }
    static func verify(code: String, deviceId: String) -> Bool {
        let t = code.trimmingCharacters(in: .whitespacesAndNewlines)
        let did = deviceId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty, !did.isEmpty else { return false }
        let p = t.components(separatedBy: "-")
        guard p.count >= 4, p[0] == "ZENCHE", p[1] == "AI" else { return false }
        let exp = p.last ?? "19700101"
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.dateFormat = "yyyyMMdd"
        df.isLenient = false
        guard exp.count == 8,
              let ed = df.date(from: exp),
              df.string(from: ed) == exp,
              Calendar.current.startOfDay(for: ed) >= Calendar.current.startOfDay(for: Date())
        else { return false }
        let sigPart = p[2..<(p.count - 1)].joined(separator: "-")
        guard let sig = Data(base64Encoded: sigPart), let pk = publicKey else { return false }
        let payload = "\(did):\(exp):a1b2c3d4e5f6"
        guard let pd = payload.data(using: .utf8) else { return false }
        var err: Unmanaged<CFError>?
        return SecKeyVerifySignature(
            pk,
            .rsaSignatureMessagePKCS1v15SHA256,
            pd as CFData,
            sig as CFData,
            &err
        )
    }
    static func verifyAndActivate(code: String) -> Bool {
        let t = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard verify(code: t, deviceId: deviceId) else { return false }
        storeVerifiedActivation(code: t, remaining: maxUsage)
        return true
    }
    static func storeVerifiedActivation(code: String, remaining: Int) {
        let bounded = max(0, min(maxUsage, remaining))
        let defaults = UserDefaults.standard
        // This property-list dictionary is the authoritative activation state
        // and is replaced with one UserDefaults write. Legacy keys are mirrored
        // afterward for compatibility with earlier releases.
        defaults.set([
            "code": code.trimmingCharacters(in: .whitespacesAndNewlines),
            "deviceId": deviceId,
            "remaining": bounded,
            "activated": bounded > 0
        ], forKey: activationStateKey)
        defaults.set(code.trimmingCharacters(in: .whitespacesAndNewlines), forKey: "ai_activation_code")
        defaults.set(deviceId, forKey: dk)
        defaults.set(maxUsage - bounded, forKey: usageCountKey)
        defaults.set(bounded, forKey: serverRemainingKey)
        defaults.set(bounded > 0, forKey: ak)
    }
    static var savedCode: String? {
        if let state = UserDefaults.standard.dictionary(forKey: activationStateKey),
           let code = state["code"] as? String,
           !code.isEmpty {
            return code
        }
        return UserDefaults.standard.string(forKey: "ai_activation_code")
    }
    private static func loadDeviceIdFromKeychain() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: deviceIdKeychainService,
            kSecAttrAccount as String: deviceIdKeychainAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data
        else { return nil }
        return String(data: data, encoding: .utf8)
    }
    private static func saveDeviceIdToKeychain(_ id: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: deviceIdKeychainService,
            kSecAttrAccount as String: deviceIdKeychainAccount
        ]
        let data = Data(id.utf8)
        if SecItemUpdate(
            query as CFDictionary,
            [kSecValueData as String: data] as CFDictionary
        ) == errSecItemNotFound {
            var item = query
            item[kSecValueData as String] = data
            item[kSecAttrAccessible as String] =
                kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            SecItemAdd(item as CFDictionary, nil)
        }
    }
    private static var publicKey: SecKey? {
        let k = ["MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAngqgOi5fjajCPusMNsfB","FdMmWyzAGArL5bA+JK/uW+Md/YDtGvXjgSodev7VOQ9SPWqHUYA+XTpdyeCA+weL","32JhFf+8+a28DjIp7RMv962m1qXJLtcdFbiBjWGDWF+itDJGUgR5OQbxV8xDd/kj","c1ZT5ft7r2KwECUvwjKr9SAOWGJPK9oNmo9u2kW/6PbjpSEIhDH88FYloNWxpmdW","XoQ2YYAfd5sKc0CNcBFdu2oEFGFHeUufbhgkZWtDPCS299W4TuWyTDfWPx4+Raap","bcVF9RfFPa1uI7MpyrOqrGgSnuSC7HxY/B+NXm5rt4p3ZRaOzyKBiZEQ8Sg0XpKI","3wIDAQAB"].joined()
        guard let d = Data(base64Encoded: k) else { return nil }
        return SecKeyCreateWithData(d as CFData, [kSecAttrKeyClass as String: kSecAttrKeyClassPublic, kSecAttrKeyType as String: kSecAttrKeyTypeRSA, kSecAttrKeySizeInBits as String: 2048] as CFDictionary, nil)
    }
}

enum AiRebindError: LocalizedError {
    case invalidEndpoint
    case responseTooLarge
    case malformedResponse
    case server(Int, String?)

    var errorDescription: String? {
        switch self {
        case .invalidEndpoint:
            return "设备码恢复地址无效"
        case .responseTooLarge:
            return "设备码恢复响应过大"
        case .malformedResponse:
            return "设备码恢复响应无效"
        case .server(let status, let message):
            if let message, !message.isEmpty { return message }
            return "设备码恢复服务返回错误（\(status)）"
        }
    }
}

enum AiRebindService {
    private static let endpoint = URL(string: "https://zenche.top/api/v1/ai/rebind")
    private static let maximumResponseBytes = 64 * 1024

    struct Result {
        let newCode: String
        let remaining: Int
    }

    static func rebind(
        oldCode: String,
        oldDeviceId: String,
        newDeviceId: String
    ) async throws -> Result {
        guard let endpoint else { throw AiRebindError.invalidEndpoint }
        let payload: [String: String] = [
            "activationCode": oldCode,
            "oldDeviceId": oldDeviceId,
            "newDeviceId": newDeviceId
        ]
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        var data = Data()
        data.reserveCapacity(4096)
        for try await byte in bytes {
            guard data.count < maximumResponseBytes else {
                throw AiRebindError.responseTooLarge
            }
            data.append(byte)
        }
        guard let http = response as? HTTPURLResponse else {
            throw AiRebindError.malformedResponse
        }
        let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard (200..<300).contains(http.statusCode) else {
            throw AiRebindError.server(http.statusCode, object?["error"] as? String)
        }
        guard let newCode = object?["newCode"] as? String,
              !newCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let remaining = object?["remaining"] as? Int,
              (0...100).contains(remaining)
        else {
            throw AiRebindError.malformedResponse
        }
        return Result(
            newCode: newCode.trimmingCharacters(in: .whitespacesAndNewlines),
            remaining: remaining
        )
    }
}

private final class AiImageService {
    private static let requestTimeout: TimeInterval = 300

    private static var serverURL: String {
        UserDefaults.standard.string(forKey: "aiServerURL") ?? "http://101.34.255.115:8787"
    }
    private static var endpoint: URL? {
        URL(string: "\(serverURL.trimmingCharacters(in: .whitespacesAndNewlines))/v1/ai")
    }
    struct Result {
        let data: Data
        let remainingUsage: Int?
    }

    func generate(
        prompt: String,
        src: Data?,
        sourceFilename: String?,
        size: String,
        activationCode: String,
        deviceId: String
    ) async throws -> Result {
        guard let url = Self.endpoint else { throw AiError.invalidEndpoint }
        var body: [String: Any] = [
            "activationCode": activationCode,
            "deviceId": deviceId,
            "prompt": prompt,
            "size": size
        ]
        if let s = src, !s.isEmpty {
            let ext = (sourceFilename as NSString?)?.pathExtension.lowercased() ?? "jpg"
            let mime: String
            switch ext {
            case "png": mime = "image/png"
            case "heic", "heif": mime = "image/heic"
            case "tif", "tiff": mime = "image/tiff"
            case "bmp": mime = "image/bmp"
            default: mime = "image/jpeg"
            }
            body["image"] = "data:\(mime);base64,\(s.base64EncodedString())"
        }
        var r = URLRequest(url: url); r.httpMethod = "POST"
        r.setValue("application/json", forHTTPHeaderField: "Content-Type")
        r.timeoutInterval = Self.requestTimeout
        r.httpBody = try JSONSerialization.data(withJSONObject: body)
        let data: Data
        let resp: URLResponse
        do {
            (data, resp) = try await URLSession.shared.data(for: r)
        } catch let error as URLError where error.code == .timedOut {
            throw AiError.requestTimedOut
        }
        guard let hr = resp as? HTTPURLResponse else { throw AiError.networkError }
        guard (200..<300).contains(hr.statusCode) else {
            if hr.statusCode == 403 { throw AiError.invalidActivationCode }
            if hr.statusCode == 502 { throw AiError.serverUnavailable }
            if hr.statusCode == 429 { throw AiError.rateLimited }
            let message = (try? JSONSerialization.jsonObject(with: data))
                .flatMap { $0 as? [String: Any] }?["error"] as? String
            throw AiError.serverError(hr.statusCode, message)
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let arr = json["data"] as? [[String: Any]], let f = arr.first else { throw AiError.noImageReturned }
        let remaining = hr.value(forHTTPHeaderField: "X-ZENCHE-Remaining").flatMap(Int.init)
        if let b64 = f["b64_json"] as? String, let d = Data(base64Encoded: b64) {
            return Result(data: d, remainingUsage: remaining)
        }
        if let u = f["url"] as? String, let url = URL(string: u) {
            let (d, _) = try await URLSession.shared.data(from: url)
            return Result(data: d, remainingUsage: remaining)
        }
        throw AiError.noImageReturned
    }
}

enum AiError: LocalizedError {
    case missingActivation, invalidActivationCode, invalidEndpoint, networkError
    case serverError(Int, String?), rateLimited, noImageReturned
    case serverUnavailable, requestTimedOut
    var errorDescription: String? {
        switch self {
        case .missingActivation: "请先在设置中输入激活码解锁 AI 功能"
        case .invalidActivationCode: "激活码无效或已过期，请联系开发者"
        case .invalidEndpoint: "API 端点地址无效"
        case .networkError: "网络连接失败"
        case .serverError(let c, let message):
            if let message, !message.isEmpty {
                "AI 服务返回错误（\(c)）：\(message)"
            } else {
                "AI 服务返回错误（\(c)）"
            }
        case .rateLimited: "请求太频繁，请稍后重试"
        case .noImageReturned: "AI 未返回有效图片"
        case .serverUnavailable: "AI 服务暂不可用，请稍后重试"
        case .requestTimedOut: "AI 生成超时，请稍后重试"
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

private struct EditorMaskPoint: Equatable {
    var x: Double
    var y: Double
}

private enum EditorMaskBrushMode: String {
    case add = "添加"
    case subtract = "减去"
}

private struct EditorMaskStroke: Identifiable, Equatable {
    let id = UUID()
    var points: [EditorMaskPoint]
    var mode: EditorMaskBrushMode
    var size: Double
}

private struct EditorMaskLayer: Identifiable, Equatable {
    var id = UUID()
    var name: String
    var isVisible = true
    var type = "画笔"
    var amount = 100.0
    var feather = 55.0
    var invert = false
    var brushMode = EditorMaskBrushMode.add
    var brushSize = 18.0
    var strokes: [EditorMaskStroke] = []
    var exposure = 0.0
    var contrast = 0.0
    var highlights = 0.0
    var shadows = 0.0
    var temperature = 0.0
    var tint = 0.0
    var saturation = 0.0
    var clarity = 0.0
}

private let editorSmartMaskKernel = CIColorKernel(source: """
kernel vec4 zencheSmartMask(__sample pixel, float kind, vec2 origin, vec2 size) {
    vec2 uv = (destCoord() - origin) / max(size, vec2(1.0));
    float r = pixel.r;
    float g = pixel.g;
    float b = pixel.b;
    float luma = dot(pixel.rgb, vec3(0.2126, 0.7152, 0.0722));
    float chroma = max(r, max(g, b)) - min(r, min(g, b));
    vec2 centered = vec2((uv.x - 0.5) / 0.72, (uv.y - 0.48) / 0.82);
    float centerPrior = 1.0 - clamp(length(centered), 0.0, 1.0);
    float subject = clamp(centerPrior * 0.72 + chroma * 0.72 + abs(luma - 0.5) * 0.18, 0.0, 1.0);
    float topY = 1.0 - uv.y;
    float topPrior = clamp((0.76 - topY) / 0.62, 0.0, 1.0);
    float skyColor = clamp((b - r * 0.88) * 2.5 + (b - g * 0.78) * 1.6 + 0.18, 0.0, 1.0);
    float sky = topPrior * skyColor * smoothstep(0.18, 0.82, luma);
    float skin = smoothstep(0.02, 0.20, r - b) * smoothstep(-0.05, 0.16, r - g) * smoothstep(0.16, 0.78, luma);
    float person = clamp(skin * 0.78 + subject * centerPrior * 0.42, 0.0, 1.0);
    float value = subject;
    if (kind > 1.5 && kind < 2.5) value = sky;
    if (kind > 2.5 && kind < 3.5) value = 1.0 - subject;
    if (kind > 3.5 && kind < 4.5) value = person;
    if (kind > 4.5 && kind < 5.5) value = smoothstep(0.55, 0.88, luma);
    if (kind > 5.5) value = 1.0 - smoothstep(0.12, 0.48, luma);
    return vec4(value, value, value, 1.0);
}
""")

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
    // DaVinci-inspired secondary grading tools.
    var wheelLift = 0.0
    var wheelGamma = 0.0
    var wheelGain = 0.0
    var wheelLiftX = 0.0
    var wheelLiftY = 0.0
    var wheelGammaX = 0.0
    var wheelGammaY = 0.0
    var wheelGainX = 0.0
    var wheelGainY = 0.0
    var curveContrast = 0.0
    var curvePivot = 50.0
    var curvePoints: [EditorCurvePoint] = EditorCurvePoint.defaults
    var maskEnabled = false
    var maskFeather = 55.0
    var maskBrushMode = EditorMaskBrushMode.add
    var maskBrushSize = 18.0
    var maskStrokes: [EditorMaskStroke] = []
    var maskType = "画笔"
    var maskAmount = 100.0
    var maskInvert = false
    var maskExposure = 0.0
    var maskContrast = 0.0
    var maskHighlights = 0.0
    var maskShadows = 0.0
    var maskTemperature = 0.0
    var maskTint = 0.0
    var maskSaturation = 0.0
    var maskClarity = 0.0
    var maskLayers: [EditorMaskLayer] = []
    var activeMaskLayerID: UUID?
    var nextMaskNumber = 1
    var rotation = 0
    var flipHorizontal = false
    var flipVertical = false
    var cropRatio = EditorCropRatio.original

    var activeMaskLayerIsVisible: Bool {
        guard let id = activeMaskLayerID,
              let layer = maskLayers.first(where: { $0.id == id })
        else { return false }
        return layer.isVisible
    }

    mutating func createMaskLayer(type: String = "画笔") {
        persistActiveMaskLayer()
        let layer = EditorMaskLayer(
            name: "\(String(localized: "蒙版")) \(nextMaskNumber)",
            type: type
        )
        nextMaskNumber += 1
        maskLayers.append(layer)
        loadMaskLayer(layer)
    }

    mutating func ensureMaskLayer() {
        if activeMaskLayerID == nil || !maskEnabled {
            createMaskLayer()
        }
    }

    mutating func selectMaskLayer(_ id: UUID) {
        guard id != activeMaskLayerID,
              let layer = maskLayers.first(where: { $0.id == id })
        else { return }
        persistActiveMaskLayer()
        loadMaskLayer(layer)
    }

    mutating func deleteActiveMaskLayer() {
        guard let id = activeMaskLayerID,
              let index = maskLayers.firstIndex(where: { $0.id == id })
        else { return }
        persistActiveMaskLayer()
        maskLayers.remove(at: index)
        if maskLayers.isEmpty {
            maskEnabled = false
            maskType = ""
            maskStrokes.removeAll()
            activeMaskLayerID = nil
        } else {
            loadMaskLayer(maskLayers[min(index, maskLayers.count - 1)])
        }
    }

    mutating func setMaskLayerVisible(_ id: UUID, _ isVisible: Bool) {
        persistActiveMaskLayer()
        guard let index = maskLayers.firstIndex(where: { $0.id == id }) else {
            return
        }
        maskLayers[index].isVisible = isVisible
    }

    func displayedMaskLayer(_ layer: EditorMaskLayer) -> EditorMaskLayer {
        guard layer.id == activeMaskLayerID else { return layer }
        return maskLayerSnapshot(identity: layer)
    }

    func effectiveMaskLayers() -> [EditorMaskLayer] {
        maskLayers.map(displayedMaskLayer)
    }

    func activeDisplayedMaskLayer() -> EditorMaskLayer? {
        guard let id = activeMaskLayerID,
              let layer = maskLayers.first(where: { $0.id == id })
        else { return nil }
        return displayedMaskLayer(layer)
    }

    private mutating func persistActiveMaskLayer() {
        guard let id = activeMaskLayerID,
              let index = maskLayers.firstIndex(where: { $0.id == id })
        else { return }
        maskLayers[index] = maskLayerSnapshot(identity: maskLayers[index])
    }

    private func maskLayerSnapshot(
        identity: EditorMaskLayer
    ) -> EditorMaskLayer {
        EditorMaskLayer(
            id: identity.id,
            name: identity.name,
            isVisible: identity.isVisible,
            type: maskType,
            amount: maskAmount,
            feather: maskFeather,
            invert: maskInvert,
            brushMode: maskBrushMode,
            brushSize: maskBrushSize,
            strokes: maskStrokes,
            exposure: maskExposure,
            contrast: maskContrast,
            highlights: maskHighlights,
            shadows: maskShadows,
            temperature: maskTemperature,
            tint: maskTint,
            saturation: maskSaturation,
            clarity: maskClarity
        )
    }

    private mutating func loadMaskLayer(_ layer: EditorMaskLayer) {
        maskEnabled = true
        activeMaskLayerID = layer.id
        maskType = layer.type
        maskAmount = layer.amount
        maskFeather = layer.feather
        maskInvert = layer.invert
        maskBrushMode = layer.brushMode
        maskBrushSize = layer.brushSize
        maskStrokes = layer.strokes
        maskExposure = layer.exposure
        maskContrast = layer.contrast
        maskHighlights = layer.highlights
        maskShadows = layer.shadows
        maskTemperature = layer.temperature
        maskTint = layer.tint
        maskSaturation = layer.saturation
        maskClarity = layer.clarity
    }

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
    @StateObject private var branchStore = LibraryBranchStore()
    @State private var selectedItemID: LibraryItem.ID?
    @State private var selectedSection = EditorAdjustmentSection.light
    @State private var settings = ProfessionalEditSettings()
    @State private var selectedPreset = EditorPreset.original
    @State private var selectedNikonCloudPresetID: String?
    @State private var showingOriginal = false
    @State private var status = "请选择文件库中的照片"
    @State private var isSaving = false
    @State private var aiIntensity = 0.72
    @State private var aiSummaryKey = "等待分析当前照片"
    @State private var settingsBeforeAI: ProfessionalEditSettings?
    @State private var aiAnalysis: EditorAIAnalysis?
    @State private var copiedAISettings: ProfessionalEditSettings?
    @State private var activeCurvePoint: Int?
    @State private var activeMaskStrokeID: UUID?
    private let context = CIContext()
    @State private var aiMode = AiImageMode.edit
    @State private var aiPrompt = ""
    @State private var aiManualPrompt = ""
    @State private var aiSelectedPresets: Set<String> = []
    @State private var aiRatio = AiAspectRatio.square
    @State private var aiResolution = AiResolution.k1
    @State private var aiResultImage: UIImage?
    @State private var aiIsGenerating = false
    @State private var pickerSample = "—"
    @State private var pickerColor = Color.white.opacity(0.12)
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

    private var selectedNikonCloudPreset: NikonCloudPreset? {
        guard let selectedNikonCloudPresetID else { return nil }
        return NikonCloudPresetLibrary.presets.first {
            $0.id == selectedNikonCloudPresetID
        }
    }

    @ViewBuilder
    private var editorPhotoPicker: some View {
        Menu {
            Button {
                selectedItemID = nil
            } label: {
                Label("选择照片", systemImage: "photo.on.rectangle")
            }
            let unclassified = photos.filter {
                branchStore.branchID(for: $0.id) == nil
            }
            if !unclassified.isEmpty {
                Menu("未分类 · \(unclassified.count)") {
                    ForEach(unclassified) { item in
                        editorPhotoMenuItem(item)
                    }
                }
            }
            ForEach(branchStore.branches) { branch in
                editorBranchMenu(branch, depth: 0)
            }
        } label: {
            HStack(spacing: 8) {
                if let item = selectedItem,
                   let image = UIImage(contentsOfFile: item.url.path) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 42, height: 30)
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                } else {
                    Image(systemName: "photo.on.rectangle")
                }
                Text(selectedItem?.filename ?? "选择照片")
                    .lineLimit(1)
            }
        }
        .menuStyle(.automatic)
    }

    @ViewBuilder
    private func editorPhotoMenuItem(_ item: LibraryItem) -> some View {
        Button {
            selectedItemID = item.id
        } label: {
            HStack(spacing: 8) {
                if let image = UIImage(contentsOfFile: item.url.path) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 48, height: 34)
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                } else {
                    Image(systemName: "photo")
                        .frame(width: 48, height: 34)
                }
                Text(item.filename)
                    .lineLimit(1)
                if selectedItemID == item.id {
                    Image(systemName: "checkmark")
                }
            }
        }
    }

    private func editorBranchMenu(
        _ branch: UserLibraryBranch,
        depth: Int
    ) -> AnyView {
        let assigned = photos.filter {
            branchStore.branchID(for: $0.id) == branch.id
        }
        return AnyView(Menu("\(String(repeating: "  ", count: depth))分支 · \(branch.name) · \(assigned.count)") {
            if assigned.isEmpty && branch.children.isEmpty {
                Text("此分支暂无可编辑照片")
            }
            ForEach(assigned) { item in
                editorPhotoMenuItem(item)
            }
            ForEach(branch.children) { child in
                editorBranchMenu(child, depth: depth + 1)
            }
        })
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
                if selectedSection == .aiTools {
                    aiToolsToolbar
                } else {
                    editorToolbar
                    nikonCloudPreviewNotice
                }
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
            aiResultImage = nil
            resetAdjustments()
            status = selectedItem == nil
                ? "请选择文件库中的照片"
                : "调整不会覆盖原文件"
        }
    }

    private var aiToolsToolbar: some View {
        HStack(spacing: 10) {
            editorPhotoPicker.frame(maxWidth: 340, alignment: .leading)
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
                    Text("修图覆盖原图 · 生图保存新文件")
                        .font(.caption)
                        .foregroundStyle(IPalette.muted)
                }
                Spacer()
                Text(ActivationManager.isActivated ? "已解锁 · 剩余 \(ActivationManager.remainingUsage) 次" : "需要激活")
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
                        composeAiPrompt()
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
                TextField(aiMode == .edit ? "输入修图描述…（可补充）" : "输入生图描述…（可补充）", text: Binding(
                    get: { aiManualPrompt },
                    set: { aiManualPrompt = $0; composeAiPrompt() }
                ), axis: .vertical)
                    .lineLimit(3...6).textFieldStyle(.roundedBorder)
            }
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("可组合预设").font(.caption.weight(.semibold))
                    Spacer()
                    Button("清空") { aiSelectedPresets.removeAll(); aiManualPrompt = ""; composeAiPrompt() }
                        .buttonStyle(.bordered).frame(minHeight: 44)
                }
                ForEach(aiModules, id: \.0) { module in
                    Text(module.0).font(.caption2.weight(.semibold)).foregroundStyle(IPalette.muted)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(module.1, id: \.self) { value in
                                let key = "\(module.0):\(value)"
                                Button(value) {
                                    let selected = aiSelectedPresets.contains(key)
                                    aiSelectedPresets = aiSelectedPresets.filter { !$0.hasPrefix("\(module.0):") }
                                    if !selected { aiSelectedPresets.insert(key) }
                                    composeAiPrompt()
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(aiSelectedPresets.contains(key) ? IPalette.cobalt : IPalette.surface)
                                .foregroundStyle(aiSelectedPresets.contains(key) ? Color.white : IPalette.ink)
                                .frame(minHeight: 44)
                            }
                        }
                    }
                }
                Text("最终提示词：\(aiPrompt.isEmpty ? "—" : aiPrompt)").font(.caption2.monospaced()).foregroundStyle(IPalette.muted).lineLimit(3)
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
                    Label(aiIsGenerating ? "正在生成…" : "生成图像", systemImage: "sparkles")
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

    private var aiModules: [(String, [String])] {
        var modules: [(String, [String])] = [
            ("主体", ["人像主体", "产品主体", "建筑主体", "风光主体", "食物主体"]),
            ("光线", ["柔和自然光", "电影感侧光", "金色时刻", "低调棚拍光", "夜景霓虹光"]),
            ("色彩", ["自然通透", "胶片暖调", "日系清新", "高反差黑白", "冷色城市"]),
            ("质感", ["保留真实皮肤纹理", "细节清晰", "轻微胶片颗粒", "柔和高光", "高动态范围"]),
            ("构图", ["浅景深", "干净背景", "对称构图", "环境叙事", "视觉焦点明确"])
        ]
        if aiMode == .edit {
            modules.append(("智能移除", [
                "去路人并自然补全背景",
                "去穿帮并移除摄影器材、工作人员、反光与杂物"
            ]))
            modules.append(("约束", [
                "保持人物身份和五官", "不改变产品形状", "不添加多余物体",
                "不过度磨皮", "保留自然阴影"
            ]))
        }
        return modules
    }

    private func composeAiPrompt() {
        var parts: [String] = []
        if !aiManualPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { parts.append(aiManualPrompt.trimmingCharacters(in: .whitespacesAndNewlines)) }
        for category in aiModules.map(\.0) {
            let values = aiSelectedPresets.filter { $0.hasPrefix("\(category):") }.map { String($0.dropFirst(category.count + 1)) }
            if !values.isEmpty { parts.append("\(category)：\(values.joined(separator: "、"))") }
        }
        aiPrompt = parts.joined(separator: "。")
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
                        selectedNikonCloudPresetID = nil
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
            editorPhotoPicker.frame(maxWidth: 340, alignment: .leading)

            Menu {
                ForEach(EditorPreset.allCases) { preset in
                    Button(LocalizedStringKey(preset.rawValue)) {
                        selectedPreset = preset
                        selectedNikonCloudPresetID = nil
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

            Menu {
                Button {
                    selectedNikonCloudPresetID = nil
                    settings.apply(.original)
                    selectedPreset = .original
                    showingOriginal = false
                    status = "尼康云创预览已关闭"
                } label: {
                    Label("关闭云创预览", systemImage: "xmark.circle")
                }
                Divider()
                ForEach(NikonCloudPresetLibrary.groups) { group in
                    Menu(group.title) {
                        ForEach(group.presets) { preset in
                            Button {
                                applyNikonCloudPreset(preset)
                            } label: {
                                HStack {
                                    Text(preset.name)
                                    if selectedNikonCloudPresetID == preset.id {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    }
                }
            } label: {
                Label(
                    selectedNikonCloudPreset?.name ?? "尼康云创",
                    systemImage: "cloud.sun"
                )
                .lineLimit(1)
            }
            .buttonStyle(.borderedProminent)
            .disabled(NikonCloudPresetLibrary.presets.isEmpty)

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

    private var nikonCloudPreviewNotice: some View {
        HStack(spacing: 10) {
            Label("尼康云创预览", systemImage: "camera.filters")
                .font(.subheadline.weight(.semibold))
            Text("内置 \(NikonCloudPresetLibrary.presets.count) 款 NP3")
                .font(.caption.monospacedDigit())
                .foregroundStyle(IPalette.muted)
            Spacer()
            Text("设备端 SDR 近似预览 · 相机与 NX Studio 成片可能不同")
                .font(.caption)
                .foregroundStyle(IPalette.muted)
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 44)
        .background(IPalette.cobaltSoft.opacity(0.55), in: RoundedRectangle(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .stroke(IPalette.cobalt.opacity(0.28))
        }
    }

    private var preview: some View {
        GeometryReader { proxy in
            let image = selectedSection == .aiTools
                ? (aiResultImage ?? (aiMode == .edit ? selectedOriginalImage : nil))
                : renderedImage
            let imageRect = editorImageRect(
                in: proxy.size,
                imageSize: image?.size
            )
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 18)
                    .fill(IPalette.graphite)
                if let image {
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
                if selectedSection == .mask,
                   settings.maskEnabled,
                   settings.activeMaskLayerIsVisible,
                   !showingOriginal {
                    maskStrokeOverlay(in: imageRect)
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
                } else if image != nil {
                    Text(aiResultImage != nil ? "AI 生成" : "原图")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .frame(minHeight: 30)
                        .background(.black.opacity(0.58))
                        .clipShape(Capsule())
                        .padding(12)
                }
            }
            .coordinateSpace(name: "editorPreview")
            .contentShape(Rectangle())
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 300, idealHeight: 460, maxHeight: 560)
    }

    private func editorImageRect(
        in container: CGSize,
        imageSize: CGSize?
    ) -> CGRect {
        let available = CGRect(origin: .zero, size: container).insetBy(
            dx: 12,
            dy: 12
        )
        guard let imageSize, imageSize.width > 0, imageSize.height > 0 else {
            return available
        }
        let scale = min(
            available.width / imageSize.width,
            available.height / imageSize.height
        )
        let size = CGSize(
            width: imageSize.width * scale,
            height: imageSize.height * scale
        )
        return CGRect(
            x: available.midX - size.width / 2,
            y: available.midY - size.height / 2,
            width: size.width,
            height: size.height
        )
    }

    @ViewBuilder
    private func maskStrokeOverlay(in imageRect: CGRect) -> some View {
        if let overlay = activeMaskOverlayImage {
            Image(uiImage: overlay)
                .resizable()
                .frame(width: imageRect.width, height: imageRect.height)
                .position(x: imageRect.midX, y: imageRect.midY)
                .allowsHitTesting(false)
        }
        Rectangle()
            .fill(Color.clear)
            .frame(width: imageRect.width, height: imageRect.height)
            .position(x: imageRect.midX, y: imageRect.midY)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(
                    minimumDistance: 0,
                    coordinateSpace: .named("editorPreview")
                )
                    .onChanged { gesture in
                        recordMaskPoint(
                            at: gesture.location,
                            imageRect: imageRect
                        )
                    }
                    .onEnded { _ in activeMaskStrokeID = nil }
            )
    }

    private func recordMaskPoint(at location: CGPoint, imageRect: CGRect) {
        guard selectedSection == .mask,
              settings.maskEnabled,
              settings.activeMaskLayerIsVisible,
              imageRect.contains(location),
              imageRect.width > 0,
              imageRect.height > 0
        else { return }
        let point = EditorMaskPoint(
            x: Double(min(max((location.x - imageRect.minX) / imageRect.width, 0), 1)),
            y: Double(min(max((location.y - imageRect.minY) / imageRect.height, 0), 1))
        )
        if let activeMaskStrokeID,
           let index = settings.maskStrokes.firstIndex(where: {
               $0.id == activeMaskStrokeID
           }) {
            settings.maskStrokes[index].points.append(point)
        } else {
            let stroke = EditorMaskStroke(
                points: [point],
                mode: settings.maskBrushMode,
                size: settings.maskBrushSize
            )
            settings.maskStrokes.append(stroke)
            activeMaskStrokeID = stroke.id
        }
        status = settings.maskBrushMode == .add
            ? "正在添加蒙版区域"
            : "正在减去蒙版区域"
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
            case .wheels:
                colorWheelsPanel
            case .curves:
                curvesPanel
            case .picker:
                pickerPanel
            case .mask:
                maskPanel
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

    private var colorWheelsPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("三向色轮 · Lift / Gamma / Gain")
                .font(.subheadline.weight(.semibold))
            HStack(spacing: 12) {
                EditorColorWheel(title: "暗部 · Lift", x: $settings.wheelLiftX, y: $settings.wheelLiftY, tint: .blue)
                EditorColorWheel(title: "中间调 · Gamma", x: $settings.wheelGammaX, y: $settings.wheelGammaY, tint: .green)
                EditorColorWheel(title: "高光 · Gain", x: $settings.wheelGainX, y: $settings.wheelGainY, tint: .orange)
            }
            Text("在圆盘内拖动色点调整对应范围")
                .font(.caption)
                .foregroundStyle(IPalette.muted)
        }
    }

    private var curvesPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("主曲线")
                .font(.subheadline.weight(.semibold))
            GeometryReader { proxy in
                ZStack {
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: proxy.size.height))
                        path.addLine(to: CGPoint(x: proxy.size.width, y: 0))
                    }
                    .stroke(IPalette.rule, style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    Path { path in
                        let samples = stride(from: 0.0, through: 1.0, by: 1.0 / 48.0).map { x in
                            CGPoint(x: x * proxy.size.width, y: (1 - curveValue(x)) * proxy.size.height)
                        }
                        guard let first = samples.first else { return }
                        path.move(to: first)
                        for point in samples.dropFirst() { path.addLine(to: point) }
                    }
                    .stroke(IPalette.cobalt, lineWidth: 3)
                    ForEach(Array(settings.curvePoints.enumerated()), id: \.offset) { index, point in
                        Circle()
                            .fill(index == activeCurvePoint ? IPalette.ink : IPalette.cobalt)
                            .frame(width: 9, height: 9)
                            .position(x: point.x * proxy.size.width, y: (1 - point.y) * proxy.size.height)
                    }
                }
                .background(IPalette.graphite)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay { RoundedRectangle(cornerRadius: 8).stroke(IPalette.rule) }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { gesture in
                            let width = max(proxy.size.width, 1)
                            let height = max(proxy.size.height, 1)
                            let x = min(max(gesture.location.x / width, 0), 1)
                            let y = min(max(1 - gesture.location.y / height, 0), 1)
                            if activeCurvePoint == nil {
                                let hit = settings.curvePoints.enumerated().min {
                                    let dx = $0.element.x - x
                                    let dy = $0.element.y - y
                                    let dx2 = $1.element.x - x
                                    let dy2 = $1.element.y - y
                                    return dx * dx + dy * dy < dx2 * dx2 + dy2 * dy2
                                }
                                if let hit, pow(hit.element.x - x, 2) + pow(hit.element.y - y, 2) < 0.035 * 0.035 {
                                    activeCurvePoint = hit.offset
                                } else {
                                    settings.curvePoints.append(EditorCurvePoint(x: x, y: y))
                                    activeCurvePoint = settings.curvePoints.count - 1
                                }
                            }
                            if let index = activeCurvePoint, settings.curvePoints.indices.contains(index) {
                                settings.curvePoints[index].x = x
                                settings.curvePoints[index].y = y
                            }
                        }
                        .onEnded { _ in
                            activeCurvePoint = nil
                        }
                )
            }
            .frame(height: 190)
            Text("点击任意位置新增控制点，拖动控制点调整曲线")
                .font(.caption)
                .foregroundStyle(IPalette.muted)
        }
    }

    private var pickerPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("颜色取样器")
                .font(.subheadline.weight(.semibold))
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(pickerColor)
                    .frame(width: 48, height: 48)
                    .overlay { RoundedRectangle(cornerRadius: 8).stroke(IPalette.rule) }
                VStack(alignment: .leading, spacing: 3) {
                    Text(pickerSample).font(.caption.monospaced())
                    Text("从当前照片中心读取 RGB")
                        .font(.caption)
                        .foregroundStyle(IPalette.muted)
                }
                Spacer()
                Button { sampleCurrentColor() } label: {
                    Label("取样", systemImage: "eyedropper")
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    private var maskPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("蒙版列表")
                .font(.subheadline.weight(.semibold))
            if settings.maskLayers.isEmpty {
                Text("暂无蒙版")
                    .font(.caption)
                    .foregroundStyle(IPalette.muted)
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            } else {
                VStack(spacing: 6) {
                    ForEach(settings.maskLayers) { layer in
                        let displayed = settings.displayedMaskLayer(layer)
                        HStack(spacing: 8) {
                            Button {
                                settings.selectMaskLayer(layer.id)
                                activeMaskStrokeID = nil
                                status = "已切换到 \(layer.name)"
                            } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(layer.name).font(.subheadline.weight(.semibold))
                                    Text(LocalizedStringKey(displayed.type))
                                        .font(.caption)
                                        .foregroundStyle(IPalette.muted)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            Toggle("", isOn: Binding(
                                get: { layer.isVisible },
                                set: { visible in
                                    settings.setMaskLayerVisible(layer.id, visible)
                                    activeMaskStrokeID = nil
                                    status = visible ? "蒙版已显示" : "蒙版已隐藏"
                                }
                            ))
                            .labelsHidden()
                            .accessibilityLabel(layer.isVisible ? "隐藏蒙版" : "显示蒙版")
                        }
                        .padding(.horizontal, 10)
                        .frame(minHeight: 48)
                        .background(
                            settings.activeMaskLayerID == layer.id
                                ? IPalette.cobalt.opacity(0.12)
                                : IPalette.surface
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay {
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(
                                    settings.activeMaskLayerID == layer.id
                                        ? IPalette.cobalt.opacity(0.45)
                                        : Color.clear,
                                    lineWidth: 1
                                )
                        }
                    }
                }
            }
            HStack(spacing: 8) {
                Button {
                    settings.createMaskLayer()
                    activeMaskStrokeID = nil
                    status = "蒙版已创建 · 在预览画面涂抹"
                } label: {
                    Label("创建蒙版", systemImage: "plus.square.on.square")
                }
                .buttonStyle(.borderedProminent)
                .tint(settings.maskEnabled ? IPalette.surface : IPalette.cobalt)
                .foregroundStyle(settings.maskEnabled ? IPalette.ink : Color.white)
                Button(role: .destructive) {
                    settings.deleteActiveMaskLayer()
                    activeMaskStrokeID = nil
                    status = "蒙版已删除"
                } label: {
                    Label("删除蒙版", systemImage: "trash")
                }
                .buttonStyle(.bordered)
                .disabled(!settings.maskEnabled)
            }
            HStack(spacing: 8) {
                Button {
                    settings.ensureMaskLayer()
                    if settings.maskType.isEmpty {
                        settings.maskType = "画笔"
                    }
                    settings.maskBrushMode = .add
                    status = "添加蒙版画笔已启用"
                } label: {
                    Label("添加蒙版（画笔）", systemImage: "paintbrush.pointed")
                }
                .buttonStyle(.borderedProminent)
                .tint(settings.maskEnabled && settings.maskBrushMode == .add ? IPalette.cobalt : IPalette.surface)
                .foregroundStyle(settings.maskEnabled && settings.maskBrushMode == .add ? Color.white : IPalette.ink)
                Button {
                    settings.ensureMaskLayer()
                    if settings.maskType.isEmpty {
                        settings.maskType = "画笔"
                    }
                    settings.maskBrushMode = .subtract
                    status = "减去蒙版画笔已启用"
                } label: {
                    Label("减去蒙版（画笔）", systemImage: "eraser")
                }
                .buttonStyle(.borderedProminent)
                .tint(settings.maskEnabled && settings.maskBrushMode == .subtract ? IPalette.cobalt : IPalette.surface)
                .foregroundStyle(settings.maskEnabled && settings.maskBrushMode == .subtract ? Color.white : IPalette.ink)
            }
            Text("智能识别")
                .font(.caption.weight(.semibold))
                .foregroundStyle(IPalette.muted)
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 104), spacing: 8)],
                spacing: 8
            ) {
                ForEach(
                    ["智能主体", "智能天空", "智能背景", "智能人物", "智能亮部", "智能暗部"],
                    id: \.self
                ) { type in
                    Button(type) {
                        settings.ensureMaskLayer()
                        settings.maskType = type
                        settings.maskAmount = 100
                        settings.maskInvert = false
                        settings.maskStrokes.removeAll()
                        activeMaskStrokeID = nil
                        status = String(localized: "智能蒙版已创建 · 可继续添加或减去画笔")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(settings.maskType == type ? IPalette.cobalt : IPalette.surface)
                    .foregroundStyle(settings.maskType == type ? Color.white : IPalette.ink)
                    .frame(minHeight: 44)
                }
            }
            editorSlider(title: "强度", value: $settings.maskAmount, range: 0...100, step: 1, formatter: { "\(Int($0))%" })
            editorSlider(title: "羽化", value: $settings.maskFeather, range: 0...100, step: 1, formatter: { "\(Int($0))%" })
            editorSlider(title: "画笔大小", value: $settings.maskBrushSize, range: 4...64, step: 1, formatter: { "\(Int($0))" })
            Button {
                settings.maskInvert.toggle()
                status = settings.maskInvert ? "蒙版已反向" : "蒙版已恢复正向"
            } label: {
                Label("反向蒙版", systemImage: "circle.lefthalf.filled.inverse")
            }
            .buttonStyle(.borderedProminent)
            .tint(settings.maskInvert ? IPalette.cobalt : IPalette.surface)
            .foregroundStyle(settings.maskInvert ? Color.white : IPalette.ink)
            .frame(minHeight: 44)
            Divider()
            Text("蒙版内调整").font(.subheadline.weight(.semibold))
            editorSlider(title: "曝光", value: $settings.maskExposure, range: -2...2, step: 0.05, formatter: { String(format: "%+.2f EV", $0) })
            standardSlider("对比度", value: $settings.maskContrast)
            standardSlider("高光", value: $settings.maskHighlights)
            standardSlider("阴影", value: $settings.maskShadows)
            standardSlider("色温", value: $settings.maskTemperature)
            standardSlider("色调", value: $settings.maskTint)
            standardSlider("饱和度", value: $settings.maskSaturation)
            standardSlider("清晰度", value: $settings.maskClarity)
            Text(settings.maskEnabled
                ? "蓝色显示当前蒙版覆盖；橡皮会擦除蓝色区域。"
                : "先创建蒙版，再选择添加或减去画笔。")
                .font(.caption)
                .foregroundStyle(IPalette.muted)
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
            output = applyGeometry(to: output)
            output = applyingEditorMask(to: output)
        }
        let extent = output.extent.integral
        guard let cgImage = context.createCGImage(output, from: extent) else {
            return nil
        }
        return UIImage(cgImage: cgImage)
    }

    private var selectedOriginalImage: UIImage? {
        guard let selectedItem else { return nil }
        return UIImage(contentsOfFile: selectedItem.url.path)
    }

    private var activeMaskOverlayImage: UIImage? {
        guard let selectedItem,
              let layer = settings.activeDisplayedMaskLayer(),
              layer.isVisible,
              !layer.type.isEmpty,
              let source = CIImage(contentsOf: selectedItem.url)
                ?? UIImage(contentsOfFile: selectedItem.url.path)
                    .flatMap({ CIImage(image: $0) })
        else { return nil }
        let base = applyGeometry(to: applyTonePipeline(to: source))
        let extent = base.extent.integral
        guard let mask = editorMaskImage(
            source: base,
            extent: extent,
            layer: layer
        ) else { return nil }
        let blue = CIImage(color: CIColor(
            red: 22.0 / 255,
            green: 115.0 / 255,
            blue: 230.0 / 255,
            alpha: 0.58
        )).cropped(to: extent)
        let clear = CIImage(color: CIColor(
            red: 0,
            green: 0,
            blue: 0,
            alpha: 0
        )).cropped(to: extent)
        let overlay = filtered(
            "CIBlendWithMask",
            image: blue,
            values: [
                kCIInputBackgroundImageKey: clear,
                kCIInputMaskImageKey: mask
            ]
        )
        guard let cgImage = context.createCGImage(overlay, from: extent) else {
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
        let blackLift = settings.blacks / 850
        let tintShift = settings.tint / 1800
        output = filtered(
            "CIColorMatrix",
            image: output,
            values: [
                "inputRVector": CIVector(x: gain, y: 0, z: 0, w: 0),
                "inputGVector": CIVector(x: 0, y: gain, z: 0, w: 0),
                "inputBVector": CIVector(x: 0, y: 0, z: gain, w: 0),
                "inputBiasVector": CIVector(
                    x: blackLift + tintShift,
                    y: blackLift - tintShift,
                    z: blackLift + tintShift,
                    w: 0
                )
            ]
        )

        output = applyingGradingCube(to: output)
        if settings.curvePoints.count > 2 {
            let dimension = 16
            var cube = [Float]()
            cube.reserveCapacity(dimension * dimension * dimension * 4)
            for blue in 0..<dimension {
                for green in 0..<dimension {
                    for red in 0..<dimension {
                        let r = Double(red) / Double(dimension - 1)
                        let g = Double(green) / Double(dimension - 1)
                        let b = Double(blue) / Double(dimension - 1)
                        let luma = r * 0.2126 + g * 0.7152 + b * 0.0722
                        let delta = curveValue(luma) - luma
                        cube += [Float(max(0, min(1, r + delta))), Float(max(0, min(1, g + delta))), Float(max(0, min(1, b + delta))), 1]
                    }
                }
            }
            let cubeData = cube.withUnsafeBufferPointer { Data(buffer: $0) }
            output = filtered("CIColorCube", image: output, values: [
                "inputCubeDimension": dimension,
                "inputCubeData": cubeData
            ])
        }

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

    private func applyingEditorMask(
        to base: CIImage
    ) -> CIImage {
        settings.effectiveMaskLayers()
            .filter { $0.isVisible && !$0.type.isEmpty }
            .reduce(base) { image, layer in
                applyingEditorMaskLayer(to: image, layer: layer)
            }
    }

    private func applyingEditorMaskLayer(
        to base: CIImage,
        layer: EditorMaskLayer
    ) -> CIImage {
        guard
              let mask = editorMaskImage(
                  source: base,
                  extent: base.extent.integral,
                  layer: layer
              )
        else { return base }
        var local = base
        if layer.exposure != 0 {
            local = filtered("CIExposureAdjust", image: local, values: [
                kCIInputEVKey: layer.exposure
            ])
        }
        if layer.temperature != 0 || layer.tint != 0 {
            local = filtered("CITemperatureAndTint", image: local, values: [
                "inputNeutral": CIVector(x: 6500, y: 0),
                "inputTargetNeutral": CIVector(
                    x: 6500 + layer.temperature * 24,
                    y: layer.tint * 1.5
                )
            ])
        }
        if layer.highlights != 0 || layer.shadows != 0 {
            local = filtered("CIHighlightShadowAdjust", image: local, values: [
                "inputHighlightAmount": max(
                    0,
                    min(2, 1 + layer.highlights / 100)
                ),
                "inputShadowAmount": layer.shadows / 100
            ])
        }
        if layer.contrast != 0 || layer.saturation != 0 {
            local = filtered("CIColorControls", image: local, values: [
                kCIInputContrastKey: max(0, 1 + layer.contrast / 100),
                kCIInputSaturationKey: max(0, 1 + layer.saturation / 100)
            ])
        }
        if layer.clarity > 0 {
            local = filtered("CIUnsharpMask", image: local, values: [
                kCIInputRadiusKey: 8,
                kCIInputIntensityKey: layer.clarity / 180
            ])
        } else if layer.clarity < 0 {
            local = filtered("CIGaussianBlur", image: local, values: [
                kCIInputRadiusKey: -layer.clarity / 70
            ]).cropped(to: base.extent)
        }
        return filtered(
            "CIBlendWithMask",
            image: local,
            values: [
                kCIInputBackgroundImageKey: base,
                kCIInputMaskImageKey: mask
            ]
        )
    }

    private func editorMaskImage(
        source: CIImage,
        extent: CGRect,
        layer: EditorMaskLayer
    ) -> CIImage? {
        let width = max(1, Int(extent.width.rounded()))
        let height = max(1, Int(extent.height.rounded()))
        let colorSpace = CGColorSpaceCreateDeviceGray()
        guard let bitmap = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else { return nil }
        bitmap.setFillColor(gray: 0, alpha: 1)
        bitmap.fill(CGRect(x: 0, y: 0, width: width, height: height))
        guard let cgMask = bitmap.makeImage() else { return nil }
        var mask = CIImage(cgImage: cgMask)
            .transformed(by: CGAffineTransform(
                translationX: extent.minX,
                y: extent.minY
            ))
        let smartKinds: [String: CGFloat] = [
            "智能主体": 1,
            "智能天空": 2,
            "智能背景": 3,
            "智能人物": 4,
            "智能亮部": 5,
            "智能暗部": 6
        ]
        if let kind = smartKinds[layer.type],
           let smart = editorSmartMaskKernel?.apply(
               extent: extent,
               arguments: [
                   source,
                   kind,
                   CIVector(x: extent.minX, y: extent.minY),
                   CIVector(x: extent.width, y: extent.height)
               ]
           ) {
            mask = smart
        }
        if let additions = editorStrokeMaskImage(
            mode: .add,
            extent: extent,
            strokes: layer.strokes
        ) {
            mask = filtered(
                "CIMaximumCompositing",
                image: mask,
                values: [kCIInputBackgroundImageKey: additions]
            )
        }
        if let removals = editorStrokeMaskImage(
            mode: .subtract,
            extent: extent,
            strokes: layer.strokes
        ) {
            let inverseRemovals = filtered("CIColorMatrix", image: removals, values: [
                "inputRVector": CIVector(x: -1, y: 0, z: 0, w: 0),
                "inputGVector": CIVector(x: 0, y: -1, z: 0, w: 0),
                "inputBVector": CIVector(x: 0, y: 0, z: -1, w: 0),
                "inputBiasVector": CIVector(x: 1, y: 1, z: 1, w: 0)
            ])
            mask = filtered(
                "CIMultiplyCompositing",
                image: mask,
                values: [kCIInputBackgroundImageKey: inverseRemovals]
            )
        }
        if layer.feather > 0 {
            mask = filtered(
                "CIGaussianBlur",
                image: mask,
                values: [
                    kCIInputRadiusKey: max(
                        0.5,
                        layer.feather / 100
                            * Double(min(width, height)) * 0.03
                    )
                ]
            ).cropped(to: extent)
        }
        if layer.invert {
            mask = filtered("CIColorMatrix", image: mask, values: [
                "inputRVector": CIVector(x: -1, y: 0, z: 0, w: 0),
                "inputGVector": CIVector(x: 0, y: -1, z: 0, w: 0),
                "inputBVector": CIVector(x: 0, y: 0, z: -1, w: 0),
                "inputBiasVector": CIVector(x: 1, y: 1, z: 1, w: 0)
            ])
        }
        if layer.amount < 100 {
            let amount = max(0, layer.amount / 100)
            mask = filtered("CIColorMatrix", image: mask, values: [
                "inputRVector": CIVector(x: amount, y: 0, z: 0, w: 0),
                "inputGVector": CIVector(x: 0, y: amount, z: 0, w: 0),
                "inputBVector": CIVector(x: 0, y: 0, z: amount, w: 0)
            ])
        }
        return mask
    }

    private func editorStrokeMaskImage(
        mode: EditorMaskBrushMode,
        extent: CGRect,
        strokes allStrokes: [EditorMaskStroke]
    ) -> CIImage? {
        let strokes = allStrokes.filter { $0.mode == mode }
        guard !strokes.isEmpty else { return nil }
        let width = max(1, Int(extent.width.rounded()))
        let height = max(1, Int(extent.height.rounded()))
        guard let bitmap = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else { return nil }
        bitmap.setFillColor(gray: 0, alpha: 1)
        bitmap.fill(CGRect(x: 0, y: 0, width: width, height: height))
        bitmap.setStrokeColor(gray: 1, alpha: 1)
        bitmap.setFillColor(gray: 1, alpha: 1)
        bitmap.setLineCap(.round)
        bitmap.setLineJoin(.round)
        for stroke in strokes {
            bitmap.setLineWidth(max(
                1,
                CGFloat(stroke.size) / 100 * CGFloat(min(width, height))
            ))
            guard let first = stroke.points.first else { continue }
            let start = CGPoint(
                x: CGFloat(first.x) * CGFloat(width),
                y: (1 - CGFloat(first.y)) * CGFloat(height)
            )
            bitmap.beginPath()
            bitmap.move(to: start)
            for point in stroke.points.dropFirst() {
                bitmap.addLine(to: CGPoint(
                    x: CGFloat(point.x) * CGFloat(width),
                    y: (1 - CGFloat(point.y)) * CGFloat(height)
                ))
            }
            bitmap.strokePath()
            if stroke.points.count == 1 {
                let radius = max(
                    0.5,
                    CGFloat(stroke.size) / 200 * CGFloat(min(width, height))
                )
                bitmap.fillEllipse(in: CGRect(
                    x: start.x - radius,
                    y: start.y - radius,
                    width: radius * 2,
                    height: radius * 2
                ))
            }
        }
        guard let image = bitmap.makeImage() else { return nil }
        return CIImage(cgImage: image).transformed(by: CGAffineTransform(
            translationX: extent.minX,
            y: extent.minY
        ))
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

    private func curveValue(_ input: Double) -> Double {
        let x = min(max(input, 0), 1)
        let points = settings.curvePoints.sorted { $0.x < $1.x }
        guard points.count > 1 else { return x }
        if x <= points[0].x { return points[0].y }
        if x >= points[points.count - 1].x { return points[points.count - 1].y }
        let index = max(1, points.firstIndex { $0.x >= x } ?? 1)
        let p0 = points[max(0, index - 2)]
        let p1 = points[index - 1]
        let p2 = points[index]
        let p3 = points[min(points.count - 1, index + 1)]
        let t = (x - p1.x) / max(0.0001, p2.x - p1.x)
        let t2 = t * t
        let t3 = t2 * t
        let y = 0.5 * ((2 * p1.y) + (-p0.y + p2.y) * t + (2 * p0.y - 5 * p1.y + 4 * p2.y - p3.y) * t2 + (-p0.y + 3 * p1.y - 3 * p2.y + p3.y) * t3)
        return min(max(y, 0), 1)
    }

    private func applyingGradingCube(to image: CIImage) -> CIImage {
        let dimension = 16
        let cloudPreset = selectedNikonCloudPreset
        var cube = [Float]()
        cube.reserveCapacity(dimension * dimension * dimension * 4)
        for blue in 0..<dimension {
            for green in 0..<dimension {
                for red in 0..<dimension {
                    var r = Double(red) / Double(dimension - 1)
                    var g = Double(green) / Double(dimension - 1)
                    var b = Double(blue) / Double(dimension - 1)
                    let luma = r * 0.2126 + g * 0.7152 + b * 0.0722
                    let shadows = pow(1 - luma, 2)
                    let midtones = 1 - abs(luma * 2 - 1)
                    let highlights = pow(luma, 2)
                    let x = settings.wheelLiftX / 800 * shadows + settings.wheelGammaX / 800 * midtones + settings.wheelGainX / 800 * highlights
                    let y = settings.wheelLiftY / 800 * shadows + settings.wheelGammaY / 800 * midtones + settings.wheelGainY / 800 * highlights
                    r += x - y * 0.5
                    g += y - x * 0.5
                    b -= (x + y) * 0.5
                    if let cloudPreset {
                        let mixed = cloudPreset.applyingColorMixer(
                            red: r,
                            green: g,
                            blue: b
                        )
                        r = mixed.red
                        g = mixed.green
                        b = mixed.blue
                    }
                    cube += [Float(max(0, min(1, r))), Float(max(0, min(1, g))), Float(max(0, min(1, b))), 1]
                }
            }
        }
        return filtered("CIColorCube", image: image, values: [
            "inputCubeDimension": dimension,
            "inputCubeData": cube.withUnsafeBufferPointer { Data(buffer: $0) }
        ])
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
        let sourceFilename = aiMode == .edit ? selectedItem?.filename : nil
        let src: Data?
        if aiMode == .edit {
            guard let item = selectedItem,
                  let data = try? Data(contentsOf: item.url),
                  !data.isEmpty else {
                status = "无法读取原图，未发送 AI 修图请求"
                return
            }
            src = data
        } else {
            src = nil
        }
        aiIsGenerating = true; status = "正在调用 AI 模型…"
        Task {
            do {
                let result = try await aiService.generate(prompt: aiPrompt, src: src, sourceFilename: sourceFilename, size: aiRatio.size, activationCode: code, deviceId: ActivationManager.deviceId)
                let img = UIImage(data: result.data)
                await MainActor.run {
                    if let remaining = result.remainingUsage {
                        ActivationManager.updateServerRemaining(remaining)
                    } else {
                        ActivationManager.recordUsageFallback()
                    }
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
        let saved: URL?
        if aiMode == .edit, let selectedItem {
            saved = model.library.replaceEditedImage(
                data,
                at: selectedItem.url,
                originalFilename: selectedItem.filename
            )
        } else {
            saved = model.library.saveEditedImage(data, originalFilename: "ai_generated.jpg")
        }
        if let saved {
            selectedItemID = saved.path; status = "已保存 AI 结果 · \(saved.lastPathComponent)"
        } else { status = model.library.message }
        isSaving = false
    }

    private func resetAdjustments() {
        settings = ProfessionalEditSettings()
        selectedPreset = .original
        selectedNikonCloudPresetID = nil
        showingOriginal = false
        settingsBeforeAI = nil
        aiSummaryKey = "等待分析当前照片"
        aiAnalysis = nil
    }

    private func sampleCurrentColor() {
        guard let selectedItem,
              let image = CIImage(contentsOf: selectedItem.url) else {
            pickerSample = "无法读取照片"
            return
        }
        let extent = image.extent
        let point = CGPoint(x: extent.midX, y: extent.midY)
        let sampleRect = CGRect(x: point.x, y: point.y, width: 1, height: 1)
        var pixel = [UInt8](repeating: 0, count: 4)
        pixel.withUnsafeMutableBytes { buffer in
            context.render(image, toBitmap: buffer.baseAddress!, rowBytes: 4, bounds: sampleRect, format: .RGBA8, colorSpace: CGColorSpaceCreateDeviceRGB())
        }
        let r = Int(pixel[0]), g = Int(pixel[1]), b = Int(pixel[2])
        pickerSample = String(format: "RGB %02X %02X %02X", r, g, b)
        pickerColor = Color(red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255)
        settings.temperature = min(max(Double(b - r) / 2.55, -100), 100)
        settings.tint = min(max((Double(g) - Double(r + b) / 2) / 2.55, -100), 100)
        status = "已取样 #\(String(format: "%02X%02X%02X", r, g, b)) · 已微调色温/色调"
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
        selectedNikonCloudPresetID = nil
        showingOriginal = false
        aiSummaryKey = analysis.summaryKey
        aiAnalysis = analysis
        status = "AI 优化已应用 · 可继续微调"
    }

    private func applyNikonCloudPreset(_ preset: NikonCloudPreset) {
        let tone = preset.tone
        settings.resetTone()
        settings.contrast = tone.contrast
        settings.highlights = tone.highlights
        settings.shadows = tone.shadows
        settings.whites = tone.whites
        settings.blacks = tone.blacks
        settings.saturation = tone.saturation
        settings.texture = tone.texture
        settings.clarity = tone.clarity
        settings.sharpening = tone.sharpening
        settings.wheelLiftX = preset.grading.lift.x
        settings.wheelLiftY = preset.grading.lift.y
        settings.wheelGammaX = preset.grading.gamma.x
        settings.wheelGammaY = preset.grading.gamma.y
        settings.wheelGainX = preset.grading.gain.x
        settings.wheelGainY = preset.grading.gain.y
        if preset.toneCurve.count > 1 {
            let denominator = Double(preset.toneCurve.count - 1)
            settings.curvePoints = preset.toneCurve.enumerated().map {
                EditorCurvePoint(
                    x: Double($0.offset) / denominator,
                    y: min(max($0.element, 0), 1)
                )
            }
        }
        selectedPreset = .original
        selectedNikonCloudPresetID = preset.id
        settingsBeforeAI = nil
        aiAnalysis = nil
        aiSummaryKey = "等待分析当前照片"
        showingOriginal = false
        status = "尼康云创预览 · \(preset.name) · SDR 近似"
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

private struct EditorCurvePoint: Equatable {
    var x: Double
    var y: Double

    static let defaults: [EditorCurvePoint] = [
        EditorCurvePoint(x: 0, y: 0),
        EditorCurvePoint(x: 0.25, y: 0.25),
        EditorCurvePoint(x: 0.5, y: 0.5),
        EditorCurvePoint(x: 0.75, y: 0.75),
        EditorCurvePoint(x: 1, y: 1)
    ]
}

private struct EditorColorWheel: View {
    let title: String
    @Binding var x: Double
    @Binding var y: Double
    let tint: Color

    var body: some View {
        VStack(spacing: 5) {
            ZStack {
                Circle()
                    .stroke(
                        AngularGradient(colors: [.red, .yellow, .green, .cyan, .blue, .purple, .red], center: .center),
                        lineWidth: 10
                    )
                Circle()
                    .fill(IPalette.graphite)
                    .padding(8)
                Circle()
                    .fill(tint)
                    .frame(width: 8, height: 8)
                    .offset(x: CGFloat(x / 100) * 28, y: -CGFloat(y / 100) * 28)
            }
            .frame(width: 78, height: 78)
            .contentShape(Circle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        let center = CGPoint(x: 39, y: 39)
                        let dx = min(max((gesture.location.x - center.x) / 28, -1), 1)
                        let dy = min(max((center.y - gesture.location.y) / 28, -1), 1)
                        x = min(max(dx * 100, -100), 100)
                        y = min(max(dy * 100, -100), 100)
                    }
            )
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(IPalette.muted)
            Text(String(format: "%+.0f, %+.0f", x, y))
                .font(.caption.monospaced())
                .foregroundStyle(IPalette.muted)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct CapturePage: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var showingFullscreen = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                PageTitle(
                    title: "照片拍摄",
                    subtitle: "会话、曝光、对焦与交付按拍摄流程组织。"
                )

                if horizontalSizeClass != .compact {
                    CaptureSessionCard()
                }
                CameraStage {
                    showingFullscreen = true
                }
                NikonCloudMonitorBar()
                ExposureReadoutRail()
                CaptureActionBar()
                if horizontalSizeClass == .compact {
                    CaptureSessionCard()
                }
                CaptureParameterDeck()
                ShootingTaskCard()
            }
            .padding(horizontalSizeClass == .compact ? 16 : 20)
        }
        .fullScreenCover(isPresented: $showingFullscreen) {
            ImmersiveCameraView(mode: .photo)
        }
    }
}

private struct CameraStage: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
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

                if (model.section == .monitor || model.monitorNikonCloudPreset != nil),
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
        .aspectRatio(
            horizontalSizeClass == .compact ? 4 / 3 : 16 / 10,
            contentMode: .fit
        )
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
    @State private var videoShutterMode = "angle"
    @State private var videoExposureMode = "manual"
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
                    if (mode == .video || model.monitorNikonCloudPreset != nil),
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
                model.capturePhoto()
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
            mode == .photo
                ? !model.isCaptureReady
                : model.camera.state != .ready
                    || !model.camera.supportsMovieRecording
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
                Picker("视频快门表示", selection: $videoShutterMode) {
                    Text("快门角度").tag("angle")
                    Text("快门速度").tag("speed")
                }
                .pickerStyle(.segmented)
                .frame(width: 150)
                ImmersiveParameterStepper(
                    title: videoShutterMode == "angle" ? "快门角度" : "快门速度",
                    value: videoShutterMode == "angle"
                        ? String(format: "%.1f°", model.camera.shutterAngle)
                        : videoShutterSpeed,
                    enabled: model.camera.supportsCustomExposure,
                    lockedReason: "当前设备不支持自定义曝光",
                    decrease: {
                        if videoShutterMode == "angle" { adjustVideoShutterAngle(-1) }
                        else { adjustVideoShutterSpeed(-1) }
                    },
                    increase: {
                        if videoShutterMode == "angle" { adjustVideoShutterAngle(1) }
                        else { adjustVideoShutterSpeed(1) }
                    }
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

    private var videoShutterSpeed: String {
        guard model.camera.activeFrameRate > 0 else { return "—" }
        let seconds = model.camera.shutterAngle / (360 * model.camera.activeFrameRate)
        return seconds < 1 ? "1/\(Int((1 / seconds).rounded()))" : String(format: "%.1fs", seconds)
    }

    private func adjustVideoShutterSpeed(_ direction: Int) {
        let values: [Double] = [1.0 / 8000, 1.0 / 4000, 1.0 / 2000, 1.0 / 1000, 1.0 / 500, 1.0 / 250, 1.0 / 125, 1.0 / 60, 1.0 / 30, 1.0 / 15, 1.0 / 8, 1.0 / 4, 1.0 / 2, 1.0]
        let current = model.camera.shutterAngle / (360 * max(model.camera.activeFrameRate, 1))
        let index = values.enumerated().min { abs($0.element - current) < abs($1.element - current) }?.offset ?? 7
        let next = values[min(max(index + direction, 0), values.count - 1)]
        model.camera.setTimedExposure(seconds: next)
    }

    @ViewBuilder
    private var secondaryParameterControls: some View {
        HStack(spacing: 8) {
            Button {
                model.camera.triggerAutoFocus()
            } label: {
                Label("AF-ON", systemImage: "viewfinder.circle")
                    .frame(height: 44)
                    .padding(.horizontal, 10)
            }
            .buttonStyle(ImmersiveControlStyle())
            .disabled(model.camera.state != .ready)
            ImmersiveParameterStepper(
                title: "焦点位置",
                value: "微调",
                enabled: model.camera.state == .ready,
                lockedReason: "当前设备不支持焦点步进",
                decrease: { model.camera.moveFocus(-1) },
                increase: { model.camera.moveFocus(1) }
            )
            if mode == .video {
                Picker("视频曝光模式", selection: $videoExposureMode) {
                    Text("M 手动").tag("manual")
                    Text("AUTO 自动").tag("auto")
                }
                .pickerStyle(.segmented)
                .frame(width: 150)
                .onChange(of: videoExposureMode) { _, value in
                    model.camera.setVideoExposureMode(custom: value == "manual")
                }
            }
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
                    title: "视频编码",
                    value: model.monitorVideoCodec.label,
                    enabled: model.camera.availableVideoCodecs.count > 1,
                    lockedReason: "当前视频来源没有可切换的录制编码",
                    decrease: { adjustVideoCodec(-1) },
                    increase: { adjustVideoCodec(1) }
                )
                ImmersiveParameterStepper(
                    title: "Log",
                    value: model.monitorVideoLog.label,
                    enabled: model.availableVideoLogs.count > 1,
                    lockedReason: "当前视频来源没有可切换的 Log 曲线",
                    decrease: { adjustVideoLog(-1) },
                    increase: { adjustVideoLog(1) }
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

    private func adjustVideoCodec(_ direction: Int) {
        let values = model.availableRecordingCodecs
        guard !values.isEmpty else { return }
        let current = values.firstIndex(of: model.monitorVideoCodec) ?? 0
        let next = min(max(current + direction, 0), values.count - 1)
        model.setMonitorVideoCodec(values[next])
    }

    private func adjustVideoLog(_ direction: Int) {
        let values = model.availableVideoLogs
        guard !values.isEmpty else { return }
        let current = values.firstIndex(of: model.monitorVideoLog) ?? 0
        let next = min(max(current + direction, 0), values.count - 1)
        model.setMonitorVideoLog(values[next])
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
                afOnButton
                guideToggles
            }
            VStack(spacing: 12) {
                captureButton
                afOnButton
                guideToggles
            }
        }
    }

    private var captureButton: some View {
        Button {
            model.capturePhoto()
        } label: {
            Label("拍摄", systemImage: "camera.fill")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
        }
        .buttonStyle(.borderedProminent)
        .disabled(!model.isCaptureReady)
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

    private var afOnButton: some View {
        Button {
            model.camera.triggerAutoFocus()
        } label: {
            Label("AF-ON", systemImage: "viewfinder.circle")
                .font(.headline)
                .frame(height: 52)
                .padding(.horizontal, 14)
        }
        .buttonStyle(.bordered)
        .disabled(model.camera.state != .ready)
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

private struct NikonCloudMonitorBar: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var showingPresetPicker = false

    private var usesDarkSurface: Bool {
        model.section == .monitor
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Text("NP3")
                    .font(.caption.monospaced().weight(.bold))
                    .foregroundStyle(Color.white)
                    .frame(width: 40, height: 40)
                    .background(IPalette.cobalt, in: RoundedRectangle(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 2) {
                    Text("尼康云创监看")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(
                            usesDarkSurface ? Color.white : IPalette.ink
                        )
                    RuntimeLocalizedText(
                        model.monitorNikonCloudPreset?.name ?? "已关闭"
                    )
                    .font(.caption)
                    .foregroundStyle(
                        usesDarkSurface
                            ? Color.white.opacity(0.74)
                            : IPalette.muted
                    )
                    .lineLimit(1)
                }

                Spacer(minLength: 8)

                Button {
                    showingPresetPicker = true
                } label: {
                    Label {
                        RuntimeLocalizedText(
                            horizontalSizeClass == .compact
                                ? "预设"
                                : "选择预设"
                        )
                    } icon: {
                        Image(systemName: "slider.horizontal.3")
                    }
                        .lineLimit(1)
                }
                .buttonStyle(.borderedProminent)
                .tint(usesDarkSurface ? IPalette.readoutGlow : IPalette.cobalt)
                .disabled(NikonCloudPresetLibrary.presets.isEmpty)
            }

            Text("照片与视频实时生效 · SDR 近似 · 不写入原片")
                .font(.caption)
                .foregroundStyle(
                    usesDarkSurface
                        ? Color.white.opacity(0.72)
                        : IPalette.muted
                )
                .lineLimit(2)
        }
        .padding(12)
        .frame(minHeight: 72)
        .background(
            usesDarkSurface
                ? Color(red: 24 / 255, green: 36 / 255, blue: 52 / 255)
                : IPalette.cobaltSoft,
            in: RoundedRectangle(cornerRadius: 14)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .stroke(
                    usesDarkSurface
                        ? Color(red: 48 / 255, green: 78 / 255, blue: 112 / 255)
                        : IPalette.cobalt.opacity(0.34)
                )
        }
        .sheet(isPresented: $showingPresetPicker) {
            NikonCloudMonitorPresetSheet(model: model)
        }
    }
}

private struct NikonCloudMonitorPresetSheet: View {
    @ObservedObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    private var filteredGroups: [NikonCloudPresetGroup] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return NikonCloudPresetLibrary.groups }
        return NikonCloudPresetLibrary.groups.compactMap { group in
            let presets = group.presets.filter {
                $0.name.localizedCaseInsensitiveContains(query)
            }
            return presets.isEmpty
                ? nil
                : NikonCloudPresetGroup(title: group.title, presets: presets)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Button {
                    model.setMonitorNikonCloudPreset(nil)
                    dismiss()
                } label: {
                    HStack {
                        Label("关闭云创监看", systemImage: "xmark.circle")
                        Spacer()
                        if model.monitorNikonCloudPresetID == nil {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(IPalette.cobalt)
                        }
                    }
                }

                ForEach(filteredGroups) { group in
                    Section(group.title) {
                        ForEach(group.presets) { preset in
                            Button {
                                model.setMonitorNikonCloudPreset(preset)
                                dismiss()
                            } label: {
                                HStack(spacing: 10) {
                                    Text(verbatim: preset.name)
                                        .foregroundStyle(IPalette.ink)
                                    Spacer()
                                    if preset.hasCustomToneCurve {
                                        Text("CURVE")
                                            .font(.caption2.monospaced().weight(.semibold))
                                            .foregroundStyle(IPalette.muted)
                                    }
                                    if model.monitorNikonCloudPresetID == preset.id {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(IPalette.cobalt)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("尼康云创监看")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "搜索云创预设")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(IPalette.surfaceRaised)
    }
}

private struct MonitorPage: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var showingFullscreen = false

    var body: some View {
        Group {
            if horizontalSizeClass == .compact {
                MonitorConsolePage()
            } else {
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
                        NikonCloudMonitorBar()
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
            }
        }
        .fullScreenCover(isPresented: $showingFullscreen) {
            ImmersiveCameraView(mode: .video)
        }
    }
}

/// Compact, camera-first monitor surface matching the native reference layout.
/// It intentionally keeps all controls wired to CameraService so the visual
/// treatment does not create a second camera state machine.
private struct MonitorConsolePage: View {
    @EnvironmentObject private var model: AppModel
    @State private var elapsedSeconds = 0
    @State private var showingFullscreen = false
    @State private var selectedFocusPoint: CGPoint?
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var connected: Bool { model.camera.state == .ready }

    var body: some View {
        GeometryReader { proxy in
            VStack(spacing: 0) {
                timecode
                    .frame(height: 102)
                    .frame(maxWidth: .infinity)
                    .background(Color(red: 5 / 255, green: 14 / 255, blue: 24 / 255))

                preview(width: proxy.size.width)

                NikonCloudMonitorBar()
                    .padding(.horizontal, 12)
                    .padding(.top, 8)

                VStack(spacing: 0) {
                    scopeStrip
                        .padding(.top, 14)
                    readoutStrip
                        .padding(.top, 13)
                    parameterStrip
                        .padding(.top, 8)
                    toolStrip
                        .padding(.top, 12)
                    Spacer(minLength: 10)
                    storageReadout
                        .padding(.bottom, 18)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(IPalette.monitorBackground)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .background(IPalette.monitorBackground)
            .preferredColorScheme(.dark)
            .onReceive(timer) { _ in
                if model.camera.isRecording {
                    elapsedSeconds += 1
                } else {
                    elapsedSeconds = 0
                }
            }
        }
        .fullScreenCover(isPresented: $showingFullscreen) {
            ImmersiveCameraView(mode: .video)
        }
    }

    private var timecode: some View {
        VStack(spacing: 6) {
            Text(timecodeText)
                .font(.system(size: 32, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white)
                .monospacedDigit()
            HStack(spacing: 8) {
                Circle()
                    .fill(model.camera.isRecording ? IPalette.video : Color.white.opacity(0.35))
                    .frame(width: 7, height: 7)
                Text(model.camera.isRecording ? "REC" : (connected ? "LIVE VIEW" : "未连接相机"))
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
    }

    private var timecodeText: String {
        let hours = elapsedSeconds / 3600
        let minutes = (elapsedSeconds % 3600) / 60
        let seconds = elapsedSeconds % 60
        return String(format: "%02d:%02d:%02d:00", hours, minutes, seconds)
    }

    private func preview(width: CGFloat) -> some View {
        ZStack {
            Color.black
            if connected {
                CameraPreview(
                    session: model.camera.session,
                    focusHandler: { point in
                        selectedFocusPoint = point
                        model.camera.focus(at: point)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                            if selectedFocusPoint == point { selectedFocusPoint = nil }
                        }
                    }
                )
                .overlay {
                    if let overlay = model.camera.monitorOverlay {
                        Image(decorative: overlay, scale: 1)
                            .resizable()
                            .scaledToFill()
                            .allowsHitTesting(false)
                    }
                }
                if model.showGrid {
                    GridOverlay()
                        .stroke(Color.white.opacity(0.35), lineWidth: 0.7)
                        .allowsHitTesting(false)
                }
                if model.showSafeGuide {
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.yellow.opacity(0.75), style: StrokeStyle(lineWidth: 1, dash: [7]))
                        .padding(width * 0.075)
                        .allowsHitTesting(false)
                }
                if let selectedFocusPoint {
                    FocusPointReticle()
                        .stroke(Color.yellow, lineWidth: 2)
                        .frame(width: 48, height: 48)
                        .position(
                            x: selectedFocusPoint.x * width,
                            y: selectedFocusPoint.y * width * 9 / 16
                        )
                        .allowsHitTesting(false)
                }
            } else {
                VStack(spacing: 9) {
                    Image(systemName: "camera.viewfinder")
                        .font(.system(size: 34, weight: .light))
                    Text("等待相机画面")
                        .font(.subheadline.weight(.semibold))
                    Button("选择相机") { model.showingConnection = true }
                        .buttonStyle(.borderedProminent)
                        .tint(IPalette.cobalt)
                }
                .foregroundStyle(.white.opacity(0.72))
            }
        }
        .aspectRatio(16 / 9, contentMode: .fit)
        .frame(maxWidth: .infinity)
        .overlay(alignment: .topLeading) {
            HStack(spacing: 6) {
                Circle()
                    .fill(connected ? IPalette.positive : IPalette.video)
                    .frame(width: 6, height: 6)
                Text(model.camera.deviceName)
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .lineLimit(1)
            }
            .foregroundStyle(.white.opacity(0.82))
            .padding(.horizontal, 9)
            .frame(height: 28)
            .background(.black.opacity(0.48), in: Capsule())
            .padding(10)
        }
        .overlay(alignment: .topTrailing) {
            Button { showingFullscreen = true } label: {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 13, weight: .bold))
                    .frame(width: 28, height: 28)
                    .foregroundStyle(.white.opacity(0.84))
                    .background(.black.opacity(0.48), in: Circle())
            }
            .buttonStyle(.plain)
            .padding(10)
            .accessibilityLabel("打开全屏取景")
        }
    }

    private var scopeStrip: some View {
        HStack(spacing: 10) {
            RGBWaveformCard()
            Button {
                model.camera.toggleVideoRecording()
            } label: {
                ZStack {
                    Circle()
                        .stroke(.white.opacity(0.95), lineWidth: 2)
                        .frame(width: 86, height: 86)
                    Circle()
                        .fill(model.camera.isRecording ? IPalette.video : Color(red: 0.55, green: 0.03, blue: 0.03))
                        .frame(width: 51, height: 51)
                        .overlay {
                            if model.camera.isRecording {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(.white)
                                    .frame(width: 15, height: 15)
                            }
                        }
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
            .disabled(!connected || !model.camera.supportsMovieRecording)
            AudioWaveformCard()
        }
        .padding(.horizontal, 18)
        .frame(height: 92)
    }

    private var readoutStrip: some View {
        HStack(spacing: 0) {
            ConsoleReadout(label: "帧率", value: String(format: "%.0f", model.camera.activeFrameRate))
            ConsoleReadout(label: "快门", value: shutterSpeed)
            ConsoleReadout(label: "光圈", value: model.camera.lensAperture > 0 ? String(format: "f/%.1f", model.camera.lensAperture) : "—", dimmed: model.camera.lensAperture <= 0)
            ConsoleReadout(label: "ISO", value: connected ? "\(Int(model.camera.exposureISO.rounded()))" : "—")
            ConsoleReadout(label: "白平衡", value: "自动")
            ConsoleReadout(label: "色调", value: String(format: "%+.0f", model.camera.exposureBias * 50))
        }
        .padding(.horizontal, 17)
    }

    private var parameterStrip: some View {
        HStack(spacing: 8) {
            MonitorConsoleStepper(
                title: "帧率",
                value: "\(Int(model.camera.activeFrameRate))p",
                enabled: connected,
                decrease: { adjustVideoSpec(-1) },
                increase: { adjustVideoSpec(1) }
            )
            MonitorConsoleStepper(
                title: "快门",
                value: String(format: "%.1f°", model.camera.shutterAngle),
                enabled: connected && model.camera.supportsCustomExposure,
                decrease: { adjustVideoShutterAngle(-1) },
                increase: { adjustVideoShutterAngle(1) }
            )
            MonitorConsoleStepper(
                title: "ISO",
                value: "\(Int(model.camera.exposureISO.rounded()))",
                enabled: connected && model.camera.supportsCustomExposure,
                decrease: { adjustVideoISO(-1) },
                increase: { adjustVideoISO(1) }
            )
        }
        .padding(.horizontal, 18)
    }

    private var shutterSpeed: String {
        guard connected, model.camera.shutterAngle > 0, model.camera.activeFrameRate > 0 else { return "—" }
        let denominator = Int((360 * model.camera.activeFrameRate / model.camera.shutterAngle).rounded())
        return denominator > 0 ? "1/\(denominator)" : "—"
    }

    private func adjustVideoShutterAngle(_ direction: Int) {
        let values = [45.0, 60.0, 72.0, 90.0, 108.0, 120.0, 144.0, 150.0,
                      172.8, 180.0, 216.0, 240.0, 270.0, 300.0, 324.0, 360.0]
        let current = values.enumerated().min {
            abs($0.element - model.camera.shutterAngle) < abs($1.element - model.camera.shutterAngle)
        }?.offset ?? 9
        let next = min(max(current + direction, 0), values.count - 1)
        model.camera.setVideoShutterAngle(values[next])
    }

    private func adjustVideoISO(_ direction: Int) {
        let values = [64, 80, 100, 125, 160, 200, 250, 320, 400, 500, 640,
                      800, 1000, 1250, 1600, 2000, 2500, 3200, 4000, 5000,
                      6400, 8000, 10000, 12800, 16000, 20000, 25600, 32000,
                      40000, 51200, 64000, 80000, 102400]
            .filter { Float($0) >= model.camera.minISO && Float($0) <= model.camera.maxISO }
        guard !values.isEmpty else { return }
        let current = values.enumerated().min {
            abs(Float($0.element) - model.camera.exposureISO) < abs(Float($1.element) - model.camera.exposureISO)
        }?.offset ?? 0
        let next = min(max(current + direction, 0), values.count - 1)
        model.camera.setVideoISO(Float(values[next]))
    }

    private func adjustVideoSpec(_ direction: Int) {
        let values = MonitorVideoSpec.allCases
        guard let current = values.firstIndex(of: model.monitorVideoSpec) else { return }
        let next = min(max(current + direction, 0), values.count - 1)
        model.setMonitorVideoSpec(values[next])
    }

    private var toolStrip: some View {
        HStack(spacing: 0) {
            ConsoleToolButton(title: "AF-ON", icon: "viewfinder.circle", active: model.camera.supportsFocusPoint) {
                model.camera.triggerAutoFocus()
            }
            ConsoleToolButton(title: "LUT", icon: "rectangle.on.rectangle", active: model.camera.falseColorEnabled) {
                model.camera.setFalseColorEnabled(!model.camera.falseColorEnabled)
            }
            ConsoleToolButton(title: "峰值", icon: "circle.dotted", active: model.camera.focusPeakingEnabled) {
                model.camera.setFocusPeakingEnabled(!model.camera.focusPeakingEnabled)
            }
            ConsoleToolButton(title: "假色", icon: "plusminus.circle", active: model.camera.falseColorEnabled) {
                model.camera.setFalseColorEnabled(!model.camera.falseColorEnabled)
            }
            ConsoleToolButton(title: "网格", icon: "viewfinder", active: model.showGrid) {
                model.showGrid.toggle()
            }
            ConsoleToolButton(title: "全屏", icon: "arrow.up.left.and.arrow.down.right", active: false) {
                showingFullscreen = true
            }
        }
        .padding(.horizontal, 20)
    }

    private var storageReadout: some View {
        let info = MonitorStorageInfo.current
        return HStack(spacing: 13) {
            Image(systemName: "iphone")
                .font(.system(size: 33, weight: .light))
                .frame(width: 60)
                .foregroundStyle(.white.opacity(0.9))
            VStack(alignment: .leading, spacing: 7) {
                HStack(alignment: .firstTextBaseline) {
                    Text("\(info.minutesRemaining)")
                        .font(.system(size: 25, weight: .bold, design: .monospaced))
                    Text("剩余录制")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.72))
                    Spacer(minLength: 10)
                    Text(info.freeDescription)
                        .font(.caption.monospacedDigit().weight(.semibold))
                        .foregroundStyle(.white.opacity(0.85))
                }
                ProgressView(value: info.progress)
                    .tint(IPalette.cobalt)
                    .scaleEffect(x: 1, y: 1.5, anchor: .center)
                HStack {
                    Text("\(info.percentUsed)% 已用")
                    Spacer()
                    Text(model.camera.isRecording ? "录制中" : "待机")
                }
                .font(.caption2.monospacedDigit().weight(.semibold))
                .foregroundStyle(.white.opacity(0.65))
            }
        }
        .padding(.horizontal, 14)
        .frame(width: 286, height: 91)
        .background(Color(red: 27 / 255, green: 36 / 255, blue: 51 / 255), in: RoundedRectangle(cornerRadius: 9))
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(Color.white.opacity(0.04))
                .frame(width: 62)
                .clipShape(RoundedRectangle(cornerRadius: 9))
        }
        .foregroundStyle(.white)
    }
}

private struct RGBWaveformCard: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        ScopePlot(
            label: "RGB",
            traces: [
                ScopeTrace(value: model.camera.redHistogram, color: Color(red: 1, green: 0.19, blue: 0.16)),
                ScopeTrace(value: model.camera.greenHistogram, color: Color(red: 0.16, green: 1, blue: 0.41)),
                ScopeTrace(value: model.camera.blueHistogram, color: Color(red: 0.13, green: 0.25, blue: 1))
            ],
            parade: true
        )
        .accessibilityLabel("RGB 波形")
    }
}

private struct AudioWaveformCard: View {
    var body: some View {
        AudioScopePlot(label: "AUDIO")
            .accessibilityLabel("音频波形，无音频源，静音基线")
    }
}

private struct ScopeTrace {
    let value: String
    let color: Color
}

private struct ScopePlot: View {
    let label: String
    let traces: [ScopeTrace]
    var parade = false

    var body: some View {
        VStack(spacing: 2) {
            Canvas { context, size in
                for (index, trace) in traces.enumerated() {
                    drawTrace(
                        context: &context,
                        size: size,
                        value: trace.value,
                        color: trace.color,
                        segment: parade ? index : nil,
                        seed: index + 1
                    )
                }
                drawGrid(context: &context, size: size)
            }
            .background(Color(red: 5 / 255, green: 10 / 255, blue: 15 / 255))

            if parade {
                HStack(spacing: 0) {
                    Text("R").frame(maxWidth: .infinity)
                    Text("G").frame(maxWidth: .infinity)
                    Text("B").frame(maxWidth: .infinity)
                }
                .font(.system(size: 8, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.86))
                .frame(height: 10)
            } else {
                Text(label)
                    .font(.system(size: 8, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.86))
                    .frame(maxWidth: .infinity)
                    .frame(height: 10)
            }
        }
        .background(Color.black)
    }

    private func drawGrid(context: inout GraphicsContext, size: CGSize) {
        let bounds = CGRect(
            x: 0.75,
            y: 0.75,
            width: max(1, size.width - 1.5),
            height: max(1, size.height - 1.5)
        )
        var guides = Path()
        for fraction in [0.25, 0.5, 0.75] {
            let y = bounds.minY + bounds.height * fraction
            guides.move(to: CGPoint(x: bounds.minX, y: y))
            guides.addLine(to: CGPoint(x: bounds.maxX, y: y))
        }
        if parade {
            for fraction in [1.0 / 3.0, 2.0 / 3.0] {
                let x = bounds.minX + bounds.width * fraction
                guides.move(to: CGPoint(x: x, y: bounds.minY))
                guides.addLine(to: CGPoint(x: x, y: bounds.maxY))
            }
        }
        context.stroke(guides, with: .color(.white.opacity(0.56)), lineWidth: 0.72)
        var frame = Path()
        frame.addRect(bounds)
        context.stroke(frame, with: .color(.white.opacity(0.94)), lineWidth: 1.1)
    }

    private func drawTrace(
        context: inout GraphicsContext,
        size: CGSize,
        value: String,
        color: Color,
        segment: Int?,
        seed: Int
    ) {
        let horizontalInset = max(2, size.width * 0.009)
        let startX: CGFloat
        let width: CGFloat
        if let segment {
            let segmentWidth = size.width / 3
            startX = segmentWidth * CGFloat(segment) + horizontalInset
            width = max(1, segmentWidth - horizontalInset * 2)
        } else {
            startX = horizontalInset
            width = max(1, size.width - horizontalInset * 2)
        }
        let topInset = max(3, size.height * 0.035)
        let bottom = size.height - max(3, size.height * 0.035)
        let plotHeight = max(1, bottom - topInset)
        if let density = ScopeLevels.density(value) {
            drawDensity(
                context: &context,
                density: density,
                color: color,
                startX: startX,
                width: width,
                top: topInset,
                height: plotHeight
            )
            return
        }
        let levels = ScopeLevels.parse(value)
        guard levels.count > 1 else { return }
        let columns = min(190, max(48, Int(width / 1.35)))
        var envelope = Path()
        var haze = Path()
        var cloud = Path()
        var sparks = Path()

        for column in 0..<columns {
            let progress = CGFloat(column) / CGFloat(max(1, columns - 1))
            let sample = progress * CGFloat(levels.count - 1)
            let lower = min(levels.count - 1, Int(sample.rounded(.down)))
            let upper = min(levels.count - 1, lower + 1)
            let blend = sample - CGFloat(lower)
            let interpolated = levels[lower] + (levels[upper] - levels[lower]) * blend
            let ripple = (scopeNoise(column, 0, seed) - 0.5) * 0.075
            let level = min(1, max(0.04, interpolated + ripple))
            let x = startX + width * progress
            let envelopeY = topInset + plotHeight * (1 - (0.12 + level * 0.82))

            if column == 0 { envelope.move(to: CGPoint(x: x, y: envelopeY)) }
            else { envelope.addLine(to: CGPoint(x: x, y: envelopeY)) }

            let particles = 18 + Int(level * 28)
            for particle in 0..<particles {
                let distribution = scopeNoise(column, particle + 1, seed * 7)
                let depth = particle % 3 == 0
                    ? pow(distribution, 2.25)
                    : pow(distribution, 0.72)
                let jitterX = (scopeNoise(column, particle + 11, seed * 13) - 0.5) * 2.2
                let jitterY = (scopeNoise(column, particle + 29, seed * 17) - 0.5) * 2.4
                let y = min(bottom, max(topInset, envelopeY + (bottom - envelopeY) * depth + jitterY))
                let bright = (column + particle + seed) % 5 == 0
                let dot = bright ? CGFloat(1.12) : CGFloat(0.72)
                let rect = CGRect(x: x + jitterX - dot / 2, y: y - dot / 2, width: dot, height: dot)
                haze.addEllipse(in: rect.insetBy(dx: -0.55, dy: -0.55))
                if bright { sparks.addEllipse(in: rect) }
                else { cloud.addEllipse(in: rect) }
            }
        }

        context.drawLayer { layer in
            layer.blendMode = .plusLighter
            layer.fill(haze, with: .color(color.opacity(0.07)))
            layer.fill(cloud, with: .color(color.opacity(0.30)))
            layer.fill(sparks, with: .color(color.opacity(0.64)))
            layer.stroke(envelope, with: .color(color.opacity(0.14)), lineWidth: 3.2)
            layer.stroke(envelope, with: .color(color.opacity(0.62)), lineWidth: 0.72)
        }
    }

    private func drawDensity(
        context: inout GraphicsContext,
        density: ScopeDensity,
        color: Color,
        startX: CGFloat,
        width: CGFloat,
        top: CGFloat,
        height: CGFloat
    ) {
        let cellWidth = width / CGFloat(density.columns)
        let cellHeight = height / CGFloat(density.rows)
        let dot = max(0.62, min(1.5, cellWidth * 0.72))
        var haze = Path()
        var cloud = Path()
        var sparks = Path()
        var envelope = Path()
        for column in 0..<density.columns {
            var firstRow: Int?
            for row in 0..<density.rows {
                let level = density.values[row * density.columns + column]
                guard level > 0 else { continue }
                if firstRow == nil { firstRow = row }
                let x = startX + (CGFloat(column) + 0.5) * cellWidth
                let y = top + (CGFloat(row) + 0.5) * cellHeight
                let intensity = CGFloat(level) / 15
                haze.addEllipse(in: CGRect(x: x - dot, y: y - dot, width: dot * 2, height: dot * 2))
                let core = dot * (0.46 + intensity * 0.38)
                if level >= 9 {
                    sparks.addEllipse(in: CGRect(x: x - core, y: y - core, width: core * 2, height: core * 2))
                } else if level >= 3 {
                    cloud.addEllipse(in: CGRect(x: x - core, y: y - core, width: core * 2, height: core * 2))
                }
            }
            if let row = firstRow {
                let point = CGPoint(
                    x: startX + (CGFloat(column) + 0.5) * cellWidth,
                    y: top + (CGFloat(row) + 0.5) * cellHeight
                )
                if envelope.isEmpty { envelope.move(to: point) }
                else { envelope.addLine(to: point) }
            }
        }
        context.drawLayer { layer in
            layer.blendMode = .plusLighter
            layer.fill(haze, with: .color(color.opacity(0.10)))
            layer.fill(cloud, with: .color(color.opacity(0.35)))
            layer.fill(sparks, with: .color(color.opacity(0.78)))
            layer.stroke(envelope, with: .color(color.opacity(0.22)), lineWidth: 2.8)
            layer.stroke(envelope, with: .color(color.opacity(0.72)), lineWidth: 0.68)
        }
    }

    private func scopeNoise(_ column: Int, _ particle: Int, _ seed: Int) -> CGFloat {
        let value = sin(Double((column + 1) * 17 + (particle + 3) * 31 + seed * 47) * 12.9898) * 43_758.5453
        return CGFloat(value - floor(value))
    }
}

private struct AudioScopePlot: View {
    let label: String

    var body: some View {
        VStack(spacing: 2) {
            Canvas { context, size in
                var guides = Path()
                for fraction in [0.25, 0.5, 0.75] {
                    let y = size.height * fraction
                    guides.move(to: CGPoint(x: 0, y: y))
                    guides.addLine(to: CGPoint(x: size.width, y: y))
                }
                var baseline = Path()
                baseline.move(to: CGPoint(x: 4, y: size.height / 2))
                baseline.addLine(to: CGPoint(x: size.width - 4, y: size.height / 2))
                let cyan = Color(red: 76 / 255, green: 199 / 255, blue: 232 / 255)
                context.stroke(baseline, with: .color(cyan.opacity(0.22)), lineWidth: 5)
                context.stroke(baseline, with: .color(cyan.opacity(0.92)), lineWidth: 1)
                context.stroke(guides, with: .color(.white.opacity(0.56)), lineWidth: 0.72)
                var frame = Path()
                frame.addRect(CGRect(x: 0.75, y: 0.75, width: max(1, size.width - 1.5), height: max(1, size.height - 1.5)))
                context.stroke(frame, with: .color(.white.opacity(0.94)), lineWidth: 1.1)
            }
            .background(Color(red: 5 / 255, green: 10 / 255, blue: 15 / 255))
            Text(label)
                .font(.system(size: 8, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.86))
                .frame(maxWidth: .infinity)
                .frame(height: 10)
        }
        .background(Color.black)
    }
}

private struct ScopeDensity {
    let columns: Int
    let rows: Int
    let values: [Int]
}

private enum ScopeLevels {
    private static let bars = Array("▁▂▃▄▅▆▇█")

    static func parse(_ value: String) -> [CGFloat] {
        let parsed = Array(value).compactMap { character -> CGFloat? in
            guard let index = bars.firstIndex(of: character) else { return nil }
            return CGFloat(index) / CGFloat(max(1, bars.count - 1))
        }
        return parsed.count > 1 ? parsed : [0.08, 0.08]
    }

    static func density(_ value: String) -> ScopeDensity? {
        guard value.hasPrefix("S"),
              let colon = value.firstIndex(of: ":") else { return nil }
        let dimensions = value[value.index(after: value.startIndex)..<colon]
            .split(separator: "x", maxSplits: 1)
        guard dimensions.count == 2,
              let columns = Int(dimensions[0]),
              let rows = Int(dimensions[1]) else { return nil }
        let payload = value[value.index(after: colon)...]
        guard payload.count == columns * rows else { return nil }
        let values = payload.compactMap { Int(String($0), radix: 16) }
        guard values.count == columns * rows else { return nil }
        return ScopeDensity(columns: columns, rows: rows, values: values)
    }
}

private struct ProfessionalScopeBoard: View {
    let red: String
    let green: String
    let blue: String
    let luma: String
    let chroma: String

    var body: some View {
        let chromaParts = chroma.split(separator: "|", maxSplits: 1).map(String.init)
        let cb = chromaParts.first ?? chroma
        let cr = chromaParts.count > 1 ? chromaParts[1] : chroma
        VStack(spacing: 1) {
            ScopePlot(
                label: "Y",
                traces: [ScopeTrace(value: luma, color: .white)]
            )
            ScopePlot(
                label: "YUV",
                traces: [
                    ScopeTrace(value: luma, color: Color(red: 0.08, green: 1, blue: 0.36)),
                    ScopeTrace(value: cb, color: Color(red: 0, green: 0.82, blue: 1)),
                    ScopeTrace(
                        value: cr,
                        color: Color(red: 1, green: 0.15, blue: 0.87)
                    )
                ]
            )
            ScopePlot(
                label: "RGB",
                traces: [
                    ScopeTrace(value: red, color: Color(red: 1, green: 0.19, blue: 0.16)),
                    ScopeTrace(value: green, color: Color(red: 0.16, green: 1, blue: 0.41)),
                    ScopeTrace(value: blue, color: Color(red: 0.13, green: 0.25, blue: 1))
                ],
                parade: true
            )
        }
        .padding(4)
        .background(Color.black)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("专业波形图，亮度、YUV 与 RGB 分量")
    }
}

private struct MonitorConsoleStepper: View {
    let title: String
    let value: String
    let enabled: Bool
    let decrease: () -> Void
    let increase: () -> Void

    var body: some View {
        HStack(spacing: 3) {
            Button(action: decrease) {
                Image(systemName: "minus").frame(width: 30, height: 32)
            }
            VStack(spacing: 1) {
                Text(title).font(.system(size: 9, weight: .semibold))
                Text(value).font(.system(size: 11, weight: .bold, design: .monospaced)).monospacedDigit()
            }
            .frame(minWidth: 54)
            Button(action: increase) {
                Image(systemName: "plus").frame(width: 30, height: 32)
            }
        }
        .buttonStyle(.plain)
        .foregroundStyle(enabled ? .white : .white.opacity(0.45))
        .background(Color.black.opacity(0.42), in: RoundedRectangle(cornerRadius: 8))
        .disabled(!enabled)
    }
}

private struct FocusPointReticle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let arm = min(rect.width, rect.height) * 0.28
        path.move(to: CGPoint(x: rect.minX, y: rect.minY + arm)); path.addLine(to: CGPoint(x: rect.minX, y: rect.minY)); path.addLine(to: CGPoint(x: rect.minX + arm, y: rect.minY))
        path.move(to: CGPoint(x: rect.maxX - arm, y: rect.minY)); path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY)); path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + arm))
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY - arm)); path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY)); path.addLine(to: CGPoint(x: rect.minX + arm, y: rect.maxY))
        path.move(to: CGPoint(x: rect.maxX - arm, y: rect.maxY)); path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY)); path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - arm))
        return path
    }
}

private struct ConsoleReadout: View {
    let label: String
    let value: String
    var dimmed = false

    var body: some View {
        VStack(spacing: 6) {
            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white.opacity(0.72))
            Text(value)
                .font(.system(size: 17, weight: .bold, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(dimmed ? .white.opacity(0.48) : .white)
                .minimumScaleFactor(0.68)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct ConsoleToolButton: View {
    let title: String
    let icon: String
    let active: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .light))
                    .frame(width: 44, height: 38)
                Text(title)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(active ? IPalette.cobalt : .white.opacity(0.7))
            }
            .frame(maxWidth: .infinity)
            .foregroundStyle(active ? IPalette.cobalt : .white.opacity(0.9))
        }
        .buttonStyle(.plain)
    }
}

private struct MonitorStorageInfo {
    let progress: Double
    let percentUsed: Int
    let freeDescription: String
    let minutesRemaining: String

    static var current: MonitorStorageInfo {
        let attributes = try? FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory())
        let total = (attributes?[.systemSize] as? NSNumber)?.doubleValue ?? 1
        let free = (attributes?[.systemFreeSize] as? NSNumber)?.doubleValue ?? total * 0.8
        let used = max(0, total - free)
        let progress = min(1, max(0, used / max(total, 1)))
        let freeGB = max(0, free / 1_073_741_824)
        let minutes = Int(max(1, min(999, freeGB * 2.1)))
        return MonitorStorageInfo(
            progress: progress,
            percentUsed: Int((progress * 100).rounded()),
            freeDescription: String(format: "%.0fGB", freeGB),
            minutesRemaining: String(format: "%02d:%02d", minutes / 60, minutes % 60)
        )
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
    @State private var videoExposureMode = "manual"
    @State private var videoShutterMode = "angle"

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("参数调节")
                .font(.headline)
            Text("按当前视频设备公开的能力调整。")
                .font(.subheadline)
                .foregroundStyle(IPalette.muted)

            Picker("视频曝光模式", selection: $videoExposureMode) {
                Text("M 手动").tag("manual")
                Text("AUTO 自动").tag("auto")
            }
            .pickerStyle(.segmented)
            .onChange(of: videoExposureMode) { _, value in
                model.camera.setVideoExposureMode(custom: value == "manual")
            }

            Picker("视频快门表示", selection: $videoShutterMode) {
                Text("快门角度").tag("angle")
                Text("快门速度").tag("speed")
            }
            .pickerStyle(.segmented)

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label(
                        videoShutterMode == "angle" ? "快门角度" : "快门速度",
                        systemImage: "circle.lefthalf.filled"
                    )
                    Spacer()
                    Text(
                        videoShutterMode == "angle"
                            ? String(format: "%.1f° · %.0fp", model.camera.shutterAngle, model.camera.activeFrameRate)
                            : shutterSpeedLabel(currentShutterSeconds)
                    )
                        .monospacedDigit()
                        .foregroundStyle(.red)
                }
                if videoShutterMode == "angle" {
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
                } else {
                    Picker(
                        "快门速度",
                        selection: Binding(
                            get: {
                                shutterSpeedOptions.min {
                                    abs($0 - currentShutterSeconds)
                                        < abs($1 - currentShutterSeconds)
                                } ?? (1.0 / 60)
                            },
                            set: { model.camera.setTimedExposure(seconds: $0) }
                        )
                    ) {
                        ForEach(shutterSpeedOptions, id: \.self) { seconds in
                            Text(shutterSpeedLabel(seconds)).tag(seconds)
                        }
                    }
                    .pickerStyle(.menu)
                    .disabled(model.camera.state != .ready || !model.camera.supportsCustomExposure)
                }
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

    private var shutterSpeedOptions: [Double] {
        [1.0 / 8000, 1.0 / 4000, 1.0 / 2000, 1.0 / 1000,
         1.0 / 500, 1.0 / 250, 1.0 / 125, 1.0 / 60, 1.0 / 30,
         1.0 / 15, 1.0 / 8, 1.0 / 4, 1.0 / 2, 1.0]
    }

    private var currentShutterSeconds: Double {
        model.camera.shutterAngle / (360 * max(model.camera.activeFrameRate, 1))
    }

    private func shutterSpeedLabel(_ seconds: Double) -> String {
        seconds < 1
            ? "1/\(Int((1 / seconds).rounded())) s"
            : String(format: "%.1f s", seconds)
    }
}

private struct MonitorOutputDeck: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("系统视频输出")
                .font(.headline)

            Picker(
                "录制规格来源",
                selection: Binding(
                    get: { model.monitorVideoVendor },
                    set: { model.setMonitorVideoVendor($0) }
                )
            ) {
                ForEach(MonitorVideoVendor.allCases) { vendor in
                    Text(vendor.label).tag(vendor)
                }
            }

            Picker(
                "视频录制规格",
                selection: Binding(
                    get: { model.monitorVideoCodec },
                    set: { model.setMonitorVideoCodec($0) }
                )
            ) {
                ForEach(model.availableRecordingCodecs) { codec in
                    Text(codec.label)
                        .tag(codec)
                        .disabled(
                            model.monitorVideoVendor == .system
                                && model.camera.state == .ready
                                && !model.camera.availableVideoCodecs.contains(codec)
                        )
                }
            }

            Picker(
                "Log / Picture Profile",
                selection: Binding(
                    get: { model.monitorVideoLog },
                    set: { model.setMonitorVideoLog($0) }
                )
            ) {
                ForEach(model.availableVideoLogs) { log in
                    Text(log.label).tag(log)
                }
            }

            Text(
                model.monitorVideoVendor == .system
                    ? "本机与 UVC 来源仅使用 AVFoundation 报告的编码；厂商机身规格不会映射成 Apple Log。"
                    : "Sony / Canon / Nikon 机身规格在 iOS 上作为能力与工作流预设展示；当前 AVFoundation / UVC 通道不提供厂商 PTP Picture Profile 写入。"
            )
            .font(.caption)
            .foregroundStyle(.secondary)

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

            Toggle("外录到当前智能设备", isOn: .constant(true))
                .disabled(true)
            Text("iOS / iPadOS 的本机与 UVC 视频源始终通过 AVFoundation 外录为 MOV，并直接写入 ZENCHE 文件库；照片同样保存在当前设备。")
                .font(.caption)
                .foregroundStyle(IPalette.muted)
                .fixedSize(horizontal: false, vertical: true)

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

            VStack(alignment: .leading, spacing: 8) {
                ProfessionalScopeBoard(
                    red: model.camera.redHistogram,
                    green: model.camera.greenHistogram,
                    blue: model.camera.blueHistogram,
                    luma: model.camera.waveform,
                    chroma: model.camera.vectorscope
                )
                .frame(height: 190)
                Text("峰值覆盖 · \(model.camera.peakingCoverage)%")
                    .font(.caption.monospaced())
                    .foregroundStyle(.white.opacity(0.7))
            }
            .padding(8)
            .background(Color.black, in: RoundedRectangle(cornerRadius: 10))

            Text("H.264、H.265 与设备公开的 ProRes 编码会直接应用到系统录制输出。N-RAW 与 N-Log 需要兼容 Nikon 机身控制；当前 iOS/UVC 来源不支持时会锁定并给出原因。")
                .font(.caption)
                .foregroundStyle(IPalette.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 16))
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
    @State private var wirelessExpanded = true
    @State private var uncategorizedExpanded = true
    @State private var localPhotosExpanded = true
    @State private var localVideosExpanded = true
    @State private var unclassifiedDropTargeted = false
    @State private var cameraStorageSnapshot = CameraStorageSnapshot.empty
    @State private var selectedCameraStorageHandles: Set<UInt32> = []
    @State private var cameraStorageStatus = "连接 Wi‑Fi/PTP‑IP 相机后可浏览存储卡"
    @State private var cameraStorageBusy = false
    @State private var cameraStorageExpanded = true
    @State private var confirmingCameraStorageDeletion = false

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
                cameraStorageWorkspace
                DisclosureGroup(isExpanded: $wirelessExpanded) {
                    WirelessTransferCard()
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Label(
                            "无线传输",
                            systemImage: "antenna.radiowaves.left.and.right"
                        )
                        .font(.headline)
                        Text(
                            "Wi‑Fi 相机\(model.wifiCamera.isConnected ? "已连接" : "未连接") · " +
                                "收件箱\(model.wireless.isRunning ? "运行中" : "已停止")"
                        )
                        .font(.caption)
                        .foregroundStyle(IPalette.muted)
                    }
                }

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
        .confirmationDialog(
            "从相机永久删除？",
            isPresented: $confirmingCameraStorageDeletion,
            titleVisibility: .visible
        ) {
            Button("永久删除", role: .destructive) {
                Task { await deleteSelectedCameraStorage() }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text(
                "将从相机存储卡永久删除所选 \(selectedCameraStorageItems.count) 个文件；此操作无法撤销。已保护文件不会被选择。"
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

    private var selectedCameraStorageItems: [CameraStorageItem] {
        cameraStorageSnapshot.items.filter {
            selectedCameraStorageHandles.contains($0.handle)
        }
    }

    private var selectableCameraStorageHandles: Set<UInt32> {
        Set(cameraStorageSnapshot.items.filter { !$0.isProtected }.map(\.handle))
    }

    private var cameraStorageWorkspace: some View {
        DisclosureGroup(isExpanded: $cameraStorageExpanded) {
            VStack(alignment: .leading, spacing: 12) {
                Text(cameraStorageCapacitySummary)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(IPalette.muted)

                HStack(spacing: 10) {
                    Button {
                        Task { await refreshCameraStorage() }
                    } label: {
                        Label(
                            cameraStorageBusy ? "正在读取…" : "刷新机内文件",
                            systemImage: "arrow.clockwise"
                        )
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(cameraStorageBusy || !model.wifiCamera.isConnected)

                    Button {
                        selectedCameraStorageHandles =
                            selectedCameraStorageHandles == selectableCameraStorageHandles
                                ? []
                                : selectableCameraStorageHandles
                    } label: {
                        Label(
                            selectedCameraStorageHandles == selectableCameraStorageHandles
                                && !selectableCameraStorageHandles.isEmpty
                                ? "取消全选"
                                : "全选",
                            systemImage: "checklist"
                        )
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(cameraStorageBusy || selectableCameraStorageHandles.isEmpty)
                }

                HStack(spacing: 10) {
                    Button {
                        Task { await downloadSelectedCameraStorage() }
                    } label: {
                        Label("下载所选", systemImage: "arrow.down.circle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(cameraStorageBusy || selectedCameraStorageHandles.isEmpty)

                    Button(role: .destructive) {
                        confirmingCameraStorageDeletion = true
                    } label: {
                        Label("从相机删除", systemImage: "trash")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(cameraStorageBusy || selectedCameraStorageHandles.isEmpty)
                }

                if !model.wifiCamera.isConnected {
                    ContentUnavailableView(
                        "机内存储尚不可用",
                        systemImage: "externaldrive.badge.wifi",
                        description: Text(
                            "iOS / iPadOS 通过 Wi‑Fi/PTP‑IP 管理相机存储卡；系统相机与普通 UVC 视频连接不开放机内文件。"
                        )
                    )
                    .frame(maxWidth: .infinity, minHeight: 170)
                } else if cameraStorageSnapshot.items.isEmpty {
                    ContentUnavailableView(
                        cameraStorageBusy ? "正在读取存储卡" : "尚未读取机内文件",
                        systemImage: "externaldrive",
                        description: Text("连接 Wi‑Fi 相机后点击“刷新机内文件”。")
                    )
                    .frame(maxWidth: .infinity, minHeight: 170)
                } else {
                    LazyVStack(spacing: 8) {
                        ForEach(cameraStorageSnapshot.items) { item in
                            CameraStorageItemRow(
                                item: item,
                                selected: selectedCameraStorageHandles.contains(
                                    item.handle
                                ),
                                loadThumbnail: {
                                    try await model.wifiCamera.storageThumbnail(
                                        handle: item.handle
                                    )
                                },
                                toggleSelection: {
                                    if selectedCameraStorageHandles.contains(
                                        item.handle
                                    ) {
                                        selectedCameraStorageHandles.remove(
                                            item.handle
                                        )
                                    } else if !item.isProtected {
                                        selectedCameraStorageHandles.insert(
                                            item.handle
                                        )
                                    }
                                }
                            )
                        }
                    }
                }

                Text(cameraStorageStatus)
                    .font(.caption.monospaced())
                    .foregroundStyle(IPalette.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 12)
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Label(
                    "相机机内存储 · \(cameraStorageSnapshot.items.count)",
                    systemImage: "externaldrive.fill"
                )
                .font(.headline)
                Text("浏览、批量下载或从相机存储卡永久删除")
                    .font(.caption)
                    .foregroundStyle(IPalette.muted)
            }
        }
        .padding(16)
        .background(IPalette.surface, in: RoundedRectangle(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .stroke(IPalette.rule, lineWidth: 1)
        }
    }

    private var cameraStorageCapacitySummary: String {
        let capacity = cameraStorageSnapshot.capacityBytes
        guard capacity > 0 else { return cameraStorageStatus }
        let used = capacity >= cameraStorageSnapshot.freeBytes
            ? capacity - cameraStorageSnapshot.freeBytes
            : 0
        return "\(formatCameraStorageBytes(used)) 已用 / \(formatCameraStorageBytes(capacity))"
    }

    private func formatCameraStorageBytes(_ bytes: UInt64) -> String {
        ByteCountFormatter.string(
            fromByteCount: Int64(min(bytes, UInt64(Int64.max))),
            countStyle: .file
        )
    }

    @MainActor
    private func refreshCameraStorage() async {
        guard model.wifiCamera.isConnected, !cameraStorageBusy else {
            cameraStorageStatus = "请先连接 Wi‑Fi/PTP‑IP 相机"
            return
        }
        cameraStorageBusy = true
        cameraStorageStatus = "正在读取存储卷与文件信息…"
        defer { cameraStorageBusy = false }
        do {
            let snapshot = try await model.wifiCamera.listStorage()
            cameraStorageSnapshot = snapshot
            selectedCameraStorageHandles.formIntersection(
                Set(snapshot.items.map(\.handle))
            )
            cameraStorageStatus = "读取完成 · \(snapshot.items.count) 个文件"
        } catch {
            cameraStorageStatus = "读取失败 · \(error.localizedDescription)"
            DiagnosticLogger.shared.error("camera-storage", cameraStorageStatus)
        }
    }

    @MainActor
    private func downloadSelectedCameraStorage() async {
        let selected = selectedCameraStorageItems
        guard !selected.isEmpty, !cameraStorageBusy else { return }
        cameraStorageBusy = true
        defer { cameraStorageBusy = false }
        do {
            for (index, item) in selected.enumerated() {
                cameraStorageStatus =
                    "正在下载 \(index + 1) / \(selected.count) · \(item.filename)"
                let data = try await model.wifiCamera.storageObject(
                    handle: item.handle
                )
                guard model.library.saveCameraStorageObject(
                    data,
                    filename: item.filename,
                    cameraName: model.wifiCamera.cameraName
                ) != nil else {
                    throw CocoaError(.fileWriteUnknown)
                }
            }
            selectedCameraStorageHandles.removeAll()
            cameraStorageStatus = "已下载 \(selected.count) 个文件到 ZENCHE 文件库"
        } catch {
            cameraStorageStatus = "下载失败 · \(error.localizedDescription)"
            DiagnosticLogger.shared.error("camera-storage", cameraStorageStatus)
        }
    }

    @MainActor
    private func deleteSelectedCameraStorage() async {
        let selected = selectedCameraStorageItems
        guard !selected.isEmpty, !cameraStorageBusy else { return }
        cameraStorageBusy = true
        cameraStorageStatus = "正在从相机删除…"
        do {
            for item in selected {
                try await model.wifiCamera.deleteStorageObject(
                    handle: item.handle
                )
            }
            selectedCameraStorageHandles.removeAll()
            cameraStorageBusy = false
            cameraStorageStatus = "已从相机删除 \(selected.count) 个文件"
            await refreshCameraStorage()
        } catch {
            cameraStorageBusy = false
            cameraStorageStatus = "删除失败 · \(error.localizedDescription)"
            DiagnosticLogger.shared.error("camera-storage", cameraStorageStatus)
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

private struct CameraStorageItemRow: View {
    let item: CameraStorageItem
    let selected: Bool
    let loadThumbnail: () async throws -> Data
    let toggleSelection: () -> Void
    @State private var thumbnail: UIImage?

    var body: some View {
        HStack(spacing: 12) {
            Button(action: toggleSelection) {
                Image(
                    systemName: selected
                        ? "checkmark.circle.fill"
                        : "circle"
                )
                .font(.title3)
                .foregroundStyle(
                    item.isProtected ? IPalette.muted : IPalette.cobalt
                )
                .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .disabled(item.isProtected)
            .accessibilityLabel("选择 \(item.filename)")

            ZStack {
                Color.black
                if let thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .scaledToFill()
                } else {
                    Image(systemName: item.isVideo ? "play.fill" : "photo")
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
            .frame(width: 76, height: 54)
            .clipShape(RoundedRectangle(cornerRadius: 7))

            VStack(alignment: .leading, spacing: 4) {
                Text(item.filename)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text(detail)
                    .font(.caption.monospaced())
                    .foregroundStyle(IPalette.muted)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .padding(8)
        .background(
            selected ? IPalette.cobaltSoft : IPalette.paperSecondary,
            in: RoundedRectangle(cornerRadius: 12)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    selected ? IPalette.cobalt : IPalette.rule,
                    lineWidth: selected ? 1.5 : 1
                )
        }
        .task(id: item.handle) {
            guard !item.isVideo, thumbnail == nil else { return }
            if let data = try? await loadThumbnail() {
                thumbnail = UIImage(data: data)
            }
        }
    }

    private var detail: String {
        let size = ByteCountFormatter.string(
            fromByteCount: Int64(min(item.sizeBytes, UInt64(Int64.max))),
            countStyle: .file
        )
        let dimensions = item.width > 0 && item.height > 0
            ? " · \(item.width) × \(item.height)"
            : ""
        return "\(size)\(dimensions) · \(item.capturedAt)"
            + (item.isProtected ? " · 已保护" : "")
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

private struct WifiCameraTransferCard: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        SettingsCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Label("Wi‑Fi 相机 · PTP/IP", systemImage: "wifi")
                            .font(.headline)
                        Text("相机控制")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(IPalette.muted)
                    }
                    Spacer()
                    Circle()
                        .fill(
                            model.wifiCamera.isConnected
                                ? Color.green
                                : Color.secondary
                        )
                        .frame(width: 9, height: 9)
                }
                Text("先在相机中开启无线遥控/PTP‑IP，并让本机加入相机热点或同一局域网。默认端口为 15740。")
                    .font(.subheadline)
                    .foregroundStyle(IPalette.muted)
                Picker(
                    "连接模式",
                    selection: Binding(
                        get: { model.wifiCamera.connectionMode },
                        set: { model.wifiCamera.connectionMode = $0 }
                    )
                ) {
                    ForEach(WifiConnectionMode.allCases) { mode in
                        RuntimeLocalizedText(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .disabled(
                    model.wifiCamera.isConnected ||
                        model.wifiCamera.state == .connecting
                )
                RuntimeLocalizedText(model.wifiCamera.connectionMode.guidance)
                    .font(.caption)
                    .foregroundStyle(IPalette.muted)
                HStack(spacing: 10) {
                    TextField(
                        "相机 IP 地址",
                        text: Binding(
                            get: { model.wifiCamera.host },
                            set: { model.wifiCamera.host = $0 }
                        )
                    )
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .textFieldStyle(.roundedBorder)
                    TextField(
                        "端口",
                        text: Binding(
                            get: { model.wifiCamera.portText },
                            set: { model.wifiCamera.portText = $0 }
                        )
                    )
                        .keyboardType(.numberPad)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 92)
                }
                RuntimeLocalizedText(model.wifiCamera.status)
                    .font(.caption)
                    .foregroundStyle(
                        model.wifiCamera.isConnected
                            ? Color.green
                            : IPalette.muted
                    )
                Button {
                    model.wifiCamera.isConnected
                        ? model.wifiCamera.disconnect()
                        : model.wifiCamera.connect()
                } label: {
                    Label(
                        model.wifiCamera.isConnected
                            ? "断开 Wi‑Fi 相机"
                            : "连接 Wi‑Fi 相机",
                        systemImage: model.wifiCamera.isConnected
                            ? "wifi.slash"
                            : "wifi"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(model.wifiCamera.state == .connecting)
            }
        }
    }
}

private struct WirelessTransferCard: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(spacing: 14) {
            WifiCameraTransferCard()
            SettingsCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Label(
                            "多协议无线图片收件箱",
                            systemImage: "tray.and.arrow.down"
                        )
                        .font(.headline)
                        Text("文件接收")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(IPalette.muted)
                    }
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
}

private struct AppSettingsSheet: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @State private var showingLogs = false
    @State private var showingDonation = false
    @State private var activationCode = ""
    @State private var activationStatus = ""
    @State private var oldDeviceId = ""
    @State private var oldActivationCode = ""
    @State private var isRebindingActivation = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    SettingsSectionHeader(
                        title: "通用",
                        detail: "界面语言与本地保存偏好"
                    )
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
                            Label(
                                "拍摄后自动存入“照片”",
                                systemImage: "photo.badge.plus"
                            )
                        }
                    }

                    SettingsSectionHeader(
                        title: "拍摄辅助",
                        detail: "蓝牙遥控与拍摄定位"
                    )
                    SettingsCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Toggle(
                                isOn: Binding(
                                    get: { model.bluetoothRemote.enabled },
                                    set: { model.bluetoothRemote.setEnabled($0) }
                                )
                            ) {
                                Label(
                                    "蓝牙遥控快门",
                                    systemImage: "button.programmable"
                                )
                            }
                            RuntimeLocalizedText(model.bluetoothRemote.status)
                                .font(.caption)
                                .foregroundStyle(IPalette.muted)
                            Text("兼容 ZENCHE BLE Remote 服务；遥控器发出快门通知后，将触发当前已连接相机。")
                                .font(.caption)
                                .foregroundStyle(IPalette.muted)

                            Divider()

                            Toggle(
                                isOn: Binding(
                                    get: { model.locationTagging.enabled },
                                    set: { model.locationTagging.setEnabled($0) }
                                )
                            ) {
                                Label("拍摄定位", systemImage: "location.fill")
                            }
                            RuntimeLocalizedText(model.locationTagging.status)
                                .font(.caption)
                                .foregroundStyle(IPalette.muted)
                            Text("仅在应用使用期间定位；下载的照片会生成包含 GPS 信息的标准 XMP 旁车文件。")
                                .font(.caption)
                                .foregroundStyle(IPalette.muted)
                        }
                    }

                    SettingsSectionHeader(
                        title: "相机兼容性",
                        detail: "当前平台使用的连接后端"
                    )
                    SettingsCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("尼康官方 SDK", systemImage: "checkmark.seal")
                                .font(.headline)
                            Text("官方桌面 SDK 不提供当前平台运行库")
                                .font(.subheadline.weight(.semibold))
                            Text("尼康只为 macOS 与 Windows 提供本次 SDK 运行库；当前平台继续使用原生相机连接后端。")
                                .font(.subheadline)
                                .foregroundStyle(IPalette.muted)
                        }
                    }

                    SettingsCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("索尼官方 SDK", systemImage: "camera.aperture")
                                .font(.headline)
                            Text("官方桌面 SDK 不提供当前平台运行库")
                                .font(.subheadline.weight(.semibold))
                            Text("索尼 Camera Remote SDK 2.02.00 只提供 macOS 与 Windows 运行库；当前平台继续使用原生 Camera Remote Command 连接后端。")
                                .font(.subheadline)
                                .foregroundStyle(IPalette.muted)
                        }
                    }

                    SettingsSectionHeader(
                        title: "服务与维护",
                        detail: "软件更新、AI 服务、诊断与支持"
                    )
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
                                    Text("状态：已激活 · 剩余 \(ActivationManager.remainingUsage) 次").font(.caption.weight(.semibold)).foregroundStyle(Color.green)
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
                        Divider()
                        VStack(alignment: .leading, spacing: 8) {
                            Text("恢复设备码")
                                .font(.system(size: 13, weight: .semibold))
                            TextField("旧设备 ID", text: $oldDeviceId)
                                .textFieldStyle(.roundedBorder)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                            SecureField("旧激活码", text: $oldActivationCode)
                                .textFieldStyle(.roundedBorder)
                            Text("恢复成功后，AI 权益和剩余次数将迁移到当前设备；旧设备绑定会永久失效。")
                                .font(.caption2)
                                .foregroundStyle(IPalette.muted)
                                .fixedSize(horizontal: false, vertical: true)
                            Button {
                                Task { await restoreDeviceBinding() }
                            } label: {
                                Text(isRebindingActivation ? "正在迁移…" : "恢复到当前设备")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .disabled(isRebindingActivation)
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

    @MainActor
    private func restoreDeviceBinding() async {
        let oldId = oldDeviceId.trimmingCharacters(in: .whitespacesAndNewlines)
        let oldCode = oldActivationCode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !oldId.isEmpty, !oldCode.isEmpty else {
            activationStatus = RuntimeLocalization.text(
                "请输入旧设备 ID 和旧激活码",
                locale: locale
            )
            return
        }
        guard ActivationManager.verify(code: oldCode, deviceId: oldId) else {
            activationStatus = RuntimeLocalization.text(
                "旧设备 ID 与旧激活码不匹配或已过期",
                locale: locale
            )
            return
        }

        isRebindingActivation = true
        activationStatus = RuntimeLocalization.text("正在迁移…", locale: locale)
        defer { isRebindingActivation = false }
        do {
            let result = try await AiRebindService.rebind(
                oldCode: oldCode,
                oldDeviceId: oldId,
                newDeviceId: ActivationManager.deviceId
            )
            guard ActivationManager.verify(
                code: result.newCode,
                deviceId: ActivationManager.deviceId
            ) else {
                activationStatus = RuntimeLocalization.text(
                    "服务器返回的新激活码验证失败，未修改本机数据",
                    locale: locale
                )
                return
            }
            ActivationManager.storeVerifiedActivation(
                code: result.newCode,
                remaining: result.remaining
            )
            oldDeviceId = ""
            oldActivationCode = ""
            activationStatus = RuntimeLocalization.text(
                "设备码恢复成功，AI 权益已迁移到当前设备",
                locale: locale
            )
        } catch {
            let prefix = RuntimeLocalization.text("设备码恢复失败：", locale: locale)
            activationStatus = prefix + error.localizedDescription
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

private struct SettingsSectionHeader: View {
    let title: LocalizedStringKey
    let detail: LocalizedStringKey

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.title3.weight(.bold))
            Text(detail)
                .font(.subheadline)
                .foregroundStyle(IPalette.muted)
        }
        .padding(.top, 8)
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

                    Text("• 修复 AI 修图原图选择：进入修图即可预览当前原图，切换照片会清除旧 AI 结果。\n• 新增“智能移除”：支持去路人并自然补全背景，以及去除摄影器材、工作人员、反光和杂物等穿帮元素。\n• 重做蒙版预览：智能蒙版和画笔蒙版以真实蓝色覆盖显示，橡皮擦除蓝色区域，不再绘制白色。\n• 修复蒙版删除与局部调整合成，曝光、对比度、色彩、细节只作用于对应蒙版区域。\n• 延长移动端 AI 请求等待时间，并展示服务端错误详情，减少长任务被误判失败。\n• iOS / iPadOS、Android、HarmonyOS、macOS、Windows 五端同步更新。")
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
                        Text("本机摄像头与 UVC")
                            .font(.headline)

                        if model.camera.availableDevices.isEmpty {
                            ContentUnavailableView(
                                "未发现相机",
                                systemImage: "video.slash",
                                description: Text("请检查系统相机权限，或连接外接 UVC 设备。")
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
                if model.hasAnyCameraConnection {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("断开", role: .destructive) {
                            model.disconnectAllCameras()
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
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
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
                    .font(
                        .system(
                            size: horizontalSizeClass == .compact ? 25 : 29,
                            weight: .bold
                        )
                    )
                    .foregroundStyle(IPalette.ink)
                Text(LocalizedStringKey(subtitle))
                    .font(horizontalSizeClass == .compact ? .footnote : .subheadline)
                    .foregroundStyle(IPalette.muted)
                    .fixedSize(horizontal: false, vertical: true)
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
