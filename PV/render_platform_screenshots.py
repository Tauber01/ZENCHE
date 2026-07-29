#!/usr/bin/env python3
from pathlib import Path
from urllib.parse import urlencode

from playwright.sync_api import sync_playwright


PV_ROOT = Path(__file__).resolve().parent
HTML_PATH = PV_ROOT / "platform_screenshots.html"
OUTPUT_DIR = PV_ROOT / "assets" / "screens" / "platforms"
TARGETS = {
    "android": (1080, 1920),
    "harmonyos": (1080, 1920),
    "ios-ipados": (1206, 2622),
    "macos": (1600, 1104),
    "windows": (1600, 1000),
}


def main():
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    base_url = HTML_PATH.resolve().as_uri()
    with sync_playwright() as playwright:
        browser = playwright.chromium.launch(headless=True)
        for platform, (width, height) in TARGETS.items():
            page = browser.new_page(viewport={"width": width, "height": height})
            page.goto(f"{base_url}?{urlencode({'platform': platform})}")
            page.wait_for_timeout(300)
            page.screenshot(
                path=str(OUTPUT_DIR / f"{platform}.png"),
                full_page=False,
            )
            page.close()
        browser.close()


if __name__ == "__main__":
    main()
