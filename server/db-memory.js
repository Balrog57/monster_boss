// server/db-memory.js - In-memory fallback storage (no Postgres required).
//
// Used automatically by db.js when DATABASE_URL is not set. Implements the
// same functions as db.js but keeps everything in Maps. Useful for local dev,
// CI, and smoke tests. NOT durable across restarts — for production, set
// DATABASE_URL to a real Postgres instance.

const matches = new Map();      // id -> match row
const seats = new Map();         // matchID -> Map<playerID, seat>

function row(id) {
  const m = matches.get(id);
  if (!m) return null;
  return { ...m, seats: Array.from(seats.get(id).values()).map(s => ({ ...s })) };
}

export async function migrate() { /* no-op */ }

export async function createMatch({ id, gameName, numPlayers, state, ctx, setupData }) {
  matches.set(id, {
    id, game_name: gameName, num_players: numPlayers,
    state: JSON.parse(JSON.stringify(state)),
    ctx: JSON.parse(JSON.stringify(ctx)),
    status: 'open', winner: null,
    setup_data: setupData || null,
    created_at: new Date(), updated_at: new Date()
  });
  const seatMap = new Map();
  for (let i = 0; i < numPlayers; i++) {
    seatMap.set(i, { id: i, name: null, credentials: null, is_bot: false });
  }
  seats.set(id, seatMap);
}

export async function fetchMatch(id) {
  return row(id);
}

export async function listMatches({ gameName, status } = {}) {
  const out = [];
  for (const [id] of matches) {
    const r = row(id);
    if (gameName && r.game_name !== gameName) continue;
    if (status && r.status !== status) continue;
    out.push(r);
  }
  return out;
}

export async function saveMatchState(id, { state, ctx, status, winner }) {
  const m = matches.get(id);
  if (!m) return;
  m.state = JSON.parse(JSON.stringify(state));
  m.ctx = JSON.parse(JSON.stringify(ctx));
  if (status) m.status = status;
  if (winner != null) m.winner = winner;
  m.updated_at = new Date();
}

export async function joinSeat(matchId, playerId, { playerName, credentials, isBot = false }) {
  const seatMap = seats.get(matchId);
  if (!seatMap) return false;
  const seat = seatMap.get(Number(playerId));
  if (!seat || seat.name !== null) return false;
  seat.name = playerName;
  seat.credentials = credentials;
  seat.is_bot = isBot;
  matches.get(matchId).updated_at = new Date();
  return true;
}

export async function leaveSeat(matchId, playerId) {
  const seatMap = seats.get(matchId);
  if (!seatMap) return false;
  const seat = seatMap.get(Number(playerId));
  if (!seat) return false;
  seat.name = null;
  seat.credentials = null;
  seat.is_bot = false;
  matches.get(matchId).updated_at = new Date();
  let humans = 0;
  for (const s of seatMap.values()) if (s.name && !s.is_bot) humans++;
  return humans === 0;
}

export async function setMatchStatus(matchId, status, winner = null) {
  const m = matches.get(matchId);
  if (!m) return;
  m.status = status;
  if (winner != null) m.winner = winner;
  m.updated_at = new Date();
}

export async function wipeMatch(id) {
  matches.delete(id);
  seats.delete(id);
}

export async function countActiveMatches() {
  let n = 0;
  for (const m of matches.values()) if (m.status === 'open' || m.status === 'running') n++;
  return n;
}

export async function closePool() { /* no-op */ }