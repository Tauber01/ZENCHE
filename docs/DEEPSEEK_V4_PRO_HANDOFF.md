# 帧澈 ZENCHE 项目交接说明（DeepSeek V4 Pro）

> 盘点时间：2026-07-30（Asia/Shanghai）  
> 盘点范围：本地工作区、Git 历史、GitHub PR / Issue / Release / Actions、五端原生源码、
> 构建脚本、测试、安装包与宣传素材。  
> 本文是交接快照，不替代 `AGENTS.md`、平台构建文档和实机验收清单。

## 0. 2026-07-30 缺陷修复增量

本交接文档初稿完成后，已从 `origin/main` 新建
`codex/fix-known-issues`，针对 GitHub #21、#22、#23 完成本地代码修复：

- Android、HarmonyOS、Windows 的照片快门按 `0xD100` → `0x500D` 回退，视频
  快门按 `0xD1A8` → `0x500D` → `0xD100` 回退；PTP
  `0x200F` 按 `AccessDenied` 处理，不再错误等同于永久只读。
- B 门不再在用户选择模式时提前接管相机，只在实际曝光期间进入 Nikon
  Control Mode，并在拍摄结束或失败后以 `ChangeCameraMode(0)` 释放机身快门。
- 参数写入和拍摄前后暂停/恢复实时取景，等待 `DeviceReady`，Android 额外回收
  超时的 `UsbRequest`，避免取消请求残留导致后续事务连锁失败。
- macOS 会选择可写的 `movieshutterspeed` / `shutterspeed2` /
  `shutterspeed`，并持续排空 `gphoto2 --capture-movie` 的 stderr 管道，避免子进程
  因管道填满而逐渐降帧。
- `.github/workflows/release.yml` 已改为“存在则更新并 `--clobber` 上传，不存在则
  创建”，且必须使用 `docs/releases/<tag>.md` 的详细简体中文正文。
- `CHANGELOG.md` 已补 0.8.3、1.0.0 和本轮未发布修复；新增 4 项防回归检查，
  自动化总数由 16 项增至 20 项。

上述修复已通过 Android、macOS、Windows 编译和 HarmonyOS HAP 构建，但 #21、
#22、#23 仍需在报告者的 Z5 / Z8 与对应主机上复核后才能在 GitHub 正式关闭。
#20 Homebrew 是新增分发能力，不属于本轮缺陷修复。

## 1. 一页结论

- 产品公开名称已经从 Nikon Link 迁移为 **帧澈 ZENCHE**。
- 当前稳定版是 **1.0.0 / build 19**，GitHub 标签 `v1.0.0` 和 `main` 均指向
  `ae5e6400bf6ceada7ef9e14f07e120f98a79cc18`。
- GitHub PR #26 已合并，PR 和 `main` 的 iOS、Android、macOS 构建均通过。
- 本地当前检出修复分支 `codex/fix-known-issues`，基线为
  `ae5e6400bf6ceada7ef9e14f07e120f98a79cc18`；本轮变更尚未提交/推送。
- 五个产品目标均为原生实现：
  iOS / iPadOS、Android、HarmonyOS、macOS、Windows。
- macOS、Android、Windows、HarmonyOS 实现 Nikon USB/PTP；iOS / iPadOS 因公开
  API 限制，只使用系统相机和兼容 UVC 视频设备，不实现 Nikon 厂商 USB/PTP。
- 六类 1.0.0 本地产物均存在且 SHA-256 回验通过；GitHub Release 也已发布相同附件。
- 自动化测试共 20 项，当前 20 / 20 通过，但以静态一致性和元数据检查为主，不能
  替代相机、USB 主机、驱动、网络和签名实测。
- 当前 GitHub 仍有 4 个未关闭 Issue：1 个 Homebrew 安装请求，3 个相机控制/稳定性
  问题；后 3 个已有本地修复，等待报告者实机确认。
- 最大未闭环事项是：17 款相机的系统化实机矩阵、#21/#22/#23 硬件复核、
  Windows/HarmonyOS 真机验收、生产签名与商店级分发。
- `CHANGELOG.md` 的 0.8.3、1.0.0 已补齐。
- 标签 Release 工作流已幂等化，并要求仓库内维护详细简体中文 Release 正文。

## 2. 接手前必须遵守

先完整阅读仓库根目录的 `AGENTS.md`，其中的约束高于普通实现习惯。

关键规则：

1. 公开品牌固定为：
   - 中文名：`帧澈`
   - 国际名：`ZENCHE`
   - 双语锁定：`帧澈 ZENCHE`
   - 产品说明：`跨平台相机控制与影像传输工具`
   - 英文品牌语：`Capture · Connect · Flow`
   - 标语：`连接相机，也连接完整工作流`
   - 正式标识：蓝色几何 Z，源文件为 `icons/app-icon.svg`
2. 不要为了“彻底改名”删除或替换 `NikonLink`、`com.tauber.nikonlink` 等内部标识。
   它们关系到升级、签名、偏好设置、本地数据和源码兼容。
3. 除非任务明确限制平台，否则产品、界面和共享行为变更必须同步到五端。
4. 产品和界面变更默认只改 `native/` 下的五端实现。不要顺手修改顶层 Web/PWA。
5. 主应用代码改动完成后，必须为受影响平台重新打包并交付可安装/可分发产物。
6. Windows 代码一旦改动，必须运行 `scripts/build-windows.ps1`，生成版本化 NSIS
   安装程序和 SHA-256。
7. `README.md` 必须始终保持简体中文、英文、日文三部分，且内容实质等价。
8. GitHub Release 正文必须是详细简体中文，不能只用自动生成的简短提交列表。

## 3. 仓库与文件结构

### 3.1 主要目录

| 路径 | 作用 | 接手注意 |
| --- | --- | --- |
| `native/ios/` | SwiftUI、AVFoundation、PhotoKit、iOS / iPadOS | 内部工程名仍为 NikonLink |
| `native/android/` | Android Views、USB Host/PTP、MediaStore | Java，非 Compose |
| `native/harmony/` | Stage 模型、ArkUI、USB Host/PTP | DevEco/Hvigor，签名未配置 |
| `native/macos/` | SwiftUI/AppKit、libgphoto2 | 当前只交付 Apple Silicon |
| `native/windows/` | WPF/.NET 8、libusb | 需要匹配架构的 libusb 和 NSIS |
| `scripts/` | 五端构建、签名、打包 | 版本号目前硬编码为 1.0.0 |
| `docs/` | 构建、签名、术语、验收与 Release 正文 | 继续维护硬件验收结果 |
| `test/` | Node 内置测试 | 主要是源码一致性测试 |
| `PV/` | 中英文宣传片、封面、截图、节拍分析和剪映素材 | 大量输出被 Git 忽略 |
| `.github/workflows/` | Build、Release、Windows、signed iOS | Release 已支持重复上传 |
| 顶层 HTML/CSS/JS | 历史 Web/PWA 实现 | 未经明确要求不要改 |

当前 Git 跟踪约 155 个文件、约 5.9 万行。相对初始提交累计约 4.17 万行新增，
主要工作集中在五端原生应用和 PV 工程。

### 3.2 本地生成目录

这些目录都被 Git 忽略，不是源码：

| 路径 | 盘点时体积 | 内容 |
| --- | ---: | --- |
| `dist/` | 约 945 MB | 各历史版本安装包和校验文件 |
| `build/` | 约 1.3 GB | iOS、macOS、Windows 等中间结果 |
| `.toolchains/` | 约 1.1 GB | Android SDK、Gradle、PowerShell、libusb |
| `native/windows/bin/` | 约 347 MB | .NET 输出 |
| `PV/output/` | 约 89 MB | 中文/英文成片、海报、联系表和封面 |
| `PV/work/` | 约 142 MB | 宣传片中间帧与 QA 结果 |

`dist/` 目前仍有以下整理债：

- 0.3.0–0.6.0 已放入 `dist/旧版/`。
- 0.7.0–0.8.3 的旧包仍散落在 `dist/` 根目录。
- 0.8.3 同时保留 NikonLink 和 ZENCHE 文件名。
- 存在未打 Git 标签的 0.8.2 测试包。
- `PV/output/` 同时存在旧 NikonLink 文件名和正式 ZENCHE 文件名。

不要在未确认备份和发布追溯需求前直接删除这些文件。后续可按
`dist/archive/<version>/` 和 `PV/archive/` 统一归档，只让最新版留在输出根目录。

## 4. 产品架构与平台能力

### 4.1 共同工作流

五端围绕同一个本地优先工作流实现：

1. **Capture**：识别相机、实时取景、拍摄、下载。
2. **Control**：快门、光圈、ISO、曝光补偿、对焦、白平衡、Picture Control。
3. **Monitor**：快门角度、条纹图案、LUT、本地超采样、分辨率/帧率等监看工具。
4. **Connect**：FTP/PASV、HTTP PUT/POST、WebDAV 收图。
5. **Flow**：应用图库、系统相册、文件选择器、网盘引导、预览、分享、删除。
6. **Diagnose**：脱敏滚动日志、预填 GitHub Issue、版本检查。
7. **Localize**：简体中文、English、日本語运行时切换与持久化。

以上是共同的信息架构，不表示每个平台拥有完全相同的底层能力；例如 Nikon
USB/PTP 不适用于 iOS/iPadOS，LUT 和条纹等监看处理也必须以各平台实际源码和
设备能力为准。

网络收件箱默认使用：

- FTP 控制端口 `2121`
- HarmonyOS 固定 PASV 数据端口 `2122`；其他平台动态/各自管理
- HTTP/WebDAV 端口 `8080`
- 用户名/密码均为 `nikonlink` / `nikonlink`
- HTTP/WebDAV 使用 Basic Auth

这些协议没有 TLS，只能在可信局域网短时开启。

### 4.2 平台矩阵

| 平台 | 原生技术 | Nikon USB/PTP | 已实现重点 | 主要限制 |
| --- | --- | :---: | --- | --- |
| macOS | SwiftUI/AppKit + `libgphoto2` | 是 | 17 机型识别、实时取景、SDRAM 拍摄、参数控制、监看工具、图库、三协议收图、更新与诊断 | arm64、ad-hoc 签名、未公证；系统 PTP 服务可能抢占设备 |
| Android | Android Views + USB Host | 是 | 原生 PTP、异步 USB 读写、拍摄、控制、LUT/条纹、系统相册、网盘引导、三协议收图 | 调试证书签名；不同厂商 USB 栈差异明显；有 2 个开放控制问题 |
| Windows | WPF/.NET 8 + `libusb` | 是 | 原生工作台、PTP、拍摄、图库、Windows 分享、三协议收图、NSIS 安装器和便携包 | 可能要切换 WinUSB；未商业签名；真机矩阵不足 |
| HarmonyOS | Stage/ArkUI + `usbManager` | 是 | USB Host/PTP、192 KB 分块、拍摄、图库、系统媒体、网盘引导、三协议收图 | HAP 未签名；API 12+；真机/签名验收不足 |
| iOS / iPadOS | SwiftUI + AVFoundation/PhotoKit | 否 | 系统相机、兼容 UVC、照片/视频、曝光/对焦/缩放、系统相册、网盘引导、三协议前台收图 | Apple 公开 API 不开放 Nikon 厂商 PTP；IPA 未签名 |

### 4.3 相机档案

目前五端注册表保持一致，共 17 款：

- EXPEED 6：Z7、Z6、Z50、D780、D6、Z5、Z7II、Z6II、Z fc、Z30
- EXPEED 7：Z9、Z8、Z f、Z6III、Z50II、Z5II、ZR

Vendor ID 为 `0x04b0`，Product ID 范围和具体映射见 README 与
`docs/CAMERA_TEST_CHECKLIST.md`。

“存在机型档案”只代表能识别设备并选择参数范围，不代表全部固件、镜头、线材、
USB 主机和拍摄模式都已验收。

## 5. 已完成的工作

### 5.1 从 Web 壳迁移到真正原生应用

- 最初实现过 Web/PWA 和打包 WebView。
- WebView 阶段遇到本地 `file://` ES module、控件失效、全局 `inert` 和图库初始化
  等问题。
- 从 0.4.0 开始，macOS 和 Android 移除 WebView 运行资源，改为原生界面直连
  相机核心。
- 后续增加 iOS / iPadOS、Windows、HarmonyOS，形成五端原生结构。
- 顶层 Web/PWA 源码仍保留，但不再是原生包的界面依赖。

### 5.2 Nikon USB/PTP 与相机控制

- 从 Z8 单机型扩展到 17 款 EXPEED 6 / 7 机型。
- 统一 Vendor/Product ID、描述符 fallback 和代际识别。
- 实现 PTP 会话、实时取景、SDRAM 拍摄、JPEG 下载和本地保存。
- 实现 P/S/A/M 与 M 模式 B 门，提供 1–60 秒 B 门时长。
- 实现快门、光圈、ISO、曝光补偿、对焦、白平衡与 Picture Control。
- 根据曝光程序锁定只读控件，避免明显无效的参数写入。
- 加入断点/端点恢复、超时、重试和诊断记录。
- Android 针对 Z30 修正 `OpenSession` 事务 ID，并加入 endpoint clear halt 和 PTP
  reset 重试。

### 5.3 监看与原生界面

- 摄影与视频监看工作区分离，同时保持主导航和设置入口一致。
- 五端实现响应式原生工作台和沉浸式全屏预览。
- 监看能力包括快门角度换算、网格/安全区、条纹图案、自定义 3D `.cube` LUT、
  本地 2× 超采样、分辨率/帧率/编码偏好等。
- 明确区分“只影响本地监看”和“写入相机”的能力，LUT、条纹和超采样不修改原片。
- iOS / iPadOS 通过 AVFoundation 协商实际设备支持的格式，并如实限制 Nikon
  厂商控制。
- 已移除全局“普通/专业”密度开关，支持平台原生控件和可访问性。

### 5.4 本地文件、系统相册与网盘

- 统一“来源 → 媒体类型 → 文件”信息层级。
- 支持应用本地图库、无线传输来源、系统照片/视频来源。
- 支持 JPEG、NEF、HEIF/HEIC、TIFF 等导入与保留原扩展名。
- 支持系统文件选择器、全尺寸预览、分享和本地文件删除。
- 系统相册按只读来源处理，避免应用误删机主媒体。
- 五端均加入网盘二级引导，不接管用户账号密码：
  百度网盘、阿里云盘、腾讯微云、夸克网盘、迅雷云盘、115。
- 实际导入走网盘客户端/系统文件提供器，不在应用内保存网盘凭据。

### 5.5 无线传输

- 五端均实现 FTP/PASV 收件箱。
- 五端均实现带 Basic Auth 的 HTTP PUT/POST 和 WebDAV。
- 支持 `OPTIONS`、`PROPFIND`、`MKCOL`、`PUT` 等 WebDAV 行为。
- 支持从 URL 路径、查询参数或 `X-Filename` 取得文件名。
- 对文件名进行清理，避免目录穿越；重复文件使用唯一命名。
- Windows 和 HarmonyOS 对大文件/分块/临时文件做了平台适配。
- iOS/iPadOS 在应用进入后台时自动停止无线监听。

### 5.6 诊断、更新、安全和本地化

- 五端加入隐私脱敏的本地滚动日志，单文件上限和保留周期由平台实现管理。
- 可生成带环境和最近日志的 GitHub Issue 预填链接。
- 日志会过滤密码、令牌、序列号等敏感内容；照片不会自动附加。
- 五端加入 GitHub Release 更新检查。
- 五端加入按版本显示的启动更新公告、防诈骗说明和本地赞助图片。
- “不再提醒”只对当前版本生效，升级后会重新显示。
- 五端支持简中、英文、日文切换并持久化。
- 公开品牌已统一到帧澈 ZENCHE，同时保留旧内部标识保证升级兼容。

### 5.7 构建与发布

- macOS：生成 DMG，内含 Applications 快捷方式，打包 `gphoto2` 及依赖，ad-hoc
  签名并生成 SHA-256。
- Android：构建 APK，当前为调试证书签名，生成 SHA-256。
- iOS：支持 unsigned IPA；另有依赖 GitHub Secrets 的 signed IPA 手动工作流。
- HarmonyOS：Hvigor 构建 HAP；无 signingConfigs 时输出未签名包。
- Windows：.NET 8 自包含发布、匹配架构的 libusb、NSIS 安装器、便携 ZIP 和
  SHA-256；支持覆盖升级和卸载。
- `scripts/build-all.sh` 在 macOS 上构建能检测到工具链的平台，Windows 始终需要
  Windows 主机单独打包。

### 5.8 宣传和品牌资产

- 完成蓝色几何 Z 品牌标识和中英文品牌文案统一。
- 完成中文 V1 正式宣传片与英文 YouTube 版本。
- 完成五端原生界面预览、节拍分析、节拍网格转场、审阅帧、海报和联系表。
- 完成 B 站、小红书、抖音、YouTube 和通用横版封面。
- PV 的可复现脚本、HTML VFX 时间线和剪映草稿说明位于 `PV/`。
- 生成媒体位于 `PV/output/`，不进入 Git。

## 6. 版本演进摘要

| 版本/阶段 | 主要成果 |
| --- | --- |
| 0.2.x | Web/PWA 相机连接、离线支持、IndexedDB 图库 |
| 0.3.x | Z8 的 macOS/Android 包装、USB/PTP、实时取景与拍摄；修复 WebView 控件 |
| 0.4.0 | macOS/Android 从 WebView 壳切换为原生界面 |
| 0.5.0 | 扩展 Z f、Z6III、Z5II 与机型化参数范围 |
| 0.6.0 | P/S/A/M/B 门、FTP/PASV、更多文件类型 |
| 0.7.0 | iOS/iPadOS、监看工具、LUT、条纹、超采样、三端打包 |
| 0.7.1 | 全 EXPEED 7 机型、摄影/视频工作区、三语 README |
| 0.7.2 | Android 状态栏/挖孔/胶囊安全区修复 |
| 0.7.3 | Windows、HarmonyOS、五端诊断、构建和验收文档 |
| 0.8.0 | 全 EXPEED 6 机型 |
| 0.8.1 | Android USB/Z30 稳定性、HTTP/WebDAV、Windows NSIS 安装器 |
| 0.8.2 | 仅见于本地测试包和 Issue 环境，没有正式 Git 标签/Release |
| 0.8.3 | 帧澈 ZENCHE 品牌、五端大型原生界面/文件工作流升级、PV 工程 |
| 1.0.0 | 五端三语、启动公告、防诈骗、赞助资源、正式发布与中英文宣传资产 |

## 7. 踩过的坑与已经采取的处理

### 7.1 WebView 不适合继续承担原生产品界面

症状：

- 本地 `file://` 对 ES module 支持不稳定。
- `inert` 状态和连接弹窗造成控件无响应。
- IndexedDB 初始化超时或内存 fallback。

处理：

- 先用单文件脚本临时修复，最终让 macOS/Android 完全原生化。
- 当前规则明确：默认不再从 Web/PWA 改原生产品。

### 7.2 Android 系统栏和厂商 USB 行为差异

症状：

- 顶栏与状态栏、挖孔、HyperOS 胶囊重叠。
- Android 13–16 的 USB 权限广播在部分设备不可靠，回传 extras 可能缺失。
- Z30 首次 PTP 会话出现发送/读取失败。

处理：

- 使用系统 insets 调整头部和底部布局。
- 权限完成时重新枚举设备和权限状态，不只依赖 fill-in extras。
- `OpenSession` 使用事务 ID 0，清除 stalled endpoint，并在失败时执行 PTP reset
  和有限次数重试。

仍需注意：

- 小米、荣耀等厂商 USB 栈行为仍有差异，开放 Issue #21/#22 表明稳定性未完全闭环。

### 7.3 参数是否可写取决于机身模式，而不只取决于机型

症状：

- Android Z8 写入曝光时间返回 PTP `0x200F`。
- macOS `gphoto2` 报 `Property shutterspeed is read only`。
- 切换 B 门后实时取景或机身快门状态可能异常。

已做：

- 根据 P/S/A/M/B 进行前端锁定。
- 参数失败后恢复/重启实时取景并记录日志。

未解决：

- 需要在具体机型、固件、照片/视频模式、实时取景状态下读取设备属性描述符和
  writable 状态，不能只靠静态模式表判断。
- 写参数前后要验证相机状态，失败时不要让 UI 与机身状态分叉。

### 7.4 USB/PTP 是排他的

- macOS 照片、图像捕捉、系统 PTP 服务或 Nikon 软件可能先占用设备。
- Windows 默认相机驱动可能阻止 libusb 声明 PTP 接口。
- Android/HarmonyOS 拔插、后台切换和睡眠可能留下 stale endpoint。

接手时必须保留清晰错误提示、断开清理、超时和恢复逻辑。不要用无限重试掩盖
设备被占用。

### 7.5 Windows 驱动与打包

踩过的坑：

- x86/x64/ARM64 的 `libusb-1.0.dll` 不能混用。
- 自包含 .NET 包很大，曾需专门压缩修复。
- 校验文件若记录绝对路径或错误文件名，会在其他机器回验失败。
- Windows 改动不能只在 macOS 上做交叉编译后宣称完成。

当前处理：

- 构建脚本检查 PE 架构。
- 默认生成 NSIS `Setup.exe` 和完整便携 ZIP。
- SHA-256 文件只记录可移植的文件名。
- GitHub 有独立 Windows 2025 runner 工作流。

### 7.6 HarmonyOS 工具链和签名

- DevEco/Hvigor 的位置、Node/JBR/SDK 需要显式检测。
- HarmonyOS 单次 USB bulk 调用限制在 200 KB 以下，当前按 192 KB 分块。
- 未配置 signingConfigs 时构建可成功，但 HAP 不能直接安装。
- 模拟器不能证明 USB Host、网络监听和 Nikon PTP 可用。

### 7.7 iOS 能力边界和签名

- Apple 公开 API 不向普通应用开放 Nikon 厂商 USB/PTP 控制。
- UVC 输入只能作为视频源，不能宣称是 Nikon 机身参数控制。
- unsigned IPA 只是编译/容器验证产物，不能直接安装。
- signed 工作流依赖 6 个 GitHub Secrets，证书和 Profile 禁止提交仓库。

### 7.8 发布工作流与人工发布冲突（已修复）

v1.0.0 标签触发的 Release Actions：

- `./scripts/build-all.sh` 成功。
- `Publish release assets` 失败。
- 根因是脚本固定执行 `gh release create`，但同名 Release 已经存在。

这不是编译失败，而是发布步骤不幂等。本轮已改为：

1. 检查 `docs/releases/<tag>.md` 是否存在且非空。
2. 检查 Release 是否存在。
3. 不存在时用详细中文正文创建。
4. 已存在时更新标题/正文，再用 `gh release upload --clobber` 替换附件。
5. 不再把 `--generate-notes` 当作最终 Release 正文。

### 7.9 品牌迁移不能破坏升级

- 公开界面、包文件名、仓库、PV 已改为 ZENCHE。
- 工程目录、bundle/package ID、scheme、偏好 key 仍有 NikonLink。
- 这些“旧名字”是兼容层，不是遗漏。不要全局搜索替换。

### 7.10 自动化通过不等于硬件通过

当前 20 项 Node 测试主要检查：

- 五端 17 款机型注册表一致。
- Android USB filter 完整。
- 品牌公告、防诈骗和赞助资源存在。
- 三语资源与运行时翻译路径存在。
- 版本号和 build number 一致。
- Nikon 照片/视频快门回退、B 门释放、macOS stderr 排空和 Release 幂等规则。

它们没有真的连接相机、执行 PTP、验证局域网协议或安装签名包。

## 8. 当前未关闭的 GitHub Issue

### P0：相机控制与稳定性（本地已修，待实机关闭）

1. [#21 Android：Z5 闪退、机身快门不可用、B 门后无法正常拍摄](https://github.com/Tauber01/ZENCHE/issues/21)
   - 环境：Android 15，小米 23013RK75C，0.8.1。
   - 日志显示 Z5 可连接、改快门和拍摄，但随后 live view 的异步 USB 请求超时。
   - Issue 正文末尾被截断，缺少完整崩溃栈和最终会话日志。
   - 本地修复：B 门延迟接管并在 finally 释放 Control Mode；拍摄/设参后等待相机
     ready 并重试恢复 live view；超时 UsbRequest 会取消、回收后再关闭。
   - 关闭前仍需：Z5 上跑“普通拍摄 → B 门 → 普通拍摄 → 机身快门 → live view”
     完整流程，并补充 tombstone/logcat 证明没有 native USB 崩溃。

2. [#22 Android：Z8 写曝光时间返回 PTP 0x200F](https://github.com/Tauber01/ZENCHE/issues/22)
   - 环境：Android 15，HONOR REA-AN00，0.8.2。
   - 前两次初始化耗时/疑似失败，第三次连接成功。
   - `SetDevicePropValue`（操作 `0x1016`）写 `exposureTime` 两次返回 `0x200F`。
   - 根因：`0x200F` 是 `AccessDenied`；新机身可能把标准 `0x500D` 设为只读，同时
     开放 Nikon `0xD100`（照片）或 `0xD1A8`（视频）。
   - 本地修复：读取属性可写标志并按视频/照片候选链回退，Nikon 属性使用
     16-bit 分子/分母打包格式；全部候选失败后才锁定控件。
   - 关闭前仍需：Z8 的 M/S 照片模式和视频模式各验证一组快门值。

3. [#23 macOS：快门角度写快门失败且实时取景帧率下降](https://github.com/Tauber01/ZENCHE/issues/23)
   - 环境：macOS 26.2 arm64，0.8.2。
   - ISO 写入成功，`shutterspeed` 被 gphoto2 报告为 read-only。
   - 快门角度 180°因此失败；实时取景从约 28 fps 降到约 11.5 fps。
   - 本地修复：照片优先 `shutterspeed2`，视频优先 `movieshutterspeed`，再回退
     标准 `shutterspeed`；持续排空 live-view 子进程 stderr，并为逐帧 AppKit
     对象加入 autorelease pool。
   - 关闭前仍需：报告者提供机型/固件并持续监看至少 10 分钟，确认快门角度可写且
     帧率不再从约 28 fps 持续跌至约 11 fps。

### P1：分发便利性

4. [#20 macOS：希望支持 Homebrew tap 安装](https://github.com/Tauber01/ZENCHE/issues/20)
   - Issue 无正文。
   - 需要先决定维护自有 tap 还是提交 cask。
   - 当前 DMG 未公证且版本只提供 arm64，可能阻碍正式 Homebrew Cask 接受。

### 已关闭且应保留回归测试的 Issue

- #4：Android 顶栏/状态栏重叠，已在 0.7.2 修复。
- #10：Android USB 授权反复弹窗，已在 0.8.1 修复。
- #12/#13：Android Z30 连接失败，已通过权限与 PTP 会话加固修复。

## 9. 待完成任务与建议优先级

### P0：发布前可靠性

- [x] 在新分支实现 Issue #21、#22、#23 的代码修复。
- [x] 给直接 PTP 相机参数层增加运行时可写性与 Nikon 快门属性回退。
- [ ] 在报告者的 Z5 / Z8 与 macOS 相机环境中完成硬件复核并关闭 #21/#22/#23。
- [ ] 对 live view、参数写入、B 门、拍摄和断开建立状态机级回归测试。
- [ ] 使用 `docs/CAMERA_TEST_CHECKLIST.md` 执行真实相机矩阵，至少优先：
  Z5、Z8、Z30、Z6III，以及 Windows/HarmonyOS 各一台 USB Host 设备。
- [ ] Windows 验证 WinUSB 切换、相机连接、安装/覆盖升级/卸载、200% 缩放。
- [ ] HarmonyOS 生成签名 HAP，并在手机、平板或 2-in-1 上验证 USB 和三协议收图。

### P1：发布与签名

- [x] 修复 `.github/workflows/release.yml` 的 Release 已存在冲突。
- [x] 让 Release 工作流使用维护好的详细中文正文，而不是最终依赖
  `--generate-notes`。
- [x] 补齐 `CHANGELOG.md` 的 0.8.3 和 1.0.0。
- [ ] 配置 Apple Developer 证书/Profile，生成可安装 signed IPA。
- [ ] 为 HarmonyOS 配置正式 signingConfigs。
- [ ] 为 macOS 配置 Developer ID、公证和 stapling。
- [ ] 为 Android 配置正式 release keystore，不再交付 debug 签名。
- [ ] 为 Windows 应用和 NSIS 安装器配置受信任代码签名。
- [ ] 评估 macOS x86_64/universal 版本，否则明确长期只支持 Apple Silicon。
- [ ] 评估并回复 Issue #20 的 Homebrew 安装方案。

### P1：测试和可观测性

- [ ] 增加 PTP 容器、参数编码、超时、取消、重连的单元测试。
- [ ] 增加 FTP/HTTP/WebDAV 的协议级自动化测试，包括鉴权、断线、重名和大文件。
- [ ] 增加日志脱敏的负面测试，防止 token、密码、序列号泄漏。
- [ ] 增加安装包内容扫描，确保原生包不意外重新带入 WebView 资源。
- [ ] 为 Issue 模板补充“相机型号、固件、拍摄模式、镜头、线材、主机和完整日志”
  必填提示，减少只有 `[Android]` / `[macOS]` 的空标题。

### P2：工程维护

- [ ] 把分散在五个构建脚本中的版本号改为单一可信来源。
- [ ] 将超大的单文件 UI 逐步拆分：
  Android `MainActivity.java`、HarmonyOS `Index.ets`、macOS `main.swift`、
  Windows `MainWindow.xaml.cs`、iOS `RootView.swift`。
- [ ] 将五端共同的机型档案生成或校验流程进一步自动化，减少手工同步风险。
- [ ] 整理 `dist/` 历史版本和 0.8.2 测试包，建立清晰的 latest/archive 规则。
- [ ] 清理或归档重复 NikonLink/ZENCHE PV 输出，但保留发布追溯信息。
- [ ] 评估固定默认 FTP/HTTP 密码的改进方案；若改为随机凭据，要同步五端、文档和
  相机配置体验。
- [ ] 评估可选 TLS/HTTPS；当前至少继续禁止公网暴露。

## 10. 当前验证和交付状态

### 10.1 2026-07-30 本地复核

- `npm test`：20 / 20 通过。
- Android、macOS、Windows 均通过编译；HarmonyOS release HAP 构建成功。
- 本轮受影响的 APK、HAP、DMG、Windows Setup EXE 和便携 ZIP 均已重建，
  容器检查及 SHA-256 回验通过。
- 工作区包含本轮修复、测试、发布文档和本交接文档，尚未提交/推送。

### 10.2 GitHub

- PR #26：已合并。
- PR #26 Build：
  - iOS：成功
  - Android：成功
  - macOS：成功
- `main` Build：成功。
- v1.0.0 Release workflow：
  - 远端历史运行的构建步骤成功。
  - 远端历史发布步骤因 Release 已存在而失败。
  - 本地 `codex/fix-known-issues` 已修复冲突，合并后才会作用于后续标签。
- GitHub Release 已存在，附件完整，并有详细简体中文说明。

### 10.3 本地 1.0.0 产物

| 平台 | 文件 | 签名/状态 |
| --- | --- | --- |
| macOS | `dist/ZENCHE-1.0.0-macOS-arm64.dmg` | ad-hoc，未公证 |
| Android | `dist/ZENCHE-1.0.0-android.apk` | debug 签名 |
| Windows | `dist/ZENCHE-1.0.0-Windows-x64-Setup.exe` | 未商业代码签名 |
| Windows | `dist/ZENCHE-1.0.0-Windows-x64.zip` | 便携版 |
| HarmonyOS | `dist/ZENCHE-1.0.0-HarmonyOS.hap` | 未签名 |
| iOS / iPadOS | `dist/ZENCHE-1.0.0-ios-unsigned.ipa` | 未签名，不可直接安装 |

每个文件旁都有同名 `.sha256`。

## 11. 建议的接手顺序

1. 阅读 `AGENTS.md`、本文、`design.md`、README 和三份平台构建说明。
2. 先审阅并提交/推送当前 `codex/fix-known-issues`，不要丢弃未提交修复。
3. 运行 `npm test`，确认接手基线仍为 20 / 20。
4. 优先在 Android Z5/Z8 和 macOS 对应相机上复核 #21/#22/#23。
5. 把硬件结果和脱敏日志回填 Issue；通过后关闭，否则基于完整日志继续修正。
6. 补充真正执行 PTP 编码/状态转换的单元测试，而不只保留静态源码断言。
7. 处理 #20 前先确认是否授权创建/维护独立 Homebrew tap。
8. 再考虑发布 1.0.1；Release 必须写详细简体中文说明，包含：
   版本亮点、五端变化、相机兼容、签名状态、验证、限制、升级和 SHA-256。

## 12. 可直接交给 DeepSeek V4 Pro 的启动提示

```text
你正在接手 /Users/tauber/Documents/NikonLink 的帧澈 ZENCHE 项目。

先完整阅读：
1. AGENTS.md
2. docs/DEEPSEEK_V4_PRO_HANDOFF.md
3. design.md
4. README.md
5. docs/CAMERA_TEST_CHECKLIST.md
6. docs/WINDOWS_BUILD.md、docs/HARMONY_BUILD.md、docs/IOS_SIGNING.md

重要边界：
- 保留 NikonLink / com.tauber.nikonlink 等兼容性内部标识。
- 默认所有产品和界面改动都要同步 iOS/iPadOS、Android、HarmonyOS、macOS、Windows。
- 未明确要求时不要修改顶层 Web/PWA。
- 主应用代码改动完成后必须打包受影响平台；Windows 改动必须生成 NSIS Setup.exe
  和 SHA-256。
- README 必须保持简中、英文、日文三部分实质等价。
- Release 正文必须是详细简体中文。

当前稳定基线：
- GitHub main 与 v1.0.0：ae5e6400bf6ceada7ef9e14f07e120f98a79cc18
- 本地修复分支：codex/fix-known-issues（未提交/未推送）
- 版本：1.0.0 / build 19
- npm test：20 / 20 通过
- 受影响平台安装包已重建且 SHA-256 全部通过

优先任务：
1. 审阅当前未提交 diff，保留 #21/#22/#23、Release workflow 和 CHANGELOG 修复。
2. 在 Z5 / Z8 和 macOS 相机上执行硬件验收，并把结果回填对应 Issue。
3. 重点确认 B 门后机身快门可用、视频/照片快门都写入正确属性、10 分钟监看不降帧。
4. 补充 PTP 编码、超时取消和状态机的可执行单元测试。
5. 评估 #20 Homebrew tap；该任务需要单独的仓库/发布授权。

开始任何实现前先报告：当前分支、工作区状态、测试基线、可用硬件/工具链，以及你
准备处理的单一问题。不要凭静态注册表宣称相机已通过实机验证。
```

## 13. 关键链接

- 仓库：https://github.com/Tauber01/ZENCHE
- v1.0.0：https://github.com/Tauber01/ZENCHE/releases/tag/v1.0.0
- PR #26：https://github.com/Tauber01/ZENCHE/pull/26
- 相机验收：`docs/CAMERA_TEST_CHECKLIST.md`
- Windows：`docs/WINDOWS_BUILD.md`
- HarmonyOS：`docs/HARMONY_BUILD.md`
- iOS 签名：`docs/IOS_SIGNING.md`
- Nikon 术语：`docs/NIKON_TERMINOLOGY.md`
- 安全策略：`SECURITY.md`
- 宣传工程：`PV/README.md`
