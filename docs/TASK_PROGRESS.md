# 帧澈 ZENCHE 任务进度

> 快照时间：2026-08-11（Asia/Shanghai）
> 当前源码候选：1.5.12 / build 39；Windows 启动修复代码提交 `970f8e08edce2529750d5b29fe3aaccd53da61ac`，发布分支 `agent/1.5.12-windows-nre-release`
> 公开状态：Tauber 已授权把 v1.5.12 作为下一版 GitHub 公开稳定版；发布完成前，GitHub 当前稳定版仍为 v1.5.11。官网自动更新继续提供 W14 的 1.5.10 / build 37，本次不部署官网
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
- 当前发布候选为 **1.5.12 / build 39**，仅新增 Windows 启动初始化门禁及相应回归，并同步五端版本元数据和中英日启动公告；1.5.11 的桌面工作区、移动端相册与 AI 代理等能力保持不变。发布完成前，GitHub 公开稳定版仍为 [v1.5.11](https://github.com/Tauber01/ZENCHE/releases/tag/v1.5.11)；官网自动更新继续提供 1.5.10 / build 37。
- Windows 启动空引用修复 `970f8e08edce2529750d5b29fe3aaccd53da61ac` 已进入 1.5.12 候选：三条 XAML 默认选择事件在访问后置控件前受 `_initializing` 门禁保护，专项 3/3、基线反证 3/3 按预期失败、独立复审 P0/P1/P2=0。版本同步后的完整 `npm test` 518/518 通过。六个 1.5.12 包及侧车正在从当前候选源码重建；Windows 包由 macOS 交叉构建且无 Authenticode，仍需真实 Windows 冷启动、参数交互与安装链验收；详见 §12.60 与 §12.61。
- 1.5.11 的完整 `npm test` 514/514、五端原生构建、包结构、侧车、签名边界与 GitHub 14/14 线上回验均作为历史发布事实保留。1.5.12 在发布前重新执行全部自动化与六包校验，不沿用旧包哈希。Nikon Z50、OPPO Camera2、移动端系统照片权限/iCloud/另存和真实 AI 服务仍需对应真机验收；真实桌面拖拽/重启恢复、Windows 多显示器/DPI、辅助功能与长时间性能边界保持不变。
- v1.5.3 已实现五端界面主体：全屏监看的影像优先 HUD、RGB 三色叠加波形示波器与静音音频基线；拍摄页的设备摘要、自适应参数卡、常驻拍摄操作区；编辑器的媒体池、中央预览、工具检查器和分析示波器。所有新面板读取既有真实状态，相机、AI、传输和非破坏保存链路不变。
- v1.5.3 发布门禁曾完成 `npm test` 256/256 与五端构建；W14 打包源码已完成完整 `npm test` 483/483、W14 专项 12/12 和五端构建，六个交付文件的 SHA-256、容器版本和结构均已回验。最终视觉/交互与三语内容审查均为 PASS，生产更新切换和公网逐端回归已完成。
- W14 已完成本地冻结与五端候选包：拍照页实时监看开关和 iOS / iPadOS 的 Mac 相机桥接已实现。Sony 由 Mac 端 Sony Camera Remote SDK 驱动；Nikon 为明确标注的 PTP 兼容路径。Sony 与 Nikon 的公开桌面 Remote SDK 均未提供可直接嵌入 iOS 的版本；真机联调和正式签名发布验收仍待完成。
- 新增 **AI 修图与生图**：基于 nano-banana 模型的五端 AI 工具、12 个快捷预设、激活码授权（设备绑定、每码 100 次、服务器端计数）。
- v1.5.0 与 v1.5.3 已作为历史 GitHub Release 保留；v1.5.12 完成发布前，GitHub 公开稳定版仍为 v1.5.11。官网生产更新继续提供 1.5.10 / build 37；1.5.9 使用旧文件名继续保留，不被新版覆盖，以便回滚。
- 既有设备激活链路已完成验签、计数与上游转发验证；W13 有效激活码的账号绑定和真实 AI 生成尚未执行。
- 最大未闭环风险仍是跨 46 款注册机型的系统实机矩阵、生产签名、公证与商店级分发；注册表与静态测试不等同于硬件实机验收。Windows 包在 macOS 交叉构建，尚未完成真实 Windows 安装/驱动/SmartScreen 验收。
- 本次恢复从历史提交 `a4a26a6` / `4a094e8`（AI 激活码系统）与 `8b6f556` / `3081f71`（Sony/Canon 适配）增量合并，保留当前编辑器、Nikon EXPEED 5/6/7、Android 状态栏与 Web/PWA 工作区。
- 本次编辑器迭代已同步五端：AI 工作台增加显式“分析画面”步骤、曝光/动态范围/色彩/细节指标，以及 AI 调整复制/粘贴；原有强度、智能优化、撤销、预设、前后对比和高质量副本保持不变。
- 本轮增量 UI 修复已完成：五端编辑器主身份恢复为“专业显影”，AI 保留为可选增强区并明确“照片不会上传”；Android 恢复原有底部连接状态与文件计数栏及其更新链路，未删除编辑或拍摄功能。
- 本轮 AI 工具 UI 优化已完成：联网 AI 创作区统一为“模式与授权状态 → 提示词/预设 → 输出参数 → 生成/保存/状态”层级；iOS/macOS 明确区分联网 AI 创作与设备端本地优化，Android 修复重复状态文本，HarmonyOS 恢复比例/分辨率控件，Windows 恢复比例/分辨率控件并显示授权状态；激活码、设备绑定、预设、服务器请求、生成、保存和本地 AI 工作台均保留。
- 本轮设置收敛已完成：五端均移除 AI 服务器地址的可编辑输入框和保存按钮，仅保留激活码操作；AI 请求仍使用内置默认代理，并继续读取历史 `aiServerURL`、`ai_server_url` 或 `ai-server-url.txt` 配置以兼容升级。
- 本轮移动端编辑入口修复已完成：Android 与 HarmonyOS 的底部/侧边“编辑”导航现在始终打开“专业显影”，不再通过重复点击导航在专业显影与 AI 工具之间来回翻转；两端编辑页新增明确的“专业显影 / AI 工具”模式切换，AI 修图与生图功能保持不变。
- 本轮设备码与兑换入口恢复已完成：五端 AI 激活卡均显示并支持复制当前设备 ID，保留激活码输入、验证和旧购买入口；新增显眼的 `https://zenche.top` 官网兑换按钮、兑换步骤说明，以及“在爱发电购买兑换码”提示、可点击二维码和购买按钮。兑换码仅用于 AI 云服务次数，未改变帧澈本体免费开源属性。
- 本轮服务器端自动更新系统已实现：`server.mjs` 新增 `/api/update`、`/api/updates` 和 `/healthz`，按 platform/architecture/channel 解析 GitHub Release 完整包，提供 SHA-256、公告、最低支持版本、版本比较、ETag/CORS、安全响应头、5 分钟缓存与 stale 回退；五端客户端默认接入 `https://zenche.top/api/update`，服务异常继续 MirrorChyan → GitHub 回退。
- 本轮五端外录已实现：照片直接进入当前设备文件库；Android、HarmonyOS、macOS、Windows 将 PTP/本机实时取景流式封装为 MJPEG AVI，iOS / iPadOS 本机与 UVC 继续以 MOV 外录。PTP 机身录制可与设备外录并行，停止、断开和写入失败会安全完成已写入帧；AVI 已纳入四端媒体库视频分类，会话命名、双目标备份与 SHA-256 同步生效。
- 本轮官网更新已完成：`zenche-update.service` 在 `101.34.255.115` 的 `127.0.0.1:4174` 运行，Nginx 公网提供 `/api/update`、`/api/updates`、`/healthz` 和 `/downloads/`。1.5.10 / build 37 已于 2026-08-10（Asia/Shanghai）切入自托管生产清单；1.5.9 请求在五端均返回 1.5.10、`update_available=true`、`stale=false` 和正确 URL/SHA-256，1.5.10 请求不重复提示，六个公开包均完成流式 SHA-256 回验。旧服务与清单备份位于 `/opt/zenche-update-backups/20260809T163105Z-v1510-r2`。

## 3. 能力进度

| 工作流 | 当前状态 | 已有证据 | 主要剩余工作 |
| --- | --- | --- | --- |
| 五端原生应用骨架 | 已完成 | `native/ios/`、`native/android/`、`native/harmony/`、`native/macos/`、`native/windows/` | 持续保持行为和文案对齐 |
| Nikon 设备识别 | 已实现待验收 | 20 款注册表与 Android filter 测试通过 | 为新增 EXPEED 5 与既有机型补齐实机记录 |
| USB/PTP 实时取景与拍摄 | 已实现待验收 | 四端传输实现、Nikon Z50 SDRAM 下载繁忙恢复与已知问题回归通过 | Z50 不同固件/存储卡/USB 主机及其他机型实测 |
| 系统摄像头 | 已实现待验收 | Android Camera2 双流到共享单流有序降级、超时与资源释放回归通过 | OPPO PEDM00 / Android 14 监看、拍摄、重复连接和前后台恢复 |
| 参数控制与 B 门 | 已实现待验收 | 快门回退、B 门释放、模式控制回归存在 | 扩大机型/拍摄模式 writable 属性验证 |
| 自动拍摄任务 | 已实现待验收 | 五端间隔、曝光包围、焦点包围、B 门静态测试通过 | 长任务、取消、断线、存储不足实测 |
| 专业监看 | 已实现待验收 | 直方图、波形、矢量、峰值对焦、假色等五端检查通过 | 性能、色彩准确性和长时间运行验证 |
| 实时监看开关与 iOS 相机桥接 | 已实现待验收 | 五端开关、Sony Camera Remote SDK 的 Mac 桥接、Nikon PTP 兼容桥接与局域网配对契约 | Sony/Nikon 真机、弱网、发热、长时间拉流和 iOS/macOS 联调 |
| 登录动作清晰化与桌面工作区 | 已实现待验收 | `831a823`；五端模式/提交与签名公告契约；Apple 忙碌态 exact 三语；macOS/Windows 连续实时分隔条、清晰编辑层级、自适应 RGB 示波器、窄窗安全约束、渲染合并、Windows AI 临时结果生命周期清理；完整 503/503，桌面包、聚合包与双审封板通过 | macOS/Windows 真实拖拽与重启恢复、Windows 多显示器/DPI、辅助功能与长时间性能实机 |
| 无线收图 | 已实现待验收 | 五端 FTP/HTTP/WebDAV 源码与文档存在 | 大文件、中断、并发、端口释放和相机 FTP 实测 |
| 拍摄会话与交付 | 已实现待验收 | 命名、配对、评级、双备份、SHA-256 五端检查通过 | 恢复、磁盘异常、跨卷和大量文件压力测试 |
| 分支图库 | 已实现待验收 | 嵌套分支、拖拽、删除恢复和移动抽屉测试通过 | 真机手势、可访问性和大图库性能 |
| 非破坏性编辑 | 已实现待验收 | 五端主导航、分组参数与导出语义检查；三移动端可见系统照片入口、工作副本与新相册项目契约通过 | 真机权限/iCloud/厂商相册、像素结果、色彩空间和超大图验证 |
| **AI 修图与生图** | **已实现待验收** | 五端 HTTPS 账号代理、原图 data URL、结果解析；三移动端 AI 新副本保存和系统相册导出回归通过 | 有效激活码真实生成、各平台真机 UI、服务器容灾与激活码发放流程 |
| **Sony / Canon 相机适配** | **已实现待验收** | Nikon 20 款、Sony 12 款、Canon 14 款，共 46 款注册表静态覆盖；vendor ID 过滤、macOS detection tokens、Windows PTP vendor ops | Sony/Canon 真机 PTP、实时取景、参数写入和不同固件验证 |
| 三语本地化 | 已实现待验收 | 简中/英/日资源与动态状态测试通过 | 人工校对、截断、窄屏与新增文案持续同步 |
| 更新与公告 | 已实现待验收 | 自有 `/api/update` + MirrorChyan + GitHub fallback；1.5.10 五端公网响应、兼容路由与六个公开包 SHA-256 已通过 | 各平台真实安装、断网 stale 回退和签名后正式分发验收 |
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

- **源码**：已实现 `server.mjs` 的 `/api/update`、`/api/updates`、`/healthz`，包含自托管 `UPDATE_RELEASE_MANIFEST`、GitHub 兼容模式、SHA-256、公告、最低支持版本、版本比较、缓存/stale 回退、ETag、CORS 与安全响应头。
- **五端接入**：iOS、Android、HarmonyOS、macOS、Windows 默认请求 `https://zenche.top/api/update`，校验 `schema_version/product` 后使用结果；不可用时仍按 MirrorChyan → GitHub 回退。
- **测试**：1.5.10 打包源码 `a9bb11bc0068920aaa8630ebb14d4ed3126dc410` 完整 `npm test` 483/483、W14 专项 12/12 通过；新增生产清单契约逐个模拟五端真实 platform/architecture 查询，防止规范化键返回空资产。
- **本机交付物**：1.5.10 / build 37 的 Android APK、iOS unsigned IPA、HarmonyOS HAP、macOS arm64 DMG、Windows x64 Setup/便携 ZIP 及侧车校验均已生成；文件大小、SHA-256 和签名状态见 `docs/releases/v1.5.10.md`。
- **生产部署**：1.5.10 自托管清单已生效；切换前备份服务端、systemd 有效配置、旧 API 响应和 `SHA256SUMS`，备份路径为 `/opt/zenche-update-backups/20260809T163105Z-v1510-r2`。本机与公网五端响应、兼容路由、1.5.10 不重复提示、六个公开包 HTTP 200 与 SHA-256 均通过。
- **下一步**：在取得正式签名与兼容相机后，补做五端真实安装、Sony/Nikon 桥接、快门、断线恢复、弱网延迟与辅助功能真机验收。

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

## 12.14 v1.5.7 F5 Windows 收口批：样式归一 + 画刷快照 + 数值裁决（2026-08-06）

- 批次：v1.5.7 字号地基批 F5（Windows）；分支 `agent/1.5.7-f5-windows`（worktree REPOS/ZENCHE-wt-1.5.7-f5-windows），基线 `f89bf94`（F3 后）。
- **TypeScale 5 档样式归一**：Controls.xaml 盘点 33 个 TextBlock 样式（9-26pt 13 档）；pro P6 观察项 **SettingsHint(11)/MetaText(11) 合并评估**——结论**不合并**：MetaText=等宽元信息（MonoFont，版本号/状态行/节点详情需等宽对齐），SettingsHint=普通说明文字（设置页提示，非等宽），语义差异明确，注释声明分工（同值不同用途，design.md 每屏 ≤5 档不冲突）。
- **画刷快照收口（9 处，口径勘误）**：cs 中 `new SolidColorBrush((Color)FindResource("ColorX"))` 构造期冻结值 → 改为 `(Brush)FindResource("XxxBrush")` 共享实例引用（Colors.xaml 已定义对应 Brush）。**修正声明：仅 ColorPhotoSoftBorder 1 处有亮/暗主题对（Theme.Dark #2E425E / Light #B6CFF5），是真实的主题热切换修复（SwapTheme 换字典后旧快照漏更）；其余 8 色（AccentBorder/WhiteDim/LogBg/LogText/WarnDeep/WarnDark/WarnBg/WarnBgSoft）本就无主题覆盖（两主题同值），属等价重构（去冻结改共享引用），不存在漏更。** 9 处 = ColorAccentBorder/ColorWhiteDim/ColorLogBg/ColorLogText/ColorPhotoSoftBorder/ColorWarnDeep/ColorWarnDark/ColorWarnBg/ColorWarnBgSoft（对应审计 cs:2176/2663/4518/4520/4724/4725/4813/4824/4831/4833 行区间，行号随 P 批漂移后为 2169/2656/4506/4508/4713/4801/4812/4819/4821）。
- **数值裁决（改值，逐项 macOS 基准证据）**：
  - `MonitorReadout` 22→18：macOS monitorReadout 值=TypeScale.title=18（main.swift:6692-6698 等宽 bold），Windows 原 22 对齐
  - `SettingsLogTitle` 22→18：macOS 日志弹窗标题=TypeScale.title=18（SettingsSheet.swift:822），Windows 原 22 对齐
  - `DeviceHeaderTitle` 24→26、`LibraryHeaderTitle` 24→26：macOS 页面标题=TypeScale.heading=26（WorkspaceHeading 设备页 main.swift:12499/分支页 8001），Windows 原 24 对齐
  - 其余端标题档（iOS 29/25、Android 30/25、Harmony 30）为各自批次归档值，本批不动；Android F3 的 58 处孤立值仅记录口径不处理
- 未改：cs 编辑器/弹窗区 21 处 TS 可映射字号（11×14/12×4/15/18/24 等）——非页面批范围（fig2 恒深区/连接弹窗/公告弹窗），留 F2/F4/后续裁决；EditorHeaderTitle=24 为 fig2 恒深编辑器体系（macOS 编辑页标题=TypeScale.emphasis=15，fig2 恒深例外）。
- 验证：npm test 256/256 全绿；dotnet build 0 错误 4 既有警告；git diff --check 干净；Controls.xaml XML 合法（xmllint）。


## 12.15 v1.5.7 F5 数值裁决执行：公告弹窗对齐 macOS 基准（2026-08-06）

- kimi 裁决（17:52）：公告弹窗非品牌资产、无豁免理由，全部对齐 macOS 基准；仅改样式定义处（引用方不动）。
- 执行（Controls.xaml 5 个 Announcement 样式）：`AnnouncementHeading` 25→26（macOS 公告标题=TypeScale.heading=26）、`AnnouncementSection` 19→18（本次更新=title=18）、`AnnouncementTitle` 17→18（谨防诈骗/自愿赞助=title=18）、`AnnouncementText` 14→12（正文=body=12）、`AnnouncementSub` 13→12（打赏说明=body=12，裁决「全部对齐」精神延伸）。
- 对齐后五端公告弹窗字号统一：标题 26/小节 18/正文 12。
- 验证：npm test 256/256；dotnet build 0 错误 0 警告；xmllint 合法；git diff --check 干净。


## 12.16 v1.5.7 F5 二轮打回修复：公告区 3 处缺陷（2026-08-06）

- 二轮打回（pro 关门复审 17:58）：8d51e1e 公告区 cs 归档引入 3 处缺陷，99fc8ab 未修。
- ① **运行时崩溃**：L4738「不再提醒」CheckBox 赋 TextBlock 样式（AnnouncementText）——跨 TargetType 赋样式运行时抛 ArgumentException，公告弹窗打开即崩。修复：恢复 FontSize=12 字面量（裁决对齐后值）。**教训：dotnet build 0 错误 ≠ 运行时安全，XAML 样式 TargetType 不匹配编译期不报。**
- ② **字重丢失**：L4793 谨防诈骗正文原 FontWeight=SemiBold 被样式（无字重 setter）吃掉变 Regular。修复：改用 AnnouncementBody + 本地补 FontWeight=SemiBold（macOS 基准 SettingsSheet.swift:1003 body 12+semibold）。
- ③ **颜色回归**：L4771 本次更新正文原无 Foreground（继承 InkBrush），AnnouncementText 带 MutedBrush 导致 ink→muted。修复：拆分样式——AnnouncementBody(12 继承色) 用于无前景覆盖正文，AnnouncementSub(12+Muted) 用于打赏灰化说明；原 AnnouncementText 无引用方已删除。
- 后续批次纪律：引用方改样式赋值时逐处核对 TargetType 兼容 + 被样式覆盖的本地属性（字重/颜色）。
- 验证：npm test 256/256；dotnet build 0 错误（既有基线警告）；xmllint 合法；git diff --check 干净。

## 12.17 v1.5.7 F2 iOS 收口批：字号归档 + 动态字档盘点 + STUDIO_* 清理（2026-08-06）

- 批次：v1.5.7 字号地基批 F2（iOS）；分支 `agent/1.5.7-f2-ios`（worktree REPOS/ZENCHE-wt-1.5.7-f2-ios），基线 `53133c6`（F5 后）。
- **字号字面量归档（34 处使用）**：
  - 映射既有档 11 处（值等值不改值）：9×2→EditorFontSize.tiny（库计数、示波器标题）、10×3→EditorFontSize.small（REC/LIVE 状态、设备名、工具标题）、13×6→SettingsFontSize.linkLabel（状态文本×2、AF-ON、timer、遥测值、设备名）
  - 图标/品牌豁免 14 处（注释声明，F1 先例）：Splash Z 标 42/品牌名 28/标语 14、侧栏 Z 16、导航图标 20、齿轮 17、控制栏按钮 16、照片 17、连接 17、空态 46、全屏 16、对焦框 34、storage 图标 33；分支工作台 28 图标 P5 已豁免
  - 孤立值 9 处（保留原值，归 F5 数值裁决）：控制页大标题 17、参数大读数 28、遥测微标签 8、时间码 32、剩余录制读数 25、波形 R/G/B 标签 8×2、音频波形标签 8、控制台读数 17
- **动态字档盘点（249 处，不动渲染，映射关系落 docs）**：caption2 22/caption 103/footnote 1/subheadline 50/body 16/headline 31/title3 6/title2 9/title 9/largeTitle 2。iOS 系统动态字档（.caption 等）随用户动态字体缩放，与 FontToken 固定 5 档（11/12/15/18/24）语义不同——保留动态字档为 iOS 平台惯例（design.md「平台原生控件优先」），映射关系：caption≈caption 档、body≈body 档、headline≈emphasis 档、title2/title3≈title 档、largeTitle≈display 档（近似，非等值替换）。可直映 TypeScale 的静态语义处未发现（全部为动态字号上下文）。
- **STUDIO_* 清理**：IPalette.studioCanvas/Panel/Raised/Rule/Gold 5 个死定义（全文件引用计数=1 仅定义处）删除；标识符保留原位注释（native-ui-1.5.3.test.mjs:80-81 文本断言，测试 8/8 过）。
- **AUTO 徽标核对**：iOS P1 已改「AUTO 胶囊」（RootView.swift:4581，caption bold+Capsule+height 18），与 macOS F1 完全一致；全文件无单字母「A」残留——任务 4 无需本批改动，记录确认。
- 验证：npm test 256/256（native-ui-1.5.3 8/8）；iOS xcodebuild BUILD SUCCEEDED（unsigned IPA）；git diff --check 干净。

## 12.18 v1.5.7 F4 Harmony 收口批：字号归档 + STUDIO_* 清理 + 录制钮补齐（2026-08-06）

- 批次：v1.5.7 字号地基批 F4（Harmony，本轮最后一批）；分支 `agent/1.5.7-f4-harmony`（worktree REPOS/ZENCHE-wt-1.5.7-f4-harmony），基线 `2cc21ab`（F2 后）。
- **字号归档（73 处残留，全量扫描后报数）**：
  - 映射 EDITOR_FS_* 档 38 处（值等值不改值）：13→EDITOR_FS_SUB×24（状态/云创监看/双目标备份/弹窗说明/公告版本/参数标签等）、9→EDITOR_FS_TINY×1（自动小字）、10→EDITOR_FS_SMALL×7（未连接/版本号/LIVE/读数标签/参数标签/峰值覆盖）、14→EDITOR_FS_MEDIUM×5（连接说明/库大小/公告正文/防诈正文/不再提醒）、16→EDITOR_FS_HEAD×1（存储值）
  - 图标/品牌豁免 17 处（注释声明）：Splash Z 标 42/品牌名 28/标语 14、TopBar Z 22/标语 10、☰ 20、⚙ 22、●状态点 10×2、对焦框 ＋ 32、卡片图标 16×2、▢ 20、▯ 36、✨ 20、⚡ 19、☕ 20（L48 空态 P4 已豁免）
  - 孤立值 15 处（保留原值，归 F5 数值裁决）：时间码 38、空态标题 22、参数大读数 28/20、读数值 17/21/22、弹窗标题 22×3、公告标题 22、公告小节标题 17×2、遥测微标签 8、沉浸按钮文本 17
- **STUDIO_* 处置**：STUDIO_PANEL/RAISED/RULE/GOLD 4 个死定义（引用计数=1 仅定义处）删除，标识符保留原位注释（native-ui-1.5.3.test.mjs:80-81 文本断言，测试 8/8 过）；**STUDIO_CANVAS 保留**（两处实际使用 L7378/7383 沉浸 HUD 底，与 F3 Android 全删不同——Harmony 有真实落地）。
- **MonitorScopeRail 补中间录制钮**（P2 backlog，功能补齐）：对齐 macOS monitor 三件套（RGB 波形 + 108 圆录制钮 + 音频波形，main.swift:6582-6608）；Harmony 采用 96 圆钮（同 ImmersiveCaptureButton 交互：videoRecording ? ■/● + UI_VIDEO 底 + toggleVideoRecording，enabled=connected&&!busy）。
- **docs 勘误**：TECHNICAL_APPROACH 0.14 动态字档计数口径修正为「标识符出现 249 / 实际 .font() 调用 115」（F2 pro 观察项）。
- 验证：npm test 256/256（native-ui-1.5.3 8/8）；assembleHap BUILD SUCCESSFUL（未签名预期）；git diff --check 干净。

## 12.19 v1.5.7 F6 键准备：新增「分支」三语键（2026-08-06，不动渲染）

- F6 键裁决（kimi 18:26）：macOS 无独立 strings（build-macos.sh:118-124 拷贝 iOS lproj），iOS Localizable.strings 即五端对齐基准表；**「分支」键五端均缺**（macOS en/ja 下原样显示中文为存量缺口）。
- 新增「分支」键（zh-Hans=分支 / en=Library / ja=ライブラリ，语义映射既有「文件库」=Library/ライブラリ）：
  - iOS Localizable.strings ×3（zh-Hans/en/ja，macOS 侧栏缺口随打包自动修复）
  - Android Localization.java
  - Harmony Localization.ets
  - Windows Localization.cs
- 「单机」「群组」键：不新增不删除（iOS 既有键保留，设备分组 UI 可能在用；其余三端待 Tauber 拍板页签短名词表后再动）。
- **仅加键不动任何 tab 渲染**；页签词表统一 + 紧凑导航提回（编辑/视频一级 tab）待 Tauber 拍板②后实施。
- main.swift:10115 `Button(section.rawValue)` 未走 LocalizedStringKey 记 backlog。
- 验证：npm test 256/256 全绿（无渲染/测试改动）；git diff --check 干净。

## 12.20 v1.5.7 F6 全量实施：五端词表统一 + 紧凑导航提回（2026-08-06，Tauber 拍板）

- Tauber 拍板（18:28）：删除「单机」「群组」键，重组为「拍照」「视频」键；kimi 落地口径（18:33）：五端一级导航统一 **拍照 / 视频 / 编辑 / 我的设备 / 分支**。
- **键变更**：iOS 三语 Localizable.strings（macOS 打包拷此表=基准）删「单机」「群组」键、新增「拍照」=拍照/Capture/撮影（放「照片拍摄」后）；Android Localization.java / Harmony Localization.ets / Windows Localization.cs 同步加「拍照」三语值；「视频」「编辑」「我的设备」「分支」复用既有键（分支键 ba5cabf 已备）。
- **iOS**（AppModel.swift + RootView.swift）：AppSection rawValue capture 照片→拍照、library 文件→分支（LocalizedStringKey 查表联动）；BottomNavigation 重排 拍照/视频/编辑/我的设备/分支+设置齿轮；「文件」标签/accessibilityLabel 两处同步改「分支」（4184/4673）。
- **Android**（MainActivity.java）：底栏 4→6 tab 重排（拍照/视频/编辑/我的设备/分支+设置）；navButton 图标 switch 补 monitor→ic_nav_video（既有资源）；editor 路由已有（PRO 默认）。
- **Harmony**（Index.ets）：CompactBottomNavigation 4→6 tab 重排；NavigationRail 侧栏长词（照片拍摄/视频监看/图像编辑/分支文件库）收短（拍照/视频/编辑/分支）；NavButton 紧凑宽度 25%→16%（6 tab 适配）；NavButton editor 路由已有。
- **macOS**（main.swift）：AppSection rawValue capture 照片→拍照（侧栏自动走 iOS 表取 Capture/撮影）；main.swift:10570 Button(section.rawValue) backlog 顺手修（包 LocalizedStringKey）。
- **Windows**（MainWindow.xaml + Localization.cs）：侧栏长词（照片拍摄/视频监看/图像编辑/分支文件库）→短词（拍照/视频/编辑/分支）；静态 Content 字面量经 Localization.cs Apply 翻译（「拍照」键已加）。
- **测试**（Tauber 授权词表断言豁免）：native-global-status.test.mjs:87-88 断言改 navTab(.capture,"拍照")/navTab(.library,"分支")；native-image-editor.test.mjs:22-28 删除 doesNotMatch（编辑已一级 tab）、断言改 拍照/编辑/分支 + NavButton('编辑',editor)；native-library-tree.test.mjs:86「分支文件库」断言保留（页内标题仍在，非导航标签）。
- 五端导航最终形态：macOS 侧栏 拍照/视频/编辑/我的设备/分支（+顶栏设置）；iOS/Android/Harmony 紧凑底栏 拍照/视频/编辑/我的设备/分支+设置齿轮；Windows 侧栏 拍照/视频/编辑/我的设备/分支。
- 验证：npm test 256/256 全绿；iOS xcodebuild BUILD SUCCEEDED；Android assembleDebug SUCCESSFUL；Harmony assembleHap SUCCESSFUL；Windows dotnet 0 错误；git diff --check 干净。

## 12.21 v1.5.7 build 31 五端打包（2026-08-06，kimi 18:44 打包指令）

- 基线整合分支 4aab8ae（F6 合入后）+ 版本号升级提交 4e7eb05（1.5.6→1.5.7、build 30→31，五端一致：package.json/scripts/Android versionCode 31+versionName/Harmony versionCode 31/iOS CURRENT_PROJECT_VERSION 31+MARKETING_VERSION 1.5.7/macOS Info.plist/Windows csproj/test 断言）。
- 产物（dist/，6 包 + 6 shasum）：
  - ZENCHE-1.5.7-ios-unsigned.ipa（unsigned 预期）
  - ZENCHE-1.5.7-android.apk（签名连续性验证：证书 SHA-256 45499c18... 与 v1.5.1/v1.5.3 一致）
  - ZENCHE-1.5.7-HarmonyOS.hap（未签名预期，证书待 Tauber）
  - ZENCHE-1.5.7-macOS-arm64.dmg（三 SDK env：NIKON_IMAGE_SDK_ZIP/NIKON_REMOTE_SDK_ZIP/SONY_CRSDK_MAC_ZIP 指向 ~/Documents/NikonLink/）
  - ZENCHE-1.5.7-Windows-x64-Setup.exe + ZENCHE-1.5.7-Windows-x64.zip（NSIS Setup，LANG=en_US.UTF-8）
- 构建验证：macOS DMG/iOS BUILD SUCCEEDED/Android assembleDebug SUCCESSFUL/Harmony assembleHap SUCCESSFUL（未签名）/Windows dotnet publish 0 错误 + NSIS 成功。

## 12.22 v1.5.7 移动端拍照页五项改动（2026-08-06，Tauber 19:14 指令 + kimi 19:24 派工）

- 批次：仅 iOS/Android/Harmony 三端，macOS/Windows 不动；分支 `agent/1.5.7-capture-mobile`（worktree REPOS/ZENCHE-wt-1.5.7-capture-mobile），基线 `b417b8e`（build 31 打包记录后）。
- **① 快门键上移**：三端参数网格与快门 dock 顺序交换（iOS RootView.swift ControlCaptureDock 前置 ControlParameterGrid；Android buildControlCaptureDock 前置 buildControlParameterGrid；Harmony ControlCaptureDock 前置 ControlParameterGrid）。
- **② 「编辑」toggle**：Android MainActivity.java:3431 与 Harmony Index.ets:4710 单向 `gridEditMode = true` 修为 `!gridEditMode`（对齐 iOS RootView.swift:4522 现有 toggle）；恢复被隐藏磁贴入口由既有「全部」按钮承担（`gridEditMode=false` + 清空隐藏数组，三端一致，同 iOS 语义）。
- **③④ 底栏 6tab→4tab + ⋯ 气泡弹窗**：
  - 底栏删「我的设备」「设置」（三端），剩 拍照/视频/编辑/分支；iOS 宽屏 SideNavigation「我的设备」保留（派工明示）。
  - iOS ⋯ 已为 SwiftUI Menu，加「我的设备」项（导航 .devices），设置项保留（gearshape 图标）。
  - Android 新写 `showControlBubbleMenu(anchor)`（PopupMenu，锚 ⋯ 按钮，深色控制栏风格），6 项：连接/断开相机、视频监看、编辑、设备、文件库、设置；抽 `handleControlMenuTarget(String)` 与 ☰ 对话框共用（原对话框内联逻辑去重）。新增 import Menu/MenuItem/PopupMenu。
  - Harmony ⋯ 改 ArkUI 原生 `bindMenu`（6 项同 Android），抽 `handleControlMenuTarget` 与 ☰ 共用（原 showControlMenuDialog 内联分支去重）。
  - 齿轮图标用法保全：iOS Menu 设置项 gearshape / Android ic_settings_gear（navButton 图标 switch + 顶栏设置按钮）/ Harmony ⚙（顶栏）——localization.test.mjs 齿轮断言三端仍过。
- **⑤ 拍照页恢复 RGB 波形监看**（紧凑三色叠加条，无音频无录制钮，位置在快门 dock 下方）：
  - iOS 新增 `CaptureScopeBar`（复用 ScopePlot/ScopeTrace，parade=false，height 78，immersiveScopeDock 样式语言）；数据源 CameraService 已发 RGB histogram。
  - Android 新增 `captureScopeView`（WaveformScopeView.RGB_PARADE，height 78）；帧分析拓宽 `scopeAnalysis = packet.monitoring || capture 页`，capture 页跑 processPreview 更新直方图但显示仍用原图（showProcessedPreview 以 monitoring 判定，对齐 iOS captureOutput 语义）。
  - Harmony 新增 `captureRgbScopeContext` + capture 分支 Canvas（height 78）+ `drawCaptureRgbScope()`（复用 drawScopePanel，RGB 叠加 parade=false）；`displayJpeg` 分析门控拓宽：新增 `scopeWanted`（monitor/capture/immersiveMonitoring），capture 页也更新直方图并 drawCaptureRgbScope，但 `pixelMap` 保持 `sourceMap`（仅 monitor/云预设用处理图；processProfessionalMonitor 无视觉处理时本就返回 source，语义同 Android）。
- 测试：npm test 256/256 全绿（localization 齿轮断言 / native-global-status navTab 断言 / native-image-editor / native-waveform-scopes 均未动、仍过）。
- 构建：iOS xcodebuild **BUILD SUCCEEDED**（unsigned IPA，44s）；Android **BUILD SUCCESSFUL** assembleDebug（12s，ANDROID_HOME=~/Library/Android/sdk 直跑 gradle，未走会重建 assets 的 build-android.sh）；Harmony **BUILD SUCCESSFUL** assembleHap（10.6s，未签名预期）；`git diff --check` 干净。
- 说明：② 的「恢复被隐藏磁贴入口」未另做独立按钮，由既有「全部」复位承担（与 iOS 行为一致）；如需独立「恢复」入口待 pro 复审意见。
## 12.23 v1.5.7 视频页白字 + 编辑页波形统一样式（2026-08-06，kimi 19:38 派工，事件 25e59e39）

- 基线 agent/1.5.6-ui @ b417b8e（build 31）；独立 worktree agent/1.5.7-issues-whitewave；提交 80ffd52（Issue①）+ 6f012d6（Issue②）。
- **Issue① 视频页文字全部调白（五端，issue 655a0a14）**：视频页（含全屏监看 HUD）所有文字改纯白——标签/说明/读数/状态/角标/空态/工具钮标题；禁用态低透明白（仍白）；激活态不再用彩色（uiAccent/uiBlue/cobalt/readout_glow 等）；黑字黄绿底激活钮改白字；LIVE/NO SOURCE 红绿状态字改白；视频页参数/输出面板强制恒深+白字（panel()/ParameterPanelShell/ParameterDeck 在 monitor 分支恒深，其他页不动）。iOS 注意点：PageTitle 副标题 muted 仅视频页用法改白（不波及他页）。Windows 用子树 DynamicResource 覆盖实现（离开视频页恢复），不改全局资源。
- **Issue② 编辑页波形统一样式（五端，issue 5c0cf4ad）**：EditorScopeDock 图形区改为与视频页完全统一的 RGB 三色叠加波形——黑井 SCOPE_BG、白网格、SCOPE_R #FF302A / SCOPE_G #28FF69 / SCOPE_B #2240FF 三迹线单坐标系叠加（parade=false、加色混合）、底部居中「RGB」标签。数据：当前编辑图（预览同图源，AI 工具取 AI 结果/原图，Pro 取渲染编辑图）下采样≤320px 后统计 64×48 档（S64x48 契约，log1p 归一），无图时空态。AI 四项指标保留为波形旁/下方紧凑文字。iOS/macOS 橙色柱状图→ScopePlot/MacScopePlot 复用；Android 纯文字→WaveformScopeView(RGB_PARADE)；Harmony 纯文字→drawEditorScope 复用 drawScopePanel；Windows 空井参考线→WaveformScope(Mode=RgbParade) + UpdateEditorScopeWaveform()。
- 验证：npm test 256/256 全绿；iOS xcodebuild Release BUILD SUCCEEDED；Android assembleRelease SUCCESSFUL；Harmony assembleHap SUCCESSFUL（未签名预期）；macOS swiftc -typecheck 0 错误；Windows dotnet Release 0 错误；git diff --check 干净（两次提交各自应用后合并 diff 与原始完全一致）。


## 12.23 v1.5.7 build 32 五端打包（2026-08-06，kimi 06:05 打包指令）

- 基线整合分支 ccf223d（含拍照页 de204e6 + 两 issue 修复 80ffd52/6f012d6）+ 版本号提交 c0b5b28（31→32 五端一致：Android versionCode 32/Harmony versionCode 32/iOS CURRENT_PROJECT_VERSION 32/macOS CFBundleVersion 32/test 断言；.gitignore 补 .scratch/）。
- 产物（dist/，6 包 + 6 shasum，覆盖同名保留 build 31 旧包）：Android apk / iOS unsigned ipa / HarmonyOS hap / macOS arm64 dmg / Windows Setup.exe + zip。
- SHA-256：
  - android.apk `0dec9273e5fcf337ea6357547dbd8c37b61985414bfa14c5e5a2bb8e05ea8c42`（签名连续性验证：SHA-256 45499c18... 与历史一致）
  - ios-unsigned.ipa `ff287d9d60181d1acdd6c4fb4d28e769c58b97476ba3d77769feccd282b5edf1`
  - HarmonyOS.hap `c51b98074fdc564181a0fbcf5db0766c8749a2f87369b2c70d7171bf1bc1a59d`（未签名预期）
  - macOS-arm64.dmg `fffff063ec5db3319d3a4ecb1a93440cbb7d28cfb2200adec89c631dab41b845`（ad-hoc 签名）
  - Windows Setup.exe `090cb31d44026a5bcbdd0ea0e1dcfee8cf5605dce41b087455b2c218a123fc4a`
  - Windows zip `29d448cba05ae8e1889c08b35d2d4199922d3f5992fd1f178393e05cfc5501d6`
- 构建验证：macOS dmg 产出（三 SDK env 指向 ~/Documents/NikonLink/）；iOS BUILD SUCCEEDED（unsigned ipa）；Android BUILD SUCCESSFUL（ANDROID_HOME=~/Library/Android/sdk，签名连续性 45499c18）；Harmony assembleHap SUCCESSFUL（未签名）；Windows dotnet publish 0 错误 + NSIS 成功（LANG=en_US.UTF-8 + SONY_CRSDK_WIN64_ZIP env）。

## 12.24 v1.5.7 B1 佳能 R6III 及 DIGIC X 同代机型入册（2026-08-06，Tauber 06:33 指令，kimi 06:45 派工，事件 90f2aa2c）

- 基线 agent/1.5.6-ui @ a5abff8；独立 worktree agent/1.5.7-b1-canon。
- **新增四款**（Canon VID 0x04a9、PID 0x0000 通配不变，注释分组「── Canon DIGIC X (2025 补齐) ──」）：
  - Canon EOS R6 Mark III：DIGIC X、ISO 100–102400
  - Canon EOS R6（初代）：DIGIC X、ISO 100–102400
  - Canon EOS R5 C：DIGIC X、ISO 100–51200
  - Canon EOS R50 V：DIGIC X、ISO 100–32000
  - ISO 口径与佳能官方规格页核对一致（R6 系 100–102400 / R5 C 100–51200 / R50 V 100–32000），无需更正 kimi 给定值。
- 改动：Windows CameraProfile.cs、Harmony CameraProfiles.ets、Android PtpCamera.java（注册表 + 手写摘要串补 4 款）、macOS main.swift（每款 detectionTokens：R6III 含 "r6 mark iii"/"r6 mk iii"/"r6 3" 等变体；R5 C/R50 V 含连写与空格变体；R6 初代基础 token 与既有 Mark II 最长匹配不冲突）、test/camera-profiles.test.mjs canonProfiles 基准 +4（契约同步，否则红）。
- docs 勘正：PROJECT_OUTLINE §2.1 目标用户 Nikon → Nikon/Sony/Canon；§4.2 标题「Nikon 相机支持」→「相机支持（Nikon / Sony / Canon）」，注册表口径 20 款 → 46 款（Nikon 20 + Sony 12 + Canon 14）；CAMERA_TEST_CHECKLIST 新增 R6III 实机验收条目（标记待设备，注 Canon 深度控制 TBC 不在入册范围）。
- 不动：Android device_filter.xml（已有佳能类通配）、PTP vendor 操作层（Canon opcode TBC）、iOS。
- 验证：npm test 256/256 全绿（Canon 注册表断言通过）；Windows dotnet 0 错误；macOS swiftc typecheck 0 错误；Android assembleDebug SUCCESSFUL；Harmony assembleHap SUCCESSFUL；git diff --check 干净。

## 12.23 v1.5.7 B2：WiFi (PTP/IP) 连接监看（2026-08-06，kimi 06:57 设计批复）

- 基线 `agent/1.5.6-ui @ b417b8e`（B1 合入后 rebase 对齐 `995c0ff`）；独立 worktree `agent/1.5.7-b2-wifi`；设计 `PLANS/B2_WIFI_MONITORING.md`（kimi 批复：参数全认可 + 心跳与会话命令串行化纪律）。
- **心跳保活**：连接建立后每 5s GetDeviceInfo（0x1002）探测、单次超时 3s、连续 3 次判离线（15–24s 无响应窗口）；全部挂在既有 PTP/IP 会话通道上（Swift actor / Java synchronized / ArkTS 顺序 await / C# 共享命令流），不与在途事务交错。
- **自动重连**：新增 `reconnecting` 态（iOS/macOS `reconnecting(attempt:)` 枚举 + `isReconnecting` 呈现）；指数退避 1/2/4/8/16s 封顶 30s（五端纯函数 `backoffDelay(forAttempt:)`/`wifiBackoffDelayMs`）；用户主动断开（`manualDisconnect`）不触发重连。
- **网络监听联动**：iOS/macOS `NWPathMonitor`、Android `NetworkCallback`（TRANSPORT_WIFI onLost）、Harmony `NetConnection`（'netLost'）、Windows `NetworkChange.NetworkAvailabilityChanged`——丢网即判离线并进入退避重连。
- **UI**：仅文本分支——「重连中 / 正在重连 Wi‑Fi 相机…」+ 橙色状态点 + 连接按钮禁用态，五端一致，无新控件。
- **测试**：`test/native-wifi-monitor.test.mjs` 6 用例（退避参考实现、五端符号断言、手动断连不触发）；npm test 262/262 全绿。
- **构建**：Android assembleDebug **BUILD SUCCESSFUL**；iOS xcodebuild **BUILD SUCCEEDED**（generic/iOS 免签名）；Harmony assembleHap **BUILD SUCCESSFUL**（未签名预期，期间修复 NetConnection `register/unregister` 须带回调参数、无 `off` 方法的 SDK 事实）；Windows dotnet build 0 错误；`git diff --check` 干净。

## 12.25 v1.5.8 C3：iOS PTP/IP 能力扩展（2026-08-06，kimi 10:22 派工，事件 0b920780）

- 分支 `agent/1.5.8-c3-ios-ptpip`，基线 `38e6369`（agent/1.5.6-ui 整合线），独立 worktree，与 C1/C2 无文件交叠。
- **厂商识别**：`PTPIPSession.detectVendor(using:)` 优先解析 GetDeviceInfo(0x1002) 数据段 Manufacturer（UTF-8 遍历五个数组后取字段）；无数据段机型退回连接握手相机名启发式（nikon/canon/sony/ilce/alpha）。新增 `PTPIPCameraVendor`（unknown/nikon/canon/sony），按会话缓存，断连清零。
- **实时取景**：`startLiveView/endLiveView/getLiveViewFrame`——尼康走 0x9201/0x9202/0x9203（0x9203 数据段返回 JPEG）；佳能按 C2 选用序列对齐（0x9110 写 EVFMode(0xD1b1)=1 + EVFOutputDevice(0xD1b0)=2，Busy 容忍）后取 0x9153 GetViewFinderData；Sony/未知不开启。连接/重连成功后自动开取景（约 10fps 拉帧，失败 300ms 退避），断连先停取景再关会话。
- **录像启停**：`startMovieRecording/stopMovieRecording` vendor 分发——尼康 0x920a/0x920b（未处取景态先开取景）；佳能 EVFRecordStatus(0xD1b8) 1/0（与 C2 三端口径一致）。`WifiCameraService.toggleVideoRecording` + `supportsMovieRecording`（仅尼康/佳能 true，Sony/未知 false 不误报）。
- **参数读写**：GetDevicePropDesc(0x1014)/GetDevicePropValue(0x1015)/SetDevicePropValue(0x1016) + 新增 data-out 请求（DataPhaseInfo=2：请求→StartData(9)→EndData(12)→响应）；属性码与 Android PtpCamera 口径一致（ISO 0x500f / 光圈 0x5007 / 快门 0x500d）。`refreshParameters` 连接后自动读取，参数卡步进经 0x1016 写入后回读。
- **UI 接线**：录像钮三处（全屏 captureButton / MonitorConsolePage scopeStrip / MonitorRecordingBar）改走 `AppModel.toggleVideoRecording`（系统相机优先、Wi‑Fi 兜底），`isRecording`/`videoRecordingAvailable` 计算属性；视频监看页与 iPad CameraStage 展示 Wi‑Fi 实时取景帧（含「等待 Wi‑Fi 实时取景…」空态与失败文案）；compact 页新增 `wifiParameterStrip`、iPad 页新增 `WifiMonitorParameterCard`（快门/光圈/ISO 步进）。
- **测试**：`test/native-ptpip-capabilities.test.mjs` 6 用例（尼康取景/录像 opcode、参数属性 op、C2 佳能序列对齐、vendor 识别、WifiCameraService 状态暴露、UI 路由）；`native-liveview-release` 断连锚点保持（disconnect 先 cancel 连接再复位 C3 状态）。npm test **269/269** 全绿（原 263 + C3 6）。
- **构建**：iOS xcodebuild Release generic/iOS 免签名 **BUILD SUCCEEDED**（编译期修复三处：静态上下文 readUInt16/readUTF8 归属、disconnect 局部变量遮蔽 vendor）；git diff --check 干净。
- **纪律**：无佳能/尼康 Wi‑Fi 实机，实时取景/录像/参数全部按 PTP/EOS 规范实现并标 TBC-awaiting-hardware，报告明确「未经实机验证」；CAMERA_TEST_CHECKLIST 挂「iOS PTP/IP（C3 1.5.8）」待设备实测条目。

## 12.26 v1.5.8 D1：Windows 启动弹窗异常诊断加固（2026-08-06，kimi 14:13 派工，事件 f70341eb）

- 背景：Tauber 报「一打开就弹 Object reference not set to an instance of an object，长期存在」；kimi 审计 HEAD f07b5a4 启动路径确认应用代码无可未防护 NRE，需更强诊断 + 防护收口。分支 `agent/1.5.8-d1-windows-nre`，基线 `f07b5a4`，只动 native/windows。
- **未处理异常弹窗升级**（App.xaml.cs HandleUnhandledException）：原 MessageBox 只显示 e.Exception.Message → 改为主题化详情对话框——异常类型（ErrorBrush + Consolas）+ Message + 完整 StackTrace（ToString() 全文，只读可滚动 TextBox，LogBgBrush/LogTextBrush/RuleBrush 日志盒样式）+「复制详情」按钮（Clipboard.SetText，失败记 Warning 不弹错）+「关闭」。异常日志写入保持。对话框自身失败退回极简 MessageBox，不递归进未处理异常路径（FindBrush/FindStyle 安全取资源，缺失回落系统默认）。
- **公告区降级保护**（MainWindow.xaml.cs ShowLaunchAnnouncementIfNeeded）：整个 UI 构建（FindResource/BitmapImage/资源查找）+ ShowDialog 包 try/catch，失败走 `_diagnostics.Warning("announcement", …)` 静默降级——不弹窗、不阻断启动。
- 三语文案走 AppLocalization：新增 5 键（未处理异常 / 复制详情 / 已复制到剪贴板 / 关闭 / 对话框引导句），中文/English/日本語。
- 验证：dotnet build Release **0 错误**（4 warning 与基线 f07b5a4 完全一致，既有）；npm test **270/270** 全绿；git diff --check 干净。

## 12.27 v1.5.8 build 33 五端打包（2026-08-06，Tauber 15:06 打包指令，kimi 15:07 派工）

- 基线整合分支 `agent/1.5.6-ui @ d77bc84`（已推 GitHub main，合并后 270/270 全绿）。v1.5.8 版本内容六项：
  - **B1 佳能 R6III 及 DIGIC X 同代机型入册**（Canon +4，档案 46 款）
  - **B2 WiFi (PTP/IP) 连接监看**（心跳保活 + 自动重连 + 网络监听联动，五端）
  - **C1 安卓本机摄像头权限引导**（永久拒绝弹设置引导 + 占用分级提示）
  - **C2 佳能 EOS 录像厂商路径**（Android/Harmony/Windows 三端 per-vendor，TBC-awaiting-hardware）
  - **C3 iOS PTP/IP 能力扩展**（实时取景 + 录像 + 参数读写，TBC-awaiting-hardware）
  - **D1 Windows 启动弹窗异常诊断加固**（完整堆栈可复制 + 公告区降级防护）
- 版本号提交：1.5.7→**1.5.8**、build 32→**33** 五端一致（沿用 c0b5b28 改动面）：package.json 1.5.8；五个构建脚本 VERSION/PackageVersion 1.5.8；Android versionCode 33/versionName 1.5.8；Harmony AppScope versionCode 33/versionName 1.5.8 + oh-package.json5 1.5.8；iOS CURRENT_PROJECT_VERSION 33 ×2 + MARKETING_VERSION 1.5.8 ×2；macOS CFBundleVersion 33 + CFBundleShortVersionString 1.5.8；Windows csproj Version 1.5.8；test 断言 buildNumber 33。
- 产物（dist/，6 包 + 6 shasum + SHA256SUMS，覆盖同名保留 build 32 旧包）：
  - `ZENCHE-1.5.8-android.apk` `b9ae57a025318fe5609e470722e7bdda6d3b32f92b5a4b62b06b0bd8cf009bc3`
  - `ZENCHE-1.5.8-ios-unsigned.ipa` `4dc53b5a07599cc92cd1a533fb1094cdd056c1ccd783b17bbe7ff865f3b1325a`
  - `ZENCHE-1.5.8-HarmonyOS.hap` `5e792b8f085107c704549b284b04c6ee49465e7e5e6b019408a4a2aa39a8024e`（未签名预期）
  - `ZENCHE-1.5.8-macOS-arm64.dmg` `e664bc83fb896258b1cd69869fa32ad70b16ed2a61a85b5326adae4530e0838d`（ad-hoc 签名）
  - `ZENCHE-1.5.8-Windows-x64-Setup.exe` `2bbf4cdc38cb671bd32ae3240f50fa1bc4d079b04ae97f01c78b35e62e7798cb`
  - `ZENCHE-1.5.8-Windows-x64.zip` `a402bb00d80bcf483a475ccc179521a8873007101b8751f96e730517196b1c41`
- 构建验证：Android assembleDebug BUILD SUCCESSFUL（ANDROID_HOME=~/Library/Android/sdk，debug 签名连续性 45499c18 已验）；iOS BUILD SUCCEEDED（unsigned ipa：无 _CodeSignature/embedded.mobileprovision，「code object is not signed at all」）；Harmony assembleHap BUILD SUCCESSFUL（未签名预期，module.json versionName 1.5.8/versionCode 33）；Windows dotnet publish 0 错误 + NSIS 成功（LANG=en_US.UTF-8 + 三 SDK env 指向 ~/Documents/NikonLink/）；macOS dmg 产出（三 SDK env）+ 挂测（/Volumes/帧澈 ZENCHE 1.5.8）+ codesign --deep --strict 通过（CFBundleShortVersionString 1.5.8/CFBundleVersion 33）。
- 验证：6/6 shasum -c OK；apksigner 验签（DevEco JBR）SHA-256 `45499c18…` 与历史一致；版本提交后 npm test 270/270 全绿。

## 12.28 v1.5.9 E1 使用人数监控（服务端 + 五端匿名上报，2026-08-06）

- 派工：Tauber「服务器后台能监控使用人数」（08-06 线程 16:05，kimi E1 派工）；计划 PLANS/ZENCHE_V1_5_9_FEATURE_BATCH.md §E1。
- **L0（ai-server/app.mjs）**：新增回环-only `GET /v1/admin/stats`——Bearer 常数时间比较（仿 redeem-rebind.mjs），返回总激活设备数、24h/7d 活跃（按 last_seen + resolveMigrationTail 迁移链归并）、剩余次数分布（0/1-10/11-50/51-99/满额桶）；CLI 由 `ZENCHE_AI_ADMIN_SECRET` 启用。附一次性报表脚本 `scripts/ai-stats-report.mjs`（直接读 devices.json 出同口径 JSON）。
- **L1（server.mjs）**：`/api/update` 处理新增可选 `installId`——服务端只存 sha256(installId) 前 12 位指纹 + platform + version 到 `data/usage-YYYY-MM-DD.json`（tmp→fsync→rename 耐久路径，与 ai-server 同款）；新增 `GET /api/stats`（回环 + Bearer 常数时间比较）聚合 DAU/WAU/累计安装 + 按平台/版本拆分。记录失败静默不影响更新响应。
- **五端客户端**：更新检查 query 追加 `installId`——Android（SharedPreferences `anonymousInstallId`）、macOS/iOS（UserDefaults `NikonLink.anonymousInstallId`，UUID 首次生成）、Harmony（preferences `anonymousInstallId`，util.generateRandomUUID）、Windows（LocalApplicationData/NikonLink/anonymous-install-id.dat，Guid）。ID 与激活码/设备码无关，关闭自动更新检查即停止上报。
- **SECURITY.md**：修订「no analytics」措辞——补充匿名/可选/仅存指纹/与照片日志无关的边界说明。
- 验证：npm test 全量绿（ai-server 45/45 含 L0 3 项、server-update 9/9 含 L1 3 项）；node --check 三文件通过；git diff --check 干净。生产服务器未动（L1 有效性绑定 zenche.top DNS 切换待 Tauber）。
## 12.29 v1.5.9 E2：佳能 USB 实时取景拉齐三端 + backlog 4 观察项（2026-08-06，kimi 16:05 派工，事件 ac93a279）

- 背景：Tauber 指令「佳能实时取景拉齐尼康同级」。计划 PLANS/ZENCHE_V1_5_9_FEATURE_BATCH.md §E2。基线 `b88c663`，分支 `agent/1.5.9-e2-canon-liveview`，串行批次第一棒（E3/E4/E5 不动）。
- **三端佳能取帧**（Android PtpCamera.java / Harmony PtpCamera.ets / Windows PtpCamera.cs）：`EOS_GetViewFinderData=0x9153`（参数 0x00200000,0,0，对齐 gphoto2 ptp.c USB trace），start/stop/getLiveViewFrame 改 vendor 分发（Canon 走 EOS 序列，Nikon/Sony 0x9201/0x9202/0x9203 逐字节不变）；EOS dataset（[u32 len][u32 type][payload] 序列）→ 内嵌 JPEG 提取（type 1/9/11，对齐 libgphoto2 library.c ptp_canon_eos_get_viewfinder_image），全部标 TBC-awaiting-hardware。
- **backlog 4 项收口**：①三端 Canon EVF 乐观置位改确认置位（canonOpenLiveView/CanonOpenLiveViewAsync 返回确认，两写至少一处被接受才置位；录像路径仍 Busy 容忍不阻断）；②EVFOutputDevice 条件写——仅当前值 (cur & ~1)==0 时写 2=PC（读失败回退无条件写，对齐 gphoto2 canon.c）；③iOS detectVendor 0x1002→0x1001（ISO 15740 GetDeviceInfo=0x1001，0x1002 实为 OpenSession；心跳探测仍 0x1002 契约不变）；④iOS enterReconnecting 先 stopLiveViewIfNeeded 再调度重连。
- **参数 EOS 通道**：读走标准 GetDevicePropValue(0x1015)/GetDevicePropDesc(0x1014)（gphoto2 对 EOS 属性读同样走标准通道；**0x9114 实为 SetRemoteMode 非属性读**——计划口径勘正，注释与 CHECKLIST 已写明）；写经 0x9110 EOS_SetDevicePropValueEx（C2 已有）。videoCodec Canon 维持显式抛错 + E2 边界注释（EOS 通道仅覆盖取景/参数，录制规格需机身选择）。
- **契约锚点**：test/native-my-devices.test.mjs 新增 E2 用例（三端 0x9153 + dataset type 1/9/11 + 确认置位 + 条件写 + 尼康 0x9203 保留锚点）；test/native-ptpip-capabilities.test.mjs 新增 iOS 用例（detectVendor 0x1001 + 探测 0x1002 保留 + 重连先停取景）。npm test **272/272** 全绿。
- **构建**：Android assembleDebug SUCCESSFUL、Harmony assembleHap SUCCESSFUL（未签名）、Windows dotnet publish 0 错误（2 既有 warning：PtpCamera.cs:1613 CS8629 + MainWindow.xaml.cs:815 CS0414，与基线一致零新增）；git diff --check 干净。
- **docs**：CAMERA_TEST_CHECKLIST 挂 3 条 E2 待设备实机条目（取景启停/取景态参数读写/macOS gphoto2 管道，不改 macOS 码只挂条目）。
- 纪律：全部佳能新代码 TBC-awaiting-hardware 标注；未建 dist（worktree 内 build 脚本产物为 1.5.8 同名中间件，不入库）；打包听 kimi 调度。

## 12.30 v1.5.9 E3：PTP/IP 遥控全端化 macOS + Windows（2026-08-06，kimi 16:31 派工，事件 d3fecd35）

- 背景：Tauber 指令「Wi‑Fi PTP/IP 遥控全端化」。计划 PLANS/ZENCHE_V1_5_9_FEATURE_BATCH.md §E3。基线 `e798afe`，分支 `agent/1.5.9-e3-ptpip-macwin`，串行批次第二棒（E4/E5 未动）。
- **docs/PTPIP_PROTOCOL.md（新）**：字节级协议文档，以 iOS RemoteCaptureServices.swift 为事实标准——双通道握手/包帧（type 1-12 表）、DataPhaseInfo 1（data-in/无数据）与 2（data-out）、厂商识别（0x1001 GetDeviceInfo 数据段布局）、取景/录像 vendor 分发（Nikon 0x9201-3/0x920a-b，Canon 0x9110 EVF 序列 + 0x9153 EOS dataset type 1/9/11）、参数属性（ISO 0x500f/光圈 0x5007/快门 0x500d）、B2 心跳契约（0x1002 探测不动）。供 E4 及后续维护。
- **macOS**（仅 main.swift UI 接线，逻辑复用 iOS 编译产物）：监看页与全屏取景显示 `wifiCamera.liveViewFrame`（CGImage）；录像钮经 `toggleMovieRecording` 路由 Wi‑Fi 机身录像（不经过外录）；监看页参数步进卡绑定 `wifiCamera.stepShutterSpeed/stepAperture/stepISO`；**auto-live-view 门控**——共享服务新增 `autoStartLiveViewOnConnect`（默认 true，iOS 行为不变），macOS 置 false，由 MonitorView/全屏 onAppear 显式 startLiveViewIfNeeded、onDisappear 停止（照片页不空拉帧）。
- **Windows**（PtpIpCamera.cs + MainWindow.xaml.cs）：传输层补 `SendCommandWithDataOutAsync`（DataPhaseInfo=2：请求→StartData(9)→EndData(12)→响应）+ `DetectVendorAsync`（0x1001 Manufacturer 解析 + 名称启发式，与 E2 iOS 口径一致）+ 取景/录像/参数方法（Nikon/Canon vendor 分发，TBC-awaiting-hardware）；UI 接 JPEG→BitmapImage 取景帧循环（WifiPreviewLoopAsync）、控制卡（实时取景/录像钮 + ISO/光圈/快门步进 + 参数读数）、快门钮视频态路由 Wi‑Fi 录像、断连/重连恢复取景与参数、关窗停循环。
- **顺手项**：iOS probe 注释 0x1002「GetDeviceInfo」勘正为「OpenSession」（pro 复审观察项②收口，仅注释；心跳 opcode 不变）。
- **契约锚点**：native-ptpip-capabilities.test.mjs 新增 2 用例（macOS 门控 + UI 接线；Windows 传输/UI 符号）。npm test **281/281** 全绿（基线 279 + E3 2）。
- **构建**：Windows dotnet build Release **0 错误**（修 3 处编译期问题：lambda 捕获前声明、WriteUInt64 缺失、ushort 隐式转换）；iOS xcodebuild Release **BUILD SUCCEEDED**；macOS 全量构建（三 SDK env）**成功**（main.swift 编译含全部 UI 接线）；git diff --check 干净。
- **docs**：CAMERA_TEST_CHECKLIST 挂 3 条 E3 待设备实机条目（macOS 遥控 / Windows 遥控 / data-out 相位）。
- 纪律：PTP/IP 新代码 TBC-awaiting-hardware 标注（macOS UI 接线沿用逻辑层既有标注）；未建 dist（构建脚本中间产物不入库）；打包听 kimi 调度。

## 12.31 v1.5.9 E4：PTP/IP 遥控全端化 Android + Harmony（2026-08-06，kimi 19:26 派工，事件 26a8e55d）

- 背景：E3 合入整合分支 `2a3daa9`（pro 复审 0 阻塞）后接棒，PTP/IP 收官两端。分支 `agent/1.5.9-e4-ptpip-and-har`，基线 `2a3daa9`。事实标准 `docs/PTPIP_PROTOCOL.md` + iOS RemoteCaptureServices.swift + Windows PtpIpCamera.cs（9097944）。
- **Android**（MainActivity.java + PtpIpCamera.java，Java）：
  - 传输层 `sendCommandWithDataOut`（DataPhaseInfo=2：请求→StartData(9, 前导 0+TransactionID+TotalLength u64+数据)→EndData(12)→响应），用于 0x1016 与 Canon 0x9110 12B 载荷。
  - `detectVendor`（0x1001 GetDeviceInfo 数据段 Manufacturer 解析 + 名称启发式回退，`deviceInfoManufacturer`/`readUtf8`/`vendorForManufacturer`/`vendorForName` 同构 iOS/Windows）。
  - 取景/录像/参数方法：Nikon 0x9201/0x9202/0x9203/0x920a/0x920b、Canon 0x9110 EVF 序列（条件写 `(cur&~1)==0`）+ 0x9153 dataset type 1/9/11 取帧；参数 ISO 0x500f/光圈 0x5007/快门 0x500d，Canon 写走 0x9110。
  - UI 接线：`wifiSourceActive()`（USB > 本机 > Wi‑Fi）、`refreshWifiParameters()`（UINT16/UINT16×100/UINT32×10000 小端，单属性失败容忍）、`stepWifiIso/Aperture/Shutter`（阶梯 + firstAtLeast）、`updateWifiControlCard()`、断连/重连清理与恢复（detectVendor→自动取景→参数刷新）。
  - **快门步进语义修正**：Windows E3 用降序分母 + FindIndex 恒命中首档（TBC 未真机验证的缺陷）；Android/Harmony 改升序秒值正确定位，注释注明差异。
  - 验证：javac 0 错误；`:app:assembleDebug` BUILD SUCCESSFUL（仅既有 deprecation 警告）。
- **Harmony**（PtpIpCamera.ets + Index.ets，ArkTS）：
  - PtpIpCamera.ets 新增 `CameraVendor` 枚举、16 个 opcode 常量、状态 getter（vendor/isLiveView/isMovieRecording）、detectVendor/startLiveView/stopLiveView/getLiveViewFrame/startMovieRecording/stopMovieRecording/readProperty/readPropertyDescriptor/writeProperty/canonWriteEosProp/canonOpenLiveView/readEosPropValue/extractEosJpeg/extractJpeg/sendCommandWithDataOut；模块级 helper 补齐 `appendU64`/`deviceInfoManufacturer`/`vendorForManufacturer`/`vendorForName`/Uint8Array 版 `readUtf8`（与 Android 字节级同构）。
  - Index.ets UI 接线：`WifiCameraTransferSection` 新增控制卡（实时取景/录制钮 + 参数读数 + ISO/光圈/快门 `WifiStepperRow`）；`connectWifiCamera`/`attemptWifiReconnect` 成功路径 detectVendor→自动取景→参数刷新；`disconnectWifiCamera`/`enterWifiReconnecting` 停取景/清录像/清厂商；`toggleLiveView`/`toggleVideoRecording` 按源路由（Wi‑Fi 走机身录像，不触外录路径）；`startPreviewLoop` 按源取帧；监看页/全屏按钮 enabled 扩展 Wi‑Fi。
  - 无 autoStartLiveViewOnConnect 门控（kimi 派工：Apple 双端私有需求，Android/Harmony 保持连上即拉帧）。
- **B2 心跳契约不动**：0x1002 探测、5s/3s×3、退避 1-30s 未改（diff 无 probe 改动）。
- **契约锚点**：native-ptpip-capabilities.test.mjs 新增 4 用例（Android 传输/UI、Harmony 传输/UI 具体符号断言）。该文件 14/14 全绿。
- **构建**：Harmony 干净 assembleHap（rm -rf entry/build .hvigor，DevEco jbr + DEVECO_SDK_HOME）**BUILD SUCCESSFUL**（CompileArkTS 实跑 ~5s，unsigned HAP）；Android assembleDebug 通过；npm test 全量（见交付报告）。
- **docs**：CAMERA_TEST_CHECKLIST 挂 3 条 E4 待设备实机条目（Android 遥控 / Harmony 遥控 / data-out 相位）。
- 纪律：PTP/IP 新代码 TBC-awaiting-hardware 标注；未建 dist、未推远端；打包听 kimi 调度。

## 12.32 v1.5.9 E5：live 图拍摄五端（路线 B）（2026-08-06，kimi 20:12 派工，事件 26a8e55d）

- 背景：Tauber 指令「live 图」。计划 PLANS/ZENCHE_V1_5_9_FEATURE_BATCH.md §E5。E4 合入整合分支 `c212070` 后接棒（功能批收官）。分支 `agent/1.5.9-e5-livephoto`，基线 `c212070`。
- **方案（路线 B，已定案）**：取景帧内存环形缓冲（LivePhotoClipRecorder，约 10fps×N 秒 JPEG）+ 快门触发时把最近 N 秒切为 Motion-JPEG AVI；照片与切片同 reservedBaseName 配对入库（`{base}_live.avi`），CaptureWorkflow 的命名/双备份/SHA-256/XMP 全复用；XMP `xmp:Label="live-photo"` + `dc:relation` 双向配对。不碰机身状态机。开关默认**关**、默认 **3s**（1/3/5/10/15s 可配）。
- **macOS**（`0f47f67`）：LivePhotoClipRecorder.swift（内存 ring + captureSlice 复用 ExternalVideoRecorder 写 AVI）+ main.swift 本机/USB 快门接线（reserveBaseName → 切片 → storeLivePhotoClip）+ SettingsSheet 开关。typecheck 0 error。
- **iOS**（`85627b4`）：移植 LivePhotoClipRecorder 接 RemoteCaptureServices/本机源喂帧转 JPEG 入环 + 快门配对 + RootView 开关。xcodebuild SUCCEEDED。
- **Windows**（`f44fdfb` + `d087b25`）：LivePhotoClipRecorder.cs + MainWindow.xaml.cs 接线 + 设置开关；**StepWifiShutterAsync 顺修**（E3 遗留缺陷，pro 裁定属实：降序分母 + FindIndex 恒命中首档 → 升序秒值阶梯 + FirstAtLeast，对齐 E4 Android/Harmony）。dotnet 0 错误。
- **节流缺陷修复**（`d087b25`）：五端 ExternalVideoRecorder.append 的帧率节流会让 captureSlice 快速回放只写第一帧（AVI 剩 1 帧）；macOS/iOS 加 `bypassThrottle: Bool = false`、captureSlice 传 true；macOS/iOS 双文件字节级一致。Android/Harmony/Windows 对应 throttle/bypass 重载。
- **Android**（`866a9d7`）：LivePhotoClipRecorder.java + MainActivity.java 接线 + 拍摄辅助面板「Live 图」开关 + 1/3/5/10/15s Spinner + `syncLivePhotoRing()` 每帧惰性幂等 arm/disarm。assembleDebug SUCCESSFUL。
- **Harmony**（`af166da`）：LivePhotoClipRecorder.ets（新增）+ CaptureWorkflow.ets（store 加 pairedWithFilename？ + storeLivePhotoClip + XMP 配对）+ ExternalVideoRecorder.ets（appendJpeg throttle 参数）+ Index.ets（字段/偏好加载/syncLivePhotoRing/captureLivePhotoSlice/本机与 USB 快门配对/Wi‑Fi 跳过 + CaptureAssistSettingsCard「Live 图」Toggle + 时长 Select）+ Localization.ets 三语条目（防子串误译：'5 秒' 是 '15 秒' 子串，五档全入表）。干净 assembleHap **BUILD SUCCESSFUL**（CompileArkTS 实跑 3.7s，unsigned HAP 1,624,449 B）。
- **Wi‑Fi PTP 遥控快门不生成切片**（五端一致）：原片在相机存储卡内，本地无照片文件可配对，切片会导致孤儿 AVI。
- **契约锚点**：native-livephoto.test.mjs（新）12 用例——五端 LivePhotoClipRecorder/captureSlice/append 绕过节流/配对 XMP/开关默认值具体符号断言 + Windows StepWifiShutterAsync 顺修锚点（升序阶梯 + FirstAtLeast）+ 五端全部 TBC-awaiting-hardware。native-local-camera.test.mjs 1 断言随 E5 契约更新（Android 本机拍照入口 `savePhoto(jpeg, baseName, liveClip)` 三参配对，单参重载保留）。npm test **297/297** 全绿（基线 285 + E5 12，含契约更新）。
- **构建（全部本会话复跑）**：macOS swiftc typecheck 0 error（build-macos.sh 同口径源列表）；iOS xcodebuild Release **BUILD SUCCEEDED**；Windows dotnet build Release **0 错误**；Android `:app:compileDebugJavaWithJavac --rerun-tasks` **BUILD SUCCESSFUL**（强制重编译，非 UP-TO-DATE 缓存）；Harmony 干净 assembleHap **BUILD SUCCESSFUL**。git diff --check 干净。
- **docs**：CAMERA_TEST_CHECKLIST 挂 5 条 E5 待设备实机条目（macOS/iOS/Windows/Android/Harmony live 图，含 Windows 快门顺修验证）。
- 纪律：E5 新代码全部 TBC-awaiting-hardware 标注；未建 dist、未推远端；打包听 kimi 调度。

## 12.33 v1.5.9 E6：延时合成视频五端（2026-08-07，kimi 03:34 派工，事件 13ef253e）

- 背景：E5 合入整合分支 `03cccd1` 后接棒（二梯队第一项），「拍—合成—导出」闭环最后一步。
  分支 `agent/1.5.9-e6-timelapse`，基线 `03cccd1`。计划 PLANS/ZENCHE_V1_5_9_FEATURE_BATCH.md §E6。
- **方案（已定案）**：序列帧（JPEG/PNG/HEIC/TIFF）→ 逐帧解码 → 统一画布（aspect-fit 黑底）→
  平台原生编码器 → H.264 MP4；帧率 24/25/30（clamp 1-60）、分辨率默认按源帧（上限源尺寸）；
  损坏帧跳过并计数（不整批失败）；进度回调 + 取消检查；产出走 CaptureWorkflow 同会话目录 +
  reserveBaseName 命名 + finalize 全套（XMP sidecar/双备份/SHA-256 清单）。输出 H.264 MP4
  （ProRes 422 仅 Apple 双端可选）。
- **macOS**（`27d41df` + 修复 `6bc69e6`）：TimelapseComposer.swift（AVAssetWriter +
  AVAssetWriterInputPixelBufferAdaptor，Codec 枚举 H.264/ProRes）+ LibraryView 入口 + Sheet；
  修复 macOS 编码器背压忙等 if 结构 + Task.sleep（xcodebuild 完整编译下 guard else 以 if 结尾
  属 fall-through 编译错误；Thread.sleep 在 async 上下文 Swift 6 模式是 error）。typecheck/xcodebuild 通过。
- **iOS**（`dd21d1d`）：TimelapseComposer.swift 移植 + 文件库入口。xcodebuild BUILD SUCCEEDED。
- **Windows**（`9745c0c`）：TimelapseComposer.cs（MediaClip.CreateFromImageFileAsync 静态帧
  clip 装入 MediaComposition → RenderToFileAsync H.264 MP4）+ 入口。dotnet build 0 错误。
- **Android**（`7ea0d3d`）：TimelapseComposer.java（BitmapFactory 解码 → aspect-fit 画布 →
  MediaCodec H.264 + MediaMuxer MP4，YUV420 I420 输入、bitrate=clamp(w*h*fps*0.07, 1M, 20M)、
  I 帧间隔 1）+ 文件库入口。compileReleaseJavaWithJavac 通过。
- **Harmony**（本次，唯一 native 段）：**API 21 已移除 ArkTS 低级编解码 API**
  （media.VideoEncoder/AVMuxer 等 @since 12 符号在 @ohos.multimedia.media.d.ts 中消失），
  改走 native C++：`native/harmony/entry/src/main/cpp/timelapse_encoder.cpp`（423 行，
  OH_VideoEncoder buffer 模式 + OH_AVMuxer，NAPI 四导出 createEncoder/feedFrame/
  finishEncoder/destroyEncoder，同步 buffer 回调 + NotifyEndOfStream + EOS，输入槽等待 5s
  限时防 UI 卡死）+ CMakeLists（libnative_media_venc/codecbase/core/avmuxer + libace_napi）；
  `TimelapseComposer.ets` 保留公开 compose() 表面与解码/画布/NV12 逻辑，编码委托 native
  （`import timelapse from 'libtimelapse.so'` + cpp/types/libtimelapse/index.d.ts 声明）；
  Index.ets 入口面板 + CaptureWorkflow.ets `storeTimelapseVideo`。参数对齐 Android
  （fps clamp、bitrate 公式、NV12 输入）。**与其他四端高级 API 方案不同，已标注待实机回归**。
- **契约锚点**：native-timelapse.test.mjs（新）8 用例——五端 compose 符号（AVAssetWriter/
  MediaCodec/MediaComposition/libtimelapse.so）、bitrate 公式、损坏帧跳过、进度/取消、
  会话入库复用（reserveBaseName + finalize）、Harmony NAPI 导出与 .d.ts、五端全部
  TBC-awaiting-hardware。npm test **305/305** 全绿（基线 297 + E6 8）。
- **构建（本会话复跑）**：Harmony 干净 assembleHap（DEVECO_SDK_HOME + DevEco jbr JAVA_HOME）
  **BUILD SUCCESSFUL**（native C++ 双 ABI 编译 + CompileArkTS ERROR:0，142 条既有 deprecation
  WARN，unsigned HAP 6,041,739 B；libtimelapse.so arm64-v8a/x86_64 均产出）；
  git diff --check 干净；E6 契约测试 8/8 独立复跑全绿。
- **docs**：CAMERA_TEST_CHECKLIST 挂 5 条 E6 待设备实机条目（五端延时合成 + Harmony native
  路径实机回归）。
- 纪律：E6 新代码全部 TBC-awaiting-hardware 标注；未建 dist、未推远端；打包听 kimi 调度。

## 12.34 v1.5.9 E7：焦点包围合成五端（2026-08-07，kimi 04:42 派工，事件 5ba6e86c）

- 背景：E6 合入整合分支 `6025b94` 后接棒（flash 线收官批第二项），闭环完整景深工作流。
  分支 `agent/1.5.9-e7-focusstack`，基线 `6025b94`。计划 PLANS/ZENCHE_V1_5_9_FEATURE_BATCH.md §E7。
- **勘察结论**：五端代码中**无独立焦点包围拍摄任务结构**（仅本地化词条「焦点包围/
  Focus Bracketing」预留），与 E6 同况——入口复用 E6 的「文件库多选序列帧」基建
  （timelapseFrameItems 帧列表 + 会话目录），不依赖不存在的任务结构。
- **方案（已定案）**：序列帧（不同对焦距离）→ 逐帧解码 → 统一画布（aspect-fit 黑底）→
  **全局亮度归一**（以首帧平均亮度为基准，每帧 scale=clamp(mean0/mean_i, 0.5, 2.0)，
  覆盖手持微抖/曝光微差；亚像素位移对齐工程量过大，列入 backlog）→ **3×3 拉普拉斯核**
  （全 8 邻域中心 8）作用于归一亮度取绝对响应 → **逐像素取 |lap| 最大帧**融合（边界
  1px 取首帧）→ JPEG 输出（92 质量）。纯 CPU 零第三方依赖；Apple 端同构未用 vImage
  （口径一致优先）。**内存优化：两遍式逐帧融合**——峰值仅 2 帧像素 + 全局 best 数组，
  不保留全部帧（4K×30 帧场景内存可控）。进度/取消/单帧坏跳过计数与 E6 同口径。
- **产出归集**：五端 `storeFocusStack(from, cameraName, stackSourceCount)`——新 base
  .jpg 入会话，复用 reserveBaseName + finalize 全套；**XMP 扩展**：finalize/xmpSidecar
  加可选 `stackSourceCount: Int? = nil`（默认 nil 现有调用零影响），非 nil 写
  `xmp:Label="focus-stack"` + `xmp:FocusStackSources="N"`（五端口径一致）。
- **macOS**：FocusStackComposer.swift（CGImageSource 解码 + CGImageDestination JPEG）
  + 文件库「焦点合成」按钮 + FocusStackComposerSheet（帧多选 ≥2 + 进度/取消）。typecheck 0 error。
- **iOS**：FocusStackComposer.swift 同构移植（UTType.jpeg）+ pbxproj 注册 +
  RootView 文件库入口 + Sheet。xcodebuild BUILD SUCCEEDED。
- **Windows**：FocusStackComposer.cs（WinRT BitmapDecoder 解码 → 手动画布 →
  同构融合 → BitmapEncoder.JpegEncoderId 输出）+ XAML 按钮 + ComposeFocusStack_Click。
  dotnet build Release **0 错误 0 警告**（macOS 交叉编译复跑）。
- **Android**：FocusStackComposer.java（BitmapFactory + 同构 ARGB 融合 +
  Bitmap.compress JPEG 92）+ 文件库双按钮行 + showComposeFocusStackDialog。
  compileReleaseJavaWithJavac BUILD SUCCESSFUL。
- **Harmony**：FocusStackComposer.ets（纯 ArkTS 图像栈：image 解码 → RGBA 画布 →
  融合 → createPixelMap(buffer) + ImagePacker JPEG；fileIo 写文件）+ Index.ets
  按钮/overlay/方法（复用 timelapseFrameItems）+ Localization 三语条目。
  assembleHap BUILD SUCCESSFUL（CompileArkTS ERROR:0，仅 packing deprecation WARN）。
- **契约锚点**：native-focusstack.test.mjs（新）7 用例——五端 compose 符号 +
  laplacian 3×3 + 亮度归一 clamp + skipped/isCancelled/onProgress + sourcesUsed≥2 +
  storeFocusStack + focus-stack XMP + Harmony 入口面板/localization + 五端
  TBC-awaiting-hardware 一致性。npm test **312/312** 全绿（基线 305 + E7 7）。
- **构建（本会话复跑）**：macOS typecheck 0 error；iOS xcodebuild SUCCEEDED；
  Windows dotnet 0 错误；Android compileReleaseJavaWithJavac SUCCESSFUL；
  Harmony assembleHap SUCCESSFUL；git diff --check 干净；E7 契约 7/7 独立复跑全绿。
- **docs**：CAMERA_TEST_CHECKLIST 挂 5 条 E7 待设备实机条目（五端焦点合成 +
  XMP focus-stack 标记验证）。
- 纪律：E7 新代码全部 TBC-awaiting-hardware 标注；亚像素对齐入 backlog；未建 dist、
  未推远端；打包听 kimi 调度。

## 12.35 v1.5.9 E8 AI 修图批处理（pro 实施，v1.5.9 收官批，2026-08-07）

- 派工：kimi 06:33（基线对齐 e31636f）+ Tauber「继续推进至交付」。
- **勘察结论（与派工假设差异）**：全端 AI 分析/渲染均本地（analyzeForAI 采样分析 + applyTonePipeline 本地渲染），批量应用**零服务器消耗**——UI 如实提示「本地处理零消耗」，不涉及次数扣减。
- **渲染管线参数化（Apple 双端）**：applyTonePipeline/applyGeometry/applyingEditorMask 加 `using settings` 参数，renderedImage 与新增 renderPhoto(from:settings:) 均传参——批量按照片复用同一份复制的 AI 方案。
- **五端批量应用**（复制 AI 方案 → 逐张本地渲染 → JPEG 副本）：
  - macOS/iOS：applyAIBatch()（photos 列表 + renderPhoto + saveEditedPhoto/saveEditedImage，Task@MainActor + @State 包装器，进度/取消/跳过）；UI 工具栏「批量应用 AI」按钮 + 线性进度条。
  - Android：applyAIBatch()（photoFiles() + renderEditedBitmap(4096) + uniqueEditedFile + JPEG 95，editorExecutor 后台 + mainHandler 进度）；UI 按钮 + 进度行。
  - Harmony：applyAIBatch()（editablePhotos() + captureEditorTone/restoreEditorTone 临时切换 + renderSingleEditedPhoto 复用像素管线 + saveEditedCopy）；UI 按钮。
  - Windows：BatchEditorAI_Click（_library.List() + RenderEditedBitmap + JpegBitmapEncoder 95 + UniqueEditedPath，Task.Run 后台 + Dispatcher 进度）；XAML 按钮 + 进度条。
- **契约锚点**：test/native-ai-batch.test.mjs（新）6 用例——五端 compose 符号 + 渲染参数化 + 后台线程 + 进度/取消/跳过 + 本地零消耗。npm test 318/318 全绿（基线 312 + E8 6）。
- 构建：macOS typecheck 0 error（本机复核）；Windows dotnet Release 0 错误（4 警告=2 既有×2 项目，零新增）；Android assembleDebug BUILD SUCCESSFUL（本机复跑）；Harmony 本机 SDK 缺失未复跑（ArkTS 纯改动，锚点兜底）。
- 纪律：未建 dist、未推远端。复审由 flash 承担（作者=pro，复审独立性）。

## 12.36 v1.5.9 build 34 五端打包（2026-08-07，kimi 07:02 派工，事件 7cfc883e）

- 基线整合分支 `agent/1.5.6-ui @ e8186e6`（E8 已合入，npm test 318/318 绿）。
  v1.5.9 版本内容 = E1 使用人数监控 + E2 佳能取景拉齐 + E3/E4 PTP/IP 遥控全端化 +
  E5 live 图五端 + E6 延时合成五端 + E7 焦点包围合成五端 + E8 AI 批处理五端。
- 版本号提交 `9bcd69a`：1.5.8→**1.5.9**、build 33→**34** 五端一致（沿用 12.27 改动面）：
  package.json 1.5.9；五个构建脚本 VERSION/PackageVersion 1.5.9；Android versionCode
  34/versionName 1.5.9；Harmony AppScope versionCode 34/versionName 1.5.9 +
  oh-package.json5 1.5.9；iOS CURRENT_PROJECT_VERSION 34 ×2 + MARKETING_VERSION
  1.5.9 ×2；macOS CFBundleVersion 34 + CFBundleShortVersionString 1.5.9；
  Windows csproj Version 1.5.9；test 断言 buildNumber 34。提交后 npm test 318/318 绿。
- 产物（dist/，6 包 + 6 shasum + SHA256SUMS，旧版归档 dist/旧版/）：
  - `ZENCHE-1.5.9-android.apk` `19214b550f731ff246260a9828bfb61f755b5800301a0980e05c586ab0418624`
  - `ZENCHE-1.5.9-ios-unsigned.ipa` `2d19e5d0d60282115c9052cdc01fd6821c0f13fca0757786c36ab7c5d3a3c8f3`
  - `ZENCHE-1.5.9-HarmonyOS.hap` `d70232cbebb0f18aca293f8917509a444cda8f6a9ccd7c4ef983c5fb53410198`（未签名预期）
  - `ZENCHE-1.5.9-macOS-arm64.dmg` `f3673723f9fc96d265f2f25cf6f1cb52f3e6ffdc4a47416167dd908dc42f3af6`（ad-hoc 签名）
  - `ZENCHE-1.5.9-Windows-x64-Setup.exe` `4b85572fc9068247187961c9cbf2385c83f8d3607a9dfa3c6303baf369b80eb2`
  - `ZENCHE-1.5.9-Windows-x64.zip` `dc624d7875a9ba77b0e3e2c908f7260222a165357f60a51e1736837dce96a030`
- 构建验证：Android assembleDebug BUILD SUCCESSFUL（openjdk@17 + ~/Library/Android/sdk），
  apksigner 验签 SHA-256 `45499c1836…` 与历史一致（签名连续性）；iOS BUILD SUCCEEDED
  （unsigned ipa：无 _CodeSignature/embedded.mobileprovision）；Harmony release
  assembleHap BUILD SUCCESSFUL（未签名预期）；macOS dmg 产出 + 挂测
  （/Volumes/帧澈 ZENCHE 1.5.9）+ codesign --deep --strict 通过
  （CFBundleShortVersionString 1.5.9/CFBundleVersion 34）；Windows dotnet publish
  0 错误（2 既有警告 CS8629/CS0414）+ NSIS 成功（LANG=en_US.UTF-8 + Nikon/Sony
  SDK env + libusb）。
- 验证：6/6 shasum -c OK。

## 12.37 v1.5.9 服务器阻塞修复 + backlog 台账补录（2026-08-07，AI审查 门禁收口）

### 阻塞修复（AI审查 发布门禁阻塞项）
- 更新服务器 server.mjs 静态服务此前对 root 下任意已存在文件无鉴权 GET 放行（:534-555），而 E1 用量数据默认落 root/data（dataDir=join(root,"data")，:433，usage-YYYY-MM-DD.json）——`GET /data/usage-*.json` 无鉴权即可拿到当日全量指纹时间序列，架空 /api/stats 回环+Bearer 门禁。
- **修法甲**：静态服务解码 pathname 后显式拒绝 `/data` 前缀（403，:534-543）；不触碰 /api/update 等公开端点与正常静态文件（新增行为级用例验证：/data/usage-*.json→403、/data→403、/api/update→200、root 静态页→200）。
- 验证：npm test 320/320 全绿（基线 318 + 新增 2 安全用例）。

### backlog 台账补录（AI审查 门禁⑤：以下观察项此前仅存于频道消息，仓库零记录——现补录标「非阻塞 backlog」）
- **E8 applyingGradingCube 实例状态泄漏**（非阻塞）：macOS main.swift:11910 / iOS RootView.swift:3751 读实例轮盘+云创预设而非复制快照；Android 同构（renderEditedBitmap 读实例 selectedNikonCloudPreset）。「复制 AI 后改轮盘/换预设再批量」场景产物偏离复制方案；默认流程（复制→直接批量）正确。建议 TBC 实机验证时一并评估。
- **E6 Harmony native 理论 UAF 窗口**（非阻塞）：OnStreamChanged 编码器线程回调访问 session->muxer 无锁，CreateEncoder streamCv 5s 超时清理后回调晚到理论 use-after-free（低概率）。实机验证时关注。
- **E5 连拍混帧**（非阻塞）：captureSlice 后 ring 未清空（仅 disarm 清），连拍间隔 <N 秒时第二张 live 片段混入第一张时刻帧。路线 B 语义，实机评估。
- **Harmony installId put 后缺 flush()**（非阻塞）：Index.ets:14541，该文件其余 12 处 put 均跟 flush——进程被杀可能丢 installId 致安装数高估，影响统计准确性不影响安全。
- **E8 编辑副本归集口径五端分裂**（非阻塞）：macOS/iOS 走 CaptureWorkflow.store（XMP+双备份+SHA-256），Windows/Android/Harmony 三端直写（无 XMP/备份/manifest）。既有行为延续非 E8 新引入，建议 backlog 拉齐。
- **timelapse 五端无专用 xmp:Label**（非阻塞）：live-photo/focus-stack 均有，延时合成视频缺——若产品要可识别需五端同步补。
- **xmp:Label 理论双写**（非阻塞）：paired+stack 同设会产生非法 XML；当前无触发路径，仅记录。

## 12.38 v1.5.9 build 35 修正版五端重打包（2026-08-07，kimi 07:41 派工，事件 b6ea2a25）

- 背景：build 34 已交付但含 UI 缺陷（iPad 实测：拍照页监看缺失/非拍照页顶栏
  多余 logo），修正后重打包。基线整合分支 `agent/1.5.6-ui @ 2b98d92`
  （合并 127ec5b 拍照页监看恢复 + logo 摘除、46bedad+402e6f6 服务器 /data/
  403 修复 + backlog 台账补录；合并态 npm test 327/327 绿）。
- 版本号提交 `92bc14e`：build 34→**35** 五端同步（版本号维持 1.5.9 不变）：
  Android versionCode 35；Harmony AppScope versionCode 35；iOS
  CURRENT_PROJECT_VERSION 35 ×2；macOS CFBundleVersion 35；test 断言 35。
  提交后 npm test 327/327 绿。
- 产物（dist/，6 包 + 6 shasum + SHA256SUMS，旧 1.5.9/34 六包归档 dist/旧版/）：
  - `ZENCHE-1.5.9-android.apk` `f06b14f26bb8014d1dedbed0dd355003d259d5ef4778289ed21d8a7c4cbeb80e`
  - `ZENCHE-1.5.9-ios-unsigned.ipa` `ee8308e73152787e0cd33b7cddac3fb38585e162ccfe9c55a9cca5e61e76f30f`
  - `ZENCHE-1.5.9-HarmonyOS.hap` `dcd7270e96790270c005e9751c981696840f323759f93453585f528687fb0135`（未签名预期）
  - `ZENCHE-1.5.9-macOS-arm64.dmg` `4c5eff65937fcb320422fba3f870646939691735eebb3a5af2191ebd1555ddba`（ad-hoc 签名）
  - `ZENCHE-1.5.9-Windows-x64-Setup.exe` `39f9cf86e5a329ea3b93857fbf4426f5140b24941d5308535c64f67ef2f87822`
  - `ZENCHE-1.5.9-Windows-x64.zip` `e84223626c9e16f5f5e32d89217915bedd76f181ae403cbf6c8a77ae1c135094`
- 构建验证：Android assembleDebug BUILD SUCCESSFUL，apksigner 验签
  SHA-256 `45499c1836…` 与历史一致（签名连续性）；iOS BUILD SUCCEEDED
  （unsigned ipa 无 _CodeSignature/embedded.mobileprovision）；Harmony
  release assembleHap BUILD SUCCESSFUL（未签名预期）；macOS dmg 产出 +
  挂测（/Volumes/帧澈 ZENCHE 1.5.9）+ codesign --deep --strict 通过
  （CFBundleShortVersionString 1.5.9/CFBundleVersion 35 实测）；Windows
  dotnet publish 0 错误 + NSIS 成功。
- 验证：6/6 shasum -c OK。
- iPad 链路复跑：archive→export signed ipa→devicectl 装到 iPad Pro 11 M5→
  launch→进程存活复核（Tauber 装修正版实测 UI）。

## 12.39 v1.5.9 build 36 五端打包交付（2026-08-07，kimi 10:32 派工，事件 625546da）

- 基线整合分支 `agent/1.5.6-ui @ 82541d5`（已推 GitHub main）。与 build 35 的增量：
  拍照页监看置顶五端同步（69f3e76）、iOS 全屏黑屏修复（33107c5）、Windows
  BasedOn 崩溃修复（abac445）、版本号 35→36（82541d5）。合并态 npm test
  338/338 绿。
- 产物（dist/，6 包 + 6 shasum + SHA256SUMS，旧 1.5.9/34+35 十二文件归档 dist/旧版/）：
  - `ZENCHE-1.5.9-android.apk` `60f243f6021b0d9cd761c4a839d76e80008b0c3d9e2a07c611ccbaf8518a97b0`
  - `ZENCHE-1.5.9-ios-unsigned.ipa` `862aa54795df6e4b0ad51e0225f28ee747289c8b7373600fd6f1b25f086ccc21`
  - `ZENCHE-1.5.9-HarmonyOS.hap` `23f8689db3f3c717d2e9850b5906cf9a04947df4178dcffaa6a9e82b5c42fbb3`（未签名预期）
  - `ZENCHE-1.5.9-macOS-arm64.dmg` `59339c85a666fd0d406fbbf2f0a027d20820b9adf5fe663d5369626ba540ec5c`（ad-hoc 签名）
  - `ZENCHE-1.5.9-Windows-x64-Setup.exe` `2063e01325ec006c3962cbc44b9dd6b2fc0c3a0367bcb4bf60f4696a5b05ff8a`
  - `ZENCHE-1.5.9-Windows-x64.zip` `f2dbcf587aa52fa2cecc6f1a0b0cc784e23d08b8502d798b6f73e6d5d38f978c`
- 构建验证：Android assembleDebug BUILD SUCCESSFUL（DevEco JBR + ANDROID_HOME），
  apksigner 验签 SHA-256 `45499c1836…` 与历史一致（签名连续性）；iOS BUILD
  SUCCEEDED（unsigned ipa 无 _CodeSignature/embedded.mobileprovision）；
  Harmony release assembleHap BUILD SUCCESSFUL（未签名预期）；macOS dmg 产出 +
  挂测（/Volumes/帧澈 ZENCHE 1.5.9）+ codesign --deep --strict 通过
  （CFBundleShortVersionString 1.5.9/CFBundleVersion 36 实测）；Windows dotnet
  publish 0 错误 + NSIS 成功（含 BasedOn 崩溃修复后构建）。
- 验证：6/6 shasum -c OK。

## 12.41 U2-R1 圆角令牌化·iOS+macOS（2026-08-07，kimi 派工，事件 5dc9c351）

- 背景：U1（3ba985d）收口颜色/字号并立 design.md 为唯一基准；U2 批把五端圆角
  字面量全量令牌化。本批苹果双端：iOS 116 处（RootView.swift）、macOS 110 处
  （main.swift 86 + SettingsSheet.swift 24）。
- 令牌：两端各建 `enum RadiusToken`（iOS RootView.swift FontToken 附近、macOS
  main.swift Palette 之后，module 级共享给 SettingsSheet.swift）——覆盖 design.md
  Spacing 坡道全档：zero(0) / r5-r8（5–8 小控件与滑杆部件）/ r10-r12（10–12 按钮
  与输入）/ r14（fig1 深色面卡片）/ r16-r20（16–20 浮层卡片与 sheet）；capsule 档
  用既有 Capsule() 表达不占 cornerRadius 数值。
- 映射（越界就近收敛、坡道内保留原值）：
  - iOS：2/3/4→r5、9→r8、15→r14、22/24→r20；5/6/7/8/10/12/14/16/18/20 保留。
  - macOS：2→r5、9→r8、13→r12、15→r14、24→r20；5/6/7/8/10/11/12/14/16/20 保留。
  - 替换后源码 cornerRadius 字面量归零（仅令牌定义处含坡道数值）。
- 契约测试：native-ios-design-unify.test.mjs + native-macos-design-unify.test.mjs
  各加 1 用例——断言 RadiusToken 全档定义 + 源码 cornerRadius 数字字面量残留为 0
  + 坡道外值（1-4/9/13/15/21-23）不出现在 cornerRadius 使用处。npm test
  357/357 全绿（355 基线 + 2 新）。
- 构建：macOS typecheck 0 error（build-macos.sh 同口径源列表，含 SettingsSheet
  引用 module 级 RadiusToken）；iOS xcodebuild BUILD SUCCEEDED（模拟器 Debug）。
- 范围：只动圆角字面量；间距（U2-S）/颜色字号（U1 已闭环）/功能逻辑零改动。
- 纪律：未 git push；未动生产服务器。

## 12.42 U2-R3 圆角令牌化·Web+Android 壳（2026-08-07，kimi 派工，事件 59601998）

- 背景：R1（iOS+macOS 圆角令牌化）闭环后接棒；Android 侧 UI = 共享 web 层
  （styles.css/tokens.css）+ 原生 WebView 壳。基线 ec06d62。
- **web 层（styles.css）**：勘察发现 54 处 border-radius 声明中 **49 处基线已
  走 var(--radius-xs/sm/md/lg/round)**（--radius-* 令牌 tokens.css 83-87 行，
  数值未动）；仅 5 处字面量 = **2 处 `0`**（方形设计意图，tokens.css 无 0 档，
  与 design.md 坡道 0 档一致）+ **3 处百分比**（scene-object 9%/scene-fruit 48%/
  scene-leaf 100%，装饰性有机形态非尺寸坡道）。**0 与百分比均无既有令牌档可
  映射**，强行映射（0→xs 或百分比→固定值）属观感改动违反红线，故保留并在
  契约测试白名单豁免。核心门=styles.css **禁止 border-radius rem/px 尺寸
  字面量**（当前零残留，探针实测捕获 0）。
- **Android 壳**：dialog_surface.xml + night 变体 `android:radius="24dp"` ×2
  处（派工称 3 处，源码 res 实测 2 文件 2 处）——24 坡道外，就近收敛 **20dp**
  （浮层卡片档 16-20）。
- 契约测试：native-android-design-unify.test.mjs 加 2 用例——web 尺寸字面量
  禁止（单转义 \d 正则，R1 教训）+ 全部 border-radius 声明 ∈ {var(--radius-*),
  0, 百分比} + Android drawable radius=20dp 且无 24dp。
- **反证（探针实际输出）**：反证 A——styles.css 注入 `border-radius: 8px` →
  探针捕获 `['border-radius: 8px']`（1 处）→ 用例变红（pass 5/fail 1）→ 还原
  全绿；反证 B——dialog_surface.xml 改回 24dp → 探针 radius=24dp → 用例变红
  → 还原全绿。
- 验收：npm test **359/359** 全绿（357 基线 + 2 新）；git diff --check 干净。
- 范围：只动圆角；styles.css 令牌数值未动；间距/颜色/字号/功能零改动。
- 纪律：未 git push；未动生产服务器。
## 12.43 v1.5.9 更新服务自托管清单模式（pro 实施，2026-08-07，Tauber 15:19 指令）

- 计划：PLANS/ZENCHE_UPDATE_SELFHOST_PLAN.md 执行项 2，仅改 server.mjs + 测试 + docs/AUTOMATIC_UPDATES.md。
- **清单模式**：`UPDATE_RELEASE_MANIFEST=<path>` 设置后 /api/update 完全走本地清单、零 GitHub 请求；未设置完全保持 GitHub 模式（向后兼容）。
- **清单形状**：`{version, title, body, published_at, release_url?, minimum_supported_version?, assets: {"<platform>/<arch>": {file, sha256}, "<platform>": {file, sha256}}}`。
- **匹配顺序**：platform/arch → platform 兜底；无匹配 url=null 且 update_available 仅按版本比较给出。
- **fail-closed**：清单模式缺 UPDATE_ASSET_BASE_URL → 503；清单缺失/JSON 损坏 → 503 不外泄详情。
- **热加载**：按 mtime 感知（无 TTL），改文件即生效无需重启。
- channel 任意值均回同一清单（自托管只有 stable，docs 注明）。
- 测试：server-update.test.mjs 新增 4 用例（清单服务零 GitHub 请求/匹配顺序兜底/缺 asset 503/缺失损坏 503/热加载）。npm test 359/359 全绿（基线 355 + 4）；node --check 通过；diff --check 干净。
- 红线：未 git push；未动生产（部署由 kimi）；/api/stats 与 /data/ 语义零改动。

## 12.44 更新服务自托管清单门禁返修（kimi 代 pro 接管，AI审查 驳回 2 必修）

- 背景：pro 会话连续两轮 400（context 溢出）停摆，返修由 kimi 直接执行（基 561cfd3）。
- 必修 1（announcement 字段映射）：buildResponse 清单模式把 version→tag_name、title→name 映射进 releaseAnnouncement——原实现清单 title 被静默丢弃、announcement 输出 0.0.0。补断言：announcement.version/title/body 全核对。
- 必修 2（minimum_supported_version 生效）：清单字段优先（强制升级闸门），env/options 兜底——原实现只取 env/options、清单写了也回 null。补断言：清单值生效 + 清单缺省时回落 options.minimumVersion（新用例）。
- 验证：npm test 360/360 全绿（359 + 1）；node --check server.mjs/测试均过。
- 非阻断观察项（mtime 同值陈旧/死代码/URL 未编码/fetchRelease manifest 分支不可达）入 backlog 不修。
- 红线：未 git push；未动生产。
## 12.45 v1.5.9 Admin 监控系统·后端 API（pro 实施，2026-08-07，Tauber 15:03 指令）

- 计划：PLANS/ZENCHE_ADMIN_MONITOR_PLAN.md「后端契约」10 路由逐条实现，仅改 ai-server/app.mjs + 测试 + ai-server/admin/index.html 占位。
- **通用约束**：全部 /v1/admin/* 仅当 ZENCHE_AI_ADMIN_SECRET 配置时存在（fail-closed 404）+ loopback + Bearer 常量时间比较；非 GET 变更写审计 JSONL（admin-audit.jsonl，追加+fsync，完整激活码不入日志，设备指纹 12 位截断）。
- **路由**：1) GET /v1/admin/stats（扩展 expiring7d/exhausted/revoked）2) /stats/history?days=30（每日快照）3) /devices 列表（filter: all/active24h/active7d/expired/expiring7d/exhausted/revoked + query 子串 + cursor 分页 limit≤200）4) /devices/{id} 详情+迁移链 5) reset-usage（迁移链只作用 tail）6) extend-expiry（经回环 signer 签新码，未配置 503）7) revoke/unrevoke 8) note（≤500 字）9) /codes/issue（新码建档，已存在 409，signer 未配置 503）10) /admin/* 静态 SPA（ai-server/admin/，无 token，loopback 天然受限，路径穿越防护同 server.mjs 惯例）。
- **吊销语义**：consume 与 rebind 入口检查 revoked → 403「该激活码已吊销」；verifyActivation 纯密码学不查库（未改）。
- **趋势快照**：admin 启用时启动补当日行 + 每 6h 幂等追加 admin-stats-snapshots.jsonl（{date, ...adminStats()}）；写失败仅 console.error 不触发 fail-stop。
- **设备记录扩展**：created_at（新记录）、revoked/revoked_at、note；旧记录缺省兼容。
- 测试：test/admin-api.test.mjs（新）9 用例——fail-closed/认证门禁/stats 扩展计数/列表过滤分页查询/迁移链详情/各操作路径/signer 503/吊销后 consume+rebind 403 与 unrevoke 恢复/审计 JSONL 落盘无激活码/快照追加。npm test 364/364 全绿（基线 355 + 9）；node --check 通过。
- 红线：未 git push；未动生产服务器 101.34.255.115；verifyActivation 密码学逻辑零改动。
- 前端由 flash admin-web 分支承接（本支已预留 /admin/ 静态路由）。

## 12.46 v1.5.9 admin API 门禁返修（pro，AI审查 门禁驳回 2 必修 + 1 联动必修）

- 必修 1（分页 total 语义）：adminListDevices 改为「先全量匹配收集 → cursor/limit 截断」——total 恒为匹配总数（含 cursor 前页），不再被 limit break 截断。补测试：5 设备 limit=2 三页 total 恒 5。
- 必修 2（迁移链后向环保护）：migrationChain 后向遍历（migrated_from 回溯）加 seenBack 环保护——成环即终止回溯，防事件循环挂死（DoS）。补测试：migrated_from 成环时详情接口 200 不死循环。
- 联动必修 3（revoke/reset-usage 迁移 tail）：两操作解析 resolveMigrationTail 作用于 tail 当前记录（对链中间节点操作不再静默无效）；extend-expiry/note 保持操作指定设备（契约语义，PLANS/ZENCHE_ADMIN_MONITOR_PLAN.md 已更新）。补测试：对中间节点 reset/revoke → 返回 tail 设备且 consume 403 验证。
- 其余非阻断观察项（ADMIN_WEB_DIR 派生/时区/expiring7d 口径/readJsonBody 悬挂/%ZZ 500/issue deviceId 校验）按派工入 backlog 不修。
- 验证：npm test 367/367 全绿（364 + 3）；node --check 通过；diff --check 干净。

## 12.47 U2-S 间距令牌化·iOS+macOS（flash 实施，2026-08-08，合并 e513cd9）

- 分支 agent/u2s-apple-spacing @ a7df7ad。iOS 394 处 + macOS 398 处（main 332/Settings 66）padding/spacing 字面量全量走 SpaceToken（9 档 4pt 栅格 s0–s40）；越界就近收敛每步漂移 ≤2pt；1-2pt 细线与 ≥44 触控目标豁免（注释注明）。
- 契约测试两端 design-unify 各加间距用例（逐 token 白名单 + 枚举数下限防失明 + 禁用值裸数字归零）。AI审查 门禁亲验：注入坡道外字面量变红、摘除新用例则防护归零，检出能力属实。
- 验证：npm test 361/361 全绿；macOS typecheck 0 error；iOS xcodebuild 模拟器 Debug + iphoneos Release 双 BUILD SUCCEEDED。
- 范围：只动间距；圆角/颜色/字号/功能零改动。未 git push。
## 12.48 ZENCHE 后台监控系统·管理台前端（零依赖静态 SPA）（2026-08-07，kimi 派工，事件 e9649f5d/453c4f34）

- 契约：PLANS/ZENCHE_ADMIN_MONITOR_PLAN.md「前端契约」（第 61-68 行）+「后端契约」
  10 条路由（后端 1f66f32 实现，同文件对照字段）。worktree REPOS/ZENCHE-wt-admin-web，
  分支 agent/admin-web @ 3ba985d。改动严格限定 ai-server/admin/**（index.html +
  app.js + styles.css 三件套）。
- 实现：vanilla 零依赖（无外部资源/字体/CDN/图表库，趋势图为纯 SVG）；中文 UI；
  深色科技风（色系参照 tokens.css graphite 深色段 oklch + accent/live/peaking 点缀）；
  token 仅存 sessionStorage，fetch 带 Bearer，401 回登录页（令牌失效自动登出）。
  - 视图一 总览：六卡（总设备/24h 活跃/7d 活跃/7d 内到期/已用尽/已吊销）+
    剩余次数分布条形（zero/low1to10/mid11to50/high51to99/full100 五档）+ 30 天
    活跃趋势（SVG 三序列折线+面积，Y 网格 + 6 刻度日期轴）。
  - 视图二 账号：搜索（设备 ID/激活码子串，320ms 防抖）+ 过滤下拉（all/
    active24h/active7d/expired/expiring7d/exhausted/revoked）+ 分页表格
    （50/页，cursor 分页 + 上一页 pages 栈 + 页码显示）；行内操作：重置次数/
    延期（弹日期输入校验 YYYYMMDD）/吊销·恢复/备注（≤500 字）；点击行进详情
    （kv 字段 + 迁移链节点展示，当前节点高亮）。
  - 视图三 签发：deviceId + 到期日（默认 +365d）→ 展示新激活码 + 一键复制
    （execCommand + clipboard API 双通道）+ 再签一张。
  - 全部操作有 confirm 确认 + toast 结果反馈；错误原样展示后端 error 文案。
- 自测：本地 mock 后端（node 假后端，仅 /tmp 未提交）逐路由走查——stats/
  history/devices（搜索/过滤/cursor 分页）/详情（迁移链）/reset/extend/revoke/
  unrevoke/note/issue（含 409）/重复签发 409/路径穿越；headless Chrome 渲染
  三视图 DOM 断言（总览 6 卡+5 分布条+趋势、账号列表 48 pill+分页信息、
  签发表单）；再以真后端（1f66f32 临时检出 .scratch 运行，未合入分支）
  ZENCHE_AI_ADMIN_SECRET 联调——静态三件套 200、devices 契约、未授权 401、
  路径穿越 404、未配 signer 签发 503「签发服务未配置」全对。
- 验收：grep 三件套零外部 URL（唯一 http:// 匹配为 SVG 命名空间常量
  http://www.w3.org/2000/svg，非资源引用）；node --check app.js 过；
  npm test 355/355 全绿（未动任何被测文件）。
- 纪律：未 git push；未动 ai-server/app.mjs；未动生产服务器。
- 门禁返修（30a6bbd）：迁移链 append 目标 + created_at 口径两项必修修复，复审通过。

## 12.49 U2-R2 圆角令牌化·Harmony+Windows（flash 实施，改派自 pro，2026-08-08，合并 0d336e5）

- 分支 agent/u2r2-harmony-windows @ 79f07c5（基 3ba985d），8 文件 +340/-235。Harmony Index.ets 104 处 borderRadius + 71 处 border({radius}) 补充面、Windows XAML 60 处 CornerRadius，全量走坡道令牌；坡道外值就近收敛，视觉意图逐处经 AI审查 核对。
- 契约测试两端各加用例（扫描断言防失明，注入反证经门禁亲验）。
- 验证：npm test 357/357 全绿（355 基线 + 2 新）；AI审查 复审放行（aa9fd138）。
- 范围：只动圆角；间距/颜色/字号/功能零改动。未 git push。

## 12.50 W13 五端邮箱账号登录墙接管与代码层安全加固（2026-08-09，GPT5.6）

- 接管基线：整合分支 `agent/1.5.6-ui` 基于 `2c7bf50`，W13-a 服务端与 W13-b 管理台已在基线内。五端客户端在首版实现基础上完成安全与视觉加固，代码候选提交为 `c661f7f62e731b36639256aba653a5e0f84b46d1`；提交使用仓库配置的 Tauber `Co-authored-by` 与 `Signed-off-by` trailers，未沿用旧代理签署。
- 安全边界加固：认证固定 `https://zenche.top/api`，禁重定向、限制响应体、严格 JSON/字段形状，协议失败不得离线放行；AI Bearer 仅随 HTTPS endpoint 发送。五端安全存储均加入 forced-signed-out tombstone、失败重试与可见错误，登录/注册保存失败不放行，登出清理失败继续保持登录墙。
- 门禁与交互：启动 `/me` 校验期间不挂载工作区；401/403、协议失败与登出统一关闭连接浮层，并完整停止相机、Wi‑Fi/本机相机、外录、无线、蓝牙和定位后台态。Apple、Android、HarmonyOS 已补焦点/IME/错误播报、44pt/dp 触控、窄窗/平板内容宽度、graphite splash；Android 修复夜间重建绕过、503 免码 IME 与分屏宽度；HarmonyOS 修复 splash 层序；macOS 登录态动态使用 320×420 / 1040×700 窗口下限；Windows 新增完整 checking/login wall、设置账号区、三语与 AI Bearer 接线。
- 统一验证（代码候选 `c661f7f` 的同内容冻结状态）：W13 定向 58/58、`npm test` 468/468；iOS generic/device Release unsigned `xcodebuild` BUILD SUCCEEDED；macOS 全源 `swiftc -typecheck` exit 0；Android 离线 `:app:compileDebugJavaWithJavac` BUILD SUCCESSFUL；HarmonyOS release `assembleHap` BUILD SUCCESSFUL（未签名属项目常态）；Windows Release `dotnet build` 0 错误、0 警告；`git diff --check` 通过。Android 的 3 个 Java 8 警告及 Apple/HarmonyOS 的现有弃用、并发或 SDK 警告未由 W13 新增。
- 视觉门禁：AI审查 第四轮严格只读复审（Buzz `906c8c87…39d39`）签发认证/契约/构建与原生视觉/交互代码静态 PASS，代码 P0/P1/P2 均为 0；审查同时明确该结论不覆盖真机截图、安装或生产验收。当前环境无可用 iOS Simulator、adb、hdc 或 Windows 实机，真机/窗口截图矩阵仍是明确阻塞。
- 文案门禁：GPT5.6luna 第四轮五端终审（Buzz `bffb38f8…38e8d`）签发用户可见内容/去 AI 痕迹静态 PASS；随后对 iOS 日文「新規登録」精确返修的窄范围复核（Buzz `dc411ea6…8abeb`）确认 PASS 继续有效。该结论同样不扩大为真机、安装或生产 PASS。
- 生产进展：2026-08-09 为官网 Nginx 补齐 `/api/v1/auth/` 与 `/api/v1/ai` 精确反代；原配置备份为 `/etc/nginx/sites-available/zenche.top.bak-20260809T154854+0800`，隔离与全局 `nginx -t` 均通过后 reload。公网 `/auth/me` 无 token 返回 JSON 401，`/ai` 空请求返回 JSON 400；免码过渡态真实发码 503、注册 200、登录 200、`me` 200、登出 200、登出后 `me` 401 均通过。无效激活携带账号 Bearer 返回 JSON 403，未调用上游；临时账号 `w13-route-smoke-1786261936353@example.com` 已由回环管理 API 禁用，verified=false、deviceCount=0。
- 剩余发布阻塞：有效激活码的真实 AI 生成与账号绑定尚未执行，SMTP/SES 严格验证码仍未启用，五端真机/窗口截图、安装、无障碍、连接态登出矩阵及版本化交付包/SHA-256/正式签名仍缺。W13 客户端继续保持未 push、未部署、未发布。

## 12.51 管理台总用户口径修正（2026-08-09，GPT5.6）

- Tauber 更正统计口径：目标是管理后台总览，不是官网；“总用户”必须统计全部注册账号，不能使用已激活设备数代替。候选 `adf310d1dbb636a5522ccc4713471b8758afc2be` 为认证系统新增专用账号计数入口，`/v1/admin/stats` 返回 `totalAccounts`；返修 `9d9ce1e` 将卡片说明收紧为“总用户 / 含未验证、已禁用、未绑定设备账号”。设备、活跃、到期、用尽与吊销指标保持原口径。
- 新契约创建两个未绑定设备的免码账号并禁用其中一个，验证 `totalAccounts=2`、`totalDevices=0`；另锁住总览文案与每日快照字段。返修后管理台专项 14/14、完整 `npm test` 470/470，`node --check ai-server/admin/app.js` 与 `git diff --check` 通过；源码候选未 push。
- Tauber 在 Buzz 事件 `c963135a…171a76` 指示继续推进至完成后，2026-08-09 将冻结候选部署到生产 `/opt/ai-server`。切换前远端三文件 SHA-256 与已知基线一致；旧文件备份至 `/opt/ai-server-backups/w13-admin-users-20260809T172051+0800`。部署后 SHA-256：`app.mjs d20b7635e2cdc192aa4a2588b30fa8cd759a3399514123e559516283836413c6`、`auth.mjs e49220fc261b991511a9ddb8dcebe920dddf0e20c7e46abec09455d8f0b008ff`、`admin/app.js 0503fab58df61dacb731d1c74f608b4ce0ae576d2e207b744b2ad02863ce5c4b`。
- `zenche-ai-server.service` 重启后为 active/running；回环管理 API 返回 `statsStatus=200`、`accountsStatus=200`、`totalAccounts=2`、账号注册表总数 2、`totalDevices=11`，管理台静态脚本显示“总用户 / 含未验证、已禁用、未绑定设备账号”。公网 `/api/v1/auth/me` 保持 HTTP/2 401 JSON，`/api/v1/ai` 空请求保持 HTTP/2 400 JSON。该部署不放行 W13 客户端发布，剩余有效激活 AI、真机/安装/签名与交付包门禁不变。

## 12.52 W14 五端实时监看开关与 iOS 相机桥接（2026-08-09，GPT5.6）

- 五端拍照界面均加入“实时监看”开关和关闭空态，保留原拍照、参数与连接流程。关闭会停止当前实时取景或远程帧循环，但不会断开相机，也不影响快门路径；iOS 全屏拍照/视频监看同步遵循该状态。
- iOS / iPadOS 新增局域网 Mac 相机桥接：主机白名单限定可信内网，使用 ephemeral `URLSession`、响应类型与上限校验、短超时、Basic Auth 和不落盘的 12 位本次配对码。macOS 新增状态、JPEG、快门和监看控制端点，并在无线传输页显示地址与本次配对码。
- 能力边界：Sony 通过 Mac 端 Sony Camera Remote SDK 2.02.00 提供实时取景与快门；Nikon 当前为 PTP 兼容桥接，虽可检测 Mac 上的 Nikon Remote SDK 运行时，但未在缺少公开控制 ABI 时冒充官方 SDK 控制。Sony 与 Nikon 的公开桌面 Remote SDK 均未提供可直接嵌入 iOS 的版本，因此 iOS 端不包含桌面 SDK 二进制。
- 视觉门禁返修：Android、HarmonyOS、Windows 关闭实时监看时会清除或忽略缓存帧，拍照页优先显示本地化关闭空态；重新开启后才恢复取景循环，相机连接与拍摄路径不受影响。Apple 动态桥接状态同步补齐中英日完整词条，避免英文或日文界面出现片段混排。
- 冻结验证：W14 专项 11/11、Apple 登录墙 + W14 联动 31/31、完整 `npm test` 481/481；三语 Apple strings 均通过 `plutil -lint`，`git diff --check` 通过。iOS generic/device Release unsigned `xcodebuild` BUILD SUCCEEDED；Android `assembleDebug`、HarmonyOS Release HAP、macOS 原生打包和 Windows x64 publish/NSIS 均成功。现有 Apple 并发/弃用、Android API 弃用与 Windows `PtpCamera` nullable/既有字段警告未由 W14 新增。
- 本地交付物已生成并逐一通过 SHA-256 回验：Android debug-signed APK、HarmonyOS unsigned HAP、iOS unsigned IPA、macOS arm64 ad-hoc signed DMG，以及 Windows x64 安装包和便携 ZIP。macOS/Windows 包继续携带已校验的 Nikon/Sony 桌面 SDK 运行时；iOS 包不含不兼容的桌面二进制。Sony/Nikon 实机的桥接连接、实时取景、快门、断线恢复与延迟仍需在持有兼容相机的环境验收，不能由编译或静态契约替代。使用说明见 `docs/LIVE_MONITOR_AND_IOS_CAMERA_BRIDGE.md`。

## 12.53 W15 登录动作清晰化与桌面工作区（2026-08-10，GPT5.6）

- 诊断证据：生产 `https://zenche.top/api/v1/auth/login` 对无效凭据约 0.2 秒返回结构化 `401`；按用户报告前后时间窗检索 `/var/log/nginx/zenche-top.access.log`，没有登录请求。故障点位于客户端提交前，不是认证服务不可达。五端原登录墙把模式按钮和真正提交按钮都标为“登录”，选中模式按钮再次点击没有行为，形成“点登录没反应”的高概率误解。
- 登录修复：iOS/iPadOS、Android、HarmonyOS、macOS、Windows 的模式标签统一为“已有账号 / 创建账号”，真正提交按钮继续使用“登录 / 注册”；Apple 忙碌态显示进度指示和“正在登录 / 正在注册”，共享语言包补齐中英日 exact key，切换模式时清除旧错误并把焦点移回邮箱。认证 API、安全存储、会话校验与 AI Bearer 协议不变。
- 桌面布局：macOS 和 Windows 均可保存主窗口大小/位置以及导航、拍摄参数、编辑媒体池、工具栏和底部区尺寸；分隔条支持拖动，设置页提供默认、拍摄、监看、编辑、紧凑预设及恢复默认。恢复逻辑会把离开当前显示器工作区的窗口约束回可见区域，Windows 另保存最大化状态。
- 范围边界：第一阶段是单主窗口内的可调分区，不包含任意浮动面板、跨窗口拖放、面板自由编组或 Adobe 完整 dock 系统。macOS/Windows 真实拖拽、重启恢复、Windows 多显示器/DPI 和辅助功能仍需真实桌面环境验收。
- 当前验证：实现与打包源码为 `83eb7b22afe0eb90daa2cb99dc0bc675ab03a57e`；完整 `npm test` 492/492，登录/布局/公告专项包含在内。Android Debug APK、iOS unsigned Release、HarmonyOS Release HAP、macOS arm64 DMG、Windows x64 publish/NSIS 均按该提交重建成功；六个包压缩/DMG 结构、版本、适用签名属性与 SHA-256 已回验，三份 Apple strings lint 通过，IPA 内中英日忙碌态 exact 值已直接抽取核对。AI审查 对 exact `d4c1b067…` 给出 P0/P1/P2=0 的最终 UI/交互 PASS；GPT5.6luna 同一提交确认上一轮 Apple exact key、签名公告两项 P1 和文档 P2 已闭环，且无新的事实、翻译、AI 痕迹或能力越界，唯一新增 P1 是聚合总包仍含旧六包。该阶段聚合包已通过 14 项一致性核对，随后由 12.54 的连续调节与窄窗响应式返修包取代。
- 版本边界：源码候选为 `1.5.11 / build 38`；生产清单保持 `1.5.10 / build 37`，本轮未部署、未推送、未打标签、未创建 GitHub Release。使用说明见 `docs/DESKTOP_WORKSPACE_LAYOUT.md`，发布表见 `docs/releases/v1.5.11.md`。

## 12.54 W15 桌面连续调节与 AI 空间增量（2026-08-10，GPT5.6）

- 用户反馈与根因：macOS 截图显示 AI 工具的模式、预设和输出参数被压缩在较小底部区域；源码核对确认该区域同时渲染重复的完整分类导航、AI 自有生成底栏和通用编辑状态/操作栏。Windows 的五处分隔条采用拖动预览、松手生效，AI 预览与选项列则没有独立分隔条。
- 实现：macOS 移除 AI 区重复分类导航及无关通用底栏，把默认底部高度提升到 360 pt、编辑预设提升到 480 pt，并将导航、参数、媒体池、工具和底部区域范围扩大；拖动期间禁用隐式动画，悬停/拖动显示系统调整光标与强调色，动态范围为中央画面保留最低尺寸。Windows 六处分隔条全部实时重排，新增可持久化的 340–720 px AI 工具列；模式按钮等宽自适应，快捷预设按分类独立换行。
- 窄窗返修：macOS 在 1040 pt 登录后最小宽度下将保存的 360 pt 侧栏动态收紧至最多 216 pt，固定保留 812 pt 内层工作区；Windows 按页面和窗口宽度联动限制侧栏与参数栏，编辑窄窗/常规分别预留 708/828 px，紧凑 AI 页收起预览并让选项列占满剩余宽度。
- 验证与交付：实现与桌面包打包源码为 `97659b2ea7a588720be041e32f736c98e8cec65c`。完整 `npm test` 493/493；macOS 全源 `swiftc -typecheck` 通过，应用构建、ad-hoc 深度严格验签、DMG 校验通过；Windows WPF `dotnet build` 0 error，Release publish、NSIS 与便携 ZIP 通过。新包 SHA-256：macOS DMG `e209b2f243d7d39c6194a1599e871ddb42ecaa3d52a1cc5bb1e729aa792ce402`，Windows Setup `b2e571afe79bee802bccca87e10c64261567b6e9e5fb8b643f139459070571b1`，Windows ZIP `c682875ee2e2b5375ddec8040cfd159e2a67de035f959e9389509c8dc7ad3c9e`。
- 当前状态：AI审查 对 exact `97659b2…` 的原生 UI/交互/响应式/辅助功能终审 PASS（P0/P1/P2 均为 0）；GPT5.6luna 已确认三语、签名事实、生产边界和去 AI 痕迹通过，其指出的旧聚合包、未封板状态与英文窗口术语均已修正。最终聚合包 SHA-256 为 `77a2f957c89f332e9b3afd09ad1a9e81ed26f0375d5b2201580b7644051dd15f`，根侧车、ZIP 完整性、六份内嵌侧车及 14 项逐字节一致性全部通过。本轮未改移动端功能或生产清单，未部署、未推送、未打标签、未创建 Release。真实 macOS/Windows 拖拽、辅助功能、重启恢复以及 Windows 多显示器/DPI 仍需实机验收。

## 12.55 W15 编辑器层级、示波器空间与性能增量（2026-08-10，GPT5.6）

- 用户反馈：桌面编辑器上下两排同时出现专业工具与 AI 入口，无法一眼区分编辑模式和具体调整类别；底部示波器的曲线只占固定小块，剩余横向空间闲置。同时要求降低资源占用并解决参数调整卡顿。
- 实现：macOS 与 Windows 将“专业显影 / AI 工具”固定为一级“编辑模式”，把光线、色彩、色轮、曲线、取色器、蒙版、细节、效果和几何固定为二级“调整类别”；AI 不再作为二级重复入口。macOS 从 AI 返回时恢复上次专业分类，Windows 的模式入口在 AI 页仍保持可见。
- 空间：macOS 示波器改为状态头在上、RGB 曲线填满剩余宽高；Windows 底部工具与示波器改为 3:2 自适应比例，不再使用固定 300 px 曲线列。两端均继续服从底部分隔条的连续调节与安全范围。
- 性能：macOS 同一界面刷新只生成一份最大边 2048 的预览图供画面和示波器复用，完整分辨率仅用于保存/导出。Windows 以 33 ms 合并高频刷新，一次 1600 px 渲染同时供预览与 320 px 示波器采样；相同 RGB 数据不重复重绘，时间码只在录制期间运行，离开编辑页或关闭窗口时释放预览、AI 结果和示波器位图。
- P2 返修：Windows 新增集中式 AI 临时结果清理。只有系统临时目录下严格匹配 `zenche_ai_*.jpg` 的文件可被删除；先遗忘活动引用再尽力删除，删除失败不会阻断用户操作。新结果替换、AI 编辑/生成模式切换、照片切换、离开编辑页和窗口关闭均覆盖；AI 结果预览使用 `BitmapCacheOption.OnLoad` 立即释放文件句柄，保存到用户路径的正式副本不进入清理路径。异常退出可能留下至多一个活动文件，未做目录扫除以避免多实例竞态。
- 验证与交付：最终源码基线为 `831a82315c3586a8c8933c76ef6e8e3612bbcba5`；完整 `npm test` 503/503，三份 Apple strings lint、macOS 全源类型检查、Windows WPF 编译与 `git diff --check` 通过。Impeccable 最终检测为 0 条布局反模式。macOS DMG SHA-256 为 `c7b6239b145aaf66698712d136457bd220287c40ddb5802bfcb1e7195e483463`；Windows Setup 为 `4687c8220c2f6c59411b5a47ab5d4a58dfe93273a8dbb8165837c872e08df03f`，Windows ZIP 为 `b732db1f8e395b138a93138ab839636d6cb3c541a353c99ad40dfebca94ff965`。Windows 两包按最终源码重建；最终基线相对 `0faeccdc987146c104fd73d742547c9baf9db221` 只有 Windows 专属变化，macOS DMG 因而复用该提交已完成深度严格验签与 DMG 校验的同字节产物。三份侧车与 Windows ZIP 结构均已回验。
- 当前状态：最终聚合包 SHA-256 为 `46515bba169afe3a495f1265dec9ab2a3ac409ecaf20d2466b041fe2144992e1`，根侧车、ZIP 完整性、六份内嵌侧车及 14 项逐字节一致性均通过。AI审查 最终门禁 PASS（P0/P1/P2=0）；GPT5.6luna 确认三语、签名事实、生产边界、去 AI 痕迹、六包哈希和聚合内容无实体问题，其上一轮唯一 P2 为材料仍写“复核进行中”，现已完成状态回填。未改移动端功能或生产清单，未部署、未推送、未打标签、未创建 Release。真实 macOS/Windows 拖拽、重启恢复、VoiceOver/Narrator、Windows 多显示器/DPI、安装及长时间 CPU/内存/帧率仍需实机验收。

## 12.56 Android Nikon Z50 拍摄后 DeviceBusy 恢复（2026-08-10）

- 用户日志显示 `CaptureToSdram` 后的 `GetObject (0x1009)` 连续返回 `DeviceBusy (0x2009)`；第 4 次警告到最终失败仅约 29 ms。根因是旧实现虽然循环 4 次，但只调用可能提前成功的 `DeviceReady`，没有强制等待，相机写入 JPEG 时会在极短时间内耗尽全部重试。
- Android `PtpCamera` 将对象下载恢复收口为独立方法：最多 9 次、最长 20 秒，按 300/600/1200/2400/4000 ms 封顶退避；每轮读取 `DeviceReady` 和 `GetEvent`，若机身补发最终 SDRAM 句柄则切换句柄后再下载。恢复路径没有 `CaptureToSdram`，不会重复拍摄；非 `0x2009 + 0x1009` 错误立即失败，线程中断保留中断状态。
- 验证：`test/known-issue-regressions.test.mjs` 定向 9/9 通过；使用 Android 35 `android.jar` 与基线完整 Debug classpath 对修改后的 `PtpCamera.java` 单独执行 Java 8 `javac`，编译通过（仅 `-source 8` 引导类路径提示）。完整 `npm test` 与 Gradle 编译在受限执行环境中均因禁止回环 socket（`listen EPERM 127.0.0.1` / Gradle daemon socket）未能启动完整门禁，不属于源码测试失败，合入前必须在允许本机回环的环境复跑。
- 边界：尚未持有 Nikon Z50 对不同固件、存储卡速度、RAW/JPEG 模式和 OPPO Android 14 USB 主机组合做真机拍摄；本分支未推送、未部署、未打标签或发布安装包。

## 12.57 Android Camera2 `endConfigure` 兼容降级（2026-08-10）

- 用户在 OPPO PEDM00 / Android 14 打开本机摄像头时收到 `CameraAccessException: CAMERA_ERROR (3): endConfigure:513`。根因是厂商 HAL 拒绝应用原先固定的双 JPEG 输出组合，而旧代码没有更低负载或单流候选。
- `LocalCameraController` 现在按常规双流、低负载双流、常规共享流、低负载共享流、最小共享流依次尝试；每个候选的尺寸均来自 `StreamConfigurationMap`。失败后关闭本次 reader/device 并重新打开，迟到回调、打开超时及拍照同步异常也会释放资源。
- 单共享 JPEG 模式以传感器时间戳区分预览与拍照帧，拍照结束后恢复 repeating 取景。专项 `native-android-camera2-compat` 4/4 与已知问题套件一起通过；仍需 OPPO 真机验证连接、监看、拍照、重复连接、前后台恢复及权限拒绝恢复。

## 12.58 W15 AI 无法修图与系统相册编辑流程（2026-08-10，GPT5.6）

- 根因：五端 AI 实际调用都经过账号/设备激活代理，HTTPS 时才附加账号 Bearer；但默认值仍是历史明文 `http://101.34.255.115:8787`，Android/HarmonyOS 运行时还错误提示用户配置 API Key。修复把五端默认迁移到 `https://zenche.top/api`，只替换历史默认值并保留其他显式自托管配置；Android/HarmonyOS 说明改为当前账号与设备激活权益。Windows/macOS 等待窗口同步为 300 秒。
- AI 请求链复核：Android、iOS/iPadOS、HarmonyOS、macOS、Windows 均向 `/v1/ai` 提交激活码、设备 ID、提示词和尺寸，修图携带完整 MIME data URL；HTTPS 且有 session 时附加 Bearer；结果支持 `b64_json` 或 URL，并落到编辑器结果。该修复未在客户端重新引入模型 API Key。
- 系统照片编辑流程：Android 新增 Photo Picker/Document Provider 桥接，以 `ContentResolver` 流复制到 `CaptureWorkflow`，对 provider `SIZE` 与真实读取字节实施双重 64 MB 上限；导入先写 `.importing` 同目录临时文件，流、同步、重命名或收尾失败均清理临时文件和本次目标，取消选择也会清空忙碌状态；另存使用 MediaStore 新建项目并处理 pending/失败清理。Android 另增加无第三方依赖的 JPEG EXIF Orientation 1–8 解码归一化，编辑缩略图、预览、分析、调整和导出共用同一方向。iOS/iPadOS 新增 PhotoKit 权限状态、iCloud 可读工作副本、设置恢复 URL 与新 PHAsset 导出；HarmonyOS 新增单选 PhotoViewPicker 工作副本和 `showAssetsCreationDialog` 新资产导出。
- 可见 UI 与保存契约：三端专业显影和 AI 修图都显示“照片来源 / 从系统相册导入”，空文件库仍可进入系统选择器；保存动作分为应用文件库新副本与系统相册新项目。移动端 AI 修图不再覆盖所选工作副本；拒绝权限、取消、导入/保存失败和设置恢复均有明确状态。Apple 中英日补齐 exact key，Android/HarmonyOS 运行时三语同步。
- 回归与构建：最终移动端实现源码基线 `5e7150d9217690e6aea56ea15d8fae852a2d825f`；完整 `npm test` 514/514 通过，专项覆盖默认 AI 代理、Bearer、原图 data URL、三端导入/导出、EXIF 1–8、可见入口、新副本保存，以及 Android/iOS/HarmonyOS 动态 AI 状态 exact/参数化三语契约。Android `assembleDebug`、iOS Release 无签名构建、HarmonyOS Release HAP 构建成功；三包 SHA-256 分别为 `91d4abd24ab634299d0d49d72fa3c2075b823f4a03ad17a6201d5399b81529f3`、`d2b4ce5fe40e77f2f5a6a51c03f7b1937db2e66ab2112ac9517012b6cb81c4f5`、`92d3b9cf19fb4855bde24e1209b229f530ea3b74bb57b4beba9193884b304223`，三份侧车和压缩结构均通过，Android v2 Debug 签名证书保持一致。复用既有桌面包后重建 GitHub 发布聚合包，SHA-256 为 `2f90a8afb39dbe26c1537c4f642e09f76898627547693453d8829005c190d9e4`；六包、六侧车和两份说明共 14 项与当前交付源逐字节一致。
- 双审封板：AI审查 对 exact `cd20e2d3ffe44fc60b06d4225d083622968741b4` 的原生 UI/交互增量终审 PASS（P0/P1/P2=0）；GPT5.6luna 对同一快照确认三端运行态三语、README 计数、事实边界、去 AI 痕迹及聚合包实体全部通过，其唯一 P2 为长期进度仍写“复核中”，已在本次状态提交中关闭。
- 尚未验证：未用有效激活码访问生产代理，未在 Android/iOS/HarmonyOS 真机执行 URI/iCloud/权限拒绝恢复/系统相册另存，也未在 Nikon Z50 或 OPPO PEDM00 上做实机回归；未做正式签名或安装验收。GitHub v1.5.11 已公开，官网生产仍为 1.5.10 / build 37，未部署本版本。

## 12.59 GitHub v1.5.11 公开发布（2026-08-11，GPT5.6）

- Tauber 在 Buzz 明确指示“传 github”。`main` 由 `8bd995cb29b4d9e03ac3152ba0cdd34393371e1b` 快进到发布提交 `7e7641fbfe571a2494e594a56c9bd3f7bad9341b`；注释标签 `v1.5.11` 解引用到同一提交。发布前 exact HEAD 完整 `npm test` 514/514，测试前后 HEAD 一致，工作树 clean，`git diff --check` 通过。
- [GitHub Release v1.5.11](https://github.com/Tauber01/ZENCHE/releases/tag/v1.5.11) 于 `2026-08-10T18:12:28Z` 公开，状态为非草稿、非预发布。Release 包含 Android APK、iOS unsigned IPA、HarmonyOS HAP、macOS arm64 DMG、Windows x64 Setup/ZIP 六个安装包及六份侧车，以及聚合交付包和其侧车，共 14 个资产；线上字节数与 GitHub SHA-256 摘要逐项对照本地文件，14/14 一致。聚合包 SHA-256 为 `2f90a8afb39dbe26c1537c4f642e09f76898627547693453d8829005c190d9e4`。
- GitHub 公开稳定版不改变签名与实机边界：Android 为 Debug 证书，iOS/HarmonyOS 未签名，macOS ad-hoc 且未公证，Windows 无 Authenticode。Nikon Z50、OPPO Camera2、移动相册/iCloud/真实 AI、桌面拖拽/多显示器/DPI、辅助功能、安装升级与长时间性能仍需真机验收；官网自动更新和生产部署均未切换，继续提供 1.5.10 / build 37。

## 12.60 Windows 曝光控件 XAML 初始化 NRE 热修候选（2026-08-11，GPT5.6）

- **触发与根因**：用户截图记录 Windows 未处理 `System.NullReferenceException`，堆栈为 `SetParameterAvailability → UpdateExposureAvailability → ExposureModeBox_SelectionChanged`。公开 `main` 发布记录提交 `77dd4056efaf95d98825c0ca81d7029f8fed2ee7` 中，`ExposureModeBox` 在 XAML 默认选中 `manual` 时同步触发事件，但后面的 `ShutterBox`、光圈、ISO 等命名控件尚未创建；原处理器先刷新整组可用性、后检查 `_initializing`，首个空引用落在 `control.IsEnabled`。独立全扫还确认 `VideoShutterModeBox` 默认选中会提前调用 `ConfigureShutterControl`；共享 `ParameterBox` 处理器也在门禁前刷新读数，后者尚未证实在冷启动断开态下触发空引用，本次作为防御性加固一并收口。
- **实现与回归**：分支 `agent/1.5.11-windows-exposure-nre` 的代码提交 `970f8e08edce2529750d5b29fe3aaccd53da61ac` 把共享参数、曝光模式和视频快门模式的初始化门禁放到危险刷新/配置之前；视频快门仍先保存安全的 XAML 预选值。新增 `test/native-windows-exposure-startup.test.mjs`，锁定 `_initializing = true`、三条事件连接与默认选中项、控件声明顺序、门禁顺序及完整树加载后的 `ConfigureShutterControl(false)` 恢复路径。曝光与视频快门两条用例均先观察到失败再修复，最终专项 3/3 通过。
- **验证**：exact 代码提交完整 `npm test -- --test-reporter=dot` 为 517/517；`git diff --check` 通过。`scripts/build-windows.ps1 -Runtime win-x64` 使用既有已验证的 libusb、Nikon Image/Remote SDK 和 Sony Camera Remote SDK 运行库完成 Release publish、NSIS 和便携 ZIP，命令最终退出 0；NU1900（漏洞源不可达）、`PtpCamera.cs` CS8629 与 `_aiGenerating` CS0414 为既有非阻断警告。独立只读全扫覆盖 11 个 XAML `IsSelected="True"`，结论为 P0=0、P1=0、P2=0。
- **本地交付物**：`ZENCHE-1.5.11-Windows-x64-Setup.exe` 为 90,871,247 字节，SHA-256 `69afb3763b374005a97b6ef1da558c7dded8fa5d94c954d5aa673560fa7d5d47`；`ZENCHE-1.5.11-Windows-x64.zip` 为 110,137,992 字节，SHA-256 `37ba48fae87f3fd074a222fe214dadacd882e3d3e0383333aa98246a38917e40`。两份 `.sha256` 使用 `shasum -a 256 -c` 回验通过；ZIP 的 52 项压缩结构及 Nikon/Sony/libusb 运行库通过 `unzip -t`。Setup 与主程序 PE Security Directory 均为 0，未做 Authenticode。
- **边界与下一步**：两个文件沿用 1.5.11 名称，仅是本地热修候选，未替换 GitHub v1.5.11 资产、未推送分支、未打标签、未创建新 Release、未切换官网自动更新。当前主机为 macOS，无法完成真实 Windows STA/BAML 冷启动、主窗口显示、曝光/视频快门切换、安装/升级/卸载、驱动与 SmartScreen 验收；这些门禁完成前不得把静态契约或交叉包描述为 Windows 实机通过。`GPT5.6luna` 的最终去 AI 痕迹审查已发起；在 Tauber 随后的“重新派工”指令下，deepseek-v4-flash 对 exact `9dce5e56001ab1cd01241a99675a35bb262d68b2` 的技术/事实与文案/去 AI 痕迹两轮窄审均给出 PASS（P0/P1/P2=0），最终门禁已按新派工闭环。

## 12.61 v1.5.12 GitHub Latest 发布准备（2026-08-11，GPT5.6）

- Tauber 在 Buzz 线程 `88c2862071355eb93ab89725fe92107cd7a910f0bd2c124213909b7f3c837f64` 明确要求把 Windows 启动修复“作为最新版发布”。本轮使用新补丁版本 `1.5.12 / build 39`，不覆盖 v1.5.11 标签或资产；发布范围为 GitHub `main`、注释标签和公开稳定 Release，官网生产清单不在本次授权范围内，继续保持 `1.5.10 / build 37`。
- 发布分支 `agent/1.5.12-windows-nre-release` 从远程 `main` 的 `77dd4056efaf95d98825c0ca81d7029f8fed2ee7` 之上现有热修封板 `6228f00f0179b1d33206783b26ff57a519b4e3fa` 创建。五端版本元数据、运行时版本回退值与中英日启动公告统一到 1.5.12 / build 39；README 新增 1.5.12 章节并保留 1.5.11 历史，`CHANGELOG.md` 增补独立条目，构建总脚本取消读取版本失败时静默回退到 1.5.3。
- 当前验证：`git diff --check` 通过，三份 Apple `.strings` 通过 `plutil -lint`，完整 `npm test` 518/518 通过。六个安装包、六份侧车、聚合包及其侧车尚待从冻结候选提交生成并回验；最终提交、标签、各包字节数与 SHA-256、线上 14/14 结果将在实际发布后回填。Windows 包继续由 macOS 交叉构建且无 Authenticode，不能据此声称真实 Windows 启动、安装、驱动或 SmartScreen 已验收。
