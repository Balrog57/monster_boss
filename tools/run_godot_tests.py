#!/usr/bin/env python3
"""Lance les suites Godot headless, une par une, et echoue si un marqueur de succes manque ou si la sortie contient « SCRIPT ERROR ».

Godot sous Windows ne propage pas toujours le code de sortie : on verifie la sortie.
Usage : python tools/run_godot_tests.py      (env GODOT = chemin de l'executable, optionnel)
"""
import os
import re
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from godot_exe import godot_exe  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
T = "res://godot/tests/"
SOAK_ALL = "players-choice,hidden-heroes,tools,next-level,crash-landing,minibosses"
SUITES = [
    ("goldens", T + "Goldens.tscn", "GOLDENS OK", []),
    ("coverage", T + "Coverage.tscn", "COVERAGE OK", []),
    ("soak", T + "Soak.tscn", "SOAK OK", []),
    ("soak APK decks", T + "Soak.tscn", "SOAK OK", ["--", "--sets=players-choice,hidden-heroes,tools"]),
    ("soak The Next Level", T + "Soak.tscn", "SOAK OK", ["--", "--sets=next-level", "--runs=4"]),
    ("soak Minibosses", T + "Soak.tscn", "SOAK OK", ["--", "--sets=minibosses", "--runs=4"]),
    ("soak all packs", T + "Soak.tscn", "SOAK OK", ["--", f"--sets={SOAK_ALL}", "--runs=3"]),
    ("online", T + "OnlineTest.tscn", "ONLINE OK", []),
    ("ui smoke", T + "UiSmoke.tscn", "UISMOKE OK", []),
]


def run(scene: str, args: list[str]) -> str:
    p = subprocess.Popen([godot_exe(), "--headless", "--path", os.path.join(ROOT, "src", "frontend"), scene, *args],
                         stdout=subprocess.PIPE, stderr=subprocess.STDOUT, stdin=subprocess.DEVNULL)
    try:
        out, _ = p.communicate(timeout=300)
    except subprocess.TimeoutExpired:
        # On tue l'arbre de CE run seulement (un taskkill global tuerait aussi l'editeur / d'autres suites).
        if os.name == "nt":
            subprocess.run(["taskkill", "/F", "/T", "/PID", str(p.pid)], capture_output=True)
        else:
            p.kill()
        out, _ = p.communicate()
    return out.decode("utf-8", errors="replace")


def main() -> int:
    failed = 0
    for label, scene, marker, args in SUITES:
        out = run(scene, args)
        if marker in out and "SCRIPT ERROR" not in out:
            print(f"[godot] {label}: OK", flush=True)
            continue
        failed += 1
        print(f"[godot] {label}: ECHEC", flush=True)
        print("\n".join([l for l in out.splitlines() if re.search(r"ERROR|ECHEC|SCRIPT", l)][:10]), flush=True)
    print(f"[godot] {len(SUITES) - failed}/{len(SUITES)} suites OK")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
