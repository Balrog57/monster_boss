#!/usr/bin/env python3
"""Play APK 2.2.6 with screen-state checks so we don't stall on menu/discard."""
from __future__ import annotations

import io
import os
import subprocess
import time
from enum import Enum

from PIL import Image

ADB = r"C:\Program Files\BlueStacks_nxt\HD-Adb.exe"
PKG = "com.dbm.project"
ACTIVITY = "com.dbm.project/md5399b08adcce2dcd4a96d41bd345c86c9.AndroidActivity"
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "docs", "reference")

# 1920×1080 — calibrated on BlueStacks Nxt
OK = (1806, 1006)
GAME_OVER_OK = (1552, 1007)
CONTINUE_CANDS = [(1550, 540), (1243, 569), (1400, 620), (1251, 550)]
TAP_START = (960, 626)
SINGLE = (720, 430)
PLAYERS_2 = (960, 560)
SKIP = (960, 900)
PLAY_BOSS = (945, 973)
PASS = (960, 500)
HAND = (700, 980)
SLOT = (620, 780)
DISCARD_A = (500, 560)
DISCARD_B = (620, 560)


class Phase(str, Enum):
    MENU = "menu"
    EXPANSIONS = "expansions"
    BOSS = "boss"
    DISCARD = "discard"
    BUILD = "build"
    BAIT = "bait"
    ADVENTURE = "adventure"
    GAME_OVER = "game_over"
    UNKNOWN = "unknown"


def adb(*args: str) -> None:
    subprocess.run([ADB, "-s", "emulator-5554", *args], check=False, capture_output=True)


def capture() -> Image.Image:
    raw = subprocess.check_output(
        [ADB, "-s", "emulator-5554", "exec-out", "screencap", "-p"], timeout=25
    )
    if raw[:8] != b"\x89PNG\r\n\x1a\n":
        raw = raw.replace(b"\r\n", b"\n")
    return Image.open(io.BytesIO(raw)).convert("RGB")


def shot(name: str, im: Image.Image | None = None) -> Image.Image:
    os.makedirs(OUT, exist_ok=True)
    if im is None:
        im = capture()
    im.save(os.path.join(OUT, name))
    print(f"  {name}")
    return im


def tap(xy: tuple[int, int], wait: float = 1.5) -> None:
    adb("shell", "input", "tap", str(xy[0]), str(xy[1]))
    time.sleep(wait)


def px(im: Image.Image, x: int, y: int) -> tuple[int, int, int]:
    return im.getpixel((x, y))


def detect_phase(im: Image.Image) -> Phase:
    w, h = im.size
    if w < 1000:
        return Phase.UNKNOWN

    # Title / boot
    if sum(px(im, 960, 626)) < 120 and sum(px(im, 960, 40)) < 120:
        if px(im, 1806, 1006)[1] < 100:
            return Phase.MENU

    # Expansions screen: grey-violet header band (not the player-count screen)
    hdr = px(im, 960, 180)
    if hdr[0] > 70 and hdr[1] > 70 and hdr[2] > 90 and px(im, 960, 400)[0] < 120:
        return Phase.EXPANSIONS

    # Game over green OK (different position)
    go_r, go_g, go_b = px(im, GAME_OVER_OK[0], GAME_OVER_OK[1])
    if go_g > 140 and go_r < 180 and "LOSE" not in Phase.GAME_OVER:
        pass  # fall through — checked below via bright center text

    # Discard overlay: purple banner band
    br = px(im, 900, 225)
    if br[0] > 45 and br[2] > 45 and br[1] < 45:
        return Phase.DISCARD

    # Boss reveal: gold PLAY button, no discard banner
    play = px(im, PLAY_BOSS[0], PLAY_BOSS[1])
    if play[0] > 60 and play[1] > 45 and play[2] < 80:
        if sum(px(im, 960, 500)) < 400:
            return Phase.BOSS

    # PASS / DONE button lit at center
    pass_px = px(im, 960, 500)
    if sum(pass_px) > 500:
        # Distinguish bait (heroes on left) vs build
        town = px(im, 120, 400)
        if town[0] > 80 or town[1] > 80:
            return Phase.BAIT
        return Phase.BUILD

    top = px(im, 960, 40)
    if top[0] > 70 and sum(pass_px) < 200:
        return Phase.ADVENTURE

    # In-board but idle
    if sum(px(im, 960, 980)) > 100:
        return Phase.BUILD

    return Phase.UNKNOWN


def wait_phase(want: Phase, timeout: float = 30, poll: float = 1.0) -> Image.Image:
    deadline = time.time() + timeout
    im = capture()
    while time.time() < deadline:
        phase = detect_phase(im)
        if phase == want:
            return im
        im = capture()
        time.sleep(poll)
    raise TimeoutError(f"phase {want} not reached in {timeout}s (last={detect_phase(im)})")


def ensure_menu_to_match() -> Image.Image:
    im = capture()
    phase = detect_phase(im)
    print(f"start phase: {phase}")

    if phase == Phase.MENU:
        tap(TAP_START, 2.5)
        tap(SINGLE, 2)
        tap(PLAYERS_2, 1.5)
        tap(OK, 3)  # confirm 2 players
        shot("game_00_players.png")
        tap(OK, 3)  # expansions
        shot("game_00_expansions.png")
        tap(SKIP, 1.5)
        tap(SKIP, 1.0)

    im = capture()
    if detect_phase(im) in (Phase.EXPANSIONS, Phase.UNKNOWN):
        for _ in range(3):
            tap(OK, 3)
            im = capture()
            if detect_phase(im) != Phase.EXPANSIONS:
                break
        tap(SKIP, 1.5)
        tap(SKIP, 1.0)

    im = capture()
    phase = detect_phase(im)
    if phase not in (Phase.BOSS, Phase.DISCARD, Phase.BUILD):
        tap((700, 560), 2)

    im = capture()
    phase = detect_phase(im)
    if phase == Phase.DISCARD:
        return im

    deadline = time.time() + 25
    while time.time() < deadline:
        im = capture()
        phase = detect_phase(im)
        if phase == Phase.BOSS:
            break
        if phase == Phase.DISCARD:
            return im
        tap(PLAY_BOSS, 2)
        time.sleep(2)
    else:
        shot("game_01_stuck.png", im)
        raise TimeoutError(f"boss screen not reached (last={detect_phase(im)})")

    shot("game_01_boss.png", im)

    tap(PLAY_BOSS, 3)
    time.sleep(10)
    im = capture()
    if detect_phase(im) in (Phase.BOSS, Phase.EXPANSIONS, Phase.UNKNOWN):
        tap(PLAY_BOSS, 4)
        time.sleep(4)

    im = capture()
    if detect_phase(im) == Phase.DISCARD:
        return ensure_past_discard()
    return im


def ensure_past_discard() -> Image.Image:
    im = capture()
    if detect_phase(im) != Phase.DISCARD:
        return im

    shot("game_02_discard.png", im)
    for attempt in range(6):
        tap(DISCARD_A, 0.5)
        tap(DISCARD_B, 0.5)
        time.sleep(0.4)
        for cx, cy in CONTINUE_CANDS:
            tap((cx, cy), 4)
            im = capture()
            if detect_phase(im) != Phase.DISCARD:
                shot("game_03_build.png", im)
                print(f"  discard cleared via ({cx},{cy}) attempt {attempt}")
                return im
    raise TimeoutError("stuck on opening discard")


def build_and_pass(place: bool = True) -> Image.Image:
    im = capture()
    phase = detect_phase(im)
    if phase not in (Phase.BUILD, Phase.BAIT):
        return im

    if place and phase == Phase.BUILD:
        tap(HAND, 1.2)
        tap(SLOT, 1.8)
        shot(f"game_build_placed_{int(time.time()) % 1000}.png")

    im = capture()
    if sum(px(im, 960, 500)) > 400:
        tap(PASS, 2.5)
    return capture()


def run_adventure(max_steps: int = 16) -> Image.Image:
    im = capture()
    for _ in range(max_steps):
        phase = detect_phase(im)
        if phase in (Phase.BUILD, Phase.BAIT):
            return im
        if phase == Phase.GAME_OVER:
            tap(GAME_OVER_OK, 2)
            return capture()
        if sum(px(im, 960, 500)) > 400:
            tap(PASS, 1.8)
        else:
            tap(OK, 0.8)
            tap((400, 400), 0.6)
            tap(SLOT, 0.6)
        im = capture()
        time.sleep(0.5)
    return im


def play_turn(n: int) -> None:
    print(f"--- turn {n} ---")
    im = capture()
    p = detect_phase(im)
    if p == Phase.DISCARD:
        ensure_past_discard()

    # BUILD: us + AI
    for i, place in enumerate((True, False)):
        im = capture()
        if detect_phase(im) in (Phase.BUILD, Phase.BAIT):
            build_and_pass(place=place)
            shot(f"game_t{n}_build_{i}.png")

    time.sleep(4)
    im = capture()
    shot(f"game_t{n}_reveal.png", im)

    time.sleep(3)
    im = capture()
    shot(f"game_t{n}_post_reveal.png", im)

    im = run_adventure()
    shot(f"game_t{n}_adventure_end.png", im)


def main() -> None:
    print("devices:", subprocess.check_output([ADB, "-s", "emulator-5554", "devices"]).decode().strip())

    # Fresh launch if on menu or stuck
    im = capture()
    if detect_phase(im) in (Phase.MENU, Phase.UNKNOWN) or len(im.tobytes()) < 400_000:
        adb("shell", "am", "force-stop", PKG)
        time.sleep(1.2)
        adb("shell", "am", "start", "-n", ACTIVITY)
        time.sleep(12)
        im = capture()

    if detect_phase(im) == Phase.MENU:
        ensure_menu_to_match()
        ensure_past_discard()
    elif detect_phase(im) == Phase.DISCARD:
        ensure_past_discard()
    elif detect_phase(im) == Phase.BOSS:
        tap(PLAY_BOSS, 3)
        time.sleep(8)
        tap(PLAY_BOSS, 4)
        ensure_past_discard()

    for turn in range(1, 5):
        try:
            play_turn(turn)
        except TimeoutError as e:
            print(f"stop: {e}")
            shot("game_stuck.png")
            break
        im = capture()
        if detect_phase(im) == Phase.MENU:
            break

    shot("game_final.png")
    print("done — game_*.png")


if __name__ == "__main__":
    main()
