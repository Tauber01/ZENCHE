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
  new TranslationEntry('AI 创作', 'AI Create', 'AI クリエイト'),
  new TranslationEntry('联网生成与修图 · 结果保存为新文件', 'Online generation and editing · Results are saved as new files', 'オンライン生成・編集 · 結果は新規ファイルとして保存'),
  new TranslationEntry('需要激活', 'Activation required', 'アクティベーションが必要'),
  new TranslationEntry('已解锁', 'Unlocked', 'ロック解除済み'),
  new TranslationEntry('输出参数', 'Output parameters', '出力パラメータ'),
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
    '• AI 修图与 AI 生图工作台统一优化：编辑页默认进入“专业显影”，可明确切换“AI 工具”；保留快捷预设、比例、分辨率、保存到文件库。\n' +
      '• 恢复设备码系统：每个激活密钥绑定当前设备，服务器计数 AI 云服务次数；帧澈本体继续免费开源。\n' +
      '• 新增官网入口：复制设备 ID 后前往 https://zenche.top 兑换绑定当前设备的激活密钥。\n' +
      '• 新增“在爱发电购买兑换码”提示、二维码与购买入口；只认官方官网和应用内爱发电入口，谨防诈骗。\n' +
      '• 设置页移除可编辑的“AI 服务器”窗口，但继续兼容读取历史配置；Sony / Canon / Nikon 相机适配保持不变。\n' +
      '• iOS / iPadOS、Android、HarmonyOS、macOS、Windows 五端同步更新。',
    '• Unified the AI photo editing and generation workspace: editing now opens Professional Develop by default, with an explicit AI Tools switch; quick presets, ratios, resolutions, and library export remain.\n' +
      '• Restored the device-code system: each activation key is bound to the current device and AI cloud usage is counted server-side; ZENCHE itself remains free and open source.\n' +
      '• Added the official redemption path: copy the device ID and visit https://zenche.top to redeem a key bound to this device.\n' +
      '• Added an Afdian redemption-code purchase prompt, QR code, and purchase entry. Only the official website and in-app Afdian entry are trusted.\n' +
      '• Removed the editable AI Server window from Settings while retaining legacy configuration reads; Sony / Canon / Nikon camera compatibility remains.\n' +
      '• Synchronized the update across iOS / iPadOS, Android, HarmonyOS, macOS, and Windows.',
    '• AI の写真編集・生成ワークスペースを統一改善。編集画面は「プロ現像」を既定にし、「AI ツール」へ明示的に切り替え可能。クイックプリセット、比率、解像度、ライブラリ保存を維持。\n' +
      '• デバイスコードシステムを復旧。各アクティベーションキーは現在のデバイスに紐づき、AI クラウド利用回数はサーバーで計数。ZENCHE 本体は無料オープンソースのまま。\n' +
      '• 公式交換導線を追加。デバイス ID をコピーし、https://zenche.top でこのデバイス用キーに交換。\n' +
      '• Afdian で交換コードを購入する案内、QR コード、購入導線を追加。公式サイトとアプリ内 Afdian 導線だけを利用してください。\n' +
      '• 設定から編集可能な AI サーバー欄を削除し、過去の設定読み込み互換性は維持。Sony / Canon / Nikon 対応は継続。\n' +
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
  new TranslationEntry('视频监看', 'Video Monitor', '動画モニター'),
  new TranslationEntry('照片', 'Photos', '写真'),
  new TranslationEntry('视频', 'Video', '動画'),
  new TranslationEntry('文件', 'Files', 'ファイル'),
  new TranslationEntry('连接相机', 'Connect Camera', 'カメラに接続'),
  new TranslationEntry('断开相机', 'Disconnect Camera', 'カメラを切断'),
  new TranslationEntry('连接', 'Connect', '接続'),
  new TranslationEntry('断开', 'Disconnect', '接続解除'),
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
  new TranslationEntry('正在查看原图', 'Viewing original', '元画像を表示中')
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
