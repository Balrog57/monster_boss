#!/usr/bin/env python3
"""Verifie le manifeste de faces APK, les donnees du set de base et quelques assets d'UI. Usage : python tools/verify_assets.py"""
import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASSETS = os.path.join(ROOT, "src", "frontend", "assets")
MANIFEST = os.path.join(ROOT, "tools", "data", "apkCardManifest.json")
CARDS = os.path.join(ROOT, "src", "frontend", "godot", "data", "cards.json")
BASE_DECK = os.path.join(ASSETS, "data", "BaseDeck", "data.json")
UI_SAMPLES = ["ui/ingame/pass_button.webp", "ui/ingame/discard_pile.webp", "ui/ingame/card_slot.webp",
              "ui/ingame/room_icon_monster.webp", "ui/ingame/room_icon_trap.webp", "ui/icons/icon_cleric.webp"]


def load(path):
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def problem(rel):
    full = os.path.join(ASSETS, rel)
    if not os.path.exists(full):
        return full
    return full + " (empty)" if os.path.getsize(full) <= 0 else None


def main() -> int:
    manifest, data = load(MANIFEST), load(CARDS)
    faces, backs = manifest.get("faces", {}), manifest.get("backs", {})
    missing = [m for m in (problem("apk_cards/" + rel) for rel in [*faces.values(), *backs.values()]) if m]
    missing += [m for m in (problem(rel) for rel in UI_SAMPLES) if m]

    base = {s: [c for c in data.get(s, []) if not c.get("set") or c["set"] == "base"] for s in ("bosses", "rooms", "spells", "heroes")}
    issues = []
    if len(base["bosses"]) != 8:
        issues.append(f"expected 8 base bosses, got {len(base['bosses'])}")
    for s, n in (("rooms", 31), ("spells", 16), ("heroes", 41)):
        if len(base[s]) < n:
            issues.append(f"expected >={n} base {s}, got {len(base[s])}")
    for c in [c for cards in base.values() for c in cards]:
        stem = str(c["id"]).lower()
        if stem not in faces and stem + "a" not in faces:
            issues.append(f"no APK face for {c['id']}")
        if not c.get("name"):
            issues.append(f"{c['id']} missing name")

    # Art alternatif de la galerie APK : AlternativeArts = N -> <id>a ... <id><lettre N+1> (a = copie de <id>).
    for sec in ("RoomCards", "SpellCards"):
        for c in load(BASE_DECK).get(sec, []):
            n = int(c.get("AlternativeArts") or 0)
            for k in range(n + 1 if n else 0):
                m = problem("apk_cards/base/%s%s.webp" % (str(c["CardNumber"]).lower(), chr(97 + k)))
                if m:
                    missing.append(m)

    for title, items in (("missing or empty files", missing), ("card-data issues", issues)):
        if items:
            print(f"[verify_assets] {len(items)} {title}:", file=sys.stderr)
            for m in items[:20]:
                print("  ", m, file=sys.stderr)
            if len(items) > 20:
                print(f"  ... and {len(items) - 20} more", file=sys.stderr)
    if missing or issues:
        return 1

    print(f"[verify_assets] OK - base set {len(base['bosses'])} bosses, {len(base['rooms'])} rooms, {len(base['spells'])} spells, {len(base['heroes'])} heroes; all APK faces present.")
    exp_sets = {"next-level", "minibosses", "crash-landing"}
    name_map = data.get("nameMap", {})
    exp = miss_art = 0
    for section in ("bosses", "rooms", "spells", "heroes"):
        for c in data.get(section, []):
            if c.get("set") not in exp_sets:
                continue
            exp += 1
            d = "epic-heroes" if section == "heroes" and c.get("epic") else section
            if not os.path.exists(os.path.join(ASSETS, "cards", d, f"{c['id']}_{name_map.get(c['id'], c['id'].lower())}.webp")):
                miss_art += 1
    print(f"[verify_assets] expansions: {exp} cards, {miss_art} missing wiki art (non-fatal).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
