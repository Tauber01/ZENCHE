import {
  abilityAccessCtrl,
  common,
  Permissions
} from '@kit.AbilityKit';
import { dataSharePredicates, preferences } from '@kit.ArkData';
import { fileIo as fs, picker } from '@kit.CoreFileKit';
import { util } from '@kit.ArkTS';
import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { image } from '@kit.ImageKit';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { promptAction } from '@kit.ArkUI';
import {
  BusinessError,
  pasteboard
} from '@kit.BasicServicesKit';
import { http } from '@kit.NetworkKit';
import { systemShare } from '@kit.ShareKit';
import { sensor } from '@kit.SensorServiceKit';
import { CameraProfile } from '../camera/CameraProfiles';
import { PtpCamera } from '../camera/PtpCamera';
import { PtpIpCamera } from '../camera/PtpIpCamera';
import { LocalCameraController } from '../camera/LocalCameraController';
import { BluetoothRemoteController } from '../camera/BluetoothRemoteController';
import {
  CaptureLocation,
  LocationTaggingController
} from '../camera/LocationTaggingController';
import { PhotoItem, PhotoLibrary } from '../storage/PhotoLibrary';
import {
  CameraStorageItem,
  CameraStorageSnapshot,
  CameraStorageVolume
} from '../storage/CameraStorage';
import {
  ExternalRecordingResult,
  ExternalVideoRecorder
} from '../storage/ExternalVideoRecorder';
import {
  FTP_PORT,
  HTTP_PORT,
  WirelessTransferServer
} from '../transfer/WirelessTransferServer';
import { DiagnosticLogger } from '../diagnostics/DiagnosticLogger';
import {
  CaptureSessionConfiguration,
  CaptureWorkflow
} from '../workflow/CaptureWorkflow';
import {
  processProfessionalMonitor,
  ProfessionalMonitorResult
} from '../monitor/ProfessionalMonitor';
import {
  NIKON_CLOUD_PRESETS,
  NikonCloudColorMix,
  NikonCloudPreset
} from '../presets/NikonCloudPreview';
import {
  LANGUAGE_ENGLISH,
  LANGUAGE_JAPANESE,
  LANGUAGE_PREFERENCE_KEY,
  LANGUAGE_SIMPLIFIED_CHINESE,
  normalizeLanguage,
  translate
} from '../localization/Localization';

const STUDIO_CANVAS: string = '#06090D';
const STUDIO_PANEL: string = '#15191F';
const STUDIO_RAISED: string = '#20242B';
const STUDIO_RULE: string = '#343A43';
const STUDIO_GOLD: string = '#D8B653';
// 图 2 系（1.5.5 阶段 2）：编辑器深灰平铺 + 品牌橙选中 + 1px 深色分隔。
// STUDIO_* 常量保留定义以兼容 native-ui-1.5.3 token 契约断言（L80-81）。
const EDITOR_BG: string = '#2A2A2E';
const EDITOR_PANEL: string = '#333338';
const EDITOR_RAISED: string = '#3A3A40';
const EDITOR_RULE: string = '#1B1B1F';
const EDITOR_ACCENT: string = '#E8833A';
const EDITOR_LABEL: string = '#8E8E93';

// v1.5.5 fig1 control-page tokens: near-black canvas, one lime accent,
// flat cards, no gradients or shadows. Shared with the monitor and
// immersive surfaces so the whole capture surface reads as one system.
const UI_BG: string = '#0A0B0D';
const UI_CARD: string = '#1C1C1E';
const UI_SECONDARY: string = '#2C2C2E';
const UI_LABEL: string = '#8E8E93';
const UI_ACCENT: string = '#CDDC39';
const UI_BLUE: string = '#0A84FF';
const UI_VIDEO: string = '#D8323A';

// ===== v1.5.6 token 层（对齐 Android TS_*/SPACE_*/SCOPE_*/HUD_* 与 design.md 色板）=====

// TypeScale（5 档，与 Android 同值）
const TS_CAPTION: number = 11;    // 辅助说明/状态
const TS_BODY: number = 12;       // 正文/标签（Harmony 热点档）
const TS_EMPHASIS: number = 15;   // 强调/卡片标题
const TS_TITLE: number = 18;      // 区块标题
const TS_DISPLAY: number = 24;    // 大数字/读数

// v1.5.7 P3: 编辑页归档档位——TS 五档之外的既有值（只归档不改值，字号统一收口归 F5）
const EDITOR_FS_TINY: number = 9;    // 编辑页微标注（媒体行非破坏说明）
const EDITOR_FS_SMALL: number = 10;  // 编辑页小标签/读数（媒体计数、示波器标题、AI 指标、模块名、曲线读数）
const EDITOR_FS_SUB: number = 13;    // 编辑页次级说明（空态、AI 摘要、面板钮、取色采样）
const EDITOR_FS_MEDIUM: number = 14; // 编辑页副标题/描述（页头副标题、云创预览、AI 工具描述、提示词输入）
const EDITOR_FS_HEAD: number = 16;   // 编辑页小标题/强调（工作台标题、选中钩、AI 创作标题）

// Spacing（4pt 体系，与 Android 同值）
const SPACE_4: number = 4;
const SPACE_8: number = 8;
const SPACE_12: number = 12;
const SPACE_16: number = 16;
const SPACE_20: number = 20;
const SPACE_24: number = 24;
const SPACE_32: number = 32;
const SPACE_40: number = 40;

// design.md 色板（dark 值为主，与 Android/其他端同名同值）
const INK: string = '#ECEEF2';              // Ink（暗色主文本）
const MUTED_INK: string = '#9AA1AD';        // Muted ink（暗色次要文本）
const RULE: string = '#FFFFFF1F';           // Rule（暗色分隔线）
const PHOTO_ACCENT: string = '#2E86E0';     // Photo accent dark（照片动作/选中）
const PHOTO_ACCENT_LIGHT: string = '#1673E6'; // Photo accent light（渐变起点）
const PHOTO_SOFT_BORDER: string = '#FFB6CFF5'; // AI 卡浅蓝边框
const POSITIVE_SOFT: string = '#E4F7EE';    // 已连接浅绿底
const READOUT_GLOW: string = '#6BAEFF';     // Readout glow（可写曝光值发光）

// SCOPE_* 示波器轨迹色（五端同名同值）
const SCOPE_R: string = '#FF302A';          // RGB parade R
const SCOPE_G: string = '#28FF69';          // RGB parade G
const SCOPE_B: string = '#2240FF';          // RGB parade B
const SCOPE_AUDIO: string = '#4CC7E8';      // 音频缺失基线
const SCOPE_BG: string = '#050A0F';         // 示波器井背景

// HUD 玻璃遮罩（对齐 Android HUD_* 语义）
const HUD_BG: string = '#AA000000';         // 67% 黑：主 HUD 控件背景
const HUD_BG_SOFT: string = '#99000000';    // 60% 黑：次要控件/胶囊
const HUD_BG_MID: string = '#66000000';     // 40% 黑：关闭/编辑按钮
const HUD_BG_DIM: string = '#55000000';     // 33% 黑：弱遮罩/弹层阴影
const HUD_BG_DARK: string = '#88000000';    // 53% 黑：深色面板
const HUD_SHADOW: string = '#44000000';     // 27% 黑：卡片投影
const HUD_OVERLAY: string = '#F2080A0F';    // 大图弹层全屏背景

// 白色系（alpha 白）
const WHITE: string = '#FFFFFF';
const WHITE_HI: string = '#F0FFFFFF';       // 94% 白
const WHITE_MID: string = '#E0FFFFFF';      // 88% 白
const WHITE_LO: string = '#BFFFFFFF';       // 75% 白
const WHITE_DIM: string = '#99FFFFFF';      // 60% 白
const WHITE_FAINT: string = '#90FFFFFF';    // 56% 白
const BLACK: string = '#000000';

// 专属语义色
const NAV_ACTIVE_BG: string = '#140A84FF';  // 导航选中态背景（UI_BLUE 8%）
const MORE_ACTIVE_BG: string = '#CC055AD2'; // 沉浸参数展开态蓝底
const WHEEL_LIFT: string = '#43B7FF';       // 色轮 Lift
const WHEEL_GAMMA: string = '#C68CFF';      // 色轮 Gamma
const WHEEL_GAIN: string = '#FFD36A';       // 色轮 Gain
const PEAKING_AMBER: string = '#FFE45C';    // 峰值覆盖高亮
const CLOUD_MUTED: string = '#CAD3E0';      // 云创监看关闭态文字
const CLOUD_CARD_BG: string = '#182434';    // 云创监看卡片背景
const CLOUD_CARD_BORDER: string = '#304E70';// 云创监看卡片边框
const WARN_BG: string = '#FFFFEEEE';        // 防诈卡浅红底
const WARN_BG_SOFT: string = '#FFF4B9B9';   // 防诈徽标浅红
const WARN_DEEP: string = '#B21923';        // 防诈深红标题
const WARN_DARK: string = '#75141C';        // 防诈暗红正文
const ACCENT_SOFT: string = '#DDFFD646';    // 等待画面 accent 边框
const PHOTO_GLOW: string = '#24055AD2';     // 品牌蓝投影
const CARD_SHADOW: string = '#14050B18';    // 顶栏/卡片投影

class ControlTile {
  readonly label: string;
  readonly value: string;

  constructor(label: string, value: string) {
    this.label = label;
    this.value = value;
  }
}

function filenameFromPath(path: string): string {
  const index: number = path.lastIndexOf('/');
  return index >= 0 ? path.substring(index + 1) : path;
}

class SelectEntry {
  readonly label: string;
  readonly value: string;

  constructor(label: string, value: string) {
    this.label = label;
    this.value = value;
  }
}

class ScopeDensity {
  readonly columns: number;
  readonly rows: number;
  readonly values: Array<number>;

  constructor(columns: number, rows: number, values: Array<number>) {
    this.columns = columns;
    this.rows = rows;
    this.values = values;
  }
}

class RememberedCameraDevice {
  readonly id: string;
  readonly name: string;
  readonly vendor: string;
  readonly transport: string;
  readonly lastConnectedAt: number;

  constructor(
    id: string,
    name: string,
    vendor: string,
    transport: string,
    lastConnectedAt: number
  ) {
    this.id = id;
    this.name = name;
    this.vendor = vendor;
    this.transport = transport;
    this.lastConnectedAt = lastConnectedAt;
  }
}

class EditorAIAnalysis {
  meanLuma: number = 0;
  contrast: number = 0;
  shadowRatio: number = 0;
  highlightRatio: number = 0;
  saturation: number = 0;
  red: number = 0;
  green: number = 0;
  blue: number = 0;
  detail: number = 0;

  summary(): string {
    if (this.meanLuma < 0.38) {
      return '检测到画面偏暗，已提亮阴影并保护高光';
    }
    if (this.meanLuma > 0.64 || this.highlightRatio > 0.08) {
      return '检测到画面偏亮，已回收高光并恢复层次';
    }
    if (this.contrast < 0.16) {
      return '检测到动态范围偏平，已增强层次与色彩';
    }
    return '曝光均衡，已优化色彩与细节';
  }
}

class EditorCurvePoint {
  x: number;
  y: number;

  constructor(x: number, y: number) {
    this.x = x;
    this.y = y;
  }
}

class EditorMaskPoint {
  x: number;
  y: number;

  constructor(x: number, y: number) {
    this.x = x;
    this.y = y;
  }
}

class EditorMaskStroke {
  readonly id: string;
  readonly subtract: boolean;
  readonly size: number;
  points: Array<EditorMaskPoint>;

  constructor(
    id: string,
    subtract: boolean,
    size: number,
    points: Array<EditorMaskPoint> = []
  ) {
    this.id = id;
    this.subtract = subtract;
    this.size = size;
    this.points = points;
  }
}

class EditorMaskLayer {
  id: string;
  name: string;
  visible: boolean = true;
  type: string = '画笔';
  amount: number = 100;
  feather: number = 55;
  invert: boolean = false;
  subtract: boolean = false;
  brushSize: number = 18;
  strokes: Array<EditorMaskStroke> = [];
  exposure: number = 0;
  contrast: number = 0;
  highlights: number = 0;
  shadows: number = 0;
  temperature: number = 0;
  tint: number = 0;
  saturation: number = 0;
  clarity: number = 0;

  constructor(id: string, name: string) {
    this.id = id;
    this.name = name;
  }

  copy(): EditorMaskLayer {
    const layer = new EditorMaskLayer(this.id, this.name);
    layer.visible = this.visible;
    layer.type = this.type;
    layer.amount = this.amount;
    layer.feather = this.feather;
    layer.invert = this.invert;
    layer.subtract = this.subtract;
    layer.brushSize = this.brushSize;
    layer.strokes = this.strokes.map((stroke: EditorMaskStroke): EditorMaskStroke => {
      return new EditorMaskStroke(
        stroke.id,
        stroke.subtract,
        stroke.size,
        stroke.points.map((point: EditorMaskPoint): EditorMaskPoint => {
          return new EditorMaskPoint(point.x, point.y);
        })
      );
    });
    layer.exposure = this.exposure;
    layer.contrast = this.contrast;
    layer.highlights = this.highlights;
    layer.shadows = this.shadows;
    layer.temperature = this.temperature;
    layer.tint = this.tint;
    layer.saturation = this.saturation;
    layer.clarity = this.clarity;
    return layer;
  }
}

class EditorPreviewRect {
  left: number;
  top: number;
  width: number;
  height: number;

  constructor(left: number, top: number, width: number, height: number) {
    this.left = left;
    this.top = top;
    this.width = width;
    this.height = height;
  }
}

type EditorToneValue = number | string | boolean | Array<Array<number>>;

const EDITOR_CURVE_DEFAULTS: Array<EditorCurvePoint> = [
  new EditorCurvePoint(0, 0),
  new EditorCurvePoint(0.25, 0.25),
  new EditorCurvePoint(0.5, 0.5),
  new EditorCurvePoint(0.75, 0.75),
  new EditorCurvePoint(1, 1)
];

class SystemMediaItem {
  readonly id: string;
  readonly uri: string;
  readonly name: string;
  readonly isVideo: boolean;
  readonly duration: number;

  constructor(
    uri: string,
    name: string,
    isVideo: boolean,
    duration: number
  ) {
    this.id = uri;
    this.uri = uri;
    this.name = name;
    this.isVideo = isVideo;
    this.duration = duration;
  }
}

class CloudProvider {
  readonly name: string;
  readonly note: string;
  readonly url: string;

  constructor(name: string, note: string, url: string) {
    this.name = name;
    this.note = note;
    this.url = url;
  }
}

interface LibraryBranchData {
  id: string;
  name: string;
  children: Array<LibraryBranchData>;
}

interface LibraryFileAssignmentData {
  path: string;
  branchId: string;
}

class LibraryBranch {
  readonly id: string;
  readonly name: string;
  readonly children: Array<LibraryBranch>;

  constructor(
    id: string,
    name: string,
    children: Array<LibraryBranch> = []
  ) {
    this.id = id;
    this.name = name;
    this.children = children;
  }

  toData(): LibraryBranchData {
    return {
      id: this.id,
      name: this.name,
      children: this.children.map(
        (child: LibraryBranch): LibraryBranchData => child.toData()
      )
    };
  }

  static fromData(data: LibraryBranchData): LibraryBranch {
    return new LibraryBranch(
      data.id,
      data.name,
      data.children.map(
        (child: LibraryBranchData): LibraryBranch =>
          LibraryBranch.fromData(child)
      )
    );
  }

  collectIds(ids: Array<string>): void {
    ids.push(this.id);
    this.children.forEach((child: LibraryBranch): void => {
      child.collectIds(ids);
    });
  }
}

const DOMESTIC_CLOUDS: Array<CloudProvider> = [
  new CloudProvider(
    '百度网盘',
    '安装客户端后，从下载目录或系统文件选择器选择。',
    'https://pan.baidu.com/'
  ),
  new CloudProvider(
    '阿里云盘',
    '把照片或视频下载到设备后再选择。',
    'https://www.alipan.com/'
  ),
  new CloudProvider(
    '腾讯微云',
    '从微云导出到本机文件，再回到 帧澈 ZENCHE。',
    'https://www.weiyun.com/'
  ),
  new CloudProvider(
    '夸克网盘',
    '安装夸克网盘客户端并下载需要的媒体。',
    'https://pan.quark.cn/'
  ),
  new CloudProvider(
    '迅雷云盘',
    '通过迅雷客户端下载到设备后选择。',
    'https://pan.xunlei.com/'
  ),
  new CloudProvider(
    '115',
    '在“存储”中下载文件，再从 帧澈 ZENCHE 选择。',
    'https://115.com/'
  )
];

interface GitHubAsset {
  name: string;
  browser_download_url: string;
}

interface GitHubRelease {
  tag_name: string;
  html_url: string;
  assets: Array<GitHubAsset>;
}

interface MirrorChyanVersion {
  version_name: string;
  url?: string;
  update_type?: string;
}

interface MirrorChyanResponse {
  code: number;
  msg: string;
  data?: MirrorChyanVersion;
}

interface SelfHostedAnnouncement {
  title?: string;
  body?: string;
}

interface SelfHostedUpdate {
  schema_version: number;
  product: string;
  version: string;
  url?: string;
  sha256?: string;
  release_url?: string;
  update_type?: string;
  announcement?: SelfHostedAnnouncement;
}

class UpdateCandidate {
  readonly version: string;
  readonly url: string;
  readonly notice: string;

  constructor(version: string, url: string, notice: string = '') {
    this.version = version;
    this.url = url;
    this.notice = notice;
  }
}

class MirrorChyanRequestError extends Error {
  readonly code: number;

  constructor(code: number, message: string) {
    super(`MirrorChyan ${code}: ${message}`);
    this.code = code;
  }
}

function taskLabel(kind: string): string {
  switch (kind) {
    case 'exposure': return '曝光包围';
    case 'focus': return '焦点包围';
    case 'bulb': return 'B 门计时';
    default: return '间隔拍摄';
  }
}

function delay(milliseconds: number): Promise<void> {
  return new Promise<void>((resolve: () => void): void => {
    setTimeout(resolve, milliseconds);
  });
}

const CURRENT_VERSION: string = '1.5.3';
const MIRROR_CHYAN_RESOURCE_ID: string = 'ZENCHE';
const MIRROR_CHYAN_API: string =
  `https://mirrorchyan.com/api/resources/${MIRROR_CHYAN_RESOURCE_ID}/latest`;
const SELF_HOSTED_UPDATE_ENDPOINT: string =
  'https://zenche.top/api/update';
const LATEST_RELEASE_API: string =
  'https://api.github.com/repos/Tauber01/ZENCHE/releases/latest';
const RELEASES_URL: string =
  'https://github.com/Tauber01/ZENCHE/releases';
const AFDIAN_URL: string =
  'https://www.ifdian.net/a/Tauber';
const ZENCHE_WEBSITE_URL: string = 'https://zenche.top';
const AI_ACTIVATION_PUBLIC_KEY: string =
  'MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAngqgOi5fjajCPusMNsfB' +
  'FdMmWyzAGArL5bA+JK/uW+Md/YDtGvXjgSodev7VOQ9SPWqHUYA+XTpdyeCA+weL' +
  '32JhFf+8+a28DjIp7RMv962m1qXJLtcdFbiBjWGDWF+itDJGUgR5OQbxV8xDd/kj' +
  'c1ZT5ft7r2KwECUvwjKr9SAOWGJPK9oNmo9u2kW/6PbjpSEIhDH88FYloNWxpmdW' +
  'XoQ2YYAfd5sKc0CNcBFdu2oEFGFHeUufbhgkZWtDPCS299W4TuWyTDfWPx4+Raap' +
  'bcVF9RfFPa1uI7MpyrOqrGgSnuSC7HxY/B+NXm5rt4p3ZRaOzyKBiZEQ8Sg0XpKI' +
  '3wIDAQAB';
const DISMISSED_ANNOUNCEMENT_VERSION_KEY: string =
  'dismissedLaunchAnnouncementVersion';
const AUTOMATIC_UPDATE_KEY: string = 'automaticallyCheckForUpdates';
const MIRROR_CHYAN_CDK_KEY: string = 'mirrorChyanCdk';
const LIBRARY_BRANCHES_KEY: string = 'libraryUserBranches';
const LIBRARY_FILE_ASSIGNMENTS_KEY: string =
  'libraryFileBranchAssignments';

const EXPOSURE_MODES: Array<SelectEntry> = [
  new SelectEntry('P · 程序自动', 'program'),
  new SelectEntry('S · 快门优先', 'shutterPriority'),
  new SelectEntry('A · 光圈优先', 'aperturePriority'),
  new SelectEntry('M · 手动', 'manual'),
  new SelectEntry('M · B门', 'bulb')
];
const SHUTTER_SPEEDS: Array<SelectEntry> = [
  new SelectEntry('1/8000 s', '0.000125'),
  new SelectEntry('1/6400 s', '0.00015625'),
  new SelectEntry('1/5000 s', '0.0002'),
  new SelectEntry('1/4000 s', '0.00025'),
  new SelectEntry('1/3200 s', '0.0003125'),
  new SelectEntry('1/2500 s', '0.0004'),
  new SelectEntry('1/2000 s', '0.0005'),
  new SelectEntry('1/1600 s', '0.000625'),
  new SelectEntry('1/1250 s', '0.0008'),
  new SelectEntry('1/1000 s', '0.001'),
  new SelectEntry('1/800 s', '0.00125'),
  new SelectEntry('1/640 s', '0.0015625'),
  new SelectEntry('1/500 s', '0.002'),
  new SelectEntry('1/400 s', '0.0025'),
  new SelectEntry('1/320 s', '0.003125'),
  new SelectEntry('1/250 s', '0.004'),
  new SelectEntry('1/200 s', '0.005'),
  new SelectEntry('1/160 s', '0.00625'),
  new SelectEntry('1/125 s', '0.008'),
  new SelectEntry('1/100 s', '0.01'),
  new SelectEntry('1/80 s', '0.0125'),
  new SelectEntry('1/60 s', '0.016667'),
  new SelectEntry('1/50 s', '0.02'),
  new SelectEntry('1/40 s', '0.025'),
  new SelectEntry('1/30 s', '0.033333'),
  new SelectEntry('1/25 s', '0.04'),
  new SelectEntry('1/20 s', '0.05'),
  new SelectEntry('1/15 s', '0.066667'),
  new SelectEntry('1/10 s', '0.1'),
  new SelectEntry('1/8 s', '0.125'),
  new SelectEntry('1/6 s', '0.166667'),
  new SelectEntry('1/4 s', '0.25'),
  new SelectEntry('1/2 s', '0.5'),
  new SelectEntry('1 s', '1'),
  new SelectEntry('1.3 s', '1.3'),
  new SelectEntry('1.6 s', '1.6'),
  new SelectEntry('2 s', '2'),
  new SelectEntry('2.5 s', '2.5'),
  new SelectEntry('3.2 s', '3.2'),
  new SelectEntry('5 s', '5'),
  new SelectEntry('10 s', '10'),
  new SelectEntry('15 s', '15'),
  new SelectEntry('30 s', '30')
];
const VIDEO_FRAME_RATES: Array<SelectEntry> = [
  new SelectEntry('24p', '24'),
  new SelectEntry('25p', '25'),
  new SelectEntry('30p', '30'),
  new SelectEntry('50p', '50'),
  new SelectEntry('60p', '60')
];
const VIDEO_CODECS: Array<SelectEntry> = [
  new SelectEntry('H.264 / AVC · 8-bit', 'h264'),
  new SelectEntry('H.265 / HEVC · 10-bit', 'h265'),
  new SelectEntry('Apple ProRes 422 HQ · 10-bit', 'prores422hq'),
  new SelectEntry('Apple ProRes RAW HQ · 12-bit', 'proresRaw'),
  new SelectEntry('N-RAW · 12-bit NEV', 'nraw')
];
const SONY_VIDEO_CODECS: Array<SelectEntry> = [
  new SelectEntry('XAVC HS 8K · HEVC Long GOP', 'sonyXavcHs8k'),
  new SelectEntry('XAVC HS 4K · HEVC Long GOP', 'sonyXavcHs4k'),
  new SelectEntry('XAVC S 4K · AVC Long GOP', 'sonyXavcS4k'),
  new SelectEntry('XAVC S HD · AVC Long GOP', 'sonyXavcSHd'),
  new SelectEntry('XAVC S-I 4K · AVC Intra', 'sonyXavcSi4k'),
  new SelectEntry('XAVC S-I HD · AVC Intra', 'sonyXavcSiHd')
];
const CANON_VIDEO_CODECS: Array<SelectEntry> = [
  new SelectEntry('RAW · 12-bit', 'canonRaw'),
  new SelectEntry('XF-HEVC S · 4:2:2 10-bit', 'canonXfHevc422'),
  new SelectEntry('XF-HEVC S · 4:2:0 10-bit', 'canonXfHevc420'),
  new SelectEntry('XF-AVC S · 4:2:2 10-bit', 'canonXfAvc422'),
  new SelectEntry('XF-AVC S · 4:2:0 8-bit', 'canonXfAvc420')
];
const NIKON_VIDEO_LOGS: Array<SelectEntry> = [
  new SelectEntry('关闭 · SDR', 'off'),
  new SelectEntry('N-Log', 'nlog')
];
const SONY_VIDEO_LOGS: Array<SelectEntry> = [
  new SelectEntry('关闭 · SDR', 'off'),
  new SelectEntry('PP7 · S-Log2', 'sonySLog2'),
  new SelectEntry('PP8 · S-Log3 / S-Gamut3.Cine', 'sonySLog3Cine'),
  new SelectEntry('PP9 · S-Log3 / S-Gamut3', 'sonySLog3'),
  new SelectEntry('PP10 · HLG', 'sonyHlg')
];
const CANON_VIDEO_LOGS: Array<SelectEntry> = [
  new SelectEntry('关闭 · SDR', 'off'),
  new SelectEntry('Canon Log', 'canonLog'),
  new SelectEntry('Canon Log 2', 'canonLog2'),
  new SelectEntry('Canon Log 3', 'canonLog3')
];
const SHUTTER_ANGLES: Array<SelectEntry> = [
  new SelectEntry('45°', '45'),
  new SelectEntry('60°', '60'),
  new SelectEntry('72°', '72'),
  new SelectEntry('90°', '90'),
  new SelectEntry('108°', '108'),
  new SelectEntry('120°', '120'),
  new SelectEntry('144°', '144'),
  new SelectEntry('150°', '150'),
  new SelectEntry('172.8°', '172.8'),
  new SelectEntry('180°', '180'),
  new SelectEntry('216°', '216'),
  new SelectEntry('240°', '240'),
  new SelectEntry('270°', '270'),
  new SelectEntry('300°', '300'),
  new SelectEntry('324°', '324'),
  new SelectEntry('360°', '360')
];
const APERTURES: Array<SelectEntry> = [
  new SelectEntry('f/1.2', '1.2'),
  new SelectEntry('f/1.4', '1.4'),
  new SelectEntry('f/1.6', '1.6'),
  new SelectEntry('f/1.8', '1.8'),
  new SelectEntry('f/2', '2'),
  new SelectEntry('f/2.2', '2.2'),
  new SelectEntry('f/2.5', '2.5'),
  new SelectEntry('f/2.8', '2.8'),
  new SelectEntry('f/3.2', '3.2'),
  new SelectEntry('f/3.5', '3.5'),
  new SelectEntry('f/4', '4'),
  new SelectEntry('f/4.5', '4.5'),
  new SelectEntry('f/5', '5'),
  new SelectEntry('f/5.6', '5.6'),
  new SelectEntry('f/6.3', '6.3'),
  new SelectEntry('f/7.1', '7.1'),
  new SelectEntry('f/8', '8'),
  new SelectEntry('f/9', '9'),
  new SelectEntry('f/10', '10'),
  new SelectEntry('f/11', '11'),
  new SelectEntry('f/13', '13'),
  new SelectEntry('f/14', '14'),
  new SelectEntry('f/16', '16'),
  new SelectEntry('f/18', '18'),
  new SelectEntry('f/20', '20'),
  new SelectEntry('f/22', '22')
];
const ISO_VALUES: Array<SelectEntry> = [
  new SelectEntry('ISO 64', '64'),
  new SelectEntry('ISO 80', '80'),
  new SelectEntry('ISO 100', '100'),
  new SelectEntry('ISO 125', '125'),
  new SelectEntry('ISO 160', '160'),
  new SelectEntry('ISO 200', '200'),
  new SelectEntry('ISO 250', '250'),
  new SelectEntry('ISO 320', '320'),
  new SelectEntry('ISO 400', '400'),
  new SelectEntry('ISO 500', '500'),
  new SelectEntry('ISO 640', '640'),
  new SelectEntry('ISO 800', '800'),
  new SelectEntry('ISO 1000', '1000'),
  new SelectEntry('ISO 1250', '1250'),
  new SelectEntry('ISO 1600', '1600'),
  new SelectEntry('ISO 2000', '2000'),
  new SelectEntry('ISO 2500', '2500'),
  new SelectEntry('ISO 3200', '3200'),
  new SelectEntry('ISO 4000', '4000'),
  new SelectEntry('ISO 5000', '5000'),
  new SelectEntry('ISO 6400', '6400'),
  new SelectEntry('ISO 8000', '8000'),
  new SelectEntry('ISO 10000', '10000'),
  new SelectEntry('ISO 12800', '12800'),
  new SelectEntry('ISO 16000', '16000'),
  new SelectEntry('ISO 20000', '20000'),
  new SelectEntry('ISO 25600', '25600'),
  new SelectEntry('ISO 32000', '32000'),
  new SelectEntry('ISO 40000', '40000'),
  new SelectEntry('ISO 51200', '51200'),
  new SelectEntry('ISO 64000', '64000'),
  new SelectEntry('ISO 80000', '80000'),
  new SelectEntry('ISO 102400', '102400')
];
const EXPOSURE_COMPENSATIONS: Array<SelectEntry> = [
  new SelectEntry('-2 EV', '-2'),
  new SelectEntry('-1.7 EV', '-1.666667'),
  new SelectEntry('-1.3 EV', '-1.333333'),
  new SelectEntry('-1 EV', '-1'),
  new SelectEntry('-0.7 EV', '-0.666667'),
  new SelectEntry('-0.3 EV', '-0.333333'),
  new SelectEntry('0 EV', '0'),
  new SelectEntry('+0.3 EV', '0.333333'),
  new SelectEntry('+0.7 EV', '0.666667'),
  new SelectEntry('+1 EV', '1'),
  new SelectEntry('+1.3 EV', '1.333333'),
  new SelectEntry('+1.7 EV', '1.666667'),
  new SelectEntry('+2 EV', '2')
];
const FOCUS_MODES: Array<SelectEntry> = [
  new SelectEntry('AF-S · 单次自动对焦', 'single-shot'),
  new SelectEntry('AF-C · 连续自动对焦', 'continuous'),
  new SelectEntry('MF · 手动对焦', 'manual')
];
const WHITE_BALANCES: Array<SelectEntry> = [
  new SelectEntry('自动', 'continuous'),
  new SelectEntry('预设手动', 'manual')
];
const PICTURE_CONTROLS: Array<SelectEntry> = [
  new SelectEntry('自动', 'auto'),
  new SelectEntry('标准', 'standard'),
  new SelectEntry('自然', 'neutral'),
  new SelectEntry('鲜艳', 'vivid'),
  new SelectEntry('单色', 'monochrome'),
  new SelectEntry('人像', 'portrait'),
  new SelectEntry('风景', 'landscape'),
  new SelectEntry('平面', 'flat')
];

@Entry
@Component
struct Index {
  private camera: PtpCamera = new PtpCamera();
  private wifiCamera: PtpIpCamera = new PtpIpCamera();
  private localCamera: LocalCameraController = new LocalCameraController();
  private bluetoothRemote?: BluetoothRemoteController;
  private locationTagging?: LocationTaggingController;
  private library?: PhotoLibrary;
  private captureWorkflow?: CaptureWorkflow;
  private wireless?: WirelessTransferServer;
  private diagnostics?: DiagnosticLogger;
  private settingsPreferences?: preferences.Preferences;
  private previewGeneration: number = 0;
  private previewAnalysisSequence: number = 0;
  private externalVideoRecorder: ExternalVideoRecorder =
    new ExternalVideoRecorder();

  @State private section: string = 'capture';
  @State private language: string = LANGUAGE_SIMPLIFIED_CHINESE;
  @State private connected: boolean = false;
  @State private localCameraSelected: boolean = false;
  @State private wifiConnected: boolean = false;
  @State private wifiConnecting: boolean = false;
  @State private wifiConnectionMode: string = 'ap';
  @State private wifiHost: string = '192.168.1.1';
  @State private wifiPort: string = '15740';
  @State private wifiCameraName: string = 'PTP/IP Camera';
  @State private wifiStatus: string = 'Wi‑Fi 相机未连接';
  @State private bluetoothRemoteEnabled: boolean = false;
  @State private bluetoothRemoteConnected: boolean = false;
  @State private bluetoothRemoteStatus: string = '蓝牙遥控未开启';
  @State private locationTaggingEnabled: boolean = false;
  @State private locationTaggingStatus: string = '定位未开启';
  @State private connectionPanelVisible: boolean = false;
  @State private liveView: boolean = false;
  @State private busy: boolean = false;
  @State private cameraName: string = '未连接';
  @State private rememberedDevices: Array<RememberedCameraDevice> = [];
  @State private cameraVendor: string = 'Nikon';
  @State private status: string = '就绪';
  // v1.5.5 fig1 control page: transport-capsule failure state and grid edit
  // mode are pure UI state; lastConnectionError only drives the status row.
  @State private lastConnectionError: string = '';
  @State private gridEditMode: boolean = false;
  @State private gridHiddenTiles: Array<boolean> = [];
  private readonly gridScroller: Scroller = new Scroller();
  @State private preview: image.PixelMap | undefined = undefined;
  @State private monitorNikonCloudPresetId: string = '';
  @State private monitorFocusPointX: number = -1;
  @State private monitorFocusPointY: number = -1;
  @State private monitorStageWidth: number = 1;
  @State private monitorStageHeight: number = 1;
  @State private photos: Array<PhotoItem> = [];
  @State private wirelessRunning: boolean = false;
  @State private wirelessStatus: string = '无线收件箱未开启';
  @State private wirelessAddress: string = '—';
  @State private exposureMode: string = 'manual';
  @State private videoFrameRate: number = 30;
  @State private videoShutterAngle: number = 180;
  @State private videoShutterMode: string = 'angle';
  @State private videoCodec: string = 'h265';
  @State private nLogEnabled: boolean = false;
  @State private videoLogProfile: string = 'off';
  @State private currentShutterSpeed: number = 0.008;
  @State private currentAperture: number = 4;
  @State private currentIso: number = 400;
  @State private currentCompensation: number = 0;
  @State private shootingTaskKind: string = 'interval';
  @State private shootingTaskCount: number = 5;
  @State private shootingTaskInterval: number = 3;
  @State private shootingTaskStep: number = 1;
  @State private shootingTaskRunning: boolean = false;
  @State private shootingTaskStatus: string = '尚未开始拍摄任务';
  @State private focusPeakingEnabled: boolean = false;
  @State private falseColorEnabled: boolean = false;
  @State private redHistogram: string = '—';
  @State private greenHistogram: string = '—';
  @State private blueHistogram: string = '—';
  @State private waveform: string = '—';
  @State private vectorscope: string = '—';
  @State private peakingCoverage: number = 0;
  private readonly scopeRenderingSettings: RenderingContextSettings =
    new RenderingContextSettings(true);
  private readonly monitorRgbScopeContext: CanvasRenderingContext2D =
    new CanvasRenderingContext2D(this.scopeRenderingSettings);
  private readonly monitorAudioScopeContext: CanvasRenderingContext2D =
    new CanvasRenderingContext2D(this.scopeRenderingSettings);
  private readonly professionalScopeContext: CanvasRenderingContext2D =
    new CanvasRenderingContext2D(this.scopeRenderingSettings);
  private readonly immersiveRgbScopeContext: CanvasRenderingContext2D =
    new CanvasRenderingContext2D(this.scopeRenderingSettings);
  private readonly immersiveAudioScopeContext: CanvasRenderingContext2D =
    new CanvasRenderingContext2D(this.scopeRenderingSettings);
  @State private sessionName: string = '未命名会话';
  @State private sessionNamingTemplate: string =
    '{session}_{date}_{counter}';
  @State private sessionCreator: string = '';
  @State private sessionRights: string = '';
  @State private sessionRating: number = 0;
  @State private sessionDualBackup: boolean = true;
  @State private captureSessionExpanded: boolean = false;
  @State private videoRecording: boolean = false;
  @State private externalRecordToDevice: boolean = true;
  @State private recentLogs: string = '点击“查询最近日志”后显示。';
  @State private updateStatus: string = '尚未检查更新';
  @State private updateChecking: boolean = false;
  @State private automaticUpdates: boolean = true;
  @State private mirrorChyanCdk: string = '';
  @State private availableUpdateUrl: string = '';
  @State private availableVersion: string = '';
  @State private largePreviewVisible: boolean = false;
  @State private largePreviewName: string = '';
  @State private systemMedia: Array<SystemMediaItem> = [];
  @State private systemAlbumStatus: string = '等待相册授权';
  @State private cloudGuideVisible: boolean = false;
  @State private launchAnnouncementVisible: boolean = false;
  @State private showSplash: boolean = true;
  @State private announcementDoNotRemind: boolean = false;
  @State private donationVisible: boolean = false;
  @State private immersivePreviewVisible: boolean = false;
  @State private immersiveMonitoring: boolean = false;
  @State private immersiveParametersExpanded: boolean = true;
  @State private immersiveMoreParametersExpanded: boolean = false;
  @State private immersiveLandscape: boolean = false;
  @State private systemExpanded: boolean = true;
  @State private cameraStorageExpanded: boolean = true;
  @State private cameraStorageBusy: boolean = false;
  @State private cameraStorageStatus: string = '连接相机后可浏览存储卡';
  @State private cameraStorageSnapshot: CameraStorageSnapshot =
    new CameraStorageSnapshot([], []);
  @State private selectedCameraStorageHandles: Array<number> = [];
  @State private systemPhotosExpanded: boolean = true;
  @State private systemVideosExpanded: boolean = true;
  @State private wirelessExpanded: boolean = true;
  @State private localPhotosExpanded: boolean = true;
  @State private localVideosExpanded: boolean = true;
  @State private localUnclassifiedExpanded: boolean = true;
  @State private userLibraryBranches: Array<LibraryBranch> = [];
  @State private expandedLibraryBranchIds: Array<string> = [];
  @State private libraryFileAssignments: Array<LibraryFileAssignmentData> = [];
  @State private draggedPhotoPath: string = '';
  @State private libraryDropTargetId: string = '';
  @State private branchCreatorVisible: boolean = false;
  @State private branchDraft: string = '';
  @State private branchParentId: string = '';
  @State private branchParentName: string = '帧澈 ZENCHE 文件库';
  @State private branchDeleteVisible: boolean = false;
  @State private branchDeleteId: string = '';
  @State private branchDeleteName: string = '';
  @State private mobileBranchDrawerExpanded: boolean = false;
  @State private editorSelectedPath: string = '';
  @State private editorPickerVisible: boolean = false;
  @State private editorPanel: string = 'light';
  @State private editorPreset: string = 'original';
  @State private editorNikonCloudPresetId: string = '';
  @State private editorExposure: number = 0;
  @State private editorContrast: number = 0;
  @State private editorHighlights: number = 0;
  @State private editorShadows: number = 0;
  @State private editorWhites: number = 0;
  @State private editorBlacks: number = 0;
  @State private editorTemperature: number = 0;
  @State private editorTint: number = 0;
  @State private editorVibrance: number = 0;
  @State private editorSaturation: number = 0;
  @State private editorTexture: number = 0;
  @State private editorClarity: number = 0;
  @State private editorSharpening: number = 0;
  @State private editorNoiseReduction: number = 0;
  @State private editorDehaze: number = 0;
  @State private editorVignette: number = 0;
  @State private editorWheelLift: number = 0;
  @State private editorWheelGamma: number = 0;
  @State private editorWheelGain: number = 0;
  @State private editorWheelLiftX: number = 0;
  @State private editorWheelLiftY: number = 0;
  @State private editorWheelGammaX: number = 0;
  @State private editorWheelGammaY: number = 0;
  @State private editorWheelGainX: number = 0;
  @State private editorWheelGainY: number = 0;
  @State private editorCurveContrast: number = 0;
  @State private editorCurvePivot: number = 50;
  @State private editorCurveShadows: number = 0;
  @State private editorCurveMidtones: number = 0;
  @State private editorCurveHighlights: number = 0;
  @State private editorCurvePoints: Array<EditorCurvePoint> = EDITOR_CURVE_DEFAULTS.map((point: EditorCurvePoint): EditorCurvePoint => new EditorCurvePoint(point.x, point.y));
  private editorActiveCurvePoint: number = -1;
  @State private editorMaskEnabled: boolean = false;
  @State private editorMaskType: string = '画笔';
  @State private editorMaskAmount: number = 100;
  @State private editorMaskFeather: number = 55;
  @State private editorMaskInvert: boolean = false;
  @State private editorMaskSubtract: boolean = false;
  @State private editorMaskBrushSize: number = 18;
  @State private editorMaskStrokes: Array<EditorMaskStroke> = [];
  @State private editorMaskExposure: number = 0;
  @State private editorMaskContrast: number = 0;
  @State private editorMaskHighlights: number = 0;
  @State private editorMaskShadows: number = 0;
  @State private editorMaskTemperature: number = 0;
  @State private editorMaskTint: number = 0;
  @State private editorMaskSaturation: number = 0;
  @State private editorMaskClarity: number = 0;
  @State private editorMaskLayers: Array<EditorMaskLayer> = [];
  @State private editorActiveMaskLayerId: string = '';
  @State private editorNextMaskNumber: number = 1;
  private editorActiveMaskStroke: number = -1;
  @State private editorPreviewWidth: number = 1;
  @State private editorPreviewHeight: number = 1;
  @State private editorImageWidth: number = 1;
  @State private editorImageHeight: number = 1;
  @State private editorRenderedPreview: image.PixelMap | undefined = undefined;
  @State private editorMaskOverlay: image.PixelMap | undefined = undefined;
  private editorRenderGeneration: number = 0;
  @State private editorPickerSample: string = 'RGB 取样：尚未取样';
  @State private editorRotation: number = 0;
  @State private editorFlipHorizontal: boolean = false;
  @State private editorFlipVertical: boolean = false;
  @State private editorCropRatio: string = 'original';
  @State private editorShowingOriginal: boolean = false;
  @State private editorSaving: boolean = false;
  @State private aiPrompt: string = '';
  @State private aiManualPrompt: string = '';
  @State private aiSelectedPresets: Array<string> = [];
  @State private aiMode: number = 0; // 0=edit, 1=generate
  @State private aiRatioIndex: number = 0;
  @State private aiResolutionIndex: number = 0;
  @State private aiResultPath: string = '';
  @State private aiGenerating: boolean = false;
  @State private aiStatus: string = '';
  @State private editorTabMode: string = 'pro'; // 'pro' | 'ai'
  @State private aiActivationInput: string = '';
  @State private aiActivationMsg: string = '';
  @State private aiRebindOldDeviceId: string = '';
  @State private aiRebindOldCode: string = '';
  @State private aiRebindBusy: boolean = false;
  @State private editorAIIntensity: number = 72;
  @State private editorAISummary: string = '等待分析当前照片';
  @State private editorAICanUndo: boolean = false;
  @State private editorAIAnalysis: EditorAIAnalysis | undefined = undefined;
  @State private editorAICopiedTone: Array<EditorToneValue> = [];
  private editorAIBackup: Array<EditorToneValue> = [];
  @State private currentFocusMode: string = 'single-shot';
  @State private currentWhiteBalance: string = 'continuous';
  @State private currentPictureControl: string = 'standard';
  @State private currentBreakpoint: string = 'lg';
  private largePreview?: image.PixelMap;
  private shootingTaskGeneration: number = 0;
  private immersiveOrientationListener:
    Callback<sensor.OrientationResponse> =
      (response: sensor.OrientationResponse): void => {
        if (!this.immersivePreviewVisible) {
          return;
        }
        const lateral: number = Math.abs(response.gamma);
        const threshold: number =
          lateral <= Math.PI * 2 ? Math.PI / 4 : 45;
        const nextLandscape: boolean = this.immersiveLandscape
          ? lateral > threshold * 0.66
          : lateral > threshold;
        if (nextLandscape !== this.immersiveLandscape) {
          this.immersiveLandscape = nextLandscape;
        }
      };

  aboutToAppear(): void {
    const context: common.UIAbilityContext =
      getContext(this) as common.UIAbilityContext;
    this.loadLanguage(context);
    this.diagnostics = new DiagnosticLogger(context);
    this.diagnostics.startSession();
    this.library = new PhotoLibrary(context);
    this.captureWorkflow = new CaptureWorkflow(this.library.directoryPath);
    this.bluetoothRemote = new BluetoothRemoteController(
      (status: string, connected: boolean): void => {
        this.bluetoothRemoteStatus = status;
        this.bluetoothRemoteConnected = connected;
      },
      (): void => {
        if (!this.busy && (this.connected || this.wifiConnected)) {
          this.capturePhoto();
        }
      }
    );
    this.locationTagging = new LocationTaggingController(
      (status: string): void => {
        this.locationTaggingStatus = status;
      }
    );
    const session: CaptureSessionConfiguration =
      this.captureWorkflow.configuration;
    this.sessionName = session.name;
    this.sessionNamingTemplate = session.namingTemplate;
    this.sessionCreator = session.creator;
    this.sessionRights = session.rights;
    this.sessionRating = session.rating;
    this.sessionDualBackup = session.dualBackupEnabled;
    this.wireless = new WirelessTransferServer(
      this.library,
      (status: string): void => {
        this.diagnostics?.info('wireless', status);
        this.wirelessStatus = status;
        this.status = status;
      },
      (path: string): void => {
        const name: string = path.substring(path.lastIndexOf('/') + 1);
        this.diagnostics?.info('wireless', `已接收文件；名称=${name}`);
        this.status = `已接收 ${name}`;
        this.refreshPhotos();
      }
    );
    this.refreshPhotos();
  }

  private async loadLanguage(
    context: common.UIAbilityContext
  ): Promise<void> {
    try {
      this.settingsPreferences = await preferences.getPreferences(
        context,
        { name: 'zenche-settings' }
      );
      const saved: preferences.ValueType =
        await this.settingsPreferences.get(
          LANGUAGE_PREFERENCE_KEY,
          LANGUAGE_SIMPLIFIED_CHINESE
        );
      this.language = normalizeLanguage(saved as string);
      const dismissedVersion: preferences.ValueType =
        await this.settingsPreferences.get(
          DISMISSED_ANNOUNCEMENT_VERSION_KEY,
          ''
        );
      this.launchAnnouncementVisible =
        (dismissedVersion as string) !== CURRENT_VERSION;
      const automaticUpdates: preferences.ValueType =
        await this.settingsPreferences.get(
          AUTOMATIC_UPDATE_KEY,
          true
        );
      this.automaticUpdates = automaticUpdates as boolean;
      const externalRecording: preferences.ValueType =
        await this.settingsPreferences.get(
          'externalRecordToDevice',
          true
        );
      this.externalRecordToDevice = externalRecording as boolean;
      const wifiConnectionMode: preferences.ValueType =
        await this.settingsPreferences.get(
          'wifiCameraConnectionMode',
          'ap'
        );
      this.wifiConnectionMode = wifiConnectionMode === 'sta' ? 'sta' : 'ap';
      const wifiHost: preferences.ValueType =
        await this.settingsPreferences.get(
          'wifiCameraHost',
          '192.168.1.1'
        );
      this.wifiHost = wifiHost as string;
      const wifiPort: preferences.ValueType =
        await this.settingsPreferences.get(
          'wifiCameraPort',
          '15740'
        );
      this.wifiPort = wifiPort as string;
      const mirrorChyanCdk: preferences.ValueType =
        await this.settingsPreferences.get(
          MIRROR_CHYAN_CDK_KEY,
          ''
        );
      this.mirrorChyanCdk = mirrorChyanCdk as string;
      const savedBranches: preferences.ValueType =
        await this.settingsPreferences.get(
          LIBRARY_BRANCHES_KEY,
          '[]'
        );
      const branchData: Array<LibraryBranchData> =
        JSON.parse(savedBranches as string) as Array<LibraryBranchData>;
      this.userLibraryBranches = branchData.map(
        (data: LibraryBranchData): LibraryBranch =>
          LibraryBranch.fromData(data)
      );
      this.expandedLibraryBranchIds = this.userLibraryBranches.map(
        (branch: LibraryBranch): string => branch.id
      );
      const savedAssignments: preferences.ValueType =
        await this.settingsPreferences.get(
          LIBRARY_FILE_ASSIGNMENTS_KEY,
          '[]'
        );
      this.libraryFileAssignments = JSON.parse(
        savedAssignments as string
      ) as Array<LibraryFileAssignmentData>;
      const savedDevices: preferences.ValueType =
        await this.settingsPreferences.get(
          'rememberedCameraDevices.v1',
          '[]'
        );
      const deviceData: Array<RememberedCameraDevice> = JSON.parse(
        savedDevices as string
      ) as Array<RememberedCameraDevice>;
      this.rememberedDevices = deviceData
        .map((device: RememberedCameraDevice): RememberedCameraDevice =>
          new RememberedCameraDevice(
            device.id,
            device.name,
            device.vendor,
            device.transport,
            device.lastConnectedAt
          ))
        .sort(
          (left: RememberedCameraDevice, right: RememberedCameraDevice): number =>
            right.lastConnectedAt - left.lastConnectedAt
        );
      if (this.automaticUpdates) {
        setTimeout((): void => {
          this.checkForUpdates(true);
        }, 800);
      }
    } catch (error) {
      this.language = LANGUAGE_SIMPLIFIED_CHINESE;
      this.launchAnnouncementVisible = true;
    }
    setTimeout(() => { this.showSplash = false; }, 2500);
  }

  private async closeLaunchAnnouncement(): Promise<void> {
    if (
      this.announcementDoNotRemind &&
      this.settingsPreferences !== undefined
    ) {
      try {
        await this.settingsPreferences.put(
          DISMISSED_ANNOUNCEMENT_VERSION_KEY,
          CURRENT_VERSION
        );
        await this.settingsPreferences.flush();
      } catch (error) {
        this.diagnostics?.warning(
          'announcement',
          `无法保存公告提醒设置：${(error as BusinessError).message}`
        );
      }
    }
    this.launchAnnouncementVisible = false;
  }

  private changeLanguage(language: string): void {
    const normalized: string = normalizeLanguage(language);
    if (normalized === this.language) {
      return;
    }
    this.language = normalized;
    this.persistLanguage();
  }

  private async persistLanguage(): Promise<void> {
    if (this.settingsPreferences === undefined) {
      return;
    }
    try {
      await this.settingsPreferences.put(
        LANGUAGE_PREFERENCE_KEY,
        this.language
      );
      await this.settingsPreferences.flush();
    } catch (error) {
      this.diagnostics?.warning(
        'settings',
        `无法保存界面语言：${(error as BusinessError).message}`
      );
    }
  }

  private tr(source: string): string {
    return translate(this.language, source);
  }

  aboutToDisappear(): void {
    this.stopImmersiveOrientationTracking();
    this.diagnostics?.endSession();
    this.previewGeneration++;
    this.finishExternalRecordingForDisconnect();
    this.camera.disconnect();
    this.wifiCamera.disconnect();
    this.bluetoothRemote?.stop();
    this.locationTagging?.setEnabled(false);
    if (this.wireless !== undefined) {
      this.wireless.stop();
    }
    if (this.preview !== undefined) {
      this.preview.release();
      this.preview = undefined;
    }
    if (this.largePreview !== undefined) {
      this.largePreview.release();
      this.largePreview = undefined;
    }
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Column() {
        if (this.section === 'capture') {
          this.ControlTopBar()
        } else if (this.section !== 'monitor') {
          this.TopBar()
        }
        if (this.isCompact()) {
          Scroll(this.gridScroller) {
            this.MainGrid()
          }
          .width('100%')
          .layoutWeight(1)
          .scrollBar(BarState.Auto)
          this.CompactBottomNavigation()
        } else {
          this.MainGrid()
        }
        this.GlobalStatusBar()
      }
      .width('100%')
      .height('100%')
      .backgroundColor(
        this.isCameraSection()
          ? UI_BG
          : $r('app.color.paper')
      )
      if (this.largePreviewVisible) {
        this.LargePhotoOverlay()
      }
      if (this.cloudGuideVisible) {
        this.CloudDriveGuideOverlay()
      }
      if (this.branchCreatorVisible) {
        this.LibraryBranchCreatorOverlay()
      }
      if (this.branchDeleteVisible) {
        this.LibraryBranchDeleteOverlay()
      }
      if (this.immersivePreviewVisible) {
        this.ImmersivePreviewOverlay()
      }
      if (this.donationVisible) {
        this.DonationOverlay()
      }
      if (this.launchAnnouncementVisible) {
        this.LaunchAnnouncementOverlay()
      }
      if (this.connectionPanelVisible) {
        this.ConnectionPanelOverlay()
      }
      if (this.showSplash) {
        this.SplashOverlay()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.paper'))
  }

  @Builder
  private GlobalStatusBar() {
    Row({ space: 8 }) {
      Text('●')
        .fontSize(10)
        .fontColor(
          this.connected || this.wifiConnected || this.localCameraSelected
            ? $r('app.color.positive')
            : $r('app.color.graphite_muted')
        )
      Text(this.tr(this.status))
        .fontSize(TS_CAPTION)
        .fontFamily('monospace')
        .fontColor($r('app.color.graphite_ink'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)
      Text(
        this.tr('文件库 · %lld 个文件')
          .replace('%lld', this.photos.length.toString())
      )
        .fontSize(TS_CAPTION)
        .fontFamily('monospace')
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.graphite_muted'))
        .maxLines(1)
    }
    .width('100%')
    .height(44)
    .padding({ left: 14, right: 14 })
    .backgroundColor(UI_BG)
  }

  @Builder
  private SplashOverlay() {
    Column() {
      Column() {
        Row() {
          Text('Z')
            .fontSize(42)
            .fontWeight(FontWeight.Bold)
            .fontColor(Color.White)
        }
        .width(80)
        .height(80)
        .borderRadius(24)
        .linearGradient({
          angle: 135,
          colors: [[PHOTO_ACCENT_LIGHT, 0], [PHOTO_ACCENT, 1]]
        })
        .justifyContent(FlexAlign.Center)
        .scale({ x: 1, y: 1 })
        .animation({ duration: 600, curve: Curve.Friction })
      }
      Column() {
        Text('帧澈 ZENCHE')
          .fontSize(28)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.ink'))
        Text('Capture · Connect · Flow')
          .fontSize(14)
          .fontColor($r('app.color.muted'))
          .margin({ top: 6 })
      }
      .margin({ top: 28 })
      .opacity(1)
      .animation({ duration: 400, curve: Curve.EaseOut })
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.paper'))
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  private MainGrid() {
    GridRow({
      columns: { xs: 4, sm: 4, md: 8, lg: 12 },
      breakpoints: {
        value: ['320vp', '520vp', '840vp'],
        reference: BreakpointsReference.WindowSize
      },
      gutter: { x: 0, y: 0 }
    }) {
      if (!this.isCompact()) {
        GridCol({ span: { xs: 4, sm: 4, md: 8, lg: 2 } }) {
          this.NavigationRail()
        }
      }
      GridCol({
        span: {
          xs: 4,
          sm: 4,
          md: 8,
          lg: this.isCameraSection() ? 7 : 10
        }
      }) {
        if (this.section === 'library') {
          this.LibraryWorkspace()
        } else if (this.section === 'devices') {
          this.MyDevicesWorkspace()
        } else if (this.section === 'editor') {
          this.ImageEditorWorkspace()
        } else if (this.section === 'settings') {
          this.SettingsWorkspace()
        } else {
          this.CameraWorkspace()
        }
      }
      if (this.isCameraSection()) {
        GridCol({ span: { xs: 4, sm: 4, md: 8, lg: 3 } }) {
          this.ParameterPanel()
        }
      }
    }
    .width('100%')
    .height(this.isCompact() ? 'auto' : '100%')
    .layoutWeight(this.isCompact() ? 0 : 1)
    .backgroundColor(
      this.isCameraSection()
        ? UI_BG
        : $r('app.color.paper')
    )
    .onBreakpointChange((breakpoint: string): void => {
      this.currentBreakpoint = breakpoint;
    })
  }

  @Builder
  private ControlTopBar() {
    Row() {
      Button('☰', { type: ButtonType.Normal })
        .width(44)
        .height(44)
        .fontSize(20)
        .fontColor(Color.White)
        .backgroundColor(UI_SECONDARY)
        .borderRadius(14)
        .onClick((): void => {
          this.showControlMenuDialog();
        })
      Text(this.tr('控制'))
        .fontSize(this.isCompact() ? 17 : 19)
        .fontWeight(FontWeight.Bold)
        .fontColor(Color.White)
        .textAlign(TextAlign.Center)
        .layoutWeight(1)
      Button('◉', { type: ButtonType.Normal })
        .width(44)
        .height(44)
        .fontSize(TS_TITLE)
        .fontColor(Color.White)
        .backgroundColor(UI_SECONDARY)
        .borderRadius(14)
        .margin({ right: 8 })
        .onClick((): void => {
          this.section = 'monitor';
        })
      Button('⋯', { type: ButtonType.Normal })
        .width(44)
        .height(44)
        .fontSize(TS_TITLE)
        .fontColor(Color.White)
        .backgroundColor(UI_SECONDARY)
        .borderRadius(14)
        .onClick((): void => {
          this.showControlMenuDialog();
        })
    }
    .width('100%')
    .height(this.isCompact() ? 60 : 64)
    .padding({
      left: this.isCompact() ? 10 : 12,
      right: this.isCompact() ? 10 : 12
    })
    .backgroundColor(UI_BG)
    .border({
      width: { bottom: 1 },
      color: UI_SECONDARY
    })
  }

  /** v1.5.5 fig1 menu: keeps every section reachable from the control page. */
  private showControlMenuDialog(): void {
    promptAction.showActionMenu({
      title: this.tr('菜单'),
      buttons: [
        { text: this.tr('连接 / 断开相机'), color: WHITE },
        { text: this.tr('视频监看'), color: WHITE },
        { text: this.tr('编辑'), color: WHITE },
        { text: this.tr('设备'), color: WHITE },
        { text: this.tr('文件库'), color: WHITE },
        { text: this.tr('设置'), color: WHITE }
      ]
    }).then((response: promptAction.ActionMenuSuccessResponse): void => {
      const targets: Array<string> = [
        'connect', 'monitor', 'editor', 'devices', 'library', 'settings'
      ];
      const target: string = targets[response.index];
      if (target === 'connect') {
        if (this.connected || this.wifiConnected || this.localCameraSelected) {
          this.disconnectFromControlMenu();
        } else {
          this.connectionPanelVisible = true;
        }
        return;
      }
      this.section = target;
    }).catch((): void => {
    });
  }

  private async disconnectFromControlMenu(): Promise<void> {
    if (this.connected) {
      await this.toggleCameraConnection();
    } else if (this.wifiConnected) {
      await this.disconnectWifiCamera();
    } else if (this.localCameraSelected) {
      this.localCameraSelected = false;
      this.status = '本机摄像头已断开';
    }
    this.lastConnectionError = '';
  }

  @Builder
  private TopBar() {
    Row() {
      Row({ space: 12 }) {
        Row() {
          Text('Z')
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
            .fontColor(Color.White)
        }
        .width(this.isCompact() ? 38 : 44)
        .height(this.isCompact() ? 38 : 44)
        .justifyContent(FlexAlign.Center)
        .linearGradient({
          angle: 135,
          colors: [[PHOTO_ACCENT_LIGHT, 0], [PHOTO_ACCENT, 1]]
        })
        .borderRadius(13)
        .shadow({
          radius: 8,
          color: PHOTO_GLOW,
          offsetX: 0,
          offsetY: 4
        })
        Column({ space: 3 }) {
          Text('帧澈 ZENCHE')
            .fontSize(this.isCompact() ? 15 : 20)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.ink'))
          if (!this.isCompact()) {
            Text('Capture · Connect · Flow')
              .fontSize(10)
              .fontFamily('monospace')
              .fontColor($r('app.color.muted'))
            Text(
              this.connected
                ? `${this.cameraName} · USB/PTP`
                : (this.localCameraSelected
                  ? `${this.tr('本机摄像头')} · HARMONYOS`
                : (this.wifiConnected
                  ? `${this.wifiCameraName} · WI‑FI/PTP‑IP`
                  : `${this.tr('未连接')} · HARMONYOS USB/PTP`))
            )
              .fontSize(10)
              .fontFamily('monospace')
              .fontColor($r('app.color.muted'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
      }
      .alignItems(VerticalAlign.Center)
      .layoutWeight(1)
      Text('●')
        .fontSize(13)
        .fontColor(
          this.connected || this.wifiConnected || this.localCameraSelected
            ? $r('app.color.positive')
            : $r('app.color.muted')
        )
        .margin({ right: 8 })
      Button(
        this.isCompact()
          ? this.tr('连接')
          : this.tr('连接管理'),
        {
        type: ButtonType.Normal
        }
      )
        .height(44)
        .padding({
          left: this.isCompact() ? 14 : 20,
          right: this.isCompact() ? 14 : 20
        })
        .fontColor($r('app.color.accent_ink'))
        .backgroundColor($r('app.color.accent'))
        .borderRadius(12)
        .enabled(!this.busy)
        .onClick((): void => {
          this.connectionPanelVisible = true;
        })
      Button('⚙', { type: ButtonType.Normal })
        .fontSize(22)
        .height(44)
        .padding({ left: 12, right: 12 })
        .fontColor($r('app.color.ink'))
        .backgroundColor($r('app.color.surface'))
        .border({
          width: 1,
          color: $r('app.color.rule_strong'),
          radius: 12
        })
        .onClick((): void => {
          this.section = 'settings';
        })
    }
    .width('100%')
    .height(this.isCompact() ? 64 : 76)
    .padding({
      left: this.isCompact() ? 12 : 20,
      right: this.isCompact() ? 12 : 20
    })
    .backgroundColor($r('app.color.surface_raised'))
    .border({
      width: { bottom: 1 },
      color: $r('app.color.rule')
    })
    .shadow({
      radius: 14,
      color: CARD_SHADOW,
      offsetX: 0,
      offsetY: 4
    })
  }

  @Builder
  private NavigationRail() {
    Column({ space: 8 }) {
      Text(this.tr('工作区'))
        .fontSize(TS_CAPTION)
        .fontFamily('monospace')
        .fontColor($r('app.color.muted'))
        .width('100%')
        .margin({ bottom: 8 })
      this.NavButton('照片拍摄', 'capture')
      this.NavButton('视频监看', 'monitor')
      this.NavButton('图像编辑', 'editor')
      this.NavButton('我的设备', 'devices')
      this.NavButton('分支文件库', 'library')
      Blank()
      Text('ZENCHE 1.5.3')
        .fontSize(10)
        .fontFamily('monospace')
        .fontColor($r('app.color.muted'))
    }
    .width('100%')
    .height('100%')
    .padding(16)
    .backgroundColor($r('app.color.paper_2'))
    .border({
      width: { right: 1 },
      color: $r('app.color.rule')
    })
  }

  @Builder
  private CompactBottomNavigation() {
    Row() {
      // v1.5.5 fig1 tab bar: 单机 / 群组 / 已下载 / 设置. The editor stays
      // reachable from the control-page menu and the desktop navigation rail;
      // the video monitor from the control page's viewfinder button.
      this.NavButton('单机', 'capture')
      this.NavButton('群组', 'devices')
      this.NavButton('已下载', 'library')
      this.NavButton('设置', 'settings')
    }
    .width('100%')
    .height(64)
    .padding({ left: 6, right: 6, top: 6, bottom: 4 })
    .backgroundColor(UI_BG)
    .border({
      width: { top: 1 },
      color: UI_SECONDARY
    })
  }

  @Builder
  private NavButton(label: string, target: string) {
    Button(this.tr(label), { type: ButtonType.Normal })
      .width(this.isCompact() ? '25%' : '100%')
      .height(this.isCompact() ? 52 : 44)
      .fontSize(this.isCompact() ? 11 : 14)
      .fontWeight(
        this.section === target ? FontWeight.Bold : FontWeight.Normal
      )
      .fontColor(this.section === target ? UI_BLUE : UI_LABEL)
      .backgroundColor(
        this.section === target ? NAV_ACTIVE_BG : Color.Transparent
      )
      .borderRadius(12)
      .flexShrink(0)
      .onClick((): void => {
        if (target === 'editor') {
          // Navigation opens the stable default; mode changes live in the editor.
          this.editorTabMode = 'pro';
          this.aiResultPath = '';
        }
        this.section = target;
        if (target === 'library') {
          this.refreshPhotos();
          this.loadSystemAlbum();
        } else if (target === 'editor') {
          this.refreshPhotos();
          this.ensureEditorSelection();
        }
      })
  }

  @Builder
  private MyDevicesWorkspace() {
    Scroll() {
      Column({ space: 16 }) {
        Column({ space: 6 }) {
          Text(this.tr('我的设备'))
            .fontSize(30)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.ink'))
          Text(this.tr('管理连接过的相机，轻触即可快速重连'))
            .fontSize(14)
            .fontColor($r('app.color.muted'))
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)

        if (this.rememberedDevices.length === 0) {
          Column({ space: 12 }) {
            Text('◉')
              .fontSize(48)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.accent'))
            Text(this.tr('尚未连接过设备'))
              .fontSize(21)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.ink'))
            Text(this.tr('成功连接相机后会自动保存在这里。'))
              .fontSize(14)
              .fontColor($r('app.color.muted'))
              .textAlign(TextAlign.Center)
          }
          .width('100%')
          .height(360)
          .justifyContent(FlexAlign.Center)
          .backgroundColor($r('app.color.surface_raised'))
          .border({
            width: 1,
            color: $r('app.color.rule'),
            radius: 20
          })
        } else {
          ForEach(
            this.rememberedDevices,
            (device: RememberedCameraDevice): void => {
              this.RememberedDeviceCard(device)
            },
            (device: RememberedCameraDevice): string => device.id
          )
        }
      }
      .width('100%')
      .padding(22)
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Auto)
  }

  @Builder
  private RememberedDeviceCard(device: RememberedCameraDevice) {
    Column() {
      if (device.vendor.toLowerCase().includes('sony')) {
        Image($r('app.media.camera_sony'))
          .width('100%')
          .height(this.isCompact() ? 180 : 230)
          .objectFit(ImageFit.Cover)
      } else if (device.vendor.toLowerCase().includes('canon')) {
        Image($r('app.media.camera_canon'))
          .width('100%')
          .height(this.isCompact() ? 180 : 230)
          .objectFit(ImageFit.Cover)
      } else {
        Image($r('app.media.camera_nikon'))
          .width('100%')
          .height(this.isCompact() ? 180 : 230)
          .objectFit(ImageFit.Cover)
      }
      Column({ space: 11 }) {
        Row() {
          Text(device.name)
            .fontSize(19)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.ink'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
          if (this.connected && this.cameraName === device.name) {
            Text(this.tr('当前已连接'))
              .fontSize(TS_CAPTION)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.positive'))
              .padding({ left: 9, right: 9, top: 5, bottom: 5 })
              .backgroundColor(POSITIVE_SOFT)
              .borderRadius(14)
          }
        }
        .width('100%')
        Text(`${device.vendor} · ${device.transport}`)
          .fontSize(13)
          .fontColor($r('app.color.muted'))
          .width('100%')
        Text(`${this.tr('最近连接')} · ${this.formatDeviceTimestamp(device.lastConnectedAt)}`)
          .fontSize(TS_BODY)
          .fontFamily('monospace')
          .fontColor($r('app.color.muted'))
          .width('100%')
        Row({ space: 10 }) {
          Button(this.tr('快速连接'), { type: ButtonType.Normal })
            .height(44)
            .layoutWeight(1)
            .fontColor($r('app.color.accent_ink'))
            .backgroundColor($r('app.color.accent'))
            .enabled(
              !this.busy &&
              !(this.connected && this.cameraName === device.name)
            )
            .onClick((): void => {
              this.reconnectRememberedDevice();
            })
          Button(this.tr('忘记设备'), { type: ButtonType.Normal })
            .height(44)
            .fontColor($r('app.color.ink'))
            .backgroundColor($r('app.color.surface'))
            .border({
              width: 1,
              color: $r('app.color.rule_strong'),
              radius: 10
            })
            .onClick((): void => {
              this.forgetRememberedDevice(device.id);
            })
        }
        .width('100%')
      }
      .width('100%')
      .padding(16)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .backgroundColor($r('app.color.surface_raised'))
    .border({
      width: 1,
      color: this.connected && this.cameraName === device.name
        ? $r('app.color.positive')
        : $r('app.color.rule'),
      radius: 20
    })
    .borderRadius(20)
  }

  @Builder
  private ImageEditorWorkspace() {
    Column({ space: 12 }) {
      this.EditorModeSwitcher()
      if (this.editorTabMode === 'ai') {
        this.AiToolsWorkspace();
      } else {
        this.ProEditorWorkspace();
      }
    }
  }

  @Builder
  private ResolveEditorWorkbench() {
    // 图 2 移动端降级：控制带（媒体行 + 工具条 + 示波器区）纵向堆叠，
    // 作为监视器下方的「底部抽屉」顶部控制面板；1px 深色分隔。
    Column() {
      this.EditorMediaRail()
      Divider()
        .strokeWidth(1)
        .color(EDITOR_RULE)
      this.EditorToolRail()
      Divider()
        .strokeWidth(1)
        .color(EDITOR_RULE)
      this.EditorScopeDock()
    }
    .width('100%')
    .backgroundColor(EDITOR_BG)
  }

  @Builder
  private EditorMediaRail() {
    // 媒体行：媒体池计数 + 当前照片名 + 非破坏说明（图 2 顶部媒体信息，横向单行）
    Row({ space: 6 }) {
      Text(`${this.tr('媒体池')} · ${this.editablePhotos().length}`)
        .fontSize(EDITOR_FS_SMALL)
        .fontFamily('monospace')
        .fontWeight(FontWeight.Bold)
        .fontColor(EDITOR_LABEL)
      Text(
        this.editorSelectedPath.length > 0
          ? filenameFromPath(this.editorSelectedPath)
          : this.tr('未选择照片')
      )
        .fontSize(TS_BODY)
        .fontFamily('monospace')
        .fontWeight(FontWeight.Bold)
        .fontColor(Color.White)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)
      Text(this.tr('非破坏编辑 · 保存为高质量副本'))
        .fontSize(EDITOR_FS_TINY)
        .fontColor(EDITOR_LABEL)
    }
    .width('100%')
    .height(52)
    .padding({ left: 12, right: 12 })
    .alignItems(VerticalAlign.Center)
    .backgroundColor(EDITOR_PANEL)
  }

  @Builder
  private EditorToolRail() {
    // 工具条：线性单色文字钮 + 品牌橙选中态（图 2 工具图标条语义）
    Row({ space: 4 }) {
      this.EditorWorkbenchTool('色轮', 'wheels')
      this.EditorWorkbenchTool('曲线', 'curves')
      this.EditorWorkbenchTool('蒙版', 'mask')
      this.EditorWorkbenchTool('几何', 'geometry')
      this.EditorWorkbenchTool('AI', 'ai')
    }
    .width('100%')
    .height(52)
    .padding({ left: 2, right: 2, top: 5, bottom: 5 })
    .backgroundColor(EDITOR_PANEL)
  }

  @Builder
  private EditorWorkbenchTool(label: string, panel: string) {
    Button({ type: ButtonType.Normal }) {
      Row({ space: 5 }) {
        Path()
          .width(16)
          .height(16)
          .commands(this.editorToolIconCommands(panel))
          .fillOpacity(0)
          .stroke(this.editorWorkbenchToolActive(panel) ? EDITOR_ACCENT : EDITOR_LABEL)
          .strokeWidth(1.4)
          .strokeLineJoin(LineJoinStyle.Round)
          .strokeLineCap(LineCapStyle.Round)
        Text(this.tr(label))
          .fontSize(TS_CAPTION)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.editorWorkbenchToolActive(panel) ? EDITOR_ACCENT : EDITOR_LABEL)
      }
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
    }
      .height(44)
      .layoutWeight(1)
      .backgroundColor(this.editorWorkbenchToolActive(panel) ? EDITOR_RAISED : Color.Transparent)
      .border({
        width: this.editorWorkbenchToolActive(panel) ? 1 : 0,
        color: this.editorWorkbenchToolActive(panel) ? EDITOR_ACCENT : EDITOR_RULE,
        radius: 0
      })
      .onClick((): void => {
        if (panel === 'ai') {
          this.editorTabMode = 'ai';
          this.aiResultPath = '';
        } else {
          this.editorTabMode = 'pro';
          this.editorPanel = panel;
        }
      })
  }

  private editorToolIconCommands(panel: string): string {
    // fig2 工具条线性单色图标（16x16，五端同几何，P2-2 集成轮）
    switch (panel) {
      case 'wheels':
        return 'M8,1.5 A6.5,6.5 0 1,0 8,14.5 A6.5,6.5 0 1,0 8,1.5 M8,8 L14,8 M8,8 L5,2.8 M8,8 L5,13.2 M8,7.3 A0.7,0.7 0 1,0 8,8.7 A0.7,0.7 0 1,0 8,7.3';
      case 'curves':
        return 'M2,13 C4.5,11.5 5.5,5.5 9,5 C11.5,4.6 12.5,6.5 14,3.5 M8.2,4.6 L9.8,4.6 L9.8,6.2 L8.2,6.2 Z M12.6,6.6 L14.2,6.6 L14.2,8.2 L12.6,8.2 Z';
      case 'mask':
        return 'M3,2 H13 A1,1 0 0,1 14,3 V13 A1,1 0 0,1 13,14 H3 A1,1 0 0,1 2,13 V3 A1,1 0 0,1 3,2 Z M8,8 m-2.5,0 a2.5,2.5 0 1,0 5,0 a2.5,2.5 0 1,0 -5,0';
      case 'geometry':
        return 'M3,9.5 L7,4 L11,9.5 Z M12,5.2 m-1.5,0 a1.5,1.5 0 1,0 3,0 a1.5,1.5 0 1,0 -3,0 M3,11.5 H13 V14 H3 Z';
      default:
        return 'M8,2 L9.3,6.7 L14,8 L9.3,9.3 L8,14 L6.7,9.3 L2,8 L6.7,6.7 Z';
    }
  }

  private editorWorkbenchToolActive(panel: string): boolean {
    return panel === 'ai'
      ? this.editorTabMode === 'ai'
      : this.editorPanel === panel;
  }

  @Builder
  private EditorScopeDock() {
    // 示波器区：面板内嵌，无卡片包装（图 2 波形图语言）
    Row({ space: 10 }) {
      Text(this.tr('编辑示波器'))
        .fontSize(EDITOR_FS_SMALL)
        .fontFamily('monospace')
        .fontWeight(FontWeight.Bold)
        .fontColor(EDITOR_LABEL)
      if (this.editorAIAnalysis === undefined) {
        Text(this.tr('运行“分析画面”后显示实测范围'))
          .fontSize(TS_CAPTION)
          .fontColor(EDITOR_LABEL)
          .layoutWeight(1)
      } else {
        Text(
          `LUMA ${Math.round(this.editorAIAnalysis.meanLuma * 100)}  ` +
          `RANGE ${Math.round(this.editorAIAnalysis.contrast * 100)}  ` +
          `COLOR ${Math.round(this.editorAIAnalysis.saturation * 100)}  ` +
          `DETAIL ${Math.round(this.editorAIAnalysis.detail * 100)}`
        )
          .fontSize(TS_CAPTION)
          .fontFamily('monospace')
          .fontWeight(FontWeight.Bold)
          .fontColor(EDITOR_ACCENT)
          .layoutWeight(1)
      }
    }
    .width('100%')
    .height(64)
    .padding({ left: 12, right: 12 })
    .alignItems(VerticalAlign.Center)
    .backgroundColor(EDITOR_PANEL)
  }

  @Builder
  private EditorModeSwitcher() {
    Row({ space: 8 }) {
      Button(this.editorTabMode === 'pro' ? '● 专业显影' : '○ 专业显影', { type: ButtonType.Normal })
        .height(44)
        .layoutWeight(1)
        .fontColor(this.editorTabMode === 'pro' ? $r('app.color.accent_ink') : $r('app.color.ink'))
        .backgroundColor(this.editorTabMode === 'pro' ? $r('app.color.accent') : $r('app.color.surface'))
        .onClick((): void => {
          this.editorTabMode = 'pro';
          this.aiResultPath = '';
        })
      Button(this.editorTabMode === 'ai' ? '● AI 工具' : '○ AI 工具', { type: ButtonType.Normal })
        .height(44)
        .layoutWeight(1)
        .fontColor(this.editorTabMode === 'ai' ? $r('app.color.accent_ink') : $r('app.color.ink'))
        .backgroundColor(this.editorTabMode === 'ai' ? $r('app.color.accent') : $r('app.color.surface'))
        .onClick((): void => {
          this.editorTabMode = 'ai';
          this.aiResultPath = '';
        })
    }
    .width('100%')
  }

  @Builder
  private ProEditorWorkspace() {
    Column({ space: 16 }) {
      Text(this.tr('专业显影'))
        .fontSize(TS_DISPLAY)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.ink'))
        .width('100%')
      Text(this.tr(
        '分组调整光线、色彩、细节、效果与几何；始终保留原文件。'
      ))
        .fontSize(EDITOR_FS_MEDIUM)
        .fontColor($r('app.color.muted'))
        .width('100%')
      if (this.editablePhotos().length === 0) {
        Column({ space: 8 }) {
          Text(this.tr('文件库中没有可编辑照片'))
            .fontSize(TS_TITLE)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.ink'))
          Text(this.tr(
            '视频与暂不支持解码的 RAW 文件不会进入编辑列表。'
          ))
            .fontSize(EDITOR_FS_SUB)
            .fontColor($r('app.color.muted'))
        }
        .width('100%')
        .height(260)
        .justifyContent(FlexAlign.Center)
        .backgroundColor($r('app.color.surface'))
        .border({
          width: 1,
          color: $r('app.color.rule'),
          radius: 12
        })
      } else {
        this.EditorPhotoPicker()
        // 图 2 移动端降级：监视器固定顶部，控制面板（工具条/媒体/示波器/参数）位于其下
        Stack({ alignContent: Alignment.Center }) {
          if (
            (this.editorMaskEnabled ||
              this.editorNikonCloudPresetId.length > 0) &&
            this.editorRenderedPreview !== undefined
          ) {
            Image(this.editorRenderedPreview)
              .width('100%')
              .height('100%')
              .padding(12)
              .objectFit(ImageFit.Contain)
          } else if (this.editorSelectedPath.length > 0) {
            Image(`file://${this.editorSelectedPath}`)
              .width('100%')
              .height('100%')
              .padding(12)
              .objectFit(ImageFit.Contain)
              .brightness(
                this.editorShowingOriginal
                  ? 1
                  : Math.pow(2, this.editorExposure / 100
                    + this.editorWheelLift / 520
                    + this.editorWheelGain / 700)
              )
              .contrast(
                this.editorShowingOriginal
                  ? 1
                  : Math.max(
                    0,
                    1 + this.editorContrast / 100
                      + this.editorCurveContrast / 180
                      + this.editorDehaze / 250
                      + this.editorClarity / 400
                  )
              )
              .saturate(
                this.editorShowingOriginal
                  ? 1
                  : Math.max(
                    0,
                    1 + this.editorSaturation / 100
                      + this.editorVibrance / 180
                      + this.editorWheelGamma / 900
                      + this.editorDehaze / 500
                  )
              )
              .rotate({
                angle: this.editorShowingOriginal
                  ? 0
                  : this.editorRotation
              })
              .scale({
                x: this.editorShowingOriginal
                  ? 1
                  : (this.editorFlipHorizontal ? -1 : 1),
                y: this.editorShowingOriginal
                  ? 1
                  : (this.editorFlipVertical ? -1 : 1)
              })
          }
          if (
            this.editorPanel === 'mask' &&
            this.editorMaskEnabled &&
            this.activeEditorMaskLayerVisible() &&
            !this.editorShowingOriginal &&
            this.editorMaskOverlay !== undefined
          ) {
            Image(this.editorMaskOverlay)
              .width('100%')
              .height('100%')
              .padding(12)
              .objectFit(ImageFit.Contain)
          }
          Text(this.tr(
            this.editorShowingOriginal ? '原图' : '调整后'
          ))
            .fontSize(TS_CAPTION)
            .fontWeight(FontWeight.Bold)
            .fontColor(Color.White)
            .padding({ left: 10, right: 10, top: 7, bottom: 7 })
            .backgroundColor($r('app.color.graphite'))
            .borderRadius(14)
            .position({ x: 12, y: 12 })
        }
        .width('100%')
        .height(this.isCompact() ? 320 : 460)
        .backgroundColor($r('app.color.graphite'))
        .borderRadius(14)
        .onAreaChange((_oldArea: Area, newArea: Area): void => {
          this.editorPreviewWidth = Math.max(1, Number(newArea.width));
          this.editorPreviewHeight = Math.max(1, Number(newArea.height));
          this.refreshEditorImageMetrics();
        })
        .onTouch((event: TouchEvent): void => {
          this.handleEditorMaskTouch(event);
        })
        Text(this.tr(
          this.editorShowingOriginal ? '正在查看原图' : '调整不会覆盖原文件'
        ))
          .fontSize(TS_CAPTION)
          .fontColor(EDITOR_LABEL)
          .width('100%')
        Divider()
          .strokeWidth(1)
          .color(EDITOR_RULE)
        this.ResolveEditorWorkbench()
        Column({ space: 10 }) {
          Scroll() {
            Row({ space: 8 }) {
            Text(this.tr('AI 智能修图 · 工作台'))
              .fontSize(EDITOR_FS_HEAD)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.ink'))
              .layoutWeight(1)
            Text(this.tr('设备端'))
              .fontSize(TS_CAPTION)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.accent_ink'))
              .padding({ left: 8, right: 8, top: 5, bottom: 5 })
              .backgroundColor($r('app.color.accent_soft'))
              .borderRadius(12)
            }
          }
          .scrollable(ScrollDirection.Horizontal)
          .scrollBar(BarState.Off)
          .width('100%')
          Text(this.tr(this.editorAISummary))
            .fontSize(EDITOR_FS_SUB)
            .fontColor($r('app.color.muted'))
            .width('100%')
          Text(this.tr('设备端处理 · 照片不会上传'))
            .fontSize(TS_CAPTION)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.accent_ink'))
            .width('100%')
          if (this.editorAIAnalysis !== undefined) {
            Row({ space: 6 }) {
              this.EditorAIMetric('曝光', this.editorAIAnalysis.meanLuma)
              this.EditorAIMetric('动态范围', this.editorAIAnalysis.contrast)
              this.EditorAIMetric('色彩', this.editorAIAnalysis.saturation)
              this.EditorAIMetric('细节', this.editorAIAnalysis.detail)
            }
            .width('100%')
          }
          Text(`${this.tr('AI 强度')} · ${this.editorAIIntensity}%`)
            .fontSize(TS_BODY)
            .fontColor($r('app.color.muted'))
            .width('100%')
          Slider({
            value: this.editorAIIntensity,
            min: 35,
            max: 100,
            step: 5,
            style: SliderStyle.OutSet
          })
            .onChange((value: number): void => {
              this.editorAIIntensity = Math.round(value);
            })
          Row({ space: 8 }) {
            Button(this.tr('分析画面'), { type: ButtonType.Normal })
              .height(48)
              .layoutWeight(1)
              .fontColor($r('app.color.ink'))
              .backgroundColor($r('app.color.paper_2'))
              .onClick((): void => {
                this.analyzeEditorPhoto().then((analysis: EditorAIAnalysis | undefined): void => {
                  if (analysis !== undefined) {
                    this.editorAIAnalysis = analysis;
                    this.editorAISummary = analysis.summary();
                    this.status = '画面分析完成 · 可应用 AI 建议';
                  }
                });
              })
            Button(this.tr('智能优化'), { type: ButtonType.Normal })
              .height(48)
              .layoutWeight(1)
              .fontColor($r('app.color.accent_ink'))
              .backgroundColor($r('app.color.accent'))
              .onClick((): void => {
                this.applyEditorAI();
              })
            Button(this.tr('撤销 AI'), { type: ButtonType.Normal })
              .height(48)
              .layoutWeight(1)
              .enabled(this.editorAICanUndo)
              .fontColor($r('app.color.ink'))
              .backgroundColor($r('app.color.paper_2'))
              .onClick((): void => {
                this.undoEditorAI();
              })
            Button(this.tr('复制 AI'), { type: ButtonType.Normal })
              .height(48)
              .layoutWeight(1)
              .enabled(this.editorAICanUndo)
              .fontColor($r('app.color.ink'))
              .backgroundColor($r('app.color.paper_2'))
              .onClick((): void => {
                this.editorAICopiedTone = this.captureEditorTone();
                this.status = '已复制 AI 调整，可应用到下一张照片';
              })
            Button(this.tr('粘贴 AI'), { type: ButtonType.Normal })
              .height(48)
              .layoutWeight(1)
              .enabled(this.editorAICopiedTone.length > 0)
              .fontColor($r('app.color.ink'))
              .backgroundColor($r('app.color.paper_2'))
              .onClick((): void => {
                this.restoreEditorTone(this.editorAICopiedTone);
                this.editorNikonCloudPresetId = '';
                this.editorAISummary = '已粘贴 AI 调整';
                this.status = '已粘贴 AI 调整';
              })
          }
          .width('100%')
        }
        .width('100%')
        .padding(14)
        .backgroundColor($r('app.color.accent_soft'))
        .border({
          width: 1,
          color: $r('app.color.accent'),
          radius: 12
        })
        Select(
          [
            '原始',
            '自然增强',
            '人像柔和',
            '风光通透',
            '高反差黑白'
          ].map((label: string): SelectEntry => {
            return new SelectEntry(label, label);
          })
        )
          .selected(this.editorPresetIndex())
          .width('100%')
          .onSelect((index: number): void => {
            const presets: Array<string> = [
              'original',
              'natural',
              'portrait',
              'landscape',
              'monochrome'
            ];
            this.applyEditorPreset(presets[index]);
          })
        Text(`${this.tr('尼康云创预览')} · ${NIKON_CLOUD_PRESETS.length} NP3`)
          .fontSize(EDITOR_FS_MEDIUM)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.ink'))
          .width('100%')
        Select(this.nikonCloudSelectEntries())
          .selected(this.nikonCloudPresetIndex())
          .width('100%')
          .onSelect((index: number): void => {
            if (index === 0) {
              this.applyEditorPreset('original');
              this.status = '尼康云创预览已关闭';
              return;
            }
            this.applyNikonCloudPreset(NIKON_CLOUD_PRESETS[index - 1]);
          })
        Text(this.tr('设备端 SDR 近似预览 · 相机与 NX Studio 成片可能不同'))
          .fontSize(TS_CAPTION)
          .fontColor($r('app.color.muted'))
          .width('100%')
        // 图 2 移动端降级：监视器 Stack 已上移至照片选择下方（见上方新位置）

        Scroll() {
          Row({ space: 8 }) {
            this.EditorPanelButton('光线', 'light')
            this.EditorPanelButton('色彩', 'color')
            this.EditorPanelButton('色轮', 'wheels')
            this.EditorPanelButton('曲线', 'curves')
            this.EditorPanelButton('取色器', 'picker')
            this.EditorPanelButton('蒙版', 'mask')
            this.EditorPanelButton('细节', 'detail')
            this.EditorPanelButton('效果', 'effects')
            this.EditorPanelButton('几何', 'geometry')
          }
        }
        .width('100%')
        .scrollable(ScrollDirection.Horizontal)
        .scrollBar(BarState.Off)
        this.EditorAdjustmentPanel()

        Row({ space: 8 }) {
          Button(
            this.tr(
              this.editorShowingOriginal ? '返回调整' : '查看原图'
            ),
            { type: ButtonType.Normal }
          )
            .height(48)
            .layoutWeight(1)
            .fontColor($r('app.color.ink'))
            .backgroundColor($r('app.color.paper_2'))
            .onClick((): void => {
              this.editorShowingOriginal = !this.editorShowingOriginal;
            })
          Button(this.tr('全部重置'), { type: ButtonType.Normal })
            .height(48)
            .layoutWeight(1)
            .fontColor($r('app.color.ink'))
            .backgroundColor($r('app.color.paper_2'))
            .onClick((): void => {
              this.resetImageEditor();
            })
          Button(
            this.tr(
              this.editorSaving ? '正在保存…' : '保存高质量副本'
            ),
            { type: ButtonType.Normal }
          )
            .height(48)
            .layoutWeight(1)
            .enabled(!this.editorSaving)
            .fontColor($r('app.color.accent_ink'))
            .backgroundColor($r('app.color.accent'))
            .onClick((): void => {
              this.saveEditedPhoto();
            })
        }
        .width('100%')
      }
    }
    .width('100%')
    .height(this.isCompact() ? 'auto' : '100%')
    .padding(16)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private EditorPhotoPicker() {
    Column({ space: 6 }) {
      Button(this.editorSelectedLabel(), { type: ButtonType.Normal })
        .height(50)
        .width('100%')
        .fontColor($r('app.color.ink'))
        .backgroundColor($r('app.color.surface'))
        .border({ width: 1, color: $r('app.color.rule'), radius: 8 })
        .onClick((): void => {
          this.editorPickerVisible = !this.editorPickerVisible;
        })
      if (this.editorPickerVisible) {
        Column({ space: 4 }) {
          this.EditorPhotoGroup('未分类', this.unclassifiedEditablePhotos(), 0)
          ForEach(
            this.userLibraryBranches,
            (branch: LibraryBranch) => {
              this.EditorPhotoBranch(branch, 0)
            },
            (branch: LibraryBranch): string => branch.id
          )
        }
        .width('100%')
        .padding(8)
        .backgroundColor($r('app.color.surface'))
        .border({ width: 1, color: $r('app.color.rule'), radius: 8 })
      }
    }
    .width('100%')
  }

  @Builder
  private EditorPhotoBranch(branch: LibraryBranch, depth: number) {
    Column({ space: 3 }) {
      Button(
        `${this.isLibraryBranchExpanded(branch.id) ? '⌄' : '›'}  分支 · ${branch.name} · ${this.editablePhotosForBranch(branch.id).length}`,
        { type: ButtonType.Normal }
      )
        .height(44)
        .width('100%')
        .padding({ left: 8 + depth * 14, right: 6 })
        .fontColor($r('app.color.ink'))
        .backgroundColor($r('app.color.paper_2'))
        .onClick((): void => this.toggleLibraryBranch(branch.id))
      if (this.isLibraryBranchExpanded(branch.id)) {
        this.EditorPhotoGroup('', this.editablePhotosForBranch(branch.id), depth + 1)
        ForEach(
          branch.children,
          (child: LibraryBranch) => this.EditorPhotoBranch(child, depth + 1),
          (child: LibraryBranch): string => child.id
        )
      }
    }
    .width('100%')
  }

  @Builder
  private EditorPhotoGroup(title: string, items: Array<PhotoItem>, depth: number) {
    Column({ space: 3 }) {
      if (title.length > 0) {
        Text(`${title} · ${items.length}`)
          .fontSize(TS_BODY)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.muted'))
          .padding({ left: 8 + depth * 14, top: 4, bottom: 2 })
      }
      ForEach(
        items,
        (item: PhotoItem) => {
          Row({ space: 8 }) {
            Image(`file://${item.path}`)
              .width(64)
              .height(46)
              .objectFit(ImageFit.Cover)
              .borderRadius(6)
            Text(item.name)
              .fontSize(TS_BODY)
              .fontColor($r('app.color.ink'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .layoutWeight(1)
            if (item.path === this.editorSelectedPath) {
              Text('✓')
                .fontSize(EDITOR_FS_HEAD)
                .fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.accent'))
            }
          }
          .width('100%')
          .height(58)
          .padding({ left: 8 + depth * 14, right: 8 })
          .backgroundColor(item.path === this.editorSelectedPath
            ? $r('app.color.accent_soft') : $r('app.color.surface'))
          .border({ width: 1, color: item.path === this.editorSelectedPath
            ? $r('app.color.accent') : $r('app.color.rule'), radius: 6 })
          .onClick((): void => {
            this.editorSelectedPath = item.path;
            this.aiResultPath = '';
            this.editorPickerVisible = false;
            this.resetImageEditor();
            this.refreshEditorImageMetrics();
          })
        },
        (item: PhotoItem): string => item.path
      )
      if (items.length === 0) {
        Text(this.tr('此分支暂无可编辑照片'))
          .fontSize(TS_CAPTION)
          .fontColor($r('app.color.muted'))
          .padding({ left: 22 + depth * 14, top: 5, bottom: 5 })
      }
    }
    .width('100%')
  }

  @Builder
  private EditorAIMetric(title: string, value: number) {
    Column({ space: 2 }) {
      Text(this.tr(title))
        .fontSize(EDITOR_FS_SMALL)
        .fontColor($r('app.color.muted'))
      Text(`${Math.round(Math.max(0, Math.min(1, value)) * 100)}%`)
        .fontSize(TS_CAPTION)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.ink'))
    }
    .layoutWeight(1)
    .height(46)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Start)
    .padding({ left: 8, right: 8 })
    .backgroundColor($r('app.color.surface_raised'))
    .borderRadius(8)
  }

  @Builder
  private EditorPanelButton(label: string, panel: string) {
    Button(this.tr(label), { type: ButtonType.Normal })
      .height(44)
      .fontSize(EDITOR_FS_SUB)
      .fontWeight(FontWeight.Bold)
      .fontColor(
        this.editorPanel === panel
          ? $r('app.color.accent_ink')
          : $r('app.color.ink')
      )
      .backgroundColor(
        this.editorPanel === panel
          ? $r('app.color.accent')
          : $r('app.color.surface')
      )
      .border({
        width: 1,
        color: this.editorPanel === panel
          ? $r('app.color.accent')
          : $r('app.color.rule'),
        radius: 22
      })
      .onClick((): void => {
        this.editorPanel = panel;
      })
  }

  @Builder
  private AiToolsWorkspace() {
    Column({ space: 16 }) {
      Text(this.tr('AI 工具'))
        .fontSize(TS_DISPLAY)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.ink'))
        .width('100%')
      Text(this.tr('基于 nano-banana-2 模型的 AI 修图与生图；需在设置中配置 API Key。'))
        .fontSize(EDITOR_FS_MEDIUM)
        .fontColor($r('app.color.muted'))
        .width('100%')

      Row({ space: 10 }) {
        Column({ space: 3 }) {
          Text(this.tr('AI 创作'))
            .fontSize(EDITOR_FS_HEAD)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.ink'))
          Text(this.tr('修图覆盖原图 · 生图保存新文件'))
            .fontSize(TS_CAPTION)
            .fontColor($r('app.color.muted'))
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        Text(this.checkAiActivated()
          ? `${this.tr('已解锁')} · ${this.getRemainingUsage()} ${this.tr('次剩余')}`
          : this.tr('需要激活'))
          .fontSize(TS_CAPTION)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.checkAiActivated()
            ? $r('app.color.positive')
            : $r('app.color.muted'))
          .padding({ left: 10, right: 10, top: 6, bottom: 6 })
          .backgroundColor(this.checkAiActivated()
            ? $r('app.color.accent_soft')
            : $r('app.color.paper_2'))
          .borderRadius(14)
      }
      .width('100%')
      .padding(12)
      .backgroundColor($r('app.color.surface'))
      .border({ width: 1, color: $r('app.color.rule'), radius: 12 })

      if (this.aiMode === 0 && this.editablePhotos().length > 0) {
        this.EditorPhotoPicker()
        if (this.aiResultPath.length === 0 && this.editorSelectedPath.length > 0) {
          Text(this.tr('已选择原图'))
            .fontSize(TS_CAPTION)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.muted'))
            .width('100%')
          Image(`file://${this.editorSelectedPath}`)
            .width('100%')
            .height(this.isCompact() ? 300 : 420)
            .objectFit(ImageFit.Contain)
            .backgroundColor($r('app.color.graphite'))
            .borderRadius(14)
            .padding(12)
        }
      }

      Row({ space: 8 }) {
        Button(this.aiMode === 0 ? '● AI 修图' : '○ AI 修图', { type: ButtonType.Normal })
          .height(44)
          .layoutWeight(1)
          .fontColor(this.aiMode === 0 ? $r('app.color.accent_ink') : $r('app.color.ink'))
          .backgroundColor(this.aiMode === 0 ? $r('app.color.accent') : $r('app.color.surface'))
          .onClick((): void => {
            this.aiMode = 0;
            this.aiResultPath = '';
            this.composeAiPrompt();
          })
        Button(this.aiMode === 1 ? '● AI 生图' : '○ AI 生图', { type: ButtonType.Normal })
          .height(44)
          .layoutWeight(1)
          .fontColor(this.aiMode === 1 ? $r('app.color.accent_ink') : $r('app.color.ink'))
          .backgroundColor(this.aiMode === 1 ? $r('app.color.accent') : $r('app.color.surface'))
          .onClick((): void => {
            this.aiMode = 1;
            this.aiResultPath = '';
            this.composeAiPrompt();
          })
      }
      .width('100%')

      TextArea({ placeholder: this.aiMode === 0 ? '输入修图描述…（可补充）' : '输入生图描述…（可补充）', text: this.aiManualPrompt })
        .height(80)
        .fontSize(EDITOR_FS_MEDIUM)
        .onChange((value: string): void => {
          this.aiManualPrompt = value;
          this.composeAiPrompt();
        })

      Text(this.tr('输出参数'))
        .fontSize(TS_BODY)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.muted'))
        .width('100%')
      Row({ space: 8 }) {
        Select([
          '1:1',
          '16:9',
          '9:16',
          '4:3',
          '3:2'
        ].map((label: string): SelectEntry => {
          return new SelectEntry(label, label);
        }))
          .selected(this.aiRatioIndex)
          .layoutWeight(1)
          .height(44)
          .onSelect((index: number): void => {
            this.aiRatioIndex = index;
          })
        Select([
          '1K',
          '2K',
          '4K'
        ].map((label: string): SelectEntry => {
          return new SelectEntry(label, label);
        }))
          .selected(this.aiResolutionIndex)
          .layoutWeight(1)
          .height(44)
          .onSelect((index: number): void => {
            this.aiResolutionIndex = index;
          })
      }
      .width('100%')

      Button(this.aiGenerating ? '正在生成…' : '生成图像', { type: ButtonType.Normal })
        .height(48)
        .width('100%')
        .enabled(
          this.aiPrompt.trim().length > 0
            && !this.aiGenerating
            && (this.aiMode !== 0 || this.editorSelectedPath.length > 0)
        )
        .fontColor($r('app.color.accent_ink'))
        .backgroundColor($r('app.color.accent'))
        .onClick((): void => {
          this.doAiGenerate();
        })

      Row() {
        Text('可组合预设')
          .fontSize(TS_BODY)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.muted'))
          .layoutWeight(1)
        Button('清空', { type: ButtonType.Normal })
          .height(44)
          .fontSize(TS_CAPTION)
          .backgroundColor($r('app.color.surface'))
          .onClick((): void => {
            this.aiSelectedPresets = [];
            this.aiManualPrompt = '';
            this.composeAiPrompt();
          })
      }
      .width('100%')
      ForEach(this.getAiModules(), (module: Array<string>) => {
        Text(this.tr(module[0]))
          .fontSize(EDITOR_FS_SMALL)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.muted'))
          .width('100%')
        Scroll() {
          Row({ space: 6 }) {
            ForEach(module.slice(1), (value: string) => {
              Button(this.tr(value), { type: ButtonType.Normal })
                .height(44)
                .fontSize(TS_CAPTION)
                .fontColor($r('app.color.ink'))
                .backgroundColor(this.isAiPresetSelected(module[0], value)
                  ? $r('app.color.accent_soft') : $r('app.color.surface'))
                .border({ width: 1, color: this.isAiPresetSelected(module[0], value)
                  ? $r('app.color.accent') : $r('app.color.rule'), radius: 8 })
                .padding({ left: 12, right: 12 })
                .onClick((): void => {
                  this.toggleAiPreset(module[0], value);
                  this.composeAiPrompt();
                })
            }, (value: string) => `${module[0]}-${value}`)
          }
        }
        .scrollable(ScrollDirection.Horizontal)
        .scrollBar(BarState.Off)
        .width('100%')
      }, (module: Array<string>) => module[0])

      if (this.aiResultPath.length > 0) {
        Image(`file://${this.aiResultPath}`)
          .width('100%')
          .height(this.isCompact() ? 320 : 460)
          .objectFit(ImageFit.Contain)
          .backgroundColor($r('app.color.graphite'))
          .borderRadius(14)
          .padding(12)

        Button(this.editorSaving ? '正在保存…' : '保存到文件库', { type: ButtonType.Normal })
          .height(48)
          .width('100%')
          .enabled(!this.editorSaving)
          .fontColor($r('app.color.accent_ink'))
          .backgroundColor($r('app.color.accent'))
          .onClick((): void => {
            this.saveAiResult();
          })
      }

      if (this.aiStatus.length > 0 || this.aiGenerating) {
        Text(this.aiGenerating ? '正在调用 AI 模型…' : this.aiStatus)
          .fontSize(TS_CAPTION)
          .fontColor($r('app.color.muted'))
          .width('100%')
          .textAlign(TextAlign.Start)
      }
    }
    .width('100%')
    .height(this.isCompact() ? 'auto' : '100%')
    .padding(16)
    .alignItems(HorizontalAlign.Start)
  }

  private getAiPresets(): Array<Array<string>> {
    if (this.aiMode === 0) {
      return [
        ['一键美颜', '对照片中的人物进行自然美颜：柔化皮肤、去除瑕疵、提亮肤色、轻微瘦脸，保持自然真实质感，不过度处理。'],
        ['自然增强', '增强照片的自然色彩与光影：提升饱和度与对比度，保留真实细节，使画面更通透清晰。'],
        ['胶片质感', '为照片添加复古胶片质感：轻微颗粒、柔和对比、温暖色调，类似柯达 Portra 胶片的色彩风格。'],
        ['日系清新', '调整为日系清新风格：低对比度、偏亮高调、冷色调、干净通透，画面清新柔和。'],
        ['黑白大片', '转换为高反差黑白摄影风格：增强明暗对比、保留细节纹理，营造经典黑白大片质感。'],
        ['复古暖调', '添加复古暖调风格：整体偏暖黄色调、轻微褪色、柔和光线，怀旧氛围。'],
        ['天空增强', '增强画面中的天空：让蓝天更通透湛蓝、云朵更立体，同时保持地面细节自然。'],
        ['美食诱人', '增强美食照片的诱人质感：提升色彩饱和度、增强光泽细节，让食物看起来更美味。']
      ];
    }
    return [
      ['人像写真', 'professional portrait photography, studio lighting, sharp focus, shallow depth of field, high detail'],
      ['风光大片', 'breathtaking landscape photography, golden hour, dramatic sky, high dynamic range, ultra detailed'],
      ['城市夜景', 'city night photography, neon lights, long exposure, reflections, vibrant urban atmosphere'],
      ['产品展示', 'professional product photography, clean studio background, soft lighting, high detail']
    ];
  }

  private getAiModules(): Array<Array<string>> {
    const modules: Array<Array<string>> = [
      ['主体', '人像主体', '产品主体', '建筑主体', '风光主体', '食物主体'],
      ['光线', '柔和自然光', '电影感侧光', '金色时刻', '低调棚拍光', '夜景霓虹光'],
      ['色彩', '自然通透', '胶片暖调', '日系清新', '高反差黑白', '冷色城市'],
      ['质感', '保留真实皮肤纹理', '细节清晰', '轻微胶片颗粒', '柔和高光', '高动态范围'],
      ['构图', '浅景深', '干净背景', '对称构图', '环境叙事', '视觉焦点明确']
    ];
    if (this.aiMode === 0) {
      modules.push([
        '智能移除',
        '去路人并自然补全背景',
        '去穿帮并移除摄影器材、工作人员、反光与杂物'
      ]);
      modules.push([
        '约束',
        '保持人物身份和五官',
        '不改变产品形状',
        '不添加多余物体',
        '不过度磨皮',
        '保留自然阴影'
      ]);
    }
    return modules;
  }

  private isAiPresetSelected(category: string, value: string): boolean {
    return this.aiSelectedPresets.indexOf(`${category}:${value}`) >= 0;
  }

  private toggleAiPreset(category: string, value: string): void {
    const key = `${category}:${value}`;
    const selected = this.isAiPresetSelected(category, value);
    this.aiSelectedPresets = this.aiSelectedPresets.filter((entry: string): boolean => !entry.startsWith(`${category}:`));
    if (!selected) this.aiSelectedPresets.push(key);
  }

  private composeAiPrompt(): void {
    const groups: Array<string> = [];
    if (this.aiManualPrompt.trim().length > 0) groups.push(this.aiManualPrompt.trim());
    this.getAiModules().forEach((module: Array<string>): void => {
      const values = this.aiSelectedPresets
        .filter((entry: string): boolean => entry.startsWith(`${module[0]}:`))
        .map((entry: string): string => entry.substring(module[0].length + 1));
      if (values.length > 0) groups.push(`${module[0]}：${values.join('、')}`);
    });
    this.aiPrompt = groups.join('。');
  }

  private async doAiGenerate(): Promise<void> {
    if (this.aiPrompt.trim().length === 0) {
      this.aiStatus = '请输入提示词';
      return;
    }
    if (!this.checkAiActivated()) {
      this.aiStatus = '请先在设置中输入激活码解锁 AI 功能';
      return;
    }
    const activationCode: string = this.getAiActivationCode();
    if (activationCode.length === 0) {
      this.aiStatus = '请先在设置中输入激活码解锁 AI 功能';
      return;
    }
    this.aiGenerating = true;
    this.aiStatus = '正在调用 AI 模型…';
    try {
      const httpRequest = http.createHttp();
      const serverUrl: string = this.getAiServerUrl();
      const endpoint: string = `${serverUrl}/v1/ai`;
      const sizes: Array<string> = ['1024x1024', '1792x1024', '1024x1792', '1365x1024', '1536x1024'];
      const body: Record<string, Object> = {
        'activationCode': activationCode,
        'deviceId': this.getDeviceId(),
        'prompt': this.aiPrompt,
        'size': sizes[this.aiRatioIndex]
      };
      if (this.aiMode === 0 && this.editorSelectedPath.length > 0) {
        const library: PhotoLibrary | undefined = this.library;
        if (library) {
          const photoItems: Array<PhotoItem> = this.editablePhotos();
          let srcBytes: ArrayBuffer | null = null;
          for (let i = 0; i < photoItems.length; i++) {
            const item: PhotoItem | undefined = photoItems[i];
            if (item && item.path === this.editorSelectedPath) {
              srcBytes = library.read(item).buffer as ArrayBuffer;
              break;
            }
          }
          if (srcBytes && srcBytes.byteLength > 0) {
            const base64Helper = new util.Base64Helper();
            const b64: string = base64Helper.encodeToStringSync(new Uint8Array(srcBytes));
            body['image'] = `data:${this.imageMimeType(this.editorSelectedPath)};base64,${b64}`;
          } else {
            throw new Error('无法读取原图，未发送 AI 修图请求');
          }
        } else if (this.aiMode === 0) {
          throw new Error('无法读取原图，未发送 AI 修图请求');
        }
      }
      const response = await httpRequest.request(
        endpoint,
        {
          method: http.RequestMethod.POST,
          header: {
            'Content-Type': 'application/json',
          },
          // Send explicit JSON so the reference image is not dropped by the
          // HTTP client while coercing a Record into request data.
          extraData: JSON.stringify(body),
          connectTimeout: 15000,
          // Keep the request alive while the proxy polls and downloads output.
          readTimeout: 300000,
        }
      );
      httpRequest.destroy();
      const responseText: string = response.result as string;
      let serverMessage: string = '';
      if (response.responseCode !== 200 && responseText.length > 0) {
        try {
          const errorResult: Record<string, Object> = JSON.parse(
            responseText
          ) as Record<string, Object>;
          serverMessage = (errorResult['error'] as string) || '';
        } catch (_) {
          serverMessage = '';
        }
      }
      if (response.responseCode === 403) {
        this.aiGenerating = false;
        this.aiStatus = serverMessage || '激活码无效或次数用完';
        return;
      }
      if (response.responseCode === 502) {
        this.aiGenerating = false;
        this.aiStatus = serverMessage || 'AI 服务暂时不可用';
        return;
      }
      if (response.responseCode !== 200) {
        throw new Error(serverMessage || `AI 服务返回错误 ${response.responseCode}`);
      }
      const result: Record<string, Object> = JSON.parse(
        responseText
      ) as Record<string, Object>;
      const dataArr: Array<Record<string, Object>> =
        result['data'] as Array<Record<string, Object>>;
      if (!dataArr || dataArr.length === 0) {
        throw new Error('AI 未返回有效图片');
      }
      const first: Record<string, Object> = dataArr[0];
      let imageBytes: ArrayBuffer | null = null;
      const b64Json: string = (first['b64_json'] as string) || '';
      if (b64Json.length > 0) {
        const base64Helper = new util.Base64Helper();
        imageBytes = base64Helper.decodeSync(b64Json).buffer as ArrayBuffer;
      } else {
        const imageUrl: string = (first['url'] as string) || '';
        if (imageUrl.length > 0) {
          const imgRequest = http.createHttp();
          const imgResponse = await imgRequest.request(imageUrl, {
            method: http.RequestMethod.GET,
            connectTimeout: 15000,
            readTimeout: 30000,
          });
          imageBytes = (imgResponse.result as ArrayBuffer);
          imgRequest.destroy();
        }
      }
      if (!imageBytes || imageBytes.byteLength === 0) {
        throw new Error('AI 未返回有效图片');
      }
      const remaining: number | undefined = this.parseAiRemaining(
        response.header as Record<string, string>
      );
      if (remaining !== undefined) {
        this.setAiRemainingUsage(remaining);
      } else {
        // Keep compatibility with older proxies that did not expose a count.
        this.recordAiUsage();
      }
      const context: common.UIAbilityContext =
        getContext(this) as common.UIAbilityContext;
      const tempDir: string = context.tempDir;
      const tempPath: string = `${tempDir}/ai_result_${Date.now()}.jpg`;
      const file = fs.openSync(tempPath, fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY);
      fs.writeSync(file.fd, imageBytes);
      fs.closeSync(file);
      this.aiResultPath = tempPath;
      this.aiStatus = '生成完成';
      this.aiGenerating = false;
    } catch (err) {
      this.aiGenerating = false;
      const rawMessage: string = (err as Error).message || 'AI 生成失败';
      const msg: string = rawMessage.toLowerCase().indexOf('timeout') >= 0 ||
        rawMessage.indexOf('超时') >= 0
        ? 'AI 生成超时，请稍后重试'
        : rawMessage;
      this.aiStatus = `生成失败：${msg}`;
    }
  }

  private async saveAiResult(): Promise<void> {
    if (this.aiResultPath.length === 0) {
      return;
    }
    this.editorSaving = true;
    try {
      const file: fs.File = fs.openSync(this.aiResultPath, fs.OpenMode.READ_ONLY);
      let data: ArrayBuffer;
      try {
        const stat: fs.Stat = fs.statSync(this.aiResultPath);
        const buffer: ArrayBuffer = new ArrayBuffer(stat.size);
        fs.readSync(file.fd, buffer);
        data = buffer;
      } finally {
        fs.closeSync(file);
      }
      const stem: string = this.aiMode === 0 ? 'edited' : 'generated';
      const library: PhotoLibrary | undefined = this.library;
      if (!library) {
        this.editorSaving = false;
        this.aiStatus = '保存 AI 结果失败';
        return;
      }
      const destination: string = this.aiMode === 0 && this.editorSelectedPath.length > 0
        ? library.replaceFile(this.editorSelectedPath, new Uint8Array(data))
        : library.saveEditedCopy(`ai_${stem}`, new Uint8Array(data));
      this.refreshPhotos();
      this.editorSelectedPath = destination;
      this.aiStatus = `已保存 AI 结果 · ${destination.split('/').pop()}`;
      this.editorSaving = false;
    } catch (err) {
      this.editorSaving = false;
      this.aiStatus = '保存 AI 结果失败';
    }
  }

  private checkAiActivated(): boolean {
    try {
      const prefs = preferences.getPreferencesSync(
        getContext(this) as common.UIAbilityContext,
        { name: 'zenche_ai_settings' }
      );
      const activated: boolean = (prefs.getSync('ai_activated', false) as boolean) || false;
      const count: number = (prefs.getSync('ai_usage_count', 0) as number) || 0;
      return activated && count < 100;
    } catch (_) {
      return false;
    }
  }

  private recordAiUsage(): void {
    try {
      const prefs = preferences.getPreferencesSync(
        getContext(this) as common.UIAbilityContext,
        { name: 'zenche_ai_settings' }
      );
      const count: number = ((prefs.getSync('ai_usage_count', 0) as number) || 0) + 1;
      prefs.putSync('ai_usage_count', count);
      prefs.flushSync();
      if (count >= 100) {
        prefs.putSync('ai_activated', false);
        prefs.flushSync();
      }
    } catch (_) {}
  }

  private parseAiRemaining(
    headers: Record<string, string>
  ): number | undefined {
    const raw: string = headers['X-ZENCHE-Remaining']
      || headers['x-zenche-remaining']
      || '';
    if (raw.length === 0) {
      return undefined;
    }
    const value: number = Number(raw);
    if (!Number.isFinite(value)) {
      return undefined;
    }
    return Math.max(0, Math.min(100, Math.floor(value)));
  }

  private imageMimeType(path: string): string {
    const lower: string = path.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.heic') || lower.endsWith('.heif')) return 'image/heic';
    if (lower.endsWith('.tif') || lower.endsWith('.tiff')) return 'image/tiff';
    if (lower.endsWith('.bmp')) return 'image/bmp';
    return 'image/jpeg';
  }

  private setAiRemainingUsage(remaining: number): void {
    try {
      const prefs = preferences.getPreferencesSync(
        getContext(this) as common.UIAbilityContext,
        { name: 'zenche_ai_settings' }
      );
      const bounded: number = Math.max(0, Math.min(100, remaining));
      prefs.putSync('ai_usage_count', 100 - bounded);
      prefs.putSync('ai_activated', bounded > 0);
      prefs.flushSync();
      if (bounded === 0) {
        this.aiStatus = 'AI 次数已用完';
      }
    } catch (_) {
    }
  }

  private getRemainingUsage(): number {
    try {
      const prefs = preferences.getPreferencesSync(
        getContext(this) as common.UIAbilityContext,
        { name: 'zenche_ai_settings' }
      );
      const count: number = (prefs.getSync('ai_usage_count', 0) as number) || 0;
      return Math.max(0, 100 - count);
    } catch (_) {
      return 0;
    }
  }

  private getDeviceId(): string {
    try {
      const prefs = preferences.getPreferencesSync(
        getContext(this) as common.UIAbilityContext,
        { name: 'zenche_ai_settings' }
      );
      let id: string = prefs.getSync('ai_device_id', '') as string;
      if (id.length > 0) {
        return id;
      }
      id = util.generateRandomUUID();
      prefs.putSync('ai_device_id', id);
      prefs.flush();
      return id;
    } catch (_) {
      return '';
    }
  }

  private getAiServerUrl(): string {
    try {
      const prefs = preferences.getPreferencesSync(
        getContext(this) as common.UIAbilityContext,
        { name: 'zenche_ai_settings' }
      );
      const url: string = (prefs.getSync('ai_server_url', 'http://101.34.255.115:8787') as string) || 'http://101.34.255.115:8787';
      return url;
    } catch (_) {
      return 'http://101.34.255.115:8787';
    }
  }

  private copyDeviceIdToClipboard(): void {
    try {
      const pb = pasteboard.getSystemPasteboard();
      const data = pasteboard.createData(
        pasteboard.MIMETYPE_TEXT_PLAIN,
        this.getDeviceId()
      );
      pb.setData(data);
      this.aiActivationMsg = '设备 ID 已复制，可前往官网兑换密钥';
    } catch (_) {
      this.aiActivationMsg = '复制设备 ID 失败';
    }
  }

  private getAiActivationCode(): string {
    try {
      const prefs = preferences.getPreferencesSync(
        getContext(this) as common.UIAbilityContext,
        { name: 'zenche_ai_settings' }
      );
      return (prefs.getSync('ai_activation_code', '') as string) || '';
    } catch (_) {
      return '';
    }
  }

  private verifyActivationCodeForDevice(code: string, deviceId: string): boolean {
    const trimmed: string = code.trim();
    const targetDeviceId: string = deviceId.trim();
    if (trimmed.length === 0 || targetDeviceId.length === 0) {
      return false;
    }
    const parts: Array<string> = trimmed.split('-');
    if (parts.length < 4 || parts[0] !== 'ZENCHE' || parts[1] !== 'AI') {
      return false;
    }
    const expiryPart: string = parts[parts.length - 1];
    if (!/^\d{8}$/.test(expiryPart)) {
      return false;
    }
    const expiryYear: number = parseInt(expiryPart.substring(0, 4));
    const expiryMonth: number = parseInt(expiryPart.substring(4, 6));
    const expiryDay: number = parseInt(expiryPart.substring(6, 8));
    const now: Date = new Date();
    const expiryDate: Date = new Date(
      expiryYear,
      expiryMonth - 1,
      expiryDay,
      23,
      59,
      59,
      999
    );
    if (expiryDate.getFullYear() !== expiryYear ||
      expiryDate.getMonth() !== expiryMonth - 1 ||
      expiryDate.getDate() !== expiryDay ||
      expiryDate < now) {
      return false;
    }
    const payload: string = `${targetDeviceId}:${expiryPart}:a1b2c3d4e5f6`;
    const signaturePart: string = parts.slice(2, parts.length - 1).join('-');
    try {
      const base64Helper = new util.Base64Helper();
      const publicKeyBlob: cryptoFramework.DataBlob = {
        data: base64Helper.decodeSync(AI_ACTIVATION_PUBLIC_KEY)
      };
      const signatureBlob: cryptoFramework.DataBlob = {
        data: base64Helper.decodeSync(signaturePart)
      };
      const payloadBlob: cryptoFramework.DataBlob = {
        data: new util.TextEncoder().encode(payload)
      };
      const generator = cryptoFramework.createAsyKeyGenerator('RSA2048');
      const keyPair = generator.convertKeySync(publicKeyBlob, null);
      const verifier = cryptoFramework.createVerify('RSA2048|PKCS1|SHA256');
      verifier.initSync(keyPair.pubKey);
      if (!verifier.verifySync(payloadBlob, signatureBlob)) {
        return false;
      }
    } catch (_) {
      return false;
    }
    return true;
  }

  private saveVerifiedActivation(code: string, remaining: number): void {
    const bounded: number = Math.max(0, Math.min(100, remaining));
    const prefs = preferences.getPreferencesSync(
      getContext(this) as common.UIAbilityContext,
      { name: 'zenche_ai_settings' }
    );
    prefs.putSync('ai_activation_code', code.trim());
    prefs.putSync('ai_usage_count', 100 - bounded);
    prefs.putSync('ai_device_id', this.getDeviceId());
    prefs.putSync('ai_activated', bounded > 0);
    prefs.flushSync();
  }

  private verifyActivationCode(code: string): boolean {
    const trimmed: string = code.trim();
    if (!this.verifyActivationCodeForDevice(trimmed, this.getDeviceId())) {
      return false;
    }
    this.saveVerifiedActivation(trimmed, 100);
    return true;
  }

  private async rebindAiActivation(): Promise<void> {
    const oldDeviceId: string = this.aiRebindOldDeviceId.trim();
    const oldCode: string = this.aiRebindOldCode.trim();
    if (oldDeviceId.length === 0 || oldCode.length === 0) {
      this.aiActivationMsg = '请输入旧设备 ID 和旧激活码';
      return;
    }
    if (!this.verifyActivationCodeForDevice(oldCode, oldDeviceId)) {
      this.aiActivationMsg = '旧设备 ID 与旧激活码不匹配或已过期';
      return;
    }

    this.aiRebindBusy = true;
    this.aiActivationMsg = '正在迁移…';
    const request: http.HttpRequest = http.createHttp();
    try {
      const currentDeviceId: string = this.getDeviceId();
      const body: Record<string, string> = {
        'activationCode': oldCode,
        'oldDeviceId': oldDeviceId,
        'newDeviceId': currentDeviceId,
      };
      const response: http.HttpResponse = await request.request(
        'https://zenche.top/api/v1/ai/rebind',
        {
          method: http.RequestMethod.POST,
          header: { 'Content-Type': 'application/json' },
          extraData: JSON.stringify(body),
          connectTimeout: 15000,
          readTimeout: 30000,
        }
      );
      const responseText: string = response.result as string;
      if (new util.TextEncoder().encode(responseText).byteLength > 64 * 1024) {
        throw new Error('设备码恢复响应过大');
      }
      let result: Record<string, Object> = {};
      if (responseText.length > 0) {
        try {
          result = JSON.parse(responseText) as Record<string, Object>;
        } catch (_) {
          throw new Error('设备码恢复响应无效');
        }
      }
      if (response.responseCode < 200 || response.responseCode >= 300) {
        const serverMessage: string = (result['error'] as string) || '';
        throw new Error(
          serverMessage || `设备码恢复服务返回错误 ${response.responseCode}`
        );
      }
      const newCode: string = ((result['newCode'] as string) || '').trim();
      const remainingValue: Object = result['remaining'];
      if (newCode.length === 0 || typeof remainingValue !== 'number') {
        throw new Error('设备码恢复响应无效');
      }
      const remaining: number = remainingValue as number;
      if (!Number.isInteger(remaining) || remaining < 0 || remaining > 100) {
        throw new Error('设备码恢复响应无效');
      }
      if (!this.verifyActivationCodeForDevice(newCode, currentDeviceId)) {
        throw new Error('服务器返回的新激活码验证失败，未修改本机数据');
      }
      this.saveVerifiedActivation(newCode, remaining);
      this.aiRebindOldDeviceId = '';
      this.aiRebindOldCode = '';
      this.aiActivationMsg = '设备码恢复成功，AI 权益已迁移到当前设备';
    } catch (error) {
      const failure = error as Error;
      this.aiActivationMsg = `设备码恢复失败：${failure.message || '网络连接失败'}`;
    } finally {
      request.destroy();
      this.aiRebindBusy = false;
    }
  }

  private doAiActivate(): void {
    const code: string = this.aiActivationInput.trim();
    if (code.length === 0) {
      this.aiActivationMsg = '请输入激活码';
      return;
    }
    if (this.verifyActivationCode(code)) {
      this.aiActivationInput = '';
      this.aiActivationMsg = '激活成功！AI 功能已解锁';
    } else {
      this.aiActivationMsg = '激活码无效或已过期';
    }
  }

  @Builder
  private EditorAdjustmentPanel() {
    Column({ space: 8 }) {
      if (this.editorPanel === 'light') {
        this.EditorSlider(
          '曝光',
          this.editorExposure,
          -200,
          200,
          true,
          (value: number): void => {
            this.editorExposure = value;
          }
        )
        this.EditorSlider(
          '对比度',
          this.editorContrast,
          -100,
          100,
          false,
          (value: number): void => {
            this.editorContrast = value;
          }
        )
        this.EditorSlider(
          '高光',
          this.editorHighlights,
          -100,
          100,
          false,
          (value: number): void => {
            this.editorHighlights = value;
          }
        )
        this.EditorSlider(
          '阴影',
          this.editorShadows,
          -100,
          100,
          false,
          (value: number): void => {
            this.editorShadows = value;
          }
        )
        this.EditorSlider(
          '白色色阶',
          this.editorWhites,
          -100,
          100,
          false,
          (value: number): void => {
            this.editorWhites = value;
          }
        )
        this.EditorSlider(
          '黑色色阶',
          this.editorBlacks,
          -100,
          100,
          false,
          (value: number): void => {
            this.editorBlacks = value;
          }
        )
      } else if (this.editorPanel === 'color') {
        this.EditorSlider(
          '色温',
          this.editorTemperature,
          -100,
          100,
          false,
          (value: number): void => {
            this.editorTemperature = value;
          }
        )
        this.EditorSlider(
          '色调',
          this.editorTint,
          -100,
          100,
          false,
          (value: number): void => {
            this.editorTint = value;
          }
        )
        this.EditorSlider(
          '自然饱和度',
          this.editorVibrance,
          -100,
          100,
          false,
          (value: number): void => {
            this.editorVibrance = value;
          }
        )
        this.EditorSlider(
          '饱和度',
          this.editorSaturation,
          -100,
          100,
          false,
          (value: number): void => {
            this.editorSaturation = value;
          }
        )
      } else if (this.editorPanel === 'wheels') {
        Text(this.tr('Lift / Gamma / Gain 三向色轮 · 拖动圆盘色点'))
          .fontSize(TS_BODY).fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.muted')).width('100%')
        Row({ space: 8 }) {
          this.EditorWheel('Lift', this.editorWheelLiftX, this.editorWheelLiftY, WHEEL_LIFT, (x: number, y: number): void => { this.editorWheelLiftX = x; this.editorWheelLiftY = y; })
          this.EditorWheel('Gamma', this.editorWheelGammaX, this.editorWheelGammaY, WHEEL_GAMMA, (x: number, y: number): void => { this.editorWheelGammaX = x; this.editorWheelGammaY = y; })
          this.EditorWheel('Gain', this.editorWheelGainX, this.editorWheelGainY, WHEEL_GAIN, (x: number, y: number): void => { this.editorWheelGainX = x; this.editorWheelGainY = y; })
        }.width('100%')
      } else if (this.editorPanel === 'curves') {
        Text('主曲线 · 拖动曲线控制点')
          .fontSize(TS_BODY).fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.muted')).width('100%')
        Stack({ alignContent: Alignment.TopStart }) {
          Path()
            .commands(this.editorCurvePathCommands())
            .stroke($r('app.color.accent_ink'))
            .strokeWidth(3)
          ForEach(this.editorCurvePoints, (curvePoint: EditorCurvePoint): void => {
            Circle().width(14).height(14).fill($r('app.color.accent_ink'))
              .position({ x: `${curvePoint.x * 320}vp`, y: `${(1 - curvePoint.y) * 140}vp` })
          })
        }
        .width('100%').height(140)
        .backgroundColor($r('app.color.graphite'))
        .borderRadius(8)
        .onTouch((event: TouchEvent): void => {
          const point = event.touches[0];
          if (point === undefined || (event.type !== TouchType.Down && event.type !== TouchType.Move)) {
            return;
          }
          const normalizedX: number = Math.max(0, Math.min(1, point.x / 320));
          const normalizedY: number = Math.max(0, Math.min(1, 1 - point.y / 140));
          if (event.type === TouchType.Down) {
            this.editorActiveCurvePoint = -1;
            let bestDistance: number = 0.035 * 0.035;
            this.editorCurvePoints.forEach((curvePoint: EditorCurvePoint, index: number): void => {
              const dx: number = curvePoint.x - normalizedX;
              const dy: number = curvePoint.y - normalizedY;
              const distance: number = dx * dx + dy * dy;
              if (distance < bestDistance) { bestDistance = distance; this.editorActiveCurvePoint = index; }
            });
            if (this.editorActiveCurvePoint < 0) {
              this.editorCurvePoints.push(new EditorCurvePoint(normalizedX, normalizedY));
              this.editorActiveCurvePoint = this.editorCurvePoints.length - 1;
            }
          }
          if (this.editorActiveCurvePoint >= 0) {
            this.editorCurvePoints[this.editorActiveCurvePoint].x = normalizedX;
            this.editorCurvePoints[this.editorActiveCurvePoint].y = normalizedY;
            this.editorCurvePoints = this.editorCurvePoints.slice();
          }
        })
      } else if (this.editorPanel === 'picker') {
        Text(this.tr(this.editorPickerSample))
          .fontSize(EDITOR_FS_SUB).fontColor($r('app.color.muted')).width('100%')
        Button(this.tr('取样当前照片中心'), { type: ButtonType.Normal })
          .height(46).width('100%')
          .onClick((): void => {
            this.sampleEditorCenterColor();
          })
      } else if (this.editorPanel === 'mask') {
        Text(this.tr('蒙版列表'))
          .fontSize(TS_BODY)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.ink'))
          .width('100%')
        if (this.editorMaskLayers.length === 0) {
          Text(this.tr('暂无蒙版'))
            .fontSize(TS_CAPTION)
            .fontColor($r('app.color.muted'))
            .height(44)
            .width('100%')
        } else {
          Column({ space: 6 }) {
            ForEach(
              this.editorMaskLayers,
              (layer: EditorMaskLayer): void => {
                Row({ space: 6 }) {
                  Button(
                    `${layer.id === this.editorActiveMaskLayerId ? '●' : '○'}  ${this.tr(layer.name)} · ${this.tr(this.displayedEditorMaskLayer(layer).type)}`,
                    { type: ButtonType.Normal }
                  )
                    .height(46)
                    .layoutWeight(1)
                    .fontSize(TS_BODY)
                    .fontColor($r('app.color.ink'))
                    .backgroundColor(Color.Transparent)
                    .onClick((): void => {
                      this.selectEditorMaskLayer(layer.id);
                      this.status = '已切换蒙版';
                      this.refreshEditorRenderedPreview();
                    })
                  Toggle({
                    type: ToggleType.Switch,
                    isOn: layer.visible
                  })
                    .width(56)
                    .height(46)
                    .onChange((visible: boolean): void => {
                      this.setEditorMaskLayerVisible(layer.id, visible);
                      this.status = visible ? '蒙版已显示' : '蒙版已隐藏';
                      this.refreshEditorRenderedPreview();
                    })
                }
                .width('100%')
                .padding({ left: 6, right: 4 })
                .backgroundColor(
                  layer.id === this.editorActiveMaskLayerId
                    ? $r('app.color.paper_2')
                    : $r('app.color.surface')
                )
                .borderRadius(9)
                .border({
                  width: 1,
                  color: layer.id === this.editorActiveMaskLayerId
                    ? $r('app.color.accent')
                    : $r('app.color.rule')
                })
              },
              (layer: EditorMaskLayer): string => layer.id
            )
          }
          .width('100%')
        }
        Row({ space: 8 }) {
          Button(this.tr('创建蒙版'), { type: ButtonType.Normal })
            .height(48)
            .layoutWeight(1)
            .fontColor($r('app.color.accent_ink'))
            .backgroundColor($r('app.color.accent'))
            .onClick((): void => {
              this.createEditorMaskLayer();
              this.status = '蒙版已创建 · 在预览画面涂抹';
              this.refreshEditorRenderedPreview();
            })
          Button(this.tr('删除蒙版'), { type: ButtonType.Normal })
            .height(48)
            .layoutWeight(1)
            .enabled(this.editorMaskEnabled)
            .fontColor($r('app.color.ink'))
            .backgroundColor($r('app.color.paper_2'))
            .onClick((): void => {
              this.deleteActiveEditorMaskLayer();
              this.status = '蒙版已删除';
              this.refreshEditorRenderedPreview();
            })
        }
        .width('100%')
        Row({ space: 8 }) {
          Button(this.tr('添加蒙版（画笔）'), { type: ButtonType.Normal })
            .height(48)
            .layoutWeight(1)
            .fontSize(TS_CAPTION)
            .fontColor(!this.editorMaskSubtract && this.editorMaskEnabled
              ? $r('app.color.accent_ink') : $r('app.color.ink'))
            .backgroundColor(!this.editorMaskSubtract && this.editorMaskEnabled
              ? $r('app.color.accent') : $r('app.color.paper_2'))
            .onClick((): void => {
              this.ensureEditorMaskLayer();
              if (this.editorMaskType.length === 0) {
                this.editorMaskType = '画笔';
              }
              this.editorMaskSubtract = false;
              this.status = '添加蒙版画笔已启用';
            })
          Button(this.tr('减去蒙版（画笔）'), { type: ButtonType.Normal })
            .height(48)
            .layoutWeight(1)
            .fontSize(TS_CAPTION)
            .fontColor(this.editorMaskSubtract && this.editorMaskEnabled
              ? $r('app.color.accent_ink') : $r('app.color.ink'))
            .backgroundColor(this.editorMaskSubtract && this.editorMaskEnabled
              ? $r('app.color.accent') : $r('app.color.paper_2'))
            .onClick((): void => {
              this.ensureEditorMaskLayer();
              if (this.editorMaskType.length === 0) {
                this.editorMaskType = '画笔';
              }
              this.editorMaskSubtract = true;
              this.status = '减去蒙版画笔已启用';
            })
        }
        .width('100%')
        Text(this.tr('智能识别'))
          .fontSize(TS_BODY)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.muted'))
          .width('100%')
        Scroll() {
          Row({ space: 8 }) {
            ForEach(
              ['智能主体', '智能天空', '智能背景', '智能人物', '智能亮部', '智能暗部'],
              (type: string): void => {
                Button(this.tr(type), { type: ButtonType.Normal })
                  .height(44)
                  .fontSize(TS_CAPTION)
                  .fontColor(this.editorMaskType === type
                    ? $r('app.color.accent_ink') : $r('app.color.ink'))
                  .backgroundColor(this.editorMaskType === type
                    ? $r('app.color.accent') : $r('app.color.paper_2'))
                  .onClick((): void => {
                    this.ensureEditorMaskLayer();
                    this.editorMaskType = type;
                    this.editorMaskAmount = 100;
                    this.editorMaskInvert = false;
                    this.editorMaskSubtract = false;
                    this.editorMaskStrokes = [];
                    this.status = this.tr('智能蒙版已创建 · 可继续添加或减去画笔');
                    this.refreshEditorRenderedPreview();
                  })
              },
              (type: string): string => type
            )
          }
        }
        .width('100%')
        .scrollable(ScrollDirection.Horizontal)
        .scrollBar(BarState.Off)
        this.EditorSlider('强度', this.editorMaskAmount, 0, 100, false, (value: number): void => {
          this.editorMaskAmount = value;
        })
        this.EditorSlider('羽化', this.editorMaskFeather, 0, 100, false, (value: number): void => {
          this.editorMaskFeather = value;
        })
        this.EditorSlider('画笔大小', this.editorMaskBrushSize, 4, 64, false, (value: number): void => {
          this.editorMaskBrushSize = value;
        })
        Button(this.tr('反向蒙版'), { type: ButtonType.Normal })
          .height(46)
          .width('100%')
          .fontColor(this.editorMaskInvert
            ? $r('app.color.accent_ink') : $r('app.color.ink'))
          .backgroundColor(this.editorMaskInvert
            ? $r('app.color.accent') : $r('app.color.paper_2'))
          .onClick((): void => {
            this.editorMaskInvert = !this.editorMaskInvert;
            this.status = this.editorMaskInvert
              ? '蒙版已反向'
              : '蒙版已恢复正向';
            this.refreshEditorRenderedPreview();
          })
        Text(this.tr('蒙版内调整'))
          .fontSize(TS_BODY)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.ink'))
          .width('100%')
        this.EditorSlider('曝光', this.editorMaskExposure, -200, 200, true, (value: number): void => {
          this.editorMaskExposure = value;
        })
        this.EditorSlider('对比度', this.editorMaskContrast, -100, 100, false, (value: number): void => {
          this.editorMaskContrast = value;
        })
        this.EditorSlider('高光', this.editorMaskHighlights, -100, 100, false, (value: number): void => {
          this.editorMaskHighlights = value;
        })
        this.EditorSlider('阴影', this.editorMaskShadows, -100, 100, false, (value: number): void => {
          this.editorMaskShadows = value;
        })
        this.EditorSlider('色温', this.editorMaskTemperature, -100, 100, false, (value: number): void => {
          this.editorMaskTemperature = value;
        })
        this.EditorSlider('色调', this.editorMaskTint, -100, 100, false, (value: number): void => {
          this.editorMaskTint = value;
        })
        this.EditorSlider('饱和度', this.editorMaskSaturation, -100, 100, false, (value: number): void => {
          this.editorMaskSaturation = value;
        })
        this.EditorSlider('清晰度', this.editorMaskClarity, -100, 100, false, (value: number): void => {
          this.editorMaskClarity = value;
        })
        Text(this.tr(this.editorMaskEnabled
          ? '蓝色显示当前蒙版覆盖；橡皮会擦除蓝色区域。'
          : '先创建蒙版，再选择添加或减去画笔。'))
          .fontSize(TS_CAPTION).fontColor($r('app.color.muted')).width('100%')
      } else if (this.editorPanel === 'detail') {
        this.EditorSlider(
          '纹理',
          this.editorTexture,
          -100,
          100,
          false,
          (value: number): void => {
            this.editorTexture = value;
          }
        )
        this.EditorSlider(
          '清晰度',
          this.editorClarity,
          -100,
          100,
          false,
          (value: number): void => {
            this.editorClarity = value;
          }
        )
        this.EditorSlider(
          '锐化',
          this.editorSharpening,
          0,
          100,
          false,
          (value: number): void => {
            this.editorSharpening = value;
          }
        )
        this.EditorSlider(
          '降噪',
          this.editorNoiseReduction,
          0,
          100,
          false,
          (value: number): void => {
            this.editorNoiseReduction = value;
          }
        )
      } else if (this.editorPanel === 'effects') {
        this.EditorSlider(
          '去雾',
          this.editorDehaze,
          -100,
          100,
          false,
          (value: number): void => {
            this.editorDehaze = value;
          }
        )
        this.EditorSlider(
          '暗角',
          this.editorVignette,
          -100,
          100,
          false,
          (value: number): void => {
            this.editorVignette = value;
          }
        )
      } else {
        Text(this.tr('裁切比例'))
          .fontSize(TS_BODY)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.muted'))
          .width('100%')
        Select(
          ['原始比例', '1:1', '4:3', '3:2', '16:9']
            .map((label: string): SelectEntry => {
              return new SelectEntry(label, label);
            })
        )
          .selected(this.editorCropRatioIndex())
          .width('100%')
          .onSelect((index: number): void => {
            const ratios: Array<string> = [
              'original', '1:1', '4:3', '3:2', '16:9'
            ];
            this.editorCropRatio = ratios[index];
            if (this.editorMaskEnabled) {
              this.refreshEditorRenderedPreview();
            }
          })
        Row({ space: 8 }) {
          Button(this.tr('旋转 90°'), { type: ButtonType.Normal })
            .height(48)
            .layoutWeight(1)
            .onClick((): void => {
              this.editorRotation = (this.editorRotation + 90) % 360;
              if (this.editorMaskEnabled) {
                this.refreshEditorRenderedPreview();
              }
            })
          Button(this.tr('水平翻转'), { type: ButtonType.Normal })
            .height(48)
            .layoutWeight(1)
            .onClick((): void => {
              this.editorFlipHorizontal =
                !this.editorFlipHorizontal;
              if (this.editorMaskEnabled) {
                this.refreshEditorRenderedPreview();
              }
            })
          Button(this.tr('垂直翻转'), { type: ButtonType.Normal })
            .height(48)
            .layoutWeight(1)
            .onClick((): void => {
              this.editorFlipVertical = !this.editorFlipVertical;
              if (this.editorMaskEnabled) {
                this.refreshEditorRenderedPreview();
              }
            })
        }
        .width('100%')
      }
    }
    .width('100%')
    .padding(14)
    .backgroundColor($r('app.color.surface'))
    .border({
      width: 1,
      color: $r('app.color.rule'),
      radius: 10
    })
  }

  @Builder
  private EditorWheel(
    label: string,
    xValue: number,
    yValue: number,
    tint: ResourceColor,
    onChange: (x: number, y: number) => void
  ) {
    Column({ space: 4 }) {
      Stack({ alignContent: Alignment.Center }) {
        Circle()
          .width(78)
          .height(78)
          .fill($r('app.color.graphite'))
          .border({ width: 6, color: tint })
        Circle()
          .width(10)
          .height(10)
          .fill(tint)
          .position({
            x: `${39 + Math.max(-1, Math.min(1, xValue / 100)) * 28}vp`,
            y: `${39 - Math.max(-1, Math.min(1, yValue / 100)) * 28}vp`
          })
      }
      .width(78)
      .height(78)
      .onTouch((event: TouchEvent): void => {
        const point = event.touches[0];
        if (point === undefined || (event.type !== TouchType.Down && event.type !== TouchType.Move)) {
          return;
        }
        const dx: number = Math.max(-1, Math.min(1, (point.x - 39) / 28));
        const dy: number = Math.max(-1, Math.min(1, (39 - point.y) / 28));
        onChange(dx * 100, dy * 100);
      })
      Text(label)
        .fontSize(TS_CAPTION)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.muted'))
      Text(`${xValue >= 0 ? '+' : ''}${Math.round(xValue)}, ${yValue >= 0 ? '+' : ''}${Math.round(yValue)}`)
        .fontSize(EDITOR_FS_SMALL)
        .fontColor($r('app.color.muted'))
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Center)
  }

  private editorCurvePathCommands(): string {
    const points: Array<EditorCurvePoint> = this.editorCurvePoints.slice().sort((a: EditorCurvePoint, b: EditorCurvePoint): number => a.x - b.x);
    if (points.length === 0) return '';
    let commands: string = `M ${points[0].x * 320} ${(1 - points[0].y) * 140}`;
    for (let index: number = 0; index < points.length - 1; index++) {
      const p0: EditorCurvePoint = points[Math.max(0, index - 1)];
      const p1: EditorCurvePoint = points[index];
      const p2: EditorCurvePoint = points[index + 1];
      const p3: EditorCurvePoint = points[Math.min(points.length - 1, index + 2)];
      const c1x: number = p1.x + (p2.x - p0.x) / 6;
      const c1y: number = p1.y + (p2.y - p0.y) / 6;
      const c2x: number = p2.x - (p3.x - p1.x) / 6;
      const c2y: number = p2.y - (p3.y - p1.y) / 6;
      commands += ` C ${c1x * 320} ${(1 - c1y) * 140} ${c2x * 320} ${(1 - c2y) * 140} ${p2.x * 320} ${(1 - p2.y) * 140}`;
    }
    return commands;
  }

  @Builder
  private EditorSlider(
    label: string,
    value: number,
    minimum: number,
    maximum: number,
    exposure: boolean,
    onChange: (value: number) => void
  ) {
    Column({ space: 4 }) {
      Text(
        exposure
          ? `${this.tr(label)} · ${(value / 100).toFixed(2)} EV`
          : `${this.tr(label)} · ${Math.round(value)}`
      )
        .fontSize(TS_BODY)
        .fontColor($r('app.color.muted'))
        .width('100%')
      Slider({
        value: value,
        min: minimum,
        max: maximum,
        step: 1,
        style: SliderStyle.OutSet
      })
        .onChange((next: number): void => {
          onChange(Math.round(next));
          if (this.editorMaskEnabled) {
            this.refreshEditorRenderedPreview();
          }
        })
    }
    .width('100%')
    .constraintSize({ minHeight: 52 })
  }

  @Builder
  private CameraWorkspace() {
    Column({ space: 16 }) {
      if (this.section === 'capture') {
        // v1.5.5 fig1 control page: status row → 2×2 status cards → parameter
        // grid → capture dock. The preview stage and session/task panels stay
        // below, exactly like the Android fig1 capture surface.
        this.ControlStatusRow()
        this.ControlStatusGrid()
        this.ControlParameterGrid()
        this.ControlCaptureDock()
      } else {
        Text('00:00:00:00')
          .fontSize(38)
          .fontFamily('monospace')
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.White)
          .textAlign(TextAlign.Center)
          .width('100%')
          .height(60)
      }
      Stack({ alignContent: Alignment.TopStart }) {
        if (this.preview !== undefined) {
          Image(this.preview)
            .width('100%')
            .height('100%')
            .objectFit(ImageFit.Contain)
        } else {
          Column({ space: 8 }) {
            Text(this.tr('等待相机画面'))
              .fontSize(22)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.graphite_ink'))
            Text(this.tr('连接相机后开启实时取景'))
              .fontSize(14)
              .fontColor($r('app.color.graphite_muted'))
          }
          .width('100%')
          .height('100%')
          .justifyContent(FlexAlign.Center)
        }
        Text(this.liveView ? 'LIVE VIEW ON' : 'LIVE VIEW OFF')
          .fontSize(10)
          .fontFamily('monospace')
          .fontColor(
            this.liveView
              ? $r('app.color.accent_ink')
              : $r('app.color.graphite_muted')
          )
          .backgroundColor($r('app.color.graphite_2'))
          .borderRadius(5)
          .padding({ left: 8, right: 8, top: 4, bottom: 4 })
          .margin(16)
        if (this.section === 'monitor' && this.monitorFocusPointX >= 0) {
          Text('＋')
            .fontSize(32)
            .fontColor(PEAKING_AMBER)
            .position({
              x: `${this.monitorFocusPointX * 100}%`,
              y: `${this.monitorFocusPointY * 100}%`
            })
        } else if (this.section !== 'monitor') {
          Button(this.tr('全屏'), { type: ButtonType.Normal })
            .height(44)
            .fontColor(Color.White)
            .backgroundColor(HUD_BG_SOFT)
            .borderRadius(12)
            .align(Alignment.TopEnd)
            .margin(16)
            .onClick((): void => {
              this.openImmersivePreview(false);
            })
        }
      }
      .width('100%')
      .layoutWeight(1)
      .constraintSize({ minHeight: 320 })
      .backgroundColor($r('app.color.graphite'))
      .border({
        width: 1,
        color: $r('app.color.graphite_rule'),
        radius: 18
      })
      .onTouch((event: TouchEvent): void => {
        if (this.section !== 'monitor' || event.type !== TouchType.Up) return;
        const point = event.touches[0];
        if (point === undefined) return;
        const normalized = this.normalizeMonitorPoint(point.x, point.y);
        if (normalized !== undefined) this.focusAtMonitorPoint(normalized[0], normalized[1]);
      })
      .onAreaChange((_oldArea: Area, newArea: Area): void => {
        this.monitorStageWidth = Math.max(1, Number(newArea.width));
        this.monitorStageHeight = Math.max(1, Number(newArea.height));
      })

      this.NikonCloudMonitorPicker()

      if (this.section === 'monitor') {
        this.MonitorScopeRail()
        this.MonitorParameterRail()
        this.MonitorParameterControls()
        this.MonitorToolRail()
        this.MonitorStorageCard()
        this.ExposureReadoutRail()
      }

      if (this.section !== 'capture') {
        Row({ space: 8 }) {
          Text(this.tr(
            this.section === 'monitor'
              ? '相机原生 JPEG · 监看输出 · 不修改原片'
              : '相机原生 JPEG · 本地预览'
          ))
            .fontSize(TS_BODY)
            .fontColor(UI_LABEL)
            .layoutWeight(1)
          Button(this.tr(this.liveView ? '停止取景' : '开启取景'), {
            type: ButtonType.Normal
          })
            .height(44)
            .fontColor(Color.White)
            .backgroundColor(UI_SECONDARY)
            .border({
              width: 1,
              color: UI_SECONDARY,
              radius: 12
            })
            .enabled(this.connected && !this.busy)
            .onClick((): void => {
              this.toggleLiveView();
            })
          Button(
            this.tr(
              this.section === 'monitor'
                ? (this.videoRecording ? '停止录制' : '开始录制')
                : '拍摄照片'
            ),
            { type: ButtonType.Normal }
          )
            .height(44)
            .fontColor(Color.White)
            .backgroundColor(
              this.section === 'monitor'
                ? UI_VIDEO
                : UI_ACCENT
            )
            .borderRadius(12)
            .enabled(
              (this.section === 'monitor'
                ? this.connected
                : (this.connected || this.wifiConnected || this.localCameraSelected)) && !this.busy
            )
            .onClick((): void => {
              if (this.section === 'monitor') {
                this.toggleVideoRecording();
              } else {
                this.capturePhoto();
              }
            })
          if (this.section === 'monitor') {
            Button('AF-ON', { type: ButtonType.Normal })
              .height(44)
              .fontColor(Color.White)
              .backgroundColor(UI_SECONDARY)
              .borderRadius(12)
              .enabled(this.connected && this.liveView && !this.busy)
              .onClick((): void => {
                this.triggerAutoFocusOn();
              })
          }
        }
        .width('100%')
      }
      if (this.section === 'capture') {
        this.CaptureSessionPanel()
        this.ShootingTaskPanel()
      }
    }
    .width('100%')
    .height(this.isCompact() ? 'auto' : '100%')
    .padding(16)
    .backgroundColor(
      this.isCameraSection()
        ? UI_BG
        : $r('app.color.paper')
    )
  }

  // ── v1.5.5 fig1 control page: status row / 2×2 cards / parameter grid / dock ──
  // Pure-UI state mirrors Android's fig1 surface; nothing here touches the
  // connection state machine or device I/O.

  private controlAnyCamera(): boolean {
    return this.connected || this.wifiConnected || this.localCameraSelected;
  }

  private controlStatusLoading(): boolean {
    // Wi‑Fi connect carries its own flag; USB connect runs inside runBusy with
    // a '正在连接…' status line, so busy+status is the honest loading signal.
    return this.wifiConnecting ||
      (this.busy && this.status.indexOf('正在连接') === 0);
  }

  private controlStatusFailed(): boolean {
    return this.lastConnectionError.length > 0 &&
      !this.controlAnyCamera() &&
      !this.controlStatusLoading();
  }

  private controlStatusDotColor(): string {
    if (this.controlStatusLoading() || this.controlAnyCamera()) {
      return UI_ACCENT;
    }
    return this.controlStatusFailed() ? UI_VIDEO : UI_LABEL;
  }

  private controlStatusTextValue(): string {
    if (this.controlStatusLoading()) {
      return this.wifiConnecting ? '正在连接 Wi‑Fi 相机…' : '正在连接…';
    }
    if (this.controlAnyCamera()) {
      return '就绪';
    }
    return this.controlStatusFailed() ? '连接失败' : '未连接';
  }

  private controlStatusRateValue(): string {
    if (this.controlStatusLoading()) {
      return '连接中';
    }
    if (this.controlAnyCamera()) {
      return this.connected ? 'USB/PTP'
        : this.wifiConnected ? 'Wi‑Fi/PTP‑IP' : 'SYSTEM';
    }
    return this.controlStatusFailed() ? '重试' : '待连接';
  }

  @Builder
  private ControlStatusRow() {
    Column({ space: 4 }) {
      Row({ space: 8 }) {
        // v1.5.7 P1：状态点宽 22vp → 10vp（视觉对齐 macOS 8pt 基准；触控面由行整体 44vp 高保证）
        Text('●')
          .fontSize(10)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.controlStatusDotColor())
          .width(10)
          .textAlign(TextAlign.Center)
        Text(this.tr(this.controlStatusTextValue()))
          .fontSize(13)
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.White)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
        Text(this.tr(this.controlStatusRateValue()))
          .fontSize(TS_BODY)
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.White)
          .padding({ left: 12, right: 12, top: 6, bottom: 6 })
          .backgroundColor(UI_SECONDARY)
          .borderRadius(15)
          .onClick((): void => {
            // fig1: tapping the transport capsule opens the connection panel
            // whenever no camera is live (covers both 待连接 and 重试 states).
            if (!this.controlAnyCamera() && !this.controlStatusLoading()) {
              this.connectionPanelVisible = true;
            }
          })
      }
      .width('100%')
      .height(44)
      if (this.controlStatusFailed()) {
        Text(this.lastConnectionError)
          .fontSize(TS_BODY)
          .fontColor(UI_VIDEO)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
      }
    }
    .width('100%')
  }

  private bodyModelName(): string {
    if (this.connected || this.localCameraSelected) {
      return this.cameraName.length > 0 ? this.cameraName : '—';
    }
    if (this.wifiConnected) {
      return this.wifiCameraName.length > 0 ? this.wifiCameraName : '—';
    }
    return '—';
  }

  @Builder
  private ControlStatusGrid() {
    if (this.isCompact()) {
      Column({ space: 10 }) {
        Row({ space: 10 }) {
          this.ControlStatusCard(
            '▣', this.tr('机身'), this.bodyModelName(), '—',
            this.controlAnyCamera()
          )
          this.ControlStatusCard(
            '◎', this.tr('镜头'), '—', this.tr('镜头数据未提供'), false
          )
        }
        Row({ space: 10 }) {
          this.ControlStorageStatusCard()
          this.ControlStatusCard(
            '▤', this.tr('格式'), 'JPEG', this.tr('照片输出'), false
          )
        }
      }
      .width('100%')
    } else {
      Row({ space: 10 }) {
        this.ControlStatusCard(
          '▣', this.tr('机身'), this.bodyModelName(), '—',
          this.controlAnyCamera()
        )
        this.ControlStatusCard(
          '◎', this.tr('镜头'), '—', this.tr('镜头数据未提供'), false
        )
        this.ControlStorageStatusCard()
        this.ControlStatusCard(
          '▤', this.tr('格式'), 'JPEG', this.tr('照片输出'), false
        )
      }
      .width('100%')
    }
  }

  @Builder
  private ControlStatusCard(
    icon: string,
    label: string,
    value: string,
    sub: string,
    active: boolean
  ) {
    Column({ space: 4 }) {
      Row({ space: 6 }) {
        Text(icon)
          .fontSize(16)
          .fontColor(UI_LABEL)
          .width(24)
          .height(24)
        Text(label)
          .fontSize(TS_BODY)
          .fontColor(UI_LABEL)
      }
      .width('100%')
      Text(value)
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor(Color.White)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
        .margin({ top: 6 })
      Text(sub.length > 0 ? sub : ' ')
        .fontSize(TS_BODY)
        .fontColor(UI_LABEL)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
        .margin({ top: 1 })
    }
    .height(104)
    .layoutWeight(1)
    .padding(12)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Start)
    .backgroundColor(UI_CARD)
    .borderRadius(15)
    .border({ width: active ? 1 : 0, color: UI_ACCENT })
  }

  private storageHasVolumes(): boolean {
    return (this.connected || this.wifiConnected) &&
      this.cameraStorageSnapshot.volumes.length > 0;
  }

  private storageUsedBytes(): number {
    return Math.max(
      0,
      this.cameraStorageSnapshot.capacityBytes -
        this.cameraStorageSnapshot.freeBytes
    );
  }

  private storageUsedPercent(): number {
    const capacity: number = this.cameraStorageSnapshot.capacityBytes;
    return capacity > 0
      ? Math.max(0, Math.min(100, Math.round(
          this.storageUsedBytes() * 100 / capacity
        )))
      : 0;
  }

  private storageFreeImages(): number {
    let total: number = 0;
    this.cameraStorageSnapshot.volumes.forEach(
      (volume: CameraStorageVolume): void => {
        total += volume.freeImages;
      }
    );
    return total;
  }

  private formatStorageBytes(bytes: number): string {
    if (bytes < 0) {
      return '—';
    }
    const units: Array<string> = ['B', 'KB', 'MB', 'GB', 'TB'];
    let value: number = bytes;
    let index: number = 0;
    while (value >= 1024 && index < units.length - 1) {
      value /= 1024;
      index++;
    }
    return index === 0
      ? `${Math.round(value)} ${units[index]}`
      : `${value.toFixed(1)} ${units[index]}`;
  }

  /** v1.5.5 fig1 storage card with accent progress bar, honest 无卡 state. */
  @Builder
  private ControlStorageStatusCard() {
    Column({ space: 4 }) {
      Row({ space: 6 }) {
        Text('▯')
          .fontSize(16)
          .fontColor(UI_LABEL)
          .width(24)
          .height(24)
        Text(this.tr('存储'))
          .fontSize(TS_BODY)
          .fontColor(UI_LABEL)
      }
      .width('100%')
      Text(this.storageHasVolumes()
        ? `${this.formatStorageBytes(this.storageUsedBytes())}/` +
          `${this.formatStorageBytes(this.cameraStorageSnapshot.capacityBytes)} · ` +
          `${this.storageUsedPercent()}%`
        : '—')
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor(Color.White)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
        .margin({ top: 6 })
      if (this.storageHasVolumes()) {
        Row() {
          Row()
            .width(`${this.storageUsedPercent()}%`)
            .height(4)
            .backgroundColor(UI_ACCENT)
            .borderRadius(2)
          if (this.storageUsedPercent() < 100) {
            Row()
              .layoutWeight(1)
              .height(4)
              .backgroundColor(UI_SECONDARY)
              .borderRadius(2)
          }
        }
        .width('100%')
        .margin({ top: 2 })
      } else {
        Row()
          .width('100%')
          .height(4)
          .backgroundColor(UI_SECONDARY)
          .borderRadius(2)
          .margin({ top: 2 })
      }
      Text(this.storageHasVolumes()
        ? (this.storageFreeImages() > 0
            ? `可拍 ${this.storageFreeImages()} 张`
            : this.tr('存储卡已满'))
        : (this.connected || this.wifiConnected) ? this.tr('无卡') : '—')
        .fontSize(TS_BODY)
        .fontColor(UI_LABEL)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
        .margin({ top: 1 })
    }
    .height(104)
    .layoutWeight(1)
    .padding(12)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Start)
    .backgroundColor(UI_CARD)
    .borderRadius(15)
  }

  /** v1.5.5 fig1 parameter grid: 3-column tiles (4 on wide screens) + 全部/编辑. */
  private controlTiles(): Array<ControlTile> {
    const live: boolean = this.connected || this.localCameraSelected;
    return [
      new ControlTile('模式', live ? this.exposureModeCode() : '—'),
      new ControlTile('快门', this.connected ? this.shutterDisplay() : '—'),
      new ControlTile('光圈', this.connected
        ? `F${this.currentAperture.toFixed(1)}` : '—'),
      new ControlTile('ISO', this.connected ? `${this.currentIso}` : '—'),
      new ControlTile('EV', this.connected
        ? `${this.currentCompensation >= 0 ? '+' : ''}` +
          `${this.currentCompensation.toFixed(1)}`
        : '—'),
      new ControlTile('传输', this.connected ? 'PTP'
        : this.wifiConnected ? 'PTP-IP' : '—'),
      new ControlTile('白平衡', this.connected
        ? (this.currentWhiteBalance === 'continuous' ? '自动' : '预设') : '—'),
      new ControlTile('对焦', this.connected
        ? (this.currentFocusMode === 'continuous' ? 'AF-C' : 'AF-S') : '—')
    ];
  }

  private controlTileHidden(index: number): boolean {
    return this.gridHiddenTiles[index] === true;
  }

  private hideControlTile(index: number): void {
    const next: Array<boolean> = this.gridHiddenTiles.slice();
    next[index] = true;
    this.gridHiddenTiles = next;
  }

  /** Visible tile indices grouped into rows of 3 (compact) or 4 (desktop). */
  private controlTileRows(): Array<Array<number>> {
    const columns: number = this.isCompact() ? 3 : 4;
    const rows: Array<Array<number>> = [];
    let row: Array<number> = [];
    for (let index: number = 0; index < 8; index++) {
      if (this.controlTileHidden(index)) {
        continue;
      }
      row.push(index);
      if (row.length === columns) {
        rows.push(row);
        row = [];
      }
    }
    if (row.length > 0) {
      rows.push(row);
    }
    return rows;
  }

  @Builder
  private ControlParameterGrid() {
    Column({ space: 8 }) {
      Row() {
        Text(this.tr('参数'))
          .fontSize(TS_EMPHASIS)
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.White)
          .layoutWeight(1)
        Button(this.tr('全部'), { type: ButtonType.Normal })
          .width(68)
          .height(44)
          .fontSize(TS_BODY)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.gridEditMode ? Color.White : $r('app.color.ink'))
          .backgroundColor(this.gridEditMode ? UI_SECONDARY : UI_ACCENT)
          .borderRadius(16)
          .onClick((): void => {
            this.gridEditMode = false;
            this.gridHiddenTiles = new Array<boolean>(8).fill(false);
          })
        Button(this.tr('编辑'), { type: ButtonType.Normal })
          .width(68)
          .height(44)
          .fontSize(TS_BODY)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.gridEditMode ? $r('app.color.ink') : Color.White)
          .backgroundColor(this.gridEditMode ? UI_ACCENT : UI_SECONDARY)
          .borderRadius(16)
          .margin({ left: 8 })
          .onClick((): void => {
            this.gridEditMode = true;
          })
      }
      .width('100%')
      .height(44)
      if (this.controlTileRows().length === 0) {
        Text(this.tr('参数已全部隐藏'))
          .fontSize(TS_BODY)
          .fontColor(UI_LABEL)
          .width('100%')
          .height(44)
          .margin({ top: 12 })
      } else {
        this.ControlTileRowsLoop(this.controlTiles())
      }
    }
    .width('100%')
  }


  @Builder
  private ControlTileRowsLoop(tiles: Array<ControlTile>) {
    ForEach(this.controlTileRows(), (row: Array<number>, rowIndex: number) => {
      Row({ space: 8 }) {
        ForEach(row, (index: number): void => {
          this.ControlParameterTile(
            index,
            tiles[index].label,
            tiles[index].value
          )
        }, (index: number): string => index.toString())
      }
      .width('100%')
      .margin({ top: rowIndex === 0 ? 0 : 8 })
    }, (row: Array<number>): string => row.join('-'))
  }

  @Builder
  private ControlParameterTile(index: number, label: string, value: string) {
    Stack({ alignContent: Alignment.TopEnd }) {
      Column({ space: 4 }) {
        Text(this.tr(label))
          .fontSize(TS_BODY)
          .fontColor(UI_LABEL)
          .width('100%')
        Text(value)
          .fontSize(28)
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.White)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
      }
      .width('100%')
      .height(84)
      .padding(12)
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Start)
      .backgroundColor(UI_CARD)
      .borderRadius(15)
      if (this.gridEditMode) {
        // v1.5.7 P1：×钮宽 22vp → 44vp 触控合规（design.md ≥44×44，高已 44）
        Button('×', { type: ButtonType.Normal })
          .width(44)
          .height(44)
          .fontSize(TS_EMPHASIS)
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.White)
          .backgroundColor(UI_SECONDARY)
          .borderRadius(11)
          .onClick((): void => {
            this.hideControlTile(index);
          })
      }
    }
    .layoutWeight(1)
  }

  private firstPhotoFile(): PhotoItem | undefined {
    for (const item of this.photos) {
      if (!item.isVideo) {
        return item;
      }
    }
    return undefined;
  }

  /** v1.5.5 fig1 capture bar: gallery, AF-ON, round shutter, INT, camera switch. */
  @Builder
  private ControlCaptureDock() {
    Row() {
      Stack({ alignContent: Alignment.Center }) {
        if (this.firstPhotoFile() !== undefined) {
          Image(`file://${this.firstPhotoFile()!.path}`)
            .width('100%')
            .height('100%')
            .objectFit(ImageFit.Cover)
        } else {
          Text('▢')
            .fontSize(20)
            .fontColor(UI_LABEL)
        }
      }
      .width(56)
      .height(56)
      .backgroundColor(UI_SECONDARY)
      .borderRadius(10)
      .onClick((): void => {
        this.section = 'library';
      })
      Button(this.tr('AF-ON'), { type: ButtonType.Normal })
        .width(76)
        .height(44)
        .fontSize(TS_BODY)
        .fontWeight(FontWeight.Bold)
        .fontColor(Color.White)
        .backgroundColor(UI_SECONDARY)
        .borderRadius(16)
        .margin({ left: 8 })
        .onClick((): void => {
          this.triggerAutoFocusOn();
        })
      Button('●', { type: ButtonType.Normal })
        .width(74)
        .height(74)
        .fontSize(TS_DISPLAY)
        .fontWeight(FontWeight.Bold)
        .fontColor(UI_ACCENT)
        .backgroundColor(UI_CARD)
        .border({ width: 3, color: UI_ACCENT, radius: 37 })
        .margin({ left: 10, right: 10 })
        .enabled(
          (this.connected || this.wifiConnected || this.localCameraSelected) &&
            !this.busy
        )
        .onClick((): void => {
          this.capturePhoto();
        })
      Button('INT', { type: ButtonType.Normal })
        .width(64)
        .height(44)
        .fontSize(TS_BODY)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.shootingTaskRunning ? $r('app.color.ink') : Color.White)
        .backgroundColor(this.shootingTaskRunning ? UI_ACCENT : UI_SECONDARY)
        .borderRadius(16)
        .onClick((): void => {
          // fig1: INT scrolls the shooting-task panel into view (compact page).
          if (this.isCompact()) {
            this.gridScroller.scrollEdge(Edge.Bottom);
          }
        })
      Button('⇄', { type: ButtonType.Normal })
        .width(44)
        .height(44)
        .fontSize(TS_TITLE)
        .fontColor(Color.White)
        .backgroundColor(UI_SECONDARY)
        .borderRadius(14)
        .margin({ left: 8 })
        .accessibilityText(this.tr('切换相机'))
        .onClick((): void => {
          this.section = 'devices';
        })
    }
    .width('100%')
    .padding(10)
    .backgroundColor(UI_CARD)
    .borderRadius(16)
  }

  @Builder
  private NikonCloudMonitorPicker() {
    Column({ space: 8 }) {
      Row({ space: 12 }) {
        Text('NP3')
          .width(40)
          .height(40)
          .fontSize(TS_CAPTION)
          .fontWeight(FontWeight.Bold)
          .fontColor(WHITE)
          .textAlign(TextAlign.Center)
          .backgroundColor($r('app.color.accent'))
          .borderRadius(12)
        Column({ space: 2 }) {
          Text(this.tr('尼康云创监看'))
            .fontSize(13)
            .fontWeight(FontWeight.Bold)
            .fontColor(
              this.section === 'monitor'
                ? WHITE
                : $r('app.color.ink')
            )
          Text(
            this.selectedMonitorNikonCloudPreset()?.name ??
            this.tr('已关闭')
          )
            .fontSize(TS_CAPTION)
            .fontColor(
              this.section === 'monitor'
                ? CLOUD_MUTED
                : $r('app.color.muted')
            )
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        Select(this.nikonCloudSelectEntries())
          .selected(this.monitorNikonCloudPresetIndex())
          .value(this.tr('选择预设'))
          .width(142)
          .height(44)
          .onSelect((index: number): void => {
            this.monitorNikonCloudPresetId = index === 0
              ? '' : NIKON_CLOUD_PRESETS[index - 1].id;
            const selected: NikonCloudPreset | undefined =
              this.selectedMonitorNikonCloudPreset();
            this.status = selected === undefined
              ? '尼康云创监看已关闭'
              : `尼康云创监看 · ${selected.name} · 照片/视频 · SDR 近似`;
          })
      }
      .width('100%')
      Text(this.tr('照片与视频实时生效 · SDR 近似 · 不写入原片'))
        .fontSize(TS_CAPTION)
        .fontColor(
          this.section === 'monitor'
            ? CLOUD_MUTED
            : $r('app.color.muted')
        )
        .maxLines(2)
    }
    .width('100%')
    .padding(12)
    .backgroundColor(
      this.section === 'monitor'
        ? CLOUD_CARD_BG
        : $r('app.color.accent_soft')
    )
    .border({
      width: 1,
      color: this.section === 'monitor'
        ? CLOUD_CARD_BORDER
        : $r('app.color.accent'),
      radius: 14
    })
  }

  @Builder
  private MonitorScopeRail() {
    Row({ space: 10 }) {
      Canvas(this.monitorRgbScopeContext)
        .width('100%')
        .height(100)
        .onReady((): void => {
          this.drawMonitorRgbScope();
        })
      .layoutWeight(1)
      .height(112)
      .padding(3)
      .backgroundColor(BLACK)
      Canvas(this.monitorAudioScopeContext)
        .width('100%')
        .height(100)
        .onReady((): void => {
          this.drawAudioScope();
        })
      .layoutWeight(1)
      .height(112)
      .padding(3)
      .backgroundColor(BLACK)
    }
    .width('100%')
  }

  @Builder
  private MonitorParameterRail() {
    Scroll() {
      Row() {
        this.MonitorReadout('帧率', this.connected ? `${this.videoFrameRate}` : '—')
        this.MonitorReadout('快门', this.connected ? this.shutterDisplay() : '—')
        this.MonitorReadout('光圈', this.connected ? `f/${this.currentAperture.toFixed(1)}` : '—')
        this.MonitorReadout('ISO', this.connected ? `${this.currentIso}` : '—')
        this.MonitorReadout('白平衡', this.connected ? '自动' : '—')
        this.MonitorReadout('编码', this.connected ? this.videoCodecShortLabel() : '—')
        this.MonitorReadout('色调', this.connected ? `${this.currentCompensation >= 0 ? '+' : ''}${Math.round(this.currentCompensation)}` : '—')
      }
    }
    .width('100%')
    .height(66)
    .scrollable(ScrollDirection.Horizontal)
    .scrollBar(BarState.Off)
  }

  @Builder
  private MonitorParameterControls() {
    Scroll() {
      Row({ space: 8 }) {
        this.ImmersiveParameterControl('帧率', this.connected ? `${this.videoFrameRate}p` : '—', 'videoFrameRate')
        this.ImmersiveParameterControl(
          this.videoShutterMode === 'angle' ? '快门角度' : '快门速度',
          this.connected
            ? (this.videoShutterMode === 'angle'
                ? `${this.videoShutterAngle.toFixed(1)}°`
                : this.shutterDisplay())
            : '—',
          'videoShutter'
        )
        this.ImmersiveParameterControl('ISO', this.connected ? `${this.currentIso}` : '—', 'iso')
        this.ImmersiveParameterControl('光圈', this.connected ? `f/${this.currentAperture.toFixed(1)}` : '—', 'aperture')
      }
      .padding({ left: 2, right: 2 })
    }
    .width('100%')
    .height(58)
    .scrollable(ScrollDirection.Horizontal)
    .scrollBar(BarState.Off)
  }

  @Builder
  private MonitorReadout(label: string, value: string) {
    Column({ space: 2 }) {
      Text(this.tr(label))
        .fontSize(10)
        .fontWeight(FontWeight.Bold)
        .fontColor(UI_LABEL)
      Text(value)
        .fontSize(17)
        .fontFamily('monospace')
        .fontWeight(FontWeight.Bold)
        .fontColor(Color.White)
    }
    .width(72)
    .height(56)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  private MonitorToolRail() {
    Row() {
      this.MonitorTool('◎', '峰值对焦', 0)
      this.MonitorTool('LUT', 'LUT', 1)
      this.MonitorTool('◉', '假色', 2)
      this.MonitorTool('AF-ON', 'AF-ON', 3)
    }
    .width('100%')
    .padding({ top: 4, bottom: 8 })
  }

  @Builder
  private MonitorTool(glyph: string, description: string, index: number) {
    Button(glyph, { type: ButtonType.Normal })
      .layoutWeight(1)
      .height(52)
      .fontSize(index === 1 ? 11 : 24)
      .fontWeight(FontWeight.Bold)
      .fontColor(Color.White)
      .backgroundColor(Color.Transparent)
      .borderRadius(8)
      .accessibilityText(this.tr(description))
      .onClick((): void => {
        if (index === 0) {
          this.focusPeakingEnabled = !this.focusPeakingEnabled;
        } else if (index === 2) {
          this.falseColorEnabled = !this.falseColorEnabled;
        } else if (index === 3) {
          this.triggerAutoFocusOn();
        }
      })
  }

  private triggerAutoFocusOn(): void {
    if (!this.connected || !this.liveView || this.busy) {
      this.showError('请先开启实时取景');
      return;
    }
    this.camera.triggerAutoFocus().then((): void => {
      this.status = 'AF-ON 已触发';
    }).catch((error: Error): void => {
      this.showError(`AF-ON 失败：${error.message}`);
    });
  }

  private focusAtMonitorPoint(x: number, y: number): void {
    if (!this.connected || !this.liveView || this.busy) {
      this.showError('请先开启实时取景');
      return;
    }
    this.monitorFocusPointX = Math.max(0, Math.min(1, x));
    this.monitorFocusPointY = Math.max(0, Math.min(1, y));
    setTimeout((): void => {
      this.monitorFocusPointX = -1;
      this.monitorFocusPointY = -1;
    }, 1400);
    const dx: number = x - 0.5;
    const dy: number = y - 0.5;
    const step: number = Math.abs(dx) >= Math.abs(dy)
      ? Math.round(Math.max(-3, Math.min(3, dx * 8)))
      : Math.round(Math.max(-3, Math.min(3, dy * 8)));
    this.camera.setParameter('focusMode', 'single-shot').then((): Promise<void> => {
      return step === 0 ? Promise.resolve() : this.camera.moveFocus(step);
    }).catch((error: Error): void => {
      this.showError(`对焦请求失败：${error.message}`);
    });
    if (step === 0) this.status = '已触发单次自动对焦';
    else this.status = '焦点步进已完成（当前相机不支持二维对焦点）';
  }

  private normalizeMonitorPoint(x: number, y: number): Array<number> | undefined {
    // ImageFit.Contain centers the source and leaves letterbox margins; ignore taps in those margins.
    // PixelMap dimensions are not exposed synchronously here, so use the monitor's 16:9 transport aspect as fallback.
    const containerWidth = Math.max(1, this.monitorStageWidth);
    const containerHeight = Math.max(1, this.monitorStageHeight);
    const sourceAspect = 16 / 9;
    const containerAspect = containerWidth / containerHeight;
    let left = 0;
    let top = 0;
    let width = 1;
    let height = 1;
    if (containerAspect > sourceAspect) {
      width = containerWidth * (sourceAspect / containerAspect);
      left = (containerWidth - width) / 2;
    } else {
      height = containerHeight * (containerAspect / sourceAspect);
      top = (containerHeight - height) / 2;
    }
    if (x < left || x > left + width || y < top || y > top + height) return undefined;
    return [Math.max(0, Math.min(1, (x - left) / width)), Math.max(0, Math.min(1, (y - top) / height))];
  }

  @Builder
  private MonitorStorageCard() {
    Row({ space: 12 }) {
      Text('▯')
        .fontSize(36)
        .fontColor(Color.White)
        .width(48)
        .textAlign(TextAlign.Center)
      Column({ space: 3 }) {
        Text('—')
          .fontSize(22)
          .fontFamily('monospace')
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.White)
        Text(this.librarySizeText())
          .fontSize(14)
          .fontColor(UI_BLUE)
        Row() {
          Text('图库占用 · 本地缓存')
            .fontSize(TS_CAPTION)
            .fontWeight(FontWeight.Bold)
            .fontColor(Color.White)
            .layoutWeight(1)
          Text(this.photos.length > 0 ? `${this.photos.length} 个文件` : '暂无文件')
            .fontSize(TS_CAPTION)
            .fontWeight(FontWeight.Bold)
            .fontColor(Color.White)
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .height(88)
    .padding(14)
    .backgroundColor(UI_CARD)
    .borderRadius(15)
  }

  private librarySizeText(): string {
    const bytes: number = this.photos.reduce(
      (total: number, item: PhotoItem): number => total + item.size,
      0
    );
    if (bytes <= 0) {
      return '暂无本地图库文件';
    }
    if (bytes >= 1024 * 1024 * 1024) {
      return `${(bytes / (1024 * 1024 * 1024)).toFixed(1)} GB`;
    }
    if (bytes >= 1024 * 1024) {
      return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
    }
    return `${Math.max(1, Math.round(bytes / 1024))} KB`;
  }

  @Builder
  private ExposureReadoutRail() {
    Scroll() {
      Row() {
        this.ReadoutCell(
          '来源',
          this.connected ? 'USB/PTP' : (this.localCameraSelected ? '本机' : '—'),
          false,
          false
        )
        this.ReadoutDivider()
        this.ReadoutCell(
          '模式',
          this.connected ? this.exposureModeCode() : '—',
          false,
          false
        )
        this.ReadoutDivider()
        this.ReadoutCell(
          '快门',
          this.connected ? this.shutterDisplay() : '—',
          this.connected && this.camera.canAdjustParameter('exposureTime'),
          true
        )
        this.ReadoutDivider()
        this.ReadoutCell(
          '光圈',
          this.connected ? `f/${this.currentAperture.toFixed(1)}` : '—',
          this.connected && this.camera.canAdjustParameter('aperture'),
          true
        )
        this.ReadoutDivider()
        this.ReadoutCell(
          'ISO',
          this.connected ? `${this.currentIso}` : '—',
          this.connected && this.camera.canAdjustParameter('iso'),
          true
        )
        this.ReadoutDivider()
        this.ReadoutCell(
          '曝光补偿',
          this.connected ? `${this.currentCompensation.toFixed(1)} EV` : '—',
          this.connected &&
            this.camera.canAdjustParameter('exposureCompensation'),
          true
        )
      }
      .padding({ left: 8, right: 8 })
    }
    .width('100%')
    .height(82)
    .scrollable(ScrollDirection.Horizontal)
    .scrollBar(BarState.Off)
    .backgroundColor($r('app.color.graphite'))
    .border({
      width: 1,
      color: $r('app.color.graphite_rule'),
      radius: 14
    })
  }

  @Builder
  private ReadoutCell(
    label: string,
    value: string,
    writable: boolean,
    showsAuto: boolean
  ) {
    Column({ space: 6 }) {
      Text(
        this.tr(label) +
          (this.connected && showsAuto && !writable
            ? ` · ${this.tr('自动')}`
            : '')
      )
        .fontSize(9)
        .fontFamily('monospace')
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.graphite_muted'))
        .maxLines(1)
      Text(value)
        .fontSize(21)
        .fontFamily('monospace')
        .fontWeight(FontWeight.Bold)
        .fontColor(
          writable
            ? $r('app.color.readout_glow')
            : $r('app.color.graphite_ink')
        )
        .maxLines(1)
    }
    .width(116)
    .height(62)
    .padding({ left: 12, right: 12 })
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private ReadoutDivider() {
    Divider()
      .vertical(true)
      .height(42)
      .strokeWidth(1)
      .color(RULE)
  }

  @Builder
  private ShootingTaskPanel() {
    Column({ space: 10 }) {
      Text(this.tr('拍摄自动化'))
        .fontSize(TS_TITLE)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.ink'))
        .width('100%')
      Text(this.tr('间隔、包围与 B 门任务集中管理'))
        .fontSize(TS_BODY)
        .fontColor($r('app.color.muted'))
        .width('100%')
      Select([
        { value: this.tr('间隔拍摄') },
        { value: this.tr('曝光包围') },
        { value: this.tr('焦点包围') },
        { value: this.tr('B 门计时') }
      ])
        .selected(
          this.shootingTaskKind === 'exposure' ? 1 :
            this.shootingTaskKind === 'focus' ? 2 :
              this.shootingTaskKind === 'bulb' ? 3 : 0
        )
        .width('100%')
        .onSelect((index: number): void => {
          this.shootingTaskKind =
            ['interval', 'exposure', 'focus', 'bulb'][index];
        })
      Text(`${this.tr('张数')} · ${this.shootingTaskCount}`)
        .fontSize(TS_BODY)
        .fontColor($r('app.color.muted'))
        .width('100%')
      Slider({
        value: this.shootingTaskCount,
        min: 1,
        max: 99,
        step: 1,
        style: SliderStyle.OutSet
      })
        .onChange((value: number): void => {
          this.shootingTaskCount = Math.round(value);
        })
      Text(
        `${this.tr(
          this.shootingTaskKind === 'bulb' ? '曝光时长' : '间隔'
        )} · ${this.shootingTaskInterval} ${this.tr('秒')}`
      )
        .fontSize(TS_BODY)
        .fontColor($r('app.color.muted'))
        .width('100%')
      Slider({
        value: this.shootingTaskInterval,
        min: 1,
        max: 60,
        step: 1,
        style: SliderStyle.OutSet
      })
        .onChange((value: number): void => {
          this.shootingTaskInterval = Math.round(value);
        })
      if (
        this.shootingTaskKind === 'exposure' ||
        this.shootingTaskKind === 'focus'
      ) {
        Text(`${this.tr('包围步长')} · ${this.shootingTaskStep}`)
          .fontSize(TS_BODY)
          .fontColor($r('app.color.muted'))
          .width('100%')
        Slider({
          value: this.shootingTaskStep,
          min: 1,
          max: 3,
          step: 1,
          style: SliderStyle.OutSet
        })
          .onChange((value: number): void => {
            this.shootingTaskStep = Math.round(value);
          })
      }
      Text(this.tr(this.shootingTaskStatus))
        .fontSize(TS_CAPTION)
        .fontFamily('monospace')
        .fontColor($r('app.color.muted'))
        .width('100%')
      Button(
        this.tr(this.shootingTaskRunning ? '取消任务' : '开始任务'),
        { type: ButtonType.Normal }
      )
        .height(44)
        .width('100%')
        .fontColor($r('app.color.accent_ink'))
        .backgroundColor(
          this.shootingTaskRunning
            ? $r('app.color.video')
            : $r('app.color.accent')
        )
        .borderRadius(6)
        .enabled(this.connected)
        .onClick((): void => {
          if (this.shootingTaskRunning) {
            this.cancelShootingTask();
          } else {
            this.startShootingTask();
          }
        })
    }
    .width('100%')
    .padding(16)
    .alignItems(HorizontalAlign.Start)
    .backgroundColor($r('app.color.surface'))
    .border({
      width: 1,
      color: $r('app.color.rule'),
      radius: 8
    })
  }

  @Builder
  private LibraryWorkspace() {
    Column({ space: 16 }) {
      Text(this.tr('分支文件库'))
        .fontSize(TS_DISPLAY)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.ink'))
        .width('100%')
      Text(this.tr(
        `${this.photos.length} 个 帧澈 ZENCHE 文件 · ` +
        `${this.systemMedia.length} 个系统相册项目 · 拖动整理`
      ))
        .fontSize(14)
        .fontColor($r('app.color.muted'))
        .width('100%')
      this.BranchWorkspace()
      Button(
        this.tr(
          `${this.wirelessExpanded ? '⌄' : '›'} 无线传输 · ` +
          `${this.wifiConnected ? 'Wi‑Fi 已连接' : 'Wi‑Fi 未连接'} · ` +
          `${this.wirelessRunning ? '收件箱运行中' : '收件箱已停止'}`
        ),
        { type: ButtonType.Normal }
      )
        .width('100%')
        .height(44)
        .fontColor($r('app.color.ink'))
        .backgroundColor($r('app.color.paper_2'))
        .onClick((): void => {
          this.wirelessExpanded = !this.wirelessExpanded;
        })
      if (this.wirelessExpanded) {
        this.WirelessTransferCard()
      }
      this.CameraStorageWorkspace()
      Row({ space: 8 }) {
        Button(this.tr('刷新系统相册'), { type: ButtonType.Normal })
          .height(44)
          .layoutWeight(1)
          .fontColor($r('app.color.ink'))
          .backgroundColor($r('app.color.paper_2'))
          .borderRadius(6)
          .onClick((): void => {
            this.loadSystemAlbum();
          })
        Button(this.tr('链接网盘'), { type: ButtonType.Normal })
          .height(44)
          .layoutWeight(1)
          .fontColor($r('app.color.ink'))
          .backgroundColor($r('app.color.paper_2'))
          .borderRadius(6)
          .onClick((): void => {
            this.cloudGuideVisible = true;
          })
      }
      .width('100%')
      Text(this.tr('系统相册中的照片与视频直接显示在本页；网盘文件通过独立指引页和系统文件选择器安全加入。'))
        .fontSize(TS_BODY)
        .fontColor($r('app.color.muted'))
        .width('100%')
      Button(
        this.tr(
          `${this.systemExpanded ? '⌄' : '›'} 系统相册 · ` +
          `${this.systemMedia.length}`
        ),
        { type: ButtonType.Normal }
      )
        .width('100%')
        .height(44)
        .fontColor($r('app.color.ink'))
        .backgroundColor($r('app.color.paper_2'))
        .onClick((): void => {
          this.systemExpanded = !this.systemExpanded;
        })
      if (this.systemExpanded && this.systemMedia.length === 0) {
        Column({ space: 8 }) {
          Text(this.tr('系统相册暂不可见'))
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
          Text(this.tr('允许照片和视频访问后，最近媒体会直接显示在这里。'))
            .fontSize(TS_BODY)
            .fontColor($r('app.color.muted'))
        }
        .width('100%')
        .height(120)
        .justifyContent(FlexAlign.Center)
        .backgroundColor($r('app.color.surface'))
        .border({
          width: 1,
          color: $r('app.color.rule'),
          radius: 14
        })
      } else if (this.systemExpanded) {
        Row({ space: 8 }) {
          Button(
            this.tr(
              `${this.systemPhotosExpanded ? '⌄' : '›'} 照片 · ` +
              `${this.systemMedia.filter((item: SystemMediaItem): boolean => !item.isVideo).length}`
            )
          )
            .height(44)
            .layoutWeight(1)
            .onClick((): void => {
              this.systemPhotosExpanded = !this.systemPhotosExpanded;
            })
          Button(
            this.tr(
              `${this.systemVideosExpanded ? '⌄' : '›'} 视频 · ` +
              `${this.systemMedia.filter((item: SystemMediaItem): boolean => item.isVideo).length}`
            )
          )
            .height(44)
            .layoutWeight(1)
            .onClick((): void => {
              this.systemVideosExpanded = !this.systemVideosExpanded;
            })
        }
        .width('100%')
        List({ space: 8 }) {
          ForEach(
            this.systemMedia.filter((item: SystemMediaItem): boolean => {
              return item.isVideo
                ? this.systemVideosExpanded
                : this.systemPhotosExpanded;
            }),
            (item: SystemMediaItem) => {
              ListItem() {
                Column({ space: 6 }) {
                  Stack({ alignContent: Alignment.BottomEnd }) {
                    Image(item.uri)
                      .width(150)
                      .height(108)
                      .objectFit(ImageFit.Cover)
                    if (item.isVideo) {
                      Text(`▶ ${this.durationLabel(item.duration)}`)
                        .fontSize(10)
                        .fontFamily('monospace')
                        .fontColor(Color.White)
                        .backgroundColor(HUD_BG_SOFT)
                        .borderRadius(12)
                        .padding({
                          left: 7,
                          right: 7,
                          top: 4,
                          bottom: 4
                        })
                        .margin(6)
                    }
                  }
                  Text(item.name)
                    .fontSize(TS_CAPTION)
                    .fontWeight(FontWeight.Medium)
                    .fontColor($r('app.color.ink'))
                    .width(150)
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                }
                .padding(8)
                .backgroundColor($r('app.color.surface'))
                .border({
                  width: 1,
                  color: $r('app.color.rule'),
                  radius: 8
                })
                .gesture(
                  TapGesture({ count: 2 })
                    .onAction((): void => {
                      this.openSystemMedia(item);
                    })
                )
              }
            },
            (item: SystemMediaItem): string => item.id
          )
        }
        .width('100%')
        .height(164)
        .listDirection(Axis.Horizontal)
        .scrollBar(BarState.Auto)
      }
      if (this.systemExpanded) {
        Text(this.tr('系统相册内容保持在原位置；帧澈 ZENCHE 只读取缩略图和预览。'))
          .fontSize(TS_CAPTION)
          .fontColor($r('app.color.muted'))
          .width('100%')
      }
    }
    .width('100%')
    .height(this.isCompact() ? 'auto' : '100%')
    .padding(16)
  }

  @Builder
  private CameraStorageWorkspace() {
    Column({ space: 10 }) {
      Button(
        this.tr(
          `${this.cameraStorageExpanded ? '⌄' : '›'} 相机机内存储 · ` +
          `${this.cameraStorageSnapshot.items.length}`
        ),
        { type: ButtonType.Normal }
      )
        .width('100%')
        .height(48)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.ink'))
        .backgroundColor($r('app.color.paper_2'))
        .onClick((): void => {
          this.cameraStorageExpanded = !this.cameraStorageExpanded;
        })
      if (this.cameraStorageExpanded) {
        Text(
          this.cameraStorageSnapshot.capacityBytes > 0
            ? `${this.formatStorageSize(
              this.cameraStorageSnapshot.capacityBytes -
                this.cameraStorageSnapshot.freeBytes
            )} 已用 / ${this.formatStorageSize(
              this.cameraStorageSnapshot.capacityBytes
            )}`
            : this.tr(this.cameraStorageStatus)
        )
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.muted'))
          .width('100%')
        Row({ space: 8 }) {
          Button(
            this.cameraStorageBusy ? this.tr('正在读取…') : this.tr('刷新机内文件'),
            { type: ButtonType.Normal }
          )
            .height(44)
            .layoutWeight(1)
            .fontColor($r('app.color.accent_ink'))
            .backgroundColor($r('app.color.accent'))
            .enabled(
              !this.cameraStorageBusy && (this.connected || this.wifiConnected)
            )
            .onClick((): void => {
              this.refreshCameraStorage();
            })
          Button(
            this.selectedCameraStorageHandles.length > 0 &&
              this.selectedCameraStorageHandles.length ===
                this.cameraStorageSnapshot.items.filter(
                  (item: CameraStorageItem): boolean => !item.protectedObject
                ).length
              ? this.tr('取消全选')
              : this.tr('全选'),
            { type: ButtonType.Normal }
          )
            .height(44)
            .layoutWeight(1)
            .enabled(!this.cameraStorageBusy && this.cameraStorageSnapshot.items.length > 0)
            .onClick((): void => {
              const selectable: Array<number> = this.cameraStorageSnapshot.items
                .filter((item: CameraStorageItem): boolean => !item.protectedObject)
                .map((item: CameraStorageItem): number => item.handle);
              this.selectedCameraStorageHandles =
                this.selectedCameraStorageHandles.length === selectable.length
                  ? []
                  : selectable;
            })
        }
        .width('100%')
        Row({ space: 8 }) {
          Button(this.tr('下载所选'), { type: ButtonType.Normal })
            .height(44)
            .layoutWeight(1)
            .fontColor($r('app.color.accent_ink'))
            .backgroundColor($r('app.color.accent'))
            .enabled(!this.cameraStorageBusy && this.selectedCameraStorageHandles.length > 0)
            .onClick((): void => {
              this.downloadSelectedCameraStorage();
            })
          Button(this.tr('从相机删除'), { type: ButtonType.Normal })
            .height(44)
            .layoutWeight(1)
            .fontColor(Color.White)
            .backgroundColor($r('app.color.video'))
            .enabled(!this.cameraStorageBusy && this.selectedCameraStorageHandles.length > 0)
            .onClick((): void => {
              this.confirmDeleteSelectedCameraStorage();
            })
        }
        .width('100%')
        if (!this.connected && !this.wifiConnected) {
          Text(this.tr('请先连接 USB/PTP 或 Wi‑Fi/PTP‑IP 相机。系统摄像头不开放机内存储。'))
            .fontSize(13)
            .fontColor($r('app.color.muted'))
            .textAlign(TextAlign.Center)
            .width('100%')
            .padding(22)
        } else if (this.cameraStorageSnapshot.items.length === 0) {
          Text(this.tr(
            this.cameraStorageBusy
              ? '正在读取存储卷与文件信息…'
              : '暂无机内文件。点击“刷新机内文件”读取相机存储卡。'
          ))
            .fontSize(13)
            .fontColor($r('app.color.muted'))
            .textAlign(TextAlign.Center)
            .width('100%')
            .padding(22)
        } else {
          List({ space: 6 }) {
            ForEach(
              this.cameraStorageSnapshot.items,
              (item: CameraStorageItem) => {
                ListItem() {
                  Row({ space: 10 }) {
                    Checkbox({
                      name: `camera-storage-${item.handle}`,
                      group: 'camera-storage-selection'
                    })
                      .select(this.selectedCameraStorageHandles.indexOf(item.handle) >= 0)
                      .enabled(!item.protectedObject && !this.cameraStorageBusy)
                      .onChange((selected: boolean): void => {
                        this.toggleCameraStorageSelection(item.handle, selected);
                      })
                    Stack({ alignContent: Alignment.Center }) {
                      Text(item.isVideo ? '▶' : '▣')
                        .fontSize(TS_TITLE)
                        .fontColor(Color.White)
                    }
                      .width(60)
                      .height(44)
                      .backgroundColor($r('app.color.graphite'))
                      .borderRadius(6)
                    Column({ space: 3 }) {
                      Text(item.filename)
                        .fontSize(14)
                        .fontWeight(FontWeight.Medium)
                        .fontColor($r('app.color.ink'))
                        .maxLines(1)
                        .textOverflow({ overflow: TextOverflow.Ellipsis })
                        .width('100%')
                      Text(
                        `${this.formatStorageSize(item.sizeBytes)}` +
                        `${item.width > 0 && item.height > 0
                          ? ` · ${item.width} × ${item.height}` : ''}` +
                        ` · ${item.capturedAt}` +
                        `${item.protectedObject ? ' · 已保护' : ''}`
                      )
                        .fontSize(TS_CAPTION)
                        .fontFamily('monospace')
                        .fontColor($r('app.color.muted'))
                        .maxLines(1)
                        .width('100%')
                    }
                      .layoutWeight(1)
                      .alignItems(HorizontalAlign.Start)
                  }
                  .width('100%')
                  .height(60)
                  .padding({ left: 8, right: 8, top: 6, bottom: 6 })
                  .backgroundColor($r('app.color.surface'))
                  .border({
                    width: 1,
                    color: $r('app.color.rule'),
                    radius: 8
                  })
                }
              },
              (item: CameraStorageItem): string => `${item.handle}`
            )
          }
            .width('100%')
            .height(Math.min(420, Math.max(72, this.cameraStorageSnapshot.items.length * 68)))
            .scrollBar(BarState.Auto)
        }
        Text(this.tr(this.cameraStorageStatus))
          .fontSize(TS_CAPTION)
          .fontFamily('monospace')
          .fontColor($r('app.color.muted'))
          .width('100%')
      }
    }
    .width('100%')
    .padding(12)
    .alignItems(HorizontalAlign.Start)
    .backgroundColor($r('app.color.surface'))
    .border({
      width: 1,
      color: $r('app.color.rule'),
      radius: 12
    })
  }

  @Builder
  private BranchWorkspace() {
    if (this.isCompact()) {
      Column({ space: 8 }) {
        Button(
          this.tr(
            `${this.mobileBranchDrawerExpanded ? '⌄' : '›'} 分支抽屉 · ` +
            `${this.userLibraryBranches.length} 个根分支`
          ),
          { type: ButtonType.Normal }
        )
          .width('100%')
          .height(56)
          .fontSize(TS_EMPHASIS)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.ink'))
          .backgroundColor($r('app.color.surface'))
          .border({
            width: 1,
            color: $r('app.color.accent'),
            radius: 12
          })
          .onClick((): void => {
            this.mobileBranchDrawerExpanded =
              !this.mobileBranchDrawerExpanded;
          })
        if (this.mobileBranchDrawerExpanded) {
          this.BranchWorkspaceContent()
        }
      }
      .width('100%')
    } else {
      this.BranchWorkspaceContent()
    }
  }

  @Builder
  private BranchWorkspaceContent() {
    Column({ space: 10 }) {
      Row({ space: 12 }) {
        Text('分支')
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.White)
          .width(54)
          .height(54)
          .textAlign(TextAlign.Center)
          .backgroundColor($r('app.color.accent'))
          .borderRadius(14)
        Column({ space: 3 }) {
          Text(this.tr('分支工作台'))
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.ink'))
          Text(this.tr('长按文件并拖到任意分支；拖回“未分类”即可移出分支。'))
            .fontSize(TS_BODY)
            .fontColor($r('app.color.muted'))
            .maxLines(2)
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        Button(this.tr('＋ 新建分支'), { type: ButtonType.Normal })
          .height(44)
          .fontColor(Color.White)
          .backgroundColor($r('app.color.accent'))
          .borderRadius(8)
          .onClick((): void => {
            this.beginCreatingLibraryBranch('', '帧澈 ZENCHE 文件库');
          })
      }
      .width('100%')
      this.UserLibraryBranchTree()
      Button(
        this.tr(
          `${this.localUnclassifiedExpanded ? '⌄' : '›'} 未分类 · ` +
          `${this.unclassifiedPhotos().length}`
        ),
        { type: ButtonType.Normal }
      )
        .width('100%')
        .height(48)
        .fontColor($r('app.color.ink'))
        .backgroundColor(
          this.libraryDropTargetId === 'unclassified'
            ? $r('app.color.accent_soft')
            : $r('app.color.paper_2')
        )
        .border({
          width: this.libraryDropTargetId === 'unclassified' ? 2 : 1,
          color: this.libraryDropTargetId === 'unclassified'
            ? $r('app.color.accent')
            : $r('app.color.rule'),
          radius: 8
        })
        .onClick((): void => {
          this.localUnclassifiedExpanded =
            !this.localUnclassifiedExpanded;
        })
        .onDragEnter((_event: DragEvent): void => {
          this.libraryDropTargetId = 'unclassified';
        })
        .onDragLeave((_event: DragEvent): void => {
          if (this.libraryDropTargetId === 'unclassified') {
            this.libraryDropTargetId = '';
          }
        })
        .onDrop((_event: DragEvent): void => {
          this.assignPhotoToBranch(this.draggedPhotoPath, '');
          this.libraryDropTargetId = '';
        })
      if (
        this.localUnclassifiedExpanded &&
        this.unclassifiedPhotos().length === 0
      ) {
        Column({ space: 6 }) {
          Text(this.tr('未分类已清空'))
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
          Text(this.tr('拍摄、导入或无线接收的新文件会先显示在这里。'))
            .fontSize(TS_BODY)
            .fontColor($r('app.color.muted'))
        }
        .width('100%')
        .height(100)
        .justifyContent(FlexAlign.Center)
      } else if (this.localUnclassifiedExpanded) {
        this.LocalPhotoCollection(this.unclassifiedPhotos())
      }
    }
    .width('100%')
    .padding(16)
    .backgroundColor($r('app.color.surface'))
    .border({
      width: 1,
      color: $r('app.color.accent'),
      radius: 16
    })
  }

  @Builder
  private LocalPhotoCollection(items: Array<PhotoItem>) {
    Row({ space: 8 }) {
      Button(
        this.tr(
          `${this.localPhotosExpanded ? '⌄' : '›'} 照片 · ` +
          `${items.filter((item: PhotoItem): boolean => !item.isVideo).length}`
        )
      )
        .height(44)
        .layoutWeight(1)
        .onClick((): void => {
          this.localPhotosExpanded = !this.localPhotosExpanded;
        })
      Button(
        this.tr(
          `${this.localVideosExpanded ? '⌄' : '›'} 视频 · ` +
          `${items.filter((item: PhotoItem): boolean => item.isVideo).length}`
        )
      )
        .height(44)
        .layoutWeight(1)
        .onClick((): void => {
          this.localVideosExpanded = !this.localVideosExpanded;
        })
    }
    .width('100%')
    List({ space: 8 }) {
      ForEach(
        items.filter((item: PhotoItem): boolean => {
          return item.isVideo
            ? this.localVideosExpanded
            : this.localPhotosExpanded;
        }),
        (item: PhotoItem) => {
          ListItem() {
            this.LocalPhotoRow(item)
          }
        },
        (item: PhotoItem): string => item.path
      )
    }
    .width('100%')
    .height(Math.min(320, Math.max(96, items.length * 82)))
  }

  @Builder
  private LocalPhotoRow(item: PhotoItem) {
    Row({ space: 12 }) {
      if (item.isVideo) {
        Stack({ alignContent: Alignment.Center }) {
          Text('▶')
            .fontSize(20)
            .fontColor(Color.White)
        }
        .width(68)
        .height(50)
        .backgroundColor($r('app.color.graphite'))
        .borderRadius(6)
      } else {
        Image(`file://${item.path}`)
          .width(68)
          .height(50)
          .objectFit(ImageFit.Cover)
          .borderRadius(6)
      }
      Column({ space: 4 }) {
        Text(item.name)
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.ink'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(item.detail)
          .fontSize(10)
          .fontFamily('monospace')
          .fontColor($r('app.color.muted'))
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      Button(this.tr('预览'), { type: ButtonType.Normal })
        .height(44)
        .fontColor($r('app.color.ink'))
        .backgroundColor($r('app.color.paper_2'))
        .borderRadius(6)
        .onClick((): void => {
          this.previewPhoto(item);
        })
      Button(this.tr('分享'), { type: ButtonType.Normal })
        .height(44)
        .fontColor($r('app.color.ink'))
        .backgroundColor($r('app.color.paper_2'))
        .borderRadius(6)
        .onClick((): void => {
          this.sharePhoto(item);
        })
      Button(this.tr('删除'), { type: ButtonType.Normal })
        .height(44)
        .fontColor($r('app.color.error'))
        .backgroundColor($r('app.color.surface'))
        .border({
          width: 1,
          color: $r('app.color.error'),
          radius: 6
        })
        .onClick((): void => {
          this.deletePhoto(item);
        })
    }
    .width('100%')
    .padding(12)
    .backgroundColor($r('app.color.surface'))
    .border({
      width: 1,
      color: $r('app.color.rule'),
      radius: 8
    })
    .gesture(
      TapGesture({ count: 2 })
        .onAction((): void => {
          this.openLargePhoto(item);
        })
    )
    .onDragStart((_event: DragEvent): DragItemInfo => {
      this.draggedPhotoPath = item.path;
      return { extraInfo: item.path };
    })
    .dragPreview(item.name)
  }

  @Builder
  private UserLibraryBranchTree() {
    Column({ space: 4 }) {
      Row({ space: 8 }) {
        Text(this.tr('用户分支'))
          .fontSize(TS_EMPHASIS)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.ink'))
          .layoutWeight(1)
        Text(this.tr(`${this.userLibraryBranches.length} 个根节点`))
          .fontSize(TS_CAPTION)
          .fontFamily('monospace')
          .fontColor($r('app.color.muted'))
      }
      .width('100%')
      if (this.userLibraryBranches.length === 0) {
        Text(this.tr('可建立项目、客户或拍摄日等分支；媒体仍保留在原始存储位置。'))
          .fontSize(TS_BODY)
          .fontColor($r('app.color.muted'))
          .width('100%')
          .padding({ top: 8, bottom: 8 })
      } else {
        ForEach(
          this.userLibraryBranches,
          (branch: LibraryBranch) => {
            this.LibraryBranchNode(branch, 0)
          },
          (branch: LibraryBranch): string => branch.id
        )
      }
    }
    .width('100%')
    .padding({ top: 6, bottom: 8 })
  }

  @Builder
  private LibraryBranchNode(
    branch: LibraryBranch,
    depth: number
  ) {
    Column({ space: 4 }) {
      Row({ space: 6 }) {
        Button(
          this.isLibraryBranchExpanded(branch.id) ? '⌄' : '›',
          { type: ButtonType.Normal }
        )
          .width(52)
          .height(52)
          .fontColor($r('app.color.ink'))
          .backgroundColor(Color.Transparent)
          .onClick((): void => {
            this.toggleLibraryBranch(branch.id);
          })
        Text(`▱  ${branch.name}`)
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.ink'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
          .height(52)
          .onClick((): void => {
            this.toggleLibraryBranch(branch.id);
          })
        Text(`${this.photosForBranch(branch.id).length} 文件`)
          .fontSize(TS_CAPTION)
          .fontFamily('monospace')
          .fontColor($r('app.color.muted'))
          .width(62)
          .height(52)
          .textAlign(TextAlign.Center)
          .onClick((): void => {
            this.toggleLibraryBranch(branch.id);
          })
        Button('＋', { type: ButtonType.Normal })
          .width(44)
          .height(44)
          .fontColor($r('app.color.ink'))
          .backgroundColor(Color.Transparent)
          .onClick((): void => {
            this.beginCreatingLibraryBranch(branch.id, branch.name);
          })
        Button(this.tr('删'), { type: ButtonType.Normal })
          .width(44)
          .height(44)
          .fontColor($r('app.color.error'))
          .backgroundColor(Color.Transparent)
          .onClick((): void => {
            this.beginDeletingLibraryBranch(branch);
          })
      }
      .width('100%')
      .height(52)
      .padding({ left: 8 + depth * 14, right: 4 })
      .backgroundColor(
        this.libraryDropTargetId === branch.id
          ? $r('app.color.accent_soft')
          : depth === 0
            ? $r('app.color.paper_2')
            : $r('app.color.surface')
      )
      .border({
        width: this.libraryDropTargetId === branch.id ? 2 : 1,
        color: this.libraryDropTargetId === branch.id
          ? $r('app.color.accent')
          : $r('app.color.rule'),
        radius: 8
      })
      .onDragEnter((_event: DragEvent): void => {
        this.libraryDropTargetId = branch.id;
      })
      .onDragLeave((_event: DragEvent): void => {
        if (this.libraryDropTargetId === branch.id) {
          this.libraryDropTargetId = '';
        }
      })
      .onDrop((_event: DragEvent): void => {
        this.assignPhotoToBranch(this.draggedPhotoPath, branch.id);
        this.libraryDropTargetId = '';
      })
      if (this.isLibraryBranchExpanded(branch.id)) {
        ForEach(
          this.photosForBranch(branch.id),
          (item: PhotoItem) => {
            this.LocalPhotoRow(item)
          },
          (item: PhotoItem): string => item.path
        )
        if (
          this.photosForBranch(branch.id).length === 0 &&
          branch.children.length === 0
        ) {
          Text(this.tr('拖动文件到这里'))
            .fontSize(TS_BODY)
            .fontColor($r('app.color.muted'))
            .width('100%')
            .height(32)
            .padding({ left: 54 + (depth + 1) * 14 })
        }
        ForEach(
          branch.children,
          (child: LibraryBranch) => {
            this.LibraryBranchNode(child, depth + 1)
          },
          (child: LibraryBranch): string => child.id
        )
      }
    }
    .width('100%')
  }

  @Builder
  private CaptureSessionPanel() {
    Column({ space: 8 }) {
      Button(
        `${this.captureSessionExpanded ? '⌄' : '›'} ${this.tr('拍前会话与交付')}`,
        { type: ButtonType.Normal }
      )
        .height(44)
        .fontSize(TS_TITLE)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.ink'))
        .backgroundColor(Color.Transparent)
        .width('100%')
        .onClick((): void => {
          this.captureSessionExpanded = !this.captureSessionExpanded;
        })
      if (this.captureSessionExpanded) {
      TextInput({
        placeholder: this.tr('项目名称'),
        text: this.sessionName
      })
        .height(44)
        .onChange((value: string): void => {
          this.sessionName = value;
        })
      TextInput({
        placeholder: this.tr('命名模板'),
        text: this.sessionNamingTemplate
      })
        .height(44)
        .fontFamily('monospace')
        .onChange((value: string): void => {
          this.sessionNamingTemplate = value;
        })
      Row({ space: 8 }) {
        TextInput({
          placeholder: this.tr('创作者'),
          text: this.sessionCreator
        })
          .height(44)
          .layoutWeight(1)
          .onChange((value: string): void => {
            this.sessionCreator = value;
          })
        TextInput({
          placeholder: this.tr('版权'),
          text: this.sessionRights
        })
          .height(44)
          .layoutWeight(1)
          .onChange((value: string): void => {
            this.sessionRights = value;
          })
      }
      .width('100%')
      Text(`${this.tr('默认评级')} · ${this.sessionRating} ★`)
        .fontSize(TS_BODY)
        .fontColor($r('app.color.muted'))
        .width('100%')
      Slider({
        value: this.sessionRating,
        min: 0,
        max: 5,
        step: 1,
        style: SliderStyle.OutSet
      })
        .onChange((value: number): void => {
          this.sessionRating = Math.round(value);
        })
      Row() {
        Text(this.tr('双目标备份'))
          .fontSize(13)
          .fontColor($r('app.color.ink'))
          .layoutWeight(1)
        Toggle({
          type: ToggleType.Switch,
          isOn: this.sessionDualBackup
        })
          .onChange((enabled: boolean): void => {
            this.sessionDualBackup = enabled;
          })
      }
      .width('100%')
      Text(this.tr(
        'RAW + JPEG 自动配对，并生成 XMP 与 SHA-256 清单。'
      ))
        .fontSize(TS_CAPTION)
        .fontColor($r('app.color.muted'))
        .width('100%')
      Text(this.tr(
        this.captureWorkflow?.status ?? '尚未开始拍摄会话'
      ))
        .fontSize(TS_CAPTION)
        .fontFamily('monospace')
        .fontColor($r('app.color.muted'))
        .width('100%')
      Button(
        this.tr(
          (this.captureWorkflow?.isActive ?? false)
            ? '结束会话'
            : '开始会话'
        ),
        { type: ButtonType.Normal }
      )
        .height(44)
        .width('100%')
        .fontColor($r('app.color.accent_ink'))
        .backgroundColor($r('app.color.accent'))
        .borderRadius(6)
        .onClick((): void => {
          this.toggleCaptureSession();
        })
      }
    }
    .width('100%')
    .padding(16)
    .alignItems(HorizontalAlign.Start)
    .backgroundColor($r('app.color.surface'))
    .border({
      width: 1,
      color: $r('app.color.rule'),
      radius: 8
    })
  }

  @Builder
  private WifiCameraTransferSection() {
    Column({ space: 10 }) {
      Row() {
        Column({ space: 3 }) {
          Text(this.tr('Wi‑Fi 相机 · PTP/IP'))
            .fontSize(TS_TITLE)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.ink'))
          Text(this.tr('相机控制'))
            .fontSize(TS_CAPTION)
            .fontColor($r('app.color.muted'))
          Text(this.tr(this.wifiStatus))
            .fontSize(TS_CAPTION)
            .fontColor(this.wifiConnected
              ? $r('app.color.positive')
              : $r('app.color.muted'))
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        Button(this.tr(this.wifiConnected ? '断开' : '连接'), {
          type: ButtonType.Normal
        })
          .height(44)
          .fontColor($r('app.color.accent_ink'))
          .backgroundColor($r('app.color.accent'))
          .borderRadius(8)
          .enabled(!this.wifiConnecting && !this.busy)
          .onClick((): void => {
            if (this.wifiConnected) {
              this.disconnectWifiCamera();
            } else {
              this.connectWifiCamera();
            }
          })
      }
      .width('100%')
      Text(this.tr('连接模式'))
        .fontSize(TS_CAPTION)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.ink'))
        .width('100%')
      Select([
        { value: this.tr('AP 直连') },
        { value: this.tr('STA 局域网') }
      ])
        .selected(this.wifiConnectionMode === 'sta' ? 1 : 0)
        .width('100%')
        .enabled(!this.wifiConnected && !this.wifiConnecting)
        .onSelect((index: number): void => {
          this.wifiConnectionMode = index === 1 ? 'sta' : 'ap';
          this.persistWifiConnectionSettings();
        })
      Text(this.tr(
        this.wifiConnectionMode === 'sta'
          ? 'STA 模式：让相机与设备加入同一局域网，并输入路由器分配给相机的 IP 地址。'
          : 'AP 模式：让设备加入相机热点；相机地址通常为 192.168.1.1。'
      ))
        .fontSize(TS_CAPTION)
        .fontColor($r('app.color.muted'))
        .width('100%')
      Row({ space: 10 }) {
        TextInput({ placeholder: '192.168.1.1', text: this.wifiHost })
          .height(44)
          .layoutWeight(1)
          .onChange((value: string): void => {
            this.wifiHost = value;
          })
        TextInput({ placeholder: '15740', text: this.wifiPort })
          .height(44)
          .width(108)
          .type(InputType.Number)
          .onChange((value: string): void => {
            this.wifiPort = value;
          })
      }
      .width('100%')
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private WirelessTransferCard() {
    Column({ space: 12 }) {
          this.WifiCameraTransferSection()
          Divider()
            .color($r('app.color.rule'))
          Text(this.tr('文件接收'))
            .fontSize(TS_CAPTION)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.muted'))
            .width('100%')
        Text(this.tr('多协议无线图片收件箱'))
            .fontSize(TS_TITLE)
            .fontWeight(FontWeight.Bold)
            .width('100%')
          Text(this.tr(this.wirelessStatus))
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .width('100%')
          Text(this.tr(this.wirelessAddress))
            .fontSize(13)
            .fontFamily('monospace')
            .fontColor($r('app.color.accent'))
            .width('100%')
          Button(
            this.tr(
              this.wirelessRunning ? '停止无线接收' : '开启无线接收'
            ),
            { type: ButtonType.Normal }
          )
            .height(44)
            .fontColor($r('app.color.accent_ink'))
            .backgroundColor($r('app.color.accent'))
            .borderRadius(6)
            .onClick((): void => {
              this.toggleWireless();
            })
          Text(this.tr(
            `FTP/PASV · ${this.wirelessAddress}\n` +
            `HTTP 上传 · 端口 ${HTTP_PORT} · /upload/文件名\n` +
            `WebDAV · 端口 ${HTTP_PORT} · 用户名/密码 nikonlink\n` +
            `接收完成后自动进入文件库`
          ))
            .fontSize(TS_BODY)
            .fontFamily('monospace')
            .fontColor($r('app.color.muted'))
            .width('100%')
    }
    .width('100%')
    .padding(20)
    .alignItems(HorizontalAlign.Start)
    .backgroundColor($r('app.color.surface'))
    .border({
      width: 1,
      color: $r('app.color.rule'),
      radius: 8
    })
  }

  @Builder
  private ConnectionPanelOverlay() {
    Column({ space: 14 }) {
      Row() {
        Column({ space: 3 }) {
          Text(this.tr('相机连接'))
            .fontSize(TS_DISPLAY)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.ink'))
          Text(this.tr('本机摄像头、USB/PTP 与官方 SDK'))
            .fontSize(TS_BODY)
            .fontColor($r('app.color.muted'))
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        Button(this.tr('关闭'), { type: ButtonType.Normal })
          .height(44)
          .fontColor($r('app.color.ink'))
          .backgroundColor($r('app.color.paper_2'))
          .borderRadius(8)
          .onClick((): void => {
            this.connectionPanelVisible = false;
          })
      }
      .width('100%')

      Row({ space: 12 }) {
        Column({ space: 4 }) {
          Text(this.tr('本机摄像头'))
            .fontSize(TS_TITLE)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.ink'))
          Text(this.tr(
            this.localCameraSelected
              ? '已选择 · 拍摄时由 HarmonyOS 系统相机接管取景'
              : '调用设备内置镜头拍照，并自动保存到帧澈文件库'
          ))
            .fontSize(TS_CAPTION)
            .fontColor(this.localCameraSelected
              ? $r('app.color.positive')
              : $r('app.color.muted'))
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        Button(this.tr(this.localCameraSelected ? '取消选择' : '使用'), {
          type: ButtonType.Normal
        })
          .height(44)
          .fontColor($r('app.color.accent_ink'))
          .backgroundColor($r('app.color.accent'))
          .borderRadius(8)
          .enabled(!this.busy)
          .onClick((): void => {
            if (this.localCameraSelected) {
              this.localCameraSelected = false;
              this.status = '已取消本机摄像头';
            } else {
              this.selectLocalCamera();
            }
          })
      }
      .width('100%')
      .padding(14)
      .backgroundColor($r('app.color.accent_soft'))
      .borderRadius(10)

      Row({ space: 12 }) {
        Column({ space: 4 }) {
          Text(this.tr('USB / PTP'))
            .fontSize(TS_TITLE)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.ink'))
          Text(this.connected
            ? `${this.cameraName} · ${this.tr('已连接')}`
            : this.tr('使用数据线连接受支持的相机'))
            .fontSize(TS_CAPTION)
            .fontColor($r('app.color.muted'))
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        Button(this.tr(this.connected ? '断开' : '连接'), {
          type: ButtonType.Normal
        })
          .height(44)
          .fontColor($r('app.color.accent_ink'))
          .backgroundColor($r('app.color.accent'))
          .borderRadius(8)
          .enabled(!this.busy)
          .onClick((): void => {
            this.toggleCameraConnection();
          })
      }
      .width('100%')
      .padding(14)
      .backgroundColor($r('app.color.paper_2'))
      .borderRadius(10)

    }
    .width('92%')
    .constraintSize({ maxWidth: 680 })
    .padding(20)
    .backgroundColor($r('app.color.surface'))
    .border({
      width: 1,
      color: $r('app.color.rule_strong'),
      radius: 16
    })
    .shadow({ radius: 24, color: HUD_SHADOW, offsetY: 10 })
  }

  @Builder
  private LargePhotoOverlay() {
    Column({ space: 12 }) {
      Row({ space: 8 }) {
        Button(this.tr('关闭'), { type: ButtonType.Normal })
          .height(44)
          .fontColor(Color.White)
          .backgroundColor(HUD_BG_MID)
          .borderRadius(8)
          .onClick((): void => {
            this.closeLargePhoto();
          })
        Button(this.tr('编辑'), { type: ButtonType.Normal })
          .height(44)
          .fontColor(Color.White)
          .backgroundColor(HUD_BG_MID)
          .borderRadius(8)
          .onClick((): void => {
            const item: PhotoItem | undefined = this.photos.find(
              (candidate: PhotoItem): boolean =>
                candidate.name === this.largePreviewName
            );
            if (item !== undefined && !item.isVideo) {
              this.editorSelectedPath = item.path;
              this.closeLargePhoto();
              this.section = 'editor';
            }
          })
        Blank()
        Button(this.tr('分享到社交平台'), { type: ButtonType.Normal })
          .height(44)
          .fontColor(Color.White)
          .backgroundColor($r('app.color.accent'))
          .borderRadius(8)
          .onClick((): void => {
            const item: PhotoItem | undefined = this.photos.find(
              (candidate: PhotoItem): boolean =>
                candidate.name === this.largePreviewName
            );
            if (item !== undefined) {
              this.sharePhoto(item);
            }
          })
      }
      .width('100%')
      if (this.largePreview !== undefined) {
        Image(this.largePreview)
          .objectFit(ImageFit.Contain)
          .width('100%')
          .layoutWeight(1)
      }
      Text(this.largePreviewName)
        .fontSize(TS_BODY)
        .fontFamily('monospace')
        .fontColor(Color.White)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%')
    .height('100%')
    .padding(20)
    .backgroundColor(HUD_OVERLAY)
  }

  @Builder
  private CloudDriveGuideOverlay() {
    Column({ space: 14 }) {
      Row() {
        Column({ space: 3 }) {
          Text(this.tr('链接网盘'))
            .fontSize(TS_DISPLAY)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.ink'))
          Text(this.tr('账号和密码始终由网盘客户端管理。'))
            .fontSize(TS_BODY)
            .fontColor($r('app.color.muted'))
        }
        .alignItems(HorizontalAlign.Start)
        Blank()
        Button(this.tr('关闭'), { type: ButtonType.Normal })
          .height(44)
          .fontColor($r('app.color.ink'))
          .backgroundColor($r('app.color.paper_2'))
          .borderRadius(6)
          .onClick((): void => {
            this.cloudGuideVisible = false;
          })
      }
      .width('100%')
      Text(this.tr('先安装并登录对应客户端，把照片或视频下载到设备，再通过系统文件选择器加入 帧澈 ZENCHE。'))
        .fontSize(13)
        .fontColor($r('app.color.muted'))
        .width('100%')
      List({ space: 8 }) {
        ForEach(
          DOMESTIC_CLOUDS,
          (provider: CloudProvider) => {
            ListItem() {
              Button({ type: ButtonType.Normal }) {
                Row({ space: 12 }) {
                  Text('☁')
                    .fontSize(TS_DISPLAY)
                    .fontColor($r('app.color.accent'))
                    .width(42)
                  Column({ space: 3 }) {
                    Text(this.tr(provider.name))
                      .fontSize(TS_EMPHASIS)
                      .fontWeight(FontWeight.Bold)
                      .fontColor($r('app.color.ink'))
                      .width('100%')
                    Text(this.tr(provider.note))
                      .fontSize(TS_BODY)
                      .fontColor($r('app.color.muted'))
                      .width('100%')
                  }
                  .alignItems(HorizontalAlign.Start)
                  .layoutWeight(1)
                  Text('↗')
                    .fontSize(TS_TITLE)
                    .fontColor($r('app.color.muted'))
                }
                .width('100%')
              }
              .width('100%')
              .height(70)
              .backgroundColor($r('app.color.surface'))
              .border({
                width: 1,
                color: $r('app.color.rule'),
                radius: 8
              })
              .onClick((): void => {
                this.openCloudProvider(provider.url);
              })
            }
          },
          (provider: CloudProvider): string => provider.name
        )
      }
      .width('100%')
      .layoutWeight(1)
      Text(this.tr('步骤：安装并登录 → 下载媒体 → 选择文件并加入。'))
        .fontSize(TS_BODY)
        .fontColor($r('app.color.muted'))
        .width('100%')
      Button(this.tr('选择文件并加入'), { type: ButtonType.Normal })
        .width('100%')
        .height(48)
        .fontColor($r('app.color.accent_ink'))
        .backgroundColor($r('app.color.accent'))
        .borderRadius(8)
        .onClick((): void => {
          this.cloudGuideVisible = false;
          this.openCloudDrive();
        })
    }
    .width(this.isCompact() ? '94%' : 620)
    .height(this.isCompact() ? '94%' : '88%')
    .padding(22)
    .backgroundColor($r('app.color.paper'))
    .border({
      width: 1,
      color: $r('app.color.rule_strong'),
      radius: 14
    })
    .shadow({
      radius: 24,
      color: HUD_BG_DIM,
      offsetX: 0,
      offsetY: 10
    })
  }

  @Builder
  private LibraryBranchCreatorOverlay() {
    Stack({ alignContent: Alignment.Center }) {
      Column({ space: 14 }) {
        Text(this.tr('新建分支'))
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.ink'))
          .width('100%')
        Text(this.tr(
          `将在“${this.branchParentName}”下创建可继续展开的节点。`
        ))
          .fontSize(13)
          .fontColor($r('app.color.muted'))
          .width('100%')
        TextInput({
          placeholder: this.tr('分支名称'),
          text: this.branchDraft
        })
          .height(44)
          .onChange((value: string): void => {
            this.branchDraft = value;
          })
        Row({ space: 8 }) {
          Button(this.tr('取消'), { type: ButtonType.Normal })
            .height(44)
            .layoutWeight(1)
            .fontColor($r('app.color.ink'))
            .backgroundColor($r('app.color.paper_2'))
            .onClick((): void => {
              this.branchCreatorVisible = false;
            })
          Button(this.tr('创建'), { type: ButtonType.Normal })
            .height(44)
            .layoutWeight(1)
            .enabled(this.branchDraft.trim().length > 0)
            .fontColor($r('app.color.accent_ink'))
            .backgroundColor($r('app.color.accent'))
            .onClick((): void => {
              this.createLibraryBranch();
            })
        }
        .width('100%')
      }
      .width(this.isCompact() ? '90%' : 460)
      .padding(22)
      .backgroundColor($r('app.color.paper'))
      .border({
        width: 1,
        color: $r('app.color.rule_strong'),
        radius: 14
      })
      .shadow({
        radius: 24,
        color: HUD_BG_DIM,
        offsetX: 0,
        offsetY: 10
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(HUD_BG_MID)
  }

  @Builder
  private LibraryBranchDeleteOverlay() {
    Stack({ alignContent: Alignment.Center }) {
      Column({ space: 14 }) {
        Text(this.tr('删除分支？'))
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.ink'))
          .width('100%')
        Text(this.tr(
          `将同时删除“${this.branchDeleteName}”下的子分支；其中的文件会回到“未分类”，原文件不受影响。`
        ))
          .fontSize(13)
          .fontColor($r('app.color.muted'))
          .width('100%')
        Row({ space: 8 }) {
          Button(this.tr('取消'), { type: ButtonType.Normal })
            .height(44)
            .layoutWeight(1)
            .fontColor($r('app.color.ink'))
            .backgroundColor($r('app.color.paper_2'))
            .onClick((): void => {
              this.branchDeleteVisible = false;
            })
          Button(this.tr('删除分支'), { type: ButtonType.Normal })
            .height(44)
            .layoutWeight(1)
            .fontColor(Color.White)
            .backgroundColor($r('app.color.error'))
            .onClick((): void => {
              this.deleteLibraryBranch();
            })
        }
        .width('100%')
      }
      .width(this.isCompact() ? '90%' : 460)
      .padding(22)
      .backgroundColor($r('app.color.paper'))
      .border({
        width: 1,
        color: $r('app.color.rule_strong'),
        radius: 14
      })
      .shadow({
        radius: 24,
        color: HUD_BG_DIM,
        offsetX: 0,
        offsetY: 10
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(HUD_BG_MID)
  }

  @Builder
  private LaunchAnnouncementOverlay() {
    Stack({ alignContent: Alignment.Center }) {
      Column({ space: 16 }) {
        Row({ space: 10 }) {
          Column({ space: 3 }) {
            Row({ space: 10 }) {
              Text('✨')
                .fontSize(20)
              Text(this.tr('更新公告'))
                .fontSize(22)
                .fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.ink'))
            }
            Text(`${this.tr('当前版本')} ${CURRENT_VERSION}`)
              .fontSize(13)
              .fontFamily('monospace')
              .fontColor($r('app.color.muted'))
              .width('100%')
              .padding({ left: 30 })
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
          Button(this.tr('关闭公告'), { type: ButtonType.Normal })
            .height(44)
            .fontColor($r('app.color.accent_ink'))
            .backgroundColor($r('app.color.accent'))
            .borderRadius(8)
            .fontWeight(FontWeight.Medium)
            .padding({ left: 18, right: 18 })
            .onClick((): void => {
              this.closeLaunchAnnouncement();
            })
        }
        .width('100%')

        Scroll() {
          Column({ space: 14 }) {
            Column({ space: 8 }) {
              Text(this.tr('本次更新'))
                .fontSize(TS_TITLE)
                .fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.ink'))
                .width('100%')
              Text(this.tr(
                '• 全屏监看改为影像优先的专业 HUD：顶部遥测、焦点十字、工具轨、真实 RGB 示波器与静音音频基线、底部参数托盘。\n' +
                '• 参数与拍摄页重构为设备摘要、自适应参数卡和常驻拍摄操作区，连接、输出和文件库状态一屏可见。\n' +
                '• 编辑器改为媒体池、中央预览、工具检查器和分析示波器协作布局；所有调整继续非破坏保存为新副本。\n' +
                '• 统一五端深色工作台视觉：ZENCHE 蓝用于主操作，暖金只标示参数读数，红色只用于录制与危险操作。\n' +
                '• iOS / iPadOS、Android、HarmonyOS、macOS、Windows 五端同步更新；相机、AI 与传输能力保持兼容。'
              ))
                .fontSize(14)
                .lineHeight(23)
                .fontColor($r('app.color.ink'))
                .width('100%')
            }
            .width('100%')
            .padding(16)
            .alignItems(HorizontalAlign.Start)
            .backgroundColor($r('app.color.surface'))
            .border({
              width: 1,
              color: $r('app.color.rule'),
              radius: 12
            })

            Column({ space: 8 }) {
              Text(this.tr('谨防诈骗'))
                .fontSize(17)
                .fontWeight(FontWeight.Bold)
                .fontColor(WARN_DEEP)
                .width('100%')
              Text(this.tr(
                '帧澈 ZENCHE 是开源免费项目。任何声称“进群领取软件”' +
                '或要求付费购买软件的人都是骗子，请勿转账。'
              ))
                .fontSize(14)
                .fontWeight(FontWeight.Medium)
                .fontColor(WARN_DARK)
                .width('100%')
            }
            .width('100%')
            .padding(16)
            .alignItems(HorizontalAlign.Start)
            .backgroundColor(WARN_BG)
            .border({
              width: 1,
              color: WARN_BG_SOFT,
              radius: 12
            })

            Column({ space: 10 }) {
              Text(this.tr('爱发电赞助'))
                .fontSize(17)
                .fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.accent'))
                .width('100%')
              Text(this.tr(
                '如果本项目对你有帮助，欢迎自愿打赏；软件功能永久免费。'
              ))
                .fontSize(13)
                .fontColor($r('app.color.muted'))
                .width('100%')
              this.FastFeedbackCard()
              Image($r('app.media.afdian_donation'))
                .width('100%')
                .height(this.isCompact() ? 390 : 460)
                .objectFit(ImageFit.Contain)
                .borderRadius(10)
            }
            .width('100%')
            .padding(16)
            .alignItems(HorizontalAlign.Start)
            .backgroundColor($r('app.color.surface'))
            .border({
              width: 1,
              color: $r('app.color.rule'),
              radius: 12
            })
          }
          .width('100%')
        }
        .width('100%')
        .layoutWeight(1)
        .scrollBar(BarState.Auto)

        Row({ space: 10 }) {
          Checkbox({
            name: 'announcement-do-not-remind',
            group: 'launch-announcement'
          })
            .select(this.announcementDoNotRemind)
            .onChange((selected: boolean): void => {
              this.announcementDoNotRemind = selected;
            })
          Text(this.tr('不再提醒（软件更新后仍会显示）'))
            .fontSize(14)
            .fontColor($r('app.color.ink'))
            .layoutWeight(1)
        }
        .width('100%')
      }
      .width(this.isCompact() ? '94%' : 660)
      .height(this.isCompact() ? '94%' : '88%')
      .padding(22)
      .alignItems(HorizontalAlign.Start)
      .backgroundColor($r('app.color.paper'))
      .border({
        width: 1,
        color: $r('app.color.rule_strong'),
        radius: 14
      })
      .shadow({
        radius: 24,
        color: HUD_BG_DIM,
        offsetX: 0,
        offsetY: 10
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(HUD_BG_DARK)
  }

  @Builder
  private FastFeedbackCard() {
    Column({ space: 10 }) {
      Row({ space: 10 }) {
        Text('⚡')
          .fontSize(19)
        Column({ space: 4 }) {
          Text(this.tr('快速问题反馈'))
            .fontSize(TS_EMPHASIS)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.ink'))
            .width('100%')
          Text(this.tr(
            '公开问题可继续在 GitHub 免费提交；在爱发电赞助后，可获取快速问题反馈渠道。'
          ))
            .fontSize(TS_BODY)
            .lineHeight(19)
            .fontColor($r('app.color.muted'))
            .width('100%')
          Text(this.tr('官方 QQ 群：165315727'))
            .fontSize(13)
            .fontFamily('monospace')
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.accent'))
            .width('100%')
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      Button(this.tr('打开爱发电'), { type: ButtonType.Normal })
        .height(44)
        .width('100%')
        .fontColor($r('app.color.ink'))
        .backgroundColor($r('app.color.surface'))
        .borderRadius(8)
        .border({
          width: 1,
          color: $r('app.color.rule_strong')
        })
        .onClick((): void => {
          this.openAfdian();
        })
    }
    .width('100%')
    .padding(14)
    .alignItems(HorizontalAlign.Start)
    .backgroundColor($r('app.color.accent_soft'))
    .border({
      width: 1,
      color: PHOTO_SOFT_BORDER,
      radius: 12
    })
  }

  @Builder
  private DonationOverlay() {
    Stack({ alignContent: Alignment.Center }) {
      Column({ space: 16 }) {
        Row() {
          Row({ space: 10 }) {
            Text('☕')
              .fontSize(20)
            Text(this.tr('爱发电赞助'))
              .fontSize(22)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.ink'))
          }
          .layoutWeight(1)
          Button(this.tr('关闭'), { type: ButtonType.Normal })
            .height(44)
            .fontColor($r('app.color.ink'))
            .backgroundColor($r('app.color.paper_2'))
            .borderRadius(8)
            .padding({ left: 16, right: 16 })
            .onClick((): void => {
              this.donationVisible = false;
            })
        }
        .width('100%')
        Text(this.tr('扫描二维码，或打开爱发电主页支持项目。'))
          .fontSize(13)
          .fontColor($r('app.color.muted'))
          .width('100%')
        Text(this.tr(
          '软件功能永久免费，赞助为自愿行为。'
        ))
          .fontSize(TS_CAPTION)
          .fontColor($r('app.color.muted'))
          .width('100%')
          .margin({ top: -6 })
        this.FastFeedbackCard()
        Column() {
          Image($r('app.media.afdian_donation'))
            .width('100%')
            .layoutWeight(1)
            .objectFit(ImageFit.Contain)
            .borderRadius(12)
        }
        .width('100%')
        .layoutWeight(1)
        .padding(10)
        .backgroundColor($r('app.color.surface'))
        .border({
          width: 1,
          color: $r('app.color.rule'),
          radius: 12
        })
        Text(this.tr('赞助不会解锁软件功能，也不影响公开 Issue 的处理。'))
          .fontSize(TS_CAPTION)
          .fontColor($r('app.color.muted'))
          .width('100%')
      }
      .width(this.isCompact() ? '94%' : 520)
      .height(this.isCompact() ? '90%' : '84%')
      .padding(20)
      .alignItems(HorizontalAlign.Start)
      .backgroundColor($r('app.color.paper'))
      .border({
        width: 1,
        color: $r('app.color.rule_strong'),
        radius: 14
      })
      .shadow({
        radius: 24,
        color: HUD_BG_DIM,
        offsetX: 0,
        offsetY: 10
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(HUD_BG_DARK)
  }

  @Builder
  private ImmersivePreviewOverlay() {
    Stack({ alignContent: Alignment.Center }) {
      if (this.preview !== undefined) {
        Image(this.preview)
          .width('100%')
          .height('100%')
          .objectFit(ImageFit.Contain)
      } else {
        Column({ space: 8 }) {
          Text(this.tr('等待相机画面'))
            .fontSize(TS_DISPLAY)
            .fontWeight(FontWeight.Bold)
            .fontColor(Color.White)
          Text(this.tr('连接相机并开启实时取景后即可全屏监看。'))
            .fontSize(13)
            .fontColor(WHITE_DIM)
        }
      }
      Row()
        .width(82)
        .height(82)
        .border({
          width: 2,
          color: ACCENT_SOFT,
          radius: 4
        })
      Column() {
        Row({ space: 10 }) {
          Button(`⌄ ${this.tr('退出全屏')}`, { type: ButtonType.Normal })
            .height(44)
            .fontColor(Color.White)
            .backgroundColor(HUD_BG_SOFT)
            .borderRadius(10)
            .onClick((): void => {
              this.closeImmersivePreview();
            })
          Text(
            `${this.liveView ? '● LIVE' : '● NO SOURCE'} · ` +
            `${this.cameraName} · USB/PTP`
          )
            .fontSize(TS_CAPTION)
            .fontFamily('monospace')
            .fontColor(Color.White)
            .backgroundColor(HUD_BG_SOFT)
            .borderRadius(22)
            .padding({
              left: 14,
              right: 14,
              top: 10,
              bottom: 10
            })
          Blank()
        }
        .width('100%')
        Blank()
        Text(
          (this.connected || this.localCameraSelected)
            ? (this.immersiveMonitoring
                ? `${this.videoShutterAngle.toFixed(1)}°   ` +
                  `${this.videoFrameRate} fps   JPEG`
                : `${this.exposureMode.toUpperCase()}   JPEG   帧澈 ZENCHE`)
            : '—'
        )
          .fontSize(13)
          .fontFamily('monospace')
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.White)
          .backgroundColor(HUD_BG_SOFT)
          .borderRadius(22)
          .padding({
            left: 18,
            right: 18,
            top: 10,
            bottom: 10
          })
          .margin({
            bottom: this.isImmersiveLandscape() ? 0 : 118
          })
      }
      .width('100%')
      .height('100%')
      .padding(20)
      this.ImmersiveTelemetryHud()
      if (this.isImmersiveLandscape()) {
        this.ImmersiveScopeDock()
      }
      this.ImmersiveParameterTray()
      if (this.isImmersiveLandscape()) {
        Row() {
          this.ImmersiveToolRail()
          Blank()
          this.ImmersiveCaptureRail()
        }
        .width('100%')
        .padding({ left: 22, right: 22 })
      } else {
        this.ImmersivePortraitControls()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.Black)
  }

  @Builder
  private ImmersiveTelemetryHud() {
    Scroll() {
      Row() {
        this.ImmersiveTelemetryCell(
          'SOURCE',
          this.connected ? 'USB/PTP' : this.wifiConnected ? 'PTP-IP'
            : this.localCameraSelected ? 'SYSTEM' : 'OFFLINE'
        )
        this.ImmersiveTelemetryCell(
          'FORMAT',
          (this.connected || this.localCameraSelected)
            ? (this.immersiveMonitoring
                ? `${this.videoFrameRate}P · ${this.videoCodecLabel()}`
                : 'PHOTO · JPEG')
            : '—'
        )
        this.ImmersiveTelemetryCell(
          'SHUTTER',
          (this.connected || this.localCameraSelected) ? this.shutterDisplay() : '—'
        )
        this.ImmersiveTelemetryCell(
          'IRIS',
          (this.connected || this.localCameraSelected) ? `F${this.currentAperture.toFixed(1)}` : '—'
        )
        this.ImmersiveTelemetryCell(
          'ISO',
          (this.connected || this.localCameraSelected) ? `${this.currentIso}` : '—'
        )
        this.ImmersiveTelemetryCell(
          'EV',
          (this.connected || this.localCameraSelected)
            ? `${this.currentCompensation >= 0 ? '+' : ''}${this.currentCompensation.toFixed(1)}`
            : '—'
        )
        this.ImmersiveTelemetryCell(
          'STATE',
          this.videoRecording ? 'REC' : this.liveView ? 'LIVE' : 'STBY'
        )
      }
      .backgroundColor(UI_CARD)
    }
    .width('76%')
    .height(52)
    .scrollable(ScrollDirection.Horizontal)
    .scrollBar(BarState.Off)
    .align(Alignment.Top)
    .margin({ top: 76 })
    .backgroundColor(UI_CARD)
    .border({ width: 1, color: UI_SECONDARY, radius: 5 })
  }

  @Builder
  private ImmersiveTelemetryCell(label: string, value: string) {
    Column({ space: 2 }) {
      Text(label)
        .fontSize(8)
        .fontFamily('monospace')
        .fontWeight(FontWeight.Bold)
        .fontColor(UI_LABEL)
        .width('100%')
      Text(value)
        .fontSize(TS_BODY)
        .fontFamily('monospace')
        .fontWeight(FontWeight.Bold)
        .fontColor(Color.White)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
    }
    .width(104)
    .height(52)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Start)
    .padding({ left: 10, right: 10 })
    .border({ width: { right: 1 }, color: UI_SECONDARY })
  }

  @Builder
  private ImmersiveScopeDock() {
    Row({ space: 5 }) {
      Canvas(this.immersiveRgbScopeContext)
        .width(176)
        .height(76)
        .onReady((): void => { this.drawImmersiveRgbScope(); })
        .backgroundColor(STUDIO_CANVAS)
      Canvas(this.immersiveAudioScopeContext)
        .width(88)
        .height(76)
        .onReady((): void => { this.drawImmersiveAudioScope(); })
        .backgroundColor(STUDIO_CANVAS)
    }
    .width(276)
    .height(86)
    .padding(5)
    .align(Alignment.BottomStart)
    .margin({ left: 18, bottom: 170 })
    .backgroundColor(UI_BG)
    .border({ width: 1, color: UI_SECONDARY, radius: 5 })
  }

  @Builder
  private ImmersiveToolRail() {
    Column({ space: 12 }) {
      Text(
        (this.connected || this.localCameraSelected)
          ? (this.immersiveMonitoring
              ? `${this.videoFrameRate}P`
              : this.exposureMode.toUpperCase())
          : '—'
      )
        .fontSize(TS_TITLE)
        .fontWeight(FontWeight.Bold)
        .fontColor(Color.White)
        .width(64)
        .height(56)
        .textAlign(TextAlign.Center)
        .backgroundColor(HUD_BG)
        .borderRadius(10)
      Button(
        this.tr(this.liveView ? 'LIVE' : '开启取景'),
        { type: ButtonType.Normal }
      )
        .width(64)
        .height(52)
        .fontSize(TS_CAPTION)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.liveView ? Color.Black : Color.White)
        .backgroundColor(this.liveView ? UI_ACCENT : HUD_BG)
        .borderRadius(10)
        .onClick((): void => {
          this.toggleLiveView();
        })
      if (this.immersiveMonitoring) {
        Button(this.tr('峰值'), { type: ButtonType.Normal })
          .width(64)
          .height(48)
          .fontSize(TS_CAPTION)
          .fontColor(this.focusPeakingEnabled ? Color.Black : Color.White)
          .backgroundColor(this.focusPeakingEnabled ? UI_ACCENT : HUD_BG)
          .borderRadius(10)
          .onClick((): void => {
            this.focusPeakingEnabled = !this.focusPeakingEnabled;
          })
        Button(this.tr('假色'), { type: ButtonType.Normal })
          .width(64)
          .height(48)
          .fontSize(TS_CAPTION)
          .fontColor(this.falseColorEnabled ? Color.Black : Color.White)
          .backgroundColor(this.falseColorEnabled ? UI_ACCENT : HUD_BG)
          .borderRadius(10)
          .onClick((): void => {
            this.falseColorEnabled = !this.falseColorEnabled;
          })
      }
      Button('AF', { type: ButtonType.Normal })
        .width(64)
        .height(48)
        .fontSize(TS_CAPTION)
        .fontColor(Color.White)
        .backgroundColor(HUD_BG)
        .borderRadius(10)
        .enabled(this.connected && this.liveView && !this.busy)
        .onClick((): void => { this.triggerAutoFocusOn(); })
    }
  }

  @Builder
  private ImmersiveCaptureRail() {
    Column({ space: 10 }) {
      Text(this.tr(this.immersiveMonitoring ? '视频' : '照片'))
        .fontSize(17)
        .fontWeight(FontWeight.Bold)
        .fontColor(
          this.immersiveMonitoring
            ? UI_VIDEO
            : UI_ACCENT
        )
      this.ImmersiveCaptureButton()
      Text(this.immersiveMonitoring
        ? (this.videoRecording ? 'REC' : this.tr('待机'))
        : 'JPEG')
        .fontSize(TS_CAPTION)
        .fontFamily('monospace')
        .fontWeight(FontWeight.Bold)
        .fontColor(Color.White)
        .padding({ left: 14, right: 14, top: 8, bottom: 8 })
        .backgroundColor(HUD_BG)
        .borderRadius(10)
    }
  }

  @Builder
  private ImmersiveCaptureButton() {
    Button(
      this.immersiveMonitoring
        ? (this.videoRecording ? '■' : '●')
        : '●',
      { type: ButtonType.Normal }
    )
      .width(96)
      .height(96)
      .fontSize(this.videoRecording ? 26 : 34)
      .fontWeight(FontWeight.Bold)
      .fontColor(this.videoRecording ? Color.White : Color.Black)
      .backgroundColor(
        this.immersiveMonitoring
          ? UI_VIDEO
          : UI_ACCENT
      )
      .borderRadius(48)
      .enabled(
        (this.immersiveMonitoring
          ? this.connected
          : (this.connected || this.wifiConnected)) && !this.busy
      )
      .onClick((): void => {
        if (this.immersiveMonitoring) {
          this.toggleVideoRecording();
        } else {
          this.capturePhoto();
        }
      })
  }

  @Builder
  private ImmersivePortraitControls() {
    Column() {
      Blank()
      Row({ space: 18 }) {
        this.ImmersiveToolRail()
        this.ImmersiveCaptureButton()
        Column({ space: 6 }) {
          Text(this.tr(this.immersiveMonitoring ? '视频' : '照片'))
            .fontSize(TS_EMPHASIS)
            .fontWeight(FontWeight.Bold)
            .fontColor(
              this.immersiveMonitoring
                ? UI_VIDEO
                : UI_ACCENT
            )
          Text(this.immersiveMonitoring
            ? (this.videoRecording ? 'REC' : this.tr('待机'))
            : 'JPEG')
            .fontSize(TS_CAPTION)
            .fontFamily('monospace')
            .fontColor(Color.White)
            .padding({ left: 12, right: 12, top: 8, bottom: 8 })
            .backgroundColor(HUD_BG)
            .borderRadius(10)
        }
      }
      .padding({ left: 14, right: 14, bottom: 12 })
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  private ImmersiveParameterTray() {
    Column({ space: 6 }) {
      Row({ space: 8 }) {
        Button(
          this.tr(
            this.immersiveParametersExpanded ? '收起参数' : '展开参数'
          ),
          { type: ButtonType.Normal }
        )
          .height(44)
          .fontColor(Color.White)
          .backgroundColor(HUD_BG_SOFT)
          .borderRadius(10)
          .onClick((): void => {
            this.immersiveParametersExpanded =
              !this.immersiveParametersExpanded;
          })
        if (this.immersiveParametersExpanded) {
          Button(
            this.tr(
              this.immersiveMoreParametersExpanded
                ? '收起更多'
                : '更多参数'
            ),
            { type: ButtonType.Normal }
          )
            .height(44)
            .fontColor(Color.White)
            .backgroundColor(
              this.immersiveMoreParametersExpanded
                ? MORE_ACTIVE_BG
                : HUD_BG_SOFT
            )
            .borderRadius(10)
            .onClick((): void => {
              this.immersiveMoreParametersExpanded =
                !this.immersiveMoreParametersExpanded;
            })
        }
      }
      if (this.immersiveParametersExpanded) {
        Scroll() {
          Row({ space: 8 }) {
            this.ImmersiveParameterControl(
              this.immersiveMonitoring ? '快门角度' : '快门',
              (this.connected || this.localCameraSelected)
                ? (this.immersiveMonitoring
                    ? `${this.videoShutterAngle.toFixed(1)}°`
                    : this.shutterDisplay())
                : '—',
              this.immersiveMonitoring ? 'videoShutter' : 'photoShutter'
            )
            this.ImmersiveParameterControl(
              '光圈',
              (this.connected || this.localCameraSelected)
                ? `f/${this.currentAperture}`
                : '—',
              'aperture'
            )
            this.ImmersiveParameterControl(
              'ISO',
              (this.connected || this.localCameraSelected)
                ? `${this.currentIso}`
                : '—',
              'iso'
            )
            this.ImmersiveParameterControl(
              '曝光补偿',
              (this.connected || this.localCameraSelected)
                ? `${this.currentCompensation.toFixed(1)} EV`
                : '—',
              'exposureCompensation'
            )
          }
          .padding({ left: 12, right: 12 })
        }
        .scrollable(ScrollDirection.Horizontal)
        .scrollBar(BarState.Off)
        if (this.immersiveMoreParametersExpanded) {
          Scroll() {
            Row({ space: 8 }) {
              if (this.immersiveMonitoring) {
                this.ImmersiveParameterControl(
                  '视频帧率',
                  (this.connected || this.localCameraSelected)
                    ? `${this.videoFrameRate}p`
                    : '—',
                  'videoFrameRate'
                )
                Button(
                  this.videoShutterMode === 'angle' ? '快门角度' : '快门速度',
                  { type: ButtonType.Normal }
                )
                  .height(44)
                  .fontColor(Color.White)
                  .backgroundColor(UI_SECONDARY)
                  .borderRadius(10)
                  .onClick((): void => {
                    this.videoShutterMode =
                      this.videoShutterMode === 'angle' ? 'speed' : 'angle';
                    if (this.videoShutterMode === 'angle') {
                      this.applyVideoShutterAngle();
                    }
                  })
                this.ImmersiveParameterControl(
                  '拍摄模式',
                  (this.connected || this.localCameraSelected)
                    ? this.exposureMode.toUpperCase()
                    : '—',
                  'exposureMode'
                )
                this.ImmersiveParameterControl(
                  '视频录制规格',
                  (this.connected || this.localCameraSelected)
                    ? this.videoCodecLabel()
                    : '—',
                  'videoCodec'
                )
                this.ImmersiveParameterControl(
                  'Log',
                  (this.connected || this.localCameraSelected)
                    ? this.videoLogLabel()
                    : '—',
                  'videoLog'
                )
              } else {
                this.ImmersiveParameterControl(
                  '拍摄模式',
                  (this.connected || this.localCameraSelected)
                    ? this.exposureMode.toUpperCase()
                    : '—',
                  'exposureMode'
                )
              }
              this.ImmersiveParameterControl(
                '对焦模式',
                (this.connected || this.localCameraSelected)
                  ? (this.currentFocusMode === 'continuous' ? 'AF-C' : 'AF-S')
                  : '—',
                'focusMode'
              )
              this.ImmersiveParameterControl(
                '白平衡',
                (this.connected || this.localCameraSelected)
                  ? (this.currentWhiteBalance === 'continuous' ? '自动' : '保留')
                  : '—',
                'whiteBalanceMode'
              )
              this.ImmersiveParameterControl(
                '优化校准',
                (this.connected || this.localCameraSelected)
                  ? (this.currentPictureControl === 'neutral' ? '自然' : '标准')
                  : '—',
                'pictureControl'
              )
            }
            .padding({ left: 12, right: 12 })
          }
          .scrollable(ScrollDirection.Horizontal)
          .scrollBar(BarState.Off)
        }
      }
    }
    .width('100%')
    .align(Alignment.Bottom)
    .margin({
      bottom: this.isImmersiveLandscape() ? 74 : 188
    })
  }

  @Builder
  private ImmersiveParameterControl(
    label: string,
    value: string,
    parameter: string
  ) {
    Row({ space: 4 }) {
      Button('−', { type: ButtonType.Normal })
        .width(44)
        .height(44)
        .fontColor(Color.White)
        .backgroundColor(HUD_BG_MID)
        .enabled(
          this.connected &&
          this.camera.canAdjustParameter(this.cameraParameter(parameter))
        )
        .onClick((): void => {
          this.adjustImmersiveParameter(parameter, -1);
        })
      Column({ space: 1 }) {
        Text(this.tr(label))
          .fontSize(10)
          .fontColor(WHITE_DIM)
        Text(value)
          .fontSize(TS_BODY)
          .fontFamily('monospace')
          .fontWeight(FontWeight.Bold)
          .fontColor(
            this.connected &&
            this.camera.canAdjustParameter(this.cameraParameter(parameter))
              ? UI_ACCENT
              : Color.White
          )
      }
      .width(52)
      Button('+', { type: ButtonType.Normal })
        .width(44)
        .height(44)
        .fontColor(Color.White)
        .backgroundColor(HUD_BG_MID)
        .enabled(
          this.connected &&
          this.camera.canAdjustParameter(this.cameraParameter(parameter))
        )
        .onClick((): void => {
          this.adjustImmersiveParameter(parameter, 1);
        })
    }
    .height(48)
    .padding(2)
    .backgroundColor(UI_CARD)
    .border({
      width: 1,
      color: this.connected &&
        this.camera.canAdjustParameter(this.cameraParameter(parameter))
          ? UI_ACCENT
          : UI_SECONDARY,
      radius: 7
    })
  }

  @Builder
  private CaptureAssistSettingsCard() {
    Column({ space: 12 }) {
      Text(this.tr('拍摄辅助'))
        .fontSize(TS_TITLE)
        .fontWeight(FontWeight.Bold)
        .width('100%')
      Text(this.tr('蓝牙遥控与拍摄定位'))
        .fontSize(TS_BODY)
        .fontColor($r('app.color.muted'))
        .width('100%')
      Row() {
        Column({ space: 3 }) {
          Text(this.tr('蓝牙遥控拍摄'))
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.ink'))
          Text(this.tr(this.bluetoothRemoteStatus))
            .fontSize(TS_CAPTION)
            .fontColor(this.bluetoothRemoteConnected
              ? $r('app.color.positive')
              : $r('app.color.muted'))
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        Toggle({
          type: ToggleType.Switch,
          isOn: this.bluetoothRemoteEnabled
        })
          .onChange((enabled: boolean): void => {
            this.setBluetoothRemoteEnabled(enabled);
          })
      }
      .width('100%')
      Divider()
        .color($r('app.color.rule'))
      Row() {
        Column({ space: 3 }) {
          Text(this.tr('拍摄位置'))
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.ink'))
          Text(this.tr(this.locationTaggingStatus))
            .fontSize(TS_CAPTION)
            .fontColor($r('app.color.muted'))
          Text(this.tr('拍摄时写入同名 XMP GPS，不在后台持续定位。'))
            .fontSize(10)
            .fontColor($r('app.color.muted'))
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        Toggle({
          type: ToggleType.Switch,
          isOn: this.locationTaggingEnabled
        })
          .onChange((enabled: boolean): void => {
            this.setLocationTaggingEnabled(enabled);
          })
      }
      .width('100%')
    }
    .width('100%')
    .padding(20)
    .alignItems(HorizontalAlign.Start)
    .backgroundColor($r('app.color.surface'))
    .border({
      width: 1,
      color: $r('app.color.rule'),
      radius: 8
    })
  }

  @Builder
  private SettingsWorkspace() {
    Scroll() {
      Column({ space: 20 }) {
        Text(this.tr('设置'))
          .fontSize(TS_DISPLAY)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.ink'))
          .width('100%')
        Text(this.tr('通用、拍摄辅助、更新、诊断与支持。'))
          .fontSize(14)
          .fontColor($r('app.color.muted'))
          .width('100%')
        Column({ space: 12 }) {
          Text(this.tr('语言'))
            .fontSize(TS_TITLE)
            .fontWeight(FontWeight.Bold)
            .width('100%')
          Text(this.tr('语言更改会立即应用，并在下次启动时保留。'))
            .fontSize(TS_BODY)
            .fontColor($r('app.color.muted'))
            .width('100%')
          Select([
            { value: '简体中文' },
            { value: 'English' },
            { value: '日本語' }
          ])
            .selected(
              this.language === LANGUAGE_ENGLISH
                ? 1
                : this.language === LANGUAGE_JAPANESE
                  ? 2
                  : 0
            )
            .width('100%')
            .height(44)
            .backgroundColor($r('app.color.paper'))
            .border({
              width: 1,
              color: $r('app.color.rule_strong'),
              radius: 6
            })
            .onSelect((index: number): void => {
              const languages: Array<string> = [
                LANGUAGE_SIMPLIFIED_CHINESE,
                LANGUAGE_ENGLISH,
                LANGUAGE_JAPANESE
              ];
              this.changeLanguage(languages[index]);
            })
        }
        .width('100%')
        .padding(20)
        .alignItems(HorizontalAlign.Start)
        .backgroundColor($r('app.color.surface'))
        .border({
          width: 1,
          color: $r('app.color.rule'),
          radius: 8
        })
        this.CaptureAssistSettingsCard()
        Column({ space: 8 }) {
          Text(this.tr('索尼官方 SDK'))
            .fontSize(TS_TITLE)
            .fontWeight(FontWeight.Bold)
            .width('100%')
          Text(this.tr('官方桌面 SDK 不提供当前平台运行库'))
            .fontSize(13)
            .fontWeight(FontWeight.Bold)
            .width('100%')
          Text(this.tr(
            '索尼 Camera Remote SDK 2.02.00 只提供 macOS 与 Windows 运行库；当前平台继续使用原生 Camera Remote Command 连接后端。'
          ))
            .fontSize(TS_BODY)
            .fontColor($r('app.color.muted'))
            .width('100%')
        }
        .width('100%')
        .padding(20)
        .alignItems(HorizontalAlign.Start)
        .backgroundColor($r('app.color.surface'))
        .border({
          width: 1,
          color: $r('app.color.rule'),
          radius: 8
        })
        Column({ space: 8 }) {
          Text(this.tr('尼康官方 SDK'))
            .fontSize(TS_TITLE)
            .fontWeight(FontWeight.Bold)
            .width('100%')
          Text(this.tr('官方桌面 SDK 不提供当前平台运行库'))
            .fontSize(13)
            .fontWeight(FontWeight.Bold)
            .width('100%')
          Text(this.tr(
            '尼康只为 macOS 与 Windows 提供本次 SDK 运行库；当前平台继续使用原生相机连接后端。'
          ))
            .fontSize(TS_BODY)
            .fontColor($r('app.color.muted'))
            .width('100%')
        }
        .width('100%')
        .padding(20)
        .alignItems(HorizontalAlign.Start)
        .backgroundColor($r('app.color.surface'))
        .border({
          width: 1,
          color: $r('app.color.rule'),
          radius: 8
        })
        Column({ space: 12 }) {
          Text('AI 功能激活')
            .fontSize(TS_TITLE)
            .fontWeight(FontWeight.Bold)
            .width('100%')
          Text('AI 修图与生图需购买激活码解锁。每个激活码 100 次，绑定设备，服务器端计数。')
            .fontSize(TS_BODY)
            .fontColor($r('app.color.muted'))
            .width('100%')
          // v1.5.7 P1：恢复 4881042 删除的兑换码说明文案（审计 backlog 项）
          Text(this.tr('兑换码仅用于 AI 云服务次数，帧澈本体保持免费开源。'))
            .fontSize(TS_CAPTION)
            .fontColor($r('app.color.muted'))
            .width('100%')
          Text(this.tr('没有兑换码？在爱发电购买兑换码'))
            .fontSize(TS_BODY)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.ink'))
            .width('100%')
          if (this.getAiActivationCode().length > 0) {
            Text('状态：已激活 ✓')
              .fontSize(13)
              .fontWeight(FontWeight.Bold)
              .fontColor(Color.Green)
              .width('100%')
          }
          Button(this.tr('前往官网兑换密钥'), { type: ButtonType.Normal })
            .height(44)
            .width('100%')
            .fontColor($r('app.color.accent_ink'))
            .backgroundColor($r('app.color.accent'))
            .onClick((): void => {
              const context = getContext(this) as common.UIAbilityContext;
              try {
                context.startAbility({
                  action: 'ohos.want.action.viewData',
                  entities: ['entity.system.browsable'],
                  uri: ZENCHE_WEBSITE_URL
                });
              } catch (_) {
                this.aiActivationMsg = '无法打开浏览器';
              }
            })
          Text(this.tr(
            '复制设备 ID 后，前往 zenche.top 使用兑换码兑换绑定当前设备的激活密钥。'
          ))
            .fontSize(TS_CAPTION)
            .fontColor($r('app.color.muted'))
            .width('100%')
          Row() {
            Text('我的设备 ID')
              .fontSize(13)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.ink'))
              .layoutWeight(1)
            Button('复制', { type: ButtonType.Normal })
              .height(44)
              .fontSize(TS_BODY)
              .fontColor($r('app.color.accent_ink'))
              .backgroundColor($r('app.color.accent'))
              .borderRadius(8)
              .padding({ left: 14, right: 14 })
              .onClick((): void => {
                this.copyDeviceIdToClipboard();
              })
          }
          .width('100%')
          .alignItems(VerticalAlign.Center)
          Text(this.getDeviceId())
            .fontSize(TS_CAPTION)
            .fontFamily('monospace')
            .fontColor($r('app.color.muted'))
            .width('100%')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(this.tr('每个激活密钥绑定当前设备，请复制上面的设备 ID 并前往官网兑换。'))
            .fontSize(TS_CAPTION)
            .fontColor($r('app.color.muted'))
            .width('100%')
          TextInput({ placeholder: '输入激活码', text: this.aiActivationInput })
            .height(44)
            .width('100%')
            .onChange((value: string): void => {
              this.aiActivationInput = value;
            })
          Row({ space: 8 }) {
            Button('购买激活码', { type: ButtonType.Normal })
              .height(44)
              .layoutWeight(1)
              .fontColor($r('app.color.ink'))
              .backgroundColor($r('app.color.paper_2'))
              .onClick((): void => {
                // 打开爱发电购买页
                const context = getContext(this) as common.UIAbilityContext;
                try {
                  context.startAbility({
                    action: 'ohos.want.action.viewData',
                    entities: ['entity.system.browsable'],
                    uri: AFDIAN_URL
                  });
                } catch (_) {
                  this.aiActivationMsg = '无法打开浏览器';
                }
              })
            Button('激活', { type: ButtonType.Normal })
              .height(44)
              .layoutWeight(1)
              .fontColor($r('app.color.accent_ink'))
              .backgroundColor($r('app.color.accent'))
              .onClick((): void => {
                this.doAiActivate();
              })
          }
          .width('100%')
          Divider()
            .color($r('app.color.rule'))
          Text(this.tr('恢复设备码'))
            .fontSize(13)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.ink'))
            .width('100%')
          TextInput({
            placeholder: this.tr('旧设备 ID'),
            text: this.aiRebindOldDeviceId,
          })
            .height(44)
            .width('100%')
            .onChange((value: string): void => {
              this.aiRebindOldDeviceId = value;
            })
          TextInput({
            placeholder: this.tr('旧激活码'),
            text: this.aiRebindOldCode,
          })
            .height(44)
            .width('100%')
            .type(InputType.Password)
            .onChange((value: string): void => {
              this.aiRebindOldCode = value;
            })
          Text(this.tr('恢复成功后，AI 权益和剩余次数将迁移到当前设备；旧设备绑定会永久失效。'))
            .fontSize(10)
            .fontColor($r('app.color.muted'))
            .width('100%')
          Button(
            this.tr(this.aiRebindBusy ? '正在迁移…' : '恢复到当前设备'),
            { type: ButtonType.Normal }
          )
            .height(44)
            .width('100%')
            .fontColor($r('app.color.ink'))
            .backgroundColor($r('app.color.paper_2'))
            .enabled(!this.aiRebindBusy)
            .onClick((): void => {
              this.rebindAiActivation();
            })
          if (this.aiActivationMsg.length > 0) {
            Text(this.aiActivationMsg)
              .fontSize(TS_CAPTION)
              .fontColor($r('app.color.muted'))
              .width('100%')
          }
        }
        .width('100%')
        .padding(20)
        .alignItems(HorizontalAlign.Start)
        .backgroundColor($r('app.color.surface'))
        .border({
          width: 1,
          color: $r('app.color.rule'),
          radius: 8
        })
        Column({ space: 12 }) {
          Text(this.tr('软件更新'))
            .fontSize(TS_TITLE)
            .fontWeight(FontWeight.Bold)
            .width('100%')
          Text(this.tr(
            `当前版本 ${CURRENT_VERSION} · 优先通过 Mirror酱检查更新，无可用 CDN 下载地址时自动回退 GitHub Releases。`
          ))
            .fontSize(TS_BODY)
            .fontColor($r('app.color.muted'))
            .width('100%')
          Row() {
            Text(this.tr('启动时自动检查更新'))
              .fontSize(13)
              .fontColor($r('app.color.ink'))
              .layoutWeight(1)
            Toggle({
              type: ToggleType.Switch,
              isOn: this.automaticUpdates
            })
              .onChange((enabled: boolean): void => {
                this.automaticUpdates = enabled;
                this.persistAutomaticUpdates();
                if (enabled) {
                  this.checkForUpdates(true);
                }
              })
          }
          .width('100%')
          TextInput({
            placeholder: this.tr('Mirror酱 CDK（可选）'),
            text: this.mirrorChyanCdk
          })
            .type(InputType.Password)
            .height(44)
            .showPasswordIcon(true)
            .onChange((value: string): void => {
              this.mirrorChyanCdk = value;
            })
          Text(this.tr(
            'CDK 保存在应用私有设置中，不会写入诊断日志。'
          ))
            .fontSize(TS_CAPTION)
            .fontColor($r('app.color.muted'))
            .width('100%')
          Row({ space: 8 }) {
            Button(this.tr('保存 CDK'), { type: ButtonType.Normal })
              .height(44)
              .layoutWeight(1)
              .fontColor($r('app.color.ink'))
              .backgroundColor($r('app.color.paper_2'))
              .borderRadius(6)
              .onClick((): void => {
                this.saveMirrorChyanCdk();
              })
            Button(this.tr('打开 Mirror酱'), { type: ButtonType.Normal })
              .height(44)
              .layoutWeight(1)
              .fontColor($r('app.color.ink'))
              .backgroundColor($r('app.color.paper_2'))
              .borderRadius(6)
              .onClick((): void => {
                this.openMirrorChyan();
              })
          }
          .width('100%')
          Text(this.tr(this.updateStatus))
            .fontSize(13)
            .fontColor($r('app.color.muted'))
            .width('100%')
          Row({ space: 8 }) {
            Button(
              this.tr(this.updateChecking ? '正在检查…' : '检查更新'),
              { type: ButtonType.Normal }
            )
              .height(44)
              .layoutWeight(1)
              .fontColor($r('app.color.ink'))
              .backgroundColor($r('app.color.paper_2'))
              .borderRadius(6)
              .enabled(!this.updateChecking)
              .onClick((): void => {
                this.checkForUpdates(false);
              })
            if (this.availableVersion.length > 0) {
              Button(
                `${this.tr('获取')} ${this.availableVersion}`,
                { type: ButtonType.Normal }
              )
                .height(44)
                .layoutWeight(1)
                .fontColor($r('app.color.accent_ink'))
                .backgroundColor($r('app.color.accent'))
                .borderRadius(6)
                .onClick((): void => {
                  this.openUpdate();
                })
            }
          }
          .width('100%')
        }
        .width('100%')
        .padding(20)
        .alignItems(HorizontalAlign.Start)
        .backgroundColor($r('app.color.surface'))
        .border({
          width: 1,
          color: $r('app.color.rule'),
          radius: 8
        })
        Column({ space: 12 }) {
          Text(this.tr('诊断日志'))
            .fontSize(TS_TITLE)
            .fontWeight(FontWeight.Bold)
            .width('100%')
          Text(this.tr(
            this.diagnostics?.directoryPath ?? '日志目录暂不可用'
          ))
            .fontSize(TS_BODY)
            .fontFamily('monospace')
            .fontColor($r('app.color.muted'))
            .width('100%')
          Row({ space: 8 }) {
            Button(this.tr('查询最近日志'), { type: ButtonType.Normal })
              .height(44)
              .layoutWeight(1)
              .fontColor($r('app.color.ink'))
              .backgroundColor($r('app.color.paper_2'))
              .borderRadius(6)
              .onClick((): void => {
                this.recentLogs =
                  this.diagnostics?.recentText(6000) ?? '日志暂不可用。';
              })
            Button(this.tr('上传脱敏日志'), { type: ButtonType.Normal })
              .height(44)
              .layoutWeight(1)
              .fontColor($r('app.color.accent_ink'))
              .backgroundColor($r('app.color.accent'))
              .borderRadius(6)
              .onClick((): void => {
                this.reportIssue();
              })
          }
          .width('100%')
          this.FastFeedbackCard()
          Text(this.recentLogs)
            .fontSize(TS_CAPTION)
            .fontFamily('monospace')
            .fontColor($r('app.color.muted'))
            .maxLines(14)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
        }
        .width('100%')
        .padding(20)
        .alignItems(HorizontalAlign.Start)
        .backgroundColor($r('app.color.surface'))
        .border({
          width: 1,
          color: $r('app.color.rule'),
          radius: 8
        })
        Text(this.tr(
          '只有在你检查预填内容并于 GitHub 确认提交后，脱敏日志才会发送。'
        ))
          .fontSize(TS_BODY)
          .fontColor($r('app.color.muted'))
          .width('100%')
        Column({ space: 12 }) {
          Text(this.tr('喜欢 帧澈 ZENCHE？'))
            .fontSize(TS_TITLE)
            .fontWeight(FontWeight.Bold)
            .width('100%')
          Text(this.tr('请作者喝杯奶茶，支持后续维护与新机型适配；兑换码可在爱发电购买。'))
            .fontSize(14)
            .fontColor($r('app.color.muted'))
            .width('100%')
          Row({ space: 8 }) {
            Button(this.tr('请作者喝奶茶'), { type: ButtonType.Normal })
              .height(44)
              .layoutWeight(1)
              .fontColor($r('app.color.accent_ink'))
              .backgroundColor($r('app.color.accent'))
              .borderRadius(6)
              .onClick((): void => {
                this.openDonation();
              })
            Button(this.tr('在爱发电购买兑换码'), { type: ButtonType.Normal })
              .height(44)
              .layoutWeight(1)
              .fontColor($r('app.color.ink'))
              .backgroundColor($r('app.color.paper_2'))
              .borderRadius(6)
              .onClick((): void => {
                this.openAfdian();
              })
          }
          .width('100%')
        }
        .width('100%')
        .padding(20)
        .alignItems(HorizontalAlign.Start)
        .backgroundColor($r('app.color.surface'))
        .border({
          width: 1,
          color: $r('app.color.rule'),
          radius: 8
        })
      }
      .width('100%')
      .padding(16)
    }
    .width('100%')
    .height(this.isCompact() ? 'auto' : '100%')
  }

  @Builder
  private ParameterPanel() {
    Scroll() {
      Column({ space: 8 }) {
        Text(this.tr('拍摄控制'))
          .fontSize(TS_TITLE)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.ink'))
          .width('100%')
          .margin({ bottom: 8 })
        if (this.section === 'monitor') {
          Text(this.tr('视频曝光三要素'))
            .fontSize(13)
            .fontColor($r('app.color.muted'))
            .width('100%')
            .margin({ bottom: 4 })
          this.ParameterSelect(
            '视频曝光模式',
            EXPOSURE_MODES.slice(0, 4),
            3,
            true,
            'exposureMode'
          )
          this.VideoFrameRateSelect()
          this.VideoShutterModeSelect()
          this.VideoShutterAngleSelect()
          this.ParameterSelect(
            '视频录制规格',
            this.videoCodecEntries(),
            this.videoCodecIndex(),
            this.camera.canAdjustParameter('videoCodec'),
            'videoCodec'
          )
          this.VideoLogSelect()
          this.ParameterSelect(
            '光圈',
            APERTURES,
            10,
            this.exposureMode === 'manual' ||
              this.exposureMode === 'aperturePriority',
            'aperture'
          )
          this.ParameterSelect('ISO 感光度', ISO_VALUES, 8, true, 'iso')
          this.ParameterSelect(
            '白平衡',
            WHITE_BALANCES,
            0,
            true,
            'whiteBalanceMode'
          )
          this.ProfessionalMonitorPanel()
        } else {
          Text(this.tr('曝光'))
            .fontSize(13)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.muted'))
            .width('100%')
            .margin({ top: 4 })
          this.ParameterSelect(
            '拍摄模式',
            EXPOSURE_MODES,
            3,
            true,
            'exposureMode'
          )
          this.ParameterSelect(
            '快门速度',
            SHUTTER_SPEEDS,
            18,
            this.exposureMode === 'manual' ||
              this.exposureMode === 'shutterPriority',
            'exposureTime'
          )
          this.ParameterSelect(
            '光圈',
            APERTURES,
            10,
            this.exposureMode === 'manual' ||
              this.exposureMode === 'aperturePriority' ||
              this.exposureMode === 'bulb',
            'aperture'
          )
          this.ParameterSelect('ISO 感光度', ISO_VALUES, 8, true, 'iso')
          this.ParameterSelect(
            '曝光补偿',
            EXPOSURE_COMPENSATIONS,
            6,
            this.exposureMode === 'program' ||
              this.exposureMode === 'aperturePriority' ||
              this.exposureMode === 'shutterPriority',
            'exposureCompensation'
          )
          Divider()
            .color($r('app.color.rule'))
            .margin({ top: 8, bottom: 4 })
          Text(this.tr('对焦与色彩'))
            .fontSize(13)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.muted'))
            .width('100%')
          this.ParameterSelect(
            '对焦模式',
            FOCUS_MODES,
            0,
            true,
            'focusMode'
          )
          this.ParameterSelect(
            '白平衡',
            WHITE_BALANCES,
            0,
            true,
            'whiteBalanceMode'
          )
          this.ParameterSelect(
            '优化校准',
            PICTURE_CONTROLS,
            1,
            true,
            'pictureControl'
          )
        }
      }
      .width('100%')
      .padding(20)
    }
    .width('100%')
    .height(this.isCompact() ? 'auto' : '100%')
    .backgroundColor($r('app.color.paper_2'))
    .border({
      width: { left: 1 },
      color: $r('app.color.rule')
    })
  }

  @Builder
  private ProfessionalMonitorPanel() {
    Text(this.tr('专业监看'))
      .fontSize(13)
      .fontWeight(FontWeight.Bold)
      .fontColor($r('app.color.ink'))
      .width('100%')
      .margin({ top: 8 })
    Row() {
      Column({ space: 2 }) {
        Text(this.tr('外录到当前智能设备'))
          .fontSize(13)
        Text(this.tr('生成无声 Motion‑JPEG AVI，可与机身录制并行'))
          .fontSize(10)
          .fontColor($r('app.color.muted'))
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      Toggle({
        type: ToggleType.Switch,
        isOn: this.externalRecordToDevice
      })
        .enabled(!this.videoRecording)
        .onChange((enabled: boolean): void => {
          this.setExternalRecordToDevice(enabled);
        })
    }
    .width('100%')
    Row() {
      Text(this.tr('峰值对焦'))
        .fontSize(13)
        .layoutWeight(1)
      Toggle({
        type: ToggleType.Switch,
        isOn: this.focusPeakingEnabled
      })
        .onChange((enabled: boolean): void => {
          this.focusPeakingEnabled = enabled;
        })
    }
    .width('100%')
    Row() {
      Text(this.tr('假色曝光'))
        .fontSize(13)
        .layoutWeight(1)
      Toggle({
        type: ToggleType.Switch,
        isOn: this.falseColorEnabled
      })
        .onChange((enabled: boolean): void => {
          this.falseColorEnabled = enabled;
        })
    }
    .width('100%')
    Column({ space: 4 }) {
      Canvas(this.professionalScopeContext)
        .width('100%')
        .height(190)
        .onReady((): void => {
          this.drawProfessionalScope();
        })
      Text(`${this.tr('峰值覆盖')} · ${this.peakingCoverage}%`)
        .fontSize(10)
        .fontFamily('monospace')
        .fontColor(WHITE_LO)
        .width('100%')
    }
    .width('100%')
    .padding(4)
    .backgroundColor(BLACK)
  }

  private scopeLevels(value: string): Array<number> {
    const bars: string = '▁▂▃▄▅▆▇█';
    const levels: Array<number> = [];
    for (let index: number = 0; index < value.length; index++) {
      const level: number = bars.indexOf(value.charAt(index));
      if (level >= 0) {
        levels.push(level / 7);
      }
    }
    return levels.length > 1 ? levels : [0.08, 0.08];
  }

  private drawScopeGrid(
    context: CanvasRenderingContext2D,
    x: number,
    y: number,
    width: number,
    height: number,
    parade: boolean
  ): void {
    context.strokeStyle = WHITE_FAINT;
    context.lineWidth = 0.72;
    for (let guide: number = 1; guide < 4; guide++) {
      const lineY: number = y + height * guide / 4;
      context.beginPath();
      context.moveTo(x, lineY);
      context.lineTo(x + width, lineY);
      context.stroke();
    }
    if (parade) {
      for (let guide: number = 1; guide < 3; guide++) {
        const lineX: number = x + width * guide / 3;
        context.beginPath();
        context.moveTo(lineX, y);
        context.lineTo(lineX, y + height);
        context.stroke();
      }
    }
    context.strokeStyle = WHITE_HI;
    context.lineWidth = 1.1;
    context.strokeRect(x + 0.5, y + 0.5, width - 1, height - 1);
  }

  private drawScopeTrace(
    context: CanvasRenderingContext2D,
    value: string,
    color: string,
    x: number,
    y: number,
    width: number,
    height: number,
    segment: number,
    seed: number
  ): void {
    const inset: number = Math.max(2, width * 0.009);
    const segmentWidth: number = segment >= 0 ? width / 3 : width;
    const startX: number = segment >= 0
      ? x + segmentWidth * segment + inset
      : x + inset;
    const plotWidth: number = Math.max(1, segmentWidth - inset * 2);
    const topInset: number = Math.max(3, height * 0.035);
    const bottom: number = y + height - Math.max(3, height * 0.035);
    const plotHeight: number = Math.max(1, bottom - y - topInset);
    const density: ScopeDensity | null = this.parseScopeDensity(value);
    if (density !== null) {
      this.drawScopeDensity(
        context, density, color, startX, y + topInset, plotWidth, plotHeight
      );
      return;
    }
    const levels: Array<number> = this.scopeLevels(value);
    const columns: number = Math.min(190, Math.max(48, Math.floor(plotWidth / 1.35)));

    context.fillStyle = color;
    context.beginPath();
    for (let column: number = 0; column < columns; column++) {
      const progress: number = column / Math.max(1, columns - 1);
      const sample: number = progress * (levels.length - 1);
      const lower: number = Math.min(levels.length - 1, Math.floor(sample));
      const upper: number = Math.min(levels.length - 1, lower + 1);
      const blend: number = sample - lower;
      const interpolated: number = levels[lower]
        + (levels[upper] - levels[lower]) * blend;
      const ripple: number = (this.scopeNoise(column, 0, seed) - 0.5) * 0.075;
      const level: number = Math.min(1, Math.max(0.04, interpolated + ripple));
      const pointX: number = startX + plotWidth * progress;
      const envelopeY: number = y + topInset
        + plotHeight * (1 - (0.12 + level * 0.82));
      const particles: number = 18 + Math.round(level * 28);
      for (let particle: number = 0; particle < particles; particle++) {
        const distribution: number = this.scopeNoise(column, particle + 1, seed * 7);
        const depth: number = Math.pow(
          distribution,
          particle % 3 === 0 ? 2.25 : 0.72
        );
        const jitterX: number =
          (this.scopeNoise(column, particle + 11, seed * 13) - 0.5) * 2.2;
        const jitterY: number =
          (this.scopeNoise(column, particle + 29, seed * 17) - 0.5) * 2.4;
        const pointY: number = Math.min(
          bottom,
          Math.max(y + topInset, envelopeY + (bottom - envelopeY) * depth + jitterY)
        );
        const bright: boolean = (column + particle + seed) % 5 === 0;
        context.globalAlpha = 0.07;
        context.fillRect(pointX + jitterX - 0.8, pointY - 0.8, 1.6, 1.6);
        context.globalAlpha = bright ? 0.64 : 0.30;
        const dot: number = bright ? 1.12 : 0.72;
        context.fillRect(pointX + jitterX - dot / 2, pointY - dot / 2, dot, dot);
      }
    }

    const trace = (): void => {
      context.beginPath();
      for (let column: number = 0; column < columns; column++) {
        const progress: number = column / Math.max(1, columns - 1);
        const sample: number = progress * (levels.length - 1);
        const lower: number = Math.min(levels.length - 1, Math.floor(sample));
        const upper: number = Math.min(levels.length - 1, lower + 1);
        const blend: number = sample - lower;
        const level: number = Math.min(
          1,
          Math.max(
            0.04,
            levels[lower] + (levels[upper] - levels[lower]) * blend
              + (this.scopeNoise(column, 0, seed) - 0.5) * 0.075
          )
        );
        const pointX: number = startX + plotWidth * progress;
        const pointY: number = y + topInset
          + plotHeight * (1 - (0.12 + level * 0.82));
        if (column === 0) context.moveTo(pointX, pointY);
        else context.lineTo(pointX, pointY);
      }
      context.stroke();
    };

    context.globalAlpha = 1;
    context.strokeStyle = color;
    context.lineJoin = 'round';
    context.lineCap = 'round';
    context.globalAlpha = 0.14;
    context.lineWidth = 3.2;
    trace();
    context.globalAlpha = 0.62;
    context.lineWidth = 0.72;
    trace();
    context.globalAlpha = 1;
  }

  private drawScopeDensity(
    context: CanvasRenderingContext2D,
    density: ScopeDensity,
    color: string,
    x: number,
    y: number,
    width: number,
    height: number
  ): void {
    const cellWidth: number = width / density.columns;
    const cellHeight: number = height / density.rows;
    const dot: number = Math.max(0.62, Math.min(1.5, cellWidth * 0.72));
    context.fillStyle = color;
    context.strokeStyle = color;
    context.beginPath();
    let hasEnvelope: boolean = false;
    for (let column: number = 0; column < density.columns; column++) {
      let firstRow: number = -1;
      for (let row: number = 0; row < density.rows; row++) {
        const level: number = density.values[row * density.columns + column];
        if (level <= 0) continue;
        if (firstRow < 0) firstRow = row;
        const pointX: number = x + (column + 0.5) * cellWidth;
        const pointY: number = y + (row + 0.5) * cellHeight;
        const intensity: number = level / 15;
        context.globalAlpha = 0.10;
        context.fillRect(pointX - dot, pointY - dot, dot * 2, dot * 2);
        if (level >= 3) {
          const core: number = dot * (0.46 + intensity * 0.38);
          context.globalAlpha = level >= 9 ? 0.78 : 0.35;
          context.fillRect(pointX - core, pointY - core, core * 2, core * 2);
        }
      }
      if (firstRow >= 0) {
        const pointX: number = x + (column + 0.5) * cellWidth;
        const pointY: number = y + (firstRow + 0.5) * cellHeight;
        if (!hasEnvelope) {
          context.moveTo(pointX, pointY);
          hasEnvelope = true;
        } else {
          context.lineTo(pointX, pointY);
        }
      }
    }
    context.globalAlpha = 0.22;
    context.lineWidth = 2.8;
    context.stroke();
    context.globalAlpha = 0.72;
    context.lineWidth = 0.68;
    context.stroke();
    context.globalAlpha = 1;
  }

  private parseScopeDensity(value: string): ScopeDensity | null {
    const colon: number = value.indexOf(':');
    if (!value.startsWith('S') || colon < 2) return null;
    const dimensions: Array<string> = value.substring(1, colon).split('x');
    if (dimensions.length !== 2) return null;
    const columns: number = Number.parseInt(dimensions[0]);
    const rows: number = Number.parseInt(dimensions[1]);
    const payload: string = value.substring(colon + 1);
    if (!Number.isFinite(columns) || !Number.isFinite(rows) ||
        payload.length !== columns * rows) return null;
    const values: Array<number> = [];
    for (let index: number = 0; index < payload.length; index++) {
      const level: number = Number.parseInt(payload.charAt(index), 16);
      if (!Number.isFinite(level)) return null;
      values.push(level);
    }
    return new ScopeDensity(columns, rows, values);
  }

  private scopeNoise(column: number, particle: number, seed: number): number {
    const value: number = Math.sin(
      ((column + 1) * 17 + (particle + 3) * 31 + seed * 47) * 12.9898
    ) * 43758.5453;
    return value - Math.floor(value);
  }

  private drawScopePanel(
    context: CanvasRenderingContext2D,
    x: number,
    y: number,
    width: number,
    height: number,
    label: string,
    values: Array<string>,
    colors: Array<string>,
    parade: boolean
  ): void {
    const footerHeight: number = Math.min(14, Math.max(10, height * 0.17));
    const plotHeight: number = Math.max(1, height - footerHeight);
    context.fillStyle = BLACK;
    context.fillRect(x, y, width, height);
    context.fillStyle = SCOPE_BG;
    context.fillRect(x, y, width, plotHeight);
    for (let index: number = 0; index < values.length; index++) {
      this.drawScopeTrace(
        context,
        values[index],
        colors[index],
        x,
        y,
        width,
        plotHeight,
        parade ? index : -1,
        index + 1
      );
    }
    this.drawScopeGrid(context, x, y, width, plotHeight, parade);
    context.globalAlpha = 1;
    context.fillStyle = WHITE_MID;
    context.font = `${Math.min(9, footerHeight * 0.68)}px monospace`;
    context.textAlign = 'center';
    const baseline: number = y + height - Math.max(1.5, footerHeight * 0.12);
    if (parade) {
      context.fillText('R', x + width / 6, baseline);
      context.fillText('G', x + width / 2, baseline);
      context.fillText('B', x + width * 5 / 6, baseline);
    } else {
      context.fillText(label, x + width / 2, baseline);
    }
    context.textAlign = 'left';
  }

  private drawMonitorRgbScope(): void {
    const context: CanvasRenderingContext2D = this.monitorRgbScopeContext;
    if (context.width <= 1 || context.height <= 1) return;
    context.clearRect(0, 0, context.width, context.height);
    this.drawScopePanel(
      context,
      0,
      0,
      context.width,
      context.height,
      '',
      [this.redHistogram, this.greenHistogram, this.blueHistogram],
      [SCOPE_R, SCOPE_G, SCOPE_B],
      false
    );
  }

  private drawAudioScope(): void {
    const context: CanvasRenderingContext2D = this.monitorAudioScopeContext;
    if (context.width <= 1 || context.height <= 1) return;
    context.clearRect(0, 0, context.width, context.height);
    this.drawScopePanel(
      context,
      0,
      0,
      context.width,
      context.height,
      'AUDIO',
      [],
      [],
      false
    );
    const footerHeight: number = Math.min(14, Math.max(10, context.height * 0.17));
    const plotHeight: number = context.height - footerHeight;
    context.strokeStyle = SCOPE_AUDIO;
    context.globalAlpha = 0.22;
    context.lineWidth = 5;
    context.beginPath();
    context.moveTo(4, plotHeight / 2);
    context.lineTo(context.width - 4, plotHeight / 2);
    context.stroke();
    context.globalAlpha = 0.92;
    context.lineWidth = 1;
    context.stroke();
    context.globalAlpha = 1;
  }

  private drawImmersiveRgbScope(): void {
    const context: CanvasRenderingContext2D = this.immersiveRgbScopeContext;
    if (context.width <= 1 || context.height <= 1) return;
    context.clearRect(0, 0, context.width, context.height);
    this.drawScopePanel(
      context,
      0,
      0,
      context.width,
      context.height,
      '',
      [this.redHistogram, this.greenHistogram, this.blueHistogram],
      [SCOPE_R, SCOPE_G, SCOPE_B],
      false
    );
  }

  private drawImmersiveAudioScope(): void {
    const context: CanvasRenderingContext2D = this.immersiveAudioScopeContext;
    if (context.width <= 1 || context.height <= 1) return;
    context.clearRect(0, 0, context.width, context.height);
    this.drawScopePanel(
      context,
      0,
      0,
      context.width,
      context.height,
      'AUDIO',
      [],
      [],
      false
    );
    const footerHeight: number = Math.min(14, Math.max(10, context.height * 0.17));
    const plotHeight: number = context.height - footerHeight;
    context.strokeStyle = SCOPE_AUDIO;
    context.globalAlpha = 0.86;
    context.lineWidth = 1;
    context.beginPath();
    context.moveTo(4, plotHeight / 2);
    context.lineTo(context.width - 4, plotHeight / 2);
    context.stroke();
    context.globalAlpha = 1;
  }

  private drawProfessionalScope(): void {
    const context: CanvasRenderingContext2D = this.professionalScopeContext;
    if (context.width <= 1 || context.height <= 1) return;
    context.clearRect(0, 0, context.width, context.height);
    this.drawScopePanel(
      context, 0, 0, context.width, context.height,
      'RGB', [this.redHistogram, this.greenHistogram, this.blueHistogram],
      [SCOPE_R, SCOPE_G, SCOPE_B], false
    );
  }

  @Builder
  private ParameterSelect(
    label: string,
    entries: Array<SelectEntry>,
    selectedIndex: number,
    modeEnabled: boolean,
    parameter: string
  ) {
    Text(this.tr(label))
      .fontSize(13)
      .fontColor($r('app.color.ink_2'))
      .width('100%')
    Select(
      entries.map((entry: SelectEntry): SelectOption => {
        return { value: this.tr(entry.label) };
      })
    )
      .selected(selectedIndex)
      .width('100%')
      .height(44)
      .fontColor($r('app.color.ink'))
      .selectedOptionBgColor($r('app.color.accent_soft'))
      .selectedOptionFontColor($r('app.color.accent'))
      .backgroundColor($r('app.color.paper'))
      .border({
        width: 1,
        color: $r('app.color.rule_strong'),
        radius: 12
      })
      .enabled(
        this.connected &&
        !this.busy &&
        modeEnabled &&
        this.camera.canAdjustParameter(parameter)
      )
      .margin({ bottom: 8 })
      .onSelect((index: number): void => {
        const entry: SelectEntry = entries[index];
        if (parameter === 'exposureTime') {
          this.currentShutterSpeed = Number(entry.value);
        } else if (parameter === 'aperture') {
          this.currentAperture = Number(entry.value);
        } else if (parameter === 'iso') {
          this.currentIso = Number(entry.value);
        }
        this.setCameraParameter(parameter, entry);
      })
  }

  @Builder
  private VideoFrameRateSelect() {
    Text(this.tr('视频帧率基准'))
      .fontSize(13)
      .fontColor($r('app.color.ink_2'))
      .width('100%')
    Select(
      VIDEO_FRAME_RATES.map((entry: SelectEntry): SelectOption => {
        return { value: entry.label };
      })
    )
      .selected(2)
      .width('100%')
      .height(44)
      .fontColor($r('app.color.ink'))
      .backgroundColor($r('app.color.paper'))
      .border({
        width: 1,
        color: $r('app.color.rule_strong'),
        radius: 6
      })
      .margin({ bottom: 8 })
      .onSelect((index: number): void => {
        this.videoFrameRate = Number(VIDEO_FRAME_RATES[index].value);
        this.applyVideoShutterAngle();
      })
  }

  @Builder
  private VideoShutterModeSelect() {
    Text(this.tr('视频快门表示'))
      .fontSize(13)
      .fontColor($r('app.color.ink_2'))
      .width('100%')
    Select([
      { value: this.tr('快门角度') },
      { value: this.tr('快门速度') }
    ])
      .selected(this.videoShutterMode === 'angle' ? 0 : 1)
      .width('100%')
      .height(44)
      .fontColor($r('app.color.ink'))
      .backgroundColor($r('app.color.paper'))
      .border({
        width: 1,
        color: $r('app.color.rule_strong'),
        radius: 6
      })
      .margin({ bottom: 8 })
      .onSelect((index: number): void => {
        this.videoShutterMode = index === 0 ? 'angle' : 'speed';
      })
  }

  @Builder
  private VideoShutterAngleSelect() {
    Text(
      `${this.tr(this.videoShutterMode === 'angle' ? '快门角度' : '快门速度')} · ${this.videoFrameRate}p`
    )
      .fontSize(13)
      .fontColor($r('app.color.ink_2'))
      .width('100%')
    Select(
      (this.videoShutterMode === 'angle' ? SHUTTER_ANGLES : SHUTTER_SPEEDS)
        .map((entry: SelectEntry): SelectOption => {
        return { value: entry.label };
      })
    )
      .selected(4)
      .width('100%')
      .height(44)
      .fontColor($r('app.color.ink'))
      .backgroundColor($r('app.color.paper'))
      .border({
        width: 1,
        color: $r('app.color.rule_strong'),
        radius: 6
      })
      .enabled(
        this.connected &&
        !this.busy &&
        this.camera.canAdjustParameter('videoExposureTime')
      )
      .margin({ bottom: 8 })
      .onSelect((index: number): void => {
        if (this.videoShutterMode === 'angle') {
          this.videoShutterAngle = Number(SHUTTER_ANGLES[index].value);
          this.applyVideoShutterAngle();
        } else {
          this.currentShutterSpeed = Number(SHUTTER_SPEEDS[index].value);
          this.setCameraParameter('videoExposureTime', SHUTTER_SPEEDS[index]);
        }
      })
  }

  @Builder
  private VideoLogSelect() {
    this.ParameterSelect(
      'Log / Picture Profile',
      this.videoLogEntries(),
      this.videoLogIndex(),
      true,
      'videoLog'
    )
  }

  private async toggleCameraConnection(): Promise<void> {
    if (this.busy) {
      return;
    }
    if (this.connected) {
      this.previewGeneration++;
      await this.runBusy('正在断开相机…', async (): Promise<void> => {
        await this.finishExternalRecordingForDisconnect();
        await this.camera.disconnect();
        this.connected = false;
        this.liveView = false;
        this.videoRecording = false;
        this.cameraName = '未连接';
        this.cameraVendor = 'Nikon';
        if (this.preview !== undefined) {
          this.preview.release();
          this.preview = undefined;
        }
        this.status = '相机已断开';
        this.lastConnectionError = '';
      });
      return;
    }

    await this.runBusy('正在连接相机…', async (): Promise<void> => {
      this.localCameraSelected = false;
      try {
        const profile: CameraProfile = await this.camera.connect();
        this.connected = true;
        this.cameraName = profile.name;
        this.cameraVendor = profile.vendorName;
        this.rememberConnectedDevice(profile);
        this.videoCodecIndex();
        this.videoLogIndex();
        this.status = `${profile.name} 已连接`;
        this.lastConnectionError = '';
      } catch (error) {
        this.lastConnectionError = (error as Error).message !== undefined
          ? (error as Error).message
          : this.tr('连接失败');
        throw (error as Error);
      }
    });
  }

  private async selectLocalCamera(): Promise<void> {
    if (this.busy) return;
    const granted: boolean = await this.requestFeaturePermissions([
      'ohos.permission.CAMERA'
    ]);
    if (!granted) {
      this.localCameraSelected = false;
      this.lastConnectionError = '未获得相机权限，无法使用本机摄像头';
      this.status = this.lastConnectionError;
      return;
    }
    if (this.connected) {
      this.previewGeneration++;
      await this.finishExternalRecordingForDisconnect();
      await this.camera.stopLiveView();
      await this.camera.disconnect();
      this.connected = false;
      this.liveView = false;
      this.videoRecording = false;
    }
    if (this.wifiConnected) {
      await this.disconnectWifiCamera();
    }
    this.localCameraSelected = true;
    this.cameraName = 'HarmonyOS 本机摄像头';
    this.cameraVendor = 'System';
    this.status = '本机摄像头已就绪 · 拍摄时打开系统取景器';
    this.lastConnectionError = '';
    this.connectionPanelVisible = false;
  }

  private async connectWifiCamera(): Promise<void> {
    if (this.wifiConnecting || this.busy) {
      return;
    }
    const port: number = Number(this.wifiPort);
    if (this.wifiHost.trim().length === 0 || !Number.isInteger(port) ||
      port < 1 || port > 65535) {
      this.wifiStatus = 'Wi‑Fi 相机地址或端口无效';
      return;
    }
    this.wifiConnecting = true;
    this.localCameraSelected = false;
    this.wifiStatus = '正在连接 Wi‑Fi 相机…';
    await this.persistWifiConnectionSettings();
    try {
      const name: string = await this.wifiCamera.connect(
        this.wifiHost.trim(),
        port
      );
      this.wifiCameraName = name;
      this.wifiConnected = true;
      this.wifiStatus = `${this.wifiConnectionMode.toUpperCase()} · ${name} 已通过 PTP/IP 连接`;
      this.status = this.wifiStatus;
      this.lastConnectionError = '';
    } catch (error) {
      this.wifiConnected = false;
      this.lastConnectionError = (error as Error).message !== undefined
        ? (error as Error).message
        : this.tr('连接失败');
      this.wifiStatus = `Wi‑Fi 连接失败：${(error as Error).message}`;
      this.status = this.wifiStatus;
    } finally {
      this.wifiConnecting = false;
    }
  }

  private async disconnectWifiCamera(): Promise<void> {
    await this.wifiCamera.disconnect();
    this.wifiConnected = false;
    this.wifiCameraName = 'PTP/IP Camera';
    this.wifiStatus = 'Wi‑Fi 相机未连接';
    this.status = 'Wi‑Fi 相机已断开';
    this.lastConnectionError = '';
  }

  private async persistWifiConnectionSettings(): Promise<void> {
    if (this.settingsPreferences === undefined) {
      return;
    }
    try {
      await this.settingsPreferences.put(
        'wifiCameraConnectionMode',
        this.wifiConnectionMode
      );
      await this.settingsPreferences.put('wifiCameraHost', this.wifiHost);
      await this.settingsPreferences.put('wifiCameraPort', this.wifiPort);
      await this.settingsPreferences.flush();
    } catch (error) {
      this.diagnostics?.warning(
        'wifi-camera',
        `无法保存 Wi‑Fi 连接设置：${(error as BusinessError).message}`
      );
    }
  }

  private async setBluetoothRemoteEnabled(enabled: boolean): Promise<void> {
    if (!enabled) {
      this.bluetoothRemoteEnabled = false;
      this.bluetoothRemote?.stop();
      return;
    }
    const granted: boolean = await this.requestFeaturePermissions([
      'ohos.permission.ACCESS_BLUETOOTH'
    ]);
    if (!granted) {
      this.bluetoothRemoteEnabled = false;
      this.bluetoothRemoteStatus = '未获得蓝牙访问权限';
      return;
    }
    this.bluetoothRemoteEnabled = true;
    this.bluetoothRemote?.start();
  }

  private async setLocationTaggingEnabled(enabled: boolean): Promise<void> {
    if (!enabled) {
      this.locationTaggingEnabled = false;
      this.locationTagging?.setEnabled(false);
      return;
    }
    const granted: boolean = await this.requestFeaturePermissions([
      'ohos.permission.APPROXIMATELY_LOCATION',
      'ohos.permission.LOCATION'
    ]);
    if (!granted) {
      this.locationTaggingEnabled = false;
      this.locationTaggingStatus = '未获得定位权限';
      return;
    }
    this.locationTaggingEnabled = true;
    this.locationTagging?.setEnabled(true);
  }

  private async requestFeaturePermissions(
    permissionsToRequest: Array<Permissions>
  ): Promise<boolean> {
    const context: common.UIAbilityContext =
      getContext(this) as common.UIAbilityContext;
    try {
      const result = await abilityAccessCtrl.createAtManager()
        .requestPermissionsFromUser(context, permissionsToRequest);
      return result.authResults.length === permissionsToRequest.length &&
        result.authResults.every((value: number): boolean => value === 0);
    } catch (error) {
      return false;
    }
  }

  private async reconnectRememberedDevice(): Promise<void> {
    if (this.busy) return;
    if (this.connected) {
      await this.toggleCameraConnection();
    }
    if (!this.connected) {
      await this.toggleCameraConnection();
    }
  }

  private rememberConnectedDevice(profile: CameraProfile): void {
    const id: string = `${profile.vendorId.toString(16).padStart(4, '0')}:` +
      `${profile.productId.toString(16).padStart(4, '0')}:${profile.name}`;
    const record: RememberedCameraDevice = new RememberedCameraDevice(
      id,
      profile.name,
      profile.vendorName,
      'USB/PTP',
      Date.now()
    );
    this.rememberedDevices = [record]
      .concat(this.rememberedDevices.filter(
        (item: RememberedCameraDevice): boolean => item.id !== id
      ))
      .slice(0, 12);
    this.persistRememberedDevices();
  }

  private forgetRememberedDevice(id: string): void {
    this.rememberedDevices = this.rememberedDevices.filter(
      (item: RememberedCameraDevice): boolean => item.id !== id
    );
    this.persistRememberedDevices();
  }

  private async persistRememberedDevices(): Promise<void> {
    if (this.settingsPreferences === undefined) return;
    try {
      await this.settingsPreferences.put(
        'rememberedCameraDevices.v1',
        JSON.stringify(this.rememberedDevices)
      );
      await this.settingsPreferences.flush();
    } catch (error) {
      this.diagnostics?.warning(
        'devices',
        `无法保存已连接设备：${(error as BusinessError).message}`
      );
    }
  }

  private formatDeviceTimestamp(timestamp: number): string {
    const value: Date = new Date(timestamp);
    const pad: (part: number) => string =
      (part: number): string => part.toString().padStart(2, '0');
    return `${value.getFullYear()}-${pad(value.getMonth() + 1)}-` +
      `${pad(value.getDate())} ${pad(value.getHours())}:` +
      `${pad(value.getMinutes())}`;
  }

  private isCompact(): boolean {
    return this.currentBreakpoint === 'xs' ||
      this.currentBreakpoint === 'sm' ||
      this.currentBreakpoint === 'md';
  }

  private isCameraSection(): boolean {
    return this.section === 'capture' || this.section === 'monitor';
  }

  private async toggleLiveView(): Promise<void> {
    if (!this.connected || this.busy) {
      return;
    }
    if (this.liveView) {
      this.previewGeneration++;
      await this.runBusy('正在停止实时取景…', async (): Promise<void> => {
        await this.finishExternalRecordingForDisconnect();
        await this.camera.stopLiveView();
        this.liveView = false;
        this.status = '实时取景已停止';
      });
      return;
    }
    await this.runBusy('正在开启实时取景…', async (): Promise<void> => {
      await this.camera.startLiveView();
      this.liveView = true;
      this.status = '实时取景已开启';
      this.startPreviewLoop();
    });
  }

  private async startPreviewLoop(): Promise<void> {
    const generation: number = ++this.previewGeneration;
    let failures: number = 0;
    while (
      generation === this.previewGeneration &&
      this.camera.isConnected &&
      this.camera.isLiveView
    ) {
      try {
        const jpeg: Uint8Array = await this.camera.getLiveViewFrame();
        failures = 0;
        if (this.externalVideoRecorder.isRecording) {
          try {
            this.externalVideoRecorder.appendJpeg(jpeg);
          } catch (recordingError) {
            await this.finishExternalRecordingAfterFailure(
              recordingError as Error
            );
          }
        }
        await this.displayJpeg(jpeg);
      } catch (error) {
        failures++;
        const message: string = (error as BusinessError).message;
        this.diagnostics?.warning(
          'liveview',
          `获取实时取景帧失败（${failures}/3）：${message}`
        );
        if (failures >= 3) {
          this.previewGeneration++;
          await this.finishExternalRecordingForDisconnect();
          await this.camera.stopLiveView();
          this.liveView = false;
          this.status = '实时取景已安全停止 · 机身控制已释放';
          this.showError('连续 3 次未收到画面，已停止重试并释放相机。');
          break;
        }
        this.status = `实时取景正在重试 · ${failures}/3`;
        await new Promise<void>((resolve: () => void) => {
          setTimeout(resolve, 600);
        });
      }
    }
  }

  private async capturePhoto(): Promise<void> {
    const library: PhotoLibrary | undefined = this.library;
    const workflow: CaptureWorkflow | undefined = this.captureWorkflow;
    if (this.localCameraSelected && !this.busy && workflow !== undefined) {
      await this.runBusy('正在打开本机摄像头…', async (): Promise<void> => {
        const granted: boolean = await this.requestFeaturePermissions([
          'ohos.permission.CAMERA'
        ]);
        if (!granted) {
          throw new Error('未获得相机权限，无法使用本机摄像头');
        }
        const context: common.UIAbilityContext =
          getContext(this) as common.UIAbilityContext;
        const jpeg: Uint8Array = await this.localCamera.capture(context);
        if (this.locationTaggingEnabled) {
          await this.locationTagging?.refresh();
        }
        const path: string = await workflow.store(
          jpeg,
          'local-camera.jpg',
          'HarmonyOS 本机摄像头',
          undefined,
          this.locationTagging?.snapshot()
        );
        await this.displayJpeg(jpeg);
        this.refreshPhotos();
        this.status = `本机拍摄已保存 · ${path.substring(path.lastIndexOf('/') + 1)}`;
      });
      return;
    }
    if (!this.connected && this.wifiConnected && !this.busy) {
      await this.runBusy('正在通过 Wi‑Fi 触发相机快门…', async (): Promise<void> => {
        await this.wifiCamera.capture();
        this.status = `${this.wifiCameraName} 已收到拍摄指令 · 原片保存在相机存储卡`;
      });
      return;
    }
    if (
      !this.connected ||
      this.busy ||
      library === undefined ||
      workflow === undefined
    ) {
      return;
    }
    await this.runBusy('正在拍摄并下载 JPEG…', async (): Promise<void> => {
      if (this.locationTaggingEnabled) {
        await this.locationTagging?.refresh();
      }
      const jpeg: Uint8Array = await this.camera.capture();
      const location: CaptureLocation | undefined =
        this.locationTagging?.snapshot();
      const path: string = await workflow.store(
        jpeg,
        'capture.jpg',
        this.cameraName,
        undefined,
        location
      );
      this.diagnostics?.info(
        'capture',
        `拍摄完成；文件=${path.substring(path.lastIndexOf('/') + 1)}` +
        `；大小=${jpeg.byteLength}`
      );
      await this.displayJpeg(jpeg);
      this.refreshPhotos();
      this.status = `已保存 ${path.substring(path.lastIndexOf('/') + 1)}`;
    });
  }

  private toggleCaptureSession(): void {
    const workflow: CaptureWorkflow | undefined = this.captureWorkflow;
    if (workflow === undefined) {
      return;
    }
    if (workflow.isActive) {
      workflow.end();
      this.status = workflow.status;
      return;
    }
    try {
      const configuration: CaptureSessionConfiguration =
        new CaptureSessionConfiguration();
      configuration.name = this.sessionName;
      configuration.namingTemplate = this.sessionNamingTemplate;
      configuration.creator = this.sessionCreator;
      configuration.rights = this.sessionRights;
      configuration.rating = this.sessionRating;
      configuration.dualBackupEnabled = this.sessionDualBackup;
      workflow.begin(configuration);
      this.status = workflow.status;
    } catch (error) {
      this.showError(
        `无法开始拍摄会话：${(error as Error).message}`
      );
    }
  }

  private async startShootingTask(): Promise<void> {
    const workflow: CaptureWorkflow | undefined = this.captureWorkflow;
    if (
      !this.connected ||
      this.busy ||
      this.shootingTaskRunning ||
      workflow === undefined
    ) {
      return;
    }
    const generation: number = ++this.shootingTaskGeneration;
    const kind: string = this.shootingTaskKind;
    const count: number = Math.max(
      1,
      Math.min(999, this.shootingTaskCount)
    );
    const interval: number = Math.max(
      1,
      Math.min(3600, this.shootingTaskInterval)
    );
    const step: number = Math.max(1, Math.min(3, this.shootingTaskStep));
    const originalCompensation: number = this.currentCompensation;
    const originalMode: string = this.exposureMode;
    this.shootingTaskRunning = true;
    this.shootingTaskStatus = `${taskLabel(kind)}准备中`;
    this.previewGeneration++;
    try {
      let total: number = kind === 'bulb' ? 1 : count;
      if (kind === 'exposure' && total % 2 === 0) {
        total++;
      }
      if (kind === 'focus' && !this.camera.isLiveView) {
        await this.camera.startLiveView();
        this.liveView = true;
      }
      if (kind === 'bulb') {
        await this.camera.setParameter('exposureMode', 'bulb');
        await this.camera.setParameter('bulbDuration', interval);
      }
      for (let index: number = 0; index < total; index++) {
        if (generation !== this.shootingTaskGeneration) {
          throw new Error('CANCELLED');
        }
        if (kind === 'exposure') {
          const center: number = Math.floor(total / 2);
          await this.camera.setParameter(
            'exposureCompensation',
            originalCompensation + (index - center) * step
          );
        }
        if (kind === 'focus' && index > 0) {
          await this.camera.moveFocus(step);
        }
        const jpeg: Uint8Array = await this.camera.capture();
        if (this.locationTaggingEnabled) {
          await this.locationTagging?.refresh();
        }
        const path: string = await workflow.store(
          jpeg,
          'capture.jpg',
          this.cameraName,
          undefined,
          this.locationTagging?.snapshot()
        );
        await this.displayJpeg(jpeg);
        this.refreshPhotos();
        this.shootingTaskStatus =
          `${taskLabel(kind)} · ${index + 1}/${total} · ` +
          path.substring(path.lastIndexOf('/') + 1);
        this.status = this.shootingTaskStatus;
        if (kind === 'interval' && index + 1 < total) {
          for (let tick: number = 0; tick < interval * 10; tick++) {
            if (generation !== this.shootingTaskGeneration) {
              throw new Error('CANCELLED');
            }
            await delay(100);
          }
        }
      }
      await this.restoreTaskCameraState(
        kind,
        originalCompensation,
        originalMode
      );
      this.shootingTaskStatus = `${taskLabel(kind)}已完成`;
      this.status = this.shootingTaskStatus;
    } catch (error) {
      await this.restoreTaskCameraState(
        kind,
        originalCompensation,
        originalMode
      );
      if ((error as Error).message === 'CANCELLED') {
        this.shootingTaskStatus = '拍摄任务已取消';
      } else {
        this.shootingTaskStatus = '拍摄任务失败';
        this.showError((error as Error).message);
      }
      this.status = this.shootingTaskStatus;
    } finally {
      this.shootingTaskRunning = false;
      if (this.liveView && this.camera.isLiveView) {
        this.startPreviewLoop();
      }
    }
  }

  private cancelShootingTask(): void {
    this.shootingTaskGeneration++;
    this.shootingTaskStatus = '正在取消拍摄任务…';
  }

  private async restoreTaskCameraState(
    kind: string,
    originalCompensation: number,
    originalMode: string
  ): Promise<void> {
    try {
      if (kind === 'exposure') {
        await this.camera.setParameter(
          'exposureCompensation',
          originalCompensation
        );
      }
      if (kind === 'bulb' && originalMode !== 'bulb') {
        await this.camera.setParameter('exposureMode', originalMode);
      }
    } catch (error) {
    }
  }

  private async toggleVideoRecording(): Promise<void> {
    if (!this.connected || this.busy) {
      return;
    }
    await this.runBusy(
      this.videoRecording ? '正在停止视频录制…' : '正在开始视频录制…',
      async (): Promise<void> => {
        if (this.videoRecording) {
          let bodyError: Error | undefined = undefined;
          if (this.camera.isMovieRecording) {
            try {
              await this.camera.stopMovieRecording();
            } catch (error) {
              bodyError = error as Error;
            }
          }
          const result: ExternalRecordingResult | undefined =
            this.externalVideoRecorder.stopIfRecording();
          if (result !== undefined) {
            await this.captureWorkflow?.completeExternalRecording(
              result.path
            );
            this.diagnostics?.info(
              'external-recording',
              `外录完成；文件=${filenameFromPath(result.path)}` +
              `；帧数=${result.frames}；大小=${result.bytes}`
            );
            this.refreshPhotos();
          }
          if (bodyError !== undefined && result === undefined) {
            throw bodyError;
          }
        } else {
          if (this.externalRecordToDevice && !this.liveView) {
            await this.camera.startLiveView();
            this.liveView = true;
            this.startPreviewLoop();
          }
          if (this.externalRecordToDevice) {
            const target: string | undefined =
              this.captureWorkflow?.reserveExternalRecording(
                this.cameraName,
                'avi'
              );
            if (target === undefined) {
              throw new Error('无法创建外录文件。');
            }
            this.externalVideoRecorder.start(target, this.videoFrameRate);
          }
          let bodyError: Error | undefined = undefined;
          try {
            await this.camera.startMovieRecording();
          } catch (error) {
            bodyError = error as Error;
          }
          if (
            bodyError !== undefined &&
            !this.externalVideoRecorder.isRecording
          ) {
            throw bodyError;
          }
        }
        this.videoRecording = this.camera.isMovieRecording ||
          this.externalVideoRecorder.isRecording;
        this.status = this.videoRecording
          ? this.externalVideoRecorder.isRecording
            ? '● EXT REC · 正在外录到当前智能设备'
            : '● REC · 视频正在录制到相机存储卡'
          : '录制已停止 · 外录文件已保存到 ZENCHE 文件库';
      }
    );
  }

  private async setExternalRecordToDevice(enabled: boolean): Promise<void> {
    if (this.videoRecording) return;
    this.externalRecordToDevice = enabled;
    this.status = enabled
      ? '外录已开启 · 视频将写入 ZENCHE 文件库'
      : '外录已关闭 · PTP 相机仅记录到机身存储卡';
    if (this.settingsPreferences !== undefined) {
      await this.settingsPreferences.put(
        'externalRecordToDevice',
        enabled
      );
      await this.settingsPreferences.flush();
    }
  }

  private async finishExternalRecordingAfterFailure(
    cause: Error
  ): Promise<void> {
    try {
      const result: ExternalRecordingResult | undefined =
        this.externalVideoRecorder.stopIfRecording();
      if (result !== undefined) {
        await this.captureWorkflow?.completeExternalRecording(result.path);
      }
    } catch (error) {
      this.externalVideoRecorder.abort();
    }
    this.videoRecording = this.camera.isMovieRecording;
    this.refreshPhotos();
    this.showError(`外录已停止：${cause.message}`);
  }

  private async finishExternalRecordingForDisconnect(): Promise<void> {
    try {
      const result: ExternalRecordingResult | undefined =
        this.externalVideoRecorder.stopIfRecording();
      if (result !== undefined) {
        await this.captureWorkflow?.completeExternalRecording(result.path);
        this.diagnostics?.info(
          'external-recording',
          `连接结束，已安全保存外录：${filenameFromPath(result.path)}`
        );
        this.refreshPhotos();
      }
    } catch (error) {
      this.externalVideoRecorder.abort();
      this.diagnostics?.error(
        'external-recording',
        `连接结束时无法完成外录：${(error as Error).message}`
      );
    }
    this.videoRecording = false;
  }

  private openImmersivePreview(monitoring: boolean): void {
    this.immersiveMonitoring = monitoring;
    this.immersiveLandscape = this.currentBreakpoint === 'lg';
    this.immersivePreviewVisible = true;
    this.startImmersiveOrientationTracking();
  }

  private startImmersiveOrientationTracking(): void {
    try {
      sensor.on(
        sensor.SensorId.ORIENTATION,
        this.immersiveOrientationListener,
        { interval: 200000000 }
      );
    } catch (error) {
      this.diagnostics?.warning(
        'immersive',
        `无法启用方向传感器，将使用窗口布局：${(error as Error).message}`
      );
    }
  }

  private stopImmersiveOrientationTracking(): void {
    try {
      sensor.off(
        sensor.SensorId.ORIENTATION,
        this.immersiveOrientationListener
      );
    } catch (error) {
    }
  }

  private isImmersiveLandscape(): boolean {
    return this.immersiveLandscape || this.currentBreakpoint === 'lg';
  }

  private closeImmersivePreview(): void {
    if (!this.immersivePreviewVisible) {
      return;
    }
    this.stopImmersiveOrientationTracking();
    this.immersivePreviewVisible = false;
    setTimeout((): void => {
      this.immersiveMonitoring = false;
    }, 0);
  }

  private shutterDisplay(): string {
    if (this.currentShutterSpeed < 1) {
      return `1/${Math.round(1 / this.currentShutterSpeed)}`;
    }
    return `${this.currentShutterSpeed.toFixed(1)}s`;
  }

  private videoCodecLabel(): string {
    const selected: SelectEntry | undefined = this.videoCodecEntries().find(
      (entry: SelectEntry): boolean => entry.value === this.videoCodec
    );
    return selected === undefined ? this.videoCodec : selected.label;
  }

  // v1.5.7 P2: 读数轨短标签（对齐 macOS MonitorReadout shortLabel 口径）。
  private videoCodecShortLabel(): string {
    switch (this.videoCodec) {
      case 'h264': return 'H.264';
      case 'h265': return 'H.265';
      case 'prores422hq': return 'ProRes 422 HQ';
      case 'proresRaw': return 'ProRes RAW';
      case 'nraw': return 'N-RAW';
      case 'sonyXavcHs8k': return 'XAVC HS 8K';
      case 'sonyXavcHs4k': return 'XAVC HS 4K';
      case 'sonyXavcS4k': return 'XAVC S 4K';
      case 'sonyXavcSHd': return 'XAVC S HD';
      case 'sonyXavcSi4k': return 'XAVC S-I 4K';
      case 'sonyXavcSiHd': return 'XAVC S-I HD';
      case 'canonRaw': return 'RAW';
      case 'canonXfHevc422':
      case 'canonXfHevc420': return 'XF-HEVC S';
      case 'canonXfAvc422':
      case 'canonXfAvc420': return 'XF-AVC S';
      default: return this.videoCodecLabel();
    }
  }

  private videoCodecEntries(): Array<SelectEntry> {
    if (this.cameraVendor === 'Sony') return SONY_VIDEO_CODECS;
    if (this.cameraVendor === 'Canon') return CANON_VIDEO_CODECS;
    return VIDEO_CODECS;
  }

  private videoLogEntries(): Array<SelectEntry> {
    if (this.cameraVendor === 'Sony') return SONY_VIDEO_LOGS;
    if (this.cameraVendor === 'Canon') return CANON_VIDEO_LOGS;
    return NIKON_VIDEO_LOGS;
  }

  private videoCodecIndex(): number {
    const entries: Array<SelectEntry> = this.videoCodecEntries();
    const index: number = entries.findIndex(
      (entry: SelectEntry): boolean => entry.value === this.videoCodec
    );
    if (index >= 0) return index;
    this.videoCodec = entries[0].value;
    return 0;
  }

  private videoLogIndex(): number {
    const entries: Array<SelectEntry> = this.videoLogEntries();
    const index: number = entries.findIndex(
      (entry: SelectEntry): boolean => entry.value === this.videoLogProfile
    );
    if (index >= 0) return index;
    this.videoLogProfile = 'off';
    this.nLogEnabled = false;
    return 0;
  }

  private videoLogLabel(): string {
    const selected: SelectEntry | undefined = this.videoLogEntries().find(
      (entry: SelectEntry): boolean => entry.value === this.videoLogProfile
    );
    return selected === undefined ? this.videoLogProfile : selected.label;
  }

  private exposureModeCode(): string {
    switch (this.exposureMode) {
      case 'program': return 'P';
      case 'shutterPriority': return 'S';
      case 'aperturePriority': return 'A';
      case 'bulb': return 'B';
      default: return 'M';
    }
  }

  private adjustImmersiveParameter(
    parameter: string,
    direction: number
  ): void {
    if (!this.connected || this.busy) {
      return;
    }
    if ([
      'videoFrameRate',
      'videoCodec',
      'videoLog',
      'exposureMode',
      'focusMode',
      'whiteBalanceMode',
      'pictureControl'
    ].includes(parameter)) {
      this.adjustImmersiveChoice(parameter, direction);
      return;
    }
    let entries: Array<SelectEntry>;
    let current: number;
    if (parameter === 'videoShutter') {
      entries = SHUTTER_ANGLES;
      current = this.videoShutterAngle;
    } else if (parameter === 'photoShutter') {
      entries = SHUTTER_SPEEDS;
      current = this.currentShutterSpeed;
    } else if (parameter === 'aperture') {
      entries = APERTURES;
      current = this.currentAperture;
    } else if (parameter === 'exposureCompensation') {
      entries = EXPOSURE_COMPENSATIONS;
      current = this.currentCompensation;
    } else {
      entries = ISO_VALUES;
      current = this.currentIso;
    }
    let nearest: number = 0;
    for (let index: number = 1; index < entries.length; index++) {
      if (
        Math.abs(Number(entries[index].value) - current) <
        Math.abs(Number(entries[nearest].value) - current)
      ) {
        nearest = index;
      }
    }
    const next: number = Math.max(
      0,
      Math.min(entries.length - 1, nearest + direction)
    );
    const entry: SelectEntry = entries[next];
    if (parameter === 'videoShutter') {
      this.videoShutterAngle = Number(entry.value);
      this.applyVideoShutterAngle();
    } else if (parameter === 'photoShutter') {
      this.currentShutterSpeed = Number(entry.value);
      this.setCameraParameter('exposureTime', entry);
    } else if (parameter === 'aperture') {
      this.currentAperture = Number(entry.value);
      this.setCameraParameter('aperture', entry);
    } else if (parameter === 'exposureCompensation') {
      this.currentCompensation = Number(entry.value);
      this.setCameraParameter('exposureCompensation', entry);
    } else {
      this.currentIso = Number(entry.value);
      this.setCameraParameter('iso', entry);
    }
  }

  private adjustImmersiveChoice(
    parameter: string,
    direction: number
  ): void {
    let entries: Array<SelectEntry>;
    let current: string;
    if (parameter === 'videoFrameRate') {
      entries = VIDEO_FRAME_RATES;
      current = this.videoFrameRate.toString();
    } else if (parameter === 'videoCodec') {
      entries = this.videoCodecEntries();
      current = this.videoCodec;
    } else if (parameter === 'videoLog') {
      entries = this.videoLogEntries();
      current = this.videoLogProfile;
    } else if (parameter === 'exposureMode') {
      entries = EXPOSURE_MODES;
      current = this.exposureMode;
    } else if (parameter === 'focusMode') {
      entries = FOCUS_MODES;
      current = this.currentFocusMode;
    } else if (parameter === 'whiteBalanceMode') {
      entries = WHITE_BALANCES;
      current = this.currentWhiteBalance;
    } else {
      entries = PICTURE_CONTROLS;
      current = this.currentPictureControl;
    }
    let index: number = entries.findIndex(
      (entry: SelectEntry): boolean => entry.value === current
    );
    if (index < 0) {
      index = 0;
    }
    const next: number = Math.max(
      0,
      Math.min(entries.length - 1, index + direction)
    );
    const entry: SelectEntry = entries[next];
    if (parameter === 'videoFrameRate') {
      this.videoFrameRate = Number(entry.value);
      this.applyVideoShutterAngle();
      return;
    }
    if (parameter === 'exposureMode') {
      this.exposureMode = entry.value;
    } else if (parameter === 'videoCodec') {
      this.videoCodec = entry.value;
    } else if (parameter === 'videoLog') {
      this.videoLogProfile = entry.value;
      this.nLogEnabled = entry.value !== 'off';
    } else if (parameter === 'focusMode') {
      this.currentFocusMode = entry.value;
    } else if (parameter === 'whiteBalanceMode') {
      this.currentWhiteBalance = entry.value;
    } else {
      this.currentPictureControl = entry.value;
    }
    this.setCameraParameter(parameter, entry);
  }

  private cameraParameter(parameter: string): string {
    if (
      parameter === 'videoShutter' ||
      parameter === 'photoShutter' ||
      parameter === 'videoFrameRate'
    ) {
      return parameter === 'videoShutter'
        || parameter === 'videoFrameRate'
        ? 'videoExposureTime'
        : 'exposureTime';
    }
    return parameter;
  }

  private async setCameraParameter(
    parameter: string,
    entry: SelectEntry
  ): Promise<void> {
    if (!this.connected || this.busy) {
      return;
    }
    const numeric: boolean = [
      'exposureTime',
      'videoExposureTime',
      'aperture',
      'iso',
      'exposureCompensation'
    ].includes(parameter);
    await this.runBusy(`正在设置 ${entry.label}…`, async (): Promise<void> => {
      await this.camera.setParameter(
        parameter,
        numeric ? Number(entry.value) : entry.value
      );
      if (parameter === 'exposureMode') {
        this.exposureMode = entry.value;
      } else if (parameter === 'videoCodec') {
        this.videoCodec = entry.value;
      } else if (parameter === 'videoLog') {
        this.videoLogProfile = entry.value;
        this.nLogEnabled = entry.value !== 'off';
      }
      this.status = `已设置 ${entry.label}`;
    });
  }

  private applyVideoShutterAngle(): void {
    const exposureSeconds: number =
      this.videoShutterAngle / (360 * this.videoFrameRate);
    this.setCameraParameter(
      'videoExposureTime',
      new SelectEntry(
        `快门角度 ${this.videoShutterAngle}°（${this.videoFrameRate}p）`,
        exposureSeconds.toString()
      )
    );
  }

  private beginCreatingLibraryBranch(
    parentId: string,
    parentName: string
  ): void {
    this.branchParentId = parentId;
    this.branchParentName = parentName;
    this.branchDraft = '';
    this.branchCreatorVisible = true;
  }

  private createLibraryBranch(): void {
    const name: string = this.branchDraft.trim();
    if (name.length === 0) {
      return;
    }
    const branch: LibraryBranch = new LibraryBranch(
      `${Date.now()}-${Math.floor(Math.random() * 100000)}`,
      name
    );
    if (this.branchParentId.length === 0) {
      this.userLibraryBranches = [
        ...this.userLibraryBranches,
        branch
      ];
    } else {
      const parent: LibraryBranch | undefined =
        this.findLibraryBranch(
          this.userLibraryBranches,
          this.branchParentId
        );
      if (parent === undefined) {
        return;
      }
      parent.children.push(branch);
      this.userLibraryBranches = [...this.userLibraryBranches];
      if (!this.isLibraryBranchExpanded(parent.id)) {
        this.expandedLibraryBranchIds = [
          ...this.expandedLibraryBranchIds,
          parent.id
        ];
      }
    }
    this.expandedLibraryBranchIds = [
      ...this.expandedLibraryBranchIds,
      branch.id
    ];
    this.branchCreatorVisible = false;
    this.persistLibraryBranches();
  }

  private beginDeletingLibraryBranch(branch: LibraryBranch): void {
    this.branchDeleteId = branch.id;
    this.branchDeleteName = branch.name;
    this.branchDeleteVisible = true;
  }

  private deleteLibraryBranch(): void {
    const branch: LibraryBranch | undefined = this.findLibraryBranch(
      this.userLibraryBranches,
      this.branchDeleteId
    );
    if (branch === undefined) {
      this.branchDeleteVisible = false;
      return;
    }
    const removedIds: Array<string> = [];
    branch.collectIds(removedIds);
    if (!this.removeLibraryBranch(
      this.userLibraryBranches,
      this.branchDeleteId
    )) {
      this.branchDeleteVisible = false;
      return;
    }
    this.userLibraryBranches = [...this.userLibraryBranches];
    this.expandedLibraryBranchIds =
      this.expandedLibraryBranchIds.filter(
        (id: string): boolean => !removedIds.includes(id)
      );
    this.libraryFileAssignments =
      this.libraryFileAssignments.filter(
        (assignment: LibraryFileAssignmentData): boolean =>
          !removedIds.includes(assignment.branchId)
      );
    this.branchDeleteVisible = false;
    this.branchDeleteId = '';
    this.branchDeleteName = '';
    this.status = '分支已删除，文件已回到未分类';
    this.persistLibraryBranches();
    this.persistLibraryFileAssignments();
  }

  private removeLibraryBranch(
    branches: Array<LibraryBranch>,
    id: string
  ): boolean {
    for (let index: number = 0; index < branches.length; index++) {
      if (branches[index].id === id) {
        branches.splice(index, 1);
        return true;
      }
      if (this.removeLibraryBranch(branches[index].children, id)) {
        return true;
      }
    }
    return false;
  }

  private findLibraryBranch(
    branches: Array<LibraryBranch>,
    id: string
  ): LibraryBranch | undefined {
    for (let index: number = 0; index < branches.length; index++) {
      if (branches[index].id === id) {
        return branches[index];
      }
      const child: LibraryBranch | undefined =
        this.findLibraryBranch(branches[index].children, id);
      if (child !== undefined) {
        return child;
      }
    }
    return undefined;
  }

  private isLibraryBranchExpanded(id: string): boolean {
    return this.expandedLibraryBranchIds.includes(id);
  }

  private toggleLibraryBranch(id: string): void {
    if (this.isLibraryBranchExpanded(id)) {
      this.expandedLibraryBranchIds =
        this.expandedLibraryBranchIds.filter(
          (candidate: string): boolean => candidate !== id
        );
    } else {
      this.expandedLibraryBranchIds = [
        ...this.expandedLibraryBranchIds,
        id
      ];
    }
  }

  private branchIdForPhoto(path: string): string {
    const assignment: LibraryFileAssignmentData | undefined =
      this.libraryFileAssignments.find(
        (candidate: LibraryFileAssignmentData): boolean =>
          candidate.path === path
      );
    return assignment?.branchId ?? '';
  }

  private photosForBranch(branchId: string): Array<PhotoItem> {
    return this.photos.filter(
      (item: PhotoItem): boolean =>
        this.branchIdForPhoto(item.path) === branchId
    );
  }

  private unclassifiedPhotos(): Array<PhotoItem> {
    return this.photos.filter(
      (item: PhotoItem): boolean =>
        this.branchIdForPhoto(item.path).length === 0
    );
  }

  private assignPhotoToBranch(path: string, branchId: string): void {
    if (path.length === 0) {
      return;
    }
    const remaining: Array<LibraryFileAssignmentData> =
      this.libraryFileAssignments.filter(
        (assignment: LibraryFileAssignmentData): boolean =>
          assignment.path !== path
      );
    this.libraryFileAssignments = branchId.length === 0
      ? remaining
      : [...remaining, { path: path, branchId: branchId }];
    if (
      branchId.length > 0 &&
      !this.isLibraryBranchExpanded(branchId)
    ) {
      this.expandedLibraryBranchIds = [
        ...this.expandedLibraryBranchIds,
        branchId
      ];
    }
    this.status = branchId.length === 0
      ? '已移到未分类'
      : '已移到分支';
    this.persistLibraryFileAssignments();
  }

  private async persistLibraryBranches(): Promise<void> {
    if (this.settingsPreferences === undefined) {
      return;
    }
    try {
      const data: Array<LibraryBranchData> =
        this.userLibraryBranches.map(
          (branch: LibraryBranch): LibraryBranchData => branch.toData()
        );
      await this.settingsPreferences.put(
        LIBRARY_BRANCHES_KEY,
        JSON.stringify(data)
      );
      await this.settingsPreferences.flush();
    } catch (error) {
      this.diagnostics?.warning(
        'library',
        `无法保存用户分支：${(error as BusinessError).message}`
      );
    }
  }

  private async persistLibraryFileAssignments(): Promise<void> {
    if (this.settingsPreferences === undefined) {
      return;
    }
    try {
      await this.settingsPreferences.put(
        LIBRARY_FILE_ASSIGNMENTS_KEY,
        JSON.stringify(this.libraryFileAssignments)
      );
      await this.settingsPreferences.flush();
    } catch (error) {
      this.diagnostics?.warning(
        'library',
        `无法保存文件分支归属：${(error as BusinessError).message}`
      );
    }
  }

  private async toggleWireless(): Promise<void> {
    if (this.wireless === undefined) {
      return;
    }
    try {
      if (this.wirelessRunning) {
        await this.wireless.stop();
        this.diagnostics?.info('wireless', '无线收件箱已停止');
        this.wirelessRunning = false;
        this.wirelessAddress = '—';
        this.status = '无线收件箱已停止';
      } else {
        await this.wireless.start();
        this.diagnostics?.info(
          'wireless',
          `无线收件箱已开启；FTP=${this.wireless.localAddress}:${FTP_PORT}` +
          `；HTTP/WebDAV=${this.wireless.localAddress}:${HTTP_PORT}`
        );
        this.wirelessRunning = true;
        this.wirelessAddress =
          `${this.wireless.localAddress}:${FTP_PORT}`;
        this.status = '无线收件箱已开启';
      }
    } catch (error) {
      this.showError(
        `无法切换无线收件箱：${(error as BusinessError).message}`
      );
    }
  }

  private async openOwnerAlbum(): Promise<void> {
    try {
      const options: photoAccessHelper.PhotoSelectOptions =
        new photoAccessHelper.PhotoSelectOptions();
      options.MIMEType =
        photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE;
      options.maxSelectNumber = 50;
      options.isOriginalSupported = true;
      const result: photoAccessHelper.PhotoSelectResult =
        await new photoAccessHelper.PhotoViewPicker().select(options);
      await this.importExternalPhotos(result.photoUris, '相册');
    } catch (error) {
      const businessError: BusinessError = error as BusinessError;
      if (businessError.code !== 13900012) {
        this.showError(`无法打开机主相册：${businessError.message}`);
      }
    }
  }

  private toggleCameraStorageSelection(handle: number, selected: boolean): void {
    const remaining: Array<number> = this.selectedCameraStorageHandles.filter(
      (value: number): boolean => value !== handle
    );
    this.selectedCameraStorageHandles = selected
      ? remaining.concat([handle])
      : remaining;
  }

  private async refreshCameraStorage(): Promise<void> {
    if (this.cameraStorageBusy) {
      return;
    }
    if (!this.connected && !this.wifiConnected) {
      this.cameraStorageStatus = '请先连接 USB/PTP 或 Wi‑Fi/PTP‑IP 相机';
      promptAction.showToast({ message: this.tr(this.cameraStorageStatus) });
      return;
    }
    this.cameraStorageBusy = true;
    this.cameraStorageStatus = '正在读取存储卡…';
    try {
      const snapshot: CameraStorageSnapshot = this.connected
        ? await this.camera.listStorage()
        : await this.wifiCamera.listStorage();
      this.cameraStorageSnapshot = snapshot;
      const valid: Array<number> = snapshot.items.map(
        (item: CameraStorageItem): number => item.handle
      );
      this.selectedCameraStorageHandles =
        this.selectedCameraStorageHandles.filter(
          (handle: number): boolean => valid.indexOf(handle) >= 0
        );
      this.cameraStorageStatus = '读取完成';
      this.diagnostics?.info(
        'camera-storage',
        `读取机内存储完成；文件=${snapshot.items.length}`
      );
    } catch (error) {
      const message: string = (error as Error).message;
      this.cameraStorageStatus = `读取失败 · ${message}`;
      this.diagnostics?.error('camera-storage', this.cameraStorageStatus);
      this.showError(message);
    } finally {
      this.cameraStorageBusy = false;
    }
  }

  private selectedCameraStorageItems(): Array<CameraStorageItem> {
    return this.cameraStorageSnapshot.items.filter(
      (item: CameraStorageItem): boolean =>
        this.selectedCameraStorageHandles.indexOf(item.handle) >= 0
    );
  }

  private async activeStorageObject(handle: number): Promise<Uint8Array> {
    return this.connected
      ? await this.camera.downloadStorageObject(handle)
      : await this.wifiCamera.downloadStorageObject(handle);
  }

  private async deleteActiveStorageObject(handle: number): Promise<void> {
    if (this.connected) {
      await this.camera.deleteStorageObject(handle);
    } else {
      await this.wifiCamera.deleteStorageObject(handle);
    }
  }

  private async downloadSelectedCameraStorage(): Promise<void> {
    const selected: Array<CameraStorageItem> = this.selectedCameraStorageItems();
    const library: PhotoLibrary | undefined = this.library;
    if (selected.length === 0 || library === undefined) {
      promptAction.showToast({ message: this.tr('请先选择要下载的机内文件。') });
      return;
    }
    this.cameraStorageBusy = true;
    try {
      for (let index: number = 0; index < selected.length; index++) {
        const item: CameraStorageItem = selected[index];
        this.cameraStorageStatus = `正在下载 ${index + 1} / ${selected.length}`;
        const bytes: Uint8Array = await this.activeStorageObject(item.handle);
        library.saveReceived(item.filename, bytes);
      }
      this.selectedCameraStorageHandles = [];
      this.cameraStorageStatus = `已下载 ${selected.length} 个文件到 ZENCHE 文件库`;
      this.refreshPhotos();
      promptAction.showToast({ message: this.tr(this.cameraStorageStatus) });
    } catch (error) {
      const message: string = (error as Error).message;
      this.cameraStorageStatus = `下载失败 · ${message}`;
      this.diagnostics?.error('camera-storage', this.cameraStorageStatus);
      this.showError(message);
    } finally {
      this.cameraStorageBusy = false;
    }
  }

  private async confirmDeleteSelectedCameraStorage(): Promise<void> {
    const selected: Array<CameraStorageItem> = this.selectedCameraStorageItems();
    if (selected.length === 0) {
      promptAction.showToast({ message: this.tr('请先选择要从相机删除的文件。') });
      return;
    }
    try {
      const result = await promptAction.showDialog({
        title: this.tr('从相机永久删除？'),
        message: this.tr(
          `将从相机存储卡永久删除所选 ${selected.length} 个文件；` +
          '此操作无法撤销。已保护文件不会被选择。'
        ),
        buttons: [
          { text: this.tr('取消'), color: MUTED_INK },
          { text: this.tr('永久删除'), color: UI_VIDEO }
        ]
      });
      if (result.index !== 1) {
        return;
      }
      this.cameraStorageBusy = true;
      this.cameraStorageStatus = '正在从相机删除…';
      for (const item of selected) {
        await this.deleteActiveStorageObject(item.handle);
      }
      this.selectedCameraStorageHandles = [];
      this.cameraStorageBusy = false;
      this.cameraStorageStatus = `已从相机删除 ${selected.length} 个文件`;
      await this.refreshCameraStorage();
    } catch (error) {
      this.cameraStorageBusy = false;
      const message: string = (error as Error).message;
      this.cameraStorageStatus = `删除失败 · ${message}`;
      this.diagnostics?.error('camera-storage', this.cameraStorageStatus);
      this.showError(message);
    }
  }

  private formatStorageSize(bytes: number): string {
    if (!Number.isFinite(bytes) || bytes < 0) {
      return '—';
    }
    const units: Array<string> = ['B', 'KB', 'MB', 'GB', 'TB'];
    let value: number = bytes;
    let index: number = 0;
    while (value >= 1024 && index < units.length - 1) {
      value /= 1024;
      index++;
    }
    return index === 0
      ? `${Math.round(value)} ${units[index]}`
      : `${value.toFixed(1)} ${units[index]}`;
  }

  private async loadSystemAlbum(): Promise<void> {
    const context: common.UIAbilityContext =
      getContext(this) as common.UIAbilityContext;
    try {
      const permissions: Array<Permissions> = [
        'ohos.permission.READ_IMAGEVIDEO'
      ];
      const result = await abilityAccessCtrl
        .createAtManager()
        .requestPermissionsFromUser(context, permissions);
      if (result.authResults.length === 0 || result.authResults[0] !== 0) {
        this.systemMedia = [];
        this.systemAlbumStatus = '未获得相册读取权限';
        return;
      }
      const predicates: dataSharePredicates.DataSharePredicates =
        new dataSharePredicates.DataSharePredicates();
      predicates
        .orderByDesc(photoAccessHelper.PhotoKeys.DATE_ADDED.toString())
        .limit(80, 0);
      const options: photoAccessHelper.FetchOptions = {
        fetchColumns: [
          photoAccessHelper.PhotoKeys.DISPLAY_NAME.toString(),
          photoAccessHelper.PhotoKeys.DATE_ADDED.toString(),
          photoAccessHelper.PhotoKeys.DURATION.toString()
        ],
        predicates: predicates
      };
      const helper: photoAccessHelper.PhotoAccessHelper =
        photoAccessHelper.getPhotoAccessHelper(context);
      const fetchResult:
        photoAccessHelper.FetchResult<photoAccessHelper.PhotoAsset> =
        await helper.getAssets(options);
      const assets: Array<photoAccessHelper.PhotoAsset> =
        await fetchResult.getAllObjects();
      fetchResult.close();
      this.systemMedia = assets.map(
        (asset: photoAccessHelper.PhotoAsset): SystemMediaItem => {
          const durationValue: photoAccessHelper.MemberType =
            asset.get(photoAccessHelper.PhotoKeys.DURATION.toString());
          return new SystemMediaItem(
            asset.uri,
            asset.displayName,
            asset.photoType === photoAccessHelper.PhotoType.VIDEO,
            Number(durationValue)
          );
        }
      );
      this.systemAlbumStatus = `最近 ${this.systemMedia.length} 项`;
    } catch (error) {
      this.systemMedia = [];
      this.systemAlbumStatus = '系统相册读取失败';
      this.diagnostics?.error(
        'library',
        `读取系统相册失败：${(error as BusinessError).message}`
      );
    }
  }

  private durationLabel(duration: number): string {
    let seconds: number = Math.max(0, Math.round(duration));
    if (seconds > 24 * 60 * 60) {
      seconds = Math.round(seconds / 1000);
    }
    const minutes: number = Math.floor(seconds / 60);
    const remainder: number = seconds % 60;
    return `${minutes}:${remainder < 10 ? '0' : ''}${remainder}`;
  }

  private async openSystemMedia(item: SystemMediaItem): Promise<void> {
    const context: common.UIAbilityContext =
      getContext(this) as common.UIAbilityContext;
    try {
      await context.startAbility({
        action: 'ohos.want.action.viewData',
        uri: item.uri,
        type: item.isVideo ? 'video/*' : 'image/*'
      });
    } catch (error) {
      this.showError(
        `无法打开系统相册文件：${(error as BusinessError).message}`
      );
    }
  }

  private async openCloudProvider(url: string): Promise<void> {
    const context: common.UIAbilityContext =
      getContext(this) as common.UIAbilityContext;
    try {
      await context.startAbility({
        action: 'ohos.want.action.viewData',
        uri: url
      });
    } catch (error) {
      this.showError(
        `无法打开网盘页面：${(error as BusinessError).message}`
      );
    }
  }

  private async openCloudDrive(): Promise<void> {
    const context: common.UIAbilityContext =
      getContext(this) as common.UIAbilityContext;
    try {
      const documentPicker: picker.DocumentViewPicker =
        new picker.DocumentViewPicker(context);
      const options: picker.DocumentSelectOptions =
        new picker.DocumentSelectOptions();
      options.maxSelectNumber = 50;
      options.fileSuffixFilters = [
        '照片与视频|jpg,jpeg,png,heic,heif,tif,tiff,nef,nrw,mp4,mov,m4v'
      ];
      const uris: Array<string> = await documentPicker.select(options);
      await this.importExternalPhotos(uris, '网盘');
    } catch (error) {
      const businessError: BusinessError = error as BusinessError;
      if (businessError.code !== 13900012) {
        this.showError(`无法打开网盘文件提供器：${businessError.message}`);
      }
    }
  }

  private async importExternalPhotos(
    uris: Array<string>,
    source: string
  ): Promise<void> {
    const library: PhotoLibrary | undefined = this.library;
    const workflow: CaptureWorkflow | undefined = this.captureWorkflow;
    if (
      library === undefined ||
      workflow === undefined ||
      uris.length === 0
    ) {
      return;
    }
    let imported: number = 0;
    const pairNames: Map<string, string> = new Map<string, string>();
    for (let index: number = 0; index < uris.length; index++) {
      const uri: string = uris[index];
      try {
        const name: string = this.externalPhotoName(uri, source, index);
        const dot: number = name.lastIndexOf('.');
        const pairKey: string =
          (dot > 0 ? name.substring(0, dot) : name).toLowerCase();
        let reservedBase: string | undefined = pairNames.get(pairKey);
        if (reservedBase === undefined) {
          reservedBase = workflow.reserveBaseName(source);
          pairNames.set(pairKey, reservedBase);
        }
        await workflow.importFromUri(
          uri,
          name,
          source,
          reservedBase
        );
        imported++;
      } catch (error) {
        this.diagnostics?.error(
          'library',
          `从${source}导入失败；URI=${uri}；错误=${(error as BusinessError).message}`
        );
      }
    }
    this.refreshPhotos();
    this.status = imported > 0
      ? `已从${source}加入 ${imported} 张照片`
      : `未能从${source}加入照片`;
    promptAction.showToast({ message: this.status });
  }

  private externalPhotoName(
    uri: string,
    source: string,
    index: number
  ): string {
    const withoutQuery: string = uri.split('?')[0];
    const slash: number = withoutQuery.lastIndexOf('/');
    const leaf: string = slash >= 0
      ? withoutQuery.substring(slash + 1)
      : withoutQuery;
    const lower: string = leaf.toLowerCase();
    const supported: boolean = [
      '.jpg', '.jpeg', '.png', '.heic', '.heif',
      '.tif', '.tiff', '.nef', '.nrw', '.mp4', '.mov', '.m4v'
    ].some((extension: string): boolean => lower.endsWith(extension));
    return supported && leaf.length > 0
      ? leaf.replace(/[<>:"|?*]/g, '_')
      : `${source}_${Date.now()}_${index + 1}.JPG`;
  }

  private refreshPhotos(): void {
    if (this.library !== undefined) {
      this.photos = this.library.list();
    }
  }

  private editablePhotos(): Array<PhotoItem> {
    return this.photos.filter((item: PhotoItem): boolean => {
      const lower: string = item.name.toLowerCase();
      return !item.isVideo &&
        !lower.endsWith('.nef') &&
        !lower.endsWith('.nrw');
    });
  }

  private unclassifiedEditablePhotos(): Array<PhotoItem> {
    return this.editablePhotos().filter(
      (item: PhotoItem): boolean => this.branchIdForPhoto(item.path).length === 0
    );
  }

  private editablePhotosForBranch(branchId: string): Array<PhotoItem> {
    return this.photosForBranch(branchId).filter(
      (item: PhotoItem): boolean => this.editablePhotos().some(
        (photo: PhotoItem): boolean => photo.path === item.path
      )
    );
  }

  private editorSelectedLabel(): string {
    const selected: PhotoItem | undefined = this.editablePhotos().find(
      (item: PhotoItem): boolean => item.path === this.editorSelectedPath
    );
    return selected === undefined ? this.tr('选择照片') : `▧  ${selected.name}`;
  }

  private ensureEditorSelection(): void {
    const photos: Array<PhotoItem> = this.editablePhotos();
    if (
      this.editorSelectedPath.length === 0 ||
      !photos.some((item: PhotoItem): boolean =>
        item.path === this.editorSelectedPath
      )
    ) {
      this.editorSelectedPath = photos.length > 0 ? photos[0].path : '';
    }
  }

  private editorSelectedIndex(): number {
    const index: number = this.editablePhotos().findIndex(
      (item: PhotoItem): boolean =>
        item.path === this.editorSelectedPath
    );
    return index < 0 ? 0 : index;
  }

  private editorPresetIndex(): number {
    const values: Array<string> = [
      'original',
      'natural',
      'portrait',
      'landscape',
      'monochrome'
    ];
    const index: number = values.indexOf(this.editorPreset);
    return index < 0 ? 0 : index;
  }

  private nikonCloudSelectEntries(): Array<SelectEntry> {
    const entries: Array<SelectEntry> = [
      new SelectEntry('关闭云创预览', '')
    ];
    NIKON_CLOUD_PRESETS.forEach((preset: NikonCloudPreset): void => {
      entries.push(new SelectEntry(preset.name, preset.id));
    });
    return entries;
  }

  private nikonCloudPresetIndex(): number {
    const index: number = NIKON_CLOUD_PRESETS.findIndex(
      (preset: NikonCloudPreset): boolean => {
        return preset.id === this.editorNikonCloudPresetId;
      }
    );
    return index < 0 ? 0 : index + 1;
  }

  private monitorNikonCloudPresetIndex(): number {
    const index: number = NIKON_CLOUD_PRESETS.findIndex(
      (preset: NikonCloudPreset): boolean => {
        return preset.id === this.monitorNikonCloudPresetId;
      }
    );
    return index < 0 ? 0 : index + 1;
  }

  private selectedMonitorNikonCloudPreset(): NikonCloudPreset | undefined {
    return NIKON_CLOUD_PRESETS.find(
      (preset: NikonCloudPreset): boolean => {
        return preset.id === this.monitorNikonCloudPresetId;
      }
    );
  }

  private selectedNikonCloudPreset(): NikonCloudPreset | undefined {
    return NIKON_CLOUD_PRESETS.find(
      (preset: NikonCloudPreset): boolean => {
        return preset.id === this.editorNikonCloudPresetId;
      }
    );
  }

  private editorCropRatioIndex(): number {
    const values: Array<string> = [
      'original', '1:1', '4:3', '3:2', '16:9'
    ];
    const index: number = values.indexOf(this.editorCropRatio);
    return index < 0 ? 0 : index;
  }

  private resetImageEditor(): void {
    this.editorPanel = 'light';
    this.editorPreset = 'original';
    this.editorNikonCloudPresetId = '';
    this.editorExposure = 0;
    this.editorContrast = 0;
    this.editorHighlights = 0;
    this.editorShadows = 0;
    this.editorWhites = 0;
    this.editorBlacks = 0;
    this.editorTemperature = 0;
    this.editorTint = 0;
    this.editorVibrance = 0;
    this.editorSaturation = 0;
    this.editorTexture = 0;
    this.editorClarity = 0;
    this.editorSharpening = 0;
    this.editorNoiseReduction = 0;
    this.editorDehaze = 0;
    this.editorVignette = 0;
    this.editorWheelLift = 0;
    this.editorWheelGamma = 0;
    this.editorWheelGain = 0;
    this.editorWheelLiftX = 0;
    this.editorWheelLiftY = 0;
    this.editorWheelGammaX = 0;
    this.editorWheelGammaY = 0;
    this.editorWheelGainX = 0;
    this.editorWheelGainY = 0;
    this.editorCurveContrast = 0;
    this.editorCurvePivot = 50;
    this.editorCurveShadows = 0;
    this.editorCurveMidtones = 0;
    this.editorCurveHighlights = 0;
    this.editorCurvePoints = EDITOR_CURVE_DEFAULTS.map((point: EditorCurvePoint): EditorCurvePoint => new EditorCurvePoint(point.x, point.y));
    this.editorActiveCurvePoint = -1;
    this.editorMaskEnabled = false;
    this.editorMaskType = '画笔';
    this.editorMaskAmount = 100;
    this.editorMaskFeather = 55;
    this.editorMaskInvert = false;
    this.editorMaskSubtract = false;
    this.editorMaskBrushSize = 18;
    this.editorMaskStrokes = [];
    this.editorMaskExposure = 0;
    this.editorMaskContrast = 0;
    this.editorMaskHighlights = 0;
    this.editorMaskShadows = 0;
    this.editorMaskTemperature = 0;
    this.editorMaskTint = 0;
    this.editorMaskSaturation = 0;
    this.editorMaskClarity = 0;
    this.editorMaskLayers = [];
    this.editorActiveMaskLayerId = '';
    this.editorNextMaskNumber = 1;
    this.editorActiveMaskStroke = -1;
    this.clearEditorRenderedPreview();
    this.editorPickerSample = 'RGB 取样：尚未取样';
    this.editorRotation = 0;
    this.editorFlipHorizontal = false;
    this.editorFlipVertical = false;
    this.editorCropRatio = 'original';
    this.editorShowingOriginal = false;
    this.editorAIBackup = [];
    this.editorAICanUndo = false;
    this.editorAISummary = '等待分析当前照片';
    this.editorAIAnalysis = undefined;
  }

  private resetEditorTone(): void {
    const rotation: number = this.editorRotation;
    const flipHorizontal: boolean = this.editorFlipHorizontal;
    const flipVertical: boolean = this.editorFlipVertical;
    const cropRatio: string = this.editorCropRatio;
    this.resetImageEditor();
    this.editorRotation = rotation;
    this.editorFlipHorizontal = flipHorizontal;
    this.editorFlipVertical = flipVertical;
    this.editorCropRatio = cropRatio;
  }

  private applyEditorPreset(preset: string): void {
    this.resetEditorTone();
    this.editorAIBackup = [];
    this.editorAICanUndo = false;
    this.editorAISummary = '等待分析当前照片';
    this.editorAIAnalysis = undefined;
    this.editorPreset = preset;
    if (preset === 'natural') {
      this.editorContrast = 8;
      this.editorHighlights = -18;
      this.editorShadows = 16;
      this.editorWhites = 8;
      this.editorBlacks = -8;
      this.editorVibrance = 14;
      this.editorTexture = 8;
      this.editorClarity = 6;
      this.editorSharpening = 24;
      this.editorNoiseReduction = 8;
    } else if (preset === 'portrait') {
      this.editorContrast = -4;
      this.editorHighlights = -24;
      this.editorShadows = 18;
      this.editorTemperature = 7;
      this.editorTint = 4;
      this.editorVibrance = 10;
      this.editorTexture = -12;
      this.editorClarity = -6;
      this.editorSharpening = 16;
      this.editorNoiseReduction = 22;
      this.editorVignette = -8;
    } else if (preset === 'landscape') {
      this.editorContrast = 12;
      this.editorHighlights = -28;
      this.editorShadows = 14;
      this.editorWhites = 12;
      this.editorBlacks = -14;
      this.editorVibrance = 24;
      this.editorSaturation = 5;
      this.editorTexture = 16;
      this.editorClarity = 18;
      this.editorSharpening = 30;
      this.editorDehaze = 12;
      this.editorVignette = -10;
    } else if (preset === 'monochrome') {
      this.editorContrast = 22;
      this.editorHighlights = -18;
      this.editorShadows = 12;
      this.editorWhites = 10;
      this.editorBlacks = -22;
      this.editorSaturation = -100;
      this.editorTexture = 12;
      this.editorClarity = 24;
      this.editorSharpening = 28;
      this.editorVignette = -14;
    }
  }

  private applyNikonCloudPreset(preset: NikonCloudPreset): void {
    this.resetEditorTone();
    this.editorPreset = 'original';
    this.editorContrast = preset.tone.contrast;
    this.editorHighlights = preset.tone.highlights;
    this.editorShadows = preset.tone.shadows;
    this.editorWhites = preset.tone.whites;
    this.editorBlacks = preset.tone.blacks;
    this.editorSaturation = preset.tone.saturation;
    this.editorTexture = preset.tone.texture;
    this.editorClarity = preset.tone.clarity;
    this.editorSharpening = preset.tone.sharpening;
    this.editorWheelLiftX = preset.grading.liftX;
    this.editorWheelLiftY = preset.grading.liftY;
    this.editorWheelGammaX = preset.grading.gammaX;
    this.editorWheelGammaY = preset.grading.gammaY;
    this.editorWheelGainX = preset.grading.gainX;
    this.editorWheelGainY = preset.grading.gainY;
    if (preset.toneCurve.length > 1) {
      const denominator: number = preset.toneCurve.length - 1;
      this.editorCurvePoints = preset.toneCurve.map(
        (value: number, index: number): EditorCurvePoint => {
          return new EditorCurvePoint(
            index / denominator,
            this.editorClampUnit(value)
          );
        }
      );
    }
    this.editorNikonCloudPresetId = preset.id;
    this.editorAIBackup = [];
    this.editorAICanUndo = false;
    this.editorAIAnalysis = undefined;
    this.editorAISummary = '等待分析当前照片';
    this.editorShowingOriginal = false;
    this.status = `尼康云创预览 · ${preset.name} · SDR 近似`;
    this.refreshEditorRenderedPreview();
  }

  private captureEditorTone(): Array<EditorToneValue> {
    return [
      this.editorExposure,
      this.editorContrast,
      this.editorHighlights,
      this.editorShadows,
      this.editorWhites,
      this.editorBlacks,
      this.editorTemperature,
      this.editorTint,
      this.editorVibrance,
      this.editorSaturation,
      this.editorTexture,
      this.editorClarity,
      this.editorSharpening,
      this.editorNoiseReduction,
      this.editorDehaze,
      this.editorVignette,
      this.editorWheelLift,
      this.editorWheelGamma,
      this.editorWheelGain,
      this.editorWheelLiftX,
      this.editorWheelLiftY,
      this.editorWheelGammaX,
      this.editorWheelGammaY,
      this.editorWheelGainX,
      this.editorWheelGainY,
      this.editorCurveContrast,
      this.editorCurvePivot,
      this.editorCurveShadows,
      this.editorCurveMidtones,
      this.editorCurveHighlights,
      this.editorCurvePoints.map((point: EditorCurvePoint): Array<number> => [point.x, point.y]),
      this.editorMaskEnabled,
      this.editorMaskFeather,
      this.editorPreset,
      this.editorShowingOriginal
    ];
  }

  private restoreEditorTone(values: Array<EditorToneValue>): void {
    if (values.length < 18) {
      return;
    }
    this.editorExposure = values[0] as number;
    this.editorContrast = values[1] as number;
    this.editorHighlights = values[2] as number;
    this.editorShadows = values[3] as number;
    this.editorWhites = values[4] as number;
    this.editorBlacks = values[5] as number;
    this.editorTemperature = values[6] as number;
    this.editorTint = values[7] as number;
    this.editorVibrance = values[8] as number;
    this.editorSaturation = values[9] as number;
    this.editorTexture = values[10] as number;
    this.editorClarity = values[11] as number;
    this.editorSharpening = values[12] as number;
    this.editorNoiseReduction = values[13] as number;
    this.editorDehaze = values[14] as number;
    this.editorVignette = values[15] as number;
    // Older copied tones contain 18 values; preserve compatibility while
    // restoring the additional grading controls when present.
    if (values.length >= 35) {
      this.editorWheelLift = values[16] as number;
      this.editorWheelGamma = values[17] as number;
      this.editorWheelGain = values[18] as number;
      this.editorWheelLiftX = values[19] as number;
      this.editorWheelLiftY = values[20] as number;
      this.editorWheelGammaX = values[21] as number;
      this.editorWheelGammaY = values[22] as number;
      this.editorWheelGainX = values[23] as number;
      this.editorWheelGainY = values[24] as number;
      this.editorCurveContrast = values[25] as number;
      this.editorCurvePivot = values[26] as number;
      this.editorCurveShadows = values[27] as number;
      this.editorCurveMidtones = values[28] as number;
      this.editorCurveHighlights = values[29] as number;
      const pointData = values[30] as Array<Array<number>>;
      if (Array.isArray(pointData) && pointData.length > 1) {
        this.editorCurvePoints = pointData.map((point: Array<number>): EditorCurvePoint => new EditorCurvePoint(point[0], point[1]));
      }
      this.editorMaskEnabled = values[31] as boolean;
      this.editorMaskFeather = values[32] as number;
      this.editorPreset = values[33] as string;
      this.editorShowingOriginal = values[34] as boolean;
    } else if (values.length >= 25) {
      this.editorWheelLift = values[16] as number;
      this.editorWheelGamma = values[17] as number;
      this.editorWheelGain = values[18] as number;
      this.editorCurveContrast = values[19] as number;
      this.editorCurvePivot = values[20] as number;
      this.editorCurveShadows = this.editorCurveContrast;
      this.editorCurveMidtones = this.editorCurveContrast;
      this.editorCurveHighlights = this.editorCurveContrast;
      this.editorMaskEnabled = values[21] as boolean;
      this.editorMaskFeather = values[22] as number;
      this.editorPreset = values[23] as string;
      this.editorShowingOriginal = values[24] as boolean;
    } else {
      this.editorPreset = values[16] as string;
      this.editorShowingOriginal = values[17] as boolean;
    }
  }

  private async applyEditorAI(): Promise<void> {
    const analysis: EditorAIAnalysis | undefined =
      await this.analyzeEditorPhoto();
    if (analysis === undefined) {
      this.showError('无法分析当前照片');
      return;
    }
    const previousTone: Array<EditorToneValue> =
      this.captureEditorTone();
    this.resetEditorTone();
    this.editorAIBackup = previousTone;
    this.editorAIAnalysis = analysis;
    this.editorAICanUndo = true;
    const amount: number = Math.max(
      0.35,
      Math.min(1, this.editorAIIntensity / 100)
    );
    const targetExposure: number = Math.max(
      -0.8,
      Math.min(
        0.8,
        Math.log2(0.48 / Math.max(0.08, analysis.meanLuma)) * 0.68
      )
    );
    this.editorExposure = Math.round(targetExposure * 100 * amount);
    this.editorContrast = this.editorAIValue(
      Math.max(-8, Math.min(24, (0.20 - analysis.contrast) * 130)),
      amount
    );
    this.editorHighlights = -this.editorAIValue(
      Math.max(6, Math.min(
        48,
        analysis.highlightRatio * 360
          + Math.max(0, analysis.meanLuma - 0.55) * 70
      )),
      amount
    );
    this.editorShadows = this.editorAIValue(
      Math.max(6, Math.min(
        46,
        analysis.shadowRatio * 330
          + Math.max(0, 0.44 - analysis.meanLuma) * 75
      )),
      amount
    );
    this.editorWhites = this.editorAIValue(
      Math.max(-8, Math.min(14, (0.58 - analysis.meanLuma) * 28)),
      amount
    );
    this.editorBlacks = -this.editorAIValue(
      Math.max(4, Math.min(18, (0.21 - analysis.contrast) * 55 + 5)),
      amount
    );
    this.editorTemperature = this.editorAIValue(
      Math.max(-18, Math.min(18, (analysis.blue - analysis.red) * 95)),
      amount
    );
    const greenExcess: number =
      analysis.green - (analysis.red + analysis.blue) / 2;
    this.editorTint = this.editorAIValue(
      Math.max(-14, Math.min(14, greenExcess * 85)),
      amount
    );
    this.editorVibrance = this.editorAIValue(
      Math.max(4, Math.min(26, (0.30 - analysis.saturation) * 95 + 6)),
      amount
    );
    this.editorSaturation = this.editorAIValue(
      Math.max(-4, Math.min(8, (0.22 - analysis.saturation) * 28)),
      amount
    );
    this.editorTexture = this.editorAIValue(
      Math.max(4, Math.min(16, (0.075 - analysis.detail) * 170 + 7)),
      amount
    );
    this.editorClarity = this.editorAIValue(
      Math.max(3, Math.min(18, (0.19 - analysis.contrast) * 70 + 6)),
      amount
    );
    this.editorSharpening = this.editorAIValue(
      Math.max(14, Math.min(34, (0.08 - analysis.detail) * 210 + 20)),
      amount
    );
    this.editorNoiseReduction = this.editorAIValue(
      Math.max(6, Math.min(
        30,
        analysis.shadowRatio * 120
          + Math.max(0, 0.38 - analysis.meanLuma) * 42 + 6
      )),
      amount
    );
    this.editorDehaze = this.editorAIValue(
      Math.max(0, Math.min(16, (0.18 - analysis.contrast) * 75)),
      amount
    );
    this.editorPreset = 'original';
    this.editorShowingOriginal = false;
    this.editorAISummary = analysis.summary();
    this.status = 'AI 优化已应用 · 可继续微调';
  }

  private undoEditorAI(): void {
    if (this.editorAIBackup.length === 0) {
      return;
    }
    this.restoreEditorTone(this.editorAIBackup);
    this.editorAIBackup = [];
    this.editorAICanUndo = false;
    this.editorAISummary = '已撤销 AI 优化';
    this.status = '已恢复 AI 优化前的参数';
  }

  private editorAIValue(value: number, amount: number): number {
    return Math.round(value * amount);
  }

  private async analyzeEditorPhoto(): Promise<EditorAIAnalysis | undefined> {
    if (this.editorSelectedPath.length === 0) {
      return undefined;
    }
    let source: image.ImageSource | undefined = undefined;
    let pixelMap: image.PixelMap | undefined = undefined;
    try {
      source = image.createImageSource(`file://${this.editorSelectedPath}`);
      pixelMap = await source.createPixelMap({
        editable: false,
        desiredSize: { width: 128, height: 128 },
        desiredPixelFormat: image.PixelMapFormat.RGBA_8888
      });
      const info: image.ImageInfo = await pixelMap.getImageInfo();
      const buffer: ArrayBuffer = new ArrayBuffer(
        info.size.width * info.size.height * 4
      );
      await pixelMap.readPixelsToBuffer(buffer);
      const pixels: Uint8Array = new Uint8Array(buffer);
      const analysis: EditorAIAnalysis = new EditorAIAnalysis();
      const lumas: Array<number> = new Array<number>(pixels.length / 4);
      let lumaSum: number = 0;
      let shadows: number = 0;
      let highlights: number = 0;
      for (let offset: number = 0; offset < pixels.length; offset += 4) {
        const red: number = pixels[offset] / 255;
        const green: number = pixels[offset + 1] / 255;
        const blue: number = pixels[offset + 2] / 255;
        const luma: number =
          red * 0.2126 + green * 0.7152 + blue * 0.0722;
        const index: number = offset / 4;
        lumas[index] = luma;
        lumaSum += luma;
        analysis.red += red;
        analysis.green += green;
        analysis.blue += blue;
        analysis.saturation += Math.max(red, Math.max(green, blue))
          - Math.min(red, Math.min(green, blue));
        if (luma < 0.10) shadows++;
        if (luma > 0.90) highlights++;
      }
      const count: number = lumas.length;
      analysis.meanLuma = lumaSum / count;
      let variance: number = 0;
      let detail: number = 0;
      for (let y: number = 0; y < info.size.height; y++) {
        for (let x: number = 0; x < info.size.width; x++) {
          const index: number = y * info.size.width + x;
          const delta: number = lumas[index] - analysis.meanLuma;
          variance += delta * delta;
          if (x > 0) {
            detail += Math.abs(lumas[index] - lumas[index - 1]);
          }
        }
      }
      analysis.contrast = Math.sqrt(variance / count);
      analysis.shadowRatio = shadows / count;
      analysis.highlightRatio = highlights / count;
      analysis.saturation /= count;
      analysis.red /= count;
      analysis.green /= count;
      analysis.blue /= count;
      analysis.detail = detail / Math.max(
        1,
        info.size.height * (info.size.width - 1)
      );
      return analysis;
    } catch (error) {
      this.diagnostics?.error(
        'editor',
        `AI 分析失败：${(error as BusinessError).message}`
      );
      return undefined;
    } finally {
      pixelMap?.release();
      source?.release();
    }
  }

  private async sampleEditorCenterColor(): Promise<void> {
    if (this.editorSelectedPath.length === 0) {
      this.editorPickerSample = 'RGB 取样：未选择照片';
      return;
    }
    let source: image.ImageSource | undefined = undefined;
    let pixelMap: image.PixelMap | undefined = undefined;
    try {
      source = image.createImageSource(`file://${this.editorSelectedPath}`);
      pixelMap = await source.createPixelMap({
        editable: false,
        desiredSize: { width: 3, height: 3 },
        desiredPixelFormat: image.PixelMapFormat.RGBA_8888
      });
      const buffer: ArrayBuffer = new ArrayBuffer(3 * 3 * 4);
      await pixelMap.readPixelsToBuffer(buffer);
      const pixels: Uint8Array = new Uint8Array(buffer);
      const offset: number = 4 * 4;
      const red: number = pixels[offset];
      const green: number = pixels[offset + 1];
      const blue: number = pixels[offset + 2];
      const hex: string = `#${red.toString(16).padStart(2, '0')}${green.toString(16).padStart(2, '0')}${blue.toString(16).padStart(2, '0')}`.toUpperCase();
      this.editorPickerSample = `RGB 取样：${hex}`;
      this.editorTemperature = Math.max(-100, Math.min(100, (blue - red) / 2.55));
      this.editorTint = Math.max(-100, Math.min(100, (green - (red + blue) / 2) / 2.55));
    } catch (error) {
      this.editorPickerSample = 'RGB 取样：读取失败';
    } finally {
      pixelMap?.release();
      source?.release();
    }
  }

  private editorChannel(value: number): number {
    return Math.max(0, Math.min(255, Math.round(value)));
  }

  private editorClampUnit(value: number): number {
    return Math.max(0, Math.min(1, value));
  }

  private editorSmoothStep(
    edge0: number,
    edge1: number,
    value: number
  ): number {
    const scaled: number = this.editorClampUnit(
      (value - edge0) / (edge1 - edge0)
    );
    return scaled * scaled * (3 - 2 * scaled);
  }

  private activeEditorMaskLayer(): EditorMaskLayer | undefined {
    return this.editorMaskLayers.find((layer: EditorMaskLayer): boolean => {
      return layer.id === this.editorActiveMaskLayerId;
    });
  }

  private activeEditorMaskLayerVisible(): boolean {
    const layer: EditorMaskLayer | undefined = this.activeEditorMaskLayer();
    return layer !== undefined && layer.visible;
  }

  private createEditorMaskLayer(): void {
    this.persistActiveEditorMaskLayer();
    const layer = new EditorMaskLayer(
      `${Date.now()}-${this.editorNextMaskNumber}`,
      `${this.tr('蒙版')} ${this.editorNextMaskNumber}`
    );
    this.editorNextMaskNumber += 1;
    this.editorMaskLayers.push(layer);
    this.editorMaskLayers = this.editorMaskLayers.slice();
    this.loadEditorMaskLayer(layer);
  }

  private ensureEditorMaskLayer(): void {
    if (!this.editorMaskEnabled || this.activeEditorMaskLayer() === undefined) {
      this.createEditorMaskLayer();
    }
  }

  private selectEditorMaskLayer(id: string): void {
    if (id === this.editorActiveMaskLayerId) return;
    this.persistActiveEditorMaskLayer();
    const layer: EditorMaskLayer | undefined = this.editorMaskLayers.find(
      (candidate: EditorMaskLayer): boolean => candidate.id === id
    );
    if (layer !== undefined) this.loadEditorMaskLayer(layer);
  }

  private deleteActiveEditorMaskLayer(): void {
    const index: number = this.editorMaskLayers.findIndex(
      (layer: EditorMaskLayer): boolean => {
        return layer.id === this.editorActiveMaskLayerId;
      }
    );
    if (index < 0) return;
    this.persistActiveEditorMaskLayer();
    this.editorMaskLayers.splice(index, 1);
    this.editorMaskLayers = this.editorMaskLayers.slice();
    if (this.editorMaskLayers.length === 0) {
      this.editorMaskEnabled = false;
      this.editorActiveMaskLayerId = '';
      this.editorMaskStrokes = [];
    } else {
      this.loadEditorMaskLayer(
        this.editorMaskLayers[Math.min(index, this.editorMaskLayers.length - 1)]
      );
    }
  }

  private setEditorMaskLayerVisible(id: string, visible: boolean): void {
    this.persistActiveEditorMaskLayer();
    const index: number = this.editorMaskLayers.findIndex(
      (layer: EditorMaskLayer): boolean => layer.id === id
    );
    if (index < 0) return;
    this.editorMaskLayers[index].visible = visible;
    this.editorMaskLayers = this.editorMaskLayers.slice();
  }

  private displayedEditorMaskLayer(layer: EditorMaskLayer): EditorMaskLayer {
    return layer.id === this.editorActiveMaskLayerId
      ? this.snapshotEditorMaskLayer(layer)
      : layer.copy();
  }

  private effectiveEditorMaskLayers(): Array<EditorMaskLayer> {
    return this.editorMaskLayers.map(
      (layer: EditorMaskLayer): EditorMaskLayer => {
        return this.displayedEditorMaskLayer(layer);
      }
    );
  }

  private persistActiveEditorMaskLayer(): void {
    const index: number = this.editorMaskLayers.findIndex(
      (layer: EditorMaskLayer): boolean => {
        return layer.id === this.editorActiveMaskLayerId;
      }
    );
    if (index < 0) return;
    this.editorMaskLayers[index] = this.snapshotEditorMaskLayer(
      this.editorMaskLayers[index]
    );
    this.editorMaskLayers = this.editorMaskLayers.slice();
  }

  private snapshotEditorMaskLayer(identity: EditorMaskLayer): EditorMaskLayer {
    const layer = new EditorMaskLayer(identity.id, identity.name);
    layer.visible = identity.visible;
    layer.type = this.editorMaskType;
    layer.amount = this.editorMaskAmount;
    layer.feather = this.editorMaskFeather;
    layer.invert = this.editorMaskInvert;
    layer.subtract = this.editorMaskSubtract;
    layer.brushSize = this.editorMaskBrushSize;
    layer.strokes = this.editorMaskStrokes.map(
      (stroke: EditorMaskStroke): EditorMaskStroke => {
        return new EditorMaskStroke(
          stroke.id,
          stroke.subtract,
          stroke.size,
          stroke.points.map((point: EditorMaskPoint): EditorMaskPoint => {
            return new EditorMaskPoint(point.x, point.y);
          })
        );
      }
    );
    layer.exposure = this.editorMaskExposure;
    layer.contrast = this.editorMaskContrast;
    layer.highlights = this.editorMaskHighlights;
    layer.shadows = this.editorMaskShadows;
    layer.temperature = this.editorMaskTemperature;
    layer.tint = this.editorMaskTint;
    layer.saturation = this.editorMaskSaturation;
    layer.clarity = this.editorMaskClarity;
    return layer;
  }

  private loadEditorMaskLayer(layer: EditorMaskLayer): void {
    const value: EditorMaskLayer = layer.copy();
    this.editorMaskEnabled = true;
    this.editorActiveMaskLayerId = value.id;
    this.editorMaskType = value.type;
    this.editorMaskAmount = value.amount;
    this.editorMaskFeather = value.feather;
    this.editorMaskInvert = value.invert;
    this.editorMaskSubtract = value.subtract;
    this.editorMaskBrushSize = value.brushSize;
    this.editorMaskStrokes = value.strokes;
    this.editorMaskExposure = value.exposure;
    this.editorMaskContrast = value.contrast;
    this.editorMaskHighlights = value.highlights;
    this.editorMaskShadows = value.shadows;
    this.editorMaskTemperature = value.temperature;
    this.editorMaskTint = value.tint;
    this.editorMaskSaturation = value.saturation;
    this.editorMaskClarity = value.clarity;
    this.editorActiveMaskStroke = -1;
  }

  private editorImageRect(): EditorPreviewRect {
    const inset: number = 12;
    const availableWidth: number = Math.max(
      1,
      this.editorPreviewWidth - inset * 2
    );
    const availableHeight: number = Math.max(
      1,
      this.editorPreviewHeight - inset * 2
    );
    const imageWidth: number = Math.max(1, this.editorImageWidth);
    const imageHeight: number = Math.max(1, this.editorImageHeight);
    const scale: number = Math.min(
      availableWidth / imageWidth,
      availableHeight / imageHeight
    );
    const width: number = imageWidth * scale;
    const height: number = imageHeight * scale;
    return new EditorPreviewRect(
      inset + (availableWidth - width) / 2,
      inset + (availableHeight - height) / 2,
      width,
      height
    );
  }

  private async refreshEditorImageMetrics(): Promise<void> {
    if (this.editorSelectedPath.length === 0) return;
    let source: image.ImageSource | undefined = undefined;
    try {
      source = image.createImageSource(`file://${this.editorSelectedPath}`);
      const info: image.ImageInfo = await source.getImageInfo();
      this.editorImageWidth = Math.max(1, info.size.width);
      this.editorImageHeight = Math.max(1, info.size.height);
      if (this.editorMaskEnabled) {
        this.refreshEditorRenderedPreview();
      }
    } catch (_) {
    } finally {
      source?.release();
    }
  }

  private handleEditorMaskTouch(event: TouchEvent): void {
    if (
      this.editorPanel !== 'mask' ||
      !this.editorMaskEnabled ||
      !this.activeEditorMaskLayerVisible() ||
      this.editorSelectedPath.length === 0
    ) {
      return;
    }
    const touch = event.touches[0];
    if (touch === undefined) {
      if (event.type === TouchType.Up) this.editorActiveMaskStroke = -1;
      return;
    }
    const rect: EditorPreviewRect = this.editorImageRect();
    if (
      event.type === TouchType.Down &&
      (
        touch.x < rect.left || touch.x > rect.left + rect.width ||
        touch.y < rect.top || touch.y > rect.top + rect.height
      )
    ) {
      return;
    }
    const point = new EditorMaskPoint(
      Math.max(0, Math.min(1, (touch.x - rect.left) / rect.width)),
      Math.max(0, Math.min(1, (touch.y - rect.top) / rect.height))
    );
    if (event.type === TouchType.Down) {
      const stroke = new EditorMaskStroke(
        `${Date.now()}-${this.editorMaskStrokes.length}`,
        this.editorMaskSubtract,
        this.editorMaskBrushSize,
        [point]
      );
      this.editorMaskStrokes.push(stroke);
      this.editorActiveMaskStroke = this.editorMaskStrokes.length - 1;
      this.editorMaskStrokes = this.editorMaskStrokes.slice();
    } else if (
      event.type === TouchType.Move &&
      this.editorActiveMaskStroke >= 0
    ) {
      this.editorMaskStrokes[this.editorActiveMaskStroke].points.push(point);
      this.editorMaskStrokes = this.editorMaskStrokes.slice();
      if (
        this.editorMaskStrokes[this.editorActiveMaskStroke].points.length % 6 === 0
      ) {
        this.refreshEditorRenderedPreview();
      }
    } else if (event.type === TouchType.Up) {
      this.editorActiveMaskStroke = -1;
      this.status = this.editorMaskSubtract
        ? '已减去蒙版区域'
        : '已添加蒙版区域';
      this.refreshEditorRenderedPreview();
    }
  }

  private editorCurveValue(input: number): number {
    const points: Array<EditorCurvePoint> = this.editorCurvePoints.slice().sort((a: EditorCurvePoint, b: EditorCurvePoint): number => a.x - b.x);
    const x: number = this.editorClampUnit(input);
    if (points.length < 2) return x;
    if (x <= points[0].x) return points[0].y;
    if (x >= points[points.length - 1].x) return points[points.length - 1].y;
    let index: number = 1;
    while (index < points.length && points[index].x < x) index++;
    const p0: EditorCurvePoint = points[Math.max(0, index - 2)];
    const p1: EditorCurvePoint = points[index - 1];
    const p2: EditorCurvePoint = points[index];
    const p3: EditorCurvePoint = points[Math.min(points.length - 1, index + 1)];
    const t: number = (x - p1.x) / Math.max(0.0001, p2.x - p1.x);
    const t2: number = t * t;
    const t3: number = t2 * t;
    const y: number = 0.5 * (2 * p1.y + (-p0.y + p2.y) * t + (2 * p0.y - 5 * p1.y + 4 * p2.y - p3.y) * t2 + (-p0.y + 3 * p1.y - 3 * p2.y + p3.y) * t3);
    return this.editorClampUnit(y);
  }

  private applyNikonCloudColorMixer(
    channels: Array<number>,
    hsl: Array<number>,
    preset: NikonCloudPreset
  ): void {
    if (preset.mixer.length !== 8) return;
    const red: number = this.editorClampUnit(channels[0]);
    const green: number = this.editorClampUnit(channels[1]);
    const blue: number = this.editorClampUnit(channels[2]);
    const maximum: number = Math.max(red, Math.max(green, blue));
    const minimum: number = Math.min(red, Math.min(green, blue));
    const delta: number = maximum - minimum;
    const lightness: number = (maximum + minimum) / 2;
    let hue: number = 0;
    let saturation: number = 0;
    if (delta > 0.000001) {
      saturation = delta / Math.max(
        0.000001,
        1 - Math.abs(2 * lightness - 1)
      );
      if (maximum === red) {
        hue = 60 * (((green - blue) / delta) % 6);
      } else if (maximum === green) {
        hue = 60 * ((blue - red) / delta + 2);
      } else {
        hue = 60 * ((red - green) / delta + 4);
      }
      if (hue < 0) hue += 360;
    }
    const anchors: Array<number> = [0, 30, 60, 120, 180, 240, 280, 330];
    let totalWeight: number = 0;
    let hueShift: number = 0;
    let chromaShift: number = 0;
    let brightnessShift: number = 0;
    for (let index: number = 0; index < anchors.length; index++) {
      const direct: number = Math.abs(hue - anchors[index]);
      const distance: number = Math.min(direct, 360 - direct);
      const weight: number = Math.max(0, 1 - distance / 60);
      const item: NikonCloudColorMix = preset.mixer[index];
      totalWeight += weight;
      hueShift += item.hue * weight;
      chromaShift += item.chroma * weight;
      brightnessShift += item.brightness * weight;
    }
    let mixedHue: number = hue;
    let mixedSaturation: number = saturation;
    let mixedLightness: number = lightness;
    if (totalWeight > 0) {
      mixedHue = (hue + hueShift / totalWeight * 0.5) % 360;
      if (mixedHue < 0) mixedHue += 360;
      mixedSaturation = this.editorClampUnit(
        saturation * (1 + chromaShift / totalWeight / 64)
      );
      mixedLightness = this.editorClampUnit(
        lightness + brightnessShift / totalWeight / 255
      );
    }
    hsl[0] = mixedHue;
    hsl[1] = mixedSaturation;
    hsl[2] = mixedLightness;
    const chroma: number = (1 - Math.abs(2 * hsl[2] - 1)) * hsl[1];
    const sector: number = hsl[0] / 60;
    const secondary: number = chroma * (1 - Math.abs(sector % 2 - 1));
    let mixedRed: number = 0;
    let mixedGreen: number = 0;
    let mixedBlue: number = 0;
    if (sector < 1) {
      mixedRed = chroma; mixedGreen = secondary;
    } else if (sector < 2) {
      mixedRed = secondary; mixedGreen = chroma;
    } else if (sector < 3) {
      mixedGreen = chroma; mixedBlue = secondary;
    } else if (sector < 4) {
      mixedGreen = secondary; mixedBlue = chroma;
    } else if (sector < 5) {
      mixedRed = secondary; mixedBlue = chroma;
    } else {
      mixedRed = chroma; mixedBlue = secondary;
    }
    const match: number = hsl[2] - chroma / 2;
    channels[0] = this.editorClampUnit(mixedRed + match);
    channels[1] = this.editorClampUnit(mixedGreen + match);
    channels[2] = this.editorClampUnit(mixedBlue + match);
  }

  private processEditorPixels(
    pixels: Uint8Array,
    width: number,
    height: number
  ): void {
    const exposure: number = Math.pow(2, this.editorExposure / 100);
    const contrast: number =
      1 + this.editorContrast / 125 + this.editorDehaze / 210;
    const baseSaturation: number =
      1 + this.editorSaturation / 100 + this.editorDehaze / 520;
    const temperature: number = this.editorTemperature / 100;
    const tint: number = this.editorTint / 100;
    const cloudPreset: NikonCloudPreset | undefined =
      this.selectedNikonCloudPreset();
    const cloudChannels: Array<number> = [0, 0, 0];
    const cloudHsl: Array<number> = [0, 0, 0];
    for (let offset: number = 0; offset < pixels.length; offset += 4) {
      let red: number = pixels[offset] / 255 * exposure;
      let green: number = pixels[offset + 1] / 255 * exposure;
      let blue: number = pixels[offset + 2] / 255 * exposure;

      let luma: number = red * 0.2126 + green * 0.7152 + blue * 0.0722;
      const shadowWeight: number = Math.pow(1 - this.editorClampUnit(luma), 2);
      const midWeight: number = 1 - Math.abs(this.editorClampUnit(luma) * 2 - 1);
      const highlightWeight: number = Math.pow(this.editorClampUnit(luma), 2);
      const wheelX: number = this.editorWheelLiftX / 100 * 0.10 * shadowWeight
        + this.editorWheelGammaX / 100 * 0.10 * midWeight
        + this.editorWheelGainX / 100 * 0.10 * highlightWeight;
      const wheelY: number = this.editorWheelLiftY / 100 * 0.10 * shadowWeight
        + this.editorWheelGammaY / 100 * 0.10 * midWeight
        + this.editorWheelGainY / 100 * 0.10 * highlightWeight;
      red += wheelX - wheelY * 0.5;
      green += wheelY - wheelX * 0.5;
      blue -= (wheelX + wheelY) * 0.5;

      red += temperature * 0.12 + tint * 0.045;
      green -= tint * 0.08;
      blue -= temperature * 0.12 - tint * 0.045;

      luma = red * 0.2126 + green * 0.7152 + blue * 0.0722;
      const toneShift: number =
        this.editorShadows / 100
          * Math.pow(1 - this.editorClampUnit(luma), 2)
          * 0.38
        + this.editorHighlights / 100
          * Math.pow(this.editorClampUnit(luma), 2)
          * 0.30
        + this.editorWhites / 100
          * this.editorSmoothStep(0.55, 1, luma)
          * 0.24
        + this.editorBlacks / 100
          * (1 - this.editorSmoothStep(0, 0.45, luma))
          * 0.20;
      red += toneShift;
      green += toneShift;
      blue += toneShift;

      const clarityMask: number =
        1 - Math.abs(this.editorClampUnit(luma) * 2 - 1);
      const localContrast: number =
        1 + this.editorClarity / 100 * clarityMask * 0.38;
      red = (red - 0.5) * contrast * localContrast + 0.5;
      green = (green - 0.5) * contrast * localContrast + 0.5;
      blue = (blue - 0.5) * contrast * localContrast + 0.5;

      if (this.editorCurvePoints.length > 2) {
        const mapped: number = this.editorCurveValue(luma);
        const delta: number = mapped - luma;
        red += delta;
        green += delta;
        blue += delta;
      }

      luma = red * 0.2126 + green * 0.7152 + blue * 0.0722;
      const maximum: number = Math.max(red, Math.max(green, blue));
      const minimum: number = Math.min(red, Math.min(green, blue));
      const colorfulness: number = maximum - minimum;
      const saturation: number = Math.max(
        0,
        baseSaturation
          + this.editorVibrance / 100
            * (1 - this.editorClampUnit(colorfulness))
            * 0.82
      );
      red = luma + (red - luma) * saturation;
      green = luma + (green - luma) * saturation;
      blue = luma + (blue - luma) * saturation;

      if (cloudPreset !== undefined) {
        cloudChannels[0] = red;
        cloudChannels[1] = green;
        cloudChannels[2] = blue;
        this.applyNikonCloudColorMixer(
          cloudChannels,
          cloudHsl,
          cloudPreset
        );
        red = cloudChannels[0];
        green = cloudChannels[1];
        blue = cloudChannels[2];
      }

      const index: number = offset / 4;
      const x: number = index % width;
      const y: number = Math.floor(index / width);
      const normalizedX: number =
        (x - width / 2) / Math.max(1, width / 2);
      const normalizedY: number =
        (y - height / 2) / Math.max(1, height / 2);
      const edge: number = Math.min(
        1,
        Math.sqrt(
          normalizedX * normalizedX + normalizedY * normalizedY
        )
      );
      const vignette: number =
        1 + this.editorVignette / 100 * edge * edge * 0.72;
      pixels[offset] = this.editorChannel(red * vignette * 255);
      pixels[offset + 1] = this.editorChannel(
        green * vignette * 255
      );
      pixels[offset + 2] = this.editorChannel(
        blue * vignette * 255
      );
    }
    this.processEditorDetailPixels(pixels, width, height);
  }

  private processEditorMaskPixels(
    pixels: Uint8Array,
    width: number,
    height: number
  ): void {
    if (!this.editorMaskEnabled) return;
    this.effectiveEditorMaskLayers().forEach(
      (layer: EditorMaskLayer): void => {
        if (layer.visible && layer.type.length > 0) {
          this.processEditorMaskLayerPixels(pixels, width, height, layer);
        }
      }
    );
  }

  private async createEditorMaskOverlay(
    sourcePixels: Uint8Array,
    width: number,
    height: number
  ): Promise<image.PixelMap | undefined> {
    const active: EditorMaskLayer | undefined = this.activeEditorMaskLayer();
    if (active === undefined || !active.visible) return undefined;
    const layer: EditorMaskLayer = this.displayedEditorMaskLayer(active);
    const mask: Uint8Array = this.buildEditorMask(
      width,
      height,
      sourcePixels,
      layer
    );
    const overlay: Uint8Array = new Uint8Array(width * height * 4);
    const intensity: number = Math.max(
      0,
      Math.min(1, layer.amount / 100)
    );
    for (let index: number = 0; index < mask.length; index++) {
      const coverage: number = mask[index] / 255;
      const effective: number = (
        layer.invert ? 1 - coverage : coverage
      ) * intensity;
      const offset: number = index * 4;
      overlay[offset] = 22;
      overlay[offset + 1] = 115;
      overlay[offset + 2] = 230;
      overlay[offset + 3] = Math.round(150 * effective);
    }
    return image.createPixelMap(overlay.buffer, {
      editable: false,
      pixelFormat: image.PixelMapFormat.RGBA_8888,
      alphaType: image.AlphaType.UNPREMUL,
      size: { width: width, height: height }
    });
  }

  private processEditorMaskLayerPixels(
    pixels: Uint8Array,
    width: number,
    height: number,
    layer: EditorMaskLayer
  ): void {
    const original: Uint8Array = new Uint8Array(pixels);
    const local: Uint8Array = new Uint8Array(pixels);
    const exposure: number = Math.pow(2, layer.exposure / 100);
    const contrast: number = 1 + layer.contrast / 100;
    const saturation: number = Math.max(
      0,
      1 + layer.saturation / 100
    );
    const temperature: number = layer.temperature / 100;
    const tint: number = layer.tint / 100;
    for (let offset: number = 0; offset < local.length; offset += 4) {
      let red: number = original[offset] / 255 * exposure;
      let green: number = original[offset + 1] / 255 * exposure;
      let blue: number = original[offset + 2] / 255 * exposure;
      red += temperature * 0.12 + tint * 0.045;
      green -= tint * 0.08;
      blue -= temperature * 0.12 - tint * 0.045;
      let luma: number = red * 0.2126 + green * 0.7152 + blue * 0.0722;
      const tone: number = layer.shadows / 100
        * Math.pow(1 - this.editorClampUnit(luma), 2) * 0.38
        + layer.highlights / 100
        * Math.pow(this.editorClampUnit(luma), 2) * 0.30;
      red += tone;
      green += tone;
      blue += tone;
      const clarityWeight: number =
        1 - Math.abs(this.editorClampUnit(luma) * 2 - 1);
      const localContrast: number = contrast
        * (1 + layer.clarity / 100 * clarityWeight * 0.38);
      red = (red - 0.5) * localContrast + 0.5;
      green = (green - 0.5) * localContrast + 0.5;
      blue = (blue - 0.5) * localContrast + 0.5;
      luma = red * 0.2126 + green * 0.7152 + blue * 0.0722;
      local[offset] = this.editorChannel(
        (luma + (red - luma) * saturation) * 255
      );
      local[offset + 1] = this.editorChannel(
        (luma + (green - luma) * saturation) * 255
      );
      local[offset + 2] = this.editorChannel(
        (luma + (blue - luma) * saturation) * 255
      );
    }
    const mask: Uint8Array = this.buildEditorMask(
      width,
      height,
      original,
      layer
    );
    const intensity: number = Math.max(
      0,
      Math.min(1, layer.amount / 100)
    );
    for (let offset: number = 0; offset < pixels.length; offset += 4) {
      const coverage: number = mask[offset / 4] / 255;
      const amount: number = (
        layer.invert ? 1 - coverage : coverage
      ) * intensity;
      for (let channel: number = 0; channel < 3; channel++) {
        pixels[offset + channel] = this.editorChannel(
          original[offset + channel]
            + (local[offset + channel] - original[offset + channel])
            * amount
        );
      }
    }
  }

  private buildEditorMask(
    width: number,
    height: number,
    sourcePixels: Uint8Array,
    layer: EditorMaskLayer
  ): Uint8Array {
    const mask = new Uint8Array(Math.max(1, width * height));
    if (layer.type !== '画笔') {
      for (let index: number = 0; index < mask.length; index++) {
        const offset: number = index * 4;
        const coverage: number = this.smartEditorMaskCoverage(
          layer.type,
          sourcePixels[offset] / 255,
          sourcePixels[offset + 1] / 255,
          sourcePixels[offset + 2] / 255,
          index % width,
          Math.floor(index / width),
          width,
          height
        );
        mask[index] = Math.max(
          0,
          Math.min(255, Math.round(coverage * 255))
        );
      }
    }
    layer.strokes.forEach((stroke: EditorMaskStroke): void => {
      if (stroke.points.length === 0) return;
      let previous: EditorMaskPoint = stroke.points[0];
      this.stampEditorMask(mask, width, height, previous, stroke, layer.feather);
      stroke.points.slice(1).forEach((current: EditorMaskPoint): void => {
        const deltaX: number = (current.x - previous.x) * width;
        const deltaY: number = (current.y - previous.y) * height;
        const radius: number = Math.max(
          1,
          stroke.size / 200 * Math.min(width, height)
        );
        const steps: number = Math.max(
          1,
          Math.ceil(
            Math.sqrt(deltaX * deltaX + deltaY * deltaY)
              / Math.max(1, radius * 0.45)
          )
        );
        for (let step: number = 1; step <= steps; step++) {
          const progress: number = step / steps;
          this.stampEditorMask(
            mask,
            width,
            height,
            new EditorMaskPoint(
              previous.x + (current.x - previous.x) * progress,
              previous.y + (current.y - previous.y) * progress
            ),
            stroke,
            layer.feather
          );
        }
        previous = current;
      });
    });
    const blurRadius: number = Math.min(
      24,
      Math.max(
        0,
        Math.round(
          layer.feather / 100 * Math.min(width, height) * 0.015
        )
      )
    );
    if (blurRadius > 0) {
      this.blurEditorMask(mask, width, height, blurRadius);
    }
    return mask;
  }

  private smartEditorMaskCoverage(
    type: string,
    red: number,
    green: number,
    blue: number,
    x: number,
    y: number,
    width: number,
    height: number
  ): number {
    const luma: number = red * 0.2126 + green * 0.7152 + blue * 0.0722;
    const chroma: number = Math.max(red, green, blue)
      - Math.min(red, green, blue);
    const unitX: number = x / Math.max(1, width - 1);
    const unitY: number = y / Math.max(1, height - 1);
    const center: number = 1 - Math.min(
      1,
      Math.sqrt(
        Math.pow((unitX - 0.5) / 0.72, 2)
          + Math.pow((unitY - 0.52) / 0.82, 2)
      )
    );
    const subject: number = this.editorClampUnit(
      center * 0.72 + chroma * 0.72 + Math.abs(luma - 0.5) * 0.18
    );
    if (type === '智能背景') return 1 - subject;
    if (type === '智能天空') {
      const top: number = this.editorClampUnit((0.76 - unitY) / 0.62);
      const skyColor: number = this.editorClampUnit(
        (blue - red * 0.88) * 2.5
          + (blue - green * 0.78) * 1.6 + 0.18
      );
      return top * skyColor * this.editorSmoothStep(0.18, 0.82, luma);
    }
    if (type === '智能人物') {
      const skin: number = this.editorSmoothStep(0.02, 0.20, red - blue)
        * this.editorSmoothStep(-0.05, 0.16, red - green)
        * this.editorSmoothStep(0.16, 0.78, luma);
      return this.editorClampUnit(skin * 0.78 + subject * center * 0.42);
    }
    if (type === '智能亮部') {
      return this.editorSmoothStep(0.55, 0.88, luma);
    }
    if (type === '智能暗部') {
      return 1 - this.editorSmoothStep(0.12, 0.48, luma);
    }
    return subject;
  }

  private blurEditorMask(
    mask: Uint8Array,
    width: number,
    height: number,
    radius: number
  ): void {
    const horizontal: Uint8Array = new Uint8Array(mask.length);
    const divisor: number = radius * 2 + 1;
    for (let y: number = 0; y < height; y++) {
      let sum: number = 0;
      for (let x: number = -radius; x <= radius; x++) {
        sum += mask[y * width + Math.max(0, Math.min(width - 1, x))];
      }
      for (let x: number = 0; x < width; x++) {
        horizontal[y * width + x] = Math.round(sum / divisor);
        const removeX: number = Math.max(0, x - radius);
        const addX: number = Math.min(width - 1, x + radius + 1);
        sum += mask[y * width + addX] - mask[y * width + removeX];
      }
    }
    for (let x: number = 0; x < width; x++) {
      let sum: number = 0;
      for (let y: number = -radius; y <= radius; y++) {
        sum += horizontal[
          Math.max(0, Math.min(height - 1, y)) * width + x
        ];
      }
      for (let y: number = 0; y < height; y++) {
        mask[y * width + x] = Math.round(sum / divisor);
        const removeY: number = Math.max(0, y - radius);
        const addY: number = Math.min(height - 1, y + radius + 1);
        sum += horizontal[addY * width + x]
          - horizontal[removeY * width + x];
      }
    }
  }

  private stampEditorMask(
    mask: Uint8Array,
    width: number,
    height: number,
    point: EditorMaskPoint,
    stroke: EditorMaskStroke,
    feather: number
  ): void {
    const radius: number = Math.max(
      1,
      stroke.size / 200 * Math.min(width, height)
    );
    const softEdge: number = radius
      * Math.max(0, Math.min(100, feather)) / 100;
    const outerRadius: number = radius + softEdge;
    const centerX: number = Math.round(point.x * (width - 1));
    const centerY: number = Math.round(point.y * (height - 1));
    const extent: number = Math.max(1, Math.ceil(outerRadius));
    for (
      let y: number = Math.max(0, centerY - extent);
      y <= Math.min(height - 1, centerY + extent);
      y++
    ) {
      for (
        let x: number = Math.max(0, centerX - extent);
        x <= Math.min(width - 1, centerX + extent);
        x++
      ) {
        const deltaX: number = x - centerX;
        const deltaY: number = y - centerY;
        const distance: number = Math.sqrt(
          deltaX * deltaX + deltaY * deltaY
        );
        if (distance > outerRadius) continue;
        const coverage: number = distance <= radius || softEdge <= 0
          ? 1
          : 1 - (distance - radius) / softEdge;
        const offset: number = y * width + x;
        const value: number = Math.max(
          0,
          Math.min(255, Math.round(coverage * 255))
        );
        mask[offset] = stroke.subtract
          ? Math.max(0, mask[offset] - value)
          : Math.max(mask[offset], value);
      }
    }
  }

  private processEditorDetailPixels(
    pixels: Uint8Array,
    width: number,
    height: number
  ): void {
    const smoothing: number =
      this.editorNoiseReduction / 100 * 0.58
        + Math.max(0, -this.editorTexture) / 100 * 0.24;
    const sharpening: number =
      this.editorSharpening / 100 * 1.15
        + Math.max(0, this.editorTexture) / 100 * 0.48
        + Math.max(0, this.editorClarity) / 100 * 0.25;
    if (smoothing === 0 && sharpening === 0) {
      return;
    }
    const source: Uint8Array = new Uint8Array(pixels);
    for (let y: number = 1; y < height - 1; y++) {
      for (let x: number = 1; x < width - 1; x++) {
        const pixelIndex: number = y * width + x;
        const offset: number = pixelIndex * 4;
        const left: number = offset - 4;
        const right: number = offset + 4;
        const top: number = offset - width * 4;
        const bottom: number = offset + width * 4;
        for (let channel: number = 0; channel < 3; channel++) {
          const centerValue: number = source[offset + channel];
          const average: number = (
            centerValue
              + source[left + channel]
              + source[right + channel]
              + source[top + channel]
              + source[bottom + channel]
          ) / 5;
          const smoothed: number =
            centerValue * (1 - smoothing) + average * smoothing;
          pixels[offset + channel] = this.editorChannel(
            smoothed + (centerValue - average) * sharpening
          );
        }
      }
    }
  }

  private editorCropRatioValue(): number {
    if (this.editorCropRatio === '1:1') {
      return 1;
    }
    if (this.editorCropRatio === '4:3') {
      return 4 / 3;
    }
    if (this.editorCropRatio === '3:2') {
      return 3 / 2;
    }
    if (this.editorCropRatio === '16:9') {
      return 16 / 9;
    }
    return 0;
  }

  private clearEditorRenderedPreview(): void {
    this.editorRenderGeneration++;
    const previous: image.PixelMap | undefined = this.editorRenderedPreview;
    const previousOverlay: image.PixelMap | undefined = this.editorMaskOverlay;
    this.editorRenderedPreview = undefined;
    this.editorMaskOverlay = undefined;
    if (previous !== undefined) {
      setTimeout((): void => {
        previous.release();
      }, 300);
    }
    if (previousOverlay !== undefined) {
      setTimeout((): void => {
        previousOverlay.release();
      }, 300);
    }
  }

  private async refreshEditorRenderedPreview(): Promise<void> {
    if ((
      !this.editorMaskEnabled &&
      this.editorNikonCloudPresetId.length === 0
    ) || this.editorSelectedPath.length === 0) {
      this.clearEditorRenderedPreview();
      return;
    }
    const generation: number = ++this.editorRenderGeneration;
    let source: image.ImageSource | undefined = undefined;
    let pixelMap: image.PixelMap | undefined = undefined;
    let overlayPixelMap: image.PixelMap | undefined = undefined;
    try {
      source = image.createImageSource(`file://${this.editorSelectedPath}`);
      const sourceInfo: image.ImageInfo = await source.getImageInfo();
      const scale: number = Math.min(
        1,
        1200 / Math.max(sourceInfo.size.width, sourceInfo.size.height)
      );
      pixelMap = await source.createPixelMap({
        editable: true,
        desiredSize: {
          width: Math.max(1, Math.round(sourceInfo.size.width * scale)),
          height: Math.max(1, Math.round(sourceInfo.size.height * scale))
        },
        desiredPixelFormat: image.PixelMapFormat.RGBA_8888
      });
      const baseInfo: image.ImageInfo = await pixelMap.getImageInfo();
      const baseBuffer: ArrayBuffer = new ArrayBuffer(
        baseInfo.size.width * baseInfo.size.height * 4
      );
      await pixelMap.readPixelsToBuffer(baseBuffer);
      if (!this.editorShowingOriginal) {
        this.processEditorPixels(
          new Uint8Array(baseBuffer),
          baseInfo.size.width,
          baseInfo.size.height
        );
        await pixelMap.writeBufferToPixels(baseBuffer);
      }
      if (this.editorRotation !== 0) {
        await pixelMap.rotate(this.editorRotation);
      }
      if (this.editorFlipHorizontal || this.editorFlipVertical) {
        await pixelMap.flip(
          this.editorFlipHorizontal,
          this.editorFlipVertical
        );
      }
      const cropRatio: number = this.editorCropRatioValue();
      if (cropRatio > 0) {
        const geometryInfo: image.ImageInfo = await pixelMap.getImageInfo();
        let cropWidth: number = geometryInfo.size.width;
        let cropHeight: number = Math.round(cropWidth / cropRatio);
        if (cropHeight > geometryInfo.size.height) {
          cropHeight = geometryInfo.size.height;
          cropWidth = Math.round(cropHeight * cropRatio);
        }
        await pixelMap.crop({
          x: Math.max(0, Math.floor((geometryInfo.size.width - cropWidth) / 2)),
          y: Math.max(0, Math.floor((geometryInfo.size.height - cropHeight) / 2)),
          size: {
            width: Math.max(1, cropWidth),
            height: Math.max(1, cropHeight)
          }
        });
      }
      const finalInfo: image.ImageInfo = await pixelMap.getImageInfo();
      const finalBuffer: ArrayBuffer = new ArrayBuffer(
        finalInfo.size.width * finalInfo.size.height * 4
      );
      await pixelMap.readPixelsToBuffer(finalBuffer);
      if (!this.editorShowingOriginal) {
        overlayPixelMap = await this.createEditorMaskOverlay(
          new Uint8Array(finalBuffer),
          finalInfo.size.width,
          finalInfo.size.height
        );
        this.processEditorMaskPixels(
          new Uint8Array(finalBuffer),
          finalInfo.size.width,
          finalInfo.size.height
        );
        await pixelMap.writeBufferToPixels(finalBuffer);
      }
      if (generation !== this.editorRenderGeneration) {
        pixelMap.release();
        overlayPixelMap?.release();
        overlayPixelMap = undefined;
        pixelMap = undefined;
        return;
      }
      const previous: image.PixelMap | undefined = this.editorRenderedPreview;
      const previousOverlay: image.PixelMap | undefined = this.editorMaskOverlay;
      this.editorRenderedPreview = pixelMap;
      this.editorMaskOverlay = overlayPixelMap;
      this.editorImageWidth = finalInfo.size.width;
      this.editorImageHeight = finalInfo.size.height;
      pixelMap = undefined;
      overlayPixelMap = undefined;
      if (previous !== undefined) {
        setTimeout((): void => {
          previous.release();
        }, 300);
      }
      if (previousOverlay !== undefined) {
        setTimeout((): void => {
          previousOverlay.release();
        }, 300);
      }
    } catch (_) {
      if (generation === this.editorRenderGeneration) {
        this.status = '蒙版预览生成失败，请重试';
      }
    } finally {
      pixelMap?.release();
      overlayPixelMap?.release();
      source?.release();
    }
  }

  private async saveEditedPhoto(): Promise<void> {
    const library: PhotoLibrary | undefined = this.library;
    const selected: PhotoItem | undefined = this.editablePhotos().find(
      (item: PhotoItem): boolean =>
        item.path === this.editorSelectedPath
    );
    if (library === undefined || selected === undefined) {
      return;
    }
    this.editorSaving = true;
    let source: image.ImageSource | undefined = undefined;
    let pixelMap: image.PixelMap | undefined = undefined;
    let packer: image.ImagePacker | undefined = undefined;
    try {
      source = image.createImageSource(`file://${selected.path}`);
      pixelMap = await source.createPixelMap({
        editable: true,
        desiredPixelFormat: image.PixelMapFormat.RGBA_8888
      });
      const info: image.ImageInfo = await pixelMap.getImageInfo();
      const buffer: ArrayBuffer = new ArrayBuffer(
        info.size.width * info.size.height * 4
      );
      await pixelMap.readPixelsToBuffer(buffer);
      const pixels: Uint8Array = new Uint8Array(buffer);
      this.processEditorPixels(
        pixels,
        info.size.width,
        info.size.height
      );
      await pixelMap.writeBufferToPixels(buffer);
      if (this.editorRotation !== 0) {
        await pixelMap.rotate(this.editorRotation);
      }
      if (this.editorFlipHorizontal || this.editorFlipVertical) {
        await pixelMap.flip(
          this.editorFlipHorizontal,
          this.editorFlipVertical
        );
      }
      const cropRatio: number = this.editorCropRatioValue();
      if (cropRatio > 0) {
        const geometryInfo: image.ImageInfo =
          await pixelMap.getImageInfo();
        let cropWidth: number = geometryInfo.size.width;
        let cropHeight: number = Math.round(cropWidth / cropRatio);
        if (cropHeight > geometryInfo.size.height) {
          cropHeight = geometryInfo.size.height;
          cropWidth = Math.round(cropHeight * cropRatio);
        }
        const region: image.Region = {
          x: Math.max(
            0,
            Math.floor((geometryInfo.size.width - cropWidth) / 2)
          ),
          y: Math.max(
            0,
            Math.floor((geometryInfo.size.height - cropHeight) / 2)
          ),
          size: {
            width: Math.max(1, cropWidth),
            height: Math.max(1, cropHeight)
          }
        };
        await pixelMap.crop(region);
      }
      if (this.editorMaskEnabled) {
        const maskInfo: image.ImageInfo = await pixelMap.getImageInfo();
        const maskBuffer: ArrayBuffer = new ArrayBuffer(
          maskInfo.size.width * maskInfo.size.height * 4
        );
        await pixelMap.readPixelsToBuffer(maskBuffer);
        this.processEditorMaskPixels(
          new Uint8Array(maskBuffer),
          maskInfo.size.width,
          maskInfo.size.height
        );
        await pixelMap.writeBufferToPixels(maskBuffer);
      }
      packer = image.createImagePacker();
      const packed: ArrayBuffer = await packer.packing(pixelMap, {
        format: 'image/jpeg',
        quality: 95
      });
      const destination: string = library.saveEditedCopy(
        selected.name,
        new Uint8Array(packed)
      );
      this.refreshPhotos();
      this.editorSelectedPath = destination;
      this.resetImageEditor();
      this.refreshEditorImageMetrics();
      this.status = `已保存编辑副本 · ${destination.split('/').pop()}`;
    } catch (error) {
      this.showError(
        `保存编辑副本失败：${(error as BusinessError).message}`
      );
    } finally {
      if (packer !== undefined) {
        await packer.release();
      }
      if (pixelMap !== undefined) {
        pixelMap.release();
      }
      source?.release();
      this.editorSaving = false;
    }
  }

  private async previewPhoto(item: PhotoItem): Promise<void> {
    await this.openLargePhoto(item);
  }

  private async openLargePhoto(item: PhotoItem): Promise<void> {
    if (this.library === undefined) {
      return;
    }
    if (item.isVideo) {
      const context: common.UIAbilityContext =
        getContext(this) as common.UIAbilityContext;
      try {
        await context.startAbility({
          action: 'ohos.want.action.viewData',
          uri: `file://${item.path}`,
          type: 'video/*'
        });
      } catch (error) {
        this.showError(
          `无法播放视频：${(error as BusinessError).message}`
        );
      }
      return;
    }
    try {
      const source: image.ImageSource = image.createImageSource(
        this.library.read(item).buffer
      );
      const pixelMap: image.PixelMap = await source.createPixelMap({
        editable: false,
        desiredPixelFormat: image.PixelMapFormat.RGBA_8888
      });
      source.release();
      if (this.largePreview !== undefined) {
        this.largePreview.release();
      }
      this.largePreview = pixelMap;
      this.largePreviewName = item.name;
      this.largePreviewVisible = true;
      this.status = `正在查看 ${item.name}`;
    } catch (error) {
      this.showError(
        '当前格式已安全保存，但系统无法显示这张照片的大图。'
      );
    }
  }

  private closeLargePhoto(): void {
    this.largePreviewVisible = false;
    this.largePreviewName = '';
    if (this.largePreview !== undefined) {
      this.largePreview.release();
      this.largePreview = undefined;
    }
  }

  private async sharePhoto(item: PhotoItem): Promise<void> {
    const context: common.UIAbilityContext =
      getContext(this) as common.UIAbilityContext;
    try {
      const record: systemShare.SharedRecord = {
        utd: item.isVideo ? 'general.video' : 'general.image',
        uri: `file://${item.path}`,
        title: item.name,
        description: '来自 帧澈 ZENCHE 文件库'
      };
      const data: systemShare.SharedData =
        new systemShare.SharedData(record);
      const controller: systemShare.ShareController =
        new systemShare.ShareController(data);
      await controller.show(context, {
        previewMode: systemShare.SharePreviewMode.DETAIL
      });
    } catch (error) {
      this.showError(
        `无法打开系统分享面板：${(error as BusinessError).message}`
      );
    }
  }

  private deletePhoto(item: PhotoItem): void {
    if (this.library === undefined) {
      return;
    }
    try {
      this.library.remove(item);
      this.libraryFileAssignments = this.libraryFileAssignments.filter(
        (assignment: LibraryFileAssignmentData): boolean =>
          assignment.path !== item.path
      );
      this.persistLibraryFileAssignments();
      this.refreshPhotos();
      this.status = `已删除 ${item.name}`;
    } catch (error) {
      this.showError(`无法删除 ${item.name}。`);
    }
  }

  private async displayJpeg(jpeg: Uint8Array): Promise<void> {
    const decodeOpts: image.DecodingOptions = {
      editable: false,
      desiredPixelFormat: image.PixelMapFormat.RGBA_8888
    } as image.DecodingOptions;
    if (this.videoRecording) {
      decodeOpts.desiredSize = { width: 1280, height: 720 };
    }
    const source: image.ImageSource = image.createImageSource(jpeg.buffer);
    const sourceMap: image.PixelMap = await source.createPixelMap(decodeOpts);
    source.release();
    let pixelMap: image.PixelMap = sourceMap;
    const monitoring: boolean =
      this.section === 'monitor' || this.immersiveMonitoring;
    const nikonCloudPreset: NikonCloudPreset | undefined =
      this.selectedMonitorNikonCloudPreset();
    const visualProcessing: boolean =
      this.focusPeakingEnabled || this.falseColorEnabled ||
      nikonCloudPreset !== undefined;
    const analyzeFrame: boolean =
      visualProcessing || this.previewAnalysisSequence++ % (this.videoRecording ? 6 : 3) === 0;
    if ((monitoring || nikonCloudPreset !== undefined) && analyzeFrame) {
      const result: ProfessionalMonitorResult =
        await processProfessionalMonitor(
          sourceMap,
          this.focusPeakingEnabled,
          this.falseColorEnabled,
          nikonCloudPreset
        );
      pixelMap = result.pixelMap;
      this.redHistogram = result.redHistogram;
      this.greenHistogram = result.greenHistogram;
      this.blueHistogram = result.blueHistogram;
      this.waveform = result.waveform;
      this.vectorscope = result.vectorscope;
      this.peakingCoverage = result.peakingCoverage;
      this.drawMonitorRgbScope();
      this.drawProfessionalScope();
      this.drawImmersiveRgbScope();
      this.drawImmersiveAudioScope();
      if (pixelMap !== sourceMap) {
        sourceMap.release();
      }
    }
    const previous: image.PixelMap | undefined = this.preview;
    this.preview = pixelMap;
    if (previous !== undefined) {
      setTimeout((): void => {
        previous.release();
      }, 300);
    }
  }

  private async runBusy(
    status: string,
    operation: () => Promise<void>
  ): Promise<void> {
    this.busy = true;
    this.status = status;
    this.diagnostics?.info('operation', status);
    try {
      await operation();
      this.diagnostics?.info('operation', `操作完成：${status}`);
    } catch (error) {
      this.diagnostics?.error(
        'operation',
        `操作失败：${status}；错误=${(error as BusinessError).message}`
      );
      this.showError((error as BusinessError).message);
    } finally {
      this.busy = false;
    }
  }

  private showError(message: string): void {
    this.diagnostics?.error('ui', message);
    this.status = message;
    promptAction.showToast({
      message: message,
      duration: 4000
    });
  }

  private async reportIssue(): Promise<void> {
    if (this.diagnostics === undefined) {
      this.showError('日志目录暂不可用。');
      return;
    }
    const context: common.UIAbilityContext =
      getContext(this) as common.UIAbilityContext;
    this.diagnostics.info('diagnostics', '用户打开 GitHub Issue 提交页');
    try {
      await context.startAbility({
        action: 'ohos.want.action.viewData',
        uri: this.diagnostics.githubIssueUrl()
      });
    } catch (error) {
      this.showError(
        `无法打开 GitHub Issue 提交页：${(error as BusinessError).message}`
      );
    }
  }

  private async persistAutomaticUpdates(): Promise<void> {
    if (this.settingsPreferences === undefined) {
      return;
    }
    try {
      await this.settingsPreferences.put(
        AUTOMATIC_UPDATE_KEY,
        this.automaticUpdates
      );
      await this.settingsPreferences.flush();
    } catch (error) {
      this.diagnostics?.warning(
        'settings',
        `无法保存自动更新设置：${(error as BusinessError).message}`
      );
    }
  }

  private async saveMirrorChyanCdk(): Promise<void> {
    if (this.settingsPreferences === undefined) {
      return;
    }
    try {
      const cdk: string = this.mirrorChyanCdk.trim();
      if (cdk.length === 0) {
        await this.settingsPreferences.delete(MIRROR_CHYAN_CDK_KEY);
        this.updateStatus = 'Mirror酱 CDK 已清除';
      } else {
        await this.settingsPreferences.put(MIRROR_CHYAN_CDK_KEY, cdk);
        this.updateStatus = 'Mirror酱 CDK 已保存';
      }
      await this.settingsPreferences.flush();
    } catch (error) {
      this.updateStatus = 'Mirror酱 CDK 保存失败';
      this.diagnostics?.error(
        'update',
        `无法保存 Mirror酱 CDK：${(error as BusinessError).message}`
      );
    }
  }

  private async checkForUpdates(silent: boolean): Promise<void> {
    if (this.updateChecking) {
      return;
    }
    this.updateChecking = true;
    if (!silent) {
      this.updateStatus = '正在检查更新…';
    }
    try {
      let candidate: UpdateCandidate;
      try {
        candidate = await this.checkSelfHostedUpdate();
        if (
          this.isNewerVersion(candidate.version, CURRENT_VERSION) &&
          candidate.url.length === 0
        ) {
          const github: UpdateCandidate = await this.checkGitHub();
          candidate = new UpdateCandidate(
            candidate.version,
            github.url,
            candidate.notice
          );
        }
      } catch (selfHostedError) {
        try {
          candidate = await this.checkMirrorChyan();
          if (
            this.isNewerVersion(candidate.version, CURRENT_VERSION) &&
            candidate.url.length === 0
          ) {
            const github: UpdateCandidate = await this.checkGitHub();
            candidate = new UpdateCandidate(
              candidate.version,
              github.url,
              candidate.notice
            );
          }
        } catch (error) {
          const mirrorError: MirrorChyanRequestError =
            error as MirrorChyanRequestError;
          this.diagnostics?.warning(
            'update',
            `Mirror酱检查失败，准备回退 GitHub；code=${mirrorError.code}`
          );
          const github: UpdateCandidate = await this.checkGitHub();
          candidate = new UpdateCandidate(
            github.version,
            github.url,
            this.mirrorFallbackStatus(mirrorError.code)
          );
        }
      }
      if (!this.isNewerVersion(candidate.version, CURRENT_VERSION)) {
        this.availableVersion = '';
        this.availableUpdateUrl = '';
        this.updateStatus = '已是最新版本';
        if (candidate.notice.length > 0) {
          this.updateStatus += ` · ${candidate.notice}`;
        }
        return;
      }

      this.availableVersion = candidate.version;
      this.availableUpdateUrl = candidate.url;
      this.updateStatus = `发现新版本 ${candidate.version}`;
      if (candidate.notice.length > 0) {
        this.updateStatus += ` · ${candidate.notice}`;
      }
      this.diagnostics?.info('update', this.updateStatus);
    } catch (error) {
      if (!silent) {
        this.updateStatus = '检查失败，请确认网络后重试';
      }
      this.diagnostics?.error(
        'update',
        `检查更新失败：${(error as BusinessError).message}`
      );
    } finally {
      this.updateChecking = false;
    }
  }

  private async checkMirrorChyan(): Promise<UpdateCandidate> {
    let endpoint: string =
      `${MIRROR_CHYAN_API}?current_version=${encodeURIComponent(`v${CURRENT_VERSION}`)}`
      + '&user_agent=ZENCHE_HarmonyOS&channel=stable';
    const cdk: string = this.mirrorChyanCdk.trim();
    if (cdk.length > 0) {
      endpoint += `&cdk=${encodeURIComponent(cdk)}`;
    }
    const request: http.HttpRequest = http.createHttp();
    try {
      const response: http.HttpResponse = await request.request(
        endpoint,
        {
          method: http.RequestMethod.GET,
          header: {
            'Accept': 'application/json',
            'User-Agent': `ZENCHE-HarmonyOS/${CURRENT_VERSION}`
          },
          connectTimeout: 20000,
          readTimeout: 20000,
          expectDataType: http.HttpDataType.STRING
        }
      );
      const root: MirrorChyanResponse =
        JSON.parse(response.result as string) as MirrorChyanResponse;
      if (root.code !== 0 || root.data === undefined) {
        throw new MirrorChyanRequestError(root.code, root.msg);
      }
      let url: string = root.data.url ?? '';
      let notice: string = '';
      if ((root.data.update_type ?? '').toLowerCase() === 'incremental') {
        url = '';
        notice =
          'Mirror酱未返回可直接安装的完整包，已回退 GitHub';
      }
      return new UpdateCandidate(
        this.normalizeVersion(root.data.version_name),
        url,
        notice
      );
    } finally {
      request.destroy();
    }
  }

  private async checkSelfHostedUpdate(): Promise<UpdateCandidate> {
    const request: http.HttpRequest = http.createHttp();
    try {
      const endpoint: string =
        `${SELF_HOSTED_UPDATE_ENDPOINT}?platform=harmony&arch=arm64`
        + `&current_version=${encodeURIComponent(CURRENT_VERSION)}`
        + '&channel=stable';
      const response: http.HttpResponse = await request.request(
        endpoint,
        {
          method: http.RequestMethod.GET,
          header: {
            'Accept': 'application/json',
            'User-Agent': `ZENCHE-HarmonyOS/${CURRENT_VERSION}`
          },
          connectTimeout: 20000,
          readTimeout: 20000,
          expectDataType: http.HttpDataType.STRING
        }
      );
      if (response.responseCode < 200 || response.responseCode >= 300) {
        throw new Error(`Self-hosted update HTTP ${response.responseCode}`);
      }
      const root: SelfHostedUpdate =
        JSON.parse(response.result as string) as SelfHostedUpdate;
      if (root.schema_version !== 1 ||
          root.product.toUpperCase() !== 'ZENCHE' ||
          root.version.length === 0) {
        throw new Error('Invalid self-hosted update feed');
      }
      let url: string = root.url ?? root.release_url ?? '';
      if ((root.update_type ?? '').toLowerCase() === 'incremental') {
        url = '';
      }
      let notice: string = '';
      if (root.announcement !== undefined) {
        const title: string = (root.announcement.title ?? '').trim();
        const body: string = (root.announcement.body ?? '').trim();
        notice = title.length === 0 ? body
          : (body.length === 0 ? title : `${title}：${body}`);
      }
      return new UpdateCandidate(
        this.normalizeVersion(root.version),
        url,
        notice
      );
    } finally {
      request.destroy();
    }
  }

  private async checkGitHub(): Promise<UpdateCandidate> {
    const request: http.HttpRequest = http.createHttp();
    try {
      const response: http.HttpResponse = await request.request(
        LATEST_RELEASE_API,
        {
          method: http.RequestMethod.GET,
          header: {
            'Accept': 'application/vnd.github+json',
            'User-Agent': `ZENCHE-HarmonyOS/${CURRENT_VERSION}`
          },
          connectTimeout: 20000,
          readTimeout: 20000,
          expectDataType: http.HttpDataType.STRING
        }
      );
      if (response.responseCode < 200 || response.responseCode >= 300) {
        throw new Error(`GitHub HTTP ${response.responseCode}`);
      }
      const release: GitHubRelease =
        JSON.parse(response.result as string) as GitHubRelease;
      let targetUrl: string = release.html_url;
      for (const asset of release.assets) {
        if (asset.name.endsWith('-HarmonyOS.hap')) {
          targetUrl = asset.browser_download_url;
          break;
        }
      }
      return new UpdateCandidate(
        this.normalizeVersion(release.tag_name),
        targetUrl
      );
    } finally {
      request.destroy();
    }
  }

  private mirrorFallbackStatus(code: number): string {
    switch (code) {
      case 7001:
        return 'Mirror酱 CDK 已过期，已回退 GitHub';
      case 7002:
        return 'Mirror酱 CDK 无效，已回退 GitHub';
      case 7003:
        return 'Mirror酱今日下载额度已用完，已回退 GitHub';
      case 7004:
        return 'Mirror酱 CDK 与资源不匹配，已回退 GitHub';
      case 7005:
        return 'Mirror酱 CDK 已被停用，已回退 GitHub';
      case 8001:
        return 'Mirror酱资源尚未配置，已回退 GitHub';
      default:
        return 'Mirror酱暂不可用，已回退 GitHub';
    }
  }

  private async openUpdate(): Promise<void> {
    const context: common.UIAbilityContext =
      getContext(this) as common.UIAbilityContext;
    try {
      await context.startAbility({
        action: 'ohos.want.action.viewData',
        uri:
          this.availableUpdateUrl.length > 0
            ? this.availableUpdateUrl
            : RELEASES_URL
      });
    } catch (error) {
      this.showError(
        `无法打开更新页：${(error as BusinessError).message}`
      );
    }
  }

  private async openMirrorChyan(): Promise<void> {
    const context: common.UIAbilityContext =
      getContext(this) as common.UIAbilityContext;
    const url: string =
      'https://mirrorchyan.com/zh/projects'
      + `?rid=${encodeURIComponent(MIRROR_CHYAN_RESOURCE_ID)}`
      + '&source=zenche_harmonyos_settings';
    try {
      await context.startAbility({
        action: 'ohos.want.action.viewData',
        uri: url
      });
    } catch (error) {
      this.showError(
        `无法打开 Mirror酱：${(error as BusinessError).message}`
      );
    }
  }

  private async openAfdian(): Promise<void> {
    const context: common.UIAbilityContext =
      getContext(this) as common.UIAbilityContext;
    try {
      await context.startAbility({
        action: 'ohos.want.action.viewData',
        uri: AFDIAN_URL
      });
    } catch (error) {
      this.showError(
        `无法打开爱发电页面：${(error as BusinessError).message}`
      );
    }
  }

  private normalizeVersion(value: string): string {
    if (value.startsWith('v') || value.startsWith('V')) {
      return value.substring(1);
    }
    return value;
  }

  private isNewerVersion(candidate: string, current: string): boolean {
    const left: Array<string> = candidate.split(/[.-]/);
    const right: Array<string> = current.split(/[.-]/);
    const count: number = Math.max(left.length, right.length);
    for (let index: number = 0; index < count; index++) {
      const candidatePart: number = this.versionPart(left, index);
      const currentPart: number = this.versionPart(right, index);
      if (candidatePart !== currentPart) {
        return candidatePart > currentPart;
      }
    }
    return false;
  }

  private versionPart(parts: Array<string>, index: number): number {
    if (index >= parts.length) {
      return 0;
    }
    const match: RegExpMatchArray | null = parts[index].match(/^\d+/);
    return match === null ? 0 : Number(match[0]);
  }

  private openDonation(): void {
    this.donationVisible = true;
  }
}
