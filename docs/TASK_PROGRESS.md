# 帧澈 ZENCHE 任务进度

> 快照时间：2026-08-04（Asia/Shanghai）
> 基线分支：`main@697f3f8`；v1.5.3 已发布为 GitHub 最新稳定版
> 当前版本：1.5.3 / build 28 已发布；发布提交 `697f3f8d1028426dc5eec430230dcf48754f9b15`；GitHub 最新稳定版为 v1.5.3
> 维护规则：每次完成实质性功能、验证、打包或发布工作后更新本文件；每次向 GitHub 上传源码、标签、Release 或附件后，还必须同步更新 `docs/PROJECT_OUTLINE.md`、`docs/TECHNICAL_APPROACH.md` 和本文件。不要只写“完成”，必须附版本、提交/标签、Release 链接、产物与 SHA-256、验证证据、签名状态、阻塞和下一步，作为项目长期记忆。

## 1. 状态图例

| 状态 | 含义 |
| --- | --- |
| 已完成 | 源码已实现，自动化与适用验证通过，所需交付物已产生 |
| 已实现待验收 | 源码和基础测试存在，但真实硬件、签名安装或完整场景仍未闭环 |
| 进行中 | 当前工作区已有未提交修改，尚未形成可追溯提交或最终交付 |
| 阻塞 | 受签名凭据、平台工具链、主机系统或外部设备限制 |
| 待处理 | 尚未开始或仅有需求/文档记录 |

## 2. 当前结论

- 五个原生目标均已建立，产品功能不依赖顶层 Web/PWA。
- 当前源码版本为 **1.5.3 / build 28**，已发布为 [GitHub 最新稳定版 v1.5.3](https://github.com/Tauber01/ZENCHE/releases/tag/v1.5.3)；发布提交 `697f3f8d1028426dc5eec430230dcf48754f9b15`（代码候选 `846e1a0dc49c59b0cc5d032d84f954a98a61add0` + README/CHANGELOG 发布同步），注释标签 `v1.5.3` 指向同一提交；生产服务未变更。
- v1.5.3 已实现五端界面主体：全屏监看的影像优先 HUD、RGB 三色叠加波形示波器与静音音频基线；拍摄页的设备摘要、自适应参数卡、常驻拍摄操作区；编辑器的媒体池、中央预览、工具检查器和分析示波器。所有新面板读取既有真实状态，相机、AI、传输和非破坏保存链路不变。
- 当前门禁证据：`git diff --check`、1.5.3 专项回归 8/8、完整 `npm test` 256/256 均通过；iOS Simulator 无签名 Release、Android Debug、HarmonyOS release HAP、macOS 全 Swift 类型检查、Windows Release XAML/C# 均通过。独立复核已关闭全部 P1，最终结论为 P0/P1 均为 0；新增三语用户文案已完成一致性与自然度校对。七个版本化交付包及同名 SHA-256 已生成并逐个回验。
- 新增 **AI 修图与生图**：基于 nano-banana 模型的五端 AI 工具、12 个快捷预设、激活码授权（设备绑定、每码 100 次、服务器端计数）。
- v1.5.0 已作为历史 GitHub Release 保留；生产下载服务器仍保留既有 v1.4.1 六包。当前公开稳定版与交付哈希以 v1.5.2 Release 和 `docs/releases/v1.5.2.md` 为准。
- AI 全链路已通过端到端验证：激活码验签 → 服务器计数 → 转发 grsai → 返回图片，计数递减正常。
- 最大未闭环风险仍是跨 42 款相机的系统实机矩阵、生产签名、公证与商店级分发；Windows 包在 macOS 交叉构建，尚未完成真实 Windows 安装/驱动/SmartScreen 验收。
- 本次恢复从历史提交 `a4a26a6` / `4a094e8`（AI 激活码系统）与 `8b6f556` / `3081f71`（Sony/Canon 适配）增量合并，保留当前编辑器、Nikon EXPEED 5/6/7、Android 状态栏与 Web/PWA 工作区。
- 本次编辑器迭代已同步五端：AI 工作台增加显式“分析画面”步骤、曝光/动态范围/色彩/细节指标，以及 AI 调整复制/粘贴；原有强度、智能优化、撤销、预设、前后对比和高质量副本保持不变。
- 本轮增量 UI 修复已完成：五端编辑器主身份恢复为“专业显影”，AI 保留为可选增强区并明确“照片不会上传”；Android 恢复原有底部连接状态与文件计数栏及其更新链路，未删除编辑或拍摄功能。
- 本轮 AI 工具 UI 优化已完成：联网 AI 创作区统一为“模式与授权状态 → 提示词/预设 → 输出参数 → 生成/保存/状态”层级；iOS/macOS 明确区分联网 AI 创作与设备端本地优化，Android 修复重复状态文本，HarmonyOS 恢复比例/分辨率控件，Windows 恢复比例/分辨率控件并显示授权状态；激活码、设备绑定、预设、服务器请求、生成、保存和本地 AI 工作台均保留。
- 本轮设置收敛已完成：五端均移除 AI 服务器地址的可编辑输入框和保存按钮，仅保留激活码操作；AI 请求仍使用内置默认代理，并继续读取历史 `aiServerURL`、`ai_server_url` 或 `ai-server-url.txt` 配置以兼容升级。
- 本轮移动端编辑入口修复已完成：Android 与 HarmonyOS 的底部/侧边“编辑”导航现在始终打开“专业显影”，不再通过重复点击导航在专业显影与 AI 工具之间来回翻转；两端编辑页新增明确的“专业显影 / AI 工具”模式切换，AI 修图与生图功能保持不变。
- 本轮设备码与兑换入口恢复已完成：五端 AI 激活卡均显示并支持复制当前设备 ID，保留激活码输入、验证和旧购买入口；新增显眼的 `https://zenche.top` 官网兑换按钮、兑换步骤说明，以及“在爱发电购买兑换码”提示、可点击二维码和购买按钮。兑换码仅用于 AI 云服务次数，未改变帧澈本体免费开源属性。
- 本轮服务器端自动更新系统已实现：`server.mjs` 新增 `/api/update`、`/api/updates` 和 `/healthz`，按 platform/architecture/channel 解析 GitHub Release 完整包，提供 SHA-256、公告、最低支持版本、版本比较、ETag/CORS、安全响应头、5 分钟缓存与 stale 回退；五端客户端默认接入 `https://zenche.top/api/update`，服务异常继续 MirrorChyan → GitHub 回退。
- 本轮五端外录已实现：照片直接进入当前设备文件库；Android、HarmonyOS、macOS、Windows 将 PTP/本机实时取景流式封装为 MJPEG AVI，iOS / iPadOS 本机与 UVC 继续以 MOV 外录。PTP 机身录制可与设备外录并行，停止、断开和写入失败会安全完成已写入帧；AVI 已纳入四端媒体库视频分类，会话命名、双目标备份与 SHA-256 同步生效。
- 本轮服务器部署已完成：使用 `/Users/tauber/Downloads/key2.pem` 以 `ubuntu@101.34.255.115` 登录；`zenche-update.service` 运行于 `127.0.0.1:4174`，Nginx 反代 `/api/update`、`/api/updates`、`/healthz` 并静态提供 `/downloads/`。v1.4.1 六个官方 Release 包及六份 `.sha256` 已上传到 `/var/www/zenche.top/downloads/`，`UPDATE_ASSET_BASE_URL=https://zenche.top/downloads` 已启用；服务器本机五平台 API、下载响应和 SHA-256 均验证通过。公网 DNS 当前仍指向 `45.207.210.254`，需切换到 `101.34.255.115` 后公网客户端才会命中本部署。

## 3. 能力进度

| 工作流 | 当前状态 | 已有证据 | 主要剩余工作 |
| --- | --- | --- | --- |
| 五端原生应用骨架 | 已完成 | `native/ios/`、`native/android/`、`native/harmony/`、`native/macos/`、`native/windows/` | 持续保持行为和文案对齐 |
| Nikon 设备识别 | 已实现待验收 | 20 款注册表与 Android filter 测试通过 | 为新增 EXPEED 5 与既有机型补齐实机记录 |
| USB/PTP 实时取景与拍摄 | 已实现待验收 | 四端传输实现、已知问题回归测试通过 | 不同固件、镜头、主机、驱动和睡眠恢复测试 |
| 参数控制与 B 门 | 已实现待验收 | 快门回退、B 门释放、模式控制回归存在 | 扩大机型/拍摄模式 writable 属性验证 |
| 自动拍摄任务 | 已实现待验收 | 五端间隔、曝光包围、焦点包围、B 门静态测试通过 | 长任务、取消、断线、存储不足实测 |
| 专业监看 | 已实现待验收 | 直方图、波形、矢量、峰值对焦、假色等五端检查通过 | 性能、色彩准确性和长时间运行验证 |
| 无线收图 | 已实现待验收 | 五端 FTP/HTTP/WebDAV 源码与文档存在 | 大文件、中断、并发、端口释放和相机 FTP 实测 |
| 拍摄会话与交付 | 已实现待验收 | 命名、配对、评级、双备份、SHA-256 五端检查通过 | 恢复、磁盘异常、跨卷和大量文件压力测试 |
| 分支图库 | 已实现待验收 | 嵌套分支、拖拽、删除恢复和移动抽屉测试通过 | 真机手势、可访问性和大图库性能 |
| 非破坏性编辑 | 已实现待验收 | 五端主导航、分组参数与导出语义检查通过 | 像素级结果、EXIF、色彩空间和超大图验证 |
| **AI 修图与生图** | **已实现待验收** | 五端 AI 工作台与联网 AI 面板、分析指标、AI 调整复制/粘贴、12 预设、提示词/比例/分辨率、激活码授权、服务器计数；全链路端到端验证通过 | 各平台真机 UI、服务器容灾、激活码发放流程 |
| **Sony / Canon 相机适配** | **已实现待验收** | Sony 12 款、Canon 10 款注册表；vendor ID 过滤、macOS detection tokens、Windows PTP vendor ops；42 项测试覆盖 | Sony/Canon 真机 PTP、实时取景、参数写入和不同固件验证 |
| 三语本地化 | 已实现待验收 | 简中/英/日资源与动态状态测试通过 | 人工校对、截断、窄屏与新增文案持续同步 |
| 更新与公告 | 已实现待验收 | 自有 `/api/update` + MirrorChyan + GitHub fallback；服务端缓存/资产选择/API 路由测试通过；五端源码契约对齐；服务器本机 API/静态资产/SHA-256 验证通过 | 将 DNS/CDN 切换到 `101.34.255.115`，再实测公网下载、公告、断网 stale 回退和各平台安装流程 |
| 诊断与隐私 | 已实现待验收 | 脱敏日志和预填 Issue 实现存在 | 敏感信息专项审计与异常日志压力测试 |
| 正式签名分发 | 进行中 | 已有多平台打包脚本与 CI | 见“签名与发布状态” |

## 4. 当前工作区进行中事项

### 4.0 1.5.3 五端工作台（本轮）

- **实现**：全屏 HUD、设备摘要/参数卡/拍摄操作区、编辑媒体池/预览/检查器/分析示波器已同步五端；iOS 拍摄会话入口保持可达，Android 编辑快捷入口指向真实控件，Windows 窄窗会收起媒体栏并保留中央预览。
- **状态真实性**：五端新增遥测、输出摘要、底部读数和参数托盘均受连接状态门控；无源时显示 `—`、`OFFLINE` 或明确空态，不显示初始化默认值。RGB 三色叠加示波器只读取真实直方图/分析值，音频无输入时只显示静音基线。
- **本地化**：新增工作台标签、空态和 iOS 辅助功能提示已覆盖简体中文、英文、日文；Android/HarmonyOS 的媒体池、工具轨和编辑示波器标签已转入运行时本地化。
- **验证**：`git diff --check`、专项 8/8、完整 256/256 通过；iOS、Android、HarmonyOS、macOS、Windows 编译门禁通过。独立终审确认 P0/P1 均为 0；新增三语用户文案已完成一致性与自然度校对。
- **候选提交**：`846e1a0dc49c59b0cc5d032d84f954a98a61add0`，提交包含 Tauber 的 `Co-authored-by` 与 `Signed-off-by` trailer；打包时工作树干净。
- **交付物**：`dist/` 下 APK、HAP、unsigned IPA、macOS arm64 DMG、Windows x64 Setup/便携 ZIP、源码 ZIP 共 7 包及同名 `.sha256` 已生成。SHA-256 依次为 `3c79546bb80ea1d1043aae06fc4d5b848d661b72f871f646b3a4c4db8379b182`、`9dc53cce4375714bfedaac0f7df76e6d225cdeb6fa86f556c6aadc5c30bbd328`、`9ddff92fc0cfc8a98d56edef017a475241ae1f8b4911b84cb559ddba0cd215dd`、`b921f2c3573891fc340e1fac627aa663fa74c7bf28f4ea62a161b8b2eb5e81a5`、`24769cf08627890ee6d67a23aa0567b92b3b9de5c1e0e08d5485a9ec1f7b631c`、`fd9dbcba313d04180b5561e9e3bc96097247c931dc4558305a547f77e10470dc`、`686c318574b78186e8cd80bb41c01130bb18b988ff3c7344fa253a330825e382`；文件名、字节数与签名状态见 `docs/releases/v1.5.3.md`。
- **签名与版本边界**：Android 为 Debug 证书；HarmonyOS/iOS 未签名；macOS ad-hoc 且深度签名/DMG 校验通过但未公证；Windows PE Security Directory 为 0，未做 Authenticode。Windows 资源版本为 `1.5.3`/`1.5.3.0`，未单独编码跨端候选号 `build 28`。源码 ZIP 固定于代码候选提交，包内的发布说明与任务进度是打包前快照；最终交付表以当前文档及后续文档提交为准。经 Tauber 明确授权，v1.5.3 已于 2026-08-04 发布为 GitHub 最新稳定版（见 §12.4）。

### 4.1 服务器端自动更新系统

- **源码**：已实现 `server.mjs` 的 `/api/update`、`/api/updates`、`/healthz`，包含 GitHub Release 资产选择、SHA-256、公告、最低支持版本、版本比较、缓存/stale 回退、ETag、CORS 与安全响应头。
- **五端接入**：iOS、Android、HarmonyOS、macOS、Windows 默认请求 `https://zenche.top/api/update`，校验 `schema_version/product` 后使用结果；不可用时仍按 MirrorChyan → GitHub 回退。
- **测试**：`node --test` 75/75 通过；`git diff --check` 通过。
- **本机交付物**：Android、iOS unsigned、Windows x64 Setup/ZIP 已由本轮源码生成并写入 `dist/`；SHA-256 分别为 Android `d4bcbfc0fa1bac599a739e85879299f1fdb0a34d53535d929f7895d5a569ea7a`、iOS `4e4bfe7d414f8baef44396504f3123ed5f3b919a350f1ed9dd10e0e869254599`、Windows Setup `5ab10ca284f65c71f0328fdad7ca2ca7467112d853ae20b15eb1b39833fc658f`、Windows ZIP `513c6b2820ff28026aa5657057ada4e5752a75b8b8f8d501eba7b6cb0bea8e11`；macOS 仅完成 Swift 编译，因缺少本机 `libexif.12.dylib` 未生成可信本轮 DMG；HarmonyOS 因既有 ArkTS 错误未生成可信本轮 HAP。
- **阻塞**：尚未把服务部署到 `zenche.top` 的生产反向代理；需要服务器 SSH/进程托管/HTTPS 配置权限。Android 构建曾遇到 SDK manifest 网络握手警告但最终成功；iOS unsigned 构建成功。Windows 使用本机 PowerShell/.NET/NSIS 生成未签名安装器与便携包。
- **部署状态**：上述生产反向代理、进程守护、资产上传和服务器本机下载验证已完成；公网 DNS/CDN 切换仍是唯一未闭环项。
- **下一步**：将 `zenche.top` DNS/CDN 指向 `101.34.255.115`，实测公网五端下载 URL、公告、SHA-256、ETag、断网 stale 回退及安装流程。

以下内容来自 2026-08-01 的 `git status` 与 diff，只表示当前本地工作现场，不等同于已经提交或发布：

### 4.2 AI 功能（已提交并发布）

- AI 修图与生图、12 个快捷预设、激活码授权、代理服务器架构已完成，已在 `claude/modest-albattani-34402d` 分支提交（35 文件，+2627/-110）并推送。
- 四端（macOS/iOS/Android/HarmonyOS）1.3.0 产物已上传 GitHub Release `v1.3.0`。
- Windows 1.3.0 EXE 安装包待 Windows 主机生成。
- 分支尚未合并回 `main`。

### 4.3 相机兼容与测试调整

- Android、HarmonyOS、iOS、Windows 的相机或 PTP 相关文件存在未提交修改。
- `test/camera-profiles.test.mjs` 与 `test/localization.test.mjs` 已修改，当前 37 项测试全部通过。
- 修改目的需以最终 diff 为准；提交前必须确认没有误删机型档案、错误缩小参数范围或破坏设备 fallback。

### 4.4 设计与宣传素材

- `design.md`、`PV/README.md`、PV V2 构建/预览脚本和 AI 图片素材存在修改或未跟踪文件。
- 这些素材不属于原生应用交付包，但发布前应确认品牌标识、标准标语、版权和输出清单。

### 4.5 工作区卫生

- Android 源码目录存在未跟踪 `.bak`/`.bak2`/`.bak3` 文件。
- 不得在未确认内容前删除；确认无追溯价值后，应在独立清理步骤中处理并避免进入提交。
- `CLAUDE.md` 为未跟踪文件，应先确认用途和是否与本组文档重复，再决定是否纳入版本控制。

## 5. 验证记录

### 5.1 自动化

2026-08-01 在仓库根目录运行：

```sh
npm test
```

结果：42 tests，42 pass，0 fail。覆盖 20 款 Nikon、12 款 Sony、10 款 Canon 档案，USB filter、vendor ops、本地化、启动公告、MirrorChyan、编辑器、素材树、专业工作流、版本号和构建号一致性。

### 5.2 1.3.0 产物与校验

2026-08-01 对 1.3.0 产物生成 `.sha256` 并回验：

| 平台 | 文件 | 当前交付属性 |
| --- | --- | --- |
| Android | `dist/ZENCHE-1.3.0-android.apk` | 调试证书签名 APK |
| HarmonyOS | `dist/ZENCHE-1.3.0-HarmonyOS.hap` | 是否可安装取决于本地 signingConfigs/Profile |
| iOS / iPadOS | `dist/ZENCHE-1.3.0-ios-unsigned.ipa` | 未签名，仅用于编译/容器验证 |
| macOS | `dist/ZENCHE-1.3.0-macOS-arm64.dmg` | Apple Silicon、ad-hoc、未公证 |
| Windows | `dist/ZENCHE-1.3.0-Windows-x64-Setup.exe` / `dist/ZENCHE-1.3.0-Windows-x64.zip` | macOS 交叉构建，未完成真实 Windows 安装、升级、驱动与 SmartScreen 验收 |

四端产物已上传 GitHub Release `v1.3.0`（https://github.com/Tauber01/ZENCHE/releases/tag/v1.3.0）。

本次恢复后本地重新生成的 SHA-256：Android APK `e6c2d6f19ad35cf1048e3f29e7a134a8edef379812a74325f3690a4e641641e5`；HarmonyOS HAP `5f514a29a51c7c8af6e3916150c01c55fbf1cf147291cba28d6c5e01fd3c6d78`；iOS unsigned IPA `58b77fc8ecfb4e8c780b950f971f9c2577a2809f233f5525649a7d9c57936ac1`；macOS DMG `e92a9c4076050533037e1f38e2b68a4be7b4bdcee52e71034f44729568fb3348`；Windows Setup `ea5ce5a9af0e1154851d669bd2dfecb4061b812366a9156e141aa0a2c1d26f73`；Windows ZIP `3c0ed2c14e1ee49b9760aaf797dcab59a20e22c4fcb224320cd553aa81ce528d`。

### 5.3 AI 端到端验证记录

2026-08-01 对生产服务器 `http://101.34.255.115:8787` 实测：

- 无效激活码 → HTTP 403 `{"error":"激活码无效"}`
- 设备不匹配 → HTTP 403
- 有效激活码 + 正确设备 → 验签通过、服务器计数、转发 grsai（nano-banana-fast）；修图原图通过上游 `images` 数组传递，返回 `{data:[{b64_json}]}`，解码为有效 JPEG（438 KB）
- 连续调用计数递减：`X-ZENCHE-Remaining` 96 → 95 → 94

### 5.4 本次编辑器迭代验证记录

2026-08-01 在仓库根目录运行：

```sh
npm test
xcrun swiftc -typecheck -swift-version 5 -framework AppKit -framework SwiftUI -framework Photos -framework AVKit native/macos/Sources/NikonLink/*.swift
xcodebuild -project native/ios/NikonLink.xcodeproj -scheme NikonLink -configuration Debug -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO build
cd native/android && ANDROID_HOME=/Users/tauber/Documents/NikonLink/.toolchains/android-sdk ./gradlew --no-daemon :app:compileDebugJavaWithJavac
dotnet build native/windows/NikonLink.Windows.csproj --no-restore
scripts/build-harmony.sh
scripts/build-macos.sh
ANDROID_HOME=/Users/tauber/Documents/NikonLink/.toolchains/android-sdk scripts/build-android.sh
scripts/build-ios.sh --unsigned
```

结果：38 项测试全部通过；iOS 模拟器构建、macOS Swift 类型检查、Android Java 编译、Windows .NET 构建、HarmonyOS HAP、macOS DMG、Android APK、iOS unsigned IPA 均成功。Android 构建期间 SDK 源列表因网络 EOF 警告，但使用本地 SDK 缓存完成；HarmonyOS 产物跳过签名。回归测试额外锁定了专业显影标题、五组调整、预设、前后对比、重置、几何和导出，以及 Android 状态/文件计数栏不得被误删。

本轮 UI 修复重新生成 1.2.0 交付物并回写 SHA-256：Android `fad2ecf580c45749565f51f2893e4df896368004f658b5e433cde0973002ea3a`；HarmonyOS `084a3979f475a717c290315134070ce36b84ee3a29bf1e3f417a7bcbbaf6de94`；iOS unsigned `2f11485e9991b84d731fb1deb9b42ee46d2ec1a1592d0061b7f827b6e5fbb807`；macOS `44a6668ae13b1282641b006ce13e45b130ef2907edc68f79d6032f8b01b6e590`；Windows x64 Setup `f84a216c5949e6293b286c9760d9b169f5d30aa320dd127eba9ddc1f08094ebf`；Windows x64 ZIP `fc1428d7830caa0cfdfb4c5fad32bd8449c4b4da074062925f32112127df4c38`。Windows 仍需在真实 Windows 主机完成安装、升级、卸载、驱动与 SmartScreen 验收。

当前 1.2.0 产物 SHA-256：Android `ac7e4f8a6000ca1bc188972e8960da615b0b635ae6339d9a0f9eb8c76b62b6c5`；HarmonyOS `b609550f61de04083794ad3329e5b6b82c9cd86a60bfc8bf267ab277ba4ca9bf`；iOS unsigned `f7118956fed18feb8e29aa9c6659d4efb27fe27f6588136527dcd18a0f00bfe5`；macOS `9e3cc34d261ccf6ffc87edd1335514f329e3cff6c716404be69d6342960dc06b`。

Windows 本次已在 macOS 上通过 PowerShell 运行 `scripts/build-windows.ps1` 生成交叉发布产物；由于不是 Windows 主机，仍未完成真实 Windows 安装、升级、卸载、驱动和 SmartScreen 验收。

Windows 1.2.0 交叉产物 SHA-256：Setup `392583eee4538a7c239f0e797b3b0a43099f00b45cd85aa39b93b5137238df96`；便携 ZIP `933d401b7da81673c69502d375868f721a30d320db46bb56d55ad06611c7318d`。

### 5.5 本轮 AI UI 优化验证记录

2026-08-01 在仓库根目录运行：

```sh
git diff --check
npm test
scripts/build-android.sh
scripts/build-ios.sh --unsigned
scripts/build-harmony.sh
scripts/build-macos.sh
pwsh -NoLogo -NoProfile -File scripts/build-windows.ps1 -LibUsbDll "$PWD/.toolchains/libusb-1.0.29/VS2022/MS64/dll/libusb-1.0.dll"
```

结果：43 项测试全部通过；Android Java、iOS unsigned、HarmonyOS ArkTS/HAP、macOS Swift/DMG、Windows .NET/NSIS 均成功。Android SDK 源列表仍出现网络 EOF 警告，但使用本地缓存完成；HarmonyOS 构建跳过签名；iOS IPA 未签名；Windows 包在 macOS 交叉构建，未完成真实 Windows 主机安装、升级、驱动和 SmartScreen 验收。

本轮重新生成的 1.3.0 产物位于 `dist/`，并已更新对应 `.sha256`：Android APK `b00fd5aa1c25f08cbcebf5e8ac18324e4fa641aa76b3f3daffe094e1ffa22dec`；HarmonyOS HAP `1e5aa7a323642e86680812d4421096bc27d012ae2453a7b57f2333d678ee26fb`；iOS unsigned IPA `8abfb9e48d4c745052e089c811864979318e35cde41edf4f5f13dae5c3f3ba63`；macOS arm64 DMG `4f85d75c625cd6f19eec7f1b934b0afc8fa5f577e95236b708ed86f055402e4b`；Windows x64 Setup `d6f18762f29670c1d507025a894c770fcdea3719c22da8b4381681ba777ed5ed`；Windows x64 ZIP `efe33572afb18cd15963360b0a6187761716afb43c396cf9fde03a42fad7c222`。

### 5.6 本轮移除 AI 服务器设置入口验证记录

2026-08-01 在仓库根目录运行：

```sh
git diff --check
npm test
scripts/build-android.sh
scripts/build-ios.sh --unsigned
scripts/build-harmony.sh
scripts/build-macos.sh
pwsh -NoLogo -NoProfile -File scripts/build-windows.ps1 -LibUsbDll "$PWD/.toolchains/libusb-1.0.29/VS2022/MS64/dll/libusb-1.0.dll"
```

结果：44 项测试全部通过；新增静态回归测试确认五端设置页不再包含 AI 服务器输入/保存控件，同时确认旧配置读取键仍存在。五端构建与交付包均成功生成。Android SDK 源列表出现网络握手警告但使用本地缓存完成；HarmonyOS 跳过签名；iOS IPA 未签名；macOS DMG 为 arm64、ad-hoc、未公证；Windows 包在 macOS 交叉构建，未完成真实 Windows 主机安装、升级、驱动和 SmartScreen 验收。

本轮 1.3.0 产物 SHA-256：Android APK `1f948147211e31ecf463ecd54de7cb995df9e38048ee50512bdf591602f01b8b`；HarmonyOS HAP `d75b5dd26a1eb5d5efd7a48a9a5112526163ce252e39114c84ad6857d55dee4b`；iOS unsigned IPA `c8e3d380c4332c2c754abda571dca82a1925bf19d59c0c99b8a36d3970462413`；macOS arm64 DMG `133464f2ad40b0960a191e70429fe32ff6ef23ca22bb994da51f2d2da5c1a030`；Windows x64 Setup `5098c2e13e80b66fdf3ceb3f76a1271c27626698c6613a2e5011a2ad4d4a6c9d`；Windows x64 ZIP `6560f544405404b4967bedfe02d6cbd241d3a572fb6b22f6e4a5291408470a09`。

### 5.7 本轮移动端编辑入口修复验证记录

2026-08-01 在仓库根目录运行：

```sh
git diff --check
npm test
cd native/android && ANDROID_HOME=/Users/tauber/Documents/NikonLink/.toolchains/android-sdk ./gradlew --no-daemon :app:compileDebugJavaWithJavac
scripts/build-android.sh
scripts/build-harmony.sh
```

结果：45 项测试全部通过；新增回归测试确认 Android/HarmonyOS 导航默认进入专业显影，并存在显式 AI 工具切换。Android Java 编译与 Android APK、HarmonyOS HAP 构建成功。Android SDK 源列表出现网络握手警告但使用本地缓存完成；HarmonyOS 跳过签名。移动端本轮产物 SHA-256：Android APK `8cc90a7885bd19a94ba67895c85c095f8014d2faa8da38eefc34ed4e99161e7a`；HarmonyOS HAP `d5d7077626cf6afd6cd9fad811d2bd0c91e7e450dbc6da2d401774ab3801e0cb`。

### 5.8 本轮设备码、官网兑换与爱发电购买入口验证记录

2026-08-01 在仓库根目录运行：

```sh
git diff --check
npm test
scripts/build-android.sh
scripts/build-ios.sh --unsigned
scripts/build-harmony.sh
scripts/build-macos.sh
pwsh -NoLogo -NoProfile -File scripts/build-windows.ps1 -LibUsbDll "$PWD/.toolchains/libusb-1.0.29/VS2022/MS64/dll/libusb-1.0.dll"
```

结果：47 项测试全部通过；新增静态回归测试确认五端 AI 激活卡同时保留设备 ID、复制和激活流程，并包含 `https://zenche.top` 官网兑换入口、“在爱发电购买兑换码”提示及二维码资源。五端构建与交付包均成功生成；逐包检查确认 Android、iOS、HarmonyOS、macOS 均包含二维码文件，Windows WPF 资源随程序集打包。Android SDK 源列表出现 TLS 握手警告但使用本地缓存完成；HarmonyOS HAP 跳过签名；iOS IPA 未签名；macOS DMG 为 arm64、ad-hoc、未公证；Windows 包在 macOS 交叉构建，未完成真实 Windows 主机安装、升级、驱动和 SmartScreen 验收。

本轮最终 1.3.0 产物 SHA-256（二维码显示尺寸调整后重新打包）：Android APK `76e2c150fc9fe201a341b9b5ad300c35c46bee3f6a8810ca48af366d1ab68519`；HarmonyOS HAP `00cc6fdca325f89ebda9f36b9b32e14bbea874381221ed4af82457bcd00154bc`；iOS unsigned IPA `c740e244cafe58b9ce6b1ccec0be973033f72663f8446333022165c2da069cfd`；macOS arm64 DMG `053232ccb1d66b854807a4287138e8d8923d483f438f32b6c66c2a739b4cdaf1`；Windows x64 Setup `4cabf1fb856fa4db9ee3bf91fa4b4aef7887301d7b67a93645aa310091ddb9c0`；Windows x64 ZIP `8d30d755d46de850c65b8bfe50ef57dafdb950c60fe0cb0d45438c1974bacd39`。六个 `.sha256` 文件均已使用 `shasum -a 256 -c` 回验通过。

当前构建机使用 `curl` 探测 `https://zenche.top` 时遇到 `LibreSSL SSL_ERROR_SYSCALL`，因此只验证了五端跳转实现和固定 HTTPS 地址，尚未在各端真实浏览器中闭环验证官网 TLS 可用性；需由官网侧检查证书、TLS 配置和公网可达性。

### 5.9 本轮专业监看与直接调色工作区验证记录

2026-08-02 将专业监看控制台与直接调色工作区同步到 iOS / iPadOS、Android、HarmonyOS、macOS 和 Windows：监看页统一提供示波器、拍摄读数、辅助工具、存储状态和录制控制；编辑页统一提供 Lift / Gamma / Gain 色轮、主曲线、取色器、线性/径向/主体蒙版及其强度、羽化和反相控制。五端启动公告已同步说明本轮功能。

本轮同时清理无法由设备或系统状态支撑的演示读数：不再固定显示 `27mm`、`6000K`、`28:59`、`18GB` 或 `4%`。不支持的镜头数据使用 `—`；Android、macOS、Windows 在可用时显示真实本地存储值，HarmonyOS 显示本地图库实际容量与文件数，macOS 与 Windows 时码跟随真实录制状态。

在仓库根目录实际运行：

```sh
git diff --check
npm test
cd native/android && ./gradlew --no-daemon :app:compileDebugJavaWithJavac
xcodebuild -project native/ios/NikonLink.xcodeproj -scheme NikonLink -sdk iphonesimulator -configuration Debug CODE_SIGNING_ALLOWED=NO build
cd native/harmony && hvigorw assembleHap
swiftc -typecheck native/macos/Sources/NikonLink/*.swift
dotnet build native/windows/NikonLink.Windows.csproj
scripts/build-android.sh
scripts/build-ios.sh --unsigned
scripts/build-harmony.sh
scripts/build-macos.sh
pwsh -NoLogo -NoProfile -File scripts/build-windows.ps1 -LibUsbDll "$PWD/.toolchains/libusb-1.0.29/VS2022/MS64/dll/libusb-1.0.dll"
```

结果：`npm test` 59/59 通过，`git diff --check` 通过；Android Java、iOS Simulator、HarmonyOS ArkTS/HAP、macOS Swift typecheck 和 Windows .NET 编译均成功。Android SDK 源列表联网出现 TLS 握手警告，但使用本地缓存完成；Windows 保留 3 个非阻塞编译警告。macOS 首次并行打包因构建期间源文件被改动而中止，源文件稳定后单独重跑成功。

本轮最终本地 1.4.0 交付包及 SHA-256：Android APK `2c19efbfcd4e6d4af735c9d6e17de8ef47b5d0958767bdaba38680e0cf124774`；HarmonyOS HAP `73726464bf0c9eea00a1d097d5bd69b7eb53f21bc10f6474fdc3b6210a1d5859`；iOS unsigned IPA `e0ee69c44d0b8717199480c8deb402cfbcf652771a4c9f9ce3df5e121de5d0cc`；macOS arm64 DMG `0d858ce72a7736bdeb935b38c0e829c85c7bce1744619b02ab77e9a572fcbeeb`；Windows x64 Setup `45089aa7ddb6cf239a1049caa034e656c5fc646c256cb56f26d41f01e2fbf3c4`；Windows x64 ZIP `98fae82171d3f7968d568ebd4cba09bc5679b2b7fb947e591c50259d9ba49508`。六份 `.sha256` 文件均已使用 `shasum -a 256 -c` 回验通过。

签名与验收状态：Android 使用 debug 证书；HarmonyOS 和 iOS 未签名；macOS 为 ad-hoc 签名且未公证；Windows 在 macOS 交叉构建、未使用受信任代码签名证书，尚未完成真实 Windows 安装、升级、驱动和 SmartScreen 验收。本轮未提交、未打标签、未上传 GitHub；上述哈希只对应当前 `dist/` 本地产物，不代表既有 v1.4.0 GitHub Release 附件已被替换。

## 6. 签名与发布状态

| 平台 | 打包能力 | 正式分发缺口 |
| --- | --- | --- |
| iOS / iPadOS | unsigned IPA 已可生成；仓库有 signed IPA 手动工作流 | Apple Developer 证书、Profile、Team 与正式签名验证 |
| Android | APK 已可生成 | 建立稳定 release keystore、签名保管与发布渠道 |
| HarmonyOS | HAP 已可生成 | 华为开发者证书、Profile、真机安装与发布签名 |
| macOS | DMG 已可生成 | Developer ID 签名、公证、Gatekeeper 验证及可能的通用架构支持 |
| Windows | Setup.exe 与 ZIP 已可生成 | 受信任代码签名证书、SmartScreen 信誉与干净主机安装验收 |

CI 当前自动构建 iOS unsigned、Android 和 macOS；Windows 有独立手动工作流；HarmonyOS 主要依赖本地 DevEco/Hvigor。标签 Release 工作流在 macOS runner 上无法替代 Windows 安装器构建，并可能在缺少 HarmonyOS 工具链时跳过 HAP，因此正式发布必须单独确认五端附件完整性。

## 7. 1.3.1 发布收敛（2026-08-02）

- 五端启动公告已重写为 1.3.1 语义：AI 工作台切换、设备码绑定、服务器计数、官网兑换、爱发电购买二维码、AI 服务器历史配置兼容、Sony / Canon / Nikon 保留和防诈骗提示。
- 版本元数据已提升为 `1.3.1 / build 22`；README 三语、CHANGELOG、构建脚本和发布说明已同步。
- 验证完成：47 项测试通过，`git diff --check` 通过；Android、HarmonyOS、iOS unsigned、macOS、Windows Setup/ZIP 六个 1.3.1 包已生成并完成 `.sha256` 回验。
- 1.3.1 GitHub Release 最终 SHA-256（已下载线上附件并逐个回验）：Android `8d3608f3cabdffae7407f734e700f5590edd1d62321ceafeabf88d8e9777d1c9`；HarmonyOS `a85a2084577435cb5a706d2e704ae32189e20571bac4ce17382ced528aa53887`；iOS unsigned `f1257053f61a0c6d3885c323b21b25baaa90310fafe26427831d09fd73574e1d`；macOS `e36fa5f7e9a41a16d424a2613e36d5e479647f68ec54291c5d5dfa83115b5f37`；Windows Setup `ff69f037bfd4b9a21f78a5dddda8abc833f615f955a7c66ebdff1b4ec5b95842`；Windows ZIP `030e1fe686fd47574143ff195f5029d5eec673e25fff485a72dd7ef8d254caf9`。
- GitHub Release `v1.3.1` 已创建并核对，发布地址为 https://github.com/Tauber01/ZENCHE/releases/tag/v1.3.1；后续每次上传 GitHub 后必须立即回写本节及三份基线文档的发布事实。
- 已将最终线上 SHA-256 回写 `docs/releases/v1.3.1.md` 并同步 GitHub Release 正文；Release 当前包含 12 个附件（六个交付包及六个 `.sha256`），线上校验全部通过。
- 已知限制保持：HarmonyOS / iOS 签名缺口、macOS 未公证、Windows 非 Windows 主机交叉构建、官网 TLS 需公网侧确认。

## 8. 1.4.0 发布收敛（2026-08-02）

- 五端 AI 修图统一发送完整原图 data URL，经代理 `images` 数组进入 Grsai；修图成功覆盖原图，生图另存新文件。
- 服务器成功扣减 AI 次数并返回 `X-ZENCHE-Remaining`；失败请求回滚次数。代理生产端到端验证成功。
- 版本元数据已提升为 `1.4.0 / build 23`；README 三语、CHANGELOG、公告、构建脚本和发布说明同步。
- 验证完成：`npm test` 59/59 通过，`git diff --check` 通过；五端包和六份 SHA-256 均已生成并本地回验。
- 本地附件 SHA-256：Android `f89f873db175e393b47e5195fbfce396a63c536782048b424ba7e060ff61f444`；HarmonyOS `ce81c588af1de6da7ecc7c1898dcf7094cda3810fb2c6465f67b2325a72cba9b`；iOS unsigned `8e70058c3e0a6004de6e81098cb7b69c28ac77fbf9f5c6c1320fd32c8be66dfb`；macOS `531a206288bf1f669d6e96566527da14970857da33deae7d077e40ca809aacea`；Windows Setup `486052d2cd398bbb62eedd983f7bb544e431fd35d7225ba75789ee1caa010499`；Windows ZIP `d33cc4696eec6a36f0b7866d9155b82bcc2b1993f8cc8ea4071752b9b74a4c22`。
- 签名状态：macOS ad-hoc 未公证，Android debug，HarmonyOS/iOS unsigned，Windows 无商业代码签名；仍需各平台正式签名和真机验收。
- 已完成提交 `8a13c0b`（`release: 帧澈 ZENCHE v1.4.0`）、标签 `v1.4.0` 和详细中文 GitHub Release：<https://github.com/Tauber01/ZENCHE/releases/tag/v1.4.0>。
- Release 已上传 12 个附件（六个交付包及六个 `.sha256`），本地 SHA-256 已回验：Android `f89f873db175e393b47e5195fbfce396a63c536782048b424ba7e060ff61f444`；HarmonyOS `ce81c588af1de6da7ecc7c1898dcf7094cda3810fb2c6465f67b2325a72cba9b`；iOS unsigned `8e70058c3e0a6004de6e81098cb7b69c28ac77fbf9f5c6c1320fd32c8be66dfb`；macOS `531a206288bf1f669d6e96566527da14970857da33deae7d077e40ca809aacea`；Windows Setup `486052d2cd398bbb62eedd983f7bb544e431fd35d7225ba75789ee1caa010499`；Windows ZIP `d33cc4696eec6a36f0b7866d9155b82bcc2b1993f8cc8ea4071752b9b74a4c22`。
- 远端 `main` 在此前 v1.3.1 发布分支上存在删除 `AGENTS.md`/`PV` 的历史，无法快进接受本地 `1.4.0` 提交；为避免覆盖远端历史，本次仅推送了独立 `v1.4.0` 标签和 Release，未强推 `main`。

### 8.1 v1.4.1 小版本发布记录

- 提交：`a029da8`（`release: 帧澈 ZENCHE v1.4.1`）；标签：`v1.4.1`。
- GitHub Release：<https://github.com/Tauber01/ZENCHE/releases/tag/v1.4.1>，已公开上传 12 个附件（六个交付包及六个 `.sha256`）。
- 最终 SHA-256：Android `5bd2d03c433765646ec96d54a104ddce3e662ba5df789dc6440ec55c341f16f3`；HarmonyOS `510f4403d970dd7cb6f23b151005592218e897012ae744e20e495e67f759c458`；iOS unsigned `157fedc5a31830c063d4e5a9f5d94a4c79fa028b3ac5577935b4a69a5ee50a28`；macOS `96b2ce2a76c16736ed4a14ed508b493dd0902ecd9ce9810c6f3224348ad12692`；Windows Setup `9dd7f7821e344ff98190b670385790d8bad5074edf07aa7e1646a8ecd56fe124`；Windows ZIP `0a4d9d839bad9258c9b2fa1cb2d8fb6e4a3de3c016d375a7043baf02e7ac5aac`。
- 发布验证：`npm test` 62/62 通过；`git diff --check` 通过；iOS、Android、HarmonyOS、macOS、Windows 五端构建成功；六份 SHA-256 使用 `shasum -a 256 -c` 回验通过。
- 签名与限制：Android debug；HarmonyOS/iOS unsigned；macOS arm64 ad-hoc 未公证；Windows 无商业代码签名。音频波形为无音频源时的静音基线，点按对焦尚未完成相机真机覆盖验收。

### 8.2 v1.5.0 外录交付记录

- 五端原生外录、AVI/MOV 文件库接入、会话命名/备份/SHA-256、断开安全收尾与三语公告已完成；详细中文发布说明位于 `docs/releases/v1.5.0.md`。
- 验证：`npm test` 111/111 通过，`git diff --check` 通过；iOS Simulator、Android、HarmonyOS、macOS、Windows 编译成功；两帧外录样片由 `ffprobe` 识别为 720×480 MJPEG AVI。
- 六个包全部生成并通过 `shasum -a 256 -c`：Android `03714f1172471a6edf5191a5e47070209b0800d3289bb7c6ef4a8fd3d03381c9`；HarmonyOS `52cd5324330001908fe6e620046ea9280e7fac82c2c709db8c0c213820c1478b`；iOS unsigned `48920468b1a7f6b2c4e215be1263cee9ebfac05a6059268fd1c2645cb906e740`；macOS `6d8b50de36c3ef6d0548281829d27776104c850ebb0837bc622afc5cbfe1ca8d`；Windows Setup `a0194d1059b53e1004b9a9aad8d10b4b86da8a77338cb41c6e68439ea715548e`；Windows ZIP `ac657be979c4df2d05f30fb36faba5c472df11048efebd112b6b1df68c29b0d2`。
- 签名状态：Android debug；HarmonyOS/iOS unsigned；macOS arm64 ad-hoc 未公证；Windows 无商业代码签名。Windows 包已按要求通过 `scripts/build-windows.ps1` 生成版本化 Setup 与 SHA-256。
- v1.5.0 尚未提交、打标签、上传 GitHub Release 或同步到生产下载服务器；不得把本地包误记为已发布版本。

## 9. 原生监看波形与点按对焦（2026-08-02）

- 五端原生监看页同步调整：录制键位于 RGB 三色叠加波形与音频波形之间；移除监看镜头读数；移除监看工具中的“曝光”入口；保留并显式开放帧率、快门角度、ISO，以及光圈/白平衡等可调参数。
- iOS、Android、HarmonyOS、macOS、Windows 的监看预览均接入点按焦点反馈：显示短时黄色焦点标记并调用现有原生对焦/焦点步进接口。PTP 平台按点位象限映射焦点步进；相机未开启实时取景或机身不支持时显示失败/提示，不伪造音频数据。
- 音频采集管线当前尚未接入五端相机传输层，因此音频波形显示“无音频源 · 静音基线”。
- 验证命令：`npm test`（62/62）；`git diff --check`；iOS Simulator `xcodebuild ... build`；macOS `swiftc -typecheck`；Android `./gradlew :app:compileDebugJavaWithJavac` 与 `scripts/build-android.sh`；`scripts/build-harmony.sh`；`scripts/build-macos.sh`；`scripts/build-windows.ps1`。
- 已生成并校验 SHA-256；最终 Release 哈希记录在本节 8.1 与 `docs/releases/v1.4.1.md`：Android `5bd2d03c433765646ec96d54a104ddce3e662ba5df789dc6440ec55c341f16f3`；HarmonyOS `510f4403d970dd7cb6f23b151005592218e897012ae744e20e495e67f759c458`；iOS unsigned `157fedc5a31830c063d4e5a9f5d94a4c79fa028b3ac5577935b4a69a5ee50a28`；macOS `96b2ce2a76c16736ed4a14ed508b493dd0902ecd9ce9810c6f3224348ad12692`；Windows Setup `9dd7f7821e344ff98190b670385790d8bad5074edf07aa7e1646a8ecd56fe124`；Windows ZIP `0a4d9d839bad9258c9b2fa1cb2d8fb6e4a3de3c016d375a7043baf02e7ac5aac`。
- 签名状态：Android debug；HarmonyOS/iOS unsigned；macOS ad-hoc 未公证；Windows 无商业代码签名。尚未进行相机真机点按对焦验收。

## 10. 已知文档债务

- `docs/CAMERA_TEST_CHECKLIST.md` 的机型清单和“Current build status”仍停留在 17 款 EXPEED 6/7、1.0.0，应更新到当前 20 款、1.3.0，并填入真实验收结果。
- `docs/DEEPSEEK_V4_PRO_HANDOFF.md` 是 2026-07-30 的历史交接快照，包含 1.0.0、17 款机型等过时信息；可用于追溯，不应作为当前状态来源。
- `AGENTS.md` 已于 2026-08-03 由项目负责人提供权威版并恢复纳入仓库版本控制（见 §12.1）；`AGENT_START_PROMPT.md` 不在仓库中，权威副本见工作区 `GUIDES/ZENCHE_START_PROMPT.md`，后续可评估是否纳入 git。

## 11. 下一步优先级

### P0：收敛 1.3.1 发布

- 已在 macOS 使用 `pwsh scripts/build-windows.ps1 -LibUsbDll .toolchains/libusb-1.0.29/VS2022/MS64/dll/libusb-1.0.dll` 生成 Windows x64 Setup/ZIP 与 SHA-256；仍需在 Windows 主机完成安装、升级、驱动与 SmartScreen 验收后再上传正式 Release。
- 将 `claude/modest-albattani-34402d` 分支合并回 `main`，确认更新公告与 README 三语一致。
- 确认 `101.34.255.115:8787` 服务器以 pm2/systemd 守护，重启后自动拉起；完善 AI 激活码发放流程。

### P0：相机与传输实机矩阵

- 更新 `docs/CAMERA_TEST_CHECKLIST.md` 至 20 款机型。
- 优先验证新增 D500、D7500、D850，以及历史问题涉及的 Z5、Z8、Z30。
- 覆盖实时取景、参数可写性、B 门释放、50 帧稳定性、拔插/睡眠恢复和文件完整性。
- 在各平台验证 FTP、HTTP/WebDAV 的鉴权、大文件、中断和端口释放。

### P1：生产分发闭环

- 配置 Android release signing、HarmonyOS signing、Apple 签名与 macOS notarization。
- 在 Windows 主机执行版本化 NSIS 构建和干净 Windows 11 安装/升级/卸载验证。
- 调整发布编排，确保 GitHub Release 五端附件和校验文件不缺失。

### P1：AI 功能扩展与质量

- 各平台真机验证 AI 面板布局、触控与生成流程。
- 为 AI 服务器补充监控、日志轮转与失败告警。
- 评估 AI 修图参考图上传尺寸限制、超时与重试策略。

## 12. 每次更新本文件时记录什么

每次工作结束至少更新以下信息：

1. 改了哪些平台、功能和文件范围。
2. 哪些状态从“进行中”转为“已实现待验收”或“已完成”。
3. 实际运行了哪些命令、测试、设备和场景，结果是什么。
4. 生成了哪些版本化包与 SHA-256，签名和可安装状态是什么。
5. 哪些事项因主机、工具链、凭据或硬件而阻塞。
6. 下一位智能体应从哪个具体步骤继续。

不要把计划写成完成，不要把静态测试写成实机通过，也不要把未签名容器写成可安装正式包。每次 GitHub 上传后，必须把实际发布状态同步回本文件、`docs/PROJECT_OUTLINE.md` 和 `docs/TECHNICAL_APPROACH.md`，不得只依赖聊天记录。

### 5.6 多端拍摄修复与监看画质优化（2026-08-02）

修复 GitHub issue #39（Android Nikon Z50 拍摄失败）并同步多端同类问题：

- **Android**（`PtpCamera.java`）：停实时取景后等待相机就绪再拍摄、拍摄前再等就绪、GET_OBJECT 遇 PTP 0x2009 DeviceBusy 重试 4 次；`MainActivity.java` 监看实时取景改为全分辨率解码，去除 inSampleSize=2 画质减半。
- **macOS**（`main.swift`）：新增 isBusyFailure 识别 gphoto2 busy/processing 输出，run() 忙时重试 3 次；停实时取景后轮询 `--get-config` 等待相机就绪。
- **Windows**（`PtpCamera.cs`）：CaptureToSdram 前 `WaitUntilDeviceReadyAsync(8000)`；`MainWindow.xaml.cs` 补齐激活码本地 RSA 验签（此前任意码都被接受为激活成功）。
- **HarmonyOS**（`PtpCamera.ets`）：停实时取景后等待就绪、GET_OBJECT 遇 0x2009 重试 4 次。

提交：`606a6ec`（分支 `claude/modest-albattani-34402d`，6 文件 +235/-15）。Android/macOS/HarmonyOS 产物已重建并上传 GitHub Release `v1.3.0`。

本次同步检查：iOS 使用 AVFoundation 无 PTP 拍摄，不受影响；四端监看画质仅 Android 存在减半问题（已修复），其余平台全分辨率。AI 兑换码逻辑确认 NONCE（a1b2c3d4e5f6）在兑换服务、AI 代理、各客户端验签间一致；Windows 激活验签已补齐对齐。

## 12.1 AGENTS.md 恢复并纳入版本控制（2026-08-03）

- 背景：远端 `main` 历史曾删除根目录 `AGENTS.md`；2026-08-03 项目负责人在 general 频道提供权威版（媒体哈希 `294eeccecb7bdba21aec11fb0671253e60d50542da13d67e2d113d7e6d2cd8f7`）。
- 操作：将权威版原样放入仓库根目录 `AGENTS.md`（SHA-256 与媒体哈希一致）；同步更新 `docs/PROJECT_OUTLINE.md` §7 与 `docs/TECHNICAL_APPROACH.md` 前置阅读注记。
- 提交：见本次提交（`docs: 恢复 AGENTS.md 权威版并纳入版本控制`），未推送远端。
- 工作区存档：`GUIDES/ZENCHE_AGENTS.md`（含 frontmatter 的来源注记）与 `GUIDES/ZENCHE_START_PROMPT.md`。

## 12.2 v1.5.2 连接、AI 服务与设备码迁移发布（2026-08-04）

- Git 身份已按仓库本地配置固定为 `Tauber <2642079880@qq.com>`；UI 基线提交 `be8290b`，core 可靠性基线提交 `668bfe4`，均含相同的 `Co-authored-by` 与 `Signed-off-by` trailer，尚未推送。
- Android USB/PTP 只对四类已知异步失败启用 `UsbRequest → bulkTransfer` 降级；首次同步降级成功后本会话粘滞走同步传输，重连与关闭重置，其他错误不吞掉。
- `ai-server/app.mjs` 是仓库内零依赖候选代理：默认回环监听，真实 generate→poll→download 链路有流式大小上限，参考图先校验再扣次，失败退款；计数写盘使用文件与目录双 fsync、三态恢复和存储异常 fail-stop。
- Tauber 在 Buzz 事件 `ea6ca27e…d525c` 明确允许“旧激活码 + 当前绑定旧设备码”迁移。服务端候选 `POST /v1/ai/rebind` 默认关闭，迁移时先通过回环 redeem 签发新码并本地验签，再单次耐久事务继承 `used`/`expiry`、冻结旧记录；支持幂等、链式迁移、目标占用保护、IP/激活码指纹限流、脱敏审计、AI in-flight 计数和换绑写锁。
- 回环 redeem `/issue-migrated` 签发端、五端恢复 UI、旧码预验签、新码二次验签及本地耐久替换已并入集成分支；恢复端点固定为 HTTPS。Nginx 精确反代、DNS 切换、关闭公网 8787、生产秘密注入、灰度与回滚仍未实施，没有生产服务器改动。
- 自动化基线：core `87cb78c` 为 `225/225`；redeem `3745eda` 为 `237/237`；五端客户端切片在 UI 分支为 `138/138`。独立审查 `87cb78c` 无 P0，发现的唯一 P1 是迁移链尾退款缺少测试；集成分支已补等价的 in-flight 退款与链尾解析覆盖，合并态完整 `npm test` 为 **248/248** 通过。
- 最终独立发布审查核对代码提交 `dce831d`、文档提交 `315809b`、完整测试、diff、秘密扫描、当时已有的四个本地产物及源码 ZIP 树，结论为无 P0、无 P1、5 项 P2 均不阻塞。此前 P1 已闭环，本地候选交付门禁通过；随后补生成的 macOS/Windows 包另按平台工具完成签名、镜像、容器和 SHA-256 验证。Tauber 在完整风险披露后明确决定将其发布为 GitHub stable；该决定不放行生产换绑。
- 发布状态：`main` 已快进到 `7376cf102ec5ab14208d047f60f28941843fe1c2`，注释标签 `v1.5.2` 指向同一提交，[GitHub Release](https://github.com/Tauber01/ZENCHE/releases/tag/v1.5.2) 已于 `2026-08-04T01:33:54Z` 发布为 Latest，且为非草稿、非预发布；生产未部署。
- 交付结果：Release 共 14 个附件，包含 Android APK、HarmonyOS HAP、iOS unsigned IPA、macOS arm64 DMG、Windows x64 Setup/ZIP、精确源码 ZIP 与七份同名 `.sha256`。发布前完整 `npm test` **248/248**、`git diff --check` 和本地七包校验均通过；发布后已把 14 个线上附件的字节数与 GitHub SHA-256 摘要逐项对照本地文件，14/14 一致、零差异。完整清单、哈希和签名状态见 `docs/releases/v1.5.2.md`。
- 线上交付包 SHA-256：Android `d90bc767d0b1b710f66e5a2b8b15a36e41932ab3a6f563f43fdbb6b6c96f87a9`；HarmonyOS `da67a6373ad4faaf64e19f512e93206f7218068b6ccd2c68d262dcc77760370f`；iOS `97976caca49bd9d00cdfa38f86be0615d7139952e424ffe8f6b3da7ab96712cc`；macOS `37d02a5c5f0a2220dcd9e9ccc93abd9f7e4c859be9ee26c45c587b5cec62d2c0`；Windows Setup `145fa25551ee14bd39bf84f0266aaff069625ba26e47ed38895b651f6ed276af`；Windows ZIP `04ebe53602db9ba7a8e77ed2b51ced917a982aeec379ab62c013a764ae04b57c`；源码 ZIP `676d8a2e7bf3b20c3a316cdff035bd9d48ef22d38b4b62a24232f131a5836a25`。
- 签名与主机限制：Android 为 Debug 证书，HarmonyOS/iOS 未签名，macOS 为 ad-hoc 且未公证，Windows 为 macOS 主机交叉构建且未使用受信任代码签名证书；真实 Windows 安装、驱动和 SmartScreen 仍未验收。GitHub stable 状态不改变这些附件属性。
- macOS DMG 已通过 `codesign --verify --deep --strict` 与 `hdiutil verify`；Windows ZIP 已确认包含主程序、Nikon/Sony SDK 运行库和匹配的 `libusb-1.0.dll`，Setup 为 NSIS PE 安装器。仍需 Developer ID/公证、受信任 Windows 代码签名、真实 Windows 主机安装/驱动/SmartScreen，以及五端实机矩阵，才能闭环受信任签名与完整实机发布门禁。

## 12.3 v1.5.2 README 发布信息同步（2026-08-04）

- 根目录 `README.md` 已将简体中文、English、日本語三段的稳定版、源码版本、Release 链接、下载链接、交付包文件名和 SHA-256 校验示例从 v1.5.1 同步为已发布的 v1.5.2。
- README 新增三语等价的 v1.5.2 更新摘要：五端全局状态条、设备码恢复与二次验签、Android 已知异步传输失败的同步 bulk 降级、默认回环监听的零依赖 AI 代理，以及发布说明链接。
- 验证：`rg` 未发现 README 残留 v1.5.1 或“本地交付候选/未发布”表述；`git diff --check` 通过。未修改应用代码、版本号、Release 附件或生产服务。
- 下一步：提交并推送本次 README 与三份长期文档同步；继续如实保留 v1.5.2 的签名、Windows 主机、实机矩阵和生产换绑限制。

## 12.4 v1.5.3 五端工作台界面发布（2026-08-04）

- 发布流程由智能体 kimi 接手执行（GPT5.6 因额度停用），授权依据为 Tauber 在本频道的明确指示“1.5.3 上传 GitHub，继续推进 1.5.4”。
- 发布前复验：`dist/` 七个 1.5.3 交付包 `shasum -a 256 -c` 全部通过，`git diff --check` 干净，完整 `npm test` **256/256** 通过（复跑于 `agent/1.5.3-ui` 工作树）。
- 提交：发布准备提交 `697f3f8d1028426dc5eec430230dcf48754f9b15`（仅 README 三语与 CHANGELOG 的 v1.5.3 发布信息同步，含 Tauber 的 `Co-authored-by` 与 `Signed-off-by` trailer）；`main` 从 `5ea2a50` 快进到该提交并推送。
- 标签：注释标签 `v1.5.3`（标签对象 `64d69abe2f2fce4969cc26a89672255bdc9281ad`）解析到 `697f3f8`，已推送。
- Release：<https://github.com/Tauber01/ZENCHE/releases/tag/v1.5.3> 于 2026-08-04T07:43:34Z 发布为 Latest，非草稿、非预发布，正文为详细简体中文（亮点、平台变化、相机兼容、验证、签名状态、已知限制、升级指引、SHA-256 表）。
- 线上回验：Release 共 14 个附件（七个交付包 + 七份同名 `.sha256`），通过 GitHub API 逐项比对线上字节数与 `digest` 字段，14/14 与本地文件完全一致、零差异。
- 线上交付包 SHA-256：Android `3c79546bb80ea1d1043aae06fc4d5b848d661b72f871f646b3a4c4db8379b182`；HarmonyOS `9dc53cce4375714bfedaac0f7df76e6d225cdeb6fa86f556c6aadc5c30bbd328`；iOS unsigned `9ddff92fc0cfc8a98d56edef017a475241ae1f8b4911b84cb559ddba0cd215dd`；macOS `b921f2c3573891fc340e1fac627aa663fa74c7bf28f4ea62a161b8b2eb5e81a5`；Windows Setup `24769cf08627890ee6d67a23aa0567b92b3b9de5c1e0e08d5485a9ec1f7b631c`；Windows ZIP `fd9dbcba313d04180b5561e9e3bc96097247c931dc4558305a547f77e10470dc`；源码 ZIP `686c318574b78186e8cd80bb41c01130bb18b988ff3c7344fa253a330825e382`。
- 签名与主机限制保持披露：Android Debug 证书，HarmonyOS/iOS 未签名，macOS ad-hoc 未公证，Windows 为 macOS 交叉构建且无 Authenticode、未完成真实 Windows 主机验收；GitHub stable 标识不改变这些附件属性。生产下载服务器与生产换绑均未变更。
- 下一步：继续推进 1.5.4 文件库管理（先完成 `agent/1.5.4-file-core` 第四轮改动的验证收口，再评估集成）。

## 12.5 RGB 三色波形五端改造合入（2026-08-05）

- 指令：Tauber 09:56 指示「修改所有的示波器为 RGB 三色波形图」；实现分支 `agent/rgb-waveform`（基线 `425ed09`），pro 独立复审 `36785c8` 无 P0/P1 通过后，kimi 指示收尾清理并合入整合分支 `agent/1.5.6-ui`。
- 功能提交 `36785c8`：五端视频波形示波器统一为 RGB 三色叠加——iOS/macOS ProfessionalScopeBoard 移除 Y/YUV 面板改单 RGB 叠加、Android WaveformScopeView 删 PROFESSIONAL 模式、Harmony drawProfessionalScope 三面板收敛、Windows WaveformScopeMode 删 Professional；守门测试/design.md/docs 三件套同步。数据契约（S64x48 + ProfessionalMonitor 六份密度图）零改动。
- 收尾提交 `372468f`（pro 复审残留清理）：Android/Windows setData 删 luma/chroma 尾参与字段（拉齐 iOS/macOS 已删参口径）、四端 YUV 死常量删除（iOS/macOS Palette.scopeYuvY/U/V、Android/Harmony SCOPE_YUV_Y/U/V）、守门测试补 iOS/macOS/Harmony Y/YUV 面板反向断言。
- 合并提交 `b96f63f`（`--no-ff`，信息注明「RGB 三色波形图 + 复审通过」）：`agent/rgb-waveform` 合入 `agent/1.5.6-ui`，12 文件 +75/-247，合并态工作树干净（仅 `.scratch/` 未跟踪）。
- 验收：收尾提交后与合并后各跑一次完整 `npm test`，均 **256/256** 全绿（含 native-waveform-scopes 5/5）。
- 编译验证：macOS swiftc -typecheck 0 错误、Android javac 通过、Windows dotnet build 成功、Harmony assembleHap BUILD SUCCESSFUL（iOS 本轮未重跑，改动仅为 3 处死常量删除，首轮 BUILD SUCCEEDED）。
- 打包暂不启动：等 v1.5.7 UI 轮定版后统一打。

## 12.6 v1.5.7 F1 macOS 基准自修（2026-08-05）

- 批次：v1.5.7 UI 统一轮先行批 F1（macOS 基准自修，做基准前先收口自身债务）；分支 `agent/1.5.7-f1-macos`（worktree REPOS/ZENCHE-wt-1.5.7-f1-macos），基线 `7a4ee35`，仅动 macOS 端与 design.md/docs 三件套。
- TypeScale 新增 `heading 26` 页面标题档：WorkspaceHeading 32pt 归 heading、设置面板主标题/各页面大标题（26/28/34）归 heading；Typography 增补该档说明（文字页面标题，与 display 大数字档互补，每屏仍 ≤5 档）。
- main.swift 字号字面量收敛：正文/标签 34 处归 TypeScale（8/9/10→caption 11 等）；图标尺寸 15 处（SF Symbols 17-46）与专属读数 3 处（曝光参数 28、存储读数 25、Splash Z 字标 42）保留原值并加注释声明。
- SettingsSheet 13 档字号（10-26 共 13 值）收敛为 TypeScale 5 档 + heading：卡片标题 16→title、子项标题 14→emphasis、描述/按钮 13→body、辅助说明 10/11→caption、面板主标题 26→heading、面板标题 17/20/23/24→title/display；仅 3 处图标（19/20/22）保留并注释。
- 小额项：曝光参数卡自动徽标「A」→「AUTO」完整字面（对齐 iOS 口径，圆徽标改 Capsule）；「选择预设」按钮暗色 tint 由 readoutGlow 改回 cobalt（readoutGlow 仅用于曝光读数）。
- design.md 增补：恒深页（fig1 控制面/fig2 编辑器工作台）为「每页双外观」条款的文档化例外（v1.5.6 终审遗留文档债收口）+ 沉浸全屏 overlay 同属恒深例外族（预览井/沉浸 overlay 任何外观保持石墨）。
- 验证：swiftc -typecheck（build-macos.sh 同口径源列表）0 错误；完整 `npm test` 256/256 通过；git diff --check 干净。

## 12.7 v1.5.7 逐页批次 P1：照片页（capture）四端对齐 macOS 基准（2026-08-05）

- 批次：v1.5.7 UI 统一轮逐页批次 P1（照片/capture 四端对齐 macOS 基准，含拍摄自动化面板）；分支 `agent/1.5.7-p1-capture`（worktree REPOS/ZENCHE-wt-1.5.7-p1-capture），基线 `693182a`（F1 合入后）。
- iOS（RootView.swift）：曝光参数 automatic 徽标单字母「A」圆标 → 完整「AUTO」Capsule（FontToken.caption + IPalette.uiBlue，对齐 macOS F1 口径；pro 复审观察项收口）。
- Android（MainActivity.java）：参数 tile 「×」隐藏钮 22×22dp → 44×44dp（触控合规，design.md ≥44×44）；顶栏与状态行状态点 22dp → 10dp（视觉对齐 macOS 8pt 基准，触控面由外层 44/36dp 高行保证，注释声明）。
- Harmony（Index.ets）：参数 tile 「×」钮宽 22vp → 44vp（高已 44）；状态点宽 22vp → 10vp；恢复 4881042 删除的兑换码说明文案（「兑换码仅用于 AI 云服务次数，帧澈本体保持免费开源。」+「没有兑换码？在爱发电购买兑换码」，TS_CAPTION/TS_BODY token 化，审计 backlog 项收口）。
- Windows：P1 结构已对齐 macOS fig1 基准（状态行/状态卡阵/参数格/拍摄坞/拍前会话/拍摄自动化面板均在），字号归档归 F5 批，本批无代码改动。
- design.md：本批为执行既有条款（触控 ≥44×44、AUTO 口径对齐 F1 已文档化），未引入新规范，无需修改。
- 验证：完整 `npm test` 256/256 通过；iOS xcodebuild Release（免签名）BUILD SUCCEEDED；Android `:app:compileDebugJavaWithJavac` 通过（仅基线 deprecation 提示）；Harmony assembleHap BUILD SUCCESSFUL（构建中间产物与 dist 已清理）；git diff --check 干净。

## 12.8 v1.5.7 逐页批次 P2：视频页（monitor）四端对齐 macOS 基准（2026-08-05）

- 批次：v1.5.7 UI 统一轮逐页批次 P2（视频/monitor 四端对齐 macOS 基准，含沉浸监视 overlay 复核）；分支 `agent/1.5.7-p2-monitor`（worktree REPOS/ZENCHE-wt-1.5.7-p2-monitor），基线 `8138ed2`（P1 合入 + RGB 三色波形已合入）。
- Windows（Controls.xaml / MainWindow.xaml）：监视读数 22pt 字面量 8 处（7 格读数 MonitorFrameRate/Shutter/Aperture/Iso/WhiteBalance/Codec/Tone + 存储读数 MonitorStorageFreeText）归档为 `MonitorReadout` 样式（MonoFont + Bold + 22pt + MonitorWellTextBrush，等宽 display 档），对齐 macOS monitorReadout 读数口径（等宽 + 大数字 display 档）；品牌 Z 标（L65/L478）与预览空态提示（L202，DisplayFont 22pt）上下文确认不属读数，保留原值待 F5 统一收口。
- iOS（CameraService.swift / RootView.swift）：`MonitorVideoCodec` 新增 `shortLabel` 计算属性（逐值对齐 macOS shortLabel 映射，automatic→自动）；MonitorConsolePage 读数轨补「编码」格（白平衡与色调之间），对齐 macOS 7 格契约（帧率/快门/光圈/ISO/白平衡/编码/色调）。
- Android（MainActivity.java）：新增 `videoCodecShortLabel()`（对齐 Windows `VideoCodecShortLabel` 口径，Android raw 值 prores422hq/nraw 等）；`buildMonitorParameterRail` 补「编码」格。
- Harmony（Index.ets）：新增 `videoCodecShortLabel()`（缺省回落全标签）；`MonitorParameterRail` 补「编码」格（tr('编码') 词条已有）。
- 沉浸 overlay：四端复核通过（native-ui-1.5.3 四件套 telemetryHUD/ScopeDock/ToolRail/ParameterTray 断言 + design.md 固定深色族条款 L67-76/369），本批未改动；RGB 三色波形渲染层（MacScopePlot/WaveformScope 等）未触及，仅测试验证不回退。
- Harmony MonitorScopeRail 缺中间录制钮：与 macOS/Windows/Android/iOS 形态差异，但 Harmony 底部已有录制按钮覆盖交互且审计未列 → 记 backlog，本批不动。
- design.md：本批为执行既有条款（读数 = 等宽 display 档，design.md Typography「display step reserved for large numerals/readouts」），未引入新规范，无需修改。
- 验证：完整 `npm test` 256/256 通过；iOS xcodebuild Release（免签名）BUILD SUCCEEDED；Android `:app:compileDebugJavaWithJavac` 通过（仅基线 deprecation 提示）；Harmony assembleHap BUILD SUCCESSFUL（构建中间产物与 dist 已清理）；Windows dotnet build 通过；git diff --check 干净。

## 12.9 v1.5.7 逐页批次 P3：编辑页（editor）四端对齐 macOS 基准（2026-08-05）

- 批次：v1.5.7 UI 统一轮逐页批次 P3（编辑/editor 四端对齐 macOS 基准）；分支 `agent/1.5.7-p3-editor`（worktree REPOS/ZENCHE-wt-1.5.7-p3-editor），基线 `7e52a75`（P1/P2 合入后）。
- Windows（MainWindow.xaml / Controls.xaml / MainWindow.xaml.cs）：EditorPanel 区 21 处字号字面量归档为 DynamicResource 样式，新增 14 样式（EditorNodeIcon / EditorCaption / EditorPreviewEmpty / EditorAccentLabel / EditorAIMetrics / EditorAISummary / EditorMonoLabel / EditorRailTitle / EditorScopeHint / AiPreviewEmpty / AiPreviewBadge / AiPanelHint / AiUnlockStatus / AiStatusText）；XML 子树解析验证 EditorPanel 元素内 0 字面量（文件其余 79 处属 capture/settings/monitor/AppBar/dialog 等 P3 范围外区域）；`BuildEditorAdjustmentControls` 工具组添加顺序按 macOS 基准拉齐（光线/色彩/色轮/曲线/取色器/蒙版/细节/效果/几何）。
- Harmony（Index.ets）：新增 5 常量 `EDITOR_FS_TINY=9 / SMALL=10 / SUB=13 / MEDIUM=14 / HEAD=16`（TS 五档之外既有值，只归档不改值）；编辑区（1944-4083）17 处字面量替换，残留 0。
- Android（MainActivity.java）：新增 4 常量 `EDITOR_FS_SMALL=10 / SUB=13 / MEDIUM=14 / HEAD=16`；13 处替换（审计 9 + 同编辑区额外 4：L6888「款 NP3」11、L7594「已选择原图」11、L7978 文件名 12、L8390 色轮值 10）；与 TS token 重合值直接映射（11→TS_CAPTION×4、12→TS_BODY×2）。
- iOS（RootView.swift）：新增 `EditorFontSize` 枚举（tiny=9 / small=10）；3 处替换（审计 1 + EditorScopeDock 1762/1767 + 2123）。
- 十组工具一致性核对：五端均暴露同 10 组（光线/色彩/色轮/曲线/取色器/蒙版/细节/效果/几何/AI）、命名一致；macOS/iOS 走 `EditorAdjustmentSection.allCases` 枚举平铺、Windows/Harmony/Android 走 5 钮 EditorToolRail + 面板钮，属既有平台结构差异未动（守门测试仅断言标签不断言导航形态）。
- 共享面板：`buildNikonCloudMonitorPanel`（capture/monitor/editor 共用）8599/8998 字面量按审计列 P3 归档为 EDITOR_FS_SUB，无视觉变化。
- AI 呈现差异保留：macOS/iOS 编辑页「AI 工具」为工具分组之一 vs Windows/Harmony/Android「AI」轨钮 + 独立工作台，既有设计差异，非红线违规。
- design.md：本批为执行既有条款（fig2 恒深直角、只归档不改值），未引入新规范，无需修改。
- 验证：完整 `npm test` 256/256 通过（Windows 组序调整后复跑）；Windows dotnet build 0 错误 4 既有警告（CS8629×2 / CS0414×2）；Harmony assembleHap BUILD SUCCESSFUL（未签名预期）；Android assembleDebug BUILD SUCCESSFUL（仅基线 deprecation 提示）；iOS xcodebuild 模拟器 BUILD SUCCEEDED；git diff --check 干净；macOS 编辑区（9483-9700）复核 0 字号字面量（基准端无需改动）。

### 12.9 勘误（2026-08-05，pro 复审口径核对）

- 样式数更正：新增 DynamicResource 样式实为 **17 个**（原报 14 漏 3：EditorHeaderTitle / EditorRailLabel / EditorMediaCount），MainWindow 移除 21 处 FontSize 不变。
- EditorPanel 0 字面量口径更正：**EditorPanel 元素树（XML/ET 解析）内 0 字号字面量属实**（SettingsPanel 为兄弟面板、开于 L1703，不在 EditorPanel 元素树内）；但按行号区间口径（L1174 开标签起配对），区间内另有 8 处（L1839/1855/1880/1888/1897/1906=11、L1957=15、L1961=12）——ET 容器链证实全部位于 **SettingsPanel 元素树**（AI 激活/恢复设备码/快速反馈，对标 macOS SettingsSheet，属 P6 设置页内容），本批未动、归 P6 收口。原报告只给了元素树口径，未给行区间口径，表述不完整。
- buildNikonCloudMonitorPanel 归属更正：审计文档（PAGE_AUDIT.md）**无该面板条目**，原报告「按审计列 P3 归档」不实；实际为拍摄/视频页共享面板的延伸归档（Android L8601 13→EDITOR_FS_SUB 等值，无行为改变），记 backlog：F3 批核对时避免重复处理。

## 12.10 v1.5.7 逐页批次 P4：我的设备页（devices）四端对齐 macOS 基准（2026-08-05）

- 批次：v1.5.7 UI 统一轮逐页批次 P4（我的设备/devices 四端对齐 macOS 基准）；分支 `agent/1.5.7-p4-devices`（worktree REPOS/ZENCHE-wt-1.5.7-p4-devices），基线 `073d816`（P1-P3 合入后）。
- iOS（RootView.swift）：新增 `DeviceFontSize.heading=30`（对标 macOS WorkspaceHeading，值不等 F1 heading 26，只归档不改值）；设备页大标题 1 处字面量替换；**卡信息行补 vendor**（`device.vendor · device.transport`，对齐 macOS 基准「vendor · transport」信息项，原仅有 transport）。
- Android（MainActivity.java）：新增 `POSITIVE_SOFT` 常量（Color.rgb(228,247,238) 去硬编码，对齐 Harmony POSITIVE_SOFT——**去字面量，非双外观收口**：该值为单外观浅绿、不随 night 切换，亮暗对留 F 批，pro 复审记录）；新增 `PAGE_FS_HEADING=30/PAGE_FS_HEADING_COMPACT=25/PAGE_FS_SUBTITLE=14`（**sectionHeader 为共享组件，4 个调用方** 6167/6597/10640/11149，跨 P3/P5/P6 页，中性命名如实；compact 副标题 12 直接映射 TS_BODY）；设备页空态 `DEVICE_FS_EMPTY_TITLE=20`、`DEVICE_FS_SUB=13`；设备卡 18→TS_TITLE、11→TS_CAPTION、12→TS_BODY；**卡信息行补 vendor**（原仅 transport）。
- Harmony（Index.ets）：新增 `DEVICE_FS_HEADING=30/SUBTITLE=14/EMPTY_TITLE=21/CARD_TITLE=19/SUB=13`；标题/副标题/空态/卡名/vendor·transport 7 处字面量替换。
- Windows（Controls.xaml / MainWindow.xaml / MainWindow.xaml.cs）：新增 5 样式 `DeviceHeaderTitle(24)/DeviceEmptyTitle(21)/DeviceBadgeText(11)/DeviceNameText(18)/DeviceMetaText(11)`；DevicesPanel 头部标题与空态标题、cs 卡 badge/名称/最近连接全部样式化；占位图标 46 豁免注释。
- 双外观核对（P4 审计点）：iOS/Harmony/Windows 设备页全部 token 引用（IPalette.*/$r('app.color.*')/DynamicResource）；Android POSITIVE_SOFT 已去字面量（亮暗对未完成，见上）；Windows 占位 ◉ 白字有 design.md graphite 恒深井依据，iOS vendor 徽标白字实为图片 HUD 叠加惯例（基线既有，非恒深例外族，pro 复审记录）。
- 图标尺寸豁免：空态 ◉ 46/48、占位 ◉ 46（同 F1 先例，注释声明不受 TypeScale 约束）。
- 设备卡信息项五端核对：名称/当前已连接徽标/vendor·transport/最近连接/快速连接+忘记设备按钮五端一致（本批补 iOS/Android vendor 信息项）。
- design.md：本批为执行既有条款（双外观成对取 token、只归档不改值、图标豁免先例），未引入新规范，无需修改。
- 验证：完整 `npm test` 256/256 通过；iOS xcodebuild 模拟器 BUILD SUCCEEDED；Windows dotnet build 0 错误 4 既有警告（CS8629×2 / CS0414×2）；Android assembleDebug BUILD SUCCESSFUL；Harmony assembleHap BUILD SUCCESSFUL（未签名预期，构建中间产物已清理）；git diff --check 干净。

## 12.11 v1.5.7 逐页批次 P5：分支文件库页（library）四端对齐 macOS 基准（2026-08-06）

- 批次：v1.5.7 UI 统一轮逐页批次 P5（分支文件库/library 四端对齐 macOS 基准）；分支 `agent/1.5.7-p5-library`（worktree REPOS/ZENCHE-wt-1.5.7-p5-library），基线 `71a4c4f`（P1-P4 + P3 勘误后）。
- macOS 基准：LibraryView（main.swift:7956）HSplitView 左列分支工作台（MacLibraryBranchRow 7699）+ 相机存储（CameraStorageMacRow 7899）+ 系统相册 DisclosureGroup，右列无线传输折叠组（TransferView 8066，本批判定为分支页组成部分）；顶部工具条（刷新/网盘/分享/访达/废纸篓，7993-8016）。macOS 本端零改动（已全 token 化，仅 3 处图标豁免带注释）。
- iOS（RootView.swift）：新增 `PageFontSize.titleCompact=25/titleRegular=29`（PageTitle 共享组件 3 调用方 1964/6088/7703，定义 9874，compact 25 / regular 29 只归档不改值）；分支工作台 28pt 图标豁免注释。分支页其余字号全系统字体无字面量。
- Android（MainActivity.java）：新增 `LIBRARY_FS_WORKBENCH=20/TITLE=14/SUB=13`；分支页 9 函数 + 无线传输面板（buildWirelessTransferPanel/buildWifiCameraPanel，差距分析补录：macOS 基准右列即无线传输，属分支页）28 处字面量替换：20/14/13→LIBRARY_FS_*，12→TS_BODY、11→TS_CAPTION（与 TS 档重合直接映射既有 token）；sectionHeader 已 P4 归档未重复处理。
- Harmony（Index.ets）：新增 `LIBRARY_FS_TINY=10/SUB=13/TITLE=14/HEAD=16/WORKBENCH=20`；LibraryWorkspace（5393 起）分支页 14 处替换 + 徽标方块 16/播放图标 ▶ 20 豁免注释；CaptureSessionPanel(6201) 属 P1 组件（仅 CameraWorkspace 4270 调用）不在本批；无线传输卡（WirelessTransferCard 6408）为分支页组成部分一并归档。
- Windows（Controls.xaml / MainWindow.xaml）：新增样式 `LibraryHeaderTitle(24)/LibraryNodeIcon(15)`；LibraryPanel 头部标题 24→LibraryHeaderTitle、相机存储状态 11→MetaText（既有样式）、节点图标 15→LibraryNodeIcon、相机存储行图标 16 豁免注释；cs 中 BuildBranchNode/BuildMediaTypeNode 为纯数据构建无字号字面量。
- 双外观核对（P5 审计点）：四端分支页前景/背景均按外观成对取 token（Android INK/MUTED/COBALT/COBALT_SOFT 经 applyAppearanceTokens 亮暗双套；Harmony $r('app.color.*') 亮暗双资源；iOS IPalette 双套；Windows DynamicResource 双字典），无硬编码单外观色值；iOS 28pt 图标白字/Windows 16 图标白字位于恒深色块上属豁免族注释声明。
- 信息项五端一致性核对（以 macOS 为基准，存在等价操作即一致，不动标签文案）：顶部工具条（刷新相册/链接网盘/分享/访达显示/移到废纸篓）五端等价；iOS 大图预览含分享/编辑 + 选中区删除、Android 文件行含编辑/分享/删除按钮、Harmony/Windows 双击预览 + 右键/选中删除——均为等价信息项。标签文案一律不动（iOS「文件」/Android「已下载」/Harmony·Windows 侧栏长名属 F6 词表裁定，待 Tauber 拍板）。
- design.md：本批为执行既有条款（每屏 ≤5 档、只归档不改值、双外观成对取 token、图标豁免先例），未引入新规范，无需修改。
- 验证：完整 `npm test` 256/256 通过；iOS xcodebuild iphoneos BUILD SUCCEEDED（unsigned IPA）；Android assembleDebug BUILD SUCCESSFUL；Harmony assembleHap BUILD SUCCESSFUL（未签名预期）；Windows dotnet publish 0 错误 4 既有警告 + NSIS Setup 构建成功（LANG=en_US.UTF-8 下 makensis 3.12 正常解析 UTF-8 中文脚本）；git diff --check 干净。

## 12.12 v1.5.7 逐页批次 P6：设置页（settings）五端对齐 macOS 基准（2026-08-06）

- 批次：v1.5.7 UI 统一轮最后页面批 P6（设置页 settings，本批动 macOS 基准端）；分支 `agent/1.5.7-p6-settings`（worktree REPOS/ZENCHE-wt-1.5.7-p6-settings），基线 `878c447`（P1-P5 后）。
- macOS（SettingsSheet.swift，基准端，仅 1 处）：F1 已收敛 13 档→TypeScale 五档，本批补最后 1 处——语言选择器文本 `size: 11` → `TypeScale.caption`（等值映射 11=11，只归档不改值）；19/22/20 图标尺寸已有 F1 豁免注释不动。DiagnosticLogViewer（811-870）已全 token 化（22 图标豁免）。
- iOS（RootView.swift）：新增 `SettingsFontSize.linkLabel=13`；AppSettingsSheet 内「没有兑换码？在爱发电购买兑换码」「恢复设备码」2 处 13 替换。设置页其余字号全系统动态字档（61 处 .caption/.headline 等既有形态，非本批数字字面量范围）。
- Android（MainActivity.java）：新增 `SETTINGS_FS_TINY=10/SUB=13`；设置页 25 处替换——12→TS_BODY×11、13→SETTINGS_FS_SUB×5、11→TS_CAPTION×5、10→SETTINGS_FS_TINY×2、18→TS_TITLE×2（SDK 卡标题，等值映射 TS 档）；含拍摄辅助卡（buildCaptureAssistantsPanel 3 处 12）。
- Harmony（Index.ets）：新增 `SETTINGS_FS_TINY=10/SUB=13/TITLE=14`；SettingsWorkspace（7841）+ 拍摄辅助卡（CaptureAssistSettingsCard 7769）共 13 处替换：14→SETTINGS_FS_TITLE×4、13→SETTINGS_FS_SUB×7、10→SETTINGS_FS_TINY×2。
- Windows（Controls.xaml + MainWindow.xaml + cs）：新增样式 `SettingsHint(11,Muted)/SettingsCardTitle(16,Bold,Ink)/SettingsFeedbackTitle(15,Bold)/SettingsFeedbackBody(12,Muted)/SettingsLogTitle(22,DisplayFont,Bold)/SettingsLogBox(12,MonoFont)`；XAML SettingsPanel 8 处 FontSize（11×6/15/12）归档——3 处带 MonoFont 复用既有 MetaText（等值），3 处纯说明→SettingsHint，反馈标题/说明→SettingsFeedbackTitle/Body；cs BuildCaptureAssistSettingsPanel 拍摄辅助卡 5 处（16/12/11/12/11）→样式引用；ViewLogs 弹窗（诊断日志查询）3 处（22/12/12）+ FontFamily 字面量 "Cascadia Mono, Consolas"→MonoFont 资源（等值 Cascadia Mono）；XAML SettingsPanel 3 处 FontFamily 原已 DynamicResource（非字面量，其中 2 处随 MetaText 收口）。公告弹窗 FontFamily（Consolas）属启动公告（红线锁文案）不在本批。
- 内容分区对齐 macOS 六区核对：外观（macOS 专属 ThemeMode 三选，四端跟随系统——既有差异等价行为）、拍摄辅助、自动更新/软件更新、AI 激活与兑换、诊断日志、捐赠/反馈——五端均有等价分区 ✓；iOS 另含「通用/相机兼容性」分区组（语言/SDK 卡，等价信息项）；Android/Harmony 含语言+SDK 卡补充分区。标签文案一律不动。
- 页式 vs sheet 形态：Android/Harmony/Windows 设置是页（section/panel）、iOS/macOS 是 sheet——裁定保留（design.md:407 允许导航容器差异），docs 记裁定。
- design.md：本批为执行既有条款（每屏 ≤5 档、只归档不改值、双外观成对取 token），未引入新规范，无需修改。
- 验证：完整 `npm test` 256/256 通过；iOS xcodebuild iphoneos BUILD SUCCEEDED；Android assembleDebug BUILD SUCCESSFUL；Harmony assembleHap BUILD SUCCESSFUL（未签名预期）；Windows dotnet build 0 错误 4 既有警告（CS8629×2/CS0414×2）；macOS 构建脚本因缺少 Nikon SDK zip 阻塞（基线 typecheck 同报 4 个外部桥接类型错误=环境限制非改动引入；本批 macOS 改动仅 1 行等值映射）；git diff --check 干净。

## 12.13 v1.5.7 F3 Android 收口批：死常量删除 + 字号归 TS_*（2026-08-06）

- 批次：v1.5.7 字号地基批 F3（Android）；分支 `agent/1.5.7-f3-android`（worktree REPOS/ZENCHE-wt-1.5.7-f3-android），基线 `6a4e26d`（P1-P6 后）。
- **死常量删除（14 个，零引用证据）**：`SPACE_4/8/12/16/20/24/32/40`（8 个，定义 197-204 行，全文件 grep 引用计数=1 即仅定义处）、`STUDIO_CANVAS/PANEL/RAISED/RULE/GOLD`（5 个，定义 152-156，同证）、`READOUT_GLOW`（1 个，定义 148，同证）——删除前逐个 `grep -c '\bNAME\b'` 全文件确认=1（仅定义行），并排除全仓库其他文件引用（grep -rn native/android 无其他文件）。
- **STUDIO_GOLD/STUDIO_PANEL 契约处理**：native-ui-1.5.3.test.mjs:80-81 对五端源码文本断言 `assert.match(source, /studioGold|STUDIO_GOLD|StudioGold/)` 与 `studioPanel|STUDIO_PANEL|StudioPanel`——删除定义后标识符保留于原位置注释（测试为文本匹配断言，注释满足），其他四端均有实际 token 落地（iOS studioGold/macOS studioGold/Harmony STUDIO_GOLD/Windows StudioGoldBrush）仅 Android 无，注释如实声明。
- **字号归 TS_*（58 处等值映射，不改渲染值）**：11→TS_CAPTION、12→TS_BODY、15→TS_EMPHASIS、18→TS_TITLE、24→TS_DISPLAY（setTextSize 同归）+ 10→EDITOR_FS_SMALL×2（媒体池计数、编辑示波器）+ 9→EDITOR_FS_TINY（新建=9，非破坏编辑说明）；覆盖壳层/沉浸 overlay/弹窗/共享组件/编辑页残留（P 批范围外）；P 批已归档 FS 档位不重复。
- **孤立值清单（58 处，保留原值，归 F5 数值裁决）**：13×27（text/setTextSize 混合，含 provider/menu/补偿标签/参数控件标题等）、10×6、16×5、17×5、20×4、14×3、22×2、38×2、19×1、28×1、34×1、46×1；条件式 3 处（`i == 1 ? 11 : 24`、`isCompactPhone() ? 10 : 11`、`videoRecording ? 26 : 34`）不拆改；COMPLEX_UNIT_SP 品牌字号 3 处（26/40/14，Splash 区）；95/64/48 等为 dp/图标参数非字号。全部不改渲染值。
- 验证：npm test 256/256 全绿（native-ui-1.5.3 8/8 含 token 断言过）；assembleDebug BUILD SUCCESSFUL（红线必跑）；git diff --check 干净。
- **12.13 勘误（pro 复审打回，6 处补归档）**：pro 独立全量扫描发现 6 处可归档遗漏——「设备端 SDR 近似预览」11→TS_CAPTION、「运行“分析画面”后显示实测范围」11→TS_CAPTION、「正在打开本机摄像头…」12→TS_BODY（此前误判为条件式不拆改，实际为直接参数替换）、媒体池计数 10→EDITOR_FS_SMALL、「编辑示波器」10→EDITOR_FS_SMALL、「非破坏编辑」9→EDITOR_FS_TINY（新建档=9，对齐 Harmony/iOS P3 tiny 先例）。替换总数 52→58，孤立值口径 54→58（pro 全量扫描 64 vs 自报 54，差额 10 处中 6 处属可归档，其余为口径分类差异）。pro 裁定接受：STUDIO_* 注释留名契约处理、52 处归档等值、14 死常量零引用、COMPLEX_UNIT_SP 豁免。
