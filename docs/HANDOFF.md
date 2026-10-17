# Boss Monster remake — complete project brief and handoff

Written 2026-10-16 for an AI agent (or human) taking over. Self-contained: read this first, then the pointers at the end.
Repo: `C:\Users\Marc\Documents\1G1R\_Programmation\monster_boss` (Windows 11), GitHub `Balrog57/monster_boss`. Work branch `parity/apk-oracle` (all recent work, pushed; `main` is its ancestor, so merging is a fast-forward). The user speaks French; the game UI is English (like the original).

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
  - `godot/data/` `cards.json` (442 cards, the single card-data file; Python writers go through `tools/cards_io.py`), `rules.txt` (in-game rules text, English). `tools/data/apkCardManifest.json` = APK face manifest (tools only, not shipped).
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
- **APK parity (the real correctness metric):** `python tools/parity/apk.py` (seeds 1-3 x 2,3 players, must be 6/6), `python tools/parity/apk.py --seeds 4 5 6 7 --players 2 3 4` (12/12), `python tools/parity/apk.py --decks BaseDeck,PlayerChoice,HiddenHeros,ToolsHeroKind` (6/6). Exit code 1 if any trace is not OK. Never run two in parallel (one Godot at a time); each run wipes its output dir, so give each a distinct `APK_PARITY_OUT` if you ever interleave them.
- Other tools: `src/frontend/godot/tests/AiCensus.tscn` (which wiki moves the AI never plays), `tools/sync_implemented.py` (regenerates `implemented` flags in cards.json; `coverage.gd` checks them), `tools/verify_assets.py` (APK faces, UI assets, base-set counts), `tools/merge_expansions.py` (wiki packs -> cards.json, then runs sync_implemented), `tools/fetch_wiki_cards.py` / `tools/extract_apk_226.py` (APK + wiki extraction; `fetch_wiki_cards` merges into cards.json and keeps hand-added fields), `tools/fetch_expansion_art.py`.
- **Web export (raw Godot, no npm):** `"/c/Tools/Godot/Godot_v4.7.2-stable_win64_console.exe" --headless --path src/frontend --export-release Web godot/build_web/index.html` (Docker does the same in `deploy/Dockerfile`).
- **Web build to try by hand:** `Godot console --headless --path src/frontend --export-release Web <scratchdir>/index.html`, then `python -m http.server 8091 --bind 127.0.0.1` in that dir and open `http://127.0.0.1:8091/index.html`. Browser-tool tips: the Godot canvas needs a `hover` before each `left_click`; refresh a stale `index.pck` with `fetch(url,{cache:'reload'})` then `location.reload()`; synthetic JS pointer events do not drive Godot; `left_click_drag` is too coarse for Godot drags; release builds hide GDScript errors (use the headless suites to find them).

## 5. Current state (all green at commit `2cff735` on `parity/apk-oracle`)
**Engine:** base set + APK extra decks (Player's Choice, Hidden Heroes, Tools of Hero Kind) are bit-identical to the APK oracle on all parity sets. Wiki packs ported: The Next Level (115 cards), Crash Landing (33), Minibosses/RMB (121). AI plays every wiki card sensibly (`AiWiki.gd`, census-verified, base behaviour untouched). Meddling Kids! blanks base room text. 442 cards have art and `implemented` flags; 24 have no implementation (the 20 Tools of Hero Kind items + rooms THK021-024; the APK does nothing with them either).
**UI (cloned from ~115 original APK frames + the C#):** title screen (TAP TO START), 2x2 stone main menu (Single Player, Multiplayer, Options, Rules), player-count carousel, expansions (APK content only; wiki packs appear behind the "Wiki expansions" option, default OFF), options (music/sound/game speed), pixel fonts rebuilt from APK atlases, board layout (phase banner, heroes in town column, right HUD, 5 slots per lane, fanned hand 175x244 with C# geometry, stacked-room peek), boss pick carousel (+ flip, `PLAY BOSS MONSTER!`), opening discard, click/drag build, DONE! button + "STILL WANT TO PASS?" bubble, spells dragged/clicked with gold-bordered board targets, long-press zoom, Freeze ice overlay, adventure without PASS/GO (3 s green timer bar above the hero, 6 s on the spell stack, heroes advance by themselves; GAME SPEED only scales hero animations), "HAS PLAYED A SPELL / ROOM ABILITY" notice, damage/soul/wound animations, game-over banner (winner, crystals, OK -> title, no score panel), pause menu (RESUME / CARD GALLERY / RULES / SETTINGS / QUIT GAME) with rules overlay and master volume (our addition), card gallery (also from main-menu OPTIONS).
**Hand-verified in a browser:** menus, boss carousel + confirm, discard, click build, DONE!, adventure with timer bar and automatic crossing, next turn, pause menu, card gallery, rules overlay.
**Infra:** Godot headless server + `ViewFilter` exist and pass the `online` suite; the web client talks WebSocket via `OnlineClient.gd`. **The old Node server on ZimaOS was stopped on 2026-10-16 by the user's order** (it leaked deck order, boss picks and face-down rooms): `docker stop boss-monster` via `ssh homelab` (192.168.1.98, user marc; alias `zimaos` does not work); container kept (restart policy unless-stopped keeps it down), `boss-monster-db` untouched. Do not restart it. Remove container and volume when the Godot server replaces it.

## 6. Rules decisions already taken
- Truth order: APK C# oracle > `docs/rules/rules.md` + PDFs > card text > old JS. Where the old JS contradicts, Godot follows the C#/rules text (examples: Dark Altar cannot recover itself; spell battle follows `EnqueueAbilityTransaction` priority; TNL setup = 5 rooms + 2 spells).
- Wiki-only changes must never move APK parity (gate behind wiki-pack conditions; the parity harness never calls `AI.gd`).
- Crash Landing end of game: source found (`rules.md` "Changes to Victory Conditions", 5-6 players: game ends when both Hero decks are depleted). Engine is 2-4 players, so it applies only when nothing can change any more (`Match._check_end_or_next_turn`).
- `legal_moves` no longer offers `buildRoom` while `buildBlocked` (Kobold Strike).

## 7. Known gaps vs the APK (small, ordered by value)
1. Not hand-verified: real-mouse drag&drop, spell drag/targeting, the game-over banner, audio (all covered only by headless tests).
2. Card gallery layout not compared pixel-for-pixel; pass-warning bubble and AI-notice offsets set by eye; RIP tombstone not scaled 1.5 like `LoseScene`; soul/wound flash is a plain white flash; LEVEL UP button is cosmetic (engine levels up at reveal).
3. Hand-dragged build over a face-up room on a non-full dungeon puts the room at the entrance (engine only offers `[i]`).
4. Multiplayer screens (`Main.gd` show_multi/profile/friends/waiting) got only font + English, no APK redesign. 3-4 players is paywalled in the APK ("FULL GAME NEEDED"): there is no reference frame, we offer it free.
5. Engine anomaly (matters for multiplayer): `pass` from a non-active player during adventure with no pause advances `activePlayer` in the middle of another player's hero; with 2+ humans this deadlocks (repro: `UiSmoke.tscn -- --seed=5100 --games=1 --players=3 --humans=3` with the `_auto_pass` guard in `BoardUI` removed). The UI currently works around it.
6. Some wiki art is generated "MISSING ART" placeholders (`tools/generate_placeholder_art.py`); Witch's Kitchen (BMA024) rarely used by AI (base behaviour left alone on purpose).

## 8. Reference material
- `docs/reference/apk_orig/` (+ `INDEX.md`): ~115 reliable original 1920x1080 frames (spell drag, timer bar, game over, pause menu, gallery, stacked rooms, hand fan). Older files in `docs/reference/` have **unreliable names** (see `INDEX_part*.md`, partial). Reference dir is gitignored: regenerate by capturing.
- **Capturing the original APK:** BlueStacks instance `Nougat32` has it installed. Start `"C:\Program Files\BlueStacks_nxt\HD-Player.exe" --instance Nougat32`, wait ~75 s, use ONLY `"C:\Program Files\BlueStacks_nxt\HD-Adb.exe" -s emulator-5554 ...` (the Android SDK adb conflicts and kills the server; the Android Studio AVDs are unusable here). Screen 1920x1080; helper scripts `tools/capture_apk_*.py`, `play_apk_*.py`. Mid-drag frames: `input swipe x1 y1 x2 y2 3000` + a second screencap.
- Decompiled C# (`apk-original/decompiled/DBMGame/`) for timings/geometry (hand = `CardPositionComponent`, timer bar durations, `FlipCardBehavior`, `CardAbilityBorder`, etc.).

## 9. What remains to do (priority order, with acceptance criteria)
**A. Finish the clone**
1. Hand-verify in the browser what headless tests cover: win/lose game-over banner and OK -> title, spell drag with a real drag (try the `claude-in-chrome` tools or a real-window Godot run with OS input), spell battle on the stack, LEVEL UP flow, a complete game to the end. Fix what breaks. Accept: one full game played by hand with no visual/logic surprise vs the APK frames.
2. Close the small gaps in section 7 items 2-3 where cheap. Compare each screen again side by side with `apk_orig` frames (render a real window at 1920x1080 and diff).
3. Capture the few missing original frames if needed (win screen needs beating the AI; level-up popup needs XP) and re-compare.
**B. Wiki expansions** only polish remains (art placeholders; rules truth is `docs/rules/rules.md`). Keep parity untouched.
**C. Multiplayer (last)**
1. Fix the engine anomaly (section 7.5) properly in `Match.gd` (then remove the UI workaround), keeping APK parity 6/6, 12/12, 6/6.
2. Redesign multiplayer screens like the APK (create/join/lobby/waiting) using `assets/ui` art; friends-only rooms by code; reconnect/resume (`OnlineClient.try_resume`), "Start with bots", turn timers (server `--turn-timeout`), APK-style UI for 3-4 players (opponent selector P2/P3/P4).
3. Test with 2+ real clients (two browser tabs against the headless server); keep `ViewFilter` whitelisting: any new `G` key must be classified or the `online` suite fails. Never leak hidden info (hands, deck order, face-down rooms, other players' pending choices, private log lines).
**D. Remove the JS scaffolding - DONE**
- Done: `src/backend`, `tests/unit`, `package*.json` and every `.js/.mjs` removed; runners are `tools/run_godot_tests.py` and `tools/parity/apk.py`; CI runs the Godot suites (after `--import`) and the Docker export. `tools/apk-oracle` (.NET) stays.
**E. Deploy**
- Docker: nginx alpine serving the static web export (`export_presets.cfg` already excludes tests and `godot/server`; add brotli for the wasm, correct `application/wasm`, `/ws` WebSocket proxy) + a Godot headless server container (no Postgres). Rewrite `deploy/docker-compose.yml`, `deploy/Dockerfile`, `deploy/DEPLOYMENT.md` (ZimaOS 192.168.1.98, port 8090, Cloudflare tunnel). Remove the stopped `boss-monster` + `boss-monster-db` containers/volume only with the user's OK. Web size target: pck ~38 MB (lossy webp imports already set).
**F. Final (only at the very end)**
- Run the full test + parity suites, `code-review` on the whole diff, merge `parity/apk-oracle` into `main`, delete the extra branch (local + remote, after asking), make sure there is no open PR, no extra worktree/stash, `git status` clean. Update this file and the README.

## 10. Pitfalls and conventions
- Engine files are shared by the APK parity; after ANY engine change run all 3 parity commands (section 4). UI work must not touch `Match.gd/BossEngine.gd/*Abilities.gd/SpellEffects.gd/AI.gd/GameManager.gd` unless fixing a proven engine bug.
- Concurrent headless Godot runs can race on the global class cache (transient parse errors): re-run alone; `godot --headless --import` refreshes it.
- LF/CRLF warnings on commit are harmless. `.uid` files are tracked.
- UI text and `godot/data/rules.txt` are English. Code comments are mostly French or English: match the surrounding file.
- Secrets: none in the repo; the ZimaOS access is via the user's ssh config (aliases `homelab`, `homelab-ts`); never print keys.
- Subagent tips that worked: give each a narrow file scope, tell it not to run git, require `python tools/run_godot_tests.py` green twice, ask for "what still differs"; run Haiku agents for image indexing (they hit request limits after ~30 images each).
