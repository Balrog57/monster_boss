# Handoff — Boss Monster remake (Godot 4 web)

Updated 2026-10-16. Branch `parity/apk-oracle` (not merged into `main`, which is an ancestor: fast-forward possible).

## Working rules (user)
- Claude **orchestrates only**: Sonnet subagents write code, Haiku subagents explore. Claude decides, runs the checks, commits and pushes.
- Commit and push at every green checkpoint.
- **Order of work (user, 2026-10-16):** 1) exact clone of the Android APK (menus AND in-game UI/UX), 2) then the wiki expansions, 3) store removed: everything free, "IN-APP STORE" replaced by in-game RULES, 4) multiplayer last.
- **End state (user):** ONE branch (`main`), NO open PR, everything reviewed (code-review skill), merged, tests green, repo clean (no extra branches/worktrees/stashes). Ask before deleting branches.
- Final product: Godot 4 web export (WASM, no threads) in nginx alpine on ZimaOS (port 8090, Cloudflare tunnel). All JS/Node is temporary scaffolding.
- Rules truth: the original APK (`apk-original/decompiled/DBMGame/`, C#, oracle `tools/apk-oracle`). Wiki expansions: `docs/rules/rules.md` + PDFs, then card text.

## State
- Engine: base + APK decks identical to the APK oracle (parity 6/6, 12/12, 6/6). TNL, Crash Landing, Minibosses ported.
- UI (this session): title screen, 2x2 stone menu, player-count carousel, expansions (no shop/paywall), options (music/sound/speed), Rules viewer (also an overlay from the in-game gear menu), board rebuilt to the APK layout (phase banner, heroes in town, right HUD, fanned hand, YOU ARE..., discard overlay, GO/PASS), pixel fonts built from the APK atlases (`tools/build_bmfonts.py`), all text in English.
- Tests: `npm run test:godot:all` = 9 suites (goldens, coverage, 5 soaks, online, ui smoke). `ui_smoke` is a seeded random human playing complete games through the real UI (options at the top of `tests/ui_smoke.gd`).
- Checked by hand in a browser (Godot web export served from a scratch dir): menus, boss carousel + confirm, discard, build (click), DONE! button, adventure with the green timer bar (heroes advance by themselves), pause menu, card gallery, rules overlay. NOT checked by hand: drag&drop with a real mouse (the browser tool cannot), spell drag/targeting, game-over banner, 3-4 players, audio.

## Known gaps vs the APK
- Target choice: on the board (dimmed board, bubble, gold pulsing outline on legal rooms / heroes / bosses, CANCEL; popup list only for targets with no board representation). Spells are dragged onto targets or clicked (long press / right click = big zoom).
- Boss pick: carousel like apk_boss00 (click / drag, PLAY BOSS MONSTER! confirms, the other cards flip face down, the opponent's boss stays hidden).
- Lane room cards: round type badge (room TYPE icon, gold = advanced) as in the APK; stacked rooms peek 28 px above the top card (DungeonSlot.add_under_cards); boss sprites at native size (clamped to the 300 px platform). Main-menu OPTIONS has no master volume on purpose (the APK has MUSIC / SOUND / GAME SPEED only; master volume is in our pause-menu Settings).
- Multiplayer screens (`Main.gd` show_multi/profile/friends/waiting) only got font + English, no APK redesign.
- LEVEL UP button is cosmetic (engine levels up at reveal).
- APK behaviour implemented from ~115 original frames (docs/reference/apk_orig, local, gitignored; see memory reference-apk-capture-bluestacks): no PASS/GO in adventure (3 s green timer bar above the hero card, 6 s on the spell stack, GAME SPEED only scales hero animations; hotseat/online keep PASS/GO), 'HAS PLAYED A SPELL / ROOM ABILITY' notice, DONE! button + 'STILL WANT TO PASS?' bubble in build, hand fan geometry copied from the C# (175x244), ability glow rings, game over banner (winner, crystals, OK -> title, no score panel), pause menu (RESUME / CARD GALLERY / RULES / SETTINGS / QUIT GAME), card gallery (also from main-menu OPTIONS).
- Still differs: card gallery layout not compared pixel for pixel; pass-warning bubble and AI notice offsets by eye; RIP tombstone not scaled 1.5 like LoseScene; soul/wound flash is a plain white flash; win screen and 3-4 players have NO original frame (3-4 players is paywalled in the APK).
- Hand-dragged build over a face-up room on a non-full dungeon places the room at the entrance (engine offers `[i]` only).
- Engine anomaly (multiplayer, to fix when doing online): `pass` from a non-active player in adventure with no pause advances `activePlayer` during another player's hero; with 2+ humans this deadlocks (repro: `UiSmoke.tscn -- --seed=5100 --games=1 --players=3 --humans=3` with the `_auto_pass` guard in `BoardUI` removed). The UI works around it.
- Wiki polish (2026-10-16, branch parity/apk-oracle): the AI now plays every TNL / CRL / RMB card in a sensible situation (`AiWiki.gd`: "does it change the fate of the active Hero?" / lure simulation; census tool `tests/AiCensus.tscn`, goldens in `tests/goldens_ai.gd`). Meddling Kids! also blanks base-set passives and triggers. Fangroot Garden / Brassknuckle can build in a NEW slot (Wild Monster stays "over an existing Room" as its card says). `implemented` flags regenerated by `tools/sync_implemented.py` and checked by `tests/coverage.gd`. 24 cards have NO implementation: the 20 Tools of Hero Kind items and the 4 Tools rooms (THK021-024), exactly like the APK where items do nothing.
- Crash Landing end of game: source found in docs/rules/rules.md ("Changes to Victory Conditions": 5-6 players, game ends when both Hero decks are depleted, Heroes may remain in town). The engine only has 2-4 players, so the rule is applied there only when nothing can change any more (no Hero lured or at an entrance), see `Match._check_end_or_next_turn`.

## To do (priority order)
1. Finish the exact clone: items above (stacked-room look, hand scale), compare each screen again with `docs/reference` (originals: 01_boot, 11_menu, 12_setup, apk_car00, emu_fix_popup, apk_reveal(options), cont_08_adv4 (build), run2_t1_adv13 (adventure), apk_boss00 (YOU ARE), new2_t1_pass1 (discard); names are unreliable, see INDEX_part*.md, partial). No original capture of spell battle / game over exists: needs the APK on a device/emulator (adb scripts in `tools/capture_apk_*.py`).
2. Play more full games by hand (spells, level up, game over) and fix mechanics bugs.
3. Wiki expansions polish: done for the points above; rule truth for anything else is still docs/rules/rules.md then the card text.
4. Multiplayer: Godot headless server exists (`godot/server`, PROTOCOL.md); redesign the multiplayer screens like the APK; fix the engine anomaly above.
5. **Live leak: DONE 2026-10-16** — the Node server leaked deck order, bossPicks and face-down rooms; the user had it stopped: `docker stop boss-monster` on ZimaOS (ssh alias `homelab`, 192.168.1.98; container stopped not removed, `boss-monster-db` untouched, restart policy unless-stopped keeps it down). Restart only with the Godot server replacement (step 7); remove the containers/volume then.
6. Delete the JS (`src/backend`, `tools/parity` except `apk.mjs` + Godot harness, `tests/unit`, `package.json`); Godot must test itself (replace `npm run test:*` and `tools/run_godot_tests.mjs` by a non-Node runner); keep `tools/apk-oracle`; update CI.
7. Docker: nginx alpine (static `build_web` + brotli wasm + `/ws` proxy) + Godot headless server container; `deploy/docker-compose.yml` (no Postgres), `DEPLOYMENT.md`.
8. Final: code-review, merge into `main`, single branch, no open PR, clean repo.

## How to test the web build by hand
```
/c/Tools/Godot/Godot_v4.7.2-stable_win64_console.exe --headless --path src/frontend --export-release Web <scratchdir>/index.html
python -m http.server 8091 --bind 127.0.0.1   # from <scratchdir>
```
Browser pane tips: the Godot canvas needs a `hover` before each `left_click`; reload with `fetch(..., {cache:'reload'})` then `location.reload()` to avoid a stale `index.pck`; synthetic JS pointer events do not drive Godot.
