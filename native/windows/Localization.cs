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
            ["尼康云创"] = new("Nikon Imaging Cloud", "Nikon Imaging Cloud"),
            ["尼康云创预览"] = new("Nikon Imaging Cloud Preview", "Nikon Imaging Cloud プレビュー"),
            ["选择尼康云创预设"] = new("Choose a Nikon Cloud Preset", "Nikon Cloud プリセットを選択"),
            ["关闭云创预览"] = new("Disable Cloud Preview", "Cloud プレビューを無効化"),
            ["尼康云创预览已关闭"] = new("Nikon cloud preview disabled", "Nikon Cloud プレビューを無効にしました"),
            ["设备端 SDR 近似预览 · 相机与 NX Studio 成片可能不同"] = new(
                "On-device approximate SDR preview · Camera and NX Studio output may differ",
                "デバイス上の SDR 近似プレビュー · カメラ／NX Studio の出力とは異なる場合があります"),
            ["尼康云创监看"] = new("Nikon Imaging Cloud Monitor", "Nikon Imaging Cloud モニター"),
            ["关闭云创监看"] = new("Disable Cloud Monitor", "Cloud モニターを無効化"),
            ["尼康云创监看已关闭"] = new(
                "Nikon Imaging Cloud monitor disabled",
                "Nikon Imaging Cloud モニターを無効にしました"),
            ["照片与视频实时生效 · SDR 近似 · 不写入原片"] = new(
                "Live on photo and video monitoring · Approximate SDR · Originals unchanged",
                "写真・動画モニターへリアルタイム適用 · SDR 近似 · オリジナルは変更されません"),
            ["选择预设"] = new("Choose Preset", "プリセットを選択"),
            ["搜索云创预设"] = new("Search Cloud Presets", "Cloud プリセットを検索"),
            ["已关闭"] = new("Off", "オフ"),
            ["应用"] = new("Apply", "適用"),
            ["107 款设备端 SDR 预设"] = new(
                "107 on-device SDR presets",
                "デバイス上の SDR プリセット 107 種類"),
            ["选择尼康云创监看预设"] = new(
                "Choose Nikon Imaging Cloud monitor preset",
                "Nikon Imaging Cloud モニタープリセットを選択"),
            ["尼康官方 SDK"] = new("Nikon Official SDK", "ニコン公式 SDK"),
            ["索尼官方 SDK"] = new("Sony Official SDK", "ソニー公式 SDK"),
            ["连接即表示同意索尼 SDK 使用限制；帧澈独立提供产品支持。"] = new(
                "Connecting confirms acceptance of the Sony SDK restrictions; ZENCHE provides product support independently.",
                "接続すると Sony SDK の利用制限に同意したものとみなされます。製品サポートは ZENCHE が独自に提供します。"),
            ["Camera Remote SDK 2.02.00 已就绪"] = new(
                "Camera Remote SDK 2.02.00 is ready",
                "Camera Remote SDK 2.02.00 は準備完了です"),
            ["官方 SDK 已安装，初始化或枚举失败"] = new(
                "Official SDK installed; initialization or enumeration failed",
                "公式 SDK はインストール済みですが、初期化または列挙に失敗しました"),
            ["SDK 已就绪 · 未发现空闲索尼相机"] = new(
                "SDK ready · No available Sony camera found",
                "SDK 準備完了 · 利用可能なソニーカメラは見つかりません"),
            ["重新检测"] = new("Check Again", "再検出"),
            ["断开当前 USB 会话后可重新检测"] = new(
                "Disconnect the current USB session to check again",
                "現在の USB セッションを切断して再検出してください"),
            ["Remote SDK 2.0.0 与 Image SDK 1.46.0 已就绪"] = new(
                "Remote SDK 2.0.0 and Image SDK 1.46.0 are ready",
                "Remote SDK 2.0.0 と Image SDK 1.46.0 は準備完了です"),
            ["官方 SDK 已安装，部分组件初始化失败"] = new(
                "Official SDK installed; some components failed to initialize",
                "公式 SDK はインストール済みですが、一部の初期化に失敗しました"),
            ["官方 SDK 运行库未载入"] = new(
                "Official SDK runtime not loaded",
                "公式 SDK ランタイムが読み込まれていません"),
            ["SDK 已就绪 · 未发现空闲尼康相机"] = new(
                "SDK ready · No available Nikon camera found",
                "SDK 準備完了 · 利用可能なニコンカメラは見つかりません"),
            ["SDK 已安装 · 断开当前 USB 会话后可重新检测"] = new(
                "SDK installed · Disconnect the current USB session to check again",
                "SDK インストール済み · 現在の USB セッションを切断して再検出してください"),
            ["Remote SDK 运行库未找到"] = new(
                "Remote SDK runtime not found",
                "Remote SDK ランタイムが見つかりません"),
            ["NEF / NRW 引擎已完成官方初始化"] = new(
                "Official NEF / NRW engine initialized",
                "公式 NEF / NRW エンジンを初期化しました"),
            ["Image SDK 运行库未找到"] = new(
                "Image SDK runtime not found",
                "Image SDK ランタイムが見つかりません"),
            ["可连接"] = new("Available", "接続可能"),
            ["正被占用"] = new("In use", "使用中"),
            ["连接管理"] = new("Connection Manager", "接続管理"),
            ["相机连接"] = new("Camera Connections", "カメラ接続"),
            ["本机摄像头、USB/PTP 与官方 SDK"] = new(
                "Local camera, USB/PTP, and official SDKs",
                "ローカルカメラ、USB/PTP、公式 SDK"),
            ["相机控制"] = new("Camera Control", "カメラ制御"),
            ["文件接收"] = new("File Receiving", "ファイル受信"),
            ["拍摄辅助"] = new("Capture Assistants", "撮影アシスト"),
            ["蓝牙遥控与拍摄定位"] = new(
                "Bluetooth remote and capture location",
                "Bluetooth リモートと撮影位置"),
            ["通用、拍摄辅助、更新、诊断与支持。"] = new(
                "General, capture assistants, updates, diagnostics, and support.",
                "一般、撮影アシスト、更新、診断、サポート。"),
            ["兼容 ZENCHE BLE Remote 服务；遥控器发出快门通知后，将触发当前已连接相机。"] = new(
                "Compatible with the ZENCHE BLE Remote service. A shutter notification triggers the currently connected camera.",
                "ZENCHE BLE Remote サービスに対応し、シャッター通知で現在接続中のカメラを撮影します。"),
            ["仅在应用使用期间定位；下载的照片会生成包含 GPS 信息的标准 XMP 旁车文件。"] = new(
                "Location is used only while the app is active. Downloaded photos receive a standard XMP GPS sidecar.",
                "位置情報はアプリ使用中のみ取得し、ダウンロードした写真に標準 XMP GPS サイドカーを作成します。"),
            ["相机连接与拍摄辅助"] = new(
                "Camera Connections & Capture Aids",
                "カメラ接続と撮影支援"),
            ["USB、Wi‑Fi PTP/IP、蓝牙快门与拍摄位置"] = new(
                "USB, Wi‑Fi PTP/IP, Bluetooth shutter, and capture location",
                "USB、Wi‑Fi PTP/IP、Bluetooth シャッター、撮影位置"),
            ["Wi‑Fi 相机 · PTP/IP"] = new(
                "Wi‑Fi Camera · PTP/IP",
                "Wi‑Fi カメラ · PTP/IP"),
            ["连接模式"] = new("Connection Mode", "接続モード"),
            ["AP 直连"] = new("AP Direct", "AP ダイレクト"),
            ["STA 局域网"] = new("STA LAN", "STA LAN"),
            ["AP 模式：让电脑加入相机热点；相机地址通常为 192.168.1.1。"] = new(
                "AP mode: Join the camera hotspot on this PC; the camera address is usually 192.168.1.1.",
                "AP モード：PC をカメラのアクセスポイントに接続します。カメラのアドレスは通常 192.168.1.1 です。"),
            ["STA 模式：让相机与电脑加入同一局域网，并输入路由器分配给相机的 IP 地址。"] = new(
                "STA mode: Connect the camera and PC to the same LAN, then enter the camera IP address assigned by the router.",
                "STA モード：カメラと PC を同じ LAN に接続し、ルーターがカメラに割り当てた IP アドレスを入力します。"),
            ["请先让电脑加入相机热点；标准 PTP/IP 默认端口为 15740。"] = new(
                "Join the camera hotspot on this PC first. Standard PTP/IP uses port 15740 by default.",
                "先に PC をカメラのアクセスポイントへ接続してください。標準 PTP/IP の既定ポートは 15740 です。"),
            ["蓝牙遥控拍摄"] = new(
                "Bluetooth Remote Capture",
                "Bluetooth リモート撮影"),
            ["拍摄位置"] = new("Capture Location", "撮影位置"),
            ["拍摄时写入同名 XMP GPS，不在后台持续定位。"] = new(
                "Writes GPS to a matching XMP sidecar at capture time; no continuous background location.",
                "撮影時に同名の XMP へ GPS を記録し、バックグラウンドで継続測位しません。"),
            ["Wi‑Fi 相机未连接"] = new(
                "Wi‑Fi camera not connected",
                "Wi‑Fi カメラ未接続"),
            ["蓝牙遥控未开启"] = new(
                "Bluetooth remote is off",
                "Bluetooth リモコンはオフです"),
            ["定位未开启"] = new("Location is off", "位置情報はオフです"),
            ["启用"] = new("Enable", "有効"),
            ["AI 创作"] = new("AI Create", "AI クリエイト"),
            ["修图覆盖原图 · 生图保存新文件"] = new("AI editing overwrites the original · generation saves a new file", "AI編集は元画像を上書き · 生成は新規ファイルとして保存"),
            ["需要激活"] = new("Activation required", "アクティベーションが必要"),
            ["已解锁"] = new("Unlocked", "ロック解除済み"),
            ["输出参数"] = new("Output parameters", "出力パラメータ"),
            ["视频曝光模式"] = new("Video Exposure Mode", "動画露出モード"),
            ["视频快门表示"] = new("Video Shutter Display", "動画シャッター表示"),
            ["视频编码"] = new("Video Codec", "動画コーデック"),
            ["视频录制规格"] = new("Video Recording Format", "動画記録形式"),
            ["录制规格来源"] = new("Recording Format Source", "記録形式のソース"),
            ["Log / Picture Profile"] = new("Log / Picture Profile", "Log / ピクチャープロファイル"),
            ["编码"] = new("Codec", "コーデック"),
            ["N-Log 已开启"] = new("N-Log enabled", "N-Log を有効にしました"),
            ["N-Log 已关闭"] = new("N-Log disabled", "N-Log を無効にしました"),
            ["我的设备"] = new("My Devices", "マイデバイス"),
            ["管理连接过的相机，轻触即可快速重连"] = new(
                "Keep connected cameras ready for one-tap reconnection.",
                "接続済みカメラを管理し、すばやく再接続できます。"),
            ["尚未连接过设备"] = new(
                "No Saved Devices",
                "保存済みデバイスはありません"),
            ["成功连接相机后会自动保存在这里。"] = new(
                "Cameras are saved here automatically after a successful connection.",
                "接続に成功したカメラは自動的にここへ保存されます。"),
            ["当前已连接"] = new("Connected", "接続中"),
            ["最近连接"] = new("Last connected", "最終接続"),
            ["快速连接"] = new("Quick Connect", "クイック接続"),
            ["忘记设备"] = new("Forget Device", "デバイスを削除"),
            ["生成图像"] = new("Generate Image", "画像を生成"),
            ["创建蒙版"] = new("Create Mask", "マスクを作成"),
            ["蒙版"] = new("Mask", "マスク"),
            ["蒙版列表"] = new("Mask List", "マスク一覧"),
            ["暂无蒙版"] = new("No masks yet", "マスクはまだありません"),
            ["显示"] = new("Visible", "表示"),
            ["显示蒙版"] = new("Show Mask", "マスクを表示"),
            ["隐藏蒙版"] = new("Hide Mask", "マスクを非表示"),
            ["蒙版已显示"] = new("Mask shown", "マスクを表示しました"),
            ["蒙版已隐藏"] = new("Mask hidden", "マスクを非表示にしました"),
            ["已切换蒙版"] = new("Mask selected", "マスクを選択しました"),
            ["删除蒙版"] = new("Delete Mask", "マスクを削除"),
            ["添加蒙版（画笔）"] = new("Add to Mask (Brush)", "マスクに追加（ブラシ）"),
            ["减去蒙版（画笔）"] = new("Subtract from Mask (Brush)", "マスクから削除（ブラシ）"),
            ["画笔大小"] = new("Brush Size", "ブラシサイズ"),
            ["画笔"] = new("Brush", "ブラシ"),
            ["智能识别"] = new("Smart Selection", "スマート選択"),
            ["智能主体"] = new("Smart Subject", "スマート被写体"),
            ["智能天空"] = new("Smart Sky", "スマート空"),
            ["智能背景"] = new("Smart Background", "スマート背景"),
            ["智能人物"] = new("Smart Person", "スマート人物"),
            ["智能亮部"] = new("Smart Highlights", "スマートハイライト"),
            ["智能暗部"] = new("Smart Shadows", "スマートシャドウ"),
            ["反向蒙版"] = new("Invert Mask", "マスクを反転"),
            ["蒙版内调整"] = new("Mask Adjustments", "マスク内調整"),
            ["蒙版已反向"] = new("Mask inverted", "マスクを反転しました"),
            ["蒙版已恢复正向"] = new("Mask restored", "マスクを通常方向に戻しました"),
            ["智能蒙版已创建 · 可继续添加或减去画笔"] = new(
                "Smart mask created · Refine with the add or subtract brush",
                "スマートマスクを作成しました · 追加／削除ブラシで調整できます"),
            ["区域 · 可继续添加或减去画笔"] = new(" area · Refine with add or subtract brush", "領域 · 追加／削除ブラシで調整できます"),
            ["蒙版已创建 · 在预览画面涂抹"] = new("Mask created · Paint on the preview", "マスクを作成しました · プレビュー上で描画してください"),
            ["蒙版已删除"] = new("Mask deleted", "マスクを削除しました"),
            ["添加蒙版画笔已启用"] = new("Add-mask brush enabled", "追加ブラシを有効にしました"),
            ["减去蒙版画笔已启用"] = new("Subtract-mask brush enabled", "削除ブラシを有効にしました"),
            ["在预览画面拖动画笔；蓝色为添加，白色为减去。"] = new("Drag on the preview; blue adds and white subtracts.", "プレビュー上をドラッグします。青は追加、白は削除です。"),
            ["先创建蒙版，再选择添加或减去画笔。"] = new("Create a mask, then choose the add or subtract brush.", "マスクを作成してから追加または削除ブラシを選択します。"),
            ["次剩余"] = new("uses remaining", "回残り"),
            ["前往官网兑换密钥"] =
                new("Redeem Key on Official Website", "公式サイトでキーを交換"),
            ["复制设备 ID 后，前往 zenche.top 使用兑换码兑换绑定当前设备的激活密钥。"] =
                new(
                    "Copy the device ID, then redeem a key bound to this device at zenche.top.",
                    "デバイス ID をコピーし、zenche.top でこのデバイス用のキーに交換してください。"),
            ["没有兑换码？在爱发电购买兑换码"] =
                new(
                    "Need a redemption code? Buy one on Afdian",
                    "交換コードをお持ちでない場合は Afdian で購入できます"),
            ["在爱发电购买兑换码"] =
                new("Buy Redemption Code on Afdian", "Afdian で交換コードを購入"),
            ["兑换码仅用于 AI 云服务次数，帧澈本体保持免费开源。"] =
                new(
                    "Redemption codes cover AI cloud usage only; ZENCHE remains free and open source.",
                    "交換コードは AI クラウド利用分のみが対象で、ZENCHE 本体は無料・オープンソースです。"),
            ["设备 ID 已复制，可前往官网兑换密钥"] =
                new(
                    "Device ID copied. You can now redeem a key on the official website.",
                    "デバイス ID をコピーしました。公式サイトでキーを交換できます。"),
            ["每个激活密钥绑定当前设备，请复制上面的设备 ID 并前往官网兑换。"] =
                new(
                    "Each activation key is bound to this device. Copy the device ID above and redeem it on the official website.",
                    "各アクティベーションキーはこのデバイスに紐づきます。上のデバイス ID をコピーして公式サイトで交換してください。"),
            ["拍前会话与交付"] =
                new("Session & Delivery", "撮影前セッションと納品"),
            ["拍摄控制"] =
                new("Capture Controls", "撮影コントロール"),
            ["视频曝光与监看"] =
                new("Video Exposure & Monitoring", "動画露出とモニタリング"),
            ["对焦与色彩"] =
                new("Focus & Color", "フォーカスとカラー"),
            ["拍摄自动化"] =
                new("Capture Automation", "撮影オートメーション"),
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
            ["• 监看页左侧改为 RGB 三色波形，右侧新增音频波形卡；无音频源时显示静音基线。\n" +
             "• Android 录制键移动到两张波形图之间，监看预览右上角移除全屏按钮。\n" +
             "• 移除监看镜头读数与“曝光”工具入口；帧率、快门角度、ISO 等参数可直接调节。\n" +
             "• 点击监看画面可切换焦点，显示焦点标记并调用原生对焦；PTP 设备按点击区域执行焦点步进。\n" +
             "• iOS / iPadOS、Android、HarmonyOS、macOS、Windows 五端同步更新。"] =
                new(
                    "• The monitor now shows separate RGB waveforms on the left and an audio waveform card on the right; without an audio source it displays a silent baseline.\n" +
                    "• Android moves the recording control between the two waveform cards and removes the monitor preview fullscreen button.\n" +
                    "• Removed the monitor lens readout and the “曝光” tool entry; frame rate, shutter angle, ISO, and related parameters can be adjusted directly.\n" +
                    "• Tapping the monitor preview switches focus, shows a focus marker, and requests native focus; PTP devices map the tap region to focus steps.\n" +
                    "• Synchronized the update across iOS / iPadOS, Android, HarmonyOS, macOS, and Windows.",
                    "• モニター左側に RGB 3 チャンネル波形、右側に音声波形カードを追加。音声ソースがない場合は無音の基準線を表示します。\n" +
                    "• Android では録画ボタンを 2 つの波形カードの中央へ移動し、モニタープレビュー右上の全画面ボタンを削除しました。\n" +
                    "• モニターのレンズ表示と「曝光」ツール入口を削除し、フレームレート、シャッター角度、ISO などを直接調整できます。\n" +
                    "• モニタープレビューをタップするとフォーカス位置を切り替え、フォーカスマーカーを表示してネイティブフォーカスを要求します。PTP 機器ではタップ領域をフォーカスステップへ変換します。\n" +
                    "• iOS / iPadOS、Android、HarmonyOS、macOS、Windows を同時更新。"),
            ["• 新增“外录到当前智能设备”：视频可实时写入 ZENCHE 文件库，并可与相机机身存储卡录制并行。\n" +
             "• 新增相机机内存储管理：可浏览存储卷与文件、查看缩略图和保护状态，并批量下载或确认后永久删除。\n" +
             "• 照片继续直接保存到当前设备；外录视频沿用会话命名、备份与 SHA‑256 完整性记录。\n" +
             "• PTP 实时取景不含音频，Android、HarmonyOS、macOS 与 Windows 外录为无声 Motion‑JPEG AVI；iOS / iPadOS 本机与 UVC 源外录为 MOV。\n" +
             "• 停止录制、断开相机或发生写入异常时会安全封装已写入的视频，减少素材损失。\n" +
             "• iOS / iPadOS、Android、HarmonyOS、macOS、Windows 五端同步更新。"] =
                new(
                    "• Added “Record to This Smart Device”: video can be written live to the ZENCHE library alongside in-camera card recording.\n" +
                    "• Added in-camera storage management with volume and file browsing, thumbnails, protection state, batch download, and confirmed permanent deletion.\n" +
                    "• Photos continue to save directly to this device; external video keeps session naming, backups, and SHA-256 integrity records.\n" +
                    "• PTP live view contains no audio. Android, HarmonyOS, macOS, and Windows record silent Motion-JPEG AVI; local and UVC sources on iOS / iPadOS record MOV.\n" +
                    "• Stopping, disconnecting the camera, or encountering a write error safely finalizes the recorded video to reduce footage loss.\n" +
                    "• Synchronized the update across iOS / iPadOS, Android, HarmonyOS, macOS, and Windows.",
                    "• 「このスマートデバイスへ外部収録」を追加。動画を ZENCHE ライブラリへリアルタイム保存し、カメラ内カード記録と併用できます。\n" +
                    "• カメラ内ストレージ管理を追加。ストレージとファイルの参照、サムネイル、保護状態、一括ダウンロード、確認付き完全削除に対応します。\n" +
                    "• 写真は引き続きこのデバイスへ直接保存。外部収録動画にはセッション命名、バックアップ、SHA-256 整合性記録を適用します。\n" +
                    "• PTP ライブビューに音声は含まれません。Android、HarmonyOS、macOS、Windows は無音の Motion-JPEG AVI、iOS / iPadOS のローカル／UVC ソースは MOV で収録します。\n" +
                    "• 収録停止、カメラ切断、書き込みエラー時も記録済み動画を安全に確定し、素材損失を抑えます。\n" +
                    "• iOS / iPadOS、Android、HarmonyOS、macOS、Windows を同時更新。"),
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
            ["来源"] = new("Source", "入力"),
            ["模式"] = new("Mode", "モード"),
            ["快门"] = new("Shutter", "シャッター"),
            ["照片拍摄"] = new("Photo Capture", "写真撮影"),
            ["视频监看"] = new("Video Monitor", "動画モニター"),
            ["编辑"] = new("Edit", "編集"),
            ["图像编辑"] = new("Image Editor", "画像編集"),
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
            ["无损调整亮度、对比度、饱和度与方向；保存时生成 JPEG 副本。"] =
                new(
                    "Adjust brightness, contrast, saturation, and orientation without changing the original; saving creates a JPEG copy.",
                    "元画像を変更せずに明るさ、コントラスト、彩度、向きを調整し、保存時に JPEG のコピーを作成します。"),
            ["编辑照片"] = new("Photo to Edit", "編集する写真"),
            ["选择一张照片开始编辑"] =
                new("Choose a photo to start editing", "写真を選択して編集を開始"),
            ["亮度"] = new("Brightness", "明るさ"),
            ["对比度"] = new("Contrast", "コントラスト"),
            ["饱和度"] = new("Saturation", "彩度"),
            ["旋转 90°"] = new("Rotate 90°", "90° 回転"),
            ["重置"] = new("Reset", "リセット"),
            ["保存副本"] = new("Save Copy", "コピーを保存"),
            ["正在保存…"] = new("Saving…", "保存中…"),
            ["调整不会覆盖原文件"] =
                new(
                    "Adjustments do not overwrite the original",
                    "調整しても元のファイルは上書きされません"),
            ["已保存副本"] = new("Saved copy", "コピーを保存しました"),
            ["无法预览："] = new("Unable to preview: ", "プレビューできません："),
            ["保存失败："] = new("Save failed: ", "保存に失敗しました："),
            ["专业显影"] = new("Pro Develop", "プロ現像"),
            ["分组调整光线、色彩、细节、效果与几何；始终保留原文件。"] =
                new(
                    "Adjust light, color, detail, effects, and geometry in focused groups while always preserving the original.",
                    "ライト、カラー、ディテール、効果、ジオメトリをグループ別に調整し、元のファイルを常に保持します。"),
            ["AI 智能修图"] = new("AI Retouch", "AI レタッチ"),
            ["设备端分析画面并生成可继续微调的专业参数；照片不会上传。"] =
                new(
                    "Analyze the image on-device and generate professional settings you can keep refining; photos are never uploaded.",
                    "デバイス上で画像を解析し、さらに微調整できるプロ設定を生成します。写真はアップロードされません。"),
            ["智能优化"] = new("Smart Enhance", "スマート補正"),
            ["AI 修图工作台"] = new("AI Retouch Workbench", "AI レタッチワークベンチ"),
            ["设备端 · 不上传"] = new("On-device · Never uploaded", "デバイス内 · アップロードなし"),
            ["分析画面"] = new("Analyze Image", "画像を解析"),
            ["画面分析完成 · 可应用 AI 建议"] = new("Analysis complete · Ready to apply AI", "解析完了 · AI 補正を適用できます"),
            ["已复制 AI 调整，可应用到下一张照片"] = new("AI settings copied; apply them to the next photo", "AI 補正をコピーしました。次の写真に適用できます"),
            ["已粘贴 AI 调整"] = new("AI settings pasted", "AI 補正を貼り付けました"),
            ["动态范围"] = new("Dynamic range", "ダイナミックレンジ"),
            ["设备端"] = new("On-device", "デバイス内"),
            ["AI 强度"] = new("AI Strength", "AI 強度"),
            ["撤销 AI"] = new("Undo AI", "AI を元に戻す"),
            ["等待分析当前照片"] =
                new("Ready to analyze this photo", "この写真を解析できます"),
            ["检测到画面偏暗，已提亮阴影并保护高光"] =
                new(
                    "The image is dark; shadows were lifted while highlights were protected.",
                    "暗めの画像を検出し、ハイライトを保護しながらシャドウを明るくしました。"),
            ["检测到画面偏亮，已回收高光并恢复层次"] =
                new(
                    "The image is bright; highlights were recovered to restore tonal detail.",
                    "明るめの画像を検出し、ハイライトを抑えて階調を復元しました。"),
            ["检测到动态范围偏平，已增强层次与色彩"] =
                new(
                    "The tonal range is flat; depth and color were enhanced.",
                    "階調がフラットなため、立体感と色彩を強調しました。"),
            ["曝光均衡，已优化色彩与细节"] =
                new(
                    "Exposure is balanced; color and detail were refined.",
                    "露出は良好です。色彩とディテールを最適化しました。"),
            ["已撤销 AI 优化"] =
                new("AI enhancement undone", "AI 補正を元に戻しました"),
            ["AI 优化已应用 · 可继续微调"] =
                new(
                    "AI enhancement applied · Continue refining any setting",
                    "AI 補正を適用しました · 各設定を引き続き調整できます"),
            ["已恢复 AI 优化前的参数"] =
                new(
                    "Restored the settings from before AI enhancement",
                    "AI 補正前の設定に戻しました"),
            ["无法分析当前照片"] =
                new("Unable to analyze this photo", "この写真を解析できません"),
            ["光线"] = new("Light", "ライト"),
            ["色彩"] = new("Color", "カラー"),
            ["色轮"] = new("Color Wheels", "カラーホイール"),
            ["曲线"] = new("Curves", "カーブ"),
            ["蒙版"] = new("Masks", "マスク"),
            ["阴影曲线"] = new("Shadow Curve", "シャドウカーブ"),
            ["中间调曲线"] = new("Midtone Curve", "中間調カーブ"),
            ["高光曲线"] = new("Highlight Curve", "ハイライトカーブ"),
            ["中间调"] = new("Midtones", "中間調"),
            ["Lift / Gamma / Gain · 三向色轮"] = new("Lift / Gamma / Gain · Three-way wheels", "Lift / Gamma / Gain · 3ウェイホイール"),
            ["蒙版类型"] = new("Mask type", "マスクタイプ"),
            ["线性渐变"] = new("Linear gradient", "線形グラデーション"),
            ["径向渐变"] = new("Radial gradient", "放射グラデーション"),
            ["主体"] = new("Subject", "被写体"),
            ["强度"] = new("Amount", "強度"),
            ["羽化"] = new("Feather", "ぼかし"),
            ["反相蒙版"] = new("Invert mask", "マスクを反転"),
            ["取色器已启用，请点击预览画面"] = new("Picker armed. Click the preview.", "スポイトを有効化しました。プレビューをクリックしてください。"),
            ["取色器已关闭"] = new("Picker disabled", "スポイトを無効化しました"),
            ["点击预览取色 · 再次关闭"] = new("Click preview to sample · click again to disable", "プレビューをクリックしてサンプル · 再度クリックで無効化"),
            ["未取样"] = new("No sample", "未サンプル"),
            ["在预览画面点击取样色彩，自动微调色温与色调"] = new("Click the preview to sample color and fine-tune temperature and tint", "プレビューをクリックして色をサンプルし、色温と色かぶりを微調整"),
            ["调色台 · 色轮 · 曲线 · 取色器 · 蒙版 · 始终保留原文件。"] = new("Colorist desk · wheels · curves · picker · masks · originals stay untouched.", "カラーグレーディング · ホイール · カーブ · スポイト · マスク · 元ファイルは保持"),
            ["细节"] = new("Detail", "ディテール"),
            ["效果"] = new("Effects", "効果"),
            ["几何"] = new("Geometry", "ジオメトリ"),
            ["曝光"] = new("Exposure", "露光量"),
            ["高光"] = new("Highlights", "ハイライト"),
            ["阴影"] = new("Shadows", "シャドウ"),
            ["白色色阶"] = new("Whites", "白レベル"),
            ["黑色色阶"] = new("Blacks", "黒レベル"),
            ["色温"] = new("Temperature", "色温"),
            ["色调"] = new("Tint", "色かぶり補正"),
            ["自然饱和度"] = new("Vibrance", "自然な彩度"),
            ["纹理"] = new("Texture", "テクスチャ"),
            ["清晰度"] = new("Clarity", "明瞭度"),
            ["锐化"] = new("Sharpening", "シャープ"),
            ["降噪"] = new("Noise Reduction", "ノイズ軽減"),
            ["去雾"] = new("Dehaze", "かすみの除去"),
            ["暗角"] = new("Vignette", "周辺光量"),
            ["裁切比例"] = new("Crop Ratio", "切り抜き比率"),
            ["原始比例"] = new("Original Ratio", "元の比率"),
            ["水平翻转"] = new("Flip Horizontal", "左右反転"),
            ["垂直翻转"] = new("Flip Vertical", "上下反転"),
            ["预设"] = new("Preset", "プリセット"),
            ["原始"] = new("Original", "オリジナル"),
            ["自然增强"] = new("Natural Enhance", "ナチュラル補正"),
            ["人像柔和"] = new("Soft Portrait", "ソフトポートレート"),
            ["风光通透"] = new("Clear Landscape", "クリア風景"),
            ["高反差黑白"] = new("High-Contrast B&W", "ハイコントラスト白黒"),
            ["查看原图"] = new("Show Original", "元画像を表示"),
            ["返回调整"] = new("Back to Adjustments", "調整に戻る"),
            ["原图"] = new("Original", "元画像"),
            ["调整后"] = new("Adjusted", "調整後"),
            ["全部重置"] = new("Reset All", "すべてリセット"),
            ["保存高质量副本"] =
                new("Save High-Quality Copy", "高品質コピーを保存"),
            ["已保存高质量副本"] =
                new("Saved high-quality copy", "高品質コピーを保存しました"),
            ["正在查看原图"] = new("Viewing original", "元画像を表示中"),
            ["相机机内存储"] = new("In-Camera Storage", "カメラ内ストレージ"),
            ["连接相机后可浏览存储卡"] = new(
                "Connect a camera to browse its memory card",
                "カメラを接続するとメモリーカードを参照できます"),
            ["正在读取存储卡…"] = new("Reading camera card…", "カメラ内カードを読み込み中…"),
            ["读取完成"] = new("Ready", "読み込み完了"),
            ["读取失败"] = new("Unable to read storage", "ストレージを読み込めません"),
            ["全选"] = new("Select All", "すべて選択"),
            ["取消全选"] = new("Deselect All", "すべての選択を解除"),
            ["下载到 ZENCHE"] = new("Download to ZENCHE", "ZENCHE へダウンロード"),
            ["从相机删除"] = new("Delete from Camera", "カメラから削除"),
            ["从相机永久删除？"] = new(
                "Permanently delete from camera?",
                "カメラから完全に削除しますか？"),
            ["永久删除"] = new("Delete Permanently", "完全に削除"),
            ["此操作无法撤销；已保护文件不会被选择。"] = new(
                "This cannot be undone. Protected files are not selected.",
                "この操作は取り消せません。保護されたファイルは選択されません。"),
            ["正在下载"] = new("Downloading", "ダウンロード中"),
            ["已下载"] = new("Downloaded", "ダウンロード完了"),
            ["正在从相机删除…"] = new("Deleting from camera…", "カメラから削除中…"),
            ["已从相机删除"] = new("Deleted from camera", "カメラから削除しました"),
            ["受保护"] = new("Protected", "保護済み"),
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
            ["外录到当前智能设备"] =
                new("Record to This Smart Device", "このスマートデバイスへ外部収録"),
            ["实时取景会生成无声 Motion‑JPEG AVI 并写入 ZENCHE 文件库；可与机身录制并行。"] =
                new(
                    "Live view creates a silent Motion-JPEG AVI in the ZENCHE library alongside in-camera recording.",
                    "ライブビューから無音の Motion-JPEG AVI を ZENCHE ライブラリへ保存し、カメラ内記録と併用できます。"),
            ["外录已开启 · 视频将写入 ZENCHE 文件库"] =
                new(
                    "External recording on · Video will be written to the ZENCHE library",
                    "外部収録オン · 動画を ZENCHE ライブラリへ保存します"),
            ["外录已关闭 · PTP 相机仅记录到机身存储卡"] =
                new(
                    "External recording off · PTP cameras record only to the camera card",
                    "外部収録オフ · PTP カメラはカメラ内カードのみに記録します"),
            ["● EXT REC · 正在外录到当前智能设备"] =
                new(
                    "● EXT REC · Recording to this smart device",
                    "● EXT REC · このスマートデバイスへ外部収録中"),
            ["录制已停止 · 外录文件已保存到 ZENCHE 文件库"] =
                new(
                    "Recording stopped · External recording saved to the ZENCHE library",
                    "収録停止 · 外部収録ファイルを ZENCHE ライブラリへ保存しました"),
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
            ["正在连接相机…"] =
                new("Connecting Camera…", "カメラに接続中…"),
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
