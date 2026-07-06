// server.js - boardgame.io server for Boss Monster online multiplayer.
//
// Runs a Koa + socket.io server on port 8000 that:
//   - hosts the BossMonster game (state, moves, phases)
//   - exposes the Lobby REST API (create/join/list matches)
//   - serves the built client from dist/ (optional, for single-port hosting)
//
// Start:  npm run serve   (uses vite-node to resolve ESM + boardgame.io paths)
// Build:  npm run build   (then this serves dist/ at http://localhost:8000)
//
import { Server, Origins } from 'boardgame.io/server';
import { BossMonster } from './src/BossMonster.js';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { existsSync } from 'node:fs';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

const server = Server({
  games: [BossMonster],
  origins: [
    Origins.LOCALHOST_IN_DEVELOPMENT,
    // Allow the Vite dev server (port 3000) to connect during development.
    'http://localhost:3000',
    // Allow LAN access if you test from another device.
    /^http:\/\/192\.168\..*/,
  ],
});

// Optionally serve the production build so the whole app runs on one port.
const distDir = path.join(__dirname, 'dist');
if (existsSync(distDir)) {
  const koaStatic = (await import('koa-static')).default;
  server.app.use(koaStatic(distDir));
  console.log(`Serving client from ${distDir}`);
}

const PORT = process.env.PORT || 8000;
server.run(PORT, () => {
  console.log(`Boss Monster server running on http://localhost:${PORT}`);
  console.log(`Lobby API:  http://localhost:${PORT}/games/boss-monster`);
});
