#!/usr/bin/env python3
"""Copy APK background music into assets/audio/music/."""
import os
import shutil

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "boss-monster-2-2-6", "assets", "Content", "Audio", "Music")
DEST = os.path.join(ROOT, "assets", "audio", "music")


def main():
    if not os.path.isdir(SRC):
        print(f"missing APK music folder: {SRC}", file=__import__("sys").stderr)
        raise SystemExit(1)
    os.makedirs(DEST, exist_ok=True)
    for fn in os.listdir(SRC):
        if fn.lower().endswith(".mp3"):
            shutil.copy2(os.path.join(SRC, fn), os.path.join(DEST, fn))
            print(f"  {fn}")
    print(f"copied music to {DEST}")


if __name__ == "__main__":
    main()
