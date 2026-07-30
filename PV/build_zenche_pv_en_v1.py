#!/usr/bin/env python3
"""Build the independent English ZENCHE V1 promotional video and YouTube cover."""

import hashlib
import json
import re
from pathlib import Path

from PIL import Image, ImageDraw, ImageEnhance, ImageFont
from playwright.sync_api import sync_playwright

import build_zenche_pv_v1 as base


PV_ROOT = Path(__file__).resolve().parent
PROJECT_ROOT = PV_ROOT.parent
WORK_DIR = PV_ROOT / "work"
OUTPUT_DIR = PV_ROOT / "output" / "youtube"
ASSET_DIR = PV_ROOT / "assets"
EN_PLATFORM_DIR = ASSET_DIR / "screens" / "platforms-en"
EN_TRANSFER_PATH = ASSET_DIR / "screens" / "current" / "macos-transfer-public-en.png"
EN_HTML_PATH = PV_ROOT / "zenche_pv_v1_en.html"
EN_PLATFORM_HTML_PATH = PV_ROOT / "platform_screenshots_en.html"

BASE_HTML_PATH = PV_ROOT / "zenche_pv_v1.html"
BASE_PLATFORM_HTML_PATH = PV_ROOT / "platform_screenshots.html"
APP_ICON = PROJECT_ROOT / "icons" / "icon-512.png"
LANDSCAPE_BACKGROUND = ASSET_DIR / "branding" / "publish-bg-landscape.png"

VISUAL_WEBM = WORK_DIR / "ZENCHE_PV_V1_EN_visual.webm"
VISUAL_MP4 = WORK_DIR / "ZENCHE_PV_V1_EN_visual.mp4"
BGM_PATH = WORK_DIR / "ZENCHE_PV_V1_EN_bgm_ArcLight.m4a"
FINAL_PATH = OUTPUT_DIR / "ZENCHE_PV_V1_Official_Release_EN.mp4"
POSTER_PATH = OUTPUT_DIR / "ZENCHE_PV_V1_Official_Release_EN_Poster.jpg"
CONTACT_SHEET_PATH = OUTPUT_DIR / "ZENCHE_PV_V1_Official_Release_EN_Contact_Sheet.jpg"
CHECKSUM_PATH = OUTPUT_DIR / "ZENCHE_PV_V1_Official_Release_EN.mp4.sha256"
MANIFEST_PATH = OUTPUT_DIR / "ZENCHE_PV_V1_Official_Release_EN_manifest.json"
COVER_PATH = OUTPUT_DIR / "ZENCHE_V1_Official_Release_YouTube_Cover_1920x1080.jpg"

PROJECT_NAME = "ZENCHE_Promo_PV_V1_Official_Release_EN"
YOUTUBE_TITLE = (
    "Connect the Camera. Connect the Complete Workflow. — "
    "ZENCHE V1 Official Release"
)

LATIN_REGULAR = Path("/System/Library/Fonts/HelveticaNeue.ttc")
LATIN_BOLD = Path("/System/Library/Fonts/Supplemental/Arial Bold.ttf")
HAN_RE = re.compile(r"[\u3400-\u4dbf\u4e00-\u9fff]")


PV_TRANSLATIONS = {
    '<html lang="zh-CN">': '<html lang="en">',
    "帧澈 ZENCHE 宣传 PV · V1 正式版": "ZENCHE PROMOTIONAL VIDEO · V1 OFFICIAL RELEASE",
    "ZENCHE Z 商标": "ZENCHE Z mark",
    "帧澈 <span>ZENCHE</span>": "<span>ZENCHE</span>",
    "帧澈 ZENCHE": "ZENCHE",
    "V1 正式版": "V1 OFFICIAL RELEASE",
    "跨平台相机控制与影像传输工具": "CROSS-PLATFORM CAMERA CONTROL & IMAGE TRANSFER",
    "不是投屏。<br /><em>命令直达机身。</em>": "NOT SCREEN MIRRORING.<br /><em>COMMANDS REACH THE CAMERA.</em>",
    "在支持的平台上，通过原生 USB/PTP 读取能力、调整参数、开启实时取景并触发拍摄。": "On supported platforms, native USB/PTP reads capabilities, changes settings, starts Live View, and triggers capture.",
    "原生 USB/PTP": "NATIVE USB/PTP",
    "实时取景": "LIVE VIEW",
    "远程拍摄": "REMOTE CAPTURE",
    "无浏览器中转 · 本地直连": "NO BROWSER RELAY · LOCAL DIRECT LINK",
    "不只发送命令，<br /><em>还知道问题在哪。</em>": "MORE THAN COMMANDS.<br /><em>IT KNOWS WHAT WENT WRONG.</em>",
    "连接控制链理解常见失败状态，给出恢复路径，并把关键过程留在本地诊断日志里。": "The control chain explains common failures, offers a recovery path, and keeps every key event in local diagnostics.",
    "状态可解释": "EXPLAINABLE STATE",
    "恢复有路径": "GUIDED RECOVERY",
    "故障可追踪": "TRACEABLE FAILURES",
    "识别系统占用": "DETECT SYSTEM CONFLICTS",
    "检测 PTP 服务或同类相机软件占用，明确提示释放连接。": "Finds PTP services or camera apps that hold the device and shows how to release it.",
    "PTP 会话恢复": "RESTORE PTP SESSIONS",
    "会话超时时尝试复位 USB/PTP 连接，减少反复盲目重插。": "Resets the USB/PTP link after a timeout instead of forcing blind reconnects.",
    "机身状态保护": "PROTECT THE CAMERA",
    "识别过热等异常，安全停止实时取景并记录具体原因。": "Detects overheating and other faults, stops Live View safely, and records the cause.",
    "● 已换算并写入相机": "● CONVERTED & WRITTEN TO CAMERA",
    "用快门角度，<br />直接控制 <em>Nikon。</em>": "SET A SHUTTER ANGLE.<br />CONTROL <em>NIKON DIRECTLY.</em>",
    "按视频帧率自动换算曝光时间，再写入当前机身。180° 语言，真正落到相机参数。": "Frame rate becomes exposure time and is written to the camera. A 180° workflow becomes a real camera setting.",
    "角度优先": "ANGLE FIRST",
    "帧率联动": "FRAME-RATE LINKED",
    "机身写入": "CAMERA WRITE",
    "监看可以更强，<br /><em>原片保持原样。</em>": "STRONGER MONITORING.<br /><em>ORIGINALS STAY UNTOUCHED.</em>",
    "自定义 .cube LUT 与条纹图案只处理本地预览，不写入原片，也不改变机身的视频设置。": "Custom .cube LUTs and zebra overlays affect local preview only—never the original file or in-camera video settings.",
    "自定义 .cube LUT": "CUSTOM .CUBE LUT",
    "条纹图案": "ZEBRA OVERLAY",
    "macOS · 原生监看": "macOS · NATIVE MONITOR",
    "帧澈 ZENCHE macOS 原生照片拍摄界面": "ZENCHE macOS native photo capture interface",
    "macOS · 无线收件箱": "macOS · WIRELESS INBOX",
    "帧澈 ZENCHE macOS 无线收件箱界面": "ZENCHE macOS wireless inbox interface",
    "三种协议，<br /><em>汇入一个文件库。</em>": "THREE PROTOCOLS.<br /><em>ONE LOCAL LIBRARY.</em>",
    "相机、手机、电脑或自动化工具都能把素材送进帧澈；不必适配单一厂商云，接收后立即进入本地工作流。": "Cameras, phones, computers, and automation tools all feed ZENCHE. No vendor cloud required—media enters the local workflow on arrival.",
    "多种来源，<br /><em>一个本地文件库。</em>": "MANY SOURCES.<br /><em>ONE LOCAL LIBRARY.</em>",
    "联机拍摄、无线收件箱、系统相册和文件选择器汇入统一入口；照片与视频到库即可浏览、预览和分享。": "Connected capture, wireless inboxes, system photos, and file pickers share one entry point. Browse, preview, and share on arrival.",
    "原位置读取": "READ IN PLACE",
    "本地保存": "SAVE LOCALLY",
    "系统分享": "SYSTEM SHARE",
    "帧澈 ZENCHE 本地文件库": "ZENCHE LOCAL LIBRARY",
    "联机拍摄": "TETHERED CAPTURE",
    "拍摄完成后保存到本地库": "Save each capture to the local library",
    "无线接收": "WIRELESS INTAKE",
    "FTP / HTTP / WebDAV 自动入库": "FTP / HTTP / WebDAV auto-import",
    "系统相册": "SYSTEM PHOTOS",
    "直接读取缩略图与预览": "Read thumbnails and previews directly",
    "文件选择器": "FILE PICKER",
    "从设备或网盘下载目录加入": "Add files from device or cloud-drive folders",
    "照片浏览": "PHOTO BROWSER",
    "缩略图与大图预览": "Thumbnails and full-size previews",
    "视频播放": "VIDEO PLAYBACK",
    "本地媒体直接打开": "Open local media directly",
    "交给平台原生分享面板": "Use the platform-native share sheet",
    "来源可见": "VISIBLE SOURCES",
    "系统相册与应用文件清晰区分": "Keep system photos and app files distinct",
    "创作数据，<em>留在你手里。</em>": "YOUR CREATIVE DATA<br /><em>STAYS IN YOUR HANDS.</em>",
    "不用注册帧澈云账号，也不用把原片先上传再下载；素材到库即可整理，诊断日志同样留在本地。": "No ZENCHE cloud account. No upload-then-download detour. Organize media on arrival; diagnostics stay local too.",
    "云账号": "CLOUD ACCOUNT",
    "无需登录即可进入工作流": "No sign-in required",
    "本地照片库": "LOCAL PHOTO LIBRARY",
    "拍摄、接收、整理都在设备上": "Capture, receive, and organize on device",
    "可诊断": "DIAGNOSABLE",
    "连接、拍摄与传输日志可追踪": "Trace connection, capture, and transfer logs",
    "桌面创作，<em>看得见完整控制链。</em>": "DESKTOP CREATION.<br /><em>SEE THE FULL CONTROL CHAIN.</em>",
    "macOS 与 Windows 都为桌面工作流重新组织监看、参数控制、文件管理和诊断信息。": "macOS and Windows reorganize monitoring, camera settings, file management, and diagnostics for desktop workflows.",
    "macOS 原生界面": "macOS native interface",
    "照片拍摄与实时取景": "Photo capture & Live View",
    "Windows 原生界面预览": "Windows native interface preview",
    "桌面参数面板与本地文件库": "Desktop controls & local library",
    "移动三端，<em>各用自己的原生语言。</em>": "THREE MOBILE PLATFORMS.<br /><em>NATIVE BY DESIGN.</em>",
    "Android、HarmonyOS 与 iOS / iPadOS 共享创作逻辑，同时遵循各平台控件、权限和硬件能力边界。": "Android, HarmonyOS, and iOS/iPadOS share the same creative logic while respecting each platform’s UI, permissions, and hardware limits.",
    "Android 原生界面预览": "Android native interface preview",
    "原生 Android · USB/PTP 联机拍摄": "Native Android · USB/PTP tethered capture",
    "HarmonyOS 原生界面预览": "HarmonyOS native interface preview",
    "USB Host 与本地工作流": "USB Host & local workflow",
    "iOS 和 iPadOS 原生界面": "iOS and iPadOS native interface",
    "系统镜头 / 外接 UVC / 无线收件箱 · 无通用 Nikon USB/PTP": "System camera / external UVC / wireless inbox · no general Nikon USB/PTP",
    "支持机型，<em>清清楚楚列出来。</em>": "SUPPORTED CAMERAS.<br /><em>CLEARLY LISTED.</em>",
    "内置 17 款 Nikon 相机设备档案，按 USB Product ID 与机型名称识别；不同固件、镜头和 USB 环境仍需实机验证。": "Seventeen built-in Nikon profiles match USB Product IDs and model names. Firmware, lens, and USB combinations still require device validation.",
    "macOS / Android：原生 USB/PTP": "macOS / Android: NATIVE USB/PTP",
    "Windows / HarmonyOS：实现完成，待真机验收": "Windows / HarmonyOS: IMPLEMENTED · DEVICE VALIDATION PENDING",
    "iOS / iPadOS：公开接口不提供通用 Nikon USB/PTP": "iOS / iPadOS: NO GENERAL NIKON USB/PTP IN PUBLIC APIS",
    "没有订阅门槛，<em>也没有黑盒。</em>": "NO SUBSCRIPTION GATE.<br /><em>NO BLACK BOX.</em>",
    "免费使用，源代码开放。创作者不被订阅锁住，开发者也能审阅控制链、扩展机型与共同改进工作流。": "Free to use and open source. Creators avoid subscription lock-in; developers can inspect the control chain, add models, and improve the workflow.",
    "<div class=\"value\">¥0</div>": "<div class=\"value\">$0</div>",
    "免费": "FREE",
    "无需订阅，直接进入创作。": "No subscription. Start creating.",
    "开源": "OPEN SOURCE",
    "代码可审阅、可扩展、可共建。": "Review, extend, and build together.",
    "文档、源代码与下载，<em>都在这里。</em>": "DOCS, SOURCE, DOWNLOADS.<br /><em>ALL IN ONE PLACE.</em>",
    "帧澈 ZENCHE · 开放项目": "ZENCHE · OPEN PROJECT",
    "项目主页": "PROJECT HOME",
    "产品说明、支持机型、构建文档与完整源代码。": "Product guide, camera support, build docs, and complete source.",
    "版本下载": "RELEASE DOWNLOADS",
    "获取各平台发布包、版本说明与更新记录。": "Platform packages, release notes, and changelogs.",
    "今天可用，<em>明天继续进化。</em>": "READY TODAY.<br /><em>STILL EVOLVING TOMORROW.</em>",
    "更多机型与固件": "MORE CAMERAS & FIRMWARE",
    "持续扩展 Nikon 机型识别、能力映射与真实设备验证覆盖。": "Expand Nikon recognition, capability maps, and real-device validation.",
    "更稳的跨平台控制": "MORE RELIABLE CROSS-PLATFORM CONTROL",
    "继续提升 PTP 会话、无线传输和五端行为的一致性与可诊断性。": "Improve PTP sessions, wireless transfer, and consistent diagnostics across five platforms.",
    "更强的本地工作流": "STRONGER LOCAL WORKFLOWS",
    "围绕素材整理、自动化接口与开放扩展，连接更多创作环节。": "Connect more creative steps through media organization, automation APIs, and open extensions.",
    "未来方向将依据设备验证、平台能力与社区反馈持续调整": "ROADMAP EVOLVES WITH DEVICE VALIDATION, PLATFORM CAPABILITIES, AND COMMUNITY FEEDBACK",
    "连接相机，也连接完整工作流": "CONNECT THE CAMERA. CONNECT THE COMPLETE WORKFLOW.",
    "帧澈": "ZENCHE",
}


PLATFORM_TRANSLATIONS = {
    '<html lang="zh-CN">': '<html lang="en">',
    "帧澈 ZENCHE 平台界面预览": "ZENCHE PLATFORM INTERFACE PREVIEWS",
    "帧澈 ZENCHE": "ZENCHE",
    "Android 原生版": "Android Native App",
    "HarmonyOS 原生版": "HarmonyOS Native App",
    "iOS / iPadOS 原生版": "iOS / iPadOS Native App",
    "连接相机": "Connect Camera",
    "选择相机": "Select Camera",
    "设置": "Settings",
    "照片拍摄": "Photo Capture",
    "联机拍摄": "Connected Capture",
    "视频监看": "Video Monitor",
    "文件与传输": "Files & Transfer",
    "快门、曝光、对焦、白平衡与拍摄模式集中在当前页面": "Shutter, exposure, focus, white balance, and shooting mode in one view",
    "原生 USB Host、相机实时取景与本地文件工作流": "Native USB Host, camera Live View, and a local file workflow",
    "使用系统镜头、外接 UVC 相机与无线收件箱进入同一套本地工作流": "System cameras, external UVC devices, and a wireless inbox feed one local workflow",
    "全屏": "Fullscreen",
    "连接支持的 Nikon 相机后开启实时取景": "Connect a supported Nikon camera to start Live View",
    "连接相机后开启实时取景": "Connect the camera to start Live View",
    "等待相机画面": "Waiting for camera",
    "等待视频设备": "Waiting for video device",
    "照片实时取景 · JPEG": "PHOTO LIVE VIEW · JPEG",
    "相机原生 JPEG · 本地预览": "CAMERA-NATIVE JPEG · LOCAL PREVIEW",
    "实时取景": "Live View",
    "开启取景": "Start Live View",
    "打开取景": "Open Live View",
    "拍摄照片": "Capture Photo",
    "拍摄": "Capture",
    "专业参数": "Pro Controls",
    "相机参数": "Camera Controls",
    "本地工作流": "Local Workflow",
    "拍摄模式": "Shooting Mode",
    "M · 手动": "M · Manual",
    "快门速度": "Shutter Speed",
    "快门": "Shutter",
    "光圈": "Aperture",
    "ISO 感光度": "ISO",
    "曝光补偿": "Exposure Comp.",
    "对焦模式": "Focus Mode",
    "照片来源": "Photo Sources",
    "系统相册 / 文件": "System Photos / Files",
    "文件处理": "File Handling",
    "本地优先": "Local First",
    "无线收件箱": "Wireless Inbox",
    "照片": "Photos",
    "视频": "Video",
    "文件": "Files",
    "未连接 · USB/PTP": "DISCONNECTED · USB/PTP",
    "未连接 · CAMERA / UVC": "DISCONNECTED · CAMERA / UVC",
    "未连接 · macOS USB/PTP": "DISCONNECTED · macOS USB/PTP",
    "未连接 · WINDOWS USB/PTP": "DISCONNECTED · WINDOWS USB/PTP",
    "未连接": "DISCONNECTED",
    "0 张": "0 PHOTOS",
    "工作区": "WORKSPACE",
    "ZENCHE · V1 正式版": "ZENCHE · V1 OFFICIAL RELEASE",
    "原生 SwiftUI / AppKit": "NATIVE SWIFTUI / APPKIT",
    "照片保存在“图片\\帧澈”": 'PHOTOS SAVED TO "PICTURES\\ZENCHE"',
    "照片设置": "Photo Settings",
    "USB/PTP · 支持 EXPEED 6 / 7": "USB/PTP · EXPEED 6 / 7",
    "本次照片 · 0 张": "SESSION PHOTOS · 0",
}


def apply_translations(source: Path, destination: Path, mapping: dict[str, str]) -> None:
    content = source.read_text(encoding="utf-8")
    for chinese, english in sorted(mapping.items(), key=lambda item: len(item[0]), reverse=True):
        content = content.replace(chinese, english)

    # English layouts need slightly tighter headlines and more forgiving card copy.
    if source == BASE_HTML_PATH:
        content = content.replace(
            "</style>",
            """
      html, body {
        font-family: "Helvetica Neue", Arial, sans-serif;
      }
      .headline {
        font-size: 62px;
        letter-spacing: -0.035em;
      }
      .subhead {
        font-size: 23px;
        line-height: 1.48;
      }
      .resilience-card p,
      .library-source small,
      .library-action small,
      .future-card p {
        line-height: 1.35;
      }
      .camera-footnote {
        font-size: 15px;
      }
    </style>""",
        )
        content = content.replace(
            "./assets/screens/platforms/",
            "./assets/screens/platforms-en/",
        )
        content = content.replace(
            "./assets/screens/current/macos-transfer-public.png",
            "./assets/screens/current/macos-transfer-public-en.png",
        )

    remaining = sorted(set(HAN_RE.findall(content)))
    if remaining:
        raise RuntimeError(
            f"Untranslated Han characters remain in {source.name}: {''.join(remaining)}"
        )
    destination.write_text(content, encoding="utf-8")


def render_english_platform_screenshots() -> None:
    EN_PLATFORM_DIR.mkdir(parents=True, exist_ok=True)
    targets = {
        "android": (1080, 1920),
        "harmonyos": (1080, 1920),
        "ios-ipados": (1206, 2622),
        "macos": (1600, 1104),
        "windows": (1600, 1000),
    }
    base_url = EN_PLATFORM_HTML_PATH.resolve().as_uri()
    with sync_playwright() as playwright:
        browser = playwright.chromium.launch(headless=True)
        for platform, (width, height) in targets.items():
            page = browser.new_page(viewport={"width": width, "height": height})
            page.goto(f"{base_url}?platform={platform}")
            page.wait_for_timeout(300)
            page.screenshot(
                path=str(EN_PLATFORM_DIR / f"{platform}.png"),
                full_page=False,
            )
            page.close()
        browser.close()


def load_font(path: Path, size: int) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(str(path), size=size)


def paste_icon(canvas: Image.Image, box: tuple[int, int, int, int]) -> None:
    icon = Image.open(APP_ICON).convert("RGB").resize(
        (box[2] - box[0], box[3] - box[1]),
        Image.Resampling.LANCZOS,
    )
    mask = Image.new("L", icon.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        (0, 0, icon.width, icon.height),
        radius=max(8, icon.width // 5),
        fill=255,
    )
    canvas.paste(icon, (box[0], box[1]), mask)


def build_english_transfer_screen() -> None:
    width, height = 2582, 1782
    canvas = Image.new("RGB", (width, height), "#f4f6fa")
    draw = ImageDraw.Draw(canvas)
    regular_26 = load_font(LATIN_REGULAR, 26)
    regular_30 = load_font(LATIN_REGULAR, 30)
    regular_34 = load_font(LATIN_REGULAR, 34)
    bold_28 = load_font(LATIN_BOLD, 28)
    bold_34 = load_font(LATIN_BOLD, 34)
    bold_44 = load_font(LATIN_BOLD, 44)
    bold_58 = load_font(LATIN_BOLD, 58)

    draw.rounded_rectangle((0, 0, width - 1, height - 1), radius=30, fill="#f4f6fa", outline="#cfd5df", width=2)
    draw.rectangle((0, 0, width, 74), fill="#ffffff")
    draw.ellipse((18, 19, 44, 45), fill="#ff5f57")
    draw.ellipse((64, 19, 90, 45), fill="#febc2e")
    draw.ellipse((110, 19, 136, 45), fill="#28c840")
    draw.text((165, 20), "ZENCHE", fill="#555b66", font=regular_30)

    draw.rectangle((0, 74, width, 210), fill="#ffffff")
    paste_icon(canvas, (40, 96, 128, 184))
    draw.text((150, 102), "ZENCHE", fill="#20242c", font=bold_44)
    draw.text((150, 156), "macOS Native App", fill="#687387", font=regular_26)
    draw.rounded_rectangle((2140, 112, 2345, 174), radius=14, fill="#1264d9")
    draw.text((2172, 126), "Connect Camera", fill="#ffffff", font=bold_28)
    draw.rounded_rectangle((2360, 112, 2515, 174), radius=14, fill="#ffffff", outline="#d9dee8", width=2)
    draw.text((2395, 126), "Settings", fill="#262b35", font=bold_28)

    draw.rectangle((0, 210, 185, height - 62), fill="#ffffff")
    nav_items = ["Capture", "Monitor", "Files", "Transfer"]
    for index, label in enumerate(nav_items):
        y = 278 + index * 150
        if label == "Transfer":
            draw.rounded_rectangle((20, y - 25, 165, y + 65), radius=18, fill="#dceaff")
            color = "#1264d9"
        else:
            color = "#667085"
        draw.text((55, y), label, fill=color, font=bold_28)

    draw.text((245, 275), "Wireless Transfer", fill="#20242c", font=bold_58)
    draw.text(
        (245, 365),
        "Receive JPEG, NEF, and HEIF from cameras over Wi-Fi.",
        fill="#606d82",
        font=regular_34,
    )

    cards = [
        (245, 470, 744, 725, "Local Library", "0 files"),
        (790, 470, 1289, 725, "Wireless Inbox", "Ready when started"),
    ]
    for x1, y1, x2, y2, title, value in cards:
        draw.rounded_rectangle((x1, y1, x2, y2), radius=24, fill="#ffffff", outline="#d9dee8", width=2)
        draw.text((x1 + 40, y1 + 68), title, fill="#20242c", font=bold_34)
        draw.text((x1 + 40, y1 + 132), value, fill="#687387", font=regular_30)

    draw.rounded_rectangle((245, 775, 2520, 1450), radius=26, fill="#ffffff", outline="#d9dee8", width=2)
    draw.text((285, 824), "Camera FTP Settings", fill="#20242c", font=bold_44)
    draw.text((285, 882), "For direct camera hotspots or the same local network", fill="#606d82", font=regular_26)
    draw.rounded_rectangle((2190, 820, 2470, 892), radius=15, fill="#1264d9")
    draw.text((2228, 837), "Start Receiver", fill="#ffffff", font=bold_28)

    rows = [
        ("Server Type", "FTP"),
        ("Server Address", "Shown after launch"),
        ("Port", "2121"),
        ("User Name", "Auto-generated"),
        ("Password", "Protected"),
        ("PASV Mode", "On"),
    ]
    row_y = 960
    for label, value in rows:
        draw.line((285, row_y - 22, 2470, row_y - 22), fill="#e7eaf0", width=2)
        draw.text((285, row_y), label, fill="#606d82", font=regular_30)
        value_box = draw.textbbox((0, 0), value, font=bold_28)
        draw.text((2470 - (value_box[2] - value_box[0]), row_y), value, fill="#252b35", font=bold_28)
        row_y += 72

    draw.rectangle((0, height - 62, width, height), fill="#0c1119")
    draw.text((48, height - 45), "DISCONNECTED", fill="#bdc6d4", font=regular_26)
    draw.text((980, height - 45), "USB/PTP · EXPEED 6 / 7", fill="#bdc6d4", font=regular_26)
    draw.text((2210, height - 45), "SESSION PHOTOS · 0", fill="#bdc6d4", font=regular_26)

    EN_TRANSFER_PATH.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(EN_TRANSFER_PATH, optimize=True)


def fit_cover(image: Image.Image, size: tuple[int, int]) -> Image.Image:
    scale = max(size[0] / image.width, size[1] / image.height)
    resized = image.resize(
        (round(image.width * scale), round(image.height * scale)),
        Image.Resampling.LANCZOS,
    )
    left = (resized.width - size[0]) // 2
    top = (resized.height - size[1]) // 2
    return resized.crop((left, top, left + size[0], top + size[1]))


def build_youtube_cover() -> None:
    canvas = fit_cover(Image.open(LANDSCAPE_BACKGROUND).convert("RGB"), (1920, 1080))
    canvas = ImageEnhance.Brightness(canvas).enhance(0.76)
    shade = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    shade_draw = ImageDraw.Draw(shade, "RGBA")
    for x in range(canvas.width):
        alpha = round(165 * (1 - min(1, x / 1300)))
        shade_draw.line((x, 0, x, canvas.height), fill=(2, 6, 13, alpha))
    canvas = Image.alpha_composite(canvas.convert("RGBA"), shade).convert("RGB")
    draw = ImageDraw.Draw(canvas, "RGBA")

    draw.rounded_rectangle(
        (80, 85, 1185, 985),
        radius=50,
        fill=(3, 8, 17, 188),
        outline=(77, 141, 255, 88),
        width=3,
    )
    paste_icon(canvas, (112, 118, 260, 266))
    draw.text((295, 125), "ZENCHE", fill="#f7f9ff", font=load_font(LATIN_BOLD, 78))
    draw.text((300, 218), "CAPTURE · CONNECT · FLOW", fill="#4d8dff", font=load_font(LATIN_BOLD, 28))

    draw.text((112, 382), "CONNECT THE CAMERA.", fill="#f7f9ff", font=load_font(LATIN_BOLD, 72))
    draw.text((112, 478), "CONNECT THE COMPLETE", fill="#f7f9ff", font=load_font(LATIN_BOLD, 72))
    draw.text((112, 566), "WORKFLOW.", fill="#f7f9ff", font=load_font(LATIN_BOLD, 72))
    draw.rounded_rectangle((112, 682, 655, 770), radius=42, fill=(255, 210, 41, 235))
    draw.text((145, 701), "V1 OFFICIAL RELEASE", fill="#05070b", font=load_font(LATIN_BOLD, 39))
    draw.text(
        (112, 846),
        "CROSS-PLATFORM CAMERA CONTROL & IMAGE TRANSFER",
        fill="#b7c2d3",
        font=load_font(LATIN_BOLD, 27),
    )
    COVER_PATH.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(COVER_PATH, quality=95, subsampling=0, optimize=True)


def configure_base_builder() -> None:
    base.WORK_DIR = WORK_DIR
    base.OUTPUT_DIR = OUTPUT_DIR
    base.HTML_PATH = EN_HTML_PATH
    base.VISUAL_WEBM = VISUAL_WEBM
    base.VISUAL_MP4 = VISUAL_MP4
    base.BGM_PATH = BGM_PATH
    base.FINAL_PATH = FINAL_PATH
    base.POSTER_PATH = POSTER_PATH
    base.CONTACT_SHEET_PATH = CONTACT_SHEET_PATH
    base.CHECKSUM_PATH = CHECKSUM_PATH
    base.MANIFEST_PATH = MANIFEST_PATH
    base.PROJECT_NAME = PROJECT_NAME
    base.REQUIRED_ASSETS = [
        EN_HTML_PATH,
        base.BGM_SOURCE,
        ASSET_DIR / "branding" / "zenche-z-mark.svg",
        EN_TRANSFER_PATH,
        EN_PLATFORM_DIR / "macos.png",
        EN_PLATFORM_DIR / "android.png",
        EN_PLATFORM_DIR / "windows.png",
        EN_PLATFORM_DIR / "harmonyos.png",
        EN_PLATFORM_DIR / "ios-ipados.png",
    ]


def mux_final_english() -> None:
    base.run(
        [
            "ffmpeg",
            "-y",
            "-i",
            VISUAL_MP4,
            "-i",
            BGM_PATH,
            "-map",
            "0:v:0",
            "-map",
            "1:a:0",
            "-t",
            str(base.DURATION),
            "-c:v",
            "copy",
            "-c:a",
            "aac",
            "-b:a",
            "192k",
            "-movflags",
            "+faststart",
            "-metadata",
            f"title={YOUTUBE_TITLE}",
            "-metadata",
            "comment=BGM: Battleplan Arclight PV; Version: V1 Official Release; Language: English",
            "-metadata:s:a:0",
            "title=Battleplan Arclight PV BGM",
            FINAL_PATH,
        ]
    )


def write_english_manifest(draft_result: dict, probe: dict) -> str:
    digest = hashlib.sha256(FINAL_PATH.read_bytes()).hexdigest()
    CHECKSUM_PATH.write_text(f"{digest}  {FINAL_PATH.name}\n", encoding="utf-8")
    manifest = {
        "product": "ZENCHE",
        "product_descriptor": "Cross-platform camera control & image transfer tool",
        "brand_line": "Capture · Connect · Flow",
        "slogan": "Connect the camera. Connect the complete workflow.",
        "asset": "Promotional PV",
        "language": "English",
        "version_label": "V1 Official Release",
        "duration_seconds": base.DURATION,
        "resolution": f"{base.WIDTH}x{base.HEIGHT}",
        "fps": base.FPS,
        "youtube_title": YOUTUBE_TITLE,
        "youtube_cover": str(COVER_PATH.resolve()),
        "beat_sync": {
            "tempo_bpm": 105.469,
            "beat_period_seconds": 0.5689,
            "first_beat_seconds": 0.4644,
            "edit_pattern": "scene changes on four-beat bar starts; internal reveals on beat subdivisions",
        },
        "bgm": {
            "label": "Battleplan Arclight PV",
            "source": str(base.BGM_SOURCE.resolve()),
            "source_offset_seconds": base.BGM_START,
            "source_end_seconds": round(base.BGM_START + base.DURATION, 3),
            "looped": False,
            "playback": "single continuous pass",
        },
        "links_visible_in_video": False,
        "final_video": str(FINAL_PATH.resolve()),
        "sha256": digest,
        "jianying_project": PROJECT_NAME,
        "jianying_save_result": draft_result,
        "probe": probe,
    }
    MANIFEST_PATH.write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    return digest


def main() -> None:
    WORK_DIR.mkdir(parents=True, exist_ok=True)
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    apply_translations(BASE_PLATFORM_HTML_PATH, EN_PLATFORM_HTML_PATH, PLATFORM_TRANSLATIONS)
    apply_translations(BASE_HTML_PATH, EN_HTML_PATH, PV_TRANSLATIONS)
    render_english_platform_screenshots()
    build_english_transfer_screen()
    build_youtube_cover()
    configure_base_builder()
    base.require_assets()
    base.render_visual()
    base.build_audio()
    mux_final_english()
    base.create_review_images()
    draft_result = base.create_jianying_draft()
    probe = base.probe_output()
    digest = write_english_manifest(draft_result, probe)
    print(
        json.dumps(
            {
                "status": "SUCCESS",
                "language": "English",
                "version": "V1 Official Release",
                "youtube_title": YOUTUBE_TITLE,
                "final_video": str(FINAL_PATH.resolve()),
                "cover": str(COVER_PATH.resolve()),
                "poster": str(POSTER_PATH.resolve()),
                "contact_sheet": str(CONTACT_SHEET_PATH.resolve()),
                "sha256": digest,
                "draft": draft_result,
                "probe": probe,
            },
            ensure_ascii=False,
            indent=2,
        )
    )


if __name__ == "__main__":
    main()
