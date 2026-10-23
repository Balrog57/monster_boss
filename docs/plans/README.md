# Plans de délégation — Boss Monster (APK 2.2.6 → Godot web)

Rédigé le 2026-10-18. Ces briefs s'adressent à une IA qui clone le dépôt et doit mener l'une des trois parties du chantier. **Lire ce README en entier, puis le brief de la partie visée** : rien d'autre n'est nécessaire pour démarrer.

| Fichier | Contenu |
|---|---|
| `docs/plans/README.md` | ce fichier : rôles, sources de vérité, commandes, règles, critères de passage |
| `docs/plans/partie-1-clone-apk.md` | lots 1.0 → 1.6 : clone exact de l'APK |
| `docs/plans/partie-2-extensions.md` | lots 2.0 → 2.5 : cartes wiki des extensions, 5-6 joueurs |
| `docs/plans/partie-3-multijoueur.md` | lots 3.0 → 3.5 : lobby en ligne à liste publique de salons |

**État du dépôt (référence unique)** : [`docs/HANDOFF.md`](../HANDOFF.md) (§5 état vérifié, §7 écarts connus avec l'APK, §4 comment lancer/tester, §10 pièges). Les briefs s'appuient dessus ; ne pas les croire contre lui sans vérifier, et le mettre à jour en fin de partie.

## 1. Contexte en dix lignes

- Jeu : clone de *Boss Monster: Master of the Dungeon* (APK Android 2.2.6, paquet `com.dbm.project`, WaveEngine/Xamarin, pas Unity). Produit final : export web Godot 4.7 (nginx en Docker) + serveur WebSocket Godot headless, sur le homelab ZimaOS de l'utilisateur.
- `apk-original/` : APK et décompilation (27/27 DLL, ILSpy 9.1, 4915 `.cs`), **local, gitignoré** (seul `apk-original/README.md` est suivi). `apk-original/decompiled/INDEX.md` en est l'index.
- Un **oracle .NET** (`tools/apk-oracle/`) fait tourner le vrai `DBMGame.dll` ; le harnais `tools/parity/apk.py` compare ses traces au moteur Godot : **c'est la vraie métrique de justesse** (6/6, 12/12, 6/6 aujourd'hui).
- Packs wiki déjà portés : The Next Level (115 cartes), Minibosses/RMB (121), Crash Landing/CRL (33). Boutique remplacée par un écran RULES. Serveur multijoueur déployé (salons par code) ; lobby public WORLDWIDE et durcissement serveur faits (partie 3, commités mais pas encore redéployés : voir `docs/HANDOFF.md` §5 et §9).
- Les écarts connus sont dispersés (`docs/HANDOFF.md` §7, `tools/parity/README.md` « Limites assumees », `docs/RAPPORT_REGLES.md` en partie périmé) et plusieurs trous n'ont jamais été mesurés (IA, animations, audio, `NotImplementedException` du C#, décisions ignorées des traces, graines 10-40). La partie 1 les ferme.

## 2. Décisions de l'utilisateur (2026-10-18)

1. **Partie 2 : 5-6 joueurs** via Crash Landing (règle physique : 5-6 joueurs seulement avec CRL). Le jeu reste 2-4 joueurs sans CRL, parité intacte.
2. **Partie 3 : lobby = liste publique de salons**, sans comptes.
3. **Briefs dans `docs/plans/`**, commités sur `main`.
4. **Hypothèse retenue : en cas de conflit entre le livret de règles et l'APK, l'APK gagne dans la partie 1 (c'est un clone)**. Le livret (`docs/rules/rules.md` + PDF) ne gouverne que les **cartes wiki** (TNL, RMB, CRL), que l'APK ne contient pas.
5. Les joueurs 3-4 restent gratuits (l'APK les verrouille derrière « FULL GAME NEEDED » ; décision antérieure de l'utilisateur).

Ordre de travail voulu par l'utilisateur : 1) clone exact de l'APK (règles **et** menus/UI/UX), 2) extensions wiki, 3) boutique supprimée (RULES à la place, déjà fait), 4) multijoueur en dernier.

## 3. Rôles (obligatoire dans chaque brief)

- **Orchestrateur = l'IA qui reçoit le brief.** Elle **décide, dispatche, vérifie, commite**. Elle **n'édite aucun fichier du dépôt elle-même** (pas même une ligne de doc). Elle lance elle-même les commandes de vérification (tests, parité, git).
- **Sonnet** (`model: sonnet`) **écrit tout le code et toutes les docs**, même une ligne. Chaque brief Sonnet contient :
  - un périmètre de fichiers **étroit** (liste explicite des fichiers qu'il peut toucher) ;
  - l'interdiction de lancer `git` ;
  - l'exigence « `python tools/run_godot_tests.py` vert **deux fois** » ;
  - la question finale obligatoire : « **qu'est-ce qui diffère encore ?** ».
- **Haiku** (`model: haiku`) **explore, indexe, compare** : lecture du C# décompilé, inventaires, matrices, comparaison d'images. **≤ 30 images par agent** (au-delà ils plafonnent) : découper le travail en plusieurs agents. Haiku ne modifie rien dans le dépôt ; il rend un tableau/une liste en texte que l'orchestrateur transmet à Sonnet.
- Les agents travaillent sur des périmètres de fichiers disjoints ; jamais deux Godot en parallèle (voir §5).

Les trois briefs de parties rappellent ces rôles en une phrase et renvoient ici.

## 4. Sources de vérité, par ordre

1. `apk-original/decompiled/DBMGame/` (C#) et l'**oracle** (`tools/apk-oracle/`).
2. Captures de l'APK `docs/reference/apk_orig/` (115 frames fiables + `INDEX.md`) — **local, gitignoré** (`docs/reference/` entier).
3. `docs/rules/rules.md` + PDF (`docs/rules/*.pdf`).
4. Texte des cartes wiki (`src/frontend/godot/data/cards.json`).

L'ancien JavaScript n'existe plus (certains commentaires et rapports le citent encore : périmés). Si 1 et 3 se contredisent : **1 gagne en partie 1** ; 3 ne gouverne que les cartes wiki.

## 5. Conventions de chemins et commandes

Chemins : sauf mention contraire, relatifs à la racine du dépôt. Raccourcis employés dans les briefs :

- `GODOT/` = `src/frontend/godot/` (`scripts/`, `tests/`, `server/`, `data/cards.json`, `scenes/`).
- `ASSETS/` = `src/frontend/assets/` (`audio/music`, `audio/sfx`, `fonts/`, `ui/`, `rules/<livre>/pNN.webp`, `data/expansions/*.json`, `apk_cards/`, `cards/`).
- `CS/` = `apk-original/decompiled/DBMGame/` (C# décompilé ; un dossier par espace de noms, ex. `CS/DBMGameModel.Logic/GameBoard.cs`, `CS/DBMGameProject.AI.Statistics/DiscardCalculator.cs`, `CS/DBMGameProject.Scenes.GamePlay/GamePlayBaseScene.cs`). Les fichiers sont à retrouver par `find`/`Glob` si un nom change.
- `apk-original/boss-monster-2-2-6/assets/Content/` = contenu du jeu extrait (paquets `CardDecks/*`, `Audio`, `Fonts`…).

Commandes (Windows ; Godot = `C:/Tools/Godot/Godot_v4.7.2-stable_win64_console.exe` ou la variable `$GODOT`, résolu par `tools/godot_exe.py`) :

- **Tests** : `python tools/run_godot_tests.py` → **14 suites, doit être 14/14** (goldens, coverage, soak, soak decks APK, soak TNL, soak Minibosses, soak THK / IOD / Player's Choice wiki, soak CRL 5-6 joueurs (x2), soak tous packs, online, ui smoke). Toute ligne `SCRIPT ERROR` fait échouer une suite.
- **Parité APK**, **toujours en séquence, jamais deux Godot en parallèle**, un `APK_PARITY_OUT` distinct par run :
  1. `python tools/parity/apk.py` → 6/6
  2. `python tools/parity/apk.py --seeds 4 5 6 7 --players 2 3 4` → 12/12
  3. `python tools/parity/apk.py --decks BaseDeck,PlayerChoice,HiddenHeros,ToolsHeroKind` → 6/6

  Exemple : `APK_PARITY_OUT=tools/parity/out/run2 python tools/parity/apk.py ...` (sous PowerShell : `$env:APK_PARITY_OUT=...`). Chaque run efface son dossier de sortie. La parité n'est faisable que sur la machine qui a `apk-original/` et le SDK .NET (CI : impossible).
- **Diagnostic d'une trace** : `ApkParity.tscn -- --traces=<dossier> --only=sN-pM --dbg=<a>-<b>` (options de `GODOT/tests/apk_parity.gd`, voir `tools/parity/README.md` ligne ~140). Ces options **ne sont pas** des options de `apk.py`.
- **Capture Godot** : `GODOT/tests/CaptureScreens.tscn`, **fenêtré** (le headless ne capture pas) : `godot --path src/frontend --resolution 1920x1080 res://godot/tests/CaptureScreens.tscn [-- --out=<dossier>] [--only=online]` ; sortie dans `docs/reference/godot_screens/` (gitignoré). Voir l'en-tête de `GODOT/tests/capture_screens.gd`.
- **Capture APK** : BlueStacks, instance `Nougat32`. `"C:\Program Files\BlueStacks_nxt\HD-Player.exe" --instance Nougat32`, attendre ~75 s, puis **uniquement** `"C:\Program Files\BlueStacks_nxt\HD-Adb.exe" -s emulator-5554 ...` (**l'adb du SDK Android tue le serveur adb**). Écran 1920×1080. Scripts : `tools/capture_apk_full_turn.py` (parcours d'un tour complet), `tools/play_apk_robust.py`. Frame en plein drag : `input swipe x1 y1 x2 y2 3000` puis un second `screencap`.
- **Export web manuel** et astuces du volet navigateur : `docs/HANDOFF.md` §4 (le canvas Godot veut un `hover` avant chaque `left_click` ; rafraîchir un `index.pck` périmé ; les événements pointeur JS synthétiques ne pilotent pas Godot ; `left_click_drag` est trop grossier pour les drags Godot ; le volet navigateur étrangle les onglets cachés, donc les timings y sont faux).
- Autres outils : `GODOT/tests/AiCensus.tscn`, `tools/sync_implemented.py`, `tools/verify_assets.py`, `tools/merge_expansions.py`, `tools/fetch_wiki_cards.py`, `tools/fetch_expansion_packs.py`, `tools/fetch_expansion_art.py`, `tools/extract_apk_226.py`, `tools/render_rules_pages.py`.

## 6. Règles de travail

- **Fichiers moteur** : `Match.gd`, `BossEngine.gd`, `RoomAbilities.gd`, `TnlAbilities.gd`, `RmbAbilities.gd`, `TnlSpells.gd`, `RmbSpells.gd`, `ThkAbilities.gd`, `IodAbilities.gd`, `PcwAbilities.gd`, `SpellEffects.gd`, `SpellTargeting.gd`, `AI.gd`, `AiWiki.gd`, `GameManager.gd`, `Minibosses.gd` (tous sous `GODOT/scripts/`). Après **tout** changement d'un fichier moteur : les **3 commandes de parité** (§5). Le travail d'UI ne touche pas ces fichiers, sauf bogue moteur prouvé.
- Les cartes wiki ne doivent **jamais** faire bouger la parité (conditionner sur le pack actif). Le harnais de parité n'appelle jamais `AI.gd`.
- **Commit à chaque point vert**, avec le trailer `Co-Authored-By: Claude <modèle> <noreply@anthropic.com>` (le modèle qui a écrit le code, ex. `Claude Sonnet 5.5`). `.uid` suivis par git ; avertissements LF/CRLF sans conséquence.
- **Langue** : textes d'UI en anglais (comme l'original) ; commentaires dans la langue du fichier (français ou anglais) ; briefs et docs de ce dossier en français.
- **Confirmer avec l'utilisateur avant tout acte irréversible ou visible de l'extérieur** : déploiement sur le homelab, suppression de branche, force push, arrêt de serveur. Aucun secret dans le dépôt ; l'accès ZimaOS passe par la config ssh de l'utilisateur (alias `homelab`, `homelab-ts`) ; ne jamais afficher de clé.
- Un lancement concurrent de Godot headless peut corrompre le cache de classes globales (erreurs de parse transitoires) : relancer seul ; `godot --headless --import` rafraîchit le cache.
- Conseils éprouvés pour les sous-agents : périmètre de fichiers étroit, « ne lance pas git », « `run_godot_tests.py` vert deux fois », « qu'est-ce qui diffère encore ? », Haiku pour l'indexation d'images (limite ~30 images).
- **État final de chaque partie** : une seule branche `main`, aucune PR ouverte, aucun worktree/stash en trop, revue `code-review` sur le diff complet, tests verts, `git status` propre, `docs/HANDOFF.md` §5 et §7 mis à jour. Demander avant de supprimer une branche.

## 7. Ordre et critères de passage

1. **Partie 1 est close quand** : tests 14/14 ; parité 6/6 + 12/12 + 6/6 ; graines 10-40 classées (chaque échec = bogue de l'IA oracle documenté, ou corrigé) ; accord IA ≥ seuil fixé au **lot 1.2** ; matrices animations/audio à 100 % « conforme ou écart justifié » ; captures comparées sans écart visible non justifié.
2. **Partie 2 ensuite, partie 3 en dernier.** Les trois briefs sont indépendants dans le texte, mais le lot 3.x « 6 sièges » dépend du **lot 2.4**.
3. Une partie ne démarre pas tant que la précédente n'a pas ses critères atteints, sauf accord explicite de l'utilisateur.

## 8. Modèle de brief à donner à un agent Sonnet

```
Tu es un agent Sonnet. Contexte : lis docs/plans/README.md (§5-§6) et la section du lot <X.Y> de docs/plans/partie-<n>-....md.
Périmètre STRICT — tu peux modifier uniquement : <liste de fichiers>. N'exécute aucune commande git.
Tâche : <objectif et sources du lot, copiés du brief>.
Vérification : `python tools/run_godot_tests.py` doit être 14/14, deux fois de suite <+ les 3 commandes de parité si tu touches un fichier moteur, une à la fois>.
Réponse finale : fichiers modifiés, résultats des commandes, puis « Qu'est-ce qui diffère encore ? ».
```

Modèle pour Haiku : même cadre, mais « lecture seule : ne modifie aucun fichier », livrable = tableau de verdicts (identique / différent / absent / non atteignable), ≤ 30 images.
