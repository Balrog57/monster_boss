#!/usr/bin/env python3
"""Merge expansion JSON packs into src/cardData.json (TNL / RMB / CRL)."""
from __future__ import annotations

import json
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "src", "cardData.json")
EXP_DIR = os.path.join(ROOT, "assets", "data", "expansions")
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

    # Clean previous expansion entries from all sections so moved cards do not linger
    for section in ("bosses", "rooms", "spells", "heroes", "items", "minibosses"):
        if section in data:
            data[section] = filter_base(data[section])

    for name in ("next-level", "minibosses", "crash-landing"):
        path = os.path.join(EXP_DIR, f"{name}.json")
        if not os.path.exists(path):
            print(f"skip missing {path}")
            continue
        pack = load(path)
        for section in ("bosses", "rooms", "spells", "heroes", "items", "minibosses"):
            if pack.get(section):
                for c in pack[section]:
                    c["name"] = clean_name(c.get("name", ""))
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
            print(f"WARNING: implemented.json ids not in cardData: {missing}", file=sys.stderr)
        print(f"applied implemented flag to {flagged} cards")

    with open(OUT, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2, ensure_ascii=False)
        f.write("\n")
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

    matrix = os.path.join(ROOT, "tools", "generate_card_matrix.js")
    subprocess.run(["node", matrix], cwd=ROOT, check=True)


if __name__ == "__main__":
    main()
