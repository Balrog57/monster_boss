// server/lobby.js - REST API for the lobby: create/list/join/leave matches.
//
// Mounted under /lobby on the Koa app. All responses are JSON.
import Router from '@koa/router';
import koaBody from 'koa-body';
import { GAME_META, playerView, legalMoves } from '../game/reducer.js';
import { createNewMatch, joinMatchSeat, leaveMatchSeat, addBotToMatch, removeBotFromMatch, loadMatch, submitMove, getMatchTimerInfo } from './matches.js';
import { listMatches, fetchMatch } from './db.js';

// Seat credential check shared by the native-client REST bridge below.
function checkSeat(row, playerID, credentials) {
  const seat = (row.seats || []).find(s => s.id === Number(playerID));
  if (!seat || !credentials || seat.credentials !== credentials) return null;
  return seat;
}

function publicSeats(row) {
  return (row.seats || []).map(s => ({ id: s.id, name: s.name || null, isBot: !!(s.isBot ?? s.is_bot) }));
}

export function lobbyRouter() {
  const router = new Router({ prefix: '/lobby' });
  router.use(koaBody());

  // List supported games.
  router.get('/games', (ctx) => {
    ctx.body = [GAME_META.name];
  });

  // List open/running matches (optionally filtered by game).
  router.get('/matches', async (ctx) => {
    const game = ctx.query.game || GAME_META.name;
    const status = ctx.query.status; // 'open' | 'running' | 'finished' | undefined
    const rows = await listMatches({ gameName: game, status });
    ctx.body = rows.map(r => {
      const setup = typeof r.setup_data === 'string' ? JSON.parse(r.setup_data) : (r.setup_data || {});
      return {
        id: r.id,
        gameName: r.game_name,
        numPlayers: r.num_players,
        status: r.status,
        winner: r.winner,
        setupData: setup,
        isPublic: setup.isPublic !== false,
        seats: (r.seats || []).map(s => ({
          id: s.id,
          name: s.name || null,
          isBot: !!(s.isBot ?? s.is_bot)
        })),
        createdAt: r.created_at,
        updatedAt: r.updated_at
      };
    });
  });

  // Get one match.
  router.get('/matches/:id', async (ctx) => {
    const row = await fetchMatch(String(ctx.params.id || '').toUpperCase());
    if (!row) { ctx.throw(404, 'match not found'); return; }
    const setup = typeof row.setup_data === 'string' ? JSON.parse(row.setup_data) : (row.setup_data || {});
    ctx.body = {
      id: row.id,
      gameName: row.game_name,
      numPlayers: row.num_players,
      status: row.status,
      winner: row.winner,
      setupData: setup,
      isPublic: setup.isPublic !== false,
      seats: (row.seats || []).map(s => ({ id: s.id, name: s.name || null, isBot: !!(s.isBot ?? s.is_bot) })),
      createdAt: row.created_at,
      updatedAt: row.updated_at
    };
  });

  // Create a new match (private or public salon, 6-character code, with optional bots and expansions).
  router.post('/matches', async (ctx) => {
    const numPlayers = Number(ctx.request.body.numPlayers) || 2;
    const botCount = Number(ctx.request.body.botCount) || 0;
    const rawSetup = ctx.request.body.setupData || {};
    const setupData = {
      ...rawSetup,
      online: true,
      isPublic: rawSetup.isPublic !== false,
      timerEnabled: rawSetup.timerEnabled !== false,
      turnTimeoutSeconds: Number(rawSetup.turnTimeoutSeconds || rawSetup.turnTimeout || 60),
      adventureTimeoutSeconds: Number(rawSetup.adventureTimeoutSeconds || 10),
      expansions: Array.isArray(rawSetup.expansions)
        ? rawSetup.expansions
        : ['hidden-heroes', 'tools', 'players-choice']
    };
    if (numPlayers < GAME_META.minPlayers || numPlayers > GAME_META.maxPlayers) {
      ctx.throw(400, `numPlayers must be ${GAME_META.minPlayers}..${GAME_META.maxPlayers}`);
      return;
    }
    const { id } = await createNewMatch({ numPlayers, setupData, botCount });
    ctx.body = { matchID: id, setupData };
  });

  // Add an AI bot to an empty seat in an open match.
  router.post('/matches/:id/bot', async (ctx) => {
    const id = String(ctx.params.id || '').toUpperCase();
    const res = await addBotToMatch(id);
    if (!res.ok) { ctx.throw(400, res.error); return; }
    ctx.body = res;
  });

  // Remove an AI bot seat from a match.
  router.delete('/matches/:id/bot/:seatId', async (ctx) => {
    const id = String(ctx.params.id || '').toUpperCase();
    const seatId = Number(ctx.params.seatId);
    const res = await removeBotFromMatch(id, seatId);
    if (!res.ok) { ctx.throw(400, res.error); return; }
    ctx.body = res;
  });

  // Join a match (takes a free seat automatically). Code is case-insensitive.
  router.post('/matches/:id/join', async (ctx) => {
    const playerName = (ctx.request.body.playerName || '').toString().trim();
    if (!playerName) { ctx.throw(400, 'playerName is required'); return; }
    const id = String(ctx.params.id || '').toUpperCase();
    const res = await joinMatchSeat(id, playerName);
    if (!res.ok) { ctx.throw(409, res.error); return; }
    ctx.body = { playerID: res.playerID, credentials: res.credentials };
  });

  // Leave a match (releases the seat; match is wiped if no human remains).
  router.post('/matches/:id/leave', async (ctx) => {
    const playerID = ctx.request.body.playerID;
    const credentials = ctx.request.body.credentials;
    const id = String(ctx.params.id || '').toUpperCase();
    const res = await leaveMatchSeat(id, playerID, credentials);
    if (!res.ok) { ctx.throw(403, res.error); return; }
    ctx.body = { emptied: res.emptied };
  });

  // --- REST bridge for native clients (Godot, friends-only polling) ---------
  // Same seats/credentials as Socket.IO, plain JSON, no socket needed.

  // Filtered state + legal moves for one seat.
  router.get('/matches/:id/state', async (ctx) => {
    const id = String(ctx.params.id || '').toUpperCase();
    const row = await fetchMatch(id);
    if (!row) { ctx.throw(404, 'match not found'); return; }
    if (!checkSeat(row, ctx.query.playerID, ctx.query.credentials)) {
      ctx.throw(403, 'invalid credentials'); return;
    }
    const match = await loadMatch(id);
    if (!match) { ctx.throw(404, 'match not found'); return; }
    const pid = Number(ctx.query.playerID);
    const timerInfo = getMatchTimerInfo(match);
    ctx.body = {
      id, status: match.status, seats: publicSeats(row),
      G: playerView(match.G, pid), ctx: match.ctx,
      moves: legalMoves(match.G, match.ctx, pid),
      turnDeadline: timerInfo.turnDeadline,
      timer: timerInfo,
    };
  });

  // Submit one move, returns the fresh filtered state + moves.
  router.post('/matches/:id/move', async (ctx) => {
    const id = String(ctx.params.id || '').toUpperCase();
    const { playerID, credentials, move } = ctx.request.body || {};
    const row = await fetchMatch(id);
    if (!row) { ctx.throw(404, 'match not found'); return; }
    if (!checkSeat(row, playerID, credentials)) {
      ctx.throw(403, 'invalid credentials'); return;
    }
    if (!move || typeof move.type !== 'string') { ctx.throw(400, 'move.type is required'); return; }
    const res = submitMove(id, Number(playerID), move);
    if (!res.ok) { ctx.throw(400, res.error); return; }
    const match = await loadMatch(id);
    const pid = Number(playerID);
    const timerInfo = getMatchTimerInfo(match);
    ctx.body = {
      ok: true, status: match.status, seats: publicSeats(row),
      G: playerView(match.G, pid), ctx: match.ctx,
      moves: legalMoves(match.G, match.ctx, pid),
      turnDeadline: timerInfo.turnDeadline,
      timer: timerInfo,
    };
  });

  return router;
}