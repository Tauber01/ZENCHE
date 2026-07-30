using System.IO;
using System.Linq;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Data;

namespace NikonLink.Windows;

internal enum InterfaceLanguage
{
    SimplifiedChinese,
    English,
    Japanese
}

internal static class AppLocalization
{
    private sealed record Translation(string English, string Japanese);

    private static readonly Dictionary<string, Translation> Strings =
        new(StringComparer.Ordinal)
        {
            ["语言更改会立即应用，并在下次启动时保留。"] =
                new(
                    "Language changes apply immediately and are remembered for the next launch.",
                    "言語の変更はすぐに適用され、次回起動時にも保持されます。"),
            ["系统“图片”与 帧澈 ZENCHE 文件库会直接合并显示；来源标注在每个文件下方。"] =
                new(
                    "System Pictures and the ZENCHE library are shown together; each file shows its source.",
                    "システムの「ピクチャ」と ZENCHE ライブラリをまとめて表示し、各ファイルに保存元を示します。"),
            ["FTP/PASV 端口 2121 · HTTP/WebDAV 端口 8080 · 用户名/密码 nikonlink · 接收完成后自动进入文件库"] =
                new(
                    "FTP/PASV port 2121 · HTTP/WebDAV port 8080 · username/password nikonlink · received files enter the library automatically",
                    "FTP/PASV ポート 2121 · HTTP/WebDAV ポート 8080 · ユーザー名/パスワード nikonlink · 受信後は自動的にライブラリへ追加"),
            ["将打开含最近脱敏日志的预填页面；在 GitHub 确认后才会提交。"] =
                new(
                    "Opens a prefilled page with recent redacted logs; nothing is submitted until you confirm on GitHub.",
                    "最近の匿名化ログを含む入力済みページを開きます。GitHub で確認するまで送信しません。"),
            ["请作者喝杯奶茶，支持维护和新机型适配。"] =
                new(
                    "Support ongoing maintenance and compatibility with more camera models.",
                    "継続的なメンテナンスと新しいカメラへの対応をご支援ください。"),
            ["爱发电赞助"] =
                new("Afdian Support", "Afdian で支援"),
            ["扫描二维码，或打开爱发电主页支持项目。"] =
                new(
                    "Scan the QR code or open the Afdian page to support the project.",
                    "QR コードを読み取るか、Afdian ページを開いてプロジェクトを支援できます。"),
            ["快速问题反馈"] =
                new(
                    "Faster Problem Feedback",
                    "より迅速な問題フィードバック"),
            ["公开问题可继续在 GitHub 免费提交；在爱发电赞助后，可获取快速问题反馈渠道。"] =
                new(
                    "Public issues remain free on GitHub. Afdian sponsors can access a faster feedback channel.",
                    "公開 Issue は引き続き GitHub から無料で送信できます。Afdian で支援すると、より迅速なフィードバック窓口を利用できます。"),
            ["官方 QQ 群：165315727"] =
                new(
                    "Official QQ group: 165315727",
                    "公式 QQ グループ：165315727"),
            ["打开爱发电"] =
                new("Open Afdian", "Afdian を開く"),
            ["赞助不会解锁软件功能，也不影响公开 Issue 的处理。"] =
                new(
                    "Sponsorship does not unlock app features or affect public issue handling.",
                    "支援によってアプリ機能が解除されたり、公開 Issue の対応が変わったりすることはありません。"),
            ["软件功能永久免费，赞助为自愿行为。"] =
                new(
                    "App features remain free; sponsorship is voluntary.",
                    "アプリの機能は無料のままで、ご支援は任意です。"),
            ["更新公告"] =
                new("What's New", "アップデートのお知らせ"),
            ["本次更新"] =
                new("In This Update", "今回の更新"),
            ["• 新增间隔拍摄、曝光包围、焦点包围与 B 门计时。\n" +
             "• 新增项目会话、命名模板、RAW + JPEG 配对、双目标备份与 SHA-256。\n" +
             "• 新增 RGB 直方图、波形、矢量示波器、峰值对焦与假色。"] =
                new(
                    "• Added interval capture, exposure bracketing, focus bracketing, and timed Bulb.\n" +
                    "• Added project sessions, naming templates, RAW + JPEG pairing, dual-destination backup, and SHA-256.\n" +
                    "• Added RGB histograms, waveform, vectorscope, focus peaking, and false color.",
                    "• インターバル撮影、露出ブラケット、フォーカスブラケット、バルブタイマーを追加しました。\n" +
                    "• プロジェクトセッション、命名テンプレート、RAW + JPEG ペアリング、二重保存、SHA-256 を追加しました。\n" +
                    "• RGB ヒストグラム、波形、ベクトルスコープ、フォーカスピーキング、フォルスカラーを追加しました。"),
            ["谨防诈骗"] =
                new("Scam Warning", "詐欺にご注意ください"),
            ["帧澈 ZENCHE 是开源免费项目。任何声称“进群领取软件”" +
             "或要求付费购买软件的人都是骗子，请勿转账。"] =
                new(
                    "ZENCHE is free and open source. Anyone claiming you must join " +
                    "a group to receive the software or pay to buy it is a scammer. " +
                    "Do not send money.",
                    "ZENCHE は無料のオープンソースプロジェクトです。" +
                    "「グループ参加でソフトを受け取れる」と案内したり、" +
                    "購入代金を要求したりする相手は詐欺です。送金しないでください。"),
            ["自愿赞助"] =
                new("Optional Support", "任意のご支援"),
            ["如果本项目对你有帮助，欢迎自愿打赏；软件功能永久免费。"] =
                new(
                    "If the project helps you, optional tips are welcome; " +
                    "the software remains free.",
                    "このプロジェクトが役立った場合は任意でご支援いただけます。" +
                    "ソフトウェアは今後も無料です。"),
            ["不再提醒（软件更新后仍会显示）"] =
                new(
                    "Don't remind me again (shown after software updates)",
                    "今後は表示しない（ソフトウェア更新後は再表示）"),
            ["关闭公告"] =
                new("Close", "閉じる"),
            ["语言"] = new("Language", "言語"),
            ["界面语言"] = new("Interface Language", "表示言語"),
            ["设置"] = new("Settings", "設定"),
            ["照片拍摄"] = new("Photo Capture", "写真撮影"),
            ["视频监看"] = new("Video Monitor", "動画モニター"),
            ["文件与传输"] = new("Files & Transfer", "ファイルと転送"),
            ["工作区"] = new("Workspace", "ワークスペース"),
            ["连接相机"] = new("Connect Camera", "カメラに接続"),
            ["未连接"] = new("Not Connected", "未接続"),
            ["等待相机画面"] = new("Waiting for camera image", "カメラ映像を待機中"),
            ["连接相机后开启实时取景"] =
                new("Connect a camera to start live view", "カメラを接続してライブビューを開始"),
            ["全屏"] = new("Full Screen", "フルスクリーン"),
            ["相机原生 JPEG · 本地预览"] =
                new("Camera JPEG · Local Preview", "カメラ JPEG · ローカルプレビュー"),
            ["开启取景"] = new("Start Live View", "ライブビュー開始"),
            ["停止取景"] = new("Stop Live View", "ライブビュー停止"),
            ["拍摄照片"] = new("Capture Photo", "写真を撮影"),
            ["开始录制"] = new("Start Recording", "録画開始"),
            ["停止录制"] = new("Stop Recording", "録画停止"),
            ["刷新相册"] = new("Refresh Library", "ライブラリを更新"),
            ["链接网盘"] = new("Connect Cloud Drive", "クラウドドライブに接続"),
            ["打开目录"] = new("Open Folder", "フォルダを開く"),
            ["多协议无线图片收件箱"] =
                new("Multi-Protocol Wireless Inbox", "マルチプロトコル・ワイヤレス受信箱"),
            ["无线收件箱未开启"] =
                new("Wireless inbox is off", "ワイヤレス受信箱は停止中"),
            ["开启无线接收"] =
                new("Start Wireless Receiver", "ワイヤレス受信を開始"),
            ["停止接收"] = new("Stop Receiving", "受信を停止"),
            ["双击文件查看大图"] =
                new("Double-click a file to preview", "ファイルをダブルクリックしてプレビュー"),
            ["分享到社交平台"] = new("Share", "共有"),
            ["删除所选"] = new("Delete Selected", "選択項目を削除"),
            ["更新、诊断与应用支持。"] =
                new("Updates, diagnostics, and support.", "アップデート、診断、サポート。"),
            ["软件更新"] = new("Software Update", "ソフトウェアアップデート"),
            ["尚未检查更新"] =
                new("Updates have not been checked", "アップデートは未確認です"),
            ["检查更新"] = new("Check for Updates", "アップデートを確認"),
            ["获取更新"] = new("Get Update", "アップデートを入手"),
            ["优先通过 Mirror酱检查更新，无可用 CDN 下载地址时自动回退 GitHub Releases"] =
                new(
                    "Check MirrorChyan first and fall back to GitHub Releases when no CDN download is available",
                    "MirrorChyan を優先して確認し、CDN ダウンロードがない場合は GitHub Releases に切り替えます"),
            ["Mirror酱 CDK（可选）"] =
                new("MirrorChyan CDK (Optional)", "MirrorChyan CDK（任意）"),
            ["CDK 使用 Windows DPAPI 加密保存，不会写入诊断日志。"] =
                new(
                    "The CDK is encrypted with Windows DPAPI and is never written to diagnostic logs.",
                    "CDK は Windows DPAPI で暗号化され、診断ログには記録されません。"),
            ["保存 CDK"] = new("Save CDK", "CDK を保存"),
            ["打开 Mirror酱"] = new("Open MirrorChyan", "MirrorChyan を開く"),
            ["Mirror酱 CDK 已清除"] =
                new("MirrorChyan CDK cleared", "MirrorChyan CDK を消去しました"),
            ["Mirror酱 CDK 已安全保存"] =
                new("MirrorChyan CDK saved securely", "MirrorChyan CDK を安全に保存しました"),
            ["Mirror酱 CDK 保存失败"] =
                new("Failed to save MirrorChyan CDK", "MirrorChyan CDK の保存に失敗しました"),
            ["Mirror酱 CDK 已过期，已回退 GitHub"] =
                new("MirrorChyan CDK expired; using GitHub", "MirrorChyan CDK の期限が切れています。GitHub を使用します"),
            ["Mirror酱 CDK 无效，已回退 GitHub"] =
                new("MirrorChyan CDK is invalid; using GitHub", "MirrorChyan CDK が無効です。GitHub を使用します"),
            ["Mirror酱今日下载额度已用完，已回退 GitHub"] =
                new("MirrorChyan daily quota is exhausted; using GitHub", "MirrorChyan の本日の上限に達しました。GitHub を使用します"),
            ["Mirror酱 CDK 与资源不匹配，已回退 GitHub"] =
                new("MirrorChyan CDK does not match this resource; using GitHub", "MirrorChyan CDK がリソースと一致しません。GitHub を使用します"),
            ["Mirror酱 CDK 已被停用，已回退 GitHub"] =
                new("MirrorChyan CDK is disabled; using GitHub", "MirrorChyan CDK は無効化されています。GitHub を使用します"),
            ["Mirror酱资源尚未配置，已回退 GitHub"] =
                new("MirrorChyan resource is not configured; using GitHub", "MirrorChyan リソースは未設定です。GitHub を使用します"),
            ["Mirror酱暂不可用，已回退 GitHub"] =
                new("MirrorChyan is unavailable; using GitHub", "MirrorChyan は利用できません。GitHub を使用します"),
            ["Mirror酱未返回可直接安装的完整包，已回退 GitHub"] =
                new("MirrorChyan did not return a full installer; using GitHub", "MirrorChyan から完全なインストーラーが返されなかったため、GitHub を使用します"),
            ["诊断日志"] = new("Diagnostic Logs", "診断ログ"),
            ["查询日志"] = new("View Logs", "ログを表示"),
            ["打开日志目录"] = new("Open Log Folder", "ログフォルダを開く"),
            ["上传脱敏日志"] =
                new("Upload Redacted Logs", "匿名化ログをアップロード"),
            ["喜欢 帧澈 ZENCHE？"] =
                new("Enjoying ZENCHE?", "ZENCHE を気に入りましたか？"),
            ["请作者喝奶茶"] = new("Support the Developer", "開発者を支援"),
            ["照片曝光与参数"] = new("Photo Exposure & Controls", "写真露出と設定"),
            ["视频曝光与参数"] = new("Video Exposure & Controls", "動画露出と設定"),
            ["拍摄模式"] = new("Shooting Mode", "撮影モード"),
            ["程序自动"] = new("Program Auto", "プログラムオート"),
            ["快门优先"] = new("Shutter Priority", "シャッター優先"),
            ["光圈优先"] = new("Aperture Priority", "絞り優先"),
            ["手动"] = new("Manual", "マニュアル"),
            ["B门"] = new("Bulb", "バルブ"),
            ["快门角度换算帧率"] =
                new("Frame Rate for Shutter Angle", "シャッター角度換算フレームレート"),
            ["快门速度"] = new("Shutter Speed", "シャッタースピード"),
            ["快门角度"] = new("Shutter Angle", "シャッター角度"),
            ["光圈"] = new("Aperture", "絞り"),
            ["ISO 感光度"] = new("ISO Sensitivity", "ISO 感度"),
            ["曝光补偿"] = new("Exposure Compensation", "露出補正"),
            ["对焦模式"] = new("Focus Mode", "フォーカスモード"),
            ["单次自动对焦"] = new("Single AF", "シングル AF"),
            ["连续自动对焦"] = new("Continuous AF", "コンティニュアス AF"),
            ["手动对焦"] = new("Manual Focus", "マニュアルフォーカス"),
            ["白平衡"] = new("White Balance", "ホワイトバランス"),
            ["预设手动"] = new("Preset Manual", "プリセットマニュアル"),
            ["优化校准"] = new("Picture Control", "ピクチャーコントロール"),
            ["自动"] = new("Auto", "オート"),
            ["标准"] = new("Standard", "スタンダード"),
            ["自然"] = new("Neutral", "ニュートラル"),
            ["鲜艳"] = new("Vivid", "ビビッド"),
            ["单色"] = new("Monochrome", "モノクローム"),
            ["人像"] = new("Portrait", "ポートレート"),
            ["风景"] = new("Landscape", "風景"),
            ["平面"] = new("Flat", "フラット"),
            ["就绪"] = new("Ready", "準備完了"),
            ["当前版本"] = new("Current Version", "現在のバージョン"),
            ["正在连接"] = new("Connecting", "接続中"),
            ["正在断开"] = new("Disconnecting", "切断中"),
            ["已连接"] = new("Connected", "接続済み"),
            ["已保存"] = new("Saved", "保存しました"),
            ["照片保存在"] = new("Photos are saved in ", "写真の保存先："),
            ["张照片"] = new(" photos", " 枚の写真"),
            ["相机原生 JPEG · 监看输出 · 不修改原片"] =
                new(
                    "Camera JPEG · Monitor Output · Original Unchanged",
                    "カメラ JPEG · モニター出力 · オリジナルは変更しません"),
            ["录制已停止 · 视频保存在相机存储卡"] =
                new(
                    "Recording Stopped · Video Saved to Camera Card",
                    "録画を停止しました · 動画はカメラのメモリーカードに保存されます"),
            ["视频正在录制到相机存储卡"] =
                new(
                    "Video is recording to the camera card",
                    "動画をカメラのメモリーカードに記録中"),
            ["实时取景已安全停止 · 机身控制已释放"] =
                new(
                    "Live View Stopped Safely · Camera Control Released",
                    "ライブビューを安全に停止し、カメラ制御を解放しました"),
            ["连续 3 次未收到实时取景画面，已停止重试并释放相机。"] =
                new(
                    "No live-view image was received after 3 attempts. Retrying stopped and camera control was released.",
                    "3 回試行してもライブビュー映像を受信できなかったため、再試行を停止してカメラ制御を解放しました。"),
            ["实时取景正在重试"] =
                new("Retrying Live View", "ライブビューを再試行中"),
            ["已刷新系统相册与 帧澈 ZENCHE 文件库"] =
                new(
                    "System library and ZENCHE library refreshed",
                    "システムライブラリと ZENCHE ライブラリを更新しました"),
            ["没有可加入文件库的照片"] =
                new(
                    "No photos can be added to the library",
                    "ライブラリに追加できる写真がありません"),
            ["已从网盘加入"] =
                new("Added from cloud drive: ", "クラウドドライブから追加："),
            ["已删除"] = new("Deleted", "削除しました"),
            ["无线传输"] = new("Wireless Transfer", "ワイヤレス転送"),
            ["停止无线接收"] =
                new("Stop Wireless Receiver", "ワイヤレス受信を停止"),
            ["正在停止实时取景…"] =
                new("Stopping Live View…", "ライブビューを停止中…"),
            ["正在开启实时取景…"] =
                new("Starting Live View…", "ライブビューを開始中…"),
            ["正在停止视频录制…"] =
                new("Stopping Video Recording…", "動画録画を停止中…"),
            ["正在开始视频录制…"] =
                new("Starting Video Recording…", "動画録画を開始中…"),
            ["正在拍摄并下载 JPEG…"] =
                new("Capturing and Downloading JPEG…", "JPEG を撮影してダウンロード中…"),
            ["正在断开相机…"] =
                new("Disconnecting Camera…", "カメラを切断中…"),
            ["正在连接 Nikon 相机…"] =
                new("Connecting Nikon Camera…", "Nikon カメラに接続中…"),
            ["相机已断开"] =
                new("Camera Disconnected", "カメラを切断しました"),
            ["录制"] = new("Record", "録画"),
            ["停止"] = new("Stop", "停止"),
            ["参数"] = new("Controls", "設定"),
            ["连接相机后可调整"] =
                new("Connect a camera to adjust", "カメラを接続すると調整できます"),
            ["拍摄模式下由相机控制"] =
                new(
                    "Controlled by the camera in this shooting mode",
                    "この撮影モードではカメラ側で制御"),
            ["正在检查更新…"] =
                new("Checking for Updates…", "アップデートを確認中…"),
            ["已是最新版本"] =
                new("You're Up to Date", "最新バージョンです"),
            ["发现新版本"] =
                new("New Version Available", "新しいバージョンがあります"),
            ["检查失败，请确认网络后重试"] =
                new(
                    "Update check failed. Check your connection and try again.",
                    "確認に失敗しました。ネットワークを確認して再試行してください。"),
            ["从网盘选择照片或视频"] =
                new(
                    "Choose Photos or Videos from a Cloud Drive",
                    "クラウドドライブから写真または動画を選択"),
            ["所有文件"] = new("All Files", "すべてのファイル"),
            ["照片与视频"] = new("Photos and Videos", "写真と動画"),
            ["拍摄任务"] = new("Shooting Task", "撮影タスク"),
            ["任务类型"] = new("Task Type", "タスクの種類"),
            ["间隔拍摄"] = new("Interval Capture", "インターバル撮影"),
            ["曝光包围"] = new("Exposure Bracketing", "露出ブラケット"),
            ["焦点包围"] = new("Focus Bracketing", "フォーカスブラケット"),
            ["B 门计时"] = new("Timed Bulb", "バルブタイマー"),
            ["开始任务"] = new("Start Task", "タスクを開始"),
            ["取消任务"] = new("Cancel Task", "タスクをキャンセル"),
            ["正在取消拍摄任务…"] = new("Cancelling shooting task…", "撮影タスクをキャンセル中…"),
            ["拍摄任务已取消"] = new("Shooting task cancelled", "撮影タスクをキャンセルしました"),
            ["拍摄任务失败"] = new("Shooting task failed", "撮影タスクに失敗しました"),
            ["准备中"] = new("Preparing", "準備中"),
            ["已完成"] = new("Completed", "完了"),
            ["张数"] = new("Shots", "枚数"),
            ["间隔"] = new("Interval", "間隔"),
            ["曝光时长"] = new("Exposure Duration", "露光時間"),
            ["秒"] = new("Seconds", "秒"),
            ["包围步长"] = new("Bracket Step", "ブラケット幅"),
            ["专业监看"] = new("Professional Monitoring", "プロモニター"),
            ["峰值对焦"] = new("Focus Peaking", "フォーカスピーキング"),
            ["假色曝光"] = new("False Color", "フォルスカラー"),
            ["波形"] = new("Waveform", "波形"),
            ["矢量"] = new("Vectorscope", "ベクトルスコープ"),
            ["峰值覆盖"] = new("Peaking Coverage", "ピーキング範囲"),
            ["拍摄会话"] = new("Capture Session", "撮影セッション"),
            ["项目名称"] = new("Project Name", "プロジェクト名"),
            ["命名模板"] = new("Naming Template", "命名テンプレート"),
            ["创作者"] = new("Creator", "作成者"),
            ["版权"] = new("Rights", "著作権"),
            ["默认评级"] = new("Default Rating", "既定の評価"),
            ["双目标备份"] = new("Dual-Destination Backup", "二重保存"),
            ["开始会话"] = new("Start Session", "セッションを開始"),
            ["结束会话"] = new("End Session", "セッションを終了"),
            ["配置并开始"] = new("Configure and Start", "設定して開始"),
            ["尚未开始拍摄会话"] = new("No capture session started", "撮影セッションは未開始です"),
            ["会话进行中"] = new("Session Active", "セッション実行中"),
            ["拍摄会话已结束"] = new("Capture session ended", "撮影セッションを終了しました")
        };

    private static readonly Dictionary<DependencyObject, string> OriginalText = [];
    private static readonly Dictionary<FrameworkElement, string> OriginalToolTips = [];
    private static readonly string SettingsPath = Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
        "NikonLink",
        "language.txt");

    static AppLocalization()
    {
        Current = Load();
    }

    internal static InterfaceLanguage Current { get; private set; }

    internal static string LanguageCode => Current switch
    {
        InterfaceLanguage.English => "en",
        InterfaceLanguage.Japanese => "ja",
        _ => "zh-Hans"
    };

    internal static void SetLanguage(InterfaceLanguage language)
    {
        Current = language;
        try
        {
            Directory.CreateDirectory(Path.GetDirectoryName(SettingsPath)!);
            File.WriteAllText(SettingsPath, LanguageCode);
        }
        catch
        {
            // A read-only profile should not prevent language switching in-session.
        }
    }

    internal static string T(string source)
    {
        if (Current == InterfaceLanguage.SimplifiedChinese)
        {
            return source;
        }
        if (Strings.TryGetValue(source, out var exact))
        {
            return Current == InterfaceLanguage.English
                ? exact.English
                : exact.Japanese;
        }
        var translated = source;
        foreach (var (chinese, value) in Strings.OrderByDescending(
                     item => item.Key.Length))
        {
            translated = translated.Replace(
                chinese,
                Current == InterfaceLanguage.English
                    ? value.English
                    : value.Japanese,
                StringComparison.Ordinal);
        }
        return translated;
    }

    internal static void Apply(DependencyObject root)
    {
        ApplyElement(root);
        foreach (var child in LogicalTreeHelper.GetChildren(root))
        {
            if (child is DependencyObject dependencyObject)
            {
                Apply(dependencyObject);
            }
        }
    }

    private static void ApplyElement(DependencyObject element)
    {
        if (element is TextBlock textBlock &&
            !BindingOperations.IsDataBound(textBlock, TextBlock.TextProperty))
        {
            if (!OriginalText.TryGetValue(textBlock, out var source))
            {
                source = textBlock.Text;
                OriginalText[textBlock] = source;
            }
            textBlock.Text = T(source);
        }
        else if (element is ContentControl contentControl &&
                 contentControl.Content is string current)
        {
            if (!OriginalText.TryGetValue(contentControl, out var source))
            {
                source = current;
                OriginalText[contentControl] = source;
            }
            contentControl.Content = T(source);
        }

        if (element is FrameworkElement frameworkElement &&
            frameworkElement.ToolTip is string currentToolTip)
        {
            if (!OriginalToolTips.TryGetValue(frameworkElement, out var source))
            {
                source = currentToolTip;
                OriginalToolTips[frameworkElement] = source;
            }
            frameworkElement.ToolTip = T(source);
        }
    }

    private static InterfaceLanguage Load()
    {
        try
        {
            return File.ReadAllText(SettingsPath).Trim() switch
            {
                "en" => InterfaceLanguage.English,
                "ja" => InterfaceLanguage.Japanese,
                _ => InterfaceLanguage.SimplifiedChinese
            };
        }
        catch
        {
            return InterfaceLanguage.SimplifiedChinese;
        }
    }
}
