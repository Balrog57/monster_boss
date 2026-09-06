import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { setupMatch, applyMove, pickOpeningDiscardIndices, legalMoves } from '../server/reducer.js';
import { payDarkHero, listDarkHeroPayTargets } from '../src/darkHeroes.js';
import { castSpell, emptyEffects } from '../src/spellEffects.js';
import { totalSouls, PHASE } from '../src/cardData.js';
import { healOneWound, resolveBait, treasureCount, roomDamageWithModifiers, canBuildRoom, buildRoom, destroyRoom } from '../src/engine.js';
import { gainCoin, buildMiniboss } from '../src/minibosses.js';
import { onBuildRoom, activateRoomAbility } from '../src/roomAbilities.js';
import { applyTaggedOnHeroSurvive } from '../src/expansionEffects.js';
import { processEndOfTurnRooms, processDreadmills } from '../src/handAbilities.js';

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

describe('expansion room batch', () => {
  it('Haunted Hall returns the hero in its room to town', () => {
    const { G, ctx } = setupMatch(2, { expansions: ['next-level'] });
    Object.assign(G, { phase: PHASE.ADVENTURE, effects: emptyEffects(), town: [] });
    Object.assign(ctx, { phase: PHASE.ADVENTURE, activePlayer: 0 });
    const hero = { id: 'h1', name: 'Cleric', treasure: 1, hp: 4 };
    G.adventure = { playerId: 0, hero, hp: 4, roomIndex: 0 };
    G.players[0].dungeon = [[{ id: 'TNL017', name: 'Haunted Hall', type: 'monster', damage: 2, treasures: [1] }]];
    const err = activateRoomAbility(G, ctx, 0, 0, null);
    assert.equal(err, null);
    assert.equal(G.adventure, null);
    assert.equal(G.town[0].id, 'h1');
    assert.equal(G.players[0].dungeon.length, 0);
  });

  it('Spiked Pit and Decoy Garden apply EOT bonuses on build', () => {
    const { G, ctx } = setupMatch(2, { expansions: ['next-level', 'crash-landing'] });
    G.effects = emptyEffects();
    G.players[0].boss = { id: 'BMA001', name: 'Boss', xp: 100, treasures: [] };
    G.players[0].dungeon = [[{ id: 'TNL044', name: 'Spiked Pit', type: 'trap', damage: 1, treasures: [4] }]];
    onBuildRoom(G, ctx, 0, G.players[0].dungeon[0][0]);
    assert.ok(G.effects.roomDamageBonus.some((e) => e.roomIndex === 0 && e.amount === 3));

    G.players[0].dungeon = [[{ id: 'CRL006', name: 'Decoy Garden', type: 'monster', damage: 1, treasures: [5] }]];
    onBuildRoom(G, ctx, 0, G.players[0].dungeon[0][0]);
    assert.equal(treasureCount(G, 0, 5), 3); // base 1 + Explorer×2
  });

  it('Invasion Swarm and Reactor Core boost adjacent/advanced damage', () => {
    const { G } = setupMatch(2, { expansions: ['crash-landing'] });
    G.effects = emptyEffects();
    G.players[0].boss = { id: 'BMA001', name: 'Boss', xp: 100, treasures: [] };
    G.players[0].dungeon = [
      [{ id: 'CRL008', name: 'Invasion Swarm', type: 'monster', damage: 0, treasures: [5] }],
      [{ id: 'BMA009', name: 'Dark Altar', type: 'monster', damage: 1, treasures: [1], advanced: false }],
      [{ id: 'CRL009', name: 'Reactor Core', type: 'trap', damage: 2, treasures: [5] }],
      [{ id: 'BMA021', name: 'Adv', type: 'monster', damage: 2, treasures: [1], advanced: true }],
    ];
    assert.equal(roomDamageWithModifiers(G, 0, 1, { id: 'h' }), 2); // 1 + adjacent swarm
    assert.equal(roomDamageWithModifiers(G, 0, 3, { id: 'h' }), 3); // 2 + reactor
  });

  it('Alien Ooze and Power Leech apply passive damage bonuses', () => {
    const { G } = setupMatch(2, { expansions: ['crash-landing', 'minibosses'] });
    G.effects = emptyEffects();
    G.players[0].boss = { id: 'BMA001', name: 'Boss', xp: 100, treasures: [] };
    G.players[0].dungeon = [
      [{ id: 'RMB024', name: 'Power Leech', type: 'monster', damage: 1, treasures: [2] }],
      [{ id: 'BMA010', name: 'Monster', type: 'monster', damage: 1, treasures: [2] }],
      [{ id: 'CRL005', name: 'Alien Ooze', type: 'trap', damage: 1, treasures: [5] }],
      [{ id: 'CRL006', name: 'Decoy Garden', type: 'monster', damage: 1, treasures: [5] }],
    ];
    assert.equal(roomDamageWithModifiers(G, 0, 1, { id: 'h' }), 3); // 1 + Power Leech
    assert.equal(roomDamageWithModifiers(G, 0, 2, { id: 'h' }), 2); // 1 + other Explorer
  });

  it('Incubus Gym forces opponents to discard a Room', () => {
    const { G, ctx } = setupMatch(2, { expansions: ['next-level'] });
    G.effects = emptyEffects();
    G.players[0].dungeon = [[{ id: 'TNL019', name: 'Incubus Gym', type: 'monster', damage: 4, treasures: [1] }]];
    G.players[1].hand = [
      { id: 'BMA009', name: 'Dark Altar', isRoom: true, type: 'monster' },
      { id: 'BMA040', name: 'Spell', isSpell: true },
    ];
    onBuildRoom(G, ctx, 0, G.players[0].dungeon[0][0]);
    assert.equal(G.players[1].hand.length, 1);
    assert.equal(G.players[1].hand[0].isSpell, true);
  });

  it('Alien Excavator uncovers a covered Room', () => {
    const { G, ctx } = setupMatch(2, { expansions: ['crash-landing'] });
    G.effects = emptyEffects();
    const covered = { id: 'CRL014', name: 'Caged Gundarf', type: 'monster', damage: 1, treasures: [2, 5] };
    const top = { id: 'CRL004', name: 'Alien Excavator', type: 'trap', damage: 2, treasures: [5] };
    G.players[0].dungeon = [[covered, top]];
    onBuildRoom(G, ctx, 0, top);
    assert.equal(G.players[0].dungeon[0].at(-1).id, 'CRL014');
    assert.ok(G.effects.roomDamageBonus.some((e) => e.roomIndex === 0));
  });

  it('Vampire Lab discards a Miniboss to heal a Wound', () => {
    const { G, ctx } = setupMatch(2, { expansions: ['minibosses'] });
    G.effects = emptyEffects();
    G.players[0].wounds = [{ wounds: 1, name: 'Hero', class: 'Cleric' }];
    G.players[0].souls = [];
    G.players[0].hand = [{ id: 'RMB201', name: 'Mini', isMiniboss: true }];
    G.players[0].dungeon = [[{ id: 'RMB018', name: 'Vampire Lab', type: 'monster', damage: 2, treasures: [1] }]];
    onBuildRoom(G, ctx, 0, G.players[0].dungeon[0][0]);
    assert.equal(G.players[0].wounds.length, 0);
    assert.equal(G.players[0].souls.length, 1);
    assert.equal(G.players[0].hand.length, 0);
  });

  it('Decapitator suppresses room treasure during Build', () => {
    const { G, ctx } = setupMatch(2, { expansions: ['next-level'] });
    Object.assign(G, { phase: PHASE.BUILD, effects: emptyEffects() });
    Object.assign(ctx, { phase: PHASE.BUILD, activePlayer: 0 });
    G.players[0].boss = { id: 'BMA001', name: 'Boss', xp: 100, treasures: [1] };
    G.players[0].dungeon = [
      [{ id: 'TNL045', name: 'Decapitator', type: 'trap', damage: 2, treasures: [4] }],
      [{ id: 'BMA009', name: 'Dark Altar', type: 'monster', damage: 1, treasures: [1] }],
    ];
    assert.equal(treasureCount(G, 0, 1), 2);
    const err = activateRoomAbility(G, ctx, 0, 0, null);
    assert.equal(err, null);
    assert.equal(G.players[0].dungeon.length, 1);
    assert.equal(treasureCount(G, 0, 1), 1); // room treasure suppressed
  });

  it('Hypercube may build over any Room', () => {
    const { G } = setupMatch(2, { expansions: ['crash-landing'] });
    G.effects = emptyEffects();
    G.players[0].buildsThisTurn = 0;
    G.players[0].dungeon = [[{ id: 'BMA009', name: 'Dark Altar', type: 'monster', damage: 1, treasures: [1] }]];
    G.players[0].hand = [{
      id: 'CRL011', name: 'Hypercube', advanced: true, type: 'trap', damage: 4, treasures: [5], isRoom: true,
    }];
    assert.equal(canBuildRoom(G, 0, 0, 0), true);
  });

  it('Goblin Mess Hall / Nursery and spell-hand rooms boost damage', () => {
    const { G } = setupMatch(2, { expansions: ['next-level', 'minibosses'] });
    G.effects = emptyEffects();
    G.players[0].boss = { id: 'BMA001', name: 'Boss', xp: 100, treasures: [] };
    G.players[0].hand = [{ id: 's1', isSpell: true }, { id: 's2', isSpell: true }];
    G.players[0].dungeon = [
      [{ id: 'BMA010', name: 'Monster', type: 'monster', damage: 1, treasures: [2] }],
      [{ id: 'TNL023', name: 'Goblin Nursery', type: 'monster', damage: 1, treasures: [2] }],
      [{ id: 'TNL028', name: 'Goblin Mess Hall', type: 'monster', damage: 3, treasures: [2], advanced: true }],
      [{ id: 'TNL038', name: 'Elemental Generator', type: 'monster', damage: 3, treasures: [3], advanced: true }],
    ];
    assert.equal(roomDamageWithModifiers(G, 0, 0, { id: 'h' }), 4); // 1 + nursery2 + mess1
    assert.equal(roomDamageWithModifiers(G, 0, 3, { id: 'h' }), 6); // 3 + 2 spells + mess1
  });

  it("Robber's Vault exchanges hoards", () => {
    const { G, ctx } = setupMatch(2, { expansions: ['minibosses'] });
    G.effects = emptyEffects();
    G.players[0].coins = 1;
    G.players[1].coins = 5;
    G.players[0].dungeon = [[{ id: 'RMB021', name: "Robber's Vault", type: 'trap', damage: 3, treasures: [1] }]];
    onBuildRoom(G, ctx, 0, G.players[0].dungeon[0][0]);
    assert.equal(G.players[0].coins, 5);
    assert.equal(G.players[1].coins, 1);
  });

  it('Dragon Nest boosts other monsters by treasure count', () => {
    const { G, ctx } = setupMatch(2, { expansions: ['minibosses'] });
    G.effects = emptyEffects();
    const nest = { id: 'RMB028', name: "Dragon's Nest", type: 'monster', damage: 4, treasures: [2] };
    G.players[0].dungeon = [
      [{ id: 'BMA010', name: 'M', type: 'monster', damage: 1, treasures: [1, 2] }],
      [nest],
    ];
    onBuildRoom(G, ctx, 0, nest);
    assert.ok(G.effects.roomDamageBonus.some((e) => e.roomIndex === 0 && e.amount === 2));
  });

  it('Wreck Room destroys another room to draw', () => {
    const { G, ctx } = setupMatch(2, { expansions: ['next-level'] });
    Object.assign(G, { phase: PHASE.BUILD, effects: emptyEffects() });
    Object.assign(ctx, { phase: PHASE.BUILD, activePlayer: 0 });
    G.decks.rooms.push({ id: 'draw1', name: 'Drawn', isRoom: true });
    G.players[0].dungeon = [
      [{ id: 'TNL041', name: 'Wreck Room', type: 'trap', damage: 1, treasures: [4] }],
      [{ id: 'BMA009', name: 'Dark Altar', type: 'monster', damage: 1, treasures: [1] }],
    ];
    const before = G.players[0].hand.length;
    assert.equal(activateRoomAbility(G, ctx, 0, 0, 1), null);
    assert.equal(G.players[0].dungeon.length, 1);
    assert.equal(G.players[0].hand.length, before + 1);
  });

  it('Collapsing Bridge gains +3 after a hero survives', () => {
    const { G } = setupMatch(2, { expansions: ['next-level'] });
    G.effects = emptyEffects();
    const room = { id: 'TNL043', name: 'Collapsing Bridge', type: 'trap', damage: 1, treasures: [4] };
    G.players[0].dungeon = [[room]];
    applyTaggedOnHeroSurvive(G, 0, 0, room);
    assert.ok(G.effects.roomDamageBonus.some((e) => e.amount === 3));
    assert.equal(room.usedThisTurn, true);
  });

  it('Fetid Beast blocks adjacent Monster builds', () => {
    const { G } = setupMatch(2, { expansions: ['minibosses'] });
    G.effects = emptyEffects();
    G.players[0].buildsThisTurn = 0;
    G.players[0].dungeon = [[{ id: 'RMB025', name: 'Fetid Beast', type: 'monster', damage: 1, treasures: [2] }]];
    G.players[0].hand = [{ id: 'BMA010', name: 'Monster', isRoom: true, type: 'monster', damage: 1, treasures: [2] }];
    assert.equal(canBuildRoom(G, 0, 0, null), false);
  });

  it('Doppelganger Hive scales with lured heroes', () => {
    const { G } = setupMatch(2, { expansions: ['minibosses'] });
    G.effects = emptyEffects();
    G.luredThisTurn = { 0: 2 };
    G.players[0].boss = { id: 'B', treasures: [], xp: 0 };
    G.players[0].dungeon = [[{ id: 'RMB029', name: 'Doppelganger Hive', type: 'monster', damage: 2, treasures: [2] }]];
    assert.equal(roomDamageWithModifiers(G, 0, 0, { id: 'h' }), 4);
  });

  it('Goblin Market pays coins for adjacent builds', () => {
    const { G } = setupMatch(2, { expansions: ['minibosses'] });
    G.effects = emptyEffects();
    G.players[0].coins = 0;
    G.players[0].buildsThisTurn = 0;
    G.players[0].dungeon = [[{ id: 'RMB023', name: 'Goblin Market', type: 'monster', damage: 1, treasures: [2] }]];
    G.players[0].hand = [{ id: 'BMA009', name: 'Dark Altar', isRoom: true, type: 'monster', damage: 1, treasures: [1] }];
    assert.equal(buildRoom(G, 0, 0, null), true);
    assert.equal(G.players[0].coins, 2);
  });

  it('Cursed Tomb forces opponents to discard Rooms', () => {
    const { G } = setupMatch(2, { expansions: ['next-level'] });
    G.effects = emptyEffects();
    G.players[0].dungeon = [[{ id: 'TNL054', name: 'Cursed Tomb', type: 'trap', damage: 1, treasures: [4] }]];
    G.players[1].hand = [
      { id: 'r1', name: 'R1', isRoom: true },
      { id: 'r2', name: 'R2', isRoom: true },
      { id: 's1', name: 'S', isSpell: true },
    ];
    destroyRoom(G, 0, 0);
    assert.equal(G.players[1].hand.length, 1);
    assert.equal(G.players[1].hand[0].isSpell, true);
  });

  it('The Smashinator clears other rooms for +6', () => {
    const { G, ctx } = setupMatch(2, { expansions: ['next-level'] });
    Object.assign(G, { phase: PHASE.BUILD, effects: emptyEffects() });
    Object.assign(ctx, { phase: PHASE.BUILD, activePlayer: 0 });
    G.players[0].dungeon = [
      [{ id: 'BMA009', name: 'A', type: 'monster', damage: 1, treasures: [1] }],
      [{ id: 'TNL048', name: 'The Smashinator', type: 'trap', damage: 1, treasures: [4] }],
      [{ id: 'BMA010', name: 'B', type: 'monster', damage: 1, treasures: [1] }],
    ];
    assert.equal(activateRoomAbility(G, ctx, 0, 1, null), null);
    assert.equal(G.players[0].dungeon.length, 1);
    assert.ok(G.effects.roomDamageBonus.some((e) => e.amount === 6));
  });

  it("Alchemist's Lab gains coins when a spell resolves", () => {
    const { G, ctx } = setupMatch(2, { expansions: ['minibosses'] });
    G.effects = emptyEffects();
    G.players[0].coins = 0;
    G.players[0].dungeon = [[{ id: 'RMB032', name: "Alchemist's Lab", type: 'trap', damage: 1, treasures: [3] }]];
    castSpell(G, ctx, 0, { id: 'BMA040', name: 'Annihilator', isSpell: true }, { roomIndex: 0 });
    assert.equal(G.players[0].coins, 2);
  });

  it('Cursed Well discards from hand for coins', () => {
    const { G, ctx } = setupMatch(2, { expansions: ['minibosses'] });
    Object.assign(G, { phase: PHASE.BUILD, effects: emptyEffects() });
    Object.assign(ctx, { phase: PHASE.BUILD, activePlayer: 0 });
    G.players[0].coins = 0;
    G.players[0].hand = [{ id: 'RMB035', name: 'Cursed Well', isRoom: true, type: 'trap', treasures: [4] }];
    const r = applyMove({ G, ctx }, { type: 'useHandRoom', args: [0, { choice: 'coins' }] }, 0);
    assert.equal(r.error, undefined);
    assert.equal(r.state.G.players[0].coins, 2);
    assert.equal(r.state.G.players[0].hand.length, 0);
  });

  it('Inner Sanctum draws when no hero entered', () => {
    const { G } = setupMatch(2, { expansions: ['next-level'] });
    G.effects = emptyEffects();
    G.decks.rooms.push({ id: 'drawme', name: 'Drawn', isRoom: true });
    G.players[0].dungeon = [[{ id: 'TNL018', name: 'Inner Sanctum', type: 'trap', damage: 2, treasures: [1] }]];
    const before = G.players[0].hand.length;
    processEndOfTurnRooms(G);
    assert.equal(G.players[0].hand.length, before + 1);
  });

  it('Dreadmill places a coin or destroys', () => {
    const { G } = setupMatch(2, { expansions: ['minibosses'] });
    G.effects = emptyEffects();
    G.players[0].coins = 1;
    G.players[0].dungeon = [[{ id: 'RMB048', name: 'The Dreadmill', type: 'trap', damage: 1, treasures: [4] }]];
    processDreadmills(G);
    assert.equal(G.players[0].coins, 0);
    assert.equal(G.players[0].dungeon[0][0].coinsOn, 1);
    assert.equal(roomDamageWithModifiers(G, 0, 0, { id: 'h' }), 2);
  });
});
