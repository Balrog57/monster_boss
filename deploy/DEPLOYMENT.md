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

> Le clone du homelab suit la branche `main` : `git checkout main && git pull`, puis la commande ci-dessous.

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

# pck : environ 40,5 Mo (non compressé)
curl -sI http://192.168.1.98:8090/index.pck

# la table MIME de nginx:alpine connaît bien wasm
docker run --rm nginx:alpine grep wasm /etc/nginx/mime.types
```

Tous les fichiers sont servis avec `Cache-Control: no-cache` (noms non hashés) :
le navigateur revalide à chaque chargement (ETag, réponses 304 peu coûteuses).
Poids mesurés le 2026-10-31 (export local, recette du `Dockerfile`) : `index.wasm` 39,5 Mo (gzip 10,1 Mo), `index.pck` 40,5 Mo
(gzip 39,6 Mo : webp déjà compressé, le gzip n'apporte rien), `index.js` 280 Ko (gzip 68 Ko), `index.png` 1,2 Mo : environ 49 Mo au
premier chargement, 0 Mo ensuite (304 à 300 octets chacun, vérifié sous Chrome et Firefox avec un profil persistant ; pour Firefox, par le journal du serveur).

### Contrôle local sans Docker

Pour essayer l'export web sur le poste de développement (aucun Docker requis) :

```bash
# 1. export + gzip : mêmes commandes que le Dockerfile (Godot 4.7.2 et ses modèles d'export installés)
godot --headless --path src/frontend --export-release Web godot/build_web/index.html
(cd src/frontend/godot/build_web && gzip -9k index.wasm index.pck index.js)
# 2. serveur statique qui reproduit nginx.conf (gzip_static, application/wasm, no-cache, ETag/304) ; --bind 0.0.0.0 pour tester depuis le LAN
python tools/web_serve.py --port 8090
# 3. test de fumée dans un vrai navigateur : console propre, canvas non vide, menus, une partie à 2, pause, redimensionnement en direct (python -m pip install playwright && python -m playwright install chromium firefox webkit)
python tools/web_smoke.py --browser chromium --shots docs/reference/web/smoke      # idem : --browser firefox | webkit | chrome | msedge, --size 1440x1080, --headed
```

Salons multijoueurs, toujours sans Docker (le script lance lui-même le serveur Godot headless `godot/server/Server.tscn` et le site, `tools/web_serve.py` fait passer `/ws` au serveur comme nginx ; pose préalable : `python -m pip install playwright websockets psutil`) :

```bash
# 6. parties complètes dans de vrais navigateurs (un contexte Playwright par joueur humain, clics souris : pseudo, avatar, salon, code, lobby, partie jusqu'à l'écran de fin)
python tools/web_online_smoke.py --players 2                          # 2 humains ; --players 4 --bots 2 : 2 humains + 2 IA du serveur
python tools/web_online_smoke.py --players 6 --bots 3 --packs crash-landing   # 5-6 joueurs : Crash Landing et case « wiki » cochées par le script
python tools/web_online_smoke.py --scenario all                       # p2 p3 p4 p5 p6 ext solo + rematch drop multi closed ; --browser firefox, --shot-every 30, --speed fast
# 7. serveur seul, sans navigateur : N salons en parallèle (IA contre robot WebSocket, 2-6 joueurs, paquets livrés) puis abus (messages mal formés, trame trop grosse, rafale, coups hors tour, doubles jonctions, reprises rapides, paquets fermés)
godot --headless --path src/frontend res://godot/server/Server.tscn -- --port=8091 --bot-delay=0
python tools/online_bots.py --rooms 22 --mix --server-pid <pid du serveur> ; python tools/online_bots.py --abuse
```

Chaque partie navigateur vérifie : même résultat final chez tous les clients, console sans erreur ni avertissement imprévu, journal serveur sans ligne `ERROR`, aucune information cachée d'un autre siège dans les vues reçues (contrat de `ViewFilter.gd`, relu sur chaque trame `state`), invariants de la liste `awaited`, absence de salle du dessus face cachée en phase `bait` / `adventure`. Scénarios scriptés : `rematch` (nouveau salon après la fin d'une partie puis après un départ en cours de partie), `drop` (coupure de la liaison de tous les clients, reconnexion automatique avec le même siège, puis onglet fermé en pleine partie : le siège passe à l'IA après la grâce), `multi` (deux salons simultanés, joins refusés : salon complet, code inconnu, partie déjà lancée), `closed` (paquet fermé demandé : refus `bad_setup` et message « INVALID SETUP » à l'écran). Les captures vont dans `docs/reference/web/online/` (ignoré par git). Une partie à 3 humains dure environ 10 à 15 minutes (une décision que le script ne joue pas, comme un choix de cible, expire au bout de `--turn-timeout` secondes et l'IA du serveur la joue).

`tools/web_serve.py` n'est qu'une imitation : il ne remplace pas le `curl -I` ci-dessus sur le vrai conteneur. Le type `application/wasm` de
`nginx:alpine` n'a pas pu être contrôlé sur un conteneur ici (pas de Docker sur le poste) ; il est confirmé par le `mime.types` livré
par nginx (`application/wasm  wasm;`, dépôt nginx, relu le 2026-10-31).

### Navigateurs : ce qui reste à vérifier par le propriétaire (Safari)

Aucun appareil Apple n'a servi aux tests ; WebKit de Playwright (Windows, sans Web Audio) est le seul proxy. À faire une fois sur un Mac / iPhone / iPad
(Safari ≥ 15 pour WebGL 2) : (1) la page se charge sans écran blanc (avertissements `glBlitFramebuffer` / `WEBGL_polygon_mode` seuls tolérés) ;
(2) après le premier clic sur TAP TO START, la musique démarre (règle de reprise de l'`AudioContext` : un geste utilisateur est exigé) et les effets sonores
sont audibles ; (3) la musique boucle sans trou audible (Godot relance le morceau à chaque fin) ; (4) redimensionner la fenêtre ou passer en plein écran
(Ctrl+Cmd+F) redimensionne le canvas sans bande noire sur les côtés d'un 4:3 ; (5) un `Cmd+R` recharge le jeu sans service worker périmé ;
(6) navigation privée : le jeu démarre et signale que la sauvegarde ne persiste pas (IndexedDB indisponible, voir S-02) ; (7) en `http://` sur le LAN
(contexte non sécurisé), le jeu démarre quand même (shim `head_include`).

## 7. Cloudflare

- Le nom d'hôte du tunnel se configure dans le tableau de bord Cloudflare, pas
  dans le dépôt ; il pointe vers `http://192.168.1.98:8090`.
- Les tunnels Cloudflare gèrent les WebSockets sans réglage particulier ; il faut
  seulement laisser **WebSockets** activé dans les paramètres Network de la zone
  (activé par défaut). Le tunnel pointe toujours vers le port 8090 : `/ws` passe par nginx.
  Contrôle **Origin** : nginx refuse (403) tout `/ws` dont l'en-tête `Origin` n'est pas
  `http(s)://<Host de la requête>`. Pour servir le jeu sous un autre nom d'hôte, il suffit
  que le tunnel transmette le `Host` public (c'est le cas par défaut) ; pour autoriser un
  autre site, ajouter une ligne dans le `map $ws_origin_ok` de `deploy/nginx.conf`.
- **Limites par IP** : nginx lit l'IP du visiteur dans `CF-Connecting-IP`, mais seulement
  si la connexion arrive d'une adresse privée/locale (cloudflared). Sans cet en-tête (tunnel
  qui ne le transmet pas, autre reverse proxy), tous les joueurs partagent l'adresse du
  tunnel, donc le même panier `limit_req` / `limit_conn`.
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
- Délai de tour : option `--turn-timeout=70` (secondes) dans le `CMD` de
  `deploy/Dockerfile.server`. Autres options : `--port`, `--adventure-timeout`,
  `--bot-delay`, `--ttl`, `--max-rooms` (voir `src/frontend/godot/server/PROTOCOL.md`).
  Après modification : `docker compose -f deploy/docker-compose.yml up -d --build server`.
- Le binaire Godot du serveur est téléchargé depuis la release GitHub officielle puis vérifié par SHA-256
  (`sha256sum -c` dans `deploy/Dockerfile.server`, mêmes valeur et source que dans `.github/workflows/ci.yml`) ;
  le build échoue si l'archive diffère. Changer de version de Godot = recalculer l'empreinte (et la comparer à `SHA512-SUMS.txt` de la release).
- Logs : `docker logs -f boss-monster-server`.
- Test du proxy (doit répondre `101 Switching Protocols`) :

```bash
curl -s -i -N --max-time 5 -H "Connection: Upgrade" -H "Upgrade: websocket" \
  -H "Sec-WebSocket-Version: 13" -H "Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==" \
  http://192.168.1.98:8090/ws
```

### Vérifications propriétaire (après chaque déploiement)

Ni la CI ni le poste de développement n'ont prouvé le comportement de nginx en conditions réelles
(Cloudflare, IP réelle) : c'est à faire une fois sur le homelab, puis à reporter dans `security/SECURITY.md`.

- [ ] Cloudflare, zone : **WebSockets** activé (Network) ; **Rocket Loader** désactivé pour le nom d'hôte (Speed > Optimization).
- [ ] `https://<nom-public>/ws` répond `101 Switching Protocols` (mêmes en-têtes que ci-dessus, `-H 'Origin: https://<nom-public>'` pour un navigateur) ; la page de lobby « WITH FRIENDS » liste bien les salons publics.
- [ ] Aucun service worker périmé : DevTools > Application > Service Workers vide (sinon « Unregister » ou recharger deux fois).
- [ ] Syntaxe nginx : `docker compose -f deploy/docker-compose.yml exec web nginx -t`.
- [ ] Les limites par IP voient la vraie adresse : `docker logs boss-monster-web` montre des adresses clientes différentes (pas toujours celle du tunnel) pour deux joueurs réels. Si ce n'est pas le cas, `CF-Connecting-IP` n'arrive pas jusqu'à nginx et tout le monde partage le même quota.

Tests nginx (à lancer depuis le homelab, `127.0.0.1:8090` ; adapter l'hôte sinon) :

```bash
H='-H Connection:Upgrade -H Upgrade:websocket -H Sec-WebSocket-Version:13 -H Sec-WebSocket-Key:dGhlIHNhbXBsZSBub25jZQ=='

# Origin étranger -> 403
curl -s -o /dev/null -w '%{http_code}\n' -H 'Origin: https://evil.example' $H --max-time 3 http://127.0.0.1:8090/ws
# Origin identique à l'hôte, ou aucun Origin -> 101
curl -s -o /dev/null -w '%{http_code}\n' -H 'Origin: http://127.0.0.1:8090' $H --max-time 3 http://127.0.0.1:8090/ws
curl -s -o /dev/null -w '%{http_code}\n' $H --max-time 3 http://127.0.0.1:8090/ws

# Limite par IP : 40 ouvertures en rafale, des 429 doivent apparaître après la rafale (5/s + 20 d'avance)
for i in $(seq 40); do curl -s -o /dev/null -w '%{http_code}\n' $H --max-time 1 http://127.0.0.1:8090/ws; done | sort | uniq -c
```

Une liaison `101` reste ouverte jusqu'à `--max-time` (curl signale alors un délai dépassé, c'est normal) ; la rafale dure donc quelques dizaines de secondes.

## 9. Ancienne pile (Node + Postgres)

Supprimée du homelab ; son historique est dans git (ne jamais supprimer un volume `boss_db` résiduel sans l'accord du propriétaire).

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
