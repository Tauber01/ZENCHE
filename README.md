<div align="center">
  <img src="icons/icon-512.png" width="128" height="128" alt="帧澈 ZENCHE 图标">
  <h1>帧澈 ZENCHE</h1>
  <p><strong>跨平台相机控制与影像传输工具</strong></p>
  <p><em>Capture · Connect · Flow</em></p>
  <p><strong>连接相机，也连接完整工作流</strong></p>

  <p>
    <a href="https://github.com/Tauber01/ZENCHE/actions/workflows/build.yml"><img src="https://github.com/Tauber01/ZENCHE/actions/workflows/build.yml/badge.svg" alt="Build"></a>
    <a href="https://github.com/Tauber01/ZENCHE/releases"><img src="https://img.shields.io/github/v/release/Tauber01/ZENCHE?display_name=tag&amp;sort=semver" alt="GitHub Release"></a>
    <a href="LICENSE"><img src="https://img.shields.io/github/license/Tauber01/ZENCHE" alt="MIT License"></a>
    <a href="https://github.com/Tauber01/ZENCHE/issues"><img src="https://img.shields.io/github/issues/Tauber01/ZENCHE" alt="GitHub Issues"></a>
  </p>
</div>

<p align="center">
  <a href="#简体中文">简体中文</a> ·
  <a href="#english">English</a> ·
  <a href="#日本語">日本語</a>
</p>

<a id="简体中文"></a>

## 简体中文

帧澈 ZENCHE 是一套本地优先的原生相机工作流工具：通过 USB/PTP 连接并控制
Nikon 相机，通过 FTP、HTTP 或 WebDAV 接收影像，再在同一个应用里完成预览、
管理、导入与分享。

- 当前源码版本：**1.1.0**
- 原生目标：**macOS · Windows · Android · HarmonyOS · iOS / iPadOS**
- 界面语言：**简体中文 · English · 日本語**（可在齿轮设置中即时切换）
- 相机档案：**17 款 Nikon EXPEED 6 / 7 机型**
- 项目仓库：[github.com/Tauber01/ZENCHE](https://github.com/Tauber01/ZENCHE)
- 安装包：[GitHub Releases](https://github.com/Tauber01/ZENCHE/releases)

> [!IMPORTANT]
> 已发布版本和实际可下载文件以 GitHub Releases 为准。项目仍在扩大实机验证范围；
> 重要拍摄请始终保留机内存储卡，不要把任何联机应用当作唯一备份。

<table>
  <tr>
    <td width="50%"><img src="docs/images/macos-monitor.png" alt="macOS 实时取景与参数控制"></td>
    <td width="50%"><img src="docs/images/macos-transfer.png" alt="macOS 无线影像传输"></td>
  </tr>
  <tr>
    <td align="center">实时取景与原生参数控制</td>
    <td align="center">FTP / HTTP / WebDAV 无线收件箱</td>
  </tr>
</table>

## 完整工作流

| 环节 | 能力 |
| --- | --- |
| Capture · 拍摄 | USB 识别、实时取景、SDRAM 拍摄、JPEG 下载；支持间隔拍摄、曝光包围、焦点包围与 B 门计时 |
| Control · 控制 | 快门、光圈、ISO、曝光补偿、对焦模式、白平衡与 Picture Control |
| Monitor · 监看 | 快门角度换算、RGB 直方图、波形、矢量示波器、峰值对焦、假色、条纹图案与自定义 3D `.cube` LUT |
| Connect · 传输 | 内置 FTP/PASV、HTTP PUT/POST 与 WebDAV 收件箱 |
| Flow · 管理 | 项目会话、命名模板、RAW + JPEG 配对、XMP 评级、双目标备份、SHA-256，以及本地图库导入、预览与分享 |
| Diagnose · 诊断 | 隐私脱敏的滚动日志、版本检查与预填 GitHub Issue |

LUT、直方图、波形、矢量示波器、峰值对焦、假色和条纹图案只影响监看画面，
不修改原片，也不写入相机的视频设置。
具体能力取决于平台、相机固件、镜头和当前拍摄模式。

## 平台支持

五个目标均为原生实现，不使用 WebView 复用界面。

| 平台 | Nikon USB/PTP | 无线收图 | 本地工作流 | 当前状态 |
| --- | :---: | :---: | :---: | --- |
| macOS | ✅ | FTP / HTTP / WebDAV | ✅ | SwiftUI/AppKit + `libgphoto2`，已接通 |
| Android | ✅ | FTP / HTTP / WebDAV | ✅ | Android Views + USB Host，已接通 |
| Windows | 🧪 | FTP / HTTP / WebDAV | ✅ | WPF/.NET 8 + `libusb`，实现完成，待扩大真机验收 |
| HarmonyOS | 🧪 | FTP / HTTP / WebDAV | ✅ | Stage/ArkUI + USB Host，实现完成，待扩大真机验收 |
| iOS / iPadOS | — | FTP / HTTP / WebDAV | ✅ | 支持系统相机；iPadOS 支持兼容的外接 UVC 视频设备 |

iOS/iPadOS 的公开 API 不向普通应用开放 Nikon 厂商 USB/PTP 控制，因此当前不能
通过 iPhone 或 iPad 调整 Nikon 机身参数或下载 USB 原片。外接 UVC 只作为视频源，
不会被标记为 Nikon 原生控制。

## 支持的相机

项目内置以下 17 款机型的 USB 档案：

- **EXPEED 6：** Z7、Z6、Z50、D780、D6、Z5、Z7II、Z6II、Z fc、Z30
- **EXPEED 7：** Z9、Z8、Z f、Z6III、Z50II、Z5II、ZR

<details>
<summary>查看 USB Product ID</summary>

| 机型 | Product ID | 机型 | Product ID |
| --- | --- | --- | --- |
| Z7 | `0x0442` | Z6 | `0x0443` |
| Z50 | `0x0444` | D780 | `0x0446` |
| D6 | `0x0447` | Z5 | `0x0448` |
| Z7II | `0x044b` | Z6II | `0x044c` |
| Z fc | `0x044f` | Z9 | `0x0450` |
| Z8 | `0x0451` | Z30 | `0x0452` |
| Z f | `0x0453` | Z6III | `0x0454` |
| Z50II | `0x0455` | Z5II | `0x0456` |
| ZR | `0x0457` |  |  |

Nikon USB Vendor ID 为 `0x04b0`。

</details>

机型档案表示应用能够正确识别设备并选择相应参数范围，不代表所有固件、镜头和
USB 主机组合均已完成实机验证。请使用
[相机实机验收清单](docs/CAMERA_TEST_CHECKLIST.md)记录结果。

## 下载与安装

前往 [GitHub Releases](https://github.com/Tauber01/ZENCHE/releases) 下载已发布
版本及同名 `.sha256` 校验文件。1.1.0 的交付文件命名如下：

| 平台 | 文件 | 安装说明 |
| --- | --- | --- |
| macOS Apple Silicon | `ZENCHE-1.1.0-macOS-arm64.dmg` | 拖入 Applications；社区构建为 ad-hoc 签名，未公证 |
| Android | `ZENCHE-1.1.0-android.apk` | 允许侧载后安装；当前使用调试证书签名 |
| Windows x64 | `ZENCHE-1.1.0-Windows-x64-Setup.exe` | 推荐安装程序；当前未使用商业代码签名证书 |
| Windows x64 便携版 | `ZENCHE-1.1.0-Windows-x64.zip` | 完整解压后运行，不要单独移动 `libusb-1.0.dll` |
| HarmonyOS | `ZENCHE-1.1.0-HarmonyOS.hap` | 真机安装前需要有效的开发者签名与 Profile |
| iOS / iPadOS | `ZENCHE-1.1.0-ios-unsigned.ipa` | CI 验证产物；必须重新签名，不能直接安装 |

Windows 相机接口可能需要切换为 WinUSB。操作前请阅读
[Windows 构建与 USB 驱动](docs/WINDOWS_BUILD.md)，避免影响 NX Tether、
Camera Control Pro 或系统照片导入。HarmonyOS 与 iOS 的签名说明分别见
[HarmonyOS 构建与部署](docs/HARMONY_BUILD.md)和
[iOS 签名与发布](docs/IOS_SIGNING.md)。

校验下载文件：

```sh
shasum -a 256 -c ZENCHE-1.1.0-macOS-arm64.dmg.sha256
```

Windows PowerShell：

```powershell
Get-FileHash .\ZENCHE-1.1.0-Windows-x64-Setup.exe -Algorithm SHA256
```

### 自动更新与 Mirror酱

五个原生客户端会在启用“启动时自动检查更新”后优先请求
[Mirror酱](https://mirrorchyan.com)，并在服务不可用、CDK 无效或没有可直接安装的
完整包时自动回退 GitHub Releases。设置页可填写可选 CDK；iOS / iPadOS 与 macOS
保存到系统钥匙串，Android 使用 Android Keystore，Windows 使用 DPAPI，
HarmonyOS 保存到应用私有设置，所有平台都不会把 CDK 写入诊断日志。

为避免破坏签名与平台安装状态，客户端不会直接覆盖应用文件，也不会应用
Mirror酱增量包；仅接受完整安装包并交给各平台原生安装流程。资源标识当前预留为
`ZENCHE`。在 Mirror酱完成资源注册和平台包映射前，客户端会显示“资源尚未配置”
并继续使用 GitHub，不影响原有更新检查。服务端接入与上传令牌配置请参考
[MirrorChyan 官方集成指南](https://github.com/MirrorChyan/docs)。

## USB 快速开始

1. 关闭 NX Tether、Camera Control Pro、照片、图像捕捉等可能占用 PTP 接口的软件。
2. 使用支持数据传输的 USB 线直连设备；首次排查时不要经过扩展坞。
3. 打开帧澈 ZENCHE，选择“连接相机”，并允许系统访问 USB 设备。
4. 等待实时取景出现，再调整参数或拍摄。
5. 在“文件”中确认影像已经写入本地图库后，再断开相机。

macOS 的系统 PTP 服务有时会先占用相机；应用会尝试释放并重新连接。拍摄或修改
参数时，实时取景短暂停顿属于正常现象。若机身报告温度过高，请停止取景并等待
相机冷却。

## Wi-Fi 无线传图

让相机和接收设备连接到同一个可信局域网，在“传输”页开启无线接收，然后按应用
显示的地址配置发送端。

| 协议 | 地址或设置 |
| --- | --- |
| FTP/PASV | `设备地址:2121`，用户名 `nikonlink`，密码 `nikonlink`，开启 PASV |
| HTTP PUT/POST | `http://设备地址:8080/upload/文件名` |
| WebDAV PUT | `http://设备地址:8080/文件名` |
| HTTP 备用命名 | `/upload?filename=文件名`，或使用 `X-Filename` 请求头 |

HTTP/WebDAV 使用同一组 Basic Auth 凭据，上传请求必须提供 `Content-Length`。

```sh
curl --user nikonlink:nikonlink \
  --upload-file DSC_0001.NEF \
  http://192.168.1.20:8080/upload/DSC_0001.NEF
```

这些入口没有 TLS 加密，只适合在可信局域网内临时开启。传输完成后请关闭接收，
不要将端口暴露到公网；iOS/iPadOS 进入后台时会自动停止无线服务。

## 本地构建

macOS 主机可统一构建 macOS、Android，并在工具链可用时构建 iOS 与 HarmonyOS：

```sh
./scripts/build-all.sh
```

常用环境：

- macOS 14+、Apple Silicon、Homebrew、`libgphoto2`
- OpenJDK 17、Android SDK 35、Gradle 8.10.2
- 完整 Xcode 与 iPhoneOS SDK
- DevEco Studio 6.0.1+、HarmonyOS SDK API 12+
- Windows 11、.NET 8 SDK、NSIS 3、对应架构的 `libusb-1.0.dll`

单平台构建：

```sh
./scripts/build-macos.sh
./scripts/build-android.sh
./scripts/build-ios.sh --unsigned
./scripts/build-harmony.sh
```

Windows 需在 Windows 主机运行：

```powershell
.\scripts\build-windows.ps1 `
  -Runtime win-x64 `
  -LibUsbDll C:\path\to\libusb-1.0.dll
```

生成已签名 iOS 包：

```sh
IOS_DEVELOPMENT_TEAM=你的TeamID ./scripts/build-ios.sh --signed
```

所有产物写入 `dist/`，并生成 SHA-256 校验文件。运行共享测试：

```sh
npm test
```

> [!NOTE]
> 为保持已有安装的升级兼容性，部分工程目录、scheme、包名和环境变量仍保留
> `NikonLink` / `com.tauber.nikonlink` 技术标识；面向用户的产品品牌与交付文件名
> 均为“帧澈 ZENCHE”。

## 仓库结构

```text
native/
  macos/          SwiftUI / AppKit
  windows/        WPF / .NET 8
  android/        Android Views / USB Host
  harmony/        Stage / ArkUI
  ios/            SwiftUI / AVFoundation / PhotoKit
scripts/          构建、签名与打包脚本
docs/             平台、术语、安全与实机验收文档
icons/            产品图标与品牌资产
PV/               宣传视频工程与交付说明
```

延伸阅读：

- [版本记录](CHANGELOG.md)
- [Nikon 中文术语与 PTP 映射](docs/NIKON_TERMINOLOGY.md)
- [相机实机验收清单](docs/CAMERA_TEST_CHECKLIST.md)
- [Windows 构建与 USB 驱动](docs/WINDOWS_BUILD.md)
- [HarmonyOS 构建与部署](docs/HARMONY_BUILD.md)
- [iOS 签名与发布](docs/IOS_SIGNING.md)
- [安全策略](SECURITY.md)
- [第三方许可](THIRD_PARTY_NOTICES.md)

## 反馈与贡献

提交问题前，请记录相机型号、固件、镜头、数据线、主机系统和复现步骤，并附上应用
生成的脱敏诊断信息：

- [提交 Issue](https://github.com/Tauber01/ZENCHE/issues/new/choose)
- [查看现有 Issues](https://github.com/Tauber01/ZENCHE/issues)
- [安全漏洞报告](SECURITY.md)

应用不会自动上传照片或完整日志。预填 Issue 会先交给用户检查，再由用户手动提交。

## 许可与商标

项目源码使用 [MIT License](LICENSE)，第三方组件说明见
[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)。

Nikon 及文中相机型号为 Nikon Corporation 的商标。本项目与 Nikon Corporation
无隶属、合作、赞助或背书关系。

<a id="english"></a>

## English

**帧澈 ZENCHE** is a local-first, cross-platform camera control and image
transfer tool for macOS, Windows, Android, HarmonyOS, and iOS/iPadOS.

It connects supported Nikon EXPEED 6/7 cameras through native USB/PTP
implementations where the operating system permits it, provides live view and
capture controls, receives images through FTP/HTTP/WebDAV, and keeps the files
in a local library for review and export.

- Source version: **1.1.0**
- Native targets: **macOS · Windows · Android · HarmonyOS · iOS / iPadOS**
- Interface languages: **Simplified Chinese · English · Japanese** (switch instantly from the gear settings)
- Camera profiles: **17 Nikon EXPEED 6 / 7 bodies**
- Downloads: [GitHub Releases](https://github.com/Tauber01/ZENCHE/releases)
- Hardware validation: [Camera test checklist](docs/CAMERA_TEST_CHECKLIST.md)

> [!IMPORTANT]
> Published versions and downloadable files are defined by GitHub Releases.
> Hardware validation is still expanding. Always keep the camera memory card
> as an independent copy during important work.

### Complete workflow

| Stage | Capabilities |
| --- | --- |
| Capture | USB detection, live view, SDRAM capture, JPEG download, interval capture, exposure bracketing, focus bracketing, and timed Bulb |
| Control | Shutter speed, aperture, ISO, exposure compensation, focus mode, white balance, and Picture Control |
| Monitor | Shutter-angle conversion, RGB histograms, waveform, vectorscope, focus peaking, false color, zebra, and custom 3D `.cube` LUTs |
| Connect | Built-in FTP/PASV, HTTP PUT/POST, and WebDAV inboxes |
| Flow | Project sessions, naming templates, RAW + JPEG pairing, XMP ratings, dual-destination backup, SHA-256, and local import, preview, and sharing |
| Diagnose | Privacy-redacted rolling logs, update checks, and prefilled GitHub Issues |

LUTs, scopes, focus peaking, false color, and zebra overlays affect only the
monitoring image. They do not modify the original file or write video settings
to the camera.
Capabilities vary with the platform, camera firmware, lens, and shooting mode.

### Platform support

All five targets use native implementations rather than a shared WebView UI.

| Platform | Nikon USB/PTP | Wireless inbox | Local workflow | Current status |
| --- | :---: | :---: | :---: | --- |
| macOS | ✅ | FTP / HTTP / WebDAV | ✅ | SwiftUI/AppKit + `libgphoto2`; connected |
| Android | ✅ | FTP / HTTP / WebDAV | ✅ | Android Views + USB Host; connected |
| Windows | 🧪 | FTP / HTTP / WebDAV | ✅ | WPF/.NET 8 + `libusb`; implemented, broader hardware validation pending |
| HarmonyOS | 🧪 | FTP / HTTP / WebDAV | ✅ | Stage/ArkUI + USB Host; implemented, broader hardware validation pending |
| iOS / iPadOS | — | FTP / HTTP / WebDAV | ✅ | System camera; compatible external UVC video input on iPadOS |

Public iOS/iPadOS APIs do not expose Nikon vendor-specific USB/PTP control to
ordinary apps. On Apple mobile platforms, ZENCHE supports the system camera,
compatible external UVC video input on iPadOS, local file workflows, and
foreground FTP/HTTP/WebDAV receiving.

### Supported cameras

- **EXPEED 6:** Z7, Z6, Z50, D780, D6, Z5, Z7II, Z6II, Z fc, and Z30
- **EXPEED 7:** Z9, Z8, Z f, Z6III, Z50II, Z5II, and ZR

All profiles use Nikon USB Vendor ID `0x04b0`. A built-in camera profile means
that ZENCHE can identify the device and select the intended parameter range; it
does not mean that every firmware, lens, cable, and USB host combination has
completed hardware validation.

<details>
<summary>USB Product IDs</summary>

| Camera | Product ID | Camera | Product ID |
| --- | --- | --- | --- |
| Z7 | `0x0442` | Z6 | `0x0443` |
| Z50 | `0x0444` | D780 | `0x0446` |
| D6 | `0x0447` | Z5 | `0x0448` |
| Z7II | `0x044b` | Z6II | `0x044c` |
| Z fc | `0x044f` | Z9 | `0x0450` |
| Z8 | `0x0451` | Z30 | `0x0452` |
| Z f | `0x0453` | Z6III | `0x0454` |
| Z50II | `0x0455` | Z5II | `0x0456` |
| ZR | `0x0457` |  |  |

</details>

### Download and install

Download published packages and their matching `.sha256` files from
[GitHub Releases](https://github.com/Tauber01/ZENCHE/releases). Version 1.1.0
uses the following delivery names:

| Platform | File | Installation note |
| --- | --- | --- |
| macOS Apple Silicon | `ZENCHE-1.1.0-macOS-arm64.dmg` | Drag to Applications; community build is ad-hoc signed and not notarized |
| Android | `ZENCHE-1.1.0-android.apk` | Sideloading required; currently signed with a debug certificate |
| Windows x64 | `ZENCHE-1.1.0-Windows-x64-Setup.exe` | Recommended installer; no commercial code-signing certificate |
| Windows x64 portable | `ZENCHE-1.1.0-Windows-x64.zip` | Extract completely; keep `libusb-1.0.dll` beside the executable |
| HarmonyOS | `ZENCHE-1.1.0-HarmonyOS.hap` | A valid developer signature and Profile are required for device installation |
| iOS / iPadOS | `ZENCHE-1.1.0-ios-unsigned.ipa` | CI validation artifact; it must be signed before installation |

Windows may require binding the camera PTP interface to WinUSB. Read
[Windows build and USB driver](docs/WINDOWS_BUILD.md) first, because changing
the interface driver can affect NX Tether, Camera Control Pro, or system photo
import. See [HarmonyOS build and deployment](docs/HARMONY_BUILD.md) and
[iOS signing and release](docs/IOS_SIGNING.md) for platform signing details.

### Automatic updates and MirrorChyan

When **Automatically check for updates at launch** is enabled, all five native
clients query [MirrorChyan](https://mirrorchyan.com) first and fall back to
GitHub Releases when the service is unavailable, the CDK is invalid, or no
directly installable full package is returned. The optional CDK is stored in
the Apple Keychain on iOS, iPadOS, and macOS, Android Keystore on Android,
DPAPI on Windows, and private app settings on HarmonyOS. It is never written
to diagnostic logs.

To preserve code signatures and platform installation state, clients do not
overwrite application files or apply MirrorChyan incremental packages. They
accept full installers only and hand them to the native installation flow.
The reserved resource ID is `ZENCHE`. Until that resource and its platform
package mappings are registered with MirrorChyan, clients report that the
resource is not configured and continue using GitHub. See the
[official MirrorChyan integration guide](https://github.com/MirrorChyan/docs)
for server-side registration and upload-token setup.

### USB quick start

1. Quit NX Tether, Camera Control Pro, Photos, Image Capture, and other software
   that may claim the PTP interface.
2. Connect the camera directly with a data-capable USB cable. Avoid a hub while
   troubleshooting the first connection.
3. Open ZENCHE, choose **Connect camera**, and grant USB access.
4. Wait for live view before changing parameters or capturing.
5. Confirm that the image appears in the local library before disconnecting.

The macOS PTP service may claim the camera first; ZENCHE attempts to release and
reconnect it. A short live-view pause during capture or parameter changes is
normal. Stop live view and let the camera cool if it reports overheating.

### Wi-Fi image transfer

Connect the camera and receiver to the same trusted LAN, enable wireless
receiving in ZENCHE, and configure the sender with the address shown by the app.

| Protocol | Address or setting |
| --- | --- |
| FTP/PASV | `device-address:2121`; username `nikonlink`; password `nikonlink`; PASV enabled |
| HTTP PUT/POST | `http://device-address:8080/upload/file-name` |
| WebDAV PUT | `http://device-address:8080/file-name` |
| Alternate HTTP naming | `/upload?filename=file-name`, or an `X-Filename` request header |

HTTP/WebDAV uses the same credentials through Basic Auth and requires
`Content-Length`.

```sh
curl --user nikonlink:nikonlink \
  --upload-file DSC_0001.NEF \
  http://192.168.1.20:8080/upload/DSC_0001.NEF
```

These services do not provide TLS. Enable them only temporarily on a trusted
LAN and never expose the ports to the public Internet. iOS/iPadOS stops all
wireless listeners when the app enters the background.

### Local build

On macOS, build macOS and Android plus iOS and HarmonyOS when their toolchains
are available:

```sh
./scripts/build-all.sh
```

Individual targets:

```sh
./scripts/build-macos.sh
./scripts/build-android.sh
./scripts/build-ios.sh --unsigned
./scripts/build-harmony.sh
```

Build Windows on a Windows host:

```powershell
.\scripts\build-windows.ps1 `
  -Runtime win-x64 `
  -LibUsbDll C:\path\to\libusb-1.0.dll
```

All artifacts are written to `dist/` with SHA-256 checksum files. Run shared
tests with `npm test`. Some project directories, schemes, package identifiers,
and environment variables retain `NikonLink` / `com.tauber.nikonlink` for
upgrade compatibility; all public branding and delivery filenames use ZENCHE.

### Feedback, license, and trademarks

Before opening an [Issue](https://github.com/Tauber01/ZENCHE/issues), record the
camera, firmware, lens, cable, host OS, reproduction steps, and redacted
diagnostics. ZENCHE does not automatically upload photos or complete logs.

Source code is released under the [MIT License](LICENSE). Third-party notices
are listed in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

Nikon and all camera model names are trademarks of Nikon Corporation. This
project is not affiliated with, endorsed by, or sponsored by Nikon Corporation.

<a id="日本語"></a>

## 日本語

**帧澈 ZENCHE** は、macOS、Windows、Android、HarmonyOS、iOS/iPadOS に対応する、
ローカル優先設計のクロスプラットフォーム・カメラ制御／画像転送ツールです。
OS が許可する環境では Nikon カメラを USB/PTP で接続・制御し、FTP、HTTP、
WebDAV で画像を受信して、同じアプリ内でプレビュー、管理、読み込み、共有まで
行えます。

- 現在のソースバージョン：**1.1.0**
- ネイティブ対象：**macOS · Windows · Android · HarmonyOS · iOS / iPadOS**
- 表示言語：**簡体字中国語 · English · 日本語**（歯車の設定から即時切り替え）
- カメラプロファイル：**Nikon EXPEED 6 / 7 の 17 機種**
- ダウンロード：[GitHub Releases](https://github.com/Tauber01/ZENCHE/releases)
- 実機検証：[カメラ実機テストチェックリスト](docs/CAMERA_TEST_CHECKLIST.md)

> [!IMPORTANT]
> 公開済みバージョンと実際にダウンロードできるファイルは GitHub Releases を
> 正とします。現在も実機検証範囲を拡大中です。重要な撮影ではカメラ内の
> メモリーカードを必ず独立したコピーとして残してください。

### ワークフロー

| 工程 | 機能 |
| --- | --- |
| Capture · 撮影 | USB 検出、ライブビュー、SDRAM 撮影、JPEG ダウンロード、インターバル撮影、露出ブラケット、フォーカスブラケット、時間指定バルブ |
| Control · 制御 | シャッター速度、絞り、ISO、露出補正、フォーカスモード、ホワイトバランス、Picture Control |
| Monitor · モニター | シャッター角度換算、RGB ヒストグラム、波形、ベクトルスコープ、フォーカスピーキング、フォルスカラー、ゼブラ、カスタム 3D `.cube` LUT |
| Connect · 転送 | 内蔵 FTP/PASV、HTTP PUT/POST、WebDAV 受信ボックス |
| Flow · 管理 | プロジェクトセッション、命名テンプレート、RAW + JPEG ペアリング、XMP 評価、二重保存、SHA-256、ローカル読み込み、プレビュー、共有 |
| Diagnose · 診断 | プライバシー情報を除去したローテーションログ、更新確認、入力済み GitHub Issue |

LUT、スコープ、フォーカスピーキング、フォルスカラー、ゼブラはモニター画像だけに
適用されます。原本を変更したり、カメラ本体の動画設定へ書き込んだりしません。利用できる機能は、
プラットフォーム、ファームウェア、レンズ、撮影モードによって異なります。

### プラットフォーム対応

5 つの対象はすべてネイティブ実装で、共通 WebView UI は使用していません。

| プラットフォーム | Nikon USB/PTP | ワイヤレス受信 | ローカルワークフロー | 現在の状態 |
| --- | :---: | :---: | :---: | --- |
| macOS | ✅ | FTP / HTTP / WebDAV | ✅ | SwiftUI/AppKit + `libgphoto2`、接続済み |
| Android | ✅ | FTP / HTTP / WebDAV | ✅ | Android Views + USB Host、接続済み |
| Windows | 🧪 | FTP / HTTP / WebDAV | ✅ | WPF/.NET 8 + `libusb`、実装済み、実機検証拡大中 |
| HarmonyOS | 🧪 | FTP / HTTP / WebDAV | ✅ | Stage/ArkUI + USB Host、実装済み、実機検証拡大中 |
| iOS / iPadOS | — | FTP / HTTP / WebDAV | ✅ | システムカメラ、iPadOS の互換外付け UVC 入力 |

iOS/iPadOS の公開 API は、一般アプリに Nikon 固有の USB/PTP 制御を提供して
いません。Apple のモバイル環境では、システムカメラ、iPadOS の互換外付け UVC
入力、ローカルファイル管理、フォアグラウンドの FTP/HTTP/WebDAV 受信に対応します。

### 対応カメラ

- **EXPEED 6：** Z7、Z6、Z50、D780、D6、Z5、Z7II、Z6II、Z fc、Z30
- **EXPEED 7：** Z9、Z8、Z f、Z6III、Z50II、Z5II、ZR

全プロファイルの Nikon USB Vendor ID は `0x04b0` です。内蔵プロファイルは、
機器を識別して想定されるパラメーター範囲を選択できることを示しますが、すべての
ファームウェア、レンズ、ケーブル、USB ホストの組み合わせで実機検証済みという
意味ではありません。

<details>
<summary>USB Product ID</summary>

| 機種 | Product ID | 機種 | Product ID |
| --- | --- | --- | --- |
| Z7 | `0x0442` | Z6 | `0x0443` |
| Z50 | `0x0444` | D780 | `0x0446` |
| D6 | `0x0447` | Z5 | `0x0448` |
| Z7II | `0x044b` | Z6II | `0x044c` |
| Z fc | `0x044f` | Z9 | `0x0450` |
| Z8 | `0x0451` | Z30 | `0x0452` |
| Z f | `0x0453` | Z6III | `0x0454` |
| Z50II | `0x0455` | Z5II | `0x0456` |
| ZR | `0x0457` |  |  |

</details>

### ダウンロードとインストール

[GitHub Releases](https://github.com/Tauber01/ZENCHE/releases) から公開済み
パッケージと同名の `.sha256` ファイルをダウンロードしてください。1.1.0 の
配布ファイル名は次のとおりです。

| プラットフォーム | ファイル | インストール上の注意 |
| --- | --- | --- |
| macOS Apple Silicon | `ZENCHE-1.1.0-macOS-arm64.dmg` | Applications へドラッグ。コミュニティ版は ad-hoc 署名で未公証 |
| Android | `ZENCHE-1.1.0-android.apk` | サイドロードが必要。現在はデバッグ証明書で署名 |
| Windows x64 | `ZENCHE-1.1.0-Windows-x64-Setup.exe` | 推奨インストーラー。商用コード署名証明書は未使用 |
| Windows x64 ポータブル | `ZENCHE-1.1.0-Windows-x64.zip` | 完全に展開し、`libusb-1.0.dll` を実行ファイルと同じ場所に保持 |
| HarmonyOS | `ZENCHE-1.1.0-HarmonyOS.hap` | 実機インストールには有効な開発者署名と Profile が必要 |
| iOS / iPadOS | `ZENCHE-1.1.0-ios-unsigned.ipa` | CI 検証用。インストール前に署名が必要 |

Windows ではカメラの PTP インターフェースを WinUSB に割り当てる必要がある場合が
あります。NX Tether、Camera Control Pro、システムの写真読み込みへ影響する可能性
があるため、先に [Windows ビルドと USB ドライバー](docs/WINDOWS_BUILD.md)を
確認してください。署名については
[HarmonyOS ビルドと配備](docs/HARMONY_BUILD.md)および
[iOS 署名とリリース](docs/IOS_SIGNING.md)を参照してください。

### 自動更新と MirrorChyan

「起動時にアップデートを自動確認」を有効にすると、5 つのネイティブクライアントは
まず [MirrorChyan](https://mirrorchyan.com) を確認し、サービスを利用できない場合、
CDK が無効な場合、または直接インストールできる完全パッケージが返らない場合に
GitHub Releases へ自動的に切り替えます。任意の CDK は iOS / iPadOS と macOS
では Apple Keychain、Android では Android Keystore、Windows では DPAPI、
HarmonyOS ではアプリの非公開設定に保存され、診断ログには記録されません。

コード署名と各プラットフォームのインストール状態を保護するため、クライアントは
アプリファイルを直接上書きせず、MirrorChyan の差分パッケージも適用しません。
完全なインストーラーのみを各 OS の標準インストール手順へ渡します。予約済みの
リソース ID は `ZENCHE` です。MirrorChyan 側でリソース登録とプラットフォーム別
パッケージの対応付けが完了するまでは「リソース未設定」と表示し、GitHub による
更新確認を継続します。サーバー側の登録とアップロードトークン設定は
[MirrorChyan 公式統合ガイド](https://github.com/MirrorChyan/docs)を参照してください。

### USB クイックスタート

1. NX Tether、Camera Control Pro、「写真」、「イメージキャプチャ」など、
   PTP インターフェースを使用するソフトウェアを終了します。
2. データ通信対応 USB ケーブルでカメラを直接接続します。初回の問題切り分けでは
   ハブを使用しないでください。
3. ZENCHE を開き、「カメラを接続」を選択して USB アクセスを許可します。
4. ライブビューが表示されてから、パラメーター変更や撮影を行います。
5. 切断前に画像がローカルライブラリへ保存されたことを確認します。

macOS の PTP サービスが先にカメラを占有する場合、ZENCHE は解放と再接続を
試みます。撮影や設定変更中の短いライブビュー停止は正常です。カメラが過熱を
報告した場合はライブビューを停止し、冷却を待ってください。

### Wi-Fi 画像転送

カメラと受信端末を同じ信頼できる LAN に接続し、ZENCHE でワイヤレス受信を
有効にして、アプリに表示されるアドレスを送信側へ設定します。

| プロトコル | アドレスまたは設定 |
| --- | --- |
| FTP/PASV | `端末アドレス:2121`、ユーザー名 `nikonlink`、パスワード `nikonlink`、PASV を有効化 |
| HTTP PUT/POST | `http://端末アドレス:8080/upload/ファイル名` |
| WebDAV PUT | `http://端末アドレス:8080/ファイル名` |
| HTTP 代替命名 | `/upload?filename=ファイル名`、または `X-Filename` リクエストヘッダー |

HTTP/WebDAV は同じ認証情報の Basic Auth を使用し、`Content-Length` が必要です。

```sh
curl --user nikonlink:nikonlink \
  --upload-file DSC_0001.NEF \
  http://192.168.1.20:8080/upload/DSC_0001.NEF
```

これらのサービスは TLS を提供しません。信頼できる LAN 内で一時的にだけ有効にし、
ポートをインターネットへ公開しないでください。iOS/iPadOS ではアプリがバック
グラウンドへ移行すると、すべてのワイヤレス受信を停止します。

### ローカルビルド

macOS では macOS と Android をビルドし、利用可能なツールチェーンに応じて
iOS と HarmonyOS もビルドできます。

```sh
./scripts/build-all.sh
```

個別ターゲット：

```sh
./scripts/build-macos.sh
./scripts/build-android.sh
./scripts/build-ios.sh --unsigned
./scripts/build-harmony.sh
```

Windows は Windows ホストでビルドします。

```powershell
.\scripts\build-windows.ps1 `
  -Runtime win-x64 `
  -LibUsbDll C:\path\to\libusb-1.0.dll
```

すべての成果物は `dist/` に出力され、SHA-256 チェックサムが生成されます。
共有テストは `npm test` で実行します。アップグレード互換性を維持するため、
一部のディレクトリ、scheme、パッケージ識別子、環境変数には
`NikonLink` / `com.tauber.nikonlink` が残っていますが、公開ブランドと配布
ファイル名はすべて ZENCHE です。

### フィードバック、ライセンス、商標

[Issue](https://github.com/Tauber01/ZENCHE/issues) を作成する前に、カメラ、
ファームウェア、レンズ、ケーブル、ホスト OS、再現手順、匿名化済み診断情報を
記録してください。ZENCHE が写真や完全なログを自動アップロードすることは
ありません。

ソースコードは [MIT License](LICENSE) で公開されています。第三者コンポーネント
については [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) を参照してください。

Nikon および各カメラ機種名は Nikon Corporation の商標です。本プロジェクトは
Nikon Corporation と提携、承認、スポンサー関係にありません。
