# 帧澈 ZENCHE 实现技术路径

> 文档状态：工程实施基线
> 最近核对：2026-08-10（Asia/Shanghai）
> 前置阅读：`AGENTS.md`、`docs/PROJECT_OUTLINE.md`、`docs/TASK_PROGRESS.md`
> 注：`AGENTS.md` 于 2026-08-03 由项目负责人提供权威版并恢复纳入仓库版本控制，此前远端历史曾删除该文件。

## 0. 1.4.0 AI 链路约定

- 客户端把当前照片编码为完整 `data:image/...;base64,...` URL，通过代理的 `images` 数组传给 Grsai `/v1/api/generate`，并轮询 `/v1/api/result?id=...`。
- 服务器在成功任务完成后扣减 AI 次数并通过 `X-ZENCHE-Remaining` 返回剩余次数；失败请求回滚预扣次数。
- 修图结果使用临时文件和原子替换覆盖当前原图；生图结果使用新的 `ai_generated_*.jpg` 文件保存。

v1.4.0 已于 2026-08-02 以提交 `8a13c0b`、标签 `v1.4.0` 发布到 [GitHub Release](https://github.com/Tauber01/ZENCHE/releases/tag/v1.4.0)。Release 包含 Android、HarmonyOS、iOS unsigned、macOS、Windows Setup 和 Windows ZIP 六个包及六份 `.sha256` 校验文件；签名状态和 SHA-256 以 `docs/releases/v1.4.0.md` 为准。

v1.4.1 的发布事实、构建产物、校验和及签名状态以 `docs/releases/v1.4.1.md` 和 [GitHub Release](https://github.com/Tauber01/ZENCHE/releases/tag/v1.4.1) 为准。

## 0.0. 1.5.10 实时监看、iOS 桥接与官网清单约定

- 五端“实时监看”只控制取景帧拉取和缓存画面，不改变相机会话、快门或文件接收链路；关闭态必须显示本地化空态，不能保留上一帧。
- iOS / iPadOS 不嵌入桌面相机 SDK。Sony 官方 Camera Remote SDK 在可信局域网内的 Mac 桥接端运行；Nikon 当前为明确标注的 PTP 兼容桥接。
- 官网更新使用 `UPDATE_RELEASE_MANIFEST=/opt/zenche-update/release.json` 切入自托管清单模式；`UPDATE_ASSET_BASE_URL=https://zenche.top/downloads` 生成下载地址。发布顺序固定为上传带版本号的新资产、校验服务器 SHA-256、原子替换清单、验证五端 API，再允许旧客户端发现更新。
- 清单只发布完整安装包及其 SHA-256，不执行静默覆盖。iOS / HarmonyOS 未签名、macOS ad-hoc 未公证、Windows 无 Authenticode、Android Debug 证书的边界必须随包披露。
- 1.5.10 / build 37 打包源码为 `a9bb11bc0068920aaa8630ebb14d4ed3126dc410`；交付表与生产回滚口径见 `docs/releases/v1.5.10.md`。
- 官网自托管清单已于 2026-08-10（Asia/Shanghai）切入生产，五端公网更新响应、兼容路由与六个公开包 SHA-256 均通过；回滚备份位于 `/opt/zenche-update-backups/20260809T163105Z-v1510-r2`。

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

## 0.8. 1.5.7 逐页批次 P3：编辑页四端对齐约定

- 编辑页字号归档纪律（只归档不改值）：非 TypeScale 五档的既有值（9/10/13/14/16）以文件级命名常量保留原值（Harmony/Android `EDITOR_FS_TINY/SMALL/SUB/MEDIUM/HEAD`、iOS `EditorFontSize.tiny/small`），与 TS 五档重合值（11/12）直接映射 `TS_CAPTION`/`TS_BODY`；字号数值统一收口归 F5，本批不改任何显示值。
- 十组工具契约（五端一致）：光线 / 色彩 / 色轮 / 曲线 / 取色器 / 蒙版 / 细节 / 效果 / 几何 / AI，命名以 macOS `EditorToolRail`（main.swift:9543，十组 8608-8618）为基准；Windows 工具组添加顺序已按基准拉齐（色轮/曲线/取色器/蒙版位于细节/效果之前）。渲染形态差异保留：macOS/iOS 用 `EditorAdjustmentSection.allCases` 枚举平铺，Windows/Harmony/Android 用 5 钮 EditorToolRail + 面板钮，属既有平台结构差异（守门测试只断言分组标签，不断言导航形态）。
- Windows 归档边界（口径勘误 2026-08-05）：字号字面量归档以 **EditorPanel 元素树**为界（XML/ET 解析实测 EditorPanel 子树 FontSize=0 / FontFamily=0）；SettingsPanel 为兄弟面板（开于 L1703），其元素树内 8 处字号字面量（L1839/1855/1880/1888/1897/1906=11、L1957=15、L1961=12，AI 激活/恢复设备码/快速反馈区，对标 macOS SettingsSheet）属 **P6 设置页**，本批未动、归 P6 收口；快速反馈对话框与底部 AppBar 状态栏亦属 P6/全局 chrome。注：按行号区间口径（EditorPanel 开标签 L1174 起配对）该区间包含 SettingsPanel 行段，两种口径的差异源于 XAML 兄弟面板定义顺序。
- 共享面板口径（勘误 2026-08-05）：审计文档无 `buildNikonCloudMonitorPanel` 条目，原「按审计列 P3」表述不实；实际为拍摄/视频页共享面板的延伸归档（Android L8601「尼康云创监看」13→EDITOR_FS_SUB，值等值、无行为改变），记 backlog：F3 批核对时避免重复处理。
- AI 区差异：macOS/iOS 编辑页「AI 工具」为工具分组之一，Windows/Harmony/Android 以「AI」轨钮 + 独立工作台呈现——既有设计差异，不视为五端契约缺口，本批不合并形态。
- 沉浸 overlay 四件套、RGB 波形渲染层、导航 chrome 不在本批（同 P2 红线，见 0.7）。

## 0.9. 1.5.7 逐页批次 P4：我的设备页四端对齐约定

- 设备页大标题档位：非 TypeScale 五档的既有值（iOS/Android/Harmony 30、Android 25、Harmony 19/21、四端 13/14）以文件级命名常量保留原值（iOS `DeviceFontSize.heading`、Android `PAGE_FS_HEADING/HEADING_COMPACT/SUBTITLE` + `DEVICE_FS_EMPTY_TITLE/SUB`、Harmony `DEVICE_FS_HEADING/SUBTITLE/EMPTY_TITLE/CARD_TITLE/SUB`），与 TS 档重合值（12/18/11）直接映射既有 token；字号数值统一收口归 F5，本批不改任何显示值。
- Android `sectionHeader` 为**共享组件**（4 个调用方：6167/6597/10640/11149），其字号归档以中性名 `PAGE_FS_*` 落位，影响全部调用方但值不变、零视觉变化；设备页专属字号用 `DEVICE_FS_*`。
- 设备卡信息行契约（五端一致）：`vendor · transport`（以 macOS `RememberedDeviceCard` 为基准）；iOS/Android 原仅显示 transport，本批补 vendor 信息项；其余信息项（名称/当前已连接徽标/最近连接/快速连接+忘记设备）五端一致。
- 双外观纪律（P4 为非恒深页）：前景/背景一律按外观成对取 token（iOS `IPalette.*` / Harmony `$r('app.color.*')` / Windows `DynamicResource`），不引入硬编码单外观色值——Android 本批新增 `POSITIVE_SOFT` 常量收口「当前已连接」徽标软底硬编码；恒深面上的白字（iOS vendor 徽标、Windows 占位图标）属恒深例外族豁免。
- 图标尺寸豁免：设备页空态/占位图标（◉ 46/48）不受 TypeScale 约束，保留原值并注释声明（同 F1 先例）。
- 沉浸 overlay 四件套、RGB 波形渲染层、导航 chrome 不在本批；Windows EditorPanel 内 AI 激活区 8 处字面量归 P6；云创监看面板已归档（见 0.8 勘误）不重复处理。

## 0.10. 1.5.7 逐页批次 P5：分支文件库页四端对齐约定

- 分支页字号归档：非 TypeScale 五档的既有值以文件级命名常量保留原值（iOS `PageFontSize.titleCompact=25/titleRegular=29`；Android `LIBRARY_FS_WORKBENCH=20/TITLE=14/SUB=13`；Harmony `LIBRARY_FS_TINY=10/SUB=13/TITLE=14/HEAD=16/WORKBENCH=20`；Windows 样式 `LibraryHeaderTitle(24)/LibraryNodeIcon(15)`），与 TS 档重合值（12→TS_BODY、11→TS_CAPTION）直接映射既有 token；字号数值统一收口归 F5，本批不改任何显示值。
- iOS `PageTitle` 为**共享组件**（3 调用方：1964/6088/7703），紧凑 25 / 常规 29 以中性名 `PageFontSize.*` 落位，影响全部调用方但值不变、零视觉变化；对齐 P4 Android `PAGE_FS_*`（sectionHeader 共享组件）先例。
- **无线传输面板属分支页组成部分**（macOS 基准 LibraryView 右列即无线传输折叠组 TransferView，8066-8070，已 token 化）：Android `buildWirelessTransferPanel/buildWifiCameraPanel`、Harmony `WirelessTransferCard/WifiCameraTransferSection` 一并归档（差距分析初版遗漏，本批补录）；iOS `WirelessTransferCard` 全系统字体、Windows 无线传输 Expander 无字号字面量，无需处理。
- Harmony `CaptureSessionPanel`（6201）属 P1 组件（仅 CameraWorkspace 4270 调用），不在本批范围；其内部 6277 的 13 保留字面量。
- 双外观纪律（P5 为非恒深页）：四端分支页前景/背景按外观成对取 token（Android INK/MUTED/COBALT/COBALT_SOFT 经 applyAppearanceTokens、Harmony $r('app.color.*')、iOS IPalette、Windows DynamicResource），无硬编码单外观色值；恒深色块上的白字（iOS 28pt 图标、Windows 16 图标）属豁免族注释声明。
- 信息项一致性以「存在等价操作」为判定（不强制五端布局相同、不改标签文案）：顶部工具条五端等价（刷新相册/链接网盘/分享/访达显示/移到废纸篓）；大图预览/文件行操作等价。标签文案（iOS「文件」/Android「已下载」/Harmony·Windows 侧栏长名）属 F6 词表裁定，本批不动。
- 图标尺寸豁免：iOS 28pt 分支工作台图标、Harmony 徽标方块 16/播放 ▶ 20、Windows 相机存储行图标 16 保留原值并注释声明（同 F1 先例）。
- 不在本批：导航 chrome/沉浸 overlay/波形层；Windows EditorPanel AI 激活区归 P6；云创监看面板已归档（见 0.8 勘误）。

## 0.11. 1.5.7 逐页批次 P6：设置页五端对齐约定（本批动 macOS 基准端）

- macOS SettingsSheet 字号归档由 F1 主体完成（13 档→TypeScale 五档），P6 收尾：剩余语言选择器 11 等值映射 `TypeScale.caption`；19/22/20 图标尺寸豁免（F1 注释）。DiagnosticLogViewer 已全 token 化。
- 设置页专属档位命名约定（延续 P3-P5 先例）：非 TS/FontToken 五档值以页面级常量保留原值——iOS `SettingsFontSize.linkLabel=13`；Android `SETTINGS_FS_TINY=10/SUB=13`；Harmony `SETTINGS_FS_TINY=10/SUB=13/TITLE=14`；Windows 样式 `SettingsHint(11)/SettingsCardTitle(16)/SettingsFeedbackTitle(15)/SettingsFeedbackBody(12)/SettingsLogTitle(22)/SettingsLogBox(12)`。与 TS 档重合值（Android 12/11/18→TS_BODY/TS_CAPTION/TS_TITLE）直接映射既有 token；只归档不改值，数值收口归 F5。
- Windows 拍摄辅助卡（cs BuildCaptureAssistSettingsPanel）与诊断日志弹窗（ViewLogs_Click）属设置页功能，其字号与 FontFamily 字面量一并归档（cs 用 `Style=FindResource` 引用，P4 设备卡先例）；日志框 "Cascadia Mono, Consolas"→MonoFont 资源（Colors.xaml MonoFont=Cascadia Mono 等值）。公告弹窗（launch-announcement）非设置页、红线锁文案，不在本批。
- 分区对齐口径：macOS 六区（外观/拍摄辅助/自动更新/AI 激活与兑换/诊断日志/捐赠·反馈）为契约；外观区为 macOS 专属（ThemeMode 三选），四端跟随系统外观属等价行为不强制加区；四端均含其余分区（语言/SDK 卡为等价补充信息项）。
- 页式 vs sheet 形态裁定：Android/Harmony/Windows 设置页式、iOS/macOS sheet——保留（design.md:407 允许导航容器差异）。
- 不在本批：Windows cs:4724 等 9 处画刷快照（归 F5）、Harmony CaptureSessionPanel（P1）、导航 chrome/沉浸 overlay/波形层。

## 0.12. 1.5.7 F3 Android 收口批约定

- 死常量删除判据：定义处之外全文件 grep 引用计数=1（仅定义行）即死；删除前须排除其他文件引用与测试文本断言。STUDIO_GOLD/STUDIO_PANEL 因 native-ui-1.5.3.test.mjs:80-81 对五端源码文本断言 `studioGold|STUDIO_GOLD|StudioGold` / `studioPanel|STUDIO_PANEL|StudioPanel`，删除定义后标识符保留于注释（文本断言满足；其他四端有实际 token 落地，仅 Android 无，注释如实声明）。
- 字号归并口径（延续 P 批）：能映射 TS 五档（11/12/15/18/24）的直接映射为 TS_CAPTION/TS_BODY/TS_EMPHASIS/TS_TITLE/TS_DISPLAY，等值不改渲染；P 批已归档的 FS 档位（PAGE_FS_*/EDITOR_FS_*/DEVICE_FS_*/LIBRARY_FS_*/SETTINGS_FS_*）不重复处理；落不了 TS 档的孤立值保留原值，列清单归 F5 数值裁决；条件式/三元（含可映射值）不拆改。
- 导航 chrome/沉浸 overlay 的字号（◉⋯ 18pt 字符钮、immersive 读数）属 F3 归并范围（只做 TS 等值映射，不改渲染值）；P1 的「导航 chrome 不动」红线指结构/样式不动，字号等值归并不冲突。

## 0.13. 1.5.7 F5 Windows 收口批约定

- 画刷快照收口模式：cs 中禁止 `new SolidColorBrush((Color)FindResource("ColorX"))`（构造期冻结值）——统一改为 `(Brush)FindResource("XxxBrush")` 共享实例引用（Colors.xaml 已为每个 Color 定义配套 Brush，Color 经 DynamicResource 跟随主题字典切换）。**口径修正：audit 9 处中仅 PhotoSoftBorder 1 处有亮暗主题对（真实热切换修复），其余 8 色两主题同值属等价重构。**
- 11pt 双样式分工：`MetaText`（MonoFont 等宽）= 等宽元信息（版本号/状态/节点详情）；`SettingsHint`（非等宽）= 普通说明文字（设置页提示）。同值不同用途，不合并，注释声明。
- 数值裁决基准（改值需 macOS 证据）：读数档=macOS monitorReadout 值 `TypeScale.title`(18)；页面标题档=macOS `TypeScale.heading`(26)（WorkspaceHeading 设备/分支页）；日志弹窗标题=macOS `TypeScale.title`(18)。Windows 端已执行 22→18（MonitorReadout/SettingsLogTitle）、24→26（Device/LibraryHeaderTitle）。其余端标题档值（iOS 29/25、Android 30/25、Harmony 30）为各自批次归档值，对齐裁定归 F5 已记录、执行留各端后续批。

- F5 打回补遗（pro 复审 3 必改 + 1 docs 勘误）：①MainWindow.xaml 66 处 FontSize 全量归档（Monitor/Capture 62 处入样式、AppBar 品牌 Z22/名19/⚙20 与对焦框＋38/◉48/图标16 豁免注释；新建 MonitorTimecode/MonitorEmptyState/MonitorWellLabel/MonitorCloudTitle/MonitorOverlayMeta/MonitorStorageIcon/CaptureFieldLabel/CaptureFieldValue/CaptureStatusHint/CaptureSubHint/CaptureCardTitle/CaptureReadoutLabel/CaptureReadoutValue/CaptureReadoutUnit/CaptureCloudTitle/CaptureCloudSub/CaptureSessionHint/CaptureEmptyTitle/CaptureBadge/ShootingTaskHint/ProfMonitorValue/SidebarHint 22 样式）；②cs 16 处非 TS 档字号归档（8/10/13/14/16/17/19/25/26 → TelemetryMicro/DialogHint/ImmersiveLabel/FastFeedbackMono/DialogTitle/AnnouncementHeading/Section/Title/Text/Sub 10 样式；录制钮 16 为按钮符号字号注释声明）；③Warn/ErrorSoft 暗色对（Theme.Dark 补 ColorErrorSoft/WarnBg=#3A1B1E 对齐 design.md:59 Video soft 暗、WarnBgSoft=#5C2B30 中间档）；④docs 口径勘误（9 处仅 1 处真实热切换修复）。
- 公告弹窗字号与 macOS 对照（记录差异，改值待 kimi 裁决）：Windows 更新公告 25 vs macOS heading=26、本次更新 19 vs macOS title=18、谨防诈骗/自愿赞助 17 vs macOS title=18、正文 14 vs macOS body=12——本批只归档不改值。

## 0.14. 1.5.7 F2 iOS 收口批约定

- iOS 字号归档口径（延续 F3/F5）：值等值映射既有档优先（9→EditorFontSize.tiny、10→EditorFontSize.small、13→SettingsFontSize.linkLabel），图标/品牌豁免注释声明（Splash 品牌资产、SF Symbol 图标），孤立值保留原值列清单归 F5 数值裁决（8/17/25/28/32 档）。
- 动态字档（.caption/.headline 等：标识符出现 249 处 / 实际 .font() 调用 115 处，口径修正见 F2 pro 观察项）为 iOS 平台动态字体惯例，与 FontToken 固定 5 档语义不同——保留，不映射替换；映射关系仅落 docs（caption≈caption、headline≈emphasis、title2/3≈title、largeTitle≈display 为近似语义，非等值）。
- STUDIO_* 死定义清理模式（F3 Android 先例）：全文件引用计数=1（仅定义处）即死；删除定义后标识符保留原位注释（native-ui-1.5.3.test.mjs:80-81 对五端源码文本断言 studioGold/studioPanel）。
- AUTO 徽标契约：五端统一「AUTO」胶囊（caption/11pt bold + Capsule + height 18），iOS P1 已对齐，后续批次核验不重复改。

## 0.15. 1.5.7 F4 Harmony 收口批约定

- Harmony 字号归档口径：值等值映射既有 EDITOR_FS_* 档（9→TINY、10→SMALL、13→SUB、14→MEDIUM、16→HEAD）；TS 五档外且无 FS 档的孤立值（8/17/19/21/22/28/32/36/38/42）保留原值列清单归 F5；图标/品牌豁免注释声明（SF 语义字符 ☰⚙✨⚡☕ 与状态点 ● 同 F1 先例）。
- STUDIO_* 清理判据修正：引用计数=1（仅定义处）即死；**有实际使用的必须保留**（Harmony STUDIO_CANVAS 两处沉浸 HUD 底使用，故仅删 PANEL/RAISED/RULE/GOLD 四死定义，与 F3 Android 全删差异源于真实使用情况）。
- MonitorScopeRail 契约：monitor 区三件套（RGB 波形 + 中间录制钮 + 音频波形）五端统一；录制钮交互参照 ImmersiveCaptureButton（■/● + UI_VIDEO + toggleVideoRecording）。
- 动态字档计数口径：标识符出现数 ≠ 实际调用数（iOS .font() 249 出现 / 115 实际调用），报告时双口径并陈。

## 0.16. W13 邮箱账号客户端安全边界（未发布候选）

- 认证 API 基址固定为 `https://zenche.top/api`，再拼接 `/v1/auth/*`；认证请求不得读取或继承历史 AI 服务器偏好。构造请求后仍须校验 HTTPS scheme 与官网 host，禁止自动重定向，并限制响应体大小。
- HTTP 响应必须是 JSON Content-Type、可解析对象且包含接口所需字段：登录/注册需要非空 token 与 account.email，`/me` 需要非空 account.email。HTML、畸形 JSON、字段缺失、响应超限或终点异常均属于协议失败，不得进入离线容忍；只有真实网络失败与格式正确的服务端 5xx 可保留缓存登录态。
- iOS/macOS 的 session token 使用 Keychain `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`，forced-signed-out 标记使用 Application Support 原子文件；Android 使用 AndroidKeyStore AES-256-GCM 与 no-backup tombstone；HarmonyOS 使用 HUKS AES-256-GCM 与 preferences 两阶段标记；Windows 使用 DPAPI CurrentUser 单一会话包与原子 tombstone。安全存储写入、标记清除或本地清理失败必须保持登录墙并显示错误，不能伪装成登录或登出成功。
- `/v1/auth/me` 的 401 与 403 都代表本地会话不可继续，必须清 session 回登录墙；启动校验期间不得挂载或暴露主工作区。登出同时关闭连接 dialog/sheet/overlay，并停止相机、无线、蓝牙、定位与外录等后台态。
- `email-code` 的 503 是 SMTP 未配置的专用过渡态：客户端隐藏验证码并允许服务端按免码开关裁决；严格态仍要求 6 位数字验证码。五端表单提供 60 秒倒计时、44pt/dp/px 触控目标、键盘/焦点链、错误播报与桌面/平板内容宽度上限。
- 账号绑定要求 AI 请求携带 Bearer，但只有 AI endpoint 本身是 HTTPS 时才可附加；历史 HTTP AI 地址继续兼容匿名旧流程，不能携带账号 token。2026-08-09 官网 Nginx 已将 `/api/v1/auth/` 前缀映射到回环 `/v1/auth/`，并将 `/api/v1/ai` 精确映射到回环 `/v1/ai`；认证请求体限制 64 KiB，AI 请求体限制 64 MiB，原配置备份在 `/etc/nginx/sites-available/zenche.top.bak-20260809T154854+0800`。公网账号完整冒烟与无效激活 JSON 路由已通过，临时冒烟账号已禁用且未绑定设备；有效激活码的真实 AI 生成和五端真机矩阵仍须完成，W13 客户端在此之前不得进入发布分支。
- 管理台总览的“总用户”必须读取账号注册表总数，未验证、已禁用、未绑定设备的账号都计入；`totalDevices` 继续单独表示迁移链折叠后的激活设备。候选 `adf310d` 在 `/v1/admin/stats` 增加 `totalAccounts`，返修 `9d9ce1e` 将总览说明明确为“含未验证、已禁用、未绑定设备账号”，不能再用已激活设备数代替用户数。2026-08-09 已按冻结哈希部署 `app.mjs`、`auth.mjs` 与 `admin/app.js`，旧文件备份在 `/opt/ai-server-backups/w13-admin-users-20260809T172051+0800`；重启后服务 active，回环管理 API 验证 `totalAccounts` 与账号列表总数同为 2，`totalDevices=11`，公网认证与 AI 路由仍为 JSON 401/400。

## 0.17. W14 实时监看开关与 iOS 相机桥接（官网已发布，真机待验收）

- 五端拍照页均使用显式“实时监看”开关。关闭会停止当前 USB/PTP、Wi-Fi/PTP-IP、本机相机或桥接帧循环，但保留连接与快门路径；打开后按原传输后端恢复实时取景。
- iOS / iPadOS 新增 `VendorSDKBridgeService`，仅允许 RFC1918、链路本地、`localhost` 与 `.local` 主机，使用 ephemeral `URLSession`、响应类型/大小校验、5/8 秒超时和 12 位本次配对码。主机与端口可保存，配对码不落盘。
- macOS 复用无线收件箱的 `8080` 端口，新增 `/sdk-bridge/status`、`live.jpg`、`capture` 与 `monitor`；既有 Basic Auth 之外还必须提供每次启动随机生成的 `X-Zenche-Bridge-Token`。关闭监看停止客户端拉帧，不会把相机断开。
- Sony 相机仅在 Mac 端 `SonyOfficialSDKService` 真正连接 Sony Camera Remote SDK 时返回 `officialSDK=true`；Nikon 返回 `nikon-ptp-compatible` 与 `officialSDK=false`。Sony 与 Nikon 当前公开的桌面 Remote SDK 均未提供可直接嵌入 iOS 的版本，iOS 没有加载桌面 Mach-O 运行时，Nikon 也不宣称官方 SDK 控制。
- 使用步骤、网络边界与故障排查见 `docs/LIVE_MONITOR_AND_IOS_CAMERA_BRIDGE.md`。当前静态编译与契约不等同于 Sony/Nikon 真机或长时间网络验收。

## 0.18. W15 登录动作清晰化与桌面工作区

- 登录故障按客户端提交前问题处理：2026-08-10 用户报告时间段内，生产 Nginx 专用访问日志没有 `/api/v1/auth/login` 请求，公网登录接口对无效凭据仍能稳定返回结构化 `401`。五端原界面同时使用“登录”表示模式与提交动作，选中的模式按钮点击不会发请求，容易被理解为提交无响应；模式标签因此统一改为“已有账号 / 创建账号”，提交按钮继续使用“登录 / 注册”，Apple 忙碌态保留动作文字与进度指示。
- macOS 使用 `DesktopWorkspaceLayout` 持久化主导航、拍摄参数栏、编辑媒体池、编辑工具栏和底部工具区尺寸；AppKit 主窗口用独立 autosave 名称恢复大小与位置，并在显示器拓扑变化时把窗口约束回可见工作区。分隔条支持拖拽与方向键微调，并提供辅助功能标签和值。
- Windows 使用 `%LOCALAPPDATA%/NikonLink/desktop-workspace-layout-v1.json` 保存窗口几何、最大化状态和同组面板尺寸；恢复时按虚拟桌面边界约束窗口。WPF `GridSplitter` 与设置页预设复用同一状态模型，响应式折叠仍优先保留中央预览。
- macOS `WorkspaceSplitHandle` 在 `DragGesture(minimumDistance: 0)` 的每次变化中关闭隐式动画并直接更新绑定值，窗口缩小时再按中央拍摄/编辑画面的最低尺寸动态收紧范围。Windows 六处 WPF `GridSplitter` 使用 `ShowsPreview=False`，拖动中实时重排；AI 工具列宽与其他面板一起写入同一布局状态。
- AI 空间按平台根因收敛：macOS AI 区只保留顶部五工具入口和自身生成底栏，不再重复完整调整分类与通用编辑底栏；Windows AI 模式使用等宽两列，预设按分类建立独立换行容器，并允许在 340–720 px 内调节 AI 工具列。
- 编辑层级统一为两级：一级“编辑模式”只包含“专业显影 / AI 工具”，二级“调整类别”只包含专业显影分类；从 AI 返回时恢复上次专业分类。macOS 把模式入口放入编辑器标题区，Windows 放入始终可见的标题工具区，避免同一目的地在上下两排重复出现。
- macOS 示波器由固定标签宽度的横排改为状态头 + 自适应曲线区，曲线填满分区；同一 SwiftUI pass 只生成一份最大边 2048 的预览图并供画面与示波器复用，保存/导出才请求完整尺寸。Windows 用 33 ms `DispatcherTimer` 合并参数滑动产生的高频预览请求，一次 1600 px 渲染同时供预览与 320 px 示波器采样；`WaveformScope.SetData` 对相同 RGB 数据不再重复 invalidation。
- Windows 监看时间码只在录制期间启动，停止录制、离开编辑页和关闭窗口时会停止计时并释放预览、AI 结果及示波器位图，避免隐藏页面继续占用 CPU/GDI 内存。
- 两个桌面端均提供默认、拍摄、监看、编辑、紧凑五套预设与恢复默认。第一阶段只支持主窗口内的固定分区调整，不实现 Adobe 式任意浮动面板、跨窗口拖放或跨显示器面板停靠；这些能力会显著扩大窗口生命周期、焦点、无障碍和状态迁移风险，留待后续独立迭代。
- Apple 的运行时本地化先匹配完整字符串，再做动态片段替换。登录忙碌态因此必须在共享的 `zh-Hans/en/ja` Apple 语言包中提供“正在登录…”与“正在注册…”的 exact key；回归测试会直接核对三语返回值，防止出现“正在Sign In…”或“正在ログイン…”混排。
- GitHub 发布版本为 `1.5.11 / build 38`，最终源码基线为 `831a82315c3586a8c8933c76ef6e8e3612bbcba5`。Windows AI 结果使用 `BitmapCacheOption.OnLoad` 解码后释放文件句柄；集中清理只接受系统临时目录下严格匹配 `zenche_ai_*.jpg` 的文件，并覆盖新结果替换、照片/模式切换、离开编辑页和窗口关闭，用户保存副本不会进入删除路径。完整 `npm test` 503/503 通过；macOS 全源类型检查、应用构建/严格验签以及 Windows WPF 编译、Release publish、NSIS、便携 ZIP 校验均通过。Windows 两包按最终源码基线重建；最终基线相对 `0faeccdc987146c104fd73d742547c9baf9db221` 只有 Windows 专属实现与测试变化，因此 macOS DMG 复用该提交已严格验签和校验的同字节产物。Android Debug、iOS unsigned、HarmonyOS unsigned、macOS ad-hoc 未公证、Windows 无 Authenticode 的平台边界保持不变。Impeccable 对本轮桌面布局文件检测为 0 条反模式；桌面阶段聚合包 SHA-256 为 `46515bba169afe3a495f1265dec9ab2a3ac409ecaf20d2466b041fe2144992e1`，14 项内容逐字节匹配当时交付源。AI审查 最终门禁 PASS（P0/P1/P2=0）；GPT5.6luna 确认三语、事实、去 AI 痕迹和交付内容无实体问题，其唯一状态 P2 已完成回填。该版本已公开到 GitHub，官网自动更新继续提供 `1.5.10 / build 37`。使用步骤与边界见 `docs/DESKTOP_WORKSPACE_LAYOUT.md`，交付状态见 `docs/releases/v1.5.11.md`。

## 0.19. W15 AI 代理迁移与移动端系统照片编辑流程

- 五端 AI 客户端默认基址统一为 `https://zenche.top/api`，再拼接 `/v1/ai`。升级时先去除空白与尾斜杠；仅当结果为空或等于历史默认 `http://101.34.255.115:8787` 时迁移到 HTTPS，其他显式自托管地址原样保留。只有 HTTPS endpoint 且本地存在有效 session 时附加 `Authorization: Bearer`；请求继续携带 `activationCode`、`deviceId`、`prompt`、`size`，修图再携带完整 MIME data URL。五端均兼容 `data[0].b64_json` 与下载 URL 结果；Android、iOS、HarmonyOS 及桌面端等待窗口统一覆盖代理轮询所需的 300 秒。
- Android 使用 Android 13+ Photo Picker，旧系统使用 `ACTION_OPEN_DOCUMENT`。导入必须经 `ContentResolver.openInputStream(uri)` 交给 `CaptureWorkflow.importFile`，不得构造 `File(uri)`；先读取 provider 声明的 `SIZE`，并以流式计数再次执行 64 MB 硬上限，避免未知或虚报大小绕过。`CaptureWorkflow` 先写同目录 `.importing` 临时文件，成功落盘后再重命名，流读取、同步、重命名或后续收尾异常都会清理临时文件和本次目标。编辑器的统一 `EditorBitmapDecoder` 解析 JPEG APP1/TIFF 的 Orientation 标签，并用 1–8 对应矩阵在采样解码后归一化旋转/镜像；缩略图、预览、分析、调整渲染和最终 JPEG 导出均复用该入口。导出使用 `MediaStore.Images` 新建项目，Android 10+ 通过 `RELATIVE_PATH=Pictures/ZENCHE` 和 `IS_PENDING` 原子公开，写入或 pending 发布失败均删除半成品。Android 9 及更早只在清单声明 legacy write 权限，并暴露应用设置恢复动作。
- iOS/iPadOS 以 PhotoKit `.readWrite` 状态区分 ready/limited/request/settings，允许 iCloud 下载后把 PHAsset 数据导入 `MediaLibrary` 私有副本。导出复用 `.addOnly` 授权和 `PHAssetCreationRequest.forAsset().addResource` 创建新资产；同时提供 `UIApplication.openSettingsURLString`，系统原 PHAsset 永不进入 change request。
- HarmonyOS 使用单选 `PhotoViewPicker`，把返回 URI 交给 `CaptureWorkflow.importFromUri` 生成文件库副本；导出使用 API 12 `showAssetsCreationDialog` 与 `PhotoCreationConfig`，让系统同意对话框承担写入授权与恢复。桌面端没有系统相册产品入口，本轮只同步 AI HTTPS 默认值和超时。
- 三个移动端都把“照片来源”放在专业显影与 AI 修图可见区域，空文件库时仍显示系统照片入口；专业调整与 AI 结果统一先写新的应用副本，再按用户操作创建新的系统相册项目。系统原片不进入覆盖/替换调用，AI 生图同样保存新副本。
- 自动化回归锁定五端默认/旧址迁移、HTTPS Bearer、data URL 上传、`b64_json` 解码、三种移动端“工作副本 + 新相册项目”边界，以及 Android、iOS/iPadOS、HarmonyOS 的动态 AI 状态 exact/参数化三语路径；运行时先翻译模板再插入文件名、预设名或服务端详情，避免二次翻译用户内容。最终移动端实现源码基线为 `5e7150d9217690e6aea56ea15d8fae852a2d825f`，完整 `npm test` 514/514。Android `assembleDebug`、iOS Release 无签名构建与 HarmonyOS Release HAP 构建通过，三包容器和侧车已回验。GitHub 发布聚合包 SHA-256 为 `2f90a8afb39dbe26c1537c4f642e09f76898627547693453d8829005c190d9e4`，14 项与当前交付源逐字节一致；真机权限、iCloud、厂商相册实现与网络代理真实生成仍分开记录。

## 0.20. Android Camera2 厂商会话降级

- `LocalCameraController` 只从 `SCALER_STREAM_CONFIGURATION_MAP` 选择 JPEG 输出，按常规双流、低负载双流、常规共享流、低负载共享流和最小共享流尝试。厂商 HAL 拒绝会话时关闭本次 `CameraDevice`/`ImageReader` 后重新打开，避免在失败设备上复用污染状态。
- 共享单 JPEG 流在静态拍照前停止 repeating、清空旧帧，并以 `onCaptureStarted` 的传感器时间戳标记目标 JPEG；完成或失败后恢复原 preview request。打开超时、迟到 `onOpened`、配置失败和 capture 同步异常走同一释放路径。
- 该降级不改变相机权限、文件保存、外录或 UI；自动化锁定候选顺序、尺寸来源、重开策略、共享表面和时间戳分流。OPPO PEDM00 / Android 14 仍需真实设备执行连接、监看、拍照、重复连接和前后台恢复。

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
- Nikon 机身可能在 JPEG 尚未完成写入时提前对 `DeviceReady` 返回成功。Android 对拍摄后的 `GetObject (0x1009)` `DeviceBusy (0x2009)` 使用最长 20 秒、最多 9 次的强制指数退避（300 ms 起步、4 秒封顶），每轮重新读取 `GetEvent` 并采用新的 SDRAM 对象句柄；恢复方法不包含 `CaptureToSdram`，因此不会为一次下载失败重复曝光。非繁忙 PTP 错误立即上抛，线程中断立即保留并退出。
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

### 5.1 PTP/IP 链路与连接监看（B2，v1.5.7）

- **链路**：五端（iOS/macOS/Android/Harmony/Windows）均以 PTP/IP（TCP 15740 默认端口）直连相机，复用各端既有 PTP 会话通道：iOS/macOS 由 Swift actor、Android 由 Java synchronized 实例锁保证心跳与事务命令严格串行；Harmony（ArkTS 顺序 await）与 Windows（C# 共享命令流）为共享单通道隐式串行——无显式 gate，与基线用户操作同模式，交错仅限 await 点且心跳失败无害（补显式 gate 已入 backlog）。握手为 PTP/IP 标准 Init Command Request/ACK（UUID + initiator 名 + 版本）与事件通道建立，随后以 GetDeviceInfo 确认会话。
- **心跳保活**：连接建立后每 5s 发送 GetDeviceInfo（0x1002）探测，单次超时 3s；连续 3 次失败判定离线（约 15–24s 无响应窗口）。
- **状态机**：`connecting → connected → reconnecting → connected/disconnected`；新增 `reconnecting` 态承载自动重连。iOS/macOS 为带 attempt 的枚举（`reconnecting(attempt:)`，对外以 `isReconnecting` 呈现）；Android/Harmony/Windows 为布尔 + 计数。
- **自动重连**：指数退避序列 1/2/4/8/16s，封顶 30s（`backoffDelay(forAttempt:)` / `wifiBackoffDelayMs` 等纯函数）；用户主动断开（`manualDisconnect` 标志）一律不触发自动重连。
- **网络层监听联动**：丢网即判离线，不等心跳超时——iOS/macOS `NWPathMonitor`（`path.status != .satisfied`）、Android `NetworkCallback`（TRANSPORT_WIFI onLost）、Harmony `NetConnection`（'netLost'）、Windows `NetworkChange.NetworkAvailabilityChanged`；监听到位后走同一退避重连流程，网络恢复即重连。
- **UI 呈现**：仅文本分支——`reconnecting` 态显示「重连中 / 正在重连 Wi‑Fi 相机…」并禁用连接按钮，橙色状态点；断连文案与既有样式语言一致，无新控件。

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
- 服务器地址由五端内置代理配置统一提供，默认 `https://zenche.top/api`；设置面板不再提供可编辑入口。为兼容升级，客户端仍读取历史保存的 `aiServerURL`、`ai_server_url` 或 `ai-server-url.txt` 值：历史默认 `http://101.34.255.115:8787` 自动迁移到 HTTPS，其他显式自托管地址继续保留。

## 7. 本地化、更新与诊断

- 五端必须提供简体中文、English、日本語并持久化选择。
- 动态状态、错误、任务进度和新 UI 文案都要走运行时本地化，不只翻译静态标题。
- 每个新版本同步五端更新公告，并按应用版本记录“不再提醒”。
- 更新检查优先 MirrorChyan，资源不可用、CDK 无效或无完整安装包时回退 GitHub Releases。
- 更新服务现在增加自有元数据入口：五端默认请求 `https://zenche.top/api/update`（可通过
  `ZENCHE_UPDATE_ENDPOINT` 覆盖），查询 `platform`、`arch`、`current_version` 和
  `channel=stable`。`server.mjs` 同时保留 `/api/updates` 兼容别名与 `/healthz`，返回
  `schema_version: 1`、`url`、`sha256`、`release_url`、`announcement`、
  `minimum_supported_version` 和 `update_available`。设置 `UPDATE_RELEASE_MANIFEST` 后，
  服务完全读取本地清单且不请求 GitHub；未设置时保留 GitHub Release 缓存/stale 模式。
  客户端校验 product/schema 后才使用结果，服务不可用仍按 MirrorChyan → GitHub 顺序回退。
  生产实例位于 `ubuntu@101.34.255.115`：`zenche-update.service` 监听 `127.0.0.1:4174`，
  Nginx 反代 API 并从 `/var/www/zenche.top/downloads/` 公网提供版本化资产；
  `UPDATE_ASSET_BASE_URL=https://zenche.top/downloads` 使清单 URL 指向官网。2026-08-10
  已将 1.5.10 / build 37 自托管清单切入生产，五端公网更新响应、兼容路由、1.5.10
  不重复提示与六个公开包 SHA-256 均通过；1.5.9 资产继续保留用于回滚。部署参数和反向代理要求见
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
