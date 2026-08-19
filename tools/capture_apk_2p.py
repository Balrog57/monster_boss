#!/usr/bin/env python3
"""Play a 2-player APK game in BlueStacks and capture every screen.

Previous captures tapped the CENTER (960, 860) after setup, which is NOT the
OK button (bottom-right) — that is what triggered FULL GAME NEEDED.
"""
from __future__ import annotations

import os
import subprocess
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ADB = r"C:\Program Files\BlueStacks_nxt\HD-Adb.exe"
PKG = "com.dbm.project"
ACTIVITY = "com.dbm.project/md5399b08adcce2dcd4a96d41bd345c86c9.AndroidActivity"
OUT = os.path.join(ROOT, "docs", "reference")

# 1920×1080 WaveEngine layout (from APK screens + HTML GameStage clones)
OK = (1737, 983)          # ok_bt bottom-right
BACK = (96, 77)           # back_bt top-left
TAP_START = (960, 626)    # TAP TO START
SINGLE = (720, 430)       # 2×2 top-left
MULTI = (1200, 430)
OPTIONS = (720, 680)
STORE = (1200, 680)
PLAYERS_2 = (960, 560)    # center fan
SKIP = (960, 900)


def adb(*args: str, timeout: int = 40) -> subprocess.CompletedProcess:
    return subprocess.run([ADB, *args], capture_output=True, timeout=timeout)


def screenshot(name: str) -> str:
    os.makedirs(OUT, exist_ok=True)
    dest = os.path.join(OUT, name)
    raw = subprocess.check_output([ADB, "exec-out", "screencap", "-p"], timeout=25)
    if raw[:8] != b"\x89PNG\r\n\x1a\n":
        raw = raw.replace(b"\r\n", b"\n")
    with open(dest, "wb") as f:
        f.write(raw)
    print(f"saved {name} ({len(raw)} bytes)")
    return dest


def tap(xy, wait=1.6):
    x, y = xy
    adb("shell", "input", "tap", str(x), str(y))
    time.sleep(wait)


def main():
    print(adb("devices").stdout.decode("utf-8", "ignore"))
    adb("shell", "am", "force-stop", PKG)
    time.sleep(1.2)
    adb("shell", "am", "start", "-n", ACTIVITY)
    time.sleep(12)
    screenshot("play_00_boot.png")
    tap(TAP_START, 2.4)
    screenshot("play_01_menu.png")
    tap(SINGLE, 2.0)
    screenshot("play_02_setup.png")
    tap(PLAYERS_2, 1.2)
    screenshot("play_03_setup_2p.png")
    tap(OK, 3.5)
    screenshot("play_04_after_ok.png")
    # Skip tutorial / extra dialogs if present
    tap(OK, 2.0)
    screenshot("play_05.png")
    tap(SKIP, 2.0)
    screenshot("play_06.png")
    # Boss pick: tap a card near center-left
    tap((520, 620), 2.5)
    screenshot("play_07_boss.png")
    tap(OK, 3.0)
    screenshot("play_08.png")
    tap((900, 620), 2.5)
    screenshot("play_09.png")
    tap(OK, 4.0)
    screenshot("play_10_board.png")
    # A couple of in-game taps (pass / room)
    tap((1730, 1000), 2.5)
    screenshot("play_11_ingame.png")
    tap((1730, 1000), 2.5)
    screenshot("play_12_ingame.png")


if __name__ == "__main__":
    main()
