#!/usr/bin/env python3
"""Build 2.2.6 cardData.json from APK JSON + wiki HQ art (BMA / BMH / THK / KSA)."""
from __future__ import annotations

import json
import os
import re
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
DECKS = os.path.join(ROOT, "boss-monster-2-2-6", "assets", "Content", "CardDecks")
OUT_JSON = os.path.join(ROOT, "src", "cardData.json")
OUT_CARDS = os.path.join(ROOT, "assets", "cards")
WIKI_API = "https://bossmonster.fandom.com/api.php"
UA = "BossMonsterFanPort/2.2.6 (local educational rebuild)"

ROOM_TYPE = {0: "monster", 1: "trap"}
CLASS_FROM_TREASURE = {0: "The Fool", 1: "Cleric", 2: "Fighter", 3: "Mage", 4: "Thief"}
SETS = {
    "BMA": "base",
    "BMH": "hidden-heroes",
    "THK": "tools",
    "KSA": "players-choice",
    "TNL": "next-level",
    "RMB": "minibosses",
    "CRL": "crash-landing",
}


def slug(name: str) -> str:
    s = (name or "").lower().replace("'", "-").replace("'", "-")
    s = re.sub(r"[^a-z0-9]+", "-", s)
    return s.strip("-") or "card"


def load_deck(folder: str) -> dict:
    path = os.path.join(DECKS, folder, "data.json")
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def set_of(cid: str) -> str:
    prefix = (cid or "")[:3].upper()
    return SETS.get(prefix, "base")


def map_boss(c: dict) -> dict:
    cid = c["CardNumber"]
    return {
        "id": cid,
        "name": c.get("Name") or cid,
        "xp": int(c.get("XP") or 0),
        "treasures": list(c.get("Treasures") or []),
        "advanced": False,
        "levelUpDesc": c.get("Description") or "",
        "subtitle": c.get("Subtitle") or "",
        "set": set_of(cid),
        "quantity": int(c.get("Quantity") or 1),
    }


def map_room(c: dict) -> dict:
    cid = c["CardNumber"]
    return {
        "id": cid,
        "name": c.get("Name") or cid,
        "advanced": bool(c.get("IsAdvanced")),
        "type": ROOM_TYPE.get(int(c.get("RoomType") or 0), "monster"),
        "damage": int(c.get("Damage") or 0),
        "treasures": list(c.get("Treasures") or []),
        "quantity": int(c.get("Quantity") or 1),
        "description": c.get("Description") or "",
        "set": set_of(cid),
    }


def map_spell(c: dict) -> dict:
    cid = c["CardNumber"]
    return {
        "id": cid,
        "name": c.get("Name") or cid,
        "category": int(c.get("SpellCategory") or 1),
        "quantity": int(c.get("Quantity") or 1),
        "description": c.get("Description") or "",
        "set": set_of(cid),
    }


def map_hero(c: dict) -> dict:
    cid = c["CardNumber"]
    treasures = list(c.get("Treasures") or [0])
    treasure = treasures[0] if treasures else 0
    epic = bool(c.get("HasStar")) or int(c.get("Wounds") or 1) >= 2 or int(c.get("HeroType") or 0) == 1
    name = c.get("Name") or cid
    cls = CLASS_FROM_TREASURE.get(treasure, name)
    if name == "The Fool" or treasure == 0:
        cls = "The Fool"
    return {
        "id": cid,
        "name": name,
        "treasure": treasure,
        "hp": int(c.get("Health") or 4),
        "wounds": int(c.get("Wounds") or (2 if epic else 1)),
        "souls": int(c.get("Souls") or (2 if epic else 1)),
        "epic": epic,
        "quantity": int(c.get("Quantity") or 1),
        "description": (c.get("Description") or "").strip(),
        "class": cls,
        "playerCount": int(c.get("MinimumPlayers") or 2),
        "set": set_of(cid),
        "replaces": c.get("ReplacesCardNumber"),
    }


def map_item(c: dict) -> dict:
    cid = c["CardNumber"]
    treasures = list(c.get("Treasures") or [])
    return {
        "id": cid,
        "name": c.get("Name") or cid,
        "subtitle": c.get("Subtitle") or "",
        "treasures": treasures,
        "treasure": treasures[0] if treasures else 0,
        "quantity": int(c.get("Quantity") or 1),
        "description": c.get("Description") or "",
        "set": set_of(cid),
        "isItem": True,
    }


def by_id(cards: list[dict]) -> dict[str, dict]:
    return {c["id"]: c for c in cards}


def merge_heroes(base: list[dict], extras: list[dict]) -> list[dict]:
    """Hidden Heroes replace matching BMA numbers; KSA heroes are added."""
    out = by_id(base)
    for h in extras:
        replaces = h.pop("replaces", None)
        if replaces and replaces in out:
            # Keep the named identity from the replacement card.
            out.pop(replaces, None)
            out[h["id"]] = h
        elif h["id"] not in out:
            out[h["id"]] = h
        else:
            out[h["id"]] = h
    # Drop leftover replaces field on base heroes
    for h in out.values():
        h.pop("replaces", None)
    return sorted(out.values(), key=lambda c: c["id"])


def http_json(url: str) -> dict:
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=30) as res:
        return json.loads(res.read().decode("utf-8"))


def http_bytes(url: str) -> bytes | None:
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    try:
        with urllib.request.urlopen(req, timeout=45) as res:
            return res.read()
    except urllib.error.HTTPError:
        return None
    except urllib.error.URLError:
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
    if section == "items":
        return "items"
    if section == "heroes":
        return "epic-heroes" if card.get("epic") else "heroes"
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
    fnt = set(fn.split("-"))
    hit = len(tokens & fnt)
    if not hit:
        return -1
    return hit * 10


def download_wiki_art(cards_by_section: dict[str, list[dict]], name_map: dict[str, str]) -> int:
    wanted = {}
    for section, cards in cards_by_section.items():
        for c in cards:
            wanted[c["id"].upper()] = (c, section)
            if c["id"].upper().startswith("BMA"):
                wanted["BMR" + c["id"][3:]] = (c, section)

    files = []
    for prefix in ("BMA", "BMR", "BMH", "THK", "KSA", "TNL", "RMB", "CRL"):
        print(f"  wiki allimages {prefix}*")
        files.extend(wiki_allimages(prefix))
        time.sleep(0.2)

    candidates: dict[str, list[tuple[int, dict]]] = {}
    for info in files:
        title = info.get("name") or info.get("title") or ""
        m = re.match(r"(BMA|BMR|BMH|THK|KSA)(\d{3})", title.upper())
        if not m:
            continue
        key = m.group(1) + m.group(2)
        if key not in wanted:
            continue
        card, _section = wanted[key]
        cid = card["id"].upper()
        score = _name_score(title, card)
        if score < 0:
            continue
        candidates.setdefault(cid, []).append((score, info))

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

    # Direct FilePath guesses for cards the prefix listing missed (heroes, BMH).
    for section, cards in cards_by_section.items():
        for card in cards:
            cid = card["id"].upper()
            dest = os.path.join(OUT_CARDS, kind_dir(card, section), f"{cid}_{name_map.get(cid, slug(card['name']))}.webp")
            if os.path.exists(dest):
                continue
            guesses = [
                f"{cid}.jpg", f"{cid}.png",
                f"{cid}_{card['name'].replace(' ', '_')}.jpg",
                f"{cid}_{card['name'].replace(' ', '_')}.png",
            ]
            if cid.startswith("BMA"):
                guesses += [f"BMR{cid[3:]}.jpg", f"BMR{cid[3:]}.png"]
            for guess in guesses:
                url = f"https://bossmonster.fandom.com/wiki/Special:FilePath/{urllib.parse.quote(guess)}"
                raw = http_bytes(url)
                if raw and raw[:15] != b"<!DOCTYPE html" and len(raw) > 4000:
                    if save_webp(raw, dest):
                        saved += 1
                        print(f"    {cid} <- {guess}")
                        break
            time.sleep(0.05)
    return saved


def copy_wiki_backs():
    """Keep APK backs as wiki-path fallbacks so getWikiCardImage always resolves."""
    backs = os.path.join(OUT_CARDS, "backs")
    os.makedirs(backs, exist_ok=True)
    apk = os.path.join(ROOT, "assets", "apk_cards")
    mapping = {
        "back_room.webp": os.path.join(apk, "base", "back_room.webp"),
        "back_boss.webp": os.path.join(apk, "base", "back_boss.webp"),
        "back_spell.webp": os.path.join(apk, "base", "back_spell.webp"),
        "back_ordinary_hero.webp": os.path.join(apk, "base", "back_ordinary_hero.webp"),
        "back_epic_hero.webp": os.path.join(apk, "base", "back_epic_hero.webp"),
        "back_item.webp": os.path.join(apk, "tools", "back_item.webp"),
    }
    for dest_name, src in mapping.items():
        dest = os.path.join(backs, dest_name)
        if os.path.exists(dest):
            continue
        if os.path.exists(src):
            im = Image.open(src).convert("RGBA")
            im.save(dest, "WEBP", quality=90, method=4)


def main():
    if not os.path.isdir(DECKS):
        print("Missing unpacked APK decks at", DECKS, file=sys.stderr)
        sys.exit(1)

    base = load_deck("BaseDeck")
    hh = load_deck("HiddenHeros")
    thk = load_deck("ToolsHeroKind")
    ksa = load_deck("PlayerChoice")

    bosses = [map_boss(c) for c in base.get("BossCards", [])]
    bosses += [map_boss(c) for c in ksa.get("BossCards", [])]

    rooms = [map_room(c) for c in base.get("RoomCards", [])]
    rooms += [map_room(c) for c in thk.get("RoomCards", [])]
    rooms += [map_room(c) for c in ksa.get("RoomCards", [])]

    spells = [map_spell(c) for c in base.get("SpellCards", [])]
    spells += [map_spell(c) for c in thk.get("SpellCards", [])]
    spells += [map_spell(c) for c in ksa.get("SpellCards", [])]

    heroes = merge_heroes(
        [map_hero(c) for c in base.get("HeroCards", [])],
        [map_hero(c) for c in hh.get("HeroCards", [])] + [map_hero(c) for c in ksa.get("HeroCards", [])],
    )

    items = [map_item(c) for c in thk.get("ItemCards", [])]

    name_map = {c["id"]: slug(c["name"]) for c in bosses + rooms + spells + heroes + items}

    payload = {
        "bosses": bosses,
        "rooms": rooms,
        "spells": spells,
        "heroes": heroes,
        "items": items,
        "nameMap": name_map,
    }
    os.makedirs(os.path.dirname(OUT_JSON), exist_ok=True)
    with open(OUT_JSON, "w", encoding="utf-8") as f:
        json.dump(payload, f, indent=2, ensure_ascii=False)
        f.write("\n")
    print(
        f"wrote {OUT_JSON}: "
        f"{len(bosses)} bosses, {len(rooms)} rooms, {len(spells)} spells, "
        f"{len(heroes)} heroes, {len(items)} items"
    )

    copy_wiki_backs()
    saved = download_wiki_art(
        {
            "bosses": bosses,
            "rooms": rooms,
            "spells": spells,
            "heroes": heroes,
            "items": items,
        },
        name_map,
    )
    print(f"wiki art saved: {saved}")


if __name__ == "__main__":
    main()
