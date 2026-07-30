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
    '更新公告',
    'What’s New',
    'アップデートのお知らせ'
  ),
  new TranslationEntry('本次更新', 'In This Update', '今回の更新'),
  new TranslationEntry(
    '• 新增启动更新公告，并支持按版本控制提醒。\n' +
      '• 五端公告与赞助入口保持一致。\n' +
      '• 更新赞助图片并优化多语言体验。',
    '• Added a launch announcement with per-version reminder control.\n' +
      '• Kept announcements and support entry points consistent across all five platforms.\n' +
      '• Updated the support image and improved the multilingual experience.',
    '• 起動時のお知らせとバージョンごとの通知設定を追加しました。\n' +
      '• 5 つのプラットフォームでお知らせと支援画面を統一しました。\n' +
      '• 支援用画像を更新し、多言語表示を改善しました。'
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
