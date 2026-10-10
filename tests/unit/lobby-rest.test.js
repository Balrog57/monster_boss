import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import Koa from 'koa';
import { createServer } from 'node:http';
import { lobbyRouter } from '../../src/backend/server/lobby.js';

// REST bridge for native clients (Godot friends-only lobby over polling).
let base;
let server;

before(async () => {
  const app = new Koa();
  const router = lobbyRouter();
  app.use(router.routes());
  app.use(router.allowedMethods());
  server = createServer(app.callback());
  await new Promise((r) => server.listen(0, '127.0.0.1', r));
  base = `http://127.0.0.1:${server.address().port}`;
});

after(() => server.close());

async function api(method, path, body, query = '') {
  const res = await fetch(base + path + query, {
    method,
    headers: { 'Content-Type': 'application/json' },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  const text = await res.text();
  let json = null;
  try { json = text ? JSON.parse(text) : null; } catch { /* leave null */ }
  return { status: res.status, json };
}

test('friends lobby: create, join by code, state + move over REST', async () => {
  const created = await api('POST', '/lobby/matches', { numPlayers: 2, setupData: { isPublic: false, expansions: [] } });
  assert.equal(created.status, 200);
  const code = created.json.matchID;
  assert.match(code, /^[A-Z0-9]{6}$/);

  const j0 = await api('POST', `/lobby/matches/${code}/join`, { playerName: 'Alice' });
  assert.equal(j0.status, 200);
  const j1 = await api('POST', `/lobby/matches/${code.toLowerCase()}/join`, { playerName: 'Bob' });
  assert.equal(j1.status, 200);

  // Both seats filled -> match running.
  const info = await api('GET', `/lobby/matches/${code}`);
  assert.equal(info.json.status, 'running');
  assert.deepEqual(info.json.seats.map((s) => s.name), ['Alice', 'Bob']);

  // Filtered state for seat 0: own moves offered, opponent hand hidden later, timer metadata present.
  const s0 = await api('GET', `/lobby/matches/${code}/state`, undefined,
    `?playerID=${j0.json.playerID}&credentials=${j0.json.credentials}`);
  assert.equal(s0.status, 200);
  assert.equal(s0.json.G.phase, 'boss');
  assert.ok(s0.json.moves.some((m) => m.type === 'pickBoss'));
  assert.ok(typeof s0.json.turnDeadline === 'number' && s0.json.turnDeadline > Date.now());
  assert.equal(s0.json.timer.timerEnabled, true);
  assert.equal(s0.json.timer.turnTimeout, 60);

  // Bad credentials are refused.
  const bad = await api('GET', `/lobby/matches/${code}/state`, undefined, '?playerID=0&credentials=nope');
  assert.equal(bad.status, 403);

  // Both pick a boss -> opening hands dealt (setup phase).
  const pick0 = s0.json.G.bossPicks[0].id;
  const m0 = await api('POST', `/lobby/matches/${code}/move`,
    { playerID: j0.json.playerID, credentials: j0.json.credentials, move: { type: 'pickBoss', args: [pick0] } });
  assert.equal(m0.status, 200);

  const s1 = await api('GET', `/lobby/matches/${code}/state`, undefined,
    `?playerID=${j1.json.playerID}&credentials=${j1.json.credentials}`);
  // Picks stay shared; the server refuses a boss taken by another player.
  const other = s1.json.G.bossPicks.map((b) => b.id).find((id) => id !== pick0);
  const m1 = await api('POST', `/lobby/matches/${code}/move`,
    { playerID: j1.json.playerID, credentials: j1.json.credentials, move: { type: 'pickBoss', args: [other] } });
  assert.equal(m1.status, 200);
  assert.equal(m1.json.G.phase, 'setup');
  assert.equal(m1.json.G.players['0'].hand.length + m1.json.G.players['1'].hand.length, 14);
  // Opponent hand is hidden in each filtered view.
  assert.ok(m1.json.G.players['0'].hand.every((c) => c.hidden));

  // Invalid move is a 400, not a crash.
  const badMove = await api('POST', `/lobby/matches/${code}/move`,
    { playerID: j1.json.playerID, credentials: j1.json.credentials, move: { type: 'pickBoss', args: ['ZZZ'] } });
  assert.equal(badMove.status, 400);
});
