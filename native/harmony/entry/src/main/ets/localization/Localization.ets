export const LANGUAGE_SIMPLIFIED_CHINESE: string = 'zh-Hans';
export const LANGUAGE_ENGLISH: string = 'en';
export const LANGUAGE_JAPANESE: string = 'ja';
export const LANGUAGE_PREFERENCE_KEY: string = 'appLanguage';

class TranslationEntry {
  readonly chinese: string;
  readonly english: string;
  readonly japanese: string;

  constructor(chinese: string, english: string, japanese: string) {
    this.chinese = chinese;
    this.english = english;
    this.japanese = japanese;
  }
}

const TRANSLATIONS: Array<TranslationEntry> = [
  new TranslationEntry('实时监看', 'Live Monitoring', 'ライブモニター'),
  new TranslationEntry('显示相机实时画面', 'Show the live camera feed', 'カメラのライブ映像を表示'),
  new TranslationEntry('实时监看已关闭', 'Live monitoring is off', 'ライブモニターはオフです'),
  new TranslationEntry(
    '打开开关即可恢复实时画面',
    'Turn on the switch to restore the live feed',
    'スイッチをオンにするとライブ映像を再開します'
  ),
  new TranslationEntry('尼康云创', 'Nikon Imaging Cloud', 'Nikon Imaging Cloud'),
  new TranslationEntry('尼康云创预览', 'Nikon Imaging Cloud Preview', 'Nikon Imaging Cloud プレビュー'),
  new TranslationEntry('选择尼康云创预设', 'Choose a Nikon Cloud Preset', 'Nikon Cloud プリセットを選択'),
  new TranslationEntry('关闭云创预览', 'Disable Cloud Preview', 'Cloud プレビューを無効化'),
  new TranslationEntry('尼康云创预览已关闭', 'Nikon cloud preview disabled', 'Nikon Cloud プレビューを無効にしました'),
  new TranslationEntry(
    '设备端 SDR 近似预览 · 相机与 NX Studio 成片可能不同',
    'On-device approximate SDR preview · Camera and NX Studio output may differ',
    'デバイス上の SDR 近似プレビュー · カメラ／NX Studio の出力とは異なる場合があります'
  ),
  new TranslationEntry('尼康云创监看', 'Nikon Imaging Cloud Monitor', 'Nikon Imaging Cloud モニター'),
  new TranslationEntry('关闭云创监看', 'Disable Cloud Monitor', 'Cloud モニターを無効化'),
  new TranslationEntry(
    '尼康云创监看已关闭',
    'Nikon Imaging Cloud monitor disabled',
    'Nikon Imaging Cloud モニターを無効にしました'
  ),
  new TranslationEntry(
    '照片与视频实时生效 · SDR 近似 · 不写入原片',
    'Live on photo and video monitoring · Approximate SDR · Originals unchanged',
    '写真・動画モニターへリアルタイム適用 · SDR 近似 · オリジナルは変更されません'
  ),
  new TranslationEntry('选择预设', 'Choose Preset', 'プリセットを選択'),
  new TranslationEntry('搜索云创预设', 'Search Cloud Presets', 'Cloud プリセットを検索'),
  new TranslationEntry('已关闭', 'Off', 'オフ'),
  new TranslationEntry('应用', 'Apply', '適用'),
  new TranslationEntry(
    '107 款设备端 SDR 预设',
    '107 on-device SDR presets',
    'デバイス上の SDR プリセット 107 種類'
  ),
  new TranslationEntry(
    '选择尼康云创监看预设',
    'Choose Nikon Imaging Cloud monitor preset',
    'Nikon Imaging Cloud モニタープリセットを選択'
  ),
  new TranslationEntry('尼康官方 SDK', 'Nikon Official SDK', 'ニコン公式 SDK'),
  new TranslationEntry(
    '官方桌面 SDK 不提供当前平台运行库',
    'The official desktop SDK has no runtime for this platform',
    '公式デスクトップ SDK はこのプラットフォーム向けランタイムを提供していません'
  ),
  new TranslationEntry(
    '尼康只为 macOS 与 Windows 提供本次 SDK 运行库；当前平台继续使用原生相机连接后端。',
    'Nikon supplies these SDK runtimes only for macOS and Windows; this platform continues using its native camera connection backend.',
    '今回の SDK ランタイムは macOS と Windows のみ提供されています。このプラットフォームではネイティブのカメラ接続バックエンドを継続して使用します。'
  ),
  new TranslationEntry('索尼官方 SDK', 'Sony Official SDK', 'ソニー公式 SDK'),
  new TranslationEntry(
    '索尼 Camera Remote SDK 2.02.00 只提供 macOS 与 Windows 运行库；当前平台继续使用原生 Camera Remote Command 连接后端。',
    'Sony Camera Remote SDK 2.02.00 supplies runtimes only for macOS and Windows; this platform continues using its native Camera Remote Command backend.',
    'Sony Camera Remote SDK 2.02.00 のランタイムは macOS と Windows のみ提供されています。このプラットフォームではネイティブの Camera Remote Command バックエンドを継続して使用します。'
  ),
  new TranslationEntry('连接管理', 'Connection Manager', '接続管理'),
  new TranslationEntry('相机连接', 'Camera Connections', 'カメラ接続'),
  new TranslationEntry(
    '本机摄像头、USB/PTP 与官方 SDK',
    'Local camera, USB/PTP, and official SDKs',
    'ローカルカメラ、USB/PTP、公式 SDK'
  ),
  new TranslationEntry('相机控制', 'Camera Control', 'カメラ制御'),
  new TranslationEntry('文件接收', 'File Receiving', 'ファイル受信'),
  new TranslationEntry('拍摄辅助', 'Capture Assistants', '撮影アシスト'),
  new TranslationEntry(
    '蓝牙遥控与拍摄定位',
    'Bluetooth remote and capture location',
    'Bluetooth リモートと撮影位置'
  ),
  new TranslationEntry(
    '通用、拍摄辅助、更新、诊断与支持。',
    'General, capture assistants, updates, diagnostics, and support.',
    '一般、撮影アシスト、更新、診断、サポート。'
  ),
  new TranslationEntry(
    '兼容 ZENCHE BLE Remote 服务；遥控器发出快门通知后，将触发当前已连接相机。',
    'Compatible with the ZENCHE BLE Remote service. A shutter notification triggers the currently connected camera.',
    'ZENCHE BLE Remote サービスに対応し、シャッター通知で現在接続中のカメラを撮影します。'
  ),
  new TranslationEntry(
    '仅在应用使用期间定位；下载的照片会生成包含 GPS 信息的标准 XMP 旁车文件。',
    'Location is used only while the app is active. Downloaded photos receive a standard XMP GPS sidecar.',
    '位置情報はアプリ使用中のみ取得し、ダウンロードした写真に標準 XMP GPS サイドカーを作成します。'
  ),
  new TranslationEntry('相机连接与拍摄辅助', 'Camera Connections & Capture Aids', 'カメラ接続と撮影支援'),
  new TranslationEntry('USB、Wi‑Fi PTP/IP、蓝牙快门与拍摄位置', 'USB, Wi‑Fi PTP/IP, Bluetooth shutter, and capture location', 'USB、Wi‑Fi PTP/IP、Bluetooth シャッター、撮影位置'),
  new TranslationEntry('Wi‑Fi 相机 · PTP/IP', 'Wi‑Fi Camera · PTP/IP', 'Wi‑Fi カメラ · PTP/IP'),
  new TranslationEntry('连接模式', 'Connection Mode', '接続モード'),
  new TranslationEntry('AP 直连', 'AP Direct', 'AP ダイレクト'),
  new TranslationEntry('STA 局域网', 'STA LAN', 'STA LAN'),
  new TranslationEntry('AP 模式：让设备加入相机热点；相机地址通常为 192.168.1.1。', 'AP mode: Join the camera hotspot on this device; the camera address is usually 192.168.1.1.', 'AP モード：この端末をカメラのアクセスポイントに接続します。カメラのアドレスは通常 192.168.1.1 です。'),
  new TranslationEntry('STA 模式：让相机与设备加入同一局域网，并输入路由器分配给相机的 IP 地址。', 'STA mode: Connect the camera and this device to the same LAN, then enter the camera IP address assigned by the router.', 'STA モード：カメラとこの端末を同じ LAN に接続し、ルーターがカメラに割り当てた IP アドレスを入力します。'),
  new TranslationEntry('请先让设备加入相机热点；默认 PTP/IP 端口为 15740。', 'Join the camera hotspot first. The default PTP/IP port is 15740.', '先にデバイスをカメラのアクセスポイントへ接続してください。PTP/IP の既定ポートは 15740 です。'),
  new TranslationEntry('蓝牙遥控拍摄', 'Bluetooth Remote Capture', 'Bluetooth リモート撮影'),
  new TranslationEntry('拍摄位置', 'Capture Location', '撮影位置'),
  new TranslationEntry('拍摄时写入同名 XMP GPS，不在后台持续定位。', 'Writes GPS to a matching XMP sidecar at capture time; no continuous background location.', '撮影時に同名の XMP へ GPS を記録し、バックグラウンドで継続測位しません。'),
  new TranslationEntry('Live 图', 'Live Photo', 'ライブフォト'),
  new TranslationEntry('快门时附带最近 N 秒取景切片，与照片同 base 配对。', 'Attaches the last N seconds of viewfinder frames at shutter time, paired with the photo under the same base name.', 'シャッター時に最新 N 秒分のファインダー映像を添付し、写真と同じベース名でペアリングします。'),
  new TranslationEntry('切片时长', 'Clip Length', 'クリップ長'),
  new TranslationEntry('1 秒', '1s', '1秒'),
  new TranslationEntry('3 秒', '3s', '3秒'),
  new TranslationEntry('5 秒', '5s', '5秒'),
  new TranslationEntry('10 秒', '10s', '10秒'),
  new TranslationEntry('15 秒', '15s', '15秒'),
  new TranslationEntry('合成延时视频', 'Compose Timelapse', 'タイムラプス合成'),
  new TranslationEntry(
    '选择序列帧（按文件名排序合成）并设置帧率。损坏帧自动跳过。',
    'Select frames (composed in filename order) and set the frame rate. Corrupt frames are skipped automatically.',
    'フレームを選択（ファイル名順で合成）しフレームレートを設定します。破損フレームは自動的にスキップされます。'
  ),
  new TranslationEntry('帧率：', 'Frame rate: ', 'フレームレート：'),
  new TranslationEntry('开始合成', 'Start', '合成開始'),
  new TranslationEntry('正在合成…', 'Composing…', '合成中…'),
  new TranslationEntry('焦点合成', 'Focus Stack', 'フォーカス合成'),
  new TranslationEntry(
    '选择焦点包围序列帧（按文件名排序合成，逐像素取最清晰帧融合）。损坏帧自动跳过。',
    'Select focus-bracketed frames (composed in filename order; the sharpest pixel from each is fused). Corrupt frames are skipped automatically.',
    '焦点ブラケットのフレームを選択（ファイル名順で合成、各ピクセルで最もシャープなフレームを融合）。破損フレームは自動的にスキップされます。'
  ),
  new TranslationEntry('Wi‑Fi 相机未连接', 'Wi‑Fi camera not connected', 'Wi‑Fi カメラ未接続'),
  new TranslationEntry('蓝牙遥控未开启', 'Bluetooth remote is off', 'Bluetooth リモコンはオフです'),
  new TranslationEntry('定位未开启', 'Location is off', '位置情報はオフです'),
  new TranslationEntry('AI 创作', 'AI Create', 'AI クリエイト'),
  new TranslationEntry('修图覆盖原图 · 生图保存新文件', 'AI editing overwrites the original · generation saves a new file', 'AI編集は元画像を上書き · 生成は新規ファイルとして保存'),
  new TranslationEntry('需要激活', 'Activation required', 'アクティベーションが必要'),
  new TranslationEntry('已解锁', 'Unlocked', 'ロック解除済み'),
  new TranslationEntry('输出参数', 'Output parameters', '出力パラメータ'),
  new TranslationEntry('视频曝光模式', 'Video Exposure Mode', '動画露出モード'),
  new TranslationEntry('视频快门表示', 'Video Shutter Display', '動画シャッター表示'),
  new TranslationEntry('视频编码', 'Video Codec', '動画コーデック'),
  new TranslationEntry('视频录制规格', 'Video Recording Format', '動画記録形式'),
  new TranslationEntry('录制规格来源', 'Recording Format Source', '記録形式のソース'),
  new TranslationEntry('Log / Picture Profile', 'Log / Picture Profile', 'Log / ピクチャープロファイル'),
  new TranslationEntry('编码', 'Codec', 'コーデック'),
  new TranslationEntry('N-Log 已开启', 'N-Log enabled', 'N-Log を有効にしました'),
  new TranslationEntry('N-Log 已关闭', 'N-Log disabled', 'N-Log を無効にしました'),
  new TranslationEntry('外录到当前智能设备', 'Record to This Smart Device', 'このスマートデバイスへ外部収録'),
  new TranslationEntry(
    '生成无声 Motion‑JPEG AVI，可与机身录制并行',
    'Creates a silent Motion-JPEG AVI alongside in-camera recording',
    '無音の Motion-JPEG AVI を生成し、カメラ内記録と併用できます'
  ),
  new TranslationEntry(
    '外录已开启 · 视频将写入 ZENCHE 文件库',
    'External recording on · Video will be written to the ZENCHE library',
    '外部収録オン · 動画を ZENCHE ライブラリへ保存します'
  ),
  new TranslationEntry(
    '外录已关闭 · PTP 相机仅记录到机身存储卡',
    'External recording off · PTP cameras record only to the camera card',
    '外部収録オフ · PTP カメラはカメラ内カードのみに記録します'
  ),
  new TranslationEntry(
    '● EXT REC · 正在外录到当前智能设备',
    '● EXT REC · Recording to this smart device',
    '● EXT REC · このスマートデバイスへ外部収録中'
  ),
  new TranslationEntry(
    '录制已停止 · 外录文件已保存到 ZENCHE 文件库',
    'Recording stopped · External recording saved to the ZENCHE library',
    '収録停止 · 外部収録ファイルを ZENCHE ライブラリへ保存しました'
  ),
  new TranslationEntry('生成图像', 'Generate Image', '画像を生成'),
  new TranslationEntry('创建蒙版', 'Create Mask', 'マスクを作成'),
  new TranslationEntry('蒙版', 'Mask', 'マスク'),
  new TranslationEntry('蒙版列表', 'Mask List', 'マスク一覧'),
  new TranslationEntry('暂无蒙版', 'No masks yet', 'マスクはまだありません'),
  new TranslationEntry('显示', 'Visible', '表示'),
  new TranslationEntry('显示蒙版', 'Show Mask', 'マスクを表示'),
  new TranslationEntry('隐藏蒙版', 'Hide Mask', 'マスクを非表示'),
  new TranslationEntry('蒙版已显示', 'Mask shown', 'マスクを表示しました'),
  new TranslationEntry('蒙版已隐藏', 'Mask hidden', 'マスクを非表示にしました'),
  new TranslationEntry('已切换蒙版', 'Mask selected', 'マスクを選択しました'),
  new TranslationEntry('删除蒙版', 'Delete Mask', 'マスクを削除'),
  new TranslationEntry('添加蒙版（画笔）', 'Add to Mask (Brush)', 'マスクに追加（ブラシ）'),
  new TranslationEntry('减去蒙版（画笔）', 'Subtract from Mask (Brush)', 'マスクから削除（ブラシ）'),
  new TranslationEntry('画笔大小', 'Brush Size', 'ブラシサイズ'),
  new TranslationEntry('画笔', 'Brush', 'ブラシ'),
  new TranslationEntry('智能识别', 'Smart Selection', 'スマート選択'),
  new TranslationEntry('智能主体', 'Smart Subject', 'スマート被写体'),
  new TranslationEntry('智能天空', 'Smart Sky', 'スマート空'),
  new TranslationEntry('智能背景', 'Smart Background', 'スマート背景'),
  new TranslationEntry('智能人物', 'Smart Person', 'スマート人物'),
  new TranslationEntry('智能亮部', 'Smart Highlights', 'スマートハイライト'),
  new TranslationEntry('智能暗部', 'Smart Shadows', 'スマートシャドウ'),
  new TranslationEntry('反向蒙版', 'Invert Mask', 'マスクを反転'),
  new TranslationEntry('蒙版内调整', 'Mask Adjustments', 'マスク内調整'),
  new TranslationEntry('蒙版已反向', 'Mask inverted', 'マスクを反転しました'),
  new TranslationEntry('蒙版已恢复正向', 'Mask restored', 'マスクを通常方向に戻しました'),
  new TranslationEntry('智能蒙版已创建 · 可继续添加或减去画笔', 'Smart mask created · Refine with the add or subtract brush', 'スマートマスクを作成しました · 追加／削除ブラシで調整できます'),
  new TranslationEntry('蒙版预览生成失败，请重试', 'Mask preview failed. Try again.', 'マスクプレビューに失敗しました。再試行してください。'),
  new TranslationEntry('区域 · 可继续添加或减去画笔', ' area · Refine with add or subtract brush', '領域 · 追加／削除ブラシで調整できます'),
  new TranslationEntry('蒙版已创建 · 在预览画面涂抹', 'Mask created · Paint on the preview', 'マスクを作成しました · プレビュー上で描画してください'),
  new TranslationEntry('蒙版已删除', 'Mask deleted', 'マスクを削除しました'),
  new TranslationEntry('添加蒙版画笔已启用', 'Add-mask brush enabled', '追加ブラシを有効にしました'),
  new TranslationEntry('减去蒙版画笔已启用', 'Subtract-mask brush enabled', '削除ブラシを有効にしました'),
  new TranslationEntry('在预览画面拖动画笔；蓝色为添加，白色为减去。', 'Drag on the preview; blue adds and white subtracts.', 'プレビュー上をドラッグします。青は追加、白は削除です。'),
  new TranslationEntry('先创建蒙版，再选择添加或减去画笔。', 'Create a mask, then choose the add or subtract brush.', 'マスクを作成してから追加または削除ブラシを選択します。'),
  new TranslationEntry('次剩余', 'uses remaining', '回残り'),
  new TranslationEntry(
    '前往官网兑换密钥',
    'Redeem Key on Official Website',
    '公式サイトでキーを交換'
  ),
  new TranslationEntry(
    '复制设备 ID 后，前往 zenche.top 使用兑换码兑换绑定当前设备的激活密钥。',
    'Copy the device ID, then redeem a key bound to this device at zenche.top.',
    'デバイス ID をコピーし、zenche.top でこのデバイス用のキーに交換してください。'
  ),
  new TranslationEntry(
    '没有兑换码？在爱发电购买兑换码',
    'Need a redemption code? Buy one on Afdian',
    '交換コードをお持ちでない場合は Afdian で購入できます'
  ),
  new TranslationEntry(
    '在爱发电购买兑换码',
    'Buy Redemption Code on Afdian',
    'Afdian で交換コードを購入'
  ),
  new TranslationEntry(
    '兑换码仅用于 AI 云服务次数，帧澈本体保持免费开源。',
    'Redemption codes cover AI cloud usage only; ZENCHE remains free and open source.',
    '交換コードは AI クラウド利用分のみが対象で、ZENCHE 本体は無料・オープンソースです。'
  ),
  new TranslationEntry(
    '设备 ID 已复制，可前往官网兑换密钥',
    'Device ID copied. You can now redeem a key on the official website.',
    'デバイス ID をコピーしました。公式サイトでキーを交換できます。'
  ),
  new TranslationEntry(
    '每个激活密钥绑定当前设备，请复制上面的设备 ID 并前往官网兑换。',
    'Each activation key is bound to this device. Copy the device ID above and redeem it on the official website.',
    '各アクティベーションキーはこのデバイスに紐づきます。上のデバイス ID をコピーして公式サイトで交換してください。'
  ),
  new TranslationEntry('恢复设备码', 'Restore Device Binding', 'デバイス紐付けを復元'),
  new TranslationEntry('旧设备 ID', 'Previous Device ID', '以前のデバイス ID'),
  new TranslationEntry('旧激活码', 'Previous Activation Key', '以前のアクティベーションキー'),
  new TranslationEntry(
    '恢复成功后，AI 权益和剩余次数将迁移到当前设备；旧设备绑定会永久失效。',
    'A successful restore moves the AI entitlement and remaining uses to this device. The previous device binding will be permanently disabled.',
    '復元に成功すると、AI 利用権と残り回数がこのデバイスへ移行し、以前のデバイス紐付けは永久に無効になります。'
  ),
  new TranslationEntry('恢复到当前设备', 'Restore to This Device', 'このデバイスへ復元'),
  new TranslationEntry('正在迁移…', 'Migrating…', '移行中…'),
  new TranslationEntry(
    '请输入旧设备 ID 和旧激活码',
    'Enter the previous device ID and activation key.',
    '以前のデバイス ID とアクティベーションキーを入力してください。'
  ),
  new TranslationEntry(
    '旧设备 ID 与旧激活码不匹配或已过期',
    'The previous device ID and activation key do not match or have expired.',
    '以前のデバイス ID とアクティベーションキーが一致しないか、有効期限が切れています。'
  ),
  new TranslationEntry(
    '服务器返回的新激活码验证失败，未修改本机数据',
    'The new activation key returned by the server failed verification. Local data was not changed.',
    'サーバーから返された新しいキーを検証できませんでした。ローカルデータは変更していません。'
  ),
  new TranslationEntry(
    '设备码恢复成功，AI 权益已迁移到当前设备',
    'Device binding restored. The AI entitlement is now on this device.',
    'デバイス紐付けを復元し、AI 利用権をこのデバイスへ移行しました。'
  ),
  new TranslationEntry('设备码恢复失败：', 'Device binding restore failed: ', 'デバイス紐付けの復元に失敗しました：'),
  new TranslationEntry('设备码恢复地址无效', 'The device binding restore endpoint is invalid.', 'デバイス紐付け復元先が無効です。'),
  new TranslationEntry('设备码恢复响应过大', 'The device binding restore response is too large.', 'デバイス紐付け復元の応答が大きすぎます。'),
  new TranslationEntry('设备码恢复响应无效', 'The device binding restore response is invalid.', 'デバイス紐付け復元の応答が無効です。'),
  new TranslationEntry('网络连接失败', 'Network connection failed.', 'ネットワーク接続に失敗しました。'),
  new TranslationEntry(
    '拍前会话与交付',
    'Session & Delivery',
    '撮影前セッションと納品'
  ),
  new TranslationEntry(
    '拍摄控制',
    'Capture Controls',
    '撮影コントロール'
  ),
  new TranslationEntry(
    '对焦与色彩',
    'Focus & Color',
    'フォーカスとカラー'
  ),
  new TranslationEntry(
    '拍摄自动化',
    'Capture Automation',
    '撮影オートメーション'
  ),
  new TranslationEntry(
    '间隔、包围与 B 门任务集中管理',
    'Manage interval, bracketing, and Bulb tasks together',
    'インターバル、ブラケット、バルブをまとめて管理'
  ),
  new TranslationEntry(
    '语言更改会立即应用，并在下次启动时保留。',
    'Language changes apply immediately and are remembered for the next launch.',
    '言語の変更はすぐに適用され、次回起動時にも保持されます。'
  ),
  new TranslationEntry(
    '请作者喝杯奶茶，支持后续维护与新机型适配。',
    'Support ongoing maintenance and compatibility with more camera models.',
    '継続的なメンテナンスと新しいカメラへの対応をご支援ください。'
  ),
  new TranslationEntry(
    '打开微信扫一扫，感谢支持。',
    'Scan with WeChat. Thank you for your support.',
    'WeChat でスキャンしてください。ご支援ありがとうございます。'
  ),
  new TranslationEntry(
    '爱发电赞助',
    'Afdian Support',
    'Afdian で支援'
  ),
  new TranslationEntry(
    '扫描二维码，或打开爱发电主页支持项目。',
    'Scan the QR code or open the Afdian page to support the project.',
    'QR コードを読み取るか、Afdian ページを開いてプロジェクトを支援できます。'
  ),
  new TranslationEntry(
    '快速问题反馈',
    'Faster Problem Feedback',
    'より迅速な問題フィードバック'
  ),
  new TranslationEntry(
    '公开问题可继续在 GitHub 免费提交；在爱发电赞助后，可获取快速问题反馈渠道。',
    'Public issues remain free on GitHub. Afdian sponsors can access a faster feedback channel.',
    '公開 Issue は引き続き GitHub から無料で送信できます。Afdian で支援すると、より迅速なフィードバック窓口を利用できます。'
  ),
  new TranslationEntry(
    '官方 QQ 群：165315727',
    'Official QQ group: 165315727',
    '公式 QQ グループ：165315727'
  ),
  new TranslationEntry(
    '打开爱发电',
    'Open Afdian',
    'Afdian を開く'
  ),
  new TranslationEntry(
    '赞助不会解锁软件功能，也不影响公开 Issue 的处理。',
    'Sponsorship does not unlock app features or affect public issue handling.',
    '支援によってアプリ機能が解除されたり、公開 Issue の対応が変わったりすることはありません。'
  ),
  new TranslationEntry(
    '软件功能永久免费，赞助为自愿行为。',
    'App features remain free; sponsorship is voluntary.',
    'アプリの機能は無料のままで、ご支援は任意です。'
  ),
  new TranslationEntry(
    '更新公告',
    'What’s New',
    'アップデートのお知らせ'
  ),
  new TranslationEntry('本次更新', 'In This Update', '今回の更新'),
  new TranslationEntry(
    '• 修复 AI 修图原图链路：客户端发送当前选中照片的完整 data:image 数据，代理按上游要求放入 images 并等待任务完成，修图结果真正基于原图。\n' +
      '• AI 修图成功后覆盖当前原图并保留文件记录；AI 生图仍保存为新文件，避免混淆。\n' +
      '• AI 次数由服务器统一扣减并回传剩余次数；失败请求自动回滚，不再出现调用未扣次数。\n' +
      '• 继续保留设备码绑定、官网兑换、爱发电购买提示和防诈骗说明。\n' +
      '• 优化 Nikon / Sony / Canon 相机识别、PTP 拍摄与专业编辑稳定性。\n' +
      '• iOS / iPadOS、Android、HarmonyOS、macOS、Windows 五端同步更新。',
    '• Fixed the AI photo-editing reference-image path: the selected photo is sent as a complete data URL, the proxy forwards it in the upstream images array, and waits for the task result so edits are based on the original.\n' +
      '• Successful AI retouching overwrites the current original while preserving library records; AI generation still saves a new file.\n' +
      '• AI usage is deducted by the server and the remaining count is returned; failed requests roll back, preventing missing quota deductions.\n' +
      '• Kept device-bound activation, official redemption, Afdian purchase guidance, and scam warnings.\n' +
      '• Improved Nikon / Sony / Canon camera detection, PTP capture, and professional editor stability.\n' +
      '• Synchronized the update across iOS / iPadOS, Android, HarmonyOS, macOS, and Windows.',
    '• AI 写真編集の参照画像経路を修正。選択した写真を完全な data URL として送り、プロキシが上流の images 配列へ転送してタスク完了まで待機するため、編集結果が元画像に基づくようになりました。\n' +
      '• AI レタッチ成功時は現在の元画像を上書きし、ライブラリ記録を保持します。AI 生成は新規ファイルとして保存します。\n' +
      '• AI 利用回数はサーバーで減算し、残り回数を返します。失敗したリクエストはロールバックされ、回数が減らない問題を防ぎます。\n' +
      '• デバイス紐付け認証、公式交換、Afdian 購入案内、詐欺注意を継続します。\n' +
      '• Nikon / Sony / Canon のカメラ検出、PTP 撮影、プロ現像の安定性を改善しました。\n' +
      '• iOS / iPadOS、Android、HarmonyOS、macOS、Windows を同時更新。'
  ),
  new TranslationEntry('智能移除', 'Smart Removal', 'スマート除去'),
  new TranslationEntry(
    '去路人并自然补全背景',
    'Remove passersby and naturally reconstruct the background',
    '通行人を削除し、背景を自然に補完'
  ),
  new TranslationEntry(
    '去穿帮并移除摄影器材、工作人员、反光与杂物',
    'Remove production artifacts, including equipment, crew, reflections, and clutter',
    '撮影機材、スタッフ、映り込み、不要物などの写り込みを除去'
  ),
  new TranslationEntry(
    'AI 生成超时，请稍后重试',
    'AI generation timed out. Please try again later.',
    'AI 生成がタイムアウトしました。しばらくしてから再試行してください'
  ),
  new TranslationEntry(
    '蓝色显示当前蒙版覆盖；橡皮会擦除蓝色区域。',
    'Blue shows the active mask coverage; the eraser removes blue areas.',
    '青は現在のマスク範囲です。消しゴムは青い領域を消去します。'
  ),
  new TranslationEntry('已选择原图', 'Original selected', '元画像を選択済み'),
  new TranslationEntry(
    '• 新增五端全局状态条：统一显示相机连接、当前操作和 ZENCHE 文件库总数。\n' +
      '• 新增“恢复设备码”入口（服务端启用后可用）：使用旧设备码与旧激活码迁移剩余 AI 次数；成功后旧绑定永久失效。\n' +
      '• Android USB/PTP 遇到已知异步传输故障时会自动降级，并在本次连接中复用稳定通道，减少重复等待。\n' +
      '• 强化 AI 代理与签发服务：限制请求和响应大小、耐久保存次数、失败自动退款，并在存储异常时停止继续写入。\n' +
      '• iOS / iPadOS、Android、HarmonyOS、macOS、Windows 五端同步更新。',
    '• Added a global status bar on all five clients for camera connection, current operation, and total ZENCHE library count.\n' +
      '• Added Restore Device Code (available after the server is enabled): migrate remaining AI uses with the old device ID and activation code; the old binding is permanently invalidated after success.\n' +
      '• Android USB/PTP now falls back on known asynchronous transfer failures and reuses the stable path for the current connection to avoid repeated waits.\n' +
      '• Hardened the AI proxy and signing service with bounded payloads, durable quota writes, automatic refunds, and fail-stop behavior after storage faults.\n' +
      '• Synchronized the update across iOS / iPadOS, Android, HarmonyOS, macOS, and Windows.',
    '• 5 つのクライアントに共通ステータスバーを追加し、カメラ接続、現在の操作、ZENCHE ライブラリ総数を表示します。\n' +
      '• 「デバイスコードを復元」を追加（サーバー有効化後に利用可能）。旧デバイス ID と旧アクティベーションコードで AI 残回数を移行し、成功後は旧紐付けを永久に無効化します。\n' +
      '• Android USB/PTP は既知の非同期転送障害時に自動フォールバックし、現在の接続では安定した経路を再利用して待ち時間の繰り返しを抑えます。\n' +
      '• AI プロキシと署名サービスを強化し、データ量制限、回数の永続保存、失敗時の自動返却、ストレージ異常後の停止動作を追加しました。\n' +
      '• iOS / iPadOS、Android、HarmonyOS、macOS、Windows を同時更新。'
  ),
  new TranslationEntry(
    '• 新增“外录到当前智能设备”：视频可实时写入 ZENCHE 文件库，并可与相机机身存储卡录制并行。\n' +
      '• 新增相机机内存储管理：可浏览存储卷与文件、查看缩略图和保护状态，并批量下载或确认后永久删除。\n' +
      '• 照片继续直接保存到当前设备；外录视频沿用会话命名、备份与 SHA‑256 完整性记录。\n' +
      '• PTP 实时取景不含音频，Android、HarmonyOS、macOS 与 Windows 外录为无声 Motion‑JPEG AVI；iOS / iPadOS 本机与 UVC 源外录为 MOV。\n' +
      '• 停止录制、断开相机或发生写入异常时会安全封装已写入的视频，减少素材损失。\n' +
      '• iOS / iPadOS、Android、HarmonyOS、macOS、Windows 五端同步更新。',
    '• Added “Record to This Smart Device”: video can be written live to the ZENCHE library alongside in-camera card recording.\n' +
      '• Added in-camera storage management with volume and file browsing, thumbnails, protection state, batch download, and confirmed permanent deletion.\n' +
      '• Photos continue to save directly to this device; external video keeps session naming, backups, and SHA-256 integrity records.\n' +
      '• PTP live view contains no audio. Android, HarmonyOS, macOS, and Windows record silent Motion-JPEG AVI; local and UVC sources on iOS / iPadOS record MOV.\n' +
      '• Stopping, disconnecting the camera, or encountering a write error safely finalizes the recorded video to reduce footage loss.\n' +
      '• Synchronized the update across iOS / iPadOS, Android, HarmonyOS, macOS, and Windows.',
    '• 「このスマートデバイスへ外部収録」を追加。動画を ZENCHE ライブラリへリアルタイム保存し、カメラ内カード記録と併用できます。\n' +
      '• カメラ内ストレージ管理を追加。ストレージとファイルの参照、サムネイル、保護状態、一括ダウンロード、確認付き完全削除に対応します。\n' +
      '• 写真は引き続きこのデバイスへ直接保存。外部収録動画にはセッション命名、バックアップ、SHA-256 整合性記録を適用します。\n' +
      '• PTP ライブビューに音声は含まれません。Android、HarmonyOS、macOS、Windows は無音の Motion-JPEG AVI、iOS / iPadOS のローカル／UVC ソースは MOV で収録します。\n' +
      '• 収録停止、カメラ切断、書き込みエラー時も記録済み動画を安全に確定し、素材損失を抑えます。\n' +
      '• iOS / iPadOS、Android、HarmonyOS、macOS、Windows を同時更新。'
  ),
  new TranslationEntry(
    '谨防诈骗',
    'Scam Warning',
    '詐欺にご注意ください'
  ),
  new TranslationEntry(
    '帧澈 ZENCHE 是开源免费项目。任何声称“进群领取软件”' +
      '或要求付费购买软件的人都是骗子，请勿转账。',
    'ZENCHE is free and open source. Anyone claiming you must join ' +
      'a group to receive the software or pay to buy it is a scammer. ' +
      'Do not send money.',
    'ZENCHE は無料のオープンソースプロジェクトです。' +
      '「グループ参加でソフトを受け取れる」と案内したり、' +
      '購入代金を要求したりする相手は詐欺です。送金しないでください。'
  ),
  new TranslationEntry('自愿赞助', 'Optional Support', '任意のご支援'),
  new TranslationEntry(
    '如果本项目对你有帮助，欢迎自愿打赏；软件功能永久免费。',
    'If the project helps you, optional tips are welcome; ' +
      'the software remains free.',
    'このプロジェクトが役立った場合は任意でご支援いただけます。' +
      'ソフトウェアは今後も無料です。'
  ),
  new TranslationEntry(
    '不再提醒（软件更新后仍会显示）',
    'Don’t remind me again (shown after software updates)',
    '今後は表示しない（ソフトウェア更新後は再表示）'
  ),
  new TranslationEntry('关闭公告', 'Close', '閉じる'),
  new TranslationEntry(
    '多协议无线图片收件箱',
    'Multi-Protocol Wireless Inbox',
    'マルチプロトコル・ワイヤレス受信箱'
  ),
  new TranslationEntry(
    '连接相机后开启实时取景',
    'Connect a camera to start live view',
    'カメラを接続してライブビューを開始'
  ),
  new TranslationEntry('语言', 'Language', '言語'),
  new TranslationEntry('界面语言', 'Interface Language', '表示言語'),
  new TranslationEntry('设置', 'Settings', '設定'),
  new TranslationEntry('打开设置', 'Open Settings', '設定を開く'),
  new TranslationEntry('来源', 'Source', '入力'),
  new TranslationEntry('模式', 'Mode', 'モード'),
  new TranslationEntry('快门', 'Shutter', 'シャッター'),
  new TranslationEntry('光圈', 'Aperture', '絞り'),
  new TranslationEntry('曝光补偿', 'Exposure', '露出補正'),
  new TranslationEntry('自动', 'Auto', 'オート'),
  new TranslationEntry('工作区', 'Workspace', 'ワークスペース'),
  new TranslationEntry('照片拍摄', 'Photo Capture', '写真撮影'),
  new TranslationEntry('拍照', 'Capture', '撮影'),
  new TranslationEntry('视频监看', 'Video Monitor', '動画モニター'),
  new TranslationEntry('照片', 'Photos', '写真'),
  new TranslationEntry('分支', 'Library', 'ライブラリ'),
  new TranslationEntry('视频', 'Video', '動画'),
  new TranslationEntry('文件', 'Files', 'ファイル'),
  new TranslationEntry('连接相机', 'Connect Camera', 'カメラに接続'),
  new TranslationEntry('断开相机', 'Disconnect Camera', 'カメラを切断'),
  new TranslationEntry('连接', 'Connect', '接続'),
  new TranslationEntry('断开', 'Disconnect', '接続解除'),
  new TranslationEntry('我的设备', 'My Devices', 'マイデバイス'),
  new TranslationEntry('设备', 'Devices', 'デバイス'),
  new TranslationEntry(
    '管理连接过的相机，轻触即可快速重连',
    'Keep connected cameras ready for one-tap reconnection.',
    '接続済みカメラを管理し、すばやく再接続できます。'),
  new TranslationEntry('尚未连接过设备', 'No Saved Devices', '保存済みデバイスはありません'),
  new TranslationEntry(
    '成功连接相机后会自动保存在这里。',
    'Cameras are saved here automatically after a successful connection.',
    '接続に成功したカメラは自動的にここへ保存されます。'),
  new TranslationEntry('当前已连接', 'Connected', '接続中'),
  new TranslationEntry('最近连接', 'Last connected', '最終接続'),
  new TranslationEntry('快速连接', 'Quick Connect', 'クイック接続'),
  new TranslationEntry('忘记设备', 'Forget Device', 'デバイスを削除'),
  new TranslationEntry('未连接', 'Not Connected', '未接続'),
  new TranslationEntry('就绪', 'Ready', '準備完了'),
  new TranslationEntry('关闭', 'Close', '閉じる'),
  new TranslationEntry('取消', 'Cancel', 'キャンセル'),
  new TranslationEntry('完成', 'Done', '完了'),
  new TranslationEntry('刷新', 'Refresh', '更新'),
  new TranslationEntry('全屏', 'Full Screen', 'フルスクリーン'),
  new TranslationEntry(
    '退出全屏',
    'Exit Full Screen',
    'フルスクリーンを終了'
  ),
  new TranslationEntry(
    '等待相机画面',
    'Waiting for camera image',
    'カメラ映像を待機中'
  ),
  new TranslationEntry('相机参数', 'Camera Controls', 'カメラ設定'),
  new TranslationEntry('拍摄模式', 'Shooting Mode', '撮影モード'),
  new TranslationEntry('程序自动', 'Program Auto', 'プログラムオート'),
  new TranslationEntry('快门优先', 'Shutter Priority', 'シャッター優先'),
  new TranslationEntry('光圈优先', 'Aperture Priority', '絞り優先'),
  new TranslationEntry('手动', 'Manual', 'マニュアル'),
  new TranslationEntry('B门', 'Bulb', 'バルブ'),
  new TranslationEntry('快门速度', 'Shutter Speed', 'シャッタースピード'),
  new TranslationEntry('快门角度', 'Shutter Angle', 'シャッター角度'),
  new TranslationEntry('视频帧率基准', 'Video Frame Rate', '動画フレームレート'),
  new TranslationEntry('光圈', 'Aperture', '絞り'),
  new TranslationEntry('ISO 感光度', 'ISO Sensitivity', 'ISO 感度'),
  new TranslationEntry('曝光补偿', 'Exposure Compensation', '露出補正'),
  new TranslationEntry('对焦模式', 'Focus Mode', 'フォーカスモード'),
  new TranslationEntry('单次自动对焦', 'Single AF', 'シングル AF'),
  new TranslationEntry('连续自动对焦', 'Continuous AF', 'コンティニュアス AF'),
  new TranslationEntry('手动对焦', 'Manual Focus', 'マニュアルフォーカス'),
  new TranslationEntry('白平衡', 'White Balance', 'ホワイトバランス'),
  new TranslationEntry(
    '预设手动',
    'Preset Manual',
    'プリセットマニュアル'
  ),
  new TranslationEntry(
    '优化校准',
    'Picture Control',
    'ピクチャーコントロール'
  ),
  new TranslationEntry('自动', 'Auto', 'オート'),
  new TranslationEntry('标准', 'Standard', 'スタンダード'),
  new TranslationEntry('自然', 'Neutral', 'ニュートラル'),
  new TranslationEntry('鲜艳', 'Vivid', 'ビビッド'),
  new TranslationEntry('单色', 'Monochrome', 'モノクローム'),
  new TranslationEntry('人像', 'Portrait', 'ポートレート'),
  new TranslationEntry('风景', 'Landscape', '風景'),
  new TranslationEntry('平面', 'Flat', 'フラット'),
  new TranslationEntry('拍摄', 'Capture', '撮影'),
  new TranslationEntry('拍摄照片', 'Capture Photo', '写真を撮影'),
  new TranslationEntry('拍摄中…', 'Capturing…', '撮影中…'),
  new TranslationEntry('开启取景', 'Start Live View', 'ライブビュー開始'),
  new TranslationEntry('停止取景', 'Stop Live View', 'ライブビュー停止'),
  new TranslationEntry('开始录制', 'Start Recording', '録画開始'),
  new TranslationEntry('停止录制', 'Stop Recording', '録画停止'),
  new TranslationEntry('视频曝光三要素', 'Video Exposure', '動画露出'),
  new TranslationEntry('监看输出', 'Monitor Output', 'モニター出力'),
  new TranslationEntry('监看辅助', 'Monitoring Tools', 'モニター補助'),
  new TranslationEntry('文件与传输', 'Files & Transfer', 'ファイルと転送'),
  new TranslationEntry('刷新系统相册', 'Refresh System Library', 'システムライブラリを更新'),
  new TranslationEntry('链接网盘', 'Connect Cloud Drive', 'クラウドドライブに接続'),
  new TranslationEntry('分享', 'Share', '共有'),
  new TranslationEntry('预览', 'Preview', 'プレビュー'),
  new TranslationEntry('删除', 'Delete', '削除'),
  new TranslationEntry('分享到社交平台', 'Share', '共有'),
  new TranslationEntry(
    '选择文件并加入',
    'Choose Files to Add',
    '追加するファイルを選択'
  ),
  new TranslationEntry(
    '系统相册暂不可见',
    'System library is unavailable',
    'システムライブラリを表示できません'
  ),
  new TranslationEntry(
    '本地图库还是空的',
    'The local library is empty',
    'ローカルライブラリは空です'
  ),
  new TranslationEntry(
    '无线收件箱未开启',
    'Wireless inbox is off',
    'ワイヤレス受信箱は停止中'
  ),
  new TranslationEntry(
    '开启无线接收',
    'Start Wireless Receiver',
    'ワイヤレス受信を開始'
  ),
  new TranslationEntry('停止接收', 'Stop Receiving', '受信を停止'),
  new TranslationEntry(
    '更新、诊断与支持。',
    'Updates, diagnostics, and support.',
    'アップデート、診断、サポート。'
  ),
  new TranslationEntry(
    '软件更新',
    'Software Update',
    'ソフトウェアアップデート'
  ),
  new TranslationEntry(
    '优先通过 Mirror酱检查更新，无可用 CDN 下载地址时自动回退 GitHub Releases。',
    'Check MirrorChyan first and fall back to GitHub Releases when no CDN download is available.',
    'MirrorChyan を優先して確認し、CDN ダウンロードがない場合は GitHub Releases に切り替えます。'
  ),
  new TranslationEntry(
    'Mirror酱 CDK（可选）',
    'MirrorChyan CDK (Optional)',
    'MirrorChyan CDK（任意）'
  ),
  new TranslationEntry(
    'CDK 保存在应用私有设置中，不会写入诊断日志。',
    'The CDK is stored in private app settings and is never written to diagnostic logs.',
    'CDK はアプリの非公開設定に保存され、診断ログには記録されません。'
  ),
  new TranslationEntry('保存 CDK', 'Save CDK', 'CDK を保存'),
  new TranslationEntry(
    '打开 Mirror酱',
    'Open MirrorChyan',
    'MirrorChyan を開く'
  ),
  new TranslationEntry(
    'Mirror酱 CDK 已清除',
    'MirrorChyan CDK cleared',
    'MirrorChyan CDK を消去しました'
  ),
  new TranslationEntry(
    'Mirror酱 CDK 已保存',
    'MirrorChyan CDK saved',
    'MirrorChyan CDK を保存しました'
  ),
  new TranslationEntry(
    'Mirror酱 CDK 保存失败',
    'Failed to save MirrorChyan CDK',
    'MirrorChyan CDK の保存に失敗しました'
  ),
  new TranslationEntry(
    'Mirror酱 CDK 已过期，已回退 GitHub',
    'MirrorChyan CDK expired; using GitHub',
    'MirrorChyan CDK の期限が切れています。GitHub を使用します'
  ),
  new TranslationEntry(
    'Mirror酱 CDK 无效，已回退 GitHub',
    'MirrorChyan CDK is invalid; using GitHub',
    'MirrorChyan CDK が無効です。GitHub を使用します'
  ),
  new TranslationEntry(
    'Mirror酱今日下载额度已用完，已回退 GitHub',
    'MirrorChyan daily quota is exhausted; using GitHub',
    'MirrorChyan の本日の上限に達しました。GitHub を使用します'
  ),
  new TranslationEntry(
    'Mirror酱 CDK 与资源不匹配，已回退 GitHub',
    'MirrorChyan CDK does not match this resource; using GitHub',
    'MirrorChyan CDK がリソースと一致しません。GitHub を使用します'
  ),
  new TranslationEntry(
    'Mirror酱 CDK 已被停用，已回退 GitHub',
    'MirrorChyan CDK is disabled; using GitHub',
    'MirrorChyan CDK は無効化されています。GitHub を使用します'
  ),
  new TranslationEntry(
    'Mirror酱资源尚未配置，已回退 GitHub',
    'MirrorChyan resource is not configured; using GitHub',
    'MirrorChyan リソースは未設定です。GitHub を使用します'
  ),
  new TranslationEntry(
    'Mirror酱暂不可用，已回退 GitHub',
    'MirrorChyan is unavailable; using GitHub',
    'MirrorChyan は利用できません。GitHub を使用します'
  ),
  new TranslationEntry(
    'Mirror酱未返回可直接安装的完整包，已回退 GitHub',
    'MirrorChyan did not return a full installer; using GitHub',
    'MirrorChyan から完全なインストーラーが返されなかったため、GitHub を使用します'
  ),
  new TranslationEntry(
    '检查更新',
    'Check for Updates',
    'アップデートを確認'
  ),
  new TranslationEntry('正在检查…', 'Checking…', '確認中…'),
  new TranslationEntry(
    '获取',
    'Get',
    '入手'
  ),
  new TranslationEntry(
    '尚未检查更新',
    'Updates have not been checked',
    'アップデートは未確認です'
  ),
  new TranslationEntry('诊断日志', 'Diagnostic Logs', '診断ログ'),
  new TranslationEntry('查询最近日志', 'View Recent Logs', '最近のログを表示'),
  new TranslationEntry('上传脱敏日志', 'Upload Redacted Logs', '匿名化ログをアップロード'),
  new TranslationEntry(
    '喜欢 帧澈 ZENCHE？',
    'Enjoying ZENCHE?',
    'ZENCHE を気に入りましたか？'
  ),
  new TranslationEntry('请作者喝奶茶', 'Support the Developer', '開発者を支援'),
  new TranslationEntry('当前版本', 'Current Version', '現在のバージョン'),
  new TranslationEntry('正在连接', 'Connecting', '接続中'),
  new TranslationEntry('已连接', 'Connected', '接続済み'),
  new TranslationEntry('已保存', 'Saved', '保存しました'),
  new TranslationEntry(
    '相机原生 JPEG · 监看输出 · 不修改原片',
    'Camera JPEG · Monitor Output · Original Unchanged',
    'カメラ JPEG · モニター出力 · オリジナルは変更しません'
  ),
  new TranslationEntry(
    '相机原生 JPEG · 本地预览',
    'Camera JPEG · Local Preview',
    'カメラ JPEG · ローカルプレビュー'
  ),
  new TranslationEntry(
    '系统相册中的照片与视频直接显示在本页；网盘文件通过独立指引页和系统文件选择器安全加入。',
    'System photos and videos appear directly on this page. Add cloud-drive files safely through the guide and system file picker.',
    'システムの写真と動画をこの画面に直接表示します。クラウドドライブのファイルはガイドとシステムファイル選択から安全に追加できます。'
  ),
  new TranslationEntry(
    '允许照片和视频访问后，最近媒体会直接显示在这里。',
    'Allow photo and video access to show recent media here.',
    '写真と動画へのアクセスを許可すると、最近のメディアがここに表示されます。'
  ),
  new TranslationEntry(
    '系统相册内容保持在原位置；帧澈 ZENCHE 只读取缩略图和预览。',
    'System-library items stay in place; ZENCHE reads only thumbnails and previews.',
    'システムライブラリの項目は元の場所に保持され、ZENCHE はサムネイルとプレビューのみを読み取ります。'
  ),
  new TranslationEntry(
    '连接相机拍摄，或在上方开启无线图片收件箱。',
    'Connect a camera to capture, or start the wireless image inbox above.',
    'カメラを接続して撮影するか、上のワイヤレス画像受信箱を開始してください。'
  ),
  new TranslationEntry(
    '账号和密码始终由网盘客户端管理。',
    'Accounts and passwords always remain with the cloud-drive app.',
    'アカウントとパスワードは常にクラウドドライブアプリが管理します。'
  ),
  new TranslationEntry(
    '先安装并登录对应客户端，把照片或视频下载到设备，再通过系统文件选择器加入 帧澈 ZENCHE。',
    'Install and sign in to the provider app, download photos or videos to the device, then add them to ZENCHE with the system file picker.',
    '対応アプリをインストールしてログインし、写真や動画をデバイスへダウンロードしてから、システムファイル選択で ZENCHE に追加します。'
  ),
  new TranslationEntry(
    '步骤：安装并登录 → 下载媒体 → 选择文件并加入。',
    'Steps: install and sign in → download media → choose files to add.',
    '手順：インストールしてログイン → メディアをダウンロード → 追加するファイルを選択。'
  ),
  new TranslationEntry(
    '连接相机并开启实时取景后即可全屏监看。',
    'Connect a camera and start live view to use full-screen monitoring.',
    'カメラを接続してライブビューを開始すると、フルスクリーンでモニターできます。'
  ),
  new TranslationEntry('收起参数', 'Hide Controls', '設定を隠す'),
  new TranslationEntry('展开参数', 'Show Controls', '設定を表示'),
  new TranslationEntry('停止', 'Stop', '停止'),
  new TranslationEntry('录制', 'Record', '録画'),
  new TranslationEntry('快门', 'Shutter', 'シャッター'),
  new TranslationEntry('无线传输', 'Wireless Transfer', 'ワイヤレス転送'),
  new TranslationEntry(
    '停止无线接收',
    'Stop Wireless Receiver',
    'ワイヤレス受信を停止'
  ),
  new TranslationEntry('端口', 'Port', 'ポート'),
  new TranslationEntry('用户名', 'Username', 'ユーザー名'),
  new TranslationEntry('密码', 'Password', 'パスワード'),
  new TranslationEntry(
    '接收完成后自动进入文件库',
    'Received files enter the library automatically',
    '受信後は自動的にライブラリへ追加'
  ),
  new TranslationEntry('百度网盘', 'Baidu Netdisk', 'Baidu Netdisk'),
  new TranslationEntry('阿里云盘', 'Aliyun Drive', 'Aliyun Drive'),
  new TranslationEntry('腾讯微云', 'Tencent Weiyun', 'Tencent Weiyun'),
  new TranslationEntry('夸克网盘', 'Quark Cloud Drive', 'Quark Cloud Drive'),
  new TranslationEntry('迅雷云盘', 'Xunlei Cloud Drive', 'Xunlei Cloud Drive'),
  new TranslationEntry('已是最新版本', "You're Up to Date", '最新バージョンです'),
  new TranslationEntry(
    '正在检查更新…',
    'Checking for Updates…',
    'アップデートを確認中…'
  ),
  new TranslationEntry(
    '发现新版本',
    'New Version Available',
    '新しいバージョンがあります'
  ),
  new TranslationEntry(
    '检查失败，请确认网络后重试',
    'Update check failed. Check your connection and try again.',
    '確認に失敗しました。ネットワークを確認して再試行してください。'
  ),
  new TranslationEntry(
    '日志目录暂不可用',
    'Log folder is unavailable',
    'ログフォルダを使用できません'
  ),
  new TranslationEntry(
    '日志暂不可用。',
    'Logs are unavailable.',
    'ログを使用できません。'
  ),
  new TranslationEntry(
    '只有在你检查预填内容并于 GitHub 确认提交后，脱敏日志才会发送。',
    'Redacted logs are sent only after you review the prefilled content and confirm on GitHub.',
    '匿名化ログは入力済み内容を確認し、GitHub で送信を確定した後にのみ送信されます。'
  ),
  new TranslationEntry('拍摄任务', 'Shooting Task', '撮影タスク'),
  new TranslationEntry('任务类型', 'Task Type', 'タスクの種類'),
  new TranslationEntry('间隔拍摄', 'Interval Capture', 'インターバル撮影'),
  new TranslationEntry('曝光包围', 'Exposure Bracketing', '露出ブラケット'),
  new TranslationEntry('焦点包围', 'Focus Bracketing', 'フォーカスブラケット'),
  new TranslationEntry('B 门计时', 'Timed Bulb', 'バルブタイマー'),
  new TranslationEntry('开始任务', 'Start Task', 'タスクを開始'),
  new TranslationEntry('取消任务', 'Cancel Task', 'タスクをキャンセル'),
  new TranslationEntry('正在取消拍摄任务…', 'Cancelling shooting task…', '撮影タスクをキャンセル中…'),
  new TranslationEntry('拍摄任务已取消', 'Shooting task cancelled', '撮影タスクをキャンセルしました'),
  new TranslationEntry('拍摄任务失败', 'Shooting task failed', '撮影タスクに失敗しました'),
  new TranslationEntry('准备中', 'Preparing', '準備中'),
  new TranslationEntry('已完成', 'Completed', '完了'),
  new TranslationEntry('张数', 'Shots', '枚数'),
  new TranslationEntry('间隔', 'Interval', '間隔'),
  new TranslationEntry('曝光时长', 'Exposure Duration', '露光時間'),
  new TranslationEntry('秒', 'Seconds', '秒'),
  new TranslationEntry('包围步长', 'Bracket Step', 'ブラケット幅'),
  new TranslationEntry('专业监看', 'Professional Monitoring', 'プロモニター'),
  new TranslationEntry('峰值对焦', 'Focus Peaking', 'フォーカスピーキング'),
  new TranslationEntry('假色曝光', 'False Color', 'フォルスカラー'),
  new TranslationEntry('波形', 'Waveform', '波形'),
  new TranslationEntry('矢量', 'Vectorscope', 'ベクトルスコープ'),
  new TranslationEntry('峰值覆盖', 'Peaking Coverage', 'ピーキング範囲'),
  new TranslationEntry('拍摄会话', 'Capture Session', '撮影セッション'),
  new TranslationEntry('项目名称', 'Project Name', 'プロジェクト名'),
  new TranslationEntry('命名模板', 'Naming Template', '命名テンプレート'),
  new TranslationEntry('创作者', 'Creator', '作成者'),
  new TranslationEntry('版权', 'Rights', '著作権'),
  new TranslationEntry('默认评级', 'Default Rating', '既定の評価'),
  new TranslationEntry('双目标备份', 'Dual-Destination Backup', '二重保存'),
  new TranslationEntry('开始会话', 'Start Session', 'セッションを開始'),
  new TranslationEntry('结束会话', 'End Session', 'セッションを終了'),
  new TranslationEntry('配置并开始', 'Configure and Start', '設定して開始'),
  new TranslationEntry('尚未开始拍摄会话', 'No capture session started', '撮影セッションは未開始です'),
  new TranslationEntry('会话进行中', 'Session Active', 'セッション実行中'),
  new TranslationEntry('拍摄会话已结束', 'Capture session ended', '撮影セッションを終了しました'),
  new TranslationEntry('编辑', 'Edit', '編集'),
  new TranslationEntry('图像编辑', 'Image Editor', '画像編集'),
  new TranslationEntry('分支抽屉', 'Branch Drawer', 'ブランチドロワー'),
  new TranslationEntry(
    '调整亮度、对比度、饱和度与方向；保存时生成 JPEG 副本。',
    'Adjust brightness, contrast, saturation, and orientation; saving creates a JPEG copy.',
    '明るさ、コントラスト、彩度、向きを調整し、保存時に JPEG のコピーを作成します。'
  ),
  new TranslationEntry(
    '文件库中没有可编辑照片',
    'There are no editable photos in the library',
    'ライブラリに編集可能な写真がありません'
  ),
  new TranslationEntry(
    '文件库 · %lld 个文件',
    'Library · %lld files',
    'ライブラリ · %lld 件'
  ),
  new TranslationEntry('个文件', 'files', '件'),
  new TranslationEntry('未选择照片', 'No photo selected', '写真が選択されていません'),
  new TranslationEntry(
    '视频与暂不支持解码的 RAW 文件不会进入编辑列表。',
    'Videos and RAW files that cannot yet be decoded are excluded from the editor.',
    '動画と、まだデコードできない RAW ファイルは編集リストに表示されません。'
  ),
  new TranslationEntry('亮度', 'Brightness', '明るさ'),
  new TranslationEntry('对比度', 'Contrast', 'コントラスト'),
  new TranslationEntry('饱和度', 'Saturation', '彩度'),
  new TranslationEntry('旋转 90°', 'Rotate 90°', '90° 回転'),
  new TranslationEntry('重置', 'Reset', 'リセット'),
  new TranslationEntry('保存副本', 'Save Copy', 'コピーを保存'),
  new TranslationEntry('正在保存…', 'Saving…', '保存中…'),
  new TranslationEntry(
    '调整不会覆盖原文件',
    'Adjustments do not overwrite the original',
    '調整しても元のファイルは上書きされません'
  ),
  new TranslationEntry(
    '保存编辑副本失败',
    'Failed to save the edited copy',
    '編集したコピーの保存に失敗しました'
  ),
  new TranslationEntry('已保存副本', 'Saved copy', 'コピーを保存しました'),
  new TranslationEntry('专业显影', 'Pro Develop', 'プロ現像'),
  new TranslationEntry(
    '分组调整光线、色彩、细节、效果与几何；始终保留原文件。',
    'Adjust light, color, detail, effects, and geometry in focused groups while always preserving the original.',
    'ライト、カラー、ディテール、効果、ジオメトリをグループ別に調整し、元のファイルを常に保持します。'
  ),
  new TranslationEntry('光线', 'Light', 'ライト'),
  new TranslationEntry('色彩', 'Color', 'カラー'),
  new TranslationEntry('细节', 'Detail', 'ディテール'),
  new TranslationEntry('效果', 'Effects', '効果'),
  new TranslationEntry('几何', 'Geometry', 'ジオメトリ'),
  new TranslationEntry('曝光', 'Exposure', '露光量'),
  new TranslationEntry('高光', 'Highlights', 'ハイライト'),
  new TranslationEntry('阴影', 'Shadows', 'シャドウ'),
  new TranslationEntry('白色色阶', 'Whites', '白レベル'),
  new TranslationEntry('黑色色阶', 'Blacks', '黒レベル'),
  new TranslationEntry('色温', 'Temperature', '色温'),
  new TranslationEntry('色调', 'Tint', '色かぶり補正'),
  new TranslationEntry('自然饱和度', 'Vibrance', '自然な彩度'),
  new TranslationEntry('纹理', 'Texture', 'テクスチャ'),
  new TranslationEntry('清晰度', 'Clarity', '明瞭度'),
  new TranslationEntry('锐化', 'Sharpening', 'シャープ'),
  new TranslationEntry('降噪', 'Noise Reduction', 'ノイズ軽減'),
  new TranslationEntry('去雾', 'Dehaze', 'かすみの除去'),
  new TranslationEntry('暗角', 'Vignette', '周辺光量'),
  new TranslationEntry('裁切比例', 'Crop Ratio', '切り抜き比率'),
  new TranslationEntry('原始比例', 'Original Ratio', '元の比率'),
  new TranslationEntry('水平翻转', 'Flip Horizontal', '左右反転'),
  new TranslationEntry('垂直翻转', 'Flip Vertical', '上下反転'),
  new TranslationEntry('预设', 'Preset', 'プリセット'),
  new TranslationEntry('原始', 'Original', 'オリジナル'),
  new TranslationEntry('自然增强', 'Natural Enhance', 'ナチュラル補正'),
  new TranslationEntry('AI 智能修图', 'AI Retouch', 'AI レタッチ'),
  new TranslationEntry('AI 修图工作台', 'AI Retouch Workbench', 'AI レタッチワークベンチ'),
  new TranslationEntry('设备端 · 不上传', 'On-device · Never uploaded', 'デバイス内 · アップロードなし'),
  new TranslationEntry('分析画面', 'Analyze Image', '画像を解析'),
  new TranslationEntry('画面分析完成 · 可应用 AI 建议', 'Analysis complete · Ready to apply AI', '解析完了 · AI 補正を適用できます'),
  new TranslationEntry('已复制 AI 调整，可应用到下一张照片', 'AI settings copied; apply them to the next photo', 'AI 補正をコピーしました。次の写真に適用できます'),
  new TranslationEntry('已粘贴 AI 调整', 'AI settings pasted', 'AI 補正を貼り付けました'),
  new TranslationEntry('曝光', 'Exposure', '露出'),
  new TranslationEntry('动态范围', 'Dynamic range', 'ダイナミックレンジ'),
  new TranslationEntry('色彩', 'Color', 'カラー'),
  new TranslationEntry('细节', 'Detail', 'ディテール'),
  new TranslationEntry(
    '设备端分析画面并生成可继续微调的专业参数；照片不会上传。',
    'Analyze the image on-device and generate professional settings you can keep refining; photos are never uploaded.',
    'デバイス上で画像を解析し、さらに微調整できるプロ設定を生成します。写真はアップロードされません。'
  ),
  new TranslationEntry('智能优化', 'Smart Enhance', 'スマート補正'),
  new TranslationEntry('设备端', 'On-device', 'デバイス内'),
  new TranslationEntry('AI 强度', 'AI Strength', 'AI 強度'),
  new TranslationEntry('撤销 AI', 'Undo AI', 'AI を元に戻す'),
  new TranslationEntry(
    '等待分析当前照片',
    'Ready to analyze this photo',
    'この写真を解析できます'
  ),
  new TranslationEntry(
    '检测到画面偏暗，已提亮阴影并保护高光',
    'The image is dark; shadows were lifted while highlights were protected.',
    '暗めの画像を検出し、ハイライトを保護しながらシャドウを明るくしました。'
  ),
  new TranslationEntry(
    '检测到画面偏亮，已回收高光并恢复层次',
    'The image is bright; highlights were recovered to restore tonal detail.',
    '明るめの画像を検出し、ハイライトを抑えて階調を復元しました。'
  ),
  new TranslationEntry(
    '检测到动态范围偏平，已增强层次与色彩',
    'The tonal range is flat; depth and color were enhanced.',
    '階調がフラットなため、立体感と色彩を強調しました。'
  ),
  new TranslationEntry(
    '曝光均衡，已优化色彩与细节',
    'Exposure is balanced; color and detail were refined.',
    '露出は良好です。色彩とディテールを最適化しました。'
  ),
  new TranslationEntry(
    '已撤销 AI 优化',
    'AI enhancement undone',
    'AI 補正を元に戻しました'
  ),
  new TranslationEntry(
    'AI 优化已应用 · 可继续微调',
    'AI enhancement applied · Continue refining any setting',
    'AI 補正を適用しました · 各設定を引き続き調整できます'
  ),
  new TranslationEntry(
    '已恢复 AI 优化前的参数',
    'Restored the settings from before AI enhancement',
    'AI 補正前の設定に戻しました'
  ),
  new TranslationEntry(
    '无法分析当前照片',
    'Unable to analyze this photo',
    'この写真を解析できません'
  ),
  new TranslationEntry('人像柔和', 'Soft Portrait', 'ソフトポートレート'),
  new TranslationEntry('风光通透', 'Clear Landscape', 'クリア風景'),
  new TranslationEntry('高反差黑白', 'High-Contrast B&W', 'ハイコントラスト白黒'),
  new TranslationEntry('查看原图', 'Show Original', '元画像を表示'),
  new TranslationEntry('返回调整', 'Back to Adjustments', '調整に戻る'),
  new TranslationEntry('原图', 'Original', '元画像'),
  new TranslationEntry('调整后', 'Adjusted', '調整後'),
  new TranslationEntry('全部重置', 'Reset All', 'すべてリセット'),
  new TranslationEntry(
    '保存高质量副本',
    'Save High-Quality Copy',
    '高品質コピーを保存'
  ),
  new TranslationEntry(
    '已保存高质量副本',
    'Saved high-quality copy',
    '高品質コピーを保存しました'
  ),
  new TranslationEntry('正在查看原图', 'Viewing original', '元画像を表示中'),
  new TranslationEntry('相机机内存储', 'In-Camera Storage', 'カメラ内ストレージ'),
  new TranslationEntry('连接相机后可浏览存储卡', 'Connect a camera to browse its memory card', 'カメラを接続するとメモリーカードを参照できます'),
  new TranslationEntry('正在读取存储卡…', 'Reading camera card…', 'カメラ内カードを読み込み中…'),
  new TranslationEntry('读取完成', 'Ready', '読み込み完了'),
  new TranslationEntry('读取失败', 'Unable to read storage', 'ストレージを読み込めません'),
  new TranslationEntry('全选', 'Select All', 'すべて選択'),
  new TranslationEntry('取消全选', 'Deselect All', 'すべての選択を解除'),
  new TranslationEntry('下载到 ZENCHE', 'Download to ZENCHE', 'ZENCHE へダウンロード'),
  new TranslationEntry('从相机删除', 'Delete from Camera', 'カメラから削除'),
  new TranslationEntry('从相机永久删除？', 'Permanently delete from camera?', 'カメラから完全に削除しますか？'),
  new TranslationEntry('永久删除', 'Delete Permanently', '完全に削除'),
  new TranslationEntry('此操作无法撤销；已保护文件不会被选择。', 'This cannot be undone. Protected files are not selected.', 'この操作は取り消せません。保護されたファイルは選択されません。'),
  new TranslationEntry('正在下载', 'Downloading', 'ダウンロード中'),
  new TranslationEntry('已下载', 'Downloaded', 'ダウンロード完了'),
  new TranslationEntry('正在从相机删除…', 'Deleting from camera…', 'カメラから削除中…'),
  new TranslationEntry('已从相机删除', 'Deleted from camera', 'カメラから削除しました'),
  new TranslationEntry('受保护', 'Protected', '保護済み'),
  new TranslationEntry('传输', 'Transfer', '転送'),
  new TranslationEntry('对焦', 'Focus', 'フォーカス'),
  new TranslationEntry('色轮', 'Color Wheels', 'カラーホイール'),
  new TranslationEntry('曲线', 'Curves', 'カーブ'),
  new TranslationEntry('峰值', 'Peaking', 'ピーキング'),
  new TranslationEntry('假色', 'False Color', 'フォルスカラー'),
  new TranslationEntry('本机摄像头', 'Local Camera', '内蔵カメラ'),
  new TranslationEntry('Wi‑Fi 相机', 'Wi‑Fi Camera', 'Wi‑Fi カメラ'),
  // W13：账号登录墙与认证失败路径。
  new TranslationEntry('登录', 'Sign In', 'ログイン'),
  new TranslationEntry('注册', 'Create Account', '新規登録'),
  new TranslationEntry('已有账号', 'Existing Account', '既存のアカウント'),
  new TranslationEntry('创建账号', 'Create Account', '新規登録'),
  new TranslationEntry('账号', 'Account', 'アカウント'),
  new TranslationEntry('邮箱', 'Email', 'メールアドレス'),
  new TranslationEntry('密码（至少 8 位）', 'Password (8 characters minimum)', 'パスワード（8文字以上）'),
  new TranslationEntry('验证码', 'Verification Code', '認証コード'),
  new TranslationEntry('获取验证码', 'Send Code', '認証コードを送信'),
  new TranslationEntry('重新获取', 'Send Again', '再送信'),
  new TranslationEntry('正在发送…', 'Sending…', '送信中…'),
  new TranslationEntry('登录后使用拍摄、编辑与 AI 功能', 'Sign in to use capture, editing, and AI features', '撮影、編集、AI 機能を利用するにはログインしてください'),
  new TranslationEntry('还没有账号？切换到「注册」即可创建', 'New to ZENCHE? Choose Create Account.', 'アカウントをお持ちでない場合は「新規登録」を選択してください。'),
  new TranslationEntry('已有账号？切换到「登录」', 'Already have an account? Choose Sign In.', 'アカウントをお持ちの場合は「ログイン」を選択してください。'),
  new TranslationEntry('正在验证登录状态…', 'Checking your session…', 'ログイン状態を確認しています…'),
  new TranslationEntry('正在验证登录状态，请稍候', 'Checking your session. Please wait.', 'ログイン状態を確認しています。しばらくお待ちください。'),
  new TranslationEntry('请输入邮箱', 'Enter your email address', 'メールアドレスを入力してください'),
  new TranslationEntry('邮箱格式不正确', 'Enter a valid email address', '有効なメールアドレスを入力してください'),
  new TranslationEntry('请输入密码', 'Enter your password', 'パスワードを入力してください'),
  new TranslationEntry('密码至少 8 位', 'Password must be at least 8 characters', 'パスワードは8文字以上で入力してください'),
  new TranslationEntry('请先获取验证码', 'Request a verification code first', '先に認証コードを取得してください'),
  new TranslationEntry('请输入 6 位验证码', 'Enter the 6-digit verification code', '6桁の認証コードを入力してください'),
  new TranslationEntry('验证码已发送至', 'Verification code sent to', '認証コードの送信先：'),
  new TranslationEntry('邮件服务暂未配置，将免验证码注册', 'Email verification is unavailable. You can create the account without a code.', 'メール認証は利用できません。コードなしで登録できます。'),
  new TranslationEntry('正在登录…', 'Signing in…', 'ログインしています…'),
  new TranslationEntry('正在注册…', 'Creating account…', '登録しています…'),
  new TranslationEntry('正在退出…', 'Signing out…', 'ログアウトしています…'),
  new TranslationEntry('欢迎，', 'Welcome, ', 'ようこそ、'),
  new TranslationEntry('未登录', 'Not signed in', '未ログイン'),
  new TranslationEntry('退出登录', 'Sign Out', 'ログアウト'),
  new TranslationEntry('登录后可跨设备同步激活绑定；退出后需重新登录才能使用全部功能。', 'Sign in to sync activation bindings across devices. After signing out, sign in again to use all features.', 'ログインするとアクティベーション情報をデバイス間で同期できます。ログアウト後は、すべての機能を利用するために再ログインしてください。'),
  new TranslationEntry('账号服务响应格式错误', 'The account service returned an invalid response', 'アカウントサービスから無効な応答が返されました'),
  new TranslationEntry('账号服务需要安全连接', 'A secure connection is required for the account service', 'アカウントサービスには安全な接続が必要です'),
  new TranslationEntry('未登录或登录已过期', 'You are not signed in, or your session has expired', 'ログインしていないか、セッションの有効期限が切れています'),
  new TranslationEntry('登录已过期，请重新登录', 'Your session has expired. Sign in again.', 'セッションの有効期限が切れました。もう一度ログインしてください。'),
  new TranslationEntry('请先登录', 'Sign in first', '先にログインしてください'),
  new TranslationEntry('邮箱或密码错误', 'Incorrect email or password', 'メールアドレスまたはパスワードが正しくありません'),
  new TranslationEntry('账号已禁用', 'This account has been disabled', 'このアカウントは無効です'),
  new TranslationEntry('该邮箱已注册', 'This email is already registered', 'このメールアドレスはすでに登録されています'),
  new TranslationEntry('验证码已过期，请重新获取', 'The verification code has expired. Send a new code.', '認証コードの有効期限が切れました。新しいコードを取得してください。'),
  new TranslationEntry('验证码错误次数过多，请重新获取', 'Too many incorrect attempts. Send a new verification code.', '認証コードの入力回数が上限に達しました。新しいコードを取得してください。'),
  new TranslationEntry('验证码错误', 'Incorrect verification code', '認証コードが正しくありません'),
  new TranslationEntry('请求参数有误', 'Check the information you entered and try again', '入力内容を確認して、もう一度お試しください'),
  new TranslationEntry('接口不存在', 'The requested account service is unavailable', '要求されたアカウントサービスは利用できません'),
  new TranslationEntry('API 服务返回错误', 'The account service returned an error', 'アカウントサービスからエラーが返されました'),
  new TranslationEntry('请求过于频繁，请稍后再试', 'Too many requests. Try again later.', 'リクエストが多すぎます。しばらくしてからもう一度お試しください。'),
  new TranslationEntry('邮件服务未配置', 'Email service is not configured', 'メールサービスが設定されていません'),
  new TranslationEntry('网络连接失败，请检查网络后重试', 'Network connection failed. Check your connection and try again.', 'ネットワーク接続に失敗しました。接続を確認してもう一度お試しください。'),
  new TranslationEntry('无法安全保存登录状态', 'Unable to save your sign-in securely', 'ログイン情報を安全に保存できませんでした'),
  new TranslationEntry('操作失败，请稍后重试', 'The operation failed. Try again later.', '操作に失敗しました。しばらくしてからもう一度お試しください。'),
  new TranslationEntry('已退出，但本机登录信息未完全清除。请重新登录后再退出一次。', 'You’re signed out, but some sign-in data remains on this device. Sign in and sign out again.', 'ログアウトしましたが、端末にログイン情報が残っています。再度ログインして、もう一度ログアウトしてください。'),
  new TranslationEntry('媒体池', 'Media Pool', 'メディアプール'),
  new TranslationEntry('工具轨', 'Tool Rail', 'ツールレール'),
  new TranslationEntry('编辑示波器', 'Editor Scopes', '編集スコープ'),
  new TranslationEntry('检查器', 'Inspector', 'インスペクタ'),
  new TranslationEntry('可编辑照片', 'Editable Photos', '編集可能な写真'),
  new TranslationEntry(
    '非破坏编辑 · 保存为高质量副本',
    'Non-destructive editing · Save a high-quality copy',
    '非破壊編集 · 高品質コピーとして保存'
  ),
  new TranslationEntry(
    '运行“分析画面”后显示实测范围',
    'Run Analyze Image to show measured ranges',
    '「画像を解析」を実行すると実測範囲を表示'
  ),
  new TranslationEntry(
    '分析后显示实测范围',
    'Analyze to show measured ranges',
    '解析後に実測範囲を表示'
  ),
  new TranslationEntry(
    '调整始终写入新副本，原文件保持不变。',
    'Adjustments are always written to a new copy; the original stays untouched.',
    '調整は常に新しいコピーへ保存され、元のファイルは変更されません。'
  ),
  new TranslationEntry(
    '• 五端登录页将模式选项明确为“已有账号 / 创建账号”，真正的登录按钮会持续显示提交状态，避免误点后看似无响应。\n' +
      '• macOS 与 Windows 新增桌面工作区布局：两端会在重启后恢复主窗口大小和位置，Windows 还会恢复最大化状态。\n' +
      '• 主导航、拍摄参数、编辑媒体池、工具栏与底部工具区可拖动调整；分隔条支持键盘和辅助功能名称。\n' +
      '• 新增默认、拍摄、监看、编辑与紧凑预设，并可一键恢复默认布局。\n' +
      '• 1.5.11 为未签名开发验证包；安装前请核对 SHA-256，Windows 布局仍需在真实 Windows 多显示器/DPI 环境复核。',
    '• Sign-in mode choices now read Existing Account and Create Account on all five platforms. The actual sign-in button remains visible while the request is in progress, so selecting a mode no longer looks like an unresponsive login attempt.\n' +
      '• macOS and Windows add a desktop workspace layout. Both restore main-window size and position; Windows also restores the maximized state.\n' +
      '• Drag to resize the main navigation, capture controls, editor media pool, tool panel, and lower tool area. Splitters also support keyboard input and accessible names.\n' +
      '• New Default, Capture, Monitor, Edit, and Compact presets are available, along with one-click restoration of the default layout.\n' +
      '• Version 1.5.11 is an unsigned development-validation package. Verify its SHA-256 before installation; the Windows layout still requires multi-monitor and DPI validation on Windows hardware.',
    '• 5 プラットフォームのログイン画面で、モード選択を「既存のアカウント」と「新規登録」に分けました。実際のログインボタンには処理中の状態が表示され、モード選択を誤って押しても無反応に見えません。\n' +
      '• macOS と Windows にデスクトップワークスペースを追加しました。両方でメインウインドウのサイズと位置を復元し、Windows では最大化状態も復元します。\n' +
      '• メインナビゲーション、撮影パラメータ、編集メディアプール、ツールパネル、下部ツール領域をドラッグして調整できます。区切り線はキーボード操作とアクセシビリティ名にも対応します。\n' +
      '• デフォルト、撮影、モニター、編集、コンパクトの各プリセットと、デフォルトレイアウトへ戻す操作を追加しました。\n' +
      '• 1.5.11 は未署名の開発検証用パッケージです。インストール前に SHA-256 を確認してください。Windows 版のレイアウトは、実機のマルチモニターおよび DPI 環境での確認が残っています。'
  )
];

export function normalizeLanguage(language: string): string {
  if (language === LANGUAGE_ENGLISH || language === LANGUAGE_JAPANESE) {
    return language;
  }
  return LANGUAGE_SIMPLIFIED_CHINESE;
}

export function translate(language: string, source: string): string {
  const normalized: string = normalizeLanguage(language);
  if (normalized === LANGUAGE_SIMPLIFIED_CHINESE) {
    return source;
  }
  const fragments: Array<TranslationEntry> = TRANSLATIONS.slice();
  fragments.sort(
    (left: TranslationEntry, right: TranslationEntry): number =>
      right.chinese.length - left.chinese.length
  );
  for (const entry of fragments) {
    if (entry.chinese === source) {
      return normalized === LANGUAGE_ENGLISH
        ? entry.english
        : entry.japanese;
    }
  }
  let translated: string = source;
  for (const entry of fragments) {
    if (translated.includes(entry.chinese)) {
      translated = translated
        .split(entry.chinese)
        .join(
          normalized === LANGUAGE_ENGLISH
            ? entry.english
            : entry.japanese
        );
    }
  }
  return translated;
}
