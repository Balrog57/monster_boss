#!/usr/bin/env python3
"""Continue from APK discard overlay: tap CONTINUE, then capture BUILD hand/selection."""
from __future__ import annotations

import os
import subprocess
import time

ADB = r"C:\Program Files\BlueStacks_nxt\HD-Adb.exe"
OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "docs", "reference")

CONTINUE_CANDIDATES = [
    (1550, 540),  # confirmed: advances discard → BUILD
    (1480, 560),
    (1620, 560),
    (1400, 620),
    (1680, 560),
    (1730, 540),
    (1280, 700),
    (960, 900),
    (1737, 983),
]


def screenshot(name: str):
    dest = os.path.join(OUT, name)
    raw = subprocess.check_output([ADB, "-s", "emulator-5554", "exec-out", "screencap", "-p"], timeout=25)
    if raw[:8] != b"\x89PNG\r\n\x1a\n":
        raw = raw.replace(b"\r\n", b"\n")
    with open(dest, "wb") as f:
        f.write(raw)
    print("saved", name, len(raw))


def tap(x, y, wait=2.0):
    subprocess.run([ADB, "-s", "emulator-5554", "shell", "input", "tap", str(x), str(y)], check=False)
    time.sleep(wait)


def main():
    screenshot("ingame_20_still_discard.png")
    # Two cards already highlighted; try CONTINUE positions
    for i, (x, y) in enumerate(CONTINUE_CANDIDATES):
        tap(x, y, 1.8)
        screenshot(f"ingame_21_try{i:02d}_{x}_{y}.png")

    # If we reached BUILD, capture hand + select + place
    tap((700, 980), 1.6)
    screenshot("ingame_30_hand_tap.png")
    tap((900, 760), 1.8)
    screenshot("ingame_31_slot_tap.png")
    tap((1730, 1000), 2.0)
    screenshot("ingame_32_pass.png")


if __name__ == "__main__":
    main()
