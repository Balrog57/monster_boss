#!/usr/bin/env python3
"""Test de fumee de l'export web dans un vrai navigateur (Playwright) : demarrage, menus, une partie a 2, redimensionnement.

Echoue (code 1) si la console contient une erreur ou un avertissement non prevu, si le canvas reste noir, si un clic n'a aucun effet
visible, ou si le redimensionnement en direct deforme le rendu. Les clics sont des clics souris reels dans le repere 1920 x 1080 du jeu
(centre sur la fenetre, voir pt()).

Prerequis : python -m pip install playwright && python -m playwright install chromium firefox webkit
Usage :
    python tools/web_smoke.py --serve                      # sert src/frontend/godot/build_web (voir tools/web_serve.py) puis teste Chromium
    python tools/web_smoke.py --serve --browser firefox --size 1440x1080 --shots docs/reference/web/smoke
    python tools/web_smoke.py --url http://192.168.1.98:8090/ --browser webkit
Navigateurs : chromium, firefox, webkit (moteurs de Playwright) ou chrome / msedge (installes sur le poste, `--browser chrome`).
"""
import argparse
import hashlib
import os
import re
import sys
import threading
import time

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

# Messages de console connus et inoffensifs, par navigateur (a relire a chaque montee de Godot / de navigateur).
NO_AUDIO_ALLOW = [r"doesn't support sample playback", r"start_sample_playback"]  # build WebKit de Playwright sous Windows : pas d'AudioContext (rien a voir avec Safari)
ALLOW = [
    r"glBlitFramebuffer: Read and write color attachments cannot be the same image",  # WebKit : couche GL, sans effet visible
    r"WEBGL_polygon_mode",  # WebKit : extension non portable activee par Godot
    r"CONTEXT_LOST_WEBGL: loseContext",  # Chromium sans tete : contexte jetable de la sonde WebGL du shell Godot (Engine.getMissingFeatures), a l'etape de demarrage
    r"GPU stall due to ReadPixels",  # Chromium : provoque par page.screenshot() sur un canvas WebGL, pas par le jeu
    r"exception handling 'try' instruction is deprecated",  # Firefox : avertissement d'Emscripten (instruction wasm `try`)
]


def pt(x, y, w, h):
    """Point (x, y) du repere de maquette 1920 x 1080 -> pixels de la fenetre (scene centree, largeur utile de Vp.gd)."""
    usable = min(1920.0, max(1440.0, w / h * 1080.0))
    s = min(w / usable, h / 1080.0)
    return w / 2 + (x - 960) * s, h / 2 + (y - 540) * s


class Smoke:
    def __init__(self, page, w, h, shots):
        self.page, self.w, self.h, self.shots = page, w, h, shots
        self.logs = []
        self.fail = []
        self.mark = "demarrage"  # derniere etape : indiquee dans les problemes de console
        page.on("console", lambda m: self.logs.append((m.type, m.text, self.mark)))
        page.on("pageerror", lambda e: self.logs.append(("pageerror", str(e), self.mark)))
        page.on("crash", lambda: self.logs.append(("crash", "page crashed", self.mark)))
        self.last = None

    def snap(self, name=None):
        png = self.page.screenshot()
        if name and self.shots:
            os.makedirs(self.shots, exist_ok=True)
            with open(os.path.join(self.shots, name + ".png"), "wb") as f:
                f.write(png)
        return png

    def click(self, x, y, name, wait=1.2, effect=True):
        """Clic reel ; echoue si l'ecran ne change pas (le clic n'a pas atteint le jeu)."""
        self.mark = name
        before = hashlib.md5(self.snap()).hexdigest()
        px, py = pt(x, y, self.w, self.h)
        self.page.mouse.click(px, py)
        self.page.wait_for_timeout(int(wait * 1000))
        png = self.snap(name)
        if effect and hashlib.md5(png).hexdigest() == before:
            self.fail.append("clic sans effet : " + name)
        return png

    def drag(self, x0, y0, x1, y1, name, wait=1.2):
        m = self.page.mouse
        p0, p1 = pt(x0, y0, self.w, self.h), pt(x1, y1, self.w, self.h)
        m.move(*p0)
        m.down()
        for i in range(1, 21):
            m.move(p0[0] + (p1[0] - p0[0]) * i / 20, p0[1] + (p1[1] - p0[1]) * i / 20)
            self.page.wait_for_timeout(20)
        m.up()
        self.page.wait_for_timeout(int(wait * 1000))
        self.snap(name)

    def check(self, cond, msg):
        if not cond:
            self.fail.append(msg)

    def console_problems(self):
        out = []
        for t, m, step in self.logs:
            if t in ("error", "warning", "pageerror", "crash") and not any(re.search(a, m) for a in ALLOW):
                out.append("%s [apres %s]: %s" % (t, step, m[:300]))
        return out


def run(args):
    from playwright.sync_api import sync_playwright

    w, h = (int(v) for v in args.size.split("x"))
    with sync_playwright() as p:
        name = args.browser
        if name in ("chrome", "msedge"):
            br = p.chromium.launch(channel=name, headless=not args.headed)
        else:
            br = getattr(p, name).launch(headless=not args.headed)
        page = br.new_context(viewport={"width": w, "height": h}).new_page()
        s = Smoke(page, w, h, args.shots)
        t0 = time.time()
        page.goto(args.url)
        page.wait_for_function("document.querySelector('canvas') && document.querySelector('canvas').width > 0", timeout=120000)
        page.evaluate("window.__f=[];(function f(t){window.__f.push(t);requestAnimationFrame(f)})(0)")
        page.wait_for_timeout(4000)
        if page.evaluate("typeof AudioContext === 'undefined' && typeof webkitAudioContext === 'undefined'"):
            print("note : ce navigateur n'a pas de Web Audio ; les avertissements d'echantillons sonores sont ignores")
            ALLOW.extend(NO_AUDIO_ALLOW)
        s.check(any("WebGL 2" in l[1] for l in s.logs), "WebGL 2 non journalise par le moteur (pas de contexte WebGL 2 ?)")
        s.check(any("Godot Engine" in l[1] for l in s.logs), "le moteur n'a rien journalise (demarrage echoue ?)")
        print("demarrage : %.1f s, %s" % (time.time() - t0, page.evaluate("navigator.userAgent")))
        title = s.snap("01_title")
        s.check(len(title) > 50000, "ecran titre vide ou noir (%d octets)" % len(title))

        s.click(960, 640, "02_menu")                       # TAP TO START
        s.click(710, 615, "03_options")                    # OPTIONS
        s.click(80, 70, "04_back")                         # fleche retour
        s.click(1240, 615, "05_rules")                     # RULES
        s.click(80, 70, "06_back")
        s.click(710, 615, "07_options")
        s.click(960, 517, "08_settings")                   # SETTINGS
        s.click(80, 70, "09_back")
        s.click(960, 679, "10_gallery", wait=2.5)          # CARD GALLERY
        s.click(260, 150, "11_back", wait=2.5)             # fleche de la galerie
        s.click(960, 841, "12_credits", wait=2.5)          # CREDITS
        s.click(80, 70, "13_back", wait=2.5)
        s.click(80, 70, "14_menu", wait=2.5)
        s.click(710, 405, "15_single")                     # SINGLE PLAYER -> proposition du tutoriel
        s.click(1175, 600, "16_players", wait=2.5)         # CANCEL
        s.click(1800, 1005, "17_expansions", wait=2.5)     # OK (2 joueurs)
        s.click(1800, 1005, "18_boss_pick", wait=12)       # OK -> tirage du boss
        s.click(945, 965, "19_discard", wait=6)            # PLAY BOSS MONSTER!
        s.click(440, 500, "20_sel1", wait=1)               # defausse de 2 cartes
        s.click(565, 500, "21_sel2", wait=1.2)
        s.click(1605, 475, "22_board", wait=5)             # CONTINUE
        s.click(1888, 30, "22b_pause")                     # engrenage : menu pause (avant tout tour : aucune fenetre de carte ne peut le masquer)
        s.click(960, 190, "22c_resume")                  # RESUME du menu pause
        s.drag(680, 990, 723, 720, "23_room_placed")       # une salle
        s.click(950, 500, "24_done", wait=3)               # DONE / PASS TURN
        for i in range(3):
            s.drag(470 + 160 * i, 1000, 863 + 140 * i, 720, "25_t%d_room" % i, wait=0.8)
            s.click(950, 500, "26_t%d_pass" % i, wait=3.5, effect=False)
        page.evaluate("window.__f=[]")
        page.wait_for_timeout(3000)
        n = page.evaluate("window.__f.length")
        fps = n / 3.0
        print("fps rAF sur le plateau : %.0f" % fps)
        s.check(fps >= args.min_fps, "fps %.0f < %d" % (fps, args.min_fps))

        # Redimensionnement en direct : la largeur utile suit (keep + canvas_resize_policy adaptatif) ; la capture ne doit pas etre en lettre-box.
        for sz in ("1440x1080", "2560x1080", "1600x1000", "1920x1080"):
            sw, sh = (int(v) for v in sz.split("x"))
            s.mark = "resize " + sz
            page.set_viewport_size({"width": sw, "height": sh})
            s.w, s.h = sw, sh
            page.wait_for_timeout(2500)
            png = s.snap("29_resize_" + sz)
            cw = page.evaluate("[document.querySelector('canvas').width, document.querySelector('canvas').height]")
            s.check(cw == [sw, sh], "canvas %s apres redimensionnement en %s" % (cw, sz))
            s.check(page.evaluate("document.documentElement.scrollWidth <= innerWidth && document.documentElement.scrollHeight <= innerHeight"), "barres de defilement a " + sz)
            if sz == "1440x1080" and args.browser != "webkit":  # (la capture WebKit de Playwright sous Windows est noire apres tout redimensionnement, meme pour une page WebGL minimale) 4:3 : aucune bande noire attendue en haut ni en bas (largeur utile 1440)
                s.check(rows_dark(png, sw, sh), "bandes noires a 1440x1080 : la largeur utile n'a pas suivi")
        s.mark = "vue etroite"
        page.set_viewport_size({"width": 390, "height": 844})  # etroit : ni plantage ni erreur
        page.wait_for_timeout(2000)
        s.snap("30_narrow")
        s.check(page.evaluate("!!document.querySelector('canvas')"), "canvas disparu en vue etroite")

        probs = s.console_problems()
        for pr in probs:
            s.fail.append("console " + pr)
        br.close()
    for f in s.fail:
        print("ECHEC :", f)
    print("OK" if not s.fail else "%d echec(s)" % len(s.fail))
    return 1 if s.fail else 0


def rows_dark(png, w, h):
    """Vrai si le haut et le bas de la capture ne sont PAS des bandes noires uniformes (rend l'image en 8 bits via le decodeur PNG de Pillow si present)."""
    try:
        from PIL import Image
        import io
        im = Image.open(io.BytesIO(png)).convert("L")
        for y in (int(h * 0.03), int(h * 0.97)):
            row = [im.getpixel((x, y)) for x in range(0, w, max(1, w // 40))]
            if max(row) <= 6:
                return False
        return True
    except ImportError:
        return True  # sans Pillow, ce controle est saute


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--url", default="http://127.0.0.1:8090/")
    ap.add_argument("--serve", action="store_true", help="sert build_web avec tools/web_serve.py pendant le test (port de --url)")
    ap.add_argument("--browser", default="chromium", choices=["chromium", "firefox", "webkit", "chrome", "msedge"])
    ap.add_argument("--size", default="1920x1080")
    ap.add_argument("--shots", default="", help="dossier des captures (ex. docs/reference/web/smoke)")
    ap.add_argument("--headed", action="store_true", help="fenetre visible (GPU reel ; sinon sans tete, rendu logiciel)")
    ap.add_argument("--min-fps", type=int, default=15)
    a = ap.parse_args()
    if a.serve:
        import web_serve
        from http.server import ThreadingHTTPServer
        web_serve.Handler.root = os.path.normpath(os.path.abspath(web_serve.ROOT_DEFAUT))
        os.environ["WEB_SERVE_QUIET"] = "1"
        port = int(re.search(r":(\d+)", a.url).group(1))
        srv = ThreadingHTTPServer(("127.0.0.1", port), web_serve.Handler)
        threading.Thread(target=srv.serve_forever, daemon=True).start()
    sys.exit(run(a))


if __name__ == "__main__":
    main()
