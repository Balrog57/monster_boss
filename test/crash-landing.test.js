import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { setupMatch } from '../server/reducer.js';
import { castSpell, emptyEffects } from '../src/spellEffects.js';
import { PHASE } from '../src/cardData.js';
import {
  applyRoomUncovered,
  isRoomDeactivated,
  roomDamageWithModifiers,
} from '../src/engine.js';
import {
  processLevelUp,
  onBuildRoom,
  activateRoomAbility,
  resolveLevelUpChoice,
} from '../src/roomAbilities.js';
import {
  processExpansionLevelUp,
  resolveExpansionLevelUpChoice,
  onExpansionBossKill,
} from '../src/expansionBosses.js';
import { canUseHandRoom, useHandRoomAbility } from '../src/handAbilities.js';

function mk(expansions = ['crash-landing'], players = 2) {
  const { G, ctx } = setupMatch(players, { expansions });
  G.effects = emptyEffects();
  G.pendingChoice = null;
  G.choiceQueue = [];
  G.decks.roomDiscard = [];
  G.decks.spellDiscard = [];
  G.decks.heroDiscard = G.decks.heroDiscard || [];
  G.phase = PHASE.BUILD;
  return { G, ctx };
}

function room(id, name, type = 'trap', damage = 1, treasures = [1], extra = {}) {
  return { id, name, type, damage, treasures, isRoom: true, ...extra };
}

function spell(id, name) {
  return { id, name, isSpell: true };
}

function wound(name = 'Wound', cls = 'Fighter') {
  return { souls: 1, name, class: cls };
}

describe('Crash Landing bosses', () => {
  it('CRL001 Imperiatrix adds +1 damage per Explorer treasure icon', () => {
    const { G } = mk();
    G.players[0].boss = { id: 'CRL001', name: 'Imperiatrix', treasures: [1] };
    G.players[0].dungeon = [[room('ex', 'Explorer Hall', 'trap', 2, [5, 5])]];
    const hero = { id: 'h1', name: 'Hero', hp: 6 };
    const before = roomDamageWithModifiers(G, 0, 0, hero);
    assert.equal(processExpansionLevelUp(G, 0, { id: 'CRL001', name: 'Imperiatrix' }), null);
    assert.equal(G.players[0].imperiatrix, true);
    assert.equal(roomDamageWithModifiers(G, 0, 0, hero), before + 2);

    G.players[0].dungeon = [[room('noexp', 'Plain Hall', 'trap', 2, [1])]];
    assert.equal(roomDamageWithModifiers(G, 0, 0, hero), before);
  });

  it('CRL002 Klonos copies a lone opponent Boss Level Up ability immediately', () => {
    const { G } = mk();
    G.players[1].boss = { id: 'RMB001', name: 'Gregore', treasures: [1] };
    G.players[0].boss = { id: 'CRL002', name: 'Klonos', treasures: [1] };
    G.players[0].coins = 0;
    assert.equal(processExpansionLevelUp(G, 0, { id: 'CRL002', name: 'Klonos' }), null);
    assert.equal(G.players[0].copiedLevelUp, 'RMB001');
    assert.equal(G.players[0].gregoreCoin, true);

    onExpansionBossKill(G, 0, { miniboss: false });
    assert.equal(G.players[0].coins, 1);
    onExpansionBossKill(G, 0, { miniboss: false });
    assert.equal(G.players[0].coins, 1); // once per turn
  });

  it('CRL002 Klonos asks which Boss to copy when several are in play', () => {
    const { G, ctx } = mk(['crash-landing'], 3);
    G.players[0].boss = { id: 'CRL002', name: 'Klonos', treasures: [1] };
    G.players[1].boss = { id: 'RMB001', name: 'Gregore', treasures: [1] };
    G.players[2].boss = { id: 'TNL004', name: 'Killa', treasures: [1] };
    G.players[2].wounds = [wound()];
    G.players[0].wounds = [wound(), wound(), wound()];

    const choice = processLevelUp(G, ctx, 0);
    assert.ok(choice);
    assert.equal(choice.type, 'pick-boss-levelup');
    assert.equal(choice.options.length, 2);

    G.pendingChoice = choice;
    assert.equal(resolveLevelUpChoice(G, ctx, 0, 1), null);
    assert.equal(G.pendingChoice, null);
    assert.equal(G.players[0].copiedLevelUp, 'TNL004');
    assert.equal(G.players[0].killaBoost, true);
    assert.equal(G.players[0].gregoreCoin, undefined);
  });

  it('CRL002 Klonos queues the copied ability\'s own choice', () => {
    const { G, ctx } = mk(['crash-landing', 'next-level'], 3);
    G.players[0].boss = { id: 'CRL002', name: 'Klonos', treasures: [1] };
    G.players[1].boss = { id: 'TNL000', name: 'Mirrax', treasures: [3] };
    G.players[2].boss = { id: 'RMB001', name: 'Gregore', treasures: [1] };

    const choice = processLevelUp(G, ctx, 0);
    assert.equal(choice?.type, 'pick-boss-levelup');
    G.pendingChoice = choice;
    assert.equal(resolveLevelUpChoice(G, ctx, 0, 0), null);
    assert.equal(G.players[0].copiedLevelUp, 'TNL000');
    assert.equal(G.pendingChoice?.type, 'pick-boss-treasure');

    assert.equal(resolveLevelUpChoice(G, ctx, 0, 0), null);
    assert.equal(G.pendingChoice, null);
    assert.ok(G.players[0].bonusTreasures?.length >= 1);
  });

  it('CRL002 Klonos cannot copy Klonos', () => {
    const { G } = mk();
    G.players[0].boss = { id: 'CRL002', name: 'Klonos', treasures: [1] };
    G.players[1].boss = { id: 'CRL002', name: 'Klonos', treasures: [1] };
    assert.equal(processExpansionLevelUp(G, 0, { id: 'CRL002', name: 'Klonos' }), null);
    assert.equal(G.players[0].copiedLevelUp, undefined);
    assert.ok(G.logs.some((l) => l.includes('no Boss to copy')));
  });

  it('CRL003 Mando brings a covered Room to the top of an opponent stack', () => {
    const { G } = mk();
    G.players[1].dungeon = [[room('cov', 'Covered Room', 'monster', 4, [3]), room('top', 'Top Room')]];
    const choice = processExpansionLevelUp(G, 0, { id: 'CRL003', name: 'Mando' });
    assert.ok(choice);
    assert.equal(choice.type, 'uncover-room');
    assert.equal(choice.options.length, 1);
    resolveExpansionLevelUpChoice(G, choice, 0);
    assert.deepEqual(G.players[1].dungeon[0].map((r) => r.id), ['top', 'cov']);
  });

  it('CRL003 Mando has nothing to do without covered Rooms', () => {
    const { G } = mk();
    G.players[1].dungeon = [[room('only', 'Only Room')]];
    assert.equal(processExpansionLevelUp(G, 0, { id: 'CRL003', name: 'Mando' }), null);
    assert.ok(G.logs.some((l) => l.includes('no covered Rooms')));
  });
});

describe('Crash Landing rooms', () => {
  it('CRL007 Frostman Lander discards from hand to deactivate an Advanced Room', () => {
    const { G, ctx } = mk();
    G.players[0].hand = [room('CRL007', 'Frostman Lander', 'trap', 2, [4], { advanced: true })];
    G.players[1].dungeon = [[room('adv', 'Advanced Target', 'monster', 5, [3], { advanced: true })]];
    assert.equal(canUseHandRoom(G, 0, 0), true);
    useHandRoomAbility(G, ctx, 0, 0, { playerId: 1, roomIndex: 0 });
    assert.equal(G.players[0].hand.length, 0);
    assert.equal(G.decks.roomDiscard.length, 1);
    assert.deepEqual(G.effects.deactivatedRooms, [{ playerId: 1, roomIndex: 0 }]);
    assert.equal(isRoomDeactivated(G, 1, 0), true);
  });

  it('CRL010 Digicron Library draws 2 Spells with another Advanced Room built', () => {
    const { G, ctx } = mk();
    const lib = room('CRL010', 'Digicron Library', 'trap', 2, [1], { advanced: true });
    const other = room('adv2', 'Other Advanced', 'monster', 3, [2], { advanced: true });
    G.players[0].dungeon = [[lib], [other]];
    const before = G.players[0].hand.length;
    assert.equal(onBuildRoom(G, ctx, 0, lib), null);
    assert.equal(G.players[0].hand.length, before + 2);
  });

  it('CRL010 Digicron Library draws nothing without another Advanced Room', () => {
    const { G, ctx } = mk();
    const lib = room('CRL010', 'Digicron Library', 'trap', 2, [1], { advanced: true });
    G.players[0].dungeon = [[lib]];
    const before = G.players[0].hand.length;
    onBuildRoom(G, ctx, 0, lib);
    assert.equal(G.players[0].hand.length, before);
  });

  it('CRL012 The Omega 42 discards an Advanced Room to re-fire a Room effect', () => {
    const { G, ctx } = mk();
    const omega = room('CRL012', 'The Omega 42', 'trap', 2, [1], { advanced: true });
    G.players[0].dungeon = [[omega]];
    G.players[0].hand = [
      room('spare', 'Spare Advanced', 'monster', 2, [1], { advanced: true }),
      spell('s1', 'Ordinary Spell'),
    ];
    assert.equal(activateRoomAbility(G, ctx, 0, 0), null);
    assert.equal(G.players[0].hand.length, 1);
    assert.equal(G.decks.roomDiscard.length, 1);
    assert.equal(omega.usedThisTurn, true);
    assert.ok(G.logs.some((l) => l.includes('Omega 42')));
  });

  it('CRL012 The Omega 42 refuses without an Advanced Room in hand', () => {
    const { G, ctx } = mk();
    const omega = room('CRL012', 'The Omega 42', 'trap', 2, [1], { advanced: true });
    G.players[0].dungeon = [[omega]];
    G.players[0].hand = [spell('s1', 'Ordinary Spell')];
    assert.equal(activateRoomAbility(G, ctx, 0, 0), 'no Advanced Room to discard');
    assert.equal(G.decks.roomDiscard.length, 0);
  });

  it('CRL013 Crash Site recovers the only Advanced Room from the discard', () => {
    const { G } = mk();
    const site = room('CRL013', 'Crash Site', 'trap', 2, [1], { advanced: true });
    const recovered = room('adv3', 'Recovered Advanced', 'monster', 4, [3], { advanced: true });
    G.players[0].dungeon = [[site]];
    G.decks.roomDiscard = [recovered, room('plain', 'Plain Room')];
    const before = G.players[0].hand.length;
    applyRoomUncovered(G, 0, 0, site);
    assert.equal(G.players[0].hand.length, before + 1);
    assert.equal(G.players[0].hand.at(-1).id, 'adv3');
    assert.equal(G.decks.roomDiscard.length, 1);
  });

  it('CRL013 Crash Site asks which Advanced Room to recover when several are there', () => {
    const { G } = mk();
    const site = room('CRL013', 'Crash Site', 'trap', 2, [1], { advanced: true });
    G.players[0].dungeon = [[site]];
    G.decks.roomDiscard = [
      room('advA', 'Advanced A', 'monster', 3, [2], { advanced: true }),
      room('advB', 'Advanced B', 'trap', 3, [2], { advanced: true }),
    ];
    applyRoomUncovered(G, 0, 0, site);
    assert.equal(G.pendingChoice?.type, 'recover-card');
    assert.equal(G.pendingChoice.options.length, 2);
  });

  it('CRL015 Celestial Map draws a Spell then destroys itself', () => {
    const { G } = mk();
    const map = room('CRL015', 'Celestial Map', 'trap', 1, [1], { advanced: true });
    G.players[0].dungeon = [[map]];
    G.decks.spells = [spell('drawn', 'Drawn Spell')];
    const before = G.players[0].hand.length;
    applyRoomUncovered(G, 0, 0, map);
    assert.equal(G.players[0].hand.length, before + 1);
    assert.equal(G.players[0].hand.at(-1).id, 'drawn');
    assert.equal(G.players[0].dungeon.length, 0);
  });

  it('CRL016 Darkling Lair deals 3 damage to the Hero at the entrance', () => {
    const { G } = mk();
    const lair = room('CRL016', 'Darkling Lair', 'trap', 2, [1], { advanced: true });
    G.players[0].dungeon = [[lair]];
    G.players[0].entrance = [{ id: 'h1', name: 'Explorer', hp: 5 }];
    applyRoomUncovered(G, 0, 0, lair);
    assert.equal(G.players[0].entrance[0]._entranceHp, 2);
  });

  it('CRL016 Darkling Lair kills a wounded Hero at the entrance', () => {
    const { G } = mk();
    const lair = room('CRL016', 'Darkling Lair', 'trap', 2, [1], { advanced: true });
    G.players[0].dungeon = [[lair]];
    G.players[0].entrance = [{ id: 'h1', name: 'Explorer', hp: 2 }];
    applyRoomUncovered(G, 0, 0, lair);
    assert.equal(G.players[0].entrance.length, 0);
    assert.equal(G.decks.heroDiscard.length, 1);
  });

  it('CRL016 Darkling Lair deals 3 damage to the Hero in play', () => {
    const { G } = mk();
    const lair = room('CRL016', 'Darkling Lair', 'trap', 2, [1], { advanced: true });
    G.players[0].dungeon = [[lair]];
    G.adventure = { playerId: 0, hero: { id: 'h2', name: 'Knight' }, hp: 5, room: lair };
    applyRoomUncovered(G, 0, 0, lair);
    assert.equal(G.adventure.hp, 2);
  });
});

describe('Crash Landing spells', () => {
  it('CRL029 Finish Him! marks the chosen Hero for lethal damage', () => {
    const { G, ctx } = mk();
    const ok = castSpell(G, ctx, 0, spell('CRL029', 'Finish Him!'), { heroId: 'h1' });
    assert.equal(ok, true);
    assert.deepEqual(G.effects.heroDamage, [{ heroId: 'h1', amount: 99 }]);
  });

  it('CRL029 Finish Him! fails without a target', () => {
    const { G, ctx } = mk();
    assert.equal(castSpell(G, ctx, 0, spell('CRL029', 'Finish Him!'), {}), false);
    assert.deepEqual(G.effects.heroDamage, []);
  });

  it('CRL030 Essence Transfer adds one Health per Wound the caster has', () => {
    const { G, ctx } = mk();
    G.players[0].wounds = [wound('W1'), wound('W2', 'Cleric')];
    assert.equal(castSpell(G, ctx, 0, spell('CRL030', 'Essence Transfer'), { heroId: 'h1' }), true);
    assert.deepEqual(G.effects.heroHealthBonus, [{ heroId: 'h1', amount: 2 }]);
  });

  it('CRL030 Essence Transfer fails with no Wounds', () => {
    const { G, ctx } = mk();
    G.players[0].wounds = [];
    assert.equal(castSpell(G, ctx, 0, spell('CRL030', 'Essence Transfer'), { heroId: 'h1' }), false);
    assert.deepEqual(G.effects.heroHealthBonus, []);
  });

  it('CRL031 Healing Tank heals one ordinary Wound into a Soul', () => {
    const { G, ctx } = mk();
    G.players[0].wounds = [wound('Wounded Mage', 'Mage')];
    G.players[0].souls = [];
    assert.equal(castSpell(G, ctx, 0, spell('CRL031', 'Healing Tank'), {}), true);
    assert.equal(G.players[0].wounds.length, 0);
    assert.equal(G.players[0].souls.length, 1);
    assert.equal(G.players[0].souls[0].name, 'Wounded Mage');
    assert.ok(G.logs.some((l) => l.includes('Healing Tank: healed')));
  });

  it('CRL032 Meteorite grants Explorer treasure to a Room until end of turn', () => {
    const { G, ctx } = mk();
    G.players[1].dungeon = [[room('victim', 'Victim Room', 'trap', 1, [1])]];
    assert.equal(
      castSpell(G, ctx, 0, spell('CRL032', 'Meteorite'), { targetPlayerId: 1, roomIndex: 0 }),
      true,
    );
    assert.deepEqual(G.players[1].dungeon[0][0].treasures, [1, 5]);
  });
});
