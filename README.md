# Nikon Link

面向 Nikon Z 系列相机的三端原生连接、监看、拍摄与无线传图工具。

> 当前版本：**0.7.0 Release Candidate**
>
> 支持平台：**macOS · Android · iOS / iPadOS**
>
> 支持机型：**Nikon Z8 · Z f · Z6III · Z5II**

![Nikon Link macOS 原生实时取景与参数控制界面](docs/images/macos-monitor.png)

Nikon Link 把联机拍摄、实时取景、常用曝光控制、监看辅助、FTP 无线收件箱和本地
照片管理放进一个统一工作流。安装包全部采用平台原生技术栈，不包含 WebView、
HTML 或 JavaScript 运行时；仓库中的 Web/PWA 只保留为历史演示，不参与安装包
构建。

## 功能概览

| 工作流 | 主要能力 |
| --- | --- |
| 联机拍摄 | USB/PTP 相机识别、实时取景、SDRAM 拍摄与 JPEG 下载 |
| 曝光控制 | P、S、A、M 与 B门；快门、光圈、ISO感光度、曝光补偿 |
| 对焦与色彩 | AF-S、AF-C、MF、白平衡与 Nikon 设定优化校准 |
| 监看辅助 | 加亮显示条纹图案、自定义 3D `.cube` LUT、本地 2× 超采样 |
| 无线传图 | 内置 FTP/PASV 收件箱，接收 JPEG、NEF、HEIF/HEIC 与 TIFF |
| 文件管理 | 本地预览、导入、分享、定位、删除及写入系统“照片” |
| 使用模式 | “普通”模式保留常用操作，“专业”模式展开完整参数 |

应用会根据 P、S、A、M/B门拍摄模式锁定当前不可调的曝光参数，避免把无效设置
写入机身。LUT、加亮显示条纹图案和超采样只处理监看画面，不修改原片或相机设置。

## 平台能力

| 能力 | macOS | Android | iOS / iPadOS |
| --- | :---: | :---: | :---: |
| Nikon USB/PTP 连接 | ✓ | ✓ | — |
| Nikon 实时取景与快门控制 | ✓ | ✓ | — |
| 曝光、对焦与白平衡控制 | ✓ | ✓ | — |
| 自定义 `.cube` LUT 与加亮显示 | ✓ | ✓ | — |
| FTP 无线收件箱 | ✓ | ✓ | ✓ |
| 本地照片库 | ✓ | ✓ | ✓ |
| 系统镜头拍摄 | — | — | ✓ |
| iPadOS 外接 UVC 视频设备 | — | — | ✓ |

- **macOS** 使用 SwiftUI/AppKit 与 `libgphoto2` 的 Nikon PTP 后端。
- **Android** 使用原生 Android View、USB Host API 和项目内 PTP 实现。
- **iOS/iPadOS** 使用 SwiftUI、AVFoundation 与 PhotoKit；支持本机镜头、
  iPadOS 外接 UVC 视频设备和前台 FTP 接收。

iOS 的公开接口不向普通应用提供通用 Nikon USB/PTP 厂商控制，因此 iPhone 和
iPad 不会把 UVC 视频输入伪装成 Nikon 快门、光圈、ISO 或原图下载能力。接入
这些能力需要 Nikon 提供 iOS 协议授权或官方 SDK。

## 原生界面

### macOS：无线收件箱

![Nikon Link macOS 原生 FTP 无线传输界面](docs/images/macos-transfer.png)

### iPhone：联机拍摄与移动端导航

![Nikon Link iPhone 原生拍摄界面](docs/images/ios-capture.png)

以上截图来自当前原生应用在未连接相机时的实际运行界面。不同系统版本、屏幕尺寸
和连接状态下，控件布局与可用参数会按设备能力调整。

## 支持机型

所有支持机型使用 Nikon Vendor ID `0x04b0`。

| 机型 | USB Product ID | macOS | Android | iOS / iPadOS |
| --- | --- | --- | --- | --- |
| Nikon Z8 | `0x0451` | 原生 USB/PTP | 原生 USB/PTP | FTP；无 PTP |
| Nikon Z f | `0x0453` | 原生 USB/PTP | 原生 USB/PTP | FTP；无 PTP |
| Nikon Z6III | `0x0454` | 原生 USB/PTP | 原生 USB/PTP | FTP；无 PTP |
| Nikon Z5II | `0x0456` | PTP 兼容模式 | 原生 USB/PTP | FTP；无 PTP |

应用严格匹配上表设备。检测到其他 Nikon USB 型号时会显示实际 Product ID，
不会误报为受支持相机。Z5II 在部分 `libgphoto2` 正式版中可能显示为通用 PTP
相机，macOS 版会通过 USB Product ID 二次确认。

## 安装

正式安装包应从
[GitHub Releases](https://github.com/Tauber01/NikonLink/releases) 下载，并
使用同名 `.sha256` 文件核对完整性。

### macOS

1. 打开 `NikonLink-0.7.0-macOS-arm64.dmg`。
2. 将 **Nikon Link** 拖到镜像内的 **Applications** 快捷入口。
3. 首次打开若被系统拦截，请前往“系统设置 → 隐私与安全性”确认。

当前社区 DMG 使用 ad-hoc 签名，尚未使用 Apple Developer ID 公证。

### Android

安装 `NikonLink-0.7.0-android.apk`。当前 APK 使用 Android 调试证书签名，
用于侧载和硬件验证，不用于 Play 商店发布。

### iOS / iPadOS

`NikonLink-0.7.0-ios-signed.ipa` 必须使用有效的 Apple Developer 证书和描述
文件生成，才能安装到授权设备。文件名包含 `ios-unsigned` 的 IPA 只用于验证
应用内容和 CI 构建，不能安装到真机。

详细签名步骤见 [iOS 签名与发布](docs/IOS_SIGNING.md)。

## USB 联机拍摄

1. 将相机更新到较新的稳定固件。
2. 关闭 NX Tether、Camera Control Pro 和其他可能占用相机的软件。
3. 使用支持数据传输的 USB-C 线直连 Mac 或 Android USB Host 设备，避免扩展坞。
4. 打开 Nikon Link，点击“连接相机”，并允许系统授予 USB 访问权限。
5. 等待实时取景出现，再调整参数或拍摄。

Nikon PTP 实时取景由相机返回原生 JPEG 帧。界面中的显示尺寸、LUT、加亮显示和
本地 2× 超采样只影响预览渲染，不等同于更改机身视频文件类型、分辨率或编码。

## Wi-Fi 无线传图

1. 让 Mac、Android、iPhone 或 iPad 与相机处于同一可信 Wi-Fi 网络；也可以
   使用相机直连热点。
2. 打开 Nikon Link 的“传输”页，点击“开启无线接收”，记下页面显示的服务器
   地址。
3. 在相机“网络菜单 → 连接到 FTP 服务器”中创建配置：

   | 项目 | 值 |
   | --- | --- |
   | 服务器类型 | `FTP` |
   | 服务器地址 | Nikon Link 显示的局域网 IPv4 地址 |
   | 端口 | `2121` |
   | 用户名 | `nikonlink` |
   | 密码 | `nikonlink` |
   | PASV 模式 | 开启 |

4. 在相机中选择照片上传，或开启自动上传。收到的文件会自动进入 Nikon Link
   本地照片库。

如果机身中没有“连接到 FTP 服务器”，请先确认机型能力并更新相机固件。FTP
收件箱未提供互联网级加密或账户隔离，只应在可信局域网中临时开启；传输完成后
请停止接收。iOS/iPadOS 进入后台时会自动停止收件箱。

## 本地构建

### 环境要求

- macOS 14+、Apple Silicon
- Homebrew 与 `libgphoto2`
- OpenJDK 17、Android SDK 35、Gradle
- 完整 Xcode、iPhoneOS SDK 与已安装的 iOS 平台组件

### 一次构建三个平台

```sh
./scripts/build-all.sh
```

默认生成：

```text
dist/NikonLink-0.7.0-macOS-arm64.dmg
dist/NikonLink-0.7.0-android.apk
dist/NikonLink-0.7.0-ios-unsigned.ipa
```

每个安装包都附带同名 `.sha256` 校验文件。生成可安装的签名 IPA：

```sh
IOS_DEVELOPMENT_TEAM=你的TeamID ./scripts/build-ios.sh --signed
```

构建脚本和 CI 不会把历史 Web/PWA 资源复制进 DMG、APK 或 IPA。

## 验证状态

0.7.0 候选版本已覆盖编译、容器结构、签名状态、原生 UI 启动和安装包 Web 资源
扫描。由于构建机器当前未连接 Nikon Z8、Z f、Z6III 或 Z5II，USB/PTP、不同固件
和镜头组合仍以实机验收为发布门槛。

请按 [相机实机验收清单](docs/CAMERA_TEST_CHECKLIST.md) 逐项记录机型、固件、镜头、
数据线和主机系统版本。机身拒绝的参数会在界面中显示错误，不会静默伪装成功。

## 项目结构

```text
native/macos/      SwiftUI / AppKit 应用与 libgphoto2 集成
native/android/    原生 Android 应用与 USB Host PTP 实现
native/ios/        SwiftUI / AVFoundation / PhotoKit 应用
scripts/           DMG、APK、IPA 三端构建脚本
docs/              签名、术语、验收清单与 README 配图
```

更多资料：

- [Nikon 中文术语与 PTP 映射](docs/NIKON_TERMINOLOGY.md)
- [相机实机验收清单](docs/CAMERA_TEST_CHECKLIST.md)
- [iOS 签名与发布](docs/IOS_SIGNING.md)
- [安全说明](SECURITY.md)
- [版本记录](CHANGELOG.md)

## 许可与商标

应用源码使用 [MIT License](LICENSE)。macOS 安装包中的 gphoto2/libgphoto2 许可
见 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)。仓库不包含 Nikon 专有 SDK。

Nikon、Z8、Z f、Z6III 与 Z5II 为 Nikon Corporation 的商标。本项目与 Nikon
Corporation 无隶属、合作或背书关系。
