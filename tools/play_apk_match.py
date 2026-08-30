#!/usr/bin/env python3
"""Play through an APK 2.2.6 solo 2P match and capture each in-game phase."""
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
CONTINUE = (1550, 540)
TAP_START = (960, 626)
SINGLE = (720, 430)
PLAYERS_2 = (960, 560)
SKIP = (960, 900)
PLAY_BOSS = (960, 980)
PASS_CENTER = (960, 500)
HAND_1 = (700, 980)
SLOT_1 = (620, 780)
DISCARD_A = (492, 560)
DISCARD_B = (604, 560)


def adb(*args: str, timeout: int = 40) -> subprocess.CompletedProcess:
    return subprocess.run([ADB, "-s", "emulator-5554", *args], capture_output=True, timeout=timeout)


def screenshot(name: str) -> int:
    os.makedirs(OUT, exist_ok=True)
    dest = os.path.join(OUT, name)
    raw = subprocess.check_output([ADB, "-s", "emulator-5554", "exec-out", "screencap", "-p"], timeout=25)
    if raw[:8] != b"\x89PNG\r\n\x1a\n":
        raw = raw.replace(b"\r\n", b"\n")
    with open(dest, "wb") as f:
        f.write(raw)
    print(f"  {name} ({len(raw)} bytes)")
    return len(raw)


def tap(xy, wait=1.8):
    x, y = xy
    adb("shell", "input", "tap", str(x), str(y))
    time.sleep(wait)


def dismiss_dialogs():
    """Tap OK / SKIP if a modal is showing."""
    tap(OK, 1.2)
    tap(SKIP, 1.0)


def start_match():
    adb("shell", "am", "force-stop", PKG)
    time.sleep(1.2)
    adb("shell", "am", "start", "-n", ACTIVITY)
    time.sleep(14)
    screenshot("match_00_boot.png")
    tap(TAP_START, 2.5)
    tap(SINGLE, 2.0)
    tap(PLAYERS_2, 1.5)
    tap(OK, 3.0)          # expansions
    dismiss_dialogs()     # tutorial
    tap((700, 560), 2.0)  # pick boss in carousel
    tap(PLAY_BOSS, 3.0)
    dismiss_dialogs()
    tap(PLAY_BOSS, 3.5)   # confirm / wait for opponent AI boss


def opening_discard():
    screenshot("match_01_discard.png")
    tap(DISCARD_A, 0.8)
    tap(DISCARD_B, 0.8)
    screenshot("match_02_discard_picked.png")
    tap(CONTINUE, 3.5)
    screenshot("match_03_after_discard.png")


def build_turn(place=True):
    if place:
        tap(HAND_1, 1.4)
        screenshot("match_04_build_select.png")
        tap(SLOT_1, 2.0)
        screenshot("match_05_build_placed.png")
    screenshot("match_06_before_pass.png")
    tap(PASS_CENTER, 2.5)
    screenshot("match_07_after_pass.png")
    dismiss_dialogs()


def wait_phase(label: str, seconds: float = 3.0):
    time.sleep(seconds)
    return screenshot(label)


def adventure_step(n: int):
    """Try common adventure interaction points."""
    screenshot(f"match_adv_{n:02d}_start.png")
    tap(PASS_CENTER, 2.0)
    dismiss_dialogs()
    tap(OK, 1.5)
    tap((400, 400), 1.0)   # town / hero area
    tap((620, 780), 1.0)   # dungeon entrance
    screenshot(f"match_adv_{n:02d}_mid.png")


def main():
    print("devices:", adb("devices").stdout.decode("utf-8", "ignore").strip())
    start_match()
    opening_discard()

    # Turn 1 BUILD: human + AI
    build_turn(place=True)
    build_turn(place=False)  # AI turn — just pass if our turn again

    wait_phase("match_08_reveal.png", 4)
    dismiss_dialogs()
    wait_phase("match_09_bait.png", 3)
    dismiss_dialogs()

    adventure_step(1)
    adventure_step(2)
    wait_phase("match_10_adventure_end.png", 2)

    # Turn 2 if still in game
    build_turn(place=True)
    build_turn(place=False)
    wait_phase("match_11_turn2_reveal.png", 4)
    wait_phase("match_12_turn2_bait.png", 3)
    adventure_step(3)
    screenshot("match_13_final.png")

    print("done — check match_*.png in docs/reference/")


if __name__ == "__main__":
    main()
