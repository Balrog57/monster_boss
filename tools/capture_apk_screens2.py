#!/usr/bin/env python3
"""Capture remaining APK screens after TAP TO START."""
from __future__ import annotations

import os
import subprocess
import time

ADB = r"C:\Program Files\BlueStacks_nxt\HD-Adb.exe"
PKG = "com.dbm.project"
ACTIVITY = "com.dbm.project/md5399b08adcce2dcd4a96d41bd345c86c9.AndroidActivity"
OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "docs", "reference")


def screenshot(name: str):
    os.makedirs(OUT, exist_ok=True)
    dest = os.path.join(OUT, name)
    raw = subprocess.check_output([ADB, "exec-out", "screencap", "-p"], timeout=20)
    if raw[:8] != b"\x89PNG\r\n\x1a\n":
        raw = raw.replace(b"\r\n", b"\n")
    with open(dest, "wb") as f:
        f.write(raw)
    print("saved", dest, len(raw))


def tap(x, y, wait=1.4):
    subprocess.run([ADB, "shell", "input", "tap", str(x), str(y)], check=False)
    time.sleep(wait)


def main():
    subprocess.run([ADB, "shell", "am", "force-stop", PKG], check=False)
    time.sleep(1)
    subprocess.run([ADB, "shell", "am", "start", "-n", ACTIVITY], check=False)
    time.sleep(12)
    screenshot("10_intro.png")
    tap(960, 700, 2.5)  # TAP TO START
    screenshot("11_menu.png")
    tap(720, 430, 2.0)  # SINGLE PLAYER
    screenshot("12_setup.png")
    tap(760, 540, 1.2)  # 2 players
    screenshot("13_setup_2p.png")
    tap(960, 860, 4.0)  # OK
    screenshot("14_after_setup.png")
    tap(700, 540, 2.5)  # pick a boss if on select
    screenshot("15_boss_or_game.png")
    tap(960, 900, 2.0)
    screenshot("16_board.png")


if __name__ == "__main__":
    main()
