import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { setupMatch } from '../server/reducer.js';
import { emptyEffects } from '../src/spellEffects.js';
import { PHASE } from '../src/cardData.js';
import { destroyRoom, roomDamageWithModifiers } from '../src/engine.js';
import { onBuildRoom, activateRoomAbility } from '../src/roomAbilities.js';
import { processExpansionLevelUp, processEndOfTurnBosses } from '../src/expansionBosses.js';

function mk(expansions = ['next-level'], players = 2) {
  const { G, ctx } = setupMatch(players, { expansions });
  G.effects = emptyEffects();
  G.pendingChoice = null;
  G.choiceQueue = [];
  G.decks.roomDiscard = [];
  G.decks.spellDiscard = [];
  G.phase = PHASE.BUILD;
  return { G, ctx };
}

function room(id, name, type = 'trap', damage = 1, treasures = [1], extra = {}) {
  return { id, name, type, damage, treasures, isRoom: true, ...extra };
}

function spell(id, name) {
  return { id, name, isSpell: true };
}

describe('Next Level bosses', () => {
  it('TNL012 Eclipse gives the uncovered Room +3 when you destroy a Room', () => {
    const { G } = mk();
    G.players[0].boss = { id: 'TNL012', name: 'Eclipse', treasures: [1] };
    const under = room('under', 'Covered Room', 'monster', 3, [2]);
    const top = room('top', 'Top Room', 'trap', 1, [1]);
    G.players[0].dungeon = [[under, top]];
    const hero = { id: 'h1', name: 'Hero', hp: 9 };

    assert.equal(processExpansionLevelUp(G, 0, { id: 'TNL012', name: 'Eclipse' }), null);
    assert.equal(G.players[0].azarellaUncover, true);
    destroyRoom(G, 0, 0);
    assert.equal(G.players[0].dungeon.length, 1);
    assert.deepEqual(G.effects.roomDamageBonus, [{ playerId: 0, roomIndex: 0, amount: 3 }]);
    assert.equal(roomDamageWithModifiers(G, 0, 0, hero), under.damage + 3);
  });

  it('TNL012 Eclipse does not boost Rooms destroyed without the ability', () => {
    const { G } = mk();
    G.players[0].dungeon = [[room('under', 'Covered Room', 'monster', 3, [2]), room('top', 'Top Room')]];
    destroyRoom(G, 0, 0);
    assert.deepEqual(G.effects.roomDamageBonus, []);
  });

  it('TNL009 Nicolius draws a Spell when another player gained 2 more Souls', () => {
    const { G } = mk();
    G.players[0].boss = { id: 'TNL009', name: 'Nicolius', treasures: [1] };
    assert.equal(processExpansionLevelUp(G, 0, { id: 'TNL009', name: 'Nicolius' }), null);
    assert.equal(G.players[0].porkusDraw, true);

    G.players[0]._soulsAtTurnStart = 0;
    G.players[1]._soulsAtTurnStart = 0;
    G.players[0].souls = [];
    G.players[1].souls = [{ souls: 2, name: 'A', class: 'Cleric', faceDown: true }, { souls: 1, name: 'B', class: 'Mage', faceDown: true }];
    G.decks.spells = [spell('drawn', 'Drawn Spell')];
    const before = G.players[0].hand.length;
    processEndOfTurnBosses(G);
    assert.equal(G.players[0].hand.length, before + 1);
    assert.equal(G.players[0].hand.at(-1).id, 'drawn');
    assert.ok(G.logs.some((l) => l.startsWith('Nicolius: drew')));
  });

  it('TNL009 Nicolius passes when the Soul gap stays below two', () => {
    const { G } = mk();
    G.players[0].porkusDraw = true;
    G.players[0]._soulsAtTurnStart = 0;
    G.players[1]._soulsAtTurnStart = 0;
    G.players[0].souls = [];
    G.players[1].souls = [{ souls: 1, name: 'A', class: 'Cleric', faceDown: true }];
    G.decks.spells = [spell('drawn', 'Drawn Spell')];
    const before = G.players[0].hand.length;
    processEndOfTurnBosses(G);
    assert.equal(G.players[0].hand.length, before);
    assert.deepEqual(G.decks.spells.length, 1);
  });
});

describe('Next Level rooms (build effects)', () => {
  it('TNL016 Arcane Crypt recovers the only Spell in the discard', () => {
    const { G, ctx } = mk();
    const crypt = room('TNL016', 'Arcane Crypt', 'trap', 2, [1]);
    G.players[0].dungeon = [[crypt]];
    G.decks.spellDiscard = [spell('old', 'Old Spell')];
    const before = G.players[0].hand.length;
    assert.equal(onBuildRoom(G, ctx, 0, crypt), null);
    assert.equal(G.players[0].hand.length, before + 1);
    assert.equal(G.decks.spellDiscard.length, 0);
  });

  it('TNL016 Arcane Crypt asks which Spell to recover when several are there', () => {
    const { G, ctx } = mk();
    const crypt = room('TNL016', 'Arcane Crypt', 'trap', 2, [1]);
    G.players[0].dungeon = [[crypt]];
    G.decks.spellDiscard = [spell('a', 'Spell A'), spell('b', 'Spell B')];
    const choice = onBuildRoom(G, ctx, 0, crypt);
    assert.equal(choice?.type, 'recover-card');
    assert.equal(choice.options.length, 2);
  });

  it('TNL024 Barbarian Hall discards the only Spell in hand', () => {
    const { G, ctx } = mk();
    const hall = room('TNL024', 'Barbarian Hall', 'monster', 3, [2]);
    G.players[0].dungeon = [[hall]];
    G.players[0].hand = [spell('s1', 'Lone Spell'), room('r1', 'Room Card')];
    assert.equal(onBuildRoom(G, ctx, 0, hall), null);
    assert.equal(G.players[0].hand.length, 1);
    assert.equal(G.players[0].hand[0].id, 'r1');
    assert.equal(G.decks.spellDiscard.length, 1);
  });

  it('TNL024 Barbarian Hall asks which Spell to discard with several in hand', () => {
    const { G, ctx } = mk();
    const hall = room('TNL024', 'Barbarian Hall', 'monster', 3, [2]);
    G.players[0].dungeon = [[hall]];
    G.players[0].hand = [spell('s1', 'Spell One'), spell('s2', 'Spell Two')];
    const choice = onBuildRoom(G, ctx, 0, hall);
    assert.equal(choice?.type, 'discard-spell');
    assert.equal(choice.options.length, 2);
    assert.equal(G.players[0].hand.length, 2);
  });

  it('TNL027 Shrooman Cave boosts the only other Monster Room', () => {
    const { G, ctx } = mk();
    const cave = room('TNL027', 'Shrooman Cave', 'monster', 2, [1]);
    const other = room('other', 'Other Monster', 'monster', 4, [3]);
    G.players[0].dungeon = [[cave], [other]];
    assert.equal(onBuildRoom(G, ctx, 0, cave), null);
    assert.deepEqual(G.effects.roomDamageBonus, [{ playerId: 0, roomIndex: 1, amount: 3 }]);
  });

  it('TNL027 Shrooman Cave asks which Monster Room to boost with several', () => {
    const { G, ctx } = mk();
    const cave = room('TNL027', 'Shrooman Cave', 'monster', 2, [1]);
    G.players[0].dungeon = [[cave], [room('m1', 'Monster 1', 'monster', 4, [3])], [room('m2', 'Monster 2', 'monster', 4, [3])]];
    const choice = onBuildRoom(G, ctx, 0, cave);
    assert.equal(choice?.type, 'boost-monster-room');
    assert.equal(choice.options.length, 2);
    assert.deepEqual(G.effects.roomDamageBonus, []);
  });

  it('TNL029 Megaworm Burrow destroys the only Advanced Room in play', () => {
    const { G, ctx } = mk();
    const burrow = room('TNL029', 'Megaworm Burrow', 'monster', 3, [2]);
    const victim = room('adv', 'Advanced Victim', 'trap', 4, [3], { advanced: true });
    G.players[0].dungeon = [[burrow]];
    G.players[1].dungeon = [[victim]];
    assert.equal(onBuildRoom(G, ctx, 0, burrow), null);
    assert.equal(G.players[1].dungeon.length, 0);
    assert.equal(G.decks.roomDiscard.length, 1);
  });

  it('TNL029 Megaworm Burrow asks which Advanced Room to destroy', () => {
    const { G, ctx } = mk();
    const burrow = room('TNL029', 'Megaworm Burrow', 'monster', 3, [2]);
    G.players[0].dungeon = [[burrow]];
    G.players[1].dungeon = [
      [room('advA', 'Advanced A', 'trap', 4, [3], { advanced: true })],
      [room('advB', 'Advanced B', 'trap', 4, [3], { advanced: true })],
    ];
    const choice = onBuildRoom(G, ctx, 0, burrow);
    assert.equal(choice?.type, 'destroy-room');
    assert.equal(choice.options.length, 2);
    assert.equal(G.players[1].dungeon.length, 2);
  });

  it('TNL036 Sorcerobe School draws a Spell on build', () => {
    const { G, ctx } = mk();
    const robe = room('TNL036', 'Sorcerobe School', 'trap', 2, [1]);
    G.players[0].dungeon = [[robe]];
    G.decks.spells = [spell('drawn', 'Drawn Spell')];
    const before = G.players[0].hand.length;
    onBuildRoom(G, ctx, 0, robe);
    assert.equal(G.players[0].hand.length, before + 1);
    assert.equal(G.players[0].hand.at(-1).id, 'drawn');
  });

  it('TNL052 Genie Lounge draws only when no Spell is in hand', () => {
    const { G, ctx } = mk();
    const lounge = room('TNL052', 'Genie Lounge', 'trap', 2, [1]);
    G.players[0].dungeon = [[lounge]];
    G.decks.spells = [spell('drawn', 'Drawn Spell')];
    G.players[0].hand = [room('r1', 'Room Card')];
    onBuildRoom(G, ctx, 0, lounge);
    assert.equal(G.players[0].hand.length, 2);
    assert.equal(G.players[0].hand.at(-1).id, 'drawn');

    G.players[0].hand = [spell('s1', 'Existing Spell')];
    onBuildRoom(G, ctx, 0, lounge);
    assert.equal(G.players[0].hand.length, 1);
  });
});

describe('Next Level rooms (activated abilities)', () => {
  it('TNL013 Dark Portal discards a Spell to recover a Room from the discard', () => {
    const { G, ctx } = mk();
    const portal = room('TNL013', 'Dark Portal', 'trap', 2, [1]);
    G.players[0].dungeon = [[portal]];
    G.players[0].hand = [spell('s1', 'Cost Spell'), room('r1', 'Hand Room')];
    G.decks.roomDiscard = [room('rec', 'Recovered Room')];
    assert.equal(activateRoomAbility(G, ctx, 0, 0), null);
    assert.deepEqual(G.players[0].hand.map((c) => c.id), ['r1', 'rec']);
    assert.equal(G.decks.spellDiscard.length, 1);
    assert.equal(G.decks.roomDiscard.length, 0);
    assert.equal(portal.usedThisTurn, true);
  });

  it('TNL013 Dark Portal refuses without a Spell in hand', () => {
    const { G, ctx } = mk();
    const portal = room('TNL013', 'Dark Portal', 'trap', 2, [1]);
    G.players[0].dungeon = [[portal]];
    G.players[0].hand = [room('r1', 'Hand Room')];
    assert.equal(activateRoomAbility(G, ctx, 0, 0), 'no spell to discard');
    assert.equal(portal.usedThisTurn, undefined);
  });

  it('TNL032 Lost Library destroys itself, draws two Spells and asks to discard one', () => {
    const { G, ctx } = mk();
    const lib = room('TNL032', 'Lost Library', 'trap', 2, [1]);
    G.players[0].dungeon = [[lib]];
    G.decks.spells = [spell('a', 'Spell A'), spell('b', 'Spell B')];
    const before = G.players[0].hand.length;
    assert.equal(activateRoomAbility(G, ctx, 0, 0), null);
    assert.equal(G.players[0].dungeon.length, 0);
    assert.equal(G.players[0].hand.length, before + 2);
    assert.equal(G.pendingChoice?.type, 'discard-spell');
    assert.equal(G.pendingChoice.options.length, 2);
  });

  it('TNL035 Observatory discards a Spell to draw a Spell', () => {
    const { G, ctx } = mk();
    const obs = room('TNL035', 'Observatory', 'trap', 2, [1]);
    G.players[0].dungeon = [[obs]];
    G.players[0].hand = [spell('s1', 'Old Spell')];
    G.decks.spells = [spell('new', 'Fresh Spell')];
    assert.equal(activateRoomAbility(G, ctx, 0, 0), null);
    assert.deepEqual(G.players[0].hand.map((c) => c.id), ['new']);
    assert.equal(G.decks.spellDiscard.length, 1);
    assert.equal(obs.usedThisTurn, true);
  });

  it('TNL055 Save Point destroys itself to recover a Spell from the discard', () => {
    const { G, ctx } = mk();
    const save = room('TNL055', 'Save Point', 'trap', 2, [1]);
    G.players[0].dungeon = [[save]];
    G.decks.spellDiscard = [spell('old', 'Played Spell')];
    assert.equal(activateRoomAbility(G, ctx, 0, 0), null);
    assert.equal(G.players[0].dungeon.length, 0);
    assert.deepEqual(G.players[0].hand.map((c) => c.id), ['old']);
    assert.equal(G.decks.spellDiscard.length, 0);
  });

  it('TNL041 Wreck Room destroys another Room and draws a Room card', () => {
    const { G, ctx } = mk();
    const wreck = room('TNL041', 'Wreck Room', 'trap', 2, [1]);
    const victim = room('victim', 'Victim Room', 'monster', 3, [2]);
    G.players[0].dungeon = [[wreck], [victim]];
    G.decks.rooms = [room('deck', 'Deck Room')];
    assert.equal(activateRoomAbility(G, ctx, 0, 0), 'must target another room');
    assert.equal(activateRoomAbility(G, ctx, 0, 0, 1), null);
    assert.equal(G.players[0].dungeon.length, 1);
    assert.equal(G.players[0].hand.at(-1).id, 'deck');
    assert.equal(wreck.usedThisTurn, true);
  });

  it('TNL042 Deadly Treadmill discards a Room card to draw a Room card', () => {
    const { G, ctx } = mk();
    const mill = room('TNL042', 'Deadly Treadmill', 'trap', 2, [1]);
    G.players[0].dungeon = [[mill]];
    G.players[0].hand = [room('r1', 'Hand Room')];
    G.decks.rooms = [room('deck', 'Deck Room')];
    assert.equal(activateRoomAbility(G, ctx, 0, 0), null);
    assert.deepEqual(G.players[0].hand.map((c) => c.id), ['deck']);
    assert.equal(G.decks.roomDiscard.length, 1);
    assert.equal(mill.usedThisTurn, true);
  });

  it('TNL045 Decapitator only works during the Build phase', () => {
    const { G, ctx } = mk();
    const dec = room('TNL045', 'Decapitator', 'trap', 2, [1]);
    G.players[0].dungeon = [[dec]];
    G.players[1].dungeon = [[room('other', 'Other Room', 'trap', 1, [3])]];
    G.phase = PHASE.ADVENTURE;
    assert.equal(activateRoomAbility(G, ctx, 0, 0), 'Build phase only');
    G.phase = PHASE.BUILD;
    assert.equal(activateRoomAbility(G, ctx, 0, 0), null);
    assert.equal(G.players[0].dungeon.length, 0);
    assert.deepEqual(G.effects.roomTreasureSuppressed, [{ playerId: 1, roomIndex: 0 }]);
  });

  it('TNL046 Chump Chomper destroys another Room and gains +4 until end of turn', () => {
    const { G, ctx } = mk();
    const chomper = room('TNL046', 'Chump Chomper', 'trap', 3, [1]);
    const snack = room('snack', 'Snack Room', 'monster', 2, [1]);
    G.players[0].dungeon = [[chomper], [snack]];
    assert.equal(activateRoomAbility(G, ctx, 0, 0), 'must target another room');
    assert.equal(activateRoomAbility(G, ctx, 0, 0, 1), null);
    assert.equal(G.players[0].dungeon.length, 1);
    assert.deepEqual(G.effects.roomDamageBonus, [{ playerId: 0, roomIndex: 0, amount: 4 }]);
    assert.equal(chomper.usedThisTurn, true);
  });

  it('TNL033 Frostbat Cave destroys itself to deactivate the remaining Room', () => {
    const { G, ctx } = mk();
    const frost = room('TNL033', 'Frostbat Cave', 'trap', 2, [1]);
    G.players[0].dungeon = [[frost]];
    G.players[1].dungeon = [[room('target', 'Target Room', 'monster', 4, [3])]];
    assert.equal(activateRoomAbility(G, ctx, 0, 0), null);
    assert.equal(G.players[0].dungeon.length, 0);
    assert.deepEqual(G.effects.deactivatedRooms, [{ playerId: 1, roomIndex: 0 }]);
  });

  it('TNL049 Warp Tube destroys itself and sends the Hero back to the first Room', () => {
    const { G, ctx } = mk();
    const tube = room('TNL049', 'Warp Tube', 'trap', 2, [1]);
    G.players[0].dungeon = [[tube], [room('first', 'First Room', 'monster', 3, [2])]];
    G.adventure = { playerId: 0, roomIndex: 1, hero: { id: 'h1', name: 'Knight' }, hp: 5 };
    assert.equal(activateRoomAbility(G, ctx, 0, 0), 'no hero in this room');
    G.adventure.roomIndex = 0;
    assert.equal(activateRoomAbility(G, ctx, 0, 0), null);
    assert.equal(G.adventure.roomIndex, -1);
    assert.equal(G.players[0].dungeon.length, 1);
  });

  it('TNL030 The Arena gains the power of the revealed Monster Room', () => {
    const { G, ctx } = mk();
    const arena = room('TNL030', 'The Arena', 'trap', 2, [1]);
    G.players[0].dungeon = [[arena]];
    G.players[0].hand = [room('m', 'Revealed Monster', 'monster', 7, [2])];
    assert.equal(activateRoomAbility(G, ctx, 0, 0), null);
    assert.deepEqual(G.effects.roomDamageBonus, [{ playerId: 0, roomIndex: 0, amount: 7 }]);
    assert.equal(arena.usedThisTurn, true);
    assert.deepEqual(G.players[0].hand.map((c) => c.id), ['m']);
  });

  it('TNL022 Rust Monster Pen debuffs the only Trap Room after discarding a Monster', () => {
    const { G, ctx } = mk();
    const pen = room('TNL022', 'Rust Monster Pen', 'trap', 3, [2]);
    G.players[0].dungeon = [[pen]];
    G.players[0].hand = [room('m', 'Monster Card', 'monster', 4, [2])];
    assert.equal(activateRoomAbility(G, ctx, 0, 0), null);
    assert.deepEqual(G.effects.roomDamageBonus, [{ playerId: 0, roomIndex: 0, amount: -1 }]);
    assert.deepEqual(G.players[0].hand.map((c) => c.id), []);
    assert.equal(G.decks.roomDiscard.length, 1);
  });

  it('TNL040 Bullet Builder debuffs the only Monster Room after discarding a Trap', () => {
    const { G, ctx } = mk();
    const bullet = room('TNL040', 'Bullet Builder', 'monster', 4, [2]);
    G.players[0].dungeon = [[bullet]];
    G.players[0].hand = [room('t', 'Trap Card', 'trap', 3, [2])];
    assert.equal(activateRoomAbility(G, ctx, 0, 0), null);
    assert.deepEqual(G.effects.roomDamageBonus, [{ playerId: 0, roomIndex: 0, amount: -1 }]);
    assert.equal(G.players[0].hand.length, 0);
    assert.equal(G.decks.roomDiscard.length, 1);
  });
});
