# Boss Monster — Web (Godot 4 + Node)

Jeu **Boss Monster** base set jouable en solo 2 joueurs (humain vs IA) dans le
navigateur. Le client historique React a été remplacé par **Godot 4
Compatibility** (export Web, threads désactivés → aucun header COOP/COEP requis).

## Stack

- **Client** : Godot 4.7 Compatibility, viewport 1920×1080 (`src/frontend/project.godot`, `src/frontend/godot/`)
- **Serveur** : Koa + Socket.IO + PostgreSQL (lobby + multi, phase 2)
- **Moteur GDScript** : `src/frontend/godot/scripts/` (CardDB, BossEngine, Match, AI, Main, Board)
- **Assets** : `src/frontend/assets/` (cartes WebP, UI extraite WPK, audio, fonts) — l'art HD des
  cartes est exclu du pack web pour l'instant (voir `src/frontend/export_presets.cfg`)

## Lancer le jeu

```bash
# 1. Éditer / tester sous Godot 4.7 (renderer Compatibility)
godot --headless --path src/frontend res://godot/tests/Soak.tscn   # soak IA-vs-IA

# 2. Exporter le client web (5 Mo pck + 39 Mo wasm)
godot --headless --path src/frontend --export-release Web godot/build_web/index.html

# 3. Servir (le serveur Koa sert src/frontend/godot/build_web/ en statique)
npm install
npm run serve        # → http://localhost:8000
```

Solo : menu → **SOLO** → 2 joueurs → partie complète (boss, setup, build, bait,
adventure pas à pas, fin à 10 âmes).

## Tests & assets

```bash
npm run test:unit    # oracle JS : moteur, reducer, IA, extensions (400+ tests)
npm run test:godot   # soak Godot : partie IA-vs-IA complète en headless
npm run card-matrix  # génère docs/card-matrix.json (validation texte)
npm run export:web   # export release Web via Godot headless
npm run fetch:expansion-art   # art TNL/RMB/CRL depuis le wiki
npm run verify:assets
```

## Règles portées en GDScript (base set, boucle solo)

- Phases : BOSS → SETUP → BUILD → BAIT → ADVENTURE → END
- Lure APK (égalité → héros reste en ville), dégâts de salles cumulés, âmes/blessures,
  élimination à 5 blessures, victoire à 10 âmes
- IA : meilleur coup légal (dégâts + trésors), construction auto
- `shortcut:` effets de sorts / capacités de salles avancées non portés (fodder
  uniquement) — à porter depuis `src/backend/game/spellEffects.js` et
  `roomAbilities.js` en phase 2, avec l'oracle `test:unit` comme référence

## Structure du repo

```
src/frontend/            Godot 4 (racine res:// = src/frontend/, assets/ partagés)
src/frontend/project.godot
src/frontend/export_presets.cfg   preset Web (threads OFF, art HD exclu du pck)
src/frontend/godot/scripts/       CardDB (autoload), BossEngine, Match, AI, Main, Board
src/frontend/godot/scenes/        Main.tscn (+ Board construit en code)
src/frontend/godot/data/          cards.json (copie de src/backend/game/)
src/frontend/godot/tests/         Soak.tscn (partie IA-vs-IA headless)
src/frontend/assets/              cartes WebP, UI, audio, fonts (versionnés)
src/backend/server/  Koa + Socket.IO + lobby + persistance (migrate.sql)
src/backend/game/    oracle JS des règles (tests + futur multi — phase 2)
tests/unit/          400+ tests Node (oracle de parité, à conserver)
deploy/              Dockerfile + docker-compose.yml + DEPLOYMENT.md
security/            SECURITY.md + .env.example (jamais de secret commité)
docs/                règles, matrice cartes, rapports
tools/               extraction APK / wiki / vérifications (dev uniquement)
apk-original/        APK + décompilation (référence locale, ni versionné ni embarqué)
```

## Références

Captures APK : `docs/reference/play_*.png` (non versionné, QA locale)  
Extracteur WPK : `tools/extract_apk_226.py`
