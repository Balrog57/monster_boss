#!/usr/bin/env python3
"""Download wiki card art for expansion packs (TNL / RMB / CRL) only."""
from __future__ import annotations

import json
import os
import re
import shutil
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from io import BytesIO

try:
    from PIL import Image
except ImportError:
    print("Pillow is required: pip install pillow", file=sys.stderr)
    sys.exit(1)

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CARD_DATA = os.path.join(ROOT, "src", "cardData.json")
OUT_CARDS = os.path.join(ROOT, "assets", "cards")
WIKI_API = "https://bossmonster.fandom.com/api.php"
UA = "BossMonsterFanPort/expansion-art"
EXP_PREFIXES = ("TNL", "RMB", "CRL")
SKIP_IMAGES = {
    "boss_monster_clerics.png",
    "boss_monster_fighters.png",
    "boss_monster_mages.png",
    "boss_monster_thieves.png",
    "bossinstructions.jpg",
    "boss_deck_back.jpg",
}


def slug(name: str) -> str:
    s = (name or "").lower().replace("'", "-")
    s = re.sub(r"[^a-z0-9]+", "-", s)
    return s.strip("-") or "card"


def http_json(url: str) -> dict:
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=60) as res:
        return json.loads(res.read().decode("utf-8"))


def http_bytes(url: str) -> bytes | None:
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    try:
        with urllib.request.urlopen(req, timeout=45) as res:
            return res.read()
    except (urllib.error.HTTPError, urllib.error.URLError):
        return None


def wiki_allimages(prefix: str) -> list[dict]:
    out = []
    cont = None
    while True:
        params = {
            "action": "query",
            "list": "allimages",
            "aiprefix": prefix,
            "ailimit": "500",
            "aisort": "name",
            "format": "json",
        }
        if cont:
            params["aicontinue"] = cont
        data = http_json(WIKI_API + "?" + urllib.parse.urlencode(params))
        out.extend(data.get("query", {}).get("allimages", []))
        cont = data.get("continue", {}).get("aicontinue")
        if not cont:
            break
        time.sleep(0.15)
    return out


def kind_dir(card: dict, section: str) -> str:
    if section == "bosses":
        return "bosses"
    if section == "rooms":
        return "rooms"
    if section == "spells":
        return "spells"
    if section == "heroes":
        return "epic-heroes" if card.get("epic") else "heroes"
    if section == "minibosses":
        return "minibosses"
    return section


def save_webp(raw: bytes, dest: str) -> bool:
    try:
        im = Image.open(BytesIO(raw)).convert("RGBA")
    except Exception:
        return False
    os.makedirs(os.path.dirname(dest), exist_ok=True)
    im.save(dest, "WEBP", quality=90, method=4)
    return True


def _name_score(filename: str, card: dict) -> int:
    fn = slug(filename)
    name = slug(card.get("name") or "")
    if not name:
        return 0
    if "tbd" in fn:
        return -50
    if name in fn:
        return 100
    tokens = {t for t in name.split("-") if len(t) > 2}
    hit = len(tokens & set(fn.split("-")))
    return hit * 10 if hit else -1


def load_expansion_cards() -> tuple[dict[str, list[dict]], dict[str, str]]:
    with open(CARD_DATA, encoding="utf-8") as f:
        data = json.load(f)
    name_map = data.get("nameMap", {})
    by_section: dict[str, list[dict]] = {}
    for section in ("bosses", "rooms", "spells", "heroes", "minibosses"):
        cards = [
            c for c in data.get(section, [])
            if (c.get("id") or "").upper().startswith(EXP_PREFIXES)
        ]
        if cards:
            by_section[section] = cards
    return by_section, name_map


def wiki_search_title(query: str) -> str | None:
    params = {
        "action": "query",
        "list": "search",
        "srsearch": query,
        "srlimit": "5",
        "format": "json",
    }
    try:
        data = http_json(WIKI_API + "?" + urllib.parse.urlencode(params))
        for hit in data.get("query", {}).get("search", []):
            title = hit.get("title") or ""
            if slug(title) == slug(query) or slug(query) in slug(title):
                return title.replace(" ", "_")
    except Exception:
        return None
    return None


def build_name_art_index() -> dict[str, str]:
    with open(CARD_DATA, encoding="utf-8") as f:
        data = json.load(f)
    name_map = data.get("nameMap", {})
    index: dict[str, str] = {}
    for section in ("bosses", "rooms", "spells", "heroes", "minibosses"):
        for card in data.get(section, []):
            cid = (card.get("id") or "").upper()
            if cid.startswith(EXP_PREFIXES):
                continue
            mapped = name_map.get(cid, slug(card.get("name") or ""))
            dest = os.path.join(OUT_CARDS, kind_dir(card, section), f"{cid}_{mapped}.webp")
            if os.path.exists(dest):
                index[slug(card.get("name") or "")] = dest
    return index


def copy_art_by_name(card: dict, dest: str, index: dict[str, str]) -> bool:
    """Reuse an existing card image when expansion reprints share art/name."""
    key = slug(card.get("name") or "")
    if not key:
        return False
    src = index.get(key)
    if not src:
        for root, _dirs, files in os.walk(OUT_CARDS):
            for fn in files:
                if not fn.endswith(".webp"):
                    continue
                if fn.startswith(EXP_PREFIXES):
                    continue
                if key in slug(fn):
                    src = os.path.join(root, fn)
                    break
            if src:
                break
    if not src:
        return False
    os.makedirs(os.path.dirname(dest), exist_ok=True)
    shutil.copy2(src, dest)
    return True


def wiki_page_titles(card: dict) -> list[str]:
    titles = []
    for key in ("name", "subtitle"):
        val = (card.get(key) or "").strip()
        if val:
            titles.append(val.replace(" ", "_"))
            titles.append(val.replace("'", "%27").replace(" ", "_"))
    found = wiki_search_title(card.get("name") or "")
    if found and found not in titles:
        titles.append(found)
    return titles


def pick_card_image(images: list[str], card: dict) -> str | None:
    name_key = slug(card.get("name") or "")
    best = None
    best_score = -1
    for img in images:
        base = img.rsplit("/", 1)[-1].lower()
        if base in SKIP_IMAGES:
            continue
        if "deck_back" in base or "instructions" in base:
            continue
        score = _name_score(base, card)
        if score > best_score:
            best_score = score
            best = img
    if best_score < 0:
        for img in images:
            base = img.rsplit("/", 1)[-1].lower()
            if base in SKIP_IMAGES:
                continue
            if any(p.lower() in base for p in EXP_PREFIXES):
                return img
        return None
    return best


def image_url_from_file(filename: str) -> str | None:
    title = "File:" + filename.replace(" ", "_")
    params = {
        "action": "query",
        "titles": title,
        "prop": "imageinfo",
        "iiprop": "url",
        "format": "json",
    }
    try:
        data = http_json(WIKI_API + "?" + urllib.parse.urlencode(params))
        pages = data.get("query", {}).get("pages", {})
        for page in pages.values():
            info = (page.get("imageinfo") or [{}])[0]
            url = info.get("url")
            if url:
                return url
    except Exception:
        return None
    return None


def fetch_wiki_page_image(card: dict) -> tuple[str, str] | None:
    """Return (url, source_label) from the card's wiki page."""
    for title in wiki_page_titles(card):
        params = {
            "action": "parse",
            "page": title,
            "prop": "text|images",
            "format": "json",
        }
        try:
            data = http_json(WIKI_API + "?" + urllib.parse.urlencode(params))
            parsed = data.get("parse")
            if not parsed:
                continue
            html = parsed.get("text", {}).get("*", "")
            urls = re.findall(
                r"https://static\.wikia\.nocookie\.net/bossmonster/images/[^\"'\s]+",
                html,
            )
            urls = [u.split("/revision/")[0] for u in urls]
            pick = pick_card_image(urls, card)
            if pick:
                return pick, f"page:{title}"
            images = parsed.get("images") or []
            for img in images:
                if img.lower() in SKIP_IMAGES:
                    continue
                url = image_url_from_file(img)
                if url and _name_score(img, card) >= 0:
                    return url.split("/revision/")[0], f"file:{img}"
        except Exception:
            continue
        time.sleep(0.12)
    return None


def download_expansion_art() -> int:
    cards_by_section, name_map = load_expansion_cards()
    wanted: dict[str, tuple[dict, str]] = {}
    for section, cards in cards_by_section.items():
        for c in cards:
            wanted[c["id"].upper()] = (c, section)

    files: list[dict] = []
    for prefix in EXP_PREFIXES:
        print(f"  wiki allimages {prefix}*")
        files.extend(wiki_allimages(prefix))
        time.sleep(0.2)

    candidates: dict[str, list[tuple[int, dict]]] = {}
    for info in files:
        title = info.get("name") or info.get("title") or ""
        m = re.match(r"(TNL|RMB|CRL)(\d{3})", title.upper())
        if not m:
            continue
        key = m.group(1) + m.group(2)
        if key not in wanted:
            continue
        card, _section = wanted[key]
        score = _name_score(title, card)
        if score < 0:
            continue
        candidates.setdefault(key, []).append((score, info))

    saved = 0
    for cid, opts in candidates.items():
        opts.sort(key=lambda x: (-x[0], len(x[1].get("name") or "")))
        score, info = opts[0]
        card, section = wanted[cid]
        url = info.get("url")
        if not url:
            continue
        raw = http_bytes(url)
        if not raw:
            continue
        mapped = name_map.get(cid, slug(card["name"]))
        dest = os.path.join(OUT_CARDS, kind_dir(card, section), f"{cid}_{mapped}.webp")
        if save_webp(raw, dest):
            saved += 1
            print(f"    {cid} ({score}) <- {info.get('name')}")
        time.sleep(0.05)

    missing: list[tuple[dict, str]] = []
    name_index = build_name_art_index()
    for section, cards in cards_by_section.items():
        for card in cards:
            cid = card["id"].upper()
            mapped = name_map.get(cid, slug(card["name"]))
            dest = os.path.join(OUT_CARDS, kind_dir(card, section), f"{cid}_{mapped}.webp")
            if os.path.exists(dest):
                continue
            missing.append((card, section))

    print(f"  {len(missing)} cards still missing — fetching wiki pages…")
    for i, (card, section) in enumerate(missing, 1):
        cid = card["id"].upper()
        mapped = name_map.get(cid, slug(card["name"]))
        dest = os.path.join(OUT_CARDS, kind_dir(card, section), f"{cid}_{mapped}.webp")

        got = fetch_wiki_page_image(card)
        if got:
            url, label = got
            raw = http_bytes(url)
            if raw and save_webp(raw, dest):
                saved += 1
                print(f"    {cid} <- {label}")
                time.sleep(0.08)
                continue

        if copy_art_by_name(card, dest, name_index):
            saved += 1
            print(f"    {cid} <- reuse:{card['name']}")
            continue

        guesses = [
            f"{cid}.jpg",
            f"{cid}.png",
            f"{cid}_{card['name'].replace(' ', '_')}.jpg",
            f"{cid}_{card['name'].replace(' ', '_')}.png",
            f"{card['name'].replace(' ', '_')}.png",
            f"{card['name'].replace(' ', '_')}.jpg",
        ]
        if card.get("subtitle"):
            guesses += [
                f"{card['subtitle'].replace(' ', '_')}.png",
                f"{card['subtitle'].replace(' ', '_')}.jpg",
            ]
        for guess in guesses:
            url = (
                "https://bossmonster.fandom.com/wiki/Special:FilePath/"
                + urllib.parse.quote(guess)
            )
            raw = http_bytes(url)
            if raw and raw[:15] != b"<!DOCTYPE html" and len(raw) > 4000:
                if save_webp(raw, dest):
                    saved += 1
                    print(f"    {cid} <- {guess}")
                    break
            time.sleep(0.05)

        if i % 25 == 0:
            print(f"  … {i}/{len(missing)} page lookups")
    return saved


def main():
    saved = download_expansion_art()
    print(f"saved {saved} expansion card images under {OUT_CARDS}")


if __name__ == "__main__":
    main()
