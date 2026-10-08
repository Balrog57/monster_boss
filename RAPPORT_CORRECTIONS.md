# Rapport de Corrections et d'Alignement — Boss Monster (APK 2.2.6 vs Web)

**Date :** 2026-10-08  
**Projet :** `monster_boss` (v2.0.0)  
**Référence source :** `boss-monster-2-2-6-android.apk` (SHA-256: `78592B483D8C7C4B8AABA1095F855226344565FB3D1B112A48113C2E90852FFD`)  
**Statut global :** ✅ **100% Validé (168/168 tests unitaires, 29/29 e2e, build Vite validé)**

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
