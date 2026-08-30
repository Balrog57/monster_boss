#!/usr/bin/env python3
"""Launch APK 2.2.6 and capture BUILD hand, selection, ghost slots, preview."""
from __future__ import annotations

import os
import subprocess
import time

ADB = r"C:\Program Files\BlueStacks_nxt\HD-Adb.exe"
PKG = "com.dbm.project"
ACTIVITY = "com.dbm.project/md5399b08adcce2dcd4a96d41bd345c86c9.AndroidActivity"
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "docs", "reference")

OK = (1737, 983)
CONTINUE = (1550, 540)  # opening discard overlay (not OK — that opens credits)
TAP_START = (960, 626)
SINGLE = (720, 430)
PLAYERS_2 = (960, 560)
SKIP = (960, 900)
PLAY_BOSS = (960, 980)
HAND_CARD = (820, 980)   # first-ish hand card in bottom dock
GHOST_SLOT = (620, 780)  # empty dungeon slot on player row
PASS = (1730, 1000)


def adb(*args: str, timeout: int = 40) -> subprocess.CompletedProcess:
    return subprocess.run([ADB, "-s", "emulator-5554", *args], capture_output=True, timeout=timeout)


def screenshot(name: str) -> str:
    os.makedirs(OUT, exist_ok=True)
    dest = os.path.join(OUT, name)
    raw = subprocess.check_output([ADB, "-s", "emulator-5554", "exec-out", "screencap", "-p"], timeout=25)
    if raw[:8] != b"\x89PNG\r\n\x1a\n":
        raw = raw.replace(b"\r\n", b"\n")
    with open(dest, "wb") as f:
        f.write(raw)
    print(f"saved {name} ({len(raw)} bytes)")
    return dest


def tap(xy, wait=1.8):
    x, y = xy
    adb("shell", "input", "tap", str(x), str(y))
    time.sleep(wait)


def main():
    print(adb("devices").stdout.decode("utf-8", "ignore"))
    adb("shell", "am", "force-stop", PKG)
    time.sleep(1.2)
    adb("shell", "am", "start", "-n", ACTIVITY)
    time.sleep(14)
    screenshot("ingame_00_boot.png")

    tap(TAP_START, 2.6)
    screenshot("ingame_01_menu.png")

    tap(SINGLE, 2.2)
    screenshot("ingame_02_setup.png")

    tap(PLAYERS_2, 1.4)
    screenshot("ingame_03_setup_2p.png")

    tap(OK, 4.0)
    screenshot("ingame_04_after_ok.png")

    # Skip tutorial / extra dialogs if present
    tap(OK, 2.2)
    screenshot("ingame_05.png")
    tap(SKIP, 2.2)
    screenshot("ingame_06.png")

    # Boss carousel: swipe/tap a card then PLAY BOSS MONSTER
    tap((700, 560), 2.4)
    screenshot("ingame_07_boss.png")
    tap(PLAY_BOSS, 3.5)
    screenshot("ingame_08_after_boss.png")
    tap(OK, 2.5)
    screenshot("ingame_09.png")
    tap(PLAY_BOSS, 4.0)
    screenshot("ingame_10_discard_or_board.png")

    # Opening discard: tap two cards then CONTINUE
    tap((492, 560), 1.2)
    tap((604, 560), 1.2)
    screenshot("ingame_11_discard_picked.png")
    tap(CONTINUE, 3.0)
    screenshot("ingame_12_after_discard.png")

    # Setup/BUILD: select a hand card, then a ghost slot
    screenshot("ingame_13_board_idle.png")
    tap(HAND_CARD, 1.6)
    screenshot("ingame_14_card_selected.png")
    tap(GHOST_SLOT, 2.0)
    screenshot("ingame_15_after_place.png")
    tap(PASS, 2.5)
    screenshot("ingame_16_after_pass.png")
    tap(OK, 2.0)
    screenshot("ingame_17.png")


if __name__ == "__main__":
    main()
