# Déploiement sur ZimaOS

Le jeu est un export web Godot (statique) servi par nginx dans un conteneur
unique `boss-monster-web`. L'export est produit **dans le build Docker**
(image `barichello/godot-ci`) : rien à exporter à la main avant le build.
Plus de Node ni de Postgres.

## Prérequis

- ZimaOS avec Docker et Docker Compose (fournis par défaut), accès SSH
  (alias `homelab` si configuré, sinon `ssh user@192.168.1.98`)
- Accès internet sortant pour tirer `barichello/godot-ci:4.7.2` et `nginx:alpine`
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
- **Désactiver Rocket Loader** pour ce nom d'hôte (Speed > Optimization) : il
  réécrit les `<script>` et casse le chargeur Emscripten/Godot.
- Service worker : le PWA est désactivé dans l'export. Les navigateurs ayant
  visité l'ancien déploiement peuvent garder une page périmée au premier
  chargement : recharger deux fois (ou vider les données du site).

## 8. Multijoueur

Tant que le serveur multijoueur Godot n'est pas déployé, le bouton
« WITH FRIENDS » affiche une erreur de connexion : c'est normal. Le service
serveur et le proxy nginx `/ws` seront ajoutés avec lui.

## 9. Migration depuis l'ancienne pile (Node + Postgres)

L'ancienne pile utilisait les conteneurs `boss-monster` et `boss-monster-db`
et le volume `boss_db`.

```bash
cd /DATA/AppData/boss-monster
# 1. Arrêter l'ancienne pile AVANT le git pull (avec l'ANCIEN fichier compose, qui
#    connaît encore les services db et boss-monster), SANS --remove-orphans
#    (il supprimerait boss-monster-db). Le volume boss_db est conservé :
DOCKER_CONFIG=/DATA/.docker-root docker compose -f deploy/docker-compose.yml down
#    (variante réversible : `stop` au lieu de `down` garde les conteneurs)
# 2. git pull, puis démarrer la nouvelle pile (section 2)
```

Le port 8090 est libéré par l'arrêt. Les anciens conteneurs `boss-monster` /
`boss-monster-db` (s'ils subsistent) et surtout le volume `boss_db` ne doivent
être supprimés (`docker rm`, `docker volume rm boss_db`) **qu'avec l'accord
explicite du propriétaire** : le volume contient les données de l'ancien
Postgres, supprimées définitivement.

## 10. Dépannage

| Symptôme | Cause probable | Solution |
|---|---|---|
| Build : `export_templates` introuvable | Tag d'image sans templates 4.7.2 | Vérifier le tag `barichello/godot-ci:4.7.2` sur Docker Hub |
| Build : `index.pck` manquant | Erreur d'export Godot | Lire les logs du stage `export` (`docker compose ... build --progress=plain`) |
| Écran blanc / page périmée | Ancien service worker | Recharger deux fois (section 7) |
| Écran blanc via Cloudflare seulement | Rocket Loader actif | Le désactiver (section 7) |
| `502` via Cloudflare | Conteneur arrêté | `docker logs boss-monster-web`, `curl -I http://192.168.1.98:8090/` |
| `permission denied` sur `docker compose` | `/DATA/.docker*` non inscriptible via SSH | `DOCKER_CONFIG=/tmp/dockercfg-bm` (section 2) |
