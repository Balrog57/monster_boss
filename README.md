# Boss Monster — Web (Godot 4)

Jeu **Boss Monster** base set jouable en solo 2 joueurs (humain vs IA) dans le
navigateur. Le client historique React a été remplacé par **Godot 4
Compatibility** (export Web, threads désactivés → aucun header COOP/COEP requis).

## Stack

- **Client** : Godot 4.7 Compatibility, viewport 1920×1080 (`src/frontend/project.godot`, `src/frontend/godot/`)
- **Serveur multi** : Godot headless (`src/frontend/godot/server/`, WebSocket)
- **Moteur GDScript** : `src/frontend/godot/scripts/` (CardDB, BossEngine, Match, AI, Main, Board)
- **Assets** : `src/frontend/assets/` (cartes WebP, UI extraite WPK, audio, fonts) — l'art HD des
  cartes est exclu du pack web pour l'instant (voir `src/frontend/export_presets.cfg`)

## Lancer le jeu

```bash
# 1. Éditer / tester sous Godot 4.7 (renderer Compatibility)
godot --headless --path src/frontend res://godot/tests/Soak.tscn   # soak IA-vs-IA

# 2. Exporter le client web (~38 Mo pck + 39,5 Mo wasm ; ~35 + 8 Mo en brotli)
godot --headless --path src/frontend --export-release Web godot/build_web/index.html

# 3. Servir en local (ou `docker build -f deploy/Dockerfile .` : nginx + export, voir deploy/DEPLOYMENT.md)
python -m http.server 8000 --directory src/frontend/godot/build_web   # → http://localhost:8000
```

Solo : menu → **SOLO** → 2 joueurs → partie complète (boss, setup, build, bait,
adventure pas à pas, fin à 10 âmes).

## Tests & assets

```bash
python tools/run_godot_tests.py          # 9 suites Godot headless (goldens, coverage, soak x5, online, ui smoke)
python tools/parity/apk.py               # parité vs l'APK d'origine (oracle .NET local, voir tools/parity/README.md)
python tools/verify_assets.py            # faces APK, assets UI, effectifs du set de base
python tools/fetch_expansion_art.py      # art TNL/RMB/CRL depuis le wiki
python tools/merge_expansions.py         # fusionne les packs wiki dans cards.json + recalcule `implemented`
```

## Règles portées en GDScript (base set, boucle solo)

- Phases : BOSS → SETUP → BUILD → BAIT → ADVENTURE → END
- Lure APK (égalité → héros reste en ville), dégâts de salles cumulés, âmes/blessures,
  élimination à 5 blessures, victoire à 10 âmes
- IA : meilleur coup légal (dégâts + trésors), construction auto
- Référence des règles : le C# décompilé de l'APK (`apk-original/`), via l'oracle `tools/apk-oracle/`

## Structure du repo

```
src/frontend/            Godot 4 (racine res:// = src/frontend/, assets/ partagés)
src/frontend/project.godot
src/frontend/export_presets.cfg   preset Web (threads OFF, art HD exclu du pck)
src/frontend/godot/scripts/       CardDB (autoload), BossEngine, Match, AI, Main, Board
src/frontend/godot/scenes/        Main.tscn (+ Board construit en code)
src/frontend/godot/data/          cards.json (source unique des cartes, 442 entrées)
src/frontend/godot/tests/         Soak.tscn (partie IA-vs-IA headless)
src/frontend/assets/              cartes WebP, UI, audio, fonts (versionnés)
src/frontend/godot/tests/         suites Godot headless (lancées par tools/run_godot_tests.py)
src/frontend/godot/server/        serveur multi Godot headless
tools/apk-oracle/    oracle .NET : DBMGame.dll de l'APK rejoué en headless (parité)
deploy/              Dockerfile + docker-compose.yml + DEPLOYMENT.md
security/            SECURITY.md + .env.example (jamais de secret commité)
docs/                règles, matrice cartes, rapports
tools/               scripts Python (stdlib sauf Pillow pour l'art) : runners de tests/parité, extraction APK / wiki
apk-original/        APK + décompilation (référence locale, ni versionné ni embarqué)
```

## Références

Captures APK : `docs/reference/play_*.png` (non versionné, QA locale)  
Extracteur WPK : `tools/extract_apk_226.py`
