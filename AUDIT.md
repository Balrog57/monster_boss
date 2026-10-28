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

## Progression Godot vs APK décompilé (2026-10-28)

Bilan des 1 194 lignes des modules 1 à 13, avec le dernier statut consigné dans ce fichier (tableaux d'origine, puis lots de correction 1a–6e). Ces statuts sont ceux écrits par les lots précédents : je ne les ai pas revérifiés ligne par ligne. Seules les mesures du dernier paragraphe ont été relancées le 2026-10-28.

| # | Module | Lignes | Sans écart | Corrigé | Accepté | Conforme | Renvoyé* | Ouvert |
|---|---|---:|---:|---:|---:|---:|---:|---:|
| 1 | Sauvegarde | 21 | 10 | 4 | 5 | 2 | 0 | 0 |
| 2 | Audio | 32 | 21 | 7 | 1 | 3 | 0 | 0 |
| 3 | Entrées | 24 | 10 | 8 | 3 | 3 | 0 | 0 |
| 4 | UI / menus | 167 | 67 | 55 | 29 | 16 | 0 | 0 |
| 5 | Règles (modèle) | 202 | 130 | 29 | 20 | 16 | 7 | 0 |
| 6 | IA | 135 | 101 | 11 | 16 | 2 | 5 | 0 |
| 7 | Plateau / scènes de jeu | 179 | 83 | 47 | 16 | 19 | 14 | 0 |
| 8 | Tutoriel | 71 | 58 | 9 | 3 | 1 | 0 | 0 |
| 9 | En ligne | 128 | 82 | 20 | 11 | 15 | 0 | 0 |
| 10 | Dépendances Android | 51 | 42 | 2 | 3 | 4 | 0 | 0 |
| 11 | Assets / rendu | 36 | 29 | 2 | 5 | 0 | 0 | 0 |
| 12 | Export web / perf | 20 | 4 | 4 | 2 | 8 | 0 | 2 |
| 13 | Couverture résiduelle | 128 | 100 | 17 | 5 | 6 | 0 | 0 |
| | **Total** | **1 194** | **737** | **215** | **119** | **95** | **26** | **2** |

\* Renvoyé : ligne qui dit « voir X » ; son statut est celui de la ligne X, comptée à part.

- **Écarts ouverts (2)** : W-14 (Moyenne, écoute humaine nécessaire) et W-18 (Haute, reste le vrai Safari : Chrome, Firefox et WebKit vérifiés le 2026-10-28). Aucun n'est classé Critique. R-E30, IA-H70 et X-M30 ont été fermés le 2026-10-28, puis S-02, I-03, I-04, I-10, I-22, P-C14 et W-08 (voir leurs lignes).
- **Sur 457 lignes avec écart relevé** (1 194 − 737 sans écart) : 215 corrigées, 119 acceptées (choix assumés ou cible souris/web), 95 classées conformes, 26 renvoyées, 2 ouvertes.
- **Extensions du wiki** (hors APK, donc sans référence décompilée) : TNL (The Next Level), CRL et RMB (Minibosses, 121 cartes : 100 Conforme, 20 Corrigé, 1 Non implémenté, Luz) ont chacune un audit carte par carte et leurs écarts corrigés (commits `0cb64cd`, `eedf159`, `ac554aa`, `edb9f22`, `0130d7b`, `f0cbf31`) ; elles ne comptent pas dans les 1 194 lignes.
- **Côté décompilation** : l'APK de référence est extrait et décompilé à 100 % au niveau des types et des méthodes (27 DLL, 4 930 / 4 930 déclarations, 560 `.cs` pour `DBMGame` sans aucun avertissement ; 29 fichiers de bibliothèques avec avertissements ILSpy), plus `classes.dex` (1 152 méthodes avec code décompilées sur 1 152) et les 4 bibliothèques natives, 0 échec de l'outil mais environ 3 % de fonctions Mono au pseudo-code dégradé dont 3 tronquées (voir `docs/audit-apk-2-2-6.md`, annexe de complétude). Le portage ne couvre que `DBMGame` ; WaveEngine, Photon, Insights, billing et BCL sont remplacés par Godot ou supprimés (boutique, Insights), ce que les modules 9 à 12 consignent.
- **Mesures relancées le 2026-10-28** (arbre de travail à `edb9f22` plus modifications non validées) : l'oracle `python tools/parity/apk.py` (`DBMGame.dll` d'origine, hors ligne) donne 6/6 (jeu de base, graines 1–3, 2–3 joueurs), 12/12 (jeu de base, graines 4–7, 2–4 joueurs) et 6/6 (jeu de base + PlayerChoice + HiddenHeros + ToolsHeroKind, graines 1–3, 2–3 joueurs), 0 erreur de script Godot, 0 carte non appariée. Ces traces comparent des parties entières mais en sautent des décisions (166, 435 et 162 décisions passées selon la série) : elles prouvent la parité sur les chemins joués, pas sur les 1 194 lignes. `python tools/run_godot_tests.py` : 19/19 suites OK (goldens, couverture, 14 soaks dont paquets APK, TNL, variantes 5–6 joueurs et extensions du wiki, en ligne, smoke UI) ; cela vérifie que le code actuel est cohérent avec ses propres références, pas la parité avec l'APK.

---

## Module 1 — Sauvegarde

Source relue : `DBMGameProject.Storage/*.cs` (11 fichiers, 376 lignes), `DBMGameProject/Game.cs:60-121`, tous les appelants (`grep GameSettings|GameStats|PurchasedItems|StorageHelper`).
Godot relu : `scripts/Profile.gd` (119 l.), `scripts/AudioManager.gd:60-130`, `scripts/Main.gd:283-293,335-339,637-642`, `scripts/BoardUI.gd:931-935`, `scripts/OnlineClient.gd:270-283,400-430`.

| ID | Élément source (décompilé) | Type | Présent dans Godot ? | Fichier Godot | Équivalent fonctionnel ? | Écart / Commentaire | Priorité |
|----|----|----|----|----|----|----|----|
| S-01 | `StorageHelper.SafeStorageWrite/Read` (8 essais, log `Crash`, `new T()` si échec) — `StorageHelper.cs:15-57` | Méthode | Oui | `Profile.gd`, `AudioManager.gd:120-128` (`ConfigFile.load/save`) | Partiel | Lecture : valeurs par défaut si fichier absent/illisible = équivalent. Écriture : code retour de `cfg.save()` jamais testé, pas de nouvel essai ni de log → une écriture ratée passe inaperçue. **6e :** voir la section « Lot 6e ». | Corrigé (6e) |
| S-02 | Backend `WaveServices.Storage` (sérialisation par type dans le stockage privé de l'app) | Service | Oui | `user://profile.cfg`, `user://audio.cfg` | Oui | **Corrigé le 2026-10-28.** `Main._ready` (`Main.gd`, après le fondu d'entrée) appelle `OS.is_userfs_persistent()` sur le web (doc 4.7 : faux en navigation privée ou si IndexedDB est refusé ; peut donner des faux positifs, d'où un simple avertissement) et, si faux, affiche 8 s, sans bloquer, « Browser storage is blocked: settings and profile will not be saved. » (`UiKit.label`, police APK, calque `_fade_layer`). Non vérifié en vrai navigation privée. | Moyenne (web) |
| S-03 | `GameSettings.Difficulty` (`DificultyEnum` Easy/Normal/Hard, défaut Normal) — `GameSettings.cs:11,31` | Propriété + enum | Non (vérifié absent) | — | N/A | Code mort dans l'APK : aucun lecteur de `.Difficulty` hors `Storage/` (grep sur les 560 `.cs`). Rien à porter. **6e :** voir la section « Lot 6e ». | Conforme (6e) |
| S-04 | `GameSettings.MusicVolume` (0/1 via MUSIC ON/OFF, défaut 1) — `GameSettings.cs:13,33`, `SettingsScene.cs:68-77` | Propriété | Oui | `AudioManager.gd` (`music_on`, bus `Music` muet), `Main.gd:640` | Oui | Booléen au lieu d'un float 0/1 : même comportement (l'APK n'écrit que 0 ou 1). | — |
| S-05 | `GameSettings.SoundVolume` (SOUND ON/OFF) — `SettingsScene.cs:78-87` | Propriété | Oui | `AudioManager.gd` (`sfx_on`, bus `SFX`), `Main.gd:641` | Oui | Idem S-04. | — |
| S-06 | `GameSettings.GameSpeed` + `GetSpeed()` (SLOW 1,5 / NORMAL 1 / FAST 0,5 ; forcé 0,5 si `ConnectionStates.InGame`) — `GameSettings.cs:45-68` | Propriété + méthode | Oui | `Profile.gd:109-119`, `BoardUI.gd:931-935`, `Main.gd:642`, `InGameMenu.gd:69` | Oui | Constantes et forçage en ligne identiques ; défaut NORMAL (1) identique. Usage par chaque animation à vérifier au module 7. | — |
| S-07 | `GameSettings.FullScreenMode` → `CustomService.IsFullScreenActive` (défaut true) — `GameSettings.cs:17,72-77` | Propriété | Non (vérifié absent) | — | — | Aucune ligne d'UI ne l'expose dans `SettingsScene`. L'implémentation Android de `CustomService` (sous-classe hors `DBMGame.dll`) est **non vérifiée faute d'accès** : probablement le mode immersif Android. Côté web, le plein écran exige un geste utilisateur ; non requis pour la parité. **6e :** voir la section « Lot 6e ». | Accepté (6e) |
| S-08 | `GameSettings.LegendaryEnabled` + ligne LEGENDARY MODE (affichée seulement si `IsBacker`, hors partie) — `SettingsScene.cs:98-110` | Propriété + UI | Non (vérifié absent) | — | — | Dépend de `IsBacker` (S-16). Effets : logos/défausse « legend », 15 avatars au lieu de 8 (`AvatarScrollComponent.cs:70`), art de cartes (`CardAssetService.cs:224`). Voir module 10. **Décision confirmée le 2026-10-26 : boutique supprimée.** **6e :** voir la section « Lot 6e ». | Accepté (6e) |
| S-09 | Champs obsolètes `TotalWins`, `IsFirstGameplay`, `IsBacker` de `GameSettings` + migration vers `GameStats` — `Game.cs:103-115` | Propriété / migration | N/A | — | N/A | Migration de sauvegardes Android antérieures : sans objet pour une installation web neuve. | — |
| S-10 | `GameSettings.SaveChanges()` au retour de SETTINGS — `SettingsScene.cs:133-136` | Méthode | Oui | `AudioManager._save`, `Profile.save_speed` (à chaque clic) | Oui | Sauvegarde immédiate au lieu d'au retour : même résultat visible, plus robuste (fermeture d'onglet). | — |
| S-11 | `GameStats.OnlineWins/OnlineDefeats` : défaite comptée **au début** de la partie en ligne, annulée à la victoire (`GamePlayMOScene.cs:46-48,262-265`) ; désertion : victoire seulement si `NumberOfTurns > 2`, défaite annulée dans tous les cas (`GamePlayMOScene.cs:241-250`) | Propriété + logique | Oui | `Profile.gd:55-73`, `OnlineClient.gd:272-283` | Différent | Godot ne compte qu'à `status == "finished"` → quitter ou fermer l'onglet en cours de partie n'ajoute **aucune** défaite (l'APK en compte une). Règle de désertion (> 2 tours) à vérifier côté serveur au module 9. Anti-double comptage par code de salle : ajout Godot, OK. | Corrigé (Moyenne) |
| S-12 | `GameStats.SPWins` (+1 à chaque victoire solo, `GamePlaySPScene.cs:80-86`) → `TotalWins()` → déblocage Hidden Heroes à 40 victoires (`LocalMarket.cs:147`, `AppPurchaseService.cs:315-321`, `WinnerScene.cs:98-110`, « N WINS TO UNLOCK! » `PurchaseScene.cs:146-149`) | Propriété + logique | Non (vérifié absent) | — (`Match.gd:12` : HiddenHeros jouable d'office) | Différent | Pas de compteur de victoires solo ni d'écran « CONGRATULATIONS! … HIDDEN HEROES ». Cohérent avec la boutique retirée (`apk-original/README.md` §2) — **à confirmer : choix assumé ?** **Décision confirmée le 2026-10-26 : boutique supprimée.** **6e :** voir la section « Lot 6e ». | Accepté (6e) |
| S-13 | `GameStats.UserName` / `Avatar` (int, index `Atlas.AVATAR`) | Propriété | Oui | `Profile.gd:20-52` (`name`, `avatar` en id texte, `NAME_MAX` 45, `random_profile`) | Oui | Id texte au lieu d'index : équivalent. `random_profile` (« player_ » + 4 car.) non recoupé avec `StringFactory.RndWord` → à vérifier au module 4. **6e :** voir la section « Lot 6e ». | Conforme (6e) |
| S-14 | `GameStats.IsFirstGameplay` : boîte TUTORIAL au 1er SINGLE PLAYER (CANCEL → faux) — `MainMenuScene.cs:60-88` ; consommé aussi par le constructeur de `GamePlayTutScene` (`:82-84`) | Propriété + flux | Oui | `Profile.gd:97-107`, `Main.gd:286-293,335-336` | Oui | Les deux points de consommation sont portés ; défaut true identique. | — |
| S-15 | `GameStats.CheckForcePlayTutorial` (rejoue le tutoriel si version sauvée < `LAST_TUTORIAL_VERSION` 2.2.4 ; `CURRENT_VERSION` 2.2.6) — `GameStats.cs:33-42`, `Game.cs:30,34,119` | Méthode | Non (vérifié absent) | — | N/A | Sans objet tant qu'aucune version web antérieure n'existe (défaut `first_gameplay = true`). À reprendre si le tutoriel change dans une future version. **6e :** voir la section « Lot 6e ». | Corrigé (6e) |
| S-16 | `GameStats.IsBacker` → `Boss.IsBacker` (`GamePlayBaseScene.cs:563-569`), visuels « legend », envoyé en ligne (`OnlineService.cs:1012`) ; mis à vrai par `AppPurchaseService.cs:191` | Propriété | Non (vérifié absent) | — | — | Statut mécène Kickstarter lié à l'achat : voir module 10. **Décision confirmée le 2026-10-26 : boutique supprimée.** **6e :** voir la section « Lot 6e ». | Accepté (6e) |
| S-17 | `OnlineStorage` (obsolète : UserName/Avatar/Wins/Defeats) | Classe | N/A | — | N/A | Seulement relu pour migration (`Game.cs:100-112`). | — |
| S-18 | `OnlineKeys` (clés de propriétés Photon : IsBacker, Wins, Defeats, Avatar, UserName, AppID, …) | Classe | Non vérifié | — | — | Protocole Photon remplacé par le serveur WS : à traiter au module 9. | — |
| S-19 | `PurchasedItems`, `PurchaseId` (SKU `com.dbm.fullgame*`, clé publique de licence Google Play), `AppItemInfo`, `AppStoreInfo` | Classes | Non (vérifié absent) | — | — | Boutique/IAP retirée : module 10. La clé de `PurchaseId.cs` est une clé **publique** (pas un secret). | — (module 10) |
| S-20 | — (absent de l'APK) Reprise de session en ligne après rechargement | Ajout Godot | Oui | `OnlineClient.gd:400-430` (`sessionStorage` via `JavaScriptBridge` sur web, `user://online_session.cfg` sinon) | — | Ajout propre au web (un onglet = un siège). Pas d'écart de parité. | — |
| S-21 | — (absent de l'APK) Volume général `master` (curseur en partie) | Ajout Godot | Oui | `AudioManager.gd:103-109`, `InGameMenu.gd:72-104` | Différent | Les réglages en partie de l'APK (`SettingsScene(fromGamePlay)`) n'ont que MUSIC/SOUND/GAME SPEED. Ajout à justifier ou retirer : module 4. **6e :** voir la section « Lot 6e ». | Accepté (6e) |

### Résumé module 1

- **21 éléments audités** : 7 OK (S-04, S-05, S-06, S-10, S-13, S-14, S-20), **4 N/A** (S-03, S-09, S-15, S-17), **9 écarts** (S-01, S-02, S-07, S-08, S-11, S-12, S-16, S-19, S-21), 1 renvoyé (S-18).
- **Bloquants web : 0.** Risque web : S-02 (stockage non persistant non détecté), corrigé le 2026-10-28 : avertissement au démarrage.
- Écarts Moyenne : S-02 (corrigé le 2026-10-28), S-11. Le reste est Basse ou suspendu à une confirmation.

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
| A-02 | `SoundBank.MaxConcurrentSounds = 10` (`AudioService.cs:97`) ; plein → `CreateSoundInstance` renvoie `null`, **le nouveau son est abandonné** (`SoundBank.cs:130-145`) ; la boucle compte dans les 10 | Constante + comportement moteur | Oui | `AudioManager.gd:10,155-165` | Différent | Godot **vole** la voix la plus ancienne (tour à tour) au lieu d'ignorer le nouveau son ; la boucle `sfx_sparklecard` a son propre lecteur (11 voix possibles). Audible seulement en rafale (> 10 sons). **6e :** voir la section « Lot 6e ». | Corrigé (6e) |
| A-03 | `LoadAllSounds()` : précharge les 42 sons (`Sfx` 38 + `SfxSting` 3 + `SfxLoop` 1) — `AudioService.cs:113-127`, appelé par `LoadingScene.cs:54` | Méthode | Oui | `AudioManager.gd:14-19,68-69` | Oui | Liste `SFX_NAMES` = les 42 noms de `Audio.cs` (recoupés un à un) et les 42 `.wav` présents dans `assets/audio/sfx/`. | — |
| A-04 | `Play(Audio.Music)` : `IsRepeat = true`, ne relance pas la piste en cours, volume = `MusicVolume` — `AudioService.cs:190-201` | Méthode | Oui | `AudioManager.gd:132-143` | Oui | Boucle forcée à l'exécution (`AudioStreamMP3.loop = true`), l'import garde `loop=false`. | — |
| A-05 | `musicVolume = 0.5f` par défaut (`AudioService.cs:29`), écrasé par `GameSettings.MusicVolume = 1` via `ApplySettings` (`Game.cs:98`) | Constante | Oui | `AudioManager.gd:41` (`music_volume = 1.0`) | Oui | Le 0,5 n'est jamais effectif dans l'APK ; Godot part directement de 1,0. | — |
| A-06 | `PlayWithMusicFade(SfxSting)` : musique × 0,5 puis retour linéaire en 2 s, seulement si musique et sons actifs et > 0 — `AudioService.cs:153-164,209-225` | Méthode | Oui | `AudioManager.gd:167-182` (`play_sting`, `duck_gain`, `_process`) | Oui | Constantes `DUCK 0.5`, `DUCK_SECONDS 2.0` et condition identiques. | — |
| A-07 | `PlayLoopSound` / `StopLoopSound` : une instance par son, compteur de demandes — `AudioService.cs:129-143,166-176` | Méthode | Oui | `AudioManager.gd:185-212` | Oui | `stop_all_loops()` (ajout Godot) sert au nettoyage en sortie de plateau. | — |
| A-08 | `MuteSFX` / `MuteMusic` (propriétés publiques) | Propriété | N/A | — | N/A | Aucun écrivain dans `DBMGame` (grep) ; `MuteMusic` n'est que lu dans `PlayWithMusicFade`. Code mort. | — |
| A-09 | `MUSIC_FADEIN_SECONDS = 2f` (`AudioService.cs:15`) | Constante | N/A | — | N/A | Déclarée, jamais utilisée. | — |
| A-10 | Pause de la musique quand l'app passe en arrière-plan : `AndroidActivity.OnPause → Game.OnDeactivated` (`AndroidActivity.cs:95-112`) → `MusicPlayer.Pause` (Wave `GLView.cs:162`, `MusicPlayer.cs:179-200`) | Cycle de vie | Non (vérifié absent dans les scripts) | — | Non vérifié | Aucun traitement de la perte de focus / onglet masqué dans les scripts. Ce que fait le moteur web quand l'onglet est masqué est **non vérifié** (à tester en navigateur). | Corrigé (Moyenne) |
| A-11 | `GetBoss{Intro,Hurt,Death,Victory}Sound` : `boss_male_*` si `Boss.IsMale`, sinon `boss_female_*` (boss nul → female) — `CardAssetService.cs:246-300` | Méthode | Oui | `AudioManager.gd:34,215-216` | Oui | `BOSS_FEMALE` = exactement les 10 boss `IsMale=false` de `data.json` (BMA006-008, KSA001-007) ; 5 masculins. Boss du wiki → masculin (ajout, pas de donnée APK). Boss inconnu = male (APK : boss nul = female) : cas inatteignable avec les paquets APK. | — |
| A-12 | `GetRoomSound` : `RoomCategory` 1 fall, 2 monster_med, 3 undead, 4 physical, 5 monster_lrg, 6 magic ; autre/nul → physical — `CardAssetService.cs:326-360`, `RoomCategory.cs` | Méthode | Oui | `AudioManager.gd:21-31,219-224` | Partiel | Correspondance enum → son identique ; les 31 salles de `BaseDeck` recoupées avec `data.json` (aucune différence) ; les salles `PlayerChoice`/`ToolsHeroKind` n'ont pas de `RoomCategory` → physical, comme l'APK. Écart de conception : table d'ids figée dans le code au lieu de lire `RoomCategory` dans les données. **6e :** voir la section « Lot 6e ». | Corrigé (6e) |
| A-13 | `GetSpellSound` (summon / null / buff / debuff selon `SpellCategory`) — `CardAssetService.cs:302-325` | Méthode | N/A | — | N/A | **Aucun appelant** dans `DBMGame` (grep) : les sorts ne jouent jamais ces sons dans l'APK. Godot ne les joue pas non plus : conforme. | — |
| A-14 | Sons jamais joués par l'APK : `sfx_spelladd`, `sfx_multigameready`, `ui_button_finish`, `ui_card_flip`, `sfx_spell_summon`, `sfx_spell_null`, `sfx_spell_debuff` (seul `Scenes.Test/AudioScene` les cite) | Asset | Oui (fichiers) | `assets/audio/sfx/` | Oui | Copiés et préchargés comme dans l'APK, jamais joués. Poids inutile dans le `.pck` (faible, voir module 12). **6e :** voir la section « Lot 6e ». | Conforme (6e) |
| A-15 | `ui_purchase` (`UnlockScene.cs:167`) | Appel | Non (vérifié absent) | — | — | Lié à l'écran de déblocage retiré (S-12). **6e :** voir la section « Lot 6e ». | Accepté (6e) |
| A-16 | Musiques : `music_main` à l'intro (`IntroScene.cs:84`), `music_dungeon_v3` en partie (`GamePlayBaseScene.cs:552`) | Appel | Oui | `Main.gd:238,276`, `BoardUI.gd:657` | Oui | — | — |
| A-17 | Stings : `sting_levelup` (`LevelUpBanner.cs:122`), `sting_player_lose` (`LoseScene.cs:21`), `sting_player_win` + voix de victoire du boss **0,5 s plus tard** (`WinnerScene.cs:121-132`) | Appel | Oui | `BoardUI.gd:1302,4285-4291` | Oui | Délai de 0,5 s identique. | — |
| A-18 | Traversée du héros : `char_hero_intro` (`GamePlayBaseScene.cs:934`), `char_hero_move` + son de salle à chaque salle (`HeroCrossingBehavior.cs:70-76`), `char_hero_death` (`:98`), `char_hero_move` puis `char_hero_attack` vers le boss (`:111,117`) | Appel | Oui | `BoardUI.gd:2211-2267,2353-2355,2376-2381` | Oui (sons) | Présence et ordre des sons vérifiés ; synchronisation exacte avec les animations : module 7. | — |
| A-19 | `HeartDecrementEmitter` : `char_hero_hurt` si PV perdus, `sfx_spell_buff` si PV rendus (`:64-70`) | Appel | Oui | `BoardUI.gd:2241,2364` | Oui | — | — |
| A-20 | Boss : intro au tirage (`RandomBossSelectionScene.cs:134`), blessure / mort (`DungeonFrameEntity.cs:507,516`) | Appel | Oui | `BoardUI.gd:1898-1905,2273-2281` | Oui | — | — |
| A-21 | Mouvements de cartes : `FlipCardBehavior.cs:113,126`, `CardPositionComponent.cs:83-96`, `AddCarouselCardsBehavior.cs:105`, `DrawCardEmitter.cs:161`, zoom `GamePlayBaseScene.cs:1267-1272`, file de héros `VerticalScrollQueueComponent.cs:194` | Appel | Oui | `BoardUI.gd:856,1390,1848,1894,3267-3335,3818-3831,4152,4164`, `CardUI.gd:108` | Partiel | Retournement de toutes les cartes du carrousel : l'APK joue `ui_card_slide_down` **une fois par carte** (sons superposés, plus fort), Godot une seule fois (`BoardUI.gd:1848`). **6e :** voir la section « Lot 6e ». | Corrigé (6e) |
| A-22 | Carrousel : `ui_shuffle_left` si l'indice augmente, `ui_shuffle_right` s'il diminue (`CarrouselComponent.cs:118-133`) | Appel | Partiel | `BoardUI.gd:1862` (tirage du boss) | Partiel | Le tirage du boss ne tourne que dans un sens → `left` seul, conforme. Les autres carrousels de l'APK (glissement dans les deux sens, `CarrouselDragBehavior`) : **non vérifié**, à traiter aux modules 4 et 7. **6e :** voir la section « Lot 6e ». | Corrigé (6e) |
| A-23 | Panneau d'adversaire étendu : `ui_card_slide_down` à l'ouverture, `ui_card_slide_up` à la fermeture (`ExpandedOpponentComponent.cs:51,60`) | Appel | Non (vérifié absent dans les appels audio) | — | — | Aucun son équivalent. L'existence du panneau lui-même dans Godot : à vérifier au module 7. **6e :** voir la section « Lot 6e ». | Corrigé (6e) |
| A-24 | Sélection de cartes : `ui_button_subselect` au retrait, `ui_button_select` à l'ajout (`CardSelectorComponent.cs:120-135`) | Appel | Oui | `BoardUI.gd:2694-2696,3227-3233` | Oui | — | — |
| A-25 | Boutons : `ui_button_select` (`ButtonBaseEntity.cs:202`, `ControlsFactory.cs:263`, `SettingButtonDecorator.cs:132`, `DoneButtonEntity.cs:164`, `TargetResolverBaseSceneBehavior.cs:165`, `GalleryScene.cs:352`, `CardDetail*`), `ui_button_goback` (`ControlsFactory.cs:245`, `CardDetailEntity.cs:124`, `CardDetailScene.cs:74`) | Appel | Oui | `UiKit.gd:211`, `Main.gd:183-616`, `CardGallery.gd:233,289`, `RulesViewer.gd`, `InGameMenu.gd:56-63`, `OnlineMenus.gd`, `BoardUI.gd` | Oui (par sondage) | Les deux sons sont branchés sur les boutons et retours ; la correspondance bouton par bouton est reportée au module 4. | — |
| A-26 | `sfx_activatecard` à l'entrée de la bulle d'action de l'adversaire (`BubblesPlayerEmitter.cs:115`) | Appel | Oui | `BoardUI.gd:3990` | Oui | — | — |
| A-27 | Boucle `sfx_sparklecard` sur les cartes jouables (`CardStackSlotComponent.cs:312,334`, arrêts `CardAttributesComponent.cs:210,261`) | Appel | Oui | `BoardUI.gd:677,2839,2985-2987` | Oui | — | — |
| A-28 | `ui_timer` : joué **uniquement** dans la salle d'attente publique, pendant le compte à rebours de lancement (`WaitingPublicRoomScene.cs:88-105`) | Appel | Différent | `CountDown.gd:49` | Différent | Godot joue `ui_timer` chaque seconde sous 5 s dans le **compte à rebours de tour en partie** (`Main.gd:576`), ce que l'APK ne fait jamais, et aucun `ui_timer` en salle d'attente (grep : seul appel). Salle publique à revoir au module 9. | Partiel (Moyenne) |
| AW-01 | Web — déverrouillage de l'audio par le navigateur (sans équivalent APK) | Contrainte web | Oui | `AudioManager.gd:48,80-87,134-136` | Oui | Musique demandée mise en attente jusqu'au premier clic / touche / toucher, puis jouée. Les SFX demandés avant ce premier geste sont perdus (sans conséquence : aucun son avant interaction). | — |
| AW-02 | Web — formats | Contrainte web | Oui | `assets/audio/music/*.mp3`, `assets/audio/sfx/*.wav` (import `compress/mode=2`, QOA) | Oui | MP3 conservé pour la musique : Godot le décode lui-même (pas de dépendance aux codecs du navigateur) ; le convertir en Ogg serait un ré-encodage avec perte pour un gain faible. SFX importés compressés (QOA). **6e :** voir la section « Lot 6e ». | Conforme (6e) |
| AW-03 | Web — mode de lecture `Sample` (Web Audio, défaut Godot 4.3+ sur le web) | Contrainte web | Oui (défaut, aucune surcharge dans `project.godot`) | — | Oui | Le mode Sample ne gère pas les `AudioEffect` : le projet n'en utilise aucun (grep). Volume/sourdine par bus et boucle d'un `AudioStreamWAV` dupliqué en mode Sample : **non vérifiés en navigateur**. **6e :** voir la section « Lot 6e ». | Conforme (6e) |
| AW-04 | Web — threads | Contrainte web | Oui | `export_presets.cfg:23` (`thread_support=false`) | Oui | Aucun thread audio côté scripts. Le mode Sample est celui recommandé sans threads. | — |

### Résumé module 2

- **32 éléments audités** : 20 OK (dont les 4 contraintes web AW), 3 N/A (A-08, A-09, A-13), **9 écarts** (A-02, A-10, A-12, A-14, A-15, A-21, A-22, A-23, A-28).
- **Bloquants web : 0.** À tester en navigateur : A-10 (onglet masqué), AW-03 (bus et boucle en mode Sample).
- Écarts Moyenne : **A-10** (pas de pause de la musique hors focus), **A-28** (`ui_timer` déplacé de la salle d'attente publique vers le tour de jeu).

### Questions ouvertes (module 2)

1. A-28 : le son `ui_timer` sur le compte à rebours de tour en ligne est-il un ajout voulu ? Sinon il faut le retirer et le rebrancher sur la salle d'attente publique.
2. ~~A-10 : faut-il couper la musique quand l'onglet est masqué (comme l'APK en arrière-plan) ?~~ Réponse : oui (lot 3).

---

## Module 3 — Entrées

Source relue : `DBMGame/AndroidActivity.cs` (entier), `LongTouchBehavior.cs`, `TwoLongTouchBehavior.cs` + `MainMenuScene.cs:121-138`, `CarrouselDragBehavior.cs`, `CardCarrouselEntity.cs:118-215`, `CardExtractBehavior.cs`, `CardHoverDetailBehavior.cs`, `PlayerNumberSelectionEntity.cs`, `TextEntryEntity.cs`, `CardAttributesComponent.cs:330-347`, inventaire par grep de **tous** les accès `WaveServices.Input` (touch / souris / clavier) et de tous les `TouchTap +=` (19 sites), utilisateurs de chaque comportement d'entrée (`grep "new <Behavior>"`).
Godot relu : `project.godot` (`[input_devices]`, `window/stretch`), `export_presets.cfg:26-40`, `CardUI.gd:26-32,262-315`, `BoardUI.gd:237,1368-1382,1421-1430,1955-1972,3218-3300,3548-3610,3743-3760`, `Main.gd:380-415`, `OnlineMenus.gd:130-136,313-318,597`, `build_web/index.html`, inventaire grep de tous les `_input` / `_gui_input` / `InputEvent*` / `KEY_*` / `ui_*`.
Doc Godot 4.7 consultée : `EditorExportPlatformWeb.html/experimental_virtual_keyboard`, `LineEdit.virtual_keyboard_enabled`.

| ID | Élément source (décompilé) | Type | Présent dans Godot ? | Fichier Godot | Équivalent fonctionnel ? | Écart / Commentaire | Priorité |
|----|----|----|----|----|----|----|----|
| I-01 | Couche tactile Wave : `TouchPanel` + `TouchGestures` (`TouchPressed/Released/Moved/Tap`), souris prise en compte si `MouseState.IsConnected` (`CardHoverBehavior.cs:124-134`, `SimpleHoverBehavior.cs:60-77`) | Moteur d'entrée | Oui | `project.godot:29-31` (`emulate_touch_from_mouse=true`, `emulate_mouse_from_touch` au défaut `true`), scripts en `InputEventMouse*` | Oui | Le toucher est converti en souris par Godot, tout le code n'écoute que la souris : un seul chemin pour souris et doigt. Comportement réel sur écran tactile **non vérifié sur appareil**. | — |
| I-02 | `ViewportManager.RecoverPosition` : coordonnées écran → résolution virtuelle | Méthode | Oui | `project.godot:23-27` (1920 × 1080, `canvas_items`, `keep_aspect`) | Oui | Conversion faite par le stretch de Godot. | — |
| I-03 | Survol de la main (`CardHoverBehavior`) : la carte sous le doigt (ou la souris) se soulève ; doigt posé = survol | Comportement | Oui | `BoardUI.gd:1740,2002` (`mouse_entered` des cartes), `BoardUI.gd:3275-3291` | Oui | **Corrigé le 2026-10-28.** Le survol ne dépend plus d'un geste ambigu : `_tick_hand_hover` (P-C07) suit le pointeur et l'extraction n'a lieu qu'au-dessus de `HAND_UPPER` (voir I-04). Glisser latéralement sur la main ne fait donc que survoler, comme l'APK. Souris vérifiée ; doigt réel non essayé. | Basse (cible souris) |
| I-04 | `CardExtractBehavior` : la carte n'est **extraite** que quand le doigt **monte au-dessus de `upperLimit`** (haut de la main + 50 px, `:47,57-66`) ; redescendre dans la main = reposer ; relâcher = déposer ; carte interdite → `InvalidCardPlayed` ; tutoriel : seule `ForcedToExtractCard` | Comportement | Oui | `BoardUI.gd:237,3578-3610,3743-3760` | Oui | **Corrigé (déjà porté dans le code, ligne d'audit périmée ; relu le 2026-10-28).** `DRAG_SLOP` n'existe plus : `BoardUI._drag_input` (≈4019-4040) ne démarre `_drag_begin` que si `y < HAND_UPPER` (= 797 = 972 − 450/2 + 50, `CardExtractBehavior.cs:166`, `upperLimit`) ; redescendre sous la limite repose la carte (`:180`) ; relâcher dépose (`_drag_end`) ; carte grisée refusée ; tutoriel `_tg("drag")` conservé. `ui_smoke` passe (21/21). | Basse (cible souris) |
| I-05 | — (absent de l'APK) Toucher une carte de la main pour la jouer | Ajout Godot | Oui | `BoardUI.gd:3221-3270` (`_on_hand_card_clicked`, `HAND_CLICK_TYPES`) | Différent | Dans l'APK, aucune carte de la main ne réagit au tap (les 19 `TouchTap +=` relus) : on joue uniquement en glissant. Ajout pratique à la souris ; à garder ou retirer selon l'objectif de clone exact. **6e :** voir la section « Lot 6e ». | Accepté (6e) |
| I-06 | `LongTouchBehavior` 1,0 s sur les cartes du **carrousel** (`CardCarrouselEntity.cs:124`) → `CardDetailEntity` ; annulé par **tout** `TouchMoved` ; le tap est ignoré si l'appui long a eu lieu (`:131`) | Comportement | Oui | `CardUI.gd:28-29,267-312` | Partiel | Durée 1,0 s identique, tap ignoré après appui long conforme. Écarts : annulation seulement au-delà de 12 px ; clic droit = appui long (ajout bureau) ; appliqué aussi à la main, aux salles et aux héros (`BoardUI.gd:1377,1524,1654,1741`). **6e :** voir la section « Lot 6e ». | Accepté (6e) |
| I-07 | `CardHoverDetailBehavior` (file de héros) : détail **immédiat** du héros sous le doigt posé ou la souris, fondu + échelle 0,8 → 1 en 0,2 s, retiré dès qu'on sort | Comportement | Non (vérifié absent) | `BoardUI.gd:1377-1378` (appui long) | Différent | Godot demande un **appui long de 1 s** sur la carte du héros ; pas de détail au survol. | Conforme (Moyenne) |
| I-08 | `CarrouselDragBehavior` : glisser = 0,004 index/px, recalage `Lerp(…, 0.2)` **par image** (dépend du framerate), seuil 0,05, flèches ← → (`:59-118`) ; utilisé par le choix du nombre de joueurs (horizontal + tap sur les côtés, `PlayerNumberSelectionEntity.cs:21-59,85`) et le zoom de pile de salles (vertical, `SlotDetailEntity.cs:85-88`) ; désactivé au tirage du boss | Comportement | Partiel | `Main.gd:409-411` (zones de tap) | Différent | Nombre de joueurs : **tap seulement**, ni glisser ni flèches. Zoom de pile de salles : **non vérifié**, module 7. **6e :** voir la section « Lot 6e ». | Corrigé (6e) |
| I-09 | `TwoLongTouchBehavior` : deux doigts écartés d'au moins 900 px dans la bande (220, 730, 1000 × 90), 2 s → `UnlockCodeScene` (code « REDEEM CODE ») — `MainMenuScene.cs:121-138` | Geste caché | Non (vérifié absent) | — | — | Accès caché au code mécène / déblocage : lié à IAP/backer, module 10. **6e :** voir la section « Lot 6e ». | Accepté (6e) |
| I-10 | `TextEntryEntity` : `TextBox` Wave avec boîte de saisie native Android (`MessageBoxTitle` USERNAME / ROOM CODE / REDEEM CODE) — `ChangeNameAvatarScene.cs:81`, `WithFriendsOnlineScene.cs:131`, `UnlockCodeScene.cs:62` | Saisie texte | Oui | `OnlineMenus.gd:130-136` (pseudo, `max_length` 45), `:313-318`, `:597` (code de salle) | Oui | **Corrigé le 2026-10-28.** `html/experimental_virtual_keyboard=true` (`export_presets.cfg`). Doc 4.7 : intègre un clavier virtuel dans la page, affiché au besoin sur écran tactile (option marquée expérimentale). Le `index.js` exporté ne l'active que si `GodotConfig.virtual_keyboard && "ontouchstart" in window` (`GodotDisplayVK.available`) : aucun effet sur un navigateur sans tactile, donc la saisie clavier du `LineEdit` sur bureau est inchangée. Non essayé sur un vrai téléphone. | Basse (cible souris) |
| I-11 | Touche Retour Android → `NavigatedBack()` de chaque scène ouverte, sortie de l'app hors scène (`AndroidActivity.cs:52-71`) | Entrée système | Non (vérifié absent) | — | — | Aucun `ui_cancel` / Échap / `NOTIFICATION_WM_GO_BACK_REQUEST` dans les scripts. Sur le web, le bouton Précédent du navigateur quitte la page au lieu de revenir à l'écran précédent. Échap pourrait jouer ce rôle au clavier. | Corrigé (Moyenne) |
| I-12 | Clavier : flèches ← → sur les carrousels (`CarrouselDragBehavior.cs:74-85`) | Entrée clavier | Partiel | `RulesViewer.gd:117-119` (pages des règles seulement) | Différent | Pas de flèches sur les carrousels (nombre de joueurs). **6e :** voir la section « Lot 6e ». | Corrigé (6e) |
| I-13 | Raccourcis de debug : `DebugSceneBehavior` (F1-F6), `DrawCardsDemoBehavior` (Ctrl+S/R/K, 1-4) | Debug | N/A | — | N/A | `DebugSceneBehavior` : aucun utilisateur (grep) ; `DrawCardsDemoBehavior` : seulement dans `CreateTestButtons()` (`GamePlayBaseScene.cs:298`), jamais appelé. Code mort. | — |
| I-14 | `HideWhenTouchBehavior` (bulles, 0,5 s, `BalloonEntity`), `TouchOutBehavior` (fermeture au toucher hors zone : `GamePlayBaseScene`, `MiddleCarrouselEntity`) | Comportement | Partiel | `BoardUI.gd:1962-1966` (le zoom se ferme au clic suivant) | Non vérifié | Fermeture au clic hors zone présente pour le zoom ; bulles et carrousel du milieu : vérification reportée au module 7. | — |
| I-15 | `SimpleHoverBehavior` (survol de la pile de sorts, `SpellBattleEntity`) | Comportement | Non vérifié | — | — | Module 7. | — |
| I-16 | `SimpleSelectorBehavior`, `IsHoverBehavior`, `SettingsSliderControl`/`SettingsSliderBehavior` | Comportement | N/A | — | N/A | Aucun utilisateur dans `DBMGame` (grep). Code mort. | — |
| I-17 | Défilement de la galerie : `ScrollCardBehavior` (← `ScrollListBehavior`, `GalleryScene`) | Comportement | Oui | `CardGallery.gd:93-96,174` (molette + glisser) | Partiel | Glisser et molette présents ; inertie et constantes de défilement non comparées (module 4). **6e :** voir la section « Lot 6e ». | Conforme (6e) |
| I-18 | `ExpansionScrollComponent` (`ExpansionScene`, `InAppPurchaseScene`) | Comportement | Non vérifié | — | — | Écrans de boutique / extensions : modules 4 et 10. | — |
| I-19 | `TapTask` (le tutoriel attend un tap) + attente de doigt levé (`TutorialBaseScene.cs:92,114`) | Tâche | Oui | `TutorialOverlay.gd:813-815,1091-1092` | Non vérifié en détail | Module 8. | — |
| I-20 | `HandMouseOverBehavior` (survol souris des boutons, `ButtonBaseEntity`) | Comportement | Oui | thème `font_hover_color` (`BoardUI.gd:533,1234-1259`) | Partiel | L'effet visuel exact du survol : module 4. **6e :** voir la section « Lot 6e ». | Conforme (6e) |
| I-21 | `Window.AddFlags(KeepScreenOn)` (`AndroidActivity.cs:43`) | Système | Non (vérifié absent) | — | — | Web : l'API Screen Wake Lock n'est pas utilisée ; l'écran du téléphone peut se mettre en veille pendant une partie. **6e :** voir la section « Lot 6e ». | Corrigé (6e) |
| I-22 | Paysage forcé (`ScreenOrientation.Landscape`, `AndroidActivity.cs:12-15`) + mode immersif (`HideSoftKeys`) | Système | Non (vérifié absent) | `export_presets.cfg:32,36` (PWA désactivée) | Oui | **Corrigé le 2026-10-28.** `Main._touch_fullscreen_landscape` (web seulement) : si `ontouchstart` et `(pointer: coarse)`, au premier `pointerup`/`touchend` (geste requis) : `requestFullscreen()` puis `screen.orientation.lock('landscape')`, échec silencieux (iOS, Firefox, refus). Rien sur souris. Non essayé sur un vrai appareil. | Basse (cible souris) |
| IW-01 | Web — gestes du navigateur (zoom à deux doigts, défilement de page) | Contrainte web | Oui | `build_web/index.html` (`touch-action: none`, `user-scalable=no`) | Oui | Constaté dans le build présent (daté du 2026-10-17, peut-être antérieur au dernier export) : à revérifier au module 12. | — |
| IW-02 | — (absent de l'APK) Relâchement perdu hors du canvas | Ajout Godot | Oui | `BoardUI.gd:1957-1960,3560-3563` (`NOTIFICATION_WM_MOUSE_EXIT`, perte de focus) | — | Protection propre au navigateur / bureau. | — |

### Résumé module 3

- **24 éléments audités** : 4 OK (I-01, I-02, IW-01, IW-02), 2 N/A (I-13, I-16), **14 écarts** (I-03, I-04, I-05, I-06, I-07, I-08, I-09, I-10, I-11, I-12, I-17, I-20, I-21, I-22), 4 non vérifiés et renvoyés aux modules 4, 7, 8 et 10 (I-14, I-15, I-18, I-19).
- **Cible décidée le 2026-10-26 : jeu à la souris (bureau).** Les écarts propres au toucher (I-03, I-04, I-10, I-22) passent donc en Basse ; ils sont tous quatre corrigés le 2026-10-28 (voir leurs lignes).
- **Bloquants web : 0.**
- Écarts Moyenne : I-07 (détail des héros au survol remplacé par un appui long : concerne aussi la souris), I-11 (pas de retour arrière, Échap).

### Questions ouvertes (module 3)

1. ~~La cible inclut-elle téléphones et tablettes ?~~ Réponse : non, souris uniquement.
2. I-05 : garder le clic pour jouer une carte de la main (ajout) ou s'en tenir au seul glisser de l'APK ?
3. ~~I-11 : faut-il brancher Échap (et éventuellement le bouton Précédent du navigateur) sur le retour arrière de l'APK ?~~ Réponse : oui, Échap (lot 3).

---

## Module 4 — UI / menus

Méthode : trois lots audités en parallèle par des sous-agents en lecture seule (mêmes règles de preuve : `fichier:ligne` des deux côtés, « vérifié absent » = grep cité). J'ai ensuite recontrôlé à la main les écarts Moyenne et Haute : U-A44, U-A59, U-A70, U-B08, U-B21, U-C01/U-A34, U-C20, U-C28, U-C31. Tous sont confirmés.
Abréviations : APK = `apk-original/decompiled/DBMGame/`, `MG` = `Main.gd`, `CG` = `CardGallery.gd`, `OM` = `OnlineMenus.gd` (tous sous `src/frontend/godot/scripts/`).
Hors lot : le menu PAUSE en partie, `InGameMenu.gd` (dont le curseur de volume S-21) et l'écran de fin de partie relèvent du module 7.

### 4A — Démarrage, menu principal, solo, options, crédits

Source relue : `Game.cs`, `LoadingScene`, `IntroScene`, `MainMenuScene`, `PlayerNumberScene`, `OptionsScene`, `SettingsScene`, `CreditsScene`, `QuitGameScene`, `ConfirmationBoxScene`, `MessageBoxScene`, `NextSceneType`, entités et composants associés, `ControlsFactory`, `DBMBaseScene`, `ButtonBaseEntity`, `StringFactory`. Godot : `MG`, `UiKit.gd`, `CreditsScreen.gd`, `RulesViewer.gd`, `Profile.gd`.

| ID | Élément source (décompilé) | Type | Présent dans Godot ? | Fichier Godot | Équivalent fonctionnel ? | Écart / Commentaire | Priorité |
|----|----|----|----|----|----|----|----|
| U-A01 | Viewport 1440×1080 Uniform, MaxTouchPoints 1 (`Game.cs:39,49`) | Démarrage | Oui | `project.godot:23-27` | Différent | Godot 1920×1080 `keep_aspect` ; coordonnées APK + 240 px, fonds étirés. Choix du port. | Accepté (Basse) |
| U-A02 | `InitializePurchase` / `AppPurchaseService` / `LocalMarket` (`Game.cs:60-78`) | Démarrage | Non (vérifié absent) | — | — | Boutique retirée volontairement (module 10). | Accepté (Basse) |
| U-A03 | `LoadStorageGameData`, `CheckForcePlayTutorial` (`Game.cs:86-121`) | Démarrage | Oui | `MG:75-80`, `Profile.gd` | — | Voir S-04..S-06, S-10, S-14, S-15. | — |
| U-A04 | Écran de chargement : fond `loading_bg`, couleur #270000 (`LoadingScene.cs:24,31`) | Écran | Partiel | `project.godot:12-14` (splash du moteur) | Partiel | Couleur exacte, mais c'est l'écran de démarrage du moteur et non une scène du jeu. | Accepté (Basse) |
| U-A05 | Sprite « loading » + 3 rupies animées (`LoadingScene.cs:36,44`, `RupisLoadingBehavior.cs:56-80`) | Animation | Non (vérifié absent) | — | — | `loading.webp` présent mais jamais référencé. | Accepté (Basse) |
| U-A06 | Fin du chargement → Intro en fondu noir 1,0 s (`LoadingScene.cs:55-60`) | Transition | Partiel | `MG:84` | Différent | Pas de fondu entre le chargement et le titre. | Corrigé (Basse) |
| U-A07 | Retour pendant le chargement = quitter (`LoadingScene.cs:65-67`) | Navigation | Non (vérifié absent) | — | — | Voir I-11. | Accepté (Basse) |
| U-A08 | Fond `intro_bg` (`IntroScene.cs:41`) | Écran | Oui | `MG:239` | Oui | — | — |
| U-A09 | Grand logo `bm_logo`, haut-centre, y 80 (`IntroScene.cs:43`, `ControlsFactory.cs:292-315`) | Élément | Oui | `MG:247` | Oui | Écart ≤ 3 px. | — |
| U-A10 | Bougies (380 ; 680) et (1050 ; 680), statiques (`IntroScene.cs:45,47`) | Élément | Oui | `MG:240-243` | Oui | — | — |
| U-A11 | Yeux du monstre, clignement de 5 s (`IntroScene.cs:54-55`, `BlinkBehavior.cs:42-63`) | Animation | Oui | `MG:200-204,244-246` | Oui | — | — |
| U-A12 | « TAP TO START » arcadepix ×2, #bfca7a, clignement 0,3 s (`IntroScene.cs:57-59`) | Texte | Oui | `MG:248-251` | Oui | — | — |
| U-A13 | Tap n'importe où → menu principal, fondu noir 1,0 s, sans son (`IntroScene.cs:107-112`) | Navigation | Oui | `MG:112-126,252` | Oui | 0,5 + 0,5 s, entrées bloquées pendant le fondu. | — |
| U-A14 | `music_main` à l'intro (`IntroScene.cs:84`) | Son | Oui | `MG:238,276` | Oui | Voir A-16. | — |
| U-A15 | Retour à l'intro → `QuitGameScene` → quitter (`IntroScene.cs:117-120`) | Navigation | Non (vérifié absent) | — | — | Sans objet dans un navigateur ; voir I-11. | Accepté (Basse) |
| U-A16 | Boîte « QUIT GAME? » / « ARE YOU SURE YOU WANT TO QUIT? », boutons CANCEL / QUIT (`QuitGameScene.cs:16-27`) | Texte | Partiel | `BoardUI.gd:4338-4342` | Différent | Godot : « Quit to menu? The current game will be lost », YES, QUIT / NO, KEEP PLAYING, dans une liste et non dans la boîte à 2 boutons. | Corrigé (Moyenne) |
| U-A17 | `NextSceneType` (SinglePlayer, PassAndPlay, OnlinePublic, OnlinePrivate) | Enum | Partiel | `MG:341-342` | Partiel | Le mode « public » de Godot est un salon listé (voir U-C08). | Accepté (Basse) |
| U-A18 | Transitions : modale 0,2 s, normale 1,0 s (`DBMBaseScene.cs:17,19`) | Timing | Oui | `MG:112-126`, `UiKit.gd:25-27` | Oui | — | — |
| U-A19 | Son du bouton joué **à l'appui** (`ButtonBaseEntity.cs:185,202`) | Son | Oui | `MG:183,196`, `UiKit.gd:97-118` | Partiel | Godot le joue au relâchement (signal `pressed`). | Corrigé (Basse) |
| U-A20 | `StayPressed` : le bouton du menu reste enfoncé pendant le fondu (`ButtonBaseEntity.cs:201`) | Visuel | Non (vérifié absent) | `MG:187-198` | Différent | — | Corrigé (Basse) |
| U-A21 | Bouton à décor : +3 px à l'appui, −3 px au relâchement (`ButtonWithDecoratorEntity.cs:47-57`) | Visuel | Oui | `MG:265-270` | Partiel | L'APK finit 3 px plus haut ; Godot revient à l'origine. | Corrigé (Basse) |
| U-A22 | Texte de bouton blanc, or #cdb15f à l'appui (`ButtonWithLabelEntity.cs:21,32`) | Visuel | Oui | `UiKit.gd:111-116` | Oui | — | — |
| U-A23 | `HandMouseOverBehavior` (main au survol) | Comportement | N/A | — | N/A | Code mort : désactivé à la création, jamais réactivé. | — |
| U-A24 | Flèche retour `back_bt` (80 ; 70), son `ui_button_goback` (`ControlsFactory.cs:232-254`) | Élément | Oui | `MG:224-225` | Oui | — | — |
| U-A25 | Bouton OK, marges 120 / 70 (`ControlsFactory.cs:261-277`) | Élément | Oui | `MG:231-232` | Oui | — | — |
| U-A26 | Torches statiques, fond `menu_bg` (`ControlsFactory.cs:281,330-344`) | Élément | Oui | `MG:206-219` | Partiel | Positions justes ; Godot ajoute un scintillement alpha 0,78 ↔ 1. | Corrigé (Basse) |
| U-A27 | Petit logo `logo_small` 688×318, y 10 (`ControlsFactory.cs:292-315`) | Élément | Partiel | `MG:220-223` | Différent | Godot réduit `bm_logo` (540×218), sans le halo de `logo_small`. | Corrigé (Basse) |
| U-A28 | Logos « legend » si mécène (`ControlsFactory.cs:296-300`) | Élément | Non (vérifié absent) | — | — | Voir S-16. | Accepté (Basse) |
| U-A29 | Flèche du menu principal → intro, fondu 1,0 s (`MainMenuScene.cs:50-55,201`) | Navigation | Oui | `MG:277` | Oui | — | — |
| U-A30 | 4 boutons du menu principal : positions, icônes, texte ×1,5 (`MainMenuScene.cs:60-120`) | Élément | Oui | `MG:258-281` | Oui | — | — |
| U-A31 | SINGLE PLAYER : boîte TUTORIAL au premier lancement (`MainMenuScene.cs:62-84`) | Navigation | Oui | `MG:287-293,335-339` | Oui | Voir S-14. | — |
| U-A32 | `ConfirmationBoxScene` : voile 0,7, `winner_bg`, boutons à 0,35 / 0,65 L et 0,56 H (`:72-125`) | Écran | Oui | `MG:297-332` | Oui | — | — |
| U-A33 | Texte du bouton décalé de 3 px à l'appui (`ButtonWithLabelEntity.cs:25-28`) | Visuel | Non (vérifié absent) | `MG:323-326` | Partiel | — | Corrigé (Basse) |
| U-A34 | MULTIPLAYER → `MenuOnlineScene` **directement** (`MainMenuScene.cs:93-104`) | Navigation | Oui | `MG:279` → `OM:172-180` | Différent | Godot intercale l'écran `MultiplayerScene` (PLAY ONLINE / PASS AND PLAY), code mort dans l'APK. Même constat que U-C01. | Corrigé (Moyenne) |
| U-A35 | OPTIONS, fondu 1,0 s (`MainMenuScene.cs:107-113`) | Navigation | Oui | `MG:280` | Oui | — | — |
| U-A36 | IN-APP STORE → `InAppPurchaseScene` (`MainMenuScene.cs:114-120`) | Élément | Non (remplacé par RULES) | `MG:281` | Différent | Boutique retirée (voir U-B50). | Accepté (Basse) |
| U-A37 | Bande secrète, appui long à deux doigts de 2 s → `UnlockCodeScene` (`MainMenuScene.cs:121-139`) | Élément | Non (vérifié absent) | — | — | Voir I-09, U-B53. | Accepté (Basse) |
| U-A38 | `ShowButtons` (glissé BackEase 0,2 s) (`MainMenuScene.cs:176-197`) | Animation | N/A | — | N/A | Atteint seulement par le geste de déblocage : mort sans lui. | — |
| U-A39 | Bandeau « HOW MANY PLAYERS? » (`PlayerNumberScene.cs:29`) | Texte | Oui | `MG:227-229,345` | Oui | — | — |
| U-A40 | Flèche (coupure nette) et OK → extensions (fondu 1,0 s) (`PlayerNumberScene.cs:40,48-53`) | Navigation | Oui | `MG:344,352,380-385` | Oui | — | — |
| U-A41 | Carrousel infini : positions, échelles 0,7 / 0,77, ordre 2-3-4 (`CarrouselInfiniteComponent.cs:34-44`) | Layout | Oui | `MG:388-411` | Oui | Interaction : voir I-08. | — |
| U-A42 | Éventails de boss par nombre de joueurs : 2 (BMA006, 002), 3 (007, 004, 005), 4 (007, 002, 001, 006) (`ControlsFactory.cs:379-427`) | Visuel | Partiel | `MG:47,413-433` | Différent | Le nombre de cartes ne suit pas 2 / 3 / 4 joueurs (2 cartes si sélectionné, 3 sinon). | Corrigé (Moyenne) |
| U-A43 | Animations du carrousel : lerp 0,2 par image, échelle 0,7 → 1 en 0,3 s, fondus du chiffre (`PlayerNumberDeckEntity.cs:73-98`) | Animation | Non (vérifié absent) | `MG:392-411` | — | Changement de sélection instantané. | Corrigé (Basse) |
| U-A44 | Sons du carrousel : `ui_shuffle_left` / `ui_shuffle_right` à chaque cran (`CarrouselComponent.cs:123-131`) | Son | Oui | `MG:175-185,409` | Différent | **Contrôlé** : `_hit` joue `ui_button_select` par défaut. Mauvais son. Complète A-22. | Corrigé (Moyenne) |
| U-A45 | Chiffre central arcadepix ×3 (63 px), chiffres latéraux ×2 (`PlayerNumberSelectionEntity.cs:57-60`) | Texte | Oui | `MG:405-408` | Partiel | Police `FONT_B` 56 px au centre ; calé sur une capture. | Corrigé (Basse) |
| U-A46 | Sélection initiale = 2 joueurs à chaque entrée (`PlayerNumberScene.cs:32`) | État | Oui | `MG:56,346` | Différent | Godot mémorise le dernier choix. | Corrigé (Basse) |
| U-A47 | Version gratuite : paquets 3 / 4 grisés, « FULL GAME NEEDED! » (`PlayerNumberSelectionEntity.cs:104-120`) | Condition | Non | — | — | Tout est débloqué (décision connue). | Accepté (Basse) |
| U-A48 | — (absent de l'APK) 5 et 6 joueurs avec Crash Landing | Ajout Godot | Oui | `MG:346-348,388-389` | — | — | Conforme (Basse) |
| U-A49 | OPTIONS : 4 boutons TUTORIAL / SETTINGS / CARD GALLERY / CREDITS (`OptionsScene.cs:55-93`) | Écran | Oui | `MG:596-613` | Oui | — | — |
| U-A50 | TUTORIAL → tutoriel sans transition (`OptionsScene.cs:64-66`) | Navigation | Oui | `MG:598-601` | Oui | — | — |
| U-A51 | SETTINGS, fondu 1,0 s (`OptionsScene.cs:74-79`) | Navigation | Oui | `MG:604-607` | Oui | — | — |
| U-A52 | CARD GALLERY, fondu 1,0 s ; retour en coupure nette (`OptionsScene.cs:87-89`) | Navigation | Oui | `MG:610-612`, `CG:289-291` | Oui | — | — |
| U-A53 | CREDITS sans transition ; boutons et logo glissent et s'estompent puis reviennent (`OptionsScene.cs:99-103,132-153`) | Animation | Partiel | `MG:615-618,647-654` | Partiel | Masquage instantané ; au retour, fondu noir 1,0 s sans glissé. | Corrigé (Basse) |
| U-A54 | Flèche d'OPTIONS : coupure nette (`OptionsScene.cs:48`) | Navigation | Oui | `MG:584-589` | Oui | — | — |
| U-A55 | SETTINGS : lignes MUSIC / SOUND / GAME SPEED à y 360 / 480 / 600 (`SettingsScene.cs:68-97`) | Écran | Oui | `MG:639-643,657-680` | Oui | Valeurs : S-04..S-06. | — |
| U-A56 | Segments de 204 px, ninepatch `settings_text_bg`, bulle 204×110, polices ×1,4 (`SettingButtonDecorator.cs:21,71,102-112`) | Visuel | Partiel | `MG:663-680` | Différent | 202 px, aplat de couleur au lieu du ninepatch, tailles de police différentes. | Corrigé (Basse) |
| U-A57 | Valeur sélectionnée : texte doré décalé de −5 px sur un texte blanc (`SettingButtonInfo.cs:57`) | Visuel | Non (vérifié absent) | `MG:676` | Partiel | — | Corrigé (Basse) |
| U-A58 | Son seulement si l'option change, à l'appui (`SettingButtonDecorator.cs:132`) | Son | Oui | `MG:678-680` | Partiel | Joué à chaque clic, même sur l'option déjà choisie. | Corrigé (Basse) |
| U-A59 | Flèche de SETTINGS : `SaveChanges` puis `Pop()` **sans transition** (`SettingsScene.cs:133-145`) | Navigation | Oui | `MG:638-640` | Différent | **Contrôlé** : Godot fait un fondu noir de 1,0 s ; le commentaire `MG:637` cite à tort `:136`. | Corrigé (Moyenne) |
| U-A60 | Ligne LEGENDARY MODE si mécène (`SettingsScene.cs:98-108`) | Élément | Non (vérifié absent) | — | — | Voir S-08. | Accepté (Basse) |
| U-A61 | Crédits : `credits.json` (logo, 14 éléments, pied), mise en forme (`CreditsScene.cs:50,119-228`) | Écran | Oui | `CreditsScreen.gd:136-139,168-248` | Oui | Fichier identique à celui de l'APK. | — |
| U-A62 | Défilement des crédits : 0,1 px/ms, délais et bornes (`CreditRollBehavior.cs:38-77`) | Timing | Oui | `CreditsScreen.gd:15-22,38-61,104-108` | Oui | — | — |
| U-A63 | Voile 0,7, glisser actif après 8,8 s, bornes (`CreditsScene.cs:46-49,115-166`) | Comportement | Oui | `CreditsScreen.gd:77-83,110-125` | Oui | — | — |
| U-A64 | Flèche des crédits, fondu 1,0 s, `ui_button_goback` (`CreditsScene.cs:129-133`) | Navigation | Oui | `CreditsScreen.gd:94-102` | Oui | — | — |
| U-A65 | `MessageBoxScene` : titre, message, OK, fondu enchaîné 0,2 s (`:70-152`) | Écran | Oui | `OM:89-125` | Oui | — | — |
| U-A66 | Pseudo par défaut « player_ » + `RndWord(4)` sur a-z1-9, avatar `Random.Next(9)` (`StringFactory.cs:20-28`) | Donnée | Oui | `Profile.gd:38-43` | Oui | Alphabet identique : **S-13 clos**. | — |
| U-A67 | Cercle de 10 rupies, rayon 160, 1 s par cran, interpolation en corde (`CircleOfRotatingRupisBehavior.cs:26-64`) | Animation | Oui | `GameOverBanner.gd:12-14,70-76` | Partiel | Godot tourne en arc continu ; rayon ≈ −5 % à mi-cran dans l'APK. | Corrigé (Basse) |
| U-A68 | — (absent de l'APK) Écran RULES à la place de la boutique | Ajout Godot | Oui | `MG:281,683-689` | — | — | Conforme (Basse) |
| U-A69 | — Visionneuse des règles (4 livrets, onglets, flèches, molette) | Ajout Godot | Oui | `RulesViewer.gd:12-157` | — | — | Conforme (Basse) |
| U-A70 | — Case « Wiki expansions (not in the APK) » | Ajout Godot | Oui | `MG:620-628`, `Profile.gd:77,83` | — | **Contrôlé** : cochée par défaut (`Profile.gd:77,83` = `true`, alors que `MG:78` prévoit `false`). Au premier lancement, des contenus hors APK s'affichent (tuiles wiki, cartes wiki dans la galerie, mention 5-6 joueurs). | Corrigé (Moyenne) |
| U-A71 | — Champ « Multiplayer server » (bureau seulement) | Ajout Godot | Oui | `MG:76,629-636` | — | Masqué sur le web. | Conforme (Basse) |
| U-A72 | — Survol des boutons pierre (teinte) | Ajout Godot | Oui | `UiKit.gd:108-109` | — | Le survol de l'APK est du code mort (U-A23). | Conforme (Basse) |
| U-A73 | — Déverrouillage audio au premier clic | Ajout Godot | Oui | `AudioManager.gd:48,63-70` | — | Voir AW-01. | — |

### 4B — Galerie, détail de carte, extensions, écrans de boutique

Source relue : `GalleryScene`, `CardDetailScene`, `ExpansionScene`, `InAppPurchaseScene`, `PurchaseScene`, `UnlockScene`, `UnlockCodeScene`, `ScrollCard*`, `ScrollListBehavior`, `ExpansionScrollComponent`, `CardDetailEntity`, `CardEntity`, `LocalMarket`, `PurchaseItemButton`. Godot : `CG`, `MG`, `CardUI.gd`, `CardDB.gd`, `InGameMenu.gd`.

| ID | Élément source (décompilé) | Type | Présent dans Godot ? | Fichier Godot | Équivalent fonctionnel ? | Écart / Commentaire | Priorité |
|----|----|----|----|----|----|----|----|
| U-B01 | Entrée depuis OPTIONS, fondu 1,0 s (`OptionsScene.cs:83-90`) | Navigation | Oui | `MG:104-125,608-612` | Oui | — | — |
| U-B02 | Entrée depuis PAUSE, fondu enchaîné 0,2 s (`PauseScene.cs:61-70`) | Navigation | Oui | `InGameMenu.gd:106-115` | Oui | — | — |
| U-B03 | CARD GALLERY masqué dans le menu PAUSE en partie en ligne (`PauseScene.cs:30,41,61`) | Condition | Non (vérifié absent) | `InGameMenu.gd:43` | Différent | Godot l'affiche aussi en ligne. | Corrigé (Basse) |
| U-B04 | Flèche retour : coupure nette, ou fermeture si on vient du jeu, `ui_button_goback` (`GalleryScene.cs:93-98,335-345`) | Navigation / son | Oui | `CG:62-64,285-291` | Oui | — | — |
| U-B05 | Décor et titres BOSS / ROOM / SPELL / HERO / EPIC HERO CARDS (`GalleryScene.cs:99-149,363-392`) | UI / textes | Oui | `CG:19-20,45-61` | Oui | — | — |
| U-B06 | 5 onglets (dos de la 1re carte de chaque type), ordre Boss, Room, Spell, Hero, Epic (`GalleryScene.cs:177-210`) | UI | Oui | `CG:19-20,75-86` | Oui | — | — |
| U-B07 | Défilement vertical des onglets : course 596 px + 100 px de dépassement, ressort (`GalleryScene.cs:184-198`, `ScrollListBehavior.cs:207-252`) | Défilement | Partiel | `CG:66-74` | Différent | Course de 220 px, sans dépassement élastique. | Corrigé (Basse) |
| U-B08 | `ui_button_select` à chaque changement d'onglet (`GalleryScene.cs:352`) | Son | Non (vérifié absent) | `CG:124-185` | — | **Contrôlé** : le changement d'onglet est muet dans Godot. | Corrigé (Moyenne) |
| U-B09 | Transition entre onglets : fondu de sortie 0,5 s puis d'entrée 0,5 s, toucher bloqué pendant le fondu (`GalleryScene.cs:395-436`) | Transition | Non (vérifié absent) | `CG:124-185` | — | Godot reconstruit la grille instantanément. | Corrigé (Moyenne) |
| U-B10 | Onglet touché : échelle 0,37 → 0,42 en 0,2 s, cadre jaune en fondu 0,5 s (`GalleryScene.cs:190-191`, `ScrollItemComponent.cs:42-66`) | Animation | Partiel | `CG:124-137,189-208` | Partiel | Fondu du cadre présent ; changement de taille instantané ; l'ancien cadre disparaît d'un coup. | Corrigé (Basse) |
| U-B11 | Onglet BOSS sélectionné à l'ouverture (`GalleryScene.cs:471-475`) | Comportement | Non (vérifié absent) | `CG:99,122-123` | Non vérifié | Aucun cadre à l'ouverture côté Godot ; la capture APK de référence encadre HERO : source et capture se contredisent. | Corrigé (Basse) |
| U-B12 | Paquets affichés : base, Player Choice, puis Hidden Heroes ; BMA023 et BMA033 masquées (`GalleryScene.cs:153-156`, `CardInfoService.cs:19,58-65,184`) | Filtre | Oui | `CG:15-16,102-120` | Oui | Comptes recoupés dans `cards.json`. | — |
| U-B13 | — (absent de l'APK) Cartes des extensions wiki dans la galerie | Ajout Godot | Oui | `CG:104-105` | — | Affichées par défaut (voir U-A70). | Conforme (Basse) |
| U-B14 | Tri par numéro de carte décroissant, héros ordinaires / épiques séparés (`GalleryScene.cs:157-176`) | Ordre | Oui | `CG:112-119` | Oui | — | — |
| U-B15 | Une tuile par art alternatif pour salles et sorts (`ScrollCardBehavior.cs:40-82`) | Contenu | Oui | `CG:6-7,146-155` | Oui | Fichiers `b.webp` cohérents avec `AlternativeArts` de `data.json`. | — |
| U-B16 | Tuile héros : carte + personnage à y −10 (`ScrollCardBehavior.cs:114-127`) | Rendu | Oui | `CG:163` | Oui | Image déjà composée. | — |
| U-B17 | Grille : 2 lignes, case 310×410, échelle 0,8 (`GalleryScene.cs:177,438-455`) | Layout | Oui | `CG:21-22,156-171` | Oui | — | — |
| U-B18 | Défilement horizontal : inertie × 0,9 par image, dépassement de 100 px, ressort 0,4, bornes `-TotalWidth + 960` (`ScrollListBehavior.cs:193-252`, `GalleryScene.cs:452-453`) | Défilement | Partiel | `CG:87-91` | Différent | `ScrollContainer` natif : course plus courte d'environ 390 px, ni dépassement ni ressort. Complète I-17. | Corrigé (Moyenne) |
| U-B19 | — (absent de l'APK) Molette de la souris | Ajout Godot | Oui | `CG:92-97` | — | 220 px par cran ; risque de double défilement non testé. | Conforme (Basse) |
| U-B20 | Tap sur une carte : sélection (0,8 → 0,85, 0,2 s), cadre jaune 0,5 s, puis détail ; la sélection est gardée par onglet (`ScrollListBehavior.cs:160-183`) | Interaction | Partiel | `CG:173-181,210-227` | Partiel | Courbes linéaires au lieu de cubiques ; sélection perdue au changement d'onglet. | Corrigé (Basse) |
| U-B21 | Détail : la carte 350×488 va au centre et passe à l'**échelle 1,8** en 0,2 s, soit 630×878 (`CardDetailScene.cs:84-91`, `CardEntity.cs:56`) | Animation | Partiel | `CG:230-278` (`CARD * 1.8`) | Différent | **Contrôlé** : Godot multiplie la tuile (280×400) par 1,8, soit **504×720, 0,8× la taille APK** ; courbe quadratique au lieu de linéaire. | Corrigé (Moyenne) |
| U-B22 | Voile noir 0,7 dès l'ouverture, cadre `card_border_yellow` en fondu 0,3 s (`CardDetailScene.cs:45,87`) | Rendu | Partiel | `CG:240-261,274` | Partiel | Voile en fondu 0,2 s ; cadre doré dessiné au lieu du sprite. | Corrigé (Basse) |
| U-B23 | `ui_button_select` à l'ouverture du détail (`CardDetailScene.cs:88`) | Son | Oui | `CG:233` | Oui | — | — |
| U-B24 | `ui_button_goback` à la fermeture du détail (`CardDetailScene.cs:74`) | Son | Non (vérifié absent) | `CG:263-267,280-283` | — | Fermeture muette. | Corrigé (Moyenne) |
| U-B25 | Fermeture : tap sur le fond ou sur la flèche posée par-dessus le voile ; retour animé 0,2 s (`CardDetailScene.cs:53-56,69-82`) | Interaction | Oui | `CG:263-267,271-283` | Partiel | Tout clic ferme ; la flèche de la galerie reste assombrie sous le voile. | Corrigé (Basse) |
| U-B26 | Pas de retournement dans le détail | Comportement | Oui | `CG:230-269` | Oui | — | — |
| U-B27 | — (absent de l'APK) Infobulle avec le nom de la carte | Ajout Godot | Oui | `CG:168` | — | — | Conforme (Basse) |
| U-B28 | `CardDetailEntity` (zoom du carrousel de boss, `CardCarrouselEntity.cs:214`) | Entité | Non vérifié | — | — | Hors galerie : module 7. | — |
| U-B29 | `ScrollCardComponent.DisableScale` | Propriété | N/A | — | N/A | Jamais lue. | — |
| U-B30 | Citations APK dans les commentaires de `CG` | Traçabilité | — | `CG:123,131,178,188` | Différent | 4 citations fausses (lignes décalées). | Corrigé (Basse) |
| U-B31 | Solo : HOW MANY PLAYERS → SELECT EXPANSIONS, fondu 1,0 s (`PlayerNumberScene.cs:52`) | Navigation | Oui | `MG:352` | Oui | — | — |
| U-B32 | Pass and Play : extensions directement, 2 joueurs fixes (`MultiplayerScene.cs:77`) | Navigation | Oui | `OM:180`, `MG:352` | Différent | Chemin mort dans l'APK (U-C01) ; Godot ajoute le choix 2 à 6. | Accepté (Basse) |
| U-B33 | En ligne : `ExpansionScene(0, OnlinePublic/OnlinePrivate)` (`ExpansionScene.cs:129-160`) | Navigation | Partiel | `OM:292,629` | — | Voir U-C08, U-C11. | — |
| U-B34 | Décor `multiplayer_bg` sans torches en ligne (`ExpansionScene.cs:76-103`) | UI | Partiel | `MG:213-218,448-449` | Différent | Godot garde `menu_bg` et les torches. | Corrigé (Basse) |
| U-B35 | « SELECT EXPANSIONS », flèche (coupure nette), OK lance la partie (`ExpansionScene.cs:49-52,93-128`) | UI / navigation | Oui | `MG:227-232,449-464` | Oui | — | — |
| U-B36 | Liste : Power-Up Pack, Tools of Hero Kind, The Player Choice, Hidden Heroes (`LocalMarket.cs:23,108-147`) | Contenu | Partiel | `MG:15-28,463-477` | Différent | Godot ajoute une tuile BOSS MONSTER en tête, retire Power-Up Pack, ajoute les paquets wiki. | Corrigé (Basse) |
| U-B37 | Power-Up Pack : bande COMING SOON, non sélectionnable (`LocalMarket.cs:109-117`) | État | Non (vérifié absent) | — | — | Assets présents, inutilisés. | Corrigé (Basse) |
| U-B38 | Tools of Hero Kind : COMING SOON, grisé (`LocalMarket.cs:119-127`) | État | Partiel | `MG:12,480-489` | Différent | Jouable dans Godot (avec l'option wiki), sans bande. Choix délibéré. | Corrigé (Basse) |
| U-B39 | The Player Choice : achat requis ; texte « An 11-card digital mini-expansion… » (`LocalMarket.cs:129-139`) | État / texte | Partiel | `MG:17` | Différent | Toujours sélectionnable ; texte réécrit. | Accepté (Basse) |
| U-B40 | Hidden Heroes : verrouillé jusqu'à 40 victoires (`LocalMarket.cs:138-147`) | État | Partiel | `MG:18` | Différent | Voir S-12. L'APK affiche « 40 NEW HEROES » pour 41 cartes. | Accepté (Basse) |
| U-B41 | Sélection d'une tuile : `bg_expansion_selected`, échelle 1,0 → 1,1 en 0,3 s, **aucun son** (`PurchaseItemButton.cs:45-58`) | Animation / son | Partiel | `MG:175-184,480-506` | Partiel | Pas d'agrandissement ; Godot joue `ui_button_select`, absent de l'APK. | Corrigé (Basse) |
| U-B42 | Tuiles alignées à gauche, défilement horizontal dès 4 tuiles (`ExpansionScrollComponent.cs:84-240`) | Layout | Non (vérifié absent) | `MG:466-477` | Différent | Godot centre les tuiles et les réduit à 0,72 au-delà de 4, sans défilement. | Corrigé (Basse) |
| U-B43 | Lignes sous la tuile : « + 7 NEW BOSSES », « + 3 NEW HEROS »… (`+` et nombre en or) (`PurchaseItemButton.cs:94-103`) | Texte | Non (vérifié absent) | `MG:495-496` | Différent | Godot affiche une phrase blanche (« 7 bosses, 3 epic heroes, 1 spell »). | Corrigé (Moyenne) |
| U-B44 | Descriptions longues (`Info`, `DetailsExpanded`) montrées par `PurchaseScene` | Texte | Partiel | `MG:509-533` (popup « ? ») | Différent | Popup absent de l'APK, avec des textes réécrits au lieu de ceux de `LocalMarket`. | Corrigé (Moyenne) |
| U-B45 | Couvertures `full_game_front`, `tools_of_hero_front`, `the_players_choice_front`, `hidden_heroes_front` | Assets | Oui | `MG:487,527` | Oui | — | — |
| U-B46 | — (absent de l'APK) Tuile BOSS MONSTER du jeu de base | Ajout Godot | Oui | `MG:468,480-483` | — | — | Corrigé (Basse) |
| U-B47 | — (absent de l'APK) Tuiles des extensions wiki | Ajout Godot | Oui | `MG:20-27,445-447` | — | Affichées par défaut (U-A70). | Conforme (Basse) |
| U-B48 | — Choix des paquets mémorisé entre sessions (l'APK repart de zéro) | Ajout Godot | Oui | `MG:79,504`, `Profile.gd:88-95` | — | — | Conforme (Basse) |
| U-B49 | — Message d'erreur 5-6 joueurs | Ajout Godot | Oui | `MG:475-477` | — | — | Conforme (Basse) |
| U-B50 | `InAppPurchaseScene` : catalogue de 4 produits avec prix (`LocalMarket.StoreItems`) | Écran | Non (vérifié absent) | — | — | Boutique retirée. | Accepté (Basse) |
| U-B51 | `PurchaseScene` : fiche d'extension, « N WINS TO UNLOCK! », bouton PURCHASE (`PurchaseScene.cs:111-180`) | Écran | Non (vérifié absent) | — | — | Boutique retirée ; voir S-12. | Accepté (Basse) |
| U-B52 | `UnlockScene` : « CONGRATULATIONS! YOU'VE UNLOCKED… » (son `ui_purchase`), « FULL GAME NEEDED! » + BUY NOW! (`UnlockScene.cs:137,167`) | Écran | Non (vérifié absent) | — | — | Boutique retirée ; voir S-12, A-15. | Accepté (Basse) |
| U-B53 | `UnlockCodeScene` : saisie « INSERT REDEEM CODE », validation serveur, 4 messages d'erreur (`UnlockCodeScene.cs:60,98-139`) | Écran | Non (vérifié absent) | — | — | Voir I-09. | Accepté (Basse) |
| U-B54 | `MyScene` (debug) | Debug | N/A | — | N/A | Seul accès par un bouton `DEBUG_ELEM`. | — |

### 4C — Menus multijoueur (interface et parcours ; protocole au module 9)

Source relue : `MultiplayerScene`, `MainMenu.Online/*`, `MainMenu.Online.Entities/*`, `AvatarScrollComponent`, `OnlineAvatarComponent`, `OpponentsExpandBehavior`, gestionnaire MULTIPLAYER de `MainMenuScene`, messages de `OnlineService` / `DBMBaseScene`. Godot : `OM`, `MG`, `Profile.gd`, `OnlineClient.gd`, `CountDown.gd`, `server/Server.gd` (lecture seule).

| ID | Élément source (décompilé) | Type | Présent dans Godot ? | Fichier Godot | Équivalent fonctionnel ? | Écart / Commentaire | Priorité |
|----|----|----|----|----|----|----|----|
| U-C01 | `MultiplayerScene` (PLAY ONLINE / PASS AND PLAY) : **aucun appelant** (`MultiplayerScene.cs:37-93`) | Écran | Oui (ajout de fait) | `MG:279`, `OM:173-180` | Différent | **Contrôlé** : grep `MultiplayerScene` ne trouve que son propre fichier. Godot intercale un écran que l'APK n'affiche jamais. | Corrigé (Moyenne) |
| U-C02 | Pseudo vide → `ChangeNameAvatarScene(canGoBack:false)` avant le menu en ligne (`MainMenuScene.cs:93-104`) | Flux | Oui | `OM:176-179`, `Profile.gd:33-35` | Partiel | Test fait sur PLAY ONLINE ; `has_profile()` teste la présence de la clé et non une valeur non vide. | Corrigé (Basse) |
| U-C03 | Éventails de boss et ouverture animée (`MultiplayerScene.cs:41-47`, `OpponentsExpandBehavior.cs`) | Composant | Oui | `OM:165-238` | N/A | Écran mort côté APK. | — |
| U-C04 | PASS AND PLAY, 2 joueurs (`MultiplayerScene.cs:70-90`) | Fonction | Oui (ajout de fait) | `OM:180`, `MG:343-352,449-458` | Différent | Inatteignable dans l'APK ; Godot propose 2 à 6 joueurs. | Accepté (Basse) |
| U-C05 | Verrou `isFullGameAvailable` (`MultiplayerScene.cs:50-114`) | Logique | Non (vérifié absent) | — | N/A | Code mort. | — |
| U-C06 | `MenuOnlineScene` : WORLDWIDE / WITH FRIENDS / CHANGE USER/AVATAR, positions, fondu 1 s (`MenuOnlineScene.cs:35-75`) | Écran | Oui | `MG:112-130`, `OM:242-246` | Oui | — | — |
| U-C07 | Flèche du menu en ligne : déconnexion puis `Pop` sans transition (`MenuOnlineScene.cs:85-91`) | Flux | Oui | `OM:243` | Partiel | Revient à l'écran U-C01 et non au menu principal. | Accepté (Basse) |
| U-C08 | WORLDWIDE : appariement automatique (rejoint une salle publique compatible ou en crée une de 4) → salle d'attente (`MenuOnlineScene.cs:43-49`, `OnlineService.cs:631-644`) | Flux | Différent | `OM:244,252-302,445-461` | Différent | Godot affiche une liste de salons publics (JOIN) et CREATE PUBLIC GAME : pas d'appariement automatique. **Décision 2026-10-26 : multijoueur en salons uniquement.** | Accepté (Basse) |
| U-C09 | Erreur « Unable to join public rooms » sans paquets (`MenuOnlineScene.cs:50-53`) | Message | Non | — | N/A | Branche inatteignable ; le commentaire `OM:9` qui la décrit est faux. | — |
| U-C10 | WITH FRIENDS : NEW GAME / ROOM CODE, champ et OK en fondu (`WithFriendsOnlineScene.cs:44-126`) | Écran | Oui | `OM:592-630` | Oui | — | — |
| U-C11 | NEW GAME → extensions → salle privée de 4, sans choix du nombre de joueurs (`WithFriendsOnlineScene.cs:68-82`) | Flux | Oui | `OM:626-663`, `MG:343-352,455-459` | Partiel | Godot ajoute HOW MANY PLAYERS (2 à 6) ; après une erreur, retour à WITH FRIENDS au lieu de rester sur les extensions. | Corrigé (Basse) |
| U-C12 | Erreur « Unable to create a private room » (`WithFriendsOnlineScene.cs:77-80`) | Message | Non | — | N/A | Branche inatteignable. | — |
| U-C13 | Champ ROOM CODE : « INSERT ROOM CODE », sans limite, sensible à la casse (`WithFriendsOnlineScene.cs:131-136`) | Saisie | Oui | `OM:595-606` | Partiel | Godot limite à 4 caractères et passe en majuscules. | Corrigé (Basse) |
| U-C14 | Code de salle : 4 caractères a-z1-9 en minuscules (`OnlineService.cs:900-912`, `StringFactory.cs:20-29`) | Donnée | Oui | `server/Server.gd:14-15,292-297` | Différent | Godot : 4 lettres majuscules sans I ni O, pas de chiffres. | Corrigé (Basse) |
| U-C15 | Erreurs de jonction : « Invalid Code », « Room is full », « Unable to join private room » (`DBMBaseScene.cs:69-83`) | Message | Oui | `OM:665-682` | Oui | — | — |
| U-C16 | Erreur « Expansions not match » (`OnlineService.cs:661-666,936-937`) | Message | Non (vérifié absent) | — | — | Pas de contrôle des extensions possédées (sans achats, sans objet). | Accepté (Basse) |
| U-C17 | `TextEntryEntity` : cadre actif / inactif, texte d'aide effacé au focus, clic hors champ (`TextEntryEntity.cs:77-147`) | Composant | Oui | `OM:128-161` | Oui | Clavier virtuel : I-10. | — |
| U-C18 | `ChangeNameAvatarScene` : « INSERT USERNAME », « SELECT AVATAR », flèche seulement si retour possible (`ChangeNameAvatarScene.cs:53-113`) | Écran | Oui | `OM:568-588` | Oui | — | — |
| U-C19 | Pseudo : vide → rien n'est enregistré ; tronqué à 45 (`ChangeNameAvatarScene.cs:41-45,104-109`) | Logique | Oui | `Profile.gd:37-51`, `OM:136,584-587` | Partiel | Godot retire les espaces de bord : un pseudo fait d'espaces est refusé (l'APK l'accepte). | Corrigé (Basse) |
| U-C20 | Sélecteur : **8 avatars** hors mécène, 15 pour un mécène (`AvatarScrollComponent.cs:70-74`) | Donnée | Oui | `Profile.gd:12-15`, `OM:579` | Différent | **Contrôlé** : Godot en propose 9, dont `avatar_xyzax`, réservé aux mécènes dans l'APK. | Accepté (Basse) |
| U-C21 | Défilement des avatars : pas de 240, échelles 0,7 / 0,9 en 0,3 s, inertie, bornes (`AvatarScrollComponent.cs:56-191`) | Composant | Oui | `OM:466-565` | Oui | Constantes reprises ; bornes calculées sur 9 avatars au lieu de 8. | Accepté (Basse) |
| U-C22 | `OnlineAvatarComponent` : fonds `avatar_bg` / `avatar_bg_selected`, animation (`OnlineAvatarComponent.cs:27-99`) | Composant | Oui | `OM:497-525` | Oui | — | — |
| U-C23 | Salle d'attente : flèche = quitter la salle + `Pop` (`WaitingRoomBaseScene.cs:79-92,149-154`) | Flux | Oui | `OM:698-700,788-800` | Partiel | Godot retourne à WITH FRIENDS ou à la liste publique au lieu de l'écran précédent. | Accepté (Basse) |
| U-C24 | Panneau des joueurs : en-têtes WINS / DEFEATS, 4 lignes, « WAITING... » (`OnlinePanelEntity.cs:38-99`) | Écran | Oui | `OM:702-747,836-871` | Oui | Comptage : S-11. | — |
| U-C25 | Ligne en or = joueur **mécène** (`OnlinePanelEntity.cs:91`) | Affichage | Oui | `OM:853-871` | Différent | Godot met l'hôte en or ; commentaire `OM:835` faux. | Corrigé (Basse) |
| U-C26 | Salle privée : « WAITING FRIENDS... » et « ROOM CODE: » (`WaitingPrivateRoomScene.cs:27-29`, `RoomCodeEntity.cs:15-30`) | Écran | Oui | `OM:727,748-753` | Oui | — | — |
| U-C27 | Bouton OK de la salle privée : hôte seulement, visible à partir de 2 joueurs (`WaitingPrivateRoomScene.cs:30-62`) | Fonction | Oui | `OM:754-758,872-879` | Oui | — | — |
| U-C28 | Salle privée pleine : l'APK attend l'appui sur OK | Flux | Différent | `server/Server.gd:424-425` | Différent | **Contrôlé** : le serveur lance la partie dès que tous les sièges sont pris. | Corrigé (Basse) |
| U-C29 | Départ de l'hôte : Photon désigne un nouvel hôte (`WaitingPrivateRoomScene.cs:41-47`) | Flux | Différent | `server/Server.gd:404-407`, `OM:802-810` | Différent | Godot ferme la salle pour tous (« Room closed »). | Corrigé (Moyenne) |
| U-C30 | Salle publique : titre « SEARCHING PLAYERS... », pas de bouton OK, pas de code affiché (`WaitingPublicRoomScene.cs:47-52`) | Écran | Différent | `OM:716-727` | Différent | Godot réutilise la salle privée (titre = nom du salon, code et OK affichés). **Décision 2026-10-26 : multijoueur en salons uniquement.** | Accepté (Basse) |
| U-C31 | Minuteries de la salle publique : 45 s dès 2 joueurs, compte à rebours visible sous 10 s, ramené à 10 s à 4 joueurs, lancement automatique ; minuterie globale de 60 à 120 s qui change de salle (`WaitingPublicRoomScene.cs:27-143`) | Fonction | Non (vérifié absent) | — | — | **Contrôlé** (constantes relues). Aucun démarrage automatique : il faut l'hôte, START WITH BOTS ou une salle pleine ; un hôte inactif bloque la salle. **Décision 2026-10-26 : multijoueur en salons uniquement.** Sans appariement automatique, le démarrage automatique n'est plus requis. | Accepté (Basse) |
| U-C32 | `CountDownEntity` (sablier, chiffres or ×3) : **seulement en salle publique** (`CountDownEntity.cs:41-98`) | Composant | Différent | `CountDown.gd:1-50`, `MG:573-576` | Partiel | Godot en fait un décompte de tour en partie. | Accepté (Basse) |
| U-C33 | `ui_timer` en salle publique (`WaitingPublicRoomScene.cs:102-105`) | Son | Différent | `CountDown.gd:48-49` | Différent | **A-28 confirmé.** | Corrigé (Moyenne) |
| U-C34 | Déconnexion en salle d'attente : « Unable to join public room » et retour (`WaitingRoomBaseScene.cs:54-61`) | Message | Oui | `OM:802-810` | Partiel | Godot tolère les coupures brèves ; sinon autres messages, et reste parfois dans la salle. | Corrigé (Moyenne) |
| U-C35 | Texte « Unable to join public room » (`DBMBaseScene.cs:77-78`) | Message | Oui | `OM:457-461` | Différent | Textes Godot : « Unable to join public game », « Game is full », « This game is no longer open ». | Corrigé (Basse) |
| U-C36 | — (absent de l'APK) RESUME après rechargement de la page | Ajout Godot | Oui | `OM:631-632,684-694` | — | Voir S-20. | Conforme (Basse) |
| U-C37 | — START WITH BOTS (sièges vides remplis par l'IA) | Ajout Godot | Oui | `OM:759-762,872-874` | — | — | Conforme (Basse) |
| U-C38 | — Liste publique : filtre, titre de salon modifiable, statuts | Ajout Godot | Oui | `OM:285-334,716-725,780-786` | — | — | Conforme (Basse) |
| U-C39 | — Salles de 5 et 6 joueurs | Ajout Godot | Oui | `OM:25-27,650-653,702-714` | — | L'APK plafonne à 4. | Conforme (Basse) |
| U-C40 | — « SEAT TAKEN ELSEWHERE » (siège repris dans un autre onglet) | Ajout Godot | Oui | `MG:564` | — | — | Conforme (Basse) |

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

1. ~~U-A70 : l'option « Wiki expansions » doit-elle être décochée par défaut (`Profile.gd:77,83`), pour qu'un premier lancement montre exactement l'APK ?~~ Réponse (2026-10-27) : oui, décochée ; le solo doit être exactement l'APK.
2. ~~U-C08 / U-C30 / U-C31 : salons au lieu de l'appariement automatique ?~~ Réponse : oui, multijoueur en salons uniquement.
3. ~~U-C01 / U-A34 : faut-il retirer l'écran PLAY ONLINE / PASS AND PLAY (MULTIPLAYER mènerait directement au menu en ligne), et donc le Pass and Play, absent de l'APK ?~~ Réponse (2026-10-27) : on garde les fenêtres et le style du multijoueur, mais le Pass and Play sur un seul écran est remplacé par un salon (chaque joueur dans son navigateur). Lot 4.

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
| R-O04 | Graines 10-40, 2-4 joueurs (93 traces, run de stress hors rapport par défaut) | trace oracle | Oui | idem | Oui à 90/93 | **90/93**. Échecs s20-p2 et s28-p3 : l'IA oracle active Dracolich Lair après la sortie du dernier héros, fenêtre qu'un humain n'a pas (`GameBoard.IsAdventureInteractionTurn`, `GameBoard.cs:285-291`). s16-p4 : remélange sur pioche vide, ordre aléatoire absent de la trace. Les trois causes sont documentées dans `tools/parity/README.md:481-485` et reproduites à l'identique ; voir R-D90 pour le petit écart moteur révélé par s16-p4. | Accepté (Basse) |
| R-O05 | Couverture des cartes par les 24 traces par défaut (script sur `oracle-*.json` : `buildRoom`, `playRoomAbility`, `playSpell`, décisions `resolveTarget.owner`) | mesure | — | — | — | Salles construites 31/35, sorts joués 16/18, boss dont la capacité s'est déclenchée 13/15. **Jamais exercés** : BMA023 et BMA033 (jamais distribués par l'APK), BMA053 Teleportation, THK025 (injouable dans l'APK), THK021 et THK023 (salles sans capacité), KSA001 Kirax et KSA005 Scythe (boss jamais tirés). BMA025 All-Seeing Eye est construit mais jamais activé. | Accepté (Moyenne) |

**Limite de l'oracle.** L'oracle ne compare que ce que l'IA APK joue, et le harnais rejoue les coups APK dans Godot : une règle **plus permissive** côté Godot (un coup légal en trop) est invisible, et les chemins que l'IA ne prend pas (Freeze puis construction, Crushinator puis construction, sorts pendant un tour forcé, Soul Harvest sur un épique) ne sont pas mesurés. Les écarts Haute ci-dessous viennent tous de la lecture du code, contre-vérifiée à la main, **non reproduits** par une partie.

### 5A — Moteur de partie (lot D)

Sources : `DBMGameModel.Logic/GameBoard.cs` (GB), `Boss.cs`, `DungeonSlot.cs`, `PlayerInteractionBase.cs`, `GameBoardExtensions.cs`.

| ID | Élément source (décompilé) | Type | Présent dans Godot ? | Fichier Godot | Équivalent fonctionnel ? | Écart / Commentaire | Priorité |
|---|---|---|---|---|---|---|---|
| R-D01 | `GB.NextStep` : machine à 13 phases (GB:15-30, 302-460) | phases | Oui | M:1181-1253, CD:6-14 | Oui | 13 phases APK regroupées en 7 phases Godot ; transitions équivalentes. Exercé par l'oracle. | — |
| R-D02 | Setup_a : 5 salles + 2 sorts, `AvoidMulliganCondition` (GB:333-347, 883-915) | phase | Oui | M:1046-1097 | Oui | Mêmes seuils (≥ 4 avancées ou ≥ 4 du même trésor). Exercé. | — |
| R-D03 | Mulligan sans borne (GB:883-915) | règle | Oui | M:1062 | Oui | Godot borne à 100 itérations ; indiscernable. | Accepté (Basse) |
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
| R-D14 | Tri des défausses par `UniqueID` avant mélange (GB:1335-1349) | règle | Non vérifié (pas de grep de tri) | — | — | Sans effet : le mélange est aléatoire des deux côtés. | Conforme (Basse) |
| R-D15 | `RandomProvider.Shuffle` (graine) | technique | Oui | CD (`_rng`) | Différent | Mélange non reproductible par conception ; l'oracle rejoue les coups, pas les mélanges. | Accepté (Basse) |
| R-D16 | `ChooseCardTypeToDraw` (Boss:270) | méthode | Oui | RA:95 | Oui | Chemin mort des deux côtés (BMA023 dans `notInGameCards`, `CardInfoService.cs:19,184` ; M:71). | — |
| R-D17 | `PlayersPriorized` par PlayerId = XP décroissant (GameBoardExtensions:105-135) | règle | Oui | M:1224-1232, CD:286-297 | Oui | XP des boss APK uniques. | — |
| R-D18 | Pioche de début de tour par `InGamePlayersPriorized` (GB:360-393) | règle | Oui | M:1199-1220 | Différent | Godot pioche dans l'ordre des sièges. Masqué par l'oracle (sièges insérés par PlayerId) ; effet seulement si la pioche s'épuise entre deux joueurs du même tour. | Accepté (Basse) |
| R-D19 | `RevealAllRoomCards` itère `Players` en ordre de sièges (GB:928-970) | règle | Oui | M:1477-1504 (ordre XP) | Différent | Même masquage que R-D18. | Accepté (Basse) |
| R-D20 | Salle ordinaire par-dessus une salle (`DungeonSlot.CheckRoomCanBeBuilt`:81) | règle | Oui | BE:119-171, M:256-340 | Oui | Exercé. | — |
| R-D21 | Salle avancée : emplacement construit + trésor imprimé, pas sur une salle en attente | règle | Oui | BE:119-171 | Oui | | — |
| R-D22 | `CheckBuildRestriction` (Neanderthal Cave) | règle | Oui | BE:119-171, BE:156-158 | Oui | | — |
| R-D23 | 5 emplacements maximum | constante | Oui | CD:18 | Oui | | — |
| R-D24 | Limite de constructions (`Boss.BuildRoom`, `CheckMaxBuildRooms` UI qui défait la plus ancienne en attente) | règle | Oui | M:536-571, GM:90-102 | Oui | | — |
| R-D25 | `MaxBuildRoomLimit` remis à 1 seulement dans `DeactivateLastActivePlayer` (GB:1213-1218) | règle | Oui | M:1181 (effets remis à zéro à `_start_turn`) | Différent | L'APK garde la valeur d'un tour à l'autre pour les joueurs déjà passés ; Godot remet tout à zéro. Voir R-D26, R-D27. | Conforme (Moyenne) |
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
| R-D47 | Fenêtre après dégâts : l'APK a déjà tué un héros à hp ≤ 0 | règle | Oui | M:1948-1973 | Non vérifié | Godot garde le héros jusqu'à la fin de la pause ; je n'ai pas confirmé si un sort peut alors viser un héros à 0 PV (SE:100-111 ajoute +3 PV sans test). | Corrigé (Moyenne) |
| R-D48 | `Hero.Deal` borne à 0 | règle | Oui | M:1928-1946 | Oui | | — |
| R-D49 | Emplacement désactivé sauté | règle | Oui | M:1878-1881 | Partiel | Godot saute sans ouvrir la fenêtre de sorts. | Accepté (Basse) |
| R-D50 | `ChooseNextActiveHero`, `ForceSkipAdventure` (Trepidation) | règle | Oui | M:1975-2006 | Oui | | — |
| R-D51 | `ChooseNextActivePlayer`, `DeactivateLastActivePlayer` (GB:1185-1218) | méthode | Oui | M:1987 | Oui | | — |
| R-D52 | `IsAdventureInteractionTurn` bloque l'UI sans héros actif (GB:285) | méthode | Oui (côté UI) | `BoardUI._my_moves`, `Match.apk_active_hero()` (README parité:485) | Oui | Règle portée par l'interface, comme l'APK ; `legal_moves` reste permissif pour le rejeu. Golden `_t_apk_active_hero_ui_gate`. | — |
| R-D53 | `Boss.IsAlive = Wounds < 5 && !IsManuallyKilled` (Boss:82) | propriété | Oui | M:2060-2063 (`eliminated`) | Partiel | Drapeau collant côté Godot, recalcul en direct côté APK. Écart seulement si les blessures baissent après élimination. | Accepté (Basse) |
| R-D54 | `KillManually` au départ d'un joueur en ligne (GB:855) | méthode | Oui | `server/GameRoom.gd:156` | Différent | Godot donne le siège à l'IA. Choix de conception, renvoyé au module 9. | Accepté (Basse) |
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
| R-D67 | Activation de salle par l'utilisateur ouvre une Spell Battle (GB:812) | méthode | Oui | RA:128-181 | Oui | Une activation est une entrée de pile (`Match` : `activateRoom`, `RoomAbilities.make_entry`) ; chaque autre joueur a sa fenêtre de réponse, elle se résout au dernier `pass` (`RoomAbilities.run_queued`). Harnais : la pile réelle remplace `_held`. | Corrigé (Moyenne) |
| R-D68 | Le sort quitte la main vers la défausse au lancement (GB:751-783) | règle | Oui | M:1714 | Partiel | Godot défausse à la résolution ; ne change qu'un remélange pendant la bataille. | Accepté (Basse) |
| R-D69 | `RemoveHeroFromGame`, `RemoveRoomOrSpellFromGame`, `DestroyRoom` (GB:624, 694-749, 835) | méthode | Oui | BE:518-580 | Oui | `destroy_room` décale bien les effets indexés. Voir R-D90 pour l'ordre défausse / déclencheur. | — |
| R-D70 | `DiscardFromHand`, `DrawRooms`, `DrawSpells` | méthode | Oui | CD:93 | Oui | | — |
| R-D71 | `ReactivateAllRooms`, `RestoreDungeon` (GB:1051, Boss:235) | méthode | Oui | SE:8 (`empty_effects`), M:1210-1214 | Oui | Godot remet à zéro au début du tour suivant ; état équivalent pour la fin de partie (évaluée avant). | Conforme (Basse) |
| R-D72 | `GetOpponents`, `GetOwnerPlayer`, `OpponnentDungeonSizeMoreThan` | méthode | Oui | BE:26-35 | Oui | | — |
| R-D73 | `PlaySpell`, `SetSpellBattleReady`, `OnAbilityApplyDone` | méthode | Oui | M:580-617, 684-731 | Oui | | — |
| R-D74 | `HeroResistDamageRoomType` (KSA016) | commande | Oui | BE:484-488 | Oui | | — |
| R-D75 | `GetFewestSoulsPlayer` (GB:1270) | code mort APK | N/A | — | — | Aucun appelant. | — |
| R-D76 | `TempNextGamePhase`, `CurrentNextStep` | code mort APK | N/A | — | — | Jamais lus. | — |
| R-D77 | `Boss.Print*`, `Boss.ActiveItem` / `DiscardItems`, `Room.IsAbilityUsed`, `DungeonSlot.BuffDamage` | code mort APK | N/A | — | — | Clonés ou hachés, jamais lus. | — |
| R-D78 | Triche `Cheat*` (GB:472-527), `DEBUG_ELEM` | debug APK | N/A | — | — | Derrière une UI de debug. | — |
| R-D79 | `SerialHelper`, `ActivationResponses`, `CryptoProvider`, `GetHashBytes` (GB:1363) | licence / synchro | N/A | — | — | Godot est autoritaire côté serveur ; renvoyé aux modules 9 et 10. | — |
| R-D80 | `DBMGameModel.Info/*` (`AIRoomInfo`, `AISpellInfo`) | données IA | Oui | `ApkAI.gd` | Oui | Renvoyé au module 6. | — |
| R-D81 | Tutoriel : pioches imposées (GameBoardExtensions:19-52) | règle | Oui | GM:22-55 | Partiel | Le reste est tiré avec une graine fixe différente de l'APK. Renvoyé au module 8. | Accepté (Basse) |
| R-D82 | — (code Godot hérité) `GameManager.calculate_lure`, `advance_hero_in_dungeon`, `Match._turn_order` | code mort Godot | Oui | GM:150-201, M:1564 | — | Aucun appelant ; `advance_hero_in_dungeon` est de plus faux (blessures prises pour des PV). À supprimer. | Corrigé (Basse) |
| R-D83 | — (ajout Godot) 5-6 joueurs (CRL « big game ») | ajout | Oui | M:17-35, CD:24 | — | Derrière la case wiki. | — |
| R-D84 | — (ajout Godot) fin `no_more_heroes` | ajout | Oui | M:2140-2166 (`not apk_only`) | — | | — |
| R-D85 | — (ajout Godot) partage de leurre CRL | ajout | Oui | BE:235 | — | | — |
| R-D86 | — (ajout Godot) `_check_end_big_game` | ajout | Oui | M:2180 | — | | — |
| R-D87 | — (ajout Godot) TNL, RMB, THK wiki, IOD | ajout | Oui | `TnlAbilities.gd`, `Minibosses.gd`, `RmbAbilities.gd`, `ThkAbilities.gd`, `IodAbilities.gd` | — | Hors périmètre APK. | — |
| R-D88 | — (ajout Godot) vote des rois | ajout | Oui | M:1388 | — | | — |
| R-D89 | — (ajout Godot) annulation de pose, sauts automatiques de fenêtre | ajout | Oui | M:416-451, 1299 | — | | — |
| R-D90 | `DestroyRoom` défausse la salle **avant** le déclencheur `WhenAnotherRoomIsDestroyed` (GB:840-851) | règle | Oui | BE:518-593 (`destroy_room`, `_on_other_room_destroyed`) | Partiel | Godot déclenche Recycling Center avant que l'appelant défausse la salle détruite. Invisible sauf pioche de salles vide (1 carte d'écart au remélange). Mis en évidence par s16-p4 (R-O04), documenté `tools/parity/README.md:482`. | Accepté (Basse) |

### 5B — Système de capacités (lot E)

Sources : `DBMGameModel.Logic.Abilities.*` (Commands, Targets, Conditions, LuredConditions, Triggers) et `GameBoard`. Les lignes de famille regroupent les éléments relus ; les éléments jamais référencés par un `data.json` APK sont classés « Sans objet ».

| ID | Élément source (décompilé) | Type | Présent dans Godot ? | Fichier Godot | Équivalent fonctionnel ? | Écart / Commentaire | Priorité |
|---|---|---|---|---|---|---|---|
| R-E01 | Dégâts salle / héros (`DealDamageToRoom`, `IPassiveDamage`) | commandes | Oui | BE:377-493, BE:518-580 | Oui | Montants concordants dans toutes les traces. | — |
| R-E02 | `DeactivateDungeonAbility` (Trap Master KSA017), `Ability.IsLocked` | commande | Oui | BE:341-350, RA:141-142 | Oui | Verrou levé à la sortie du héros, comme `RemoveHeroFromGame` (voir R-F69). | Conforme (Basse) |
| R-E03 | `ReactivateAllRooms` / `Boss.RestoreDungeon` | commande | Oui | M:1210-1214 | Oui | Remise à zéro au début du tour suivant au lieu de la fin du tour ; aucun écart observé. | Conforme (Basse) |
| R-E04 | `ChooseCardFromHand`, `FlipItem`, `PlaceAtOwnerDungeonEntrance`, `SkipBeginingOfTurn` | commandes | N/A | M:1261-1262 | — | Aucune carte APK ne les utilise ; `FlipItem.Execute` lève `NotImplementedException`. | Accepté (Basse) |
| R-E05 | `chooseDraw`, `SwapSlotInDungeon` | commandes | Oui | RA:95, RA:738, M:1215-1243 | Oui | BMA023 et BMA033 jamais distribuées (R-D16). Golden seulement. | Conforme (Basse) |
| R-E06 | Pioche et remélange (`DrawCards`, `ReShuffleDiscardsPilesBackToDeck`) | commandes | Oui | M:1256-1259, CD (`draw_pile`) | Oui | | — |
| R-E07 | Destruction et défausse de salle | commandes | Oui | BE:518-595 | Oui | Voir R-D90. | — |
| R-E08 | Trésors et âmes (`IPassiveTreasure`, `IPassiveScorekeep`, `RemoveHeroFromTheGame`) | commandes | Oui | CD:215-251, BE:61-86 | Partiel | Voir R-F21 (Soul Harvest) et R-F23 (passifs dans Trepidation). | voir R-F21 |
| R-E09 | 16 sorts BaseDeck | commandes | Oui | SE (`cast_spell`) | Partiel | Détail carte par carte en 5C. | — |
| R-E10 | Autres Commands (≈ 40 sur 49) | commandes | Non vérifié (ligne à ligne) | — | — | Couvertes indirectement par 5C : chaque carte APK y est tracée avec ses commandes. | Accepté (Basse) |
| R-E11 | `HeroInDungeon` : `EntranceQueue.Take(1)` par donjon (`HeroInDungeon.cs`, `InternalGetAvailableTargets`) | cible | Oui | ST:116-136, ST:299-322 | **Différent** | Vérifié : Godot propose **tous** les héros de l'entrée, l'APK seulement le premier de chaque donjon. Touche BMA041 Assassin, BMA044 Exhaustion, BMA045 Fear. L'IA ne choisit que le premier, donc invisible pour l'oracle ; un humain peut viser un héros que l'APK n'offre pas. | Corrigé (Moyenne) |
| R-E12 | Cibles de salle (`RoomInDungeon`, `AdjacentsRoom`, `NextRoom`, `AnotherRoom`) | cibles | Oui | BE:45-47, ST:39-47 | Oui | | — |
| R-E13 | Comptage de Monster's Ballroom | cible | Oui | BE:406-411 | Différent | Doublon de R-F36. | voir R-F36 |
| R-E14 | Cible de Robobo (`BossOpponents` → `ChooseAndDestroyRoom`) | cible | Oui | RA:833, RA:1089-1103 | Non vérifié | Le lot E signale que Godot ne retire pas les salles gelées des choix ; je n'ai pas confronté au C# de `ChooseAndDestroyRoom`. Le lot F (R-F04) ne relève pas d'écart. | Corrigé (Moyenne) |
| R-E15 | `BossOpponentWithAtLeastHand`, `CrossingHeroAtachedItem`, `HeroInDeck`, `ItemInScorekeep`, `ItemInTown` | cibles | N/A | — | — | Inutilisées dans les `data.json` APK. | Accepté (Basse) |
| R-E16 | Autres Targets (≈ 25 sur 33) | cibles | Non vérifié (ligne à ligne) | — | — | Couvertes indirectement par 5C. | Accepté (Basse) |
| R-E17 | Re-vérification de condition à l'exécution (Motivation `OpponnentDungeonSizeMoreThan`) | condition | Oui | M:1299-1305, BE:30-36 | Partiel | Ne re-vérifie pas exactement au même moment. Aucun écart observé (6 jeux de Motivation). | Corrigé (Moyenne) |
| R-E18 | Kobold Strike : bloque les constructions | condition | Oui | SE:307, M:296 | Différent | `buildBlocked` retire aussi les sorts de phase Build (M:296), l'APK seulement les constructions. | Corrigé (Moyenne) |
| R-E19 | Liger's Den : `YouPlaySpellCard` + `OncePerTurn` | condition | Oui | M:1745-1750 | Partiel | Godot ne teste pas l'état gelé ni le verrou Trap Master avant de piocher. | Corrigé (Moyenne) |
| R-E20 | `HeroHasAtachedItem`, `OpponnentHasMoreThanInHand`, `OwnerHasFewerThanOpponent` | conditions | N/A | — | — | Inutilisées. | Accepté (Basse) |
| R-E21 | Conditions de leurre utilisées | leurre | Oui | BE:176-229, M:1537-1562 | Oui | | — |
| R-E22 | `LuredBySouls`, `LuredByCardsInHand` | leurre | N/A | — | — | Inutilisées (= R-D41). | Accepté (Basse) |
| R-E23 | `WhenYouBuildThisRoom`, `WhenYouBuildAnotherRoom` | déclencheurs | Oui | M:1477-1504, RA:528, RA:577 | Oui | Ordre inverse de `EnqueueAbilityTransaction` reproduit (M:1499). | — |
| R-E24 | `HeroDiesInThisRoom` | déclencheur | Oui | RA:607-630 | Partiel | Voir R-D46 (salle déclenchée après `DealHero`) et R-F26 (`OncePerTurn` consommé trop tôt). | voir R-D46 |
| R-E25 | `AnySpellCardIsPlayed`, `HeroDiesAnotherRoom`, `WhenOpponentPlaysSpellCard`, `WhenThisRoomIsDestroyed` | déclencheurs | N/A | BE:584 | — | Inutilisés dans les `data.json` APK. | Accepté (Basse) |
| R-E26 | `EnqueueAbilityTransaction` : capacités de salle mises en file | pile | Oui (autre forme) | RA:128-181, M:1573-1760 | Oui | Sorts et capacités de salle passent par la même pile (`_stack_insert_index`) ; seule All-Seeing Eye reste immédiate : sa transaction se résout avant le sort qu'elle annule. | Corrigé (Moyenne) |
| R-E27 | `RemovePendingTransactionsByTarget` : annule les transactions dont la cible a quitté le jeu (`GameBoard.cs:1351-1361`, appelée GB:606, 618, 743, 843) | pile | Non (vérifié absent) | M:1701-1740 | **Différent** | Vérifié : seul Counterspell marque `canceled`. Les sorts visant un héros (`heroId`) ratent sans dégât si le héros est parti. Les sorts visant par **indice** (`roomIndex`, `townIndex`, `soulIndex`) ne sont jamais annulés et frappent ce qui occupe l'indice. Rare : il faut deux sorts empilés sur la même zone. | Corrigé (Moyenne) |
| R-E28 | Contre-sort (`CancelSpellAbility`, All-Seeing Eye) | pile | Oui | M:1728-1734, RA:237-251 | Oui | Le lot E citait les échecs s16-p4, s20-p2, s28-p3 ; contre-vérifié : ce sont une course de l'IA oracle et un remélange (R-O04), pas le contre-sort. 7 Counterspell joués, 0 écart. | Conforme (Basse) |
| R-E29 | `OncePerTurn` : `IsEffectApplied` posé à `Run` (`Ability.cs:135`, `OncePerTurn.cs:12`) | pile | Oui | RA:139, RA:167, RA:180 | Oui | `usedThisTurn` est posé à l'exécution de la transaction, pas à la mise en file ; une transaction annulée ou qui échoue ne le consomme pas, et `Room.CanPlayerPlayAbility` (`RoomAbilities.is_queued`) interdit une 2e mise en file. | Corrigé (Moyenne) |
| R-E30 | Autorésolution d'une cible unique (`TryToAutoresolve`) | pile | Oui | ST:51, RA:1056-1085 | Oui | Seul appel : `PlayerInteractionBase.ResolveTarget:39`, gardé par `tryToAutoresolveTargets`, vrai pour `HumanPlayerInteraction.cs:48` et `RemotePlayerInteraction.cs:69` seulement (l'IA ne l'a pas). `SingleTargetProvider` (l.16-40) : pas d'interaction requise, ou `Count() <= TargetsAmount` ; `ComposedTargetProvider` (l.35-52) : un seul propriétaire ET `Count() <= TargetsAmount`. Revu tous les choix du moteur (`RoomAbilities`, `Minibosses`, `RmbAbilities`, `SpellEffects`, `TnlAbilities.ask`) : tous se résolvent déjà seuls à une option (sorts : le clic sur la carte joue direct quand un seul coup est légal, `BoardUI._play_from_hand`), et une mesure sur 63 traces d'oracle (graines 10-30, 2-4 joueurs) n'a trouvé aucun choix ouvert avec une seule option. Un seul trou : Hellcow (`BossDungeon`, un seul donjon candidat) gardait le choix d'ordre. L'APK prend alors les salles d'office dans l'ordre de `GetAvailableTargets` (`source.Reverse()`) et `RearrangeDungeon.Execute` INVERSE le donjon ; Godot le fait désormais pour un siège humain (`rearrange_choice`, `isAI` faux et `autoAI` vrai), pas pour l'IA ni le harnais (même distinction que X-M32, sinon les traces divergent). Cartes jamais distribuées (BMA033) et choix « may » des extensions du wiki (Alien Excavator, Mando, vote de The King) laissés tels quels : ce ne sont pas des cibles APK. Golden `_t_levelup_hellcow` (humain : donjon inversé d'office). | Corrigé (Moyenne) |
| R-E31 | `OnAbilityApplyDone` (déclencheurs après sort) | pile | Oui | SE (`cast_spell`), M:1743-1752 | Non vérifié | | Conforme (Moyenne) |

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
| R-F18 | BMA049 Kobold Strike : `UndoBuildRoom` + `SkipBuildPhase` | sort | Oui | SE:306-329 | Partiel | Durée (R-D26) et blocage des sorts Build (R-E18). Oracle 1× (1). | Conforme (Moyenne) |
| R-F19 | BMA050 Motivation : `OpponnentDungeonSizeMoreThan(1)` → `BuildExtraRoom` | sort | Oui | SE:140-146, BE:24-36 | Partiel | Report au tour suivant (R-D27). Oracle 6× (6). | Conforme (Moyenne) |
| R-F20 | BMA051 Princess in Peril : `HeroInTown` → `PlaceAtDungeonEntrance` | sort | Oui | SE:222-236, ST:137-139 | Oui | Oracle 12× (9). | — |
| R-F21 | BMA052 Soul Harvest : `HeroInScorekeep(Owner, Dead)` → `RemoveHeroFromTheGame` + `DrawCards(2, Spell)` | sort | Oui | SE:245-264, ST:168-172, ST:341-347, RA:1167 | **Différent** | Vérifié : un épique mort laisse 2 entrées d'âme (`RoomAbilities.gd:1167`, `CardDB.soul_entry` = 1 âme chacune) ; `_soul_harvest` n'en retire qu'une (`souls.remove_at(idx)`, SE:257). L'APK retire le héros entier de `SoulsHeroes` (`GameBoard.cs:694-731`). Un humain qui vise un épique ne perd qu'1 âme au lieu de 2. L'IA APK ne vise que des ordinaires (`ApkAI._chk_052`), donc invisible. Oracle 1× (1). | **Haute** |
| R-F22 | BMA053 Teleportation : `ActiveHeroInDungeon(Owner)` → `MoveHeroToRelativeSlot(5)` | sort | Oui | SE:268-275, ST:126-129, ST:380-390 | Oui (lecture) | **Jamais joué** dans les 24 traces ; golden `_t_apk_teleportation_*` seulement. | Conforme (Basse) |
| R-F23 | BMA054 Trepidation : `BossOpponentWithAtLeastScore(Dead, 2)` → `SkipAdventurePhase` | sort | Oui | SE:333-346, ST:160-167, ST:251-255 | Partiel | `Boss.Souls` inclut `CalculatePassiveSouls` (`Boss.cs:103-110`) ; `ST._souls_total` ne somme que les entrées `souls`, sans KSA006 Jarin ni T.P.K. (`CardDB.total_souls` les inclut). Cibles légales fausses avec PlayerChoice. Oracle 4× (4). | Corrigé (Moyenne) |
| R-F24 | BMA055 Zombie Attack : `HeroInScorekeep(Opponent, Dead)` → `SendBackToDungeonEntrance` + `DealHero(-2)` | sort | Oui | SE:350-403, ST:173-182 | Oui | PV de base + 2. Oracle 7× (6). | — |

#### Salles BaseDeck

| ID | Élément source (décompilé) | Type | Présent dans Godot ? | Fichier Godot | Équivalent fonctionnel ? | Écart / Commentaire | Priorité |
|---|---|---|---|---|---|---|---|
| R-F25 | BMA009 Dark Altar (activée) : `DestroyRoom` ; `CardInDeck(1, DiscardPile)` → `PutCardInHand` | salle | Oui | RA:169, RA:188-203 | Oui | Oracle 24× (15). | — |
| R-F26 | BMA010 Open Grave : `HeroDiesInThisRoom`, `OncePerTurn`, `RoomInDeck(DiscardPile)` | salle | Oui | RA:607-630, RA:754-764 | Partiel | `usedThisTurn` posé avant de savoir s'il y a une cible (RA:621-623) ; l'APK ne consomme `IsEffectApplied` que si la condition passe. Un 2e héros mort le même tour après un ajout à la défausse : déclenche en APK, pas en Godot. Oracle 12× (8). | Corrigé (Basse) |
| R-F27 | BMA011 Specter's Sanctum : `WhenYouBuildThisRoom` → `DiscardRandomCardFromHand(1, Spell)` | salle | Oui | RA:544, RA:639-650, RA:801 | Oui | Oracle 30× (20). | — |
| R-F28 | BMA012 Succubus Spa : `HeroDiesInThisRoom`, `PickRandomCardFromHand` | salle | Oui | RA:626, RA:654-691 | Oui | Oracle 3× (3). | — |
| R-F29 | BMA013 Dracolich Lair (activée) | salle | Oui | RA:176, RA:388-431 | Oui | Oracle 50× (17). | — |
| R-F30 | BMA014 Vampire Bordello : `HeroDiesInThisRoom`, `FlipHero` | salle | Oui | RA:629, RA:782-793, BE:306-330 | Partiel | Même `OncePerTurn` prématuré que R-F26. Oracle 4× (4). | Corrigé (Basse) |
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
| R-F41 | BMA025 All-Seeing Eye (activée) : `LastSpellPlayed` → `CancelSpellAbility` | salle | Oui | RA:170, RA:208-251 | Oui (lecture) | **Jamais activée** dans les 24 traces. | Conforme (Basse) |
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
| R-F59 | KSA001 Kirax : `AddTreasuresToDungeon` (passif) | boss | Oui | BE:81-86 | Oui (lecture) | **Jamais tiré** dans les traces. | Conforme (Basse) |
| R-F60 | KSA002 Hellcow : `RearrangeDungeon` | boss | Oui | RA:928-982 | Oui | Oracle 1× (1). | — |
| R-F61 | KSA003 The Brothers Wise : `SpellInDeck` → `PutCardInHand`, facultatif | boss | Oui | RA:904-912, M:926 | Oui | Oracle 1× (1). | — |
| R-F62 | KSA004 Kaw'nee : `HeroInScorekeep(Opponent, Dead, Ordinary)` → `PlaceAtScorekeep` | boss | Oui | RA:913-927, M:933-942 | Oui | Oracle 2× (2). | — |
| R-F63 | KSA005 Scythe : `LastRoomDealDamage(3)` (passif) | boss | Oui | BE:471-476 | Oui (lecture) | **Jamais tiré**. | Conforme (Basse) |
| R-F64 | KSA006 Jarin : `AddSoulsToBoss(1)` (passif) | boss | Oui | CD:224-231 | Oui | Oracle 3× (3). Voir R-F23. | — |
| R-F65 | KSA007 Elicon : `MultiplyTreasuresDungeon(2)` | boss | Oui | RA:901-903 | Oui | Oracle 1× (1). | — |
| R-F66 | KSA013 T.P.K. : `AddSoulsToBossIfTreasures(2, …)` | sort | Oui | SE:408-418, CD:233-251, ST:146-153 | Oui | Oracle 2× (2). | — |
| R-F67 | KSA014 Demigod : `LuredByWounds` | héros | Oui | BE:199-201 | Oui | Présent dans 6 traces. | — |
| R-F68 | KSA016 Monster Hunter : `HeroResistDamageRoomType(1, Monster)` | héros | Oui | BE:484-488 | Oui (lecture) | Passif non isolé dans les traces. | Conforme (Basse) |
| R-F69 | KSA017 Trap Master : `ThisHeroEntersDungeon` → `DeactivateDungeonAbility` | héros | Oui | BE:341-350, BE:397-401, RA:141-142, M:2018 | Oui | Oracle 4× (4). | — |

#### ToolsHeroKind et HiddenHeros

| ID | Élément source (décompilé) | Type | Présent dans Godot ? | Fichier Godot | Équivalent fonctionnel ? | Écart / Commentaire | Priorité |
|---|---|---|---|---|---|---|---|
| R-F70 | THK021-024 : 4 salles avancées, `Ability` nulle | salle | Oui | `ThkAbilities.gd:617-620`, RA:147-148 | Oui | Inertes comme l'APK hors case wiki. THK022 et THK024 construites 1×. | — |
| R-F71 | THK025 Excavation : `Ability` nulle | sort | Oui | CD:315 | Oui | Injouable comme l'APK (`thkLive` seulement avec la case wiki). | — |
| R-F72 | THK001-020 : 20 objets sans capacité | objet | Oui | M:100-130 | Oui | Révélés sans effet, comme `RevealItems`. | — |
| R-F73 | BMH056-079 : 24 ordinaires, `ReplacesCardNumber` = BMA056-079 | héros | Oui | M:73-78, CD:264-272 | Oui | Stats identiques. | — |
| R-F74 | BMH080 The Fool | héros | Oui | CD:272 | Oui | | — |
| R-F75 | BMH081-096 : 16 épiques | héros | Oui | idem | Oui | 29 des 41 BMH présents dans les traces (les héros 4 joueurs manquent : aucune trace 4 joueurs avec ce paquet). | Conforme (Basse) |
| R-F76 | BMH056-096 : `Description = ""` dans `HiddenHeros/data.json` ; nom et texte imprimés dans l'image | texte | Texte faux | `cards.json heroes[BMH056..096].description` | Non (texte seul) | Ce n'est pas un décalage entre cartes : Godot recopie le texte des BMA de même numéro (« Nick the Masher » pour BMH056), alors que l'image montre un autre personnage (« Everel the Healer » pour BMH056, « Brother Ben » pour BMH057, « Patrik Cogstopper » pour BMH096). Aucune règle touchée. Texte jamais affiché : `description_text` (`CardData.gd:52`) n'a aucun lecteur (vérifié au module 11, G-07). Les vrais noms ne sont que dans les images ou les `.wpk` non décodés. Renvoyé au module 11. | Accepté (Basse) |

### Non vérifié (module 5)

- Aucun écart Haute n'a été **reproduit** par une partie : ils viennent de la lecture du C# et du GDScript, contre-vérifiée à la main (R-D31, R-D46, R-F15, R-F21, R-F48). Un golden par écart serait la preuve suivante.
- R-E10 et R-E16 : ≈ 40 Commands et ≈ 25 Targets non relues une par une ; couvertes seulement à travers les cartes de 5C.
- R-E14 (Robobo et salles gelées), R-D47 (cible à 0 PV dans la fenêtre post-dégâts), R-E31 : non tranchés. R-E30 a été tranché depuis (Corrigé, 2026-10-28).
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
| IA-O04 | Capacités éligibles (`AbilityCalculator.CheckXXX` non nul) et capacité tirée dans l'ensemble | décision | Oui | `ApkAI.gd:1297-1338`, `AI.gd:95-108` | Oui à 99,8 % | Éligibles : sorts 716/718, salles 859/859, « rien d'éligible » 51636/51648. Tirée dans l'ensemble : 1575/1577. Les écarts sont Giant Size (IA-H14), Motivation (IA-H17) et Princess in Peril (IA-H18). | Accepté (Basse) |
| IA-O05 | Cibles déterministes des sorts et capacités activées (`SetSelectedTargets`) | décision | Oui | `ApkAI.gd` (`_chk_*`) | Oui | Sorts **590/590**, salles **734/734**. | — |
| IA-O06 | Cibles déterministes des déclencheurs (`TriggerCalculator`) | décision | Oui | `ApkAI.gd:1405-1744` | Oui à 98 % | **993/1009**. Les 16 écarts sont Mimic Vault ×10 (IA-H68), Specter's Sanctum ×5 (IA-H69) et Zombie Prison ×1 (IA-H70, depuis établi comme artefact du harnais et compté non mesurable). Tous dans les graines 10-40. | Corrigé (Moyenne) |
| IA-O07 | Cibles tirées au hasard (`Shuffle()`, `NextBool`) | décision | Oui | `ApkAI.gd` (`shuf`) | Non comparable | Accord attendu ≈ 1/n : sorts 79/126, salles 67/125, déclencheurs 124/301. Le tirage est fidèle (`Random.Next(1,100)` = `randi_range(1,99)`), seule la graine diffère. | — |
| IA-O08 | Coups jouables selon les règles (`CanPlayerPlayAbility`, mesure de la légalité du moteur et non de l'IA) | moteur | Oui | `Match.gd` (`legal_moves`) | Oui à 99,8 % | 53134/53225. Deux motifs : (a) BuildPhase_a à 3-4 joueurs, à la bascule entre deux joueurs (`NextStep` non exécuté) : l'APK a déjà ouvert la fenêtre du joueur suivant, Godot pas encore (Freeze, Jeopardy, Princess, Motivation, Soul Harvest) ; (b) AdventurePhase_c : Boulder Ramp jouable côté APK seulement, et BMA053 Teleportation jouable côté Godot seulement. Non tranché : décalage de fenêtre du harnais ou vraie règle. Renvoi au module 5. | Accepté (Moyenne) |

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
| IA-G08 | `StatisticAI.SelectWhereToDrawFrom` : `NextDouble() <= p` (`StatisticAI.cs:16-23`) | méthode | Oui | `AI.gd:60-72` | Oui | Seul le flux aléatoire diffère. Jamais exercé : BMA023 Haunted Library n'est jamais distribuée. | Conforme (Basse) |
| IA-G09 | `StatisticAI.DiscardCards`, `SelectRoomToBuild`, `SelectPositionToBuild` (`StatisticAI.cs:25-56`) | méthodes | N/A | — | — | Inatteignables : redéfinies par `FixedAI`. | — |
| IA-G10 | `StatisticAI.RandomSelection` (`StatisticAI.cs:101-141`) | méthode | N/A | — | — | Ne sert qu'à IA-G09 et aux capacités (IA-H01). | — |
| IA-G11 | `StatisticAI.backup = new RandomAI()` (`StatisticAI.cs:14`) | champ | N/A | — | — | Jamais lu : il n'y a pas de repli vers `RandomAI`. | — |
| IA-G12 | `RandomAI` (`RandomAI.cs:12-83`) | classe | Non (vérifié absent) | — | — | Atteinte seulement par l'autoplay de debug (`HumanPlayerInteraction.cs:26-41`, `DEBUG_ELEM`) et par `GameFlowTestService`. | Accepté (Basse) |
| IA-G13 | `NullAI` | classe | N/A | — | — | Jamais instanciée. | — |
| IA-G14 | `DeckType` (`AIPlayerInteraction.cs:125-139`) | enum | Oui | `AI.gd:60-72`, `Match.gd:1240` | Oui | | — |
| IA-G15 | `AIHelper.GetGamePhase` : Setup, Early, Mid, Late (`AIHelper.cs:68-83`) | méthode | Oui | `ApkAI.gd:62-66` | Oui | Mêmes bornes de tour. | — |
| IA-G16 | `AIHelper.GetBuildableRooms` / `GetBuildablePositions`, `Boss.CanBuildRoom` | méthodes | Oui | `Match.gd:256-296`, `BossEngine.gd:119-171` | Oui | | — |
| IA-G17 | `AIHelper.GetDungeonDamage`, double après BMA017 (`AIHelper.cs:95-117`) | méthode | Oui | `ApkAI.gd:210-229` | Oui | | — |
| IA-G18 | `AIHelper.GetTotalTreasuresForHero` / `OfType`, `Boss.GetDungeonTreasures` | méthodes | Oui | `ApkAI.gd:195-208`, `BossEngine.gd:61-95` | Oui | Voir R-F15 pour le cas d'une salle gelée. | — |
| IA-G19 | `StatisticsCalculator.CalculateHandDiscardStatistics` (`StatisticsCalculator.cs:30-42`) | méthode | Oui | `ApkAI.gd:382-414` | Partiel | `list.Max()` planterait sur une main sans salle ; Godot prend 0. Inatteignable. | Accepté (Basse) |
| IA-G20 | `CalculateRoomsStatistics` (`StatisticsCalculator.cs:44-53,118-129`) | méthode | Oui | `ApkAI.gd:298-341` | Oui | | — |
| IA-G21 | `CalculateSlotStatistics` (`StatisticsCalculator.cs:55-68`) | méthode | Oui | `ApkAI.gd:343-366` | Oui | | — |
| IA-G22 | `NormalizeValues` (`StatisticsCalculator.cs:131-163`) | méthode | Oui | `ApkAI.gd:271-290` | Oui | | — |
| IA-G23 | `Early/Mid/LateRoomMinChance` (`StatisticsCalculator.cs:13-17`) | constantes | N/A | — | — | Jamais lues (`switch` vide). | — |
| IA-G24 | `RoomCalculator` : 9 tableaux de valeurs (`RoomCalculator.cs:55-64`) | données | Oui | `ApkAI.gd:16-24` | Oui | Identiques (script). | — |
| IA-G25 | `RoomCalculator` : 9 scalaires (`RoomCalculator.cs:65-73`) | données | Oui | `ApkAI.gd:25-32` | Oui | Identiques (script). | — |
| IA-G26 | `RoomCalculator.CalculateValue` (`RoomCalculator.cs:77-123`) | méthode | Oui | `ApkAI.gd:91-97` | Oui | | — |
| IA-G27 | `CalculateRoomValue` (`RoomCalculator.cs:138-149`) | méthode | Oui | `ApkAI.gd:83-89` | Oui | Godot borne les indices à 0-9 ; l'APK planterait au-delà. Inatteignable. | Accepté (Basse) |
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
| IA-G44 | `CardInfoService.GetAIRoomInfo` : exception pour une salle sans fiche IA (`CardInfoService.cs:129-158`) | méthode | Oui | `ApkAI.gd:83-89` | Différent | Godot met des facteurs vides (salles THK et wiki). Hors APK. | Accepté (Basse) |
| IA-G45 | Salles et héros de `BaseDeck/data.json` vus par l'IA | asset | Oui | `src/frontend/godot/data/cards.json` | Oui | 31/31 salles et 41/41 héros identiques (script). | — |
| IA-G46 | `AIPlayerInteraction.BuildRoom` : boucle jusqu'à `MaxBuildRoomLimit` (`AIPlayerInteraction.cs:165-186`) | méthode | Oui | `AI.gd:111-116`, `Match.gd:556-570` | Oui | | — |
| IA-G47 | `InternalDoPlayerActions` BuildPhase_a : capacité **et** construction choisies sur le même état, exécutées ensuite (`AIPlayerInteraction.cs:86-101`) | méthode | Oui | `AI.gd:95-116` | Partiel | Vérifié : Godot joue la capacité, puis choisit la salle à construire à un appel suivant, sur l'état d'après la capacité. Si le sort change la main, le donjon ou la ville, la salle choisie peut différer. L'oracle enregistre la décision d'avant la capacité, donc ce cas ne se mesure pas. | Corrigé (Moyenne) |
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
| IA-H14 | `CheckBMA047` Giant Size : la branche « héros actif » réutilise la liste des salles Piège (`AbilityCalculator.cs:844-847`) | méthode | Oui | `ApkAI.gd:657-676` | Partiel | Bogue APK non reproduit par défaut (le sort viserait un type de salle interdit) ; option de mesure `--ai-copy-trap-bug`. Explique les écarts d'éligibilité de Giant Size (IA-O04). | Accepté (Basse) |
| IA-H15 | `CheckBMA048` Jeopardy | méthode | Oui | `ApkAI.gd:839-846` | Oui | | — |
| IA-H16 | `CheckBMA049` Kobold Strike | méthode | Oui | `ApkAI.gd:848-857` | Oui | | — |
| IA-H17 | `CheckBMA050` Motivation : `GetBuildableRooms().Count() < 2` via `Boss.CanBuildRoom`, sans limite par tour | méthode | Oui | `ApkAI.gd:859-869`, `Match.gd:273` | Partiel | Godot compte les coups `buildRoom` légaux, qui disparaissent après la première construction du tour. L'APK peut jouer Motivation après sa construction (s30-p4 seq 306). | Corrigé (Moyenne) |
| IA-H18 | `CheckBMA051` Princess in Peril | méthode | Oui | `ApkAI.gd:871-895` | Non vérifié | Port ligne à ligne conforme ; l'écart s26-p4 seq 20-24 n'est pas expliqué. | Corrigé (Moyenne) |
| IA-H19 | `CheckBMA052` Soul Harvest | méthode | Oui | `ApkAI.gd:897-910` | Oui | Peu exercé. | — |
| IA-H20 | `CheckBMA053` Teleportation (`Take(0)` : jamais éligible) | méthode | Oui (bogue APK reproduit) | `ApkAI.gd:912-920` | Oui | | — |
| IA-H21 | `CheckBMA054` Trepidation | méthode | Oui | `ApkAI.gd:922-933` | Oui | | — |
| IA-H22 | `CheckBMA055` Zombie Attack | méthode | Oui | `ApkAI.gd:935-957` | Oui | | — |
| IA-H23 | `CheckKSA013` T.P.K. : vise le premier de `InGamePlayersPriorized` | méthode | Oui | `ApkAI.gd:959-964,1401-1404` | Partiel | Hors harnais, Godot ne propose que le lanceur comme cible ; l'APK vise le boss de plus haute XP, qui peut être un adversaire. Paquet PlayerChoice seulement. | Corrigé (Moyenne) |
| IA-H24 | `CheckBMA009` Dark Altar | méthode | Oui | `ApkAI.gd:971-1002` | Oui | | — |
| IA-H25 | `CheckBMA013` Dracolich Lair | méthode | Oui | `ApkAI.gd:1005-1030` | Oui | | — |
| IA-H26 | `CheckBMA024` Witch's Kitchen | méthode | Oui | `ApkAI.gd:1032-1043` | Oui | | — |
| IA-H27 | `CheckBMA025` All-Seeing Eye (Spell Battle) | méthode | Oui | `ApkAI.gd:1193-1231` | Oui | Exercé seulement dans les graines 10-40. | — |
| IA-H28 | `CheckBMA027` Bottomless Pit | méthode | Oui | `ApkAI.gd:1045-1052` | Oui | | — |
| IA-H29 | `CheckBMA028` Boulder Ramp + `HasHeroPassedSlot` | méthode | Oui | `ApkAI.gd:1054-1089` | Oui | | — |
| IA-H30 | `CheckBMA030` Jackpot Stash | méthode | Oui | `ApkAI.gd:1103-1150` | Oui | | — |
| IA-H31 | `CheckBMA032` Crushinator | méthode | Oui | `ApkAI.gd:1233-1278` | Oui | La condition supplémentaire `not big_game` ne joue qu'à 5-6 joueurs (wiki). | Conforme (Basse) |
| IA-H32 | `CheckBMA038` Torture Chamber | méthode | Oui | `ApkAI.gd:1152-1169` | Oui | | — |
| IA-H33 | `CheckBMA039` Zombie Prison | méthode | Oui | `ApkAI.gd:1171-1191` | Oui | Choix de cible : IA-H70. | — |
| IA-H34 | `AIHelper` : dégâts du donjon, héros attiré, qui attire | méthodes | Oui | `ApkAI.gd:195-625` | Oui | | — |
| IA-H35 | `CalculateSpellValue`, `CalculateHeroValuetoSteal` | méthodes | Oui | `ApkAI.gd:1680-1698` | Oui | | — |
| IA-H36 | `AbilitySelectedInformation` (cibles préréglées) | classe | Oui | `AI.gd:28,53-60`, `ApkAI.gd:1746-1750` | Oui | | — |
| IA-H37 | `TriggerCalculator` : cache de cibles périmées (`TriggerCalculator.cs:22-27,143-149`) | classe | Oui | `ApkAI.gd:~1405` | Différent | Bogue APK non reproduit en jeu : avec des cibles périmées, l'APK abandonne la capacité (Mimic Vault, 2e Open Grave). L'IA Godot joue donc un peu mieux. Seul le harnais l'émule. | Accepté (Basse) |
| IA-H38 | `CheckBMA001` Draculord | méthode | Oui | `ApkAI.gd:1546-1569` | Oui | | — |
| IA-H39 | `CheckBMA002` Xyzax | méthode | Oui | `ApkAI.gd:1571-1591` | Oui | | — |
| IA-H40 | `CheckBMA003` / `CheckBMA007` | méthodes | Oui | `ApkAI.gd:1593-1597` | Oui | | — |
| IA-H41 | `CheckBMA004` Robobo | méthode | Oui | `ApkAI.gd:1599-1609` | Oui | | — |
| IA-H42 | `CheckBMA005` / `CheckBMA022` + `SelectSpellToDiscard` | méthodes | Oui | `ApkAI.gd:1611-1623` | Oui | | — |
| IA-H43 | `CheckBMA006` Seducia | méthode | Oui | `ApkAI.gd:1625-1632` | Oui | | — |
| IA-H44 | `CheckBMA008` Gorgona | méthode | Oui | `ApkAI.gd:1634-1638` | Oui | | — |
| IA-H45 | `CheckBMA010` Open Grave | méthode | Oui | `ApkAI.gd:1640-1646` | Oui | | — |
| IA-H46 | `CheckBMA011` Specter's Sanctum | méthode | Oui | `ApkAI.gd:1648-1656` | Partiel | Logique conforme ; l'état évalué diffère (IA-H69). | voir IA-H69 |
| IA-H47 | `CheckBMA012` Succubus Spa : renvoie le joueur lui-même pour `BossOpponent` | méthode | Oui | `ApkAI.gd:1648-1656` | Partiel | Bogue APK non reproduit : Godot prend l'adversaire désigné. | Accepté (Basse) |
| IA-H48 | `CheckBMA014` Vampire Bordello | méthode | Oui | `ApkAI.gd:1658-1662` | Oui | | — |
| IA-H49 | `CheckBMA036` Mimic Vault | méthode | Oui | `ApkAI.gd:1664-1672` | Partiel | Logique conforme ; l'état évalué diffère (IA-H68). | voir IA-H68 |
| IA-H50 | `CheckBMA037` Monstrous Monument | méthode | Oui | `ApkAI.gd:1674-1678` | Oui | | — |
| IA-H51 | `CheclKSA002` Hellcow | méthode | Oui | `ApkAI.gd:1700-1744` | Oui | Non mesuré par l'oracle. | — |
| IA-H52 | `CheclKSA003` The Brothers Wise | méthode | Oui | `ApkAI.gd:1680-1693` | Oui | | — |
| IA-H53 | `CheclKSA004` Kaw'nee | méthode | Oui | `ApkAI.gd:1695-1698` | Oui | | — |
| IA-H54 | `CheckBMA033` Centipede Tunnel | méthode | N/A | — | — | Carte jamais distribuée. | — |
| IA-H55 | Déclencheurs à cible unique (BMA017, 019, 021, 031, 034, KSA001, 005, 006, 007) | méthodes | Oui | `ApkAI.gd:1420-1440` | Oui | Résolus automatiquement. | — |
| IA-H56 | `TriggerCalculator.CalculateCommandTargets` / `CheckSpellInHandCommand` | méthode | Non vérifié | — | — | Aucun équivalent identifié. | Accepté (Basse) |
| IA-H57 | `CalculateTriggerTargets` : un fournisseur avec assez peu de cibles est pris tel quel | méthode | Oui | `ApkAI.gd:~1405` | Oui | | — |
| IA-H58 | `InternalDoPlayerActions` Setup_b → `BuildRoom` | méthode | Oui | `Match.gd:1141-1160` | Oui | | — |
| IA-H59 | `InternalDoPlayerActions` BuildPhase_a : `UseAbility()` pour **chaque** IA à chaque `NextStep`, construction seulement pour le joueur actif (`AIPlayerInteraction.cs:86-101`, appelé pour toutes les IA par `GamePlayBaseScene.cs:864-871`) | méthode | Oui | `Match.gd:263-267`, `AI.gd:95-108`, `BoardUI.gd:884-902` | **Différent** | Vérifié : Godot a une « politique IA » qui ne donne aucun coup à une IA hors de son tour de construction, sauf dans la fenêtre d'après la dernière construction. Mesuré sur les 24 traces de référence : 1551 des 2177 appels `UseAbility` de l'APK en BuildPhase_a viennent d'une IA hors de son tour, et 69 capacités sont jouées ainsi (Dracolich Lair 25, Jackpot Stash 13, Princess in Peril 10, Jeopardy 6…). Dans Godot, les adversaires jouent donc moins de sorts et de capacités pendant le tour des autres, et plus tard. L'oracle ne le voit pas : il rejoue les coups APK. | **Haute** |
| IA-H60 | `InternalDoPlayerActions` AdventurePhase_b / _c : `UseAbility()` pour toutes les IA | méthode | Oui | `BoardUI.gd:889`, `Match.gd:343-420` | Partiel | Une IA non active n'agit que pendant les pauses après dégâts et avant la sortie. Elle n'a pas la fenêtre d'avant l'entrée du héros (par exemple pour Trepidation). | Corrigé (Moyenne) |
| IA-H61 | `InternalDoPlayerActions` ExtraBuildPhase → `BuildRoom` | méthode | Oui | `Match.gd:1421-1449` | Non vérifié | Lu en surface. | Accepté (Basse) |
| IA-H62 | Réponse de l'IA en Spell Battle (`UseAbility` puis `SetSpellBattleReady`) | méthode | Oui | `AI.gd:41-47`, `Match.gd:1678-1700` | Oui | | — |
| IA-H63 | `InternalResolveTarget` : exception ou `null` → abandon | méthode | Oui | `AI.gd:63-71` | Partiel | Godot n'abandonne que si `choose` rend −1 ; pas de chemin d'exception (IA-H37). | Accepté (Basse) |
| IA-H64 | `InvokeCallback` / `SimulateHumanDelays` (1-4 s, test en ligne seulement) | méthode | Oui | `BoardUI.gd:891-893` | Différent | L'IA APK hors ligne est immédiate, rythmée par les animations ; Godot attend 0,5 s (construction) ou 0,2 s (aventure). Cosmétique, renvoi au module 7. | Accepté (Basse) |
| IA-H65 | `HumanPlayerInteraction.AutoPlayMode` + `RandomAI` | classe | N/A | — | — | Debug seulement (`CreateTestButtons` jamais appelé) : pas d'autoplay à l'expiration du minuteur dans l'APK, rien à porter. | — |
| IA-H66 | `DoNextStepAndRefresh` : IA dans l'ordre `InGamePlayersPriorized` | méthode | Oui | `BoardUI.gd:884-902` | Partiel | Godot joue un coup par tick, dans l'ordre d'insertion des joueurs (le même en pratique). | Accepté (Basse) |
| IA-H67 | Exécution différée des capacités (`EnqueueAbilityTransaction` puis `NextStep`) | méthode | Oui | `Match.gd` | Partiel | Même cause que IA-G47 et R-D67 ; seul le harnais reproduit la course (`_held`). | Accepté (Basse) |
| IA-H68 | Écart Mimic Vault, 10 cas (`TriggerCalculator.cs:290-303`) | cause | Oui | `Match.gd:1492`, `ApkAI.gd:1664` | Partiel | Cause démontrée : le C# fige la cible dans `EnqueueAbilityTransaction` (`GameBoard.cs:1329-1330`) avant de lever `PendingToBeBuilt` (`GameBoard.cs:950-952`). La salle qui vient d'être révélée ne compte donc pas encore dans les dégâts du donjon. Godot a déjà tout retourné (`Match.gd:1492`). s13-p4 seq 1352 : dégâts APK 7, Godot 8, donc Godot accepte un héros à 8 PV que l'APK écarte. | Corrigé (Moyenne) |
| IA-H69 | Écart Specter's Sanctum, 5 cas à 4 joueurs | cause | Oui | `Match.gd:1477-1500`, `ApkAI.gd:1648` | Partiel | Cause démontrée : l'APK décide toutes les cibles à la révélation, avant tout effet ; Godot applique chaque déclencheur avant de calculer le suivant, et ordonne la file par XP au lieu de l'ordre des sièges (`GameBoard.cs:930`). s10-p4 seq 13 : Dark Laboratory de P1 a déjà changé le nombre de sorts en main quand Godot choisit. | Corrigé (Moyenne) |
| IA-H70 | Écart Zombie Prison, 1 cas (s21-p4) | cause | Oui | `ApkParityTrace.gd` (`_ai_measure_choice`, `_ai_choice`), `ApkAI.gd:1759-1795` | Oui | Reproduit (`--seeds 21 --players 4 --ai-agreement`) : artefact du harnais, pas un écart de l'IA ni des règles. À s21-p4@518 l'oracle tire la capacité de Zombie Prison dans la fenêtre BuildPhase_a APRÈS le DONE ; Godot a déjà fermé la phase BUILD et est en aventure, donc `_ai_measure_choice` sort en « ability:phase » avant `AI.remember` : la cible préréglée (`sel`) est vide et `ApkAI.choose` retombe sur l'option 0 au choix @519. `_chk_039` retrouve bien le héros BMA078 quand `sel` existe (activateTarget 10/10). Correction du harnais : le choix est compté « target:presetNotMeasurable[Zombie Prison] » (non mesurable) au lieu d'un désaccord. Résultat : `target` s21-p4 23/23 (23/24 avant), aucun écart restant sur Zombie Prison. Règles et IA inchangées. | Corrigé (Moyenne) |
| IA-H71 | Écart d'éligibilité Giant Size | cause | Oui | `ApkAI.gd:670-676` | Partiel | = IA-H14. | Accepté (Basse) |
| IA-H72 | Écart Motivation (s30-p4) | cause | Oui | `ApkAI.gd:859-869` | Partiel | = IA-H17. | voir IA-H17 |
| IA-H73 | Écart Princess in Peril (s26-p4) | cause | Non vérifié | `ApkAI.gd:871-895` | Non vérifié | = IA-H18 ; cause non établie sans exécution. | voir IA-H18 |
| IA-H74 | `RevealAllRoomCards` : ordre et moment de résolution des cibles (`GameBoard.cs:928-968,1317-1332`) | méthode | Oui | `Match.gd:1477-1500` | Différent | Cause commune de IA-H68, IA-H69 et sans doute IA-H73 : sièges contre XP pour l'ordre, et cibles figées à la révélation contre cibles calculées après les effets. Rejoint R-D19 et R-D35 du module 5. | Corrigé (Moyenne) |

### Non vérifié (module 6)

- IA-H18 / IA-H73 (Princess in Peril, s26-p4) : cause non établie. IA-H70 (Zombie Prison, s21-p4) a été établi depuis : artefact du harnais, corrigé (2026-10-28).
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
| P-A05 | `SP.InitializeGameboard` : boss limités sans le jeu complet (SP:22-30) | méthode | N/A | — | — | Boutique supprimée : tous les boss sont jouables. | Accepté (Basse) |
| P-A06 | `SP.OnUserPlayerVictory` : `GameStats.SPWins++` (SP:58-64) | méthode | Non (vérifié absent, `grep SPWins`) | `Profile.gd:54-72` | Différent | Ne servait qu'au déverrouillage, supprimé. | Accepté (Basse) |
| P-A07 | `SP.CreateBeforePlayerInteractionTask` : affiche le donjon du joueur actif (SP:69-77) | méthode | Oui | B:783-799 | Partiel | Godot ne suit que l'aventure, pas le joueur actif en construction à 3-4 joueurs. | Corrigé (Basse) |
| P-A08 | `TopRightPanel_ChangeVisibleOpponent` : fondu entre donjons (Base:767-773, 1008-1029) | méthode | Oui | B:801-832 | Partiel | Pas de fondu. | Corrigé (Basse) |
| P-A09 | `DoNextStepAndRefresh` : chaîne de tâches (Base:838-879) | méthode | Oui | B:860-905, 1062-1165 | Différent | Architecture événementielle ; effet équivalent, ordre fin non garanti. | Accepté (Basse) |
| P-A10 | `CreateCheckEndOfGameTask` : si tous les humains sont morts en fin de tour → `OnUserPlayerDefeat` (Base:1071-1078) | méthode | Non (vérifié absent) | B:4273-4302, M:2090-2135 | **Différent** | Vérifié : Godot n'ouvre l'écran de fin que sur `G.gameOver`. À 3-4 joueurs, un humain éliminé regarde les IA finir la partie au lieu de voir « YOU LOSE » à la fin du tour. | **Haute** |
| P-A11 | `WinnerScene` : voile, bandeau, nom ×2,5, particules, cristaux, OK (WS:10-87) | scène | Oui | `GameOverBanner.gd:338-392` | Oui | Calé sur les captures. | — |
| P-A12 | `PlayBossVictorySoundTask` : `sting_player_win`, voix du boss à +0,5 s (WS:89-100) | méthode | Oui | B:4281-4288 | Oui | En pass and play, le jingle dépend du siège affiché. | Accepté (Basse) |
| P-A13 | OK de victoire : `UnlockFromWins` puis écran HIDDEN HEROES (WS:65-87) | méthode | N/A | B:4301 | — | Déverrouillage supprimé, retour titre conservé. | Accepté (Basse) |
| P-A14 | `LoseScene` : « ...YOU LOSE! », pierre tombale, `sting_player_lose`, OK (LS:4-28) | scène | Oui | `GameOverBanner.gd:349-352`, B:4289-4290 | Oui | | — |
| P-A15 | `PauseScene` : PAUSED, RESUME / CARD GALLERY / SETTINGS / QUIT GAME (PS:13-75) | scène | Oui | `InGameMenu.gd:241-258` | Oui | RULES en plus (ajout). CARD GALLERY masqué en ligne dans l'APK : renvoi module 9. | Conforme (Basse) |
| P-A16 | Réglages depuis la pause : musique, sons, vitesse | scène | Oui | `InGameMenu.gd:260-273` | Oui | MASTER VOLUME en plus (ajout). | Conforme (Basse) |
| P-A17 | Jeu figé pendant la pause, hors ligne seulement (Base:1091-1100) | comportement | Oui | B:872-873 | Oui | | — |
| P-A18 | `QuitGameScene` : « QUIT GAME? / ARE YOU SURE YOU WANT TO QUIT? », CANCEL / QUIT | scène | Oui | B:4338-4342 | Différent | Godot : « Quit to menu? The current game will be lost », « YES, QUIT » / « NO, KEEP PLAYING ». `Main._confirm_box` (Main.gd:297) a déjà le gabarit APK. | Conforme (Basse) |
| P-A19 | `NavigatedBack` (touche Retour) : pause, puis confirmation de sortie (Base:1172-1179) | méthode | Non (vérifié absent, `grep KEY_ESCAPE\|ui_cancel`) | — | — | Échap ne fait rien. Hors cible souris. | Conforme (Basse) |
| P-A20 | `ModalScene` : voile 0,7 | classe | Oui | B:2563-2575 | Oui | | — |
| P-A21 | Engrenage → pause, garde `isInPauseScene` (Base:782-785) | méthode | Oui | B:4304-4310 | Oui | | — |
| P-A22 | `PhaseTitleControl` : plaque BUILD / BAIT / ADVENTURE, saut 0,5 s, masquée hors phases (PTC:44-99) | entité | Oui | B:2009-2068 | Oui | En `setup` / `boss`, Godot montre la plaque BUILD estompée (B:1190). | Conforme (Basse) |
| P-A23 | BAIT : vols ville → donjons | comportement | Oui | B:232, 2018-2033 | Oui | 1,0 s par héros. | — |
| P-A24 | `CreateWaitAndMoveHeroToNextSlotTask` : barre de 3 s, `char_hero_intro` (Base:924-952) | méthode | Oui | B:233, 945-1000, 2211, 2353 | Oui | | — |
| P-A25 | `OnTimerSlowDown` : barre figée pendant zoom, glisser, carrousel (Base:169-190) | méthode | Oui | B:937-938 | Partiel | Le carrousel de défausse n'existe pas (P-A39). | Conforme (Basse) |
| P-A26 | Spell battle : barre de 6 s au-dessus de la dernière carte (Base:210-214, 631-664) | méthode | Oui | B:234, 945-966, 3845-3910 | Oui | | — |
| P-A27 | `DoneButtonBehavior` : PASS TURN puis DONE! (DBB:25-55) | comportement | Oui | B:3518-3524, 4267-4271 | Oui | | — |
| P-A28 | Premier appui sur PASS : « HEY! YOU CAN BUILD A ROOM! STILL WANT TO PASS? » (Base:259-269) | comportement | Oui | B:3526-3550, 4206-4235 | Oui | Texte et place conformes ; voir P-C24 pour l'animation. | — |
| P-A29 | Pulsation `halt_button_pulse` du bouton DONE | comportement | Non (vérifié absent) | — | — | = P-C51. | voir P-C51 |
| P-A30 | Minuterie de 70 s du bouton DONE (Base:272) | comportement | Non vérifié | `CountDown.gd` | — | En ligne seulement : renvoi module 9. | — |
| P-A31 | `BuildRoomHandSceneBehavior` : glisser une salle, emplacements jaunes, dépôt face cachée (BRH:79-157) | comportement | Oui | B:3598-3770 | Oui | | — |
| P-A32 | `CheckMaxBuildRooms` / `UndoBuild` (BRH:158-192) | méthode | Oui | `GameManager.gd:89-147`, B:3240-3305 | Oui | Reprise par clic au lieu de glisser hors du donjon. | Accepté (Basse) |
| P-A33 | Lâcher sur la main = annuler (BRH:117-131) | méthode | Oui | B:3753 | Oui | | — |
| P-A34 | `PlaySpellsInHandSceneBehavior` : lâcher hors de la main joue le sort (PSH:25-91) | comportement | Oui | B:3771-3800 | Partiel | Godot limite la zone de lâcher au plateau : lâché sur la colonne de droite, le sort est annulé. Un clic joue aussi le sort (ajout). | Corrigé (Basse) |
| P-A35 | `PlayRoomAbilitiesSceneBehavior` : toucher une salle zoome la pile, toucher la bordure résout (PRA:31-58) | comportement | Oui | B:3422-3482 | Partiel | Bouton CANCEL en plus. | Conforme (Basse) |
| P-A36 | `ShowRoomSlotDetail` : tout toucher sur un emplacement montre la pile complète (Base:681-718) | méthode | Oui | D:80, B:3802-3815 | Partiel | = P-B46 / P-C15. | voir P-C15 |
| P-A37 | `TargetResolverBaseSceneBehavior` : cibles en jaune, source en vert, titre = description de la carte (TRB:59-188) | classe | Oui | B:2751-3115 | Partiel | Titre tiré du message du moteur ; contour vert de la source non retrouvé. | Accepté (Basse) |
| P-A38 | `TriggerAbilitiesResolverSceneBehavior` (TAR:31-47) | comportement | Oui | B:3050-3115 | Oui | | — |
| P-A39 | `ShowDiscardPile` : diaporama des salles et sorts défaussés (Base:745-765) | méthode | Oui | B:4349-4382 | Différent | = P-C17. | voir P-C17 |
| P-A40 | `ShowDungeonQueue` : diaporama des héros à l'entrée (Base:720-743) | méthode | Non (vérifié absent) | B:1524-1527 | Partiel | = P-B47. | voir P-B47 |
| P-A41 | `ShowHeroInTown` : zoom à gauche (Base:787-797) | méthode | Oui | B:1385-1388 | Partiel | Appui long, zoom centré. | Corrigé (Basse) |
| P-A42 | `ShowChallengerBossDetail` : boss + sorts « jusqu'à la fin du tour » (Base:775-780, 1221-1247) | méthode | Oui | B:4384-4393 | Partiel | = P-B61. | voir P-B61 |
| P-A43 | `ShowZoom` : sons, ralentissement de la barre (Base:1263-1280) | méthode | Oui | B:3816-3834 | Oui | | — |
| P-A44 | `HighLightCards` Red / Yellow / GreenGlow (Base:1288-1329) | méthode | Oui | B:3711-3730, 2996 | Oui | | — |
| P-A45 | `BubblesPlayerEmitter` : bulles en file, une par panneau d'adversaire, variante AGAINST | classe | Oui | B:3942-3998 | Partiel | Une seule bulle à la fois (la nouvelle remplace l'ancienne), position fixe. AGAINST : P-B12. | Partiel (Moyenne) |
| P-A46 | Toucher une bulle → carte zoomée, cibles en rouge (Base:1249-1261) | méthode | Oui | B:3968-4014 | Oui | | — |
| P-A47 | Bulles en solo, pas en pass and play (PaP:94-96, SP:82-88) | méthode | Oui | B:3942-3946 | Oui | | — |
| P-A48 | `IsPlayingOnlineBubbleSceneBehavior` | comportement | Non (vérifié absent) | — | — | Renvoi module 9. | — |
| P-A49 | Pass and play : 2 humains, boss aléatoires (PaP:5-20) | scène | Oui | B:1175, 1939-1948 | Oui | | — |
| P-A50 | Pass and play : la main sort puis revient, les donjons s'échangent (PaP:97-174) | méthode | Oui | B:742-781 | Oui | Barre PLAYER n en plus. | Conforme (Basse) |
| P-A51 | Pass and play : aventure automatique, main cachée en BAIT et aventure (PaP:44-84) | méthode | Oui | B:704-740, 921-929, 1127-1139 | Différent | Avec 2 humains, Godot montre des boutons GO / PASS TURN et la main en aventure. | Sans objet (Moyenne) |
| P-A52 | `LeaveGameplayScene` → écran titre (Base:1103-1107) | méthode | Oui | B:4344-4347 | Oui | | — |
| P-A53 | Vitesse SLOW 1,5 / NORMAL 1 / FAST 0,5 | comportement | Oui | B:931-935 | Oui | | — |
| P-A54 | Bannière LEVEL UP puis choix (Base:911-914, 981) | méthode | Oui | B:1283-1346, 3076 | Oui | | — |
| P-A55 | `GamePlayMOScene` : messages de connexion, désertion, 60 s | classe | Non (vérifié absent) | — | — | Renvoi module 9. | — |
| P-A56 | `GamePlayTutScene` | classe | N/A | — | — | Renvoi module 8. | — |
| P-A57 | `DrawCardsDemoBehavior`, `CreateTestButtons` (debug) | comportement | N/A | — | — | Code de debug mort. | Accepté (Basse) |
| P-A58 | `CreateRefreshHandTask` (animation de pioche) | méthode | Oui | B:4016-4200 | Oui | Voir P-B35. | — |
| P-A59 | `CreateScene` : disposition générale (Base:196-296) | méthode | Oui | B:321-660 | Oui | Détail en 7B et 7C. | — |

### 7B — Entités du plateau

| ID | Élément source (décompilé) | Type | Présent dans Godot ? | Fichier Godot | Équivalent fonctionnel ? | Écart / Commentaire | Priorité |
|---|---|---|---|---|---|---|---|
| P-B01 | `BalloonEntity` : bulle du boss « HEY… » | classe | Oui | B:4210-4226 | Partiel | Disparaît après 6 s au lieu de se refermer au clic ; pas d'écriture progressive. Voir P-C24. | Conforme (Basse) |
| P-B02 | `BalloonEntity` : bulles du tutoriel | méthodes | Non vérifié | `TutorialOverlay.gd:1067` | — | Renvoi module 8. | — |
| P-B03 | `BossCharacterWithXP` | classe | N/A | — | — | Jamais instanciée. | — |
| P-B04 | `BossDetailHeaderControl` : icône, nom tronqué à 10, sous-titre à 25 | classe | Oui | B:434-466, 2133 | Partiel | Police réduite au lieu de tronquer ; pas de fondu au changement de boss. | Corrigé (Basse) |
| P-B05 | `boss_icon_legend` (backer) | asset | N/A | — | — | Boutique supprimée. | — |
| P-B06 | `BossXPAndOrderControl` : « 800XP » | classe | Oui | B:399-402, 1274-1278 | Oui | | — |
| P-B07 | `BossXPAndOrderControl` : cercle doré = `boss.PlayerId`, l'ordre de jeu (`BossXPAndOrderControl.cs:109`) | classe | Oui | B:402, 1279 | **Différent** | Vérifié : Godot affiche « 2 » si le boss est monté de niveau, sinon « 1 » (`B:1279`). L'APK affiche l'ordre de jeu (1..N, par XP décroissante), qui ne change pas au level-up. `G.xpOrder` existe (M:1090) mais n'est pas lu. L'adversaire affiche « 1 » au lieu de « 2 ». | **Haute** |
| P-B08 | Icône du premier trésor du boss (`mp_icon_treasure_*`) | asset | Oui | B:403, 1281-1282 | Partiel | Petite variante d'icône. | Corrigé (Basse) |
| P-B09 | Badge DAMAGE = `AIHelper.GetDungeonDamage` : dégâts modifiés des salles actives, ×2 après Minotaur's Maze (`DungeonFrameEntity.cs:413`) | classe | Oui | B:1272, 4395-4401 | **Différent** | Vérifié : `_get_total_dungeon_damage` additionne le `damage` imprimé. Goblin Armory, Dizzygas, Monster's Ballroom, Freeze et Minotaur's Maze sont ignorés, alors que `BossEngine.room_damage_with_modifiers` existe. Valeur fausse dès qu'une de ces cartes de base est en jeu. | **Haute** |
| P-B10 | Mise à jour du DAMAGE avec fondu, décalage à 2 chiffres | propriété | Oui | B:2362-2364 | Partiel | Fondu seulement pendant un pas de héros. | Corrigé (Basse) |
| P-B11 | `BubbleEntity` « HAS PLAYED A SPELL / ROOM ABILITY », clic = zoom | classe | Oui | B:3968-4000 | Oui | | — |
| P-B12 | `CreatePlayAgainstBubble` : « AGAINST » + icônes des boss visés | méthode | Non (vérifié absent, `grep AGAINST`) | — | — | La bulle ne dit pas contre qui le sort est joué (3-4 joueurs). | Partiel (Moyenne) |
| P-B13 | Bulle « IS PLAYING! » | type de bulle | Non (vérifié absent) | — | — | Renvoi module 9. | — |
| P-B14 | `CarouselSelectorEntity` : « SELECT 2 CARDS TO DISCARD », CONTINUE | classe | Oui | B:1178-1245, 3221-3237 | Oui | Pas de grossissement au survol (voulu d'après les captures). | — |
| P-B15 | Sélecteur réutilisé pour les choix de cartes | classe | Oui | B:2631-2706 | Oui | | — |
| P-B16 | `CarouselShowEntity`, `MiddleCarrouselEntity` : diaporama de consultation | classes | Non (vérifié absent) | — | — | = P-C17. | voir P-C17 |
| P-B17 | `ChallengerDetail` : panneau en bas à droite | classe | Oui | B:406-466 | Oui | Écart ≤ 3 px. | — |
| P-B18 | WOUNDS : 5 icônes | compteur | Oui | B:2121-2160 | Oui | | — |
| P-B19 | SOULS : 10 icônes | compteur | Oui | B:2154-2160 | Oui | | — |
| P-B20 | Trésors du donjon = `GetDungeonTreasures` : exclut les salles en attente et gelées (`ChallengerDetail.cs:160`, `Boss.cs:252-256`) | compteur | Oui | B:2161-2162, `BossEngine.gd:61-112` | **Différent** | Vérifié : `dungeon_treasures` ne filtre pas `faceDown`. Le compteur monte dès qu'une salle est posée face cachée, au lieu de la révélation, ce qui dévoile le trésor de la salle cachée de l'adversaire. Il compte aussi les salles gelées (R-F15). | **Haute** |
| P-B21 | Panneau `challenger_panel_selected_red` quand un sort vise le boss | asset | Non (vérifié absent) | B:2927-2931 | Différent | La cible est signalée sur le sprite du boss : information équivalente. | Corrigé (Basse) |
| P-B22 | Bouton LEVEL UP : zoom du boss ×1,3 | bouton | Oui | B:479-480, 4384-4394 | Oui | | — |
| P-B23 | `CollapsedOpponentDetail` ×(N-1) : vignettes de chaque adversaire (nom, âmes, blessures, trésors) | classe | Oui | B:801-832 | Différent | Godot montre des boutons P2, P3… et un seul panneau : on ne voit pas l'état de tous les adversaires ensemble. | Corrigé (Moyenne) |
| P-B24 | Particules sur le joueur actif | particules | Oui | B:819-831 | Partiel | | Conforme (Basse) |
| P-B25 | `icon_death_profile` quand un boss meurt | asset | Non (vérifié absent) | B:1568-1597 | Différent | La pierre tombale du couloir suffit. | Conforme (Basse) |
| P-B26 | État sélectionné d'une vignette | comportement | Oui | B:816 | Partiel | | Conforme (Basse) |
| P-B27 | `ExpandedOpponentDetail` : XP, blessures, âmes, cartes en main de l'adversaire (3+ joueurs) | classe | Non (vérifié absent, `grep bg_boss_detail`) | — | — | À 3-4 joueurs, les mains adverses ne sont visibles nulle part. | Corrigé (Moyenne) |
| P-B28 | `OneOpponentDetail` (2 joueurs) : WOUNDS / SOULS « xN » | classe | Oui | B:434-446, 2163-2166 | Oui | | — |
| P-B29 | `OneOpponentDetail` : trésors sur fond teinté à la couleur du boss | classe | Oui | B:444-446, 2167-2169 | Partiel | Fond blanc au lieu de la teinte ; même comptage faux que P-B20. | Conforme (Basse) |
| P-B30 | « ROOM DECK x{RoomsInHand} » / « SPELL DECK x{SpellsInHand} » = cartes **en main** de l'adversaire (`OneOpponentDetail.cs:212`) | classe | Oui | B:2169-2172 | **Différent** | Vérifié : Godot affiche la taille des pioches communes (`G.decks.rooms/spells`). Le nombre de cartes de l'adversaire n'est jamais montré ; valeur fausse en permanence. | **Haute** |
| P-B31 | `DoneButtonEntity` : PASS TURN / DONE!, fondu 0,15 s | classe | Oui | B:482-494, 4246-4271 | Oui | | — |
| P-B32 | Premier appui = bulle, second = passe | logique | Oui | B:3526-3546 | Oui | | — |
| P-B33 | Barre jaune de 70 s dans le bouton (`activateTimeOuts`) | entité | Oui (sous une autre forme) | B:1093-1096 | Différent | Chiffre en haut d'écran. Renvoi module 9. | Conforme (Basse) |
| P-B34 | `halt_button_pulse` | asset | Non | — | — | = P-C51. | voir P-C51 |
| P-B35 | `DrawCardEmitter` : pioche animée (DrawCardEmitter:147) | classe | Oui | B:4118-4175, 4016 | Oui | | — |
| P-B36 | `DrawCardEmitter` : défausse animée | classe | Oui | B:4062-4114 | Oui | | — |
| P-B37 | `DungeonFrameEntity` : cadre, fond du boss, fondu | classe | Oui | B:357-404, 2070-2077 | Oui | | — |
| P-B38 | 5 emplacements (pas de 140), file d'entrée | emplacements | Oui | B:67-82, 841-858, 1439-1680 | Oui | | — |
| P-B39 | Sprite du boss avec `CharacterOffset` | méthode | Oui | B:1551-1612 | Partiel | Décalage par boss non comparé. | Conforme (Basse) |
| P-B40 | Clic sur le boss = zoom de sa carte ×1,3 (`DungeonFrameEntity.cs:269`) | événement | Non (vérifié absent : sprite en `MOUSE_FILTER_IGNORE`, B:377-378) | — | — | On ne peut pas lire la carte du boss adverse. | Corrigé (Moyenne) |
| P-B41 | Coup sur le boss : calque additif, secousse, voix (`DungeonFrameEntity.cs:489`) | méthode | Oui | B:2467-2497 | Oui | | — |
| P-B42 | Mort du boss : pierre tombale + voix | méthode | Oui | B:1571-1597, 2275-2283 | Oui | | — |
| P-B43 | Lueur `*_character_glow` du boss monté de niveau (`DungeonFrameEntity.cs:484`) | asset | Non (vérifié absent ; assets importés, jamais lus) | — | — | Le boss monté de niveau perd sa lueur rouge. | Corrigé (Moyenne) |
| P-B44 | `HighLightBuildableSlots` | méthode | Oui | B:3677-3730 | Oui | | — |
| P-B45 | Voile `frozzen_card` (gel) | asset | Oui | C:127-155, B:1651-1655 | Oui | | — |
| P-B46 | Clic sur un emplacement = zoom de la pile + bordure de capacité (`DungeonFrameEntity.cs:351`) | événement | Oui | B:3422-3467, D:80, 200-204 | Partiel | = P-C15. | voir P-C15 |
| P-B47 | Clic sur la file d'entrée = diaporama des héros (≥ 2) ou zoom (`DungeonFrameEntity.cs:382`) | événement | Oui | B:1517-1527 | Partiel | Seule la première carte est lisible ; zoom par appui long seulement. | Corrigé (Moyenne) |
| P-B48 | Salle adverse en attente décalée (`positionToBuild`) | animation | Non vérifié | B:1613-1680 | — | | — |
| P-B49 | `HandEntity` : éventail | classe | Oui | B:1986-2007 | Oui | | — |
| P-B50 | Saut de la main (pass and play) | comportement | Oui | B:742-780 | Oui | | — |
| P-B51 | `HeartDecrementEmitter` : « −N » qui monte de 140 px en 1,3 s | classe | Oui | B:2448-2465 | Oui | | — |
| P-B52 | Soin d'un héros (dégâts négatifs) | cas | Oui | B:2361-2364 | Partiel | Son joué, mais pas de cœur flottant. | Corrigé (Basse) |
| P-B53 | `HeartEntity` : PV du héros | classe | Oui | B:2392-2418 | Oui | | — |
| P-B54 | Cœur sur la carte : dégâts ou PV courants en or quand ils diffèrent de l'imprimé (`SlotRoomCardEntity.cs:30`) | asset | Non (vérifié absent, `grep health_room`) | — | — | On ne voit ni les dégâts modifiés d'une salle ni les PV restants d'un héros blessé. Même cause que P-B09. | Corrigé (Moyenne) |
| P-B55 | `IconCounterControlEntity` : fondu par icône | classe | Oui | B:2079-2131 | Partiel | Fondu seulement sur mon panneau. | Corrigé (Basse) |
| P-B56 | `LevelUpBanner` | classe | Oui | B:1283-1346 | Oui | | — |
| P-B57 | Reflets `bg_lu_shine_cuarto` | asset | Non | — | — | Invisibles sur les captures. | Accepté (Basse) |
| P-B58 | `PhaseTitleControl` | classe | Oui | B:2009-2068 | Oui | | — |
| P-B59 | `ProgressBarEntity` : 3 s / 6 s | classe | Oui | `TimeBar.gd:1-34` | Oui | | — |
| P-B60 | Horloge `timebar_clock`, ralenti ×0,07 | asset | Non | B:937-938 | Différent | = P-C29. | voir P-C29 |
| P-B61 | `SlotDetailEntity` : zoom à plusieurs cartes (pile, boss + sorts « jusqu'à la fin du tour ») | classe | Non (vérifié absent) | B:3802-3814 | — | = P-C15. | voir P-C15 |
| P-B62 | `SpellBattleEntity` : pile au centre | classe | Oui | B:3845-3910 | Oui | | — |
| P-B63 | `TopLeftPanelEntity` : colonne de la ville, tas de défausse | classe | Oui | B:406-431, 1348-1360 | Oui | | — |
| P-B64 | File de la ville qui défile | composant | Oui | B:1348-1437 | Partiel | Ordre inversé : P-C47. | voir P-C47 |
| P-B65 | Clic sur un héros de la ville = zoom à gauche | événement | Oui | B:3802-3814 | Partiel | Appui long ou clic droit. | Corrigé (Basse) |
| P-B66 | Clic sur le tas = diaporama de la défausse | événement | Oui | B:4349-4382 | Différent | = P-C17. | voir P-C17 |
| P-B67 | `discard_pile_legend` (backer) | asset | N/A | — | — | Boutique supprimée. | — |
| P-B68 | Bouton d'options `bt_options` | bouton | Oui | B:603-648 | Partiel | Engrenage dessiné par code au lieu de la texture APK. | Corrigé (Basse) |

### 7C — Composants du plateau

| ID | Élément source (décompilé) | Type | Présent dans Godot ? | Fichier Godot | Équivalent fonctionnel ? | Écart / Commentaire | Priorité |
|---|---|---|---|---|---|---|---|
| P-C01 | `AddCarouselCardsBehavior` : cartes du carrousel qui montent une à une en 1,0 s, `ui_card_slide_general` (:50, :98) | comportement | Non (vérifié absent) | B:1771, 1974 | Différent | Les 7 cartes de la défausse d'ouverture apparaissent d'un coup, sans son. | Corrigé (Moyenne) |
| P-C02 | `AppearBehavior` : zoom 0,2 s, 0,8 → 1,3 | comportement | Oui | B:3816-3843 | Oui | | — |
| P-C03 | `BaseZoomComponent` : position, verrou pendant une résolution | composant | Oui | B:3802-3814 | Partiel | Position différente ; pas de verrou. | Corrigé (Basse) |
| P-C04 | `BossCardManagerComponent` : une main par siège | composant | Oui | B:742-776, 1681 | Oui | | — |
| P-C05 | `CardDroppedEventArgs` | DTO | N/A | — | — | | — |
| P-C06 | `CardExtractBehavior` : la carte sort de la main au-dessus de y 797, y retourne en redescendant ; carte non jouable non extraite (:166, :180) | comportement | Oui | B:3578-3618, 3750 | Partiel | Godot démarre le glisser après 12 px dans toute direction, annule au relâchement sous y 940, et laisse glisser une carte grisée (`_drag_begin` ne teste pas `playable`). | Corrigé (Moyenne) |
| P-C07 | `CardHoverBehavior` : carte au centre le plus proche du pointeur, toute la main se replace (:106) | comportement | Oui | C:248-264, B:1996-2007 | Partiel | Godot garde la carte survolée tant que le pointeur reste dessus ; les voisines ne bougent pas. | Partiel (Moyenne) |
| P-C08 | `CardHoverDetailBehavior` | comportement | N/A | — | — | Jamais instancié. | — |
| P-C09 | `CardHoverWithDelayBehavior` : survol retardé de 0,3 s | comportement | Non | C:248 | Différent | | Accepté (Basse) |
| P-C10 | `CardManagerComponent` : main triée salles puis sorts (:116), cartes grisées | composant | Oui | B:1730-1778 | Partiel | Grisage fidèle ; tri non retrouvé côté interface (non vérifié en jeu). | Corrigé (Moyenne) |
| P-C11 | `CardMoveBehavior` : glissement des cartes (lerp 0,009 par ms) | comportement | Oui (survol seulement) | C:238-246 | Partiel | La main est recréée à chaque rafraîchissement : quand une carte est jouée ou piochée, les autres sautent à leur place au lieu de glisser. | Corrigé (Moyenne) |
| P-C12 | `CardPositionComponent` : éventail, carte survolée ×1,2, voisines écartées (:151-200) | composant | Oui | B:1986-2007 | Partiel | Géométrie au repos identique. Au survol, pas de grossissement (choix documenté, `docs/HANDOFF.md:116`) ni d'écartement. | Accepté (Basse) |
| P-C13 | `CardSelectorComponent` : choisir N cartes (:120-150) | composant | Oui | B:3221-3234, 2631-2705 | Partiel | `_popup_cards` n'accepte qu'une carte. | Accepté (Basse) |
| P-C14 | `CardStackSlotComponent` : pile (1 carte dessous visible), vol de la salle posée vers son emplacement, agrandissement en surbrillance (:29, :95, :210-296) | composant | Oui | D:25-140, C:98-154, B:2424-2446 | Oui | **Corrigé le 2026-10-28.** Une seule carte sous la pile (déjà fait). Vol : `DungeonSlot._fly_pending` reprend `MovePendingRoomToRightPlace` (`:210-233`) et `DungeonFrameEntity.Refresh` (`:398-409`) : la salle posée en attente (et son ombre) part de la pile d'attente (premier emplacement libre, `min(4, DungeonSize)`), décalage `(i − k) × 140` px (pas des emplacements `-236 + n × 140`), durée `|décalage| / 1920` s (`VirtualWidth`), `CubicEase` EaseOut. Nul quand la salle est posée sur le premier emplacement libre, comme l'APK. Pas d'agrandissement en surbrillance (hors périmètre). Non joué à l'œil nu, ni en headless (animation coupée). | Partiel (Moyenne) |
| P-C15 | `CardZoomComponent` + `SlotDetailEntity` : zoom d'une pile de salles ou du boss avec ses sorts du tour (:31) | composant | Oui (carte seule) | B:3433-3437, 3802-3814 | Partiel | Seule la salle du dessus est zoomée, et seulement si elle est activable ; les salles recouvertes et les sorts actifs sur un boss ne se consultent pas. Regroupe P-A36, P-A42, P-B46, P-B61. | Corrigé (Moyenne) |
| P-C16 | `CarouselSelectorShowComponent` : fond en 0,1 s, cartes après 0,5 s (:49) | composant | Oui | B:1178-1221 | Partiel | Tout apparaît d'un coup. | Corrigé (Moyenne) |
| P-C17 | `CarouselShowComponent` : diaporama de la défausse et de la file d'entrée (:63, `GamePlayBaseScene.cs:710-765`) | composant | Non (vérifié absent) | B:4349-4381 | Différent | Vérifié : le clic sur la défausse ouvre un `AcceptDialog` avec des noms en texte, héros morts compris ; aucune image de carte. Le clic sur la file d'entrée ne fait rien. Regroupe P-A39, P-A40, P-B16, P-B66. | Corrigé (Moyenne) |
| P-C18 | `CountDownBehavior` (salle publique en ligne) | composant | Oui | `CountDown.gd:49-84` | Différent | Réutilisé comme minuteur de tour en ligne. Renvoi module 9. | Accepté (Basse) |
| P-C19 | `DoneButtonBehavior` : variantes avec minuterie, fondu 0,3 s | comportement | Oui | B:4246-4275 | Partiel | | Corrigé (Basse) |
| P-C20 | `ExpandedOpponentComponent` : panneau adverse qui se déroule | composant | Non (vérifié absent) | B:801-832 | Différent | = P-B27. | voir P-B27 |
| P-C21 | `ExpansionScrollComponent` | composant | N/A | — | — | Boutique supprimée. | — |
| P-C22 | `HeartControlComponent` : cœur de dégâts au-dessus d'une salle modifiée, cœur du héros en fondu | composant | Oui (héros) | B:2406-2464 | Partiel | = P-B54 pour le cœur de salle. | voir P-B54 |
| P-C23 | `HeroesQueueComponent` : file d'entrée (−40 px par rang, échelle 0,4 puis 0,36, glissement 0,5 s) | composant | Oui | B:1439-1466 | Partiel | Cartes toutes à la même taille ; pas de glissement. | Corrigé (Basse) |
| P-C24 | `HideWhenTouchBehavior` : bulle qui entre en 0,5 s et se ferme au clic extérieur | comportement | Oui | B:4210-4239 | Partiel | Bulle instantanée, fermée après 6 s. | Corrigé (Moyenne) |
| P-C25 | `IsHoverBehavior` | comportement | N/A | — | — | Code mort. | — |
| P-C26 | `JumpBehavior` : 300 px, 0,5 s, BackEase 0,4 | comportement | Oui | B:778-780, 2065-2068 | Oui | | — |
| P-C27 | `MiddleCarouselAnimationBehavior` : bande noire qui s'ouvre en 0,5 s, opacité 0,8 | comportement | Oui | B:1185-1198, 2635-2638 | Différent | Bande affichée d'un coup, opacité 0,88 (mesurée sur capture). | Corrigé (Moyenne) |
| P-C28 | `MiddleCarouselShowComponent` | composant | Oui (sélecteur) | B:1178-1221, 2631-2705 | Partiel | Partie diaporama : P-C17. | Conforme (Basse) |
| P-C29 | `ProgressBarBehavior` : 141 px, horloge `timebar_clock`, fondu 0,2 s (:23, :176) | comportement | Oui | `TimeBar.gd`, B:945-963 | Partiel | Pas d'horloge ni de fondu. | Corrigé (Basse) |
| P-C30 | `PulseBehavior` : anneaux de capacité, 2 s | comportement | Oui | D:177-188 | Oui | | — |
| P-C31 | `RearrangeSelectorComponent` (Hellcow : échanger deux cartes) | composant | Non (vérifié absent) | M:975, `RoomAbilities.gd:928` | Différent | Choix successifs dans une liste. | Accepté (Basse) |
| P-C32 | `RupisLoadingBehavior` (écran de chargement) | comportement | Non | — | — | Hors plateau. | Accepté (Basse) |
| P-C33 | `ScrollListBehavior` | comportement | Non vérifié | — | — | Menu principal (module 4). | — |
| P-C34 | `ScrollType` | enum | N/A | — | — | | — |
| P-C35 | `ShowHideTaskComponent` | composant | N/A | — | — | Infrastructure. | — |
| P-C36 | `ShowHintComponent` | composant | Oui | B:3526-3550, 4205-4226 | Oui | | — |
| P-C37 | `SimpleHoverBehavior` sur la pile de sorts : survol = bordure rouge et cibles en évidence | comportement | Non (vérifié absent : cartes de pile en `MOUSE_FILTER_IGNORE`, B:3865) | B:3845-3881 | Différent | On ne voit pas ce que vise un sort adverse posé sur la pile. | Corrigé (Moyenne) |
| P-C38 | `SimplePositionComponent` : pile de sorts | composant | Oui | B:3894-3908 | Partiel | Pas de glissement. | Corrigé (Basse) |
| P-C39 | `SimpleSelectorBehavior` | comportement | N/A | — | — | Code mort. | — |
| P-C40 | `SoulLoadingComponent` (tutoriel) | composant | Oui | `TutorialOverlay.gd:988-1038` | Oui | Renvoi module 8. | — |
| P-C41 | `SpellBattleComponent` | composant | Oui | B:945-1052 | Partiel | Pas de fondu de barre. | Corrigé (Basse) |
| P-C42 | `SpellBattleHighLightsComponent` : cible sur la pile encadrée | composant | Oui | B:2729-2741 | Partiel | Une cible sur la pile passe par une liste. | Corrigé (Moyenne) |
| P-C43 | `SpellBattleShowComponent` : fondu 0,1 s | composant | Oui | B:3857-3881 | Partiel | | Corrigé (Basse) |
| P-C44 | `TextAndBackgorundComponent` : bulle, décalage selon la longueur | composant | Oui | B:1214-1219 | Partiel | | Conforme (Basse) |
| P-C45 | `TouchOutBehavior` : fermeture au relâchement hors zone | comportement | Oui | B:1963-1969 | Partiel | Fermeture à l'appui. | Accepté (Basse) |
| P-C46 | `TutorialSelectorComponent` | composant | N/A | — | — | Renvoi module 8. | — |
| P-C47 | `VerticalScrollQueueComponent` : colonne de la ville, **dernier arrivé en haut** (entrée par le haut à y −110, `CreateReorderTask` donne y 120 au dernier de la liste : `VerticalScrollQueueComponent.cs:183-211`) | composant | Oui | B:1348-1437 (boucle sur `town` à partir de l'index 0, B:1368) | Différent | Vérifié dans le C# : l'APK met le héros arrivé en dernier en haut et le plus ancien (le prochain à être attiré) en bas, puis fait défiler vers le bas. Godot construit `town[0]`, le plus ancien, en haut : la colonne est inversée. À confirmer sur une capture. Pas de rebond ni d'inertie. | Corrigé (Moyenne) |
| P-C48 | `WoundLoadingComponent` (tutoriel) | composant | Oui | `TutorialOverlay.gd:988-1013` | Oui | | — |
| P-C49 | Géométrie de la main (`HandEntity.cs:32-46`) | géométrie | Oui | B:82-84 | Oui | | — |
| P-C50 | Géométrie des emplacements et de la file (`DungeonFrameEntity.cs:356,370`) | géométrie | Oui | B:66-81 | Oui | | — |
| P-C51 | Bouton DONE : pulsation `halt_button_pulse` ×3 toutes les 5 s (`DoneButtonEntity.cs:98-106`) | comportement | Non (vérifié absent ; assets importés, jamais lus) | B:4246-4275 | Différent | Le bouton ne pulse pas pour inviter à finir le tour. Regroupe P-A29 et P-B34. | Corrigé (Moyenne) |
| P-C52 | Bulle « HAS PLAYED » : une impulsion de 4 anneaux | comportement | Oui | B:3968-3995 | Partiel | Godot fait osciller l'alpha en boucle. | Conforme (Basse) |

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
| T-A04 | Réaffichage forcé après mise à jour : `CheckForcePlayTutorial("2.2.6","2.2.4")` repasse `IsFirstGameplay` à vrai (Game.cs:119, GameStats.cs:33-42) | Game / GameStats | Non (`grep -in "version\|CheckForce" Profile.gd` : aucune version de tutoriel) | — | — | Pas de mécanisme de version. Sans objet pour un port web neuf. **6e :** voir la section « Lot 6e ». | Corrigé (6e) |
| T-A05 | Plateau imposé : `InitializeGameBoardTutorial`, jeu de base, 2 joueurs, humain BMA003 (KING CROAK), IA BMA006 (SEDUCIA) avec `FixedAI` (GameBoardExtensions.cs:19-52) | Extension GameBoard | Oui | GameManager.gd:24-45 ; ApkAI.gd (port de FixedAI) | Oui | Les bosses, le jeu de base et l'IA FixedAI sont conformes. | — |
| T-A06 | Pioches prioritaires : salles `032,026,034,027,016`+`010,020,019,009,021`+`022,021` ; sorts `041,055,054,044` ; héros `064,068` (`PrioritizeQueueCards`, sommet en premier) | GameBoardExtensions.cs:24-37,207-219 | Oui | GameManager.gd:27-29,39-41,47-54 | Oui | Les trois listes et leur ordre sont identiques. | — |
| T-A07 | `RandomProvider.Seed = 2832` : tout le reste des pioches et de l'aléatoire de l'IA | GameBoardExtensions.cs:23 | Partiel | GameManager.gd:26,34-37 | Partiel | Le générateur .NET n'est pas reproductible. Hors cartes imposées, le reste des pioches et l'aléatoire de l'IA diffèrent de l'APK, et les étapes avalées en dépendent (voir T-A31). Écart reconnu dans le commentaire de `GameManager.gd:26`. | Accepté (Moyenne) |
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
| T-A22 | Adventure_c, humain : main verrouillée, page23 (« HIT THIS ROOM ») attachée à `Slots[2].TopRoom`, rejouée à chaque tour de barre (cs:240-252,258-278) | p23 + `ProgressBarBehavior_Loop` | Partiel | TutorialOverlay.gd:424-427, 276-287, 330-345, 708-716 | Partiel | L'APK rejoue p23 à chaque tour de la barre de temps. Godot fige la partie et rejoue la consigne après 8 s sans action (`NAG`). Équivalent en pratique. L'indice `_slot_node(0)` correspond bien à BMA027 (index Godot 0 = 1re salle traversée). **6e :** voir la section « Lot 6e ». | Corrigé (6e) |
| T-A23 | Ouverture du détail de BMA027 avec le héros 064 dedans (`CheckPlayRoomAbilityCondition`) : verrou du carrousel, page24 « TAP THE ROOM DESCRIPTION… », barre en pause (cs:322-335,386-394) | `OnRoomDetailShow`, p24 | Oui | TutorialOverlay.gd:482-495, 276-287, 722-725 | Oui | Texte conforme, `_hit_state` reprend les conditions. La partie reste figée pendant la consigne (équivalent de `Pause`/`Resume`). | — |
| T-A24 | Âme de 064 (`CheckFirstSoulHero`, `firstWound`) : scène page26 « SPLENDIT… » + DONE déverrouillé (cs:215-221,418-424) | p26 | Oui | TutorialOverlay.gd:428-433, 460-465, 731-735 | Oui | Déclenchée sur « âme 064 + animations finies ». Pas de contrôle « joueur actif = humain », sans conséquence ici. | — |
| T-A25 | Sort BMA041 : `CheckPlaySpellCondition` (héros 068 à l'entrée de la mine adverse, sort en main), page27 forcé sur le mage, cible imposée (cs:226-235,396-405) | TutorialDragCardScene p27 (isReinforcement) | Oui | TutorialOverlay.gd:259-274, 434-439, 533-543 | Oui | Texte immédiat comme `isReinforcement:true`. Le coup est limité à `playSpell` sur 068 et la zone de dépôt à l'entrée de la mine adverse. L'APK force « le 1er sort de la main » : même carte, car BMA055 est défaussé. | — |
| T-A26 | Rappel de p27 sur 068 à chaque tour de barre (`ProgressBarBehavior_Loop`, cs:269-277) | `ProgressBarBehavior_Loop` | Partiel | TutorialOverlay.gd:330-338 | Partiel | Même équivalence par le rappel à 8 s que T-A22. **6e :** voir la section « Lot 6e ». | Corrigé (6e) |
| T-A27 | Dépôt de BMA041 (`CardDropped`, `Handled`) : barre en pause, 0,5 s, puis page28 (cs:312-318) | `MyHand_CardDropped` | Oui | TutorialOverlay.gd:294-296, 440-444 | Oui | Délai de 0,5 s, texte et partie figée tant que le sort est sur la pile. | — |
| T-A28 | Effet du sort résolu (`AbilityApplyDone` + PV = initial+3) : page29 (cs:320-326,407-415) | p29 | Oui | TutorialOverlay.gd:445-449, 476-480 | Partiel | Godot exige en plus que p28 ait été montrée (`_done.has("adv28")`) ; pas l'APK. Sans conséquence si p28 se joue. **6e :** voir la section « Lot 6e ». | Corrigé (6e) |
| T-A29 | Blessure de l'IA sur 068 (`CheckFirstWoundHero`, `firstSoul`) : page25 « HAHA… CROAKS » (cs:222-225,427-433) | p25 | Oui | TutorialOverlay.gd:449-453, 468-474 | Partiel | L'APK le montre au `NextStep` suivant en AdventurePhase_b avec l'IA active. Godot la lit comme un état permanent (blessure de 068 au tour ≤ 1), sans délai. Le texte est le même, le moment peut différer. **6e :** voir la section « Lot 6e ». | Corrigé (6e) |
| T-A30 | Première montée de niveau du boss humain : p30 (« WOW!! … ») puis p31 (« YOU DON'T KNOW… ») (cs:361-370, TutorialLevelUpScene) | CreateBeforeLevelUpTask | Oui | TutorialOverlay.gd:455-457, 758-770 ; BoardUI.gd:1288,3069 | Oui | `levelup` et `choice` retardent la bannière jusqu'à la fin des deux pages. Textes conformes ; le jeu reprend ensuite normalement. | — |
| T-A31 | Étapes dont la condition ne survient pas (tirage ou IA différents) | architecture générale | Partiel | TutorialOverlay.gd:1-16, 329-458 | Différent | L'APK suppose le déroulé. Godot saute une étape dont la condition n'arrive pas et ne bloque jamais le joueur. C'est un choix défensif (mieux que de planter), mais p25/p26/p28/p29 peuvent ne jamais s'afficher si l'IA ou le hasard s'écartent. | Accepté (Moyenne) |
| T-A32 | Restrictions limitées au tour 0 (`NumberOfTurns==0`), puis jeu normal (cs:181 ...) | `CreateBeforePlayerInteractionTask` | Oui | TutorialOverlay.gd:204-205 (`_turn() <= 1`) | Oui | À la fin, le jeu continue sans tutoriel, comme dans l'APK (captures tut_126-129). | — |
| T-A33 | Scènes de rappel (carte invalide / DONE verrouillé) : `ShowReinforcementScene`, 4 branches (cs:280-309) | InvalidCardPlayed, DoneHaltButton_PressedWhenLocked | Oui | TutorialOverlay.gd:523-530, 544-548, 578-593 | Partiel | Drag invalide et DONE verrouillé sont couverts. En revanche un simple clic (`tap`, l.553-562) sur une mauvaise carte est refusé sans scène de rappel. À confirmer côté APK (`CardExtractBehavior.cs:216`). **6e :** voir la section « Lot 6e ». | Corrigé (6e) |
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
| T-B12 | King Croak : `kingcroak_anim`, 7 images à 8 i/s en boucle, échelle 8,7, retourné, position (100,343) (TutorialIntroScene.cs:144-161) | Entité animée | Oui | TutorialOverlay.gd:53-57, 893-907, 1109-1113 | Oui | x = 349 au lieu de 340 : décalage de +9 px mesuré par corrélation (l.53). Écart cosmétique. **6e :** voir la section « Lot 6e ». | Conforme (6e) |
| T-B13 | Intro 2, p04 : même scène globe + King, mains (800,485) (cs:30-47, 108-117) | `isFirstPart:false` | Oui | TutorialOverlay.gd:605-621 | Oui | Le décor noir de `tut_17..20` est fourni par `board.make_intro_field()` (l.610). L'APK le tient du plateau non encore distribué. | — |
| T-B14 | p05 `SoulLoadingComponent(10)` : détail à (690,385), icônes tous les 50 px ; vides en parallèle (0,2 s), pleines une à une, lueurs en parallèle ; `FinishState` ; main (RightEdge-395, 640) (SoulLoadingComponent.cs ; cs:56-72, 120-134) | Composant + tâche | Oui | TutorialOverlay.gd:988-1013 ; appel l.614 (base 930,385) | Oui | Le détail est retiré au début de l'étape suivante (l.943-945), comme dans l'APK. | — |
| T-B15 | p08 `WoundLoadingComponent(5)` + `boss_tombstone` (origine (0,0,5), x = 5×50) ; 2e texte qui prolonge le 1er (`text.Length`) ; main (RightEdge-395, 580) (WoundLoadingComponent.cs ; cs:73-86, 136-152) | Composant | Oui | TutorialOverlay.gd:988-1013 (pierre l.1000, 1010) ; appel 618 | Oui | Pas de lueur pour les blessures, conforme à l'APK. Confirmé sur `tut_20` (5 gouttes + RIP). | — |
| T-B16 | `TutorialDiscardTwoCardsScene` : bulle medium (720,200), pas de Delay 0,2 s, main verticale non retournée à (720,576), voile plein sans trou (TutorialDiscardTwoCardsScene.cs:15-48) | Scène | Oui | TutorialOverlay.gd:623-628 | Oui | Confirmé sur `tut_22` (bulle centrée en x=960, main au centre). Déclenchement 0,9 s après l'ouverture du sélecteur : `CarouselSelectorShowComponent.cs:58` ↔ Godot l.316-319, 369-376. | — |
| T-B17 | Pointeurs de défausse sur BMA026 et BMA055 : local (-50,400), rotation -90°, tremblement vertical, fondu de 0,5 s retiré quand la carte est choisie (AddCarouselCardsBehavior.cs:117-131 ; TutorialSelectorComponent.cs:57-64) | `InTutorialModeAddHandsToDiscardCards` | Oui | TutorialOverlay.gd:1120-1146 | Oui | Conforme à `tut_22` : deux mains doigt en haut sous Ligers et Zombie Attack. | — |
| T-B18 | `TutorialSelectorComponent.UpdateSelectedCards` : seules les 2 cartes ciblées se choisissent. Mauvais choix → `BossHint = WrongCardPick`, bon choix → `RightCardPick`, 2 choisies → `ClickContinue`. La bulle `BossHint` (boss_globe 230×400, enfant du boss) apparaît en 0,5 s (échelle 0,8→1, opacité 0,5→1) et ne se ferme qu'en touchant HORS de la bulle (TutorialSelectorComponent.cs:34-55 ; HideWhenTouchBehavior.cs ; DungeonFrameEntity.cs:137-146, 260-262) | Bulle d'indice | Oui | TutorialOverlay.gd:565-576 (logique), 1067-1088 (bulle), 1091-1093, 321-326 (minuterie) | Partiel | La logique de choix est identique. Écarts sur la bulle : (a) Godot la retire automatiquement après 6 s (`_hint_t = 6.0`) alors que l'APK n'a aucun minuteur ; (b) l'apparition est instantanée, sans fondu ni zoom ; (c) Godot la ferme sur n'importe quel clic (`_input`, âge > 0,25 s), l'APK seulement hors de la bulle. Au bout de 6 s, « HIT CONTINUE, MINION » disparaît alors que le bouton CONTINUE n'est pas pressé. Géométrie fixe mesurée sur `tut_26` (1285, 589, 238×150). | Corrigé (Moyenne) |
| T-B19 | `TutorialFirstDrawedCardScene` : bulle medium (720,162), sans Delay, main retournée non verticale à (936,378), main du joueur attachée ; `IsCardEnabled` sur BMA022 (TutorialFirstDrawedCardScene.cs:34-72) | Scène | Oui | TutorialOverlay.gd:660-675 | Oui | Confirmé sur `tut_62` : main à x 1175-1345, y 385-475. Godot fige en plus la carte piochée en vol (l.664-667) pour la garder au-dessus du voile. | — |
| T-B20 | `TutorialDragCardScene` (p13/p16/p19) : bulle long (720,645), 2 messages si non renfort, main enfant de la carte imposée en local (50,-450), rotation +90°, tremblement vertical, retirée à `End` (TutorialDragCardScene.cs:39-102) | Scène + pointeur de carte | Oui | TutorialOverlay.gd:630-648, 925-938 | Oui | Confirmé sur `tut_28` : bulle centrée à y 645, main au-dessus de la carte. Le 2e message se retape depuis 0 (l.639). Seule la main du joueur est éclairée (trou = `_hand_rect`). | — |
| T-B21 | Variante renfort (`isReinforcement`) : texte d'un coup, main reposée (cs:290-307 ↔ TutorialDragCardScene.cs) | Scène | Oui | TutorialOverlay.gd:578-594 ; `gate("drag")` l.529-534 ; `gate("pass")` l.543-546 | Oui | Mêmes appels que l'APK : p13, p19, p16 selon la phase, et le DONE verrouillé. | — |
| T-B22 | `TutorialDoneButtonScene` : bulle long (720,226), main verticale retournée à (position du bouton + (-50,-210)), bouton éclairé, hit-test du bouton désactivé (TutorialDoneButtonScene.cs:23-74) | Scène | Oui | TutorialOverlay.gd:650-658 | Oui | Confirmé sur `tut_46` : la main (≈905-1000, 290-460) se pose sur le bouton DONE. Les cartes de la main restent assombries, comme l'APK (seul le bouton est attaché). | — |
| T-B23 | `TutorialBaitScene` : bulle large (800,350), main retournée à (LimitedLeftEdge+200, 320), colonne HEROES IN TOWN attachée, 2 pages (TutorialBaitScene.cs:13-82) | Scène | Oui | TutorialOverlay.gd:689-696 | Oui | Confirmé sur `tut_65`/`tut_67` : colonne gauche éclairée, bulle à (1040,350). Les icônes du premier texte sont retirées au début du second. | — |
| T-B24 | Icônes de trésors : fighter/thief/cleric/mage tous les 160 px à (bulle + (-240,60)), décalages y 3/6/0/6, fondu 0,5 s (TutorialBaitScene.cs:84-125) | `CreateShowDetailTask` | Oui | TutorialOverlay.gd:1038-1058 | Oui | Position (800+160 i, 410+dy), centre. Non confirmé sur capture : `tut_66`/`tut_67` ne montrent pas les icônes tapées. | — |
| T-B25 | `TutorialAdventureScene` p22 : bulle large (600,250), main 1 (320,700) retournée par le bug, main 2 (RightEdge-710, 490), héros + dégâts totaux attachés (cs:50-60) | Scène | Oui | TutorialOverlay.gd:698-756 (cas 22) | Oui | Confirmé sur `tut_80` : bulle centrée à (840,250), main 1 sur le héros doigt à gauche, main 2 sur DAMAGE doigt à droite. | — |
| T-B26 | p23 : bulle medium (salle + (0,-350)), main (salle + (-250,0)), salle et barre attachées, barre mise en pause pendant la scène (cs:61-69, 160-165) | Scène | Oui | TutorialOverlay.gd:698-756 (cas 23), `_holding` 290, `NAG` 32 | Partiel | Géométrie conforme à `tut_84` (bulle (1003,373), main à x≈750). Différence de flux : Godot fige la partie tant que le joueur n'a pas joué la salle et rejoue la consigne après 8 s sans action. L'APK relance la barre et ne rejoue qu'à chaque tour de barre. Plus indulgent, ne bloque jamais. **6e :** voir la section « Lot 6e ». | Corrigé (6e) |
| T-B27 | p24 : bulle long (VirtualWidth/2, VirtualHeight/2-350), main (centre + (-300,200)), voile plein (cs:70-75) | Scène | Oui | TutorialOverlay.gd:698-756 (cas 24), `_on_room_detail` 482-497 | Oui | Confirmé sur `tut_100` : la zone de détail de salle est assombrie sous le voile plein. | — |
| T-B28 | p25 / p26 : bulle medium et main relatives au panneau (panel + (-550,100/200), panel + (-200,50/150)) ; boss et panneau de détail attachés (cs:76-90) | Scène | Oui | TutorialOverlay.gd:698-756 (cas 25 et 26) | Oui | Panneaux et bulles codés en dur (1709/1159 en x). Conforme à `tut_108` (p26 : main (1509,633)). Pour p25, aucune capture ne montre la scène : Non vérifié visuellement. | — |
| T-B29 | p27 (via DragCard renfort, héros attaché) : « LOOKS LIKE SOMEONE HAS VISIT… », main sur le sort (GamePlayTutScene.cs:231, 274) | Scène | Oui | TutorialOverlay.gd:630-643 (appels l.355-358, 380-386) | Oui | Même coup attendu que l'APK : entrée adverse comme zone de dépôt (`gate("spell_drop")` l.536-538). | — |
| T-B30 | p28 : bulle long (VirtualWidth/2, VirtualHeight/2-400), main (400,350), carte de sort, main et barre attachées (cs:106-114) | Scène | Oui | TutorialOverlay.gd:698-756 (cas 28) | Oui | Confirmé sur `tut_118` : bulle centrée à (960,140), main à (640,350), carte Assassin et barre éclairées. | — |
| T-B31 | p29 : bulle long (VirtualWidth×1,2, 150), main verticale (200,350) (cs:115-123) | Scène | Oui | TutorialOverlay.gd:698-756 (cas 29) | Oui | Positions + 240 conformes (bulle (1104,150), main (440,350)). Aucune capture dans l'index pour p29 : Non vérifié visuellement. | — |
| T-B32 | `TutorialLevelUpScene` p30/p31 : p30 bulle long (VirtualWidth×0,5, 400), main (LimitedLeftEdge+150, 640) ; p31 bulle neuve (LeftEdge+500, 580), mains (RightEdge-395, 950) et (RightEdge-550, 780) ; boss et bouton LEVEL UP attachés (TutorialLevelUpScene.cs:25-88) | Scène | Oui | TutorialOverlay.gd:758-771 | Partiel | Positions et bulles conformes au C#. Écart sur le trou : Godot éclaire le rectangle entier de la plateforme du boss (300×210, BoardUI.gd:379-392) alors que l'APK n'attache que l'entité boss. Pour p26, Godot copie seulement le sprite du boss (l.725 : `sprites = [… "sprite"]`), il est donc incohérent entre les deux scènes. Aucune capture du tutoriel pour p30/p31 : `levelup_*` est une partie normale. **6e :** voir la section « Lot 6e ». | Corrigé (6e) |
| T-B33 | Comportement des entités attachées interactives pendant la scène : LEVEL UP (p31), pièces de la main, héros (cs:179-193 ; TouchGestures désactivé seulement pour DONE et la main) | TouchGestures | Non vérifié | TutorialOverlay.gd:779-780 (voile STOP partout) | Non vérifié | Godot avance au clic n'importe où. Dans l'APK, un tap sur LEVEL UP/boss pendant p31 atteint peut-être l'entité plutôt que le fond (priorité de collider de Wave non lue). **6e :** voir la section « Lot 6e ». | Accepté (6e) |
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
| N-A05 | `OnDisconnect` (Disconnect, TimeoutDisconnect, DisconnectByServer, …UserLimit, …Logic, S/OnlineClient.cs:245-255) | événement | Oui | OC:135-149 | Partiel | `STATE_CLOSED` déclenche une reconnexion avec backoff 1 à 8 s (OC:151-153) et un `resume`. Message "connexion perdue, reconnexion..." émis par `request_error`, mais seul l'écran d'attente l'écoute (OM:766). En partie, rien n'est affiché au joueur (voir N-A41). Seul le motif d'éviction (1000) est distingué ; pas de distinction timeout, limite d'utilisateurs ou logique serveur. | Corrigé (Moyenne) |
| N-A06 | `OnException` (ExceptionOnConnect, Exception, ExceptionOnReceive, S/OnlineClient.cs:256-264) | événement | Oui | OC:155-162,194-198 | Oui | Échec de `connect_to_url` : retry. Timeout de requête 8 s (OC:27,190) avec message "connexion impossible" ou "le serveur ne répond pas". | — |
| N-A07 | `SendInternalEvent` : index d'ordre mod 100, JSON dans Hashtable, `ReceiverGroup.Others` (S/OnlineClient.cs:175-206) | méthode | Non, par design | OC:164 `_send`, OC:386 `send_move` | Oui | Plus de diffusion pair à pair : le client envoie seulement `{t:"move",move}`. L'ordre est garanti par TCP/WebSocket, donc l'index d'ordre n'a plus d'objet. `PhotonClientOwnerId` est remplacé par `seat_of(conn)` côté serveur (SV:392) : pas d'usurpation de siège possible. | — |
| N-A08 | `OnlineClient.NextEventOrderIndex`, `PendingOrderedReceivedEvents`, `PendingUnorderedReceivedEvents`, `MAX_EVENT_ORDER_INDEX` (S/OnlineClient.cs:25-35,218-231) | champ/file | Non (vérifié absent : `grep -rn "order_index\|PendingOrdered" scripts server` = 0) | — | Oui (sans objet) | Réordonnancement par joueur (Photon n'ordonne pas entre émetteurs) inutile : un seul flux serveur ordonné, état complet renvoyé après chaque coup. | — |
| N-A09 | `GetPlayerUsername` (S/OnlineClient.cs:208) | méthode | Oui | GR:341-346 (`name` du siège), SV:241 `_clean_name` | Oui | Nom nettoyé côté serveur (contrôle, bidi, 25 car.), défaut "Joueur". | — |
| N-A10 | `OnlineClient.OnOperationResponse` (S/OnlineClient.cs:268) | méthode | N/A | — | Oui | Simple appel à la base, sans effet propre. | — |
| N-A11 | `OnlineService : UpdatableService`, `Initialize` / `Terminate` / `Update` (S/OnlineService.cs:536,544,549) | classe | Oui | OC (Node), SV | Oui | Le client est un `Node` ; l'`Update` n'a plus à dépiler d'événements, les messages sont traités à la réception (OC:116-121). | — |
| N-A12 | `Update` : reconnexion automatique toutes les 4 s si Offline et `maintainConnected` (S/OnlineService.cs:555-565) | méthode | Oui | OC:97-103,151-153 | Oui+ | Backoff 1 à 8 s et reprise du même siège via `resume` (OC:110-111). L'APK ne revient qu'au lobby, il ne rentre jamais dans sa salle. | — |
| N-A13 | `OnlineService.Connect` / `Disconnect` (S/OnlineService.cs:605,611) | méthode | Oui | OC:343 `watch_rooms`, OC:352 `unwatch_rooms`, OC:170 `_ensure_open` | Oui | Liaison ouverte à la demande, fermée au départ du lobby public si aucune salle. | — |
| N-A14 | `OnlineService.CurrentPlayer` (`OnlinePlayerInfo`) / `CurrentRoom` (`OnlineRoomInfo`) (S/OnlineService.cs:60-61, init à 536-542) | propriété | Oui | OC:36-58 (`match_id`, `player_id`, `current_seats`, `current_title`, `current_status`…) | Oui | Les mêmes informations viennent du message `lobby`. | — |
| N-A15 | `ConnectionState` / `GetConnectionState` (S/OnlineService.cs:67,1068-1106) | méthode | Partiel | OC:56 `connected`, OC:49 `current_status`, `_want_open` | Partiel | Pas d'enum explicite : états déduits de `connected`, `match_id`, `current_status`. Équivalent à l'usage des écrans (lobby, salle, partie). **6d :** voir la section « Lot 6d ». | Conforme (aucun indicateur dans l'APK) |
| N-A16 | `ConnectionStates.Offline` (S/ConnectionStates.cs:5) | enum | Oui | OC:56 `connected == false` | Oui | — | — |
| N-A17 | `ConnectionStates.Connecting` | enum | Partiel | OC:155-162, OM:347 (`o.connected`) | Partiel | Pas d'indicateur "connexion en cours" dédié. L'attente se lit via `connected` et les messages d'erreur. **6d :** voir la section « Lot 6d ». | Conforme (APK sans indicateur Connecting) |
| N-A18 | `ConnectionStates.InLobby` | enum | Oui | OC:343 `watch_rooms`, SV:334 `listRooms` | Oui | Lobby public = liaison ouverte sans salle, avec push `rooms`. | — |
| N-A19 | `ConnectionStates.InRoom` (Joined et salle ouverte) | enum | Oui | OC:225 `lobby`, GR:21 `status == "open"` | Oui | — | — |
| N-A20 | `ConnectionStates.InGame` (Joined et `IsOpen == false`) | enum | Oui | GR:21 `status == "running"`, OC:272 | Oui | `CloseRoom` (`IsOpen=false`) est remplacé par le statut `running`, qui refuse les jonctions. | — |
| N-A21 | `ConnectionStates.Unknown` | enum | Non (vérifié absent : pas de cas "inconnu") | — | Oui (sans objet) | — | — |
| N-A22 | `CreateJoinRoomResults.Success` (S/CreateJoinRoomResults.cs:12) | enum | Oui | OC:332-339 (`joined`) | Oui | — | — |
| N-A23 | `CreateJoinRoomResults.NotFound` | enum | Oui | SV:355-356 (`not_found`), OM:458-460 ("This game is no longer open"), OM:679-681 ("Invalid Code") | Oui | Anti-force-brute en plus : 5 échecs par connexion = fermeture 1008 (SV:289-290), soupape globale 100/s (SV:26). | — |
| N-A24 | `CreateJoinRoomResults.RoomIsFull` | enum | Oui | SV:357-358 (`full`), OM:460,681 ("Room is full") | Oui | `full` regroupe pleine et déjà lancée, ce qui correspond à `IsOpen=false`. | — |
| N-A25 | `CreateJoinRoomResults.ExpansionsNotMatch` | enum | Non (vérifié absent : `grep -n "ExpansionsNotMatch\|expansions_not" OC SV OM` = 0) | — | Oui (sans objet) | Les extensions sont fixées par l'hôte pour toute la salle (SV:313-316) ; le client n'a plus de déblocage par achat. Store retiré : N/A. **6d :** voir la section « Lot 6d ». | Conforme (sans objet) |
| N-A26 | `CreateJoinRoomResults.FailToCreatePublic` / `FailToCreatePrivate` | enum | Oui | OM:660-663 ("Unable to create public/private room"), `bad_setup` en plus (SV:320) | Oui | Message distinct si `bad_setup` (5-6 joueurs sans Crash Landing). Le serveur renvoie `full` si 200 salles (SV:311-312), et l'UI affiche alors le message générique de création. | — |
| N-A27 | `CreateJoinRoomResults.FailToJoinPublic` / `FailToJoinPrivate` | enum | Oui | OM:457,677 ("Unable to join …") | Oui | Défaut pour toute erreur autre que `not_found` / `full`. | — |
| N-A28 | `OnlineService.CreatePrivateRoom` (S/OnlineService.cs:646) et `CreateNewRoom` (957) | méthode | Oui | SV:308-333 `create`, `_new_code` SV:292 | Oui | Code de 4 lettres sans I ni O, comme `RndWord(4)`, avec nouveau tirage si collision (SV:297). Hôte au siège 0 ; l'APK tente jusqu'à 10 fois. | — |
| N-A29 | `OnlineService.JoinPrivateRoom` (S/OnlineService.cs:661) et `JoinRoomByName` (927) | méthode | Oui | SV:349-359 `join`, OC:321 `join_lobby` | Oui | Code insensible à la casse et aux espaces (SV:354). | — |
| N-A30 | `OnlineService.JoinPublicRoom` (631) : jointure aléatoire ou création | méthode | Remplacé volontairement | SV:334-337 `listRooms`, OC:343, OM:450 | Oui (par design) | Lobbies publics listés : le joueur choisit dans `rooms`. L'auto-appariement n'est pas porté (décision utilisateur). **6d :** voir la section « Lot 6d ». | Accepté (pas d'appariement automatique : décision produit) |
| N-A31 | `OnlineService.JoinRandomRoom` (913) / `JoinAnyExistingPublicRoom` (617, WORLDWIDE) | méthode | Non, par design | — | Non, par design | Appariement automatique mondial volontairement non porté. **6d :** voir la section « Lot 6d ». | Accepté (pas d'appariement mondial : décision produit) |
| N-A32 | `OnlineService.CreateOrJoinTestRoom` ("TestRoomFor"+n, S/OnlineService.cs:651) | méthode | Non (vérifié absent : `grep -rn "TestRoomFor" src` = 0) | — | Sans objet (outil de debug APK) | — | — |
| N-A33 | `OnlineService.LeaveRoom` / `CloseRoom` (668, 678) | méthode | Oui | OC:373 `leave_match`, SV:401-412 `leave`, `_close_room` SV:186 | Oui (sémantique différente) | Hôte qui quitte la salle d'attente : `closed` envoyé aux autres (SV:405-407). Un joueur qui quitte en partie : l'IA garde le siège définitivement (GR:161) ; l'APK tue le joueur (`KillManually`, S/OnlineFlowManager.cs:307-318). Salle fermée quand plus aucun humain actif (SV:411-412). **6d :** voir la section « Lot 6d ». | Accepté (siège gardé par l'IA : décision utilisateur R-D54) |
| N-A34 | `OnlineService.GetNewRoomName` (898) | méthode | Oui | SV:292 `_new_code` | Oui | Aléa cryptographique (`Crypto`), ce qui est mieux que `RndWord`. | — |
| N-A35 | `OnlineService.CreateRoomOptions` (986) : `MaxPlayers` 4, `IsVisible`, `CheckUserOnJoin`, props lobby | méthode | Oui | SV:317, GR:35, GR:142-147 `list_entry` | Oui+ | 2 à 6 joueurs (Crash Landing). Props visibles dans la liste : `code`, `title`, `host`, `numPlayers`, `free`, `sets`, `status`. | — |
| N-A36 | `OnlineService.SavePlayerProperties` (1005) : Wins, Defeats, Avatar, IsBacker, UserName | méthode | Oui | OC:325 `_profile_fields`, SV:265 `_clean_profile` | Oui | Avatar, victoires, défaites et nom sont validés côté serveur (liste blanche `a-z_`, clamp 0 à 99999). Cosmétique, donc falsifiable : l'APK l'est aussi. | — |
| N-A37 | `OnlineService.CheckCustomProperties` (1017) | méthode | Non (vérifié absent) | — | Oui (sans objet) | Contrôle `IsOpen` / `IsVisible` / pleine remplacé par `status == "open"` et `free_seat()` (SV:357). | — |
| N-A38 | `OnlineService.GetPlayersInRoom` (754) | méthode | Oui | GR:341-346 `lobby_msg` | Oui | Tableau `seats` ordonné par siège, avec `connected`. | — |
| N-A39 | `HandlePhotonEvents` cas 255 (Join) : réinit. de `playersSequenceIndex`, `OnRoomUpdate` (S/OnlineService.cs:770-801) | méthode | Oui | SV:423-426 `_join`, GR `broadcast` GR:363 | Oui | Chaque jonction rediffuse le `lobby` à tous les sièges. | — |
| N-A40 | `HandlePhotonEvents` cas 254 (Leave) : `OnPlayerLeave` + `OnRoomUpdate` (803-830) | méthode | Partiel | OC:225, GR:156-162, GR:329-333 | Partiel | En salle d'attente : `lobby` rediffusé. **En partie, l'adversaire qui part n'a aucun signal visible** : `lobby.seats[].connected` arrive dans chaque `state` mais n'est lu par aucun écran de jeu (`grep -n "current_seats\|connected" scripts/BoardUI.gd` = 0). Le journal ne signale que le délai dépassé, pas un départ explicite (`GameRoom.leave`, GR:161, n'écrit rien). | Corrigé (Moyenne) |
| N-A41 | `OnlineFlowManager.OnPlayerLeaveGame` / `OnErrorOccurred` (S/OnlineFlowManager.cs:68-175) | événement | Non (vérifié absent) | — | Non | Aucun écran de partie n'écoute `request_error` (`grep -rn request_error scripts` : seul OM:766-797). Conséquences en partie : coupure silencieuse ; serveur redémarré (état en mémoire perdu) → `resume` rend `not_found`, `_forget()` (OC:236) vide `match_id`, `send_move` ignore tout (OC:387) : **plateau figé sans message** (hors partie perdue de toute façon). Le serveur n'envoie `closed` qu'aux sièges connectés (SV:191-193) : en partie ce message est rarement reçu, et le client ne l'affiche qu'hors partie (aucun écouteur de `closed_room` : `grep -rn closed_room scripts` = OC seul). | Corrigé (Moyenne) |
| N-A42 | `OnlinePlayerInfo` : Id, IsMasterClient, UserName, Avatar, Wins, Defeats, IsBacker (S/OnlinePlayerInfo.cs) | classe | Oui, sauf Id/IsMasterClient/IsBacker | GR:344-345, OM:31,863 (`_rows`), OC:50 `current_host` | Oui | Nom, avatar, victoires, défaites par siège ; l'hôte est un indice `host` (équivalent de IsMasterClient pour le démarrage). `IsBacker` : store retiré, N/A. **6d :** voir la section « Lot 6d ». | Conforme (Id/IsMasterClient/IsBacker sans objet) |
| N-A43 | `OnlineRoomInfo` : Name, IsPublic, Players, NumberOfPlayers, Expansions (S/OnlineRoomInfo.cs) | classe | Oui | GR:346 (`code`, `numPlayers`, `sets`, `title`), `public` en liste (SV:205) | Oui | `IsPublic` = salle présente dans `rooms`. Pas de champ `isPublic` explicite dans `lobby`. **6d :** voir la section « Lot 6d ». | Corrigé (6d) |
| N-A44 | `OnlineKeys.WINS` / `DEFEATS` / `AVATAR` / `USERNAME` (Storage/OnlineKeys.cs:7-13) | clé | Oui | OC:326 (`avatar`,`wins`,`defeats`), `name` | Oui | — | — |
| N-A45 | `OnlineKeys.ISBACKER` | clé | Non (vérifié absent : `grep -rn -i backer server scripts/OnlineClient.gd` = 0) | — | N/A | Store retiré, pas de backer. **6d :** voir la section « Lot 6d ». | Accepté (boutique retirée, pas de mécène) |
| N-A46 | `OnlineKeys.APPID` / `SERVERADDRES` / `APPVERSION` | clé | Remplacé | OC:21 `DEFAULT_URL`, OC:74 `server_url` | Partiel | **Pas de version de protocole** (`grep -rn -i "version" server/Server.gd scripts/OnlineClient.gd` = 0). L'APK isole les versions via `AppVersion` Photon. Un onglet web resté ouvert avec ancien client + nouveau serveur n'est pas détecté (champs inconnus ignorés, `bad_message` éventuel). **6d :** voir la section « Lot 6d ». | Corrigé (6d) |
| N-A47 | `OnlineKeys.ISPRIVATE` | clé | Oui | SV:323-324, GR:18 `public` | Oui | Booléen JSON strict (le texte "true" ne rend pas la salle publique). | — |
| N-A48 | `OnlineKeys.EXPANSIONS` | clé | Oui | SV:313-316,GR:15,GR:147 | Oui | Liste blanche `KNOWN_SETS` ; hôte seul décide. | — |
| N-A49 | `DBMEventCode.Unknown` (0) | enum | Non (sans objet) | SV:413-414 (`bad_message`) | Oui | Type inconnu rejeté. | — |
| N-A50 | `DBMEventCode.BeginCountDown` (1) + `BeginCountDownModel.RemainingTime` (M/BeginCountDownModel.cs) | événement/modèle | Non, par design | SV:380-385 (`start`), SV:424-425 (démarrage à salle pleine) | Partiel (par design) | L'APK diffuse un compte à rebours (pour les salles publiques). Godot : l'hôte appuie sur Start (ou démarrage immédiat à salle pleine, aucun compte à rebours). Timers d'auto-démarrage volontairement non portés. **6d :** voir la section « Lot 6d ». | Accepté (pas de compte à rebours de salle publique : décision produit) |
| N-A51 | `DBMEventCode.GameInitialization` (2) + `GameInitializationModel` (SelectedPlayers, RandomSeed, Expansions, M/GameInitializationModel.cs) | événement/modèle | Oui, remplacé | GR:173-193 `start`, GR:184-188 | Oui | Le serveur crée le `Match` (`m.rng.randomize()`), assigne `isAI` par siège ; chaque client reçoit sa vue. Le seed partagé n'existe plus (inutile avec un serveur autoritaire). | — |
| N-A52 | `DBMEventCode.BuildRoom` (3) + `BuildRoomModel` (RoomID, SlotIndex) ; `SendBuildRoom`, `SendUndoBuildRoom` (S/OnlineFlowManager.cs:451,458) | événement | Oui | OGM:115-135, `buildRoom` / `undoBuild` (PM, GR:205) | Oui | Les indices sont ceux de la main côté serveur, et les coups doivent être exactement un de `legal_moves` (GR:210-213). Le undo a une file `_queued_build` (OGM:60,74-79) qui attend l'état suivant. | — |
| N-A53 | `DBMEventCode.PlayCardAbility` (4) + `PlayCardAbilityModel` (PlayedCardID) | événement | Oui | GR:205 `submit_move`, OGM:96 `apply_move` | Oui | Coups de capacité/sort proposés dans `moves` (Match.legal_moves). | — |
| N-A54 | `DBMEventCode.SetSpellBattleReady` (5), `SendSpellBattleReady` (S/OnlineFlowManager.cs:495) | événement | Oui | GR:237 (`pass`), VF:379 (`stackPassed`) | Oui | Fenêtre de sorts : chaque humain passe ; `awaited` indique qui est attendu (GR:295-309). Le détail du `stackPassed` dans Match n'est pas relu ici. | — |
| N-A55 | `DBMEventCode.SetDiscardCards` (6) + `DiscardCardsModel` (DiscardedCardsIDs) | événement | Oui | Match.gd:207 `openingDiscard`, GR:205 | Oui | Défausse d'ouverture : coups `openingDiscard [i,j]` du `legal_moves`. | — |
| N-A56 | `DBMEventCode.ChooseDeckToDraw` (7) + `ChooseDeckToDrawModel.SelectedDeck` | événement | Oui (par coup) | GR:205 | Oui (sous réserve) | Je n'ai pas localisé le coup nominal dans `Match.gd` ; la pioche passe par `legal_moves`. Voir "Non vérifié". **6d :** voir la section « Lot 6d ». | Conforme (choix de pioche = choix en attente) |
| N-A57 | `DBMEventCode.ResolveTarget` (8) + `ResolvedTargetModel` (AbilityOwnerID, TargetID, SelectedCards) + `UnresolvedTargetData` | événement/modèle | Oui | GR:262-270 (`pendingChoice`), VF:440-445 | Oui+ | Choix en attente : options visibles du seul propriétaire (le reste devient `{"hidden":true}`, VF:444). `choiceQueue` réduite à `type` + `playerId` (VF:445). | — |
| N-A58 | `DBMEventCode.FinishUserInteraction` (20) ; `pendingFinishUserInteractions`, `IsAwaitingOtherPlayersInteractionTurns` (S/OnlineFlowManager.cs:56,320-327,364) | événement | Oui | GR:197-228, `passBuild` (Match.gd:252-254,337) | Oui | "Fin du tour de construction" = `passBuild`. Le blocage (attente de pair) devient `awaited` + délai (GR:295-316). | — |
| N-A59 | `DBMEventCode.SkipHaltTimer` (21) ; `pendingSkipHalt`, `SendSkipHalt` (S/OnlineFlowManager.cs:331-338,397) | événement | Oui | GR:258-260 `_in_adventure_pause`, GR:316, PM (pause d'aventure 10 s) | Oui | Pause d'aventure : chaque humain peut passer, sinon l'IA passe à l'échéance (10 s). | — |
| N-A60 | `DBMEventCode.SlowDown` (22) + `SlowDownModel.IsSlowDawnActive` ; `SendSlowDownModel` (S/OnlineFlowManager.cs:419) | événement | Non (vérifié absent : `grep -rn -i "slowdown\|slow_down" scripts server` = 0) | — | Oui (sans objet) | Signal d'animation entre pairs ; serveur autoritaire, plus de synchronisation d'animation à faire. **6d :** voir la section « Lot 6d ». | Conforme (remplacé par `awaited`) |
| N-A61 | `DBMEventCode.DebugDrawCard` (30) / `DebugPutHeroInTown` (31) + `DebugTBModel`, `OnlineService_OnDebugDrawCard` / `…PutHeroInTown` (S/OnlineFlowManager.cs:342,354) | événement/modèle | Non (vérifié absent : `grep -n -i "debugDraw\|cheat" scripts/Match.gd server/*.gd` = 0) | — | Oui (sans objet) | Triche de debug de l'APK : aucun client ne peut l'invoquer, tout coup doit être dans `legal_moves` (GR:210). Meilleur du point de vue sécurité. | — |
| N-A62 | `MessageBaseModel` (PhotonClientOwnerId, GameboardHash, ByBoss, M/MessageBaseModel.cs) | modèle | Remplacé | SV:392 (`seat_of(id)` dérive le siège), SV:389-391 | Oui+ | Le client ne fournit plus `ByBoss` : le siège vient de la connexion. Une trame `move` ne peut pas se faire passer pour un autre siège. | — |
| N-A63 | `GameboardHash` + `OnlineFlowManager.CheckGameboardHash` + `OnGameboardRefresh` / `OnErrorOccurred` (S/OnlineFlowManager.cs:260-273) | méthode | Remplacé | SV:394-395 (resynchro `message_for`) | Oui+ | Détection de désynchronisation inutile : l'état complet filtré est renvoyé après chaque coup, et un coup illégal est suivi d'un `state` de resynchro. Message `sync` disponible (SV:398-400). | — |
| N-A64 | `OnlineFlowManager.IsAwaitingMessages`, `CreateWaitNextStepTask`, `IsAwaitingSyncMessage` (S/OnlineFlowManager.cs:44,223,255) | méthode | Remplacé | GR:295-316 | Oui | L'attente de messages des pairs devient `awaited` + `deadline` + `serverTime` (OC:264-270). Affichage via `CountDown` (`scripts/CountDown.gd:33-36`). | — |
| N-A65 | `OnlineFlowManager.ClearPendingReveivedEvents`, `receivedSkipHalt`, `receivedFinishUserInteractions` (334-358 approx.) | méthode | Non (sans objet) | — | Oui | Plus de dédoublonnage entre pairs. | — |
| N-A66 | `OnlineFlowManager.OnlineService_OnPlayerLeave` : `KillManually`, retrait des attentes (S/OnlineFlowManager.cs:307-318) | méthode | Remplacé | GR:156-162, GR:329-333 | Oui (sémantique différente) | Plus aucune attente bloquante pour un joueur parti : sa décision tombe à l'échéance (`turnTimeout`, défaut 60 s) puis l'IA joue (GR:329-333). **Un joueur qui part laisse jusqu'à 60 s d'attente** (APK : immédiat), puis la partie continue avec l'IA, au lieu d'éliminer le joueur. **6d :** voir la section « Lot 6d ». | Conforme (départ immédiat ; coupure : reprise puis abandon) |
| N-A67 | Reprise de partie après coupure : absente de l'APK (Photon sans rejoin) | comportement | Oui (ajout) | OC:439 `try_resume`, SV:360-379, GR:94-107 | Oui+ | Jeton de siège 16 octets (GR:167), session dans `sessionStorage` (un onglet = un siège, OC:404-417), éviction de l'ancien onglet (SV:372-374, `evicted`). | — |
| N-A68 | Perte d'info cachée : mains, pioches, salles face cachée adverses | sécurité | Oui | VF:411-449, VF:453-475 | Oui | Liste blanche des clés de `G` et de joueur (VF:377,389), mains/pioches remplacées par `{"hidden":true}` à taille conservée, minibosses et objets face cachés masqués, journal privé réduit à la ligne publique pour les non-propriétaires (VF:479-486). Test automatisé dans `tests/online_test.gd:82-110,185-188`. | — |
| N-A69 | Contenu de `stack` et de `bossPicks` en phase boss visibles de tous | sécurité | Partiel (non prouvé) | VF:379 (`stack` public), VF:439 | Non vérifié | `stack` est une clé publique ; si un sort posé face cachée y figure, il serait visible. `bossPicks` est entièrement visible pendant la phase `boss` : comparaison avec l'APK non faite. **6d :** voir la section « Lot 6d ». | Conforme (prouvé, test ajouté) |
| N-A70 | Transport `Photon` UDP/TCP natif (Android) | dépendance | Remplacé | OC:60 `WebSocketPeer` | Oui | Aucune dépendance Android native côté Godot. | — |
| N-A71 | Fermeture d'onglet / mise en arrière-plan (contrainte web) | web | Partiel | OC:122 (rattrapage de veille), SV:149-150 `_drop`, SV:170-183 | Oui | Aucun `beforeunload` / `pagehide` n'envoie `leave` (`grep -rn -i "beforeunload\|pagehide\|visibilitychange" scripts server` = 0). Fermer l'onglet laisse le siège occupé : en salle d'attente libéré après 30 s (`seat-grace`), en partie l'IA reprend après le délai du tour. L'hôte d'une salle privée n'est jamais libéré (volontaire, GR:120). **6d :** voir la section « Lot 6d ». | Corrigé (6d) |
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
| N-B04 | Dernier joueur restant : « No players to play with… » ou « You win by desertion », victoire seulement si NumberOfTurns > 2, Wins++, Defeats-- (GPMO:104-118) | méthode | Non (vérifié absent) | GR:156-162 ; SV:401-412 | Différent (voulu) | Pas de règle des 2 tours côté serveur. Le siège passe à l'IA, la partie continue et se termine normalement. La salle ne se ferme que si plus aucun humain n'est actif. Grep des textes dans `godot/` : 0 résultat. **6d :** voir la section « Lot 6d ». | Conforme (modale APK, siège à l'IA) |
| N-B05 | « <nom> has left the game. » si NumberOfPlayers > 1 (GPMO:103-107) | modale | Non (vérifié absent) | — | Non | Aucun message de départ. Les autres joueurs ne savent pas qu'un siège est passé à l'IA, hormis une ligne de journal en cas de timeout (GR:332). **6d :** voir la section « Lot 6d ». | Conforme (message porté) |
| N-B06 | OnlineService_OnPlayerLeave puis KillManually (OFM:307-318 ; GameBoard.cs:855) | méthode | Oui (autre forme) | GR:156-162, 231-233 | Différent (voulu) | Le siège reste à l'IA (`left` et `auto`) au lieu d'être tué. Décision délibérée de l'utilisateur. **6d :** voir la section « Lot 6d ». | Accepté (siège à l'IA : décision utilisateur R-D54) |
| N-B07 | OnDisconnect : modale « Connection problem / The connection with the server was lost. » puis sortie (GPMO:92-95, 121-138) | modale | Non | OC:135-149 | Différent | Godot reconnecte seul avec `resume`, ce qui est mieux sur le web. Mais `request_error` n'a aucun écouteur en partie (grep : seulement OM:766-768, déconnecté au premier état OM:831). Pendant la coupure, les coups sont perdus sans message (OC:389-391). | Corrigé (Moyenne) |
| N-B08 | Perte définitive de la session en jeu (même modale puis sortie) | comportement | Non | OC:234-236 (`_forget` sur bad_token ou not_found), 239-244 (`closed`) | Non | Redémarrage du serveur, salle expirée ou siège évincé : le client oublie la session sans rien afficher. Le plateau reste figé avec un compte à rebours périmé. Seul QUIT GAME en sort. L'APK affichait une modale et quittait. | **Haute** |
| N-B09 | OnlineFlowManager_OnErrorOccurred : « Unexpected problem » (hash de plateau invalide) (GPMO:87-90 ; OFM:260-273) | modale | N/A | — | N/A | Architecture serveur autoritaire : aucun hash à comparer. Un coup illégal renvoie `error illegal` puis un `state` de resynchronisation (SV:392-395). | — |
| N-B10 | Triche debug : OnDrawRoomOrSpellToHand, OnPutHeroInTown, interrupteurs DEBUG_ELEM (GPMO:275-285 ; Base:355-375 ; OFM:342-362) | méthodes | N/A | — | N/A | Outils de debug sans équivalent. Le serveur n'accepte que des coups de `legal_moves` (GR:205-218). | — |
| N-B11 | Sortie de partie : ShowMessageBox(exit) puis Dispose appelle `onlineService.Disconnect()` (GPMO:58-68, 121-138) | méthode | Non (vérifié absent) | BUI:4344-4347 ; Main.gd:546 ; grep `leave_match` : un seul appelant (OM:793, salle d'attente) | Non | Après une partie (finie ou quittée), le client ne quitte jamais la salle et la connexion reste ouverte. `create` et `join` reçoivent alors `busy`/« deja dans une salle » (SV:309-310, 350-351). Le joueur voit « Unable to create/join private room ». Il faut recharger la page. Pour une salle finie, ça dure jusqu'à la fermeture à `finished_ttl` de 600 s (SV:176-177, 186-197). Déduit du code, non exécuté. | **Haute** |
| N-B12 | Bulle « IS PLAYING! » : IsPlayingOnlineBubbleSceneBehavior, RemotePlayerInteraction.IsPlaying, BubblesFactory.CreateIsPlayingBubble (texte `   IS\nPLAYING!`), BubblesPlayerEmitter.IsPlayingBubbleActive | comportement et bulle | Non (vérifié absent) | — (grep `IS.?PLAYING\|isPlaying` dans `godot/` : 0) | Non | **P-A48/P-B13 confirmé absent.** L'APK l'affiche pour chaque adversaire en attente de message : décision en cours, SkipHalt ou FinishUserInteraction attendu, ou zoom (SlowDown). Godot a `awaited` (OC:270) mais ne s'en sert que pour son propre compte à rebours (CD:120). On ne voit pas qui retient la partie. | Corrigé (Moyenne) |
| N-B13 | SendSlowDownModel / OnSlowDown, qui alimente IsPlaying (GPMO:287-291 ; OFM:419-427) | message | Non (vérifié absent) | — (grep `slow_down\|SlowDown` : 0 hors commentaires BUI:936) | Non | Sans bulle IS PLAYING, le message n'a plus d'usage visible. **6d :** voir la section « Lot 6d ». | Conforme (piloté par le serveur) |
| N-B14 | Barre jaune de 70 s dans le bouton DONE (Base:272 ; DoneButtonEntity.cs:98,145-148). Fin de délai : StopAndHide, FinishUserInteraction (Base:1030-1042) | entité et minuterie | Oui (autre forme) | GR:23, 311-316 ; CD:114-137 ; Main.gd:572-576 | Différent | **P-A30/P-B33 réglé.** Godot : 60 s (`--turn-timeout=60`, deploy/Dockerfile.server:33) et chiffre doré en haut à droite (1150,12), au lieu de 70 s et d'une barre jaune dans DONE. Le décompte ne s'affiche que pour MON siège attendu. **6d :** voir la section « Lot 6d ». | Conforme (70 s + barre jaune du bouton DONE) |
| N-B15 | Conséquence du délai : l'APK passe seulement son propre tour de construction (auto-DONE). Aucun délai sur les autres décisions | comportement | Oui (différent) | GR:329-334 (`auto = true`), 231-233, 263-292 ; PROTOCOL.md:292-294 | Non | Au timeout (60 s, ou 10 s pour une pause d'aventure, GR:316), l'IA joue à la place du joueur pour toutes ses décisions suivantes, et immédiatement. Seul un coup du joueur remet `auto` à faux (GR:215). Quelques secondes d'hésitation pendant une pause d'aventure peuvent donc coûter le tour de construction suivant, joué par l'IA. À valider avec le propriétaire. | **Haute** |
| N-B16 | Remise à zéro du délai : l'APK ne remet la barre à zéro que quand une capacité se résout en BuildPhase_b (Base:621-624) et la met en pause pendant un combat de sorts (Base:655-657) | comportement | Oui (différent) | GR:220-227 (`_after_move` puis `_reset_deadline`), 104-105 (`resume` remet un délai complet) ; Match.gd:416-425 | Non | Tout coup valide remet le délai à 60 s. Alterner `buildRoom` et `undoBuild` (toujours légal avant DONE) bloque la partie indéfiniment. Un `resume` d'un autre siège repousse aussi l'échéance d'un joueur absent. Un joueur peut bloquer les autres pour toujours. | **Haute** |
| N-B17 | GamePlayBaseScene.TimeOut = 60 s (Base:131-140) | propriété | N/A | — | N/A | Jamais lue (grep -w `TimeOut` : seule la définition, hors WRB). Pas de « 60 s » dans GamePlayMOScene (P-A55) : les 60 s d'`activateTimeOuts` sont du code mort. | — |
| N-B18 | Fenêtres d'aventure et de pile en ligne : barre de 3 s par pas du héros (Base:215, 944), SkipHalt automatique (OFM:227-231, 397-408) | comportement | Oui (différent) | BUI:922-927 (`_apk_flow` faux en ligne), 1020-1030 ; GR:258-260 | Différent | En ligne, Godot demande un GO ou PASS TURN manuel à chaque pas quand le joueur a une décision. L'APK avance seul après 3 s. La pause d'aventure serveur est de 10 s (N-B15 pour la suite). | Corrigé (Moyenne) |
| N-B19 | Pause en ligne : le jeu ne se fige pas (PauseScene.PauseBaseScene = !activateTimeOuts, Base:1095-1096) | comportement | Oui | BUI:874 (`_modal_open() and not _is_online()`) | Oui | Le serveur continue d'écouler le délai pendant le menu. | — |
| N-B20 | CARD GALLERY masquée en ligne (`new PauseScene(!activateTimeOuts)`, Base:1095 ; PauseScene.cs:28-31,61) | bouton | Oui (à tort) | InGameMenu.gd:180, 243-252 | Non | **P-A15 confirmé** : la galerie est toujours proposée en ligne (InGameMenu n'a aucun indicateur en ligne). RULES est aussi proposé, c'est un ajout. **6d :** voir la section « Lot 6d ». | Conforme (galerie masquée en ligne, test ajouté) |
| N-B21 | Vitesse de jeu forcée à 0,5 en ligne (GameSettings) | comportement | Oui | BUI:944-946 | Oui | Alias verbal : déjà audité ailleurs. | — |
| N-B22 | Choix du boss avec minuterie en ligne : useTimeoutInBossSelection, pas de bouton PLAY, fermeture après 2 s (Base:98 ; RandomBossSelectionScene.cs:81,137) | comportement | Oui | BUI:1204, 1907-1925 (`BOSS_AUTO_TIME`) | Oui | Le bouton n'apparaît que s'il y a un seul humain. Durée exacte de `BOSS_AUTO_TIME` non confrontée aux 2 s. | — |
| N-B23 | IsOtherUserInteractionActive : interactions verrouillées pendant le tour d'un autre (GPMO:72 ; Base:116-124) | propriété | Oui (autre forme) | OnlineGameManager.gd:43-46 | Oui | Le client n'a pas de coups légaux hors de son tour : verrouillage par construction. | — |
| N-B24 | ShowAbilityApplyRequestBubble : bulle « HAS PLAYED A SPELL / ROOM ABILITY » pour les coups des joueurs distants (GPMO:247-253) | bulle | Non | BUI:903 (unique appel de `_notice_ai`) | Non | La bulle n'est déclenchée que par la boucle IA locale. En ligne `legal_moves` d'un autre siège est vide (OnlineGameManager.gd:43-46), donc ni humains distants ni IA serveur n'en génèrent. Déduit du code, à confirmer en exécution. | Corrigé (Moyenne) |
| N-B25 | MenuOnlineScene : WORLDWIDE / WITH FRIENDS / CHANGE USER/AVATAR (MO:39-75) | scène | Oui | OM:242-246 | Oui | Disposition déjà auditée ailleurs. | — |
| N-B26 | MenuOnlineScene : Connect() à l'entrée, Disconnect() au retour (MO:34, 86-90) | méthode | Oui (autre forme) | OC:343-357 ; OM:243 | Oui | La connexion est paresseuse (au premier appel utile). Contrainte web : aucune connexion Photon préalable. | — |
| N-B27 | WORLDWIDE : ExpansionScene puis JoinPublicRoom (appariement auto), sinon « NETWORK ERROR / Unable to join public rooms » (MO:43-54 ; OS:631-644) | flux | Non (voulu) | OM:252-302 (liste des salons publics, hors APK) | Différent (voulu) | Pas d'appariement automatique : décision utilisateur. **6d :** voir la section « Lot 6d ». | Accepté (pas d'appariement automatique : décision produit) |
| N-B28 | WITH FRIENDS / NEW GAME : ExpansionScene puis CreatePrivateRoom ; échec : « Unable to create private room » (WFO:68-82 ; ExpansionScene.cs:146-157 ; OS:646) | flux | Oui | OM:626-629, 646-663 | Oui | Variantes ajoutées : salon public, INVALID SETUP pour 5-6 joueurs. | — |
| N-B29 | ROOM CODE : champ en fondu, OK, JoinPrivateRoom, succès vers WaitingPrivateRoom (WFO:49-62, 94-106) | flux | Oui | OM:608-630, 665-682 | Oui | Code de 4 lettres majuscules, « Invalid Code » si la longueur n'est pas 4. | — |
| N-B30 | Textes d'erreur ShowOnlineMessageBox (DBMBaseScene.cs:69-83) | modales | Oui (partiel) | OM:457-461, 663, 678-682, 807 | Différent | Présents : Invalid Code, Room is full, Unable to create/join private room, Unable to create public room. Écarts : « Unable to join public game » au lieu de « …room ». Pas de « Unexpected Error <n> ». Pas de « Expansions not match » (N-B31). **6d :** voir la section « Lot 6d ». | Conforme (textes de CreateJoinRoomResults) |
| N-B31 | ExpansionsNotMatch : refus si le joiner n'a pas les extensions de la salle (OS:1017-1056) | contrôle | N/A | — | N/A | Boutique retirée : le serveur accepte tout joueur, les paquets sont ceux de l'hôte. | — |
| N-B32 | WaitingRoomBaseScene.OnDisconnect : « NETWORK ERROR / Unable to join public room » avec 3 pops (WRB:54-61) | modale | Oui (partiel) | OM:802-810 | Différent | `_on_waiting_error` ignore « reconnexion » : sur panne durable il n'y a aucun message, le client retente à l'infini. La flèche de retour reste disponible. **6d :** voir la section « Lot 6d ». | Corrigé (6d) |
| N-B33 | Salle morte : playersInRoom == 0 donne « NETWORK ERROR » puis Pop (WPR:132-136) | modale | Oui (avec bug) | OM:806-810 ; OC:239-244 | Différent | Le client émet `request_error` AVANT `_forget()`. `room_gone` (`match_id == ""`) est donc faux au moment du test. Le message devient « Unable to join private room », le OK ne fait rien et le joueur reste sur l'écran mort jusqu'à la flèche. Le texte « Room closed » n'apparaît jamais. | Corrigé (Moyenne) |
| N-B34 | NavigatedBack : LeaveRoom puis Pop (WRB:149-154). Photon fait migrer le maître quand il part | flux | Oui | OM:788-800 ; SV:401-407 | Différent (voulu) | Quand l'hôte quitte une salle ouverte, la salle ferme pour tout le monde (aussi pour une publique). L'APK la gardait. Pas de bannissement dans l'APK ni dans Godot. **6d :** voir la section « Lot 6d ». | Conforme (migration de l'hôte) |
| N-B35 | Panneau des joueurs : OnlinePanelEntity.UpdatePanel et OnlinePlayerInfoEntity.Refresh (nom tronqué à 25, avatar, WINS et DEFEATS, « WAITING... ») (OPE:78-98) | scène | Oui | OM:836-879 | Oui | Titre « WAITING FRIENDS... » présent (OM:727). WINS et DEFEATS viennent du profil envoyé au join (OC:325-326). | — |
| N-B36 | Nom en or pour IsBacker (OnlinePlayerInfoEntity.cs:55-63) | affichage | Oui (autre sens) | OM:853 | Différent (voulu) | Godot colore l'hôte en or. Pas de statut backer (boutique retirée). **6d :** voir la section « Lot 6d ». | Accepté (pas de mécène : boutique retirée) |
| N-B37 | OK de la salle privée : maître seulement et playersInRoom > 1 (WPrR:41-62) | contrôle | Oui | OM:872-879 | Oui | Condition `humans > 1`. START WITH BOTS (ajout) lance avec des IA. | — |
| N-B38 | SendGameInitialization : CloseRoom, graine, répartition des bosses, GoToGamePlay si plus d'un joueur (WRB:107-145) | méthode | Oui (autre forme) | GR:173-193 ; SV:380-385 | Oui | La salle passe à `running` et refuse les arrivées (SV:357-358). La graine est tirée par le serveur. L'origine de `forcedBoss` n'est pas auditée ici. | — |
| N-B39 | Démarrage : l'APK exige OK du maître (2 à 4 joueurs). Godot démarre dès que la salle est pleine | flux | Oui (différent) | SV:424-425 ; GR:173 | Différent (voulu) | La taille (2-6) est fixée à la création. Un salon plein démarre seul, l'hôte peut lancer avant. **6d :** voir la section « Lot 6d ». | Corrigé (6c) |
| N-B40 | Salle publique : titre « SEARCHING PLAYERS... », CountDownBehavior 45 s, compte à rebours 10 s à 4 joueurs, BeginCountDown, GlobalWaiting 60-120 s avec nouvelle recherche (WPR:27-143) | scène | Non (voulu) | — | Différent (voulu) | Décision utilisateur : salons et liste uniquement. **6d :** voir la section « Lot 6d ». | Accepté (pas de salle publique à appariement : décision produit) |
| N-B41 | `ui_timer` en salle d'attente publique, chaque seconde sous 5 s (WPR:102-105 ; WRB:35) | son | Non | — (grep : seul appel CD:49) | Différent | **A-28 réglé.** Absent de la salle d'attente (cohérent avec N-B40). Il est rejoué par Godot dans le décompte de tour en partie, ce que l'APK ne fait jamais : ajout. **6d :** voir la section « Lot 6d ». | Accepté (pas de compte à rebours de salle publique : décision produit) |
| N-B42 | CountDownEntity (chiffres or ×3, ombre +3 px, sablier (30,-8), fondu 0,3 s) et CountDownBehavior (CDE:41-81) | entité | Oui (réutilisé) | CD:93-137 | Oui (visuel) | **P-C18/A-28.** Même habillage, mais utilisé comme minuteur de tour en partie (position (1150,12)) et non en salle d'attente (APK (1120,960)). `CountDownBehavior` n'existe pas : le décompte lit `turnDeadline` du serveur (CD:117-124). **6d :** voir la section « Lot 6d ». | Accepté (pas de compte à rebours de salle d'attente : décision produit) |
| N-B43 | RoomCodeEntity : « ROOM CODE: » avec le code en or (RoomCodeEntity.cs) | entité | Oui | OM:749-753 | Oui | — | — |
| N-B44 | TextEntryEntity : focus, placeholder, MaxLength, HideSoftKeys (TEE:77-147) | entité | Oui (autre forme) | OM:128-154 | Oui | Le clavier virtuel Android (CustomService.HideSoftKeys) est sans objet sur le web de bureau. | — |
| N-B45 | ChangeNameAvatarScene : valeurs par défaut `player_xxxx` et avatar au hasard, nom vide non enregistré, Truncate(45), pas de retour au premier passage (CNA:37-46, 101-111) | scène | Oui | OM:568-588 ; Profile.gd:16, 37-43 | Oui | Le serveur borne le nom à 25 (SV:241-243), comme l'affichage APK. | — |
| N-B46 | OnlineService.Update : reconnexion toutes les 4 s (`maintainConnected`) (OS:555-565) | méthode | Oui (amélioré) | OC:97-153 | Oui | Reprise avec `resume` et jeton de siège. | — |
| N-B47 | Pas d'IA dans les parties en ligne de l'APK | règle | Non (ajout voulu) | GR:51-57, 172-180 ; OM:760 | Différent (voulu) | Les sièges vides deviennent des IA (START WITH BOTS). | — |
| N-B48 | Expulsion d'un joueur (kick) | fonction | N/A | — | N/A | Absente de l'APK (aucune occurrence dans les scènes en ligne) et de Godot. | — |
| N-B49 | Fermeture de l'onglet / de l'application en pleine partie | contrainte web | Oui (autre forme) | GR:109-116, 329-334 ; SV:162-167 | Différent (voulu) | La connexion est détachée mais le siège reste. L'IA reprend à l'échéance du délai, avec les conséquences de N-B15. Aucun message pour les autres. **6d :** voir la section « Lot 6d ». | Corrigé (6d) |
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
| D-08 | `FullScreen = true` et `HideSoftKeys()` (barres système immersives, `AndroidCustomService.cs`, `SystemUiVisibility |= 1,2,0x800,0x1000`) | Méthode | Non (vérifié absent) | grep `fullscreen\|FULLSCREEN\|window_set_mode` dans `scripts/` : 0 résultat | Non | Pas de bouton plein écran. F11 reste possible dans le navigateur. **6e :** voir la section « Lot 6e ». | Accepté (6e) |
| D-09 | `Window.AddFlags(KeepScreenOn)` (`AndroidActivity.cs:52`) | Appel natif (wake lock) | Non (vérifié absent) | grep `keep_screen_on\|screen_set_keep_on\|wakeLock` : 0 résultat | Non | Pas de verrou d'écran. Sans importance en bureau à la souris : une partie contre l'IA demande des clics. **6e :** voir la section « Lot 6e ». | Corrigé (6e) |
| D-10 | `OnKeyDown(Keycode.Back)` appelle `NavigatedBack()` sur toutes les scènes (`AndroidActivity.cs:65-83`) | Méthode, bouton retour | Partiel | Flèche retour à l'écran (`Main.gd:213-226`, `back_bt.webp`), menu engrenage en jeu (`BoardUI.gd:4301-4340`) | Oui (par bouton) | Aucune touche Échap ou Retour gérée : grep `KEY_ESCAPE\|ui_cancel\|KEY_BACK\|_unhandled_key` dans `scripts/` : 0 résultat. Aucun besoin de capter le bouton Retour du navigateur. **6e :** voir la section « Lot 6e ». | Conforme (6e) |
| D-11 | `LoadingScene.NavigatedBack` appelle `Platform.Exit()` (`LoadingScene.cs:64-67`) ; `QuitGameScene` appelle `Platform.Exit()` (`QuitGameScene.cs:31`) | Méthode, quitter l'application | Partiel | Quitter la partie : `BoardUI.gd:4339-4340`, puis `Main.gd:546` (retour titre) | Oui (N/A web) | Pas de « quitter l'appli » dans un onglet. La confirmation « Quit to menu ? » en partie est portée. Depuis le menu principal, la flèche mène à l'écran titre (`Main.gd:276`) comme dans l'APK (`MainMenuScene.cs:199`). Aucun appel à `get_tree().quit()` : grep `\.quit(` : 0 résultat. | — |
| D-12 | `OnPause` appelle `game.OnDeactivated()` (`AndroidActivity.cs:~96-102`) | Cycle de vie | Partiel | Seul `NOTIFICATION_APPLICATION_FOCUS_OUT` géré : `BoardUI.gd:3562` (abandon d'un appui de glisser) | Non vérifié | Aucune pause générale ni coupure audio à la perte de focus ou au masquage de l'onglet : grep `visibilitychange\|NOTIFICATION_APPLICATION_PAUSED\|get_tree().paused` : 0 résultat. Un onglet masqué gèle `requestAnimationFrame`, donc la logique pilotée par `delta` s'arrête. La coupure du son et le clamp du delta au retour ne sont pas prouvés. **6e :** voir la section « Lot 6e ». | Conforme (6e) |
| D-13 | `OnResume` appelle `game.OnActivated()` (`AndroidActivity.cs:~106-115`) | Cycle de vie | Partiel | Comme D-12 | Non vérifié | Au retour sur l'onglet, l'APK reprend le Wave loop. Le port repart sur un `delta` potentiellement grand (garde-fou côté réseau seulement : `OnlineClient.gd:122`, `SLEEP_GAP_S`). **6e :** voir la section « Lot 6e ». | Conforme (6e) |
| D-14 | `Game.OnlineSuspend` donne `OnlineClient.IsSuspended` ; déconnexion après `MaxSuspendedTime` = 30 s (`Game.cs:~80-85`, `OnlineClient.cs:43-45,145-160`) | Méthode, suspension réseau | Oui | `OnlineClient.gd:26-33,115-134` (ping 20 s, reprise après trou > 5 s, pong 8 s) ; reprise par jeton `OnlineClient.gd:104-106,403-426` ; `server/Server.gd:30-45` (inactivité 120 s, grâce de siège 30 s) ; `server/GameRoom.gd:313-331` (IA prend le relais) | Oui (supérieur) | Pas de déconnexion volontaire à 30 s : la liaison'est rouverte avec le jeton de siège. Renvoi module 9. | — |
| D-15 | `OnWindowFocusChanged` appelle `HideSoftKeys()` (`AndroidActivity.cs:~90-94`) | Méthode | Non (N/A) | — | N/A | Barres système Android seulement. | — |
| D-16 | `CustomService` (service de base) et `AndroidCustomService` (`DBMGameProject.Interfaces/CustomService.cs`) | Classe, service plateforme | Non (N/A) | — | N/A | `HideSoftKeys` et `IsFullScreenActive` sont sans objet sur le web. | — |
| D-17 | `TextEntryEntity.LostFocus` programme `HideSoftKeys` après 0,2 s (`TextEntryEntity.cs:~118-130`) | Méthode, clavier virtuel | Partiel | `OnlineMenus.gd:128-165` (LineEdit, perte de focus au clic hors champ) ; `export_presets.cfg` : `html/experimental_virtual_keyboard=false` | Oui (bureau) | Bureau : clavier physique, rien à masquer. Mobile : clavier virtuel désactivé, donc la saisie du code de salle ou du pseudo sur tactile est probablement impossible. Cible souris : lacune tactile. **6e :** voir la section « Lot 6e ». | Accepté (6e) |
| D-18 | `Insights.Initialize` avec `XAMARIN_INSIGHTS_KEY` et `ForceDataTransmission` (`Game.cs:~20`, `AndroidActivity.cs:39-40`) | Analytique Xamarin | Non (absent par conception) | grep `insights\|analytic\|telemetr\|sentry\|crashlytics\|ubertest` dans `scripts/` : 0 résultat ; aucun `HTTPRequest` ni `HTTPClient` | Oui | Aucune télémétrie dans le port. La clé figure en clair dans l'APK. | — |
| D-19 | `AndroidEnvironment.UnhandledExceptionRaiser` appelle `LogService.LogException` puis `Insights.Report` (`AndroidActivity.cs:41-44`, `LogService.cs:~42-50`) | Rapport de crash | Non (vérifié absent) | Seuls `push_error` : `CardDB.gd:44`, `Match.gd:130` (console du navigateur) | Non | Pas de remontée d'erreurs. L'absence est cohérente avec D-18. **6e :** voir la section « Lot 6e ». | Accepté (6e) |
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
| D-44 | `KeyboardState` : flèches gauche et droite du carrousel (`CarrouselDragBehavior.cs:74-84`) | Entrée clavier | Partiel | `RulesViewer.gd:117-119` ; `CardGallery.gd` : aucun `KEY_LEFT` (grep) | Non vérifié | Le carrousel (`CardCarrouselEntity`) n'a pas de flèches clavier dans le port. Pas de pertinence en jeu à la souris. **6e :** voir la section « Lot 6e ». | Corrigé (6e) |
| D-45 | Moteurs physiques `WaveEngineAndroid.Bepu` et `.Farseer` | Bibliothèques | Non (N/A) | — | N/A | Inutilisés par DBMGame : grep `Farseer\|Bepu\|RigidBody` : 0 résultat. Les 111 `RectangleCollider` et le `Framework.Physics2D` ne servent qu'au test de touche (Controls Godot). | — |
| D-46 | `Zlib.Portable`, `System.Json` | Bibliothèques | Non (N/A) | — | N/A | Aucun usage dans DBMGame : grep `Zlib\|System.Json\|GZip\|Deflate` : 0 résultat. | — |
| D-47 | `Newtonsoft.Json` (7 fichiers : `CardInfoService`, `CreditsScene`, `OnlineService`, `OnlineClient`, `AppPurchaseService`, `GameBoardFlowInfo`, `InternalJsonContractResolver`) | Sérialisation | Oui | Cartes : `CardDB.gd` ; réseau : `NetCodec.gd` ; réglages : `ConfigFile` (`Profile.gd`) | Oui | Les sauvegardes passent par `WaveServices.Storage` + `StorageHelper` (retries x8) : module 1. | — |
| D-48 | Ouvrir une URL, partager, noter, réseaux sociaux (`Intent`, `Launcher`, `Share`) | Appel natif | Non (absent des deux côtés) | `OS.shell_open` : grep dans `scripts/` : 0 résultat ; `CreditsScreen.gd` sans URL | N/A | Côté APK, grep `https?://` dans DBMGame hors modèle : seulement `ValidationURL` et l'hôte Photon ; aucun `Intent` ni `Launcher`. Les crédits APK ne contiennent aucun lien. | — |
| D-49 | Vibration, notifications, permissions à l'exécution | Appel natif | Non (absent des deux côtés) | grep `vibrat\|Handheld\|notif` : seulement des bulles de jeu | N/A | grep `Vibrat\|Notification` dans DBMGame : 0 résultat. | — |
| D-50 | `Resource.cs` (identifiants R Android), `LayoutId = 2130903040` | Classe générée | Non (N/A) | — | N/A | | — |
| D-51 | Ajouts web du port : `JavaScriptBridge` (origine, `sessionStorage`), shim `isSecureContext` et `AudioWorklet` dans `head_include` | Spécifique web | Oui | `Main.gd:71-75`, `OnlineClient.gd:403-426`, `export_presets.cfg` (`html/head_include`, `thread_support=false`) | Oui | Le shim force `window.isSecureContext = true` et stubbe `audioWorklet` pour le HTTP clair sur ZimaOS. À garder en tête hors du homelab. **6e :** voir la section « Lot 6e ». | Conforme (6e) |

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
| G-07 | BMH056 : `Description` vide dans `HiddenHeros/data.json:19-30`, texte imprimé sur l'image | Texte de carte | Oui, texte faux | `godot/data/cards.json:4036-4053` | Non (texte) | `description` = "Nick the Masher..." (texte de BMA056) alors que l'image dit "Everel the Healer". Mon script Python sur `cards.json` : 41 héros hidden-heroes sur 41 reprennent mot pour mot le texte du BMA remplacé. R-F76 est confirmé et étendu : non limité à BMH056. Correction de R-F76 : AUDIT.md dit "Affiché en infobulle (`CardData.gd:52`)". `description_text` n'est que lu à `CardData.gd:52` et déclaré à `:17`, aucun autre lecteur. Les `.get("description")` de `BoardUI.gd:1666` et `:3961` ne portent que sur les salles. Le texte faux n'est donc affiché nulle part et la carte est affichée via l'image correcte. Risque seulement si une infobulle ou une galerie texte est ajoutée. Corriger ou vider ces 41 champs. | Corrigé (Basse) |
| G-08 | `PlayerChoice/Assets/ksa001-ksa017.wpk`, `dungeonbg_ksa*`, `boss_profile`, `hero_characters` | Atlas de cartes | Oui | GA/apk_cards/playerchoice/ (11 webp : ksa001-007, 013, 014, 016, 017), GA/ui/characters/ksa*, GA/ui/dungeon | Oui | 11 images pour 11 cartes (7 boss, 1 sort, 3 héros) dans `data.json`. Les ids manquants dans la plage ksa001-017 n'existent pas dans les données. | — |
| G-09 | `ToolsHeroKind/Assets/back_item-thk019.wpk`, `thk020-025.wpk` | Atlas de cartes | Oui | GA/apk_cards/tools/ (back_item, thk001 à thk025, plus thk025a) | Oui | 25 cartes thk et 1 dos. `thk025a` n'a pas de source APK : c'est un ajout (alt-art), à confirmer. | — |
| G-10 | `Common/AVATAR.wpk` | Atlas UI | Oui | GA/ui/avatar/ (19 webp) | Oui | `assets_full_coverage.md` : extrait. Contenu de l'atlas non recompté ici. | — |
| G-11 | `Common/GRADIENTS.wpk`, `INGAME.wpk`, `NAVIGATION.wpk`, `TUTORIAL.wpk` | Atlas UI | Oui | GA/ui/gradients (15), GA/ui/ingame (108), GA/ui/navigation (29), GA/ui/tutorial (20) | Oui | Extraits par `tools/extract_apk_226.py`, sprites individuels en webp. Comptage par sprite non refait (voir Non vérifié). | — |
| G-12 | `Common/gallery_bg`, `intro_bg`, `menu_bg`, `multiplayer_bg`, `particle_01.wpk` | Sprites | Oui | GA/ui/backgrounds/*.webp, GA/ui/particle_01.webp | Oui | Les 5 fonds et la particule sont présents. | — |
| G-13 | `Common/credits.json` | Données | Oui | GA/data/credits.json | Oui | `cmp` : identique à la source. | — |
| G-14 | `EXPANSIONS.wpk` | Atlas UI | Oui | GA/ui/expansions/ (21 webp) | Oui | Présent. Écran Expansions : voir G-34 (magasin retiré par décision de portée). | — |
| G-15 | `Fonts/arcadepix.wpk`, `arcadepix2.wpk`, `bookman_old_style.wpk` | SpriteFonts | Oui | GA/fonts/arcadepix.fnt (+_bm.png), arcadepix2.fnt, bookman_old_style.fnt | Oui | BMFont, utilisé par `UiKit.gd:5-6` (FONT_A, FONT_B). Le rendu bitmap garde le pixel-art. | — |
| G-16 | `Fonts/f04b03.wpk` (16 459 octets) | SpriteFont | Non (vérifié absent) | — (`find src apk-original -iname "*f04b03*"` : seuls des caches `.godot/` périmés) | N/A | `ControlsFactory.Create04b03TB` (`ControlsFactory.cs:54-58`) n'a aucun appelant dans DEC (grep : seule sa définition). Police du code mort, `assets_full_coverage.md` la déclare "MANQUANT". Les "ui/characters" ne la référencent pas. | — |
| G-17 | `Loading/LOADING_SCREEN.wpk` : sprite `loading` ("LOADING..." animé) | Atlas | Partiel | GA/ui/loading/loading.webp (importé, jamais lu) | Non | `grep -rn "ui/loading\|loading.webp"` sur scripts et scènes : aucun résultat. `LoadingScene.cs:30-32` pose ce sprite en (830, 0.8 x H) avec `RupisLoadingBehavior` (3 points, 0,5 s, `LoadingScene.cs:34-39`). Absent en Godot. Le chargement web est celui du moteur. | Accepté (Basse) |
| G-18 | `Loading/loading_bg.wpk` | Sprite | Oui | GA/ui/backgrounds/loading_bg.png, `src/frontend/project.godot:12` (`boot_splash/image`) | Partiel | Fond en boot splash. L'écran applicatif `LoadingScene` (fond puis fondu noir vers Intro, `LoadingScene.cs:48-58`) n'existe pas en Godot ; `Main.gd` démarre directement. | Accepté (Basse) |
| G-19 | `NinePatch/avatars_bg`, `bg_levelup_banner`, `code_area_act`, `code_area_inact`, `progress_green`, `searching_bg` | Ninepatch | Oui | GA/ui/ninepatch/ (6 webp) | Oui | Utilisés : `BoardUI.gd:1323` (levelup, marges 15/17/15/15), `OnlineMenus.gd:129,578,705,749,777`, `TimeBar.gd:7`. Rendu par `UiKit.ninepatch` (NinePatchRect). | — |
| G-20 | `NinePatch/progress_yellow.wpk` | Ninepatch | Non (vérifié absent) | — (`find` : introuvable ; GA/ui/ninepatch ne contient que 6 fichiers) | Non | Barre jaune de 177 px sous le bouton DONE (5 s) : `DoneButtonEntity.cs:98` crée `new ProgressBarEntity(..., 177f, 5 s, ..., NinePatchs.InGame.progress_yellow)`, instancié à `GamePlayBaseScene.cs:252`. Elle se vide en 5 s puis `StopAndHideButton` (`:145-148`). `grep progress_yellow` dans GS : aucun résultat. Le comportement associé (pulsation, minuteur de 5 s) est déjà noté absent en P-C51 (AUDIT.md:1095). | Corrigé (Moyenne) |
| G-21 | `NinePatch/settings_text_bg.wpk` | Ninepatch | Non (vérifié absent) | — | Partiel | `SettingButtonDecorator.cs:71` l'utilise, 3 lignes dans `SettingsScene.cs:70-92`. `Main.gd:663-680` (`_toggle_row`) dessine un aplat à la place. Déjà noté U-A56 (AUDIT.md:244, Basse). | Accepté (Basse) |
| G-22 | `NinePatch/settings_slider_bg.wpk` | Ninepatch | Non (vérifié absent) | — | N/A | `SettingsSliderControl.cs:41` : aucun appelant (`new SettingsSliderControl` introuvable dans DEC). Code mort, déjà noté I-16 (AUDIT.md:152). | — |
| G-23 | `Tutorial/kingcroak_anim.wpk` et `kingcroak_anim.xml` | Atlas animé | Oui | GA/ui/tutorial/kingcroak_anim.webp et `.xml`, `TutorialOverlay.gd:52-56,895-902` | Oui | 7 images de 63 x 62 en AtlasTexture, 8 images/s, boucle. `texture_filter = NEAREST` (`:902`), fidèle à PointClamp (`TutorialIntroScene.cs`). | — |
| G-24 | `Tutorial/mascara_00.wpk`, `mascara_black.wpk` | Sprites | Oui | GA/ui/tutorial/mascara_00.webp, mascara_black.webp | Oui | Présents. | — |
| G-25 | `Tutorial/mascara_01.wpk` (65 670 octets) | Sprite | Non (vérifié absent) | — (`find` : seul un cache `.godot/imported` périmé) | N/A | Uniquement dans l'enum `Sprites.cs:33`. `grep -rn "mascara_01"` dans DEC ne donne que cette déclaration : jamais chargé. Code mort. | — |
| G-26 | `DBMGame.CardEffectpsTexture.frag` et `.vert` : niveau de gris `0.3 R + 0.55 G + 0.15 B`, `mix(gris, couleur, Amount)`, `x outColor` ; `CardMaterial` (`.Amount`), `ColorFadeBehavior.cs:56` | Shader GLSL | Oui (inline) | `CardUI.gd:57-63` (shader `amt`, poids 0.3/0.59/0.11, facteur 0,62) ; `Main.gd:435-441` (`_gray_mat`, facteur 0,65) | Oui, approchant | Aucun fichier `.gdshader` (`find` : zéro), deux chaînes `shader_type canvas_item` dans GS. `amt` interpolé en 0,5 s (`CardUI.gd:45-70`, fondu 0,5 s, `BoardUI.gd:1743`). Écarts voulus : poids 0,59/0,11 au lieu de 0,55/0,15 et assombrissement x0,62 que le source n'a pas (réglage sur captures, non vérifié). Compatible WebGL2 / GL Compatibility. | Accepté (Basse) |
| G-27 | `DungeonAdditiveLayer` = `DefaultLayers.Additive` (`CustomLayers.cs:16`), `AdditiveLayer` (`DBMBaseScene.cs:88`), halo additif du boss (`DungeonFrameEntity.cs:54-78,280-290,530-572`) | Mode de fusion | Oui | `BoardUI.gd:2492` (`CanvasItemMaterial.BLEND_MODE_ADD`), GA/ui/characters/*_glow.webp | Oui | Le glow est dans l'atlas `hero_characters` et `_character_glow` (webp présents). Les autres couches Additive de l'APK sont un seul `RegisterLayer`. | — |
| G-28 | `DBMGameProject.Common.Layers` (9 classes : Carousel, Dungeon{Top,Bottom}Scissor, SidePanel, SpellBattle, TimeBar, TopCards, VirtualScreenAlphaScissor, CustomLayers) | Couches et ordre de dessin | Oui, par équivalent | `z_index`/ordre des enfants dans `BoardUI.gd` (ex. `:1294` découpe au couloir) | Non vérifié en détail | Le détail de chaque couche (scissor, draw order) relève du module 7 et n'a pas été recontrôlé ici. Godot n'a pas de couches nommées ; c'est l'ordre des nœuds et `clip_contents`. | — |
| G-29 | `ParticlesFactory.CreateBackParticles` et `ParticleSystemRenderer2D` | Système de particules | Oui | `ApkParticles.gd` (CPUParticles2D, 133 particules, vie 1,5-3 s, coté 4-24 px, texture `particle_01.webp` 19 x 19) | Oui | Portage détaillé (constantes tracées au source). CPU volontairement, pas de GPUParticles en export web sans threads. | — |
| G-30 | Résolution virtuelle `VIEWPORT_WIDTH = 1440` (`DBMGameProject/Game.cs:26`) | Écran virtuel | Oui | `src/frontend/project.godot:23-27` : 1920 x 1080, `canvas_items`, `keep_aspect` ; `CreditsScreen.gd:5,16` (`DX = 240`) | Oui | Convention x_godot = x_apk + 240 acceptée. Le décalage est appliqué partout où je l'ai vu (`CreditsScreen.gd`, `UiKit`). | — |
| G-31 | `AddressMode.PointClamp` (25 occurrences : `ControlsFactory`, `LoadingScene`, `LevelUpBanner`, `ProgressBarEntity`, `GalleryScene`, `PurchaseScene`, `OnlineAvatarComponent`, `Soul/Wound/RupisLoading`, scènes Tutorial) contre `LinearClamp` (`CardMaterial.cs:175`) | Filtrage de texture | Partiel | `project.godot` : pas de `default_texture_filter` (filtre linéaire par défaut) ; `TutorialOverlay.gd:902,1019,1049` met `TEXTURE_FILTER_NEAREST` ; mipmaps désactivés (`*.webp.import: mipmaps/generate=false`) | Partiel | Le source utilise PointClamp pour ses sprites UI et LinearClamp pour les cartes. Godot garde le linéaire par défaut hors tutoriel. À 1080p tout est à l'échelle 1:1, donc invisible. En fenêtre redimensionnée, `canvas_items` agrandit en linéaire (léger flou, jamais de pixels nets). Compression sans mipmaps : conforme à l'APK. | Accepté (Basse) |
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
| W-01 | `LoadingScene.CreateScene` (`DBMGameProject.Scenes.MainMenu/LoadingScene.cs:20-40`) : fond `loading_bg`, sprite d'atlas `Atlas.Loading.loading`, `RupisLoadingBehavior(3, 0.5 s)`. `Game.cs:56` y envoie dès le démarrage. | scène | Partiel | `project.godot` (`boot_splash/image=loading_bg.png`, `fullsize`, `bg_color`) | Partiel | Le fond est repris comme boot splash Godot. Le splash Godot web se montre pendant le chargement du .wasm et du .pck, puis rien de plus : la barre de progression HTML par défaut du shell s'affiche, et l'animation Rupis (3 points) n'existe pas pendant le chargement. **6e :** voir la section « Lot 6e ». | Accepté (6e) |
| W-02 | `LoadingScene.Start` : `CardAssetService.LoadHeavyAssets()` et `AudioService.LoadAllSounds()` dans un `TaskScheduler`, puis `IntroScene` | chargement asynchrone | Non (vérifié absent) | `grep load_threaded` dans `godot/scripts` : 0 résultat | Différent | Pas de préchargement des cartes ni des sons. Le jeu charge à la demande : `AudioManager.gd:131` (`load(path)` avec cache), `BoardUI.gd:259`, `RulesViewer.gd:85`. Sur le web, chaque première utilisation lit le .pck déjà en mémoire (pas de latence réseau). Le coût est un chargement synchrone de décodage au premier usage. Non mesuré. | Corrigé (Moyenne) |
| W-03 | `Game.OnlineSuspend` (`AndroidActivity.cs:95-112`, `OnlineClient.cs:45` : `MaxSuspendedTime` 30 s) : pause en arrière-plan | pause et reprise | Partiel | `BoardUI.gd:3562`, `BoardUI.gd:860-870` | Oui (adapté) | `NOTIFICATION_APPLICATION_FOCUS_OUT` n'annule que le glisser en cours. Dans `_process`, `dt` est borné à 1 s par image pour qu'un onglet en arrière-plan ne vide pas la barre de temps d'un coup. La partie locale n'est pas mise en pause à la perte de focus (le navigateur ralentit `requestAnimationFrame`). Pas d'équivalent au `IsSuspended` sur 30 s : le multijoueur est géré côté serveur (délai de grâce 30 s, HANDOFF). **6e :** voir la section « Lot 6e ». | Conforme (6e) |
| W-04 | Cadence APK : aucun `TargetFramerate` ni `IsFixedTimeStep` dans le décompilé (`grep` sans résultat) | N/A (web) : cadence | Non vérifié | `project.godot` : pas de `max_fps`, `vsync` ni `low_processor_mode` | Non vérifié | Valeurs par défaut Godot (vsync actif, physique 60 tps). Aucune mesure de fps dans le dépôt. **6e :** voir la section « Lot 6e ». | Conforme (6e) |
| W-05 | N/A (web) : shell HTML `html/head_include` | script injecté dans la page | Oui | `export_presets.cfg:30` | Sans objet | Le script force `window.isSecureContext = true` et remplace `AudioContext` par une sous-classe qui fournit un faux `audioWorklet.addModule()` quand `audioWorklet` est absent. Intention : permettre à Godot de démarrer en HTTP non sécurisé (LAN `http://192.168.1.98:8090`). Fragile : il masque un vrai contexte non sécurisé, et il écrase la classe globale `AudioContext`. Sans threads, l'audio n'utilise pas le worklet. Vérifié le 2026-10-26 sur le homelab : ce mode n'évite pas le worklet. À chaque son, Godot lève `Failed to create PositionWorklet` (`AudioWorkletNode` impossible, le faux `addModule()` ne charge rien) ; la console se remplit. Effet audible non vérifié. le script ne s'exécute que dans la page. À reconfirmer à chaque montée de version Godot. Derrière Cloudflare en HTTPS, il est inutile (HTTP-only : inconnu). | Corrigé (Moyenne) |
| W-06 | N/A (web) : options d'export | `export_presets.cfg` | Oui | `export_presets.cfg:19-21,29-36` | Oui | `thread_support=false`, donc ni COOP ni COEP requis : `ensureCrossOriginIsolationHeaders=false` (visible dans `GODOT_CONFIG` du `index.html`, ligne 114). `extensions_support=false`. `vram_texture_compression` desktop et mobile à `false` : les textures sont en webp non compressé en VRAM (plus lourd en mémoire GPU, compatible partout). `canvas_resize_policy=2` (adaptatif), `focus_canvas_on_start=true`, PWA désactivé, `custom_html_shell=""`. | — |
| W-07 | N/A (web) : renderer, affichage | `project.godot` | Oui | `project.godot:25-34,38-39` | Oui | `gl_compatibility` (WebGL 2) ; fenêtre 1920×1080 ; `stretch mode=canvas_items`, `aspect=keep_aspect` ; `emulate_touch_from_mouse=true`. Cohérent avec la cible desktop souris. | — |
| W-08 | N/A (web) : taille du build | `index.pck`, `index.wasm` | Oui | `build_web/` | Oui | `index.pck` = 39 392 976 octets, `index.wasm` = 39 514 754 octets, `index.js` = 279 815 octets (`ls -l`). Premier chargement : environ 79 Mo bruts, réduit par gzip pré-calculé (`Dockerfile:15`, `gzip -9k`). Tailles .gz non mesurées (aucun .gz local). Pas de brotli. **Corrigé en partie le 2026-10-28** (mesures du même poste, export `--export-release Web`) : `index.pck` 61 374 196 → 57 163 068 octets (−4 211 128, −6,9 %). `exclude_filter` retire 66 cartes du wiki jamais chargées (l'APK a la même carte : `CardDB.card_image` prend `apk_cards` d'abord) et les 6 dos du wiki (les 5 dos APK existent), soit `assets/cards/backs/*`, `assets/cards/*/BMA*` et 11 fichiers `KSA002`/`THK*`. Textures déjà en WebP (avec perte q 0,7 pour les cartes, sans perte pour l'interface) : pas de gain sans changer l'aspect, laissées telles quelles. Les fichiers d'interface qui ne sont pas cités par leur nom sont chargés par motif (`%s_bg`, `room_icon_%s`...) : non retirés. Brotli : l'image `nginx:alpine` n'embarque pas le module (paquet `brotli` à compiler via pkg-oss), pas simple ni sûr : `gzip -9` + `gzip_static` conservés ; `index.pck` ne se compresse de toute façon presque pas. | Mesuré (Moyenne) |
| W-09 | N/A (web) : contenu du pck | filtres d'export | Oui | `export_presets.cfg:11-13` | Oui | `include_filter` explicite (scripts, scènes, data, audio, fonts, ui, cards, apk_cards, rules). `exclude_filter` : `godot/tests/*` et `godot/server/*`. Assets sources : `assets/cards` 47 Mo, `apk_cards` 16 Mo, `rules` 12 Mo, `ui` 9,2 Mo, `audio` 7,0 Mo (`du -sh`). Le .pck de 39 Mo est plus petit que ces sources (webp ré-encodé ou non inclus), mais il date du 17 oct. (voir W-11). Les 12 Mo de `rules` et les 47 Mo de `cards` (wiki) pèsent dans tous les cas. Aucun `.gdignore` hors `.godot/`. **6e :** voir la section « Lot 6e ». | Conforme (6e) |
| W-10 | N/A (web) : nginx | `deploy/nginx.conf`, `Dockerfile` | Oui | `deploy/nginx.conf`, `deploy/Dockerfile:15-27` | Oui | `gzip_static on` sert `index.wasm.gz`, `index.pck.gz` et `index.js.gz` avec le Content-Type d'origine. `application/wasm` est annoncé comme présent dans `nginx:alpine` ; `DEPLOYMENT.md:75-81` donne la commande de contrôle, je ne l'ai pas exécutée. `Cache-Control: no-cache` + ETag sur tout : revalidation à chaque chargement (304). Pas de COOP ni COEP, inutiles sans threads. Pas de cache long : acceptable. | — |
| W-11 | N/A (web) : fraîcheur du build local | `build_web/` | Oui | `src/frontend/godot/build_web/` | Non | `build_web/` date du 17 oct. 13:40. Dernier commit : 25 oct. 22:33 (`git log -1`). Les scripts modifiés depuis sont nombreux (`find -newer index.pck` : `AI.gd`, `BoardUI.gd`, `Main.gd` et d'autres). Le dossier est ignoré par git (`.gitignore`) et régénéré par le Dockerfile. Le build local est périmé (inoffensif en production) ; la production'est reconstruite par `docker compose --build` (`DEPLOYMENT.md`). **6e :** voir la section « Lot 6e ». | Conforme (6e) |
| W-12 | N/A (web) : invalidation de cache | `Cache-Control: no-cache` | Oui | `deploy/nginx.conf`, `DEPLOYMENT.md:86-88,119-122` | Oui | Pas de hash dans les noms : le navigateur revalide à chaque chargement. Le risque porte sur les visiteurs de l'ancien déploiement avec service worker (`DEPLOYMENT.md` : recharger deux fois). Le PWA est désactivé dans l'export (`export_presets.cfg:35`). **6e :** voir la section « Lot 6e ». | Conforme (6e) |
| W-13 | N/A (web) : déblocage audio au premier clic | `AudioManager._input` | Oui | `AudioManager.gd:48,80-87,136-138` | Oui | `_unlocked := not OS.has_feature("web")` ; un clic, une touche ou un toucher débloque la musique mise en attente. Cohérent avec l'autoplay des navigateurs. | — |
| W-14 | N/A (web) : audio, qualité et latence | `AudioManager`, assets audio | Oui | `AudioManager.gd`, `assets/audio/` | Non vérifié | 42 wav et 2 mp3 : `music_dungeon_v3.mp3` 2,8 Mo, `music_main.mp3` 0,7 Mo. Voix SFX en nombre fixe (`VOICES`), vol de la plus ancienne. Aucune écoute humaine. 2026-10-28 : 0 erreur audio en console dans Chrome 150 et Firefox 146 ; la qualité et la latence demandent une écoute. Pas de réglage `audio/driver/output_latency` dans `project.godot`. | Non vérifiable ici (Moyenne) |
| W-15 | N/A (web) : travail par image | `_process` | Oui | `BoardUI.gd:860`, `ApkParticles.gd:110`, `AudioManager.gd:183` | Oui | `BoardUI._process` : appelle `_tick_warn`, `_drag_tilt`, puis une boucle IA avec `legal_moves` et `AI.pick_move` seulement si timer atteint (> 0,5 s ou 0,2 s). `ApkParticles._process` ne fait que suivre un nœud. `AudioManager` ne tourne que pendant un sting (`set_process(false)` par défaut). 139 occurrences de tween/`create_tween` dans `BoardUI.gd` (4401 lignes), 18 mentions de shader/`ShaderMaterial` dans les scripts. Aucun profilage : risque réel non mesuré. **6e :** voir la section « Lot 6e ». | Conforme (6e) |
| W-16 | N/A (web) : calcul IA sur le thread principal | `AI.pick_move` | Oui | `BoardUI.gd:~890-900`, `AI.gd` | Non vérifié | Sans threads, une décision IA coûteuse (`legal_moves` + `score_move`) bloque le rendu. Seuil de freeze non mesuré dans un navigateur ; aucune trace dans le dépôt d'une mesure. | Conforme (Moyenne) |
| W-17 | N/A (web) : WebGL 2 | `Engine.getMissingFeatures` | Oui | `build_web/index.html:165-198` | Oui | Le shell standard de Godot affiche un message d'erreur si WebGL 2 ou WebAssembly manque. Pas de texte de repli personnalisé. **6e :** voir la section « Lot 6e ». | Conforme (6e) |
| W-18 | N/A (web) : navigateurs testés | test réel | Oui | `http://192.168.1.98:8090` (build déployé), Playwright | Partiel | 2026-10-28, build déployé, Playwright 1280x720 : **Chrome 150** (le vrai Chrome installé) : WebGL 2, menus, choix des joueurs, plateau, 0 erreur console. **Firefox 146** : idem jusqu'à la défausse de la première main, 0 erreur (un seul avertissement de dépréciation de l'instruction wasm `try`, émis par Emscripten). **WebKit** (moteur de Safari, build Windows de Playwright) : rendu identique jusqu'au plateau ; avertissements `glBlitFramebuffer: Read and write color attachments cannot be the same image` (couche GL de Godot, sans effet visible) ; aucun son, car ce build n'a pas Web Audio (`typeof AudioContext` = `undefined`), ce qui ne dit rien du vrai Safari. Reste : vrai Safari sur macOS ou iOS (aucun appareil Apple ici), en particulier l'audio et le hack `head_include`. | Haute (Safari réel seulement) |
| W-19 | N/A (web) : clic droit, menu contextuel, plein écran | entrées | Partiel | `OnlineMenus.gd:137,319` (menu contextuel désactivé sur 2 `LineEdit`) | Non vérifié | Aucun code de plein écran (`window_set_mode` : 0 résultat). Pas de gestion explicite du clic droit sur le canvas : le comportement du navigateur reste actif. Zoom de page et perte de focus : couverts seulement par `canvas_resize_policy=2` et par le handler de `BoardUI`. **6e :** voir la section « Lot 6e ». | Corrigé (6e) |
| W-20 | N/A (web) : mobile | tactile | Partiel | `project.godot:36` (`emulate_touch_from_mouse`) | Oui (hors cible) | Cible souris sur desktop (mémoire projet) ; tactile non testé (HANDOFF:141). **6e :** voir la section « Lot 6e ». | Accepté (6e) |

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
  - Moyenne : W-02 (pas de préchargement des cartes et des sons, décodage au premier usage), W-05 (`head_include` force `isSecureContext` et remplace `AudioContext` : fragile à chaque montée de Godot), W-08 (environ 79 Mo bruts au premier chargement, gzip seulement ; `.pck` allégé de 4,2 Mo le 2026-10-28), W-14 (audio web jamais écouté par un humain), W-16 (IA sur le fil principal sans threads, gel non mesuré).
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

Aucun bloquant prouvé. Points de vigilance : navigateurs hors Chromium non essayés (W-18), shim `head_include` qui force `isSecureContext` et remplace `AudioContext` (W-05, D-51), IA sur le fil principal sans threads (W-16), environ 75 Mo au premier chargement après allègement du `.pck` de 4,2 Mo (W-08, corrigé le 2026-10-28).

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
| X-M06 | `BossInfo.CharacterOffset` (X -40..110, Y 260..320 par boss ; `DungeonFrameEntity.cs:540-549` : marge droite = 720 + X + 211, `LocalY = Y`) | champ + positionnement | Non (vérifié absent) | `grep -rniE "characteroffset\|character_offset\|\"offset\"" scripts data/cards.json tools/*.py` = 0. Godot centre le sprite sur l'estrade : BoardUI.gd:1546-1600 (taille/position :1594-1596, constantes :89-90) | Différent | Le décalage propre à chaque boss n'est pas repris. Un sprite large (KSA005, 333 px) est réduit à 300 px (BoardUI.gd:90) alors que l'APK ne le réduit pas. Écart visuel jamais mesuré par capture : non vérifié pixel par pixel. | Corrigé (Moyenne) |
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
| X-M22 | `GB.DiscardFromHand` (l.605, 617) et `GB.DestroyRoom` (l.841) : `DiscardPile*.Sort()` par `UniqueID` à chaque ajout | effet de bord | Non (vérifié absent) | `grep "sort" BossEngine.gd CardDB.gd RoomAbilities.gd` : aucun tri de `roomDiscard` ou `spellDiscard` ; `ApkAI.gd:627-630` (`_discard_rank` = `_oid`, harnais seulement) | **Différent** | Les défausses ne sont pas triées. Les listes de choix (Dark Altar, Open Grave, Dracolich, Monstrous Monument…) apparaissent dans l'ordre d'insertion au lieu de l'ordre de carte de l'APK. Les égalités de valeur de l'IA (`_chk_009`, `_chk_013` : `_discard_rank`) se départagent aussi différemment hors harnais. Même cause que R-D14 (« sans effet », jugé sur le mélange seulement). | Corrigé (Moyenne) |
| X-M23 | `IBuildRestrictionCommand` / `CannotBuildRoom` (BMA018 Neanderthal Cave), `DungeonSlot.cs:94` | interface | Oui | BE:145-162 (refus des seules salles avancées) | Oui | `Advanced` + `Any` : les ordinaires se bâtissent dessus, les avancées non. L'APK ne regarde ni gel ni verrou, Godot non plus (seul `no_text` TNL). Fichier [flux]. | — |
| X-M24 | `BaseCondition` + conditions utilisées (`DuringPhase`, `OncePerTurn`, `OpponnentDungeonSizeMoreThan`, `HasPendingRoomToBuild`) | classe de base | Oui (par carte) | CD:304-326 (`SPELL_PHASE`), RA:125 et :167 (`ONCE_PER_TURN`), ST:392-394 | Oui | Voir X-M36 pour les phases. | — |
| X-M25 | `BaseTargetProvider` (UniqueID, TargetsAmount, `MinTargetsAmount`, `NeedPlayerIteraction`, `HasSecretValues`, `HasOnboardVisibleTargets`) | classe de base | Non (par conception) | `ApkParityTrace.gd:1185` (usage de `targetId` côté harnais) | N/A | `HasSecretValues` n'est lu que dans `Targets/` (grep) : sans effet. `ViewFilter.gd:73-77` masque déjà les choix d'un autre joueur. | — |
| X-M26 | `SingleTargetProvider.TryToAutoresolve` | classe | Oui (au cas par cas) | RA:216-217, :501-517 | Oui | Auto-résolution d'une cible unique (Kitchen, Dark Altar, Draculord). Voir X-M04 pour l'exception. | — |
| X-M27 | `ComposedTargetProvider` (CleanEmptyValues, `GetAvailableTargets`, `TryToAutoresolve`) | classe | Oui (au cas par cas) | RA:404-447, RA:955-1005 | Partiel | `CheckConditions` (`Ability.cs:117-118`) exige au moins un propriétaire avec `Min` cartes : Godot refuse Dracolich si moins de 2 salles en main ou défausse vide (RA:411-415). | — |
| X-M28 | `BossOwner` (35 occurrences : 15 bosses, sorts et salles de pioche) | cible | Oui (implicite : `player_id`) | RA:ensemble, SE:46-47 `_target_id` | Oui | Pour un sort, `GetOwnerPlayer(spell)` renvoie le `FromPlayer` de la transaction en attente (`GB:229-243`) : Godot passe `caster_id`. Oracle : 24 traces, 0 écart. | — |
| X-M29 | `BossDungeon` (KSA002 Hellcow : `["False","5","Any","Any","Any"]`, `HasOnboardVisibleTargets=false`) | cible | Oui | RA:955-1005, M:974-989 (`rearrange-dungeon`) | Oui | Joueur `Any` = tous les donjons non éliminés ; Godot exige que TOUT le donjon soit ciblable (`_rearrangeable`, RA:987-996), équivalent à `Target1.Count == DungeonSize` (`RearrangeDungeon.cs`). Oracle 1× (1). | — |
| X-M30 | `BossDungeon` / `RearrangeDungeon` : cibles calculées dans `RevealAllRoomCards` (`GB:928-967` ; `EnqueueAbilityTransaction` résout tout de suite, GB:1317-1331) | cas limite | Oui | M:1575-1625 (`_build_reveal_queue`, `_pending_slots`), RA:1056-1110 (`rearrange_choice`, `_rearrangeable`) | Oui | À l'instant du level-up de Hellcow, l'APK exclut les emplacements encore en attente des joueurs traités après lui (`!slot.PendingToBeBuilt`) et compare à `DungeonSize` (dernier emplacement non en attente). Godot a déjà tout révélé. Seul un adversaire qui construit le même tour, joueur de rang plus bas, serait touché. Corrigé le 2026-10-28 : `_build_reveal_queue` photographie les emplacements encore face cachés (`_pending_slots`) à l'instant où il met le level-up en file ; `process_level_up` et `rearrange_choice` reçoivent cet instantané (`pend`, recopié dans les choix suivants) et `_rearrangeable` reprend `DungeonSize` : dernier emplacement non en attente + 1, comparé aux cibles actives. Un emplacement en attente en fin de donjon n'en fait plus partie (les salles avant lui restent réordonnables, l'ordre ne touche que ces salles) ; un trou en attente avant une salle visible rend le donjon non ciblable (l'APK le propose puis lève « Dungeon size must be equal to selected rooms » : non porté, un plantage n'est pas une règle). Golden `_t_levelup_hellcow_pending` (adversaire de rang plus bas qui construit le même tour : sa salle en attente n'est pas proposée, 2 salles au lieu de 3, salle en attente intacte). Les traces d'oracle ne l'exercent pas (parité inchangée). Klonos qui copie Hellcow lit un instantané vide. | Corrigé (Moyenne) |
| X-M31 | `HeroInThisRoom` (BMA017, BMA027, BMA028 ; paramètres `["Any","Owner"]` ignorés) | cible | Oui | RA:22-28 (`hero_is_in_room`), RA:306-316, RA:328-340 ; M:1948-1951 | Oui | C# : héros de l'`EntranceQueue` dont `InsideDungeonSlot` est le slot de la salle ; Godot : `adventure.playerId` et `roomIndex`. Oracle : BMA017 10× (4), BMA027 16× (12), BMA028 3× (3). Mort différée de Boulder Ramp : voir R-D46. | — |
| X-M32 | `RoomInHand` — Dracolich Lair (`["True","2","Any","Any","Owner"]`) | cible | Oui | RA:404-426 | Partiel | Même condition d'usage (2 salles en main ET 1 en défausse). Écart d'interface : avec exactement 2 salles, l'APK autorésout (`enumerable.Count() <= TargetsAmount`) alors que Godot ouvre toujours un choix de paires, parfois à une seule option. Affichage du popup non vérifié en jeu. **6e :** voir la section « Lot 6e ». | Corrigé (6e) |
| X-M33 | `RoomInHand` — Witch's Kitchen (`["False","1","Any","Monster","Owner"]`) + `BossOwner` | cible | Oui | RA:501-533 | Oui | `RoomType.ToString()` Monster/Trap ↔ `type == "monster"` : 35/35 types de salles APK recoupés. Une seule Monster : défausse automatique. | — |
| X-M34 | `OncePerTurn` posé à l'exécution (`Ability.cs:135`) | cas limite | Partiel | RA:167 pose `usedThisTurn`, RA:180 ne remet à faux que pour « no activated ability » | Partiel | `_witchs_kitchen` (RA:501-507) et `_all_seeing_eye` (RA:208-215) retournent une erreur SANS remettre `usedThisTurn=false` (Dracolich le fait, RA:414). Inatteignable : `legal_moves` sonde sur copie (M:327-330) et le serveur n'accepte que des coups de `legal_moves`. R-E29 dit à tort que RA:180 couvre tous les échecs. **6e :** voir la section « Lot 6e ». | Corrigé (6e) |
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
| X-M58 | `LogicCardBase.AlternativeArtId` ← `GameBoardExtensions.cs:170-193` (copie k d'un lot : `n = n % (Alt+1) + 1`) → `CardAssetService.GetFrontCardAsset:209-211` (suffixe a, b…) | champ + choix d'image | Partiel | `CardDB.gd:165-173` ne charge que `<id>.webp` (= `<id>a`, même md5) ; `CardGallery.gd:6-7` gère les arts alternatifs en galerie seulement | **Différent** | En partie, la 2e copie de BMA017, 021, 029 et des sorts BMA040, 042, 053 affiche l'art « b » dans l'APK ; Godot affiche toujours « a » (fichiers `bma0xxb.webp` présents mais non utilisés en jeu). Purement visuel. | Corrigé (Moyenne) |
| X-M59 | `LogicStrings` (`NameOrDefault`, gabarits `Target{0}<Hero>`…) | classe | Non (par conception) | — | N/A | Sert aux `ToString()` de commandes (messages de debug). | — |
| X-M60 | `DBMRandom` (copie de `System.Random`) | classe | Non (vérifié absent) | `grep 161803398` dans scripts : 0 ; `Match.gd:54` `rng.randomize()`, `GameManager.gd:26-41` (`TUT_SEED=2832`) | Différent (assumé) | Les mélanges ne reproduisent pas les séquences de l'APK. Tutoriel : les 12 salles, 4 sorts et 2 héros forcés sont identiques à `GameBoardExtensions.cs:174-196` ; seul le reste des pioches diffère (TUT_SEED commenté, GameManager.gd:26). L'oracle utilise le `DBMRandom` d'origine (`tools/apk-oracle/Program.cs`). **6e :** voir la section « Lot 6e ». | Corrigé (6e) |

### 13B — Projet et moteur (`DBMGameProject.*`, `WaveEngine.Extensions.*`, 107 classes)

| ID | Élément source (décompilé) | Type (classe/méthode/asset/scène) | Présent dans Godot ? | Fichier Godot | Équivalent fonctionnel ? | Écart / Commentaire | Priorité |
|---|---|---|---|---|---|---|---|
| X-P01 | `BaseBorderBehavior.cs:9-70` et `BorderStyles.cs:3-10` : états None, Yellow, YellowGlow, Red, GreenGlow, fondu entrant ou sortant à chaque changement (`:59-68`) | classe abstraite + enum | Partiel | `CardUI.gd:82-86`, `BoardUI.gd:3711-3730` | Partiel | Pas d'enum ni de comportement commun : chaque cadre est posé à la main (`set_gold`, `_gold_frame`). Le fondu au changement de style n'est pas vérifié. | Accepté (Basse) |
| X-P02 | `CardBorderBehavior.cs:39-78` : Yellow, YellowGlow (+ particules), Red ; variante `_scaled` ×2,7 si l'échelle du parent ≤ 0,5 (`:31`, `:64-71`) | classe | Oui (partiel) | `CardUI.gd:86`, `BoardUI.gd:1761`, `3679-3704`, `3717`, `4007-4008` | Partiel | Les `_scaled` ne servent qu'aux emplacements (`BoardUI.gd:3679`, `3704`). Les cibles de sort sur petites cartes étirent `card_border_yellow_glow` (390×528) sur la carte (`BoardUI.gd:3715-3717`), et le trait s'amincit au lieu d'utiliser le `_scaled` (152×203, ×2,7). Les 8 assets `card_border_*` existent. | Corrigé (Moyenne) |
| X-P03 | `CardBorderBehavior.cs:55-57` : GreenGlow posé sur la salle propriétaire de la capacité en cours de résolution (`TargetResolverBaseSceneBehavior.cs:228`) ; grossissement + boucle `sfx_sparklecard` + particules (`CardStackSlotComponent.cs:309-316`) | état de bordure | Non (vérifié absent) | `BoardUI.gd:2977-2987`, `2996-3007` | Différent | `grep -rn card_border_green src/frontend/godot/scripts` donne 0 résultat, donc l'asset `card_border_green_glow` n'est jamais chargé. Godot applique les particules et le son de boucle aux salles ciblables, pas à la salle source. Contredit en partie P-A44 (marqué Oui). | Corrigé (Moyenne) |
| X-P04 | `ChallengerBorderBehavior.cs:7-23` : `challenger_panel_selected_red` ou `_yellow` autour du panneau adverse (`OneOpponentDetail.cs:232`) | classe | Non (vérifié absent) | — | Non | `grep -n "challenger_panel\|selected_red\|selected_yellow" scripts/*.gd` donne 0 résultat. Les assets (229×475) sont dans `assets/ui/ingame/` mais jamais lus. Godot cible le sprite du boss (`BoardUI.gd:2938-2941`), pas le cadre du panneau. | Corrigé (Basse) |
| X-P05 | `CollapsedOpponentBorderBehavior.cs:7-23` : `bg_boss_profile_selected_yellow` ou `_red` sur les vignettes (3 à 4 joueurs) ; opacité 1 si joueur actif (`CollapsedOpponentDetail.cs:331-333`) | classe | Non (vérifié absent) | `BoardUI.gd:801-832` | Différent | Même grep, 0 résultat. Les vignettes sont remplacées par des boutons P2, P3… (voir P-B23). Seules les particules du joueur actif sont portées (`BoardUI.gd:824-832`). | Conforme (Basse) |
| X-P06 | `CardShadowBehavior.cs:14-120` : ombre `card_shadow` décalée jusqu'à (40, 70) selon l'échelle (0,37 → 0,5), opacité 0,75, visible pendant le glisser (`CardExtractBehavior.cs:227`) et sur la salle en attente (`CardStackSlotComponent.cs:130`) | comportement + asset | Non (vérifié absent) | — | Non | `grep -rni "card_shadow\|CardShadow" scripts` donne 0 résultat. `find src/frontend/assets -name "card_shadow*"` ne trouve rien (seule une copie importée périmée dans `.godot/imported`). La carte glissée n'a pas d'ombre portée. | Corrigé (Moyenne) |
| X-P07 | `CardRotationBehavior.cs:84-131` : inclinaison Y = delta x × 0,005 rad par image, bornée à ±22,5° ; X jamais appliqué ; inversion des ordres d'affichage enfants (`:113-131`) ; carte attirée vers le doigt (18 × dt, `:87-95`) | comportement | Oui (approximé) | `BoardUI.gd:3616-3623`, `3625-3630` | Partiel | Même formule, rendue en largeur × cos(angle) sans perspective 3D. `UseTopTexture` et l'inversion des enfants n'ont pas d'objet en 2D. La carte suit directement la souris. | Accepté (Basse) |
| X-P08 | `CarrouselHorizontalComponent.cs:23-45` : positions ±266 / ±342 / ±380, échelles 0,64 / 0,61 / 0,58 autour de 1,14 ; ordres d'affichage 0,1 à 0,5 ; utilisé par `CardCarrouselEntity` (tirage du boss) | composant | Oui | `BoardUI.gd:91-94`, `1795-1798`, `1866-1877` | Oui | Rapports d'échelle (0,56 / 0,535 / 0,51 contre 0,58 / 0,55 / 0,52) et positions (272 / 342 / 378) mesurés sur les captures, écart ≤ 6 px. Le glisser et les flèches du nombre de joueurs restent absents (voir I-08). | — |
| X-P09 | `CarrouselVerticalComponent.cs:46-61` : colonne verticale (y −700, 0, 140, 175, 210, 245), échelles 1,4 / 1,2 / 1, opacités 0 / 1 / 0,8 / 0,6 / 0,4 / 0 ; zoom de pile via `SlotDetailEntity.cs:77-90` | composant | Non (vérifié absent) | `BoardUI.gd:3433-3450` | Non | Seule la salle du dessus est zoomée, et seulement si elle est activable. Aucune colonne défilante ni dégradé d'opacité. Voir P-C15 ; le glisser vertical est dans I-08. | Corrigé (Moyenne) |
| X-P10 | `ExpandBaseBehavior.cs:13-153` : éventail ouvert ou fermé (durée 0,5 s, interpolation des positions et rotations) ; seule sous-classe `OpponentsExpandBehavior`, écran `MultiplayerScene` sans appelant (U-C01) | classe abstraite | Oui (équivalent d'écran) | `OnlineMenus.gd:165-238` | Oui | Chemin mort de l'APK ; Godot l'a reproduit pour PLAY ONLINE / PASS AND PLAY (U-C03). | — |
| X-P11 | `FollowBehavior.cs:8-58` : une entité suit une autre (décalage, copie d'opacité) ; barres de temps (`GamePlayBaseScene.cs:216`, `SpellBattleEntity.cs:33`) et cœur du héros (`HeroCardEntity.cs:75-79`, décalage (0, −150)) | comportement | Oui | `BoardUI.gd:76`, `944-960`, `2412-2417` | Oui | Barre verte placée au-dessus du héros qui traverse, ou de la pile ; cœur du héros à −150 × 0,78 de son sprite. | — |
| X-P12 | `HeartRoomControlRotationBehavior.cs:24-28` : cœur de la salle visible seulement si la rotation Y du parent est dans [−90°, 0°] (moitié de retournement) | comportement | Oui (par construction 2D) | `CardUI.gd:107`, `BoardUI.gd:1866-1877` | Oui | Pas de rotation 3D : le retournement est une échelle X de 1 → 0 → 1 qui échange les textures. Aucun rendu intermédiaire visible à reproduire. | — |
| X-P13 | `RitchTextComponent.cs:33-61` : interligne 6, retour à la ligne manuel via `StringFactory.GetLines` (17 px par majuscule), balises `<rtf>` et mots `#` en or ; seul appelant `BalloonEntity.cs:79` | composant | Oui | `BoardUI.gd:4219` (bulle), `TutorialOverlay.gd:879-889` | Oui | Le seul texte réel de bulle, `DoneHint`, n'a aucun `#` (`TutorialStringFactory.cs:28`), donc pas d'or. Le `#BUILD #A #ROOM` n'est que dans un bouton DEBUG (`GamePlayBaseScene.cs:543`). Godot coupe les lignes à la main (T-A35). Les titres BBCode en or sont portés (`BoardUI.gd:565`, `1216`). | — |
| X-P14 | `SimpleTimerBehavior.cs:6-65` : minuterie répétée ; 5 s pour pulser le bouton DONE (`DoneButtonEntity.cs:106-117`), 3 s pour relancer le halo de capacité (`CardAttributesComponent.cs:328`) | comportement | Partiel | `BoardUI.gd:3463` (3 s), `DungeonSlot.gd:176-179` | Partiel | Halo de capacité 3 s : Oui. Pulsation du bouton DONE toutes les 5 s : absente, voir P-C51 (`grep pulse` ne donne rien sur `btn_pass`). | Conforme (Basse) |
| X-P15 | `TransformEffectBehavior.cs:10-111` : interpolation de position, d'opacité, d'échelle et de rotation | comportement | N/A | — | — | Code mort : `grep -rn TransformEffectBehavior` ne trouve aucun appelant en dehors du fichier. Les Tweens Godot couvrent le besoin. | — |
| X-P16 | `ButtonWithDeckEntity.cs:12-53` : gros bouton à éventail (`big_button`, titre arcadepix ×1,3 centré, texte Bookman, éventail replié à l'appui) ; seul appelant `MultiplayerScene.cs:47,70` (écran mort, U-C01) | entité | Oui (équivalent d'écran) | `OnlineMenus.gd:165-238` | Oui | `big_button` et `big_button_selected` existent dans `assets/ui/buttons/` et `assets/ui/navigation/`. Aucune action requise. | — |
| X-P17 | `HeroCardEntity.cs:42-114` : sprite du héros (y −40), cœur de PV `health_hero_icon` ×2 suivant le héros, cœur de carte `health_hero_buff_icon` (−115, 195) ×1,3 en or, masqué tant que la valeur vaut la PV initiale ; `RefreshHeroHeart` (`:90-114`) | classe | Partiel | `BoardUI.gd:76`, `2395-2417`, `2447-2453` | Partiel | Cœur de PV et cœur « −N » (`health_hero_trans_icon`) : Oui. Cœur de buff sur la carte du héros : absent (`grep health_hero_buff` dans `scripts` ne donne rien). L'asset `health_hero_buff_icon` est aussi absent de `assets/ui/` (`find` vide), alors qu'il est dans `Atlas.cs:65`. `health_room_icon_glow` existe. | Corrigé (Moyenne) |
| X-P18 | `LabelAndBackground.cs:16-150` : libellé sur fond centré, largeur estimée par caractère (17 ou 15 px × échelle), `<rtf>` retiré pour le calcul, fondu 0,3 s | entité | Oui (mécanisme Godot) | `UiKit.gd:32-44`, `116` | Oui | `Label` Godot centré par alignement, contour noir 3 px ; la largeur est fournie par le moteur de texte, plus besoin de l'estimation à 15/17 px. Aucune action requise. | — |
| X-P19 | `PurchaseDetailEntity.cs:13-44` : ligne « + N … » de la boutique (or, blanc) | entité | N/A | — | — | Boutique retirée (périmètre). Le contenu reste affiché ailleurs par les fiches d'extensions. | — |
| X-P20 | `UIButtonEntity.cs:32-80` : bouton à deux textures (normal, pressé), `TouchPressed` / `Released` | entité | Oui | `BoardUI.gd:301-312`, `4267-4271` | Oui | `TextureButton` avec `texture_pressed`. `DoneButtonEntity` (pass/done) est couvert par P-B31. | — |
| X-P21 | `UpdatableTextBlock.cs:19-46` : le texte s'estompe (0,25 s) puis réapparaît au changement | entité | Non vérifié | `BoardUI.gd:2412-2417` (étiquette de PV créée avec `_lbl`, aucun fondu) | Non vérifié | Les compteurs de cœur, d'XP et de blessures sont changés par affectation directe. Le fondu ne m'a pas été confirmé sur chaque compteur ; effet visuel mineur. | Corrigé (Basse) |
| X-P22 | `TopRightPanelEntity.cs:20-219` : colonne droite 211 px, 2 joueurs = `OneOpponentDetail`, 3 à 4 = `ExpandedOpponentDetail` + `CollapsedOpponentDetail`, `ChallengerDetail`, bouton level up (105, 55), bouton options | entité | Partiel | `BoardUI.gd:433-478`, `480`, `627-635`, `801-832` | Partiel | 2 joueurs : conforme (P-B17). 3 à 4 : vignettes remplacées par `foe_bar` (P-B23), pas de panneau étendu (P-B27). Bouton level up présent. | Corrigé (Moyenne) |
| X-P23 | `GamePlayPaPScene.cs:18-203` : hotseat 2 joueurs, boss aléatoires, changement de joueur avec main qui sort puis revient, donjons échangés | scène | Oui | `Main.gd:341-382`, `BoardUI.gd:704-781`, `1175`, `1939-1948` | Partiel | Voir P-A49 à P-A51. Écart connu : en pass and play Godot montre GO / PASS TURN et la main en aventure. Chemin atteignable seulement par `MultiplayerScene` (mort côté APK) ; Godot le propose. | Accepté (Basse) |
| X-P24 | `CardsFactory.cs:16-103` : dos de pioche (BMA009 / BMA041), cartes de test, `CreateInGameCard`, `CreateSlotRoomInGameCard` (échelles Min/Max 0,5) | fabrique | Oui | `CardUI.gd:36`, `100-101`, `BoardUI.gd:1660` | Oui | Dos de carte : `assets/apk_cards/base/back_room.webp`, `back_spell.webp`, `back_boss.webp` existent. Les échelles de carte posée sont reprises (`BoardUI.gd:1665`). | — |
| X-P25 | `CarouselLayer`, `SidePanelLayer`, `SpellBattleLayer`, `TimeBarLayer`, `TopCardsLayer` (`*.cs:5-8`) : couches d'affichage, aucune logique propre, découpées au rectangle virtuel | couches (5 classes) | N/A | — | — | Équivalent Godot : l'ordre d'empilement se règle par `z_index` et l'ordre des nœuds, le rectangle virtuel par le viewport 1920×1080 (`project.godot:23-26`). | — |
| X-P26 | `DungeonTopScissorLayer.cs:9-19` et `DungeonBottomScissorLayer.cs:9-19` : découpe du donjon en haut (y 63, h 437) et en bas (y 500, h 453) | couches (2 classes) | Non (vérifié absent) | `BoardUI.gd:362`, `1307` | Différent | `grep clip_contents` ne trouve que le nœud racine et une bannière. Aucune découpe par donjon : le saut du héros (y −200 puis +400, `BoardUI.gd:2247-2253`) peut déborder du cadre au lieu d'être coupé. | Conforme (Basse) |
| X-P27 | `ScissorAlphaLayer.cs:8-43`, `ScissorAlphaLayer2/3/4` : couche alpha avec test de ciseau | infrastructure WaveEngine (4 classes) | N/A | — | — | Moteur de rendu Wave ; Godot : `clip_contents` ou `Window` (voir X-P26 pour le seul besoin de fond). | — |
| X-P28 | `DBMMenuBaseScene.cs:7-27` : retour = pop de l'écran ; `ShowFullGameUnlockScene` (achat du jeu complet) | scène de base | N/A | — | — | Boutique et déverrouillage retirés (périmètre). Le retour des menus passe par `go()` / flèche dans `Main.gd` et `OnlineMenus.gd`. | — |
| X-P29 | `IHighLight.cs:8-12` : `HighLightCards(cards, style)` et `CleanHighLightCards(style)` ; implémentée par `GamePlayBaseScene`, les piles, les panneaux | interface | Oui | `BoardUI.gd:2944-3010`, `3711-3730` | Partiel | Mécanisme équivalent (cadre doré, rouge, halo). Les styles GreenGlow et des panneaux adverses manquent (X-P03, X-P04, X-P05). | Conforme (Basse) |
| X-P30 | `EntitiesExtensions.cs:12-80` : `IsContainedByEntity` (test de dépôt avec précision ×1,2, `BuildRoomHandSceneBehavior.cs:239`), `ChangeLayer`, `DetachFromOwner`, `FindChildByTag` | helpers | Oui (test de dépôt) | `BoardUI.gd:3694-3695` | Oui | Même zone ×1,2 centrée sur l'emplacement. Les autres helpers (couches, détachement) n'ont pas d'objet dans Godot (`reparent`, `z_index`). | — |
| X-P31 | `ScenesExtensions.cs:10-15` : taille d'une texture d'atlas | helper | N/A | — | — | Godot lit `Texture2D.get_size()` directement. | — |
| X-P32 | `StringExtensions.cs:10-89` : `Truncate` (boss 10 car., sous-titre 25, alias 15, nom 45), `Heigth`, `WordWrap`, `BreakLine` | helpers | Partiel | `OnlineMenus.gd:136`, `318`, `432-433`, `860`, `Profile.gd:16` | Partiel | Troncatures du nom de joueur (45, 25) portées. Pas de troncature du nom de boss (10) ni du sous-titre (25) dans `BoardUI.gd:2144-2163`. Aucun boss du jeu de base ne dépasse ces tailles ; seuls `The Brothers Wise` (17), `Elicon` (sous-titre 31) du deck PlayerChoice. `Heigth` ne sert qu'à la boutique (retirée). | Corrigé (Basse) |
| X-P33 | `ViewportManagerExtensions.cs:13-46` : bords utiles du viewport plafonnés à 1920×1080 | helpers | Oui | `project.godot:23-27` | Partiel | `canvas_items` + `keep_aspect` : bandes noires sur écran non 16:9. L'APK étend la zone utile jusqu'au plafond. Écart cosmétique. | Accepté (Basse) |
| X-P34 | `IKindleApplication.cs`, `ISteamApplication.cs` : interfaces vides (stores Amazon et Steam) | interfaces (2) | N/A | — | — | Aucun membre. Portage store non applicable. | — |
| X-P35 | `CustomColors.cs:10-74` : GoldColor #cdb15f, PistachioColor #bfca7a, SidePanelsBackColor #180a18, LoadingBg #270000, TutorialBg #e2bc54, couleurs de trésor des boss (cleric #34495c, fighter #5e2a2f, mage #52506a, thief #74635d), `GetRTFColorString`, `CountTextNotFormat` | constantes + helpers | Partiel | `UiKit.gd:8`, `Main.gd:44`, `CreditsScreen.gd:34`, `BoardUI.gd:99` | Partiel | Or et pistache : Oui (même valeur). `grep` des 6 autres hex et de `Color(0.0` correspondants dans `BoardUI.gd`, `Main.gd`, `UiKit.gd` : aucun trouvé, donc non reconnus. `GetBossTreasureColor` (`OneOpponentDetail.cs`) : non vérifié. Les `<rtf>` sont remplacés par BBCode (`BoardUI.gd:565`). | Accepté (Basse) |
| X-P36 | `Directories.cs:3-19` : chemins `Content/…` | constantes | N/A | — | — | Chemins du pack WPK ; Godot utilise `res://assets/…`. | — |
| X-P37 | `SpeedEnum.cs:3-8` : Slow, Normal, Fast (`SettingsScene`, `GameSettings`) | enum | Oui | `Profile.gd:109-118`, `BoardUI.gd` (`_speed_factor`) | Oui | 0 / 1 / 2 enregistrés ; facteur ×1,5 / ×1 / ×0,5. | — |
| X-P38 | `IExternalInteractionResolver.cs:7-12` (`ChooseCardToDraw`, `ChooseCardsToDiscard`) et `IExternalTargetResolver.cs:6-11` (`ResolveTarget`) ; seul appelant `HumanPlayerInteraction.cs`, `TargetResolverBaseSceneBehavior.cs` | interfaces (2) | Oui (par un autre mécanisme) | `BoardUI.gd:2751-2800`, `3494-3503`, `SpellTargeting.gd` | Oui (ciblage), non vérifié (pioche) | Le ciblage et la défausse passent par la liste de coups légaux (`_target_list`, `_show_discard`). Le choix de pioche (Haunted Library, R-F39) : côté règles Oui, interface de choix non vérifiée. | Conforme (Basse) |
| X-P39 | `IDBMPurchaser.cs`, `DBMPurchaser.cs:44`, `ILocalStorage.cs`, `DefaultLocalStorage.cs:39` : achats intégrés et stockage local de reçus | service (4 classes) | N/A | — | — | Boutique retirée (module 10). | — |
| X-P40 | `Scenes.Test/` : `BacklightTestScene`, `BossSelectionTestScene`, `BubbleTestScene`, `BubblesTestScene`, `DoneTestScene`, `DrawOrderScene`, `FlipCardScene`, `HandBossSwitchTestScene`, `HeartTestScene`, `LabelTestScene`, `LogTestScene`, `NewHandTest`, `NinePatchScene`, `SpellBattleTest` | scènes de débogage (14) | N/A | — | — | Scènes d'essai du développeur, jamais ouvertes depuis le menu (aucun parcours public). Rien à porter. | — |
| X-P41 | `Properties/AssemblyInfo.cs:1-21` | métadonnées d'assemblage | N/A | — | — | Aucune logique. | — |
| X-P42 | `CardRenderer.cs:10-58` : rendu de la carte avec `UseTopTexture` (face ou dos), teinte, retournement horizontal | moteur de rendu | N/A | — | — | Godot affiche la face ou le dos par un échange de texture (`CardUI.gd:191`). | — |
| X-P43 | `TextControlDrawableRenderer.cs:10-83` et `TextDrawableBlock.cs:10-197` : rendu et propriétés du bloc de texte (police, largeur, alignement, riche, interligne) | moteur de texte (2 classes) | N/A | — | — | Équivalent : `Label` / `RichTextLabel` avec `UiKit.label()` (`UiKit.gd:32-44`). | — |
| X-P44 | `DummyRenderer2D.cs:6-15` : rendu vide pour entité à collision seule | infrastructure | N/A | — | — | Godot : un `Control` sans texture reçoit déjà la souris. | — |
| X-P45 | `MovementBehavior.cs:10-101` : déplacement, rotation, échelle animés sur `AnimationUI` | comportement | Oui (par tweens) | `BoardUI.gd:2250-2253`, `CardUI.gd` (`lerp_vers`) | Oui | `create_tween()` / `lerp_vers` pour tous les mouvements. | — |
| X-P46 | `ParticlesParentSizeBehavior.cs:9-34` : émetteur à la taille du parent × échelle (0,9) | comportement | Oui | `ApkParticles.gd:6-9`, `96` | Oui | Constante `ECHELLE` 0,9 identique ; taille d'émission recalculée à chaque changement. | — |
| X-P47 | `ScaleEffectBehavior.cs:10-108` : grossir ou réduire entre Min et Max, durée donnée | comportement | Oui | `CardUI.gd:15`, `252-254` | Oui | `hover_scale` 1,2 + `lerp_vers` ; salle courante agrandie `BoardUI.gd:2231`. | — |
| X-P48 | `SpriteAtlasEnum.cs:7-33`, `SpriteEnum.cs:7-21`, `SpriteRaw.cs:10-28` : sprite choisi par valeur d'enum (`Atlas.InGameGUI.*`) | infrastructure + enums de sprites | Partiel | `assets/ui/` | Partiel | Contrôle des sprites cités par les classes de ce lot : présents `card_border_*` (+ `_scaled`), `challenger_panel_selected_*`, `bg_boss_profile_selected_*`, `health_hero_icon`, `health_hero_trans_icon`, `health_room_icon_glow`, `levelup_bt(_pressed)`, `bg_levelup_panel`, `big_button(_selected)`, `fg_cover_unlocked`. Absents : `card_shadow`, `health_hero_buff_icon`. Inutilisés dans les scripts : `challenger_panel_selected_*`, `bg_boss_profile_selected_*`, `card_border_green_glow(_scaled)`. | Conforme (Moyenne) |
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

- X-M30 : Hellcow face à un adversaire dont des salles sont encore en attente au moment du level-up (corrigé le 2026-10-28, golden).
- X-M06 : effet visuel de `CharacterOffset` (aucune capture comparée).
- X-M32 : choix de paires de Dracolich quand il n'y a qu'une paire ; X-M22 : ordre réel des défausses à l'écran ; X-M55 : couverture de chaque TypeName (Godot est codé par carte).
- X-P21 (fondu des compteurs), X-P35 (couleurs de trésor des boss), X-P38 (écran de choix de pioche de Haunted Library), X-P01 (fondu au changement de bordure), X-P26 (débordement du saut du héros).

### Synthèse du module 13

- **Classes couvertes** : 177 sur 177, en 128 lignes (13A : 60, 13B : 57, 13C : 11). Avec les modules 1 à 12, **les 560 classes du décompilé et les 5 fichiers non C# de `DBMGame/` sont audités** ; contrôle par mot entier refait le 2026-10-26 (0 classe manquante).
- **Écarts** : 28 — Critique 0, Haute 0, Moyenne 12, Basse 16.
  - Moyenne 13A : X-M04 (Kaw'nee et Rotten Ruins proposent « passer » quand l'APK résout seul), X-M06 (décalage propre à chaque boss absent), X-M22 (défausses non triées par numéro de carte : ordre des choix et égalités de l'IA), X-M30 (Hellcow et salles en attente, corrigé le 2026-10-28), X-M58 (deuxième art des cartes en double jamais affiché en partie).
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
| W-18 | Partiel | Chrome 150, Firefox 146 et WebKit (Playwright) vérifiés le 2026-10-28 sur le build déployé : chargement, menus, plateau OK. Reste le vrai Safari (aucun appareil Apple ici). |
| IA-G47 | Ouvert (Moyenne) | L'APK choisit la salle avant de résoudre la capacité ; non corrigé, non mesurable par l'oracle. |

Non vérifié après correction : aucun rendu à l'écran (P-A10, P-B07, P-B09, P-B30, modale en ligne), aucun essai en ligne dans un vrai navigateur. Boulder Ramp, Exhaustion, Soul Harvest sur une Épique et le tour forcé ne sont couverts que par des goldens (aucune trace oracle ne les joue).

## Lot 1a : règles (2026-10-26)

Validé par `python tools/run_godot_tests.py` (14/14) et l'oracle (6/6, 12/12, 6/6).

| ID | État | Changement |
|---|---|---|
| R-E11 | Corrigé | `SpellTargeting._front_hero` : seul le premier héros de chaque entrée est ciblable (`EntranceQueue.Take(1)`), dans `enumerate_targets` et dans l'UI. |
| R-F10, R-F14 | Corrigé | Assassin et Fear : par R-E11. |
| R-F13 | Corrigé | Exhaustion : cibles par R-E11, mort différée par R-D46. |
| R-E30 | Corrigé | Revue de tous les choix du moteur : seul Hellcow (un seul donjon candidat, siège humain) gardait un choix ; l'APK inverse alors le donjon d'office (`RoomAbilities.rearrange_choice`). Les autres se résolvaient déjà seuls. Golden `_t_levelup_hellcow`. |
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
| R-E29 | Corrigé | `usedThisTurn` posé à l'exécution (R-D67). |

Non vérifié : R-D34, R-D35, R-E14, R-E18 et R-E19 portent sur des chemins que l'oracle ne joue presque pas ; seule l'absence de régression est prouvée.

## Lot 1b : IA (2026-10-26)

Validé par `python tools/run_godot_tests.py` (14/14) et l'oracle (6/6, 12/12, 6/6) ; stress graines 10 à 40, 2 à 4 joueurs : 90/93.

| ID | État | Changement |
|---|---|---|
| IA-H74 | Corrigé | Comme `RevealAllRoomCards` → `EnqueueAbilityTransaction`, la cible de chaque déclencheur de révélation est figée à la mise en file (`ApkAI.reveal_target`), avant tout effet et salles en attente exclues ; `ApkAI.choose` la rejoue (`apkPre`). Les cibles se figent dans l'ordre des sièges (`G.apkSeats`, posé par le harnais seulement), la file reste triée par PlayerId. Golden ajouté. |
| IA-H68, IA-H69, IA-O06 | Corrigé | Par IA-H74 : accord des cibles 832/853 → 849/853 (Mimic Vault 41/41, Specter's Sanctum 89/89). |
| — | Corrigé | `GameBoard.DestroyRoom` : la salle détruite est défaussée avant le déclencheur de Recycling Center, donc remélangée avec les défausses si la pioche est vide. Sans golden dédié. |
| Stress s16-p4 | Ouvert | Remélange des défausses non reproductible (l'ordre tiré n'est pas dans la trace). Sans lien avec IA-H74. |
| Stress s20-p2, s28-p3 | Ouvert | L'IA oracle active Dracolich Lair après la sortie du dernier héros, Godot a déjà fermé le tour. Sans lien avec IA-H74. |
| IA-G47 | Ouvert | L'oracle enregistre la décision d'avant la capacité : rien ne la mesure. |
| IA-H17 | Ouvert | Une seule trace (s30-p4 seq 306) ; lecture de `MaxBuildRoomLimit` à poursuivre. |
| IA-H23 | Ouvert | T.P.K. : dépend des cibles proposées par le moteur (décision de produit). |
| IA-H70 | Corrigé | Artefact du harnais (cible préréglée non mémorisée quand Godot a déjà fermé la phase BUILD) : le choix est compté non mesurable, `ApkParityTrace.gd`. |

## Lot 2 : plateau (2026-10-27)

Validé par `python tools/run_godot_tests.py` (14/14) et l'oracle (6/6, 12/12, 6/6 ; `CardDB.expanded_deck` porte maintenant une clé `art`). Captures Godot comparées aux frames de `docs/reference/apk_orig/` quand elles existent ; à 3-4 joueurs, aucune frame (verrou payant), seul le C# fait foi.

| ID | État | Changement |
|---|---|---|
| P-B23, P-B27, X-P22 | Corrigé (C#) | Vignettes adverses et panneau étendu à 3-4 joueurs ; COINS (Minibosses) dans le panneau étendu, pas dans les vignettes fermées. |
| P-C15, X-P09 | Corrigé | Zoom d'une pile de salles à l'échelle `AppearBehavior` (×1,3), environ 540 px comme la frame APK ; défilement `CarrouselVerticalComponent`. |
| P-B40 | Corrigé | Zoom du boss seul conforme à la frame LEVEL UP ; boss avec sorts gardés calculé d'après le C# (sans frame). |
| P-B47 | Corrigé (C#) | Zoom d'un héros de la file et diaporama de 3 héros. |
| P-C17 | Corrigé (C#) | Défausse en carrousel, salles puis sorts. |
| P-B54 | Corrigé (C#) | Cœur doré des dégâts modifiés et cœur de PV bonus (`health_hero_buff_icon`). |
| P-C06, P-C11 | Corrigé | La main se réécarte à la sélection et les cartes glissent vers leur place. |
| P-C07 | Partiel | Limite d'extraction y 797 portée ; le choix de la carte la plus proche parmi les cartes qui se chevauchent ne l'est pas. |
| P-C14 | Corrigé | Une seule carte sous la pile ; vol de la salle posée porté le 2026-10-28 (`DungeonSlot._fly_pending`). |
| P-C51 | Corrigé | Pulsation de PASS TURN après 5 s : 3 anneaux `halt_button_pulse`, 0,3 s d'écart, 2 s, échelle 0,9 → 1,3. |
| G-20 | Ouvert | Barre jaune sous DONE : asset `progress_yellow` présent dans l'APK (`Content/NinePatch/progress_yellow.wpk`), pas encore extrait ; n'existe qu'avec le délai de 70 s. |
| X-P03 | Corrigé | `GreenGlow`, particules et étincelles sur la salle source d'une capacité multi-cibles (`TargetResolverBaseSceneBehavior`) ; cibles en bordure jaune. Les choix en attente et les capacités à cible unique ne passent pas encore la salle source. |
| X-P02 | Corrigé | Bordures `_scaled` sur les petites cartes. |
| X-P06 | Ouvert | Asset `card_shadow` introuvable (ni dans l'APK extrait, ni dans le dépôt). |
| P-A45, P-B12 | Partiel | File de bulles par adversaire, ligne « AGAINST » et icônes de boss ; « IS PLAYING! » absent, « AGAINST » seulement quand `targetPlayerId` est explicite. |
| P-C24 | Corrigé | Bulle d'avertissement PASS : entrée animée, fermeture au clic extérieur, sans délai. |
| P-C47 | Corrigé | Ville : le plus récent en haut. |
| P-B43 | Corrigé | Lueur de niveau dessinée derrière le boss. Non vérifiée à l'écran. |
| P-C37, P-C42 | Corrigé | Survol d'un sort de la pile : bordure rouge sur le sort et cadre rouge sur sa cible. |
| X-M58 | Corrigé | Les doublons alternent l'art `a` et `b` (`CardDB`, `CardData`). |
| X-M06 | Ouvert | Décalage par boss présent dans `data.json`, sémantique des marges à mesurer sur des frames. |

Non vérifié : défilement du carrousel à la souris, clics dans l'interface 3-4 joueurs (méthodes appelées directement), lueur de niveau à l'écran.

## Lot 3 : menus, sons, entrées (2026-10-27)

Validé par `python tools/run_godot_tests.py` (14/14). Moteur de règles non touché.

| ID | État | Changement |
|---|---|---|
| U-A16 | Corrigé | Boîte « QUIT GAME? / ARE YOU SURE YOU WANT TO QUIT? » (CANCEL, QUIT), conforme à `apk_orig2/quit2.png`. |
| U-A42, U-A44 | Corrigé | Éventails de boss selon `ControlsFactory.BossCardsDeck` (2 à 4 cartes, ordre de superposition de l'APK) ; `ui_shuffle_left` / `ui_shuffle_right` selon le côté cliqué (sens déduit du C#). |
| U-A59 | Corrigé | La flèche de SETTINGS revient à OPTIONS sans fondu. |
| U-B09, U-B18, U-B21, U-B08, U-B24 | Corrigé | Galerie : fondu d'onglet 0,5 s + 0,5 s, défilement à inertie (×0,9, dépassement 100 px, ressort 0,4), détail 630×878, sons `ui_button_select` / `ui_button_goback`. Inertie non essayée à la souris. |
| U-B43, U-B44 | Corrigé | « + N NEW BOSSES » sous Player's Choice et Hidden Heroes (40 comme l'APK) ; fenêtre « ? » avec les textes `LocalMarket`. Les 3 lignes de Player's Choice se chevauchent comme dans l'APK (14 px). |
| U-A70 | Corrigé | « Wiki expansions » décochée par défaut (un profil qui l'a enregistrée cochée la garde). |
| A-28, U-C33 | Corrigé / Partiel | `ui_timer` retiré du compte à rebours de tour en ligne ; celui de l'attente de salle publique n'a pas d'écran où jouer (lot 4). |
| I-07 | Conforme | `CardHoverDetailBehavior` n'est instancié nulle part dans le C# : l'appui long de 1 s est fidèle. |
| I-11 | Corrigé | Échap = touche Retour Android : modale, puis flèche « Back » visible, sinon le plateau (pause → QUIT GAME? → pause) ; sans effet quand un LineEdit a le focus. À essayer dans un vrai navigateur. |
| A-10 | Corrigé | Musique en pause quand l'onglet est masqué (`visibilitychange`) ; hors web, perte de focus de l'application. À essayer dans un vrai navigateur. |

## Lot 4 : en ligne (2026-10-27)

Validé par `python tools/run_godot_tests.py` (14/14, dont `online` et `ui smoke` avec serveur réel et 3 clients). Moteur de règles non touché. Protocole : `lobby.seats[].left`, `state.plays` (8 derniers sorts / capacités joués, carte en clair), `leave` de l'hôte en salle d'attente transmis au prochain humain connecté (voir `PROTOCOL.md`).

| ID | État | Changement |
|---|---|---|
| N-A40, N-A41 | Corrigé | Départ d'un adversaire en partie : « X has left the game. », ou « You win by desertion. » (plus de 2 tours) / « No players to play with. » quand il ne reste aucun humain (`GamePlayMOScene.cs:96-119`) ; la défaite posée au départ est retirée en cas de victoire par désertion. |
| N-A05, N-B07 | Corrigé | « Reconnecting... » et la modale de session perdue existaient ; ajout de la modale « Connection problem » après 20 s de liaison coupée en partie. |
| N-B33 | Corrigé | Salle fermée : « Room closed », OK ramène à l'écran précédent. |
| U-C34 | Corrigé | Salle d'attente : plus de 10 s de liaison coupée → « NETWORK ERROR », OK ramène à l'écran précédent. Sans test dédié. |
| N-B12 | Corrigé | Bulle « IS PLAYING! » par adversaire attendu. |
| N-B24 | Corrigé | Bulles « HAS PLAYED A SPELL / ROOM ABILITY » pour les coups distants (`state.plays`). |
| N-B18 | Corrigé | Aventure en ligne au rythme de l'APK : pas de GO / PASS TURN, le héros avance après la barre de 3 s. |
| U-C29 | Corrigé | L'hôte qui quitte la salle d'attente passe le rôle au prochain humain connecté ; la salle ne ferme que s'il n'y en a plus. `GameRoom.join` ne vole plus le rôle d'hôte au siège 0. |
| U-C01, U-A34 | Corrigé (décision) | L'écran MULTIPLAYER garde ses deux fenêtres ; PASS AND PLAY devient PLAY WITH FRIENDS (salon privé par code, chacun dans son navigateur). Mode `pass` supprimé. |
| N-B15 (test) | Corrigé | `online_test._scenario_adventure_expiry` : deux humains en pause d'aventure, délai expiré : aucun siège en `auto`, un nouveau délai court, l'IA ne rejoue pas. |

Non porté : `OnErrorOccurred` (« Unexpected problem »), aucune erreur serveur n'étant fatale en partie. Non vérifié dans un vrai navigateur à plusieurs onglets : départs, bulles, coupures de plus de 10 s et 20 s, passage d'hôte.

Essai réel du 2026-10-27 sur le homelab (navigateur intégré, Chrome 152, deux onglets) : PLAY WITH FRIENDS → NEW GAME crée un salon privé à code, le second onglet le rejoint par ROOM CODE, la partie démarre pour les deux ; bulle « IS PLAYING! » ; Échap ouvre la pause (I-11) puis QUIT GAME? ; le départ du second joueur affiche chez l'hôte « No players to play with. The game will now end. », OK ramène au titre. Défaut trouvé et corrigé (`8f77b15`) : un départ reçu avant l'ouverture du plateau (onglet en arrière-plan) était ignoré. Non essayés : départ à 3 joueurs (« X has left the game. »), victoire par désertion, coupures de plus de 10 s et 20 s, passage d'hôte, bulles « HAS PLAYED A… », avance automatique de l'aventure.

| ID | État | Constat |
|---|---|---|
| W-19 | Corrigé (lot 5) | Nouveau, vu 3 fois sur le homelab : juste après TAP TO START, le premier clic sur MULTIPLAYER (et parfois sur l'écran suivant) est ignoré ; le second fonctionne. Cause non cherchée (transition d'écran qui avale le clic, ou focus du canvas). |


## Lot 5 : web (2026-10-27)

Validé par `python tools/run_godot_tests.py` (14/14). Moteur de règles non touché (pas d'oracle).

| ID | État | Changement |
|---|---|---|
| W-19 | Corrigé | Cause : le voile noir de `Main.go()` restait en `MOUSE_FILTER_STOP` pendant tout le fondu (1,0 s), y compris l'éclaircie où le nouvel écran est déjà visible. Après le changement d'écran, le voile laisse passer les clics. Écart assumé avec l'APK, qui refuse tout ordre pendant toute la transition. `ui_smoke` : un seul clic sur MULTIPLAYER pendant l'éclaircie ouvre l'écran. |
| W-05 | Corrigé | `head_include` ne remplace plus la classe `AudioContext` : quand `audioWorklet` manque (HTTP non sécurisé), il ajoute un `audioWorklet` factice et remplace `AudioWorkletNode` par un `GainNode` (Chrome expose le vrai `AudioWorkletNode` en HTTP, qui échouait sans module chargé). Avant, `new AudioWorkletNode` échouait et le son n'était jamais lancé. La position de lecture reste figée avec le faux nœud. |
| W-02 | Corrigé | Les 42 SFX étaient déjà préchargés dans `AudioManager._ready()` ; la musique de partie l'est aussi. Pas d'écran de chargement, textures des cartes non préchargées. |
| W-16 | Conforme (mesuré) | `AI.pick_move`, 6 parties à 4 joueurs, toutes extensions, 4 546 décisions : médiane 0,2 ms, p99 5,2 ms, max 9,9 ms en natif. En wasm (2 à 4 fois plus lent), environ 40 ms au pire : sous le seuil de 50 ms. Aucun changement. |
| W-08 | Corrigé | `index.wasm` 39,5 Mo → 10,1 Mo en gzip ; `index.pck` ne se compresse presque pas (39,4 → 38,5 Mo). Le homelab sert bien les `.gz` (`gzip_static`, bon `Content-Type`). Le `.pck` déployé fait 59,2 Mo, réduit de 4,2 Mo le 2026-10-28 (cartes du wiki redondantes retirées de l'export) ; le reste est de la texture déjà en WebP. |
| W-14 | Non vérifiable ici | `audio/driver/output_latency` par défaut ; la latence réelle du mode Sample dépend du Web Audio du navigateur. Écoute humaine nécessaire. |

Essai réel du 2026-10-27 sur le homelab en HTTP (navigateur intégré, panneau masqué, attentes de 6 s) : un seul clic sur TAP TO START puis un seul sur MULTIPLAYER ouvrent les écrans (W-19) ; plus aucune erreur `PositionWorklet` ni `AudioWorkletNode` dans la console en naviguant (W-05). Le son n'a pas été écouté.

## Restes des lots 1 et 2, règles et IA (2026-10-27)

Validé par `python tools/run_godot_tests.py` (14/14) ; oracle 6/6, 12/12, 6/6 ; stress (graines 10 à 40) 90/93, mêmes échecs connus ; `--ai-agreement` sur les 6 traces par défaut : usableSet 2050/2050, 0 mutation de l'état par les requêtes de l'IA.

| ID | État | Changement |
|---|---|---|
| X-M22 | Corrigé | Chaque salle et sort reçoit un `_uid` dans l'ordre du paquet avant mélange (`GetLogicCards`) ; tout ajout à `roomDiscard` / `spellDiscard` passe par `CardDB.discard_add`, qui trie la pile (`DiscardPile*.Sort()`). Non vérifié : l'ordre de la liste de cartes Godot égale-t-il celui de `CardInfo` hors harnais ; cartes wiki sans numéro APK. |
| IA-H17 | Corrigé | `_chk_050` compte les salles de la main que `Boss.CanBuildRoom` accepte, sans limite par tour (`MaxBuildRoomLimit` n'est jamais décrémenté à la pose). |
| IA-G47 | Corrigé (non mesurable) | La salle est choisie sur l'état d'avant la capacité, puis rejouée après elle si elle est toujours en main dans la même fenêtre. L'oracle ne mesure pas ce cas. |
| IA-H23 | Corrigé | T.P.K. : tout siège IA peut viser n'importe quel boss (l'APK retient le premier de `InGamePlayersPriorized`) ; un humain n'a toujours que lui-même. |
| R-E29 | Corrigé | `usedThisTurn` posé à l'exécution de la transaction (R-D67). |
| IA-H70 | Corrigé | Artefact du harnais établi (s21-p4@519) : la capacité tirée par l'oracle après le DONE n'est pas mesurable côté Godot ; compté « presetNotMeasurable ». |

## Restes du lot 2, plateau (2026-10-27)

Validé par `python tools/run_godot_tests.py` (14/14 ; un échec isolé de `soak APK decks` chez l'agent, non reproduit, à surveiller). Moteur de règles non touché.

| ID | État | Changement |
|---|---|---|
| G-20 | Corrigé | `progress_yellow` extrait de `Content/NinePatch/progress_yellow.wpk` ; barre de 177 px sous DONE, seulement avec le minuteur de tour (en ligne). Non portés : décalage de 2 px à l'appui, icône d'horloge. Barre non vue se vider en vraie partie. |
| X-P06 | Corrigé | `card_shadow` est un sprite de l'atlas INGAME (350x488, noir) : extrait ; ombre décalée de (40,70) à l'échelle 0,5, opacité 0,75, sous la carte glissée et sous la salle en attente. |
| X-M06 | Corrigé | Table `BOSS_OFFSET` des 15 boss de l'APK (`data.json`) ; sprites à leur taille native (KSA005 n'est plus réduit). Draculord et King Croak comparés à `apk_orig/adv_t8_full_state_…` : à quelques pixels. |
| P-C14 | Corrigé | La salle en attente a la taille de l'APK (175x244) et son ombre ; le vol vers l'emplacement est porté le 2026-10-28 (`DungeonSlot._fly_pending`). |
| P-C07 | Corrigé | Parmi les cartes de la main sous le pointeur, celle dont le centre est le plus proche gagne. Essayé par événements simulés, pas à la souris. |
| P-A45, P-B12 | Corrigé | « AGAINST » aussi quand le sort vise une salle, un héros ou un sort de la pile d'un adversaire. Sans ligne AGAINST : les effets sans cible nommée. |

## Lot 6a : règles et IA, écarts Basse (2026-10-27)

Validé par `python tools/run_godot_tests.py` (14/14), oracle APK 6/6, 12/12 et 6/6, `--ai-agreement` usableSet 2050/2050 avec 0 mutation de l'état Godot, stress graines 10-40 à 90/93 (échecs connus s16-p4, s20-p2, s28-p3).

| ID | État | Changement |
|---|---|---|
| R-O04 | Accepté | Trois échecs connus, causes documentées, non engine. |
| R-D03 | Accepté | Borne à 100 itérations, indiscernable. |
| R-D14 | Conforme | Déjà conforme : `CardDB.discard_add` trie à l'ajout (X-M22). |
| R-D15 | Accepté | Mélange non reproductible par conception. |
| R-D18 | Accepté | Masqué par l'oracle, effet seulement si la pioche s'épuise entre deux joueurs. |
| R-D19 | Accepté | Même cause que R-D18. |
| R-D49 | Accepté | Fenêtre de sorts non ouverte sur emplacement désactivé : cosmétique. |
| R-D53 | Accepté | Drapeau collant, écart seulement si les blessures baissent après élimination. |
| R-D54 | Accepté | Choix de conception (siège donné à l'IA). |
| R-D68 | Accepté | Ne change qu'un remélange pendant la bataille ; risque pour s16-p4, coût supérieur au gain. |
| R-D71 | Conforme | Conforme, remise à zéro équivalente. |
| R-D81 | Accepté | Tutoriel, renvoyé au module 8. |
| R-D82 | Corrigé | Code mort supprimé : `calculate_lure`, `advance_hero_in_dungeon`, signal `hero_adventured` (GameManager) et `_turn_order` (Match). |
| R-D90 | Accepté | Invisible sauf pioche de salles vide ; cause de s16-p4, laissé tel quel pour garder 90/93. |
| R-E02 | Conforme | Conforme. |
| R-E03 | Conforme | Conforme. |
| R-E04 | Accepté | Inutilisé dans les cartes APK. |
| R-E05 | Conforme | Conforme. |
| R-E10 | Accepté | Couvert indirectement par la trace 5C. |
| R-E15 | Accepté | Inutilisé dans les `data.json` APK. |
| R-E16 | Accepté | Couvert indirectement par la trace 5C. |
| R-E20 | Accepté | Inutilisé. |
| R-E22 | Accepté | Inutilisé. |
| R-E25 | Accepté | Inutilisé dans les `data.json` APK. |
| R-E28 | Conforme | Conforme, 0 écart. |
| R-F22 | Conforme | Conforme (lecture + golden). |
| R-F26 | Corrigé | Open Grave ne consomme `usedThisTurn` que s'il y a une salle en défausse (`Ability.CheckConditions` : cible minimale). Golden `_t_died_once_per_turn_needs_target`. |
| R-F30 | Corrigé | Vampire Bordello ne consomme `usedThisTurn` que s'il y a une blessure à soigner (même règle que R-F26). |
| R-F41 | Conforme | Conforme (lecture). |
| R-F59 | Conforme | Conforme (lecture). |
| R-F63 | Conforme | Conforme (lecture). |
| R-F68 | Conforme | Conforme (lecture). |
| R-F75 | Conforme | Conforme. |
| R-F76 | Accepté | Texte seul, jamais affiché ; renvoyé au module 11. |
| IA-O04 | Accepté | 99,8 %, écarts expliqués (IA-H14, IA-H17 corrigé, IA-H18). |
| IA-G08 | Conforme | Conforme, seul le flux aléatoire diffère. |
| IA-G12 | Accepté | Atteinte seulement par l'autoplay de debug. |
| IA-G19 | Accepté | Inatteignable. |
| IA-G27 | Accepté | Inatteignable. |
| IA-G44 | Accepté | Salles hors APK, facteurs vides. |
| IA-H14 | Accepté | Bogue APK volontairement non reproduit. |
| IA-H31 | Conforme | Conforme. |
| IA-H37 | Accepté | Bogue APK volontairement non reproduit en jeu. |
| IA-H47 | Accepté | Bogue APK volontairement non reproduit. |
| IA-H56 | Accepté | Aucun équivalent, rien d'observable. |
| IA-H61 | Accepté | Lu en surface, aucun écart observé à l'oracle. |
| IA-H63 | Accepté | Pas de chemin d'exception, voir IA-H37. |
| IA-H64 | Accepté | Cosmétique, module 7. |
| IA-H66 | Accepté | Même ordre en pratique. |
| IA-H67 | Accepté | Seul le harnais reproduit la course. |
| IA-H71 | Accepté | = IA-H14. |

## Lot 6b : plateau, écarts Basse (2026-10-27)

Validé par `python tools/run_godot_tests.py` (14/14) ; captures `docs/reference/apk_orig/` comparées avec `capture_screens.gd --only=lot6b` (engrenage, file d'entrée, horloge de la barre, cadres du panneau adverse, zoom de la ville). Non vérifiés à l'écran : cœur de soin, fondus, glissements, troncature des noms.

| ID | État | Changement |
|---|---|---|
| P-A05 | Accepté | Boutique supprimée : tous les boss sont jouables (code de verrouillage retiré par choix). |
| P-A06 | Accepté | `SPWins` ne sert qu'au déverrouillage, supprimé avec la boutique. |
| P-A07 | Corrigé | `_update_foe` suit le joueur actif hors aventure (hors ligne) : à 3-4 joueurs, son donjon passe en haut avant son tour (`GamePlaySPScene.CreateBeforePlayerInteractionTask`). |
| P-A08 | Corrigé | Changement d'adversaire : le donjon du haut s'estompe 0,5 s, change, puis réapparaît 0,5 s (`CreateChangeVisibleOpponentDungeon`). |
| P-A09 | Accepté | Architecture par état et non par tâches chaînées ; aucun écart observable, un portage littéral réécrirait la boucle de flux (moteur). |
| P-A12 | Accepté | Seul le chemin pass and play est touché : `GamePlayPaPScene` est mort côté APK (X-P23). |
| P-A13 | Accepté | Déverrouillage supprimé avec la boutique ; retour titre conservé. |
| P-A15 | Conforme | Conforme ; RULES en plus (ajout assumé). |
| P-A16 | Conforme | Conforme ; MASTER VOLUME en plus (ajout assumé). |
| P-A18 | Conforme | Déjà conforme : `_open_quit_confirm` reprend QUIT GAME? / CANCEL / QUIT ; la ligne était périmée. |
| P-A19 | Conforme | Déjà conforme : Échap ouvre la pause puis QUIT GAME? (`back_pressed`) ; la ligne était périmée. |
| P-A22 | Conforme | Conforme ; plaque BUILD estompée en `setup` / `boss` (choix voulu). |
| P-A25 | Conforme | Le carrousel de défausse existe (P-C17) ; `_win_paused` couvre zoom, glisser, ciblage et fenêtres ; l'horloge s'affiche (P-C29). |
| P-A32 | Accepté | Reprise par clic au lieu du glisser hors du donjon : même effet (`undoBuild`), geste non porté. |
| P-A34 | Corrigé | `_spell_drop` : tout relâchement au-dessus de la main joue le sort, colonnes latérales comprises (`PlaySpellsInHandSceneBehavior.MyHand_CardDropped`). |
| P-A35 | Conforme | Conforme ; bouton CANCEL en plus (ajout assumé). |
| P-A37 | Accepté | Le titre vient du message du moteur (une quinzaine d'appelants) ; la description de la carte n'est pas portée par les coups : nécessite le moteur. Contour vert de la source déjà présent (`SourceGlow`). |
| P-A41 | Corrigé | Un clic sur un héros de la ville le zoome à gauche (bord x 450, centre y borné 300-700, `_town_tap`) ; se ferme au clic suivant. |
| P-A50 | Conforme | Conforme ; barre PLAYER n en plus (ajout assumé). |
| P-A57 | Accepté | Code de debug mort dans l'APK. |
| P-B01 | Conforme | Déjà conforme depuis P-C24 : la bulle entre en 0,5 s et ne se ferme qu'au clic extérieur ; l'écriture progressive n'est utilisée que par le tutoriel APK. |
| P-B04 | Corrigé | Nom du boss tronqué à 10 caractères et sous-titre à 25, suivis de « ... » (`BossDetailHeaderControl.cs:71-72`, `_truncate`). |
| P-B08 | Corrigé | Icône du badge XP = `mp_icon_treasure_<premier trésor>` à l'échelle 0,9, centrée en (155 ; 21) du badge. |
| P-B10 | Corrigé | Compteur DAMAGE : ancien chiffre estompé 0,25 s puis nouveau en fondu 0,25 s à chaque changement (`_fade_text`), pas seulement pendant un pas de héros. |
| P-B21 | Corrigé | Un sort qui vise le boss adverse (2 joueurs) pose `challenger_panel_selected_red` autour du panneau (`_challenger_glow`, fondu 0,3 s). |
| P-B24 | Conforme | Déjà conforme : émetteur de particules sur la vignette du joueur actif (`_refresh_foe_bar`). |
| P-B25 | Conforme | Déjà conforme : `icon_death_profile` sur la vignette d'un boss éliminé (`_opp_front`). |
| P-B26 | Conforme | Déjà conforme : voile `topMask` sur les vignettes non choisies, nom en or, cadre jaune du joueur actif (`_opp_front`). |
| P-B29 | Conforme | Le sprite `bg_treasures_boss_profile` est noir (alpha 119) : la teinte de l'APK ne change rien de visible ; le fond sombre de Godot est équivalent. |
| P-B33 | Conforme | Barre jaune du bouton posée par G-20 (`_tick_done_bar`) ; le chiffre en haut est un ajout. |
| P-B39 | Conforme | Déjà conforme : `BOSS_OFFSET` (15 boss, X-M06) place le sprite selon `CharacterOffset`. |
| P-B52 | Corrigé | Soin d'un héros : cœur flottant avec le nombre sans signe (`HeartControlComponent.cs:43`), son `sfx_spell_buff` conservé. |
| P-B55 | Corrigé | Compteurs du panneau adverse (blessures, âmes, pioches) en fondu comme le panneau du joueur (`_fade_text`). |
| P-B57 | Accepté | Étoile du bandeau LEVEL UP invisible sur les frames APK (découpée par la couche scissor). |
| P-B65 | Corrigé | Même changement que P-A41 : le clic sur un héros de la ville zoome à gauche. |
| P-B68 | Corrigé | Engrenage = sprite APK `bt_options` / `bt_options_pressed` (extrait de l'atlas INGAME), zone de clic inchangée. |
| P-C03 | Corrigé | Position du zoom de la ville portée (P-A41) ; le verrou pendant une résolution n'est pas reproduit (le ciblage masque déjà le clic). |
| P-C09 | Accepté | Le survol retardé n'agit que dans le sélecteur ; il y est volontairement sans effet (seul le halo de sélection, capture tut_26). |
| P-C12 | Accepté | Pas de grossissement au survol : la capture APK contredit le C# (choix documenté, `docs/HANDOFF.md:116`). |
| P-C13 | Accepté | Le choix de N cartes demande des coups à sélection multiple : nécessite le moteur. |
| P-C18 | Accepté | Salle publique en ligne (lobby), hors plateau ; `CountDown.gd` sert de minuteur de tour. |
| P-C19 | Corrigé | Variantes `*_timer` du bouton quand une échéance existe, fondu 0,3 s (CubicEase) à chaque changement de variante visible (`_style_pass_button`). |
| P-C23 | Corrigé | File d'entrée : cartes suivantes à 0,9 (échelle 0,36 / 0,4), glissement de 0,5 s (CubicEase) quand les rangs changent. |
| P-C28 | Conforme | Diaporama = P-C17, corrigé (défausse en carrousel). |
| P-C29 | Corrigé | Horloge `timebar_clock` au bout de la barre pendant le ralentissement (0,2 s) ; la barre entre / sort en fondu de 0,2 s. |
| P-C31 | Accepté | Échange de deux cartes (Hellcow) : le moteur ne propose que des choix successifs (`RoomAbilities.gd:928`) : nécessite le moteur. |
| P-C32 | Accepté | Écran de chargement : Godot affiche le `boot_splash` (même image) pendant le vrai chargement ; un écran artificiel allongerait le démarrage. |
| P-C38 | Corrigé | Cartes déjà sur la pile : glissement de 0,3 s vers leur nouvelle place (`CardMoveBehavior`). |
| P-C41 | Corrigé | Barre de temps en fondu de 0,2 s (`ProgressBarEntity.FadeBehavior`). |
| P-C43 | Corrigé | La pile de sorts entre et sort en fondu de 0,1 s. |
| P-C44 | Conforme | Le titre du sélecteur est centré verticalement selon son nombre de lignes : équivalent des trois décalages de l'APK. |
| P-C45 | Accepté | Au clic de souris l'appui et le relâchement sont simultanés : l'écart n'existe qu'au tactile. |
| P-C52 | Conforme | Déjà conforme : `_pulse_rings` (4 anneaux) sur la bulle HAS PLAYED ; la ligne était périmée. |
| G-07 | Accepté | nécessite le moteur (données de cartes et règles, repris avec les règles). |
| G-17 | Accepté | Écran de chargement : le chargement web est celui du moteur ; un écran artificiel allongerait le démarrage. |
| G-18 | Accepté | Fond de chargement = `boot_splash` ; l'écran applicatif n'a rien à masquer (chargement à la demande). |
| G-21 | Accepté | Le ninepatch `settings_text_bg` (13 x 13) code ses marges dans des pixels de bord ; l'aplat mesuré (109, 99, 131) vient de la capture. |
| G-26 | Accepté | Poids 0,59 / 0,11 et facteur 0,62 calibrés sur les captures APK ; le `.frag` brut (0,3 / 0,55 / 0,15) n'inclut pas la teinte de scène. |
| G-31 | Accepté | Invisible à 1080p (échelle 1:1) ; un filtre global casserait les cartes (LinearClamp). |
| X-P01 | Accepté | La main est reconstruite à chaque `refresh` : un fondu repartirait de zéro à chaque rafraîchissement. |
| X-P04 | Corrigé | `challenger_panel_selected_yellow` (cible possible) et `_red` (touché) autour du panneau adverse, position (1693 ; 48), fondu 0,3 s. |
| X-P05 | Conforme | Déjà conforme : cadre `bg_boss_profile_selected_yellow` sur la vignette du joueur actif ou ciblée (`_opp_front`, `_foe_mark`). |
| X-P07 | Accepté | Inclinaison en perspective 3D : le rendu 2D de Godot n'a pas de perspective (largeur × cos de l'angle). |
| X-P14 | Conforme | Déjà conforme : `_tick_pulse` relance `halt_button_pulse` toutes les 5 s sur PASS TURN / DONE. |
| X-P21 | Corrigé | Textes des compteurs en fondu (`_fade_text`) : DAMAGE, blessures, âmes et pioches adverses, nom et sous-titre du boss adverse. |
| X-P23 | Accepté | Chemin atteignable seulement par `MultiplayerScene`, mort côté APK. |
| X-P26 | Conforme | Déjà conforme : chaque couloir est un `clip_contents` (`LANE_Y` 62 / 497, hauteurs 435 / 455) ; la ligne était périmée. |
| X-P29 | Conforme | Mécanisme équivalent ; GreenGlow (`SourceGlow`) et cadres des panneaux adverses présents. |
| X-P32 | Corrigé | Même correctif que P-B04 (`Truncate`). |
| X-P33 | Accepté | Plateau en 1920 x 1080 fixe : étendre la zone utile demande de refaire les ancrages de toute l'interface. |
| X-P35 | Accepté | Teintes de trésor sans effet visible (sprite noir) ; or et pistache identiques à l'APK. |
| X-P38 | Conforme | Le choix de pioche (Haunted Library, `draw-type`) passe par la fenêtre générique `pendingChoice` ; non exercé en capture. |

## Écarts Moyenne restants, règles et IA (2026-10-27)

Validé par `python tools/run_godot_tests.py` (14/14) ; oracle 6/6, 12/12, 6/6 ; stress (graines 10 à 40) 90/93, mêmes échecs connus (s16-p4, s20-p2, s28-p3), aucun corrigé ; `--ai-agreement` sur les 6 traces par défaut : usableSet 2050/2050, 0 mutation de l'état par les requêtes de l'IA.

| ID | État | Changement |
|---|---|---|
| R-O05 | Accepté | Mesure de couverture, pas une règle. Les cartes jamais exercées par les 24 traces ne sont pas atteignables par l'IA de l'APK (Teleportation : `CheckBMA053` ne la joue jamais ; BMA023, BMA033, THK025 jamais distribuées ou injouables) ou n'ont pas été tirées ; leur comportement est couvert par les goldens (BMA053 7 références, BMA025 9, KSA001 4, KSA005 6, THK021 12, THK025 16). |
| R-D25 | Conforme | Déjà porté avec R-D26 et R-D27 : `buildLimit` n'est effacé que quand le joueur cesse d'être actif (`_advance_build`, équivalent de `DeactivateLastActivePlayer`) et pour tous au début de l'aventure (`ChooseNextActivePlayer`, `_init_adventure_phase`). Une limite posée hors tour est donc gardée jusqu'à la fin du tour de construction du joueur, comme dans l'APK. |
| R-D47 | Corrigé | `ProccessActiveHero` retire le héros à hp <= 0 avant la fenêtre de sorts. `SpellTargeting.hero_dead_in_window` : en pause « post-damage », hors `dealZero` (DealHero ne teste pas la mort, R-D46), un héros à 0 PV n'est plus ciblable ni « héros actif » (Assassin ne peut plus le ressusciter) ; le héros suivant de l'entrée l'est. Golden `_t_apk_dead_hero_untargetable_in_window`. |
| R-D67 | Corrigé | Voir la section « R-D67 : capacités de salle en bataille de sorts » ci-dessous. Toute capacité activée (11 du jeu de base, THK, RMB, TNL, CRL) est une entrée de pile ; les capacités à déclencheur restent immédiates (l'APK ne les met pas en bataille : `IsActivatedByUser` = `Trigger == null`). |
| R-E26 | Corrigé | Même correction que R-D67 : les capacités de salle suivent l'ordre `_stack_insert_index` ; All-Seeing Eye reste immédiate (sa transaction passe devant le sort visé). |
| R-E17 | Corrigé | `Ability.DoEffect` ne reverifie pas les conditions : elles sont testées à la mise en jeu (`Spell.CanPlayerPlayAbility`, `SpellTargeting.conditions_ok`), puis la transaction s'exécute. `_motivation` ne reverifie plus `OpponnentDungeonSizeMoreThan` : la construction supplémentaire est accordée même si l'écart a disparu entre-temps. Golden dans `_t_spell_motivation_extra_build`. |
| R-E27 | Corrigé | `RemovePendingTransactionsByTarget` : une transaction retient la carte visée (salle du sommet de l'emplacement, héros de la ville) par un `_tuid` (compteur statique de `Match`, qui ne consomme pas le tirage global). À la résolution, `_retarget_stack_effect` retrouve la carte (les indices glissent après `DestroyRoom`) ou annule le sort si elle a quitté le jeu. Non couvert : les cibles par indice d'âme ou de blessure (`soulIndex`, `woundIndex`). Golden `_t_apk_stack_target_leaves_game`. |
| R-E31 | Conforme | `OnAbilityApplyDone` ne déclenche que `YouPlaySpellCard` (Liger's Den, appliqué après le sort non annulé dans `_resolve_pending_stack`) ; `WhenOpponentPlaysSpellCard` et `AnySpellCardIsPlayed` n'existent sur aucune carte des `data.json`. `IUntilEndOfGameCommand` ne concerne que KSA013 T.P.K., porté à part. |
| R-F18 | Conforme | Durée (R-D26), sorts de construction non bloqués (R-E18) et `SkipBuildPhase` limité à `BuildPhase_a` : conforme. Détail : la salle rendue à la main perd aussi sa marque `undoBuild`. |
| R-F19 | Conforme | Report au tour suivant corrigé (R-D27) ; la condition n'est plus reverifiée à la résolution (R-E17). Oracle 6 sur 6. |
| IA-O08 | Accepté | Mesuré à nouveau sur le stress (93 traces, 45238 requêtes) : 134 écarts. 120 sont dans s16-p4 et s20-p2 (états déjà divergents). Les 14 restants sont isolés (0,03 %). Corrigé en route : pendant une Spell Battle, `active_entrance_hero` prenait le répondant courant pour le joueur actif (Teleportation jouable côté Godot seulement : 12 cas devenus 3). Cause non établie pour les 14 cas restants (Freeze et Giant Size dans la fenêtre qui suit la mort d'un héros, un Dark Altar au tour 1). Aucun REFUS ni écart d'état dans ces traces : seuls les ensembles de coups légaux diffèrent, à des instants où l'oracle est entre deux étapes. |
| IA-H18 | Corrigé | Cause : `room_damage_with_modifiers` laissait une salle posée ce tour (face cachée, `PendingToBeBuilt`) donner son bonus passif à ses voisines (Dizzygas +2 à la salle Trap suivante), alors que `Boss.GetPassiveDamage` ne parcourt que `DungeonActiveRooms`. L'IA surestimait les dégâts de son donjon en phase de construction (s26-p4 : Open Grave 4 au lieu de 2) et jugeait Princess in Peril éligible. |
| IA-H60 | Corrigé | `BoardUI` donne à une IA hors tour la fenêtre d'avant l'entrée du héros (aucun héros en cours, pile vide) : une capacité tirée par `ApkAI.abilities`, une fois par fenêtre (`AI._window_key` contient le joueur actif), jamais un sort hors APK ni un coup nocif. Boucle d'affichage seulement : l'oracle ne la mesure pas ; non vérifié en partie. |
| G-07 | Corrigé | Les 41 `description` des héros hidden-heroes de `cards.json` sont vidées (le `Description` de l'APK est vide, le texte est imprimé sur l'image ; aucun lecteur ne les affichait). |
| P-A37 | Accepté | Le titre vient du message du moteur (une trentaine de sites de `RoomAbilities.gd`) ; l'état ne porte pas la carte source du choix, donc pas sa description. Sans effet sur les règles. Contour vert de la source déjà présent (`SourceGlow`). |
| P-C13 | Accepté | Le moteur propose N choix successifs d'une carte : le résultat est le même que le choix de N cartes d'un coup, seule la présentation diffère. Le nombre N n'est pas dans l'état du choix. |
| P-C31 | Accepté | Hellcow : échanger deux cartes revient à deux choix successifs (`RoomAbilities.gd:928`) ; même résultat, présentation différente. |

## Écarts Moyenne restants, plateau et tutoriel (2026-10-27)

Validé par `python tools/run_godot_tests.py` (14/14) ; captures `capture_screens.gd --only=plateau_tuto` (défausse d'ouverture animée) et `--only=tutorial` (29 vues, les 19 étapes s'affichent) comparées à `apk_orig2/tut_26` ; animations vérifiées sur captures espacées dans le temps, pas sur trace APK (aucune vidéo).

| ID | État | Changement |
|---|---|---|
| P-C01 | Corrigé | La défausse d'ouverture n'apparaît plus d'un coup : `_disc_intro` fait arriver la carte k depuis le bas de l'écran quand `CubicEase(t / 1 s)` dépasse k / n (`AddCarouselCardsBehavior.cs:76-104`), avec `ui_card_slide_general` à chaque carte. L'état survit aux reconstructions de la main (`_disc_*`). Sans animations (tests), tout est posé d'emblée. |
| P-C10 | Corrigé | Main triée salles puis sorts, tri stable (`CardManagerComponent.cs:116`), dans l'éventail comme dans la défausse d'ouverture. Seul l'affichage change : les coups gardent l'indice du moteur, le survol passe par le rang trié. `ui_smoke` vérifie désormais l'éventail dans cet ordre. |
| P-C16 | Corrigé | Fond en fondu de 0,1 s (bulle et texte), cartes ajoutées 0,5 s après (`CarouselSelectorShowComponent.cs:48-49`). |
| P-C27 | Corrigé | Le bandeau de la défausse s'ouvre en 0,5 s, hauteur 0 → 1, CubicEase InOut (`_disc_open`, `MiddleCarouselAnimationBehavior.cs`). Opacité gardée à 0,88 : valeur mesurée sur la capture APK (le panneau 0,8 se superpose à un voile), la valeur du code seule serait plus claire. |
| X-P17 | Corrigé | Le cœur de buff `health_hero_buff_icon` existait déjà sur les cartes d'entrée (`CardUI.add_heart`, `BoardUI._create_entrance_card`) : la ligne était périmée (l'asset est dans `assets/ui/ingame/`). Il manquait le zoom d'un héros aux PV gagnés : `UiKit.zoom_card` l'ajoute. Cœur de PV en donjon et cœur « −N » déjà fidèles. |
| X-P48 | Conforme | Tous les sprites cités sont présents (`card_shadow` et `health_hero_buff_icon` aussi, sous `assets/ui/ingame/`) et utilisés (`challenger_panel_selected_*`, `bg_boss_profile_selected_*`, `card_border_green_glow` le sont dans `BoardUI.gd`). Les enums de sprites n'ont pas d'équivalent Godot : le chemin du fichier tient lieu de valeur. |
| T-A07 | Accepté | Le tirage de l'APK est reproductible (`DBMRandom`, générateur de Knuth portable), la ligne le disait à tort. Mais l'identité des pioches suppose les mêmes mélanges dans le même ordre d'appel que `GameBoard.InternalInititalizeGameBoard`, et l'IA scriptée `FixedAI` : cela passe par le moteur de règles (`Match.gd`, `ApkAI.gd`), hors périmètre de ce lot. Seules les pioches imposées sont identiques ; le hasard du tutoriel est fixe (`TUT_SEED`). |
| T-A31 | Accepté | Choix défensif conservé (sauter une étape dont la condition n'arrive pas plutôt que bloquer). Le déroulé est déterministe (pioches imposées + graine fixe) : la capture `--only=tutorial` et `ui_smoke` montrent les 19 étapes, p25, p26, p28 et p29 comprises. Faire coller l'IA à `FixedAI` relève du moteur. |
| T-B18 | Corrigé | Bulle `BossHint` du sélecteur : entrée en 0,5 s (opacité 0,5 → 1, échelle 0,7 → 1, CubicEase InOut), plus de minuterie de 6 s, fermée seulement par un appui hors de la bulle une fois entrée, avec fondu de sortie de 0,5 s (`HideWhenTouchBehavior.cs`). Logique de choix déjà identique. |

## Lot 6c : menus, écarts Basse (2026-10-27)

Validé par `python tools/run_godot_tests.py` (14/14) ; captures `capture_screens.gd --only=lot6c` comparées à `13_setup_2p.png` (joueurs) et aux captures APK de menu, réglages, extensions et galerie. 83 lignes : 38 Corrigé, 16 Conforme, 29 Accepté.

| ID | État | Changement |
|---|---|---|
| U-A01 | Accepté | Choix du port web : 1920x1080 `keep_aspect`, décalage de 240 px. |
| U-A02 | Accepté | Boutique, déblocages et mécènes retirés (décision produit). |
| U-A04 | Accepté | Écran de chargement : sur le web, c'est le démarrage du moteur. |
| U-A05 | Accepté | Écran de chargement : sur le web, c'est le démarrage du moteur. |
| U-A06 | Corrigé | Fondu noir de 0,5 s (1 vers 0) à l'arrivée sur le titre, voile ignorant la souris (`Main._ready`). |
| U-A07 | Accepté | Sans objet dans un navigateur (pas de sortie de l'application). |
| U-A15 | Accepté | Sans objet dans un navigateur (pas de sortie de l'application). |
| U-A17 | Accepté | Multijoueur par salles seulement : PASS AND PLAY remplacé par PLAY WITH FRIENDS (décision produit). |
| U-A19 | Corrigé | Le son des boutons part à l'appui (`button_down`) dans `Main._img_btn`/`_hit`/`_confirm_box`, `UiKit.stone_button`, `OnlineMenus`. |
| U-A20 | Corrigé | `stone_button` : le bouton reste enfoncé après le clic si la souris est dedans (StayPressed) ; les boutons retour et OK ne restent pas enfoncés. `unpress` rend l'état repos au retour de la galerie. |
| U-A21 | Corrigé | Glissé hors du bouton : texte et icône à base − 3 px, comme l'APK (`_stone_btn`). |
| U-A26 | Corrigé | Scintillement des torches supprimé : torches statiques. |
| U-A27 | Corrigé | `_apk_screen` dessine `gradients/logo_small.webp` (688x318) en (616, 10) sur tous les écrans de menu (pixel identique à la capture APK). |
| U-A28 | Accepté | Boutique, déblocages et mécènes retirés (décision produit). |
| U-A33 | Corrigé | Texte décalé de 3 px à l'appui, seulement sur les boutons `bt_apply_effects` (OK des boîtes de message et de confirmation), pas sur les boutons pierre d'OPTIONS (`shiftTextWhenPressed`). |
| U-A36 | Accepté | Boutique, déblocages et mécènes retirés (décision produit). |
| U-A37 | Accepté | Boutique, déblocages et mécènes retirés (décision produit). |
| U-A43 | Corrigé | `_draw_fans(animate)` : glissement 0,35 s, échelle 0,7 vers 1 en 0,3 s, chiffres latéraux en fondu 0,1 s, éventails sortants réduits vers le centre. |
| U-A45 | Corrigé | Chiffre central en arcadepix 63 px (`FONT_A`), comparé à `13_setup_2p.png`. |
| U-A46 | Corrigé | `show_solo_count` remet 2 joueurs à chaque entrée ; le retour depuis les extensions garde le choix (`keep`). |
| U-A47 | Accepté | Boutique, déblocages et mécènes retirés (décision produit). |
| U-A48 | Conforme | Ajout Godot assumé, aucun écart avec l'APK. |
| U-A53 | Corrigé | CREDITS : logo en fondu 0,5 s, boutons en fondu 0,3 s puis glissés de 50 px (BackEase In 0,2 s) ; au retour, cascade 0 / 0,1 / 0,2 / 0,3 s (fondu 0,3 s, glissement 0,2 s, BackEase Out). |
| U-A56 | Corrigé | Ninepatch `settings_text_bg` (extrait de l'APK), segments de 204 px, bulle `settings_bt` 204x110, police x1,4 (`UiKit.draw_toggle`, partagé par OPTIONS et le menu en jeu). |
| U-A57 | Corrigé | Valeur choisie : texte doré décalé de −5 px sur le texte blanc. |
| U-A58 | Corrigé | Son à l'appui, et seulement si l'option change. |
| U-A60 | Accepté | Boutique, déblocages et mécènes retirés (décision produit). |
| U-A67 | Corrigé | `GameOverBanner._place` : interpolation en corde entre les sommets du décagone, 1 s par cran. |
| U-A68 | Conforme | Ajout Godot assumé, aucun écart avec l'APK. |
| U-A69 | Conforme | Ajout Godot assumé, aucun écart avec l'APK. |
| U-A71 | Conforme | Ajout Godot assumé, aucun écart avec l'APK. |
| U-A72 | Conforme | Ajout Godot assumé, aucun écart avec l'APK. |
| U-B03 | Corrigé | `InGameMenu.show_gallery` faux en ligne : pas de CARD GALLERY, les boutons montent d'un cran comme dans `PauseScene`. |
| U-B07 | Corrigé | Défilement vertical des onglets sur mesure : course de 596 px, dépassement de 100 px, ressort 0,4 et inertie 0,1 (`CardGallery._input`/`_process`), molette conservée. |
| U-B10 | Corrigé | Onglet : taille 153x213 contre 135x188 en 0,2 s (CubicEase In), cadre jaune en fondu 0,5 s, ancien cadre effacé en 0,5 s. |
| U-B11 | Corrigé | BOSS sélectionné à l'ouverture avec cadre en fondu (`GalleryScene.Start : SetSelected(0)`). |
| U-B13 | Conforme | Ajout Godot assumé, aucun écart avec l'APK. |
| U-B19 | Conforme | Ajout Godot assumé, aucun écart avec l'APK. |
| U-B20 | Corrigé | Carte : 0,8 vers 0,85 en 0,2 s, cadre en fondu, sélection gardée par onglet (`_sel_idx`). |
| U-B22 | Corrigé | Détail : voile 0,7 immédiat, cadre = sprite `card_border_yellow` en fondu 0,3 s. |
| U-B25 | Corrigé | Détail : flèche de retour au-dessus du voile, tap sur le fond ferme, retour animé 0,2 s. |
| U-B27 | Conforme | Ajout Godot assumé, aucun écart avec l'APK. |
| U-B30 | Corrigé | Citations de `CardGallery.gd` remises sur les bonnes lignes de l'APK. |
| U-B32 | Accepté | Multijoueur par salles seulement : PASS AND PLAY remplacé par PLAY WITH FRIENDS (décision produit). |
| U-B34 | Corrigé | Écrans en ligne sur `multiplayer_bg.webp`, sans torches (`_apk_screen(back, online)`). |
| U-B36 | Corrigé | Tuile POWER-UP PACK ajoutée en tête (COMING SOON) ; la tuile du jeu de base est retirée (B46). |
| U-B37 | Corrigé | Power-Up Pack : bande `coming_soon_band`, illustration grisée, ni sélection ni « ? ». |
| U-B38 | Corrigé | Tools of Hero Kind : COMING SOON et grisé tant que la case wiki est décochée ; jouable avec la case. |
| U-B39 | Accepté | Achat retiré : la tuile reste sélectionnable ; le texte de détail reste celui de l'APK. |
| U-B40 | Accepté | Boutique, déblocages et mécènes retirés (décision produit). |
| U-B41 | Corrigé | Tuile choisie : échelle 1,0 vers 1,1 en 0,3 s (CubicEase InOut), aucun son. |
| U-B42 | Corrigé | Tuiles alignées à gauche (centre 455, pas 331, taille réelle), glissement horizontal avec inertie dès 4 tuiles. Détails des tuiles : police arcadepix x1 (19 px) comme l'APK (`PurchaseDetailEntity`, capitales de 14 px, `+40 NEW HEROES` mesuré à y 760 à 773 sur `apk_orig2/mp_newgame.png`) ; pas de lignes porté de 14 à 17 px car les 3 lignes de The Player's Choice, jointives à 14, se chevauchaient (aucune capture APK ne les montre) ; la « ? » (ajout hors APK) est descendue sous les lignes. |
| U-B46 | Corrigé | Tuile BOSS MONSTER retirée (le jeu de base est toujours présent). |
| U-B47 | Conforme | Ajout Godot assumé, aucun écart avec l'APK. |
| U-B48 | Conforme | Ajout Godot assumé, aucun écart avec l'APK. |
| U-B49 | Conforme | Ajout Godot assumé, aucun écart avec l'APK. |
| U-B50 | Accepté | Boutique, déblocages et mécènes retirés (décision produit). |
| U-B51 | Accepté | Boutique, déblocages et mécènes retirés (décision produit). |
| U-B52 | Accepté | Boutique, déblocages et mécènes retirés (décision produit). |
| U-B53 | Accepté | Boutique, déblocages et mécènes retirés (décision produit). |
| U-C02 | Corrigé | `Profile.has_profile` exige un pseudo non vide, comme `MainMenuScene` (`UserName != null && != string.Empty`). |
| U-C04 | Accepté | Multijoueur par salles seulement : PASS AND PLAY remplacé par PLAY WITH FRIENDS (décision produit). |
| U-C07 | Accepté | L'écran parent est PLAY ONLINE / PLAY WITH FRIENDS (décision produit). |
| U-C08 | Accepté | Pas d'appariement public automatique : salles listées avec code ; le décompte de tour réutilise `CountDown`. |
| U-C11 | Corrigé | Après une erreur de création ou de jonction, retour sur SELECT EXPANSIONS (`show_setup`) comme `ExpansionScene.GoToNexScene`. |
| U-C13 | Corrigé | Saisie du code sans limite de longueur ni mise en majuscules. |
| U-C14 | Corrigé | Codes de salle de 4 caractères a-z 1-9 en minuscules, sensibles à la casse (`Server.gd`, `OnlineClient.gd`, PROTOCOL.md, test `online`). |
| U-C16 | Accepté | Boutique, déblocages et mécènes retirés (décision produit). |
| U-C19 | Corrigé | Le pseudo n'est plus rogné : seul un pseudo vide n'enregistre rien ; tronqué à 45. |
| U-C20 | Accepté | Boutique, déblocages et mécènes retirés (décision produit). |
| U-C21 | Accepté | Boutique, déblocages et mécènes retirés (décision produit). |
| U-C23 | Accepté | L'écran parent est PLAY ONLINE / PLAY WITH FRIENDS (décision produit). |
| U-C25 | Corrigé | Commentaire `OnlineMenus` corrigé : l'APK dore le mécène, Godot dore l'hôte (ajout assumé, plus de mécènes). |
| U-C28 | Corrigé | Le serveur ne lance plus la partie à la salle pleine : l'hôte appuie sur OK (`start`). Hôte seul avec des IA : démarrage immédiat. PROTOCOL.md et tests `online` / `ui_smoke` mis à jour. |
| U-C30 | Accepté | Pas d'appariement public automatique : salles listées avec code ; le décompte de tour réutilise `CountDown`. |
| U-C31 | Accepté | Pas d'appariement public automatique : salles listées avec code ; le décompte de tour réutilise `CountDown`. |
| U-C32 | Accepté | Pas d'appariement public automatique : salles listées avec code ; le décompte de tour réutilise `CountDown`. |
| U-C35 | Corrigé | Textes « Unable to join public room » et « Room is full ». |
| U-C36 | Conforme | Ajout Godot assumé, aucun écart avec l'APK. |
| U-C37 | Conforme | Ajout Godot assumé, aucun écart avec l'APK. |
| U-C38 | Conforme | Ajout Godot assumé, aucun écart avec l'APK. |
| U-C39 | Conforme | Ajout Godot assumé, aucun écart avec l'APK. |
| U-C40 | Conforme | Ajout Godot assumé, aucun écart avec l'APK. |

## R-D67 : capacités de salle en bataille de sorts (2026-10-27)

Validé par `python tools/run_godot_tests.py` (14/14, goldens 2148) ; oracle 6/6, 12/12, 6/6 ; stress (graines 10 à 40) 90/93, mêmes échecs connus (s16-p4, s20-p2, s28-p3) ; `--ai-agreement` : usableSet 2121/2121, 0 mutation de l'état par les requêtes de l'IA.

APK : `GameBoard.PlayRoomAbility` met la capacité en file (`EnqueueAbilityTransaction`) ; `IsActivatedByUser` (`Trigger == null`) ouvre une Spell Battle (`OnAbilityApplyRequest` : tous les joueurs vivants peuvent répondre). Le joueur du tour passe en tête de file, les autres par rang de joueur ; la transaction s'exécute au `NextStep` (`DoEffect`, sans revérifier les conditions) ; `OncePerTurn` (`IsEffectApplied`) n'est posé qu'à l'exécution. `Room.CanPlayerPlayAbility` refuse une salle déjà en file. `RemovePendingTransactionsByTarget` annule la transaction dont une cible quitte le jeu. L'IA qui répond ne considère que Counterspell et All-Seeing Eye, et ne vise que des sorts : elle laisse donc passer toute capacité de salle.

Changements :
- `Match.gd` : le coup `activateRoom` (sauf BMA025) crée une entrée de pile `type: "ability"` (`RoomAbilities.make_entry`, salle retrouvée par `_tuid`), relance la fenêtre de réponse comme un sort et se résout dans `_resolve_pending_stack`. Si la capacité ouvre un choix, la pile attend (entrée `resolving`) puis reprend dans `_resolve_choice_body`. Une salle en file n'est plus activable (`RoomAbilities.is_queued`).
- `RoomAbilities.gd` : `run_queued` (salle détruite ou recouverte : annulée, sauf Dracolich Lair et Witch's Kitchen qui ne ciblent pas leur salle) ; `activate_room_ability(..., queued)` ne revérifie plus les conditions à l'exécution ; une exécution qui échoue ne consomme pas `OncePerTurn`.
- `BoardUI.gd` : la capacité s'affiche comme l'APK (carte de la salle à l'échelle 1, portrait du boss, même pour la mienne). `PROTOCOL.md` : entrée de pile `ability`. `ViewFilter` : aucune clé ajoutée.
- `ApkParityTrace.gd` : l'émulation `_held` d'activation est remplacée par la pile réelle ; les décisions de cibles de l'oracle, journalisées à la mise en file, résolvent tout de suite les choix de ciblage de Godot ; il ne retient plus que la dernière passe jusqu'au step de phase. Les cibles de main périmées (Dracolich Lair, Witch's Kitchen) annulent l'entrée.
- Goldens : capacité sans réponse, annulée par le sort du joueur du tour (`OncePerTurn` non consommé), salle détruite en réponse.

Cibles à la mise en file (`AbilityTransaction.ResolveTargets`, avant `OnAbilityApplyRequest`) :
- `Match._advance_targeting` rejoue la capacité sur une copie de l'état ; le prochain choix ouvert est présenté à l'activateur (humain ou IA) avec `targeting: true`, les choix déjà faits sont mémorisés par signature (`_opt_sig` : `_uid` / `_oid` de l'instance, sinon id et nom, indices exclus) dans `picks`. Sans autre choix, l'entrée entre dans la pile. Rien du vrai état n'est touché avant l'exécution.
- Les adversaires voient l'entrée avec sa cible publique (`target`, salle visée) ; `picks` (cartes de la main comprises) reste au siège de l'activateur (`ViewFilter`).
- À l'exécution (`_run_ability_entry`, `AbilityTransaction.Run`) : le rejeu sur une copie vérifie que chaque cible existe encore ; sinon la transaction est annulée sans effet et sans consommer `OncePerTurn` (`GameBoard.cs` 606 `DiscardCard` et 618 pour une carte de main, 843 `DestroyRoom`, tous suivis de `RemovePendingTransactionsByTarget` 1351-1358, qui annule toute transaction `TargetsResolved` contenant la cible).
- Choix laissé à l'exécution : `uncover-room` / `uncover-own-room` (CRL), conséquence d'une destruction que l'APK ne connaît pas (extension wiki, aucun C# à citer).

Dracolich Lair (BMA013) et Witch's Kitchen (BMA024) s'exécutent même salle détruite ou recouverte : leurs cibles (`data.json` 1344-1390 : `RoomInHand`, `RoomInDeck` de la défausse, `BossOwner` ; BMA024 : `RoomInHand`, `BossOwner`) ne contiennent pas la salle, donc `RemovePendingTransactionsByTarget` ne les touche pas, et `Ability.DoEffect` ne revérifie pas les conditions. `RoomAbilities.run_queued` les appelle directement dans ce cas. Les autres capacités visent leur propre salle (`ThisRoom`) : annulées si elle est détruite.

Golden : `_t_apk_room_ability_target_seen_by_opponent` (cible choisie à la mise en file ; l'adversaire voit l'entrée ; sans réponse c'est la cible choisie qui est défaussée ; Jeopardy en réponse la fait quitter la main, transaction annulée, `OncePerTurn` intact).

Écarts connus : All-Seeing Eye reste immédiate ; les coups wiki sans équivalent APK (`useItem`, `useHandRoom`, RMB `activateMiniboss`, TNL `docScarecrow`) restent immédiats. Non vérifié : parties en ligne réelles et interface humaine (suites `online` et `ui smoke` seulement).

## Lot 6d : en ligne, écarts Basse (2026-10-27)

Validé par `python tools/run_godot_tests.py` (14/14) ; `online_test.gd` (`_scenario_version`, `_scenario_away`, `_scenario_abandon`, `_check_stack_and_boss_picks`) et `ui_smoke.gd` (`online_link_lost_waiting`, `online_version_mismatch`, `online_pause_no_gallery`). Aucun changement de moteur (Match.gd, BossEngine, IA) : l'oracle APK n'est pas concerné. Non vérifié : jeu réel à deux navigateurs (l'écouteur `pagehide` et la reprise après rechargement ne sont testés qu'en processus, hors export web). Abréviations : OC = scripts/OnlineClient.gd, OM = scripts/OnlineMenus.gd, SV = server/Server.gd, GR = server/GameRoom.gd, VF = server/ViewFilter.gd, BUI = scripts/BoardUI.gd, CD = scripts/CountDown.gd.

32 lignes : 6 Corrigé (dont N-B39, fait au lot 6c), 15 Conforme, 11 Accepté.

| ID | État | Preuve |
|---|---|---|
| N-A15 | Conforme | L'APK ne lit `ConnectionState` que pour trois choses : ne pas ouvrir « NETWORK ERROR » pendant `Connecting` (WaitingRoomBaseScene.cs:56), refuser `SendGameInitialization` hors ligne (WRB:109) et forcer la vitesse en partie (GameSettings.cs:49). Godot a les trois : liaison rouverte seule et modale seulement après `WAIT_LINK_GRACE_S` (OM:841-847), l'hôte ne démarre qu'avec une liaison ouverte (`_send` refuse si la liaison est fermée, OC:188), vitesse forcée à 0,5 en ligne (BUI:1077-1079). Aucun écran de l'APK n'affiche l'état : pas d'énumération à porter. |
| N-A17 | Conforme | `Connecting` n'a qu'un lecteur dans l'APK, WRB:56, qui SUPPRIME la modale. Godot : même effet (OM:841-847, `_on_waiting_error` ignore « reconnexion », OM:827-829). Ajouts au-delà de l'APK : libellé « Reconnecting... » en partie (Main.gd:775-787), « UNABLE TO REACH THE SERVER » dans la liste publique (OM:354-380). |
| N-A25 | Conforme | `join` n'envoie aucun paquet (SV:367-380) : les extensions sont celles de la salle (`create.sets`, SV:330-337), la jonction ne peut donc pas diverger ; boutique retirée, pas de déblocage à comparer. `grep -n "ExpansionsNotMatch\/expansions_not" scripts server` = 0. |
| N-A30 | Accepté | Salons publics listés et choisis par le joueur (SV:352-356 `listRooms`, OM:436-476) au lieu de `JoinPublicRoom` aléatoire ; l'auto-appariement WORLDWIDE n'est pas porté, périmètre multijoueur fixé par l'utilisateur (salles privées/publiques dans le navigateur de chacun). |
| N-A31 | Accepté | `JoinRandomRoom` / `JoinAnyExistingPublicRoom` (WORLDWIDE) : même décision produit, aucune file d'appariement globale ; `grep -rn "JoinRandom\/random_room" scripts server` = 0. |
| N-A33 | Accepté | Hôte qui quitte la salle d'attente : le rôle passe au premier autre humain connecté, la salle ferme seulement s'il n'y en a aucun (SV:422-433, GR:77-83 ; test `_scenario_host_public`), comme la migration de maître Photon. Joueur qui quitte en partie : `GameRoom.leave` (GR:187-194) garde le siège à l'IA au lieu de `KillManually` (OnlineFlowManager.cs:307-318) : décision explicite de l'utilisateur (R-D54, N-B06) dans le modèle de salle. Salle fermée sans humain actif : `_collect_rooms` (SV:174-188). |
| N-A42 | Conforme | Nom, avatar, victoires, défaites par siège (GR:432-437 `lobby_msg`, OM:872-905) ; `Id` = indice de siège, `IsMasterClient` = champ `host` du lobby (OC:287-289, démarrage réservé à l'hôte SV:398-401). `IsBacker` : boutique retirée. |
| N-A43 | Corrigé (6d) | `lobby` porte maintenant `public` (GR:437 `lobby_msg`, PROTOCOL.md) et le client le relit à chaque lobby (OC:284-285) : après un rechargement (`try_resume`), `public_room` était perdu (titre « WAITING FRIENDS... » et flèche de retour vers WITH FRIENDS au lieu de la liste). Test `_scenario_away` (`public_room` remis à faux puis `fetch_lobby`). |
| N-A45 | Accepté | `OnlineKeys.ISBACKER` : boutique et mécènes retirés (décision produit) ; `grep -rn -i backer server scripts/OnlineClient.gd` = 0. |
| N-A46 | Corrigé (6d) | Équivalent de l'`AppVersion` Photon : `NetCodec.PROTOCOL_VERSION` (NetCodec.gd:7), envoyé dans `v` par `create`, `join`, `resume`, `listRooms` (OC:191-192) ; le serveur refuse tout autre `v` ou son absence par `error` `version`, sans effet de bord (SV:305-317). Les menus affichent « Game updated. Please reload the page. » (OM:24, 675, 696, 709, tick de la liste OM:358-363) ; CI mise à jour (`listRooms` avec `v`). PROTOCOL.md. Un onglet périmé qui reprend sa session (`resume` refusé pour `version`) perd sa session (OC `_on_message`, `session_lost`, Main.gd `_on_session_lost` affiche le message) au lieu de rester figé sur une liaison vivante. Test `_scenario_version` (5 valeurs invalides x 4 messages, absence, ping libre, client périmé, reprise refusée) et `ui_smoke` `online_version_mismatch`. |
| N-A50 | Accepté | `BeginCountDown` ne sert qu'aux salons publics à appariement automatique (WaitingPublicRoomScene) ; ici l'hôte appuie sur OK/START WITH BOTS (SV:398-401, OM:769-776). Aucun minuteur d'auto-démarrage, par décision produit. |
| N-A56 | Conforme | Le coup nominal existe : choix `draw-type` du moteur (Match.gd:939, :1267 Haunted Library), joué par `resolveChoice` ; le serveur n'accepte que l'un des `legal_moves` du siège (GR:236-246). Le message `ChooseDeckToDraw` (PlayerInteractionBase.cs:86-91) n'a plus d'objet : l'autorité est le serveur. |
| N-A60 | Conforme | `SlowDown` n'existe que pour alimenter IsPlaying chez les pairs. Godot : le serveur diffuse `awaited` (GR:30, `state_msg` GR:439-451), `OnlineGameManager` en tire les adversaires attendus (OnlineGameManager.gd:14-17) et BoardUI affiche la bulle IS PLAYING! (BUI:4538-4601 ; `ui_smoke` `online_is_playing`). |
| N-A66 | Conforme | Départ explicite : `leave` pose `auto`+`left` (GR:187-194), `_is_ai` (GR:286) donne la main à l'IA au tick suivant, sans attendre le délai de tour. Coupure sans `leave` : la décision attendue tombe à l'échéance (GR:411-428) et, au bout de `--abandon-grace` (120 s), le siège est déclaré parti comme après un `leave` si un autre humain est connecté (GR:163-174, 402). Le délai de reprise est volontaire (équivalent supérieur de N-A03). |
| N-A69 | Conforme | `stack` : sorts et capacités sont montrés dès leur pose (APK comme Godot) ; la seule donnée privée d'une entrée, `picks` (cartes de la main comprises), est retirée pour les autres sièges (VF:49-58). `bossPicks` : l'APK montre tous les bosses dans le carrousel (RandomBossSelectionScene) ; le pool est identique pour tous les sièges pendant la phase `boss` puis vide (VF:83). Tests : `_check_stack_and_boss_picks` (unitaire, jetons secrets) et, dans `_check_view`, vérification à chaque vue des parties IA que `picks` n'apparaît que chez l'activateur et que `bossPicks` vaut le pool en phase `boss`, `[]` ensuite. |
| N-A71 | Corrigé (6d) | Web : écouteur `pagehide` (OC:83-92, `JavaScriptBridge.create_callback`) qui envoie `away` en salle d'attente. Le serveur libère le siège après `--away-grace` (10 s) au lieu de `--seat-grace` (30 s) si la liaison tombe (SV:419-421, GR:133-160) ; un `resume` dans le délai le garde. Pas de reprise automatique au démarrage : après un rechargement le siège n'est gardé que si RESUME (WITH FRIENDS, OM:643) est pressé dans les 10 s ; sinon un invité rejoint avec le code, l'hôte d'une salle privée n'est jamais libéré. Pas de `leave` : il ne laisserait aucune reprise (pagehide part aussi au rechargement). En partie rien n'est envoyé (reprise et abandon de N-B49). PROTOCOL.md. Test `_scenario_away` (B pagehide+fermeture libéré, C sans pagehide gardé, D coupé puis rouvert garde son siège). Non vérifié dans un vrai navigateur ni sur un vrai rechargement. |
| N-B04 | Conforme | Main.gd:791-807 : s'il ne reste aucun autre humain, « You win by desertion. The game will now end. » (tour > 2, `Profile.record_desertion`) ou « No players to play with. The game will now end. », OK quitte la partie (GamePlayMOScene.cs:104-118) ; la salle côté serveur se ferme sans humain actif (SV:174-188). Tests `ui_smoke` (`online_player_left`) et `online_test` `_scenario_player_left`. |
| N-B05 | Conforme | « <nom> has left the game. » (15 caractères, Main.gd:802) quand un humain est marqué `left` dans le lobby et qu'il en reste un autre ; signal `player_left` (OC:274-281). Test `ui_smoke` « Bobby has left the game. ». |
| N-B06 | Accepté | Le siège reste à l'IA (`left` + `auto`, GR:187-194) au lieu de `KillManually` : décision délibérée de l'utilisateur dans le modèle de salle ; le départ est annoncé aux autres (N-B04/B05). |
| N-B13 | Conforme | La bulle IS PLAYING! existe (BUI:4538-4601) et suit `awaited` du serveur (OnlineGameManager.gd:14-17), sans message SlowDown ; elle s'efface à l'entrée de la bulle de coup (BUI:4601). Le ralentissement pendant un zoom est local (`_win_paused`, BUI:1083). Test `ui_smoke` `online_is_playing` / `online_remote_notice`. |
| N-B14 | Conforme | 70 s : `turn_timeout_ms` 70000 (GR:24), `--turn-timeout=70` (SV:36, deploy/Dockerfile.server:33, DEPLOYMENT.md:121) ; barre jaune dans DONE `_tick_done_bar` (BUI:4933-4958, P-B33 ligne `Conforme`). Le chiffre doré en haut (CountDown.gd) est un ajout. Fin de délai : seule la décision expirée est jouée (GR:411-428). Le texte d'origine (60 s) était périmé. |
| N-B20 | Conforme | `menu.show_gallery = not _is_online()` (BUI:5122) ; InGameMenu retire CARD GALLERY et descend RESUME d'un cran (InGameMenu.gd:50-56), comme `new PauseScene(!activateTimeOuts)` (PauseScene.cs:28-31,61). RULES, ajout, reste. Test `ui_smoke` `online_pause_no_gallery` : boutons RESUME / RULES / SETTINGS / QUIT GAME. |
| N-B27 | Accepté | WORLDWIDE liste les salons du serveur (OM:263-312) au lieu de `JoinPublicRoom` ; l'erreur « Unable to join public rooms » de l'APK n'a donc plus de cas (`ui_smoke` « la boîte ne doit plus s'ouvrir »). |
| N-B30 | Conforme | Tous les cas atteignables de `ShowOnlineMessageBox` sont portés avec le texte de l'APK : « Invalid Code » (OM:683,694), « Room is full » (OM:476,695), « Unable to create public/private room » (OM:677), « Unable to join private room » (OM:692), « Unable to join public room » (OM:473, 834). « Expansions not match » : sans objet (N-A25). « Unexpected Error <n> » est la branche `_` du `switch` de l'APK, inatteignable sur un échec ; ici toute erreur inconnue retombe sur le texte de jonction/création. Écart du texte d'origine (« …public game ») déjà corrigé. Textes propres à Godot, sans cas APK : « This game is no longer open » (clic sur une ligne de la liste publique devenue introuvable, OM:475), « Unable to resume the game » (RESUME, OM:709), « Room closed » (OM:834), « Game updated. » (N-A46). |
| N-B32 | Corrigé (6d) | La modale existe (U-C34) : après `WAIT_LINK_GRACE_S` (10 s) sans liaison, `_on_waiting_error` (OM:827-847) ouvre « NETWORK ERROR » et OK ramène à l'écran précédent. Reste corrigé : le texte est maintenant toujours « Unable to join public room », y compris en salle privée, comme `WaitingRoomBaseScene.OnDisconnect` (WRB:54-61, FailToJoinPublic en dur) ; « Room closed » reste réservé à la salle fermée. Test `ui_smoke` `online_link_lost_waiting`. |
| N-B34 | Conforme | L'hôte qui quitte une salle d'attente passe le rôle au premier autre humain connecté, la salle reste ouverte, publique ou non ; elle ne ferme que sans autre humain (SV:422-433, GR:77-83), comme la migration de maître de Photon. Le texte d'origine (salle fermée pour tous) était périmé. Test `_scenario_host_public`. |
| N-B36 | Accepté | L'or de `IsBacker` (OnlinePlayerInfoEntity.cs:55-63) n'a pas de sens sans boutique ; Godot dore la ligne de l'hôte (OM:889, ajout). |
| N-B39 | Corrigé (6c) | Vérifié dans le code : le serveur ne lance plus à salle pleine (SV:449 : démarrage immédiat seulement pour l'hôte seul avec des IA, `_join`), l'hôte appuie sur OK (`start`, SV:398-401 ; OK visible seulement avec plus d'un humain, OM:908-915). Fait au lot 6c (U-C28, 3b092f3). Tests `online_test` (« la salle pleine attend l'hôte ») et `ui_smoke`. |
| N-B40 | Accepté | WaitingPublicRoomScene (SEARCHING PLAYERS, 45 s, 10 s, 60-120 s, relance) : salons et liste seulement, par décision de l'utilisateur ; le titre du salon remplace l'en-tête (OM:731-740). |
| N-B41 | Accepté | `ui_timer` rythme le compte à rebours de la salle publique (WPR:102-105), absente ici. CountDown.gd ne joue aucun son (commentaire de tête : A-28). |
| N-B42 | Accepté | L'habillage de CountDownEntity est repris à l'identique pour le minuteur de tour (CD:15-25, (1150, 12)) ; son emploi en salle d'attente publique (APK (1120, 960)) disparaît avec N-B40. `CountDownBehavior` remplacé par `turnDeadline` du serveur (CD:27-37). |
| N-B49 | Corrigé (6d) | Un humain sans liaison depuis `--abandon-grace` (120 s) est déclaré parti, tant qu'un autre humain est connecté (seul face aux IA, ou panne commune : `--ttl` et `resume` inchangés), comme après un `leave` : `abandon_ghosts` (GR:163-172, appelé par `tick` GR:402) pose `left`+`auto`, jeton mort, donc « X has left the game. » / fin par abandon chez les autres (N-B04/B05) ; avant ce délai `resume` rend le siège et l'IA ne joue que les décisions expirées. Option `--abandon-grace`, PROTOCOL.md. Test `_scenario_abandon` (B parti signalé une fois, C reconnecté non, ancien jeton `bad_token`). Changement de comportement à signaler : un humain coupé plus de 120 s ne peut plus reprendre sa place quand d'autres humains sont encore là (délai à régler par `--abandon-grace`). |

## Lot 6e : réglages, audio, entrées, tutoriel, plateforme, web, divers (2026-10-27)

Validé par `python tools/run_godot_tests.py` (14/14), l'oracle APK et `ui_smoke` (`_check_audio`, `tut_decks`, `tutorial`). Non vérifié : les sons à l'oreille, le Screen Wake Lock, `contextmenu`, `visibilitychange` et le glisser du carrousel dans un vrai navigateur (seul le chemin GDScript est testé en processus).

58 lignes : 24 Corrigé, 19 Conforme, 15 Accepté.

| ID | État | Preuve |
|---|---|---|
| S-01 | Corrigé | Profile.write / Profile.read (Profile.gd:20-37) : 8 essais comme StorageHelper, push_error si tous échouent ; utilisés par Profile, AudioManager (réglages) et la session en ligne (OnlineClient.gd, Profile.write(cfg, SESSION_PATH)). |
| S-03 | Conforme | Code mort dans l'APK : aucun lecteur de .Difficulty hors Storage/ ; rien à porter. |
| S-07 | Accepté | Mode plein écran / barres système immersives d'Android (CustomService.IsFullScreenActive, aucune ligne d'UI) : barres système Android, sans équivalent web ; F11 reste disponible dans le navigateur. |
| S-08 | Accepté | LEGENDARY MODE dépend de IsBacker : boutique, mécènes et légendaires supprimés (décision produit du 2026-10-26). |
| S-12 | Accepté | Compteur SPWins et déblocage Hidden Heroes à 40 victoires : boutique et déblocages supprimés (décision produit), HiddenHeros jouable d'office (Match.gd:12). |
| S-13 | Conforme | random_profile (Profile.gd:59-64) = « player_ » + StringFactory.RndWord(4) (ChangeNameAvatarScene.cs:43, alphabet de StringFactory.cs:22) ; NAME_MAX 45 = Truncate(45) (:106). |
| S-15 | Corrigé | Profile.check_force_play_tutorial (Profile.gd:164-176, CURRENT_VERSION 2.2.6, LAST_TUTORIAL_VERSION 2.2.4, comparaison de versions) appelée au démarrage (Main.gd:99, Game.cs:119) : repasse first_gameplay à vrai si la version sauvée est plus ancienne. |
| S-16 | Accepté | IsBacker : statut mécène Kickstarter lié à l'achat, boutique supprimée (décision produit). |
| S-21 | Accepté | Curseur MASTER VOLUME (InGameMenu.gd:76-104) : remplace les touches de volume matérielles d'Android (système, hors du jeu), qui n'existent pas sur le web ; il n'agit que sur le bus Master et laisse MUSIC / SOUND / GAME SPEED identiques à l'APK. |
| A-02 | Corrigé | AudioManager._play (AudioManager.gd:172-185) : 10 voix, boucles comprises ; plein, le NOUVEAU son est abandonné (trace dropped:), comme SoundBank.CreateSoundInstance (SoundBank.cs:130-145). _next_voice (vol de la plus ancienne) supprimée. Test _check_audio. |
| A-12 | Corrigé | AudioManager.room_category (AudioManager.gd:252-263) lit RoomCategory dans assets/data/<paquet>/data.json (BaseDeck, HiddenHeros, PlayerChoice, ToolsHeroKind) ; autre ou absent : physical. Table d'ids figée supprimée. Test _check_audio (effectifs par catégorie). |
| A-14 | Conforme | Les 7 sons sont copiés et préchargés comme dans l'APK (seule AudioScene de test les joue) ; aucun appel Godot ne les joue. |
| A-15 | Accepté | ui_purchase ne sert qu'à UnlockScene : écran de déblocage supprimé avec la boutique. |
| A-21 | Corrigé | Retournement de toutes les cartes du carrousel : un ui_card_slide_down par carte (BoardUI.gd:2191, FlipCardBehavior.cs:126) ; zoom de pile : ui_shuffle_left/right à chaque changement d'indice arrondi (_zoom_stack_layout). |
| A-22 | Corrigé | Tous les carrousels jouent ui_shuffle_left/right selon le sens : nombre de joueurs (Main.gd _count_step, :467-490), zoom de pile de salles (BoardUI _zoom_stack_layout), tirage du boss (BoardUI.gd:2203), main (BoardUI.gd:3713-3720). |
| A-23 | Corrigé | _opp_toggle (BoardUI.gd:884-888) joue ui_card_slide_down à l'ouverture du panneau étendu et ui_card_slide_up à la fermeture (ExpandedOpponentComponent.cs:51,60). |
| AW-02 | Conforme | MP3 pour la musique (décodé par Godot lui-même), SFX en QOA : aucun écart de comportement avec l'APK. |
| AW-03 | Conforme | Aucun AudioEffect dans les scripts : le mode Sample du web suffit ; pause de la musique par stream_paused (AudioManager.gd:85). Lecture réelle en navigateur non vérifiée ici. |
| I-05 | Accepté | Clic sur une carte de la main : équivalent souris du glisser tactile de l'APK (le glisser reste le geste principal) ; cible web à la souris sur bureau. |
| I-06 | Accepté | Tolérance de 12 px avant annulation de l'appui long et clic droit = appui long : indispensables à la souris (pas de tremblement du doigt ni de clic droit au tactile) ; durée 1,0 s et tap ignoré après appui long identiques à l'APK. Cible souris sur bureau. |
| I-08 | Corrigé | Nombre de joueurs : flèches ← → (Main.gd:171-176, _count_step), glisser 0,004 index/px avec recalage (Main.gd:474-500, CarrouselDragBehavior), tap sur les côtés conservé ; zoom de pile de salles : flèches ← → (BoardUI.gd:5247) après un appui dans le cadre. |
| I-09 | Accepté | TwoLongTouchBehavior ouvre UnlockCodeScene (code REDEEM / mécène) : codes de déblocage supprimés avec la boutique ; geste à deux doigts de toute façon tactile. |
| I-12 | Corrigé | Flèches ← → sur le carrousel du nombre de joueurs (Main.gd:171-176) et sur le zoom de pile (BoardUI.gd:5247) ; pages des règles (RulesViewer.gd:117-119). |
| I-17 | Conforme | CardGallery.gd reprend ScrollListBehavior.Update : ressort 0,4 et inertie 0,1 (CardGallery.gd:80,104-110,294 ; ScrollListBehavior.cs:214-224) ; la molette est un ajout souris. |
| I-20 | Conforme | ButtonBaseEntity.ShowHover n'est mis à vrai nulle part (grep sur le décompilé) : HandMouseOverBehavior reste inactif dans l'APK (IsActive = false, ButtonBaseEntity.cs:210-214), donc aucun survol visible à porter ; la couleur de survol des boutons Godot est l'état standard du bureau. |
| I-21 | Corrigé | Main._keep_screen_on (Main.gd:116-117) : Screen Wake Lock (navigator.wakeLock.request('screen')), redemandé au retour d'onglet et au premier appui ; sans effet si l'API manque. Équivalent de AddFlags(KeepScreenOn) (AndroidActivity.cs:43). |
| T-A04 | Corrigé | Voir S-15 : Profile.check_force_play_tutorial (Profile.gd:164) appelée à l'ouverture (Main.gd:99). |
| T-A22 | Corrigé | NAG = 3,0 s (TutorialOverlay.gd:33), la durée de la barre de temps de l'aventure qui boucle (IsLoopActive, GamePlayBaseScene.cs:215) ; remise à zéro à chaque scène (_hold_t, :318,343,487,802). Test _tut_hit sur TutorialScript.NAG. |
| T-A26 | Corrigé | Même rappel que T-A22 (NAG 3,0 s, TutorialOverlay.gd:33). |
| T-A28 | Corrigé | p29 ne demande plus adv28 : seulement l'effet du sort et les PV (TutorialOverlay.gd:442, cs:317-323). |
| T-A29 | Corrigé | p25 : phase d'aventure, IA active (active_player() == 1), blessure de 068 et animations finies (TutorialOverlay.gd:447, cs:221-223). |
| T-A33 | Corrigé | _gate_tap (TutorialOverlay.gd:550-561) appelle _reinforce() sur un tap en carte non imposée, comme ExtractCard (CardExtractBehavior.cs:211-237 : InvalidCardPlayed à l'appui, glissé ou non). |
| T-B12 | Conforme | Position mesurée sur les captures de l'APK : le +9 px compense le retournement du sprite autour de son origine (TutorialOverlay.gd:53), le rendu final coïncide. |
| T-B26 | Corrigé | Rappel de p23 toutes les 3,0 s (NAG), la période de la barre de l'APK, barre en pause sous la scène (_hold_t remis à zéro, TutorialOverlay.gd:802) ; géométrie déjà conforme. |
| T-B32 | Corrigé | _levelup (TutorialOverlay.gd:758) n'attache plus que le bouton LEVEL UP et le sprite du boss (board._lane[1]["sprite"]), comme p26 et TutorialLevelUpScene.cs. |
| T-B33 | Accepté | Priorité entre le collider plein écran de TutorialBaseScene (DrawOrder -10, :82-93) et les entités rattachées : comportement d'exécution de Wave non décidable depuis le décompilé (seul DONE désactive ses gestes, TutorialDoneButtonScene.cs:36) ; non reproductible. Le voile STOP de Godot reste le comportement sûr. |
| D-08 | Accepté | FullScreen et HideSoftKeys : barres système immersives d'Android, sans équivalent web (F11 dans le navigateur). |
| D-09 | Corrigé | Voir I-21 : Screen Wake Lock (Main.gd:116-117). |
| D-10 | Conforme | Échap déclenche le retour (Main.gd:177, _unhandled_key_input), en plus de la flèche à l'écran ; la touche Retour d'Android n'existe pas sur le web. |
| D-12 | Conforme | Onglet masqué : AudioManager._setup_background_pause (AudioManager.gd:74-91, visibilitychange, musique en pause) ; requestAnimationFrame est gelé par le navigateur ; BoardUI._process borne le temps écoulé (BoardUI.gd:1005). |
| D-13 | Conforme | Retour sur l'onglet : set_background(false) (AudioManager.gd:80-91) ; barre de temps et réseau protégés par le plafond de dt (BoardUI.gd:1005) et SLEEP_GAP_S (OnlineClient.gd:122). |
| D-17 | Accepté | Clavier virtuel : saisie tactile seulement (clavier logiciel Android, touch-only) ; au clavier physique, rien à masquer. |
| D-19 | Accepté | Insights.Report (Xamarin Insights, service arrêté) : télémétrie tierce non reproductible ; les erreurs vont à la console du navigateur (push_error). |
| D-44 | Corrigé | Voir I-12 : flèches ← → sur les carrousels (Main.gd:171-176, BoardUI.gd:5247). |
| D-51 | Conforme | Ajouts web documentés sans pendant dans l'APK (origine, sessionStorage, shim isSecureContext / audioWorklet) : rien à porter ; à garder en tête hors homelab. |
| W-01 | Accepté | Le chargement du .wasm et du .pck est celui de l'enveloppe HTML de Godot (splash loading_bg déjà repris, project.godot:12-14) : l'animation Rupis de LoadingScene est une scène du moteur de jeu, qui ne peut pas tourner avant que le moteur existe. Reste, comme l'APK, la moitié « noir -> titre » (Main.gd:104-112). |
| W-03 | Conforme | Pause en arrière-plan : musique (AudioManager.gd:74-91), glisser annulé (BoardUI.gd:4003), dt plafonné (BoardUI.gd:1005) ; multijoueur : délai de grâce de 30 s côté serveur. |
| W-04 | Conforme | Aucun TargetFramerate ni IsFixedTimeStep dans l'APK : les valeurs par défaut de Godot sont l'équivalent. |
| W-09 | Conforme | Contenu du pck inventorié (include_filter / exclude_filter, export_presets.cfg:11-13) ; aucun écart avec l'APK à porter. |
| W-11 | Conforme | build_web/ est ignoré par git et régénéré par le Dockerfile ; un build local périmé est sans effet en production. |
| W-12 | Conforme | Cache-Control: no-cache dans deploy/nginx.conf ; PWA désactivé (export_presets.cfg:35). |
| W-15 | Conforme | Travail par image inventorié (BoardUI._process, ApkParticles, AudioManager) : bornes et arrêts conformes ; aucune charge excessive relevée. |
| W-17 | Conforme | Le message d'erreur WebGL 2 / WebAssembly est celui de l'enveloppe standard de Godot (build_web/index.html:165-198). |
| W-19 | Corrigé | Menu contextuel du navigateur supprimé (contextmenu -> preventDefault, Main.gd:118) : le clic droit sert au zoom des cartes (CardUI.gd:335). Plein écran : barres système Android, F11 dans le navigateur (voir D-08). |
| W-20 | Accepté | Tactile : cible web à la souris sur bureau, tactile hors périmètre (émulation souris -> toucher conservée, project.godot:36). |
| X-M32 | Corrigé | _dracolich_lair (RoomAbilities.gd:488-510) se résout seule pour un joueur humain quand une seule paire est possible : PlayerInteractionBase.ResolveTarget:39 n'appelle TryToAutoresolve (Count() <= TargetsAmount, ComposedTargetProvider.cs:35-52) que si tryToAutoresolveTargets, vrai pour HumanPlayerInteraction.cs:48 et RemotePlayerInteraction.cs:69 seulement ; l'IA (FixedAI) et le harnais de l'oracle (autoAI faux) gardent le choix. Une première version sans cette distinction faisait diverger s4-p2 et s5-p2. Test goldens `_t_choice_dracolich_lair` (humain : pile directe ; harnais : choix ouvert). |
| X-M34 | Corrigé | _unuse_on_error (RoomAbilities.gd:292) remet usedThisTurn à faux sur toute erreur de _all_seeing_eye (:256) et _witchs_kitchen (:263), comme Dracolich. |
| X-M60 | Corrigé | DbmRandom (scripts/DbmRandom.gd, System.Random soustractif de Knuth) + RandomProvider.Shuffle ; le tutoriel fixe la graine 2832 (GameManager.gd:25,33, Match.gd:101-139, CardDB.shuffled). Les trois pioches (salles, sorts, héros) sont identiques à la trace de l'oracle (test tut_decks, tests/tut_decks_data.gd). |

## TNL : audit carte par carte (2026-10-27)

Lecture seule, aucun code de jeu modifié. Référence, dans l'ordre : texte de la carte (`assets/data/expansions/next-level.json`, tiré du wiki), FAQ et glossaire de `docs/rules/rules.md` (livret TNL à partir de la ligne 956, clarifications de cartes lignes 260-940), arbitrages de `docs/rules/arbitrages-wiki.md` ; pour les mécaniques de base, l'APK déjà porté. Chaque ligne vient de la lecture du chemin de code, pas du nom ni des commentaires. Non lancé : la suite Godot (aucun comportement douteux n'a eu besoin d'être rejoué).

Abréviations (dossier `src/frontend/godot/scripts/`) : TA = TnlAbilities.gd, TS = TnlSpells.gd, M = Match.gd, BE = BossEngine.gd, RA = RoomAbilities.gd, AW = AiWiki.gd. Goldens : noms des fonctions `_t_*` de `tests/goldens_tnl.gd` (sans le préfixe). IA : « auto » = effet sans décision, « poids » = les options d'un choix portent un `ai` (AI.gd:260), « score » = `score_activate` / `score_spell` / `score_move`.

Les textes imprimés des héros à capacité (`heroAbility`) ne sont dans aucune source du dépôt (le JSON n'a que les statistiques) : leur conformité se mesure à `cards.json`, à la FAQ et au glossaire, pas à la carte. Le wiki a répondu HTTP 402 aux audits précédents (`docs/reference/part2/2.1_tnl_A.md`, `2.1_tnl_B.md`, dont plusieurs écarts ont depuis été corrigés) ; il n'a pas été réessayé.

### Cartes (115)

| Id | Carte | Texte (résumé) | Code | Golden | IA | Statut | Priorité |
|---|---|---|---|---|---|---|---|
| TNL000 | Mirrax | Level up : copie les icônes de trésor d'un autre boss, pour la partie | TA:317, 346-360 (boss vivants, Kirax compris via `_boss_icons` 330-343), 1266-1271 (`bonusTreasures`) ; BE:61-66 | mirrax | poids (nb d'icônes) | Conforme | — |
| TNL001 | Doc Scarecrow | Build : défausser une carte pour qu'un héros de la ville ne puisse pas être leurré | TA:1477-1488 (coup `docScarecrow`), 1547-1555, 855-856 ; M:1616 (leurre sauté). Le code limite à une fois par tour (`used "scarecrow"`, TA:1483, 1554), le texte n'a pas de limite | scarecrow | score (AW `scarecrow_value`) | Corrigé (TNL) | — |
| TNL002 | Belladonna | Level up : guérir une blessure | TA:318, 362-370, 1272-1274 (`heal_one_wound`, épique permis) | belladonna | poids (âmes) | Conforme | — |
| TNL003 | Torix Uz'Kali | Toute salle Monster défaussée ou détruite : peut la mettre en main | TA:319-320, 420-447 (file `torixQueue`), 1222-1234 ; BE:`discard_room_to_pile` (torix_catch) ; M:517-518 (file vidée après chaque coup) | torix, torix_jeopardy, torix_via_apply_move | poids fixe (prend toujours) | Conforme | — |
| TNL004 | Killa | 3 blessures ou plus : dernière salle +3 | TA:768-781 (dernière salle non gelée, FAQ) | killa | auto | Conforme | — |
| TNL005 | Shellda | Fin de tour : peut échanger deux salles d'un donjon | TA:892-893, 913-939, 1293-1305 (piles échangées, effets indexés suivent) | shellda, end_of_turn_resume | poids (`swap_ai`) | Conforme | — |
| TNL006 | Smoake | Quand vous construisez une salle Monster : peut piocher une salle | TA:455-456 (pioche toujours prise, jamais gênante) | smoake | auto | Conforme | — |
| TNL007 | Kazanna | Level up : défausse la main, pioche 3 sorts | TA:322-326 | kazanna | auto | Conforme | — |
| TNL008 | Dr. Timebender | 1/tour : défausser un sort pour annuler un sort adverse | TA:1509-1512, 1574-1577 (annulation immédiate : prioritaire, hors Counterspell, FAQ) | timebender | score 100 (annule toujours) | Conforme | — |
| TNL009 | Nicolius | Fin de tour : peut piocher un sort si un joueur a gagné 2 âmes de plus que vous | TA:863-867, 881-889 (photo des âmes au début du tour) | nicolius | auto | Conforme | — |
| TNL010 | Porkus | Level up : retire un héros face cachée, en cherche un autre dans les pioches de héros | TA:327, 397-415, 1278-1292 ; sans âme à retirer, aucune recherche (TA:402-404) alors que la 2e phrase pourrait s'appliquer | porkus | poids | Corrigé (TNL) | — |
| TNL011 | Angstigoth | 1/tour, quand vous tuez un héros : piocher une salle | TA:673-677 ; M:2292-2293 | angstigoth | auto | Conforme | — |
| TNL012 | Eclipse | Quand vous détruisez une salle de votre donjon : la salle découverte +3 | TA:463-485 (`destroy_actor`), M:811-813, 1814-1816, 1857-1859 (arbitrage : seulement si le propriétaire détruit). Une destruction résolue sans choix (cible unique auto-résolue par `ask`, TA:244-245, par exemple Megaworm Burrow adverse) garde `destroy_actor = -1` et compte comme l'acte du propriétaire | eclipse, arbitrages_wiki | auto | Corrigé (TNL) | — |
| TNL013 | Dark Portal | 1/tour : défausser un sort pour reprendre une salle de la défausse | TA:1055-1061, 1320-1321, 519-527 | dark_portal | score 12 | Conforme | — |
| TNL014 | Imp Temple | 1/tour : la carte qu'un adversaire doit défausser va dans votre main | TA:537-565 (`live`, 1/tour par exemplaire) ; branché sur Incubus Gym, Wraith's Throne, Cursed Tomb, RA:926 (Torture Chamber), M:901 (Specter, Succubus), RmbAbilities:473 | imp_temple_dragon_graveyard, incubus_gym | auto | Conforme | — |
| TNL015 | Madman's Manor | 1/tour, héros mort ici : un sort de la défausse en main | TA:653-658 ; le jeton « 1/tour » est consommé (656) avant de savoir qu'il y a un sort à reprendre (522), contrairement au jeu de base (RA:719-730) | hero_dies_triggers | auto | Corrigé (TNL) | — |
| TNL016 | Arcane Crypt | Build ou découverte : peut reprendre un sort de la défausse | TA:492-493 (facultatif), 466-485 (découverte) | build_effects, uncover_effects | poids | Conforme | — |
| TNL017 | Haunted Hall | Détruire : un héros de cette salle retourne en ville | TA:1136-1142, 1180-1194 | haunted_hall_warp_tube | score 70 (si le héros survivrait) | Conforme | — |
| TNL018 | Inner Sanctum | Fin de tour : si aucun héros n'est entré, peut piocher une salle | TA:714-716 (drapeau `entered`), 878-880 ; pioche toujours prise | inner_sanctum_blockpile, audit_lot21 | auto | Conforme | — |
| TNL019 | Incubus Gym | Build : chaque adversaire défausse une salle | TA:503-505, 568-585 | incubus_gym | auto | Conforme | — |
| TNL020 | Dragon Graveyard | 1/tour : prendre une carte de la défausse fait piocher une salle | TA:594-604 ; RA:73-74 (tous les chemins passent par `take_discard_card`) | imp_temple_dragon_graveyard, audit_lot21 | auto | Conforme | — |
| TNL021 | Wraith's Throne | 1/tour, héros mort ici : chaque adversaire défausse un sort | TA:653-659 ; jeton consommé même si aucun adversaire n'a de sort | hero_dies_triggers, once_per_turn_death_triggers | auto | Corrigé (TNL) | — |
| TNL022 | Rust Monster Pen | 1/tour : défausser une salle Monster pour -1 à une salle Trap | TA:1078-1082, 1326-1327, 1347-1350 ; plancher à 0 appliqué une seule fois en fin de calcul (BE:504) : une salle à 0 dégât, -1 puis +3, donne 2 au lieu de 3 (FAQ « jamais sous zéro ») | rust_bullet | score 30 (si sauve) | Corrigé (TNL) | — |
| TNL023 | Goblin Nursery | La salle à sa gauche, si Monster : +2 | TA:762-764 (index - 1 = côté entrée) | passive_damage | auto | Conforme | — |
| TNL024 | Barbarian Hall | Build : défausse un sort si vous en avez | TA:506-508, 529-532 | build_effects | auto | Conforme | — |
| TNL025 | Spawn Point | 1/tour, héros mort ici : piocher 2 salles | TA:653-660 | once_per_turn_death_triggers, hero_dies_triggers | auto | Conforme | — |
| TNL026 | Fangroot Garden | 1/tour, héros mort ici : peut construire une autre salle | TA:661, 946-1003 (emplacement neuf ou par-dessus ; avancée : trésor commun) ; jeton consommé même sans salle posable (656) | hero_dies_triggers | poids | Corrigé (TNL) | — |
| TNL027 | Shrooman Cave | Build ou découverte : une AUTRE salle Monster +3 | TA:494-497 (s'exclut, FAQ) | build_effects, uncover_effects | poids | Conforme | — |
| TNL028 | Goblin Mess Hall | Chaque autre salle Monster de votre donjon +1 | TA:765-767 | passive_damage | auto | Conforme | — |
| TNL029 | Megaworm Burrow | Build : détruire une salle avancée de n'importe quel donjon | TA:509-512 ; s'exclut elle-même (lecture : « one Advanced Room » pourrait la contenir) | megaworm | poids (`room_options`) | Conforme | — |
| TNL030 | The Arena | 1/tour : révéler une salle Monster de la main pour +X | TA:1088-1092, 1254-1259 (la salle reste en main, FAQ) | arena | score 15 | Conforme | — |
| TNL031 | Antimagic Zone | Défausser de la main : annuler un sort adverse | TA:1507-1508, 1569-1573 (immédiat, hors Counterspell, FAQ) | antimagic_zone | score 120 | Conforme | — |
| TNL032 | Lost Library | Détruire : piocher 2 sorts puis en défausser 1 | TA:1117-1120 | lost_library | score 3 (rarement jouée) | Conforme | — |
| TNL033 | Frostbat Cave | Détruire : désactiver une salle de n'importe quel donjon | TA:1121-1125, 1355-1357 | decapitator_frostbat | score 65 (si elle sauve un héros) | Conforme | — |
| TNL034 | Spellslime Pit | Chaque sort que vous jouez : +1 | TA:843-845 (sort annulé exclu, FAQ) | spellslime_hall_of_mirrors, audit_lot21 | auto | Conforme | — |
| TNL035 | Observatory | 1/tour : défausser un sort pour piocher un sort | TA:1062-1066, 1322-1323 | observatory_treadmill | score 12 | Conforme | — |
| TNL036 | Sorcerobe School | Build ou découverte : piocher un sort | TA:498-499 | build_effects, uncover_effects | auto | Conforme | — |
| TNL037 | Hall of Mirrors | 1/tour, un adversaire joue un sort : piocher un sort | TA:846-849 (sort annulé exclu, FAQ) | spellslime_hall_of_mirrors, audit_lot21 | auto | Conforme | — |
| TNL038 | Elemental Generator | +X, X = sorts en main | TA:753-754 (compté à l'entrée du héros : le sort lancé ensuite est inclus, FAQ) | passive_damage | auto | Conforme | — |
| TNL039 | Brainsucker Queen | 1/tour, héros mort ici : piocher 2 sorts puis en défausser 1 | TA:662-664 | hero_dies_triggers | auto | Conforme | — |
| TNL040 | Bullet Builder | 1/tour : défausser une salle Trap pour -1 à une salle Monster | TA:1083-1087, 1328-1329 ; même plancher final que Rust Monster Pen (BE:504) | rust_bullet | score 30 | Corrigé (TNL) | — |
| TNL041 | Wreck Room | 1/tour : détruire une autre salle de votre donjon pour piocher une salle | TA:1093-1102, 1361-1366 | wreck_chomper_smashinator | score BUILD_FIRST (donjon plein) | Conforme | — |
| TNL042 | Deadly Treadmill | 1/tour : défausser une salle pour piocher une salle | TA:1067-1071, 1324-1325 | observatory_treadmill, audit_lot21 | score 12 | Conforme | — |
| TNL043 | Collapsing Bridge | 1/tour, un héros y survit : +3 (texte révisé, FAQ) | TA:704-708 (sortie de salle en vie, `usedThisTurn`) | bom_boy_and_bridge | auto | Conforme | — |
| TNL044 | Spiked Pit | Build ou découverte : +3 sur elle-même | TA:500-502 | build_effects, uncover_effects | auto | Conforme | — |
| TNL045 | Decapitator | Phase de construction, détruire : une salle perd son trésor jusqu'à la fin du tour | TA:1126-1135, 1358-1360 ; BE:50-57 (`noTreasure` retire l'imprimé, garde les ajouts ; le tag reste sur l'instance couverte, FAQ) | decapitator_frostbat | score BUILD_FIRST (gain de leurre) | Conforme | — |
| TNL046 | Chump Chomper | 1/tour : détruire une autre salle pour +4 | TA:1093-1102, 1361-1369 | wreck_chomper_smashinator | score 70 (si elle tue) | Conforme | — |
| TNL047 | Blockpile Puzzle | Fin de tour : détruisez une salle de votre donjon | TA:894-910, 1351-1354 (un choix par exemplaire, peut se détruire elle-même, FAQ) | inner_sanctum_blockpile, audit_lot21 | poids (la moins dangereuse) | Conforme | — |
| TNL048 | The Smashinator | 1/tour : détruire toutes les autres salles visibles pour +6 | TA:1103-1116 (sommets visibles non gelés, FAQ) ; refusée s'il n'y a aucune autre salle (le texte ne l'interdit pas, le coût serait vide) | wreck_chomper_smashinator | score 45 (si elle sauve) | Conforme | — |
| TNL049 | Warp Tube | Détruire : un héros de cette salle repart de la 1re salle | TA:1136-1144, 1197-1203 (dégâts gardés) | haunted_hall_warp_tube | score 75 (si le héros survit) | Conforme | — |
| TNL050 | Bom-Boy Factory | Un héros y meurt ou y survit : elle se détruit | TA:665-669, 709-710 | bom_boy_and_bridge | auto | Conforme | — |
| TNL051 | Hatchling's Hoard | Quatre icônes ; se construit sur tout trésor C/F/M/T | TA:946-969 ; BE:50-57 ; données [1,2,3,4] | hatchlings_hoard | auto | Conforme | — |
| TNL052 | Genie Lounge | Build : piocher un sort si vous n'en avez aucun en main | TA:513-515 (build seulement) | build_effects | auto | Conforme | — |
| TNL053 | Werewolf Den | 1/tour : défausser une carte pour +1 à un héros | TA:1072-1077, 1168-1177, 1251-1253, 786-806 (ville, entrées, héros actif) | werewolf_den | score 30 (si sauve) | Conforme | — |
| TNL054 | Cursed Tomb | Détruite par l'effet d'une autre carte : chaque adversaire défausse 2 salles | TA:588-591, 643-645 ; BE:554-555 | cursed_tomb | auto | Conforme | — |
| TNL055 | Save Point | Détruire : reprendre un sort que vous avez joué ce tour | TA:822-825, 1145-1150, 1156-1166 ; M:1837-1838 (sort annulé compris, arbitrage) | save_point, arbitrages_wiki | score 5 | Conforme | — |
| TNL056 | All Your Base | Voir la main d'un adversaire ; peut prendre une salle | TS:145-150, 293-299 : seules ses salles sont proposées, ses sorts ne sont montrés à personne | all_your_base | score 40 | Corrigé (TNL) | — |
| TNL057 | Another Castle | Héros de votre donjon envoyé à l'entrée d'un adversaire | TS:35-39, 151-165 (héros du donjon, pas de l'entrée, FAQ) | another_castle | score 8 | Conforme | — |
| TNL058 | Fairy Fountain | Une salle : zéro dégât, chaque héros qui y entre +1 | TS:166-171 ; TA:474-475 (fin si découverte), 714-719 ; BE:401 | fairy_fountain, audit_lot21 | score (AW `tag_gain`) | Conforme | — |
| TNL059 | It's On! | Tue un héros de votre donjon à 3 PV ou moins, ou si vous avez 3 blessures | TS:43-45, 172-178 (PV restants, FAQ) | its_on | score 90 | Conforme | — |
| TNL060 | Hiring Spree | Piochez 3 salles, donnez-en une à un autre joueur | TS:179-181, 300-306 | hiring_spree | score BUILD_FIRST | Conforme | — |
| TNL061 | Lightning Bolt! | 3 dégâts à un héros de votre donjon ; en défaussant un autre sort, 3 dégâts à chaque héros de l'entrée | TS:182-192, 307-313 ; TA:786-806 (dégâts aux héros de l'entrée gardés comme PV en moins) | lightning_bolt | score 90 | Conforme | — |
| TNL062 | Meddling Kids! | Une salle sans texte ; OU un joueur à 3 héros entrés ne peut pas gagner | TS:193-204 ; RA:238 (`not queued and no_text`) : une capacité déjà déclarée (entrée de pile, exécutée par `run_queued`) s'exécute quand même, alors que la FAQ (rules.md:620-624) dit que Meddling Kids! annule une capacité déclarée (Rust Monster Pen). Mode « nowin » : M:2363, conforme | meddling_kids, meddling_kids_base_passives | score 90 (mode joueur) | Corrigé (TNL) | — |
| TNL063 | Oh, Yeah! | Échange deux salles de votre donjon ; OU (2 de vos salles détruites ce tour) détruit une salle | TS:54-62, 205-213 ; TA:588-589 (compteur) ; l'échange exige deux sommets non gelés | oh_yeah | score (`swap_gain`) | Conforme | — |
| TNL064 | Party Up | Chaque héros qui entre dans un donjon choisi +1 | TS:214-216 ; TA:802-804 | party_up_pause | score 15 | Conforme | — |
| TNL065 | Pause | Le héros du donjon revient à l'entrée en pleine santé ; aucun héros n'entre avant le tour suivant | TS:217-223 | party_up_pause | score 8 | Conforme | — |
| TNL066 | Pity | Retire du jeu un héros du donjon d'un adversaire | TS:63-66, 224-235 | pity_undead | score 85 | Conforme | — |
| TNL067 | Secret Stash | Une salle de votre donjon gagne un trésor C/F/M/T jusqu'à la fin du tour | TS:236-243 ; BE:50-57 | secret_stash_super_effective | score BUILD_FIRST (gain de leurre) | Conforme | — |
| TNL068 | Shortcut! | Un héros saute la prochaine salle ; 5 salles : les deux prochaines | TS:244-250 ; TA:722-738 (arbitrage : salle gelée sautée, cinq piles) | shortcut, arbitrages_wiki | score 40 | Conforme | — |
| TNL069 | Super Effective! | Une salle de votre donjon +2 ; +4 si un seul héros a été leurré chez vous | TS:251-257 ; M:1626-1627 (leurre compté au Bait seulement, FAQ) | secret_stash_super_effective | score 50 | Conforme | — |
| TNL070 | Surprise Gift | Pose une salle face cachée chez un adversaire à la place de la vôtre | TS:92-109, 258-261, 314-337 ; M:1047 (tour de pose consommé, effets de construction au propriétaire du donjon) | surprise_gift | score BUILD_FIRST (si rentable) | Conforme | — |
| TNL071 | Undead Minion | Retire une âme face cachée ; dégâts = ses PV à un héros de votre donjon | TS:78-86, 262-272 (épique permis, FAQ) | pity_undead | score 70 | Conforme | — |
| TNL072 | Wild Monster | Peut construire tout de suite une salle Monster par-dessus une salle | TS:87-89, 273-277 ; TA:972-982 (facultatif), 985-1003 (effets de construction immédiats, FAQ) | wild_monster | score 25 | Conforme | — |
| TNL073-076, 078 | Elfstar, Kyle, Danae, Solemn Caine, Adynn (Clerc) | Statistiques seules (PV 4, 4, 6, 6, 8) | données identiques wiki / `cards.json` ; aucun code propre | new_match_decks (composition) ; TNL078 : aucun | auto | Conforme | — |
| TNL079-082, 084 | Hookshot Joe, Tarka, Lady Samantha, Ampersand, Damok (Guerrier) | Statistiques seules (PV 4, 4, 6, 6, 8) | idem | new_match_decks ; TNL080-082 : aucun nominatif | auto | Conforme | — |
| TNL085-088, 090 | Megan, Otus, A Kid and His Spellslime, Wink, Iskandar (Mage) | Statistiques seules (PV 4, 4, 6, 6, 8) | idem | new_match_decks ; aucun nominatif | auto | Conforme | — |
| TNL091-094, 096 | Black Leaf, Murphy, Colgar, Francisco, Raymond (Voleur) | Statistiques seules (PV 4, 4, 6, 6, 8) | idem | new_match_decks ; aucun nominatif | auto | Conforme | — |
| TNL098, 099, 101, 102, 103, 105, 106, 107, 109, 110, 111, 113 | Tyrone, Branadin, Heavenboy, Lone Fox and Kit, Ser Mortin, O'Brien, Dumbledalf, Wrathfuss, Markus, Rom, Gaimina, Roberta (épiques) | Statistiques seules (PV 11 à 13, 2 âmes, 2 blessures) | idem ; l'épique vaut 2 âmes / 2 blessures par le moteur de base | new_match_decks ; 098 et 099 cités dans belladonna / porkus / pity_undead | auto | Conforme | — |
| TNL077 | Vampire (noir) | Héros noir : un adversaire peut défausser une salle du trésor du héros pour +3 PV, 1 fois par tour | TA:1384-1390, 1460-1498 (`dark_heroes`, `extra_moves`), 1556-1568 ; FAQ : 1/tour, un seul adversaire | dark_heroes | score 60 si le héros allait mourir | Conforme | — |
| TNL083 | Barbarian (noir) | Idem | idem | dark_heroes | idem | Conforme | — |
| TNL089 | Witch (noir) | Idem | idem | dark_heroes | idem | Conforme | — |
| TNL095 | Hitman (noir) | Idem | idem | dark_heroes | idem | Conforme | — |
| TNL097 | The Fool | Attiré par le joueur avec le moins d'âmes ; égalité : reste en ville | BE:211-212 (`fewerSouls`), 179-181 (égalité = ville, FAQ) | lure_kinds | auto | Conforme | — |
| TNL100 | Necromancer (hybride Clerc / Voleur) | S'il survit : retourne un héros face cachée face visible | TA:680-689 ; M:2319-2320 ; trésors [1,4] (carte, pas le wiki) | necromancer, lure_kinds | poids | Conforme | — |
| TNL104 | Swordmage (hybride Mage / Guerrier) | +2 PV à chaque sort joué pendant qu'il est dans le donjon | TA:826-832 (avant les effets du sort, sort annulé exclu, FAQ) | hero_abilities, lure_kinds | auto | Conforme | — |
| TNL108 | Druid (hybride Clerc / Mage) | +X PV, X = sorts en main du propriétaire du donjon, mis à jour en continu | TA:808-820 (`sync_hero`, sorts en attente sur la pile comptés) ; M:517-519, 2006-2008, 2207-2208 | hero_abilities, lure_kinds | auto | Conforme | — |
| TNL112 | Archer (hybride Guerrier / Voleur) | Saute la dernière salle (sans dégâts ni capacité, trésor compté) | TA:735-737 (FAQ) | hero_abilities, lure_kinds | auto | Conforme | — |
| TNL114 | The Brothers (épique) | Attiré par le plus haut total Âmes moins Blessures ; égalité : reste en ville | BE:217-218 ; l'égalité est confirmée par la FAQ (rules.md:838-840), le sens du maximum ne l'est par aucune source | lure_kinds | auto | Conforme | — |

### Règles propres à TNL

| Id | Règle (source) | Code | Golden | Statut | Priorité |
|---|---|---|---|---|---|
| TNL-R01 | Composition : 75 salles, 31 sorts, 42 héros (livret p.2) ; 12 boss imprimés au livret, 13 dans les données (Mirrax en plus, XP identique au wiki) | CardDB, `cards.json` | data | Conforme | — |
| TNL-R02 | Nombre de héros 13 + 9 / 17 + 13 / 25 + 17 pour 2 / 3 / 4 joueurs ; les héros à étoile toujours inclus (livret p.8) | TA:622-640 (`limit_heroes` lit l'étoile comme « héros à capacité », hypothèse invérifiable sans les scans) ; M:143-144 | new_match_decks | Conforme | — |
| TNL-R03 | Un seul paquet de héros : celui de TNL remplace celui du jeu de base ; salles et sorts mélangés (livret p.2) | M:84-93 | new_match_decks | Conforme | — |
| TNL-R04 | Défausse amorcée par 4 salles et 2 sorts au hasard, face visible (livret p.8) | TA:606-620 ; M:1129-1130 | setup_hands | Conforme | — |
| TNL-R05 | Main de départ : 5 salles + 2 sorts, SANS défausse (livret p.8) ; la défausse de 2 cartes est le mode « Classic » (livret p.17) | M:1119-1136 : TNL garde la défausse de 2 de l'APK (main de 5). Le golden `setup_hands` l'impose alors que son commentaire cite le livret (main de 7) | setup_hands (7 cartes gardées ; Classic Mode : 5) | Corrigé (TNL) | — |
| TNL-R06 | Mulligan : quatre salles avancées ou quatre du même trésor | M:1136-1160 (TNL : choix `var_mulligan`, Variants.gd:70 ; jeu de base : automatique, comme l'APK) | variants (mulligan TNL) | Conforme | — |
| TNL-R07 | 2 à 4 joueurs | M:25-34 (`setup_error`) | new_match_decks | Conforme | — |
| TNL-R08 | Héros noirs : capacité écrite sur la carte ; comptés comme ordinaires (glossaire) | `dark` + `heroAbility` (cards.json), TA:1460-1498 ; texte imprimé indisponible | dark_heroes | Conforme | — |
| TNL-R09 | Héros hybrides : deux trésors, comptés comme épiques (glossaire) | BE:lure_tied (trésors cumulés, comme Monster Hunter) ; `epic` vrai | lure_kinds | Conforme | — |
| TNL-R10 | Glossaire « Hero », « Heal », « Kill », « Deactivate », « Uncover », « Destroy », « Entrance » | moteur de base (APK) ; TA:362-370, 466-485, 1372-1379 | belladonna, uncover_effects | Conforme | — |
| TNL-R11 | Effets « cancel » prioritaires, non annulables par Counterspell (FAQ Antimagic Zone, Dr. Timebender) | TA:1500-1513, 1569-1577 (immédiats, hors pile) | antimagic_zone, timebender | Conforme | — |
| TNL-R12 | Deux exemplaires de The Brothers : n'en jouer qu'un (glossaire « Limited Edition ») | `cards.json` quantity 1 (le JSON wiki dit 11) | data | Conforme | — |
| TNL-R13 | Variantes du livret p.17 : Classic Mode, Hard Mode (sans héros de 4 PV), I Choose You (2 boss, on en garde 1), Machinations (pioche si aucune âme), Unlimited Lives | `Variants.gd` ; Main.gd `_draw_variants` (cases de SELECT EXPANSIONS) ; Match.gd `new_match` (jetons `-wiki` de `sets` -> `G.variants`) ; goldens `variants` | — | Corrigé (TNL) | — |

### Synthèse du lot TNL

115 cartes : 105 Conforme, 10 Écart (2 Moyenne, 8 Basse), 0 Non implémenté, 0 Haute. Par type : 13 boss (10 Conforme, 3 Écart), 43 salles (38 Conforme, 5 Écart), 17 sorts (15 Conforme, 2 Écart), 42 héros (42 Conforme). Règles : 13 lignes, 11 Conforme, 1 Écart (Moyenne), 1 Non implémenté (Basse). Goldens : 91 des 115 cartes apparaissent dans au moins une fonction de `goldens_tnl.gd` (grep) ; 24 héros sans capacité n'y figurent pas, et aucune statistique de héros n'est assertée. Mise à jour (2026-10-28) : les 10 écarts et TNL-R13 sont corrigés, voir « TNL : corrections » en fin de section.

Écarts Moyenne :

- TNL-R05 : main de départ de 7 cartes gardées au livret, 5 dans le code (M:1119-1136).
- TNL062 Meddling Kids! : n'annule pas une capacité déjà déclarée (RA:238).
- TNL001 Doc Scarecrow : limite « une fois par tour » (TA:1483, 1554) absente du texte imprimé.

Écarts Basse :

- TNL010 Porkus : pas de recherche s'il n'y a aucun héros face cachée.
- TNL012 Eclipse : destruction à cible unique auto-résolue, comptée pour le propriétaire.
- TNL015, TNL021, TNL026 : jeton 1/tour consommé sans effet.
- TNL022, TNL040 : plancher à 0 appliqué en fin de calcul.
- TNL056 All Your Base : la main n'est pas montrée.
- TNL-R13 : variantes absentes.

Ordre de correction proposé, par thème :

1. Mise en place : trancher TNL-R05 (garder 7 cartes en TNL, « Classic Mode » en option, corriger l'assertion du golden), puis TNL-R13 si le propriétaire veut les variantes.
2. Priorité et annulations : TNL062 (une capacité en pile dont la salle a perdu son texte avant la résolution doit être annulée ; `run_queued` ne revérifie rien par parité APK pour le gel, donc limiter la vérification à `noText`).
3. Capacités de boss : TNL001 (limite 1/tour), TNL012 (porter `destroy_actor` jusque dans un `ask` auto-résolu), TNL010 (recherche sans retrait).
4. Déclencheurs « une fois par tour » : TNL015, TNL021, TNL026 (ne poser `usedThisTurn` qu'après avoir trouvé une cible, comme RA:719-730 pour le jeu de base).
5. Dégâts : TNL022, TNL040 (plancher par effet, ou documenter l'ordre).
6. Information : TNL056 (montrer la main visée à celui qui lance le sort).

Points non tranchés (aucun code changé) :

- Textes de héros à capacité non vérifiables (Vampire, Barbarian, Witch, Hitman, Necromancer, Swordmage, Druid, Archer) ; le sens du maximum de The Brothers n'est confirmé par rien (seule l'égalité l'est).
- Belladonna : le texte wiki met entre parenthèses « Turn one face-down Hero face-up », l'inverse du glossaire de « Heal » et de la FAQ ; le code suit le glossaire, aucune décision nécessaire.
- Meddling Kids! et Oh, Yeah! : catégorie 1 (Build) dans la liste wiki, 4 (marteau + hache) dans `cards.json` ; le code suit les icônes de la carte et la FAQ (jouables en Adventure), ce qui paraît juste.
- Bom-Boy Factory : Trap dans TNL050, Monster dans la variante promo ORG001 du wiki.


### TNL : corrections (2026-10-28)

Tous les écarts de la section ci-dessus sont corrigés (statut `Corrigé (TNL)`), sans écart accepté. Référence : texte des cartes (`next-level.json`), `docs/rules/rules.md` (livret TNL, FAQ), APK pour la mécanique de base ; le jeu de base et les paquets de l'APK ne changent pas (oracle inchangé). « Partie TNL » = le set `next-level` est dans `G.sets` (`TnlAbilities.active(G)`), pas seulement la case wiki : une partie de base avec la case wiki cochée garde la mise en place de l'APK.

- TNL001 Doc Scarecrow : la limite « une fois par tour » est retirée (TnlAbilities.gd:1505 ; plus de `mark_used` dans `apply_move`). Un héros déjà écarté n'est plus proposé, donc pas de boucle. Golden `scarecrow`.
- TNL010 Porkus : sans héros face cachée, la recherche dans les pioches a lieu quand même (TnlAbilities.gd:409). Golden `porkus`.
- TNL012 Eclipse : une destruction à cible unique résolue d'office par `ask` compte pour celui qui l'a déclenchée (TnlAbilities.gd:245-250 : `destroy_actor` posé autour de `resolve_pick`). Golden `eclipse` (Megaworm Burrow adverse : pas de +3).
- TNL015, TNL021, TNL026 : le jeton 1/tour n'est consommé que si l'effet a une cible (TnlAbilities.gd:661-667, `_can_build_any` :983), comme RoomAbilities.gd:719-730 pour le jeu de base. Golden `once_per_turn_death_triggers`.
- TNL022, TNL040 : le plancher à 0 joue à chaque réduction (TnlAbilities.gd:1369-1370 : le -1 est limité aux dégâts courants de la salle), donc 0, -1 puis +3 donne 3. Le plancher final de BossEngine.gd:504 reste. Golden `rust_bullet`.
- TNL056 All Your Base : la main entière est montrée au lanceur (TnlSpells.gd:146-156 : ligne de journal privée + message du choix, que ViewFilter ne donne qu'à lui). Golden `all_your_base`.
- TNL062 Meddling Kids! : annule l'entrée de pile d'une capacité déjà déclarée de la salle visée (TnlSpells.gd:210-218 : `canceled`, comme Counterspell ; OncePerTurn n'est posé qu'à l'exécution, le coût n'est pas payé). Golden `meddling_kids`.
- TNL-R05 : une partie TNL garde 5 salles + 2 sorts (7 cartes), sans défausse d'ouverture (Match.gd:1145, 1187, 1196 ; Variants.gd:39 `keeps_opening_hand`). Golden `setup_hands` corrigé (7 cartes) et complété (TNL + Classic Mode : défausse de 2).
- TNL-R06 Mulligan : en partie TNL c'est maintenant un choix (« you may »), main entière (salles et sorts) remélangée et redistribuée une fois ; l'IA rejoue d'office une main mauvaise (Match.gd:1136-1160, 1071-1073 ; Variants.gd:70). Jeu de base : inchangé (automatique, AvoidMulliganCondition). Golden `variants` (Mulligan).
- TNL-R13 variantes : cases « PLAY VARIANTS » dans SELECT EXPANSIONS, décochées par défaut, offertes seulement avec la case « Wiki expansions » (Main.gd:626 `_draw_variants`, `_active_sets` :136), non enregistrées entre deux lancements.
  - Transport : jeton `<id>-wiki` dans `sets` (comme `tools-wiki`), accepté par le serveur (Server.gd:12 `KNOWN_SETS`), rangé par `Match.new_match` dans `G.variants` (Match.gd:61, clé publique de ViewFilter.gd). Les salons en ligne les portent donc (PROTOCOL.md, `create.sets`) ; ce ne sont pas des paquets pour la règle 5-6 joueurs (`setup_error`).
  - Classic Mode : défausse de 2 cartes en TNL (Match.gd:1145).
  - Hard Mode : aucun héros ordinaire de 4 PV (Match.gd:95).
  - I Choose You : à la fin des choix de boss, chacun reçoit un second boss tiré dans les restants et en garde un (Variants.gd:46 ; reprise Match.gd:562, 1074) ; l'IA garde l'XP la plus haute.
  - Machinations : en fin de tour, un joueur sans Âme gagnée peut piocher une salle ou un sort (Variants.gd:84, appelé Match.gd:2456 et 2485) ; l'IA pioche un sort si elle n'en a aucun, sinon une salle.
  - Unlimited Lives : pas d'élimination à 5 blessures (`CardDB.no_elimination`, CardDB.gd:29 ; Match.gd:2345, ApkAI.gd:1252), fin à la fin d'un tour sans carte dans les pioches de héros, gagnant au meilleur Âmes - Blessures, égalité à l'XP la plus basse (Match.gd:2379, 2475). Le texte ne parle pas des 10 Âmes : elles ne terminent pas la partie.
  - Goldens : `variants` ; ui_smoke (cases) ; online_test (jetons dans le salon, 5 joueurs + variante) ; deux soaks (`soak TNL + variants`, `soak Unlimited Lives`) dans tools/run_godot_tests.py.
- Statistiques des héros sans capacité : golden `hero_stats` compare PV, trésor, âmes, blessures, rang et classe de cards.json au JSON du wiki pour les 32 héros sans capacité (20 ordinaires, 12 épiques ; l'audit parlait de 24).

Limites : le Mulligan TNL remet les sept cartes mais n'est proposé que si les cinq salles tirées sont mauvaises (les sorts n'ont pas de trésor) ; les variantes ne sont pas enregistrées dans le profil ; un client sans ce code ignore les jetons de variante.


## CRL : audit carte par carte (2026-10-28)

Audit en lecture seule ; les corrections sont dans la section « CRL : corrections » ci-dessous. Référence, dans l'ordre : texte de la carte (`assets/data/expansions/crash-landing.json`, tiré du wiki), livret officiel CRL (`docs/rules/rules.md` lignes 2288-2362 = `rules_crash_landing.pdf`), règles de mise en place et de mélange des paquets (lignes 2995-3050, 3187, 3427, 3526, 3643, 3744-3761), glossaire « Uncover » (lignes 3906-3908), arbitrages de `docs/rules/arbitrages-wiki.md` ; pour les mécaniques de base, l'APK déjà porté. Les FAQ de cartes (lignes 260-940) ne citent aucune carte CRL. Chaque ligne vient de la lecture du chemin de code, pas du nom ni des commentaires. Lancé : la suite `goldens` (2218 asserts, 0 échec) pour partir d'un état sain ; une sonde jetable (supprimée) a compté les héros d'une partie TNL / RMB + CRL (voir CRL-R06).

Abréviations (dossier `src/frontend/godot/scripts/`) : RA = RoomAbilities.gd, TA = TnlAbilities.gd, BE = BossEngine.gd, M = Match.gd, SE = SpellEffects.gd, ST = SpellTargeting.gd, AW = AiWiki.gd, CD = CardDB.gd. Goldens : noms des fonctions `_t_*` de `tests/goldens_crl.gd` (sans le préfixe). IA : « auto » = effet sans décision, « poids » / « score » = `AI.gd` (`_score_choice` :234, `_score_spell` :265, `_score_activate_room`) ou `AiWiki.gd` note les options, « neutre » = aucune note (toutes les options valent 0, l'IA prend la première et ne passe jamais).

Les textes imprimés des héros à capacité (The Prince, The King) sont ceux de `cards.json` (copiés du wiki, arbitrages-wiki.md) ; les dix Explorers n'ont aucun texte. Le wiki a répondu HTTP 402 aux audits précédents (`docs/reference/part2/2.1_crl.md`, dont presque tous les écarts ont depuis été corrigés : 5-6 joueurs, partage du leurre, Gundarf, Decoy Garden) ; il n'a pas été réessayé. Les 33 cartes de `cards.json` sont identiques à celles du JSON wiki (comparaison champ par champ : aucune différence).

### Cartes (33)

| Id | Carte | Texte (résumé) | Code | Golden | IA | Statut | Priorité |
|---|---|---|---|---|---|---|---|
| CRL001 | Imperiatrix | Level up : pour la partie, +1 à chaque salle de votre donjon par icône Explorer qu'elle porte | BE:487-491 (`RoomsDamagePerTreasure`, `room_treasures` : icônes gagnées jusqu'à la fin du tour comprises) ; cards.json `levelUp` ; passif, rien à exécuter (RA:1051) | boss_imperiatrix | auto | Conforme | — |
| CRL002 | Klonos | Level up : choisit un autre boss, en garde le level up pour la partie (même si ce boss meurt) | RA:1518-1541 (`_klonos`, `copy_level_up` : copie dans `copiedLevelUps`, exécute l'effet tout de suite, un seul boss = automatique) ; BE:92-100 ; CD:262 ; M:996-999. Les joueurs éliminés sont exclus des choix (« another Boss » ne dit rien d'un boss éliminé : lecture prudente) | boss_klonos, boss_klonos_queues_choice | neutre (choix du boss : aucune règle écrite pour le départager) | Conforme | — |
| CRL003 | Mando | Level up : peut remonter une salle couverte au sommet d'une pile du donjon de chaque adversaire | RA:1544-1562 (file `mandoQueue`, un choix facultatif par adversaire) ; M:991-995 -> RA:1408-1421 (`uncover_move_to_top`) : l'effet « uncover » de la salle remontée n'appelle que `RoomAbilities.on_uncover`, donc les salles TNL (Arcane Crypt, Sorcerobe School, Shrooman Cave, Spiked Pit) ne déclenchent rien alors que le glossaire dit « returned to the top of the Room card stack by another effect » ; aucun poids IA : l'IA remonte la première salle couverte de chaque adversaire (parfois une Crash Site ou une Darkling Lair qui sert son propriétaire) | boss_mando | neutre | Corrigé (CRL) | Moyenne |
| CRL004 | Alien Excavator | À la construction, peut remonter une de ses salles couvertes (uncover) | RA:653 (`_alien_excavator`), 1388-1394, 1408-1421 ; M:988-989 ; même défaut que Mando (effets TNL « uncover » ignorés) ; aucun poids IA : l'IA remonte la première salle couverte même si elle est plus faible que celle qu'elle recouvre | room_alien_excavator | neutre | Corrigé (CRL) | Moyenne |
| CRL005 | Alien Ooze | +1 s'il y a une autre salle au trésor Explorer (un boss n'est pas une salle) | BE:451-457 : ignore les salles gelées mais compte une salle encore face cachée (la boucle des voisines, BE:436, les ignore) | room_alien_ooze | auto | Corrigé (CRL) | Basse |
| CRL006 | Decoy Garden | À la construction, gagne Explorer*2 jusqu'à la fin du tour | RA:654-658 (`extraTreasures` + [5, 5], cumulatif si The Omega 42 le rejoue) ; BE:50-58 ; effacé au début du tour (M:1285) | room_decoy_garden, start_turn_clears_temporary_treasure | poids (AW:259) | Conforme | — |
| CRL007 | Frostman Lander | Défaussée de la main : désactive une salle avancée de n'importe quel donjon jusqu'à la fin du tour | RA:1423-1447 (`hand_room_targets`, `use_hand_room`) ; M:330, 383, 691, 1664-1672 (BUILD et ADVENTURE) ; la désactivation est rangée par emplacement (`deactivatedRooms`, comme le gel de l'APK) : si Alien Excavator / Mando remonte ensuite une autre salle sur cet emplacement, la nouvelle salle du sommet hérite de la désactivation alors que le texte vise la carte désignée | room_frostman_lander | score (AI.gd:204-211) | Corrigé (CRL) | Basse |
| CRL008 | Invasion Swarm | Les salles adjacentes ont +1 | BE:446-447 (salles actives, ni gelées ni face cachées, texte non ignoré) | room_invasion_swarm | auto | Conforme | — |
| CRL009 | Reactor Core | Les salles avancées de votre donjon ont +1 | BE:448-449 | room_reactor_core | auto | Conforme | — |
| CRL010 | Digicron Library | À la construction, si au moins une autre salle avancée (elle comprise) : pioche 2 sorts | RA:659-666 (au moins 2 salles avancées visibles, elle comprise). Le texte se contredit lui-même (« at least one other [...] (including this one) ») : la lecture simple « au moins une autre avancée » est suivie | room_digicron_library | poids (AW:252) | Conforme | — |
| CRL011 | Hypercube | Se bâtit sur n'importe quelle salle, quel que soit le trésor | BE:162-164 (Neanderthal Cave bloque avant, BE:158-160 ; une salle face cachée ne se couvre pas) | room_hypercube | score de pose (APK) | Conforme | — |
| CRL012 | The Omega 42 | Une fois par tour, défausse une salle avancée pour rejouer un effet « build » ou « uncover » d'une salle de son donjon | RA:206, 265, 1450-1514 (choix de la salle, puis de la carte) ; M:1004-1009 ; cibles : `has_build_effect` / `has_uncover_effect` RA:1307-1316 = base, CRL, RMB, drapeaux `onBuild*` seulement : manquent les salles TNL (TNL016, 019, 024, 027, 029, 044 ; 036 et 052 passent par leurs drapeaux) et KSA010 Bone Crank ; en mode « uncover » (RA:1514) seul `RoomAbilities.on_uncover` est appelé, jamais `TnlAbilities.on_uncover` ; le rejeu d'une salle Monster fait aussi tirer Smoake (TA:460) alors que `rmbReplay` n'écarte que les boss RMB | room_omega_42, room_omega_42_choices | poids (AI.gd:252-262, 307) | Corrigé (CRL) | Moyenne |
| CRL013 | Crash Site | À la découverte, cherche une salle avancée dans la défausse et la prend en main | RA:1316, 1350, 1375-1386 (obligatoire, automatique s'il n'y a qu'une carte, choix sinon) | uncover_crash_site | poids (AW:253) | Conforme | — |
| CRL014 | Caged Gundarf | À la découverte, ses dégâts sont doublés jusqu'à la fin du tour | RA:1351-1356 (`roomDamageBonus` = dégâts du moment, modificateurs compris) ; BE:465-468 ; le bonus est rangé par emplacement : une salle remontée ensuite sur ce même emplacement (Excavator, Mando, Omega) hérite du doublement alors que la carte doublée est couverte (règle des compteurs, rules.md:2973 : une salle couverte perd ses compteurs) | uncover_caged_gundarf, uncover_caged_gundarf_modifiers | poids (AW:260) | Corrigé (CRL) | Basse |
| CRL015 | Celestial Map | À la découverte, pioche 1 sort puis se détruit | RA:1357-1362 (la salle du dessous est découverte à son tour : cascade) | uncover_celestial_map | poids (AW:261) | Conforme | — |
| CRL016 | Darkling Lair | À la découverte, 3 dégâts à un héros de votre donjon ou de votre entrée | RA:1363-1372 (choix s'il y a plusieurs héros) ; M:1000-1003 ; le héros actif est dans `entrance` (RA:1327) | uncover_darkling_lair | poids (AW:258) ; choix du héros neutre (tous les héros sont les siens) | Conforme | — |
| CRL017 | The Prince | Attiré par le plus bas total Âmes - Blessures ; une fois devenu blessure ou âme, le propriétaire du donjon peut piocher 2 salles, 2 sorts ou un de chaque | BE:219-220 ; TA:1417-1423 (choix facultatif, poids) ; M:2352-2353 | heroes_prince_king | poids | Conforme | — |
| CRL018 | Crash Dodgers | Explorer, 4 PV, 1 âme / blessure | cards.json (= JSON wiki) ; BE:`treasure_count` (trésor 5) | explorer_lure ; stats : aucune assertion | auto | Conforme | — |
| CRL019 | Corbin Crickton | Explorer, 4 PV | idem | explorer_lure | auto | Conforme | — |
| CRL020 | T'Matha | Explorer, 6 PV | idem | card_data (comptage) | auto | Conforme | — |
| CRL021 | Lindo Callari | Explorer, 6 PV | idem | card_data (comptage) | auto | Conforme | — |
| CRL022 | Doug O'Shibe, Ace Pilot | Explorer, 8 PV | idem | card_data (comptage) | auto | Conforme | — |
| CRL023 | Guy the Redrobe | Explorer, 8 PV | idem | card_data (comptage) | auto | Conforme | — |
| CRL024 | Andromeda James | Explorer épique, 11 PV, 2 âmes / blessures | idem | big_game_bait_split | auto | Conforme | — |
| CRL025 | Morgan Fragman | Explorer épique, 11 PV | idem | card_data (comptage) | auto | Conforme | — |
| CRL026 | Banzai Barb | Explorer épique, 13 PV | idem | card_data (comptage) | auto | Conforme | — |
| CRL027 | Aliff | Explorer épique, 13 PV | idem | card_data (comptage) | auto | Conforme | — |
| CRL028 | The King | Cleric épique 20 PV ; chaque joueur peut voter pour le donjon où il va (égalité : reste en ville) | BE:191-203 ; M:1462-1486 (`_king_vote`, un choix facultatif par joueur vivant) ; AW:236-247 ; jamais partagé à 5-6 joueurs (BE:`lure_split_targets`) | heroes_prince_king | poids | Conforme | — |
| CRL029 | Finish Him! | Tue un héros à 2 PV ou moins ; OU, avec moins d'âmes que tout joueur, prend face cachée un héros qui a survécu au donjon d'un autre joueur ce tour | SE:463-490 ; ST:208-228 ; « kill » = PV à 0, il meurt dans la salle (glossaire, arbitrages-wiki.md) ; l'IA note 100 tout héros ciblable, y compris celui d'un adversaire (il meurt alors chez lui et lui donne l'âme) | spell_finish_him | score constant (AI.gd:274) | Corrigé (CRL) | Basse |
| CRL030 | Essence Transfer | +X PV à un héros dans le donjon d'un adversaire, X = vos blessures | SE:492-502 ; ST:229-238 (« in a dungeon » = l'entrée, comme les sorts de l'APK) ; l'IA note 90 sans regarder si le héros mourait de toute façon | spell_essence_transfer | score constant (AI.gd:276) | Corrigé (CRL) | Basse |
| CRL031 | Healing Tank | Si aucun héros n'a été attiré chez vous à la phase d'appât, soigne une blessure ordinaire | SE:504-523 ; ST:239-241 ; `luredThisTurn` M:1639, 1655 (catégorie 3 : seulement en ADVENTURE, donc après l'appât) | spell_healing_tank | poids (AI.gd:250) | Conforme | — |
| CRL032 | Meteorite | Une salle de n'importe quel donjon gagne un trésor Explorer jusqu'à la fin du tour | SE:525-537 ; ST:25 | spell_meteorite, start_turn_clears_temporary_treasure | score (AI.gd:280-288) | Conforme | — |
| CRL033 | Not Dead Yet | X dégâts à chaque héros de votre donjon ou entrée, X = vos blessures | SE:539-552 ; ST:242-244 ; un héros tombé à 0 meurt dans sa première salle | spell_not_dead_yet | score constant (AI.gd:289) : jouée même quand elle ne tue ni ne sert à rien | Corrigé (CRL) | Basse |

### Règles propres à CRL

| Id | Règle (source) | Code | Golden | Statut | Priorité |
|---|---|---|---|---|---|
| CRL-R01 | Composition : 3 boss, 13 salles (23 exemplaires), 5 sorts (7), 12 héros (7 ordinaires + 5 épiques) | `cards.json` ; M:`new_match` | card_data, new_match_deck | Conforme | — |
| CRL-R02 | Cinquième trésor, Alien Artifact / Explorer (livret p.1) | CD:17 (`TREASURE_NAMES`), BE:`treasure_count` ; BoardUI.gd:2468 (pas d'icône, compte affiché s'il y en a) | explorer_lure | Conforme | — |
| CRL-R03 | « Uncover » : une salle est découverte quand celle du dessus est détruite ou remontée au sommet par un autre effet (livret p.1, glossaire) | BE:603-609 (destruction : base, CRL, TNL, RMB) ; RA:1408-1421 (remontée : base, CRL, RMB seulement, pas TNL) ; RA:1514 (Omega) | uncover_*, room_alien_excavator, boss_mando | Corrigé (CRL) | Moyenne |
| CRL-R04 | 5-6 joueurs avec CRL, avec un jeu de base complet (BMR, TNL ou RMB) : 25 + 7 ordinaires, 16 (BMR) ou 17 (TNL, RMB) + 5 épiques (lignes 3003-3050, 3643) ; les mini-extensions (THK, IOD) se combinent à tout jeu de base (lignes 3744-3761) ; trois Objets par tour à 5-6 (ligne 2859, « with or without CRL ») | M:18-34 (`BIG_GAME_SETS` = base, Hidden Heroes, Tools, CRL ; TNL, Minibosses, THK wiki, IOD refusés par `setup_error`, écartés par `new_match` :62-66) ; CD:20-21 (`HERO_COUNTS` 32 + 21 seulement) ; M:154-155 (contrôle 32 + 21) ; TA:628-640 (`limit_heroes` borné à 4 joueurs) ; Server.gd:336, OnlineMenus.gd:29, PROTOCOL.md:16 | big_game_setup (asserte le refus) | Corrigé (CRL) | Moyenne |
| CRL-R05 | Paquet de héros du jeu de base à 5-6 joueurs : 32 + 21 (BMR, Hidden Heroes), icônes de joueurs respectées, les 12 héros CRL tous là | M:91-121, 147-155 | big_game_setup | Conforme | — |
| CRL-R06 | 2-4 joueurs avec CRL : le paquet de base de n joueurs, plus les 12 héros CRL (le livret ne retire que les icônes 3 / 4 joueurs) | M:91-121 (base) ; avec TNL ou RMB, `limit_heroes` (M:148-150, TA:632) coupe aussi les héros CRL : une sonde donne 4 + 1 héros CRL à 2 joueurs avec TNL (3 + 2 avec RMB), 6 + 3 à 4 joueurs, au lieu de 7 + 5 | crl_heroes_2_to_4 (base seulement) | Corrigé (CRL) | Moyenne |
| CRL-R07 | 5-6 joueurs : plus d'élimination à 5 blessures | M:2345, 2379 ; CD:29-31 ; ApkAI.gd:1252 | big_game_no_elimination | Conforme | — |
| CRL-R08 | 5-6 joueurs : fin de partie à la fin du tour où un joueur a 10 âmes ou quand les pioches de héros ordinaires et épiques sont vides (des héros peuvent rester en ville) | M:2467-2493 (`_check_end_big_game`) | big_game_end_and_winner | Conforme | — |
| CRL-R09 | 5-6 joueurs : gagnant = meilleur Âmes - Blessures de tous les joueurs ; égalité : l'XP la plus basse | M:2467-2515 (`_tie_break_players(.., true)`) ; le commentaire CD:24 (« départ à l'XP la plus basse ») est faux, c'est le départage | big_game_end_and_winner, tie_break_xp_direction | Conforme | — |
| CRL-R10 | 5-6 joueurs : égalité de trésors = les héros du type sont partagés (autant que de joueurs à égalité, du plus ancien au plus haut XP, on recommence) ; sinon restent en ville | BE:238-290 (`lure_split_targets`) ; M:1637-1660 ; AW:75 | big_game_bait_split | Conforme | — |
| CRL-R11 | 2-4 joueurs avec CRL : l'égalité laisse toujours le héros en ville (inchangé) | BE:`lure_target` ; M:`_resolve_bait` | big_game_bait_split (4 joueurs), explorer_lure | Conforme | — |
| CRL-R12 | Un héros par joueur révélé à chaque tour, trois Objets par tour à 5-6 | M:1334-1360, ThkAbilities.gd:120-131 | big_game_setup | Conforme | — |
| CRL-R13 | Sans Crash Landing, IOD retire les Objets Explorer et Banseer Bivan (lignes 2743, 2933) | M:72-74, 137 | iod `gating` | Conforme | — |
| CRL-R14 | 2-4 joueurs avec CRL : fin « héros épuisés » reprise du livret mais gardée (aucun héros attiré ni à l'entrée) pour qu'un Explorer inattirable ne bloque pas la partie | M:2435-2446 (justifié dans le commentaire) | end_of_game_stuck_town, heroes_exhausted_end_not_in_apk_mode | Conforme | — |
| CRL-R15 | 5-6 joueurs sans Crash Landing avec deux boîtes de base (ligne 3526 : « unofficial guidelines », variante Unlimited Lives, héros supplémentaires) | `setup_error` le refuse ; Unlimited Lives existe (Variants.gd) mais pas le paquet de héros du guide | — | Non implémenté | Basse |

### Synthèse du lot CRL

33 cartes : 24 Conforme, 9 Écart (3 Moyenne, 6 Basse), 0 Non implémenté, 0 Haute (état de l'audit ; tous les écarts sont ensuite corrigés, voir ci-dessous). Par type : 3 boss (2 Conforme, 1 Écart), 13 salles (8 Conforme, 5 Écart), 5 sorts (2 Conforme, 3 Écart), 12 héros (12 Conforme). Règles : 15 lignes, 11 Conforme, 3 Écart (Moyenne : CRL-R03, CRL-R04, CRL-R06), 1 Non implémenté (Basse : CRL-R15, hors CRL). Goldens : les 33 cartes apparaissent dans `goldens_crl.gd`, mais les dix Explorers et les statistiques de toutes les cartes ne sont que comptés (card_data) : aucun test table par table des PV, trésors, âmes, dégâts.

Écarts Moyenne :

- CRL003 Mando, CRL004 Alien Excavator, CRL-R03 : une salle remontée au sommet ne déclenche pas son effet « uncover » TNL (RA:1408-1421).
- CRL012 The Omega 42 : ne propose pas les salles TNL ni Bone Crank, ne rejoue pas l'effet TNL en mode « uncover », fait tirer Smoake.
- CRL-R04 : 5-6 joueurs refusés avec TNL, Minibosses, THK wiki, IOD alors que le livret les combine à CRL.
- CRL-R06 : héros CRL coupés par `limit_heroes` en 2-4 joueurs avec TNL ou RMB.

Écarts Basse :

- CRL005 Alien Ooze compte une salle face cachée.
- CRL007 Frostman Lander et CRL014 Caged Gundarf : l'état rangé par emplacement passe à la salle remontée par Excavator / Mando / Omega.
- CRL029, CRL030, CRL033 : notes IA constantes (Finish Him! sert l'adversaire, Essence Transfer et Not Dead Yet jouées sans effet utile) ; Mando et Excavator sans poids.
- CRL-R15 : 5-6 joueurs sans CRL (guide non officiel, hors règles de Crash Landing).

Ordre de correction proposé, par thème :

1. Paquets de héros : CRL-R06 (les héros CRL ne passent plus par `limit_heroes`), puis CRL-R04 (accepter TNL, Minibosses, THK wiki, IOD à 5-6 joueurs, 32 + 22 avec TNL / RMB).
2. « Uncover » : CRL-R03 / CRL003 / CRL004 en un seul point partagé (`uncover_move_to_top`, Omega), Eclipse écarté (« when you destroy »), CRL012 (cibles TNL et Bone Crank, pas de Smoake au rejeu).
3. États par emplacement : CRL007, CRL014 (effacés quand la salle de l'emplacement change par remontée), CRL005.
4. IA : poids de CRL003, CRL004, CRL029, CRL030, CRL033.
5. Golden table par table des statistiques CRL.

Points non tranchés (aucun code changé) :

- CRL010 Digicron Library : « at least one other Advanced Room [...] (including this one) » se contredit ; la lecture simple est gardée. Ce n'est pas un conflit entre le texte et le livret (le livret ne cite pas la carte).
- CRL029 Finish Him! : « Kill » laisse le héros mourir dans sa prochaine salle (glossaire « The Room in which a Hero is reduced to zero Health [...] » et arbitrage déjà tranché).
- CRL-R15 : le paragraphe de la ligne 3526 est un guide non officiel qui n'est pas une règle de Crash Landing ; ni l'APK, ni le livret, ni le wiki ne le définissent, donc rien à porter.
- Non vérifié : les textes imprimés des cartes (scans), l'affichage à six sièges (ui_smoke seulement), le comportement en ligne à six joueurs au-delà d'`online_test`.

### CRL : corrections (2026-10-28)

Les 9 écarts de cartes et les 3 écarts de règles sont corrigés (statut `Corrigé (CRL)`), sans écart accepté. CRL-R15 reste `Non implémenté` : c'est un guide non officiel, pas une règle de Crash Landing, et rien (APK, livret, wiki) ne le définit. Aucun conflit entre texte de carte et livret / FAQ.

- CRL-R06 : les héros CRL ne passent plus par `limit_heroes` en 2-4 joueurs avec TNL ou RMB, ils s'ajoutent au paquet du livret (Match.gd:149-158, `is_crl`). Golden `crl_heroes_with_tnl_rmb`.
- CRL-R04 : 5-6 joueurs admis avec TNL, Minibosses, THK wiki et IOD (Match.gd:19, `BIG_GAME_SETS` ; message Match.gd:25, OnlineMenus.gd `BIG_GAME_MSG`, PROTOCOL.md:16) ; Player's Choice reste refusé. Pool 32 + 22 avec TNL / RMB (Match.gd:162-164, `want_epics`). Goldens `big_game_tnl_rmb`, `big_game_setup`, `online_test` (refus PC, 5 et 6 sièges) ; trois soaks 5-6 joueurs ajoutés (tools/run_godot_tests.py).
- CRL-R03, CRL003 Mando, CRL004 Alien Excavator : un seul point d'« uncover » (RoomAbilities.gd:1431 `fire_uncover`, appelé par `uncover_move_to_top` :1408 et `omega_finish` :1508) qui joue l'effet de la salle puis l'effet TNL ; le doublon dans Laser Drill IOD est retiré. Eclipse ne réagit qu'à une destruction (TnlAbilities.gd:471 `by_destroy`). `has_uncover_effect` / `has_build_effect` couvrent les salles TNL (RoomAbilities.gd:1307-1320, TnlAbilities.gd:493-499). Goldens `uncover_by_move_fires_tnl`.
- CRL007 Frostman Lander, CRL014 Caged Gundarf : `uncover_move_to_top` efface `deactivatedRooms` et `roomDamageBonus` de l'emplacement dont la salle change (RoomAbilities.gd:1408-1430). Golden `uncover_by_move_clears_slot_state`.
- CRL012 The Omega 42 : propose les salles TNL (hors `no_text`) et Bone Crank, rejoue l'effet « uncover » TNL, et Smoake ne tire plus au rejeu (RoomAbilities.gd:1464 `_omega_42`, :1523 `rmbReplay` ; TnlAbilities.gd:460). Golden `omega_42_tnl_rooms`.
- CRL005 Alien Ooze : une salle face cachée n'est plus comptée (BossEngine.gd:455). Golden `room_alien_ooze_face_down`.
- CRL003, CRL004, CRL029, CRL030, CRL033 (IA) : poids de la remontée (AI.gd:250, AiWiki.gd:267 `uncover_value`) ; Finish Him! ne tue plus un héros adverse, sert le sien qui atteindrait le boss (AI.gd:276) ; Essence Transfer seulement si les PV font survivre un héros adverse (AI.gd:282) ; Not Dead Yet seulement si X dégâts tuent un de mes héros qui atteindrait le boss (AI.gd:297) ; aides AiWiki.gd:249-266. Golden `ai_crl_weights`.
- Commentaires faux corrigés (CardDB.gd:24, ThkAbilities.gd:125).
- Statistiques des 33 cartes : golden table par table `card_stats` (valeurs attendues écrites dans le test et comparées champ par champ au JSON du wiki).

## RMB : audit carte par carte (2026-10-28)

Audit en lecture seule ; les corrections sont dans la section « RMB : corrections » ci-dessous. Référence, dans l'ordre : texte de la carte (`assets/data/expansions/minibosses.json`, tiré du wiki), manuel commun TNL / RMB (`docs/rules/rules.md`, section « Minibosses » ligne 1600, mise en place 3055-3070, variantes 3477, pile lignes 21 et 131), arbitrages de `docs/rules/arbitrages-wiki.md` ; pour les mécaniques de base, l'APK déjà porté. Les statistiques des 121 cartes sont comparées champ par champ au JSON du wiki par le golden `rmb_card_stats` ; les heros n'ont aucun texte dans le JSON (sauf les cinq dont la capacité est codée d'après une paraphrase du wiki).

Abréviations (dossier `src/frontend/godot/scripts/`) : MB = Minibosses.gd, RB = RmbAbilities.gd, RS = RmbSpells.gd, BE = BossEngine.gd, TA = TnlAbilities.gd, M = Match.gd, RA = RoomAbilities.gd, SE = SpellEffects.gd, ST = SpellTargeting.gd, CD = CardDB.gd. Goldens : noms des fonctions `_t_*` de `tests/goldens_rmb.gd` (sans le préfixe). IA : « poids / score » = `AI.gd` / `AiWiki.gd` note les options, « auto » = effet sans décision, « neutre » = aucune note (l'IA prend la première option). Les références de code sont celles de la lecture de chaque chemin, les numéros de ligne datent de l'audit.

### Cartes (121)

| Id | Carte | Texte (résumé) | Code | Golden | IA | Statut | Priorité |
|---|---|---|---|---|---|---|---|
| RMB001 | Gregore | Level up : For the rest of the game, once per turn gain (c) when you kill a hero. | M:2334, RB:180, RA:983 | boss_coin_triggers, boss_flags_and_klonos | neutre | Conforme | — |
| RMB002 | Calabeza | Level up : For the rest of the game, once per turn you may discard a Monster Room to promote a Miniboss instead of paying (c). | MB:360 | boss_flags_and_klonos, calabeza_promote, promote | neutre | Conforme | — |
| RMB003 | Belladonna | Level up : For the rest of the game, once per turn you may pay (c)(c) to force an opponent to discard a randon Spell card. | RB:487, RB:546 | boss_active_powers, boss_flags_and_klonos | neutre | Conforme | — |
| RMB004 | Lamia | Level up : For the rest of the game, gain (c) whenever you build a Monster Room. | RB:222 | boss_coin_triggers, boss_flags_and_klonos, spells_rooms | neutre | Conforme | — |
| RMB005 | King Croak | Level up : For the rest of the game, Minibosses that you build start on Level 2. | MB:155 | boss_flags_and_klonos, reveal_and_discard | neutre | Conforme | — |
| RMB006 | Ravenus | Level up : For the rest of the game, once per turn you may pay (c)(c) to double the damage value of a Monster Room. | RB:489, RB:548 | boss_active_powers, boss_flags_and_klonos | neutre | Conforme | — |
| RMB007 | Baron Hex | Level up : For the rest of the game, gain (c) whenever you cast a Spell. | MB:691 | boss_coin_triggers, boss_flags_and_klonos | neutre | Conforme | — |
| RMB008 | Oculus | Level up : For the rest of the game, draw a Spell when a Hero dies in a room with a Miniboss. | MB:656 | boss_coin_triggers, boss_flags_and_klonos | neutre | Conforme | — |
| RMB009 | Kazanna | Level up : For the rest of the game, once per turn you may pay (c)(c) to draw a Spell card. | RB:491, RB:550 | boss_active_powers, boss_flags_and_klonos | neutre | Conforme | — |
| RMB010 | Dr. Deadly | Level up : For the rest of the game, gain (c) whenever you build a Trap Room. | RB:224 | boss_coin_triggers, boss_flags_and_klonos | neutre | Conforme | — |
| RMB011 | Scott | Level up : For the rest of the game, your Trap Rooms have +1. Any opponents may give you (c) to cancel this ability until the end of your turn. | BoardUI.gd:3632, MB:245, RB:505, RB:506 | boss_flags_and_klonos, boss_oculus_croak_scott, fix_sabotage_cuts_miniboss_text | neutre | Conforme | — |
| RMB012 | Kirax | Level up : For the rest of the game, once per turn you may pay (c)(c) to add one of any treasure type to any player's dungeon | BE:82, RB:493, RB:552, RA:983 ; écart : « any treasure type » : Explorer manquait avec CRL (RB:681 `[1, 2, 3, 4]`) | boss_active_powers, boss_flags_and_klonos | neutre | Corrigé (RMB) | Basse |
| RMB013 | Spectral Bomb | You may destroy this Room to force an opponent to discard a random Spell card. | RB:336, RB:403 | rooms_destroy_for_coins, rooms_triggers | neutre | Conforme | — |
| RMB014 | Monster Academy | When you build or uncover this Room, gain (c) (c) for every miniboss you reveal from your hand. | RB:267 | rooms_build_effects, rooms_uncover_effects | neutre | Conforme | — |
| RMB015 | Ancient Guardtower | When you build this Room, choose one opponent. Once this turn you may give them (c) to take one random Spell card from them. | RB:274, RB:339 ; écart : `randi()` global pour le sort pris au hasard (RB:414) : tirage non reproductible, hors du générateur du moteur | rooms_build_effects, rooms_uncover_effects | neutre | Corrigé (RMB) | Basse |
| RMB016 | Tomb of Terrors | You may discard this from your hand to draw a room or spell card from the Discard pile. | RB:514, RB:573 | fix_draculad_no_miniboss, fix_tomb_no_miniboss, rooms_hand_abilities | neutre | Conforme | — |
| RMB017 | Imp Hoard | Once per turn when an opponent discards a card, you may put it in your hand. | M:878, MB:725, RA:381, RA:525 | rooms_triggers | neutre | Corrigé (RMB) | Basse |
| RMB018 | Vampire Lab | When you build or uncover this Room, you may discard a Miniboss to heal a Wound. | RB:279 | rooms_build_effects, rooms_uncover_effects | neutre | Conforme | — |
| RMB019 | Haunted Cavern | Once per turn, You may pay (c) and choose a hero at the entrance to your dungeon. It cannot enter your dungeon until next turn. | M:789, M:2115, RB:344, RB:418 | rooms_paywall_cavern_guardtower, stack_probe_identity | neutre | Conforme | — |
| RMB020 | Minion Clinic | When you build this Room, place up to three (c) on it. For each (c) you place, choose one card from the discard pile and put it in your hand. This Room has -1 for every (c) on it. | RB:140, RB:282 ; écart : Coins posés sur la salle invisibles à l'écran (DungeonSlot.gd:123) | rooms_build_effects, rooms_uncover_effects | neutre | Corrigé (RMB) | Basse |
| RMB021 | Robber's Vault | When you build this room, exchange your Hoard with another player's, even if you have no coins. | RB:285 | rooms_build_effects, rooms_uncover_effects | neutre | Conforme | — |
| RMB022 | Minotaur Catacombs | Destroy this Room to return a Hero in it to the beginning of your Dungeon. | RB:347, RB:422 | rooms_destroy_for_coins | neutre | Conforme | — |
| RMB023 | Goblin Market | Whenever you build a Room next to this Room, gain (c)(c). | RB:244 | rooms_passive_damage | neutre | Conforme | — |
| RMB024 | Power Leech | If the Room to the right of this is a Monster Room, give that room +2. | RB:130 | rooms_passive_damage | neutre | Conforme | — |
| RMB025 | Fetid Beast | Monster Rooms may not be built adjacent to this room. (But this Room may be built adjacent to other Monster Rooms.) | BE:142, RB:108, RB:110 | rooms_passive_damage | neutre | Corrigé (RMB) | Basse |
| RMB026 | Training Camp | Once per turn, you may discard a Miniboss to double the damage of one of your Monster Rooms until end of turn. | RB:350, RB:425 | rooms_discard_and_coin_costs | neutre | Conforme | — |
| RMB027 | Shrooman Aviary | You may discard this from your hand to give one hero +3 until end of turn. | RB:517, RB:579 | rooms_hand_abilities | neutre | Conforme | — |
| RMB028 | Dragon's Nest | When you build or uncover this Room, until end of turn, give every other Monster Room in your dungeon +1 for every treasure icon that room has. | RB:292 | rooms_build_effects, rooms_uncover_effects | neutre | Conforme | — |
| RMB029 | Doppelganger Hive | This room has +1 for every Hero that was lured to your dungeon this turn. | RB:134 | rooms_passive_damage | neutre | Conforme | — |
| RMB030 | Foyer Elemental | Once per turn when a Hero survives this Room, gain (c) (c). | RB:190 | rooms_hero_dependent | neutre | Conforme | — |
| RMB031 | Mysterious Portal | When you build or uncover this Room, you may discard a Miniboss to draw a Spell card. | RB:298 | rooms_build_effects, rooms_uncover_effects | neutre | Conforme | — |
| RMB032 | Alchemist's Lab | Once per turn, when you cast a Spell, gain (c) (c). (Cancelled spells are not cast.) | MB:695 | boss_coin_triggers | neutre | Corrigé (RMB) | Basse |
| RMB033 | Black Market | Once per turn, when a Room in any dungeon is destroyed, pay (c) to draw a spell card. | RB:163 | rooms_triggers | neutre | Corrigé (RMB) | Basse |
| RMB034 | Mind Thresher | Once per turn if a Hero dies in this Room, you may remove that Hero from the game to draw two Spell cards. | RB:200, RB:698 | fix_build_slot_shift, fix_mind_thresher_once, rooms_hero_dependent | neutre | Corrigé (RMB) | Basse |
| RMB035 | Cursed Well | You may discard this from your hand to draw a Spell card or gain (c) (c). | RB:520, RB:584 | rooms_hand_abilities | neutre | Conforme | — |
| RMB036 | Loot Box | When you build this Room, pay (c)(c) and draw two Spell cards. | RB:301 | rooms_build_effects, rooms_uncover_effects | neutre | Conforme | — |
| RMB037 | Crystal Ballroom | When you build this Room, place up to three (c) on it. For each (c) you place, draw one Spell card. This Room has -1 for every (c) on it. | RB:140, RB:304 ; écart : Coins posés sur la salle invisibles à l'écran (DungeonSlot.gd:123) | rooms_build_effects, rooms_uncover_effects | neutre | Corrigé (RMB) | Basse |
| RMB038 | Efreet's Chamber | Once per turn when a Hero is at the entrance to your dungeon, you may draw a Spell card to give this room -2 OR discard a Spell to give this room +2. | RB:353, RB:428 | rooms_efreet_blackmarket | neutre | Conforme | — |
| RMB039 | Magipede | This room has +1 for every Spell card in your hand. | RB:136 | rooms_passive_damage | neutre | Conforme | — |
| RMB040 | Delver's Quarry | When you build or uncover this Room, draw a Room card. | RB:307 | level_two_triggers, rooms_build_effects, rooms_uncover_effects | neutre | Conforme | — |
| RMB041 | Garbage Chute | Once per turn when a Room is destroyed, gain (c) (c). | RB:159 | rooms_triggers | neutre | Corrigé (RMB) | Basse |
| RMB042 | Unstable Mine | You may destroy this Room to gain (c) (c) (c). | RB:436, RB:887 | rooms_destroy_for_coins | neutre | Conforme | — |
| RMB043 | Sawtooth Pendulum | Once per turn, you may pay (c) to kill a Hero in this Room with 3 or less Health. | RB:356, RB:439 | rooms_hero_dependent | neutre | Conforme | — |
| RMB044 | The Catapult | Once per turn, you may discard a Miniboss to deactivate a Room in an opponent's dungeon. | RB:360, RB:445 | rooms_discard_and_coin_costs | neutre | Conforme | — |
| RMB045 | Endless Gallery | You can destroy this room to add one treasure of any type to any player's dungeon until end of turn. | BE:82, RB:448, RB:890 ; écart : « treasure of any type » : Explorer manquait avec CRL (RB:681) | rooms_destroy_for_coins | neutre | Corrigé (RMB) | Basse |
| RMB046 | Paywall | Each turn, any player may give you any number of (c). For every (c) they give you, give this Room -1 until end of turn. | RB:509 | rooms_paywall_cavern_guardtower | neutre | Conforme | — |
| RMB047 | Living Trap | You may destroy a Monster room in your dungeon to kill a hero in this Room. | RB:363, RB:454 | rooms_hero_dependent | neutre | Conforme | — |
| RMB048 | The Dreadmill | Once per Build phase, place a (c) on this Room. This Room has +1 for every (c) on it. If you cannot place a coin on this Room, destroy it. | MB:680, RB:138 ; écart : Coins posés sur la salle invisibles à l'écran (DungeonSlot.gd:123) | rooms_passive_damage | neutre | Corrigé (RMB) | Basse |
| RMB049 | Personnel Office | Once per turn gain (c) when an opponent plays or promotes a Miniboss. | RB:172 | rooms_build_effects, rooms_triggers | neutre | Corrigé (RMB) | Basse |
| RMB050 | Trophy Room | When you build or uncover this Room, Gain (c) for every multi-treasure Room in your dungeon, including this one. | RB:309 | rooms_build_effects, rooms_uncover_effects | neutre | Conforme | — |
| RMB051 | Lightning Rod | Once per turn, if a Hero dies in this Room, gain (c)(c)(c). | RB:200, RB:205 | rooms_hero_dependent | neutre | Corrigé (RMB) | Basse |
| RMB052 | Pixie Fountain | You may destroy this Room to gain (c) for every Wound you have. | RB:366, RB:457 | rooms_destroy_for_coins | neutre | Conforme | — |
| RMB053 | The Keystone | You may destroy this Room to gain (c) for every Room remaining in your dungeon. | RB:461, RB:894 | rooms_destroy_for_coins | neutre | Conforme | — |
| RMB054 | Pool of Shadows | Once per turn, you may discard a Spell to gain (c) (c). | RB:369, RB:464 | rooms_discard_and_coin_costs, spells_rooms | neutre | Conforme | — |
| RMB065 | Windfall | If you have no coins in your Hoard, gain (c)(c)(c). | RS:3, RS:133, SE:58, ST:420 | boss_coin_triggers, spell_phases_and_targets, spells_economy | neutre | Conforme | — |
| RMB066 | Internship | Place the top three cards of the Room deck in the discard pile. If one of these cards is a Miniboss, you may immediately build it. (In addition to your normal build turn.) | RS:137, RS:338 | spell_phases_and_targets, spells_rooms | neutre | Conforme | — |
| RMB067 | Spirit Dragon | Choose a Room in any dungeon. Until end of turn, it has one of each treasure type instead of its normal treasure. | BE:54, RS:160, RS:339 | spell_phases_and_targets, spells_rooms | neutre | Conforme | — |
| RMB068 | Sabotage! | Choose a Room. Until end of turn it has no ability text. OR, if if you have more Minibosses than your opponent, deactivate that Room until end of turn./ | RS:165, RS:342 | fix_build_slot_shift, fix_pay_without_cap, fix_sabotage_cuts_miniboss_text | neutre | Conforme | — |
| RMB069 | Rage! | Choose a Miniboss. For every level that Miniboss has, give its Room +1 until end of turn. AND, if you have only one Miniboss, you may then double the damage of that Room. | RS:176, RS:343 | spell_phases_and_targets, spells_heroes | neutre | Conforme | — |
| RMB070 | Ambush | Yo may discard two Monster Room cards or one Miniboss card to kill one Hero in your dungeon. | RS:185, RS:344 | spell_phases_and_targets, spells_heroes | neutre | Conforme | — |
| RMB071 | Rebirth | Chose a player (including yourself). That playwe discards their hand and draws Rooms and Spells equal to the number of each they discarded. | RS:192, RS:345 | spell_phases_and_targets, spells_economy | neutre | Conforme | — |
| RMB072 | Smash! | Deal 2 damage to a Hero in your dungeon. OR deal 4 damage to a Hero in a Room that contains a Miniboss. | RS:211, RS:346 | spell_phases_and_targets, spells_heroes | neutre | Conforme | — |
| RMB073 | Pay to Win | Choose a Room to gain +1 until end of turn, plus an additional +1 for each (c) you pay when you cast this spell. | RS:219, RS:347 ; écart : « Choose a Room » : seules les salles du lanceur étaient proposées (RS:81-86) | fix_pay_without_cap, fix_tomb_no_miniboss, spell_phases_and_targets | neutre | Corrigé (RMB) | Basse |
| RMB074 | Zoning Board | For your build turn, you may build an Advanced Room on top of any other Room, ignoring matching treasure icon requirements. | BE:166, RS:226, RS:348 | spell_phases_and_targets, spells_rooms, spells_stack_and_traitor | neutre | Conforme | — |
| RMB075 | Respawn | Treat all of your Rooms as if they were just built. | RS:229, RS:349 | spell_phases_and_targets, spells_rooms | neutre | Conforme | — |
| RMB076 | Heist | Choose a Room in any dungeon. Until end of turn end that Room's treasure icons. | RS:240, RS:350 | spell_phases_and_targets, spells_rooms | neutre | Conforme | — |
| RMB077 | Short Circuit | Choose an opponent casting a spell. Until end of turn, that opponent must pay (c) for each spell they wish to cast. If they don't, that spell is cancelled. | CD:347, M:1881, RS:245, RS:353 | spell_phases_and_targets, spells_stack_and_traitor | poids/score (AI:189, AI:191) | Conforme | — |
| RMB078 | Traitor | Choose an opponent's Miniboss. You may pay that opponent one (c) per that Miniboss's Level to take it and immediatly build it at that same level. You may not build a room this turn. | RS:248, RS:356 | spell_phases_and_targets, spells_stack_and_traitor | neutre | Conforme | — |
| RMB079 | Armor Up! | Give a Hero +1 until end of turn AND give this Hero an additional +2 until end of turn for every (c) you spend when casting this spell. | RS:3, RS:259, SE:58, ST:420 | fix_pay_without_cap, fix_tomb_no_miniboss, spell_phases_and_targets | neutre | Conforme | — |
| RMB055 | Spike | L1: This Room has +1. / L2: Once per turn, discard a card to do 2 damage to a Hero in this Room. / L3: Choose a Miniboss. Return that card to its owner's hand. Reset to Level One. | MB:432, MB:447 | boss_coin_triggers, build_miniboss, build_restrictions | neutre | Conforme | — |
| RMB056 | Kid Croak | L1: This Room gains +1 Fighter. / L2: Once per turn during the Build phase, you may switch the position of two Rooms in any dungeon. / L3: Give all Monster Rooms in one dungeon +1 or -1 until end of turn. Reset to Level One. | MB:435, MB:450 | attached_to_top_room, build_restrictions, calabeza_promote | neutre | Conforme | — |
| RMB057 | Draculad | L1: This Room gains +1 Cleric. / L2: Once per turn, you may return a Hero in your dungeon to town. / L3: Look at one opponent's hand. You may take one Spell or Room card from them. Reset to Level One. | MB:438, MB:458 | destroyed_miniboss, fix_draculad_no_miniboss, fix_mind_thresher_once | neutre | Conforme | — |
| RMB058 | Rocky | L1: You may build any Room on top of this one, regardless of treasure icon. / L2: When a Hero dies in this Room, you may treat another Room in your dungeon as just built. / L3: Give a Hero in any dungeon +5 until end of turn. Reset to Level One. | BE:166, MB:273, MB:461 | attached_to_top_room, boss_flags_and_klonos, calabeza_promote | neutre | Corrigé (RMB) | Basse |
| RMB059 | Cerebella | L1: This Room gains +1 Mage. / L2: When a Hero dies in this Room, you may draw a Spell card. / L3: Choose a dungeon. Heroes ignore all ability text in that dungeon until end of turn. Reset to Level One. | BE:351, MB:565, MB:569 | destroyed_miniboss, fix_sabotage_cuts_miniboss_text, level_one_passives | neutre | Corrigé (RMB) | Basse |
| RMB060 | Paddywhack | L1: This Room gains +1 Thief. / L2: Once per turn when you gain one or more coins, gain one extra coin. / L3: Kill a Hero in this Room. Reset to Level One. | MB:78, MB:464 | level_one_passives, level_three_each, level_two_triggers | neutre | Corrigé (RMB) | Basse |
| RMB061 | Icicle Man | L1: This Room has +1. / L2: Ignore the ability text of any Heroes or Epic Heroes in, or at the entrance to, your dungeon. / L3: Deactivate a Room in any dungeon until end of turn. Reset to Level One. | BE:351, MB:256, MB:467 | heroes, level_one_passives, level_three_each | neutre | Corrigé (RMB) | Basse |
| RMB062 | Mageseeker | L1: This Room has +1 for every treasure icon it has. / L2: Once per turn, you may discard a Spell card to cancel an opponent's Spell. / L3: Choose a dungeon. Until end of turn, Heroes entering that dungeon skip its first room. Reset to Level One. | MB:238, MB:565 | level_one_passives, level_three_each, level_two_activations | neutre | Conforme | — |
| RMB063 | Brassknuckle | L1: This Room has +1. / L2: Once per turn when a Hero dies in this Room, draw a Room card. You may immediately build that Room. / L3: Double this Room's damage until end of turn. Reset to Level One. | MB:580, MB:644 | activation_guards, level_one_passives, level_three_each | neutre | Corrigé (RMB) | Basse |
| RMB064 | Jinx | L1: Draw an extra Room at the beginning of the Build phase, then discard a Room. / L2: Double this Room's treasure value. (It has one extra copy of each printed treasure icon it has.) / L3: Choose a Hero in town. Place it at the entrance to your dungeon. Reset to Level One. | MB:222, MB:470 | level_one_passives, level_three_each, level_two_activations | neutre | Conforme | — |
| RMB080 | Felicity, Joyful Nurse | Cleric, 4 PV, trésor 1, 1 âme(s) ; aucun texte imprimé | cards.json (statistiques) | boss_coin_triggers, boss_flags_and_klonos, heroes | auto | Conforme | — |
| RMB081 | Wolfhard, Teen Hero | Cleric, 4 PV, trésor 1, 1 âme(s) ; aucun texte imprimé | cards.json (statistiques) | boss_coin_triggers, level_two_triggers | auto | Conforme | — |
| RMB082 | Holkin, Propheteer | Cleric, 6 PV, trésor 1, 1 âme(s) ; aucun texte imprimé | cards.json (statistiques) | level_two_triggers | auto | Conforme | — |
| RMB083 | Luz, Merciful Healer | Cleric, 6 PV, trésor 1, 1 âme(s) ; aucun texte imprimé | cards.json (statistiques) ; texte « When Luz is around, heroes only sometimes die » : aucune règle déterministe (arbitrages-wiki.md:26) | level_two_triggers | auto | Non implémenté | Basse |
| RMB084 | Inquisitor | Cleric, 6 PV, trésor 1, 1 âme(s) ; capacité codée d'après la paraphrase du wiki (arbitrages-wiki.md) | TA:12 | boss_coin_triggers, heroes | auto | Conforme | — |
| RMB085 | Josie, Vampire Slayer | Cleric, 8 PV, trésor 1, 1 âme(s) ; aucun texte imprimé | cards.json (statistiques) | level_two_triggers, rooms_destroy_for_coins | auto | Conforme | — |
| RMB086 | Tess, Dwarven Shieldmaiden | Fighter, 4 PV, trésor 2, 1 âme(s) ; aucun texte imprimé | cards.json (statistiques) | boss_coin_triggers, rooms_hero_dependent | auto | Conforme | — |
| RMB087 | Steven the Human | Fighter, 4 PV, trésor 2, 1 âme(s) ; aucun texte imprimé | cards.json (statistiques) | level_two_activations, rooms_hero_dependent | auto | Conforme | — |
| RMB088 | Rotgut, Half-Giant Berserker | Fighter, 6 PV, trésor 2, 1 âme(s) ; aucun texte imprimé | cards.json (statistiques) | level_two_activations, rooms_hero_dependent | auto | Conforme | — |
| RMB089 | Maxine, Sister of Steel | Fighter, 6 PV, trésor 2, 1 âme(s) ; aucun texte imprimé | cards.json (statistiques) | rooms_hero_dependent | auto | Conforme | — |
| RMB090 | Sellsword | Fighter, 6 PV, trésor 2, 1 âme(s) ; aucun texte imprimé | cards.json (statistiques) | fix_mind_thresher_once, fix_sabotage_cuts_miniboss_text, heroes | auto | Conforme | — |
| RMB091 | Joe the Smith | Fighter, 8 PV, trésor 2, 1 âme(s) ; aucun texte imprimé | cards.json (statistiques) | fix_mind_thresher_once, level_three_each, rooms_hero_dependent | auto | Conforme | — |
| RMB092 | Eloi Marlborn | Mage, 4 PV, trésor 3, 1 âme(s) ; aucun texte imprimé | cards.json (statistiques) | fix_mind_thresher_once, level_three_each, rooms_hero_dependent | auto | Conforme | — |
| RMB093 | Exai, Mindmage | Mage, 4 PV, trésor 3, 1 âme(s) ; aucun texte imprimé | cards.json (statistiques) | level_three_each, rooms_hand_abilities | auto | Conforme | — |
| RMB094 | Clebrina, Familiar | Mage, 6 PV, trésor 3, 1 âme(s) ; aucun texte imprimé | cards.json (statistiques) | level_three_each, rooms_paywall_cavern_guardtower, stack_probe_identity | auto | Conforme | — |
| RMB095 | Bross, Illusionist Adept | Mage, 6 PV, trésor 3, 1 âme(s) ; aucun texte imprimé | cards.json (statistiques) | rooms_paywall_cavern_guardtower, stack_probe_identity | auto | Conforme | — |
| RMB096 | Alchemist | Mage, 6 PV, trésor 3, 1 âme(s) ; aucun texte imprimé | cards.json (statistiques) | heroes, rooms_efreet_blackmarket | auto | Conforme | — |
| RMB097 | Dovkro, Born of the Dragon | Mage, 8 PV, trésor 3, 1 âme(s) ; aucun texte imprimé | cards.json (statistiques) | rooms_efreet_blackmarket | auto | Conforme | — |
| RMB098 | K'Bothi the Spy | Thief, 4 PV, trésor 4, 1 âme(s) ; aucun texte imprimé | cards.json (statistiques) | spell_phases_and_targets | auto | Conforme | — |
| RMB099 | The Steel Mouser | Thief, 4 PV, trésor 4, 1 âme(s) ; aucun texte imprimé | cards.json (statistiques) | fix_pay_without_cap, spells_economy | auto | Conforme | — |
| RMB100 | Ofcroak, Vengeful Handmaid | Thief, 6 PV, trésor 4, 1 âme(s) ; aucun texte imprimé | cards.json (statistiques) | spells_heroes | auto | Conforme | — |
| RMB101 | Koko the Piper | Thief, 6 PV, trésor 4, 1 âme(s) ; aucun texte imprimé | cards.json (statistiques) | spells_heroes | auto | Conforme | — |
| RMB102 | Scoundrel | Thief, 6 PV, trésor 4, 1 âme(s) ; aucun texte imprimé | cards.json (statistiques) | heroes, spells_heroes | auto | Conforme | — |
| RMB103 | Marmo, Master of Dreams | Thief, 8 PV, trésor 4, 1 âme(s) ; aucun texte imprimé | cards.json (statistiques) | rmb_card_stats | auto | Conforme | — |
| RMB104 | The Fool | Cleric, 2 PV, trésor 1, 1 âme(s) ; capacité codée d'après la paraphrase du wiki (arbitrages-wiki.md) | cards.json (statistiques) | heroes | auto | Conforme | — |
| RMB105 | Haize, Half-angel | Cleric, 11 PV, trésor 1, 2 âme(s), épique ; aucun texte imprimé | cards.json (statistiques) | rmb_card_stats | auto | Conforme | — |
| RMB106 | The Overseer | Cleric, 11 PV, trésor 1, 2 âme(s), épique ; aucun texte imprimé | cards.json (statistiques) | rmb_card_stats | auto | Conforme | — |
| RMB107 | Paladin | Cleric, 12 PV, trésor 1, 2 âme(s), épique ; aucun texte imprimé | cards.json (statistiques) | heroes | auto | Conforme | — |
| RMB108 | Koverian, Executioner | Cleric, 13 PV, trésor 1, 2 âme(s), épique ; aucun texte imprimé | cards.json (statistiques) | rmb_card_stats | auto | Conforme | — |
| RMB109 | Varraka, Combat Instructor | Fighter, 11 PV, trésor 2, 2 âme(s), épique ; aucun texte imprimé | cards.json (statistiques) | rmb_card_stats | auto | Conforme | — |
| RMB110 | Zheng-Yi, One Kick Woman | Fighter, 11 PV, trésor 2, 2 âme(s), épique ; aucun texte imprimé | cards.json (statistiques) | rmb_card_stats | auto | Conforme | — |
| RMB111 | Relic Hunter | Mage, 12 PV, trésor 3, 2 âme(s), épique ; aucun texte imprimé | cards.json (statistiques) | rmb_card_stats | auto | Conforme | — |
| RMB112 | Unseena, Invisible Wrestler | Fighter, 13 PV, trésor 2, 2 âme(s), épique ; aucun texte imprimé | cards.json (statistiques) | rmb_card_stats | auto | Conforme | — |
| RMB113 | Zutara, Elemental Master | Mage, 11 PV, trésor 3, 2 âme(s), épique ; aucun texte imprimé | cards.json (statistiques) | rmb_card_stats | auto | Conforme | — |
| RMB114 | Mortimer, Evil Genius | Mage, 11 PV, trésor 3, 2 âme(s), épique ; aucun texte imprimé | cards.json (statistiques) | rmb_card_stats | auto | Conforme | — |
| RMB115 | Warlock | Mage, 12 PV, trésor 3, 2 âme(s), épique ; capacité codée d'après la paraphrase du wiki (arbitrages-wiki.md) | M:2178, TA:15, TA:1421 | heroes_wiki_paraphrases | auto | Conforme | — |
| RMB116 | Shigeru the Spellbinder | Mage, 13 PV, trésor 3, 2 âme(s), épique ; aucun texte imprimé | cards.json (statistiques) | rmb_card_stats | auto | Conforme | — |
| RMB117 | Moran, Master of Keys | Thief, 11 PV, trésor 4, 2 âme(s), épique ; aucun texte imprimé | cards.json (statistiques) | rmb_card_stats | auto | Conforme | — |
| RMB118 | Marsden, Reformed Outlaw | Thief, 11 PV, trésor 4, 2 âme(s), épique ; aucun texte imprimé | cards.json (statistiques) | rmb_card_stats | auto | Conforme | — |
| RMB119 | Tax Collector | Thief, 12 PV, trésor 4, 2 âme(s), épique ; capacité codée d'après la paraphrase du wiki (arbitrages-wiki.md) | M:2178, TA:16, TA:1421 | heroes_wiki_paraphrases | auto | Conforme | — |
| RMB120 | Petros, Dwarven Noble | Thief, 13 PV, trésor 4, 2 âme(s), épique ; aucun texte imprimé | cards.json (statistiques) | rmb_card_stats | auto | Conforme | — |
| RMB121 | The Progenitors | Cleric, 20 PV, trésor 1, 2 âme(s), épique ; capacité codée d'après la paraphrase du wiki (arbitrages-wiki.md) | BE:221 | heroes_wiki_paraphrases | auto | Conforme | — |

### Règles propres à RMB

| Id | Règle (source) | Code | Golden | Statut | Priorité |
|---|---|---|---|---|---|
| RMB-R01 | Mise en place : 5 salles + 2 sorts, on garde les 7 ; la défausse de 2 cartes est le Classic Mode (`docs/rules/rules.md` 3059-3064, 3477) | M:1146-1166 (`_deal_opening_hands`, `_queue_next_opening_discard`) ; Variants.gd:39 (`keeps_opening_hand`) ne gardait les 7 que pour TNL ; le commentaire de M:1171 écrivait que RMB défausse 2 cartes « comme l'APK » alors que le manuel commun TNL / RMB dit le contraire | setup_hands | Corrigé (RMB) | Moyenne |
| RMB-R02 | Mulligan : quatre salles avancées ou quatre cartes d'un même trésor, on peut remélanger toute la main (rules.md 3064-3065) | M:1148-1153 (`tnl_mull = TnlAbilities.active`) : jamais proposé avec RMB seul ; Variants.mulligan (Variants.gd:73) | setup_hands | Corrigé (RMB) | Moyenne |
| RMB-R03 | 3 Coins au départ (rules.md 3060-3061) | Match.gd:179 ( `START_COINS`) ; BoardUI affiche « COINS » | setup_hands | Conforme | — |
| RMB-R04 | Miniboss : posé face cachée sur n'importe quelle salle à la place de la construction ; révélation 1 Coin ; promotion 1 Coin (autre tour) ; le niveau 3 remet au niveau 1 | MB:154-181 (`attach`, `normalize`), MB:313 (`apply_build`), MB:333 (`reveal_all`), MB:356-378 (`promote_options`, `apply_promote`) | build_miniboss, reveal_and_discard, promote, level_three_each | Conforme | — |
| RMB-R05 | Salle détruite : son miniboss est défaussé ; salle recouverte : il saute (livret p.6, arbitrages-wiki.md:12) | MB:193 (`on_destroy`) | destroyed_miniboss | Conforme | — |
| RMB-R06 | Coins posés sur une salle (Dreadmill, Minion Clinic, Crystal Ballroom) : information publique | `room.coins` (RB:647, MB:682) ; aucun affichage : DungeonSlot.gd:123 et BoardUI.gd:1959 ne posaient un badge que pour un miniboss | badge de salle (`ui_labels_and_menu`), ui smoke | Corrigé (RMB) | Basse |
| RMB-R07 | Pile : « Spells and activated abilities resolve in a streamlined Last In, First Out order » (rules.md 21, 131) | M:722-731 : `activateMiniboss`, `rmbBoss`, `rmbPay` étaient appliqués tout de suite (AUDIT.md « Écarts connus » de R-D67), seules les capacités de salle étaient des entrées de pile | stack_probe_identity, stack_rmb_abilities | Corrigé (RMB) | Moyenne |
| RMB-R08 | Statistiques des 121 cartes (12 boss, 42 salles, 15 sorts, 42 héros, 10 minibosses) | `cards.json` ; CardDB.gd:46-57 | rmb_card_stats | Conforme | — |

### Synthèse du lot RMB

121 cartes à l'audit initial : 113 Conforme, 7 Écart (7 Basse), 1 Non implémenté (Luz), 0 Haute. Après corrections et relecture : 100 Conforme, 20 Corrigé (RMB), 1 Non implémenté (Luz). Par type : 12 boss (11 Conforme, 1 Corrigé), 42 salles (29 Conforme, 13 Corrigé), 15 sorts (14 Conforme, 1 Corrigé), 10 minibosses (5 Conforme, 5 Corrigé), 42 héros (41 Conforme, 1 Non implémenté). Règles : 8 lignes, dont 3 Écart Moyenne corrigés (RMB-R01, RMB-R02, RMB-R07) et 1 Écart Basse corrigé (RMB-R06).

Écarts Moyenne :

- RMB-R01 : une partie Minibosses seule défaussait 2 cartes à l'ouverture, alors que le manuel garde les 7 (Classic Mode = défausse).
- RMB-R02 : le mulligan n'était proposé qu'avec TNL.
- RMB-R07 : les capacités de miniboss (niveau 2), les pouvoirs de boss RMB et le paiement du Paywall ne passent pas par la pile.

Écarts Basse :

- RMB015 Ancient Guardtower : tirage avec `randi()` global (non reproductible).
- RMB012 Kirax, RMB045 Endless Gallery : « any treasure type » sans Explorer avec Crash Landing.
- RMB073 Pay to Win : seules les salles du lanceur étaient ciblables.
- RMB048 Dreadmill, RMB020 Minion Clinic, RMB037 Crystal Ballroom, RMB-R06 : Coins posés sur la salle non affichés.
- RMB083 Luz : « When Luz is around, heroes only sometimes die » n'a aucune règle déterministe (arbitrages-wiki.md:26).

Ordre de correction : (1) mise en place RMB-R01 / RMB-R02 ; (2) cibles et listes de choix RMB073, RMB012, RMB045 ; (3) RMB015 ; (4) affichage des Coins RMB-R06 ; (5) golden table par table `rmb_card_stats` ; (6) RMB-R07.

Points non tranchés :

- RMB083 Luz : aucun effet n'est défini par le texte ; elle joue comme un héros de statistiques. Recherche refaite le 2026-10-28 : la page fandom de la carte est bloquée (403 Cloudflare), l'API ne la liste pas, mais la page « List of Cards » (api.php, action=parse) donne le seul texte : « Luz is a fast-paced heroine who brings good vibrations an pwerful healing to any battle. When Luz is around, heroes only sometimes die. » (ligne RMB083, PV 6, trésor 1, 1 âme) ; les PDF de règles (`rules_minibosses.pdf`, `rules_next_level.pdf`, guide non officiel) n'ont aucune occurrence de Luz. Texte d'ambiance, sans condition ni probabilité : rien à porter, la carte reste `Non implémenté`.
- `rmbHand` (défausse d'une carte de la main) et `discardForCoin` restent immédiats : ce sont des coûts / actions de main sans cible ni effet sur le donjon, comme les capacités de main des salles (R-D67). Les effets DÉCLENCHÉS (non activés) restent immédiats comme pour les salles.
- RMB104 The Fool : `cards.json` garde la fiche de l'APK (aucune classe, aucun trésor, leurre par le moins d'âmes) alors que le wiki écrit Cleric / trésor 1.
- Non vérifié : les textes imprimés des cartes (scans), l'IA des pouvoirs de boss. La relecture texte / code des cartes « Conforme » (salles déclenchées, sorts, boss, niveaux de minibosses) a été refaite le 2026-10-28 : elle a trouvé les trois écarts ci-dessous (salles désactivées, deux Alchemist's Lab, Fetid Beast).

### RMB : corrections (2026-10-28)

7 écarts de cartes, 3 écarts de règles et l'affichage des Coins sont corrigés (statut `Corrigé (RMB)`). Reste : RMB083 Luz (`Non implémenté`, aucune règle dans son texte, recherche refaite). RMB-R07 est corrigé. Aucun conflit entre texte de carte et livret.

- RMB-R01 : une partie Minibosses garde ses 7 cartes à l'ouverture, la défausse de 2 est le Classic Mode (Variants.gd:39-43 `_big_set`, `keeps_opening_hand` ; commentaire Match.gd:1171). Golden `setup_hands` (7 cartes, puis Classic Mode : défausse de 2).
- RMB-R02 : le mulligan est proposé avec RMB comme avec TNL (Match.gd:1148 `_big_hand()`). Golden `setup_hands` (cinq salles du même trésor, choix de l'humain, main redistribuée).
- RMB073 Pay to Win : toutes les salles sont ciblables, celles des adversaires comprises (RmbSpells.gd:81). Goldens `spell_phases_and_targets` (3 salles x 0 à 5 Coins), `fix_pay_without_cap` (salle adverse, 2 Coins, +3).
- RMB012 Kirax, RMB045 Endless Gallery : « any treasure type » inclut Explorer quand Crash Landing est dans la partie (RmbAbilities.gd:901 `icon_types`, :681, :907). Golden `boss_active_powers` (cinq choix, icône Explorer ajoutée).
- RMB015 Ancient Guardtower : le sort pris au hasard passe par le générateur du moteur (RmbAbilities.gd:414 `TnlAbilities._rng_get()`), plus de `randi()` global.
- RMB048, RMB020, RMB037, RMB-R06 : les Coins posés sur une salle sont affichés par le badge de la salle, avec ou sans miniboss (Minibosses.gd:854-870 `badge_text`, `room_coins`, `badge_tooltip`). Goldens `ui_labels_and_menu` (badge) et `ui smoke` (plateau, « COINS: 2 »).
- RMB-R07 : les capacités de miniboss de niveau 2, les pouvoirs de boss RMB (`rmbBoss`) et le paiement du Paywall (`rmbPay`) sont des entrées de pile comme les capacités de salle après R-D67, sans mécanisme parallèle : le type d'entrée `ability` porte une charge `rmb` {type, args, clé} (Minibosses.gd `make_entry`, `run_entry`, `move_key`, `is_queued`, `respond_moves`, `QUEUED_MOVES`). Match.gd `apply_move` (branche `activateMiniboss` / `rmbBoss` / `rmbPay`) rejoue l'activation sur une copie via `_advance_targeting`, l'activateur choisit ses cibles à la mise en file (`targeting`), `_enqueue_ability` l'empile, `_exec_entry` l'exécute (`Minibosses.run_entry`, qui annule si la salle a quitté la partie ou est recouverte, ou si une cible a disparu) ; le coût et le « une fois par tour » ne sont consommés qu'à l'exécution ; les adversaires répondent (sorts, capacités de salle ou de miniboss en réponse, `respond_moves`) ; ViewFilter masque `picks`. L'IA n'empile pas ces coups sur une pile non vide (AI.gd, -50). Golden `stack_rmb_abilities` : mise en file, réponse de l'adversaire qui détruit la cible ou change le résultat, cible disparue (0 dégât, once-per-turn intact), Paywall détruit en réponse, masquage des cibles.
- Relecture des cartes Conforme : une salle désactivée « loses its abilities until end of turn » (rules.md:128) mais ses déclencheurs (Garbage Chute RMB041, Black Market RMB033, Personnel Office RMB049, Imp Hoard RMB017, Alchemist's Lab RMB032, Lightning Rod RMB051, Mind Thresher RMB034) et le texte de ses minibosses (Paddywhack RMB060, Icicle Man RMB061, Rocky RMB058, Cerebella RMB059, Brassknuckle RMB063) ne tenaient compte que de « no ability text » ; ils passent par `TnlAbilities.live` (face visible, texte présent, ni désactivée ni verrouillée) : RmbAbilities.gd `on_destroyed`, `on_opponent_miniboss`, `on_hero_died`, Minibosses.gd `on_spell_cast`, `on_hand_discard`, `gain_coin`, `hero_text_ignored` (sans `live`, qui rebouclerait sur `abilities_locked`), `on_hero_died`. Fetid Beast RMB025 désactivée ne bloque plus les salles Monster voisines (RmbAbilities.gd `fetid_blocks`, BossEngine.gd:141). Deux Alchemist's Lab donnent chacun +2 au premier sort du tour (la boucle s'arrêtait au premier). Golden `fix_deactivated_triggers`.
- Statistiques des 121 cartes : golden table par table `rmb_card_stats` (RMB-R08, tableau écrit dans le test puis `cards.json` comparé au JSON du wiki champ par champ ; exceptions documentées : le champ `gainCoin` n'est pas stocké, RMB104 The Fool garde la fiche de l'APK).
- Validation : `python tools/run_godot_tests.py` : 19/19 suites OK ; oracle `tools/parity/apk.py` : 6/6, 12/12 (`--seeds 4 5 6 7 --players 2 3 4`), 6/6 (`--decks BaseDeck,PlayerChoice,HiddenHeros,ToolsHeroKind`) ; `--ai-agreement` : `usableSet 2121 2121 100.0 0 2121 2121 100.0 0`, « mutations de l'etat Godot par les requetes IA : 0 (doit etre 0) » ; stress `--seeds 10..40 --players 2 3 4` : 90/93 (hors OK : s16-p4, s20-p2, s28-p3, échecs connus).

## Soaks bloqués (2026-10-28)

Trois fois de suite, une suite de soak a échoué sur `run_godot_tests.py` (1 échec sur 30 déjà sur le code d'avant). Les soaks tirent une graine au hasard : `soak_runner.gd` l'affiche maintenant (`SOAK seed=N`) et la rejoue avec `-- --seed=N` (RNG de la partie, `CardDB`, `TnlAbilities` et RNG global tous graînés ; deux lancements donnent la même partie).

- **Tomb of Terrors au tour 1** (graine 1266755014, 4 joueurs, tous paquets) : le moteur n'est pas bloqué. Le soak résolvait chaque choix en attente par `legal_moves(...)[0]` ; pour `take_discard` l'option 0 est Tomb of Terrors elle-même, reprise de la défausse, rejouée, redéfaussée, sans fin (4000 pas au tour 1). Un siège IA réel (`GameRoom`, `BoardUI`) passe par `AI.pick_move`, qui donne -5 à cette carte. Correction : le soak résout les choix avec `AI.pick_move` (repli sur le premier coup).
- **Respawn + Arcane Crypt** (graine 3204597387, 2 joueurs) : boucle réelle de l'IA. Arcane Crypt (TNL016) récupère un sort de la défausse, l'IA y reprend Respawn (RMB075, score fixe 8,0), le rejoue (toutes les salles sont « construites » à nouveau, Arcane Crypt se redéclenche), et ainsi de suite dans le même tour. Les règles n'interdisent pas la combinaison ; c'est l'IA qui ne doit pas la répéter. Correction : `RmbSpells.score_spell` donne -5 à Respawn si le joueur l'a déjà joué ce tour (`respawnTurn`, posé par l'effet, clé ajoutée à `ViewFilter.PLAYER_PUBLIC_KEYS`, sinon `online_test` échoue).
- **Non reproduit** : le blocage « all packs » en phase d'aventure (pile à 1 entrée, aucun choix en attente) vu une fois sur le code d'avant. Environ 40 minutes de chasse à graines variées (2 à 6 joueurs, tous paquets, Minibosses, IOD) n'en ont pas retrouvé ; il reste à surveiller, la graine sera maintenant dans le journal.
- Régressions : deux suites ajoutées à `tools/run_godot_tests.py` (21 au total), « soak graines bloquees » (1266755014) et « soak graine Respawn + Arcane Crypt » (3204597387).
- Validation : `run_godot_tests.py` 21/21 deux fois de suite ; oracle 6/6, 12/12, 6/6 (paquets), `--ai-agreement` `usableSet` 2121/2121 et mutations 0, stress graines 10-40 : 90/93 (s16-p4, s20-p2, s28-p3 comme avant).

## Salle encore face cachée en phase d'aventure (2026-10-28)

Observé en ligne (2 joueurs, jeu de base, tour 4) : B pose Torture Chamber (BMA038) puis DONE ; ADVENTURE PHASE s'affiche, la salle de A est face visible, celle de B montre encore son dos dans les deux clients, puis elle se retourne après les PASS TURN.

- **Non reproduit côté serveur.** Chemins écartés : DONE automatique à l'échéance du délai (premier ou second constructeur), pose puis DONE, coups hors tour, DONE pendant la fenêtre de sorts (`buildWindow`), coupure de liaison (siège repris par l'IA puis rendu), `_build_reveal_queue` (lit `faceDown` de la salle du dessus de chaque pile, aucun drapeau « en attente » séparé), `ViewFilter._room_view` (ne masque que `faceDown`). Preuve : fuzz de plus de 400 parties à 2 humains (3000 pas au plus, coups aléatoires et de l'IA, 10 % de dépassements, 4 % de coupures), contrôle à chaque pas du moteur et des vues des deux sièges : aucune salle `faceDown` en phase `bait` / `adventure`.
- Le moteur ne retourne une salle qu'à `Match._build_reveal_queue` ; une salle vue face cachée puis retournée sans nouvelle phase de construction ne peut donc pas venir de l'état serveur. Piste restante côté client (non vérifiée, aucun navigateur lancé) : `DungeonSlot._update_view` / `BoardUI` (dos de `CardUI.flip_in`, vol `_fly_pending` de P-C14, ajouté le jour même) sur un onglet Chrome en arrière-plan dont les tweens sont suspendus.
- Régression : `online_test.gd`, `_scenario_reveal_invariant` (12 parties aléatoires, moteur et vues), invariant « jamais de salle face cachée une fois la construction close ». Aucun changement de règles : l'oracle n'a pas été relancé.
