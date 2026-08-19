// server/matches.js - In-memory registry and authority for active matches.
//
// Holds the authoritative { G, ctx } for matches that are currently being
// played. The server applies moves here (single-threaded, no locks needed at
// 1k concurrent) and broadcasts the resulting state to connected sockets.
// State is snapshotted to Postgres via db.js on a debounce timer and on
// terminal events (game over, abandoned).
import { nanoid, customAlphabet } from 'nanoid';
import { setupMatch, applyMove, playerView, GAME_META } from './reducer.js';
import {
  createMatch as dbCreateMatch,
  fetchMatch as dbFetchMatch,
  saveMatchState as dbSaveMatchState,
  joinSeat as dbJoinSeat,
  leaveSeat as dbLeaveSeat,
  setMatchStatus as dbSetMatchStatus,
  wipeMatch as dbWipeMatch
} from './db.js';

// matchID -> { id, G, ctx, sockets: Map<socketID, {playerID, socket}>, dirty, status, turnTimer }
const registry = new Map();
const salonCode = customAlphabet('ABCDEFGHJKLMNPQRSTUVWXYZ23456789', 6);

// Timer configuration (milliseconds per build phase turn)
const TURN_TIMEOUT_MS = Number(process.env.TURN_TIMEOUT_MS || 60000); // default 60s

// ---------------------------------------------------------------------------
// Turn timer: auto-pass when the active player's deadline expires.
// The server is authoritative — checks every 5s.
// ---------------------------------------------------------------------------
let timerInterval = null;

export function startTurnTimers() {
  if (timerInterval) return;
  timerInterval = setInterval(() => {
    const now = Date.now();
    for (const match of registry.values()) {
      if (match.status === 'finished' || match.G.gameOver) continue;
      if (!match.turnStartedAt) continue;
      const deadline = match.turnStartedAt + TURN_TIMEOUT_MS;
      if (now < deadline) continue;
      // Timer expired: auto-pass for the active player (BUILD phase only).
      const activePid = match.ctx.activePlayer;
      const phase = match.ctx.phase || match.G.phase;
      if (phase === 'BUILD' || phase === 'BOSS' || phase === 'SETUP') {
        const { state, error } = applyMove({ G: match.G, ctx: match.ctx }, { type: 'pass', args: [] }, activePid);
        if (!error) {
          match.G = state.G;
          match.ctx = state.ctx;
          match.dirty = true;
          match.turnStartedAt = Date.now();
          match.G.logs.push(`Player ${activePid} ran out of time — auto-pass.`);
          broadcastState(match.id);
        } else {
          // Move rejected (e.g. phase advanced) — reset timer.
          match.turnStartedAt = Date.now();
        }
      } else {
        // Non-build phases auto-advance on the server anyway; reset.
        match.turnStartedAt = Date.now();
      }
    }
  }, 5000);
}

export function stopTurnTimers() {
  if (timerInterval) { clearInterval(timerInterval); timerInterval = null; }
}

export function listRegistry() {
  return Array.from(registry.values());
}

export function getMatch(id) {
  return registry.get(id) || null;
}

export function hasMatch(id) {
  return registry.has(id);
}

export async function createNewMatch({ numPlayers, setupData } = {}) {
  let id = salonCode();
  for (let i = 0; i < 8; i++) {
    if (!registry.has(id) && !(await dbFetchMatch(id))) break;
    id = salonCode();
  }
  const { G, ctx } = setupMatch(numPlayers, setupData);
  await dbCreateMatch({
    id, gameName: GAME_META.name, numPlayers: G.numPlayers, state: G, ctx, setupData
  });
  registry.set(id, { id, G, ctx, sockets: new Map(), dirty: false, status: 'open' });
  return { id, G, ctx };
}

// Load a match back into the registry from Postgres (used on reconnect after
// the process restarted or the match was evicted from memory).
export async function loadMatch(id) {
  if (registry.has(id)) return registry.get(id);
  const row = await dbFetchMatch(id);
  if (!row) return null;
  const G = typeof row.state === 'string' ? JSON.parse(row.state) : row.state;
  const ctx = typeof row.ctx === 'string' ? JSON.parse(row.ctx) : row.ctx;
  const match = { id, G, ctx, sockets: new Map(), dirty: false, status: row.status };
  registry.set(id, match);
  return match;
}

// Apply a move from a player. Returns { ok, error }.
export function submitMove(matchID, playerID, move) {
  const match = registry.get(matchID);
  if (!match) return { ok: false, error: 'match not found' };
  if (match.status === 'finished') return { ok: false, error: 'match is finished' };

  const { state, error } = applyMove({ G: match.G, ctx: match.ctx }, move, playerID);
  if (error) return { ok: false, error };
  match.G = state.G;
  match.ctx = state.ctx;
  match.dirty = true;
  // Reset turn timer on each move
  match.turnStartedAt = Date.now();

  if (match.G.gameOver) {
    match.status = 'finished';
  }
  return { ok: true };
}

// Broadcast the current state to all connected sockets. Each socket receives
// the playerView filtered for its own playerID.
export function broadcastState(matchID) {
  const match = registry.get(matchID);
  if (!match) return;
  const deadline = match.turnStartedAt ? match.turnStartedAt + TURN_TIMEOUT_MS : null;
  for (const [socketID, entry] of match.sockets) {
    const view = playerView(match.G, entry.playerID);
    entry.socket.emit('match:state', { G: view, ctx: match.ctx, matchID, turnDeadline: deadline });
  }
  if (match.G.gameOver) {
    for (const [, entry] of match.sockets) {
      entry.socket.emit('match:ended', { winner: match.G.winner, matchID });
    }
  }
}

export function addSocket(matchID, socket, playerID) {
  const match = registry.get(matchID);
  if (!match) return false;
  const isReconnect = match.sockets.size > 0;
  match.sockets.set(socket.id, { socket, playerID });
  // On (re)join, send the current state immediately.
  const view = playerView(match.G, playerID);
  const deadline = match.turnStartedAt ? match.turnStartedAt + TURN_TIMEOUT_MS : null;
  socket.emit('match:state', { G: view, ctx: match.ctx, matchID, turnDeadline: deadline });
  // Notify other players about the reconnection.
  if (isReconnect) {
    const playerName = match.G.players[playerID]?.boss?.name || `Joueur ${playerID}`;
    for (const [sid, entry] of match.sockets) {
      if (sid !== socket.id) {
        entry.socket.emit('match:notification', { matchID, message: `${playerName} s'est reconnecté !` });
      }
    }
  }
  return true;
}

export function removeSocket(matchID, socketID) {
  const match = registry.get(matchID);
  if (!match) return;
  match.sockets.delete(socketID);
}

// Persist the dirty matches to Postgres (called by a debounce timer).
export async function flushDirty() {
  const dirty = [];
  for (const match of registry.values()) {
    if (match.dirty) {
      dirty.push(match);
      match.dirty = false;
    }
  }
  await Promise.all(dirty.map(async (m) => {
    try {
      await dbSaveMatchState(m.id, {
        state: m.G, ctx: m.ctx, status: m.status,
        winner: m.G.winner != null ? m.G.winner : null
      });
    } catch (e) {
      console.error(`[matches] flush failed for ${m.id}:`, e.message);
      m.dirty = true; // retry next pass
    }
  }));
}

// --- Seat management (delegates to db, mirrors boardgame.io semantics) ------
export async function joinMatchSeat(matchID, playerName) {
  const row = await dbFetchMatch(String(matchID || '').toUpperCase());
  if (!row) return { ok: false, error: 'match not found' };
  if (row.status === 'finished') return { ok: false, error: 'match is finished' };
  const seats = row.seats || [];
  const free = seats.find(s => !s.name && !s.isBot);
  if (!free) return { ok: false, error: 'match is full' };
  // A player can only hold one seat per match: if the same playerName is
  // already seated, refuse.
  if (seats.some(s => s.name === playerName)) {
    return { ok: false, error: 'player already joined this match' };
  }
  const credentials = nanoid();
  const ok = await dbJoinSeat(row.id, free.id, { playerName, credentials, isBot: false });
  if (!ok) return { ok: false, error: 'seat was taken concurrently' };
  return { ok: true, playerID: free.id, credentials };
}

export async function leaveMatchSeat(matchID, playerID, credentials) {
  const row = await dbFetchMatch(matchID);
  if (!row) return { ok: false, error: 'match not found' };
  const seat = (row.seats || []).find(s => s.id === Number(playerID));
  if (!seat) return { ok: false, error: 'player not found' };
  if (seat.credentials && seat.credentials !== credentials) return { ok: false, error: 'invalid credentials' };
  const emptied = await dbLeaveSeat(matchID, Number(playerID));
  // If no human remains, wipe the match (mirrors boardgame.io behavior).
  if (emptied) {
    await dbWipeMatch(matchID);
    registry.delete(matchID);
  }
  return { ok: true, emptied };
}

export async function abandonMatch(matchID) {
  await dbWipeMatch(matchID);
  registry.delete(matchID);
}

export async function setMatchFinished(matchID, winner) {
  await dbSetMatchStatus(matchID, 'finished', winner);
  const match = registry.get(matchID);
  if (match) match.status = 'finished';
}