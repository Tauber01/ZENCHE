# 帧澈 ZENCHE 实现技术路径

> 文档状态：工程实施基线
> 最近核对：2026-08-04（Asia/Shanghai）
> 前置阅读：`AGENTS.md`、`docs/PROJECT_OUTLINE.md`、`docs/TASK_PROGRESS.md`
> 注：`AGENTS.md` 于 2026-08-03 由项目负责人提供权威版并恢复纳入仓库版本控制，此前远端历史曾删除该文件。

## 0. 1.4.0 AI 链路约定

- 客户端把当前照片编码为完整 `data:image/...;base64,...` URL，通过代理的 `images` 数组传给 Grsai `/v1/api/generate`，并轮询 `/v1/api/result?id=...`。
- 服务器在成功任务完成后扣减 AI 次数并通过 `X-ZENCHE-Remaining` 返回剩余次数；失败请求回滚预扣次数。
- 修图结果使用临时文件和原子替换覆盖当前原图；生图结果使用新的 `ai_generated_*.jpg` 文件保存。

v1.4.0 已于 2026-08-02 以提交 `8a13c0b`、标签 `v1.4.0` 发布到 [GitHub Release](https://github.com/Tauber01/ZENCHE/releases/tag/v1.4.0)。Release 包含 Android、HarmonyOS、iOS unsigned、macOS、Windows Setup 和 Windows ZIP 六个包及六份 `.sha256` 校验文件；签名状态和 SHA-256 以 `docs/releases/v1.4.0.md` 为准。

v1.4.1 的发布事实、构建产物、校验和及签名状态以 `docs/releases/v1.4.1.md` 和 [GitHub Release](https://github.com/Tauber01/ZENCHE/releases/tag/v1.4.1) 为准。

## 0.1. 1.4.1 原生监看约定

- 五端监看卡统一显示 RGB 三色叠加波形（R/G/B 三通道同一坐标系加色混合）和音频波形；音频传输管线尚未接入时只显示静音基线，不生成伪造电平。
- 监看预览点按显示焦点标记并调用现有原生对焦/焦点步进能力；PTP 平台按点击区域映射步进，设备能力不足时如实提示。
- Android 录制键位于两张波形卡之间，监看页移除镜头读数、曝光工具和右上角全屏入口；帧率、快门角度、ISO 等参数在监看页可调。

## 0.2. 1.5.0 外录约定

- 照片继续通过各端 `CaptureWorkflow` 直接写入当前智能设备；视频外录也必须进入同一会话命名、双目标备份、XMP 和 SHA-256 流程。
- Android、HarmonyOS、macOS、Windows 的 PTP 实时取景为 JPEG 帧，外录器直接流式写入可定位的 RIFF/Motion-JPEG AVI，并在停止时回填总帧数、缓冲区大小、`movi` 长度和 `idx1` 索引。
- 标准 PTP 实时取景不提供音频，以上 AVI 明确为无声视频；不得生成伪造音轨。iOS / iPadOS 本机与 UVC 视频源继续使用 AVFoundation MOV。
- 外录可与机身存储卡录制并行；机身拒绝开始录制但实时取景可用时，设备外录继续运行并明确提示。
- 停止录制、相机断开或帧写入失败必须尝试完成已有 AVI/MOV，再刷新文件库；只有没有收到任何有效帧时才删除空文件。

## 0.3. 1.5.2 状态、连接与 AI 恢复约定

- 五端全局状态条统一显示连接状态、当前操作和本地文件库总数；紧凑布局也不得隐藏关键状态，长状态必须截断而不能挤压计数。
- Android USB/PTP 只对已知异步传输失败降级到同步 bulk 传输；首次成功后仅在当前连接会话复用同步路径，重连或关闭必须重置。
- 五端“恢复设备码”固定请求 `https://zenche.top/api/v1/ai/rebind`：发送前用旧设备码本地验签旧激活码，响应后用当前设备码本地验签新码，验证完成后再持久化。迁移保留服务端剩余次数并永久冻结旧绑定；404 必须提示服务暂未开放。
- `ai-server/redeem-rebind.mjs` 只在回环地址提供 `POST /issue-migrated`，Bearer 共享密钥、RSA 私钥和监听端口均由运行时注入；请求体有 16 KiB 上限，日志仅记录短指纹。AI 代理通过回环调用它，私钥不得进入代理进程或仓库。
- 客户端、代理和签发端代码随 v1.5.2 GitHub 稳定版源码交付，但生产换绑保持默认关闭；DNS/HTTPS、Nginx 精确反代、秘密注入、公网 8787 关闭、灰度与回滚未闭环前不得上线。
- v1.5.2 GitHub 附件的产物、SHA-256 与签名状态以 `docs/releases/v1.5.2.md` 为准。Android Debug APK、HarmonyOS unsigned HAP、iOS unsigned IPA、macOS arm64 ad-hoc DMG 和 macOS 主机交叉生成的 Windows x64 Setup/ZIP 延续 v1.5.1 的公开附件属性；GitHub stable 标识不能替代正式证书签名、商店分发、Windows 主机验证或五端实机验收。
- v1.5.2 已于 2026-08-04 发布为 [GitHub Latest](https://github.com/Tauber01/ZENCHE/releases/tag/v1.5.2)，注释标签解析到 `7376cf102ec5ab14208d047f60f28941843fe1c2`。Release 为非草稿、非预发布，共 14 个附件；七个交付包和七份 `.sha256` 的线上字节数及 GitHub SHA-256 摘要已与本地逐项比对，零差异。
- 线上交付包 SHA-256：Android `d90bc767d0b1b710f66e5a2b8b15a36e41932ab3a6f563f43fdbb6b6c96f87a9`；HarmonyOS `da67a6373ad4faaf64e19f512e93206f7218068b6ccd2c68d262dcc77760370f`；iOS `97976caca49bd9d00cdfa38f86be0615d7139952e424ffe8f6b3da7ab96712cc`；macOS `37d02a5c5f0a2220dcd9e9ccc93abd9f7e4c859be9ee26c45c587b5cec62d2c0`；Windows Setup `145fa25551ee14bd39bf84f0266aaff069625ba26e47ed38895b651f6ed276af`；Windows ZIP `04ebe53602db9ba7a8e77ed2b51ced917a982aeec379ab62c013a764ae04b57c`；源码 ZIP `676d8a2e7bf3b20c3a316cdff035bd9d48ef22d38b4b62a24232f131a5836a25`。
- README 同步约定：根目录文档的三语段落必须同时更新 v1.5.2 稳定版链接、交付包命名、校验命令与版本亮点；安装包签名属性、验证结果和已知限制只引用 `docs/releases/v1.5.2.md`，不得把 GitHub stable 标识写成正式签名或实机验收结论。
- 最终独立发布审查以代码提交 `dce831d`、文档提交 `315809b` 和当时已有的四个本地产物为范围，完整测试 248/248、diff 检查、产物哈希/大小、源码 ZIP 树和秘密扫描均通过；结论无 P0/P1，5 项 P2 为非阻塞观察。随后补生成的 macOS/Windows 包另按平台工具完成签名、镜像、容器和 SHA-256 验证。独立审查只放行本地候选；Tauber 在完整风险披露后另行明确授权 GitHub stable 发布，该授权仍不放行生产换绑。

## 0.4. 1.5.3 五端工作台界面约定

- 全屏监看必须以实时画面为主，顶部遥测、焦点十字、工具轨、示波器和底部参数托盘只读取既有相机/监看状态。所有视频波形示波器统一为 RGB 三色叠加（R/G/B 三通道同坐标系加色混合，专业示波板为单面板 RGB 叠加，不再有 Y/YUV 面板）；PTP 无音频源时只显示并标注静音基线，不生成模拟电平。
- 拍摄页使用设备摘要、自适应参数卡和常驻拍摄操作区组织现有连接、曝光、对焦、取景与快门动作。新的视觉层不得创建第二套相机状态或绕过既有可用性/忙碌状态门禁。
- 编辑器使用媒体池、中央预览、工具检查器与分析示波器的协作布局，继续复用既有照片选择、专业显影、AI 工具和高质量副本保存链路；所有本地参数调整保持非破坏性，不因视觉改版覆盖原文件。
- 颜色角色固定为：ZENCHE 蓝表示主操作和选中导航，暖金只表示活动参数/读数，红色只表示录制、停止录制或危险操作。深色工作台可以借鉴参考图的信息密度与层级，不复制参考产品商标、品牌名称或专有图标。
- 新增界面文案必须在简体中文、英文、日文三套资源中同步；紧凑移动端允许横向滚动或重排，但不得隐藏关键连接、拍摄、监看或编辑入口。
- 无连接或无可用画面时，新增 HUD、摘要、输出读数和参数托盘必须显示 `—`、`OFFLINE` 或明确空态，不能把初始化的快门、光圈、ISO、帧率、编码或变焦值呈现为实时数据。快捷入口必须导航到真实控件，不能用提示消息代替交互结果。
- Windows 编辑工作台在 1120 点以下收起媒体栏并压缩工具栏；移动端继续使用可滚动/抽屉式紧凑布局。响应式处理必须优先保留中央画面、拍摄动作与编辑保存入口。
- 1.5.3 对应版本 `1.5.3 / build 28`，已于 2026-08-04 经 Tauber 明确授权发布为 GitHub Latest。
- 当前代码候选固定于 `846e1a0dc49c59b0cc5d032d84f954a98a61add0`，发布提交为 `697f3f8d1028426dc5eec430230dcf48754f9b15`（仅含 README/CHANGELOG 发布信息同步）；完整 `npm test` 256/256 通过，七个版本化交付包及同名 `.sha256` 已生成并回验。Android 为 Debug 证书，HarmonyOS/iOS 未签名，macOS ad-hoc 且未公证，Windows 无 Authenticode 并仍需真实 Windows 主机验收。源码 ZIP 固定于代码提交，包内发布文档是打包前快照；Windows PE 资源记录 `1.5.3`/`1.5.3.0`，未单独编码跨端候选号 `build 28`。完整文件名、字节数和 SHA-256 以 `docs/releases/v1.5.3.md` 为准。
- v1.5.3 已于 2026-08-04T07:43:34Z 发布为 [GitHub Latest](https://github.com/Tauber01/ZENCHE/releases/tag/v1.5.3)，注释标签解析到发布提交 `697f3f8d1028426dc5eec430230dcf48754f9b15`。Release 为非草稿、非预发布，共 14 个附件；七个交付包和七份 `.sha256` 的线上字节数及 GitHub SHA-256 摘要已与本地逐项比对，14/14 一致、零差异。GitHub stable 标识不能替代正式证书签名、商店分发、Windows 主机验证或五端实机验收。

## 0.5. 1.5.7 F1 macOS 基准自修约定（TypeScale 收敛）

- TypeScale 新增页面标题档 `heading ≈ 26pt`（文字页面标题，与 `display 24` 大数字/读数档语义互补）；任一页面仍只用 ≤5 档（页面标题与正文/标签/读数组合不同屏超 5 档）。design.md Typography 已同步该档说明。
- macOS 端字号字面量归 TypeScale：main.swift 正文/标签一律归 TypeScale 5 档（caption 11 / body 12 / emphasis 15 / title 18 / display 24）+ heading 26；图标尺寸（SF Symbols 17-46pt）与专属读数（曝光参数 28、存储读数 25、Splash Z 字标 42）保留原值并在代码注释声明「不受 TypeScale 约束」。
- SettingsSheet 原 13 档字号（10/11/12/13/14/16/17/19/20/22/23/24/26）收敛为 TypeScale 档；其中卡片标题 16→title 18、子项标题 14→emphasis 15、卡片描述/按钮文字 13→body 12、辅助说明 10/11→caption 11、面板主标题 26→heading 26、面板标题 17/20/23/24→title/display；仅 3 处图标尺寸（19/20/22）保留原值并注释。
- 曝光参数卡自动徽标由单字母「A」改为完整「AUTO」字面（对齐 iOS 口径），圆徽标改 Capsule；「选择预设」按钮暗色 tint 由 readoutGlow 改回 cobalt（readoutGlow 仅用于曝光读数，design.md 色板条款）。
- design.md 增补恒深例外条款：fig1 控制面与 fig2 编辑器工作台为恒深页（不随系统外观切换），是「每页双外观」条款的文档化例外；沉浸全屏 overlay 同属恒深例外族，预览井与沉浸 overlay 任何外观下保持石墨。此三处为 v1.5.6 终审遗留文档债的收口。
- 本批仅动 macOS 端与 design.md/docs 三件套；数据契约与四端渲染层零改动。

## 0.6. 1.5.7 逐页批次 P1：照片页四端对齐约定

- 触控目标纪律：参数 tile 的「×」隐藏钮必须 ≥44×44（Android 22×22dp → 44×44dp、Harmony 宽 22vp → 44vp），执行 design.md 触控条款。
- 状态点为纯装饰元素（不承载独立触控）：视觉尺寸对齐 macOS 8pt 基准（Android/Harmony 22 → 10dp/vp），触控面由外层行/容器保证，代码注释声明该口径。
- 曝光 automatic 徽标五端统一为完整「AUTO」字面 + Capsule 形态（macOS F1 定稿，iOS 本批对齐；Android/Harmony 无该徽标形态，不适用）。
- 兑换码说明文案属信息性内容：恢复 4881042 删除的「兑换码仅用于 AI 云服务次数，帧澈本体保持免费开源。」与「没有兑换码？在爱发电购买兑换码」引导，以 TypeScale 档（TS_CAPTION/TS_BODY）呈现，不恢复二维码与重复按钮（保留单区块双按钮结构）。
- P1 批仅执行既有 design.md 条款，不引入新规范；字号归档（iOS F2 / Android F3 / Harmony F4 / Windows F5）由后续地基批处理。

## 0.7. 1.5.7 逐页批次 P2：视频页四端对齐约定

- 监视读数 7 格契约（五端一致）：帧率 / 快门 / 光圈 / ISO / 白平衡 / 编码 / 色调，以 macOS `MonitorView.monitorReadout`（main.swift:6600-6608）为基准；iOS/Android/Harmony 读数轨本批补「编码」格。
- 编码格短标签口径：读数轨内统一用短标签（macOS `shortLabel` / Windows `VideoCodecShortLabel` 同源映射：H.264 / H.265 / ProRes 422 HQ / ProRes RAW / N-RAW / XAVC HS 8K… / XF-HEVC S / XF-AVC S / RAW），iOS 新增 `MonitorVideoCodec.shortLabel`、Android/Harmony 新增 `videoCodecShortLabel()`；全标签（含位深/封装细节）仍用于参数选择器与沉浸参数显示，不混用。
- Windows 读数 22pt 归档：监视读数数值（7 格 + 存储读数）归档为 `MonitorReadout` 样式（等宽 + Bold + 22pt + MonitorWellTextBrush），归 display 档（design.md「display step reserved for large numerals/readouts」）；品牌 Z 标与预览空态提示（DisplayFont 22pt）不属读数，保留字面量待 F5 统一收口。
- 沉浸监视 overlay 属 design.md 固定深色族（L67-76/369），四端维持恒深，不随系统主题切换；本批只复核不改动。
- Harmony `MonitorScopeRail` 缺中间录制钮：底部录制按钮已覆盖交互，记 backlog 不本批处理。

## 1. 总体原则

项目采用“五端原生实现、行为对齐、平台能力如实降级”的技术路线。

- 以 `native/` 下五个平台为产品实现主体，不用 Web/PWA 充当原生功能替代品。
- 共享的是产品语义、状态模型、协议和验收标准，不强行共享 UI 代码。
- 使用各平台原生控件、生命周期、权限、存储和分发机制。
- 保留 `NikonLink` 与 `com.tauber.nikonlink` 等兼容性标识。
- 对相机、USB、签名和操作系统限制做显式能力检测，不以静态 UI 暗示不可用能力。
- 任何跨平台功能都按同一条纵向功能切片推进：设计语义、五端实现、测试、实机验证、打包、文档。

## 2. 分层架构

各平台文件组织不同，但实现时应维持以下逻辑层次：

1. **原生界面层**：导航、页面布局、控件、可访问性、窗口与方向适配。
2. **应用状态层**：连接状态、拍摄参数、任务状态、图库选择、设置与本地化。
3. **工作流层**：拍摄会话、自动拍摄、素材命名、配对、备份、校验和编辑导出。
4. **设备与媒体层**：PTP/AVFoundation、实时帧、图片处理、系统图库和文件提供器。
5. **传输层**：FTP/PASV、HTTP PUT/POST、WebDAV、鉴权、临时文件和原子落盘。
6. **基础设施层**：诊断日志、更新检查、安全存储、公告、构建、签名和发布。

新增功能应尽量进入所属层，避免把协议、文件 I/O 或复杂任务状态全部堆进页面事件处理器。现有部分平台仍是大型单文件实现；扩展时优先复用已有服务类，不做与任务无关的大规模重构。

## 3. 平台实现路径

### 3.1 iOS / iPadOS

- UI：SwiftUI，入口和主要页面位于 `native/ios/NikonLink/`。
- 媒体：AVFoundation、PhotoKit、系统文件选择与分享能力。
- 相机边界：支持系统相机和兼容 UVC 视频源；不实现普通应用无法获得的 Nikon 厂商 USB/PTP。
- 分发：`scripts/build-ios.sh --unsigned` 用于编译与容器验证；正式安装需要证书和 Profile 后运行 `--signed`。
- 安全存储：敏感更新凭据使用系统钥匙串。

### 3.2 Android

- UI：Java + Android Views，不引入 Compose 作为局部替代，除非有明确迁移任务。
- 相机：USB Host 原生 PTP，处理 USB 权限广播、端点、超时、取消请求与拔插恢复。
- 媒体：应用目录、MediaStore、系统文件选择器与分享。
- 分发：`scripts/build-android.sh` 当前生成调试证书签名 APK；正式发布需建立受控签名流程。
- 安全存储：MirrorChyan CDK 等敏感值通过 Android Keystore 保护。

### 3.3 HarmonyOS

- UI：Stage 模型 + ArkUI/ArkTS，主要页面位于 `entry/src/main/ets/pages/Index.ets`。
- 相机：`usbManager` + 原生 PTP；单次 USB 数据传输控制在 200 KB 以下，当前使用 192 KB 分块。
- 媒体：应用私有目录、系统媒体和文件选择能力。
- 分发：`scripts/build-harmony.sh` 通过 Hvigor 生成 HAP；无 signingConfigs 时产物不可直接作为正式安装包。
- 生命周期：离开相关页面或应用状态变化时停止取景、释放 USB 和关闭监听端口。

### 3.4 macOS

- UI：SwiftUI + AppKit。
- 相机：随应用打包 `gphoto2`/`libgphoto2` 及所需动态库；处理系统 PTP 服务抢占、可写属性选择和实时取景子进程管道。
- 媒体：本地文件、Photos、系统打开/分享能力。
- 分发：`scripts/build-macos.sh` 生成 DMG 与 SHA-256；当前为 ad-hoc 签名且未公证。
- 安全存储：敏感更新凭据使用系统钥匙串。

### 3.5 Windows

- UI：WPF/XAML + .NET 8。
- 相机：`libusb-1.0.dll` + 原生 PTP；必须校验 DLL 架构，并清楚提示 WinUSB/libusbK 驱动要求。
- 媒体：本地图库、文件系统、Windows 分享和系统集成。
- 分发：Windows 主机运行 `scripts/build-windows.ps1`，生成 NSIS `Setup.exe`、便携 ZIP 及各自 SHA-256。
- 安全存储：MirrorChyan CDK 等敏感值使用 DPAPI。

## 4. Nikon USB/PTP 技术路线

### 4.1 设备识别

- Nikon Vendor ID 固定为 `0x04b0`。
- Android、HarmonyOS、macOS、Windows 的相机档案必须保持同一机型、Product ID 和 ISO 范围。
- Android USB attachment filter 必须覆盖全部受支持 Product ID。
- 描述符 fallback 用于处理代际后缀与设备报告差异，但不能把未知设备静默识别为受支持机型。

### 4.2 会话与事务

- 打开设备后识别接口和 bulk 端点，再建立 PTP Session。
- 每个事务必须有有限超时、明确错误映射和可恢复清理。
- 相机模式切换、拍摄和属性写入可能与实时取景互斥；执行前暂停、等待 DeviceReady，结束后恢复。
- 不用无限重试掩盖设备被系统、Nikon 软件或其他进程占用。

### 4.3 参数读写

- 先读取设备属性描述符和可写状态，再结合 P/S/A/M/B 模式决定 UI 是否可操作。
- Nikon 照片快门和视频快门需要保留厂商属性与标准 PTP 属性的回退链。
- 写入失败时回读真实机身状态，避免 UI 与相机分叉。
- `0x200F` 等错误应按上下文解释为访问受限或当前不可写，不轻率判断为永久不支持。

### 4.4 拍摄与实时取景

- SDRAM 拍摄完成后按对象句柄下载并原子保存，确保一次快门只产生一份预期文件。
- B 门仅在实际曝光期间进入 Nikon remote/control mode，结束、取消或失败都要释放机身控制。
- 实时取景循环要能在参数写入、拍摄、拔线、睡眠和应用切换后恢复或安全退出。
- JPEG 预览、监看 LUT、斑马纹、峰值对焦等只影响显示，不修改相机文件字节。

## 5. 无线传输技术路线

- FTP 控制端口：`2121`；HarmonyOS 固定 PASV 数据端口 `2122`，其他平台按实现选择可用端口。
- HTTP/WebDAV 端口：`8080`。
- 当前默认凭据：`nikonlink` / `nikonlink`；HTTP/WebDAV 使用 Basic Auth。
- HTTP 支持 PUT/POST，文件名可来自路径、`filename` 查询参数或 `X-Filename`。
- WebDAV 至少覆盖 `OPTIONS`、`PROPFIND`、`MKCOL`、`PUT`。
- 对文件名做规范化与目录穿越防护；大文件先写 `.part` 或临时文件，完成后原子移动。
- 重名文件生成唯一名称，不覆盖已有素材；缺少 `Content-Length` 或鉴权失败时不创建空文件。
- 服务只在用户明确开启且应用生命周期允许时监听，退出后释放全部端口。

## 6. 本地工作流与图像处理

### 6.1 拍摄会话

- 会话配置包括项目目录、命名模板、RAW + JPEG 配对、XMP 评级、双目标备份与 SHA-256 清单。
- 状态必须可持久化、可恢复并能区分未完成、失败和已验证交付。
- 自动拍摄任务需要取消、进度、错误恢复和任务互斥控制。

### 6.2 素材树与图库

- 支持任意层级用户分支、持久化展开状态、拖拽归类、安全删除和缩略图。
- 删除分支时恢复或迁移其中素材，不能静默删除原文件。
- 手机采用默认折叠抽屉，平板、折叠展开态和桌面保留常驻树状工作区。

### 6.3 非破坏性编辑

- 调整参数按光线、色彩、细节、效果和几何分组。
- 原始文件保持不变；预设透明可追溯；支持前后对比、重置和高质量 JPEG 副本导出。
- 五端的参数名称、范围、默认值、旋转翻转和裁切语义需要对齐。

### 6.4 AI 修图与生图

- 五端编辑器提供 AI 工具面板：AI 修图（基于当前照片）与 AI 生图（纯文本），含快捷预设、宽高比与分辨率选择。
- **密钥架构**：开源客户端不内置任何模型 API 密钥。客户端把 `激活码 + 设备ID + 提示词 + 图片` 发送到作者私有代理服务器，由服务器用自有密钥转发 grsai（nano-banana-fast）并下载图片、以 `{data:[{b64_json}]}` 返回。修图模式的原图以完整 `data:image/...;base64,...` 数据 URL 传递，代理原样放入上游 `images` 数组。
- **授权与计数**：激活码为 RSA 离线签名，绑定设备 ID、每码 100 次；次数在服务器端 JSON 存储中按设备累计，失败（上游异常）自动回滚扣减。客户端本地只保存激活码文本，不再计数。
- **服务器**：仓库内候选实现为 `ai-server/app.mjs`，采用纯 Node 零依赖 HTTP 代理和可注入 `createApp` 工厂；默认仅监听 `127.0.0.1`，正式 CLI 端点为 `POST /v1/ai`。上游 grsai 走 JSON `POST /v1/api/generate`，请求使用 `model`、`prompt`、`images`、`aspectRatio`、`imageSize` 与 `replyType`，异步结果经 `/v1/api/result` 轮询后限流下载。请求体、上游 JSON 和图片响应均有流式大小上限；消费提交与失败退款共用 `tmp → 文件 fsync → rename → 目录 fsync` 耐久写盘和 fail-stop 恢复。生产 `/opt/ai-server/server.js` 尚未由该候选替换。
- **设备码换绑**：`POST /v1/ai/rebind` 默认关闭，只有显式设置 `ZENCHE_AI_ENABLE_REBIND=1` 且注入 `ZENCHE_REBIND_SECRET`（或测试签发器）时才注册。服务端先校验旧码与旧设备绑定，再通过回环 redeem 服务签发绑定新设备的新码并本地二次验签，最后单次耐久事务冻结旧记录、创建新记录并原样继承 `used`/`expiry`。in-flight 计数 Map 与 rebind 写锁阻断 AI 请求、退款和迁移交错；IP 与激活码指纹双桶限流，审计只记录 SHA-256 短指纹。公网只允许经 `https://zenche.top/api/v1/ai/rebind` 精确反代，DNS 未切换或公网 8787 未关闭时禁止启用。
- **客户端恢复**：五端只在本地旧码验签通过后提交 `activationCode`、`oldDeviceId`、`newDeviceId`，并在服务端成功响应后对 `newCode` 做当前设备二次验签，再以各平台的耐久存储能力替换激活状态。网络与响应体均设上限，日志不得输出旧码、新码或完整设备码。
- 服务器地址由五端内置代理配置统一提供，默认 `http://101.34.255.115:8787`；设置面板不再提供可编辑入口。为兼容升级，客户端仍会读取历史保存的 `aiServerURL`、`ai_server_url` 或 `ai-server-url.txt` 值。

## 7. 本地化、更新与诊断

- 五端必须提供简体中文、English、日本語并持久化选择。
- 动态状态、错误、任务进度和新 UI 文案都要走运行时本地化，不只翻译静态标题。
- 每个新版本同步五端更新公告，并按应用版本记录“不再提醒”。
- 更新检查优先 MirrorChyan，资源不可用、CDK 无效或无完整安装包时回退 GitHub Releases。
- 更新服务现在增加自有元数据入口：五端默认请求 `https://zenche.top/api/update`（可通过
  `ZENCHE_UPDATE_ENDPOINT` 覆盖），查询 `platform`、`arch`、`current_version` 和
  `channel=stable`。`server.mjs` 同时保留 `/api/updates` 兼容别名与 `/healthz`，从
  GitHub Releases 选择完整安装包并返回 `schema_version: 1`、`url`、`sha256`、
  `release_url`、`announcement`、`minimum_supported_version` 和 `update_available`。
  服务端按 channel 缓存 5 分钟，GitHub 暂不可用时返回最近缓存并标记 `stale`；没有
  缓存则返回 503。客户端校验 product/schema 后才使用结果，服务不可用仍按
  MirrorChyan → GitHub 顺序回退。生产实例已部署到 `ubuntu@101.34.255.115`：
  `zenche-update.service` 监听 `127.0.0.1:4174`，Nginx 反代 API 并从
  `/var/www/zenche.top/downloads/` 提供 v1.4.1 六个官方安装包和六份 `.sha256`；
  `UPDATE_ASSET_BASE_URL=https://zenche.top/downloads` 使 `url` 指向服务器资产，
  `release_url` 保留 GitHub 页面。服务器本机五平台回源、静态下载和 SHA-256 已验证。
  截至 2026-08-02，公网 DNS 仍解析到 `45.207.210.254`，切换 DNS/CDN 到
  `101.34.255.115` 后才可进行公网闭环验收。部署参数和反向代理要求见
  `docs/AUTOMATIC_UPDATES.md`。
- 敏感 CDK 不进入诊断日志；各平台使用对应安全存储。
- 诊断日志需要限量滚动、保留周期、隐私脱敏和可操作错误上下文。

## 8. 推荐实施流程

### 8.1 开始前

1. 阅读 `AGENTS.md` 和三份项目基线文档。
2. 运行 `git status --short`，识别现有未提交改动并保护用户工作。
3. 确认任务是否是产品/界面/共享行为；若是且未限平台，范围默认为五端。
4. 搜索五端对应实现、测试、版本公告、README 与构建脚本。
5. 明确能力差异、签名要求、主机限制和预期交付物。

### 8.2 实现中

1. 先定义共同状态、行为、错误和文案，再分别使用平台原生实现。
2. 保持移动端 iOS、Android、HarmonyOS 的信息架构和行为对齐。
3. 不修改不相关的 Web/PWA、品牌标识、包名或持久化键。
4. 对共享行为补充静态一致性或单元回归测试。
5. 及时更新 `docs/TASK_PROGRESS.md` 的当前状态、验证证据与剩余阻塞。

### 8.3 验证与交付

1. 运行 `npm test`。
2. 执行受影响平台的编译、UI/生命周期、网络与硬件验收。
3. 对跨平台主应用变更打包五端；Windows 代码变更必须在 Windows 主机生成 NSIS 安装器。
4. 校验所有 `.sha256`，记录签名、公证、证书和可安装状态。
5. 若产生新版本，同步版本号、构建号、五端公告、三语 README、CHANGELOG 和详细中文 Release。
6. 最终交付时提供每个生成包及校验文件的绝对可点击路径；受主机、工具链或签名阻塞的目标要写明准确原因与预期文件名。
7. 每次 GitHub 上传源码、标签、Release 或附件完成后，立即更新 `docs/PROJECT_OUTLINE.md`、`docs/TECHNICAL_APPROACH.md` 和 `docs/TASK_PROGRESS.md`，写入版本、提交/标签、Release 链接、实际上传文件及 SHA-256、验证证据、签名状态、阻塞和下一步；未完成这组三份文档同步，不得视为发布收敛。

## 9. 自动化测试策略

当前 `npm test` 主要使用 Node 内置测试进行源码一致性和回归检查，覆盖：

- 20 款相机注册表与 Android USB filter 对齐。
- PTP 快门回退、B 门释放、macOS 实时取景管道等已知缺陷。
- 五端三语、本地化动态状态、设置图标和移动端布局约束。
- 启动公告、防诈骗、MirrorChyan、安全存储和更新回退。
- 图像编辑、素材树、沉浸参数、自动拍摄、会话与专业监看。
- 版本号、构建号、Release 工作流和打包脚本一致性。
- AI 代理真实 generate→poll→download、流式资源上限、耐久写盘故障注入，以及设备码换绑的验签、幂等、链式迁移、计数继承、限流、签发失败零副作用和并发写锁。

这些测试不能替代实机。USB/PTP、相机固件、驱动、签名安装、网络中断、性能、内存、方向切换和窗口缩放必须另行验证。

## 10. 完成定义

一项应用功能只有同时满足以下条件才可标记完成：

- 需求范围内的五端实现完成，能力差异被明确处理。
- 文案与本地化完整，持久化和升级兼容未被破坏。
- 自动化测试通过，新增风险有回归覆盖。
- 必要的模拟器、桌面启动、网络与相机实机验证有记录。
- 受影响平台交付物生成且 SHA-256 通过。
- 签名与可安装状态准确披露。
- 相关 README、进度、验收、公告和 Release 文档同步。
- 每次 GitHub 上传后，`docs/PROJECT_OUTLINE.md`、`docs/TECHNICAL_APPROACH.md` 和 `docs/TASK_PROGRESS.md` 已同步记录发布事实，后续智能体可仅依据这些文档恢复上下文。

仅有源码、仅能编译、仅有未签名容器或仅在一个平台实现，都不能替代上述完整交付定义。
