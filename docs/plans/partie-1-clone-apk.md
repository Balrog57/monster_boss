# Partie 1 — Clone exact de l'APK

> Prérequis : lire [`docs/plans/README.md`](README.md) (rôles, sources de vérité, commandes, règles, conventions de chemins `GODOT/`, `ASSETS/`, `CS/`) et [`docs/HANDOFF.md`](../HANDOFF.md) (état de référence). Dans ce brief : `GODOT/` = `src/frontend/godot/`, `ASSETS/` = `src/frontend/assets/`, `CS/` = `apk-original/decompiled/DBMGame/`.

## Rôles (rappel ; détail dans le README §3)

L'IA qui reçoit ce brief est **orchestrateur seulement** : elle décide, dispatche, vérifie (tests, parité, git), commite, et **n'édite aucun fichier du dépôt**. **Sonnet** (`model: sonnet`) écrit tout le code et toutes les docs, avec périmètre de fichiers étroit, sans git, `python tools/run_godot_tests.py` vert deux fois, et la question finale « qu'est-ce qui diffère encore ? ». **Haiku** (`model: haiku`) explore, indexe, compare (≤ 30 images par agent) et rend des tableaux ; il ne modifie rien.

## Objectif

Le jeu Godot (web) se **comporte, s'affiche, s'anime, sonne et « réfléchit »** comme l'APK Android 2.2.6, hors boutique (remplacée par l'écran RULES, déjà fait) et hors multijoueur en ligne (partie 3). Les joueurs 3-4 restent gratuits (décision de l'utilisateur). **Règle de conflit : l'APK gagne sur le livret de règles** ; le livret ne s'applique qu'aux cartes wiki (partie 2).

## État de départ (vérifié le 2026-10-18)

- Décompilation complète au niveau assemblage : 27/27 DLL, 0 marqueur d'échec ILSpy, 4915 `.cs`, index `apk-original/decompiled/INDEX.md`. 560 `.cs` pour `DBMGame.dll` (`CS/`). Reste à **prouver que rien d'utile ne manque**.
- Parité 6/6, 12/12, 6/6 ; tests 14/14. Écarts connus : `docs/HANDOFF.md` §7, `tools/parity/README.md` section « Limites assumees », `docs/RAPPORT_REGLES.md` (§3 « Limites connues » ; le rapport est en partie périmé : il compare aussi à un ancien JS supprimé).
- Trous jamais mesurés : IA, animations, audio, 22 `throw new NotImplementedException()` dans `CS/`, `stats.decisionsSkipped` élevé dans des traces « OK » (288 sur `s3-p2`, 45 sur `s1-p3`), graines 10-40 à 59/93.
- Les sorties `apk-original/*` sont **gitignorées** (sauf `apk-original/README.md`) : les livrables de lecture du C# qui doivent survivre vont dans `apk-original/README.md` ou dans le dépôt (docs/tools), jamais ailleurs sous `apk-original/`.

---

## Lot 1.0 — Clôturer l'audit de décompilation

**Objectif** : prouver que la décompilation ne cache rien d'utile, et nettoyer le dépôt de ce que l'audit rend inutile.

**Sources** : `apk-original/decompiled/INDEX.md` ; `apk-original/decompiled/evidence/managed_members_DBMGame.json` ; `CS/` ; `apk-original/apktool-decoded/smali/` ; `apk-original/boss-monster-2-2-6/assets/Content/`.

**Qui fait quoi**
- **Haiku 1** : confronter les 918 TypeDefs de `DBMGame.dll` (`apk-original/decompiled/evidence/managed_members_DBMGame.json`) aux 560 `.cs` de `CS/` ; lister tout type non généré par le compilateur qui n'a pas de fichier.
- **Haiku 2** : les 22 `throw new NotImplementedException()` de `CS/` (ex. `CS/DBMGameModel.Logic.Abilities.Commands/BuildRoomBy.cs:45`, `.../KillHero.cs:33` ; aussi `ChooseAndDestroyRoom`, `ChooseCardFromHand`, `DiscardSomeCardFromHand`, `FlipItem` ×2, `KillHeroInRoom`, `RemoveHeroFromTheGame`, `SkipAdventurePhase`, `SkipBeginingOfTurn`, `SkipBuildPhase`, `UndoBuildRoom`…) : pour chacun, atteignable en jeu (xrefs depuis `AbilityFactory`/données `data.json`) ou code mort ? Rendre un tableau.
- **Haiku 3** : `classes.dex` n'existe qu'en smali (196 fichiers sous `apk-original/apktool-decoded/smali/`) : lister ce que fait la glu Java (`AndroidActivity`, `AndroidCustomService` ; leurs pendants C# sont `CS/DBMGame/AndroidActivity.cs`, `AndroidCustomService.cs`) et confirmer qu'elle ne porte **aucune règle ni animation**. Si oui : pas de port.
- **Haiku 4** : identifier les 71 `.fxo` / 44 `.frag` / 32 `.vert` (emplacements : `CS/DBMGame.CardEffect*.{frag,vert,fxo}` ; `apk-original/decompiled/Wave/Framework` ; `apk-original/decompiled/Wave/Materials`) : WaveEngine générique ou effets propres au jeu (glow de coup au boss, flip, fondu) ? Les effets propres au jeu entrent dans la **matrice du lot 1.3**.
- **Haiku 5** : second art par carte (alt-art de la galerie APK, `docs/HANDOFF.md` §7.7) : où est-il dans les WPK `apk-original/boss-monster-2-2-6/assets/Content/CardDecks/*` ? Si présent → Sonnet étend `tools/extract_apk_226.py` et `tools/verify_assets.py` ; les tuiles alt-art s'ajoutent à `GODOT/scripts/CardGallery.gd` (lot 1.3).
- **Haiku 6** : polices : le jeu utilise-t-il les BMFont (`tools/build_bmfonts.py` → `ASSETS/fonts/*.fnt` + `*_bm.png`) ou les TTF reconstruits (`tools/build_fonts.py` → `ASSETS/fonts/*.TTF`) ? **Un seul chemin doit rester** ; Sonnet supprime l'autre outil et `tools/ensure_fonts.py` (héritage de l'époque JS).
- **Orchestrateur** : transmet les tableaux à Sonnet ; note que `Common/marketItems.json` est absent de l'APK (acceptable : boutique supprimée).
- **Sonnet** : réécrit `apk-original/README.md` (inventaire vérifié ; **plus aucune référence** à `tests/unit/fixtures/apk-base-heroes.json`, supprimé, ni à l'ancienne pile) ; adapte/supprime les outils selon Haiku 5-6 ; consigne le tableau des `NotImplementedException` dans `apk-original/README.md`.

**Fichiers cibles** : `apk-original/README.md`, `tools/extract_apk_226.py`, `tools/verify_assets.py`, `tools/build_bmfonts.py` ou `tools/build_fonts.py` (un seul survit), `tools/ensure_fonts.py` (supprimé), `GODOT/scripts/CardGallery.gd` (si alt-art).

**Critère d'acceptation** : `apk-original/README.md` réécrit avec l'inventaire vérifié (types sans fichier, tableau des 22 `NotImplementedException` atteignable/mort, verdict glu Java, verdict shaders, verdict polices) ; aucune référence à `tests/unit/fixtures` dans le dépôt hors rapports historiques ; `python tools/verify_assets.py` et `python tools/run_godot_tests.py` verts.

---

## Lot 1.1 — Règles et flux de jeu (moteur)

**Objectif** : aucun écart de règle ou de flux avec le `GameBoard` de l'APK ; toutes les décisions de l'oracle sont rejouées ou classées.

**Sources** : `CS/DBMGameModel.Logic/GameBoard.cs` (13 phases, voir `tools/parity/README.md`) ; `CS/DBMGameProject.Scenes.GamePlay/GamePlayBaseScene.cs` ; oracle `tools/apk-oracle/` (`Program.cs`, `Trace.cs`, `TracingAI.cs`) ; `tools/parity/README.md` ; `docs/RAPPORT_REGLES.md` (périmé en partie).

**Qui fait quoi et cibles** (moteur : `GODOT/scripts/Match.gd`, `ApkParityTrace.gd`, `BoardUI.gd`, `GameManager.gd`)

1. **Vraie BaitPhase**. Aujourd'hui le leurre se fait à la fin du BUILD en un seul pas : `Match._close_build_phase()` (`GODOT/scripts/Match.gd` ~1216-1233) pose `G["phase"] = BAIT` puis appelle `_resolve_bait()` (~1351) dans la foulée, avant `ADVENTURE` ; la plaque BAIT n'est qu'UI (`docs/HANDOFF.md` §7.1). **Sonnet** : phase distincte alignée sur `GameBoard.AssignHeroesToDungeons` (`GameBoard.cs`), **sans changer la projection de parité** (`ApkParityTrace.gd` photographie déjà `bait`). Parité 3 variantes obligatoire.
2. **Départage** (fin de partie à égalité). `Match._tie_break_players()` (`Match.gd` ~1897-1911) applique « différence âmes − blessures la plus haute, puis XP la plus basse gagne » (livret ; son commentaire cite encore `engine.js`, supprimé). `docs/RAPPORT_REGLES.md` ligne ~143 affirme que l'APK retient l'XP la plus haute (`orderby PlayerId`) en citant `GameBoard.cs:1030`. Dans le C# actuel c'est `GameBoard.GetLessExperiencePlayerToWin` (`GameBoard.cs` ~1014-1033, utilisé par `GetWinnerWhenThereAreVariousCandidates`). **Haiku** vérifie ce que `PlayerId` désigne réellement (ordre de siège ? XP ?) et ce que fait l'APK dans les deux appels (`GetWinnerWhenSomePlayersAlive` aussi) ; **Sonnet** aligne `Match.gd` sur l'APK et ajoute un golden (`GODOT/tests/goldens.gd`).
3. **Timers en solo**. L'APK a 70 s (bouton DONE, `GamePlayBaseScene.cs:272`), 60 s (tour, `GamePlayBaseScene.cs:139`), 3 s (pas d'aventure : à localiser) ; le solo Godot n'a pas d'équivalent (seul le serveur a `--turn-timeout`, `GODOT/server/GameRoom.gd`). **Haiku** relève les constantes (`CS/DBMGameProject.Scenes.GamePlay.Components/CountDownBehavior.cs`, `ProgressBarBehavior.cs`, `GamePlayBaseScene.cs`) et le comportement à l'expiration (passe automatique ? IA ?). **Sonnet** implémente dans `Match`/`BoardUI` selon l'APK, en respectant l'option de vitesse SLOW/NORMAL/FAST (`Profile.load_speed()`, déjà lue par `BoardUI.gd` ~822).
4. **Décisions ignorées**. Les traces « OK » ont `stats.decisionsSkipped` élevé (288 sur `s3-p2`, 45 sur `s1-p3` ; compteur dans `GODOT/scripts/ApkParityTrace.gd`, lisible dans `tools/parity/out/apk/report.json` après un run). **Haiku** classe chaque décision ignorée (fenêtre de sorts sans choix côté Godot, cible interne, bogue de l'oracle). **Sonnet** fait échouer `tools/parity/apk.py` au-delà d'un seuil par classe, ou ouvre le choix Godot manquant.
5. **Graines 10-40** (59/93 aujourd'hui : `python tools/parity/apk.py --seeds 10 11 ... 40 --players 2 3 4`, 93 traces). **Haiku** classe les 34 échecs avec `--only=sN-pM --dbg=<a>-<b>` (options de `GODOT/tests/apk_parity.gd`, voir README parité ligne ~140) selon la grille de `tools/parity/README.md` « Limites assumees ». Tout ce qui n'est pas un bogue de l'IA oracle est un **écart de règle à corriger par Sonnet**. Objectif : 93/93, ou 100 % des restes documentés comme bogues oracle dans `tools/parity/README.md`.
6. **`undoBuildRoom` et `chooseDraw` (BMA023)** jamais couverts par l'oracle. **Sonnet** : soit un mode oracle qui force ces chemins (modifier `tools/apk-oracle/TracingAI.cs`), soit des goldens (`GODOT/tests/goldens.gd`, `goldens_undo.gd`) avec justification écrite.
7. **THK** (Tools of Hero-Kind) reste grisé comme dans l'APK : **ne rien implémenter** (partie 2, derrière la case wiki).

**Critère d'acceptation** : parité 6/6, 12/12, 6/6 **inchangée** ; graines 10-40 classées (tableau dans `tools/parity/README.md`) ; un golden par règle touchée ; `python tools/run_godot_tests.py` 14/14 ; seuil `decisionsSkipped` appliqué dans `apk.py`.

---

## Lot 1.2 — IA identique à l'APK

**Objectif** : l'IA Godot (`GODOT/scripts/AI.gd`, 438 lignes) joue les mêmes coups que l'IA statistique de l'APK, **mesuré**.

**Sources** : `CS/DBMGameProject.AI.Statistics/` (`StatisticsCalculator`, `RoomCalculator`, `DungeonSlotCalculator`, `DiscardCalculator`, `DrawCalculator`, `AbilityCalculator`, `TriggerCalculator`) et `CS/DBMGameProject.AI/StatisticAI.cs` ; `ai_info.json` par paquet (`apk-original/boss-monster-2-2-6/assets/Content/CardDecks/<paquet>/ai_info.json`) ; `docs/RAPPORT_REGLES.md` §3 ; `tools/apk-oracle/TracingAI.cs` (la trace contient déjà chaque décision de l'IA oracle).

**Qui fait quoi**
- **Haiku** : matrice méthode C# → fonction GDScript, avec les constantes (ex. `DiscardCalculator.cs` lignes ~10-22 : facteurs `early/mid/lateCantBuildRoomFactor` −100/−150/−200, `setup/early/mid/lateKeepSpellFactor` 0,4/0,5/0,9/1,0 ; seuils de phase EARLY/MID/LATE) et verdict « identique / différent / absent ». Vérifier en particulier les écarts listés dans `docs/RAPPORT_REGLES.md` (trésor précoce inversé, valorisation du leurre, combos Construction Zone / Goblin Armory / Dizzygas / Minotaur, choix salle-vs-sort, heuristiques par carte, seuils décalés d'un tour) : **réels aujourd'hui ou périmés ?** Plus `choose_boss` (code mort) et `BMA029`/`BMA015` qui lisent `dungeon[0]` (`docs/HANDOFF.md` §7.3).
- **Sonnet, nouvelle métrique** : mode `--ai-agreement` (à créer) dans `tools/parity/apk.py` + `GODOT/scripts/ApkParityTrace.gd` : à chaque décision de l'IA oracle, demander à `AI.pick_move` ce qu'elle jouerait **sur le même état** et compter l'accord par type de coup (build, discard, spell, cible, draw). Rapport dans `report.json`. **L'oracle ne doit pas être modifié au-delà de la trace.**
- **Sonnet, corrections** : corriger `AI.gd` écart par écart en suivant la matrice, jusqu'à un taux d'accord **fixé après la première mesure** (viser 100 % sur les coups déterministes ; les tirages aléatoires de l'IA C# sont à identifier et exclus). **Le seuil est consigné par Sonnet dans `tools/parity/README.md`** (voir critère) : c'est le seuil cité par le README §7.
- Les cartes wiki gardent `GODOT/scripts/AiWiki.gd` (heuristiques maison, hors périmètre partie 1).

**Fichiers cibles** : `GODOT/scripts/AI.gd`, `GODOT/scripts/ApkParityTrace.gd`, `tools/parity/apk.py`, `tools/parity/README.md`, `GODOT/tests/goldens_ai.gd`.

**Critère d'acceptation** : matrice 100 % renseignée (consignée dans `tools/parity/README.md` ou en en-tête de `AI.gd`) ; `--ai-agreement` ≥ seuil sur les 18 traces (6 + 12) ; seuil et mesure initiale consignés dans `tools/parity/README.md` ; `GODOT/tests/goldens_ai.gd` étendu ; parité 6/6, 12/12, 6/6 inchangée (l'IA n'y est pas appelée, mais `AI.gd` est un fichier moteur : lancer les 3 commandes).

---

## Lot 1.3 — Interface et animations pixel/timing

**Objectif** : chaque écran et chaque animation de l'APK trouve son équivalent Godot mesuré (position, taille, police, couleur, durée, easing).

**Sources** : captures `docs/reference/apk_orig/` (115 frames fiables + `INDEX.md`, **local, gitignoré**) ; C# : `CS/DBMGameProject.Scenes.GamePlay/GamePlayBaseScene.cs`, `CS/DBMGameProject.Scenes.GamePlay.Entities/DungeonFrameEntity.cs`, `CS/WaveEngine.Extensions.Behaviors/MovementBehavior.cs` (et `FadeBehavior`, `ShakeBehavior`, `ScaleEffectBehavior`, `BlinkBehavior`…), `CS/WaveEngine.Extensions.ITasks/SingleAnimationTask.cs`, `CS/DBMGameProject.Common.Components/FlipCardBehavior.cs`, `CS/DBMGameProject.Scenes.GamePlay.Components/CardPositionComponent.cs`, `CardAbilityBorder` (pas de fichier du même nom : le symbole n'apparaît que dans `CS/DBMGameProject.Common.Components/CardAttributesComponent.cs` ; chercher aussi `CardBorderBehavior`, `BaseBorderBehavior`) ; scènes menus (`CS/DBMGameProject.Scenes.*`, `LoseScene`, `WinnerScene`, `PauseScene`, `RandomBossSelectionScene`).

**Cibles Godot** (`GODOT/scripts/`) : `BoardUI.gd` (3569 lignes, ~25 occurrences de `create_tween`), `Main.gd`, `OnlineMenus.gd` (écrans locaux seulement), `CardGallery.gd`, `GameOverBanner.gd`, `UiKit.gd`, `InGameMenu.gd`, `CardUI.gd`.

**Qui fait quoi**
- **Haiku (plusieurs, un par fichier C#)** : **matrice des animations** : pour chaque `*Behavior` / `*AnimationTask` / tween C# → durée, easing, propriétés, déclencheur, puis le site `BoardUI.gd` correspondant (ligne) et le verdict. Les durées Godot non étiquetées (0.12, 0.22, 0.4 s…) doivent **chacune** trouver leur origine C# ou être remplacées. Inclure les effets de shader propres au jeu identifiés au lot 1.0 (Haiku 4).
- **Haiku** : **matrice des écrans** : chaque scène/menu APK (titre, menu 2×2, solo setup, options, carrousel de boss, pause, fin de partie, galerie, RULES à la place du store) → frame de référence (`apk_orig/INDEX.md`) → capture Godot (`CaptureScreens.tscn`) → écart (position, taille, police, couleur). Compléter `docs/reference/godot_screens/COMPARISON.md` et `PHASES.md` (locaux).
- **Captures APK manquantes** (`docs/HANDOFF.md` §9 A4 : écran de victoire, popup level-up, menu options ; lobby/salle d'attente en ligne pour la partie 3) : exécuter `tools/capture_apk_full_turn.py` via BlueStacks (commandes : README §5, **HD-Adb.exe uniquement**) — l'**orchestrateur** lance, **Haiku** indexe les nouvelles frames dans `docs/reference/apk_orig/INDEX.md`.
- **Sonnet, écarts déjà connus** (`docs/HANDOFF.md` §7) : main grisée conservée derrière l'écran de fin ; capacité de salle = zoom puis tap (APK `ShowZoomCard`, `GamePlayBaseScene.cs` ~734) ; tombe RIP à l'échelle de `LoseScene` ; galerie comparée pixel à pixel + alt-art (lot 1.0) ; bouton wiki EXTRA MOVES absent de l'APK → **masqué quand aucun pack wiki n'est actif**.
- **Sonnet, ensuite** : chaque ligne « différent » de la matrice animations, par lots de 5-10, `ui_smoke` vert entre chaque lot.
- **Vérification manuelle à la fin** : export web, deux parties complètes à la souris (drag de sort compris, non vérifiable par l'outil navigateur) : **à faire par l'utilisateur**, ou via BlueStacks côté APK pour comparer.

**Critère d'acceptation** : matrices 100 % « conforme » ou « écart justifié » ; `GODOT/tests/ui_smoke.gd` et `CaptureScreens.tscn` verts ; aucune durée sans origine ; `python tools/run_godot_tests.py` 14/14 ; la parité n'est pas à relancer tant que seuls des fichiers d'UI sont touchés.

---

## Lot 1.4 — Audio

**Objectif** : chaque événement sonore de l'APK joue le bon fichier, avec le bon volume/boucle/fondu.

**Sources** : appels `PlaySound`/`PlayMusic` dans le C# (`grep` sur `CS/`) ; 84 fichiers `.import` / 42 sfx + 2 musiques extraits dans `ASSETS/audio/sfx` et `ASSETS/audio/music` (`music_main.mp3`, `music_dungeon_v3.mp3`) ; contenu natif `apk-original/boss-monster-2-2-6/assets/Content/Audio`.

**Cible** : `GODOT/scripts/AudioManager.gd` (129 lignes) et ses sites d'appel.

**Qui fait quoi**
- **Haiku** : liste des appels C# avec l'événement déclencheur, puis **matrice événement → fichier son C# → appel Godot**. Volume, boucle, fondu, coupure (mute) depuis les options.
- **Sonnet** : combler les manques selon la matrice.

**Critère d'acceptation** : matrice 100 % « conforme » ou « écart justifié » ; `python tools/run_godot_tests.py` 14/14 ; l'écoute réelle reste à confirmer par l'utilisateur (non vérifiable par les outils headless).

---

## Lot 1.5 — Écran RULES (déjà fait, à vérifier seulement)

**Objectif** : l'écran RULES (qui remplace IN-APP STORE) est cohérent avec l'APK.

**Sources** : frame du menu 2×2 de l'APK (`apk_orig/INDEX.md`), menu pause APK (`PauseScene.cs`) ; `GODOT/scripts/RulesViewer.gd`, `Main.gd`, `InGameMenu.gd`.

**Qui fait quoi**
- **Haiku** : compare la position/le style du bouton RULES avec le bouton IN-APP STORE de l'APK (frame menu 2×2) et l'overlay en jeu avec le menu pause APK.
- **Sonnet** : corrige les pixels si besoin. **Rien d'autre.**

**Critère d'acceptation** : écarts de pixels listés par Haiku corrigés ou justifiés ; `ui_smoke` vert.

---

## Lot 1.6 — Clôture de la partie 1

**Objectif** : dépôt propre, documentation honnête, merge.

**Qui fait quoi**
- **Sonnet** :
  - marquer `docs/RAPPORT_REGLES.md` et `docs/RAPPORT_CORRECTIONS.md` comme historiques (en-tête ; `RAPPORT_CORRECTIONS.md` en a déjà un, à harmoniser) ;
  - supprimer des en-têtes `GODOT/tests/goldens_crl.gd`, `goldens_rmb.gd`, `goldens_tnl.gd` les références à `tests/unit/*.test.js` (les trois en contiennent) ;
  - corriger le commentaire périmé de `GODOT/scripts/Profile.gd` ligne ~97 (« simplement mémorisée pour l'instant » : la vitesse est lue par `BoardUI.gd` ~822, `InGameMenu.gd`, `Main.gd`) ;
  - retirer `design_system` de `.dockerignore` (ligne 18) ;
  - supprimer les outils morts identifiés au lot 1.0 (`tools/extract_music.py`, `tools/ensure_fonts.py`, `tools/build_decompiled_index.py` ou `tools/play_apk_robust.py` si doublon — vérifier d'abord qu'aucun script ni la doc n'en dépend : `docs/HANDOFF.md` §8 cite `play_apk_robust.py`).
  - mettre à jour `docs/HANDOFF.md` §5 et §7 (liste honnête des écarts restants, idéalement vide hors « bogues de l'IA oracle non reproduits »).
- **Orchestrateur** : `python tools/run_godot_tests.py` 14/14, parité 3 variantes, `--ai-agreement`, `code-review` du diff complet, merge dans `main` (au 2026-10-18 la branche courante est déjà `main` ; `docs/HANDOFF.md` mentionne encore `parity/apk-oracle` : si cette branche existe toujours, la fusionner puis demander avant de la supprimer), puis **redéploiement homelab** (`deploy/DEPLOYMENT.md` §3) **après accord de l'utilisateur**.

**Critère d'acceptation** : tous les critères du README §7 point 1 ; une seule branche `main`, aucune PR, `git status` propre ; `docs/HANDOFF.md` §5/§7 à jour.
