# 帧澈 ZENCHE

**跨平台相机控制与影像传输工具**

*Capture · Connect · Flow*

> 连接相机，也连接完整工作流

帧澈 ZENCHE 想解决的事情很简单：拍摄时用电脑或移动设备看画面、调参数、按快门，
拍完以后把照片收回来。它不依赖 Nikon 专有 SDK，USB 联机部分基于 PTP，
无线传图既可使用相机自带的 FTP 功能，也可通过 HTTP 或 WebDAV 接收
其他手机、电脑和自动化工具发送的图片。

> 当前版本：**0.8.3 正式版**
>
> 支持平台：**macOS · Android · Windows · HarmonyOS · iOS / iPadOS**
>
> 支持机型：**EXPEED 6：Z7 · Z6 · Z50 · D780 · D6 · Z5 · Z7II · Z6II · Z fc · Z30；EXPEED 7：Z9 · Z8 · Z f · Z6III · Z50II · Z5II · ZR**

项目仍在实机测试阶段，重要拍摄请保留机内存储卡，不要把应用当作唯一备份。

![macOS 上的实时取景与参数控制](docs/images/macos-monitor.png)

## 目前能做什么

- 通过 USB 识别相机，打开实时取景并拍摄照片
- 调整快门、光圈、ISO、曝光补偿、对焦模式和白平衡
- 支持 P、S、A、M 以及 M 模式下的 B 门拍摄
- 将拍摄结果下载到本地照片库
- 在监看画面上使用条纹图案、自定义 `.cube` LUT 和 2× 超采样
- 通过内置 FTP/PASV、HTTP 上传和 WebDAV 收件箱接收 JPEG、NEF、HEIF/HEIC 和 TIFF
- 保存本地诊断日志，方便排查连接、拍摄和传输问题
- 各平台设置页统一提供软件更新、诊断日志和打赏支持入口

LUT、条纹图案和超采样只作用于预览画面，不会改动原片，也不会写入相机的视频设置。

## 平台支持

各平台并不是同一套功能的简单移植，当前进度如下：

| 平台 | USB 联机拍摄 | 无线收图 | 说明 |
| --- | :---: | --- | --- |
| macOS | 可用 | FTP、HTTP、WebDAV | SwiftUI/AppKit；通过 `libgphoto2` 连接相机 |
| Android | 可用 | FTP、HTTP、WebDAV | 原生 Android 应用；使用 USB Host |
| Windows | 待验收 | FTP、HTTP、WebDAV | WPF/.NET 8；代码已完成，仍需原生工具链和真机验证 |
| HarmonyOS | 待验收 | FTP、HTTP、WebDAV | Stage/ArkUI；代码已完成，仍需原生工具链和真机验证 |
| iOS / iPadOS | 不支持 | FTP、HTTP、WebDAV | 可使用本机镜头；iPadOS 支持外接 UVC 视频设备 |

iOS/iPadOS 的公开接口没有向普通应用开放 Nikon USB/PTP 厂商控制，因此 iPhone
和 iPad 目前不能通过 帧澈 ZENCHE 调节机身参数或下载 USB 原片。UVC 视频输入也只
作为视频源使用，不会被显示成 Nikon 相机控制。

## 支持的相机

目前内置了 17 款机型的设备档案：

- EXPEED 6：Nikon Z7、Z6、Z50、D780、D6、Z5、Z7II、Z6II、Z fc、Z30
- EXPEED 7：Nikon Z9、Z8、Z f、Z6III、Z50II、Z5II、ZR

不同固件、镜头和 USB 环境可能带来差异。部分机型在旧版 `libgphoto2` 中会被
识别为通用 PTP 相机，macOS 版会再读取 USB 信息确认机型。

<details>
<summary>USB Product ID</summary>

| 机型 | Product ID |
| --- | --- |
| Z7 | `0x0442` |
| Z6 | `0x0443` |
| Z50 | `0x0444` |
| D780 | `0x0446` |
| D6 | `0x0447` |
| Z5 | `0x0448` |
| Z7II | `0x044b` |
| Z6II | `0x044c` |
| Z fc | `0x044f` |
| Z9 | `0x0450` |
| Z8 | `0x0451` |
| Z30 | `0x0452` |
| Z f | `0x0453` |
| Z6III | `0x0454` |
| Z50II | `0x0455` |
| Z5II | `0x0456` |
| ZR | `0x0457` |

Nikon USB Vendor ID 为 `0x04b0`。

</details>

## 下载与安装

安装包和对应的 `.sha256` 校验文件发布在
[GitHub Releases](https://github.com/Tauber01/ZENCHE/releases)。

### macOS

1. 打开 `ZENCHE-0.8.3-macOS-arm64.dmg`。
2. 将 **帧澈 ZENCHE** 拖到镜像内的 **Applications** 快捷入口。
3. 首次打开若被系统拦截，请前往“系统设置 → 隐私与安全性”确认。

当前社区 DMG 使用 ad-hoc 签名，尚未使用 Apple Developer ID 公证。

### Android

安装 `ZENCHE-0.8.3-android.apk`。当前 APK 使用 Android 调试证书签名，
用于侧载和硬件验证，不用于 Play 商店发布。

### Windows

运行 `ZENCHE-0.8.3-Windows-x64-Setup.exe` 完成安装。也可下载便携 ZIP，
解压后运行 `ZENCHE.exe`，不要单独移动同目录下的 `libusb-1.0.dll`。
相机接口可能需要切换到 WinUSB，操作前请先阅读
[Windows 构建与 USB 驱动](docs/WINDOWS_BUILD.md)，以免影响 Nikon 官方软件。

### HarmonyOS

HAP 需要经过有效签名才能安装到支持 USB Host 的真机。环境、权限和签名配置见
[HarmonyOS 构建与部署](docs/HARMONY_BUILD.md)。

### iOS / iPadOS

IPA 必须使用有效的 Apple Developer 证书和描述文件签名。名称中带有
`ios-unsigned` 的文件只是 CI 构建产物，不能直接安装。具体步骤见
[iOS 签名与发布](docs/IOS_SIGNING.md)。

## USB 联机拍摄

1. 关闭 NX Tether、Camera Control Pro、“照片”、“图像捕捉”等可能占用相机的
   软件。
2. 使用支持数据传输的 USB-C 线直连设备，第一次排查时尽量不要经过扩展坞。
3. 打开 帧澈 ZENCHE，选择“连接相机”，并允许系统访问 USB 设备。
4. 实时取景出现后再调整参数或拍摄。

macOS 的系统 PTP 服务有时会先占用相机。应用会尝试释放并重新连接；如果仍然失败，
请退出其他相机软件，重新插拔相机后再试。

实时取景由相机返回 JPEG 帧。拍摄或修改参数时，画面短暂停顿属于正常现象。若机身
报告温度过高，应用会停止实时取景，此时应关闭相机并等待机身冷却。

## Wi-Fi 无线传图

先让相机和接收设备连到同一个可信局域网，然后在 帧澈 ZENCHE 的“传输”页开启
无线接收。相机端仍使用 FTP：

| 项目 | 设置 |
| --- | --- |
| 服务器地址 | 应用中显示的局域网 IPv4 地址 |
| 端口 | `2121` |
| 用户名 | `nikonlink` |
| 密码 | `nikonlink` |
| PASV 模式 | 开启 |

所有原生平台还会同时开启以下入口：

| 协议 | 地址或用法 |
| --- | --- |
| HTTP PUT/POST | `http://设备地址:8080/upload/文件名` |
| WebDAV PUT | `http://设备地址:8080/文件名` |
| HTTP POST 备用命名 | 请求地址使用 `/upload?filename=文件名`，或发送 `X-Filename` 请求头 |

HTTP/WebDAV 使用 Basic Auth，用户名和密码同样是 `nikonlink`，上传请求必须提供
`Content-Length`。例如：

```sh
curl --user nikonlink:nikonlink \
  --upload-file DSC_0001.NEF \
  http://192.168.1.20:8080/upload/DSC_0001.NEF
```

这些服务不加密，只适合在可信局域网内临时使用。
传输完成后请关闭接收，不要把端口暴露到公网。iOS/iPadOS 进入后台时会自动停止
所有无线接收服务。

![macOS 上的无线传图页面](docs/images/macos-transfer.png)

## 本地构建

在 macOS 上构建 macOS、Android 和可用的 iOS 产物：

```sh
./scripts/build-all.sh
```

常用环境包括：

- macOS 14+、Apple Silicon、Homebrew、`libgphoto2`
- OpenJDK 17、Android SDK 35
- 完整 Xcode 和 iOS SDK
- Windows 11、.NET 8 SDK、对应架构的 `libusb-1.0.dll`
- DevEco Studio 5.x、HarmonyOS SDK API 12+ 和应用签名

默认生成：

```text
dist/ZENCHE-0.8.3-macOS-arm64.dmg
dist/ZENCHE-0.8.3-android.apk
dist/ZENCHE-0.8.3-ios-unsigned.ipa
```

Windows 需要在 Windows 主机单独构建：

```powershell
.\scripts\build-windows.ps1 -LibUsbDll C:\path\to\libusb-1.0.dll
```

该命令同时生成 `ZENCHE-0.8.3-Windows-x64-Setup.exe` 安装程序和便携 ZIP。

HarmonyOS 可单独构建：

```sh
./scripts/build-harmony.sh
```

生成已签名的 iOS 安装包：

```sh
IOS_DEVELOPMENT_TEAM=你的TeamID ./scripts/build-ios.sh --signed
```

构建结果位于 `dist/`，每个安装包旁边会生成同名的 SHA-256 校验文件。

## 遇到问题

0.8.3 正式版本已覆盖编译、容器结构、签名状态、原生 UI 启动和原生安装包
扫描。Windows 源码和自包含包已通过 .NET 编译与 PE/ZIP 结构检查；HarmonyOS
源码、资源和未签名 HAP 构建已通过，签名、启动和真机测试仍待完成。
由于构建机器当前未连接全部 EXPEED 6 / 7 机型，USB/PTP、不同固件和镜头组合仍以
实机验收为发布门槛。

提交 Issue 前，建议先记录相机型号、固件、镜头、数据线和主机系统版本，并按
[相机实机验收清单](docs/CAMERA_TEST_CHECKLIST.md)复现一次。

应用内的“提交 GitHub Issue”会预填版本信息和一小段脱敏日志，最后仍由用户检查
并手动提交。照片和完整日志不会自动上传。各平台日志目录、保留时间和安全说明见
[安全策略](SECURITY.md)。

## 仓库结构

```text
native/macos/      macOS 应用
native/windows/    Windows 应用
native/android/    Android 应用
native/harmony/    HarmonyOS 应用
native/ios/        iOS / iPadOS 应用
scripts/           各平台构建脚本
docs/              构建、签名、术语和实机测试文档
```

相关文档：

- [Nikon 中文术语与 PTP 映射](docs/NIKON_TERMINOLOGY.md)
- [相机实机验收清单](docs/CAMERA_TEST_CHECKLIST.md)
- [Windows 构建与 USB 驱动](docs/WINDOWS_BUILD.md)
- [HarmonyOS 构建与部署](docs/HARMONY_BUILD.md)
- [iOS 签名与发布](docs/IOS_SIGNING.md)
- [版本记录](CHANGELOG.md)

## 许可

项目源码使用 [MIT License](LICENSE)。第三方组件许可见
[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)。

Nikon 及文中机型名为 Nikon Corporation 的商标。本项目与 Nikon Corporation
无隶属、合作或背书关系。

---

<a id="english"></a>

## English

帧澈 ZENCHE is a native macOS, Android, and iOS/iPadOS utility for connecting,
monitoring, controlling, and transferring files from Nikon cameras.

> Current version: **0.8.3 Stable Release**
>
> Platforms: **macOS · Android · iOS / iPadOS**
>
> EXPEED 6 cameras: **Nikon Z7 · Z6 · Z50 · D780 · D6 · Z5 · Z7II · Z6II · Z fc · Z30**
>
> EXPEED 7 cameras: **Nikon Z9 · Z8 · Z f · Z6III · Z50II · Z5II · ZR**

The interface separates creation into two clear workspaces. **Photo** contains
the shutter, exposure, focus, white balance, Picture Control, and local photo
workflow. **Video** contains live monitoring, zebra overlays, local 3D LUTs,
supersampling, and output controls. Files and wireless transfer live in a
separate management group.

### Features

| Workflow | Capabilities |
| --- | --- |
| Photo | USB/PTP detection, photo live view, SDRAM capture, and JPEG download |
| Photo controls | P/S/A/M and Bulb; shutter, aperture, ISO, exposure compensation, focus, and white balance |
| Video monitoring | Live view, zebra overlay, custom `.cube` LUT, and local 2× supersampling |
| Wireless transfer | FTP/PASV plus HTTP and WebDAV inboxes for JPEG, NEF, HEIF/HEIC, and TIFF |
| File management | Local preview, import, share, reveal, delete, and save to Photos |
| Settings | Software updates, diagnostic logs, and donation/support access on every platform |
| Experience modes | Simple mode for common actions; Pro mode for full controls |

LUTs, zebra overlays, and supersampling affect only the monitoring image. They
do not modify the original file or the camera's recording settings.

### Platform capabilities

| Capability | macOS | Android | iOS / iPadOS |
| --- | :---: | :---: | :---: |
| Nikon USB/PTP connection | ✓ | ✓ | — |
| Nikon live view and shutter control | ✓ | ✓ | — |
| Exposure, focus, and white-balance control | ✓ | ✓ | — |
| Custom `.cube` LUT and zebra overlay | ✓ | ✓ | — |
| FTP wireless inbox | ✓ | ✓ | ✓ |
| HTTP / WebDAV wireless inbox | ✓ | ✓ | ✓ |
| Local photo library | ✓ | ✓ | ✓ |
| System-camera capture | — | — | ✓ |
| External UVC video on iPadOS | — | — | ✓ |

- **macOS** uses SwiftUI/AppKit and the Nikon PTP backend from `libgphoto2`.
- **Android** uses native Android Views, USB Host, and the in-project PTP
  implementation.
- **iOS/iPadOS** uses SwiftUI, AVFoundation, and PhotoKit for system cameras,
  external UVC input on iPadOS, and foreground FTP/HTTP/WebDAV receiving.

Public iOS APIs do not expose general Nikon vendor-specific USB/PTP control to
ordinary applications. Nikon shutter, aperture, ISO, and original-file
download therefore require Nikon protocol authorization or an official SDK;
帧澈 ZENCHE does not present a UVC stream as native Nikon control.

### Supported EXPEED 6 and 7 cameras

All listed cameras use Nikon USB Vendor ID `0x04b0`.

| Camera | USB Product ID | macOS | Android | iOS / iPadOS |
| --- | --- | --- | --- | --- |
| Nikon Z7 | `0x0442` | Native USB/PTP | Native USB/PTP | No PTP |
| Nikon Z6 | `0x0443` | Native USB/PTP | Native USB/PTP | No PTP |
| Nikon Z50 | `0x0444` | Native USB/PTP | Native USB/PTP | No PTP |
| Nikon D780 | `0x0446` | Native USB/PTP | Native USB/PTP | No PTP |
| Nikon D6 | `0x0447` | Native USB/PTP | Native USB/PTP | No PTP |
| Nikon Z5 | `0x0448` | Native USB/PTP | Native USB/PTP | No PTP |
| Nikon Z7II | `0x044b` | Native USB/PTP | Native USB/PTP | No PTP |
| Nikon Z6II | `0x044c` | Native USB/PTP | Native USB/PTP | No PTP |
| Nikon Z fc | `0x044f` | Native USB/PTP | Native USB/PTP | No PTP |
| Nikon Z9 | `0x0450` | Native USB/PTP | Native USB/PTP | FTP; no PTP |
| Nikon Z8 | `0x0451` | Native USB/PTP | Native USB/PTP | FTP; no PTP |
| Nikon Z30 | `0x0452` | Native USB/PTP | Native USB/PTP | No PTP |
| Nikon Z f | `0x0453` | Native USB/PTP | Native USB/PTP | FTP; no PTP |
| Nikon Z6III | `0x0454` | Native USB/PTP | Native USB/PTP | FTP; no PTP |
| Nikon Z50II | `0x0455` | Native USB/PTP | Native USB/PTP | FTP; no PTP |
| Nikon Z5II | `0x0456` | PTP compatibility mode | Native USB/PTP | FTP; no PTP |
| Nikon ZR | `0x0457` | PTP compatibility mode | Native USB/PTP | FTP; no PTP |

帧澈 ZENCHE matches the Product ID first and can fall back to the USB product
name for newer profiles such as the ZR. An unsupported Nikon device is reported
with its actual Product ID instead of being presented as a supported camera.

### Install and connect

Download release artifacts and matching `.sha256` files from
[GitHub Releases](https://github.com/Tauber01/ZENCHE/releases).

1. Update the camera to a recent stable firmware.
2. Quit NX Tether, Camera Control Pro, Photos, Image Capture, and any software
   that may claim the PTP interface.
3. Connect the camera directly with a data-capable USB-C cable.
4. Open 帧澈 ZENCHE, choose **Connect camera**, and grant USB access.
5. Start live view, adjust supported controls, and capture.

Nikon PTP live view supplies JPEG frames. Display resolution, LUT, zebra, and
local 2× supersampling change only preview rendering, not the camera's video
file type, resolution, or codec.

### Local build

Requirements include macOS 14+ on Apple Silicon, Homebrew with `libgphoto2`,
OpenJDK 17, Android SDK 35, Gradle, and a complete Xcode installation.

```sh
./scripts/build-all.sh
```

The build produces macOS DMG, Android APK, and unsigned iOS IPA artifacts in
`dist/`, each with a matching SHA-256 checksum. See
[iOS signing](docs/IOS_SIGNING.md) for a device-installable IPA.

Hardware verification across every camera, firmware, lens, cable, and host
combination remains a release gate. Record results with the
[camera test checklist](docs/CAMERA_TEST_CHECKLIST.md).

The source is licensed under the [MIT License](LICENSE). Nikon and the camera
model names are trademarks of Nikon Corporation. This project is not affiliated
with, endorsed by, or sponsored by Nikon Corporation.

[Back to language selection](#nikon-link)

---

<a id="日本語"></a>

## 日本語

帧澈 ZENCHE は、Nikon カメラの接続、モニタリング、撮影制御、ファイル転送を
行う macOS・Android・iOS/iPadOS 向けネイティブアプリです。

> 現在のバージョン：**0.8.3 正式リリース**
>
> 対応プラットフォーム：**macOS · Android · iOS / iPadOS**
>
> EXPEED 6 対応機種：**Nikon Z7 · Z6 · Z50 · D780 · D6 · Z5 · Z7II · Z6II · Z fc · Z30**
>
> EXPEED 7 対応機種：**Nikon Z9 · Z8 · Z f · Z6III · Z50II · Z5II · ZR**

画面は **写真** と **動画** の二つの制作ワークスペースに分かれています。
写真にはシャッター、露出、フォーカス、ホワイトバランス、ピクチャーコントロール、
ローカル保存を集約し、動画にはライブビュー、ゼブラ表示、3D LUT、スーパー
サンプリング、出力設定を集約しています。ファイルとワイヤレス転送は管理グループ
から操作します。

### 主な機能

| ワークフロー | 機能 |
| --- | --- |
| 写真 | USB/PTP 検出、写真ライブビュー、SDRAM 撮影、JPEG ダウンロード |
| 写真制御 | P/S/A/M・バルブ、シャッター、絞り、ISO、露出補正、AF、ホワイトバランス |
| 動画モニター | ライブビュー、ゼブラ表示、カスタム `.cube` LUT、ローカル 2× スーパーサンプリング |
| ワイヤレス転送 | JPEG、NEF、HEIF/HEIC、TIFF を受信する FTP/PASV、HTTP、WebDAV 受信ボックス |
| ファイル管理 | ローカル表示、読み込み、共有、場所表示、削除、「写真」への保存 |
| 設定 | 全プラットフォーム共通の更新、診断ログ、寄付・サポート |
| 操作モード | よく使う操作だけの「普通」と、全設定を表示する「プロ」 |

LUT、ゼブラ表示、スーパーサンプリングはモニター画像だけに適用されます。原本や
カメラ本体の動画記録設定は変更しません。

### プラットフォーム別機能

| 機能 | macOS | Android | iOS / iPadOS |
| --- | :---: | :---: | :---: |
| Nikon USB/PTP 接続 | ✓ | ✓ | — |
| Nikon ライブビュー・シャッター制御 | ✓ | ✓ | — |
| 露出・フォーカス・ホワイトバランス | ✓ | ✓ | — |
| カスタム `.cube` LUT・ゼブラ表示 | ✓ | ✓ | — |
| FTP ワイヤレス受信 | ✓ | ✓ | ✓ |
| HTTP / WebDAV ワイヤレス受信 | ✓ | ✓ | ✓ |
| ローカル写真ライブラリ | ✓ | ✓ | ✓ |
| システムカメラ撮影 | — | — | ✓ |
| iPadOS 外付け UVC ビデオ | — | — | ✓ |

- **macOS**：SwiftUI/AppKit と `libgphoto2` の Nikon PTP バックエンド。
- **Android**：ネイティブ Android View、USB Host、内蔵 PTP 実装。
- **iOS/iPadOS**：SwiftUI、AVFoundation、PhotoKit。本体カメラ、iPadOS の
  外付け UVC、フォアグラウンド FTP/HTTP/WebDAV 受信に対応。

iOS の公開 API は、一般アプリに Nikon 固有の USB/PTP 制御を提供していません。
Nikon のシャッター、絞り、ISO、原本ダウンロードには、Nikon のプロトコル認可
または公式 SDK が必要です。帧澈 ZENCHE は UVC 入力を Nikon ネイティブ制御と
して表示しません。

### EXPEED 6 / 7 対応機種

全機種の Nikon USB Vendor ID は `0x04b0` です。

| 機種 | USB Product ID | macOS | Android | iOS / iPadOS |
| --- | --- | --- | --- | --- |
| Nikon Z7 | `0x0442` | ネイティブ USB/PTP | ネイティブ USB/PTP | PTP 非対応 |
| Nikon Z6 | `0x0443` | ネイティブ USB/PTP | ネイティブ USB/PTP | PTP 非対応 |
| Nikon Z50 | `0x0444` | ネイティブ USB/PTP | ネイティブ USB/PTP | PTP 非対応 |
| Nikon D780 | `0x0446` | ネイティブ USB/PTP | ネイティブ USB/PTP | PTP 非対応 |
| Nikon D6 | `0x0447` | ネイティブ USB/PTP | ネイティブ USB/PTP | PTP 非対応 |
| Nikon Z5 | `0x0448` | ネイティブ USB/PTP | ネイティブ USB/PTP | PTP 非対応 |
| Nikon Z7II | `0x044b` | ネイティブ USB/PTP | ネイティブ USB/PTP | PTP 非対応 |
| Nikon Z6II | `0x044c` | ネイティブ USB/PTP | ネイティブ USB/PTP | PTP 非対応 |
| Nikon Z fc | `0x044f` | ネイティブ USB/PTP | ネイティブ USB/PTP | PTP 非対応 |
| Nikon Z9 | `0x0450` | ネイティブ USB/PTP | ネイティブ USB/PTP | FTP、PTP 非対応 |
| Nikon Z8 | `0x0451` | ネイティブ USB/PTP | ネイティブ USB/PTP | FTP、PTP 非対応 |
| Nikon Z30 | `0x0452` | ネイティブ USB/PTP | ネイティブ USB/PTP | PTP 非対応 |
| Nikon Z f | `0x0453` | ネイティブ USB/PTP | ネイティブ USB/PTP | FTP、PTP 非対応 |
| Nikon Z6III | `0x0454` | ネイティブ USB/PTP | ネイティブ USB/PTP | FTP、PTP 非対応 |
| Nikon Z50II | `0x0455` | ネイティブ USB/PTP | ネイティブ USB/PTP | FTP、PTP 非対応 |
| Nikon Z5II | `0x0456` | PTP 互換モード | ネイティブ USB/PTP | FTP、PTP 非対応 |
| Nikon ZR | `0x0457` | PTP 互換モード | ネイティブ USB/PTP | FTP、PTP 非対応 |

Product ID を優先して照合し、ZR などの新しい機種では USB 製品名もフォール
バックとして利用します。未対応の Nikon USB 機器は、対応機種として誤表示せず、
実際の Product ID を表示します。

### インストールと接続

[GitHub Releases](https://github.com/Tauber01/ZENCHE/releases) から
インストールファイルと同名の `.sha256` をダウンロードしてください。

1. カメラを新しい安定版ファームウェアへ更新します。
2. NX Tether、Camera Control Pro、「写真」、「イメージキャプチャ」など、
   PTP インターフェースを使用するアプリを終了します。
3. データ通信対応 USB-C ケーブルでカメラを直接接続します。
4. 帧澈 ZENCHE で「カメラを接続」を選び、USB アクセスを許可します。
5. ライブビューを開始し、利用可能な設定を調整して撮影します。

Nikon PTP ライブビューは JPEG フレームを返します。表示サイズ、LUT、ゼブラ、
ローカル 2× スーパーサンプリングはプレビュー表示だけを変更し、カメラ本体の
動画ファイル形式、解像度、コーデックは変更しません。

### ローカルビルド

macOS 14+（Apple Silicon）、Homebrew と `libgphoto2`、OpenJDK 17、
Android SDK 35、Gradle、完全な Xcode 環境が必要です。

```sh
./scripts/build-all.sh
```

`dist/` に macOS DMG、Android APK、未署名 iOS IPA と各 SHA-256 チェックサムを
生成します。実機へインストールできる IPA については
[iOS 署名手順](docs/IOS_SIGNING.md)を参照してください。

すべての機種、ファームウェア、レンズ、ケーブル、ホスト環境の組み合わせは実機
検証がリリース条件です。[カメラ実機テストチェックリスト](docs/CAMERA_TEST_CHECKLIST.md)
に結果を記録してください。

ソースコードは [MIT License](LICENSE) で提供されます。Nikon および各機種名は
Nikon Corporation の商標です。本プロジェクトは Nikon Corporation との提携、
承認、スポンサー関係を持ちません。

[言語選択へ戻る](#nikon-link)
