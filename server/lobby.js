// server/lobby.js - REST API for the lobby: create/list/join/leave matches.
//
// Mounted under /lobby on the Koa app. All responses are JSON.
import Router from '@koa/router';
import koaBody from 'koa-body';
import { GAME_META } from './reducer.js';
import { createNewMatch, joinMatchSeat, leaveMatchSeat } from './matches.js';
import { listMatches, fetchMatch } from './db.js';

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
    ctx.body = rows.map(r => ({
      id: r.id,
      gameName: r.game_name,
      numPlayers: r.num_players,
      status: r.status,
      winner: r.winner,
      seats: (r.seats || []).map(s => ({
        id: s.id,
        name: s.name || null,
        isBot: !!s.isBot
      })),
      createdAt: r.created_at,
      updatedAt: r.updated_at
    }));
  });

  // Get one match.
  router.get('/matches/:id', async (ctx) => {
    const row = await fetchMatch(ctx.params.id);
    if (!row) { ctx.throw(404, 'match not found'); return; }
    ctx.body = {
      id: row.id,
      gameName: row.game_name,
      numPlayers: row.num_players,
      status: row.status,
      winner: row.winner,
      seats: (row.seats || []).map(s => ({ id: s.id, name: s.name || null, isBot: !!s.isBot })),
      createdAt: row.created_at,
      updatedAt: row.updated_at
    };
  });

  // Create a new match.
  router.post('/matches', async (ctx) => {
    const numPlayers = Number(ctx.request.body.numPlayers) || 2;
    const setupData = ctx.request.body.setupData || {};
    if (numPlayers < GAME_META.minPlayers || numPlayers > GAME_META.maxPlayers) {
      ctx.throw(400, `numPlayers must be ${GAME_META.minPlayers}..${GAME_META.maxPlayers}`);
      return;
    }
    const { id } = await createNewMatch({ numPlayers, setupData });
    ctx.body = { matchID: id };
  });

  // Join a match (takes a free seat automatically).
  router.post('/matches/:id/join', async (ctx) => {
    const playerName = (ctx.request.body.playerName || '').toString().trim();
    if (!playerName) { ctx.throw(400, 'playerName is required'); return; }
    const res = await joinMatchSeat(ctx.params.id, playerName);
    if (!res.ok) { ctx.throw(409, res.error); return; }
    ctx.body = { playerID: res.playerID, credentials: res.credentials };
  });

  // Leave a match (releases the seat; match is wiped if no human remains).
  router.post('/matches/:id/leave', async (ctx) => {
    const playerID = ctx.request.body.playerID;
    const credentials = ctx.request.body.credentials;
    if (playerID == null) { ctx.throw(400, 'playerID is required'); return; }
    const res = await leaveMatchSeat(ctx.params.id, playerID, credentials);
    if (!res.ok) { ctx.throw(403, res.error); return; }
    ctx.body = { emptied: res.emptied };
  });

  return router;
}