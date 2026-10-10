#!/usr/bin/env python3
"""Generate honest placeholder faces for expansion cards with no official art.

Context: the 107 Rise of the Minibosses + 1 Boss Monster 2 cards have no art
on the wiki, are absent from the APK, are blocked on BoardGameGeek (403) and
are excluded from the DriveThru art pack licence. Instead of showing a card
back in-game, we generate a clearly-labelled stand-in face so the card is
readable (name, stats, rules text). Each face carries a "MISSING ART" ribbon
so nobody mistakes it for official art. Re-running the script replaces those
files 1:1 when real art becomes available under `assets/cards/`.

Usage: python tools/generate_placeholder_art.py [--force]
"""
from __future__ import annotations

import json
import os
import sys

try:
    from PIL import Image, ImageDraw, ImageFont
except ImportError:
    print("Pillow is required: pip install pillow", file=sys.stderr)
    sys.exit(1)

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CARD_DATA = os.path.join(ROOT, "src", "backend", "game", "cardData.json")
MANIFEST = os.path.join(ROOT, "src", "backend", "game", "apkCardManifest.json")
OUT_CARDS = os.path.join(ROOT, "src", "frontend", "assets", "cards")
FONT_DIR = os.path.join(ROOT, "src", "frontend", "assets", "fonts")

W, H = 746, 1039  # matches official faces
PLACEHOLDER_SETS = ("minibosses", "next-level")

SET_LABEL = {
    "minibosses": "RISE OF THE MINIBOSSES",
    "next-level": "BOSS MONSTER 2",
}

# section -> (background, frame, accent, label)
THEME = {
    "bosses": ((26, 8, 10), (122, 31, 31), (255, 170, 80), "BOSS"),
    "rooms": ((16, 10, 32), (74, 44, 107), (196, 160, 255), "ROOM"),
    "spells": ((8, 22, 30), (23, 92, 110), (140, 230, 255), "SPELL"),
    "heroes": ((10, 28, 14), (38, 110, 52), (170, 240, 170), "HERO"),
    "minibosses": ((30, 22, 6), (122, 90, 26), (255, 215, 130), "MINIBOSS"),
    "items": ((28, 20, 8), (110, 80, 30), (255, 220, 150), "ITEM"),
}

TREASURE = {1: "Cleric", 2: "Fighter", 3: "Mage", 4: "Thief", 5: "Explorer"}


def load_font(name: str, size: int):
    return ImageFont.truetype(os.path.join(FONT_DIR, name), size)


def section_dir(section: str, card: dict) -> str:
    if section == "bosses":
        return "bosses"
    if section == "rooms":
        return "rooms"
    if section == "spells":
        return "spells"
    if section == "items":
        return "items"
    if section == "minibosses":
        return "minibosses"
    if card.get("epic"):
        return "epic-heroes"
    return "heroes"


def stats_line(section: str, card: dict) -> str:
    if section == "rooms":
        tr = "+".join(TREASURE.get(t, str(t)) for t in card.get("treasures", []))
        adv = "ADVANCED " if card.get("advanced") else ""
        return f"{adv}{card.get('type', '?').upper()}  DMG {card.get('damage', '?')}  TREASURE {tr}"
    if section == "bosses":
        tr = "+".join(TREASURE.get(t, str(t)) for t in card.get("treasures", []))
        sub = f"  {card.get('subtitle', '').upper()}" if card.get("subtitle") else ""
        return f"XP {card.get('xp', '?')}  TREASURE {tr}{sub}"
    if section == "spells":
        return f"SPELL  x{card.get('quantity', '?')}"
    if section == "heroes":
        epic = "EPIC " if card.get("epic") else ""
        dark = "DARK " if card.get("dark") else ""
        tr = TREASURE.get(card.get("treasure"), str(card.get("treasure")))
        return (
            f"{epic}{dark}{card.get('class', '?').upper()}  "
            f"HP {card.get('hp', '?')}  TREASURE {tr}  "
            f"WOUNDS {card.get('wounds', '?')}  SOULS {card.get('souls', '?')}"
        )
    if section == "minibosses":
        lvls = card.get("levels", [])
        return f"{len(lvls)} LEVELS" if lvls else "MINIBOSS"
    return ""


def body_text(section: str, card: dict) -> str:
    if section == "minibosses":
        parts = []
        for i, lvl in enumerate(card.get("levels", []), 1):
            name = (lvl.get("name") or "").strip()
            desc = (lvl.get("description") or "").strip()
            head = f"Lv{i}" + (f" {name}" if name else "")
            parts.append(f"{head}: {desc}" if desc else head)
        return "\n\n".join(parts)
    return (card.get("description") or card.get("levelUpDesc") or "").strip()


def draw_centered(draw: ImageDraw.ImageDraw, cx: int, y: int, text: str,
                 font: ImageFont.FreeTypeFont, fill) -> int:
    bbox = draw.textbbox((0, 0), text, font=font)
    draw.text((cx - (bbox[2] - bbox[0]) / 2 - bbox[0], y), text, font=font, fill=fill)
    return y + (bbox[3] - bbox[1])


def wrap(draw: ImageDraw.ImageDraw, text: str, font, max_w: int) -> list[str]:
    lines: list[str] = []
    for para in text.split("\n"):
        if not para.strip():
            lines.append("")
            continue
        words, cur = para.split(), ""
        for wd in words:
            trial = (cur + " " + wd).strip()
            if draw.textlength(trial, font=font) <= max_w:
                cur = trial
            else:
                if cur:
                    lines.append(cur)
                cur = wd
        if cur:
            lines.append(cur)
    return lines


def render(section: str, card: dict) -> Image.Image:
    bg, frame, accent, label = THEME[section]
    img = Image.new("RGB", (W, H), bg)
    d = ImageDraw.Draw(img)
    # frame
    d.rectangle([0, 0, W - 1, H - 1], outline=accent, width=10)
    d.rectangle([24, 24, W - 25, H - 25], outline=frame, width=6)
    # pixel-dot texture
    for yy in range(60, H - 60, 46):
        for xx in range(60, W - 60, 46):
            if (xx + yy) % 92 == 0:
                d.rectangle([xx, yy, xx + 5, yy + 5], fill=frame)

    title_f = load_font("arcadepix.TTF", 52)
    sub_f = load_font("arcadepix.TTF", 30)
    body_f = load_font("bookman_old_style.TTF", 30)
    small_f = load_font("arcadepix.TTF", 24)

    y = 70
    y = draw_centered(d, W // 2, y, label, sub_f, accent) + 18
    name = card.get("name", card.get("id", "?")).upper()
    # shrink title until it fits (max 2 lines)
    size = 52
    while size > 30:
        f = load_font("arcadepix.TTF", size)
        if d.textlength(name, font=f) <= W - 140:
            break
        size -= 4
    title_f = load_font("arcadepix.TTF", size)
    if d.textlength(name, font=title_f) > W - 140:
        words = name.split()
        l1, l2 = " ".join(words[: len(words) // 2]), " ".join(words[len(words) // 2 :])
        y = draw_centered(d, W // 2, y, l1, title_f, (255, 255, 255)) + 8
        y = draw_centered(d, W // 2, y, l2, title_f, (255, 255, 255)) + 8
    else:
        y = draw_centered(d, W // 2, y, name, title_f, (255, 255, 255)) + 8
    y = draw_centered(d, W // 2, y + 6, card.get("id", ""), small_f, accent) + 24

    # divider
    d.rectangle([70, y, W - 70, y + 4], fill=accent)
    y += 26
    stats = stats_line(section, card)
    if stats:
        for ln in wrap(d, stats, sub_f, W - 180):
            y = draw_centered(d, W // 2, y, ln, sub_f, (255, 255, 255)) + 8
        y += 12
        d.rectangle([70, y, W - 70, y + 4], fill=accent)
        y += 26

    body = body_text(section, card)
    if body:
        for ln in wrap(d, body, body_f, W - 180)[:16]:
            if ln == "":
                y += 14
                continue
            y = draw_centered(d, W // 2, y, ln, body_f, (240, 235, 220)) + 10

    # missing-art ribbon
    ribbon_h, pad = 64, 46
    d.rectangle([pad, H - pad - ribbon_h, W - pad, H - pad], fill=(150, 20, 20))
    d.rectangle([pad, H - pad - ribbon_h, W - pad, H - pad], outline=(255, 220, 120), width=3)
    draw_centered(d, W // 2, H - pad - ribbon_h + 14, "MISSING ART - PLACEHOLDER",
                  small_f, (255, 240, 200))
    set_label = SET_LABEL.get(card.get("set", ""), "")
    if set_label:
        draw_centered(d, W // 2, 34, set_label, small_f, accent)
    return img


def main() -> int:
    force = "--force" in sys.argv
    with open(CARD_DATA, encoding="utf-8") as fh:
        data = json.load(fh)
    name_map = data.get("nameMap", {})
    try:
        with open(MANIFEST, encoding="utf-8") as fh:
            apk_faces = (json.load(fh).get("faces", {}))
    except FileNotFoundError:
        apk_faces = {}

    made, skipped = 0, 0
    for section in ("bosses", "rooms", "spells", "heroes", "items", "minibosses"):
        for card in data.get(section, []):
            if card.get("set") not in PLACEHOLDER_SETS:
                continue
            cid = card["id"]
            stem = cid.lower()
            if stem in apk_faces or (stem + "a") in apk_faces:
                skipped += 1
                continue
            slug = name_map.get(cid, cid.lower())
            out = os.path.join(OUT_CARDS, section_dir(section, card), f"{cid}_{slug}.webp")
            if os.path.exists(out) and not force:
                skipped += 1
                continue
            os.makedirs(os.path.dirname(out), exist_ok=True)
            render(section, card).save(out, "WEBP", quality=82, method=6)
            made += 1
    print(f"[placeholder-art] generated={made} skipped={skipped}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
