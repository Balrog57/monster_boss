# Handoff — Boss Monster remake (Godot 4 web)

Updated 2026-10-16. Branch `parity/apk-oracle` (not merged into `main`). Last pushed commit: `acb2c87`.

## Working rules (user)
- Claude **orchestrates only**: Sonnet subagents write code, Haiku subagents explore. Claude decides, runs the checks, commits and pushes.
- Commit and push at every green checkpoint.
- Final product: Godot 4 web export (WASM, Compatibility, no threads) served by nginx alpine on ZimaOS (port 8090, Cloudflare tunnel). All JS/Node is temporary scaffolding, to be deleted.
- Rules truth: the original APK (`apk-original/decompiled/DBMGame/`, C#). Wiki expansions: `docs/rules/rules.md` + PDFs, then card text, then the JS.

## Current state
**Pushed (`acb2c87`)**
- C# oracle `tools/apk-oracle` (runs the original `DBMGame.dll` headless).
- Base set + APK decks (KSA, BMH; THK greyed out as in the APK) identical to the APK.
- Next Level (115) and Crash Landing (33) ported.
- Web pck 242 → 38 MB.

**Not committed (working tree)**
1. **Minibosses (RMB, 121 cards)**: `Minibosses.gd`, `RmbAbilities.gd`, `RmbSpells.gd`, `goldens_rmb.gd`. Green on its side (goldens 1280/1280, APK parity 6/6, 12/12, 6/6).
2. **Headless Godot online server**: `godot/server/` (Server, GameRoom, ViewFilter, PROTOCOL.md), `NetCodec.gd`, `OnlineClient.gd` / `OnlineGameManager.gd` rewritten on WebSocket, test `online_test.gd`.
3. **An agent was running** when this session ended, on 4 items:
   - fixing the `online` suite (ViewFilter didn't know the RMB keys);
   - private log lines visible only to their owner;
   - `try_resume` and a "Start with bots" button in `Main.gd`;
   - excluding `godot/server/*` from the web export.

   **First action: `git status` + `npm run test:godot:all`.** If `online` still fails, resume those 4 items.

## Checks (run them yourself)
```
npm run test:godot:all          # goldens, coverage, soaks (base, APK decks, TNL, RMB, all packs), online
npm run test:parity:apk         # seeds 1-3 x 2,3 — must be 6/6 OK
npm run test:parity:apk:wide    # seeds 4-7 x 2-4 — 12/12
npm run test:parity:apk:decks   # with PlayerChoice/HiddenHeros/ToolsHeroKind — 6/6
```
Parallel agents: give each its own `$env:APK_PARITY_OUT="<folder>"` (apk.mjs wipes its output folder).
The old JS harness `npm run test:parity` is nondeterministic: don't use it.

## Decisions taken
- Godot covers APK content **and** the wiki expansions (TNL, CRL, RMB).
- Where the JS contradicts the C# (APK) or the rules text, Godot follows the C# / rules text. Examples:
  - Dark Altar cannot recover itself.
  - The spell battle follows the `EnqueueAbilityTransaction` priority order (neither FIFO nor LIFO).
  - TNL setup: 5 rooms + 2 spells.
- Rule added that is **not in the source**, for the user to confirm: with Crash Landing, the game ends when the hero decks are empty.

## To do (priority order)
1. Finish the online follow-ups (above), then commit and push.
2. **Live leak**: the Node server (if deployed on ZimaOS) sends deck order, bossPicks and face-down rooms. Ask the user: take it down, or replace it quickly with the Godot server.
3. T6–7: delete the JS (`src/backend`, `tools/parity` except `apk.mjs` + the Godot harness, `tests/unit`, `package.json`). Godot must test itself alone, so replace `npm run test:*` and `tools/run_godot_tests.mjs` with a non-Node runner. Keep `tools/apk-oracle` (.NET). Update CI (`.github/workflows/ci.yml`).
4. T13–14: Docker nginx alpine (static `build_web` + brotli wasm + `/ws` proxy) + a Godot headless container for the server. Update `deploy/docker-compose.yml` (no Postgres) and `DEPLOYMENT.md`.
5. T8, T9, T11: adventure animations (Tween, damage popups, shake), mouse/touch drag-and-drop, Solo / Pass & Play menus.
6. Remaining limits:
   - The AI never plays some cards (Doc Scarecrow, Scott cancel, Paywall…).
   - Meddling Kids! doesn't blank base-set passives.
   - Some immediate builds only go over an existing room.
   - The `implemented` flags in cards.json are not up to date.
7. Not yet verified:
   - The interface played by hand.
   - The web export in a real browser.
   - The audio in a browser.
   - Opening the PR to `main`.

## Memory
Auto-memory (`~/.claude/projects/...monster-boss/memory/`) has: the architecture vision, the APK oracle, the orchestrator role and the card sources.
