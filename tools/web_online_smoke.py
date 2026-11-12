#!/usr/bin/env python3
"""Parties en ligne REELLES dans N navigateurs (Playwright) : menus, salon, salle d'attente, partie jusqu'au bout, controles de vue.

Pile testee : serveur Godot headless (godot/server/Server.tscn) + export web servi par tools/web_serve.py (qui proxifie /ws comme nginx).
Chaque joueur est un contexte de navigateur distinct (sessionStorage, IndexedDB et profil separes). Tout passe par de vrais clics souris dans le
repere 1920 x 1080 du jeu (voir web_smoke.pt) : pseudo, avatar, creation du salon (nombre de joueurs, paquets), code, jonction, lancement.
En partie, le script lit les trames WebSocket recues par chaque navigateur (Playwright `page.on("websocket")`) pour savoir quelle decision est
attendue, puis agit par clic / glisser (choix du boss, defausse d'ouverture, pose d'une salle, DONE, PASS). Les decisions qu'il ne sait pas jouer
(choix de cible, fenetres de sorts...) expirent cote serveur (--turn-timeout) : l'IA du serveur joue alors la decision expiree, comme pour un joueur lent.

Controles : aucune erreur / avertissement de console imprevu ; aucune erreur du serveur (journal --server-log) ; tous les clients voient le meme
resultat final ; la vue recue par chaque siege ne contient jamais d'information cachee d'un autre siege (contrat de ViewFilter.gd).

Prerequis : python -m pip install playwright websockets && python -m playwright install chromium firefox
Usage (le serveur et le site sont lances par le script) :
    python tools/web_online_smoke.py --players 2                       # 2 humains, Chromium
    python tools/web_online_smoke.py --players 4 --bots 2              # 4 sieges : 2 humains + 2 IA
    python tools/web_online_smoke.py --players 6 --bots 3 --packs crash-landing
    python tools/web_online_smoke.py --scenario all                    # les scenarios de la liste SCENARIOS
Scenarios scriptes : rematch (N-B11 : nouveau salon apres la fin / apres un depart), drop (coupure de liaison puis onglet ferme en jeu), multi (2 salons en meme temps
et joins refuses), closed (paquet ferme refuse par le serveur).
Options : --browser chromium|firefox, --shots DIR (captures), --shot-every N, --speed slow|normal|fast, --max-secs, --turn-timeout.
"""
import argparse
import json
import os
import re
import socket
import subprocess
import sys
import threading
import time
from collections import Counter
from http.server import ThreadingHTTPServer

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, ".."))
sys.path.insert(0, HERE)
import web_serve  # noqa: E402
from godot_exe import godot_exe  # noqa: E402
from web_smoke import ALLOW, NO_AUDIO_ALLOW, pt  # noqa: E402

SHOTS_DEFAULT = os.path.join(ROOT, "docs", "reference", "web", "online")
URL = "http://127.0.0.1:%d/"
TILE_X = {"players-choice": 1117, "hidden-heroes": 1448, "next-level": 1779, "crash-landing": 2110}  # centres des tuiles (x), tx = 0
AVATAR_X = [260, 500, 740, 980, 1220, 1460, 1700]   # avatars visibles du selecteur (y 745)
SPEED_X = {"slow": 860, "normal": 1065, "fast": 1268}
# Messages de console ajoutes pour les parties en ligne (les navigateurs sans tete n'ont ni GPU ni audio reels).
ALLOW_ONLINE = [r"WebSocket connection to .* failed", r"\[net\] "]


# --------------------------------------------------------------------------------------------------------------------
# Pile locale : serveur Godot headless + site (web_serve) dans ce processus
# --------------------------------------------------------------------------------------------------------------------

class Stack:
    def __init__(self, web_port=8090, ws_port=8091, turn_timeout=8, adventure_timeout=3, bot_delay=150, extra=(), log_dir=None, quiet=True):
        self.web_port, self.ws_port = web_port, ws_port
        self.args = ["--port=%d" % ws_port, "--turn-timeout=%d" % turn_timeout, "--adventure-timeout=%d" % adventure_timeout,
                     "--bot-delay=%d" % bot_delay, *extra]
        self.log_path = os.path.join(log_dir or SHOTS_DEFAULT, "server.log")
        self.proc = None
        self.http = None

    def start(self):
        os.makedirs(os.path.dirname(self.log_path), exist_ok=True)
        self.log = open(self.log_path, "w", encoding="utf-8", errors="replace")
        self.proc = subprocess.Popen([godot_exe(), "--headless", "--path", os.path.join(ROOT, "src", "frontend"), "res://godot/server/Server.tscn", "--", *self.args],
                                     stdout=self.log, stderr=subprocess.STDOUT)
        t0 = time.time()
        while time.time() - t0 < 60:
            try:
                socket.create_connection(("127.0.0.1", self.ws_port), 1).close()
                break
            except OSError:
                time.sleep(0.5)
        else:
            raise RuntimeError("le serveur Godot n'ecoute pas sur %d" % self.ws_port)
        web_serve.Handler.root = os.path.normpath(os.path.abspath(web_serve.ROOT_DEFAUT))
        web_serve.Handler.ws_upstream = ("127.0.0.1", self.ws_port)
        os.environ["WEB_SERVE_QUIET"] = "1"
        self.http = ThreadingHTTPServer(("127.0.0.1", self.web_port), web_serve.Handler)
        threading.Thread(target=self.http.serve_forever, daemon=True).start()

    def server_errors(self):
        self.log.flush()
        with open(self.log_path, encoding="utf-8", errors="replace") as f:
            txt = f.read()
        return [l for l in txt.splitlines() if re.search(r"ERROR|SCRIPT ERROR|WARNING|Parse Error|Invalid|Cannot|Nonexistent|Out of bounds", l)]

    def stop(self):
        if self.http:
            self.http.shutdown()
        if self.proc:
            self.proc.terminate()
            try:
                self.proc.wait(10)
            except subprocess.TimeoutExpired:
                self.proc.kill()
        self.log.close()


# --------------------------------------------------------------------------------------------------------------------
# Contrat de vue (ViewFilter.gd) : ce qu'un siege n'a pas le droit de voir chez les autres
# --------------------------------------------------------------------------------------------------------------------

PUBLIC_KEYS = {"activePlayer", "adventure", "adventurePausePassed", "afterHero", "apkSkippedHero", "autoAI", "buildIndex", "buildOrder", "buildWindow", "effects",
               "forcedBuild", "gameOver", "itemQueue", "kingVote", "townItems", "lastHeroFight", "luredThisTurn", "mandoQueue", "mulliganPending", "numPlayers", "phase",
               "roboboQueue", "sets", "setupBuild", "setupForced", "setupReveal", "stack", "stackActivePlayer", "stackPassed", "stackReturnPlayer", "tnlEndPending",
               "tnlGiftBuilt", "town", "turn", "variants", "xpOrder"}
FILTERED_KEYS = {"decks", "players", "bossPicks", "pendingChoice", "choiceQueue", "log", "logs"}
PLAYER_PUBLIC = {"id", "boss", "souls", "wounds", "eliminated", "leveledUp", "buildsThisTurn", "buildLimit", "isAI", "entrance", "passed", "hasActed", "coins",
                 "tnlSoulsStart", "rmbBoss", "tnlBoss", "bonusTreasures", "copiedLevelUps", "untilEndSpells", "respawnTurn", "iodBoss", "manuallyKilled"}
PLAYER_HIDDEN = {"hand", "dungeon", "items"}
SECRET_PILES = ("rooms", "spells", "heroes", "epics", "items")


def view_leaks(msg):
    """Liste des violations du contrat de ViewFilter dans un message `state` recu par `msg['seat']` (vide = conforme)."""
    out = []
    v, seat = msg.get("view", {}), int(msg.get("seat", -1))
    for k in v:
        if k not in PUBLIC_KEYS and k not in FILTERED_KEYS:
            out.append("cle de G non prevue : %s" % k)
    for pid, p in (v.get("players") or {}).items():
        if int(pid) == seat:
            continue
        for k in p:
            if k not in PLAYER_PUBLIC and k not in PLAYER_HIDDEN:
                out.append("cle de joueur %s non prevue : %s" % (pid, k))
        for c in p.get("hand", []):
            if set(c) - {"hidden", "isRoom"} or c.get("hidden") is not True:
                out.append("main du siege %s lisible : %s" % (pid, str(c)[:80]))
        for stack in p.get("dungeon", []):
            for r in stack:
                if isinstance(r, dict) and r.get("faceDown") and not r.get("hidden"):
                    out.append("salle face cachee du siege %s lisible : %s" % (pid, str(r)[:80]))
                if isinstance(r, dict) and r.get("faceDown") and (set(r) - {"faceDown", "hidden", "mb"}):
                    out.append("salle face cachee du siege %s porte des champs en clair : %s" % (pid, sorted(set(r) - {"faceDown", "hidden", "mb"})))
                mb = r.get("mb") if isinstance(r, dict) else None
                if isinstance(mb, dict) and mb.get("faceDown") and not mb.get("hidden"):
                    out.append("miniboss face cache du siege %s lisible" % pid)
        for it in p.get("items", []) or []:
            if it.get("faceDown") and not it.get("hidden"):
                out.append("objet face cache du siege %s lisible" % pid)
    for k, pile in (v.get("decks") or {}).items():
        if k in SECRET_PILES:
            for c in pile:
                if c != {"hidden": True}:
                    out.append("pioche %s lisible : %s" % (k, str(c)[:80]))
                    break
    if v.get("phase") != "boss" and v.get("bossPicks"):
        out.append("bossPicks non vide hors phase boss")
    pc = v.get("pendingChoice") or {}
    if pc and int(pc.get("playerId", -1)) != seat:
        extra = set(pc) - {"type", "playerId", "bossName", "options"}
        if extra:
            out.append("choix d'autrui : champs en clair %s" % sorted(extra))
        for o in pc.get("options", []):
            if o != {"hidden": True}:
                out.append("choix d'autrui : option lisible")
                break
    for e in v.get("stack", []) or []:
        if isinstance(e, dict) and "picks" in e and int(e.get("playerId", -1)) != seat:
            out.append("pile : `picks` d'un autre siege visible")
    return out


def face_down_tops(msg):
    """Salles du dessus d'un donjon (tous sieges, vue recue) qui sont face cachees : [(siege, emplacement)]."""
    out = []
    for pid, p in ((msg.get("view") or {}).get("players") or {}).items():
        for i, stack in enumerate(p.get("dungeon", [])):
            if stack and isinstance(stack[-1], dict) and stack[-1].get("faceDown"):
                out.append((int(pid), i))
    return out


# --------------------------------------------------------------------------------------------------------------------
# Un joueur = un contexte de navigateur
# --------------------------------------------------------------------------------------------------------------------

class Client:
    def __init__(self, br, name, size, shots, url, tag):
        self.name, self.tag, self.url = name, tag, url
        self.w, self.h = size
        self.shots = shots
        self.ctx = br.new_context(viewport={"width": self.w, "height": self.h})
        self.page = self.ctx.new_page()
        self.logs = []          # (type, texte, etape)
        self.mark = "demarrage"
        self.frames_in = Counter()
        self.frames_out = Counter()
        self.sent_moves = 0
        self.actions = Counter()
        self.inv = []           # violations des invariants de `awaited` (N-A54)
        self.plays_n = 0
        self.remote_plays = []  # sorts / capacites joues par les AUTRES sieges, vus dans `plays` (N-B24)
        self._t_act = 0.0
        self.state = None       # dernier `state` recu
        self.lobby = None       # dernier `lobby` / `state` recu (champs du lobby)
        self.joined = None      # derniere trame `joined`
        self.errors = []        # trames `error` recues {message, code}
        self.leaks = []
        self.n_state = 0
        self.last_states = []   # 4 derniers `state` (diagnostic)
        self.final = None       # gameOver du dernier etat
        self.fd_seen = []       # salles du dessus face cachees vues dans un etat en phase bait / adventure
        self.closed = False
        self.ws_open = 0
        self.ws_closed = 0
        self.t_state = 0.0
        self.session_dead = False
        self.dead_at = None     # (temps de partie, tour, phase, gameOver deja la ?) du premier etat ou MON siege est elimine (N-B52)
        self.dead_t = 0.0
        self.illegal_after = Counter()  # type du dernier coup envoye avant chaque erreur `illegal`
        self.spell_windows = Counter()  # etats vus avec une pile de sorts : total / ou 2 humains ou plus sont attendus (N-A54)
        self.bubble_shots = 0  # captures de la bulle « HAS PLAYED A SPELL » (N-B24), 3 au plus
        self.left_seen = set()  # sieges adverses partis deja signales
        self.msg_pending = False  # un message « X has left the game. » attend son OK
        self.choices = Counter()  # choix en attente vus (N-A56) : (mien | autre, type)
        self.quit_lose = False  # a quitte la salle par le OK de l'ecran de defaite
        self.gone = False       # page fermee volontairement (deconnexion en cours de partie)
        self.log_from = 0       # console_problems() ne regarde que les messages apres cet index (parties successives)
        self.log_lines = []
        self.page.on("console", lambda m: self.logs.append((m.type, m.text, self.mark)))
        self.page.on("pageerror", lambda e: self.logs.append(("pageerror", str(e), self.mark)))
        self.page.on("crash", lambda: self.logs.append(("crash", "page crashed", self.mark)))
        self.page.on("websocket", self._on_ws)

    def reset_game(self):
        """Entre deux parties du meme navigateur : compteurs et etats a zero (la console ne compte que ce qui suit)."""
        self.state = self.lobby = self.joined = self.final = self.dead_at = None
        self.left_seen, self.msg_pending = set(), False
        self.closed = False
        self.plays_n = 0
        self.sent_moves = self.n_state = 0
        self.actions, self.inv, self.leaks, self.fd_seen, self.errors, self.remote_plays = Counter(), [], [], [], [], []
        self.choices = Counter()
        self.illegal_after = Counter()
        self.log_from = len(self.logs)

    def rewrite_create(self, sets):
        """Fait ajouter `sets` aux messages `create` envoyes par le jeu (a appeler avant load) : l'interface ne propose pas les paquets fermes, le serveur doit les refuser."""
        self.ctx.add_init_script("(function(){var s=WebSocket.prototype.send;WebSocket.prototype.send=function(d){try{if(typeof d==='string'){var m=JSON.parse(d);"
                                 "if(m.t==='create'){m.sets=(m.sets||[]).concat(%s);d=JSON.stringify(m);}}}catch(e){}return s.call(this,d);};})();" % json.dumps(sets))

    # -- trames ------------------------------------------------------------------------------------------------
    def _on_ws(self, ws):
        self.ws_open += 1
        ws.on("framereceived", self._rx)
        ws.on("framesent", self._tx)
        ws.on("close", lambda *_: setattr(self, "ws_closed", self.ws_closed + 1))

    def _tx(self, payload):
        try:
            d = json.loads(payload)
        except (TypeError, ValueError):
            return
        t = d.get("t", "?")
        self.frames_out[t] += 1
        if t == "move":
            self.sent_moves += 1
            self._last_move = (d.get("move") or {}).get("type")
            self._sent_at, self._sent_state = time.time(), self._sum(self.state)
        self.log_lines.append(("->", t, str(payload)[:200]))

    def _rx(self, payload):
        try:
            d = json.loads(payload)
        except (TypeError, ValueError):
            return
        t = d.get("t", "?")
        self.frames_in[t] += 1
        if t == "state":
            self.n_state += 1
            self.state, self.lobby = d, d
            self.t_state = time.time()
            self.last_states = (self.last_states + [d])[-4:]
            lk = view_leaks(d)
            if lk:
                self.leaks.append((d.get("view", {}).get("turn"), lk))
            self.check_awaited(d)
            for i, st in enumerate(d.get("seats") or []):
                if st.get("left") and i != d["seat"] and i not in self.left_seen:
                    self.left_seen.add(i)
                    gone = ((d["view"].get("players") or {}).get(str(i)) or {}).get("eliminated")
                    self.msg_pending = self.msg_pending or not gone  # un siege elimine qui part ne produit aucun message (APK : !player.IsAlive)
            pc = d["view"].get("pendingChoice") or {}
            if pc:
                self.choices[("mien" if int(pc.get("playerId", -1)) == int(d["seat"]) else "autre") + ":" + str(pc.get("type"))] += 1
            me = ((d["view"].get("players") or {}).get(str(d.get("seat"))) or {})
            if me.get("eliminated") and self.dead_at is None:
                self.dead_t = time.time()
                self.dead_at = (d["view"].get("turn"), d["view"].get("phase"), d["view"].get("gameOver") is not None, self.n_state)
            ph = d.get("view", {}).get("phase")
            if ph in ("bait", "adventure"):
                fd = face_down_tops(d)
                if fd:
                    self.fd_seen.append((d["view"].get("turn"), ph, fd))
            if d["view"].get("gameOver") is not None:
                self.final = d["view"]["gameOver"]
        elif t == "lobby":
            self.lobby = d
        elif t == "joined":
            self.joined = d
        elif t == "error":
            self.errors.append(d)
            if d.get("code") == "illegal":
                self.illegal_after[getattr(self, "_last_move", None)] += 1
                self._trace_illegal()
        elif t == "closed":
            self.closed = True
        self.log_lines.append(("<-", t, ""))

    @staticmethod
    def _sum(d):
        if not d:
            return None
        v = d.get("view", {})
        return dict(t=time.time(), n=None, turn=v.get("turn"), phase=v.get("phase"), active=v.get("activePlayer", v.get("current", v.get("active"))), stack=len(v.get("stack") or []),
                    awaited=d.get("awaited"), seat=d.get("seat"), moves=sorted({m["type"] for m in d.get("moves", [])}), pc=bool(v.get("pendingChoice")),
                    ack=d.get("ack"), pause=(v.get("adventure") or {}).get("pause"), room=(v.get("adventure") or {}).get("roomIndex"), plays=len(d.get("plays") or []))

    def _trace_illegal(self):
        """Diagnostic (BM_TRACE=fichier) : pour chaque `illegal`, dernier coup et etats avant l'envoi / avant l'erreur."""
        path = os.environ.get("BM_TRACE")
        if not path:
            return
        now = time.time()
        a, b = getattr(self, "_sent_state", None), self._sum(self.state)
        def ms(x):
            return None if x is None else int((now - x) * 1000)
        line = "%s ILLEGAL %s t=%.3f move=%s sent_ago=%sms | state_at_send=%s (age_at_send=%sms) | state_now=%s (age_now=%sms) same=%s" % (
            self.name, time.strftime("%H:%M:%S"), now, "%s#%d" % (getattr(self, "_last_move", None), self.sent_moves), ms(getattr(self, "_sent_at", None)),
            a and {k: v for k, v in a.items() if k != "t"}, a and int((self._sent_at - a["t"]) * 1000), b and {k: v for k, v in b.items() if k != "t"}, ms(self.t_state),
            a is not None and b is not None and {k: v for k, v in a.items() if k != "t"} == {k: v for k, v in b.items() if k != "t"})
        with open(path, "a", encoding="utf-8") as f:
            f.write(line + "\n")

    def check_awaited(self, d):
        """N-A54 : invariants de `awaited` (sieges humains dont une decision retient la partie) sur chaque etat recu par CE siege."""
        v, seat, aw = d["view"], int(d["seat"]), [int(x) for x in d.get("awaited") or []]
        moves = {m["type"] for m in d.get("moves", [])}
        if seat in aw and not moves:
            self.inv.append((v.get("turn"), v.get("phase"), "siege %d attendu sans aucun coup legal" % seat))
        stack = v.get("stack") or []
        if stack:
            self.spell_windows["etats avec pile"] += 1
            if len(aw) >= 2:
                self.spell_windows["pile et 2 humains attendus"] += 1
        passed = (v.get("stackPassed") or {}).get(str(seat))
        if stack and "pass" in moves and not passed and seat not in aw and not (v.get("pendingChoice") or {}):
            self.inv.append((v.get("turn"), v.get("phase"), "fenetre de sorts : siege %d peut passer mais n'est pas attendu (awaited %s)" % (seat, aw)))
        if stack and passed and seat in aw:
            self.inv.append((v.get("turn"), v.get("phase"), "fenetre de sorts : siege %d a passe mais reste attendu" % seat))
        plays = d.get("plays") or []
        for pl in plays:
            if pl.get("n", 0) > self.plays_n and int(pl.get("seat", -1)) != seat:
                self.remote_plays.append((v.get("turn"), pl.get("seat"), pl.get("move", {}).get("type"), (pl.get("card") or {}).get("name")))
        if plays:
            self.plays_n = max(self.plays_n, max(p.get("n", 0) for p in plays))

    # -- navigateur --------------------------------------------------------------------------------------------
    def load(self):
        self.page.goto(self.url)
        self.page.wait_for_function("document.querySelector('canvas') && document.querySelector('canvas').width > 0", timeout=120000)
        self.page.wait_for_timeout(5000)
        if self.page.evaluate("typeof AudioContext === 'undefined' && typeof webkitAudioContext === 'undefined'"):
            ALLOW.extend(NO_AUDIO_ALLOW)

    def wait(self, s):
        self.page.wait_for_timeout(int(s * 1000))

    def click(self, x, y, wait=1.2, name=None):
        if name:
            self.mark = name
        px, py = pt(x, y, self.w, self.h)
        self.page.mouse.click(px, py)
        self.wait(wait)

    def drag(self, x0, y0, x1, y1, wait=1.0, steps=18):
        m = self.page.mouse
        p0, p1 = pt(x0, y0, self.w, self.h), pt(x1, y1, self.w, self.h)
        m.move(*p0)
        m.down()
        for i in range(1, steps + 1):
            m.move(p0[0] + (p1[0] - p0[0]) * i / steps, p0[1] + (p1[1] - p0[1]) * i / steps)
            self.wait(0.02)
        m.move(p1[0] + 1, p1[1])
        m.move(*p1)
        m.up()
        self.wait(wait)

    def type_text(self, text):
        self.page.keyboard.press("Control+a")
        self.page.keyboard.type(text)
        self.wait(0.4)

    def shot(self, label):
        if not self.shots:
            return
        os.makedirs(self.shots, exist_ok=True)
        try:
            self.page.screenshot(path=os.path.join(self.shots, "%s_%s.png" % (self.tag, label)))
        except Exception as e:  # noqa: BLE001 - une capture qui echoue ne fait pas echouer la partie
            print("capture impossible (%s): %s" % (label, e))

    def session(self):
        """Session de siege gardee par le jeu dans sessionStorage (code, siege, jeton)."""
        try:
            raw = self.page.evaluate("window.sessionStorage.getItem('bossmonster_online_session')")
            return json.loads(raw) if raw else None
        except Exception:  # noqa: BLE001
            return None

    def console_problems(self):
        allow = ALLOW + ALLOW_ONLINE
        out = []
        for t, m, step in self.logs[self.log_from:]:
            if t in ("error", "warning", "pageerror", "crash") and not any(re.search(a, m) for a in allow):
                out.append("%s [apres %s]: %s" % (t, step, m[:300]))
        return out

    # -- menus -------------------------------------------------------------------------------------------------
    def to_menu(self):
        self.mark = "titre"
        self.click(960, 640, 2.5)            # TAP TO START

    def options(self, wiki=False, speed=None):
        """Menu -> OPTIONS (vitesse de jeu ; `wiki` : ignore, plus de case) -> menu."""
        self.mark = "options"
        self.click(710, 615, 2.5)            # OPTIONS
        if speed:
            self.click(960, 517, 2.5)        # SETTINGS
            self.click(SPEED_X[speed], 600, 0.8)
            self.click(80, 70, 2.0)
        self.click(80, 70, 2.5)              # fleche : menu

    def profile(self, name, avatar_slot=3):
        """MULTIPLAYER -> PLAY WITH FRIENDS sans profil : pseudo + avatar, OK, puis WITH FRIENDS."""
        self.mark = "profil"
        self.click(1240, 410, 2.5)           # MULTIPLAYER
        self.click(660, 540, 3.0)            # PLAY WITH FRIENDS -> CHANGE NAME / AVATAR
        self.click(900, 430, 0.6)            # champ du pseudo
        self.type_text(name)
        self.click(960, 200, 0.4)            # defocus
        self.click(AVATAR_X[avatar_slot], 745, 0.8)
        self.click(1800, 1005, 3.0)          # OK -> menu en ligne
        self.click(960, 583, 3.0)            # WITH FRIENDS

    def friends(self):
        """Menu (profil deja cree) -> WITH FRIENDS."""
        self.mark = "friends"
        self.click(1240, 410, 2.5)           # MULTIPLAYER
        self.click(660, 540, 3.0)            # PLAY WITH FRIENDS

    def create_room(self, count, packs=(), wiki=False, variants=()):
        """WITH FRIENDS -> NEW GAME -> HOW MANY PLAYERS? -> SELECT EXPANSIONS -> OK : cree le salon."""
        self.mark = "create"
        self.click(960, 378, 3.0)            # NEW GAME
        if count >= 5 or packs:
            # 5-6 : Crash Landing doit etre coche AVANT (l'anneau des nombres en depend) : SELECT EXPANSIONS d'abord, puis fleche retour.
            self.click(1800, 1005, 3.0)      # OK -> SELECT EXPANSIONS
            self.pick_packs(packs, wiki, variants)
            self.click(80, 70, 2.5)          # retour a HOW MANY PLAYERS? (choix gardes)
        for _ in range(count - 2):           # voisin de droite = nombre suivant
            self.click(1341, 600, 0.8)
        self.shot("count")
        self.click(1800, 1005, 3.0)          # OK -> SELECT EXPANSIONS
        self.shot("packs")
        self.mark = "create_ok"
        self.click(1800, 1005, 4.0)          # OK -> creation du salon

    def pick_packs(self, packs, wiki, variants=()):
        """Sur SELECT EXPANSIONS : coche les tuiles voulues ; la liste defile toujours (TNL, CRL listes d'emblee ; un glissement de 560 px : PC 547, HH 878, TNL 1209, CRL 1540). `wiki` : ignore."""
        self.drag(1500, 700, 940, 700, 1.0)
        xs = {"players-choice": 547, "hidden-heroes": 878, "next-level": 1209, "crash-landing": 1540}
        for p in packs:
            self.click(xs[p], 600, 1.0)
        vx = {"classic": 45, "hard": 355, "choose": 665, "machinations": 975, "unlimited": 1285}
        for v in variants:
            self.click(vx[v], 1021, 0.6)

    def join_room(self, code):
        """WITH FRIENDS -> ROOM CODE -> saisie du code -> OK."""
        self.mark = "join"
        self.click(960, 594, 1.5)            # ROOM CODE
        self.click(900, 777, 0.6)
        self.page.keyboard.press("Control+a")  # le champ garde le code precedent apres un refus
        self.page.keyboard.type(code)
        self.wait(0.5)
        self.click(1800, 1005, 4.0)          # OK

    def start_game(self, with_bots=False):
        """Salle d'attente, hote : OK (au moins 2 humains) ou START WITH BOTS."""
        self.mark = "start"
        if with_bots:
            self.click(1531, 1012, 1.0)
        else:
            self.click(1800, 1005, 1.0)

    def leave_waiting(self):
        self.mark = "leave_waiting"
        self.click(80, 70, 2.5)

    # -- partie : decisions jouees par clic -----------------------------------------------------------------------
    SLOT_X0, SLOT_DX, SLOT_Y = 723.0, 140.4, 720.0   # emplacements du donjon (repere 1920 x 1080)
    DONE_XY = (950, 500)                              # DONE / PASS TURN (BoardUI.action_box)

    def hand_point(self, i, n):
        """Point de saisie de la carte i d'une main de n cartes (eventail BoardUI._fan_target, sans survol)."""
        half = min(float(n - n % 2) * 250.0 * 0.8, 1200.0) * 0.5
        step = 2 * half / (n + 1)
        cx = 960.0 + (-half + 2 * half * (i + 1) / (n + 1))
        left = cx - 87.5                       # la carte suivante recouvre la droite : on prend le milieu de la part visible
        return (left + min(step, 175.0) / 2.0 if i < n - 1 else cx), 930.0

    def my_dungeon(self):
        st = self.state
        return ((st["view"].get("players") or {}).get(str(st["seat"])) or {}).get("dungeon", [])

    def dismiss(self):
        """OK du message « X has left the game. » (fenetre modale : sans lui les clics suivants tombent dans le vide)."""
        if self.msg_pending and not self.gone:
            self.msg_pending = False
            self.shot("msg_%s" % self.name)
            self.click(960, 604, 1.0, "msg_ok")

    def act(self, build_limit=2):
        """Une decision par appel (au plus une toutes les 2,5 s) : boss, defausse d'ouverture, pose, DONE / PASS. Renvoie le nom de l'action ou ''."""
        st = self.state
        if not st or st["view"].get("gameOver") is not None or self.closed:
            return ""
        now = time.time()
        if now - getattr(self, "_t_act", 0) < 2.5 or now - self.t_state < 0.8:
            return ""
        seat, moves = st["seat"], st.get("moves", [])
        types = {m["type"] for m in moves}
        v = st["view"]
        action = ""
        if "pickBoss" in types:
            self.click(945, 965, 0.3, "boss")
            action = "pickBoss"
        elif "openingDiscard" in types:
            self.click(440, 500, 0.5, "discard")
            self.click(565, 500, 0.5, "discard")
            self.click(1605, 475, 0.3, "discard")
            action = "openingDiscard"
        elif seat in (st.get("awaited") or []):
            built = ((v.get("players") or {}).get(str(seat)) or {}).get("buildsThisTurn", 0)
            bm = [m for m in moves if m["type"] == "buildRoom"]
            if bm and built < build_limit and v.get("phase") in ("build", "setup"):
                mv = bm[0]
                hand = ((v.get("players") or {}).get(str(seat)) or {}).get("hand", [])
                i = int(mv["args"][0])
                dg = self.my_dungeon()
                if len(mv["args"]) > 1 and mv["args"][1] is not None:
                    k = int(mv["args"][1])
                else:
                    k = next((j for j, s in enumerate(dg) if not s), 0)
                x, y = self.hand_point(i, len(hand))
                self.mark = "build"
                self.drag(x, y, self.SLOT_X0 + self.SLOT_DX * k, self.SLOT_Y, 0.6)
                action = "buildRoom"
            elif types & {"pass", "passBuild"}:
                self.click(*self.DONE_XY, 0.4, "done")
                action = "done"
        if action:
            self._t_act = time.time()
            self.actions[action] += 1
        return action

    def leave_board(self):
        """Fin de partie : OK du bandeau (retour au titre). Sinon menu en jeu -> QUIT GAME -> QUIT."""
        self.mark = "leave_board"
        if self.state and self.state["view"].get("gameOver") is not None:
            self.click(1560, 1005, 3.0)
        else:
            self.click(1888, 30, 1.0)         # engrenage
            self.click(960, 777, 1.0)         # QUIT GAME : 3e bouton du menu en ligne (InGameMenu : 122,5 + 194,2 x rang, rang 1 = RESUME, hauteur 144)
            self.click(1176, 605, 3.0)        # QUIT
        self.shot("after_leave")



# --------------------------------------------------------------------------------------------------------------------
# Scenarios
# --------------------------------------------------------------------------------------------------------------------

NAMES = ["Alice", "Bob", "Carol", "Dave", "Erin", "Frank"]
SCENARIOS = {
    # nom : sieges du salon, humains (un navigateur chacun ; le premier cree le salon), paquets, (wiki : ignore), demarrage par START WITH BOTS
    "p2": dict(seats=2, humans=2),
    "p3": dict(seats=3, humans=3),
    "p4": dict(seats=4, humans=2),
    "p5": dict(seats=5, humans=2, packs=["crash-landing"], wiki=True),
    "p6": dict(seats=6, humans=3, packs=["crash-landing"], wiki=True),
    "ext": dict(seats=3, humans=2, packs=["players-choice", "hidden-heroes", "next-level"], wiki=True),
    "solo": dict(seats=3, humans=1, bots_start=True),
}


class Run:
    """Un navigateur Playwright et les clients (un contexte chacun) qu'il porte."""

    def __init__(self, pw, stack, browser, shots, size, port):
        self.pw, self.stack, self.shots, self.size = pw, stack, shots, size
        self.url = URL % port
        launch = {"firefox": pw.firefox, "chromium": pw.chromium}[browser]
        self.br = launch.launch(headless=True)
        self.clients = []

    def spawn(self, n, tag="c", first=0):
        out = []
        for i in range(n):
            c = Client(self.br, NAMES[first + i], self.size, self.shots, self.url, "%s%d" % (tag, i))
            c.load()
            c.to_menu()
            out.append(c)
        self.clients += out
        return out

    def close(self):
        self.br.close()


def open_room(cs, spec, speed=None, again=False):
    """Le premier client cree le salon (profil, options, nombre de joueurs, paquets), les autres le rejoignent par le code. Renvoie le code.
    again : les profils existent deja (deuxieme salon du meme navigateur, N-B11) : menu -> WITH FRIENDS directement."""
    host = cs[0]
    wiki = spec.get("wiki", False)
    if speed:
        host.options(speed=speed)
    if speed and not again:  # la vitesse de jeu est un reglage du navigateur : tous les clients l'appliquent
        for c in cs[1:]:
            c.options(speed=speed)
    if again:
        host.to_menu()  # la fin de partie / QUIT GAME ramene a l'ecran titre
        host.friends()
    else:
        host.profile(host.name, 1)
    host.create_room(spec["seats"], spec.get("packs", ()), wiki, spec.get("variants", ()))
    host.wait(1.0)
    if not host.joined:
        raise RuntimeError("salon non cree (erreurs serveur : %s)" % host.errors)
    code = host.joined["code"]
    for i, c in enumerate(cs[1:], 1):
        if again:
            c.to_menu()
            c.friends()
        else:
            c.profile(c.name, 1 + i % 6)
        c.join_room(code)
        if not c.joined or c.joined.get("code") != code:
            raise RuntimeError("%s n'a pas rejoint %s (erreurs : %s)" % (c.name, code, c.errors))
    return code


def lobby_check(cs, spec):
    probs = []
    host = cs[0]
    host.wait(1.5)
    lob = host.lobby or {}
    names = [s["name"] for s in lob.get("seats", [])]
    for i, c in enumerate(cs):
        if names[i:i + 1] != [c.name]:
            probs.append("siege %d : nom %r attendu %r" % (i, names[i:i + 1], c.name))
    want_sets = sorted(spec.get("packs", []))
    got = sorted(s for s in lob.get("sets", []) if not s.endswith("-wiki"))
    if got != want_sets:
        probs.append("paquets du salon %s, voulus %s" % (got, want_sets))
    if lob.get("numPlayers") != spec["seats"]:
        probs.append("numPlayers %s, voulu %s" % (lob.get("numPlayers"), spec["seats"]))
    return probs


def play(cs, max_s, shots_every=0, label="g", hook=None):
    """Fait jouer tous les clients jusqu'a la fin de la partie (gameOver recu partout) ou max_s secondes. hook(secondes) : evenements scenarises."""
    t0 = time.time()
    last_shot = 0
    live = lambda: [c for c in cs if not c.gone]  # noqa: E731
    while time.time() - t0 < max_s:
        if hook:
            hook(time.time() - t0)
        for c in live():
            c.dismiss()
            if len(c.remote_plays) > c.bubble_shots and c.bubble_shots < 3:  # N-B24 : coup distant recu, la bulle doit etre a l'ecran
                c.bubble_shots = len(c.remote_plays)
                c.shot("bubble%d_%s" % (c.bubble_shots, "_".join(str(x) for x in c.remote_plays[-1][1:3])))
            if c.dead_at and c.final is None and not c.closed and not c.quit_lose and c.state["view"].get("phase") not in ("boss", "adventure", "bait") and time.time() - c.dead_t > 4 and len(live()) > 1:
                # N-B52 : mon boss est mort, la partie des autres continue : l'ecran YOU LOSE doit proposer OK, qui quitte le salon sans message chez les autres
                c.quit_lose = True
                c.shot("lose")
                c.click(1560, 1005, 3.0, "lose_ok")
                c.shot("lose_after_ok")
                c.gone = True
                for o in live():
                    o.shot("after_%s_left" % c.name)
                continue
            if not c.closed:
                c.act()
        live()[0].wait(0.4)
        if shots_every and time.time() - last_shot > shots_every:
            last_shot = time.time()
            for c in live():
                c.shot("%s%03d" % (label, int(time.time() - t0)))
        if all(c.final is not None or c.closed for c in live()):
            return time.time() - t0, True
    return time.time() - t0, False


def summarize(cs, dur, done, stack, log_mark, tolerate_illegal=False):
    """Verdict d'une partie : meme resultat partout, aucune fuite de vue, console propre, journal serveur sans erreur."""
    probs = []
    if not done:
        probs.append("partie non terminee")
    finals = [json.dumps(c.final, sort_keys=True) for c in cs if c.final is not None and not c.gone]
    if len(set(finals)) > 1:
        probs.append("resultats differents : %s" % finals)
    for c in cs:
        if c.leaks:
            probs.append("%s : fuite de vue %s" % (c.name, c.leaks[0]))
        if c.inv:
            probs.append("%s : invariants d'awaited %s" % (c.name, c.inv[:2]))
        if c.fd_seen:
            probs.append("%s : salle du dessus face cachee en bait / adventure %s" % (c.name, c.fd_seen[0]))
        for pr in c.console_problems():
            probs.append("%s console %s" % (c.name, pr))
        bad = [e for e in c.errors if e.get("code") in ("bad_message", "bad_move")]
        ill = sum(e.get("code") == "illegal" for e in c.errors)
        if ill > (30 if tolerate_illegal else 5):  # quelques `illegal` sont normaux : un clic part pendant qu'un etat plus recent arrive (course avec l'horloge du serveur)
            bad.append("%d coups illegaux" % ill)
        if bad:
            probs.append("%s : erreurs serveur recues %s" % (c.name, bad[:2]))
    errs = stack.server_errors()[log_mark:]
    if errs:
        probs.append("journal serveur : %s" % errs[:3])
    st = next((c.state for c in cs if c.state), None)
    fin = next((c.final for c in cs if c.final and not c.gone), None)
    winner = (fin or {}).get("winner")
    turn = st["view"].get("turn") if st else None
    return dict(done=done, secs=round(dur), winner=winner, turn=turn, problems=probs,
                clicks={c.name: dict(c.actions) for c in cs}, moves_sent={c.name: c.sent_moves for c in cs},
                states={c.name: c.n_state for c in cs}, remote_plays={c.name: len(c.remote_plays) for c in cs},
                eliminated_at={c.name: c.dead_at for c in cs if c.dead_at}, spell_windows={c.name: dict(c.spell_windows) for c in cs}, illegal={c.name: dict(c.illegal_after) for c in cs if c.illegal_after}, choices={c.name: dict(c.choices) for c in cs})


def run_scenario(run, name, spec, max_s=900, speed=None, shots_every=0):
    cs = run.spawn(spec["humans"], tag=name + "_")
    log_mark = len(run.stack.server_errors())
    t0 = time.time()
    code = open_room(cs, spec, speed)
    lp = lobby_check(cs, spec)
    cs[0].shot("lobby")
    cs[0].start_game(with_bots=spec.get("bots_start", False))
    dur, done = play(cs, max_s, shots_every, "g")
    cs[0].wait(6)  # le bandeau du vainqueur arrive apres la derniere traversee du heros
    for c in cs:
        c.shot("final")
    res = summarize(cs, dur, done, run.stack, log_mark)
    res["problems"] = lp + res["problems"]
    res["code"], res["setup_secs"] = code, round(time.time() - t0 - dur)
    for c in cs:
        c.leave_board()
    return res, cs


# --------------------------------------------------------------------------------------------------------------------
# Scenarios scriptes (hors SCENARIOS) : rejeu de salon, deconnexions, refus, salons simultanes, paquet ferme
# --------------------------------------------------------------------------------------------------------------------

def one_game(run, cs, spec, max_s, speed=None, shots_every=0, again=False, label="g", hook=None, tolerate_illegal=False):
    """Salon -> lobby -> partie -> verdict (une partie complete pour les clients cs, le premier est l'hote)."""
    for c in cs:
        c.reset_game()
    mark = len(run.stack.server_errors())
    t0 = time.time()
    code = open_room(cs, spec, speed, again)
    lp = lobby_check(cs, spec)
    cs[0].start_game(with_bots=spec.get("bots_start", False))
    dur, done = play(cs, max_s, shots_every, label, hook)
    live_cs = [c for c in cs if not c.gone]
    live_cs[0].wait(6)  # le bandeau du vainqueur arrive apres la derniere traversee du heros
    for c in live_cs:
        c.shot(label + "_final")
    res = summarize(cs, dur, done, run.stack, mark, tolerate_illegal)
    res["problems"] = lp + res["problems"]
    res["code"], res["setup_secs"] = code, round(time.time() - t0 - dur)
    print(label, json.dumps(res, ensure_ascii=False, default=str), flush=True)  # verdict garde meme si la partie suivante plante
    return res


def scn_rematch(run, max_s, speed, shots_every):
    """N-B11 : fin de partie -> OK -> menu -> nouveau salon (le meme navigateur) ; puis depart en cours de partie (QUIT GAME) et nouveau salon."""
    a, b = run.spawn(2, tag="rm_")
    spec = dict(seats=2, humans=2)
    out = {}
    out["game1"] = r1 = one_game(run, [a, b], spec, max_s, speed, shots_every, False, "g1")
    for c in (a, b):
        c.leave_board()
    out["game2"] = r2 = one_game(run, [a, b], spec, 60, None, shots_every, True, "g2", hook=None)
    # la partie 2 est interrompue par l'hote (QUIT GAME) : le guest voit « No players to play with. », OK le ramene au titre
    a.leave_board()
    b.wait(3)
    b.shot("g2_after_host_left")
    if not b.msg_pending:
        r2["problems"].append("le depart de l'hote n'a pas ete signale au guest")
    b.dismiss()
    b.wait(2)
    b.shot("g2_guest_title")
    r2["problems"] = [p for p in r2["problems"] if "non terminee" not in p]
    r2["note"] = "partie 2 abandonnee volontairement par l'hote (departs : %s)" % [e for e in b.errors]
    out["game3"] = one_game(run, [a, b], spec, max_s, None, shots_every, True, "g3")
    for c in (a, b):
        c.leave_board()
    return out


def scn_drop(run, max_s, speed, shots_every):
    """3 humains : coupure de liaison de tous (reconnexion automatique, meme siege) a 35 s ; un joueur ferme son onglet a 80 s (30 s de grace puis l'IA joue son siege)."""
    cs = run.spawn(3, tag="dr_")
    ev = {"cut": None, "close": None}

    def hook(t):
        if t > 35 and ev["cut"] is None:
            ev["cut"] = web_serve.Handler.cut_tunnels()
            for c in cs:
                c.shot("cut")
        if t > 80 and ev["close"] is None:
            ev["close"] = round(t)
            cs[2].shot("before_close")
            cs[2].page.close()
            cs[2].gone = True

    res = one_game(run, cs, dict(seats=3, humans=3), max_s, speed, shots_every, False, "g", hook, tolerate_illegal=True)  # un clic double apres la coupure : `illegal` attendu
    res["cut_tunnels"], res["closed_at"] = ev["cut"], ev["close"]
    res["ws_opened"] = {c.name: c.ws_open for c in cs}
    if not ev["cut"]:
        res["problems"].append("aucun tunnel /ws coupe (partie trop courte ?)")
    if ev["cut"] and min(c.ws_open for c in cs[:2]) < 2:
        res["problems"].append("pas de reconnexion automatique apres la coupure : %s" % res["ws_opened"])
    if ev["close"] is None:
        res["problems"].append("la fermeture d'onglet n'a pas eu lieu (partie finie avant 80 s)")
    return res


def scn_multi(run, max_s, speed, shots_every):
    """Deux salons de 2 humains en meme temps + joins refuses : code inconnu, salon complet, partie deja lancee."""
    ra, rb, extra = run.spawn(2, tag="ma_"), run.spawn(2, tag="mb_", first=2), run.spawn(1, tag="mx_", first=4)[0]
    spec = dict(seats=2, humans=2)
    mark = len(run.stack.server_errors())
    t0 = time.time()
    code_a = open_room(ra, spec)
    code_b = open_room(rb, spec)
    probs = []
    if code_a == code_b:
        probs.append("deux salons, un seul code %s" % code_a)
    # refus : Erin tente le salon A (complet), un code inconnu, puis le salon A deja lance
    extra.profile(extra.name, 5)
    extra.join_room(code_a)
    extra.shot("full")
    extra.click(960, 560, 1.5)       # OK du message
    extra.join_room("zzzz")
    extra.shot("wrong_code")
    extra.click(960, 560, 1.5)
    ra[0].start_game()
    rb[0].start_game()
    extra.wait(3)
    extra.join_room(code_a)
    extra.shot("started")
    codes = [e.get("code") for e in extra.errors]
    if codes != ["full", "not_found", "full"]:
        probs.append("joins refuses : codes %s, attendus ['full', 'not_found', 'full']" % codes)
    dur, done = play(ra + rb, max_s, shots_every, "g")
    # chaque salon a son propre resultat : verdict par salon (les clients d'un salon n'ont vu que ses sieges, la vue est controlee a chaque trame)
    # `illegal` toleree : six navigateurs sur un poste, un clic repete avant l'arrivee de l'etat est refuse par le serveur
    res = summarize(ra, dur, done, run.stack, mark, True)
    resb = summarize(rb, dur, done, run.stack, mark, True)
    res["problems"] = probs + res["problems"] + ["salon %s : %s" % (code_b, p) for p in resb["problems"]]
    fa = {json.dumps(c.final, sort_keys=True) for c in ra}
    fb = {json.dumps(c.final, sort_keys=True) for c in rb}
    res["rooms"] = {code_a: [c.name for c in ra], code_b: [c.name for c in rb]}
    res["winners"] = {code_a: res["winner"], code_b: resb["winner"]}
    res["finals_per_room"] = [len(fa), len(fb)]
    res["refused"] = codes
    res["secs_total"] = round(time.time() - t0)
    return res


def scn_closed(run, max_s, speed, shots_every):
    """Paquet ferme demande (l'interface ne le propose pas : le message `create` est complete en route) : le serveur refuse, l'interface l'explique, rien ne plante."""
    c = Client(run.br, "Zoe", run.size, run.shots, run.url, "cl_")
    c.rewrite_create(["iod"])
    c.load()
    c.to_menu()
    mark = len(run.stack.server_errors())
    c.profile(c.name, 2)
    c.create_room(2)
    c.wait(2)
    c.shot("refused")
    probs = []
    codes = [e.get("code") for e in c.errors]
    if codes != ["bad_setup"]:
        probs.append("erreurs recues %s, attendu ['bad_setup']" % codes)
    if c.joined:
        probs.append("un salon a ete cree malgre le paquet ferme : %s" % c.joined)
    probs += c.console_problems()
    probs += ["journal serveur : %s" % e for e in run.stack.server_errors()[mark:][:3]]
    return dict(done=True, problems=probs, errors=c.errors)


EXTRA = {"rematch": scn_rematch, "drop": scn_drop, "multi": scn_multi, "closed": scn_closed}


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--players", type=int, help="nombre de sieges du salon (2-6) : partie ad hoc")
    ap.add_argument("--bots", type=int, default=0, help="sieges d'IA parmi --players (les autres sont des humains, un navigateur chacun)")
    ap.add_argument("--packs", default="", help="paquets (players-choice,hidden-heroes,next-level,crash-landing)")
    ap.add_argument("--scenario", default="", help="nom d'un scenario (%s) ou `all`" % ",".join(list(SCENARIOS) + list(EXTRA)))
    ap.add_argument("--browser", default="chromium", choices=["chromium", "firefox"])
    ap.add_argument("--size", default="960x540", help="fenetre de chaque navigateur")
    ap.add_argument("--shots", default=SHOTS_DEFAULT)
    ap.add_argument("--speed", default="", choices=["", "slow", "normal", "fast"])
    ap.add_argument("--shot-every", type=int, default=0, help="capture d'ecran de chaque client toutes les N secondes de jeu")
    ap.add_argument("--max-secs", type=int, default=900)
    ap.add_argument("--turn-timeout", type=int, default=10, help="delai serveur d'une decision que le script ne sait pas jouer (l'IA la joue ensuite)")
    ap.add_argument("--adventure-timeout", type=int, default=3, help="delai serveur d'un pas d'aventure (s)")
    ap.add_argument("--bot-delay", type=int, default=150, help="delai serveur avant le coup d'un siege IA (ms)")
    ap.add_argument("--web-port", type=int, default=8090)
    ap.add_argument("--ws-port", type=int, default=8091)
    a = ap.parse_args()
    specs = {}
    if a.scenario == "all":
        specs = dict(SCENARIOS)
        specs.update(EXTRA)
    elif a.scenario:
        specs = {a.scenario: (SCENARIOS.get(a.scenario) or EXTRA[a.scenario])}
    elif a.players:
        packs = [p for p in a.packs.split(",") if p]
        specs = {"p%d" % a.players: dict(seats=a.players, humans=a.players - a.bots, packs=packs, wiki=bool(packs) or a.players >= 5)}
    else:
        ap.error("--players ou --scenario")
    from playwright.sync_api import sync_playwright
    w, h = (int(v) for v in a.size.split("x"))
    stack = Stack(a.web_port, a.ws_port, a.turn_timeout, a.adventure_timeout, a.bot_delay, log_dir=a.shots)
    stack.start()
    bad = 0
    try:
        with sync_playwright() as pw:
            for name, spec in specs.items():
                run = Run(pw, stack, a.browser, a.shots, (w, h), a.web_port)
                try:
                    if callable(spec):
                        res = spec(run, a.max_secs, a.speed or None, a.shot_every)
                    else:
                        res, _ = run_scenario(run, name, spec, a.max_secs, a.speed or None, a.shot_every)
                finally:
                    run.close()
                print(name, json.dumps(res, indent=1, ensure_ascii=False, default=str))
                bad += any(r.get("problems") for r in ([res] if "problems" in res else res.values()) if isinstance(r, dict))
    finally:
        stack.stop()
    print("OK" if not bad else "%d scenario(s) en echec" % bad)
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
