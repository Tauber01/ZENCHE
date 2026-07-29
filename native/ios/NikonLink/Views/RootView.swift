import AVFoundation
import SwiftUI
import UniformTypeIdentifiers
import UIKit

struct RootView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color(red: 0.035, green: 0.045, blue: 0.06)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    AppHeader()
                    Divider().overlay(Color.white.opacity(0.08))

                    if proxy.size.width >= 820 {
                        HStack(spacing: 0) {
                            SideNavigation()
                            Divider().overlay(Color.white.opacity(0.08))
                            CurrentPage()
                        }
                    } else {
                        CurrentPage()
                        Divider().overlay(Color.white.opacity(0.08))
                        BottomNavigation()
                    }

                    StatusBar()
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
        .padding(.vertical, 10)
    }

    private var brand: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 11)
                    .fill(Color(red: 0.08, green: 0.11, blue: 0.16))
                Text("N")
                    .font(.system(size: 24, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
            }
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 2) {
                Text("Nikon Link")
                    .font(.headline)
                Text("原生 iOS / iPadOS")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
                Text(model.camera.state.title)
                    .lineLimit(1)
            }
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 12)
            .frame(height: 38)
        }
        .buttonStyle(.bordered)
    }

    private var settingsButton: some View {
        Button {
            model.showingSettings = true
        } label: {
            Image(systemName: "gearshape")
                .font(.system(size: 17, weight: .semibold))
                .frame(width: 38, height: 38)
        }
        .buttonStyle(.bordered)
        .accessibilityLabel("打开设置")
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
        .frame(width: 100)
        .background(Color.black.opacity(0.12))
    }

    private func groupLabel(_ title: String) -> some View {
        Text(title)
            .font(.caption2.monospaced().weight(.semibold))
            .foregroundStyle(.secondary)
            .frame(width: 78, alignment: .leading)
            .padding(.leading, 4)
    }

    private func navigationButton(_ section: AppSection) -> some View {
        let active = model.section == section
        let accent = section == .monitor ? Color.red : Color.accentColor
        return Button {
            model.section = section
        } label: {
            VStack(spacing: 7) {
                Image(systemName: section.icon)
                    .font(.system(size: 20, weight: .medium))
                Text(section.rawValue)
                    .font(.caption.weight(.medium))
            }
            .foregroundStyle(active ? accent : .secondary)
            .frame(width: 78, height: 62)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(active ? accent.opacity(0.14) : .clear)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct BottomNavigation: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        HStack {
            ForEach(AppSection.allCases) { section in
                Button {
                    model.section = section
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: section.icon)
                            .font(.system(size: 18, weight: .medium))
                        Text(section.rawValue)
                            .font(.caption2)
                    }
                    .foregroundStyle(model.section == section ? Color.accentColor : .secondary)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
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

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                PageTitle(
                    title: "照片拍摄",
                    subtitle: "快门、曝光、对焦、变焦与构图辅助集中在当前页面。"
                )

                CameraStage()
                CaptureActionBar()
                CaptureParameterDeck()
            }
            .padding(20)
        }
    }
}

private struct CameraStage: View {
    @EnvironmentObject private var model: AppModel

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
                        .foregroundStyle(.secondary)
                    Text("等待相机画面")
                        .font(.title3.weight(.semibold))
                    Text("iPad 可搜索外接 UVC 相机；iPhone 可使用本机镜头。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Button("选择相机") {
                        model.showingConnection = true
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(30)
            }
        }
        .aspectRatio(16 / 10, contentMode: .fit)
        .overlay(alignment: .topLeading) {
            HStack(spacing: 7) {
                Circle()
                    .fill(model.camera.state == .ready ? Color.green : Color.red)
                    .frame(width: 7, height: 7)
                Text(model.camera.deviceName.uppercased())
                    .font(.caption2.monospaced().weight(.semibold))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(.black.opacity(0.55), in: Capsule())
            .padding(12)
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
                    in: 1...max(1, Double(model.camera.maxZoomFactor)),
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
        .background(Color.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 18))
    }
}

private struct CapabilityChip: View {
    let title: String
    let available: Bool

    var body: some View {
        Label(title, systemImage: available ? "checkmark.circle.fill" : "minus.circle")
            .font(.caption.weight(.medium))
            .foregroundStyle(available ? Color.green : Color.secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Color.white.opacity(0.05), in: Capsule())
    }
}

private struct MonitorPage: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                PageTitle(
                    title: "视频监看",
                    subtitle: "系统视频设备预览、监看参数与输出规格。"
                )
                CameraStage()
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

private struct MonitorParameterDeck: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("参数调节")
                .font(.headline)
            Text("按当前视频设备公开的能力调整。")
                .font(.subheadline)
                .foregroundStyle(.secondary)

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
                        .foregroundStyle(.secondary)
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
                .foregroundStyle(.secondary)

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
                    in: 1...max(1, Double(model.camera.maxZoomFactor)),
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

            Text("画面尺寸/帧频会切换 AVFoundation 的采集格式；编码仅保存为输出偏好，不改变实时取景输入，也不会修改 Nikon 机身的视频文件类型。")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 16))
    }
}

private struct LibraryPage: View {
    @EnvironmentObject private var model: AppModel
    @State private var showingImporter = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    PageTitle(
                        title: "文件与传输",
                        subtitle: "\(model.library.items.count) 个本地文件 · 无线收件箱与文件管理"
                    )
                    Spacer()
                    Button {
                        showingImporter = true
                    } label: {
                        Label("导入", systemImage: "square.and.arrow.down")
                    }
                    .buttonStyle(.bordered)
                }

                WirelessTransferCard()

                HStack {
                    Text("本地文件")
                        .font(.headline)
                    Spacer()
                    if let selected = model.library.selectedItem {
                        Text(selected.filename)
                            .font(.caption.monospaced())
                            .lineLimit(1)
                        ShareLink(item: selected.url) {
                            Label("分享", systemImage: "square.and.arrow.up")
                        }
                        .buttonStyle(.bordered)
                        Button(role: .destructive) {
                            model.library.deleteSelected()
                        } label: {
                            Label("删除", systemImage: "trash")
                        }
                        .buttonStyle(.bordered)
                    }
                }

                if model.library.items.isEmpty {
                    ContentUnavailableView(
                        "暂无照片",
                        systemImage: "photo.on.rectangle.angled",
                        description: Text("拍摄、导入或无线接收的文件会显示在这里。")
                    )
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 260)
                } else {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 150), spacing: 12)],
                        spacing: 12
                    ) {
                        ForEach(model.library.items) { item in
                            LibraryThumbnail(
                                item: item,
                                selected: model.library.selectedItemID == item.id
                            )
                            .onTapGesture {
                                model.library.selectedItemID = item.id
                            }
                        }
                    }
                }
            }
            .padding(20)
        }
        .fileImporter(
            isPresented: $showingImporter,
            allowedContentTypes: [.image],
            allowsMultipleSelection: true
        ) { result in
            if case .success(let urls) = result {
                model.library.importFiles(urls)
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
                if let image = UIImage(contentsOfFile: item.url.path) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    Image(systemName: "photo")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(height: 125)
            .clipped()
            .background(Color.black.opacity(0.35))
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
                    Label("Nikon 无线收件箱", systemImage: "wifi")
                        .font(.headline)
                    Spacer()
                    Circle()
                        .fill(model.wireless.isRunning ? Color.green : Color.secondary)
                        .frame(width: 8, height: 8)
                    Text(model.wireless.isRunning ? "接收中" : "已停止")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                Text(model.wireless.status)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if model.wireless.isRunning {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("\(model.wireless.hostAddress):\(WirelessTransferServer.port)")
                            .font(.body.monospaced().weight(.semibold))
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

                Text("相机 FTP 端口设为 2121，用户名与密码均为 nikonlink，并开启 PASV。服务只在 Nikon Link 位于前台时运行。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct AppSettingsSheet: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var showingLogs = false
    @State private var showingDonation = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    SettingsCard {
                        Toggle(isOn: $model.autoSaveToPhotos) {
                            Label("拍摄后自动存入“照片”", systemImage: "photo.badge.plus")
                        }
                    }

                    SettingsCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("诊断日志", systemImage: "doc.text.magnifyingglass")
                                .font(.headline)
                            Text("按日写入、5 MB 滚动并保留 14 天；查询与上传前会自动脱敏。")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            ViewThatFits(in: .horizontal) {
                                HStack(spacing: 10) {
                                    logButtons
                                }
                                VStack(spacing: 10) {
                                    logButtons
                                }
                            }
                        }
                    }

                    SettingsCard {
                        HStack(spacing: 14) {
                            Image(systemName: "cup.and.saucer.fill")
                                .font(.title2)
                                .foregroundStyle(.orange)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("喜欢 Nikon Link？")
                                    .font(.headline)
                                Text("请作者喝杯奶茶，支持后续维护与新机型适配。")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
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
                            Text("Nikon Link 不上传照片，也不包含分析服务。只有你点击上传并在 GitHub 确认时，预览中的脱敏日志才会发送。")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(20)
            }
            .navigationTitle("设置")
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

private struct DonationSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if let image = UIImage(named: "wechat-donation") {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .padding(20)
                } else {
                    ContentUnavailableView(
                        "二维码未找到",
                        systemImage: "qrcode",
                        description: Text("请重新安装 Nikon Link 后再试。")
                    )
                }
            }
            .navigationTitle("请作者喝奶茶")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
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
            .background(Color.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 18))
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
                        Text("iOS 没有向普通应用开放通用 USB/PTP 相机控制。要控制 Nikon Link 已适配的 EXPEED 6 / 7 相机并下载原图，需要 Nikon 提供 iOS 协议授权或官方 SDK。这里不会把普通视频连接伪装成 Nikon 原生控制。")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
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
                            .foregroundStyle(.secondary)
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.green.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
                    }
                }
                .padding(20)
            }
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
                    Text(title)
                        .font(.headline)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
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

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 28, weight: .bold, design: .rounded))
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

private struct StatusBar: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: statusIcon)
                .foregroundStyle(statusColor)
            Text(model.statusMessage)
                .lineLimit(1)
            Spacer()
            Text("本次 · \(model.library.items.count) 张")
                .foregroundStyle(.secondary)
        }
        .font(.caption)
        .padding(.horizontal, 14)
        .frame(height: 30)
        .background(Color.black.opacity(0.35))
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
