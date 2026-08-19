#!/usr/bin/env python3
"""Ensure APK SpriteFont WPKs exist, then rebuild browser TTFs into assets/fonts."""
from __future__ import annotations

import os
import sys
import zipfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FONTS_DIR = os.path.join(ROOT, "boss-monster-2-2-6", "assets", "Content", "Fonts")
APKS = [
    os.path.join(ROOT, "boss-monster-2-2-6-android.apk"),
    os.path.join(ROOT, "boss-monster-2-4-12.apk"),
]
NEEDED = ("arcadepix.wpk", "arcadepix2.wpk", "bookman_old_style.wpk", "f04b03.wpk")


def fonts_ready():
    return all(os.path.isfile(os.path.join(FONTS_DIR, name)) for name in NEEDED)


def extract_from_apk():
    os.makedirs(FONTS_DIR, exist_ok=True)
    for apk in APKS:
        if not os.path.isfile(apk):
            continue
        with zipfile.ZipFile(apk) as zf:
            names = zf.namelist()
            hits = [n for n in names if n.replace("\\", "/").endswith(".wpk") and "Fonts" in n.replace("\\", "/")]
            if not hits:
                continue
            for n in hits:
                base = os.path.basename(n)
                dest = os.path.join(FONTS_DIR, base)
                with zf.open(n) as src, open(dest, "wb") as out:
                    out.write(src.read())
                print("extracted", base, "from", os.path.basename(apk))
            return True
    return False


def main():
    if not fonts_ready():
        if not extract_from_apk():
            sys.exit("No APK SpriteFonts found. Place boss-monster-2-2-6-android.apk in the repo root.")
    if not fonts_ready():
        sys.exit("Font WPKs still missing after APK extract.")
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    import build_fonts
    build_fonts.main()


if __name__ == "__main__":
    main()
