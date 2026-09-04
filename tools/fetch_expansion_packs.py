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
SPELL_PHASE = {"Build": 1, "Adventure": 3, "Both": 4, "Either": 4}


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
        s = m.group(1).strip()
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


def map_boss(cid: str, cells: list[str], row: str = "") -> dict:
    name = clean_cell(cells[1]) if len(cells) > 1 else cid
    xp_match = re.search(r"\d+", clean_cell(cells[3])) if len(cells) > 3 else None
    xp = int(xp_match.group()) if xp_match else 500
    treasures = parse_treasures(clean_cell(cells[4])) if len(cells) > 4 else [1]
    
    level = ""
    for c in cells[5:]:
        clean_c = clean_cell(c)
        if "level up" in clean_c.lower():
            level = re.sub(r"^.*?level up:?\s*", "", clean_c, flags=re.I).strip()
            break
    if not level:
        m = re.search(r"Level Up:?\s*(.+?)(?:\|\||\n|$)", row, re.I | re.S)
        if m:
            level = clean_cell(m.group(1))
            
    qty_match = re.search(r"\d+", clean_cell(cells[-1])) if cells else None
    qty = int(qty_match.group()) if qty_match else 1
    
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


def map_room(cid: str, cells: list[str], row: str = "") -> dict:
    name = clean_cell(cells[1]) if len(cells) > 1 else cid
    subtype = clean_cell(cells[2]) if len(cells) > 2 else "Monster Room"
    dmg_match = re.search(r"\d+", clean_cell(cells[3])) if len(cells) > 3 else None
    dmg = int(dmg_match.group()) if dmg_match else 1
    treasures = parse_treasures(clean_cell(cells[4])) if len(cells) > 4 else [1]
    
    desc = clean_cell(cells[6]) if len(cells) > 6 else ""
    if not desc or len(desc) < 3:
        for c in cells[5:]:
            clean_c = clean_cell(c)
            if len(clean_c) > len(desc) and not clean_c.isdigit() and "room" not in clean_c.lower()[:8]:
                desc = clean_c
                
    qty_match = re.search(r"\d+", clean_cell(cells[-1])) if cells else None
    qty = int(qty_match.group()) if qty_match else 1
    
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
    name = clean_cell(cells[1]) if len(cells) > 1 else cid
    phase_str = clean_cell(cells[3]) if len(cells) > 3 else "Build"
    phase = SPELL_PHASE.get(phase_str, 1)
    
    desc = clean_cell(cells[6]) if len(cells) > 6 else ""
    if not desc or len(desc) < 3:
        for c in cells[4:]:
            clean_c = clean_cell(c)
            if len(clean_c) > len(desc) and not clean_c.isdigit() and clean_c not in SPELL_PHASE:
                desc = clean_c
                
    # The quantity is column 9; trailing table/footer text may contain a year.
    qty_text = clean_cell(cells[8]) if len(cells) > 8 else "1"
    qty_match = re.match(r"^(\d+)(?:\s*[‡*])?\s*$", qty_text)
    if not qty_match:
        raise ValueError(f"{cid}: invalid spell quantity {qty_text!r}")
    qty = int(qty_match.group(1))
    
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
    subtype = clean_cell(cells[2]) if len(cells) > 2 else "Ordinary Hero"
    name_col = clean_cell(cells[1]) if len(cells) > 1 else cid
    desc_col = clean_cell(cells[6]) if len(cells) > 6 else ""
    
    name = name_col
    if name_col in ("Cleric", "Fighter", "Mage", "Thief", "Explorer", "Ordinary Hero", "Epic Hero", "Dark Hero"):
        if desc_col and len(desc_col) > 3:
            name = desc_col.split(".")[0].split(" -- ")[0].split(" - ")[0].strip()
            
    hp_match = re.search(r"\d+", clean_cell(cells[3])) if len(cells) > 3 else None
    hp = int(hp_match.group()) if hp_match else 5
    
    treasure_col = clean_cell(cells[4]) if len(cells) > 4 else "Fighter"
    treasures = parse_treasures(treasure_col)
    
    type_col = clean_cell(cells[5]) if len(cells) > 5 else ""
    epic = "Epic" in subtype or "Epic" in type_col
    dark = "Dark" in subtype or "Dark" in type_col or "Dark" in desc_col
    hybrid = "Hybrid" in subtype or "Hybrid" in type_col or len(treasures) > 1
    
    qty_match = re.search(r"\d+", clean_cell(cells[-1])) if cells else None
    qty = int(qty_match.group()) if qty_match else 1
    
    card = {
        "id": cid,
        "name": name,
        "treasure": treasures[0] if treasures else 1,
        "hp": hp,
        "wounds": 2 if epic else 1,
        "souls": 2 if epic else 1,
        "epic": epic,
        "class": list(TREASURE.keys())[treasures[0] - 1] if treasures else "Fighter",
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


def map_miniboss(cid: str, cells: list[str]) -> dict:
    name = clean_cell(cells[1]) if len(cells) > 1 else cid
    desc = clean_cell(cells[6]) if len(cells) > 6 else ""
    
    levels = []
    parts = re.split(r"Level\s+(\d+):\s*", desc, flags=re.I)
    if len(parts) >= 3:
        for k in range(1, len(parts), 2):
            lvl_num = int(parts[k])
            lvl_desc = parts[k+1].strip()
            levels.append({"level": lvl_num, "description": lvl_desc})
    else:
        levels.append({"level": 1, "description": desc})
        
    qty_match = re.search(r"\d+", clean_cell(cells[-1])) if cells else None
    qty = int(qty_match.group()) if qty_match else 1
    
    return {
        "id": cid,
        "name": name,
        "quantity": qty,
        "set": PREFIX_TO_PACK[cid[:3]],
        "levels": levels,
    }


def classify_and_map(cid: str, cells: list[str], row: str) -> tuple[str, dict] | None:
    type_col = clean_cell(cells[5]) if len(cells) > 5 else ""
    sub_col = clean_cell(cells[2]) if len(cells) > 2 else ""
    
    if type_col in ("Boss", "Bosses|Boss") or "Bosses|Boss" in row or (sub_col not in ("Monster Room", "Trap Room", "Advanced Monster Room", "Advanced Trap Room", "Spell") and any(re.search(r"\b" + re.escape(k) + r"\b", type_col, re.I) for k in ["boss"])):
        return "bosses", map_boss(cid, cells, row)
    if "miniboss" in type_col.lower() or "miniboss" in sub_col.lower() or (cid.startswith("RMB") and 55 <= int(cid[3:]) <= 64):
        return "minibosses", map_miniboss(cid, cells)
    if "room" in type_col.lower() or "room" in sub_col.lower() or "monster" in sub_col.lower() or "trap" in sub_col.lower():
        return "rooms", map_room(cid, cells, row)
    if "spell" in type_col.lower() or "spell" in sub_col.lower():
        return "spells", map_spell(cid, cells, row)
    if "hero" in type_col.lower() or "hero" in sub_col.lower():
        return "heroes", map_hero(cid, cells)
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
        raw_cells = split_table_row(row)
        clean_cells = [clean_cell(c) for c in raw_cells]
        cid = None
        for c in clean_cells:
            if re.fullmatch(rf"{prefix}\d{{3}}", c):
                cid = c
                break
        if not cid or not cid.startswith(prefix) or cid in seen:
            continue
        mapped = classify_and_map(cid, raw_cells, row)
        if not mapped:
            continue
        key, card = mapped
        out[key].append(card)
        seen.add(cid)
    return out


def write_pack(pack_id: str, data: dict) -> None:
    path = os.path.join(EXP_DIR, f"{pack_id}.json")
    out = {}
    for key, cards in data.items():
        if cards:
            out[key] = sorted(cards, key=lambda c: c["id"])
    with open(path, "w", encoding="utf-8") as f:
        json.dump(out, f, indent=2, ensure_ascii=False)
        f.write("\n")
    totals = ", ".join(f"{k}={len(out.get(k, []))}" for k in sorted(out))
    print(f"wrote {path} ({totals})")


def main():
    text = wiki_wikitext("List_of_Cards")
    for prefix, pack_id in PREFIX_TO_PACK.items():
        data = parse_pack(prefix, text)
        write_pack(pack_id, data)


if __name__ == "__main__":
    main()
