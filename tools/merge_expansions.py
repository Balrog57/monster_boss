#!/usr/bin/env python3
"""Merge expansion JSON packs into src/frontend/godot/data/cards.json (TNL / RMB / CRL), puis recalcule `implemented` (sync_implemented.py)."""
from __future__ import annotations

import json
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import sync_implemented  # noqa: E402
from cards_io import CARDS as OUT, ROOT, dump_cards  # noqa: E402

EXP_DIR = os.path.join(ROOT, "src", "frontend", "assets", "data", "expansions")
CORRUPT = re.compile(r"\]\]$")


def load(path: str) -> dict:
    with open(path, encoding="utf-8") as f:
        return json.load(f)


EXP_PREFIXES = ("TNL", "RMB", "CRL")


def clean_name(raw: str) -> str:
    """Names can carry the wiki flavour line or a link remnant."""
    if not raw:
        return raw
    s = raw
    if "|" in s:
        head, tail = s.split("|", 1)
        if "]" in tail or head.strip() == tail.strip():
            s = head
    s = re.split(r"\xa0", s, maxsplit=1)[0]
    s = s.split("\n", 1)[0]
    s = s.replace("[", "").replace("]", "")
    return re.sub(r"\s+", " ", s).strip()


def filter_base(cards: list, key="id") -> list:
    return [c for c in cards if not any(c[key].startswith(p) for p in EXP_PREFIXES)]


def main():
    with open(OUT, encoding="utf-8") as f:
        data = json.load(f)

    # Clean previous expansion entries from all sections so moved cards do not linger.
    # cards.json porte des champs a la main (levelUp, heroAbility, lure, treasures, dark...) absents des packs : on les garde.
    previous = {}
    for section in ("bosses", "rooms", "spells", "heroes", "items", "minibosses"):
        if section in data:
            previous.update({c["id"]: c for c in data[section]})
            data[section] = filter_base(data[section])

    for name in ("next-level", "minibosses", "crash-landing"):
        path = os.path.join(EXP_DIR, f"{name}.json")
        if not os.path.exists(path):
            print(f"skip missing {path}")
            continue
        pack = load(path)
        for section in ("bosses", "rooms", "spells", "heroes", "items", "minibosses"):
            if pack.get(section):
                for k, c in enumerate(pack[section]):
                    c["name"] = clean_name(c.get("name", ""))
                    pack[section][k] = {**c, **previous.get(c["id"], {})}  # cards.json (corrections a la main) l'emporte sur le pack
                existing = data.setdefault(section, [])
                existing.extend(pack[section])
                data[section] = sorted(existing, key=lambda c: c["id"])
        nm = data.setdefault("nameMap", {})
        for section in ("bosses", "rooms", "spells", "heroes", "items", "minibosses"):
            for c in pack.get(section, []):
                cid = c["id"]
                slug = c["name"].lower().replace("'", "-")
                slug = "".join(ch if ch.isalnum() or ch == "-" else "-" for ch in slug).strip("-")
                nm[cid] = slug or cid.lower()
        print(f"merged {name}: +{len(pack.get('rooms', []))} rooms")

    impl_path = os.path.join(EXP_DIR, "implemented.json")
    if os.path.exists(impl_path):
        implemented = set(load(impl_path).get("ids", []))
        flagged = 0
        for section in ("bosses", "rooms", "spells", "heroes", "items", "minibosses"):
            for c in data.get(section, []):
                if c["id"] in implemented:
                    c["implemented"] = True
                    flagged += 1
        missing = sorted(implemented - {c["id"] for s in ("bosses", "rooms", "spells", "heroes", "items", "minibosses") for c in data.get(s, [])})
        if missing:
            print(f"WARNING: implemented.json ids not in cards.json: {missing}", file=sys.stderr)
        print(f"applied implemented flag to {flagged} cards")

    with open(OUT, "w", encoding="utf-8", newline="") as f:
        f.write(dump_cards(data))
    print(f"updated {OUT}")

    corrupt = []
    for section in ("bosses", "rooms", "spells", "heroes", "minibosses"):
        for c in data.get(section, []):
            text = c.get("levelUpDesc") or c.get("description") or ""
            if section == "minibosses":
                text = " ".join(l.get("description", "") for l in c.get("levels", []))
            if CORRUPT.search(text or ""):
                corrupt.append(c["id"])
    if corrupt:
        print(f"ERROR: corrupt card text in {len(corrupt)} cards: {corrupt[:10]}...", file=sys.stderr)
        sys.exit(1)

    sync_implemented.main()  # recalcule `implemented` d'apres le moteur Godot


if __name__ == "__main__":
    main()
