#!/usr/bin/env python3
"""List NAVIGATION.wpk sprite names and try RGBA4444 / DXT1 channel orders.

Compares decoded atlas crops against docs/reference/11_menu.png (gold icons)
and reports the layout that keeps gold as gold (high R+G, low B) instead of
magenta/purple (high R+B).
"""
from __future__ import annotations

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from extract_apk_226 import CONTENT, parse_atlas, rgb565, decode_dxt1, decode_rgba4444  # noqa: E402

from PIL import Image
import struct


def decode_4444_variant(pixels, w, h, order):
    """order is a 4-char string using R,G,B,A for bit fields 15-12, 11-8, 7-4, 3-0."""
    img = Image.new("RGBA", (w, h))
    out = img.load()
    idx = {ch: i for i, ch in enumerate(order)}
    for y in range(h):
        row = y * w
        for x in range(w):
            v = pixels[(row + x) * 2] | (pixels[(row + x) * 2 + 1] << 8)
            nib = [(v >> 12) & 0xF, (v >> 8) & 0xF, (v >> 4) & 0xF, v & 0xF]
            r, g, b, a = (nib[idx[c]] * 17 for c in "RGBA")
            out[x, y] = (r, g, b, a)
    return img


def gold_score(img):
    """Higher = more yellow/gold pixels, fewer magenta/cyan/pure-red/pure-green."""
    px = img.convert("RGB").resize((64, 64))
    data = list(px.getdata())
    n = len(data) or 1
    gold = mag = red = green = 0
    for r, g, b in data:
        if r > 160 and g > 120 and b < 90:
            gold += 1
        if r > 140 and b > 140 and g < 100:
            mag += 1
        if r > 180 and g < 80 and b < 80:
            red += 1
        if g > 180 and r < 80 and b < 80:
            green += 1
    return gold / n, mag / n, red / n, green / n


def main():
    nav = os.path.join(CONTENT, "Common", "NAVIGATION.wpk")
    sprites, fmt, aw, ah, pixels = parse_atlas(nav)
    print(f"NAVIGATION fmt={fmt} {aw}x{ah} {len(sprites)} sprites")
    for name, x, y, w, h in sorted(sprites):
        print(f"  {name:40s} {w:4d}x{h:<4d} @ {x},{y}")

    print("\n--- 4444 channel-order scores on full atlas ---")
    for order in ("RGBA", "RBGA", "GRBA", "GBRA", "BRGA", "BGRA", "ARGB", "ABGR"):
        img = decode_4444_variant(pixels, aw, ah, order)
        gold, mag, red, green = gold_score(img)
        print(f"  {order}: gold={gold:.3f} magenta={mag:.3f} red={red:.3f} green={green:.3f}")

    dng = os.path.join(CONTENT, "CardDecks", "BaseDeck", "Assets", "dungeonbg_bma001_bma004.wpk")
    if os.path.isfile(dng):
        sprites, fmt, aw, ah, pixels = parse_atlas(dng)
        print(f"\nDUNGEON atlas fmt={fmt} {aw}x{ah}")
        for r_high in (False, True):
            img = decode_dxt1(pixels, aw, ah, r_high=r_high)
            gold, mag, red, green = gold_score(img)
            print(f"  DXT1 r_high={r_high}: gold={gold:.3f} magenta={mag:.3f} red={red:.3f} green={green:.3f}")


if __name__ == "__main__":
    main()
