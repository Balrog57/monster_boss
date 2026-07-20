#!/usr/bin/env python3
"""
build_fonts.py - Rebuild valid TTF fonts from the Boss Monster APK's
WaveEngine SpriteFont (.TTF.wpk) assets.

The APK does NOT ship real TrueType fonts: each "<name>.TTF.wpk" is a
WaveEngine.Framework.Graphics.SpriteFont, i.e. a pre-rendered bitmap glyph
atlas plus a metrics/character-map blob.  The ".TTF" files that were copied
into assets/fonts/ are just the (renamed) SpriteFont payload, so browsers
reject them with "OTS parsing error".

This tool reverse-engineers the SpriteFont layout and rebuilds a genuine,
browser-loadable outline TTF for each font, preserving the exact pixel art
of the original game.

SpriteFont payload layout (after gzip decompression of the WPK stream):

  offset 0   : int32  atlas width  (W)
  offset 4   : int32  atlas height (H)
  offset 8   : int32  mip count (1)
  offset 12  : int32  texture byte size == W*H*4 (32-bit RGBA)
  offset 16  : texture pixels, W*H*4 bytes, row-major, RGBA
  after tex  : int32  N1, then N1 records of 4*int32 = glyph crop
                        [x, y, w, h] in the atlas, indexed by glyph id
               int32  N2, then N2 records of 4*int32 = glyph metrics
                        [leftBearing, topOffset, advanceWidth, lineHeight]
               int32  N3, then a UTF-8 encoded string of N3 characters;
                        the i-th character is the code point mapped to
                        glyph id i (an identity list U+0000..U+00FF for the
                        256-glyph fonts).

Vertical model: every glyph lives in a cell `lineHeight` rows tall; its crop
is placed at (leftBearing, topOffset) inside that cell and the text baseline
sits `B` rows below the top of the cell, where B is the (statistical) bottom
of the capital letters.  We recover B as the mode of (topOffset + h).

Usage:
  python tools/build_fonts.py            # rebuild all four fonts
"""
import gzip
import os
import struct
from collections import Counter

from PIL import Image

from fontTools.fontBuilder import FontBuilder
from fontTools.pens.ttGlyphPen import TTGlyphPen

APK_FONTS = "boss-monster-2-4-12/resources/assets/Content/Assets/Fonts"
OUT_DIR = "assets/fonts"

# Each output font -> source WPK + friendly family name
FONTS = {
    "arcadepix": ("arcadepix.TTF.wpk", "ArcadePix"),
    "arcadepix2": ("arcadepix2.TTF.wpk", "ArcadePix2"),
    "bookman_old_style": ("bookman_old_style.TTF.wpk", "Bookman Old Style"),
    "f04b03": ("f04b03.TTF.wpk", "04b03"),
}

SCALE = 64          # font units per atlas pixel
ALPHA_THRESHOLD = 128  # atlas alpha >= this -> opaque pixel


# ---------------------------------------------------------------------------
# SpriteFont parsing
# ---------------------------------------------------------------------------
def parse_spritefont(path):
    """Return (atlas, crops, metrics, chars) for a SpriteFont WPK.

    atlas   : PIL RGBA image (the glyph texture)
    crops   : list of (x, y, w, h)  indexed by glyph id
    metrics : list of (leftBearing, topOffset, advance, lineHeight)
    chars   : list of unicode chars, chars[i] -> glyph id i
    """
    raw = open(path, "rb").read()
    if raw[:4] != b"WPK\x00":
        raise ValueError(f"{path}: not a WPK file")
    data = gzip.decompress(raw[raw.find(b"\x1f\x8b"):])

    w, h, _mips, texsize = struct.unpack_from("<4i", data, 0)
    assert texsize == w * h * 4, f"{path}: unexpected texture size"
    atlas = Image.frombytes("RGBA", (w, h), bytes(data[16:16 + texsize]))

    cm = data[16 + texsize:]
    off = 0
    (n1,) = struct.unpack_from("<i", cm, off); off += 4
    crops = [struct.unpack_from("<4i", cm, off + i * 16) for i in range(n1)]
    off += n1 * 16
    (n2,) = struct.unpack_from("<i", cm, off); off += 4
    metrics = [struct.unpack_from("<4i", cm, off + i * 16) for i in range(n2)]
    off += n2 * 16
    (n3,) = struct.unpack_from("<i", cm, off); off += 4
    # n3 characters, UTF-8 encoded (variable byte length)
    chars = cm[off:].decode("utf-8", errors="ignore")[:n3]
    return atlas, crops, metrics, list(chars)


def baseline_row(metrics, crops):
    """Recover the baseline (rows from top of cell) as the mode of the
    bottom edge (topOffset + h) of the non-empty glyphs."""
    bottoms = Counter()
    for i, (lb, top, adv, lh) in enumerate(metrics):
        x, y, w, h = crops[i]
        if h > 0 and w > 0:
            bottoms[top + h] += 1
    return bottoms.most_common(1)[0][0]


# ---------------------------------------------------------------------------
# Glyph -> outline conversion
# ---------------------------------------------------------------------------
def glyph_contours(atlas, crop, metric, base):
    """Build TrueType contours for one glyph.

    Returns (pen, lsb, advance_units, y_min, y_max) where pen has the
    pixel-run rectangles drawn in font units (y up, baseline at 0).
    y_min/y_max are None for empty glyphs.
    """
    x, y, w, h = crop
    lb, top, adv, lh = metric
    pen = TTGlyphPen(None)
    if w <= 0 or h <= 0:
        return pen, 0, adv * SCALE, None, None

    alpha = atlas.crop((x, y, x + w, y + h)).split()[3]
    px = alpha.load()

    y_min = None
    y_max = None
    for r in range(h):                       # r = row within the crop
        c = 0
        while c < w:
            if px[c, r] >= ALPHA_THRESHOLD:
                c2 = c
                while c2 < w and px[c2, r] >= ALPHA_THRESHOLD:
                    c2 += 1
                # pixel run [c, c2) on row r -> one rectangle
                x0 = (lb + c) * SCALE
                x1 = (lb + c2) * SCALE
                y_top = (base - top - r) * SCALE
                y_bot = (base - top - r - 1) * SCALE
                pen.moveTo((x0, y_bot))
                pen.lineTo((x1, y_bot))
                pen.lineTo((x1, y_top))
                pen.lineTo((x0, y_top))
                pen.closePath()
                y_min = y_bot if y_min is None else min(y_min, y_bot)
                y_max = y_top if y_max is None else max(y_max, y_top)
                c = c2
            else:
                c += 1

    return pen, lb * SCALE, adv * SCALE, y_min, y_max


# ---------------------------------------------------------------------------
# Font assembly
# ---------------------------------------------------------------------------
def build_font(src, family, out_path):
    atlas, crops, metrics, chars = parse_spritefont(src)
    base = baseline_row(metrics, crops)
    lh = metrics[0][3] if metrics else 21

    # char -> glyph id
    char_to_id = {}
    for gid, ch in enumerate(chars):
        char_to_id.setdefault(ord(ch), gid)

    glyph_order = [".notdef"]
    glyphs = {}
    hmtx = {}
    cmap = {}
    extents = []

    # .notdef : empty glyph with the space advance
    pen = TTGlyphPen(None)
    glyphs[".notdef"] = pen.glyph()
    space_adv = metrics[char_to_id.get(32, 0)][2] if 32 in char_to_id else 8
    hmtx[".notdef"] = (space_adv * SCALE, 0)

    for code in sorted(char_to_id):
        if code < 32:                        # skip C0 controls
            continue
        gid = char_to_id[code]
        if gid >= len(crops):
            continue
        name = "uni%04X" % code
        pen, lsb, adv, y_min, y_max = glyph_contours(atlas, crops[gid], metrics[gid], base)
        glyphs[name] = pen.glyph()
        hmtx[name] = (adv, lsb)
        cmap[code] = name
        extents.append((pen, lsb, adv, y_min, y_max))
        if name not in glyph_order:
            glyph_order.append(name)

    upm = lh * SCALE
    # ascender / descender from actual glyph extents (tracked while drawing)
    asc = base * SCALE
    desc = (base - lh) * SCALE
    for (_pen, _lsb, _adv, y_min, y_max) in extents:
        if y_min is not None:
            desc = min(desc, y_min)
            asc = max(asc, y_max)

    fb = FontBuilder(upm, isTTF=True)
    fb.setupGlyphOrder(glyph_order)
    fb.setupCharacterMap(cmap)
    fb.setupGlyf(glyphs)
    fb.setupHorizontalMetrics(hmtx)
    fb.setupHorizontalHeader(ascent=asc, descent=desc)
    fb.setupOS2(sTypoAscender=asc, sTypoDescender=desc, sTypoLineGap=0,
                usWinAscent=asc, usWinDescent=-desc)
    fb.setupNameTable({
        "familyName": family,
        "styleName": "Regular",
        "uniqueFontIdentifier": "BossMonster.%s" % family.replace(" ", ""),
        "fullName": family,
        "psName": family.replace(" ", ""),
        "version": "Version 2.4.12 (rebuilt from SpriteFont)",
    })
    fb.setupPost()
    fb.save(out_path)
    return len(glyph_order) - 1, base, lh


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    for stem, (wpk, family) in FONTS.items():
        src = os.path.join(APK_FONTS, wpk)
        out = os.path.join(OUT_DIR, stem + ".TTF")
        n, base, lh = build_font(src, family, out)
        print("%-20s -> %s  (%d glyphs, baseline=%d, lineHeight=%d)"
              % (stem, out, n, base, lh))


if __name__ == "__main__":
    main()
