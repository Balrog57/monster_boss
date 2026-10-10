# RAPPORT RÈGLES — Boss Monster 2.2.6 (APK) × moteur JS × port Godot 4

Généré le 2026-10-10 à partir du C# décompilé de l'APK, du moteur JS existant et du port Godot 4 en cours.

## 0. Provenance et méthode

| Élément | Valeur |
|---|---|
| APK | `boss-monster-2-2-6-android.apk`, SHA-256 `78592b48…` (conforme au rapport d'extraction) |
| Assemblage analysé | `DBMGame.dll` — 888 832 octets, SHA-256 `7bf2ae01…`, 918 types / 5 704 méthodes, x86/il-only |
| Décompilation | `ilspycmd` 9.1.0.7988 (mode projet, .NET 8) → `apk-original/decompiled/DBMGame/` (560 fichiers .cs) + `Wave/` (671) |
| Analyse assistée | REA 6.3.0 (`rea-dotnet-static`) : artifact, membres, graphe, reconstruction (64 méthodes verrouillées) — preuves dans `apk-original/decompiled/evidence/` |
| Index du code | `apk-original/decompiled/INDEX.md` (59 namespaces → types) |
| Couverture assets | `apk-original/decompiled/assets_coverage.md` |
| Référence officielle | `docs/rules/rules.md` (livre de règles 10ᵉ anniversaire) |
| Nature de l'analyse | 100 % statique, aucune exécution du code cible |

Le C# cité est une **reconstruction IL→source** : les chemins et numéros de ligne renvoient au décompilé, pas au source d'origine de Wave Engine.

## 1. Légende

| Statut | Signification |
|---|---|
| `aligné` | même règle, même résultat, vérifié des deux côtés |
| `partiel` | couvert mais sans les cas limites / constantes exacts |
| `divergent` | comportements différents — voir l'explication en clair |
| `absent JS` / `absent Godot` | règle présente dans l'APK, non implémentée côté port |
| `non vérifié` | source C# ou port non consulté sur ce point |

## 2. Synthèse des écarts majeurs

**Flux de partie** — Godot n'exécute jamais les phases `BEGINNING` ni `BAIT`, ordonne le donjon à l'envers, vide la ville à chaque fin de Build et ne connaît ni les 5 blessures / 10 âmes, ni les minuteurs (70 s / 60 s / 3 s), ni l'`ExtraBuildPhase`. Le JS conclut la partie sur l'épuisement des héros et départage par XP **la plus basse** quand l'APK départage par XP **la plus élevée**.

**Habilités** — le C# résout les habilités par **réflexion depuis le JSON des cartes** (`AbilityFactory`) avec transactions annulables ; le JS embarque tout en `switch` par id de carte. Tous les joueurs peuvent répondre à un sort côté C#, seul le joueur actif (et 4 sorts précis) côté JS. Portée JS : 8/12 triggers, 4/7 conditions, 43/47 commandes, 26/31 cibles. Port Godot : **0 habilité** (trou déclaré).

**IA adverse** — l'APK calcule des scores pondérés (trésor « early » 100/50/0, pénalité bait −100 × blessures, combos de placement +10 000 / ±500 / −1 000, arbitrage pioche salle-vs-sort) que ni `ai.js` ni `AI.gd` n'évaluent : comportements d'ouverture **opposés** côté trésor, décisions de placement simplifiées, triggers carte-par-carte non portés (~28 heuristiques C# contre 8 constantes JS, zéro Godot).

**Couverture assets** — 11 des 12 chemins `Content/…` référencés dans le C# sont présents dans l'APK ; `Common/marketItems.json` (achats in-app) est le seul manquant. Les répertoires `Audio/`, `CardDecks/`, `NinePatch/`, `Tutorial/` de l'APK ne sont pas tous couverts par les scripts d'extraction actuels.

## 3. Limites connues

- Les 269 ids `CRL/RMB/TNL` (extensions) n'ont **aucune** source APK : les extensions étaient du
  contenu téléchargeable, absent de l'APK 2.2.6. Source de vérité du port = le wiki
  (`tools/fetch_expansion_packs.py` → `assets/data/expansions/*.json` → `tools/merge_expansions.py`
  → `cardData.json`), à recouper avec le livre de règles : statut `non vérifié (APK)`.
- `NullAI` n'est jamais instancié ; `DamageModifier` (`DungeonSlotCalculator.cs:49-57`) est du code mort — signalés comme tels.
- Les DLL `mscorlib`/`System.*`/`Photon*`/`OpenTK*` n'ont pas été décompilées (bibliothèques, pas de règles).
- Les données de cartes ne sont pas dans la DLL : elles vivent dans `assets/Content/CardDecks/*/data.json`.

# Carte des règles — Partie 1 : Flux et phases

**Portée** : boucle de parties, ordre des phases, priorités et timings, conditions de fin de partie, damier/donjon, pioche/défausse/pioche de héros/bait.

**Sources vérifiées** (chemins relatifs à la racine de chaque implémentation) :

- C# original : `apk-original/decompiled/DBMGame/` → `DBMGameModel.Logic/GameBoard.cs`, `Boss.cs`, `DungeonSlot.cs`, `DBMGameProject.Extensions/GameBoardExtensions.cs`, `DBMGameProject.Scenes.GamePlay/GamePlayBaseScene.cs`, `DBMGameProject.Scenes.GamePlay.SceneBehaviors/BuildRoomHandSceneBehavior.cs`, `DBMGameProject.Scenes.GamePlay.Components/DoneButtonBehavior.cs`, `DBMGameProject.Scenes.GamePlay/RandomBossSelectionScene.cs`, `DBMGameModel.Logic.Abilities.LuredConditions/`
- JS : `src/backend/game/` → `reducer.js`, `engine.js`, `cardData.js`, `items.js`, `stack.js`
- Godot : `godot/scripts/` → `Match.gd`, `GameManager.gd`, `CardDB.gd`, `BossEngine.gd`, `BoardUI.gd`, `Main.gd`
- Référence officielle : `docs/rules/rules.md`

**Légende des statuts** : `aligné` = même règle dans les trois implémentations ; `partiel` = même intention, mécanique différente ; `divergent` = comportements incompatibles (une phrase en fin de document) ; `absent JS` / `absent Godot` = règle non portée. Une cellule « — » signifie que l'implémentation ne porte pas la règle.

**Note Godot** : deux contrôleurs coexistent. La boucle vit dans `Match.gd` (miroir assumé de `reducer.js`), étendu par `GameManager.gd` (`class_name GameManager extends Match`), et la scène vivante est `Main.gd` → `Board.tscn` → `BoardUI.gd`, qui appelle tantôt `apply_move` (`Match`) tantôt `build_room_at` (`GameManager`).

### 1.1 Machine à états des phases (`GameBoard.GamePhases`, `NextStep()`, transactions en attente, `ExtraBuildPhase`)

| Règle | C# original (fichier:ligne) | JS (fichier:ligne) | Godot (fichier:ligne) | Statut |
|---|---|---|---|---|
| Énumération des phases : `Setup_a/b/c`, `BeginningOfTurn`, `BuildPhase_a/b`, `BaitPhase`, `AdventurePhase_a/b/c`, `EndOfTurnPhase`, `EndOfGame`, `ExtraBuildPhase` | `GameBoard.cs:15-30` | `cardData.js:107-115` (7 phases plates, pas de sous-phases ni d'`ExtraBuild`) | `CardDB.gd:5-13` (7 phases plates) | `partiel` |
| Boucle Setup → Beginning → Build → Bait → Adventure → End → Beginning | `GameBoard.cs:333-460` | `reducer.js:527-563` | `Match.gd:142,157,181,274-275` (jamais BEGINNING ni BAIT) | `divergent` |
| Commit de phase (`CurrentGamePhase ← NextGamePhase`, successeur calculé) et exception si aucune phase successeur | `GameBoard.cs:454-459` | `reducer.js:233-244,527-562` | `Match.gd:157,181,274` | `partiel` |
| `PendingAbilityTransactions` entièrement drainées en tête de chaque `NextStep()` | `GameBoard.cs:306-315` | `stack.js:34-43` + `reducer.js:650-656` (résolution LIFO seulement après accord de tous) | — | `partiel` |
| Priorité du joueur actif dans les réponses (ses effets partent en premier) | `GameBoard.cs:1317-1333` | `reducer.js:578-588,888-892` | — | `aligné` |
| Fenêtre de réponse ouverte à tous les joueurs en vie | `GameBoard.cs:775-782` (diffusion simultanée) | `reducer.js:601-616,1128-1137` (passage en ordre de XP) | — | `partiel` |
| `NextStep()` bloqué pendant une Spell Battle jusqu'au « prêt » de tous | `GameBoard.cs:320-329`, `GamePlayBaseScene.cs:587-617` | — | — | `absent JS` |
| Injection d'une phase `ExtraBuildPhase` quand des tours de construction supplémentaires sont en attente | `GameBoard.cs:316-319,412-420` | `reducer.js:204,934` (compteur `extraBuildsFor`, pas de phase) | — | `divergent` |
| Un seul joueur actif à la fois ; joueur suivant selon `PlayerId` attribué par XP décroissant | `GameBoard.cs:1185-1211`, `GameBoardExtensions.cs:115-119` | `reducer.js:219-231,237` | `Match.gd:56-57` (`xpOrder[0]` fixe, aucun actif par phase) | `divergent` |
| Coups légaux filtrés par phase (construction réservée à la phase Build) | `GameBoard.cs:297-300` | `reducer.js:1598-1714` (+ construction immédiale en Adventure, `reducer.js:928`) | `Match.gd:69-89` | `partiel` |


### 1.2 Orchestration de la partie (`GamePlayBaseScene.cs` : tours, ordre, priorité, timings, défausse initiale, choix du boss, révélation)

| Règle | C# original (fichier:ligne) | JS (fichier:ligne) | Godot (fichier:ligne) | Statut |
|---|---|---|---|---|
| Distribution initiale de 5 salles + 2 sorts, puis défausse de 2 cartes (main ramenée à 5) | `GameBoard.cs:336-344,917-926` | `reducer.js:305-317,278-289,1165-1172` | `Match.gd:137-144` (3+2, aucune défausse) | `divergent` |
| La défausse initiale est séquentielle et bloque tout autre coup tant que tout le monde n'a pas défaussé | `GameBoard.cs:348-351,917-926` | `reducer.js:284-289,1275-1277` | — | `partiel` |
| Anti-mulligan : ≥ 4 salles avancées ou ≥ 4 trésors d'une même classe → re-tirage complet | `GameBoard.cs:883-915` | — | — | `absent JS` |
| Amorçage des défausse de départ (4 salles + 2 sorts) | `GameBoardExtensions.cs:142-157` (aucun amorçage) | `reducer.js:319-320` | — | `divergent` |
| Choix du boss avant la distribution (pool partagé, un boss par joueur) | `GamePlayBaseScene.cs:570-575,991-1006`, `RandomBossSelectionScene.cs:44-60` | `reducer.js:83-86,895-905,1311-1313` (pool de 2n) | `Match.gd:33,104-113` (pool de n+2) | `partiel` |
| Première salle construite face cachée en ordre de XP, révélée ensuite en même temps | `GameBoard.cs:348-359,928-970`, `BuildRoomHandSceneBehavior.cs:182` | `reducer.js:907-923,326-342` | `Match.gd:74-79,114-121` (posée visible) | `divergent` |
| Bouton Pass/Done avec minuteur de 70 s (variantes timer vs illimité) | `GamePlayBaseScene.cs:272`, `DoneButtonBehavior.cs:37-55`, `DoneButtonEntity.cs:171-185` | `reducer.js:1679,1711` (`pass` sans minuteur) | `BoardUI.gd:156,175-176` (`passBuild` sans minuteur) | `divergent` |
| Timeout global de tour de 60 s | `GamePlayBaseScene.cs:131-141` | — | — | `absent JS` |
| Fenêtre d'aventure chronométrée (3 s par palier de salle, ralentie pendant les sorts/zooms) | `GamePlayBaseScene.cs:215,924-952` | `reducer.js:611-648,1128-1137` (fenêtre de réponse sans minuteur) | `Match.gd:127-128` (résolution à la demande) | `partiel` |
| Résultat de fin de tour : restauration des salles, réactivation des emplacements, vérification de fin | `GameBoard.cs:441-448,1051-1060` | `reducer.js:404-425,500-517` | `Match.gd:154-156` (seul `buildsThisTurn` est remis à 0) | `partiel` |

### 1.3 Conditions de fin de partie

| Règle | C# original (fichier:ligne) | JS (fichier:ligne) | Godot (fichier:ligne) | Statut |
|---|---|---|---|---|
| 5 blessures → élimination du joueur | `GameBoard.cs:32`, `Boss.cs:82-90` | `engine.js:700` | `Match.gd:251-253`, `GameManager.gd:137-139` | `aligné` |
| 10 âmes → victoire | `GameBoard.cs:34,987-990` | `engine.js:721-730` | `Match.gd:9,256-262` | `aligné` |
| 10 âmes ne gagnent que si le joueur a moins de 5 blessures | `GameBoard.cs:1041-1049` | `engine.js:700,721-730` | `Match.gd:257-262` (aucun contrôle) | `divergent` |
| Vainqueur quand un seul joueur est encore en vie | `GameBoard.cs:981-984` | `engine.js:731-734` | `Match.gd:263-272` | `aligné` |
| Départage (égalité d'âmes ou tous morts) : max(âmes − blessures), puis XP le plus bas | `GameBoard.cs:1014-1033` (`orderby PlayerId` croissant = XP la plus élevée) | `engine.js:725-730,735-743` | `Match.gd:263-272` (aucun départage, `winner = -1` si 0 survivant) | `divergent` |
| Fin de partie quand les decks de héros sont épuisés | `GameBoard.cs:1241-1255` (journal seul) | `engine.js:714,747-760` | `Match.gd:273-275` (ville vide → tour suivant) | `divergent` |
| Reprise des défausse quand un deck est vide | `GameBoard.cs:541-544,1335-1349` | `cardData.js:194-212`, `reducer.js:56-61` | `CardDB.gd:85-94`, `Match.gd:163,203-207` | `aligné` |
| Défaite immédiate affichée quand tous les joueurs humains sont éliminés | `GamePlayBaseScene.cs:1071-1078` | — | — | `absent JS` |


### 1.4 Damier et donjon

| Règle | C# original (fichier:ligne) | JS (fichier:ligne) | Godot (fichier:ligne) | Statut |
|---|---|---|---|---|
| Donjon limité à 5 emplacements | `Boss.cs:153-158` | `engine.js:29,277-280` | `CardDB.gd:16`, `GameManager.gd:65` | `aligné` |
| Une seule salle construite par tour | `Boss.cs:145,168-171`, `GameBoard.cs:1215` | `reducer.js:204-205,934-935` | `GameManager.gd:37`, `Match.gd:81,118` | `aligné` |
| Donjon plein (5) : l'emplacement cible doit être précisé et aucune pile vide précédente ne peut être sautée | `Boss.cs:172-188` | `engine.js:280,331-342` | `GameManager.gd:62-65` | `aligné` |
| Nouvelle pile construite côté entrée (donc combattue en premier) | `Boss.cs:180-188`, `GameBoard.cs:1099-1114` (le héros descend du dernier index vers 0) | `engine.js:331-342` (insertion en index 0) | `Match.gd:117`, `GameManager.gd:84` (`append` en fin de liste) | `divergent` |
| Salle avancée : jamais sur emplacement vide, trésor correspondant obligatoire | `DungeonSlot.cs:89-103` | `engine.js:284-307` | `GameManager.gd:49-65` | `aligné` |
| Pas de construction sur un emplacement encore en attente de révélation | `DungeonSlot.cs:84-88` | `engine.js:268-308` (—) ; garde par le quota de 1 construction, `reducer.js:934` | — | `absent JS` |
| Interdiction de construction (`buildBlocked`) et construction forcée d'une salle imposée | `GameBoard.cs:1216`, `Boss.cs:259-268` | `engine.js:273-274` | — | `partiel` |

### 1.5 Pioche, défausse, pioche de héros et bait

| Règle | C# original (fichier:ligne) | JS (fichier:ligne) | Godot (fichier:ligne) | Statut |
|---|---|---|---|---|
| Début de tour : chaque joueur en vie pioche 1 salle (ou 1 sort par capacité) | `GameBoard.cs:360-393` | `reducer.js:379-403` | `Match.gd:152-167` (pioche jusqu'à 5) | `divergent` |
| Ordre de cette pioche | `GameBoard.cs:365` (ordre de XP) | `reducer.js:380` (ordre des sièges) | `Match.gd:154-156` (ordre des sièges) | `divergent` |
| 1 héros révélé en ville par joueur en vie | `GameBoard.cs:1241-1255` | `reducer.js:366-375` | `Match.gd:199-210` (4 héros fixes) | `divergent` |
| La ville se cumule d'un tour à l'autre | `GameBoard.cs:1247-1248` (file conservée) | `reducer.js:371` (`town.push`) | `Match.gd:200` (`town = []` à chaque fin de Build) | `divergent` |
| 1 objet révélé avec les héros (2 en partie à 4) | `GameBoard.cs:1257-1268` | `items.js:7-9`, `reducer.js:356-364` | — | `absent Godot` |
| Phase BAIT sans sort ni abilité jouable | `GameBoard.cs:421-424` | `reducer.js:1683-1689` | — | `absent Godot` |
| Bait : héros attiré par le plus grand trésor, égalité → reste en ville | `GameBoard.cs:1220-1239`, `BaseLuredCondition.cs:17-25`, `LuredByTreasures.cs:21-25` | `engine.js:188-209,211-266` | `BossEngine.gd:58-75`, `Match.gd:216-221` | `divergent` |
| Traitement du bait en ordre FIFO de la ville | `GameBoard.cs:1222` | `engine.js:219` | `Match.gd:216` | `aligné` |

## Divergences confirmées

- Godot n'exécute jamais les phases BEGINNING ni BAIT (la ville est peinte en fin de Build, `Match.gd:180-181`) et revient de END directement au tour suivant (`Match.gd:273-275`), alors que l'APK et le JS les traversent systématiquement.
- Godot distribue 3 salles + 2 sorts sans défausse et pioche jusqu'à 5 cartes en début de tour (`Match.gd:141,160-167`), au lieu du 5 + 2 puis défausse de 2 de l'APK (`GameBoard.cs:336-344,917-926`) et du JS (`reducer.js:305-317`).
- Seul le JS amorce les défausse de 4 salles + 2 sorts demandées par `rules.md:74` (`reducer.js:319-320`) ; ni l'APK (`GameBoardExtensions.cs:142-157`) ni Godot ne le font.
- Godot empile ses nouvelles salles en fin de donjon (`Match.gd:117`, `GameManager.gd:84`), donc elles sont combattues en dernier, à l'inverse de l'APK (`Boss.cs:180-188`) et du JS (`engine.js:340`) qui les placent à l'entrée.
- Godot réinitialise la ville à chaque fin de Build et ne révèle que 4 héros (`Match.gd:199-210`), alors que l'APK et le JS révèlent 1 héros par joueur et laissent la ville se cumuler.
- Godot jette en défausse le héros dont le leurre fait égalité (`Match.gd:219-221`), alors que l'APK et le JS le laissent en ville (`BaseLuredCondition.cs:17-25`, `engine.js:207`).
- Godot déclare le vainqueur dès 10 âmes sans contrôle de blessures et ne connaît aucun départage par âmes − blessures ni par XP (`Match.gd:256-272`), alors que l'APK et le JS appliquent ces règles — et divergent entre eux : l'APK retient l'XP la plus élevée (`orderby PlayerId`, `GameBoard.cs:1030`) quand le JS et les règles retiennent la plus basse (`engine.js:728,742`).
- Le JS conclut la partie à l'épuisement des héros (`engine.js:747-760`) et porte les constructions supplémentaires en compteur (`reducer.js:204,934`) ; l'APK continue à piocher à vide (`GameBoard.cs:1241-1255`) et ajoute une phase `ExtraBuildPhase` (`GameBoard.cs:316-319`) ; Godot n'a ni l'un ni l'autre.
- Les minuteurs (70 s sur le bouton Done, 60 s de tour, 3 s par palier d'aventure) n'existent ni en JS ni en Godot (`GamePlayBaseScene.cs:131-141,215,272`).

## 2. Habilités et cartes

Section consacrée au système déclaratif d'habilités du jeu original (Triggers, Conditions, Commands,
Targets, LuredConditions) et à sa couverture dans les deux réimplémentations.

**Légende des chemins** (toutes les lignes citées ci-dessous ont été ouvertes et lues) :

| Abréviation | Chemin réel |
|---|---|
| `C#\...` | `apk-original\decompiled\DBMGame` |
| `JS\...` | `src\backend\game` |
| `Godot\...` | `godot\scripts` |
| `APK\...` | `apk-original\boss-monster-2-2-6\assets\Content\CardDecks` |

Référence officielle : `docs\rules\rules.md:21` (« Spells and activated abilities resolve in a
streamlined **"Last In, First Out"** order (the Stack) »), `rules.md:59`, `rules.md:126`
(définition *Activated Ability*), `rules.md:162-164` (les habilités « when you build » et Level Up
s'exécutent immédiatement, en ordre XP ; aucun sort ni habilité activée pendant Build avant révélation).

---

### 2.1 Inventaire C# — `DBMGameModel.Logic.Abilities.*`

L'arbre `DBMGameModel.Logic.Abilities` contient 6 sous-espaces de noms. Base commune :

| Élément | Fichier:ligne | Rôle |
|---|---|---|
| `Ability` | `C#\DBMGameModel.Logic.Abilities\Ability.cs:13` | Conteneur : `Trigger` + `Conditions` + `Effects` |
| `Ability(AbilityInfo, ILogicCard)` | `Ability.cs:43-69` | Construction depuis le JSON : Trigger L52-55, Conditions L56-63, Effects L64-68 |
| `CheckConditions` | `Ability.cs:83-127` | Garde : phase/trigger/`IsLocked` L86-88, conditions L91-98, **min. de cibles disponibles** L100-124 |
| `DoEffect` / `UndoEffect` | `Ability.cs:129-149` | Applique puis annule (ordre inversé L144) |
| `IsActivatedByUser` | `Ability.cs:25-35` | `Trigger == null` ⇒ activée par le joueur (sinon déclenchée) |
| Helpers passifs | `Ability.cs:191-285` | `GetPassiveWounds/Souls/Treasures/Damage`, `IsUndoableType` (247), `IsUntilEndOfGameSpellType` (252), `IsPassiveType` (267), `IsCollectionTargets` (272) |
| `Effect` | `Effect.cs:11` | 1 liste de `TargetsProviders` + 1 liste de `Commands` (`Effect.cs:19-21`) |
| `Effect(EffectInfo, Ability)` | `Effect.cs:32-50` | Instancie les cibles L40-44 et les commandes L45-49 |
| Multi-cibles | `Effect.cs:125-166` | `ClearTargets` : un seul `IsMultiTarget` par effet (L133-137), clone de commandes L148-165 |
| `AbilityTransaction` | `AbilityTransaction.cs:9` | Machine à états (L11-19) |
| Liaison cible→champ | `BaseCommand.cs:73-77` | Attributs réflexifs `[RequiredTarget]`/`[RequiredParameter]` |

#### Triggers — `C#\DBMGameModel.Logic.Abilities.Triggers` (12 concrets + 1 abstraite)

| Classe | Fichier:ligne |
|---|---|
| `BaseTrigger` (abstraite) | `BaseTrigger.cs:3` |
| `AnySpellCardIsPlayed` | `AnySpellCardIsPlayed.cs:3` |
| `AtTheBeginingOfYourTurn` | `AtTheBeginingOfYourTurn.cs:3` |
| `FirstTimeHeroEnterThisRoom` | `FirstTimeHeroEnterThisRoom.cs:3` |
| `HeroDiesAnotherRoom` | `HeroDiesAnotherRoom.cs:3` |
| `HeroDiesInThisRoom` | `HeroDiesInThisRoom.cs:3` |
| `ThisHeroEntersDungeon` | `ThisHeroEntersDungeon.cs:3` |
| `WhenAnotherRoomIsDestroyed` | `WhenAnotherRoomIsDestroyed.cs:3` |
| `WhenOpponentPlaysSpellCard` | `WhenOpponentPlaysSpellCard.cs:3` |
| `WhenThisRoomIsDestroyed` | `WhenThisRoomIsDestroyed.cs:3` |
| `WhenYouBuildAnotherRoom` | `WhenYouBuildAnotherRoom.cs:3` |
| `WhenYouBuildThisRoom` | `WhenYouBuildThisRoom.cs:3` |
| `YouPlaySpellCard` | `YouPlaySpellCard.cs:3` |

#### Conditions — `C#\DBMGameModel.Logic.Abilities.Conditions` (7 concrètes + 1 abstraite)

| Classe | Fichier:ligne | Sémantique lue |
|---|---|---|
| `BaseCondition` | `BaseCondition.cs:3` | `CheckCondition(GameBoard)` L9, `Setup(string[])` L11 |
| `DuringPhase` | `DuringPhase.cs:5` | L15-21 : `Build` ⇒ `BuildPhase_a`, sinon les 3 phases Adventure ; parse L26 |
| `HasPendingRoomToBuild` | `HasPendingRoomToBuild.cs:6` | salle en construction en attente |
| `HeroHasAtachedItem` | `HeroHasAtachedItem.cs:5` | héro cible équipé |
| `OncePerTurn` | `OncePerTurn.cs:3` | L12 : `return !ability.IsEffectApplied;` |
| `OpponnentDungeonSizeMoreThan` | `OpponnentDungeonSizeMoreThan.cs:5` | taille de donjon adverse |
| `OpponnentHasMoreThanInHand` | `OpponnentHasMoreThanInHand.cs:6` | carte en main adverse |
| `OwnerHasFewerThanOpponent` | `OwnerHasFewerThanOpponent.cs:6` | comparaison de compteurs |

#### LuredConditions — `C#\DBMGameModel.Logic.Abilities.LuredConditions` (5 + abstraite)

| Classe | Fichier:ligne | Sémantique lue |
|---|---|---|
| `BaseLuredCondition` | `BaseLuredCondition.cs:6` | `GetBosses` abstrait L27, `GetBoss` L17-25 |
| `LuredByTreasures` | `LuredByTreasures.cs:8` | L21-39 : max de trésors correspondants |
| `LuredByFewerSouls` | `LuredByFewerSouls.cs:6` | L18-22 : **min** d'âmes (« The Fool ») |
| `LuredBySouls` | `LuredBySouls.cs:6` | L18-22 : max d'âmes |
| `LuredByWounds` | `LuredByWounds.cs:6` | L18-22 : **min** de blessures |
| `LuredByCardsInHand` | `LuredByCardsInHand.cs:6` | L18-22 : max de cartes en main |

#### Commands — `C#\DBMGameModel.Logic.Abilities.Commands` (47 concrètes + `BaseCommand` + `IBuildRestrictionCommand`)

`BaseCommand` (`BaseCommand.cs:9`) impose `Execute`/`Undo`/`Clear`/`SetParameters`/`SetTarget`
(`BaseCommand.cs:22-30`), expose les champs `[RequiredTarget]` par réflexion (`BaseCommand.cs:73-77`)
et `RequiredTargetsCountByType` (`BaseCommand.cs:51`).

Interfaces (`...\Commands.Interfaces`) : `IPassiveDamageCommand.cs:3`, `IPassiveScorekeepCommand.cs:3`,
`IPassiveTreasureCommand.cs:6`, `IUndoableCommand.cs:3`, `IUntilEndOfGameCommand.cs:3`.

| Classe | Fichier:ligne | Classe | Fichier:ligne |
|---|---|---|---|
| `AddSoulsToBoss` | `AddSoulsToBoss.cs:5` | `LastRoomDealDamage` | `LastRoomDealDamage.cs:6` |
| `AddSoulsToBossIfTreasures` | `AddSoulsToBossIfTreasures.cs:9` | `MoveHeroToRelativeSlot` | `MoveHeroToRelativeSlot.cs:5` |
| `AddTreasuresToDungeon` | `AddTreasuresToDungeon.cs:8` | `MultiplyTreasuresDungeon` | `MultiplyTreasuresDungeon.cs:3` |
| `BuildExtraRoom` | `BuildExtraRoom.cs:3` | `PickRandomCardFromHand` | `PickRandomCardFromHand.cs:7` |
| `BuildRoomBy` | `BuildRoomBy.cs:5` | `PlaceAtDungeonEntrance` | `PlaceAtDungeonEntrance.cs:5` |
| `CancelSpellAbility` | `CancelSpellAbility.cs:5` | `PlaceAtOwnerDungeonEntrance` | `PlaceAtOwnerDungeonEntrance.cs:5` |
| `CannotBuildRoom` | `CannotBuildRoom.cs:5` | `PlaceAtScorekeep` | `PlaceAtScorekeep.cs:5` |
| `ChooseAndDestroyRoom` | `ChooseAndDestroyRoom.cs:8` | `PlaceAtTown` | `PlaceAtTown.cs:3` |
| `ChooseCardFromHand` | `ChooseCardFromHand.cs:5` | `PutCardInHand` | `PutCardInHand.cs:3` |
| `ChooseCardToDraw` | `ChooseCardToDraw.cs:3` | `RearrangeDungeon` | `RearrangeDungeon.cs:7` |
| `DeactivateDungeonAbility` | `DeactivateDungeonAbility.cs:7` | `RemoveHeroFromTheGame` | `RemoveHeroFromTheGame.cs:5` |
| `DeactivateRoom` | `DeactivateRoom.cs:5` | `RoomDamageEqualToCount` | `RoomDamageEqualToCount.cs:8` |
| `DealDamageToDungeon` | `DealDamageToDungeon.cs:3` | `SendBackToDungeonEntrance` | `SendBackToDungeonEntrance.cs:5` |
| `DealDamageToRoom` | `DealDamageToRoom.cs:5` | `SkipAdventurePhase` | `SkipAdventurePhase.cs:5` |
| `DealHero` | `DealHero.cs:3` | `SkipBeginingOfTurn` | `SkipBeginingOfTurn.cs:5` |
| `DealRoomsCountToHero` | `DealRoomsCountToHero.cs:7` | `SkipBuildPhase` | `SkipBuildPhase.cs:5` |
| `DestroyRoom` | `DestroyRoom.cs:5` | `SwapSlotInDungeon` | `SwapSlotInDungeon.cs:3` |
| `DiscardAllHand` | `DiscardAllHand.cs:6` | `UndoBuildRoom` | `UndoBuildRoom.cs:5` |
| `DiscardRandomCardFromHand` | `DiscardRandomCardFromHand.cs:7` | `FlipItem` | `FlipItem.cs:5` |
| `DiscardSomeCardFromHand` | `DiscardSomeCardFromHand.cs:8` | `FlipHero` | `FlipHero.cs:3` |
| `DiscardTargetRoomFromHand` | `DiscardTargetRoomFromHand.cs:3` | `HeroResistDamageRoomType` | `HeroResistDamageRoomType.cs:7` |
| `DiscardTargetSpellFromHand` | `DiscardTargetSpellFromHand.cs:3` | `IBuildRestrictionCommand` | `IBuildRestrictionCommand.cs:3` |
| `DrawCards` | `DrawCards.cs:6` | `KillHero` | `KillHero.cs:5` |
| `ExtraBuildTurn` | `ExtraBuildTurn.cs:3` | `KillHeroInRoom` | `KillHeroInRoom.cs:6` |

#### Targets — `C#\DBMGameModel.Logic.Abilities.Targets` (33 fichiers : 2 abstraits + 31 concrets)

Classes abstraites : `BaseTargetProvider.cs:5`, `SingleTargetProvider.cs:7`,
`ComposedTargetProvider.cs:7`.

| Classe | Fichier:ligne | Classe | Fichier:ligne |
|---|---|---|---|
| `ActiveHeroInDungeon` | `ActiveHeroInDungeon.cs:7` | `NextRoom` | `NextRoom.cs:6` |
| `AdjacentsRoom` | `AdjacentsRoom.cs:6` | `RoomInDeck` | `RoomInDeck.cs:7` |
| `AllBoss` | `AllBoss.cs:5` | `RoomInDungeon` | `RoomInDungeon.cs:7` |
| `AnotherRoom` | `AnotherRoom.cs:5` | `RoomInHand` | `RoomInHand.cs:7` |
| `BossDungeon` | `BossDungeon.cs:3` | `SpellCardJustPlayed` | `SpellCardJustPlayed.cs:6` |
| `BossOpponent` | `BossOpponent.cs:5` | `SpellInDeck` | `SpellInDeck.cs:7` |
| `BossOpponents` | `BossOpponents.cs:5` | `SpellInHand` | `SpellInHand.cs:6` |
| `BossOpponentWithAtLeastHand` | `BossOpponentWithAtLeastHand.cs:6` | `ThisRoom` | `ThisRoom.cs:6` |
| `BossOpponentWithAtLeastScore` | `BossOpponentWithAtLeastScore.cs:6` | `CrossingHeroAtachedItem` | `CrossingHeroAtachedItem.cs:6` |
| `BossOwner` | `BossOwner.cs:5` | `HeroInDeck` | `HeroInDeck.cs:6` |
| `CardInDeck` | `CardInDeck.cs:7` | `ItemInScorekeep` | `ItemInScorekeep.cs:6` |
| `CardInHand` | `CardInHand.cs:7` | `ItemInTown` | `ItemInTown.cs:6` |
| `HeroInDungeon` | `HeroInDungeon.cs:7` | `LastSpellPlayed` | `LastSpellPlayed.cs:6` |
| `HeroInScorekeep` | `HeroInScorekeep.cs:7` | `HeroUnassigned` | `HeroUnassigned.cs:7` |
| `HeroInThisRoom` | `HeroInThisRoom.cs:6` | `HeroInTown` | `HeroInTown.cs:7` |

---

### 2.2 `AbilityFactory` : instanciation par réflexion, transactions, ordre de pile

**Fabrique** (`C#\DBMGameModel.Logic\AbilityFactory.cs:14`, singleton L16-32) :

- `FindType` (`AbilityFactory.cs:124-134`) : parcourt `assembly.DefinedTypes` et compare
  `t.Name.ToLowerInvariant() == typeString.ToLowerInvariant()` — le `TypeName` du JSON est donc le
  **nom de classe C#**, insensible à la casse ; `typeString == null` ⇒ `null` (L129-132).
- Créateurs : `CreateCommand` L34-53 (`Activator.CreateInstance(type, owner)` L47 puis
  `SetParameters(parameters)` L50), `CreateTargetProvider` L55-74, `CreateCondition` L76-101
  (`Setup(parameters)` L98), `CreateLuredCondition` L82-106, `CreateTrigger` L108-122.
- **Anomalie vérifiée** : `CreateTrigger(Type, string[])` L119-122 ignore `parameters`
  (`return (BaseTrigger)Activator.CreateInstance(type);`) — aucun trigger n'emporte de paramètre.

**Entrée JSON** : `AbilityInfo` (`C#\DBMGameModel.Info\AbilityInfo.cs:3-12`) = `CanAvoid`,
`Trigger` (`TypeParametersPair`), `Conditions[]`, `Effects[]`. Exemple réel
(`APK\BaseDeck\data.json`, boss `BMA001`) : `Trigger: null`, cibles `CardInHand["1","Opponent"]` +
`BossOwner[]`, commande `PutCardInHand[]`.

**`AbilityTransaction`** (`AbilityTransaction.cs:9`) :

| Étape | Ligne | Comportement |
|---|---|---|
| États | `AbilityTransaction.cs:11-19` | `Waiting → ResolvingTargets → TargetsResolved → Running → (Canceled\|Finished)` |
| `ResolveTargets` | `AbilityTransaction.cs:58-78` | Construit la file d'actions puis la joue ; si vide ⇒ `TargetsResolved` immédiat |
| File d'actions | `AbilityTransaction.cs:165-222` | Par `Effect` : `ClearTargets` (L171-175), puis 1 action par `TargetProvider` appelant `PlayerInteraction.ResolveTarget(...)` (L181-205) avec `Ability.CanAvoid` (L205) |
| Annulation cible | `AbilityTransaction.cs:184-196` | cible invalide ou interaction joueur ⇒ `Cancel()` |
| `Run` | `AbilityTransaction.cs:80-117` | vérifie `CheckIfAbilityTargetsAreWellResolved` (L94, méthode L224-232), appelle `Ability.DoEffect` (L98), exception catchée + log (L100-103), callback plateau `OnAbilityApplyDone` (L104-107) |
| `Cancel` | `AbilityTransaction.cs:119-125` | annulation complète |
| Clone (réseau) | `AbilityTransaction.cs:132-152` | `ShallowCopy` + `Effect.ChangeTargetsFields` (L146-149) |

**Pile de sorts / ordre de résolution** (`C#\DBMGameModel.Logic\GameBoard.cs`) :

| Mécanique | Ligne |
|---|---|
| `public List<AbilityTransaction> PendingAbilityTransactions` | `GameBoard.cs:44` |
| File d'attente des sorts en main (`SpellBattleCards`) | `GameBoard.cs:94-96` |
| `EnqueueAbilityTransaction` — joueur actif inséré en **index 0** (priorité), sinon insertion avant le premier non-actif de `PlayerId >= ` (L1328-1329), puis `ResolveTargets()` immédiat (L1332) | `GameBoard.cs:1317-1333` |
| Contre-sort réordonné **juste avant** la carte visée | `GameBoard.cs:763-769` |
| `NextStep` : drain `First()` → `Run()` en boucle (FIFO de la liste, LIFO pour les contre-sorts par insertion) | `GameBoard.cs:306-315` |
| Début de *Spell Battle* : `IsActivatedByUser` ⇒ `PendingSpellBattlePlayers = InGamePlayersPriorized` (tous les joueurs peuvent répondre) | `GameBoard.cs:754-762` |
| Fin de Spell Battle / exception si non fini | `GameBoard.cs:320-329` |
| Défausse du sort à l'application | `GameBoard.cs:770-774` |
| Après résolution : `YouPlaySpellCard` (L796), `WhenOpponentPlaysSpellCard` (L801), `AnySpellCardIsPlayed` (L803) | `GameBoard.cs:785-810` |
| Sort « jusqu'à fin de partie » retiré de la partie | `GameBoard.cs:791-795` |
| Annulation des transactions dont la cible disparaît | `GameBoard.cs:1351-1361` |
| Undo réel : `UndoEffect` quand un héro porteur d'habilité quitte la partie | `GameBoard.cs:694-700` |

**Reset `OncePerTurn`** : `Ability.DoEffect` pose `IsEffectApplied` (`Ability.cs:135`), `Clean()`
le remet à `false` (`Ability.cs:151-154`) appelé par `Boss.RestoreDungeon`
(`C#\DBMGameModel.Logic\Boss.cs:244`) lui-même appelé en `EndOfTurnPhase` (`GameBoard.cs:441-447`).
À noter : `Room.IsAbilityUsed` (`C#\DBMGameModel.Logic\Room.cs:12`) n'est **jamais écrit** dans le
binaire décompilé (seule lecture : `Room.cs:70`).

---

### 2.3 Déclenchement et résolution des cibles (scène)

**Points d'appel des triggers** (`C#\DBMGameModel.Logic\GameBoard.cs`) :

| Moment de déclenchement | Ligne |
|---|---|
| Début de tour (`AtTheBeginingOfYourTurn`), après le choix de pioche | `GameBoard.cs:364-391` (trigger L388) |
| Révélation des salles construites : `WhenYouBuildThisRoom` (L950) + `WhenYouBuildAnotherRoom` (L951) | `GameBoard.cs:928-969` |
| Level Up à 5 salles, `CheckConditions` puis enfilement | `GameBoard.cs:953-961` |
| Destruction : `WhenAnotherRoomIsDestroyed` (L851), option `checkTriggers` | `GameBoard.cs:835-853` |
| Un héro devient actif : `ThisHeroEntersDungeon` | `GameBoard.cs:1062-1085` (L1078) |
| Première traversée d'une salle : `FirstTimeHeroEnterThisRoom` (L1132) | `GameBoard.cs:1123-1134` |
| Héro tué : `HeroDiesInThisRoom` (L1147) + `HeroDiesAnotherRoom` (L1148) | `GameBoard.cs:1143-1151` |
| Helpers génériques `CheckTriggerInDungeon` / `CheckTriggerInRoom` / `CheckHeroTrigger` : test `room.Ability.Trigger is T && CheckConditions(this)` puis `EnqueueAbilityTransaction` | `GameBoard.cs:1290-1315` |
| Habilité activée par le joueur : `Room.CanPlayerPlayAbility` (non passive, `Trigger == null`, pas déjà en attente, conditions OK) | `C#\DBMGameModel.Logic\Room.cs:49-57` |

**Résolution des cibles (choix joueur vs auto)** :

| Mécanique | Fichier:ligne |
|---|---|
| `BaseTargetProvider.NeedPlayerIteraction` (défaut `true`), `HasOnboardVisibleTargets`, `TargetsAmount`, `MinTargetsAmount`, `IsMultiTarget` | `Targets\BaseTargetProvider.cs:15-43` |
| Auto si `!NeedPlayerIteraction` **ou** `candidates <= TargetsAmount` (`SingleTargetProvider`) | `Targets\SingleTargetProvider.cs:16-40` |
| Auto (`ComposedTargetProvider`) : exactement 1 joueur et `<= TargetsAmount` | `Targets\ComposedTargetProvider.cs:35-56` ; variante par joueur L58-69 |
| Surlignage plateau : seuls les providers `NeedPlayerIteraction && TargetsAmount == 1` et **un seul** sont surlignés | `DBMGameProject.Scenes.GamePlay.SceneBehaviors\TargetResolverBaseSceneBehavior.cs:95-108` |
| `StartToResolveOnBoardTarget` : cibles visibles ⇒ surlignage ; provider composé à 1 joueur ⇒ sélection auto du joueur | `TargetResolverBaseSceneBehavior.cs:110-143` |
| `ResolveTarget` : `HasOnboardVisibleTargets` ⇒ callback direct (L192-195) ; `SingleTargetProvider` ⇒ carrousel de choix (L196-203) ; `ComposedTargetProvider` ⇒ `TryToAutoresolve` puis carrousel (L204-219) | `TargetResolverBaseSceneBehavior.cs:180-221` |
| Habilité « collection » ⇒ mode réarrangement du carrousel | `TargetResolverBaseSceneBehavior.cs:201` |
| Trigger : ignore la résolution interactive si `IsActivatedByUser` | `TriggerAbilitiesResolverSceneBehavior.cs:43-59` |
| Trigger : sélection tactile d'une carte sur le plateau | `TriggerAbilitiesResolverSceneBehavior.cs:20-41` |
| Activation d'une salle : surlignage puis `HumanPlayerInteraction.PlayRoomAbility` | `PlayRoomAbilitiesSceneBehavior.cs:43-71` |

---

### 2.4 Matrice — Triggers

| Mécanique | C# original (fichier:ligne) | JS (fichier:ligne) | Godot (fichier:ligne) | Statut |
|---|---|---|---|---|
| `WhenYouBuildThisRoom` (BMA011, BMA022, BMA033, BMA034, BMA036, BMA037) | `GameBoard.cs:950` / `Triggers\WhenYouBuildThisRoom.cs:3` | `roomAbilities.js:29` (`onBuildRoom`), appels `reducer.js:334`, `reducer.js:450`, `reducer.js:953` ; cas BMA022 `roomAbilities.js:34`, BMA011 `:56`, BMA036 `:68`, BMA037 `:85`, BMA034 `:346`, BMA033 `:367` | absent (`Match.gd:114-123` construit sans appel d'habilité) | aligné |
| `WhenYouBuildAnotherRoom` (BMA019 Beast Menagerie) | `GameBoard.cs:951` | `roomAbilities.js:388-402` (boucle `r !== room`, `usedThisTurn`) | absent | aligné |
| `HeroDiesInThisRoom` (BMA010, BMA012, BMA014, BMA016, BMA021) | `GameBoard.cs:1147` | `roomAbilities.js:409` (`onHeroDiedInRoom`), appel `reducer.js:718` ; cas `:415`, `:432`, `:442`, `:450`, `:455` | absent | aligné |
| `HeroDiesAnotherRoom` (0 carte dans les 4 decks APK) | `GameBoard.cs:1148` | — | absent | absent JS |
| `FirstTimeHeroEnterThisRoom` (BMA017 Minotaur's Maze) | `GameBoard.cs:1132` | `reducer.js:786-795` (`adv.mazeSentBack[i]` = « première fois ») | absent | aligné |
| `ThisHeroEntersDungeon` (KSA017 Trap Master) | `GameBoard.cs:1078` | `items.js:16-25` (`dungeonIgnoresRoomAbilities` évalue l'entrée dynamiquement) | absent | partiel |
| `AtTheBeginingOfYourTurn` (BMA023 Haunted Library) | `GameBoard.cs:388` | `reducer.js:344` (`beginPhaseBeginning`), BMA023 `reducer.js:383-403` + `roomAbilities.js:1072` | absent | partiel |
| `YouPlaySpellCard` (BMA026 Liger's Den) | `GameBoard.cs:796` | `reducer.js:657-673` (après résolution réelle du sort) | absent | aligné |
| `WhenOpponentPlaysSpellCard` (0 carte APK) | `GameBoard.cs:801` | `spellEffects.js:77-91` (TNL037 Hall of Mirrors, extension hors APK) | absent | absent JS |
| `AnySpellCardIsPlayed` (0 carte APK) | `GameBoard.cs:803` | `spellEffects.js:59-76` (RMB032, TNL034 — extensions hors APK) | absent | absent JS |
| `WhenAnotherRoomIsDestroyed` (BMA031 Recycling Center) | `GameBoard.cs:849-852` | `engine.js:415-425` (dans `destroyRoom`, `engine.js:373`) | absent | aligné |
| `WhenThisRoomIsDestroyed` (jamais référencée en C#, 0 carte) | `Triggers\WhenThisRoomIsDestroyed.cs:3` (aucun `CheckTriggerInRoom<>` correspondant) | — | absent | absent JS |
| `BaseTrigger` + test générique `Trigger is T && CheckConditions` | `GameBoard.cs:1301-1315` | — (pas de déclencheur générique) | absent | divergent |

---

### 2.5 Matrice — Conditions et LuredConditions

| Mécanique | C# original (fichier:ligne) | JS (fichier:ligne) | Godot (fichier:ligne) | Statut |
|---|---|---|---|---|
| `DuringPhase` (13 cartes : 8 `Adventure`, 5 `Build`) | `Conditions\DuringPhase.cs:5`, logique L15-21, parse L26 | pas de condition générique : portée par `cardData.js:48-51` (`canPlaySpell`) + `reducer.js:193` + gardes par carte `reducer.js:1445-1517` | absent | partiel |
| `OncePerTurn` (BMA010,012,013,014,016,019,021,024,025,026) | `Conditions\OncePerTurn.cs:3` (L12 `!IsEffectApplied`), reset `Boss.cs:244` ← `GameBoard.cs:444` | drapeau par salle `usedThisTurn`, reset `reducer.js:417`, gates `roomAbilities.js:392`, `roomAbilities.js:1888`, `reducer.js:1446` | absent | aligné |
| `HasPendingRoomToBuild` (BMA019) | `Conditions\HasPendingRoomToBuild.cs:6` | `roomAbilities.js:388-402` (« autre salle construite » sans notion de build en attente) | absent | partiel |
| `OpponnentDungeonSizeMoreThan` (BMA050 Motivation) | `Conditions\OpponnentDungeonSizeMoreThan.cs:5` | `spellEffects.js:163-170` | absent | aligné |
| `HeroHasAtachedItem` (0 carte APK) | `Conditions\HeroHasAtachedItem.cs:5` | — | absent | absent JS |
| `OpponnentHasMoreThanInHand` (0 carte APK) | `Conditions\OpponnentHasMoreThanInHand.cs:6` | — | absent | absent JS |
| `OwnerHasFewerThanOpponent` (0 carte APK) | `Conditions\OwnerHasFewerThanOpponent.cs:6` | — | absent | absent JS |
| `LuredByTreasures` (82 héros) | `LuredConditions\LuredByTreasures.cs:8` (L21-39) | `engine.js:109-209` + `resolveBait` `engine.js:211-266` | `BossEngine.gd:58-75` (`lure_target`) | partiel |
| `LuredByFewerSouls` (BMA080/BMH080 The Fool) | `LuredConditions\LuredByFewerSouls.cs:6` (min, L18-22) | `engine.js:225-243` (min `totalSouls`, égalité ⇒ ville L237-241) | absent | aligné |
| `LuredByWounds` (KSA014 Demigod) | `LuredConditions\LuredByWounds.cs:6` (min, L18-22) | `engine.js:228-241` (`useWounds`) | absent | aligné |
| `LuredBySouls` (max ; 0 carte APK) | `LuredConditions\LuredBySouls.cs:6` | `engine.js:188-209` (« no wounds/souls tie-break for standard heroes ») | absent | absent JS |
| `LuredByCardsInHand` (0 carte APK) | `LuredConditions\LuredByCardsInHand.cs:6` | — | absent | absent JS |

---

### 2.6 Matrice — Commands (47 classes)

Références JS : `SE` = `spellEffects.js`, `RA` = `roomAbilities.js`, `EN` = `engine.js`,
`RED` = `reducer.js`, `IT` = `items.js`.

| Mécanique (cartes APK) | C# original (fichier:ligne) | JS (fichier:ligne) | Godot (fichier:ligne) | Statut |
|---|---|---|---|---|
| `AddSoulsToBoss` (KSA006) | `Commands\AddSoulsToBoss.cs:5` | `RA:1008` | absent | aligné |
| `AddSoulsToBossIfTreasures` (KSA013) | `Commands\AddSoulsToBossIfTreasures.cs:9` | `SE:430` | absent | aligné |
| `AddTreasuresToDungeon` (KSA001) | `Commands\AddTreasuresToDungeon.cs:8` | `RA:961` | absent | aligné |
| `BuildExtraRoom` (BMA050) | `Commands\BuildExtraRoom.cs:3` | `SE:164-177` (`extraBuild`), `SE:1160` (`extraBuildsFor`), `RED:204` | absent | aligné |
| `BuildRoomBy` (BMA003, BMA007) | `Commands\BuildRoomBy.cs:5` | `RA:897` (level-up, « may immediately build ») | absent | partiel |
| `CancelSpellAbility` (BMA043, BMA025) | `Commands\CancelSpellAbility.cs:5` | `RED:1003-1017` (BMA043), `RA:2038` (BMA025) | absent | partiel |
| `CannotBuildRoom` (BMA018) | `Commands\CannotBuildRoom.cs:5` + `IBuildRestrictionCommand.cs:3` | `EN:301-316` (`canBuildRoom` / `fetidBlocksMonsterBuild`) | absent | aligné |
| `ChooseAndDestroyRoom` (BMA004) | `Commands\ChooseAndDestroyRoom.cs:8` | `RA:899`, choix `RA:775-787` | absent | aligné |
| `ChooseCardToDraw` (BMA023) | `Commands\ChooseCardToDraw.cs:3` | `RED:383-403` + `RA:1072` | absent | aligné |
| `DeactivateDungeonAbility` (KSA017) | `Commands\DeactivateDungeonAbility.cs:7` (`IUndoableCommand`, `Execute`/`Undo` verrouillent `Ability.IsLocked`) | `IT:16-25` (évaluation dynamique, pas d'undo) | absent | partiel |
| `DeactivateRoom` (BMA046) | `Commands\DeactivateRoom.cs:5` | `SE:227-238` (`G.effects.deactivatedRooms`, `SE:19`) | absent | aligné |
| `DealDamageToDungeon` (BMA032) | `Commands\DealDamageToDungeon.cs:3` | `RA:1945-1955` (The Crushinator), liste `RED:1379-1424` | absent | partiel |
| `DealDamageToRoom` (BMA015, BMA029, BMA040, BMA047) | `Commands\DealDamageToRoom.cs:5` (`IPassiveDamageCommand`) | `EN:570-672` (`roomDamageWithModifiers`), cas `EN:609-610` | absent | partiel |
| `DealHero` (BMA028, BMA041, BMA055) | `Commands\DealHero.cs:3` | `SE:125` (BMA041), `RA:1924` (BMA028), `SE:389` (BMA055) ; consommation `RED:802-810` | absent | aligné |
| `DealRoomsCountToHero` (BMA044) | `Commands\DealRoomsCountToHero.cs:7` | `SE:208-222` | absent | aligné |
| `DestroyRoom` (BMA009, BMA027, BMA028, BMA030, BMA032, BMA042) | `Commands\DestroyRoom.cs:5` | `EN:373-425` | absent | aligné |
| `DiscardAllHand` (BMA048) | `Commands\DiscardAllHand.cs:6` | `SE:240-255` | absent | aligné |
| `DiscardRandomCardFromHand` (BMA011, BMA038) | `Commands\DiscardRandomCardFromHand.cs:7` | `RA:56-66` (BMA011) ; helper `RA:594-602` | absent | aligné |
| `DiscardSomeCardFromHand` (BMA005, BMA022) | `Commands\DiscardSomeCardFromHand.cs:8` | `RA:34-54` (choix `discard-spell`), `RA:908-925` (BMA005) | absent | aligné |
| `DiscardTargetRoomFromHand` (BMA013, BMA024) | `Commands\DiscardTargetRoomFromHand.cs:3` | `RA:2018-2036` | absent | aligné |
| `DiscardTargetSpellFromHand` (BMA025) | `Commands\DiscardTargetSpellFromHand.cs:3` | `RA:2038-2066` | absent | aligné |
| `DrawCards` (BMA005, BMA016, BMA019, BMA021, BMA048, BMA052) | `Commands\DrawCards.cs:6` | `cardData.js:194` (`drawCards`), usages `RA:35`, `RA:144`, `SE:576` | absent | aligné |
| `ExtraBuildTurn` (BMA034) | `Commands\ExtraBuildTurn.cs:3` | `RA:346-354` | absent | aligné |
| `FlipHero` (BMA014) | `Commands\FlipHero.cs:3` | `RA:450-453` + `EN:765-772` (`healOneWound`) | absent | aligné |
| `HeroResistDamageRoomType` (KSA016) | `Commands\HeroResistDamageRoomType.cs:7` (`IPassiveDamageCommand`) | `EN:570-607` (`roomDamageWithModifiers`, piège `monster`) | absent | partiel |
| `KillHero` (BMA027) | `Commands\KillHero.cs:5` | `RA:1916-1923` + `items.js:171` (`killHeroInDungeon`, importé `RA:14`) | absent | aligné |

| Mécanique (cartes APK) | C# original (fichier:ligne) | JS (fichier:ligne) | Godot (fichier:ligne) | Statut |
|---|---|---|---|---|
| `KillHeroInRoom` (BMA042) | `Commands\KillHeroInRoom.cs:6` | `SE:179-194` | absent | partiel |
| `LastRoomDealDamage` (KSA005) | `Commands\LastRoomDealDamage.cs:6` (`IPassiveDamageCommand`) | `RA:1003-1006`, calcul `EN:657` | absent | partiel |
| `MoveHeroToRelativeSlot` (BMA017, BMA053) | `Commands\MoveHeroToRelativeSlot.cs:5` | `RED:786-795` (BMA017), `SE:365-380` (BMA053) | absent | aligné |
| `MultiplyTreasuresDungeon` (BMA030, KSA007) | `Commands\MultiplyTreasuresDungeon.cs:3` (`IPassiveTreasureCommand`, `IUntilEndOfGameCommand`) | `EN:85-91` (`treasureDoubled`), `RA:1937-1955`, `RA:1013` | absent | partiel |
| `PickRandomCardFromHand` (BMA012) | `Commands\PickRandomCardFromHand.cs:7` | `RA:455-468` | absent | aligné |
| `PlaceAtDungeonEntrance` (BMA006, BMA036, BMA051) | `Commands\PlaceAtDungeonEntrance.cs:5` | `RA:72` (BMA036), `RA:927-955` (BMA006), `SE:336-348` (BMA051) | absent | aligné |
| `PlaceAtScorekeep` (BMA008, KSA004) | `Commands\PlaceAtScorekeep.cs:5` | `RA:944-959` (BMA008), `RA:981-1001` (KSA004) | absent | partiel |
| `PlaceAtTown` (BMA045) | `Commands\PlaceAtTown.cs:3` | `SE:302-320` | absent | aligné |
| `PutCardInHand` (BMA001,002,003,007,009,010…) | `Commands\PutCardInHand.cs:3` | `RA:36`, `RA:96`, `RA:145`, `RA:418` | absent | aligné |
| `RearrangeDungeon` (KSA002) | `Commands\RearrangeDungeon.cs:7` | `RA:967-969` + `RA:1107-1121` (`makeRearrangeChoice`) | absent | aligné |
| `RemoveHeroFromTheGame` (BMA052) | `Commands\RemoveHeroFromTheGame.cs:5` | `SE:350-363` | absent | aligné |
| `RoomDamageEqualToCount` (BMA020) | `Commands\RoomDamageEqualToCount.cs:8` (`IPassiveDamageCommand`) | `EN:578-586` | absent | aligné |
| `SendBackToDungeonEntrance` (BMA039, BMA055) | `Commands\SendBackToDungeonEntrance.cs:5` | `RA:1977-2000` (BMA039), `SE:389-400` (BMA055) | absent | aligné |
| `SkipAdventurePhase` (BMA054) | `Commands\SkipAdventurePhase.cs:5` | `SE:282-299` (`G.effects.noEntry`) | absent | partiel |
| `SkipBuildPhase` (BMA049) | `Commands\SkipBuildPhase.cs:5` | `SE:258-281` + `SE:1106-1107` (`noRoomBuild`, `SE:33`), gate `RED:203` | absent | partiel |
| `SwapSlotInDungeon` (BMA033) | `Commands\SwapSlotInDungeon.cs:3` | `RA:367-381` (choix `swap-rooms`) + `RA:1271-1282` | absent | aligné |
| `UndoBuildRoom` (BMA049) | `Commands\UndoBuildRoom.cs:5` | `SE:258-281` | absent | aligné |
| `ChooseCardFromHand` (0 carte APK) | `Commands\ChooseCardFromHand.cs:5` | — | absent | absent JS |
| `FlipItem` (0 carte APK) | `Commands\FlipItem.cs:5` | `RA:1516-1543` (flip d'objet, contexte boss) | absent | partiel |
| `PlaceAtOwnerDungeonEntrance` (0 carte APK) | `Commands\PlaceAtOwnerDungeonEntrance.cs:5` | — | absent | absent JS |
| `SkipBeginingOfTurn` (0 carte APK) | `Commands\SkipBeginingOfTurn.cs:5` | — | absent | absent JS |
| Interfaces passives (`IPassiveDamageCommand`, `IPassiveScorekeepCommand`, `IPassiveTreasureCommand`) | `Commands.Interfaces\*.cs:3`, agrégation `Ability.cs:191-245` | `EN:570` (dégâts), `EN:51-101` (trésors), pas de « scorekeep » générique | absent | partiel |
| `IUntilEndOfGameCommand` (sorts permanents) | `IUntilEndOfGameCommand.cs:3`, usage `GameBoard.cs:791-795` | `SE:14-37` (`emptyEffects`, listes jusqu'à fin de tour) | absent | partiel |
| `IUndoableCommand` (undo) | `IUndoableCommand.cs:3`, usage `Ability.cs:138-149`, `GameBoard.cs:697-700` | mécanique d'annulation absente (cas particulier `SE:257`) | absent | partiel |
| `IBuildRestrictionCommand` | `IBuildRestrictionCommand.cs:3`, agrégation `Ability.cs:169-178` | `EN:268-322` (`canBuildRoom`) | absent | partiel |

---

### 2.7 Matrice — Targets

| Mécanique | C# original (fichier:ligne) | JS (fichier:ligne) | Godot (fichier:ligne) | Statut |
|---|---|---|---|---|
| Base + auto-résolution | `Targets\BaseTargetProvider.cs:15-43`, `SingleTargetProvider.cs:16-40`, `ComposedTargetProvider.cs:35-69` | `reducer.js:190-199` (une move par cible), `spellTargeting.js:54` | absent | divergent |
| Table des cibles de sorts (37 entrées) | `Targets\*.cs` | `spellTargeting.js:4-43` (`SPELL_TARGETS`), `spellNeedsTarget` `:45`, `spellTargetsFor` `:509` | absent | partiel |
| `BossOwner` (auto-caster) | `Targets\BossOwner.cs:5` | `SE:431` (`G.players[casterId]`) | absent | aligné |
| `ThisRoom` | `Targets\ThisRoom.cs:6` | `RED:1582-1596` (`pushActivateMoves`, index de la salle) | absent | aligné |
| `HeroInThisRoom` | `Targets\HeroInThisRoom.cs:6` | `RED:1440-1443` (`heroIsInRoom`) | absent | aligné |
| `RoomInDungeon` | `Targets\RoomInDungeon.cs:7` | `RA:1122-1132` (`listDungeonRoomOptions`) | absent | aligné |
| `RoomInHand` | `Targets\RoomInHand.cs:7` | `RA:799-802` (`handRoomOptions`) | absent | aligné |
| `SpellInHand` | `Targets\SpellInHand.cs:6` | `RA:127-131` | absent | aligné |
| `HeroInTown` | `Targets\HeroInTown.cs:7` | `spellTargeting.js:12` (`hero-town`), `RA:720-726` | absent | aligné |
| `HeroInDungeon` | `Targets\HeroInDungeon.cs:7` | `spellTargeting.js:6,9` (`hero-own/opponent/any-dungeon`) | absent | aligné |
| `HeroInScorekeep` (âmes/blessures) | `Targets\HeroInScorekeep.cs:7` | `spellTargeting.js:13,16` (`own-soul`, `opponent-soul`) | absent | aligné |
| `BossOpponentWithAtLeastScore` (BMA054) | `Targets\BossOpponentWithAtLeastScore.cs:6` | `spellTargeting.js:15` (`trepidation-player`), `spellTargeting.js:431-444`, `:204-212` | absent | aligné |
| `LastSpellPlayed` / `SpellCardJustPlayed` | `Targets\LastSpellPlayed.cs:6`, `SpellCardJustPlayed.cs:6` | `stack.js:24-26` (`topEffect`), `RED:1100` | absent | aligné |
| `BossOpponent` / `BossOpponents` | `Targets\BossOpponent.cs:5`, `BossOpponents.cs:5` | `RA:550-555` (`opponentsWith`), `RA:899-906` | absent | partiel |
| `BossDungeon` (choix de donjon adverse) | `Targets\BossDungeon.cs:3` | `RA:967-969` (Hellcow : « any dungeon ») | absent | partiel |
| `CardInDeck` (défausse/pioche) | `Targets\CardInDeck.cs:7` | `RA:1031-1046` (`discardCardOptions`) | absent | partiel |
| `CardInHand` | `Targets\CardInHand.cs:7` | `RA:870` (création), `RA:1223` (résolution `steal-card`) | absent | partiel |
| `RoomInDeck` | `Targets\RoomInDeck.cs:7` | `RA:1031-1046`, `RA:1429-1449` (`search-advanced`) | absent | partiel |
| `SpellInDeck` (KSA003) | `Targets\SpellInDeck.cs:7` | `RA:970-979` | absent | partiel |
| `HeroInDeck` (BMA006) | `Targets\HeroInDeck.cs:6` | `RA:927-955` (Seducia : town + hero decks) | absent | partiel |
| `ActiveHeroInDungeon` (héro en cours) | `Targets\ActiveHeroInDungeon.cs:7` | `RED:1440-1443` + `G.adventure.hero` | absent | partiel |
| `HeroUnassigned` (BMA006) | `Targets\HeroUnassigned.cs:7` | `RA:720-726` (`seduciaHeroOptions`), `RA:803-818` | absent | partiel |
| `ItemInTown` | `Targets\ItemInTown.cs:6` | `RA:2070-2077` (objets en ville) | absent | partiel |
| `AllBoss` (BMA048, BMA049) | `Targets\AllBoss.cs:5` | `SE:240-255`, `SE:258-281` (boucle sur tous) | absent | partiel |
| `AnotherRoom` (salle « autre ») | `Targets\AnotherRoom.cs:5` | `RED:1431` (`NEEDS_OTHER_TARGET_ROOMS`), `RED:1586-1591` | absent | partiel |
| `AdjacentsRoom` (BMA015) | `Targets\AdjacentsRoom.cs:6` | `EN:609` (calcul inline, pas de provider) | absent | absent JS |
| `NextRoom` (BMA029) | `Targets\NextRoom.cs:6` | `EN:610` (calcul inline) | absent | absent JS |
| `BossOpponentWithAtLeastHand` (0 carte APK) | `Targets\BossOpponentWithAtLeastHand.cs:6` | — | absent | absent JS |
| `CrossingHeroAtachedItem` (0 carte APK) | `Targets\CrossingHeroAtachedItem.cs:6` | — | absent | absent JS |
| `ItemInScorekeep` (0 carte APK) | `Targets\ItemInScorekeep.cs:6` | — | absent | absent JS |
| Carrousel « collection » (multi-sélection) | `TargetResolverBaseSceneBehavior.cs:201`, `Effect.cs:133-165` | `RA:893`, `RA:1419`, `RA:2011` (`remaining` dans `pendingChoice`) | absent | partiel |
| Cible optionnelle (`CanAvoid`) | `Ability.cs:17`, `AbilityTransaction.cs:205` | `RED:1616` (`pendingChoice.optional`) | absent | partiel |

---

### 2.8 Couverture Godot (`BossEngine.gd`, `Match.gd`)

| Mécanique | C# original | JS | Godot (fichier:ligne) | Statut |
|---|---|---|---|---|
| Fabrique d'habilités / données déclaratives | `AbilityFactory.cs:14` | `roomAbilities.js:33` (switch) | — | absent Godot |
| Pile de sorts / transactions | `GameBoard.cs:306-315`, `GameBoard.cs:44` | `stack.js:8-48` | — | absent Godot |
| Triggers (12 classes) | `GameBoard.cs:1290-1315` | 8/12 portés | — | absent Godot |
| Conditions (7 classes) | `Conditions\*.cs` | 4/7 portées (inline) | — | absent Godot |
| Commands (47 classes) | `Commands\*.cs` | 43/47 portées (inline) | — | absent Godot |
| Targets (31 classes) | `Targets\*.cs` | `spellTargeting.js:4-43` | — | absent Godot |
| Lure / `LuredCondition` | `LuredConditions\*.cs` | `engine.js:211-266` | `BossEngine.gd:58-75` (`lure_target`) | partiel |
| Comptages de trésors (base de `LuredByTreasures`) | `LuredByTreasures.cs:21-39` | `engine.js:51-101` | `BossEngine.gd:24-51` | partiel |
| Déclaration explicite du trou | — | — | `Match.gd:5` (commentaire : « effets de sorts salles avancés non portés ») | absent Godot |
| Mains / construction sans habilité | `GameBoard.cs:950` | `reducer.js:953` | `Match.gd:114-123` (pose de salle sans `onBuildRoom`) | absent Godot |
| Combat sans habilités de salle | `GameBoard.cs:1139-1147` | `reducer.js:796-810` | `Match.gd:234-254` (dégâts bruts `damage`) | absent Godot |
| Coups légaux : aucun `playSpell` / `activateRoom` | `Room.cs:49-57` | `reducer.js:1663-1680` | `Match.gd:60-89` (uniquement `pickBoss`, `buildInitialRoom`, `buildRoom`, `passBuild`, `adventureNext`) | absent Godot |
| Chargement des données | `AbilityInfo.cs:3-12` | `cardData.js` | `CardDB.gd:33-45` (`res://godot/data/cards.json`) | partiel |

`Godot\BossEngine.gd:1-81` ne contient que des fonctions pures (`active_room`, `all_active_rooms`,
`count_visible_rooms`, `dungeon_treasures`, `treasure_count(s)`, `can_build_room`, `lure_target`,
`hero_souls/wounds`) : **aucune** notion de trigger, condition, commande ou cible.

---

### 2.9 Données et cohérence des identifiants

| Point | Référence vérifiée |
|---|---|
| Source C# des habilités : JSON `AbilityInfo` imbriqué dans chaque carte | `APK\BaseDeck\data.json` (`BossCards[].LevelUpAbility`, `RoomCards[].Ability`…), schéma `C#\DBMGameModel.Info\AbilityInfo.cs:3-12` |
| 4 decks seulement dans l'APK extrait | `APK\BaseDeck\data.json` (93 488 o), `APK\HiddenHeros\data.json` (21 755 o), `APK\PlayerChoice\data.json` (12 256 o), `APK\ToolsHeroKind\data.json` (11 857 o) |
| JS : les habilités ne sont **pas** dans les données, mais en dur | `roomAbilities.js:33` (`switch (room.id)`), `spellEffects.js:44` (`SPELL_EFFECTS[card.id]`), `reducer.js:1379-1424` (liste `ACTIVATED_ABILITY_ROOMS`) |
| Champs de cartes côté JS | `cardData.json` (`bosses[].levelUpDesc`, `rooms[].id/name/damage/treasures`) — **aucune** structure `Trigger`/`Conditions`/`Effects` |
| Godot : copie byte-identique du JS | `godot\data\cards.json` MD5 `8A4AE93C5DC76E7027A81B1E4E9A5218` = `src\backend\game\cardData.json` ; chargé par `Godot\CardDB.gd:33-45` |
| Carte de correspondance externe | `godot\data\card_matrix.json` (`cards.<ID>.text/status/tags`) |
| Comptage : APK = 173 ids, JS = 442 ids, **0 id APK absent du JS** | calcul sur les 4 `data.json` vs `cardData.json` |
| 269 ids JS sans source APK (extensions : `CRL` 33 + `RMB` 121 + `TNL` 115) : source = wiki, pas l'APK | `tools/fetch_expansion_packs.py` (« List_of_Cards »), `tools/merge_expansions.py` (« TNL / RMB / CRL ») |
| Correspondance image/apk | `src\backend\game\apkCardManifest.json`, `nameMap` dans `cardData.json` |

**Triggers réellement utilisés par le JSON APK (8/12)** : `WhenYouBuildThisRoom` (6),
`HeroDiesInThisRoom` (5), `AtTheBeginingOfYourTurn` (1), `FirstTimeHeroEnterThisRoom` (1),
`WhenYouBuildAnotherRoom` (1), `ThisHeroEntersDungeon` (1), `WhenAnotherRoomIsDestroyed` (1),
`YouPlaySpellCard` (1).
**Conditions utilisées (4/7)** : `DuringPhase` (13), `OncePerTurn` (10), `HasPendingRoomToBuild` (1),
`OpponnentDungeonSizeMoreThan` (1).
**Commandes utilisées (43/47)**, **cibles utilisées (26/31)**, **LuredConditions utilisées (3/5)**.

**Compléments vérifiés le 2026-10-10** : les 4 `data.json` utilisent **80 `TypeName` distincts**
(Triggers/Conditions/Effects/Targets/Commands confondus) — le schéma piloté par données est complet
pour les 173 cartes APK. Les decks Base/Hidden/PlayerChoice embarquent en plus un `ai_info.json`
(`SpellCards[]`/`RoomCards[]` avec champ `Affects: Player|Enemy|All`) qui alimente
`AbilityCalculator`/`TriggerCalculator` — voir §3.2.4-3.2.5.

---

### Capacités absentes du port

**A. Côté JS — classes C# sans équivalent fonctionnel**

1. `Triggers\WhenThisRoomIsDestroyed` (`WhenThisRoomIsDestroyed.cs:3`) — jamais invoquée même en C#
   (aucun `CheckTriggerInRoom<WhenThisRoomIsDestroyed>`), 0 carte concernée, rien côté JS.
2. `Triggers\HeroDiesAnotherRoom` (`HeroDiesAnotherRoom.cs:3`, appel `GameBoard.cs:1148`) — le JS
   n'a que `onHeroDiedInRoom` pour la salle concernée (`roomAbilities.js:409`), sans boucle sur les
   *autres* salles du donjon. 0 carte APK.
3. `Triggers\WhenOpponentPlaysSpellCard` / `AnySpellCardIsPlayed` (`GameBoard.cs:801`, `:803`) —
   n'existent en JS que pour 3 salles d'extension codées en dur (`spellEffects.js:59-91`), sans
   généralisation ; 0 carte APK.
4. `Conditions\HeroHasAtachedItem` (`HeroHasAtachedItem.cs:5`),
   `Conditions\OpponnentHasMoreThanInHand` (`OpponnentHasMoreThanInHand.cs:6`),
   `Conditions\OwnerHasFewerThanOpponent` (`OwnerHasFewerThanOpponent.cs:6`) — aucune contrepartie
   JS, 0 carte APK.
5. `LuredConditions\LuredBySouls` (`LuredBySouls.cs:6`) et `LuredConditions\LuredByCardsInHand`
   (`LuredByCardsInHand.cs:6`) — `engine.js:188-209` exclut explicitement les départages par
   âmes/blessures pour les héros standards ; 0 carte APK.
6. `Commands\ChooseCardFromHand` (`ChooseCardFromHand.cs:5`),
   `Commands\PlaceAtOwnerDungeonEntrance` (`PlaceAtOwnerDungeonEntrance.cs:5`),
   `Commands\SkipBeginingOfTurn` (`SkipBeginingOfTurn.cs:5`) — aucune occurrence JS, 0 carte APK.
7. `Targets\BossOpponentWithAtLeastHand` (`BossOpponentWithAtLeastHand.cs:6`),
   `Targets\CrossingHeroAtachedItem` (`CrossingHeroAtachedItem.cs:6`),
   `Targets\ItemInScorekeep` (`ItemInScorekeep.cs:6`) — aucun filtre JS équivalent, 0 carte APK.
8. **Fabrique déclarative entière** : `AbilityFactory.cs:14-134` + `AbilityInfo` + `EffectInfo` n'ont
   aucune contrepartie. Le JS ne peut pas instancier une habilité depuis `cardData.json` : il faut
   écrire une fonction par carte. Cartes **déjà présentes** dans le port mais pilotées par des gardes
   en dur et non par les données : `AdjacentsRoom`/`NextRoom` (calculs inline `engine.js:609-610`),
   `IBuildRestrictionCommand` (`engine.js:268-322`), `IUntilEndOfGameCommand` (`spellEffects.js:14-37`),
   `IUndoableCommand` (`DeactivateDungeonAbility.cs:7` remplacé par la vérification dynamique
   `items.js:16-25`).
9. **Annulation (undo) d'habilité** : `Ability.UndoEffect` (`Ability.cs:138-149`) +
   `GameBoard.cs:697-700` (le piège de Trap Master se retire quand le héro quitte la partie) n'ont
   pas d'équivalent structurel en JS.

**B. Côté Godot — tout le sous-système**

- Aucun trigger, aucune condition, aucune commande, aucune cible : `Match.gd:60-89` n'offre que 5
  types de coups, `Match.gd:114-123` construit sans `onBuildRoom`, `Match.gd:234-254` combat sans
  dégâts modifiés, `Match.gd:5` documente le trou. Seul `BossEngine.gd:24-75` (trésors, lure)
  recoupe partiellement `LuredByTreasures`.

**C. Absents des deux ports**

- Les 269 ids `CRL*`/`RMB*`/`TNL*` présents dans `cardData.json` n'ont aucune source C# dans
  l'APK extrait (4 decks) : toute habilité de ces cartes est **non vérifiable** contre l'original
  (statut `non vérifié`).

---

### Divergences confirmées

1. **Fenêtre de réponse au sort — `divergent`.**
   C# : dès qu'une habilité activée par un joueur s'applique, *tous* les joueurs sont mis en attente
   de réponse (`GameBoard.cs:754-762`, `PendingSpellBattlePlayers`), et n'importe quel sort peut
   s'empiler ; l'ordre vient de `PendingAbilityTransactions` (`GameBoard.cs:1317-1333`), le
   contre-sort étant inséré juste avant sa cible (`GameBoard.cs:763-769`).
   JS : pendant qu'un effet est sur la pile, seul le joueur actif peut répondre, et seuls
   `BMA043`/`RMB077` (plus Timebender et TNL031) sont jouables (`reducer.js:1623-1642`,
   `cardData.js:47-51`) ; la pile est une LIFO maison (`stack.js:12-43`).
   Résultat : pas de chaîne de sorts en réponse dans le port.

2. **Représentation des habilités : données vs code — `divergent`.**
   Le C# lit `TypeName`/`Parameters` depuis `APK\*\data.json` et résout les classes par réflexion
   (`AbilityFactory.cs:124-134`). Le JS n'a aucune structure équivalente dans `cardData.json` :
   tout est `switch` sur l'id (`roomAbilities.js:33`, `spellEffects.js:44`) ou liste codée en dur
   (`reducer.js:1379-1424`, `spellTargeting.js:4-43`). Toute nouvelle carte exige du code, et
   `CreateTrigger` ignore de toute façon ses paramètres (`AbilityFactory.cs:119-122`).

3. **Portée de la condition `DuringPhase` — `partiel`.**
   C# : `DuringPhase` ne reconnaît que `Build` et « sinon Adventure » (`DuringPhase.cs:15-21`),
   ce qui colle aux 13 usages du JSON (5 `Build`, 8 `Adventure`). JS : pas de condition équivalente,
   mais des gardes spécifiques par carte dans `canOfferActivatedRoom` (`reducer.js:1445-1517`) et
   `canPlaySpell` (`cardData.js:48-51`). Résultat globalement le même mais non dérivé des mêmes
   données — divergence de modèle, risque de désynchronisation texte/données.

4. **Activation unique par tour : mécanisme divergent — `divergent`.**
   C# : `OncePerTurn` teste `!ability.IsEffectApplied` (`OncePerTurn.cs:12`), remis à `false` une
   fois par tour via `Boss.RestoreDungeon` (`Boss.cs:244`, appelé `GameBoard.cs:441-447`) ; le
   drapeau `Room.IsAbilityUsed` (`Room.cs:12`) n'est **jamais écrit** dans le décompilé, donc les
   habilités activées *sans* `OncePerTurn` ne sont pas verrouillées par le code.
   JS : `room.usedThisTurn` est posé pour **toute** activation (`reducer.js:1446`,
   `roomAbilities.js:1888`) et réinitialisé en `reducer.js:417`. Le port est plus strict que
   l'original sur ce point.

5. **Résolution des cibles : auto vs choix — `divergent`.**
   C# a deux canaux explicites — auto si `!NeedPlayerIteraction` ou si le nombre de candidats
   `<= TargetsAmount` (`SingleTargetProvider.cs:16-40`, `ComposedTargetProvider.cs:35-69`), sinon
   carrousel de choix + surlignage plateau (`TargetResolverBaseSceneBehavior.cs:95-143`, `:180-221`).
   Le JS énumère chaque cible valide comme un coup distinct (`reducer.js:190-199`,
   `spellTargeting.js:54`) : ni `NeedPlayerIteraction`, ni surlignage « cibles visibles sur le
   plateau », ni annulation `CanAvoid` au sens C# (`AbilityTransaction.cs:205`) — seulement
   `pendingChoice.optional` (`reducer.js:1616`).

6. **Couverture de contenu — `non vérifié`.**
   173 ids APK contre 442 dans `cardData.json` (269 ids d'extensions sans décompilation de
   référence) : les habilités `CRL*`/`RMB*`/`TNL*` ne peuvent pas être confrontées à l'original.
   Godot ne couvre que le set de base et sans habilité (`Match.gd:21-23`, `Match.gd:5`).

**Périmètre** : cerveau de l'IA adverse du jeu original (APK C#/Xamarin décompilé) et ses fonctions de score, comparé aux réimplémentations JS (`src/backend/game/`) et Godot 4 (`godot/scripts/`).

**Conventions de chemins** :
- `C#` = relatif à `apk-original/decompiled/DBMGame/` (ex. `AI\FixedAI.cs:12` = `DBMGameProject.AI\FixedAI.cs:12`).
- `JS` = relatif à `src/backend/game/` sauf mention contraire (`src/backend/server/matches.js`).
- `Godot` = relatif à `godot/scripts/`.

---

## 3.1 Architecture IA du C# (`DBMGameProject.AI`)

L'IA est une injection de cerveau (`AIBrain`) dans un adaptateur d'interaction joueur. Trois cerveaux coexistent :

| Brain | Rôle | Référence |
|---|---|---|
| `AIBrain` (interface, 7 méthodes) | pioche / défausse / salle à bâtir / position / ability / cibles trigger / cibles commande | `AI\AIBrain.cs:7-22` |
| **`FixedAI`** | **cerveau réel du jeu** : argmax déterministe pour salle + position ; délègue le reste à `StatisticAI` | `AI\FixedAI.cs:10-72`, backup `AI\FixedAI.cs:12` |
| `StatisticAI` | backup/debug : mêmes scores mais **sélection aléatoire pondérée** (`RandomSelection`), backup `RandomAI` | `AI\StatisticAI.cs:12-14`, `100-143` |
| `RandomAI` | chaos : pioche pile-ou-face, salle au hasard, ability avec 10 % de chance | `AI\RandomAI.cs:14-57` |
| `NullAI` | passif (toujours RoomDeck, prend les `amount` premières cartes, jamais de salle ni d'ability) — **jamais instancié** dans le code décompilé | `AI\NullAI.cs:9-47` |

**Sélection** : tous les joueurs IA reçoivent `new FixedAI()` — tutoriel (`GameBoardExtensions.cs:49`), partie locale (`:129`), mode solo en ligne (`:70`), clonage de board pour IA-vs-IA/simulation (`:241`, `:298`). Le mode auto-play d'un humain (`HumanPlayerInteraction.AutoPlayMode`) utilise `RandomAI` (`Services.PlayerInteraction\HumanPlayerInteraction.cs:16,39`).

**Quand l'IA joue** (`AIPlayerInteraction`) : les actions sont déclenchées par phase de jeu dans `InternalDoPlayerActions` (`Services.PlayerInteraction\AIPlayerInteraction.cs:76-123`) :
- `Setup_b` → construire une salle (`:83-85`) ;
- `BuildPhase_a` → activer une ability puis construire si joueur actif (`:86-104`) ;
- `AdventurePhase_b` / `AdventurePhase_c` → activer abilities (`:105-110`) ;
- `ExtraBuildPhase` → construire si joueur actif (`:111-116`) ;
- bataille de sorts : `AbilityApplyRequest` (`:29-43`) ;
- résolution de cibles : `InternalResolveTarget` → cible pré-sélectionnée par l'ability, sinon `Brain.SelectTriggerTargets` / `SelectCommandTargets` (`:45-74`) ;
- pioche : `InternalChooseCardTypeToDrawFrom` (`:125-139`) ; défausse : `InternalDiscardCardsInHand` (`:141-148`).

**Délai humain simulé** : `SimulateHumanDelays` impose un timer de `1 + Random.NextDouble()*3` secondes par callback (`AIPlayerInteraction.cs:224-239`), activé uniquement en mode test en ligne (`GameBoardExtensions.cs:70-73`).

### Matrice A — architecture & déclenchement

| Décision/règle | C# original (fichier:ligne) | JS (…:ligne) | Godot (…:ligne) | Statut |
|---|---|---|---|---|
| Brain injectée = `FixedAI` (chaîne Fixed→StatisticAI→RandomAI) | `AI\FixedAI.cs:12`, `GameBoardExtensions.cs:129` | bot = moteur unique `aiPickMove` (`src/backend/server/matches.js:62`) | `AI.pick_move` statique (`Board.gd:74`, `BoardUI.gd:63`) | divergent — JS/Godot n'ont pas de couche de backup ni de chaîne de brains |
| IA joue en Setup_b / BuildPhase_a / Adventure_b/c / ExtraBuild | `AIPlayerInteraction.cs:81-117` | tick serveur 350 ms quand `isAI` (`matches.js:60-74`) | `_process` 0,5–0,6 s, seulement phases `boss`/`build` (`Board.gd:70-76`, `BoardUI.gd:59-63`) | partiel — Godot ne joue ni aventure ni bataille de sorts |
| Délai « humain » aléatoire 1–4 s | `AIPlayerInteraction.cs:226-234` | fixe 350 ms (`matches.js:66-74`) | 0,5/0,6 s fixes (`BoardUI.gd:61`, `Board.gd:72`) | divergent — pas de jitter côté JS/Godot |
| Construction : boucle jusqu'à `MaxBuildRoomLimit`, s'arrête si `SelectRoomToBuild` = null | `AIPlayerInteraction.cs:165-186` | un seul build puis fin de build (`reducer.js:1537-1561`) | `Match.gd:176-179` (`_ai_build` forcé) | partiel |
| Prise de boss : pré-sélection par XP dans le setup (pas de « pick » pour l'IA) | `GameBoardExtensions.cs:38-47` (boss fixes tutoriel) | auto-pick XP max (`reducer.js:292-303`, timeout `matches.js:104-123`) | `AI.choose_boss` XP max (`AI.gd:6-11`) | divergent — concept de choix de boss absent du C# |
| `NullAI` (IA passive) exposée mais inutilisée | `AI\NullAI.cs:9` | — | — | non vérifié (jamais instanciée : aucune occurrence de `new NullAI`) |
| Relais IA après timeout humain (>60 s) | — (mode auto-play = `RandomAI`, `HumanPlayerInteraction.cs:39`) | `p.isAI = true` + reprise bot (`matches.js:91-101`) | — | divergent — JS transforme le siège humain en bot à part entière |

---

## 3.2 Fonctions de score exactes (`DBMGameProject.AI.Statistics`)

### 3.2.1 `RoomCalculator.cs` — valeur d'une salle

**Sélecteur de phase** (`AI\AIHelper.cs:68-83`) : `Setup` = tours ≤ 0 + phase Setup ; `Early` = tours ≤ 0 ; `Mid` = tours ≤ 3 ; `Late` = tours > 3.

**Formule** (`Statistics\RoomCalculator.cs:138-149`) :
```
valeur = damageTable[room.Damage] + treasureTable[room.Treasures.Length]
       + Σ ( factors[AIType] × multiplicité )
```
plafonnée à `Math.Max(0, valeur)` (`RoomCalculator.cs:122`), puis + modificateurs de phase − pénalité build-over (`:102-121`).

**Tables** (`RoomCalculator.cs:55-63`) — indices 0..9 :

| Table | Valeurs | Ligne |
|---|---|---|
| `earlyDamageValue` | 0, 25, 100, 150, 175, **200 (plafond)** | `:55` |
| `earlyTreasureValue` | **100 (0 trésor), 50 (1), 0 (2+)** | `:56` |
| `earlyFactors` | Kill 35, Spell 20, Combo 25, Positive 0, Destroy 0, Negative 0, **Lure −100**, **Advanced −25** | `:57` |
| `midDamageValue` | 0, 25, 75, 175, 200… | `:58` |
| `midTreasureValue` | 0, 25, 100, 100, 125, 200… | `:59` |
| `midFactors` | Kill −15, Spell 25, Combo 0, Positive 10, Destroy 25, Negative −15, Lure 25, Advanced 50 | `:60` |
| `lateDamageValue` | 0, 25, 75, 175, 200… | `:61` |
| `lateTreasureValue` | 100 (0), 75 (1), 75 (2), 0 (3+) | `:62` |
| `lateFactors` | Kill 0, Spell 25, Combo 50, Positive 5, Destroy 175, Negative −75, Lure 150, Advanced 50 | `:63` |

L'ordre des facteurs est l'enum `AIRoomFactorTypes` = Kill, Spell, Combo, Positive, Destroy, Negative, Lure, Advanced (`DBMGameModel.Info\AIRoomFactorTypes.cs:3-13`), alimenté par les données carte via `AIRoomInfo.Factors` (`DBMGameModel.Info\AIRoomInfo.cs:11-69`).

**Constantes/modificateurs** :
- `setupConstructionZoneComboValue = 10000` (`:64`) — combo Construction Zone (BMA034) : +10000 si advanced Fighter/Thief en main (`:220-231`), et flag persistant `setupConstructionZoneComboActive` (`:49,154-157,210-218`) — **bug** : `SetupConstrucionZoneComboAdvancedRoom` calcule `num` puis `return 0.0` (`:217`).
- Dizzygas (BMA029) posée en premier au Setup : `−1000` (`:65,233-241`).
- Goblin Armory (BMA015) Early/Mid : `+100` si la salle précédente est un Monster, `−100` sinon (`:68-69,286-294`).
- Dizzygas Early/Mid : `+100` si la salle précédente est un Trap, `−100` sinon (`:66-67,296-304`).
- Bait (Early/Mid, s'il y a des héros en ville) : par héros qui serait **nouvellement** attiré par le joueur et survivrait (`PV > dégâts_dongeon + room.Damage`) : `−100 × Blessures + 1` (`:70-71,263-284`).
- Late : **aucun** modificateur (`:205-208`).
- Build-over (`:125-136,243-261`) : si un emplacement vide existe → 0 ; sinon min sur les emplacements occupés : recouvrement d'une advanced → `−300` ; advanced par-dessus basic → `0` ; sinon → `valeur(ancienne salle, sans modificateurs)`.

### 3.2.2 `DungeonSlotCalculator.cs` — position de pose

`valeur(slot) = RoomCalculator.CalculateValue(sans modifs) + bonus_placement − buildOver` (`Statistics\DungeonSlotCalculator.cs:25-47`), plafond à 0.
- Minotaur's Maze (BMA017) en index 4 (dernière case) : `−1000` (`:9,59-67`).
- Goblin Armory (si `DungeonSize == 5`) : index 0 → `−200` ; précédée d'un non-Monster → `−500` ; d'un Monster → `+500` (`:13,19,21,69-78`).
- Dizzygas (si `DungeonSize == 5`) : index 0 → `−1000` ; précédée d'un non-Trap → `−500` ; d'un Trap → `+500` (`:11,15,17,80-89`).
- `damageModifier = 50` et `DamageModifier()` (pénalité si la nouvelle salle fait moins de dégâts que l'ancienne) sont **du code mort** — jamais appelés (`:23,49-57`).

### 3.2.3 `DiscardCalculator.cs` / `DrawCalculator.cs` / normalisation

- Défausse salle = `RoomCalculator.CalculateValue(sans modifs)` + `cantBuildFactor` si non construisable, plafond 0 (`Statistics\DiscardCalculator.cs:48-56`) ; facteurs par phase : Setup −100, Early −100, Mid −150, Late −200 (`:8-14`).
- Défausse sort = `meilleure valeur de salle en main × keepSpellFactor` (`:58-61`) ; keepSpell : 0.4 / 0.5 / 0.9 / 1.0 (`:16-22`).
- Pioche pièce : proba de piocher une salle selon le nombre de salles construisables en main (`Statistics\DrawCalculator.cs:24-51`) : 0→1.0, 1→0.75, ≥2→**0.25 Early / 0.15 Mid / 0.1 Late**.
- Normalisation en probabilités : soustraction du min, puis `(minChance + (100 − n×minChance)/somme × valeur)/100` ; si toutes égales → `1/n` (`Statistics\StatisticsCalculator.cs:132-163`). Constantes `EarlyRoomMinChance = 5`, `Mid = 7.5`, `Late = 10` déclarées mais **inutilisées** dans le corps décompilé (`:12-16`, switch vide `:49-51`).

### 3.2.4 `AbilityCalculator.cs` — éligibilité/valeur des sorts & habilités

Table de dispatch par numéro de carte (`Statistics\AbilityCalculator.cs:16-61`) : BMA040–BMA055, BMA009, BMA024, BMA027, BMA028, BMA030, BMA038, BMA039, BMA013, BMA032, KSA013 ; en bataille de sorts uniquement BMA043 et BMA025 (`:18-27`). Toute carte non listée → `null` = ne jamais jouer (`:57`).

Toutes les valeurs retournées sont **binaires `1.0`** (éligible) ou `null` (inéligible) — ex. `Tuple.Create(1.0, …)` `:84,105,128,…`. Conditions notables (heuristiques carte-par-carte) :
- **BMA040 Annihilator / BMA047 Giant Size** : héro dans l'entrée ou actif, `0 < PV_après_dongeon ≤ 3` (`:825-868`).
- **BMA041 Assassin** : hors Setup/Early ; adversaire attiré, héro mourrait dans (−3, 0] (`:68-89`).
- **BMA042 Cave-In** : héro survivant dans le slot de valeur min (`CalculateWorstSlot`, `severalRoomsInSlotFactor = −75`, `:14,933-952`).
- **BMA043 Counterspell** (bataille) : sort adverse nous visant, sinon BMA040/044/047/053 sans cible, sinon KSA013 (`:111-150`).
- **BMA044 Exhaustion** : Late seulement ; `0 < PV_après ≤ DungeonSize` (`:152-170`).
- **BMA046 Freeze** : slot le plus dommageable restant (`:212-238`).
- **BMA048 Jeopardy** : main ≤ moyenne adverse − 1 (`:245-266`).
- **BMA049 Kobold Strike** : `DungeonSize ≥ moyenne adverse + 1` (`:268-289`).
- **BMA050 Motivation** : ≥ 2 salles construisables en main (`:291-305`).
- **BMA051 Princess in Peril** : héro orphelin (tie-break ou soul-less) que l'on pourrait tuer (`:307-345`).
- **BMA052 Soul Harvest** : Late ; moins de sorts que la moyenne (`:347-373`).
- **BMA054 Trepidation** : Late ; adversaire `Souls ≥ miennes + 2` avec file d'entrée (`:395-416`).
- **BMA055 Zombie Attack** : Late ; héros épique du leader, `PV_initiaux − dégâts_dongeon > −2` (`:418-445`).
- **BMA009 Dark Altar** : Mid avec salle dessous, ou Late avec dongeon > 4 ; pioche la meilleure salle du discard, sinon un sort au hasard (`WaveServices.Random.NextBool`, `:447-498`).
- **BMA013 Dracolich Lair** : échange 2 cartes non construisables contre la meilleure salle du discard (`:671-711`).
- **BMA024 Witch's Kitchen** : main < 2 sorts, meilleure salle Monster (`:500-523`).
- **BMA028 Boulder Ramp** : recalcule les dégâts en retirant la salle cible (+5) pour tuer un héro survivant (`:545-592`).
- **BMA030 Jackpot Stash** : simulation complète des trésors/bait `BMA030Logic` (`:870-931`).
- **BMA032 The Crushinator** : comptage des blessures évitées `num2 < num` (`:748-816`).
- **BMA038/039** : cible = adversaire au plus haut `Score` (`:610-669`).
- Valeurs annexes : `CalculateSpellValue` (priorité fixe KSA013 > BMA051 > BMA043 > BMA046 > BMA045, `:954-972`) et `CalculateHeroValuetoSteal` (`:974-983`, inclut un `Intersect != null` toujours vrai — buggy).

### 3.2.5 `TriggerCalculator.cs` — activation & cibles

Dispatch par carte (`Statistics\TriggerCalculator.cs:48-141`) : BMA000–BMA037 (séries), KSA002–KSA004 ; sinon cibles vides. Exemples :
- BMA010 Open Grave : meilleure salle construisible du discard (`:151-162`).
- BMA011/012 : adversaire trié `Score desc, SpellsInHand desc` (`:164-201`).
- **BMA033 Centipede Tunnel** : casse les combos adverses (Minotaur `:676-688`, Vampire Bordello `:648-660`, Dizzygas `:724-736`, Goblin Armory `:763-794`) sinon crée les siens (`:690-722,738-761,796-827`), ordre de priorité Minotaur→Vampire→Dizzygas→Goblin (`:238-272`).
- BMA006 Mimic Vault : héros killable trié `Souls desc` (`:459-476`).
- BMA008 : héros de ville trié `Souls desc` puis `PV − dégâts desc` (`:497-513`).
- Cibles de commande (défense d'un sort adverse) : **cible prise au hasard** dans les disponibles (`Shuffle().First()`, `:609-623`).
- État machine `resolvingCard/targetIndex/selectedTargets` pour séquences multi-cibles (`:14-28,143-149,625-636`).

### Matrice B — score de salle & sélection

| Décision/règle | C# original (fichier:ligne) | JS (…:ligne) | Godot (…:ligne) | Statut |
|---|---|---|---|---|
| Formule salle = tableDamage + tableTrésors + Σ facteurs IA | `RoomCalculator.cs:138-149` | tableDamage seule + advanced flat + trésors par type (`ai.js:58-89`) | `damage*10 + trésors*3` linéaire (`AI.gd:33`) | divergent |
| Bornes de phase : Mid = tours 1–3, Late ≥ 4 | `AIHelper.cs:68-83` | Early ≤ 1, Mid 2–4, Late ≥ 5 (`ai.js:54-56`) | `G.turn` jamais lu (`AI.gd:27-38`) | divergent — décalage d'un tour sur Mid/Late |
| `earlyDamageValue` = 0/25/100/150/175/200 | `RoomCalculator.cs:55` | 0/2.5/10/15/17.5/20 (÷10) (`ai.js:62`) | — | aligné (échelle ÷10) |
| `midDamageValue` = 0/25/75/175/200 | `RoomCalculator.cs:58` | 0/2.5/7.5/17.5/20 (`ai.js:64`) | — | aligné |
| `lateDamageValue` = 0/25/75/175/200 | `RoomCalculator.cs:61` | 0/2.5/7.5/17.5/20 (`ai.js:66`) | — | aligné |
| `earlyTreasureValue` = 100 (0 trésor) / 50 (1) / 0 (2+) — Early favorise les salles sans trésor | `RoomCalculator.cs:56` | **inversé** : +1 par type de trésor manquant (`ai.js:84-87`) | +3 par trésor (`AI.gd:33`) | divergent |
| `midTreasureValue` = 0/25/100/100/125/200 | `RoomCalculator.cs:59` | — | — | absent JS |
| `lateTreasureValue` = 100/75/75/0… | `RoomCalculator.cs:62` | — | — | absent JS |
| `earlyFactors` (Kill 35, Spell 20, Combo 25, Lure −100, Advanced −25) | `RoomCalculator.cs:57` | — | — | absent JS |
| `midFactors` (−15/25/0/10/25/−15/25/50) | `RoomCalculator.cs:60` | — | — | absent JS |
| `lateFactors` (0/25/50/5/175/−75/150/50) | `RoomCalculator.cs:63` | — | — | absent JS |
| Facteurs lus par carte via `AIRoomInfo` (Kill…Advanced) | `RoomCalculator.cs:143-147`, `AIRoomInfo.cs:34-69` | — | — | absent JS — aucun champ facteur dans `cardData.json` |
| Plafond à 0 de la valeur | `RoomCalculator.cs:122` | scores négatifs possibles (`ai.js:79,227`) | — | divergent |
| Advanced par-dessus advanced : −300 | `RoomCalculator.cs:125-129` | −30 (`ai.js:74-75`) | — | aligné |
| Advanced par-dessus basic : 0 | `RoomCalculator.cs:131-134` | +0 (`ai.js:76-77`) | — | aligné |
| Basic par-dessus basic : pénalité = valeur de l'ancienne salle | `RoomCalculator.cs:135` | `oldRoom.damage * 2` (`ai.js:79`) | — | divergent — JS ignore trésors/facteurs de la salle recouverte |
| Pénalité build-over = min(emplacements occupés), 0 si slot vide | `RoomCalculator.cs:243-261` | appliquée uniquement sur le slot visé (`ai.js:71-81`) | — | partiel |
| Bait Early/Mid : −100 × Blessures + 1 par héros qui serait attiré et survivrait | `RoomCalculator.cs:70-71,263-284` | — | — | absent JS — aucun calcul d'attraction au build |
| Combo Construction Zone (BMA034) : +10000 (advanced Fighter/Thief en main) | `RoomCalculator.cs:64,220-231` | — | — | absent JS |
| Setup : Dizzygas (BMA029) en première salle : −1000 | `RoomCalculator.cs:65,233-241` | — | — | absent JS |
| Early/Mid : Goblin Armory après Monster +100 / sinon −100 | `RoomCalculator.cs:68-69,286-294` | — | — | absent JS |
| Early/Mid : Dizzygas après Trap +100 / sinon −100 | `RoomCalculator.cs:66-67,296-304` | — | — | absent JS |
| Late : aucun modificateur | `RoomCalculator.cs:205-208` | — | — | aligné |
| Choix de salle : argmax score, tie-break `Damage desc` | `FixedAI.cs:34-36` | argmax strict, 1er casse l'égalité (`ai.js:20-26`) | meilleur `damage` seul (`Match.gd:184-197`) | partiel — pas de tie-break dégâts côté JS |
| Bonus level-up : 5 salles visibles sans level-up | — | +25 (`ai.js:88-89`) | — | divergent (capacité JS-only, sans équivalent APK) |

### Matrice C — position, pioche, défausse

| Décision/règle | C# original (fichier:ligne) | JS (…:ligne) | Godot (…:ligne) | Statut |
|---|---|---|---|---|
| Choix de position : argmax `DungeonSlotCalculator`, tie-break dégâts du haut | `FixedAI.cs:50-52` | argmax sur `buildRoom` args `[i, ti]` (`reducer.js:209-213` + `ai.js:71-82`) | aucun choix : `dungeon.append([card])` (`Match.gd:114-118`) | absent Godot |
| Slot value = salle + bonus placement − build-over | `DungeonSlotCalculator.cs:25-47` | build-over seul (`ai.js:71-81`) | — | partiel |
| Minotaur's Maze interdite en dernière case : −1000 | `DungeonSlotCalculator.cs:9,59-67` | — | — | absent JS |
| Goblin Armory : −200 en first, ±500 selon voisin Monster (`DungeonSize==5`) | `DungeonSlotCalculator.cs:13,19,21,69-78` | — | — | absent JS |
| Dizzygas : −1000 en first, ±500 selon voisin Trap (`DungeonSize==5`) | `DungeonSlotCalculator.cs:11,15,17,80-89` | — | — | absent JS |
| `damageModifier = 50` (pénalité dégâts décroissants) | `DungeonSlotCalculator.cs:23,49-57` (code mort) | — | — | non vérifié — jamais appelé dans le décompilé |
| Choix du deck de pioche (proba 1.0/0.75/0.25, 0.15, 0.1 selon salles construisables) | `DrawCalculator.cs:24-51`, tiré au sort par `StatisticAI.cs:18-25`, délégué par `FixedAI.cs:14-17` | pioche fixe 5+2, aucun choix (`reducer.js:305-312`) | pioche fixe 3+2 (`Match.gd:137-141`) | absent JS — modèle de pioche unique salle/sort inexistant |
| Défausse de fin de setup : `amount` cartes de plus faible valeur (ordre ascendant) | `FixedAI.cs:19-24` | 2 cartes min par `openingDiscardScore` (sort 80, salle `dmg*10+adv*8`) (`reducer.js:246-257`) | — (5 cartes direct, `Match.gd:138`) | partiel — formule simplifiée JS |
| Valeur de défausse salle : valeur sans modifs + (−100/−100/−150/−200 si non construisable) | `DiscardCalculator.cs:8-14,48-56` | `discardCost` linéaire `dmg*0.7 + adv*2.5 + trésors*0.6` (`ai.js:31-39`) | — | divergent |
| Valeur de défausse sort = meilleure salle × (0.4/0.5/0.9/1.0) | `DiscardCalculator.cs:16-22,58-61` | sort = 1.5 fixe (`ai.js:37`) | — | divergent |
| StatisticAI : défausse = sélection pondérée aléatoire des cartes *conservées* | `StatisticAI.cs:27-32,117-143` | — | — | absent JS (le JS n'a qu'une défausse d'ouverture déterministe) |

---

## 3.3 Décisions concrètes de l'IA C# (synthèse)

- **Quelle salle piocher** : pas de choix de carte — choix du *deck* (salle vs sort) par probabilité `DrawCalculator` via `StatisticAI` (`FixedAI.cs:14-17`).
- **Quelle salle défausser** : les `amount` cartes de valeur la plus basse (`FixedAI.cs:21-23`) — mélange salle (valeur `RoomCalculator` sans modifs + pénalité « non construisable ») et sorts (meilleure salle × facteur de conservation).
- **Quelle salle bâtir** : argmax `RoomCalculator.CalculateValue` sur les salles constructibles (`AIHelper.cs:13-16`), tie-break dégâts (`FixedAI.cs:34-36`).
- **Où la poser** : argmax `DungeonSlotCalculator` sur les emplacements constructibles (`AIHelper.cs:18-21`), tie-break dégâts de la salle du dessus (`FixedAI.cs:50-52`).
- **Quels sorts/habilités jouer** : une seule ability par appel, valeur binaire 1.0 si les conditions heuristiques de `AbilityCalculator` sont remplies (`AbilityCalculator.cs:16-61`), tirage pondéré par `StatisticAI.RandomSelection` (`StatisticAI.cs:58-70,100-115`).
- **Quels triggers/cibles** : heuristiques par numéro de carte dans `TriggerCalculator` (cf. §3.2.5) ; pour les défenses de commande, cible **aléatoire** (`TriggerCalculator.cs:609-623`).
- **Quand passer** : l'IA C# ne « passe » pas au sens JS — elle construit tant que `SelectRoomToBuild` ≠ null (jusqu'au quota, `AIPlayerInteraction.cs:165-186`) et s'arrête sinon ; aucune notion de garde anti-blocage.

---

## 3.4 Couverture JS — `src/backend/game/ai.js`

Architecture : **argmax sur `legalMoves`** (`aiPickMove`, `ai.js:11-28`), piloté par le serveur toutes les 350 ms (`matches.js:60-74`), avec aide externe pour l'ouverture (`pickOpeningDiscardIndices`, `reducer.js:252-257`) et les choix de level-up (`aiResolveLevelUpChoice`, `roomAbilities.js:1775-1825`).

Implémenté avec formule :
- Construction (table damage ÷10 identique, advanced +5, trésors +1/+3 par type nouveau, build-over simplifié, bonus level-up +25) — `ai.js:51-90` (cf. Matrice B).
- Sorts : constante par carte si la cible du move est non nulle (BMA040/047→10, BMA043→12, BMA025→11, BMA051→9, BMA054→8, BMA046→8, BMA044/BMA055→7, BMA050→7, BMA049→6, BMA041/BMA042→6, BMA052→5, BMA045→5, BMA053→1, défaut 2) — `ai.js:158-208`.
- Activations de salle : BMA027→9, BMA028→8, BMA024→4, BMA009→2, THK021→6, THK022/023→5, RMB015→6/−5, sinon −8 — `ai.js:210-228`.
- Extras expansions/variantes JS : `buildMiniboss` 6, `promoteMiniboss` 5, `activateMiniboss` 8, `payDarkHero` 7, `resolveNextHero` 5/8, `docScarecrow` (coût `6 − discardCost×0.5`, refus si on tue déjà le héros, `−10` sinon), `timebenderCancel` (`11 − discardCost×0.5`, `−10` sinon) — `ai.js:100-141`.
- Garde anti-étale : `pass` → −40 si aucun héros n'est attractible (`ai.js:142-152`).
- Sélection de boss : XP max (`ai.js:6-8`, doublon auto dans `reducer.js:292-303`).

**Ce qui manque côté JS (capacités absentes)** :
1. Choix du deck de pioche (salle vs sort) — modèle de pioche fixe.
2. Toutes les tables de trésors (mid/late) et l'inversion Early (favoriser les salles sans trésor).
3. Les 3 tables de facteurs IA (Kill/Spell/Combo/Positive/Destroy/Negative/Lure/Advanced) et les données `AIRoomInfo` par carte.
4. Pénalité bait (−100 × Blessures) et toute la simulation d'attraction au build.
5. Combos de placement : Construction Zone (+10000), Dizzygas/Goblin Armory (±100/±500), Minotaur dernière case (−1000), Dizzygas en première salle (−1000).
6. Le plafond à 0 (scores JS négatifs possibles).
7. Les 25+ heuristiques de triggers carte-par-carte (`TriggerCalculator`) — `scoreActivate` ne couvre que 8 salles/sorts.
8. Les décisions d'abilities conditionnelles fines (BMA030 simulation trésors, BMA032 blessures évitées, BMA013, BMA038/039, BMA009 cycle complet…) — remplacées par des constantes.
9. Le tri de cibles adverses par `Score` (BMA011/012/033/038/039…).
10. Défausse mid-game pondérée (seule l'ouverture existe : `reducer.js:246-257`).
11. Cible de commande aléatoire → JS : cibles énumérées et notées dans les moves.

---

## 3.5 Couverture Godot — `godot/scripts/AI.gd`

Miroir minimal de `ai.js` (commentaire assumé `AI.gd:3-4`, *« scoring complet (sorts, miniboss, level-up) reporté à la phase 2 »*) :
- `choose_boss` : XP max (`AI.gd:6-11`).
- `pick_move` : argmax sur `legal_moves` (`AI.gd:13-25`) mais **score limité** : `pickBoss` 1.0, `buildInitialRoom`/`buildRoom` = `damage*10 + trésors*3` (`AI.gd:31-33`), `passBuild` −1 (`:34-35`), `adventureNext` 0 (`:36-37`), défaut 0 (`:38`).
- **Second chemin IA** : `Match._ai_build` ignore `AI.gd` et construit la salle au **maximum de dégâts** en fin de phase build (`Match.gd:176-197`).
- Invocation : uniquement phases `boss`/`build`, délai 0,6 s (`Board.gd:62-78`) / 0,5 s (`BoardUI.gd:51-67`).

**Absents Godot** : choix de position de salle, pioche (fixe 3+2, `Match.gd:137-141`), défausse, sorts, activations de salle, triggers, cibles, bataille de sorts, expansions, phase adventure côté IA. Aucune table de phases (Early/Mid/Late) ni aucun modificateur de `RoomCalculator`.

---

## 3.6 Déterminisme / RNG

| Implémentation | Comportement | Référence |
|---|---|---|
| C# `FixedAI` (salle/position/défausse) | **déterministe** (argmax + tie-breaks) | `FixedAI.cs:21-23,34-36,50-52` |
| C# `FixedAI` (pioche/abilities/cibles) | **non déterministe** : délègue à `StatisticAI` qui tire `WaveServices.Random.NextDouble()` | `StatisticAI.cs:20,103,128` ; aussi `AbilityCalculator.cs:486,969` (hasard dans BMA009 et `CalculateSpellValue`) |
| C# RNG global | `RandomProvider` **seedable** (setter `Seed`, compteur de samples pour rejouer) ; tutoriel = seed 2832 | `DBMGameModel\RandomProvider.cs:15-41`, `GameBoardExtensions.cs:25` ; `Shuffle` : `RandomProvider.cs:43-62` (RAND partagé vs `rndSeed` d'entropie pour `useSharedRandom:false`) |
| C# `RandomAI` | mélange sur `rndSeed` (hors seed de partie) | `RandomAI.cs:25,30,41`, `RandomProvider.cs:52` |
| JS `ai.js` | **100 % déterministe** (argmax, aucun `Math.random`) | `ai.js` (aucune occurrence) |
| JS état de partie | **non seedable** : `Math.random` dans `shuffle` et effets | `cardData.js:185-209`, `roomAbilities.js:1784,2221`, `minibosses.js:490` |
| Godot `AI.gd` | **déterministe** (boucles strictes `>`) | `AI.gd:8-9,21-22` |
| Godot `Match.gd` | RNG **non seedé** (`rng.randomize()`) pour les decks | `Match.gd:13,16` |

Conséquence : une partie C# peut être rejouée par seed (`RandomProvider.Seed` + `UpdatesNumberOfCallsToNext`), ce qui n'est le cas ni du JS ni du Godot actuels.

---

## Écarts de difficulté IA

1. **C# est de loin la plus forte** : 3 tables de score par phase + facteurs par carte + 12 modificateurs positionnels + ~25 heuristiques de triggers + ~20 règles d'abilities conditionnelles (simulations de trésors, blessures, bait). Les décisions les plus profondes (BMA030, BMA032, BMA033 combos) sont des mini-simulations du jeu.
2. **JS est intermédiaire** : elle reprend fidèlement la table de dégâts (÷10) et le build-over de base, ajoute de bonnes garde-fous (anti-étale, docScarecrow conditionnel, timebender conditionnel, cibles énumérées et notées), mais ignore trésors par phase, facteurs, bait et tous les combos de placement — d'où un bot « correct mais linéaire » qui construira une salle Dizzygas mal placée ou qui suicide un bait coûteux.
3. **Godot est un bot faible** : `damage*10 + trésors*3`, pas de position, pas de sorts ; le chemin `_ai_build` (max dégâts) contourne même son propre score.
4. **Sens d'erreur JS notable** : le bonus trésor Early JS (+1/+3 par type nouveau) pousse l'IA JS à empiler les trésors tôt, à l'inverse de l'APK qui valorise à 100 les salles **sans** trésor en Early (`RoomCalculator.cs:56`) — comportement d'ouverture radicalement différent face à un même deck.

---

## Divergences confirmées

1. **Trésor Early inversé** — l'APK donne 100/50/0 aux salles à 0/1/2+ trésors en Early (`RoomCalculator.cs:56`), l'IA JS ajoute +1 (+3 mid/late) par type de trésor absent du dongeon (`ai.js:84-87`), et Godot +3 par trésor (`AI.gd:33`) : les trois IA préfèrent des salles opposées dès l'ouverture.
2. **Bait et compétition de trésors absents du JS** — l'APK applique `−100 × Blessures + 1` par héros qui survivrait en étant attiré (`RoomCalculator.cs:263-284`), l'IA JS n'évalue jamais l'attraction au moment de construire (seul `docScarecrow` la consulte a posteriori, `ai.js:114-129`).
3. **Combos de placement non portés** — Construction Zone +10000 (`RoomCalculator.cs:64,220-231`), Goblin Armory/Dizzygas ±100/±500 (`RoomCalculator.cs:286-304`, `DungeonSlotCalculator.cs:69-89`), Minotaur interdite en case 5 (−1000, `DungeonSlotCalculator.cs:59-67`) : aucune de ces règles n'existe en JS ni en Godot.
4. **Pioche choisie vs pioche imposée** — l'APK arbitre salle/sort par probabilité selon ses constructibles (`DrawCalculator.cs:24-51` via `StatisticAI.cs:18-25`) ; le JS distribue 5+2 fixes (`reducer.js:305-312`) et le Godot 3+2 (`Match.gd:141`) : le bot JS/Godot ne peut pas « chercher des salles ».
5. **Triggers carte-par-carte** — l'APK encode des cibles intelligentes pour ~28 cartes dont le mini-jeu de combos de Centipede Tunnel (`TriggerCalculator.cs:227-280,648-843`) ; le JS ne score que 8 activations (`ai.js:210-228`) avec des constantes, le Godot zéro — un bot JS jouera BMA033 sans logique de combo.
6. **Phases décalées d'un tour** — Mid = tours 1–3 et Late ≥ 4 dans l'APK (`AIHelper.cs:78-82`), Mid = tours 2–4 et Late ≥ 5 côté JS (`ai.js:54-56`).
7. **Build-over basic→basic divergent** — l'APK pénalise de la valeur complète de la salle recouverte (`RoomCalculator.cs:135`), le JS seulement `damage*2` (`ai.js:79`), ignorant trésors et facteurs perdus.
8. **Déterminisme partiel en C#** — `FixedAI` est déterministe pour la construction mais ses délégués (pioche, abilities, cibles) tirent sur `WaveServices.Random` (`StatisticAI.cs:20,103`), donc même seedé via `RandomProvider`, le replay C# n'est pas garanti sans re-seed du RNG moteur WaveEngine ; le JS, lui, est déterministe mais son état de partie ne l'est pas (`cardData.js:185-209`).

## 4. Validation croisée — décompilation (REA) × émulation (BlueStacks)

Vérifié le 2026-10-10. But : prouver que le C# décompilé est fidèle (REA) et que
l'APK émulé se comporte comme le modèle décompilé (BlueStacks).

### 4.1 REA : 145 méthodes C# ancrées à l'IL, 0 rejet

- Preuve : `apk-original/decompiled/evidence/reconstruction_validation.json`
  (`ev_09a69103...`, opération `import_managed_reconstruction`, provider
  `rea-dotnet-workflows`), artifact SHA-256 `7bf2ae01...`, ilspycmd 9.1.0.7988,
  100 % statique (`executed: False`).
- Chaque méthode verrouillée = token + `signature_sha256` + `normalized_il_sha256`
  + `body_sha256` : le texte ILSpy cité dans ce rapport est rattaché au CIL
  d'origine pour ces méthodes.

| Type | Liées / méthodes IL | Non liées (nature) |
|---|---|---|
| `AI.Statistics.RoomCalculator` | 15 / 18 | `.cctor`, lambdas `b__*` |
| `AI.Statistics.TriggerCalculator` | 41 / 82 | `.ctor`, lambdas `b__*` des combos |
| `Abilities.Targets.RoomInDungeon` | 8 / 14 | lambdas `b__*`, méthode `InternalGetAvailableTargets` |
| `Logic.GameBoard` | 61 / 99 | lambdas `b__*` (`AvoidMulliganCondition`, `CheckEndOfGame`...) |
| `AI.FixedAI` | 7 / 14 | `.ctor`, lambdas `b__*` |
| `Logic.AbilityFactory` | 13 / 17 | `Create*` génériques (`CreateCommand`, `CreateCondition`, `CreateTargetProvider`, `CreateTrigger`) |
| **Total** | **145 / 244** | **0 rejet à l'import** |

- Note : le `local_path` de la preuve pointe vers `tools/extracted_assemblies/`
  (emplacement pré-déplacement ; octets identiques, SHA inchangé).
- Outil : `tools/build_reconstruction_payload.py` (liste `TYPES` extensible).

### 4.2 Émulation : l'APK 2.2.6 émulé confirme le modèle décompilé

- Protocole : BlueStacks Nxt (`emulator-5554`, `HD-Adb.exe`), package `com.dbm.project`,
  `versionName=2.2.6` (dumpsys) — **même version que la cible décompilée**.
- Script : `tools/capture_apk_full_turn.py` (corrigé : sur l'écran expansions, taper
  OK — l'ancien SKIP ouvrait la popup "40 WINS TO UNLOCK" de Hidden Heroes).
  Captures dans `docs/reference/` (gitignoré).

| Observation émulée | Conforme au décompilé |
|---|---|
| Boot "BOSS MONSTER — TAP TO START" | — (identité app) |
| Écran expansions : 4 decks (Base / Tools / Player's Choice / Hidden Heroes) | `assets/Content/CardDecks/` = 4 dossiers |
| Sélection boss "YOU ARE ...", 5 cartes BOSS face cachée | `RandomBossSelectionScene.cs` |
| "SELECT 2 CARDS TO DISCARD", main 5 salles + 2 sorts | phase Setup/défausse (`GameBoard.cs`) |
| Bannière "BUILD PHASE", donjon à 5 emplacements vides | 5 slots max, ordre des phases |
| Main à 5 cartes après défausse | pioche 5+2, défausse 2 |
| Compteurs : 5 emplacements WOUNDS, 10 SOULS, decks Room x3 / Spell x2, TREASURES, LEVEL UP | `WOUNDS_TO_DIE=5`, `SOULS_TO_WIN=10` |
| Bouton "PASS TURN" + adversaire IA (Cerebellus) en 2P | `DoneButtonBehavior`, `FixedAI` |
| Boss pioché : King Croak (panneau XP, avatar) | données `BaseDeck/data.json` |

- Limites de cette passe : geste de pose d'une salle non rejoué (sélection de carte OK,
  *ghost slot* non déclenché en pilotage manuel ; la pose est un comportement UI
  WaveEngine, pas une règle) ; phases Bait/Adventure, valeurs des minuteurs et fin de
  partie non ré-observées (couvertes par les captures historiques `docs/reference/run*`).
- Census exhaustif des assets : `apk-original/decompiled/assets_full_coverage.md`
  (123/123 fichiers APK extraits ou justifiés, 0 manquant ; outil `tools/check_full_coverage.py`).
