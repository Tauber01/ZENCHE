# Nikon Link

面向 macOS 与 Android 的 Nikon Z8 联机控制应用，同时保留可安装的 Web/PWA
版本。界面提供“普通 / 专业”双模式，覆盖联机拍摄、参数控制、实时监看、自动
导入与本地文件管理。

## Z8 原生能力

- USB 设备严格匹配 Nikon Z8（Vendor `0x04b0` / Product `0x0451`）
- PTP 会话、相机忙状态处理与断开恢复
- Nikon 实时取景：`StartLiveView` / `GetLiveViewImg` / `EndLiveView`
- Nikon SDRAM 拍摄并下载原图 JPEG
- 快门、光圈、ISO、曝光补偿、白平衡、对焦与曝光模式
- 拍摄文件存入设备本地照片库，可预览、下载、删除和撤销

macOS 使用 `libgphoto2` 的 Z8 后端；Android 使用系统 USB Host API 直接实现
PTP，因 Nikon 当前公开的 Remote Module SDK 未提供 Android 版本。

## 安装

### macOS

打开 `NikonLink-0.3.1-macOS-arm64.dmg`，将 **Nikon Link** 拖入“应用程序”。
当前社区构建为 ad-hoc 签名，未使用 Apple Developer ID 公证；首次打开时可能
需要在“系统设置 → 隐私与安全性”中确认。

### Android

安装 `NikonLink-0.3.1-android.apk`。这是使用 Android 调试证书签名的直接安装
版本，适合侧载验证，不用于 Play 商店发布。

## 连接 Z8

1. 将 Z8 更新到较新的稳定固件，关闭 NX Tether、Camera Control Pro 和其他会
   占用相机的程序。
2. 使用支持数据传输的 USB-C 线直连电脑或 Android USB Host 设备，避免扩展坞。
3. 打开 Nikon Link，选择“**Nikon Z8 原生 USB**”，允许 USB 访问。
4. 等待实时取景出现，再进行拍摄或参数调整。

> 当前构建完成了协议与软件侧验证，但构建机器上未连接 Z8，因此仍需一次实机
> 验收。不同固件、镜头和照片格式可能影响部分参数可写性；机身拒绝的参数会在
> 界面中直接显示错误，不会静默伪装成功。

## 本地构建

要求：macOS 14+、Apple Silicon、Swift Command Line Tools、Homebrew、
OpenJDK 17、Android SDK 35、Gradle。

```sh
./scripts/build-all.sh
```

产物生成在 `dist/`，并附带 SHA-256 校验文件。生成目录和安装包不提交到 Git；
正式发布应作为 GitHub Release assets 上传。

## 许可与商标

应用源码使用 MIT License。macOS 安装包中的 gphoto2/libgphoto2 许可见
`THIRD_PARTY_NOTICES.md`。仓库不包含 Nikon 专有 SDK。Nikon 与 Z8 为 Nikon
Corporation 的商标，本项目与 Nikon Corporation 无隶属或背书关系。
