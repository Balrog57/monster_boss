#!/usr/bin/env python3
"""Parite Godot <-> APK ORIGINALE (oracle = DBMGame.dll 2.2.6 headless, tools/apk-oracle).

  python tools/parity/apk.py [--seeds 1 2 3] [--players 2 3] [--decks BaseDeck,PlayerChoice] [--skip-gen] [--ai-agreement]
  python tools/parity/apk.py --tutorial [--waves 1 2 3] [--tut-turns 4] [--ai-agreement]   # tutoriel de l'APK (lot L8), voir tutorial_main

1. genere les traces oracle (seeds x joueurs) dans tools/parity/out/apk/ (ou $APK_PARITY_OUT)
2. Godot (ApkParity.tscn) rejoue chaque trace (aucune aide) et enregistre sa projection
   apres chaque step de l'oracle
3. ce script projette l'etat de l'oracle de la meme facon, compare aux points de
   controle (voir README.md) et ecrit <OUT>/report.json

Le harnais ne corrige aucune regle : il rapporte. Code de sortie 1 si une trace n'est pas OK (ou, avec --ai-agreement, si `usableSet` a un ecart).

--ai-agreement (lot 1.2) : le rejeu Godot demande en plus a l'IA Godot (AI.gd) ce qu'elle jouerait sur le meme etat, a chaque decision de l'IA
oracle, et compte l'accord par type de coup (report.json : `aiAgreement` global et par trace ; tableau console). Aucun effet sur le rejeu.
Sorts et capacites de salle : l'oracle tire au hasard parmi ses capacites eligibles (cle `abilityChoices` de la trace) ; on compare les ensembles
(`usableSet`, `eligibleSet:*`, `chosenInSet:*`) et les cibles preregles (`spellTarget`, `activateTarget`, `...Shuffle` pour les cibles tirees au hasard).
Cibles des declencheurs et des commandes (choix ouverts par le moteur) : `target` (deterministe), `targetShuffle` (tirage `Shuffle()`), `targetPass` (abstention).
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

# Classes `skippedBy` connues (mesurees sur defaut + wide + decks, voir README « Decisions oracle ignorees »). Toute autre classe, ou
# `openingDiscardMismatch` / `spellTargetUnmatched` > 0, fait echouer la trace (statut SKIP).
KNOWN_SKIP = {
    "implicitTargetNoOption:resolveTarget:t1",
    "implicitTargetNoOption:resolveTarget:t2",
    "noChoice-dropped:resolveTarget:t1",
    "noChoice-dropped:resolveTarget:t2",
    "noChoice-dropped:resolveTarget:t3",
    "noChoice-late:resolveTarget:t1",
    "noChoice-late:resolveTarget:t2",
    "otherCardChoice:resolveTarget:t2",
    "otherPlayer-deferred:discard",
    "otherPlayer-deferred:resolveTarget:t1",
    "otherPlayer-deferred:resolveTarget:t2",
    "otherPlayer-late:resolveTarget:t1",
    "otherPlayer-late:resolveTarget:t2",
}
FORBIDDEN_SKIP_SITES = ("openingDiscardMismatch",)
# `otherCardChoice:resolveTarget:t2` est connu (cibles BossOwner, benignes) ; `otherCardChoice:resolveTarget:t1` (BMA011/BMA036/BMA037 interactifs)
# reste signale (skipWarnings) sans faire echouer, en attendant une decision. Exemption PAR CLE : une autre cle `otherCardChoice:*` fait echouer.
WARN_SKIP_KEYS = ("otherCardChoice:resolveTarget:t1",)


def skip_issues(gd):
    st = gd.get("stats") or {}
    out = [f"classe inconnue {k} (n={c['n']})" for k, c in (st.get("skippedBy") or {}).items()
           if k not in WARN_SKIP_KEYS and (k not in KNOWN_SKIP or k.split(":")[0] in FORBIDDEN_SKIP_SITES)]
    if st.get("spellTargetUnmatched"):
        out.append(f"spellTargetUnmatched={st['spellTargetUnmatched']}")
    return out


def skip_warnings(gd):
    return [f"{k} n={c['n']}" for k, c in ((gd.get("stats") or {}).get("skippedBy") or {}).items() if k in WARN_SKIP_KEYS]


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
    issues = skip_issues(gd)
    cands = [c for c in (first_refus and ("REFUS", first_refus["seq"]), first_div and ("DIVERGE", first_div["seq"])) if c]
    first = min(cands, key=lambda c: c[1]) if cands else None
    return {
        "status": f"{first[0]}@{first[1]}" if first else ("SKIP" if issues else "OK"), "skipIssues": issues, "skipWarnings": skip_warnings(gd),
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


def run_godot(ai=False):
    exe = godot_exe()
    p = subprocess.Popen([exe, "--headless", "--path", os.path.join(REPO, "src", "frontend"), "res://godot/tests/ApkParity.tscn", "--",
                          "--traces=" + OUT.replace("\\", "/"), *(["--ai-agreement"] if ai else [])],
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


# --- parite d'initialisation (R-D15 / T-A07) : meme graine, memes pioches, memes mains, memes boss ----------------

def run_init_parity():
    p = subprocess.Popen([godot_exe(), "--headless", "--path", os.path.join(REPO, "src", "frontend"), "res://godot/tests/InitParity.tscn", "--",
                          "--traces=" + OUT.replace("\\", "/")], stdout=subprocess.PIPE, stderr=subprocess.STDOUT, stdin=subprocess.DEVNULL)
    try:
        raw, _ = p.communicate(timeout=600)
    except subprocess.TimeoutExpired:
        if os.name == "nt":
            subprocess.run(["taskkill", "/F", "/T", "/PID", str(p.pid)], capture_output=True)
        else:
            p.kill()
        raw, _ = p.communicate()
    out = raw.decode("utf-8", errors="replace")
    if "INIT PARITY OK" not in out:
        print("[apk-parity] la parite d'initialisation Godot a echoue :", file=sys.stderr)
        print("\n".join([l for l in out.splitlines() if re.search(r"ERROR|SCRIPT|FAIL", l)][:20]) or out[-2000:], file=sys.stderr)
        sys.exit(1)


def compare_init(trace, gi):
    """Compare l'initialisation de l'oracle (`initial`, mains d'ouverture avant defausse, `deckOrders` apres distribution) a celle de Godot (meme graine)."""
    ini = trace["initial"]
    diffs = []

    def chk(field, oracle, godot):
        if oracle != godot:
            diffs.append(field)
            return False
        return True

    chk("bosses", [b["card"] for b in ini["bosses"]], gi["bosses"])
    chk("rank", [b["playerId"] for b in ini["bosses"]], gi["rank"])
    spell_cards = {c[0] for c in gi["pre"]["spells"]} | {c[0] for h in gi["hands"] for c in h if c[2]}
    discards = [st for st in trace["steps"] if st["kind"] == "decision" and st["detail"].get("decision") == "discard" and st["phase"] == "Setup_a"]
    opt_rooms = [o["id"] for st in discards for o in st["detail"]["options"] if o["card"] not in spell_cards]
    opt_spells = [o["id"] for st in discards for o in st["detail"]["options"] if o["card"] in spell_cards]
    # UniqueID : l'APK numerote heros, salles puis sorts d'une suite, Godot repart de 1 pour chaque categorie (meme ordre dans le paquet avant melange)
    off = {"rooms": min([c["id"] for c in ini["deckRooms"]] + opt_rooms) - 1 if ini["deckRooms"] or opt_rooms else 0,
           "spells": min([c["id"] for c in ini["deckSpells"]] + opt_spells) - 1 if ini["deckSpells"] or opt_spells else 0}

    def norm(c, kind):  # carte oracle -> [carte, uid Godot]
        return [c["card"], c["id"] - off[kind] if kind in off else 0]

    def g_norm(arr, kind):
        return [[c[0], c[1] if kind in off else 0] for c in arr]

    for k, name in (("heroes", "deckHeroes"), ("rooms", "deckRooms"), ("spells", "deckSpells"), ("items", "deckItems")):
        chk("pre." + k, [norm(c, k) for c in ini[name]], g_norm(gi["pre"][k], k))
    # mains d'ouverture avant defausse, par PlayerId (rang d'XP)
    ohands = {}
    for st in trace["steps"]:
        if st["kind"] == "decision" and st["detail"].get("decision") == "discard" and st["phase"] == "Setup_a":
            ohands[st["detail"]["player"]] = sorted((o["card"], o["id"] - off["spells" if o["card"] in spell_cards else "rooms"]) for o in st["detail"]["options"])
    ghands = {gi["rank"][i]: sorted((c[0], c[1]) for c in h) for i, h in enumerate(gi["hands"])}
    chk("hands", ohands, ghands)
    post = next((st["deckOrders"] for st in trace["steps"] if "deckOrders" in st), None)
    if post is not None:
        for k in ("heroes", "rooms", "spells", "items"):
            chk("post." + k, [norm(c, k) for c in post[k]], g_norm(gi["post"][k], k))
    # mulligan : la pioche de salles apres distribution n'est pas la queue de la pioche d'avant
    n = trace["meta"]["players"]
    mull = post is not None and [c["id"] for c in post["rooms"]] != [c["id"] for c in ini["deckRooms"]][5 * n:]
    return {"trace": re.sub(r"^oracle-|\.json$", "", trace.get("_name", "")), "ok": not diffs, "diffs": diffs, "mulligan": mull}


def aggregate_skipped(traces):
    """Somme `stats.skippedBy` de toutes les traces : classe -> {n, distinct, traces, cards, ex} (diagnostic, aucun seuil)."""
    agg = {}
    for t in traces:
        for key, c in ((t.get("stats") or {}).get("skippedBy") or {}).items():
            a = agg.setdefault(key, {"n": 0, "distinct": 0, "replayed": 0, "traces": {}, "cards": {}, "ex": []})
            a["n"] += c["n"]
            a["distinct"] += c["distinct"]
            a["replayed"] += c.get("replayed", 0)
            a["traces"][t["trace"]] = c["n"]
            for card, k in c["cards"].items():
                a["cards"][card] = a["cards"].get(card, 0) + k
            a["ex"] += [{"trace": t["trace"], **e} for e in c["ex"]][: max(0, 3 - len(a["ex"]))]
    return dict(sorted(agg.items(), key=lambda kv: -kv[1]["n"]))


AI_ORDER = ["build", "buildCard", "buildSlot", "discard", "usableSet", "eligibleSet:spell", "eligibleSet:activate", "eligibleSet:pass", "chosenInSet:spell", "chosenInSet:activate",
            "spellTarget", "spellTargetShuffle", "activateTarget", "activateTargetShuffle", "target", "targetShuffle", "targetPass", "draw", "pass"]
AI_FIELDS = ("n", "agree", "forced", "nt", "ntAgree", "ties")


def pct(a, n):
    return round(100.0 * a / n, 1) if n else None


def aggregate_ai(traces):
    """Somme `aiAgreement` des traces : types (n, agree, forced, nt, ntAgree, ties, pct, ntPct, ex), by (n, agree, pct), unavailable, mutations."""
    types, by, unav, mut = {}, {}, {}, 0
    for t in traces:
        a = t.get("aiAgreement")
        if not a:
            continue
        mut += a.get("mutations", 0)
        for k, v in a["unavailable"].items():
            unav[k] = unav.get(k, 0) + v
        for k, v in a["by"].items():
            b = by.setdefault(k, {"n": 0, "agree": 0})
            b["n"] += v["n"]
            b["agree"] += v["agree"]
        for k, v in a["types"].items():
            g = types.setdefault(k, {**{f: 0 for f in AI_FIELDS}, "ex": []})
            for f in AI_FIELDS:
                g[f] += v[f]
            g["ex"] += [{"trace": t["trace"], **e} for e in v["ex"][:2]]
    for g in types.values():
        g["pct"], g["ntPct"] = pct(g["agree"], g["n"]), pct(g["ntAgree"], g["nt"])
        g["ex"] = g["ex"][:12]
    for b in by.values():
        b["pct"] = pct(b["agree"], b["n"])
    empty = {**{f: 0 for f in AI_FIELDS}, "ex": [], "pct": None, "ntPct": None}
    return {"types": {k: types.get(k, empty) for k in AI_ORDER}, "by": dict(sorted(by.items())), "unavailable": unav, "mutations": mut}


def print_ai(ag, traces):
    print()
    print("== accord de l'IA Godot (AI.gd) avec l'IA oracle : coup Godot sur l'etat Godot juste avant le coup oracle (definitions : README « Accord de l'IA »)")
    print(f"  {'type':<22} {'n':>5} {'accord':>6} {'%':>6}   {'forces':>6}   {'n>=2 cand.':>10} {'accord':>6} {'%':>6}   {'indiff.':>7}")
    for k, g in ag["types"].items():
        f = lambda v: "-" if v is None else f"{v:.1f}"
        print(f"  {k:<22} {g['n']:>5} {g['agree']:>6} {f(g['pct']):>6}   {g['forced']:>6}   {g['nt']:>10} {g['ntAgree']:>6} {f(g['ntPct']):>6}   {g['ties']:>7}")
    print(f"  mutations de l'etat Godot par les requetes IA : {ag['mutations']} (doit etre 0) ; requetes sans coup disponible : {ag['unavailable'] or 'aucune'}")
    worst = sorted((kv for kv in ag["by"].items() if not kv[0].startswith("passAlt") and kv[1]["n"] - kv[1]["agree"] > 0), key=lambda kv: kv[1]["agree"] - kv[1]["n"])[:12]
    print("  desaccords par sous-classe (type:carte|choix, desaccords/n) : " + "  ".join(f"{k}={v['n'] - v['agree']}/{v['n']}" for k, v in worst))
    us = sorted(((k, v["n"]) for k, v in ag["by"].items() if k.startswith("usableSet-")), key=lambda kv: -kv[1])
    print("  usableSet, ecarts par carte et par sens (godotOnly = coup legal chez Godot que l'APK interdit ; oracleOnly = l'inverse) : "
          + ("  ".join(f"{k[len('usableSet-'):]}={n}" for k, n in us) or "aucun ecart"))
    alt = sorted(((k, v["n"]) for k, v in ag["by"].items() if k.startswith("passAlt")), key=lambda kv: -kv[1])
    print("  oracle ne joue rien mais Godot jouerait (site>coup) : " + ("  ".join(f"{k[8:]}={n}" for k, n in alt) or "aucun cas"))
    print("  par trace (accord / n tous types) : " + "  ".join(
        f"{t['trace']}={sum(v['agree'] for v in t['aiAgreement']['types'].values())}/{sum(v['n'] for v in t['aiAgreement']['types'].values())}" for t in traces if t.get("aiAgreement")))
    for k, g in ag["types"].items():
        for e in g["ex"][:2]:
            print(f"  ex {k:<21} {e['trace']}@{e['seq']} T{e['turn']} P{e['player']}: oracle={e['oracle']} | godot={e['godot']}{' (indifferent)' if e['tie'] else ''}")


def fmt(v):
    s = json.dumps(v, separators=(",", ":"), ensure_ascii=False)
    return s[:67] + "..." if len(s) > 70 else s


def load(path):
    with open(path, encoding="utf-8") as f:
        return json.load(f)


# --- tutoriel de l'APK (lot L8, T-A07 / T-A31) ------------------------------------------------------------------------
# Oracle : `--tutorial` = GameBoardExtensions.InitializeGameBoardTutorial (graine 2832, pioches imposees, BMA003 contre BMA006), humain scripte
# (tools/apk-oracle/TutorialHumanBrain.cs : defausse BMA026+BMA055, salles BMA034 / BMA016 / BMA027, capacite de BMA027, sort BMA041 sur BMA068), IA = FixedAI.
# `--seed` = graine de WaveServices.Random (decisions de StatisticAI) : la trace doit en etre independante (voir `waves`).
# Godot : (1) rejeu de la trace par ApkParity (regles : humain et IA rejoues), (2) TutParity : MEME partie jouee par Godot lui-meme (start_tutorial, humain scripte,
# IA du siege 2 = AI.pick_move) comparee aux points de controle de l'oracle, (3) avec --ai-agreement : accord de l'IA Godot sur les decisions du siege 2.

def tutorial_generate(waves, turns):
    os.makedirs(OUT, exist_ok=True)
    for f in os.listdir(OUT):
        if re.match(r"^(oracle|gd-|init-|tut-).*\.json$|^report\.json$", f):
            os.unlink(os.path.join(OUT, f))
    names = []
    for w in waves:
        name = f"oracle-tut-w{w}.json"
        r = subprocess.run(["dotnet", "run", "--project", "tools/apk-oracle", "-v", "q", "--", "--tutorial", "--seed", str(w), "--max-turns", str(turns), "--out", os.path.join(OUT, name)],
                           cwd=REPO, capture_output=True, text=True, encoding="utf-8", errors="replace", stdin=subprocess.DEVNULL)
        if not os.path.exists(os.path.join(OUT, name)):
            sys.exit(f"[apk-parity] oracle {name} ECHEC\n{(r.stdout + r.stderr).strip()}")
        names.append(name)
    return names


def run_tut_parity():
    p = subprocess.Popen([godot_exe(), "--headless", "--path", os.path.join(REPO, "src", "frontend"), "res://godot/tests/TutParity.tscn", "--",
                          "--traces=" + OUT.replace("\\", "/")], stdout=subprocess.PIPE, stderr=subprocess.STDOUT, stdin=subprocess.DEVNULL)
    try:
        raw, _ = p.communicate(timeout=600)
    except subprocess.TimeoutExpired:
        if os.name == "nt":
            subprocess.run(["taskkill", "/F", "/T", "/PID", str(p.pid)], capture_output=True)
        else:
            p.kill()
        raw, _ = p.communicate()
    out = raw.decode("utf-8", errors="replace")
    if "TUT PARITY OK" not in out:
        print("[apk-parity] TutParity Godot a echoue :", file=sys.stderr)
        print("\n".join([l for l in out.splitlines() if re.search(r"ERROR|SCRIPT|FAIL", l)][:20]) or out[-2000:], file=sys.stderr)
        sys.exit(1)
    return [l for l in out.splitlines() if "stuck" in l]


def oracle_actions(trace):
    """Actions du jeu (buildRoom / playRoomAbility / playSpell) par siege : [genre, carte, tour] dans l'ordre de l'oracle."""
    out = {"1": [], "2": []}
    for s in trace["steps"]:
        d = s.get("detail") or {}
        a = d.get("action")
        if s["kind"] == "action" and a in ("buildRoom", "playRoomAbility", "playSpell"):
            card = (d.get("room") or d.get("spell"))["card"]
            out[str(d["player"])].append([a, card, s["turn"]])
    return out


def godot_actions(tut):
    out = {"1": [], "2": []}
    for pid, mtype, card, turn in tut["live"]["moves"]:
        out[str(pid)].append([{"activateRoom": "playRoomAbility"}.get(mtype, mtype), card, max(0, turn)])
    return out


def compare_tut_live(trace, tut):
    """Points de controle du tutoriel joue par Godot (debut de tour, leurre) + journal des actions, contre l'oracle."""
    live = tut["live"]
    diffs, checks = [], 0
    last = trace["turns"] - 2  # Godot s'arrete au debut du dernier tour (turnstart:turns-1) : actions et leurres comparables jusqu'au tour `last`
    steps = trace["steps"]
    for i, s in enumerate(steps):
        kind = check_kind(steps, i)
        if kind not in ("turnstart", "bait") or s["turn"] > last + (1 if kind == "turnstart" else 0):
            continue
        g = live["snaps"].get(f"{kind}:{s['turn']}")
        checks += 1
        d = diff_proj(oracle_proj(s, trace), g, kind) if g else [{"field": "(point non atteint par Godot)", "oracle": None, "godot": None}]
        for x in d:
            diffs.append({"check": f"{kind}:{s['turn']}", "field": x["field"], "oracle": x["oracle"], "godot": x["godot"]})
    oa, ga = oracle_actions(trace), godot_actions(tut)
    for pid in ("1", "2"):
        o = [x for x in oa[pid] if x[2] <= last]
        g = [x for x in ga[pid] if x[2] <= last]
        checks += 1
        if o != g:
            diffs.append({"check": f"actions:P{pid}", "field": "actions", "oracle": o, "godot": g})
    return {"checks": checks, "diffs": diffs}


def tutorial_main(a):
    global OUT
    OUT = OUT + "-tut"
    names = sorted(f for f in os.listdir(OUT) if re.match(r"^oracle-tut-.*\.json$", f)) if a.skip_gen and os.path.isdir(OUT) else tutorial_generate(a.waves, a.tut_turns)
    run_godot(a.ai_agreement)
    stuck = run_tut_parity()
    rows = []
    sig = {}
    for n in names:  # WaveServices.Random : la trace de l'APK (hors graine) est-elle independante du hasard de l'IA ?
        t = load(os.path.join(OUT, n))
        sig.setdefault(json.dumps([t["initial"], t["steps"]], sort_keys=True), []).append(t["meta"]["seed"])
    for n in names:
        t = load(os.path.join(OUT, n))
        tid = re.sub(r"^oracle-", "", n)
        replay = compare_trace(t, load(os.path.join(OUT, "gd-" + tid)))
        tut = load(os.path.join(OUT, tid))
        t["_name"] = n
        init = compare_init(t, tut["init"])
        live = compare_tut_live(t, tut)
        rows.append((tid, replay, init, live, replay["status"] == "OK" and init["ok"] and not live["diffs"]))
    print()
    print("trace          rejeu ok/total refus   init           live ok/total   statut")
    for tid, replay, init, live, ok in rows:
        print(f"{tid:<14} {replay['matched']:>4}/{replay['checks']:<5} {replay['refusCount']:>5}   {'identique' if init['ok'] else 'ECART ' + ','.join(init['diffs']):<13}  {live['checks'] - len(live['diffs']):>4}/{live['checks']:<8}  {'OK' if ok else 'ECART'}")
        for d in live["diffs"][:6]:
            print(f"    live {d['check']} {d['field']} oracle={fmt(d['oracle'])} godot={fmt(d['godot'])}")
        if replay["firstDivergence"]:
            d = replay["firstDivergence"]
            print(f"    rejeu seq {d['seq']} {d['field']} oracle={fmt(d['oracle'])} godot={fmt(d['godot'])}")
    print(f"[apk-parity] tutoriel : {len(names)} graine(s) de WaveServices.Random, {len(sig)} trace(s) distincte(s) de l'oracle (1 = l'IA scriptee de l'APK ne depend pas de son hasard)")
    for line in stuck:
        print("[apk-parity] " + line)
    ok_all = all(r[4] for r in rows)
    if a.ai_agreement:
        traces = []
        for n in names:
            gd = load(os.path.join(OUT, "gd-" + re.sub(r"^oracle-", "", n)))
            traces.append({"trace": re.sub(r"^oracle-|\.json$", "", n), "aiAgreement": gd.get("aiAgreement")})
        ag = aggregate_ai(traces)
        print_ai(ag, traces)
        ok_all = ok_all and ag["mutations"] == 0 and ag["types"]["usableSet"]["agree"] == ag["types"]["usableSet"]["n"]
    print(f"APK TUTORIAL RAPPORT: {sum(1 for r in rows if r[4])}/{len(rows)} traces OK")
    return 0 if ok_all and not stuck else 1


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--seeds", type=int, nargs="+", default=[1, 2, 3])
    ap.add_argument("--players", type=int, nargs="+", default=[2, 3])
    ap.add_argument("--decks", default="BaseDeck")
    ap.add_argument("--skip-gen", action="store_true")
    ap.add_argument("--no-init-parity", action="store_true", help="saute la parite d'initialisation (meme graine : pioches, mains d'ouverture, boss ; report.json `initParity`)")
    ap.add_argument("--tutorial", action="store_true", help="lot L8 : tutoriel de l'APK (InitializeGameBoardTutorial + FixedAI), voir tutorial_main")
    ap.add_argument("--waves", type=int, nargs="+", default=[1, 2, 3], help="--tutorial : graines de WaveServices.Random de l'oracle")
    ap.add_argument("--tut-turns", type=int, default=4, help="--tutorial : nombre de tours joues")
    ap.add_argument("--ai-agreement", action="store_true", help="lot 1.2 : accord de l'IA Godot (AI.gd) avec l'IA oracle, par type de coup (report.json `aiAgreement`)")
    a = ap.parse_args()
    if a.tutorial:
        return tutorial_main(a)
    if a.skip_gen:
        names = sorted(f for f in os.listdir(OUT) if re.match(r"^oracle-.*\.json$", f))
    else:
        names = generate(a.seeds, a.players, a.decks)

    ai = a.ai_agreement
    godot_errors = run_godot(ai)
    if not a.no_init_parity:
        run_init_parity()
    traces, unmapped = [], set()
    for name in names:
        trace = load(os.path.join(OUT, name))
        tid = re.sub(r"^oracle-", "", name)
        entry = {"trace": re.sub(r"^oracle-|\.json$", "", name), "seed": trace["meta"]["seed"], "players": trace["meta"]["players"],
                 "oracleSteps": len(trace["steps"]), "oracleResult": trace.get("result"), "oracleTurns": trace.get("turns")}
        gd = load(os.path.join(OUT, f"gd-{tid}"))
        unmapped.update(gd.get("unmapped", []))
        entry.update(compare_trace(trace, gd))
        if ai:
            entry["aiAgreement"] = gd.get("aiAgreement")
        traces.append(entry)

    report = {"generatedAt": datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%S.000Z"), "godot": godot_exe(),
              "godotScriptErrors": len(godot_errors), "unmappedCards": sorted(unmapped),
              "decisionsSkipped": sum((t["stats"] or {}).get("decisionsSkipped", 0) for t in traces),
              "passiveSkipped": sum((t["stats"] or {}).get("passiveSkipped", 0) for t in traces),
              "spellTargetUnmatched": sum((t["stats"] or {}).get("spellTargetUnmatched", 0) for t in traces),
              "skippedBy": aggregate_skipped(traces), "traces": traces}
    if ai:
        report["aiAgreement"] = aggregate_ai(traces)
    if not a.no_init_parity:
        inits = []
        for name in names:
            tr = load(os.path.join(OUT, name))
            tr["_name"] = name
            inits.append(compare_init(tr, load(os.path.join(OUT, "init-" + re.sub(r"^oracle-", "", name)))))
        report["initParity"] = {"traces": len(inits), "ok": sum(1 for i in inits if i["ok"]), "mulligans": sum(1 for i in inits if i["mulligan"]),
                                "mulliganOk": sum(1 for i in inits if i["mulligan"] and i["ok"]), "list": inits}
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
        if r["skipIssues"]:
            print(f"           decisions ignorees non classees: {'; '.join(r['skipIssues'])}")
        if r["skipWarnings"]:
            print(f"           (avertissement, non bloquant) decisions ignorees a classer: {'; '.join(r['skipWarnings'])}")
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
    print(f"== decisions oracle ignorees (stats.decisionsSkipped = {report['decisionsSkipped']}) par classe site:decision:tCible ; distinct = seq differents ; carte@action oracle parente, - = declencheur")
    for key, a in report["skippedBy"].items():
        top = " ".join(f"{k}={v}" for k, v in sorted(a["cards"].items(), key=lambda kv: -kv[1])[:4])
        worst = " ".join(f"{k}={v}" for k, v in sorted(a["traces"].items(), key=lambda kv: -kv[1])[:3])
        print(f"  {key:<38} {a['n']:>5} (distinct {a['distinct']:>4}, rejoue apres {a['replayed']:>3})  cartes@action: {top}  traces: {worst}")
    print(f"  decisions passives BMA020 comptees a part (passiveSkipped) : {report['passiveSkipped']}")
    print(f"  playSpell dont la cible oracle n'est dans aucune variante Godot (cands[0] joue) : {report['spellTargetUnmatched']}")
    print()
    if ai:
        print_ai(report["aiAgreement"], traces)
        print()
    print(f"[apk-parity] rapport: {os.path.join(OUT, 'report.json')}")
    ip = report.get("initParity")
    if ip:
        bad_init = [i["trace"] + ":" + ",".join(i["diffs"]) for i in ip["list"] if not i["ok"]]
        print(f"[apk-parity] initialisation (meme graine : boss, rang, pioches avant et apres distribution, mains avant defausse) : {ip['ok']}/{ip['traces']} traces identiques, "
              f"dont {ip['mulliganOk']}/{ip['mulligans']} avec mulligan" + (f" ; ecarts : {' '.join(bad_init)}" if bad_init else ""))
    bad = [t["trace"] for t in traces if t["status"] != "OK"]
    print(f"APK PARITY RAPPORT: {len(traces) - len(bad)}/{len(traces)} traces OK" + (f" (hors OK: {', '.join(bad)})" if bad else ""))
    # Seuil d'echec de --ai-agreement : `usableSet` (legalite du moteur) est a 100 % depuis la passe « ecarts de legalite » ; tout ecart est un ecart de REGLE.
    us = report["aiAgreement"]["types"]["usableSet"] if ai else None
    if us and us["agree"] != us["n"]:
        print(f"ECHEC usableSet: {us['n'] - us['agree']} ecart(s) de legalite sur {us['n']} (voir la ventilation par carte ci-dessus)")
    return 1 if bad or (us and us["agree"] != us["n"]) or (ip and ip["ok"] != ip["traces"]) else 0


if __name__ == "__main__":
    sys.exit(main())
