import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { canBuildRoom, buildRoom, extendVisualIndex, dungeonIndexFromVisual, DUNGEON_SLOTS, countVisibleRooms, resolveBait } from '../src/engine.js';
import { HEROES, ROOMS, SPELLS, BOSSES, ITEMS, PHASE, heroesForSets, allowedCardSets } from '../src/cardData.js';
import { itemRevealCount, tryAttachRevealedItem } from '../src/items.js';
import { activateRoomAbility } from '../src/roomAbilities.js';

function player(over = {}) {
  return {
    boss: { id: 'BMA007', name: 'Cleopatra', xp: 850, treasures: [4] },
    dungeon: [],
    hand: [],
    souls: [],
    wounds: [],
    buildsThisTurn: 0,
    ...over,
  };
}

describe('engine build targeting', () => {
  it('maps 5 visual slots packed against the boss', () => {
    assert.equal(DUNGEON_SLOTS, 5);
    assert.equal(extendVisualIndex([]), 4);
    assert.equal(extendVisualIndex([[{}]]), 3);
    assert.equal(extendVisualIndex([[{}], [{}], [{}], [{}], [{}]]), null);
    assert.equal(dungeonIndexFromVisual([['a']], 4), 0);
    assert.equal(dungeonIndexFromVisual([['a']], 3), null);
  });

  it('lets ordinary rooms extend or overwrite, advanced only matching treasure', () => {
    const ordinary = { id: 'BMA027', name: 'Pit', isRoom: true, advanced: false, treasures: [4], damage: 1 };
    const advanced = { id: 'BMA036', name: 'Mimic', isRoom: true, advanced: true, treasures: [4], damage: 1 };
    const base = { id: 'BMA010', name: 'Grave', isRoom: true, advanced: false, treasures: [4], damage: 2 };
    const G = {
      effects: {},
      decks: { roomDiscard: [] },
      players: {
        0: player({
          dungeon: [[base]],
          hand: [ordinary, advanced],
        }),
      },
    };
    assert.equal(canBuildRoom(G, 0, 0, null), true);
    assert.equal(canBuildRoom(G, 0, 0, 0), true);
    // Advanced with no explicit index targets the last room (engine default).
    assert.equal(canBuildRoom(G, 0, 1, null), true);
    assert.equal(canBuildRoom(G, 0, 1, 0), true);
    assert.equal(buildRoom(G, 0, 0, null), true);
    assert.equal(countVisibleRooms(G.players[0].dungeon), 2);
  });
});

describe('base set cards', () => {
  it('includes BMA056–096 heroes on the base set', () => {
    const baseHeroes = HEROES.filter((h) => h.set === 'base');
    assert.ok(baseHeroes.length >= 41);
    assert.ok(baseHeroes.some((h) => h.id === 'BMA056'));
    assert.ok(baseHeroes.some((h) => h.id === 'BMA096'));
    assert.equal(BOSSES.filter((b) => b.set === 'base').length, 8);
    assert.ok(ROOMS.filter((r) => r.set === 'base').length >= 31);
    assert.ok(SPELLS.filter((s) => s.set === 'base').length >= 16);
  });

  it('has type, damage and treasures on every base room', () => {
    for (const r of ROOMS.filter((c) => c.set === 'base')) {
      assert.ok(r.type === 'monster' || r.type === 'trap', r.id);
      assert.equal(typeof r.damage, 'number', r.id);
      assert.ok(Array.isArray(r.treasures) && r.treasures.length, r.id);
      assert.ok(r.name, r.id);
    }
  });
});

describe('expansion packs', () => {
  it('reveals 1 item (2 in a 4-player game)', () => {
    assert.equal(itemRevealCount(2), 1);
    assert.equal(itemRevealCount(3), 1);
    assert.equal(itemRevealCount(4), 2);
  });

  it('replaces base heroes when Hidden Heroes is selected', () => {
    const withHH = heroesForSets(HEROES, allowedCardSets(['hidden-heroes']));
    assert.ok(withHH.every((h) => h.set !== 'base'));
    assert.ok(withHH.some((h) => h.id === 'BMH056'));
    const baseOnly = heroesForSets(HEROES, allowedCardSets([]));
    assert.ok(baseOnly.every((h) => String(h.id).startsWith('BMA')));
    assert.ok(ITEMS.filter((it) => it.set === 'tools').length >= 20);
    assert.ok(ROOMS.some((r) => r.id === 'THK021'));
  });

  it('lures Trap Master by combined Mage + Thief treasure', () => {
    const G = {
      effects: {},
      town: [{ id: 'KSA017', name: 'Trap Master', treasure: 3, hp: 13, class: 'Mage' }],
      players: {
        0: { boss: { xp: 100, treasures: [3, 3] }, dungeon: [], wounds: [], souls: [], eliminated: false },
        1: { boss: { xp: 200, treasures: [4] }, dungeon: [], wounds: [], souls: [], eliminated: false },
      },
    };
    const [assign] = resolveBait(G);
    assert.equal(assign.stayInTown, false);
    assert.equal(assign.targetPlayerId, 0);
  });

  it('attaches a matching town item and activates Artificer Workbench', () => {
    const G = {
      logs: [],
      phase: PHASE.BUILD,
      town: [{ id: 'BMA056', name: 'Cleric', treasure: 1, item: null }],
      townItems: [],
      decks: { spells: [{ id: 'BMA040', name: 'Annihilator', isSpell: true }], spellDiscard: [], roomDiscard: [] },
      players: {
        0: {
          dungeon: [[{ id: 'THK023', name: "Artificer's Workbench", type: 'trap' }]],
          items: [{ id: 'THK004', name: 'Staff of Healing', faceDown: false }],
          hand: [],
        },
      },
    };
    tryAttachRevealedItem(G, { id: 'THK001', name: 'Extra Life', treasure: 1 });
    assert.equal(G.town[0].item.id, 'THK001');
    assert.equal(G.townItems.length, 0);
    const err = activateRoomAbility(G, {}, 0, 0, null);
    assert.equal(err, null);
    assert.equal(G.players[0].items[0].faceDown, true);
    assert.equal(G.players[0].hand[0].id, 'BMA040');
  });
});
