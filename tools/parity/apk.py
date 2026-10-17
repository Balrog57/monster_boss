#!/usr/bin/env python3
"""Parite Godot <-> APK ORIGINALE (oracle = DBMGame.dll 2.2.6 headless, tools/apk-oracle).

  python tools/parity/apk.py [--seeds 1 2 3] [--players 2 3] [--decks BaseDeck,PlayerChoice] [--skip-gen]

1. genere les traces oracle (seeds x joueurs) dans tools/parity/out/apk/ (ou $APK_PARITY_OUT)
2. Godot (ApkParity.tscn) rejoue chaque trace (aucune aide) et enregistre sa projection
   apres chaque step de l'oracle
3. ce script projette l'etat de l'oracle de la meme facon, compare aux points de
   controle (voir README.md) et ecrit <OUT>/report.json

Le harnais ne corrige aucune regle : il rapporte. Code de sortie 1 si une trace n'est pas OK.
"""
import argparse
import datetime
import json
import os
import re
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))
sys.path.insert(0, os.path.dirname(HERE))
from godot_exe import godot_exe  # noqa: E402

# APK_PARITY_OUT : dossier distinct par agent/run ; ne jamais lancer deux rejeux en parallele (un seul Godot a la fois).
OUT = os.path.abspath(os.environ["APK_PARITY_OUT"]) if os.environ.get("APK_PARITY_OUT") else os.path.join(HERE, "out", "apk")

# --- projection de l'oracle (miroir de ApkParityTrace.project) ---------------

PHASE = {
    "Setup_a": "setup", "Setup_b": "setup", "Setup_c": "setup",
    "BeginningOfTurn": "build", "BuildPhase_a": "build", "BuildPhase_b": "build", "ExtraBuildPhase": "build",
    "BaitPhase": "adventure", "AdventurePhase_a": "adventure", "AdventurePhase_b": "adventure", "AdventurePhase_c": "adventure",
    "EndOfTurnPhase": "end", "EndOfGame": "over",
}


def oracle_proj(step, trace):
    players = {}
    for p in step["players"]:
        slots = [s for s in p["dungeon"] if len(s["rooms"]) > 0]  # slot 0 = fond, comme Godot inverse
        players[str(p["playerId"])] = {
            "souls": p["souls"], "wounds": p["wounds"],
            "hand": sorted(c["card"] for c in p["hand"]),
            "spells": sorted(c["card"] for c in p["spells"]),
            "dungeon": [[r["card"] for r in s["rooms"]] for s in slots],
            "pending": [bool(s.get("pending")) for s in slots],
            "entrance": sorted(h["card"] for h in p["entrance"]),
        }
    dc = step["deckCounts"]
    hero = step.get("activeHero")
    return {
        "phase": PHASE[step["phase"]], "turn": step["turn"], "active": step.get("activePlayer"),
        "town": [h["card"] for h in step["heroesInTown"]],
        "hero": {"card": hero["card"], "hp": hero["hp"]} if hero else None,
        "winner": (trace.get("winner") or {}).get("playerId") if step["phase"] == "EndOfGame" else None,
        "decks": {k: dc.get(k) for k in ("heroes", "rooms", "spells", "discardRooms", "discardSpells", "items")},
        "players": players,
    }


# --- points de controle -------------------------------------------------------

DECKS = ["decks"]


def P(*f):
    return [f"players.*.{x}" for x in f]


KINDS = {
    "setup": ["phase", *DECKS, *P("hand", "spells")],
    "turnstart": ["phase", "turn", "town", *DECKS, *P("souls", "wounds", "hand", "spells", "dungeon", "entrance")],
    "build": ["phase", "turn", "active", *P("hand", "spells", "dungeon", "pending")],
    "bait": ["phase", "turn", "town", *DECKS, *P("souls", "wounds", "hand", "spells", "dungeon", "entrance")],
    "adv": ["phase", "hero", *P("souls", "wounds")],
    "over": ["phase", "winner", *P("souls", "wounds")],
}


def check_kind(steps, i):
    s = steps[i]
    d = s.get("detail") or {}
    if s["kind"] == "decision" and d.get("decision") == "discard" and s["phase"] == "Setup_a":
        later = any(n["kind"] == "decision" and (n.get("detail") or {}).get("decision") == "discard" and n["phase"] == "Setup_a"
                    for n in steps[i + 1:])
        return None if later else "setup"
    if s["kind"] != "phase":
        return None
    ph = s["phase"]
    if ph == "BeginningOfTurn":
        return "turnstart"
    if ph == "BuildPhase_a":
        return "build" if s.get("activePlayer") is not None else None
    return {"BaitPhase": "bait", "AdventurePhase_c": "adv", "EndOfGame": "over"}.get(ph)


def skip_fields(steps, i, kind):
    """Apres une fenetre de sorts, l'oracle repete le joueur actif alors que Godot a deja passe au suivant : `active` n'est plus comparable."""
    if kind != "build":
        return []
    ap = steps[i].get("activePlayer")
    for j in range(i - 1, -1, -1):
        if steps[j]["kind"] == "phase":
            break
        d = steps[j].get("detail") or {}
        if d.get("action") == "spellBattleReady" or (d.get("action") == "buildRoom" and d.get("player") == ap):
            return ["active"]
    return []


def _ordered(keys):
    """Ordre des cles d'un objet JS : entiers croissants d'abord, puis insertion (la « premiere divergence » en depend)."""
    ints = sorted((k for k in keys if k.isdigit()), key=int)
    return ints + [k for k in keys if not k.isdigit()]


def flatten(o, prefix="", out=None):
    out = {} if out is None else out
    if isinstance(o, dict):
        for k in _ordered(list(o)):
            flatten(o[k], f"{prefix}.{k}" if prefix else k, out)
    else:
        out[prefix] = o
    return out


def spec_re(spec):
    return re.compile("^" + spec.replace(".", r"\.").replace("*", "[^.]+") + r"(\.|$)")


def group(p):
    p = re.sub(r"^players\.[^.]+\.", "players.*.", p)
    return "decks" if re.match(r"^decks\..*", p) else p


def diff_proj(o, g, kind, skip=()):
    fo, fg = flatten(o), flatten(g)
    res = [spec_re(k) for k in KINDS[kind] if k not in skip]
    out = []
    for p, ov in fo.items():
        if not any(r.search(p) for r in res):
            continue
        gv = fg.get(p)
        if ov == gv:  # comparaison numerique (1 == 1.0), pas de chaines JSON
            continue
        out.append({"field": p, "group": group(p), "oracle": ov, "godot": gv})
    return out


# --- comparaison d'une trace ---------------------------------------------------

def compare_trace(trace, gd):
    steps = trace["steps"]
    checks, matched = 0, 0
    first_div = None
    first_by_field = {}
    for i, s in enumerate(steps):
        kind = check_kind(steps, i)
        if not kind:
            continue
        # turnstart/bait : Godot enchaine parfois plusieurs phases en un coup, on compare a sa photo prise au bon moment.
        g = gd["snaps"].get(f"{kind}:{s['turn']}") if kind in ("turnstart", "bait") else gd["proj"].get(str(s["seq"]))
        detail = s.get("detail") or {}
        hero = s.get("activeHero")
        # Godot enchaine parfois la fin du tour dans le meme coup (dernier heros blesse => joueur elimine) ou termine la partie : `phase` non comparable.
        ahead = ["phase"] if kind == "adv" and g and ((g.get("turn") or 0) > s["turn"] or g.get("phase") == "over") else []
        # Fin de construction + fenetre de sorts : rien de comparable a ce point (Godot a deja enchaine revelation, leurre et aventure).
        if kind == "build" and g and g.get("phase") != "build" and detail.get("executed") is False:
            continue
        # Heros tue par une capacite/un sort (hp <= 0) : Godot le retire tout de suite (Match._finish_hero_if_dead), l'oracle au NextStep suivant.
        pending_kill = ["hero", "players.*.souls", "players.*.wounds"] if kind == "adv" and hero and hero["hp"] <= 0 and g and not g.get("hero") else []
        if g:
            diffs = diff_proj(oracle_proj(s, trace), g, kind, [*skip_fields(steps, i, kind), *ahead, *pending_kill])
        else:
            diffs = [{"field": "(point non atteint par Godot)", "group": "-", "oracle": None, "godot": None}]
        checks += 1
        if not diffs:
            matched += 1
            continue
        d = diffs[0]
        rec = {"seq": s["seq"], "turn": s["turn"], "phase": s["phase"], "check": kind, "field": d["field"],
               "oracle": d["oracle"], "godot": d["godot"], "moreFields": len(diffs) - 1}
        first_div = first_div or rec
        for x in diffs:
            first_by_field.setdefault(x["group"], {"seq": s["seq"], "phase": s["phase"], "field": x["field"], "oracle": x["oracle"], "godot": x["godot"]})
    refus = [e for e in gd["events"] if e["type"] == "REFUS"]
    first_refus = refus[0] if refus else None
    cands = [c for c in (first_refus and ("REFUS", first_refus["seq"]), first_div and ("DIVERGE", first_div["seq"])) if c]
    first = min(cands, key=lambda c: c[1]) if cands else None
    return {
        "status": f"{first[0]}@{first[1]}" if first else "OK",
        "firstRefus": first_refus, "firstDivergence": first_div, "firstByField": first_by_field,
        "refusCount": len(refus), "checks": checks, "matched": matched,
        "notes": len([e for e in gd["events"] if e["type"] != "REFUS"]),
        "stats": gd.get("stats"),
    }


# --- orchestration --------------------------------------------------------------

def generate(seeds, players, decks):
    os.makedirs(OUT, exist_ok=True)
    for f in os.listdir(OUT):
        if re.match(r"^(oracle|gd-).*\.json$|^report\.json$", f):
            os.unlink(os.path.join(OUT, f))
    names = []
    for seed in seeds:
        for n in players:
            name = f"oracle-s{seed}-p{n}.json"
            r = subprocess.run(["dotnet", "run", "--project", "tools/apk-oracle", "-v", "q", "--", "--seed", str(seed), "--players", str(n),
                                "--decks", decks, "--out", os.path.join(OUT, name)],
                               cwd=REPO, capture_output=True, text=True, encoding="utf-8", errors="replace", stdin=subprocess.DEVNULL)
            out = (r.stdout + r.stderr).strip()
            if not os.path.exists(os.path.join(OUT, name)):
                sys.exit(f"[apk-parity] oracle {name} ECHEC\n{out}")
            print(f"[apk-parity] {out.splitlines()[-1] if out else ''}", flush=True)
            names.append(name)
    return names


def run_godot():
    exe = godot_exe()
    p = subprocess.Popen([exe, "--headless", "--path", os.path.join(REPO, "src", "frontend"), "res://godot/tests/ApkParity.tscn", "--",
                          "--traces=" + OUT.replace("\\", "/")],
                         stdout=subprocess.PIPE, stderr=subprocess.STDOUT, stdin=subprocess.DEVNULL)
    try:
        raw, _ = p.communicate(timeout=900)
    except subprocess.TimeoutExpired:
        if os.name == "nt":
            subprocess.run(["taskkill", "/F", "/T", "/PID", str(p.pid)], capture_output=True)
        else:
            p.kill()
        raw, _ = p.communicate()
    out = raw.decode("utf-8", errors="replace")
    lines = out.splitlines()
    if "APK PARITY OK" not in out:
        print("[apk-parity] le rejeu Godot a echoue :", file=sys.stderr)
        print("\n".join([l for l in lines if re.search(r"ERROR|SCRIPT|FAIL", l)][:20]) or out[-2000:], file=sys.stderr)
        sys.exit(1)
    return [l for l in lines if re.search(r"SCRIPT ERROR|^ERROR|Parse Error", l)]


def fmt(v):
    s = json.dumps(v, separators=(",", ":"), ensure_ascii=False)
    return s[:67] + "..." if len(s) > 70 else s


def load(path):
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--seeds", type=int, nargs="+", default=[1, 2, 3])
    ap.add_argument("--players", type=int, nargs="+", default=[2, 3])
    ap.add_argument("--decks", default="BaseDeck")
    ap.add_argument("--skip-gen", action="store_true")
    a = ap.parse_args()
    if a.skip_gen:
        names = sorted(f for f in os.listdir(OUT) if re.match(r"^oracle-.*\.json$", f))
    else:
        names = generate(a.seeds, a.players, a.decks)

    godot_errors = run_godot()
    traces, unmapped = [], set()
    for name in names:
        trace = load(os.path.join(OUT, name))
        tid = re.sub(r"^oracle-", "", name)
        entry = {"trace": re.sub(r"^oracle-|\.json$", "", name), "seed": trace["meta"]["seed"], "players": trace["meta"]["players"],
                 "oracleSteps": len(trace["steps"]), "oracleResult": trace.get("result"), "oracleTurns": trace.get("turns")}
        gd = load(os.path.join(OUT, f"gd-{tid}"))
        unmapped.update(gd.get("unmapped", []))
        entry.update(compare_trace(trace, gd))
        traces.append(entry)

    report = {"generatedAt": datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%S.000Z"), "godot": godot_exe(),
              "godotScriptErrors": len(godot_errors), "unmappedCards": sorted(unmapped), "traces": traces}
    with open(os.path.join(OUT, "report.json"), "w", encoding="utf-8") as f:
        json.dump(report, f, indent=2, ensure_ascii=False)

    print()
    print(f"[apk-parity] cartes non mappees: {', '.join(report['unmappedCards']) or 'aucune'}   erreurs de script Godot: {len(godot_errors)}")
    print()
    print("trace      checks ok/total  refus  statut         premiere divergence d'etat")
    for r in traces:
        d = r["firstDivergence"]
        print(f"{r['trace']:<10} {r['matched']:>5}/{r['checks']:<5}   {r['refusCount']:>5}  {r['status']:<13}  "
              + (f"seq {d['seq']} {d['phase']} {d['field']} oracle={fmt(d['oracle'])} godot={fmt(d['godot'])}" if d else "-"))
        f = r["firstRefus"]
        if f:
            print(f"           premier REFUS: seq {f['seq']} {f['phase']} P{f['player']} {f['move']} ({f['reason']}; godot phase={f['godotPhase']} actif=P{f['godotActive']} legal=[{','.join(map(str, f['legal']))}])")
    print()
    print("== premiere divergence par groupe de champs (trace@seq) : classe les causes, au-dela de la toute premiere")
    groups = {}
    for t in traces:
        for g, v in t["firstByField"].items():
            groups.setdefault(g, []).append(f"{t['trace']}@{v['seq']}")
    for g, v in sorted(groups.items(), key=lambda kv: -len(kv[1])):
        print(f"  {g:<22} {len(v)}/{len(traces)}  {' '.join(v)}")
    print()
    print(f"[apk-parity] rapport: {os.path.join(OUT, 'report.json')}")
    bad = [t["trace"] for t in traces if t["status"] != "OK"]
    print(f"APK PARITY RAPPORT: {len(traces) - len(bad)}/{len(traces)} traces OK" + (f" (hors OK: {', '.join(bad)})" if bad else ""))
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
