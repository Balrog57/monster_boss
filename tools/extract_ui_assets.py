#!/usr/bin/env python3
"""
extract_ui_assets.py - Extract UI spritesheets from the Boss Monster APK with
the CORRECT color decode (R5G6B5, little-endian uint16).

The card spritesheets and UI spritesheets all use WaveEngine's "format 13" —
a 16-bit R5G6B5 layout (R=bits 11-15, G=bits 5-10, B=bits 0-4,
little-endian).  The official Steam screenshots show the intro/menu backgrounds
as warm brown/red and the logo/buttons as green/yellow; decoding as B5G6R5
swaps red and blue, giving blue banners and a pink logo.  The correct layout
is therefore R5G6B5.

Backgrounds (menu_bg.png.wpk, intro_bg.png.wpk, etc.) use "format 12" — same
16-bit R5G6B5 layout, no sprite list, header is just [fmt, w, h, mips].

Usage:
  python tools/extract_ui_assets.py            # extract everything to assets/ui/
  python tools/extract_ui_assets.py --validate # render a montage of key sprites
"""
import argparse
import gzip
import os
import struct

from PIL import Image

APK_COMMON = "boss-monster-2-2-6/assets/Content/Common"
OUT = "assets/ui"

# Spritesheets whose sprites are individually useful (cropped per-name).
# Each sheet has its own pixel format (validated against the official Steam
# screenshots — see tools/montage_*.png). Use SHEET_DECODER[stem] below to
# pick the right (r_high, swap_bytes) combination for each.
SPRITESHEETS = [
    "TUTORIAL.wpk",
    "NAVIGATION.wpk",
    "INGAME.wpk",
    "GRADIENTS.wpk",
    "AVATAR.wpk",
]

# Per-sheet decoder. The WaveEngine format 13 (16-bit 5-6-5) is stored
# inconsistently across sheets: TUTORIAL/AVATAR use little-endian R5G6B5,
# NAVIGATION/INGAME use little-endian B5G6R5. (r_high=True => R high bits,
# swap_bytes=True => 16-bit words are big-endian inside the WPK.)
SHEET_DECODER = {
    "TUTORIAL":    (True,  False),  # R5G6B5 LE  (blue soul, red wound, gold cleric)
    "NAVIGATION":  (False, False),  # B5G6R5 LE  (green logo, olive buttons)
    "INGAME":      (False, False),  # B5G6R5 LE  (red PASS TURN, red wound, blue soul)
    "AVATAR":      (True,  False),  # R5G6B5 LE  (purple/blue avatar frames, red capes)
    # GRADIENTS uses format 1 (not 13) — separate decoder below.
}

# Standalone backgrounds (single-image .png.wpk, format 12).
BACKGROUNDS = ["menu_bg", "intro_bg", "multiplayer_bg", "gallery_bg", "particle_01"]


def _decode_16bit(pixels, width, height, r_high, swap_bytes=False):
    """Decode a 16-bit 5-6-5 image.

    r_high=True     -> R5G6B5 (R=bits 11-15, G=bits 5-10, B=bits 0-4)
    r_high=False    -> B5G6R5 (B=bits 11-15, G=bits 5-10, R=bits 0-4)
    swap_bytes=True -> stored big-endian (read byte 1 then byte 0)
    """
    img = Image.new("RGBA", (width, height))
    out = img.load()
    for y in range(height):
        row = y * width
        for x in range(width):
            i = (row + x) * 2
            if swap_bytes:
                v = pixels[i + 1] | (pixels[i] << 8)
            else:
                v = pixels[i] | (pixels[i + 1] << 8)
            hi = (v >> 11) & 0x1F
            g6 = (v >> 5) & 0x3F
            lo = v & 0x1F
            r5, b5 = (hi, lo) if r_high else (lo, hi)
            r = (r5 << 3) | (r5 >> 2)
            g = (g6 << 2) | (g6 >> 4)
            b = (b5 << 3) | (b5 >> 2)
            out[x, y] = (r, g, b, 255)
    return img


def decode_background(pixels, width, height):
    """Decode R5G6B5 16-bit little-endian pixels.

    Used by standalone backgrounds (format 12). Matches the official
    screenshots: warm browns, red banners.
    """
    return _decode_16bit(pixels, width, height, r_high=True, swap_bytes=False)


def decode_spritesheet(pixels, width, height, r_high, swap_bytes):
    """Decode a 16-bit 5-6-5 spritesheet atlas.

    The right (r_high, swap_bytes) combination depends on the sheet — see
    SHEET_DECODER. TUTORIAL and AVATAR use R5G6B5 little-endian, NAVIGATION
    and INGAME use B5G6R5 little-endian. (No sheet tested so far needs the
    big-endian swap path; it remains available for future sheets.)
    """
    return _decode_16bit(pixels, width, height, r_high=r_high, swap_bytes=swap_bytes)


def apply_tint(img, tint):
    """Apply a per-channel tint to an RGBA image.

    `tint` is a tuple (r_scale, g_scale, b_scale, mode) where the scales are
    multiplied to each channel.  mode="tint" applies the scale to non-transparent
    pixels only and preserves the original alpha.  mode="replace" replaces RGB
    entirely (the image is forced to opaque first).
    """
    if tint is None:
        return img
    if len(tint) == 4:
        r_scale, g_scale, b_scale, mode = tint
    else:
        r_scale, g_scale, b_scale = tint
        mode = "tint"
    w, h = img.size
    out = img.copy()
    pixels = out.load()
    for y in range(h):
        for x in range(w):
            r, g, b, a = pixels[x, y]
            if a == 0:
                continue
            if mode == "swap":
                # Swap R and B channels, then apply scales
                r, b = b, r
            nr = min(255, int(r * r_scale))
            ng = min(255, int(g * g_scale))
            nb = min(255, int(b * b_scale))
            pixels[x, y] = (nr, ng, nb, a)
    return out


# Per-sprite tint table. The WaveEngine sprites are stored with a generic
# pink/yellow palette and the actual game tints them with a color uniform at
# render time. The mapping below is calibrated against the official Steam
# screenshots. None = no tint (sprite already in its final color).
#
# The tint is a multiplier applied to each channel. The MVP rule is:
#   "to make the sprite look green/yellow like the official, multiply R and B
#   down (kill the pink) and let G dominate."
#
# Tints were validated by rendering each tinted sprite and comparing against
# the corresponding region of the official Steam screenshots.
SPRITE_TINT = {
    # NAVIGATION — green-themed menu chrome
    "bm_logo":                   (0.45, 0.95, 0.30),  # green/yellow logo
    "bm_logo_legend":            (0.45, 0.95, 0.30),
    "intro_start_btn":           (0.50, 1.00, 0.40),  # olive button bg
    "intro_start_btn_pressed":   (0.50, 1.00, 0.40),
    "intro_quit_btn":            (0.50, 1.00, 0.40),
    "intro_quit_btn_pressed":    (0.50, 1.00, 0.40),
    "options_bt":                (0.50, 1.00, 0.40),
    "options_bt_pressed":        (0.50, 1.00, 0.40),
    "settings_bt":               (0.50, 1.00, 0.40),
    "back_bt":                   (0.50, 1.00, 0.40),
    "back_bt_pressed":           (0.50, 1.00, 0.40),
    "big_button":                (0.50, 1.00, 0.40),
    "big_button_selected":       (0.50, 1.00, 0.40),
    "button":                    (0.50, 1.00, 0.40),
    "button_pressed":            (0.50, 1.00, 0.40),
    "ok_bt":                     (0.50, 1.00, 0.40),
    "ok_bt_pressed":             (0.50, 1.00, 0.40),
    # TUTORIAL — class icons get their own color
    "icon_cleric":               (1.00, 0.85, 0.30),  # gold
    "icon_fighter":              (1.00, 0.85, 0.30),  # gold/silver
    "icon_mage":                 (1.00, 0.85, 0.30),
    "icon_thief":                (1.00, 0.85, 0.30),
    "soul":                      (0.30, 0.70, 1.20, "swap"),  # blue gem (swap R/B then tint)
    "soul_glow":                 (0.30, 0.70, 1.20, "swap"),
    "wound":                     (1.20, 0.30, 0.30, "swap"),  # red droplet (swap R/B then tint)
    # INGAME — same green theme for HUD
    "pass_button_timer":         (0.50, 1.00, 0.40),
    "pass_button_timer_pressed": (0.50, 1.00, 0.40),
    "pass_button":               (0.50, 1.00, 0.40),
    "pass_button_pressed":       (0.50, 1.00, 0.40),
    "play":                      (0.50, 1.00, 0.40),
    "play_pressed":              (0.50, 1.00, 0.40),
    "total_damage":              (0.40, 1.00, 0.40),  # green counter
    "boss_tombstone":            (0.70, 0.70, 0.70),  # neutral grey
}


def parse_spritesheet(path, stem):
    """Return (sprites, atlas_image) for a WPK spritesheet.

    The pixel format depends on the sheet (see SHEET_DECODER). For sheets
    listed there we use (r_high, swap_bytes); for any other sheet we fall
    back to the NAVIGATION/INGAME default (B5G6R5 little-endian).
    """
    with open(path, "rb") as f:
        raw = f.read()
    gz = raw.find(b"\x1f\x8b\x08")
    if gz < 0:
        gz = raw.find(b"\x1f\x8b")
    dec = gzip.decompress(raw[gz:])
    off = 0
    count = struct.unpack_from("<i", dec, off)[0]
    off += 4
    sprites = []
    for _ in range(count):
        name_len = dec[off]
        off += 1
        name = dec[off:off + name_len].decode("ascii", errors="replace")
        off += name_len
        x, y, w, h = struct.unpack_from("<iiii", dec, off)
        off += 16
        sprites.append((name, x, y, w, h))
    off += 4  # separator
    _fmt = struct.unpack_from("<i", dec, off)[0]
    off += 4
    width = struct.unpack_from("<I", dec, off)[0]
    off += 4
    height = struct.unpack_from("<I", dec, off)[0]
    off += 4
    _mips = struct.unpack_from("<i", dec, off)[0]
    off += 4
    pixels = dec[len(dec) - width * height * 2:]
    r_high, swap_bytes = SHEET_DECODER.get(stem, (False, False))
    atlas = decode_spritesheet(pixels, width, height, r_high, swap_bytes)
    return sprites, atlas


def extract_background(name, out_dir):
    """Extract a standalone background .png.wpk (format 12).

    Background WPK layout: gzip -> [fmt:int32, w:int32, h:int32, mips:int32, pixels].
    Pixels start at offset 16 (right after the 4 int32 header).
    """
    path = os.path.join(APK_COMMON, f"{name}.png.wpk")
    if not os.path.exists(path):
        print(f"  {name}: source missing, skip")
        return
    with open(path, "rb") as f:
        raw = f.read()
    gz = raw.find(b"\x1f\x8b\x08")
    if gz < 0:
        gz = raw.find(b"\x1f\x8b")
    dec = gzip.decompress(raw[gz:])
    fmt = struct.unpack_from("<i", dec, 0)[0]
    width = struct.unpack_from("<I", dec, 4)[0]
    height = struct.unpack_from("<I", dec, 8)[0]
    _mips = struct.unpack_from("<i", dec, 12)[0]
    if fmt != 12:
        print(f"  {name}: unexpected format {fmt}, skipping")
        return
    pixel_size = width * height * 2
    pixels = dec[16:16 + pixel_size]
    atlas = decode_background(pixels, width, height)
    bg_out = os.path.join(out_dir, "backgrounds")
    os.makedirs(bg_out, exist_ok=True)
    atlas.convert("RGB").save(os.path.join(bg_out, f"{name}.jpg"), quality=88)
    print(f"  {name}: {width}x{height} (fmt={fmt}) -> backgrounds/{name}.jpg")


def extract_all():
    os.makedirs(OUT, exist_ok=True)
    # Spritesheets -> individual PNGs in subfolders by sheet name.
    for sheet_name in SPRITESHEETS:
        path = os.path.join(APK_COMMON, sheet_name)
        if not os.path.exists(path):
            print(f"  {sheet_name}: missing, skip")
            continue
        stem = sheet_name.replace(".spritesheet.wpk", "").replace(".wpk", "")
        try:
            sprites, atlas = parse_spritesheet(path, stem)
            folder = sheet_name.replace(".spritesheet.wpk", "").replace(".wpk", "").lower()
            out_dir = os.path.join(OUT, folder)
            os.makedirs(out_dir, exist_ok=True)
            for name, x, y, w, h in sprites:
                x2 = min(x + w, atlas.width)
                y2 = min(y + h, atlas.height)
                crop = atlas.crop((x, y, x2, y2))
                tint = SPRITE_TINT.get(name)
                if tint is not None:
                    crop = apply_tint(crop, tint)
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
    /logos/hud) using the corrected B5G6R5 decode, overwriting the old ones."""
    mapping = {
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
        path = os.path.join(APK_COMMON, f"{sheet_name}.wpk")
        if not os.path.exists(path):
            continue
        sprites, atlas = parse_spritesheet(path, sheet_name)
        sprite_map = {n: (x, y, w, h) for n, x, y, w, h in sprites}
        for sprite_name, rel_dest in files.items():
            if sprite_name not in sprite_map:
                continue
            x, y, w, h = sprite_map[sprite_name]
            crop = atlas.crop((x, y, min(x + w, atlas.width), min(y + h, atlas.height)))
            tint = SPRITE_TINT.get(sprite_name)
            if tint is not None:
                crop = apply_tint(crop, tint)
            dest = os.path.join(OUT, rel_dest)
            os.makedirs(os.path.dirname(dest), exist_ok=True)
            crop.save(dest)
            print(f"    compat: {sprite_name} -> ui/{rel_dest}")


def validate():
    """Render a montage comparing a few key sprites."""
    path = os.path.join(APK_COMMON, "TUTORIAL.spritesheet.wpk")
    sprites, atlas = parse_spritesheet(path, "TUTORIAL")
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
    ap = argparse.ArgumentParser(description="Extract UI assets with B5G6R5 decode")
    ap.add_argument("--validate", action="store_true", help="render a montage of key sprites only")
    args = ap.parse_args()
    if args.validate:
        validate()
    else:
        extract_all()


if __name__ == "__main__":
    main()
