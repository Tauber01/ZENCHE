#!/usr/bin/env python3
import hashlib
import json
import os
import subprocess
import sys
from pathlib import Path


CURRENT_DIR = os.path.dirname(os.path.abspath(__file__))
ENV_ROOT = os.getenv("JY_SKILL_ROOT", "").strip()
SKILL_CANDIDATES = [
    ENV_ROOT,
    os.path.join(CURRENT_DIR, ".agent", "skills", "jianying-editor"),
    os.path.join(CURRENT_DIR, ".trae", "skills", "jianying-editor"),
    os.path.join(CURRENT_DIR, ".claude", "skills", "jianying-editor"),
    os.path.join(CURRENT_DIR, "skills", "jianying-editor"),
    os.path.abspath(".agent/skills/jianying-editor"),
    os.path.dirname(CURRENT_DIR),
    os.path.expanduser("~/.codex/skills/jianying-editor"),
]

SCRIPTS_PATH = None
ATTEMPTED = []
for candidate in SKILL_CANDIDATES:
    if not candidate:
        continue
    candidate = os.path.abspath(candidate)
    ATTEMPTED.append(candidate)
    if os.path.exists(os.path.join(candidate, "scripts", "jy_wrapper.py")):
        SCRIPTS_PATH = os.path.join(candidate, "scripts")
        SKILL_ROOT = candidate
        break

if not SCRIPTS_PATH:
    raise ImportError(
        "Could not find jianying-editor/scripts/jy_wrapper.py\nTried:\n- "
        + "\n- ".join(ATTEMPTED)
    )

if SCRIPTS_PATH not in sys.path:
    sys.path.insert(0, SCRIPTS_PATH)

if sys.platform == "darwin":
    HOMEBREW_BIN = "/opt/homebrew/bin"
    if HOMEBREW_BIN not in os.environ.get("PATH", ""):
        os.environ["PATH"] = HOMEBREW_BIN + ":" + os.environ.get("PATH", "")

from jy_wrapper import JyProject
from web_recorder import record_web_animation


PV_ROOT = Path(CURRENT_DIR)
WORK_DIR = PV_ROOT / "work"
OUTPUT_DIR = PV_ROOT / "output"
HTML_PATH = PV_ROOT / "zenche_pv_v1.html"
PLATFORM_SCREENSHOT_RENDERER = PV_ROOT / "render_platform_screenshots.py"
BGM_SOURCE = PV_ROOT / "assets" / "bgm" / "ZENCHE_BGM_BATTLEPLAN_ARCLIGHT.m4s"
VISUAL_WEBM = WORK_DIR / "ZENCHE_PV_V1_visual.webm"
VISUAL_MP4 = WORK_DIR / "ZENCHE_PV_V1_visual.mp4"
BGM_PATH = WORK_DIR / "ZENCHE_PV_V1_bgm_弧光作战.m4a"
FINAL_PATH = OUTPUT_DIR / "帧澈_ZENCHE_PV_V1_正式版.mp4"
POSTER_PATH = OUTPUT_DIR / "帧澈_ZENCHE_PV_V1_正式版_海报.jpg"
CONTACT_SHEET_PATH = OUTPUT_DIR / "帧澈_ZENCHE_PV_V1_正式版_联系表.jpg"
CHECKSUM_PATH = OUTPUT_DIR / "帧澈_ZENCHE_PV_V1_正式版.mp4.sha256"
MANIFEST_PATH = OUTPUT_DIR / "帧澈_ZENCHE_PV_V1_正式版_manifest.json"

PROJECT_NAME = "帧澈_ZENCHE_宣传PV_V1_正式版"
DURATION = 102.7
BGM_START = 5.1
WIDTH = 1920
HEIGHT = 1080
FPS = 30

REQUIRED_ASSETS = [
    HTML_PATH,
    PLATFORM_SCREENSHOT_RENDERER,
    BGM_SOURCE,
    PV_ROOT / "assets" / "branding" / "zenche-z-mark.svg",
    PV_ROOT / "assets" / "screens" / "current" / "macos-transfer.png",
    PV_ROOT / "assets" / "screens" / "platforms" / "macos.png",
    PV_ROOT / "assets" / "screens" / "platforms" / "android.png",
    PV_ROOT / "assets" / "screens" / "platforms" / "windows.png",
    PV_ROOT / "assets" / "screens" / "platforms" / "harmonyos.png",
    PV_ROOT / "assets" / "screens" / "platforms" / "ios-ipados.png",
]


def run(command):
    print("Running:", " ".join(str(part) for part in command[:8]), "...")
    subprocess.run([str(part) for part in command], check=True)


def require_assets():
    missing = [str(path) for path in REQUIRED_ASSETS if not path.exists()]
    if missing:
        raise FileNotFoundError("Missing required PV assets:\n- " + "\n- ".join(missing))


def render_platform_screenshots():
    run([sys.executable, PLATFORM_SCREENSHOT_RENDERER])


def render_visual():
    if VISUAL_WEBM.exists():
        VISUAL_WEBM.unlink()

    ok = record_web_animation(
        str(HTML_PATH),
        str(VISUAL_WEBM),
        max_duration=int(DURATION + 8),
    )
    if not ok or not VISUAL_WEBM.exists():
        raise RuntimeError("Web animation recording failed.")

    run(
        [
            "ffmpeg",
            "-y",
            "-i",
            VISUAL_WEBM,
            "-t",
            str(DURATION),
            "-an",
            "-vf",
            f"scale={WIDTH}:{HEIGHT}:flags=lanczos,fps={FPS},format=yuv420p",
            "-c:v",
            "libx264",
            "-preset",
            "medium",
            "-crf",
            "18",
            "-movflags",
            "+faststart",
            VISUAL_MP4,
        ]
    )


def build_audio():
    duration_result = subprocess.run(
        [
            "ffprobe",
            "-v",
            "error",
            "-show_entries",
            "format=duration",
            "-of",
            "default=noprint_wrappers=1:nokey=1",
            str(BGM_SOURCE),
        ],
        check=True,
        capture_output=True,
        text=True,
    )
    source_duration = float(duration_result.stdout.strip())
    usable_duration = source_duration - BGM_START
    mix_tail = (
        "loudnorm=I=-16:TP=-1.5:LRA=11,"
        "afade=t=in:st=0:d=1.0,"
        f"afade=t=out:st={DURATION - 3}:d=3"
    )

    if usable_duration >= DURATION:
        run(
            [
                "ffmpeg",
                "-y",
                "-ss",
                str(BGM_START),
                "-i",
                BGM_SOURCE,
                "-t",
                str(DURATION),
                "-af",
                mix_tail,
                "-c:a",
                "aac",
                "-b:a",
                "192k",
                "-ar",
                "48000",
                BGM_PATH,
            ]
        )
        return

    crossfade = 2.0
    continuation_duration = DURATION - usable_duration + crossfade
    run(
        [
            "ffmpeg",
            "-y",
            "-i",
            BGM_SOURCE,
            "-i",
            BGM_SOURCE,
            "-filter_complex",
            (
                f"[0:a]atrim=start={BGM_START}:end={source_duration},"
                "asetpts=PTS-STARTPTS[first];"
                f"[1:a]atrim=start=0:end={continuation_duration},"
                "asetpts=PTS-STARTPTS[continuation];"
                f"[first][continuation]acrossfade=d={crossfade}:c1=tri:c2=tri,"
                f"{mix_tail}[mixed]"
            ),
            "-map",
            "[mixed]",
            "-t",
            str(DURATION),
            "-c:a",
            "aac",
            "-b:a",
            "192k",
            "-ar",
            "48000",
            BGM_PATH,
        ]
    )


def mux_final():
    run(
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
            str(DURATION),
            "-c:v",
            "copy",
            "-c:a",
            "aac",
            "-b:a",
            "192k",
            "-movflags",
            "+faststart",
            "-metadata",
            "title=帧澈 ZENCHE 宣传 PV · V1 正式版",
            "-metadata",
            "comment=BGM：弧光作战 PV；版本：V1 正式版",
            "-metadata:s:a:0",
            "title=弧光作战 PV BGM",
            FINAL_PATH,
        ]
    )


def create_review_images():
    run(
        [
            "ffmpeg",
            "-y",
            "-ss",
            "99.4",
            "-i",
            FINAL_PATH,
            "-frames:v",
            "1",
            "-q:v",
            "2",
            POSTER_PATH,
        ]
    )
    run(
        [
            "ffmpeg",
            "-y",
            "-ss",
            "2.5",
            "-i",
            FINAL_PATH,
            "-vf",
            "fps=1/5,scale=384:216:flags=lanczos,tile=5x4",
            "-frames:v",
            "1",
            "-q:v",
            "2",
            CONTACT_SHEET_PATH,
        ]
    )


def create_jianying_draft():
    project = JyProject(
        project_name=PROJECT_NAME,
        width=WIDTH,
        height=HEIGHT,
        overwrite=True,
    )
    video_segment = project.add_media_safe(
        str(VISUAL_MP4.resolve()),
        start_time="0s",
        duration=f"{DURATION}s",
        track_name="VideoTrack",
    )
    if video_segment is None:
        raise RuntimeError("Could not add rendered PV to the video track.")

    audio_segment = project.add_audio_safe(
        str(BGM_PATH.resolve()),
        start_time="0s",
        duration=f"{DURATION}s",
        track_name="BGM",
    )
    if audio_segment is None:
        raise RuntimeError("Could not add BGM to the audio track.")

    return project.save()


def probe_output():
    result = subprocess.run(
        [
            "ffprobe",
            "-v",
            "error",
            "-show_entries",
            "format=duration,size,bit_rate,tags:stream=codec_type,codec_name,width,height,r_frame_rate,sample_rate,channels",
            "-of",
            "json",
            str(FINAL_PATH),
        ],
        check=True,
        capture_output=True,
        text=True,
    )
    return json.loads(result.stdout)


def write_delivery_metadata(draft_result, probe):
    digest = hashlib.sha256(FINAL_PATH.read_bytes()).hexdigest()
    CHECKSUM_PATH.write_text(f"{digest}  {FINAL_PATH.name}\n", encoding="utf-8")

    manifest = {
        "product": "帧澈 ZENCHE",
        "product_descriptor": "跨平台相机控制与影像传输工具",
        "brand_line": "Capture · Connect · Flow",
        "slogan": "连接相机，也连接完整工作流",
        "asset": "宣传 PV",
        "version_label": "V1 正式版",
        "duration_seconds": DURATION,
        "resolution": f"{WIDTH}x{HEIGHT}",
        "fps": FPS,
        "beat_sync": {
            "tempo_bpm": 105.469,
            "beat_period_seconds": 0.5689,
            "first_beat_seconds": 0.4644,
            "edit_pattern": "scene changes on four-beat bar starts; internal reveals on beat subdivisions",
        },
        "bgm": {
            "label": "弧光作战 PV",
            "source": str(BGM_SOURCE.resolve()),
            "source_offset_seconds": BGM_START,
        },
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


def main():
    WORK_DIR.mkdir(parents=True, exist_ok=True)
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    render_platform_screenshots()
    require_assets()
    render_visual()
    build_audio()
    mux_final()
    create_review_images()
    draft_result = create_jianying_draft()
    probe = probe_output()
    digest = write_delivery_metadata(draft_result, probe)
    print(
        json.dumps(
            {
                "status": "SUCCESS",
                "version": "V1 正式版",
                "final_video": str(FINAL_PATH.resolve()),
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
