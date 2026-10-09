import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { setupMatch } from '../../src/backend/game/reducer.js';
import { castSpell, emptyEffects } from '../../src/backend/game/spellEffects.js';
import { totalSouls } from '../../src/backend/game/cardData.js';
import { resolveBait, treasureCount, roomDamageWithModifiers } from '../../src/backend/game/engine.js';
import { processLevelUp, resolveLevelUpChoice, activateRoomAbility } from '../../src/backend/game/roomAbilities.js';
import {
  applyItemReward,
  applyItemSurvivePowerUp,
  applyHeroEnterDungeon,
  onHeroEnterRoom,
  onHeroSurvivedRoom,
} from '../../src/backend/game/items.js';

function mk(expansions = ['tools', 'players-choice']) {
  const { G, ctx } = setupMatch(2, { expansions });
  G.effects = emptyEffects();
  G.pendingChoice = null;
  G.choiceQueue = [];
  G.decks.roomDiscard = [];
  G.decks.spellDiscard = [];
  return { G, ctx };
}

function room(id, name, type = 'trap', damage = 1, treasures = [1], extra = {}) {
  return { id, name, type, damage, treasures, isRoom: true, ...extra };
}

describe('Tools of Hero-Kind items', () => {
  it('THK002 Holy Hand Grenade discards Rooms on reward and on survive', () => {
    const { G } = mk();
    G.players[1].hand = [
      { id: 'r1', name: 'Room A', isRoom: true },
      { id: 's1', name: 'Spell A', isSpell: true },
    ];
    applyItemReward(G, 0, { id: 'THK002', name: 'Holy Hand Grenade' });
    assert.equal(G.players[1].hand.length, 1);
    assert.equal(G.players[1].hand[0].isSpell, true);
    assert.equal(G.decks.roomDiscard.length, 1);

    G.players[0].hand = [
      { id: 'r2', name: 'Room B', isRoom: true },
      { id: 'r3', name: 'Room C', isRoom: true },
      { id: 's2', name: 'Spell B', isSpell: true },
    ];
    applyItemSurvivePowerUp(G, 0, { id: 'h1', name: 'Hero', item: { id: 'THK002' } });
    assert.equal(G.players[0].hand.length, 1);
    assert.equal(G.players[0].hand[0].isSpell, true);
  });

  it('THK003 Inquisitor\'s Robes destroys the first Advanced Room survived', () => {
    const { G } = mk();
    const adv = room('adv1', 'Advanced Trap', 'trap', 2, [4], { advanced: true });
    G.players[0].dungeon = [[adv]];
    applyItemReward(G, 0, { id: 'THK003', name: "Inquisitor's Robes" });
    assert.equal(G.players[0].dungeon.length, 0);

    const adv2 = room('adv2', 'Advanced Trap 2', 'monster', 3, [2], { advanced: true });
    G.players[0].dungeon = [[adv2]];
    const hero = { id: 'h1', name: 'Hero', item: { id: 'THK003' } };
    onHeroSurvivedRoom(G, 0, 0, adv2, hero, null);
    assert.equal(G.players[0].dungeon.length, 0);
    assert.equal(hero._inquisitorFired, true);
  });

  it('THK005 Goblin Suit marks ordinary Monster Rooms for +1 damage', () => {
    const { G } = mk();
    applyItemReward(G, 0, { id: 'THK005', name: 'Goblin Suit' });
    assert.deepEqual(G.effects.ordinaryMonsterBonus, [0]);
  });

  it('THK006 Claws of the Berserker adds +1 Health per Monster Room', () => {
    const { G } = mk();
    G.players[0].dungeon = [
      [room('m1', 'Monster 1', 'monster', 2, [2])],
      [room('m2', 'Monster 2', 'monster', 2, [3])],
    ];
    G.players[0].entrance = [{ id: 'h1', name: 'Hero', hp: 5 }];
    applyItemReward(G, 0, { id: 'THK006', name: 'Claws of the Berserker' });
    assert.ok(G.effects.heroHealthBonus.some((b) => b.heroId === 'h1' && b.amount === 2));
  });

  it('THK007 Oversized Sword gives +5 Health to a Hero in a dungeon', () => {
    const { G } = mk();
    G.players[0].dungeon = [[room('m1', 'Monster', 'monster', 2, [2])]];
    G.players[0].entrance = [{ id: 'h1', name: 'Hero', hp: 5 }];
    applyItemReward(G, 0, { id: 'THK007', name: 'Oversized Sword' });
    assert.ok(G.effects.heroHealthBonus.some((b) => b.heroId === 'h1' && b.amount === 5));
  });

  it('THK008 Vorpal Blade kills a wounded Hero and gains a temp Wound on survive', () => {
    const { G } = mk();
    const victim = { id: 'h1', name: 'Wounded', hp: 6, souls: 1, class: 'Fighter' };
    G.players[1].entrance = [];
    G.adventure = { playerId: 1, hero: victim, hp: 1, roomIndex: 0 };
    applyItemReward(G, 0, { id: 'THK008', name: 'Vorpal Blade' });
    assert.equal(G.adventure, null);
    assert.equal(G.players[1].souls.length, 1);
    assert.ok(G.logs.some((l) => l.includes('Vorpal Blade: killed Wounded')));

    const wounds = G.players[0].wounds.length;
    applyItemSurvivePowerUp(G, 0, { id: 'h2', name: 'Hero', item: { id: 'THK008' } });
    assert.equal(G.players[0].wounds.length, wounds + 1);
    assert.equal(G.players[0].wounds.at(-1).temp, true);
  });

  it('THK009 Antimagic Lizard discards Spells on reward and on survive', () => {
    const { G } = mk();
    G.players[1].hand = [
      { id: 'r1', name: 'Room A', isRoom: true },
      { id: 's1', name: 'Spell A', isSpell: true },
    ];
    applyItemReward(G, 0, { id: 'THK009', name: 'Antimagic Lizard' });
    assert.equal(G.players[1].hand.length, 1);
    assert.equal(G.players[1].hand[0].isRoom, true);
    assert.equal(G.decks.spellDiscard.length, 1);

    G.players[0].hand = [
      { id: 's2', name: 'Spell B', isSpell: true },
      { id: 's3', name: 'Spell C', isSpell: true },
      { id: 'r2', name: 'Room B', isRoom: true },
    ];
    applyItemSurvivePowerUp(G, 0, { id: 'h1', name: 'Hero', item: { id: 'THK009' } });
    assert.equal(G.players[0].hand.length, 1);
    assert.equal(G.players[0].hand[0].isRoom, true);
  });

  it('THK010 Ice Rod deactivates a Room on reward and on survive', () => {
    const { G } = mk();
    G.players[1].dungeon = [[room('opp', 'Opponent Room', 'trap', 2, [1])]];
    applyItemReward(G, 0, { id: 'THK010', name: 'Ice Rod' });
    assert.ok(G.effects.deactivatedRooms.some((e) => e.playerId === 1 && e.roomIndex === 0));

    const own = room('own', 'Own Room', 'trap', 1, [3]);
    G.players[0].dungeon = [[own]];
    onHeroSurvivedRoom(G, 0, 0, own, { id: 'h1', name: 'Hero', item: { id: 'THK010' } }, null);
    assert.ok(G.effects.deactivatedRooms.some((e) => e.playerId === 0 && e.roomIndex === 0));
  });

  it('THK011 Magic Mirror copies a face-up Item reward and reverses the dungeon', () => {
    const { G } = mk();
    G.players[1].items = [{ id: 'THK005', name: 'Goblin Suit', faceDown: false }];
    applyItemReward(G, 0, { id: 'THK011', name: 'Magic Mirror' });
    assert.deepEqual(G.effects.ordinaryMonsterBonus, [0]);

    G.players[0].dungeon = [
      [room('a', 'A', 'monster', 1, [1])],
      [room('b', 'B', 'trap', 1, [2])],
      [room('c', 'C', 'monster', 1, [3])],
    ];
    applyHeroEnterDungeon(G, 0, { id: 'h1', name: 'Hero', item: { id: 'THK011' } });
    assert.equal(G.players[0].dungeon[0][0].id, 'c');
    assert.equal(G.players[0].dungeon[2][0].id, 'a');
  });

  it('THK013 Bag of Holding destroys dual-treasure Rooms and recovers from the discard', () => {
    const { G } = mk();
    const dual = room('dual', 'Dual Room', 'monster', 2, [2, 4]);
    G.players[0].dungeon = [[dual]];
    onHeroSurvivedRoom(G, 0, 0, dual, { id: 'h1', name: 'Hero', item: { id: 'THK013' } }, null);
    assert.equal(G.players[0].dungeon.length, 0);

    G.decks.roomDiscard = [room('back', 'Recovered Room', 'trap', 1, [1, 2])];
    applyItemReward(G, 0, { id: 'THK013', name: 'Bag of Holding' });
    assert.equal(G.players[0].hand.length, 1);
    assert.equal(G.players[0].hand[0].id, 'back');
    assert.equal(G.decks.roomDiscard.length, 0);
  });

  it('THK014 Cheat Code ignores room ability text until end of turn', () => {
    const { G } = mk();
    applyItemReward(G, 0, { id: 'THK014', name: 'Cheat Code' });
    assert.deepEqual(G.effects.ignoreAbilityPids, [0]);
  });

  it('THK015 Ten Foot Pole deactivates the first Trap Room', () => {
    const { G } = mk();
    G.players[0].dungeon = [
      [room('m', 'Monster', 'monster', 2, [2])],
      [room('t', 'Trap', 'trap', 2, [4])],
    ];
    applyItemReward(G, 0, { id: 'THK015', name: 'Ten Foot Pole' });
    assert.ok(G.effects.deactivatedRooms.some((e) => e.playerId === 0 && e.roomIndex === 1));

    G.effects.deactivatedRooms = [];
    applyHeroEnterDungeon(G, 0, { id: 'h1', name: 'Hero', item: { id: 'THK015' } });
    assert.ok(G.effects.deactivatedRooms.some((e) => e.playerId === 0 && e.roomIndex === 1));
  });

  it('THK016 The Bomb destroys the last Room of the dungeon without damage', () => {
    const { G } = mk();
    const last = room('last', 'Last Room', 'trap', 5, [4]);
    G.players[0].dungeon = [[room('m', 'Monster', 'monster', 2, [2])], [last]];
    const res = onHeroEnterRoom(G, 0, 1, last, { id: 'h1', name: 'Hero', item: { id: 'THK016' } });
    assert.equal(res.skipDamage, true);
    assert.equal(G.players[0].dungeon.length, 1);
    assert.ok(G.logs.some((l) => l.includes('The Bomb: destroyed')));
  });

  it('THK017 Boots of Jumping makes the hero ignore the next Room', () => {
    const { G } = mk();
    const adv = { skipNext: false };
    const r = room('t', 'Trap', 'trap', 3, [4]);
    onHeroSurvivedRoom(G, 0, 0, r, { id: 'h1', name: 'Hero', item: { id: 'THK017' } }, adv);
    assert.equal(adv.skipNext, true);
  });

  it('THK018 Pet Monster deactivates the first Monster Room', () => {
    const { G } = mk();
    G.players[0].dungeon = [
      [room('m1', 'Monster 1', 'monster', 3, [2])],
      [room('t', 'Trap', 'trap', 1, [4])],
    ];
    applyItemReward(G, 0, { id: 'THK018', name: 'Pet Monster' });
    assert.ok(G.effects.deactivatedRooms.some((e) => e.playerId === 0 && e.roomIndex === 0));

    G.effects.deactivatedRooms = [];
    applyHeroEnterDungeon(G, 0, { id: 'h1', name: 'Hero', item: { id: 'THK018' } });
    assert.ok(G.effects.deactivatedRooms.some((e) => e.playerId === 0 && e.roomIndex === 0));
  });

  it('THK019 Star of Invulnerability ignores the first three Rooms', () => {
    const { G } = mk();
    G.players[0].dungeon = [
      [room('r1', 'Room 1', 'monster', 4, [2])],
      [room('r2', 'Room 2', 'trap', 4, [4])],
      [room('r3', 'Room 3', 'monster', 4, [3])],
      [room('r4', 'Room 4', 'monster', 4, [1])],
    ];
    const hero = { id: 'h1', name: 'Hero', item: { id: 'THK019' } };
    assert.equal(roomDamageWithModifiers(G, 0, 0, hero), 0);
    assert.equal(roomDamageWithModifiers(G, 0, 2, hero), 0);
    assert.equal(roomDamageWithModifiers(G, 0, 3, hero), 4);

    G.survivorsThisTurn = { 0: [{ id: 'h2', name: 'Sole Survivor' }] };
    applyItemReward(G, 0, { id: 'THK019', name: 'Star of Invulnerability' });
    assert.ok(G.logs.some((l) => l.includes('Star of Invulnerability: Sole Survivor removed')));
  });
});

describe('Tools of Hero-Kind rooms', () => {
  it('THK022 Burial Mound asks to discard two Rooms then flips an Item', () => {
    const { G, ctx } = mk();
    G.players[0].dungeon = [[room('THK022', 'Burial Mound', 'trap', 0, [1], { advanced: true })]];
    G.players[0].hand = [
      { id: 'r1', name: 'Room A', isRoom: true },
      { id: 'r2', name: 'Room B', isRoom: true },
      { id: 's1', name: 'Spell A', isSpell: true },
    ];
    G.players[0].items = [{ id: 'THK001', name: 'Extra Life', faceDown: true }];
    assert.equal(activateRoomAbility(G, ctx, 0, 0, null), null);
    assert.equal(G.pendingChoice.type, 'discard-hand-rooms');
    assert.equal(G.pendingChoice.then, 'flip-item-up');
    assert.equal(G.pendingChoice.options.length, 2);

    G.pendingChoice = null;
    G.players[0].hand = [{ id: 'r1', name: 'Room A', isRoom: true }];
    assert.equal(activateRoomAbility(G, ctx, 0, 0, null), 'not enough rooms in hand');
  });

  it('THK024 Magnetic Ceiling takes the hero Item face-down', () => {
    const { G } = mk();
    const ceiling = room('THK024', 'Magnetic Ceiling', 'trap', 0, [4], { advanced: true });
    G.players[0].dungeon = [[ceiling]];
    const hero = { id: 'h1', name: 'Hero', item: { id: 'THK001', name: 'Extra Life', faceDown: false } };
    onHeroEnterRoom(G, 0, 0, ceiling, hero);
    assert.equal(hero.item, null);
    assert.equal(G.players[0].items.length, 1);
    assert.equal(G.players[0].items[0].id, 'THK001');
    assert.equal(G.players[0].items[0].faceDown, true);
    assert.equal(ceiling.usedThisTurn, true);
  });
});

describe("Player's Choice boss level-ups", () => {
  it('KSA001 Kirax gains Cleric, Fighter and Mage treasure', () => {
    const { G } = mk();
    G.players[0].boss = { id: 'KSA001', name: 'Kirax', treasures: [4], xp: 1000 };
    assert.equal(processLevelUp(G, {}, 0), null);
    assert.deepEqual(G.players[0].boss.treasures, [4, 1, 2, 3]);
    assert.equal(treasureCount(G, 0, 1), 1);
    assert.equal(treasureCount(G, 0, 2), 1);
    assert.equal(treasureCount(G, 0, 3), 1);
    assert.equal(treasureCount(G, 0, 4), 1);
  });

  it('KSA003 The Brothers Wise searches the Spell deck', () => {
    const { G } = mk();
    G.players[0].boss = { id: 'KSA003', name: 'The Brothers Wise', treasures: [3], xp: 700 };
    G.players[0].hand = [];
    G.decks.spells = [
      { id: 's1', name: 'Spell One', isSpell: true },
      { id: 's2', name: 'Spell Two', isSpell: true },
    ];
    const choice = processLevelUp(G, {}, 0);
    assert.equal(choice.type, 'search-spell');
    assert.equal(choice.options.length, 2);
    G.pendingChoice = choice;
    assert.equal(resolveLevelUpChoice(G, {}, 0, 1), null);
    assert.equal(G.players[0].hand.length, 1);
    assert.equal(G.players[0].hand[0].id, 's2');
    assert.equal(G.decks.spells.length, 1);
  });

  it('KSA005 Scythe gives the last Room +3 damage', () => {
    const { G } = mk();
    G.players[0].boss = { id: 'KSA005', name: 'Scythe', treasures: [2], xp: 775 };
    G.players[0].dungeon = [
      [room('m1', 'First', 'monster', 1, [2])],
      [room('m2', 'Last', 'trap', 2, [4])],
    ];
    assert.equal(processLevelUp(G, {}, 0), null);
    assert.equal(G.players[0].scytheBoost, true);
    assert.equal(roomDamageWithModifiers(G, 0, 0, { id: 'h' }), 1);
    assert.equal(roomDamageWithModifiers(G, 0, 1, { id: 'h' }), 5);
  });

  it('KSA006 Jarin scores +1 Soul for the rest of the game', () => {
    const { G } = mk();
    G.players[0].boss = { id: 'KSA006', name: 'Jarin', treasures: [3], xp: 675 };
    G.players[0].souls = [];
    assert.equal(processLevelUp(G, {}, 0), null);
    assert.equal(G.players[0].bonusSouls, 1);
    assert.equal(totalSouls(G.players[0]), 1);
  });

  it('KSA007 Elicon doubles room treasures until end of turn', () => {
    const { G } = mk();
    G.players[0].boss = { id: 'KSA007', name: 'Elicon', treasures: [4], xp: 875 };
    G.players[0].dungeon = [[room('m1', 'Room', 'monster', 2, [1])]];
    assert.equal(treasureCount(G, 0, 1), 1);
    assert.equal(treasureCount(G, 0, 4), 1);
    assert.equal(processLevelUp(G, {}, 0), null);
    assert.ok(G.effects.treasureDoubled.includes(0));
    assert.equal(treasureCount(G, 0, 1), 2);
    assert.equal(treasureCount(G, 0, 4), 2);
  });
});

describe("Player's Choice spell and heroes", () => {
  it('KSA013 T.P.K. is worth two extra Souls with one face-down Soul per class', () => {
    const { G, ctx } = mk();
    G.players[0].souls = [];
    castSpell(G, ctx, 0, { id: 'KSA013', name: 'T.P.K.', isSpell: true }, {});
    assert.equal(G.players[0].souls.length, 1);
    assert.equal(G.players[0].souls[0].tpk, true);
    assert.equal(totalSouls(G.players[0]), 0);

    G.players[0].souls.push(
      { souls: 1, name: 'Cleric', class: 'Cleric', faceDown: true },
      { souls: 1, name: 'Fighter', class: 'Fighter', faceDown: true },
      { souls: 1, name: 'Mage', class: 'Mage', faceDown: false },
      { souls: 1, name: 'Thief', class: 'Thief', faceDown: true },
    );
    assert.equal(totalSouls(G.players[0]), 4); // T.P.K. still worth 0
    G.players[0].souls[3].faceDown = true;
    assert.equal(totalSouls(G.players[0]), 6); // all four classes face-down → +2
  });

  it('KSA014 Demigod is lured to the dungeon with the fewest Wounds', () => {
    const { G } = mk();
    G.town = [{ id: 'KSA014', name: 'Demigod', treasure: 0, hp: 20, class: 'The Fool', souls: 2 }];
    G.players[0].boss = { treasures: [1], xp: 0, name: 'B0' };
    G.players[1].boss = { treasures: [2], xp: 0, name: 'B1' };
    G.players[0].dungeon = [[room('r0', 'Cleric Room', 'trap', 1, [1])]];
    G.players[1].dungeon = [[room('r1', 'Fighter Room', 'monster', 2, [2])]];
    G.players[0].wounds = [];
    G.players[1].wounds = [{ wounds: 1, name: 'Hero' }, { wounds: 1, name: 'Hero 2' }];

    let assignment = resolveBait(G).find((a) => a.hero?.id === 'KSA014' || a.hero?.name === 'Demigod');
    assert.equal(assignment.targetPlayerId, 0);
    assert.equal(assignment.stayInTown, false);

    G.players[1].wounds = [];
    assignment = resolveBait(G).find((a) => a.hero?.name === 'Demigod');
    assert.equal(assignment.stayInTown, true);
  });

  it('KSA016 Monster Hunter lures by Fighter/Cleric treasure and takes -1 from Monster Rooms', () => {
    const { G } = mk();
    G.town = [{ id: 'KSA016', name: 'Monster Hunter', treasure: 1, hp: 13, class: 'Cleric', souls: 2 }];
    G.players[0].boss = { treasures: [1], xp: 0, name: 'B0' };
    G.players[1].boss = { treasures: [4], xp: 0, name: 'B1' };
    G.players[0].dungeon = [[room('m0', 'Monster Room', 'monster', 3, [1])]];
    G.players[1].dungeon = [];

    const assignment = resolveBait(G).find((a) => a.hero?.name === 'Monster Hunter');
    assert.equal(assignment.targetPlayerId, 0);

    assert.equal(roomDamageWithModifiers(G, 0, 0, { id: 'KSA016' }), 2);
    assert.equal(roomDamageWithModifiers(G, 0, 0, { id: 'BMA056' }), 3);
  });
});
