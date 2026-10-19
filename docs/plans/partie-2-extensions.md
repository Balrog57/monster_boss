# Partie 2 — Cartes des extensions (wiki) et 5-6 joueurs

> Prérequis : lire [`docs/plans/README.md`](README.md) (rôles, sources de vérité, commandes, règles, conventions `GODOT/`, `ASSETS/`, `CS/`) et [`docs/HANDOFF.md`](../HANDOFF.md). Dans ce brief : `GODOT/` = `src/frontend/godot/`, `ASSETS/` = `src/frontend/assets/`. **À démarrer après la partie 1** (README §7), sauf accord de l'utilisateur (partie 1 close, partie 2 engagée le 2026-10-18).

## Rôles (rappel ; détail dans le README §3)

L'IA qui reçoit ce brief est **orchestrateur seulement** : elle décide, dispatche, vérifie (tests, parité, git), commite, et **n'édite aucun fichier du dépôt**. **Sonnet** (`model: sonnet`) écrit tout le code et toutes les docs (périmètre de fichiers étroit, pas de git, `python tools/run_godot_tests.py` vert deux fois, question finale « qu'est-ce qui diffère encore ? »). **Haiku** (`model: haiku`) explore, indexe, compare (≤ 30 images par agent) et rend des tableaux ; il ne modifie rien.

## Objectif

Toutes les cartes des extensions wiki se comportent et s'affichent comme le wiki et le livret le disent, les sets absents sont ajoutés si les règles existent, et le jeu passe à **5-6 joueurs avec Crash Landing** (décision de l'utilisateur, 2026-10-18). **Contrainte absolue : la parité APK ne bouge pas** (les packs wiki sont toujours conditionnés sur le pack actif ; le nombre de joueurs reste 2-4 si CRL est désactivé).

## Sources de vérité (partie 2)

Le C# de l'APK **ne contient pas** les extensions (contenu téléchargeable absent de l'APK 2.2.6 ; `docs/RAPPORT_REGLES.md` §3). Ordre ici : **livret** (`docs/rules/rules.md` + `docs/rules/rules_*.pdf`) > texte wiki (`https://bossmonster.fandom.com`) > `GODOT/data/cards.json`. Repères dans `docs/rules/rules.md` : The Next Level ~l.956, Minibosses ~l.1600, Crash Landing ~l.2288 (« Changes to Victory Conditions » ~l.2316), Implements of Destruction (« IOD ») ~l.2455.

## État de départ (vérifié le 2026-10-18)

> **Statut au 2026-10-19 : lots 2.0-2.4 faits, clôture technique 2.5a faite** (état actuel et chiffres : `docs/HANDOFF.md` §5 et §7 ; `cards.json` compte désormais 477 cartes). Les puces ci-dessous décrivent l'état *de départ* (442 cartes, moteur 2-4 joueurs) et ne sont pas mises à jour.

- **Déjà portés** : TNL (115 cartes : `GODOT/scripts/TnlAbilities.gd`, `TnlSpells.gd`), RMB/Minibosses (121 : `RmbAbilities.gd`, `RmbSpells.gd`, `Minibosses.gd`), CRL (33 : logique répartie dans `Match.gd`, `BossEngine.gd`, `RoomAbilities.gd`, `CardDB.gd` — il n'y a **pas** de `CrlAbilities.gd`), IA des cartes wiki `AiWiki.gd`, goldens dédiés (`GODOT/tests/goldens_tnl.gd`, `goldens_rmb.gd`, `goldens_crl.gd`), soak par pack (`GODOT/tests/soak_runner.gd`).
- Packs activés par défaut : `EXT_PACKS` dans `GODOT/scripts/Main.gd` (ligne ~10) et `Profile.gd`. Données : `ASSETS/data/expansions/{next-level,minibosses,crash-landing}.json` (+ `implemented.json`) fusionnées dans `GODOT/data/cards.json` (442 cartes, champ `set`).
- 107 cartes RMB en art de remplacement (`tools/generate_placeholder_art.py`). RMB063 n'est jamais proposé par `GODOT/tests/ai_census.gd` / `AiCensus.tscn`. 24 cartes THK (`implemented=false`).
- Le moteur est **2-4 joueurs** : `Match.new_match` fait `clampi(num_players, 2, 4)` (`GODOT/scripts/Match.gd` ligne 31) ; `GODOT/server/GameRoom.gd` ligne 32 et `GODOT/server/Server.gd` ligne 240 clampent aussi à 2-4 ; le sélecteur « HOW MANY PLAYERS? » de `Main.gd` (~l.248) tourne sur 3 valeurs. La condition de fin CRL existe déjà (`Match._check_end_or_next_turn`, `Match.gd` ~1821, test des deux pioches vides ~1874) mais n'est atteignable qu'à 2-4 joueurs.

---

## Lot 2.0 — Inventaire du wiki

**Objectif** : savoir exactement ce que le wiki contient par rapport à `cards.json`.

**Sources** : `https://bossmonster.fandom.com` (page *List of Cards* et pages par set) ; `GODOT/data/cards.json` (champ `set`) ; `docs/rules/` ; scripts `tools/fetch_wiki_cards.py`, `tools/fetch_expansion_packs.py`.

**Qui fait quoi**
- **Haiku** : lister tous les sets du wiki et croiser avec `cards.json` (442 cartes). Sortie : tableau set → nombre de cartes wiki → présentes / absentes → source de règles (PDF dans `docs/rules/` ou page wiki).
- **Haiku** : pour chaque carte présente, comparer le texte wiki actuel au champ texte/`cmd` de `cards.json` ; signaler toute différence (errata).
- **Orchestrateur** : décide, avec ce tableau, quels sets absents entrent au lot 2.3.

**Fichiers cibles** : aucun (lecture seule) ; le tableau est transmis à Sonnet pour les lots 2.1-2.3 (et mis en forme dans `docs/HANDOFF.md` §5 à la clôture).

**Critère d'acceptation** : tableau complet set par set, avec la liste des errata carte par carte ; chaque set classé « présent / absent + source de règles ».

---

## Lot 2.1 — Audit comportemental carte par carte

**Objectif** : chaque carte wiki implémentée est conforme à son texte et au livret, et couverte par un golden.

**Sources** : texte wiki ; `docs/rules/rules.md` (TNL ~l.956, RMB ~l.1600, CRL ~l.2288) ; implémentations GDScript (`match` sur l'id de carte dans `TnlAbilities.gd`, `TnlSpells.gd`, `RmbAbilities.gd`, `RmbSpells.gd`, `Minibosses.gd`, `RoomAbilities.gd`, `BossEngine.gd`).

**Qui fait quoi**
- **Haiku, par pack** (3 agents) : pour chaque carte, lire son implémentation et vérifier contre le texte wiki et le livret. Verdict par carte : **conforme / écart / non testé par un golden**.
- **Sonnet** : corriger les écarts ; **un golden par carte corrigée** dans `GODOT/tests/goldens_tnl.gd` / `goldens_rmb.gd` / `goldens_crl.gd`. **RMB063** (jamais proposé par `AiCensus`) : trouver pourquoi et corriger `GODOT/scripts/AiWiki.gd`.
- La parité APK doit rester inchangée (packs conditionnés).

**Fichiers cibles** : `GODOT/scripts/TnlAbilities.gd`, `TnlSpells.gd`, `RmbAbilities.gd`, `RmbSpells.gd`, `Minibosses.gd`, `AiWiki.gd` (et au besoin `RoomAbilities.gd`, `BossEngine.gd`), `GODOT/tests/goldens_*.gd`.

**Critère d'acceptation** : verdict « conforme » pour 100 % des cartes ou écart documenté et justifié ; un golden par carte corrigée ; `AiCensus.tscn` PASS (RMB063 proposé ou justifié) ; `python tools/run_godot_tests.py` 14/14 ; **parité 6/6, 12/12, 6/6 inchangée** (fichiers moteur touchés → 3 commandes, en séquence).

---

## Lot 2.2 — Art des cartes

**Objectif** : réduire les 107 cartes RMB en art de remplacement.

**Sources** : pages wiki individuelles des cartes (pas seulement *List of Cards*) ; `tools/fetch_expansion_art.py`, `tools/generate_placeholder_art.py`, `tools/verify_assets.py` ; images dans `ASSETS/cards/`.

**Qui fait quoi**
- **Haiku** : pour chaque carte RMB sans art, l'image existe-t-elle sur sa page wiki individuelle ? (≤ 30 images vérifiées par agent.)
- **Sonnet** : étendre `tools/fetch_expansion_art.py` aux pages individuelles, relancer, puis `python tools/verify_assets.py`.
- **Sans source** : garder le placeholder et le noter dans `docs/HANDOFF.md` (Sonnet).

**Fichiers cibles** : `tools/fetch_expansion_art.py`, `ASSETS/cards/` (nouvelles images), `docs/HANDOFF.md`.

**Critère d'acceptation** : `tools/verify_assets.py` vert ; chaque carte restante en placeholder est listée avec la raison (« aucune source ») ; `python tools/run_godot_tests.py` 14/14.

---

## Lot 2.3 — Sets absents (selon lot 2.0)

**Objectif** : ajouter chaque set absent dont les règles sont disponibles, et rendre THK jouable **uniquement derrière la case wiki**.

**Sources** : tableau du lot 2.0 ; PDF de règles dans `docs/rules/` ; modèle d'un pack existant (`GODOT/scripts/TnlAbilities.gd`, `ASSETS/data/expansions/next-level.json`).

**Qui fait quoi (par set absent avec règles disponibles) — Sonnet**
1. Ajouter le pack dans `ASSETS/data/expansions/<set>.json` via `tools/fetch_expansion_packs.py`.
2. Fusion dans `GODOT/data/cards.json` : `tools/merge_expansions.py` (qui relance `tools/sync_implemented.py`).
3. Écrire `GODOT/scripts/<Set>Abilities.gd` sur le modèle de `TnlAbilities.gd`.
4. Goldens (`GODOT/tests/goldens_<set>.gd`, à enregistrer dans `goldens.gd` et `tools/run_godot_tests.py` si nécessaire), soak par pack, case à cocher dans `GODOT/scripts/Main.gd`, onglet RULES si un PDF officiel existe (`tools/render_rules_pages.py` → `ASSETS/rules/<livre>/pNN.webp`).

**THK (Tools of Hero-Kind)** : les 24 cartes sont dans `cards.json` avec `implemented=false` parce que l'APK ne les joue pas. En partie 2, les implémenter d'après le wiki (set « Implements of Destruction », IOD, `rules.md` ~l.2455) **uniquement derrière la case wiki**, jamais dans le mode APK pur, pour que `--decks ToolsHeroKind` reste 6/6.

**Fichiers cibles** : `ASSETS/data/expansions/`, `GODOT/data/cards.json`, `GODOT/scripts/<Set>Abilities.gd`, `GODOT/scripts/Main.gd`, `GODOT/tests/goldens_*.gd`, `tools/` (scripts de pack), `ASSETS/rules/`.

**Critère d'acceptation** : chaque set ajouté a pack + abilities + goldens + soak + case + (RULES si PDF) ; `tools/sync_implemented.py` cohérent ; `coverage.gd` vert ; THK jouable avec la case wiki, grisé sans ; tests 14/14 ; **parité 3 variantes inchangée** (notamment `--decks ...ToolsHeroKind` 6/6).

---

## Lot 2.4 — 5-6 joueurs (Crash Landing)

**Objectif** : étendre le jeu à 5-6 joueurs quand Crash Landing est actif. **Règle physique** : 5-6 joueurs seulement avec Crash Landing ; fin de partie « les deux pioches de héros épuisées » (`docs/rules/rules.md` « Changes to Victory Conditions » ~l.2316 ; déjà codée dans `Match.gd` ~1874 mais inactive à 2-4 joueurs).

**Sources** : `docs/rules/rules.md` section Crash Landing (~l.2288-2330, et ~l.3003 « 5-6 player games with Crash Landing require a full set of Heroes… ») ; `docs/rules/rules_crash_landing.pdf`.

**Qui fait quoi**
- **Haiku** : lister tout ce qui suppose ≤ 4 joueurs : `GODOT/scripts/Match.gd` (`new_match`, ligne 31), `BossEngine.gd`, `GameManager.gd`, `Main.gd` (sélection du nombre), `BoardUI.gd` (disposition des donjons / colonne ville), `GODOT/server/GameRoom.gd` (ligne 32, sièges) et `Server.gd` (ligne 240), `GODOT/server/ViewFilter.gd`, `GODOT/tests/ui_smoke.gd` (option `--players` : 2|3|4), `soak_runner.gd`, `online_test.gd`.
- **Sonnet, moteur** : `Match.new_match` jusqu'à 6 joueurs, héros révélés par tour selon CRL, condition de fin active ; goldens 5 et 6 joueurs (`goldens_crl.gd`) ; soak 5/6 avec CRL ; **le nombre reste 2-4 si CRL est désactivé** (parité intacte).
- **Sonnet, UI** : disposition de 5-6 donjons (**pas de référence APK** : s'inspirer de la mise en page à 4 joueurs, réduire l'échelle, garder la lisibilité en 1920×1080 ; captures dans `docs/reference/godot_screens/` via `CaptureScreens.tscn`) ; sélecteur 2-6 dans le menu solo quand CRL est coché.
- **Sonnet, serveur** : sièges 6 — faire ici le minimum : constante de sièges + `online_test` à 6 joueurs (la partie 3 l'utilisera).

**Fichiers cibles** : `GODOT/scripts/Match.gd`, `BossEngine.gd`, `GameManager.gd`, `Main.gd`, `BoardUI.gd`, `GODOT/server/GameRoom.gd`, `Server.gd`, `ViewFilter.gd`, `GODOT/tests/goldens_crl.gd`, `soak_runner.gd`, `ui_smoke.gd`, `online_test.gd`.

**Critère d'acceptation** : tests 14/14 + nouveaux goldens/soak (5 et 6 joueurs avec CRL) ; **parité 3 variantes inchangée** ; `ui_smoke` à 6 joueurs vert (`--players 6 --sets crash-landing` : l'option `--players` n'accepte aujourd'hui que 2|3|4, Sonnet l'étend) ; captures 5 et 6 joueurs lisibles ; 2-4 joueurs strictement inchangé sans CRL.

---

## Lot 2.5 — Clôture de la partie 2

**Qui fait quoi**
- **Sonnet** : relancer `tools/sync_implemented.py` ; galerie (`GODOT/scripts/CardGallery.gd`) et onglets RULES à jour ; `docs/HANDOFF.md` §5 et §7.
- **Orchestrateur** : `GODOT/tests/coverage.gd` vert (via `run_godot_tests.py`), tests 14/14, **parité 3 variantes**, `code-review` du diff complet, merge dans `main`, redéploiement homelab (`deploy/DEPLOYMENT.md` §3) **après accord de l'utilisateur**.

**Critère d'acceptation** : critères du README §6 « État final » ; `coverage.gd` vert ; une seule branche `main`, aucune PR, `git status` propre.
