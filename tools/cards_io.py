"""Lecture/ecriture de src/frontend/godot/data/cards.json (source de verite des cartes) avec la mise en page du depot :
indent 2, UTF-8, `levelUp` des boss sur une seule ligne. Importe par merge_expansions / fetch_wiki_cards."""
import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CARDS = os.path.join(ROOT, "src", "frontend", "godot", "data", "cards.json")


def load_cards() -> dict:
    with open(CARDS, encoding="utf-8") as f:
        return json.load(f)


def dump_cards(data: dict) -> str:
    inline = {}
    shallow = {k: v for k, v in data.items()}
    for section, cards in data.items():
        if not isinstance(cards, list):
            continue
        out = []
        for c in cards:
            if isinstance(c, dict) and isinstance(c.get("levelUp"), dict):
                key = f"@@LU{len(inline)}@@"
                inline[key] = json.dumps(c["levelUp"], ensure_ascii=False)
                c = {**c, "levelUp": key}
            out.append(c)
        shallow[section] = out
    text = json.dumps(shallow, indent=2, ensure_ascii=False)
    for key, val in inline.items():
        text = text.replace(json.dumps(key), val)
    return text + "\n"


def save_cards(data: dict) -> None:
    with open(CARDS, "w", encoding="utf-8", newline="") as f:
        f.write(dump_cards(data))
