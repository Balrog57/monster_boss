// server/matches.js - In-memory registry and authority for active matches.
//
// Holds the authoritative { G, ctx } for matches that are currently being
// played. The server applies moves here (single-threaded, no locks needed at
// 1k concurrent) and broadcasts the resulting state to connected sockets.
// State is snapshotted to Postgres via db.js on a debounce timer and on
// terminal events (game over, abandoned).
import { nanoid, customAlphabet } from 'nanoid';
import { setupMatch, applyMove, playerView, GAME_META, pickOpeningDiscardIndices } from '../game/reducer.js';
import { aiPickMove } from '../game/ai.js';
import { encodeState, decodeState, parseState } from '../game/stateCodec.js';
import { aiResolveLevelUpChoice } from '../game/roomAbilities.js';
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

// Timer configuration defaults (milliseconds per turn / phase)
const DEFAULT_TURN_TIMEOUT_MS = Number(process.env.TURN_TIMEOUT_MS || 60000); // 60s global timeout (APK GamePlayBaseScene.cs:131)
const DEFAULT_DONE_TIMEOUT_MS = Number(process.env.DONE_TIMEOUT_MS || 70000); // 70s Pass/Done button timeout (APK DoneButtonBehavior.cs:37)
const DEFAULT_ADVENTURE_TIMEOUT_MS = Number(process.env.ADVENTURE_TIMEOUT_MS || 10000); // 10s reaction timeout in multiplayer

export function getMatchTimerInfo(match) {
  if (!match || match.status === 'finished' || match.G?.gameOver) {
    return { timerEnabled: false, turnDeadline: null, turnTimeout: 0, remainingSeconds: 0 };
  }
  const setup = match.setupData || {};
  const enabled = setup.timerEnabled !== false;
  const configuredTurnSec = setup.turnTimeoutSeconds != null
    ? Number(setup.turnTimeoutSeconds)
    : (setup.turnTimeout != null ? Number(setup.turnTimeout) : DEFAULT_TURN_TIMEOUT_MS / 1000);

  if (!enabled || configuredTurnSec <= 0) {
    return { timerEnabled: false, turnDeadline: null, turnTimeout: 0, remainingSeconds: 0 };
  }

  const isAdvPause = Boolean(!match.G.stack?.length && match.G.adventure?.pause);
  const timeoutMs = isAdvPause
    ? (setup.adventureTimeoutSeconds ? Number(setup.adventureTimeoutSeconds) * 1000 : DEFAULT_ADVENTURE_TIMEOUT_MS)
    : configuredTurnSec * 1000;

  const startedAt = match.turnStartedAt || Date.now();
  const deadline = startedAt + timeoutMs;
  const remainingSeconds = Math.max(0, Math.ceil((deadline - Date.now()) / 1000));

  return {
    timerEnabled: true,
    turnDeadline: deadline,
    turnTimeout: Math.round(timeoutMs / 1000),
    remainingSeconds,
  };
}

// ---------------------------------------------------------------------------
// ---------------------------------------------------------------------------
// Turn timer: auto-pass when the active player's deadline expires.
// Server-authoritative timer loop (1s interval) with disconnect/AFK fallback.
// ---------------------------------------------------------------------------
let timerInterval = null;

export function checkAndRunBotTurn(matchID) {
  const match = registry.get(matchID);
  if (!match || match.status === 'finished' || match.G?.gameOver) return;

  const { G, ctx } = match;
  let pid = ctx?.activePlayer;
  let move = null;

  if (G.pendingChoice) {
    pid = G.pendingChoice.playerId;
    if (!G.players[pid]?.isAI) return;
    if (G.pendingChoice.type === 'opening-discard') {
      move = { type: 'openingDiscard', args: pickOpeningDiscardIndices(G.players[pid].hand) };
    } else {
      const choiceIdx = aiResolveLevelUpChoice(G, G.pendingChoice);
      move = { type: 'resolveLevelUpChoice', args: [choiceIdx ?? 0] };
    }
  } else if (!G.stack?.length && G.adventure?.pause) {
    const aiPid = Object.keys(G.players).find(id => G.players[id].isAI && !G.players[id].eliminated && !G.adventurePausePassed?.[id]);
    if (aiPid == null) return;
    pid = Number(aiPid);
    move = { type: 'pass', args: [] };
  } else {
    if (!G.players[pid]?.isAI || G.players[pid].eliminated) return;
    move = aiPickMove(G, ctx, pid);
  }

  if (move) {
    setTimeout(() => {
      const current = registry.get(matchID);
      if (!current || current.status === 'finished' || current.G?.gameOver) return;
      const res = submitMove(matchID, pid, move);
      if (res.ok) {
        broadcastState(matchID);
        checkAndRunBotTurn(matchID);
      }
    }, 350);
  }
}

export function startTurnTimers() {
  if (timerInterval) return;
  timerInterval = setInterval(() => {
    const now = Date.now();
    for (const match of registry.values()) {
      if (match.status === 'finished' || match.G?.gameOver) continue;
      if (!match.turnStartedAt) continue;

      const timerInfo = getMatchTimerInfo(match);
      if (!timerInfo.timerEnabled || !timerInfo.turnDeadline) continue;
      if (now < timerInfo.turnDeadline) continue;

      const activePid = match.G.pendingChoice ? match.G.pendingChoice.playerId : match.ctx.activePlayer;
      const p = match.G.players[activePid];

      // Disconnect / Inactivity Fallback: If human timed out, AI Bot takes over!
      if (p && !p.isAI) {
        p.isAI = true;
        p.aiTakeover = true;
        match.G.logs.push(`Joueur ${activePid} n'a pas répondu à temps (${timerInfo.turnTimeout}s) — L'IA prend le relais.`);
        match.dirty = true;
        match.turnStartedAt = Date.now();
        broadcastState(match.id);
        checkAndRunBotTurn(match.id);
        continue;
      }

      const phase = (match.G.phase || match.ctx.phase || '').toLowerCase();
      if (match.G.pendingChoice) {
        let move = null;
        if (match.G.pendingChoice.type === 'opening-discard') {
          move = { type: 'openingDiscard', args: pickOpeningDiscardIndices(p?.hand || []) };
        } else {
          const choiceIdx = aiResolveLevelUpChoice(match.G, match.G.pendingChoice);
          move = { type: 'resolveLevelUpChoice', args: [choiceIdx ?? 0] };
        }
        if (move) {
          const { state, error } = applyMove({ G: match.G, ctx: match.ctx }, move, activePid);
          if (!error) {
            match.G = state.G;
            match.ctx = state.ctx;
            match.dirty = true;
            match.turnStartedAt = Date.now();
            match.G.logs.push(`Player ${activePid} ran out of time — auto-resolved choice.`);
            broadcastState(match.id);
            checkAndRunBotTurn(match.id);
            continue;
          }
        }
        match.turnStartedAt = Date.now();
      } else if (phase === 'boss') {
        if (p && !p.boss) {
          const available = (match.G.bossPicks || []).filter(b =>
            !Object.values(match.G.players).some(pl => pl.boss?.id === b.id)
          );
          const chosen = [...available].sort((a, b) => b.xp - a.xp)[0];
          if (chosen) {
            const { state, error } = applyMove({ G: match.G, ctx: match.ctx }, { type: 'pickBoss', args: [chosen.id] }, activePid);
            if (!error) {
              match.G = state.G;
              match.ctx = state.ctx;
              match.dirty = true;
              match.turnStartedAt = Date.now();
              match.G.logs.push(`Player ${activePid} ran out of time — auto-picked ${chosen.name}.`);
              broadcastState(match.id);
              checkAndRunBotTurn(match.id);
              continue;
            }
          }
        }
        match.turnStartedAt = Date.now();
      } else if (phase === 'build' || phase === 'setup' || phase === 'adventure') {
        const { state, error } = applyMove({ G: match.G, ctx: match.ctx }, { type: 'pass', args: [] }, activePid);
        if (!error) {
          match.G = state.G;
          match.ctx = state.ctx;
          match.dirty = true;
          match.turnStartedAt = Date.now();
          match.G.logs.push(`Player ${activePid} ran out of time — auto-pass.`);
          broadcastState(match.id);
          checkAndRunBotTurn(match.id);
        } else {
          match.turnStartedAt = Date.now();
        }
      } else {
        match.turnStartedAt = Date.now();
      }
    }
  }, 1000);
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

export async function createNewMatch({ numPlayers, setupData, botCount = 0 } = {}) {
  let id = salonCode();
  for (let i = 0; i < 8; i++) {
    if (!registry.has(id) && !(await dbFetchMatch(id))) break;
    id = salonCode();
  }
  const { G, ctx } = setupMatch(numPlayers, setupData);
  await dbCreateMatch({
    id, gameName: GAME_META.name, numPlayers: G.numPlayers, state: G, ctx, setupData
  });
  const match = { id, G, ctx, setupData, sockets: new Map(), dirty: false, status: 'open' };
  registry.set(id, match);

  const botsToAdd = Math.min(Math.max(0, Number(botCount) || 0), numPlayers - 1);
  for (let b = 0; b < botsToAdd; b++) {
    const seatId = numPlayers - 1 - b;
    const cred = nanoid();
    await dbJoinSeat(id, seatId, { playerName: `Bot ${seatId + 1} (IA)`, credentials: cred, isBot: true });
    if (match.G.players[seatId]) {
      match.G.players[seatId].isAI = true;
    }
  }

  return { id, G, ctx };
}

// Load a match back into the registry from Postgres (used on reconnect after
// the process restarted or the match was evicted from memory).
export async function loadMatch(id) {
  if (registry.has(id)) return registry.get(id);
  const row = await dbFetchMatch(id);
  if (!row) return null;
  const G = typeof row.state === 'string' ? parseState(row.state) : decodeState(row.state);
  const ctx = typeof row.ctx === 'string' ? JSON.parse(row.ctx) : row.ctx;
  const setupData = typeof row.setup_data === 'string' ? JSON.parse(row.setup_data) : (row.setup_data || {});
  const match = { id, G, ctx, setupData, sockets: new Map(), dirty: false, status: row.status };
  // Restore isAI flags from seats
  for (const s of row.seats || []) {
    if ((s.isBot || s.is_bot) && match.G.players[s.id]) {
      match.G.players[s.id].isAI = true;
    }
  }
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
  } else {
    checkAndRunBotTurn(matchID);
  }
  return { ok: true };
}

// Broadcast the current state to all connected sockets. Each socket receives
// the playerView filtered for its own playerID.
export function broadcastState(matchID) {
  const match = registry.get(matchID);
  if (!match) return;
  const timerInfo = getMatchTimerInfo(match);
  for (const [socketID, entry] of match.sockets) {
    const view = encodeState(playerView(match.G, entry.playerID));
    entry.socket.emit('match:state', {
      G: view,
      ctx: match.ctx,
      matchID,
      turnDeadline: timerInfo.turnDeadline,
      timer: timerInfo
    });
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

  // If this seat was temporarily controlled by AI takeover, restore human control
  if (match.G.players[playerID]?.aiTakeover) {
    match.G.players[playerID].isAI = false;
    delete match.G.players[playerID].aiTakeover;
    match.G.logs.push(`Joueur ${playerID} est de retour ! L'IA cède le contrôle.`);
    match.dirty = true;
  }

  // On (re)join, send the current state immediately.
  const view = encodeState(playerView(match.G, playerID));
  const timerInfo = getMatchTimerInfo(match);
  socket.emit('match:state', {
    G: view,
    ctx: match.ctx,
    matchID,
    turnDeadline: timerInfo.turnDeadline,
    timer: timerInfo
  });
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

  let match = registry.get(row.id);
  if (!match) match = await loadMatch(row.id);

  // Check if all seats are now filled
  const updatedRow = await dbFetchMatch(row.id);
  const filledCount = (updatedRow.seats || []).filter(s => s.name != null).length;
  if (filledCount >= updatedRow.num_players) {
    await dbSetMatchStatus(row.id, 'running');
    if (match) {
      match.status = 'running';
      match.turnStartedAt = Date.now();
      for (const s of updatedRow.seats || []) {
        if ((s.isBot || s.is_bot) && match.G.players[s.id]) {
          match.G.players[s.id].isAI = true;
        }
      }
      broadcastState(row.id);
      checkAndRunBotTurn(row.id);
    }
  }

  return { ok: true, playerID: free.id, credentials };
}

export async function addBotToMatch(matchID) {
  const mid = String(matchID || '').toUpperCase();
  const row = await dbFetchMatch(mid);
  if (!row) return { ok: false, error: 'match not found' };
  if (row.status === 'finished') return { ok: false, error: 'match is finished' };
  const seats = row.seats || [];
  const free = seats.find(s => !s.name && !s.isBot);
  if (!free) return { ok: false, error: 'no empty seat available' };

  const credentials = nanoid();
  const botName = `Bot ${free.id + 1} (IA)`;
  const ok = await dbJoinSeat(row.id, free.id, { playerName: botName, credentials, isBot: true });
  if (!ok) return { ok: false, error: 'failed to join seat' };

  let match = registry.get(mid);
  if (!match) match = await loadMatch(mid);
  if (match && match.G.players[free.id]) {
    match.G.players[free.id].isAI = true;
  }

  // Check if all seats are now filled
  const updatedRow = await dbFetchMatch(mid);
  const filledCount = (updatedRow.seats || []).filter(s => s.name != null).length;
  if (filledCount >= updatedRow.num_players) {
    await dbSetMatchStatus(mid, 'running');
    if (match) {
      match.status = 'running';
      match.turnStartedAt = Date.now();
      for (const s of updatedRow.seats || []) {
        if ((s.isBot || s.is_bot) && match.G.players[s.id]) {
          match.G.players[s.id].isAI = true;
        }
      }
      broadcastState(mid);
      checkAndRunBotTurn(mid);
    }
  }

  return { ok: true, playerID: free.id, botName };
}

export async function removeBotFromMatch(matchID, playerID) {
  const mid = String(matchID || '').toUpperCase();
  const row = await dbFetchMatch(mid);
  if (!row) return { ok: false, error: 'match not found' };
  const seat = (row.seats || []).find(s => s.id === Number(playerID));
  if (!seat || !(seat.isBot || seat.is_bot)) return { ok: false, error: 'seat is not a bot' };

  await dbLeaveSeat(mid, Number(playerID));
  const match = registry.get(mid);
  if (match && match.G.players[playerID]) {
    match.G.players[playerID].isAI = false;
  }
  return { ok: true };
}

export async function leaveMatchSeat(matchID, playerID, credentials) {
  const mid = String(matchID || '').toUpperCase();
  const row = await dbFetchMatch(mid);
  if (!row) return { ok: false, error: 'match not found' };
  const seat = (row.seats || []).find(s => s.id === Number(playerID));
  if (!seat) return { ok: false, error: 'player not found' };
  if (seat.credentials && seat.credentials !== credentials) return { ok: false, error: 'invalid credentials' };
  const emptied = await dbLeaveSeat(mid, Number(playerID));
  // If no human remains, wipe the match (mirrors boardgame.io behavior).
  if (emptied) {
    await dbWipeMatch(mid);
    registry.delete(mid);
  }
  return { ok: true, emptied };
}

export async function abandonMatch(matchID) {
  const mid = String(matchID || '').toUpperCase();
  await dbWipeMatch(mid);
  registry.delete(mid);
}

export async function setMatchFinished(matchID, winner) {
  const mid = String(matchID || '').toUpperCase();
  await dbSetMatchStatus(mid, 'finished', winner);
  const match = registry.get(mid);
  if (match) match.status = 'finished';
}