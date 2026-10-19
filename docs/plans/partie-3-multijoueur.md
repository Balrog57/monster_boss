# Partie 3 — Lobby en ligne (liste publique de salons)

> Prérequis : lire [`docs/plans/README.md`](README.md) (rôles, sources de vérité, commandes, règles, conventions `GODOT/`, `ASSETS/`, `CS/`) et [`docs/HANDOFF.md`](../HANDOFF.md) (§5 « Multiplayer », §7 points 8-9, §9). Dans ce brief : `GODOT/` = `src/frontend/godot/`. **À démarrer en dernier** (README §7) ; le lot « 6 sièges » dépend du **lot 2.4** de la partie 2.

## Rôles (rappel ; détail dans le README §3)

L'IA qui reçoit ce brief est **orchestrateur seulement** : elle décide, dispatche, vérifie (tests, git, vérifications manuelles), commite, et **n'édite aucun fichier du dépôt**. **Sonnet** (`model: sonnet`) écrit tout le code et toutes les docs (périmètre de fichiers étroit, pas de git, `python tools/run_godot_tests.py` vert deux fois, question finale « qu'est-ce qui diffère encore ? »). **Haiku** (`model: haiku`) explore, indexe, compare (≤ 30 images par agent) et rend des tableaux ; il ne modifie rien.

## Objectif

Remplacer le WORLDWIDE « Unable to join public rooms » par un **vrai lobby : liste publique de salons, sans comptes** (décision de l'utilisateur, 2026-10-18), durcir le serveur, et redéployer. Un onglet de navigateur = un joueur. Les écrans en ligne reprennent le style APK (polices, boutons, panneau de salle d'attente).

## État de départ (vérifié le 2026-10-18)

- Serveur headless `GODOT/server/` : `Server.gd` (options `--port --turn-timeout=60 --adventure-timeout=10 --bot-delay=350 --ttl=3600 --max-rooms=200`), `GameRoom.gd` (sièges, jetons, bots, minuteur de tour), `ViewFilter.gd` (filtre d'informations cachées par siège), `PROTOCOL.md` (messages `create`, `join`, `resume`, `start`, `move`, `sync`, `leave`, `ping`…). Codes de salon à 4 lettres sans I/O, jetons de reconnexion, bots, timeout de tour, `GameRoom` clampé à 2-4 joueurs (`GameRoom.gd` ligne 32 ; `Server.gd` ligne 240).
- Client : `GODOT/scripts/OnlineClient.gd` (URL = origine de la page → `wss://<hôte>/ws` ; session persistée dans `user://online_session.cfg`, lignes ~20 et ~346-369), `OnlineGameManager.gd`, `NetCodec.gd`, `OnlineMenus.gd` (PLAY ONLINE / WITH FRIENDS / PASS AND PLAY ; WORLDWIDE = boîte d'erreur APK, `OnlineMenus.gd` ligne ~233).
- Déployé : nginx `/ws` → `server:8091` (`deploy/nginx.conf`, port non publié, `deploy/docker-compose.yml`), image `deploy/Dockerfile.server` (binaire Godot 4.7.2 téléchargé **sans empreinte vérifiée**, ligne ~13). CI `.github/workflows/ci.yml` : job `export` contient déjà une vérification `/ws` → `101 Switching Protocols`. Parties en mémoire seulement.
- `security/SECURITY.md` : tous les contrôles listés sont décochés (limite de débit, en-tête `Origin`, épinglage d'images par digest…).
- Hypothèse du plan à **confirmer par Haiku (lot 3.0)** : chaque onglet est déjà une session distincte (jeton de reconnexion par client). Point d'attention : `user://` d'un export web vit dans IndexedDB, **partagé par tous les onglets d'une même origine** ; `OnlineClient.gd` écrit un seul jeton dans `user://online_session.cfg`. `docs/HANDOFF.md` §5 dit avoir testé deux onglets à la main (create/join, reprise après rechargement) : vérifier ce qui se passe quand deux onglets d'un même navigateur reprennent leur session.

---

## Lot 3.0 — État des lieux

**Objectif** : cartographier l'existant et ce qui manque pour une liste publique.

**Sources** : `GODOT/server/PROTOCOL.md`, `Server.gd`, `GameRoom.gd`, `ViewFilter.gd` ; `GODOT/scripts/OnlineClient.gd`, `OnlineMenus.gd`, `OnlineGameManager.gd` ; `GODOT/tests/online_test.gd` (scène `OnlineTest.tscn`).

**Qui fait quoi**
- **Haiku** : produire (a) la liste des messages existants (client→serveur, serveur→client), (b) le cycle de vie d'un salon (création, attente, démarrage, partie, fin, TTL `--ttl`/`finished_ttl_s`, `--max-rooms`), (c) ce qui manque pour une liste publique : visibilité, nom de salon, nombre de sièges libres, état « en attente / en cours ».
- **Haiku** : confirmer l'isolation par onglet : où le jeton est stocké (voir point d'attention ci-dessus), s'il est partagé entre onglets d'une même origine, et ce que fait le serveur si deux connexions reprennent le même siège.
- **Orchestrateur** : transmet à Sonnet pour 3.1-3.3 ; décide si le stockage du jeton doit passer à un stockage par onglet.

**Fichiers cibles** : aucun (lecture seule).

**Critère d'acceptation** : liste des messages, cycle de vie du salon, liste des manques et verdict d'isolation par onglet (avec la preuve : ligne de code ou test) rendus par écrit.

---

## Lot 3.1 — Protocole et serveur

**Objectif** : exposer des salons publics et durcir le serveur.

**Sources** : lot 3.0 ; `security/SECURITY.md` ; `deploy/nginx.conf` ; `deploy/DEPLOYMENT.md` §8.

**Qui fait quoi — Sonnet** (périmètre : `GODOT/server/`, `GODOT/tests/online_test.gd`, `deploy/nginx.conf` si la limite se fait côté nginx, `security/SECURITY.md`)
- Nouveaux messages dans `PROTOCOL.md` : `listRooms` → `rooms` (code, nom d'hôte, sièges libres/total, packs actifs, état), drapeau `public` à la création, `roomsChanged` poussé aux clients du lobby. Nettoyage des salons publics vides après N minutes.
- **Contrôles de sécurité** (`security/SECURITY.md`) : vérification `Origin` sur `/ws` (nginx ou serveur), limite de connexions et de messages par IP, taille maximale des messages, validation des champs (`name`, `avatar`, nombre de sièges). **Nombre de sièges 2-6** : actuellement clampé à 2-4 dans `GameRoom.gd` (ligne 32) et `Server.gd` (ligne 240) ; le passage à 6 n'a de sens qu'avec le **lot 2.4** (6 sièges avec CRL seulement ; le serveur doit refuser 5-6 sans CRL).
- `GODOT/tests/online_test.gd` : scénario lobby (créer une salle publique, la lister depuis un second client, la rejoindre, vérifier sa disparition quand elle est complète).

**Fichiers cibles** : `GODOT/server/Server.gd`, `GameRoom.gd`, `ViewFilter.gd` (si de nouvelles clés de `G`), `PROTOCOL.md`, `GODOT/tests/online_test.gd`, `deploy/nginx.conf`, `security/SECURITY.md`.

**Critère d'acceptation** : `online_test` couvre le scénario lobby et passe ; `python tools/run_godot_tests.py` 14/14 (deux fois) ; chaque contrôle de sécurité implémenté est coché dans `security/SECURITY.md` **avec la preuve** (test ou commande) ; `PROTOCOL.md` documente tous les nouveaux messages. La parité APK n'est pas concernée (`server/` n'est pas un fichier moteur), sauf si `Match.gd` est touché pour les sièges (alors : 3 commandes, README §5).

---

## Lot 3.2 — Écran lobby

**Objectif** : WORLDWIDE affiche une vraie liste de salons.

**Sources** : lot 3.1 ; captures APK du lobby/salle d'attente si le lot 1.3 les a obtenues (`docs/reference/apk_orig/INDEX.md`, local) ; matrice d'animations du lot 1.3 (durées des fondus de menu) ; `GODOT/scripts/OnlineMenus.gd`, `UiKit.gd`, `docs/HANDOFF.md` §7.8.

**Qui fait quoi — Sonnet** (périmètre : `GODOT/scripts/OnlineMenus.gd`, `UiKit.gd`, `OnlineClient.gd`, `Main.gd` si le menu change, `GODOT/tests/ui_smoke.gd`, `capture_screens.gd`)
- WORLDWIDE n'affiche plus la boîte d'erreur : **liste défilante de salons** (style panneau salle d'attente APK, polices et boutons APK), **rafraîchissement automatique**, bouton **JOIN**, bouton **CREATE PUBLIC GAME** (nom, sièges 2-6 selon packs, packs), retour.
- **Fondus entre écrans en ligne** (`docs/HANDOFF.md` §7.8) avec les durées des menus APK (matrice du lot 1.3).
- **Pass-and-play** : limiter à 2 joueurs pour coller à l'APK, ou garder 2-4/6 derrière l'option wiki. **Décision à faire confirmer par l'utilisateur au début du lot** (l'orchestrateur la lui demande avant de dispatcher Sonnet).
- Textes d'UI en anglais.

**Fichiers cibles** : `GODOT/scripts/OnlineMenus.gd`, `UiKit.gd`, `OnlineClient.gd`, `Main.gd`, `GODOT/tests/ui_smoke.gd`, `capture_screens.gd`.

**Critère d'acceptation** : la liste apparaît, se rafraîchit, un clic JOIN rejoint une salle publique d'un autre client (test `online_test`/`ui_smoke`) ; plus aucune boîte « Unable to join public rooms » ; décision pass-and-play enregistrée dans `docs/HANDOFF.md` ; captures du lobby dans `docs/reference/godot_screens/` (local) ; `python tools/run_godot_tests.py` 14/14.

---

## Lot 3.3 — Sessions par navigateur et reprise

**Objectif** : un onglet = un siège, de façon prouvée.

**Qui fait quoi**
- **Sonnet** : garantir (correctifs éventuels dans `OnlineClient.gd`, `GODOT/server/`) : un onglet = un siège ; rechargement de page = reprise du même siège (déjà en place, à retester) ; fermeture = l'IA prend le siège après timeout (déjà en place) ; **deux onglets du même navigateur = deux sièges distincts** (à corriger si le jeton partagé de `user://online_session.cfg` les confond).
- **Orchestrateur / utilisateur** : test manuel à deux navigateurs (ou deux profils) contre le serveur local (`deploy/docker-compose.yml`, port 8090), puis contre le homelab, avec accord de l'utilisateur. L'outil navigateur ne pilote pas les drags Godot : l'utilisateur confirme les parties complètes à la souris.

**Fichiers cibles** : `GODOT/scripts/OnlineClient.gd`, `OnlineGameManager.gd`, `GODOT/server/GameRoom.gd`, `GODOT/tests/online_test.gd`.

**Critère d'acceptation** : scénarios « deux onglets → deux sièges », « rechargement → même siège », « fermeture → IA après timeout » couverts par un test ou une procédure manuelle consignée dans `docs/HANDOFF.md` ; résultats du test à deux navigateurs notés.

---

## Lot 3.4 — Déploiement et CI

**Objectif** : image serveur reproductible, CI qui vérifie le lobby, vérifications propriétaire.

**Qui fait quoi — Sonnet** (périmètre : `deploy/Dockerfile.server`, `.github/workflows/ci.yml`, `deploy/DEPLOYMENT.md`, `security/SECURITY.md`)
- `deploy/Dockerfile.server` : **épingler le binaire Godot par SHA-256** (le `curl` de la ligne ~13 n'est pas vérifié).
- `.github/workflows/ci.yml` job `export` : ajouter un `curl` du `listRooms` (ou une connexion WebSocket qui attend `rooms`), en plus de la vérification `101` existante.
- Optionnel : épingler les images Docker par digest (case de `security/SECURITY.md`).

**Vérifications propriétaire** (à demander à l'utilisateur, `deploy/DEPLOYMENT.md` §7-8) : Cloudflare **WebSockets activé**, **Rocket Loader désactivé**, `/ws` → `101`, aucun service worker périmé.

**Critère d'acceptation** : CI verte avec le nouveau contrôle ; empreinte SHA-256 vérifiée au build ; vérifications propriétaire confirmées par l'utilisateur et consignées.

---

## Lot 3.5 — Clôture de la partie 3

**Qui fait quoi**
- **Sonnet** : `docs/HANDOFF.md` §5 et §7 (points 8-9 : mettre à jour la liste) et `security/SECURITY.md` cochés avec preuve.
- **Orchestrateur** : `online_test` et `python tools/run_godot_tests.py` verts, `code-review` du diff complet, merge dans `main`, **déploiement après accord de l'utilisateur** (`deploy/DEPLOYMENT.md` §3), `git status` propre.

**Critère d'acceptation** : critères du README §6 « État final » ; lobby fonctionnel sur le homelab (deux navigateurs, une salle publique créée, listée, rejointe) ; `security/SECURITY.md` coché avec preuve ; une seule branche `main`, aucune PR.
