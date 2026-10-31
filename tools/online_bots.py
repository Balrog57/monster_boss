#!/usr/bin/env python3
"""Charge et abus du serveur multijoueur par des clients WebSocket sans navigateur (bibliotheque `websockets`).

  --rooms N    N salons en parallele, chacun : 1 humain (ce robot) + 1 IA serveur, partie jouee jusqu'a gameOver (isolation : chaque robot
               ne voit que son salon et son siege, la vue recue respecte ViewFilter ; memoire du serveur echantillonnee avec --server-pid).
  --abuse      messages mal formes, trames trop grandes, coups d'un mauvais siege / hors tour, jonction en double, reprises rapides,
               salon plein / lance / code faux, rafale de messages : le serveur doit rester debout et servir ensuite une partie normale.

Le serveur doit tourner deja : godot --headless --path src/frontend res://godot/server/Server.tscn -- --port=8091 (--url ws://127.0.0.1:8091 par defaut).
Usage : python tools/online_bots.py --rooms 20 --server-pid 1234 ; python tools/online_bots.py --rooms 22 --mix ; python tools/online_bots.py --abuse
"""
import argparse
import asyncio
from collections import Counter
import json
import os
import random
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import websockets  # noqa: E402
from web_online_smoke import face_down_tops, view_leaks  # noqa: E402

# Configurations tournantes de --mix : (joueurs, paquets). 5-6 joueurs exigent Crash Landing (Match.setup_error) ; seuls les paquets de CardDB.SHIPPED_SETS sont jouables en ligne.
CONFIGS = [(2, []), (3, []), (4, []), (2, ["hidden-heroes"]), (3, ["next-level"]), (4, ["hidden-heroes", "next-level"]), (5, ["crash-landing"]),
           (6, ["crash-landing"]), (3, ["players-choice", "hidden-heroes", "next-level"]), (2, ["next-level", "crash-landing"]), (4, ["crash-landing", "hidden-heroes"])]
PRIO = ["pickBoss", "openingDiscard", "buildRoom", "pass", "passBuild", "resolveChoice"]
VERSION = 1


async def rx(ws, want, timeout=5.0):
    """Premiere trame de type `want` (ou liste de types) dans le delai ; None sinon."""
    want = [want] if isinstance(want, str) else want
    end = time.time() + timeout
    while time.time() < end:
        try:
            m = json.loads(await asyncio.wait_for(ws.recv(), max(0.05, end - time.time())))
        except (asyncio.TimeoutError, websockets.ConnectionClosed):
            return None
        if m.get("t") in want:
            return m
    return None


def pick(moves, rng, built):
    for t in PRIO:
        c = [m for m in moves if m["type"] == t]
        if c and not (t == "buildRoom" and built >= 2):
            return rng.choice(c)
    c = [m for m in moves if m["type"] != "undoBuild"]
    return rng.choice(c) if c else None


async def bot_game(url, i, rng, results, max_s, cfg=(2, []), dump=None):
    t0 = time.time()
    res = dict(bot=i, ok=False, states=0, leaks=0, errors=[], secs=0, turns=0, seat_mismatch=0, closed=False, cfg=cfg, fd=0, choices=Counter())
    recent = []
    results.append(res)
    try:
        async with websockets.connect(url, max_size=1 << 22, ping_interval=None) as ws:
            await ws.send(json.dumps(dict(t="create", v=VERSION, name="Bot%d" % i, players=cfg[0], bots=cfg[0] - 1, sets=cfg[1], turnTimeout=4)))
            j = await rx(ws, "joined")
            if not j:
                res["errors"].append("pas de joined")
                return
            seat, code = j["seat"], j["code"]
            built = 0
            last_turn = -1
            mv = None
            last_ping = time.time()
            pending = None  # trame arrivee pendant la « reflexion » du robot : l'etat qu'il allait jouer est perime, il rejoue sur le plus recent
            while time.time() - t0 < max_s:
                try:
                    m = pending or json.loads(await asyncio.wait_for(ws.recv(), 6.0))
                    pending = None
                except asyncio.TimeoutError:
                    await ws.send(json.dumps(dict(t="sync")))
                    continue
                if time.time() - last_ping > 20: # comme le vrai client : sans trame pendant 120 s le serveur coupe (« inactif »), et un siege qui attend l'IA n'envoie rien
                    last_ping = time.time()
                    await ws.send(json.dumps(dict(t="ping")))
                t = m.get("t")
                if t == "closed":
                    res["closed"] = True
                    break
                if t == "error":
                    res["errors"].append("%s:%s apres %s" % (m.get("code"), m.get("message"), str(mv)[:80] if mv else "-"))
                    continue
                if t != "state":
                    continue
                res["states"] += 1
                res["last"] = dict(turn=m["view"].get("turn"), phase=m["view"].get("phase"), deadline=m.get("deadline"), awaited=m.get("awaited"), server_time=m.get("serverTime"), at=time.time(),
                                   pending=(m["view"].get("pendingChoice") or {}).get("type"), stack=len(m["view"].get("stack") or []), moves=[x["type"] for x in m.get("moves", [])][:6])
                pc = (m.get("view") or {}).get("pendingChoice") or {}
                if pc:
                    res["choices"][("mien" if int(pc.get("playerId", -1)) == seat else "autre") + ":" + str(pc.get("type"))] += 1
                if m.get("seat") != seat or m.get("code") != code:
                    res["seat_mismatch"] += 1
                if view_leaks(m):
                    res["leaks"] += 1
                v = m["view"]
                recent = (recent + [m])[-4:]
                if v.get("phase") in ("bait", "adventure") and face_down_tops(m): # diagnostic " salle encore face cachee en phase d'aventure " (AUDIT)
                    res["fd"] += 1
                    if dump and res["fd"] == 1:
                        with open(os.path.join(dump, "fd_bot%d.json" % i), "w", encoding="utf-8") as f:
                            json.dump(recent, f)
                if v.get("turn") != last_turn:
                    last_turn, built = v.get("turn"), 0
                res["turns"] = v.get("turn", 0)
                if v.get("gameOver") is not None:
                    res["ok"] = True
                    res["winner"] = v["gameOver"].get("winner")
                    break
                mv = pick(m.get("moves", []), rng, built)
                if mv is not None:
                    built += mv["type"] == "buildRoom"
                    await asyncio.sleep(rng.uniform(0.02, 0.15))
                    try:
                        pending = json.loads(await asyncio.wait_for(ws.recv(), 0.02))
                        continue
                    except asyncio.TimeoutError:
                        pass
                    await ws.send(json.dumps(dict(t="move", move=mv)))
    except Exception as e:  # noqa: BLE001
        res["errors"].append("exception %r" % e)
    finally:
        res["secs"] = round(time.time() - t0)


def rss_mb(pid):
    try:
        import psutil
        return round(psutil.Process(pid).memory_info().rss / 1e6)
    except Exception:  # noqa: BLE001
        return None


async def run_rooms(url, n, seed, max_s, pid, mix=False, dump=None):
    rng = random.Random(seed)
    results = []
    mem = [(0, rss_mb(pid))] if pid else []

    async def sampler():
        t0 = time.time()
        while True:
            await asyncio.sleep(10)
            if pid:
                mem.append((round(time.time() - t0), rss_mb(pid)))

    s = asyncio.create_task(sampler())
    await asyncio.gather(*(bot_game(url, i, random.Random(rng.random()), results, max_s, CONFIGS[i % len(CONFIGS)] if mix else (2, []), dump) for i in range(n)))
    s.cancel()
    if pid:
        mem.append((-1, rss_mb(pid)))
    ok = sum(r["ok"] for r in results)
    print("salons : %d, parties terminees : %d" % (n, ok))
    print("etats recus : %d, fuites de vue : %d, siege / code inattendu : %d" % (sum(r["states"] for r in results), sum(r["leaks"] for r in results), sum(r["seat_mismatch"] for r in results)))
    print("duree : min %ds max %ds ; tours : %s" % (min(r["secs"] for r in results), max(r["secs"] for r in results), sorted(r["turns"] for r in results)))
    by = {}
    for r in results:
        k = "%dj %s" % (r["cfg"][0], "+".join(r["cfg"][1]) or "base")
        by.setdefault(k, [0, 0])
        by[k][0] += 1
        by[k][1] += r["ok"]
    print("par configuration (lancees / terminees) : %s" % by)
    for r in results:
        if not r["ok"]:  # salon non termine : etat du dernier message recu (un tour qui n'avance plus = defaut du serveur, pas lenteur)
            last = dict(r.get("last", {}))
            last["secondes_depuis_le_dernier_etat"] = round(time.time() - last.pop("at", time.time()))
            print("NON TERMINE bot %d %s : %s ; erreurs %s" % (r["bot"], r["cfg"], last, r["errors"][:2]))
    ch = Counter()
    for r in results:
        ch.update(r["choices"])
    print("choix en attente vus (mien / d'un autre siege, type) : %s" % dict(ch))
    print("etats recus avec salle du dessus face cachee en bait / adventure : %d (parties touchees : %d)" % (sum(r["fd"] for r in results), sum(bool(r["fd"]) for r in results)))
    errs = [(r["bot"], r["errors"][:2]) for r in results if r["errors"]]
    print("erreurs : %s" % (errs[:5] or "aucune"))
    if mem:
        print("memoire du serveur (Mo) : %s" % mem)
    return 0 if ok == n and not any(r["leaks"] or r["seat_mismatch"] for r in results) else 1


# --------------------------------------------------------------------------------------------------------------------

async def abuse(url):
    out = []

    def rec(name, cond, detail=""):
        out.append((name, bool(cond), detail))
        print("%-58s %s %s" % (name, "OK " if cond else "ECHEC", detail))

    async def conn():
        return await websockets.connect(url, max_size=1 << 22, ping_interval=None)

    async def code_of(ws, **kw):
        await ws.send(json.dumps(dict(t="create", v=VERSION, name="Abuse", players=2, **kw)))
        return await rx(ws, ["joined", "error"])

    # 1. messages mal formes : erreur ou fermeture, jamais de plantage
    ws = await conn()
    for raw in ["not json", "[]", "1", "null", '"x"', '{"no_t":1}', '{"t":5}', '{"t":"zzz"}', '{"t":"move","move":"x"}', '{"t":"create"}', '{"t":"join","v":1,"code":{}}']:
        await ws.send(raw)
        m = await rx(ws, "error", 2)
        rec("message mal forme %-26s" % raw[:26], m is not None and m.get("code") in ("bad_message", "version", "bad_move", "no_seat", "not_found", "bad_setup"), m and m.get("code"))
    await ws.close()

    # 2. trame trop grande (> 16 Kio) -> fermeture 1009 ; trame binaire ignoree
    ws = await conn()
    await ws.send(b"\x00\x01\x02")
    await ws.send(json.dumps(dict(t="ping")))
    rec("trame binaire ignoree, ping repond", await rx(ws, "pong", 2) is not None)
    await ws.send(json.dumps(dict(t="create", v=VERSION, name="A" * 20000)))
    try:
        await asyncio.wait_for(ws.wait_closed(), 5)
        rec("trame de 20 Kio : liaison coupee", ws.close_code in (1009, 1006, 1008), ws.close_code)
    except asyncio.TimeoutError:
        rec("trame de 20 Kio : liaison coupee", False, "toujours ouverte")

    # 3. rafale > 60 messages / s -> 1008
    ws = await conn()
    for _ in range(120):
        await ws.send(json.dumps(dict(t="ping")))
    try:
        while True: # les pong recus doivent etre lus : sinon la file de la bibliotheque (32 trames) bloque la lecture de la trame de fermeture
            await asyncio.wait_for(ws.recv(), 5)
    except websockets.ConnectionClosed:
        rec("rafale de 120 messages : liaison coupee", ws.close_code in (1008, 1006), ws.close_code)
    except asyncio.TimeoutError:
        rec("rafale de 120 messages : liaison coupee", False, "toujours ouverte")

    # 4. versions, setups invalides
    ws = await conn()
    await ws.send(json.dumps(dict(t="create", v=999, name="x", players=2)))
    m = await rx(ws, "error")
    rec("version inconnue refusee", m and m.get("code") == "version")
    for sets in (["iod"], ["minibosses"], ["tools"], ["players-choice-wiki"]):
        await ws.send(json.dumps(dict(t="create", v=VERSION, name="x", players=2, sets=sets)))
        m = await rx(ws, ["error", "joined"])
        rec("paquet ferme %s refuse (bad_setup)" % sets, m and m.get("code") == "bad_setup", m and m.get("code") or m and m.get("t"))
    await ws.send(json.dumps(dict(t="create", v=VERSION, name="x", players=6, sets=["players-choice"])))
    m = await rx(ws, "error")
    rec("6 joueurs sans Crash Landing refuse", m and m.get("code") == "bad_setup")
    await ws.send(json.dumps(dict(t="create", v=VERSION, name={"a": 1}, players="99", sets="oops", bots=-5, public="true", title=12, turnTimeout="x")))
    m = await rx(ws, ["joined", "error"])
    rec("champs de types faux : pas de plantage", m is not None, m and (m.get("t"), m.get("code")))
    await ws.close()

    # 5. coups : sans siege, hors tour, faux, duplique
    ws0 = await conn()
    m = await code_of(ws0, bots=0)
    code, token = m["code"], m["token"]
    await ws0.send(json.dumps(dict(t="move", move=dict(type="pass", args=[]))))
    e = await rx(ws0, "error")
    rec("coup avant le debut de la partie refuse", e and e.get("code") == "illegal", e and e.get("code"))
    wsx = await conn()
    await wsx.send(json.dumps(dict(t="move", move=dict(type="pass", args=[]))))
    e = await rx(wsx, "error")
    rec("coup sans siege refuse (no_seat)", e and e.get("code") == "no_seat", e and e.get("code"))
    await wsx.send(json.dumps(dict(t="start")))
    e = await rx(wsx, "error")
    rec("start sans salle refuse (forbidden)", e and e.get("code") == "forbidden", e and e.get("code"))
    await wsx.send(json.dumps(dict(t="join", v=VERSION, code="zzzz")))
    e = await rx(wsx, "error")
    rec("code inconnu : not_found", e and e.get("code") == "not_found", e and e.get("code"))
    await wsx.send(json.dumps(dict(t="join", v=VERSION, code=code, name="Guest")))
    j = await rx(wsx, "joined")
    rec("jonction valide", j is not None)
    await wsx.send(json.dumps(dict(t="join", v=VERSION, code=code, name="Guest2")))
    e = await rx(wsx, "error")
    rec("jonction en double : busy", e and e.get("code") == "busy", e and e.get("code"))
    await wsx.send(json.dumps(dict(t="create", v=VERSION, name="x", players=2)))
    e = await rx(wsx, "error")
    rec("creation depuis une salle : busy", e and e.get("code") == "busy", e and e.get("code"))
    ws2 = await conn()
    await ws2.send(json.dumps(dict(t="join", v=VERSION, code=code, name="Third")))
    e = await rx(ws2, "error")
    rec("salon plein : full", e and e.get("code") == "full", e and e.get("code"))
    await ws0.send(json.dumps(dict(t="start")))
    st = await rx(ws0, "state", 5)
    rec("start de l'hote : etat recu", st is not None)
    ws3 = await conn()
    await ws3.send(json.dumps(dict(t="join", v=VERSION, code=code, name="Late")))
    e = await rx(ws3, "error")
    rec("partie lancee : full", e and e.get("code") == "full", e and e.get("code"))
    await wsx.send(json.dumps(dict(t="start")))
    e = await rx(wsx, "error")
    rec("start par un invite : forbidden", e and e.get("code") == "forbidden", e and e.get("code"))
    # coup illegal et coup d'un autre siege
    await wsx.send(json.dumps(dict(t="move", move=dict(type="buildRoom", args=[99]))))
    e = await rx(wsx, "error")
    rec("coup inexistant : illegal + resynchronisation", e and e.get("code") == "illegal")
    await wsx.send(json.dumps(dict(t="move", move=dict(type="pickBoss", args=["BMA999"]))))
    e = await rx(wsx, "error")
    rec("pickBoss d'une carte inconnue : illegal", e and e.get("code") == "illegal")
    await wsx.send(json.dumps(dict(t="move", move=dict(type=["x"], args="y"))))
    e = await rx(wsx, "error")
    rec("coup a champs de types faux : erreur, pas de plantage", e is not None, e and e.get("code"))

    # 6. reprises rapides : 15 reprises successives du meme siege (chaque nouvelle liaison evince la precedente)
    ok = 0
    ws_old = wsx
    seat_x, tok_x = j["seat"], j["token"]
    for k in range(15):
        wn = await conn()
        await wn.send(json.dumps(dict(t="resume", v=VERSION, code=code, seat=seat_x, token=tok_x)))
        r = await rx(wn, ["joined", "error"], 3)
        ok += bool(r and r.get("t") == "joined")
        ws_old = wn
    rec("15 reprises rapides du meme siege", ok == 15, "%d/15" % ok)
    wb = await conn()
    await wb.send(json.dumps(dict(t="resume", v=VERSION, code=code, seat=seat_x, token="0" * 32)))
    e = await rx(wb, "error")
    rec("reprise avec un faux jeton : bad_token", e and e.get("code") == "bad_token", e and e.get("code"))
    # anti force brute : 6 essais de code faux sur UNE connexion -> coupee
    wf = await conn()
    for k in range(7):
        try:
            await wf.send(json.dumps(dict(t="join", v=VERSION, code="a%03d" % k, name="x")))
        except websockets.ConnectionClosed:
            break
    try:
        await asyncio.wait_for(wf.wait_closed(), 5)
        rec("7 codes faux sur une liaison : coupee (1008)", wf.close_code == 1008, wf.close_code)
    except asyncio.TimeoutError:
        rec("7 codes faux sur une liaison : coupee (1008)", False)
    for w in (ws0, ws_old, wsx, ws2, ws3, wb):
        try:
            await w.close()
        except Exception:  # noqa: BLE001
            pass

    # 7. apres tout cela, une partie normale se joue encore
    res = []
    await bot_game(url, 999, random.Random(1), res, 240)
    rec("serveur sain : partie normale jouee jusqu'au bout", res[0]["ok"], "tours %s en %ds" % (res[0]["turns"], res[0]["secs"]))
    bad = [n for n, c, _ in out if not c]
    print("%d controle(s), %d echec(s)" % (len(out), len(bad)))
    return 1 if bad else 0


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--url", default="ws://127.0.0.1:8091")
    ap.add_argument("--rooms", type=int, default=0)
    ap.add_argument("--abuse", action="store_true")
    ap.add_argument("--seed", type=int, default=1)
    ap.add_argument("--max-secs", type=int, default=300)
    ap.add_argument("--mix", action="store_true", help="configurations tournantes (2-6 joueurs, paquets de CONFIGS) au lieu de 2 joueurs en jeu de base")
    ap.add_argument("--dump", default="", help="dossier ou ecrire les 4 derniers etats d'un client qui voit une salle face cachee en phase d'aventure")
    ap.add_argument("--server-pid", type=int, default=0, help="pid du serveur Godot (memoire echantillonnee avec psutil)")
    a = ap.parse_args()
    rc = 0
    if a.rooms:
        rc |= asyncio.run(run_rooms(a.url, a.rooms, a.seed, a.max_secs, a.server_pid, a.mix, a.dump or None))
    if a.abuse:
        rc |= asyncio.run(abuse(a.url))
    if not a.rooms and not a.abuse:
        ap.error("--rooms N et / ou --abuse")
    return rc


if __name__ == "__main__":
    sys.exit(main())
