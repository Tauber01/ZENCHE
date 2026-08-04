# 帧澈 ZENCHE 任务进度

> 快照时间：2026-08-04（Asia/Shanghai）
> 基线分支：`main`；1.5.2 在独立集成 worktree 收口
> 当前版本：1.5.2 / build 27 本地交付候选；GitHub 最新正式版仍为 v1.5.1
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
- 当前集成源码版本为 **1.5.2 / build 27**，GitHub 最新正式版仍为 **v1.5.1 / build 26**。本轮未推送、未打标签、未创建 Release、未部署生产。四个直接 PTP 平台已恢复并自动核对 20 款 Nikon、12 款 Sony α 与 10 款 Canon EOS R 档案。
- 新增 **AI 修图与生图**：基于 nano-banana 模型的五端 AI 工具、12 个快捷预设、激活码授权（设备绑定、每码 100 次、服务器端计数）。
- `dist/` 中已生成 1.5.0 的 Android APK、HarmonyOS HAP、iOS unsigned IPA、macOS DMG、Windows x64 Setup.exe/ZIP 及 SHA-256；v1.5.0 尚未上传 GitHub 或生产下载服务器。既有官方 v1.4.1 Release 六包仍保留在服务器下载目录。
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

### 4.0 服务器端自动更新系统（本轮）

- **源码**：已实现 `server.mjs` 的 `/api/update`、`/api/updates`、`/healthz`，包含 GitHub Release 资产选择、SHA-256、公告、最低支持版本、版本比较、缓存/stale 回退、ETag、CORS 与安全响应头。
- **五端接入**：iOS、Android、HarmonyOS、macOS、Windows 默认请求 `https://zenche.top/api/update`，校验 `schema_version/product` 后使用结果；不可用时仍按 MirrorChyan → GitHub 回退。
- **测试**：`node --test` 75/75 通过；`git diff --check` 通过。
- **本机交付物**：Android、iOS unsigned、Windows x64 Setup/ZIP 已由本轮源码生成并写入 `dist/`；SHA-256 分别为 Android `d4bcbfc0fa1bac599a739e85879299f1fdb0a34d53535d929f7895d5a569ea7a`、iOS `4e4bfe7d414f8baef44396504f3123ed5f3b919a350f1ed9dd10e0e869254599`、Windows Setup `5ab10ca284f65c71f0328fdad7ca2ca7467112d853ae20b15eb1b39833fc658f`、Windows ZIP `513c6b2820ff28026aa5657057ada4e5752a75b8b8f8d501eba7b6cb0bea8e11`；macOS 仅完成 Swift 编译，因缺少本机 `libexif.12.dylib` 未生成可信本轮 DMG；HarmonyOS 因既有 ArkTS 错误未生成可信本轮 HAP。
- **阻塞**：尚未把服务部署到 `zenche.top` 的生产反向代理；需要服务器 SSH/进程托管/HTTPS 配置权限。Android 构建曾遇到 SDK manifest 网络握手警告但最终成功；iOS unsigned 构建成功。Windows 使用本机 PowerShell/.NET/NSIS 生成未签名安装器与便携包。
- **部署状态**：上述生产反向代理、进程守护、资产上传和服务器本机下载验证已完成；公网 DNS/CDN 切换仍是唯一未闭环项。
- **下一步**：将 `zenche.top` DNS/CDN 指向 `101.34.255.115`，实测公网五端下载 URL、公告、SHA-256、ETag、断网 stale 回退及安装流程。

以下内容来自 2026-08-01 的 `git status` 与 diff，只表示当前本地工作现场，不等同于已经提交或发布：

### 4.1 AI 功能（已提交并发布）

- AI 修图与生图、12 个快捷预设、激活码授权、代理服务器架构已完成，已在 `claude/modest-albattani-34402d` 分支提交（35 文件，+2627/-110）并推送。
- 四端（macOS/iOS/Android/HarmonyOS）1.3.0 产物已上传 GitHub Release `v1.3.0`。
- Windows 1.3.0 EXE 安装包待 Windows 主机生成。
- 分支尚未合并回 `main`。

### 4.2 相机兼容与测试调整

- Android、HarmonyOS、iOS、Windows 的相机或 PTP 相关文件存在未提交修改。
- `test/camera-profiles.test.mjs` 与 `test/localization.test.mjs` 已修改，当前 37 项测试全部通过。
- 修改目的需以最终 diff 为准；提交前必须确认没有误删机型档案、错误缩小参数范围或破坏设备 fallback。

### 4.3 设计与宣传素材

- `design.md`、`PV/README.md`、PV V2 构建/预览脚本和 AI 图片素材存在修改或未跟踪文件。
- 这些素材不属于原生应用交付包，但发布前应确认品牌标识、标准标语、版权和输出清单。

### 4.4 工作区卫生

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

- 五端原生监看页同步调整：录制键位于 RGB 三色波形与音频波形之间；移除监看镜头读数；移除监看工具中的“曝光”入口；保留并显式开放帧率、快门角度、ISO，以及光圈/白平衡等可调参数。
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

## 12.2 v1.5.2 连接、AI 服务与设备码迁移候选（2026-08-04）

- Git 身份已按仓库本地配置固定为 `Tauber <2642079880@qq.com>`；UI 基线提交 `be8290b`，core 可靠性基线提交 `668bfe4`，均含相同的 `Co-authored-by` 与 `Signed-off-by` trailer，尚未推送。
- Android USB/PTP 只对四类已知异步失败启用 `UsbRequest → bulkTransfer` 降级；首次同步降级成功后本会话粘滞走同步传输，重连与关闭重置，其他错误不吞掉。
- `ai-server/app.mjs` 是仓库内零依赖候选代理：默认回环监听，真实 generate→poll→download 链路有流式大小上限，参考图先校验再扣次，失败退款；计数写盘使用文件与目录双 fsync、三态恢复和存储异常 fail-stop。
- Tauber 在 Buzz 事件 `ea6ca27e…d525c` 明确允许“旧激活码 + 当前绑定旧设备码”迁移。服务端候选 `POST /v1/ai/rebind` 默认关闭，迁移时先通过回环 redeem 签发新码并本地验签，再单次耐久事务继承 `used`/`expiry`、冻结旧记录；支持幂等、链式迁移、目标占用保护、IP/激活码指纹限流、脱敏审计、AI in-flight 计数和换绑写锁。
- 回环 redeem `/issue-migrated` 签发端、五端恢复 UI、旧码预验签、新码二次验签及本地耐久替换已并入集成分支；恢复端点固定为 HTTPS。Nginx 精确反代、DNS 切换、关闭公网 8787、生产秘密注入、灰度与回滚仍未实施，没有生产服务器改动。
- 自动化基线：core `87cb78c` 为 `225/225`；redeem `3745eda` 为 `237/237`；五端客户端切片在 UI 分支为 `138/138`。独立审查 `87cb78c` 无 P0，发现的唯一 P1 是迁移链尾退款缺少测试；集成分支已补等价的 in-flight 退款与链尾解析覆盖，合并态完整 `npm test` 为 **248/248** 通过。
- 发布状态：已集成并升到 1.5.2 / build 27，正在同步三语文档和生成五端本地候选包。尚未上传 GitHub、未打 `v1.5.2` 标签、未创建 Release、未部署生产；签名、Windows 主机、相机真机等门禁必须随交付包精确披露。
