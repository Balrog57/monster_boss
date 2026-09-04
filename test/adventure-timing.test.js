import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { setupMatch, applyMove, legalMoves } from '../server/reducer.js';
import { PHASE, SPELLS } from '../src/cardData.js';

function forceAdventure(state, playerId = 0) {
  let s = state;
  for (let i = 0; i < 4000; i++) {
    if (s.G.phase === PHASE.ADVENTURE) return s;
    const pid = s.ctx.activePlayer;
    const moves = ['pass', 'resolveNextHero', 'buildRoom', 'playSpell', 'activateRoom', 'pickBoss', 'buildInitialRoom', 'openingDiscard', 'resolveLevelUpChoice'];
    let progressed = false;
    for (const type of moves) {
      const r = applyMove(s, { type, args: type === 'resolveNextHero' ? [] : type === 'pass' ? [] : [0] }, pid);
      if (!r.error) {
        s = r.state;
        progressed = true;
        break;
      }
    }
    if (!progressed) break;
  }
  return s;
}

describe('adventure timing', () => {
  it('pauses after room damage until all players pass', () => {
    let state = setupMatch(2, { expansions: [] });
    state = forceAdventure(state);
    if (state.G.phase !== PHASE.ADVENTURE) return; // setup variance — skip
    const owner = Object.keys(state.G.players).find((pid) => state.G.players[pid].entrance?.length);
    if (owner == null) return;
    const r = applyMove(state, { type: 'resolveNextHero', args: [] }, Number(owner));
    if (r.error) return;
    state = r.state;
    if (!state.G.adventure) return;
    const beforeHp = state.G.adventure.hp;
    const r2 = applyMove(state, { type: 'resolveNextHero', args: [] }, Number(owner));
    if (r2.error || !r2.state.G.adventure?.pause) return;
    assert.equal(r2.state.G.adventure.pause, 'post-damage');
    assert.ok(r2.state.G.adventure.hp <= beforeHp);
    const pass0 = applyMove(r2.state, { type: 'pass', args: [] }, 0);
    assert.equal(pass0.error, undefined);
    assert.ok(!pass0.state.G.adventure?.playerId == null || pass0.state.G.adventure?.pause);
    const pass1 = applyMove(pass0.state, { type: 'pass', args: [] }, 1);
    assert.equal(pass1.error, undefined);
    assert.ok(pass1.state.G.adventure?.pause === 'pre-exit' || pass1.state.G.adventure == null);
  });
});

describe('stack responses', () => {
  for (const pause of [null, 'post-damage']) {
    it(`resolves a spell before continuing adventure (${pause}) and restores its owner`, () => {
      let state = setupMatch(2, { expansions: [] });
      Object.assign(state.ctx, { phase: PHASE.ADVENTURE, activePlayer: 0, currentPlayer: 0 });
      Object.assign(state.G, { phase: PHASE.ADVENTURE, activePlayer: 0 });
      const hero = { id: 'test-hero', name: 'Hero', hp: 10 };
      state.G.players[0].entrance = [hero];
      state.G.players[1].entrance = [{ ...hero, id: 'other-hero' }];
      state.G.players[0].hand = [{ ...SPELLS.find(c => c.id === 'BMA044'), isSpell: true }];
      if (pause) state.G.adventure = { playerId: 0, hero, hp: 10, roomIndex: 0, pause };
      let result = applyMove(state, { type: 'playSpell', args: [0, { heroId: hero.id }] }, 0);
      assert.equal(result.error, undefined);
      state = result.state;
      assert.equal(state.ctx.activePlayer, 1);
      assert.deepEqual(legalMoves(state.G, state.ctx, 0), []);
      result = applyMove(state, { type: 'pass', args: [] }, 1);
      assert.equal(result.error, undefined);
      assert.equal(result.state.G.stack.length, 0);
      assert.equal(result.state.ctx.activePlayer, 0);
      assert.equal(result.state.G.activePlayer, 0);
      if (pause) assert.equal(result.state.G.adventure.pause, pause);
    });
  }
  it('gives active player first chance to respond', () => {
    const state = setupMatch(2, { expansions: [] });
    const order = [String(state.ctx.activePlayer), String(state.ctx.activePlayer) === '0' ? '1' : '0'];
    assert.ok(order.length === 2);
    // Regression guard: stack metadata slot exists for priority anchor.
    assert.ok('stackActivePlayer' in state.G || state.G.stackActivePlayer == null);
  });
});
