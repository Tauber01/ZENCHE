#!/usr/bin/env python3
"""Build public-safe PV screenshots and platform-specific launch covers."""

from pathlib import Path

from PIL import Image, ImageDraw, ImageEnhance, ImageFilter, ImageFont


PV_ROOT = Path(__file__).resolve().parent
PROJECT_ROOT = PV_ROOT.parent
ASSET_DIR = PV_ROOT / "assets"
CURRENT_SCREENS = ASSET_DIR / "screens" / "current"
BRANDING_DIR = ASSET_DIR / "branding"
OUTPUT_DIR = PV_ROOT / "output" / "publish"

TRANSFER_SOURCE = CURRENT_SCREENS / "macos-transfer.png"
TRANSFER_PUBLIC = CURRENT_SCREENS / "macos-transfer-public.png"
APP_ICON = PROJECT_ROOT / "icons" / "icon-512.png"
LANDSCAPE_BACKGROUND = BRANDING_DIR / "publish-bg-landscape.png"
PORTRAIT_BACKGROUND = BRANDING_DIR / "publish-bg-portrait.png"

CN_FONT = Path("/System/Library/Fonts/STHeiti Medium.ttc")
CN_FONT_LIGHT = Path("/System/Library/Fonts/STHeiti Light.ttc")
LATIN_FONT = Path("/System/Library/Fonts/Supplemental/Arial Bold.ttf")

WHITE = "#f7f9ff"
MUTED = "#b7c2d3"
BLUE = "#4d8dff"
YELLOW = "#ffd229"
DARK = "#05070b"


def font(path: Path, size: int) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(str(path), size=size)


def fit_cover(image: Image.Image, size: tuple[int, int]) -> Image.Image:
    target_width, target_height = size
    scale = max(target_width / image.width, target_height / image.height)
    resized = image.resize(
        (round(image.width * scale), round(image.height * scale)),
        Image.Resampling.LANCZOS,
    )
    left = (resized.width - target_width) // 2
    top = (resized.height - target_height) // 2
    return resized.crop((left, top, left + target_width, top + target_height))


def rounded_mask(size: tuple[int, int], radius: int) -> Image.Image:
    mask = Image.new("L", size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, size[0], size[1]), radius=radius, fill=255)
    return mask


def paste_rounded(
    canvas: Image.Image,
    image: Image.Image,
    box: tuple[int, int, int, int],
    radius: int,
) -> None:
    width = box[2] - box[0]
    height = box[3] - box[1]
    prepared = fit_cover(image.convert("RGB"), (width, height))
    canvas.paste(prepared, (box[0], box[1]), rounded_mask((width, height), radius))


def build_public_transfer_screen() -> None:
    source = Image.open(TRANSFER_SOURCE).convert("RGB")
    draw = ImageDraw.Draw(source)

    header_background = "#ffffff"
    page_background = "#f4f6fa"
    card_background = "#ffffff"

    # Window title.
    draw.rectangle((152, 0, 520, 75), fill=header_background)
    draw.text((168, 20), "帧澈 ZENCHE", fill="#555555", font=font(CN_FONT, 30))

    # Main brand lockup.
    draw.rectangle((34, 88, 350, 192), fill=header_background)
    icon = Image.open(APP_ICON).convert("RGB")
    paste_rounded(source, icon, (40, 94, 128, 182), 17)
    draw.text((148, 108), "帧澈 ZENCHE", fill="#242424", font=font(CN_FONT, 38))
    draw.text((148, 154), "原生版", fill="#687387", font=font(CN_FONT_LIGHT, 23))

    # Product name in the transfer introduction.
    draw.rectangle((240, 385, 1330, 438), fill=page_background)
    draw.text(
        (244, 398),
        "通过相机内置 Wi-Fi，把 JPEG、NEF 或 HEIF 直接发送到帧澈 ZENCHE。",
        fill="#606d82",
        font=font(CN_FONT_LIGHT, 25),
    )

    # Public-safe connection values. No local address or credentials are exposed.
    draw.rectangle((2100, 930, 2500, 1225), fill=card_background)
    value_font = font(CN_FONT, 27)
    safe_values = [
        (952, "FTP"),
        (1007, "启动后显示"),
        (1066, "2121"),
        (1124, "自动生成"),
        (1181, "已保护"),
    ]
    for y, value in safe_values:
        right = 2482
        text_box = draw.textbbox((0, 0), value, font=value_font)
        draw.text((right - (text_box[2] - text_box[0]), y), value, fill="#2d2d2d", font=value_font)

    TRANSFER_PUBLIC.parent.mkdir(parents=True, exist_ok=True)
    source.save(TRANSFER_PUBLIC, optimize=True)


def add_cover_copy(canvas: Image.Image, portrait: bool) -> None:
    width, height = canvas.size
    draw = ImageDraw.Draw(canvas, "RGBA")

    if portrait:
        pad = round(width * 0.085)
        mark_size = round(width * 0.15)
        brand_y = round(height * 0.085)
        headline_y = round(height * 0.30)
        headline_size = round(width * 0.092)
        sub_size = round(width * 0.043)
        meta_size = round(width * 0.031)
        line_gap = round(headline_size * 1.25)

        draw.rounded_rectangle(
            (
                pad - round(width * 0.025),
                brand_y - round(height * 0.025),
                width - pad + round(width * 0.025),
                round(height * 0.67),
            ),
            radius=round(width * 0.045),
            fill=(3, 8, 17, 165),
            outline=(77, 141, 255, 75),
            width=max(2, round(width * 0.002)),
        )

        icon = Image.open(APP_ICON).convert("RGB")
        paste_rounded(
            canvas,
            icon,
            (pad, brand_y, pad + mark_size, brand_y + mark_size),
            round(mark_size * 0.20),
        )
        draw.text(
            (pad + mark_size + round(width * 0.035), brand_y + round(mark_size * 0.18)),
            "帧澈 ZENCHE",
            fill=WHITE,
            font=font(CN_FONT, round(width * 0.058)),
        )
        draw.text(
            (pad + mark_size + round(width * 0.035), brand_y + round(mark_size * 0.65)),
            "CAPTURE · CONNECT · FLOW",
            fill=BLUE,
            font=font(LATIN_FONT, round(width * 0.022)),
        )

        draw.text((pad, headline_y), "连接相机，", fill=WHITE, font=font(CN_FONT, headline_size))
        draw.text(
            (pad, headline_y + line_gap),
            "也连接完整工作流",
            fill=WHITE,
            font=font(CN_FONT, headline_size),
        )
        draw.rounded_rectangle(
            (
                pad,
                headline_y + line_gap * 2 + round(height * 0.025),
                pad + round(width * 0.43),
                headline_y + line_gap * 2 + round(height * 0.075),
            ),
            radius=round(height * 0.024),
            fill=(255, 210, 41, 230),
        )
        draw.text(
            (pad + round(width * 0.026), headline_y + line_gap * 2 + round(height * 0.031)),
            "V1 正式版发布",
            fill=DARK,
            font=font(CN_FONT, sub_size),
        )
        draw.text(
            (pad, round(height * 0.61)),
            "跨平台相机控制与影像传输工具",
            fill=MUTED,
            font=font(CN_FONT_LIGHT, sub_size),
        )
        draw.text(
            (pad, round(height * 0.665)),
            "USB/PTP 直连  ·  五端原生  ·  本地工作流",
            fill=WHITE,
            font=font(CN_FONT_LIGHT, meta_size),
        )
    else:
        pad = round(width * 0.055)
        mark_size = round(height * 0.13)
        brand_y = round(height * 0.085)
        panel_top = round(height * 0.10)
        panel_bottom = round(height * 0.88)
        panel_right = round(width * 0.61)

        draw.rounded_rectangle(
            (pad - 28, panel_top - 20, panel_right, panel_bottom),
            radius=48,
            fill=(3, 8, 17, 182),
            outline=(77, 141, 255, 72),
            width=3,
        )
        icon = Image.open(APP_ICON).convert("RGB")
        paste_rounded(
            canvas,
            icon,
            (pad, brand_y, pad + mark_size, brand_y + mark_size),
            round(mark_size * 0.20),
        )
        draw.text(
            (pad + mark_size + 28, brand_y + 7),
            "帧澈 ZENCHE",
            fill=WHITE,
            font=font(CN_FONT, round(height * 0.064)),
        )
        draw.text(
            (pad + mark_size + 30, brand_y + round(mark_size * 0.62)),
            "CAPTURE · CONNECT · FLOW",
            fill=BLUE,
            font=font(LATIN_FONT, round(height * 0.025)),
        )

        headline_y = round(height * 0.33)
        headline_size = round(height * 0.084)
        draw.text((pad, headline_y), "连接相机，", fill=WHITE, font=font(CN_FONT, headline_size))
        draw.text(
            (pad, headline_y + round(headline_size * 1.18)),
            "也连接完整工作流",
            fill=WHITE,
            font=font(CN_FONT, headline_size),
        )
        pill_y = headline_y + round(headline_size * 2.45)
        draw.rounded_rectangle(
            (pad, pill_y, pad + round(width * 0.22), pill_y + round(height * 0.075)),
            radius=round(height * 0.036),
            fill=(255, 210, 41, 230),
        )
        draw.text(
            (pad + 24, pill_y + 12),
            "V1 正式版发布",
            fill=DARK,
            font=font(CN_FONT, round(height * 0.037)),
        )
        draw.text(
            (pad, round(height * 0.72)),
            "帧澈 ZENCHE 正式版发布",
            fill=WHITE,
            font=font(CN_FONT, round(height * 0.042)),
        )
        draw.text(
            (pad, round(height * 0.79)),
            "跨平台相机控制与影像传输工具",
            fill=MUTED,
            font=font(CN_FONT_LIGHT, round(height * 0.031)),
        )


def prepare_background(path: Path, size: tuple[int, int]) -> Image.Image:
    image = fit_cover(Image.open(path).convert("RGB"), size)
    image = ImageEnhance.Brightness(image).enhance(0.78)
    overlay = Image.new("RGBA", size, (2, 6, 13, 0))
    overlay_draw = ImageDraw.Draw(overlay, "RGBA")
    for x in range(size[0]):
        alpha = round(128 * (1 - min(1, x / max(1, size[0] * 0.75))))
        overlay_draw.line((x, 0, x, size[1]), fill=(2, 6, 13, alpha))
    return Image.alpha_composite(image.convert("RGBA"), overlay).convert("RGB")


def build_cover(path: Path, size: tuple[int, int], portrait: bool) -> None:
    background_path = PORTRAIT_BACKGROUND if portrait else LANDSCAPE_BACKGROUND
    canvas = prepare_background(background_path, size)
    add_cover_copy(canvas, portrait=portrait)
    path.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(path, quality=94, subsampling=0, optimize=True)


def main() -> None:
    required = [
        TRANSFER_SOURCE,
        APP_ICON,
        LANDSCAPE_BACKGROUND,
        PORTRAIT_BACKGROUND,
    ]
    missing = [str(path) for path in required if not path.exists()]
    if missing:
        raise FileNotFoundError("Missing publish assets:\n- " + "\n- ".join(missing))

    build_public_transfer_screen()
    build_cover(OUTPUT_DIR / "帧澈_ZENCHE_正式版发布_B站封面_1920x1200.jpg", (1920, 1200), False)
    build_cover(OUTPUT_DIR / "帧澈_ZENCHE_正式版发布_通用横版_1920x1080.jpg", (1920, 1080), False)
    build_cover(OUTPUT_DIR / "帧澈_ZENCHE_正式版发布_抖音封面_1080x1440.jpg", (1080, 1440), True)
    build_cover(OUTPUT_DIR / "帧澈_ZENCHE_正式版发布_抖音竖屏封面_1080x1920.jpg", (1080, 1920), True)
    build_cover(OUTPUT_DIR / "帧澈_ZENCHE_正式版发布_小红书封面_1242x1660.jpg", (1242, 1660), True)
    print(f"Public transfer screen: {TRANSFER_PUBLIC}")
    print(f"Publish assets: {OUTPUT_DIR}")


if __name__ == "__main__":
    main()
