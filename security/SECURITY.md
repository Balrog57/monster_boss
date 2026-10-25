# Security policy - Boss Monster

## Signalement

Ne pas ouvrir d'issue publique pour une faille. Contacter l'auteur du dépôt
(`Balrog57/monster_boss`) en privé avec : description, étapes de
reproduction, impact estimé. Délai de réponse visé : 7 jours.

## Surface actuelle

Deux conteneurs (`deploy/docker-compose.yml`), pas de base de données :

- **`boss-monster-web`** : nginx servant l'export web Godot statique (aucun
  code serveur applicatif). Seul le port 8090 est publié.
- **`boss-monster-server`** : serveur multijoueur Godot headless
  (`src/frontend/godot/server/`), WebSocket sur le port 8091 du réseau compose,
  **non publié** : seul nginx l'atteint via `/ws` (en-têtes `Upgrade`).

## Posture

- **Secrets** : aucun secret n'est commité (`.gitignore` : `.env`, `.env.*`).
  Le déploiement actuel n'a besoin d'aucune variable d'environnement
  (voir `security/.env.example`). Ne jamais commiter de clé SSH ni de jeton Cloudflare.
- **Autorité côté serveur** : seul `Match.gd` (dans le serveur) applique les
  coups ; un coup doit être exactement l'un des `legal_moves` du siège, sinon
  `error: illegal` (`src/frontend/godot/server/PROTOCOL.md`). Le client n'est
  jamais une source de confiance.
- **Informations cachées** : `ViewFilter.gd` filtre l'état envoyé à chaque
  siège en liste blanche (mains et pioches adverses, salles face cachée, choix
  d'autrui, journal privé) ; toute clé inconnue de `G` est retirée, et la suite
  `online` échoue si une nouvelle clé n'est pas classée.
- **Sièges** : un siège se reprend avec le `token` secret reçu à la
  création/jonction ; les codes de salle (4 lettres) ne donnent que le droit
  de rejoindre un siège libre ; anti-force-brute (331 776 codes) : 5 échecs `join`/`resume` sur UNE connexion la coupent (1008) et le reste de la rafale n'est pas traité (`Server.gd`). Il n'y a plus de compteur global à 5/s (un seul client pouvait faire répondre `busy` à tous les joueurs) : seule reste une soupape globale à 100 échecs/s. Le débit de connexions neuves par IP est borné par nginx (`limit_req`). Les salons **privés** ne sont jamais listés (`listRooms` ne renvoie que les salles `public` ouvertes avec un siège libre, sans jeton ni détail de siège) : leur code reste l'unique secret.
- **Compteurs WINS/DEFEATS** : déclarés par le client et affichés dans la salle
  d'attente ; ils sont **cosmétiques**, non vérifiés, et ne doivent servir à aucune décision.
- **Salles abandonnées** : siège non-hôte absent plus de 30 s en salle d'attente libéré ; salle publique ouverte sans humain connecté depuis 120 s fermée ; plafond de salles **par source** non implémenté (Godot ne voit que l'adresse de nginx), borné par `limit_req` nginx + `--max-rooms` (`PROTOCOL.md`).
- **Pas de persistance** : les parties vivent en mémoire (TTL après le dernier humain,
  `--max-rooms`, `--ttl`) ; aucune donnée personnelle stockée côté serveur.
- **Chaîne de build** : images `barichello/godot-ci:4.7.2`, `nginx:alpine` et
  `debian:bookworm-slim` + binaire Godot 4.7.2 (releases GitHub, vérifié par SHA-256 ; les trois images sont épinglées par digest : `debian` dans `Dockerfile.server`, `nginx:alpine` et `barichello/godot-ci:4.7.2` dans `Dockerfile`). L'APK
  d'origine et sa décompilation (`apk-original/`) sont exclus du contexte Docker (`.dockerignore`).

## À durcir avant toute exposition publique large

Coché = implémenté **et** prouvé (test ou commande indiquée). Les contrôles nginx ont été exécutés le 2026-10-25 sur la stack du homelab (commit `c9471a5`) et en CI (run 40213471823) ; restent décochées les vérifications du propriétaire (Cloudflare) et TLS.

- [x] Limite de débit **par connexion** WebSocket : 60 messages/s, au-delà fermeture 1008 (`Server.gd`, `MAX_MSGS_PER_SEC`). Preuve : `python tools/run_godot_tests.py` suite `online`, scénario « limites » (100 messages en une seconde → fermeture 1008, au plus 60 réponses).
- [x] Anti-force-brute **par connexion** : 5 échecs `join`/`resume` coupent la connexion, une rafale de 30 essais ne reçoit que 5 réponses, un joueur innocent n'est pas bloqué par les échecs d'un autre, soupape globale à 100/s. Preuve : suite `online`, scénario « bruteforce ».
- [x] Taille maximale des messages : trame texte de 16 Kio au plus, sinon fermeture 1009 ; un message de 300 Kio dépasse le tampon d'entrée (64 Kio) et est coupé par Godot. Preuve : suite `online`, scénario « limites ».
- [x] Limite par **IP** (connexions et requêtes) : `deploy/nginx.conf` (`limit_req` 5/s + rafale 20 et `limit_conn` 20 sur `/ws`, 30 requêtes/s sur le site avec rafale 100, 429), IP réelle lue dans `CF-Connecting-IP` depuis les adresses privées. Preuve (homelab 192.168.1.98:8090, 2026-10-25, commit `c9471a5`) : `nginx -t` OK ; 40 ouvertures `/ws` en rafale depuis une même IP → 20×`101` + 20×`429` ; 200 `GET /` en parallèle → 104×`200` + 96×`429` (rafale 100). **Reste en attente du propriétaire :** l'IP réelle derrière Cloudflare (`CF-Connecting-IP`) n'est pas encore vérifiée ; en local, nginx voit 172.21.0.1 (pont Docker). À contrôler dans les journaux nginx via le tunnel : l'adresse cliente doit varier d'un joueur à l'autre, sinon tous les joueurs partagent le même panier.
- [x] Vérification de l'en-tête `Origin` sur `/ws` : `deploy/nginx.conf` (403 si `Origin` ≠ `http(s)://<Host>`, absence d'`Origin` acceptée pour curl et la CI). Preuve : homelab, 2026-10-25 (`c9471a5`) : `/ws` → `101` sans `Origin` et avec une `Origin` locale, `403` avec `Origin: https://evil.example` ; et CI, run 40213471823, étape « Assert foreign Origin is refused on /ws ». Le serveur Godot ne peut pas faire ce contrôle (les en-têtes du handshake ne sont pas exposés : `WebSocketPeer.get_handshake_headers()` est vide côté serveur, vérifié sous Godot 4.7.2).
- [x] Binaire Godot 4.7.2 vérifié par SHA-256 (`deploy/Dockerfile.server` et job `godot` de la CI) : `cadd3204e728a35d3f13adb7fd0d7902636b79f6b95c40c265eb73b6c35329e4`, calculé le 2026-10-24 sur `Godot_v4.7.2-stable_linux.x86_64.zip` téléchargé depuis la release officielle `godotengine/godot` 4.7.2-stable (77 860 424 octets) ; le SHA-512 du même fichier (`9aa00f7a…4c65`) égale la ligne correspondante de `SHA512-SUMS.txt` de cette release. Preuve : `echo "cadd3204e728a35d3f13adb7fd0d7902636b79f6b95c40c265eb73b6c35329e4  godot.zip" | sha256sum -c -` → `godot.zip: OK` sur l'archive téléchargée (une empreinte altérée → `FAILED`, code 1).
- [x] Images Docker épinglées par digest : `debian:bookworm-slim` (`deploy/Dockerfile.server`, digest de l'index multi-arch lu sur le registre Docker Hub le 2026-10-24), `nginx:alpine` et `barichello/godot-ci:4.7.2` (`deploy/Dockerfile`, épinglées le 2026-10-25 par `3639bca`). Preuve : les trois références portent `@sha256:…` dans les Dockerfiles, et le build Docker passe en CI (run 40213471823, étapes `export`) ainsi que sur le homelab (déploiement `c9471a5`).
- [x] CI : étapes `export` « Assert lobby listRooms through nginx » (client WebSocket via nginx, Origin identique à l'hôte) et « Assert foreign Origin is refused on /ws ». Preuve : run GitHub 40213471823 vert, étapes comprises.
- [ ] Vérifications propriétaire (Cloudflare : WebSockets activé, Rocket Loader désactivé, `/ws` → 101, pas de service worker périmé, IP réelle visible) : procédure dans `deploy/DEPLOYMENT.md`, section 8.
- [ ] TLS : fourni par le tunnel Cloudflare ; ne pas exposer le port 8090 directement sur Internet.
