package com.tauber.nikonlink;

import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

final class Localization {
    static final String SIMPLIFIED_CHINESE = "zh-Hans";
    static final String ENGLISH = "en";
    static final String JAPANESE = "ja";
    static final String PREFERENCE_KEY = "appLanguage";

    private static final class Entry {
        final String english;
        final String japanese;

        Entry(String english, String japanese) {
            this.english = english;
            this.japanese = japanese;
        }
    }

    private static final Map<String, Entry> STRINGS = new LinkedHashMap<>();

    static {
        add("语言更改会立即应用，并在下次启动时保留。",
                "Language changes apply immediately and are remembered for the next launch.",
                "言語の変更はすぐに適用され、次回起動時にも保持されます。");
        add("快门、曝光、对焦、白平衡与拍摄模式集中在当前页面",
                "Shutter, exposure, focus, white balance, and shooting mode in one place",
                "シャッター、露出、フォーカス、ホワイトバランス、撮影モードを一画面で操作");
        add("请作者喝杯奶茶，支持后续维护与新机型适配。",
                "Support ongoing maintenance and compatibility with more camera models.",
                "継続的なメンテナンスと新しいカメラへの対応をご支援ください。");
        add("打开微信扫一扫，感谢支持。",
                "Scan with WeChat. Thank you for your support.",
                "WeChat でスキャンしてください。ご支援ありがとうございます。");
        add("更新公告", "What's New", "アップデートのお知らせ");
        add("本次更新", "In This Update", "今回の更新");
        add("• 新增启动更新公告，并支持按版本控制提醒。\n"
                        + "• 五端公告与赞助入口保持一致。\n"
                        + "• 更新赞助图片并优化多语言体验。",
                "• Added a launch announcement with per-version reminder control.\n"
                        + "• Kept announcements and support entry points consistent across all five platforms.\n"
                        + "• Updated the support image and improved the multilingual experience.",
                "• 起動時のお知らせとバージョンごとの通知設定を追加しました。\n"
                        + "• 5 つのプラットフォームでお知らせと支援画面を統一しました。\n"
                        + "• 支援用画像を更新し、多言語表示を改善しました。");
        add("谨防诈骗", "Scam Warning", "詐欺にご注意ください");
        add("帧澈 ZENCHE 是开源免费项目。任何声称“进群领取软件”"
                        + "或要求付费购买软件的人都是骗子，请勿转账。",
                "ZENCHE is free and open source. Anyone claiming you must join "
                        + "a group to receive the software or pay to buy it is a scammer. "
                        + "Do not send money.",
                "ZENCHE は無料のオープンソースプロジェクトです。"
                        + "「グループ参加でソフトを受け取れる」と案内したり、"
                        + "購入代金を要求したりする相手は詐欺です。送金しないでください。");
        add("自愿赞助", "Optional Support", "任意のご支援");
        add("如果本项目对你有帮助，欢迎自愿打赏；软件功能永久免费。",
                "If the project helps you, optional tips are welcome; "
                        + "the software remains free.",
                "このプロジェクトが役立った場合は任意でご支援いただけます。"
                        + "ソフトウェアは今後も無料です。");
        add("不再提醒（软件更新后仍会显示）",
                "Don't remind me again (shown after software updates)",
                "今後は表示しない（ソフトウェア更新後は再表示）");
        add("关闭公告", "Close", "閉じる");
        add("多协议无线图片收件箱",
                "Multi-Protocol Wireless Inbox",
                "マルチプロトコル・ワイヤレス受信箱");
        add("启动时自动检查更新",
                "Automatically check for updates at launch",
                "起動時にアップデートを自動確認");
        add("连接相机后开启实时取景",
                "Connect a camera to start live view",
                "カメラを接続してライブビューを開始");
        add("系统相册暂不可见",
                "System library is unavailable",
                "システムライブラリを表示できません");
        add("语言", "Language", "言語");
        add("界面语言", "Interface Language", "表示言語");
        add("设置", "Settings", "設定");
        add("打开设置", "Open Settings", "設定を開く");
        add("照片拍摄", "Photo Capture", "写真撮影");
        add("视频监看", "Video Monitor", "動画モニター");
        add("文件与传输", "Files & Transfer", "ファイルと転送");
        add("照片", "Photos", "写真");
        add("视频", "Video", "動画");
        add("文件", "Files", "ファイル");
        add("工作区", "Workspace", "ワークスペース");
        add("连接 Nikon 相机", "Connect Nikon Camera", "Nikon カメラに接続");
        add("连接相机", "Connect Camera", "カメラに接続");
        add("断开相机", "Disconnect Camera", "カメラを切断");
        add("未连接", "Not Connected", "未接続");
        add("就绪", "Ready", "準備完了");
        add("关闭", "Close", "閉じる");
        add("取消", "Cancel", "キャンセル");
        add("完成", "Done", "完了");
        add("好", "OK", "OK");
        add("刷新", "Refresh", "更新");
        add("全屏", "Full Screen", "フルスクリーン");
        add("等待相机画面", "Waiting for camera image", "カメラ映像を待機中");
        add("相机参数", "Camera Controls", "カメラ設定");
        add("拍摄模式", "Shooting Mode", "撮影モード");
        add("程序自动", "Program Auto", "プログラムオート");
        add("快门优先", "Shutter Priority", "シャッター優先");
        add("光圈优先", "Aperture Priority", "絞り優先");
        add("手动", "Manual", "マニュアル");
        add("B门", "Bulb", "バルブ");
        add("快门速度", "Shutter Speed", "シャッタースピード");
        add("快门角度", "Shutter Angle", "シャッター角度");
        add("视频帧率基准", "Video Frame Rate", "動画フレームレート");
        add("光圈", "Aperture", "絞り");
        add("ISO 感光度", "ISO Sensitivity", "ISO 感度");
        add("曝光补偿", "Exposure Compensation", "露出補正");
        add("对焦模式", "Focus Mode", "フォーカスモード");
        add("单次自动对焦", "Single AF", "シングル AF");
        add("连续自动对焦", "Continuous AF", "コンティニュアス AF");
        add("手动对焦", "Manual Focus", "マニュアルフォーカス");
        add("白平衡", "White Balance", "ホワイトバランス");
        add("预设手动", "Preset Manual", "プリセットマニュアル");
        add("优化校准", "Picture Control", "ピクチャーコントロール");
        add("自动", "Auto", "オート");
        add("标准", "Standard", "スタンダード");
        add("自然", "Neutral", "ニュートラル");
        add("鲜艳", "Vivid", "ビビッド");
        add("单色", "Monochrome", "モノクローム");
        add("人像", "Portrait", "ポートレート");
        add("风景", "Landscape", "風景");
        add("平面", "Flat", "フラット");
        add("拍摄照片", "Capture Photo", "写真を撮影");
        add("拍摄中…", "Capturing…", "撮影中…");
        add("拍摄", "Capture", "撮影");
        add("开启实时取景", "Start Live View", "ライブビュー開始");
        add("停止实时取景", "Stop Live View", "ライブビュー停止");
        add("开启取景", "Start Live View", "ライブビュー開始");
        add("停止取景", "Stop Live View", "ライブビュー停止");
        add("开始录制", "Start Recording", "録画開始");
        add("停止录制", "Stop Recording", "録画停止");
        add("视频曝光三要素", "Video Exposure", "動画露出");
        add("监看输出", "Monitor Output", "モニター出力");
        add("监看辅助", "Monitoring Tools", "モニター補助");
        add("实时取景格式", "Live View Format", "ライブビュー形式");
        add("监看显示尺寸", "Monitoring Display Size", "モニター表示サイズ");
        add("实时取景原始尺寸", "Original Live View Size", "ライブビュー元サイズ");
        add("加亮显示", "Zebra Highlight", "ゼブラ表示");
        add("应用到实时取景", "Apply to Live View", "ライブビューに適用");
        add("导入 LUT", "Import LUT", "LUT を読み込む");
        add("刷新相册", "Refresh Library", "ライブラリを更新");
        add("链接网盘", "Connect Cloud Drive", "クラウドドライブに接続");
        add("打开目录", "Open Folder", "フォルダを開く");
        add("分享到社交平台", "Share", "共有");
        add("选择文件并加入", "Choose Files to Add", "追加するファイルを選択");
        add("本地图库还是空的", "The local library is empty", "ローカルライブラリは空です");
        add("无线收件箱未开启", "Wireless inbox is off", "ワイヤレス受信箱は停止中");
        add("开启无线接收", "Start Wireless Receiver", "ワイヤレス受信を開始");
        add("停止接收", "Stop Receiving", "受信を停止");
        add("更新、诊断与支持。", "Updates, diagnostics, and support.", "アップデート、診断、サポート。");
        add("软件更新", "Software Update", "ソフトウェアアップデート");
        add("检查更新", "Check for Updates", "アップデートを確認");
        add("正在检查…", "Checking…", "確認中…");
        add("获取更新", "Get Update", "アップデートを入手");
        add("尚未检查更新", "Updates have not been checked", "アップデートは未確認です");
        add("诊断日志", "Diagnostic Logs", "診断ログ");
        add("查询日志", "View Logs", "ログを表示");
        add("查询最近日志", "View Recent Logs", "最近のログを表示");
        add("最近诊断日志", "Recent Diagnostic Logs", "最近の診断ログ");
        add("打开日志目录", "Open Log Folder", "ログフォルダを開く");
        add("上传脱敏日志", "Upload Redacted Logs", "匿名化ログをアップロード");
        add("喜欢 帧澈 ZENCHE？", "Enjoying ZENCHE?", "ZENCHE を気に入りましたか？");
        add("请作者喝奶茶", "Support the Developer", "開発者を支援");
        add("保存位置", "Save Location", "保存先");
        add("当前版本", "Current Version", "現在のバージョン");
        add("正在连接", "Connecting", "接続中");
        add("已连接", "Connected", "接続済み");
        add("已保存", "Saved", "保存しました");
        add("断开", "Disconnect", "接続解除");
        add("分享", "Share", "共有");
        add("预览", "Preview", "プレビュー");
        add("删除", "Delete", "削除");
        add("相机原生 JPEG · 监看输出 · 不修改原片",
                "Camera JPEG · Monitor Output · Original Unchanged",
                "カメラ JPEG · モニター出力 · オリジナルは変更しません");
        add("相机原生 JPEG · 本地预览",
                "Camera JPEG · Local Preview",
                "カメラ JPEG · ローカルプレビュー");
        add("系统相册中的照片与视频直接显示在本页；网盘文件通过独立指引页和系统文件选择器安全加入。",
                "System photos and videos appear directly on this page. Add cloud-drive files safely through the guide and system file picker.",
                "システムの写真と動画をこの画面に直接表示します。クラウドドライブのファイルはガイドとシステムファイル選択から安全に追加できます。");
        add("允许照片和视频访问后，最近媒体会直接显示在这里。",
                "Allow photo and video access to show recent media here.",
                "写真と動画へのアクセスを許可すると、最近のメディアがここに表示されます。");
        add("系统相册内容保持在原位置；帧澈 ZENCHE 只读取缩略图和预览。",
                "System-library items stay in place; ZENCHE reads only thumbnails and previews.",
                "システムライブラリの項目は元の場所に保持され、ZENCHE はサムネイルとプレビューのみを読み取ります。");
        add("连接相机拍摄，或在上方开启无线图片收件箱。",
                "Connect a camera to capture, or start the wireless image inbox above.",
                "カメラを接続して撮影するか、上のワイヤレス画像受信箱を開始してください。");
        add("账号和密码始终由网盘客户端管理。",
                "Accounts and passwords always remain with the cloud-drive app.",
                "アカウントとパスワードは常にクラウドドライブアプリが管理します。");
        add("先安装并登录对应客户端，把照片或视频下载到设备，再通过系统文件选择器加入 帧澈 ZENCHE。",
                "Install and sign in to the provider app, download photos or videos to the device, then add them to ZENCHE with the system file picker.",
                "対応アプリをインストールしてログインし、写真や動画をデバイスへダウンロードしてから、システムファイル選択で ZENCHE に追加します。");
        add("步骤：安装并登录 → 下载媒体 → 选择文件并加入。",
                "Steps: install and sign in → download media → choose files to add.",
                "手順：インストールしてログイン → メディアをダウンロード → 追加するファイルを選択。");
        add("连接相机并开启实时取景后即可全屏监看。",
                "Connect a camera and start live view to use full-screen monitoring.",
                "カメラを接続してライブビューを開始すると、フルスクリーンでモニターできます。");
        add("语言更改会立即应用，并在下次启动时保留。",
                "Language changes apply immediately and are remembered for the next launch.",
                "言語の変更はすぐに適用され、次回起動時にも保持されます。");
        add("正在连接…", "Connecting…", "接続中…");
        add("正在检测 Nikon 相机", "Detecting Nikon Camera", "Nikon カメラを検出中");
        add("实时取景已安全停止 · 机身控制已释放",
                "Live View Stopped Safely · Camera Control Released",
                "ライブビューを安全に停止し、カメラ制御を解放しました");
        add("实时取景正在重试", "Retrying Live View", "ライブビューを再試行中");
        add("视频正在录制到相机存储卡",
                "Video is recording to the camera card",
                "動画をカメラのメモリーカードに記録中");
        add("录制已停止 · 视频保存在相机存储卡",
                "Recording Stopped · Video Saved to Camera Card",
                "録画を停止しました · 動画はカメラのメモリーカードに保存されます");
        add("处理中…", "Processing…", "処理中…");
        add("停止", "Stop", "停止");
        add("录制", "Record", "録画");
        add("参数", "Controls", "設定");
        add("收起参数", "Hide Controls", "設定を隠す");
        add("展开参数", "Show Controls", "設定を表示");
        add("连接相机后可调整", "Connect a camera to adjust", "カメラを接続すると調整できます");
        add("拍摄模式下由相机控制",
                "Controlled by the camera in this shooting mode",
                "この撮影モードではカメラ側で制御");
        add("监看显示尺寸", "Monitoring Display Size", "モニター表示サイズ");
        add("监看 LUT（本地）", "Monitor LUT (Local)", "モニター LUT（ローカル）");
        add("尚未导入；LUT 只影响监看，不写入原片。",
                "No LUT imported; it affects monitoring only and is never written to the original.",
                "LUT は未読み込みです。モニターのみに作用し、オリジナルには書き込みません。");
        add("加亮显示阈值", "Zebra Threshold", "ゼブラしきい値");
        add("无线传输", "Wireless Transfer", "ワイヤレス転送");
        add("停止无线接收", "Stop Wireless Receiver", "ワイヤレス受信を停止");
        add("接收完成后自动进入文件库",
                "Received files enter the library automatically",
                "受信後は自動的にライブラリへ追加");
        add("端口", "Port", "ポート");
        add("用户名", "Username", "ユーザー名");
        add("密码", "Password", "パスワード");
        add("百度网盘", "Baidu Netdisk", "Baidu Netdisk");
        add("阿里云盘", "Aliyun Drive", "Aliyun Drive");
        add("腾讯微云", "Tencent Weiyun", "Tencent Weiyun");
        add("夸克网盘", "Quark Cloud Drive", "Quark Cloud Drive");
        add("迅雷云盘", "Xunlei Cloud Drive", "Xunlei Cloud Drive");
        add("已是最新版本", "You're Up to Date", "最新バージョンです");
        add("正在检查更新…", "Checking for Updates…", "アップデートを確認中…");
        add("发现新版本", "New Version Available", "新しいバージョンがあります");
        add("检查失败，请确认网络后重试",
                "Update check failed. Check your connection and try again.",
                "確認に失敗しました。ネットワークを確認して再試行してください。");
        add("日志目录暂不可用", "Log folder is unavailable", "ログフォルダを使用できません");
        add("日志暂不可用。", "Logs are unavailable.", "ログを使用できません。");
        add("只有在你检查预填内容并于 GitHub 确认提交后，脱敏日志才会发送。",
                "Redacted logs are sent only after you review the prefilled content and confirm on GitHub.",
                "匿名化ログは入力済み内容を確認し、GitHub で送信を確定した後にのみ送信されます。");
    }

    private Localization() {}

    static String normalize(String language) {
        if (ENGLISH.equals(language) || JAPANESE.equals(language)) {
            return language;
        }
        return SIMPLIFIED_CHINESE;
    }

    static String translate(String language, String source) {
        if (source == null || SIMPLIFIED_CHINESE.equals(normalize(language))) {
            return source;
        }
        Entry exact = STRINGS.get(source);
        if (exact != null) {
            return ENGLISH.equals(language) ? exact.english : exact.japanese;
        }
        String translated = source;
        List<String> fragments = new ArrayList<>(STRINGS.keySet());
        fragments.sort((left, right) -> Integer.compare(
                right.length(),
                left.length()));
        for (String chinese : fragments) {
            if (translated.contains(chinese)) {
                Entry value = STRINGS.get(chinese);
                translated = translated.replace(
                        chinese,
                        ENGLISH.equals(language) ? value.english : value.japanese);
            }
        }
        return translated;
    }

    static String[] translate(String language, String[] source) {
        String[] result = new String[source.length];
        for (int index = 0; index < source.length; index++) {
            result[index] = translate(language, source[index]);
        }
        return result;
    }

    private static void add(String chinese, String english, String japanese) {
        STRINGS.put(chinese, new Entry(english, japanese));
    }
}
