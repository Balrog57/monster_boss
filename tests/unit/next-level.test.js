import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { setupMatch, applyMove, legalMoves } from '../../src/backend/game/reducer.js';
import { castSpell, emptyEffects } from '../../src/backend/game/spellEffects.js';
import { PHASE } from '../../src/backend/game/cardData.js';
import { destroyRoom, roomDamageWithModifiers, resolveBait, discardRoomToPile } from '../../src/backend/game/engine.js';
import { onBuildRoom, activateRoomAbility, resolveLevelUpChoice, aiResolveLevelUpChoice } from '../../src/backend/game/roomAbilities.js';
import { processExpansionLevelUp, processEndOfTurnBosses } from '../../src/backend/game/expansionBosses.js';

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

describe('Next Level spells', () => {
  it('TNL056 All Your Base takes a Room card from the opponent', () => {
    const { G, ctx } = mk();
    G.players[1].hand = [room('steal', 'Stolen Room'), spell('s1', 'Their Spell')];
    assert.equal(castSpell(G, ctx, 0, spell('TNL056', 'All Your Base'), { targetPlayerId: 1 }), true);
    assert.deepEqual(G.players[0].hand.map((c) => c.id), ['steal']);
    assert.deepEqual(G.players[1].hand.map((c) => c.id), ['s1']);
  });

  it('TNL057 Another Castle sends your Hero to an opponent entrance', () => {
    const { G, ctx } = mk();
    G.players[0].entrance = [{ id: 'h1', name: 'Knight', hp: 5 }];
    assert.equal(
      castSpell(G, ctx, 0, spell('TNL057', 'Another Castle'), { heroId: 'h1', targetPlayerId: 1 }),
      true,
    );
    assert.equal(G.players[0].entrance.length, 0);
    assert.deepEqual(G.players[1].entrance.map((h) => h.id), ['h1']);
  });

  it('TNL058 Fairy Fountain deactivates the chosen Room', () => {
    const { G, ctx } = mk();
    assert.equal(
      castSpell(G, ctx, 0, spell('TNL058', 'Fairy Fountain'), { targetPlayerId: 1, roomIndex: 0 }),
      true,
    );
    assert.deepEqual(G.effects.deactivatedRooms, [{ playerId: 1, roomIndex: 0 }]);
  });

  it('TNL059 It\'s On! kills the chosen Hero and needs a target', () => {
    const { G, ctx } = mk();
    assert.equal(castSpell(G, ctx, 0, spell('TNL059', "It's On!"), { heroId: 'h1' }), true);
    assert.deepEqual(G.effects.heroDamage, [{ heroId: 'h1', amount: 99 }]);
    assert.equal(castSpell(G, ctx, 0, spell('TNL059', "It's On!"), {}), false);
  });

  it('TNL060 Hiring Spree draws three Room cards', () => {
    const { G, ctx } = mk();
    G.decks.rooms = [room('d1', 'Deck Room 1'), room('d2', 'Deck Room 2'), room('d3', 'Deck Room 3')];
    const before = G.players[0].hand.length;
    assert.equal(castSpell(G, ctx, 0, spell('TNL060', 'Hiring Spree'), {}), true);
    assert.equal(G.players[0].hand.length, before + 3);
    assert.equal(G.decks.rooms.length, 0);
  });

  it('TNL062 Meddling Kids! silences the chosen Room', () => {
    const { G, ctx } = mk();
    assert.equal(
      castSpell(G, ctx, 0, spell('TNL062', 'Meddling Kids!'), { targetPlayerId: 1, roomIndex: 0 }),
      true,
    );
    assert.deepEqual(G.effects.deactivatedRooms, [{ playerId: 1, roomIndex: 0 }]);
    assert.ok(G.logs.some((l) => l.startsWith('Meddling Kids!')));
  });

  it('TNL063 Oh, Yeah! swaps the first two Rooms of your dungeon', () => {
    const { G, ctx } = mk();
    G.players[0].dungeon = [[room('a', 'Room A')], [room('b', 'Room B')]];
    assert.equal(castSpell(G, ctx, 0, spell('TNL063', 'Oh, Yeah!'), {}), true);
    assert.deepEqual(G.players[0].dungeon.map((s) => s[0].id), ['b', 'a']);
    G.players[0].dungeon = [[room('a', 'Room A')]];
    assert.equal(castSpell(G, ctx, 0, spell('TNL063', 'Oh, Yeah!'), {}), false);
  });

  it('TNL064 Party Up makes Heroes entering your dungeon gain +1 Health', () => {
    const { G, ctx } = mk();
    assert.equal(castSpell(G, ctx, 0, spell('TNL064', 'Party Up'), {}), true);
    assert.deepEqual(G.effects.staffHealingPids, [0]);
  });

  it('TNL065 Pause returns your Hero to the entrance at full Health', () => {
    const { G, ctx } = mk();
    assert.equal(castSpell(G, ctx, 0, spell('TNL065', 'Pause'), {}), false);
    G.adventure = { playerId: 0, roomIndex: 2, hero: { id: 'h1', name: 'Knight', hp: 10 }, hp: 3 };
    assert.equal(castSpell(G, ctx, 0, spell('TNL065', 'Pause'), {}), true);
    assert.equal(G.adventure.hp, 10);
    assert.equal(G.adventure.roomIndex, -1);
    assert.deepEqual(G.effects.noEntry, [0]);
  });

  it('TNL066 Pity removes the Hero from the game', () => {
    const { G, ctx } = mk();
    assert.equal(castSpell(G, ctx, 0, spell('TNL066', 'Pity'), { heroId: 'h1' }), false);
    G.players[1].entrance = [{ id: 'h1', name: 'Knight', hp: 5 }];
    G.adventure = { playerId: 1, roomIndex: 0, hero: { id: 'h1', name: 'Knight', hp: 5 }, hp: 5 };
    assert.equal(castSpell(G, ctx, 0, spell('TNL066', 'Pity'), { heroId: 'h1' }), true);
    assert.equal(G.adventure, null);
    assert.equal(G.players[1].entrance.length, 0);
  });

  it('TNL067 Secret Stash adds one of each treasure icon to a Room', () => {
    const { G, ctx } = mk();
    G.players[0].dungeon = [[room('stashed', 'Stashed Room', 'trap', 2, [1])]];
    assert.equal(
      castSpell(G, ctx, 0, spell('TNL067', 'Secret Stash'), { roomIndex: 0 }),
      true,
    );
    assert.deepEqual(G.players[0].dungeon[0][0].treasures, [1, 1, 2, 3, 4]);
  });

  it('TNL068 Shortcut! skips one Room, or two in a five Room dungeon', () => {
    const { G, ctx } = mk();
    G.adventure = { playerId: 1, roomIndex: 0, hero: { id: 'h1', name: 'Knight' }, hp: 5 };
    G.players[1].dungeon = [[room('r1', 'R1')], [room('r2', 'R2')], [room('r3', 'R3')]];
    assert.equal(castSpell(G, ctx, 0, spell('TNL068', 'Shortcut!'), {}), true);
    assert.equal(G.adventure.roomIndex, 1);

    G.adventure.roomIndex = 0;
    G.players[1].dungeon = [[room('r1', 'R1')], [room('r2', 'R2')], [room('r3', 'R3')], [room('r4', 'R4')], [room('r5', 'R5')]];
    assert.equal(castSpell(G, ctx, 0, spell('TNL068', 'Shortcut!'), {}), true);
    assert.equal(G.adventure.roomIndex, 2);
  });

  it('TNL069 Super Effective! gives your Room +2 until end of turn', () => {
    const { G, ctx } = mk();
    assert.equal(
      castSpell(G, ctx, 0, spell('TNL069', 'Super Effective!'), { roomIndex: 1 }),
      true,
    );
    assert.deepEqual(G.effects.roomDamageBonus, [{ playerId: 0, roomIndex: 1, amount: 2 }]);
  });

  it('TNL070 Surprise Gift places a Room face-down over an opponent Room', () => {
    const { G, ctx } = mk();
    G.players[0].hand = [room('gift', 'Gifted Room', 'monster', 5, [3])];
    G.players[1].dungeon = [[room('target', 'Target Room', 'trap', 1, [1])]];
    assert.equal(
      castSpell(G, ctx, 0, spell('TNL070', 'Surprise Gift'), { targetPlayerId: 1, handIndex: 0, roomIndex: 0 }),
      true,
    );
    assert.equal(G.players[0].hand.length, 0);
    assert.equal(G.players[1].dungeon[0].length, 2);
    assert.equal(G.players[1].dungeon[0][1].id, 'gift');
    assert.equal(G.players[1].dungeon[0][1].faceDown, true);
    assert.equal(
      castSpell(G, ctx, 0, spell('TNL070', 'Surprise Gift'), { targetPlayerId: 1, handIndex: 0, roomIndex: 0 }),
      false,
    );
  });
});

describe('Next Level boss abilities', () => {
  function forceActive(G, ctx, pid) {
    G.activePlayer = pid;
    ctx.activePlayer = pid;
    ctx.currentPlayer = pid;
    G.phase = PHASE.BUILD;
  }

  function passUntilNextTurn(state, max = 40) {
    const startTurn = state.G.turn;
    for (let i = 0; i < max && state.G.turn === startTurn; i++) {
      const G = state.G;
      if (G.pendingChoice) {
        const opt = aiResolveLevelUpChoice(G, G.pendingChoice);
        const r = applyMove(state, { type: 'resolveLevelUpChoice', args: [opt] }, G.pendingChoice.playerId);
        assert.equal(r.error, undefined, r.error);
        state = r.state;
        continue;
      }
      const r = applyMove(state, { type: 'pass', args: [] }, Number(state.ctx.activePlayer));
      assert.equal(r.error, undefined, r.error);
      state = r.state;
    }
    assert.ok(state.G.turn > startTurn, 'reached the next turn');
    return state;
  }

  it('TNL001 Doc Scarecrow discards a card and keeps one Town Hero from being lured', () => {
    const { G, ctx } = mk();
    G.players[0].boss = { id: 'TNL001', name: 'Doc Scarecrow', treasures: [1] };
    assert.equal(processExpansionLevelUp(G, 0, { id: 'TNL001', name: 'Doc Scarecrow' }), null);
    assert.equal(G.players[0].docScarecrow, true);

    G.town = [
      { id: 'h1', name: 'Fighter', treasure: 1, hp: 6 },
      { id: 'h2', name: 'Mage', treasure: 2, hp: 6 },
    ];
    G.players[0].dungeon = [[room('d1', 'My Room', 'monster', 5, [1])]];
    G.players[1].boss = { id: 'BMA002', name: 'Rival Boss', treasures: [] };
    G.players[1].dungeon = [[room('d2', 'Rival Room', 'monster', 1, [2])]];
    G.players[0].hand = [spell('s1', 'Spare Spell'), room('r1', 'Spare Room', 'monster', 1, [1])];
    G.players[1].hand = [];
    forceActive(G, ctx, 0);

    assert.ok(legalMoves(G, ctx, 0).some((m) => m.type === 'docScarecrow'));
    const res = applyMove({ G, ctx }, { type: 'docScarecrow', args: [1, 0] }, 0);
    assert.equal(res.error, undefined, res.error);
    const g2 = res.state.G;

    assert.equal(g2.players[0].hand.length, 1);
    assert.equal(g2.decks.roomDiscard.length, 1);
    assert.equal(g2.decks.roomDiscard[0].id, 'r1');
    assert.equal(g2.town[0].noLureThisTurn, true);
    assert.equal(g2.town[1].noLureThisTurn, undefined);
    assert.equal(g2.players[0]._scarecrowUsedThisBuild, true);
    assert.ok(g2.logs.some((l) => l.startsWith('Doc Scarecrow:')));

    const again = applyMove({ G: g2, ctx: res.state.ctx }, { type: 'docScarecrow', args: [0, 1] }, 0);
    assert.ok(again.error, 'only once per Build phase');

    const assignments = resolveBait(g2);
    const marked = assignments.find((a) => a.hero.id === 'h1');
    assert.equal(marked.stayInTown, true);
    assert.equal(marked.scarecrow, true);
    const unmarked = assignments.find((a) => a.hero.id === 'h2');
    assert.notEqual(unmarked.scarecrow, true);
    assert.equal(unmarked.stayInTown, false);
    assert.equal(unmarked.targetPlayerId, 1);
  });

  it('TNL001 Doc Scarecrow is only offered when unlocked, unused and in Build', () => {
    const { G, ctx } = mk();
    G.town = [{ id: 'h1', name: 'Hero', treasure: 1, hp: 6 }];
    G.players[0].hand = [room('r1', 'Room', 'monster', 1, [1])];
    forceActive(G, ctx, 0);

    assert.ok(!legalMoves(G, ctx, 0).some((m) => m.type === 'docScarecrow'));
    G.players[0].docScarecrow = true;
    assert.ok(legalMoves(G, ctx, 0).some((m) => m.type === 'docScarecrow'));
    G.players[0]._scarecrowUsedThisBuild = true;
    assert.ok(!legalMoves(G, ctx, 0).some((m) => m.type === 'docScarecrow'));

    G.players[0]._scarecrowUsedThisBuild = false;
    G.phase = PHASE.ADVENTURE;
    const res = applyMove({ G, ctx }, { type: 'docScarecrow', args: [0, 0] }, 0);
    assert.match(res.error || '', /Build phase/);
  });

  it('TNL001 once-per-turn flags reset at the next turn Beginning', () => {
    const { G, ctx } = mk();
    G.players[0].boss = { id: 'TNL001', name: 'Doc Scarecrow', treasures: [1] };
    processExpansionLevelUp(G, 0, { id: 'TNL001', name: 'Doc Scarecrow' });
    G.town = [{ id: 'h1', name: 'Fighter', treasure: 1, hp: 6 }];
    G.players[0].dungeon = [[room('d1', 'My Room', 'monster', 5, [1])]];
    G.players[0].hand = [spell('s1', 'Spare Spell')];
    G.players[1].hand = [];
    forceActive(G, ctx, 0);
    G.players[0]._timebenderUsedThisTurn = true;

    const used = applyMove({ G, ctx }, { type: 'docScarecrow', args: [0, 0] }, 0);
    assert.equal(used.error, undefined, used.error);
    assert.equal(used.state.G.town[0].noLureThisTurn, true);

    const next = passUntilNextTurn(used.state);
    assert.equal(next.G.players[0]._scarecrowUsedThisBuild, false);
    assert.equal(next.G.players[0]._timebenderUsedThisTurn, false);
    assert.ok(!next.G.town.some((h) => h.noLureThisTurn));
  });

  it("TNL003 Torix Uz'Kali recovers destroyed Monster Rooms to hand", () => {
    const { G } = mk();
    G.players[0].boss = { id: 'TNL003', name: 'Torix', treasures: [1] };
    assert.equal(processExpansionLevelUp(G, 0, { id: 'TNL003', name: "Torix Uz'Kali" }), null);
    assert.equal(G.players[0].recoverDestroyedMonsters, true);

    G.players[1].dungeon = [[room('mon', 'Beast', 'monster', 3, [1])]];
    const before = G.players[0].hand.length;
    destroyRoom(G, 1, 0);
    assert.equal(G.decks.roomDiscard.length, 0);
    assert.equal(G.players[0].hand.length, before + 1);
    assert.equal(G.players[0].hand.at(-1).id, 'mon');
    assert.ok(G.logs.some((l) => l.startsWith("Torix Uz'Kali: recovered")));
  });

  it("TNL003 Torix only takes Monster Rooms and needs the ability", () => {
    const { G } = mk();
    G.players[1].dungeon = [[room('trap1', 'Trap Room', 'trap', 2, [1])]];
    destroyRoom(G, 1, 0);
    assert.equal(G.decks.roomDiscard.length, 1);

    G.players[0].recoverDestroyedMonsters = true;
    G.players[1].dungeon = [[room('mon', 'Beast', 'monster', 3, [1])]];
    destroyRoom(G, 1, 0);
    assert.equal(G.decks.roomDiscard.length, 1);
    assert.equal(G.players[0].hand.at(-1).id, 'mon');

    const discarded = room('handmon', 'Hand Monster', 'monster', 1, [1]);
    G.players[1].hand = [discarded];
    discardRoomToPile(G, G.players[1].hand.splice(0, 1)[0]);
    assert.equal(G.decks.roomDiscard.length, 1);
    assert.equal(G.players[0].hand.at(-1).id, 'handmon');
  });

  it('TNL003 Torix takes Monster Rooms discarded through a choice effect', () => {
    const { G } = mk();
    G.players[0].recoverDestroyedMonsters = true;
    G.players[1].hand = [room('mon', 'Beast', 'monster', 3, [1])];
    G.pendingChoice = { type: 'discard-room-hand', playerId: 1, bossName: 'Test', options: [{ handIndex: 0 }] };
    const err = resolveLevelUpChoice(G, null, 1, 0);
    assert.equal(err, null);
    assert.equal(G.decks.roomDiscard.length, 0);
    assert.equal(G.players[0].hand.at(-1).id, 'mon');
  });

  it('TNL005 Shellda queues an end-of-turn Room swap choice', () => {
    const { G } = mk();
    G.players[0].boss = { id: 'TNL005', name: 'Shellda', treasures: [1] };
    assert.equal(processExpansionLevelUp(G, 0, { id: 'TNL005', name: 'Shellda' }), null);
    assert.equal(G.players[0].shelldaSwap, true);

    G.players[0].dungeon = [[room('a', 'Alpha', 'trap', 1, [1])], [room('b', 'Beta', 'monster', 2, [2])]];
    G.players[1].dungeon = [[room('c', 'Gamma', 'trap', 1, [1])], [room('d', 'Delta', 'monster', 2, [2])]];
    processEndOfTurnBosses(G);

    const choice = G.pendingChoice;
    assert.ok(choice, 'Shellda choice queued');
    assert.equal(choice.type, 'shellda-swap');
    assert.equal(choice.playerId, 0);
    assert.equal(choice.optional, true);
    assert.ok(choice.options.some((o) => o.playerId === 0 && o.roomIndexA === 0 && o.roomIndexB === 1));
    assert.ok(choice.options.some((o) => o.playerId === 1 && o.roomIndexA === 0 && o.roomIndexB === 1));
    assert.ok(choice.options.every((o) => typeof o.label === 'string'));

    const idx = choice.options.findIndex((o) => o.playerId === 0);
    assert.equal(resolveLevelUpChoice(G, null, 0, idx), null);
    assert.equal(G.players[0].dungeon[0][0].id, 'b');
    assert.equal(G.players[0].dungeon[1][0].id, 'a');
    assert.equal(G.pendingChoice, null);
    assert.ok(G.logs.some((l) => l.startsWith('Shellda: swapped')));
  });

  it('TNL005 Shellda can be skipped and the AI skips it', () => {
    const { G } = mk();
    G.players[0].shelldaSwap = true;
    G.players[0].dungeon = [[room('a', 'Alpha', 'trap', 1, [1])], [room('b', 'Beta', 'monster', 2, [2])]];
    G.players[1].dungeon = [[room('c', 'Gamma', 'trap', 1, [1])], [room('d', 'Delta', 'monster', 2, [2])]];
    processEndOfTurnBosses(G);
    const choice = G.pendingChoice;
    assert.ok(choice);
    assert.equal(aiResolveLevelUpChoice(G, choice), -1);

    assert.equal(resolveLevelUpChoice(G, null, 0, -1), null);
    assert.equal(G.pendingChoice, null);
    assert.equal(G.players[0].dungeon[0][0].id, 'a');
    assert.ok(G.logs.some((l) => l.startsWith('Shellda: skipped')));
  });

  it('TNL005 Shellda offers no choice when no dungeon has two Rooms', () => {
    const { G } = mk();
    G.players[0].shelldaSwap = true;
    G.players[0].dungeon = [[room('a', 'Alpha', 'trap', 1, [1])]];
    G.players[1].dungeon = [[room('c', 'Gamma', 'trap', 1, [1])]];
    processEndOfTurnBosses(G);
    assert.equal(G.pendingChoice, null);
  });

  it("TNL008 Dr. Timebender cancels an opponent's Spell on the stack", () => {
    const { G, ctx } = mk();
    G.players[0].boss = { id: 'TNL008', name: 'Dr. Timebender', treasures: [1] };
    assert.equal(processExpansionLevelUp(G, 0, { id: 'TNL008', name: 'Dr. Timebender' }), null);
    assert.equal(G.players[0].timebenderCancel, true);

    G.stack = [{ id: 'e1', type: 'spell', playerId: 1, card: spell('BMA040', 'Annihilator'), target: null, resolved: false }];
    G.stackReturnPlayer = 1;
    G.players[0].hand = [spell('mine', 'My Spell'), spell('mine2', 'My Other Spell')];
    G.players[1].hand = [];
    forceActive(G, ctx, 0);

    const offered = legalMoves(G, ctx, 0).filter((m) => m.type === 'timebenderCancel');
    assert.equal(offered.length, 2);

    const res = applyMove({ G, ctx }, { type: 'timebenderCancel', args: [0] }, 0);
    assert.equal(res.error, undefined, res.error);
    const g2 = res.state.G;
    assert.equal(g2.stack.length, 0);
    assert.equal(g2.decks.spellDiscard.length, 2);
    assert.equal(g2.players[0].hand.length, 1);
    assert.equal(g2.players[0]._timebenderUsedThisTurn, true);
    assert.ok(g2.logs.some((l) => l.startsWith('Dr. Timebender:')));
    assert.equal(String(res.state.ctx.activePlayer), '1', 'control returns to the spell owner');
    assert.equal(String(res.state.G.activePlayer), '1');

    const again = applyMove({ G: g2, ctx: res.state.ctx }, { type: 'timebenderCancel', args: [0] }, 0);
    assert.ok(again.error, 'once per turn');
  });

  it('TNL008 Dr. Timebender needs the ability, an opponent Spell and a Spell card', () => {
    const { G, ctx } = mk();
    G.players[0].hand = [spell('mine', 'My Spell')];
    forceActive(G, ctx, 0);
    G.stack = [{ id: 'e1', type: 'spell', playerId: 1, card: spell('s', 'S'), resolved: false }];
    assert.ok(!legalMoves(G, ctx, 0).some((m) => m.type === 'timebenderCancel'));

    G.players[0].timebenderCancel = true;
    G.stack = [{ id: 'e2', type: 'spell', playerId: 0, card: spell('s', 'S'), resolved: false }];
    assert.ok(!legalMoves(G, ctx, 0).some((m) => m.type === 'timebenderCancel'));

    G.stack = [{ id: 'e3', type: 'spell', playerId: 1, card: spell('s', 'S'), resolved: false }];
    assert.ok(legalMoves(G, ctx, 0).some((m) => m.type === 'timebenderCancel'));

    G.players[0].hand = [room('r', 'Room', 'monster', 1, [1])];
    assert.ok(!legalMoves(G, ctx, 0).some((m) => m.type === 'timebenderCancel'));

    const res = applyMove({ G, ctx }, { type: 'timebenderCancel', args: [0] }, 0);
    assert.ok(res.error, 'needs a Spell card in hand');
  });
});

describe('Boss ability review regressions', () => {
  function forceActive(G, ctx, pid) {
    G.activePlayer = pid;
    ctx.activePlayer = pid;
    ctx.currentPlayer = pid;
    G.phase = PHASE.BUILD;
  }

  it('BMA048 Jeopardy terminates when Torix recovers his own Monster Room', () => {
    const { G, ctx } = mk();
    G.players[0].recoverDestroyedMonsters = true;
    G.players[0].hand = [room('m1', 'Beast', 'monster', 3, [1]), room('t1', 'Trap', 'trap', 1, [1])];
    G.players[1].hand = [spell('s1', 'Charm'), room('m2', 'Ghoul', 'monster', 2, [1])];

    castSpell(G, ctx, 1, { id: 'BMA048', name: 'Jeopardy', isSpell: true }, null);

    // Reaching this line at all proves the discard loop terminates.
    assert.equal(G.players[1].hand.length, 3, '1 Spell + 2 Rooms redrawn');
    assert.ok(G.players[0].hand.some((c) => c.id === 'm1'), 'Torix kept the recovered Room');
    assert.ok(G.players[0].hand.some((c) => c.id === 'm2'), 'Torix recovered the opponent Monster Room too');
    assert.equal(G.players[0].hand.length, 5, '2 recovered Rooms + 1 Spell + 2 Rooms');
    assert.equal(G.decks.roomDiscard.filter((c) => c.id === 'm1' || c.id === 'm2').length, 0);
  });

  it('RMB071 Rebirth terminates when Torix recovers his own Monster Room', () => {
    const { G, ctx } = mk();
    G.players[0].recoverDestroyedMonsters = true;
    G.players[0].hand = [
      room('m1', 'Beast', 'monster', 3, [1]),
      room('t1', 'Trap', 'trap', 1, [1]),
      spell('s1', 'Charm'),
    ];

    castSpell(G, ctx, 0, { id: 'RMB071', name: 'Rebirth', isSpell: true }, { targetPlayerId: 0 });

    assert.ok(G.players[0].hand.some((c) => c.id === 'm1'), 'Torix kept the recovered Room');
    assert.equal(G.players[0].hand.length, 4, 'recovered Room + 2 Rooms + 1 Spell redrawn');
  });

  it('TNL001 Doc Scarecrow does not pass priority and waits for the Spell stack', () => {
    const { G, ctx } = mk();
    G.players[0].boss = { id: 'TNL001', name: 'Doc Scarecrow', treasures: [1] };
    processExpansionLevelUp(G, 0, { id: 'TNL001', name: 'Doc Scarecrow' });
    G.town = [{ id: 'h1', name: 'Fighter', treasure: 1, hp: 6 }];
    G.players[0].hand = [room('r1', 'Room', 'monster', 1, [1])];
    G.players[1].hand = [];
    forceActive(G, ctx, 0);

    const res = applyMove({ G, ctx }, { type: 'docScarecrow', args: [0, 0] }, 0);
    assert.equal(res.error, undefined, res.error);
    assert.equal(String(res.state.ctx.activePlayer), '0', 'free action keeps priority');
    assert.equal(String(res.state.G.activePlayer), '0', 'free action keeps priority');
    assert.equal(res.state.G.turn, G.turn, 'turn not consumed');

    const { G: G2, ctx: ctx2 } = mk();
    G2.players[0].boss = { id: 'TNL001', name: 'Doc Scarecrow', treasures: [1] };
    processExpansionLevelUp(G2, 0, { id: 'TNL001', name: 'Doc Scarecrow' });
    G2.town = [{ id: 'h1', name: 'Fighter', treasure: 1, hp: 6 }];
    G2.players[0].hand = [room('r1', 'Room', 'monster', 1, [1])];
    forceActive(G2, ctx2, 0);
    G2.stack = [{ id: 'e1', type: 'spell', playerId: 1, card: spell('s', 'S'), resolved: false }];

    assert.ok(!legalMoves(G2, ctx2, 0).some((m) => m.type === 'docScarecrow'));
    const blocked = applyMove({ G: G2, ctx: ctx2 }, { type: 'docScarecrow', args: [0, 0] }, 0);
    assert.match(blocked.error || '', /stack/);
  });

  it('TNL001 Doc Scarecrow routes a Miniboss card to the Miniboss discard', () => {
    const { G, ctx } = mk();
    G.players[0].boss = { id: 'TNL001', name: 'Doc Scarecrow', treasures: [1] };
    processExpansionLevelUp(G, 0, { id: 'TNL001', name: 'Doc Scarecrow' });
    G.town = [{ id: 'h1', name: 'Fighter', treasure: 1, hp: 6 }];
    G.players[0].hand = [{ id: 'MB1', name: 'Lieutenant', isMiniboss: true }];
    forceActive(G, ctx, 0);

    const res = applyMove({ G, ctx }, { type: 'docScarecrow', args: [0, 0] }, 0);
    assert.equal(res.error, undefined, res.error);
    assert.equal(res.state.G.decks.minibossDiscard.length, 1);
    assert.equal(res.state.G.decks.roomDiscard.length, 0);
    assert.equal(res.state.G.decks.spellDiscard.length, 0);
  });

  it('the End phase never leaves a queued choice behind a win', () => {
    const { G, ctx } = mk();
    G.players[0].shelldaSwap = true;
    G.players[0].souls = Array.from({ length: 10 }, (_, i) => ({ id: `s${i}` }));
    G.players[0].dungeon = [[room('a', 'Alpha', 'trap', 1, [1])], [room('b', 'Beta', 'monster', 2, [2])]];
    G.players[1].dungeon = [[room('c', 'Gamma', 'trap', 1, [1])], [room('d', 'Delta', 'monster', 2, [2])]];
    forceActive(G, ctx, 0);

    let state = { G, ctx };
    for (let i = 0; i < 80 && !state.G.gameOver; i++) {
      const g = state.G;
      if (g.pendingChoice) {
        const opt = aiResolveLevelUpChoice(g, g.pendingChoice);
        const r = applyMove(state, { type: 'resolveLevelUpChoice', args: [opt] }, g.pendingChoice.playerId);
        assert.equal(r.error, undefined, r.error);
        state = r.state;
        continue;
      }
      const r = applyMove(state, { type: 'pass', args: [] }, Number(state.ctx.activePlayer));
      assert.equal(r.error, undefined, r.error);
      state = r.state;
    }

    assert.equal(state.G.gameOver, true, '10 Souls ends the game');
    assert.equal(state.G.winner, 0);
    assert.equal(state.G.pendingChoice, null, 'no unresolvable choice left behind');
  });

  it('TNL001 Doc Scarecrow cannot mark an already marked Hero', () => {
    const { G, ctx } = mk();
    G.players[0].boss = { id: 'TNL001', name: 'Doc Scarecrow', treasures: [1] };
    processExpansionLevelUp(G, 0, { id: 'TNL001', name: 'Doc Scarecrow' });
    G.town = [{ id: 'h1', name: 'Fighter', treasure: 1, hp: 6, noLureThisTurn: true }];
    G.players[0].hand = [room('r1', 'Room', 'monster', 1, [1])];
    forceActive(G, ctx, 0);

    assert.ok(!legalMoves(G, ctx, 0).some((m) => m.type === 'docScarecrow'));
    const res = applyMove({ G, ctx }, { type: 'docScarecrow', args: [0, 0] }, 0);
    assert.match(res.error || '', /already/);
  });
});
