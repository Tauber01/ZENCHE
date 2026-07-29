import AppKit
import SwiftUI
import UniformTypeIdentifiers

private enum SettingsPalette {
    static let ink = Color(red: 0.075, green: 0.09, blue: 0.12)
    static let muted = Color(red: 0.36, green: 0.40, blue: 0.47)
    static let cobalt = Color(red: 0.02, green: 0.35, blue: 0.82)
    static let cobaltSoft = Color(red: 0.88, green: 0.93, blue: 1.0)
    static let support = Color(red: 0.96, green: 0.48, blue: 0.33)
    static let supportSoft = Color(red: 1.0, green: 0.94, blue: 0.90)
    static let rule = Color.black.opacity(0.10)
}

struct SettingsSheet: View {
    @ObservedObject var updater: UpdateController
    @Environment(\.dismiss) private var dismiss
    @State private var showDonation = false
    @State private var showLogViewer = false
    @State private var logExportMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("设置")
                        .font(.system(size: 26, weight: .bold))
                    Text("帧澈 ZENCHE \(updater.currentVersion)")
                        .foregroundStyle(SettingsPalette.muted)
                }
                Spacer()
                Button("完成") { dismiss() }
                    .buttonStyle(.plain)
            }

            settingsCard {
                HStack(alignment: .top, spacing: 14) {
                    settingIcon("arrow.triangle.2.circlepath", color: SettingsPalette.cobalt)
                    VStack(alignment: .leading, spacing: 5) {
                        Text("自动更新")
                            .font(.system(size: 16, weight: .bold))
                        Text("启动时自动检查 GitHub Releases，有新版本时可直接下载安装包。")
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
                    VStack(alignment: .leading, spacing: 3) {
                        Text(updater.statusText)
                            .font(.system(size: 13, weight: .semibold))
                        Text("当前版本 \(updater.currentVersion)")
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
            Text(logExportMessage ?? "")
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
        Button(title, action: action)
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
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("请作者喝奶茶")
                        .font(.system(size: 24, weight: .bold))
                    Text("打开微信扫一扫，感谢支持。")
                        .foregroundStyle(SettingsPalette.muted)
                }
                Spacer()
                Button("关闭") { dismiss() }
                    .buttonStyle(.plain)
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
        }
        .padding(24)
        .frame(width: 500, height: 700)
    }
}
