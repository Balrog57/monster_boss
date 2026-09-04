import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { setupMatch, legalMoves, applyMove } from '../server/reducer.js';
import { aiPickMove, aiChooseBoss } from '../src/ai.js';

describe('ai', () => {
  for (const expansions of [[], null]) {
    for (let seed = 1; seed <= 20; seed++) {
      it(`finishes seed ${seed}, ${expansions ? 'base' : 'all expansions'}, without rejected moves`, (t) => {
        let rng = seed;
        t.mock.method(Math, 'random', () => ((rng = (Math.imul(rng, 1664525) + 1013904223) >>> 0) / 4294967296));
        let state = setupMatch(2, { expansions, humanCount: 0 });
        for (let step = 0; step < 4000 && !state.G.gameOver; step++) {
          const { G, ctx } = state;
          let pid = G.pendingChoice?.playerId ?? ctx.activePlayer;
          if (!G.pendingChoice && !G.stack?.length && G.adventure?.pause) {
            pid = Object.keys(G.players).find(id => !G.players[id].eliminated && !G.adventurePausePassed?.[id]);
          }
          const move = aiPickMove(G, ctx, pid);
          assert.ok(move, `no move: ${G.phase}, player ${pid}`);
          const result = applyMove(state, move, pid);
          assert.equal(result.error, undefined, `${G.phase} ${JSON.stringify(move)}: ${result.error}`);
          state = result.state;
        }
        assert.equal(state.G.gameOver, true, `unfinished at turn ${state.G.turn}, ${state.G.phase}`);
        assert.ok([0, 1].includes(state.G.winner));
      });
    }
  }
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
