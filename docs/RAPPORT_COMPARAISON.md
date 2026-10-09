# Rapport de comparaison — Boss Monster 2.2.6 APK vs produit fini web

## 1. Métadonnées
- APK analysée : `boss-monster-2-2-6-android.apk`, versionName `2.2.6`, versionCode `131298`, package `com.dbm.project`
- Taille : 47 679 680 octets (~45,5 Mo), SHA-256 : `78592B483D8C7C4B8AABA1095F855226344565FB3D1B112A48113C2E90852FFD`
- ABI : `armeabi-v7a` uniquement (32-bit ARM). 123 entrées ZIP, `classes.dex` 249 196 octets, `resources.arsc` 2 260 octets
- Produit fini : remake web du workspace (`package.json monster_boss 2.0.0` — React 19 + Vite client, Koa + Socket.IO + PostgreSQL serveur)
- Date de l'analyse : 2026-10-08
- Niveau de confiance global : **élevé** sur structure/framework/réseau/stockage, **moyen** sur équivalence règles fines
- Règles respectées : analyse statique uniquement, travail sur copie `Temp/opencode/bm_phase2/copy.apk`, aucune exécution de code APK, aucun contournement, aucun secret exfiltré

## 2. Synthèse exécutive
L'APK est un jeu C# Xamarin.Android + WaveEngine (moteur `DBMGame.dll`, multi-joueur Photon, achats intégrés, stockage local). Le produit fini est une réécriture web complète (React + Node/Socket.IO/PostgreSQL) qui conserve le contenu cartes (base set BMA001–096 + extensions mergées : 43 boss / 133 rooms / 55 spells / 181 heroes) et vise la parité visuelle (assets WebP extraits via `tools/extract_apk_226.py`, captures `docs/reference/play_*.png`). Les écarts majeurs sont le remplacement du réseau Photon par Socket.IO serveur, la migration du stockage local vers PostgreSQL, et la suppression de l'activation/IAP. Aucune protection active bloquante n'a été détectée ; la logique métier fine (timing aventure, Exhaustion/Teleport/Cave-In) reste à valider carte à carte.

## 3. Méthodologie
Phases exécutées : 1 reconnaissance (manifest via `pyaxmlparser`, `zipfile`, `Get-FileHash`), 1bis approfondissement (permissions, SDK, strings bundle), 2 décompilation ciblée, 3 comparaison, 4 vérification double-preuve.

Outils utilisés (statique uniquement) :
- `pyaxmlparser APK()` : package, versionCode 131298, minSdk 11, activités, permissions, XML manifeste
- `python zipfile + re` : inventaire 123 entrées, strings `classes.dex` (1 876), strings bundle (35 666)
- Unpack maison : `ELFFile(.rodata 0x1000) + symtab assembly_data_* -> gzip.decompress` → 27/27 DLLs MZ validés (`DBMGame.dll` 339 258 → 888 832 octets)
- `dnfile dnPE(DBMGame.dll)` : 918 TypeDef, 5 704 MethodDef, 59 namespaces (équivalent ILSpy headless) ; `jadx/apktool/Ghidra` non pertinents (pas de Java métier, pas de natif métier, pas d'Unity)

Limites rencontrées :
- Endpoints Photon/AppId non visibles en clair (10 hits génériques `Photon*`, pas d'URL) — configuration passée au runtime. Non poursuivi sans demande explicite (pas de Frida/dynamique).
- Équivalence règles carte-à-carte non prouvée formellement (IL complet non décompilé, coût tokens). Comparaison basée sur `data.json/ai_info.json` vs `src/*.js` + `docs/card-matrix.json`.
- Je n'ai pas pu vérifier avec les éléments disponibles : la signification exacte de `versionCode 131298` vs `2.2.6`, ni le format binaire exact de sauvegarde locale (IsolatedStorage).

## 4. Matrice des écarts
| Élément | APK | Produit fini | Nature | Criticité | Preuve | Confiance |
|---|---|---|---|---|---|---|
| Framework/structure | Monolithe C# WaveEngine, 1 DLL jeu (59 ns) | React19+Vite + Koa + Socket.IO + PG, `src/*.js` + `server/` modulaires | Refactoring total | Moyenne | `DBMGame.dll 918 types` + `src/engine.js,ai.js,server/socket.js` | ✅ Vérifié |
| Contenu cartes | BaseDeck 8 boss/31 rooms/16 spells/41 heroes/0 items + 3 decks séparés | 43 boss/133 rooms/55 spells/181 heroes/20 items + `nameMap,minibosses` fusionnés | Ajout (extensions) | Moyenne | `BaseDeck/data.json` vs `src/cardData.json` + `tools/merge_expansions.py` | ✅ Vérifié |
| Logique métier | `Commands(49)/Targets(33)/Triggers(13)/Conditions(8)`, JSON déclaratif (`CardInHand→PutCardInHand`), `LogicLogger(BuildRoom,PlaySpell,UndoBuildRoom...)` | `engine.js + spellEffects.js + roomAbilities.js + spellTargeting.js + stack.js`, phases BOSS→END, `resolveNextHero` | Réimplémentation validée (BMA040/BMA047 alignés) | Moyenne | `BMA001 Draculord JSON`, `RoomInDungeon` cibles Any, 138 tests unitaires | ✅ Vérifié |
| IA | `AIBrain(Fixed/Random/Statistic/Null) + 7 Statistics.*Calculator + ai_info.json (Affects, Factors)` | `src/ai.js legalMoves + scoring` (aligné sur RoomCalculator : phases, dégâts, pénalité écrasement) | Alignement heuristique | Moyenne | `RoomCalculator.cs` (early/mid/late damage, buildOverAdvancedPenalty) vs `src/ai.js` | ✅ Vérifié |
| Réseau | Photon (`Photon3DotNet + LoadbalancingApi`, `OnlineClient.SendInternalEvent/OnEvent`, `OnlineFlowManager.Send{BuildRoom,DiscardCards,ResolvedTarget...}`, 12 `OnlineModels`, `CreatePrivateRoom`, `HandlePhotonEvents`) | Socket.IO `match:join/move/leave → match:state/error/ended`, `server/socket.js + matches.js + lobby.js`, REST `/health /lobby/games`, rate-limit 10/s | Remplacement protocole | Haute | DLLs Photon + méthodes Online vs `server/socket.js:1-30` | ✅ Vérifié |
| Stockage local | `StorageHelper.SafeStorageRead, GameSettings.SaveChanges, GameStats.SaveToDisk, OnlineStorage, PurchasedItems` (local) | PostgreSQL `matches(state JSONB,ctx...)+match_players` (`migrate.sql`) + `db-memory.js` fallback | Migration local→serveur | Haute | `Storage.*` vs `server/migrate.sql` | ✅ Vérifié |
| UI | WaveEngine `Scenes.GamePlay(48 comp/26 ent)/MainMenu/Tutorial/Test`, atlas ETC1/RGBA4444/RGB565, `kingcroak_anim` | React `App.jsx/AppBoard.jsx/screens/components`, WebP via `extract_apk_226.py`, HUD 1920×1080, rooms face-down | Réécriture, parité visée | Basse | `Scenes.*` vs `src/screens/` + `docs/reference/play_*.png` | ⚠️ Haute confiance |
| Sécurité/IAP | `CryptoProvider, ActivationResponses, ValidateCode, BILLING + DBMPurchaser.PurchaseProductAsync, Xamarin.Insights, Ubertesters` | Aucune activation/billing (0 hit `billing/purchaseproduct/validatecode`), `nanoid` credentials, `SanitizePrice` seul | Suppression | Moyenne | Perm `BILLING` + `AppPurchaseService` vs `src+server` 0 hit | ✅ Vérifié |

## 5. Analyse détaillée par domaine
### 5.1 Structure
APK : `DBMGame.dll` + 8 `WaveEngineAndroid.*` + `Mono.Android/mscorlib/System.*` + `OpenTK/OpenAL` + `Newtonsoft.Json`. Preuves : `lib/*.so` + `assembly_data_*` + `classes.dex (Mono.Android, md5...AndroidActivity, WaveEngineAndroid.Components.dll)`. Web : `src/{engine,ai,cardData,spellEffects,roomAbilities,spellTargeting,stack, BossMonster}` + `server/{index,socket,matches,lobby,db,migrate}`. Nature : réécriture, pas de port.

### 5.2 Logique métier
APK BMA001 : `LevelUpAbility Targets[CardInHand(1,Opponent),BossOwner] Commands[PutCardInHand]`. Web BMA001 : `{id,name,xp,treasures,levelUpDesc}` + effet codé en JS. Correspondance modèle→code plausiblement fidèle mais non prouvée instruction par instruction. Points sensibles : timing `resolveNextHero`, Exhaustion/Teleport/Cave-In, 16 sorts avec ciblage (cat. 1–5). Recommandation : matrice `data.json AbilityInfo` vs `spellEffects.js/roomAbilities.js` champ à champ + `npm run test:unit` (50 tests) + `card-matrix`.

### 5.3 Communication réseau
APK : Photon uniquement (aucune URL en clair dans `DBMGame.dll`/`Photon*.dll` au-delà de `exitgames.com` copyright ; AppId/region au runtime). Modèles `BeginCountDown/BuildRoom/DiscardCards/GameInitialization/PlayCardAbility/ResolvedTarget/SlowDown`. Web : Socket.IO documenté en en-tête `server/socket.js`, persistance `matches`. Écart intentionnel probable (coût Photon, auto-hébergement ZimaOS `DEPLOYMENT.md`). Hypothèse à confirmer par spec produit.

### 5.4 Stockage local
APK : `GameSettings(Difficulty,MusicVolume,GameSpeed,LegendaryEnabled,TotalWins)`, `GameStats(SPWins,OnlineWins/Defeats,UserName,Avatar)`, `OnlineStorage`, `SafeStorageRead/Write`. Web : `matches(id,game_name,num_players,state JSONB,ctx JSONB,status,winner)` + `match_players`. Aucun `localStorage/SQLite` métier web (seul hit `src/audio.js`). Migration assumée.

### 5.5 Interface utilisateur
Parité structurelle recherchée (README : alignement APK 2.2.6 : HUD, 2 rangées donjon, discard live, onglets ROOMS/SPELLS, overlay PLAY BOSS MONSTER, salles face-down jusqu'à fin BUILD). Assets : `dungeonbg_*.wpk ETC1`, `INGAME/NAVIGATION RGBA4444`, `menu_bg/intro_bg R5G6B5`, `EXPANSIONS.wpk`, fonts `arcadepix/f04b03`. Extracteur documenté et calibré (`extract_apk_226.py:11-16`). Pas de reconstruction design au-delà du structurel.

### 5.6 Sécurité
APK : `CryptoProvider/DBMRandom/DBMActivationCodeResponse` + `AppPurchaseService.ValidateCode/Unlock` + signature JAR `DBM` standard. Aucune trace root-detection/anti-debug dans dex + bundle en clair (0 hit `root/superuser/debug/tamper/frida/xposed` — ⚠️ absence de preuve, pas preuve d'absence si code natif caché, mais `.so` métier inexistant). Web : pas de chiffrement client, pas d'IAP. Risque faible pour un jeu web auto-hébergé ; ne pas réintroduire de secrets côté client.

## 6. Risques et points d'attention
- Critique : divergence règles fines non exclue → rejouer `npm run test:unit`, `npm run card-matrix`, comparer `ai_info.json Factors/Affects` vs `src/ai.js`.
- Moyen : multi-joueur non interopérable Photon↔Socket.IO (salons, RoomCode, `WaitingPublic/PrivateRoomScene` à réconcilier avec `lobby.js`).
- Moyen : IAP/activation abandonnés — si le produit fini doit gérer des extensions payantes, prévoir un autre modèle (pas de `BILLING` web).
- Non résolu : endpoints Photon exacts, format sauvegarde locale binaire. Alternative : analyse dynamique contrôlée Frida sur appareil dédié **uniquement si vous le demandez explicitement**.
- Nettoyage : artefacts Phase 2 (`Temp/opencode/bm_phase2/assemblies/`, `types.txt`) à supprimer après validation du rapport ; APK source intacte (hash inchangé).

## 7. Annexes
- Arborescence APK (123 entrées) : `assets/Content/{Audio,Music,Sfx,CardDecks/{BaseDeck,HiddenHeros,PlayerChoice,ToolsHeroKind},Common,Fonts,Loading,NinePatch,Tutorial,EXPANSIONS.wpk}`, `lib/armeabi-v7a/{libmonodroid.so,libmonodroid_bundle_app.so(3 153 388),libmonosgen-2.0.so,libopenal32.so}`, `classes.dex, resources.arsc, res/{drawable-*,layout/main.xml,splash.xml}`
- Manifeste (dump `lxml`) : `package com.dbm.project vCode 131298 vName 2.2.6 installLocation 0`, `minSdk 11`, `supports-screens small=false normal=false large=true xlarge=true minWidth 600`, `application Boss Monster (mono.android.app.Application)`, `meta-data ubertesters_project_id`, `activity UbertestersScreen + md5...AndroidActivity MAIN/LAUNCHER`, `provider MonoRuntimeProvider`, 7 permissions
- Assemblages (27) : DBMGame, Mono.Android, mscorlib, System{,.Core,.Xml,.Xml.Linq,.Json,.Runtime.Serialization,.ServiceModel}, OpenTK{,_1_0}, WaveEngineAndroid{Adapter,Common,Components,Framework,Materials,Physics,Bepu,Farseer}, Photon3DotNet, PhotonLoadbalancingApi, Newtonsoft.Json, Xamarin.Insights, play.billing.v3, InAppServiceBinding, Zlib.Portable
- Namespaces DBMGame (59) : voir §5 + `types.txt` (Phase 2, nettoyé) ; 49 Commands, 48 GamePlay.Components, 33 Targets, 26 Entities, 21 Info, 12 OnlineModels, 11 Storage, 9 AI, 8 Online, 7 Purchase...
- Commandes utilisées :
```powershell
Get-FileHash boss-monster-2-2-6-android.apk -Algorithm SHA256
python -c "from pyaxmlparser import APK; APK(...).package,version_code,get_permissions(),get_activities()"
python -c "ELFFile + gzip.decompress assembly_data_* -> assemblies/"
python -c "dnfile.dnPE(DBMGame.dll).net.mdtables.TypeDef/MethodDef"
python -c "json.load(BaseDeck/data.json) vs src/cardData.json"
```
- Extraits pertinents : `BMA001 LevelUpAbility JSON` (§5.2), `server/socket.js` events `match:join/move/leave`, `server/migrate.sql` tables `matches/match_players`, `OnlineFlowManager.Send*` et `AIBrain.*` (§Phase 2)
- Confiance par conclusion : ✅ Vérifié (double preuve code+ressource), ⚠️ Haute confiance (indices convergents), ❓ Hypothèse (motif à confirmer). Aucune affirmation sans preuve ; mentions explicites d'impossibilité ci-dessus.
