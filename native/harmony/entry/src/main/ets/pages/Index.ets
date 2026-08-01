import {
  abilityAccessCtrl,
  common,
  Permissions
} from '@kit.AbilityKit';
import { dataSharePredicates, preferences } from '@kit.ArkData';
import { fileIo as fs, picker } from '@kit.CoreFileKit';
import { util } from '@kit.ArkTS';
import { image } from '@kit.ImageKit';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { promptAction } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';
import { deviceInfo } from '@kit.BasicServicesKit';
import { http } from '@kit.NetworkKit';
import { systemShare } from '@kit.ShareKit';
import { sensor } from '@kit.SensorServiceKit';
import { CameraProfile } from '../camera/CameraProfiles';
import { PtpCamera } from '../camera/PtpCamera';
import { PhotoItem, PhotoLibrary } from '../storage/PhotoLibrary';
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
  LANGUAGE_ENGLISH,
  LANGUAGE_JAPANESE,
  LANGUAGE_PREFERENCE_KEY,
  LANGUAGE_SIMPLIFIED_CHINESE,
  normalizeLanguage,
  translate
} from '../localization/Localization';

class SelectEntry {
  readonly label: string;
  readonly value: string;

  constructor(label: string, value: string) {
    this.label = label;
    this.value = value;
  }
}

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

const CURRENT_VERSION: string = '1.3.0';
const MIRROR_CHYAN_RESOURCE_ID: string = 'ZENCHE';
const MIRROR_CHYAN_API: string =
  `https://mirrorchyan.com/api/resources/${MIRROR_CHYAN_RESOURCE_ID}/latest`;
const LATEST_RELEASE_API: string =
  'https://api.github.com/repos/Tauber01/ZENCHE/releases/latest';
const RELEASES_URL: string =
  'https://github.com/Tauber01/ZENCHE/releases';
const AFDIAN_URL: string =
  'https://www.ifdian.net/a/Tauber';
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
  private library?: PhotoLibrary;
  private captureWorkflow?: CaptureWorkflow;
  private wireless?: WirelessTransferServer;
  private diagnostics?: DiagnosticLogger;
  private settingsPreferences?: preferences.Preferences;
  private previewGeneration: number = 0;
  private previewAnalysisSequence: number = 0;

  @State private section: string = 'capture';
  @State private language: string = LANGUAGE_SIMPLIFIED_CHINESE;
  @State private connected: boolean = false;
  @State private liveView: boolean = false;
  @State private busy: boolean = false;
  @State private cameraName: string = '未连接';
  @State private status: string = '就绪';
  @State private preview: image.PixelMap | undefined = undefined;
  @State private photos: Array<PhotoItem> = [];
  @State private wirelessRunning: boolean = false;
  @State private wirelessStatus: string = '无线收件箱未开启';
  @State private wirelessAddress: string = '—';
  @State private exposureMode: string = 'manual';
  @State private videoFrameRate: number = 30;
  @State private videoShutterAngle: number = 180;
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
  @State private sessionName: string = '未命名会话';
  @State private sessionNamingTemplate: string =
    '{session}_{date}_{counter}';
  @State private sessionCreator: string = '';
  @State private sessionRights: string = '';
  @State private sessionRating: number = 0;
  @State private sessionDualBackup: boolean = true;
  @State private videoRecording: boolean = false;
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
  @State private systemPhotosExpanded: boolean = true;
  @State private systemVideosExpanded: boolean = true;
  @State private wirelessExpanded: boolean = false;
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
  @State private editorPanel: string = 'light';
  @State private editorPreset: string = 'original';
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
  @State private editorRotation: number = 0;
  @State private editorFlipHorizontal: boolean = false;
  @State private editorFlipVertical: boolean = false;
  @State private editorCropRatio: string = 'original';
  @State private editorShowingOriginal: boolean = false;
  @State private editorSaving: boolean = false;
  @State private aiPrompt: string = '';
  @State private aiMode: number = 0; // 0=edit, 1=generate
  @State private aiRatioIndex: number = 0;
  @State private aiResolutionIndex: number = 0;
  @State private aiResultPath: string = '';
  @State private aiGenerating: boolean = false;
  @State private aiStatus: string = '';
  @State private editorTabMode: string = 'pro'; // 'pro' | 'ai'
  @State private aiActivationInput: string = '';
  @State private aiServerInput: string = '';
  @State private aiActivationMsg: string = '';
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
    this.camera.disconnect();
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
        this.TopBar()
        if (this.isCompact()) {
          Scroll() {
            this.MainGrid()
          }
          .width('100%')
          .layoutWeight(1)
          .scrollBar(BarState.Auto)
        } else {
          this.MainGrid()
        }
        this.StatusBar()
      }
      .width('100%')
      .height('100%')
      .backgroundColor($r('app.color.paper'))
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
      if (this.showSplash) {
        this.SplashOverlay()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.paper'))
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
        .backgroundColor($r('app.color.graphite'))
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
      GridCol({ span: { xs: 4, sm: 4, md: 8, lg: 2 } }) {
        this.NavigationRail()
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
    .backgroundColor($r('app.color.paper'))
    .onBreakpointChange((breakpoint: string): void => {
      this.currentBreakpoint = breakpoint;
    })
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
        .width(44)
        .height(44)
        .justifyContent(FlexAlign.Center)
        .backgroundColor($r('app.color.graphite'))
        .borderRadius(13)
        .shadow({
          radius: 8,
          color: '#24055AD2',
          offsetX: 0,
          offsetY: 4
        })
        Column({ space: 3 }) {
          Text('帧澈 ZENCHE')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.ink'))
          Text('Capture · Connect · Flow')
            .fontSize(10)
            .fontFamily('monospace')
            .fontColor($r('app.color.muted'))
          Text(
            this.connected
              ? `${this.cameraName} · USB/PTP`
              : `${this.tr('未连接')} · HARMONYOS USB/PTP`
          )
            .fontSize(10)
            .fontFamily('monospace')
            .fontColor($r('app.color.muted'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
      }
      .alignItems(VerticalAlign.Center)
      .layoutWeight(1)
      Button(
        this.isCompact()
          ? this.tr(this.connected ? '断开' : '连接')
          : this.tr(this.connected ? '断开相机' : '连接相机'),
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
          this.toggleCameraConnection();
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
    .height(76)
    .padding({ left: 20, right: 20 })
    .backgroundColor($r('app.color.surface_raised'))
    .border({
      width: { bottom: 1 },
      color: $r('app.color.rule')
    })
    .shadow({
      radius: 14,
      color: '#14050B18',
      offsetX: 0,
      offsetY: 4
    })
  }

  @Builder
  private NavigationRail() {
    if (this.isCompact()) {
      Scroll() {
        Row({ space: 8 }) {
          this.NavButton('照片拍摄', 'capture')
          this.NavButton('视频监看', 'monitor')
          this.NavButton('图像编辑', 'editor')
          this.NavButton('分支文件库', 'library')
        }
        .padding({ left: 16, right: 16 })
      }
      .width('100%')
      .height(60)
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
      .backgroundColor($r('app.color.paper_2'))
      .border({
        width: { bottom: 1 },
        color: $r('app.color.rule')
      })
    } else {
      Column({ space: 8 }) {
        Text(this.tr('工作区'))
          .fontSize(11)
          .fontFamily('monospace')
          .fontColor($r('app.color.muted'))
          .width('100%')
          .margin({ bottom: 8 })
        this.NavButton('照片拍摄', 'capture')
        this.NavButton('视频监看', 'monitor')
        this.NavButton('图像编辑', 'editor')
        this.NavButton('分支文件库', 'library')
        Blank()
        Text('ZENCHE 1.3.0')
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
  }

  @Builder
  private NavButton(label: string, target: string) {
    Button(this.tr(label), { type: ButtonType.Normal })
      .width(this.isCompact() ? 104 : '100%')
      .height(44)
      .fontSize(14)
      .fontWeight(
        this.section === target ? FontWeight.Bold : FontWeight.Normal
      )
      .fontColor(
        this.section === target
          ? target === 'monitor'
            ? $r('app.color.video')
            : $r('app.color.accent')
          : $r('app.color.muted')
      )
      .backgroundColor(
        this.section === target
          ? target === 'monitor'
            ? $r('app.color.video_soft')
            : $r('app.color.surface_raised')
          : Color.Transparent
      )
      .border({
        width: this.section === target ? 1 : 0,
        color: target === 'monitor'
          ? $r('app.color.video')
          : $r('app.color.accent'),
        radius: 12
      })
      .borderRadius(12)
      .flexShrink(0)
      .onClick((): void => {
        if (target === 'editor') {
          this.editorTabMode = this.editorTabMode === 'pro' ? 'ai' : 'pro';
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
  private ImageEditorWorkspace() {
    if (this.editorTabMode === 'ai') {
      this.AiToolsWorkspace();
    } else {
      this.ProEditorWorkspace();
    }
  }

  @Builder
  private ProEditorWorkspace() {
    Column({ space: 16 }) {
      Text(this.tr('专业显影'))
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.ink'))
        .width('100%')
      Text(this.tr(
        '分组调整光线、色彩、细节、效果与几何；始终保留原文件。'
      ))
        .fontSize(14)
        .fontColor($r('app.color.muted'))
        .width('100%')
      if (this.editablePhotos().length === 0) {
        Column({ space: 8 }) {
          Text(this.tr('文件库中没有可编辑照片'))
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.ink'))
          Text(this.tr(
            '视频与暂不支持解码的 RAW 文件不会进入编辑列表。'
          ))
            .fontSize(13)
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
        Select(
          this.editablePhotos().map((item: PhotoItem): SelectEntry => {
            return new SelectEntry(item.name, item.name);
          })
        )
          .selected(this.editorSelectedIndex())
          .width('100%')
          .onSelect((index: number): void => {
            this.editorSelectedPath = this.editablePhotos()[index].path;
            this.resetImageEditor();
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
        Stack({ alignContent: Alignment.Center }) {
          if (this.editorSelectedPath.length > 0) {
            Image(`file://${this.editorSelectedPath}`)
              .width('100%')
              .height('100%')
              .objectFit(ImageFit.Contain)
              .brightness(
                this.editorShowingOriginal
                  ? 1
                  : Math.pow(2, this.editorExposure / 100)
              )
              .contrast(
                this.editorShowingOriginal
                  ? 1
                  : Math.max(
                    0,
                    1 + this.editorContrast / 100
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
          Text(this.tr(
            this.editorShowingOriginal ? '原图' : '调整后'
          ))
            .fontSize(11)
            .fontWeight(FontWeight.Bold)
            .fontColor(Color.White)
            .padding({ left: 10, right: 10, top: 7, bottom: 7 })
            .backgroundColor($r('app.color.graphite'))
            .borderRadius(14)
            .position({ x: 12, y: 12 })
        }
        .width('100%')
        .height(this.isCompact() ? 320 : 460)
        .padding(12)
        .backgroundColor($r('app.color.graphite'))
        .borderRadius(14)

        Scroll() {
          Row({ space: 8 }) {
            this.EditorPanelButton('光线', 'light')
            this.EditorPanelButton('色彩', 'color')
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
  private EditorPanelButton(label: string, panel: string) {
    Button(this.tr(label), { type: ButtonType.Normal })
      .height(44)
      .fontSize(13)
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
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.ink'))
        .width('100%')
      Text(this.tr('基于 nano-banana-2 模型的 AI 修图与生图；需在设置中配置 API Key。'))
        .fontSize(14)
        .fontColor($r('app.color.muted'))
        .width('100%')

      Row({ space: 8 }) {
        Button(this.aiMode === 0 ? '● AI 修图' : '○ AI 修图', { type: ButtonType.Normal })
          .height(44)
          .layoutWeight(1)
          .fontColor(this.aiMode === 0 ? $r('app.color.accent_ink') : $r('app.color.ink'))
          .backgroundColor(this.aiMode === 0 ? $r('app.color.accent') : $r('app.color.surface'))
          .onClick((): void => {
            this.aiMode = 0;
            this.aiResultPath = '';
          })
        Button(this.aiMode === 1 ? '● AI 生图' : '○ AI 生图', { type: ButtonType.Normal })
          .height(44)
          .layoutWeight(1)
          .fontColor(this.aiMode === 1 ? $r('app.color.accent_ink') : $r('app.color.ink'))
          .backgroundColor(this.aiMode === 1 ? $r('app.color.accent') : $r('app.color.surface'))
          .onClick((): void => {
            this.aiMode = 1;
            this.aiResultPath = '';
          })
      }
      .width('100%')

      Text('快捷预设')
        .fontSize(12)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.muted'))
        .width('100%')
      Scroll() {
        Row({ space: 6 }) {
          ForEach(this.getAiPresets(), (preset: Array<string>) => {
            Button(preset[0], { type: ButtonType.Normal })
              .height(32)
              .fontSize(11)
              .fontColor($r('app.color.ink'))
              .backgroundColor($r('app.color.surface'))
              .borderRadius(16)
              .padding({ left: 12, right: 12 })
              .onClick((): void => {
                this.aiPrompt = preset[1];
              })
          }, (preset: Array<string>) => preset[0])
        }
      }
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
      .width('100%')

      TextArea({ placeholder: this.aiMode === 0 ? '输入修图描述…' : '输入生图描述…' })
        .height(80)
        .fontSize(14)
        .onChange((value: string): void => {
          this.aiPrompt = value;
        })

      Button(this.aiGenerating ? '正在生成…' : '生成', { type: ButtonType.Normal })
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
          .fontSize(11)
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
            body['image'] = `data:image/jpeg;base64,${b64}`;
          }
        }
      }
      const response = await httpRequest.request(
        endpoint,
        {
          method: http.RequestMethod.POST,
          header: {
            'Content-Type': 'application/json',
          },
          extraData: body,
          connectTimeout: 15000,
          readTimeout: 60000,
        }
      );
      httpRequest.destroy();
      if (response.responseCode === 403) {
        this.aiGenerating = false;
        this.aiStatus = '激活码无效或次数用完';
        return;
      }
      if (response.responseCode === 502) {
        this.aiGenerating = false;
        this.aiStatus = 'AI 服务暂时不可用';
        return;
      }
      if (response.responseCode !== 200) {
        throw new Error(`AI 服务返回错误 ${response.responseCode}`);
      }
      const result: Record<string, Object> = JSON.parse(
        (response.result as string)
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
      const msg: string = (err as Error).message || 'AI 生成失败';
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
      const destination: string = library.saveEditedCopy(
        `ai_${stem}`,
        new Uint8Array(data)
      );
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
      return activated;
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
      id = deviceInfo.udid || deviceInfo.serial || '';
      if (id.length === 0) {
        id = util.generateRandomUUID();
      }
      prefs.putSync('ai_device_id', id);
      prefs.flushSync();
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

  private verifyActivationCode(code: string): boolean {
    const trimmed: string = code.trim();
    if (trimmed.length === 0) {
      return false;
    }
    const parts: Array<string> = trimmed.split('-');
    if (parts.length < 4 || parts[0] !== 'ZENCHE' || parts[1] !== 'AI') {
      return false;
    }
    const expiryPart: string = parts[parts.length - 1];
    const expiryYear: number = parseInt(expiryPart.substring(0, 4));
    const expiryMonth: number = parseInt(expiryPart.substring(4, 6));
    const expiryDay: number = parseInt(expiryPart.substring(6, 8));
    const now: Date = new Date();
    const expiryDate: Date = new Date(expiryYear, expiryMonth - 1, expiryDay);
    if (expiryDate < now) {
      return false;
    }
    const deviceId: string = this.getDeviceId();
    const payload: string = `${deviceId}:${expiryPart}:a1b2c3d4e5f6`;
    // HarmonyOS doesn't export the full SubtleCrypto API, so signature
    // verification is deferred to the server or skipped for now.
    // In production, send (code, deviceId) to a simple HTTP endpoint
    // that verifies the signature on your side.
    const prefs = preferences.getPreferencesSync(
      getContext(this) as common.UIAbilityContext,
      { name: 'zenche_ai_settings' }
    );
    prefs.putSync('ai_activated', true);
    prefs.putSync('ai_activation_code', trimmed);
    prefs.putSync('ai_usage_count', 0);
    prefs.putSync('ai_device_id', deviceId);
    prefs.flushSync();
    return true;
  }

  private doAiActivate(): void {
    const code: string = this.aiActivationInput.trim();
    if (code.length === 0) {
      this.aiActivationMsg = '请输入激活码';
      return;
    }
    // 保存服务器地址
    const serverUrl: string = this.aiServerInput.trim();
    if (serverUrl.length > 0) {
      try {
        const prefs = preferences.getPreferencesSync(
          getContext(this) as common.UIAbilityContext,
          { name: 'zenche_ai_settings' }
        );
        prefs.putSync('ai_server_url', serverUrl);
        prefs.flushSync();
      } catch (_) {}
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
          .fontSize(12)
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
          })
        Row({ space: 8 }) {
          Button(this.tr('旋转 90°'), { type: ButtonType.Normal })
            .height(48)
            .layoutWeight(1)
            .onClick((): void => {
              this.editorRotation = (this.editorRotation + 90) % 360;
            })
          Button(this.tr('水平翻转'), { type: ButtonType.Normal })
            .height(48)
            .layoutWeight(1)
            .onClick((): void => {
              this.editorFlipHorizontal =
                !this.editorFlipHorizontal;
            })
          Button(this.tr('垂直翻转'), { type: ButtonType.Normal })
            .height(48)
            .layoutWeight(1)
            .onClick((): void => {
              this.editorFlipVertical = !this.editorFlipVertical;
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
        .fontSize(12)
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
        })
    }
    .width('100%')
    .constraintSize({ minHeight: 52 })
  }

  @Builder
  private CameraWorkspace() {
    Column({ space: 16 }) {
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
        Button(this.tr('全屏'), { type: ButtonType.Normal })
          .height(44)
          .fontColor(Color.White)
          .backgroundColor('#99000000')
          .borderRadius(12)
          .align(Alignment.TopEnd)
          .margin(16)
          .onClick((): void => {
            this.openImmersivePreview(this.section === 'monitor');
          })
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

      Row({ space: 8 }) {
        Text(this.tr(
          this.section === 'monitor'
            ? '相机原生 JPEG · 监看输出 · 不修改原片'
            : '相机原生 JPEG · 本地预览'
        ))
          .fontSize(12)
          .fontColor($r('app.color.muted'))
          .layoutWeight(1)
        Button(this.tr(this.liveView ? '停止取景' : '开启取景'), {
          type: ButtonType.Normal
        })
          .height(44)
          .fontColor($r('app.color.ink'))
          .backgroundColor($r('app.color.surface'))
          .border({
            width: 1,
            color: $r('app.color.rule_strong'),
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
          .fontColor($r('app.color.accent_ink'))
          .backgroundColor(
            this.section === 'monitor'
              ? $r('app.color.video')
              : $r('app.color.accent')
          )
          .borderRadius(12)
          .enabled(this.connected && !this.busy)
          .onClick((): void => {
            if (this.section === 'monitor') {
              this.toggleVideoRecording();
            } else {
              this.capturePhoto();
            }
          })
      }
      .width('100%')
      if (this.section === 'capture') {
        this.ShootingTaskPanel()
      }
    }
    .width('100%')
    .height(this.isCompact() ? 'auto' : '100%')
    .padding(16)
  }

  @Builder
  private ShootingTaskPanel() {
    Column({ space: 10 }) {
      Text(this.tr('拍摄任务'))
        .fontSize(17)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.ink'))
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
        .fontSize(12)
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
        .fontSize(12)
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
          .fontSize(12)
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
        .fontSize(11)
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
        .fontSize(24)
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
        .fontSize(12)
        .fontColor($r('app.color.muted'))
        .width('100%')
      this.CaptureSessionPanel()
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
            .fontSize(12)
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
                        .backgroundColor('#99000000')
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
                    .fontSize(11)
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
          .fontSize(11)
          .fontColor($r('app.color.muted'))
          .width('100%')
      }
      Button(
        this.tr(`${this.wirelessExpanded ? '⌄' : '›'} 无线传输`),
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
    }
    .width('100%')
    .height(this.isCompact() ? 'auto' : '100%')
    .padding(16)
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
          .fontSize(15)
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
            .fontSize(12)
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
            .fontSize(12)
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
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.ink'))
          .layoutWeight(1)
        Text(this.tr(`${this.userLibraryBranches.length} 个根节点`))
          .fontSize(11)
          .fontFamily('monospace')
          .fontColor($r('app.color.muted'))
      }
      .width('100%')
      if (this.userLibraryBranches.length === 0) {
        Text(this.tr('可建立项目、客户或拍摄日等分支；媒体仍保留在原始存储位置。'))
          .fontSize(12)
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
          .fontSize(11)
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
            .fontSize(12)
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
      Text(this.tr('拍摄会话'))
        .fontSize(17)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.ink'))
        .width('100%')
      TextInput({
        placeholder: this.tr('项目名称'),
        text: this.sessionName
      })
        .height(42)
        .onChange((value: string): void => {
          this.sessionName = value;
        })
      TextInput({
        placeholder: this.tr('命名模板'),
        text: this.sessionNamingTemplate
      })
        .height(42)
        .fontFamily('monospace')
        .onChange((value: string): void => {
          this.sessionNamingTemplate = value;
        })
      Row({ space: 8 }) {
        TextInput({
          placeholder: this.tr('创作者'),
          text: this.sessionCreator
        })
          .height(42)
          .layoutWeight(1)
          .onChange((value: string): void => {
            this.sessionCreator = value;
          })
        TextInput({
          placeholder: this.tr('版权'),
          text: this.sessionRights
        })
          .height(42)
          .layoutWeight(1)
          .onChange((value: string): void => {
            this.sessionRights = value;
          })
      }
      .width('100%')
      Text(`${this.tr('默认评级')} · ${this.sessionRating} ★`)
        .fontSize(12)
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
        .fontSize(11)
        .fontColor($r('app.color.muted'))
        .width('100%')
      Text(this.tr(
        this.captureWorkflow?.status ?? '尚未开始拍摄会话'
      ))
        .fontSize(11)
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
  private WirelessTransferCard() {
    Column({ space: 12 }) {
        Text(this.tr('多协议无线图片收件箱'))
            .fontSize(17)
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
            .fontSize(12)
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
  private LargePhotoOverlay() {
    Column({ space: 12 }) {
      Row({ space: 8 }) {
        Button(this.tr('关闭'), { type: ButtonType.Normal })
          .height(44)
          .fontColor(Color.White)
          .backgroundColor('#66000000')
          .borderRadius(8)
          .onClick((): void => {
            this.closeLargePhoto();
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
        .fontSize(12)
        .fontFamily('monospace')
        .fontColor(Color.White)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%')
    .height('100%')
    .padding(20)
    .backgroundColor('#F2080A0F')
  }

  @Builder
  private CloudDriveGuideOverlay() {
    Column({ space: 14 }) {
      Row() {
        Column({ space: 3 }) {
          Text(this.tr('链接网盘'))
            .fontSize(24)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.ink'))
          Text(this.tr('账号和密码始终由网盘客户端管理。'))
            .fontSize(12)
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
                    .fontSize(24)
                    .fontColor($r('app.color.accent'))
                    .width(42)
                  Column({ space: 3 }) {
                    Text(this.tr(provider.name))
                      .fontSize(15)
                      .fontWeight(FontWeight.Bold)
                      .fontColor($r('app.color.ink'))
                      .width('100%')
                    Text(this.tr(provider.note))
                      .fontSize(12)
                      .fontColor($r('app.color.muted'))
                      .width('100%')
                  }
                  .alignItems(HorizontalAlign.Start)
                  .layoutWeight(1)
                  Text('↗')
                    .fontSize(18)
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
        .fontSize(12)
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
      color: '#55000000',
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
        color: '#55000000',
        offsetX: 0,
        offsetY: 10
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#66000000')
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
        color: '#55000000',
        offsetX: 0,
        offsetY: 10
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#66000000')
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
            .height(42)
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
                .fontSize(17)
                .fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.ink'))
                .width('100%')
              Text(this.tr(
                '• 新增 AI 修图与生图工具，内置一键美颜等快捷预设，激活码解锁后即可使用。\n' +
                '• 新增树状分支文件库，支持嵌套分支、拖拽归类与持久化组织。\n' +
                '• 新增专业非破坏性修图工具，提供光影 / 色彩 / 细节 / 效果 / 几何五组参数与透明预设。\n' +
                '• 新增可展开的全屏二级相机参数面板，移动端保持紧凑触控区域。\n' +
                '• USB/PTP 连接可靠性大幅提升：瞬时错误自动重试、HONOR 设备同步降级传输。\n' +
                '• 新增对 Nikon D500、D7500、D850（EXPEED 5）的 USB/PTP 控制支持。\n• 视频录制监看延迟优化：子采样解码、管道重叠取帧、智能跳帧分析。'
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
                .fontColor('#B21923')
                .width('100%')
              Text(this.tr(
                '帧澈 ZENCHE 是开源免费项目。任何声称“进群领取软件”' +
                '或要求付费购买软件的人都是骗子，请勿转账。'
              ))
                .fontSize(14)
                .fontWeight(FontWeight.Medium)
                .fontColor('#75141C')
                .width('100%')
            }
            .width('100%')
            .padding(16)
            .alignItems(HorizontalAlign.Start)
            .backgroundColor('#FFFFEEEE')
            .border({
              width: 1,
              color: '#FFF4B9B9',
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
        color: '#55000000',
        offsetX: 0,
        offsetY: 10
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#88000000')
  }

  @Builder
  private FastFeedbackCard() {
    Column({ space: 10 }) {
      Row({ space: 10 }) {
        Text('⚡')
          .fontSize(19)
        Column({ space: 4 }) {
          Text(this.tr('快速问题反馈'))
            .fontSize(15)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.ink'))
            .width('100%')
          Text(this.tr(
            '公开问题可继续在 GitHub 免费提交；在爱发电赞助后，可获取快速问题反馈渠道。'
          ))
            .fontSize(12)
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
        .height(42)
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
      color: '#FFB6CFF5',
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
            .height(40)
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
          .fontSize(11)
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
          .fontSize(11)
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
        color: '#55000000',
        offsetX: 0,
        offsetY: 10
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#88000000')
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
            .fontSize(24)
            .fontWeight(FontWeight.Bold)
            .fontColor(Color.White)
          Text(this.tr('连接相机并开启实时取景后即可全屏监看。'))
            .fontSize(13)
            .fontColor('#99FFFFFF')
        }
      }
      Row()
        .width(82)
        .height(82)
        .border({
          width: 2,
          color: '#DDFFD646',
          radius: 4
        })
      Column() {
        Row({ space: 10 }) {
          Button(`⌄ ${this.tr('退出全屏')}`, { type: ButtonType.Normal })
            .height(44)
            .fontColor(Color.White)
            .backgroundColor('#99000000')
            .borderRadius(10)
            .onClick((): void => {
              this.closeImmersivePreview();
            })
          Text(
            `${this.liveView ? '● LIVE' : '● NO SOURCE'} · ` +
            `${this.cameraName} · USB/PTP`
          )
            .fontSize(11)
            .fontFamily('monospace')
            .fontColor(Color.White)
            .backgroundColor('#99000000')
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
          this.immersiveMonitoring
            ? `${this.videoShutterAngle.toFixed(1)}°   ` +
              `${this.videoFrameRate} fps   JPEG`
            : `${this.exposureMode.toUpperCase()}   JPEG   帧澈 ZENCHE`
        )
          .fontSize(13)
          .fontFamily('monospace')
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.White)
          .backgroundColor('#99000000')
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
      this.ImmersiveParameterBar()
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
  private ImmersiveToolRail() {
    Column({ space: 12 }) {
      Text(
        this.immersiveMonitoring
          ? `${this.videoFrameRate}P`
          : this.exposureMode.toUpperCase()
      )
        .fontSize(19)
        .fontWeight(FontWeight.Bold)
        .fontColor(Color.White)
        .width(64)
        .height(56)
        .textAlign(TextAlign.Center)
        .backgroundColor('#AA000000')
        .borderRadius(10)
      Button(
        this.tr(this.liveView ? 'LIVE' : '开启取景'),
        { type: ButtonType.Normal }
      )
        .width(64)
        .height(52)
        .fontSize(11)
        .fontWeight(FontWeight.Bold)
        .fontColor(Color.White)
        .backgroundColor(this.liveView ? '#B8991020' : '#AA000000')
        .borderRadius(10)
        .onClick((): void => {
          this.toggleLiveView();
        })
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
            ? $r('app.color.video')
            : $r('app.color.accent')
        )
      this.ImmersiveCaptureButton()
      Text(this.immersiveMonitoring
        ? (this.videoRecording ? 'REC' : this.tr('待机'))
        : 'JPEG')
        .fontSize(11)
        .fontFamily('monospace')
        .fontWeight(FontWeight.Bold)
        .fontColor(Color.White)
        .padding({ left: 14, right: 14, top: 8, bottom: 8 })
        .backgroundColor('#AA000000')
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
      .fontColor(Color.White)
      .backgroundColor(
        this.immersiveMonitoring
          ? $r('app.color.video')
          : $r('app.color.accent')
      )
      .borderRadius(48)
      .enabled(this.connected && !this.busy)
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
            .fontSize(15)
            .fontWeight(FontWeight.Bold)
            .fontColor(
              this.immersiveMonitoring
                ? $r('app.color.video')
                : $r('app.color.accent')
            )
          Text(this.immersiveMonitoring
            ? (this.videoRecording ? 'REC' : this.tr('待机'))
            : 'JPEG')
            .fontSize(11)
            .fontFamily('monospace')
            .fontColor(Color.White)
            .padding({ left: 12, right: 12, top: 8, bottom: 8 })
            .backgroundColor('#AA000000')
            .borderRadius(10)
        }
      }
      .padding({ left: 14, right: 14, bottom: 12 })
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  private ImmersiveParameterBar() {
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
          .backgroundColor('#99000000')
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
                ? '#CC055AD2'
                : '#99000000'
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
              this.immersiveMonitoring
                ? `${this.videoShutterAngle.toFixed(1)}°`
                : this.shutterDisplay(),
              this.immersiveMonitoring ? 'videoShutter' : 'photoShutter'
            )
            this.ImmersiveParameterControl(
              '光圈',
              `f/${this.currentAperture}`,
              'aperture'
            )
            this.ImmersiveParameterControl('ISO', `${this.currentIso}`, 'iso')
            this.ImmersiveParameterControl(
              '曝光补偿',
              `${this.currentCompensation.toFixed(1)} EV`,
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
                  `${this.videoFrameRate}p`,
                  'videoFrameRate'
                )
              } else {
                this.ImmersiveParameterControl(
                  '拍摄模式',
                  this.exposureMode.toUpperCase(),
                  'exposureMode'
                )
              }
              this.ImmersiveParameterControl(
                '对焦模式',
                this.currentFocusMode === 'continuous' ? 'AF-C' : 'AF-S',
                'focusMode'
              )
              this.ImmersiveParameterControl(
                '白平衡',
                this.currentWhiteBalance === 'continuous' ? '自动' : '保留',
                'whiteBalanceMode'
              )
              this.ImmersiveParameterControl(
                '优化校准',
                this.currentPictureControl === 'neutral' ? '自然' : '标准',
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
        .backgroundColor('#66000000')
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
          .fontColor('#99FFFFFF')
        Text(value)
          .fontSize(12)
          .fontFamily('monospace')
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.White)
      }
      .width(52)
      Button('+', { type: ButtonType.Normal })
        .width(44)
        .height(44)
        .fontColor(Color.White)
        .backgroundColor('#66000000')
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
    .backgroundColor('#99000000')
    .borderRadius(10)
  }

  @Builder
  private SettingsWorkspace() {
    Scroll() {
      Column({ space: 20 }) {
        Text(this.tr('设置'))
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.ink'))
          .width('100%')
        Text(this.tr('更新、诊断与支持。'))
          .fontSize(14)
          .fontColor($r('app.color.muted'))
          .width('100%')
        Column({ space: 12 }) {
          Text(this.tr('语言'))
            .fontSize(17)
            .fontWeight(FontWeight.Bold)
            .width('100%')
          Text(this.tr('语言更改会立即应用，并在下次启动时保留。'))
            .fontSize(12)
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
        Column({ space: 12 }) {
          Text('AI 功能激活')
            .fontSize(17)
            .fontWeight(FontWeight.Bold)
            .width('100%')
          Text('AI 修图与生图需购买激活码解锁。每个激活码 100 次，绑定设备，服务器端计数。')
            .fontSize(12)
            .fontColor($r('app.color.muted'))
            .width('100%')
          if (this.getAiActivationCode().length > 0) {
            Text('状态：已激活 ✓')
              .fontSize(13)
              .fontWeight(FontWeight.Bold)
              .fontColor(Color.Green)
              .width('100%')
          }
          TextInput({ placeholder: '输入激活码', text: this.aiActivationInput })
            .height(44)
            .width('100%')
            .onChange((value: string): void => {
              this.aiActivationInput = value;
            })
          TextInput({ placeholder: '服务器地址（默认 http://101.34.255.115:8787）', text: this.aiServerInput })
            .height(44)
            .width('100%')
            .onChange((value: string): void => {
              this.aiServerInput = value;
            })
          Row({ space: 8 }) {
            Button('购买激活码', { type: ButtonType.Normal })
              .height(40)
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
                    uri: 'https://www.ifdian.net/a/Tauber'
                  });
                } catch (_) {
                  this.aiActivationMsg = '无法打开浏览器';
                }
              })
            Button('激活', { type: ButtonType.Normal })
              .height(40)
              .layoutWeight(1)
              .fontColor($r('app.color.accent_ink'))
              .backgroundColor($r('app.color.accent'))
              .onClick((): void => {
                this.doAiActivate();
              })
          }
          .width('100%')
          if (this.aiActivationMsg.length > 0) {
            Text(this.aiActivationMsg)
              .fontSize(11)
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
            .fontSize(17)
            .fontWeight(FontWeight.Bold)
            .width('100%')
          Text(this.tr(
            `当前版本 ${CURRENT_VERSION} · 优先通过 Mirror酱检查更新，无可用 CDN 下载地址时自动回退 GitHub Releases。`
          ))
            .fontSize(12)
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
            .height(42)
            .showPasswordIcon(true)
            .onChange((value: string): void => {
              this.mirrorChyanCdk = value;
            })
          Text(this.tr(
            'CDK 保存在应用私有设置中，不会写入诊断日志。'
          ))
            .fontSize(11)
            .fontColor($r('app.color.muted'))
            .width('100%')
          Row({ space: 8 }) {
            Button(this.tr('保存 CDK'), { type: ButtonType.Normal })
              .height(40)
              .layoutWeight(1)
              .fontColor($r('app.color.ink'))
              .backgroundColor($r('app.color.paper_2'))
              .borderRadius(6)
              .onClick((): void => {
                this.saveMirrorChyanCdk();
              })
            Button(this.tr('打开 Mirror酱'), { type: ButtonType.Normal })
              .height(40)
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
            .fontSize(17)
            .fontWeight(FontWeight.Bold)
            .width('100%')
          Text(this.tr(
            this.diagnostics?.directoryPath ?? '日志目录暂不可用'
          ))
            .fontSize(12)
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
            .fontSize(11)
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
          .fontSize(12)
          .fontColor($r('app.color.muted'))
          .width('100%')
        Column({ space: 12 }) {
          Text(this.tr('喜欢 帧澈 ZENCHE？'))
            .fontSize(17)
            .fontWeight(FontWeight.Bold)
            .width('100%')
          Text(this.tr('请作者喝杯奶茶，支持后续维护与新机型适配。'))
            .fontSize(14)
            .fontColor($r('app.color.muted'))
            .width('100%')
          Button(this.tr('请作者喝奶茶'), { type: ButtonType.Normal })
            .height(44)
            .fontColor($r('app.color.accent_ink'))
            .backgroundColor($r('app.color.accent'))
            .borderRadius(6)
            .onClick((): void => {
              this.openDonation();
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
        Text(this.tr('相机参数'))
          .fontSize(17)
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
          this.VideoFrameRateSelect()
          this.VideoShutterAngleSelect()
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
      this.ScopeLine('R', this.redHistogram, '#FFD22D34')
      this.ScopeLine('G', this.greenHistogram, '#FF199152')
      this.ScopeLine('B', this.blueHistogram, '#FF2468D8')
      this.ScopeLine('波形', this.waveform, '#FF1C2330')
      this.ScopeLine('矢量', this.vectorscope, '#FF1C2330')
      Text(`${this.tr('峰值覆盖')} · ${this.peakingCoverage}%`)
        .fontSize(10)
        .fontFamily('monospace')
        .fontColor($r('app.color.muted'))
        .width('100%')
    }
    .width('100%')
    .padding(10)
    .backgroundColor($r('app.color.paper_2'))
    .borderRadius(6)
  }

  @Builder
  private ScopeLine(label: string, value: string, color: ResourceColor) {
    Row({ space: 6 }) {
      Text(this.tr(label))
        .width(34)
        .fontSize(10)
        .fontWeight(FontWeight.Bold)
        .fontColor(color)
      Text(value)
        .fontSize(9)
        .fontFamily('monospace')
        .fontColor($r('app.color.ink'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)
    }
    .width('100%')
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
  private VideoShutterAngleSelect() {
    Text(
      `${this.tr('快门角度')} · ${this.videoFrameRate}p`
    )
      .fontSize(13)
      .fontColor($r('app.color.ink_2'))
      .width('100%')
    Select(
      SHUTTER_ANGLES.map((entry: SelectEntry): SelectOption => {
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
        this.videoShutterAngle = Number(SHUTTER_ANGLES[index].value);
        this.applyVideoShutterAngle();
      })
  }

  @Builder
  private StatusBar() {
    Row() {
      Text(this.tr(this.status))
        .fontSize(10)
        .fontFamily('monospace')
        .fontColor($r('app.color.graphite_ink'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)
      Text(
        this.language === LANGUAGE_ENGLISH
          ? `${this.photos.length} photos`
          : this.language === LANGUAGE_JAPANESE
            ? `${this.photos.length} 枚の写真`
            : `${this.photos.length} 张照片`
      )
        .fontSize(10)
        .fontFamily('monospace')
        .fontColor($r('app.color.graphite_muted'))
    }
    .width('100%')
    .height(34)
    .padding({ left: 16, right: 16 })
      .backgroundColor($r('app.color.graphite_2'))
    .border({
      width: { top: 1 },
      color: $r('app.color.graphite_rule')
    })
  }

  private async toggleCameraConnection(): Promise<void> {
    if (this.busy) {
      return;
    }
    if (this.connected) {
      this.previewGeneration++;
      await this.runBusy('正在断开相机…', async (): Promise<void> => {
        await this.camera.disconnect();
        this.connected = false;
        this.liveView = false;
        this.videoRecording = false;
        this.cameraName = '未连接';
        if (this.preview !== undefined) {
          this.preview.release();
          this.preview = undefined;
        }
        this.status = '相机已断开';
      });
      return;
    }

    await this.runBusy('正在连接 Nikon 相机…', async (): Promise<void> => {
      const profile: CameraProfile = await this.camera.connect();
      this.connected = true;
      this.cameraName = profile.name;
      this.status = `${profile.name} 已连接`;
    });
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
    if (
      !this.connected ||
      this.busy ||
      library === undefined ||
      workflow === undefined
    ) {
      return;
    }
    await this.runBusy('正在拍摄并下载 JPEG…', async (): Promise<void> => {
      const jpeg: Uint8Array = await this.camera.capture();
      const path: string = await workflow.store(
        jpeg,
        'capture.jpg',
        this.cameraName
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
        const path: string = await workflow.store(
          jpeg,
          'capture.jpg',
          this.cameraName
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
          await this.camera.stopMovieRecording();
        } else {
          await this.camera.startMovieRecording();
        }
        this.videoRecording = this.camera.isMovieRecording;
        this.status = this.videoRecording
          ? '● REC · 视频正在录制到相机存储卡'
          : '录制已停止 · 视频保存在相机存储卡';
      }
    );
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

  private adjustImmersiveParameter(
    parameter: string,
    direction: number
  ): void {
    if (!this.connected || this.busy) {
      return;
    }
    if ([
      'videoFrameRate',
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
    this.editorRotation = 0;
    this.editorFlipHorizontal = false;
    this.editorFlipVertical = false;
    this.editorCropRatio = 'original';
    this.editorShowingOriginal = false;
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
    for (let offset: number = 0; offset < pixels.length; offset += 4) {
      let red: number = pixels[offset] / 255 * exposure;
      let green: number = pixels[offset + 1] / 255 * exposure;
      let blue: number = pixels[offset + 2] / 255 * exposure;

      red += temperature * 0.12 + tint * 0.045;
      green -= tint * 0.08;
      blue -= temperature * 0.12 - tint * 0.045;

      let luma: number =
        red * 0.2126 + green * 0.7152 + blue * 0.0722;
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
    const visualProcessing: boolean =
      this.focusPeakingEnabled || this.falseColorEnabled;
    const analyzeFrame: boolean =
      visualProcessing || this.previewAnalysisSequence++ % (this.videoRecording ? 6 : 3) === 0;
    if (monitoring && analyzeFrame) {
      const result: ProfessionalMonitorResult =
        await processProfessionalMonitor(
          sourceMap,
          this.focusPeakingEnabled,
          this.falseColorEnabled
        );
      pixelMap = result.pixelMap;
      this.redHistogram = result.redHistogram;
      this.greenHistogram = result.greenHistogram;
      this.blueHistogram = result.blueHistogram;
      this.waveform = result.waveform;
      this.vectorscope = result.vectorscope;
      this.peakingCoverage = result.peakingCoverage;
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
