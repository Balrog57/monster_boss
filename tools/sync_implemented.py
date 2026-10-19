#!/usr/bin/env python3
"""Recalcule le drapeau `implemented` de chaque carte de src/frontend/godot/data/cards.json d'apres le code reel du moteur.

Une carte est « implementee » quand :
  - salle / sort : son id apparait entre guillemets dans un script du moteur, ou son texte ne porte aucune capacite (vide ou « (rappel) ») ;
  - boss        : son id, ou la commande de son level-up (`levelUp.cmd`), apparait dans le moteur ;
  - heros       : sa capacite (`heroAbility.cmd`) et sa condition de leurre (`lure`) apparaissent dans le moteur (un heros sans capacite l'est d'office) ;
  - miniboss    : son id apparait dans le moteur ;
  - objet (Tools of Hero Kind) : son id apparait dans le moteur (ThkAbilities ; l'APK ne les joue pas : elles ne se jouent que derriere la case wiki).

La meme regle est rejouee par src/frontend/godot/tests/coverage.gd (ECHEC si un drapeau ment) : lancer ce script apres toute carte ajoutee ou implementee.
Usage : python tools/sync_implemented.py [--check]   (--check : n'ecrit rien, sort 1 si cards.json n'est pas a jour)
"""
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GODOT = os.path.join(ROOT, "src", "frontend", "godot")
CARDS = os.path.join(GODOT, "data", "cards.json")
# Scripts qui portent les regles (pas l'IA, l'interface, les traces de parite ni les tests : un id cite par l'IA n'implemente rien). CardDB: Jarin (passive_souls).
ENGINE = ["Match", "BossEngine", "RoomAbilities", "SpellEffects", "SpellTargeting", "TnlAbilities", "TnlSpells",
          "RmbAbilities", "RmbSpells", "Minibosses", "ThkAbilities", "IodAbilities", "PcwAbilities", "CardDB"]
SECTIONS = ["bosses", "rooms", "spells", "heroes", "items", "minibosses"]


def engine_words():
    src = ""
    for name in ENGINE:
        with open(os.path.join(GODOT, "scripts", name + ".gd"), encoding="utf-8") as f:
            src += f.read() + "\n"
    return set(re.findall(r'"([A-Za-z0-9]+)"', src))


def text_of(card):
    return card.get("description") or card.get("levelUpDesc") or ""


def is_implemented(section, card, words):
    cid = card["id"]
    if section == "items":
        return cid in words
    if section == "minibosses":
        return cid in words
    if section == "heroes":
        cmd = (card.get("heroAbility") or {}).get("cmd")
        lure = card.get("lure")
        return (cmd is None or cmd in words) and (lure is None or lure in words or lure == "treasures")
    if section == "bosses":
        lu = card.get("levelUp")
        cmd = lu.get("cmd") if isinstance(lu, dict) else None
        return cid in words or (cmd is not None and cmd in words)
    t = text_of(card).strip()
    reminder = t == "" or (t.startswith("(") and t.endswith(")"))
    return cid in words or reminder


def census(data, words):
    return {c["id"]: is_implemented(s, c, words) for s in SECTIONS for c in data.get(s, [])}


def rewrite(raw, flags):
    """Remplace / ajoute la ligne `"implemented"` dans chaque carte, sans toucher au reste de la mise en page."""
    lines = raw.split("\n")
    out = []
    i = 0
    changed = 0
    while i < len(lines):
        if lines[i] == "    {":
            j = i
            while not lines[j].startswith("    }"):
                j += 1
            block = lines[i:j]
            m = next((re.match(r'      "id": "([^"]+)"', l) for l in block if re.match(r'      "id": "([^"]+)"', l)), None)
            if m and m.group(1) in flags:
                block = [l for l in block if not l.startswith('      "implemented"')]
                if not block[-1].endswith(","):
                    block[-1] += ","
                block.append('      "implemented": %s' % ("true" if flags[m.group(1)] else "false"))
                if block != lines[i:j]:
                    changed += 1
            out.extend(block)
            out.append(lines[j])
            i = j + 1
        else:
            out.append(lines[i])
            i += 1
    return "\n".join(out), changed


def main():
    with open(CARDS, encoding="utf-8", newline="") as f:
        raw = f.read()
    crlf = "\r\n" in raw  # checkout Windows (autocrlf) : rewrite() lit des lignes finies par un seul LF
    raw = raw.replace("\r\n", "\n")
    data = json.loads(raw)
    flags = census(data, engine_words())
    new_raw, changed = rewrite(raw, flags)
    json.loads(new_raw)  # garde-fou : le fichier reste du JSON valide
    todo = [(s, c["id"], c["name"]) for s in SECTIONS for c in data[s] if not flags[c["id"]]]
    print("cartes: %d, implementees: %d, sans implementation: %d" % (len(flags), sum(flags.values()), len(todo)))
    for s, cid, name in todo:
        print("  sans implementation: %s %s (%s)" % (cid, name, s))
    if "--check" in sys.argv:
        print("cards.json a jour" if new_raw == raw else "cards.json PAS a jour (%d cartes)" % changed)
        sys.exit(0 if new_raw == raw else 1)
    if new_raw != raw:
        with open(CARDS, "w", encoding="utf-8", newline="") as f:
            f.write(new_raw.replace("\n", "\r\n") if crlf else new_raw)
        print("cards.json mis a jour (%d cartes)" % changed)


if __name__ == "__main__":
    main()
