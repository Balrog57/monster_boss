#!/usr/bin/env python3
"""Phase 5 : ecart image contre image entre les frames de l'APK (BlueStacks) et les captures Godot.

Entree : `tools/parity/frame_pairs.json` (une ligne par frame APK : capture Godot appariee ou `null` + raison).
Frames APK : `docs/reference/apk_orig/` et `apk_orig2/` ; captures Godot : `docs/reference/godot_screens/godot_<nom>.png`
(produites par `godot --path src/frontend --resolution 1920x1080 res://godot/tests/CaptureScreens.tscn`, fenetre reelle).
Par paire (gris, zones masquees exclues) : ecart absolu moyen, grille 12x7 (carte de chaleur), % de pixels a plus de 16/255, SSIM par blocs de 16.
Sortie : tools/parity/out/image_diff.md + .csv (tries du pire au meilleur) et docs/reference/diff/<frame>.png (APK | Godot | diff | grille).
Usage : python tools/parity/image_diff.py [--check] [--capture] [--no-png] [--only=<sous-chaine>] [--godot-dir=<dossier sous docs/reference>] [--tag=<nom>]
  --check    code 1 si une paire seuillee depasse son seuil (garde-fou de non-regression, pas de PNG)
  --capture  relance d'abord CaptureScreens (fenetre, ~minutes) pour rafraichir les captures Godot
Seuils (cle `max_*`, sinon ceux du `kind` dans "kinds") : max_mean, max_pct, max_cell (moyenne de la pire cellule), max_chrome (ecart moyen sur les rectangles `chrome` du kind :
colonnes laterales, bandeau de phase, boutons ; hors masques). `probes` d'une paire : [x, y, w, h, nom, tolerance] = ecart de la couleur MOYENNE d'un morceau de fond (RGB, signe) ;
la pire sonde est rapportee (colonne `sonde`) et echoue au-dela de sa tolerance. `mask` : [x, y, w, h, raison] = zone exclue (contenu de la partie), la raison est obligatoire.
"""
import csv
import json
import math
import os
import subprocess
import sys

import numpy as np
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
REF = os.path.join(ROOT, "docs", "reference")
PAIRS = os.path.join(HERE, "frame_pairs.json")
OUT = os.path.join(HERE, "out")
DIFF_DIR = os.path.join(REF, "diff")
GRID = (12, 7)  # colonnes, lignes
BLOCK = 16
sys.path.insert(0, os.path.dirname(HERE))


def load_grey(path, size=None):
    im = Image.open(path).convert("RGB")
    if size is not None and im.size != size:
        im = im.resize(size, Image.BILINEAR)
    return im, np.asarray(im.convert("L"), dtype=np.float32)


def usable_crop(a, g):
    """APK 1920x1080 fait foi ; une capture d'une autre taille est rognee au centre a la largeur / hauteur communes, puis les deux sont rognees pareil."""
    w, h = min(a.size[0], g.size[0]), min(a.size[1], g.size[1])
    def c(im):
        x, y = (im.size[0] - w) // 2, (im.size[1] - h) // 2
        return im.crop((x, y, x + w, y + h))
    return c(a), c(g)


def mask_array(shape, regions):
    m = np.ones(shape, dtype=bool)  # True = compte
    for r in regions:
        x, y, w, h = r[:4]
        m[y:y + h, x:x + w] = False
    return m


def ssim_blocks(a, b, valid):
    """SSIM par blocs de 16x16 (constantes standard, plage 255), moyenne sur les blocs entierement valides."""
    h, w = a.shape[0] // BLOCK * BLOCK, a.shape[1] // BLOCK * BLOCK
    def blk(x):
        return x[:h, :w].reshape(h // BLOCK, BLOCK, w // BLOCK, BLOCK).transpose(0, 2, 1, 3).reshape(h // BLOCK, w // BLOCK, -1)
    A, B, V = blk(a), blk(b), blk(valid.astype(np.float32)).min(axis=2) > 0
    ma, mb = A.mean(2), B.mean(2)
    va, vb = A.var(2), B.var(2)
    cov = ((A - ma[..., None]) * (B - mb[..., None])).mean(2)
    c1, c2 = (0.01 * 255) ** 2, (0.03 * 255) ** 2
    s = ((2 * ma * mb + c1) * (2 * cov + c2)) / ((ma ** 2 + mb ** 2 + c1) * (va + vb + c2))
    return float(s[V].mean()) if V.any() else 1.0


def measure(apk_path, god_path, masks, chrome=(), probes=()):
    a, ag = load_grey(apk_path)
    g, gg = load_grey(god_path)
    note = ""
    if a.size != g.size:
        note = "taille %s -> rognage central" % (g.size,)
        a, g = usable_crop(a, g)
        ag, gg = np.asarray(a.convert("L"), dtype=np.float32), np.asarray(g.convert("L"), dtype=np.float32)
    valid = mask_array(ag.shape, masks)
    d = np.abs(ag - gg)
    n = valid.sum()
    mean = float(d[valid].sum() / n) if n else 0.0
    pct = float((d[valid] > 16).sum() * 100.0 / n) if n else 0.0
    cols, rows = GRID
    cells = np.zeros((rows, cols), dtype=np.float32)
    ys, xs = np.array_split(np.arange(ag.shape[0]), rows), np.array_split(np.arange(ag.shape[1]), cols)
    for r, yy in enumerate(ys):
        for c, xx in enumerate(xs):
            v = valid[yy[0]:yy[-1] + 1, xx[0]:xx[-1] + 1]
            dd = d[yy[0]:yy[-1] + 1, xx[0]:xx[-1] + 1]
            cells[r, c] = dd[v].mean() if v.any() else 0.0
    chrome_v = None
    if chrome:
        cm = np.zeros(ag.shape, dtype=bool)
        for x, y, w, h, *_ in chrome:
            cm[y:y + h, x:x + w] = True
        cm &= valid
        chrome_v = float(d[cm].mean()) if cm.any() else 0.0
    pr = []
    arr_a, arr_g = np.asarray(a.convert("RGB"), dtype=np.float32), np.asarray(g.convert("RGB"), dtype=np.float32)
    for x, y, w, h, name, tol in probes:
        dv = (arr_g[y:y + h, x:x + w].reshape(-1, 3).mean(0) - arr_a[y:y + h, x:x + w].reshape(-1, 3).mean(0))  # Godot - APK, par canal
        pr.append((name, float(np.abs(dv).max()), tol, dv.round(1).tolist()))
    return dict(mean=mean, pct=pct, cell=float(cells.max()), ssim=ssim_blocks(ag, gg, valid), cells=cells, a=a, g=g, d=d, valid=valid, note=note, chrome=chrome_v, probes=pr)


def write_png(path, res, masks, title):
    W, H = 960, 540
    a, g = res["a"].convert("RGB").resize((W, H)), res["g"].convert("RGB").resize((W, H))
    d = Image.fromarray(np.clip(res["d"] * 4, 0, 255).astype(np.uint8)).resize((W, H)).convert("RGB")
    heat = Image.new("RGB", (W, H), (0, 0, 0))
    hd = ImageDraw.Draw(heat)
    cols, rows = GRID
    cw, ch = W / cols, H / rows
    for r in range(rows):
        for c in range(cols):
            v = float(res["cells"][r, c])
            k = min(255, int(v * 255 / 30))  # 30/255 de moyenne = rouge plein
            hd.rectangle([c * cw, r * ch, (c + 1) * cw - 1, (r + 1) * ch - 1], fill=(k, max(0, 160 - k), 40))
            hd.text((c * cw + 4, r * ch + 4), "%.1f" % v, fill=(255, 255, 255))
    sx, sy = W / res["a"].size[0], H / res["a"].size[1]
    for im in (d, a, g):
        dr = ImageDraw.Draw(im, "RGBA")
        for m in masks:
            x, y, w, h = m[:4]
            dr.rectangle([x * sx, y * sy, (x + w) * sx, (y + h) * sy], fill=(255, 0, 255, 70), outline=(255, 0, 255, 200))
    out = Image.new("RGB", (W * 2, H * 2))
    out.paste(a, (0, 0)); out.paste(g, (W, 0)); out.paste(d, (0, H)); out.paste(heat, (W, H))
    ImageDraw.Draw(out).text((6, 4), title, fill=(255, 255, 0))
    out.save(path)


def run_capture():
    from godot_exe import godot_exe
    cmd = [godot_exe(), "--path", os.path.join(ROOT, "src", "frontend"), "--resolution", "1920x1080", "res://godot/tests/CaptureScreens.tscn"]
    print("capture :", " ".join(cmd))
    subprocess.run(cmd, timeout=3600, stdin=subprocess.DEVNULL)


def main():
    args = sys.argv[1:]
    check, no_png = "--check" in args, "--no-png" in args or "--check" in args
    only = next((a[7:] for a in args if a.startswith("--only=")), "")
    if "--capture" in args:
        run_capture()
    cfg = json.load(open(PAIRS, encoding="utf8"))
    kinds = cfg.get("kinds", {})
    god_dir = os.path.join(REF, next((a[12:] for a in args if a.startswith("--godot-dir=")), cfg.get("godot_dir", "godot_screens")))
    tag = next((a[6:] for a in args if a.startswith("--tag=")), "image_diff")
    rows, skipped, missing = [], [], []
    for p in cfg["pairs"]:
        if only and only not in p["apk"]:
            continue
        if not p.get("godot"):
            skipped.append(p)
            continue
        ap = os.path.join(REF, p["apk"])
        gp = os.path.join(god_dir, "godot_%s.png" % p["godot"])
        if not os.path.exists(gp) or not os.path.exists(ap):
            missing.append(p)
            continue
        kd = kinds.get(p.get("kind", ""), {})
        masks = kd.get("mask", []) + p.get("mask", [])  # masques du kind (contenu de partie) + masques propres a la paire
        res = measure(ap, gp, masks, kd.get("chrome", []), p.get("probes", []))
        lim = {**{k: v for k, v in kd.items() if k.startswith("max_")}, **{k: v for k, v in p.items() if k.startswith("max_")}}
        fails = [k for k, v in (("mean", lim.get("max_mean")), ("pct", lim.get("max_pct")), ("cell", lim.get("max_cell")), ("chrome", lim.get("max_chrome"))) if v is not None and (res[k] or 0.0) > v]
        fails += ["sonde:" + n for n, dv, tol, _ in res["probes"] if dv > tol]
        name = os.path.splitext(os.path.basename(p["apk"]))[0]
        rows.append(dict(p=p, res=res, lim=lim, fails=fails, name=name))
        if not no_png:
            os.makedirs(DIFF_DIR, exist_ok=True)
            write_png(os.path.join(DIFF_DIR, name + ".png"), res, masks,
                      "%s | %s | mean %.2f pct %.1f%% cell %.1f ssim %.3f" % (p["apk"], p["godot"], res["mean"], res["pct"], res["cell"], res["ssim"]))
    rows.sort(key=lambda r: -r["res"]["mean"])
    os.makedirs(OUT, exist_ok=True)
    with open(os.path.join(OUT, tag + ".csv"), "w", newline="", encoding="utf8") as f:
        w = csv.writer(f)
        w.writerow(["apk", "godot", "kind", "mean", "pct16", "worst_cell", "chrome", "ssim", "max_mean", "max_cell", "max_chrome", "probes", "fail"])
        for r in rows:
            q, l = r["res"], r["lim"]
            w.writerow([r["p"]["apk"], r["p"]["godot"], r["p"].get("kind", ""), "%.3f" % q["mean"], "%.2f" % q["pct"], "%.2f" % q["cell"], "" if q["chrome"] is None else "%.2f" % q["chrome"], "%.4f" % q["ssim"], l.get("max_mean", ""), l.get("max_cell", ""), l.get("max_chrome", ""), "; ".join("%s %s" % (n, dv) for n, _, _, dv in q["probes"]), " ".join(r["fails"])])
    n_apk = len(cfg["pairs"])
    md = ["# Ecart image APK / Godot (phase 5)", "",
          "%d frames APK : %d appariees (%d mesurees, %d capture manquante), %d non comparables." % (n_apk, len(rows) + len(missing), len(rows), len(missing), len(skipped)), "",
          "| # | frame APK | capture Godot | kind | moyenne | % > 16 | pire cellule | chrome | SSIM | seuil (moy/%/cell/chrome) | echec |", "|---|---|---|---|---:|---:|---:|---:|---:|---|---|"]
    for i, r in enumerate(rows, 1):
        q, l = r["res"], r["lim"]
        md.append("| %d | %s | %s | %s | %.2f | %.1f | %.1f | %s | %.3f | %s | %s |" % (i, r["p"]["apk"], r["p"]["godot"], r["p"].get("kind", ""), q["mean"], q["pct"], q["cell"],
                  "-" if q["chrome"] is None else "%.2f" % q["chrome"], q["ssim"], "/".join(str(l.get(k, "-")) for k in ("max_mean", "max_pct", "max_cell", "max_chrome")), " ".join(r["fails"]) or "ok"))
    if missing:
        md += ["", "## Captures Godot manquantes", ""] + ["- %s -> godot_%s.png" % (p["apk"], p["godot"]) for p in missing]
    reasons = {}
    for p in skipped:
        reasons.setdefault(p.get("reason", "?"), []).append(p["apk"])
    md += ["", "## Non comparables", ""]
    for k, v in sorted(reasons.items(), key=lambda kv: -len(kv[1])):
        md.append("- %d : %s" % (len(v), k))
    open(os.path.join(OUT, tag + ".md"), "w", encoding="utf8").write("\n".join(md) + "\n")
    if "--freeze" in args:  # plafond = ecart actuel + 20 % pour les kinds "freeze" (plateau, tutoriel : contenu de partie != APK) ; a abaisser a la main quand un ecart est corrige
        up = lambda v: math.ceil((v * 1.2 + 0.3) * 10) / 10
        for r in rows:
            p, q = r["p"], r["res"]
            if kinds.get(p.get("kind", ""), {}).get("freeze") and not any(k.startswith("max_") for k in p):
                p["max_mean"], p["max_cell"] = up(q["mean"]), up(q["cell"])
                if q["chrome"] is not None:
                    p["max_chrome"] = up(q["chrome"])
        json.dump(cfg, open(PAIRS, "w", encoding="utf8"), indent=1, ensure_ascii=False)
        print("plafonds ecrits dans", PAIRS)
    failing = [r for r in rows if r["fails"]]
    print("\n".join(md[:5]))
    for r in rows[:int(next((a[6:] for a in args if a.startswith('--top=')), 25))]:
        print("%6.2f %5.1f%% cell %5.1f chrome %5s ssim %.3f %-8s %s -> %s %s" % (r["res"]["mean"], r["res"]["pct"], r["res"]["cell"], "-" if r["res"]["chrome"] is None else "%.1f" % r["res"]["chrome"], r["res"]["ssim"], r["p"].get("kind", ""), r["name"], r["p"]["godot"], "FAIL " + ",".join(r["fails"]) if r["fails"] else ""))
    print("seuils depasses : %d / %d paires seuillees ; captures manquantes : %d" % (len(failing), sum(1 for r in rows if r["lim"]), len(missing)))
    if check:
        for r in failing:
            print("ECHEC", r["p"]["apk"], r["res"]["mean"], r["res"]["cell"], r["fails"])
        sys.exit(1 if failing or missing else 0)


if __name__ == "__main__":
    main()
