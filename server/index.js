// server/index.js - Boss Monster server bootstrap (no boardgame.io).
//
// Koa app + Socket.IO + static client + lobby REST + cleanup cron + graceful shutdown.
import Koa from 'koa';
import serve from 'koa-static';
import { createServer } from 'node:http';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { existsSync } from 'node:fs';
import { migrate, closePool, countActiveMatches, storageKind } from './db.js';
import { lobbyRouter } from './lobby.js';
import { createSocketIO, broadcastLobbyUpdate } from './socket.js';
import { startCleanupCron } from './cleanup.js';
import { flushDirty, startTurnTimers, stopTurnTimers } from './matches.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

const PORT = Number(process.env.PORT) || 8000;
const STATIC_DIR = process.env.STATIC_DIR || path.join(__dirname, '..', 'dist');
const FLUSH_INTERVAL_MS = Number(process.env.FLUSH_INTERVAL_MS || 5000);

async function main() {
  // 1. DB migrations (idempotent). Uses in-memory fallback if no DATABASE_URL.
  // If Postgres is not ready yet (e.g. racing with the db container), retry a
  // few times before giving up — the app container depends_on db healthy, but
  // the pool can still briefly refuse connections during handover.
  if (!process.env.DATABASE_URL) {
    await migrate();
    console.log('[db] storage: memory');
  } else {
    const MAX_DB_RETRIES = 5;
    const DB_RETRY_MS = 2000;
    for (let attempt = 1; attempt <= MAX_DB_RETRIES; attempt++) {
      try {
        await migrate();
        console.log('[db] storage: postgres');
        break;
      } catch (e) {
        if (attempt === MAX_DB_RETRIES) throw e;
        console.log(`[db] migration attempt ${attempt}/${MAX_DB_RETRIES} failed: ${e.message}; retrying in ${DB_RETRY_MS}ms...`);
        await new Promise(r => setTimeout(r, DB_RETRY_MS));
      }
    }
  }

  // 2. Koa app.
  const app = new Koa();
  app.use(async (ctx, next) => {
    ctx.set('Access-Control-Allow-Origin', ctx.get('Origin') || '*');
    ctx.set('Access-Control-Allow-Methods', 'GET,POST,PUT,DELETE,OPTIONS');
    ctx.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');
    if (ctx.method === 'OPTIONS') { ctx.status = 204; return; }
    await next();
  });
  // Healthcheck endpoint (used by Docker). Mounted BEFORE lobby + static so
  // it always answers, even if a stray file exists under dist/.
  app.use(async (ctx, next) => {
    if (ctx.path === '/health') {
      try {
        const n = await countActiveMatches();
        ctx.body = { ok: true, activeMatches: n, storage: storageKind() };
      } catch (e) {
        ctx.status = 503;
        ctx.body = { ok: false, error: e.message, storage: storageKind() };
      }
      return;
    }
    await next();
  });
  app.use(lobbyRouter().routes());
  app.use(lobbyRouter().allowedMethods());
  if (existsSync(STATIC_DIR)) {
    app.use(serve(STATIC_DIR));
    console.log(`[static] serving ${STATIC_DIR}`);
  }

  // 3. HTTP + Socket.IO server.
  const httpServer = createServer(app.callback());
  const io = createSocketIO(httpServer);

  // 4. Periodic state flush to DB (debounced snapshot of dirty matches).
  const flushTimer = setInterval(flushDirty, FLUSH_INTERVAL_MS);
  flushTimer.unref?.();

  // 5. Lobby update broadcast (so lobby viewers see new matches quickly).
  const lobbyTimer = setInterval(async () => {
    try { await broadcastLobbyUpdate(io); } catch (e) { /* ignore */ }
  }, 3000);
  lobbyTimer.unref?.();

  // 6. Cleanup cron.
  const cleanup = startCleanupCron();

  // 6b. Turn timers (auto-pass on expiry, server-authoritative).
  startTurnTimers();

  // 7. Graceful shutdown.
  let shuttingDown = false;
  const shutdown = async (sig) => {
    if (shuttingDown) return;
    shuttingDown = true;
    console.log(`\n[shutdown] received ${sig}, flushing state...`);
    clearInterval(flushTimer);
    clearInterval(lobbyTimer);
    clearInterval(cleanup.timer);
    stopTurnTimers();
    await flushDirty();
    io.close();
    httpServer.close();
    await closePool();
    console.log('[shutdown] done.');
    process.exit(0);
  };
  process.on('SIGTERM', () => shutdown('SIGTERM'));
  process.on('SIGINT', () => shutdown('SIGINT'));

  // 8. Listen.
  httpServer.listen(PORT, () => {
    console.log(`Boss Monster server running on http://localhost:${PORT}`);
    console.log(`Lobby API:  http://localhost:${PORT}/lobby`);
    console.log(`Socket.IO:  ws://localhost:${PORT}/socket.io`);
    console.log(`Health:     http://localhost:${PORT}/health`);
    console.log(`Cleanup:    every ${cleanup.intervalMs / 60000}min, purge after ${cleanup.staleMs / 60000}min inactivity`);
  });
}

main().catch((err) => {
  console.error('[boot] failed:', err);
  process.exit(1);
});