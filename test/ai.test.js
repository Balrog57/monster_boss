import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { setupMatch, legalMoves } from '../server/reducer.js';
import { aiPickMove, aiChooseBoss } from '../src/ai.js';

describe('ai', () => {
  it('only returns a legal move', () => {
    const { G, ctx } = setupMatch(2, { expansions: [] });
    const moves = legalMoves(G, ctx, ctx.activePlayer);
    const pick = aiPickMove(G, ctx, ctx.activePlayer);
    assert.ok(pick);
    assert.ok(moves.some((m) => m.type === pick.type && JSON.stringify(m.args) === JSON.stringify(pick.args)));
  });

  it('picks the highest-XP boss', () => {
    const bosses = [
      { id: 'BMA004', xp: 400 },
      { id: 'BMA001', xp: 900 },
    ];
    assert.equal(aiChooseBoss(bosses).id, 'BMA001');
  });

  it('prefers passing over a useless room activation', () => {
    const { G, ctx } = setupMatch(2, { expansions: [] });
    G.phase = 'build';
    ctx.phase = 'build';
    ctx.activePlayer = 0;
    G.activePlayer = 0;
    G.players[0].boss = { id: 'BMA001', xp: 900, treasures: [1] };
    G.players[0].dungeon = [[{ id: 'BMA025', name: 'All-Seeing Eye', type: 'trap', isRoom: true }]];
    G.players[0].hand = [{ id: 'BMA010', name: 'Open Grave', isRoom: true, advanced: false, treasures: [4], damage: 2 }];
    G.players[0].buildsThisTurn = 1;
    G.stack = [];
    const moves = legalMoves(G, ctx, 0);
    assert.ok(moves.some((m) => m.type === 'pass'));
    assert.ok(!moves.some((m) => m.type === 'activateRoom'));
    const pick = aiPickMove(G, ctx, 0);
    assert.equal(pick.type, 'pass');
  });
});
