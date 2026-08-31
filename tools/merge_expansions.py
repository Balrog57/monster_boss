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


def merge_list(existing: list, extra: list, key="id") -> list:
    by_id = {c[key]: c for c in existing}
    for c in extra:
        by_id[c[key]] = c
    return sorted(by_id.values(), key=lambda c: c[key])


def main():
    with open(OUT, encoding="utf-8") as f:
        data = json.load(f)

    for name in ("next-level", "minibosses", "crash-landing"):
        path = os.path.join(EXP_DIR, f"{name}.json")
        if not os.path.exists(path):
            print(f"skip missing {path}")
            continue
        pack = load(path)
        data["bosses"] = merge_list(data.get("bosses", []), pack.get("bosses", []))
        data["rooms"] = merge_list(data.get("rooms", []), pack.get("rooms", []))
        data["spells"] = merge_list(data.get("spells", []), pack.get("spells", []))
        data["heroes"] = merge_list(data.get("heroes", []), pack.get("heroes", []))
        data["items"] = merge_list(data.get("items", []), pack.get("items", []))
        if pack.get("minibosses"):
            data["minibosses"] = merge_list(data.get("minibosses", []), pack.get("minibosses", []))
        nm = data.setdefault("nameMap", {})
        for section in ("bosses", "rooms", "spells", "heroes", "items"):
            for c in pack.get(section, []):
                cid = c["id"]
                slug = c["name"].lower().replace("'", "-")
                slug = "".join(ch if ch.isalnum() or ch == "-" else "-" for ch in slug).strip("-")
                nm[cid] = slug or cid.lower()
        print(f"merged {name}: +{len(pack.get('rooms', []))} rooms")

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
