import AppKit
import SwiftUI
import UniformTypeIdentifiers

enum RuntimeLocalization {
    private static let tables: [String: [String: String]] = [
        "en": loadTable(language: "en"),
        "ja": loadTable(language: "ja")
    ]

    static func text(_ source: String, locale: Locale) -> String {
        let language = languageCode(for: locale)
        guard language != "zh-Hans", let table = tables[language] else {
            return source
        }
        if let exact = table[source] {
            return exact
        }

        // Camera state, transfer state, and error messages often contain a
        // filename, camera name, or count. Translate their stable fragments
        // using the same Localizable.strings table used by SwiftUI literals.
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

    private static func languageCode(for locale: Locale) -> String {
        let identifier = locale.identifier.lowercased()
        if identifier.hasPrefix("ja") { return "ja" }
        if identifier.hasPrefix("en") { return "en" }
        return "zh-Hans"
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

struct RuntimeLocalizedText: View {
    @Environment(\.locale) private var locale
    let source: String

    init(_ source: String) {
        self.source = source
    }

    var body: some View {
        Text(RuntimeLocalization.text(source, locale: locale))
    }
}

enum InterfaceLanguage: String, CaseIterable, Identifiable {
    case simplifiedChinese = "zh-Hans"
    case english = "en"
    case japanese = "ja"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .simplifiedChinese: return "简体中文"
        case .english: return "English"
        case .japanese: return "日本語"
        }
    }

    var locale: Locale {
        Locale(identifier: rawValue)
    }
}

/// 界面主题三态。system 跟随系统外观，light/dark 强制亮或暗。
enum ThemeMode: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: return "跟随系统"
        case .light: return "亮色"
        case .dark: return "暗色"
        }
    }

    /// SwiftUI 环境用的配色方案；system 返回 nil 表示不覆盖。
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    /// AppKit 全局外观；system 返回 nil 表示跟随系统。
    var appKitAppearance: NSAppearance? {
        switch self {
        case .system: return nil
        case .light: return NSAppearance(named: .aqua)
        case .dark: return NSAppearance(named: .darkAqua)
        }
    }
}

/// 设置面板专用色板。与主 Palette 重复的 token（ink/muted/cobalt/cobaltSoft/
/// positive/rule，base 即 Palette.paper）直接转发主 Palette，保持单一来源；
/// support/supportSoft/card 为设置面板独有，本地保留。
private enum SettingsPalette {
    private static func dynamic(
        light: (Double, Double, Double),
        dark: (Double, Double, Double)
    ) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            let rgb = isDark ? dark : light
            return NSColor(srgbRed: rgb.0, green: rgb.1, blue: rgb.2, alpha: 1)
        })
    }

    static var ink: Color { Palette.ink }
    static var muted: Color { Palette.muted }
    static var cobalt: Color { Palette.cobalt }
    static var positive: Color { Palette.positive }
    static var cobaltSoft: Color { Palette.cobaltSoft }
    static var rule: Color { Palette.rule }
    /// 面板底：即主 Palette.paper，用于 Sheet 背景。
    static var base: Color { Palette.paper }
    static let support = dynamic(
        light: (0.941, 0.451, 0.298), dark: (0.980, 0.560, 0.404))
    static let supportSoft = dynamic(
        light: (1.0, 0.941, 0.902), dark: (0.243, 0.157, 0.110))
    /// 卡片面：亮色为纯白，暗色为提升面板，替代原先硬编码的 Color.white。
    static let card = dynamic(
        light: (1.0, 1.0, 1.0), dark: (0.137, 0.153, 0.180))
}

private let afdianURL = URL(string: "https://www.ifdian.net/a/Tauber")!
private let zencheWebsiteURL = URL(string: "https://zenche.top")!

struct SettingsSheet: View {
    @ObservedObject var updater: UpdateController
    let auth: AuthService
    @ObservedObject var desktopLayout: DesktopWorkspaceLayout
    @Binding var languageRaw: String
    @Binding var themeRaw: String
    @ObservedObject var bluetoothRemote: BluetoothRemoteService
    @ObservedObject var locationTagging: LocationTaggingService
    @Binding var livePhotoEnabled: Bool
    @Binding var livePhotoSeconds: Double
    @Environment(\.dismiss) private var dismiss
    @State private var showDonation = false
    @State private var showLogViewer = false
    @State private var logExportMessage: String?
    @State private var activationCode = ""
    @State private var activationStatus = ""
    @State private var oldDeviceId = ""
    @State private var oldActivationCode = ""
    @State private var isRebindingActivation = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SpaceToken.s20) {
            HStack {
                VStack(alignment: .leading, spacing: SpaceToken.s4) {
                    Text("设置")
                        .font(.system(size: TypeScale.heading, weight: .bold))
                    HStack(spacing: SpaceToken.s4) {
                        Text("帧澈 ZENCHE")
                        Text(updater.currentVersion)
                    }
                    .foregroundStyle(SettingsPalette.muted)
                    RuntimeLocalizedText("通用、拍摄辅助、更新、诊断与支持。")
                        .font(.system(size: TypeScale.body))
                        .foregroundStyle(SettingsPalette.muted)
                }
                Spacer()
                HStack(spacing: SpaceToken.s4) {
                    Image(systemName: "globe")
                        .foregroundStyle(SettingsPalette.muted)
                    ForEach(InterfaceLanguage.allCases) { language in
                        Button {
                            languageRaw = language.rawValue
                        } label: {
                            Text(language.displayName)
                                .font(
                                    .system(
                                        size: TypeScale.caption, // v1.5.7 P6: 语言选择器文本 11（等值映射 TypeScale.caption，只归档不改值）
                                        weight: language.rawValue == languageRaw
                                            ? .bold
                                            : .medium
                                    )
                                )
                                .padding(.horizontal, SpaceToken.s8)
                                .frame(height: 28)
                                .background(
                                    language.rawValue == languageRaw
                                        ? SettingsPalette.cobaltSoft
                                        : Color.clear
                                )
                                .clipShape(
                                    RoundedRectangle(cornerRadius: RadiusToken.r6)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .fixedSize()
                Button("完成") { dismiss() }
                    .buttonStyle(.plain)
            }

            // W13-c：账号区（邮箱 + 退出登录；登出后回登录墙）
            settingsCard {
                HStack(alignment: .top, spacing: SpaceToken.s12) {
                    settingIcon("person.crop.circle.fill", color: SettingsPalette.cobalt)
                    VStack(alignment: .leading, spacing: SpaceToken.s4) {
                        RuntimeLocalizedText("当前账号")
                            .font(.system(size: TypeScale.emphasis, weight: .semibold))
                        Text(auth.account?.email ?? "未登录")
                            .font(.system(size: TypeScale.title, weight: .bold))
                            .foregroundStyle(SettingsPalette.ink)
                            .textSelection(.enabled)
                    }
                    Spacer()
                }

                Divider()

                Button(role: .destructive) {
                    Task {
                        await auth.logout()
                        dismiss()
                    }
                } label: {
                    Label("退出登录", systemImage: "rectangle.portrait.and.arrow.right")
                        .font(.system(size: TypeScale.body, weight: .semibold))
                        .foregroundStyle(SettingsPalette.support)
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                }
                .buttonStyle(.plain)

                RuntimeLocalizedText("退出后将清除本机登录令牌，需重新登录才能使用全部功能。")
                    .font(.system(size: TypeScale.caption))
                    .foregroundStyle(SettingsPalette.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            settingsCard {
                HStack(alignment: .top, spacing: SpaceToken.s12) {
                    settingIcon("circle.lefthalf.filled", color: SettingsPalette.cobalt)
                    VStack(alignment: .leading, spacing: SpaceToken.s4) {
                        RuntimeLocalizedText("外观")
                            .font(.system(size: TypeScale.title, weight: .bold))
                        RuntimeLocalizedText("选择界面主题。跟随系统会随 macOS 明暗外观自动切换；实时画面区在任一主题下都保持石墨黑以保证取景判断。")
                            .font(.system(size: TypeScale.body))
                            .foregroundStyle(SettingsPalette.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                    HStack(spacing: SpaceToken.s4) {
                        ForEach(ThemeMode.allCases) { mode in
                            themeButton(mode)
                        }
                    }
                    .padding(SpaceToken.s4)
                    .background(SettingsPalette.base)
                    .clipShape(RoundedRectangle(cornerRadius: RadiusToken.r8))
                    .fixedSize()
                }
            }

            settingsCard {
                HStack(alignment: .top, spacing: SpaceToken.s12) {
                    settingIcon("rectangle.3.group", color: SettingsPalette.cobalt)
                    VStack(alignment: .leading, spacing: SpaceToken.s4) {
                        RuntimeLocalizedText("桌面工作区")
                            .font(.system(size: TypeScale.title, weight: .bold))
                        RuntimeLocalizedText("拖动窗口边缘、主导航与面板分隔条可调整大小；窗口位置和布局会在下次启动时恢复。")
                            .font(.system(size: TypeScale.body))
                            .foregroundStyle(SettingsPalette.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                }

                Divider()

                HStack(spacing: SpaceToken.s8) {
                    ForEach(DesktopWorkspacePreset.allCases) { preset in
                        Button {
                            desktopLayout.apply(preset)
                        } label: {
                            RuntimeLocalizedText(preset.title)
                                .font(.system(size: TypeScale.body, weight: .semibold))
                                .frame(maxWidth: .infinity)
                                .frame(height: 36)
                        }
                        .buttonStyle(.bordered)
                    }
                }

                HStack {
                    RuntimeLocalizedText("预设会调整窗口和面板尺寸；之后仍可继续自由拖动。")
                        .font(.system(size: TypeScale.caption))
                        .foregroundStyle(SettingsPalette.muted)
                    Spacer()
                    Button {
                        desktopLayout.reset()
                    } label: {
                        Label("恢复默认布局", systemImage: "arrow.counterclockwise")
                            .font(.system(size: TypeScale.body, weight: .semibold))
                    }
                    .buttonStyle(.bordered)
                }
            }

            settingsCard {
                HStack(alignment: .top, spacing: SpaceToken.s12) {
                    settingIcon(
                        "dot.radiowaves.left.and.right",
                        color: SettingsPalette.cobalt
                    )
                    VStack(alignment: .leading, spacing: SpaceToken.s4) {
                        RuntimeLocalizedText("拍摄辅助")
                            .font(.system(size: TypeScale.title, weight: .bold))
                        RuntimeLocalizedText("蓝牙遥控与拍摄定位")
                            .font(.system(size: TypeScale.body))
                            .foregroundStyle(SettingsPalette.muted)
                    }
                }

                Divider()

                HStack(alignment: .top, spacing: SpaceToken.s12) {
                    VStack(alignment: .leading, spacing: SpaceToken.s4) {
                        RuntimeLocalizedText("蓝牙遥控拍摄")
                            .font(.system(size: TypeScale.emphasis, weight: .semibold))
                        RuntimeLocalizedText(bluetoothRemote.status)
                            .font(.system(size: TypeScale.body))
                            .foregroundStyle(
                                bluetoothRemote.connected
                                    ? SettingsPalette.positive
                                    : SettingsPalette.muted
                            )
                        RuntimeLocalizedText("兼容 ZENCHE BLE Remote 服务；遥控器发出快门通知后，将触发当前已连接相机。")
                            .font(.system(size: TypeScale.caption))
                            .foregroundStyle(SettingsPalette.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { bluetoothRemote.enabled },
                        set: { bluetoothRemote.setEnabled($0) }
                    ))
                    .labelsHidden()
                    .toggleStyle(.switch)
                }

                Divider()

                HStack(alignment: .top, spacing: SpaceToken.s12) {
                    VStack(alignment: .leading, spacing: SpaceToken.s4) {
                        RuntimeLocalizedText("live 图拍摄")
                            .font(.system(size: TypeScale.emphasis, weight: .semibold))
                        RuntimeLocalizedText(
                            livePhotoEnabled
                                ? "已开启 · 快门附带最近 \(Int(livePhotoSeconds)) 秒取景切片"
                                : "已关闭 · 快门仅保存照片"
                        )
                            .font(.system(size: TypeScale.body))
                            .foregroundStyle(SettingsPalette.muted)
                        RuntimeLocalizedText("取景开启时环形缓存取景帧；快门触发后以照片同文件名保存最近 N 秒切片（AVI），XMP 写入配对标记。")
                            .font(.system(size: TypeScale.caption))
                            .foregroundStyle(SettingsPalette.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                    Toggle("", isOn: $livePhotoEnabled)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }

                if livePhotoEnabled {
                    HStack(alignment: .top, spacing: SpaceToken.s12) {
                        VStack(alignment: .leading, spacing: SpaceToken.s4) {
                            RuntimeLocalizedText("切片时长")
                                .font(.system(size: TypeScale.emphasis, weight: .semibold))
                            RuntimeLocalizedText("快门前的取景秒数（1–15 秒）")
                                .font(.system(size: TypeScale.caption))
                                .foregroundStyle(SettingsPalette.muted)
                        }
                        Spacer()
                        Picker("", selection: $livePhotoSeconds) {
                            ForEach([1.0, 3.0, 5.0, 10.0, 15.0], id: \.self) { seconds in
                                Text("\(Int(seconds)) 秒").tag(seconds)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.segmented)
                        .fixedSize()
                    }
                }

                Divider()

                HStack(alignment: .top, spacing: SpaceToken.s12) {
                    VStack(alignment: .leading, spacing: SpaceToken.s4) {
                        RuntimeLocalizedText("拍摄位置")
                            .font(.system(size: TypeScale.emphasis, weight: .semibold))
                        RuntimeLocalizedText(locationTagging.status)
                            .font(.system(size: TypeScale.body))
                            .foregroundStyle(SettingsPalette.muted)
                        RuntimeLocalizedText("仅在应用使用期间定位；下载的照片会生成包含 GPS 信息的标准 XMP 旁车文件。")
                            .font(.system(size: TypeScale.caption))
                            .foregroundStyle(SettingsPalette.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { locationTagging.enabled },
                        set: { locationTagging.setEnabled($0) }
                    ))
                    .labelsHidden()
                    .toggleStyle(.switch)
                }
            }

            settingsCard {
                HStack(alignment: .top, spacing: SpaceToken.s12) {
                    settingIcon("arrow.triangle.2.circlepath", color: SettingsPalette.cobalt)
                    VStack(alignment: .leading, spacing: SpaceToken.s4) {
                        Text("自动更新")
                            .font(.system(size: TypeScale.title, weight: .bold))
                        Text("启动时优先通过 Mirror酱检查更新，无可用 CDN 下载地址时自动回退 GitHub Releases。")
                            .font(.system(size: TypeScale.body))
                            .foregroundStyle(SettingsPalette.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                    Toggle(
                        "",
                        isOn: $updater.automaticallyChecksForUpdates
                    )
                    .labelsHidden()
                    .toggleStyle(.switch)
                }

                Divider()

                HStack(spacing: SpaceToken.s12) {
                    SecureField(
                        "Mirror酱 CDK（可选）",
                        text: $updater.mirrorChyanCDK
                    )
                    .textFieldStyle(.roundedBorder)
                    Text("CDK 保存在系统钥匙串中，不会写入诊断日志。")
                        .font(.system(size: TypeScale.caption))
                        .foregroundStyle(SettingsPalette.muted)
                    Spacer()
                    actionButton("打开 Mirror酱") {
                        updater.openMirrorChyan()
                    }
                }

                Divider()

                HStack(spacing: SpaceToken.s12) {
                    VStack(alignment: .leading, spacing: SpaceToken.s4) {
                        RuntimeLocalizedText(updater.statusText)
                            .font(.system(size: TypeScale.body, weight: .semibold))
                        HStack(spacing: SpaceToken.s4) {
                            Text("当前版本")
                            Text(updater.currentVersion)
                        }
                            .font(.system(size: TypeScale.body))
                            .foregroundStyle(SettingsPalette.muted)
                    }
                    Spacer()
                    if updater.isChecking || updater.isDownloading {
                        ProgressView()
                            .controlSize(.small)
                    }
                    if updater.downloadedInstaller != nil {
                        actionButton("打开安装包", primary: true) {
                            updater.openDownloadedInstaller()
                        }
                    } else if updater.availableUpdate != nil {
                        actionButton("下载更新", primary: true) {
                            updater.downloadUpdate()
                        }
                    } else {
                        actionButton("检查更新") {
                            updater.checkForUpdates()
                        }
                        .disabled(updater.isChecking)
                    }
                }
            }

            settingsCard {
                HStack(alignment: .top, spacing: SpaceToken.s12) {
                    settingIcon(
                        "doc.text.magnifyingglass",
                        color: SettingsPalette.cobalt
                    )
                    VStack(alignment: .leading, spacing: SpaceToken.s4) {
                        Text("诊断日志")
                            .font(.system(size: TypeScale.title, weight: .bold))
                        Text("记录相机连接、USB/PTP 命令、实时取景重试及错误详情，默认保留 14 天。")
                            .font(.system(size: TypeScale.body))
                            .foregroundStyle(SettingsPalette.muted)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("~/Library/Logs/帧澈 ZENCHE")
                            .font(.system(size: TypeScale.caption, design: .monospaced))
                            .foregroundStyle(SettingsPalette.muted)
                    }
                    Spacer()
                }

                Divider()

                VStack(alignment: .leading, spacing: SpaceToken.s8) {
                    Text("导出和提交前会自动隐藏相机序列号和用户名路径；在 GitHub 确认后才会提交。")
                        .font(.system(size: TypeScale.body))
                        .foregroundStyle(SettingsPalette.muted)
                    HStack(spacing: SpaceToken.s8) {
                        Spacer()
                        actionButton("查询日志") {
                            showLogViewer = true
                        }
                        actionButton("打开日志目录") {
                            openLogDirectory()
                        }
                        actionButton("导出诊断包") {
                            exportDiagnostics()
                        }
                        actionButton("上传脱敏日志", primary: true) {
                            openGithubIssue()
                        }
                    }
                    fastFeedbackCallout
                }
            }

            settingsCard {
                HStack(alignment: .top, spacing: SpaceToken.s12) {
                    settingIcon("key.fill", color: SettingsPalette.cobalt)
                    VStack(alignment: .leading, spacing: SpaceToken.s4) {
                        Text("AI 功能激活").font(.system(size: TypeScale.title, weight: .bold))
                        Text("AI 修图与生图功能需购买激活码解锁。每个激活码可使用 100 次，绑定当前设备。")
                            .font(.system(size: TypeScale.body)).foregroundStyle(SettingsPalette.muted).fixedSize(horizontal: false, vertical: true)
                        if ActivationManager.isActivated {
                            Text("状态：已激活 ✓ · 剩余 \(ActivationManager.remainingUsage) 次")
                                .font(.system(size: TypeScale.body, weight: .semibold)).foregroundStyle(Color.green)
                        }
                    }
                    Spacer()
                }
                Divider()
                VStack(alignment: .leading, spacing: SpaceToken.s8) {
                    Button {
                        NSWorkspace.shared.open(zencheWebsiteURL)
                    } label: {
                        Label("前往官网兑换密钥", systemImage: "globe")
                            .font(.system(size: TypeScale.body, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 38)
                    }
                    .buttonStyle(.borderedProminent)

                    Text("复制设备 ID 后，前往 zenche.top 使用兑换码兑换绑定当前设备的激活密钥。")
                        .font(.system(size: TypeScale.caption))
                        .foregroundStyle(SettingsPalette.muted)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("没有兑换码？在爱发电购买兑换码")
                        .font(.system(size: TypeScale.body, weight: .semibold))

                    if let url = Bundle.main.url(
                        forResource: "wechat-donation",
                        withExtension: "png"
                    ), let image = NSImage(contentsOf: url) {
                        Button {
                            NSWorkspace.shared.open(afdianURL)
                        } label: {
                            Image(nsImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 280)
                                .clipShape(RoundedRectangle(cornerRadius: RadiusToken.r8))
                                .overlay {
                                    RoundedRectangle(cornerRadius: RadiusToken.r8)
                                        .stroke(SettingsPalette.rule, lineWidth: 1)
                                }
                        }
                        .buttonStyle(.plain)
                        .frame(maxWidth: .infinity)
                        .accessibilityLabel("在爱发电购买兑换码")
                    }

                    actionButton("在爱发电购买兑换码") {
                        NSWorkspace.shared.open(afdianURL)
                    }

                    Text("兑换码仅用于 AI 云服务次数，帧澈本体保持免费开源。")
                        .font(.system(size: TypeScale.caption))
                        .foregroundStyle(SettingsPalette.muted)
                }
                Divider()
                VStack(alignment: .leading, spacing: SpaceToken.s8) {
                    HStack(spacing: SpaceToken.s8) {
                        Text("我的设备 ID").font(.system(size: TypeScale.body, weight: .semibold))
                        Spacer()
                        Button("复制") {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(ActivationManager.deviceId, forType: .string)
                            activationStatus = "设备 ID 已复制，可前往官网兑换密钥"
                        }
                        .buttonStyle(.plain)
                        .font(.system(size: TypeScale.caption, weight: .semibold))
                        .foregroundStyle(SettingsPalette.cobalt)
                    }
                    Text(ActivationManager.deviceId)
                        .font(.system(size: TypeScale.caption, design: .monospaced))
                        .foregroundStyle(SettingsPalette.muted)
                        .textSelection(.enabled)
                    Text("每个激活密钥绑定当前设备，请复制上面的设备 ID 并前往官网兑换。")
                        .font(.system(size: TypeScale.caption))
                        .foregroundStyle(SettingsPalette.muted)
                }
                Divider()
                VStack(alignment: .leading, spacing: SpaceToken.s8) {
                    Text("激活码").font(.system(size: TypeScale.body, weight: .semibold))
                    TextField("输入激活码", text: $activationCode).textFieldStyle(.roundedBorder)
                }
                HStack(spacing: SpaceToken.s8) {
                    Spacer()
                    if !activationStatus.isEmpty { Text(activationStatus).font(.system(size: TypeScale.caption)).foregroundStyle(SettingsPalette.muted) }
                    actionButton("购买激活码") { NSWorkspace.shared.open(URL(string: "https://www.ifdian.net/a/Tauber")!) }
                    actionButton("激活", primary: true) {
                        let c = activationCode.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !c.isEmpty else { activationStatus = "请输入激活码"; return }
                        activationStatus = ActivationManager.verifyAndActivate(code: c) ? "激活成功！AI 功能已解锁" : "激活码无效或已过期"
                        if activationStatus.hasPrefix("激活成功") { activationCode = "" }
                    }
                }
                Divider()
                VStack(alignment: .leading, spacing: SpaceToken.s8) {
                    Text("恢复设备码")
                        .font(.system(size: TypeScale.body, weight: .semibold))
                    TextField("旧设备 ID", text: $oldDeviceId)
                        .textFieldStyle(.roundedBorder)
                    SecureField("旧激活码", text: $oldActivationCode)
                        .textFieldStyle(.roundedBorder)
                    Text("恢复成功后，AI 权益和剩余次数将迁移到当前设备；旧设备绑定会永久失效。")
                        .font(.system(size: TypeScale.caption))
                        .foregroundStyle(SettingsPalette.muted)
                        .fixedSize(horizontal: false, vertical: true)
                    actionButton(
                        isRebindingActivation ? "正在迁移…" : "恢复到当前设备",
                        primary: false
                    ) {
                        Task { await restoreDeviceBinding() }
                    }
                    .disabled(isRebindingActivation)
                }
            }

            settingsCard {
                HStack(spacing: SpaceToken.s12) {
                    settingIcon(
                        "cup.and.saucer.fill",
                        color: SettingsPalette.support,
                        soft: SettingsPalette.supportSoft
                    )
                    VStack(alignment: .leading, spacing: SpaceToken.s4) {
                        Text("喜欢 帧澈 ZENCHE？")
                            .font(.system(size: TypeScale.title, weight: .bold))
                        Text("请作者喝杯奶茶，支持后续维护与新机型适配。")
                            .font(.system(size: TypeScale.body))
                            .foregroundStyle(SettingsPalette.muted)
                    }
                    Spacer()
                    Button {
                        showDonation = true
                    } label: {
                        Label("请作者喝奶茶", systemImage: "heart.fill")
                            .font(.system(size: TypeScale.body, weight: .bold))
                            .foregroundStyle(Color.white)
                            .padding(.horizontal, SpaceToken.s16)
                            .frame(height: 38)
                            .background(SettingsPalette.support)
                            .clipShape(RoundedRectangle(cornerRadius: RadiusToken.r8))
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack {
                Button("查看项目主页") {
                    updater.openReleasePage()
                }
                .buttonStyle(.link)
                Spacer()
                Text("更新包仅从 github.com/Tauber01/ZENCHE 获取")
                    .font(.system(size: TypeScale.caption))
                    .foregroundStyle(SettingsPalette.muted)
            }
            }
            .padding(SpaceToken.s24)
        }
        .frame(width: 620)
        .sheet(isPresented: $showDonation) {
            DonationSheet()
        }
        .sheet(isPresented: $showLogViewer) {
            DiagnosticLogViewer()
        }
        .alert(
            "诊断日志",
            isPresented: Binding(
                get: { logExportMessage != nil },
                set: { if !$0 { logExportMessage = nil } }
            )
        ) {
            Button("好") { logExportMessage = nil }
        } message: {
            RuntimeLocalizedText(logExportMessage ?? "")
        }
    }

    @MainActor
    private func restoreDeviceBinding() async {
        let locale = Locale(identifier: languageRaw)
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

    private func themeButton(_ mode: ThemeMode) -> some View {
        let selected = mode.rawValue == themeRaw
        return Button {
            themeRaw = mode.rawValue
        } label: {
            RuntimeLocalizedText(mode.displayName)
                .font(.system(size: TypeScale.body, weight: selected ? .bold : .medium))
                .foregroundStyle(
                    selected ? SettingsPalette.cobalt : SettingsPalette.muted
                )
                .padding(.horizontal, SpaceToken.s12)
                .frame(height: 30)
                .background(selected ? SettingsPalette.cobaltSoft : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: RadiusToken.r7))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(mode.displayName))
    }

    private func settingsCard<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: SpaceToken.s16) {
            content()
        }
        .padding(SpaceToken.s16)
        .background(SettingsPalette.card)
        .clipShape(RoundedRectangle(cornerRadius: RadiusToken.r14))
        .overlay {
            RoundedRectangle(cornerRadius: RadiusToken.r14)
                .stroke(SettingsPalette.rule, lineWidth: 1)
        }
    }

    private func settingIcon(
        _ name: String,
        color: Color,
        soft: Color = SettingsPalette.cobaltSoft
    ) -> some View {
        Image(systemName: name)
            .font(.system(size: 19, weight: .semibold)) // 图标尺寸，不受 TypeScale 约束
            .foregroundStyle(color)
            .frame(width: 42, height: 42)
            .background(soft)
            .clipShape(RoundedRectangle(cornerRadius: RadiusToken.r10))
    }

    private func actionButton(
        _ title: String,
        primary: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(LocalizedStringKey(title), action: action)
            .font(.system(size: TypeScale.body, weight: .semibold))
            .foregroundStyle(primary ? Color.white : SettingsPalette.ink)
            .padding(.horizontal, SpaceToken.s12)
            .frame(height: 36)
            .background(primary ? SettingsPalette.cobalt : SettingsPalette.card)
            .clipShape(RoundedRectangle(cornerRadius: RadiusToken.r8))
            .overlay {
                RoundedRectangle(cornerRadius: RadiusToken.r8)
                    .stroke(primary ? Color.clear : SettingsPalette.rule, lineWidth: 1)
            }
            .buttonStyle(.plain)
    }

    private var fastFeedbackCallout: some View {
        FastFeedbackCallout {
            NSWorkspace.shared.open(afdianURL)
        }
    }

    private func openLogDirectory() {
        DiagnosticLogger.shared.info("diagnostics", "用户打开日志目录")
        NSWorkspace.shared.open(DiagnosticLogger.shared.directoryURL)
    }

    private func exportDiagnostics() {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"

        let panel = NSSavePanel()
        panel.title = "导出 帧澈 ZENCHE 诊断日志"
        panel.nameFieldStringValue =
            "ZENCHE-Diagnostics-\(formatter.string(from: Date())).zip"
        panel.allowedContentTypes = [.zip]
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let destination = panel.url else {
            return
        }

        do {
            try DiagnosticLogger.shared.exportArchive(to: destination)
            NSWorkspace.shared.activateFileViewerSelecting([destination])
        } catch {
            DiagnosticLogger.shared.error(
                "diagnostics",
                "导出诊断日志失败：\(error.localizedDescription)"
            )
            logExportMessage = error.localizedDescription
        }
    }

    private func openGithubIssue() {
        DiagnosticLogger.shared.info(
            "diagnostics",
            "用户打开 GitHub Issue 提交页"
        )
        guard let url = DiagnosticLogger.shared.githubIssueURL() else {
            logExportMessage = "无法生成 GitHub Issue 地址。"
            return
        }
        NSWorkspace.shared.open(url)
    }
}

private struct DiagnosticLogViewer: View {
    @Environment(\.dismiss) private var dismiss
    @State private var logText = DiagnosticLogger.shared.recentText(
        maxCharacters: 12_000
    )

    var body: some View {
        VStack(alignment: .leading, spacing: SpaceToken.s12) {
            HStack {
                VStack(alignment: .leading, spacing: SpaceToken.s4) {
                    Text("诊断日志查询")
                        .font(.system(size: TypeScale.title, weight: .bold))
                    Text("显示近期脱敏日志；刷新可读取最新记录。")
                        .foregroundStyle(SettingsPalette.muted)
                }
                Spacer()
                Button("刷新") {
                    logText = DiagnosticLogger.shared.recentText(
                        maxCharacters: 12_000
                    )
                }
                Button("关闭") { dismiss() }
            }

            ScrollView([.horizontal, .vertical]) {
                Text(logText)
                    .font(.system(size: TypeScale.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .padding(SpaceToken.s12)
            }
            .background(Color.primary.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: RadiusToken.r10))
        }
        .padding(SpaceToken.s20)
        .frame(width: 760, height: 520)
    }
}

private struct FastFeedbackCallout: View {
    let openAfdian: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: SpaceToken.s12) {
            Image(systemName: "bolt.horizontal.circle.fill")
                .font(.system(size: 22, weight: .semibold)) // 图标尺寸，不受 TypeScale 约束
                .foregroundStyle(SettingsPalette.cobalt)
                .frame(width: 42, height: 42)
                .background(SettingsPalette.cobaltSoft)
                .clipShape(RoundedRectangle(cornerRadius: RadiusToken.r11))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: SpaceToken.s4) {
                Text("快速问题反馈")
                    .font(.system(size: TypeScale.emphasis, weight: .bold))
                Text("公开问题可继续在 GitHub 免费提交；在爱发电赞助后，可获取快速问题反馈渠道。")
                    .font(.system(size: TypeScale.body))
                    .foregroundStyle(SettingsPalette.muted)
                    .fixedSize(horizontal: false, vertical: true)
                Text("官方 QQ 群：165315727")
                    .font(.system(size: TypeScale.body, weight: .bold, design: .monospaced))
                    .foregroundStyle(SettingsPalette.cobalt)
                    .textSelection(.enabled)
            }
            Spacer(minLength: 12)
            Button("打开爱发电", action: openAfdian)
                .buttonStyle(.bordered)
        }
        .padding(SpaceToken.s12)
        .background(SettingsPalette.cobaltSoft.opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: RadiusToken.r12))
        .overlay {
            RoundedRectangle(cornerRadius: RadiusToken.r12)
                .stroke(SettingsPalette.cobalt.opacity(0.16))
        }
    }
}

private struct DonationSheet: View {
    @Environment(\.dismiss) private var dismiss
    private let donationImage: NSImage? = {
        guard let url = Bundle.main.url(
            forResource: "wechat-donation",
            withExtension: "png"
        ) else {
            return nil
        }
        return NSImage(contentsOf: url)
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: SpaceToken.s16) {
            HStack {
                HStack(spacing: SpaceToken.s12) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 20, weight: .bold)) // 图标尺寸，不受 TypeScale 约束
                        .foregroundStyle(SettingsPalette.cobalt)
                        .frame(width: 44, height: 44)
                        .background(SettingsPalette.cobaltSoft)
                        .clipShape(RoundedRectangle(cornerRadius: RadiusToken.r12))
                    VStack(alignment: .leading, spacing: SpaceToken.s4) {
                        Text("爱发电赞助")
                            .font(.system(size: TypeScale.display, weight: .bold))
                        Text("扫描二维码，或打开爱发电主页支持项目。")
                            .foregroundStyle(SettingsPalette.muted)
                    }
                }
                Spacer()
                Button("关闭") { dismiss() }
                    .buttonStyle(.plain)
            }

            FastFeedbackCallout {
                NSWorkspace.shared.open(afdianURL)
            }

            if let donationImage {
                Image(nsImage: donationImage)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: RadiusToken.r14))
                    .overlay {
                        RoundedRectangle(cornerRadius: RadiusToken.r14)
                            .stroke(SettingsPalette.rule, lineWidth: 1)
                    }
            } else {
                ContentUnavailableView(
                    "二维码未找到",
                    systemImage: "qrcode",
                    description: Text("请重新安装 帧澈 ZENCHE 后再试。")
                )
                .frame(height: 420)
            }

            Text("赞助不会解锁软件功能，也不影响公开 Issue 的处理。")
                .font(.system(size: TypeScale.caption))
                .foregroundStyle(SettingsPalette.muted)
        }
        .padding(SpaceToken.s24)
        .frame(width: 520, height: 760)
        .background(SettingsPalette.cobaltSoft.opacity(0.18))
    }
}

struct LaunchAnnouncementSheet: View {
    let version: String
    @Binding var doNotRemind: Bool
    let close: () -> Void

    private let donationImage: NSImage? = {
        guard let url = Bundle.main.url(
            forResource: "wechat-donation",
            withExtension: "png"
        ) else {
            return nil
        }
        return NSImage(contentsOf: url)
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: SpaceToken.s16) {
            HStack {
                VStack(alignment: .leading, spacing: SpaceToken.s4) {
                    Text("更新公告")
                        .font(.system(size: TypeScale.heading, weight: .bold))
                    HStack(spacing: SpaceToken.s4) {
                        Text("当前版本")
                        Text(version)
                    }
                    .font(.system(size: TypeScale.body, design: .monospaced))
                    .foregroundStyle(SettingsPalette.muted)
                }
                Spacer()
                Button("关闭公告", action: close)
                    .buttonStyle(.borderedProminent)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: SpaceToken.s16) {
                    settingsSection(
                        title: "本次更新",
                        icon: "sparkles.rectangle.stack.fill",
                        color: SettingsPalette.cobalt
                    ) {
                        RuntimeLocalizedText("• 新增“下载到本地”：联机拍摄、相机卡下载、AI 修图/生图与专业编辑结果都可以通过系统保存器另存到用户选择的位置。\n• 五端文件库均提供统一入口；支持应用内预览的页面也提供快捷入口。AI 与专业编辑提供直达入口；“保存到系统相册”继续作为独立操作保留。\n• 导出只创建副本，不移动或删除 ZENCHE 文件库中的源文件；macOS 与 Windows 的 AI 修图也改为始终生成新文件，不再覆盖原图。\n• 用户取消时不显示错误；只有复制完成、同步落盘且大小校验通过后才显示成功。失败时会清理临时文件，并尽力删除未完成的目标。\n• GitHub Release 提供 1.5.13 五端安装包，官网自动更新仍保持 1.5.10。各平台签名与安装边界，以及系统保存器、权限、同名文件、大文件和存储空间不足等场景，请参阅发布说明并按需真机验证。")
                            .font(.system(size: TypeScale.body))
                            .lineSpacing(5)
                    }

                    settingsSection(
                        title: "谨防诈骗",
                        icon: "exclamationmark.shield.fill",
                        color: .red
                    ) {
                        Text("帧澈 ZENCHE 是开源免费项目。任何声称“进群领取软件”或要求付费购买软件的人都是骗子，请勿转账。")
                            .font(.system(size: TypeScale.body, weight: .semibold))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .background(Color.red.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: RadiusToken.r14))

                    VStack(alignment: .leading, spacing: SpaceToken.s8) {
                        Label("爱发电赞助", systemImage: "heart.fill")
                            .font(.system(size: TypeScale.title, weight: .bold))
                            .foregroundStyle(SettingsPalette.cobalt)
                        Text("如果本项目对你有帮助，欢迎自愿打赏；软件功能永久免费。")
                            .font(.system(size: TypeScale.body))
                            .foregroundStyle(SettingsPalette.muted)
                        FastFeedbackCallout {
                            NSWorkspace.shared.open(afdianURL)
                        }
                        if let donationImage {
                            Image(nsImage: donationImage)
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: .infinity, maxHeight: 430)
                                .clipShape(RoundedRectangle(cornerRadius: RadiusToken.r14))
                        }
                    }
                    .padding(SpaceToken.s16)
                    .background(SettingsPalette.card)
                    .clipShape(RoundedRectangle(cornerRadius: RadiusToken.r14))
                    .overlay {
                        RoundedRectangle(cornerRadius: RadiusToken.r14)
                            .stroke(SettingsPalette.rule)
                    }
                }
                .padding(.trailing, SpaceToken.s4)
            }

            Toggle(
                "不再提醒（软件更新后仍会显示）",
                isOn: $doNotRemind
            )
            .toggleStyle(.checkbox)
        }
        .padding(SpaceToken.s24)
        .frame(width: 620, height: 780)
        .background(SettingsPalette.cobaltSoft.opacity(0.22))
    }

    private func settingsSection<Content: View>(
        title: LocalizedStringKey,
        icon: String,
        color: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: SpaceToken.s8) {
            Label(title, systemImage: icon)
                .font(.system(size: TypeScale.title, weight: .bold))
                .foregroundStyle(color)
            content()
        }
        .padding(SpaceToken.s16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(SettingsPalette.card)
        .clipShape(RoundedRectangle(cornerRadius: RadiusToken.r14))
        .overlay {
            RoundedRectangle(cornerRadius: RadiusToken.r14)
                .stroke(SettingsPalette.rule)
        }
    }
}
