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
        add("尼康云创", "Nikon Imaging Cloud", "Nikon Imaging Cloud");
        add("尼康云创预览", "Nikon Imaging Cloud Preview", "Nikon Imaging Cloud プレビュー");
        add("选择尼康云创预设", "Choose a Nikon Cloud Preset", "Nikon Cloud プリセットを選択");
        add("关闭云创预览", "Disable Cloud Preview", "Cloud プレビューを無効化");
        add("尼康云创预览已关闭", "Nikon cloud preview disabled", "Nikon Cloud プレビューを無効にしました");
        add("设备端 SDR 近似预览 · 相机与 NX Studio 成片可能不同",
                "On-device approximate SDR preview · Camera and NX Studio output may differ",
                "デバイス上の SDR 近似プレビュー · カメラ／NX Studio の出力とは異なる場合があります");
        add("尼康云创监看", "Nikon Imaging Cloud Monitor", "Nikon Imaging Cloud モニター");
        add("关闭云创监看", "Disable Cloud Monitor", "Cloud モニターを無効化");
        add("尼康云创监看已关闭", "Nikon Imaging Cloud monitor disabled", "Nikon Imaging Cloud モニターを無効にしました");
        add("照片与视频实时生效 · SDR 近似 · 不写入原片",
                "Live on photo and video monitoring · Approximate SDR · Originals unchanged",
                "写真・動画モニターへリアルタイム適用 · SDR 近似 · オリジナルは変更されません");
        add("选择预设", "Choose Preset", "プリセットを選択");
        add("搜索云创预设", "Search Cloud Presets", "Cloud プリセットを検索");
        add("已关闭", "Off", "オフ");
        add("应用", "Apply", "適用");
        add("107 款设备端 SDR 预设", "107 on-device SDR presets", "デバイス上の SDR プリセット 107 種類");
        add("选择尼康云创监看预设",
                "Choose Nikon Imaging Cloud monitor preset",
                "Nikon Imaging Cloud モニタープリセットを選択");
        add("尼康官方 SDK", "Nikon Official SDK", "ニコン公式 SDK");
        add("官方桌面 SDK 不提供当前平台运行库",
                "The official desktop SDK has no runtime for this platform",
                "公式デスクトップ SDK はこのプラットフォーム向けランタイムを提供していません");
        add("尼康只为 macOS 与 Windows 提供本次 SDK 运行库；当前平台继续使用原生相机连接后端。",
                "Nikon supplies these SDK runtimes only for macOS and Windows; this platform continues using its native camera connection backend.",
                "今回の SDK ランタイムは macOS と Windows のみ提供されています。このプラットフォームではネイティブのカメラ接続バックエンドを継続して使用します。");
        add("索尼官方 SDK", "Sony Official SDK", "ソニー公式 SDK");
        add("索尼 Camera Remote SDK 2.02.00 只提供 macOS 与 Windows 运行库；当前平台继续使用原生 Camera Remote Command 连接后端。",
                "Sony Camera Remote SDK 2.02.00 supplies runtimes only for macOS and Windows; this platform continues using its native Camera Remote Command backend.",
                "Sony Camera Remote SDK 2.02.00 のランタイムは macOS と Windows のみ提供されています。このプラットフォームではネイティブの Camera Remote Command バックエンドを継続して使用します。");
        add("连接管理", "Connection Manager", "接続管理");
        add("相机连接", "Camera Connections", "カメラ接続");
        add("本机摄像头、USB/PTP 与官方 SDK",
                "Local camera, USB/PTP, and official SDKs",
                "ローカルカメラ、USB/PTP、公式 SDK");
        add("相机控制", "Camera Control", "カメラ制御");
        add("文件接收", "File Receiving", "ファイル受信");
        add("拍摄辅助", "Capture Assistants", "撮影アシスト");
        add("蓝牙遥控与拍摄定位",
                "Bluetooth remote and capture location",
                "Bluetooth リモートと撮影位置");
        add("通用、拍摄辅助、更新、诊断与支持。",
                "General, capture assistants, updates, diagnostics, and support.",
                "一般、撮影アシスト、更新、診断、サポート。");
        add("兼容 ZENCHE BLE Remote 服务；遥控器发出快门通知后，将触发当前已连接相机。",
                "Compatible with the ZENCHE BLE Remote service. A shutter notification triggers the currently connected camera.",
                "ZENCHE BLE Remote サービスに対応し、シャッター通知で現在接続中のカメラを撮影します。");
        add("仅在应用使用期间定位；下载的照片会生成包含 GPS 信息的标准 XMP 旁车文件。",
                "Location is used only while the app is active. Downloaded photos receive a standard XMP GPS sidecar.",
                "位置情報はアプリ使用中のみ取得し、ダウンロードした写真に標準 XMP GPS サイドカーを作成します。");
        add("Wi‑Fi 相机 · PTP/IP", "Wi‑Fi Camera · PTP/IP", "Wi‑Fi カメラ · PTP/IP");
        add("连接模式", "Connection Mode", "接続モード");
        add("AP 直连", "AP Direct", "AP ダイレクト");
        add("STA 局域网", "STA LAN", "STA LAN");
        add("AP 模式：让手机加入相机热点；相机地址通常为 192.168.1.1。",
                "AP mode: Join the camera hotspot on this phone; the camera address is usually 192.168.1.1.",
                "AP モード：スマートフォンをカメラのアクセスポイントに接続します。カメラのアドレスは通常 192.168.1.1 です。");
        add("STA 模式：让相机与手机加入同一局域网，并输入路由器分配给相机的 IP 地址。",
                "STA mode: Connect the camera and phone to the same LAN, then enter the camera IP address assigned by the router.",
                "STA モード：カメラとスマートフォンを同じ LAN に接続し、ルーターがカメラに割り当てた IP アドレスを入力します。");
        add("先在相机中开启无线遥控/PTP‑IP，并让手机加入相机热点或同一局域网。默认端口为 15740。",
                "Enable wireless remote/PTP‑IP on the camera, then join its hotspot or local network on your phone. The default port is 15740.",
                "カメラでワイヤレスリモート／PTP‑IP を有効にし、スマートフォンをカメラのアクセスポイントまたは同じ LAN に接続してください。既定ポートは 15740 です。");
        add("相机 IP 地址", "Camera IP address", "カメラの IP アドレス");
        add("端口", "Port", "ポート");
        add("断开 Wi‑Fi 相机", "Disconnect Wi‑Fi Camera", "Wi‑Fi カメラを切断");
        add("连接 Wi‑Fi 相机", "Connect Wi‑Fi Camera", "Wi‑Fi カメラに接続");
        add("Wi‑Fi 相机未连接", "Wi‑Fi camera not connected", "Wi‑Fi カメラ未接続");
        add("蓝牙遥控快门", "Bluetooth Remote Shutter", "Bluetooth リモートシャッター");
        add("蓝牙遥控拍摄", "Bluetooth Remote Capture", "Bluetooth リモート撮影");
        add("蓝牙遥控未开启", "Bluetooth remote is off", "Bluetooth リモコンはオフです");
        add("拍摄定位", "Capture Location", "撮影位置");
        add("拍摄位置", "Capture Location", "撮影位置");
        add("定位未开启", "Location is off", "位置情報はオフです");
        add("拍摄文件会生成标准 XMP GPS 旁车文件",
                "Captured files receive a standard XMP GPS sidecar",
                "撮影ファイルに標準 XMP GPS サイドカーを作成します");
        add("AI 创作", "AI Create", "AI クリエイト");
        add("修图覆盖原图 · 生图保存新文件", "AI editing overwrites the original · generation saves a new file", "AI編集は元画像を上書き · 生成は新規ファイルとして保存");
        add("需要激活", "Activation required", "アクティベーションが必要");
        add("已解锁", "Unlocked", "ロック解除済み");
        add("输出参数", "Output parameters", "出力パラメータ");
        add("智能移除", "Smart Removal", "スマート除去");
        add("去路人并自然补全背景",
                "Remove passersby and naturally reconstruct the background",
                "通行人を削除し、背景を自然に補完");
        add("去穿帮并移除摄影器材、工作人员、反光与杂物",
                "Remove production artifacts, including equipment, crew, reflections, and clutter",
                "撮影機材、スタッフ、映り込み、不要物などの写り込みを除去");
        add("AI 生成超时，请稍后重试",
                "AI generation timed out. Please try again later.",
                "AI 生成がタイムアウトしました。しばらくしてから再試行してください");
        add("视频曝光模式", "Video Exposure Mode", "動画露出モード");
        add("视频快门表示", "Video Shutter Display", "動画シャッター表示");
        add("视频编码", "Video Codec", "動画コーデック");
        add("视频录制规格", "Video Recording Format", "動画記録形式");
        add("录制规格来源", "Recording Format Source", "記録形式のソース");
        add("Log / Picture Profile", "Log / Picture Profile", "Log / ピクチャープロファイル");
        add("编码", "Codec", "コーデック");
        add("N-Log 已开启", "N-Log enabled", "N-Log を有効にしました");
        add("N-Log 已关闭", "N-Log disabled", "N-Log を無効にしました");
        add("我的设备", "My Devices", "マイデバイス");
        add("管理连接过的相机，轻触即可快速重连",
                "Keep connected cameras ready for one-tap reconnection.",
                "接続済みカメラを管理し、すばやく再接続できます。");
        add("尚未连接过设备", "No Saved Devices", "保存済みデバイスはありません");
        add("成功连接相机后会自动保存在这里。",
                "Cameras are saved here automatically after a successful connection.",
                "接続に成功したカメラは自動的にここへ保存されます。");
        add("当前已连接", "Connected", "接続中");
        add("最近连接", "Last connected", "最終接続");
        add("快速连接", "Quick Connect", "クイック接続");
        add("忘记设备", "Forget Device", "デバイスを削除");
        add("生成图像", "Generate Image", "画像を生成");
        add("创建蒙版", "Create Mask", "マスクを作成");
        add("蒙版", "Mask", "マスク");
        add("蒙版列表", "Mask List", "マスク一覧");
        add("暂无蒙版", "No masks yet", "マスクはまだありません");
        add("显示", "Visible", "表示");
        add("显示蒙版", "Show Mask", "マスクを表示");
        add("隐藏蒙版", "Hide Mask", "マスクを非表示");
        add("蒙版已显示", "Mask shown", "マスクを表示しました");
        add("蒙版已隐藏", "Mask hidden", "マスクを非表示にしました");
        add("已切换蒙版", "Mask selected", "マスクを選択しました");
        add("删除蒙版", "Delete Mask", "マスクを削除");
        add("添加蒙版（画笔）", "Add to Mask (Brush)", "マスクに追加（ブラシ）");
        add("减去蒙版（画笔）", "Subtract from Mask (Brush)", "マスクから削除（ブラシ）");
        add("画笔大小", "Brush Size", "ブラシサイズ");
        add("画笔", "Brush", "ブラシ");
        add("智能识别", "Smart Selection", "スマート選択");
        add("智能主体", "Smart Subject", "スマート被写体");
        add("智能天空", "Smart Sky", "スマート空");
        add("智能背景", "Smart Background", "スマート背景");
        add("智能人物", "Smart Person", "スマート人物");
        add("智能亮部", "Smart Highlights", "スマートハイライト");
        add("智能暗部", "Smart Shadows", "スマートシャドウ");
        add("反向蒙版", "Invert Mask", "マスクを反転");
        add("蒙版内调整", "Mask Adjustments", "マスク内調整");
        add("蒙版已反向", "Mask inverted", "マスクを反転しました");
        add("蒙版已恢复正向", "Mask restored", "マスクを通常方向に戻しました");
        add("智能蒙版已创建 · 可继续添加或减去画笔",
                "Smart mask created · Refine with the add or subtract brush",
                "スマートマスクを作成しました · 追加／削除ブラシで調整できます");
        add("区域 · 可继续添加或减去画笔", " area · Refine with add or subtract brush", "領域 · 追加／削除ブラシで調整できます");
        add("蒙版已创建 · 在预览画面涂抹", "Mask created · Paint on the preview", "マスクを作成しました · プレビュー上で描画してください");
        add("蒙版已删除", "Mask deleted", "マスクを削除しました");
        add("添加蒙版画笔已启用", "Add-mask brush enabled", "追加ブラシを有効にしました");
        add("减去蒙版画笔已启用", "Subtract-mask brush enabled", "削除ブラシを有効にしました");
        add("在预览画面拖动画笔；蓝色为添加，白色为减去。", "Drag on the preview; blue adds and white subtracts.", "プレビュー上をドラッグします。青は追加、白は削除です。");
        add("蓝色显示当前蒙版覆盖；橡皮会擦除蓝色区域。",
                "Blue shows the active mask coverage; the eraser removes blue areas.",
                "青は現在のマスク範囲です。消しゴムは青い領域を消去します。");
        add("已选择原图", "Original selected", "元画像を選択済み");
        add("先创建蒙版，再选择添加或减去画笔。", "Create a mask, then choose the add or subtract brush.", "マスクを作成してから追加または削除ブラシを選択します。");
        add("次剩余", "uses remaining", "回残り");
        add("前往官网兑换密钥", "Redeem Key on Official Website", "公式サイトでキーを交換");
        add("复制设备 ID 后，前往 zenche.top 使用兑换码兑换绑定当前设备的激活密钥。",
                "Copy the device ID, then redeem a key bound to this device at zenche.top.",
                "デバイス ID をコピーし、zenche.top でこのデバイス用のキーに交換してください。");
        add("没有兑换码？在爱发电购买兑换码",
                "Need a redemption code? Buy one on Afdian",
                "交換コードをお持ちでない場合は Afdian で購入できます");
        add("在爱发电购买兑换码", "Buy Redemption Code on Afdian", "Afdian で交換コードを購入");
        add("兑换码仅用于 AI 云服务次数，帧澈本体保持免费开源。",
                "Redemption codes cover AI cloud usage only; ZENCHE remains free and open source.",
                "交換コードは AI クラウド利用分のみが対象で、ZENCHE 本体は無料・オープンソースです。");
        add("设备 ID 已复制，可前往官网兑换密钥",
                "Device ID copied. You can now redeem a key on the official website.",
                "デバイス ID をコピーしました。公式サイトでキーを交換できます。");
        add("每个激活密钥绑定当前设备，请复制上面的设备 ID 并前往官网兑换。",
                "Each activation key is bound to this device. Copy the device ID above and redeem it on the official website.",
                "各アクティベーションキーはこのデバイスに紐づきます。上のデバイス ID をコピーして公式サイトで交換してください。");
        add("恢复设备码", "Restore Device Binding", "デバイス紐付けを復元");
        add("旧设备 ID", "Previous Device ID", "以前のデバイス ID");
        add("旧激活码", "Previous Activation Key", "以前のアクティベーションキー");
        add("恢复成功后，AI 权益和剩余次数将迁移到当前设备；旧设备绑定会永久失效。",
                "A successful restore moves the AI entitlement and remaining uses to this device. The previous device binding will be permanently disabled.",
                "復元に成功すると、AI 利用権と残り回数がこのデバイスへ移行し、以前のデバイス紐付けは永久に無効になります。");
        add("恢复到当前设备", "Restore to This Device", "このデバイスへ復元");
        add("正在迁移…", "Migrating…", "移行中…");
        add("请输入旧设备 ID 和旧激活码",
                "Enter the previous device ID and activation key.",
                "以前のデバイス ID とアクティベーションキーを入力してください。");
        add("旧设备 ID 与旧激活码不匹配或已过期",
                "The previous device ID and activation key do not match or have expired.",
                "以前のデバイス ID とアクティベーションキーが一致しないか、有効期限が切れています。");
        add("服务器返回的新激活码验证失败，未修改本机数据",
                "The new activation key returned by the server failed verification. Local data was not changed.",
                "サーバーから返された新しいキーを検証できませんでした。ローカルデータは変更していません。");
        add("设备码恢复成功，AI 权益已迁移到当前设备",
                "Device binding restored. The AI entitlement is now on this device.",
                "デバイス紐付けを復元し、AI 利用権をこのデバイスへ移行しました。");
        add("设备码恢复失败：", "Device binding restore failed: ", "デバイス紐付けの復元に失敗しました：");
        add("设备码恢复地址无效", "The device binding restore endpoint is invalid.", "デバイス紐付け復元先が無効です。");
        add("设备码恢复响应过大", "The device binding restore response is too large.", "デバイス紐付け復元の応答が大きすぎます。");
        add("设备码恢复响应无效", "The device binding restore response is invalid.", "デバイス紐付け復元の応答が無効です。");
        add("无法保存迁移后的激活码", "Unable to save the migrated activation key.", "移行後のアクティベーションキーを保存できません。");
        add("网络连接失败", "Network connection failed.", "ネットワーク接続に失敗しました。");
        add("语言更改会立即应用，并在下次启动时保留。",
                "Language changes apply immediately and are remembered for the next launch.",
                "言語の変更はすぐに適用され、次回起動時にも保持されます。");
        add("快门、曝光、对焦、白平衡与拍摄模式集中在当前页面",
                "Shutter, exposure, focus, white balance, and shooting mode in one place",
                "シャッター、露出、フォーカス、ホワイトバランス、撮影モードを一画面で操作");
        add("会话、曝光、对焦与交付按拍摄流程组织",
                "Session, exposure, focus, and delivery follow the capture workflow",
                "セッション、露出、フォーカス、納品を撮影フローに沿って整理");
        add("拍前会话与交付", "Session & Delivery", "撮影前セッションと納品");
        add("拍摄控制", "Capture Controls", "撮影コントロール");
        add("对焦与色彩", "Focus & Color", "フォーカスとカラー");
        add("拍摄自动化", "Capture Automation", "撮影オートメーション");
        add("间隔、包围与 B 门任务集中管理",
                "Manage interval, bracketing, and Bulb tasks together",
                "インターバル、ブラケット、バルブをまとめて管理");
        add("连接相机后显示当前机型与实时画面",
                "Connect a camera to show its model and live view",
                "カメラを接続すると機種名とライブビューを表示");
        add("原生 USB/PTP 相机", "Native USB/PTP Camera", "ネイティブ USB/PTP カメラ");
        add("连接后自动识别当前机型与可用参数",
                "Automatically identify the camera and available controls after connection",
                "接続後にカメラと利用可能な設定を自動認識");
        add("请作者喝杯奶茶，支持后续维护与新机型适配。",
                "Support ongoing maintenance and compatibility with more camera models.",
                "継続的なメンテナンスと新しいカメラへの対応をご支援ください。");
        add("打开微信扫一扫，感谢支持。",
                "Scan with WeChat. Thank you for your support.",
                "WeChat でスキャンしてください。ご支援ありがとうございます。");
        add("爱发电赞助", "Afdian Support", "Afdian で支援");
        add("扫描二维码，或打开爱发电主页支持项目。",
                "Scan the QR code or open the Afdian page to support the project.",
                "QR コードを読み取るか、Afdian ページを開いてプロジェクトを支援できます。");
        add("快速问题反馈",
                "Faster Problem Feedback",
                "より迅速な問題フィードバック");
        add("公开问题可继续在 GitHub 免费提交；在爱发电赞助后，可获取快速问题反馈渠道。",
                "Public issues remain free on GitHub. Afdian sponsors can access a faster feedback channel.",
                "公開 Issue は引き続き GitHub から無料で送信できます。Afdian で支援すると、より迅速なフィードバック窓口を利用できます。");
        add("官方 QQ 群：165315727",
                "Official QQ group: 165315727",
                "公式 QQ グループ：165315727");
        add("打开爱发电", "Open Afdian", "Afdian を開く");
        add("赞助不会解锁软件功能，也不影响公开 Issue 的处理。",
                "Sponsorship does not unlock app features or affect public issue handling.",
                "支援によってアプリ機能が解除されたり、公開 Issue の対応が変わったりすることはありません。");
        add("软件功能永久免费，赞助为自愿行为。",
                "App features remain free; sponsorship is voluntary.",
                "アプリの機能は無料のままで、ご支援は任意です。");
        add("更新公告", "What's New", "アップデートのお知らせ");
        add("本次更新", "In This Update", "今回の更新");
        add("• 修复 AI 修图原图链路：客户端发送当前选中照片的完整 data:image 数据，代理按上游要求放入 images 并等待任务完成，修图结果真正基于原图。\n"
                        + "• AI 修图成功后覆盖当前原图并保留文件记录；AI 生图仍保存为新文件，避免混淆。\n"
                        + "• AI 次数由服务器统一扣减并回传剩余次数；失败请求自动回滚，不再出现调用未扣次数。\n"
                        + "• 继续保留设备码绑定、官网兑换、爱发电购买提示和防诈骗说明。\n"
                        + "• 优化 Nikon / Sony / Canon 相机识别、PTP 拍摄与专业编辑稳定性。\n"
                        + "• iOS / iPadOS、Android、HarmonyOS、macOS、Windows 五端同步更新。",
                "• Fixed the AI photo-editing reference-image path: the selected photo is sent as a complete data URL, the proxy forwards it in the upstream images array, and waits for the task result so edits are based on the original.\n"
                        + "• Successful AI retouching overwrites the current original while preserving library records; AI generation still saves a new file.\n"
                        + "• AI usage is deducted by the server and the remaining count is returned; failed requests roll back, preventing missing quota deductions.\n"
                        + "• Kept device-bound activation, official redemption, Afdian purchase guidance, and scam warnings.\n"
                        + "• Improved Nikon / Sony / Canon camera detection, PTP capture, and professional editor stability.\n"
                        + "• Synchronized the update across iOS / iPadOS, Android, HarmonyOS, macOS, and Windows.",
                "• AI 写真編集の参照画像経路を修正。選択した写真を完全な data URL として送り、プロキシが上流の images 配列へ転送してタスク完了まで待機するため、編集結果が元画像に基づくようになりました。\n"
                        + "• AI レタッチ成功時は現在の元画像を上書きし、ライブラリ記録を保持します。AI 生成は新規ファイルとして保存します。\n"
                        + "• AI 利用回数はサーバーで減算し、残り回数を返します。失敗したリクエストはロールバックされ、回数が減らない問題を防ぎます。\n"
                        + "• デバイス紐付け認証、公式交換、Afdian 購入案内、詐欺注意を継続します。\n"
                        + "• Nikon / Sony / Canon のカメラ検出、PTP 撮影、プロ現像の安定性を改善しました。\n"
                        + "• iOS / iPadOS、Android、HarmonyOS、macOS、Windows を同時更新。");
        add("• 新增五端全局状态条：统一显示相机连接、当前操作和 ZENCHE 文件库总数。\n"
                        + "• 新增“恢复设备码”入口（服务端启用后可用）：使用旧设备码与旧激活码迁移剩余 AI 次数；成功后旧绑定永久失效。\n"
                        + "• Android USB/PTP 遇到已知异步传输故障时会自动降级，并在本次连接中复用稳定通道，减少重复等待。\n"
                        + "• 强化 AI 代理与签发服务：限制请求和响应大小、耐久保存次数、失败自动退款，并在存储异常时停止继续写入。\n"
                        + "• iOS / iPadOS、Android、HarmonyOS、macOS、Windows 五端同步更新。",
                "• Added a global status bar on all five clients for camera connection, current operation, and total ZENCHE library count.\n"
                        + "• Added Restore Device Code (available after the server is enabled): migrate remaining AI uses with the old device ID and activation code; the old binding is permanently invalidated after success.\n"
                        + "• Android USB/PTP now falls back on known asynchronous transfer failures and reuses the stable path for the current connection to avoid repeated waits.\n"
                        + "• Hardened the AI proxy and signing service with bounded payloads, durable quota writes, automatic refunds, and fail-stop behavior after storage faults.\n"
                        + "• Synchronized the update across iOS / iPadOS, Android, HarmonyOS, macOS, and Windows.",
                "• 5 つのクライアントに共通ステータスバーを追加し、カメラ接続、現在の操作、ZENCHE ライブラリ総数を表示します。\n"
                        + "• 「デバイスコードを復元」を追加（サーバー有効化後に利用可能）。旧デバイス ID と旧アクティベーションコードで AI 残回数を移行し、成功後は旧紐付けを永久に無効化します。\n"
                        + "• Android USB/PTP は既知の非同期転送障害時に自動フォールバックし、現在の接続では安定した経路を再利用して待ち時間の繰り返しを抑えます。\n"
                        + "• AI プロキシと署名サービスを強化し、データ量制限、回数の永続保存、失敗時の自動返却、ストレージ異常後の停止動作を追加しました。\n"
                        + "• iOS / iPadOS、Android、HarmonyOS、macOS、Windows を同時更新。");
        add("• 新增“外录到当前智能设备”：视频可实时写入 ZENCHE 文件库，并可与相机机身存储卡录制并行。\n"
                        + "• 新增相机机内存储管理：可浏览存储卷与文件、查看缩略图和保护状态，并批量下载或确认后永久删除。\n"
                        + "• 照片继续直接保存到当前设备；外录视频沿用会话命名、备份与 SHA‑256 完整性记录。\n"
                        + "• PTP 实时取景不含音频，Android、HarmonyOS、macOS 与 Windows 外录为无声 Motion‑JPEG AVI；iOS / iPadOS 本机与 UVC 源外录为 MOV。\n"
                        + "• 停止录制、断开相机或发生写入异常时会安全封装已写入的视频，减少素材损失。\n"
                        + "• iOS / iPadOS、Android、HarmonyOS、macOS、Windows 五端同步更新。",
                "• Added “Record to This Smart Device”: video can be written live to the ZENCHE library alongside in-camera card recording.\n"
                        + "• Added in-camera storage management with volume and file browsing, thumbnails, protection state, batch download, and confirmed permanent deletion.\n"
                        + "• Photos continue to save directly to this device; external video keeps session naming, backups, and SHA-256 integrity records.\n"
                        + "• PTP live view contains no audio. Android, HarmonyOS, macOS, and Windows record silent Motion-JPEG AVI; local and UVC sources on iOS / iPadOS record MOV.\n"
                        + "• Stopping, disconnecting the camera, or encountering a write error safely finalizes the recorded video to reduce footage loss.\n"
                        + "• Synchronized the update across iOS / iPadOS, Android, HarmonyOS, macOS, and Windows.",
                "• 「このスマートデバイスへ外部収録」を追加。動画を ZENCHE ライブラリへリアルタイム保存し、カメラ内カード記録と併用できます。\n"
                        + "• カメラ内ストレージ管理を追加。ストレージとファイルの参照、サムネイル、保護状態、一括ダウンロード、確認付き完全削除に対応します。\n"
                        + "• 写真は引き続きこのデバイスへ直接保存。外部収録動画にはセッション命名、バックアップ、SHA-256 整合性記録を適用します。\n"
                        + "• PTP ライブビューに音声は含まれません。Android、HarmonyOS、macOS、Windows は無音の Motion-JPEG AVI、iOS / iPadOS のローカル／UVC ソースは MOV で収録します。\n"
                        + "• 収録停止、カメラ切断、書き込みエラー時も記録済み動画を安全に確定し、素材損失を抑えます。\n"
                        + "• iOS / iPadOS、Android、HarmonyOS、macOS、Windows を同時更新。");
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
        add("来源", "Source", "入力");
        add("模式", "Mode", "モード");
        add("快门", "Shutter", "シャッター");
        add("光圈", "Aperture", "絞り");
        add("曝光补偿", "Exposure", "露出補正");
        add("自动", "Auto", "オート");
        add("照片拍摄", "Photo Capture", "写真撮影");
        add("视频监看", "Video Monitor", "動画モニター");
        add("文件与传输", "Files & Transfer", "ファイルと転送");
        add("照片", "Photos", "写真");
        add("分支", "Library", "ライブラリ");
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
        add("优先通过 Mirror酱检查更新，无可用 CDN 下载地址时自动回退 GitHub Releases。",
                "Check MirrorChyan first and fall back to GitHub Releases when no CDN download is available.",
                "MirrorChyan を優先して確認し、CDN ダウンロードがない場合は GitHub Releases に切り替えます。");
        add("Mirror酱 CDK（可选）",
                "MirrorChyan CDK (Optional)",
                "MirrorChyan CDK（任意）");
        add("CDK 使用 Android Keystore 加密保存，不会写入诊断日志。",
                "The CDK is encrypted with Android Keystore and is never written to diagnostic logs.",
                "CDK は Android Keystore で暗号化され、診断ログには記録されません。");
        add("保存 CDK", "Save CDK", "CDK を保存");
        add("打开 Mirror酱", "Open MirrorChyan", "MirrorChyan を開く");
        add("Mirror酱 CDK 已清除",
                "MirrorChyan CDK cleared",
                "MirrorChyan CDK を消去しました");
        add("Mirror酱 CDK 已安全保存",
                "MirrorChyan CDK saved securely",
                "MirrorChyan CDK を安全に保存しました");
        add("Mirror酱 CDK 保存失败",
                "Failed to save MirrorChyan CDK",
                "MirrorChyan CDK の保存に失敗しました");
        add("Mirror酱 CDK 已过期，已回退 GitHub",
                "MirrorChyan CDK expired; using GitHub",
                "MirrorChyan CDK の期限が切れています。GitHub を使用します");
        add("Mirror酱 CDK 无效，已回退 GitHub",
                "MirrorChyan CDK is invalid; using GitHub",
                "MirrorChyan CDK が無効です。GitHub を使用します");
        add("Mirror酱今日下载额度已用完，已回退 GitHub",
                "MirrorChyan daily quota is exhausted; using GitHub",
                "MirrorChyan の本日の上限に達しました。GitHub を使用します");
        add("Mirror酱 CDK 与资源不匹配，已回退 GitHub",
                "MirrorChyan CDK does not match this resource; using GitHub",
                "MirrorChyan CDK がリソースと一致しません。GitHub を使用します");
        add("Mirror酱 CDK 已被停用，已回退 GitHub",
                "MirrorChyan CDK is disabled; using GitHub",
                "MirrorChyan CDK は無効化されています。GitHub を使用します");
        add("Mirror酱资源尚未配置，已回退 GitHub",
                "MirrorChyan resource is not configured; using GitHub",
                "MirrorChyan リソースは未設定です。GitHub を使用します");
        add("Mirror酱暂不可用，已回退 GitHub",
                "MirrorChyan is unavailable; using GitHub",
                "MirrorChyan は利用できません。GitHub を使用します");
        add("Mirror酱未返回可直接安装的完整包，已回退 GitHub",
                "MirrorChyan did not return a full installer; using GitHub",
                "MirrorChyan から完全なインストーラーが返されなかったため、GitHub を使用します");
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
        add("外录到当前智能设备",
                "Record to This Smart Device",
                "このスマートデバイスへ外部収録");
        add("生成无声 Motion‑JPEG AVI，可与机身录制并行",
                "Creates a silent Motion-JPEG AVI alongside in-camera recording",
                "無音の Motion-JPEG AVI を生成し、カメラ内記録と併用できます");
        add("外录使用实时取景生成无声 Motion‑JPEG AVI，可与机身录制并行；照片始终直接写入当前设备。",
                "External recording creates a silent Motion-JPEG AVI from live view alongside in-camera recording; photos are always written directly to this device.",
                "外部収録はライブビューから無音の Motion-JPEG AVI を生成し、カメラ内記録と併用できます。写真は常にこのデバイスへ直接保存されます。");
        add("外录已开启 · 视频将写入 ZENCHE 文件库",
                "External recording on · Video will be written to the ZENCHE library",
                "外部収録オン · 動画を ZENCHE ライブラリへ保存します");
        add("外录已关闭 · PTP 相机仅记录到机身存储卡",
                "External recording off · PTP cameras record only to the camera card",
                "外部収録オフ · PTP カメラはカメラ内カードのみに記録します");
        add("● EXT REC · 正在外录到当前智能设备",
                "● EXT REC · Recording to this smart device",
                "● EXT REC · このスマートデバイスへ外部収録中");
        add("录制已停止 · 外录文件已保存到 ZENCHE 文件库",
                "Recording stopped · External recording saved to the ZENCHE library",
                "収録停止 · 外部収録ファイルを ZENCHE ライブラリへ保存しました");
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
        add("拍摄任务", "Shooting Task", "撮影タスク");
        add("任务类型", "Task Type", "タスクの種類");
        add("间隔拍摄", "Interval Capture", "インターバル撮影");
        add("曝光包围", "Exposure Bracketing", "露出ブラケット");
        add("焦点包围", "Focus Bracketing", "フォーカスブラケット");
        add("B 门计时", "Timed Bulb", "バルブタイマー");
        add("开始任务", "Start Task", "タスクを開始");
        add("取消任务", "Cancel Task", "タスクをキャンセル");
        add("正在取消拍摄任务…", "Cancelling shooting task…", "撮影タスクをキャンセル中…");
        add("拍摄任务已取消", "Shooting task cancelled", "撮影タスクをキャンセルしました");
        add("拍摄任务失败", "Shooting task failed", "撮影タスクに失敗しました");
        add("准备中", "Preparing", "準備中");
        add("已完成", "Completed", "完了");
        add("张数", "Shots", "枚数");
        add("间隔", "Interval", "間隔");
        add("曝光时长", "Exposure Duration", "露光時間");
        add("秒", "Seconds", "秒");
        add("包围步长", "Bracket Step", "ブラケット幅");
        add("专业监看", "Professional Monitoring", "プロモニター");
        add("峰值对焦", "Focus Peaking", "フォーカスピーキング");
        add("假色曝光", "False Color", "フォルスカラー");
        add("波形", "Waveform", "波形");
        add("矢量", "Vectorscope", "ベクトルスコープ");
        add("峰值覆盖", "Peaking Coverage", "ピーキング範囲");
        add("拍摄会话", "Capture Session", "撮影セッション");
        add("项目名称", "Project Name", "プロジェクト名");
        add("命名模板", "Naming Template", "命名テンプレート");
        add("创作者", "Creator", "作成者");
        add("版权", "Rights", "著作権");
        add("默认评级", "Default Rating", "既定の評価");
        add("双目标备份", "Dual-Destination Backup", "二重保存");
        add("开始会话", "Start Session", "セッションを開始");
        add("结束会话", "End Session", "セッションを終了");
        add("配置并开始", "Configure and Start", "設定して開始");
        add("尚未开始拍摄会话", "No capture session started", "撮影セッションは未開始です");
        add("会话进行中", "Session Active", "セッション実行中");
        add("拍摄会话已结束", "Capture session ended", "撮影セッションを終了しました");
        add("编辑", "Edit", "編集");
        add("图像编辑", "Image Editor", "画像編集");
        add("分支抽屉", "Branch Drawer", "ブランチドロワー");
        add("调整亮度、对比度、饱和度与方向；保存时生成 JPEG 副本。",
                "Adjust brightness, contrast, saturation, and orientation; saving creates a JPEG copy.",
                "明るさ、コントラスト、彩度、向きを調整し、保存時に JPEG のコピーを作成します。");
        add("文件库中没有可编辑照片",
                "There are no editable photos in the library",
                "ライブラリに編集可能な写真がありません");
        add("文件库 · %lld 个文件", "Library · %lld files", "ライブラリ · %lld 件");
        add("个文件", "files", "件");
        add("未选择照片", "No photo selected", "写真が選択されていません");
        add("视频与暂不支持解码的 RAW 文件不会进入编辑列表。",
                "Videos and RAW files that cannot yet be decoded are excluded from the editor.",
                "動画と、まだデコードできない RAW ファイルは編集リストに表示されません。");
        add("亮度", "Brightness", "明るさ");
        add("对比度", "Contrast", "コントラスト");
        add("饱和度", "Saturation", "彩度");
        add("旋转 90°", "Rotate 90°", "90° 回転");
        add("重置", "Reset", "リセット");
        add("保存副本", "Save Copy", "コピーを保存");
        add("调整不会覆盖原文件",
                "Adjustments do not overwrite the original",
                "調整しても元のファイルは上書きされません");
        add("正在保存编辑副本…",
                "Saving edited copy…",
                "編集したコピーを保存中…");
        add("已保存编辑副本",
                "Saved edited copy",
                "編集したコピーを保存しました");
        add("保存编辑副本失败",
                "Failed to save the edited copy",
                "編集したコピーの保存に失敗しました");
        add("无法解码当前照片",
                "Unable to decode the current photo",
                "現在の写真をデコードできません");
        add("专业显影", "Pro Develop", "プロ現像");
        add("分组调整光线、色彩、细节、效果与几何；始终保留原文件。",
                "Adjust light, color, detail, effects, and geometry in focused groups while always preserving the original.",
                "ライト、カラー、ディテール、効果、ジオメトリをグループ別に調整し、元のファイルを常に保持します。");
        add("AI 智能修图", "AI Retouch", "AI レタッチ");
        add("设备端分析画面并生成可继续微调的专业参数；照片不会上传。",
                "Analyze the image on-device and generate professional settings you can keep refining; photos are never uploaded.",
                "デバイス上で画像を解析し、さらに微調整できるプロ設定を生成します。写真はアップロードされません。");
        add("智能优化", "Smart Enhance", "スマート補正");
        add("AI 修图工作台", "AI Retouch Workbench", "AI レタッチワークベンチ");
        add("设备端 · 不上传", "On-device · Never uploaded", "デバイス内 · アップロードなし");
        add("分析画面", "Analyze Image", "画像を解析");
        add("画面分析完成 · 可应用 AI 建议", "Analysis complete · Ready to apply AI", "解析完了 · AI 補正を適用できます");
        add("已复制 AI 调整，可应用到下一张照片", "AI settings copied; apply them to the next photo", "AI 補正をコピーしました。次の写真に適用できます");
        add("已粘贴 AI 调整", "AI settings pasted", "AI 補正を貼り付けました");
        add("曝光", "Exposure", "露出");
        add("动态范围", "Dynamic range", "ダイナミックレンジ");
        add("色彩", "Color", "カラー");
        add("细节", "Detail", "ディテール");
        add("设备端", "On-device", "デバイス内");
        add("AI 强度", "AI Strength", "AI 強度");
        add("撤销 AI", "Undo AI", "AI を元に戻す");
        add("等待分析当前照片", "Ready to analyze this photo", "この写真を解析できます");
        add("检测到画面偏暗，已提亮阴影并保护高光",
                "The image is dark; shadows were lifted while highlights were protected.",
                "暗めの画像を検出し、ハイライトを保護しながらシャドウを明るくしました。");
        add("检测到画面偏亮，已回收高光并恢复层次",
                "The image is bright; highlights were recovered to restore tonal detail.",
                "明るめの画像を検出し、ハイライトを抑えて階調を復元しました。");
        add("检测到动态范围偏平，已增强层次与色彩",
                "The tonal range is flat; depth and color were enhanced.",
                "階調がフラットなため、立体感と色彩を強調しました。");
        add("曝光均衡，已优化色彩与细节",
                "Exposure is balanced; color and detail were refined.",
                "露出は良好です。色彩とディテールを最適化しました。");
        add("已撤销 AI 优化", "AI enhancement undone", "AI 補正を元に戻しました");
        add("AI 优化已应用 · 可继续微调",
                "AI enhancement applied · Continue refining any setting",
                "AI 補正を適用しました · 各設定を引き続き調整できます");
        add("已恢复 AI 优化前的参数",
                "Restored the settings from before AI enhancement",
                "AI 補正前の設定に戻しました");
        add("无法分析当前照片", "Unable to analyze this photo", "この写真を解析できません");
        add("光线", "Light", "ライト");
        add("色彩", "Color", "カラー");
        add("细节", "Detail", "ディテール");
        add("效果", "Effects", "効果");
        add("几何", "Geometry", "ジオメトリ");
        add("曝光", "Exposure", "露光量");
        add("高光", "Highlights", "ハイライト");
        add("阴影", "Shadows", "シャドウ");
        add("白色色阶", "Whites", "白レベル");
        add("黑色色阶", "Blacks", "黒レベル");
        add("色温", "Temperature", "色温");
        add("色调", "Tint", "色かぶり補正");
        add("自然饱和度", "Vibrance", "自然な彩度");
        add("纹理", "Texture", "テクスチャ");
        add("清晰度", "Clarity", "明瞭度");
        add("锐化", "Sharpening", "シャープ");
        add("降噪", "Noise Reduction", "ノイズ軽減");
        add("去雾", "Dehaze", "かすみの除去");
        add("暗角", "Vignette", "周辺光量");
        add("裁切比例", "Crop Ratio", "切り抜き比率");
        add("原始比例", "Original Ratio", "元の比率");
        add("水平翻转", "Flip Horizontal", "左右反転");
        add("垂直翻转", "Flip Vertical", "上下反転");
        add("预设", "Preset", "プリセット");
        add("原始", "Original", "オリジナル");
        add("自然增强", "Natural Enhance", "ナチュラル補正");
        add("人像柔和", "Soft Portrait", "ソフトポートレート");
        add("风光通透", "Clear Landscape", "クリア風景");
        add("高反差黑白", "High-Contrast B&W", "ハイコントラスト白黒");
        add("查看原图", "Show Original", "元画像を表示");
        add("返回调整", "Back to Adjustments", "調整に戻る");
        add("原图", "Original", "元画像");
        add("调整后", "Adjusted", "調整後");
        add("全部重置", "Reset All", "すべてリセット");
        add("保存高质量副本",
                "Save High-Quality Copy",
                "高品質コピーを保存");
        add("已保存高质量副本",
                "Saved high-quality copy",
                "高品質コピーを保存しました");
        add("正在查看原图", "Viewing original", "元画像を表示中");
        add("相机机内存储", "In-Camera Storage", "カメラ内ストレージ");
        add("连接相机后可浏览存储卡", "Connect a camera to browse its memory card", "カメラを接続するとメモリーカードを参照できます");
        add("正在读取存储卡…", "Reading camera card…", "カメラ内カードを読み込み中…");
        add("读取完成", "Ready", "読み込み完了");
        add("读取失败", "Unable to read storage", "ストレージを読み込めません");
        add("全选", "Select All", "すべて選択");
        add("取消全选", "Deselect All", "すべての選択を解除");
        add("下载到 ZENCHE", "Download to ZENCHE", "ZENCHE へダウンロード");
        add("从相机删除", "Delete from Camera", "カメラから削除");
        add("从相机永久删除？", "Permanently delete from camera?", "カメラから完全に削除しますか？");
        add("永久删除", "Delete Permanently", "完全に削除");
        add("此操作无法撤销；已保护文件不会被选择。", "This cannot be undone. Protected files are not selected.", "この操作は取り消せません。保護されたファイルは選択されません。");
        add("正在下载", "Downloading", "ダウンロード中");
        add("已下载", "Downloaded", "ダウンロード完了");
        add("正在从相机删除…", "Deleting from camera…", "カメラから削除中…");
        add("已从相机删除", "Deleted from camera", "カメラから削除しました");
        add("受保护", "Protected", "保護済み");
        add("传输", "Transfer", "転送");
        add("对焦", "Focus", "フォーカス");
        add("色轮", "Color Wheels", "カラーホイール");
        add("曲线", "Curves", "カーブ");
        add("峰值", "Peaking", "ピーキング");
        add("假色", "False Color", "フォルスカラー");
        add("本机摄像头", "Local Camera", "内蔵カメラ");
        add("Wi‑Fi 相机", "Wi‑Fi Camera", "Wi‑Fi カメラ");
        add("媒体池", "Media Pool", "メディアプール");
        add("工具轨", "Tool Rail", "ツールレール");
        add("编辑示波器", "Editor Scopes", "編集スコープ");
        add("检查器", "Inspector", "インスペクタ");
        add("可编辑照片", "Editable Photos", "編集可能な写真");
        add("非破坏编辑 · 保存为高质量副本",
                "Non-destructive editing · Save a high-quality copy",
                "非破壊編集 · 高品質コピーとして保存");
        add("运行“分析画面”后显示实测范围",
                "Run Analyze Image to show measured ranges",
                "「画像を解析」を実行すると実測範囲を表示");
        add("分析后显示实测范围",
                "Analyze to show measured ranges",
                "解析後に実測範囲を表示");
        add("调整始终写入新副本，原文件保持不变。",
                "Adjustments are always written to a new copy; the original stays untouched.",
                "調整は常に新しいコピーへ保存され、元のファイルは変更されません。");
        add("• 全屏监看改为影像优先的专业 HUD：顶部遥测、焦点十字、工具轨、真实 RGB 示波器与静音音频基线、底部参数托盘。\n"
                        + "• 参数与拍摄页重构为设备摘要、自适应参数卡和常驻拍摄操作区，连接、输出和文件库状态一屏可见。\n"
                        + "• 编辑器改为媒体池、中央预览、工具检查器和分析示波器协作布局；所有调整继续非破坏保存为新副本。\n"
                        + "• 统一五端深色工作台视觉：ZENCHE 蓝用于主操作，暖金只标示参数读数，红色只用于录制与危险操作。\n"
                        + "• iOS / iPadOS、Android、HarmonyOS、macOS、Windows 五端同步更新；相机、AI 与传输能力保持兼容。",
                "• Full-screen monitoring now uses an image-first professional HUD with top telemetry, a focus reticle, tool rail, real RGB scopes, an explicit silent-audio baseline, and a bottom parameter tray.\n"
                        + "• Capture and controls now combine a device summary, adaptive parameter cards, and a persistent capture dock so connection, output, and library state stay visible.\n"
                        + "• The editor now coordinates a media pool, central preview, tool inspector, and analysis scopes; every adjustment still saves non-destructively as a new copy.\n"
                        + "• A unified dark studio system spans all five clients: ZENCHE blue marks primary actions, warm gold is reserved for parameter readouts, and red is reserved for recording and destructive actions.\n"
                        + "• iOS / iPadOS, Android, HarmonyOS, macOS, and Windows are updated together while camera, AI, and transfer capabilities remain compatible.",
                "• フルスクリーンモニターを映像優先のプロ HUD へ刷新。上部テレメトリ、フォーカスレティクル、ツールレール、実測 RGB スコープ、無音オーディオ基準線、下部パラメータトレイを配置しました。\n"
                        + "• 撮影・設定画面をデバイス概要、可変パラメータカード、常設撮影ドックで再構成し、接続、出力、ライブラリ状態を一画面で確認できます。\n"
                        + "• エディタはメディアプール、中央プレビュー、ツールインスペクタ、解析スコープが連携する構成へ刷新。すべての調整は引き続き非破壊で新しいコピーへ保存します。\n"
                        + "• 5 クライアントで共通のダークスタジオ表現を採用。ZENCHE ブルーは主要操作、ウォームゴールドはパラメータ値、赤は収録と危険操作に限定します。\n"
                        + "• iOS / iPadOS、Android、HarmonyOS、macOS、Windows を同時更新し、カメラ、AI、転送機能の互換性を維持します。");
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
