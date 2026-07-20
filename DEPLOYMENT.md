# Déploiement sur ZimaOS

## Prérequis sur le ZimaOS

- Docker et Docker Compose installés (ZimaOS les fournit par défaut)
- Accès SSH ou terminal au ZimaOS (`ssh user@192.168.1.98`)
- Le dépôt du projet synchronisé sur le ZimaOS

## 1. Récupérer le code sur le ZimaOS

```bash
ssh user@192.168.1.98
cd /DATA/AppData
git clone https://github.com/Balrog57/monster_boss.git boss-monster
cd boss-monster
```

Ou, si le dépôt existe déjà :

```bash
cd /DATA/AppData/boss-monster
git pull
```

## 2. Lancer le déploiement

```bash
cd /DATA/AppData/boss-monster
DOCKER_CONFIG=/DATA/.docker-root docker compose up -d --build
```

> **Note `DOCKER_CONFIG`** : si `/DATA/.docker-root` échoue avec une erreur de permission (`config.json` ou `buildx/instances` refusés via SSH), utiliser un répertoire accessible en écriture :
>
> ```bash
> mkdir -p /tmp/dockercfg-bm
> DOCKER_CONFIG=/tmp/dockercfg-bm docker compose up -d --build
> ```

Cette commande :
- Build l'image `boss-monster:latest` (multi-stage : build Vite + runtime Node)
- Démarre le service `db` (postgres:16-alpine) avec un volume persistant `boss_db`
- Démarre le service `boss-monster` (app) sur le port 8090
- L'app attend que Postgres soit sain (`depends_on: service_healthy`) avant de démarrer
- Les migrations SQL s'exécutent automatiquement au boot (idempotentes)

## 3. Accéder au jeu

- **Local** : http://192.168.1.98:8090
- **Tunnel Cloudflare** : https://<votre-domaine-cloudflare> (le tunnel proxyfie HTTP + WebSocket sur le port 8090)

## 4. Vérifier que tout fonctionne

```bash
# Healthcheck de l'app
curl http://192.168.1.98:8090/health
# Doit retourner : {"ok":true,"activeMatches":0,"storage":"postgres"}

# Lobby API
curl http://192.168.1.98:8090/lobby/games
# Doit retourner : ["boss-monster"]

# Statut des conteneurs
docker compose ps

# Logs de l'app
docker compose logs -f boss-monster

# Logs de la DB
docker compose logs -f db
```

## 5. Mettre à jour

```bash
cd /DATA/AppData/boss-monster
git pull
DOCKER_CONFIG=/DATA/.docker-root docker compose up -d --build
```

> En cas d'erreur de permission sur `DOCKER_CONFIG`, appliquer le contournement de la section 2 (`/tmp/dockercfg-bm`).

Le volume `boss_db` est conservé entre les redéploiements — les matches en cours et l'historique persistent.

## 6. Backup de la base de données

```bash
# Dump complet
docker exec boss-monster-db pg_dump -U boss bossmonster > backup_$(date +%Y%m%d).sql

# Restore
cat backup_YYYYMMDD.sql | docker exec -i boss-monster-db psql -U boss bossmonster
```

## 7. Architecture des conteneurs

```
ZimaOS (192.168.1.98)
├── boss-monster-db        (postgres:16-alpine, port 5432 interne, volume boss_db)
└── boss-monster           (Node 22 + Koa + Socket.IO, port 8090 externe)
    ├── /lobby/*           REST API (create/join/leave matches)
    ├── /socket.io/         WebSocket (real-time game state)
    ├── /health            Healthcheck Docker
    └── /*                 Client statique (dist/)
```

## 8. Variables d'environnement (tunings optionnels)

Définies dans `docker-compose.yml`, modifiables :

| Variable | Défaut | Rôle |
|---|---|---|
| `DATABASE_URL` | `postgres://boss:boss@db:5432/bossmonster` | Connexion Postgres |
| `PORT` | `8000` | Port d'écoute interne (mappé sur 8090) |
| `STALE_MATCH_MS` | `3600000` (1h) | Âge max d'un match inactif avant purge |
| `CLEANUP_INTERVAL_MS` | `1800000` (30min) | Fréquence du cron de purge |
| `MAX_MOVES_PER_SEC` | `10` | Limite anti-spam de moves par joueur |
| `FLUSH_INTERVAL_MS` | `5000` | Fréquence de snapshot d'état vers Postgres |

## 9. Tunnel Cloudflare

Le tunnel Cloudflare proxyfie le port 8090 vers votre domaine. Le WebSocket
(`wss://`) passe automatiquement — aucune config supplémentaire nécessaire.

Si le multi online ne se connecte pas via le tunnel :
1. Vérifier que `cloudflared` tourne et pointe vers `192.168.1.98:8090`
2. Vérifier dans la console navigateur que `socket.io` se connecte en `wss://` (pas `ws://`)
3. Si 502/503 : vérifier que l'app répond sur `http://192.168.1.98:8090/health`

## 10. Dépannage

| Symptôme | Cause probable | Solution |
|---|---|---|
| App redémarre en boucle | DB pas prête | Le retry gère ça ; vérifier `docker compose logs db` |
| `502 Bad Gateway` via Cloudflare | App down ou port incorrect | `curl http://192.168.1.98:8090/health` |
| WebSocket ne se connecte pas | Tunnel pas configuré pour WS | Cloudflare Tunnel gère WS par défaut sur le même port |
| Matches disparaissent après redémarrage | Volume `boss_db` supprimé | Ne jamais `docker volume rm boss_db` |
| `npm ci` échoue dans le build | Lockfile désynchronisé | `git pull` puis `docker compose build --no-cache` |
| `permission denied` sur `docker compose` | Config `/DATA/.docker*` non accessible en écriture via SSH | `mkdir -p /tmp/dockercfg-bm` puis `DOCKER_CONFIG=/tmp/dockercfg-bm docker compose ...` |