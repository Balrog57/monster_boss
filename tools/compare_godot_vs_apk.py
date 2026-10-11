#!/usr/bin/env python3
"""Compare visual assets and layout between APK screenshots and Godot screenshots."""
import os
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
APK_REF = os.path.join(ROOT, "docs", "reference")
GODOT_DIR = os.path.join(ROOT, "docs", "reference", "godot_screens")

def inspect_image(path):
    if not os.path.exists(path):
        return f"MISSING: {path}"
    im = Image.open(path)
    return f"{os.path.basename(path)}: size={im.size}, mode={im.mode}"

print("--- GODOT SCREENS ---")
for f in sorted(os.listdir(GODOT_DIR)):
    if f.endswith(".png"):
        print(inspect_image(os.path.join(GODOT_DIR, f)))

print("\n--- APK REFERENCE SCREENS ---")
apk_samples = [
    "01_boot.png",
    "02_after_center_tap.png",
    "04_after_single.png",
    "05_setup.png",
    "apk_build_idle.png",
    "apk_build_placed.png",
    "apk_reveal.png",
    "apk_bait.png",
    "apk_adventure_start.png"
]
for f in apk_samples:
    print(inspect_image(os.path.join(APK_REF, f)))
