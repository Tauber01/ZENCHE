# 帧澈 ZENCHE 宣传 PV

这里集中存放帧澈 ZENCHE 宣传 PV 的脚本、画面素材、BGM、历史版本和最终输出。

## 品牌固定文案

- 中文名：`帧澈`
- 国际名：`ZENCHE`
- 产品说明：`跨平台相机控制与影像传输工具`
- 英文品牌语：`Capture · Connect · Flow`
- 标语：`连接相机，也连接完整工作流`
- 商标：`assets/branding/zenche-z-mark.svg`（蓝色几何 Z 正式标识）

## 当前正式版

- 版本标识：`V1 正式版`
- 画幅：1920 × 1080，30 fps，84.4 秒
- 节奏：105.47 BPM；复杂章节占 3 小节，简洁章节占 2 小节
- 项目网页：`https://github.com/Tauber01/ZENCHE`
- 版本下载：`https://github.com/Tauber01/ZENCHE/releases`
- BGM：弧光作战 PV（从有效音乐起点连续播放一次，不循环）
- 最终成片：`output/帧澈_ZENCHE_PV_V1_正式版.mp4`
- 剪映草稿：`帧澈_ZENCHE_宣传PV_V1_正式版`

## 内容重点

1. 原生 USB/PTP 直连与机身控制
2. macOS 控制链的占用识别、PTP 会话恢复、过热保护与诊断留痕
3. 快门角度按帧率换算并写入机身曝光时间
4. 自定义 `.cube` LUT 与条纹图案仅作用于监看，不写入原片
5. FTP、HTTP 与 WebDAV 三协议汇入同一本地文件库
6. 联机拍摄、无线接收、系统相册与文件选择器组成统一的本地文件管理入口
7. 本地优先、无需云账号、诊断日志可追踪
8. macOS、Windows 两个桌面端的原生界面展示
9. Android、HarmonyOS、iOS / iPadOS 三个移动端的原生界面展示
10. 17 款 EXPEED 6 / 7 相机设备档案与各平台 USB/PTP 能力边界
11. 免费、开源
12. 项目主页与 Releases 下载链接
13. 更多机型、更稳定的跨平台控制和更强本地工作流的未来方向

## 支持机型

- EXPEED 6：Z7、Z6、Z50、D780、D6、Z5、Z7II、Z6II、Z fc、Z30
- EXPEED 7：Z9、Z8、Z f、Z6III、Z50II、Z5II、ZR

macOS 与 Android 当前提供原生 USB/PTP；Windows 与 HarmonyOS 的控制实现仍需真机
验收；iOS / iPadOS 的公开接口不提供通用 Nikon USB/PTP 厂商控制。

## 五端界面素材

- `assets/screens/platforms/macos.png`：依据当前 macOS 原生界面结构生成的等比例预览
- `assets/screens/platforms/ios-ipados.png`：依据当前 iOS / iPadOS 原生界面结构生成的等比例预览
- `assets/screens/platforms/android.png`：依据当前 Android 原生界面代码生成的等比例预览
- `assets/screens/platforms/harmonyos.png`：依据当前 ArkUI 界面代码生成的等比例预览
- `assets/screens/platforms/windows.png`：依据当前 WPF 界面代码生成的等比例预览

## 目录

- `build_zenche_pv_v1.py`：一键生成视觉、BGM、成片、海报、联系表和剪映草稿
- `zenche_pv_v1.html`：Web VFX 时间线与视觉源文件
- `platform_screenshots.html`：五个原生平台的界面预览源文件
- `render_platform_screenshots.py`：生成五端等比例界面预览图
- `render_pv_previews.py`：按节拍时间点生成宣传片审阅帧
- `analyze_bgm_beats.py`：分析 BGM 主拍、强起音与四拍小节落点
- `render_pv_previews.py`：按确定时间点生成节奏与版式审阅帧
- `assets/`：BGM 与界面画面
- `work/`：渲染中间文件
- `output/`：最终交付文件
- `archive/`：旧版 PV 源文件、成片与审阅帧

## 重新生成

在项目根目录运行：

```bash
JY_SKILL_ROOT=/Users/tauber/.codex/skills/jianying-editor \
python3 PV/build_zenche_pv_v1.py
```
