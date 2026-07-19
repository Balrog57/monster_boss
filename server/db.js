// server/db.js - PostgreSQL pool, migrations, and match storage helpers.
//
// When DATABASE_URL is set, all functions use a real Postgres pool. When it
// is unset, they fall back to an in-memory store (db-memory.js) so the server
// can run for local dev and tests without an external database. The in-memory
// fallback is NOT durable across restarts.
import pg from 'pg';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import * as memoryDB from './db-memory.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

const { Pool } = pg;

let pool = null;
const useMemory = !process.env.DATABASE_URL;

export function getPool() {
  if (useMemory) return null;
  if (!pool) {
    const databaseUrl = process.env.DATABASE_URL;
    pool = new Pool({
      connectionString: databaseUrl,
      max: Number(process.env.DB_POOL_MAX || 10),
      idleTimeoutMillis: 30000,
    });
    pool.on('error', (err) => {
      console.error('[db] pool error:', err.message);
    });
  }
  return pool;
}

export async function migrate() {
  if (useMemory) { return memoryDB.migrate(); }
  const sqlPath = path.join(__dirname, 'migrate.sql');
  const sql = readFileSync(sqlPath, 'utf8');
  const p = getPool();
  await p.query(sql);
  console.log('[db] migrations applied');
}

export async function closePool() {
  if (useMemory) { return memoryDB.closePool(); }
  if (pool) {
    await pool.end();
    pool = null;
    console.log('[db] pool closed');
  }
}

export function storageKind() {
  return useMemory ? 'memory' : 'postgres';
}

// --- Match helpers ---------------------------------------------------------
// Each function delegates to memoryDB when useMemory is true, else uses pg.

export async function createMatch(opts) {
  if (useMemory) return memoryDB.createMatch(opts);
  const p = getPool();
  await p.query(
    `INSERT INTO matches (id, game_name, num_players, state, ctx, status, setup_data)
     VALUES ($1, $2, $3, $4, $5, 'open', $6)`,
    [opts.id, opts.gameName, opts.numPlayers, JSON.stringify(opts.state), JSON.stringify(opts.ctx), JSON.stringify(opts.setupData || null)]
  );
  const seatValues = [];
  const seatParams = [];
  for (let i = 0; i < opts.numPlayers; i++) {
    seatValues.push(`($1, $${i + 2})`);
    seatParams.push(i);
  }
  await p.query(
    `INSERT INTO match_players (match_id, player_id) VALUES ${seatValues.join(', ')}`,
    [opts.id, ...seatParams]
  );
}

export async function fetchMatch(id) {
  if (useMemory) return memoryDB.fetchMatch(id);
  const p = getPool();
  const { rows } = await p.query(
    `SELECT m.*, COALESCE(
       jsonb_agg(jsonb_build_object(
         'id', mp.player_id,
         'name', mp.player_name,
         'credentials', mp.credentials,
         'isBot', mp.is_bot
       ) ORDER BY mp.player_id) FILTER (WHERE mp.match_id IS NOT NULL), '[]'::jsonb
     ) AS seats
     FROM matches m
     LEFT JOIN match_players mp ON mp.match_id = m.id
     WHERE m.id = $1
     GROUP BY m.id`,
    [id]
  );
  return rows[0] || null;
}

export async function listMatches(opts = {}) {
  if (useMemory) return memoryDB.listMatches(opts);
  const p = getPool();
  const where = [];
  const params = [];
  if (opts.gameName) { params.push(opts.gameName); where.push(`m.game_name = $${params.length}`); }
  if (opts.status)   { params.push(opts.status);   where.push(`m.status = $${params.length}`); }
  const clause = where.length ? `WHERE ${where.join(' AND ')}` : '';
  const { rows } = await p.query(
    `SELECT m.*, COALESCE(
       jsonb_agg(jsonb_build_object(
         'id', mp.player_id,
         'name', mp.player_name,
         'isBot', mp.is_bot
       ) ORDER BY mp.player_id) FILTER (WHERE mp.match_id IS NOT NULL), '[]'::jsonb
     ) AS seats
     FROM matches m
     LEFT JOIN match_players mp ON mp.match_id = m.id
     ${clause}
     GROUP BY m.id
     ORDER BY m.created_at DESC`,
    params
  );
  return rows;
}

export async function saveMatchState(id, data) {
  if (useMemory) return memoryDB.saveMatchState(id, data);
  const p = getPool();
  const sets = ['state = $2', 'ctx = $3'];
  const params = [id, JSON.stringify(data.state), JSON.stringify(data.ctx)];
  if (data.status) { params.push(data.status); sets.push(`status = $${params.length}`); }
  if (data.winner != null) { params.push(data.winner); sets.push(`winner = $${params.length}`); }
  await p.query(`UPDATE matches SET ${sets.join(', ')} WHERE id = $1`, params);
}

export async function joinSeat(matchId, playerId, data) {
  if (useMemory) return memoryDB.joinSeat(matchId, playerId, data);
  const p = getPool();
  const res = await p.query(
    `UPDATE match_players
       SET player_name = $3, credentials = $4, is_bot = $5
     WHERE match_id = $1 AND player_id = $2
       AND player_name IS NULL`,
    [matchId, playerId, data.playerName, data.credentials, data.isBot]
  );
  return res.rowCount > 0;
}

export async function leaveSeat(matchId, playerId) {
  if (useMemory) return memoryDB.leaveSeat(matchId, playerId);
  const p = getPool();
  await p.query(
    `UPDATE match_players SET player_name = NULL, credentials = NULL, is_bot = FALSE
     WHERE match_id = $1 AND player_id = $2`,
    [matchId, playerId]
  );
  const { rows } = await p.query(
    `SELECT COUNT(*) AS humans FROM match_players WHERE match_id = $1 AND player_name IS NOT NULL AND is_bot = FALSE`,
    [matchId]
  );
  return Number(rows[0].humans) === 0;
}

export async function setMatchStatus(matchId, status, winner = null) {
  if (useMemory) return memoryDB.setMatchStatus(matchId, status, winner);
  const p = getPool();
  await p.query(
    `UPDATE matches SET status = $2, winner = COALESCE($3, winner) WHERE id = $1`,
    [matchId, status, winner]
  );
}

export async function wipeMatch(id) {
  if (useMemory) return memoryDB.wipeMatch(id);
  const p = getPool();
  await p.query(`DELETE FROM matches WHERE id = $1`, [id]);
}

export async function countActiveMatches() {
  if (useMemory) return memoryDB.countActiveMatches();
  const p = getPool();
  const { rows } = await p.query(`SELECT COUNT(*) AS n FROM matches WHERE status IN ('open','running')`);
  return Number(rows[0].n);
}