#!/usr/bin/env python3
"""build_bmfonts.py - Export the APK SpriteFonts as BMFont (.fnt + .png) for Godot.

The vector TTFs from build_fonts.py threshold the atlas alpha at 128, which loses the dark inner strokes
and soft diagonals of the striped font (arcadepix2: 'S' reads like 'B').  A BMFont keeps the original RGBA
atlas, so Godot draws exactly what the APK draws (white glyph tinted by the font colour, black details kept).

  python tools/build_bmfonts.py
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build_fonts as bf  # noqa: E402

OUT = "src/frontend/assets/fonts"


def build(stem, wpk):
    atlas, crops, metrics, chars = bf.parse_spritefont(os.path.join(bf.APK_FONTS, wpk))
    lh = metrics[0][3]
    base = bf.baseline_row(metrics, crops)
    png = stem + "_bm.png"
    atlas.save(os.path.join(OUT, png))
    seen = set()
    rows = []
    for gid, ch in enumerate(chars):
        code = ord(ch)
        if code < 32 or code in seen or gid >= len(crops):
            continue
        seen.add(code)
        x, y, w, h = crops[gid]
        lb, top, adv, _lh = metrics[gid]
        rows.append("char id=%d x=%d y=%d width=%d height=%d xoffset=%d yoffset=%d xadvance=%d page=0 chnl=15"
                    % (code, x, y, max(w, 0), max(h, 0), lb, top, adv))
    lines = [
        'info face="%s" size=%d bold=0 italic=0 charset="" unicode=1 stretchH=100 smooth=0 aa=1 padding=0,0,0,0 spacing=0,0 outline=0' % (stem, lh),
        "common lineHeight=%d base=%d scaleW=%d scaleH=%d pages=1 packed=0" % (lh, base, atlas.size[0], atlas.size[1]),
        'page id=0 file="%s"' % png,
        "chars count=%d" % len(rows),
    ] + rows
    with open(os.path.join(OUT, stem + ".fnt"), "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lines) + "\n")
    print("%-18s %d glyphs, lineHeight=%d base=%d" % (stem, len(rows), lh, base))


if __name__ == "__main__":
    for stem, (wpk, _fam) in bf.FONTS.items():
        build(stem, wpk)
