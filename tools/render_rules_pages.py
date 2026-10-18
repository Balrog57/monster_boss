#!/usr/bin/env python3
"""One-off generator: renders the official Brotherwise rulebooks (docs/rules/*.pdf) to WebP pages for the in-game RULES screen.
Output (committed): src/frontend/assets/rules/<book>/pNN.webp, 1500 px wide. Needs PyMuPDF + Pillow. Usage: python tools/render_rules_pages.py
"""
import os

import fitz
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BOOKS = {"base": "rules_base", "next-level": "rules_next_level", "minibosses": "rules_minibosses", "crash-landing": "rules_crash_landing"}
WIDTH = 1500

total = 0
for book, pdf in BOOKS.items():
    out = os.path.join(ROOT, "src", "frontend", "assets", "rules", book)
    os.makedirs(out, exist_ok=True)
    for i, page in enumerate(fitz.open(os.path.join(ROOT, "docs", "rules", pdf + ".pdf")), 1):
        pix = page.get_pixmap(matrix=fitz.Matrix(WIDTH / page.rect.width, WIDTH / page.rect.width), alpha=False)
        path = os.path.join(out, f"p{i:02d}.webp")
        Image.frombytes("RGB", (pix.width, pix.height), pix.samples).save(path, quality=85)
        total += os.path.getsize(path)
    print(book, i, "pages")
print("total %.1f MB" % (total / 1e6))
