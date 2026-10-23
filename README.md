# Boss Monster - Web (Godot 4)

Recréation de **Boss Monster: Master of the Dungeon** (APK 2.2.6) jouable dans le navigateur : solo contre l'IA
(2 à 4 joueurs, 2 à 6 avec Crash Landing), pass and play, parties en ligne par code de salle ou par liste publique de salons (WORLDWIDE), extensions de l'APK et du wiki.
Client **Godot 4.7 Compatibility** (export Web, threads désactivés : aucun header COOP/COEP requis), pas de Node ni de base de données.
Reprise du projet : `docs/HANDOFF.md`.

## Stack

- **Client** : Godot 4.7.2 Compatibility, viewport 1920×1080 (`src/frontend/project.godot`, `src/frontend/godot/`)
- **Moteur GDScript** : `src/frontend/godot/scripts/` (`Match`, `BossEngine`, `AI`, `CardDB`, UI `Main`/`BoardUI`...)
- **Serveur multijoueur** : Godot headless, WebSocket (`src/frontend/godot/server/`, protocole dans `PROTOCOL.md`), parties en mémoire
- **Assets** : `src/frontend/assets/` (cartes WebP, UI extraite de l'APK, audio, fonts) ; données de cartes : `src/frontend/godot/data/cards.json` (source unique)
- **Déploiement** : nginx (export statique) + conteneur serveur Godot derrière `/ws` (`deploy/`)

## Démarrage rapide

Prérequis : Godot 4.7.2 (variable `GODOT`, sinon `tools/godot_exe.py` cherche le chemin Windows par défaut puis `godot`), Python 3.

```bash
# 1. Jouer / éditer : ouvrir src/frontend/project.godot dans l'éditeur Godot 4.7 et lancer la scène principale
# 2. Exporter le client web (~38 Mo pck)
godot --headless --path src/frontend --import          # une fois, pour les class_name
godot --headless --path src/frontend --export-release Web godot/build_web/index.html
# 3. Servir en local
python -m http.server 8000 --directory src/frontend/godot/build_web   # http://localhost:8000
# 4. Serveur multijoueur local (optionnel, ws://localhost:8091)
godot --headless --path src/frontend res://godot/server/Server.tscn -- --port=8091
```

Production : `docker compose -f deploy/docker-compose.yml up -d --build` (l'export est fait dans le build Docker, port 8090) ; voir `deploy/DEPLOYMENT.md`.

## Tests & outils

```bash
python tools/run_godot_tests.py          # 14 suites Godot headless (goldens, coverage, 10 soak dont THK / IOD / CRL 5-6 joueurs, online, ui smoke) ; c'est ce que lance la CI
python tools/parity/apk.py               # parité vs l'APK d'origine : LOCAL UNIQUEMENT (oracle .NET + apk-original/ non versionné, voir tools/parity/README.md)
python tools/verify_assets.py            # faces APK, assets UI, effectifs du set de base
python tools/merge_expansions.py         # fusionne les packs wiki dans cards.json + recalcule `implemented`
```

## Structure du repo

```
src/frontend/            projet Godot 4 (res:// = src/frontend/)
  godot/scripts/         moteur et UI (Match, BossEngine, AI, CardDB, BoardUI, Main...)
  godot/data/            cards.json (477 cartes)
  godot/server/          serveur multijoueur headless (+ ViewFilter : informations cachées)
  godot/tests/           suites Godot headless (lancées par tools/run_godot_tests.py)
  assets/                cartes WebP, UI, audio, fonts, pages des livrets de règles (versionnés)
deploy/                  Dockerfile (export + nginx), Dockerfile.server, docker-compose.yml, DEPLOYMENT.md
security/                SECURITY.md + .env.example (jamais de secret commité)
docs/                    HANDOFF, règles, rapports ; docs/reference/ (captures APK) est local et ignoré par git
tools/                   scripts Python (stdlib, Pillow pour l'art) : runners de tests/parité, extraction APK / wiki ; apk-oracle/ = oracle .NET
apk-original/            APK + décompilation (référence locale, ni versionné ni embarqué)
```

## Références

Règles : le C# décompilé de l'APK (`apk-original/`, via l'oracle `tools/apk-oracle/`), puis `docs/rules/rules.md`.
Extracteur d'APK : `tools/extract_apk_226.py`.
