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
from extract_apk_226 import ASSETS, is_premultiplied, mark_unpremultiplied, read_unpremultiplied, unpremultiply  # noqa: E402


def main() -> int:
    apply = "--apply" in sys.argv
    done = read_unpremultiplied()
    n = 0
    for dp, dn, fn in os.walk(ASSETS):
        dn[:] = [d for d in dn if d != "fonts"]
        for f in fn:
            p = os.path.join(dp, f)
            if not f.endswith(".webp") or open(p, "rb").read(16)[12:16] != b"VP8L":
                continue
            rel = os.path.relpath(p, ASSETS).replace("\\", "/")
            im = Image.open(p).convert("RGBA")
            if rel in done or not is_premultiplied(im):  # liste d'abord : un fichier deja converti n'est jamais reconverti
                continue
            n += 1
            print(rel)
            if apply:
                tmp = p + ".tmp"
                unpremultiply(im).save(tmp, "WEBP", lossless=True, exact=True)
                os.replace(tmp, p)
                mark_unpremultiplied(p)  # liste mise a jour fichier par fichier : un plantage ne perd pas les conversions deja faites
    print(f"{n} fichier(s) {'convertis' if apply else 'a convertir'}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
