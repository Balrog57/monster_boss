# Dockerfile - Boss Monster game (custom Node server + Postgres + static client)
#
# Multi-stage build:
#   1. build stage: Node + npm install + vite build -> dist/
#   2. runtime stage: Node + dist/ + server/ (serves client + lobby API + Socket.IO)
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
ENV DATABASE_URL=postgres://boss:boss@db:5432/bossmonster
ENV TZ=Europe/Paris

# Install only production deps (pg, socket.io, koa, etc.)
COPY package.json package-lock.json* ./
RUN npm ci --omit=dev || npm install --omit=dev

# Copy the built client + server
COPY --from=build /app/dist ./dist
COPY server ./server
COPY src ./src
# server/reducer.js imports from src/ (cardData.js, engine.js, etc.)

EXPOSE 8000

# Healthcheck: hit the HTTP health endpoint
HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
  CMD node -e "fetch('http://127.0.0.1:8000/health').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"

CMD ["node", "server/index.js"]