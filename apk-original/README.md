# apk-original — APK d'origine (référence locale uniquement)

Ce dossier contient **l'APK d'origine et sa décompilation**, qui ne font
**pas partie du projet** :

- `boss-monster-2-2-6-android.apk` — APK Boss Monster 2.2.6 d'origine.
- `boss-monster-2-2-6/` — extraction/décompilation de l'APK
  (`assets/`, `lib/`, `res/`, `classes.dex`, …), utilisée uniquement comme
  **référence de parité** (textes de cartes, visuels, règles, audio).

Règles :

- **Ne jamais commiter** ce contenu (voir `.gitignore` : `apk-original/`).
- **Ne jamais l'embarquer** dans l'image Docker (voir `.dockerignore`).
- Les scripts d'extraction sous `tools/` (`extract_apk_226.py`,
  `extract_music.py`, `build_fonts.py`, …) lisent ce dossier et produisent
  les assets du jeu sous `assets/` (versionnés, eux).
- Sur une machine sans l'APK, tout fonctionne sauf les scripts
  d'extraction ; les tests utilisent la fixture versionnée
  `tests/unit/fixtures/apk-base-heroes.json`.
