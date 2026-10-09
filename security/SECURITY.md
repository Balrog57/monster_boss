# Security policy — Boss Monster

## Signalement

Ne pas ouvrir d'issue publique pour une faille. Contacter l'auteur du dépôt
(`Balrog57/monster_boss`) en privé avec : description, étapes de
reproduction, impact estimé. Délai de réponse visé : 7 jours.

## Posture actuelle

- **Secrets** : aucun secret n'est commité (`.gitignore` : `.env`, `.env.*`).
  Copier `security/.env.example` vers `.env` (jamais versionné) pour un
  déploiement. Le `DATABASE_URL` par défaut du compose est un mot de passe
  **local/dev uniquement** — le changer en production.
- **Réseau** : le serveur (`src/backend/server/`) expose HTTP + Socket.IO
  sur `PORT` (8000 par défaut). CORS permissif (`Access-Control-Allow-Origin`
  = origine de la requête ou `*`) : ne pas exposer tel quel sur Internet sans
  reverse-proxy (TLS, restriction d'origine).
- **Abus de coups** : `MAX_MOVES_PER_SEC` (défaut 10) limite le débit de
  coups par socket (`src/backend/server/socket.js`). Les coups sont
  re-validés côté serveur (`applyMove`) : le client n'est jamais une source
  de confiance (vues filtrées par `playerView`).
- **Base de données** : `DATABASE_URL` obligatoire en production, sinon repli
  mémoire non persistant. Migrations idempotentes
  (`src/backend/server/migrate.sql`).
- **Chaîne de build** : image `node:22-slim` multi-stage
  (`deploy/Dockerfile`) ; `npm ci` reproductible via `package-lock.json`.
  L'APK d'origine et sa décompilation (`apk-original/`, ~95 Mo) sont exclus
  du contexte Docker (`.dockerignore`).

## À durcir avant toute exposition publique

- [ ] Mot de passe Postgres dédié + secret géré hors compose.
- [ ] Restreindre CORS aux origines du frontend derrière reverse-proxy + TLS.
- [ ] Scan `npm audit` intégré à la CI.
- [ ] Rate-limit HTTP (lobby REST) en plus du rate-limit Socket.IO.
