# 帧澈 ZENCHE 项目大纲

> 文档状态：工作基线
> 最近核对：2026-08-20（Asia/Shanghai）
> 使用方式：开始产品、界面、技术或发布工作前，先阅读根目录 `AGENTS.md`，再阅读本文、`docs/TECHNICAL_APPROACH.md` 与 `docs/TASK_PROGRESS.md`。

## 1. 项目定位

帧澈 ZENCHE 是一套本地优先的原生跨平台相机控制与影像传输工具，围绕摄影现场的完整工作流组织能力：连接相机、实时监看、调整参数、自动拍摄、接收影像、整理素材、非破坏性处理、导出与诊断。

- 中文名称：帧澈
- 国际名称：ZENCHE
- 双语锁定：帧澈 ZENCHE
- 产品描述：跨平台相机控制与影像传输工具
- 英文品牌语：Capture · Connect · Flow
- 标准标语：连接相机，也连接完整工作流
- 当前源码版本：1.5.14（连接可靠性、Sony 兼容、桌面导入与五端文件库更新）
- 当前原生构建号：41
- 发布状态：[GitHub Release v1.5.14](https://github.com/Tauber01/ZENCHE/releases/tag/v1.5.14)
  已于 `2026-08-19T19:58:12Z` 发布为 Latest，非草稿、非预发布；注释标签对象
  `fea9c2a8774c5b96d409940fb7b55e2f5e907c22` 解引用到发布提交
  `17e87ce6c39aad07f712cd0605efe90899e6e72c`。Release ID `373311624`，包含六个五端安装包与
  六份 SHA-256 侧车；发布 run `32295909168` 公开前完成全资产侧车验证并原子切换，
  GitHub 端名称、字节数和六包摘要 12/12 一致。官网自托管更新已同步切换到
  `1.5.14 / build 41`，双 API 五端响应与六包公网 SHA-256 均已回验。

1.5.13 为五端文件库、支持应用内预览的页面、AI 与专业显影工作区增加“下载到本地”入口。操作始终创建副本，AI/专业显影直达流程会先产生新的 ZENCHE 文件库项目；移动端使用系统文档保存器，桌面端在后台复制并以稳定文件身份阻止别名路径覆盖源文件。五端文件库统一识别 JPG/JPEG、HEIF/HEIC、PNG、TIF/TIFF、NEF/NRW、ARW、CR2/CR3、MOV/MP4/M4V 与 AVI。旧候选包内的“尚未发布”瞬时公告已改为长期有效的 GitHub Release、官网 1.5.10、签名与实机边界；最终包内产品名称统一为“专业显影 / Pro Develop / プロ現像”，三语正向与反向契约阻止通用术语回归。逐包字节数和 SHA-256 见 `docs/releases/v1.5.13.md`。

1.5.14 / build 41 为五端连接可靠性与恢复体验正式稳定版。PTP/IP 心跳改用 event 通道的
标准 Probe Request/Response(type 13/14)，常驻 reader 同时响应相机主动探测并排空
事件；Apple、HarmonyOS、Windows 为完整 command transaction 增加显式串行 gate。
GetDeviceInfo 恢复无参数请求及 PIMA STR/AUINT16 解析，data-out 按
StartData(tx,length) + EndData(tx,data) 组帧并校验响应 transaction。Android/HarmonyOS
补齐网络监听权限，Windows 自动重连每轮有 12 秒上限且只在会话恢复完成后退出重连
态；五端连接取消均以代际或等价门禁阻止旧回调复活。五端顶层连接管理现可直接发现
Wi‑Fi/PTP‑IP，并按连接中、重连中、已连接和失败提供取消、停止重连、断开与重试；
进度、端点锁定和 Wi‑Fi/IP/端口恢复提示与全局拍摄状态同步。Android、HarmonyOS、
Windows 隔离 Wi‑Fi 与其他连接源错误，HarmonyOS 小视口面板可滚动，Windows 重连
期间不会保留假可用的快门、LIVE 或存储入口。冻结实现
`9eaa7c314b7e51f1e6e91d87b284e317d0c3d903` 的完整自动化 579/579、连接体验/协议
专项 55/55 与五端原生打包全部通过；六包、六份侧车、版本、容器、架构和适用签名
边界均已回验，逐包状态见 `docs/releases/v1.5.14.md`。此前
`6dbdb0d4802328629ffcbf0a97371a92d5862fd1` 候选包已被本地替代且不会发布。2026-08-20
集成继续修复桌面外部命令无界等待与 iOS Sony 路由，并把 Sony ZV-E10、A6100/
A6100A、A6400/A6400A、A6600 纳入五端识别/兼容配置；旧机型未进入当前 Sony
Camera Remote SDK 公开支持表，完整遥控能力仍需对应真机验证。macOS/Windows 新增
照片与视频一键多选导入、取消、流式写入、RAW+JPEG 配对、双备份与校验清单；五端
文件库均以“所有文件”开场，提供搜索、筛选、排序，并把项目分类和来源工具降为默认
收起的二级结构。桌面缩略图按需解码、限额缓存，删除改走系统废纸篓/回收站并同步
正确历史会话的备份、清单与共享 XMP。发布与逐包证据以 `docs/releases/v1.5.14.md`
最终记录为准。2026-08-20 的总实现封板为
`5e8b7f1e81c91d99848c619ba583784f5a20cb57`：完整自动化 630 项中 629 通过、
0 失败、1 项 Windows 主机专属用例跳过；六个正式资产和六份同名 SHA-256 已由该
实现重建并通过版本、容器、架构和适用签名回验。正式签名、真机相机、断网、安装
与 Windows 主机验收边界不变。
正式 GitHub 资产已从封板实现重建；官网生产清单、两套 API 与六个公网下载均已对
1.5.14 回验，详细证据和回滚路径见 `docs/releases/v1.5.14.md`。

W15 修复五端登录页中“模式标签”和“提交按钮”同名造成的误触歧义，并为 macOS、Windows 增加可保存的桌面工作区。两端会恢复主窗口大小和位置，Windows 还会恢复最大化状态；主导航、拍摄参数、编辑媒体池、工具面板及底部工具区可在拖动中实时连续调节，Windows AI 工具面板另有独立分隔条。桌面编辑器将“专业显影 / AI 工具”固定为一级模式，色轮、曲线、蒙版等归入二级“调整类别”；RGB 示波器会填满底部可用空间。预览和示波器复用同一受控尺寸图像，Windows 另合并高频刷新、按录制状态启停时间码，并在替换结果、切换照片或模式、离开编辑页及关闭窗口时清理受限命名的 AI 临时文件和编辑位图。第一版不包含任意浮动面板或跨屏面板停靠；Windows 多显示器/DPI 与两端真实拖拽、重启恢复及长时间性能仍需真机验收。最终源码基线为 `831a82315c3586a8c8933c76ef6e8e3612bbcba5`，完整测试 503/503 通过；Windows 两包已按该基线重建，未受后续 Windows 专属改动影响的 macOS DMG 复用 `0faeccdc987146c104fd73d742547c9baf9db221` 已验证产物。最终聚合包 SHA-256 为 `46515bba169afe3a495f1265dec9ab2a3ac409ecaf20d2466b041fe2144992e1`，14 项逐字节一致。AI审查 最终门禁 PASS（P0/P1/P2=0）；GPT5.6luna 确认三语、签名事实、生产边界、去 AI 痕迹与交付内容无实体问题，其唯一状态 P2 已完成回填。

Windows 启动异常修复已随 1.5.12 / build 39 GitHub Latest 发布：WPF 在 `InitializeComponent()` 期间同步处理 XAML 默认选中项；曝光模式会在后置参数控件创建前刷新整组可用性，形成截图所示 `SetParameterAvailability → UpdateExposureAvailability → ExposureModeBox_SelectionChanged` 空引用链，视频快门模式随后也会在 `ShutterBox` 创建前配置快门。共享参数处理器虽在当前冷启动断开态下未证实触发同类空引用，但也在初始化门禁前刷新读数，本次作为防御性加固一并收口。代码提交 `970f8e08edce2529750d5b29fe3aaccd53da61ac` 将三条路径统一置于初始化门禁之后，并以 3 条启动契约锁定事件连接、默认选中、控件顺序、门禁初值及完整树加载后的恢复配置；冻结实现与打包源码基线 `025517c179003db1790a3a5c1ffd0560ce55d39e` 的完整 `npm test` 518/518 通过。六个新版本包均已从该基线重新构建，没有复用或改名 1.5.11 资产；14 项聚合包 SHA-256 为 `1bdaed8f3ae6214e1f8aa3133d8e88fa5a7274a0b711e52374a30b2c38d5f2ce`，逐项与交付源一致。Windows 包继续由 macOS 交叉构建且无 Authenticode；真实 Windows 冷启动、参数交互、安装升级、卸载、驱动和 SmartScreen 仍需实机验收。逐包字节数、SHA-256 与签名边界见 `docs/releases/v1.5.12.md`。

Android Nikon Z50 的 SDRAM 拍摄后下载新增有界繁忙恢复：`CaptureToSdram` 成功后若 `GetObject (0x1009)` 返回 `DeviceBusy (0x2009)`，客户端不会再次触发快门，而是在最长 20 秒、最多 9 次尝试内强制指数退避，并重新读取 Nikon 事件以刷新最终对象句柄。该修复针对“相机已接受拍摄但仍在写入 JPEG”的阶段；不同固件、存储卡速度与 USB 主机组合仍需 Z50 真机验收。

Android 本机摄像头对厂商 Camera2 HAL 拒绝双 JPEG 输出的情况增加有序降级：先尝试常规与低负载双流，再依次尝试共享单 JPEG 流；每次失败都完整关闭并重开相机，所有尺寸只取自设备 `StreamConfigurationMap`。共享流以传感器时间戳区分取景帧和拍照帧，迟到回调、打开超时与拍照失败会统一释放会话。该修复针对 OPPO PEDM00 / Android 14 的 `endConfigure` 失败；真实设备的持续取景、重复拍摄与前后台恢复仍需验收。

W15 后续 AI 运行时与系统相册流程统一把五端默认 AI 代理迁移到 `https://zenche.top/api`；仅历史默认 `http://101.34.255.115:8787`（含尾斜杠）自动迁移，用户明确配置的自托管地址继续兼容。HTTPS 请求继续携带当前账号 Bearer，并提交激活码、设备 ID、提示词以及修图原图；Android 与 HarmonyOS 删除“需配置 API Key”的过期运行时说明。Android、iOS/iPadOS、HarmonyOS 的修图页固定显示系统照片入口：经系统选择器读取 URI/PHAsset 后先创建应用私有工作副本，专业调整与 AI 修图都保存为新的应用副本；导出时再新建系统相册项目，不写入系统原片。权限拒绝、取消、导入失败和保存失败均保留可恢复状态，iOS/Android 可引导用户打开系统设置；新增状态、数量、权限弹窗和 AI 控件均进入完整三语路径，动态文件名、预设名与服务端详情以参数插入，避免对用户内容做二次翻译。Android 编辑解码会归一化 JPEG EXIF 方向 1–8，预览、分析和导出使用同一朝向。桌面端本轮只同步 AI 代理与 300 秒等待窗口，不新增系统相册入口。最终移动端实现源码基线为 `5e7150d9217690e6aea56ea15d8fae852a2d825f`；完整 `npm test` 514/514，Android、iOS 与 HarmonyOS 原生构建和包结构校验通过。GitHub 发布聚合包 SHA-256 为 `2f90a8afb39dbe26c1537c4f642e09f76898627547693453d8829005c190d9e4`。Release 于 `2026-08-10T18:12:28Z` 公开为非草稿、非预发布版本；六包、六侧车、聚合包及其侧车共 14 个线上资产的字节数与 GitHub SHA-256 摘要均已逐项对照本地文件，14/14 一致。

W14 为五端拍照页增加实时监看开关，并在 iOS / iPadOS 增加可信局域网 Mac 相机桥接。Sony 官方 Camera Remote SDK 在 Mac 端执行，Nikon 使用明确标注的 PTP 兼容路径。关闭开关只停止取景帧并清空缓存画面，不断开相机或禁用快门。1.5.10 六个本地交付文件已逐个通过 SHA-256 和结构校验；完整文件表、签名边界与使用限制见 `docs/releases/v1.5.10.md` 和 `docs/LIVE_MONITOR_AND_IOS_CAMERA_BRIDGE.md`。

v1.4.0 已完成 AI 原图上传、服务器次数扣减/失败回滚、修图覆盖原图与生图另存的五端行为对齐；包与签名状态详见 `docs/releases/v1.4.0.md`。发布提交为 `8a13c0b`，标签为 `v1.4.0`，Release 为 [GitHub v1.4.0](https://github.com/Tauber01/ZENCHE/releases/tag/v1.4.0)。

v1.4.1 聚焦五端原生监看体验：RGB/音频波形卡、Android 波形间录制键、监看参数调节、预览点按对焦，以及移除镜头读数和监看“曝光”入口。发布提交、标签、Release、包与 SHA-256 详见 `docs/releases/v1.4.1.md`。

v1.5.0 新增五端原生外录：照片直接写入当前智能设备，PTP 视频可在机身录制同时将实时取景流式封装到 ZENCHE 文件库；Android、HarmonyOS、macOS、Windows 使用无声 Motion-JPEG AVI，iOS / iPadOS 本机与 UVC 源使用 MOV。外录接入会话命名、备份、SHA-256 和断开安全收尾，包与签名状态详见 `docs/releases/v1.5.0.md`。

v1.5.2 已完成集成并发布：五端全局状态条、五端“恢复设备码”入口、Android USB/PTP 会话降级、仓库内零依赖 AI 代理、设备码换绑协议和回环签发端已经合并。换绑只证明“旧激活码 + 当前绑定的旧设备码”凭据，成功后签发绑定新设备码的新码、继承次数与到期日并冻结旧记录；它不保证 HarmonyOS 卸载重装后的设备码本体连续。客户端入口固定使用 HTTPS，并在请求前验证旧凭据、响应后验证新码；服务端仍默认关闭，不得绕过 DNS、HTTPS、8787 明文端口收口、灰度和回滚门禁。最终独立发布审查以代码提交 `dce831d` 和文档提交 `315809b` 为对象，结论为无 P0、无 P1，5 项 P2 均不阻塞本地候选交付。Tauber 随后在 Buzz 事件 `e32e0706…f12b` 明确决定将该版本作为 GitHub 最新稳定版发布；该产品决定不改变签名、Windows 主机、实机或生产网络限制。

v1.5.2 Release 已公开 14 个附件：Android Debug 签名 APK、HarmonyOS 未签名 HAP、iOS / iPadOS unsigned IPA、macOS arm64 ad-hoc DMG、Windows x64 Setup/ZIP、精确源码 ZIP，以及七份同名 `.sha256`。发布前后均逐项核对线上大小与 GitHub SHA-256 摘要，14/14 一致；完整清单、签名和安装限制见 `docs/releases/v1.5.2.md`。GitHub 稳定通道标识不改变附件本身的验证属性：macOS 包未使用 Developer ID、未公证；Windows 包在 macOS 交叉构建，尚未在真实 Windows 主机验证安装、驱动和 SmartScreen。

v1.5.3 聚焦五端原生工作台界面：全屏监看采用影像优先的遥测 HUD、焦点十字、工具轨、RGB 三色叠加波形示波器、静音音频基线和参数托盘；拍摄页使用设备摘要、自适应参数卡与常驻拍摄操作区；编辑器使用媒体池、中央预览、工具检查器和分析示波器协作布局。新界面只复用既有真实相机、图库与编辑状态；无连接或无画面时显示 `—`、`OFFLINE` 或明确空态，不把初始化默认值当作实时遥测。iOS 拍摄会话入口、Android 编辑快捷入口和 Windows 窄窗中央预览均已纳入回归门禁；相机连接、拍摄、外录、传输、AI 激活与设备码恢复协议保持兼容。五端共享 ZENCHE 蓝、参数暖金和录制/危险红的角色约定，不复制参考产品的商标或专有图标。

v1.5.3 固定于代码提交 `846e1a0dc49c59b0cc5d032d84f954a98a61add0`、发布提交 `697f3f8d1028426dc5eec430230dcf48754f9b15`：完整 `npm test` 256/256 通过，APK、HAP、unsigned IPA、macOS arm64 DMG、Windows x64 Setup/便携 ZIP 与源码 ZIP 共七包及同名 `.sha256` 已生成并逐个回验。它们不是商店或受信任签名包：Android 使用 Debug 证书，HarmonyOS 与 iOS 未签名，macOS 为 ad-hoc 且未公证，Windows 未做 Authenticode 且仍需真实 Windows 主机验收。文件名、字节数、SHA-256、源码快照和版本资源边界见 `docs/releases/v1.5.3.md`。v1.5.3 已于 2026-08-04 发布为 GitHub Latest，Release 共 14 个附件，线上字节数与 SHA-256 摘要已与本地逐项比对，14/14 一致。

v1.5.3 线上七个交付包的 SHA-256 为：Android `3c79546bb80ea1d1043aae06fc4d5b848d661b72f871f646b3a4c4db8379b182`；HarmonyOS `9dc53cce4375714bfedaac0f7df76e6d225cdeb6fa86f556c6aadc5c30bbd328`；iOS / iPadOS `9ddff92fc0cfc8a98d56edef017a475241ae1f8b4911b84cb559ddba0cd215dd`；macOS `b921f2c3573891fc340e1fac627aa663fa74c7bf28f4ea62a161b8b2eb5e81a5`；Windows Setup `24769cf08627890ee6d67a23aa0567b92b3b9de5c1e0e08d5485a9ec1f7b631c`；Windows ZIP `fd9dbcba313d04180b5561e9e3bc96097247c931dc4558305a547f77e10470dc`；源码 ZIP `686c318574b78186e8cd80bb41c01130bb18b988ff3c7344fa253a330825e382`。

v1.5.2 线上七个交付包的 SHA-256 为：Android `d90bc767d0b1b710f66e5a2b8b15a36e41932ab3a6f563f43fdbb6b6c96f87a9`；HarmonyOS `da67a6373ad4faaf64e19f512e93206f7218068b6ccd2c68d262dcc77760370f`；iOS / iPadOS `97976caca49bd9d00cdfa38f86be0615d7139952e424ffe8f6b3da7ab96712cc`；macOS `37d02a5c5f0a2220dcd9e9ccc93abd9f7e4c859be9ee26c45c587b5cec62d2c0`；Windows Setup `145fa25551ee14bd39bf84f0266aaff069625ba26e47ed38895b651f6ed276af`；Windows ZIP `04ebe53602db9ba7a8e77ed2b51ced917a982aeec379ab62c013a764ae04b57c`；源码 ZIP `676d8a2e7bf3b20c3a316cdff035bd9d48ef22d38b4b62a24232f131a5836a25`。

本次文档同步将根目录 `README.md` 的简体中文、English、日本語三段统一到 v1.5.2：更新稳定版链接、交付包文件名与 SHA-256 示例，并补充全局状态条、设备码恢复、Android 传输降级和零依赖 AI 代理说明。三语内容保持实质等价；发布属性仍以 `docs/releases/v1.5.2.md` 为准。

`NikonLink`、`com.tauber.nikonlink` 等名称是为升级、签名、偏好设置、应用数据和源码兼容保留的内部标识，不是需要继续替换的公开品牌文案。

## 2. 目标用户与核心场景

### 2.1 目标用户

- 使用 Nikon、Sony、Canon 相机进行棚拍、静物、活动、延时或视频监看的摄影师。
- 需要在移动端和桌面端接收、整理、备份与交付素材的个人或小型团队。
- 需要开放、可诊断、可自行构建的跨平台相机工作流用户。

### 2.2 核心场景

1. 通过 USB/PTP 识别相机，建立会话并显示实时取景。
2. 调整快门、光圈、ISO、曝光补偿、对焦、白平衡和 Picture Control。
3. 执行单张拍摄、间隔拍摄、曝光包围、焦点包围和定时 B 门。
4. 使用直方图、波形、矢量示波器、峰值对焦、假色、斑马纹和 `.cube` LUT 监看。
5. 通过 FTP/PASV、HTTP PUT/POST 或 WebDAV 接收相机与局域网设备上传的影像。
6. 按项目、分支和会话整理素材，完成命名、配对、评级、双目标备份和校验。
7. 对照片进行非破坏性调整，导出高质量 JPEG 副本。
8. 通过脱敏日志、版本检查和预填 Issue 完成问题诊断与反馈。
9. 在编辑器中调用 AI 修图与生图：修图会上传当前应用内照片，移动端成功后保存新的应用副本，生图同样另存为新影像；从系统相册导入时系统原片始终不被覆盖，导出会创建新的系统相册项目；服务器负责扣减次数，失败自动回滚。
10. 将联机拍摄、相机卡下载、AI 修图/生图结果和专业编辑副本另存到用户选择的本地位置；导出只创建副本，不移动、删除或覆盖 ZENCHE 文件库源文件。

## 3. 平台范围

产品默认同时维护以下五个原生目标，不通过 WebView 复用界面：

| 平台 | 源码目录 | 主要技术 | Nikon USB/PTP |
| --- | --- | --- | :---: |
| iOS / iPadOS | `native/ios/` | SwiftUI、AVFoundation、PhotoKit | 否，受 Apple 公开 API 限制 |
| Android | `native/android/` | Android Views、Java、USB Host | 是 |
| HarmonyOS | `native/harmony/` | Stage 模型、ArkUI、ArkTS、USB Host | 是 |
| macOS | `native/macos/` | SwiftUI、AppKit、`libgphoto2` | 是 |
| Windows | `native/windows/` | WPF、.NET 8、`libusb` | 是 |

除非任务明确限定平台，产品、界面和共享行为变更必须同步五端。iOS / iPadOS 不虚构 Nikon 厂商 USB 控制能力，但其余工作流、信息架构和可用功能应与其他平台保持合理一致。

顶层 `index.html`、`styles.css`、`app.js`、Service Worker 和浏览器服务属于历史 Web/PWA 实现。未经用户明确要求，不在这些文件中实现原生产品或界面变更。

## 4. 产品能力边界

### 4.1 已定义的共同能力

- **Capture**：设备识别、实时取景、SDRAM 拍摄、JPEG 下载和自动拍摄任务。
- **Control**：曝光、对焦、白平衡、拍摄模式与 Picture Control。
- **Monitor**：专业示波与辅助监看；监看效果不得修改原片。
- **Connect**：FTP/PASV、HTTP PUT/POST、WebDAV 局域网收件箱；PTP/IP 直连相机，含 event 通道 5s Probe 心跳（3s 超时、连续 3 次判离线）、指数退避自动重连（1/2/4/8/16s 封顶 30s、用户主动断开不触发）与网络层监听联动（丢网即判离线并进入重连）。
- **Flow**：“所有文件”优先的本地图库、搜索/筛选/排序、默认收起的项目分类与来源工具、拍摄会话、RAW + JPEG 配对、评级、备份、SHA-256，以及通过系统保存器导出本地副本；macOS/Windows 另提供照片与视频一键多选导入。
- **Develop**：分组参数、预设、前后对比、几何调整，以及将高质量 JPEG 新副本保存到文件库、系统相册或用户选择的本地位置。
- **AI 工具**：AI 修图与 AI 生图、快捷预设、宽高比/分辨率选择、激活码授权与服务器端计数；开源客户端不内置模型 API 密钥。
- **Diagnose**：脱敏日志、更新检查、启动公告、防诈骗提示和问题反馈。
- **Localize**：简体中文、English、日本語运行时切换与持久化。

### 4.2 相机支持（Nikon / Sony / Canon）

五端识别注册表对齐为 50 款机型；直接 USB/PTP 仍主要由 Android、HarmonyOS、
macOS、Windows 承担，iOS 受 Apple 公开 API 限制无厂商 USB/PTP 能力：

- Nikon（20 款）：EXPEED 5（D500、D7500、D850）；EXPEED 6（Z7、Z6、Z50、
  D780、D6、Z5、Z7II、Z6II、Z fc、Z30）；EXPEED 7（Z9、Z8、Z f、Z6III、
  Z50II、Z5II、ZR）
- Sony α（16 款，VID 0x054c 通配）：A1、A1 II、A9 III、A7R V、A7 IV、
  A7S III、A7C II、A7C R、ZV-E1、A6700、FX30、ZV-E10 II、ZV-E10、
  A6100（含 A6100A 识别别名）、A6400（含 A6400A 识别别名）、A6600
- Canon EOS R（14 款，VID 0x04a9 通配）：R1、R3、R5、R5 Mark II、
  R6 Mark II、R7、R8、R10、R50、R100，以及 2025 年按 DIGIC X 世代补齐的
  R6 Mark III、R6（初代）、R5 C、R50 V

机型注册表代表设备识别和参数范围已进入源码，不代表所有固件、镜头、线材、拍摄模式与主机组合均完成实机验收。尤其 ZV-E10、A6100/A6100A、A6400/A6400A、A6600 未列入当前 Sony Camera Remote SDK 公开支持表，只能使用兼容路径。硬件结论必须以 `docs/CAMERA_TEST_CHECKLIST.md` 的实际记录为准。

### 4.3 安全与数据原则

- 产品本地优先，不把照片、CDK、账号或诊断数据默认上传到自有服务。
- FTP、HTTP 和 WebDAV 当前没有 TLS，只能在可信局域网短时启用。
- HTTP/WebDAV 使用 Basic Auth；日志必须过滤密码、令牌、序列号等敏感内容。
- 不在应用内托管第三方网盘账号；导入通过系统文件提供器或对应客户端完成。
- 重要拍摄必须保留相机存储卡，应用不能被描述为唯一备份。
- **AI 功能**：开源客户端不内置模型 API 密钥，模型请求由作者维护的代理服务器持有密钥并转发；仅发送用户主动提交的提示词与（修图模式下）当前编辑照片。AI 使用次数在服务器端计数，激活码绑定设备、每码 100 次。
- **系统照片编辑**：移动端通过系统选择器获得受控 URI/PHAsset，立即复制到 ZENCHE 文件库后才进入编辑器；不得把内容 URI 当作普通文件路径，也不得原位写入系统原片。用户明确导出时调用平台照片库 API 创建新项目；拒绝或限制权限时保留系统设置/授权对话框恢复路径。
- **本地副本导出**：所有平台都通过系统文件保存器选择目标位置；取消不视为错误，成功状态只能在复制完成、同步落盘并通过大小校验后出现。ZENCHE 文件库中的源文件始终保留；同名覆盖是否允许由系统保存器向用户确认，失败时清理本次临时或不完整目标。该能力与“保存到系统相册”分开呈现。
- **W13 账号系统候选与服务端部署**：五端已接入邮箱注册、登录墙、会话校验与账号绑定，原生客户端候选为 `c661f7f`，仍未推送或发布。管理台“总用户”统计由 `adf310d` 增加全部注册账号计数、`9d9ce1e` 明确说明“含未验证、已禁用、未绑定设备账号”，已于 2026-08-09 部署到生产 `/opt/ai-server`；旧文件备份在 `/opt/ai-server-backups/w13-admin-users-20260809T172051+0800`。部署后回环管理 API 返回 `totalAccounts=2`、账号注册表总数 2、`totalDevices=11`，管理台静态脚本与冻结候选 SHA-256 一致。账号密码与 session token 只允许经 `https://zenche.top/api` 访问；历史 `http://101.34.255.115:8787` AI 配置不得作为认证基址，AI endpoint 为 HTTP 时客户端不得附加账号 Bearer。AI审查 与 GPT5.6luna 已分别签发原生视觉/交互、用户可见内容的代码静态 PASS。官网 Nginx 的 `/api/v1/auth/*` 与 `/api/v1/ai` 精确 HTTPS 反代继续通过公网 JSON 401/400 复验；临时冒烟账号已禁用留档。有效激活码的真实 AI 生成、真机视觉/安装矩阵与正式签名发布验收仍未完成，因此 W13 客户端仍不得推送或发布。
- **W14 实时监看与 iOS 相机桥接官网发布**：五端拍照页新增“实时监看”开关，iOS / iPadOS 可在同一可信局域网连接 Mac 相机桥接。Sony 由 Mac 端 Sony Camera Remote SDK 驱动；Nikon 当前明确走 PTP 兼容路径。两家公开的桌面 Remote SDK 均未提供可直接嵌入 iOS 的版本，因此 iOS 没有伪装或改写厂商桌面 SDK。1.5.10 / build 37 官网自动更新已上线；Sony/Nikon 真机联调及正式签名发布验收仍待完成。
- **W15 登录动作清晰化与桌面工作区**：生产 Nginx 专用访问日志在用户报告“点登录没反应”前后未发现 `/api/v1/auth/login` 请求，说明故障发生于客户端提交前。五端登录模式标签改为“已有账号 / 创建账号”，Apple 提交按钮在忙碌态保留动作文字并补齐中英日 exact key；macOS/Windows 新增窗口几何和面板尺寸持久化、越界恢复、可访问分隔条、五种工作区预设及重置。本轮进一步把桌面分隔条改为实时连续调节，增加 Windows AI 工具面板独立宽度，释放 macOS AI 区被重复导航和通用底栏占用的高度，并在窄窗下联动限制侧栏、参数栏和 AI 分栏；Windows AI 临时结果在受限路径和命名守卫下覆盖全部正常生命周期清理。公告不再把各平台一概称为“未签名”，而是引导用户查阅逐包签名状态。最终源码基线为 `831a82315c3586a8c8933c76ef6e8e3612bbcba5`；相关能力已随 1.5.11 / build 38 GitHub Release 公开，并由当前 1.5.12 / build 39 继承。官网生产清单继续保持 1.5.10 / build 37。
- **服务器端自动更新**：`server.mjs` 提供只读 `GET /api/update`（兼容 `/api/updates`）和 `/healthz`。生产可用 `UPDATE_RELEASE_MANIFEST` 完全切换到自托管清单，按五端规范化平台键返回版本、完整包 URL、SHA-256、公告和 `update_available`；未设置清单时继续兼容 GitHub Release 缓存/stale 模式。五端原生客户端默认请求 `https://zenche.top/api/update`，失败后继续 MirrorChyan/GitHub 回退，不直接覆盖应用文件。
- **生产部署状态**：`zenche-update.service` 监听 `127.0.0.1:4174`，1Panel OpenResty 将更新
  API 和 `/downloads/` 公网发布到 `https://zenche.top`；实际静态根为
  `/opt/1panel/www/sites/zenche-top/index/downloads/`。截至 2026-08-20，
  `1.5.14 / build 41` 自托管清单已生效；`/api/update` 与 `/api/updates` 的五端
  响应、健康检查与六个公开包 SHA-256 均已通过。旧版资产继续保留，本次回滚备份位于
  `/opt/zenche-update-backups/20260819T200402Z-v1514`。

## 5. 品牌、文档与发布约束

- 正式标识使用 `icons/app-icon.svg` 的蓝色几何 Z；宣传素材可使用等价品牌资产。
- 不使用旧的“澈”字方块替代 Z 标识，不改写标准标语。
- `README.md` 必须依次包含完整且实质等价的简体中文、英文、日文内容。
- 每个新版本都要同步五端应用内更新公告，且五端变更说明实质等价。
- GitHub Release 正文必须是详细简体中文，包含亮点、平台变化、相机兼容、签名状态、验证、限制、升级指引与 SHA-256。
- 每次向 GitHub 上传源码、标签、Release 或构建附件后，必须在同一工作周期更新 `docs/PROJECT_OUTLINE.md`、`docs/TECHNICAL_APPROACH.md` 和 `docs/TASK_PROGRESS.md`；三份文档必须记录本次版本、提交或标签、Release 链接、上传产物与 SHA-256、验证结果、签名状态、阻塞事项和下一步，作为项目长期记忆。
- 主应用代码变更只有在受影响平台完成验证和可交付打包后才算完成；Windows 代码变更必须生成版本化 NSIS 安装程序及 SHA-256。

## 6. 成功标准

项目的完成度不只看“代码存在”，还要同时满足：

1. 五端范围和平台能力边界正确。
2. 同一功能的行为、状态、文案和持久化语义保持一致。
3. 自动化测试通过，并按风险补充对应回归测试。
4. USB、相机、网络、窗口尺寸和生命周期等真实环境通过验收。
5. 受影响平台生成可下载的版本化交付物及校验文件。
6. 签名、未签名、调试证书、ad-hoc、公证等状态被准确披露。
7. README、Release、更新公告和兼容性文档与实际交付一致。

## 7. 文档职责

- `AGENTS.md`：不可违反的项目规则与交付约束。2026-08-03 由项目负责人提供权威版并纳入版本控制（提交见 `docs/TASK_PROGRESS.md` §12.1）。
- `docs/PROJECT_OUTLINE.md`：项目是什么、服务谁、支持什么、边界在哪里。
- `docs/TECHNICAL_APPROACH.md`：五端如何实现、如何验证、如何构建与发布。
- `docs/TASK_PROGRESS.md`：当前做到了哪里、正在改什么、下一步是什么。
- `docs/CAMERA_TEST_CHECKLIST.md`：相机、USB、网络和平台实机验收记录入口。

上述三份基线文档是发布后的长期记忆载体。每次 GitHub 上传完成后必须同步维护它们；当源码或任务事实与本文不一致时，先验证事实，再在同一变更中更新本文与相关文档；不要让项目知识长期依赖聊天记录。
