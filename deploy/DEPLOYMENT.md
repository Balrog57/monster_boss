# Déploiement sur ZimaOS

Le jeu comprend deux conteneurs : `boss-monster-web` (export web Godot statique
servi par nginx) et `boss-monster-server` (serveur multijoueur Godot headless,
voir section 8). L'export est produit **dans le build Docker**
(image `barichello/godot-ci`) : rien à exporter à la main avant le build.
Plus de Node ni de Postgres.

## Prérequis

- ZimaOS avec Docker et Docker Compose (fournis par défaut), accès SSH
  (alias `homelab` si configuré, sinon `ssh user@192.168.1.98`)
- Accès internet sortant pour tirer `barichello/godot-ci:4.7.2`, `nginx:alpine`,
  `debian:bookworm-slim` et le binaire Godot 4.7.2 (GitHub releases)
- Quelques Go libres pour le premier build (image Godot ~ 2 Go)

## 1. Première installation

```bash
ssh homelab            # ou ssh user@192.168.1.98
cd /DATA/AppData
git clone https://github.com/Balrog57/monster_boss.git boss-monster
cd boss-monster
```

## 2. Build et démarrage

```bash
cd /DATA/AppData/boss-monster
DOCKER_CONFIG=/DATA/.docker-root docker compose -f deploy/docker-compose.yml up -d --build
```

> **Note `DOCKER_CONFIG`** : si `/DATA/.docker-root` échoue avec une erreur de
> permission (`config.json` ou `buildx/instances` refusés via SSH), utiliser un
> répertoire accessible en écriture :
>
> ```bash
> mkdir -p /tmp/dockercfg-bm
> DOCKER_CONFIG=/tmp/dockercfg-bm docker compose -f deploy/docker-compose.yml up -d --build
> ```

Accès : http://192.168.1.98:8090

## 3. Mettre à jour

> Le clone du homelab suit actuellement la branche `parity/apk-oracle` ; après la fusion dans `main` :
> `git checkout main && git pull`, puis la commande ci-dessous.

```bash
cd /DATA/AppData/boss-monster
git pull
DOCKER_CONFIG=/DATA/.docker-root docker compose -f deploy/docker-compose.yml up -d --build
```

## 4. Rollback

```bash
cd /DATA/AppData/boss-monster
git log --oneline -n 10          # repérer le commit sain
git checkout <commit>
DOCKER_CONFIG=/DATA/.docker-root docker compose -f deploy/docker-compose.yml up -d --build
# pour revenir ensuite à la dernière version : git checkout <branche> && git pull && (même commande)
```

## 5. Logs et état

```bash
docker logs boss-monster-web
docker logs boss-monster-server    # serveur multijoueur
docker compose -f deploy/docker-compose.yml ps
```

## 6. Vérifications

```bash
# wasm : type MIME correct + compression gzip pré-calculée
curl -sI -H 'Accept-Encoding: gzip' http://192.168.1.98:8090/index.wasm
# attendu : Content-Type: application/wasm  et  Content-Encoding: gzip

# pck : environ 38 Mo (non compressé)
curl -sI http://192.168.1.98:8090/index.pck

# la table MIME de nginx:alpine connaît bien wasm
docker run --rm nginx:alpine grep wasm /etc/nginx/mime.types
```

Tous les fichiers sont servis avec `Cache-Control: no-cache` (noms non hashés) :
le navigateur revalide à chaque chargement (ETag, réponses 304 peu coûteuses).

## 7. Cloudflare

- Le nom d'hôte du tunnel se configure dans le tableau de bord Cloudflare, pas
  dans le dépôt ; il pointe vers `http://192.168.1.98:8090`.
- Les tunnels Cloudflare gèrent les WebSockets sans réglage particulier ; il faut
  seulement laisser **WebSockets** activé dans les paramètres Network de la zone
  (activé par défaut). Le tunnel pointe toujours vers le port 8090 : `/ws` passe par nginx.
- **Désactiver Rocket Loader** pour ce nom d'hôte (Speed > Optimization) : il
  réécrit les `<script>` et casse le chargeur Emscripten/Godot.
- Service worker : le PWA est désactivé dans l'export. Les navigateurs ayant
  visité l'ancien déploiement peuvent garder une page périmée au premier
  chargement : recharger deux fois (ou vider les données du site).

## 8. Multijoueur

- Service `server` (conteneur `boss-monster-server`, image construite par
  `deploy/Dockerfile.server`) : Godot 4.7.2 headless, WebSocket sur le port 8091
  du réseau compose. **Aucun port n'est publié** : seul nginx l'atteint.
  Les parties vivent en mémoire (pas de base de données) : un redémarrage du
  conteneur les efface.
- nginx (`deploy/nginx.conf`) proxifie `/ws` vers `server:8091` (en-têtes
  `Upgrade`/`Connection`, timeouts 3600 s). Le client web se connecte à
  `ws(s)://<hôte de la page>/ws`. nginx démarre même si le serveur est arrêté
  (resolver Docker + variable) ; `/ws` répond alors `502` jusqu'à son retour.
- Délai de tour : option `--turn-timeout=60` (secondes) dans le `CMD` de
  `deploy/Dockerfile.server`. Autres options : `--port`, `--adventure-timeout`,
  `--bot-delay`, `--ttl`, `--max-rooms` (voir `src/frontend/godot/server/PROTOCOL.md`).
  Après modification : `docker compose -f deploy/docker-compose.yml up -d --build server`.
- Logs : `docker logs -f boss-monster-server`.
- Test du proxy (doit répondre `101 Switching Protocols`) :

```bash
curl -s -i -N --max-time 5 -H "Connection: Upgrade" -H "Upgrade: websocket" \
  -H "Sec-WebSocket-Version: 13" -H "Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==" \
  http://192.168.1.98:8090/ws
```

## 9. Ancienne pile (Node + Postgres) - historique

L'ancienne pile (conteneurs `boss-monster` et `boss-monster-db`, volume `boss_db`)
a été arrêtée puis **supprimée avec l'accord du propriétaire** (conteneurs et
volume retirés du homelab). Si un homelab en possède encore une copie, ne
supprimer les conteneurs et surtout le volume `boss_db` (`docker rm`,
`docker volume rm boss_db`) qu'avec l'accord explicite du propriétaire ; arrêter
l'ancienne pile avec `docker compose ... stop` (pas `down --remove-orphans`) avant le premier `up` de la nouvelle.

## 10. Dépannage

| Symptôme | Cause probable | Solution |
|---|---|---|
| Build : `export_templates` introuvable | Tag d'image sans templates 4.7.2 | Vérifier le tag `barichello/godot-ci:4.7.2` sur Docker Hub |
| Build : `index.pck` manquant | Erreur d'export Godot | Lire les logs du stage `export` (`docker compose ... build --progress=plain`) |
| Écran blanc / page périmée | Ancien service worker | Recharger deux fois (section 7) |
| Écran blanc via Cloudflare seulement | Rocket Loader actif | Le désactiver (section 7) |
| `502` via Cloudflare | Conteneur arrêté | `docker logs boss-monster-web`, `curl -I http://192.168.1.98:8090/` |
| « WITH FRIENDS » : erreur de connexion, `/ws` en `502` | Serveur multijoueur arrêté ou en cours de démarrage | `docker logs boss-monster-server`, `docker compose -f deploy/docker-compose.yml ps` |
| `/ws` ne répond pas `101` via Cloudflare | WebSockets désactivés dans la zone | Réactiver (section 7) |
| `permission denied` sur `docker compose` | `/DATA/.docker*` non inscriptible via SSH | `DOCKER_CONFIG=/tmp/dockercfg-bm` (section 2) |
