import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {
  onBuildRoom,
  onHeroDiedInRoom,
  processLevelUp,
  resolveLevelUpChoice,
  hauntedLibraryChoice,
  activateRoomAbility,
} from '../src/roomAbilities.js';
import { castSpell, emptyEffects } from '../src/spellEffects.js';
import {
  activeRoom,
  canBuildRoom,
  destroyRoom,
  dungeonTreasures,
  roomDamageWithModifiers,
} from '../src/engine.js';
import { PHASE } from '../src/cardData.js';

// Base set (BMA001-096) parity with APK 2.2.6 BaseDeck/data.json.
// Bosses 8/8, spells 16/16, rooms 31/31, heroes 41/41 (data-driven).
// The APK extract (boss-monster-2-2-6/, gitignored) is optional: CI reads the
// committed fixture, and the fixture is cross-checked against the APK whenever
// the local extract is present.

function mkPlayer(over = {}) {
  return {
    boss: { id: 'BMA001', name: 'Draculord', treasures: [] },
    dungeon: [],
    entrance: [],
    hand: [],
    souls: [],
    wounds: [],
    eliminated: false,
    buildsThisTurn: 0,
    ...over,
  };
}

function mkG(p0 = {}, p1 = {}) {
  return {
    phase: PHASE.BUILD,
    turn: 1,
    players: { 0: mkPlayer(p0), 1: mkPlayer(p1) },
    decks: { rooms: [], spells: [], heroes: [], roomDiscard: [], spellDiscard: [], heroDiscard: [] },
    town: [],
    logs: [],
    effects: emptyEffects(),
    stack: [],
    pendingChoice: null,
  };
}

const room = (id, name, type, damage = 1, treasures = [1], extra = {}) => ({
  id, name, type, damage, treasures, isRoom: true, ...extra,
});
const spell = (id, name, category, extra = {}) => ({ id, name, isSpell: true, category, ...extra });

const APK_URL = new URL('../boss-monster-2-2-6/assets/Content/CardDecks/BaseDeck/data.json', import.meta.url);
const FIXTURE_URL = new URL('./fixtures/apk-base-heroes.json', import.meta.url);
const readJson = (url) => JSON.parse(fs.readFileSync(url, 'utf-8').replace(/^\uFEFF/, ''));
const apkLocal = fs.existsSync(APK_URL) ? readJson(APK_URL) : null;
const refHeroes = (apkLocal ?? readJson(FIXTURE_URL)).HeroCards;

describe('base set heroes match APK stats and lure', () => {
  it('all 41 base heroes have identical HP, treasure, souls, wounds', () => {
    const web = JSON.parse(fs.readFileSync(new URL('../src/cardData.json', import.meta.url), 'utf-8'));
    const apkHeroes = Object.fromEntries(refHeroes.map((c) => [c.CardNumber, c]));
    const webBase = web.heroes.filter((h) => h.set === 'base');
    assert.equal(webBase.length, 41);
    assert.deepEqual(new Set(webBase.map((h) => h.id)), new Set(Object.keys(apkHeroes)));
    assert.equal(refHeroes.filter((c) => c.Ability?.Effects?.length).length, 0);
    for (const h of webBase) {
      const a = apkHeroes[h.id];
      assert.equal(h.hp, a.Health, `${h.id} hp`);
      assert.equal(h.treasure, a.Treasures[0], `${h.id} treasure`);
      assert.equal(h.souls, a.Souls, `${h.id} souls`);
      assert.equal(h.wounds, a.Wounds, `${h.id} wounds`);
      // APK HasStar is always false in the base set; epic status follows the
      // official subtitle (16 Epic Heroes: BMA081-096)
      assert.equal(!!h.epic, a.Subtitle === 'Epic Hero', `${h.id} epic`);
    }
    // The Fool is lured by fewest souls, not treasure
    const fool = webBase.find((h) => h.id === 'BMA080');
    assert.equal(fool.treasure, 0);
    assert.equal(apkHeroes.BMA080.LuredCondition.TypeName, 'LuredByFewerSouls');
  });

  it('committed fixture matches the local APK extract', { skip: apkLocal ? false : 'APK extract not present' }, () => {
    assert.deepEqual(readJson(FIXTURE_URL).HeroCards, apkLocal.HeroCards);
  });
});

describe('base set boss level-ups', () => {
  it('BMA005 Cerebellus draws 3 spells then discards 1', () => {
    const G = mkG({ boss: { id: 'BMA005', name: 'Cerebellus', treasures: [] } });
    G.decks.spells = [spell('BMA040', 'Annihilator', 3), spell('BMA044', 'Exhaustion', 4), spell('BMA050', 'Motivation', 3)];
    const handBefore = G.players[0].hand.length;
    const choice = processLevelUp(G, {}, 0);
    assert.equal(G.players[0].hand.length, handBefore + 3);
    assert.equal(choice?.type, 'discard-spell');
    assert.equal(choice.options.length, 3);
    G.pendingChoice = choice;
    const err = resolveLevelUpChoice(G, {}, 0, 0);
    assert.equal(err, null);
    assert.equal(G.players[0].hand.length, handBefore + 2);
  });
});

describe('base set hero-death rooms', () => {
  it('BMA016 Golem Factory draws a room, once per turn', () => {
    const factory = room('BMA016', 'Golem Factory', 'trap', 1, [2]);
    const G = mkG({ dungeon: [[factory]] });
    G.decks.rooms = [room('BMA009', 'Dark Altar', 'trap'), room('BMA010', 'Open Grave', 'monster')];
    onHeroDiedInRoom(G, {}, 0, factory, { id: 'BMA056', name: 'Squire' });
    assert.equal(G.players[0].hand.length, 1);
    onHeroDiedInRoom(G, {}, 0, factory, { id: 'BMA057', name: 'Apprentice' });
    assert.equal(G.players[0].hand.length, 1);
  });
});

describe('base set build rules', () => {
  it('BMA018 Neanderthal Cave blocks advanced builds on itself', () => {
    const cave = room('BMA018', 'Neanderthal Cave', 'trap', 1, [1]);
    const adv = room('BMA013', 'Dracolich Lair', 'monster', 3, [1], { advanced: true, isRoom: true });
    const G = mkG({ dungeon: [[cave]], hand: [adv] });
    assert.equal(canBuildRoom(G, 0, 0, 0), false);
    const plain = room('BMA009', 'Dark Altar', 'trap', 1, [1]);
    const G2 = mkG({ dungeon: [[plain]], hand: [{ ...adv }] });
    assert.equal(canBuildRoom(G2, 0, 0, 0), true);
  });

  it('BMA019 Beast Menagerie draws on monster build, once per turn', () => {
    const menagerie = room('BMA019', 'Beast Menagerie', 'monster', 1, [2]);
    const G = mkG({ dungeon: [[menagerie]] });
    G.decks.rooms = [room('BMA009', 'A', 'trap'), room('BMA010', 'B', 'monster'), room('BMA011', 'C', 'trap')];
    onBuildRoom(G, {}, 0, room('BMA010', 'Open Grave', 'monster', 2, [2]));
    assert.equal(G.players[0].hand.length, 1);
    onBuildRoom(G, {}, 0, room('BMA010', 'Open Grave', 'monster', 2, [2]));
    assert.equal(G.players[0].hand.length, 1);
  });

  it('BMA022 Dark Laboratory draws 2 spells then discards 1', () => {
    const G = mkG();
    G.decks.spells = [spell('BMA040', 'Annihilator', 3), spell('BMA044', 'Exhaustion', 4)];
    const choice = onBuildRoom(G, {}, 0, room('BMA022', 'Dark Laboratory', 'trap', 1, [3]));
    assert.equal(G.players[0].hand.length, 2);
    assert.equal(choice?.type, 'discard-spell');
  });

  it('BMA034 Construction Zone grants an extra build', () => {
    const G = mkG();
    G.players[0].buildsThisTurn = 1;
    onBuildRoom(G, {}, 0, room('BMA034', 'Construction Zone', 'trap', 1, [1]));
    assert.equal(G.players[0].buildsThisTurn, 0);
  });

  it('BMA037 Monstrous Monument recovers a monster from discard', () => {
    const G = mkG();
    G.decks.roomDiscard = [room('BMA010', 'Open Grave', 'monster', 2, [2])];
    onBuildRoom(G, {}, 0, room('BMA037', 'Monstrous Monument', 'trap', 1, [4]));
    assert.equal(G.players[0].hand.length, 1);
    assert.equal(G.players[0].hand[0].id, 'BMA010');
    assert.equal(G.decks.roomDiscard.length, 0);
  });
});

describe('base set passive room damage', () => {
  it("BMA020 Monster's Ballroom damage equals monster room count", () => {
    const ballroom = room('BMA020', "Monster's Ballroom", 'monster', 0, [4]);
    const G = mkG({ dungeon: [[ballroom], [{ ...room('BMA010', 'Open Grave', 'monster', 2, [2]) }], [{ ...room('BMA009', 'Dark Altar', 'trap', 1, [1]) }]] });
    assert.equal(roomDamageWithModifiers(G, 0, 0, { id: 'BMA056' }), 2);
  });

  it('BMA029 Dizzygas Hallway gives +2 to the next trap room', () => {
    const dizzy = room('BMA029', 'Dizzygas Hallway', 'trap', 1, [3]);
    const victim = room('BMA009', 'Dark Altar', 'trap', 1, [1]);
    const G = mkG({ dungeon: [[dizzy], [victim]] });
    assert.equal(roomDamageWithModifiers(G, 0, 1, { id: 'BMA056' }), 3);
  });

  it('BMA035 Dragon Hatchery counts all four treasure types', () => {
    const hatchery = room('BMA035', 'Dragon Hatchery', 'monster', 2, [1, 3, 2, 4]);
    const G = mkG({ dungeon: [[hatchery]] });
    const t = dungeonTreasures(G, 0);
    for (const k of [1, 2, 3, 4]) assert.ok(t.includes(k), `treasure ${k}`);
  });
});

describe('base set destruction triggers', () => {
  it('BMA031 Recycling Center draws 2 rooms when another room is destroyed', () => {
    const G = mkG({ dungeon: [[room('BMA031', 'Recycling Center', 'trap', 1, [1])], [room('BMA009', 'Dark Altar', 'trap', 1, [1])]] });
    G.decks.rooms = [room('BMA010', 'A', 'monster'), room('BMA011', 'B', 'trap')];
    destroyRoom(G, 0, 1);
    assert.equal(G.players[0].hand.length, 2);
    assert.equal(G.decks.roomDiscard.length, 1);
  });
});

describe('base set beginning-of-turn choice', () => {
  it('BMA023 Haunted Library draws from the chosen deck', () => {
    const G = mkG();
    G.decks.rooms = [room('BMA009', 'Dark Altar', 'trap')];
    G.decks.spells = [spell('BMA040', 'Annihilator', 3)];
    G.pendingChoice = hauntedLibraryChoice(0);
    const err = resolveLevelUpChoice(G, {}, 0, 1);
    assert.equal(err, null);
    assert.equal(G.players[0].hand.length, 1);
    assert.equal(G.players[0].hand[0].id, 'BMA040');
    assert.equal(G.decks.spells.length, 0);
    assert.equal(G.decks.rooms.length, 1);
  });
});

describe('base set activated room abilities', () => {
  it('BMA028 Boulder Ramp deals 5 to the hero and destroys another room', () => {
    const G = mkG({ dungeon: [[room('BMA028', 'Boulder Ramp', 'trap', 2, [2])], [room('BMA009', 'Dark Altar', 'trap', 1, [1])]] });
    G.adventure = { playerId: 0, hero: { id: 'BMA056', name: 'Squire' }, hp: 10, roomIndex: 0 };
    G.decks.roomDiscard = [];
    const err = activateRoomAbility(G, {}, 0, 0, 1);
    assert.equal(err, null);
    assert.equal(G.adventure.hp, 5);
    assert.equal(G.players[0].dungeon.length, 1);
  });

  it('BMA032 Crushinator boosts rooms +2 and destroys the other room', () => {
    const G = mkG({ dungeon: [[room('BMA032', 'The Crushinator', 'trap', 2, [2])], [room('BMA009', 'Dark Altar', 'trap', 1, [1])]] });
    G.decks.roomDiscard = [];
    const err = activateRoomAbility(G, {}, 0, 0, 1);
    assert.equal(err, null);
    assert.equal(G.effects.roomDamageBonus.length, 1);
    assert.deepEqual(G.effects.roomDamageBonus[0], { playerId: 0, roomIndex: 0, amount: 2 });
    assert.equal(G.players[0].dungeon.length, 1);
  });

  it('BMA038 Torture Chamber makes the opponent discard a room', () => {
    const G = mkG(
      { dungeon: [[room('BMA038', 'Torture Chamber', 'trap', 1, [4])]] },
      { hand: [room('BMA009', 'Dark Altar', 'trap', 1, [1], { isRoom: true })] },
    );
    G.decks.roomDiscard = [];
    const err = activateRoomAbility(G, {}, 0, 0);
    assert.equal(err, null);
    assert.equal(G.players[1].hand.length, 0);
    assert.equal(G.decks.roomDiscard.length, 2); // discarded room + the chamber itself
    assert.ok(G.decks.roomDiscard.some((c) => c.id === 'BMA009'));
    assert.ok(G.decks.roomDiscard.some((c) => c.id === 'BMA038'));
    assert.equal(G.players[0].dungeon.length, 0);
  });

  it("BMA039 Zombie Prison returns an opponent's dead hero to entrance", () => {
    const G = mkG(
      { dungeon: [[room('BMA039', 'Zombie Prison', 'trap', 1, [3])]] },
      { souls: [{ souls: 1, name: 'Cleric', class: 'Cleric', faceDown: true }], entrance: [] },
    );
    const err = activateRoomAbility(G, {}, 0, 0);
    assert.equal(err, null);
    assert.equal(G.players[1].souls.length, 0);
    assert.equal(G.players[1].entrance.length, 1);
    assert.equal(G.players[0].dungeon.length, 0);
  });
});

describe('base set spell effects', () => {
  it('BMA041 Assassin gives +3 HP to a hero in an opponent dungeon', () => {
    const G = mkG({}, { entrance: [{ id: 'BMA060', name: 'Fighter', hp: 4 }] });
    const ok = castSpell(G, {}, 0, { id: 'BMA041', name: 'Assassin' }, { heroId: 'BMA060' });
    assert.equal(ok, true);
    assert.deepEqual(G.effects.heroHealthBonus, [{ heroId: 'BMA060', amount: 3 }]);
  });

  it('BMA046 Freeze deactivates a room in any dungeon', () => {
    const G = mkG({ dungeon: [[room('BMA009', 'Dark Altar', 'trap', 1, [1])]] });
    const ok = castSpell(G, {}, 0, { id: 'BMA046', name: 'Freeze' }, { roomIndex: 0 });
    assert.equal(ok, true);
    assert.deepEqual(G.effects.deactivatedRooms, [{ playerId: 0, roomIndex: 0 }]);
  });

  it('BMA051 Princess in Peril moves a town hero to your entrance', () => {
    const G = mkG();
    G.town = [{ id: 'BMA056', name: 'Cleric', hp: 4 }];
    const ok = castSpell(G, {}, 0, { id: 'BMA051', name: 'Princess in Peril' }, { townIndex: 0 });
    assert.equal(ok, true);
    assert.equal(G.town.length, 0);
    assert.equal(G.players[0].entrance.length, 1);
  });

  it('BMA053 Teleportation restarts the exploring hero at the first room', () => {
    const G = mkG();
    G.adventure = { playerId: 0, hero: { id: 'BMA056', name: 'Cleric' }, hp: 3, roomIndex: 2, mazeSentBack: { 1: true } };
    const ok = castSpell(G, {}, 0, { id: 'BMA053', name: 'Teleportation' }, { heroId: 'BMA056' });
    assert.equal(ok, true);
    assert.equal(G.adventure.roomIndex, -1);
  });
});

describe('base set stack interaction spells', () => {
  function stackState() {
    return {
      G: {
        phase: PHASE.BUILD,
        turn: 2,
        players: {
          0: mkPlayer({ hand: [] }),
          1: mkPlayer({ hand: [] }),
        },
        decks: { rooms: [], spells: [], heroes: [], roomDiscard: [], spellDiscard: [], heroDiscard: [] },
        town: [],
        logs: [],
        effects: emptyEffects(),
        stack: [],
        pendingChoice: null,
      },
      ctx: { activePlayer: 0, currentPlayer: 0 },
    };
  }

  it('BMA043 Counterspell cancels the spell on the stack', async () => {
    const reducer = await import('../server/reducer.js');
    const state = stackState();
    state.G.stack = [{ card: { id: 'BMA048', name: 'Jeopardy', isSpell: true }, playerId: 1 }];
    state.G.players[0].hand = [{ id: 'BMA043', name: 'Counterspell', isSpell: true, category: 2 }];
    const r = reducer.applyMove(state, { type: 'playSpell', args: [0, null] }, 0);
    assert.equal(r.error, undefined, r.error);
    assert.equal(r.state.G.stack.length, 0);
    assert.ok(r.state.G.decks.spellDiscard.some((c) => c.id === 'BMA043'));
    assert.ok(r.state.G.decks.spellDiscard.some((c) => c.id === 'BMA048'));
    assert.match(r.state.G.logs.join('\n'), /Counterspell cancels Jeopardy/);
  });

  it("BMA026 Liger's Den draws when a spell resolves, once per turn", async () => {
    const reducer = await import('../server/reducer.js');
    const state = stackState();
    state.G.players[0].dungeon = [[{ ...room('BMA026', "Liger's Den", 'monster', 2, [2]), faceDown: false }]];
    state.G.players[0].hand = [{ id: 'BMA051', name: 'Princess in Peril', isSpell: true, category: 1 }];
    state.G.town = [{ id: 'BMA056', name: 'Cleric', hp: 4 }];
    state.G.decks.spells = [spell('BMA040', 'Annihilator', 3), spell('BMA044', 'Exhaustion', 4)];
    let r = reducer.applyMove(state, { type: 'playSpell', args: [0, { townIndex: 0 }] }, 0);
    assert.equal(r.error, undefined, r.error);
    state.G = r.state.G; state.ctx = r.state.ctx;
    r = reducer.applyMove({ G: state.G, ctx: { activePlayer: 1, currentPlayer: 1 } }, { type: 'pass', args: [] }, 1);
    assert.equal(r.error, undefined, r.error);
    assert.equal(r.state.G.players[0].entrance.length, 1);
    assert.equal(r.state.G.players[0].hand.length, 1);
    assert.match(r.state.G.logs.join('\n'), /Liger's Den/);
  });

  it('base-only games use official hero deck sizes (2p: 13+8, 3p: 17+12, 4p: 25+16)', async () => {
    const reducer = await import('../server/reducer.js');
    for (const [n, ordinary, epic] of [[2, 13, 8], [3, 17, 12], [4, 25, 16]]) {
      const { G } = reducer.setupMatch(n, { expansions: [], humanCount: 1 });
      assert.equal(G.decks.heroes.length, ordinary, `${n}p ordinary heroes`);
      assert.equal(G.decks.epics.length, epic, `${n}p epic heroes`);
    }
  });
});
