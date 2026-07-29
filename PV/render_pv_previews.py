#!/usr/bin/env python3
"""Render deterministic PV review frames without recording the full timeline."""

from pathlib import Path
from urllib.parse import urlencode

from playwright.sync_api import sync_playwright


PV_ROOT = Path(__file__).resolve().parent
HTML_PATH = PV_ROOT / "zenche_pv_v1.html"
OUTPUT_DIR = PV_ROOT / "work" / "qa-beat-sync"
REVIEW_TIMES = {
    "brand-mark": 1.25,
    "brand-lockup": 2.75,
    "first-transition": 5.016,
    "direct-control": 6.45,
    "monitoring": 26.95,
    "desktop-platforms": 54.25,
    "mobile-platforms": 61.10,
    "camera-support": 68.45,
    "project-page": 81.80,
    "future": 88.65,
    "end-card": 96.20,
}


def main() -> None:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    base_url = HTML_PATH.resolve().as_uri()
    with sync_playwright() as playwright:
        browser = playwright.chromium.launch(headless=True)
        page = browser.new_page(viewport={"width": 1920, "height": 1080})
        for label, seek in REVIEW_TIMES.items():
            page.goto(f"{base_url}?{urlencode({'seek': seek})}")
            page.wait_for_timeout(150)
            page.screenshot(path=str(OUTPUT_DIR / f"{label}.png"))
        page.close()
        browser.close()


if __name__ == "__main__":
    main()
