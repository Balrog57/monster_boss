#!/usr/bin/env python3
"""Parse Boss Monster wiki List_of_Cards into assets/data/expansions/*.json."""
from __future__ import annotations

import json
import os
import re
import urllib.parse
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
EXP_DIR = os.path.join(ROOT, "assets", "data", "expansions")
WIKI_API = "https://bossmonster.fandom.com/api.php"
UA = "BossMonsterFanPort/expansion-fetch"

PREFIX_TO_PACK = {"TNL": "next-level", "RMB": "minibosses", "CRL": "crash-landing"}
TREASURE = {"Cleric": 1, "Fighter": 2, "Mage": 3, "Thief": 4, "Explorer": 5}
SPELL_PHASE = {"Build": 1, "Adventure": 2, "Both": 3}


def wiki_wikitext(page: str) -> str:
    q = urllib.parse.urlencode(
        {"action": "parse", "page": page, "prop": "wikitext", "format": "json"}
    )
    req = urllib.request.Request(f"{WIKI_API}?{q}", headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=60) as res:
        return json.loads(res.read().decode("utf-8"))["parse"]["wikitext"]["*"]


def clean_cell(raw: str) -> str:
    s = raw.strip()
    s = re.sub(r"<[^>]+>", "", s)
    s = s.replace("'''", "").replace("''", "")
    m = re.search(r"\[\[(?:[^|\]]*\|)?([^\]]+)\]\]", s)
    if m:
        return m.group(1).strip()
    s = re.sub(r"^\[+|\]+$", "", s)
    return s.strip()


def parse_treasures(text: str) -> list[int]:
    if not text or text in ("-", "–"):
        return []
    if "Universal" in text:
        return [1, 2, 3, 4]
    out = []
    for part in re.split(r"[/+&]", text):
        part = part.strip()
        for name, num in TREASURE.items():
            if name.lower() in part.lower():
                out.append(num)
    return out or [1]


def split_rows(text: str) -> list[str]:
    return re.split(r"\n\s*\|-\s*\n", text)


def split_table_row(row: str) -> list[str]:
    """Split wiki table row on || or newline+| without breaking [[Link|Label]]."""
    row = row.strip()
    if row.startswith("|"):
        row = row[1:]
    cells: list[str] = []
    buf: list[str] = []
    i = 0
    in_link = 0
    while i < len(row):
        if row.startswith("[[", i):
            in_link += 1
            buf.append("[")
            i += 2
            continue
        if row.startswith("]]", i) and in_link > 0:
            in_link -= 1
            buf.append("]")
            i += 2
            continue
        if row.startswith("||", i) and in_link == 0:
            cells.append("".join(buf))
            buf = []
            i += 2
            continue
        if row[i] == "\n" and in_link == 0:
            j = i + 1
            while j < len(row) and row[j] in " \t":
                j += 1
            if j < len(row) and row[j] == "|":
                cells.append("".join(buf))
                buf = []
                i = j + 1
                continue
        buf.append(row[i])
        i += 1
    if buf:
        cells.append("".join(buf))
    return cells


def row_cells(row: str) -> list[str]:
    return [clean_cell(c) for c in split_table_row(row) if c.strip()]


def card_id(cells: list[str]) -> str | None:
    for c in cells:
        if re.fullmatch(r"(?:TNL|RMB|CRL)\d{3}", c):
            return c
    return None


def map_boss(cid: str, cells: list[str], row: str = "") -> dict:
    # ID, name, subtitle, xp, treasure, Boss, levelUp, -, qty
    name = cells[1] if len(cells) > 1 else cid
    xp = int(re.search(r"\d+", cells[3]).group()) if len(cells) > 3 and re.search(r"\d+", cells[3]) else 500
    treasures = parse_treasures(cells[4]) if len(cells) > 4 else [1]
    level = ""
    for c in cells:
        if "level up" in c.lower():
            level = re.sub(r"^.*?level up:?\s*", "", c, flags=re.I).strip()
            break
    if not level:
        m = re.search(r"Level Up:?\s*(.+?)(?:\|\||\n|$)", row, re.I | re.S)
        if m:
            level = clean_cell(m.group(1))
    qty = int(cells[-1]) if cells[-1].isdigit() else 1
    card = {
        "id": cid,
        "name": name,
        "xp": xp,
        "treasures": treasures[:1] or [1],
        "levelUpDesc": level,
        "set": PREFIX_TO_PACK[cid[:3]],
        "quantity": qty,
    }
    tag_boss(card)
    return card


def count_coins(text: str) -> int:
    if not text:
        return 0
    d = text.lower()
    m = re.search(r"gain (\d+) coins?", d)
    if m:
        return int(m.group(1))
    icons = len(re.findall(r"\(c\)", text, re.I))
    if icons:
        return icons
    if re.search(r"gain (a |one |1 )coin", d):
        return 1
    if "two coins" in d or "2 coins" in d:
        return 2
    return 0


def tag_room(card: dict) -> None:
    d = (card.get("description") or "").lower()
    if not d:
        return
    coins = count_coins(card.get("description", ""))
    if coins and re.search(r"when you build", d):
        card["gainCoin"] = coins
    if "when you build" in d and "draw a room" in d:
        card["onBuildDrawRoom"] = True
    if "when you build" in d and "draw a spell" in d:
        card["onBuildDrawSpell"] = True
    if "when you build or uncover" in d and "draw a room" in d:
        card["onBuildDrawRoom"] = True
        card["onUncover"] = "draw-room"
    elif "when uncovered" in d and "draw a room" in d:
        card["onUncover"] = "draw-room"
    if "when a hero dies" in d and "draw a spell" in d:
        card["onHeroDieDrawSpell"] = True
    if "when a hero dies" in d and "draw a room" in d:
        card["onHeroDieDrawRoom"] = True
    if "when a hero dies" in d and "heal a wound" in d:
        card["onHeroDieHealWound"] = True
    if "destroy this room" in d:
        if "hero dies" in d:
            card["destroyOnHeroDie"] = True
        if "survives" in d or "survive" in d:
            card["destroyOnHeroSurvive"] = True
    if "build an additional room" in d or "additional room this turn" in d:
        card["onBuildExtraBuild"] = True
    if "heal a wound" in d and "when you build" in d:
        card["onBuildHealWound"] = True


def tag_spell(card: dict) -> None:
    d = (card.get("description") or "").lower()
    if not d:
        return
    if count_coins(card.get("description", "")) and "gain" in d:
        card["genericSpell"] = True
    if "draw a spell" in d or "draw two spell" in d:
        card["genericSpell"] = True
    if "draw a room" in d or "draw two room" in d:
        card["genericSpell"] = True
    if "heal a wound" in d:
        card["genericSpell"] = True


def tag_boss(card: dict) -> None:
    d = (card.get("levelUpDesc") or "").lower()
    if not d:
        return
    if any(k in d for k in ("draw a spell", "draw two spell", "draw a room", "draw two room",
                            "heal a wound", "+1 soul", "double treasure", "last room")):
        card["genericLevelUp"] = True


def map_room(cid: str, cells: list[str], row: str = "") -> dict:
    name = cells[1] if len(cells) > 1 else cid
    subtype = cells[2] if len(cells) > 2 else "Monster Room"
    dmg = int(re.search(r"\d+", cells[3]).group()) if len(cells) > 3 and re.search(r"\d+", cells[3]) else 1
    treasures = parse_treasures(cells[4]) if len(cells) > 4 else [1]
    desc = ""
    for c in cells:
        if c in (cid, name, subtype) or re.fullmatch(r"\d+", c):
            continue
        if "room" in c.lower() and len(c) < 12:
            continue
        if c in ("-", "–") or c.isdigit():
            continue
        if len(c) > len(desc):
            desc = c
    qty = int(cells[-1]) if cells and cells[-1].isdigit() else 1
    advanced = "Advanced" in subtype
    rtype = "trap" if "Trap" in subtype else "monster"
    card = {
        "id": cid,
        "name": name,
        "advanced": advanced,
        "type": rtype,
        "damage": dmg,
        "treasures": treasures,
        "quantity": qty,
        "description": desc,
        "set": PREFIX_TO_PACK[cid[:3]],
    }
    tag_room(card)
    return card


def map_spell(cid: str, cells: list[str], row: str = "") -> dict:
    name = cells[1] if len(cells) > 1 else cid
    phase_raw = next((c for c in cells if c in SPELL_PHASE), cells[3] if len(cells) > 3 else "Build")
    phase = SPELL_PHASE.get(phase_raw, 1)
    desc = ""
    for c in cells:
        if c in (cid, name, phase_raw) or c in SPELL_PHASE:
            continue
        if "spell" in c.lower() and len(c) < 12:
            continue
        if c in ("-", "–") or c.isdigit():
            continue
        if len(c) > len(desc):
            desc = c
    qty = int(cells[-1]) if cells and cells[-1].isdigit() else 1
    card = {
        "id": cid,
        "name": name,
        "category": phase,
        "quantity": qty,
        "description": desc,
        "set": PREFIX_TO_PACK[cid[:3]],
    }
    tag_spell(card)
    return card


def map_hero(cid: str, cells: list[str]) -> dict:
    # treasure label, subtype, hp?, treasure, Hero, name block, hp, qty
    subtype = next((c for c in cells if "Hero" in c), "Ordinary Hero")
    treasure_label = cells[0] if cells and cells[0] not in (cid,) else (cells[4] if len(cells) > 4 else "Fighter")
    treasures = parse_treasures(treasure_label)
    if len(cells) > 4 and "/" in cells[4]:
        treasures = parse_treasures(cells[4])
    epic = "Epic" in subtype
    dark = "Dark" in subtype
    hybrid = "Hybrid" in subtype
    hp = 5
    for c in cells:
        if c.isdigit() and int(c) >= 3:
            hp = int(c)
            break
    name = cid
    for c in cells:
        if c not in (cid,) and "Hero" not in c and not c.isdigit() and len(c) > 2 and c not in TREASURE:
            if not re.fullmatch(r"(?:TNL|RMB|CRL)\d{3}", c):
                name = c.split(".")[0].strip()
                break
    qty = int(cells[-1]) if cells[-1].isdigit() else 1
    card = {
        "id": cid,
        "name": name,
        "treasure": treasures[0] if treasures else 1,
        "hp": hp,
        "wounds": 2 if epic else 1,
        "souls": 2 if epic else 1,
        "epic": epic,
        "class": treasure_label.split("/")[0].strip() if "/" not in treasure_label else list(TREASURE.keys())[treasures[0] - 1],
        "set": PREFIX_TO_PACK[cid[:3]],
        "quantity": qty,
    }
    if len(treasures) > 1:
        card["treasures"] = treasures
        card["hybrid"] = True
    if dark:
        card["dark"] = True
    if hybrid:
        card["hybrid"] = True
    return card


def classify_and_map(cid: str, cells: list[str], row: str) -> tuple[str, dict] | None:
    blob = " | ".join(cells)
    if re.search(r"\[\[Bosses\|Boss\]\]", row):
        return "bosses", map_boss(cid, cells, row)
    if "Spell" in blob:
        return "spells", map_spell(cid, cells, row)
    if "Room" in blob:
        return "rooms", map_room(cid, cells, row)
    if "Hero" in blob or "hero" in blob.lower():
        return "heroes", map_hero(cid, cells)
    if "Miniboss" in blob:
        return "minibosses", {
            "id": cid,
            "name": cells[1] if len(cells) > 1 else cid,
            "quantity": int(cells[-1]) if cells[-1].isdigit() else 1,
            "set": PREFIX_TO_PACK[cid[:3]],
            "levels": [{"level": 1, "description": cells[6] if len(cells) > 6 else ""}],
        }
    return None


def parse_pack(prefix: str, text: str) -> dict:
    out: dict[str, list] = {
        "bosses": [],
        "rooms": [],
        "spells": [],
        "heroes": [],
        "minibosses": [],
    }
    seen = set()
    for row in split_rows(text):
        if prefix not in row:
            continue
        cells = row_cells(row)
        cid = card_id(cells)
        if not cid or not cid.startswith(prefix) or cid in seen:
            continue
        mapped = classify_and_map(cid, cells, row)
        if not mapped:
            continue
        key, card = mapped
        out[key].append(card)
        seen.add(cid)
    return out


def write_pack(pack_id: str, data: dict) -> None:
    path = os.path.join(EXP_DIR, f"{pack_id}.json")
    existing = {}
    if os.path.exists(path):
        with open(path, encoding="utf-8") as f:
            existing = json.load(f)
    for key, cards in data.items():
        if not cards:
            continue
        by_id = {c["id"]: c for c in existing.get(key, [])}
        by_id.update({c["id"]: c for c in cards})
        existing[key] = sorted(by_id.values(), key=lambda c: c["id"])
    with open(path, "w", encoding="utf-8") as f:
        json.dump(existing, f, indent=2, ensure_ascii=False)
        f.write("\n")
    totals = ", ".join(f"{k}={len(existing.get(k, []))}" for k in sorted(existing))
    print(f"wrote {path} ({totals})")


def main():
    text = wiki_wikitext("List_of_Cards")
    for prefix, pack_id in PREFIX_TO_PACK.items():
        data = parse_pack(prefix, text)
        write_pack(pack_id, data)


if __name__ == "__main__":
    main()
