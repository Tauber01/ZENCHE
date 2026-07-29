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

帧澈 ZENCHE 是一套本地优先的原生相机工作流工具：通过 USB/PTP 连接并控制
Nikon 相机，通过 FTP、HTTP 或 WebDAV 接收影像，再在同一个应用里完成预览、
管理、导入与分享。

- 当前源码版本：**0.8.3**
- 原生目标：**macOS · Windows · Android · HarmonyOS · iOS / iPadOS**
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
| Capture · 拍摄 | USB 识别、实时取景、SDRAM 拍摄、JPEG 下载；支持 P / S / A / M 与 M 模式 B 门 |
| Control · 控制 | 快门、光圈、ISO、曝光补偿、对焦模式、白平衡与 Picture Control |
| Monitor · 监看 | 快门角度换算、加亮显示条纹、自定义 3D `.cube` LUT 与本地 2× 超采样 |
| Connect · 传输 | 内置 FTP/PASV、HTTP PUT/POST 与 WebDAV 收件箱 |
| Flow · 管理 | JPEG、NEF、HEIF/HEIC、TIFF 本地图库，支持导入、预览、分享与保存到系统相册 |
| Diagnose · 诊断 | 隐私脱敏的滚动日志、版本检查与预填 GitHub Issue |

LUT、条纹图案和超采样只影响监看画面，不修改原片，也不写入相机的视频设置。
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
版本及同名 `.sha256` 校验文件。0.8.3 的交付文件命名如下：

| 平台 | 文件 | 安装说明 |
| --- | --- | --- |
| macOS Apple Silicon | `ZENCHE-0.8.3-macOS-arm64.dmg` | 拖入 Applications；社区构建为 ad-hoc 签名，未公证 |
| Android | `ZENCHE-0.8.3-android.apk` | 允许侧载后安装；当前使用调试证书签名 |
| Windows x64 | `ZENCHE-0.8.3-Windows-x64-Setup.exe` | 推荐安装程序；当前未使用商业代码签名证书 |
| Windows x64 便携版 | `ZENCHE-0.8.3-Windows-x64.zip` | 完整解压后运行，不要单独移动 `libusb-1.0.dll` |
| HarmonyOS | `ZENCHE-0.8.3-HarmonyOS.hap` | 真机安装前需要有效的开发者签名与 Profile |
| iOS / iPadOS | `ZENCHE-0.8.3-ios-unsigned.ipa` | CI 验证产物；必须重新签名，不能直接安装 |

Windows 相机接口可能需要切换为 WinUSB。操作前请阅读
[Windows 构建与 USB 驱动](docs/WINDOWS_BUILD.md)，避免影响 NX Tether、
Camera Control Pro 或系统照片导入。HarmonyOS 与 iOS 的签名说明分别见
[HarmonyOS 构建与部署](docs/HARMONY_BUILD.md)和
[iOS 签名与发布](docs/IOS_SIGNING.md)。

校验下载文件：

```sh
shasum -a 256 -c ZENCHE-0.8.3-macOS-arm64.dmg.sha256
```

Windows PowerShell：

```powershell
Get-FileHash .\ZENCHE-0.8.3-Windows-x64-Setup.exe -Algorithm SHA256
```

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

## English

**帧澈 ZENCHE** is a local-first, cross-platform camera control and image
transfer tool for macOS, Windows, Android, HarmonyOS, and iOS/iPadOS.

It connects supported Nikon EXPEED 6/7 cameras through native USB/PTP
implementations where the operating system permits it, provides live view and
capture controls, receives images through FTP/HTTP/WebDAV, and keeps the files
in a local library for review and export.

- Source version: **0.8.3**
- Native targets: **macOS · Windows · Android · HarmonyOS · iOS / iPadOS**
- Camera profiles: **17 Nikon EXPEED 6 / 7 bodies**
- Downloads: [GitHub Releases](https://github.com/Tauber01/ZENCHE/releases)
- Hardware validation: [Camera test checklist](docs/CAMERA_TEST_CHECKLIST.md)

Public iOS/iPadOS APIs do not expose Nikon vendor-specific USB/PTP control to
ordinary apps. On Apple mobile platforms, ZENCHE supports the system camera,
compatible external UVC video input on iPadOS, local file workflows, and
foreground FTP/HTTP/WebDAV receiving.

## License

Source code is released under the [MIT License](LICENSE). Third-party notices
are listed in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

Nikon and all camera model names are trademarks of Nikon Corporation. This
project is not affiliated with, endorsed by, or sponsored by Nikon Corporation.
