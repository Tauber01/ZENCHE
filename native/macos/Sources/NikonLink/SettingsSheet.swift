import AppKit
import SwiftUI

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

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("设置")
                        .font(.system(size: 26, weight: .bold))
                    Text("Nikon Link \(updater.currentVersion)")
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
                HStack(spacing: 14) {
                    settingIcon("cup.and.saucer.fill", color: SettingsPalette.support)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("喜欢 Nikon Link？")
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
                Text("更新包仅从 github.com/Tauber01/NikonLink 获取")
                    .font(.system(size: 11))
                    .foregroundStyle(SettingsPalette.muted)
            }
        }
        .padding(26)
        .frame(width: 620)
        .sheet(isPresented: $showDonation) {
            DonationSheet()
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
                    description: Text("请重新安装 Nikon Link 后再试。")
                )
                .frame(height: 420)
            }
        }
        .padding(24)
        .frame(width: 500, height: 700)
    }
}
