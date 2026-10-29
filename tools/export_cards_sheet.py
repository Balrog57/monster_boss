"""Exporte src/frontend/godot/data/cards.json en classeur Excel : une feuille par type de carte, une ligne par carte.
Usage : python tools/export_cards_sheet.py [sortie.xlsx]   (defaut : docs/cartes.xlsx ; necessite openpyxl)"""
import json
import os
import sys
from collections import Counter

from openpyxl import Workbook
from openpyxl.styles import Font, PatternFill
from openpyxl.utils import get_column_letter

from cards_io import ROOT, load_cards
from generate_placeholder_art import is_placeholder

SHEETS = [("bosses", "Boss"), ("rooms", "Salles"), ("spells", "Sorts"), ("heroes", "Héros"),
          ("items", "Objets"), ("minibosses", "Minibosses")]
FIRST = ["id", "name", "subtitle", "set", "quantity", "implemented"]
NEW = ["source", "jouable_apk", "visuel", "fichier_visuel", "statut", "motif_exclusion"]
ASSETS = os.path.join(ROOT, "src", "frontend", "assets")
MANIFEST = os.path.join(ROOT, "tools", "data", "apkCardManifest.json")
_FACES = None  # faces du manifeste APK, chargees a la demande par card_extras
_FILL = {"Exclu": "FDE2E2", "Inclus": "E2F3E2", "provisoire": "FFE9CC", "manquant": "FFE9CC"}

# set -> (extension, origine, livret/regles, audit, statut, motif)
ORACLE = "oracle .NET de l'APK (6/6, 12/12)"
GOLDENS = "goldens seulement, pas d'audit carte par carte"
SETS = {
    "base": ("Jeu de base (BMA)", "APK", "docs/rules/rules_base.pdf + FAQ avancée", ORACLE, "Inclus", ""),
    "players-choice": ("The Player's Choice (APK, 11 KSA)", "APK", "FAQ avancée", ORACLE, "Inclus", ""),
    "hidden-heroes": ("Hidden Heroes (BMH)", "APK", "FAQ avancée", ORACLE, "Inclus", ""),  # débloqué d'emblée, boutique retirée
    "tools": ("Tools of Hero-Kind (THK)", "APK (cartes inertes)", "aucun livret : FAQ + guide non officiel", GOLDENS, "Exclu",
              "Inerte dans l'APK (COMING SOON) ; règles sans livret officiel ; pas d'audit carte par carte. Reste catalogué, non jouable comme dans l'APK."),
    "crash-landing": ("Crash Landing (CRL)", "Wiki", "docs/rules/rules_crash_landing.pdf", "audit carte par carte 33/33 + corrections (AUDIT.md)", "Inclus", ""),
    "next-level": ("Boss Monster 2 / The Next Level (TNL)", "Wiki", "docs/rules/rules_next_level.pdf", "audit carte par carte 115/115 + corrections", "Inclus", ""),
    "minibosses": ("Rise of the Minibosses (RMB)", "Wiki", "docs/rules/rules_minibosses.pdf", "audit carte par carte 121/121 ; 1 carte sans règle (Luz)", "Exclu",
                   "Visuels provisoires pour 107 cartes sur 121 ; Luz (RMB083) sans règle déterministe."),
    "iod": ("Implements of Destruction (IOD)", "Wiki", "aucun livret officiel (guide non officiel)", GOLDENS, "Exclu",
            "Pas de livret officiel ; visuel provisoire pour IOD023 ; pas d'audit carte par carte."),
    "players-choice-wiki": ("The Player's Choice, 6 cartes KSA hors APK", "Wiki", "FAQ avancée (4 cartes)", GOLDENS, "Exclu",
                            "Pas de livret ; pas d'audit carte par carte."),
}


def card_extras(c, section, data):
    """Colonnes NEW d'une carte : source, jouabilite APK, etat du visuel, fichier, statut d'extension."""
    global _FACES
    if _FACES is None:
        with open(MANIFEST, encoding="utf-8") as f:
            _FACES = json.load(f).get("faces", {})
    faces, name_map = _FACES, data.get("nameMap", {})
    cid, setk = c["id"], c.get("set") or "base"
    if setk not in SETS:
        raise ValueError(f"set inconnu dans cards.json : {setk!r} (carte {cid}) ; l'ajouter à SETS")
    statut, motif = SETS[setk][4:]
    stem = cid.lower()
    face = stem if stem in faces else stem + "a" if stem + "a" in faces else None
    if face:
        source, visuel, rel = "APK", "APK", "apk_cards/" + faces[face]
        jouable = "non" if setk == "tools" else "oui"
    else:
        d = "epic-heroes" if section == "heroes" and c.get("epic") else section
        rel = f"cards/{d}/{cid}_{name_map.get(cid, stem)}.webp"
        path = os.path.join(ASSETS, rel)
        source, jouable = "Wiki", "n/a"
        visuel = "manquant" if not os.path.exists(path) else "provisoire" if is_placeholder(path) else "réel"
    return dict(zip(NEW, [source, jouable, visuel, rel, statut, motif]))


def cell(v):
    if isinstance(v, bool):
        return "oui" if v else "non"
    if isinstance(v, list):
        if all(isinstance(x, dict) and "level" in x for x in v):
            return "\n".join(f"Niv. {x['level']} : {x.get('description', '')}" for x in v)
        return ", ".join(str(x) for x in v)
    if isinstance(v, dict):
        return json.dumps(v, ensure_ascii=False)
    return v


def write_sheet(ws, cards):
    seen = Counter(k for c in cards for k in c)
    cols = [k for k in FIRST if k in seen] + NEW + sorted(k for k in seen if k not in FIRST and k not in NEW)
    ws.append(cols)
    for c in cards:
        ws.append([cell(c.get(k)) for k in cols])
    for cell_ in ws[1]:
        cell_.font = Font(bold=True, color="FFFFFF")
        cell_.fill = PatternFill("solid", fgColor="4F2A2A")
    for i, k in enumerate(cols, 1):
        width = max(len(str(r[i - 1].value or "")) for r in ws.iter_rows(min_row=1))
        ws.column_dimensions[get_column_letter(i)].width = min(max(width + 2, 8), 70)
    for k in ("statut", "visuel"):
        for row in ws.iter_rows(min_row=2, min_col=cols.index(k) + 1, max_col=cols.index(k) + 1):
            if row[0].value in _FILL:
                row[0].fill = PatternFill("solid", fgColor=_FILL[row[0].value])
    ws.freeze_panes = "C2"
    ws.auto_filter.ref = ws.dimensions


def main():
    data = load_cards()
    out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, "docs", "cartes.xlsx")
    wb = Workbook()
    summary = wb.active
    summary.title = "Résumé"
    summary.append(["Type", "Cartes distinctes", "Exemplaires (quantity)", "Implémentées", "Incluses", "Exclues"])
    stats = {k: Counter() for k in SETS}  # set -> compteurs cartes / visuels
    for key, title in SHEETS:
        cards = [{**c, **card_extras(c, key, data)} for c in data[key]]
        for c in cards:
            st = stats[c.get("set") or "base"]
            st["cartes"] += 1
            st["réel" if c["visuel"] in ("APK", "réel") else c["visuel"]] += 1
        summary.append([title, len(cards), sum(c.get("quantity", 1) for c in cards),
                        sum(1 for c in cards if c.get("implemented")),
                        sum(1 for c in cards if c["statut"] == "Inclus"), sum(1 for c in cards if c["statut"] == "Exclu")])
        write_sheet(wb.create_sheet(title), cards)
    summary.append(["Total", *(f"=SUM({get_column_letter(i)}2:{get_column_letter(i)}{len(SHEETS) + 1})" for i in range(2, 7))])
    for c in summary[1]:
        c.font = Font(bold=True)
    for c in summary[summary.max_row]:
        c.font = Font(bold=True)
    for i in range(1, 7):
        summary.column_dimensions[get_column_letter(i)].width = 24
    ext = wb.create_sheet("Extensions")
    ext.append(["set", "extension", "origine", "livret/règles", "audit", "cartes", "visuels réels",
                "visuels provisoires", "visuels manquants", "statut", "motif"])
    for k, (label, origine, livret, audit, statut, motif) in SETS.items():
        st = stats[k]
        ext.append([k, label, origine, livret, audit, st["cartes"], st["réel"], st["provisoire"], st["manquant"], statut, motif])
    last = ext.max_row
    ext.append(["Total", *[""] * 4, *(f"=SUM({get_column_letter(i)}2:{get_column_letter(i)}{last})" for i in range(6, 10))])
    for c in ext[1]:
        c.font = Font(bold=True, color="FFFFFF")
        c.fill = PatternFill("solid", fgColor="4F2A2A")
    for c in ext[ext.max_row]:
        c.font = Font(bold=True)
    for row in ext.iter_rows(min_row=2, max_row=last, min_col=10, max_col=10):
        row[0].fill = PatternFill("solid", fgColor=_FILL[row[0].value])
    for i in range(1, 12):
        ext.column_dimensions[get_column_letter(i)].width = min(max(max(len(str(r[i - 1].value or "")) for r in ext.iter_rows()) + 2, 8), 70)
    ext.freeze_panes = "C2"
    ext.auto_filter.ref = f"A1:K{last}"
    wb.save(out)
    print(out)


if __name__ == "__main__":
    main()
