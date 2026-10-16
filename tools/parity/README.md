# Harnais de parite JS <-> GDScript

Mesure l'ecart entre le moteur de regle JavaScript (`src/backend/game/`, 8 719 lignes,
reference issue de l'APK) et son port GDScript (`src/frontend/godot/scripts/`).
C'est l'instrument qui rend les phases 2 a 5 de la roadmap **verifiables** : avant
de supprimer le JS en Phase 8, on doit pouvoir prouver que GDScript rejoue
exactement les memes parties.

## Usage

```bash
npm run test:parity          # gen + rejeu GDScript + diff  (genere des traces)
npm run test:parity:gen      # regenere seulement les traces
node tools/parity/compare.mjs --seeds 1 2 3 4 5   # plus de graines
```

Sortie : `tools/parity/out/parity-report.json` (genere, gitignore).

## Comment ca marche

1. `gen.mjs` joue des parties completes avec le moteur **JS** pilote par sa propre
   IA, et enregistre pour chaque coup la projection canonique de l'etat.
2. `Parity.tscn` (Godot headless) rejoue **exactement la meme liste de coups** dans
   le port GDScript via `ParityTrace.gd`.
3. `compare.mjs` compare les deux projections coup par coup.

## Deux difficultes que le harnais a du resoudre

**Les melanges ne sont pas reproductibles.** `reducer.js` melange avec
`Math.random()` et `CardDB.gd` avec `RandomNumberGenerator.randi_range()`. Aucun
PRNG n'est reproductible entre Float64 et float32. Le harnais contourne le
probleme : la trace **contient la distribution initiale complete**, et GDScript
l'adopte au lieu de remeler. C'est aussi ce qui permet au port de jouer la meme
partie que l'APK.

**Les deux moteurs n'ont jamais partage la meme forme d'etat.** `ParityTrace.adopt()`
traduit une fois pour toutes :

| JS | GDScript | Effet si non traduit |
|---|---|---|
| `logs` | `log` | `Match._log()` plante |
| `pendingChoice: null` | `{}` | `.is_empty()` sur null |
| `gameOver: false` | `null` | partie vue comme finie |
| cles `"0"`, `"1"` (string) | `0`, `1` (int) | `players.has(0)` faux -> aucun coup legal |
| `resolveLevelUpChoice` | `resolveChoice` | coup refuse |
| `pass` | `passBuild` | coup refuse |

Et `dungeon` est un tableau de **slots**, chaque slot contenant une **pile** de
salles empilees (`dungeon[i][0]`) : la projection le respecte, sinon tous les ids
sortent `null`.

## Ce qui est compare

Uniquement des invariants, via `canon.mjs` : phase, tour, joueur actif, joueur
gagnant, et par joueur (ames, blessures, boss + XP, main, donjon, entree, etats
d'activation) plus les tailles de pioches/defausse et la ville.

## Ecarts connus ignores

`KNOWN_GAPS` liste les champs absents du port a ce jour. **Chacun est un livrable
de phase, pas une regression** — c'est la liste de travail des phases 2 a 4 :

| Champ | Phase | Pourquoi il est ignore |
|---|---|---|
| `adventure` | 2 | le port resout l'aventure en un seul pas, sans etat persiste |
| `stack` | 3 | pile de sorts non portee |
| `players.*.coins` / `.items` / `.passed` | 4 | extension minibosses |
| `townItems`, `decks.items/minibosses`, `discards.*` | 4 | contenu extension |

Un champ absent des deux cotes est ignore ; present d'un seul cote, c'est une
divergence. Retirer une entree de `KNOWN_GAPS` **est** le jalon de la phase
correspondante.

## Lire le rapport

```
trace-s1-p2-base.json  284 coups  REFUS@0 (buildInitialRoom)
    phase: js="setup" gd="boss"
    players.0.hand.0: js="BMA024" gd=null
```

`REFUS@N` = le port refuse le coup N (absent de `legal_moves`). La trace s'arrete
la : continuer au-dela ne produirait que du bruit. `DIVERGE@N` = le coup est
accepte mais l'etat resultant differe.

## La trace commence apres l'attribution des boss

Volontairement. L'APK attribue les boss a l'initialisation
(`GameBoardExtensions.InititalizeGameBoard`) et n'expose **aucun** coup
`pickBoss` : l'ecran est un caroussel purement cosmetique
(`RandomBossSelectionScene`, 5 s de rotation puis retour force sur le boss deja
attribue). Le moteur JS, lui, fait choisir le joueur dans une liste. Les deux
moteurs divergent donc legitimement sur cette phase ; la comparer noierait tout le
reste. `gen.mjs` fige donc l'etat une fois la phase `setup` atteinte, mains
distribuees, et ne compare que ce qui suit.

## Machine de phases de reference (APK 2.2.6, verifie)

`GameBoard.GamePhases` (`DBMGameModel.Logic/GameBoard.cs`) — **13 phases**, pas 6 :

```
Setup_a  -> DrawRooms(5) + DrawSpells(2) + DiscardCardsInHand(2)      (le mulligan)
Setup_b  -> CheckAllPlayersDiscardsTwoCards()
Setup_c  -> DeactivateLastActivePlayer + RevealAllRoomCards()
BeginningOfTurn -> RevealItems + RevealHeroes, puis DrawRooms par joueur
                    (ou ChooseCardTypeToDraw si IsCanChooseCardToDraw),
                    CheckTriggerInDungeon<AtTheBeginingOfYourTurn>
BuildPhase_a -> ChooseNextActivePlayer ; reste en _a tant qu'il reste un joueur vivant
BuildPhase_b -> DeactivateLastActivePlayer + RevealAllRoomCards   -> les salles se revelent ICI
ExtraBuildPhase -> un joueur de PendingExtraBuiltTurns rejoue son tour
BaitPhase -> AssignHeroesToDungeons
AdventurePhase_a -> ChooseNextActivePlayer   AdventurePhase_b -> ChooseNextActiveHero
AdventurePhase_c -> ProccessActiveHero
EndOfTurnPhase -> RestoreDungeon + ReactivateAllRooms + CheckEndOfGame
EndOfGame
```

Regles cle :

- **Ordre de tour** : `PlayersPriorized => Players.OrderBy(p => p.PlayerId)`, et
  `PlayerId` est attribue dans `InititalizeGameBoard` par **XP decroissant**. Le
  boss le plus fort construit donc en premier. Le meme ordre que le JS.
- **`ExtraBuildPhase`** est declenche par `PendingExtraBuiltTurns` en
  `BeginningOfTurn` ou `BaitPhase`. Le JS ne l'a pas.
- **Aucune salle initiale.** `InternalInititalizeGameBoard` ne construit que les
  quatre pioches. Le premier coup `buildInitialRoom` du JS et du port est donc
  **inventé** : dans l'APK la premiere salle se pose en `BuildPhase_a` comme
  n'importe quelle autre, et se revele en `BuildPhase_b`.

## Piege : le JS n'est pas la reference

Au-dela des ecarts de details, le moteur JS **reinvente une phase entiere** :
son `SETUP` ou chaque joueur pose une salle initiale n'existe pas dans l'APK, ou
`Setup_a/b/c` ne servent qu'a distribuer la main et a la melanger. Porter le JS
tel quel porterait cette erreur avec lui.

## Etat actuel du harnais (mesure, pas estimation)

**22 %** — les traces sont rejetees au coup 3 ou 4. Ecarts successifs trouves et
corriges depuis le debut du harnais :

| Ecart | Cause |
|---|---|
| trace refusee au coup 0 | 6 divergences de conventions d'etat (voir tableau plus haut) |
| `dungeon` entiers `null` | `dungeon` est un tableau de slots contenant des piles de salles |
| identifiants de joueur | cles JSON `"0"` vs int `0` dans le port |
| `buildInitialRoom` refuse | arguments de coup JSON parsés en float : `[0.0]` != `[0]` |
| `buildRoom` refuse | le JS envoie `[i, null]`, le port `[i]` : on ignore les nuls de fin |
| `players.*.passed` | mecanisme interne du JS, equivalent a `buildsThisTurn` cote port |

**Divergence ouverte :** pendant la phase `setup`, le JS fait tourner le joueur
actif d'un joueur a l'autre, le port attend que tous aient pose. L'ecart
reapparait a chaque tour de setup (`active: js=0 gd=1`). C'est le prochain
livrable de la Phase 2.

## Piege : le JS n'est pas la reference

Le harnais mesure JS <-> GDScript, ce qui est utile mais **insuffisant** : le JS
est une reimplementation, et sur l'attribution des boss il s'ecarte de l'APK
(reserve de boss du mode essai, `Shuffle().Take(n - nHumains)` pour l'IA au lieu
du boss au plus fort XP, `PlayerId` attribue par **rang d'XP decroissant**). Pour
ces mecaniques, seule reference : `apk-original/decompiled/DBMGame/**`, verifie
en execution sur BlueStacks Nxt (l'emulateur du SDK Android ne sait plus
executer d'invite ARM, et l'APK est `armeabi-v7a` seul).
---

# Parite Godot <-> APK ORIGINALE (`npm run test:parity:apk`)

Le harnais ci-dessus compare le port a un moteur JS qui n'est **pas** la reference.
Celui-ci compare a la vraie : `tools/apk-oracle` fait jouer `DBMGame.dll` 2.2.6
(IA originale contre IA originale) et trace chaque phase, action et decision.

```bash
npm run test:parity:apk                       # graines 1-3 x 2 et 3 joueurs (BaseDeck), ~15 s : doit rester 6/6 OK
npm run test:parity:apk:wide                  # graines 4-7 x 2, 3 et 4 joueurs, ~25 s : couverture, des echecs connus (voir « Limites »)
node tools/parity/apk.mjs --seeds 4 5 --players 2 4
node tools/parity/apk.mjs --decks BaseDeck,PlayerChoice,HiddenHeros   # autres paquets (l'oracle les joue, Godot n'en gere pas les regles)
node tools/parity/apk.mjs --skip-gen          # rejoue les traces deja generees
GODOT=<exe> npm run test:parity:apk           # sinon C:/Tools/Godot/...console.exe, puis `godot`
APK_PARITY_OUT=<dossier> npm run test:parity:apk   # dossier de sortie dedie (rejeux paralleles de plusieurs agents)
```

Sortie : `tools/parity/out/apk/` (ou `$APK_PARITY_OUT`, gitignore) = `oracle-*.json` (traces),
`gd-*.json` (projections Godot), **`report.json`** et un tableau en console.
Le harnais ne corrige aucune regle : il rapporte (code de sortie 0 meme a 0 %).

## Fonctionnement

1. `dotnet run --project tools/apk-oracle -- --seed S --players N --out ...` pour chaque trace.
2. `ApkParity.tscn` (`apk_parity.gd` + `scripts/ApkParityTrace.gd`) monte une partie Godot avec
   **les memes bosses et les memes pioches** (cartes C# `BMA006` -> `cards.json` par `id`,
   chaque instance gardant l'id d'instance de l'oracle dans `_oid`), puis rejoue les actions et
   decisions de l'oracle **comme des coups Godot** (`buildRoom`, `activateRoom`, `playSpell`,
   `openingDiscard`, `resolveChoice`, `adventureNext`, `pass`...). L'IA Godot n'intervient jamais.
   Un coup absent de `legal_moves` est un **REFUS** (consigne dans `events`, le rejeu continue).
3. `apk.mjs` projette l'etat de l'oracle de la meme facon et compare aux points de controle.

Le rejeu ne recoit aucune aide de regles : Godot implemente la salle initiale (`Setup_b`, un `buildRoom` par joueur) comme l'APK ; un `buildRoom` qu'il ne propose pas est un REFUS. Le harnais ne fait que synchroniser les phases (voir « Conventions de rejeu »).

## Conditions initiales (posees par le harnais)

- Bosses : ceux de l'oracle. `pid` Godot = `playerId` - 1 ; les joueurs sont inseres par `PlayerId` croissant (comme `Match.new_match`), pas dans l'ordre des sieges de la trace : les effets sur « tous les joueurs » (Jeopardy) suivent `InGamePlayersPriorized`.
- Pioches : celles de l'oracle **apres la distribution d'ouverture** (champ `deckOrders` ajoute au
  step `Setup_a` de la trace, seul changement dans `tools/apk-oracle` : `AvoidMulliganCondition`
  remelange tout le paquet quand une main a >= 4 salles avancees ou >= 4 memes tresors, donc
  `initial` seul ne suffit pas). Sommet en premier cote oracle, inverse cote Godot (`pop_back`).
  Une seule pioche heros, dans l'ordre oracle (le port a deux pioches ordinaires/epiques).
- Mains d'ouverture : les `options` de la decision `discard` de l'oracle ; la defausse de 2 cartes
  est ensuite rejouee via `openingDiscard`.
- `Match._start_turn` est retenu (`ApkMatch`) jusqu'au step `BeginningOfTurn` de l'oracle.

## Points de controle et champs compares

Godot enchaine des phases en un seul coup (fin de BUILD -> leurre -> aventure ; fin d'aventure ->
tour suivant) alors que l'oracle expose chaque `NextStep`. Pour `turnstart` et `bait`, Godot
photographie donc son etat **au moment exact** (surcharges de `_start_turn` et `_init_adventure_phase`) ;
les autres points utilisent la projection prise apres le step oracle correspondant.

| Point (step oracle) | Champs compares |
|---|---|
| `setup` : derniere `discard` de `Setup_a` | `phase`, pioches/defausses, `players.*.hand`, `.spells` |
| `turnstart` : phase `BeginningOfTurn` | `phase`, `turn`, `town`, pioches/defausses, `players.*.{souls,wounds,hand,spells,dungeon,entrance}` |
| `build` : phase `BuildPhase_a` avec joueur actif | `phase`, `turn`, `active`, `players.*.{hand,spells,dungeon,pending}` |
| `bait` : phase `BaitPhase` | comme `turnstart` (apres leurre : `entrance` et `town` significatifs) |
| `adv` : phase `AdventurePhase_c` (une salle ou la sortie du heros) | `phase`, `hero.{card,hp}` du heros actif, `players.*.{souls,wounds}` |
| `over` : `EndOfGame` | `phase`, `winner`, `players.*.{souls,wounds}` |

Projection : `hand` = codes des salles en main (trie), `spells` = codes des sorts (trie),
`dungeon` = piles de salles non vides, fond -> entree, sommet de pile en premier,
`pending` = sommet encore face cachee, `entrance` = codes des heros (trie), `town` ordonne,
pioches = `heroes` (ordinaires + epiques), `rooms`, `spells`, `discardRooms`, `discardSpells`.
`souls`/`wounds` sont les totaux (`CardDB.total_souls/total_wounds` vs `Souls`/`Wounds` C#).
`active` n'est pas compare quand l'oracle repete le joueur apres une fenetre de sorts ou sa propre construction.

Conventions de rejeu (harnais seulement, aucune regle) :

- `Setup_c`/`BeginningOfTurn` : un joueur dont l'IA oracle n'a pas pose de salle initiale fait `passBuild` cote Godot ; un `ExtraBuildPhase` oracle sans `buildRoom` derriere ferme le tour supplementaire Godot (`forcedBuild`).
- `playRoomAbility` est **retenu** jusqu'au prochain step de phase avec ses decisions : l'oracle met la capacite en file et ne l'execute qu'au `NextStep` suivant, apres d'eventuelles actions de l'IA ; Godot l'applique tout de suite. Une activation devenue impossible (salle recouverte) est notee `FIZZLE` (exception C# loguee, rien ne s'execute).
- `HeroDiesInThisRoom` est execute par l'oracle un `NextStep` apres l'ajout de l'ame : `ApkMatch._hero_died_trigger` retient le declencheur jusqu'au step suivant.
- Les decisions de declencheurs arrivent dans le journal AVANT le step qui les execute : une decision sans choix Godot correspondant est retenue (2 steps de phase) puis rejouee des qu'un choix du bon joueur s'ouvre (`_late`).
- Les tirages « au hasard » (`forcedRandom`) ne proposent que les pertes a venir (`seq` >= step courant).

Une fenetre de pause d'aventure Godot (`post-damage`, `pre-exit`) = fenetre
de sorts de l'oracle, tous les joueurs « passent » ; un `spellBattleReady` fait passer le repondant
que Godot attend ; `AdventurePhase_c` = un `adventureNext`, sauf un step `detail.executed == false` (l'oracle sort de `NextStep()` sans phase quand un duel de sorts se termine, `GameBoard.cs:318`) qui n'est pas rejoue ; une `decision` oracle sans choix en attente
cote Godot est comptee dans `stats.decisionsSkipped` ; un choix Godot que l'oracle n'a pas resolu est
pris a l'option 0 (`AUTO-CHOICE`) pour ne pas figer la partie ; si Godot a deja fini le tour que l'oracle
deroule encore, plus aucun coup n'est joue (REFUS `Godot a deja termine ce tour`).

## Lire le rapport

`status` = `OK`, `REFUS@seq` ou `DIVERGE@seq` (le plus precoce des deux). Par trace :
`firstRefus`, `firstDivergence` (seq, phase, champ, valeur oracle, valeur Godot), `firstByField`
(premiere divergence de chaque groupe de champs sur toute la trace : sert a classer les causes, car
tout ce qui suit la premiere divergence est en cascade), `stats`, `matched/checks`.

## Limites assumees

- **Tirages au hasard** (Specter's Sanctum, `DiscardRandomCardFromHand`) : le harnais releve dans la trace les cartes qui
  quittent une main sans cause visible (`_involuntary_losses`) et les passe a Godot dans `G["forcedRandom"]`
  (crochet sans effet par defaut dans `RoomAbilities._discard_random_spell_from`). Succubus Spa (BMA012,
  `PickRandomCardFromHand`) et la defausse de salle de Torture Chamber (BMA038) ne sont pas implementees dans Godot.
- `_sync_build(-1)` (l'oracle a clos la construction) force des `passBuild` mais s'arrete des que Godot ouvre un tour de
  construction supplementaire (`forcedBuild`) ou change de tour : c'est alors l'oracle qui pilote.
- Les melanges de reconstitution (pioche vide) ne sont pas reproductibles ; aucune des traces par defaut n'en declenche.
- **Courses de l'IA oracle** (graines 4-7, non reproductibles par construction) : l'IA active une capacite de salle (Dracolich Lair, Torture Chamber, Jackpot Stash...), puis pose une salle ou joue une carte AVANT que la transaction ne s'execute (elle peut batir sur la salle qui va etre detruite, ou poser la carte qu'elle va defausser) ; l'APK finit par lever/ignorer l'exception. Godot reserve les activations au joueur actif et les applique tout de suite : s4-p2, s5-p2, s5-p3 (debut), s6-p3 et s7-p3 en dependent.
- Paquets `PlayerChoice` (bosses KSA003/006/007, sort KSA013 T.P.K., heros KSA014/KSA017) et `HiddenHeros` (heros BMH* : les regles Godot propres a un heros, ex. The Fool, sont indexees sur l'identifiant BMA) : mappes dans `cards.json` mais sans regles dans Godot ; non implementes volontairement.
- `chooseDraw` et `undoBuildRoom` n'apparaissent pas dans ces traces ; ils seraient un REFUS.
- Les decisions `resolveTarget` internes aux capacites (cibles d'IA) ne sont transmises que si Godot
  a un choix en attente correspondant ; l'appariement oracle->option est heuristique (`_refs`).
