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
  de rejoindre un siège libre ; anti-force-brute (331 776 codes) : plus de 5 échecs `join`/`resume` par seconde sur tout le serveur → `busy` sans recherche, 5 échecs sur une connexion la coupent (`Server.gd`).
- **Compteurs WINS/DEFEATS** : déclarés par le client et affichés dans la salle
  d'attente ; ils sont **cosmétiques**, non vérifiés, et ne doivent servir à aucune décision.
- **Pas de persistance** : les parties vivent en mémoire (TTL après le dernier humain,
  `--max-rooms`, `--ttl`) ; aucune donnée personnelle stockée côté serveur.
- **Chaîne de build** : images `barichello/godot-ci:4.7.2`, `nginx:alpine` et
  `debian:bookworm-slim` + binaire Godot 4.7.2 (releases GitHub). L'APK
  d'origine et sa décompilation (`apk-original/`) sont exclus du contexte Docker (`.dockerignore`).

## À durcir avant toute exposition publique large

- [ ] Pas de limite de débit par connexion WebSocket ni par IP (seulement `--max-rooms`) : ajouter `limit_req`/`limit_conn` dans `deploy/nginx.conf` ou la limiter au niveau Cloudflare.
- [ ] Vérifier l'en-tête `Origin` sur `/ws` (aujourd'hui aucune restriction d'origine).
- [ ] Épingler les images Docker par digest.
- [ ] TLS : fourni par le tunnel Cloudflare ; ne pas exposer le port 8090 directement sur Internet.
