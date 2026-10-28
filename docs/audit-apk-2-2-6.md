# Audit technique statique : Boss Monster 2.2.6 (Android, WaveEngine 1.4.2)

Rapport du 2026-10-27. Analyse **statique** de `apk-original/`. Rien n'a été exécuté ni intercepté sur le réseau.

Légende : **FAIT** = observé dans un fichier cité. **INFÉRENCE** = déduit des faits. **HYPOTHÈSE** = non prouvé, à vérifier. Les chemins sont relatifs à `apk-original/`.

## Champs du gabarit renseignés

| Champ | Valeur | Source |
|---|---|---|
| Jeu | Boss Monster (APK `boss-monster-2-2-6-android.apk`) | `apktool-decoded/AndroidManifest.xml:4` |
| Package | `com.dbm.project` | idem, l.2 |
| Version | `versionName` 2.2.6, `versionCode` 131298 | `apktool-decoded/apktool.yml:9-10` |
| Outils | apktool 3.0.3, ilspycmd, REA (`decompiled/evidence/`) | `apktool.yml:1`, `README.md` |
| Objectif | TOUT (sécurité, compatibilité, documentation, performance) | demande |
| Périmètre | APK, assemblies extraites, C# décompilé (560 `.cs`), smali (196 fichiers), assets | — |
| Hors périmètre | Serveurs distants, exécution, trafic réseau, clé privée de signature, Play Console | — |

---

## 1. Résumé exécutif

1. **FAIT** : la validation TLS est désactivée pour la requête de validation de code (`WebUtils.cs:19`, callback `=> true`). C'est le seul constat de sécurité *Élevée*.
2. **FAIT** : l'APK ne contient qu'une ABI, `armeabi-v7a` (32 bits). **INFÉRENCE** : il ne s'installe pas sur un appareil 64 bits uniquement.
3. **FAIT** : aucun `targetSdkVersion`, `allowBackup` ni `networkSecurityConfig` n'est déclaré. `minSdkVersion` = 11. **INFÉRENCE** : l'app tourne en mode de compatibilité legacy.
4. **FAIT** : télémétrie Xamarin Insights forcée (`AndroidActivity.cs:39-40`, `ForceDataTransmission = true`). Aucun mécanisme de consentement trouvé dans le C#.
5. **FAIT** : multijoueur Photon avec `AppId` et serveur en dur (`OnlineClient.cs:134-135`). Aucune authentification personnalisée trouvée. **INFÉRENCE** : jeu client-autoritaire, triche possible.
6. **FAIT** (DNS du 2026-10-27, depuis le poste d'audit) : `digitalbossmonster.azurewebsites.net` et les hôtes Insights testés ne se résolvent plus ; `app-eu.exitgamescloud.com` se résout encore (45.67.210.235, bloc néerlandais de G-Core Labs attribué à un client en 2022 d'après RIPE). Le domaine `exitgamescloud.com`, lui, est enregistré sans interruption depuis 2011 (RDAP Verisign) ; l'opérateur réel du serveur reste inconnu (S-13).
7. **FAIT** : composants tiers anciens (Mono.Android 5.1.3, Newtonsoft.Json 6.0.8, OpenTK 0.9.9.3, Photon 4.0.0.4) ; manifeste avec SDK fantôme (`ubertesters_project_id` et `UbertestersScreen` déclarés, aucune classe Ubertesters dans le smali ni dans `classes.dex`).
8. **FAIT** : signature APK uniquement v1 (JAR), confirmée par `apksigner verify -v` ; aucun schéma v2, v3, v3.1, v3.2 ou v4. Certificat RSA 2048, valide jusqu'en 2115 ; les digests du manifeste JAR sont SHA-1.
9. **FAIT** : pas de publicité, de Play Services, de push ni de Play Games (smali). Une seule activité exportée (le lanceur) et aucun receiver ni service déclaré.
10. **FAIT** : code non obfusqué, 918 TypeDefs lisibles et 22 `NotImplementedException`. Un point de lancement d'exception existe dans `GamePlayBaseScene.cs:1333`, mais la carte BMA023 associée est exclue du deck normal par `CardInfoService.cs:19,184` ; son atteignabilité en jeu normal n'est donc pas établie.

**Risques principaux** : MITM sur l'activation de code (S-01), télémétrie activée sans consentement observable dans le code (P-01), trafic Photon vers un serveur d'opérateur inconnu (S-13), compatibilité limitée à ARM 32 bits (C-01), signature v1 seulement (S-09).
**Priorités** : (1) pour un clone, ne pas porter le callback TLS permissif ; (2) ne pas reprendre une signature v1 seule ; (3) vérifier les obligations de confidentialité à partir des données effectivement envoyées et des documents de service, absents de l'APK.

---

## 2. Méthodologie et limites

- **Analysé** : `AndroidManifest.xml` (décodé et binaire), `apktool.yml`, `META-INF/*`, `lib/`, `classes.dex` (chaînes), smali (super-classes des 19 ACW, `Application.smali`), C# du jeu et parties pertinentes de `decompiled/Wave/` et `decompiled/Xamarin.Insights/`; signature contrôlée par `apksigner 37.0.0` ; chemins d'E/S et attributs de permissions des assemblies examinés ; en-têtes ELF, dépendances, symboles dynamiques et durcissement des 4 `.so` (pyelftools) ; résolution DNS des hôtes du jeu ; tailles des assets.
- **Décompilation complète (FAIT)** : les 27 assemblies gérées (C#, ilspycmd, dossier `decompiled/`) et les 4 bibliothèques natives (Ghidra 12 en ligne de commande : 285 + 5 164 + 733 + 3 fonctions, voir §7 et l'annexe) et `classes.dex` (1 152 méthodes avec code) ont été décompilés en totalité : 0 échec de l'outil, mais pseudo-code natif dégradé par endroits (voir lacune 1 et l'annexe) et 29 fichiers de bibliothèques avec avertissements ILSpy. Ce qui est « décompilé » n'est pas « relu ligne à ligne » : l'analyse a porté sur des balayages systématiques de toutes les sources (appels sensibles, chaînes, URL, secrets) puis sur la lecture détaillée des fonctions concernées.
- **Non analysé** : lecture intégrale du pseudo-code de `libmonosgen-2.0.so` (5 164 fonctions) et d'OpenAL (733) ; contenu des shaders, audio et textures (repris du README) ; contenu de `resources.arsc` ; comportement à l'exécution, trafic réseau, contenu des paquets Photon et Insights, identité du titulaire du domaine `exitgamescloud.com` (masquée dans le RDAP) et opérateur du serveur Photon actuel.
- **Limites de la décompilation** : ilspycmd reconstruit du C# lisible mais perd les commentaires, certains noms locaux et l'état des `async`. Sur les 323 types générés par le compilateur (avec `<Module>`), 297 sont des fermetures de lambdas (`DisplayClass`), 20 des types `<…>d__` (dont 11 machines `async`, les autres étant probablement des itérateurs), plus 3 `__StaticArrayInitTypeSize` et `<PrivateImplementationDetails>`.
- **Reprise du README** : le décompte de 22 `NotImplementedException`, la ligne 1333 et l'exclusion de BMA023 du deck normal ont été vérifiés. Les 21 verdicts « morts » ont été revérifiés (voir §6) : 20 confirmés pour les données livrées, 1 nuancé (`FindPackedTexture`). L'atteignabilité de `ChooseCardToDraw` en jeu normal n'est pas prouvée.
- **Confiance globale** : *Haute* pour les faits cités, *Moyenne* pour la couverture (aucune analyse dynamique ; analyse native statique par balayage, pas par relecture intégrale).

## 3. Métadonnées de l'APK

| Élément | Valeur | Statut |
|---|---|---|
| Taille / SHA-256 | 47 679 680 octets / `78592B48…2FFD` | FAIT (`Get-FileHash`, égal au README) |
| Package | `com.dbm.project` | FAIT |
| Version | 2.2.6 / 131298 | FAIT |
| minSdk / targetSdk | 11 (Android 3.0) / **non déclaré** | FAIT (`apktool.yml:7-8`) |
| `platformBuildVersion` | 15 / `4.0.4-1406430` | FAIT |
| Écrans | `largeScreens` + `xlargeScreens` uniquement, `requiresSmallestWidthDp=600`, `normalScreens=false` | FAIT (manifeste l.3) |
| Orientation | paysage forcé | FAIT (manifeste l.7) |
| Signature | CN=DBM, série `79e92dae`, RSA 2048, SHA256withRSA, du 2015-03-02 au 2115-02-06 | FAIT (`keytool`/`openssl` sur `META-INF/DBM.RSA`) |
| Empreinte du certificat | SHA-256 `57:76:76:82:03:15:CF:E6…44:48:08:8C` | FAIT |
| Schéma | `DBM.SF` + `DBM.RSA`, digests SHA-1 | FAIT : `apksigner verify -v` confirme v1=true et v2/v3/v3.1/v3.2/v4=false |
| ABI | `armeabi-v7a` seule (ELF machine `0x28` = ARM) | FAIT |

Structure : `assets/Content/` (Audio, CardDecks, Common, Fonts, Loading, NinePatch, Tutorial, `EXPANSIONS.wpk`), `lib/armeabi-v7a/` (4 `.so`), `res/` (8 fichiers), `classes.dex` (249 196 octets), `resources.arsc` (2 260 octets).

## 4. Architecture Android

**Manifeste** (`apktool-decoded/AndroidManifest.xml`, FAIT) :

| Composant | Détail | Exporté ? |
|---|---|---|
| `md5399…AndroidActivity` | `MAIN`/`LAUNCHER`, `singleTask`, paysage | Oui (intent-filter) : normal pour un lanceur |
| `com.ubertesters.sdk.UbertestersScreen` | aucun intent-filter | INFÉRENCE : non exporté (défaut) |
| `mono.MonoRuntimeProvider` | `exported="false"`, `initOrder=2147483647` | Non |
| Receivers / Services | **aucun déclaré** | — |
| Deep links | **aucun** | — |

**Permissions** (7) : `GET_TASKS`, `WRITE_EXTERNAL_STORAGE`, `SYSTEM_ALERT_WINDOW`, `BILLING`, `INTERNET`, `ACCESS_NETWORK_STATE`, `ACCESS_WIFI_STATE`.

**Configuration** : `android:debuggable` absent (INFÉRENCE : `false`), `android:allowBackup` absent (INFÉRENCE : `true` par défaut sur cette cible), `usesCleartextTraffic` et `networkSecurityConfig` absents. `android:installLocation="auto"`.

**Classes Java générées non déclarées au manifeste** (FAIT, `apktool-decoded/smali/md5*`) : `NetworkChangeReceiver` (super-classe `BroadcastReceiver`) et `BillingService` (super-classe `Service`) existent mais ne figurent pas dans le manifeste. **INFÉRENCE** : le receiver est enregistré dynamiquement (jamais exporté) ; `BillingService` n'est pas démarrable depuis l'extérieur puisqu'aucune entrée de manifeste ne l'expose. **FAIT** (`decompiled/Xamarin.Insights/Xamarin.InsightsCore/NetworkChangeReceiver.cs:7,61`) : `NetworkChangeReceiver` est une classe interne du SDK Xamarin Insights, qui s'enregistre à l'exécution sur `android.net.conn.CONNECTIVITY_CHANGE` ; `BackgroundManager` (même paquet `md5797f…`, `BackgroundManager.cs:12`) implémente `ActivityLifecycleCallbacks`. Ces deux classes sont donc du code Insights, pas du jeu. Le seul autre `registerReceiver` du smali est celui de `mono.android.app.Application.onCreate` (action `TIMEZONE_CHANGED`, `Application.smali:41-51`). Le receiver n'est pas exporté (enregistrement dynamique). `BillingService` (super-classe `Service`) n'a aucune entrée de manifeste : elle ne peut pas être démarrée de l'extérieur.

## 5. Architecture WaveEngine

- **Version** : `WaveEngineAndroid.Framework.dll` = 1.4.2.0 (FAIT). Les autres DLL `WaveEngineAndroid.*` sont dans `extracted_assemblies/`.
- **Moteur Mono** : `libmonosgen-2.0.so` (SGen), `libmonodroid.so`, `Mono.Android.dll` 5.1.3 (Xamarin.Android 5.1). Les assemblies sont embarquées dans `libmonodroid_bundle_app.so` et non dans `assets/`.
- **Rendu** : OpenTK 0.9.9.3 (OpenGL ES), 147 shaders (`.fxo`/`.frag`/`.vert`), dont 143 génériques WaveEngine et 1 effet propre au jeu (`CardEffect*Texture`, grisage des cartes injouables). Source : README §5.
- **Entités et services** : namespaces `DBMGameProject.Scenes.*`, `.Services.*` (Online, AppPurchase, Log, `CardInfoService`, `CardAssetService`), `.Storage`, `.Common.Components`. Architecture scène/entité/composant de WaveEngine.
- **Règles** : `DBMGameModel.*` (modèle pur, `Logic.Abilities.{Commands,Conditions,Targets}`), séparé de l'UI. C'est ce qui rend l'oracle .NET possible.
- **Entrées** : tactile (scènes) et touche Retour (`AndroidActivity.cs:65-87`). Capteurs : 4 listeners en smali, inutilisés par DBMGame (README §4).
- **Audio** : OpenAL (`libopenal32.so`), SFX/musique en `.wpk`.
- **Assets** : conteneurs `.wpk` (WaveEngine Package), non compressés dans l'APK (`apktool.yml` `doNotCompress`).
- **Sauvegarde** : `WaveServices.Storage.Read/Write<T>` avec 8 essais (`StorageHelper.cs:9-60`) ; types `GameSettings`, `GameStats`, `PurchasedItems`, `OnlineStorage`. Un répertoire `gamesaves` et un suffixe `_bk` sont déclarés (`StorageHelper.cs:11-13`), mais les constantes ne sont pas utilisées dans le fichier lu.
- **Points d'extension** : decks JSON (`CardDecks/*/data.json`) chargés par Newtonsoft via `CardInfoService.cs:75-79`. Les extensions (`EXPANSIONS.wpk`) passent par la même voie.

## 6. Code C# / assemblies

- **Application** : `DBMGame.dll` (888 832 octets), 560 `.cs`, 53 842 lignes (arbre `decompiled/`), 918 TypeDefs (README §2).
- **Moteur** : 8 DLL `WaveEngineAndroid.*` (Adapter, Bepu, Common, Components, Farseer, Framework, Materials, Physics).
- **Tierces** : `Newtonsoft.Json` 6.0.8, `Photon3DotNet` 4.0.0.4 + `PhotonLoadbalancingApi`, `Xamarin.Insights` 1.9, `play.billing.v3` + `InAppServiceBinding`, `OpenTK`/`OpenTK-1.0`, `Zlib.Portable`, `System.Json`, BCL Mono.
- **Obfuscation** : **aucune observée**. Types, méthodes et chaînes sont en clair. Les assemblies sortent telles quelles du bundle.
- **Réflexion** : Newtonsoft avec `InternalJsonContractResolver` (`CardInfoService.cs:76`).
- **P/Invoke** : aucune déclaration trouvée dans le C# du jeu ; le code du moteur déclare `memcpy` depuis `libc` (`Wave/Common/WaveEngine.Common/UnsafeMethods.cs`) et des fonctions OpenAL depuis `libopenal32.so` (`Wave/Adapter/WaveEngine.Audio.OpenAL/{AL,Alc}.cs`). Les `.so` n'ont pas été désassemblées pour vérifier les exports.
- **`NotImplementedException`** : 22 occurrences confirmées. Le site `ChooseCardToDraw` existe à `GamePlayBaseScene.cs:1333`, mais BMA023 est filtrée du deck normal (`CardInfoService.cs:19,184`) ; appeler ce site en jeu normal n'est pas démontré. Les 12 méthodes `Undo` levant l'exception sont confirmées mortes dans le cas observé : `Effect.Undo` (`Effect.cs:70-86`) appelle `Undo` sur *toutes* les commandes de l'effet, mais n'est atteinte que via `Ability.UndoEffect` (`Ability.cs:138-148`), elle-même appelée uniquement par `GameBoard.cs:697-699` quand `IsUndoableType()` est vrai (`Ability.cs:247-250`, présence d'une commande `IUndoableCommand`). Seule `DeactivateDungeonAbility` implémente cette interface, et son unique occurrence dans les données (`CardDecks/PlayerChoice/data.json:461`) est seule dans son tableau `Commands`. **Fragilité** : si une carte d'extension associait cette commande à une autre commande dans le même effet, `Undo` lèverait l'exception à l'exécution. 

Les 9 autres sites (FAIT, recherche des références dans tout `decompiled/DBMGame/`) :

| Site | Verdict revérifié |
|---|---|
| `FlipItem.Execute`, `HeroHasAtachedItem.Check`, `CrossingHeroAtachedItem`, `ItemInScorekeep`, `ItemInTown` | **Confirmés morts pour les données livrées** : aucune référence directe dans le C#, aucune occurrence du `TypeName` correspondant dans les `data.json` de l'APK. Ces classes sont instanciées par réflexion (`AbilityFactory.cs:47,68,95` : `Activator.CreateInstance`) à partir du nom des données. Elles deviendraient atteignables si une extension les utilisait |
| `TaskSetOperationSelector.cs:67` et `:84` | **Confirmés morts, mais la classe est très utilisée** (`TaskFactory.cs` l'instancie, `WaitAll`/`WaitAny` partout). Le README dit « aucun appelant » : c'est inexact pour la classe, exact pour ces deux lignes. La ligne 67 n'est atteinte que si le paramètre n'est ni `IEnumerable<Func<ITask>>`, ni `ICollection<Func<ITask>>`, ni `IEnumerable<ITask>`, ni `ICollection<ITask>` ; toutes les fabriques passent des tableaux de `Func<ITask>` ou d'`ITask`. `WaitPredicate` n'a aucun appelant (`ITaskSet.cs:11` et sa définition seulement) |
| `BaseScene.CreateScopedLabel` (`BaseScene.cs:192-195`) | **Confirmé mort** : aucun appelant |
| `CardAssetService.FindPackedTexture` (`CardAssetService.cs:102-121`) | **Nuancé** : appelée en trois endroits (`:128,208,238`), elle lève l'exception (message « Texture not found ») si le nom de texture sort de toutes les plages de fichiers `.wpk` du deck. Le README la dit morte parce que toutes les textures livrées se résolvent ; c'est un garde-fou, atteignable si une donnée est incohérente |
- **Maintenabilité** : bonne séparation modèle/UI. Fautes de nommage d'origine (`HeroHasAtachedItem`, `BCKUP_SUFIX`, `Conected`) à conserver pour la parité. La constante `nothingimportantatall = "vicmamoj"` (`SerialHelper.cs`) n'a pas été tracée.

### Balayage systématique des 27 assemblies décompilées (FAIT)

Les 27 assemblies de `extracted_assemblies/` sont décompilées dans `decompiled/` (`Wave/` regroupe `Adapter`, `Common`, `Components`, `Framework`, `Materials`, `Physics` ; les 21 autres ont chacune leur dossier : `DBMGame` 560 fichiers `.cs`, `mscorlib` 1 104, `Wave` 671, `Mono.Android` 392, `WaveEngineAndroid.Bepu` 436, `System` 365, `System.Xml` 357, `WaveEngineAndroid.Farseer` 200, `Newtonsoft.Json` 201, `Xamarin.Insights` 122, etc.). Recherche par motifs sur l'ensemble des sources :

| Motif | Résultat (FAIT) |
|---|---|
| `Process.Start` / `ProcessStartInfo` | uniquement dans `System.Diagnostics` (BCL) ; aucune occurrence dans `DBMGame`, `Wave`, `Xamarin.Insights` |
| `Assembly.Load*` | `DBMGame/ResourceManager.cs:42` et `Wave/SerializationUtils.cs:54` : chargement d'assemblies par `AssemblyName` issu des métadonnées de types (références statiques), pas d'entrée externe ; le reste est du BCL |
| `BinaryFormatter`, `SoapFormatter`, `NetDataContractSerializer`, `LosFormatter` | uniquement dans le BCL (`mscorlib`, Remoting) ; non utilisés par le jeu |
| `TypeNameHandling.All/Auto/Objects/Arrays` | `GameBoardFlowInfo.cs` (2, types de journal jamais désérialisés, cf. S-15) et le code interne de Newtonsoft.Json |
| `ServerCertificateValidationCallback` | `DBMGame/WebUtils.cs:19` (S-01) ; le reste est le BCL (`ServicePointManager`, `SslStream`) |
| `HttpWebRequest` / `WebClient` / `WebRequest.Create` | `WebUtils.cs` (jeu), `Xamarin.Insights/WebPoster40.cs`, `Photon3DotNet/HttpBase3.cs`, `Wave/Common/WebClient.cs` (classe d'événements sans appelant dans le jeu) ; le reste est le BCL |
| `new TcpClient/UdpClient/Socket(`, `TcpListener` | `Photon3DotNet` (`SocketTcp`, `SocketUdp`, `SocketUdpAsync`, `PingMono`) et le BCL |
| `DllImport` | OpenAL (`Wave/Adapter/…/AL.cs`, `Alc.cs`, `OpenTK-1.0`), OpenGL ES (`OpenTK*`), `libc` `memcpy` (`Wave/Common/UnsafeMethods.cs:8`), `JNIEnv` et `Logger`/`AndroidEnvironment` (`Mono.Android`), BCL ; aucun P/Invoke dans `DBMGame` |
| `GetEnvironmentVariable` / `Set…` | BCL, `Mono.Android/JNIEnv.cs` ; aucun dans `DBMGame` |
| `GetExternalStorage…` | `Xamarin.Insights/HardwareDetector.cs` (2) seulement |
| URL en dur (hors schémas XML et documentation) | `DBMGame` : `https://digitalbossmonster.azurewebsites.net/DBM/ValidateCodeWithPlatform/` (2 occurrences) ; `Photon3DotNet` et `PhotonLoadbalancingApi` : `http://www.exitgames.com` (texte) ; `Zlib.Portable` : `codeplex.com/DotNetZip` ; `OpenTK-1.0` : `opentk.com` ; aucune dans `Wave`, `Xamarin.Insights`, `play.billing.v3`, `InAppServiceBinding`, `Bepu`, `Farseer`, `Newtonsoft.Json` |
| Secrets (`api_key`, `secret`, `password`, `token` affectés à une chaîne) | une seule constante, `INAPP_CONTINUATION_TOKEN = "INAPP_CONTINUATION_TOKEN"` (nom d'une clé du protocole Play Billing, pas un secret) |

Limites : ces balayages sont textuels sur du C# décompilé ; une valeur construite dynamiquement (par exemple l'hôte d'Insights, absent des URL en dur) n'apparaît pas. `Activator.CreateInstance` / `Type.GetType` (80 occurrences) n'ont pas été triés un par un en dehors de `AbilityFactory` (voir plus haut).

## 7. Bibliothèques natives et JNI

Analyse des en-têtes ELF et des symboles dynamiques (FAIT, pyelftools ; aucun désassemblage du code machine) :

| Fichier | Taille | Dépendances (`DT_NEEDED`) | Symboles dyn. exportés / importés | Durcissement | Rôle |
|---|---|---|---|---|---|
| `libmonodroid_bundle_app.so` | 3 153 388 | libc, libm, libdl, liblog, libz | 31 / 10 | `.symtab` présent (non strippé), pas de canari de pile, **pas de RELRO, pile exécutable (`PT_GNU_STACK` avec le bit X)** | bundle de 27 assemblies (`assembly_data_*_dll`, `mono_mkbundle_init`) |
| `libmonosgen-2.0.so` | 2 769 812 | libdl, libc, liblog, libm | 994 / 250 | RELRO, strippé, pas de canari ; importe `system`, `execve`, `fork`, `mprotect`, `strcpy`, `sprintf` | runtime Mono SGen (API `mono_*`) |
| `libmonodroid.so` | 140 756 | libdl, libm, liblog, libc, libstdc++, libz | 159 / 111 | RELRO, canari, strippé ; importe `socket`, `connect`, `execl`, `fork`, `strcpy`, `strcat`, `sprintf` | pont Xamarin.Android (`monodroid_*`, `unz*` pour lire l'APK, `CreateNLSocket`/`ReadEvents`) |
| `libopenal32.so` | 353 988 | libdl, libOpenSLES, liblog, libstdc++, libm, libc | 328 / 100 | RELRO, canari, strippé | OpenAL Soft sur OpenSL ES (`al*`, extensions `SOFT`) |

Toutes ELF ARM 32 bits. Aucune dépendance sur une bibliothèque propre au jeu. Les imports de fonctions « dangereuses » (`system`, `execve`, `strcpy`…) sont ceux d'un runtime Mono et d'un pont Xamarin standard, pas la preuve d'un défaut exploitable. Le seul point de durcissement anormal est `libmonodroid_bundle_app.so` (pile exécutable, sans RELRO) : elle ne contient que des données et deux symboles d'init, donc le risque pratique est faible (S-14).

**Désassemblage ARM (FAIT, lecture statique seule).** Première passe avec rizin 0.9.1 (`aa`), puis passe complète avec Ghidra 12 en ligne de commande (`analyzeHeadless`, décompilation des 257 fonctions de `libmonodroid.so`). Le fournisseur Ghidra de REA n'accepte que les PE sous Windows (REA a refusé l'ELF ARM), d'où l'appel direct à `analyzeHeadless`. Ghidra charge l'ELF à la base `0x10000` : ses adresses valent celles de rizin + `0x10000`, et j'ai résolu les chaînes des pools de littéraux avec un script qui lit le fichier. Le désassembleur a trouvé 257 fonctions dans `libmonodroid.so` (strippée, RELRO complet, `rizin` détecte le compilateur « GCC 4.9 20140827 »).

| Fonction | Adresse | Ce que fait le code (FAIT) |
|---|---|---|
| `mono_mkbundle_init` + `my_inflate` (`libmonodroid_bundle_app.so`) | `0xdd8`, `0xca8` | Parcourt la table des assemblies, alloue la taille déclarée (`malloc`), décompresse chacune avec zlib en mode gzip (`inflateInit2` avec `windowBits = 0x1f`, puis `inflate`/`inflateEnd`) puis remplace le pointeur compressé. En cas d'échec : `fprintf` du nom puis `exit(1)`. Aucun appel réseau, `exec` ni `dlopen`. Les tailles viennent de la table générée à la compilation, sans validation à l'exécution |
| `monodroid_dylib_mono_init` | `0x3d38` (6 256 octets) | `dlopen` de `libmonosgen-2.0.so`, puis une centaine de `dlsym` pour résoudre les fonctions `mono_*`. Chaînes associées : « Trying to load sgen from: %s », « cannot find libmonosgen-2.0.so in app_libdir… nor in runtime_libdir » |
| `monodroid_debug_connect` | `0xa1c0` | Passe le socket en non bloquant (`fcntl`), `connect` vers l'adresse IPv4 (16 octets) fournie par l'appelant, attend avec `select`, lit `SO_ERROR` avec `getsockopt`, restaure le mode bloquant. Retourne 1 en cas de succès, des codes négatifs sinon |
| `monodroid_debug_accept` | `0xa3b8` | `bind`, `listen` puis `accept` : mode serveur du même transport de débogage |
| `fcn.000151ac` | `0x151ac` | Second `dlopen` (chargement de bibliothèques natives à la demande) |
| `entry0` (zone adjacente à `CreateNLSocket`) | `0x3690`, `0x3740` | `socket` puis `bind` : socket netlink (INFÉRENCE d'après les exports `CreateNLSocket`/`ReadEvents`), utilisé par Mono pour l'état du réseau |

**Chaînes de configuration lues par `libmonodroid.so`** (FAIT, `.rodata`) : propriétés système `debug.mono.{debug,connect,extra,gdb,gdbport,runtime_args,env,log,trace,profile,gc,wref,max_grefc}`, `mono.llvm`, `persist.sys.dalvik.vm.lib`, `ro.build.version.{sdk,release}`, et un répertoire `%s/.__override__`. **Correction d'une lecture précédente** : le message « Ignoring debug.mono.gdb system property setting. » n'est pas un refus. Il est journalisé seulement quand aucun `gdbserver` n'est trouvé (`FUN_0001b4e0`, Ghidra `0x1b4e0`).

**Chaîne de lancement d'un débogueur natif (FAIT, décompilation Ghidra)** :
1. `FUN_0001b778` (`0x1b778`) retourne vrai si la propriété `debug.mono.gdb` est non vide, ou si un fichier `<répertoire>/gdb` existe (deux répertoires testés ; le fichier est supprimé par `unlink`).
2. Dans ce cas, `FUN_0001b4e0` cherche un exécutable `gdbserver` (`libgdbserver.so` dans les répertoires de l'application, puis `/system/bin/gdbserver`). Sans résultat : message « Unable to find gdbserver! ».
3. Avec un résultat : `getpid`, `fork`, puis dans l'enfant `execl(gdbserver, …, <adresse>, <pid>)`. L'adresse vient de `debug.mono.gdbport` (sinon `:9999`). Le parent attend 2 s (`sleep`). En cas d'échec d'`execl` : « Start of gdbserver failed » puis `exit(0x46)`.
4. L'appel est fait depuis l'initialisation du runtime (`FUN_0001b86c`, `0x1b86c`), juste après `monodroid_embedded_assemblies_install_preload_hook`.

**Autres lectures de propriétés, avec fonction** (FAIT) : `debug.mono.connect` et `debug.mono.extra` dans la fonction d'initialisation du runtime (Ghidra `0x1f1xx`–`0x1f2xx`) ; si `connect` est présent, `start_connection` (`connect` ou `accept`) puis, en cas d'échec, `exit(3)`. `debug.mono.extra` est analysée par `FUN_0001ac2c` et produit `--debugger-agent=transport=dt_socket,…,embedding=1`. `debug.mono.runtime_args`, `env`, `gc`, `trace`, `profile`, `log`, `wref`, `max_grefc` sont lues chacune dans une fonction d'initialisation distincte. `monodroid_get_namespaced_system_property` (`0x1fbdc`) tente d'abord `<nom>.<suffixe global>` quand un indicateur global est actif (suffixe non résolu), puis le nom nu, via `__system_property_get`. Le répertoire `%s/.__override__` est construit par `FUN_0001676c` à partir du répertoire de fichiers de l'application (appel JNI) et conservé dans une variable globale.

**Pont de débogage Xamarin Studio (« XS ») sur TCP (FAIT, décompilation Ghidra)** : quand `debug.mono.connect` est défini, `FUN_00020810` y lit l'option `port=<n>` (toute autre option : « Unknown connection option »). `start_connection` (`0x20938`) lance un fil d'exécution qui exécute `FUN_00020bb8` (`0x20bb8`) : `socket`, `SO_REUSEADDR`, `bind` sur **toutes les interfaces (adresse 0.0.0.0, octets d'adresse à zéro)** au port demandé, `listen(1)`, puis `accept` avec des fenêtres d'attente de 2 s (« Listened… for 2 seconds, nobody connected »). Le pair accepté envoie des commandes (un octet de longueur puis le texte, 255 octets au plus) traitées par `process_cmd` (`0x1e1cc`) **sans authentification** : `connect output|stdout|stderr` (`dup2` du socket sur stdout/stderr, donc les journaux du processus sont envoyés au pair), `ping`/`pong`, `exit process` (`exit(0)`), `start debugger: sdb` (initialise l'agent de débogage Mono avec `transport=socket-fd`), `start profiler: log:…`. Toute autre commande : « Unsupported command ». Cela corrige ma lecture précédente : `debug.mono.connect` ouvre un **écouteur** TCP (le `connect` sortant de `monodroid_debug_connect` sert à l'agent `dt_socket`, qui vient de `debug.mono.extra`).

**Chargement d'assemblies depuis un dossier de remplacement (FAIT, décompilation Ghidra)** : le crochet de pré-chargement Mono installé par `monodroid_embedded_assemblies_install_preload_hook` (`0x158fc`) passe par `open_from_update_dir` (`FUN_000199d0`, `0x199d0`, journal « open_from_update_dir: trying to open assembly: %s »). Si l'un des deux dossiers de remplacement existe, la fonction y essaie jusqu'à trois formes de chemin (`%s/%s` etc.) pour l'assembly demandée et, si le fichier existe, l'ouvre avec `mono_assembly_open_full`. Un dossier est `<répertoire de fichiers de l'application>/.__override__` (`FUN_0001676c`) ; **le second dossier n'est pas identifié**. Au démarrage, `FUN_00019de0` compte les `.dll` de ces dossiers : si l'APK ne contient aucune assembly et que ces dossiers n'en contiennent pas non plus, le runtime s'arrête (« Assuming this is part of Fast Deployment. Exiting… », `exit(0x41)`). Je n'ai trouvé aucune vérification de signature ni de hachage sur ces fichiers, ni de condition « déboguable » (voir ci-dessous). C'est le mécanisme Xamarin « Fast Deployment » : une assembly déposée dans ce dossier remplace celle du bundle. Écrire dans `<files>/.__override__` exige de pouvoir écrire dans le répertoire privé de l'application (root, ou `run-as`, indisponible ici puisque le manifeste ne déclare pas `debuggable`) : INFÉRENCE sur les droits Android, non testée.

Un message « This installation from the trial license has expired. Please rebuild and reinstall your app. » (`FUN_0001e104`, `exit(0xb)`) correspond au mode d'essai Xamarin activé par la propriété `xamarin.android.trial` ; il n'est pas actif sans cette propriété (INFÉRENCE d'après `FUN_0001f1xx`, qui lit `xamarin.android.trial` dans un drapeau global).

**Aucun contrôle « application déboguable » ni de uid** n'a été trouvé dans `libmonodroid.so` : la recherche de `debuggable`, `ro.debuggable`, `getuid`, `geteuid` dans toute la décompilation ne donne rien (FAIT, recherche textuelle sur le pseudo-code).

**`libmonosgen-2.0.so` : appelants de `system`, `execv`, `execve`, `fork` (FAIT, Ghidra, pseudo-code et chaînes résolues)** : tous appartiennent au runtime Mono standard, aucun n'est spécifique au jeu.
- `system` : compilateur AOT du runtime (assembleur `as`, éditeur de liens `ld`, `strip`) et un traceur de graphes qui écrit `/tmp/minidtree.graph` puis lance `dot … ; gv` (outils de développement Mono).
- `execv` : rendu des traces natives en cas de plantage (`gdb` ou `lldb` avec `attach <pid>`, `info threads`, `thread apply all bt`).
- `fork` + `execve` : création de processus de `System.Diagnostics.Process` (`wapi_CreateProcess`, `io-layer/processes.c`) et `g_spawn` d'eglib (`gspawn.c`).
Ces chemins existent dans le binaire ; je n'ai pas établi s'ils sont atteignables depuis le jeu (aucune occurrence de `Process.Start`, `System.Diagnostics.Process` ou `ProcessStartInfo` dans le C# décompilé de `DBMGame/` et `Wave/`, recherche faite pour ce rapport ; les autres assemblies tierces n'ont pas été fouillées pour ce motif).

**Couverture de la décompilation native (FAIT, Ghidra `analyzeHeadless`, première passe : 279 / 4 657 / 518 fonctions avec un délai de 30 s par fonction ; effectifs finaux après rattrapage du code hors fonction dans l'annexe)**

| Bibliothèque | Fonctions décompilées | Échecs | Balayage réalisé |
|---|---|---|---|
| `libmonodroid.so` | 285 (dont 139 nommées parmi les 279 premières) | 0 | appels sensibles, chaînes, propriétés, chemins ; fonctions clés relues (voir ci-dessus) |
| `libmonosgen-2.0.so` | 5 164 | 0 (2 reprises après un premier échec, voir l'annexe) | appelants de `system`, `exec*`, `fork`, `dlopen`, sockets, `getenv`, `setenv`, `chmod`, `kill`, `unlink`, `fopen`, chemins, variables d'environnement |
| `libopenal32.so` | 733 | 0 | idem |
| `libmonodroid_bundle_app.so` | 3 | 0 | lecture intégrale (`install_dll_config_files` vide, `my_inflate`, `mono_mkbundle_init`) |

Résultats du balayage de `libmonosgen-2.0.so` (FAIT) : `system` (2 fonctions : compilation AOT et traceur de graphes `dot|gv`), `execv` (1 : rendu des traces natives avec `gdb`/`lldb`), `fork` + `execve` (2 : `Process` et `g_spawn`), `dlopen` (2), sockets (agent de débogage Mono `debugger-agent.c` : écoute, connexion, acceptation ; couche `_wapi_*` de `System.Net.Sockets`), `getaddrinfo` (1, résolution `networking-posix.c`), `setenv` (1), `chmod` (3), `kill` (2, `kill(pid, 0)` de test d'existence relevé dans l'une d'elles), `unlink` (8), `rename` (5), `fopen` (29). Chemins en dur : `/dev/{null,random,urandom,zero,rtc}`, `/proc/*` (`cpuinfo`, `self/maps`, `self/exe`, `mounts`, `net/dev`, `stat`, `uptime`, `loadavg`), `/etc/mnttab`, `/tmp` et `/tmp/minidtree.graph`. Aucune URL en dur hors un message renvoyant à `mono-project.com/download`. Variables d'environnement lues (35) : `MONO_PATH`, `MONO_CONFIG`, `MONO_CFG_DIR`, `MONO_GAC_PREFIX`, `MONO_DEBUG`, `MONO_GC_PARAMS`, `MONO_SDB_ENV_OPTIONS`, `MONO_XDEBUG`, `MONO_LOG_LEVEL`, `MONO_LOG_MASK`, `MONO_EGD_SOCKET`, `HOME`, `TMPDIR`, etc. Elles deviennent pilotables par propriété système via `debug.mono.env` (voir ci-dessous).

Résultats du balayage d'`libopenal32.so` (FAIT) : aucun `system`, `exec*`, `fork`, `popen` ni socket ; `dlopen` dans une seule fonction (`libOpenSLES.so`) ; `getenv` dans 4 fonctions (`ALSOFT_CONF`, `ALSOFT_DRIVERS`, `ALSOFT_LOGFILE`, `ALSOFT_LOGLEVEL`, `ALSOFT_DEFAULT_REVERB`, `ALSOFT_TRAP_*`, `XDG_CONFIG_HOME`, `XDG_CONFIG_DIRS`) ; `fopen` dans 5 (fichiers `alsoft.conf` : `/etc/openal/alsoft.conf`, `$XDG_CONFIG_*`, et le fichier de journal `ALSOFT_LOGFILE`) ; lecture de `/proc/cpuinfo`. Aucune URL.

**`debug.mono.env` (FAIT, décompilation Ghidra)** : `FUN_0001d4c0` (`0x1d4c0`) lit `debug.mono.env`, découpe la valeur sur `|` et appellent `setenv(nom, valeur, 1)` pour chaque élément `NOM=valeur` (valeur « 1 » si `=` est absent), avec le journal « Env variable '%s' set to '%s' ». N'importe quel nom est accepté, donc `MONO_PATH`, `MONO_CONFIG`, `MONO_DEBUG`, `MONO_SDB_ENV_OPTIONS`… sont pilotables par propriété système avant l'initialisation du runtime Mono (INFÉRENCE pour l'ordre d'initialisation exact, FAIT pour la lecture et le `setenv`). Cela étend S-17.

**Limites de ce désassemblage** : la décompilation est du pseudo-code Ghidra, pas le code source ; les noms `FUN_…` sont ceux de Ghidra (le binaire est strippé). Je n'ai pas exécuté l'application : que le déclenchement par propriété fonctionne sur un appareil réel est une INFÉRENCE d'après le code, non testée. `libopenal32.so` (OpenAL Soft) a été analysée avec Ghidra pour les appels sensibles : aucun appel à `system`, `exec*`, `fork`, `popen` ni `socket`. Elle importe `dlopen` (un seul site d'appel, chargement de `libOpenSLES.so`, FAIT d'après les chaînes ; le détail de la fonction n'a pas été relu), `getenv` et `fopen`, avec des variables `ALSOFT_*` (`ALSOFT_LOGFILE`, `ALSOFT_DRIVERS`, `ALSOFT_SOUNDFONT`…) : ce sont des variables d'environnement du processus, non modifiables sans accès à l'appareil (INFÉRENCE). Le code managé consulté ne montre pas de P/Invoke propre au jeu ; les imports natifs repérés appartiennent au moteur (libc et OpenAL). Les quatre `.so` ont été examinées pour leurs appels sensibles ; la logique interne de `libmonosgen-2.0.so` et d'OpenAL n'a pas été relue en entier. Le pont JNI est généré par Xamarin (proxies `mono.*`, 165 fichiers smali). Aucun code natif séparé du jeu n'a été trouvé (aucune `.so` hors Mono/OpenAL).

## 8. Réseau et backend

| Endpoint | Preuve | Usage |
|---|---|---|
| `https://digitalbossmonster.azurewebsites.net/DBM/ValidateCodeWithPlatform/{code}/{platform}` | `AppPurchaseService.cs:22,268` | validation de codes de déverrouillage |
| `app-eu.exitgamescloud.com:5055` | `OnlineClient.cs:135` | Photon Cloud (multijoueur) |
| Xamarin Insights (hôte non identifié) | `AndroidActivity.cs:39` | télémétrie et crashs |

- **HTTP/HTTPS** : HTTPS pour le backend de codes. Photon : protocole non précisé dans le code. **INFÉRENCE** : UDP par défaut du SDK Photon 4.0, sans chiffrement activé (aucune occurrence de `EncryptionMode`/`ConnectionProtocol`).
- **Pinning** : aucun. Pire, la validation de certificat est neutralisée (S-01).
- **WebView, deep links** : aucun.
- **Authentification** : aucune trouvée (ni `AuthenticationValues`). Le nom de joueur est aléatoire (`StringFactory.RndWord(24)`, `OnlineClient.cs:133`).
- **Secrets en dur** : `AppId` Photon, clé Insights, clé publique de facturation (S-03 à S-05).
- **Messages Photon entrants** : `OnlineService.RaiseInternalEvent` (`OnlineService.cs:878-896`) désérialise la charge JSON reçue d'un autre joueur avec `JsonConvert.DeserializeObject<TMessage>(value)`, sans `TypeNameHandling` : le défaut de Newtonsoft (`None`) évite l'instanciation de types arbitraires. En revanche, `hashtable[2]`, `photonEvent[254]` et `photonEvent[245]` sont lus sans contrôle de type ni de nullité (`hashtable` peut être `null`), et un pair malveillant peut donc provoquer une exception. `TypeNameHandling.All` n'apparaît que sur deux propriétés du journal de partie (`GameBoardFlowInfo.cs:21,30`), pas sur les messages réseau ; sa désérialisation éventuelle n'a pas été retracée (S-15).
- **Disponibilité des serveurs** (FAIT, résolution DNS le 2026-10-27 depuis le poste d'audit ; aucune requête HTTP ni UDP envoyée) :

| Hôte | Résultat DNS | Lecture |
|---|---|---|
| `digitalbossmonster.azurewebsites.net` | introuvable | le backend de codes n'existe plus (INFÉRENCE : site Azure supprimé ; S-01 devient théorique pour l'APK d'origine) |
| `insights.xamarin.com`, `insights.xamarin.io` | introuvables | l'hôte réel d'Insights n'apparaît pas en clair dans le code décompilé (`ApiBlob.Endpoint` est fourni à l'exécution) ; ces deux noms sont des suppositions et ne prouvent rien |
| `app-eu.exitgamescloud.com` | `45.67.210.235` (pas de PTR) | le domaine `exitgamescloud.com` est toujours délégué (4 serveurs AWS Route 53) |

**RDAP, consulté le 2026-10-27** (FAIT, deux requêtes en lecture sur des registres publics) :

| Objet | Résultat |
|---|---|
| Domaine `exitgamescloud.com` (RDAP Verisign) | registrar GoDaddy.com, LLC ; **créé le 2011-07-04** ; dernière modification 2026-07-05 ; expire le 2027-07-04 ; verrous client (suppression, renouvellement, transfert, mise à jour) ; titulaire non affiché |
| IP 45.67.210.235 (RDAP RIPE) | bloc 45.67.210.0/24, réseau `GCL-CUSTOMER-NL`, Pays-Bas, « G-Core Labs Customer assignment », enregistré le 2022-05-17 ; contacts administratifs G-Core Labs S.A. |

**INFÉRENCE** : une date de création en 2011 indique que le domaine n'a pas expiré puis été racheté (un nouvel enregistrement aurait une date récente), ce qui écarte le scénario « domaine perdu et racheté par un tiers ». Elle ne dit pas qui contrôle aujourd'hui le serveur qui répond : l'adresse appartient à un *client* d'un hébergeur, pas à un bloc identifié Exit Games |

## 9. Stockage et données

- **Mécanisme** : `WaveServices.Storage` appelle `DataContractSerializer` en lecture/écriture (`Wave/Framework/WaveEngine.Framework.Services/Storage.cs`), et l'adaptateur Android utilise `IsolatedStorageFile.GetUserStoreForApplication()` (`Wave/Adapter/WaveEngine.Adapter.IO/IOManager.cs`). Les données résident dans le magasin isolé associé à l'application ; aucun chiffrement applicatif n'est visible dans cette couche.
- **Données persistées** : réglages, statistiques de victoires, achats (`PurchasedItems`), clés en ligne (`OnlineKeys.APPID`).
- **Pas de SQLite ni de `SharedPreferences`** : aucune occurrence dans `DBMGame/`.
- **Fichiers externes** : aucun usage de stockage externe par le jeu trouvé. Le code Xamarin Insights consulte l'état et l'espace libre du volume externe pour construire les informations appareil (`HardwareDetector.cs:368-374`); cela ne montre pas d'écriture de fichiers. Les assemblies de facturation déclarent aussi `WRITE_EXTERNAL_STORAGE` dans leurs attributs (`play.billing.v3` et `InAppServiceBinding`).
- **Logs** : `LogService` renvoie chaque message à `Insights.Track` (`LogService.cs:59,65`) et chaque erreur à `Insights.Report` (l.54). Les messages de connexion Photon contiennent `appID`, serveur et nom de joueur (`OnlineClient.cs:239`).
- **Sauvegarde/restauration** : `allowBackup`, agent et règles de sauvegarde ne sont pas déclarés. L'attribut absent ne suffit pas à prouver qu'une sauvegarde système est disponible ou restaurée sur cette application legacy ; cela dépend de la plateforme et de sa configuration. Aucun chiffrement applicatif observé.

## 10. Confidentialité et SDK tiers

| SDK | Fonction | Données (INFÉRENCE) | Permissions |
|---|---|---|---|
| Xamarin Insights 1.9 | analytics et crashs | identifiants d'appareil, logs du jeu, exceptions | `INTERNET`, `ACCESS_NETWORK_STATE` |
| Photon (Exit Games) | multijoueur | pseudo aléatoire, événements de jeu | `INTERNET` |
| Google Play Billing v3 | achats | jetons d'achat | `BILLING` |
| Ubertesters (déclaré seulement) | test bêta | — | aucune classe présente |

Pas de publicité, de push, de Play Services ni de Play Games (README §4, confirmé par la liste smali : seuls `com.dbm.project.R`, `mono`, `opentk` et 8 paquets `md5…`).

**Données lues par Xamarin Insights** (FAIT, `decompiled/Xamarin.Insights/.../HardwareDetector.cs`) : identifiant Android `android_id` (`l.42`, repli `noDeviceId`), nom de l'opérateur mobile via `TelephonyManager` (`l.157,385`), espace libre du stockage externe (`l.368-374`), nom de package (`l.392,399`), ainsi que la locale. `Insights.Identify` n'est appelé nulle part dans `DBMGame/` : aucun identifiant utilisateur applicatif n'est associé aux événements, mais l'identifiant d'appareil reste transmis. Cette liste est celle du SDK ; le contenu réel des paquets n'a pas été capturé.

**Conformité à vérifier** : base légale et consentement pour Insights (collecte forcée), politique de confidentialité, droits des mineurs (jeu familial), localisation des données (Photon EU).

**P-01 — Télémétrie sans consentement observable (préoccupation, pas conclusion juridique).** `AndroidActivity.OnCreate` initialise Insights et active `ForceDataTransmission`; `LogService` envoie les avertissements/erreurs à `Insights.Track` et les exceptions à `Insights.Report`. Aucun écran ni garde de consentement n'a été trouvé dans le C# examiné. Le contenu complet des événements, leur destination effective et l'existence d'une information ou d'un consentement hors application ne sont pas établis par cette analyse statique. Pour un portage, différer l'initialisation jusqu'au consentement ou fournir un réglage explicite, et documenter les catégories de données réellement transmises.

## 11. Sécurité défensive

**Anti-debug / root / intégrité** : aucun trouvé dans `DBMGame/` (recherches ciblées négatives, pas exhaustives).

| ID | Sév. | Preuve | Impact | Recommandation | Conf. | Statut |
|---|---|---|---|---|---|---|
| **S-01** | **Élevée** | `decompiled/DBMGame/DBMGameProject.Services.AppPurchase/WebUtils.cs:19` : `ServerCertificateValidationCallback … => true` | Tout certificat est accepté : un MITM peut forger la réponse de `ValidateCode` (`AppPurchaseService.cs:264-299`) et débloquer du contenu payant | Supprimer le callback ; valider la chaîne ; envisager le pinning | Haute | Observé |
| **S-02** | Faible | `WebUtils.cs:19` : `Delegate.Combine` à chaque appel | Le délégué s'accumule à chaque requête (fuite mineure) | Enregistrer une seule fois, ou ne pas l'enregistrer | Haute | Observé |
| **S-03** | Faible | `Game.cs:20` : `XAMARIN_INSIGHTS_KEY = "c3ca05a3…2005a"` | Clé de télémétrie exposée : injection de faux événements | Rotation côté fournisseur (service Insights vraisemblablement arrêté) | Moyenne | Observé ; clé « publique par conception » = hypothèse |
| **S-04** | Moyenne | `OnlineClient.cs:134-135` : `AppId` et serveur en dur ; aucune auth personnalisée | Toute personne ayant l'APK peut se connecter à l'application Photon et rejouer ou forger des événements | Authentification Photon côté serveur ; validation serveur des événements | Moyenne | Observé + Inféré |
| **S-05** | Info | `PurchaseId.cs:5` : clé RSA 2048 publique de Google Play | Publique par nature, pas un secret | Aucune | Haute | Observé |
| **S-06** | Faible | Manifeste l.5-6 : `ubertesters_project_id` + `UbertestersScreen`, classe absente | Surface résiduelle ; crash si l'activité est lancée ; identifiant de projet exposé | Retirer ces déclarations | Moyenne | Observé ; absence de classe = inféré |
| **S-07** | Faible | Manifeste l.15-17 ; aucune référence à `GET_TASKS` ou `SYSTEM_ALERT_WINDOW` dans C# décompilé ou smali. `WRITE_EXTERNAL_STORAGE` est aussi déclaré par les bindings Billing ; Insights lit l'état et l'espace libre du stockage externe (`HardwareDetector.cs:368-374`). | Permissions résiduelles ou dépendantes d'anciens SDK ; aucun accès à une fenêtre superposée ni aux tâches récentes n'a été trouvé. L'usage du stockage externe observé est une lecture de métadonnées, pas une écriture par l'application. | Vérifier les manifestes fusionnés et retirer ce qui n'est pas requis lors d'un éventuel portage | Moyenne | Vérifié statiquement ; justification historique non établie |
| **S-08** | Faible | `apktool.yml` : pas de `targetSdkVersion`, manifeste sans `allowBackup`/`networkSecurityConfig` | Configuration legacy. `allowBackup` absent suit la valeur par défaut de la plateforme ; l'appareil et sa version déterminent l'effet réel. | Déclarer explicitement la politique de sauvegarde et le target SDK sur un nouveau build | Moyenne | Absence observée ; effet déduit |
| **S-09** | Moyenne | `apksigner verify -v --print-certs` : v1=true ; v2/v3/v3.1/v3.2/v4=false | L'APK repose uniquement sur la signature JAR v1 ; il n'a pas les protections des schémas modernes. Une exploitation de type Janus dépend de l'appareil et d'une APK altérée ; elle n'est pas démontrée sur ce fichier. | Pour un nouveau build, signer au minimum en v2 et vérifier le résultat | Haute | Confirmé |
| **S-10** | Info | `CryptoProvider.GetHashString` (SHA-1) est appelé par `LogicCardBase` et `GameBoard` pour produire des empreintes d'état ; `SerialHelper.GetSerialKeyAlphaNumeric` dérive 64 bits d'un `Guid` haché SHA-256. La constante `vicmamoj` est déclarée mais jamais lue. | Aucun usage de SHA-1 à des fins d'authentification ou de signature n'a été trouvé. L'empreinte d'état ne doit pas être considérée comme une preuve cryptographique. Le générateur de code d'activation est côté client et ne constitue pas un secret. | Ne pas utiliser ces empreintes pour une décision de sécurité ; aucune correction nécessaire pour leur rôle observé | Moyenne | Usages tracés dans le C# décompilé |
| **S-11** | Faible | `WebUtils.cs` + `AppPurchaseService.cs:268` : le `code` est concaténé sans encodage dans l'URL | Caractères spéciaux (`/`, `?`) altèrent le chemin ; le code utilisateur transite en clair dans le chemin | `Uri.EscapeDataString`, requête POST | Moyenne | Observé |
| **S-12** | Moyenne | `Newtonsoft.Json` 6.0.8, `Mono.Android` 5.1.3, `OpenTK` 0.9.9.3 | Composants anciens. **HYPOTHÈSE** : un JSON très imbriqué peut faire déborder la pile (CVE-2024-21907, versions < 13.0.1), ici sur des `data.json` locaux et des réponses du backend ; impact réel faible | Mettre à jour si le code est réutilisé ; ne parser que des sources de confiance | Basse | À vérifier |
| **S-13** | Faible | `OnlineClient.cs:135` (`app-eu.exitgamescloud.com:5055`) ; DNS : `45.67.210.235` ; RDAP : domaine créé en 2011, IP dans un bloc client G-Core Labs (NL) | Le client enverrait ses connexions et événements de jeu (pseudo aléatoire, `AppId`, événements) à un serveur dont l'opérateur actuel n'est pas identifié. Le domaine n'a pas changé de mains par rachat après expiration (création 2011), mais le titulaire est masqué et rien ne prouve que ce serveur soit Photon | Ne pas reprendre ce nom d'hôte ; pour un portage, utiliser son propre serveur ; demander confirmation à Exit Games si le comportement historique compte | Moyenne | Observé (DNS, RDAP) ; exploitation = hypothèse |
| **S-14** | Info | `libmonodroid_bundle_app.so` : pile exécutable, pas de RELRO, `.symtab` présent | Durcissement absent sur une bibliothèque qui ne contient que des données et deux symboles d'initialisation | Reconstruire avec un NDK/Xamarin récent | Haute | Observé |
| **S-15** | Faible | `OnlineService.cs:883-888` : `photonEvent[254]`, `[245]`, `hashtable[2]` lus sans validation ; `GameBoardFlowInfo.cs:21,30` : `TypeNameHandling.All` | Un pair malveillant peut déclencher une exception (déni de service local). Le `TypeNameHandling.All` du journal n'est exploitable que si ces objets sont désérialisés depuis une source non fiable : **aucune désérialisation de `GameBoardFlowInfo` ou des types `LogicLogger` n'existe dans `DBMGame/`** (les seuls `DeserializeObject`/`Deserialize<>` portent sur la réponse du backend, les messages Photon, `CardDeckInfo`, `AICardDeckInfo` et `CreditInfo`) ; ces propriétés ne servent donc qu'à sérialiser | Valider les types et les nullités à la réception ; ne pas activer `TypeNameHandling` sur des données externes | Moyenne | Observé (validation) ; `TypeNameHandling` non exploitable ici |
| **S-16** | Faible | `Storage/PurchasedItems.cs:6-47` : simple `Dictionary<string,bool> Purchased`, lu et écrit par `StorageHelper` ; `AppPurchaseService.cs:62-65` (`IsLocalPurchased`) ; stockage isolé en `DataContractSerializer` (§9) | Les déverrouillages sont lus dans un fichier du bac à sable, sans signature ni empreinte (FAIT : `PurchasedItems.cs` n'en contient aucune). **INFÉRENCE** : un appareil rooté ou une sauvegarde modifiée permettrait de s'octroyer des achats sans serveur | Valider côté serveur et signer l'état local si un achat est conservé | Moyenne | Observé (absence de protection) ; exploitation inférée |
| **S-17** | Faible | `libmonodroid.so`, `.rodata` : propriétés `debug.mono.{connect,extra,runtime_args,env,…}` et dossier `%s/.__override__` ; `monodroid_debug_connect`/`accept` à `0xa1c0`/`0xa3b8` (`connect`, `bind`, `listen`, `accept`) | La build de production embarque le transport de débogage Mono, le lancement de `gdbserver`, un pont XS en écoute TCP (`debug.mono.connect=port=<n>`, commandes non authentifiées), `setenv` arbitraire par `debug.mono.env` et le chargement d'assemblies depuis un dossier de remplacement sans vérification d'intégrité, le tout piloté par propriétés système. Ghidra a retrouvé le chemin complet : `debug.mono.gdb` ou un fichier `gdb` déclenche `fork` + `execl` d'un `gdbserver` ; `debug.mono.connect=port=<n>` ouvre un écouteur TCP sur toutes les interfaces avec des commandes non authentifiées (`exit process`, redirection de stdout/stderr, démarrage de l'agent de débogage ; FAIT), sans contrôle « déboguable » ni uid. Le pilotage par propriété exige un accès `adb shell` ou root, et le `gdbserver` doit être présent dans l'application ou le système ; le dossier `.__override__` exige l'écriture dans le répertoire privé de l'application (INFÉRENCE d'après le fonctionnement connu de Xamarin.Android 5, non retracé dans le code). Aucune faille propre au jeu n'est démontrée | Pour un nouveau build, utiliser un runtime Release récent ; vérifier que les options de débogage ne sont pas actives | Moyenne | Chaîne `fork`/`execl` et lectures de propriétés décompilées ; exécution sur appareil non testée |

**Faux positifs possibles** : S-03 et S-05 sont des clés publiques ou semi-publiques par conception ; S-01 n'a d'impact que si l'endpoint est encore actif (le DNS indique qu'il ne l'est plus) ; S-13 peut être un faux positif si Exit Games exploite ce serveur via un hébergeur ; les imports `system`/`execve` de `libmonosgen-2.0.so` sont normaux pour Mono.

## 12. Performance, compatibilité et taille

- **Compatibilité** : mono-ABI 32 bits (C-01 ci-dessous). `minSdk` 11. Écrans petits et normaux exclus par le manifeste (tablettes ≥ 600 dp uniquement).
- **Taille** : 47,7 Mo. Répartition mesurée des assets (`assets/Content/`) : `CardDecks` 29,1 Mo, `Audio` 6,9 Mo (dont `music_dungeon_v3.mp3` 2,7 Mo et `music_main.mp3` 0,7 Mo), `Common` 3,9 Mo, polices/chargement/tutoriel ≈ 0,3 Mo, `EXPANSIONS.wpk` 0,5 Mo. Plus gros fichiers : trois `.wpk` de 4,0 Mo (`ksa001-ksa017`, `bmh056-bmh075`, `bmh076-bmh095`). Les `.so` pèsent ≈ 6,4 Mo, soit environ 13 % de l'APK. Les `.wpk` sont stockés sans compression dans l'archive (`apktool.yml`, `doNotCompress`), donc leur poids réel dépend du format interne des textures (non analysé).
- **Allocations probables (INFÉRENCE)** : Mono SGen avec Newtonsoft et `async/await` dans le thread de jeu ; la boucle Photon tourne à 66 ms (`OnlineClient.cs:147`) sur une tâche `LongRunning`.
- **Pistes** : fournir les ABI `arm64-v8a` (et `x86_64`), compresser les assets, paginer les textures, supprimer les shaders inutilisés (143 génériques pour un jeu 2D de cartes).

| ID | Catégorie | Sév. | Preuve | Description | Impact | Recommandation | Conf. | Statut |
|---|---|---|---|---|---|---|---|---|
| **C-01** | Compatibilité | Moyenne | `lib/armeabi-v7a/*` seul | Aucune ABI 64 bits | Installation impossible sur appareils 64 bits purs (INFÉRENCE) | Recompiler avec Xamarin récent | Haute | Observé |
| **C-02** | Compatibilité | Faible | `AndroidActivity.cs:65` | Gestion de la touche Retour via `NavigatedBack` | Sans effet sur la navigation par gestes récente (HYPOTHÈSE) | Tester sur Android 13+ | Basse | À vérifier |

## 13. Licences et composants tiers

Aucun texte de licence n'est présent dans les `.cs` décompilés (recherche de « Licensed under », « MIT License », « Apache License », « Microsoft Public License », « GNU », « zlib license » : zéro résultat). Les détenteurs de droits ci-dessous viennent des métadonnées des DLL (`VersionInfo`), pas d'un texte de licence.

| Composant | Détenteur déclaré (métadonnées DLL) | Licence | Notice dans l'APK |
|---|---|---|---|
| Xamarin.Android / Mono (`Mono.Android` 5.1.3, BCL) | Xamarin / « Mono development team » (`System.Json`) | Le `NOTICE` pointe vers `xamarin.com/mobile-licensing` ; licence exacte par composant non établie | Notice générale présente |
| Newtonsoft.Json 6.0.8 | James Newton-King | MIT (page officielle du paquet [NuGet](https://www.nuget.org/packages/Newtonsoft.Json/6.0.8)) | Non trouvée dans les fichiers examinés |
| OpenTK 0.9.9.3 / OpenTK-1.0 (1.0.278) | The Open Toolkit Library | Non confirmée pour ces versions ; le dépôt amont actuel indique MIT, ce qui ne suffit pas à établir le texte applicable aux DLL embarquées | Non trouvée |
| Photon3DotNet / PhotonLoadbalancingApi 4.0.0.4 | Exit Games GmbH | Conditions du fournisseur à vérifier ; aucun contrat embarqué | Non trouvée |
| Farseer Physics 3.3 | Farseer Physics (2011) | Non confirmée | Non trouvée |
| Bepu Physics 1.2 | Bepu Entertainment LLC | Non confirmée ; ne pas lui attribuer Apache-2.0 sur la base de BEPU v2 | Non trouvée |
| WaveEngine 1.4.2 (8 DLL) | Wave Corporation (2014) | Conditions de l'éditeur non vérifiées pour cette version | Non trouvée |
| Zlib.Portable 1.9.1.9000 | Dino Chiesa (2006-2011), porté par Robert McLaws | Non confirmée pour le paquet exact | Non trouvée |
| `play.billing.v3`, `InAppServiceBinding` | « Copyright 2013 » sans société ; Microsoft 2013 | Non confirmée | Non trouvée |
| Xamarin.Insights 1.9 | Xamarin Inc. (2014) | Conditions Xamarin à vérifier ; statut du service non vérifié ici | Non trouvée |

`assets/Content/Common/credits.json` crédite PLAIN CONCEPTS (développement) ; il ne liste pas les bibliothèques (lecture partielle, début du fichier seulement). Points juridiques : droits sur les cartes, illustrations et sons, marque Boss Monster, conditions de réutilisation de l'APK comme référence.

## 14. Annexes

**Fichiers clés**

| Chemin | Rôle |
|---|---|
| `apktool-decoded/AndroidManifest.xml`, `apktool.yml` | manifeste, SDK, version |
| `boss-monster-2-2-6/META-INF/DBM.{RSA,SF}`, `MANIFEST.MF` | signature |
| `decompiled/DBMGame/DBMGameProject.Services.AppPurchase/{WebUtils,AppPurchaseService}.cs` | réseau, achats |
| `decompiled/DBMGame/DBMGameProject.Services.Online/OnlineClient.cs` | Photon |
| `decompiled/DBMGame/DBMGame/AndroidActivity.cs` | cycle de vie, Insights |
| `decompiled/DBMGame/DBMGameProject/Game.cs`, `Storage/PurchaseId.cs`, `Storage/StorageHelper.cs` | secrets, stockage |
| `decompiled/evidence/*.json` | preuves REA (graphes, membres) |

**Glossaire** : ACW = Android Callable Wrapper (proxy Java généré par Xamarin) ; WPK = paquet d'assets WaveEngine ; Photon = middleware multijoueur Exit Games ; Janus = faille d'APK v1 (CVE-2017-13156).

### Annexe — Complétude de l'extraction et de la décompilation, module par module (vérifiée le 2026-10-28)

**1. Extraction (FAIT).**
- `libmonodroid_bundle_app.so` contient **27 flux gzip** ; chacun, décompressé, est identique octet pour octet (SHA-256) à une DLL de `apk-original/extracted_assemblies/` : **27 sur 27**, aucune DLL en trop. Les 27 noms `.dll` du bundle correspondent aux 27 fichiers ; il n'y a ni `.config`, ni `.mdb`, ni `.pdb` dans le bundle.
- L'APK contient 123 fichiers : 93 `.wpk`, 8 `.json`, 6 `.png`, 4 `.xml`, 4 `.so`, 2 `.mp3`, `classes.dex`, `resources.arsc`, 3 fichiers de signature, `NOTICE`. Aucune autre assembly, aucun `.jar`.
- `classes.dex` : 196 classes, 1 539 méthodes définies (1 152 avec code) ; `apktool-decoded/smali/` contient **196 fichiers** et **1 539 déclarations `.method`** : correspondance complète. Le fichier `decompiled/smali_coverage_verification.md` affiche « 0 classe » : son comptage est défaillant, il n'est pas la preuve d'un manque.

**2. Assemblies gérées, DLL par DLL (FAIT).** Méthode : (a) recensement des tables de métadonnées de chaque DLL avec `System.Reflection.Metadata` ; (b) nouvelle décompilation de chacune des 27 DLL avec `ilspycmd` 11.1.0.9782 en mode projet (une exécution par DLL, code de retour 0, sortie d'erreur limitée à l'avis de mise à jour de l'outil) ; (c) vérification que chaque type de premier niveau a sa déclaration (genre, nom et arité des paramètres génériques) dans le C# généré ; (d) recherche de marqueurs d'échec ; (e) comparaison avec l'arbre `decompiled/` existant (produit par `ilspycmd` 9.1).

| DLL | Octets | SHA-256 (12 car.) | TypeDef | Types 1er niveau* | Méthodes (avec corps IL) | Fichiers `.cs` | Lignes | Types sans déclaration | Échecs | `goto IL_` (fichiers) | `NotImplementedException` |
|---|---:|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| `DBMGame.dll` | 888 832 | `7bf2ae019338` | 917 | 560 | 5 704 (5 603) | 560 | 51 995 | 0 | 0 | 0 | 21 |
| `InAppServiceBinding.dll` | 7 680 | `f41d24505650` | 3 | 2 | 22 (12) | 3 | 366 | 0 | 0 | 0 | 0 |
| `Mono.Android.dll` | 923 648 | `7742e09e356b` | 561 | 395 | 5 592 (4 911) | 392 | 56 097 | 0 | 0 | 0 | 0 |
| `Newtonsoft.Json.dll` | 401 920 | `50c55e3eb570` | 271 | 200 | 2 865 (2 785) | 201 | 29 371 | 0 | 0 | 0 | 2 |
| `OpenTK-1.0.dll` | 98 816 | `76dfac30701e` | 94 | 81 | 454 (361) | 81 | 5 445 | 0 | 0 | 0 | 2 |
| `OpenTK.dll` | 266 752 | `fbf9314270e4` | 13 | 10 | 2 166 (1 508) | 11 | 18 528 | 0 | 0 | 0 | 0 |
| `Photon3DotNet.dll` | 123 904 | `243c602acdff` | 76 | 52 | 691 (653) | 53 | 9 048 | 0 | 0 | 3 | 4 |
| `PhotonLoadbalancingApi.dll` | 40 960 | `e82a275160e2` | 25 | 24 | 235 (235) | 25 | 2 714 | 0 | 0 | 0 | 0 |
| `System.Core.dll` | 309 760 | `b33512d359c0` | 228 | 143 | 1 988 (1 961) | 142 | 21 469 | 0 | 0 | 0 | 0 |
| `System.Json.dll` | 20 480 | `04988a2b5673` | 8 | 6 | 107 (106) | 7 | 1 122 | 0 | 0 | 0 | 0 |
| `System.Runtime.Serialization.dll` | 135 680 | `2d31fd9b9e38` | 77 | 56 | 684 (664) | 57 | 9 291 | 0 | 0 | 2 | 0 |
| `System.ServiceModel.dll` | 96 768 | `61b763b9cfd1` | 69 | 56 | 450 (416) | 54 | 3 750 | 0 | 0 | 0 | 3 |
| `System.Xml.Linq.dll` | 38 912 | `9e90f62db9ea` | 32 | 21 | 246 (244) | 22 | 2 142 | 0 | 0 | 0 | 0 |
| `System.Xml.dll` | 619 520 | `316f60069606` | 401 | 356 | 3 803 (3 601) | 357 | 52 117 | 0 | 0 | 1 | 6 |
| `System.dll` | 622 080 | `069d9095ca30` | 458 | 364 | 3 694 (3 423) | 365 | 52 335 | 0 | 0 | 4 | 9 |
| `WaveEngineAndroid.Adapter.dll` | 169 472 | `8444abbfc73f` | 137 | 91 | 978 (795) | 92 | 8 701 | 0 | 0 | 0 | 0 |
| `WaveEngineAndroid.Bepu.dll` | 715 264 | `3d8ca4c56dc1` | 481 | 439 | 4 367 (4 024) | 436 | 49 681 | 0 | 0 | 2 | 0 |
| `WaveEngineAndroid.Common.dll` | 254 976 | `28c5a0d53a85` | 189 | 183 | 1 659 (1 396) | 183 | 16 326 | 0 | 0 | 0 | 6 |
| `WaveEngineAndroid.Components.dll` | 234 496 | `658f07568683` | 141 | 123 | 1 349 (1 340) | 124 | 16 727 | 0 | 0 | 0 | 0 |
| `WaveEngineAndroid.Farseer.dll` | 360 960 | `dc221b496cff` | 226 | 199 | 1 755 (1 649) | 200 | 25 976 | 0 | 0 | 2 | 0 |
| `WaveEngineAndroid.Framework.dll` | 403 456 | `24e541c7869d` | 288 | 239 | 2 588 (2 510) | 240 | 24 582 | 0 | 0 | 0 | 1 |
| `WaveEngineAndroid.Materials.dll` | 233 472 | `a7f7f125bf91` | 21 | 14 | 241 (241) | 15 | 1 722 | 0 | 0 | 0 | 0 |
| `WaveEngineAndroid.Physics.dll` | 46 080 | `8def51a19cce` | 21 | 16 | 284 (272) | 17 | 2 352 | 0 | 0 | 0 | 8 |
| `Xamarin.Insights.dll` | 90 112 | `ad8f33316bd4` | 142 | 121 | 664 (566) | 122 | 5 535 | 0 | 0 | 0 | 19 |
| `Zlib.Portable.dll` | 83 968 | `4fe9922be851` | 53 | 31 | 327 (323) | 32 | 6 987 | 0 | 0 | 0 | 11 |
| `mscorlib.dll` | 1 820 160 | `dd1eb451d2e4` | 1342 | 1129 | 10 484 (9 494) | 1 104 | 140 331 | 0 | 0 | 8 | 76 |
| `play.billing.v3.dll` | 27 648 | `238e364596e2` | 20 | 19 | 90 (77) | 20 | 1 078 | 0 | 0 | 0 | 0 |
| **Total (27)** | | | **6 294** | **4 930** | **53 487 (49 170)** | **4 915** | **615 788** | **0** | **0** | **22** | **168** |

\* Types de premier niveau hors types générés par le compilateur (attribut `CompilerGenerated`, noms en `<…>`, `__StaticArrayInitTypeSize`). Les types imbriqués sont inclus dans le fichier de leur type parent. Les types génériques de même nom et d'arité différente (`Func`1` … `Func`17`) partagent un fichier : d'où des fichiers `.cs` moins nombreux que les types (4 915 fichiers pour 4 930 types, `AssemblyInfo.cs` compris).

La colonne « Lignes » compte l'arbre régénéré avec `ilspycmd` 11.1 (51 995 lignes pour `DBMGame`), pas l'arbre conservé dans `decompiled/` (53 842 lignes, `ilspycmd` 9.1).

Résultats : **4 930 types attendus, 4 930 déclarations retrouvées, 0 manquant.** Aucune occurrence de `Could not decompile`, `DecompilerException`, `Error decompiling`. En revanche, 29 fichiers (493 lignes) de l'arbre `decompiled/` portent des avertissements `//IL_… Incompatible stack types: I vs Ref` ou `Expected O, but got I` (mscorlib 20, OpenTK 3, OpenTK-1.0 3, System 2, Mono.Android 1 ; aucun dans `DBMGame`) : le corps de ces méthodes n'est pas fidèle. L'arbre existant et le nouveau contiennent exactement les mêmes 4 915 chemins (0 en plus, 0 en moins) ; 3 478 fichiers sont identiques et 1 437 diffèrent (versions 9.1 et 11.1 de l'outil). Pour `DBMGame`, 256 fichiers sur 560 diffèrent, 165 encore après normalisation des qualificatifs `base.`/`this.` et des espaces ; les différences que j'ai lues sont syntaxiques (lambdas `delegate` / `=>`, champs d'événements, qualificatifs), mais je ne les ai pas toutes revues une à une. L'arbre existant, qui sert de référence au portage, n'a pas été modifié.

Limites de cette vérification : l'existence d'une déclaration et l'absence de marqueur d'échec ne prouvent pas que chaque corps de méthode soit sémantiquement exact. 22 fichiers contiennent des `goto IL_` laissés par le décompilateur (flux de contrôle non structuré) : `mscorlib` (8 fichiers) et, hors `mscorlib`, `Photon3DotNet` (3), `System` (4), `System.Runtime.Serialization` (2), `System.Xml` (1), `WaveEngineAndroid.Bepu` (2), `WaveEngineAndroid.Farseer` (2) ; aucun dans `DBMGame`. Les 168 `throw new NotImplementedException()` sans argument se répartissent entre le jeu (21 ici + 1 avec message, soit les 22 du README) et des stubs du profil mobile de la BCL Mono et des bibliothèques tierces.

**3. Bibliothèques natives, une par une (FAIT).** Méthode : Ghidra 12 en ligne de commande (`analyzeHeadless`, auto-analyse, export du pseudo-code C de chaque fonction), puis recherche du code de `.text` resté hors de toute fonction et création de fonctions sur ce code (deux passes, la seconde avec une limite de 60 passes d'analyse), puis annotation des chaînes des pools de littéraux ARM par un script qui lit l'ELF (base Ghidra `0x10000` = adresse rizin + `0x10000`). Le pseudo-code est dans `apk-original/native_decompiled/<bibliothèque>/decompiled.c` (local, ignoré par git).

| Bibliothèque | Fonctions décompilées | Instructions de `.text` hors fonction (selon Ghidra*) | Échecs de décompilation |
|---|---:|---:|---:|
| `libmonodroid.so` | 285 | 0 | 0 |
| `libmonodroid_bundle_app.so` | 3 | 0 | 0 |
| `libopenal32.so` | 733 | 0 | 0 |
| `libmonosgen-2.0.so` | 5 164 | 0 | 0 |

**`classes.dex` (Java)** : importé dans Ghidra (loader DEX) et décompilé en pseudo-Java/C : 1 152 fonctions pour 1 152 méthodes ayant du bytecode (1 539 méthodes définies, dont 387 abstraites ou natives sans corps), 0 échec ; sortie dans `apk-original/native_decompiled/classes.dex/decompiled.c`. Parallèlement le DEX est entièrement désassemblé en smali : 196 classes sur 196, mêmes méthodes (1 539) et champs (376) classe par classe. Aucun décompilateur Java (jadx) n'est installé, donc pas de Java source reconstitué.

\* Non revérifiable par un tiers : le projet Ghidra n'est pas conservé ; une relecture indépendante avec rizin (`aaa`) trouve 7 (monodroid), 249 (monosgen) et 12 (openal) débuts de fonction sans entrée Ghidra à la même adresse, sans pouvoir dire s'ils sont absorbés dans d'autres fonctions.

**Réserves de qualité du pseudo-code natif (relecture indépendante).** 0 échec de l'outil ne veut pas dire pseudo-code exact : `libmonosgen-2.0.so` compte 3 fonctions tronquées (`halt_baddata`, « Bad instruction » : `FUN_001563f0`, `FUN_00186918`, `mono_monitor_enter_v4`), 86 tables de saut non récupérées (3 examinées : sauts indirects par pointeur, pas des `switch`) et 21 exports qui sont des trampolines d'une instruction `b` absorbés dans la fonction voisine ; `libmonodroid.so` 1 table de saut non récupérée (`_Unwind_DeleteException`). Environ 3 % des fonctions de Mono (173), 1,8 % de monodroid (5) et 1,6 % d'OpenAL (12) portent un marqueur de dégradation (table de saut, `halt_baddata`, `unaff_`, `in_stack_`, propagation de types qui ne converge pas).

Les nombres de fonctions comptent les fonctions créées par la passe de rattrapage (environ 24 700 instructions étaient hors fonction avant). Cette passe a fait apparaître du code que l'analyse automatique n'avait pas vu : un client socket vers un démon d'entropie (`FUN_0016be9c`, chemin EGD de Mono), une fonction avec `fork` + `execv` sans chaîne associée (`FUN_002118f4`, côté Mono) et des lectures de `LC_ALL` / `LANG`  ; ces trois points ne sont pas analysés plus loin ici (voir lacune 1). `libmonodroid_bundle_app.so` ne contient que l'initialisation du bundle (`mono_mkbundle_init`, `my_inflate` en gzip via `inflateInit2_` avec fenêtre `0x1f`, `install_dll_config_files` vide). Deux fonctions de Mono (`FUN_00047348`, 4 060 instructions ; `FUN_0007b1ec`) avaient échoué à la première passe : le décompilateur renvoyait « Response buffer size exceeded », limite de charge utile par défaut. Relancées avec cette limite relevée à 512 Mo, elles ont abouti (27 379 et 6 654 lignes de pseudo-code) ; leurs chaînes de pools de littéraux ne sont pas annotées. Le dossier `apk-original/native_analysis/` n'a pas été produit par cette analyse et n'a pas été relu.


**Lacunes / questions ouvertes**
1. Code machine des `.so` : les quatre bibliothèques sont décompilées en totalité (aucun échec de l'outil, mais voir les réserves de qualité de l'annexe : fonctions tronquées, tables de saut non récupérées). Seul le balayage systématique (chaînes, appels sensibles) et la lecture des fonctions sensibles ont été faits : la relecture intégrale des 5 164 fonctions de `libmonosgen-2.0.so` et des 733 d'OpenAL ne l'a pas été (code tiers standard : Mono et OpenAL Soft). Le second dossier de remplacement d'assemblies de `libmonodroid.so` reste non identifié ; le comportement sur appareil des propriétés `debug.mono.*` n'est pas testé. L'inventaire C# du jeu ne contient pas de P/Invoke propre au jeu ; le moteur déclare des appels `libc` (`memcpy`) et OpenAL.
2. Titulaire du domaine `exitgamescloud.com` (masqué dans le RDAP), opérateur du serveur sur 45.67.210.235 et hôte réel d'Insights ; seuls DNS et RDAP ont été consultés le 2026-10-27, aucune requête applicative.
3. Licences contractuelles exactes des SDK propriétaires (WaveEngine, Photon) et licences/avis des anciennes versions OpenTK, Farseer, BEPU, Zlib ; l'APK ne contient pas de notices complètes repérées.
4. Consentement et obligations de confidentialité : aucun mécanisme de consentement n'a été trouvé dans le C# examiné, mais une analyse de code ne remplace pas les documents juridiques ou une capture des données réellement transmises.
5. Usage des 4 listeners de capteurs (accéléromètre, boussole, gyroscope, mouvement) : le README les dit inutilisés par DBMGame, non retracé ici.
6. Atteignabilité réelle de `ChooseCardToDraw` (BMA023 exclue du deck normal) : nécessiterait un scénario de partie ou une analyse des extensions.
7. Contenu exact des paquets Photon et Insights : exige une capture réseau sur l'APK en cours d'exécution.

**Commandes de vérification** (depuis `apk-original/`)

```bash
apksigner verify -v --print-certs boss-monster-2-2-6-android.apk
aapt2 dump badging boss-monster-2-2-6-android.apk
llvm-readelf -d -s boss-monster-2-2-6/lib/armeabi-v7a/libmonodroid.so
rg -n "GetRunningTasks|SYSTEM_ALERT|ExternalStorage" apktool-decoded/smali
rizin -q -c "aa; pdf @ sym.monodroid_debug_connect" boss-monster-2-2-6/lib/armeabi-v7a/libmonodroid.so
"$GHIDRA_INSTALL_DIR/support/analyzeHeadless" <projet> mono -import boss-monster-2-2-6/lib/armeabi-v7a/libmonodroid.so -postScript ExportAll.java <sortie.c>
python -c "from elftools.elf.elffile import ELFFile as E; e=E(open('boss-monster-2-2-6/lib/armeabi-v7a/libmonodroid_bundle_app.so','rb')); print([(s['p_type'],s['p_flags']) for s in e.iter_segments()])"
nslookup app-eu.exitgamescloud.com
curl -s https://rdap.verisign.com/com/v1/domain/EXITGAMESCLOUD.COM
curl -s https://rdap.db.ripe.net/ip/45.67.210.235
```

À lancer depuis un dossier neutre (pas depuis `apk-original/`) pour les scripts Python.
