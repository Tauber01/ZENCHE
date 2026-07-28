# Nikon Link

面向 macOS 与 Android 的 Nikon Z 系列原生联机控制应用。安装版不包含 WebView、
HTML 或 JavaScript 运行时：macOS 使用 SwiftUI/AppKit，Android 使用系统原生
View 与 USB Host API。仓库中的 Web/PWA 仅作为独立演示版本，不参与 DMG 或
APK 运行。界面提供“普通 / 专业”双模式，覆盖联机拍摄、参数控制、实时监看、
USB 与 Wi-Fi 图片导入及本地文件管理。

## 支持机型

| 机型 | USB Product ID | macOS | Android |
| --- | --- | --- | --- |
| Nikon Z8 | `0x0451` | 原生支持 | 原生支持 |
| Nikon Z f | `0x0453` | 原生支持 | 原生支持 |
| Nikon Z6III | `0x0454` | 原生支持 | 原生支持 |
| Nikon Z5II | `0x0456` | PTP 兼容模式 | 原生支持 |

所有机型使用 Nikon Vendor ID `0x04b0`。应用会严格匹配上表设备，检测到其他
Nikon USB 型号时会显示实际 Product ID，不会误报为已连接。

## 原生能力

- PTP 会话、相机忙状态处理与断开恢复
- Nikon 实时取景：`StartLiveView` / `GetLiveViewImg` / `EndLiveView`
- Nikon SDRAM 拍摄并下载原图 JPEG
- P、M、A、S、B 曝光模式；B 门支持 1–60 秒常用时长
- 快门、光圈、ISO、曝光补偿、白平衡与对焦控制
- 内置 FTP 无线收件箱，接收 JPEG、NEF、HEIF、HEIC 与 TIFF
- 拍摄和无线接收文件存入设备本地照片库，可预览、定位和删除

macOS 使用 `libgphoto2` 的 Nikon PTP 后端；Android 使用系统 USB Host API
直接实现 PTP，因 Nikon 当前公开的 Remote Module SDK 未提供 Android 版本。
Z5II 在当前 libgphoto2 正式版中可能显示为通用 PTP 相机，macOS 版会用 USB
Product ID 进行二次确认。

## 安装

### macOS

打开 `NikonLink-0.6.0-macOS-arm64.dmg`，将 **Nikon Link** 拖到安装盘中的
**Applications** 快捷入口。
当前社区构建为 ad-hoc 签名，未使用 Apple Developer ID 公证；首次打开时可能
需要在“系统设置 → 隐私与安全性”中确认。

### Android

安装 `NikonLink-0.6.0-android.apk`。这是使用 Android 调试证书签名的直接安装
版本，适合侧载验证，不用于 Play 商店发布。

## 连接相机

1. 将相机更新到较新的稳定固件，关闭 NX Tether、Camera Control Pro 和其他会
   占用相机的程序。
2. 使用支持数据传输的 USB-C 线直连电脑或 Android USB Host 设备，避免扩展坞。
3. 打开 Nikon Link，点击“**连接相机**”，允许 USB 访问。
4. 等待实时取景出现，再进行拍摄或参数调整。

## Wi-Fi 无线传图

1. 让 Mac/Android 设备与相机位于同一个 Wi-Fi 网络；也可以让相机建立直连热点，
   再让接收设备加入该热点。
2. 打开 Nikon Link 的“传输”页，点击“**开启无线接收**”，记下页面显示的
   服务器地址。
3. 在相机“网络菜单 → 连接到 FTP 服务器”中创建配置：服务器类型选择 `FTP`，
   端口填写 `2121`，用户名和密码均填写 `nikonlink`，PASV 模式选择“开启”。
4. 在相机中选择照片上传，或开启“自动上传”。收到的文件会自动进入 Nikon Link
   照片库。

如果机身中没有“连接到 FTP 服务器”，请先更新相机固件。无线收件箱只应在可信
局域网中开启，用完后点击“停止接收”。

> 当前构建完成了协议与软件侧验证，但构建机器上未连接 Z8，因此仍需一次实机
> 验收；Z f、Z6III、Z5II 同样需要逐机型验证。不同固件、镜头和照片格式可能
> 影响部分参数可写性；机身拒绝的参数会在界面中直接显示错误，不会静默伪装成功。

## 本地构建

要求：macOS 14+、Apple Silicon、SwiftUI/AppKit Command Line Tools、
Homebrew、OpenJDK 17、Android SDK 35、Gradle。

```sh
./scripts/build-all.sh
```

产物生成在 `dist/`，并附带 SHA-256 校验文件。生成目录和安装包不提交到 Git；
正式发布应作为 GitHub Release assets 上传。

## 许可与商标

应用源码使用 MIT License。macOS 安装包中的 gphoto2/libgphoto2 许可见
`THIRD_PARTY_NOTICES.md`。仓库不包含 Nikon 专有 SDK。Nikon、Z8、Z f、
Z6III 与 Z5II 为 Nikon Corporation 的商标，本项目与 Nikon Corporation
无隶属或背书关系。
