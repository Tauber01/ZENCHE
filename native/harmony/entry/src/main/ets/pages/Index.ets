import {
  abilityAccessCtrl,
  common,
  Permissions
} from '@kit.AbilityKit';
import { dataSharePredicates, preferences } from '@kit.ArkData';
import { picker } from '@kit.CoreFileKit';
import { image } from '@kit.ImageKit';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { promptAction } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';
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

const CURRENT_VERSION: string = '1.1.0';
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
  @State private immersiveLandscape: boolean = false;
  @State private systemExpanded: boolean = true;
  @State private systemPhotosExpanded: boolean = true;
  @State private systemVideosExpanded: boolean = true;
  @State private wirelessExpanded: boolean = false;
  @State private localExpanded: boolean = true;
  @State private localPhotosExpanded: boolean = true;
  @State private localVideosExpanded: boolean = true;
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
          this.NavButton('文件与传输', 'library')
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
        this.NavButton('文件与传输', 'library')
        Blank()
        Text('ZENCHE 1.1.0')
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
        this.section = target;
        if (target === 'library') {
          this.refreshPhotos();
          this.loadSystemAlbum();
        }
      })
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
      Text(this.tr('文件与传输'))
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.ink'))
        .width('100%')
      Text(this.tr(
        `${this.photos.length} 个 帧澈 ZENCHE 文件 · ` +
        `${this.systemMedia.length} 个系统相册项目`
      ))
        .fontSize(14)
        .fontColor($r('app.color.muted'))
        .width('100%')
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
      Button(
        this.tr(
          `${this.localExpanded ? '⌄' : '›'} 帧澈 ZENCHE 文件库 · ` +
          `${this.photos.length}`
        ),
        { type: ButtonType.Normal }
      )
        .width('100%')
        .height(44)
        .fontColor($r('app.color.ink'))
        .backgroundColor($r('app.color.paper_2'))
        .onClick((): void => {
          this.localExpanded = !this.localExpanded;
        })
      if (this.localExpanded && this.photos.length === 0) {
        Column({ space: 12 }) {
          Text(this.tr('本地图库还是空的'))
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
          Text(this.tr('连接相机拍摄，或在上方开启无线图片收件箱。'))
            .fontSize(14)
            .fontColor($r('app.color.muted'))
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else if (this.localExpanded) {
        Row({ space: 8 }) {
          Button(
            this.tr(
              `${this.localPhotosExpanded ? '⌄' : '›'} 照片 · ` +
              `${this.photos.filter((item: PhotoItem): boolean => !item.isVideo).length}`
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
              `${this.photos.filter((item: PhotoItem): boolean => item.isVideo).length}`
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
            this.photos.filter((item: PhotoItem): boolean => {
              return item.isVideo
                ? this.localVideosExpanded
                : this.localPhotosExpanded;
            }),
            (item: PhotoItem) => {
              ListItem() {
                Row({ space: 12 }) {
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
                .padding(16)
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
              }
            },
            (item: PhotoItem): string => item.path
          )
        }
        .width('100%')
        .layoutWeight(1)
      }
    }
    .width('100%')
    .height(this.isCompact() ? 'auto' : '100%')
    .padding(16)
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
                '• 新增间隔拍摄、曝光包围、焦点包围与 B 门计时。\n' +
                '• 新增项目会话、命名模板、RAW + JPEG 配对、双目标备份与 SHA-256。\n' +
                '• 新增 RGB 直方图、波形、矢量示波器、峰值对焦与假色。'
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
      .width(64)
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
    .height(50)
    .padding(4)
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

  private cameraParameter(parameter: string): string {
    if (parameter === 'videoShutter' || parameter === 'photoShutter') {
      return parameter === 'videoShutter'
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
      this.refreshPhotos();
      this.status = `已删除 ${item.name}`;
    } catch (error) {
      this.showError(`无法删除 ${item.name}。`);
    }
  }

  private async displayJpeg(jpeg: Uint8Array): Promise<void> {
    const source: image.ImageSource = image.createImageSource(jpeg.buffer);
    const sourceMap: image.PixelMap = await source.createPixelMap({
      editable: false,
      desiredPixelFormat: image.PixelMapFormat.RGBA_8888
    });
    source.release();
    let pixelMap: image.PixelMap = sourceMap;
    const monitoring: boolean =
      this.section === 'monitor' || this.immersiveMonitoring;
    const visualProcessing: boolean =
      this.focusPeakingEnabled || this.falseColorEnabled;
    const analyzeFrame: boolean =
      visualProcessing || this.previewAnalysisSequence++ % 3 === 0;
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
