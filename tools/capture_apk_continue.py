#!/usr/bin/env python3
"""Continue the 2P APK match from YOU ARE CLEOPATRA / PLAY BOSS MONSTER."""
from __future__ import annotations

import os
import subprocess
import time

ADB = r"C:\Program Files\BlueStacks_nxt\HD-Adb.exe"
OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "docs", "reference")


def screenshot(name: str):
    dest = os.path.join(OUT, name)
    raw = subprocess.check_output([ADB, "exec-out", "screencap", "-p"], timeout=25)
    if raw[:8] != b"\x89PNG\r\n\x1a\n":
        raw = raw.replace(b"\r\n", b"\n")
    with open(dest, "wb") as f:
        f.write(raw)
    print("saved", name, len(raw))


def tap(x, y, wait=2.2):
    subprocess.run([ADB, "shell", "input", "tap", str(x), str(y)], check=False)
    time.sleep(wait)


def main():
    screenshot("play_20_before.png")
    # PLAY BOSS MONSTER — bottom-center gold-bordered button
    tap(960, 980, 3.5)
    screenshot("play_21_after_play.png")
    tap(960, 900, 2.5)
    screenshot("play_22.png")
    tap(1730, 1000, 2.5)
    screenshot("play_23.png")
    # Pass / build a room if a hand card is visible (left-of-center hand)
    tap(700, 980, 2.0)
    screenshot("play_24.png")
    tap(960, 700, 2.0)
    screenshot("play_25.png")
    tap(1730, 1000, 2.5)
    screenshot("play_26_board.png")


if __name__ == "__main__":
    main()
