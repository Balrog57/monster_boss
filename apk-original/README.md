# apk-original — APK d'origine, décompilation et inventaire vérifié

Audit du 2026-10-18 (lot 1.0). Ce dossier contient **l'APK d'origine et toute sa
décompilation**, qui ne font **pas partie du projet** : référence de parité locale uniquement.

Règles :

- **Ne jamais commiter** ce contenu (voir `.gitignore` : `apk-original/*`, sauf ce README).
- **Ne jamais l'embarquer** dans l'image Docker (voir `.dockerignore`).
- Sur une machine sans l'APK, tout fonctionne sauf les scripts d'extraction et l'oracle.
  Les données de cartes versionnées sont `src/frontend/godot/data/cards.json` et
  `src/frontend/assets/data/*/data.json` (copie des `data.json` de l'APK).

## 1. Contenu du dossier et outils

| Chemin | Contenu | Outil / consommateur |
|---|---|---|
| `boss-monster-2-2-6-android.apk` | APK Boss Monster 2.2.6 d'origine (SHA-256 `78592b48…2ffd`) | — |
| `boss-monster-2-2-6/` | APK décompressé : `assets/Content/` (Audio, CardDecks, Common, Fonts, Loading, NinePatch, Tutorial, `EXPANSIONS.wpk`), `lib/`, `res/`, `classes.dex` | `tools/extract_apk_226.py` (WPK -> `src/frontend/assets/`), `tools/build_bmfonts.py` (polices), `tools/check_full_coverage.py` (rapport `decompiled/assets_full_coverage.md`) |
| `extracted_assemblies/` | `DBMGame.dll`, `Mono.Android.dll`, … sortis de `libmonodroid_bundle_app.so` | `tools/extract_assemblies.py` |
| `decompiled/` | C# décompilé (ilspycmd) : `DBMGame/` (560 `.cs`, 54 402 lignes, le jeu), `Wave/` (WaveEngine), 20 assemblages tiers ; `INDEX.md` ; `evidence/` (JSON REA) | `tools/build_decompiled_index.py`, `tools/build_reconstruction_payload.py` |
| `apktool-decoded/` | `AndroidManifest.xml`, `res/` décodé, `smali/` (196 fichiers : `classes.dex` n'existe qu'en smali) | lecture seule |

L'oracle (`tools/apk-oracle/`, .NET, charge `DBMGame.dll`) est piloté par
`python tools/parity/apk.py` : c'est la vraie mesure de parité des règles
(voir `tools/parity/README.md`, local uniquement).

Commandes d'extraction (depuis la racine du dépôt) :

    python tools/extract_apk_226.py     # textures, sons, données -> src/frontend/assets/
    python tools/build_bmfonts.py       # polices BMFont -> src/frontend/assets/fonts/
    python tools/check_full_coverage.py # chaque fichier de l'APK est extrait ou justifié
    python tools/verify_assets.py       # faces de cartes, art alternatif, assets d'UI

## 2. Complétude de la décompilation

- `DBMGame.dll` : 918 TypeDefs (`decompiled/evidence/managed_members_DBMGame.json`) =
  323 générés par le compilateur (dont 3 `__StaticArrayInitTypeSize=N`) + 35 types imbriqués
  retrouvés + 560 types de premier niveau, tous déclarés dans les 560 `.cs` de `decompiled/DBMGame/`.
  **Types sans déclaration : aucun.**
- Les 27 DLL (2026-10-28) : recensées avec `System.Reflection.Metadata`, puis re-décompilées une à
  une avec `ilspycmd` 11.1 (code de retour 0 pour toutes) : 6 294 TypeDefs, **4 930 types de premier
  niveau, 4 930 déclarations retrouvées, 0 manquant**, 0 marqueur d'échec, mêmes 4 915 chemins que
  `decompiled/` (3 478 fichiers identiques, 1 437 différents entre ilspycmd 9.1 et 11.1 ; `decompiled/`
  n'a pas été modifié). Limite : une déclaration présente ne prouve pas que chaque corps de méthode
  soit exact (29 fichiers gardent des `goto IL_`, aucun dans `DBMGame`). Détail par DLL :
  `docs/audit-apk-2-2-6.md`, annexe de complétude. Le décompte de `DBMGame` y est 917 TypeDefs (918 ici,
  pseudo-type `<Module>` compris, non revérifié).
- Code Java : `classes.dex` n'existe qu'en smali (196 fichiers) ; aucun autre code dans l'APK que
  `classes.dex` et les 4 `.so` ARM32.
- Code natif (`lib/armeabi-v7a/`, Ghidra 12) : `libmonodroid.so` (285 fonctions), `libmonodroid_bundle_app.so`
  (3), `libopenal32.so` (733), `libmonosgen-2.0.so` (5 164) décompilées vers `native_decompiled/`
  (local, ignoré par git) ; 0 instruction de `.text` hors fonction ; 0 échec de décompilation
  (2 fonctions de Mono reprises avec une limite de charge utile relevée). `classes.dex` : 1 152 méthodes
  avec code décompilées sur 1 152 (loader DEX de Ghidra), et 196 classes / 1 539 méthodes / 376 champs
  identiques en smali. `tools/extract_assemblies.py` n'existe plus : `extracted_assemblies/`
  (27 DLL, SHA-256 vérifiés contre le bundle) a été produit avant sa suppression.
- Le seul manque d'assets : `Common/marketItems.json` est absent de l'APK (boutique supprimée du
  clone : acceptable).

## 3. `NotImplementedException` dans `decompiled/DBMGame/` (22)

21 sont du code mort ; 1 est atteignable (à traiter au lot 1.1, `chooseDraw`).
Les fichiers `Commands/` sont sous `DBMGameModel.Logic.Abilities.Commands/`.

| Fichier:ligne | Classe.Méthode | Verdict | Preuve |
|---|---|---|---|
| `Commands/ChooseCardFromHand.cs:57` | `ChooseCardFromHand.Undo` | mort | `Ability.UndoEffect` (`Ability.cs:138-151`) n'est appelé que par `GameBoard.RemoveHeroFromGame` (`GameBoard.cs:697-699`) si `IsUndoableType()` ; seule `DeactivateDungeonAbility` (KSA017) est `IUndoableCommand` |
| `Commands/ChooseAndDestroyRoom.cs:36` | `ChooseAndDestroyRoom.Undo` | mort | idem |
| `Commands/UndoBuildRoom.cs:33` | `UndoBuildRoom.Undo` | mort | idem |
| `Commands/BuildRoomBy.cs:45` | `BuildRoomBy.Undo` | mort | idem |
| `Commands/SkipBeginingOfTurn.cs:33` | `SkipBeginingOfTurn.Undo` | mort | idem |
| `Commands/RemoveHeroFromTheGame.cs:37` | `RemoveHeroFromTheGame.Undo` | mort | idem |
| `Commands/FlipItem.cs:33` | `FlipItem.Undo` | mort | idem |
| `Commands/SkipBuildPhase.cs:27` | `SkipBuildPhase.Undo` | mort | idem |
| `Commands/SkipAdventurePhase.cs:33` | `SkipAdventurePhase.Undo` | mort | idem |
| `Commands/KillHero.cs:33` | `KillHero.Undo` | mort | idem |
| `Commands/DiscardSomeCardFromHand.cs:48` | `DiscardSomeCardFromHand.Undo` | mort | idem |
| `Commands/KillHeroInRoom.cs:34` | `KillHeroInRoom.Undo` | mort | idem |
| `Commands/FlipItem.cs:38` | `FlipItem.Execute` | mort | aucune carte n'utilise `FlipItem` dans les `data.json` |
| `Conditions/HeroHasAtachedItem.cs:14` | `HeroHasAtachedItem.Check` | mort | absente de tous les `data.json` (créée seulement par `AbilityFactory` à partir des données) |
| `Targets/CrossingHeroAtachedItem.cs:25` | `CrossingHeroAtachedItem.GetTargets` | mort | idem |
| `Targets/ItemInScorekeep.cs:32` | `ItemInScorekeep.GetTargets` | mort | idem |
| `Targets/ItemInTown.cs:29` | `ItemInTown.GetTargets` | mort | idem |
| `DBMGameProject.Services/CardAssetService.cs:118` | `CardAssetService.FindPackedTexture` | mort (défensif) | toutes les textures se résolvent |
| `WaveEngine.Extensions.ITasks/TaskSetOperationSelector.cs:67` | `TaskSetOperationSelector` | mort | aucun appelant |
| `WaveEngine.Extensions.ITasks/TaskSetOperationSelector.cs:84` | `TaskSetOperationSelector` | mort | aucun appelant |
| `WaveEngine.Extensions/BaseScene.cs:194` | `BaseScene` | mort | repli inatteignable |
| `DBMGameProject.Scenes.GamePlay/GamePlayBaseScene.cs:1333` | `GamePlayBaseScene.ChooseCardToDraw` | **atteignable** | BMA023 « Haunted Library » (`ChooseCardToDraw` au début du tour), joueur humain hors autoplay : `Boss.cs:270-276` -> `GameBoard.cs:367-371` -> `PlayerInteractionBase.cs:84-94` -> `HumanPlayerInteraction.cs:112-120` -> scène (`GamePlayBaseScene.cs:558`) ; aucun override dans les scènes MO/PaP/SP/Tut. Non vérifié : si l'exception est interceptée plus haut |

## 4. Glue Java (`apktool-decoded/smali/`, 196 fichiers)

165 `mono.*` (runtime Xamarin et proxies d'interfaces), 19 ACW `md5…` (AndroidActivity,
Application, GLView, BackgroundManager, NetworkChangeReceiver, gestion d'exceptions,
BillingService + stub AIDL, SplashView, 4 listeners de capteurs), 4 `opentk*` (surface GL),
8 `com.dbm.project.R` (ressources). Pas de Play services, de publicités, de push ni de Play Games.

**Aucune règle, logique de carte, animation ni son** : uniquement de la plomberie (cycle de vie,
billing IPC appelé par `WaveEngine.Framework.Services/InAppPurchase.cs`, capteurs inutilisés par
DBMGame, splash `#ebebeb`). `AndroidCustomService` est du C# pur (`HideSoftKeys`). Le multijoueur
de l'APK est Photon, en C# seulement. **Verdict : rien à porter.**

## 5. Shaders (147 fichiers : 71 `.fxo`, 44 `.frag`, 32 `.vert`)

143 sont des shaders génériques WaveEngine (BasicMaterial 54, BasicMaterial2D 14, DualTexture 14,
EnvironmentMap 12, NormalMapping 16, RimLight 8, Skybox 4, ToonShading 8, SpriteBatch 9,
LineBatch 4). Propre au jeu : `DBMGame.CardEffectpsTexture` / `CardEffectvsTexture` (GLSL + DX),
via `DBMGameProject.Common.Components/CardMaterial.cs:12` : grisage `mix(gris, couleur, Amount)`
(gris = 0,3 R + 0,55 G + 0,15 B, multiplié par la couleur de sommet). Déclencheur principal : carte
non jouable (`CardAttributesComponent.IsCardEnabled`, fondu 0,5 s CubicEase via `ColorFadeBehavior`,
opacité 0,8 ; calcul dans `CardManagerComponent.RefreshCardsStatus`). Le halo est un sprite séparé
(`CardGlow`) ; le retournement est `FlipCardBehavior` / `CardRotationBehavior`, sans shader.
**Verdict** : un seul effet propre au jeu (grisage des cartes injouables), à suivre dans la matrice
d'animations du lot 1.3.

## 6. Art alternatif de la galerie

`GalleryScene.cs:153-183` et `ScrollCardBehavior.AddElements`
(`DBMGameProject.Scenes.MainMenu.Entities/ScrollCardBehavior.cs:40-98`) : pour Room et Spell, une
tuile par exemplaire (`Quantity`), art `AlternativeArtId = num % (AlternativeArts + 1) + 1`
(1 -> `a`, 2 -> `b`, `CardAssetService.GetFrontCardAsset` l.203-218), sauf doublon immédiat.
Cartes avec `AlternativeArts = 1` (`BaseDeck/data.json`) : BMA017 Room ×2, BMA021 Room ×3, BMA023
Room ×2 (masquée dans la galerie), BMA029 Room ×3, BMA040 / BMA042 / BMA053 Spell ×2. La galerie
APK montre donc a,b / a,b,a / a,b,a / a,b / a,b / a,b.

Les images `src/frontend/assets/apk_cards/base/bma0XXb.webp` sont extraites par
`tools/extract_apk_226.py` ; `tools/verify_assets.py` exige `<id>a` … pour toute carte avec
`AlternativeArts > 0` ; `CardGallery.gd` émet les tuiles comme l'APK.

## 7. Polices

Le jeu n'utilise que les BMFont (`arcadepix`, `arcadepix2`, `bookman_old_style`, `.fnt` +
`_bm.png`, produits par `tools/build_bmfonts.py`) ; `f04b03.fnt` n'est chargé par aucun script
Godot (conservé : le lot 1.3 dira si une scène APK l'utilise). Il n'y a plus de TTF dans
`src/frontend/assets/fonts/`. `tools/build_fonts.py` reste la bibliothèque de lecture des
SpriteFont (importée par `build_bmfonts.py`) ; lancé seul, il reconstruit des TTF dans
`tools/.cache/fonts/` (gitignoré), que seul `tools/generate_placeholder_art.py` utilise (faces
provisoires RMB).
