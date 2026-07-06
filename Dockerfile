# Dockerfile - Boss Monster game (boardgame.io server + static client)
#
# Multi-stage build:
#   1. build stage: Node + npm install + vite build -> dist/
#   2. runtime stage: Node + dist/ + server.js (serves client on :8000)
#
# The server.js hosts both the boardgame.io game (state/moves/multiplayer) and
# the built client, so a single port (8000) serves everything.
#
FROM node:20-slim AS build
WORKDIR /app

# Install deps (cache layer)
COPY package.json package-lock.json* ./
RUN npm ci || npm install

# Copy source and build the client
COPY . .
RUN npm run build

# --- runtime stage ---
FROM node:20-slim AS runtime
WORKDIR /app

ENV NODE_ENV=production
ENV PORT=8000

# Install only production deps (boardgame.io server, koa-static)
COPY package.json package-lock.json* ./
RUN npm ci --omit=dev || npm install --omit=dev

# Copy the built client + server
COPY --from=build /app/dist ./dist
COPY server.js ./
COPY src ./src
COPY assets ./assets

# vite-node is needed to run server.js (resolves ESM + boardgame.io paths)
RUN npx --yes vite-node --version 2>/dev/null || npm install -g vite-node

EXPOSE 8000

# Healthcheck: hit the lobby API
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD node -e "fetch('http://127.0.0.1:8000/games').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"

CMD ["npx", "vite-node", "server.js"]
