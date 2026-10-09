import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import { setupMatch, applyMove } from '../../src/backend/game/reducer.js';
import { castSpell, emptyEffects } from '../../src/backend/game/spellEffects.js';
import { PHASE } from '../../src/backend/game/cardData.js';
import { roomDamageWithModifiers, destroyRoom } from '../../src/backend/game/engine.js';
import { activateRoomAbility, onBuildRoom, onHeroDiedInRoom, resolveLevelUpChoice } from '../../src/backend/game/roomAbilities.js';
import { canUseHandRoom, notifyOpponentMiniboss, useHandRoomAbility } from '../../src/backend/game/handAbilities.js';
import { applyTaggedOnHeroSurvive } from '../../src/backend/game/expansionEffects.js';
import {
  activateMiniboss,
  beginningPhaseCoins,
  buildMiniboss,
  canActivateMiniboss,
  canBuildMiniboss,
  canPromoteMiniboss,
  clearMinibossTurnFlags,
  gainCoin,
  icicleIgnoresHeroAbilities,
  minibossDamageBonus,
  minibossExtraTreasures,
  onMinibossHeroDied,
  onRoomDestroyed,
  processJinxDraw,
  promoteMiniboss,
  revealMinibosses,
  resolveMinibossPendingChoice,
  rockyAllowsAnyBuild,
} from '../../src/backend/game/minibosses.js';
import { processExpansionLevelUp } from '../../src/backend/game/expansionBosses.js';

// Rise of the Minibosses: the ten Miniboss cards RMB055–RMB064 (levels 1/2/3),
// the build → reveal → promote → activate loop, and the pack's persistent
// boss abilities.

const MB_NAMES = {
  RMB055: 'Spike',
  RMB056: 'Kid Croak',
  RMB057: 'Draculad',
  RMB058: 'Rocky',
  RMB059: 'Cerebella',
  RMB060: 'Paddywhack',
  RMB061: 'Icicle Man',
  RMB062: 'Mageseeker',
  RMB063: 'Brassknuckle',
  RMB064: 'Jinx',
};

const room = (id = 'r1', over = {}) => ({
  id, name: `Room ${id}`, type: 'monster', damage: 1, treasures: [2], isRoom: true, ...over,
});
const spell = (id = 's1', over = {}) => ({ id, name: `Spell ${id}`, isSpell: true, ...over });

/** Build-phase state with an empty dungeon for each player unless provided. */
function setup(dungeon0 = null, dungeon1 = null) {
  const s = setupMatch(2, { expansions: ['minibosses'] });
  const { G, ctx } = s;
  G.phase = PHASE.BUILD;
  ctx.phase = PHASE.BUILD;
  ctx.activePlayer = 0;
  G.effects = emptyEffects();
  if (dungeon0) G.players[0].dungeon = dungeon0;
  if (dungeon1) G.players[1].dungeon = dungeon1;
  return s;
}

function putMb(G, pid, roomIndex, id, level = 1, over = {}) {
  const stack = G.players[pid].dungeon[roomIndex];
  stack.miniboss = {
    card: { id, name: MB_NAMES[id] || id },
    level,
    faceDown: false,
    usedL3: false,
    usedThisTurn: false,
    ...over,
  };
  return stack.miniboss;
}

function stackAt(G, pid, roomIndex) {
  return G.players[pid].dungeon[roomIndex];
}

describe('miniboss cards RMB055–RMB064 — level 1 passives', () => {
  it('RMB055 Spike L1 gives the room +1 damage', () => {
    const { G } = setup([[room('r1', { damage: 2 })]]);
    putMb(G, 0, 0, 'RMB055', 1);
    assert.equal(minibossDamageBonus(stackAt(G, 0, 0)), 1);
    assert.equal(roomDamageWithModifiers(G, 0, 0, { id: 'h' }), 3);
  });

  it('RMB056 Kid Croak L1 adds the Fighter treasure icon', () => {
    const { G } = setup([[room('r1')]]);
    putMb(G, 0, 0, 'RMB056', 1);
    assert.deepEqual(minibossExtraTreasures(stackAt(G, 0, 0)), [2]);
  });

  it('RMB057 Draculad L1 adds the Cleric treasure icon', () => {
    const { G } = setup([[room('r1')]]);
    putMb(G, 0, 0, 'RMB057', 1);
    assert.deepEqual(minibossExtraTreasures(stackAt(G, 0, 0)), [1]);
  });

  it('RMB058 Rocky L1 lets any Room be built on top', () => {
    const { G } = setup([[room('r1')]]);
    putMb(G, 0, 0, 'RMB058', 1);
    assert.equal(rockyAllowsAnyBuild(stackAt(G, 0, 0)), true);
    putMb(G, 0, 0, 'RMB058', 1, { faceDown: true });
    assert.equal(rockyAllowsAnyBuild(stackAt(G, 0, 0)), false);
  });

  it('RMB059 Cerebella L1 adds the Mage treasure icon', () => {
    const { G } = setup([[room('r1')]]);
    putMb(G, 0, 0, 'RMB059', 1);
    assert.deepEqual(minibossExtraTreasures(stackAt(G, 0, 0)), [3]);
  });

  it('RMB060 Paddywhack L1 adds the Thief treasure icon', () => {
    const { G } = setup([[room('r1')]]);
    putMb(G, 0, 0, 'RMB060', 1);
    assert.deepEqual(minibossExtraTreasures(stackAt(G, 0, 0)), [4]);
  });

  it('RMB061 Icicle Man L1 gives +1 and does not yet ignore hero text', () => {
    const { G } = setup([[room('r1', { damage: 3 })]]);
    putMb(G, 0, 0, 'RMB061', 1);
    assert.equal(minibossDamageBonus(stackAt(G, 0, 0)), 1);
    assert.equal(icicleIgnoresHeroAbilities(G, 0), false);
    putMb(G, 0, 0, 'RMB061', 2);
    assert.equal(icicleIgnoresHeroAbilities(G, 0), true);
    assert.equal(icicleIgnoresHeroAbilities(G, 1), false);
  });

  it('RMB062 Mageseeker L1 gives +1 per treasure icon', () => {
    const { G } = setup([[room('r1', { treasures: [1, 2, 4] })]]);
    putMb(G, 0, 0, 'RMB062', 1);
    assert.equal(minibossDamageBonus(stackAt(G, 0, 0)), 3);
    assert.equal(roomDamageWithModifiers(G, 0, 0, { id: 'h' }), 4);
  });

  it('RMB063 Brassknuckle L1 gives +1 damage', () => {
    const { G } = setup([[room('r1', { damage: 4 })]]);
    putMb(G, 0, 0, 'RMB063', 1);
    assert.equal(roomDamageWithModifiers(G, 0, 0, { id: 'h' }), 5);
  });

  it('RMB064 Jinx L1 triggers the extra draw / discard at Build start', () => {
    const { G } = setup([[room('r1')]]);
    putMb(G, 0, 0, 'RMB064', 1);
    G.decks.rooms = [room('drawn')];
    G.players[0].hand = [room('kept')];
    processJinxDraw(G);
    assert.equal(G.pendingChoice?.type, 'mb-jinx-discard');
    assert.equal(G.pendingChoice.options.length, 2); // kept + drawn
    resolveMinibossPendingChoice(G, {}, 0, 1); // discard the drawn Room
    assert.deepEqual(G.players[0].hand.map((c) => c.id), ['kept']);
    assert.equal(G.decks.roomDiscard.length, 1);
  });
});

describe('miniboss cards RMB055–RMB064 — level 2 activations', () => {
  it('RMB055 Spike L2 discards a card to deal 2 damage in this Room', () => {
    const { G, ctx } = setup([[room('r1')]]);
    putMb(G, 0, 0, 'RMB055', 2);
    G.players[0].hand = [spell('to-discard')];
    G.adventure = { playerId: 0, roomIndex: 0, hero: { id: 'h1', name: 'Hero' }, hp: 5 };
    assert.equal(canActivateMiniboss(G, 0, 0, 'l2'), true);
    assert.equal(activateMiniboss(G, ctx, 0, 0, 'l2'), null);
    assert.equal(G.pendingChoice.type, 'mb-spike-discard');
    resolveMinibossPendingChoice(G, ctx, 0, 0);
    assert.equal(G.players[0].hand.length, 0);
    assert.equal(G.decks.spellDiscard.length, 1);
    assert.equal(G.adventure.hp, 3);
    assert.equal(stackAt(G, 0, 0).miniboss.usedThisTurn, true);
    assert.equal(canActivateMiniboss(G, 0, 0, 'l2'), false); // once per turn
  });

  it('RMB056 Kid Croak L2 offers a two-Room swap', () => {
    const { G, ctx } = setup([[room('r1')]], [[room('r2')]]);
    putMb(G, 0, 0, 'RMB056', 2);
    assert.equal(activateMiniboss(G, ctx, 0, 0, 'l2'), null);
    assert.equal(G.pendingChoice.type, 'swap-rooms');
    assert.equal(G.pendingChoice.bossName, 'Kid Croak');
    assert.equal(stackAt(G, 0, 0).miniboss.usedThisTurn, true);
  });

  it('RMB057 Draculad L2 returns the only Hero in the dungeon to town', () => {
    const { G, ctx } = setup([[room('r1')]]);
    putMb(G, 0, 0, 'RMB057', 2);
    const hero = { id: 'h1', name: 'Waiting', hp: 4 };
    G.players[0].entrance = [hero];
    assert.equal(activateMiniboss(G, ctx, 0, 0, 'l2'), null);
    assert.ok(!G.pendingChoice);
    assert.equal(G.players[0].entrance.length, 0);
    assert.deepEqual(G.town.map((h) => h.id), ['h1']);
    assert.equal(stackAt(G, 0, 0).miniboss.usedThisTurn, true);
  });

  it('RMB059 Cerebella L2 draws a Spell when a Hero dies in the Room', () => {
    const { G } = setup([[room('r1')]]);
    putMb(G, 0, 0, 'RMB059', 2);
    G.decks.spells = [spell('drawn')];
    onMinibossHeroDied(G, {}, 0, 0, { id: 'dead', name: 'Dead' });
    assert.deepEqual(G.players[0].hand.map((c) => c.id), ['drawn']);
  });

  it('RMB062 Mageseeker L2 discards a Spell to cancel the top of the stack', () => {
    const { G, ctx } = setup([[room('r1')]]);
    putMb(G, 0, 0, 'RMB062', 2);
    G.players[0].hand = [spell('counter'), room('not-a-spell')];
    G.stack = [{ card: spell('incoming', { id: 'BMA040' }), playerId: 1 }];
    assert.equal(canActivateMiniboss(G, 0, 0, 'l2'), true);
    assert.equal(activateMiniboss(G, ctx, 0, 0, 'l2'), null);
    assert.equal(G.stack.length, 0);
    assert.deepEqual(G.decks.spellDiscard.map((c) => c.id), ['counter', 'BMA040']);
    assert.deepEqual(G.players[0].hand.map((c) => c.id), ['not-a-spell']);
    assert.equal(stackAt(G, 0, 0).miniboss.usedThisTurn, true);
    assert.equal(G.skipAdvance, true);
  });

  it('RMB064 Jinx L2 repeats this Room’s printed treasure icons', () => {
    const { G } = setup([[room('r1', { treasures: [1, 4] })]]);
    putMb(G, 0, 0, 'RMB064', 2);
    assert.deepEqual(minibossExtraTreasures(stackAt(G, 0, 0)), [1, 4]);
    putMb(G, 0, 0, 'RMB064', 1);
    assert.deepEqual(minibossExtraTreasures(stackAt(G, 0, 0)), []);
  });

  it('RMB063 Brassknuckle L2 draws a Room and grants an immediate build', () => {
    const { G } = setup([[room('r1')]]);
    putMb(G, 0, 0, 'RMB063', 2);
    G.decks.rooms = [room('drawn')];
    G.players[0].buildsThisTurn = 1;
    onMinibossHeroDied(G, {}, 0, 0, { id: 'dead', name: 'Dead' });
    assert.deepEqual(G.players[0].hand.map((c) => c.id), ['drawn']);
    assert.deepEqual(G.effects.immediateBuild, [0]);
    assert.equal(G.players[0].buildsThisTurn, 0);
    assert.equal(stackAt(G, 0, 0).miniboss.usedThisTurn, true);
  });
});

describe('miniboss cards RMB055–RMB064 — level 3 activations', () => {
  it('RMB055 Spike L3 returns a Miniboss to its owner’s hand and resets', () => {
    const { G, ctx } = setup([[room('r1')]]);
    putMb(G, 0, 0, 'RMB055', 3);
    assert.equal(activateMiniboss(G, ctx, 0, 0, 'l3'), null);
    assert.ok(!G.pendingChoice);
    assert.equal(stackAt(G, 0, 0).miniboss, undefined);
    assert.deepEqual(G.players[0].hand.map((c) => c.id), ['RMB055']);
  });

  it('RMB055 Spike L3 asks which Miniboss when several are in play', () => {
    const { G, ctx } = setup([[room('r1'), room('r2')]], [[room('r3')]]);
    putMb(G, 0, 0, 'RMB055', 3);
    putMb(G, 1, 0, 'RMB061', 1);
    assert.equal(activateMiniboss(G, ctx, 0, 0, 'l3'), null);
    assert.equal(G.pendingChoice.type, 'mb-spike-return');
    resolveMinibossPendingChoice(G, ctx, 0, 1);
    assert.equal(stackAt(G, 1, 0).miniboss, undefined);
    assert.deepEqual(G.players[1].hand.map((c) => c.id), ['RMB061']);
    assert.equal(stackAt(G, 0, 0).miniboss.level, 1);
  });

  it('RMB057 Draculad L3 lets you take a card from the only opponent', () => {
    const { G, ctx } = setup([[room('r1')]]);
    putMb(G, 0, 0, 'RMB057', 3);
    G.players[1].hand = [room('stolen'), spell('also')];
    assert.equal(activateMiniboss(G, ctx, 0, 0, 'l3'), null);
    assert.equal(G.pendingChoice.type, 'mb-draculad-steal');
    resolveMinibossPendingChoice(G, ctx, 0, 0);
    assert.deepEqual(G.players[0].hand.map((c) => c.id), ['stolen']);
    assert.deepEqual(G.players[1].hand.map((c) => c.id), ['also']);
    assert.equal(stackAt(G, 0, 0).miniboss.level, 1);
  });

  it('RMB058 Rocky L3 gives a Hero +5 health and resets', () => {
    const { G, ctx } = setup([[room('r1')]]);
    putMb(G, 0, 0, 'RMB058', 3);
    G.players[0].entrance = [{ id: 'h1', name: 'Buff Me', hp: 4 }];
    assert.equal(activateMiniboss(G, ctx, 0, 0, 'l3'), null);
    assert.ok(!G.pendingChoice);
    assert.deepEqual(G.effects.heroHealthBonus, [{ heroId: 'h1', amount: 5 }]);
    assert.equal(stackAt(G, 0, 0).miniboss.level, 1);
  });

  it('RMB059 Cerebella L3 makes Heroes ignore ability text in a dungeon', () => {
    const { G, ctx } = setup([[room('r1')]]);
    putMb(G, 0, 0, 'RMB059', 3);
    assert.equal(activateMiniboss(G, ctx, 0, 0, 'l3'), null);
    assert.equal(G.pendingChoice.type, 'mb-cerebella-ignore');
    resolveMinibossPendingChoice(G, ctx, 0, 1);
    assert.deepEqual(G.effects.ignoreAbilityPids, [1]);
    assert.equal(stackAt(G, 0, 0).miniboss.level, 1);
  });

  it('RMB060 Paddywhack L3 kills the Hero in this Room and resets', () => {
    const { G, ctx } = setup([[room('r1')]]);
    putMb(G, 0, 0, 'RMB060', 3);
    G.adventure = { playerId: 0, roomIndex: 0, hero: { id: 'h1', name: 'Victim' }, hp: 6 };
    assert.equal(activateMiniboss(G, ctx, 0, 0, 'l3'), null);
    assert.equal(G.adventure.hp, 0);
    assert.equal(stackAt(G, 0, 0).miniboss.level, 1);
  });

  it('RMB061 Icicle Man L3 deactivates a Room and resets', () => {
    const { G, ctx } = setup([[room('r1')]]);
    putMb(G, 0, 0, 'RMB061', 3);
    assert.equal(activateMiniboss(G, ctx, 0, 0, 'l3'), null);
    assert.deepEqual(G.effects.deactivatedRooms, [{ playerId: 0, roomIndex: 0 }]);
    assert.equal(stackAt(G, 0, 0).miniboss.level, 1);
  });

  it('RMB062 Mageseeker L3 makes Heroes skip the first Room of a dungeon', () => {
    const { G, ctx } = setup([[room('r1')]]);
    putMb(G, 0, 0, 'RMB062', 3);
    assert.equal(activateMiniboss(G, ctx, 0, 0, 'l3'), null);
    assert.equal(G.pendingChoice.type, 'mb-mage-skip');
    resolveMinibossPendingChoice(G, ctx, 0, 1);
    assert.deepEqual(G.effects.skipFirstRoomPids, [1]);
    assert.equal(stackAt(G, 0, 0).miniboss.level, 1);
  });

  it('RMB063 Brassknuckle L3 doubles this Room’s damage until end of turn', () => {
    const { G, ctx } = setup([[room('r1', { damage: 3 })]]);
    putMb(G, 0, 0, 'RMB063', 3);
    assert.equal(activateMiniboss(G, ctx, 0, 0, 'l3'), null);
    assert.deepEqual(G.effects.roomDamageBonus, [{ playerId: 0, roomIndex: 0, amount: 3 }]);
    assert.equal(roomDamageWithModifiers(G, 0, 0, { id: 'h' }), 7); // 3 base + 3 L3 double + 1 L1 passive after reset
    assert.equal(stackAt(G, 0, 0).miniboss.level, 1);
  });

  it('RMB064 Jinx L3 pulls a Hero from town to your entrance and resets', () => {
    const { G, ctx } = setup([[room('r1')]]);
    putMb(G, 0, 0, 'RMB064', 3);
    G.town = [{ id: 'h1', name: 'Town Hero', hp: 5 }];
    assert.equal(activateMiniboss(G, ctx, 0, 0, 'l3'), null);
    assert.ok(!G.pendingChoice);
    assert.equal(G.town.length, 0);
    assert.deepEqual(G.players[0].entrance.map((h) => h.id), ['h1']);
    assert.equal(stackAt(G, 0, 0).miniboss.level, 1);
  });
});

describe('miniboss build, reveal and promote loop', () => {
  it('buildMiniboss attaches face-down at Level 1 and consumes the build', () => {
    const { G } = setup([[room('r1')]]);
    G.decks.minibosses = [{ id: 'RMB055', name: 'Spike' }];
    G.players[0].buildsThisTurn = 0;
    assert.equal(canBuildMiniboss(G, 0), true);
    assert.equal(buildMiniboss(G, 0, null, 0), true);
    const mb = stackAt(G, 0, 0).miniboss;
    assert.equal(mb.faceDown, true);
    assert.equal(mb.level, 1);
    assert.equal(G.players[0].buildsThisTurn, 1);
    assert.equal(canBuildMiniboss(G, 0), false); // one build per turn
  });

  it('canBuildMiniboss refuses outside Build or onto an occupied stack', () => {
    const { G } = setup([[room('r1')]]);
    G.decks.minibosses = [{ id: 'RMB055', name: 'Spike' }];
    G.phase = PHASE.ADVENTURE;
    assert.equal(canBuildMiniboss(G, 0), false);
    G.phase = PHASE.BUILD;
    putMb(G, 0, 0, 'RMB055', 1);
    assert.equal(canBuildMiniboss(G, 0), false);
  });

  it('revealMinibosses pays 1 Coin to flip it face-up', () => {
    const { G } = setup([[room('r1')]]);
    const mb = putMb(G, 0, 0, 'RMB064', 2, { faceDown: true });
    G.players[0].coins = 3;
    revealMinibosses(G, {});
    assert.equal(mb.faceDown, false);
    assert.equal(G.players[0].coins, 2);
  });

  it('revealMinibosses discards the Miniboss when you cannot pay', () => {
    const { G } = setup([[room('r1')]]);
    putMb(G, 0, 0, 'RMB064', 1, { faceDown: true });
    G.players[0].coins = 0;
    revealMinibosses(G, {});
    assert.equal(stackAt(G, 0, 0).miniboss, undefined);
    assert.deepEqual(G.decks.minibossDiscard.map((c) => c.id), ['RMB064']);
  });

  it('promoteMiniboss spends 1 Coin, raises the level and locks the turn', () => {
    const { G } = setup([[room('r1')]]);
    const mb = putMb(G, 0, 0, 'RMB055', 1);
    G.players[0].coins = 2;
    assert.equal(canPromoteMiniboss(G, 0, 0), true);
    assert.equal(promoteMiniboss(G, 0, 0), null);
    assert.equal(mb.level, 2);
    assert.equal(G.players[0].coins, 1);
    assert.equal(canPromoteMiniboss(G, 0, 0), false);
    assert.equal(promoteMiniboss(G, 0, 0), 'already promoted this turn');
    clearMinibossTurnFlags(G);
    assert.equal(canPromoteMiniboss(G, 0, 0), true);
    assert.equal(promoteMiniboss(G, 0, 0), null);
    assert.equal(mb.level, 3);
    clearMinibossTurnFlags(G);
    assert.equal(canPromoteMiniboss(G, 0, 0), false);
    assert.equal(promoteMiniboss(G, 0, 0), 'cannot promote'); // Level 3 is max
  });

  it('promoteMiniboss refuses face-down Minibosses, missing Coins and other phases', () => {
    const { G } = setup([[room('r1')]]);
    putMb(G, 0, 0, 'RMB055', 1, { faceDown: true });
    G.players[0].coins = 5;
    assert.equal(canPromoteMiniboss(G, 0, 0), false);
    assert.equal(promoteMiniboss(G, 0, 0), 'cannot promote');

    const { G: G2 } = setup([[room('r1')]]);
    putMb(G2, 0, 0, 'RMB055', 1);
    G2.players[0].coins = 0;
    assert.equal(canPromoteMiniboss(G2, 0, 0), false);
    assert.equal(promoteMiniboss(G2, 0, 0), 'need 1 Coin');

    const { G: G3 } = setup([[room('r1')]]);
    putMb(G3, 0, 0, 'RMB055', 1);
    G3.players[0].coins = 5;
    G3.phase = PHASE.ADVENTURE;
    assert.equal(canPromoteMiniboss(G3, 0, 0), false);
    assert.equal(promoteMiniboss(G3, 0, 0), 'promote only during the Build phase');
  });

  it('clearMinibossTurnFlags resets promote and activation locks', () => {
    const { G } = setup([[room('r1')]]);
    const mb = putMb(G, 0, 0, 'RMB055', 2);
    mb.usedThisTurn = true;
    G.players[0].promoteUsedThisTurn = true;
    clearMinibossTurnFlags(G);
    assert.equal(mb.usedThisTurn, false);
    assert.equal(G.players[0].promoteUsedThisTurn, false);
  });
});

describe('miniboss activation guards', () => {
  it('a face-down Miniboss cannot be activated', () => {
    const { G, ctx } = setup([[room('r1')]]);
    putMb(G, 0, 0, 'RMB063', 3, { faceDown: true });
    assert.equal(canActivateMiniboss(G, 0, 0), false);
    assert.equal(activateMiniboss(G, ctx, 0, 0, 'l3'), 'cannot activate miniboss');
  });

  it('activation requires the Build or Adventure phase', () => {
    const { G } = setup([[room('r1')]]);
    putMb(G, 0, 0, 'RMB063', 3);
    G.phase = PHASE.END;
    assert.equal(canActivateMiniboss(G, 0, 0, 'l3'), false);
    G.phase = PHASE.ADVENTURE;
    assert.equal(canActivateMiniboss(G, 0, 0, 'l3'), true);
  });

  it('Level 2 needs level ≥ 2, Level 3 needs level 3 and an unused L3', () => {
    const { G } = setup([[room('r1')]]);
    putMb(G, 0, 0, 'RMB063', 2);
    assert.equal(canActivateMiniboss(G, 0, 0, 'l3'), false);
    putMb(G, 0, 0, 'RMB063', 3, { usedL3: true });
    assert.equal(canActivateMiniboss(G, 0, 0, 'l3'), false);
    putMb(G, 0, 0, 'RMB063', 1);
    assert.equal(canActivateMiniboss(G, 0, 0, 'l2'), false);
  });

  it('onRoomDestroyed sends the Miniboss to the Miniboss discard pile', () => {
    const { G } = setup();
    const stack = [];
    stack.miniboss = { card: { id: 'RMB064', name: 'Jinx' }, level: 1, faceDown: false };
    G.players[0].dungeon = [stack];
    onRoomDestroyed(G, 0, stack);
    assert.equal(stack.miniboss, undefined);
    assert.deepEqual((G.decks.minibossDiscard || []).map((c) => c.id), ['RMB064']);
  });
});

describe('Rise of the Minibosses pack bosses', () => {
  const BOSSES = [
    ['RMB001', 'Gregore', 'gregoreCoin'],
    ['RMB002', 'Calabeza', 'calabezaPromote'],
    ['RMB003', 'Belladonna', 'belladonnaForce'],
    ['RMB004', 'Lamia', 'lamiaCoin'],
    ['RMB005', 'King Croak', 'croakMinibossLevel2'],
    ['RMB006', 'Ravenus', 'ravenusDouble'],
    ['RMB007', 'Baron Hex', 'baronHexCoin'],
    ['RMB008', 'Oculus', 'oculusSpell'],
    ['RMB009', 'Kazanna', 'kazannaSpell'],
    ['RMB010', 'Dr. Deadly', 'deadlyTrapCoin'],
    ['RMB011', 'Scott', 'scottTrapBonus'],
    ['RMB012', 'Kirax', 'kiraxKillCoin'],
  ];

  for (const [id, name, flag] of BOSSES) {
    it(`${id} ${name} registers its persistent ability on Level Up`, () => {
      const { G } = setup([[room('r1')]]);
      const err = processExpansionLevelUp(G, 0, { id, name });
      assert.equal(err, null);
      assert.equal(G.players[0][flag], true);
    });
  }

  it('RMB005 King Croak makes built Minibosses start at Level 2', () => {
    const { G } = setup([[room('r1')]]);
    processExpansionLevelUp(G, 0, { id: 'RMB005', name: 'King Croak' });
    G.decks.minibosses = [{ id: 'RMB055', name: 'Spike' }];
    G.players[0].buildsThisTurn = 0;
    assert.equal(buildMiniboss(G, 0, null, 0), true);
    assert.equal(stackAt(G, 0, 0).miniboss.level, 2);
  });
});

describe('miniboss economy hooks', () => {
  it('Paddywhack L2 pays one extra Coin per gain, once per turn', () => {
    const { G } = setup([[room('r1')]]);
    putMb(G, 0, 0, 'RMB060', 2);
    G.players[0].coins = 0;
    gainCoin(G, 0, 1, 'test');
    assert.equal(G.players[0].coins, 2);
    gainCoin(G, 0, 1, 'test again');
    assert.equal(G.players[0].coins, 3);
    clearMinibossTurnFlags(G);
    gainCoin(G, 0, 1, 'next turn');
    assert.equal(G.players[0].coins, 5);
  });

  it('Paddywhack bonus is skipped while the Miniboss is face-down', () => {
    const { G } = setup([[room('r1')]]);
    putMb(G, 0, 0, 'RMB060', 2, { faceDown: true });
    G.players[0].coins = 0;
    gainCoin(G, 0, 1, 'test');
    assert.equal(G.players[0].coins, 1);
  });

  it('coin-per-turn Rooms pay at the beginning of the turn', () => {
    const { G } = setup([[room('r1', { coinPerTurn: true })]]);
    G.players[0].coins = 0;
    beginningPhaseCoins(G);
    assert.equal(G.players[0].coins, 1);
    beginningPhaseCoins(G);
    assert.equal(G.players[0].coins, 2); // once per call, not once per turn flag
  });

  it('destroying the last Room of a stack drops its Miniboss', () => {
    const { G } = setup([[room('r1')]]);
    putMb(G, 0, 0, 'RMB061', 1);
    G.decks.minibossDiscard = [];
    destroyRoom(G, 0, 0);
    assert.deepEqual(G.decks.minibossDiscard.map((c) => c.id), ['RMB061']);
    assert.equal(G.players[0].dungeon.length, 0); // empty stack removed with its Miniboss
  });
});

describe('Rise of the Minibosses Rooms', () => {
  it('RMB013 Spectral Bomb destroys itself and forces an opponent to discard a Spell', () => {
    const { G, ctx } = setup([[room('RMB013', { name: 'Spectral Bomb', type: 'trap', treasures: [1] })]], []);
    G.players[1].hand = [spell('victim')];
    assert.equal(activateRoomAbility(G, ctx, 0, 0), null);
    assert.equal(G.players[1].hand.length, 0);
    assert.equal(G.decks.spellDiscard.length, 1);
    assert.equal(G.players[0].dungeon.length, 0);
  });

  it('RMB017 Imp Hoard takes the Spell an opponent was forced to discard', () => {
    const { G, ctx } = setup([[
      room('RMB017', { name: 'Imp Hoard', type: 'monster' }),
      room('RMB013', { name: 'Spectral Bomb', type: 'trap' }),
    ]], []);
    G.players[1].hand = [spell('swiped')];
    assert.equal(activateRoomAbility(G, ctx, 0, 0), null);
    assert.equal(G.players[1].hand.length, 0);
    assert.deepEqual(G.players[0].hand.map((c) => c.id), ['swiped']);
    assert.equal(G.decks.spellDiscard.length, 0); // taken, not discarded
    assert.equal(G.players[0].dungeon[0][0].id, 'RMB017');
    assert.equal(G.players[0].dungeon[0][0].usedThisTurn, true); // once per turn
  });

  it('RMB016 Tomb of Terrors recovers a card from the discard piles', () => {
    const { G, ctx } = setup();
    G.players[0].hand = [{ id: 'RMB016', name: 'Tomb of Terrors', isRoom: true, type: 'trap' }];
    G.decks.roomDiscard = [];
    G.decks.spellDiscard = [spell('from-discard')];
    assert.equal(canUseHandRoom(G, 0, 0), true);
    assert.equal(useHandRoomAbility(G, ctx, 0, 0), null);
    assert.deepEqual(G.players[0].hand.map((c) => c.id), ['from-discard']);
    assert.deepEqual(G.decks.roomDiscard.map((c) => c.id), ['RMB016']);
    assert.equal(G.decks.spellDiscard.length, 0);
  });

  it('RMB019 Haunted Cavern pays a Coin to block the entrance Hero', () => {
    const { G, ctx } = setup([[room('RMB019', { name: 'Haunted Cavern', type: 'monster' })]]);
    G.players[0].coins = 2;
    G.players[0].entrance = [{ id: 'h1', name: 'Waiting', hp: 5 }];
    assert.equal(activateRoomAbility(G, ctx, 0, 0), null);
    assert.equal(G.players[0].coins, 1);
    assert.equal(G.players[0].entrance[0]._blockedUntilNextTurn, true);
  });

  it('RMB022 Minotaur Catacombs destroys itself and restarts the Hero run', () => {
    const { G, ctx } = setup([[room('RMB022', { name: 'Minotaur Catacombs', type: 'monster' })]]);
    G.adventure = { playerId: 0, roomIndex: 0, hero: { id: 'h1', name: 'Hero' }, hp: 4 };
    assert.equal(activateRoomAbility(G, ctx, 0, 0), null);
    assert.equal(G.players[0].dungeon.length, 0);
    assert.equal(G.adventure.roomIndex, -1); // back before the first Room
  });

  it('RMB026 Training Camp discards a Miniboss to double a Monster Room', () => {
    const { G, ctx } = setup([[room('prey', { name: 'Big Monster', type: 'monster', damage: 2 })],
      [room('RMB026', { name: 'Training Camp', type: 'monster' })]]);
    G.players[0].hand = [{ id: 'RMB201', name: 'Spare Miniboss', isMiniboss: true }];
    assert.equal(activateRoomAbility(G, ctx, 0, 1), null); // Training Camp is the top of stack 1
    assert.equal(G.pendingChoice.type, 'double-monster'); // two Monster Rooms to choose from
    resolveLevelUpChoice(G, ctx, 0, 0);
    assert.deepEqual(G.players[0].hand, []);
    assert.deepEqual(G.decks.minibossDiscard.map((c) => c.id), ['RMB201']);
    assert.deepEqual(G.effects.roomDamageBonus, [{ playerId: 0, roomIndex: 0, amount: 2 }]);
  });

  it('RMB027 Shrooman Aviary discards itself for a Hero +3 Health', () => {
    const { G, ctx } = setup();
    G.players[0].hand = [{ id: 'RMB027', name: 'Shrooman Aviary', isRoom: true, type: 'monster' }];
    G.players[0].entrance = [{ id: 'h1', name: 'Buffed', hp: 4 }];
    assert.equal(useHandRoomAbility(G, ctx, 0, 0), null);
    assert.deepEqual(G.effects.heroHealthBonus, [{ heroId: 'h1', amount: 3 }]);
    assert.deepEqual(G.decks.roomDiscard.map((c) => c.id), ['RMB027']);
  });

  it('RMB030 Foyer Elemental pays 2 Coins when a Hero survives, once per turn', () => {
    const { G } = setup([[room('RMB030', { name: 'Foyer Elemental', type: 'monster' })]]);
    const r = G.players[0].dungeon[0][0];
    G.players[0].coins = 0;
    applyTaggedOnHeroSurvive(G, 0, 0, r);
    assert.equal(G.players[0].coins, 2);
    applyTaggedOnHeroSurvive(G, 0, 0, r);
    assert.equal(G.players[0].coins, 2);
  });

  it('RMB031 Mysterious Portal discards a Miniboss to draw a Spell', () => {
    const { G, ctx } = setup([[room('RMB031', { name: 'Mysterious Portal', type: 'trap' })]]);
    G.players[0].hand = [{ id: 'RMB201', name: 'Spare Miniboss', isMiniboss: true }];
    G.decks.spells = [spell('drawn')];
    onBuildRoom(G, ctx, 0, G.players[0].dungeon[0][0]);
    assert.deepEqual(G.players[0].hand.map((c) => c.id), ['drawn']);
    assert.deepEqual(G.decks.minibossDiscard.map((c) => c.id), ['RMB201']);
  });

  it('RMB033 Black Market pays 1 Coin to draw a Spell when a Room is destroyed', () => {
    const { G } = setup([[
      room('RMB033', { name: 'Black Market', type: 'trap' }),
      room('victim', { name: 'Victim', type: 'trap' }),
    ]]);
    G.players[0].coins = 1;
    G.decks.spells = [spell('bought')];
    destroyRoom(G, 0, 0);
    assert.equal(G.players[0].coins, 0);
    assert.deepEqual(G.players[0].hand.map((c) => c.id), ['bought']);
    assert.equal(G.players[0].dungeon[0][0].usedThisTurn, true);
  });

  it('RMB034 Mind Thresher removes the dying Hero from the game', () => {
    const { G, ctx } = setup([[room('RMB034', { name: 'Mind Thresher', type: 'trap' })]]);
    const hero = { id: 'h1', name: 'Doomed', hp: 1 };
    G.adventure = { playerId: 0, roomIndex: 0, hero, hp: 0 };
    onHeroDiedInRoom(G, ctx, 0, G.players[0].dungeon[0][0], hero);
    assert.equal(hero._removedFromGame, true);
  });

  it('RMB036 Loot Box pays 2 Coins to draw 2 Spells', () => {
    const { G, ctx } = setup([[room('RMB036', { name: 'Loot Box', type: 'trap' })]]);
    G.players[0].coins = 5;
    G.decks.spells = [spell('a'), spell('b'), spell('c')];
    onBuildRoom(G, ctx, 0, G.players[0].dungeon[0][0]);
    assert.equal(G.players[0].coins, 3);
    assert.deepEqual(G.players[0].hand.map((c) => c.id), ['c', 'b']);
  });

  it('RMB037 Crystal Ballroom spends up to 3 Coins to draw that many Spells', () => {
    const { G, ctx } = setup([[room('RMB037', { name: 'Crystal Ballroom', type: 'trap' })]]);
    G.players[0].coins = 5;
    G.decks.spells = [spell('a'), spell('b'), spell('c'), spell('d')];
    onBuildRoom(G, ctx, 0, G.players[0].dungeon[0][0]);
    assert.equal(G.players[0].coins, 2);
    assert.equal(G.players[0].hand.length, 3);
  });

  it('RMB038 Efreet’s Chamber draws a Spell and debuffs the Room by 2', () => {
    const { G, ctx } = setup([[room('RMB038', { name: "Efreet's Chamber", type: 'monster' })]]);
    G.players[0].entrance = [{ id: 'h1', name: 'Waiting', hp: 5 }];
    G.decks.spells = [spell('drawn')];
    assert.equal(activateRoomAbility(G, ctx, 0, 0), null);
    assert.deepEqual(G.players[0].hand.map((c) => c.id), ['drawn']);
    assert.deepEqual(G.effects.roomDamageBonus, [{ playerId: 0, roomIndex: 0, amount: -2 }]);
  });

  it('RMB039 Magipede gains +1 damage per Spell in hand', () => {
    const { G } = setup([[room('RMB039', { name: 'Magipede', type: 'monster', damage: 1, treasures: [2] })]]);
    G.players[0].hand = [spell('s1'), spell('s2')];
    assert.equal(roomDamageWithModifiers(G, 0, 0, { id: 'h' }), 3);
  });

  it('RMB041 Garbage Chute gains 2 Coins when any Room is destroyed', () => {
    const { G } = setup([[
      room('RMB041', { name: 'Garbage Chute', type: 'trap' }),
      room('victim', { name: 'Victim', type: 'trap' }),
    ]]);
    G.players[0].coins = 0;
    destroyRoom(G, 0, 0); // destroys the top Room (victim)
    assert.equal(G.players[0].coins, 2);
    assert.equal(G.players[0].dungeon[0][0].usedThisTurn, true);
    destroyRoom(G, 0, 0); // second destroy same turn
    assert.equal(G.players[0].coins, 2); // once per turn
    assert.equal(G.players[0].dungeon.length, 0);
  });

  it('RMB042 Unstable Mine destroys itself for 3 Coins', () => {
    const { G, ctx } = setup([[room('RMB042', { name: 'Unstable Mine', type: 'trap' })]]);
    G.players[0].coins = 0;
    assert.equal(activateRoomAbility(G, ctx, 0, 0), null);
    assert.equal(G.players[0].coins, 3);
    assert.equal(G.players[0].dungeon.length, 0);
  });

  it('RMB043 Sawtooth Pendulum pays a Coin to kill a wounded Hero', () => {
    const { G, ctx } = setup([[room('RMB043', { name: 'Sawtooth Pendulum', type: 'trap' })]]);
    G.players[0].coins = 1;
    G.adventure = { playerId: 0, roomIndex: 0, hero: { id: 'h1', name: 'Weak' }, hp: 3 };
    assert.equal(activateRoomAbility(G, ctx, 0, 0), null);
    assert.equal(G.adventure.hp, 0);
    assert.equal(G.players[0].coins, 0);

    const { G: G2, ctx: ctx2 } = setup([[room('RMB043', { name: 'Sawtooth Pendulum', type: 'trap' })]]);
    G2.players[0].coins = 1;
    G2.adventure = { playerId: 0, roomIndex: 0, hero: { id: 'h1', name: 'Healthy' }, hp: 6 };
    assert.equal(activateRoomAbility(G2, ctx2, 0, 0), 'hero has more than 3 Health');
    assert.equal(G2.players[0].coins, 1);
  });

  it('RMB044 The Catapult discards a Miniboss to deactivate an opponent Room', () => {
    const { G, ctx } = setup([[room('RMB044', { name: 'The Catapult', type: 'trap' })]], [[room('r2')]]);
    G.players[0].hand = [{ id: 'RMB201', name: 'Spare Miniboss', isMiniboss: true }];
    assert.equal(activateRoomAbility(G, ctx, 0, 0), null);
    assert.deepEqual(G.decks.minibossDiscard.map((c) => c.id), ['RMB201']);
    assert.deepEqual(G.effects.deactivatedRooms, [{ playerId: 1, roomIndex: 0 }]);
  });

  it('RMB045 Endless Gallery destroys itself for universal treasure', () => {
    const { G, ctx } = setup([[room('RMB045', { name: 'Endless Gallery', type: 'trap' })]]);
    assert.equal(activateRoomAbility(G, ctx, 0, 0), null);
    assert.equal(G.players[0].dungeon.length, 0);
    assert.deepEqual(G.effects.treasureDoubled, [0]);
  });

  it('RMB046 Paywall lets any player pay Coins to weaken the Room', () => {
    const { G, ctx } = setup([[room('RMB046', { name: 'Paywall', type: 'trap' })]], [[room('r2')]]);
    G.players[0].coins = 0;
    G.players[1].coins = 3;
    const r = applyMove({ G, ctx }, { type: 'payToPaywall', args: [0, 2] }, 1);
    assert.equal(r.error, undefined);
    assert.equal(r.state.G.players[1].coins, 1);
    assert.equal(r.state.G.players[0].coins, 2);
    assert.deepEqual(r.state.G.effects.roomDamageBonus, [{ playerId: 0, roomIndex: 0, amount: -2 }]);

    const bad = applyMove({ G, ctx }, { type: 'payToPaywall', args: [0, 5] }, 1);
    assert.equal(bad.error, 'not enough coins');
  });

  it('RMB047 Living Trap destroys another Monster Room to kill the Hero here', () => {
    const { G, ctx } = setup([[room('RMB047', { name: 'Living Trap', type: 'trap' })],
      [room('prey', { name: 'Prey Monster', type: 'monster' })]]);
    G.adventure = { playerId: 0, roomIndex: 0, hero: { id: 'h1', name: 'Hero' }, hp: 4 };
    assert.equal(activateRoomAbility(G, ctx, 0, 0, 1), null);
    assert.equal(G.players[0].dungeon.length, 1);
    assert.equal(G.players[0].dungeon[0][0].id, 'RMB047');
    assert.equal(G.players[1].dungeon.length, 0); // prey stack destroyed
    assert.equal(G.adventure.hp, 0);
    assert.equal(activateRoomAbility(G, ctx, 0, 0), 'already used this turn');
  });

  it('RMB049 Personnel Office pays a Coin once per turn when an opponent handles a Miniboss', () => {
    const { G } = setup([[room('RMB049', { name: 'Personnel Office', type: 'monster' })]], [[room('r2')]]);
    G.players[0].coins = 0;
    notifyOpponentMiniboss(G, 1);
    assert.equal(G.players[0].coins, 1);
    notifyOpponentMiniboss(G, 1);
    assert.equal(G.players[0].coins, 1);
    assert.equal(G.players[0].dungeon[0][0].usedThisTurn, true);
  });

  it('RMB050 Trophy Room pays 1 Coin per face-down Hero in the score area', () => {
    const { G, ctx } = setup([[room('RMB050', { name: 'Trophy Room', type: 'trap' })]]);
    G.players[0].coins = 0;
    G.players[0].souls = [
      { souls: 1, faceDown: true },
      { souls: 1, faceDown: true },
      { souls: 1, faceDown: false },
    ];
    onBuildRoom(G, ctx, 0, G.players[0].dungeon[0][0]);
    assert.equal(G.players[0].coins, 2);
  });

  it('RMB051 Lightning Rod pays a Coin when a Hero dies in it', () => {
    const { G, ctx } = setup([[room('RMB051', { name: 'Lightning Rod', type: 'trap' })]]);
    G.players[0].coins = 0;
    onHeroDiedInRoom(G, ctx, 0, G.players[0].dungeon[0][0], { id: 'h1', name: 'Dead' });
    assert.equal(G.players[0].coins, 1);
  });

  it('RMB052 Pixie Fountain destroys itself for 1 Coin per Wound', () => {
    const { G, ctx } = setup([[room('RMB052', { name: 'Pixie Fountain', type: 'monster' })]]);
    G.players[0].coins = 0;
    G.players[0].wounds = [{ wounds: 1 }, { wounds: 1 }, { wounds: 1 }];
    assert.equal(activateRoomAbility(G, ctx, 0, 0), null);
    assert.equal(G.players[0].coins, 3);
    assert.equal(G.players[0].dungeon.length, 0);
  });

  it('RMB053 The Keystone destroys itself for 1 Coin per Room in the dungeon', () => {
    const { G, ctx } = setup([[
      room('RMB053', { name: 'The Keystone', type: 'trap' }),
    ], [room('r2')], [room('r3')]]);
    G.players[0].coins = 0;
    assert.equal(activateRoomAbility(G, ctx, 0, 0), null);
    assert.equal(G.players[0].coins, 3); // 1 Coin per Room, counted before the destroy
    assert.equal(G.players[0].dungeon.length, 2);
  });

  it('RMB054 Pool of Shadows discards a Spell for 2 Coins', () => {
    const { G, ctx } = setup([[room('RMB054', { name: 'Pool of Shadows', type: 'trap' })]]);
    G.players[0].coins = 0;
    G.players[0].hand = [spell('spent'), room('kept')];
    assert.equal(activateRoomAbility(G, ctx, 0, 0), null);
    assert.equal(G.players[0].coins, 2);
    assert.deepEqual(G.players[0].hand.map((c) => c.id), ['kept']);
    assert.equal(G.decks.spellDiscard.length, 1);
    assert.equal(G.players[0].dungeon[0][0].usedThisTurn, true);
  });
});

describe('Rise of the Minibosses Heroes', () => {
  const PACK_HEROES = [
    'RMB080', 'RMB081', 'RMB082', 'RMB083', 'RMB084', 'RMB085', 'RMB086', 'RMB087',
    'RMB088', 'RMB089', 'RMB090', 'RMB091', 'RMB092', 'RMB093', 'RMB094', 'RMB095',
    'RMB096', 'RMB097', 'RMB098', 'RMB099', 'RMB100', 'RMB101', 'RMB102', 'RMB103',
    'RMB104', 'RMB105', 'RMB106', 'RMB107', 'RMB108', 'RMB109', 'RMB110', 'RMB111',
    'RMB112', 'RMB113', 'RMB114', 'RMB115', 'RMB116', 'RMB117', 'RMB118', 'RMB119',
    'RMB120', 'RMB121',
  ];
  const CLASSES = new Set(['Cleric', 'Fighter', 'Mage', 'Thief']);

  it('all 42 pack Heroes carry complete, playable stats', () => {
    const web = JSON.parse(fs.readFileSync(new URL('../../src/backend/game/cardData.json', import.meta.url), 'utf-8'));
    const byId = new Map(web.heroes.map((h) => [h.id, h]));
    for (const id of PACK_HEROES) {
      const h = byId.get(id);
      assert.ok(h, `${id} present in card data`);
      assert.equal(h.set, 'minibosses', `${id} set`);
      assert.ok(h.hp > 0, `${id} hp`);
      assert.ok(h.class && CLASSES.has(h.class), `${id} class`);
      assert.ok(h.treasure >= 0 && h.souls >= 0 && h.wounds >= 0, `${id} stats`);
      assert.ok(h.quantity >= 1, `${id} quantity`);
    }
    assert.equal(PACK_HEROES.length, 42);
  });

  it('pack Heroes are dealt into the hero deck of a pack game', () => {
    const { G } = setupMatch(4, { expansions: ['minibosses'] });
    const ids = (G.decks.heroes || []).map((c) => c.id);
    const pack = ids.filter((id) => PACK_HEROES.includes(id));
    assert.ok(pack.length >= 15, `expected pack Heroes in a 4-player deal, got ${pack.length}`);
    assert.ok(ids.every((id) => PACK_HEROES.includes(id) || String(id).startsWith('BMA')), 'only base + pack Heroes');
  });
});

describe('Rise of the Minibosses Spells', () => {
  it('RMB066 Internship keeps a Monster Room from the top three and discards the rest', () => {
    const { G, ctx } = setup();
    G.decks.rooms = [
      room('t1', { type: 'trap' }),
      room('t2', { type: 'trap' }),
      room('m1', { name: 'Kept Monster', type: 'monster' }),
    ];
    assert.equal(castSpell(G, ctx, 0, spell('RMB066'), {}), true);
    assert.deepEqual(G.players[0].hand.map((c) => c.id), ['m1']);
    assert.equal(G.decks.roomDiscard.length, 2);
  });

  it('RMB067 Spirit Dragon adds one of each treasure icon to a Room', () => {
    const { G, ctx } = setup([[room('r1', { treasures: [1] })]]);
    assert.equal(castSpell(G, ctx, 0, spell('RMB067'), { targetPlayerId: 0, roomIndex: 0 }), true);
    assert.deepEqual(G.players[0].dungeon[0][0].treasures, [1, 1, 2, 3, 4]);
  });

  it('RMB068 Sabotage! deactivates the targeted Room for the turn', () => {
    const { G, ctx } = setup([[room('r1')]], [[room('r2')]]);
    assert.equal(castSpell(G, ctx, 0, spell('RMB068'), { targetPlayerId: 1, roomIndex: 0 }), true);
    assert.deepEqual(G.effects.deactivatedRooms, [{ playerId: 1, roomIndex: 0 }]);
  });

  it('RMB069 Rage! boosts every Miniboss Room by its Level', () => {
    const { G, ctx } = setup([[room('r1')], [room('r2')]]);
    putMb(G, 0, 1, 'RMB060', 2);
    assert.equal(castSpell(G, ctx, 0, spell('RMB069'), {}), true);
    assert.deepEqual(G.effects.roomDamageBonus, [{ playerId: 0, roomIndex: 1, amount: 2 }]);
  });

  it('RMB072 Smash! deals 2 damage to the targeted Hero', () => {
    const { G, ctx } = setup();
    assert.equal(castSpell(G, ctx, 0, spell('RMB072'), { heroId: 'h1' }), true);
    assert.deepEqual(G.effects.heroDamage, [{ heroId: 'h1', amount: 2 }]);
  });

  it('RMB073 Pay to Win adds +1 to a Room in your dungeon', () => {
    const { G, ctx } = setup([[room('r1')]]);
    assert.equal(castSpell(G, ctx, 0, spell('RMB073'), { roomIndex: 0 }), true);
    assert.deepEqual(G.effects.roomDamageBonus, [{ playerId: 0, roomIndex: 0, amount: 1 }]);
  });

  it('RMB075 Respawn resolves without changing the state', () => {
    const { G, ctx } = setup();
    const before = JSON.stringify({ dungeon: G.players[0].dungeon, effects: G.effects });
    assert.equal(castSpell(G, ctx, 0, spell('RMB075'), {}), true);
    assert.ok(G.logs.some((l) => l.startsWith('Respawn:')));
    assert.equal(JSON.stringify({ dungeon: G.players[0].dungeon, effects: G.effects }), before);
  });

  it('RMB076 Heist negates a Room treasure icons for the turn', () => {
    const { G, ctx } = setup([[room('r1', { treasures: [1, 2] })]]);
    assert.equal(castSpell(G, ctx, 0, spell('RMB076'), { targetPlayerId: 0, roomIndex: 0 }), true);
    assert.deepEqual(G.players[0].dungeon[0][0].treasures, []);
  });

  it('RMB077 Short Circuit counters the Spell on top of the stack', () => {
    const { G, ctx } = setup();
    G.stack = [{ type: 'spell', card: { id: 'BMA001', name: 'Doom' }, resolved: false }];
    assert.equal(castSpell(G, ctx, 0, spell('RMB077'), {}), true);
    assert.equal(G.stack[0].resolved, true);
    assert.deepEqual(G.effects.counteredSpells, ['BMA001']);

    const s2 = setup();
    assert.equal(castSpell(s2.G, s2.ctx, 0, spell('RMB077'), {}), false); // nothing to counter
  });

  it('RMB078 Traitor steals an opponent Miniboss for its Level in Coins', () => {
    const { G, ctx } = setup([[room('host')]], [[room('r1')]]);
    putMb(G, 1, 0, 'RMB060', 2);
    G.players[0].coins = 3;
    G.players[1].coins = 0;
    assert.equal(castSpell(G, ctx, 0, spell('RMB078'), { targetPlayerId: 1, roomIndex: 0 }), true);
    assert.equal(G.players[1].dungeon[0].miniboss, undefined);
    assert.equal(G.players[0].dungeon[0].miniboss.card.id, 'RMB060');
    assert.equal(G.players[0].dungeon[0].miniboss.faceDown, false);
    assert.equal(G.players[0].coins, 1); // 3 minus the 2 paid
    assert.equal(G.players[1].coins, 3); // 2 received + Paddywhack passive (+1 when gaining Coins)
    assert.deepEqual(G.effects.noRoomBuild, [0]); // no Room build this turn
  });

  it('RMB079 Armor Up! gives the targeted Hero +1 Health', () => {
    const { G, ctx } = setup();
    assert.equal(castSpell(G, ctx, 0, spell('RMB079'), { heroId: 'h1' }), true);
    assert.deepEqual(G.effects.heroHealthBonus, [{ heroId: 'h1', amount: 1 }]);
  });
});

