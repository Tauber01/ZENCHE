import {
  abilityAccessCtrl,
  common,
  Permissions
} from '@kit.AbilityKit';
import { dataSharePredicates } from '@kit.ArkData';
import { picker } from '@kit.CoreFileKit';
import { image } from '@kit.ImageKit';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { promptAction } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';
import { http } from '@kit.NetworkKit';
import { systemShare } from '@kit.ShareKit';
import { CameraProfile } from '../camera/CameraProfiles';
import { PtpCamera } from '../camera/PtpCamera';
import { PhotoItem, PhotoLibrary } from '../storage/PhotoLibrary';
import {
  FTP_PORT,
  HTTP_PORT,
  WirelessTransferServer
} from '../transfer/WirelessTransferServer';
import { DiagnosticLogger } from '../diagnostics/DiagnosticLogger';

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

const CURRENT_VERSION: string = '0.8.3';
const LATEST_RELEASE_API: string =
  'https://api.github.com/repos/Tauber01/ZENCHE/releases/latest';
const RELEASES_URL: string =
  'https://github.com/Tauber01/ZENCHE/releases';

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
  private wireless?: WirelessTransferServer;
  private diagnostics?: DiagnosticLogger;
  private previewGeneration: number = 0;

  @State private section: string = 'capture';
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
  @State private videoRecording: boolean = false;
  @State private recentLogs: string = '点击“查询最近日志”后显示。';
  @State private updateStatus: string = '尚未检查更新';
  @State private updateChecking: boolean = false;
  @State private availableUpdateUrl: string = '';
  @State private availableVersion: string = '';
  @State private largePreviewVisible: boolean = false;
  @State private largePreviewName: string = '';
  @State private systemMedia: Array<SystemMediaItem> = [];
  @State private systemAlbumStatus: string = '等待相册授权';
  @State private cloudGuideVisible: boolean = false;
  @State private immersivePreviewVisible: boolean = false;
  @State private immersiveMonitoring: boolean = false;
  @State private immersiveParametersExpanded: boolean = true;
  @State private systemExpanded: boolean = true;
  @State private systemPhotosExpanded: boolean = true;
  @State private systemVideosExpanded: boolean = true;
  @State private wirelessExpanded: boolean = false;
  @State private localExpanded: boolean = true;
  @State private localPhotosExpanded: boolean = true;
  @State private localVideosExpanded: boolean = true;
  @State private currentBreakpoint: string = 'lg';
  private largePreview?: image.PixelMap;

  aboutToAppear(): void {
    const context: common.UIAbilityContext =
      getContext(this) as common.UIAbilityContext;
    this.diagnostics = new DiagnosticLogger(context);
    this.diagnostics.startSession();
    this.library = new PhotoLibrary(context);
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

  aboutToDisappear(): void {
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
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.paper'))
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
      Column({ space: 4 }) {
        Text('帧澈 ZENCHE')
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.ink'))
        Text('Capture · Connect · Flow')
          .fontSize(10)
          .fontFamily('monospace')
          .fontColor($r('app.color.muted'))
        Text(
          this.connected
            ? `${this.cameraName} · USB/PTP`
            : '未连接 · HARMONYOS USB/PTP'
        )
          .fontSize(11)
          .fontFamily('monospace')
          .fontColor($r('app.color.muted'))
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      Button(
        this.isCompact()
          ? (this.connected ? '断开' : '连接')
          : (this.connected ? '断开相机' : '连接相机'),
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
        .borderRadius(6)
        .enabled(!this.busy)
        .onClick((): void => {
          this.toggleCameraConnection();
        })
      Button('设置', { type: ButtonType.Normal })
        .height(44)
        .padding({ left: 12, right: 12 })
        .fontColor($r('app.color.ink'))
        .backgroundColor($r('app.color.surface'))
        .border({
          width: 1,
          color: $r('app.color.rule_strong'),
          radius: 6
        })
        .onClick((): void => {
          this.section = 'settings';
        })
    }
    .width('100%')
    .height(68)
    .padding({ left: 20, right: 20 })
    .backgroundColor($r('app.color.surface'))
    .border({
      width: { bottom: 1 },
      color: $r('app.color.rule')
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
        Text('工作区')
          .fontSize(11)
          .fontFamily('monospace')
          .fontColor($r('app.color.muted'))
          .width('100%')
          .margin({ bottom: 8 })
        this.NavButton('照片拍摄', 'capture')
        this.NavButton('视频监看', 'monitor')
        this.NavButton('文件与传输', 'library')
        Blank()
        Text('NIKON LINK 0.8.3')
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
    Button(label, { type: ButtonType.Normal })
      .width(this.isCompact() ? 104 : '100%')
      .height(44)
      .fontSize(14)
      .fontWeight(
        this.section === target ? FontWeight.Bold : FontWeight.Normal
      )
      .fontColor(
        this.section === target
          ? $r('app.color.accent')
          : $r('app.color.ink')
      )
      .backgroundColor(
        this.section === target
          ? $r('app.color.accent_soft')
          : Color.Transparent
      )
      .borderRadius(6)
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
            Text('等待相机画面')
              .fontSize(22)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.graphite_ink'))
            Text('连接相机后开启实时取景')
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
        Button('全屏', { type: ButtonType.Normal })
          .height(44)
          .fontColor(Color.White)
          .backgroundColor('#99000000')
          .borderRadius(8)
          .align(Alignment.TopEnd)
          .margin(16)
          .onClick((): void => {
            this.immersiveMonitoring = this.section === 'monitor';
            this.immersivePreviewVisible = true;
          })
      }
      .width('100%')
      .layoutWeight(1)
      .constraintSize({ minHeight: 320 })
      .backgroundColor($r('app.color.graphite'))
      .border({
        width: 1,
        color: $r('app.color.graphite_rule'),
        radius: 10
      })

      Row({ space: 8 }) {
        Text(
          this.section === 'monitor'
            ? '相机原生 JPEG · 监看输出 · 不修改原片'
            : '相机原生 JPEG · 本地预览'
        )
          .fontSize(12)
          .fontColor($r('app.color.muted'))
          .layoutWeight(1)
        Button(this.liveView ? '停止取景' : '开启取景', {
          type: ButtonType.Normal
        })
          .height(44)
          .fontColor($r('app.color.ink'))
          .backgroundColor($r('app.color.surface'))
          .border({
            width: 1,
            color: $r('app.color.rule_strong'),
            radius: 6
          })
          .enabled(this.connected && !this.busy)
          .onClick((): void => {
            this.toggleLiveView();
          })
        Button(
          this.section === 'monitor'
            ? (this.videoRecording ? '停止录制' : '开始录制')
            : '拍摄照片',
          { type: ButtonType.Normal }
        )
          .height(44)
          .fontColor($r('app.color.accent_ink'))
          .backgroundColor(
            this.section === 'monitor'
              ? $r('app.color.video')
              : $r('app.color.accent')
          )
          .borderRadius(6)
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
    }
    .width('100%')
    .height(this.isCompact() ? 'auto' : '100%')
    .padding(16)
  }

  @Builder
  private LibraryWorkspace() {
    Column({ space: 16 }) {
      Text('文件与传输')
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.ink'))
        .width('100%')
      Text(
        `${this.photos.length} 个 帧澈 ZENCHE 文件 · ` +
        `${this.systemMedia.length} 个系统相册项目`
      )
        .fontSize(14)
        .fontColor($r('app.color.muted'))
        .width('100%')
      Row({ space: 8 }) {
        Button('刷新系统相册', { type: ButtonType.Normal })
          .height(44)
          .layoutWeight(1)
          .fontColor($r('app.color.ink'))
          .backgroundColor($r('app.color.paper_2'))
          .borderRadius(6)
          .onClick((): void => {
            this.loadSystemAlbum();
          })
        Button('链接网盘', { type: ButtonType.Normal })
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
      Text('系统相册中的照片与视频直接显示在本页；网盘文件通过独立指引页和系统文件选择器安全加入。')
        .fontSize(12)
        .fontColor($r('app.color.muted'))
        .width('100%')
      Button(
        `${this.systemExpanded ? '⌄' : '›'} 系统相册 · ` +
        `${this.systemMedia.length}`,
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
          Text('系统相册暂不可见')
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
          Text('允许照片和视频访问后，最近媒体会直接显示在这里。')
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
          radius: 8
        })
      } else if (this.systemExpanded) {
        Row({ space: 8 }) {
          Button(
            `${this.systemPhotosExpanded ? '⌄' : '›'} 照片 · ` +
            `${this.systemMedia.filter((item: SystemMediaItem): boolean => !item.isVideo).length}`
          )
            .height(44)
            .layoutWeight(1)
            .onClick((): void => {
              this.systemPhotosExpanded = !this.systemPhotosExpanded;
            })
          Button(
            `${this.systemVideosExpanded ? '⌄' : '›'} 视频 · ` +
            `${this.systemMedia.filter((item: SystemMediaItem): boolean => item.isVideo).length}`
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
        Text('系统相册内容保持在原位置；帧澈 ZENCHE 只读取缩略图和预览。')
          .fontSize(11)
          .fontColor($r('app.color.muted'))
          .width('100%')
      }
      Button(
        `${this.wirelessExpanded ? '⌄' : '›'} 无线传输`,
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
        `${this.localExpanded ? '⌄' : '›'} 帧澈 ZENCHE 文件库 · ` +
        `${this.photos.length}`,
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
          Text('本地图库还是空的')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
          Text('连接相机拍摄，或在上方开启无线图片收件箱。')
            .fontSize(14)
            .fontColor($r('app.color.muted'))
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else if (this.localExpanded) {
        Row({ space: 8 }) {
          Button(
            `${this.localPhotosExpanded ? '⌄' : '›'} 照片 · ` +
            `${this.photos.filter((item: PhotoItem): boolean => !item.isVideo).length}`
          )
            .height(44)
            .layoutWeight(1)
            .onClick((): void => {
              this.localPhotosExpanded = !this.localPhotosExpanded;
            })
          Button(
            `${this.localVideosExpanded ? '⌄' : '›'} 视频 · ` +
            `${this.photos.filter((item: PhotoItem): boolean => item.isVideo).length}`
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
                  Button('预览', { type: ButtonType.Normal })
                    .height(44)
                    .fontColor($r('app.color.ink'))
                    .backgroundColor($r('app.color.paper_2'))
                    .borderRadius(6)
                    .onClick((): void => {
                      this.previewPhoto(item);
                    })
                  Button('分享', { type: ButtonType.Normal })
                    .height(44)
                    .fontColor($r('app.color.ink'))
                    .backgroundColor($r('app.color.paper_2'))
                    .borderRadius(6)
                    .onClick((): void => {
                      this.sharePhoto(item);
                    })
                  Button('删除', { type: ButtonType.Normal })
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
  private WirelessTransferCard() {
    Column({ space: 12 }) {
          Text('多协议无线图片收件箱')
            .fontSize(17)
            .fontWeight(FontWeight.Bold)
            .width('100%')
          Text(this.wirelessStatus)
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .width('100%')
          Text(this.wirelessAddress)
            .fontSize(13)
            .fontFamily('monospace')
            .fontColor($r('app.color.accent'))
            .width('100%')
          Button(
            this.wirelessRunning ? '停止无线接收' : '开启无线接收',
            { type: ButtonType.Normal }
          )
            .height(44)
            .fontColor($r('app.color.accent_ink'))
            .backgroundColor($r('app.color.accent'))
            .borderRadius(6)
            .onClick((): void => {
              this.toggleWireless();
            })
          Text(
            `FTP/PASV · ${this.wirelessAddress}\n` +
            `HTTP 上传 · 端口 ${HTTP_PORT} · /upload/文件名\n` +
            `WebDAV · 端口 ${HTTP_PORT} · 用户名/密码 nikonlink\n` +
            `接收完成后自动进入文件库`
          )
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
        Button('关闭', { type: ButtonType.Normal })
          .height(44)
          .fontColor(Color.White)
          .backgroundColor('#66000000')
          .borderRadius(8)
          .onClick((): void => {
            this.closeLargePhoto();
          })
        Blank()
        Button('分享到社交平台', { type: ButtonType.Normal })
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
          Text('链接网盘')
            .fontSize(24)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.ink'))
          Text('账号和密码始终由网盘客户端管理。')
            .fontSize(12)
            .fontColor($r('app.color.muted'))
        }
        .alignItems(HorizontalAlign.Start)
        Blank()
        Button('关闭', { type: ButtonType.Normal })
          .height(44)
          .fontColor($r('app.color.ink'))
          .backgroundColor($r('app.color.paper_2'))
          .borderRadius(6)
          .onClick((): void => {
            this.cloudGuideVisible = false;
          })
      }
      .width('100%')
      Text('先安装并登录对应客户端，把照片或视频下载到设备，再通过系统文件选择器加入 帧澈 ZENCHE。')
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
                    Text(provider.name)
                      .fontSize(15)
                      .fontWeight(FontWeight.Bold)
                      .fontColor($r('app.color.ink'))
                      .width('100%')
                    Text(provider.note)
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
      Text('步骤：安装并登录 → 下载媒体 → 选择文件并加入。')
        .fontSize(12)
        .fontColor($r('app.color.muted'))
        .width('100%')
      Button('选择文件并加入', { type: ButtonType.Normal })
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
  private ImmersivePreviewOverlay() {
    Stack({ alignContent: Alignment.Center }) {
      if (this.preview !== undefined) {
        Image(this.preview)
          .width('100%')
          .height('100%')
          .objectFit(ImageFit.Contain)
      } else {
        Column({ space: 8 }) {
          Text('等待相机画面')
            .fontSize(24)
            .fontWeight(FontWeight.Bold)
            .fontColor(Color.White)
          Text('连接相机并开启实时取景后即可全屏监看。')
            .fontSize(13)
            .fontColor('#99FFFFFF')
        }
      }
      Column() {
        Row({ space: 10 }) {
          Button('⌄ 退出全屏', { type: ButtonType.Normal })
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
      }
      .width('100%')
      .height('100%')
      .padding(20)
      this.ImmersiveParameterBar()
      Row() {
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
            .backgroundColor('#99000000')
            .borderRadius(10)
          Text('USB\nPTP')
            .fontSize(11)
            .fontFamily('monospace')
            .fontWeight(FontWeight.Bold)
            .fontColor(Color.White)
            .width(64)
            .height(56)
            .textAlign(TextAlign.Center)
            .backgroundColor('#99000000')
            .borderRadius(10)
        }
        Blank()
        Column({ space: 10 }) {
          Text(this.immersiveMonitoring ? '视频' : '照片')
            .fontSize(17)
            .fontWeight(FontWeight.Bold)
            .fontColor(
              this.immersiveMonitoring
                ? $r('app.color.video')
                : $r('app.color.accent')
            )
          Button(
            this.immersiveMonitoring
              ? (this.videoRecording ? '■\n停止' : '●\n录制')
              : '●\n拍摄',
            { type: ButtonType.Normal }
          )
            .width(96)
            .height(96)
            .fontSize(15)
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
          Button(
            this.liveView ? '停止取景' : '开启取景',
            { type: ButtonType.Normal }
          )
            .height(44)
            .fontColor(Color.White)
            .backgroundColor('#99000000')
            .borderRadius(8)
            .onClick((): void => {
              this.toggleLiveView();
            })
        }
      }
      .width('100%')
      .padding({ left: 22, right: 22 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.Black)
  }

  @Builder
  private ImmersiveParameterBar() {
    Column({ space: 6 }) {
      Button(
        this.immersiveParametersExpanded ? '收起参数' : '展开参数',
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
    .margin({ bottom: 74 })
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
        Text(label)
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
        Text('设置')
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.ink'))
          .width('100%')
        Text('更新、诊断与支持。')
          .fontSize(14)
          .fontColor($r('app.color.muted'))
          .width('100%')
        Column({ space: 12 }) {
          Text('软件更新')
            .fontSize(17)
            .fontWeight(FontWeight.Bold)
            .width('100%')
          Text(`当前版本 ${CURRENT_VERSION} · 从 帧澈 ZENCHE 的 GitHub Releases 检查新版本。`)
            .fontSize(12)
            .fontColor($r('app.color.muted'))
            .width('100%')
          Text(this.updateStatus)
            .fontSize(13)
            .fontColor($r('app.color.muted'))
            .width('100%')
          Row({ space: 8 }) {
            Button(
              this.updateChecking ? '正在检查…' : '检查更新',
              { type: ButtonType.Normal }
            )
              .height(44)
              .layoutWeight(1)
              .fontColor($r('app.color.ink'))
              .backgroundColor($r('app.color.paper_2'))
              .borderRadius(6)
              .enabled(!this.updateChecking)
              .onClick((): void => {
                this.checkForUpdates();
              })
            if (this.availableVersion.length > 0) {
              Button(
                `获取 ${this.availableVersion}`,
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
          Text('诊断日志')
            .fontSize(17)
            .fontWeight(FontWeight.Bold)
            .width('100%')
          Text(this.diagnostics?.directoryPath ?? '日志目录暂不可用')
            .fontSize(12)
            .fontFamily('monospace')
            .fontColor($r('app.color.muted'))
            .width('100%')
          Row({ space: 8 }) {
            Button('查询最近日志', { type: ButtonType.Normal })
              .height(44)
              .layoutWeight(1)
              .fontColor($r('app.color.ink'))
              .backgroundColor($r('app.color.paper_2'))
              .borderRadius(6)
              .onClick((): void => {
                this.recentLogs =
                  this.diagnostics?.recentText(6000) ?? '日志暂不可用。';
              })
            Button('上传脱敏日志', { type: ButtonType.Normal })
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
        Text('只有在你检查预填内容并于 GitHub 确认提交后，脱敏日志才会发送。')
          .fontSize(12)
          .fontColor($r('app.color.muted'))
          .width('100%')
        Column({ space: 12 }) {
          Text('喜欢 帧澈 ZENCHE？')
            .fontSize(17)
            .fontWeight(FontWeight.Bold)
            .width('100%')
          Text('请作者喝杯奶茶，支持后续维护与新机型适配。')
            .fontSize(14)
            .fontColor($r('app.color.muted'))
            .width('100%')
          Button('请作者喝奶茶', { type: ButtonType.Normal })
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
        Text('相机参数')
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.ink'))
          .width('100%')
          .margin({ bottom: 8 })
        if (this.section === 'monitor') {
          Text('视频曝光三要素')
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
    .backgroundColor($r('app.color.surface'))
    .border({
      width: { left: 1 },
      color: $r('app.color.rule')
    })
  }

  @Builder
  private ParameterSelect(
    label: string,
    entries: Array<SelectEntry>,
    selectedIndex: number,
    modeEnabled: boolean,
    parameter: string
  ) {
    Text(label)
      .fontSize(13)
      .fontColor($r('app.color.ink_2'))
      .width('100%')
    Select(
      entries.map((entry: SelectEntry): SelectOption => {
        return { value: entry.label };
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
        radius: 6
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
    Text('视频帧率基准')
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
    Text(`快门角度 · 按 ${this.videoFrameRate}p 换算`)
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
        (this.exposureMode === 'manual' ||
          this.exposureMode === 'shutterPriority')
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
      Text(this.status)
        .fontSize(10)
        .fontFamily('monospace')
        .fontColor($r('app.color.graphite_ink'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)
      Text(`${this.photos.length} 张照片`)
        .fontSize(10)
        .fontFamily('monospace')
        .fontColor($r('app.color.graphite_muted'))
    }
    .width('100%')
    .height(34)
    .padding({ left: 16, right: 16 })
    .backgroundColor($r('app.color.graphite'))
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
    if (!this.connected || this.busy || library === undefined) {
      return;
    }
    await this.runBusy('正在拍摄并下载 JPEG…', async (): Promise<void> => {
      const jpeg: Uint8Array = await this.camera.capture();
      const path: string = library.saveCapture(jpeg);
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

  private closeImmersivePreview(): void {
    if (!this.immersivePreviewVisible) {
      return;
    }
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
      return 'exposureTime';
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
      'exposureTime',
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
    if (library === undefined || uris.length === 0) {
      return;
    }
    let imported: number = 0;
    for (let index: number = 0; index < uris.length; index++) {
      const uri: string = uris[index];
      try {
        const name: string = this.externalPhotoName(uri, source, index);
        library.importFromUri(uri, name);
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
    const pixelMap: image.PixelMap = await source.createPixelMap({
      editable: false,
      desiredPixelFormat: image.PixelMapFormat.RGBA_8888
    });
    source.release();
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

  private async checkForUpdates(): Promise<void> {
    if (this.updateChecking) {
      return;
    }
    this.updateChecking = true;
    this.updateStatus = '正在检查更新…';
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
      const version: string = this.normalizeVersion(release.tag_name);
      if (!this.isNewerVersion(version, CURRENT_VERSION)) {
        this.availableVersion = '';
        this.availableUpdateUrl = '';
        this.updateStatus = '已是最新版本';
        return;
      }

      let targetUrl: string = release.html_url;
      for (const asset of release.assets) {
        if (asset.name.endsWith('-HarmonyOS.hap')) {
          targetUrl = asset.browser_download_url;
          break;
        }
      }
      this.availableVersion = version;
      this.availableUpdateUrl = targetUrl;
      this.updateStatus = `发现新版本 ${version}`;
      this.diagnostics?.info('update', this.updateStatus);
    } catch (error) {
      this.updateStatus = '检查失败，请确认网络后重试';
      this.diagnostics?.error(
        'update',
        `检查更新失败：${(error as BusinessError).message}`
      );
    } finally {
      this.updateChecking = false;
      request.destroy();
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

  private async openDonation(): Promise<void> {
    const context: common.UIAbilityContext =
      getContext(this) as common.UIAbilityContext;
    try {
      await context.startAbility({
        action: 'ohos.want.action.viewData',
        uri:
          'https://raw.githubusercontent.com/Tauber01/ZENCHE/' +
          'main/native/macos/Resources/wechat-donation.png'
      });
    } catch (error) {
      this.showError(
        `无法打开赞赏二维码：${(error as BusinessError).message}`
      );
    }
  }
}
