#!/usr/bin/env python3
"""Inject base-set heroes BMA056–096 from wiki BaseDeck into src/cardData.json."""
from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BASE = json.loads((ROOT / "assets" / "data" / "BaseDeck" / "data.json").read_text(encoding="utf-8"))
DATA = json.loads((ROOT / "src" / "cardData.json").read_text(encoding="utf-8"))

CLASS_SLUG = {1: "cleric", 2: "fighter", 3: "mage", 4: "thief"}

heroes = []
for h in BASE.get("HeroCards") or []:
    cid = h["CardNumber"]
    treasure = (h.get("Treasures") or [1])[0]
    epic = h.get("HeroType") == 1 or (h.get("Subtitle") or "").lower().startswith("epic")
    heroes.append({
        "id": cid,
        "name": h.get("Name") or "Hero",
        "treasure": treasure,
        "hp": h.get("Health") or 4,
        "wounds": h.get("Wounds") or (2 if epic else 1),
        "souls": h.get("Souls") or (2 if epic else 1),
        "epic": epic,
        "quantity": h.get("Quantity") or 1,
        "description": h.get("Description") or "",
        "class": h.get("Name") or CLASS_SLUG.get(treasure, "Cleric").title(),
        "playerCount": h.get("MinimumPlayers") or 2,
        "set": "base",
        "subtitle": h.get("Subtitle") or ("Epic Hero" if epic else "Ordinary Hero"),
    })
    DATA.setdefault("nameMap", {})[cid] = CLASS_SLUG.get(treasure, "hero")

existing = {c["id"] for c in DATA.get("heroes") or []}
injected = [h for h in heroes if h["id"] not in existing]
DATA["heroes"] = injected + (DATA.get("heroes") or [])

out = ROOT / "src" / "cardData.json"
out.write_text(json.dumps(DATA, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
print(f"injected {len(injected)} base heroes (total heroes {len(DATA['heroes'])})")
