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
- Checked by hand in a browser (Godot web export served from a scratch dir): menus, boss pick, discard, build, adventure, gear menu, rules overlay. NOT checked by hand: drag&drop (the browser tool cannot), spell targeting, game-over screen, 3-4 players, audio.

## Known gaps vs the APK
- Target choice: done on the board (dimmed board, bubble, gold pulsing outline on legal rooms / heroes / town heroes / bosses, CANCEL stone, `BoardUI._target_list`); the centred popup list stays only for targets with no board representation (souls, wounds, items, spell stack, pairs of rooms, choose-a-name). Several moves on one target (mode, payment) open a small list. In 3-4 player games the P<n> button of an opponent who has targets turns gold. Activatable-room glow subtler; hand cards slightly different scale.
- Boss pick: carousel like apk_boss00 (click / drag a card to the centre, PLAY BOSS MONSTER! confirms; the opponent's boss stays hidden). The APK also flips the other cards face down after the pick (game_01_boss.png): not done.
- Lane room cards: round type badge (monster / trap, gold = advanced) on the top-left corner as in the APK (it is a room-TYPE icon, not an owner icon). Stacked rooms are not drawn the APK way (older card peeking above the top one, ~28 px up). Boss sprites drawn at native size (clamped to the 300 px platform). Main-menu OPTIONS: no master volume on purpose (the APK has only MUSIC / SOUND / GAME SPEED; MASTER VOLUME exists only in the web client and in our in-game modal).
- Multiplayer screens (`Main.gd` show_multi/profile/friends/waiting) only got font + English, no APK redesign.
- LEVEL UP button is cosmetic (engine levels up at reveal).
- Hand-dragged build over a face-up room on a non-full dungeon places the room at the entrance (engine offers `[i]` only).
- Engine anomaly (multiplayer, to fix when doing online): `pass` from a non-active player in adventure with no pause advances `activePlayer` during another player's hero; with 2+ humans this deadlocks (repro: `UiSmoke.tscn -- --seed=5100 --games=1 --players=3 --humans=3` with the `_auto_pass` guard in `BoardUI` removed). The UI works around it.
- AI never plays some cards (Doc Scarecrow, Scott cancel, Paywall...); Meddling Kids! doesn't blank base passives; some immediate builds only go over an existing room; `implemented` flags in cards.json outdated.
- Rule added that is not in the source (user to confirm): with Crash Landing, the game ends when the hero decks are empty.

## To do (priority order)
1. Finish the exact clone: items above (stacked-room look, hand scale), compare each screen again with `docs/reference` (originals: 01_boot, 11_menu, 12_setup, apk_car00, emu_fix_popup, apk_reveal(options), cont_08_adv4 (build), run2_t1_adv13 (adventure), apk_boss00 (YOU ARE), new2_t1_pass1 (discard); names are unreliable, see INDEX_part*.md, partial). No original capture of spell battle / game over exists: needs the APK on a device/emulator (adb scripts in `tools/capture_apk_*.py`).
2. Play more full games by hand (spells, level up, game over) and fix mechanics bugs.
3. Wiki expansions polish (only after the clone is exact).
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
