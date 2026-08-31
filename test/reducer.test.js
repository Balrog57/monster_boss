import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { setupMatch, applyMove, legalMoves } from '../server/reducer.js';
import { PHASE, ROOMS, SPELLS } from '../src/cardData.js';
import { aiPickMove } from '../src/ai.js';
import { pickOpeningDiscardIndices } from '../server/reducer.js';
import { onBuildRoom, processLevelUp, resolveLevelUpChoice, aiResolveLevelUpChoice } from '../src/roomAbilities.js';
import { healOneWound } from '../src/engine.js';
import { spellTargetsFor } from '../src/spellTargeting.js';

function playUntil(pred, start, max = 8000) {
  let state = start;
  const phases = new Set([state.G.phase]);
  for (let n = 0; n < max; n++) {
    if (pred(state)) return { state, steps: n, phases };
    const G = state.G;
    const ctx = state.ctx;
    if (G.pendingChoice) {
      const pid = G.pendingChoice.playerId;
      if (G.pendingChoice.type === 'opening-discard') {
        const pair = pickOpeningDiscardIndices(G.players[pid].hand);
        const r = applyMove(state, { type: 'openingDiscard', args: pair }, pid);
        assert.equal(r.error, undefined, r.error);
        state = r.state;
        phases.add(state.G.phase);
        continue;
      }
      const optIdx = aiResolveLevelUpChoice(G, G.pendingChoice);
      const r = applyMove(state, { type: 'resolveLevelUpChoice', args: [optIdx] }, pid);
      assert.equal(r.error, undefined, r.error);
      state = r.state;
      phases.add(state.G.phase);
      continue;
    }
    if (G.adventure?.pause) {
      for (const p of Object.keys(G.players)) {
        if (G.players[p]?.eliminated) continue;
        if (G.adventurePausePassed?.[String(p)]) continue;
        const r = applyMove(state, { type: 'pass', args: [] }, Number(p));
        assert.equal(r.error, undefined, r.error);
        state = r.state;
      }
      phases.add(state.G.phase);
      continue;
    }
    const pid = ctx.activePlayer;
    const moves = legalMoves(G, ctx, pid);
    const pick = (moves.length ? (aiPickMove(G, ctx, pid) || moves[0]) : { type: 'pass', args: [] });
    const r = applyMove(state, pick, pid);
    if (r.error) {
      const pass = applyMove(state, { type: 'pass', args: [] }, pid);
      if (pass.error) throw new Error(`stuck: ${r.error} / ${pass.error} phase=${G.phase} pid=${pid}`);
      state = pass.state;
    } else {
      state = r.state;
    }
    phases.add(state.G.phase);
  }
  throw new Error(`did not finish in ${max} moves (phase=${state.G.phase})`);
}

describe('reducer base match', () => {
  it('deals BMA heroes when no expansions are selected', () => {
    const { G } = setupMatch(2, { expansions: [] });
    const ids = [...G.decks.heroes, ...G.decks.epics].map((h) => h.id);
    assert.ok(ids.length > 0);
    assert.ok(ids.every((id) => String(id).startsWith('BMA')));
  });

  it('plays a complete 2p vs-AI game using only legalMoves', () => {
    let state = setupMatch(2, { expansions: [] });
    state.G.players[0].isAI = true;
    state.G.players[1].isAI = true;
    const { state: end, phases } = playUntil((s) => s.G.gameOver, state);
    assert.equal(end.G.gameOver, true);
    assert.ok(end.G.winner === 0 || end.G.winner === 1);
    for (const p of [PHASE.BOSS, PHASE.SETUP, PHASE.BUILD, PHASE.ADVENTURE]) {
      assert.ok(phases.has(p), `missing phase ${p}`);
    }
  });

  it('deals Hidden Heroes instead of BMA when that pack is on', () => {
    const { G } = setupMatch(2, { expansions: ['hidden-heroes'] });
    const ids = [...G.decks.heroes, ...G.decks.epics].map((h) => h.id);
    assert.ok(ids.length > 0);
    assert.ok(ids.every((id) => String(id).startsWith('BMH')));
  });

  it('includes Tools items when the tools pack is on', () => {
    const base = setupMatch(2, { expansions: [] });
    assert.equal(base.G.decks.items.length, 0);
    const tools = setupMatch(2, { expansions: ['tools'] });
    assert.ok(tools.G.decks.items.length >= 20);
  });

  it('plays a complete 2p game with all expansion packs', () => {
    let state = setupMatch(2, { expansions: null });
    state.G.players[0].isAI = true;
    state.G.players[1].isAI = true;
    const { state: end } = playUntil((s) => s.G.gameOver, state);
    assert.equal(end.G.gameOver, true);
    assert.ok(end.G.winner === 0 || end.G.winner === 1);
  });
});

describe('activated rooms match APK text', () => {
  function roomCard(id) {
    const r = ROOMS.find((c) => c.id === id);
    assert.ok(r, id);
    return { ...r, isRoom: true };
  }
  function spellCard(id) {
    const c = SPELLS.find((x) => x.id === id);
    assert.ok(c, id);
    return { ...c, isSpell: true };
  }
  function buildState() {
    const state = setupMatch(2, { expansions: [] });
    const G = state.G;
    const ctx = state.ctx;
    G.phase = PHASE.BUILD;
    ctx.phase = PHASE.BUILD;
    ctx.activePlayer = 0;
    ctx.currentPlayer = 0;
    G.activePlayer = 0;
    G.turn = 1;
    G.players[0].boss = { id: 'BMA001', name: 'Draculord', xp: 900, treasures: [1] };
    G.players[1].boss = { id: 'BMA002', name: 'Xyzax', xp: 850, treasures: [3] };
    G.players[0].passed = false;
    G.players[1].passed = false;
    return { G, ctx };
  }

  it('keeps the active player after activating a room', () => {
    const state = buildState();
    state.G.players[0].dungeon = [[roomCard('BMA030')]];
    state.G.players[0].hand = [];
    const r = applyMove(state, { type: 'activateRoom', args: [0, null] }, 0);
    assert.equal(r.error, undefined, r.error);
    assert.equal(r.state.ctx.activePlayer, 0);
    assert.equal(r.state.G.phase, PHASE.BUILD);
  });

  it('does not discard a monster when Witch\'s Kitchen is built', () => {
    const monster = roomCard('BMA015');
    const kitchen = roomCard('BMA024');
    const G = {
      players: {
        0: { dungeon: [[kitchen]], hand: [monster], eliminated: false },
      },
      decks: { spells: [spellCard('BMA050')], roomDiscard: [], spellDiscard: [] },
      logs: [],
      phase: PHASE.BUILD,
    };
    const choice = onBuildRoom(G, {}, 0, kitchen);
    assert.ok(!choice);
    assert.equal(G.players[0].hand.length, 1);
    assert.equal(G.players[0].hand[0].id, 'BMA015');
  });

  it('cancels the stacked spell with All-Seeing Eye', () => {
    const state = buildState();
    state.G.players[0].dungeon = [[roomCard('BMA025')]];
    state.G.players[0].hand = [spellCard('BMA050')];
    state.G.stack = [{ card: spellCard('BMA048'), playerId: 1, type: 'spell' }];
    state.G.stackReturnPlayer = 1;
    const r = applyMove(state, { type: 'activateRoom', args: [0, null] }, 0);
    assert.equal(r.error, undefined, r.error);
    assert.equal(r.state.G.stack.length, 0);
    assert.ok(r.state.G.logs.some((l) => /All-Seeing Eye/.test(l) && /Jeopardy/.test(l)));
  });

  it('lets Centipede Tunnel offer a swap instead of auto-swapping', () => {
    const tunnel = roomCard('BMA033');
    const a = roomCard('BMA009');
    const b = roomCard('BMA010');
    const G = {
      players: {
        0: { dungeon: [[a], [b], [tunnel]], hand: [], eliminated: false },
        1: { dungeon: [], hand: [], eliminated: false },
      },
      decks: { rooms: [], spells: [], roomDiscard: [], spellDiscard: [] },
      logs: [],
      phase: PHASE.BUILD,
    };
    const choice = onBuildRoom(G, {}, 0, tunnel);
    assert.equal(choice?.type, 'swap-rooms');
    assert.ok(choice.options.length >= 2);
    assert.equal(G.players[0].dungeon[0][0].id, 'BMA009');
  });
});

describe('APK choice and heal rules', () => {
  it('flips a Wound into a Soul', () => {
    const p = { wounds: [{ wounds: 1, souls: 1, name: 'Cleric', class: 'Cleric' }], souls: [] };
    const soul = healOneWound(p);
    assert.equal(p.wounds.length, 0);
    assert.equal(p.souls.length, 1);
    assert.equal(soul.souls, 1);
    assert.equal(soul.name, 'Cleric');
  });

  it('lets Hellcow pick a dungeon instead of auto-reversing', () => {
    const G = {
      players: {
        0: { dungeon: [[{ id: 'BMA009', name: 'A', damage: 1 }], [{ id: 'BMA010', name: 'B', damage: 2 }]], boss: { id: 'KSA002', name: 'Hellcow' }, eliminated: false, souls: [], wounds: [] },
        1: { dungeon: [[{ id: 'BMA011', name: 'C', damage: 2 }], [{ id: 'BMA012', name: 'D', damage: 1 }]], boss: { id: 'BMA001', name: 'Draculord' }, eliminated: false, souls: [], wounds: [] },
      },
      logs: [],
    };
    G.players[0].boss.id = 'KSA002';
    const choice = processLevelUp(G, {}, 0);
    assert.equal(choice?.type, 'pick-dungeon');
    assert.equal(G.players[0].dungeon[0][0].id, 'BMA009');
  });

  it('lists every player item for Excavation', () => {
    const G = {
      players: {
        0: { items: [{ id: 'THK001', name: 'Extra Life', faceDown: true }], eliminated: false },
        1: { items: [{ id: 'THK012', name: 'Necronomicon', faceDown: false }], eliminated: false },
      },
    };
    const me = G.players[0];
    const targets = spellTargetsFor(G, me, 0, 'THK025');
    assert.equal(targets.length, 2);
  });

  it('lets King Croak search deck and discard for an Advanced Monster', () => {
    const adv = { id: 'BMA013', name: 'Dracolich Lair', advanced: true, type: 'monster', treasures: [1], isRoom: true };
    const other = { id: 'BMA014', name: 'Vampire Bordello', advanced: true, type: 'monster', treasures: [1], isRoom: true };
    const G = {
      players: {
        0: { dungeon: [[{ id: 'BMA009', name: 'Dark Altar', treasures: [1] }]], boss: { id: 'BMA003', name: 'King Croak' }, hand: [], eliminated: false, souls: [], wounds: [] },
        1: { dungeon: [], boss: { id: 'BMA001', name: 'Draculord' }, eliminated: false, souls: [], wounds: [] },
      },
      decks: { rooms: [adv], roomDiscard: [other], spells: [] },
      logs: [],
    };
    const choice = processLevelUp(G, {}, 0);
    assert.equal(choice?.type, 'search-advanced');
    assert.equal(choice.optional, true);
    assert.equal(choice.options.length, 2);
    assert.equal(G.players[0].dungeon[0].length, 1);
  });

  it('lets Seducia search town and both Hero decks', () => {
    const townHero = { id: 'BMA100', name: 'Cleric', hp: 5 };
    const deckHero = { id: 'BMA101', name: 'Fighter', hp: 6 };
    const epic = { id: 'BMA200', name: 'The Fool', hp: 8, epic: true };
    const G = {
      players: {
        0: { dungeon: [], entrance: [], boss: { id: 'BMA006', name: 'Seducia' }, eliminated: false, souls: [], wounds: [] },
        1: { dungeon: [], entrance: [], boss: { id: 'BMA001', name: 'Draculord' }, eliminated: false, souls: [], wounds: [] },
      },
      town: [townHero],
      decks: { heroes: [deckHero], epics: [epic], rooms: [], spells: [] },
      logs: [],
    };
    const choice = processLevelUp(G, {}, 0);
    assert.equal(choice?.type, 'pick-hero');
    assert.equal(choice.options.length, 3);
    G.pendingChoice = choice;
    const err = resolveLevelUpChoice(G, {}, 0, 1);
    assert.equal(err, null);
    assert.equal(G.players[0].entrance[0].name, 'Fighter');
    assert.equal(G.decks.heroes.length, 0);
  });

  it('lets Kaw\'nee choose among ordinary souls', () => {
    const G = {
      players: {
        0: { dungeon: [], boss: { id: 'KSA004', name: "Kaw'nee" }, eliminated: false, souls: [], wounds: [] },
        1: { dungeon: [], boss: { id: 'BMA001', name: 'Draculord' }, eliminated: false, souls: [{ souls: 1, name: 'A' }, { souls: 1, name: 'B' }], wounds: [] },
      },
      logs: [],
    };
    G.pendingChoice = processLevelUp(G, {}, 0);
    assert.equal(G.pendingChoice?.type, 'pick-soul');
    assert.equal(G.pendingChoice.options.length, 2);
    resolveLevelUpChoice(G, {}, 0, 1);
    assert.equal(G.players[0].souls[0].name, 'B');
    assert.equal(G.players[1].souls.length, 1);
  });

  it('queues each opponent for Robobo in a 3-player game', () => {
    const G = {
      players: {
        0: { dungeon: [[{ id: 'BMA009', name: 'A', damage: 1 }]], boss: { id: 'BMA004', name: 'Robobo' }, eliminated: false, souls: [], wounds: [] },
        1: { dungeon: [[{ id: 'BMA010', name: 'B', damage: 2 }]], boss: { id: 'BMA001', name: 'Draculord' }, eliminated: false, souls: [], wounds: [] },
        2: { dungeon: [[{ id: 'BMA011', name: 'C', damage: 3 }]], boss: { id: 'BMA002', name: 'Xyzax' }, eliminated: false, souls: [], wounds: [] },
      },
      decks: { roomDiscard: [] },
      logs: [],
    };
    G.pendingChoice = processLevelUp(G, {}, 0);
    assert.equal(G.pendingChoice?.type, 'destroy-room');
    assert.equal(G.pendingChoice.playerId, 1);
    assert.deepEqual(G.roboboQueue, [2]);
    resolveLevelUpChoice(G, {}, 1, 0);
    assert.equal(G.pendingChoice?.type, 'destroy-room');
    assert.equal(G.pendingChoice.playerId, 2);
    resolveLevelUpChoice(G, {}, 2, 0);
    assert.equal(G.pendingChoice, null);
    assert.equal(G.players[1].dungeon.length, 0);
    assert.equal(G.players[2].dungeon.length, 0);
  });

  it('lets Mimic Vault choose among ordinary Heroes in town', () => {
    const vault = { id: 'BMA036', name: 'Mimic Vault' };
    const G = {
      players: {
        0: { dungeon: [[vault]], entrance: [], hand: [], eliminated: false },
        1: { dungeon: [], hand: [], eliminated: false },
      },
      town: [{ id: 'h1', name: 'Cleric', hp: 4 }, { id: 'h2', name: 'Mage', hp: 5 }],
      decks: { rooms: [], spells: [], roomDiscard: [], spellDiscard: [] },
      logs: [],
      phase: PHASE.BUILD,
    };
    const choice = onBuildRoom(G, {}, 0, vault);
    assert.equal(choice?.type, 'pick-hero');
    assert.equal(choice.options.length, 2);
  });

  it('lists own souls for Soul Harvest and opponent souls for Zombie Attack', () => {
    const G = {
      players: {
        0: { souls: [{ souls: 1, name: 'Mine' }], wounds: [], eliminated: false, dungeon: [] },
        1: { souls: [{ souls: 1, name: 'Theirs' }, { souls: 1, name: 'Other' }], wounds: [], eliminated: false, dungeon: [] },
      },
      town: [],
    };
    const harvest = spellTargetsFor(G, G.players[0], 0, 'BMA052');
    assert.equal(harvest.length, 1);
    assert.equal(harvest[0].soulIndex, 0);
    const zombie = spellTargetsFor(G, G.players[0], 0, 'BMA055');
    assert.equal(zombie.length, 2);
    const trep = spellTargetsFor(G, G.players[0], 0, 'BMA054');
    assert.equal(trep.length, 0);
  });
});
