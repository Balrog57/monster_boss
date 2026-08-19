#!/usr/bin/env python3
"""
extract_apk_226.py - Extract every usable asset from Boss Monster 2.2.6.

WPK types in this APK:
  TextureAtlas  fmt 6 = ETC1 (Android), fmt 9 = RGBA4444, fmt 1 = RGBA8888
  Texture2D     fmt 8 = RGB565, fmt 1 = RGBA8888
  SoundEffect   WAV payload after a 16-byte header
  SpriteFont    handled by tools/build_fonts.py

Color notes (calibrated against APK 2.2.6 screenshots):
  Dungeon backgrounds (fmt 6) are ETC1, not DXT1. Decoding them as BC1/DXT1
    yields magenta walls and neon red/green noise. ETC1 matches the in-game
    caves, tombs, and halls (brown/grey stone, not a single tint).
  INGAME / NAVIGATION / cards / characters (atlas fmt 9) are little-endian RGBA4444.
  Fullscreen Texture2D backgrounds (fmt 8) are R5G6B5 (r_high=True).
"""
import gzip
import json
import os
import shutil
import struct
import sys
from collections import deque

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
APK = os.path.join(ROOT, "boss-monster-2-2-6")
CONTENT = os.path.join(APK, "assets", "Content")
OUT_UI = os.path.join(ROOT, "assets", "ui")
OUT_AUDIO = os.path.join(ROOT, "assets", "audio")
OUT_DATA = os.path.join(ROOT, "assets", "data")
OUT_CARDS = os.path.join(ROOT, "assets", "apk_cards")
OUT_CHARS = os.path.join(ROOT, "assets", "ui", "characters")
OUT_DUNGEON = os.path.join(ROOT, "assets", "ui", "dungeon")
OUT_EXP = os.path.join(ROOT, "assets", "ui", "expansions")
OUT_NINE = os.path.join(ROOT, "assets", "ui", "ninepatch")
OUT_TUT = os.path.join(ROOT, "assets", "ui", "tutorial")
MANIFEST = os.path.join(ROOT, "src", "apkCardManifest.json")


def wpk_payload(path):
    raw = open(path, "rb").read()
    if raw[:4] != b"WPK\x00":
        raise ValueError(f"{path}: not WPK")
    return gzip.decompress(raw[raw.find(b"\x1f\x8b"):])


def rgb565(c, r_high=True):
    if r_high:
        r5, g6, b5 = (c >> 11) & 0x1F, (c >> 5) & 0x3F, c & 0x1F
    else:
        b5, g6, r5 = (c >> 11) & 0x1F, (c >> 5) & 0x3F, c & 0x1F
    return (
        (r5 << 3) | (r5 >> 2),
        (g6 << 2) | (g6 >> 4),
        (b5 << 3) | (b5 >> 2),
        255,
    )


def decode_etc1(data, width, height):
    """Android ETC1 (WaveEngine atlas fmt 6). texture2ddecoder returns BGRA."""
    import texture2ddecoder
    raw = texture2ddecoder.decode_etc1(bytes(data), width, height)
    img = Image.frombytes("RGBA", (width, height), raw)
    b, g, r, a = img.split()
    return Image.merge("RGBA", (r, g, b, a))


def decode_dxt1(data, width, height, r_high=False):
    """BC1/DXT1 (unused on this APK; fmt 6 is ETC1). Kept for decoder trials."""
    img = Image.new("RGBA", (width, height))
    px = img.load()
    off = 0
    blocks_x = (width + 3) // 4
    blocks_y = (height + 3) // 4
    for by in range(blocks_y):
        for bx in range(blocks_x):
            c0 = struct.unpack_from("<H", data, off)[0]
            c1 = struct.unpack_from("<H", data, off + 2)[0]
            bits = struct.unpack_from("<I", data, off + 4)[0]
            off += 8
            a = rgb565(c0, r_high=r_high)
            b = rgb565(c1, r_high=r_high)
            if c0 > c1:
                cols = [
                    a,
                    b,
                    tuple((2 * a[i] + b[i]) // 3 for i in range(4)),
                    tuple((a[i] + 2 * b[i]) // 3 for i in range(4)),
                ]
            else:
                cols = [
                    a,
                    b,
                    tuple((a[i] + b[i]) // 2 for i in range(4)),
                    (0, 0, 0, 0),
                ]
            for py in range(4):
                for px_i in range(4):
                    x, y = bx * 4 + px_i, by * 4 + py
                    if x < width and y < height:
                        px[x, y] = cols[(bits >> (2 * (py * 4 + px_i))) & 3]
    return img


def decode_16bit(pixels, width, height, r_high):
    """Texture2D fmt 8: packed 565 (little-endian)."""
    try:
        import numpy as np
        arr = np.frombuffer(pixels, dtype="<u2", count=width * height).reshape(height, width)
        if r_high:
            r = ((arr >> 11) & 0x1F); g = (arr >> 5) & 0x3F; b = arr & 0x1F
        else:
            b = ((arr >> 11) & 0x1F); g = (arr >> 5) & 0x3F; r = arr & 0x1F
        r8 = ((r << 3) | (r >> 2)).astype(np.uint8)
        g8 = ((g << 2) | (g >> 4)).astype(np.uint8)
        b8 = ((b << 3) | (b >> 2)).astype(np.uint8)
        a8 = np.full(arr.shape, 255, dtype=np.uint8)
        rgba = np.dstack((r8, g8, b8, a8))
        return Image.fromarray(rgba, "RGBA")
    except Exception:
        img = Image.new("RGBA", (width, height))
        out = img.load()
        for y in range(height):
            row = y * width
            for x in range(width):
                v = pixels[(row + x) * 2] | (pixels[(row + x) * 2 + 1] << 8)
                out[x, y] = rgb565(v, r_high=r_high)
        return img


def decode_rgba4444(pixels, width, height):
    """Atlas fmt 9: little-endian RGBA4444 (R=bits 15-12 … A=bits 3-0)."""
    try:
        import numpy as np
        arr = np.frombuffer(pixels, dtype="<u2", count=width * height).reshape(height, width)
        r = (((arr >> 12) & 0xF) * 17).astype(np.uint8)
        g = (((arr >> 8) & 0xF) * 17).astype(np.uint8)
        b = (((arr >> 4) & 0xF) * 17).astype(np.uint8)
        a = ((arr & 0xF) * 17).astype(np.uint8)
        return Image.fromarray(np.dstack((r, g, b, a)), "RGBA")
    except Exception:
        img = Image.new("RGBA", (width, height))
        out = img.load()
        for y in range(height):
            row = y * width
            for x in range(width):
                v = pixels[(row + x) * 2] | (pixels[(row + x) * 2 + 1] << 8)
                r4, g4, b4, a4 = (v >> 12) & 0xF, (v >> 8) & 0xF, (v >> 4) & 0xF, v & 0xF
                out[x, y] = (r4 * 17, g4 * 17, b4 * 17, a4 * 17)
        return img


def decode_rgba(pixels, width, height):
    return Image.frombytes("RGBA", (width, height), pixels[: width * height * 4])


def chroma_key_standee(img, threshold=18, max_transparent=0.99):
    """Flood-fill near-black from the edges so pixel-art outlines stay opaque.

    If the sprite is mostly dark, flood-fill would erase it — keep the original.
    """
    im = img.convert("RGBA")
    w, h = im.size
    px = im.load()
    alpha = im.getchannel("A")
    lo, hi = alpha.getextrema()
    if lo < 255:
        return im
    original = im.copy()

    def is_bg(x, y):
        r, g, b, a = px[x, y]
        return a == 0 or (r <= threshold and g <= threshold and b <= threshold)

    seen = bytearray(w * h)
    q = deque()
    for x in range(w):
        q.append((x, 0))
        q.append((x, h - 1))
    for y in range(h):
        q.append((0, y))
        q.append((w - 1, y))
    while q:
        x, y = q.popleft()
        if x < 0 or y < 0 or x >= w or y >= h:
            continue
        i = y * w + x
        if seen[i]:
            continue
        seen[i] = 1
        if not is_bg(x, y):
            continue
        px[x, y] = (0, 0, 0, 0)
        q.append((x + 1, y))
        q.append((x - 1, y))
        q.append((x, y + 1))
        q.append((x, y - 1))
    n = w * h
    transparent = im.getchannel("A").histogram()[0]
    if n and transparent / n > max_transparent:
        return original
    return im


def save_webp(img, dest, *, lossy=False, quality=90):
    dest = os.path.splitext(dest)[0] + ".webp"
    os.makedirs(os.path.dirname(dest) or ".", exist_ok=True)
    if lossy:
        img.convert("RGB").save(dest, "WEBP", quality=quality, method=4)
        return dest
    rgba = img.convert("RGBA")
    if rgba.getchannel("A").getextrema() == (255, 255):
        img.convert("RGB").save(dest, "WEBP", quality=quality, method=4)
    else:
        rgba.save(dest, "WEBP", lossless=True, exact=True)
    return dest


def parse_atlas(path):
    d = wpk_payload(path)
    count = struct.unpack_from("<i", d, 0)[0]
    off = 4
    sprites = []
    for _ in range(count):
        nlen = d[off]
        off += 1
        name = d[off : off + nlen].decode("ascii", errors="replace")
        off += nlen
        x, y, w, h = struct.unpack_from("<iiii", d, off)
        off += 16
        sprites.append((name, x, y, w, h))
    fmt, aw, ah, _mips, nbytes = struct.unpack_from("<iiiii", d, off)
    pixels = d[-nbytes:] if nbytes else d[off + 20 :]
    if len(pixels) < nbytes:
        pixels = d[-nbytes:]
    return sprites, fmt, aw, ah, pixels


def atlas_image(fmt, aw, ah, pixels, r_high):
    if fmt == 6:
        return decode_etc1(pixels, aw, ah)
    if fmt == 1:
        return decode_rgba(pixels, aw, ah)
    if fmt == 9:
        return decode_rgba4444(pixels, aw, ah)
    return decode_16bit(pixels, aw, ah, r_high=r_high)


def save_crops(sprites, atlas, out_dir, *, lossy=False, chroma=False):
    os.makedirs(out_dir, exist_ok=True)
    n = 0
    for name, x, y, w, h in sprites:
        crop = atlas.crop((x, y, min(x + w, atlas.width), min(y + h, atlas.height)))
        if chroma and name.endswith("_character") and not name.endswith("_character_glow"):
            crop = chroma_key_standee(crop)
        save_webp(crop, os.path.join(out_dir, name + ".webp"), lossy=lossy)
        n += 1
    return n


def extract_texture2d(path, dest, r_high=True, lossy=False):
    d = wpk_payload(path)
    fmt = struct.unpack_from("<i", d, 0)[0]
    w = struct.unpack_from("<I", d, 4)[0]
    h = struct.unpack_from("<I", d, 8)[0]
    if fmt == 1:
        img = decode_rgba(d[16:], w, h)
    else:
        img = decode_16bit(d[16 : 16 + w * h * 2], w, h, r_high=r_high)
    dest = save_webp(img, dest, lossy=lossy)
    return fmt, w, h, dest


def extract_wav(path, dest):
    d = wpk_payload(path)
    i = d.find(b"RIFF")
    if i < 0:
        print(f"  no WAV in {os.path.basename(path)}")
        return False
    os.makedirs(os.path.dirname(dest), exist_ok=True)
    open(dest, "wb").write(d[i:])
    return True


def copy_json():
    mapping = {
        os.path.join(CONTENT, "CardDecks", "BaseDeck"): "BaseDeck",
        os.path.join(CONTENT, "CardDecks", "HiddenHeros"): "HiddenHeros",
        os.path.join(CONTENT, "CardDecks", "PlayerChoice"): "PlayerChoice",
        os.path.join(CONTENT, "CardDecks", "ToolsHeroKind"): "ToolsHeroKind",
    }
    for src, name in mapping.items():
        dest = os.path.join(OUT_DATA, name)
        os.makedirs(dest, exist_ok=True)
        for fn in ("data.json", "ai_info.json"):
            sp = os.path.join(src, fn)
            if os.path.exists(sp):
                shutil.copy2(sp, os.path.join(dest, fn))
                print(f"  data {name}/{fn}")
    cred = os.path.join(CONTENT, "Common", "credits.json")
    if os.path.exists(cred):
        shutil.copy2(cred, os.path.join(OUT_DATA, "credits.json"))


def copy_music():
    src = os.path.join(CONTENT, "Audio", "Music")
    dest = os.path.join(OUT_AUDIO, "music")
    os.makedirs(dest, exist_ok=True)
    for fn in os.listdir(src):
        shutil.copy2(os.path.join(src, fn), os.path.join(dest, fn))
        print(f"  music {fn}")


COMPAT = {
    "soul": "icons/soul.webp",
    "wound": "icons/wound.webp",
    "icon_cleric": "icons/icon_cleric.webp",
    "icon_fighter": "icons/icon_fighter.webp",
    "icon_mage": "icons/icon_mage.webp",
    "icon_thief": "icons/icon_thief.webp",
    "bm_logo": "logos/bm_logo.webp",
    "intro_start_btn": "buttons/intro_start_btn.webp",
    "intro_start_btn_pressed": "buttons/intro_start_btn_pressed.webp",
    "intro_quit_btn": "buttons/intro_quit_btn.webp",
    "intro_quit_btn_pressed": "buttons/intro_quit_btn_pressed.webp",
    "options_bt": "buttons/options_bt.webp",
    "options_bt_pressed": "buttons/options_bt_pressed.webp",
    "back_bt": "buttons/back_bt.webp",
    "back_bt_pressed": "buttons/back_bt_pressed.webp",
    "big_button": "buttons/big_button.webp",
    "big_button_selected": "buttons/big_button_selected.webp",
    "button": "buttons/button.webp",
    "button_pressed": "buttons/button_pressed.webp",
    "ok_bt": "buttons/ok_bt.webp",
    "ok_bt_pressed": "buttons/ok_bt_pressed.webp",
    "boss_icon": "buttons/boss_icon.webp",
    "boss_multi_icon": "buttons/boss_multi_icon.webp",
    "options_icon": "buttons/options_icon.webp",
    "inapp_icon": "buttons/inapp_icon.webp",
    "settings_bt": "buttons/settings_bt.webp",
}


def extract_atlas_file(path, out_dir, r_high, *, lossy=False, chroma=False):
    sprites, fmt, aw, ah, pixels = parse_atlas(path)
    atlas = atlas_image(fmt, aw, ah, pixels, r_high)
    n = save_crops(sprites, atlas, out_dir, lossy=lossy, chroma=chroma)
    print(f"  {os.path.basename(path)}: fmt={fmt} {aw}x{ah} {n} sprites -> {os.path.relpath(out_dir, ROOT)}")
    return sprites, atlas


def write_card_manifest():
    faces = {}
    backs = {}
    for folder in ("base", "hidden", "playerchoice", "tools"):
        d = os.path.join(OUT_CARDS, folder)
        if not os.path.isdir(d):
            continue
        stems = {os.path.splitext(fn)[0] for fn in os.listdir(d) if fn.endswith(".webp")}
        for stem in stems:
            rel = f"{folder}/{stem}.webp"
            faces[stem] = rel
            if stem.startswith("back_"):
                backs[stem] = rel
        for stem in list(stems):
            if stem.endswith("a") and stem[:-1] not in stems:
                faces[stem[:-1]] = f"{folder}/{stem}.webp"
    payload = {"faces": faces, "backs": backs}
    os.makedirs(os.path.dirname(MANIFEST), exist_ok=True)
    with open(MANIFEST, "w", encoding="utf-8") as f:
        json.dump(payload, f, indent=2, sort_keys=True)
        f.write("\n")
    print(f"  manifest {len(faces)} faces / {len(backs)} backs")


def main():
    if not os.path.isdir(CONTENT):
        sys.exit(f"missing unpacked APK at {APK}")

    copy_json()
    copy_music()

    sfx_src = os.path.join(CONTENT, "Audio", "Sfx")
    sfx_dest = os.path.join(OUT_AUDIO, "sfx")
    for fn in os.listdir(sfx_src):
        if fn.endswith(".wpk"):
            extract_wav(os.path.join(sfx_src, fn), os.path.join(sfx_dest, fn.replace(".wpk", ".wav")))
    print("  sfx wavs extracted")

    # UI atlases (fmt 9 = RGBA4444; r_high only affects DXT1 sheets)
    ui_sheets = {
        "INGAME.wpk": os.path.join(OUT_UI, "ingame"),
        "NAVIGATION.wpk": os.path.join(OUT_UI, "navigation"),
        "AVATAR.wpk": os.path.join(OUT_UI, "avatar"),
        "TUTORIAL.wpk": os.path.join(OUT_UI, "tutorial"),
        "GRADIENTS.wpk": os.path.join(OUT_UI, "gradients"),
        "LOADING_SCREEN.wpk": os.path.join(OUT_UI, "loading"),
    }
    common = os.path.join(CONTENT, "Common")
    loading = os.path.join(CONTENT, "Loading")
    for sheet, dest in ui_sheets.items():
        folder = common if sheet != "LOADING_SCREEN.wpk" else loading
        path = os.path.join(folder, sheet)
        if os.path.exists(path):
            sprites, atlas = extract_atlas_file(path, dest, r_high=False)
            sm = {n: (x, y, w, h) for n, x, y, w, h in sprites}
            for name, rel in COMPAT.items():
                if name in sm:
                    x, y, w, h = sm[name]
                    crop = atlas.crop((x, y, min(x + w, atlas.width), min(y + h, atlas.height)))
                    save_webp(crop, os.path.join(OUT_UI, rel))

    # Backgrounds (R5G6B5 / fmt 8)
    bg_dir = os.path.join(OUT_UI, "backgrounds")
    for name in ("menu_bg", "intro_bg", "multiplayer_bg", "gallery_bg"):
        p = os.path.join(common, f"{name}.wpk")
        if os.path.exists(p):
            fmt, w, h, dest = extract_texture2d(p, os.path.join(bg_dir, f"{name}.webp"), r_high=True, lossy=True)
            print(f"  bg {name} fmt={fmt} {w}x{h}")
    p = os.path.join(loading, "loading_bg.wpk")
    if os.path.exists(p):
        extract_texture2d(p, os.path.join(bg_dir, "loading_bg.webp"), r_high=True, lossy=True)

    # Dungeon backgrounds: ETC1 (fmt 6), flattened RGB
    decks = os.path.join(CONTENT, "CardDecks")
    for rel in (
        "BaseDeck/Assets/dungeonbg_bma001_bma004.wpk",
        "BaseDeck/Assets/dungeonbg_bma005_bma008.wpk",
        "PlayerChoice/Assets/dungeonbg_ksa001_ksa004.wpk",
        "PlayerChoice/Assets/dungeonbg_ksa005_ksa007.wpk",
    ):
        p = os.path.join(decks, rel.replace("/", os.sep))
        if os.path.exists(p):
            extract_atlas_file(p, OUT_DUNGEON, r_high=False, lossy=True)

    # Boss standing sprites + profiles
    for rel in ("BaseDeck/Assets/boss_profile.wpk", "PlayerChoice/Assets/boss_profile.wpk"):
        p = os.path.join(decks, rel.replace("/", os.sep))
        if os.path.exists(p):
            extract_atlas_file(p, OUT_CHARS, r_high=False, chroma=True)

    # In-dungeon hero characters
    for rel in (
        "BaseDeck/Assets/hero_characters.wpk",
        "HiddenHeros/Assets/hero_characters.wpk",
        "PlayerChoice/Assets/hero_characters.wpk",
    ):
        p = os.path.join(decks, rel.replace("/", os.sep))
        if os.path.exists(p):
            extract_atlas_file(p, os.path.join(OUT_CHARS, "heroes"), r_high=False, chroma=True)

    extract_atlas_file(os.path.join(CONTENT, "EXPANSIONS.wpk"), OUT_EXP, r_high=False)

    # Ninepatches + tutorial images
    nine = os.path.join(CONTENT, "NinePatch")
    if os.path.isdir(nine):
        os.makedirs(OUT_NINE, exist_ok=True)
        for fn in os.listdir(nine):
            if fn.endswith(".wpk"):
                extract_texture2d(os.path.join(nine, fn), os.path.join(OUT_NINE, fn.replace(".wpk", ".webp")), r_high=True)
    tut = os.path.join(CONTENT, "Tutorial")
    os.makedirs(OUT_TUT, exist_ok=True)
    for fn in os.listdir(tut):
        src = os.path.join(tut, fn)
        if fn.endswith(".xml"):
            shutil.copy2(src, os.path.join(OUT_TUT, fn))
        elif fn.endswith(".wpk"):
            extract_texture2d(src, os.path.join(OUT_TUT, fn.replace(".wpk", ".webp")), r_high=True)

    # Card atlases (do not overwrite wiki webp). Pixel-art faces are RGBA4444.
    card_jobs = [
        ("BaseDeck/Assets/back_boss-bma013.wpk", "base"),
        ("BaseDeck/Assets/bma014-bma029.wpk", "base"),
        ("BaseDeck/Assets/bma030-bma047.wpk", "base"),
        ("BaseDeck/Assets/bma048-bma066.wpk", "base"),
        ("BaseDeck/Assets/bma067-bma086.wpk", "base"),
        ("BaseDeck/Assets/bma087-bma096.wpk", "base"),
        ("HiddenHeros/Assets/bmh056-bmh075.wpk", "hidden"),
        ("HiddenHeros/Assets/bmh076-bmh095.wpk", "hidden"),
        ("HiddenHeros/Assets/bmh096-bmh096.wpk", "hidden"),
        ("PlayerChoice/Assets/ksa001-ksa017.wpk", "playerchoice"),
        ("ToolsHeroKind/Assets/back_item-thk019.wpk", "tools"),
        ("ToolsHeroKind/Assets/thk020-thk025.wpk", "tools"),
    ]
    for rel, folder in card_jobs:
        p = os.path.join(decks, rel.replace("/", os.sep))
        if os.path.exists(p):
            extract_atlas_file(p, os.path.join(OUT_CARDS, folder), r_high=False)

    write_card_manifest()
    print("done")


if __name__ == "__main__":
    main()
