# 帧澈 ZENCHE 项目大纲

> 文档状态：工作基线
> 最近核对：2026-08-04（Asia/Shanghai）
> 使用方式：开始产品、界面、技术或发布工作前，先阅读根目录 `AGENTS.md`，再阅读本文、`docs/TECHNICAL_APPROACH.md` 与 `docs/TASK_PROGRESS.md`。

## 1. 项目定位

帧澈 ZENCHE 是一套本地优先的原生跨平台相机控制与影像传输工具，围绕摄影现场的完整工作流组织能力：连接相机、实时监看、调整参数、自动拍摄、接收影像、整理素材、非破坏性处理、导出与诊断。

- 中文名称：帧澈
- 国际名称：ZENCHE
- 双语锁定：帧澈 ZENCHE
- 产品描述：跨平台相机控制与影像传输工具
- 英文品牌语：Capture · Connect · Flow
- 标准标语：连接相机，也连接完整工作流
- 当前源码版本：1.5.3
- 当前原生构建号：28
- 发布状态：v1.5.3 是 `agent/1.5.3-ui` 本地交付候选，尚未推送、打标签或发布；GitHub 最新稳定版仍为 [v1.5.2](https://github.com/Tauber01/ZENCHE/releases/tag/v1.5.2)，标签落点为 `7376cf102ec5ab14208d047f60f28941843fe1c2`

v1.4.0 已完成 AI 原图上传、服务器次数扣减/失败回滚、修图覆盖原图与生图另存的五端行为对齐；包与签名状态详见 `docs/releases/v1.4.0.md`。发布提交为 `8a13c0b`，标签为 `v1.4.0`，Release 为 [GitHub v1.4.0](https://github.com/Tauber01/ZENCHE/releases/tag/v1.4.0)。

v1.4.1 聚焦五端原生监看体验：RGB/音频波形卡、Android 波形间录制键、监看参数调节、预览点按对焦，以及移除镜头读数和监看“曝光”入口。发布提交、标签、Release、包与 SHA-256 详见 `docs/releases/v1.4.1.md`。

v1.5.0 新增五端原生外录：照片直接写入当前智能设备，PTP 视频可在机身录制同时将实时取景流式封装到 ZENCHE 文件库；Android、HarmonyOS、macOS、Windows 使用无声 Motion-JPEG AVI，iOS / iPadOS 本机与 UVC 源使用 MOV。外录接入会话命名、备份、SHA-256 和断开安全收尾，包与签名状态详见 `docs/releases/v1.5.0.md`。

v1.5.2 已完成集成并发布：五端全局状态条、五端“恢复设备码”入口、Android USB/PTP 会话降级、仓库内零依赖 AI 代理、设备码换绑协议和回环签发端已经合并。换绑只证明“旧激活码 + 当前绑定的旧设备码”凭据，成功后签发绑定新设备码的新码、继承次数与到期日并冻结旧记录；它不保证 HarmonyOS 卸载重装后的设备码本体连续。客户端入口固定使用 HTTPS，并在请求前验证旧凭据、响应后验证新码；服务端仍默认关闭，不得绕过 DNS、HTTPS、8787 明文端口收口、灰度和回滚门禁。最终独立发布审查以代码提交 `dce831d` 和文档提交 `315809b` 为对象，结论为无 P0、无 P1，5 项 P2 均不阻塞本地候选交付。Tauber 随后在 Buzz 事件 `e32e0706…f12b` 明确决定将该版本作为 GitHub 最新稳定版发布；该产品决定不改变签名、Windows 主机、实机或生产网络限制。

v1.5.2 Release 已公开 14 个附件：Android Debug 签名 APK、HarmonyOS 未签名 HAP、iOS / iPadOS unsigned IPA、macOS arm64 ad-hoc DMG、Windows x64 Setup/ZIP、精确源码 ZIP，以及七份同名 `.sha256`。发布前后均逐项核对线上大小与 GitHub SHA-256 摘要，14/14 一致；完整清单、签名和安装限制见 `docs/releases/v1.5.2.md`。GitHub 稳定通道标识不改变附件本身的验证属性：macOS 包未使用 Developer ID、未公证；Windows 包在 macOS 交叉构建，尚未在真实 Windows 主机验证安装、驱动和 SmartScreen。

v1.5.3 聚焦五端原生工作台界面：全屏监看采用影像优先的遥测 HUD、焦点十字、工具轨、真实 RGB 示波器、静音音频基线和参数托盘；拍摄页使用设备摘要、自适应参数卡与常驻拍摄操作区；编辑器使用媒体池、中央预览、工具检查器和分析示波器协作布局。新界面只复用既有真实相机、图库与编辑状态；无连接或无画面时显示 `—`、`OFFLINE` 或明确空态，不把初始化默认值当作实时遥测。iOS 拍摄会话入口、Android 编辑快捷入口和 Windows 窄窗中央预览均已纳入回归门禁；相机连接、拍摄、外录、传输、AI 激活与设备码恢复协议保持兼容。五端共享 ZENCHE 蓝、参数暖金和录制/危险红的角色约定，不复制参考产品的商标或专有图标。

v1.5.3 本地交付候选固定于代码提交 `846e1a0dc49c59b0cc5d032d84f954a98a61add0`：完整 `npm test` 256/256 通过，APK、HAP、unsigned IPA、macOS arm64 DMG、Windows x64 Setup/便携 ZIP 与源码 ZIP 共七包及同名 `.sha256` 已生成并逐个回验。它们不是商店或受信任签名包：Android 使用 Debug 证书，HarmonyOS 与 iOS 未签名，macOS 为 ad-hoc 且未公证，Windows 未做 Authenticode 且仍需真实 Windows 主机验收。文件名、字节数、SHA-256、源码快照和版本资源边界见 `docs/releases/v1.5.3.md`；该候选尚未推送、打标签、发布或部署。

v1.5.2 线上七个交付包的 SHA-256 为：Android `d90bc767d0b1b710f66e5a2b8b15a36e41932ab3a6f563f43fdbb6b6c96f87a9`；HarmonyOS `da67a6373ad4faaf64e19f512e93206f7218068b6ccd2c68d262dcc77760370f`；iOS / iPadOS `97976caca49bd9d00cdfa38f86be0615d7139952e424ffe8f6b3da7ab96712cc`；macOS `37d02a5c5f0a2220dcd9e9ccc93abd9f7e4c859be9ee26c45c587b5cec62d2c0`；Windows Setup `145fa25551ee14bd39bf84f0266aaff069625ba26e47ed38895b651f6ed276af`；Windows ZIP `04ebe53602db9ba7a8e77ed2b51ced917a982aeec379ab62c013a764ae04b57c`；源码 ZIP `676d8a2e7bf3b20c3a316cdff035bd9d48ef22d38b4b62a24232f131a5836a25`。

本次文档同步将根目录 `README.md` 的简体中文、English、日本語三段统一到 v1.5.2：更新稳定版链接、交付包文件名与 SHA-256 示例，并补充全局状态条、设备码恢复、Android 传输降级和零依赖 AI 代理说明。三语内容保持实质等价；发布属性仍以 `docs/releases/v1.5.2.md` 为准。

`NikonLink`、`com.tauber.nikonlink` 等名称是为升级、签名、偏好设置、应用数据和源码兼容保留的内部标识，不是需要继续替换的公开品牌文案。

## 2. 目标用户与核心场景

### 2.1 目标用户

- 使用 Nikon 相机进行棚拍、静物、活动、延时或视频监看的摄影师。
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
9. 在编辑器中调用 AI 修图与生图：修图会上传当前原图并在成功后覆盖原图，生图则另存为新影像；服务器负责扣减次数，失败自动回滚。

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
- **Connect**：FTP/PASV、HTTP PUT/POST、WebDAV 局域网收件箱。
- **Flow**：本地图库、树状分支、拍摄会话、RAW + JPEG 配对、评级、备份与 SHA-256。
- **Develop**：分组参数、预设、前后对比、几何调整和 JPEG 副本导出。
- **AI 工具**：AI 修图与 AI 生图、快捷预设、宽高比/分辨率选择、激活码授权与服务器端计数；开源客户端不内置模型 API 密钥。
- **Diagnose**：脱敏日志、更新检查、启动公告、防诈骗提示和问题反馈。
- **Localize**：简体中文、English、日本語运行时切换与持久化。

### 4.2 Nikon 相机支持

当前四个直接 PTP 平台的注册表对齐为 20 款机型：

- EXPEED 5：D500、D7500、D850
- EXPEED 6：Z7、Z6、Z50、D780、D6、Z5、Z7II、Z6II、Z fc、Z30
- EXPEED 7：Z9、Z8、Z f、Z6III、Z50II、Z5II、ZR

机型注册表代表设备识别和参数范围已进入源码，不代表所有固件、镜头、线材、拍摄模式与主机组合均完成实机验收。硬件结论必须以 `docs/CAMERA_TEST_CHECKLIST.md` 的实际记录为准。

### 4.3 安全与数据原则

- 产品本地优先，不把照片、CDK、账号或诊断数据默认上传到自有服务。
- FTP、HTTP 和 WebDAV 当前没有 TLS，只能在可信局域网短时启用。
- HTTP/WebDAV 使用 Basic Auth；日志必须过滤密码、令牌、序列号等敏感内容。
- 不在应用内托管第三方网盘账号；导入通过系统文件提供器或对应客户端完成。
- 重要拍摄必须保留相机存储卡，应用不能被描述为唯一备份。
- **AI 功能**：开源客户端不内置模型 API 密钥，模型请求由作者维护的代理服务器持有密钥并转发；仅发送用户主动提交的提示词与（修图模式下）当前编辑照片。AI 使用次数在服务器端计数，激活码绑定设备、每码 100 次。
- **服务器端自动更新**：`server.mjs` 提供只读 `GET /api/update`（兼容 `/api/updates`）和 `/healthz`。服务按平台/架构解析 GitHub Release 完整安装包，返回版本、下载 URL、SHA-256、公告、最低支持版本和 `update_available`；元数据按 channel 缓存，上游异常时返回带 `stale: true` 的最近缓存。五端原生客户端默认请求 `https://zenche.top/api/update`，失败后继续 MirrorChyan/GitHub 回退，不直接覆盖应用文件。
- **生产部署状态**：v1.4.1 六个官方 Release 包和六份 `.sha256` 已上传至 `101.34.255.115:/var/www/zenche.top/downloads/`；`zenche-update.service` 监听 `127.0.0.1:4174`，Nginx 反代更新 API 并提供 `/downloads/` 静态资产，`UPDATE_ASSET_BASE_URL=https://zenche.top/downloads` 已启用。服务器本机验证通过；公网 DNS 截至 2026-08-02 仍指向 `45.207.210.254`，DNS/CDN 切换到 `101.34.255.115` 后完成公网验收。

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
