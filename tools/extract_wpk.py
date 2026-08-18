#!/usr/bin/env python3
"""
extract_wpk.py - Decode WaveEngine WPK spritesheets from the Boss Monster APK.

The Boss Monster APK (v2.4.12) stores card art as WaveEngine .wpk spritesheets.
The format (reverse-engineered, documented in README.md):

  Header:
    - magic: "WPK\0"           (4 bytes)
    - type:   null-terminated ASCII string (e.g. "2WaveEngine...SpriteSheet v1.0.0.0")
    - flag:   1 byte (0x01)    compression flag
    - payload: gzip stream     (starts with 0x1f 0x8b)

  Decompressed payload:
    - count: int32             number of sprites
    - per sprite:
        - name_len: byte
        - name:    ASCII (sprite id, e.g. "bma089")
        - x, y, w, h: int32 x4  rectangle in the atlas
    - separator: int32 (0)
    - format:   int32 (13 = E_RBG 16-bit)
    - width:    int32 (atlas width, e.g. 2048)
    - height:   int32 (atlas height, e.g. 1024)
    - mips:     int32
    - ... padding / extra metadata
    - pixel data: width * height * 2 bytes (16-bit, at the END of the buffer)

  E_RBG 16-bit pixel layout (little-endian uint16):
    bits 11-15: R   (5 bits)
    bits  5-10: B   (6 bits)
    bits  0-4:  G   (5 bits)
  Note the unusual R-B-G ordering (not RGB565), which is why a naive RGB565
  decode swaps blue and green and yields greenish cards.

Usage:
  python tools/extract_wpk.py <wpk-file> [--out DIR] [--variant NAME]
  python tools/extract_wpk.py <wpk-file> --validate       # render decode variants
  python tools/extract_wpk.py --all                       # extract every card sheet
"""
import argparse
import gzip
import os
import struct
import sys

from PIL import Image

E_RBG_FORMAT = 13


# ---------------------------------------------------------------------------
# WPK parsing
# ---------------------------------------------------------------------------
def parse_wpk(path):
    """Return (sprites, atlas_image) for a WPK spritesheet.

    sprites: list of (name, x, y, w, h)
    atlas_image: PIL RGB image of the full decoded texture
    """
    with open(path, "rb") as f:
        raw = f.read()

    if raw[:4] != b"WPK\0":
        raise ValueError(f"{path}: not a WPK file (bad magic {raw[:4]!r})")

    # Find the gzip stream (0x1f 0x8b) that follows the type string + flag.
    gzip_idx = raw.find(b"\x1f\x8b")
    if gzip_idx < 0:
        raise ValueError(f"{path}: no gzip stream found")
    decompressed = gzip.decompress(raw[gzip_idx:])

    off = 0
    count = struct.unpack_from("<i", decompressed, off)[0]
    off += 4
    sprites = []
    for _ in range(count):
        name_len = decompressed[off]
        off += 1
        name = decompressed[off:off + name_len].decode("ascii")
        off += name_len
        x, y, w, h = struct.unpack_from("<iiii", decompressed, off)
        off += 16
        sprites.append((name, x, y, w, h))

    # Texture metadata: separator(0) + format + width + height + mips
    _sep = struct.unpack_from("<i", decompressed, off)[0]
    off += 4
    fmt = struct.unpack_from("<i", decompressed, off)[0]
    off += 4
    width = struct.unpack_from("<I", decompressed, off)[0]
    off += 4
    height = struct.unpack_from("<I", decompressed, off)[0]
    off += 4
    _mips = struct.unpack_from("<i", decompressed, off)[0]
    off += 4

    if fmt != E_RBG_FORMAT:
        sys.stderr.write(
            f"warning: {path} format is {fmt}, expected {E_RBG_FORMAT} (E_RBG)\n"
        )

    # Pixel data lives at the END of the buffer.
    pixel_size = width * height * 2
    pixel_start = len(decompressed) - pixel_size
    if pixel_start < off:
        raise ValueError(
            f"{path}: pixel data ({pixel_size}B) does not fit in buffer ({len(decompressed)}B)"
        )
    pixels = decompressed[pixel_start:pixel_start + pixel_size]

    atlas = decode_e_rbg(pixels, width, height)
    return sprites, atlas


def decode_e_rbg(pixels, width, height):
    """Decode E_RBG 16-bit little-endian pixel data into an RGB PIL image.

    E_RBG bit layout: R(11-15) B(5-10) G(0-4).
    """
    img = Image.new("RGB", (width, height))
    out = img.load()
    for y in range(height):
        row = y * width
        for x in range(width):
            v = pixels[(row + x) * 2] | (pixels[(row + x) * 2 + 1] << 8)
            r5 = (v >> 11) & 0x1F
            b6 = (v >> 5) & 0x3F
            g5 = v & 0x1F
            # Expand to 8-bit channels
            out[x, y] = (
                (r5 << 3) | (r5 >> 2),
                (g5 << 3) | (g5 >> 2),
                (b6 << 2) | (b6 >> 4),
            )
    return img


# ---------------------------------------------------------------------------
# Variant decoders (for validation only)
# ---------------------------------------------------------------------------
def decode_variant(pixels, width, height, mode):
    """Decode with an alternate channel mapping for color validation.

    mode: 'e_rbg' (correct), 'rgb565', 'bgr565', 'rbg_swap'
    """
    img = Image.new("RGB", (width, height))
    out = img.load()
    for y in range(height):
        row = y * width
        for x in range(width):
            v = pixels[(row + x) * 2] | (pixels[(row + x) * 2 + 1] << 8)
            r5 = (v >> 11) & 0x1F
            g6_std = (v >> 5) & 0x3F   # standard RGB565 green position
            b5_std = v & 0x1F          # standard RGB565 blue position
            # E_RBG positions
            b6 = (v >> 5) & 0x3F
            g5 = v & 0x1F
            if mode == "e_rbg":
                out[x, y] = (
                    (r5 << 3) | (r5 >> 2),
                    (g5 << 3) | (g5 >> 2),
                    (b6 << 2) | (b6 >> 4),
                )
            elif mode == "rgb565":
                out[x, y] = (
                    (r5 << 3) | (r5 >> 2),
                    (g6_std << 2) | (g6_std >> 4),
                    (b5_std << 3) | (b5_std >> 2),
                )
            elif mode == "bgr565":
                out[x, y] = (
                    (b5_std << 3) | (b5_std >> 2),
                    (g6_std << 2) | (g6_std >> 4),
                    (r5 << 3) | (r5 >> 2),
                )
            elif mode == "rbg_swap":
                # E_RBG but swap the recovered G and B (what a naive decode produces)
                out[x, y] = (
                    (r5 << 3) | (r5 >> 2),
                    (b6 << 2) | (b6 >> 4),
                    (g5 << 3) | (g5 >> 2),
                )
    return img


# ---------------------------------------------------------------------------
# Sprite cropping + output
# ---------------------------------------------------------------------------
def crop_sprites(sprites, atlas, out_dir, prefix=""):
    os.makedirs(out_dir, exist_ok=True)
    written = []
    for name, x, y, w, h in sprites:
        # Clamp to atlas bounds (some rects overshoot by a pixel)
        x2 = min(x + w, atlas.width)
        y2 = min(y + h, atlas.height)
        crop = atlas.crop((x, y, x2, y2))
        fname = f"{prefix}{name}.png"
        crop.save(os.path.join(out_dir, fname))
        written.append(fname)
    return written


def render_validation(wpk_path, out_dir):
    """Render the first sprite under several decode hypotheses as a montage."""
    with open(wpk_path, "rb") as f:
        raw = f.read()
    gzip_idx = raw.find(b"\x1f\x8b")
    decompressed = gzip.decompress(raw[gzip_idx:])

    off = 0
    count = struct.unpack_from("<i", decompressed, off)[0]
    off += 4
    first_name = None
    first_rect = None
    for _ in range(count):
        name_len = decompressed[off]; off += 1
        name = decompressed[off:off + name_len].decode("ascii"); off += name_len
        x, y, w, h = struct.unpack_from("<iiii", decompressed, off); off += 16
        if first_name is None:
            first_name, first_rect = name, (x, y, w, h)

    _sep = struct.unpack_from("<i", decompressed, off)[0]; off += 4
    _fmt = struct.unpack_from("<i", decompressed, off)[0]; off += 4
    width = struct.unpack_from("<I", decompressed, off)[0]; off += 4
    height = struct.unpack_from("<I", decompressed, off)[0]; off += 4
    pixel_size = width * height * 2
    pixels = decompressed[len(decompressed) - pixel_size:]

    os.makedirs(out_dir, exist_ok=True)
    montage_w = 700
    crops = []
    for mode in ["e_rbg", "rgb565", "bgr565", "rbg_swap"]:
        atlas = decode_variant(pixels, width, height, mode)
        x, y, w, h = first_rect
        crop = atlas.crop((x, y, min(x + w, width), min(y + h, height)))
        crops.append(crop)
    # Stack vertically into a montage
    total_h = sum(c.height for c in crops) + 10 * (len(crops) - 1)
    montage = Image.new("RGB", (montage_w, total_h), (32, 32, 32))
    yy = 0
    labels = ["e_rbg (hypothesis)", "rgb565", "bgr565", "rbg_swap (greenish)"]
    from PIL import ImageDraw
    draw = ImageDraw.Draw(montage)
    for label, crop in zip(labels, crops):
        resized = crop.resize((montage_w, crop.height))
        montage.paste(resized, (0, yy))
        draw.rectangle((0, yy, 220, yy + 24), fill=(0, 0, 0))
        draw.text((6, yy + 4), label, fill=(255, 255, 255))
        yy += crop.height + 10
    out = os.path.join(out_dir, f"validate_{first_name}.png")
    montage.save(out)
    print(f"Validation montage: {out}")
    return out


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------
def main():
    ap = argparse.ArgumentParser(description="Extract sprites from a WPK spritesheet")
    ap.add_argument("wpk", nargs="?", help="path to a .wpk file")
    ap.add_argument("--out", default="extracted", help="output directory")
    ap.add_argument("--validate", action="store_true", help="render decode-variant montage for one card")
    ap.add_argument("--all", action="store_true", help="extract every card spritesheet in the APK")
    args = ap.parse_args()

    apk_assets = "boss-monster-2-2-6/assets/Content/CardDecks/BaseDeck/Assets"

    if args.all:
        sheets = sorted(f for f in os.listdir(apk_assets) if f.endswith(".wpk") and f.startswith("bma"))
        print(f"Extracting {len(sheets)} spritesheets...")
        for s in sheets:
            path = os.path.join(apk_assets, s)
            try:
                sprites, atlas = parse_wpk(path)
                written = crop_sprites(sprites, atlas, args.out, prefix="card_")
                print(f"  {s}: {len(written)} sprites -> {args.out}")
            except Exception as e:
                print(f"  {s}: FAILED ({e})")
        return

    if not args.wpk:
        ap.error("a wpk file is required (or use --all)")

    if args.validate:
        render_validation(args.wpk, args.out)
        return

    sprites, atlas = parse_wpk(args.wpk)
    written = crop_sprites(sprites, atlas, args.out)
    print(f"Extracted {len(written)} sprites to {args.out}/:")
    for fn in written:
        print(f"  {fn}")


if __name__ == "__main__":
    main()
