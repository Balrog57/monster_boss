#!/usr/bin/env python3
"""Launch the 2.2.6 APK in BlueStacks and capture reference screenshots."""
from __future__ import annotations

import os
import subprocess
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ADB = r"C:\Program Files\BlueStacks_nxt\HD-Adb.exe"
PKG = "com.dbm.project"
ACTIVITY = "com.dbm.project/md5399b08adcce2dcd4a96d41bd345c86c9.AndroidActivity"
OUT = os.path.join(ROOT, "docs", "reference")


def adb(*args: str, timeout: int = 30) -> subprocess.CompletedProcess:
    return subprocess.run([ADB, *args], capture_output=True, timeout=timeout)


def screenshot(name: str) -> str:
    os.makedirs(OUT, exist_ok=True)
    dest = os.path.join(OUT, name)
    raw = subprocess.check_output([ADB, "exec-out", "screencap", "-p"], timeout=20)
    if raw[:8] != b"\x89PNG\r\n\x1a\n":
        raw = raw.replace(b"\r\n", b"\n")
    with open(dest, "wb") as f:
        f.write(raw)
    print(f"  saved {dest} ({len(raw)} bytes)")
    return dest


def tap(x: int, y: int):
    adb("shell", "input", "tap", str(x), str(y))
    time.sleep(1.2)


def dump_focus() -> str:
    p = adb("shell", "dumpsys", "window")
    text = (p.stdout or b"").decode("utf-8", "ignore")
    for line in text.splitlines():
        if "mCurrentFocus" in line or "mFocusedApp" in line:
            return line.strip()
    return ""


def main():
    print("devices:", adb("devices").stdout.decode("utf-8", "ignore").strip())
    adb("shell", "am", "force-stop", PKG)
    time.sleep(1)
    adb("shell", "am", "start", "-n", ACTIVITY)
    print("started", dump_focus())
    time.sleep(10)
    screenshot("01_boot.png")
    # Typical 1920×1080 intro / menu taps (scaled from APK 16:9).
    tap(960, 820)
    screenshot("02_after_center_tap.png")
    tap(960, 540)
    screenshot("03_mid.png")
    # Single player cell (left-top of 2×2), then 2 players, then OK.
    tap(700, 480)
    screenshot("04_after_single.png")
    tap(760, 540)
    screenshot("05_setup.png")
    tap(960, 820)
    screenshot("06_after_ok.png")
    print("focus", dump_focus())


if __name__ == "__main__":
    main()
