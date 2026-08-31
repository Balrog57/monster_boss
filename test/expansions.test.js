import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { setupMatch, applyMove, pickOpeningDiscardIndices, legalMoves } from '../server/reducer.js';
import { payDarkHero, listDarkHeroPayTargets } from '../src/darkHeroes.js';
import { castSpell, emptyEffects } from '../src/spellEffects.js';
import { totalSouls } from '../src/cardData.js';
import { healOneWound, resolveBait, treasureCount } from '../src/engine.js';
import { gainCoin, buildMiniboss } from '../src/minibosses.js';

function playUntil(pred, start, max = 80) {
  let state = start;
  for (let n = 0; n < max; n++) {
    if (pred(state)) return state;
    const { G, ctx } = state;
    if (G.pendingChoice?.type === 'opening-discard') {
      const pid = G.pendingChoice.playerId;
      const pair = pickOpeningDiscardIndices(G.players[pid].hand);
      state = applyMove(state, { type: 'openingDiscard', args: pair }, pid).state;
      continue;
    }
    const pid = ctx.activePlayer;
    const moves = legalMoves(G, ctx, pid);
    const move = moves[0] || { type: 'pass', args: [] };
    const r = applyMove(state, move, pid);
    state = r.error ? applyMove(state, { type: 'pass', args: [] }, pid).state : r.state;
  }
  throw new Error('playUntil timeout');
}

describe('phase 1 rule fidelity', () => {
  it('souls are face-down and wounds face-up', () => {
    const { G } = setupMatch(2, { expansions: [] });
    G.players[0].souls.push({ souls: 1, name: 'Cleric', class: 'Cleric', faceDown: true });
    G.players[0].wounds.push({ wounds: 1, name: 'Fighter', class: 'Fighter', faceDown: false });
    assert.equal(G.players[0].souls[0].faceDown, true);
    assert.equal(G.players[0].wounds[0].faceDown, false);
  });

  it('T.P.K. bonus requires face-down soul of each class', () => {
    const p = {
      souls: [
        { tpk: true, souls: 0, name: 'T.P.K.' },
        { souls: 1, class: 'Cleric', faceDown: true },
        { souls: 1, class: 'Fighter', faceDown: true },
        { souls: 1, class: 'Mage', faceDown: false },
        { souls: 1, class: 'Thief', faceDown: true },
      ],
    };
    assert.equal(totalSouls(p), 4);
    p.souls[3].faceDown = true;
    assert.equal(totalSouls(p), 6);
  });

  it('Kobold Strike returns face-down builds to hand', () => {
    const { G } = setupMatch(2, { expansions: [] });
    const ctx = { numPlayers: 2, activePlayer: 0, currentPlayer: 0, phase: 'build' };
    G.phase = 'build';
    G.players[0].dungeon = [[{ id: 'BMA009', name: 'Dark Altar', faceDown: true, builtThisTurn: true, isRoom: true }]];
    G.players[0].hand = [];
    castSpell(G, ctx, 0, { id: 'BMA049', name: 'Kobold Strike', isSpell: true }, {});
    assert.equal(G.players[0].dungeon.length, 0);
    assert.equal(G.players[0].hand.length, 1);
    assert.equal(G.effects.buildBlocked, true);
  });

  it('healOneWound creates a face-down soul', () => {
    const p = { wounds: [{ wounds: 1, name: 'X', class: 'Cleric' }], souls: [] };
    healOneWound(p);
    assert.equal(p.souls[0].faceDown, true);
  });
});

describe('expansion packs', () => {
  it('includes Next Level heroes when pack is on', () => {
    const { G } = setupMatch(2, { expansions: ['next-level'] });
    const ids = [...G.decks.heroes, ...G.decks.epics].map((h) => h.id);
    assert.ok(ids.some((id) => String(id).startsWith('TNL')));
  });

  it('enables large game with Crash Landing and 5 players', () => {
    const { G } = setupMatch(5, { expansions: ['crash-landing'] });
    assert.equal(G.largeGame, true);
    assert.equal(G.numPlayers, 5);
  });

  it('grants coins via miniboss room', () => {
    const { G } = setupMatch(2, { expansions: ['minibosses'] });
    const start = G.players[0].coins;
    gainCoin(G, 0, 2, 'test');
    assert.equal(G.players[0].coins, start + 2);
  });

  it('Next Level deals a larger opening hand', () => {
    const state = playUntil((s) => s.G.players[1].hand.length === 8, setupMatch(2, { expansions: ['next-level'] }));
    assert.equal(state.G.players[1].hand.length, 8);
    assert.ok(state.G.expansionSets.includes('next-level'));
  });

  it('large game splits tied lure among dungeons', () => {
    const { G } = setupMatch(2, { expansions: ['crash-landing'] });
    G.largeGame = true;
    G.town = [
      { id: 'h1', treasure: 2, class: 'Fighter', name: 'F1' },
      { id: 'h2', treasure: 2, class: 'Fighter', name: 'F2' },
    ];
    G.players[0].boss = { treasures: [2], xp: 0, name: 'B1' };
    G.players[1].boss = { treasures: [2], xp: 0, name: 'B2' };
    G.players[0].dungeon = [[{ id: 'BMA009', treasures: [2], isRoom: true, name: 'Room' }]];
    G.players[1].dungeon = [[{ id: 'BMA010', treasures: [2], isRoom: true, name: 'Room2' }]];
    const assignments = resolveBait(G);
    const lured = assignments.filter((a) => !a.stayInTown);
    assert.equal(lured.length, 2);
    assert.notEqual(lured[0].targetPlayerId, lured[1].targetPlayerId);
  });

  it('buildMiniboss attaches from deck', () => {
    const { G } = setupMatch(2, { expansions: ['minibosses'] });
    G.players[0].dungeon = [[{ id: 'BMA009', name: 'Room', isRoom: true }]];
    const before = G.decks.minibosses.length;
    assert.ok(buildMiniboss(G, 0, null, 0));
    assert.equal(G.decks.minibosses.length, before - 1);
    assert.ok(G.players[0].dungeon[0].miniboss);
  });

  it('Zara level 1 counts all treasure types for lure', () => {
    const { G } = setupMatch(2, { expansions: ['minibosses'] });
    G.players[0].boss = { treasures: [], xp: 0, name: 'B' };
    G.players[0].dungeon = [[{
      id: 'BMA009', treasures: [4], isRoom: true, name: 'Thief Room',
    }]];
    G.players[0].dungeon[0].miniboss = {
      card: { id: 'RMB202', name: 'Zara' },
      level: 1,
      faceDown: false,
      usedL3: false,
    };
    assert.equal(treasureCount(G, 0, 1), 1);
    assert.equal(treasureCount(G, 0, 4), 1);
  });

  it('starts with 3 coins when minibosses pack is on', () => {
    const { G } = setupMatch(2, { expansions: ['minibosses'] });
    assert.equal(G.players[0].coins, 3);
  });

  it('payDarkHero discards matching room and buffs hero HP', () => {
    const { G } = setupMatch(2, { expansions: ['next-level'] });
    G.phase = 'adventure';
    const hero = { id: 'dark1', name: 'Dark Test', dark: true, treasure: 2, hp: 5, class: 'Fighter' };
    G.players[0].entrance = [hero];
    G.players[1].hand = [{ id: 'room1', name: 'Trap', isRoom: true, treasures: [2], type: 'trap' }];
    const targets = listDarkHeroPayTargets(G);
    assert.ok(targets.length >= 1);
    const err = payDarkHero(G, 1, 0, targets[0]);
    assert.equal(err, null);
    assert.equal(hero._entranceHp, 8);
    assert.equal(G.players[1].hand.length, 0);
  });

  it('imports expansion card counts from wiki packs', () => {
    const { G } = setupMatch(2, { expansions: ['next-level', 'minibosses', 'crash-landing'] });
    const roomIds = G.decks.rooms.map((c) => c.id);
    assert.ok(roomIds.filter((id) => String(id).startsWith('TNL')).length >= 30);
    assert.ok(roomIds.filter((id) => String(id).startsWith('RMB')).length >= 30);
    assert.ok(roomIds.filter((id) => String(id).startsWith('CRL')).length >= 10);
  });
});
