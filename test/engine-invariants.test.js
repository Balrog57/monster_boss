import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { setupMatch, applyMove } from '../server/reducer.js';
import { canBuildRoom, destroyRoom } from '../src/engine.js';
import { onExpansionBossKill } from '../src/expansionBosses.js';

describe('engine invariants', () => {
  it('uses _entranceHp when hero enters dungeon', () => {
    const { G, ctx } = setupMatch(2, { expansions: ['minibosses'] });
    const p = G.players[0];
    p.boss = G.bossPicks[0];
    G.players[1].boss = G.bossPicks[1];
    p.dungeon = [[{
      id: 'BMA001', name: 'Room', type: 'monster', damage: 1, treasures: [1], isRoom: true,
    }]];
    const hero = { id: 'BMH001', name: 'Test', hp: 5, class: 'Fighter', treasure: 2 };
    hero._entranceHp = 2;
    p.entrance = [hero];
    G.phase = 'adventure';
    ctx.phase = 'adventure';
    G.activePlayer = 0;
    ctx.activePlayer = 0;
    const { state, error } = applyMove({ G, ctx }, { type: 'resolveNextHero', args: [] }, 0);
    assert.ok(!error, error);
    assert.ok(state.G.adventure);
    assert.equal(state.G.adventure.hp, 1);
  });

  it('Hypercube builds over any room', () => {
    const { G } = setupMatch(2, { expansions: ['crash-landing'] });
    const p = G.players[0];
    p.dungeon = [[[{
      id: 'BMA001', name: 'Cleric', type: 'monster', damage: 1, treasures: [1], isRoom: true, advanced: false,
    }]]];
    const hyper = {
      id: 'CRL011', name: 'Hypercube', advanced: true, type: 'trap', damage: 3,
      treasures: [5], isRoom: true,
    };
    p.hand = [hyper];
    assert.equal(canBuildRoom(G, 0, 0, 0), true);
  });

  it('discards miniboss when host stack is destroyed', () => {
    const { G } = setupMatch(2, { expansions: ['minibosses'] });
    const p = G.players[0];
    const room = { id: 'BMA001', name: 'R', type: 'monster', damage: 1, treasures: [1] };
    p.dungeon = [[room]];
    p.dungeon[0].miniboss = { card: { id: 'RMB201', name: 'Gruk' }, level: 1, faceDown: false };
    G.decks.minibossDiscard = [];
    destroyRoom(G, 0, 0);
    assert.equal(p.dungeon.length, 0);
    assert.equal(G.decks.minibossDiscard.length, 1);
  });

  it('Gregore grants coin on hero kill', () => {
    const { G } = setupMatch(2, { expansions: ['minibosses'] });
    G.players[0].gregoreCoin = true;
    G.players[0].coins = 0;
    onExpansionBossKill(G, 0);
    assert.equal(G.players[0].coins, 1);
  });
});
