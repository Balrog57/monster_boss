#!/usr/bin/env python3
"""Extract KSA dungeon BGs, boss sprites, and expansion card rasters used as APK fallback."""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from extract_apk_226 import (  # noqa: E402
    CONTENT,
    OUT_CHARS,
    OUT_DUNGEON,
    extract_atlas_file,
    write_card_manifest,
)

DECKS = os.path.join(CONTENT, "CardDecks")
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_CARDS = os.path.join(ROOT, "assets", "apk_cards")


def p(rel: str) -> str:
    return os.path.join(DECKS, rel.replace("/", os.sep))


def main():
    jobs = [
        (p("PlayerChoice/Assets/dungeonbg_ksa001_ksa004.wpk"), OUT_DUNGEON, False, True, False),
        (p("PlayerChoice/Assets/dungeonbg_ksa005_ksa007.wpk"), OUT_DUNGEON, False, True, False),
        (p("PlayerChoice/Assets/boss_profile.wpk"), OUT_CHARS, False, False, True),
        (p("HiddenHeros/Assets/bmh056-bmh075.wpk"), os.path.join(OUT_CARDS, "hidden"), False, False, False),
        (p("HiddenHeros/Assets/bmh076-bmh095.wpk"), os.path.join(OUT_CARDS, "hidden"), False, False, False),
        (p("HiddenHeros/Assets/bmh096-bmh096.wpk"), os.path.join(OUT_CARDS, "hidden"), False, False, False),
        (p("PlayerChoice/Assets/ksa001-ksa017.wpk"), os.path.join(OUT_CARDS, "playerchoice"), False, False, False),
        (p("ToolsHeroKind/Assets/back_item-thk019.wpk"), os.path.join(OUT_CARDS, "tools"), False, False, False),
        (p("ToolsHeroKind/Assets/thk020-thk025.wpk"), os.path.join(OUT_CARDS, "tools"), False, False, False),
    ]
    for path, out, r_high, lossy, chroma in jobs:
        if not os.path.exists(path):
            print("missing", path)
            continue
        extract_atlas_file(path, out, r_high, lossy=lossy, chroma=chroma)
    write_card_manifest()


if __name__ == "__main__":
    main()
