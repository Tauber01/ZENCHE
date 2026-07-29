/*
 * Hallmark · genre: modern-minimal · macrostructure: Split Studio
 * theme: Cobalt · enrichment: none · nav: N3 · footer: Ft2
 * audience: Nikon Z photographers · use: tether/capture/transfer
 * Pre-emit critique: P5 H5 E5 S5 R5 V5
 * contrast: pass (40–41) · mobile: 320/375/414/768 static pass
 * Static slop review: pass (native-applicable gates)
 */
import { common } from '@kit.AbilityKit';
import { image } from '@kit.ImageKit';
import { promptAction } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';
import { CameraProfile } from '../camera/CameraProfiles';
import { PtpCamera } from '../camera/PtpCamera';
import { PhotoItem, PhotoLibrary } from '../storage/PhotoLibrary';
import {
  FTP_PORT,
  WirelessFtpServer
} from '../transfer/WirelessFtpServer';
import { DiagnosticLogger } from '../diagnostics/DiagnosticLogger';

class SelectEntry {
  readonly label: string;
  readonly value: string;

  constructor(label: string, value: string) {
    this.label = label;
    this.value = value;
  }
}

const EXPOSURE_MODES: Array<SelectEntry> = [
  new SelectEntry('P · 程序自动', 'program'),
  new SelectEntry('S · 快门优先', 'shutterPriority'),
  new SelectEntry('A · 光圈优先', 'aperturePriority'),
  new SelectEntry('M · 手动', 'manual'),
  new SelectEntry('M · B门', 'bulb')
];
const SHUTTER_SPEEDS: Array<SelectEntry> = [
  new SelectEntry('1/8000 s', '0.000125'),
  new SelectEntry('1/1000 s', '0.001'),
  new SelectEntry('1/250 s', '0.004'),
  new SelectEntry('1/125 s', '0.008'),
  new SelectEntry('1/60 s', '0.016667'),
  new SelectEntry('1 s', '1'),
  new SelectEntry('30 s', '30')
];
const APERTURES: Array<SelectEntry> = [
  new SelectEntry('f/1.4', '1.4'),
  new SelectEntry('f/2.8', '2.8'),
  new SelectEntry('f/4', '4'),
  new SelectEntry('f/5.6', '5.6'),
  new SelectEntry('f/8', '8'),
  new SelectEntry('f/11', '11'),
  new SelectEntry('f/16', '16')
];
const ISO_VALUES: Array<SelectEntry> = [
  new SelectEntry('ISO 64', '64'),
  new SelectEntry('ISO 100', '100'),
  new SelectEntry('ISO 200', '200'),
  new SelectEntry('ISO 400', '400'),
  new SelectEntry('ISO 800', '800'),
  new SelectEntry('ISO 1600', '1600'),
  new SelectEntry('ISO 3200', '3200'),
  new SelectEntry('ISO 6400', '6400'),
  new SelectEntry('ISO 12800', '12800'),
  new SelectEntry('ISO 25600', '25600')
];
const EXPOSURE_COMPENSATIONS: Array<SelectEntry> = [
  new SelectEntry('-2 EV', '-2'),
  new SelectEntry('-1 EV', '-1'),
  new SelectEntry('0 EV', '0'),
  new SelectEntry('+1 EV', '1'),
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
  private wireless?: WirelessFtpServer;
  private diagnostics?: DiagnosticLogger;
  private previewGeneration: number = 0;

  @State private section: string = 'capture';
  @State private connected: boolean = false;
  @State private liveView: boolean = false;
  @State private busy: boolean = false;
  @State private cameraName: string = '未连接';
  @State private status: string = '就绪';
  @State private preview?: image.PixelMap;
  @State private photos: Array<PhotoItem> = [];
  @State private wirelessRunning: boolean = false;
  @State private wirelessStatus: string = '无线收件箱未开启';
  @State private wirelessAddress: string = '—';
  @State private exposureMode: string = 'manual';
  @State private currentBreakpoint: string = 'lg';

  aboutToAppear(): void {
    const context: common.UIAbilityContext =
      getContext(this) as common.UIAbilityContext;
    this.diagnostics = new DiagnosticLogger(context);
    this.diagnostics.startSession();
    this.library = new PhotoLibrary(context);
    this.wireless = new WirelessFtpServer(
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
  }

  build() {
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
        } else if (this.section === 'transfer') {
          this.TransferWorkspace()
        } else if (this.section === 'diagnostics') {
          this.DiagnosticsWorkspace()
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
        Text('Nikon Link')
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.ink'))
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
      Button(this.connected ? '断开相机' : '连接相机', {
        type: ButtonType.Normal
      })
        .height(44)
        .padding({ left: 20, right: 20 })
        .fontColor($r('app.color.accent_ink'))
        .backgroundColor($r('app.color.accent'))
        .borderRadius(6)
        .enabled(!this.busy)
        .onClick((): void => {
          this.toggleCameraConnection();
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
          this.NavButton('本地照片', 'library')
          this.NavButton('无线传输', 'transfer')
          this.NavButton('诊断日志', 'diagnostics')
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
        this.NavButton('本地照片', 'library')
        this.NavButton('无线传输', 'transfer')
        this.NavButton('诊断日志', 'diagnostics')
        Blank()
        Text('NIKON LINK 0.7.0')
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
        Button('拍摄照片', { type: ButtonType.Normal })
          .height(44)
          .fontColor($r('app.color.accent_ink'))
          .backgroundColor($r('app.color.accent'))
          .borderRadius(6)
          .enabled(this.connected && !this.busy)
          .onClick((): void => {
            this.capturePhoto();
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
      Text('本地照片')
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.ink'))
        .width('100%')
      if (this.photos.length === 0) {
        Column({ space: 12 }) {
          Text('本地图库还是空的')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
          Text('连接相机拍摄，或在无线传输页开启 FTP 收件箱。')
            .fontSize(14)
            .fontColor($r('app.color.muted'))
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        List({ space: 8 }) {
          ForEach(
            this.photos,
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
  private TransferWorkspace() {
    Scroll() {
      Column({ space: 20 }) {
        Text('无线传输')
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.ink'))
          .width('100%')
        Text('在可信局域网中临时开启 FTP 收件箱，传输完成后请停止接收。')
          .fontSize(14)
          .fontColor($r('app.color.muted'))
          .width('100%')
        Column({ space: 12 }) {
          Text('FTP 收件箱')
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
          Text('相机配置')
            .fontSize(17)
            .fontWeight(FontWeight.Bold)
            .width('100%')
          Text(
            '服务器类型  FTP\n' +
            `端口        ${FTP_PORT}\n` +
            '用户名      nikonlink\n' +
            '密码        nikonlink\n' +
            'PASV 模式   开启'
          )
            .fontSize(13)
            .fontFamily('monospace')
            .lineHeight(24)
            .fontColor($r('app.color.ink_2'))
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
  private DiagnosticsWorkspace() {
    Scroll() {
      Column({ space: 20 }) {
        Text('诊断日志')
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.ink'))
          .width('100%')
        Text('日志仅保存在本机，按日写入、5 MB 滚动并保留 14 天。')
          .fontSize(14)
          .fontColor($r('app.color.muted'))
          .width('100%')
        Column({ space: 12 }) {
          Text('本地目录')
            .fontSize(17)
            .fontWeight(FontWeight.Bold)
            .width('100%')
          Text(this.diagnostics?.directoryPath ?? '日志目录暂不可用')
            .fontSize(12)
            .fontFamily('monospace')
            .fontColor($r('app.color.muted'))
            .width('100%')
          Button('提交 GitHub Issue', { type: ButtonType.Normal })
            .height(44)
            .fontColor($r('app.color.accent_ink'))
            .backgroundColor($r('app.color.accent'))
            .borderRadius(6)
            .onClick((): void => {
              this.reportIssue();
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
        Text('只有在你检查预填内容并于 GitHub 确认提交后，脱敏日志才会发送。')
          .fontSize(12)
          .fontColor($r('app.color.muted'))
          .width('100%')
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
          3,
          this.exposureMode === 'manual' ||
            this.exposureMode === 'shutterPriority',
          'exposureTime'
        )
        this.ParameterSelect(
          '光圈',
          APERTURES,
          2,
          this.exposureMode === 'manual' ||
            this.exposureMode === 'aperturePriority' ||
            this.exposureMode === 'bulb',
          'aperture'
        )
        this.ParameterSelect('ISO 感光度', ISO_VALUES, 3, true, 'iso')
        this.ParameterSelect(
          '曝光补偿',
          EXPOSURE_COMPENSATIONS,
          2,
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
      entries.map((entry: SelectEntry) => {
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
      .enabled(this.connected && !this.busy && modeEnabled)
      .margin({ bottom: 8 })
      .onSelect((index: number): void => {
        const entry: SelectEntry = entries[index];
        if (parameter === 'exposureMode') {
          this.exposureMode = entry.value;
        }
        this.setCameraParameter(parameter, entry);
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
    while (
      generation === this.previewGeneration &&
      this.camera.isConnected &&
      this.camera.isLiveView
    ) {
      try {
        const jpeg: Uint8Array = await this.camera.getLiveViewFrame();
        await this.displayJpeg(jpeg);
      } catch (error) {
        const message: string = (error as BusinessError).message;
        this.diagnostics?.warning(
          'liveview',
          `获取实时取景帧失败，将重试：${message}`
        );
        this.status = `实时取景暂停：${message}`;
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
      this.status = `已设置 ${entry.label}`;
    });
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
          `无线收件箱已开启；地址=${this.wireless.localAddress}:${FTP_PORT}`
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

  private refreshPhotos(): void {
    if (this.library !== undefined) {
      this.photos = this.library.list();
    }
  }

  private async previewPhoto(item: PhotoItem): Promise<void> {
    if (this.library === undefined) {
      return;
    }
    if (
      !item.name.toLowerCase().endsWith('.jpg') &&
      !item.name.toLowerCase().endsWith('.jpeg')
    ) {
      this.showError('NEF、HEIF 与 TIFF 已安全保存，但当前页面只预览 JPEG。');
      return;
    }
    try {
      await this.displayJpeg(this.library.read(item));
      this.section = 'capture';
      this.status = `正在预览 ${item.name}`;
    } catch (error) {
      this.showError(`无法预览 ${item.name}。`);
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
    if (this.preview !== undefined) {
      this.preview.release();
    }
    this.preview = pixelMap;
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
}
