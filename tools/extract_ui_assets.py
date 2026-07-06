#!/usr/bin/env python3
"""
extract_ui_assets.py - Extract UI spritesheets from the Boss Monster APK with
the CORRECT color decode (R/B swapped vs the original E_RBG interpretation).

The card spritesheets use format 13 (E_RBG). Our earlier tools/extract_wpk.py
decoded E_RBG as R(11-15) B(5-10) G(0-4), which produced magenta/purple icons
because the real channel order for UI assets is B(11-15) G(5-10) R(0-4) — i.e.
the red and blue 5-bit fields are swapped relative to our assumption, while the
6-bit field is correctly green.

This script re-extracts every Common/ spritesheet + background with the swapped
decode so icons (soul=wound=blue/red), buttons (gold), and backgrounds render
with correct colors.

Usage:
  python tools/extract_ui_assets.py            # extract everything to assets/ui/
  python tools/extract_ui_assets.py --validate # render a montage of key sprites
"""
import argparse
import gzip
import os
import struct

from PIL import Image

APK_COMMON = "boss-monster-2-4-12/resources/assets/Content/Assets/Common"
OUT = "assets/ui"

# Spritesheets whose sprites are individually useful (cropped per-name).
SPRITESHEETS = [
    "TUTORIAL.spritesheet.wpk",
    "NAVIGATION.spritesheet.wpk",
    "INGAME.spritesheet.wpk",
    "GRADIENTS.spritesheet.wpk",
    "AVATAR.spritesheet.wpk",
]

# Standalone backgrounds (single-image .png.wpk).
BACKGROUNDS = ["menu_bg", "intro_bg", "multiplayer_bg", "gallery_bg", "particle_01"]


def _swap_r_b(r, g, b):
    """The fix: swap the red and blue channels."""
    return b, g, r


def decode_format13_swapped(pixels, width, height):
    """Decode E_RBG 16-bit pixels with R and B swapped (correct for UI assets)."""
    img = Image.new("RGBA", (width, height))
    out = img.load()
    for y in range(height):
        row = y * width
        for x in range(width):
            v = pixels[(row + x) * 2] | (pixels[(row + x) * 2 + 1] << 8)
            r5 = (v >> 11) & 0x1F
            b6 = (v >> 5) & 0x3F
            g5 = v & 0x1F
            r = (r5 << 3) | (r5 >> 2)
            g = (g5 << 3) | (g5 >> 2)
            b = (b6 << 2) | (b6 >> 4)
            r, g, b = _swap_r_b(r, g, b)
            out[x, y] = (r, g, b, 255)
    return img


def parse_spritesheet(path):
    """Return (sprites, atlas_image) for a WPK spritesheet."""
    with open(path, "rb") as f:
        raw = f.read()
    dec = gzip.decompress(raw[raw.find(b"\x1f\x8b"):])
    off = 0
    count = struct.unpack_from("<i", dec, off)[0]
    off += 4
    sprites = []
    for _ in range(count):
        name_len = dec[off]; off += 1
        name = dec[off:off + name_len].decode("ascii"); off += name_len
        x, y, w, h = struct.unpack_from("<iiii", dec, off); off += 16
        sprites.append((name, x, y, w, h))
    off += 4  # separator
    _fmt = struct.unpack_from("<i", dec, off)[0]; off += 4
    width = struct.unpack_from("<I", dec, off)[0]; off += 4
    height = struct.unpack_from("<I", dec, off)[0]; off += 4
    pixels = dec[len(dec) - width * height * 2:]
    atlas = decode_format13_swapped(pixels, width, height)
    return sprites, atlas


def extract_background(name, out_dir):
    """Extract a standalone background .png.wpk.

    Background WPK format (no sprite list):
      format(int32) + width(int32) + height(int32) + mips(int32) + pixels
    Pixel data starts immediately after the 16-byte header.
    """
    path = os.path.join(APK_COMMON, f"{name}.png.wpk")
    if not os.path.exists(path):
        print(f"  {name}: source missing, skip")
        return
    with open(path, "rb") as f:
        raw = f.read()
    dec = gzip.decompress(raw[raw.find(b"\x1f\x8b"):])
    _fmt = struct.unpack_from("<i", dec, 0)[0]
    width = struct.unpack_from("<I", dec, 4)[0]
    height = struct.unpack_from("<I", dec, 8)[0]
    pixel_size = width * height * 2
    pixels = dec[16:16 + pixel_size]
    atlas = decode_format13_swapped(pixels, width, height)
    bg_out = os.path.join(out_dir, "backgrounds")
    os.makedirs(bg_out, exist_ok=True)
    atlas.convert("RGB").save(os.path.join(bg_out, f"{name}.jpg"), quality=88)
    print(f"  {name}: {width}x{height} -> backgrounds/{name}.jpg")


def extract_all():
    os.makedirs(OUT, exist_ok=True)
    # Spritesheets -> individual PNGs in subfolders by sheet name.
    for sheet_name in SPRITESHEETS:
        path = os.path.join(APK_COMMON, sheet_name)
        if not os.path.exists(path):
            print(f"  {sheet_name}: missing, skip")
            continue
        try:
            sprites, atlas = parse_spritesheet(path)
            folder = sheet_name.replace(".spritesheet.wpk", "").lower()
            out_dir = os.path.join(OUT, folder)
            os.makedirs(out_dir, exist_ok=True)
            for name, x, y, w, h in sprites:
                x2 = min(x + w, atlas.width)
                y2 = min(y + h, atlas.height)
                crop = atlas.crop((x, y, x2, y2))
                crop.save(os.path.join(out_dir, f"{name}.png"))
            print(f"  {sheet_name}: {len(sprites)} sprites -> ui/{folder}/")
        except Exception as e:
            print(f"  {sheet_name}: FAILED ({e})")

    # Backgrounds
    for name in BACKGROUNDS:
        try:
            extract_background(name, OUT)
        except Exception as e:
            print(f"  {name}: FAILED ({e})")

    # Re-export the few icons the game expects under assets/ui/icons/ and
    # assets/ui/buttons/ (compat with existing code paths).
    _export_compat_icons()


def _export_compat_icons():
    """Re-export the specific files the current code references (icons/buttons
    /logos/hud) using the corrected decode, overwriting the magenta versions."""
    mapping = {
        # TUTORIAL sheet -> icons used by AppBoard Soul/Wound + treasure helpers
        "TUTORIAL": {
            "soul": "icons/soul.png",
            "soul_glow": "icons/soul_glow.png",
            "wound": "icons/wound.png",
            "icon_cleric": "icons/icon_cleric.png",
            "icon_fighter": "icons/icon_fighter.png",
            "icon_mage": "icons/icon_mage.png",
            "icon_thief": "icons/icon_thief.png",
        },
        "NAVIGATION": {
            "intro_start_btn": "buttons/intro_start_btn.png",
            "intro_start_btn_pressed": "buttons/intro_start_btn_pressed.png",
            "intro_quit_btn": "buttons/intro_quit_btn.png",
            "intro_quit_btn_pressed": "buttons/intro_quit_btn_pressed.png",
            "options_bt": "buttons/options_bt.png",
            "options_bt_pressed": "buttons/options_bt_pressed.png",
            "settings_bt": "buttons/settings_bt.png",
            "back_bt": "buttons/back_bt.png",
            "back_bt_pressed": "buttons/back_bt_pressed.png",
            "big_button": "buttons/big_button.png",
            "big_button_selected": "buttons/big_button_selected.png",
            "button": "buttons/button.png",
            "button_pressed": "buttons/button_pressed.png",
            "ok_bt": "buttons/ok_bt.png",
            "ok_bt_pressed": "buttons/ok_bt_pressed.png",
            "bm_logo": "logos/bm_logo.png",
        },
    }
    for sheet_name, files in mapping.items():
        path = os.path.join(APK_COMMON, f"{sheet_name}.spritesheet.wpk")
        if not os.path.exists(path):
            continue
        sprites, atlas = parse_spritesheet(path)
        sprite_map = {n: (x, y, w, h) for n, x, y, w, h in sprites}
        for sprite_name, rel_dest in files.items():
            if sprite_name not in sprite_map:
                continue
            x, y, w, h = sprite_map[sprite_name]
            crop = atlas.crop((x, y, min(x + w, atlas.width), min(y + h, atlas.height)))
            dest = os.path.join(OUT, rel_dest)
            os.makedirs(os.path.dirname(dest), exist_ok=True)
            crop.save(dest)
            print(f"    compat: {sprite_name} -> ui/{rel_dest}")


def validate():
    """Render a montage comparing a few key sprites."""
    path = os.path.join(APK_COMMON, "TUTORIAL.spritesheet.wpk")
    sprites, atlas = parse_spritesheet(path)
    sm = {n: (x, y, w, h) for n, x, y, w, h in sprites}
    targets = ["soul", "wound", "icon_cleric", "icon_fighter", "icon_mage", "icon_thief"]
    crops = []
    for t in targets:
        if t in sm:
            x, y, w, h = sm[t]
            crops.append((t, atlas.crop((x, y, x + w, y + h))))
    if not crops:
        print("no validation targets found")
        return
    cols = 3
    rows = (len(crops) + cols - 1) // cols
    cw = max(c.width for _, c in crops) + 20
    ch = max(c.height for _, c in crops) + 30
    canvas = Image.new("RGB", (cols * cw, rows * ch), (24, 24, 24))
    from PIL import ImageDraw
    draw = ImageDraw.Draw(canvas)
    for i, (name, crop) in enumerate(crops):
        col = i % cols
        row = i // cols
        canvas.paste(crop, (col * cw + 10, row * ch + 25))
        draw.text((col * cw + 10, row * ch + 5), name, fill=(255, 255, 255))
    os.makedirs("tools", exist_ok=True)
    canvas.save("tools/ui_validate.png")
    print(f"Validation montage: tools/ui_validate.png ({canvas.size})")


def main():
    ap = argparse.ArgumentParser(description="Extract UI assets with corrected R/B swap")
    ap.add_argument("--validate", action="store_true", help="render a montage of key sprites only")
    args = ap.parse_args()
    if args.validate:
        validate()
    else:
        extract_all()


if __name__ == "__main__":
    main()
