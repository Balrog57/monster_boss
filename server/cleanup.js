// server/cleanup.js - Stale match purge cron.
//
// Wipes matches that have not been updated for more than STALE_MS and either:
//   - have no human player seated, or
//   - are finished.
// Mirrors the behavior we verified in boardgame.io (auto-wipe on last leave)
// and adds a safety net for matches abandoned via tab-close.
import { listMatches, wipeMatch } from './db.js';
import { GAME_META } from './reducer.js';

const DEFAULT_STALE_MS = 60 * 60 * 1000;       // 1 hour
const DEFAULT_INTERVAL_MS = 30 * 60 * 1000;   // 30 minutes

export function startCleanupCron({ onTick } = {}) {
  const staleMs = Number(process.env.STALE_MATCH_MS || DEFAULT_STALE_MS);
  const intervalMs = Number(process.env.CLEANUP_INTERVAL_MS || DEFAULT_INTERVAL_MS);

  const purge = async () => {
    try {
      const cutoff = new Date(Date.now() - staleMs);
      // List matches older than cutoff (updated_at < cutoff). We fetch all
      // and filter in JS to keep the query simple across PG versions.
      const rows = await listMatches({ gameName: GAME_META.name });
      let wiped = 0;
      for (const r of rows) {
        const updated = new Date(r.updated_at);
        if (updated >= cutoff) continue;
        const hasHuman = (r.seats || []).some(s => s.name && !s.isBot);
        const isFinished = r.status === 'finished';
        if (!hasHuman || isFinished) {
          await wipeMatch(r.id);
          wiped++;
        }
      }
      if (wiped > 0) console.log(`[cleanup] purged ${wiped} stale match(es).`);
      if (onTick) onTick({ wiped });
    } catch (err) {
      console.error('[cleanup] failed:', err.message);
    }
  };

  const timer = setInterval(purge, intervalMs);
  timer.unref?.();
  // Run an initial pass shortly after boot.
  setTimeout(purge, 5000);
  return { timer, purge, staleMs, intervalMs };
}