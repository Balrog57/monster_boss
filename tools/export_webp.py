#!/usr/bin/env python3
"""
export_webp.py - Convert leftover PNG/JPG UI + APK cards to WebP.

Also chroma-keys still-opaque *_character standees (not glow / hr / profile art)
and drops duplicate wiki JPGs when a WebP already exists.
"""
import os
import sys

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from extract_apk_226 import chroma_key_standee, save_webp  # noqa: E402

UI = os.path.join(ROOT, "assets", "ui")
CARDS_APK = os.path.join(ROOT, "assets", "apk_cards")
CARDS_WIKI = os.path.join(ROOT, "assets", "cards")
EXTS = (".png", ".jpg", ".jpeg")


def should_chroma(path):
    name = os.path.basename(path).lower()
    if not name.endswith("_character.png") and not name.endswith("_character.webp"):
        return False
    if "_glow" in name or name.endswith("_hr.png") or name.endswith("_hr.webp"):
        return False
    return True


def convert_tree(root, *, chroma=False, delete_src=True):
    n_ok = n_skip = n_chroma = 0
    for dirpath, _dirs, files in os.walk(root):
        for fn in files:
            ext = os.path.splitext(fn)[1].lower()
            if ext not in EXTS:
                continue
            src = os.path.join(dirpath, fn)
            dest = os.path.splitext(src)[0] + ".webp"
            try:
                if os.path.exists(dest) and os.path.abspath(src) != os.path.abspath(dest):
                    if delete_src:
                        os.remove(src)
                    n_skip += 1
                    continue
                img = Image.open(src)
                if chroma and should_chroma(src):
                    before = img.convert("RGBA").getchannel("A").getextrema()
                    img = chroma_key_standee(img)
                    after = img.getchannel("A").getextrema()
                    if after != before:
                        n_chroma += 1
                lossy = img.mode in ("RGB", "L") or ext in (".jpg", ".jpeg")
                save_webp(img, dest, lossy=lossy)
                n_ok += 1
                if delete_src and os.path.abspath(src) != os.path.abspath(dest):
                    os.remove(src)
            except Exception as e:
                n_skip += 1
                print(f"  skip {os.path.relpath(src, ROOT)}: {e}")
    return n_ok, n_skip, n_chroma


def drop_wiki_jpg():
    n = 0
    if not os.path.isdir(CARDS_WIKI):
        return 0
    for dirpath, _dirs, files in os.walk(CARDS_WIKI):
        for fn in files:
            ext = os.path.splitext(fn)[1].lower()
            if ext not in (".jpg", ".jpeg"):
                continue
            src = os.path.join(dirpath, fn)
            webp = os.path.splitext(src)[0] + ".webp"
            if os.path.exists(webp):
                os.remove(src)
                n += 1
    return n


def main():
    print("ui + apk_cards -> webp")
    u = convert_tree(UI, chroma=True)
    c = convert_tree(CARDS_APK, chroma=False)
    d = drop_wiki_jpg()
    print(f"  ui converted={u[0]} skipped={u[1]} chroma={u[2]}")
    print(f"  apk_cards converted={c[0]} skipped={c[1]}")
    print(f"  dropped wiki jpg duplicates={d}")


if __name__ == "__main__":
    main()
