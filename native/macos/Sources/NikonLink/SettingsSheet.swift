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

private enum SettingsPalette {
    static let ink = Color(red: 0.075, green: 0.09, blue: 0.12)
    static let muted = Color(red: 0.36, green: 0.40, blue: 0.47)
    static let cobalt = Color(red: 0.02, green: 0.35, blue: 0.82)
    static let cobaltSoft = Color(red: 0.88, green: 0.93, blue: 1.0)
    static let support = Color(red: 0.96, green: 0.48, blue: 0.33)
    static let supportSoft = Color(red: 1.0, green: 0.94, blue: 0.90)
    static let rule = Color.black.opacity(0.10)
}

private let afdianURL = URL(string: "https://www.ifdian.net/a/Tauber")!

struct SettingsSheet: View {
    @ObservedObject var updater: UpdateController
    @Binding var languageRaw: String
    @Environment(\.dismiss) private var dismiss
    @State private var showDonation = false
    @State private var showLogViewer = false
    @State private var logExportMessage: String?
    @State private var activationCode = ""
    @State private var activationStatus = ""
    @State private var serverURL = UserDefaults.standard.string(forKey: "aiServerURL") ?? "http://101.34.255.115:8787"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("设置")
                        .font(.system(size: 26, weight: .bold))
                    HStack(spacing: 4) {
                        Text("帧澈 ZENCHE")
                        Text(updater.currentVersion)
                    }
                    .foregroundStyle(SettingsPalette.muted)
                }
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: "globe")
                        .foregroundStyle(SettingsPalette.muted)
                    ForEach(InterfaceLanguage.allCases) { language in
                        Button {
                            languageRaw = language.rawValue
                        } label: {
                            Text(language.displayName)
                                .font(
                                    .system(
                                        size: 11,
                                        weight: language.rawValue == languageRaw
                                            ? .bold
                                            : .medium
                                    )
                                )
                                .padding(.horizontal, 7)
                                .frame(height: 28)
                                .background(
                                    language.rawValue == languageRaw
                                        ? SettingsPalette.cobaltSoft
                                        : Color.clear
                                )
                                .clipShape(
                                    RoundedRectangle(cornerRadius: 6)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .fixedSize()
                Button("完成") { dismiss() }
                    .buttonStyle(.plain)
            }

            settingsCard {
                HStack(alignment: .top, spacing: 14) {
                    settingIcon("arrow.triangle.2.circlepath", color: SettingsPalette.cobalt)
                    VStack(alignment: .leading, spacing: 5) {
                        Text("自动更新")
                            .font(.system(size: 16, weight: .bold))
                        Text("启动时优先通过 Mirror酱检查更新，无可用 CDN 下载地址时自动回退 GitHub Releases。")
                            .font(.system(size: 13))
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

                HStack(spacing: 12) {
                    SecureField(
                        "Mirror酱 CDK（可选）",
                        text: $updater.mirrorChyanCDK
                    )
                    .textFieldStyle(.roundedBorder)
                    Text("CDK 保存在系统钥匙串中，不会写入诊断日志。")
                        .font(.system(size: 11))
                        .foregroundStyle(SettingsPalette.muted)
                    Spacer()
                    actionButton("打开 Mirror酱") {
                        updater.openMirrorChyan()
                    }
                }

                Divider()

                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        RuntimeLocalizedText(updater.statusText)
                            .font(.system(size: 13, weight: .semibold))
                        HStack(spacing: 4) {
                            Text("当前版本")
                            Text(updater.currentVersion)
                        }
                            .font(.system(size: 12))
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
                HStack(alignment: .top, spacing: 14) {
                    settingIcon(
                        "doc.text.magnifyingglass",
                        color: SettingsPalette.cobalt
                    )
                    VStack(alignment: .leading, spacing: 5) {
                        Text("诊断日志")
                            .font(.system(size: 16, weight: .bold))
                        Text("记录相机连接、USB/PTP 命令、实时取景重试及错误详情，默认保留 14 天。")
                            .font(.system(size: 13))
                            .foregroundStyle(SettingsPalette.muted)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("~/Library/Logs/帧澈 ZENCHE")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(SettingsPalette.muted)
                    }
                    Spacer()
                }

                Divider()

                VStack(alignment: .leading, spacing: 10) {
                    Text("导出和提交前会自动隐藏相机序列号和用户名路径；在 GitHub 确认后才会提交。")
                        .font(.system(size: 12))
                        .foregroundStyle(SettingsPalette.muted)
                    HStack(spacing: 10) {
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
                HStack(alignment: .top, spacing: 14) {
                    settingIcon("key.fill", color: SettingsPalette.cobalt)
                    VStack(alignment: .leading, spacing: 5) {
                        Text("AI 功能激活").font(.system(size: 16, weight: .bold))
                        Text("AI 修图与生图功能需购买激活码解锁。每个激活码可使用 100 次，绑定当前设备。")
                            .font(.system(size: 13)).foregroundStyle(SettingsPalette.muted).fixedSize(horizontal: false, vertical: true)
                        if ActivationManager.isActivated {
                            Text("状态：已激活 ✓ · 剩余 \(ActivationManager.remainingUsage) 次")
                                .font(.system(size: 12, weight: .semibold)).foregroundStyle(Color.green)
                        }
                    }
                    Spacer()
                }
                Divider()
                VStack(alignment: .leading, spacing: 8) {
                    Text("激活码").font(.system(size: 12, weight: .semibold))
                    TextField("输入激活码", text: $activationCode).textFieldStyle(.roundedBorder)
                    Text("AI 服务器").font(.system(size: 12, weight: .semibold))
                    TextField("服务器地址（如 http://101.34.255.115:8787）", text: $serverURL).textFieldStyle(.roundedBorder)
                }
                HStack(spacing: 10) {
                    Spacer()
                    if !activationStatus.isEmpty { Text(activationStatus).font(.system(size: 11)).foregroundStyle(SettingsPalette.muted) }
                    actionButton("购买激活码") { NSWorkspace.shared.open(URL(string: "https://www.ifdian.net/a/Tauber")!) }
                    actionButton("激活", primary: true) {
                        let c = activationCode.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !c.isEmpty else { activationStatus = "请输入激活码"; return }
                        UserDefaults.standard.set(serverURL.trimmingCharacters(in: .whitespacesAndNewlines), forKey: "aiServerURL")
                        activationStatus = ActivationManager.verifyAndActivate(code: c) ? "激活成功！AI 功能已解锁" : "激活码无效或已过期"
                        if activationStatus.hasPrefix("激活成功") { activationCode = "" }
                    }
                }
            }

            settingsCard {
                HStack(spacing: 14) {
                    settingIcon("cup.and.saucer.fill", color: SettingsPalette.support)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("喜欢 帧澈 ZENCHE？")
                            .font(.system(size: 16, weight: .bold))
                        Text("请作者喝杯奶茶，支持后续维护与新机型适配。")
                            .font(.system(size: 13))
                            .foregroundStyle(SettingsPalette.muted)
                    }
                    Spacer()
                    Button {
                        showDonation = true
                    } label: {
                        Label("请作者喝奶茶", systemImage: "heart.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Color.white)
                            .padding(.horizontal, 16)
                            .frame(height: 38)
                            .background(SettingsPalette.support)
                            .clipShape(RoundedRectangle(cornerRadius: 9))
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
                    .font(.system(size: 11))
                    .foregroundStyle(SettingsPalette.muted)
            }
            }
            .padding(26)
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

    private func settingsCard<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            content()
        }
        .padding(18)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .stroke(SettingsPalette.rule, lineWidth: 1)
        }
    }

    private func settingIcon(_ name: String, color: Color) -> some View {
        Image(systemName: name)
            .font(.system(size: 19, weight: .semibold))
            .foregroundStyle(color)
            .frame(width: 42, height: 42)
            .background(
                color == SettingsPalette.support
                    ? SettingsPalette.supportSoft
                    : SettingsPalette.cobaltSoft
            )
            .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func actionButton(
        _ title: String,
        primary: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(LocalizedStringKey(title), action: action)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(primary ? Color.white : SettingsPalette.ink)
            .padding(.horizontal, 14)
            .frame(height: 36)
            .background(primary ? SettingsPalette.cobalt : Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
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
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("诊断日志查询")
                        .font(.system(size: 23, weight: .bold))
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
                    .font(.system(size: 11, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .padding(14)
            }
            .background(Color.black.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .padding(22)
        .frame(width: 760, height: 520)
    }
}

private struct FastFeedbackCallout: View {
    let openAfdian: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            Image(systemName: "bolt.horizontal.circle.fill")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(SettingsPalette.cobalt)
                .frame(width: 42, height: 42)
                .background(SettingsPalette.cobaltSoft)
                .clipShape(RoundedRectangle(cornerRadius: 11))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text("快速问题反馈")
                    .font(.system(size: 14, weight: .bold))
                Text("公开问题可继续在 GitHub 免费提交；在爱发电赞助后，可获取快速问题反馈渠道。")
                    .font(.system(size: 12))
                    .foregroundStyle(SettingsPalette.muted)
                    .fixedSize(horizontal: false, vertical: true)
                Text("官方 QQ 群：165315727")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(SettingsPalette.cobalt)
                    .textSelection(.enabled)
            }
            Spacer(minLength: 12)
            Button("打开爱发电", action: openAfdian)
                .buttonStyle(.bordered)
        }
        .padding(14)
        .background(SettingsPalette.cobaltSoft.opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
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
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                HStack(spacing: 12) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(SettingsPalette.cobalt)
                        .frame(width: 44, height: 44)
                        .background(SettingsPalette.cobaltSoft)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    VStack(alignment: .leading, spacing: 3) {
                        Text("爱发电赞助")
                            .font(.system(size: 24, weight: .bold))
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
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14)
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
                .font(.system(size: 11))
                .foregroundStyle(SettingsPalette.muted)
        }
        .padding(24)
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
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("更新公告")
                        .font(.system(size: 26, weight: .bold))
                    HStack(spacing: 4) {
                        Text("当前版本")
                        Text(version)
                    }
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(SettingsPalette.muted)
                }
                Spacer()
                Button("关闭公告", action: close)
                    .buttonStyle(.borderedProminent)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    settingsSection(
                        title: "本次更新",
                        icon: "sparkles.rectangle.stack.fill",
                        color: SettingsPalette.cobalt
                    ) {
                        Text("• 新增 AI 修图与生图工具，内置一键美颜等快捷预设，激活码解锁后即可使用。\n• 新增树状分支文件库，支持嵌套分支、拖拽归类与持久化组织。\n• 新增专业非破坏性修图工具，提供光影 / 色彩 / 细节 / 效果 / 几何五组参数与透明预设。\n• 新增可展开的全屏二级相机参数面板，移动端保持紧凑触控区域。\n• USB/PTP 连接可靠性大幅提升：瞬时错误自动重试、HONOR 设备同步降级传输。\n• 新增对 Nikon D500、D7500、D850（EXPEED 5）的 USB/PTP 控制支持。\n• 视频录制监看延迟优化：子采样解码、管道重叠取帧、智能跳帧分析。")
                            .font(.system(size: 14))
                            .lineSpacing(5)
                    }

                    settingsSection(
                        title: "谨防诈骗",
                        icon: "exclamationmark.shield.fill",
                        color: .red
                    ) {
                        Text("帧澈 ZENCHE 是开源免费项目。任何声称“进群领取软件”或要求付费购买软件的人都是骗子，请勿转账。")
                            .font(.system(size: 14, weight: .semibold))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .background(Color.red.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 14))

                    VStack(alignment: .leading, spacing: 10) {
                        Label("爱发电赞助", systemImage: "heart.fill")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(SettingsPalette.cobalt)
                        Text("如果本项目对你有帮助，欢迎自愿打赏；软件功能永久免费。")
                            .font(.system(size: 13))
                            .foregroundStyle(SettingsPalette.muted)
                        FastFeedbackCallout {
                            NSWorkspace.shared.open(afdianURL)
                        }
                        if let donationImage {
                            Image(nsImage: donationImage)
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: .infinity, maxHeight: 430)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                    }
                    .padding(18)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(SettingsPalette.rule)
                    }
                }
                .padding(.trailing, 4)
            }

            Toggle(
                "不再提醒（软件更新后仍会显示）",
                isOn: $doNotRemind
            )
            .toggleStyle(.checkbox)
        }
        .padding(24)
        .frame(width: 620, height: 780)
        .background(SettingsPalette.cobaltSoft.opacity(0.22))
    }

    private func settingsSection<Content: View>(
        title: LocalizedStringKey,
        icon: String,
        color: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: icon)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(color)
            content()
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .stroke(SettingsPalette.rule)
        }
    }
}
