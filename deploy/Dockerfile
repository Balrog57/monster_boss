# deploy/Dockerfile - Boss Monster game (Godot web client + Node server + Postgres)
#
# Build from the repo root:
#   docker build -f deploy/Dockerfile .
# (or via deploy/docker-compose.yml, which sets context + dockerfile.)
#
# Prérequis : exporter le client Godot AVANT le build :
#   godot --headless --path src/frontend --export-release Web godot/build_web/index.html
#
# Single-stage image:
#   Node + src/ (serveur, moteur partagé, client web exporté, lobby API + Socket.IO)
#
# NOTE: Node 22+ is required — src/backend/game/cardData.js uses
# `import ... with { type: 'json' }` (import attributes), which is only
# flag-free on Node 22+.
FROM node:22-slim AS runtime
WORKDIR /app

ENV NODE_ENV=production
ENV PORT=8000
ENV DATABASE_URL=postgres://boss:boss@db:5432/bossmonster
ENV TZ=Europe/Paris

# Install only production deps (pg, socket.io, koa, etc.)
COPY package.json package-lock.json* ./
RUN npm ci --omit=dev || npm install --omit=dev

# Copy the backend (server + shared game engine) and the exported Godot web
# client (src/frontend/godot/build_web, servi via STATIC_DIR, voir index.js).
COPY src ./src

EXPOSE 8000

# Healthcheck: hit the HTTP health endpoint
HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
  CMD node -e "fetch('http://127.0.0.1:8000/health').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"

CMD ["node", "src/backend/server/index.js"]