#!/usr/bin/env python3
"""Convertit en alpha droit les webp lossless deja extraits (meme code que l'extraction : extract_apk_226.unpremultiply).
Saute : fonts/ (png), webp avec perte (cartes wiki : VP8/ALPH), fichiers non premultiplies (heuristique is_premultiplied).
Idempotence : les fichiers deja convertis sont listes dans tools/data/unpremultiplied_assets.txt (l'heuristique seule ne le garantit pas
pour les images dont les pixels semi-transparents sont presque opaques).
Usage : python tools/unpremultiply_assets.py [--apply]   (sans --apply : liste seulement)"""
import os
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from extract_apk_226 import ROOT, is_premultiplied, unpremultiply  # noqa: E402

ASSETS = os.path.join(ROOT, "src", "frontend", "assets")
DONE = os.path.join(ROOT, "tools", "data", "unpremultiplied_assets.txt")


def main() -> int:
    apply = "--apply" in sys.argv
    done = set(open(DONE, encoding="utf-8").read().split()) if os.path.exists(DONE) else set()
    n = 0
    for dp, dn, fn in os.walk(ASSETS):
        dn[:] = [d for d in dn if d != "fonts"]
        for f in fn:
            p = os.path.join(dp, f)
            if not f.endswith(".webp") or open(p, "rb").read(16)[12:16] != b"VP8L":
                continue
            rel = os.path.relpath(p, ASSETS).replace("\\", "/")
            im = Image.open(p).convert("RGBA")
            if rel in done or not is_premultiplied(im):
                continue
            n += 1
            print(rel)
            if apply:
                unpremultiply(im).save(p, "WEBP", lossless=True, exact=True)
                done.add(rel)
    if apply:
        with open(DONE, "w", encoding="utf-8", newline="\n") as fh:
            fh.write("\n".join(sorted(done)) + "\n")
    print(f"{n} fichier(s) {'convertis' if apply else 'a convertir'}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
