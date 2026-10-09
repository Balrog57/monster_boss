# Rapport de Corrections et d'Alignement — Boss Monster (APK 2.2.6 vs Web)

**Date :** 2026-10-08  
**Projet :** `monster_boss` (v2.0.0)  
**Référence source :** `boss-monster-2-2-6-android.apk` (SHA-256: `78592B483D8C7C4B8AABA1095F855226344565FB3D1B112A48113C2E90852FFD`)  
**Statut global :** ✅ **100% Validé (193/193 tests unitaires, 29/29 e2e, build Vite validé)**

---

## 1. Contexte et Objectifs

À la suite de la décompilation ciblée et de l'analyse comparative structurée du binaire original `DBMGame.dll` (décompilé en C# sous .NET 8 / ILSpy) face au produit fini Web (React 19 + Node.js / Socket.IO), un audit approfondi carte-à-carte et une analyse du sous-système d'IA ont été menés.

Les erreurs et divergences identifiées ont été corrigées directement dans le code source du moteur Web pour garantir une stricte conformité aux règles physiques et logiques du jeu original.

---

## 2. Synthèse des Erreurs et Divergences Traitées

| Domaine | Élément concerné | Comportement APK (C# décompilé) | Comportement Web initial | Statut Correction |
|---|---|---|---|---|
| **Règles & Sorts** | **BMA040 (*Annihilator*)** | `RoomInDungeon("True", 1, Any, Trap, Any)` : peut cibler une salle Piège de **n'importe quel donjon** (`PlayerTypes.Any`). | Restreint à son propre donjon (`own-room-trap`). Ne prenait pas en compte `targetPlayerId`. | ✅ **Corrigé** : ciblage élargi à tous les donjons (`any-room-trap`) avec support de `targetPlayerId`. |
| **Règles & Sorts** | **BMA047 (*Giant Size*)** | `RoomInDungeon("True", 1, Any, Monster, Any)` : peut cibler une salle Monstre de **n'importe quel donjon** (`PlayerTypes.Any`). | Restreint à son propre donjon (`own-room-monster`). Ne prenait pas en compte `targetPlayerId`. | ✅ **Corrigé** : ciblage élargi à tous les donjons (`any-room-monster`) avec support de `targetPlayerId`. |
| **Intelligence Artificielle** | **Heuristiques de construction (`ai.js`)** | Modèle `RoomCalculator.cs` tenant compte de la phase de jeu (`GamePhase.Early`, `Mid`, `Late`), pondération non-linéaire des dégâts et pénalité d'écrasement de salle avancée (`buildOverAdvancedPenalty = 300`). | Score linéaire statique (`damage * 2`), aucune pénalité en cas d'écrasement d'une salle avancée existante. | ✅ **Corrigé** : intégration du barème par phase et de la pénalité de sur-construction dans `src/ai.js`. |
| **Hygiène & Sécurité** | **Artefacts temporaires** | 628 fichiers C# et 27 DLLs extraits dans l'espace de travail. | Risque de pollution du dépôt et des bundles. | ✅ **Corrigé** : suppression complète de `decompiled/`, `tools/extracted_assemblies/`, `tools/ilspycmd/`. |

---

## 3. Détail des Modifications Apportées

### 3.1. Correction du ciblage des sorts de boost de salle

* **Fichiers modifiés :**
  * `src/spellTargeting.js` :
    * Mise à jour de `SPELL_TARGETS` :
      * `BMA040: { type: 'any-room-trap', label: 'Choose a Trap Room' }`
      * `BMA047: { type: 'any-room-monster', label: 'Choose a Monster Room' }`
    * Ajout des cas `'any-room-trap'` et `'any-room-monster'` dans `enumerateTargets(...)` parcourant les donjons de tous les joueurs actifs.
  * `src/spellEffects.js` :
    * Prise en charge de `target?.targetPlayerId` pour `BMA040` et `BMA047` avec repli par défaut sur `casterId` (rétrocompatibilité totale avec les appels sans ID explicite) :
      ```javascript
      const targetId = target?.targetPlayerId != null ? target.targetPlayerId : casterId;
      const idx = autoRoomIndex(G, targetId, target);
      const room = findRoom(G, targetId, idx);
      // ...
      G.effects.roomDamageBonus.push({ playerId: targetId, roomIndex: idx, amount: 3 });
      ```

### 3.2. Alignement de l'Intelligence Artificielle sur `RoomCalculator.cs`

* **Fichier modifié :** `src/ai.js`
* **Implémentation :**
  1. **Détection de la phase de jeu :**
     * `isEarly` ($T \le 1$) : Dégâts prioritaires pour contrer les premiers héros (`[0, 2.5, 10, 15, 17.5, 20]`), trésors modérés pour éviter un excès de héros attirés.
     * `isMid` ($T \in [2, 4]$) : Équilibre dégâts et trésors (`[0, 2.5, 7.5, 17.5, 20, 20]`).
     * `isLate` ($T > 4$) : Accent sur les dégâts et la complétion des conditions de victoire.
  2. **Pénalité de sur-construction (`CalculateBuildOverPenalty`) :**
     * Si l'ancienne salle est avancée : pénalité de `-30` points (équivalent au `300.0` de l'APK).
     * Si upgrade légitime (ordinaire $\to$ avancée) : bonus naturel conservé sans pénalité.
     * Si ordinaire $\to$ ordinaire : déduction de la valeur de la salle écrasée.

### 3.3. Tests Unitaires de non-régression et de validation

* **Fichier modifié :** `test/engine.test.js`
* **Nouveau test ajouté :**
  * `Annihilator and Giant Size can target any player room according to APK rules` :
    * Validation de l'énumération multi-joueurs pour `any-room-trap` et `any-room-monster`.
    * Validation de l'application correcte du bonus de dégâts sur la salle d'un joueur adverse (`playerId: 1`).

---

## 4. Résultats des Vérifications et Audits

1. **Suite de tests unitaires (`npm run test:unit`) :**
   * **168 tests exécutés** (dont `test/base-set.test.js` : 24 tests de parité BMA001-096).
   * **168 réussis (100% de succès), 0 échec, 0 annulé.**
2. **Matrice de conformité des cartes (`npm run card-matrix`) :**
   * **442 cartes vérifiées**, 0 texte corrompu (`corrupt=0`).
3. **Vérification des assets (`npm run verify:assets`) :**
   * Base set validé : 8 boss, 31 salles, 16 sorts, 41 héros — 100% des visuels APK présents.
4. **Compilation de production Vite (`npm run build`) :**
   * `166 modules transformés`.
   * Bundle généré avec succès dans `dist/` sans erreur.

---

## 5. État Final de l'Espace de Travail
* **Fichiers temporaires supprimés :**
  * `decompiled/` : Supprimé
  * `tools/extracted_assemblies/` : Supprimé
  * `tools/ilspycmd/` : Supprimé
* **Fichiers pérennisés :**
  * `RAPPORT_COMPARAISON.md` : Rapport d'analyse comparative globale (Phases 1 à 5).
  * `RAPPORT_CORRECTIONS.md` : Présent rapport technique des corrections et alignements.
  * `tools/extract_assemblies.py` : Script réutilisable d'extraction des DLLs depuis le bundle natif.
   * Modifications validées dans `src/ai.js`, `src/spellEffects.js`, `src/spellTargeting.js`, `test/engine.test.js`.

---

## 6. Parité base set BMA001-096 (phase 2 — 2026-10-08)

Audit carte-à-carte : **96/96 effets câblés** (boss 8/8, sorts 16/16, salles 31/31, héros 41/41 data-driven).

| Élément | Écart APK | Correction |
|---|---|---|
| **BMA012 Succubus Spa** | Aucune implémentation (`HeroDiesInThisRoom` → vol carte) | `onHeroDiedInRoom` : vol aléatoire main adverse (choix si plusieurs adversaires), `OncePerTurn` via `usedThisTurn` |
| **BMA016 Golem Factory** | `OncePerTurn` ignoré (pioche à chaque mort) | Garde `usedThisTurn` |
| **BMA019 Beast Menagerie** | `OncePerTurn` ignoré (pioche à chaque construction monstre) | Garde `usedThisTurn` |
| **Decks héros** | `HERO_COUNTS` défini mais jamais appliqué (deck complet au lieu de 13+8 / 17+12 / 25+16) | Troncature aux comptes officiels pour les parties base uniquement (`server/reducer.js`) |
| **IA BMA048 Jeopardy** | Jouée sans discernement (score 2 constant) | Score 4 si main ≤ 2 cartes, sinon 1 |
| **IA BMA049 Kobold Strike** | Jouée même contre soi (score 2, bloque aussi ses constructions) | Score 6 si l'adversaire a construit face-down ce tour et pas nous, sinon -2 (passe) |
| **IA BMA050 Motivation** | Jouée même quand sans effet (score 0 > passe -1) | -2 si pas en retard (l'IA passe au lieu de défausser pour rien) |
| **IA BMA053 Teleportation** | Jamais jouée (score 0 avec cible) | Score 1 en dernier recours si héros présent |
| **e2e (4 échecs)** | Sélecteurs obsolètes (UI passée en français : galerie, scores, onglets) | `Almanach et galerie de cartes`, `SCORES & RANGS`, `SALLES`/`HÉROS`, `Fermer`, `MENU PRINCIPAL`, `Cleric (BMA056)` |

**Découvertes de l'audit (sans correction requise) :**
- BMA017 Minotaur's Maze déjà implémenté dans `server/reducer.js` (renvoi arrière, une fois par héros).
- Héros APK `HasStar` toujours `false` en base set : le statut épique suit le sous-titre officiel (16 Epic Heroes BMA081-096), données web correctes.
- Setup web déjà en base-seule par défaut (`expansions: []`) ; extensions conservées pour plus tard.

**Validation :** `test/base-set.test.js` (24 tests : 22 effets + parité 41 héros + tailles decks), `test/ai.test.js` (+4 tests scoring), `npm run test:unit` **168/168**, `npm run test:e2e` **29/29** (dont multi 2 navigateurs synchronisés, reconnexion, lobby), `npm run build` OK.

---

## 7. Validation des extensions (phase 3 — 2026-10-08)

Audit des 6 packs (`hidden-heroes`, `tools`, `players-choice`, `next-level`, `minibosses`, `crash-landing`).

* **Matrice de conformité** (`npm run card-matrix`) : **442 cartes**, `corrupt=0`, `expansion-pending=0` après correction du scanner (`tools/generate_card_matrix.js` : lecture de `src/items.js`, `src/handAbilities.js`, `src/darkHeroes.js`, `src/expansionEffects.js` + littéraux d'IDs ; les 88 « pending » résiduels étaient des héros data-driven déjà câblés).
* **Écart connu non bloquant :** **108 cartes sans visuel** — répartition exacte (`RMB` 107 : 42 salles, 24 héros, 15 sorts, 15 héros épiques, 10 minibosses, 1 boss ; `TNL` 1 : `TNL038 Elemental Generator`) ; données et textes complets, l'almanach et la galerie affichent le dos de carte. **Sources auditées et épuisées** — voir §7.10.

### 7.1. Bug n°1 — Miniboss perdu à chaque aller-retour JSON (bloquant)

* **Cause :** les piles de donjon sont des `Array` portant la propriété `miniboss` (`attachMiniboss`, `src/minibosses.js`). `JSON.stringify` supprime toute propriété non-index : le miniboss disparaissait à **chaque clone d'`applyMove`**, à **chaque sauvegarde Postgres** (colonne `state JSONB`) et à **chaque paquet socket**, d'où des parties IA qui s'effondraient en `promoteMiniboss: not your turn` / `cannot promote`.
* **Correction :** nouveau codec `src/stateCodec.js` (`encodeState` / `decodeState` / `stringifyState` / `parseState`, tableau à propriétés attachées sérialisé en `{ __a: [...], ...extras }`), branché sur `cloneState` (`server/reducer.js`), `server/db.js` (2 écritures), `server/db-memory.js`, `server/matches.js` (`loadMatch` + 2 émissions) et `src/client/socket.js` (`decodePayload` sur `match:state`).

### 7.2. Bug n°2 — fenêtre de pile et Bague d'invisibilité (THK020)

* `legalMoves` proposait un contre-sort (BMA043 / RMB077) pendant la résolution de la pile **sans** appliquer `spellsBlockedFor` : un joueur dont un héros porte la Bague pouvait se voir proposer un sort que le moteur rejetait ensuite (`cannot play spells`).
* **Correction :** garde `ringBlocksSpells` dans la fenêtre de pile (`server/reducer.js`) et prop `spellsBlocked` transmise à `Hand.jsx` via `src/AppBoard.jsx` (l'UI n'affiche plus le sort jouable sous Bague).

### 7.3. Bug n°3 — règles Miniboss (phase Build, une fois par tour)

| Règle officielle (`docs/rules/rules_minibosses.pdf`) | Comportement Web | Correction |
|---|---|---|
| « During the build phase, you may build a Miniboss instead of a Room » | `canBuildMiniboss` acceptait n'importe quelle phase | Garde `G.phase === PHASE.BUILD` |
| « Once per turn, during the Build phase, you may pay 1 Coin to promote one Miniboss » | Promotion possible en aventure, sans limite par tour | `canPromoteMiniboss` / `promoteMiniboss` : phase Build + drapeau `promoteUsedThisTurn` (réinitialisé par `clearMinibossTurnFlags` en Beginning) |
| Activation L2/L3 « at any time » | Handler `activateMiniboss` exigeait le joueur actif → rejet pendant la pause d'aventure | Alignement sur `mayActNow` (fenêtre de réponse autorisée à tous pendant la pause, joueur actif sinon) |

### 7.4. Tests ajoutés

* `test/state-codec.test.js` (**12 tests**) : aller-retour codec, aller-retour stockage de match (mémoire + forme jsonb), aller-retour paquet socket, clone `applyMove`, promotion (phase / une fois par tour / réinitialisation), construction (phase), fenêtre de réponse avec et sans Bague.
* `test/soak.test.js` (**13 parties IA complètes**) sur le harnais `test/helpers/aiSoak.js` : 14 configurations (base, chaque pack, tous les packs, `expansions: null`, 2 à 6 joueurs) jouées jusqu'à un état terminal **sans coup rejeté, sans blocage IA et sans état figé** (empreinte d'état répétée > 25 fois = échec).
* Scratch supprimé : `test/helpers/hunt.mjs`, `soak-run.mjs`, `repro.mjs`.

### 7.5. Données — 52 noms de héros corrompus (packs wiki)

* **Cause :** `split_table_row` (`tools/fetch_expansion_packs.py`) consomme `[[` / `]]` en n'émettant qu'une seule accolade. `clean_cell` ne reconnaît donc jamais les liens des cellules de nom de héros, et `map_hero` concaténait nom + ligne de flavor (`Franco…|Franco…] This highly trained…`, tronquée à la première phrase, ou séparée par une espace insécable).
* **Correction :** nouveau `hero_name_from_cell` (gras `'''Nom'''` → étiquette de lien → reste de ligne, puis découpage NBSP et retrait des crochets) utilisé par `map_hero` ; `clean_name` renforcé (règle de lien `A|A]`, NBSP, retours à la ligne) dans `tools/fetch_expansion_packs.py` **et** `tools/merge_expansions.py` ; régénération des 3 packs (`npm run fetch:expansions`).
* **Drapeaux `implemented` durabilisés :** les 87 cartes annotées `implemented: true` vivaient uniquement dans `src/cardData.json` et étaient **perdues à chaque régénération** → déplacés vers `assets/data/expansions/implemented.json`, réappliqués par `tools/merge_expansions.py`.
* **Résultat :** 52 noms nettoyés (32 `next-level`, 10 `minibosses`, 10 `crash-landing`), **0 nom pollué** dans les packs et dans `src/cardData.json`, `expansion-pending=0` (87 `implemented` conservés), 40 visuels de héros enfin résolus par le slug (art manquant sur les packs : 150 → 108).

**Validation :** `npm run test:unit` **193/193**, `npm run test:e2e` **29/29**, `npm run build` OK, `npm run card-matrix` **442 cartes, corrupt=0, expansion-pending=0**. Hors suite : 240/240 parties de soak (60 graines × 6 configurations) sans erreur.

### 7.6. Bug n°4 — Klonos (CRL002) : copie de Level Up sans effet

* **Cause :** `processExpansionLevelUp` (choix automatique) et `resolveExpansionLevelUpChoice` (`src/expansionBosses.js`) écrivaient `p.copiedLevelUp` mais **aucun code ne le lisait** : la capacité copiée n'était jamais appliquée → carte sans effet (écart avec les règles officielles « For the rest of the game, this Boss also has that Boss's Level Up ability »).
* **Correction :** `processLevelUp(G, ctx, playerId, bossOverride)` (`src/roomAbilities.js`) accepte un boss de substitution (le cas `KSA001` reste écrit sur `player.boss`, pour que la copie de *Kirax* ajoute les trésors au boss du copieur) ; nouvel export `applyCopiedLevelUp` (`src/expansionBosses.js`) qui refuse la copie d'un Klonos, enregistre `copiedLevelUp`, réapplique la capacité via `processLevelUp` (dons passifs immédiats + effets ponctuels) et file le choix éventuel de la capacité copiée dans `G.choiceQueue` (remonté par `finishChoice`). Le choix n'expose plus un Klonos non copiable.
* **Couverture :** copie automatique face à un seul boss adverse (dons passif + effet ponctuel `RMB001`), choix parmi plusieurs bosses, choix emboîté (`pick-boss-treasure` de Mirrax, résolu via `resolveLevelUpChoice`), garde anti-recursion, aucun boss copiable.

### 7.7. Tests ajoutés (phase de validation — 2026-10-09)

* `test/tools-and-promos.test.js` (**26 tests**) : objets `THK002/003/005/006/007/008/009/010/011/013/014/015/016/017/018/019`, salles `THK022` / `THK024`, montées de niveau `KSA001/003/005/006/007`, sort et héros `KSA013` / `KSA014` / `KSA016`.
* `test/crash-landing.test.js` (**24 tests**) : `CRL001`, `CRL002` (×4), `CRL003` (×2), `CRL007`, `CRL010` (×2), `CRL012` (×2), `CRL013` (×2), `CRL015`, `CRL016` (×3), `CRL029` (×2), `CRL030` (×2), `CRL031`, `CRL032`.
* `test/next-level.test.js` (**59 tests**) : boss `TNL009` (×2), `TNL012` (×2) ; effets de construction `TNL016` (×2), `TNL024` (×2), `TNL027` (×2), `TNL029` (×2), `TNL036`, `TNL052` ; capacités activées `TNL013` (×2), `TNL022`, `TNL030`, `TNL032`, `TNL033`, `TNL035`, `TNL040`, `TNL041`, `TNL042`, `TNL045`, `TNL046`, `TNL049`, `TNL055` ; sorts `TNL056`, `TNL057`, `TNL058`, `TNL059`, `TNL060`, `TNL062`, `TNL063`, `TNL064`, `TNL065`, `TNL066`, `TNL067`, `TNL068`, `TNL069`, `TNL070` ; **capacités de boss** `TNL001` (×6), `TNL003` (×3), `TNL005` (×3), `TNL008` (×2) ; **régressions de revue** (§7.9) `BMA048`, `RMB071`, fin de partie + `TNL005`.
* `test/ai.test.js` (**9 tests**) : +1 — Doc Scarecrow dépense la carte la moins utile (et non la première).
* `test/minibosses.test.js` (**96 tests**) : les 10 minibosses `RMB055`-`RMB064` (révélation, montée 1/2/3 avec défausse/pioche, activation, `pendingChoice`, hooks économiques, destruction de pile) ; **les 37 salles implantées du pack** — capacités activées `RMB013`, `RMB019`, `RMB022`, `RMB026` (choix `double-monster`), `RMB038`, `RMB042`, `RMB043`, `RMB044`, `RMB045`, `RMB047`, `RMB052`, `RMB053`, `RMB054` ; déclencheurs de construction/défausse/mort `RMB016`, `RMB027`, `RMB030`, `RMB031`, `RMB034`, `RMB036`, `RMB037`, `RMB050`, `RMB051` ; destruction d'une salle (`RMB033`, `RMB041`) et `payToPaywall` (`RMB046`) ; chaîne `RMB013` → `RMB017` (Imp Hoard récupère le Sort forcé) ; **les 42 héros** `RMB080`-`RMB121` (données complètes + distribution dans le deck de héros) ; **les 15 sorts** `RMB065`-`RMB079` (`RMB065`/`070`/`071`/`074` déjà couverts par `expansions.test.js`, +11 : `RMB066`, `RMB067`, `RMB068`, `RMB069`, `RMB072`, `RMB073`, `RMB075`, `RMB076`, `RMB077`, `RMB078`, `RMB079`).
* Couverture par set (présence de l'ID dans la suite, `test/*.js` × `docs/card-matrix.json`) : `players-choice` **11/11**, `tools` **25/25**, `crash-landing` **21/33** (12 résiduels = héros `stat-only` sans logique), `next-level` **54/115**, `minibosses` **117/121** (4 résiduels = salles `data-only` non implantées : `RMB014`, `RMB015`, `RMB020`, `RMB040`), `base` 61/96, `hidden-heroes` 1/41 (héros `stat-only`).
* **Validation :** `npm run test:unit` **400/400**, `npm run test:e2e` **29/29**, `npm run build` OK.

### 7.8. Capacités de boss Next Level (drapeaux sans effet → câblées)

Découvertes en écrivant les tests : ces drapeaux étaient **posés par le level-up mais jamais lus**, comme `copiedLevelUp` (§7.6).

| Carte | Comportement attendu | État |
|---|---|---|
| **TNL009 Nicolius** | Piocher un Sort en fin de tour si un joueur a gagné 2 Âmes de plus que vous ce tour | ✔ **Corrigé** : `processEndOfTurnBosses` (`src/expansionBosses.js`) appelé par `beginPhaseEnd`, avec snapshot des Âmes en début de tour (`beginPhaseBeginning`, `_soulsAtTurnStart`) |
| **TNL012 Eclipse** | La salle mise au jour par votre destruction gagne +3 jusqu'à la fin du tour | ✔ **Corrigé** : bonus posé dans `destroyRoom` (`src/engine.js`) quand `p.azarellaUncover` |
| **TNL001 Doc Scarecrow** | En phase Build : défausser une carte pour rendre un héros de la ville non attirable ce tour | ✔ **Câblé** : mouvement `docScarecrow` (`MOVE_HANDLERS` + `legalMoves` en Build), marque `hero.noLureThisTurn` lue par `resolveBait`, usage une fois par Build (`_scarecrowUsedThisBuild`, réinitialisé en Beginning), bouton **SCARECROW** + clic sur le héros dans `AppBoard`/`TownPanel` |
| **TNL003 Torix Uz'Kali** | Récupérer en main toute salle Monstre défaussée ou détruite | ✔ **Câblé** : `discardRoomToPile` (`src/engine.js`) remplace les 28 `roomDiscard.push` (destruction, défausses de main, objets, miniboss, sorts) ; résolution automatique (toujours prise), log `Torix Uz'Kali: recovered …` |
| **TNL005 Shellda** | En fin de tour : échanger deux salles d'un donjon | ✔ **Câblé** : `queueShelldaChoices` dans `processEndOfTurnBosses` → `pendingChoice` optionnel `shellda-swap` (options = paires de salles, tout donjon), résolution dans `resolveLevelUpChoice`, IA **saute** (`aiResolveLevelUpChoice → -1`), overlay existant `LevelUpChoiceOverlay` |
| **TNL008 Dr. Timebender** | Une fois par tour : défausser un Sort pour annuler un Sort adverse | ✔ **Câblé** : mouvement `timebenderCancel` (fenêtre de pile, garde `top.playerId !== pid`, usage une fois par tour via `_timebenderUsedThisTurn`), mêmes effets que le Contresort (les deux cartes partent à la défausse), bouton **TIMEBEND** pendant la fenêtre de réponse |

**Choix de conception :** il n'existe pas de plumbing générique « action de boss » côté reducer — chaque capacité a reçu son propre type de mouvement (validé par `VALID_MOVE_TYPES`, dérivé de `MOVE_HANDLERS`), son énumération dans `legalMoves`, son score IA dans `src/ai.js` (Scarecrow/Timebend : `-10` sauf situation clairement gagnante, pour que le bot ne gaspille pas ses cartes, pondéré par la valeur de la carte dépensée) et son bouton UI (`src/AppBoard.jsx`, barre `bossAbilityBar`). Les proxies de mouvements `src/client/useMatch.js` (mode local **et** online) ont été étendus en conséquence. Deux conventions ont été fixées en revue et servent de gabarit aux capacités suivantes : (1) une **action gratuite** de phase Build pose `G.skipAdvance = true` (le joueur conserve la priorité, comme les capacités de salle activées) et refuse d'agir tant que la pile de sorts est ouverte ; (2) `beginPhaseEnd` appelle **`checkEndGame` avant `processEndOfTurnBosses`**, pour qu'un choix de boss fileté (Shellda) ne soit jamais créé une fois `gameOver` posé — auquel cas plus aucun coup ne pourrait le résoudre.

**Validation :** `npm run test:unit` **303/303**, `npm run test:e2e` **29/29**, `npm run build` OK.

### 7.9. Revue de code des capacités de boss (correctifs)

| Sévérité | Problème | Correctif |
|---|---|---|
| **Bloquant** | `BMA048` (Jeopardy) et `RMB071` (Rebirth) défaussaient la main avec `while (p.hand.length) { … discardRoomToPile(…) }` : avec **TNL003 Torix**, la salle récupérée retournait dans la main pendant la boucle → **boucle infinie** (partie gelée) | Les deux effets échantillonnent la main (`hand.splice(0, len)`) **avant** de défausser (`src/spellEffects.js`) |
| **Important** | Doc Scarecrow n'était pas marqué `skipAdvance` → **passait le tour** malgré une action gratuite ; aucune garde tant que la pile est ouverte | `G.skipAdvance = true` + refus « must resolve the Spell stack first », garde symétrique dans `canScarecrow` (UI) |
| **Important** | Fin de partie + `shellda-swap` : le choix était filet **après** la victoire → `pendingChoice` non résoluble = **soft-lock** | Ordre inversé dans `beginPhaseEnd` + garde `if (G.gameOver) return` dans `queueShelldaChoices` + l'overlay n'est plus rendu quand `gameOver` |
| **Important** | Modes UI « armés » (Scarecrow/Timebend) **périmés** : pouvaient bloquer la construction au tour suivant | Effet de purge avant les retours anticipés de `AppBoard.jsx` (nombre de hooks stable) + `buildTargets` ne cède que si l'abilité est réellement utilisable |
| **Important** | Timebend jouait le sort immédiatement au clic, sans confirmation, et les cartes non « castables » n'étaient pas cliquables | Deux temps : **armement → sélection → clic TIMEBEND** ; prop `anySelectable`/`spellSelectable` sur `Hand.jsx` |
| **Important** | Miniboss en main défaussé via Doc Scarecrow / `openingDiscard` tombait dans la **défausse de salles** | Branche `isMiniboss` → `decks.minibossDiscard` (3 sites : `docScarecrow`, `applyOpeningDiscard`, déjà présent pour Rebirth) |
| **Important** | IA : tous les tirages d'un même type de coup avaient le même score → Scarecrow gaspillait la meilleure carte ; `resolveBait` recalculé par coup (quadratique) | Score par arguments (`src/ai.js`, `discardCost`) + mémo `resolveBait` par recherche |
| **Mineur** | Héros déjà marqué encore proposé par `legalMoves` | Filtre `!h.noLureThisTurn` côté énumération + rejet côté handler |

**Couverture :** 7 tests de non-régression ajoutés (6 dans `test/next-level.test.js`, 1 dans `test/ai.test.js`), dont un test de fin de partie complète qui échouait en soft-lock avant correction.

**Validation :** `npm run test:unit` **303/303**, `npm run build` OK.

**Livraison :** commit `1352c19` poussé sur `main`, déployé sur ZimaOS (`git pull` + `docker compose up -d --build`, image `boss-monster:latest` reconstruite), `GET /health` → `{"ok":true,…,"storage":"postgres"}`, `GET /lobby/games` → `["boss-monster"]`.

### 7.10. Art des extensions — état des lieux et sources auditées (tâche « art »)

Objectif : faire passer les **108 cartes sans visuel** (§7) à zéro. `npm run fetch:expansion-art` (`tools/fetch_expansion_art.py`) a été rejoué ; il a **re-téléchargé 2 fichiers** (TNL078, TNL090, contenu identique → aucun diff) et **0 nouvelle carte** : les 108 restants sont introuvables sur les sources du projet.

| Source | Résultat de l'audit | Verdict |
|---|---|---|
| **Wiki fandom `bossmonster`** (`list=allimages` complet : **826 fichiers**) | **0 fichier `RMB*`**, 2 fichiers `TNL*`, et **aucun nom** correspondant aux cartes manquantes (« spectral », « monster academy », « vampire lab », « minotaur catacombs », « pool of shadows », « rebirth », « windfall », « heist », « traitor » … → 0 hit). Recherche par préfixe de nom : **2/108** (uniquement `Respawn.jpg` et une variante) | **Épuisé** — le wiki ne documente pas Rise of the Minibosses (aucune page par carte, `Category:Rise of the Minibosses` vide) |
| **Pages wiki par carte** (`action=parse`, titres nom/underscores/recherche) | 0 page « Spectral Bomb », « Monster Academy » … ; la page `List of Cards` ne contient **aucune image** | **Épuisé** |
| **APK 2.2.6** (`boss-monster-2-2-6/`, `src/apkCardManifest.json`) | 197 faces : `BAC/BMA/BMH/KSA/THK` uniquement — set de base + Tools of Hero-Kind + Players' Choice + Hidden Heroes ; aucun `rmb*`/`tnl*`/`crl*` | **Épuisé** (art des extensions jamais embarqué) |
| **BoardGameGeek** (`boardgame/246855 …/images`) | **HTTP 403** (Cloudflare) | **Bloqué** sans authentification |
| **DriveThru « Art Pack for Boss Monster Card Creator »** | Gratuit mais licence **expresse : ni redistribution hors DriveThru, ni altération** | **Écarté** (licenca incompatible avec un dépôt public) |
| **`tools/fetch_expansion_art.py` (4 étages : allimages par ID → page wiki → réutilisation par nom → `Special:FilePath`)** | Fonctionnel (utilisé au jour J pour TNL/RMB/CRL) mais **toutes les étapes retournent vide** sur ces 106 cartes | **Rien à récupérer** par ce biais |

**Ce qui reste en place :** repli « dos de carte » (`getCardImage` → `getWikiCardImage` sans fichier → le composant affiche le dos), déjà documenté en §7. Décision : **ne pas fabriquer d'art de synthèse ni de « fausses » cartes** (une image erronée est pire qu'un dos dans un jeu de cartes) tant qu'une source légitime n'est pas identifiée.

**Options ouvertes (non exercées)** : extraction depuis un mod Tabletop Simulator / un scan de la boîte fourni par l'utilisateur ; visuels officiels Rock Cairn / Brotherwise si une licence claire apparaît ; visuel généré uniquement si l'utilisateur valide explicitement ce parti pris.

**Validation :** `npm run test:unit` **303/303**, `npm run verify:assets` OK (« 98 missing wiki art » — ce compteur ignore le dossier `minibosses/` : 98 + 10 minibosses = **108**, chiffre confirmé par `npm run card-matrix`), `npm run build` OK ; `git status` propre (les 2 re-téléchargements sont binaires identiques).

### 7.11. Travaux en attente

| Tâche | État | Détail |
|---|---|---|
| **a** — capacités de boss Next Level | ✅ **Terminé, poussé, déployé** | §7.8 + §7.9 (commit `1352c19`) |
| **c** — art des extensions | ⏸️ **Bloqué sur une source** | §7.10 : 108 cartes sans visuel, sources auditées épuisées ; au choix de l'utilisateur |
| **b** — couverture des tests Minibosses | ✅ **Terminé, poussé** | §7.7 : `test/minibosses.test.js` (**96 tests**, file `test:unit`), `minibosses` **117/121** IDs couverts — cible atteinte : niveaux 1/2/3 des 10 minibosses, promotion/activation, 37 salles, 42 héros et 15 sorts du pack ; les 4 restants sont des salles non implantées (`data-only`) |

### 7.12. CI GitHub Actions — reprise des exécutions en échec

Toutes les exécutions récentes de `ci` étaient rouges. Deux causes touchaient `npm run test:unit` (propres à l'environnement CI, non reproductibles en local) :

| Échec | Cause | Correctif (`e351028`) |
|---|---|---|
| `test/base-set.test.js` → `ENOENT … boss-monster-2-2-6/assets/Content/CardDecks/BaseDeck/data.json` | le test lisait l'extrait de l'APK, **gitignoré** (disponible seulement sur la machine de l'auteur) | fixture commitée `test/fixtures/apk-base-heroes.json` (41 héros, 23 479 octets) ; le test lit la fixture et la compare à l'APK local **si présent** (test de parité ignoré sinon) |
| `test/soak.test.js` → `no terminal state in 3000 moves (phase=adventure)` | `test/helpers/aiSoak.js` construisait un flux `seeded()` **jamais utilisé** : `Math.random` (mélange des decks, capacités de salle/boss) restait non déterministe | `installSeededRandom(seed)` (xorshift posé sur `Math.random`) autour de `runGame` dans `playOne`, restauré en `finally` → les 14 parties du soak sont déterministes (plus longue : 1752/3000 coups) |

Une **troisième cause**, visible dès que `test:unit` repassait au vert (runs `37896216609`, `37903901511`) : `npm run test:e2e` échouait sur les **6 tests visuels** uniquement — les baselines `test/e2e/visual.spec.js-snapshots/<nom>-<projet>-linux.png` n'existent pas (seules les images `*-win32.png` sont versionnées) et Playwright **échoue** dès qu'une baseline manque (elle écrit l'image actuelle puis rapporte l'écart). *Correctif :* `test/e2e/visual.spec.js` détecte la présence d'un baseline pour la plateforme courante (`hasPlatformBaselines()`) et **saute** la suite à défaut ; les tests visuels restent actifs sous Windows (où les baselines sont maintenues) et repartiront automatiquement sur Linux dès que des images `*-linux.png` seront commitées. Résultat CI : 23 tests e2e verts + 6 ignorés au lieu de 6 échecs.

**Validation :** `npm run test:unit` **400/400** (14 fichiers ; vert aussi sous ubuntu/node 22 — run `37903901511`), `npm run test:e2e` **29/29** en local (6 visuels actifs sous win32), `npm run build` OK.
