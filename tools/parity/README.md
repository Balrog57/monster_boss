# Harnais de parite Godot <-> APK

Le seul harnais de parite est `apk.py` : il compare le port Godot (`src/frontend/godot/`) a l'APK d'origine
(oracle .NET `tools/apk-oracle`). L'ancien harnais JS <-> GDScript a ete supprime avec le code JS.
Fichiers Godot associes : `src/frontend/godot/tests/apk_parity.gd` + `ApkParity.tscn`, `scripts/ApkParityTrace.gd`.

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
  boss le plus fort construit donc en premier. (ancien moteur JS : meme ordre).
- **`ExtraBuildPhase`** est declenche par `PendingExtraBuiltTurns` en
  `BeginningOfTurn` ou `BaitPhase`.
- **Aucune salle initiale.** `InternalInititalizeGameBoard` ne construit que les
  quatre pioches. Le premier coup `buildInitialRoom` du JS et du port est donc
  **inventé** : dans l'APK la premiere salle se pose en `BuildPhase_a` comme
  n'importe quelle autre, et se revele en `BuildPhase_b`.

---

# Parite Godot <-> APK ORIGINALE (`python tools/parity/apk.py`)

`tools/apk-oracle` fait jouer `DBMGame.dll` 2.2.6
(IA originale contre IA originale) et trace chaque phase, action et decision.

```bash
python tools/parity/apk.py                                     # graines 1-3 x 2 et 3 joueurs (BaseDeck), ~15 s : doit rester 6/6 OK
python tools/parity/apk.py --seeds 4 5 6 7 --players 2 3 4     # « wide » : 12/12
python tools/parity/apk.py --decks BaseDeck,PlayerChoice,HiddenHeros,ToolsHeroKind   # 6/6 ; un paquet a la fois : voir « Paquets supplementaires »
python tools/parity/apk.py --skip-gen                          # rejoue les traces deja generees
GODOT=<exe> python tools/parity/apk.py                         # sinon tools/godot_exe.py : C:/Tools/Godot/...console.exe, puis `godot`
APK_PARITY_OUT=<dossier> python tools/parity/apk.py            # dossier de sortie dedie
```

**Local uniquement, pas en CI** : l'oracle exige `DBMGame.dll` (dans `apk-original/`, non versionne) et le SDK .NET.
Ne jamais lancer deux rejeux en parallele (un seul Godot a la fois) ; chaque run efface son dossier de sortie, donc un `APK_PARITY_OUT` distinct par run.

Sortie : `tools/parity/out/apk/` (ou `$APK_PARITY_OUT`, gitignore) = `oracle-*.json` (traces),
`gd-*.json` (projections Godot), **`report.json`** et un tableau en console.
Le harnais ne corrige aucune regle : il rapporte. Code de sortie 1 des qu'une trace n'est pas `OK` (ou si le rejeu Godot echoue), 0 sinon.

## Fonctionnement

1. `dotnet run --project tools/apk-oracle -- --seed S --players N --out ...` pour chaque trace.
2. `ApkParity.tscn` (`apk_parity.gd` + `scripts/ApkParityTrace.gd`) monte une partie Godot avec
   **les memes bosses et les memes pioches** (cartes C# `BMA006` -> `cards.json` par `id`,
   chaque instance gardant l'id d'instance de l'oracle dans `_oid`), puis rejoue les actions et
   decisions de l'oracle **comme des coups Godot** (`buildRoom`, `activateRoom`, `playSpell`,
   `openingDiscard`, `resolveChoice`, `adventureNext`, `pass`...). L'IA Godot n'intervient jamais.
   Un coup absent de `legal_moves` est un **REFUS** (consigne dans `events`, le rejeu continue).
3. `apk.py` projette l'etat de l'oracle de la meme facon et compare aux points de controle.

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

## Paquets supplementaires (`--decks`)

`--decks` est passe tel quel a l'oracle (`GameDecks` : `BaseDeck`, `PlayerChoice`, `HiddenHeros`, `ToolsHeroKind`). Le moteur Godot les nomme par
`set` dans `cards.json` : `players-choice` (KSA, 11 cartes), `hidden-heroes` (BMH, 41 heros), `tools` (THK, 25 cartes) ; le jeu de base est toujours
present (`GamePlayBaseScene` : `cardDecks = { BaseDeck } + extensions`), les autres se combinent librement (`ExpansionScene`).

- **PlayerChoice** : 7 bosses, 3 heros epiques, T.P.K. Les capacites sont lues dans `cards.json` (`levelUp`, `ability`, `heroAbility`, extraits de
  `data.json`), pas par id. Level-ups passifs (`IsLevelUpUnlocked`) : KSA001 `AddTreasuresToDungeon` (`BossEngine.dungeon_treasures`), KSA005
  `LastRoomDealDamage` (`room_damage_with_modifiers`), KSA006 `AddSoulsToBoss` (`CardDB.passive_souls`) ; KSA007 `MultiplyTreasuresDungeon` ; avec
  choix : KSA002 `RearrangeDungeon` (`rearrange-dungeon`), KSA003 `PutCardInHand` (`search-spell`), KSA004 `PlaceAtScorekeep` (`steal-hero`). Heros :
  KSA014 `LuredByWounds`, KSA016 `HeroResistDamageRoomType`, KSA017 `DeactivateDungeonAbility` (`BossEngine.abilities_locked`).
  **T.P.K.** (`IUntilEndOfGameCommand`) quitte la defausse pour rester chez le lanceur ; la condition (les 4 classes face cachee) se lit sur le
  scorekeeping de la **cible** choisie. Un humain n'a que lui-meme (`BossOwner`) ; l'IA de l'oracle (`AbilityCalculator.CheckKSA013`) designe tous les
  joueurs et `SetTarget` garde le premier (le boss de plus haute XP) : le harnais ouvre ce choix (`G.aiTargetsAllBosses`) pour rejouer l'oracle.
- **HiddenHeros** : les 41 BMH ont `ReplacesCardNumber` = BMA056-096 (memes stats). `GetCardInfoFromDeck` ecarte donc les BMA : aucune regle propre, les
  regles de heros se lisent sur `lure` / `treasures` (`CardDB.hero_lure`), plus sur l'id (`BossEngine.lure_target` etait cable sur BMA080).
- **ToolsHeroKind** n'est **pas jouable dans l'APK 2.2.6** : `CardInfoService.GetAvailableDecks` l'exclut (comme `PowerUpPack`), le magasin l'affiche
  « COMING SOON », son `data.json` n'a aucune capacite (salles, sort et objets : `null`), pas de `ai_info.json` (l'IA leve des qu'une salle THK est
  en main) et `FlipItem.Execute` leve `NotImplementedException`. Le moteur ne fait que `RevealItems` (1 objet par tour, 2 a 4 joueurs, vers
  `RevealedItemsQueue`). L'oracle le charge par reflexion avec des infos IA vides (`tools/apk-oracle/Program.cs`) pour verifier que les regles se
  reduisent a cela : objets inertes, salles ordinaires, THK025 injouable. Godot : `G.decks.items` + `G.itemQueue` (`Match._reveal_items`),
  la case a cocher est grisee dans le menu.

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
- Diagnostic : `godot ... ApkParity.tscn -- --traces=<dossier> --only=s5-p2 --dbg=480-498` imprime l'etat Godot (phase, joueur, pv/salle du heros, effets, choix ouvert, entrees) apres chaque step oracle de la plage.
- Un choix Godot dont le `bossName` est celui d'une AUTRE carte que le proprietaire de la decision oracle (Monstrous Monument + King Croak, meme carte visee) fait attendre la decision (`_late`).
- Controles non comparables (`apk.py`) : `build` au `NextStep executed:false` qui clot la construction (Godot a deja enchaine revelation/leurre/aventure), `adv` quand Godot est deja `over` ou que l'oracle a un heros a hp <= 0 en attente de `ProccessActiveHero` (Godot le retire et compte l'ame tout de suite).
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

- **Tirages au hasard** (Specter's Sanctum, Torture Chamber, Succubus Spa) : le harnais releve dans la trace les cartes qui
  quittent une main — ou changent de main — sans cause visible (`_involuntary_losses`) et les passe a Godot dans `G["forcedRandom"]`
  (crochet sans effet par defaut dans `RoomAbilities._discard_random_from` / `steal_random_card`). Pour Succubus Spa, l'absence de carte
  forcee = aucune carte n'a bouge (l'IA oracle a parfois designe son propre boss : transaction sans effet net) : pas de vol.
- `_sync_build(-1)` (l'oracle a clos la construction) force des `passBuild` mais s'arrete des que Godot ouvre un tour de
  construction supplementaire (`forcedBuild`) ou change de tour : c'est alors l'oracle qui pilote.
- Les melanges de reconstitution (pioche vide) ne sont pas reproductibles ; aucune des traces par defaut n'en declenche.
- **Courses et bogues de l'IA oracle** (pas des regles : un humain attend la fin de la Spell Battle) : l'IA enchaine, dans une seule liste d'actions
  precalculee (`AIPlayerInteraction.InternalDoPlayerActions`), une capacite/un sort PUIS une construction. `GameBoard.EnqueueAbilityTransaction`
  met l'effet en file ; il ne s'execute qu'au `NextStep` suivant (`GameBoard.NextStep`, `PendingAbilityTransactions`), apres la construction.
  Le harnais le reproduit (Godot applique tout de suite) : activation retenue (`_held`), cibles devenues absentes de la main
  (`_stale_hand_targets` : Dracolich Lair / Witch's Kitchen, defausse partielle puis exception C#), derniere « passe » d'un sort du
  constructeur retenue (`_held_pass` : Jeopardy joue puis salle posee sur l'ANCIENNE main). Autres bogues de l'IA (cibles invalides) : Mimic Vault /
  Open Grave avortes (`_abort_trigger`, `TriggerCalculator` renvoie des cibles deja calculees), Succubus Spa sur son propre boss, decisions de
  Goblin Armory / Dizzygas Hallway ignorees (`Boss.GetPassiveDamage` « resout » une transaction a chaque calcul de degats). **Non reproduit** :
  s5-p2@498 (Giant Size lance par l'IA sur une salle PIEGE, `AbilityCalculator.CheckBMA040And047` mele Trap/Monster ; le C# ne valide pas le type
  a l'execution, Godot le refuse) ; fenetres `AdventurePhase_a/b` d'un tour sans heros (Godot enchaine le tour, l'IA oracle y active des capacites :
  REFUS « Godot a deja termine ce tour »).
- **Graines 10-40 (hors du rapport par defaut)** : `apk.py --seeds 10 ... 40 --players 2 3 4` (93 traces) rejoue a 59/93 apres les correctifs de cette passe
  (30/93 avant) ; le reste est du meme ordre (courses ci-dessus, tour sans heros, etc.), non classe en detail.
- Paquets supplementaires : voir « Paquets supplementaires ». Les traces `--decks` heritent des echecs du jeu de base (memes cartes de base), qui dominent le bruit : pour savoir si un echec releve d'un paquet, chercher le dernier evenement KSA/BMH (niveau gagne, T.P.K. joue, heros KSA a l'entree) avant la premiere divergence.
- `chooseDraw` (Haunted Library, BMA023) est rejoue par le harnais (choix Godot `draw-type`) mais ne figure dans aucune trace des graines 1-80 (l'IA oracle ne construit jamais BMA023) : le chemin n'est couvert que par un golden. `undoBuildRoom` n'apparait pas non plus ; il serait un REFUS.
- Les decisions `resolveTarget` internes aux capacites (cibles d'IA) ne sont transmises que si Godot
  a un choix en attente correspondant ; l'appariement oracle->option est heuristique (`_refs`).
