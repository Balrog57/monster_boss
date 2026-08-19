# Boss Monster — Web (React + Node)

Jeu **Boss Monster** base set (BMA001–096) jouable en solo 2 joueurs (humain vs IA) ou en ligne (Socket.IO + PostgreSQL).

## Stack

- **Client** : React 19 + Vite, plateau 1920×1080
- **Serveur** : Koa + Socket.IO + PostgreSQL
- **Assets** : cartes wiki WebP + fallback APK (`assets/apk_cards/`), UI extraite WPK (ETC1 / RGBA4444)

## Lancer le jeu

```bash
npm install
npm run dev          # client Vite → http://localhost:3000
npm run serve        # serveur API + matchmaking (autre terminal)
```

Solo : menu → **SOLO** → 2 joueurs → partie complète (boss, setup, discard, build, bait, adventure, fin).

## Tests & assets

```bash
npm run test:unit    # moteur, reducer, IA (21 tests)
npm run verify:assets
```

## Règles implémentées (base set)

- Phases : BOSS → SETUP → BUILD → BAIT → ADVENTURE → END
- 16 sorts avec ciblage (`src/spellTargeting.js`) et phases (cat. 1–5 dont Cave-In / Exhaustion)
- Aventure pas à pas (`resolveNextHero`), effets Exhaustion / Teleport / Cave-In héros
- Salles activables, level-up boss, opening discard 7→5
- IA via `legalMoves` + scoring (`src/ai.js`)

## UI (alignement APK 2.2.6)

- Plateau : HUD, 2 rangées donjon, discard live, main avec onglets ROOMS/SPELLS
- Boss in-board overlay « PLAY BOSS MONSTER! »
- Salles face-down jusqu’à révélation fin de BUILD

## Références

Captures APK : `docs/reference/play_*.png`  
Extracteur WPK : `tools/extract_apk_226.py`
