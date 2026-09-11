import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { setupMatch, applyMove } from '../server/reducer.js';
import { canBuildRoom, destroyRoom, buildRoom, checkEndGame } from '../src/engine.js';
import { onExpansionBossKill } from '../src/expansionBosses.js';
import { castSpell } from '../src/spellEffects.js';

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

  it('buildRoom over an existing room does not push covered room to roomDiscard', () => {
    const { G } = setupMatch(2);
    const p = G.players[0];
    const baseRoom = { id: 'BMA001', name: 'Base', type: 'monster', treasures: [1], isRoom: true, advanced: false };
    const advRoom = { id: 'BMA008', name: 'Adv', type: 'monster', treasures: [1], isRoom: true, advanced: true };
    p.dungeon = [[baseRoom]];
    p.hand = [advRoom];
    G.decks.roomDiscard = [];
    const ok = buildRoom(G, 0, 0, 0);
    assert.equal(ok, true);
    assert.equal(p.dungeon[0].length, 2);
    assert.equal(p.dungeon[0][0].id, 'BMA001');
    assert.equal(p.dungeon[0][1].id, 'BMA008');
    assert.equal(G.decks.roomDiscard.length, 0);
  });

  it('checkEndGame breaks ties by souls - wounds first, then lowest boss XP', () => {
    // Both reach 10 souls, different net score
    const G1 = {
      players: {
        0: { boss: { xp: 400 }, souls: Array(10).fill({ souls: 1 }), wounds: Array(2).fill({ wounds: 1 }), eliminated: false },
        1: { boss: { xp: 300 }, souls: Array(10).fill({ souls: 1 }), wounds: [], eliminated: false },
      },
    };
    const res1 = checkEndGame(G1);
    assert.equal(res1.gameOver, true);
    assert.equal(res1.winner, 1);

    // Both reach 10 souls, same net score, lowest XP wins
    const G2 = {
      players: {
        0: { boss: { xp: 500 }, souls: Array(10).fill({ souls: 1 }), wounds: [{ wounds: 1 }], eliminated: false },
        1: { boss: { xp: 200 }, souls: Array(10).fill({ souls: 1 }), wounds: [{ wounds: 1 }], eliminated: false },
      },
    };
    const res2 = checkEndGame(G2);
    assert.equal(res2.gameOver, true);
    assert.equal(res2.winner, 1);

    // All players eliminated (5 wounds)
    const G3 = {
      players: {
        0: { boss: { xp: 500 }, souls: Array(4).fill({ souls: 1 }), wounds: Array(5).fill({ wounds: 1 }), eliminated: false },
        1: { boss: { xp: 200 }, souls: Array(6).fill({ souls: 1 }), wounds: Array(5).fill({ wounds: 1 }), eliminated: false },
      },
    };
    const res3 = checkEndGame(G3);
    assert.equal(res3.gameOver, true);
    assert.equal(res3.winner, 1);
  });

  it('Fear spell removes exploring hero from entrance to avoid hero cloning', () => {
    const hero = { id: 'BMH001', name: 'Cleric Hero', hp: 4 };
    const G = {
      town: [],
      logs: [],
      adventure: { playerId: 0, hero, hp: 4, roomIndex: 0 },
      players: {
        0: { entrance: [hero], souls: [], wounds: [] },
      },
    };
    const ok = castSpell(G, {}, 0, { id: 'BMA045', name: 'Fear' }, { heroId: 'BMH001' });
    assert.equal(ok, true);
    assert.equal(G.adventure, null);
    assert.equal(G.players[0].entrance.length, 0);
    assert.equal(G.town.length, 1);
    assert.equal(G.town[0].id, 'BMH001');
  });

  it('allows pass in adventure phase when all entrance heroes are blocked', () => {
    const { G, ctx } = setupMatch(2);
    G.phase = 'adventure';
    ctx.phase = 'adventure';
    G.activePlayer = 0;
    ctx.activePlayer = 0;
    const hero = { id: 'BMH001', name: 'Blocked Hero', hp: 4, _blockedUntilNextTurn: true };
    G.players[0].entrance = [hero];
    G.adventure = null;
    const { state, error } = applyMove({ G, ctx }, { type: 'pass', args: [] }, 0);
    assert.ok(!error, error);
    assert.equal(state.ctx.activePlayer, 1);
  });
});
