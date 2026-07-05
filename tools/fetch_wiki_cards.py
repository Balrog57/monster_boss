#!/usr/bin/env python3
"""
fetch_wiki_cards.py - Download card art from the Boss Monster wiki.

The wiki hosts clean, correctly-colored scans of every card. This replaces the
broken APK extraction (the WPK E_RBG decode produces greenish/blue-tinted cards)
with the authoritative reference images.

Sources, per category (mirrors src/cardData.json):
  bosses       BMA001-BMA008  -> assets/cards/bosses/
  rooms        BMA009-BMA039  -> assets/cards/rooms/
  spells       BMA040-BMA055  -> assets/cards/spells/
  heroes (ord) BMA056-BMA080  -> assets/cards/heroes/
  heroes (epic)BMA081-BMA096  -> assets/cards/epic-heroes/

Card backs are NOT on the wiki; they are kept from the existing APK extraction
(assets/cards/backs/).

Usage:
  python tools/fetch_wiki_cards.py            # download all 96 cards
  python tools/fetch_wiki_cards.py --dry-run  # show what would be downloaded
  python tools/fetch_wiki_cards.py --only BMA001,BMA002  # specific cards
"""
import argparse
import json
import os
import sys
import time
import urllib.request

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
WIKI_JSON = os.path.join(REPO, "wiki_images.json")
CARD_DATA = os.path.join(REPO, "src", "cardData.json")
ASSETS = os.path.join(REPO, "assets", "cards")

# Category -> (folder, id-set) derived from cardData.json at runtime.


def slugify(name):
    """Convert a card name to a filename slug (matches existing convention)."""
    out = []
    for ch in name.lower():
        if ch.isalnum():
            out.append(ch)
        elif ch in " -":
            out.append("-")
        else:
            out.append("-")
    s = "".join(out)
    while "--" in s:
        s = s.replace("--", "-")
    return s.strip("-")


def build_target_map(wiki):
    """Return {card_id: (folder, slug)} for every card the game needs.

    Uses the wiki's authoritative card name for the filename slug, fixing the
    placeholder class-only names ('Cleric', 'Fighter', etc.) in cardData.json.
    """
    with open(CARD_DATA, encoding="utf-8") as f:
        data = json.load(f)
    targets = {}
    for c in data["bosses"]:
        name = wiki.get(c["id"], {}).get("name", c["name"])
        targets[c["id"]] = ("bosses", slugify(name), name)
    for c in data["rooms"]:
        name = wiki.get(c["id"], {}).get("name", c["name"])
        targets[c["id"]] = ("rooms", slugify(name), name)
    for c in data["spells"]:
        name = wiki.get(c["id"], {}).get("name", c["name"])
        targets[c["id"]] = ("spells", slugify(name), name)
    for c in data["heroes"]:
        name = wiki.get(c["id"], {}).get("name", c["name"])
        folder = "epic-heroes" if c.get("epic") else "heroes"
        targets[c["id"]] = (folder, slugify(name), name)
    return targets, data


def download(url, dest):
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
    with urllib.request.urlopen(req, timeout=30) as r:
        data = r.read()
    with open(dest, "wb") as f:
        f.write(data)
    return len(data)


def cleanup_old_files(targets):
    """Remove old placeholder-named JPGs (e.g. BMA056_cleric.jpg) now that we
    save under the real card name (e.g. BMA056_nick-the-masher.jpg).
    Applies to all card folders.
    """
    removed = 0
    valid_names = {f"{cid}_{slug}.jpg" for cid, (folder, slug, _) in targets.items()}
    for folder in ("bosses", "rooms", "spells", "heroes", "epic-heroes"):
        d = os.path.join(ASSETS, folder)
        if not os.path.isdir(d):
            continue
        for fn in os.listdir(d):
            if fn.endswith(".jpg") and fn not in valid_names:
                os.remove(os.path.join(d, fn))
                removed += 1
    return removed


def main():
    ap = argparse.ArgumentParser(description="Download card art from the wiki")
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--only", help="comma-separated list of card IDs to fetch")
    args = ap.parse_args()

    with open(WIKI_JSON, encoding="utf-8") as f:
        wiki = json.load(f)
    targets, card_data = build_target_map(wiki)

    only = set(args.only.split(",")) if args.only else None
    ok = fail = skip = 0
    name_map_updates = {}
    hero_name_updates = {}  # cid -> real name, for heroes whose name was a class placeholder

    for cid in sorted(targets):
        if only and cid not in only:
            continue
        folder, slug, real_name = targets[cid]
        if cid not in wiki:
            print(f"  {cid}: SKIP (no wiki URL)")
            skip += 1
            continue
        url = wiki[cid]["imageUrl"]
        fname = f"{cid}_{slug}.jpg"
        dest = os.path.join(ASSETS, folder, fname)
        if args.dry_run:
            print(f"  {cid} -> {folder}/{fname}  ({real_name})")
            continue
        try:
            size = download(url, dest)
            print(f"  {cid}: OK {size//1024}KB -> {folder}/{fname}")
            ok += 1
            name_map_updates[cid] = slug
            # Track heroes that need their real name written back to cardData.
            for c in card_data["heroes"]:
                if c["id"] == cid and c["name"] != real_name:
                    hero_name_updates[cid] = real_name
            time.sleep(0.15)  # be polite to the wiki
        except Exception as e:
            print(f"  {cid}: FAIL ({e})")
            fail += 1

    if not args.dry_run and not only:
        # 1. Update hero names to their real wiki names (fixes the
        #    'Cleric'/'Fighter'/'Mage'/'Thief' placeholders).
        for c in card_data["heroes"]:
            if c["id"] in hero_name_updates:
                c["name"] = hero_name_updates[c["id"]]
        # 2. Update nameMap with the real filename slugs.
        card_data["nameMap"] = {**card_data.get("nameMap", {}), **name_map_updates}
        with open(CARD_DATA, "w", encoding="utf-8") as f:
            json.dump(card_data, f, indent=2, ensure_ascii=False)
        print(f"\nUpdated {len(hero_name_updates)} hero names + "
              f"{len(name_map_updates)} nameMap entries in {CARD_DATA}")
        # Clean up the old generically-named files (heroes + any renamed cards).
        removed = cleanup_old_files(targets)
        if removed:
            print(f"Removed {removed} obsolete JPGs (old names)")

    print(f"\nSummary: {ok} ok, {fail} failed, {skip} skipped")


if __name__ == "__main__":
    main()
