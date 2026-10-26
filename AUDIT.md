# AUDIT — parité fonctionnelle APK 2.2.6 (Wave Engine) → Godot 4.7 (web)

Source de vérité : `apk-original/decompiled/DBMGame/` (560 `.cs`, ilspycmd) + assets `apk-original/boss-monster-2-2-6/`.
Cible : `src/frontend/` (Godot 4.7, GL Compatibility, export Web sans threads) + `src/frontend/godot/server/` (serveur WS headless).

## Légende

- **Présent ?** : `Oui` / `Non (vérifié absent)` / `Non vérifié (accès manquant)` / `N/A` (rien à porter, preuve donnée).
- **Équivalent ?** : `Oui` / `Partiel` / `Différent` / `—`.
- **Priorité** : Critique (bloque le jeu ou le web) / Haute (règle ou comportement visible faux) / Moyenne (écart perceptible, contournable) / Basse (cosmétique, code mort, choix assumé).
- Chaque ligne cite `fichier:ligne` côté source et côté Godot. Aucune ligne « Oui » sans preuve relue dans le code.

## Plan des modules

| # | Module | Namespaces source | État |
|---|---|---|---|
| 1 | Sauvegarde | `DBMGameProject.Storage`, `Game.LoadStorageGameData` | **Fait (2026-10-26)** |
| 2 | Audio | `Services/AudioService`, `Resources` (sons) | **Fait (2026-10-26)** |
| 3 | Entrées | `AndroidActivity`, comportements tactiles (`Common.Components`, `GamePlay.Components`, `MainMenu.Components`) | **Fait (2026-10-26)** |
| 4 | UI / menus | `Scenes.MainMenu*`, `Factories`, `Common.*` | **Fait (2026-10-26)** |
| 5 | Règles (modèle) | `DBMGameModel.*` | **Fait (2026-10-26)** |
| 6 | IA | `DBMGameProject.AI*` | **Fait (2026-10-26)** |
| 7 | Plateau / scènes de jeu | `Scenes.GamePlay*` | **Fait (2026-10-26)** |
| 8 | Tutoriel | `Scenes.Tutorial*`, `GamePlayTutScene` | **Fait (2026-10-26)** |
| 9 | En ligne | `Services.Online`, `Logic.OnlineModels`, Photon | **Fait (2026-10-26)** |
| 10 | Dépendances Android (IAP, logs, Insights) | `Services.AppPurchase`, `Services.Log`, `InAppServiceBinding`, `play.billing.v3`, `Xamarin.Insights` | **Fait (2026-10-26)** |
| 11 | Assets / rendu | `Resources`, `WaveEngine.Extensions.*`, particules, polices | **Fait (2026-10-26)** |
| 12 | Export web / perf | `export_presets.cfg`, `.pck`, chargement | **Fait (2026-10-26)** |
| 13 | Couverture résiduelle | les 177 classes non citées par les modules 1 à 12 | **Fait (2026-10-26)** |

---

## Module 1 — Sauvegarde

Source relue : `DBMGameProject.Storage/*.cs` (11 fichiers, 376 lignes), `DBMGameProject/Game.cs:60-121`, tous les appelants (`grep GameSettings|GameStats|PurchasedItems|StorageHelper`).
Godot relu : `scripts/Profile.gd` (119 l.), `scripts/AudioManager.gd:60-130`, `scripts/Main.gd:283-293,335-339,637-642`, `scripts/BoardUI.gd:931-935`, `scripts/OnlineClient.gd:270-283,400-430`.

| ID | Élément source (décompilé) | Type | Présent dans Godot ? | Fichier Godot | Équivalent fonctionnel ? | Écart / Commentaire | Priorité |
|----|----|----|----|----|----|----|----|
| S-01 | `StorageHelper.SafeStorageWrite/Read` (8 essais, log `Crash`, `new T()` si échec) — `StorageHelper.cs:15-57` | Méthode | Oui | `Profile.gd`, `AudioManager.gd:120-128` (`ConfigFile.load/save`) | Partiel | Lecture : valeurs par défaut si fichier absent/illisible = équivalent. Écriture : code retour de `cfg.save()` jamais testé, pas de nouvel essai ni de log → une écriture ratée passe inaperçue. | Basse |
| S-02 | Backend `WaveServices.Storage` (sérialisation par type dans le stockage privé de l'app) | Service | Oui | `user://profile.cfg`, `user://audio.cfg` | Partiel | Web : Godot monte `user://` sur IndexedDB (IDBFS), pas de fichier local → conforme à la contrainte web. Écart : aucun appel à `OS.is_userfs_persistent()` ; en navigation privée / stockage bloqué, réglages et profil sont perdus sans avertissement. | Moyenne (web) |
| S-03 | `GameSettings.Difficulty` (`DificultyEnum` Easy/Normal/Hard, défaut Normal) — `GameSettings.cs:11,31` | Propriété + enum | Non (vérifié absent) | — | N/A | Code mort dans l'APK : aucun lecteur de `.Difficulty` hors `Storage/` (grep sur les 560 `.cs`). Rien à porter. | Basse |
| S-04 | `GameSettings.MusicVolume` (0/1 via MUSIC ON/OFF, défaut 1) — `GameSettings.cs:13,33`, `SettingsScene.cs:68-77` | Propriété | Oui | `AudioManager.gd` (`music_on`, bus `Music` muet), `Main.gd:640` | Oui | Booléen au lieu d'un float 0/1 : même comportement (l'APK n'écrit que 0 ou 1). | — |
| S-05 | `GameSettings.SoundVolume` (SOUND ON/OFF) — `SettingsScene.cs:78-87` | Propriété | Oui | `AudioManager.gd` (`sfx_on`, bus `SFX`), `Main.gd:641` | Oui | Idem S-04. | — |
| S-06 | `GameSettings.GameSpeed` + `GetSpeed()` (SLOW 1,5 / NORMAL 1 / FAST 0,5 ; forcé 0,5 si `ConnectionStates.InGame`) — `GameSettings.cs:45-68` | Propriété + méthode | Oui | `Profile.gd:109-119`, `BoardUI.gd:931-935`, `Main.gd:642`, `InGameMenu.gd:69` | Oui | Constantes et forçage en ligne identiques ; défaut NORMAL (1) identique. Usage par chaque animation à vérifier au module 7. | — |
| S-07 | `GameSettings.FullScreenMode` → `CustomService.IsFullScreenActive` (défaut true) — `GameSettings.cs:17,72-77` | Propriété | Non (vérifié absent) | — | — | Aucune ligne d'UI ne l'expose dans `SettingsScene`. L'implémentation Android de `CustomService` (sous-classe hors `DBMGame.dll`) est **non vérifiée faute d'accès** : probablement le mode immersif Android. Côté web, le plein écran exige un geste utilisateur ; non requis pour la parité. | Basse |
| S-08 | `GameSettings.LegendaryEnabled` + ligne LEGENDARY MODE (affichée seulement si `IsBacker`, hors partie) — `SettingsScene.cs:98-110` | Propriété + UI | Non (vérifié absent) | — | — | Dépend de `IsBacker` (S-16). Effets : logos/défausse « legend », 15 avatars au lieu de 8 (`AvatarScrollComponent.cs:70`), art de cartes (`CardAssetService.cs:224`). Voir module 10. **Décision confirmée le 2026-10-26 : boutique supprimée.** | Basse |
| S-09 | Champs obsolètes `TotalWins`, `IsFirstGameplay`, `IsBacker` de `GameSettings` + migration vers `GameStats` — `Game.cs:103-115` | Propriété / migration | N/A | — | N/A | Migration de sauvegardes Android antérieures : sans objet pour une installation web neuve. | — |
| S-10 | `GameSettings.SaveChanges()` au retour de SETTINGS — `SettingsScene.cs:133-136` | Méthode | Oui | `AudioManager._save`, `Profile.save_speed` (à chaque clic) | Oui | Sauvegarde immédiate au lieu d'au retour : même résultat visible, plus robuste (fermeture d'onglet). | — |
| S-11 | `GameStats.OnlineWins/OnlineDefeats` : défaite comptée **au début** de la partie en ligne, annulée à la victoire (`GamePlayMOScene.cs:46-48,262-265`) ; désertion : victoire seulement si `NumberOfTurns > 2`, défaite annulée dans tous les cas (`GamePlayMOScene.cs:241-250`) | Propriété + logique | Oui | `Profile.gd:55-73`, `OnlineClient.gd:272-283` | Différent | Godot ne compte qu'à `status == "finished"` → quitter ou fermer l'onglet en cours de partie n'ajoute **aucune** défaite (l'APK en compte une). Règle de désertion (> 2 tours) à vérifier côté serveur au module 9. Anti-double comptage par code de salle : ajout Godot, OK. | Corrigé (Moyenne) |
| S-12 | `GameStats.SPWins` (+1 à chaque victoire solo, `GamePlaySPScene.cs:80-86`) → `TotalWins()` → déblocage Hidden Heroes à 40 victoires (`LocalMarket.cs:147`, `AppPurchaseService.cs:315-321`, `WinnerScene.cs:98-110`, « N WINS TO UNLOCK! » `PurchaseScene.cs:146-149`) | Propriété + logique | Non (vérifié absent) | — (`Match.gd:12` : HiddenHeros jouable d'office) | Différent | Pas de compteur de victoires solo ni d'écran « CONGRATULATIONS! … HIDDEN HEROES ». Cohérent avec la boutique retirée (`apk-original/README.md` §2) — **à confirmer : choix assumé ?** **Décision confirmée le 2026-10-26 : boutique supprimée.** | Basse |
| S-13 | `GameStats.UserName` / `Avatar` (int, index `Atlas.AVATAR`) | Propriété | Oui | `Profile.gd:20-52` (`name`, `avatar` en id texte, `NAME_MAX` 45, `random_profile`) | Oui | Id texte au lieu d'index : équivalent. `random_profile` (« player_ » + 4 car.) non recoupé avec `StringFactory.RndWord` → à vérifier au module 4. | Basse |
| S-14 | `GameStats.IsFirstGameplay` : boîte TUTORIAL au 1er SINGLE PLAYER (CANCEL → faux) — `MainMenuScene.cs:60-88` ; consommé aussi par le constructeur de `GamePlayTutScene` (`:82-84`) | Propriété + flux | Oui | `Profile.gd:97-107`, `Main.gd:286-293,335-336` | Oui | Les deux points de consommation sont portés ; défaut true identique. | — |
| S-15 | `GameStats.CheckForcePlayTutorial` (rejoue le tutoriel si version sauvée < `LAST_TUTORIAL_VERSION` 2.2.4 ; `CURRENT_VERSION` 2.2.6) — `GameStats.cs:33-42`, `Game.cs:30,34,119` | Méthode | Non (vérifié absent) | — | N/A | Sans objet tant qu'aucune version web antérieure n'existe (défaut `first_gameplay = true`). À reprendre si le tutoriel change dans une future version. | Basse |
| S-16 | `GameStats.IsBacker` → `Boss.IsBacker` (`GamePlayBaseScene.cs:563-569`), visuels « legend », envoyé en ligne (`OnlineService.cs:1012`) ; mis à vrai par `AppPurchaseService.cs:191` | Propriété | Non (vérifié absent) | — | — | Statut mécène Kickstarter lié à l'achat : voir module 10. **Décision confirmée le 2026-10-26 : boutique supprimée.** | Basse |
| S-17 | `OnlineStorage` (obsolète : UserName/Avatar/Wins/Defeats) | Classe | N/A | — | N/A | Seulement relu pour migration (`Game.cs:100-112`). | — |
| S-18 | `OnlineKeys` (clés de propriétés Photon : IsBacker, Wins, Defeats, Avatar, UserName, AppID, …) | Classe | Non vérifié | — | — | Protocole Photon remplacé par le serveur WS : à traiter au module 9. | — |
| S-19 | `PurchasedItems`, `PurchaseId` (SKU `com.dbm.fullgame*`, clé publique de licence Google Play), `AppItemInfo`, `AppStoreInfo` | Classes | Non (vérifié absent) | — | — | Boutique/IAP retirée : module 10. La clé de `PurchaseId.cs` est une clé **publique** (pas un secret). | — (module 10) |
| S-20 | — (absent de l'APK) Reprise de session en ligne après rechargement | Ajout Godot | Oui | `OnlineClient.gd:400-430` (`sessionStorage` via `JavaScriptBridge` sur web, `user://online_session.cfg` sinon) | — | Ajout propre au web (un onglet = un siège). Pas d'écart de parité. | — |
| S-21 | — (absent de l'APK) Volume général `master` (curseur en partie) | Ajout Godot | Oui | `AudioManager.gd:103-109`, `InGameMenu.gd:72-104` | Différent | Les réglages en partie de l'APK (`SettingsScene(fromGamePlay)`) n'ont que MUSIC/SOUND/GAME SPEED. Ajout à justifier ou retirer : module 4. | Basse |

### Résumé module 1

- **21 éléments audités** : 7 OK (S-04, S-05, S-06, S-10, S-13, S-14, S-20), **4 N/A** (S-03, S-09, S-15, S-17), **9 écarts** (S-01, S-02, S-07, S-08, S-11, S-12, S-16, S-19, S-21), 1 renvoyé (S-18).
- **Bloquants web : 0.** Risque web : S-02 (stockage non persistant non détecté).
- Écarts Moyenne : S-02, S-11. Le reste est Basse ou suspendu à une confirmation.

### Questions ouvertes (module 1)

1. ~~S-12 / S-16 / S-08 : retrait assumé ?~~ Réponse : oui, la boutique est supprimée.
2. ~~S-11 : faut-il reproduire la défaite comptée dès le début d'une partie en ligne (anti-abandon) ?~~ Réponse : oui, comme l'APK (corrigé le 2026-10-26).

---

## Module 2 — Audio

Source relue : `DBMGameProject.Services/AudioService.cs` (226 l.), `DBMGameProject.Resources/Audio.cs`, `CardAssetService.cs:246-360`, `DBMGameModel.Logic/RoomCategory.cs`, **tous** les appels `Audio.(Sfx|SfxSting|SfxLoop|Music).*` (63 sites, grep exhaustif hors `Scenes.Test`), `HeroCrossingBehavior.cs:55-120`, `WinnerScene.cs:121-132`, `LoseScene.cs:21`, `WaitingPublicRoomScene.cs:88-108`, `AndroidActivity.cs:95-112`, moteur Wave `SoundBank.cs:128-146`, `SoundPlayer.cs:116-139`.
Assets source : `assets/Content/Audio/Music/` (2 `.mp3`, 3,4 Mo), `assets/Content/Audio/Sfx/` (42 `.wpk`).
Godot relu : `scripts/AudioManager.gd` (autoload, 259 l.), tous les appels `AudioManager.*` et `BoardUI._play_sfx` (≈ 90 sites), `CountDown.gd:40-52`, `assets/audio/**/*.import`, `project.godot`.
Données recoupées par script : `RoomCategory` et `IsMale` de `assets/data/*/data.json` contre les tables de `AudioManager.gd:21-34`.

| ID | Élément source (décompilé) | Type | Présent dans Godot ? | Fichier Godot | Équivalent fonctionnel ? | Écart / Commentaire | Priorité |
|----|----|----|----|----|----|----|----|
| A-01 | `AudioService` (service enregistré par `Game.cs:44`, accédé par chaque scène `DBMBaseScene.cs:43`) | Classe / service | Oui | `AudioManager.gd` (autoload `project.godot:19`) | Oui | — | — |
| A-02 | `SoundBank.MaxConcurrentSounds = 10` (`AudioService.cs:97`) ; plein → `CreateSoundInstance` renvoie `null`, **le nouveau son est abandonné** (`SoundBank.cs:130-145`) ; la boucle compte dans les 10 | Constante + comportement moteur | Oui | `AudioManager.gd:10,155-165` | Différent | Godot **vole** la voix la plus ancienne (tour à tour) au lieu d'ignorer le nouveau son ; la boucle `sfx_sparklecard` a son propre lecteur (11 voix possibles). Audible seulement en rafale (> 10 sons). | Basse |
| A-03 | `LoadAllSounds()` : précharge les 42 sons (`Sfx` 38 + `SfxSting` 3 + `SfxLoop` 1) — `AudioService.cs:113-127`, appelé par `LoadingScene.cs:54` | Méthode | Oui | `AudioManager.gd:14-19,68-69` | Oui | Liste `SFX_NAMES` = les 42 noms de `Audio.cs` (recoupés un à un) et les 42 `.wav` présents dans `assets/audio/sfx/`. | — |
| A-04 | `Play(Audio.Music)` : `IsRepeat = true`, ne relance pas la piste en cours, volume = `MusicVolume` — `AudioService.cs:190-201` | Méthode | Oui | `AudioManager.gd:132-143` | Oui | Boucle forcée à l'exécution (`AudioStreamMP3.loop = true`), l'import garde `loop=false`. | — |
| A-05 | `musicVolume = 0.5f` par défaut (`AudioService.cs:29`), écrasé par `GameSettings.MusicVolume = 1` via `ApplySettings` (`Game.cs:98`) | Constante | Oui | `AudioManager.gd:41` (`music_volume = 1.0`) | Oui | Le 0,5 n'est jamais effectif dans l'APK ; Godot part directement de 1,0. | — |
| A-06 | `PlayWithMusicFade(SfxSting)` : musique × 0,5 puis retour linéaire en 2 s, seulement si musique et sons actifs et > 0 — `AudioService.cs:153-164,209-225` | Méthode | Oui | `AudioManager.gd:167-182` (`play_sting`, `duck_gain`, `_process`) | Oui | Constantes `DUCK 0.5`, `DUCK_SECONDS 2.0` et condition identiques. | — |
| A-07 | `PlayLoopSound` / `StopLoopSound` : une instance par son, compteur de demandes — `AudioService.cs:129-143,166-176` | Méthode | Oui | `AudioManager.gd:185-212` | Oui | `stop_all_loops()` (ajout Godot) sert au nettoyage en sortie de plateau. | — |
| A-08 | `MuteSFX` / `MuteMusic` (propriétés publiques) | Propriété | N/A | — | N/A | Aucun écrivain dans `DBMGame` (grep) ; `MuteMusic` n'est que lu dans `PlayWithMusicFade`. Code mort. | — |
| A-09 | `MUSIC_FADEIN_SECONDS = 2f` (`AudioService.cs:15`) | Constante | N/A | — | N/A | Déclarée, jamais utilisée. | — |
| A-10 | Pause de la musique quand l'app passe en arrière-plan : `AndroidActivity.OnPause → Game.OnDeactivated` (`AndroidActivity.cs:95-112`) → `MusicPlayer.Pause` (Wave `GLView.cs:162`, `MusicPlayer.cs:179-200`) | Cycle de vie | Non (vérifié absent dans les scripts) | — | Non vérifié | Aucun traitement de la perte de focus / onglet masqué dans les scripts. Ce que fait le moteur web quand l'onglet est masqué est **non vérifié** (à tester en navigateur). | Moyenne |
| A-11 | `GetBoss{Intro,Hurt,Death,Victory}Sound` : `boss_male_*` si `Boss.IsMale`, sinon `boss_female_*` (boss nul → female) — `CardAssetService.cs:246-300` | Méthode | Oui | `AudioManager.gd:34,215-216` | Oui | `BOSS_FEMALE` = exactement les 10 boss `IsMale=false` de `data.json` (BMA006-008, KSA001-007) ; 5 masculins. Boss du wiki → masculin (ajout, pas de donnée APK). Boss inconnu = male (APK : boss nul = female) : cas inatteignable avec les paquets APK. | — |
| A-12 | `GetRoomSound` : `RoomCategory` 1 fall, 2 monster_med, 3 undead, 4 physical, 5 monster_lrg, 6 magic ; autre/nul → physical — `CardAssetService.cs:326-360`, `RoomCategory.cs` | Méthode | Oui | `AudioManager.gd:21-31,219-224` | Partiel | Correspondance enum → son identique ; les 31 salles de `BaseDeck` recoupées avec `data.json` (aucune différence) ; les salles `PlayerChoice`/`ToolsHeroKind` n'ont pas de `RoomCategory` → physical, comme l'APK. Écart de conception : table d'ids figée dans le code au lieu de lire `RoomCategory` dans les données. | Basse |
| A-13 | `GetSpellSound` (summon / null / buff / debuff selon `SpellCategory`) — `CardAssetService.cs:302-325` | Méthode | N/A | — | N/A | **Aucun appelant** dans `DBMGame` (grep) : les sorts ne jouent jamais ces sons dans l'APK. Godot ne les joue pas non plus : conforme. | — |
| A-14 | Sons jamais joués par l'APK : `sfx_spelladd`, `sfx_multigameready`, `ui_button_finish`, `ui_card_flip`, `sfx_spell_summon`, `sfx_spell_null`, `sfx_spell_debuff` (seul `Scenes.Test/AudioScene` les cite) | Asset | Oui (fichiers) | `assets/audio/sfx/` | Oui | Copiés et préchargés comme dans l'APK, jamais joués. Poids inutile dans le `.pck` (faible, voir module 12). | Basse |
| A-15 | `ui_purchase` (`UnlockScene.cs:167`) | Appel | Non (vérifié absent) | — | — | Lié à l'écran de déblocage retiré (S-12). | Basse |
| A-16 | Musiques : `music_main` à l'intro (`IntroScene.cs:84`), `music_dungeon_v3` en partie (`GamePlayBaseScene.cs:552`) | Appel | Oui | `Main.gd:238,276`, `BoardUI.gd:657` | Oui | — | — |
| A-17 | Stings : `sting_levelup` (`LevelUpBanner.cs:122`), `sting_player_lose` (`LoseScene.cs:21`), `sting_player_win` + voix de victoire du boss **0,5 s plus tard** (`WinnerScene.cs:121-132`) | Appel | Oui | `BoardUI.gd:1302,4285-4291` | Oui | Délai de 0,5 s identique. | — |
| A-18 | Traversée du héros : `char_hero_intro` (`GamePlayBaseScene.cs:934`), `char_hero_move` + son de salle à chaque salle (`HeroCrossingBehavior.cs:70-76`), `char_hero_death` (`:98`), `char_hero_move` puis `char_hero_attack` vers le boss (`:111,117`) | Appel | Oui | `BoardUI.gd:2211-2267,2353-2355,2376-2381` | Oui (sons) | Présence et ordre des sons vérifiés ; synchronisation exacte avec les animations : module 7. | — |
| A-19 | `HeartDecrementEmitter` : `char_hero_hurt` si PV perdus, `sfx_spell_buff` si PV rendus (`:64-70`) | Appel | Oui | `BoardUI.gd:2241,2364` | Oui | — | — |
| A-20 | Boss : intro au tirage (`RandomBossSelectionScene.cs:134`), blessure / mort (`DungeonFrameEntity.cs:507,516`) | Appel | Oui | `BoardUI.gd:1898-1905,2273-2281` | Oui | — | — |
| A-21 | Mouvements de cartes : `FlipCardBehavior.cs:113,126`, `CardPositionComponent.cs:83-96`, `AddCarouselCardsBehavior.cs:105`, `DrawCardEmitter.cs:161`, zoom `GamePlayBaseScene.cs:1267-1272`, file de héros `VerticalScrollQueueComponent.cs:194` | Appel | Oui | `BoardUI.gd:856,1390,1848,1894,3267-3335,3818-3831,4152,4164`, `CardUI.gd:108` | Partiel | Retournement de toutes les cartes du carrousel : l'APK joue `ui_card_slide_down` **une fois par carte** (sons superposés, plus fort), Godot une seule fois (`BoardUI.gd:1848`). | Basse |
| A-22 | Carrousel : `ui_shuffle_left` si l'indice augmente, `ui_shuffle_right` s'il diminue (`CarrouselComponent.cs:118-133`) | Appel | Partiel | `BoardUI.gd:1862` (tirage du boss) | Partiel | Le tirage du boss ne tourne que dans un sens → `left` seul, conforme. Les autres carrousels de l'APK (glissement dans les deux sens, `CarrouselDragBehavior`) : **non vérifié**, à traiter aux modules 4 et 7. | Basse |
| A-23 | Panneau d'adversaire étendu : `ui_card_slide_down` à l'ouverture, `ui_card_slide_up` à la fermeture (`ExpandedOpponentComponent.cs:51,60`) | Appel | Non (vérifié absent dans les appels audio) | — | — | Aucun son équivalent. L'existence du panneau lui-même dans Godot : à vérifier au module 7. | Basse |
| A-24 | Sélection de cartes : `ui_button_subselect` au retrait, `ui_button_select` à l'ajout (`CardSelectorComponent.cs:120-135`) | Appel | Oui | `BoardUI.gd:2694-2696,3227-3233` | Oui | — | — |
| A-25 | Boutons : `ui_button_select` (`ButtonBaseEntity.cs:202`, `ControlsFactory.cs:263`, `SettingButtonDecorator.cs:132`, `DoneButtonEntity.cs:164`, `TargetResolverBaseSceneBehavior.cs:165`, `GalleryScene.cs:352`, `CardDetail*`), `ui_button_goback` (`ControlsFactory.cs:245`, `CardDetailEntity.cs:124`, `CardDetailScene.cs:74`) | Appel | Oui | `UiKit.gd:211`, `Main.gd:183-616`, `CardGallery.gd:233,289`, `RulesViewer.gd`, `InGameMenu.gd:56-63`, `OnlineMenus.gd`, `BoardUI.gd` | Oui (par sondage) | Les deux sons sont branchés sur les boutons et retours ; la correspondance bouton par bouton est reportée au module 4. | — |
| A-26 | `sfx_activatecard` à l'entrée de la bulle d'action de l'adversaire (`BubblesPlayerEmitter.cs:115`) | Appel | Oui | `BoardUI.gd:3990` | Oui | — | — |
| A-27 | Boucle `sfx_sparklecard` sur les cartes jouables (`CardStackSlotComponent.cs:312,334`, arrêts `CardAttributesComponent.cs:210,261`) | Appel | Oui | `BoardUI.gd:677,2839,2985-2987` | Oui | — | — |
| A-28 | `ui_timer` : joué **uniquement** dans la salle d'attente publique, pendant le compte à rebours de lancement (`WaitingPublicRoomScene.cs:88-105`) | Appel | Différent | `CountDown.gd:49` | Différent | Godot joue `ui_timer` chaque seconde sous 5 s dans le **compte à rebours de tour en partie** (`Main.gd:576`), ce que l'APK ne fait jamais, et aucun `ui_timer` en salle d'attente (grep : seul appel). Salle publique à revoir au module 9. | Moyenne |
| AW-01 | Web — déverrouillage de l'audio par le navigateur (sans équivalent APK) | Contrainte web | Oui | `AudioManager.gd:48,80-87,134-136` | Oui | Musique demandée mise en attente jusqu'au premier clic / touche / toucher, puis jouée. Les SFX demandés avant ce premier geste sont perdus (sans conséquence : aucun son avant interaction). | — |
| AW-02 | Web — formats | Contrainte web | Oui | `assets/audio/music/*.mp3`, `assets/audio/sfx/*.wav` (import `compress/mode=2`, QOA) | Oui | MP3 conservé pour la musique : Godot le décode lui-même (pas de dépendance aux codecs du navigateur) ; le convertir en Ogg serait un ré-encodage avec perte pour un gain faible. SFX importés compressés (QOA). | Basse |
| AW-03 | Web — mode de lecture `Sample` (Web Audio, défaut Godot 4.3+ sur le web) | Contrainte web | Oui (défaut, aucune surcharge dans `project.godot`) | — | Oui | Le mode Sample ne gère pas les `AudioEffect` : le projet n'en utilise aucun (grep). Volume/sourdine par bus et boucle d'un `AudioStreamWAV` dupliqué en mode Sample : **non vérifiés en navigateur**. | Basse |
| AW-04 | Web — threads | Contrainte web | Oui | `export_presets.cfg:23` (`thread_support=false`) | Oui | Aucun thread audio côté scripts. Le mode Sample est celui recommandé sans threads. | — |

### Résumé module 2

- **32 éléments audités** : 20 OK (dont les 4 contraintes web AW), 3 N/A (A-08, A-09, A-13), **9 écarts** (A-02, A-10, A-12, A-14, A-15, A-21, A-22, A-23, A-28).
- **Bloquants web : 0.** À tester en navigateur : A-10 (onglet masqué), AW-03 (bus et boucle en mode Sample).
- Écarts Moyenne : **A-10** (pas de pause de la musique hors focus), **A-28** (`ui_timer` déplacé de la salle d'attente publique vers le tour de jeu).

### Questions ouvertes (module 2)

1. A-28 : le son `ui_timer` sur le compte à rebours de tour en ligne est-il un ajout voulu ? Sinon il faut le retirer et le rebrancher sur la salle d'attente publique.
2. A-10 : faut-il couper la musique quand l'onglet est masqué (comme l'APK en arrière-plan) ?

---

## Module 3 — Entrées

Source relue : `DBMGame/AndroidActivity.cs` (entier), `LongTouchBehavior.cs`, `TwoLongTouchBehavior.cs` + `MainMenuScene.cs:121-138`, `CarrouselDragBehavior.cs`, `CardCarrouselEntity.cs:118-215`, `CardExtractBehavior.cs`, `CardHoverDetailBehavior.cs`, `PlayerNumberSelectionEntity.cs`, `TextEntryEntity.cs`, `CardAttributesComponent.cs:330-347`, inventaire par grep de **tous** les accès `WaveServices.Input` (touch / souris / clavier) et de tous les `TouchTap +=` (19 sites), utilisateurs de chaque comportement d'entrée (`grep "new <Behavior>"`).
Godot relu : `project.godot` (`[input_devices]`, `window/stretch`), `export_presets.cfg:26-40`, `CardUI.gd:26-32,262-315`, `BoardUI.gd:237,1368-1382,1421-1430,1955-1972,3218-3300,3548-3610,3743-3760`, `Main.gd:380-415`, `OnlineMenus.gd:130-136,313-318,597`, `build_web/index.html`, inventaire grep de tous les `_input` / `_gui_input` / `InputEvent*` / `KEY_*` / `ui_*`.
Doc Godot 4.7 consultée : `EditorExportPlatformWeb.html/experimental_virtual_keyboard`, `LineEdit.virtual_keyboard_enabled`.

| ID | Élément source (décompilé) | Type | Présent dans Godot ? | Fichier Godot | Équivalent fonctionnel ? | Écart / Commentaire | Priorité |
|----|----|----|----|----|----|----|----|
| I-01 | Couche tactile Wave : `TouchPanel` + `TouchGestures` (`TouchPressed/Released/Moved/Tap`), souris prise en compte si `MouseState.IsConnected` (`CardHoverBehavior.cs:124-134`, `SimpleHoverBehavior.cs:60-77`) | Moteur d'entrée | Oui | `project.godot:29-31` (`emulate_touch_from_mouse=true`, `emulate_mouse_from_touch` au défaut `true`), scripts en `InputEventMouse*` | Oui | Le toucher est converti en souris par Godot, tout le code n'écoute que la souris : un seul chemin pour souris et doigt. Comportement réel sur écran tactile **non vérifié sur appareil**. | — |
| I-02 | `ViewportManager.RecoverPosition` : coordonnées écran → résolution virtuelle | Méthode | Oui | `project.godot:23-27` (1920 × 1080, `canvas_items`, `keep_aspect`) | Oui | Conversion faite par le stretch de Godot. | — |
| I-03 | Survol de la main (`CardHoverBehavior`) : la carte sous le doigt (ou la souris) se soulève ; doigt posé = survol | Comportement | Oui | `BoardUI.gd:1740,2002` (`mouse_entered` des cartes), `BoardUI.gd:3275-3291` | Partiel | Souris : conforme. Doigt : le survol n'existe qu'en glissant avec le doigt posé (souris émulée) ; à vérifier sur appareil, car il entre en conflit avec I-04. | Basse (cible souris) |
| I-04 | `CardExtractBehavior` : la carte n'est **extraite** que quand le doigt **monte au-dessus de `upperLimit`** (haut de la main + 50 px, `:47,57-66`) ; redescendre dans la main = reposer ; relâcher = déposer ; carte interdite → `InvalidCardPlayed` ; tutoriel : seule `ForcedToExtractCard` | Comportement | Oui | `BoardUI.gd:237,3578-3610,3743-3760` | Différent | Godot démarre le glisser après **12 px dans n'importe quelle direction** (`DRAG_SLOP`) ; reposer = relâcher sous y 940. Conséquence au doigt : glisser latéralement sur la main pour parcourir les cartes (geste APK) **arrache la carte** dans Godot. La règle du tutoriel est portée (`_tg("drag")`). | Basse (cible souris) |
| I-05 | — (absent de l'APK) Toucher une carte de la main pour la jouer | Ajout Godot | Oui | `BoardUI.gd:3221-3270` (`_on_hand_card_clicked`, `HAND_CLICK_TYPES`) | Différent | Dans l'APK, aucune carte de la main ne réagit au tap (les 19 `TouchTap +=` relus) : on joue uniquement en glissant. Ajout pratique à la souris ; à garder ou retirer selon l'objectif de clone exact. | Basse |
| I-06 | `LongTouchBehavior` 1,0 s sur les cartes du **carrousel** (`CardCarrouselEntity.cs:124`) → `CardDetailEntity` ; annulé par **tout** `TouchMoved` ; le tap est ignoré si l'appui long a eu lieu (`:131`) | Comportement | Oui | `CardUI.gd:28-29,267-312` | Partiel | Durée 1,0 s identique, tap ignoré après appui long conforme. Écarts : annulation seulement au-delà de 12 px ; clic droit = appui long (ajout bureau) ; appliqué aussi à la main, aux salles et aux héros (`BoardUI.gd:1377,1524,1654,1741`). | Basse |
| I-07 | `CardHoverDetailBehavior` (file de héros) : détail **immédiat** du héros sous le doigt posé ou la souris, fondu + échelle 0,8 → 1 en 0,2 s, retiré dès qu'on sort | Comportement | Non (vérifié absent) | `BoardUI.gd:1377-1378` (appui long) | Différent | Godot demande un **appui long de 1 s** sur la carte du héros ; pas de détail au survol. | Moyenne |
| I-08 | `CarrouselDragBehavior` : glisser = 0,004 index/px, recalage `Lerp(…, 0.2)` **par image** (dépend du framerate), seuil 0,05, flèches ← → (`:59-118`) ; utilisé par le choix du nombre de joueurs (horizontal + tap sur les côtés, `PlayerNumberSelectionEntity.cs:21-59,85`) et le zoom de pile de salles (vertical, `SlotDetailEntity.cs:85-88`) ; désactivé au tirage du boss | Comportement | Partiel | `Main.gd:409-411` (zones de tap) | Différent | Nombre de joueurs : **tap seulement**, ni glisser ni flèches. Zoom de pile de salles : **non vérifié**, module 7. | Basse |
| I-09 | `TwoLongTouchBehavior` : deux doigts écartés d'au moins 900 px dans la bande (220, 730, 1000 × 90), 2 s → `UnlockCodeScene` (code « REDEEM CODE ») — `MainMenuScene.cs:121-138` | Geste caché | Non (vérifié absent) | — | — | Accès caché au code mécène / déblocage : lié à IAP/backer, module 10. | Basse |
| I-10 | `TextEntryEntity` : `TextBox` Wave avec boîte de saisie native Android (`MessageBoxTitle` USERNAME / ROOM CODE / REDEEM CODE) — `ChangeNameAvatarScene.cs:81`, `WithFriendsOnlineScene.cs:131`, `UnlockCodeScene.cs:62` | Saisie texte | Oui | `OnlineMenus.gd:130-136` (pseudo, `max_length` 45), `:313-318`, `:597` (code de salle) | Partiel | **Web mobile : `html/experimental_virtual_keyboard=false`** (`export_presets.cfg:31`). D'après la doc 4.7, cette option embarque le clavier virtuel dans la page ; sans elle, un téléphone ou une tablette sans clavier physique **ne peut pas saisir le pseudo ni le code de salle** → menus en ligne inutilisables au doigt. | Basse (cible souris) |
| I-11 | Touche Retour Android → `NavigatedBack()` de chaque scène ouverte, sortie de l'app hors scène (`AndroidActivity.cs:52-71`) | Entrée système | Non (vérifié absent) | — | — | Aucun `ui_cancel` / Échap / `NOTIFICATION_WM_GO_BACK_REQUEST` dans les scripts. Sur le web, le bouton Précédent du navigateur quitte la page au lieu de revenir à l'écran précédent. Échap pourrait jouer ce rôle au clavier. | Moyenne |
| I-12 | Clavier : flèches ← → sur les carrousels (`CarrouselDragBehavior.cs:74-85`) | Entrée clavier | Partiel | `RulesViewer.gd:117-119` (pages des règles seulement) | Différent | Pas de flèches sur les carrousels (nombre de joueurs). | Basse |
| I-13 | Raccourcis de debug : `DebugSceneBehavior` (F1-F6), `DrawCardsDemoBehavior` (Ctrl+S/R/K, 1-4) | Debug | N/A | — | N/A | `DebugSceneBehavior` : aucun utilisateur (grep) ; `DrawCardsDemoBehavior` : seulement dans `CreateTestButtons()` (`GamePlayBaseScene.cs:298`), jamais appelé. Code mort. | — |
| I-14 | `HideWhenTouchBehavior` (bulles, 0,5 s, `BalloonEntity`), `TouchOutBehavior` (fermeture au toucher hors zone : `GamePlayBaseScene`, `MiddleCarrouselEntity`) | Comportement | Partiel | `BoardUI.gd:1962-1966` (le zoom se ferme au clic suivant) | Non vérifié | Fermeture au clic hors zone présente pour le zoom ; bulles et carrousel du milieu : vérification reportée au module 7. | — |
| I-15 | `SimpleHoverBehavior` (survol de la pile de sorts, `SpellBattleEntity`) | Comportement | Non vérifié | — | — | Module 7. | — |
| I-16 | `SimpleSelectorBehavior`, `IsHoverBehavior`, `SettingsSliderControl`/`SettingsSliderBehavior` | Comportement | N/A | — | N/A | Aucun utilisateur dans `DBMGame` (grep). Code mort. | — |
| I-17 | Défilement de la galerie : `ScrollCardBehavior` (← `ScrollListBehavior`, `GalleryScene`) | Comportement | Oui | `CardGallery.gd:93-96,174` (molette + glisser) | Partiel | Glisser et molette présents ; inertie et constantes de défilement non comparées (module 4). | Basse |
| I-18 | `ExpansionScrollComponent` (`ExpansionScene`, `InAppPurchaseScene`) | Comportement | Non vérifié | — | — | Écrans de boutique / extensions : modules 4 et 10. | — |
| I-19 | `TapTask` (le tutoriel attend un tap) + attente de doigt levé (`TutorialBaseScene.cs:92,114`) | Tâche | Oui | `TutorialOverlay.gd:813-815,1091-1092` | Non vérifié en détail | Module 8. | — |
| I-20 | `HandMouseOverBehavior` (survol souris des boutons, `ButtonBaseEntity`) | Comportement | Oui | thème `font_hover_color` (`BoardUI.gd:533,1234-1259`) | Partiel | L'effet visuel exact du survol : module 4. | Basse |
| I-21 | `Window.AddFlags(KeepScreenOn)` (`AndroidActivity.cs:43`) | Système | Non (vérifié absent) | — | — | Web : l'API Screen Wake Lock n'est pas utilisée ; l'écran du téléphone peut se mettre en veille pendant une partie. | Basse |
| I-22 | Paysage forcé (`ScreenOrientation.Landscape`, `AndroidActivity.cs:12-15`) + mode immersif (`HideSoftKeys`) | Système | Non (vérifié absent) | `export_presets.cfg:32,36` (PWA désactivée) | Différent | Aucun verrouillage d'orientation sur le web : téléphone en portrait = jeu en bandeau minuscule (`keep_aspect`). Pas de plein écran automatique. | Basse (cible souris) |
| IW-01 | Web — gestes du navigateur (zoom à deux doigts, défilement de page) | Contrainte web | Oui | `build_web/index.html` (`touch-action: none`, `user-scalable=no`) | Oui | Constaté dans le build présent (daté du 2026-10-17, peut-être antérieur au dernier export) : à revérifier au module 12. | — |
| IW-02 | — (absent de l'APK) Relâchement perdu hors du canvas | Ajout Godot | Oui | `BoardUI.gd:1957-1960,3560-3563` (`NOTIFICATION_WM_MOUSE_EXIT`, perte de focus) | — | Protection propre au navigateur / bureau. | — |

### Résumé module 3

- **24 éléments audités** : 4 OK (I-01, I-02, IW-01, IW-02), 2 N/A (I-13, I-16), **14 écarts** (I-03, I-04, I-05, I-06, I-07, I-08, I-09, I-10, I-11, I-12, I-17, I-20, I-21, I-22), 4 non vérifiés et renvoyés aux modules 4, 7, 8 et 10 (I-14, I-15, I-18, I-19).
- **Cible décidée le 2026-10-26 : jeu à la souris (bureau).** Les écarts propres au toucher (I-03, I-04, I-10, I-22) passent donc en Basse.
- **Bloquants web : 0.**
- Écarts Moyenne : I-07 (détail des héros au survol remplacé par un appui long : concerne aussi la souris), I-11 (pas de retour arrière, Échap).

### Questions ouvertes (module 3)

1. ~~La cible inclut-elle téléphones et tablettes ?~~ Réponse : non, souris uniquement.
2. I-05 : garder le clic pour jouer une carte de la main (ajout) ou s'en tenir au seul glisser de l'APK ?
3. I-11 : faut-il brancher Échap (et éventuellement le bouton Précédent du navigateur) sur le retour arrière de l'APK ?

---

## Module 4 — UI / menus

Méthode : trois lots audités en parallèle par des sous-agents en lecture seule (mêmes règles de preuve : `fichier:ligne` des deux côtés, « vérifié absent » = grep cité). J'ai ensuite recontrôlé à la main les écarts Moyenne et Haute : U-A44, U-A59, U-A70, U-B08, U-B21, U-C01/U-A34, U-C20, U-C28, U-C31. Tous sont confirmés.
Abréviations : APK = `apk-original/decompiled/DBMGame/`, `MG` = `Main.gd`, `CG` = `CardGallery.gd`, `OM` = `OnlineMenus.gd` (tous sous `src/frontend/godot/scripts/`).
Hors lot : le menu PAUSE en partie, `InGameMenu.gd` (dont le curseur de volume S-21) et l'écran de fin de partie relèvent du module 7.

### 4A — Démarrage, menu principal, solo, options, crédits

Source relue : `Game.cs`, `LoadingScene`, `IntroScene`, `MainMenuScene`, `PlayerNumberScene`, `OptionsScene`, `SettingsScene`, `CreditsScene`, `QuitGameScene`, `ConfirmationBoxScene`, `MessageBoxScene`, `NextSceneType`, entités et composants associés, `ControlsFactory`, `DBMBaseScene`, `ButtonBaseEntity`, `StringFactory`. Godot : `MG`, `UiKit.gd`, `CreditsScreen.gd`, `RulesViewer.gd`, `Profile.gd`.

| ID | Élément source (décompilé) | Type | Présent dans Godot ? | Fichier Godot | Équivalent fonctionnel ? | Écart / Commentaire | Priorité |
|----|----|----|----|----|----|----|----|
| U-A01 | Viewport 1440×1080 Uniform, MaxTouchPoints 1 (`Game.cs:39,49`) | Démarrage | Oui | `project.godot:23-27` | Différent | Godot 1920×1080 `keep_aspect` ; coordonnées APK + 240 px, fonds étirés. Choix du port. | Basse |
| U-A02 | `InitializePurchase` / `AppPurchaseService` / `LocalMarket` (`Game.cs:60-78`) | Démarrage | Non (vérifié absent) | — | — | Boutique retirée volontairement (module 10). | Basse |
| U-A03 | `LoadStorageGameData`, `CheckForcePlayTutorial` (`Game.cs:86-121`) | Démarrage | Oui | `MG:75-80`, `Profile.gd` | — | Voir S-04..S-06, S-10, S-14, S-15. | — |
| U-A04 | Écran de chargement : fond `loading_bg`, couleur #270000 (`LoadingScene.cs:24,31`) | Écran | Partiel | `project.godot:12-14` (splash du moteur) | Partiel | Couleur exacte, mais c'est l'écran de démarrage du moteur et non une scène du jeu. | Basse |
| U-A05 | Sprite « loading » + 3 rupies animées (`LoadingScene.cs:36,44`, `RupisLoadingBehavior.cs:56-80`) | Animation | Non (vérifié absent) | — | — | `loading.webp` présent mais jamais référencé. | Basse |
| U-A06 | Fin du chargement → Intro en fondu noir 1,0 s (`LoadingScene.cs:55-60`) | Transition | Partiel | `MG:84` | Différent | Pas de fondu entre le chargement et le titre. | Basse |
| U-A07 | Retour pendant le chargement = quitter (`LoadingScene.cs:65-67`) | Navigation | Non (vérifié absent) | — | — | Voir I-11. | Basse |
| U-A08 | Fond `intro_bg` (`IntroScene.cs:41`) | Écran | Oui | `MG:239` | Oui | — | — |
| U-A09 | Grand logo `bm_logo`, haut-centre, y 80 (`IntroScene.cs:43`, `ControlsFactory.cs:292-315`) | Élément | Oui | `MG:247` | Oui | Écart ≤ 3 px. | — |
| U-A10 | Bougies (380 ; 680) et (1050 ; 680), statiques (`IntroScene.cs:45,47`) | Élément | Oui | `MG:240-243` | Oui | — | — |
| U-A11 | Yeux du monstre, clignement de 5 s (`IntroScene.cs:54-55`, `BlinkBehavior.cs:42-63`) | Animation | Oui | `MG:200-204,244-246` | Oui | — | — |
| U-A12 | « TAP TO START » arcadepix ×2, #bfca7a, clignement 0,3 s (`IntroScene.cs:57-59`) | Texte | Oui | `MG:248-251` | Oui | — | — |
| U-A13 | Tap n'importe où → menu principal, fondu noir 1,0 s, sans son (`IntroScene.cs:107-112`) | Navigation | Oui | `MG:112-126,252` | Oui | 0,5 + 0,5 s, entrées bloquées pendant le fondu. | — |
| U-A14 | `music_main` à l'intro (`IntroScene.cs:84`) | Son | Oui | `MG:238,276` | Oui | Voir A-16. | — |
| U-A15 | Retour à l'intro → `QuitGameScene` → quitter (`IntroScene.cs:117-120`) | Navigation | Non (vérifié absent) | — | — | Sans objet dans un navigateur ; voir I-11. | Basse |
| U-A16 | Boîte « QUIT GAME? » / « ARE YOU SURE YOU WANT TO QUIT? », boutons CANCEL / QUIT (`QuitGameScene.cs:16-27`) | Texte | Partiel | `BoardUI.gd:4338-4342` | Différent | Godot : « Quit to menu? The current game will be lost », YES, QUIT / NO, KEEP PLAYING, dans une liste et non dans la boîte à 2 boutons. | Moyenne |
| U-A17 | `NextSceneType` (SinglePlayer, PassAndPlay, OnlinePublic, OnlinePrivate) | Enum | Partiel | `MG:341-342` | Partiel | Le mode « public » de Godot est un salon listé (voir U-C08). | Basse |
| U-A18 | Transitions : modale 0,2 s, normale 1,0 s (`DBMBaseScene.cs:17,19`) | Timing | Oui | `MG:112-126`, `UiKit.gd:25-27` | Oui | — | — |
| U-A19 | Son du bouton joué **à l'appui** (`ButtonBaseEntity.cs:185,202`) | Son | Oui | `MG:183,196`, `UiKit.gd:97-118` | Partiel | Godot le joue au relâchement (signal `pressed`). | Basse |
| U-A20 | `StayPressed` : le bouton du menu reste enfoncé pendant le fondu (`ButtonBaseEntity.cs:201`) | Visuel | Non (vérifié absent) | `MG:187-198` | Différent | — | Basse |
| U-A21 | Bouton à décor : +3 px à l'appui, −3 px au relâchement (`ButtonWithDecoratorEntity.cs:47-57`) | Visuel | Oui | `MG:265-270` | Partiel | L'APK finit 3 px plus haut ; Godot revient à l'origine. | Basse |
| U-A22 | Texte de bouton blanc, or #cdb15f à l'appui (`ButtonWithLabelEntity.cs:21,32`) | Visuel | Oui | `UiKit.gd:111-116` | Oui | — | — |
| U-A23 | `HandMouseOverBehavior` (main au survol) | Comportement | N/A | — | N/A | Code mort : désactivé à la création, jamais réactivé. | — |
| U-A24 | Flèche retour `back_bt` (80 ; 70), son `ui_button_goback` (`ControlsFactory.cs:232-254`) | Élément | Oui | `MG:224-225` | Oui | — | — |
| U-A25 | Bouton OK, marges 120 / 70 (`ControlsFactory.cs:261-277`) | Élément | Oui | `MG:231-232` | Oui | — | — |
| U-A26 | Torches statiques, fond `menu_bg` (`ControlsFactory.cs:281,330-344`) | Élément | Oui | `MG:206-219` | Partiel | Positions justes ; Godot ajoute un scintillement alpha 0,78 ↔ 1. | Basse |
| U-A27 | Petit logo `logo_small` 688×318, y 10 (`ControlsFactory.cs:292-315`) | Élément | Partiel | `MG:220-223` | Différent | Godot réduit `bm_logo` (540×218), sans le halo de `logo_small`. | Basse |
| U-A28 | Logos « legend » si mécène (`ControlsFactory.cs:296-300`) | Élément | Non (vérifié absent) | — | — | Voir S-16. | Basse |
| U-A29 | Flèche du menu principal → intro, fondu 1,0 s (`MainMenuScene.cs:50-55,201`) | Navigation | Oui | `MG:277` | Oui | — | — |
| U-A30 | 4 boutons du menu principal : positions, icônes, texte ×1,5 (`MainMenuScene.cs:60-120`) | Élément | Oui | `MG:258-281` | Oui | — | — |
| U-A31 | SINGLE PLAYER : boîte TUTORIAL au premier lancement (`MainMenuScene.cs:62-84`) | Navigation | Oui | `MG:287-293,335-339` | Oui | Voir S-14. | — |
| U-A32 | `ConfirmationBoxScene` : voile 0,7, `winner_bg`, boutons à 0,35 / 0,65 L et 0,56 H (`:72-125`) | Écran | Oui | `MG:297-332` | Oui | — | — |
| U-A33 | Texte du bouton décalé de 3 px à l'appui (`ButtonWithLabelEntity.cs:25-28`) | Visuel | Non (vérifié absent) | `MG:323-326` | Partiel | — | Basse |
| U-A34 | MULTIPLAYER → `MenuOnlineScene` **directement** (`MainMenuScene.cs:93-104`) | Navigation | Oui | `MG:279` → `OM:172-180` | Différent | Godot intercale l'écran `MultiplayerScene` (PLAY ONLINE / PASS AND PLAY), code mort dans l'APK. Même constat que U-C01. | Moyenne |
| U-A35 | OPTIONS, fondu 1,0 s (`MainMenuScene.cs:107-113`) | Navigation | Oui | `MG:280` | Oui | — | — |
| U-A36 | IN-APP STORE → `InAppPurchaseScene` (`MainMenuScene.cs:114-120`) | Élément | Non (remplacé par RULES) | `MG:281` | Différent | Boutique retirée (voir U-B50). | Basse |
| U-A37 | Bande secrète, appui long à deux doigts de 2 s → `UnlockCodeScene` (`MainMenuScene.cs:121-139`) | Élément | Non (vérifié absent) | — | — | Voir I-09, U-B53. | Basse |
| U-A38 | `ShowButtons` (glissé BackEase 0,2 s) (`MainMenuScene.cs:176-197`) | Animation | N/A | — | N/A | Atteint seulement par le geste de déblocage : mort sans lui. | — |
| U-A39 | Bandeau « HOW MANY PLAYERS? » (`PlayerNumberScene.cs:29`) | Texte | Oui | `MG:227-229,345` | Oui | — | — |
| U-A40 | Flèche (coupure nette) et OK → extensions (fondu 1,0 s) (`PlayerNumberScene.cs:40,48-53`) | Navigation | Oui | `MG:344,352,380-385` | Oui | — | — |
| U-A41 | Carrousel infini : positions, échelles 0,7 / 0,77, ordre 2-3-4 (`CarrouselInfiniteComponent.cs:34-44`) | Layout | Oui | `MG:388-411` | Oui | Interaction : voir I-08. | — |
| U-A42 | Éventails de boss par nombre de joueurs : 2 (BMA006, 002), 3 (007, 004, 005), 4 (007, 002, 001, 006) (`ControlsFactory.cs:379-427`) | Visuel | Partiel | `MG:47,413-433` | Différent | Le nombre de cartes ne suit pas 2 / 3 / 4 joueurs (2 cartes si sélectionné, 3 sinon). | Moyenne |
| U-A43 | Animations du carrousel : lerp 0,2 par image, échelle 0,7 → 1 en 0,3 s, fondus du chiffre (`PlayerNumberDeckEntity.cs:73-98`) | Animation | Non (vérifié absent) | `MG:392-411` | — | Changement de sélection instantané. | Basse |
| U-A44 | Sons du carrousel : `ui_shuffle_left` / `ui_shuffle_right` à chaque cran (`CarrouselComponent.cs:123-131`) | Son | Oui | `MG:175-185,409` | Différent | **Contrôlé** : `_hit` joue `ui_button_select` par défaut. Mauvais son. Complète A-22. | Moyenne |
| U-A45 | Chiffre central arcadepix ×3 (63 px), chiffres latéraux ×2 (`PlayerNumberSelectionEntity.cs:57-60`) | Texte | Oui | `MG:405-408` | Partiel | Police `FONT_B` 56 px au centre ; calé sur une capture. | Basse |
| U-A46 | Sélection initiale = 2 joueurs à chaque entrée (`PlayerNumberScene.cs:32`) | État | Oui | `MG:56,346` | Différent | Godot mémorise le dernier choix. | Basse |
| U-A47 | Version gratuite : paquets 3 / 4 grisés, « FULL GAME NEEDED! » (`PlayerNumberSelectionEntity.cs:104-120`) | Condition | Non | — | — | Tout est débloqué (décision connue). | Basse |
| U-A48 | — (absent de l'APK) 5 et 6 joueurs avec Crash Landing | Ajout Godot | Oui | `MG:346-348,388-389` | — | — | Basse |
| U-A49 | OPTIONS : 4 boutons TUTORIAL / SETTINGS / CARD GALLERY / CREDITS (`OptionsScene.cs:55-93`) | Écran | Oui | `MG:596-613` | Oui | — | — |
| U-A50 | TUTORIAL → tutoriel sans transition (`OptionsScene.cs:64-66`) | Navigation | Oui | `MG:598-601` | Oui | — | — |
| U-A51 | SETTINGS, fondu 1,0 s (`OptionsScene.cs:74-79`) | Navigation | Oui | `MG:604-607` | Oui | — | — |
| U-A52 | CARD GALLERY, fondu 1,0 s ; retour en coupure nette (`OptionsScene.cs:87-89`) | Navigation | Oui | `MG:610-612`, `CG:289-291` | Oui | — | — |
| U-A53 | CREDITS sans transition ; boutons et logo glissent et s'estompent puis reviennent (`OptionsScene.cs:99-103,132-153`) | Animation | Partiel | `MG:615-618,647-654` | Partiel | Masquage instantané ; au retour, fondu noir 1,0 s sans glissé. | Basse |
| U-A54 | Flèche d'OPTIONS : coupure nette (`OptionsScene.cs:48`) | Navigation | Oui | `MG:584-589` | Oui | — | — |
| U-A55 | SETTINGS : lignes MUSIC / SOUND / GAME SPEED à y 360 / 480 / 600 (`SettingsScene.cs:68-97`) | Écran | Oui | `MG:639-643,657-680` | Oui | Valeurs : S-04..S-06. | — |
| U-A56 | Segments de 204 px, ninepatch `settings_text_bg`, bulle 204×110, polices ×1,4 (`SettingButtonDecorator.cs:21,71,102-112`) | Visuel | Partiel | `MG:663-680` | Différent | 202 px, aplat de couleur au lieu du ninepatch, tailles de police différentes. | Basse |
| U-A57 | Valeur sélectionnée : texte doré décalé de −5 px sur un texte blanc (`SettingButtonInfo.cs:57`) | Visuel | Non (vérifié absent) | `MG:676` | Partiel | — | Basse |
| U-A58 | Son seulement si l'option change, à l'appui (`SettingButtonDecorator.cs:132`) | Son | Oui | `MG:678-680` | Partiel | Joué à chaque clic, même sur l'option déjà choisie. | Basse |
| U-A59 | Flèche de SETTINGS : `SaveChanges` puis `Pop()` **sans transition** (`SettingsScene.cs:133-145`) | Navigation | Oui | `MG:638-640` | Différent | **Contrôlé** : Godot fait un fondu noir de 1,0 s ; le commentaire `MG:637` cite à tort `:136`. | Moyenne |
| U-A60 | Ligne LEGENDARY MODE si mécène (`SettingsScene.cs:98-108`) | Élément | Non (vérifié absent) | — | — | Voir S-08. | Basse |
| U-A61 | Crédits : `credits.json` (logo, 14 éléments, pied), mise en forme (`CreditsScene.cs:50,119-228`) | Écran | Oui | `CreditsScreen.gd:136-139,168-248` | Oui | Fichier identique à celui de l'APK. | — |
| U-A62 | Défilement des crédits : 0,1 px/ms, délais et bornes (`CreditRollBehavior.cs:38-77`) | Timing | Oui | `CreditsScreen.gd:15-22,38-61,104-108` | Oui | — | — |
| U-A63 | Voile 0,7, glisser actif après 8,8 s, bornes (`CreditsScene.cs:46-49,115-166`) | Comportement | Oui | `CreditsScreen.gd:77-83,110-125` | Oui | — | — |
| U-A64 | Flèche des crédits, fondu 1,0 s, `ui_button_goback` (`CreditsScene.cs:129-133`) | Navigation | Oui | `CreditsScreen.gd:94-102` | Oui | — | — |
| U-A65 | `MessageBoxScene` : titre, message, OK, fondu enchaîné 0,2 s (`:70-152`) | Écran | Oui | `OM:89-125` | Oui | — | — |
| U-A66 | Pseudo par défaut « player_ » + `RndWord(4)` sur a-z1-9, avatar `Random.Next(9)` (`StringFactory.cs:20-28`) | Donnée | Oui | `Profile.gd:38-43` | Oui | Alphabet identique : **S-13 clos**. | — |
| U-A67 | Cercle de 10 rupies, rayon 160, 1 s par cran, interpolation en corde (`CircleOfRotatingRupisBehavior.cs:26-64`) | Animation | Oui | `GameOverBanner.gd:12-14,70-76` | Partiel | Godot tourne en arc continu ; rayon ≈ −5 % à mi-cran dans l'APK. | Basse |
| U-A68 | — (absent de l'APK) Écran RULES à la place de la boutique | Ajout Godot | Oui | `MG:281,683-689` | — | — | Basse |
| U-A69 | — Visionneuse des règles (4 livrets, onglets, flèches, molette) | Ajout Godot | Oui | `RulesViewer.gd:12-157` | — | — | Basse |
| U-A70 | — Case « Wiki expansions (not in the APK) » | Ajout Godot | Oui | `MG:620-628`, `Profile.gd:77,83` | — | **Contrôlé** : cochée par défaut (`Profile.gd:77,83` = `true`, alors que `MG:78` prévoit `false`). Au premier lancement, des contenus hors APK s'affichent (tuiles wiki, cartes wiki dans la galerie, mention 5-6 joueurs). | Moyenne |
| U-A71 | — Champ « Multiplayer server » (bureau seulement) | Ajout Godot | Oui | `MG:76,629-636` | — | Masqué sur le web. | Basse |
| U-A72 | — Survol des boutons pierre (teinte) | Ajout Godot | Oui | `UiKit.gd:108-109` | — | Le survol de l'APK est du code mort (U-A23). | Basse |
| U-A73 | — Déverrouillage audio au premier clic | Ajout Godot | Oui | `AudioManager.gd:48,63-70` | — | Voir AW-01. | — |

### 4B — Galerie, détail de carte, extensions, écrans de boutique

Source relue : `GalleryScene`, `CardDetailScene`, `ExpansionScene`, `InAppPurchaseScene`, `PurchaseScene`, `UnlockScene`, `UnlockCodeScene`, `ScrollCard*`, `ScrollListBehavior`, `ExpansionScrollComponent`, `CardDetailEntity`, `CardEntity`, `LocalMarket`, `PurchaseItemButton`. Godot : `CG`, `MG`, `CardUI.gd`, `CardDB.gd`, `InGameMenu.gd`.

| ID | Élément source (décompilé) | Type | Présent dans Godot ? | Fichier Godot | Équivalent fonctionnel ? | Écart / Commentaire | Priorité |
|----|----|----|----|----|----|----|----|
| U-B01 | Entrée depuis OPTIONS, fondu 1,0 s (`OptionsScene.cs:83-90`) | Navigation | Oui | `MG:104-125,608-612` | Oui | — | — |
| U-B02 | Entrée depuis PAUSE, fondu enchaîné 0,2 s (`PauseScene.cs:61-70`) | Navigation | Oui | `InGameMenu.gd:106-115` | Oui | — | — |
| U-B03 | CARD GALLERY masqué dans le menu PAUSE en partie en ligne (`PauseScene.cs:30,41,61`) | Condition | Non (vérifié absent) | `InGameMenu.gd:43` | Différent | Godot l'affiche aussi en ligne. | Basse |
| U-B04 | Flèche retour : coupure nette, ou fermeture si on vient du jeu, `ui_button_goback` (`GalleryScene.cs:93-98,335-345`) | Navigation / son | Oui | `CG:62-64,285-291` | Oui | — | — |
| U-B05 | Décor et titres BOSS / ROOM / SPELL / HERO / EPIC HERO CARDS (`GalleryScene.cs:99-149,363-392`) | UI / textes | Oui | `CG:19-20,45-61` | Oui | — | — |
| U-B06 | 5 onglets (dos de la 1re carte de chaque type), ordre Boss, Room, Spell, Hero, Epic (`GalleryScene.cs:177-210`) | UI | Oui | `CG:19-20,75-86` | Oui | — | — |
| U-B07 | Défilement vertical des onglets : course 596 px + 100 px de dépassement, ressort (`GalleryScene.cs:184-198`, `ScrollListBehavior.cs:207-252`) | Défilement | Partiel | `CG:66-74` | Différent | Course de 220 px, sans dépassement élastique. | Basse |
| U-B08 | `ui_button_select` à chaque changement d'onglet (`GalleryScene.cs:352`) | Son | Non (vérifié absent) | `CG:124-185` | — | **Contrôlé** : le changement d'onglet est muet dans Godot. | Moyenne |
| U-B09 | Transition entre onglets : fondu de sortie 0,5 s puis d'entrée 0,5 s, toucher bloqué pendant le fondu (`GalleryScene.cs:395-436`) | Transition | Non (vérifié absent) | `CG:124-185` | — | Godot reconstruit la grille instantanément. | Moyenne |
| U-B10 | Onglet touché : échelle 0,37 → 0,42 en 0,2 s, cadre jaune en fondu 0,5 s (`GalleryScene.cs:190-191`, `ScrollItemComponent.cs:42-66`) | Animation | Partiel | `CG:124-137,189-208` | Partiel | Fondu du cadre présent ; changement de taille instantané ; l'ancien cadre disparaît d'un coup. | Basse |
| U-B11 | Onglet BOSS sélectionné à l'ouverture (`GalleryScene.cs:471-475`) | Comportement | Non (vérifié absent) | `CG:99,122-123` | Non vérifié | Aucun cadre à l'ouverture côté Godot ; la capture APK de référence encadre HERO : source et capture se contredisent. | Basse |
| U-B12 | Paquets affichés : base, Player Choice, puis Hidden Heroes ; BMA023 et BMA033 masquées (`GalleryScene.cs:153-156`, `CardInfoService.cs:19,58-65,184`) | Filtre | Oui | `CG:15-16,102-120` | Oui | Comptes recoupés dans `cards.json`. | — |
| U-B13 | — (absent de l'APK) Cartes des extensions wiki dans la galerie | Ajout Godot | Oui | `CG:104-105` | — | Affichées par défaut (voir U-A70). | Basse |
| U-B14 | Tri par numéro de carte décroissant, héros ordinaires / épiques séparés (`GalleryScene.cs:157-176`) | Ordre | Oui | `CG:112-119` | Oui | — | — |
| U-B15 | Une tuile par art alternatif pour salles et sorts (`ScrollCardBehavior.cs:40-82`) | Contenu | Oui | `CG:6-7,146-155` | Oui | Fichiers `b.webp` cohérents avec `AlternativeArts` de `data.json`. | — |
| U-B16 | Tuile héros : carte + personnage à y −10 (`ScrollCardBehavior.cs:114-127`) | Rendu | Oui | `CG:163` | Oui | Image déjà composée. | — |
| U-B17 | Grille : 2 lignes, case 310×410, échelle 0,8 (`GalleryScene.cs:177,438-455`) | Layout | Oui | `CG:21-22,156-171` | Oui | — | — |
| U-B18 | Défilement horizontal : inertie × 0,9 par image, dépassement de 100 px, ressort 0,4, bornes `-TotalWidth + 960` (`ScrollListBehavior.cs:193-252`, `GalleryScene.cs:452-453`) | Défilement | Partiel | `CG:87-91` | Différent | `ScrollContainer` natif : course plus courte d'environ 390 px, ni dépassement ni ressort. Complète I-17. | Moyenne |
| U-B19 | — (absent de l'APK) Molette de la souris | Ajout Godot | Oui | `CG:92-97` | — | 220 px par cran ; risque de double défilement non testé. | Basse |
| U-B20 | Tap sur une carte : sélection (0,8 → 0,85, 0,2 s), cadre jaune 0,5 s, puis détail ; la sélection est gardée par onglet (`ScrollListBehavior.cs:160-183`) | Interaction | Partiel | `CG:173-181,210-227` | Partiel | Courbes linéaires au lieu de cubiques ; sélection perdue au changement d'onglet. | Basse |
| U-B21 | Détail : la carte 350×488 va au centre et passe à l'**échelle 1,8** en 0,2 s, soit 630×878 (`CardDetailScene.cs:84-91`, `CardEntity.cs:56`) | Animation | Partiel | `CG:230-278` (`CARD * 1.8`) | Différent | **Contrôlé** : Godot multiplie la tuile (280×400) par 1,8, soit **504×720, 0,8× la taille APK** ; courbe quadratique au lieu de linéaire. | Moyenne |
| U-B22 | Voile noir 0,7 dès l'ouverture, cadre `card_border_yellow` en fondu 0,3 s (`CardDetailScene.cs:45,87`) | Rendu | Partiel | `CG:240-261,274` | Partiel | Voile en fondu 0,2 s ; cadre doré dessiné au lieu du sprite. | Basse |
| U-B23 | `ui_button_select` à l'ouverture du détail (`CardDetailScene.cs:88`) | Son | Oui | `CG:233` | Oui | — | — |
| U-B24 | `ui_button_goback` à la fermeture du détail (`CardDetailScene.cs:74`) | Son | Non (vérifié absent) | `CG:263-267,280-283` | — | Fermeture muette. | Moyenne |
| U-B25 | Fermeture : tap sur le fond ou sur la flèche posée par-dessus le voile ; retour animé 0,2 s (`CardDetailScene.cs:53-56,69-82`) | Interaction | Oui | `CG:263-267,271-283` | Partiel | Tout clic ferme ; la flèche de la galerie reste assombrie sous le voile. | Basse |
| U-B26 | Pas de retournement dans le détail | Comportement | Oui | `CG:230-269` | Oui | — | — |
| U-B27 | — (absent de l'APK) Infobulle avec le nom de la carte | Ajout Godot | Oui | `CG:168` | — | — | Basse |
| U-B28 | `CardDetailEntity` (zoom du carrousel de boss, `CardCarrouselEntity.cs:214`) | Entité | Non vérifié | — | — | Hors galerie : module 7. | — |
| U-B29 | `ScrollCardComponent.DisableScale` | Propriété | N/A | — | N/A | Jamais lue. | — |
| U-B30 | Citations APK dans les commentaires de `CG` | Traçabilité | — | `CG:123,131,178,188` | Différent | 4 citations fausses (lignes décalées). | Basse |
| U-B31 | Solo : HOW MANY PLAYERS → SELECT EXPANSIONS, fondu 1,0 s (`PlayerNumberScene.cs:52`) | Navigation | Oui | `MG:352` | Oui | — | — |
| U-B32 | Pass and Play : extensions directement, 2 joueurs fixes (`MultiplayerScene.cs:77`) | Navigation | Oui | `OM:180`, `MG:352` | Différent | Chemin mort dans l'APK (U-C01) ; Godot ajoute le choix 2 à 6. | Basse |
| U-B33 | En ligne : `ExpansionScene(0, OnlinePublic/OnlinePrivate)` (`ExpansionScene.cs:129-160`) | Navigation | Partiel | `OM:292,629` | — | Voir U-C08, U-C11. | — |
| U-B34 | Décor `multiplayer_bg` sans torches en ligne (`ExpansionScene.cs:76-103`) | UI | Partiel | `MG:213-218,448-449` | Différent | Godot garde `menu_bg` et les torches. | Basse |
| U-B35 | « SELECT EXPANSIONS », flèche (coupure nette), OK lance la partie (`ExpansionScene.cs:49-52,93-128`) | UI / navigation | Oui | `MG:227-232,449-464` | Oui | — | — |
| U-B36 | Liste : Power-Up Pack, Tools of Hero Kind, The Player Choice, Hidden Heroes (`LocalMarket.cs:23,108-147`) | Contenu | Partiel | `MG:15-28,463-477` | Différent | Godot ajoute une tuile BOSS MONSTER en tête, retire Power-Up Pack, ajoute les paquets wiki. | Basse |
| U-B37 | Power-Up Pack : bande COMING SOON, non sélectionnable (`LocalMarket.cs:109-117`) | État | Non (vérifié absent) | — | — | Assets présents, inutilisés. | Basse |
| U-B38 | Tools of Hero Kind : COMING SOON, grisé (`LocalMarket.cs:119-127`) | État | Partiel | `MG:12,480-489` | Différent | Jouable dans Godot (avec l'option wiki), sans bande. Choix délibéré. | Basse |
| U-B39 | The Player Choice : achat requis ; texte « An 11-card digital mini-expansion… » (`LocalMarket.cs:129-139`) | État / texte | Partiel | `MG:17` | Différent | Toujours sélectionnable ; texte réécrit. | Basse |
| U-B40 | Hidden Heroes : verrouillé jusqu'à 40 victoires (`LocalMarket.cs:138-147`) | État | Partiel | `MG:18` | Différent | Voir S-12. L'APK affiche « 40 NEW HEROES » pour 41 cartes. | Basse |
| U-B41 | Sélection d'une tuile : `bg_expansion_selected`, échelle 1,0 → 1,1 en 0,3 s, **aucun son** (`PurchaseItemButton.cs:45-58`) | Animation / son | Partiel | `MG:175-184,480-506` | Partiel | Pas d'agrandissement ; Godot joue `ui_button_select`, absent de l'APK. | Basse |
| U-B42 | Tuiles alignées à gauche, défilement horizontal dès 4 tuiles (`ExpansionScrollComponent.cs:84-240`) | Layout | Non (vérifié absent) | `MG:466-477` | Différent | Godot centre les tuiles et les réduit à 0,72 au-delà de 4, sans défilement. | Basse |
| U-B43 | Lignes sous la tuile : « + 7 NEW BOSSES », « + 3 NEW HEROS »… (`+` et nombre en or) (`PurchaseItemButton.cs:94-103`) | Texte | Non (vérifié absent) | `MG:495-496` | Différent | Godot affiche une phrase blanche (« 7 bosses, 3 epic heroes, 1 spell »). | Moyenne |
| U-B44 | Descriptions longues (`Info`, `DetailsExpanded`) montrées par `PurchaseScene` | Texte | Partiel | `MG:509-533` (popup « ? ») | Différent | Popup absent de l'APK, avec des textes réécrits au lieu de ceux de `LocalMarket`. | Moyenne |
| U-B45 | Couvertures `full_game_front`, `tools_of_hero_front`, `the_players_choice_front`, `hidden_heroes_front` | Assets | Oui | `MG:487,527` | Oui | — | — |
| U-B46 | — (absent de l'APK) Tuile BOSS MONSTER du jeu de base | Ajout Godot | Oui | `MG:468,480-483` | — | — | Basse |
| U-B47 | — (absent de l'APK) Tuiles des extensions wiki | Ajout Godot | Oui | `MG:20-27,445-447` | — | Affichées par défaut (U-A70). | Basse |
| U-B48 | — Choix des paquets mémorisé entre sessions (l'APK repart de zéro) | Ajout Godot | Oui | `MG:79,504`, `Profile.gd:88-95` | — | — | Basse |
| U-B49 | — Message d'erreur 5-6 joueurs | Ajout Godot | Oui | `MG:475-477` | — | — | Basse |
| U-B50 | `InAppPurchaseScene` : catalogue de 4 produits avec prix (`LocalMarket.StoreItems`) | Écran | Non (vérifié absent) | — | — | Boutique retirée. | Basse |
| U-B51 | `PurchaseScene` : fiche d'extension, « N WINS TO UNLOCK! », bouton PURCHASE (`PurchaseScene.cs:111-180`) | Écran | Non (vérifié absent) | — | — | Boutique retirée ; voir S-12. | Basse |
| U-B52 | `UnlockScene` : « CONGRATULATIONS! YOU'VE UNLOCKED… » (son `ui_purchase`), « FULL GAME NEEDED! » + BUY NOW! (`UnlockScene.cs:137,167`) | Écran | Non (vérifié absent) | — | — | Boutique retirée ; voir S-12, A-15. | Basse |
| U-B53 | `UnlockCodeScene` : saisie « INSERT REDEEM CODE », validation serveur, 4 messages d'erreur (`UnlockCodeScene.cs:60,98-139`) | Écran | Non (vérifié absent) | — | — | Voir I-09. | Basse |
| U-B54 | `MyScene` (debug) | Debug | N/A | — | N/A | Seul accès par un bouton `DEBUG_ELEM`. | — |

### 4C — Menus multijoueur (interface et parcours ; protocole au module 9)

Source relue : `MultiplayerScene`, `MainMenu.Online/*`, `MainMenu.Online.Entities/*`, `AvatarScrollComponent`, `OnlineAvatarComponent`, `OpponentsExpandBehavior`, gestionnaire MULTIPLAYER de `MainMenuScene`, messages de `OnlineService` / `DBMBaseScene`. Godot : `OM`, `MG`, `Profile.gd`, `OnlineClient.gd`, `CountDown.gd`, `server/Server.gd` (lecture seule).

| ID | Élément source (décompilé) | Type | Présent dans Godot ? | Fichier Godot | Équivalent fonctionnel ? | Écart / Commentaire | Priorité |
|----|----|----|----|----|----|----|----|
| U-C01 | `MultiplayerScene` (PLAY ONLINE / PASS AND PLAY) : **aucun appelant** (`MultiplayerScene.cs:37-93`) | Écran | Oui (ajout de fait) | `MG:279`, `OM:173-180` | Différent | **Contrôlé** : grep `MultiplayerScene` ne trouve que son propre fichier. Godot intercale un écran que l'APK n'affiche jamais. | Moyenne |
| U-C02 | Pseudo vide → `ChangeNameAvatarScene(canGoBack:false)` avant le menu en ligne (`MainMenuScene.cs:93-104`) | Flux | Oui | `OM:176-179`, `Profile.gd:33-35` | Partiel | Test fait sur PLAY ONLINE ; `has_profile()` teste la présence de la clé et non une valeur non vide. | Basse |
| U-C03 | Éventails de boss et ouverture animée (`MultiplayerScene.cs:41-47`, `OpponentsExpandBehavior.cs`) | Composant | Oui | `OM:165-238` | N/A | Écran mort côté APK. | — |
| U-C04 | PASS AND PLAY, 2 joueurs (`MultiplayerScene.cs:70-90`) | Fonction | Oui (ajout de fait) | `OM:180`, `MG:343-352,449-458` | Différent | Inatteignable dans l'APK ; Godot propose 2 à 6 joueurs. | Basse |
| U-C05 | Verrou `isFullGameAvailable` (`MultiplayerScene.cs:50-114`) | Logique | Non (vérifié absent) | — | N/A | Code mort. | — |
| U-C06 | `MenuOnlineScene` : WORLDWIDE / WITH FRIENDS / CHANGE USER/AVATAR, positions, fondu 1 s (`MenuOnlineScene.cs:35-75`) | Écran | Oui | `MG:112-130`, `OM:242-246` | Oui | — | — |
| U-C07 | Flèche du menu en ligne : déconnexion puis `Pop` sans transition (`MenuOnlineScene.cs:85-91`) | Flux | Oui | `OM:243` | Partiel | Revient à l'écran U-C01 et non au menu principal. | Basse |
| U-C08 | WORLDWIDE : appariement automatique (rejoint une salle publique compatible ou en crée une de 4) → salle d'attente (`MenuOnlineScene.cs:43-49`, `OnlineService.cs:631-644`) | Flux | Différent | `OM:244,252-302,445-461` | Différent | Godot affiche une liste de salons publics (JOIN) et CREATE PUBLIC GAME : pas d'appariement automatique. **Décision 2026-10-26 : multijoueur en salons uniquement.** | Basse |
| U-C09 | Erreur « Unable to join public rooms » sans paquets (`MenuOnlineScene.cs:50-53`) | Message | Non | — | N/A | Branche inatteignable ; le commentaire `OM:9` qui la décrit est faux. | — |
| U-C10 | WITH FRIENDS : NEW GAME / ROOM CODE, champ et OK en fondu (`WithFriendsOnlineScene.cs:44-126`) | Écran | Oui | `OM:592-630` | Oui | — | — |
| U-C11 | NEW GAME → extensions → salle privée de 4, sans choix du nombre de joueurs (`WithFriendsOnlineScene.cs:68-82`) | Flux | Oui | `OM:626-663`, `MG:343-352,455-459` | Partiel | Godot ajoute HOW MANY PLAYERS (2 à 6) ; après une erreur, retour à WITH FRIENDS au lieu de rester sur les extensions. | Basse |
| U-C12 | Erreur « Unable to create a private room » (`WithFriendsOnlineScene.cs:77-80`) | Message | Non | — | N/A | Branche inatteignable. | — |
| U-C13 | Champ ROOM CODE : « INSERT ROOM CODE », sans limite, sensible à la casse (`WithFriendsOnlineScene.cs:131-136`) | Saisie | Oui | `OM:595-606` | Partiel | Godot limite à 4 caractères et passe en majuscules. | Basse |
| U-C14 | Code de salle : 4 caractères a-z1-9 en minuscules (`OnlineService.cs:900-912`, `StringFactory.cs:20-29`) | Donnée | Oui | `server/Server.gd:14-15,292-297` | Différent | Godot : 4 lettres majuscules sans I ni O, pas de chiffres. | Basse |
| U-C15 | Erreurs de jonction : « Invalid Code », « Room is full », « Unable to join private room » (`DBMBaseScene.cs:69-83`) | Message | Oui | `OM:665-682` | Oui | — | — |
| U-C16 | Erreur « Expansions not match » (`OnlineService.cs:661-666,936-937`) | Message | Non (vérifié absent) | — | — | Pas de contrôle des extensions possédées (sans achats, sans objet). | Basse |
| U-C17 | `TextEntryEntity` : cadre actif / inactif, texte d'aide effacé au focus, clic hors champ (`TextEntryEntity.cs:77-147`) | Composant | Oui | `OM:128-161` | Oui | Clavier virtuel : I-10. | — |
| U-C18 | `ChangeNameAvatarScene` : « INSERT USERNAME », « SELECT AVATAR », flèche seulement si retour possible (`ChangeNameAvatarScene.cs:53-113`) | Écran | Oui | `OM:568-588` | Oui | — | — |
| U-C19 | Pseudo : vide → rien n'est enregistré ; tronqué à 45 (`ChangeNameAvatarScene.cs:41-45,104-109`) | Logique | Oui | `Profile.gd:37-51`, `OM:136,584-587` | Partiel | Godot retire les espaces de bord : un pseudo fait d'espaces est refusé (l'APK l'accepte). | Basse |
| U-C20 | Sélecteur : **8 avatars** hors mécène, 15 pour un mécène (`AvatarScrollComponent.cs:70-74`) | Donnée | Oui | `Profile.gd:12-15`, `OM:579` | Différent | **Contrôlé** : Godot en propose 9, dont `avatar_xyzax`, réservé aux mécènes dans l'APK. | Basse |
| U-C21 | Défilement des avatars : pas de 240, échelles 0,7 / 0,9 en 0,3 s, inertie, bornes (`AvatarScrollComponent.cs:56-191`) | Composant | Oui | `OM:466-565` | Oui | Constantes reprises ; bornes calculées sur 9 avatars au lieu de 8. | Basse |
| U-C22 | `OnlineAvatarComponent` : fonds `avatar_bg` / `avatar_bg_selected`, animation (`OnlineAvatarComponent.cs:27-99`) | Composant | Oui | `OM:497-525` | Oui | — | — |
| U-C23 | Salle d'attente : flèche = quitter la salle + `Pop` (`WaitingRoomBaseScene.cs:79-92,149-154`) | Flux | Oui | `OM:698-700,788-800` | Partiel | Godot retourne à WITH FRIENDS ou à la liste publique au lieu de l'écran précédent. | Basse |
| U-C24 | Panneau des joueurs : en-têtes WINS / DEFEATS, 4 lignes, « WAITING... » (`OnlinePanelEntity.cs:38-99`) | Écran | Oui | `OM:702-747,836-871` | Oui | Comptage : S-11. | — |
| U-C25 | Ligne en or = joueur **mécène** (`OnlinePanelEntity.cs:91`) | Affichage | Oui | `OM:853-871` | Différent | Godot met l'hôte en or ; commentaire `OM:835` faux. | Basse |
| U-C26 | Salle privée : « WAITING FRIENDS... » et « ROOM CODE: » (`WaitingPrivateRoomScene.cs:27-29`, `RoomCodeEntity.cs:15-30`) | Écran | Oui | `OM:727,748-753` | Oui | — | — |
| U-C27 | Bouton OK de la salle privée : hôte seulement, visible à partir de 2 joueurs (`WaitingPrivateRoomScene.cs:30-62`) | Fonction | Oui | `OM:754-758,872-879` | Oui | — | — |
| U-C28 | Salle privée pleine : l'APK attend l'appui sur OK | Flux | Différent | `server/Server.gd:424-425` | Différent | **Contrôlé** : le serveur lance la partie dès que tous les sièges sont pris. | Basse |
| U-C29 | Départ de l'hôte : Photon désigne un nouvel hôte (`WaitingPrivateRoomScene.cs:41-47`) | Flux | Différent | `server/Server.gd:404-407`, `OM:802-810` | Différent | Godot ferme la salle pour tous (« Room closed »). | Moyenne |
| U-C30 | Salle publique : titre « SEARCHING PLAYERS... », pas de bouton OK, pas de code affiché (`WaitingPublicRoomScene.cs:47-52`) | Écran | Différent | `OM:716-727` | Différent | Godot réutilise la salle privée (titre = nom du salon, code et OK affichés). **Décision 2026-10-26 : multijoueur en salons uniquement.** | Basse |
| U-C31 | Minuteries de la salle publique : 45 s dès 2 joueurs, compte à rebours visible sous 10 s, ramené à 10 s à 4 joueurs, lancement automatique ; minuterie globale de 60 à 120 s qui change de salle (`WaitingPublicRoomScene.cs:27-143`) | Fonction | Non (vérifié absent) | — | — | **Contrôlé** (constantes relues). Aucun démarrage automatique : il faut l'hôte, START WITH BOTS ou une salle pleine ; un hôte inactif bloque la salle. **Décision 2026-10-26 : multijoueur en salons uniquement.** Sans appariement automatique, le démarrage automatique n'est plus requis. | Basse |
| U-C32 | `CountDownEntity` (sablier, chiffres or ×3) : **seulement en salle publique** (`CountDownEntity.cs:41-98`) | Composant | Différent | `CountDown.gd:1-50`, `MG:573-576` | Partiel | Godot en fait un décompte de tour en partie. | Basse |
| U-C33 | `ui_timer` en salle publique (`WaitingPublicRoomScene.cs:102-105`) | Son | Différent | `CountDown.gd:48-49` | Différent | **A-28 confirmé.** | Moyenne |
| U-C34 | Déconnexion en salle d'attente : « Unable to join public room » et retour (`WaitingRoomBaseScene.cs:54-61`) | Message | Oui | `OM:802-810` | Partiel | Godot tolère les coupures brèves ; sinon autres messages, et reste parfois dans la salle. | Moyenne |
| U-C35 | Texte « Unable to join public room » (`DBMBaseScene.cs:77-78`) | Message | Oui | `OM:457-461` | Différent | Textes Godot : « Unable to join public game », « Game is full », « This game is no longer open ». | Basse |
| U-C36 | — (absent de l'APK) RESUME après rechargement de la page | Ajout Godot | Oui | `OM:631-632,684-694` | — | Voir S-20. | Basse |
| U-C37 | — START WITH BOTS (sièges vides remplis par l'IA) | Ajout Godot | Oui | `OM:759-762,872-874` | — | — | Basse |
| U-C38 | — Liste publique : filtre, titre de salon modifiable, statuts | Ajout Godot | Oui | `OM:285-334,716-725,780-786` | — | — | Basse |
| U-C39 | — Salles de 5 et 6 joueurs | Ajout Godot | Oui | `OM:25-27,650-653,702-714` | — | L'APK plafonne à 4. | Basse |
| U-C40 | — « SEAT TAKEN ELSEWHERE » (siège repris dans un autre onglet) | Ajout Godot | Oui | `MG:564` | — | — | Basse |

### Commentaires Godot à corriger (citations APK fausses relevées par les trois lots)

`MG:637` (`:136` → `SettingsScene.cs:143`), `MG:279`, `OM:9`, `OM:835`, `CountDown.gd:1`, `Profile.gd:11`, `CG:123,131,178,188`, citation `BlinkBehavior.cs:36-60` (en fait `:42-63`), « `MainMenuScene.cs:84-87` » pour SINGLE PLAYER (en fait `:60`).

### Non vérifié (module 4)

- Positions et tailles au pixel : aucune comparaison de rendu ; seules les coordonnées calculées depuis le code et les captures de `docs/reference/` ont servi.
- U-B11 : onglet sélectionné à l'ouverture de la galerie (la source et la capture se contredisent).
- U-B18 / U-B19 : modèle d'inertie du `ScrollContainer` et double défilement à la molette, non testés.
- U-B21 : la taille du détail est calculée depuis la source ; il n'existe pas de capture APK du détail.
- U-B28 : zoom du carrousel de boss (module 7).
- Fondus réels dans le navigateur : vérifiés dans le code seulement.
- Vu au passage, pour le module 11 : l'image `bmh056.webp` montrerait « Everel the Healer » alors que la description de BMH056 dans `cards.json` commence par « Nick the Masher ».

### Résumé module 4

| Lot | Audités | OK | N/A | Écarts (dont ajouts Godot) | Non vérifiés | Haute | Moyenne |
|---|---|---|---|---|---|---|---|
| 4A | 73 | 33 | 2 | 38 (6) | 0 | 0 | 6 (U-A16, A34, A42, A44, A59, A70) |
| 4B | 54 | 15 | 2 | 34 (7) | 3 | 0 | 7 (U-B08, B09, B18, B21, B24, B43, B44) |
| 4C | 40 | 9 | 4 | 27 (5) | 0 | 0 | 4 (U-C01, C29, C33, C34) |
| **Total** | **167** | **57** | **8** | **99 (18)** | **3** | **0** | **17** |

U-A03 (renvoi) et U-A73 (ajout sans écart) sont comptés dans les OK. U-A34 et U-C01 décrivent le même écart.

- **Bloquants web : 0.**
- **Écart Haute : aucun.** U-C31 (pas de démarrage automatique en salle publique) passe en Basse : le multijoueur se fait en salons uniquement (décision du 2026-10-26).
- **Écarts Moyenne principaux :**
  - Parcours multijoueur : U-C01 / U-A34 (écran mort de l'APK intercalé), U-C29 (pas de passage de l'hôte à un autre joueur).
  - Galerie : U-B21 (détail 0,8× trop petit), U-B08 et U-B24 (sons manquants), U-B09 (pas de fondu entre onglets).
  - Option wiki cochée par défaut (U-A70).

### Questions ouvertes (module 4)

1. U-A70 : l'option « Wiki expansions » doit-elle être décochée par défaut (`Profile.gd:77,83`), pour qu'un premier lancement montre exactement l'APK ?
2. ~~U-C08 / U-C30 / U-C31 : salons au lieu de l'appariement automatique ?~~ Réponse : oui, multijoueur en salons uniquement.
3. U-C01 / U-A34 : faut-il retirer l'écran PLAY ONLINE / PASS AND PLAY (MULTIPLAYER mènerait directement au menu en ligne), et donc le Pass and Play, absent de l'APK ?

---

## Module 5 — Règles (modèle)

Périmètre : `DBMGameModel.Logic*` (moteur `GameBoard`, `Boss`, `DungeonSlot`, système de capacités `Abilities.*`) et les cartes des 4 paquets APK (BaseDeck, PlayerChoice, HiddenHeros, ToolsHeroKind). Les extensions wiki (TNL, RMB, CRL, IOD, THK wiki, Player's Choice wiki) sont hors périmètre : elles ne s'activent que derrière leur case et l'APK ne les connaît pas.

Côté Godot : `src/frontend/godot/scripts/` — `Match.gd` (M), `BossEngine.gd` (BE), `CardDB.gd` (CD), `RoomAbilities.gd` (RA), `SpellEffects.gd` (SE), `SpellTargeting.gd` (ST), `GameManager.gd` (GM). Godot n'a pas de moteur générique de capacités : chaque carte APK est codée par identifiant.

Méthode : lecture croisée du C# et du GDScript (3 lots en parallèle), puis contre-vérification à la main de chaque ligne Haute, puis rejeu de l'oracle APK (`tools/apk-oracle` charge le vrai `DBMGame.dll`, `tools/parity/apk.py` rejoue ses coups dans Godot et compare l'état à chaque point de contrôle).

### 5.0 — Résultats de l'oracle APK (lancés le 2026-10-26 sur `3ef4350`)

| ID | Élément source (décompilé) | Type | Présent dans Godot ? | Fichier Godot | Équivalent fonctionnel ? | Écart / Commentaire | Priorité |
|---|---|---|---|---|---|---|---|
| R-O01 | Parties IA contre IA BaseDeck, graines 1-3, 2-3 joueurs (`apk.py --ai-agreement`) | trace oracle | Oui | `ApkParity.tscn`, `ApkParityTrace.gd` | Oui | **6/6** traces, 0 refus. Accord d'IA : ensemble des coups jouables 100 %, aucun coup « godotOnly » ni « oracleOnly » ; seuls écarts de choix = tirages aléatoires. | — |
| R-O02 | Graines 4-7, 2-4 joueurs | trace oracle | Oui | idem | Oui | **12/12**. 443 décisions ignorées par le harnais, toutes classées (noChoice, abandonnées). | — |
| R-O03 | 4 paquets APK (`--decks BaseDeck,PlayerChoice,HiddenHeros,ToolsHeroKind`) | trace oracle | Oui | idem | Oui | **6/6**. 163 décisions ignorées, classées. | — |
| R-O04 | Graines 10-40, 2-4 joueurs (93 traces, run de stress hors rapport par défaut) | trace oracle | Oui | idem | Oui à 90/93 | **90/93**. Échecs s20-p2 et s28-p3 : l'IA oracle active Dracolich Lair après la sortie du dernier héros, fenêtre qu'un humain n'a pas (`GameBoard.IsAdventureInteractionTurn`, `GameBoard.cs:285-291`). s16-p4 : remélange sur pioche vide, ordre aléatoire absent de la trace. Les trois causes sont documentées dans `tools/parity/README.md:481-485` et reproduites à l'identique ; voir R-D90 pour le petit écart moteur révélé par s16-p4. | Basse |
| R-O05 | Couverture des cartes par les 24 traces par défaut (script sur `oracle-*.json` : `buildRoom`, `playRoomAbility`, `playSpell`, décisions `resolveTarget.owner`) | mesure | — | — | — | Salles construites 31/35, sorts joués 16/18, boss dont la capacité s'est déclenchée 13/15. **Jamais exercés** : BMA023 et BMA033 (jamais distribués par l'APK), BMA053 Teleportation, THK025 (injouable dans l'APK), THK021 et THK023 (salles sans capacité), KSA001 Kirax et KSA005 Scythe (boss jamais tirés). BMA025 All-Seeing Eye est construit mais jamais activé. | Moyenne |

**Limite de l'oracle.** L'oracle ne compare que ce que l'IA APK joue, et le harnais rejoue les coups APK dans Godot : une règle **plus permissive** côté Godot (un coup légal en trop) est invisible, et les chemins que l'IA ne prend pas (Freeze puis construction, Crushinator puis construction, sorts pendant un tour forcé, Soul Harvest sur un épique) ne sont pas mesurés. Les écarts Haute ci-dessous viennent tous de la lecture du code, contre-vérifiée à la main, **non reproduits** par une partie.

### 5A — Moteur de partie (lot D)

Sources : `DBMGameModel.Logic/GameBoard.cs` (GB), `Boss.cs`, `DungeonSlot.cs`, `PlayerInteractionBase.cs`, `GameBoardExtensions.cs`.

| ID | Élément source (décompilé) | Type | Présent dans Godot ? | Fichier Godot | Équivalent fonctionnel ? | Écart / Commentaire | Priorité |
|---|---|---|---|---|---|---|---|
| R-D01 | `GB.NextStep` : machine à 13 phases (GB:15-30, 302-460) | phases | Oui | M:1181-1253, CD:6-14 | Oui | 13 phases APK regroupées en 7 phases Godot ; transitions équivalentes. Exercé par l'oracle. | — |
| R-D02 | Setup_a : 5 salles + 2 sorts, `AvoidMulliganCondition` (GB:333-347, 883-915) | phase | Oui | M:1046-1097 | Oui | Mêmes seuils (≥ 4 avancées ou ≥ 4 du même trésor). Exercé. | — |
| R-D03 | Mulligan sans borne (GB:883-915) | règle | Oui | M:1062 | Oui | Godot borne à 100 itérations ; indiscernable. | Basse |
| R-D04 | Défausse de 2 cartes, main à 5 (GB:917) | phase | Oui | M:1097 | Oui | Exercé. | — |
| R-D05 | Setup_b : construction initiale parallèle | phase | Oui | M:1131, 1142, 1168 | Oui | Exercé. | — |
| R-D06 | Setup_c : révélation puis ExtraBuildPhase | phase | Oui | M:1453 | Oui | Exercé. | — |
| R-D07 | BeginningOfTurn : objets, héros, 1 salle (GB:360-393) | phase | Oui | M:1181-1253 | Oui | Ordre identique. | — |
| R-D08 | Révélation de `Players.Count` héros, morts inclus (GB:1241) | règle | Oui | M:1275-1293 | Oui | Golden dans `tests/goldens.gd`. | — |
| R-D09 | Objets : 1 par tour à 2-4 joueurs (GB:1257-1268) | règle | Oui | M:1263-1273 | Oui | 3 objets à 5-6 joueurs (ajout Godot, R-D83). | — |
| R-D10 | Paquet de héros trié ordinaires puis épiques (GameBoardExtensions:146) | règle | Oui | M:87-96, 122 | Oui | Exercé. | — |
| R-D11 | Paquet de héros épuisé : ni fin ni remélange | règle | Oui | M:2140-2166 | Oui | Identique en mode APK seul. | — |
| R-D12 | Constantes : 5 emplacements, 10 âmes, 5 blessures, main de 5, 2-4 joueurs | constantes | Oui | M:10, M:58, CD:18 | Oui | | — |
| R-D13 | `ReShuffleDiscardsPilesBackToDeck` : les deux défausses retournent dans leur pioche (GB:1335-1349) | règle | Oui | CD:114-136 (`draw_pile`) | Oui | | — |
| R-D14 | Tri des défausses par `UniqueID` avant mélange (GB:1335-1349) | règle | Non vérifié (pas de grep de tri) | — | — | Sans effet : le mélange est aléatoire des deux côtés. | Basse |
| R-D15 | `RandomProvider.Shuffle` (graine) | technique | Oui | CD (`_rng`) | Différent | Mélange non reproductible par conception ; l'oracle rejoue les coups, pas les mélanges. | Basse |
| R-D16 | `ChooseCardTypeToDraw` (Boss:270) | méthode | Oui | RA:95 | Oui | Chemin mort des deux côtés (BMA023 dans `notInGameCards`, `CardInfoService.cs:19,184` ; M:71). | — |
| R-D17 | `PlayersPriorized` par PlayerId = XP décroissant (GameBoardExtensions:105-135) | règle | Oui | M:1224-1232, CD:286-297 | Oui | XP des boss APK uniques. | — |
| R-D18 | Pioche de début de tour par `InGamePlayersPriorized` (GB:360-393) | règle | Oui | M:1199-1220 | Différent | Godot pioche dans l'ordre des sièges. Masqué par l'oracle (sièges insérés par PlayerId) ; effet seulement si la pioche s'épuise entre deux joueurs du même tour. | Basse |
| R-D19 | `RevealAllRoomCards` itère `Players` en ordre de sièges (GB:928-970) | règle | Oui | M:1477-1504 (ordre XP) | Différent | Même masquage que R-D18. | Basse |
| R-D20 | Salle ordinaire par-dessus une salle (`DungeonSlot.CheckRoomCanBeBuilt`:81) | règle | Oui | BE:119-171, M:256-340 | Oui | Exercé. | — |
| R-D21 | Salle avancée : emplacement construit + trésor imprimé, pas sur une salle en attente | règle | Oui | BE:119-171 | Oui | | — |
| R-D22 | `CheckBuildRestriction` (Neanderthal Cave) | règle | Oui | BE:119-171, BE:156-158 | Oui | | — |
| R-D23 | 5 emplacements maximum | constante | Oui | CD:18 | Oui | | — |
| R-D24 | Limite de constructions (`Boss.BuildRoom`, `CheckMaxBuildRooms` UI qui défait la plus ancienne en attente) | règle | Oui | M:536-571, GM:90-102 | Oui | | — |
| R-D25 | `MaxBuildRoomLimit` remis à 1 seulement dans `DeactivateLastActivePlayer` (GB:1213-1218) | règle | Oui | M:1181 (effets remis à zéro à `_start_turn`) | Différent | L'APK garde la valeur d'un tour à l'autre pour les joueurs déjà passés ; Godot remet tout à zéro. Voir R-D26, R-D27. | Moyenne |
| R-D26 | `SkipBuildPhase` (Kobold Strike BMA049) : `MaxBuildRoomLimit = 0` pour tous (`SkipBuildPhase.cs`, Execute) | commande | Oui | SE:305-329 (`buildBlocked`) | Différent | Vérifié dans le C# : seul le joueur désactivé repasse à 1 (`GameBoard.cs:1215`, `Boss.cs:145` à la création). Les joueurs qui avaient déjà construit ce tour gardent 0 et sautent leur construction du tour suivant ; Godot ne bloque que le tour courant. 1 exemplaire, rarement joué par l'IA. Correction (2026-10-26) : `ChooseNextActivePlayer` remet aussi la limite à 1 au début de l'aventure (`GameBoard.cs:1196`) : pas de report au tour suivant. Corrigé dans Godot le 2026-10-26. | Corrigé (Moyenne) |
| R-D27 | `BuildExtraRoom` (Motivation BMA050) : `MaxBuildRoomLimit++` | commande | Oui | SE:~137 | Différent | Lancée hors de son tour, l'APK reporte la limite 2 au tour suivant ; l'effet Godot expire à `_start_turn`. Non exercé. Correction (2026-10-26) : `ChooseNextActivePlayer` remet aussi la limite à 1 au début de l'aventure (`GameBoard.cs:1196`) : pas de report au tour suivant. Corrigé dans Godot le 2026-10-26. | Corrigé (Moyenne) |
| R-D28 | `BuildRoomBy` (level-up BMA003 / BMA007) | commande | Oui | RA:~1081 | Oui | | — |
| R-D29 | `ExtraBuildTurn` (BMA034) → `PendingExtraBuiltTurns` | commande | Oui | RA:~730, M:1421-1449 | Oui | File FIFO, saut si aucune construction légale. | — |
| R-D30 | Injection d'ExtraBuildPhase avant BeginningOfTurn / BaitPhase (GB:316-319, 412) | phase | Oui | M:1421-1449, 1307 | Oui | | — |
| R-D31 | `DuringPhase.Build` = BuildPhase_a seule, donc pas ExtraBuildPhase ; `ForcedToBuildRoom` | condition | Oui | CD:303-327 (`can_play_spell`), M:273 et M:296 (`legal_moves`), M:1421-1440 (`_start_forced_build`) | **Différent** | Vérifié : pendant un tour de construction forcé, Godot reste en phase `build`. `legal_moves` propose donc les sorts de phase Build (BMA049, 050, 051, 055) et les constructions supplémentaires de `extra_builds_for`, sans test de `forcedBuild`. L'APK n'ouvre aucune fenêtre de sort Build en ExtraBuildPhase. Invisible pour l'oracle (Godot plus permissif) ; un humain ou l'IA Godot peut jouer ces coups. | **Haute** |
| R-D32 | `Ability.CheckConditions` ne bloque que Setup_b | règle | Oui | CD:303-327 | Oui | | — |
| R-D33 | `EnqueueAbilityTransaction` : LIFO par joueur, tri PlayerId, joueur actif en tête (GB:1317-1333) | règle | Oui | M:1640-1654 | Oui | | — |
| R-D34 | Après la dernière construction (`ActivePlayer == null`) : tri par PlayerId pur | règle | Oui | M:602-603 | Différent | Godot donne encore la priorité au dernier constructeur. Effet seulement avec ≥ 2 sorts empilés. | Corrigé (Moyenne) |
| R-D35 | `RevealAllRoomCards` : emplacements en attente par indice C# croissant ; level-up à `DungeonSize == 5` (GB:928-970) | phase | Oui | M:1477-1504 | Partiel | Identique avec un seul emplacement en attente. Avec ≥ 2 pour un joueur (Motivation), l'ordre des déclencheurs et du level-up diffère. Non exercé. | Corrigé (Moyenne) |
| R-D36 | Level-up à 5 salles, une fois | règle | Oui | M:1495, RA:870 | Oui | | — |
| R-D37 | Fenêtre de sorts avant révélation (BuildPhase_b) | phase | Oui | M:1327, 1368 | Oui | | — |
| R-D38 | `AssignHeroesToDungeons` : un seul meilleur joueur, sinon le héros reste en ville (GB:1220-1239) | phase | Oui | M:1537-1562, BE:176-229 | Oui | | — |
| R-D39 | `LuredByTreasures` : `Boss.GetDungeonTreasures` filtre `slot.IsActive && !PendingToBeBuilt` (`Boss.cs:252-256`) | règle | Oui | BE:61-86 | **Différent** | Doublon de R-F15 (a) : une salle gelée garde ses trésors au leurre. | voir R-F15 |
| R-D40 | `LuredByFewerSouls`, `LuredByWounds` | règle | Oui | BE:176-229 | Oui | | — |
| R-D41 | `LuredBySouls`, `LuredByCardsInHand` | code mort APK | N/A | — | — | Aucune carte APK ne les utilise. | — |
| R-D42 | Nouvel emplacement de donjon et effets indexés par emplacement | règle | Oui | M:557-560 (`push_front`), `TnlAbilities.gd:1007-1019` (`insert_slot`, chemin wiki seul) | **Différent** | Doublon de R-F15 (b) et R-F48. | voir R-F15 |
| R-D43 | Aventure de l'entrée vers le boss ; dégâts sur emplacements actifs (`ProccessActiveHero`, GB:1087-1183) | phase | Oui | M:1834-1894, 1928-1946 | Oui | Exercé. | — |
| R-D44 | Héros mort pendant le pas : `HeroDiesInThisRoom` de cette salle + âme | règle | Oui | M:1758-1776 | Oui | | — |
| R-D45 | Héros qui sort : blessure si hp > 0, âme sans déclencheur sinon | règle | Oui | M:2006-2082 | Oui | | — |
| R-D46 | `DealHero` (Boulder Ramp BMA028, Exhaustion BMA044) ne teste pas la mort (`DealHero.cs:42-45`) | commande | Oui | RA:318-331 (`_boulder_ramp`), M:1758-1776 (`_finish_hero_if_dead`) | **Différent** | Vérifié : côté APK, le héros reste à 0 PV jusqu'au `ProccessActiveHero` suivant, qui l'avance d'un emplacement (`num--`), lui inflige cette salle, puis déclenche `HeroDiesInThisRoom` de **cette nouvelle salle** (`GameBoard.cs:1112-1146`). Godot le tue tout de suite et déclenche la salle **courante** (`_deathRoom` n'est jamais écrit, seulement lu à M:1766). Exemple : un héros tué par Boulder Ramp devant Golem Factory pioche une salle côté APK, rien côté Godot. Le harnais classe ces points `adv` comme non comparables. | **Haute** |
| R-D47 | Fenêtre après dégâts : l'APK a déjà tué un héros à hp ≤ 0 | règle | Oui | M:1948-1973 | Non vérifié | Godot garde le héros jusqu'à la fin de la pause ; je n'ai pas confirmé si un sort peut alors viser un héros à 0 PV (SE:100-111 ajoute +3 PV sans test). | Moyenne |
| R-D48 | `Hero.Deal` borne à 0 | règle | Oui | M:1928-1946 | Oui | | — |
| R-D49 | Emplacement désactivé sauté | règle | Oui | M:1878-1881 | Partiel | Godot saute sans ouvrir la fenêtre de sorts. | Basse |
| R-D50 | `ChooseNextActiveHero`, `ForceSkipAdventure` (Trepidation) | règle | Oui | M:1975-2006 | Oui | | — |
| R-D51 | `ChooseNextActivePlayer`, `DeactivateLastActivePlayer` (GB:1185-1218) | méthode | Oui | M:1987 | Oui | | — |
| R-D52 | `IsAdventureInteractionTurn` bloque l'UI sans héros actif (GB:285) | méthode | Oui (côté UI) | `BoardUI._my_moves`, `Match.apk_active_hero()` (README parité:485) | Oui | Règle portée par l'interface, comme l'APK ; `legal_moves` reste permissif pour le rejeu. Golden `_t_apk_active_hero_ui_gate`. | — |
| R-D53 | `Boss.IsAlive = Wounds < 5 && !IsManuallyKilled` (Boss:82) | propriété | Oui | M:2060-2063 (`eliminated`) | Partiel | Drapeau collant côté Godot, recalcul en direct côté APK. Écart seulement si les blessures baissent après élimination. | Basse |
| R-D54 | `KillManually` au départ d'un joueur en ligne (GB:855) | méthode | Oui | `server/GameRoom.gd:156` | Différent | Godot donne le siège à l'IA. Choix de conception, renvoyé au module 9. | Basse |
| R-D55 | `CheckEndOfGame` en EndOfTurnPhase seulement (GB:972-1049) | phase | Oui | M:2090-2175 | Oui | | — |
| R-D56 | 10 âmes et < 5 blessures : un gagnant | règle | Oui | M:2104-2116 | Oui | Golden. | — |
| R-D57 | Plusieurs à 10 âmes : meilleur Âmes-Blessures, puis PlayerId le plus bas | règle | Oui | M:2104-2116, 2204-2216 | Oui | Goldens. | — |
| R-D58 | Aucun survivant : meilleur Âmes-Blessures sur tous | règle | Oui | M:2119-2138 | Oui | | — |
| R-D59 | Un seul survivant : il gagne | règle | Oui | M:2119-2138 | Oui | | — |
| R-D60 | Élimination à 5 blessures | règle | Oui | M:2060-2063 | Oui | | — |
| R-D61 | `Score = Souls - Wounds` (Boss:112) | propriété | Oui | CD:215-280 | Oui | | — |
| R-D62 | Âmes / blessures des héros (1/1, 2/2) | données | Oui | `cards.json` | Oui | | — |
| R-D63 | Timing des épiques | règle | Oui | M:87-96 | Oui | | — |
| R-D64 | Révélation des objets (`RevealItems`) | règle | Oui | M:1263-1273 | Oui | Objets inertes dans l'APK (R-F72). | — |
| R-D65 | Spell Battle : `PendingSpellBattlePlayers` à chaque activation | règle | Oui | M:580-617, 1583, 1701-1754 | Partiel | Voir R-D66, R-D67. | — |
| R-D66 | `RemovePendingTransactionsByTarget` (GB:1351-1361) | méthode | Non (vérifié absent) | M:1701-1740 | — | Doublon de R-E27. | voir R-E27 |
| R-D67 | Activation de salle par l'utilisateur ouvre une Spell Battle (GB:812) | méthode | Oui | RA:128-181 | Partiel | Godot applique l'activation tout de suite, sans fenêtre de réponse. Le harnais retient `playRoomAbility` (`_held`), donc masqué. | Moyenne |
| R-D68 | Le sort quitte la main vers la défausse au lancement (GB:751-783) | règle | Oui | M:1714 | Partiel | Godot défausse à la résolution ; ne change qu'un remélange pendant la bataille. | Basse |
| R-D69 | `RemoveHeroFromGame`, `RemoveRoomOrSpellFromGame`, `DestroyRoom` (GB:624, 694-749, 835) | méthode | Oui | BE:518-580 | Oui | `destroy_room` décale bien les effets indexés. Voir R-D90 pour l'ordre défausse / déclencheur. | — |
| R-D70 | `DiscardFromHand`, `DrawRooms`, `DrawSpells` | méthode | Oui | CD:93 | Oui | | — |
| R-D71 | `ReactivateAllRooms`, `RestoreDungeon` (GB:1051, Boss:235) | méthode | Oui | SE:8 (`empty_effects`), M:1210-1214 | Oui | Godot remet à zéro au début du tour suivant ; état équivalent pour la fin de partie (évaluée avant). | Basse |
| R-D72 | `GetOpponents`, `GetOwnerPlayer`, `OpponnentDungeonSizeMoreThan` | méthode | Oui | BE:26-35 | Oui | | — |
| R-D73 | `PlaySpell`, `SetSpellBattleReady`, `OnAbilityApplyDone` | méthode | Oui | M:580-617, 684-731 | Oui | | — |
| R-D74 | `HeroResistDamageRoomType` (KSA016) | commande | Oui | BE:484-488 | Oui | | — |
| R-D75 | `GetFewestSoulsPlayer` (GB:1270) | code mort APK | N/A | — | — | Aucun appelant. | — |
| R-D76 | `TempNextGamePhase`, `CurrentNextStep` | code mort APK | N/A | — | — | Jamais lus. | — |
| R-D77 | `Boss.Print*`, `Boss.ActiveItem` / `DiscardItems`, `Room.IsAbilityUsed`, `DungeonSlot.BuffDamage` | code mort APK | N/A | — | — | Clonés ou hachés, jamais lus. | — |
| R-D78 | Triche `Cheat*` (GB:472-527), `DEBUG_ELEM` | debug APK | N/A | — | — | Derrière une UI de debug. | — |
| R-D79 | `SerialHelper`, `ActivationResponses`, `CryptoProvider`, `GetHashBytes` (GB:1363) | licence / synchro | N/A | — | — | Godot est autoritaire côté serveur ; renvoyé aux modules 9 et 10. | — |
| R-D80 | `DBMGameModel.Info/*` (`AIRoomInfo`, `AISpellInfo`) | données IA | Oui | `ApkAI.gd` | Oui | Renvoyé au module 6. | — |
| R-D81 | Tutoriel : pioches imposées (GameBoardExtensions:19-52) | règle | Oui | GM:22-55 | Partiel | Le reste est tiré avec une graine fixe différente de l'APK. Renvoyé au module 8. | Basse |
| R-D82 | — (code Godot hérité) `GameManager.calculate_lure`, `advance_hero_in_dungeon`, `Match._turn_order` | code mort Godot | Oui | GM:150-201, M:1564 | — | Aucun appelant ; `advance_hero_in_dungeon` est de plus faux (blessures prises pour des PV). À supprimer. | Basse |
| R-D83 | — (ajout Godot) 5-6 joueurs (CRL « big game ») | ajout | Oui | M:17-35, CD:24 | — | Derrière la case wiki. | — |
| R-D84 | — (ajout Godot) fin `no_more_heroes` | ajout | Oui | M:2140-2166 (`not apk_only`) | — | | — |
| R-D85 | — (ajout Godot) partage de leurre CRL | ajout | Oui | BE:235 | — | | — |
| R-D86 | — (ajout Godot) `_check_end_big_game` | ajout | Oui | M:2180 | — | | — |
| R-D87 | — (ajout Godot) TNL, RMB, THK wiki, IOD | ajout | Oui | `TnlAbilities.gd`, `Minibosses.gd`, `RmbAbilities.gd`, `ThkAbilities.gd`, `IodAbilities.gd` | — | Hors périmètre APK. | — |
| R-D88 | — (ajout Godot) vote des rois | ajout | Oui | M:1388 | — | | — |
| R-D89 | — (ajout Godot) annulation de pose, sauts automatiques de fenêtre | ajout | Oui | M:416-451, 1299 | — | | — |
| R-D90 | `DestroyRoom` défausse la salle **avant** le déclencheur `WhenAnotherRoomIsDestroyed` (GB:840-851) | règle | Oui | BE:518-593 (`destroy_room`, `_on_other_room_destroyed`) | Partiel | Godot déclenche Recycling Center avant que l'appelant défausse la salle détruite. Invisible sauf pioche de salles vide (1 carte d'écart au remélange). Mis en évidence par s16-p4 (R-O04), documenté `tools/parity/README.md:482`. | Basse |

### 5B — Système de capacités (lot E)

Sources : `DBMGameModel.Logic.Abilities.*` (Commands, Targets, Conditions, LuredConditions, Triggers) et `GameBoard`. Les lignes de famille regroupent les éléments relus ; les éléments jamais référencés par un `data.json` APK sont classés « Sans objet ».

| ID | Élément source (décompilé) | Type | Présent dans Godot ? | Fichier Godot | Équivalent fonctionnel ? | Écart / Commentaire | Priorité |
|---|---|---|---|---|---|---|---|
| R-E01 | Dégâts salle / héros (`DealDamageToRoom`, `IPassiveDamage`) | commandes | Oui | BE:377-493, BE:518-580 | Oui | Montants concordants dans toutes les traces. | — |
| R-E02 | `DeactivateDungeonAbility` (Trap Master KSA017), `Ability.IsLocked` | commande | Oui | BE:341-350, RA:141-142 | Oui | Verrou levé à la sortie du héros, comme `RemoveHeroFromGame` (voir R-F69). | Basse |
| R-E03 | `ReactivateAllRooms` / `Boss.RestoreDungeon` | commande | Oui | M:1210-1214 | Oui | Remise à zéro au début du tour suivant au lieu de la fin du tour ; aucun écart observé. | Basse |
| R-E04 | `ChooseCardFromHand`, `FlipItem`, `PlaceAtOwnerDungeonEntrance`, `SkipBeginingOfTurn` | commandes | N/A | M:1261-1262 | — | Aucune carte APK ne les utilise ; `FlipItem.Execute` lève `NotImplementedException`. | Basse |
| R-E05 | `chooseDraw`, `SwapSlotInDungeon` | commandes | Oui | RA:95, RA:738, M:1215-1243 | Oui | BMA023 et BMA033 jamais distribuées (R-D16). Golden seulement. | Basse |
| R-E06 | Pioche et remélange (`DrawCards`, `ReShuffleDiscardsPilesBackToDeck`) | commandes | Oui | M:1256-1259, CD (`draw_pile`) | Oui | | — |
| R-E07 | Destruction et défausse de salle | commandes | Oui | BE:518-595 | Oui | Voir R-D90. | — |
| R-E08 | Trésors et âmes (`IPassiveTreasure`, `IPassiveScorekeep`, `RemoveHeroFromTheGame`) | commandes | Oui | CD:215-251, BE:61-86 | Partiel | Voir R-F21 (Soul Harvest) et R-F23 (passifs dans Trepidation). | voir R-F21 |
| R-E09 | 16 sorts BaseDeck | commandes | Oui | SE (`cast_spell`) | Partiel | Détail carte par carte en 5C. | — |
| R-E10 | Autres Commands (≈ 40 sur 49) | commandes | Non vérifié (ligne à ligne) | — | — | Couvertes indirectement par 5C : chaque carte APK y est tracée avec ses commandes. | Basse |
| R-E11 | `HeroInDungeon` : `EntranceQueue.Take(1)` par donjon (`HeroInDungeon.cs`, `InternalGetAvailableTargets`) | cible | Oui | ST:116-136, ST:299-322 | **Différent** | Vérifié : Godot propose **tous** les héros de l'entrée, l'APK seulement le premier de chaque donjon. Touche BMA041 Assassin, BMA044 Exhaustion, BMA045 Fear. L'IA ne choisit que le premier, donc invisible pour l'oracle ; un humain peut viser un héros que l'APK n'offre pas. | Corrigé (Moyenne) |
| R-E12 | Cibles de salle (`RoomInDungeon`, `AdjacentsRoom`, `NextRoom`, `AnotherRoom`) | cibles | Oui | BE:45-47, ST:39-47 | Oui | | — |
| R-E13 | Comptage de Monster's Ballroom | cible | Oui | BE:406-411 | Différent | Doublon de R-F36. | voir R-F36 |
| R-E14 | Cible de Robobo (`BossOpponents` → `ChooseAndDestroyRoom`) | cible | Oui | RA:833, RA:1089-1103 | Non vérifié | Le lot E signale que Godot ne retire pas les salles gelées des choix ; je n'ai pas confronté au C# de `ChooseAndDestroyRoom`. Le lot F (R-F04) ne relève pas d'écart. | Corrigé (Moyenne) |
| R-E15 | `BossOpponentWithAtLeastHand`, `CrossingHeroAtachedItem`, `HeroInDeck`, `ItemInScorekeep`, `ItemInTown` | cibles | N/A | — | — | Inutilisées dans les `data.json` APK. | Basse |
| R-E16 | Autres Targets (≈ 25 sur 33) | cibles | Non vérifié (ligne à ligne) | — | — | Couvertes indirectement par 5C. | Basse |
| R-E17 | Re-vérification de condition à l'exécution (Motivation `OpponnentDungeonSizeMoreThan`) | condition | Oui | M:1299-1305, BE:30-36 | Partiel | Ne re-vérifie pas exactement au même moment. Aucun écart observé (6 jeux de Motivation). | Moyenne |
| R-E18 | Kobold Strike : bloque les constructions | condition | Oui | SE:307, M:296 | Différent | `buildBlocked` retire aussi les sorts de phase Build (M:296), l'APK seulement les constructions. | Corrigé (Moyenne) |
| R-E19 | Liger's Den : `YouPlaySpellCard` + `OncePerTurn` | condition | Oui | M:1745-1750 | Partiel | Godot ne teste pas l'état gelé ni le verrou Trap Master avant de piocher. | Corrigé (Moyenne) |
| R-E20 | `HeroHasAtachedItem`, `OpponnentHasMoreThanInHand`, `OwnerHasFewerThanOpponent` | conditions | N/A | — | — | Inutilisées. | Basse |
| R-E21 | Conditions de leurre utilisées | leurre | Oui | BE:176-229, M:1537-1562 | Oui | | — |
| R-E22 | `LuredBySouls`, `LuredByCardsInHand` | leurre | N/A | — | — | Inutilisées (= R-D41). | Basse |
| R-E23 | `WhenYouBuildThisRoom`, `WhenYouBuildAnotherRoom` | déclencheurs | Oui | M:1477-1504, RA:528, RA:577 | Oui | Ordre inverse de `EnqueueAbilityTransaction` reproduit (M:1499). | — |
| R-E24 | `HeroDiesInThisRoom` | déclencheur | Oui | RA:607-630 | Partiel | Voir R-D46 (salle déclenchée après `DealHero`) et R-F26 (`OncePerTurn` consommé trop tôt). | voir R-D46 |
| R-E25 | `AnySpellCardIsPlayed`, `HeroDiesAnotherRoom`, `WhenOpponentPlaysSpellCard`, `WhenThisRoomIsDestroyed` | déclencheurs | N/A | BE:584 | — | Inutilisés dans les `data.json` APK. | Basse |
| R-E26 | `EnqueueAbilityTransaction` : capacités de salle mises en file | pile | Oui (autre forme) | RA:128-181, M:1573-1760 | Partiel | Les sorts passent par la pile ; les capacités de salle se résolvent immédiatement (= R-D67). | Moyenne |
| R-E27 | `RemovePendingTransactionsByTarget` : annule les transactions dont la cible a quitté le jeu (`GameBoard.cs:1351-1361`, appelée GB:606, 618, 743, 843) | pile | Non (vérifié absent) | M:1701-1740 | **Différent** | Vérifié : seul Counterspell marque `canceled`. Les sorts visant un héros (`heroId`) ratent sans dégât si le héros est parti. Les sorts visant par **indice** (`roomIndex`, `townIndex`, `soulIndex`) ne sont jamais annulés et frappent ce qui occupe l'indice. Rare : il faut deux sorts empilés sur la même zone. | Moyenne |
| R-E28 | Contre-sort (`CancelSpellAbility`, All-Seeing Eye) | pile | Oui | M:1728-1734, RA:237-251 | Oui | Le lot E citait les échecs s16-p4, s20-p2, s28-p3 ; contre-vérifié : ce sont une course de l'IA oracle et un remélange (R-O04), pas le contre-sort. 7 Counterspell joués, 0 écart. | Basse |
| R-E29 | `OncePerTurn` : `IsEffectApplied` posé à `Run` (`Ability.cs:135`, `OncePerTurn.cs:12`) | pile | Oui | RA:139, RA:167, RA:180 | Partiel | Godot pose `usedThisTurn` à l'activation et le remet à faux si l'activation échoue (RA:180). Comme l'effet est appliqué tout de suite, la différence ne se voit que si une transaction est annulée avant de s'exécuter. Non observé. | Moyenne |
| R-E30 | Autorésolution d'une cible unique (`TryToAutoresolve`) | pile | Partiel | ST:51 | Non vérifié | Lié à R-E11. | Partiel (Moyenne) |
| R-E31 | `OnAbilityApplyDone` (déclencheurs après sort) | pile | Oui | SE (`cast_spell`), M:1743-1752 | Non vérifié | | Moyenne |

### 5C — Cartes des 4 paquets APK (lot F)

Stats comparées par script entre les 4 `src/frontend/assets/data/*/data.json` (extraits de l'APK) et `src/frontend/godot/data/cards.json` : 233 fiches, **toutes identiques** (quantité, XP, trésors, dégâts, type, PV, âmes, blessures, joueurs minimum, catégorie, texte). « Oracle N× (T) » = N activations ou résolutions dans T des 24 traces.

#### Boss BaseDeck (level-up)

| ID | Élément source (décompilé) | Type | Présent dans Godot ? | Fichier Godot | Équivalent fonctionnel ? | Écart / Commentaire | Priorité |
|---|---|---|---|---|---|---|---|
| R-F01 | BMA001 Draculord : `CardInHand(1, Opponent)` → `PutCardInHand` | boss | Oui | RA:882, RA:997-1024 | Oui | Oracle 7× (7). | — |
| R-F02 | BMA002 Xyzax : `CardInDeck(2, DiscardPile)` → `PutCardInHand` | boss | Oui | RA:883, RA:1027-1039 | Oui | Oracle 6× (6). | — |
| R-F03 | BMA003 King Croak : `RoomInDeck(1, Advanced, Monster)` → `PutCardInHand` + `BuildRoomBy` | boss | Oui | RA:884, RA:1044-1085 | Oui | Oracle 4× (4). | — |
| R-F04 | BMA004 Robobo : `BossOpponents` → `ChooseAndDestroyRoom` | boss | Oui | RA:885, RA:1089-1103 | Oui | Choix par l'adversaire, PlayerId croissant. Voir R-E14. Oracle 4× (4). | — |
| R-F05 | BMA005 Cerebellus : `DrawCards(3, Spell)` + `DiscardSomeCardFromHand(1, Spell)` | boss | Oui | RA:886, RA:1128, RA:294 | Oui | Oracle 6× (6). | — |
| R-F06 | BMA006 Seducia : `HeroUnassigned` → `PlaceAtDungeonEntrance` | boss | Oui | RA:887, RA:1133-1151 | Oui | Ville + pioche de héros. Oracle 8× (8). | — |
| R-F07 | BMA007 Cleopatra : `RoomInDeck(1, Advanced, Trap)` → `PutCardInHand` + `BuildRoomBy` | boss | Oui | RA:888, RA:1044 | Oui | Oracle 6× (6). | — |
| R-F08 | BMA008 Gorgona : `HeroInTown` → `PlaceAtScorekeep(FaceDown)` | boss | Oui | RA:889, RA:1154-1170, M:904-915 | Oui | Oracle 4× (4). | — |

#### Sorts BaseDeck

| ID | Élément source (décompilé) | Type | Présent dans Godot ? | Fichier Godot | Équivalent fonctionnel ? | Écart / Commentaire | Priorité |
|---|---|---|---|---|---|---|---|
| R-F09 | BMA040 Annihilator : `RoomInDungeon(Trap)` → `DealDamageToRoom(3)` | sort | Oui | SE:82-96, ST:87-95 | Oui | Oracle 9× (8). | — |
| R-F10 | BMA041 Assassin : `HeroInDungeon(Any, Opponent)` → `DealHero(-3)` | sort | Oui | SE:100-111, ST:116-122 | Partiel | Excès de cibles (R-E11). Oracle 17× (14). | Corrigé (Moyenne) |
| R-F11 | BMA042 Cave-In : `RoomInDungeon(Owner)` → `KillHeroInRoom` + `DestroyRoom` | sort | Oui | SE:150-167, ST:70-73 | Oui | Oracle 13× (9). | — |
| R-F12 | BMA043 Counterspell : `SpellCardJustPlayed` → `CancelSpellAbility` | sort | Oui | M:590-596, M:1728-1734, ST:49-57 | Oui | Oracle 7× (7). | — |
| R-F13 | BMA044 Exhaustion : `HeroInDungeon(Any, Owner)` → `DealRoomsCountToHero` | sort | Oui | SE:171-190, ST:123-125 | Partiel | Excès de cibles (R-E11) ; mort différée (R-D46). Oracle 3× (3). | Corrigé (Moyenne) |
| R-F14 | BMA045 Fear : `HeroInDungeon(Any, Any)` → `PlaceAtTown` | sort | Oui | SE:194-217, ST:130-136 | Partiel | Excès de cibles (R-E11). Oracle 5× (5). | Corrigé (Moyenne) |
| R-F15 | BMA046 Freeze : `RoomInDungeon(Any)` → `DeactivateRoom`, sans condition de phase | sort | Oui | SE:128-136, BE:61-86, BE:334-338, M:557-560 | **Différent** | Vérifié, deux écarts. (a) `Boss.GetDungeonTreasures` exclut `!slot.IsActive` (`Boss.cs:252-256`) ; `BossEngine.dungeon_treasures` ne consulte pas `deactivatedRooms` : une salle gelée en construction garde ses trésors au leurre. (b) `deactivatedRooms` est indexé par emplacement et la construction APK fait `push_front` (M:560) sans décaler les effets ; seul le chemin wiki appelle `TnlAbilities.insert_slot` (`TnlAbilities.gd:1007-1019`). Freeze puis construction d'un nouvel emplacement : le gel glisse sur la salle voisine. Carte la plus jouée (30× dans 18 traces), mais l'IA la lance en aventure, donc l'oracle ne mesure pas ces chemins. | **Haute** |
| R-F16 | BMA047 Giant Size : `RoomInDungeon(Monster)` → `DealDamageToRoom(3)` | sort | Oui | SE:115-124, ST:96-107 | Oui | Bogue d'IA APK (liste Trap) assumé, README. Oracle 11× (9). | — |
| R-F17 | BMA048 Jeopardy : `AllBoss` → `DiscardAllHand` + pioches | sort | Oui | SE:279-297 | Oui | Oracle 6× (6). | — |
| R-F18 | BMA049 Kobold Strike : `UndoBuildRoom` + `SkipBuildPhase` | sort | Oui | SE:306-329 | Partiel | Durée (R-D26) et blocage des sorts Build (R-E18). Oracle 1× (1). | Moyenne |
| R-F19 | BMA050 Motivation : `OpponnentDungeonSizeMoreThan(1)` → `BuildExtraRoom` | sort | Oui | SE:140-146, BE:24-36 | Partiel | Report au tour suivant (R-D27). Oracle 6× (6). | Moyenne |
| R-F20 | BMA051 Princess in Peril : `HeroInTown` → `PlaceAtDungeonEntrance` | sort | Oui | SE:222-236, ST:137-139 | Oui | Oracle 12× (9). | — |
| R-F21 | BMA052 Soul Harvest : `HeroInScorekeep(Owner, Dead)` → `RemoveHeroFromTheGame` + `DrawCards(2, Spell)` | sort | Oui | SE:245-264, ST:168-172, ST:341-347, RA:1167 | **Différent** | Vérifié : un épique mort laisse 2 entrées d'âme (`RoomAbilities.gd:1167`, `CardDB.soul_entry` = 1 âme chacune) ; `_soul_harvest` n'en retire qu'une (`souls.remove_at(idx)`, SE:257). L'APK retire le héros entier de `SoulsHeroes` (`GameBoard.cs:694-731`). Un humain qui vise un épique ne perd qu'1 âme au lieu de 2. L'IA APK ne vise que des ordinaires (`ApkAI._chk_052`), donc invisible. Oracle 1× (1). | **Haute** |
| R-F22 | BMA053 Teleportation : `ActiveHeroInDungeon(Owner)` → `MoveHeroToRelativeSlot(5)` | sort | Oui | SE:268-275, ST:126-129, ST:380-390 | Oui (lecture) | **Jamais joué** dans les 24 traces ; golden `_t_apk_teleportation_*` seulement. | Basse |
| R-F23 | BMA054 Trepidation : `BossOpponentWithAtLeastScore(Dead, 2)` → `SkipAdventurePhase` | sort | Oui | SE:333-346, ST:160-167, ST:251-255 | Partiel | `Boss.Souls` inclut `CalculatePassiveSouls` (`Boss.cs:103-110`) ; `ST._souls_total` ne somme que les entrées `souls`, sans KSA006 Jarin ni T.P.K. (`CardDB.total_souls` les inclut). Cibles légales fausses avec PlayerChoice. Oracle 4× (4). | Corrigé (Moyenne) |
| R-F24 | BMA055 Zombie Attack : `HeroInScorekeep(Opponent, Dead)` → `SendBackToDungeonEntrance` + `DealHero(-2)` | sort | Oui | SE:350-403, ST:173-182 | Oui | PV de base + 2. Oracle 7× (6). | — |

#### Salles BaseDeck

| ID | Élément source (décompilé) | Type | Présent dans Godot ? | Fichier Godot | Équivalent fonctionnel ? | Écart / Commentaire | Priorité |
|---|---|---|---|---|---|---|---|
| R-F25 | BMA009 Dark Altar (activée) : `DestroyRoom` ; `CardInDeck(1, DiscardPile)` → `PutCardInHand` | salle | Oui | RA:169, RA:188-203 | Oui | Oracle 24× (15). | — |
| R-F26 | BMA010 Open Grave : `HeroDiesInThisRoom`, `OncePerTurn`, `RoomInDeck(DiscardPile)` | salle | Oui | RA:607-630, RA:754-764 | Partiel | `usedThisTurn` posé avant de savoir s'il y a une cible (RA:621-623) ; l'APK ne consomme `IsEffectApplied` que si la condition passe. Un 2e héros mort le même tour après un ajout à la défausse : déclenche en APK, pas en Godot. Oracle 12× (8). | Basse |
| R-F27 | BMA011 Specter's Sanctum : `WhenYouBuildThisRoom` → `DiscardRandomCardFromHand(1, Spell)` | salle | Oui | RA:544, RA:639-650, RA:801 | Oui | Oracle 30× (20). | — |
| R-F28 | BMA012 Succubus Spa : `HeroDiesInThisRoom`, `PickRandomCardFromHand` | salle | Oui | RA:626, RA:654-691 | Oui | Oracle 3× (3). | — |
| R-F29 | BMA013 Dracolich Lair (activée) | salle | Oui | RA:176, RA:388-431 | Oui | Oracle 50× (17). | — |
| R-F30 | BMA014 Vampire Bordello : `HeroDiesInThisRoom`, `FlipHero` | salle | Oui | RA:629, RA:782-793, BE:306-330 | Partiel | Même `OncePerTurn` prématuré que R-F26. Oracle 4× (4). | Basse |
| R-F31 | BMA015 Goblin Armory : passif `AdjacentsRoom(Monster)` +1 | salle | Oui | BE:414-432 | Oui | 1553 décisions passives (14). | — |
| R-F32 | BMA016 Golem Factory : `HeroDiesInThisRoom` → `DrawCards(1, Room)` | salle | Oui | RA:627, RA:767-771 | Oui | Oracle 17× (10). Voir R-D46. | — |
| R-F33 | BMA017 Minotaur's Maze : `FirstTimeHeroEnterThisRoom` → `MoveHeroToRelativeSlot(1)` | salle | Oui | M:1936-1943 | Oui | Oracle 10× (4). | — |
| R-F34 | BMA018 Neanderthal Cave : `CannotBuildRoom(Advanced)` | salle | Oui | BE:156-158 | Oui | Couvert indirectement. | — |
| R-F35 | BMA019 Beast Menagerie : `WhenYouBuildAnotherRoom`, `OncePerTurn`, `HasPendingRoomToBuild(Monster)` | salle | Oui | RA:571-604 | Oui | Oracle 20× (9). | — |
| R-F36 | BMA020 Monster's Ballroom : `RoomDamageEqualToCount(Monster)` | salle | Oui | BE:406-411 | Différent | `GetPassiveDamage` ne compte que `slot.IsActive` ; Godot compte les salles Monster gelées (pas de test `is_room_deactivated`). Freeze sur une Monster voisine : Ballroom reste à N au lieu de N-1. Code lu, non reproduit. 147 décisions passives (2). | Corrigé (Moyenne) |
| R-F37 | BMA021 Brainsucker Hive : `HeroDiesInThisRoom` → `DrawCards(1, Spell)` | salle | Oui | RA:628, RA:774-778 | Oui | Oracle 24× (11). | — |
| R-F38 | BMA022 Dark Laboratory : `WhenYouBuildThisRoom` → pioche 2 sorts, défausse 1 | salle | Oui | RA:544, RA:633-635 | Oui | Oracle 27× (17). | — |
| R-F39 | BMA023 Haunted Library : `ChooseCardToDraw` | salle | Oui (écartée des pioches) | RA:94-100, M:70-71 | Oui | `notInGameCards` (`CardInfoService.cs:19,184`). | — |
| R-F40 | BMA024 Witch's Kitchen (activée) | salle | Oui | RA:177, RA:485-514 | Oui | Oracle 20× (7). | — |
| R-F41 | BMA025 All-Seeing Eye (activée) : `LastSpellPlayed` → `CancelSpellAbility` | salle | Oui | RA:170, RA:208-251 | Oui (lecture) | **Jamais activée** dans les 24 traces. | Basse |
| R-F42 | BMA026 Liger's Den : `YouPlaySpellCard` → `DrawCards(1, Spell)` | salle | Oui | M:1743-1752 | Partiel | Voir R-E19. Oracle 15× (6). | — |
| R-F43 | BMA027 Bottomless Pit (activée) : `DestroyRoom` + `KillHero` | salle | Oui | RA:171, RA:306-315 | Oui | Oracle 16× (12). | — |
| R-F44 | BMA028 Boulder Ramp (activée) : `DestroyRoom(AnotherRoom)` + `DealHero(5)` | salle | Oui | RA:172, RA:318-331 | Partiel | Mort différée et salle déclenchée (R-D46). Oracle 3× (3). | voir R-D46 |
| R-F45 | BMA029 Dizzygas Hallway : `NextRoom(Trap)` +2 | salle | Oui | BE:414-435 | Oui | 2165 décisions passives (12). | — |
| R-F46 | BMA030 Jackpot Stash (activée) : `MultiplyTreasuresDungeon(2)` | salle | Oui | RA:164-173, RA:334-342, BE:71-86 | Oui | Oracle 15× (13). | — |
| R-F47 | BMA031 Recycling Center : `WhenAnotherRoomIsDestroyed` → `DrawCards(2, Room)` | salle | Oui | BE:582-593 | Oui | Ordre défausse / déclencheur : R-D90. Oracle 15× (8). | — |
| R-F48 | BMA032 The Crushinator (activée) : `DestroyRoom(AnotherRoom)` + `DealDamageToDungeon(2)` | salle | Oui | RA:345-357, M:557-560 | **Différent** | Vérifié : `DealDamageToDungeon` fait `slot.Deal(2)` sur les 5 emplacements, vides compris, jusqu'à `RestoreDungeon`. Godot pose le +2 sur les indices existants à l'activation (RA:354-355), puis une construction (M:560 `push_front`, sans décalage) décale toutes les salles : la nouvelle salle reçoit un +2, la salle la plus proche du boss le perd. Séquence courante pour un humain (activer puis construire). Le harnais retient l'activation après la construction (`_held`), donc l'oracle ne voit pas ce chemin. Oracle 33× (12). | **Haute** |
| R-F49 | BMA033 Centipede Tunnel : `SwapSlotInDungeon` | salle | Oui (écartée des pioches) | RA:549, RA:738-751, M:70-71 | Oui | Golden seulement. | — |
| R-F50 | BMA034 Construction Zone : `ExtraBuildTurn` | salle | Oui | RA:548, RA:730-735 | Oui | Oracle 8× (7). Voir R-D31. | — |
| R-F51 | BMA036 Mimic Vault : `HeroInTown(Ordinary)` → `PlaceAtDungeonEntrance` | salle | Oui | RA:546, RA:694-714 | Oui | Oracle 10× (10). | — |
| R-F52 | BMA037 Monstrous Monument : `RoomInDeck(Monster, DiscardPile)` → `PutCardInHand` | salle | Oui | RA:547, RA:717-727 | Oui | Oracle 5× (5). | — |
| R-F53 | BMA038 Torture Chamber (activée) : `ThisRoom` → `DestroyRoom` + défausse adverse | salle | Oui | RA:175, RA:361-382 | Partiel | `room_index` non transmis : la fonction détruit la **première** BMA038 trouvée depuis l'entrée (RA:365-368), sans exclure une salle en attente. Avec deux Torture Chambers, la mauvaise peut partir. Code lu, non reproduit. Oracle 13× (10). | Corrigé (Moyenne) |
| R-F54 | BMA039 Zombie Prison (activée) : `SendBackToDungeonEntrance` | salle | Oui | RA:178, RA:437-482 | Oui | Oracle 9× (7). | — |
| R-F55 | BMA035 Dragon Hatchery : aucune capacité | salle | Oui | — | Oui | Construite 5×. | — |

#### Héros BaseDeck

| ID | Élément source (décompilé) | Type | Présent dans Godot ? | Fichier Godot | Équivalent fonctionnel ? | Écart / Commentaire | Priorité |
|---|---|---|---|---|---|---|---|
| R-F56 | BMA056-079 : 24 ordinaires, `LuredByTreasures` | héros | Oui | `cards.json`, BE:176-230 | Oui | Présents dans les 24 traces. | — |
| R-F57 | BMA080 The Fool : `LuredByFewerSouls` | héros | Oui | CD:272, BE:196-198 | Oui | | — |
| R-F58 | BMA081-096 : 16 épiques | héros | Oui | `cards.json` | Oui | `HasStar` jamais lu côté C#. | — |

#### PlayerChoice

| ID | Élément source (décompilé) | Type | Présent dans Godot ? | Fichier Godot | Équivalent fonctionnel ? | Écart / Commentaire | Priorité |
|---|---|---|---|---|---|---|---|
| R-F59 | KSA001 Kirax : `AddTreasuresToDungeon` (passif) | boss | Oui | BE:81-86 | Oui (lecture) | **Jamais tiré** dans les traces. | Basse |
| R-F60 | KSA002 Hellcow : `RearrangeDungeon` | boss | Oui | RA:928-982 | Oui | Oracle 1× (1). | — |
| R-F61 | KSA003 The Brothers Wise : `SpellInDeck` → `PutCardInHand`, facultatif | boss | Oui | RA:904-912, M:926 | Oui | Oracle 1× (1). | — |
| R-F62 | KSA004 Kaw'nee : `HeroInScorekeep(Opponent, Dead, Ordinary)` → `PlaceAtScorekeep` | boss | Oui | RA:913-927, M:933-942 | Oui | Oracle 2× (2). | — |
| R-F63 | KSA005 Scythe : `LastRoomDealDamage(3)` (passif) | boss | Oui | BE:471-476 | Oui (lecture) | **Jamais tiré**. | Basse |
| R-F64 | KSA006 Jarin : `AddSoulsToBoss(1)` (passif) | boss | Oui | CD:224-231 | Oui | Oracle 3× (3). Voir R-F23. | — |
| R-F65 | KSA007 Elicon : `MultiplyTreasuresDungeon(2)` | boss | Oui | RA:901-903 | Oui | Oracle 1× (1). | — |
| R-F66 | KSA013 T.P.K. : `AddSoulsToBossIfTreasures(2, …)` | sort | Oui | SE:408-418, CD:233-251, ST:146-153 | Oui | Oracle 2× (2). | — |
| R-F67 | KSA014 Demigod : `LuredByWounds` | héros | Oui | BE:199-201 | Oui | Présent dans 6 traces. | — |
| R-F68 | KSA016 Monster Hunter : `HeroResistDamageRoomType(1, Monster)` | héros | Oui | BE:484-488 | Oui (lecture) | Passif non isolé dans les traces. | Basse |
| R-F69 | KSA017 Trap Master : `ThisHeroEntersDungeon` → `DeactivateDungeonAbility` | héros | Oui | BE:341-350, BE:397-401, RA:141-142, M:2018 | Oui | Oracle 4× (4). | — |

#### ToolsHeroKind et HiddenHeros

| ID | Élément source (décompilé) | Type | Présent dans Godot ? | Fichier Godot | Équivalent fonctionnel ? | Écart / Commentaire | Priorité |
|---|---|---|---|---|---|---|---|
| R-F70 | THK021-024 : 4 salles avancées, `Ability` nulle | salle | Oui | `ThkAbilities.gd:617-620`, RA:147-148 | Oui | Inertes comme l'APK hors case wiki. THK022 et THK024 construites 1×. | — |
| R-F71 | THK025 Excavation : `Ability` nulle | sort | Oui | CD:315 | Oui | Injouable comme l'APK (`thkLive` seulement avec la case wiki). | — |
| R-F72 | THK001-020 : 20 objets sans capacité | objet | Oui | M:100-130 | Oui | Révélés sans effet, comme `RevealItems`. | — |
| R-F73 | BMH056-079 : 24 ordinaires, `ReplacesCardNumber` = BMA056-079 | héros | Oui | M:73-78, CD:264-272 | Oui | Stats identiques. | — |
| R-F74 | BMH080 The Fool | héros | Oui | CD:272 | Oui | | — |
| R-F75 | BMH081-096 : 16 épiques | héros | Oui | idem | Oui | 29 des 41 BMH présents dans les traces (les héros 4 joueurs manquent : aucune trace 4 joueurs avec ce paquet). | Basse |
| R-F76 | BMH056-096 : `Description = ""` dans `HiddenHeros/data.json` ; nom et texte imprimés dans l'image | texte | Texte faux | `cards.json heroes[BMH056..096].description` | Non (texte seul) | Ce n'est pas un décalage entre cartes : Godot recopie le texte des BMA de même numéro (« Nick the Masher » pour BMH056), alors que l'image montre un autre personnage (« Everel the Healer » pour BMH056, « Brother Ben » pour BMH057, « Patrik Cogstopper » pour BMH096). Aucune règle touchée. Texte jamais affiché : `description_text` (`CardData.gd:52`) n'a aucun lecteur (vérifié au module 11, G-07). Les vrais noms ne sont que dans les images ou les `.wpk` non décodés. Renvoyé au module 11. | Basse |

### Non vérifié (module 5)

- Aucun écart Haute n'a été **reproduit** par une partie : ils viennent de la lecture du C# et du GDScript, contre-vérifiée à la main (R-D31, R-D46, R-F15, R-F21, R-F48). Un golden par écart serait la preuve suivante.
- R-E10 et R-E16 : ≈ 40 Commands et ≈ 25 Targets non relues une par une ; couvertes seulement à travers les cartes de 5C.
- R-E14 (Robobo et salles gelées), R-D47 (cible à 0 PV dans la fenêtre post-dégâts), R-E30, R-E31 : non tranchés.
- R-D14 : tri des défausses par `UniqueID` sans grep côté Godot.
- Cartes jamais exercées par l'oracle : BMA053, BMA025 (activation), KSA001, KSA005 ; passifs KSA016 et KSA014 non isolés.
- Les noms des 41 BMH : 3 images ouvertes seulement.

### Synthèse module 5

| Lot | Lignes | OK | N/A ou code mort | Ajouts / code hérité Godot | Écarts (lignes) | dont renvois vers une autre ligne | Non vérifié | Haute | Moyenne | Basse |
|---|---|---|---|---|---|---|---|---|---|---|
| 5.0 Oracle | 5 | 4 | 0 | 0 | 1 | 0 | 0 | 0 | 1 | 1 |
| 5A Moteur | 90 | 53 | 6 | 8 | 20 (+ R-D66, renvoi) | 2 (R-D39, R-D42) | 2 | 2 | 7 | 13 |
| 5B Capacités | 31 | 10 | 5 | 0 | 11 | 4 (R-E08, R-E13, R-E24, R-E26) | 5 | 0 | 10 | 11 |
| 5C Cartes | 76 | 60 | 0 | 0 | 16 | 1 (R-F44) | 0 | 3 | 8 | 9 |
| **Total** | **202** | **127** | **11** | **8** | **48** | **7** | **7** | **5** | **26** | **34** |

Module 5 : **202 éléments audités, 127 OK, 41 écarts distincts (48 lignes, 7 renvois), 7 non vérifiés, 0 blocage web** (moteur en GDScript pur, sans thread ni fichier). Critique 0.

Les 5 écarts **Haute** sont tous des chemins que l'IA de l'APK ne prend pas, donc que l'oracle ne voit pas :
1. **R-F15** Freeze : la salle gelée garde ses trésors au leurre, et le gel glisse sur la mauvaise salle après une construction (couvre R-D39 et R-D42).
2. **R-F48** Crushinator puis construction : le +2 glisse et la salle la plus proche du boss le perd.
3. **R-F21** Soul Harvest sur un épique : 1 âme retirée au lieu de 2.
4. **R-D31** Tour de construction forcé : Godot autorise les sorts de phase Build et les constructions supplémentaires.
5. **R-D46** Boulder Ramp ou Exhaustion à 0 PV : la mort et son déclencheur arrivent tout de suite, dans la salle courante, au lieu de la salle suivante.

Les écarts 1 et 2 ont la même cause : le chemin APK de `buildRoom` (M:560) ne décale pas les effets indexés, alors que `TnlAbilities.insert_slot` le fait déjà.

### Questions ouvertes (module 5)

1. ~~R-D26 et R-D27 : l'APK reporte au tour suivant les limites de construction de Kobold Strike (0) et de Motivation (2), ce qui ressemble à un bogue de l'APK. Faut-il reproduire ce comportement à l'identique, ou garder la lecture « ce tour seulement » de Godot ?~~ Réponse : Godot aligné sur l'APK (corrigé le 2026-10-26).
2. R-D46 : même question pour la mort différée après `DealHero` (la salle déclenchée est celle d'après). Faut-il la reproduire à l'identique ?

---

## Module 6 — IA

Périmètre : `DBMGameProject.AI/` (`FixedAI`, `StatisticAI`, `RandomAI`, `NullAI`, `AIBrain`, `AIHelper`, `AbilitySelectedInformation`), `DBMGameProject.AI.Statistics/` (`RoomCalculator`, `DungeonSlotCalculator`, `DiscardCalculator`, `DrawCalculator`, `StatisticsCalculator`, `AbilityCalculator`, `TriggerCalculator`), `DBMGameModel.Info/AI*`, `DBMGameProject.Services.PlayerInteraction/AIPlayerInteraction.cs` et l'autoplay de `HumanPlayerInteraction.cs`. Côté Godot : `AI.gd` (aiguillage), `ApkAI.gd` (port de l'IA APK), `Match.gd` (`legal_moves`), `BoardUI.gd` (cadence). `AiWiki.gd` (cartes wiki) est hors périmètre.

L'APK joue ses adversaires avec **`FixedAI`** (`GameBoardExtensions.cs:49,70,129,241,298`) : construction, emplacement et défausse sont des argmax déterministes ; pioche, capacités et cibles passent par `StatisticAI` (tirages). L'oracle (`tools/apk-oracle`) joue avec la même `FixedAI`, donc il mesure la bonne IA.

### 6.0 — Accord de l'IA mesuré par l'oracle (`apk.py --ai-agreement`, 2026-10-26, `3ef4350`)

Accord = l'IA Godot, interrogée sur l'état exact de l'oracle juste avant chaque décision, rend la même décision (définitions : `tools/parity/README.md:233-258`). Les 3 traces en échec du run de stress (s16-p4, s20-p2, s28-p3, voir R-O04) sont exclues : après leur première divergence, les états ne sont plus comparables. Mesure pure (`mutations = 0`).

| ID | Élément source (décompilé) | Type | Présent dans Godot ? | Fichier Godot | Équivalent fonctionnel ? | Écart / Commentaire | Priorité |
|---|---|---|---|---|---|---|---|
| IA-O01 | Construction : carte + emplacement (`FixedAI.SelectRoomToBuild`, `SelectPositionToBuild`) | décision | Oui | `ApkAI.gd:298-367` | Oui | **2854/2854** (137 base, 307 wide, 121 decks, 2289 graines 10-40). | — |
| IA-O02 | Défausse d'ouverture (`FixedAI.DiscardCards`) | décision | Oui | `ApkAI.gd:382-414` | Oui | **336/336**. | — |
| IA-O03 | Passer (rien à jouer) | décision | Oui | `AI.gd:49-117` | Oui | **1611/1611**. | — |
| IA-O04 | Capacités éligibles (`AbilityCalculator.CheckXXX` non nul) et capacité tirée dans l'ensemble | décision | Oui | `ApkAI.gd:1297-1338`, `AI.gd:95-108` | Oui à 99,8 % | Éligibles : sorts 716/718, salles 859/859, « rien d'éligible » 51636/51648. Tirée dans l'ensemble : 1575/1577. Les écarts sont Giant Size (IA-H14), Motivation (IA-H17) et Princess in Peril (IA-H18). | Basse |
| IA-O05 | Cibles déterministes des sorts et capacités activées (`SetSelectedTargets`) | décision | Oui | `ApkAI.gd` (`_chk_*`) | Oui | Sorts **590/590**, salles **734/734**. | — |
| IA-O06 | Cibles déterministes des déclencheurs (`TriggerCalculator`) | décision | Oui | `ApkAI.gd:1405-1744` | Oui à 98 % | **993/1009**. Les 16 écarts sont Mimic Vault ×10 (IA-H68), Specter's Sanctum ×5 (IA-H69) et Zombie Prison ×1 (IA-H70). Tous dans les graines 10-40. | Moyenne |
| IA-O07 | Cibles tirées au hasard (`Shuffle()`, `NextBool`) | décision | Oui | `ApkAI.gd` (`shuf`) | Non comparable | Accord attendu ≈ 1/n : sorts 79/126, salles 67/125, déclencheurs 124/301. Le tirage est fidèle (`Random.Next(1,100)` = `randi_range(1,99)`), seule la graine diffère. | — |
| IA-O08 | Coups jouables selon les règles (`CanPlayerPlayAbility`, mesure de la légalité du moteur et non de l'IA) | moteur | Oui | `Match.gd` (`legal_moves`) | Oui à 99,8 % | 53134/53225. Deux motifs : (a) BuildPhase_a à 3-4 joueurs, à la bascule entre deux joueurs (`NextStep` non exécuté) : l'APK a déjà ouvert la fenêtre du joueur suivant, Godot pas encore (Freeze, Jeopardy, Princess, Motivation, Soul Harvest) ; (b) AdventurePhase_c : Boulder Ramp jouable côté APK seulement, et BMA053 Teleportation jouable côté Godot seulement. Non tranché : décalage de fenêtre du harnais ou vraie règle. Renvoi au module 5. | Moyenne |

### 6A — Construction, défausse, pioche (lot G)

Tables de valeurs comparées par script, chiffre par chiffre : les 9 tableaux et 9 scalaires de `RoomCalculator.cs:13-29,55-73`, les 7 constantes de `DungeonSlotCalculator.cs:9-21`, les 8 de `DiscardCalculator.cs:8-22`, et les facteurs des 31 salles de `BaseDeck/ai_info.json` (copie Godot identique à l'APK, octet pour octet) sont **identiques** à `ApkAI.gd:15-56`.

| ID | Élément source (décompilé) | Type | Présent dans Godot ? | Fichier Godot | Équivalent fonctionnel ? | Écart / Commentaire | Priorité |
|---|---|---|---|---|---|---|---|
| IA-G01 | `AIBrain` (`AIBrain.cs:8-20`) | interface | Oui | `AI.gd:14,49`, `ApkAI.gd:298,382,416` | Oui | Une fonction par méthode, sans interface. | — |
| IA-G02 | `FixedAI` (`FixedAI.cs:10-72`), secours `StatisticAI` | classe | Oui | `AI.gd:49-117` | Oui | | — |
| IA-G03 | `FixedAI.SelectWhereToDrawFrom` → `StatisticAI` (`FixedAI.cs:14-17`) | méthode | Oui | `AI.gd:60-72` | Oui | | — |
| IA-G04 | `FixedAI.DiscardCards` : tri croissant stable, `Take(2)` (`FixedAI.cs:19-24`) | méthode | Oui | `ApkAI.gd:382-414`, `AI.gd:14-17` | Oui | Égalités : salles dans l'ordre de la main, puis sorts. | — |
| IA-G05 | `FixedAI.SelectRoomToBuild` : valeur décroissante, puis dégâts décroissants (`FixedAI.cs:26-39`) | méthode | Oui | `ApkAI.gd:298-341` | Oui | Puis ordre de la main ; `null` si maximum à 0. | — |
| IA-G06 | `FixedAI.SelectPositionToBuild` : valeur décroissante, puis dégâts du dessus croissants (`FixedAI.cs:42-55`) | méthode | Oui | `ApkAI.gd:343-366` | Oui | Puis indice C# croissant. | — |
| IA-G07 | `FixedAI.SelectAbilityToUse`, `SelectTriggerTargets`, `SelectCommandTargets` | méthodes | — | — | — | Lot H. | — |
| IA-G08 | `StatisticAI.SelectWhereToDrawFrom` : `NextDouble() <= p` (`StatisticAI.cs:16-23`) | méthode | Oui | `AI.gd:60-72` | Oui | Seul le flux aléatoire diffère. Jamais exercé : BMA023 Haunted Library n'est jamais distribuée. | Basse |
| IA-G09 | `StatisticAI.DiscardCards`, `SelectRoomToBuild`, `SelectPositionToBuild` (`StatisticAI.cs:25-56`) | méthodes | N/A | — | — | Inatteignables : redéfinies par `FixedAI`. | — |
| IA-G10 | `StatisticAI.RandomSelection` (`StatisticAI.cs:101-141`) | méthode | N/A | — | — | Ne sert qu'à IA-G09 et aux capacités (IA-H01). | — |
| IA-G11 | `StatisticAI.backup = new RandomAI()` (`StatisticAI.cs:14`) | champ | N/A | — | — | Jamais lu : il n'y a pas de repli vers `RandomAI`. | — |
| IA-G12 | `RandomAI` (`RandomAI.cs:12-83`) | classe | Non (vérifié absent) | — | — | Atteinte seulement par l'autoplay de debug (`HumanPlayerInteraction.cs:26-41`, `DEBUG_ELEM`) et par `GameFlowTestService`. | Basse |
| IA-G13 | `NullAI` | classe | N/A | — | — | Jamais instanciée. | — |
| IA-G14 | `DeckType` (`AIPlayerInteraction.cs:125-139`) | enum | Oui | `AI.gd:60-72`, `Match.gd:1240` | Oui | | — |
| IA-G15 | `AIHelper.GetGamePhase` : Setup, Early, Mid, Late (`AIHelper.cs:68-83`) | méthode | Oui | `ApkAI.gd:62-66` | Oui | Mêmes bornes de tour. | — |
| IA-G16 | `AIHelper.GetBuildableRooms` / `GetBuildablePositions`, `Boss.CanBuildRoom` | méthodes | Oui | `Match.gd:256-296`, `BossEngine.gd:119-171` | Oui | | — |
| IA-G17 | `AIHelper.GetDungeonDamage`, double après BMA017 (`AIHelper.cs:95-117`) | méthode | Oui | `ApkAI.gd:210-229` | Oui | | — |
| IA-G18 | `AIHelper.GetTotalTreasuresForHero` / `OfType`, `Boss.GetDungeonTreasures` | méthodes | Oui | `ApkAI.gd:195-208`, `BossEngine.gd:61-95` | Oui | Voir R-F15 pour le cas d'une salle gelée. | — |
| IA-G19 | `StatisticsCalculator.CalculateHandDiscardStatistics` (`StatisticsCalculator.cs:30-42`) | méthode | Oui | `ApkAI.gd:382-414` | Partiel | `list.Max()` planterait sur une main sans salle ; Godot prend 0. Inatteignable. | Basse |
| IA-G20 | `CalculateRoomsStatistics` (`StatisticsCalculator.cs:44-53,118-129`) | méthode | Oui | `ApkAI.gd:298-341` | Oui | | — |
| IA-G21 | `CalculateSlotStatistics` (`StatisticsCalculator.cs:55-68`) | méthode | Oui | `ApkAI.gd:343-366` | Oui | | — |
| IA-G22 | `NormalizeValues` (`StatisticsCalculator.cs:131-163`) | méthode | Oui | `ApkAI.gd:271-290` | Oui | | — |
| IA-G23 | `Early/Mid/LateRoomMinChance` (`StatisticsCalculator.cs:13-17`) | constantes | N/A | — | — | Jamais lues (`switch` vide). | — |
| IA-G24 | `RoomCalculator` : 9 tableaux de valeurs (`RoomCalculator.cs:55-64`) | données | Oui | `ApkAI.gd:16-24` | Oui | Identiques (script). | — |
| IA-G25 | `RoomCalculator` : 9 scalaires (`RoomCalculator.cs:65-73`) | données | Oui | `ApkAI.gd:25-32` | Oui | Identiques (script). | — |
| IA-G26 | `RoomCalculator.CalculateValue` (`RoomCalculator.cs:77-123`) | méthode | Oui | `ApkAI.gd:91-97` | Oui | | — |
| IA-G27 | `CalculateRoomValue` (`RoomCalculator.cs:138-149`) | méthode | Oui | `ApkAI.gd:83-89` | Oui | Godot borne les indices à 0-9 ; l'APK planterait au-delà. Inatteignable. | Basse |
| IA-G28 | `CalculateBuildOverPenalty` (`RoomCalculator.cs:125-136,243-261`) | méthode | Oui | `ApkAI.gd:141-157` | Oui | | — |
| IA-G29 | Combo Construction Zone (`RoomCalculator.cs:151-166,210-231`) | méthodes | Oui | `ApkAI.gd:102-107,116-122` | Oui | `SetupConstrucionZoneComboAdvancedRoom` renvoie 0 (bogue APK), correctement absente. | — |
| IA-G30 | `SetupDoNotPlaceDizzygasFirst` (`RoomCalculator.cs:233-241`) | méthode | Oui | `ApkAI.gd:107-108` | Oui | | — |
| IA-G31 | Modificateurs Early / Mid : appât, Goblin Armory, Dizzygas Hallway (`RoomCalculator.cs:169-203,286-308`) | méthodes | Oui | `ApkAI.gd:109-114,133-139` | Oui | Rien en Late, comme l'APK. | — |
| IA-G32 | `BaitHeroFactor` (`RoomCalculator.cs:263-284`) | méthode | Oui | `ApkAI.gd:159-172` | Oui | | — |
| IA-G33 | `FindBaitingPlayer` (`RoomCalculator.cs:310-331`) | méthode | Oui | `ApkAI.gd:174-193` | Oui | Égalité → personne, à 2, 3 et 4 joueurs. | — |
| IA-G34 | `DungeonSlotCalculator` : 7 constantes (`DungeonSlotCalculator.cs:9-21`) | données | Oui | `ApkAI.gd:34-40` | Oui | Identiques (script). | — |
| IA-G35 | `DungeonSlotCalculator.CalculateValue` (`:25-47`) | méthode | Oui | `ApkAI.gd:250-263` | Oui | | — |
| IA-G36 | Placement Minotaur, Goblin, Dizzygas (`DungeonSlotCalculator.cs:59-90`) | méthodes | Oui | `ApkAI.gd:254-259,265-269` | Oui | | — |
| IA-G37 | `DungeonSlotCalculator.DamageModifier` (`:23,49-57`) | méthode | N/A | — | — | Code mort. | — |
| IA-G38 | `DiscardCalculator` : 8 constantes (`DiscardCalculator.cs:8-22`) | données | Oui | `ApkAI.gd:42-43` | Oui | Identiques (script). | — |
| IA-G39 | `CalculateDiscardValue` (`DiscardCalculator.cs:24-62`) | méthodes | Oui | `ApkAI.gd:369-414` | Oui | | — |
| IA-G40 | `DrawCalculator.CalculateDeckDrawValue` (`DrawCalculator.cs:8-52`) | méthode | Oui | `ApkAI.gd:416-428` | Oui | | — |
| IA-G41 | `AIRoomFactorTypes` | enum | Oui | `ApkAI.gd:15` | Oui | Même ordre. | — |
| IA-G42 | `AIRoomInfo` + `BaseDeck/ai_info.json` (31 salles) | classe + asset | Oui | `ApkAI.gd:47-56`, `src/frontend/assets/data/BaseDeck/ai_info.json` | Oui | Facteurs identiques (script). | — |
| IA-G43 | `AICardDeckInfo` + `ai_info.json` PlayerChoice / HiddenHeros | classe + assets | Oui | `src/frontend/assets/data/{PlayerChoice,HiddenHeros}/ai_info.json` | Oui | Ces paquets n'ont aucune salle. | — |
| IA-G44 | `CardInfoService.GetAIRoomInfo` : exception pour une salle sans fiche IA (`CardInfoService.cs:129-158`) | méthode | Oui | `ApkAI.gd:83-89` | Différent | Godot met des facteurs vides (salles THK et wiki). Hors APK. | Basse |
| IA-G45 | Salles et héros de `BaseDeck/data.json` vus par l'IA | asset | Oui | `src/frontend/godot/data/cards.json` | Oui | 31/31 salles et 41/41 héros identiques (script). | — |
| IA-G46 | `AIPlayerInteraction.BuildRoom` : boucle jusqu'à `MaxBuildRoomLimit` (`AIPlayerInteraction.cs:165-186`) | méthode | Oui | `AI.gd:111-116`, `Match.gd:556-570` | Oui | | — |
| IA-G47 | `InternalDoPlayerActions` BuildPhase_a : capacité **et** construction choisies sur le même état, exécutées ensuite (`AIPlayerInteraction.cs:86-101`) | méthode | Oui | `AI.gd:95-116` | Partiel | Vérifié : Godot joue la capacité, puis choisit la salle à construire à un appel suivant, sur l'état d'après la capacité. Si le sort change la main, le donjon ou la ville, la salle choisie peut différer. L'oracle enregistre la décision d'avant la capacité, donc ce cas ne se mesure pas. | Moyenne |
| IA-G48 | Setup_a : défausse d'ouverture joueur par joueur (`GameBoard.cs:331-346`) | méthode | Oui | `Match.gd:1062-1092` | Oui | | — |
| IA-G49 | Choix de pioche (Haunted Library) au début du tour (`GameBoard.cs:360-380`) | méthode | Oui | `Match.gd:1207-1245`, `AI.gd:60-72` | Oui | Chemin mort (IA-G08). | — |
| IA-G50 | Prise en compte de la proximité du level-up | — | N/A | — | — | Vérifié absent dans l'IA APK : rien à porter. | — |
| IA-G51 | Cas à 4 joueurs | comportement | Oui | `ApkAI.gd:174-193` | Oui | | — |
| IA-G52 | Donjon plein (5 salles) | comportement | Oui | `ApkAI.gd:141-157,250-263` | Oui | | — |
| IA-G53 | `AiWiki.gd` | ajout Godot | — | `AiWiki.gd` | — | Hors périmètre APK. | — |

### 6B — Capacités, sorts, cibles et boucle d'interaction (lot H)

| ID | Élément source (décompilé) | Type | Présent dans Godot ? | Fichier Godot | Équivalent fonctionnel ? | Écart / Commentaire | Priorité |
|---|---|---|---|---|---|---|---|
| IA-H01 | `StatisticAI.SelectAbilityToUse` + `RandomSelection` (`StatisticAI.cs:58-70,105-118`) | méthode | Oui | `AI.gd:95-108` | Oui | Tirage uniforme parmi les capacités éligibles, une fois par fenêtre. | — |
| IA-H02 | `StatisticsCalculator.CalculateAbilityStatistics` | méthode | Oui | `ApkAI.gd:1338` | Oui | | — |
| IA-H03 | `FixedAI` → `StatisticAI` pour capacités et cibles | classe | Oui | `AI.gd:49` | Oui | | — |
| IA-H04 | `AIHelper.GetGamePhase` | méthode | Oui | `ApkAI.gd:62-66` | Oui | | — |
| IA-H05 | `AIHelper.GetUsableAbilities` | méthode | Oui | `Match.gd:249-267`, `ApkAI.gd:1338` | Partiel | Hors de son tour de construction, une IA n'a aucun coup. Voir IA-H59. | voir IA-H59 |
| IA-H06 | `AbilityCalculator.CalculateAbilityAndTargetValue` (`AbilityCalculator.cs:20-58`) | méthode | Oui | `ApkAI.gd:1297-1336` | Oui | Une carte sans `CheckXXX` n'est jamais jouée. | — |
| IA-H07 | `CheckBMA040` Annihilator | méthode | Oui | `ApkAI.gd:657-684` | Oui | Cible tirée au hasard. | — |
| IA-H08 | `CheckBMA041` Assassin | méthode | Oui | `ApkAI.gd:686-695` | Oui | | — |
| IA-H09 | `CheckBMA042` Cave-In + `CalculateWorstSlot` | méthode | Oui | `ApkAI.gd:697-723` | Oui | | — |
| IA-H10 | `CheckBMA043` Counterspell (`GetAgainstPlayers`) | méthode | Oui | `ApkAI.gd:725-776` | Oui | | — |
| IA-H11 | `CheckBMA044` Exhaustion | méthode | Oui | `ApkAI.gd:778-788` | Oui | | — |
| IA-H12 | `CheckBMA045` Fear | méthode | Oui | `ApkAI.gd:790-806` | Oui | | — |
| IA-H13 | `CheckBMA046` Freeze + `CalculateMostDamagingSlot` | méthode | Oui | `ApkAI.gd:808-837` | Oui | | — |
| IA-H14 | `CheckBMA047` Giant Size : la branche « héros actif » réutilise la liste des salles Piège (`AbilityCalculator.cs:844-847`) | méthode | Oui | `ApkAI.gd:657-676` | Partiel | Bogue APK non reproduit par défaut (le sort viserait un type de salle interdit) ; option de mesure `--ai-copy-trap-bug`. Explique les écarts d'éligibilité de Giant Size (IA-O04). | Basse |
| IA-H15 | `CheckBMA048` Jeopardy | méthode | Oui | `ApkAI.gd:839-846` | Oui | | — |
| IA-H16 | `CheckBMA049` Kobold Strike | méthode | Oui | `ApkAI.gd:848-857` | Oui | | — |
| IA-H17 | `CheckBMA050` Motivation : `GetBuildableRooms().Count() < 2` via `Boss.CanBuildRoom`, sans limite par tour | méthode | Oui | `ApkAI.gd:859-869`, `Match.gd:273` | Partiel | Godot compte les coups `buildRoom` légaux, qui disparaissent après la première construction du tour. L'APK peut jouer Motivation après sa construction (s30-p4 seq 306). | Moyenne |
| IA-H18 | `CheckBMA051` Princess in Peril | méthode | Oui | `ApkAI.gd:871-895` | Non vérifié | Port ligne à ligne conforme ; l'écart s26-p4 seq 20-24 n'est pas expliqué. | Moyenne |
| IA-H19 | `CheckBMA052` Soul Harvest | méthode | Oui | `ApkAI.gd:897-910` | Oui | Peu exercé. | — |
| IA-H20 | `CheckBMA053` Teleportation (`Take(0)` : jamais éligible) | méthode | Oui (bogue APK reproduit) | `ApkAI.gd:912-920` | Oui | | — |
| IA-H21 | `CheckBMA054` Trepidation | méthode | Oui | `ApkAI.gd:922-933` | Oui | | — |
| IA-H22 | `CheckBMA055` Zombie Attack | méthode | Oui | `ApkAI.gd:935-957` | Oui | | — |
| IA-H23 | `CheckKSA013` T.P.K. : vise le premier de `InGamePlayersPriorized` | méthode | Oui | `ApkAI.gd:959-964,1401-1404` | Partiel | Hors harnais, Godot ne propose que le lanceur comme cible ; l'APK vise le boss de plus haute XP, qui peut être un adversaire. Paquet PlayerChoice seulement. | Moyenne |
| IA-H24 | `CheckBMA009` Dark Altar | méthode | Oui | `ApkAI.gd:971-1002` | Oui | | — |
| IA-H25 | `CheckBMA013` Dracolich Lair | méthode | Oui | `ApkAI.gd:1005-1030` | Oui | | — |
| IA-H26 | `CheckBMA024` Witch's Kitchen | méthode | Oui | `ApkAI.gd:1032-1043` | Oui | | — |
| IA-H27 | `CheckBMA025` All-Seeing Eye (Spell Battle) | méthode | Oui | `ApkAI.gd:1193-1231` | Oui | Exercé seulement dans les graines 10-40. | — |
| IA-H28 | `CheckBMA027` Bottomless Pit | méthode | Oui | `ApkAI.gd:1045-1052` | Oui | | — |
| IA-H29 | `CheckBMA028` Boulder Ramp + `HasHeroPassedSlot` | méthode | Oui | `ApkAI.gd:1054-1089` | Oui | | — |
| IA-H30 | `CheckBMA030` Jackpot Stash | méthode | Oui | `ApkAI.gd:1103-1150` | Oui | | — |
| IA-H31 | `CheckBMA032` Crushinator | méthode | Oui | `ApkAI.gd:1233-1278` | Oui | La condition supplémentaire `not big_game` ne joue qu'à 5-6 joueurs (wiki). | Basse |
| IA-H32 | `CheckBMA038` Torture Chamber | méthode | Oui | `ApkAI.gd:1152-1169` | Oui | | — |
| IA-H33 | `CheckBMA039` Zombie Prison | méthode | Oui | `ApkAI.gd:1171-1191` | Oui | Choix de cible : IA-H70. | — |
| IA-H34 | `AIHelper` : dégâts du donjon, héros attiré, qui attire | méthodes | Oui | `ApkAI.gd:195-625` | Oui | | — |
| IA-H35 | `CalculateSpellValue`, `CalculateHeroValuetoSteal` | méthodes | Oui | `ApkAI.gd:1680-1698` | Oui | | — |
| IA-H36 | `AbilitySelectedInformation` (cibles préréglées) | classe | Oui | `AI.gd:28,53-60`, `ApkAI.gd:1746-1750` | Oui | | — |
| IA-H37 | `TriggerCalculator` : cache de cibles périmées (`TriggerCalculator.cs:22-27,143-149`) | classe | Oui | `ApkAI.gd:~1405` | Différent | Bogue APK non reproduit en jeu : avec des cibles périmées, l'APK abandonne la capacité (Mimic Vault, 2e Open Grave). L'IA Godot joue donc un peu mieux. Seul le harnais l'émule. | Basse |
| IA-H38 | `CheckBMA001` Draculord | méthode | Oui | `ApkAI.gd:1546-1569` | Oui | | — |
| IA-H39 | `CheckBMA002` Xyzax | méthode | Oui | `ApkAI.gd:1571-1591` | Oui | | — |
| IA-H40 | `CheckBMA003` / `CheckBMA007` | méthodes | Oui | `ApkAI.gd:1593-1597` | Oui | | — |
| IA-H41 | `CheckBMA004` Robobo | méthode | Oui | `ApkAI.gd:1599-1609` | Oui | | — |
| IA-H42 | `CheckBMA005` / `CheckBMA022` + `SelectSpellToDiscard` | méthodes | Oui | `ApkAI.gd:1611-1623` | Oui | | — |
| IA-H43 | `CheckBMA006` Seducia | méthode | Oui | `ApkAI.gd:1625-1632` | Oui | | — |
| IA-H44 | `CheckBMA008` Gorgona | méthode | Oui | `ApkAI.gd:1634-1638` | Oui | | — |
| IA-H45 | `CheckBMA010` Open Grave | méthode | Oui | `ApkAI.gd:1640-1646` | Oui | | — |
| IA-H46 | `CheckBMA011` Specter's Sanctum | méthode | Oui | `ApkAI.gd:1648-1656` | Partiel | Logique conforme ; l'état évalué diffère (IA-H69). | voir IA-H69 |
| IA-H47 | `CheckBMA012` Succubus Spa : renvoie le joueur lui-même pour `BossOpponent` | méthode | Oui | `ApkAI.gd:1648-1656` | Partiel | Bogue APK non reproduit : Godot prend l'adversaire désigné. | Basse |
| IA-H48 | `CheckBMA014` Vampire Bordello | méthode | Oui | `ApkAI.gd:1658-1662` | Oui | | — |
| IA-H49 | `CheckBMA036` Mimic Vault | méthode | Oui | `ApkAI.gd:1664-1672` | Partiel | Logique conforme ; l'état évalué diffère (IA-H68). | voir IA-H68 |
| IA-H50 | `CheckBMA037` Monstrous Monument | méthode | Oui | `ApkAI.gd:1674-1678` | Oui | | — |
| IA-H51 | `CheclKSA002` Hellcow | méthode | Oui | `ApkAI.gd:1700-1744` | Oui | Non mesuré par l'oracle. | — |
| IA-H52 | `CheclKSA003` The Brothers Wise | méthode | Oui | `ApkAI.gd:1680-1693` | Oui | | — |
| IA-H53 | `CheclKSA004` Kaw'nee | méthode | Oui | `ApkAI.gd:1695-1698` | Oui | | — |
| IA-H54 | `CheckBMA033` Centipede Tunnel | méthode | N/A | — | — | Carte jamais distribuée. | — |
| IA-H55 | Déclencheurs à cible unique (BMA017, 019, 021, 031, 034, KSA001, 005, 006, 007) | méthodes | Oui | `ApkAI.gd:1420-1440` | Oui | Résolus automatiquement. | — |
| IA-H56 | `TriggerCalculator.CalculateCommandTargets` / `CheckSpellInHandCommand` | méthode | Non vérifié | — | — | Aucun équivalent identifié. | Basse |
| IA-H57 | `CalculateTriggerTargets` : un fournisseur avec assez peu de cibles est pris tel quel | méthode | Oui | `ApkAI.gd:~1405` | Oui | | — |
| IA-H58 | `InternalDoPlayerActions` Setup_b → `BuildRoom` | méthode | Oui | `Match.gd:1141-1160` | Oui | | — |
| IA-H59 | `InternalDoPlayerActions` BuildPhase_a : `UseAbility()` pour **chaque** IA à chaque `NextStep`, construction seulement pour le joueur actif (`AIPlayerInteraction.cs:86-101`, appelé pour toutes les IA par `GamePlayBaseScene.cs:864-871`) | méthode | Oui | `Match.gd:263-267`, `AI.gd:95-108`, `BoardUI.gd:884-902` | **Différent** | Vérifié : Godot a une « politique IA » qui ne donne aucun coup à une IA hors de son tour de construction, sauf dans la fenêtre d'après la dernière construction. Mesuré sur les 24 traces de référence : 1551 des 2177 appels `UseAbility` de l'APK en BuildPhase_a viennent d'une IA hors de son tour, et 69 capacités sont jouées ainsi (Dracolich Lair 25, Jackpot Stash 13, Princess in Peril 10, Jeopardy 6…). Dans Godot, les adversaires jouent donc moins de sorts et de capacités pendant le tour des autres, et plus tard. L'oracle ne le voit pas : il rejoue les coups APK. | **Haute** |
| IA-H60 | `InternalDoPlayerActions` AdventurePhase_b / _c : `UseAbility()` pour toutes les IA | méthode | Oui | `BoardUI.gd:889`, `Match.gd:343-420` | Partiel | Une IA non active n'agit que pendant les pauses après dégâts et avant la sortie. Elle n'a pas la fenêtre d'avant l'entrée du héros (par exemple pour Trepidation). | Moyenne |
| IA-H61 | `InternalDoPlayerActions` ExtraBuildPhase → `BuildRoom` | méthode | Oui | `Match.gd:1421-1449` | Non vérifié | Lu en surface. | Basse |
| IA-H62 | Réponse de l'IA en Spell Battle (`UseAbility` puis `SetSpellBattleReady`) | méthode | Oui | `AI.gd:41-47`, `Match.gd:1678-1700` | Oui | | — |
| IA-H63 | `InternalResolveTarget` : exception ou `null` → abandon | méthode | Oui | `AI.gd:63-71` | Partiel | Godot n'abandonne que si `choose` rend −1 ; pas de chemin d'exception (IA-H37). | Basse |
| IA-H64 | `InvokeCallback` / `SimulateHumanDelays` (1-4 s, test en ligne seulement) | méthode | Oui | `BoardUI.gd:891-893` | Différent | L'IA APK hors ligne est immédiate, rythmée par les animations ; Godot attend 0,5 s (construction) ou 0,2 s (aventure). Cosmétique, renvoi au module 7. | Basse |
| IA-H65 | `HumanPlayerInteraction.AutoPlayMode` + `RandomAI` | classe | N/A | — | — | Debug seulement (`CreateTestButtons` jamais appelé) : pas d'autoplay à l'expiration du minuteur dans l'APK, rien à porter. | — |
| IA-H66 | `DoNextStepAndRefresh` : IA dans l'ordre `InGamePlayersPriorized` | méthode | Oui | `BoardUI.gd:884-902` | Partiel | Godot joue un coup par tick, dans l'ordre d'insertion des joueurs (le même en pratique). | Basse |
| IA-H67 | Exécution différée des capacités (`EnqueueAbilityTransaction` puis `NextStep`) | méthode | Oui | `Match.gd` | Partiel | Même cause que IA-G47 et R-D67 ; seul le harnais reproduit la course (`_held`). | Basse |
| IA-H68 | Écart Mimic Vault, 10 cas (`TriggerCalculator.cs:290-303`) | cause | Oui | `Match.gd:1492`, `ApkAI.gd:1664` | Partiel | Cause démontrée : le C# fige la cible dans `EnqueueAbilityTransaction` (`GameBoard.cs:1329-1330`) avant de lever `PendingToBeBuilt` (`GameBoard.cs:950-952`). La salle qui vient d'être révélée ne compte donc pas encore dans les dégâts du donjon. Godot a déjà tout retourné (`Match.gd:1492`). s13-p4 seq 1352 : dégâts APK 7, Godot 8, donc Godot accepte un héros à 8 PV que l'APK écarte. | Moyenne |
| IA-H69 | Écart Specter's Sanctum, 5 cas à 4 joueurs | cause | Oui | `Match.gd:1477-1500`, `ApkAI.gd:1648` | Partiel | Cause démontrée : l'APK décide toutes les cibles à la révélation, avant tout effet ; Godot applique chaque déclencheur avant de calculer le suivant, et ordonne la file par XP au lieu de l'ordre des sièges (`GameBoard.cs:930`). s10-p4 seq 13 : Dark Laboratory de P1 a déjà changé le nombre de sorts en main quand Godot choisit. | Moyenne |
| IA-H70 | Écart Zombie Prison, 1 cas (s21-p4) | cause | Oui | `RoomAbilities.gd:439-446`, `ApkAI.gd:1171,1759-1795` | Non vérifié | Godot retombe sur l'option 0, alors que `_chk_039` donnerait une autre cible. Hypothèse : artefact de mesure (cible préréglée non retrouvée). | Moyenne |
| IA-H71 | Écart d'éligibilité Giant Size | cause | Oui | `ApkAI.gd:670-676` | Partiel | = IA-H14. | Basse |
| IA-H72 | Écart Motivation (s30-p4) | cause | Oui | `ApkAI.gd:859-869` | Partiel | = IA-H17. | voir IA-H17 |
| IA-H73 | Écart Princess in Peril (s26-p4) | cause | Non vérifié | `ApkAI.gd:871-895` | Non vérifié | = IA-H18 ; cause non établie sans exécution. | voir IA-H18 |
| IA-H74 | `RevealAllRoomCards` : ordre et moment de résolution des cibles (`GameBoard.cs:928-968,1317-1332`) | méthode | Oui | `Match.gd:1477-1500` | Différent | Cause commune de IA-H68, IA-H69 et sans doute IA-H73 : sièges contre XP pour l'ordre, et cibles figées à la révélation contre cibles calculées après les effets. Rejoint R-D19 et R-D35 du module 5. | Moyenne |

### Non vérifié (module 6)

- IA-H18 / IA-H73 (Princess in Peril, s26-p4) et IA-H70 (Zombie Prison, s21-p4) : cause non établie.
- IA-O08 : les 91 écarts de légalité sont-ils un décalage de fenêtre du harnais ou une vraie règle ? Non tranché.
- IA-H61 (tour de construction forcé) et IA-H56 (`CalculateCommandTargets`) : lus en surface.
- `BossEngine.room_damage_with_modifiers` et `hero_hp` face à `DungeonSlot.GetTopRoomTotalDamage` et `Hero.CurrentHealth`, qui nourrissent les calculs d'appât : non relus.
- IA-H23 (T.P.K.) : comportement tiré d'un commentaire de code, pas d'un test.

### Synthèse module 6

| Lot | Lignes | OK ou N/A (sans priorité) | Écarts distincts | Renvois vers une autre ligne | dont non vérifiés | Haute | Moyenne | Basse |
|---|---|---|---|---|---|---|---|---|
| 6.0 Oracle | 8 | 5 (dont IA-O07 non comparable) | 3 | 0 | 0 | 0 | 2 | 1 |
| 6A Construction / défausse / pioche | 53 | 47 | 6 | 0 | 0 | 0 | 1 | 5 |
| 6B Capacités / cibles / boucle | 74 | 49 | 20 | 5 | 5 | 1 | 8 | 11 |
| **Total** | **135** | **101** | **29** | **5** | **5** | **1** | **11** | **17** |

Module 6 : **135 éléments audités, 101 OK ou N/A, 29 écarts distincts (dont 5 non vérifiés), 0 blocage web.** Critique 0.

- **Mesuré** : l'IA Godot prend les mêmes décisions déterministes que l'APK à 100 % pour la construction, l'emplacement, la défausse et le « passer » (4801 décisions). Elle est à 99,8 % sur les capacités et à 98 % sur les cibles des déclencheurs.
- **Seul écart Haute, IA-H59** : dans l'APK, les adversaires jouent leurs sorts et capacités aussi pendant le tour de construction des autres. Godot les en empêche par une règle d'IA à lui (`Match.gd:263-267`). Effet visible : moins de sorts adverses pendant le tour du joueur.
- **Écarts Moyenne principaux** : IA-H68, IA-H69 et IA-H74 ont une même cause. Godot calcule les cibles des déclencheurs de révélation après les effets, alors que l'APK les fige avant. IA-G47 et IA-H67 ont aussi une même cause : la construction est décidée après la capacité au lieu d'en même temps.

---

## Module 7 — Plateau / scènes de jeu

Périmètre : `DBMGameProject.Scenes.GamePlay/` (11), `.SceneBehaviors/` (8), `.Entities/` (26), `.Components/` (48). Côté Godot : `BoardUI.gd` (B), `CardUI.gd` (C), `DungeonSlot.gd` (D), `TimeBar.gd`, `CountDown.gd`, `InGameMenu.gd`, `GameOverBanner.gd`, `ApkParticles.gd`, `UiKit.gd`, tous sous `src/frontend/godot/scripts/`. Les chemins APK courts sont relatifs à `apk-original/decompiled/DBMGame/DBMGameProject.Scenes.GamePlay*/`. Les captures APK de référence sont dans `docs/reference/apk_orig/` et `apk_orig2/` (locales). Le tutoriel est renvoyé au module 8, le jeu en ligne au module 9. Cible souris uniquement : les gestes tactiles sans équivalent souris sont classés Basse.

Méthode : trois lots en lecture seule (scènes, entités, composants), puis contre-vérification à la main de chaque ligne Haute (P-A10, P-B07, P-B09, P-B20, P-B30, P-C17 et la colonne de la ville P-C47).

### 7A — Scènes et comportements de scène

| ID | Élément source (décompilé) | Type | Présent dans Godot ? | Fichier Godot | Équivalent fonctionnel ? | Écart / Commentaire | Priorité |
|---|---|---|---|---|---|---|---|
| P-A01 | `GamePlayBaseScene.Start` : musique `music_dungeon_v3`, boss, fondu des donjons, main (Base:548-576) | méthode | Oui | B:657, 1811-1858, 2070-2077 | Oui | Fondu de 0,5 s par donjon, le mien d'abord. | — |
| P-A02 | `RandomBossSelectionScene` : 0,5 s, cartes face cachée, rotation, retournement, voix, « YOU ARE <boss> » (RBSS:82-109) | scène | Oui | B:223-226, 1811-1948, 1233-1263 | Oui | Sons et voix alignés. | — |
| P-A03 | `RandomBossSelectionSceneBehavior` : 5 s CubicEase InOut, 2N + rand(N) cartes (RBSSB:16-44) | comportement | Oui | B:225, 1851-1856 | Oui | | — |
| P-A04 | Carrousel du boss : bouton « PLAY BOSS MONSTER! » ou fermeture à 2 s (RBSS:31-37, 50-64, 104-107) | scène | Oui | B:1826-1830, 1939-1948, M:528-531 | Oui | | — |
| P-A05 | `SP.InitializeGameboard` : boss limités sans le jeu complet (SP:22-30) | méthode | N/A | — | — | Boutique supprimée : tous les boss sont jouables. | Basse |
| P-A06 | `SP.OnUserPlayerVictory` : `GameStats.SPWins++` (SP:58-64) | méthode | Non (vérifié absent, `grep SPWins`) | `Profile.gd:54-72` | Différent | Ne servait qu'au déverrouillage, supprimé. | Basse |
| P-A07 | `SP.CreateBeforePlayerInteractionTask` : affiche le donjon du joueur actif (SP:69-77) | méthode | Oui | B:783-799 | Partiel | Godot ne suit que l'aventure, pas le joueur actif en construction à 3-4 joueurs. | Basse |
| P-A08 | `TopRightPanel_ChangeVisibleOpponent` : fondu entre donjons (Base:767-773, 1008-1029) | méthode | Oui | B:801-832 | Partiel | Pas de fondu. | Basse |
| P-A09 | `DoNextStepAndRefresh` : chaîne de tâches (Base:838-879) | méthode | Oui | B:860-905, 1062-1165 | Différent | Architecture événementielle ; effet équivalent, ordre fin non garanti. | Basse |
| P-A10 | `CreateCheckEndOfGameTask` : si tous les humains sont morts en fin de tour → `OnUserPlayerDefeat` (Base:1071-1078) | méthode | Non (vérifié absent) | B:4273-4302, M:2090-2135 | **Différent** | Vérifié : Godot n'ouvre l'écran de fin que sur `G.gameOver`. À 3-4 joueurs, un humain éliminé regarde les IA finir la partie au lieu de voir « YOU LOSE » à la fin du tour. | **Haute** |
| P-A11 | `WinnerScene` : voile, bandeau, nom ×2,5, particules, cristaux, OK (WS:10-87) | scène | Oui | `GameOverBanner.gd:338-392` | Oui | Calé sur les captures. | — |
| P-A12 | `PlayBossVictorySoundTask` : `sting_player_win`, voix du boss à +0,5 s (WS:89-100) | méthode | Oui | B:4281-4288 | Oui | En pass and play, le jingle dépend du siège affiché. | Basse |
| P-A13 | OK de victoire : `UnlockFromWins` puis écran HIDDEN HEROES (WS:65-87) | méthode | N/A | B:4301 | — | Déverrouillage supprimé, retour titre conservé. | Basse |
| P-A14 | `LoseScene` : « ...YOU LOSE! », pierre tombale, `sting_player_lose`, OK (LS:4-28) | scène | Oui | `GameOverBanner.gd:349-352`, B:4289-4290 | Oui | | — |
| P-A15 | `PauseScene` : PAUSED, RESUME / CARD GALLERY / SETTINGS / QUIT GAME (PS:13-75) | scène | Oui | `InGameMenu.gd:241-258` | Oui | RULES en plus (ajout). CARD GALLERY masqué en ligne dans l'APK : renvoi module 9. | Basse |
| P-A16 | Réglages depuis la pause : musique, sons, vitesse | scène | Oui | `InGameMenu.gd:260-273` | Oui | MASTER VOLUME en plus (ajout). | Basse |
| P-A17 | Jeu figé pendant la pause, hors ligne seulement (Base:1091-1100) | comportement | Oui | B:872-873 | Oui | | — |
| P-A18 | `QuitGameScene` : « QUIT GAME? / ARE YOU SURE YOU WANT TO QUIT? », CANCEL / QUIT | scène | Oui | B:4338-4342 | Différent | Godot : « Quit to menu? The current game will be lost », « YES, QUIT » / « NO, KEEP PLAYING ». `Main._confirm_box` (Main.gd:297) a déjà le gabarit APK. | Basse |
| P-A19 | `NavigatedBack` (touche Retour) : pause, puis confirmation de sortie (Base:1172-1179) | méthode | Non (vérifié absent, `grep KEY_ESCAPE\|ui_cancel`) | — | — | Échap ne fait rien. Hors cible souris. | Basse |
| P-A20 | `ModalScene` : voile 0,7 | classe | Oui | B:2563-2575 | Oui | | — |
| P-A21 | Engrenage → pause, garde `isInPauseScene` (Base:782-785) | méthode | Oui | B:4304-4310 | Oui | | — |
| P-A22 | `PhaseTitleControl` : plaque BUILD / BAIT / ADVENTURE, saut 0,5 s, masquée hors phases (PTC:44-99) | entité | Oui | B:2009-2068 | Oui | En `setup` / `boss`, Godot montre la plaque BUILD estompée (B:1190). | Basse |
| P-A23 | BAIT : vols ville → donjons | comportement | Oui | B:232, 2018-2033 | Oui | 1,0 s par héros. | — |
| P-A24 | `CreateWaitAndMoveHeroToNextSlotTask` : barre de 3 s, `char_hero_intro` (Base:924-952) | méthode | Oui | B:233, 945-1000, 2211, 2353 | Oui | | — |
| P-A25 | `OnTimerSlowDown` : barre figée pendant zoom, glisser, carrousel (Base:169-190) | méthode | Oui | B:937-938 | Partiel | Le carrousel de défausse n'existe pas (P-A39). | Basse |
| P-A26 | Spell battle : barre de 6 s au-dessus de la dernière carte (Base:210-214, 631-664) | méthode | Oui | B:234, 945-966, 3845-3910 | Oui | | — |
| P-A27 | `DoneButtonBehavior` : PASS TURN puis DONE! (DBB:25-55) | comportement | Oui | B:3518-3524, 4267-4271 | Oui | | — |
| P-A28 | Premier appui sur PASS : « HEY! YOU CAN BUILD A ROOM! STILL WANT TO PASS? » (Base:259-269) | comportement | Oui | B:3526-3550, 4206-4235 | Oui | Texte et place conformes ; voir P-C24 pour l'animation. | — |
| P-A29 | Pulsation `halt_button_pulse` du bouton DONE | comportement | Non (vérifié absent) | — | — | = P-C51. | voir P-C51 |
| P-A30 | Minuterie de 70 s du bouton DONE (Base:272) | comportement | Non vérifié | `CountDown.gd` | — | En ligne seulement : renvoi module 9. | — |
| P-A31 | `BuildRoomHandSceneBehavior` : glisser une salle, emplacements jaunes, dépôt face cachée (BRH:79-157) | comportement | Oui | B:3598-3770 | Oui | | — |
| P-A32 | `CheckMaxBuildRooms` / `UndoBuild` (BRH:158-192) | méthode | Oui | `GameManager.gd:89-147`, B:3240-3305 | Oui | Reprise par clic au lieu de glisser hors du donjon. | Basse |
| P-A33 | Lâcher sur la main = annuler (BRH:117-131) | méthode | Oui | B:3753 | Oui | | — |
| P-A34 | `PlaySpellsInHandSceneBehavior` : lâcher hors de la main joue le sort (PSH:25-91) | comportement | Oui | B:3771-3800 | Partiel | Godot limite la zone de lâcher au plateau : lâché sur la colonne de droite, le sort est annulé. Un clic joue aussi le sort (ajout). | Basse |
| P-A35 | `PlayRoomAbilitiesSceneBehavior` : toucher une salle zoome la pile, toucher la bordure résout (PRA:31-58) | comportement | Oui | B:3422-3482 | Partiel | Bouton CANCEL en plus. | Basse |
| P-A36 | `ShowRoomSlotDetail` : tout toucher sur un emplacement montre la pile complète (Base:681-718) | méthode | Oui | D:80, B:3802-3815 | Partiel | = P-B46 / P-C15. | voir P-C15 |
| P-A37 | `TargetResolverBaseSceneBehavior` : cibles en jaune, source en vert, titre = description de la carte (TRB:59-188) | classe | Oui | B:2751-3115 | Partiel | Titre tiré du message du moteur ; contour vert de la source non retrouvé. | Basse |
| P-A38 | `TriggerAbilitiesResolverSceneBehavior` (TAR:31-47) | comportement | Oui | B:3050-3115 | Oui | | — |
| P-A39 | `ShowDiscardPile` : diaporama des salles et sorts défaussés (Base:745-765) | méthode | Oui | B:4349-4382 | Différent | = P-C17. | voir P-C17 |
| P-A40 | `ShowDungeonQueue` : diaporama des héros à l'entrée (Base:720-743) | méthode | Non (vérifié absent) | B:1524-1527 | Partiel | = P-B47. | voir P-B47 |
| P-A41 | `ShowHeroInTown` : zoom à gauche (Base:787-797) | méthode | Oui | B:1385-1388 | Partiel | Appui long, zoom centré. | Basse |
| P-A42 | `ShowChallengerBossDetail` : boss + sorts « jusqu'à la fin du tour » (Base:775-780, 1221-1247) | méthode | Oui | B:4384-4393 | Partiel | = P-B61. | voir P-B61 |
| P-A43 | `ShowZoom` : sons, ralentissement de la barre (Base:1263-1280) | méthode | Oui | B:3816-3834 | Oui | | — |
| P-A44 | `HighLightCards` Red / Yellow / GreenGlow (Base:1288-1329) | méthode | Oui | B:3711-3730, 2996 | Oui | | — |
| P-A45 | `BubblesPlayerEmitter` : bulles en file, une par panneau d'adversaire, variante AGAINST | classe | Oui | B:3942-3998 | Partiel | Une seule bulle à la fois (la nouvelle remplace l'ancienne), position fixe. AGAINST : P-B12. | Moyenne |
| P-A46 | Toucher une bulle → carte zoomée, cibles en rouge (Base:1249-1261) | méthode | Oui | B:3968-4014 | Oui | | — |
| P-A47 | Bulles en solo, pas en pass and play (PaP:94-96, SP:82-88) | méthode | Oui | B:3942-3946 | Oui | | — |
| P-A48 | `IsPlayingOnlineBubbleSceneBehavior` | comportement | Non (vérifié absent) | — | — | Renvoi module 9. | — |
| P-A49 | Pass and play : 2 humains, boss aléatoires (PaP:5-20) | scène | Oui | B:1175, 1939-1948 | Oui | | — |
| P-A50 | Pass and play : la main sort puis revient, les donjons s'échangent (PaP:97-174) | méthode | Oui | B:742-781 | Oui | Barre PLAYER n en plus. | Basse |
| P-A51 | Pass and play : aventure automatique, main cachée en BAIT et aventure (PaP:44-84) | méthode | Oui | B:704-740, 921-929, 1127-1139 | Différent | Avec 2 humains, Godot montre des boutons GO / PASS TURN et la main en aventure. | Moyenne |
| P-A52 | `LeaveGameplayScene` → écran titre (Base:1103-1107) | méthode | Oui | B:4344-4347 | Oui | | — |
| P-A53 | Vitesse SLOW 1,5 / NORMAL 1 / FAST 0,5 | comportement | Oui | B:931-935 | Oui | | — |
| P-A54 | Bannière LEVEL UP puis choix (Base:911-914, 981) | méthode | Oui | B:1283-1346, 3076 | Oui | | — |
| P-A55 | `GamePlayMOScene` : messages de connexion, désertion, 60 s | classe | Non (vérifié absent) | — | — | Renvoi module 9. | — |
| P-A56 | `GamePlayTutScene` | classe | N/A | — | — | Renvoi module 8. | — |
| P-A57 | `DrawCardsDemoBehavior`, `CreateTestButtons` (debug) | comportement | N/A | — | — | Code de debug mort. | Basse |
| P-A58 | `CreateRefreshHandTask` (animation de pioche) | méthode | Oui | B:4016-4200 | Oui | Voir P-B35. | — |
| P-A59 | `CreateScene` : disposition générale (Base:196-296) | méthode | Oui | B:321-660 | Oui | Détail en 7B et 7C. | — |

### 7B — Entités du plateau

| ID | Élément source (décompilé) | Type | Présent dans Godot ? | Fichier Godot | Équivalent fonctionnel ? | Écart / Commentaire | Priorité |
|---|---|---|---|---|---|---|---|
| P-B01 | `BalloonEntity` : bulle du boss « HEY… » | classe | Oui | B:4210-4226 | Partiel | Disparaît après 6 s au lieu de se refermer au clic ; pas d'écriture progressive. Voir P-C24. | Basse |
| P-B02 | `BalloonEntity` : bulles du tutoriel | méthodes | Non vérifié | `TutorialOverlay.gd:1067` | — | Renvoi module 8. | — |
| P-B03 | `BossCharacterWithXP` | classe | N/A | — | — | Jamais instanciée. | — |
| P-B04 | `BossDetailHeaderControl` : icône, nom tronqué à 10, sous-titre à 25 | classe | Oui | B:434-466, 2133 | Partiel | Police réduite au lieu de tronquer ; pas de fondu au changement de boss. | Basse |
| P-B05 | `boss_icon_legend` (backer) | asset | N/A | — | — | Boutique supprimée. | — |
| P-B06 | `BossXPAndOrderControl` : « 800XP » | classe | Oui | B:399-402, 1274-1278 | Oui | | — |
| P-B07 | `BossXPAndOrderControl` : cercle doré = `boss.PlayerId`, l'ordre de jeu (`BossXPAndOrderControl.cs:109`) | classe | Oui | B:402, 1279 | **Différent** | Vérifié : Godot affiche « 2 » si le boss est monté de niveau, sinon « 1 » (`B:1279`). L'APK affiche l'ordre de jeu (1..N, par XP décroissante), qui ne change pas au level-up. `G.xpOrder` existe (M:1090) mais n'est pas lu. L'adversaire affiche « 1 » au lieu de « 2 ». | **Haute** |
| P-B08 | Icône du premier trésor du boss (`mp_icon_treasure_*`) | asset | Oui | B:403, 1281-1282 | Partiel | Petite variante d'icône. | Basse |
| P-B09 | Badge DAMAGE = `AIHelper.GetDungeonDamage` : dégâts modifiés des salles actives, ×2 après Minotaur's Maze (`DungeonFrameEntity.cs:413`) | classe | Oui | B:1272, 4395-4401 | **Différent** | Vérifié : `_get_total_dungeon_damage` additionne le `damage` imprimé. Goblin Armory, Dizzygas, Monster's Ballroom, Freeze et Minotaur's Maze sont ignorés, alors que `BossEngine.room_damage_with_modifiers` existe. Valeur fausse dès qu'une de ces cartes de base est en jeu. | **Haute** |
| P-B10 | Mise à jour du DAMAGE avec fondu, décalage à 2 chiffres | propriété | Oui | B:2362-2364 | Partiel | Fondu seulement pendant un pas de héros. | Basse |
| P-B11 | `BubbleEntity` « HAS PLAYED A SPELL / ROOM ABILITY », clic = zoom | classe | Oui | B:3968-4000 | Oui | | — |
| P-B12 | `CreatePlayAgainstBubble` : « AGAINST » + icônes des boss visés | méthode | Non (vérifié absent, `grep AGAINST`) | — | — | La bulle ne dit pas contre qui le sort est joué (3-4 joueurs). | Moyenne |
| P-B13 | Bulle « IS PLAYING! » | type de bulle | Non (vérifié absent) | — | — | Renvoi module 9. | — |
| P-B14 | `CarouselSelectorEntity` : « SELECT 2 CARDS TO DISCARD », CONTINUE | classe | Oui | B:1178-1245, 3221-3237 | Oui | Pas de grossissement au survol (voulu d'après les captures). | — |
| P-B15 | Sélecteur réutilisé pour les choix de cartes | classe | Oui | B:2631-2706 | Oui | | — |
| P-B16 | `CarouselShowEntity`, `MiddleCarrouselEntity` : diaporama de consultation | classes | Non (vérifié absent) | — | — | = P-C17. | voir P-C17 |
| P-B17 | `ChallengerDetail` : panneau en bas à droite | classe | Oui | B:406-466 | Oui | Écart ≤ 3 px. | — |
| P-B18 | WOUNDS : 5 icônes | compteur | Oui | B:2121-2160 | Oui | | — |
| P-B19 | SOULS : 10 icônes | compteur | Oui | B:2154-2160 | Oui | | — |
| P-B20 | Trésors du donjon = `GetDungeonTreasures` : exclut les salles en attente et gelées (`ChallengerDetail.cs:160`, `Boss.cs:252-256`) | compteur | Oui | B:2161-2162, `BossEngine.gd:61-112` | **Différent** | Vérifié : `dungeon_treasures` ne filtre pas `faceDown`. Le compteur monte dès qu'une salle est posée face cachée, au lieu de la révélation, ce qui dévoile le trésor de la salle cachée de l'adversaire. Il compte aussi les salles gelées (R-F15). | **Haute** |
| P-B21 | Panneau `challenger_panel_selected_red` quand un sort vise le boss | asset | Non (vérifié absent) | B:2927-2931 | Différent | La cible est signalée sur le sprite du boss : information équivalente. | Basse |
| P-B22 | Bouton LEVEL UP : zoom du boss ×1,3 | bouton | Oui | B:479-480, 4384-4394 | Oui | | — |
| P-B23 | `CollapsedOpponentDetail` ×(N-1) : vignettes de chaque adversaire (nom, âmes, blessures, trésors) | classe | Oui | B:801-832 | Différent | Godot montre des boutons P2, P3… et un seul panneau : on ne voit pas l'état de tous les adversaires ensemble. | Moyenne |
| P-B24 | Particules sur le joueur actif | particules | Oui | B:819-831 | Partiel | | Basse |
| P-B25 | `icon_death_profile` quand un boss meurt | asset | Non (vérifié absent) | B:1568-1597 | Différent | La pierre tombale du couloir suffit. | Basse |
| P-B26 | État sélectionné d'une vignette | comportement | Oui | B:816 | Partiel | | Basse |
| P-B27 | `ExpandedOpponentDetail` : XP, blessures, âmes, cartes en main de l'adversaire (3+ joueurs) | classe | Non (vérifié absent, `grep bg_boss_detail`) | — | — | À 3-4 joueurs, les mains adverses ne sont visibles nulle part. | Moyenne |
| P-B28 | `OneOpponentDetail` (2 joueurs) : WOUNDS / SOULS « xN » | classe | Oui | B:434-446, 2163-2166 | Oui | | — |
| P-B29 | `OneOpponentDetail` : trésors sur fond teinté à la couleur du boss | classe | Oui | B:444-446, 2167-2169 | Partiel | Fond blanc au lieu de la teinte ; même comptage faux que P-B20. | Basse |
| P-B30 | « ROOM DECK x{RoomsInHand} » / « SPELL DECK x{SpellsInHand} » = cartes **en main** de l'adversaire (`OneOpponentDetail.cs:212`) | classe | Oui | B:2169-2172 | **Différent** | Vérifié : Godot affiche la taille des pioches communes (`G.decks.rooms/spells`). Le nombre de cartes de l'adversaire n'est jamais montré ; valeur fausse en permanence. | **Haute** |
| P-B31 | `DoneButtonEntity` : PASS TURN / DONE!, fondu 0,15 s | classe | Oui | B:482-494, 4246-4271 | Oui | | — |
| P-B32 | Premier appui = bulle, second = passe | logique | Oui | B:3526-3546 | Oui | | — |
| P-B33 | Barre jaune de 70 s dans le bouton (`activateTimeOuts`) | entité | Oui (sous une autre forme) | B:1093-1096 | Différent | Chiffre en haut d'écran. Renvoi module 9. | Basse |
| P-B34 | `halt_button_pulse` | asset | Non | — | — | = P-C51. | voir P-C51 |
| P-B35 | `DrawCardEmitter` : pioche animée (DrawCardEmitter:147) | classe | Oui | B:4118-4175, 4016 | Oui | | — |
| P-B36 | `DrawCardEmitter` : défausse animée | classe | Oui | B:4062-4114 | Oui | | — |
| P-B37 | `DungeonFrameEntity` : cadre, fond du boss, fondu | classe | Oui | B:357-404, 2070-2077 | Oui | | — |
| P-B38 | 5 emplacements (pas de 140), file d'entrée | emplacements | Oui | B:67-82, 841-858, 1439-1680 | Oui | | — |
| P-B39 | Sprite du boss avec `CharacterOffset` | méthode | Oui | B:1551-1612 | Partiel | Décalage par boss non comparé. | Basse |
| P-B40 | Clic sur le boss = zoom de sa carte ×1,3 (`DungeonFrameEntity.cs:269`) | événement | Non (vérifié absent : sprite en `MOUSE_FILTER_IGNORE`, B:377-378) | — | — | On ne peut pas lire la carte du boss adverse. | Moyenne |
| P-B41 | Coup sur le boss : calque additif, secousse, voix (`DungeonFrameEntity.cs:489`) | méthode | Oui | B:2467-2497 | Oui | | — |
| P-B42 | Mort du boss : pierre tombale + voix | méthode | Oui | B:1571-1597, 2275-2283 | Oui | | — |
| P-B43 | Lueur `*_character_glow` du boss monté de niveau (`DungeonFrameEntity.cs:484`) | asset | Non (vérifié absent ; assets importés, jamais lus) | — | — | Le boss monté de niveau perd sa lueur rouge. | Moyenne |
| P-B44 | `HighLightBuildableSlots` | méthode | Oui | B:3677-3730 | Oui | | — |
| P-B45 | Voile `frozzen_card` (gel) | asset | Oui | C:127-155, B:1651-1655 | Oui | | — |
| P-B46 | Clic sur un emplacement = zoom de la pile + bordure de capacité (`DungeonFrameEntity.cs:351`) | événement | Oui | B:3422-3467, D:80, 200-204 | Partiel | = P-C15. | voir P-C15 |
| P-B47 | Clic sur la file d'entrée = diaporama des héros (≥ 2) ou zoom (`DungeonFrameEntity.cs:382`) | événement | Oui | B:1517-1527 | Partiel | Seule la première carte est lisible ; zoom par appui long seulement. | Moyenne |
| P-B48 | Salle adverse en attente décalée (`positionToBuild`) | animation | Non vérifié | B:1613-1680 | — | | — |
| P-B49 | `HandEntity` : éventail | classe | Oui | B:1986-2007 | Oui | | — |
| P-B50 | Saut de la main (pass and play) | comportement | Oui | B:742-780 | Oui | | — |
| P-B51 | `HeartDecrementEmitter` : « −N » qui monte de 140 px en 1,3 s | classe | Oui | B:2448-2465 | Oui | | — |
| P-B52 | Soin d'un héros (dégâts négatifs) | cas | Oui | B:2361-2364 | Partiel | Son joué, mais pas de cœur flottant. | Basse |
| P-B53 | `HeartEntity` : PV du héros | classe | Oui | B:2392-2418 | Oui | | — |
| P-B54 | Cœur sur la carte : dégâts ou PV courants en or quand ils diffèrent de l'imprimé (`SlotRoomCardEntity.cs:30`) | asset | Non (vérifié absent, `grep health_room`) | — | — | On ne voit ni les dégâts modifiés d'une salle ni les PV restants d'un héros blessé. Même cause que P-B09. | Moyenne |
| P-B55 | `IconCounterControlEntity` : fondu par icône | classe | Oui | B:2079-2131 | Partiel | Fondu seulement sur mon panneau. | Basse |
| P-B56 | `LevelUpBanner` | classe | Oui | B:1283-1346 | Oui | | — |
| P-B57 | Reflets `bg_lu_shine_cuarto` | asset | Non | — | — | Invisibles sur les captures. | Basse |
| P-B58 | `PhaseTitleControl` | classe | Oui | B:2009-2068 | Oui | | — |
| P-B59 | `ProgressBarEntity` : 3 s / 6 s | classe | Oui | `TimeBar.gd:1-34` | Oui | | — |
| P-B60 | Horloge `timebar_clock`, ralenti ×0,07 | asset | Non | B:937-938 | Différent | = P-C29. | voir P-C29 |
| P-B61 | `SlotDetailEntity` : zoom à plusieurs cartes (pile, boss + sorts « jusqu'à la fin du tour ») | classe | Non (vérifié absent) | B:3802-3814 | — | = P-C15. | voir P-C15 |
| P-B62 | `SpellBattleEntity` : pile au centre | classe | Oui | B:3845-3910 | Oui | | — |
| P-B63 | `TopLeftPanelEntity` : colonne de la ville, tas de défausse | classe | Oui | B:406-431, 1348-1360 | Oui | | — |
| P-B64 | File de la ville qui défile | composant | Oui | B:1348-1437 | Partiel | Ordre inversé : P-C47. | voir P-C47 |
| P-B65 | Clic sur un héros de la ville = zoom à gauche | événement | Oui | B:3802-3814 | Partiel | Appui long ou clic droit. | Basse |
| P-B66 | Clic sur le tas = diaporama de la défausse | événement | Oui | B:4349-4382 | Différent | = P-C17. | voir P-C17 |
| P-B67 | `discard_pile_legend` (backer) | asset | N/A | — | — | Boutique supprimée. | — |
| P-B68 | Bouton d'options `bt_options` | bouton | Oui | B:603-648 | Partiel | Engrenage dessiné par code au lieu de la texture APK. | Basse |

### 7C — Composants du plateau

| ID | Élément source (décompilé) | Type | Présent dans Godot ? | Fichier Godot | Équivalent fonctionnel ? | Écart / Commentaire | Priorité |
|---|---|---|---|---|---|---|---|
| P-C01 | `AddCarouselCardsBehavior` : cartes du carrousel qui montent une à une en 1,0 s, `ui_card_slide_general` (:50, :98) | comportement | Non (vérifié absent) | B:1771, 1974 | Différent | Les 7 cartes de la défausse d'ouverture apparaissent d'un coup, sans son. | Moyenne |
| P-C02 | `AppearBehavior` : zoom 0,2 s, 0,8 → 1,3 | comportement | Oui | B:3816-3843 | Oui | | — |
| P-C03 | `BaseZoomComponent` : position, verrou pendant une résolution | composant | Oui | B:3802-3814 | Partiel | Position différente ; pas de verrou. | Basse |
| P-C04 | `BossCardManagerComponent` : une main par siège | composant | Oui | B:742-776, 1681 | Oui | | — |
| P-C05 | `CardDroppedEventArgs` | DTO | N/A | — | — | | — |
| P-C06 | `CardExtractBehavior` : la carte sort de la main au-dessus de y 797, y retourne en redescendant ; carte non jouable non extraite (:166, :180) | comportement | Oui | B:3578-3618, 3750 | Partiel | Godot démarre le glisser après 12 px dans toute direction, annule au relâchement sous y 940, et laisse glisser une carte grisée (`_drag_begin` ne teste pas `playable`). | Moyenne |
| P-C07 | `CardHoverBehavior` : carte au centre le plus proche du pointeur, toute la main se replace (:106) | comportement | Oui | C:248-264, B:1996-2007 | Partiel | Godot garde la carte survolée tant que le pointeur reste dessus ; les voisines ne bougent pas. | Moyenne |
| P-C08 | `CardHoverDetailBehavior` | comportement | N/A | — | — | Jamais instancié. | — |
| P-C09 | `CardHoverWithDelayBehavior` : survol retardé de 0,3 s | comportement | Non | C:248 | Différent | | Basse |
| P-C10 | `CardManagerComponent` : main triée salles puis sorts (:116), cartes grisées | composant | Oui | B:1730-1778 | Partiel | Grisage fidèle ; tri non retrouvé côté interface (non vérifié en jeu). | Moyenne |
| P-C11 | `CardMoveBehavior` : glissement des cartes (lerp 0,009 par ms) | comportement | Oui (survol seulement) | C:238-246 | Partiel | La main est recréée à chaque rafraîchissement : quand une carte est jouée ou piochée, les autres sautent à leur place au lieu de glisser. | Moyenne |
| P-C12 | `CardPositionComponent` : éventail, carte survolée ×1,2, voisines écartées (:151-200) | composant | Oui | B:1986-2007 | Partiel | Géométrie au repos identique. Au survol, pas de grossissement (choix documenté, `docs/HANDOFF.md:116`) ni d'écartement. | Basse |
| P-C13 | `CardSelectorComponent` : choisir N cartes (:120-150) | composant | Oui | B:3221-3234, 2631-2705 | Partiel | `_popup_cards` n'accepte qu'une carte. | Basse |
| P-C14 | `CardStackSlotComponent` : pile (1 carte dessous visible), vol de la salle posée vers son emplacement, agrandissement en surbrillance (:29, :95, :210-296) | composant | Oui | D:25-140, C:98-154, B:2424-2446 | Partiel | 2 cartes dessous au lieu d'une ; pas de vol de la salle posée ; pas d'agrandissement. | Moyenne |
| P-C15 | `CardZoomComponent` + `SlotDetailEntity` : zoom d'une pile de salles ou du boss avec ses sorts du tour (:31) | composant | Oui (carte seule) | B:3433-3437, 3802-3814 | Partiel | Seule la salle du dessus est zoomée, et seulement si elle est activable ; les salles recouvertes et les sorts actifs sur un boss ne se consultent pas. Regroupe P-A36, P-A42, P-B46, P-B61. | Moyenne |
| P-C16 | `CarouselSelectorShowComponent` : fond en 0,1 s, cartes après 0,5 s (:49) | composant | Oui | B:1178-1221 | Partiel | Tout apparaît d'un coup. | Moyenne |
| P-C17 | `CarouselShowComponent` : diaporama de la défausse et de la file d'entrée (:63, `GamePlayBaseScene.cs:710-765`) | composant | Non (vérifié absent) | B:4349-4381 | Différent | Vérifié : le clic sur la défausse ouvre un `AcceptDialog` avec des noms en texte, héros morts compris ; aucune image de carte. Le clic sur la file d'entrée ne fait rien. Regroupe P-A39, P-A40, P-B16, P-B66. | Moyenne |
| P-C18 | `CountDownBehavior` (salle publique en ligne) | composant | Oui | `CountDown.gd:49-84` | Différent | Réutilisé comme minuteur de tour en ligne. Renvoi module 9. | Basse |
| P-C19 | `DoneButtonBehavior` : variantes avec minuterie, fondu 0,3 s | comportement | Oui | B:4246-4275 | Partiel | | Basse |
| P-C20 | `ExpandedOpponentComponent` : panneau adverse qui se déroule | composant | Non (vérifié absent) | B:801-832 | Différent | = P-B27. | voir P-B27 |
| P-C21 | `ExpansionScrollComponent` | composant | N/A | — | — | Boutique supprimée. | — |
| P-C22 | `HeartControlComponent` : cœur de dégâts au-dessus d'une salle modifiée, cœur du héros en fondu | composant | Oui (héros) | B:2406-2464 | Partiel | = P-B54 pour le cœur de salle. | voir P-B54 |
| P-C23 | `HeroesQueueComponent` : file d'entrée (−40 px par rang, échelle 0,4 puis 0,36, glissement 0,5 s) | composant | Oui | B:1439-1466 | Partiel | Cartes toutes à la même taille ; pas de glissement. | Basse |
| P-C24 | `HideWhenTouchBehavior` : bulle qui entre en 0,5 s et se ferme au clic extérieur | comportement | Oui | B:4210-4239 | Partiel | Bulle instantanée, fermée après 6 s. | Moyenne |
| P-C25 | `IsHoverBehavior` | comportement | N/A | — | — | Code mort. | — |
| P-C26 | `JumpBehavior` : 300 px, 0,5 s, BackEase 0,4 | comportement | Oui | B:778-780, 2065-2068 | Oui | | — |
| P-C27 | `MiddleCarouselAnimationBehavior` : bande noire qui s'ouvre en 0,5 s, opacité 0,8 | comportement | Oui | B:1185-1198, 2635-2638 | Différent | Bande affichée d'un coup, opacité 0,88 (mesurée sur capture). | Moyenne |
| P-C28 | `MiddleCarouselShowComponent` | composant | Oui (sélecteur) | B:1178-1221, 2631-2705 | Partiel | Partie diaporama : P-C17. | Basse |
| P-C29 | `ProgressBarBehavior` : 141 px, horloge `timebar_clock`, fondu 0,2 s (:23, :176) | comportement | Oui | `TimeBar.gd`, B:945-963 | Partiel | Pas d'horloge ni de fondu. | Basse |
| P-C30 | `PulseBehavior` : anneaux de capacité, 2 s | comportement | Oui | D:177-188 | Oui | | — |
| P-C31 | `RearrangeSelectorComponent` (Hellcow : échanger deux cartes) | composant | Non (vérifié absent) | M:975, `RoomAbilities.gd:928` | Différent | Choix successifs dans une liste. | Basse |
| P-C32 | `RupisLoadingBehavior` (écran de chargement) | comportement | Non | — | — | Hors plateau. | Basse |
| P-C33 | `ScrollListBehavior` | comportement | Non vérifié | — | — | Menu principal (module 4). | — |
| P-C34 | `ScrollType` | enum | N/A | — | — | | — |
| P-C35 | `ShowHideTaskComponent` | composant | N/A | — | — | Infrastructure. | — |
| P-C36 | `ShowHintComponent` | composant | Oui | B:3526-3550, 4205-4226 | Oui | | — |
| P-C37 | `SimpleHoverBehavior` sur la pile de sorts : survol = bordure rouge et cibles en évidence | comportement | Non (vérifié absent : cartes de pile en `MOUSE_FILTER_IGNORE`, B:3865) | B:3845-3881 | Différent | On ne voit pas ce que vise un sort adverse posé sur la pile. | Moyenne |
| P-C38 | `SimplePositionComponent` : pile de sorts | composant | Oui | B:3894-3908 | Partiel | Pas de glissement. | Basse |
| P-C39 | `SimpleSelectorBehavior` | comportement | N/A | — | — | Code mort. | — |
| P-C40 | `SoulLoadingComponent` (tutoriel) | composant | Oui | `TutorialOverlay.gd:988-1038` | Oui | Renvoi module 8. | — |
| P-C41 | `SpellBattleComponent` | composant | Oui | B:945-1052 | Partiel | Pas de fondu de barre. | Basse |
| P-C42 | `SpellBattleHighLightsComponent` : cible sur la pile encadrée | composant | Oui | B:2729-2741 | Partiel | Une cible sur la pile passe par une liste. | Moyenne |
| P-C43 | `SpellBattleShowComponent` : fondu 0,1 s | composant | Oui | B:3857-3881 | Partiel | | Basse |
| P-C44 | `TextAndBackgorundComponent` : bulle, décalage selon la longueur | composant | Oui | B:1214-1219 | Partiel | | Basse |
| P-C45 | `TouchOutBehavior` : fermeture au relâchement hors zone | comportement | Oui | B:1963-1969 | Partiel | Fermeture à l'appui. | Basse |
| P-C46 | `TutorialSelectorComponent` | composant | N/A | — | — | Renvoi module 8. | — |
| P-C47 | `VerticalScrollQueueComponent` : colonne de la ville, **dernier arrivé en haut** (entrée par le haut à y −110, `CreateReorderTask` donne y 120 au dernier de la liste : `VerticalScrollQueueComponent.cs:183-211`) | composant | Oui | B:1348-1437 (boucle sur `town` à partir de l'index 0, B:1368) | Différent | Vérifié dans le C# : l'APK met le héros arrivé en dernier en haut et le plus ancien (le prochain à être attiré) en bas, puis fait défiler vers le bas. Godot construit `town[0]`, le plus ancien, en haut : la colonne est inversée. À confirmer sur une capture. Pas de rebond ni d'inertie. | Moyenne |
| P-C48 | `WoundLoadingComponent` (tutoriel) | composant | Oui | `TutorialOverlay.gd:988-1013` | Oui | | — |
| P-C49 | Géométrie de la main (`HandEntity.cs:32-46`) | géométrie | Oui | B:82-84 | Oui | | — |
| P-C50 | Géométrie des emplacements et de la file (`DungeonFrameEntity.cs:356,370`) | géométrie | Oui | B:66-81 | Oui | | — |
| P-C51 | Bouton DONE : pulsation `halt_button_pulse` ×3 toutes les 5 s (`DoneButtonEntity.cs:98-106`) | comportement | Non (vérifié absent ; assets importés, jamais lus) | B:4246-4275 | Différent | Le bouton ne pulse pas pour inviter à finir le tour. Regroupe P-A29 et P-B34. | Moyenne |
| P-C52 | Bulle « HAS PLAYED » : une impulsion de 4 anneaux | comportement | Oui | B:3968-3995 | Partiel | Godot fait osciller l'alpha en boucle. | Basse |

### Non vérifié (module 7)

- P-C47 : l'inversion de la colonne de la ville est déduite du C#, sans capture qui le confirme.
- P-C10 : tri salles puis sorts de la main, non observé en jeu.
- P-B48 : décalage animé d'une salle adverse en attente.
- P-B02, P-C33 : renvoyés aux modules 8 et 4.
- Verrou de zoom pendant une résolution (`LockZoomWhenAnAbilityIsBeingResolved`), contour vert de la salle source (P-A37), bulles pour les capacités déclenchées de l'adversaire (P-A45) : non retrouvés, non tranchés.
- Les écarts visuels (durées, fondus, opacités) viennent du code ; seuls quelques-uns ont été comparés à une capture.

### Synthèse module 7

| Lot | Lignes | OK ou N/A (sans priorité) | Écarts distincts | Renvois vers une autre ligne | Non vérifié (sans priorité) | Haute | Moyenne | Basse |
|---|---|---|---|---|---|---|---|---|
| 7A Scènes | 59 | 30 | 23 | 5 | 1 | 1 | 2 | 20 |
| 7B Entités | 68 | 32 | 27 | 7 | 2 | 4 | 7 | 16 |
| 7C Composants | 52 | 17 | 32 | 2 | 1 | 0 | 15 | 17 |
| **Total** | **179** | **79** | **82** | **14** | **4** | **5** | **24** | **53** |

Module 7 : **179 éléments audités, 79 OK ou N/A, 82 écarts distincts, 4 non vérifiés, 0 blocage web.** Critique 0.

Les 5 écarts **Haute**, tous contre-vérifiés dans le code :
1. **P-A10** : à 3-4 joueurs, un humain éliminé n'a pas son écran « YOU LOSE » ; il regarde les IA finir.
2. **P-B07** : le cercle doré montre le niveau (1 ou 2) au lieu de l'ordre de jeu.
3. **P-B09** : le badge DAMAGE additionne les dégâts imprimés, sans Goblin Armory, Dizzygas, Ballroom, Freeze ni Minotaur's Maze.
4. **P-B20** : le compteur de trésors compte les salles posées face cachée, et dévoile donc le trésor de la salle cachée de l'adversaire.
5. **P-B30** : « ROOM DECK / SPELL DECK xN » montre la taille des pioches au lieu du nombre de cartes en main de l'adversaire.

Les écarts Moyenne se regroupent en quatre familles :
- **Consultation des cartes absente** : diaporama de la défausse et de la file d'entrée, zoom d'une pile de salles, clic sur un boss, sorts actifs d'un boss, vue des adversaires à 3-4 joueurs.
- **Animations manquantes** : carrousel, cascade, glissement de la main, bulles, pulsation du bouton DONE.
- **Bulles d'adversaire simplifiées** : une seule à la fois, sans « AGAINST ».
- **Colonne de la ville inversée.**

---

## Module 8 — Tutoriel

Périmètre : `DBMGameProject.Scenes.Tutorial*/` (TutorialBaseScene, Intro, BossMessage, DiscardTwoCards, FirstDrawedCard, DragCard, DoneButton, Bait, Adventure, LevelUp), `GamePlayTutScene`, `TutorialStringFactory`, `TutorialFactory`, `BalloonFactory`, `AnimatedWritingBehavior`, `TutorialSelectorComponent`, `Soul/WoundLoadingComponent`. Côté Godot : `TutorialOverlay.gd`, `GameManager.gd:24-54` (tirages imposés), `Main.gd`, `Profile.gd`, sous `src/frontend/godot/scripts/`. Positions Godot = APK + 240 px en x. Captures de référence : `docs/reference/apk_orig2/tut_11..129` (locales).

Méthode : deux lots en lecture seule (script et déroulé, puis scènes et visuels). Les 23 pages de texte ont été comparées par script avec `TutorialOverlay.gd:60-83` : identiques caractère par caractère. Aucune ligne Haute ou Critique, donc rien à contre-vérifier ; seul T-B18 (minuterie de 6 s, `TutorialOverlay.gd:1083`) a été relu à la main.

### 8A — Script et déroulé

| ID | Élément source (décompilé) | Type (classe/méthode/asset/scène) | Présent dans Godot ? | Fichier Godot | Équivalent fonctionnel ? | Écart / Commentaire | Priorité |
|---|---|---|---|---|---|---|---|
| T-A01 | Proposition au 1er lancement : `IsFirstGameplay` → boîte « TUTORIAL / DO YOU WANT TO PLAY A TUTORIAL GAME? », OK → `GamePlayTutScene`, CANCEL → flag à faux puis HOW MANY PLAYERS (MainMenuScene.cs:60-88) | MainMenuScene, `singlePlayerButton.ButtonTap` | Oui | Main.gd:286-293 ; Profile.gd:98-107 | Oui | Mêmes textes, mêmes branches. Le flag est enregistré dans `settings.first_gameplay`. | — |
| T-A02 | Bouton OPTIONS > TUTORIAL (OptionsScene.cs:62-67) | OptionsScene | Oui | Main.gd:596-601 | Oui | `start_tutorial()` est appelé sans transition, comme dans l'APK. | — |
| T-A03 | Le constructeur consomme le flag : `IsFirstGameplay=false` puis `SaveToDisk` (GamePlayTutScene.cs:79-86) | GamePlayTutScene ctor | Oui | Main.gd:335-339 | Oui | Le flag tombe dès le lancement, pas à la fin. Il n'y a pas de drapeau « tutoriel terminé », comme dans l'APK. | — |
| T-A04 | Réaffichage forcé après mise à jour : `CheckForcePlayTutorial("2.2.6","2.2.4")` repasse `IsFirstGameplay` à vrai (Game.cs:119, GameStats.cs:33-42) | Game / GameStats | Non (`grep -in "version\|CheckForce" Profile.gd` : aucune version de tutoriel) | — | — | Pas de mécanisme de version. Sans objet pour un port web neuf. | Basse |
| T-A05 | Plateau imposé : `InitializeGameBoardTutorial`, jeu de base, 2 joueurs, humain BMA003 (KING CROAK), IA BMA006 (SEDUCIA) avec `FixedAI` (GameBoardExtensions.cs:19-52) | Extension GameBoard | Oui | GameManager.gd:24-45 ; ApkAI.gd (port de FixedAI) | Oui | Les bosses, le jeu de base et l'IA FixedAI sont conformes. | — |
| T-A06 | Pioches prioritaires : salles `032,026,034,027,016`+`010,020,019,009,021`+`022,021` ; sorts `041,055,054,044` ; héros `064,068` (`PrioritizeQueueCards`, sommet en premier) | GameBoardExtensions.cs:24-37,207-219 | Oui | GameManager.gd:27-29,39-41,47-54 | Oui | Les trois listes et leur ordre sont identiques. | — |
| T-A07 | `RandomProvider.Seed = 2832` : tout le reste des pioches et de l'aléatoire de l'IA | GameBoardExtensions.cs:23 | Partiel | GameManager.gd:26,34-37 | Partiel | Le générateur .NET n'est pas reproductible. Hors cartes imposées, le reste des pioches et l'aléatoire de l'IA diffèrent de l'APK, et les étapes avalées en dépendent (voir T-A31). Écart reconnu dans le commentaire de `GameManager.gd:26`. | Moyenne |
| T-A08 | Boss humain forcé : le carrousel s'arrête sur BMA003 (`userSelectedBosses`, cs:115-119) | `InitializeGameboard` | Oui | TutorialOverlay.gd:515-516 ; BoardUI.gd:1823 | Oui | Le gate `boss` renvoie `BMA003`. | — |
| T-A09 | Intro partie 1 (avant le carrousel) : page01, page02, page03, un tap par page (`TutorialIntroScene(true)`, cs:165-171) | TutorialIntroScene | Oui | TutorialOverlay.gd:352-358 (déclenchement), 596-603 | Oui | Textes identiques, déclenchée au démarrage, le carrousel attend (gate `carousel`, l.511). | — |
| T-A10 | Intro partie 2 (après le choix du boss) : page04, page05 (10 âmes), page08 (5 blessures + 2e texte) (cs:150-160) | TutorialIntroScene(false) | Oui | TutorialOverlay.gd:359-363, 605-621 | Oui | Déclenchement dès que `p0.boss != null`. Texte, second texte et animation des icônes conformes. | — |
| T-A11 | Défausse d'ouverture : `DiscardTwoCards`, 0,9 s après l'ouverture du sélecteur (CarouselSelectorShowComponent.cs:58) | TutorialDiscardTwoCardsScene | Oui | TutorialOverlay.gd:364-372, 623-627, 310-318 | Oui | Délai de 0,9 s et texte conformes. | — |
| T-A12 | Seules BMA026 et BMA055 sont choisissables, jamais désélectionnables ; mauvaise carte = moquerie ; bonne = encouragement ; 2e bonne = « HIT CONTINUE, MINION » (TutorialSelectorComponent.cs:35-58) | TutorialSelectorComponent | Oui | TutorialOverlay.gd:553-575 | Oui | Les 4 cas sont couverts, y compris le re-clic sur une carte déjà choisie. | — |
| T-A13 | Mains-pointeurs sur BMA026 et BMA055, fondu à la sélection (AddCarouselCardsBehavior.cs:117-130) | AddCarouselCardsBehavior | Oui | TutorialOverlay.gd:1120-1146 | Oui | Pointeurs et fondu de 0,5 s présents (relève du lot visuel). | — |
| T-A14 | Salle 1 : `ForcedToDragCard`=BMA034 en Setup_b, DONE verrouillé, page13 en 2 textes (cs:184-192) | TutorialDragCardScene | Oui | TutorialOverlay.gd:243-246, 374-379, 630-643 | Oui | Les deux textes s'enchaînent chacun avec un tap. Seule BMA034 est glissable (gate `drag`, l.523-530), DONE est verrouillé (l.544-548). | — |
| T-A15 | Pose interdite sur un emplacement occupé pendant le tutoriel (`IsTutorialModeActive`, BuildRoomHandSceneBehavior.cs:174) | BuildRoomHandSceneBehavior | Oui | TutorialOverlay.gd:531-532 ; BoardUI.gd:3660 | Oui | Seul l'emplacement libre est accepté, comme dans l'APK : aucun emplacement précis n'est imposé. | — |
| T-A16 | Après la pose : carte non reprenable, DONE déverrouillé, scène page18 « WHEN THE "PASS TURN"… » (cs:336-347) | `CardToRevealAdded`, TutorialDoneButtonScene | Oui | TutorialOverlay.gd:380-383, 650-657, 549-550 | Oui | Déclenchée quand `buildsThisTurn>=1` et que le bouton PASS est affiché. L'annulation de la pose est bloquée. | — |
| T-A17 | Salle 2 (ExtraBuildPhase) : BMA016, page19, puis « NOW HIT "DONE" » (cs:193-201,348-354) | TutorialDragCardScene / DoneButtonScene | Oui | TutorialOverlay.gd:248-251, 384-391 | Oui | Phase `build` avec `setupForced` au tour 0. Textes conformes. | — |
| T-A18 | Carte piochée BMA022 : scène page19_a au `BeginningOfTurn` du tour 0 (cs:372-380, TutorialFirstDrawedCardScene) | TutorialFirstDrawedCardScene | Oui | TutorialOverlay.gd:392-403, 660-670 | Oui | Déclenchée au début du tour 1 si BMA022 est en main ; sinon l'étape saute. | — |
| T-A19 | BuildPhase_a (humain) : la scène LEURRE s'exécute avant la page16 (`task = Bait.ContinueWith(task)`, cs:204-213) | TutorialBaitScene (page20 + icônes, page21) | Oui | TutorialOverlay.gd:404-408, 689-696 | Oui | L'ordre leurre puis page16 est respecté (`bait` puis `build3`). Textes et icônes conformes. | — |
| T-A20 | Salle 3 : BMA027 forcée, page16, puis « NOW HIT "DONE" » (cs:202-210) | TutorialDragCardScene | Oui | TutorialOverlay.gd:252-257, 409-416 | Oui | Conforme. | — |
| T-A21 | Adventure_b, humain avec `Souls==0` : main verrouillée, page22 sur le héros et le total de dégâts (cs:236-239) | TutorialAdventureScene p22 | Oui | TutorialOverlay.gd:417-422, 698-707 | Oui | Condition équivalente : souls vides, entrée non vide. Verrou de main via le gate `tap`/`drag` (l.521-530). | — |
| T-A22 | Adventure_c, humain : main verrouillée, page23 (« HIT THIS ROOM ») attachée à `Slots[2].TopRoom`, rejouée à chaque tour de barre (cs:240-252,258-278) | p23 + `ProgressBarBehavior_Loop` | Partiel | TutorialOverlay.gd:424-427, 276-287, 330-345, 708-716 | Partiel | L'APK rejoue p23 à chaque tour de la barre de temps. Godot fige la partie et rejoue la consigne après 8 s sans action (`NAG`). Équivalent en pratique. L'indice `_slot_node(0)` correspond bien à BMA027 (index Godot 0 = 1re salle traversée). | Basse |
| T-A23 | Ouverture du détail de BMA027 avec le héros 064 dedans (`CheckPlayRoomAbilityCondition`) : verrou du carrousel, page24 « TAP THE ROOM DESCRIPTION… », barre en pause (cs:322-335,386-394) | `OnRoomDetailShow`, p24 | Oui | TutorialOverlay.gd:482-495, 276-287, 722-725 | Oui | Texte conforme, `_hit_state` reprend les conditions. La partie reste figée pendant la consigne (équivalent de `Pause`/`Resume`). | — |
| T-A24 | Âme de 064 (`CheckFirstSoulHero`, `firstWound`) : scène page26 « SPLENDIT… » + DONE déverrouillé (cs:215-221,418-424) | p26 | Oui | TutorialOverlay.gd:428-433, 460-465, 731-735 | Oui | Déclenchée sur « âme 064 + animations finies ». Pas de contrôle « joueur actif = humain », sans conséquence ici. | — |
| T-A25 | Sort BMA041 : `CheckPlaySpellCondition` (héros 068 à l'entrée de la mine adverse, sort en main), page27 forcé sur le mage, cible imposée (cs:226-235,396-405) | TutorialDragCardScene p27 (isReinforcement) | Oui | TutorialOverlay.gd:259-274, 434-439, 533-543 | Oui | Texte immédiat comme `isReinforcement:true`. Le coup est limité à `playSpell` sur 068 et la zone de dépôt à l'entrée de la mine adverse. L'APK force « le 1er sort de la main » : même carte, car BMA055 est défaussé. | — |
| T-A26 | Rappel de p27 sur 068 à chaque tour de barre (`ProgressBarBehavior_Loop`, cs:269-277) | `ProgressBarBehavior_Loop` | Partiel | TutorialOverlay.gd:330-338 | Partiel | Même équivalence par le rappel à 8 s que T-A22. | Basse |
| T-A27 | Dépôt de BMA041 (`CardDropped`, `Handled`) : barre en pause, 0,5 s, puis page28 (cs:312-318) | `MyHand_CardDropped` | Oui | TutorialOverlay.gd:294-296, 440-444 | Oui | Délai de 0,5 s, texte et partie figée tant que le sort est sur la pile. | — |
| T-A28 | Effet du sort résolu (`AbilityApplyDone` + PV = initial+3) : page29 (cs:320-326,407-415) | p29 | Oui | TutorialOverlay.gd:445-449, 476-480 | Partiel | Godot exige en plus que p28 ait été montrée (`_done.has("adv28")`) ; pas l'APK. Sans conséquence si p28 se joue. | Basse |
| T-A29 | Blessure de l'IA sur 068 (`CheckFirstWoundHero`, `firstSoul`) : page25 « HAHA… CROAKS » (cs:222-225,427-433) | p25 | Oui | TutorialOverlay.gd:449-453, 468-474 | Partiel | L'APK le montre au `NextStep` suivant en AdventurePhase_b avec l'IA active. Godot la lit comme un état permanent (blessure de 068 au tour ≤ 1), sans délai. Le texte est le même, le moment peut différer. | Basse |
| T-A30 | Première montée de niveau du boss humain : p30 (« WOW!! … ») puis p31 (« YOU DON'T KNOW… ») (cs:361-370, TutorialLevelUpScene) | CreateBeforeLevelUpTask | Oui | TutorialOverlay.gd:455-457, 758-770 ; BoardUI.gd:1288,3069 | Oui | `levelup` et `choice` retardent la bannière jusqu'à la fin des deux pages. Textes conformes ; le jeu reprend ensuite normalement. | — |
| T-A31 | Étapes dont la condition ne survient pas (tirage ou IA différents) | architecture générale | Partiel | TutorialOverlay.gd:1-16, 329-458 | Différent | L'APK suppose le déroulé. Godot saute une étape dont la condition n'arrive pas et ne bloque jamais le joueur. C'est un choix défensif (mieux que de planter), mais p25/p26/p28/p29 peuvent ne jamais s'afficher si l'IA ou le hasard s'écartent. | Moyenne |
| T-A32 | Restrictions limitées au tour 0 (`NumberOfTurns==0`), puis jeu normal (cs:181 ...) | `CreateBeforePlayerInteractionTask` | Oui | TutorialOverlay.gd:204-205 (`_turn() <= 1`) | Oui | À la fin, le jeu continue sans tutoriel, comme dans l'APK (captures tut_126-129). | — |
| T-A33 | Scènes de rappel (carte invalide / DONE verrouillé) : `ShowReinforcementScene`, 4 branches (cs:280-309) | InvalidCardPlayed, DoneHaltButton_PressedWhenLocked | Oui | TutorialOverlay.gd:523-530, 544-548, 578-593 | Partiel | Drag invalide et DONE verrouillé sont couverts. En revanche un simple clic (`tap`, l.553-562) sur une mauvaise carte est refusé sans scène de rappel. À confirmer côté APK (`CardExtractBehavior.cs:216`). | Basse |
| T-A34 | Quitter / passer : aucun bouton « skip » ; PauseScene > QUIT GAME → IntroScene (`LeaveGameplayScene`, GamePlayBaseScene.cs:1103) ; fin de partie → même retour | PauseScene / LeaveGameplayScene | Oui | Main.gd:543-546 ; BoardUI (`setup(..., show_title)`) | Oui | Aucun skip dans l'APK ni dans Godot ; pas d'écran de fin dédié ; retour à l'écran titre. | — |
| T-A35 | Bulle de rappel `DoneHint` « HEY! YOU CAN BUILD A ROOM! STILL WANT TO PASS? » (hors tutoriel : ShowHintComponent) | TutorialStringFactory.DoneHint | Oui | BoardUI.gd:3532-3543, 4219 | Oui | Texte utilisé en jeu normal comme dans l'APK. | — |
| T-A36 | Chaînes `HitHalt`, `HitGo`, `HitPlay`, `HitPassAll`, `GetSpellBattleMessage`, `GetSpellBattleCardMessage`, `HitOkButton`, `TutorialEnum.none/HitX` | TutorialStringFactory / TutorialEnum | N/A | — | — | Aucune utilisation dans le décompilé (`grep -rn "TutorialEnum.Hit\|GetSpellBattle\|HitOkButton"` : seulement leur définition). Code mort, absent de Godot à raison. | — |

### 8B — Scènes, bulles et pointeurs

| ID | Élément source (décompilé) | Type (classe/méthode/asset/scène) | Présent dans Godot ? | Fichier Godot | Équivalent fonctionnel ? | Écart / Commentaire | Priorité |
|---|---|---|---|---|---|---|---|
| T-B01 | Voile noir plein écran `mascara_black` (TutorialBaseScene.cs:55-66, 172-180) | Scène modale, asset `BackgroundMask` | Oui | TutorialOverlay.gd:26, 827-844 | Oui | Alpha 165/255 mesuré sur les captures ; reste tel quel sous tous les écrans (sauf T-B02). | — |
| T-B02 | Cadre `mascara_00` à trou, p05 (528) et p08 (442), x = LimitedRightEdge-439 (TutorialIntroScene.cs:68-84) | Asset `mascara_00`, panneau violet de droite éclairé | Oui | TutorialOverlay.gd:831-837 ; appels 614, 618 (x 1481) | Oui | Conforme à `tut_20` : le panneau Wounds/Souls est éclairé. | — |
| T-B03 | Tap plein écran : `backTouch` TouchTap → `flowTask.TrySkip` ; `CreateBackTapTask` ; actif seulement quand `TouchPanelState.Count == 0` (TutorialBaseScene.cs:67-75, 105-109, 195-198) | TouchGestures sur collider plein écran | Oui | TutorialOverlay.gd:812-825, 940-964 | Oui | Un clic gauche relâché saute la frappe ou la tâche en cours, sinon passe à la suite. Le garde « aucun doigt posé » n'est pas nécessaire en souris : le relâchement part vers le nœud qui a reçu l'appui. | — |
| T-B04 | Entités « attachées » (`AttachEntity`, `detachedEntitiesBy*`) dessinées au-dessus du voile (TutorialBaseScene.cs:99-113, 179-193) | Re-parentage d'entités | Oui | TutorialOverlay.gd:773-799 (`_holes`, `_sprites`), 846-863 (`_minus`) | Oui | Rendu équivalent : trous découpés dans le voile et sprites du boss recopiés dessus. Un clic dans un trou n'atteint pas l'entité (voile `MOUSE_FILTER_STOP`, l.779). Voir T-B33 pour le comportement exact de l'APK. | — |
| T-B05 | Mains `hand1`/`hand2` : visibles si position ≠ 0, flip, rotation -90°, origine (1,0) ; bug : la main 2 applique flip/rotation à la transform de la main 1 (TutorialBaseScene.cs:140-170) | `TutorialFactory.CreateTutorialHand`, asset `hand` | Oui | TutorialOverlay.gd:91-125 (classe Hand), 909-923 ; cas p22 l.701-711 | Oui | Le bug de l'APK est reproduit : p22 a la main 1 retournée vers le héros et la main 2 normale. Confirmé sur `tut_80`. | — |
| T-B06 | `ShakeBehavior` : amplitude 20, `AmplitudeDecrement=0`, `VelocityFactor=0.12` → sin(7,2 t), axe horizontal (vertical si main verticale ou pointeur) (TutorialFactory.cs:30-35 ; ShakeBehavior.cs) | Behavior | Oui | TutorialOverlay.gd:30-31, 114-125 | Oui | Constantes identiques, tremblement sans fin, phase à 0 à la création. | — |
| T-B07 | Ouverture d'une scène : `CrossFadeTransition(ModalTransitionsTime)` ; fermeture : `Pop()` sans transition (GamePlayTutScene.cs:136-142 ; TutorialBaseScene.cs:179-193) | Transition de contexte | Oui | TutorialOverlay.gd:29, 1099-1105 ; `_end` 801-810 | Oui | Fondu de 0,2 s à l'entrée, suppression immédiate à la sortie. | — |
| T-B08 | `AnimatedWritingBehavior` : 15 lettres/s, `elapsed*15`, reprise à `startingLength`, tap = tout affiché, bourrage « ā » du mot en cours pour figer le retour à la ligne (AnimatedWritingBehavior.cs:11-72) | Behavior de texte | Oui | TutorialOverlay.gd:27, 966-980 | Oui | `visible_characters` sur le texte complet : le retour à la ligne est précalculé, comme avec le bourrage de l'APK. Le saut d'un tap est correct. | — |
| T-B09 | Bulles : medium 608×225, long 880×213, large 777×360, globe 690×360 (marge 13,5), texte échelle 1,2, interligne 6, texte à (-0,45 L, -0,32 H) (BalloonFactory.cs:22-60 ; BalloonEntity.cs:69-87) | `BalloonFactory.Bubble*`, atlas `txt_bg_*` / `globe_bg_large` | Oui | TutorialOverlay.gd:44-50, 865-891 | Oui | Largeur de texte 0,8 L × 1,2 ; police arcadepix 25 px mesurée. Le sprite est centré à la position APK + 240 (origine centre). | — |
| T-B10 | `TutorialBossMessage` : bulle long à (720, 864), tap pour continuer (TutorialBossMessage.cs:21-41) | Scène | N/A | — | — | Code mort : `grep -rn TutorialBossMessage --include=*.cs .` hors Scenes.Tutorial → 0 résultat. Le « YOU ARE … » du tutoriel vient de `RandomBossSelectionScene.cs:76` (BoardUI.gd:1216), hors de ce lot. | — |
| T-B11 | `TutorialIntroScene(isFirstPart)` : p01-p03, globe (900,350), King Croak, main (800,485) après chaque frappe, tap pour continuer (TutorialIntroScene.cs:30-48, 56-111) | Scène | Oui | TutorialOverlay.gd:596-603 | Oui | Un seul texte par étape, 0,2 s de délai après la frappe, main posée après la frappe : tout y est. | — |
| T-B12 | King Croak : `kingcroak_anim`, 7 images à 8 i/s en boucle, échelle 8,7, retourné, position (100,343) (TutorialIntroScene.cs:144-161) | Entité animée | Oui | TutorialOverlay.gd:53-57, 893-907, 1109-1113 | Oui | x = 349 au lieu de 340 : décalage de +9 px mesuré par corrélation (l.53). Écart cosmétique. | Basse |
| T-B13 | Intro 2, p04 : même scène globe + King, mains (800,485) (cs:30-47, 108-117) | `isFirstPart:false` | Oui | TutorialOverlay.gd:605-621 | Oui | Le décor noir de `tut_17..20` est fourni par `board.make_intro_field()` (l.610). L'APK le tient du plateau non encore distribué. | — |
| T-B14 | p05 `SoulLoadingComponent(10)` : détail à (690,385), icônes tous les 50 px ; vides en parallèle (0,2 s), pleines une à une, lueurs en parallèle ; `FinishState` ; main (RightEdge-395, 640) (SoulLoadingComponent.cs ; cs:56-72, 120-134) | Composant + tâche | Oui | TutorialOverlay.gd:988-1013 ; appel l.614 (base 930,385) | Oui | Le détail est retiré au début de l'étape suivante (l.943-945), comme dans l'APK. | — |
| T-B15 | p08 `WoundLoadingComponent(5)` + `boss_tombstone` (origine (0,0,5), x = 5×50) ; 2e texte qui prolonge le 1er (`text.Length`) ; main (RightEdge-395, 580) (WoundLoadingComponent.cs ; cs:73-86, 136-152) | Composant | Oui | TutorialOverlay.gd:988-1013 (pierre l.1000, 1010) ; appel 618 | Oui | Pas de lueur pour les blessures, conforme à l'APK. Confirmé sur `tut_20` (5 gouttes + RIP). | — |
| T-B16 | `TutorialDiscardTwoCardsScene` : bulle medium (720,200), pas de Delay 0,2 s, main verticale non retournée à (720,576), voile plein sans trou (TutorialDiscardTwoCardsScene.cs:15-48) | Scène | Oui | TutorialOverlay.gd:623-628 | Oui | Confirmé sur `tut_22` (bulle centrée en x=960, main au centre). Déclenchement 0,9 s après l'ouverture du sélecteur : `CarouselSelectorShowComponent.cs:58` ↔ Godot l.316-319, 369-376. | — |
| T-B17 | Pointeurs de défausse sur BMA026 et BMA055 : local (-50,400), rotation -90°, tremblement vertical, fondu de 0,5 s retiré quand la carte est choisie (AddCarouselCardsBehavior.cs:117-131 ; TutorialSelectorComponent.cs:57-64) | `InTutorialModeAddHandsToDiscardCards` | Oui | TutorialOverlay.gd:1120-1146 | Oui | Conforme à `tut_22` : deux mains doigt en haut sous Ligers et Zombie Attack. | — |
| T-B18 | `TutorialSelectorComponent.UpdateSelectedCards` : seules les 2 cartes ciblées se choisissent. Mauvais choix → `BossHint = WrongCardPick`, bon choix → `RightCardPick`, 2 choisies → `ClickContinue`. La bulle `BossHint` (boss_globe 230×400, enfant du boss) apparaît en 0,5 s (échelle 0,8→1, opacité 0,5→1) et ne se ferme qu'en touchant HORS de la bulle (TutorialSelectorComponent.cs:34-55 ; HideWhenTouchBehavior.cs ; DungeonFrameEntity.cs:137-146, 260-262) | Bulle d'indice | Oui | TutorialOverlay.gd:565-576 (logique), 1067-1088 (bulle), 1091-1093, 321-326 (minuterie) | Partiel | La logique de choix est identique. Écarts sur la bulle : (a) Godot la retire automatiquement après 6 s (`_hint_t = 6.0`) alors que l'APK n'a aucun minuteur ; (b) l'apparition est instantanée, sans fondu ni zoom ; (c) Godot la ferme sur n'importe quel clic (`_input`, âge > 0,25 s), l'APK seulement hors de la bulle. Au bout de 6 s, « HIT CONTINUE, MINION » disparaît alors que le bouton CONTINUE n'est pas pressé. Géométrie fixe mesurée sur `tut_26` (1285, 589, 238×150). | Moyenne |
| T-B19 | `TutorialFirstDrawedCardScene` : bulle medium (720,162), sans Delay, main retournée non verticale à (936,378), main du joueur attachée ; `IsCardEnabled` sur BMA022 (TutorialFirstDrawedCardScene.cs:34-72) | Scène | Oui | TutorialOverlay.gd:660-675 | Oui | Confirmé sur `tut_62` : main à x 1175-1345, y 385-475. Godot fige en plus la carte piochée en vol (l.664-667) pour la garder au-dessus du voile. | — |
| T-B20 | `TutorialDragCardScene` (p13/p16/p19) : bulle long (720,645), 2 messages si non renfort, main enfant de la carte imposée en local (50,-450), rotation +90°, tremblement vertical, retirée à `End` (TutorialDragCardScene.cs:39-102) | Scène + pointeur de carte | Oui | TutorialOverlay.gd:630-648, 925-938 | Oui | Confirmé sur `tut_28` : bulle centrée à y 645, main au-dessus de la carte. Le 2e message se retape depuis 0 (l.639). Seule la main du joueur est éclairée (trou = `_hand_rect`). | — |
| T-B21 | Variante renfort (`isReinforcement`) : texte d'un coup, main reposée (cs:290-307 ↔ TutorialDragCardScene.cs) | Scène | Oui | TutorialOverlay.gd:578-594 ; `gate("drag")` l.529-534 ; `gate("pass")` l.543-546 | Oui | Mêmes appels que l'APK : p13, p19, p16 selon la phase, et le DONE verrouillé. | — |
| T-B22 | `TutorialDoneButtonScene` : bulle long (720,226), main verticale retournée à (position du bouton + (-50,-210)), bouton éclairé, hit-test du bouton désactivé (TutorialDoneButtonScene.cs:23-74) | Scène | Oui | TutorialOverlay.gd:650-658 | Oui | Confirmé sur `tut_46` : la main (≈905-1000, 290-460) se pose sur le bouton DONE. Les cartes de la main restent assombries, comme l'APK (seul le bouton est attaché). | — |
| T-B23 | `TutorialBaitScene` : bulle large (800,350), main retournée à (LimitedLeftEdge+200, 320), colonne HEROES IN TOWN attachée, 2 pages (TutorialBaitScene.cs:13-82) | Scène | Oui | TutorialOverlay.gd:689-696 | Oui | Confirmé sur `tut_65`/`tut_67` : colonne gauche éclairée, bulle à (1040,350). Les icônes du premier texte sont retirées au début du second. | — |
| T-B24 | Icônes de trésors : fighter/thief/cleric/mage tous les 160 px à (bulle + (-240,60)), décalages y 3/6/0/6, fondu 0,5 s (TutorialBaitScene.cs:84-125) | `CreateShowDetailTask` | Oui | TutorialOverlay.gd:1038-1058 | Oui | Position (800+160 i, 410+dy), centre. Non confirmé sur capture : `tut_66`/`tut_67` ne montrent pas les icônes tapées. | — |
| T-B25 | `TutorialAdventureScene` p22 : bulle large (600,250), main 1 (320,700) retournée par le bug, main 2 (RightEdge-710, 490), héros + dégâts totaux attachés (cs:50-60) | Scène | Oui | TutorialOverlay.gd:698-756 (cas 22) | Oui | Confirmé sur `tut_80` : bulle centrée à (840,250), main 1 sur le héros doigt à gauche, main 2 sur DAMAGE doigt à droite. | — |
| T-B26 | p23 : bulle medium (salle + (0,-350)), main (salle + (-250,0)), salle et barre attachées, barre mise en pause pendant la scène (cs:61-69, 160-165) | Scène | Oui | TutorialOverlay.gd:698-756 (cas 23), `_holding` 290, `NAG` 32 | Partiel | Géométrie conforme à `tut_84` (bulle (1003,373), main à x≈750). Différence de flux : Godot fige la partie tant que le joueur n'a pas joué la salle et rejoue la consigne après 8 s sans action. L'APK relance la barre et ne rejoue qu'à chaque tour de barre. Plus indulgent, ne bloque jamais. | Basse |
| T-B27 | p24 : bulle long (VirtualWidth/2, VirtualHeight/2-350), main (centre + (-300,200)), voile plein (cs:70-75) | Scène | Oui | TutorialOverlay.gd:698-756 (cas 24), `_on_room_detail` 482-497 | Oui | Confirmé sur `tut_100` : la zone de détail de salle est assombrie sous le voile plein. | — |
| T-B28 | p25 / p26 : bulle medium et main relatives au panneau (panel + (-550,100/200), panel + (-200,50/150)) ; boss et panneau de détail attachés (cs:76-90) | Scène | Oui | TutorialOverlay.gd:698-756 (cas 25 et 26) | Oui | Panneaux et bulles codés en dur (1709/1159 en x). Conforme à `tut_108` (p26 : main (1509,633)). Pour p25, aucune capture ne montre la scène : Non vérifié visuellement. | — |
| T-B29 | p27 (via DragCard renfort, héros attaché) : « LOOKS LIKE SOMEONE HAS VISIT… », main sur le sort (GamePlayTutScene.cs:231, 274) | Scène | Oui | TutorialOverlay.gd:630-643 (appels l.355-358, 380-386) | Oui | Même coup attendu que l'APK : entrée adverse comme zone de dépôt (`gate("spell_drop")` l.536-538). | — |
| T-B30 | p28 : bulle long (VirtualWidth/2, VirtualHeight/2-400), main (400,350), carte de sort, main et barre attachées (cs:106-114) | Scène | Oui | TutorialOverlay.gd:698-756 (cas 28) | Oui | Confirmé sur `tut_118` : bulle centrée à (960,140), main à (640,350), carte Assassin et barre éclairées. | — |
| T-B31 | p29 : bulle long (VirtualWidth×1,2, 150), main verticale (200,350) (cs:115-123) | Scène | Oui | TutorialOverlay.gd:698-756 (cas 29) | Oui | Positions + 240 conformes (bulle (1104,150), main (440,350)). Aucune capture dans l'index pour p29 : Non vérifié visuellement. | — |
| T-B32 | `TutorialLevelUpScene` p30/p31 : p30 bulle long (VirtualWidth×0,5, 400), main (LimitedLeftEdge+150, 640) ; p31 bulle neuve (LeftEdge+500, 580), mains (RightEdge-395, 950) et (RightEdge-550, 780) ; boss et bouton LEVEL UP attachés (TutorialLevelUpScene.cs:25-88) | Scène | Oui | TutorialOverlay.gd:758-771 | Partiel | Positions et bulles conformes au C#. Écart sur le trou : Godot éclaire le rectangle entier de la plateforme du boss (300×210, BoardUI.gd:379-392) alors que l'APK n'attache que l'entité boss. Pour p26, Godot copie seulement le sprite du boss (l.725 : `sprites = [… "sprite"]`), il est donc incohérent entre les deux scènes. Aucune capture du tutoriel pour p30/p31 : `levelup_*` est une partie normale. | Basse |
| T-B33 | Comportement des entités attachées interactives pendant la scène : LEVEL UP (p31), pièces de la main, héros (cs:179-193 ; TouchGestures désactivé seulement pour DONE et la main) | TouchGestures | Non vérifié | TutorialOverlay.gd:779-780 (voile STOP partout) | Non vérifié | Godot avance au clic n'importe où. Dans l'APK, un tap sur LEVEL UP/boss pendant p31 atteint peut-être l'entité plutôt que le fond (priorité de collider de Wave non lue). | Basse |
| T-B34 | Sons dans les scènes tutoriel | — | N/A | — | Oui | `grep -rn -i "sound\|audio\|sfx" DBMGameProject.Scenes.Tutorial*` → 0 résultat. Godot : `grep -n -i "audio\|sfx\|play_" TutorialOverlay.gd` → 0 résultat. Le seul son lié est `ui_card_slide_general` à la pose des cartes de défausse (AddCarouselCardsBehavior.cs:105), hors de ce lot. | — |
| T-B35 | `CarouselSelectorShowComponent.tutorialBalloon` : BubbleMedium « tutorialMessagesBalloon » à (0,430), invisible (cs:36-37, 57) | Bulle | N/A | — | — | Code inerte : `grep -n tutorialBalloon` → déclaré, créé, `IsVisible=false`, ajouté comme enfant, jamais affiché. | — |

### Non vérifié

- Déroulé réel non exécuté : quelles étapes se déclenchent avec la graine 2832 et les décisions de l'IA (T-A07, T-A31). Risque : les scènes p25/p26/p28/p29 peuvent être sautées sans bruit.
- T-A33 : `CardExtractBehavior.cs:216` non relu (déclenche-t-il `InvalidCardPlayed` ?).
- Activation de salles autres que BMA027 pendant p23/p24 : le gate `move` ne filtre pas `activateRoom`.
- Pause automatique à l'ouverture d'un modal (`ScreenContextManager_OnDesactivatingScene`, cs:121-134) : équivalent Godot non cherché.
- T-B33 : priorité de hit-test de Wave entre le voile plein écran et les entités attachées (LEVEL UP, boss).
- T-B24, T-B28 (p25), T-B31, T-B32 : aucune capture APK de ces scènes ; coordonnées tirées du C# seulement.
- Rendu Godot non capturé : les verdicts « Oui » viennent du code rapproché des captures APK, pas d'une comparaison image contre image.
- Particules dorées autour du héros (`tut_75..82`) non lues.

### Synthèse du module 8

- **Éléments audités** : 71 (8A : 36, 8B : 35).
- **Conformes ou sans objet** : 58 (dont 4 N/A : code mort ou inerte côté APK).
- **Écarts** : 13 — Critique 0, Haute 0, Moyenne 3, Basse 10.
  - Moyenne : T-A07 (tirage de la graine 2832 non reproductible, `GameManager.gd:26`), T-A31 (étapes p25/p26/p28/p29 sautées si leur condition ne se produit pas), T-B18 (bulle d'indice fermée au bout de 6 s et sur n'importe quel clic, sans fondu).
  - Basse : T-A04, T-A22, T-A26, T-A28, T-A29, T-A33, T-B12, T-B26, T-B32, T-B33.
- **Non vérifié** : 1 ligne (T-B33) et les points ci-dessus.
- **Bloquants web** : aucun. Le tutoriel n'a ni son propre ni dépendance native ; le drapeau de premier lancement passe par `Profile.gd` (stockage web déjà couvert au module 1).

---

## Module 9 — En ligne

Périmètre : `DBMGameProject.Services.Online/` (8 fichiers), `DBMGameModel.Logic.OnlineModels/` (12), `Storage/OnlineKeys.cs`, `Scenes.GamePlay/GamePlayMOScene.cs`, parties en ligne de `GamePlayBaseScene.cs`, `Scenes.MainMenu.Online*/` (comportement ; la disposition est au module 4C). Côté Godot : `scripts/OnlineClient.gd`, `NetCodec.gd`, `OnlineGameManager.gd`, `OnlineMenus.gd`, `CountDown.gd`, `InGameMenu.gd`, serveur `server/Server.gd`, `GameRoom.gd`, `ViewFilter.gd`, `PROTOCOL.md`, et `deploy/nginx.conf`. Tous les chemins Godot sont sous `src/frontend/godot/`.

Architecture : l'APK fait jouer les clients en pair à pair via Photon (le maître de salle tient la partie, les autres comparent un hash de plateau). Le port a un serveur WebSocket autoritaire qui fait tourner `Match.gd` et envoie à chaque client une vue filtrée. On juge donc l'équivalence fonctionnelle vue du joueur. Décisions du propriétaire : salons seulement (pas d'appariement WORLDWIDE ni de compte à rebours de salle publique), boutique supprimée (pas de backer), un joueur qui part laisse son siège à l'IA.

Méthode : deux lots en lecture seule (9A protocole et service, 9B session de jeu et salles d'attente), puis contre-vérification à la main des quatre lignes Haute (N-B08, N-B11, N-B15, N-B16) dans `GameRoom.gd:205-227, 310-335`, `Server.gd:308-358`, `OnlineClient.gd:231-244, 386-391` et `Main.gd:546, 566-576`.

### 9A — Protocole, service et serveur

| ID | Élément source (décompilé) | Type (classe/méthode/asset/scène) | Présent dans Godot ? | Fichier Godot | Équivalent fonctionnel ? | Écart / Commentaire | Priorité |
|---|---|---|---|---|---|---|---|
| N-A01 | `OnlineClient : LoadBalancingClient` (S/OnlineClient.cs:19) | classe | Oui (autre archi) | OC:1 | Oui | Client WebSocket JSON sur serveur autoritaire, à la place de Photon LoadBalancing. Photon (appId, `app-eu.exitgamescloud.com:5055`, S/OnlineClient.cs:21,135) est remplacé par `server_url()` (OC:74-93) : `ws(s)://<hôte de la page>/ws` en web. | — |
| N-A02 | `OnlineClient()` ctor : nom aléatoire `RndWord(24)`, boucle `Service()` toutes les 66 ms (S/OnlineClient.cs:131-168) | méthode | Oui | OC:97 `_process` | Oui | Pompe réseau par `_process` + `WebSocketPeer.poll()` (OC:104). Pas de thread (contrainte web respectée). Le nom vient du profil joueur, pas d'un aléa. | — |
| N-A03 | `OnlineClient.IsSuspended` + `MaxSuspendedTime` 30 s → `Disconnect()` (S/OnlineClient.cs:43-45,149-160) | propriété | Non, et c'est volontaire | OC:29-33,122-134 | Équivalent supérieur | L'APK coupe après 30 s de pause appli. Godot garde la session : ping immédiat si `delta > SLEEP_GAP_S`, liaison rouverte avec `resume` si elle est morte, et le serveur tolère 120 s de silence (SV:32). | — |
| N-A04 | `OnlineClient.OnConnect` (StatusCode.Connect, S/OnlineClient.cs:238) | événement | Oui | OC:106-114 | Oui | Ouverture détectée à `STATE_OPEN`. Signal interne `_reply("open")`. | — |
| N-A05 | `OnDisconnect` (Disconnect, TimeoutDisconnect, DisconnectByServer, …UserLimit, …Logic, S/OnlineClient.cs:245-255) | événement | Oui | OC:135-149 | Partiel | `STATE_CLOSED` déclenche une reconnexion avec backoff 1 à 8 s (OC:151-153) et un `resume`. Message "connexion perdue, reconnexion..." émis par `request_error`, mais seul l'écran d'attente l'écoute (OM:766). En partie, rien n'est affiché au joueur (voir N-A41). Seul le motif d'éviction (1000) est distingué ; pas de distinction timeout, limite d'utilisateurs ou logique serveur. | Moyenne |
| N-A06 | `OnException` (ExceptionOnConnect, Exception, ExceptionOnReceive, S/OnlineClient.cs:256-264) | événement | Oui | OC:155-162,194-198 | Oui | Échec de `connect_to_url` : retry. Timeout de requête 8 s (OC:27,190) avec message "connexion impossible" ou "le serveur ne répond pas". | — |
| N-A07 | `SendInternalEvent` : index d'ordre mod 100, JSON dans Hashtable, `ReceiverGroup.Others` (S/OnlineClient.cs:175-206) | méthode | Non, par design | OC:164 `_send`, OC:386 `send_move` | Oui | Plus de diffusion pair à pair : le client envoie seulement `{t:"move",move}`. L'ordre est garanti par TCP/WebSocket, donc l'index d'ordre n'a plus d'objet. `PhotonClientOwnerId` est remplacé par `seat_of(conn)` côté serveur (SV:392) : pas d'usurpation de siège possible. | — |
| N-A08 | `OnlineClient.NextEventOrderIndex`, `PendingOrderedReceivedEvents`, `PendingUnorderedReceivedEvents`, `MAX_EVENT_ORDER_INDEX` (S/OnlineClient.cs:25-35,218-231) | champ/file | Non (vérifié absent : `grep -rn "order_index\|PendingOrdered" scripts server` = 0) | — | Oui (sans objet) | Réordonnancement par joueur (Photon n'ordonne pas entre émetteurs) inutile : un seul flux serveur ordonné, état complet renvoyé après chaque coup. | — |
| N-A09 | `GetPlayerUsername` (S/OnlineClient.cs:208) | méthode | Oui | GR:341-346 (`name` du siège), SV:241 `_clean_name` | Oui | Nom nettoyé côté serveur (contrôle, bidi, 25 car.), défaut "Joueur". | — |
| N-A10 | `OnlineClient.OnOperationResponse` (S/OnlineClient.cs:268) | méthode | N/A | — | Oui | Simple appel à la base, sans effet propre. | — |
| N-A11 | `OnlineService : UpdatableService`, `Initialize` / `Terminate` / `Update` (S/OnlineService.cs:536,544,549) | classe | Oui | OC (Node), SV | Oui | Le client est un `Node` ; l'`Update` n'a plus à dépiler d'événements, les messages sont traités à la réception (OC:116-121). | — |
| N-A12 | `Update` : reconnexion automatique toutes les 4 s si Offline et `maintainConnected` (S/OnlineService.cs:555-565) | méthode | Oui | OC:97-103,151-153 | Oui+ | Backoff 1 à 8 s et reprise du même siège via `resume` (OC:110-111). L'APK ne revient qu'au lobby, il ne rentre jamais dans sa salle. | — |
| N-A13 | `OnlineService.Connect` / `Disconnect` (S/OnlineService.cs:605,611) | méthode | Oui | OC:343 `watch_rooms`, OC:352 `unwatch_rooms`, OC:170 `_ensure_open` | Oui | Liaison ouverte à la demande, fermée au départ du lobby public si aucune salle. | — |
| N-A14 | `OnlineService.CurrentPlayer` (`OnlinePlayerInfo`) / `CurrentRoom` (`OnlineRoomInfo`) (S/OnlineService.cs:60-61, init à 536-542) | propriété | Oui | OC:36-58 (`match_id`, `player_id`, `current_seats`, `current_title`, `current_status`…) | Oui | Les mêmes informations viennent du message `lobby`. | — |
| N-A15 | `ConnectionState` / `GetConnectionState` (S/OnlineService.cs:67,1068-1106) | méthode | Partiel | OC:56 `connected`, OC:49 `current_status`, `_want_open` | Partiel | Pas d'enum explicite : états déduits de `connected`, `match_id`, `current_status`. Équivalent à l'usage des écrans (lobby, salle, partie). | Basse |
| N-A16 | `ConnectionStates.Offline` (S/ConnectionStates.cs:5) | enum | Oui | OC:56 `connected == false` | Oui | — | — |
| N-A17 | `ConnectionStates.Connecting` | enum | Partiel | OC:155-162, OM:347 (`o.connected`) | Partiel | Pas d'indicateur "connexion en cours" dédié. L'attente se lit via `connected` et les messages d'erreur. | Basse |
| N-A18 | `ConnectionStates.InLobby` | enum | Oui | OC:343 `watch_rooms`, SV:334 `listRooms` | Oui | Lobby public = liaison ouverte sans salle, avec push `rooms`. | — |
| N-A19 | `ConnectionStates.InRoom` (Joined et salle ouverte) | enum | Oui | OC:225 `lobby`, GR:21 `status == "open"` | Oui | — | — |
| N-A20 | `ConnectionStates.InGame` (Joined et `IsOpen == false`) | enum | Oui | GR:21 `status == "running"`, OC:272 | Oui | `CloseRoom` (`IsOpen=false`) est remplacé par le statut `running`, qui refuse les jonctions. | — |
| N-A21 | `ConnectionStates.Unknown` | enum | Non (vérifié absent : pas de cas "inconnu") | — | Oui (sans objet) | — | — |
| N-A22 | `CreateJoinRoomResults.Success` (S/CreateJoinRoomResults.cs:12) | enum | Oui | OC:332-339 (`joined`) | Oui | — | — |
| N-A23 | `CreateJoinRoomResults.NotFound` | enum | Oui | SV:355-356 (`not_found`), OM:458-460 ("This game is no longer open"), OM:679-681 ("Invalid Code") | Oui | Anti-force-brute en plus : 5 échecs par connexion = fermeture 1008 (SV:289-290), soupape globale 100/s (SV:26). | — |
| N-A24 | `CreateJoinRoomResults.RoomIsFull` | enum | Oui | SV:357-358 (`full`), OM:460,681 ("Room is full") | Oui | `full` regroupe pleine et déjà lancée, ce qui correspond à `IsOpen=false`. | — |
| N-A25 | `CreateJoinRoomResults.ExpansionsNotMatch` | enum | Non (vérifié absent : `grep -n "ExpansionsNotMatch\|expansions_not" OC SV OM` = 0) | — | Oui (sans objet) | Les extensions sont fixées par l'hôte pour toute la salle (SV:313-316) ; le client n'a plus de déblocage par achat. Store retiré : N/A. | Basse |
| N-A26 | `CreateJoinRoomResults.FailToCreatePublic` / `FailToCreatePrivate` | enum | Oui | OM:660-663 ("Unable to create public/private room"), `bad_setup` en plus (SV:320) | Oui | Message distinct si `bad_setup` (5-6 joueurs sans Crash Landing). Le serveur renvoie `full` si 200 salles (SV:311-312), et l'UI affiche alors le message générique de création. | — |
| N-A27 | `CreateJoinRoomResults.FailToJoinPublic` / `FailToJoinPrivate` | enum | Oui | OM:457,677 ("Unable to join …") | Oui | Défaut pour toute erreur autre que `not_found` / `full`. | — |
| N-A28 | `OnlineService.CreatePrivateRoom` (S/OnlineService.cs:646) et `CreateNewRoom` (957) | méthode | Oui | SV:308-333 `create`, `_new_code` SV:292 | Oui | Code de 4 lettres sans I ni O, comme `RndWord(4)`, avec nouveau tirage si collision (SV:297). Hôte au siège 0 ; l'APK tente jusqu'à 10 fois. | — |
| N-A29 | `OnlineService.JoinPrivateRoom` (S/OnlineService.cs:661) et `JoinRoomByName` (927) | méthode | Oui | SV:349-359 `join`, OC:321 `join_lobby` | Oui | Code insensible à la casse et aux espaces (SV:354). | — |
| N-A30 | `OnlineService.JoinPublicRoom` (631) : jointure aléatoire ou création | méthode | Remplacé volontairement | SV:334-337 `listRooms`, OC:343, OM:450 | Oui (par design) | Lobbies publics listés : le joueur choisit dans `rooms`. L'auto-appariement n'est pas porté (décision utilisateur). | Basse |
| N-A31 | `OnlineService.JoinRandomRoom` (913) / `JoinAnyExistingPublicRoom` (617, WORLDWIDE) | méthode | Non, par design | — | Non, par design | Appariement automatique mondial volontairement non porté. | Basse |
| N-A32 | `OnlineService.CreateOrJoinTestRoom` ("TestRoomFor"+n, S/OnlineService.cs:651) | méthode | Non (vérifié absent : `grep -rn "TestRoomFor" src` = 0) | — | Sans objet (outil de debug APK) | — | — |
| N-A33 | `OnlineService.LeaveRoom` / `CloseRoom` (668, 678) | méthode | Oui | OC:373 `leave_match`, SV:401-412 `leave`, `_close_room` SV:186 | Oui (sémantique différente) | Hôte qui quitte la salle d'attente : `closed` envoyé aux autres (SV:405-407). Un joueur qui quitte en partie : l'IA garde le siège définitivement (GR:161) ; l'APK tue le joueur (`KillManually`, S/OnlineFlowManager.cs:307-318). Salle fermée quand plus aucun humain actif (SV:411-412). | Basse |
| N-A34 | `OnlineService.GetNewRoomName` (898) | méthode | Oui | SV:292 `_new_code` | Oui | Aléa cryptographique (`Crypto`), ce qui est mieux que `RndWord`. | — |
| N-A35 | `OnlineService.CreateRoomOptions` (986) : `MaxPlayers` 4, `IsVisible`, `CheckUserOnJoin`, props lobby | méthode | Oui | SV:317, GR:35, GR:142-147 `list_entry` | Oui+ | 2 à 6 joueurs (Crash Landing). Props visibles dans la liste : `code`, `title`, `host`, `numPlayers`, `free`, `sets`, `status`. | — |
| N-A36 | `OnlineService.SavePlayerProperties` (1005) : Wins, Defeats, Avatar, IsBacker, UserName | méthode | Oui | OC:325 `_profile_fields`, SV:265 `_clean_profile` | Oui | Avatar, victoires, défaites et nom sont validés côté serveur (liste blanche `a-z_`, clamp 0 à 99999). Cosmétique, donc falsifiable : l'APK l'est aussi. | — |
| N-A37 | `OnlineService.CheckCustomProperties` (1017) | méthode | Non (vérifié absent) | — | Oui (sans objet) | Contrôle `IsOpen` / `IsVisible` / pleine remplacé par `status == "open"` et `free_seat()` (SV:357). | — |
| N-A38 | `OnlineService.GetPlayersInRoom` (754) | méthode | Oui | GR:341-346 `lobby_msg` | Oui | Tableau `seats` ordonné par siège, avec `connected`. | — |
| N-A39 | `HandlePhotonEvents` cas 255 (Join) : réinit. de `playersSequenceIndex`, `OnRoomUpdate` (S/OnlineService.cs:770-801) | méthode | Oui | SV:423-426 `_join`, GR `broadcast` GR:363 | Oui | Chaque jonction rediffuse le `lobby` à tous les sièges. | — |
| N-A40 | `HandlePhotonEvents` cas 254 (Leave) : `OnPlayerLeave` + `OnRoomUpdate` (803-830) | méthode | Partiel | OC:225, GR:156-162, GR:329-333 | Partiel | En salle d'attente : `lobby` rediffusé. **En partie, l'adversaire qui part n'a aucun signal visible** : `lobby.seats[].connected` arrive dans chaque `state` mais n'est lu par aucun écran de jeu (`grep -n "current_seats\|connected" scripts/BoardUI.gd` = 0). Le journal ne signale que le délai dépassé, pas un départ explicite (`GameRoom.leave`, GR:161, n'écrit rien). | Moyenne |
| N-A41 | `OnlineFlowManager.OnPlayerLeaveGame` / `OnErrorOccurred` (S/OnlineFlowManager.cs:68-175) | événement | Non (vérifié absent) | — | Non | Aucun écran de partie n'écoute `request_error` (`grep -rn request_error scripts` : seul OM:766-797). Conséquences en partie : coupure silencieuse ; serveur redémarré (état en mémoire perdu) → `resume` rend `not_found`, `_forget()` (OC:236) vide `match_id`, `send_move` ignore tout (OC:387) : **plateau figé sans message** (hors partie perdue de toute façon). Le serveur n'envoie `closed` qu'aux sièges connectés (SV:191-193) : en partie ce message est rarement reçu, et le client ne l'affiche qu'hors partie (aucun écouteur de `closed_room` : `grep -rn closed_room scripts` = OC seul). | Moyenne |
| N-A42 | `OnlinePlayerInfo` : Id, IsMasterClient, UserName, Avatar, Wins, Defeats, IsBacker (S/OnlinePlayerInfo.cs) | classe | Oui, sauf Id/IsMasterClient/IsBacker | GR:344-345, OM:31,863 (`_rows`), OC:50 `current_host` | Oui | Nom, avatar, victoires, défaites par siège ; l'hôte est un indice `host` (équivalent de IsMasterClient pour le démarrage). `IsBacker` : store retiré, N/A. | Basse |
| N-A43 | `OnlineRoomInfo` : Name, IsPublic, Players, NumberOfPlayers, Expansions (S/OnlineRoomInfo.cs) | classe | Oui | GR:346 (`code`, `numPlayers`, `sets`, `title`), `public` en liste (SV:205) | Oui | `IsPublic` = salle présente dans `rooms`. Pas de champ `isPublic` explicite dans `lobby`. | Basse |
| N-A44 | `OnlineKeys.WINS` / `DEFEATS` / `AVATAR` / `USERNAME` (Storage/OnlineKeys.cs:7-13) | clé | Oui | OC:326 (`avatar`,`wins`,`defeats`), `name` | Oui | — | — |
| N-A45 | `OnlineKeys.ISBACKER` | clé | Non (vérifié absent : `grep -rn -i backer server scripts/OnlineClient.gd` = 0) | — | N/A | Store retiré, pas de backer. | Basse |
| N-A46 | `OnlineKeys.APPID` / `SERVERADDRES` / `APPVERSION` | clé | Remplacé | OC:21 `DEFAULT_URL`, OC:74 `server_url` | Partiel | **Pas de version de protocole** (`grep -rn -i "version" server/Server.gd scripts/OnlineClient.gd` = 0). L'APK isole les versions via `AppVersion` Photon. Un onglet web resté ouvert avec ancien client + nouveau serveur n'est pas détecté (champs inconnus ignorés, `bad_message` éventuel). | Basse |
| N-A47 | `OnlineKeys.ISPRIVATE` | clé | Oui | SV:323-324, GR:18 `public` | Oui | Booléen JSON strict (le texte "true" ne rend pas la salle publique). | — |
| N-A48 | `OnlineKeys.EXPANSIONS` | clé | Oui | SV:313-316,GR:15,GR:147 | Oui | Liste blanche `KNOWN_SETS` ; hôte seul décide. | — |
| N-A49 | `DBMEventCode.Unknown` (0) | enum | Non (sans objet) | SV:413-414 (`bad_message`) | Oui | Type inconnu rejeté. | — |
| N-A50 | `DBMEventCode.BeginCountDown` (1) + `BeginCountDownModel.RemainingTime` (M/BeginCountDownModel.cs) | événement/modèle | Non, par design | SV:380-385 (`start`), SV:424-425 (démarrage à salle pleine) | Partiel (par design) | L'APK diffuse un compte à rebours (pour les salles publiques). Godot : l'hôte appuie sur Start (ou démarrage immédiat à salle pleine, aucun compte à rebours). Timers d'auto-démarrage volontairement non portés. | Basse |
| N-A51 | `DBMEventCode.GameInitialization` (2) + `GameInitializationModel` (SelectedPlayers, RandomSeed, Expansions, M/GameInitializationModel.cs) | événement/modèle | Oui, remplacé | GR:173-193 `start`, GR:184-188 | Oui | Le serveur crée le `Match` (`m.rng.randomize()`), assigne `isAI` par siège ; chaque client reçoit sa vue. Le seed partagé n'existe plus (inutile avec un serveur autoritaire). | — |
| N-A52 | `DBMEventCode.BuildRoom` (3) + `BuildRoomModel` (RoomID, SlotIndex) ; `SendBuildRoom`, `SendUndoBuildRoom` (S/OnlineFlowManager.cs:451,458) | événement | Oui | OGM:115-135, `buildRoom` / `undoBuild` (PM, GR:205) | Oui | Les indices sont ceux de la main côté serveur, et les coups doivent être exactement un de `legal_moves` (GR:210-213). Le undo a une file `_queued_build` (OGM:60,74-79) qui attend l'état suivant. | — |
| N-A53 | `DBMEventCode.PlayCardAbility` (4) + `PlayCardAbilityModel` (PlayedCardID) | événement | Oui | GR:205 `submit_move`, OGM:96 `apply_move` | Oui | Coups de capacité/sort proposés dans `moves` (Match.legal_moves). | — |
| N-A54 | `DBMEventCode.SetSpellBattleReady` (5), `SendSpellBattleReady` (S/OnlineFlowManager.cs:495) | événement | Oui | GR:237 (`pass`), VF:379 (`stackPassed`) | Oui | Fenêtre de sorts : chaque humain passe ; `awaited` indique qui est attendu (GR:295-309). Le détail du `stackPassed` dans Match n'est pas relu ici. | — |
| N-A55 | `DBMEventCode.SetDiscardCards` (6) + `DiscardCardsModel` (DiscardedCardsIDs) | événement | Oui | Match.gd:207 `openingDiscard`, GR:205 | Oui | Défausse d'ouverture : coups `openingDiscard [i,j]` du `legal_moves`. | — |
| N-A56 | `DBMEventCode.ChooseDeckToDraw` (7) + `ChooseDeckToDrawModel.SelectedDeck` | événement | Oui (par coup) | GR:205 | Oui (sous réserve) | Je n'ai pas localisé le coup nominal dans `Match.gd` ; la pioche passe par `legal_moves`. Voir "Non vérifié". | Basse |
| N-A57 | `DBMEventCode.ResolveTarget` (8) + `ResolvedTargetModel` (AbilityOwnerID, TargetID, SelectedCards) + `UnresolvedTargetData` | événement/modèle | Oui | GR:262-270 (`pendingChoice`), VF:440-445 | Oui+ | Choix en attente : options visibles du seul propriétaire (le reste devient `{"hidden":true}`, VF:444). `choiceQueue` réduite à `type` + `playerId` (VF:445). | — |
| N-A58 | `DBMEventCode.FinishUserInteraction` (20) ; `pendingFinishUserInteractions`, `IsAwaitingOtherPlayersInteractionTurns` (S/OnlineFlowManager.cs:56,320-327,364) | événement | Oui | GR:197-228, `passBuild` (Match.gd:252-254,337) | Oui | "Fin du tour de construction" = `passBuild`. Le blocage (attente de pair) devient `awaited` + délai (GR:295-316). | — |
| N-A59 | `DBMEventCode.SkipHaltTimer` (21) ; `pendingSkipHalt`, `SendSkipHalt` (S/OnlineFlowManager.cs:331-338,397) | événement | Oui | GR:258-260 `_in_adventure_pause`, GR:316, PM (pause d'aventure 10 s) | Oui | Pause d'aventure : chaque humain peut passer, sinon l'IA passe à l'échéance (10 s). | — |
| N-A60 | `DBMEventCode.SlowDown` (22) + `SlowDownModel.IsSlowDawnActive` ; `SendSlowDownModel` (S/OnlineFlowManager.cs:419) | événement | Non (vérifié absent : `grep -rn -i "slowdown\|slow_down" scripts server` = 0) | — | Oui (sans objet) | Signal d'animation entre pairs ; serveur autoritaire, plus de synchronisation d'animation à faire. | Basse |
| N-A61 | `DBMEventCode.DebugDrawCard` (30) / `DebugPutHeroInTown` (31) + `DebugTBModel`, `OnlineService_OnDebugDrawCard` / `…PutHeroInTown` (S/OnlineFlowManager.cs:342,354) | événement/modèle | Non (vérifié absent : `grep -n -i "debugDraw\|cheat" scripts/Match.gd server/*.gd` = 0) | — | Oui (sans objet) | Triche de debug de l'APK : aucun client ne peut l'invoquer, tout coup doit être dans `legal_moves` (GR:210). Meilleur du point de vue sécurité. | — |
| N-A62 | `MessageBaseModel` (PhotonClientOwnerId, GameboardHash, ByBoss, M/MessageBaseModel.cs) | modèle | Remplacé | SV:392 (`seat_of(id)` dérive le siège), SV:389-391 | Oui+ | Le client ne fournit plus `ByBoss` : le siège vient de la connexion. Une trame `move` ne peut pas se faire passer pour un autre siège. | — |
| N-A63 | `GameboardHash` + `OnlineFlowManager.CheckGameboardHash` + `OnGameboardRefresh` / `OnErrorOccurred` (S/OnlineFlowManager.cs:260-273) | méthode | Remplacé | SV:394-395 (resynchro `message_for`) | Oui+ | Détection de désynchronisation inutile : l'état complet filtré est renvoyé après chaque coup, et un coup illégal est suivi d'un `state` de resynchro. Message `sync` disponible (SV:398-400). | — |
| N-A64 | `OnlineFlowManager.IsAwaitingMessages`, `CreateWaitNextStepTask`, `IsAwaitingSyncMessage` (S/OnlineFlowManager.cs:44,223,255) | méthode | Remplacé | GR:295-316 | Oui | L'attente de messages des pairs devient `awaited` + `deadline` + `serverTime` (OC:264-270). Affichage via `CountDown` (`scripts/CountDown.gd:33-36`). | — |
| N-A65 | `OnlineFlowManager.ClearPendingReveivedEvents`, `receivedSkipHalt`, `receivedFinishUserInteractions` (334-358 approx.) | méthode | Non (sans objet) | — | Oui | Plus de dédoublonnage entre pairs. | — |
| N-A66 | `OnlineFlowManager.OnlineService_OnPlayerLeave` : `KillManually`, retrait des attentes (S/OnlineFlowManager.cs:307-318) | méthode | Remplacé | GR:156-162, GR:329-333 | Oui (sémantique différente) | Plus aucune attente bloquante pour un joueur parti : sa décision tombe à l'échéance (`turnTimeout`, défaut 60 s) puis l'IA joue (GR:329-333). **Un joueur qui part laisse jusqu'à 60 s d'attente** (APK : immédiat), puis la partie continue avec l'IA, au lieu d'éliminer le joueur. | Basse |
| N-A67 | Reprise de partie après coupure : absente de l'APK (Photon sans rejoin) | comportement | Oui (ajout) | OC:439 `try_resume`, SV:360-379, GR:94-107 | Oui+ | Jeton de siège 16 octets (GR:167), session dans `sessionStorage` (un onglet = un siège, OC:404-417), éviction de l'ancien onglet (SV:372-374, `evicted`). | — |
| N-A68 | Perte d'info cachée : mains, pioches, salles face cachée adverses | sécurité | Oui | VF:411-449, VF:453-475 | Oui | Liste blanche des clés de `G` et de joueur (VF:377,389), mains/pioches remplacées par `{"hidden":true}` à taille conservée, minibosses et objets face cachés masqués, journal privé réduit à la ligne publique pour les non-propriétaires (VF:479-486). Test automatisé dans `tests/online_test.gd:82-110,185-188`. | — |
| N-A69 | Contenu de `stack` et de `bossPicks` en phase boss visibles de tous | sécurité | Partiel (non prouvé) | VF:379 (`stack` public), VF:439 | Non vérifié | `stack` est une clé publique ; si un sort posé face cachée y figure, il serait visible. `bossPicks` est entièrement visible pendant la phase `boss` : comparaison avec l'APK non faite. | Basse |
| N-A70 | Transport `Photon` UDP/TCP natif (Android) | dépendance | Remplacé | OC:60 `WebSocketPeer` | Oui | Aucune dépendance Android native côté Godot. | — |
| N-A71 | Fermeture d'onglet / mise en arrière-plan (contrainte web) | web | Partiel | OC:122 (rattrapage de veille), SV:149-150 `_drop`, SV:170-183 | Oui | Aucun `beforeunload` / `pagehide` n'envoie `leave` (`grep -rn -i "beforeunload\|pagehide\|visibilitychange" scripts server` = 0). Fermer l'onglet laisse le siège occupé : en salle d'attente libéré après 30 s (`seat-grace`), en partie l'IA reprend après le délai du tour. L'hôte d'une salle privée n'est jamais libéré (volontaire, GR:120). | Basse |
| N-A72 | Limites réseau : Origin, débit, connexions | infra | Oui (ajout) | NX:20-30 (map Origin), NX:60-75 (`/ws`, `limit_req`, `limit_conn`), SV:16-32, SV:135-147 | Oui+ | Origin refusée en 403 si ≠ hôte de la page ; 429 à 5 ouvertures/s par IP (rafale 20), 20 liaisons par IP ; 60 messages/s ; trame 16 Kio ; silence 120 s ; 512 connexions. Le port 8091 est en `expose` seulement (docker-compose.yml:39), donc non publié. Pas de contrôle d'Origin dans le serveur Godot lui-même (impossible : en-têtes non exposés, SV:21-24). | — |
| N-A73 | `proxy_read_timeout 3600s` et ping 20 s (NX:73, OC:28) | infra | Oui | NX:73-74, OC:123-127 | Oui | Liaison inactive ne coupe pas côté nginx. | — |
| N-A74 | Liste publique poussée (`rooms`) | fonction | Oui (ajout) | SV:202-224, OC:343 | Oui | Mise à jour regroupée toutes les 250 ms, 50 salles au plus, jamais de jeton ni de détail de siège. | — |
| N-A75 | Hôte (Photon master client) : migration de l'hôte | comportement | Remplacé | GR:121-133 | Oui | Salle publique : le rôle d'hôte passe au premier humain connecté après 30 s d'absence. Salle privée : l'hôte garde le rôle (volontaire). En partie, l'hôte n'a plus de rôle (serveur autoritaire). | — |

### 9B — Session de jeu en ligne et salles d'attente

| ID | Élément source (décompilé) | Type (classe/méthode/asset/scène) | Présent dans Godot ? | Fichier Godot | Équivalent fonctionnel ? | Écart / Commentaire | Priorité |
|---|---|---|---|---|---|---|---|
| N-B01 | OnlineDefeats++ et SaveToDisk dès le constructeur de la partie (GPMO:46-48) | méthode (ctor) | Non (vérifié absent) | OC:272-283, Profile.gd:62-73 | Différent | Godot ne compte qu'à `status == "finished"`. Aucune défaite n'est posée au début de partie. Voir N-B02 et N-B03. | Corrigé (Moyenne) |
| N-B02 | OnUserPlayerVictory : Defeats--, Wins++, SaveToDisk (GPMO:260-267) | méthode | Oui | OC:278-283 (`record_result`, une fois par salle) | Oui | Le résultat final est le même : victoire +1 ou défaite +1. Compté pour le siège local quand `gameOver.winner` est reçu. Un joueur éliminé en 3-4 joueurs ne voit le résultat qu'à la fin globale (voir N-B52). | — |
| N-B03 | Défaite conservée si on quitte ou ferme en cours de partie (anti-abandon) | comportement | Non | BUI:4344-4347 et Main.gd:546 (QUIT renvoie à `show_title` sans `leave`) ; OC:272-274 | Différent | **S-11 confirmé** : quitter ne compte aucune défaite sur le moment. Nuance : QUIT GAME n'envoie jamais `leave` et le WebSocket reste ouvert. Si la partie se termine socket ouvert, le résultat est compté (et c'est l'IA qui jouait pour le joueur). Onglet fermé : jamais de défaite. | Corrigé (Moyenne) |
| N-B04 | Dernier joueur restant : « No players to play with… » ou « You win by desertion », victoire seulement si NumberOfTurns > 2, Wins++, Defeats-- (GPMO:104-118) | méthode | Non (vérifié absent) | GR:156-162 ; SV:401-412 | Différent (voulu) | Pas de règle des 2 tours côté serveur. Le siège passe à l'IA, la partie continue et se termine normalement. La salle ne se ferme que si plus aucun humain n'est actif. Grep des textes dans `godot/` : 0 résultat. | Basse |
| N-B05 | « <nom> has left the game. » si NumberOfPlayers > 1 (GPMO:103-107) | modale | Non (vérifié absent) | — | Non | Aucun message de départ. Les autres joueurs ne savent pas qu'un siège est passé à l'IA, hormis une ligne de journal en cas de timeout (GR:332). | Basse |
| N-B06 | OnlineService_OnPlayerLeave puis KillManually (OFM:307-318 ; GameBoard.cs:855) | méthode | Oui (autre forme) | GR:156-162, 231-233 | Différent (voulu) | Le siège reste à l'IA (`left` et `auto`) au lieu d'être tué. Décision délibérée de l'utilisateur. | Basse |
| N-B07 | OnDisconnect : modale « Connection problem / The connection with the server was lost. » puis sortie (GPMO:92-95, 121-138) | modale | Non | OC:135-149 | Différent | Godot reconnecte seul avec `resume`, ce qui est mieux sur le web. Mais `request_error` n'a aucun écouteur en partie (grep : seulement OM:766-768, déconnecté au premier état OM:831). Pendant la coupure, les coups sont perdus sans message (OC:389-391). | Moyenne |
| N-B08 | Perte définitive de la session en jeu (même modale puis sortie) | comportement | Non | OC:234-236 (`_forget` sur bad_token ou not_found), 239-244 (`closed`) | Non | Redémarrage du serveur, salle expirée ou siège évincé : le client oublie la session sans rien afficher. Le plateau reste figé avec un compte à rebours périmé. Seul QUIT GAME en sort. L'APK affichait une modale et quittait. | **Haute** |
| N-B09 | OnlineFlowManager_OnErrorOccurred : « Unexpected problem » (hash de plateau invalide) (GPMO:87-90 ; OFM:260-273) | modale | N/A | — | N/A | Architecture serveur autoritaire : aucun hash à comparer. Un coup illégal renvoie `error illegal` puis un `state` de resynchronisation (SV:392-395). | — |
| N-B10 | Triche debug : OnDrawRoomOrSpellToHand, OnPutHeroInTown, interrupteurs DEBUG_ELEM (GPMO:275-285 ; Base:355-375 ; OFM:342-362) | méthodes | N/A | — | N/A | Outils de debug sans équivalent. Le serveur n'accepte que des coups de `legal_moves` (GR:205-218). | — |
| N-B11 | Sortie de partie : ShowMessageBox(exit) puis Dispose appelle `onlineService.Disconnect()` (GPMO:58-68, 121-138) | méthode | Non (vérifié absent) | BUI:4344-4347 ; Main.gd:546 ; grep `leave_match` : un seul appelant (OM:793, salle d'attente) | Non | Après une partie (finie ou quittée), le client ne quitte jamais la salle et la connexion reste ouverte. `create` et `join` reçoivent alors `busy`/« deja dans une salle » (SV:309-310, 350-351). Le joueur voit « Unable to create/join private room ». Il faut recharger la page. Pour une salle finie, ça dure jusqu'à la fermeture à `finished_ttl` de 600 s (SV:176-177, 186-197). Déduit du code, non exécuté. | **Haute** |
| N-B12 | Bulle « IS PLAYING! » : IsPlayingOnlineBubbleSceneBehavior, RemotePlayerInteraction.IsPlaying, BubblesFactory.CreateIsPlayingBubble (texte `   IS\nPLAYING!`), BubblesPlayerEmitter.IsPlayingBubbleActive | comportement et bulle | Non (vérifié absent) | — (grep `IS.?PLAYING\|isPlaying` dans `godot/` : 0) | Non | **P-A48/P-B13 confirmé absent.** L'APK l'affiche pour chaque adversaire en attente de message : décision en cours, SkipHalt ou FinishUserInteraction attendu, ou zoom (SlowDown). Godot a `awaited` (OC:270) mais ne s'en sert que pour son propre compte à rebours (CD:120). On ne voit pas qui retient la partie. | Moyenne |
| N-B13 | SendSlowDownModel / OnSlowDown, qui alimente IsPlaying (GPMO:287-291 ; OFM:419-427) | message | Non (vérifié absent) | — (grep `slow_down\|SlowDown` : 0 hors commentaires BUI:936) | Non | Sans bulle IS PLAYING, le message n'a plus d'usage visible. | Basse |
| N-B14 | Barre jaune de 70 s dans le bouton DONE (Base:272 ; DoneButtonEntity.cs:98,145-148). Fin de délai : StopAndHide, FinishUserInteraction (Base:1030-1042) | entité et minuterie | Oui (autre forme) | GR:23, 311-316 ; CD:114-137 ; Main.gd:572-576 | Différent | **P-A30/P-B33 réglé.** Godot : 60 s (`--turn-timeout=60`, deploy/Dockerfile.server:33) et chiffre doré en haut à droite (1150,12), au lieu de 70 s et d'une barre jaune dans DONE. Le décompte ne s'affiche que pour MON siège attendu. | Basse |
| N-B15 | Conséquence du délai : l'APK passe seulement son propre tour de construction (auto-DONE). Aucun délai sur les autres décisions | comportement | Oui (différent) | GR:329-334 (`auto = true`), 231-233, 263-292 ; PROTOCOL.md:292-294 | Non | Au timeout (60 s, ou 10 s pour une pause d'aventure, GR:316), l'IA joue à la place du joueur pour toutes ses décisions suivantes, et immédiatement. Seul un coup du joueur remet `auto` à faux (GR:215). Quelques secondes d'hésitation pendant une pause d'aventure peuvent donc coûter le tour de construction suivant, joué par l'IA. À valider avec le propriétaire. | **Haute** |
| N-B16 | Remise à zéro du délai : l'APK ne remet la barre à zéro que quand une capacité se résout en BuildPhase_b (Base:621-624) et la met en pause pendant un combat de sorts (Base:655-657) | comportement | Oui (différent) | GR:220-227 (`_after_move` puis `_reset_deadline`), 104-105 (`resume` remet un délai complet) ; Match.gd:416-425 | Non | Tout coup valide remet le délai à 60 s. Alterner `buildRoom` et `undoBuild` (toujours légal avant DONE) bloque la partie indéfiniment. Un `resume` d'un autre siège repousse aussi l'échéance d'un joueur absent. Un joueur peut bloquer les autres pour toujours. | **Haute** |
| N-B17 | GamePlayBaseScene.TimeOut = 60 s (Base:131-140) | propriété | N/A | — | N/A | Jamais lue (grep -w `TimeOut` : seule la définition, hors WRB). Pas de « 60 s » dans GamePlayMOScene (P-A55) : les 60 s d'`activateTimeOuts` sont du code mort. | — |
| N-B18 | Fenêtres d'aventure et de pile en ligne : barre de 3 s par pas du héros (Base:215, 944), SkipHalt automatique (OFM:227-231, 397-408) | comportement | Oui (différent) | BUI:922-927 (`_apk_flow` faux en ligne), 1020-1030 ; GR:258-260 | Différent | En ligne, Godot demande un GO ou PASS TURN manuel à chaque pas quand le joueur a une décision. L'APK avance seul après 3 s. La pause d'aventure serveur est de 10 s (N-B15 pour la suite). | Moyenne |
| N-B19 | Pause en ligne : le jeu ne se fige pas (PauseScene.PauseBaseScene = !activateTimeOuts, Base:1095-1096) | comportement | Oui | BUI:874 (`_modal_open() and not _is_online()`) | Oui | Le serveur continue d'écouler le délai pendant le menu. | — |
| N-B20 | CARD GALLERY masquée en ligne (`new PauseScene(!activateTimeOuts)`, Base:1095 ; PauseScene.cs:28-31,61) | bouton | Oui (à tort) | InGameMenu.gd:180, 243-252 | Non | **P-A15 confirmé** : la galerie est toujours proposée en ligne (InGameMenu n'a aucun indicateur en ligne). RULES est aussi proposé, c'est un ajout. | Basse |
| N-B21 | Vitesse de jeu forcée à 0,5 en ligne (GameSettings) | comportement | Oui | BUI:944-946 | Oui | Alias verbal : déjà audité ailleurs. | — |
| N-B22 | Choix du boss avec minuterie en ligne : useTimeoutInBossSelection, pas de bouton PLAY, fermeture après 2 s (Base:98 ; RandomBossSelectionScene.cs:81,137) | comportement | Oui | BUI:1204, 1907-1925 (`BOSS_AUTO_TIME`) | Oui | Le bouton n'apparaît que s'il y a un seul humain. Durée exacte de `BOSS_AUTO_TIME` non confrontée aux 2 s. | — |
| N-B23 | IsOtherUserInteractionActive : interactions verrouillées pendant le tour d'un autre (GPMO:72 ; Base:116-124) | propriété | Oui (autre forme) | OnlineGameManager.gd:43-46 | Oui | Le client n'a pas de coups légaux hors de son tour : verrouillage par construction. | — |
| N-B24 | ShowAbilityApplyRequestBubble : bulle « HAS PLAYED A SPELL / ROOM ABILITY » pour les coups des joueurs distants (GPMO:247-253) | bulle | Non | BUI:903 (unique appel de `_notice_ai`) | Non | La bulle n'est déclenchée que par la boucle IA locale. En ligne `legal_moves` d'un autre siège est vide (OnlineGameManager.gd:43-46), donc ni humains distants ni IA serveur n'en génèrent. Déduit du code, à confirmer en exécution. | Moyenne |
| N-B25 | MenuOnlineScene : WORLDWIDE / WITH FRIENDS / CHANGE USER/AVATAR (MO:39-75) | scène | Oui | OM:242-246 | Oui | Disposition déjà auditée ailleurs. | — |
| N-B26 | MenuOnlineScene : Connect() à l'entrée, Disconnect() au retour (MO:34, 86-90) | méthode | Oui (autre forme) | OC:343-357 ; OM:243 | Oui | La connexion est paresseuse (au premier appel utile). Contrainte web : aucune connexion Photon préalable. | — |
| N-B27 | WORLDWIDE : ExpansionScene puis JoinPublicRoom (appariement auto), sinon « NETWORK ERROR / Unable to join public rooms » (MO:43-54 ; OS:631-644) | flux | Non (voulu) | OM:252-302 (liste des salons publics, hors APK) | Différent (voulu) | Pas d'appariement automatique : décision utilisateur. | Basse |
| N-B28 | WITH FRIENDS / NEW GAME : ExpansionScene puis CreatePrivateRoom ; échec : « Unable to create private room » (WFO:68-82 ; ExpansionScene.cs:146-157 ; OS:646) | flux | Oui | OM:626-629, 646-663 | Oui | Variantes ajoutées : salon public, INVALID SETUP pour 5-6 joueurs. | — |
| N-B29 | ROOM CODE : champ en fondu, OK, JoinPrivateRoom, succès vers WaitingPrivateRoom (WFO:49-62, 94-106) | flux | Oui | OM:608-630, 665-682 | Oui | Code de 4 lettres majuscules, « Invalid Code » si la longueur n'est pas 4. | — |
| N-B30 | Textes d'erreur ShowOnlineMessageBox (DBMBaseScene.cs:69-83) | modales | Oui (partiel) | OM:457-461, 663, 678-682, 807 | Différent | Présents : Invalid Code, Room is full, Unable to create/join private room, Unable to create public room. Écarts : « Unable to join public game » au lieu de « …room ». Pas de « Unexpected Error <n> ». Pas de « Expansions not match » (N-B31). | Basse |
| N-B31 | ExpansionsNotMatch : refus si le joiner n'a pas les extensions de la salle (OS:1017-1056) | contrôle | N/A | — | N/A | Boutique retirée : le serveur accepte tout joueur, les paquets sont ceux de l'hôte. | — |
| N-B32 | WaitingRoomBaseScene.OnDisconnect : « NETWORK ERROR / Unable to join public room » avec 3 pops (WRB:54-61) | modale | Oui (partiel) | OM:802-810 | Différent | `_on_waiting_error` ignore « reconnexion » : sur panne durable il n'y a aucun message, le client retente à l'infini. La flèche de retour reste disponible. | Basse |
| N-B33 | Salle morte : playersInRoom == 0 donne « NETWORK ERROR » puis Pop (WPR:132-136) | modale | Oui (avec bug) | OM:806-810 ; OC:239-244 | Différent | Le client émet `request_error` AVANT `_forget()`. `room_gone` (`match_id == ""`) est donc faux au moment du test. Le message devient « Unable to join private room », le OK ne fait rien et le joueur reste sur l'écran mort jusqu'à la flèche. Le texte « Room closed » n'apparaît jamais. | Moyenne |
| N-B34 | NavigatedBack : LeaveRoom puis Pop (WRB:149-154). Photon fait migrer le maître quand il part | flux | Oui | OM:788-800 ; SV:401-407 | Différent (voulu) | Quand l'hôte quitte une salle ouverte, la salle ferme pour tout le monde (aussi pour une publique). L'APK la gardait. Pas de bannissement dans l'APK ni dans Godot. | Basse |
| N-B35 | Panneau des joueurs : OnlinePanelEntity.UpdatePanel et OnlinePlayerInfoEntity.Refresh (nom tronqué à 25, avatar, WINS et DEFEATS, « WAITING... ») (OPE:78-98) | scène | Oui | OM:836-879 | Oui | Titre « WAITING FRIENDS... » présent (OM:727). WINS et DEFEATS viennent du profil envoyé au join (OC:325-326). | — |
| N-B36 | Nom en or pour IsBacker (OnlinePlayerInfoEntity.cs:55-63) | affichage | Oui (autre sens) | OM:853 | Différent (voulu) | Godot colore l'hôte en or. Pas de statut backer (boutique retirée). | Basse |
| N-B37 | OK de la salle privée : maître seulement et playersInRoom > 1 (WPrR:41-62) | contrôle | Oui | OM:872-879 | Oui | Condition `humans > 1`. START WITH BOTS (ajout) lance avec des IA. | — |
| N-B38 | SendGameInitialization : CloseRoom, graine, répartition des bosses, GoToGamePlay si plus d'un joueur (WRB:107-145) | méthode | Oui (autre forme) | GR:173-193 ; SV:380-385 | Oui | La salle passe à `running` et refuse les arrivées (SV:357-358). La graine est tirée par le serveur. L'origine de `forcedBoss` n'est pas auditée ici. | — |
| N-B39 | Démarrage : l'APK exige OK du maître (2 à 4 joueurs). Godot démarre dès que la salle est pleine | flux | Oui (différent) | SV:424-425 ; GR:173 | Différent (voulu) | La taille (2-6) est fixée à la création. Un salon plein démarre seul, l'hôte peut lancer avant. | Basse |
| N-B40 | Salle publique : titre « SEARCHING PLAYERS... », CountDownBehavior 45 s, compte à rebours 10 s à 4 joueurs, BeginCountDown, GlobalWaiting 60-120 s avec nouvelle recherche (WPR:27-143) | scène | Non (voulu) | — | Différent (voulu) | Décision utilisateur : salons et liste uniquement. | Basse |
| N-B41 | `ui_timer` en salle d'attente publique, chaque seconde sous 5 s (WPR:102-105 ; WRB:35) | son | Non | — (grep : seul appel CD:49) | Différent | **A-28 réglé.** Absent de la salle d'attente (cohérent avec N-B40). Il est rejoué par Godot dans le décompte de tour en partie, ce que l'APK ne fait jamais : ajout. | Basse |
| N-B42 | CountDownEntity (chiffres or ×3, ombre +3 px, sablier (30,-8), fondu 0,3 s) et CountDownBehavior (CDE:41-81) | entité | Oui (réutilisé) | CD:93-137 | Oui (visuel) | **P-C18/A-28.** Même habillage, mais utilisé comme minuteur de tour en partie (position (1150,12)) et non en salle d'attente (APK (1120,960)). `CountDownBehavior` n'existe pas : le décompte lit `turnDeadline` du serveur (CD:117-124). | Basse |
| N-B43 | RoomCodeEntity : « ROOM CODE: » avec le code en or (RoomCodeEntity.cs) | entité | Oui | OM:749-753 | Oui | — | — |
| N-B44 | TextEntryEntity : focus, placeholder, MaxLength, HideSoftKeys (TEE:77-147) | entité | Oui (autre forme) | OM:128-154 | Oui | Le clavier virtuel Android (CustomService.HideSoftKeys) est sans objet sur le web de bureau. | — |
| N-B45 | ChangeNameAvatarScene : valeurs par défaut `player_xxxx` et avatar au hasard, nom vide non enregistré, Truncate(45), pas de retour au premier passage (CNA:37-46, 101-111) | scène | Oui | OM:568-588 ; Profile.gd:16, 37-43 | Oui | Le serveur borne le nom à 25 (SV:241-243), comme l'affichage APK. | — |
| N-B46 | OnlineService.Update : reconnexion toutes les 4 s (`maintainConnected`) (OS:555-565) | méthode | Oui (amélioré) | OC:97-153 | Oui | Reprise avec `resume` et jeton de siège. | — |
| N-B47 | Pas d'IA dans les parties en ligne de l'APK | règle | Non (ajout voulu) | GR:51-57, 172-180 ; OM:760 | Différent (voulu) | Les sièges vides deviennent des IA (START WITH BOTS). | — |
| N-B48 | Expulsion d'un joueur (kick) | fonction | N/A | — | N/A | Absente de l'APK (aucune occurrence dans les scènes en ligne) et de Godot. | — |
| N-B49 | Fermeture de l'onglet / de l'application en pleine partie | contrainte web | Oui (autre forme) | GR:109-116, 329-334 ; SV:162-167 | Différent (voulu) | La connexion est détachée mais le siège reste. L'IA reprend à l'échéance du délai, avec les conséquences de N-B15. Aucun message pour les autres. | Basse |
| N-B50 | Dépendance native : Photon (ExitGames.Client.Photon), DBMEventCode, tri des événements par séquence (OS:549-600) | plateforme | N/A | — | N/A | Remplacé par WebSocket JSON et serveur autoritaire (PROTOCOL.md). Aucun SDK natif en Godot. | — |
| N-B51 | InitializeGameboard : Alias = pseudo de la salle, IsBacker, log « Player Disconnected While Initialization » (GPMO:140-197) | méthode | Non vérifié | BUI:814, 2161 | — | Les pseudos (`current_seats`) ne sont lus que dans la salle d'attente. Non confirmé que le plateau les affiche ou ignore les noms de boss. | — |
| N-B52 | Joueur éliminé en 3-4 joueurs : LoseScene dès que tous les humains locaux sont morts, même si la partie continue (Base:1070-1077) | comportement | Non vérifié | BUI:4273-4300 | — | Godot affiche le bandeau de fin sur `gameOver` seulement. Non confirmé ce que voit un joueur éliminé et s'il attend la fin. | — |
| N-B53 | CreateBeforePlayerInteractionTask : le donjon visible bascule sur le joueur actif (GPMO:232-240) | comportement | Non vérifié | BUI:1060-1080 (`_update_foe`) | — | Non confirmé que la vue suit l'adversaire actif en ligne. | — |

### Contre-vérification des lignes Haute

- **N-B08** confirmé : `OnlineClient.gd:234-244` oublie la session (`_forget`) sur `bad_token`, `not_found` ou `closed` et n'émet que `request_error`, que seul l'écran d'attente écoute (`OnlineMenus.gd:766`). En partie, `send_move` sort aussitôt si `match_id` est vide (`OnlineClient.gd:387`) : plateau figé, sans message, jusqu'à QUIT GAME.
- **N-B11** confirmé : le QUIT GAME et le OK de fin de partie appellent `show_title()` (`Main.gd:546`), sans `leave_match` (un seul appelant, `OnlineMenus.gd:793`). Le serveur garde `conn.room` et répond `busy` à `create` ou `join` (`Server.gd:309-310, 350-351`) jusqu'à la fermeture de la salle : 600 s après la fin, et pas avant la fin tant que la liaison reste ouverte (`humans_connected() > 0`, `Server.gd:175`). Atténuation : le bouton RESUME de WITH FRIENDS (`OnlineMenus.gd:632, 684-694`) permet de revenir dans la salle.
- **N-B15** confirmé : à l'échéance, `tick()` met `auto = true` pour chaque siège attendu (`GameRoom.gd:329-334`) ; seul un coup du joueur le remet à faux (`GameRoom.gd:215`). Avec la pause d'aventure de 10 s, un humain qui hésite perd la main sur toutes ses décisions suivantes, y compris le tour de construction. Documenté comme voulu dans `PROTOCOL.md:292-294` : à arbitrer par le propriétaire (passer seulement la décision expirée, comme l'APK qui ne fait qu'un DONE automatique).
- **N-B16** confirmé : `_after_move` relance `_reset_deadline()` après tout coup valide (`GameRoom.gd:220-227`). `undoBuild` reste légal jusqu au DONE (`Match.gd:414-424, 549`). Alterner `buildRoom` et `undoBuild` repousse l'échéance sans fin : un joueur peut bloquer la table indéfiniment. L APK ne réarme sa barre de 70 s que sur une capacité résolue (`GamePlayBaseScene.cs:621-624`).

### Non vérifié

- `Match.gd` non relu pour : le coup de `ChooseDeckToDraw` (N-A56), `stackPassed` (N-A54), une carte face cachée dans `stack` (N-A69).
- N-B51 (pseudos affichés sur le plateau), N-B52 (ce que voit un joueur éliminé à 3-4 joueurs en ligne, lié à P-A10), N-B53 (bascule du donjon visible sur le joueur actif).
- N-B11 et N-B24 sont déduits du code : aucune partie en ligne réelle n'a été jouée pendant l audit. `tests/online_test.gd` lu, non exécuté.
- Comportement réel derrière nginx (403 Origin, 429) : lu dans `deploy/nginx.conf`, prouvé sur le homelab selon `PROTOCOL.md`, non rejoué ici.
- Durée de `BOSS_AUTO_TIME` face aux 2 s de l'APK (N-B22), origine de `forcedBoss` (WRB:121-124).

### Synthèse du module 9

- **Éléments audités** : 128 (9A : 75, 9B : 53).
- **Conformes ou sans objet** : 82 lignes sans priorité (dont 3 Non vérifié en 9B).
- **Écarts** : 46 — Critique 0, Haute 4, Moyenne 10, Basse 32.
  - Haute : N-B08 (session perdue en partie : plateau figé sans message), N-B11 (après une partie, impossible de créer ou rejoindre un salon sans recharger), N-B15 (l'IA garde la main après un seul dépassement de délai, à arbitrer), N-B16 (un joueur peut bloquer la partie sans fin avec pose/reprise).
  - Moyenne : N-A05, N-A40, N-A41 (coupure et départ adverse invisibles en partie), N-B01 et N-B03 (S-11 : aucune défaite comptée à l'abandon), N-B07 (modale de connexion perdue absente en partie), N-B12 (bulle IS PLAYING! absente), N-B18 (pas d'avance automatique de l aventure en ligne), N-B24 (bulle HAS PLAYED A SPELL absente pour les coups distants), N-B33 (salle fermée : mauvais message, OK sans effet).
- **Renvois réglés** : S-11 (N-B01, N-B03), S-18 (N-A44 à N-A48), P-A15 (N-B20, galerie toujours proposée en ligne), P-A30 et P-B33 (N-B14 : 60 s en chiffre contre 70 s en barre), P-A48 et P-B13 (N-B12), P-A55 (N-B04, N-B05, N-B07, N-B17), P-C18 et A-28 (N-B41, N-B42), R-D54 (N-B06).
- **Points meilleurs que l'APK** : coups validés contre `legal_moves` (pas de triche ni d'usurpation de siège), information cachée filtrée côté serveur (N-A68), reprise de siège après coupure (N-A67), Origin et débit limités (N-A72).
- **Bloquants web** : aucun. Photon natif remplacé par WebSocket sans thread. Contrainte web : la fermeture d'onglet n'envoie pas `leave` (N-A71) ; le siège passe à l'IA à l'échéance.

---

## Module 10 — Dépendances Android (IAP, logs, Insights)

Périmètre : `AndroidManifest.xml` (permissions, activités), `AndroidActivity.cs` (cycle de vie, bouton Retour, orientation, écran allumé), `Game.cs`, `DBMGameProject.Interfaces/CustomService.cs`, `Services.AppPurchase/`, `Services.CatalogService/`, `Services.Log/`, `Services.Test/`, `InAppServiceBinding`, `play.billing.v3`, `Xamarin.Insights`, `WaveEngineAndroid.Bepu/Farseer`, `Zlib.Portable`, `System.Json`, `Newtonsoft.Json`. Stockage renvoyé au module 1, Photon au module 9. Décisions du propriétaire : boutique supprimée, cible bureau à la souris.

Méthode : un lot en lecture seule. Aucune ligne Haute, donc rien à contre-vérifier.

| ID | Élément source (décompilé) | Type (classe/méthode/asset/scène) | Présent dans Godot ? | Fichier Godot | Équivalent fonctionnel ? | Écart / Commentaire | Priorité |
|---|---|---|---|---|---|---|---|
| D-01 | Permission `INTERNET` (AndroidManifest.xml:19) | Manifest, permission | Oui | `godot/scripts/OnlineClient.gd:78-91`, `godot/scripts/Main.gd:71-75` | Oui | Le navigateur n'a pas de permission à déclarer. Le WebSocket vise `window.location.origin`. | — |
| D-02 | Permissions `ACCESS_NETWORK_STATE`, `ACCESS_WIFI_STATE` (manifest:20-21) | Manifest, permission (utilisée par Photon) | Non (vérifié absent) | grep `NetworkState` ou `online` dans `scripts/` : seul l'état du WebSocket est suivi (`OnlineClient.gd:96-140`) | Oui | Détection de coupure remplacée par ping/pong et reprise de siège (voir D-14). | — |
| D-03 | `WRITE_EXTERNAL_STORAGE` (manifest:16) | Manifest, permission | Oui | `godot/scripts/Profile.gd:17` (`user://profile.cfg`) | Oui | Sauvegarde : renvoi module 1, non refait ici. | — |
| D-04 | `SYSTEM_ALERT_WINDOW`, `GET_TASKS` (manifest:15,17) | Manifest, permissions | Non (vérifié absent) | grep `ALERT_WINDOW\|GET_TASKS` dans `decompiled/DBMGame` : 0 résultat | N/A | Aucun usage dans DBMGame (probablement hérités d'Ubertesters ou Wave). | — |
| D-05 | `com.android.vending.BILLING` (manifest:18) | Manifest, permission | Non (supprimé) | `Main.gd:6` (« IN-APP STORE supprime ») | Oui (décision) | Boutique retirée. | — |
| D-06 | `AndroidActivity` MainLauncher, singleTask (manifest:7-12 ; `DBMGame/AndroidActivity.cs:20`) | Classe, point d'entrée | Oui | `project.godot` (`run/main_scene`), `export_presets.cfg:[preset.0]` | Oui | L'entrée est `Main.tscn`, qui appelle `show_title()` (`Main.gd:64-84`). Pas de `singleTask` : plusieurs onglets possibles (le serveur évince le doublon, `OnlineClient.gd:403`). | — |
| D-07 | `ScreenOrientation.Landscape`, `SupportedOrientations` (`AndroidActivity.cs:29-31`, manifest:7) | Propriété d'activité | Partiel | `project.godot` (`[display]` 1920x1080, `stretch/mode=canvas_items`, `aspect=keep_aspect`) | Oui | Le paysage est forcé par le letterbox, pas de verrouillage. L'APK utilise un viewport 1440x1080 `Uniform` (`Game.cs` `VIEWPORT_WIDTH`), le port une maquette 1920x1080 : voir le module sur l'UI. | — |
| D-08 | `FullScreen = true` et `HideSoftKeys()` (barres système immersives, `AndroidCustomService.cs`, `SystemUiVisibility |= 1,2,0x800,0x1000`) | Méthode | Non (vérifié absent) | grep `fullscreen\|FULLSCREEN\|window_set_mode` dans `scripts/` : 0 résultat | Non | Pas de bouton plein écran. F11 reste possible dans le navigateur. | Basse |
| D-09 | `Window.AddFlags(KeepScreenOn)` (`AndroidActivity.cs:52`) | Appel natif (wake lock) | Non (vérifié absent) | grep `keep_screen_on\|screen_set_keep_on\|wakeLock` : 0 résultat | Non | Pas de verrou d'écran. Sans importance en bureau à la souris : une partie contre l'IA demande des clics. | Basse |
| D-10 | `OnKeyDown(Keycode.Back)` appelle `NavigatedBack()` sur toutes les scènes (`AndroidActivity.cs:65-83`) | Méthode, bouton retour | Partiel | Flèche retour à l'écran (`Main.gd:213-226`, `back_bt.webp`), menu engrenage en jeu (`BoardUI.gd:4301-4340`) | Oui (par bouton) | Aucune touche Échap ou Retour gérée : grep `KEY_ESCAPE\|ui_cancel\|KEY_BACK\|_unhandled_key` dans `scripts/` : 0 résultat. Aucun besoin de capter le bouton Retour du navigateur. | Basse |
| D-11 | `LoadingScene.NavigatedBack` appelle `Platform.Exit()` (`LoadingScene.cs:64-67`) ; `QuitGameScene` appelle `Platform.Exit()` (`QuitGameScene.cs:31`) | Méthode, quitter l'application | Partiel | Quitter la partie : `BoardUI.gd:4339-4340`, puis `Main.gd:546` (retour titre) | Oui (N/A web) | Pas de « quitter l'appli » dans un onglet. La confirmation « Quit to menu ? » en partie est portée. Depuis le menu principal, la flèche mène à l'écran titre (`Main.gd:276`) comme dans l'APK (`MainMenuScene.cs:199`). Aucun appel à `get_tree().quit()` : grep `\.quit(` : 0 résultat. | — |
| D-12 | `OnPause` appelle `game.OnDeactivated()` (`AndroidActivity.cs:~96-102`) | Cycle de vie | Partiel | Seul `NOTIFICATION_APPLICATION_FOCUS_OUT` géré : `BoardUI.gd:3562` (abandon d'un appui de glisser) | Non vérifié | Aucune pause générale ni coupure audio à la perte de focus ou au masquage de l'onglet : grep `visibilitychange\|NOTIFICATION_APPLICATION_PAUSED\|get_tree().paused` : 0 résultat. Un onglet masqué gèle `requestAnimationFrame`, donc la logique pilotée par `delta` s'arrête. La coupure du son et le clamp du delta au retour ne sont pas prouvés. | Basse |
| D-13 | `OnResume` appelle `game.OnActivated()` (`AndroidActivity.cs:~106-115`) | Cycle de vie | Partiel | Comme D-12 | Non vérifié | Au retour sur l'onglet, l'APK reprend le Wave loop. Le port repart sur un `delta` potentiellement grand (garde-fou côté réseau seulement : `OnlineClient.gd:122`, `SLEEP_GAP_S`). | Basse |
| D-14 | `Game.OnlineSuspend` donne `OnlineClient.IsSuspended` ; déconnexion après `MaxSuspendedTime` = 30 s (`Game.cs:~80-85`, `OnlineClient.cs:43-45,145-160`) | Méthode, suspension réseau | Oui | `OnlineClient.gd:26-33,115-134` (ping 20 s, reprise après trou > 5 s, pong 8 s) ; reprise par jeton `OnlineClient.gd:104-106,403-426` ; `server/Server.gd:30-45` (inactivité 120 s, grâce de siège 30 s) ; `server/GameRoom.gd:313-331` (IA prend le relais) | Oui (supérieur) | Pas de déconnexion volontaire à 30 s : la liaison'est rouverte avec le jeton de siège. Renvoi module 9. | — |
| D-15 | `OnWindowFocusChanged` appelle `HideSoftKeys()` (`AndroidActivity.cs:~90-94`) | Méthode | Non (N/A) | — | N/A | Barres système Android seulement. | — |
| D-16 | `CustomService` (service de base) et `AndroidCustomService` (`DBMGameProject.Interfaces/CustomService.cs`) | Classe, service plateforme | Non (N/A) | — | N/A | `HideSoftKeys` et `IsFullScreenActive` sont sans objet sur le web. | — |
| D-17 | `TextEntryEntity.LostFocus` programme `HideSoftKeys` après 0,2 s (`TextEntryEntity.cs:~118-130`) | Méthode, clavier virtuel | Partiel | `OnlineMenus.gd:128-165` (LineEdit, perte de focus au clic hors champ) ; `export_presets.cfg` : `html/experimental_virtual_keyboard=false` | Oui (bureau) | Bureau : clavier physique, rien à masquer. Mobile : clavier virtuel désactivé, donc la saisie du code de salle ou du pseudo sur tactile est probablement impossible. Cible souris : lacune tactile. | Basse |
| D-18 | `Insights.Initialize` avec `XAMARIN_INSIGHTS_KEY` et `ForceDataTransmission` (`Game.cs:~20`, `AndroidActivity.cs:39-40`) | Analytique Xamarin | Non (absent par conception) | grep `insights\|analytic\|telemetr\|sentry\|crashlytics\|ubertest` dans `scripts/` : 0 résultat ; aucun `HTTPRequest` ni `HTTPClient` | Oui | Aucune télémétrie dans le port. La clé figure en clair dans l'APK. | — |
| D-19 | `AndroidEnvironment.UnhandledExceptionRaiser` appelle `LogService.LogException` puis `Insights.Report` (`AndroidActivity.cs:41-44`, `LogService.cs:~42-50`) | Rapport de crash | Non (vérifié absent) | Seuls `push_error` : `CardDB.gd:44`, `Match.gd:130` (console du navigateur) | Non | Pas de remontée d'erreurs. L'absence est cohérente avec D-18. | Basse |
| D-20 | `LogService.LogError` et `LogWarning` appellent `Insights.Track` (`LogService.cs:~53-63`) | Journal et suivi | Non (vérifié absent) | grep `LogService\|LogCategory` : 0 résultat | N/A | Journalisation sans télémétrie : inutile côté web. | — |
| D-21 | `LogService` : files de 30 entrées, `GetLogList`, `ShowLastLogs` (`LogService.cs:109-115`) ; `LogCategory` (11 valeurs) | Classe, journal en mémoire | Non | — | N/A | `ShowLastLogs` n'est jamais appelé (grep `ShowLastLogs` : seule la définition). Outil de debug. | — |
| D-22 | Ubertesters : `meta-data ubertesters_project_id` et activité `UbertestersScreen` (manifest:5-6) | SDK de bêta-test | Non (N/A) | — | N/A | Seule la déclaration apparaît dans le manifest ; `ls apktool-decoded/smali/com/` ne liste que `dbm/`. Non vérifié dans les DLL. | — |
| D-23 | `mono.MonoRuntimeProvider`, `mono.android.app.Application` (manifest:4,13) | Runtime Xamarin | Non (N/A) | — | N/A | | — |
| D-24 | `supports-screens` (large et xlarge, 600 dp minimum) (manifest:3) | Manifest | Partiel | `project.godot` (resizable) | Oui | Fenêtre redimensionnable, pas de taille minimale imposée. | — |
| D-25 | `AppPurchaseService` : `ConnectToMarket`, `InitializeInAppPurchaseService`, `ReloadProducsAndUpdate`, `PurchaseItem` (`AppPurchaseService.cs:76-184`) | Classe, achat intégré | Non (supprimé) | `Main.gd:6,281` ; grep `purchase\|iap\|store` dans `scripts/` : seul l'asset sonore `ui_purchase` (`AudioManager.gd:20`) | Oui (décision) | Le bouton IN-APP STORE est remplacé par RULES (`Main.gd:281`). | — |
| D-26 | `PurchaseId` : ids `com.dbm.fullgame` à `fullgame4`, clé RSA `MARKETDBMKey` | Constantes | Non (supprimé) | grep `com.dbm\|MARKETDBM` : 0 résultat | Oui (décision) | | — |
| D-27 | `LocalMarket.GetAllItemList`, `IsFullVersionOnly` (Full Game déverrouille bosses, Pass and Play et en ligne), asset `Content/Common/marketItems.json` (`AppPurchaseService.cs:24`) | Classe et catalogue | Non (supprimé) | `Main.gd:20-26` (`APK_DECKS`, tous `playable:true`) | Oui (décision) | Plus aucune restriction de version. Le Power-Up Pack (`IsCommingSoon`) est absent du port : voir le module sur les cartes. Le fichier `marketItems.json` n'est pas dans `apk-original` (`find -name marketItems.json` : rien) : non lu. | — |
| D-28 | Hidden Heroes `WinsToUnlock = 40` (`LocalMarket.cs:~150`, `UnlockFromWins` `AppPurchaseService.cs:315`, `WinnerScene.cs:~101`) | Logique de déblocage | Non (supprimé) | `Main.gd:24` (hidden-heroes jouable d'emblée) | Oui (décision) | | — |
| D-29 | `UnlockScene` (« CONGRATULATIONS ») et `Unlock(DBMActivationCodeResponse)` (`AppPurchaseService.cs:185-262`) | Scène | Non (supprimé) | — | Oui (décision) | | — |
| D-30 | Code de rachat : `ValidateCode`, `WebUtils.MakeRequest`, URL `digitalbossmonster.azurewebsites.net` (`AppPurchaseService.cs:22,264-300`), `UnlockCodeScene` déclenché par `TwoLongTouchBehavior` (`MainMenuScene.cs:121-140`) | Réseau et scène | Non (supprimé) | grep `azurewebsites\|ValidateCode\|redeem` : 0 résultat | Oui (décision) | Aucun appel HTTP sortant dans le port. | — |
| D-31 | `WebUtils` : `ServerCertificateValidationCallback = true` (accepte tout certificat) (`WebUtils.cs`) | Faille de l'APK | Non | — | N/A | Non reproduit, tant mieux. | — |
| D-32 | Backer et Legendary : `IsBacker` (`Game.cs:~108`, `Boss.cs:24`, `GamePlayBaseScene.cs:564-568`, `ControlsFactory.cs:296,321`, logo `logo_small_legend`, `OnlinePlayerInfo`) | Champs et rendu | Non (supprimé) | grep `backer\|legendary` : seulement du texte de carte dans `cards.json:3964,4821` | Oui (décision) | | — |
| D-33 | `play.billing.v3` (`BillingService`, `Buy`, `GetPurchases`, `Security`, `Inventory`, `ConsumePurchase`…) | Bibliothèque | Non (N/A) | — | Oui (décision) | | — |
| D-34 | `InAppServiceBinding` (`IInAppBillingService` AIDL) | Liaison native | Non (N/A) | — | Oui (décision) | | — |
| D-35 | `CatalogService` et `ICatalogService` (enveloppe de `Catalog.GetItem/RegisterItem`) | Classe | Non (N/A) | Réglages : `Profile.gd`, `AudioManager.gd` (ConfigFile) | Oui | Inutilisé : grep `CatalogService` hors du dossier : 0 résultat. Le `Catalog` Wave lui-même reste utilisé via `Game.cs` (stockage, voir module 1). | — |
| D-36 | `AudioService` (`DBMGameProject.Services/AudioService.cs`) | Service audio | Oui | `AudioManager.gd` (autoload) | Oui | Aucun appel Android direct (grep `Android\.` dans DBMGame : seulement 3 fichiers). Ajout web : déblocage de l'audio au premier clic (`AudioManager.gd:48,80-88`). | — |
| D-37 | `CardInfoService`, `CardAssetService`, `ModalSceneService`, `TextureAtlasInfo` | Services | Oui (équivalents) | `CardDB.gd`, `data/cards.json` | Oui | Aucun appel natif. Chargement du JSON via Newtonsoft + `InternalJsonContractResolver` (`CardInfoService.cs:74-77`), remplacé par le `JSON` de Godot. | — |
| D-38 | `Services.Online`, `OnlineClient` (hôte `app-eu.exitgamescloud.com:5055`, `OnlineClient.cs:135`) | Photon | Voir module 9 | `OnlineClient.gd`, `server/` | Voir module 9 | Renvoi uniquement. | — |
| D-39 | `Services.PlayerInteraction` (Human/AI/Remote) | Services | Voir autres modules | `AI.gd`, `GameManager.gd` | — | Aucune dépendance native. | — |
| D-40 | `Services.Test.GameFlowTestService` (boucle IA contre IA infinie) | Service de test | Non (N/A) | Suites de tests dans `godot/tests/` | N/A | Jamais enregistré dans `Game.cs`. | — |
| D-41 | `Scenes.Test` (16 scènes), `DebugSceneBehavior` (F1-F6), `DrawCardsDemoBehavior` (Ctrl+S/R/K, 1-4) | Debug | Non (N/A) | — | N/A | | — |
| D-42 | `Platform.OnScreenSizeChanged` (`EdgeAlignmentComponent`, `VirtualScreenAlphaScissorLayer`, `StretchBehavior`), `ViewportManager.Activate(...Uniform)` (`Game.cs`) | Redimensionnement | Oui | `project.godot` (canvas_items et keep_aspect) ; `export_presets.cfg` : `html/canvas_resize_policy=2` | Oui | | — |
| D-43 | `TouchPanel.MaxTouchPoints = 1` (`Game.cs`), `TwoLongTouchBehavior`, `TouchGestures` | Entrées | Oui | `project.godot` : `pointing/emulate_touch_from_mouse=true` | Oui (souris) | Le multi-point n'a pas d'usage, hormis le code de rachat (supprimé). | — |
| D-44 | `KeyboardState` : flèches gauche et droite du carrousel (`CarrouselDragBehavior.cs:74-84`) | Entrée clavier | Partiel | `RulesViewer.gd:117-119` ; `CardGallery.gd` : aucun `KEY_LEFT` (grep) | Non vérifié | Le carrousel (`CardCarrouselEntity`) n'a pas de flèches clavier dans le port. Pas de pertinence en jeu à la souris. | Basse |
| D-45 | Moteurs physiques `WaveEngineAndroid.Bepu` et `.Farseer` | Bibliothèques | Non (N/A) | — | N/A | Inutilisés par DBMGame : grep `Farseer\|Bepu\|RigidBody` : 0 résultat. Les 111 `RectangleCollider` et le `Framework.Physics2D` ne servent qu'au test de touche (Controls Godot). | — |
| D-46 | `Zlib.Portable`, `System.Json` | Bibliothèques | Non (N/A) | — | N/A | Aucun usage dans DBMGame : grep `Zlib\|System.Json\|GZip\|Deflate` : 0 résultat. | — |
| D-47 | `Newtonsoft.Json` (7 fichiers : `CardInfoService`, `CreditsScene`, `OnlineService`, `OnlineClient`, `AppPurchaseService`, `GameBoardFlowInfo`, `InternalJsonContractResolver`) | Sérialisation | Oui | Cartes : `CardDB.gd` ; réseau : `NetCodec.gd` ; réglages : `ConfigFile` (`Profile.gd`) | Oui | Les sauvegardes passent par `WaveServices.Storage` + `StorageHelper` (retries x8) : module 1. | — |
| D-48 | Ouvrir une URL, partager, noter, réseaux sociaux (`Intent`, `Launcher`, `Share`) | Appel natif | Non (absent des deux côtés) | `OS.shell_open` : grep dans `scripts/` : 0 résultat ; `CreditsScreen.gd` sans URL | N/A | Côté APK, grep `https?://` dans DBMGame hors modèle : seulement `ValidationURL` et l'hôte Photon ; aucun `Intent` ni `Launcher`. Les crédits APK ne contiennent aucun lien. | — |
| D-49 | Vibration, notifications, permissions à l'exécution | Appel natif | Non (absent des deux côtés) | grep `vibrat\|Handheld\|notif` : seulement des bulles de jeu | N/A | grep `Vibrat\|Notification` dans DBMGame : 0 résultat. | — |
| D-50 | `Resource.cs` (identifiants R Android), `LayoutId = 2130903040` | Classe générée | Non (N/A) | — | N/A | | — |
| D-51 | Ajouts web du port : `JavaScriptBridge` (origine, `sessionStorage`), shim `isSecureContext` et `AudioWorklet` dans `head_include` | Spécifique web | Oui | `Main.gd:71-75`, `OnlineClient.gd:403-426`, `export_presets.cfg` (`html/head_include`, `thread_support=false`) | Oui | Le shim force `window.isSecureContext = true` et stubbe `audioWorklet` pour le HTTP clair sur ZimaOS. À garder en tête hors du homelab. | Basse |

### Non vérifié

- Onglet masqué puis réactivé (D-12, D-13) : coupure du son et taille du `delta` au retour, à tester dans un navigateur.
- Contenu des DLL pour Ubertesters (seul le dossier smali a été listé) ; `marketItems.json` absent d'`apk-original`.
- Numéros de ligne marqués `~` : approchés.

### Synthèse du module 10

- **Éléments audités** : 51.
- **Conformes ou sans objet** : 42.
- **Écarts** : 9, tous Basse (D-08 plein écran, D-09 écran allumé, D-10 touche Échap, D-12 et D-13 perte de focus, D-17 clavier virtuel, D-19 rapport de crash, D-44 flèches du carrousel, D-51 shim `head_include`).
- **Aucune télémétrie** dans le port (pas de `HTTPRequest` ni `HTTPClient`), aucun appel HTTP sortant, aucun reste de boutique ou de backer hormis l'asset sonore `ui_purchase`. La faille de l'APK qui accepte tout certificat (`WebUtils.cs`, D-31) n'est pas reproduite.
- **Bloquants web** : aucun.

---

## Module 11 — Assets / rendu

Périmètre : contenu brut de l'APK (`apk-original/boss-monster-2-2-6/assets/Content/` : Audio, CardDecks, Common, EXPANSIONS.wpk, Fonts, Loading, NinePatch, Tutorial), shader `DBMGame.CardEffectps/vsTexture`, `WaveEngine.Extensions.*`, `DBMGameProject.Common.Layers/`, particules, polices, crédits. Côté Godot : `src/frontend/assets/` (apk_cards, audio, cards, data, fonts, rules, ui), `godot/data/cards.json`, `CardUI.gd`, `ApkParticles.gd`, `CreditsScreen.gd`, `TutorialOverlay.gd`, `project.godot`. Les dispositions d'écrans sont aux modules 4, 7 et 8 ; ici on vérifie que chaque asset et chaque fonction de rendu existe.

Méthode : un lot en lecture seule, appuyé sur `apk-original/decompiled/assets_full_coverage.md` et `python -I tools/verify_assets.py` (« all'APK faces present »). Les 5 fichiers notés MANQUANT par le rapport de couverture ont été revus un à un. Aucune ligne Haute. R-F76 a été corrigé dans le module 5 : le texte faux des 41 héros Hidden Heroes n'est lu par aucun écran (`description_text` sans lecteur, contre-vérifié par grep).

| ID | Élément source (décompilé) | Type (classe/méthode/asset/scène) | Présent dans Godot ? | Fichier Godot | Équivalent fonctionnel ? | Écart / Commentaire | Priorité |
|---|---|---|---|---|---|---|---|
| G-01 | `APK/Audio/` (44 : 42 sfx WPK et 2 MP3) | Dossier d'assets | Oui | GA/audio/sfx (42 wav), GA/audio/music (2) | Oui | Comptage seulement ; audit détaillé au module 2. | — |
| G-02 | `APK/CardDecks/BaseDeck/data.json` et `ai_info.json` | Données | Oui | GA/data/BaseDeck/ | Oui | `cmp` octet à octet : identiques. | — |
| G-03 | `CardDecks/HiddenHeros/data.json` et `ai_info.json` | Données | Oui | GA/data/HiddenHeros/ | Oui | `cmp` : identiques. | — |
| G-04 | `CardDecks/PlayerChoice/data.json`, `CardDecks/ToolsHeroKind/data.json` | Données | Oui | GA/data/PlayerChoice/, GA/data/ToolsHeroKind/ | Oui | `cmp` : identiques. | — |
| G-05 | `BaseDeck/Assets/*.wpk` : bma014 à bma096, `back_boss-bma013`, `dungeonbg_*`, `boss_profile`, `hero_characters` | Atlas de cartes | Oui | GA/apk_cards/base (117 fichiers), GA/ui/characters (145), GA/ui/dungeon (15) | Oui | webp. `verify_assets.py` : "all'APK faces present". 8 boss, 31 salles, 16 sorts, 41 héros. | — |
| G-06 | `HiddenHeros/Assets/bmh056-096.wpk` (images) | Atlas de cartes | Oui | GA/apk_cards/hidden/ (41 webp) | Oui | 41 images pour 41 cartes. Lecture visuelle de `bmh056.webp` : "Cleric, Everel the Healer", portrait correct. | — |
| G-07 | BMH056 : `Description` vide dans `HiddenHeros/data.json:19-30`, texte imprimé sur l'image | Texte de carte | Oui, texte faux | `godot/data/cards.json:4036-4053` | Non (texte) | `description` = "Nick the Masher..." (texte de BMA056) alors que l'image dit "Everel the Healer". Mon script Python sur `cards.json` : 41 héros hidden-heroes sur 41 reprennent mot pour mot le texte du BMA remplacé. R-F76 est confirmé et étendu : non limité à BMH056. Correction de R-F76 : AUDIT.md dit "Affiché en infobulle (`CardData.gd:52`)". `description_text` n'est que lu à `CardData.gd:52` et déclaré à `:17`, aucun autre lecteur. Les `.get("description")` de `BoardUI.gd:1666` et `:3961` ne portent que sur les salles. Le texte faux n'est donc affiché nulle part et la carte est affichée via l'image correcte. Risque seulement si une infobulle ou une galerie texte est ajoutée. Corriger ou vider ces 41 champs. | Basse |
| G-08 | `PlayerChoice/Assets/ksa001-ksa017.wpk`, `dungeonbg_ksa*`, `boss_profile`, `hero_characters` | Atlas de cartes | Oui | GA/apk_cards/playerchoice/ (11 webp : ksa001-007, 013, 014, 016, 017), GA/ui/characters/ksa*, GA/ui/dungeon | Oui | 11 images pour 11 cartes (7 boss, 1 sort, 3 héros) dans `data.json`. Les ids manquants dans la plage ksa001-017 n'existent pas dans les données. | — |
| G-09 | `ToolsHeroKind/Assets/back_item-thk019.wpk`, `thk020-025.wpk` | Atlas de cartes | Oui | GA/apk_cards/tools/ (back_item, thk001 à thk025, plus thk025a) | Oui | 25 cartes thk et 1 dos. `thk025a` n'a pas de source APK : c'est un ajout (alt-art), à confirmer. | — |
| G-10 | `Common/AVATAR.wpk` | Atlas UI | Oui | GA/ui/avatar/ (19 webp) | Oui | `assets_full_coverage.md` : extrait. Contenu de l'atlas non recompté ici. | — |
| G-11 | `Common/GRADIENTS.wpk`, `INGAME.wpk`, `NAVIGATION.wpk`, `TUTORIAL.wpk` | Atlas UI | Oui | GA/ui/gradients (15), GA/ui/ingame (108), GA/ui/navigation (29), GA/ui/tutorial (20) | Oui | Extraits par `tools/extract_apk_226.py`, sprites individuels en webp. Comptage par sprite non refait (voir Non vérifié). | — |
| G-12 | `Common/gallery_bg`, `intro_bg`, `menu_bg`, `multiplayer_bg`, `particle_01.wpk` | Sprites | Oui | GA/ui/backgrounds/*.webp, GA/ui/particle_01.webp | Oui | Les 5 fonds et la particule sont présents. | — |
| G-13 | `Common/credits.json` | Données | Oui | GA/data/credits.json | Oui | `cmp` : identique à la source. | — |
| G-14 | `EXPANSIONS.wpk` | Atlas UI | Oui | GA/ui/expansions/ (21 webp) | Oui | Présent. Écran Expansions : voir G-34 (magasin retiré par décision de portée). | — |
| G-15 | `Fonts/arcadepix.wpk`, `arcadepix2.wpk`, `bookman_old_style.wpk` | SpriteFonts | Oui | GA/fonts/arcadepix.fnt (+_bm.png), arcadepix2.fnt, bookman_old_style.fnt | Oui | BMFont, utilisé par `UiKit.gd:5-6` (FONT_A, FONT_B). Le rendu bitmap garde le pixel-art. | — |
| G-16 | `Fonts/f04b03.wpk` (16 459 octets) | SpriteFont | Non (vérifié absent) | — (`find src apk-original -iname "*f04b03*"` : seuls des caches `.godot/` périmés) | N/A | `ControlsFactory.Create04b03TB` (`ControlsFactory.cs:54-58`) n'a aucun appelant dans DEC (grep : seule sa définition). Police du code mort, `assets_full_coverage.md` la déclare "MANQUANT". Les "ui/characters" ne la référencent pas. | — |
| G-17 | `Loading/LOADING_SCREEN.wpk` : sprite `loading` ("LOADING..." animé) | Atlas | Partiel | GA/ui/loading/loading.webp (importé, jamais lu) | Non | `grep -rn "ui/loading\|loading.webp"` sur scripts et scènes : aucun résultat. `LoadingScene.cs:30-32` pose ce sprite en (830, 0.8 x H) avec `RupisLoadingBehavior` (3 points, 0,5 s, `LoadingScene.cs:34-39`). Absent en Godot. Le chargement web est celui du moteur. | Basse |
| G-18 | `Loading/loading_bg.wpk` | Sprite | Oui | GA/ui/backgrounds/loading_bg.png, `src/frontend/project.godot:12` (`boot_splash/image`) | Partiel | Fond en boot splash. L'écran applicatif `LoadingScene` (fond puis fondu noir vers Intro, `LoadingScene.cs:48-58`) n'existe pas en Godot ; `Main.gd` démarre directement. | Basse |
| G-19 | `NinePatch/avatars_bg`, `bg_levelup_banner`, `code_area_act`, `code_area_inact`, `progress_green`, `searching_bg` | Ninepatch | Oui | GA/ui/ninepatch/ (6 webp) | Oui | Utilisés : `BoardUI.gd:1323` (levelup, marges 15/17/15/15), `OnlineMenus.gd:129,578,705,749,777`, `TimeBar.gd:7`. Rendu par `UiKit.ninepatch` (NinePatchRect). | — |
| G-20 | `NinePatch/progress_yellow.wpk` | Ninepatch | Non (vérifié absent) | — (`find` : introuvable ; GA/ui/ninepatch ne contient que 6 fichiers) | Non | Barre jaune de 177 px sous le bouton DONE (5 s) : `DoneButtonEntity.cs:98` crée `new ProgressBarEntity(..., 177f, 5 s, ..., NinePatchs.InGame.progress_yellow)`, instancié à `GamePlayBaseScene.cs:252`. Elle se vide en 5 s puis `StopAndHideButton` (`:145-148`). `grep progress_yellow` dans GS : aucun résultat. Le comportement associé (pulsation, minuteur de 5 s) est déjà noté absent en P-C51 (AUDIT.md:1095). | Moyenne |
| G-21 | `NinePatch/settings_text_bg.wpk` | Ninepatch | Non (vérifié absent) | — | Partiel | `SettingButtonDecorator.cs:71` l'utilise, 3 lignes dans `SettingsScene.cs:70-92`. `Main.gd:663-680` (`_toggle_row`) dessine un aplat à la place. Déjà noté U-A56 (AUDIT.md:244, Basse). | Basse |
| G-22 | `NinePatch/settings_slider_bg.wpk` | Ninepatch | Non (vérifié absent) | — | N/A | `SettingsSliderControl.cs:41` : aucun appelant (`new SettingsSliderControl` introuvable dans DEC). Code mort, déjà noté I-16 (AUDIT.md:152). | — |
| G-23 | `Tutorial/kingcroak_anim.wpk` et `kingcroak_anim.xml` | Atlas animé | Oui | GA/ui/tutorial/kingcroak_anim.webp et `.xml`, `TutorialOverlay.gd:52-56,895-902` | Oui | 7 images de 63 x 62 en AtlasTexture, 8 images/s, boucle. `texture_filter = NEAREST` (`:902`), fidèle à PointClamp (`TutorialIntroScene.cs`). | — |
| G-24 | `Tutorial/mascara_00.wpk`, `mascara_black.wpk` | Sprites | Oui | GA/ui/tutorial/mascara_00.webp, mascara_black.webp | Oui | Présents. | — |
| G-25 | `Tutorial/mascara_01.wpk` (65 670 octets) | Sprite | Non (vérifié absent) | — (`find` : seul un cache `.godot/imported` périmé) | N/A | Uniquement dans l'enum `Sprites.cs:33`. `grep -rn "mascara_01"` dans DEC ne donne que cette déclaration : jamais chargé. Code mort. | — |
| G-26 | `DBMGame.CardEffectpsTexture.frag` et `.vert` : niveau de gris `0.3 R + 0.55 G + 0.15 B`, `mix(gris, couleur, Amount)`, `x outColor` ; `CardMaterial` (`.Amount`), `ColorFadeBehavior.cs:56` | Shader GLSL | Oui (inline) | `CardUI.gd:57-63` (shader `amt`, poids 0.3/0.59/0.11, facteur 0,62) ; `Main.gd:435-441` (`_gray_mat`, facteur 0,65) | Oui, approchant | Aucun fichier `.gdshader` (`find` : zéro), deux chaînes `shader_type canvas_item` dans GS. `amt` interpolé en 0,5 s (`CardUI.gd:45-70`, fondu 0,5 s, `BoardUI.gd:1743`). Écarts voulus : poids 0,59/0,11 au lieu de 0,55/0,15 et assombrissement x0,62 que le source n'a pas (réglage sur captures, non vérifié). Compatible WebGL2 / GL Compatibility. | Basse |
| G-27 | `DungeonAdditiveLayer` = `DefaultLayers.Additive` (`CustomLayers.cs:16`), `AdditiveLayer` (`DBMBaseScene.cs:88`), halo additif du boss (`DungeonFrameEntity.cs:54-78,280-290,530-572`) | Mode de fusion | Oui | `BoardUI.gd:2492` (`CanvasItemMaterial.BLEND_MODE_ADD`), GA/ui/characters/*_glow.webp | Oui | Le glow est dans l'atlas `hero_characters` et `_character_glow` (webp présents). Les autres couches Additive de l'APK sont un seul `RegisterLayer`. | — |
| G-28 | `DBMGameProject.Common.Layers` (9 classes : Carousel, Dungeon{Top,Bottom}Scissor, SidePanel, SpellBattle, TimeBar, TopCards, VirtualScreenAlphaScissor, CustomLayers) | Couches et ordre de dessin | Oui, par équivalent | `z_index`/ordre des enfants dans `BoardUI.gd` (ex. `:1294` découpe au couloir) | Non vérifié en détail | Le détail de chaque couche (scissor, draw order) relève du module 7 et n'a pas été recontrôlé ici. Godot n'a pas de couches nommées ; c'est l'ordre des nœuds et `clip_contents`. | — |
| G-29 | `ParticlesFactory.CreateBackParticles` et `ParticleSystemRenderer2D` | Système de particules | Oui | `ApkParticles.gd` (CPUParticles2D, 133 particules, vie 1,5-3 s, coté 4-24 px, texture `particle_01.webp` 19 x 19) | Oui | Portage détaillé (constantes tracées au source). CPU volontairement, pas de GPUParticles en export web sans threads. | — |
| G-30 | Résolution virtuelle `VIEWPORT_WIDTH = 1440` (`DBMGameProject/Game.cs:26`) | Écran virtuel | Oui | `src/frontend/project.godot:23-27` : 1920 x 1080, `canvas_items`, `keep_aspect` ; `CreditsScreen.gd:5,16` (`DX = 240`) | Oui | Convention x_godot = x_apk + 240 acceptée. Le décalage est appliqué partout où je l'ai vu (`CreditsScreen.gd`, `UiKit`). | — |
| G-31 | `AddressMode.PointClamp` (25 occurrences : `ControlsFactory`, `LoadingScene`, `LevelUpBanner`, `ProgressBarEntity`, `GalleryScene`, `PurchaseScene`, `OnlineAvatarComponent`, `Soul/Wound/RupisLoading`, scènes Tutorial) contre `LinearClamp` (`CardMaterial.cs:175`) | Filtrage de texture | Partiel | `project.godot` : pas de `default_texture_filter` (filtre linéaire par défaut) ; `TutorialOverlay.gd:902,1019,1049` met `TEXTURE_FILTER_NEAREST` ; mipmaps désactivés (`*.webp.import: mipmaps/generate=false`) | Partiel | Le source utilise PointClamp pour ses sprites UI et LinearClamp pour les cartes. Godot garde le linéaire par défaut hors tutoriel. À 1080p tout est à l'échelle 1:1, donc invisible. En fenêtre redimensionnée, `canvas_items` agrandit en linéaire (léger flou, jamais de pixels nets). Compression sans mipmaps : conforme à l'APK. | Basse |
| G-32 | `CreditsScene.cs`, `CreditRollBehavior.cs` | Scène | Oui | `CreditsScreen.gd` (constantes tracées : vitesse 100 px/s, voile 0,7, logo y 170, retard 8,8 s) | Oui | Défilement, voile, logo, pied, glissement. Lit `credits.json` (identique). Non lancé, comportement non rejoué. | — |
| G-33 | Sprites `ui/ingame` de l'atlas INGAME (`ColorFadeBehavior`, `FadeBehavior`) | Fondus | Oui | `CardUI.gd:45-70`, `BoardUI.gd:1573` (fondus 0,5 s linéaires) | Oui | Fondus implémentés en tweens. | — |
| G-34 | `PurchaseScene`, `ExpansionScene`, `InAppPurchaseScene` (assets `expansions`, `buy_now_band`, `blocked_band`...) | Scènes | Partiel | GA/ui/expansions/ (21 webp importés) | Oui, par décision | Magasin retiré (mémoire `project-scope-decisions`). Les assets sont dans le .pck sans usage probable (poids marginal). | — |
| G-35 | `Common/marketItems.json` (référencé par `AppPurchaseService.cs`) | Données | Non (vérifié absent) | — (ni dans APK/Common ni dans GA) | N/A | `assets_coverage.md` §2 : non résolu, absent de l'APK. Sans objet, magasin hors portée. | — |
| G-36 | Contraintes web : GL Compatibility (`project.godot:35-36`), export `src/frontend/godot/build_web/` | Rendu web | Oui | `index.pck` 38 Mo ; `index.wasm` 38 Mo | Oui | CPUParticles et shaders canvas_item (pas de compute) : sans blocage. Assets webp, 91 Mo de sources avant compression, `.pck` 38 Mo (mesuré par `du`). Pas de texture dépassant 4096 x 4096 vérifiée (non mesuré). | — |

### Non vérifié

- Contenu interne des atlas WPK (INGAME, NAVIGATION, TUTORIAL, AVATAR, GRADIENTS, EXPANSIONS) : sprites non recomptés un à un contre les webp. Un sprite isolé manquant n'est pas exclu.
- Calibrage du gris des cartes désactivées (G-26 : facteurs 0,62 et 0,65 contre les captures).
- Couches de découpe et ordre de dessin (G-28), relevant du module 7.
- Origine de `thk025a.webp` (G-09), taille maximale des textures contre la limite WebGL2, rendu réel (Godot non lancé).

### Synthèse du module 11

- **Éléments audités** : 36.
- **Conformes ou sans objet** : 29 (dont 5 N/A : code mort de l'APK ou boutique retirée, et 1 Non vérifié, G-28).
- **Écarts** : 7 — Critique 0, Haute 0, Moyenne 1 (G-20 : barre jaune `progress_yellow` de 5 s sous DONE absente, lié à P-C51), Basse 6 (G-07, G-17, G-18, G-21, G-26, G-31).
- **Données de cartes** : les quatre `data.json` et `ai_info.json` sont identiques octet à octet à l'APK ; toutes les faces de cartes sont présentes.
- **Bloquants web** : aucun. Shaders `canvas_item` seulement (GL Compatibility), particules CPU, pas de GPUParticles.

---

## Module 12 — Export web / perf

Périmètre : démarrage et chargement de l'APK (`Game.cs`, `LoadingScene.cs`, `AndroidActivity.cs`), puis contrôles propres au web sans équivalent APK (« N/A (web) ») : `src/frontend/export_presets.cfg`, `project.godot`, `godot/build_web/`, `deploy/Dockerfile`, `nginx.conf`, `DEPLOYMENT.md`, `docs/HANDOFF.md`, et le travail par image de `BoardUI.gd`, `ApkParticles.gd`, `AudioManager.gd`.

Méthode : un lot en lecture seule (aucun export, aucun profilage). La seule ligne Haute (W-18) a été contre-vérifiée dans `docs/HANDOFF.md:75, 141` : le build web n'a été essayé que dans le navigateur intégré (Chromium) de l'application de bureau.

| ID | Élément source (décompilé) | Type (classe/méthode/asset) | Présent dans Godot ? | Fichier Godot | Équivalent fonctionnel ? | Écart / Commentaire | Priorité |
|---|---|---|---|---|---|---|---|
| W-01 | `LoadingScene.CreateScene` (`DBMGameProject.Scenes.MainMenu/LoadingScene.cs:20-40`) : fond `loading_bg`, sprite d'atlas `Atlas.Loading.loading`, `RupisLoadingBehavior(3, 0.5 s)`. `Game.cs:56` y envoie dès le démarrage. | scène | Partiel | `project.godot` (`boot_splash/image=loading_bg.png`, `fullsize`, `bg_color`) | Partiel | Le fond est repris comme boot splash Godot. Le splash Godot web se montre pendant le chargement du .wasm et du .pck, puis rien de plus : la barre de progression HTML par défaut du shell s'affiche, et l'animation Rupis (3 points) n'existe pas pendant le chargement. | Basse |
| W-02 | `LoadingScene.Start` : `CardAssetService.LoadHeavyAssets()` et `AudioService.LoadAllSounds()` dans un `TaskScheduler`, puis `IntroScene` | chargement asynchrone | Non (vérifié absent) | `grep load_threaded` dans `godot/scripts` : 0 résultat | Différent | Pas de préchargement des cartes ni des sons. Le jeu charge à la demande : `AudioManager.gd:131` (`load(path)` avec cache), `BoardUI.gd:259`, `RulesViewer.gd:85`. Sur le web, chaque première utilisation lit le .pck déjà en mémoire (pas de latence réseau). Le coût est un chargement synchrone de décodage au premier usage. Non mesuré. | Moyenne |
| W-03 | `Game.OnlineSuspend` (`AndroidActivity.cs:95-112`, `OnlineClient.cs:45` : `MaxSuspendedTime` 30 s) : pause en arrière-plan | pause et reprise | Partiel | `BoardUI.gd:3562`, `BoardUI.gd:860-870` | Oui (adapté) | `NOTIFICATION_APPLICATION_FOCUS_OUT` n'annule que le glisser en cours. Dans `_process`, `dt` est borné à 1 s par image pour qu'un onglet en arrière-plan ne vide pas la barre de temps d'un coup. La partie locale n'est pas mise en pause à la perte de focus (le navigateur ralentit `requestAnimationFrame`). Pas d'équivalent au `IsSuspended` sur 30 s : le multijoueur est géré côté serveur (délai de grâce 30 s, HANDOFF). | Basse |
| W-04 | Cadence APK : aucun `TargetFramerate` ni `IsFixedTimeStep` dans le décompilé (`grep` sans résultat) | N/A (web) : cadence | Non vérifié | `project.godot` : pas de `max_fps`, `vsync` ni `low_processor_mode` | Non vérifié | Valeurs par défaut Godot (vsync actif, physique 60 tps). Aucune mesure de fps dans le dépôt. | Basse |
| W-05 | N/A (web) : shell HTML `html/head_include` | script injecté dans la page | Oui | `export_presets.cfg:30` | Sans objet | Le script force `window.isSecureContext = true` et remplace `AudioContext` par une sous-classe qui fournit un faux `audioWorklet.addModule()` quand `audioWorklet` est absent. Intention : permettre à Godot de démarrer en HTTP non sécurisé (LAN `http://192.168.1.98:8090`). Fragile : il masque un vrai contexte non sécurisé, et il écrase la classe globale `AudioContext`. Sans threads, l'audio n'utilise pas le worklet. Vérifié le 2026-10-26 sur le homelab : ce mode n'évite pas le worklet. À chaque son, Godot lève `Failed to create PositionWorklet` (`AudioWorkletNode` impossible, le faux `addModule()` ne charge rien) ; la console se remplit. Effet audible non vérifié. le script ne s'exécute que dans la page. À reconfirmer à chaque montée de version Godot. Derrière Cloudflare en HTTPS, il est inutile (HTTP-only : inconnu). | Moyenne |
| W-06 | N/A (web) : options d'export | `export_presets.cfg` | Oui | `export_presets.cfg:19-21,29-36` | Oui | `thread_support=false`, donc ni COOP ni COEP requis : `ensureCrossOriginIsolationHeaders=false` (visible dans `GODOT_CONFIG` du `index.html`, ligne 114). `extensions_support=false`. `vram_texture_compression` desktop et mobile à `false` : les textures sont en webp non compressé en VRAM (plus lourd en mémoire GPU, compatible partout). `canvas_resize_policy=2` (adaptatif), `focus_canvas_on_start=true`, PWA désactivé, `custom_html_shell=""`. | — |
| W-07 | N/A (web) : renderer, affichage | `project.godot` | Oui | `project.godot:25-34,38-39` | Oui | `gl_compatibility` (WebGL 2) ; fenêtre 1920×1080 ; `stretch mode=canvas_items`, `aspect=keep_aspect` ; `emulate_touch_from_mouse=true`. Cohérent avec la cible desktop souris. | — |
| W-08 | N/A (web) : taille du build | `index.pck`, `index.wasm` | Oui | `build_web/` | Oui | `index.pck` = 39 392 976 octets, `index.wasm` = 39 514 754 octets, `index.js` = 279 815 octets (`ls -l`). Premier chargement : environ 79 Mo bruts, réduit par gzip pré-calculé (`Dockerfile:15`, `gzip -9k`). Tailles .gz non mesurées (aucun .gz local). Pas de brotli. | Moyenne |
| W-09 | N/A (web) : contenu du pck | filtres d'export | Oui | `export_presets.cfg:11-13` | Oui | `include_filter` explicite (scripts, scènes, data, audio, fonts, ui, cards, apk_cards, rules). `exclude_filter` : `godot/tests/*` et `godot/server/*`. Assets sources : `assets/cards` 47 Mo, `apk_cards` 16 Mo, `rules` 12 Mo, `ui` 9,2 Mo, `audio` 7,0 Mo (`du -sh`). Le .pck de 39 Mo est plus petit que ces sources (webp ré-encodé ou non inclus), mais il date du 17 oct. (voir W-11). Les 12 Mo de `rules` et les 47 Mo de `cards` (wiki) pèsent dans tous les cas. Aucun `.gdignore` hors `.godot/`. | Basse |
| W-10 | N/A (web) : nginx | `deploy/nginx.conf`, `Dockerfile` | Oui | `deploy/nginx.conf`, `deploy/Dockerfile:15-27` | Oui | `gzip_static on` sert `index.wasm.gz`, `index.pck.gz` et `index.js.gz` avec le Content-Type d'origine. `application/wasm` est annoncé comme présent dans `nginx:alpine` ; `DEPLOYMENT.md:75-81` donne la commande de contrôle, je ne l'ai pas exécutée. `Cache-Control: no-cache` + ETag sur tout : revalidation à chaque chargement (304). Pas de COOP ni COEP, inutiles sans threads. Pas de cache long : acceptable. | — |
| W-11 | N/A (web) : fraîcheur du build local | `build_web/` | Oui | `src/frontend/godot/build_web/` | Non | `build_web/` date du 17 oct. 13:40. Dernier commit : 25 oct. 22:33 (`git log -1`). Les scripts modifiés depuis sont nombreux (`find -newer index.pck` : `AI.gd`, `BoardUI.gd`, `Main.gd` et d'autres). Le dossier est ignoré par git (`.gitignore`) et régénéré par le Dockerfile. Le build local est périmé (inoffensif en production) ; la production'est reconstruite par `docker compose --build` (`DEPLOYMENT.md`). | Basse |
| W-12 | N/A (web) : invalidation de cache | `Cache-Control: no-cache` | Oui | `deploy/nginx.conf`, `DEPLOYMENT.md:86-88,119-122` | Oui | Pas de hash dans les noms : le navigateur revalide à chaque chargement. Le risque porte sur les visiteurs de l'ancien déploiement avec service worker (`DEPLOYMENT.md` : recharger deux fois). Le PWA est désactivé dans l'export (`export_presets.cfg:35`). | Basse |
| W-13 | N/A (web) : déblocage audio au premier clic | `AudioManager._input` | Oui | `AudioManager.gd:48,80-87,136-138` | Oui | `_unlocked := not OS.has_feature("web")` ; un clic, une touche ou un toucher débloque la musique mise en attente. Cohérent avec l'autoplay des navigateurs. | — |
| W-14 | N/A (web) : audio, qualité et latence | `AudioManager`, assets audio | Oui | `AudioManager.gd`, `assets/audio/` | Non vérifié | 42 wav et 2 mp3 : `music_dungeon_v3.mp3` 2,8 Mo, `music_main.mp3` 0,7 Mo. Voix SFX en nombre fixe (`VOICES`), vol de la plus ancienne. Aucune écoute humaine (HANDOFF section 9 : lot 1.4). Pas de réglage `audio/driver/output_latency` dans `project.godot`. | Moyenne |
| W-15 | N/A (web) : travail par image | `_process` | Oui | `BoardUI.gd:860`, `ApkParticles.gd:110`, `AudioManager.gd:183` | Oui | `BoardUI._process` : appelle `_tick_warn`, `_drag_tilt`, puis une boucle IA avec `legal_moves` et `AI.pick_move` seulement si timer atteint (> 0,5 s ou 0,2 s). `ApkParticles._process` ne fait que suivre un nœud. `AudioManager` ne tourne que pendant un sting (`set_process(false)` par défaut). 139 occurrences de tween/`create_tween` dans `BoardUI.gd` (4401 lignes), 18 mentions de shader/`ShaderMaterial` dans les scripts. Aucun profilage : risque réel non mesuré. | Basse |
| W-16 | N/A (web) : calcul IA sur le thread principal | `AI.pick_move` | Oui | `BoardUI.gd:~890-900`, `AI.gd` | Non vérifié | Sans threads, une décision IA coûteuse (`legal_moves` + `score_move`) bloque le rendu. Seuil de freeze non mesuré dans un navigateur ; aucune trace dans le dépôt d'une mesure. | Moyenne |
| W-17 | N/A (web) : WebGL 2 | `Engine.getMissingFeatures` | Oui | `build_web/index.html:165-198` | Oui | Le shell standard de Godot affiche un message d'erreur si WebGL 2 ou WebAssembly manque. Pas de texte de repli personnalisé. | Basse |
| W-18 | N/A (web) : navigateurs testés | test réel | Partiel | `docs/HANDOFF.md:75,141` | Non vérifié | Testé seulement dans le navigateur intégré (Chromium) de l'application de bureau. Firefox, Safari et Chrome proprement dit : « not tested ». Essai du 2026-10-26 sur le build déployé (`http://192.168.1.98:8090`, HTTP clair) dans le navigateur intégré (Chrome 152) : WebGL 2 présent, menus, partie solo et clics souris OK ; erreurs audio en boucle (voir W-05). Claude in Chrome n'était pas connecté : Chrome proprement dit reste à faire, comme Firefox et Safari. Safari reste le plus risqué pour WebGL 2 et l'audio ; l'effet du hack `head_include` y est inconnu. | **Haute** |
| W-19 | N/A (web) : clic droit, menu contextuel, plein écran | entrées | Partiel | `OnlineMenus.gd:137,319` (menu contextuel désactivé sur 2 `LineEdit`) | Non vérifié | Aucun code de plein écran (`window_set_mode` : 0 résultat). Pas de gestion explicite du clic droit sur le canvas : le comportement du navigateur reste actif. Zoom de page et perte de focus : couverts seulement par `canvas_resize_policy=2` et par le handler de `BoardUI`. | Basse |
| W-20 | N/A (web) : mobile | tactile | Partiel | `project.godot:36` (`emulate_touch_from_mouse`) | Oui (hors cible) | Cible souris sur desktop (mémoire projet) ; tactile non testé (HANDOFF:141). | Basse |

### Non vérifié

- Tailles des `.gz`, temps de chargement sur une connexion lente, type MIME `application/wasm` servi en production (commande de contrôle dans `DEPLOYMENT.md:75-81`, non exécutée).
- Effet réel du `head_include` en HTTP sur le réseau local et sous Firefox ou Safari.
- Images par seconde, mémoire, durée d'une décision IA dans un navigateur.
- Contenu exact du `.pck` (filtres lus, archive non listée) ; état du `index.html` de production.

### Synthèse du module 12

- **Éléments audités** : 20.
- **Conformes** : 4 (W-06, W-07, W-10, W-13).
- **Écarts** : 16 — Critique 0, Haute 1, Moyenne 5, Basse 10.
  - Haute : W-18, aucun essai hors Chromium (Firefox, Safari, Chrome). C'est un manque de test, pas un défaut prouvé ; Safari est le plus exposé (WebGL2, audio, `head_include`).
  - Moyenne : W-02 (pas de préchargement des cartes et des sons, décodage au premier usage), W-05 (`head_include` force `isSecureContext` et remplace `AudioContext` : fragile à chaque montée de Godot), W-08 (environ 79 Mo bruts au premier chargement, gzip seulement), W-14 (audio web jamais écouté par un humain), W-16 (IA sur le fil principal sans threads, gel non mesuré).
- **Bloquants web prouvés** : aucun. Le build local `build_web/` est périmé (17 oct.), sans effet : la production'est reconstruite par le Dockerfile.

---

## Synthèse générale (2026-10-26)

Comptes refaits par un script sur les lignes des tableaux (une ligne = un élément ; les renvois entre modules comptent dans chaque module).

| # | Module | Lignes | Critique | Haute | Moyenne | Basse | Sans écart |
|---|---|---|---|---|---|---|---|
| 1 | Sauvegarde | 21 | 0 | 0 | 1 | 9 | 11 |
| 2 | Audio | 32 | 0 | 0 | 2 | 9 | 21 |
| 3 | Entrées | 24 | 0 | 0 | 2 | 8 | 14 |
| 4 | UI / menus | 167 | 0 | 0 | 17 | 83 | 67 |
| 5 | Règles (modèle) | 202 | 0 | 5 | 25 | 34 | 138 |
| 6 | IA | 135 | 0 | 1 | 11 | 17 | 106 |
| 7 | Plateau / scènes de jeu | 179 | 0 | 5 | 24 | 53 | 97 |
| 8 | Tutoriel | 71 | 0 | 0 | 3 | 10 | 58 |
| 9 | En ligne | 128 | 0 | 4 | 10 | 32 | 82 |
| 10 | Dépendances Android | 51 | 0 | 0 | 0 | 9 | 42 |
| 11 | Assets / rendu | 36 | 0 | 0 | 1 | 6 | 29 |
| 12 | Export web / perf | 20 | 0 | 1 | 5 | 10 | 4 |
| 13 | Couverture résiduelle | 128 | 0 | 0 | 12 | 16 | 100 |
| | **Total** | **1194** | **0** | **16** | **113** | **296** | **769** |

### Les 16 écarts Haute (à corriger en premier)

| Module | ID | Résumé |
|---|---|---|
| Règles | R-F15 | Freeze : une salle gelée garde ses trésors ; `push_front` sans décaler les effets d'emplacement. |
| Règles | R-F48 | Crushinator puis construction : le +2 se décale. |
| Règles | R-F21 | Soul Harvest retire 1 entrée d'âme d'une épique au lieu de 2. |
| Règles | R-D31 | Tour de construction forcé : sorts de construction et constructions en plus permis. |
| Règles | R-D46 | DealHero : mort immédiate dans la salle courante (APK : différée au slot suivant). À arbitrer. |
| IA | IA-H59 | L'IA hors de son tour n'utilise pas ses capacités à chaque étape de BuildPhase_a. |
| Plateau | P-A10 | Pas de « YOU LOSE » quand tous les humains sont morts à 3-4 joueurs. |
| Plateau | P-B07 | Le cercle d'ordre affiche le niveau au lieu du numéro du joueur. |
| Plateau | P-B09 | Le badge DAMAGE n'additionne que les dégâts imprimés. |
| Plateau | P-B20 | Le compteur de trésors inclut les salles face cachée. |
| Plateau | P-B30 | « ROOM/SPELL DECK x » montre les pioches au lieu des mains adverses. |
| En ligne | N-B08 | Session perdue en partie : plateau figé, aucun message. |
| En ligne | N-B11 | Après une partie, impossible de créer ou rejoindre un salon sans recharger la page. |
| En ligne | N-B15 | Après un seul dépassement de délai, l'IA garde la main sur toutes les décisions. À arbitrer. |
| En ligne | N-B16 | Pose puis reprise en boucle : l'échéance recule sans fin, la table est bloquée. |
| Export web | W-18 | Jamais essayé hors Chromium (Firefox, Safari, Chrome) : manque de test, pas de défaut prouvé. |

### Questions ouvertes pour le propriétaire

- ~~S-11 / N-B01, N-B03 : compter une défaite dès le début d'une partie en ligne, comme l'APK (anti-abandon) ?~~ Réglé : oui (corrigé).
- R-D46 : reproduire la mort différée de DealHero ?
- ~~R-D26 et R-D27 : les limites Kobold / Motivation doivent-elles déborder sur le tour suivant comme l'APK ?~~ Réglé : aligné sur l'APK (corrigé).
- N-B15 : au dépassement de délai, passer seulement la décision expirée (APK) ou laisser l'IA jouer jusqu'au retour du joueur (choix actuel, `PROTOCOL.md:292-294`) ?
- Questions des modules 1 à 4 non encore posées : A-10, A-28 (réglée au module 9 : N-B41), I-05, I-11, U-A70, U-C01.

### Bloquants web

Aucun bloquant prouvé. Points de vigilance : navigateurs hors Chromium non essayés (W-18), shim `head_include` qui force `isSecureContext` et remplace `AudioContext` (W-05, D-51), IA sur le fil principal sans threads (W-16), environ 79 Mo au premier chargement (W-08).

---

## Vérification contre le règlement officiel (2026-10-26)

Sources : `docs/rules/rules.md` (règles de base l.1-134, FAQ avancée l.135-955, guide non officiel l.2363-3924), textes des cartes dans `CardDecks/*/data.json`, et le C# décompilé relu pour chaque point. Les citations clés ont été recontrôlées à la main : `rules.md:128` (salle désactivée), `rules.md:598-601` (Kobold Strike), `rules.md:3843-3846` (mort du héros), `Boss.cs:254` (`GetDungeonTreasures` filtre `IsActive` et `PendingToBeBuilt`), `GameBoard.cs:1213-1217` (seule remise à 1 de `MaxBuildRoomLimit`), `DealHero.cs:42-45`.

| Point | Règlement | APK | Godot | Verdict | Décision proposée |
|---|---|---|---|---|---|
| R-F15 Freeze, trésors | Salle désactivée : 0 dégât, aucun trésor, sans capacité jusqu'à la fin du tour (l.128). | `Boss.cs:254` exclut les emplacements inactifs. | `BossEngine.gd:61-96` ne les exclut pas, et cela sert aussi à l'appât (`BossEngine.gd:220, 249`). | Godot faux (règlement = APK). L'appât est faussé, pas seulement l'affichage. | Corriger. |
| R-F15 décalage au `push_front` | Muet (pas de notion d'index). | Emplacements fixes : le gel reste sur sa salle. | `Match.gd:556-560` ne décale pas `deactivatedRooms` ni `roomDamageBonus` hors wiki. | Godot faux (APK fait foi). | Corriger avec `TnlAbilities.insert_slot` dans les deux branches. |
| R-F48 Crushinator | +2 à toutes les autres salles actives, y compris celles révélées plus tard dans le tour (l.845-846, 3875-3879). | `DealDamageToDungeon.cs` : +2 sur les 5 emplacements, vides compris. | +2 posé sur les index existants, puis décalé par le `push_front`. | Godot faux (règlement = APK). | Corriger. |
| R-F21 Soul Harvest | Une Épique vaut 2 âmes (l.51) ; la carte retire un héros entier. | `GameBoard.cs:694-731` retire l'objet héros : −2 âmes pour une Épique. | `SpellEffects.gd:245-264` retire 1 entrée sur 2. | Godot faux (règlement = APK). | Corriger. |
| R-D31 tour forcé | Sorts Build seulement avant la révélation ; aucun sort ni capacité à la révélation (l.162-164, 211) ; Construction Zone agit après la révélation (l.387-390). | `DuringPhase.cs` : Build = `BuildPhase_a` seulement ; `Boss.cs:262-263` limite à la carte imposée. | `Match.gd:273, 296-305` propose sorts Build et constructions en plus pendant `forcedBuild`. | Godot faux (règlement = APK). | Corriger. |
| R-D46 DealHero | Le héros meurt dès que ses PV tombent à 0 et qu'il quitte la salle courante (l.3843-3846). | `DealHero.cs:42-45` ne teste pas la mort ; le héros passe à la salle suivante, en subit les dégâts et la déclenche (`GameBoard.cs:1112-1149`). | Mort immédiate dans la salle courante (`Match.gd:1758-1776`). | L'APK s'écarte du règlement ; Godot suit le règlement. | Au choix du propriétaire : clone exact = reproduire l'APK. |
| R-D26 Kobold Strike | « for the rest of the turn » (l.598-601), texte de carte « this turn ». | Limite 0 pour tous ; remise à 1 dans `DeactivateLastActivePlayer` (`GameBoard.cs:1215`), à la fin du tour de construction du joueur et pour chaque joueur au début de l'aventure (`ChooseNextActivePlayer`, `GameBoard.cs:1196`, phase `AdventurePhase_a`). La limite ne survit qu'au reste de la phase de construction. | Avant : `buildBlocked` expirait au tour suivant. Corrigé le 2026-10-26 : `player.buildLimit`, remis à 1 en fin de tour de construction et au début de l'aventure. | Godot aligné sur l'APK. Correction de l'audit : l'APK ne reporte pas la limite au tour suivant. | Fait. |
| R-D27 Motivation | « build an extra room this turn » (l.659-663). | `BuildExtraRoom.cs` : `MaxBuildRoomLimit++`, même remise à 1 que R-D26. | Corrigé le 2026-10-26 : `buildLimit` incrémenté, `extraBuild` supprimé. | Godot aligné sur l'APK ; pas de report au tour suivant. | Fait. |
| IA-H59 IA hors de son tour | Les non-actifs peuvent jouer sorts Build et capacités pendant la phase, l'actif a la priorité (l.97, 157-159, 202-203). | L'IA tente `UseAbility` à chaque étape (`AIPlayerInteraction.cs:86-101`). | Aucune action d'IA hors de son tour (`Match.gd:263-267`). | Godot plus restrictif que le règlement et que l'APK. | Corriger (politique d'IA, pas une règle violée). |
| P-A10 « YOU LOSE » | 5 blessures = défaite (l.251) ; rien sur l'écran. | Écran de défaite en fin de tour si tous les humains sont morts (`GamePlayBaseScene.cs:1071-1078`). | Écran seulement sur `gameOver`. | Règlement muet, l'APK fait foi. | Corriger. |
| P-B09 badge DAMAGE | Muet (affichage). | Somme des dégâts modifiés (`AIHelper.cs:95-110`). | Somme des dégâts imprimés. | Règlement muet, l'APK fait foi. | Corriger avec `room_damage_with_modifiers`. |
| P-B20 compteur de trésors | Salles face cachée : information cachée (l.78, 98), révélées avant l'appât (l.205, 212-214) ; salle gelée : aucun trésor (l.128). | Exclut face cachée et inactives (`Boss.cs:254`). | Compte tout. Le compteur dévoile un trésor caché de l'adversaire ; l'appât n'est faussé que par le gel (R-F15). | Godot faux (règlement = APK). | Corriger en même temps que R-F15. |
| S-11 défaite en ligne | Muet. | Défaite comptée au début, annulée à la victoire. | Comptée seulement à la fin. | Règlement muet, l'APK fait foi. | Décision de produit. |
| N-B15 délai dépassé | Muet. | DONE automatique du seul tour de construction. | L'IA joue toutes les décisions suivantes. | Règlement muet, l'APK fait foi. | Décision de produit. |

Bilan : sur 12 lignes de règles et d'affichage, 9 sont des erreurs de Godot, confirmées par le règlement ou, quand il est muet, par l'APK (R-F15 en deux parties, R-F48, R-F21, R-D31, IA-H59, P-A10, P-B09, P-B20). Sur R-D46, l'APK s'écarte du règlement ; sur décision du propriétaire (l'APK fait foi), Godot reproduit l'APK. R-D26 et R-D27 : relecture du C#, l'APK remet la limite à 1 au début de l'aventure, donc pas de report au tour suivant ; l'audit initial se trompait. Le règlement ne dit rien des deux questions en ligne.

---

## Module 13 — Couverture résiduelle (classes jamais citées)

Contrôle par script : sur les 560 classes C# de `apk-original/decompiled/DBMGame/`, 383 étaient citées par les modules 1 à 12. Les 177 autres (70 `DBMGameModel.*`, 107 `DBMGameProject.*`, `WaveEngine.Extensions.*` et `Properties`) sont auditées ici, chacune dans au moins une ligne (les lignes groupées sont signalées dans la colonne Élément). Deux lots en lecture seule, menés pendant que les corrections de règles étaient en cours : les numéros de ligne de `Match.gd`, `BossEngine.gd`, `SpellEffects.gd`, `RoomAbilities.gd` et `CardDB.gd` peuvent avoir glissé.

### 13A — Modèle (`DBMGameModel.*`, 70 classes)

| ID | Élément source (décompilé) | Type (classe/méthode/asset/scène) | Présent dans Godot ? | Fichier Godot | Équivalent fonctionnel ? | Écart / Commentaire | Priorité |
|---|---|---|---|---|---|---|---|
| X-M01 | `ActivationResponseType`, `DBMActivationResponse`, `DBMActivationErrorResponse`, `PlatformType`, `PlatformTypeExtension` (réponses de la validation de code de rachat, e-mails par plateforme) | enums et DTO | Non (vérifié absent) | — : `grep -rniE "ValidateCode\|ValidationURL\|kickstarter\|backer" scripts/*.gd` ne trouve que des « activation de capacité » sans rapport | N/A | Seul consommateur : `UnlockCodeScene.cs:106-153` (accès caché, déjà U-B53). Décision de périmètre : boutique et déblocages supprimés. | — |
| X-M02 | `AISpellTarget` (Player, Enemy, All) | enum | Non (vérifié absent) | `ApkAI.gd:46-57` (seul `ROOM_FACTORS` d'`ai_info.json` est copié) | N/A | Donnée morte côté APK : `AISpellInfo.AIAffects` n'est lu nulle part et `CardInfoService.GetAISpellInfo` (l.252) n'a aucun appelant (grep). Les valeurs Player/Enemy/All de `ai_info.json` ne servent donc à rien. | — |
| X-M03 | `AbilityInfo` (CanAvoid, Trigger, Conditions, Effects) | classe d'info | Oui (autre forme) | `cards.json` : `levelUp{canAvoid,trigger,targets,cmd,args}` pour 10 bosses, `heroAbility` pour 2 héros ; le reste codé par id (RA:169-179, SE:53) | Oui | Godot ne lit pas Trigger/Conditions/Effects en données : tout est du code par carte. 31/31 salles, 18 sorts, 15 bosses de `data.json` sont présents dans `cards.json`, quantités, trésors, dégâts, catégorie de sort identiques (script de comparaison, 0 écart hors THK025). | — |
| X-M04 | `AbilityInfo.CanAvoid` passé à `ResolveTarget(…, canBeCanceled)` (`AbilityTransaction.cs:205`) ; `ResolveTarget` autorésout d'abord (`PlayerInteractionBase.cs:37-41`, `tryToAutoresolveTargets=true` pour Human et Remote) | champ + méthode | Partiel | RA:929-945 (KSA004), RA:920-928 (KSA003) : le choix est toujours ouvert avec `optional=true` ; M:218 ajoute l'option « passer » | **Différent** | Cartes APK avec `CanAvoid=true` : KSA003, KSA004, KSA007 (+ BMA033, jamais distribuée). `HeroInScorekeep` est un `ComposedTargetProvider` (`ComposedTargetProvider.cs` `TryToAutoresolve`) : un seul candidat (1 adversaire, 1 héros ordinaire mort) est pris d'office, sans annulation possible. Godot ouvre quand même un choix avec « passer ». Idem KSA003 s'il ne reste qu'un sort dans la pioche. Elicon (BossOwner seul) est bien appliqué sans choix (RA:917-919). Fichier [flux]. | Corrigé (Moyenne) |
| X-M05 | `BossInfo` : XP, IsMale, LevelUpAbility | classe d'info | Oui | XP : `cards.json` bosses (15/15 égaux). IsMale : `AudioManager.gd:33,227` (`BOSS_FEMALE` = BMA006-008 + KSA001-007, identique aux 10 `IsMale=false`). LevelUp : RA:886-912 | Oui | Les 8 bosses de base sont codés par id (RA:896-903), les 7 KSA lus dans `levelUp` (RA:906-910). | — |
| X-M06 | `BossInfo.CharacterOffset` (X -40..110, Y 260..320 par boss ; `DungeonFrameEntity.cs:540-549` : marge droite = 720 + X + 211, `LocalY = Y`) | champ + positionnement | Non (vérifié absent) | `grep -rniE "characteroffset\|character_offset\|\"offset\"" scripts data/cards.json tools/*.py` = 0. Godot centre le sprite sur l'estrade : BoardUI.gd:1546-1600 (taille/position :1594-1596, constantes :89-90) | Différent | Le décalage propre à chaque boss n'est pas repris. Un sprite large (KSA005, 333 px) est réduit à 300 px (BoardUI.gd:90) alors que l'APK ne le réduit pas. Écart visuel jamais mesuré par capture : non vérifié pixel par pixel. | Moyenne |
| X-M07 | `CreditInfo`, `CreditElementInfo`, `CreditParagraphInfo`, `CreditImgInfo` (Path, Shadow, Width, Height, H1, H2, Names, Img, SeparatorImg, Logo, Footer) | classes d'info | Oui | `CreditsScreen.gd:169-248` ; `src/frontend/assets/data/credits.json` | Oui | `cmp` : fichier identique à l'APK. Godot lit Logo, SeparatorImg, H1, Paragraph.H2/Names, Footer.H2/Img. Non lus : `Shadow` et `Paragraph.Img`, mais absents des données (grep -i shadow = 0 ; un seul `Img`, dans le Footer, l.208). | — |
| X-M08 | `EffectInfo` (Targets, Commands) et `TypeParametersPair` (TypeName, Parameters) | classes d'info | Oui (aplati) | `cards.json` `levelUp.targets/cmd/args`, `heroAbility` ; sinon RA:169-179 | Oui | Les Parameters ne servent que quand le code en a besoin (`args[0]` de Scythe, Jarin, T.P.K. : BE:478, CD:225-257). Pas de lecture générique. | — |
| X-M09 | `GameDecks` (None, BaseDeck, PowerUpPack, PlayerChoice, ToolsHeroKind, HiddenHeros) | enum | Oui | M:13-17 (`APK_SETS`), Main.gd:10-22 et :99-106 | Oui (écart assumé) | `GetAvailableDecks` exclut PowerUpPack, ToolsHeroKind, None (`CardInfoService.cs:58-65`) et `LocalMarket.cs:108-130` les marque « COMING SOON ». Godot expose « tools » derrière la case wiki (`WIKI_GATED`). PowerUpPack n'a pas de `data.json`. Hidden Heroes : 41 héros dans les données (le libellé « 40 » est marketing). Déblocage `WinsToUnlock=40` supprimé (décision de périmètre). | — |
| X-M10 | `HeroInfo` : HeroType, Health, Wounds, Souls | classe d'info | Oui | `cards.json` heroes : `epic`, `hp`, `wounds`, `souls` | Oui | 85/85 héros APK recoupés (PV, blessures, âmes, épique = `HeroType==1`) : 0 écart. `MinimumPlayers` : `playerCount`, filtre M:100-102. | — |
| X-M11 | `HeroInfo.HasStar` (3 vrais : KSA014, KSA016, KSA017) | champ | Non (vérifié absent) | `cards.json` : `star` seulement sur KSA015 (wiki) ; ThkAbilities.gd:85 | N/A | `HasStar` n'est lu par aucun code APK (`grep -rn HasStar` : la seule occurrence est la déclaration). Aucune règle ni rendu concerné. | — |
| X-M12 | `HeroInfo.LuredCondition` + `BaseLuredCondition.GetBoss` (un seul gagnant sinon `null`) + `LuredByTreasures/FewerSouls/Wounds` | champ + classe de base | Oui | BE:179-248 (`lure_target` : égalité = -1, joueurs éliminés ignorés), CD:270-279 (`hero_lure`, `hero_treasures`) | Oui | 85/85 recoupés : LuredByTreasures 82, FewerSouls 2 (BMA080/BMH080), Wounds 1 (KSA014), et `treasures` égaux aux trésors APK. Égalité (y compris tout le monde à 0) : le héros reste en ville des deux côtés. Fichier [flux]. | — |
| X-M13 | `HeroInfo.Ability` (2 héros : KSA016 `HeroResistDamageRoomType`, KSA017 `DeactivateDungeonAbility`) | champ | Oui | `cards.json` `heroAbility` ; BE:344-350 et :491-496 | Oui (lecture) | C# `GB:1139` : dégâts = -(total de la salle) + `Number` si type de salle identique et total non nul ; Godot `dmg -= 1` si `dmg != 0` et type égal. KSA016 jamais isolé par l'oracle (R-F68). | — |
| X-M14 | `IPassiveDamageCommand` (`DealDamageToRoom`, `HeroResistDamageRoomType`, `LastRoomDealDamage`, `RoomDamageEqualToCount`) ; `Ability.IsPassiveType` (Ability.cs:267) | interface | Oui | BE:384-505 (BMA020 :413, KSA005 :478-483, KSA016 :491-496) ; M:38-46 `ACTIVATABLE_ROOMS` | Oui | Cartes : BMA015, 029, 040, 047 (dégâts), BMA020, KSA005, KSA016. Sur les données, « Trigger nul et commande non passive » donne exactement BMA009, 013, 024, 025, 027, 028, 030, 032, 038, 039 ; Godot = les 9 de `ACTIVATABLE_ROOMS` + BMA025 en branche séparée (M:1607). KSA005 jamais tiré en oracle. | — |
| X-M15 | `IPassiveScorekeepCommand` (`AddSoulsToBoss`, `AddSoulsToBossIfTreasures`) | interface | Oui | CD:225-257 | Oui | KSA006 (3 occurrences oracle) et KSA013 T.P.K. (2). T.P.K. juge le scorekeeping de `BossOwner` d'un sort = `FromPlayer` de la transaction (`GB:211-250`) ; ST:146-153 ne propose que le lanceur à l'humain. | — |
| X-M16 | `IPassiveTreasureCommand` (`AddTreasuresToDungeon`) | interface | Oui | BE:61-86 | Oui (lecture) | KSA001 Kirax : jamais tiré (R-F59). | — |
| X-M17 | `IUndoableCommand` (`DeactivateDungeonAbility`), appelé par `GB:697` à la sortie du héros | interface | Oui | BE:344-350 ; RA:141-142 | Oui | KSA017 : oracle 4×. | — |
| X-M18 | `IUntilEndOfGameCommand` (T.P.K., Jarin, Kirax) ; `GB:791` retire le sort du jeu | interface | Oui | SE:416-427 (`_tpk`) ; CD:225-257 | Oui | Le sort quitte la défausse (`pile.rfind`) et reste chez le lanceur. | — |
| X-M19 | `BaseCommand` (Execute, Undo, Clear, SetTarget, `[RequiredTarget]`, ShallowCopy) | classe de base | Non (par conception) | — ; équivalent : `RA.activate_room_ability` (RA:128-181), `SE.cast_spell` (SE:53) | N/A | Aucun objet commande : tout est du code par carte. La réflexion `RequiredTarget` ne sert qu'à compter les cibles pour l'interface. | — |
| X-M20 | `DiscardTargetRoomFromHand` (BMA013 Dracolich Lair, BMA024 Witch's Kitchen) → `GB.DiscardFromHand` | commande | Oui | RA:428-447 (`dracolich_discard`), RA:519-533 (`kitchen_discard`) | Oui | Même ordre qu'en C# : cibles de la défausse résolues AVANT de défausser. Oracle : 50× (17) et 20× (7). Imp Hoard (RMB017) appelé. | — |
| X-M21 | `DiscardTargetSpellFromHand` (BMA025 All-Seeing Eye) | commande | Oui | RA:208-222, :270 | Oui | Un seul sort en main : défausse automatique. | — |
| X-M22 | `GB.DiscardFromHand` (l.605, 617) et `GB.DestroyRoom` (l.841) : `DiscardPile*.Sort()` par `UniqueID` à chaque ajout | effet de bord | Non (vérifié absent) | `grep "sort" BossEngine.gd CardDB.gd RoomAbilities.gd` : aucun tri de `roomDiscard` ou `spellDiscard` ; `ApkAI.gd:627-630` (`_discard_rank` = `_oid`, harnais seulement) | **Différent** | Les défausses ne sont pas triées. Les listes de choix (Dark Altar, Open Grave, Dracolich, Monstrous Monument…) apparaissent dans l'ordre d'insertion au lieu de l'ordre de carte de l'APK. Les égalités de valeur de l'IA (`_chk_009`, `_chk_013` : `_discard_rank`) se départagent aussi différemment hors harnais. Même cause que R-D14 (« sans effet », jugé sur le mélange seulement). | Moyenne |
| X-M23 | `IBuildRestrictionCommand` / `CannotBuildRoom` (BMA018 Neanderthal Cave), `DungeonSlot.cs:94` | interface | Oui | BE:145-162 (refus des seules salles avancées) | Oui | `Advanced` + `Any` : les ordinaires se bâtissent dessus, les avancées non. L'APK ne regarde ni gel ni verrou, Godot non plus (seul `no_text` TNL). Fichier [flux]. | — |
| X-M24 | `BaseCondition` + conditions utilisées (`DuringPhase`, `OncePerTurn`, `OpponnentDungeonSizeMoreThan`, `HasPendingRoomToBuild`) | classe de base | Oui (par carte) | CD:304-326 (`SPELL_PHASE`), RA:125 et :167 (`ONCE_PER_TURN`), ST:392-394 | Oui | Voir X-M36 pour les phases. | — |
| X-M25 | `BaseTargetProvider` (UniqueID, TargetsAmount, `MinTargetsAmount`, `NeedPlayerIteraction`, `HasSecretValues`, `HasOnboardVisibleTargets`) | classe de base | Non (par conception) | `ApkParityTrace.gd:1185` (usage de `targetId` côté harnais) | N/A | `HasSecretValues` n'est lu que dans `Targets/` (grep) : sans effet. `ViewFilter.gd:73-77` masque déjà les choix d'un autre joueur. | — |
| X-M26 | `SingleTargetProvider.TryToAutoresolve` | classe | Oui (au cas par cas) | RA:216-217, :501-517 | Oui | Auto-résolution d'une cible unique (Kitchen, Dark Altar, Draculord). Voir X-M04 pour l'exception. | — |
| X-M27 | `ComposedTargetProvider` (CleanEmptyValues, `GetAvailableTargets`, `TryToAutoresolve`) | classe | Oui (au cas par cas) | RA:404-447, RA:955-1005 | Partiel | `CheckConditions` (`Ability.cs:117-118`) exige au moins un propriétaire avec `Min` cartes : Godot refuse Dracolich si moins de 2 salles en main ou défausse vide (RA:411-415). | — |
| X-M28 | `BossOwner` (35 occurrences : 15 bosses, sorts et salles de pioche) | cible | Oui (implicite : `player_id`) | RA:ensemble, SE:46-47 `_target_id` | Oui | Pour un sort, `GetOwnerPlayer(spell)` renvoie le `FromPlayer` de la transaction en attente (`GB:229-243`) : Godot passe `caster_id`. Oracle : 24 traces, 0 écart. | — |
| X-M29 | `BossDungeon` (KSA002 Hellcow : `["False","5","Any","Any","Any"]`, `HasOnboardVisibleTargets=false`) | cible | Oui | RA:955-1005, M:974-989 (`rearrange-dungeon`) | Oui | Joueur `Any` = tous les donjons non éliminés ; Godot exige que TOUT le donjon soit ciblable (`_rearrangeable`, RA:987-996), équivalent à `Target1.Count == DungeonSize` (`RearrangeDungeon.cs`). Oracle 1× (1). | — |
| X-M30 | `BossDungeon` / `RearrangeDungeon` : cibles calculées dans `RevealAllRoomCards` (`GB:928-967` ; `EnqueueAbilityTransaction` résout tout de suite, GB:1317-1331) | cas limite | Non vérifié | M:1455-1500 (`_build_reveal_queue` met `faceDown=false` pour tous avant tout level-up) | Non vérifié | À l'instant du level-up de Hellcow, l'APK exclut les emplacements encore en attente des joueurs traités après lui (`!slot.PendingToBeBuilt`) et compare à `DungeonSize` (dernier emplacement non en attente). Godot a déjà tout révélé. Seul un adversaire qui construit le même tour, joueur de rang plus bas, serait touché. Je n'ai ni reproduit ni mesuré. Fichiers [flux]. | Moyenne (à confirmer) |
| X-M31 | `HeroInThisRoom` (BMA017, BMA027, BMA028 ; paramètres `["Any","Owner"]` ignorés) | cible | Oui | RA:22-28 (`hero_is_in_room`), RA:306-316, RA:328-340 ; M:1948-1951 | Oui | C# : héros de l'`EntranceQueue` dont `InsideDungeonSlot` est le slot de la salle ; Godot : `adventure.playerId` et `roomIndex`. Oracle : BMA017 10× (4), BMA027 16× (12), BMA028 3× (3). Mort différée de Boulder Ramp : voir R-D46. | — |
| X-M32 | `RoomInHand` — Dracolich Lair (`["True","2","Any","Any","Owner"]`) | cible | Oui | RA:404-426 | Partiel | Même condition d'usage (2 salles en main ET 1 en défausse). Écart d'interface : avec exactement 2 salles, l'APK autorésout (`enumerable.Count() <= TargetsAmount`) alors que Godot ouvre toujours un choix de paires, parfois à une seule option. Affichage du popup non vérifié en jeu. | Basse |
| X-M33 | `RoomInHand` — Witch's Kitchen (`["False","1","Any","Monster","Owner"]`) + `BossOwner` | cible | Oui | RA:501-533 | Oui | `RoomType.ToString()` Monster/Trap ↔ `type == "monster"` : 35/35 types de salles APK recoupés. Une seule Monster : défausse automatique. | — |
| X-M34 | `OncePerTurn` posé à l'exécution (`Ability.cs:135`) | cas limite | Partiel | RA:167 pose `usedThisTurn`, RA:180 ne remet à faux que pour « no activated ability » | Partiel | `_witchs_kitchen` (RA:501-507) et `_all_seeing_eye` (RA:208-215) retournent une erreur SANS remettre `usedThisTurn=false` (Dracolich le fait, RA:414). Inatteignable : `legal_moves` sonde sur copie (M:327-330) et le serveur n'accepte que des coups de `legal_moves`. R-E29 dit à tort que RA:180 couvre tous les échecs. | Basse |
| X-M35 | `AtTheBeginingOfYourTurn` (BMA023 seule) et `BaseTrigger` | déclencheur | Oui | RA:95-100 (`can_choose_draw`), M:1213-1236 | Oui (chemin mort) | BMA023 est dans `notInGameCards` (`CardInfoService.cs:19,184`) : jamais distribuée, M:70-71 aussi. Golden seulement. | — |
| X-M36 | `GamePhases` (Adventure, Build) + `DuringPhase.cs` (Build = `BuildPhase_a` seule ; Adventure = `AdventurePhase_a/b/c`) | enum | Oui | CD:304-326 ; RA:162-165 (BMA030) ; PHASE `CardDB.gd:6-14` | Oui | 13 cartes `DuringPhase` recoupées : BMA040, 041, 042, 044, 045, 047, 053, 054 en Adventure ; BMA049, 050, 051, 055, 030 en Build. Les 12 sorts de `SPELL_PHASE` concordent. Les valeurs numériques de l'enum ne servent pas (`Enum.Parse` par nom). | — |
| X-M37 | `HeroTypes` (Any, Ordinary, Epic) et `HeroInfo.HeroTypes` (Ordinary=0, Epic=1) | enum | Oui | `cards.json` `epic` ; RA:929-936 (KSA004 filtre `not epic`) | Oui | 85/85 recoupés. | — |
| X-M38 | `RoomTypes` (Any, Monster, Trap) | enum | Oui | `cards.json` `type` | Oui | Comparaison par `ToString()` en C#, par chaîne en Godot. | — |
| X-M39 | `RoomLevels` (Any, Advanced, Ordinary) | enum | Oui | BE:145-162 ; RA:404-426 | Oui | Valeurs APK utilisées : Any (Dracolich, Kitchen, Exhaustion), Advanced (BMA018, King Croak, Cleopatra). | — |
| X-M40 | `PlayerTypes` (Any, Opponent, Opponents, Owner) | enum | Oui | ST:140-161 | Oui | `Opponents` n'apparaît dans aucun `data.json` (grep = 0). | — |
| X-M41 | `DeckTypes` (Any, BoardDeck, DiscardPile) | enum | Oui | RA:920-928 (BoardDeck), RA:31-60 (DiscardPile) | Oui | Seules valeurs utilisées par les données : DiscardPile ×5, BoardDeck ×1 (KSA003). | — |
| X-M42 | `HeroStates` (Any, Dead, Alive) | enum | Oui | ST:171-185 (Dead = `souls`) | Oui | Alive n'est utilisé que par BMA014 (Owner, Alive = `WoundsHeroes`). | — |
| X-M43 | `CardStates` (FaceUp, FaceDown) | enum | Oui | `CardDB.gd` `soul_entry` (`faceDown: true`) | Oui | `FaceDown` ×2 (BMA008 Gorgona, KSA004). | — |
| X-M44 | `CardTypes` (Any, Room, Spell) | enum | Oui | `CardDB.draw_pile(…,"rooms"/"spells")` | Oui | Paramètres `Spell` / `Room` de `DrawCards` (BMA005, 016, 019, 021, 022, 024, 026, 031…). | — |
| X-M45 | `ItemStates` (Any, Attached, UnAttached) | enum | Non (vérifié absent) | — | N/A | Utilisé seulement par `ItemInTown`, jamais référencé par un `data.json` APK (grep = 0). | — |
| X-M46 | `RequiredParameter`, `RequiredTarget` (attributs de réflexion) | attributs | Non (par conception) | — | N/A | Servent à compter les cibles et à sérialiser côté réseau Photon. | — |
| X-M47 | `GameBoardFlowLogger` (`LogInitialization` `[Conditional("TESTING")][Conditional("WINDOWS")]`, `Save()` vide) | classe | Non (par conception) | `ApkParityTrace.gd` (rejeu de traces oracle) | N/A | `LogInitialization` n'a aucun appelant dans le code décompilé : `initialized` reste faux, tous les `Instance.X` sont inertes dans l'APK livré. | — |
| X-M48 | `ActionBase` (NextStep, ByBoss) | classe de base | Non (par conception) | `ApkParityTrace.gd:783-803` | N/A | Enregistrements de rejeu, aucun texte ni format de journal. Le journal texte de l'APK est `LogService.LogInfo` (par ex. `GB:599` « Discard Room card … »), consultable seulement par les écrans de debug (`GetInfosList`). Les messages `_log` de Godot (M:618, RA:`_log`) n'ont donc aucun libellé APK à respecter. | — |
| X-M49 | `BuildRoomAction`, `UndoBuildRoomAction` | action | Oui | M:`buildRoom`, `undoBuild` ; `ApkParityTrace.gd:787` (buildRoom) ; `PROTOCOL.md:43` | Oui | L'oracle émet `undoBuildRoom` (`TracingAI.cs:32-35`) mais `ApkParityTrace.gd:783-803` ne le traite pas (l'IA de l'APK ne l'emploie pas). | — |
| X-M50 | `PlayRoomAbilityAction`, `PlaySpellAction`, `SetSpellBattleReadyAction` | action | Oui | M:617-634 (`activateRoom`), `playSpell`, `pass` ; `ApkParityTrace.gd:789,801,803` | Oui | `spellBattleReady` ↔ « pass » dans la fenêtre de sorts. | — |
| X-M51 | `ResolverTargetAction`, `ChooseCardTypeToDrawAction`, `DiscardCardsInHandAction` | action | Oui | M:`resolveChoice` (:209-219), `openingDiscard` (:207, :523) ; `ApkParityTrace.gd:228,1151,1163-1185` | Oui | Choix de pioche de BMA023 = `draw-type` (M:1229-1236). | — |
| X-M52 | `CheatDrawRoomOrSpellToHandAction`, `CheatDrawRoomsToHandAction`, `CheatDrawSpellsToHandAction`, `CheatPutHeroInTownAction` | action de debug | Non (vérifié absent) | — | N/A | Appelées uniquement depuis les éléments `DEBUG_ELEM` (`GamePlayBaseScene.cs:423,1114-1133`). Le serveur n'accepte que des coups légaux. | — |
| X-M53 | `ICardInfoService.GetCardInfo<T>` | interface | Oui (autre forme) | `CardDB.gd` (autoload) | Oui | — | — |
| X-M54 | `IOnlineFlowSender` (11 méthodes : FinishUserInteraction, SlowDownModel, DiscardCards, ChooseDeckToDraw, BuildRoom, UndoBuildRoom, PlayCardAbility, DebugDrawCard, DebugPutHeroInTown, SpellBattleReady, ResolvedTarget) | interface | Oui (protocole JSON) | `PROTOCOL.md:19` ; M:189-226 ; M:458-523 | Oui | Équivalents : pass/passBuild, openingDiscard, resolveChoice (dont pioche), buildRoom, undoBuild, activateRoom, playSpell. `SendSlowDownModel` : absent (déjà N-A60/N-B13). Debug : absent par choix. | — |
| X-M55 | `AbilityFactory` (instanciation par nom de type, `FindType` insensible à la casse) | fabrique | Non (par conception) | — ; code par id (RA:169-179, SE:53-75) | N/A | Aucune carte APK n'utilise un TypeName que Godot ne couvre pas par carte. Un TypeName inconnu serait une erreur silencieuse (aucun test ne compare la liste des TypeName). | — |
| X-M56 | `ActionsSequence` (file FIFO d'actions asynchrones, utilisée pour la résolution des cibles `AbilityTransaction.cs:167-215` et le choix de pioche `GB:364`) | classe | Oui (autre forme) | RA:84-92 (`enqueue_pending`), `choiceQueue` ; M:1229-1236 | Oui | L'ordre cible 1 puis cible 2 de Dracolich est reproduit (RA:439-443). | — |
| X-M57 | `ILogicCard`, `LogicCardBase` (UniqueID, CardNumber, Treasures, `GetHashBytes`, `CompareTo`) | classes | Non (par conception) | cartes = `Dictionary` (`id`) | N/A | `GetHashBytes` sert à la détection de désynchronisation entre pairs ; le serveur Godot est autoritaire. `UniqueID` : voir X-M22. | — |
| X-M58 | `LogicCardBase.AlternativeArtId` ← `GameBoardExtensions.cs:170-193` (copie k d'un lot : `n = n % (Alt+1) + 1`) → `CardAssetService.GetFrontCardAsset:209-211` (suffixe a, b…) | champ + choix d'image | Partiel | `CardDB.gd:165-173` ne charge que `<id>.webp` (= `<id>a`, même md5) ; `CardGallery.gd:6-7` gère les arts alternatifs en galerie seulement | **Différent** | En partie, la 2e copie de BMA017, 021, 029 et des sorts BMA040, 042, 053 affiche l'art « b » dans l'APK ; Godot affiche toujours « a » (fichiers `bma0xxb.webp` présents mais non utilisés en jeu). Purement visuel. | Moyenne |
| X-M59 | `LogicStrings` (`NameOrDefault`, gabarits `Target{0}<Hero>`…) | classe | Non (par conception) | — | N/A | Sert aux `ToString()` de commandes (messages de debug). | — |
| X-M60 | `DBMRandom` (copie de `System.Random`) | classe | Non (vérifié absent) | `grep 161803398` dans scripts : 0 ; `Match.gd:54` `rng.randomize()`, `GameManager.gd:26-41` (`TUT_SEED=2832`) | Différent (assumé) | Les mélanges ne reproduisent pas les séquences de l'APK. Tutoriel : les 12 salles, 4 sorts et 2 héros forcés sont identiques à `GameBoardExtensions.cs:174-196` ; seul le reste des pioches diffère (TUT_SEED commenté, GameManager.gd:26). L'oracle utilise le `DBMRandom` d'origine (`tools/apk-oracle/Program.cs`). | Basse |

### 13B — Projet et moteur (`DBMGameProject.*`, `WaveEngine.Extensions.*`, 107 classes)

| ID | Élément source (décompilé) | Type (classe/méthode/asset/scène) | Présent dans Godot ? | Fichier Godot | Équivalent fonctionnel ? | Écart / Commentaire | Priorité |
|---|---|---|---|---|---|---|---|
| X-P01 | `BaseBorderBehavior.cs:9-70` et `BorderStyles.cs:3-10` : états None, Yellow, YellowGlow, Red, GreenGlow, fondu entrant ou sortant à chaque changement (`:59-68`) | classe abstraite + enum | Partiel | `CardUI.gd:82-86`, `BoardUI.gd:3711-3730` | Partiel | Pas d'enum ni de comportement commun : chaque cadre est posé à la main (`set_gold`, `_gold_frame`). Le fondu au changement de style n'est pas vérifié. | Basse |
| X-P02 | `CardBorderBehavior.cs:39-78` : Yellow, YellowGlow (+ particules), Red ; variante `_scaled` ×2,7 si l'échelle du parent ≤ 0,5 (`:31`, `:64-71`) | classe | Oui (partiel) | `CardUI.gd:86`, `BoardUI.gd:1761`, `3679-3704`, `3717`, `4007-4008` | Partiel | Les `_scaled` ne servent qu'aux emplacements (`BoardUI.gd:3679`, `3704`). Les cibles de sort sur petites cartes étirent `card_border_yellow_glow` (390×528) sur la carte (`BoardUI.gd:3715-3717`), et le trait s'amincit au lieu d'utiliser le `_scaled` (152×203, ×2,7). Les 8 assets `card_border_*` existent. | Moyenne |
| X-P03 | `CardBorderBehavior.cs:55-57` : GreenGlow posé sur la salle propriétaire de la capacité en cours de résolution (`TargetResolverBaseSceneBehavior.cs:228`) ; grossissement + boucle `sfx_sparklecard` + particules (`CardStackSlotComponent.cs:309-316`) | état de bordure | Non (vérifié absent) | `BoardUI.gd:2977-2987`, `2996-3007` | Différent | `grep -rn card_border_green src/frontend/godot/scripts` donne 0 résultat, donc l'asset `card_border_green_glow` n'est jamais chargé. Godot applique les particules et le son de boucle aux salles ciblables, pas à la salle source. Contredit en partie P-A44 (marqué Oui). | Moyenne |
| X-P04 | `ChallengerBorderBehavior.cs:7-23` : `challenger_panel_selected_red` ou `_yellow` autour du panneau adverse (`OneOpponentDetail.cs:232`) | classe | Non (vérifié absent) | — | Non | `grep -n "challenger_panel\|selected_red\|selected_yellow" scripts/*.gd` donne 0 résultat. Les assets (229×475) sont dans `assets/ui/ingame/` mais jamais lus. Godot cible le sprite du boss (`BoardUI.gd:2938-2941`), pas le cadre du panneau. | Basse |
| X-P05 | `CollapsedOpponentBorderBehavior.cs:7-23` : `bg_boss_profile_selected_yellow` ou `_red` sur les vignettes (3 à 4 joueurs) ; opacité 1 si joueur actif (`CollapsedOpponentDetail.cs:331-333`) | classe | Non (vérifié absent) | `BoardUI.gd:801-832` | Différent | Même grep, 0 résultat. Les vignettes sont remplacées par des boutons P2, P3… (voir P-B23). Seules les particules du joueur actif sont portées (`BoardUI.gd:824-832`). | Basse |
| X-P06 | `CardShadowBehavior.cs:14-120` : ombre `card_shadow` décalée jusqu'à (40, 70) selon l'échelle (0,37 → 0,5), opacité 0,75, visible pendant le glisser (`CardExtractBehavior.cs:227`) et sur la salle en attente (`CardStackSlotComponent.cs:130`) | comportement + asset | Non (vérifié absent) | — | Non | `grep -rni "card_shadow\|CardShadow" scripts` donne 0 résultat. `find src/frontend/assets -name "card_shadow*"` ne trouve rien (seule une copie importée périmée dans `.godot/imported`). La carte glissée n'a pas d'ombre portée. | Moyenne |
| X-P07 | `CardRotationBehavior.cs:84-131` : inclinaison Y = delta x × 0,005 rad par image, bornée à ±22,5° ; X jamais appliqué ; inversion des ordres d'affichage enfants (`:113-131`) ; carte attirée vers le doigt (18 × dt, `:87-95`) | comportement | Oui (approximé) | `BoardUI.gd:3616-3623`, `3625-3630` | Partiel | Même formule, rendue en largeur × cos(angle) sans perspective 3D. `UseTopTexture` et l'inversion des enfants n'ont pas d'objet en 2D. La carte suit directement la souris. | Basse |
| X-P08 | `CarrouselHorizontalComponent.cs:23-45` : positions ±266 / ±342 / ±380, échelles 0,64 / 0,61 / 0,58 autour de 1,14 ; ordres d'affichage 0,1 à 0,5 ; utilisé par `CardCarrouselEntity` (tirage du boss) | composant | Oui | `BoardUI.gd:91-94`, `1795-1798`, `1866-1877` | Oui | Rapports d'échelle (0,56 / 0,535 / 0,51 contre 0,58 / 0,55 / 0,52) et positions (272 / 342 / 378) mesurés sur les captures, écart ≤ 6 px. Le glisser et les flèches du nombre de joueurs restent absents (voir I-08). | — |
| X-P09 | `CarrouselVerticalComponent.cs:46-61` : colonne verticale (y −700, 0, 140, 175, 210, 245), échelles 1,4 / 1,2 / 1, opacités 0 / 1 / 0,8 / 0,6 / 0,4 / 0 ; zoom de pile via `SlotDetailEntity.cs:77-90` | composant | Non (vérifié absent) | `BoardUI.gd:3433-3450` | Non | Seule la salle du dessus est zoomée, et seulement si elle est activable. Aucune colonne défilante ni dégradé d'opacité. Voir P-C15 ; le glisser vertical est dans I-08. | Moyenne |
| X-P10 | `ExpandBaseBehavior.cs:13-153` : éventail ouvert ou fermé (durée 0,5 s, interpolation des positions et rotations) ; seule sous-classe `OpponentsExpandBehavior`, écran `MultiplayerScene` sans appelant (U-C01) | classe abstraite | Oui (équivalent d'écran) | `OnlineMenus.gd:165-238` | Oui | Chemin mort de l'APK ; Godot l'a reproduit pour PLAY ONLINE / PASS AND PLAY (U-C03). | — |
| X-P11 | `FollowBehavior.cs:8-58` : une entité suit une autre (décalage, copie d'opacité) ; barres de temps (`GamePlayBaseScene.cs:216`, `SpellBattleEntity.cs:33`) et cœur du héros (`HeroCardEntity.cs:75-79`, décalage (0, −150)) | comportement | Oui | `BoardUI.gd:76`, `944-960`, `2412-2417` | Oui | Barre verte placée au-dessus du héros qui traverse, ou de la pile ; cœur du héros à −150 × 0,78 de son sprite. | — |
| X-P12 | `HeartRoomControlRotationBehavior.cs:24-28` : cœur de la salle visible seulement si la rotation Y du parent est dans [−90°, 0°] (moitié de retournement) | comportement | Oui (par construction 2D) | `CardUI.gd:107`, `BoardUI.gd:1866-1877` | Oui | Pas de rotation 3D : le retournement est une échelle X de 1 → 0 → 1 qui échange les textures. Aucun rendu intermédiaire visible à reproduire. | — |
| X-P13 | `RitchTextComponent.cs:33-61` : interligne 6, retour à la ligne manuel via `StringFactory.GetLines` (17 px par majuscule), balises `<rtf>` et mots `#` en or ; seul appelant `BalloonEntity.cs:79` | composant | Oui | `BoardUI.gd:4219` (bulle), `TutorialOverlay.gd:879-889` | Oui | Le seul texte réel de bulle, `DoneHint`, n'a aucun `#` (`TutorialStringFactory.cs:28`), donc pas d'or. Le `#BUILD #A #ROOM` n'est que dans un bouton DEBUG (`GamePlayBaseScene.cs:543`). Godot coupe les lignes à la main (T-A35). Les titres BBCode en or sont portés (`BoardUI.gd:565`, `1216`). | — |
| X-P14 | `SimpleTimerBehavior.cs:6-65` : minuterie répétée ; 5 s pour pulser le bouton DONE (`DoneButtonEntity.cs:106-117`), 3 s pour relancer le halo de capacité (`CardAttributesComponent.cs:328`) | comportement | Partiel | `BoardUI.gd:3463` (3 s), `DungeonSlot.gd:176-179` | Partiel | Halo de capacité 3 s : Oui. Pulsation du bouton DONE toutes les 5 s : absente, voir P-C51 (`grep pulse` ne donne rien sur `btn_pass`). | Basse |
| X-P15 | `TransformEffectBehavior.cs:10-111` : interpolation de position, d'opacité, d'échelle et de rotation | comportement | N/A | — | — | Code mort : `grep -rn TransformEffectBehavior` ne trouve aucun appelant en dehors du fichier. Les Tweens Godot couvrent le besoin. | — |
| X-P16 | `ButtonWithDeckEntity.cs:12-53` : gros bouton à éventail (`big_button`, titre arcadepix ×1,3 centré, texte Bookman, éventail replié à l'appui) ; seul appelant `MultiplayerScene.cs:47,70` (écran mort, U-C01) | entité | Oui (équivalent d'écran) | `OnlineMenus.gd:165-238` | Oui | `big_button` et `big_button_selected` existent dans `assets/ui/buttons/` et `assets/ui/navigation/`. Aucune action requise. | — |
| X-P17 | `HeroCardEntity.cs:42-114` : sprite du héros (y −40), cœur de PV `health_hero_icon` ×2 suivant le héros, cœur de carte `health_hero_buff_icon` (−115, 195) ×1,3 en or, masqué tant que la valeur vaut la PV initiale ; `RefreshHeroHeart` (`:90-114`) | classe | Partiel | `BoardUI.gd:76`, `2395-2417`, `2447-2453` | Partiel | Cœur de PV et cœur « −N » (`health_hero_trans_icon`) : Oui. Cœur de buff sur la carte du héros : absent (`grep health_hero_buff` dans `scripts` ne donne rien). L'asset `health_hero_buff_icon` est aussi absent de `assets/ui/` (`find` vide), alors qu'il est dans `Atlas.cs:65`. `health_room_icon_glow` existe. | Moyenne |
| X-P18 | `LabelAndBackground.cs:16-150` : libellé sur fond centré, largeur estimée par caractère (17 ou 15 px × échelle), `<rtf>` retiré pour le calcul, fondu 0,3 s | entité | Oui (mécanisme Godot) | `UiKit.gd:32-44`, `116` | Oui | `Label` Godot centré par alignement, contour noir 3 px ; la largeur est fournie par le moteur de texte, plus besoin de l'estimation à 15/17 px. Aucune action requise. | — |
| X-P19 | `PurchaseDetailEntity.cs:13-44` : ligne « + N … » de la boutique (or, blanc) | entité | N/A | — | — | Boutique retirée (périmètre). Le contenu reste affiché ailleurs par les fiches d'extensions. | — |
| X-P20 | `UIButtonEntity.cs:32-80` : bouton à deux textures (normal, pressé), `TouchPressed` / `Released` | entité | Oui | `BoardUI.gd:301-312`, `4267-4271` | Oui | `TextureButton` avec `texture_pressed`. `DoneButtonEntity` (pass/done) est couvert par P-B31. | — |
| X-P21 | `UpdatableTextBlock.cs:19-46` : le texte s'estompe (0,25 s) puis réapparaît au changement | entité | Non vérifié | `BoardUI.gd:2412-2417` (étiquette de PV créée avec `_lbl`, aucun fondu) | Non vérifié | Les compteurs de cœur, d'XP et de blessures sont changés par affectation directe. Le fondu ne m'a pas été confirmé sur chaque compteur ; effet visuel mineur. | Basse |
| X-P22 | `TopRightPanelEntity.cs:20-219` : colonne droite 211 px, 2 joueurs = `OneOpponentDetail`, 3 à 4 = `ExpandedOpponentDetail` + `CollapsedOpponentDetail`, `ChallengerDetail`, bouton level up (105, 55), bouton options | entité | Partiel | `BoardUI.gd:433-478`, `480`, `627-635`, `801-832` | Partiel | 2 joueurs : conforme (P-B17). 3 à 4 : vignettes remplacées par `foe_bar` (P-B23), pas de panneau étendu (P-B27). Bouton level up présent. | Moyenne |
| X-P23 | `GamePlayPaPScene.cs:18-203` : hotseat 2 joueurs, boss aléatoires, changement de joueur avec main qui sort puis revient, donjons échangés | scène | Oui | `Main.gd:341-382`, `BoardUI.gd:704-781`, `1175`, `1939-1948` | Partiel | Voir P-A49 à P-A51. Écart connu : en pass and play Godot montre GO / PASS TURN et la main en aventure. Chemin atteignable seulement par `MultiplayerScene` (mort côté APK) ; Godot le propose. | Basse |
| X-P24 | `CardsFactory.cs:16-103` : dos de pioche (BMA009 / BMA041), cartes de test, `CreateInGameCard`, `CreateSlotRoomInGameCard` (échelles Min/Max 0,5) | fabrique | Oui | `CardUI.gd:36`, `100-101`, `BoardUI.gd:1660` | Oui | Dos de carte : `assets/apk_cards/base/back_room.webp`, `back_spell.webp`, `back_boss.webp` existent. Les échelles de carte posée sont reprises (`BoardUI.gd:1665`). | — |
| X-P25 | `CarouselLayer`, `SidePanelLayer`, `SpellBattleLayer`, `TimeBarLayer`, `TopCardsLayer` (`*.cs:5-8`) : couches d'affichage, aucune logique propre, découpées au rectangle virtuel | couches (5 classes) | N/A | — | — | Équivalent Godot : l'ordre d'empilement se règle par `z_index` et l'ordre des nœuds, le rectangle virtuel par le viewport 1920×1080 (`project.godot:23-26`). | — |
| X-P26 | `DungeonTopScissorLayer.cs:9-19` et `DungeonBottomScissorLayer.cs:9-19` : découpe du donjon en haut (y 63, h 437) et en bas (y 500, h 453) | couches (2 classes) | Non (vérifié absent) | `BoardUI.gd:362`, `1307` | Différent | `grep clip_contents` ne trouve que le nœud racine et une bannière. Aucune découpe par donjon : le saut du héros (y −200 puis +400, `BoardUI.gd:2247-2253`) peut déborder du cadre au lieu d'être coupé. | Basse |
| X-P27 | `ScissorAlphaLayer.cs:8-43`, `ScissorAlphaLayer2/3/4` : couche alpha avec test de ciseau | infrastructure WaveEngine (4 classes) | N/A | — | — | Moteur de rendu Wave ; Godot : `clip_contents` ou `Window` (voir X-P26 pour le seul besoin de fond). | — |
| X-P28 | `DBMMenuBaseScene.cs:7-27` : retour = pop de l'écran ; `ShowFullGameUnlockScene` (achat du jeu complet) | scène de base | N/A | — | — | Boutique et déverrouillage retirés (périmètre). Le retour des menus passe par `go()` / flèche dans `Main.gd` et `OnlineMenus.gd`. | — |
| X-P29 | `IHighLight.cs:8-12` : `HighLightCards(cards, style)` et `CleanHighLightCards(style)` ; implémentée par `GamePlayBaseScene`, les piles, les panneaux | interface | Oui | `BoardUI.gd:2944-3010`, `3711-3730` | Partiel | Mécanisme équivalent (cadre doré, rouge, halo). Les styles GreenGlow et des panneaux adverses manquent (X-P03, X-P04, X-P05). | Basse |
| X-P30 | `EntitiesExtensions.cs:12-80` : `IsContainedByEntity` (test de dépôt avec précision ×1,2, `BuildRoomHandSceneBehavior.cs:239`), `ChangeLayer`, `DetachFromOwner`, `FindChildByTag` | helpers | Oui (test de dépôt) | `BoardUI.gd:3694-3695` | Oui | Même zone ×1,2 centrée sur l'emplacement. Les autres helpers (couches, détachement) n'ont pas d'objet dans Godot (`reparent`, `z_index`). | — |
| X-P31 | `ScenesExtensions.cs:10-15` : taille d'une texture d'atlas | helper | N/A | — | — | Godot lit `Texture2D.get_size()` directement. | — |
| X-P32 | `StringExtensions.cs:10-89` : `Truncate` (boss 10 car., sous-titre 25, alias 15, nom 45), `Heigth`, `WordWrap`, `BreakLine` | helpers | Partiel | `OnlineMenus.gd:136`, `318`, `432-433`, `860`, `Profile.gd:16` | Partiel | Troncatures du nom de joueur (45, 25) portées. Pas de troncature du nom de boss (10) ni du sous-titre (25) dans `BoardUI.gd:2144-2163`. Aucun boss du jeu de base ne dépasse ces tailles ; seuls `The Brothers Wise` (17), `Elicon` (sous-titre 31) du deck PlayerChoice. `Heigth` ne sert qu'à la boutique (retirée). | Basse |
| X-P33 | `ViewportManagerExtensions.cs:13-46` : bords utiles du viewport plafonnés à 1920×1080 | helpers | Oui | `project.godot:23-27` | Partiel | `canvas_items` + `keep_aspect` : bandes noires sur écran non 16:9. L'APK étend la zone utile jusqu'au plafond. Écart cosmétique. | Basse |
| X-P34 | `IKindleApplication.cs`, `ISteamApplication.cs` : interfaces vides (stores Amazon et Steam) | interfaces (2) | N/A | — | — | Aucun membre. Portage store non applicable. | — |
| X-P35 | `CustomColors.cs:10-74` : GoldColor #cdb15f, PistachioColor #bfca7a, SidePanelsBackColor #180a18, LoadingBg #270000, TutorialBg #e2bc54, couleurs de trésor des boss (cleric #34495c, fighter #5e2a2f, mage #52506a, thief #74635d), `GetRTFColorString`, `CountTextNotFormat` | constantes + helpers | Partiel | `UiKit.gd:8`, `Main.gd:44`, `CreditsScreen.gd:34`, `BoardUI.gd:99` | Partiel | Or et pistache : Oui (même valeur). `grep` des 6 autres hex et de `Color(0.0` correspondants dans `BoardUI.gd`, `Main.gd`, `UiKit.gd` : aucun trouvé, donc non reconnus. `GetBossTreasureColor` (`OneOpponentDetail.cs`) : non vérifié. Les `<rtf>` sont remplacés par BBCode (`BoardUI.gd:565`). | Basse |
| X-P36 | `Directories.cs:3-19` : chemins `Content/…` | constantes | N/A | — | — | Chemins du pack WPK ; Godot utilise `res://assets/…`. | — |
| X-P37 | `SpeedEnum.cs:3-8` : Slow, Normal, Fast (`SettingsScene`, `GameSettings`) | enum | Oui | `Profile.gd:109-118`, `BoardUI.gd` (`_speed_factor`) | Oui | 0 / 1 / 2 enregistrés ; facteur ×1,5 / ×1 / ×0,5. | — |
| X-P38 | `IExternalInteractionResolver.cs:7-12` (`ChooseCardToDraw`, `ChooseCardsToDiscard`) et `IExternalTargetResolver.cs:6-11` (`ResolveTarget`) ; seul appelant `HumanPlayerInteraction.cs`, `TargetResolverBaseSceneBehavior.cs` | interfaces (2) | Oui (par un autre mécanisme) | `BoardUI.gd:2751-2800`, `3494-3503`, `SpellTargeting.gd` | Oui (ciblage), non vérifié (pioche) | Le ciblage et la défausse passent par la liste de coups légaux (`_target_list`, `_show_discard`). Le choix de pioche (Haunted Library, R-F39) : côté règles Oui, interface de choix non vérifiée. | Basse |
| X-P39 | `IDBMPurchaser.cs`, `DBMPurchaser.cs:44`, `ILocalStorage.cs`, `DefaultLocalStorage.cs:39` : achats intégrés et stockage local de reçus | service (4 classes) | N/A | — | — | Boutique retirée (module 10). | — |
| X-P40 | `Scenes.Test/` : `BacklightTestScene`, `BossSelectionTestScene`, `BubbleTestScene`, `BubblesTestScene`, `DoneTestScene`, `DrawOrderScene`, `FlipCardScene`, `HandBossSwitchTestScene`, `HeartTestScene`, `LabelTestScene`, `LogTestScene`, `NewHandTest`, `NinePatchScene`, `SpellBattleTest` | scènes de débogage (14) | N/A | — | — | Scènes d'essai du développeur, jamais ouvertes depuis le menu (aucun parcours public). Rien à porter. | — |
| X-P41 | `Properties/AssemblyInfo.cs:1-21` | métadonnées d'assemblage | N/A | — | — | Aucune logique. | — |
| X-P42 | `CardRenderer.cs:10-58` : rendu de la carte avec `UseTopTexture` (face ou dos), teinte, retournement horizontal | moteur de rendu | N/A | — | — | Godot affiche la face ou le dos par un échange de texture (`CardUI.gd:191`). | — |
| X-P43 | `TextControlDrawableRenderer.cs:10-83` et `TextDrawableBlock.cs:10-197` : rendu et propriétés du bloc de texte (police, largeur, alignement, riche, interligne) | moteur de texte (2 classes) | N/A | — | — | Équivalent : `Label` / `RichTextLabel` avec `UiKit.label()` (`UiKit.gd:32-44`). | — |
| X-P44 | `DummyRenderer2D.cs:6-15` : rendu vide pour entité à collision seule | infrastructure | N/A | — | — | Godot : un `Control` sans texture reçoit déjà la souris. | — |
| X-P45 | `MovementBehavior.cs:10-101` : déplacement, rotation, échelle animés sur `AnimationUI` | comportement | Oui (par tweens) | `BoardUI.gd:2250-2253`, `CardUI.gd` (`lerp_vers`) | Oui | `create_tween()` / `lerp_vers` pour tous les mouvements. | — |
| X-P46 | `ParticlesParentSizeBehavior.cs:9-34` : émetteur à la taille du parent × échelle (0,9) | comportement | Oui | `ApkParticles.gd:6-9`, `96` | Oui | Constante `ECHELLE` 0,9 identique ; taille d'émission recalculée à chaque changement. | — |
| X-P47 | `ScaleEffectBehavior.cs:10-108` : grossir ou réduire entre Min et Max, durée donnée | comportement | Oui | `CardUI.gd:15`, `252-254` | Oui | `hover_scale` 1,2 + `lerp_vers` ; salle courante agrandie `BoardUI.gd:2231`. | — |
| X-P48 | `SpriteAtlasEnum.cs:7-33`, `SpriteEnum.cs:7-21`, `SpriteRaw.cs:10-28` : sprite choisi par valeur d'enum (`Atlas.InGameGUI.*`) | infrastructure + enums de sprites | Partiel | `assets/ui/` | Partiel | Contrôle des sprites cités par les classes de ce lot : présents `card_border_*` (+ `_scaled`), `challenger_panel_selected_*`, `bg_boss_profile_selected_*`, `health_hero_icon`, `health_hero_trans_icon`, `health_room_icon_glow`, `levelup_bt(_pressed)`, `bg_levelup_panel`, `big_button(_selected)`, `fg_cover_unlocked`. Absents : `card_shadow`, `health_hero_buff_icon`. Inutilisés dans les scripts : `challenger_panel_selected_*`, `bg_boss_profile_selected_*`, `card_border_green_glow(_scaled)`. | Moyenne |
| X-P49 | `ExpandTextureComponent.cs:14-132` : voile plein écran à trou rectangulaire (maillage de 8 sommets), utilisé par `TutorialBaseScene` | rendu | Oui | `TutorialOverlay.gd:6`, `132`, `597-661` | Oui | Voile + rectangles « attachés » dessinés au-dessus (`_holes`). | — |
| X-P50 | `NinePatchRenderer.cs:12-192` : neuf-patch par maillage de 16 sommets | rendu | Oui | `UiKit.gd` (`ninepatch`), `BoardUI.gd:1323`, `OnlineMenus.gd:129`, `578` | Oui | `NinePatchRect` avec marges relevées dans le WPK (ex. 15, 17, 15, 15). 6 textures dans `assets/ui/ninepatch/`. | — |
| X-P51 | `ITasks/` noyau : `ITask`, `ITaskContext`, `ITaskSet`, `TaskBase`, `TaskNode`, `TaskFactory`, `TaskSetOperationSelector`, `BasicTaskToken`, `DeferedTaskNode`, `DeferedTaskNodeBase`, `DeferedContinueWithTask` | framework de tâches (11 classes) | N/A | — | — | Chaînage `ContinueWith`, `WaitAll`, `WaitAny`. Équivalent Godot : `await`, `Tween.chain()` / `parallel()`, `create_timer()`. | — |
| X-P52 | `ITasks/` attentes : `ActionTask`, `ActiveWaitConditionTask`, `WaitTimeTask`, `WaitCountTaskSet`, `WaitCountTaskSetBase`, `WaitCountDeferedTaskSet`, `SingleAnimationTask` | framework de tâches (7 classes) | N/A | — | — | Attente de condition, de durée, de N tâches, animation d'une propriété : `await get_tree().create_timer()`, `Tween`, signaux. | — |
| X-P53 | `VideoTask.cs:10-52` | tâche vidéo | N/A | — | — | Code mort : `CreateVideoTask` (`TaskFactory.cs:205`) n'a aucun appelant (`grep VideoTask`). Aucune vidéo dans Godot (`grep ogv` vide). | — |
| X-P54 | `ScopedTimer.cs:8-195` : minuterie liée à la scène, supprimée à sa fermeture | infrastructure | Oui (par minuteries Godot) | `BoardUI.gd:1901`, `CountDown.gd` | Oui | `get_tree().create_timer()` et `Tween` ; libérés avec le nœud. | — |
| X-P55 | `ScreenContextExtensions.cs:9-26` : liste des scènes d'un contexte | helper | N/A | — | — | Godot : `get_children()` ou `get_tree().get_nodes_in_group()`. | — |
| X-P56 | `ResouceFileAttribute.cs`, `ResouceFilesAttribute.cs`, `ResourceManager.cs:71`, `WPKAssetAttribute.cs` : résolution enum → chemin d'un asset du WPK | infrastructure de ressources (4 classes) | N/A | — | — | Godot charge par chemin `res://assets/…` (`UiKit.tex`, `_tex`). Vérification des chemins : voir X-P48. | — |
| X-P57 | `ImageAtlas.cs:9-157`, `ImageAtlasControl.cs`, `ImageAtlasControlRenderer.cs` : contrôle UI affichant un morceau d'atlas | contrôle UI (3 classes) | Oui | `UiKit.gd` (`image`), `CardUI.gd`, `BoardUI.gd:2412` | Oui | `TextureRect` sur WebP déjà découpés (atlas défait à l'extraction). | — |

### 13C — Classes citées seulement dans un nom plus long (contrôle du 2026-10-26)

Un second contrôle, qui cherche le nom de classe comme mot entier, a trouvé 11 classes et 4 fichiers non C# (plus 2 assemblées d'exécution jamais nommées) que le premier comptait à tort : leur nom n'apparaissait qu'à l'intérieur d'un autre (`Effect` dans `EffectInfo`, `Item` dans `ItemInfo`…). `ScissorAlphaLayer3` et `ScissorAlphaLayer4` sont couverts par X-P27, le shader de fragment par G-26.

| ID | Élément source (décompilé) | Type (classe/méthode/asset/scène) | Présent dans Godot ? | Fichier Godot | Équivalent fonctionnel ? | Écart / Commentaire | Priorité |
|---|---|---|---|---|---|---|---|
| X-R01 | `DBMGameModel.Extensions/Actions.cs` : `EncapsulateCallback` (chaîne deux `Action`, avant ou après ; 5 appels) | extension | Non (par conception) | — | N/A | Plomberie C# de rappels ; Godot chaîne par `Callable` et signaux. Aucun effet de jeu. | — |
| X-R02 | `CardInfo` (`CardNumber`, `Name`, `Subtitle`, `Description`, `Treasures` / `TreasureTypes`, `MinimumPlayers`, `Quantity`, `ReplacesCardNumber`, `AlternativeArts`) | classe de données | Oui | `CardDB.gd:42` (`load_cards` ← `data/cards.json`), `CardDB.gd:77-80` (quantité), `Match.gd:73-79` (`ReplacesCardNumber`, `MinimumPlayers`) | Oui | Champs repris tels quels dans `cards.json` (extraction de `data.json`). `AlternativeArts` : voir X-M58. | — |
| X-R03 | `CardDeckInfo` (Boss / Spell / Room / Hero / ItemCards d'un paquet) | classe de données | Oui | `cards.json` (champ de paquet), `Match.gd:73-79` (paquets actifs) | Oui | Un paquet = un `data.json` de `CardDecks/` ; même découpage par type. | — |
| X-R04 | `RoomInfo` (`IsAdvanced`, `RoomType` Monster/Trap, `Damage`, `RoomCategory`, `Ability`), `SpellInfo`, `ItemInfo` | classes de données | Oui | `cards.json` ; `CardDB.gd:312-321` (`category` des sorts) | Oui | Lus par chaque module de règles (modules 5 et 6). | — |
| X-R05 | `DBMGameModel.Logic/Item.cs` (`Item : LogicCardBase`) | classe | Oui (autre forme) | `ThkAbilities.gd:121-149` (pioche et `add_item`) | Oui | Objet = `Dictionary` comme les autres cartes (voir X-M57). Paquet ToolsHeroKind couvert par la parité oracle (`--decks`). | — |
| X-R06 | `Effect.cs` (`Execute` / `Undo` des commandes, groupes multi-cibles, `SetEffectTarget`) | classe | Oui (autre forme) | `RoomAbilities.gd`, `SpellEffects.gd` (code par carte) ; annulation : `BossEngine.gd:344-350` | Oui | `Undo` n'est appelé que via `Ability.UndoEffect` ← `GameBoard.RemoveHeroFromGame` (GB:697), déjà couvert par X-M17. | — |
| X-R07 | Cible `SpellInHand` (`Number`, `AllRequired`, `PlayerType`) : seule carte APK = BMA024 Witch's Kitchen | fournisseur de cibles | Oui | `RoomAbilities.gd:206`, `292`, `485-533` | Oui | Voir R-F40, X-M20 et IA-H26 (oracle 20×). | — |
| X-R08 | `DBMGameProject.AI/GamePhase.cs` (enum Setup, Early, Mid, Late) | enum | Oui | `ApkAI.gd:62-66` | Oui | Valeurs de `AIHelper.GetGamePhase` (IA-G15). | — |
| X-R09 | `WaveEngine.Extensions/BaseScene.cs` (tâches `RegisterTask`, minuteurs `CreateTimer`, comportements de scène, abonnement tactile, `Pause` / `Resume`) | classe de base de scène | Oui (autre forme) | arbre de scènes Godot, `Timer` / `create_tween` | Oui | Infrastructure moteur. Pause de l'application : sur le web, Godot n'est pas suspendu mais l'onglet masqué est ralenti par le navigateur ; le délai de tour en ligne est tenu par le serveur (`GameRoom.gd`). Non vérifié en jeu. | — |
| X-R10 | `DBMGame.CardEffectvsTexture.vert`, `*.fxo` (shaders compilés DirectX), `DBMGame.csproj` | shader / projet | N/A | — | N/A | Le shader de vertex est trivial ; le fragment est porté (G-26). Les `.fxo` sont les mêmes shaders compilés pour Windows. Le `.csproj` n'est qu'un fichier de projet. | — |
| X-R11 | Assemblées d'exécution `OpenTK`, `OpenTK-1.0`, `Mono.Android`, `mscorlib`, `System.*` (`apk-original/decompiled/`) | bibliothèques de plateforme | N/A | — | N/A | Liaisons OpenGL et runtime Xamarin/.NET d'Android, remplacés par le moteur Godot et l'export web. Les autres assemblées tierces (Photon, Newtonsoft, Xamarin.Insights, facturation, Bepu, Farseer, Zlib) sont traitées au module 10. | — |

### Non vérifié

- X-M30 : Hellcow face à un adversaire dont des salles sont encore en attente au moment du level-up (lu des deux côtés, non reproduit).
- X-M06 : effet visuel de `CharacterOffset` (aucune capture comparée).
- X-M32 : choix de paires de Dracolich quand il n'y a qu'une paire ; X-M22 : ordre réel des défausses à l'écran ; X-M55 : couverture de chaque TypeName (Godot est codé par carte).
- X-P21 (fondu des compteurs), X-P35 (couleurs de trésor des boss), X-P38 (écran de choix de pioche de Haunted Library), X-P01 (fondu au changement de bordure), X-P26 (débordement du saut du héros).

### Synthèse du module 13

- **Classes couvertes** : 177 sur 177, en 128 lignes (13A : 60, 13B : 57, 13C : 11). Avec les modules 1 à 12, **les 560 classes du décompilé et les 5 fichiers non C# de `DBMGame/` sont audités** ; contrôle par mot entier refait le 2026-10-26 (0 classe manquante).
- **Écarts** : 28 — Critique 0, Haute 0, Moyenne 12, Basse 16.
  - Moyenne 13A : X-M04 (Kaw'nee et Rotten Ruins proposent « passer » quand l'APK résout seul), X-M06 (décalage propre à chaque boss absent), X-M22 (défausses non triées par numéro de carte : ordre des choix et égalités de l'IA), X-M30 (Hellcow et salles en attente, à confirmer), X-M58 (deuxième art des cartes en double jamais affiché en partie).
  - Moyenne 13B : X-P02 (bordure étirée sur petites cartes), X-P03 (halo vert de la salle source absent, contredit P-A44), X-P06 (ombre de carte glissée absente, sprite `card_shadow` manquant), X-P09 (colonne de pile défilante absente), X-P17 (cœur de buff du héros absent, sprite `health_hero_buff_icon` manquant), X-P22 (panneau adverse à 3-4 joueurs), X-P48 (deux sprites manquants, quatre jamais lus).
- **Correction d'un module précédent** : P-A44 (module 7) est marqué Oui alors que `card_border_green_glow` n'est lu par aucun script (X-P03) ; R-E29 (module 5) suppose à tort que `RoomAbilities.gd:180` couvre tous les échecs de capacité (X-M34, sans effet en jeu).
- **Bloquants web** : aucun.

---

## Corrections des écarts Haute (2026-10-26, non commitées)

Quatre lots, chacun validé par `python tools/run_godot_tests.py` (14/14) et, pour le moteur, par la parité oracle (6/6, 12/12, 6/6). Principe appliqué : l'APK, le règlement officiel et le wiki (extensions) font foi ; Godot s'adapte, bizarreries de l'APK comprises.

| ID | État | Changement |
|---|---|---|
| R-F15 | Corrigé | `BossEngine.dungeon_treasures` ignore les salles gelées et face cachée (`Boss.cs:254`) ; `TnlAbilities.insert_slot` et `remove_slot_effects` appelés hors wiki aussi (les effets restent sur leur salle). |
| R-F48 | Corrigé | Crushinator : bonus +2 aussi sur les emplacements vides (`effects.emptySlotBonus`), repris par la salle construite ensuite. |
| R-F21 | Corrigé | Soul Harvest retire l'entrée ciblée, plus une seule autre entrée du même héros s'il est épique. |
| R-D31 | Corrigé | Phase `EXTRA_BUILD` : pas de sort de construction ni de Jackpot Stash pendant le tour forcé ; la limite par joueur empêche les constructions en plus. |
| R-D46 | Corrigé (APK) | `RoomAbilities.deal_hero` : un héros mis à 0 PV par DealHero passe à la salle suivante et y meurt avec son déclencheur ; sans salle suivante, il meurt sans déclencheur. |
| R-D26, R-D27 | Corrigé | `player.buildLimit` (0 pour Kobold Strike, +1 pour Motivation), remis à 1 en fin de tour de construction et au début de l'aventure, comme `DeactivateLastActivePlayer`. |
| IA-H59 | Corrigé | Les IA non actives jouent leur capacité à chaque pas de construction (`Match._ai_offturn`, `AI.pick_move`, `GameRoom._ai_step`). Non mesurable par l'oracle (accord IA inchangé) ; golden ajouté. |
| P-A10 | Corrigé | Hors ligne : écran « ...YOU LOSE! » quand tous les humains sont éliminés, hors phases boss, appât et aventure. |
| P-B07 | Corrigé | Le cercle d'ordre affiche `Boss.PlayerId` (rang d'XP fixé à la mise en place). |
| P-B09 | Corrigé | Badge DAMAGE = `AIHelper.GetDungeonDamage`, BMA017 compté deux fois comme dans l'APK. |
| P-B20 | Corrigé | Résolu par R-F15 : le compteur n'inclut plus les salles face cachée ni gelées. |
| P-B30 | Corrigé | `x{n}` = salles et sorts en main de l'adversaire ; `ViewFilter` marque `isRoom` sur les dos de cartes. |
| N-B08 | Corrigé | Modale « Connection problem / The connection with the server was lost. » puis retour au menu ; « Reconnecting... » pendant une coupure passagère. |
| N-B11 | Corrigé | Quitter le plateau en ligne envoie `leave` et oublie la session : créer ou rejoindre un salon fonctionne ensuite. |
| N-B15 | Corrigé (APK) | Au délai dépassé, l'IA ne joue que la décision expirée (DONE automatique en construction) ; `auto` permanent seulement pour un joueur parti ou sans liaison. Délai par défaut 70 s (`GamePlayBaseScene.cs:272`). |
| N-B16 | Corrigé | En construction, le délai appartient à la fenêtre de décision : pose et reprise ne le repoussent plus, `resume` non plus. |
| S-11 (N-B01, N-B03) | Corrigé (APK) | Défaite comptée au démarrage de la partie en ligne, annulée en cas de victoire. Victoire par désertion non portée (le siège passe à l'IA). |
| W-18 | Partiel | Navigateur intégré (Chrome 152) sur le homelab le 2026-10-26 : chargement, menus, partie solo à la souris OK ; erreurs AudioWorklet (W-05). Restent Chrome proprement dit, Firefox et Safari. |
| IA-G47 | Ouvert (Moyenne) | L'APK choisit la salle avant de résoudre la capacité ; non corrigé, non mesurable par l'oracle. |

Non vérifié après correction : aucun rendu à l'écran (P-A10, P-B07, P-B09, P-B30, modale en ligne), aucun essai en ligne dans un vrai navigateur. Boulder Ramp, Exhaustion, Soul Harvest sur une Épique et le tour forcé ne sont couverts que par des goldens (aucune trace oracle ne les joue).

## Lot 1a : règles (2026-10-26)

Validé par `python tools/run_godot_tests.py` (14/14) et l'oracle (6/6, 12/12, 6/6).

| ID | État | Changement |
|---|---|---|
| R-E11 | Corrigé | `SpellTargeting._front_hero` : seul le premier héros de chaque entrée est ciblable (`EntranceQueue.Take(1)`), dans `enumerate_targets` et dans l'UI. |
| R-F10, R-F14 | Corrigé | Assassin et Fear : par R-E11. |
| R-F13 | Corrigé | Exhaustion : cibles par R-E11, mort différée par R-D46. |
| R-E30 | Partiel | Autorésolution d'une cible unique faite pour KSA003 et KSA004 ; le reste n'est pas contrôlé. |
| R-F53 | Corrigé | Torture Chamber détruit la salle activée (`room_index` transmis). Golden ajouté. |
| R-F36 | Corrigé | Monster's Ballroom ignore les salles gelées (`slot.IsActive`). Golden ajouté. |
| R-F23 | Corrigé | Trepidation compte `CardDB.total_souls` (âmes passives comprises, comme `Boss.Souls`). Golden ajouté. |
| R-E18 | Corrigé | Kobold Strike ne bloque plus les sorts de la phase de construction (`SkipBuildPhase` ne touche que `MaxBuildRoomLimit`). |
| R-E19 | Corrigé | Liger's Den vérifie le gel et le verrou Trap Master. |
| R-E14 | Corrigé | Robobo n'offre plus de salle gelée. |
| X-M04 | Corrigé | KSA003 et KSA004 : un candidat unique est pris d'office, sans « passer » ; KSA007 était déjà conforme. |
| R-D34 | Corrigé | Fenêtre après la dernière construction : pas de joueur actif, tri de la pile par PlayerId pur. |
| R-D35 | Corrigé | Révélation des salles en attente par indice C# croissant ; level-up quand le dernier emplacement C# est révélé. |
| X-M22 | Ouvert | Trier les défausses par `UniqueID` demande de numéroter les cartes comme `GameBoardExtensions` ; chantier à valider contre l'oracle. |
| R-E29 | Ouvert | Différence visible seulement si une transaction est annulée avant de s'exécuter ; jamais observé. |

Non vérifié : R-D34, R-D35, R-E14, R-E18 et R-E19 portent sur des chemins que l'oracle ne joue presque pas ; seule l'absence de régression est prouvée.
