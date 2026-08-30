#!/usr/bin/env python3
"""Navigate APK through discard → BUILD → reveal → BAIT → ADVENTURE and capture."""
from __future__ import annotations

import os
import subprocess
import time

ADB = r"C:\Program Files\BlueStacks_nxt\HD-Adb.exe"
PKG = "com.dbm.project"
ACTIVITY = "com.dbm.project/md5399b08adcce2dcd4a96d41bd345c86c9.AndroidActivity"
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "docs", "reference")

# 1920×1080 coordinates
OK = (1806, 1006)
GAME_OVER_OK = (1552, 1007)
TAP_START = (960, 626)
SINGLE = (720, 430)
PLAYERS_2 = (960, 560)
SKIP = (960, 900)
PLAY_BOSS = (945, 973)
CONTINUE = (1550, 540)
PASS = (960, 500)
PASS_ALT = (1730, 1000)
HAND_CARD = (700, 980)
GHOST_SLOT = (620, 780)
GHOST_SLOT2 = (900, 760)


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
    adb("shell", "am", "force-stop", PKG)
    time.sleep(1.2)
    adb("shell", "am", "start", "-n", ACTIVITY)
    time.sleep(14)

    tap(TAP_START, 2.6)
    tap(SINGLE, 2.2)
    tap(PLAYERS_2, 1.4)
    tap(OK, 4.0)
    tap(OK, 2.2)
    tap(SKIP, 2.2)

    tap((700, 560), 2.4)
    tap(PLAY_BOSS, 3.5)
    time.sleep(6.0)
    tap(PLAY_BOSS, 4.0)

    # Opening discard: pick 2 cards + CONTINUE
    tap((492, 560), 1.0)
    tap((604, 560), 1.0)
    screenshot("apk_discard_picked.png")
    tap(CONTINUE, 3.5)
    screenshot("apk_after_discard.png")

    # SETUP/BUILD: place room, pass both players
    screenshot("apk_build_idle.png")
    tap(HAND_CARD, 1.6)
    screenshot("apk_build_card_sel.png")
    tap(GHOST_SLOT, 2.0)
    screenshot("apk_build_placed.png")
    tap(PASS, 2.5)
    screenshot("apk_build_pass1.png")
    tap(OK, 1.5)
    tap(PASS_ALT, 2.5)
    screenshot("apk_build_pass2.png")
    tap(OK, 2.0)

    # Reveal / end of BUILD
    screenshot("apk_reveal.png")
    time.sleep(2.0)
    screenshot("apk_post_reveal.png")
    tap(OK, 2.0)
    tap(PASS, 2.0)

    # BAIT phase
    screenshot("apk_bait.png")
    time.sleep(2.0)
    tap(OK, 2.0)

    # ADVENTURE
    screenshot("apk_adventure_start.png")
    tap(PASS, 2.0)
    screenshot("apk_adventure_mid.png")
    tap(OK, 2.0)
    tap(PASS_ALT, 2.0)
    screenshot("apk_adventure_end.png")

    # Hand tabs / spell
    tap((120, 980), 1.0)
    screenshot("apk_hand_tabs.png")


if __name__ == "__main__":
    main()
