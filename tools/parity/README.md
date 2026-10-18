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
python tools/parity/apk.py --skip-gen --ai-agreement           # + accord de l'IA Godot avec l'IA oracle par type de coup (voir « Accord de l'IA »)
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
- `playRoomAbility` est **retenu** jusqu'au prochain step de phase avec ses decisions : l'oracle met la capacite en file et ne l'execute qu'au `NextStep` suivant, apres d'eventuelles actions de l'IA ; Godot l'applique tout de suite. Trois cas :
  - **All-Seeing Eye (BMA025)** repondant a un sort n'est **jamais retenu** : `EnqueueAbilityTransaction` met la transaction du joueur du tour en tete et `OnAbilityApplyRequest` replace un Counterspell avant sa cible (`GameBoard.cs:1317-1332`, `:754-769`) ; la pile Godot rend cet ordre, mais seulement si l'Eye est applique pendant que le sort attend encore (les « pret » suivants le resolvent). Retenu, il arrivait apres la resolution du sort (s33-p2@37, s19-p4@359, s20-p4@368).
  - Activation **recouverte** par la construction suivante de la meme action IA : seules les capacites « Destroy this room » levent a l'execution (`GameBoard.DestroyRoom` : `Dungeon.First(slot => slot.TopRoom == room)`, `GameBoard.cs:838`, premier effet de BMA009/027/030/038/039) -> `FIZZLE` (exception C# loguee, rien ne s'execute). Dracolich Lair / Witch's Kitchen (BMA013/024) n'ont aucun effet lie a la position (`Ability.DoEffect` execute les effets dans l'ordre) : l'oracle les execute quand meme (defausse + pioche, s36-p4@357-364). Godot ne sait les appliquer que sur la salle du dessus : le harnais les rejoue juste AVANT la construction qui les recouvre (`_release_covered`), sauf si la carte construite est l'une de leurs cibles en main (cas `_stale_hand_targets`).
  - Sinon : applique au step de phase suivant, avant la fermeture de la fenetre (`_release_held`).
- `HeroDiesInThisRoom` est execute par l'oracle un `NextStep` apres l'ajout de l'ame : `ApkMatch._hero_died_trigger` retient le declencheur jusqu'au step suivant.
- Une **fenetre de sorts avant la revelation** (`buildWindow`) n'est close que par une decision de revelation : les decisions passives de Goblin Armory / Dizzygas Hallway (`Boss.GetPassiveDamage`, `@-`) ne la ferment pas (Jackpot Stash s'active apres elles, avant la revelation : s23-p2@330 ; sinon le niveau Gorgona se declenchait trop tot et tuait un heros de la ville).
- Photo `bait` : `_refresh_bait_snap` rafraichit aussi `souls`/`wounds`/`entrance` (une capacite de la fenetre, Zombie Prison, agit AVANT le leurre cote oracle alors que Godot a deja enchaine : s21-p4@518-527) ; la ville reste celle du leurre.
- `AdventurePhase_b` sans heros pour le joueur actif : le `pass` Godot est immediat, **sauf** si un SORT est joue avant le prochain `NextStep` execute (`_window_has_spell` -> `_pass_idle`, au step de phase suivant) : Trepidation sur un autre joueur depend du joueur actif (`SpellEffects._trepidation`, `stackActivePlayer == tid` retire le heros de la cible) et l'oracle garde le lanceur actif jusqu'a `AdventurePhase_a` (s35-p2@231-238). Sans sort, un heros ajoute par une capacite (Zombie Prison) ne doit pas entrer : `ChooseNextActiveHero` a deja designe personne (s24-p4@266-272).
- Auto-DONE de la construction (`_build_and_done`) : pas de `passBuild` si le meme joueur construit encore avant le prochain `NextStep` execute (`_builds_again`) : l'IA joue Motivation (BMA050) apres sa 1re construction puis pose la 2e (s30-p4@305-314).
- `_close_forced` (tour supplementaire sans construction) ne ferme pas le tour Godot quand l'oracle enchaine un autre `ExtraBuildPhase` du meme joueur (Construction Zone puis niveau King Croak, s38-p3@98-99).
- **Transaction annulee** (`CANCELED`) : deux capacites en file designent le MEME heros a leur mise en file (Seducia niveau 2 + Mimic Vault, s26-p2@124-127 ; Gorgona + Mimic Vault, s36-p3@186-190) ; la 1re execute `RemoveHeroFromGame`, qui retire aussi les transactions en file ciblant ce heros (`GameBoard.cs:743 RemovePendingTransactionsByTarget`). Godot ouvre le 2e choix apres le 1er : le harnais le ferme sans effet (`pick-hero` / `kill-hero` dont la cible oracle est deja a une entree). Classe : IA oracle (les deux IA choisissent la meme cible).
- Tirages « au hasard » (`_involuntary_losses`) : les cartes designees par les decisions des deux fenetres precedentes (un `NextStep` execute les transactions decidees avant lui) ne sont pas des pertes involontaires (Draculord vole BMA055 puis Specter's Sanctum defausse au hasard BMA052 : s31-p2@185-188).
- Les decisions de declencheurs arrivent dans le journal AVANT le step qui les execute : une decision sans choix Godot correspondant est retenue (2 steps de phase) puis rejouee des qu'un choix du bon joueur s'ouvre (`_late`).
- Diagnostic : `godot ... ApkParity.tscn -- --traces=<dossier> --only=s5-p2 --dbg=480-498` imprime l'etat Godot (phase, joueur, pv/salle du heros, effets, choix ouvert, entrees) apres chaque step oracle de la plage ; `forced=<carte>` / `window` indiquent un tour de construction force / une fenetre de sorts ouverte, `-- --dbglog=N` affiche N lignes du journal Godot (3 par defaut), le choix ouvert porte le nom du boss/salle qui l'a cree (`pick-hero[Seducia]`).
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

## Decisions oracle ignorees (`stats.decisionsSkipped`)

Le total ne dit pas *quelles* decisions sont ignorees : `stats.skippedBy` les ventile par classe `site:decision:tCible`
(`tCible` = rang du fournisseur de cible dans la capacite, `BaseTargetProvider.UniqueID`) et `apk.py` l'agrege dans `report.json`
(`skippedBy`, `decisionsSkipped`, `spellTargetUnmatched`) et l'imprime sous le tableau. Par classe : `n` (comptages, une decision retenue
puis re-tentee compte plusieurs fois), `distinct` (seq differents), `replayed` (retenues puis finalement rejouees : elles restent
comptees ignorees), `cards` (`carte@action oracle parente`, `-` = declencheur/phase), `ex` (3 exemples seq/phase/joueur/carte). Sites :
`noChoice-*` / `otherPlayer-*` (aucun choix Godot ouvert / choix d'un autre joueur ; `-dropped` abandonnee, `-late` retenue dans `_late`,
`-deferred` dans `_deferred`), `openingDiscardMismatch`, `otherCardChoice`, `implicitTargetNoOption`, `implicitTargetConsumed`.
`-- --skip-ex=N` (option de `apk_parity.gd`, pas de `apk.py`) releve jusqu'a N exemples par classe (diagnostic : tous les cas = 99999).
Le comptage ne change ni le rejeu ni la projection (traces `gd-*.json` identiques a la base, hors ces champs).

**Pourquoi tant de decisions ignorees** : `TracingAI` (IA) enregistre une decision `resolveTarget` pour **chaque** fournisseur de cible
de chaque capacite, y compris `ThisRoom`/`BossOwner` (`NeedPlayerIteraction == false`) et les cas a candidat unique ; un humain
(`HumanPlayerInteraction`, `tryToAutoresolveTargets = true`, `SingleTargetProvider.TryToAutoresolve`) ne voit jamais ces decisions.
Quand l'IA remplit les fournisseurs d'une capacite d'un coup, la decision du 1er porte toutes les cibles et celle du 2e est vide.

Classement (a) benin, (b) choix Godot manquant, (c) bogue/artefact oracle. Mesure : defaut = graines 1-3 x 2/3 joueurs (432) ;
« s3 » = graines 3, 11, 40 x 2/3 joueurs (2211, dont s11-p3 et s40-p3 qui divergent deja pour d'autres causes).

| Classe | defaut | s3,11,40 | Verdict | Preuve |
|---|---|---|---|---|
| BMA020 Monster's Ballroom, `noChoice-dropped:t1/t2` | 266 | 2006 | (c) | Degats passifs (`RoomDamageEqualToCount` = `IPassiveDamageCommand`) : `Boss.GetPassiveDamage` cree et resout une `AbilityTransaction` a chaque calcul de degats, donc des decisions sans action ni phase (`@-`), comme Goblin Armory/Dizzygas (BMA015/029, deja exclus du compteur). s3-p2 : 133 x 2 ; s3-p2@128-129 |
| Cible non interactive (`BossOwner`, `ThisRoom`, `AllBoss`, `BossOpponents`, `HeroInThisRoom`) | 77 | 99 | (a) | `NeedPlayerIteraction = false`, autoresolue pour un humain. s1-p2@78 (BMA030 `ThisRoom`/`BossOwner`), s1-p3@53 (BMA022), s1-p3@377-378 (BMA003 t2) |
| Selection vide (2e fournisseur d'une capacite) | 31 | 34 | (a) | La decision t1 porte les cibles des deux fournisseurs, t2 est `chosen: []` : s1-p2@79, @116, @197 (BMA030, BMA051, BMA032) |
| Cible portee par `playSpell` (parent `playSpell`) | 26 | 32 | (a) | `_spell` choisit la variante de `playSpell` dont la cible recouvre la decision (`_refs`/`_intersects`) ; `spellTargetUnmatched` = 0 sur le defaut. s1-p2@115 (BMA051). 1 non apparie : s11-p3 (trace deja en echec) |
| Cible portee par `activateRoom` (BMA032 / BMA028 `AnotherRoom`) | 15 | 13 | (a) | `_ability` lit la salle visee dans les decisions imbriquees (`args[1]`). s1-p2@196 |
| Candidat unique autoresolu cote Godot | 5 | 9 | (a) | `TryToAutoresolve` (`num <= TargetsAmount`) : BMA011 en 2 joueurs (un seul adversaire, s1-p2@15, s3-p2@8), BMA014 avec 1 blessure (s2-p2@145 : `players.wounds = 1`), BMA024 avec 1 salle Monster en main (s11-p2@61, @99). Godot fait de meme (`_witchs_kitchen`, `_vampire_bordello`, `_specters_sanctum`) |
| Retenues puis rejouees (`replayed`) | 5 | 1 | (a) | BMA010 Open Grave t1 (`recover-card`, appariement exact : s2-p2@166 `DBGM`), BMA003/BMA008 t1 (`otherPlayer-deferred`) : le choix est bien rejoue, seul le premier passage compte |
| `openingDiscard` de Setup_a d'un autre joueur (`otherPlayer-deferred:discard`) | 3 | 6 | (a) | Rejouee des que le choix de ce joueur s'ouvre (`replayed` = n). s1-p2@2 |
| Cibles main perimees BMA013/BMA024 (`STALE-TARGET`) | 0 | 11 | (c) | Course de l'IA oracle (activation en file, main modifiee avant l'execution) : s11-p3@314, @428, @456 (BMA013) et s11-p2@32 (BMA024) ; voir « Limites assumees » |
| Succubus Spa sur son propre boss (BMA012) | 4 | 0 | (c) | `chosen = [boss du joueur 1]` pour le proprietaire joueur 1 : s1-p3@60-61 (2 decisions, comptees 2 fois) |
| **Total** | **432** | **2211** | | (b) : **aucun cas** |

Aucune classe (b) (choix que l'APK propose a un humain et que Godot resout seul) n'est prouvee sur ces traces. Limite de la preuve :
(a) « cible non interactive » repose sur le rang `tCible` -> fournisseur lu dans `data.json` (ordre des `Targets` des `Effects`) ; les
classes `otherCardChoice` (8 comptages, 3 decisions) n'ont jamais ete rejouees : BMA019/BMA022/BMA007 sont `BossOwner` (benin), BMA011
(s40-p3@222, 3 joueurs, trace deja en echec) designait un adversaire que Godot resolvait seul (filtre sur les porteurs de sort, supprime : le choix est maintenant ouvert sur tous les adversaires vivants).
**Seuil** : BMA020 est sorti de `decisionsSkipped` (compte a part : `stats.passiveSkipped`, `report.passiveSkipped`), sans changer le rejeu ;
nouveaux totaux : defaut **166** (+266 passives), wide **443** (445 avant le correctif de Specter's Sanctum, BMA011, qui propose maintenant tous les adversaires vivants : s4-p3 seq 151 et s7-p4 seq 465 sont rejoues), decks **163** (+28 passives), graines 3/11/40 : 205 (+2006). `apk.py` marque une
trace `SKIP` (statut non OK, code de sortie 1, raison dans `skipIssues` et en console) si une classe `skippedBy` n'est pas dans `KNOWN_SKIP`
(liste codee dans `apk.py`, 13 classes mesurees sur defaut + wide + decks), si `openingDiscardMismatch` apparait, ou si `spellTargetUnmatched` > 0.
Pas de plafond numerique par classe. Classes connues : `noChoice-dropped:resolveTarget:t1|t2|t3`, `noChoice-late:resolveTarget:t1|t2`,
`otherPlayer-deferred:discard`, `otherPlayer-deferred:resolveTarget:t1|t2`, `otherPlayer-late:resolveTarget:t1|t2`,
`implicitTargetNoOption:resolveTarget:t1|t2`, `otherCardChoice:resolveTarget:t2` (cibles `BossOwner`, benignes : 19 comptages sur wide).
**En attente** : `otherCardChoice:resolveTarget:t1` (wide 17, decks 2 ; BMA036 / BMA037 interactifs, BMA011 pour les restes) est signale
(`skipWarnings`, avertissement console, `WARN_SKIP_KEYS` dans `apk.py`) mais ne fait pas echouer, tant que la classification n'est pas tranchee ;
l'exemption est PAR CLE : toute autre cle `otherCardChoice:*` fait echouer la trace.

## Accord de l'IA (`--ai-agreement`, lot 1.2)

```bash
python tools/parity/apk.py --skip-gen --ai-agreement     # sur des traces deja generees (APK_PARITY_OUT=<dossier avec oracle-*.json>)
godot ... ApkParity.tscn -- --traces=<dossier> --ai-agreement [--ai-ex=N]     # N exemples de desaccord par type et par trace (6 par defaut)
```

A chaque decision de l'IA oracle (`TracingAI`), le rejeu demande a l'IA Godot (`AI.gd` : `AI.pick_move`, `AI.score_move`, `AI.select_opening_discards`)
ce qu'elle jouerait sur **le meme etat Godot, juste avant que le harnais applique le coup oracle**, et compare. Sortie : `report.json`
(`aiAgreement` global et, par trace, dans `traces[*].aiAgreement`) et un tableau console. Mesure pure : les requetes ne modifient rien
(`hash(G)` avant/apres, compteur `mutations` = 0 ; `legal_moves` copie deja `G` pour tester les capacites), le rejeu ne depend jamais du resultat ;
`report.json`, `gd-*.json` (hors cle `aiAgreement`), statuts et projections sont **identiques** avec et sans l'option (verifie sur les 18 traces ;
duree du rejeu +15 % environ). Sans l'option : aucun appel a l'IA, comportement inchange.

**Definition de l'accord** (par type ; « meme carte » = meme code, une autre copie ne compte pas comme desaccord ; le departage de Godot est celui de
`pick_move` : premier meilleur score) :

| Type | Point de mesure (harnais) | Accord si |
|---|---|---|
| `build` | `buildRoom` oracle, avant la pose | le meilleur `buildRoom` de Godot est la meme carte **et** le meme emplacement (pile recouverte, ou « nouvelle pile ») |
| `buildCard` | idem | la meme carte (emplacement ignore) |
| `buildSlot` | idem | etant donnee la carte de l'oracle, Godot choisit le meme emplacement parmi les coups de cette carte |
| `discard` | defausse d'ouverture (`Setup_a`) | `select_opening_discards` rend le meme multiensemble de 2 codes |
| `spell` | `playSpell` oracle | decision « capacite » = tous les coups legaux sauf construire, plus « ne rien faire » (`passBuild`/`pass`/`adventureNext`) : le meilleur est un `playSpell` du meme sort ; si Godot ne jouerait rien ou autre chose : desaccord |
| `spellTarget` | idem, cible oracle connue (decisions imbriquees) | parmi les variantes de `playSpell` de ce sort, la meilleure designe une instance cible de l'oracle (`_refs`) |
| `activate` | `playRoomAbility` oracle | meme decision « capacite » : le meilleur est un `activateRoom` de la meme salle (le 2e argument de BMA028/032 n'est pas compare) |
| `target` | choix Godot ouvert, avant `resolveChoice` | meme indice, ou option equivalente (memes codes de cartes designees, meme joueur proprietaire, meme pile) ; l'option « passer » (-1) et les options non appariees ne comptent pas |
| `draw` | `chooseDraw` (Haunted Library) | meme pile (salles / sorts) |
| `pass` | `passBuild`/`pass` rejoue par le harnais parce que l'IA oracle n'a rien joue (salle initiale, tour de construction, tour supplementaire, repondant de Spell Battle) | `AI.pick_move` ne propose aucun coup actif (null, `passBuild`, `pass`, `adventureNext`) ; sous-classes `pass:setup|build|extra|respond`, et `passAlt:*` = ce que Godot jouerait a la place |

Colonnes : `n`, `agree`, `%` ; `forces` = un seul candidat distinct (accord automatique) ; `n>=2 cand.` = decisions avec au moins 2 candidats distincts
(le vrai taux de decision) ; `indiff.` = desaccords ou le coup oracle a **le meme score** que le choix Godot (l'IA Godot ne les distingue pas et prend le
premier). Un coup requete indisponible (aucun coup legal, choix deja ferme) va dans `unavailable`, hors `n`. Les repondants de Spell Battle dont le
joueur n'est pas celui que Godot attend ne sont pas comparables (`unavailable.pass:respond-order`) ; aucun cas sur les 18 traces.

**Nature de la mesure** : l'IA oracle n'est **pas** deterministe. `StatisticAI.RandomSelection` tire carte, emplacement, defausse, capacite et type de
pioche au sort selon des probabilites (`NormalizeValues` : valeurs moins le minimum, normalisees). Un accord « argmax Godot = tirage oracle » plafonne donc
bien sous 100 % pour `build`, `buildCard`, `buildSlot`, `discard`, `spell`, `activate`, `draw`. Une partie des cibles est aussi tiree (`Shuffle()` :
`TriggerCalculator.cs` 363/401/615/621/643, `AbilityCalculator.cs` 485/864/969 ; cartes piochees dans une defausse, sort au hasard...), ce qui borne `target`
(typiquement `recover-card`).
La trace ne porte pas les probabilites de l'oracle ; une mesure plus fine (probabilite attribuee au coup tire) demanderait de les y ajouter
(`TracingAI.cs`), non fait.

**Mesure initiale** (18 traces : defaut graines 1-3 x 2/3 joueurs + wide graines 4-7 x 2/3/4 joueurs, `BaseDeck`, 6/6 et 12/12 inchanges ; `AI.gd` non modifie) :

| Type | n | accord | % | forces | n>=2 cand. | accord | % | indiff. |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| build (carte + emplacement) | 444 | 306 | 68,9 | 19 | 425 | 287 | 67,5 | 33 |
| buildCard (carte seule) | 444 | 327 | 73,6 | 80 | 364 | 247 | 67,9 | 13 |
| buildSlot (emplacement, carte oracle) | 444 | 412 | 92,8 | 134 | 310 | 278 | 89,7 | 29 |
| discard (ouverture) | 51 | 4 | 7,8 | 0 | 51 | 4 | 7,8 | 0 |
| spell (jouer tel sort ou passer) | 102 | 85 | 83,3 | 0 | 102 | 85 | 83,3 | 2 |
| spellTarget (cible oracle) | 102 | 37 | 36,3 | 26 | 76 | 22 | 28,9 | 54 |
| activate (capacite de salle) | 142 | 70 | 49,3 | 0 | 142 | 70 | 49,3 | 11 |
| target (option d'un choix ouvert) | 210 | 82 | 39,0 | 10 | 200 | 72 | 36,0 | 126 |
| draw | 0 | 0 | - | 0 | 0 | 0 | - | 0 |
| pass (l'oracle ne joue rien) | 214 | 158 | 73,8 | 58 | 156 | 100 | 64,1 | 0 |

`draw` : `chooseDraw` n'apparait dans aucune de ces traces (BMA023 jamais distribuee, voir « Limites assumees ») ; chemin mesure mais non exerce. Defausses
forcees hors ouverture : l'oracle n'en trace aucune (`discard` n'existe qu'en `Setup_a`) ; celles des capacites passent par `resolveTarget` donc par `target`
(ex. `discard-spell[Dark Laboratory]`).

Desaccords les plus frequents (sous-classe `type:carte` ou `target:type de choix[boss]`, desaccords/n sur les 18 traces) : `target:recover-card[Dracolich
Lair]` 32/38 et `[Dark Altar]` 18/19, `target:dracolich-discard` 20/38 (beaucoup d'indifferences : `_score_choice` rend 0 pour ces choix) ; `spellTarget`
BMA046 25/25, BMA047 7/7, BMA042 7/8 (Godot prend la premiere variante de cible, score identique) ; `activate:BMA013` 24/42, `BMA032` 16/29, `BMA009` 11/19
(Godot prefere un sort a score fixe 20 ou toute capacite a score 5 par defaut) ; `pass:build` 30/34 (l'oracle ne construit pas, Godot construirait 20 fois,
surtout BMA034/035/037 ; cause a instruire : position nulle, `CanBuildRoom` ou valeur nulle cote C#, ou activerait une capacite) ; `pass:respond` 25/179 (Godot contre-sortirait avec
BMA043 ou activerait All-Seeing Eye BMA025 la ou l'IA oracle laisse passer) ; `discard` 47/51 (sur les exemples, Godot defausse les sorts, l'oracle des salles).

Limites de la mesure : (1) les types sont evalues isolement (`build` parmi les `buildRoom`, `spell`/`activate` parmi les coups sans construction) :
l'ordre entre construire et jouer un sort, que l'oracle fixe en une liste (`AIPlayerInteraction.InternalDoPlayerActions`), n'est pas mesure ;
(2) les joueurs du harnais ne sont pas `isAI` : `legal_moves` est celui d'un humain (un siege IA du vrai jeu n'ouvre pas de Spell Battle hors de son tour, alors
que l'IA oracle consulte ses capacites a chaque fenetre) ; (3) l'etat est celui du rejeu : sort deja mis sur la pile ou capacite retenue avant une
construction (`_held`, `_held_pass`) peuvent differer legerement de celui que l'oracle a vu en precalculant sa liste ; (4) la main d'ouverture est dans l'ordre
des `options` oracle ; (5) non mesures : fenetres d'aventure (`_settle`) et de revelation (`_close_window`), cibles de `playRoomAbility` imbriquees
(BMA028/032 2e salle), `rearrange-dungeon` (KSA002), 2e carte de `recover-card` (Xyzax), cartes wiki.

## Limites assumees

- **Tirages au hasard** (Specter's Sanctum, Torture Chamber, Succubus Spa) : le harnais releve dans la trace les cartes qui
  quittent une main — ou changent de main — sans cause visible (`_involuntary_losses`) et les passe a Godot dans `G["forcedRandom"]`
  (crochet sans effet par defaut dans `RoomAbilities._discard_random_from` / `steal_random_card`). Pour Succubus Spa, l'absence de carte
  forcee = aucune carte n'a bouge (l'IA oracle a parfois designe son propre boss : transaction sans effet net) : pas de vol.
- `_sync_build(-1)` (l'oracle a clos la construction) force des `passBuild` mais s'arrete des que Godot ouvre un tour de
  construction supplementaire (`forcedBuild`) ou change de tour : c'est alors l'oracle qui pilote.
- Les melanges de reconstitution (pioche vide) ne sont pas reproductibles : l'ordre tire est inconnu du harnais, et `GameBoard.ReShuffleDiscardsPilesBackToDeck`
  remet les DEUX defausses (salles ET sorts) dans leurs pioches a la fois ; Godot fait pareil (`CardDB.draw_pile`, pioche de tour et pioches d'effet). Aucune
  des traces par defaut n'en declenche ; s16-p4@593 (Recycling Center sur pioche vide) reste en echec : cartes piochees au hasard, et la salle detruite
  entre dans la defausse AVANT le declencheur cote APK (transaction mise en file) alors que Godot pioche avant que l'appelant la defausse (1 carte d'ecart de pioche).
- **Courses et bogues de l'IA oracle** (pas des regles : un humain attend la fin de la Spell Battle) : l'IA enchaine, dans une seule liste d'actions
  precalculee (`AIPlayerInteraction.InternalDoPlayerActions`), une capacite/un sort PUIS une construction. `GameBoard.EnqueueAbilityTransaction`
  met l'effet en file ; il ne s'execute qu'au `NextStep` suivant (`GameBoard.NextStep`, `PendingAbilityTransactions`), apres la construction.
  Le harnais le reproduit (Godot applique tout de suite) : activation retenue (`_held`), cibles devenues absentes de la main
  (`_stale_hand_targets` : Dracolich Lair / Witch's Kitchen, defausse partielle puis exception C#), derniere « passe » d'un sort du
  constructeur retenue (`_held_pass` : Jeopardy joue puis salle posee sur l'ANCIENNE main). Autres bogues de l'IA (cibles invalides) : Mimic Vault /
  Open Grave avortes (`_abort_trigger`, `TriggerCalculator` renvoie des cibles deja calculees), Succubus Spa sur son propre boss, decisions de
  Goblin Armory / Dizzygas Hallway ignorees (`Boss.GetPassiveDamage` « resout » une transaction a chaque calcul de degats). **Non reproduit** :
  s5-p2@498 (Giant Size lance par l'IA sur une salle PIEGE, `AbilityCalculator.CheckBMA040And047` mele Trap/Monster ; le C# ne valide pas le type
  a l'execution, Godot le refuse) ; fenetres `AdventurePhase_a/b` sans heros actif, qu'il s'agisse d'un tour sans heros ou de la fenetre APRES la sortie du dernier
  heros (s20-p2@677, s28-p3@329 : Dracolich Lair active apres le dernier heros, partie deja close a 10 ames cote Godot) : Godot enchaine
  le tour, l'IA oracle y active des capacites (REFUS « Godot a deja termine ce tour » / `activateRoom` absent de `legal_moves`). Un humain n'y a PAS de
  fenetre : `GameBoard.IsAdventureInteractionTurn` exige `ActiveHero != null` et `GamePlayBaseScene.CreateWaitAndMoveHeroToNextSlotTask`
  n'ouvre la barre de temps qu'avec un heros actif ; `CheckEndOfGame` ne tourne qu'en `EndOfTurnPhase` (Godot : `_check_end_or_next_turn`
  seulement quand l'aventure est finie, donc pas d'arret premature a 10 ames).
- **Graines 10-40 (hors du rapport par defaut)** : `apk.py --seeds 10 ... 40 --players 2 3 4` (93 traces) rejoue a **90/93** (76/93 avant la passe l11d, 69/93 avant l11c, 30/93 deux passes plus tot ; `--skip-gen` rejoue les traces deja generees d'un dossier copie). Corriges en l11c : Jeopardy / Kobold Strike / Centipede Tunnel / Kaw'nee ignorent les joueurs elimines
  (`InGamePlayersPriorized`), un Liger's Den par salle, pioche vide = remelange des deux defausses (`CardDB.draw_pile`), Bottomless Pit / Cave-In
  (`KillHero` / `KillHeroInRoom`) ne levent aucun declencheur de mort, destruction de la salle du heros au slot C# 4 sans pas « vide »,
  un heros ajoute a un joueur deja passe (Zombie Prison) attend le tour suivant (une seule ronde). Corriges en l11d (14 traces) :
  harnais (All-Seeing Eye immediat : s19-p4, s20-p4, s33-p2 ; fenetre de revelation non close par les passives : s23-p2 ; auto-DONE : s30-p4 ; `pass` differe : s35-p2 ; capacite recouverte : s36-p4 ; photo bait : s21-p4 ; `CANCELED` : s26-p2, s36-p3 ; `ExtraBuildPhase` enchaines : s38-p3 ; pertes au hasard : s31-p2) et **deux regles du moteur**
  prouvees par le C# : `Hero.NearestBossSlotIndex` est un entier stocke que la destruction d'un slot ne change pas (en index Godot il baisse de 1, `BossEngine.destroy_room` ; Minotaur's Maze apres Crushinator, s21-p2@518, golden `_t_maze_after_destroyed_nearer_room`) ;
  `SendBackToDungeonEntrance.Execute` fait `RestoreHealth()` (`DBMGameModel.Logic.Abilities.Commands/SendBackToDungeonEntrance.cs:62`) : Zombie Prison / Zombie Attack renvoient un heros mort a ses PV de BASE, +2 pour Zombie Attack seulement (`BossEngine.hero_base_hp`, s27-p3@562, golden `_t_zombie_restores_base_hp`).
  **Restent en echec (3), tous classes bogue / course de l'IA oracle ou remelange non reproductible** — trace — cause — classe — preuve :
  - **s16-p4** — Recycling Center (BMA031#96) declenche par la destruction de BMA021#74 (Crushinator BMA032#99, seq 582-589) sur pioche de salles VIDE : `ReShuffleDiscardsPilesBackToDeck` (`GameBoard.cs:1335-1347`, `Shuffle()` aleatoire dont l'ordre n'est pas dans la trace) — remelange non reproductible — seq 593 pioche 19 / defausse 0 (oracle) contre 18 / 1 (Godot), puis REFUS seq 609 `buildRoom(BMA030)` « carte absente de la main » (carte tiree du paquet remelange). Ecart d'ordre residuel du moteur : `DestroyRoom` defausse la salle AVANT le declencheur (`GameBoard.cs:840-851`), `BossEngine.destroy_room` declenche avant que l'appelant ne defausse ; invisible hors pioche vide (1 carte), non corrige car le remelange rend la trace non rejouable de toute facon.
  - **s20-p2** — seq 677 : l'IA oracle active Dracolich Lair (BMA013#33, tour 4) dans la fenetre `AdventurePhase_a` APRES la sortie du dernier heros de son donjon ; Godot a deja enchaine le tour suivant (REFUS « Godot a deja termine ce tour », puis `decks.discardRooms` 6/5 a seq 686) — course de l'IA oracle (fenetre sans heros actif) — `GameBoard.IsAdventureInteractionTurn` exige `ActiveHero != null` (`GameBoard.cs:285-291`), `GamePlayBaseScene.CreateWaitAndMoveHeroToNextSlotTask` (`:924`) n'ouvre la barre de temps qu'avec un heros actif : un humain n'a pas cette fenetre ; `CheckEndOfGame` ne tourne qu'en `EndOfTurnPhase` (`GameBoard.cs:448`).
  - **s28-p3** — seq 329 : meme cause (Dracolich Lair BMA013 de P3 activee apres le dernier heros, partie deja close a 10 ames cote Godot : REFUS `activateRoom(BMA013)`, `godotPhase=end`) ; les 114 points de controle d'etat concordent, seul le REFUS fait echouer la trace — course de l'IA oracle, memes preuves.
  Regle appliquee a l'interface HUMAINE (pas au moteur) : `GameBoard` accepte ces actions (l'IA les joue via `DoPlayerActions`) mais `IsAdventureInteractionTurn` exige `ActiveHero != null` (`GameBoard.cs:285-293` ; `CardManagerComponent.RefreshCardsStatus:162`, `HumanPlayerInteraction:140`). `Match.legal_moves` reste donc inchange (IA Godot et rejeu de l'oracle : s20-p2 et s28-p3 restent des REFUS d'IA oracle) ; `BoardUI._my_moves` retire sorts, capacites de salle, `useHandRoom` et extras TNL/RMB des coups du joueur humain en aventure quand `Match.apk_active_hero()` est faux (ni heros actif, ni heros designe a l'entree du joueur actif, ni Spell Battle ouverte) : cartes grisees, pas de fenetre chronometree, pas de clic d'activation. Le heros retire de l'entree par Trepidation (fenetre pre-aventure de sa cible) reste « actif » pour l'APK jusqu'a `ProccessActiveHero` : `SpellEffects._trepidation` pose `G.apkSkippedHero` (efface a `_advance_adventure_player` / `_init_adventure_phase`), la fenetre reste donc ouverte (s36-p4@321-328). Goldens `_t_apk_active_hero_ui_gate` ; `ui_smoke.gd` compare l'interface a `board._my_moves`.
- Paquets supplementaires : voir « Paquets supplementaires ». Les traces `--decks` heritent des echecs du jeu de base (memes cartes de base), qui dominent le bruit : pour savoir si un echec releve d'un paquet, chercher le dernier evenement KSA/BMH (niveau gagne, T.P.K. joue, heros KSA a l'entree) avant la premiere divergence.
- `chooseDraw` (Haunted Library, BMA023) est rejoue par le harnais (choix Godot `draw-type`) mais ne figure dans aucune trace des graines 1-80 (BMA023 et BMA033 ne sont jamais distribuees : `CardInfoService.notInGameCards`, ecartees des pioches de `new_match`) : le chemin n'est couvert que par un golden. `undoBuildRoom` n'apparait pas non plus ; il serait un REFUS.
- Les decisions `resolveTarget` internes aux capacites (cibles d'IA) ne sont transmises que si Godot
  a un choix en attente correspondant ; l'appariement oracle->option est heuristique (`_refs`).
