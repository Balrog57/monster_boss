import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { setupMatch, applyMove, legalMoves, playerView } from '../../src/backend/game/reducer.js';
import { encodeState, decodeState, stringifyState, parseState } from '../../src/backend/game/stateCodec.js';
import * as db from '../../src/backend/server/db.js';
import {
  attachMiniboss, canPromoteMiniboss, canBuildMiniboss, clearMinibossTurnFlags,
  promoteMiniboss as rawPromote,
} from '../../src/backend/game/minibosses.js';
import { spellsBlockedFor } from '../../src/backend/game/items.js';

const SPIKE = { id: 'RMB055', name: 'Spike', isRoom: true, type: 'monster' };
const COUNTERSPELL = { id: 'BMA043', name: 'Counterspell', isSpell: true };
const RING = { id: 'THK020', name: 'Ring of Invisibility' };

/** Build-phase state with a revealed Miniboss under player 0's only room. */
function minibossState() {
  const state = setupMatch(2, { expansions: ['minibosses'] });
  const { G, ctx } = state;
  G.pendingChoice = null;
  G.choiceQueue = [];
  G.phase = 'build';
  G.activePlayer = 0;
  ctx.activePlayer = 0;
  ctx.currentPlayer = 0;
  G.players[0].dungeon = [[{ id: 'r1', name: 'Hall of Blades', type: 'monster', damage: 2, treasures: [2] }]];
  attachMiniboss(G.players[0].dungeon[0], SPIKE);
  G.players[0].dungeon[0].miniboss.faceDown = false;
  G.players[0].coins = 3;
  G.players[0].passed = false;
  G.players[1].dungeon = [[{ id: 'r2', name: 'Crypt', type: 'trap', damage: 1, treasures: [1] }]];
  G.players[1].coins = 3;
  return state;
}

function minibossOf(state, pid = 0) {
  return state.G.players[pid].dungeon[0].miniboss;
}

describe('state codec — properties attached to array stacks', () => {
  it('documents the hazard: plain JSON drops .miniboss', () => {
    const { G } = minibossState();
    const stack = G.players[0].dungeon[0];
    assert.ok(stack.miniboss, 'miniboss attached to the stack array');
    const plain = JSON.parse(JSON.stringify(stack));
    assert.equal(plain.miniboss, undefined);
  });

  it('encodeState/decodeState round trip keeps .miniboss', () => {
    const { G } = minibossState();
    const decoded = decodeState(encodeState(G));
    const stack = decoded.players[0].dungeon[0];
    assert.ok(Array.isArray(stack), 'dungeon stack is still an array');
    assert.ok(stack.miniboss, 'miniboss survived encode/decode');
    assert.equal(stack.miniboss.card.id, 'RMB055');
    assert.equal(stack.miniboss.level, 1);
    assert.equal(stack.miniboss.faceDown, false);
  });

  it('stringifyState/parseState (Postgres column) keeps .miniboss', () => {
    const { G } = minibossState();
    const text = stringifyState(G);
    assert.equal(typeof text, 'string');
    const decoded = parseState(text);
    assert.ok(decoded.players[0].dungeon[0].miniboss);
    // Postgres parses the text into a jsonb document; pg hands it back as JSON text.
    const fromDb = parseState(JSON.stringify(JSON.parse(text)));
    assert.ok(fromDb.players[0].dungeon[0].miniboss);
  });

  it('match storage round trip keeps .miniboss', async () => {
    const state = minibossState();
    const id = `codec-test-${process.pid}-${Date.now()}`;
    await db.createMatch({ id, gameName: 'monster_boss', numPlayers: 2, state: state.G, ctx: state.ctx });
    const row = await db.fetchMatch(id);
    assert.ok(row);
    // The row is JSON on the wire (and a jsonb document in Postgres).
    const wireRow = JSON.parse(JSON.stringify(row));
    const loaded = typeof wireRow.state === 'string' ? parseState(wireRow.state) : decodeState(wireRow.state);
    assert.ok(loaded.players[0].dungeon[0].miniboss, 'miniboss survives save + reload');

    const next = minibossState();
    await db.saveMatchState(id, { state: next.G, ctx: next.ctx });
    const row2 = JSON.parse(JSON.stringify(await db.fetchMatch(id)));
    const loaded2 = typeof row2.state === 'string' ? parseState(row2.state) : decodeState(row2.state);
    assert.ok(loaded2.players[0].dungeon[0].miniboss, 'miniboss survives second save + reload');
    await db.wipeMatch(id);
  });

  it('socket payload (encode + JSON transport + decode) keeps .miniboss', () => {
    const { G } = minibossState();
    for (const pid of [0, 1]) {
      const wire = JSON.parse(JSON.stringify(encodeState(playerView(G, pid))));
      const client = decodeState(wire);
      assert.ok(client.players[0].dungeon[0].miniboss, `player ${pid} view keeps the miniboss`);
      assert.equal(client.players[0].dungeon[0].miniboss.card.id, 'RMB055');
    }
  });

  it('applyMove clones without losing the miniboss', () => {
    const state = minibossState();
    const promote = legalMoves(state.G, state.ctx, 0).find((m) => m.type === 'promoteMiniboss');
    assert.ok(promote, 'promote offered in the Build phase');
    const res = applyMove(state, promote, 0);
    assert.equal(res.error, undefined, res.error);
    const stack = res.state.G.players[0].dungeon[0];
    assert.ok(stack.miniboss, 'miniboss survives the applyMove clone');
    assert.equal(stack.miniboss.level, 2);
    assert.equal(res.state.G.players[0].coins, 2);
  });
});

describe('miniboss promotion rules', () => {
  it('can only promote during the Build phase', () => {
    const { G } = minibossState();
    assert.equal(canPromoteMiniboss(G, 0, 0), true);

    G.phase = 'adventure';
    G.activePlayer = 0;
    assert.equal(canPromoteMiniboss(G, 0, 0), false);
    assert.equal(rawPromote(G, 0, 0), 'promote only during the Build phase');
    assert.equal(canBuildMiniboss(G, 1), false);
  });

  it('offers exactly one promotion per turn', () => {
    const state = minibossState();
    const { G, ctx } = state;
    const first = legalMoves(G, ctx, 0).find((m) => m.type === 'promoteMiniboss');
    assert.ok(first);
    const res = applyMove(state, first, 0);
    assert.equal(res.error, undefined, res.error);
    assert.equal(res.state.G.players[0].dungeon[0].miniboss.level, 2);

    // The action rotates the active player; come back to player 0 as the turn cycle does.
    res.state.G.activePlayer = 0;
    res.state.ctx.activePlayer = 0;
    res.state.ctx.currentPlayer = 0;

    assert.equal(canPromoteMiniboss(res.state.G, 0, 0), false, 'flag blocks a second promotion');
    assert.equal(
      legalMoves(res.state.G, res.state.ctx, 0).find((m) => m.type === 'promoteMiniboss'),
      undefined,
      'no second promotion offered in the same turn',
    );
    const again = applyMove(res.state, { type: 'promoteMiniboss', args: [0] }, 0);
    assert.match(again.error || '', /already promoted/);
    assert.equal(rawPromote(res.state.G, 0, 0), 'already promoted this turn');

    clearMinibossTurnFlags(res.state.G);
    assert.equal(canPromoteMiniboss(res.state.G, 0, 0), true, 'flag resets at the beginning of the turn');
  });

  it('builds a Miniboss only during the Build phase', () => {
    const state = minibossState();
    const { G } = state;
    assert.equal(canBuildMiniboss(G, 1), true, 'player 1 has a room and no miniboss yet');
    G.phase = 'adventure';
    assert.equal(canBuildMiniboss(G, 1), false);
    G.phase = 'build';
    G.players[1].buildsThisTurn = 1;
    assert.equal(canBuildMiniboss(G, 1), false, 'one build per turn');
  });
});

describe('spell response window', () => {
  function stackState() {
    const state = setupMatch(2, { expansions: ['tools'] });
    const { G, ctx } = state;
    G.pendingChoice = null;
    G.choiceQueue = [];
    G.phase = 'adventure';
    G.activePlayer = 0;
    ctx.activePlayer = 0;
    G.players[0].hand = [{ ...COUNTERSPELL }];
    G.stack = [{
      id: 'stack-1', type: 'spell', playerId: 1,
      card: { id: 'BMA048', name: 'Fireball', isSpell: true },
      target: null, resolved: false,
    }];
    G.stackPassed = {};
    return state;
  }

  it('offers a counterspell while no Ring of Invisibility is in play', () => {
    const { G, ctx } = stackState();
    assert.equal(spellsBlockedFor(G, 0), false);
    assert.ok(legalMoves(G, ctx, 0).some((m) => m.type === 'playSpell'));
  });

  it('blocks the counterspell for a player whose hero carries the Ring', () => {
    const { G, ctx } = stackState();
    G.players[0].entrance = [{ id: 'hero-1', name: 'Scout', item: { ...RING } }];
    assert.equal(spellsBlockedFor(G, 0), true);
    const moves = legalMoves(G, ctx, 0);
    assert.ok(!moves.some((m) => m.type === 'playSpell'), 'no spell offered under the Ring');
    assert.ok(moves.some((m) => m.type === 'pass'), 'the window can still be passed');
  });
});
