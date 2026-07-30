import AVFoundation
import AVKit
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
    static let paper = Color(red: 0.965, green: 0.973, blue: 0.988)
    static let paperSecondary = Color(red: 0.937, green: 0.953, blue: 0.976)
    static let surface = Color(red: 0.992, green: 0.996, blue: 1.0)
    static let ink = Color(red: 0.075, green: 0.09, blue: 0.12)
    static let muted = Color(red: 0.36, green: 0.40, blue: 0.47)
    static let cobalt = Color(red: 0.02, green: 0.35, blue: 0.82)
    static let cobaltSoft = Color(red: 0.88, green: 0.93, blue: 1.0)
    static let video = Color(red: 0.82, green: 0.12, blue: 0.16)
    static let videoSoft = Color(red: 1.0, green: 0.90, blue: 0.91)
    static let graphite = Color(red: 0.045, green: 0.055, blue: 0.075)
    static let rule = Color.black.opacity(0.10)
    static let shadow = Color(red: 0.05, green: 0.09, blue: 0.16).opacity(0.10)
}

private let afdianURL = URL(string: "https://www.ifdian.net/a/Tauber")!

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
                        .fill(IPalette.graphite)
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
        ) as? String ?? "1.1.0"
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
                        BottomNavigation()
                    }

                    StatusBar()
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
            .preferredColorScheme(.light)
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
        .preferredColorScheme(.light)
        .environment(\.colorScheme, .light)
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
                    .fill(Color(red: 0.08, green: 0.11, blue: 0.16))
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
        case .ready: return .green
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
                    .fill(IPalette.graphite)
                    .frame(width: 34, height: 34)
                Text("Z")
                    .font(.system(size: 16, weight: .heavy))
                    .foregroundStyle(.white)
            }
            .padding(.bottom, 10)
            groupLabel("创作")
            navigationButton(.capture)
            navigationButton(.monitor)
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
                Text(LocalizedStringKey(section.rawValue))
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
                        Text(LocalizedStringKey(section.rawValue))
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
        case .library: LibraryPage()
        }
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
                    subtitle: "快门、曝光、对焦、变焦与构图辅助集中在当前页面。"
                )

                CameraStage {
                    showingFullscreen = true
                }
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
                    Text("iPad 可搜索外接 UVC 相机；iPhone 可使用本机镜头。")
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
            Button {
                showsParameters.toggle()
            } label: {
                Label(
                    showsParameters ? "收起参数" : "展开参数",
                    systemImage: showsParameters ? "chevron.down" : "chevron.up"
                )
                .font(.caption.weight(.semibold))
                .frame(minWidth: 104, minHeight: 44)
            }
            .buttonStyle(ImmersiveControlStyle())

            if showsParameters {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        if mode == .video {
                            ImmersiveParameterStepper(
                                title: "快门角度",
                                value: String(format: "%.1f°", model.camera.shutterAngle),
                                enabled: model.camera.supportsCustomExposure,
                                lockedReason: "当前设备不支持自定义曝光",
                                decrease: { adjustVideoShutterAngle(-1) },
                                increase: { adjustVideoShutterAngle(1) }
                            )
                            ImmersiveParameterStepper(
                                title: "ISO",
                                value: "\(Int(model.camera.exposureISO.rounded()))",
                                enabled: model.camera.supportsCustomExposure,
                                lockedReason: "当前设备不支持自定义 ISO",
                                decrease: { adjustVideoISO(-1) },
                                increase: { adjustVideoISO(1) }
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
                            ImmersiveParameterStepper(
                                title: "ISO",
                                value: "\(Int(model.camera.exposureISO.rounded()))",
                                enabled: model.camera.supportsCustomExposure,
                                lockedReason: "当前设备未开放自定义 ISO",
                                decrease: { adjustVideoISO(-1) },
                                increase: { adjustVideoISO(1) }
                            )
                        }
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
                    .padding(.horizontal, 2)
                }
            }
        }
        .disabled(model.camera.state != .ready)
        .padding(.bottom, 10)
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
            }
            .frame(minWidth: 74)
            Button(action: increase) {
                Image(systemName: "plus")
                    .frame(width: 44, height: 44)
            }
        }
        .buttonStyle(ImmersiveControlStyle())
        .padding(4)
        .background(.black.opacity(0.54), in: RoundedRectangle(cornerRadius: 12))
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
            Text("相机参数")
                .font(.headline)

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
            Text("拍摄任务")
                .font(.headline)
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
                "拍摄会话",
                systemImage: model.captureWorkflow.isActive
                    ? "folder.badge.gearshape"
                    : "folder.badge.plus"
            )
            .font(.headline)
        }
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

private struct LibraryPage: View {
    @EnvironmentObject private var model: AppModel
    @State private var showingCloudImporter = false
    @State private var showingCloudGuide = false
    @State private var previewItem: LibraryItem?
    @State private var systemPreviewItem: SystemAlbumItem?
    @State private var systemAlbumItems: [SystemAlbumItem] = []
    @State private var systemAlbumStatus = "正在读取系统相册…"
    @State private var systemAlbumExpanded = true
    @State private var systemPhotosExpanded = true
    @State private var systemVideosExpanded = true
    @State private var wirelessExpanded = false
    @State private var localLibraryExpanded = true
    @State private var localPhotosExpanded = true
    @State private var localVideosExpanded = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    PageTitle(
                        title: "文件与传输",
                        subtitle: "\(model.library.items.count) 个本地文件 · 无线照片自动入库"
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

                CaptureSessionCard()

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

                DisclosureGroup(isExpanded: $localLibraryExpanded) {
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
                                model.library.deleteSelected()
                            } label: {
                                Label("删除", systemImage: "trash")
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                    if model.library.items.isEmpty {
                        ContentUnavailableView(
                            "暂无文件",
                            systemImage: "photo.on.rectangle.angled",
                            description: Text("拍摄、导入或无线接收的文件会显示在这里。")
                        )
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 260)
                    } else {
                        DisclosureGroup(
                            "照片 · \(model.library.items.filter { !$0.isVideo }.count)",
                            isExpanded: $localPhotosExpanded
                        ) {
                            localLibraryGrid(model.library.items.filter { !$0.isVideo })
                        }
                        DisclosureGroup(
                            "视频 · \(model.library.items.filter(\.isVideo).count)",
                            isExpanded: $localVideosExpanded
                        ) {
                            localLibraryGrid(model.library.items.filter(\.isVideo))
                        }
                    }
                } label: {
                    Label(
                        "帧澈 ZENCHE 文件库 · \(model.library.items.count)",
                        systemImage: "folder"
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
        .fullScreenCover(item: $previewItem) { item in
            LibraryLargePhotoView(item: item)
        }
        .fullScreenCover(item: $systemPreviewItem) { item in
            SystemAlbumPreviewView(item: item)
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
                .preferredColorScheme(.light)
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

                    Text("• 新增间隔拍摄、曝光包围、焦点包围与 B 门计时。\n• 新增项目会话、命名模板、RAW + JPEG 配对、双目标备份与 SHA-256。\n• 新增 RGB 直方图、波形、矢量示波器、峰值对焦与假色。")
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

private struct StatusBar: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: statusIcon)
                .foregroundStyle(statusColor)
            RuntimeLocalizedText(model.statusMessage)
                .lineLimit(1)
            Spacer()
            Text("本次 · \(model.library.items.count) 张")
                .foregroundStyle(IPalette.muted)
        }
        .font(.caption)
        .padding(.horizontal, 14)
        .frame(height: 30)
        .background(IPalette.graphite)
        .foregroundStyle(Color.white.opacity(0.82))
    }

    private var statusIcon: String {
        model.camera.state == .ready ? "checkmark.circle.fill" : "info.circle"
    }

    private var statusColor: Color {
        model.camera.state == .ready ? .green : .secondary
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
