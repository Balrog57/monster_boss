# Boss Monster remake — complete project brief and handoff

Written 2026-10-16, updated 2026-10-17, for an AI agent (or human) taking over. Self-contained: read this first, then the pointers at the end.
Repo: `C:\Users\Marc\Documents\1G1R\_Programmation\monster_boss` (Windows 11), GitHub `Balrog57/monster_boss`. Work happens directly on `main` (the former `parity/apk-oracle` branch was merged and removed). The user speaks French; the game UI is English (like the original).

## 1. What this is
A faithful remake of the card game **Boss Monster: Master of the Dungeon** (Brotherwise Games; Android version 2.2.6 by Plain Concepts, package `com.dbm.project`). Each player is a Boss who builds a dungeon of rooms to lure Heroes and steal their Souls (first to 10 Souls wins; 5 Wounds = dead). Phases per turn: BOSS pick (once) -> SETUP (discard 2, build a first room) -> BUILD (place a face-down room / play spells) -> ADVENTURE (Heroes cross dungeons, spell windows) -> reveal/level up.

**Final product (decided):** a **Godot 4 web export** (WASM, Compatibility renderer, single-threaded) served as static files by **nginx alpine** in Docker on the user's ZimaOS homelab (port 8090 behind a Cloudflare tunnel) plus a **Godot headless server** container for online games. The JavaScript/Node scaffolding has been removed (section 9.D); tooling is Python stdlib + a .NET oracle. The original APK decompilation is the **ground truth for rules**.

## 2. User's working rules and priorities (binding)
- **Claude orchestrates only**: Sonnet subagents write code, Haiku subagents explore/index, the orchestrator decides, runs checks, commits and pushes. Commit + push at every green checkpoint, with trailer `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>`.
- **Order of work (user, 2026-10-16):** 1) exact clone of the Android APK (rules AND menus/in-game UI/UX), 2) then the wiki expansions, 3) the in-app store is removed: everything free, "IN-APP STORE" replaced by in-game RULES, 4) **multiplayer last**.
- **End state (user):** ONE branch (`main`), NO open PR, everything reviewed (use the `code-review` skill on the full diff), merged, tests green, repo clean (no extra branches, worktrees, stashes). Ask before deleting branches. Do this only at the very end.
- Confirm before outward-facing/irreversible actions (server shutdowns, force push, branch deletion).

## 3. Repo map
- `apk-original/` the APK + full decompilation (`decompiled/DBMGame/` C#, source of truth for rules, timings, geometry).
- `tools/apk-oracle/` .NET program that runs the original `DBMGame.dll` headless (the **oracle**). `tools/parity/apk.py` drives oracle vs Godot and diffs traces (local only: needs `apk-original/` and the .NET SDK). Keep both.
- `src/frontend/` Godot project (`project.godot`, `export_presets.cfg`, `assets/` = APK-extracted art/audio/fonts, `godot/` = game):
  - `godot/scripts/` engine + UI. Engine: `Match.gd` (rules/moves, `legal_moves`, `apply_move`, state `G`), `BossEngine.gd`, `RoomAbilities.gd`, `SpellEffects.gd`, `SpellTargeting.gd`, `AI.gd`, wiki packs `TnlAbilities.gd/TnlSpells.gd` (The Next Level), `Minibosses.gd/RmbAbilities.gd/RmbSpells.gd` (Minibosses), `AiWiki.gd` (AI for wiki cards), `CardDB.gd`, `GameManager.gd`. UI: `Main.gd` (title, menus, expansions, options), `BoardUI.gd` (in-game board), `CardUI.gd`, `DungeonSlot.gd`, `InGameMenu.gd`, `CardGallery.gd`, `GameOverBanner.gd`, `RulesViewer.gd`, `TimeBar.gd`, `UiKit.gd`, `AudioManager.gd`, `Profile.gd`. Online: `OnlineClient.gd`, `OnlineGameManager.gd`, `NetCodec.gd`.
  - `godot/server/` headless Godot WebSocket server (`Server.gd`, `GameRoom.gd`, `ViewFilter.gd` = per-seat hidden-info filter, `PROTOCOL.md`). Excluded from the web export.
  - `godot/data/` `cards.json` (442 cards, the single card-data file; Python writers go through `tools/cards_io.py`). `tools/data/apkCardManifest.json` = APK face manifest (tools only, not shipped).
  - `godot/tests/` all headless suites (below).
- No `src/backend`, `tests/unit` or `package.json` any more: test entry points are `tools/run_godot_tests.py` and `tools/parity/apk.py`.
- `deploy/` Dockerfile (Godot web export stage + nginx), compose, `deploy/DEPLOYMENT.md`.
- `docs/` rules (`docs/rules/rules.md`, wiki PDFs), reports, `docs/reference/` (**gitignored, local only**: APK screenshots, see section 8).
- `tools/` Python helpers: `run_godot_tests.py` (suite runner), `godot_exe.py` (Godot path: `$GODOT`, the Windows default, else `godot`), `verify_assets.py`, `build_bmfonts.py` (APK SpriteFont -> BMFont), `sync_implemented.py`, capture/extract scripts.
- `.github/workflows/ci.yml` CI: `godot` job (import the project, then `python3 tools/run_godot_tests.py`) and `export` job (docker build + curl checks). No parity in CI: it needs the local oracle (`DBMGame.dll` from the gitignored `apk-original/`).
- `AGENTS.md` placement rules per role (frontend, deploy, security, docs, tools).

## 4. How to run and test (Windows; Git Bash and PowerShell both available)
- Godot 4.7.2 console exe: `/c/Tools/Godot/Godot_v4.7.2-stable_win64_console.exe` (`godot` on Linux/CI). Headless run: `--headless --path src/frontend res://godot/tests/<Scene>.tscn`.
- **`python tools/run_godot_tests.py`** (~2-3 min) = 9 suites, all must print OK: goldens, coverage, soak, soak APK decks, soak TNL, soak Minibosses, soak all packs, online, ui smoke. Any `SCRIPT ERROR` in the output fails a suite (the runner checks the marker, since Godot on Windows does not propagate the exit code). `ui_smoke` (`tests/ui_smoke.gd`, `UiSmoke.tscn`, options documented at the top: `--games --seed --players --humans --sets --style --turns --anim`) plays complete seeded games through the real UI code paths, with checks after every gesture.
- **APK parity (the real correctness metric):** `python tools/parity/apk.py` (seeds 1-3 x 2,3 players, must be 6/6), `python tools/parity/apk.py --seeds 4 5 6 7 --players 2 3 4` (12/12), `python tools/parity/apk.py --decks BaseDeck,PlayerChoice,HiddenHeros,ToolsHeroKind` (6/6). Exit code 1 if any trace is not OK. Never run two in parallel (one Godot at a time); each run wipes its output dir, so give each a distinct `APK_PARITY_OUT` if you ever interleave them. The trace replay (`ApkParityTrace.gd`) presses DONE (`passBuild`) after each replayed human-seat build because the oracle's AI ends its build turn by itself.
- Other tools: `src/frontend/godot/tests/AiCensus.tscn` (which wiki moves the AI never plays), `tools/sync_implemented.py` (regenerates `implemented` flags in cards.json; `coverage.gd` checks them), `tools/verify_assets.py` (APK faces, UI assets, base-set counts), `tools/merge_expansions.py` (wiki packs -> cards.json, then runs sync_implemented), `tools/fetch_wiki_cards.py` / `tools/extract_apk_226.py` (APK + wiki extraction; `fetch_wiki_cards` merges into cards.json and keeps hand-added fields), `tools/fetch_expansion_art.py`.
- **Web export (raw Godot, no npm):** `"/c/Tools/Godot/Godot_v4.7.2-stable_win64_console.exe" --headless --path src/frontend --export-release Web godot/build_web/index.html` (Docker does the same in `deploy/Dockerfile`). Boot splash: `project.godot` uses `assets/ui/backgrounds/loading_bg.png` on `#270000` instead of the Godot logo.
- **Web build to try by hand:** `Godot console --headless --path src/frontend --export-release Web <scratchdir>/index.html`, then `python -m http.server 8091 --bind 127.0.0.1` in that dir and open `http://127.0.0.1:8091/index.html`. Browser-tool tips: the Godot canvas needs a `hover` before each `left_click`; refresh a stale `index.pck` with `fetch(url,{cache:'reload'})` then `location.reload()`; synthetic JS pointer events do not drive Godot; `left_click_drag` is too coarse for Godot drags; release builds hide GDScript errors (use the headless suites to find them).

## 5. Current state (2026-10-17, branch `main`, everything pushed, CI green)
**Verified:** `python tools/run_godot_tests.py` 9/9; APK parity `python tools/parity/apk.py` 6/6, `--seeds 4 5 6 7 --players 2 3 4` 12/12, `--decks BaseDeck,PlayerChoice,HiddenHeros,ToolsHeroKind` 6/6 (local only, needs the gitignored oracle); CI = `godot` job + `export` job (docker build web + server, curl checks incl. WebSocket 101) green.
**Engine:** base set + APK extra decks (Player's Choice, Hidden Heroes, Tools of Hero Kind) bit-identical to the APK oracle. Wiki packs ported: The Next Level (115), Crash Landing (33), Minibosses/RMB (121). `Match.gd` no longer lets a non-active seat pass during adventure outside pause/stack (APK `GameBoard.ChooseNextActivePlayer`); the old UI workaround is gone. Building over a face-up room before the dungeon is full is a legal move (`Boss.CanBuildRoom`) and the AI scores it (`AiWiki.gd`, APK `RoomCalculator`), so AI and humans share the same legal moves. Wiki census (`AiCensus.tscn`) is PASS with an allowlist. 442 cards; 24 have `implemented=false` (Tools of Hero Kind items/rooms, which the APK does nothing with either).
**UI (cloned from original APK frames + the C#):** menus, boss carousel, discard, build, DONE!, timer bar, spells, pause menu, gallery, rules overlay (see git history of this file for the full list) plus, this session: LEVEL UP boss zoom and on-board room choices (APK `ShowZoomCard` / `CardSelector`); APK card carousel for off-board choices, scrollable town column, tap-to-zoom bubbles; pixel pass (hero cards at the entrance, LoseScene layout, pause menu, notices, sidebar, zoom sizes, EPIC header); phase-by-phase audit (boss pick dim, discard band + diamond CONTINUE, hand-size drag, room flip reveal, BAIT plate and hero card flight, hero sprite crossing with HP heart and room focus, boss hit glow, level-up banner, notice target outlines). Robustness: the click is kept alive during a hand refresh, boss-pick race with the AI fixed, timer windows reset only on hero steps/spells. Wiki UI: hand-card menus for coin/miniboss moves, APK backgrounds for wiki bosses, legible placeholders (107 RMB cards still have placeholder art; TNL038 has real art now).
**Flow / UI (2026-10-18):** the boss pool is every boss of the selected decks; a built room is revocable until DONE (`undoBuild`, human seats only, see `server/PROTOCOL.md`); wiki expansions are on by default; the rules screen shows only the official rulebook pages (base 10th Anniversary + Next Level, Minibosses, Crash Landing: one tab per book, `assets/rules/<book>/pNN.webp`, generated from `docs/rules/*.pdf` by `tools/render_rules_pages.py`; no hand-written rules text); the gallery follows the APK order (CardNumber descending) and hides Tools and BMA023/033.
**Multiplayer (APK screens):** PLAY ONLINE / PASS AND PLAY; WORLDWIDE shows the APK "Unable to join public rooms" box; WITH FRIENDS NEW GAME / ROOM CODE (4-letter codes without I/O); name + avatar scroller; waiting-room panel with WINS/DEFEATS local counters; turn countdown. PASS AND PLAY: the view follows the active human seat with the APK hand-over (hand slides down 0.5 s, lanes fade, seat switch, fade in, hand slides up) in boss/setup/build phases; the PLAYER n seat bar still exists. The web client uses the page origin (`ws(s)://<host>/ws`). Tested by hand with two browser tabs against the real server: create/join, boss pick, discard, build, resume after a page reload, the AI takes over a closed tab's seat after the timeout. `ViewFilter` whitelists every `G` key (hidden info never leaves the server); WINS/DEFEATS sent by clients are cosmetic and unverified.
**Pixel comparison:** `src/frontend/godot/tests/CaptureScreens.tscn` (windowed run, see the header of `capture_screens.gd`) writes `docs/reference/godot_screens/` (gitignored); `COMPARISON.md` and `PHASES.md` in that folder hold the comparison with `apk_orig` (local only).
**Deployed (ZimaOS homelab 192.168.1.98:8090, behind the Cloudflare tunnel):** `boss-monster-web` = nginx static Godot export (gzip_static, `no-cache`, PWA off), `boss-monster-server` = Godot headless multiplayer server, nginx proxies `/ws` (the server port is not published). The old Node container, `boss-monster-db` and the `boss_db` volume were removed with the owner's approval. The homelab clone tracks `main`. Games live in memory only: restarting the server container erases them.
**Caveat:** the in-app browser pane throttles hidden tabs, so timings seen there (timer bars, AI delays) are not representative.

## 6. Rules decisions already taken
- Truth order: APK C# oracle > `docs/rules/rules.md` + PDFs > card text > old JS. Where the old JS contradicts, Godot follows the C#/rules text (examples: Dark Altar cannot recover itself; spell battle follows `EnqueueAbilityTransaction` priority; TNL setup = 5 rooms + 2 spells).
- Wiki-only changes must never move APK parity (gate behind wiki-pack conditions; the parity harness never calls `AI.gd`).
- Crash Landing end of game: source found (`rules.md` "Changes to Victory Conditions", 5-6 players: game ends when both Hero decks are depleted). Engine is 2-4 players, so it applies only when nothing can change any more (`Match._check_end_or_next_turn`).
- `legal_moves` no longer offers `buildRoom` while `buildBlocked` (Kobold Strike).

## 7. Known differences vs the APK (honest list, ordered by value)
**Rules / flow**
1. The engine does not split BaitPhase into its own step (the lure runs in one go when the build ends; the BAIT plate is UI only). Justified, no rule gap: `GameBoard.AssignHeroesToDungeons` (`GameBoard.cs` ~1220-1239) has the same order (reveal, extra build, reveal, lure), the same criteria, and no trigger or choice inside, so no observable state sits between the two. Only the animation could differ (lot 1.3).
2. A room ability activates in one click (APK: zoom, then tap).
3. `BMA029` / `BMA015` position factors read `dungeon[0]` in the AI; RMB063 is never offered in census runs; 24 THK cards are `implemented=false` (the APK ignores them too).
4. The engine is 2-4 players. The APK paywalls 3-4 players ("FULL GAME NEEDED"); we offer it free.
**UI**
5. The APK keeps the greyed hand behind the end screen; we do not.
6. Wiki: the EXTRA MOVES button does not exist in the APK; wiki bosses reuse APK backgrounds and show a card instead of a sprite; 107 RMB cards still show placeholder art.
7. Not hand-verified with real mouse input: OS-level spell drag and audio (the browser pane cannot drive Godot drags precisely). Card gallery not compared pixel-for-pixel (it does show the alt-art tiles: Room/Spell cards with `AlternativeArts` get one tile per copy, art cycling a,b,a… as in `ScrollCardBehavior.AddElements`); RIP tombstone not scaled like `LoseScene`.
**Multiplayer**
8. PASS AND PLAY accepts 2-4 players (APK: 2). WORLDWIDE matchmaking is absent (APK-style error box only). NEW GAME fixes the seat count. No fade transitions between online screens.
9. Games are in memory (no persistence); WINS/DEFEATS are client-declared and cosmetic.
**Tooling**
10. Parity is local only (oracle DLL under the gitignored `apk-original/`, .NET SDK needed); CI cannot run it.

## 8. Reference material
- `docs/reference/apk_orig/` (+ `INDEX.md`): ~115 reliable original 1920x1080 frames (spell drag, timer bar, game over, pause menu, gallery, stacked rooms, hand fan). Older files in `docs/reference/` have **unreliable names** (see `INDEX_part*.md`, partial). Reference dir is gitignored: regenerate by capturing.
- **Capturing the original APK:** BlueStacks instance `Nougat32` has it installed. Start `"C:\Program Files\BlueStacks_nxt\HD-Player.exe" --instance Nougat32`, wait ~75 s, use ONLY `"C:\Program Files\BlueStacks_nxt\HD-Adb.exe" -s emulator-5554 ...` (the Android SDK adb conflicts and kills the server; the Android Studio AVDs are unusable here). Screen 1920x1080; helper scripts `tools/capture_apk_full_turn.py`, `tools/play_apk_robust.py`. Mid-drag frames: `input swipe x1 y1 x2 y2 3000` + a second screencap.
- Decompiled C# (`apk-original/decompiled/DBMGame/`) for timings/geometry (hand = `CardPositionComponent`, timer bar durations, `FlipCardBehavior`, `CardAbilityBorder`, etc.).

## 9. What remains to do (priority order, with acceptance criteria)
A (clone), B (wiki), C (multiplayer), D (JS scaffolding removal) and E (deploy) are done; section 5 says what is verified.
**F. Final merge: Done** (merged into `main`, extra branch removed, homelab clone tracks `main`).
Plan for the remaining work (parts 1-3): `docs/plans/README.md`.
**Optional**
- **A4. BlueStacks captures** of the missing original frames (victory screen, level-up popup, online lobby/waiting room: see section 8), then re-compare with `CaptureScreens.tscn` and close gaps.
- **Owner check, Cloudflare:** open the public hostname through the tunnel with Rocket Loader disabled for it (Speed > Optimization) and WebSockets enabled; confirm `/ws` answers 101 (`deploy/DEPLOYMENT.md` sections 7-8) and that no stale service worker keeps an old page.
- The items of section 7, cheapest first: UI-only ones (greyed hand behind the end screen, zoom-then-tap room ability); engine ones (a real bait phase) must keep parity 6/6, 12/12, 6/6; real art for the 107 RMB placeholders (`tools/generate_placeholder_art.py`) if a source appears; WORLDWIDE matchmaking and online fades only if the owner asks.

## 10. Pitfalls and conventions
- Engine files are shared by the APK parity; after ANY engine change run all 3 parity commands (section 4). UI work must not touch `Match.gd/BossEngine.gd/*Abilities.gd/SpellEffects.gd/AI.gd/GameManager.gd` unless fixing a proven engine bug.
- Concurrent headless Godot runs can race on the global class cache (transient parse errors): re-run alone; `godot --headless --import` refreshes it.
- LF/CRLF warnings on commit are harmless. `.uid` files are tracked.
- UI text is English. Code comments are mostly French or English: match the surrounding file.
- Secrets: none in the repo; the ZimaOS access is via the user's ssh config (aliases `homelab`, `homelab-ts`); never print keys.
- Subagent tips that worked: give each a narrow file scope, tell it not to run git, require `python tools/run_godot_tests.py` green twice, ask for "what still differs"; run Haiku agents for image indexing (they hit request limits after ~30 images each).
