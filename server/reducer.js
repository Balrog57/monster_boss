// server/reducer.js - Pure game reducer for Boss Monster (no boardgame.io).
//
// Replaces src/BossMonster.js. The state shape { G, ctx } mirrors what
// boardgame.io used to produce so the existing UI (AppBoard.jsx) and helpers
// (engine.js, cardData.js, roomAbilities.js, spellEffects.js, ai.js) work
// unchanged.
//
// Public API:
//   setupMatch(numPlayers, setupData?) -> { G, ctx }
//   applyMove(state, move, playerID)  -> { state, error? }  (state = { G, ctx })
//   playerView(G, playerID)           -> G  (opponent hands hidden)
//   legalMoves(G, ctx, playerID)      -> Move[]  (for AI bots in solo mode)
//
// A move is { type: 'pickBoss'|'buildInitialRoom'|'buildRoom'|'playSpell'|'pass'|'resolveNextHero', args: [...] }.

import {
  BOSSES, ROOMS, SPELLS, HEROES, PHASE, SPELL_CATEGORY,
  getExpandedDeck, shuffle, drawCards, playerOrderByXP, totalSouls, totalWounds
} from '../src/cardData.js';
import { castSpell, emptyEffects, isBuildBlocked, extraBuildsFor, isRoomDeactivated, isNoEntry } from '../src/spellEffects.js';
import { onBuildRoom, onHeroDiedInRoom, processLevelUp } from '../src/roomAbilities.js';
import {
  activeRoom, allActiveRooms, countVisibleRooms, dungeonTreasures,
  resolveBait, buildRoom, heroHealthWithModifiers,
  roomDamageWithModifiers, checkEndGame
} from '../src/engine.js';

const HERO_COUNTS = {
  2: { ordinary: 13, epic: 8 },
  3: { ordinary: 17, epic: 12 },
  4: { ordinary: 25, epic: 16 }
};

const GAME_NAME = 'boss-monster';
const MIN_PLAYERS = 2;
const MAX_PLAYERS = 4;

// ---------------------------------------------------------------------------
// setup
// ---------------------------------------------------------------------------
function dealBossCards(numPlayers) {
  return shuffle(BOSSES).slice(0, Math.min(numPlayers * 2, BOSSES.length));
}

function filterHeroesByPlayerCount(heroes, count) {
  if (!count || count >= 4) return heroes;
  return heroes.filter(h => {
    if (count === 2) return !h.playerCount || h.playerCount === 2;
    if (count === 3) return !h.playerCount || h.playerCount <= 3;
    return true;
  });
}

export function setupMatch(numPlayers, setupData = {}) {
  const n = Math.min(Math.max(numPlayers || 2, MIN_PLAYERS), MAX_PLAYERS);
  const roomDeck = shuffle(getExpandedDeck(ROOMS).map(r => ({ ...r, isRoom: true })));
  const spellDeck = shuffle(getExpandedDeck(SPELLS).map(s => ({ ...s, isSpell: true })));
  const ordinaryHeroes = shuffle(getExpandedDeck(filterHeroesByPlayerCount(HEROES.filter(h => !h.epic), n)).map(h => ({ ...h, epic: false, wounds: 1, souls: 1 })));
  const epicHeroes = shuffle(getExpandedDeck(filterHeroesByPlayerCount(HEROES.filter(h => h.epic), n)).map(h => ({ ...h, epic: true, wounds: 2, souls: 2 })));

  const players = {};
  for (let i = 0; i < n; i++) {
    players[i] = {
      boss: null,
      dungeon: [],
      hand: [],
      souls: [],
      wounds: [],
      entrance: [],
      eliminated: false,
      leveledUp: false,
      buildsThisTurn: 0,
      isAI: i > 0,
      passed: false
    };
  }

  const G = {
    players,
    bossPicks: dealBossCards(n),
    numPlayers: n,
    xpOrder: playerOrderByXP(players),
    decks: {
      rooms: roomDeck,
      spells: spellDeck,
      heroes: ordinaryHeroes,
      epics: epicHeroes,
      roomDiscard: [],
      spellDiscard: [],
      heroDiscard: []
    },
    town: [],
    turn: 0,
    phase: PHASE.BOSS,
    effects: emptyEffects(),
    logs: ['Welcome to Boss Monster!'],
    gameOver: false,
    winner: null
  };

  const ctx = {
    numPlayers: n,
    currentPlayer: G.xpOrder[0] ?? 0,
    activePlayer: G.xpOrder[0] ?? 0,
    phase: PHASE.BOSS,
    turn: 0
  };

  return { G, ctx };
}

// ---------------------------------------------------------------------------
// Phase transitions (mirrors BossMonster.js phases: BOSS -> SETUP -> BEGINNING
// -> BUILD -> BAIT -> ADVENTURE -> END -> BEGINNING ...)
// ---------------------------------------------------------------------------
function spellAllowedInPhase(category, phase) {
  if (category === SPELL_CATEGORY.ANY) return true;
  if (category === SPELL_CATEGORY.BUILD_BAIT) return phase === PHASE.BUILD || phase === PHASE.BAIT;
  if (category === SPELL_CATEGORY.ADVENTURE_BUILD) return phase === PHASE.ADVENTURE || phase === PHASE.BUILD;
  if (category === SPELL_CATEGORY.BUILD) return phase === PHASE.BUILD;
  if (category === SPELL_CATEGORY.BAIT) return phase === PHASE.BAIT;
  if (category === SPELL_CATEGORY.ADVENTURE) return phase === PHASE.ADVENTURE;
  return false;
}

function nextXPActivePlayer(G, current) {
  const order = G.xpOrder || [0, 1];
  const cur = current != null ? current : order[0];
  const idx = order.indexOf(cur);
  for (let i = 1; i <= order.length; i++) {
    const candidate = order[(idx + i) % order.length];
    if (candidate != null && !G.players[candidate]?.eliminated && !G.players[candidate]?.passed) {
      return candidate;
    }
  }
  return null;
}

function beginPhase(G, ctx, phase) {
  G.phase = phase;
  ctx.phase = phase;
  G.xpOrder = playerOrderByXP(G.players);
  ctx.activePlayer = G.xpOrder[0] ?? 0;
  ctx.currentPlayer = ctx.activePlayer;
  for (const p of Object.values(G.players)) p.passed = false;
}

function endPhaseSetup(G, ctx) {
  // Auto-pick bosses for AI seats that haven't picked
  for (let i = 0; i < ctx.numPlayers; i++) {
    if (!G.players[i].boss) {
      const available = G.bossPicks.filter(b =>
        !Object.values(G.players).some(pl => pl.boss?.id === b.id)
      );
      if (available.length > 0) {
        const chosen = [...available].sort((a, b) => b.xp - a.xp)[0];
        G.players[i].boss = { ...chosen };
        G.logs.push(`Player ${i} chose ${chosen.name}`);
      }
    }
  }
  // Deal starting hands
  for (let i = 0; i < ctx.numPlayers; i++) {
    const p = G.players[i];
    drawCards(G.decks.rooms, 5).forEach(c => p.hand.push(c));
    drawCards(G.decks.spells, 2).forEach(c => p.hand.push(c));
  }
  // Seed discard piles
  drawCards(G.decks.rooms, 4).forEach(c => G.decks.roomDiscard.push(c));
  drawCards(G.decks.spells, 2).forEach(c => G.decks.spellDiscard.push(c));
  G.xpOrder = playerOrderByXP(G.players);
  G.logs.push('Setup: hands dealt, discard seeded.');
}

function endPhaseSetupBuild(G, ctx) {
  // Reveal face-down rooms in XP order and trigger onBuildRoom
  for (const pid of playerOrderByXP(G.players)) {
    const room = activeRoom(G.players[pid].dungeon[0]);
    if (room) {
      G.logs.push(`Revealed ${room.name} for Player ${pid}`);
      onBuildRoom(G, ctx, pid, room);
    }
  }
  G.effects = emptyEffects();
}

function beginPhaseBeginning(G, ctx) {
  G.turn += 1;
  G.phase = PHASE.BEGINNING;
  ctx.phase = PHASE.BEGINNING;
  G.logs.push(`--- Turn ${G.turn} - Beginning Phase ---`);
  const aliveCount = Object.values(G.players).filter(p => !p.eliminated).length;
  for (let i = 0; i < aliveCount; i++) {
    let hero = null;
    if (G.decks.heroes.length > 0) hero = G.decks.heroes.pop();
    else if (G.decks.epics.length > 0) hero = G.decks.epics.pop();
    if (hero) {
      G.town.push(hero);
      G.logs.push(`${hero.name} arrives in town`);
    }
  }
  for (let i = 0; i < ctx.numPlayers; i++) {
    const p = G.players[i];
    if (p.eliminated) continue;
    const room = G.decks.rooms.pop();
    if (room) p.hand.push(room);
  }
  for (const p of Object.values(G.players)) {
    p.buildsThisTurn = 0;
    p.passed = false;
  }
  G.effects = emptyEffects();
  G.xpOrder = playerOrderByXP(G.players);
}

function beginPhaseBuild(G, ctx) {
  beginPhase(G, ctx, PHASE.BUILD);
  G.logs.push(`--- Turn ${G.turn} - Build Phase ---`);
}

function endPhaseBuild(G, ctx) {
  for (const pid of playerOrderByXP(G.players)) {
    const p = G.players[pid];
    for (const stack of p.dungeon) {
      const room = activeRoom(stack);
      if (room) onBuildRoom(G, ctx, pid, room);
    }
    if (countVisibleRooms(p.dungeon) >= 5 && !p.leveledUp) {
      p.leveledUp = true;
      G.logs.push(`Player ${pid} LEVELED UP!`);
      processLevelUp(G, ctx, pid);
    }
  }
}

function beginPhaseBait(G, ctx) {
  beginPhase(G, ctx, PHASE.BAIT);
  G.logs.push(`--- Turn ${G.turn} - Bait Phase ---`);
}

function endPhaseBait(G, ctx) {
  const assignments = resolveBait(G);
  for (const assign of assignments) {
    const heroIdx = G.town.indexOf(assign.hero);
    if (assign.stayInTown || assign.targetPlayerId === null || isNoEntry(G, assign.targetPlayerId)) {
      if (isNoEntry(G, assign.targetPlayerId)) G.logs.push(`${assign.hero.name} stays in town (Trepidation).`);
      else G.logs.push(`${assign.hero.name} stays in town (tie/no lure)`);
      continue;
    }
    if (heroIdx >= 0) G.town.splice(heroIdx, 1);
    G.players[assign.targetPlayerId].entrance.push(assign.hero);
    G.logs.push(`${assign.hero.name} lured to Player ${assign.targetPlayerId}'s dungeon`);
  }
}

function beginPhaseAdventure(G, ctx) {
  beginPhase(G, ctx, PHASE.ADVENTURE);
  G.logs.push(`--- Turn ${G.turn} - Adventure Phase ---`);
}

function beginPhaseEnd(G, ctx) {
  G.phase = PHASE.END;
  ctx.phase = PHASE.END;
  G.effects = emptyEffects();
  G.logs.push(`--- Turn ${G.turn} - End Phase ---`);
  const result = checkEndGame(G);
  if (result.gameOver) {
    G.gameOver = true;
    G.winner = result.winner;
    G.logs.push(`Game Over! Player ${result.winner} wins!`);
  }
}

// Check if all non-eliminated players have passed -> phase ends.
function phaseComplete(G) {
  return Object.values(G.players).every(p => p.eliminated || p.passed);
}

function advancePhase(G, ctx) {
  // Called when a phase's endIf becomes true. Moves to the next phase and
  // runs its onBegin. Some phases auto-end immediately (BEGINNING, END).
  switch (G.phase) {
    case PHASE.BOSS:
      endPhaseSetup(G, ctx);
      beginPhase(G, ctx, PHASE.SETUP);
      G.logs.push('Setup: each player builds one room face-down in XP order.');
      break;
    case PHASE.SETUP:
      endPhaseSetupBuild(G, ctx);
      beginPhaseBeginning(G, ctx);
      break;
    case PHASE.BEGINNING:
      beginPhaseBuild(G, ctx);
      break;
    case PHASE.BUILD:
      endPhaseBuild(G, ctx);
      beginPhaseBait(G, ctx);
      break;
    case PHASE.BAIT:
      endPhaseBait(G, ctx);
      beginPhaseAdventure(G, ctx);
      break;
    case PHASE.ADVENTURE:
      // adventure end is a no-op
      beginPhaseEnd(G, ctx);
      break;
    case PHASE.END:
      if (G.gameOver) return; // stay in END if game is over
      beginPhaseBeginning(G, ctx);
      break;
  }
}

// ---------------------------------------------------------------------------
// Adventure resolution (per-player)
// ---------------------------------------------------------------------------
function resolveAdventureForPlayer(G, ctx, playerId) {
  const p = G.players[playerId];
  if (!p) return;
  while (p.entrance.length > 0) {
    const hero = p.entrance[0];
    G.logs.push(`${hero.name} enters Player ${playerId}'s dungeon`);
    let heroHP = heroHealthWithModifiers(G, hero);
    let deathRoom = null;

    for (let i = 0; i < p.dungeon.length && heroHP > 0; i++) {
      if (isRoomDeactivated(G, playerId, i)) {
        G.logs.push(`${activeRoom(p.dungeon[i]).name} is deactivated — skipped`);
        continue;
      }
      const dmg = roomDamageWithModifiers(G, playerId, i, hero);
      heroHP -= dmg;
      G.logs.push(`${activeRoom(p.dungeon[i]).name} deals ${dmg} damage to ${hero.name} (HP ${heroHP})`);
      if (heroHP <= 0) {
        deathRoom = activeRoom(p.dungeon[i]);
        break;
      }
    }

    const souls = hero.souls || 1;
    const wounds = hero.wounds || 1;
    if (heroHP <= 0) {
      for (let i = 0; i < souls; i++) p.souls.push({ souls: 1, name: hero.name });
      G.logs.push(`${hero.name} defeated! Player ${playerId} gains ${souls} soul(s).`);
      if (deathRoom) onHeroDiedInRoom(G, ctx, playerId, deathRoom, hero);
    } else {
      for (let i = 0; i < wounds; i++) p.wounds.push({ wounds: 1, name: hero.name });
      G.logs.push(`${hero.name} survives! Player ${playerId} takes ${wounds} wound(s).`);
    }
    const moved = p.entrance.shift();
    G.decks.heroDiscard.push(moved);
  }
}

// ---------------------------------------------------------------------------
// Move validation + application
// ---------------------------------------------------------------------------
function isActivePlayer(G, pid) {
  return String(pid) === String(G.activePlayer ?? null);
}

const MOVE_HANDLERS = {
  pickBoss: (G, ctx, pid, [bossId]) => {
    const p = G.players[pid];
    if (!p) return 'invalid player';
    if (p.boss) return 'boss already chosen';
    const boss = G.bossPicks.find(b => b.id === bossId);
    if (!boss) return 'boss not available';
    if (Object.values(G.players).some(pl => pl.boss?.id === bossId && pl !== p)) return 'boss taken by another player';
    p.boss = { ...boss };
    G.logs.push(`${pid === 0 ? 'You' : `Player ${pid}`} chose ${boss.name}`);
    return null;
  },

  buildInitialRoom: (G, ctx, pid, [handIndex]) => {
    if (!isActivePlayer(G, pid)) return 'not your turn';
    const p = G.players[pid];
    const card = p.hand[handIndex];
    if (!card || !card.isRoom || card.advanced) return 'invalid card';
    if (p.dungeon.length >= 1) return 'already built';
    buildRoom(G, pid, handIndex, null);
    G.logs.push(`${pid === 0 ? 'You' : `Player ${pid}`} built ${card.name} face down`);
    p.passed = true;
    return null;
  },

  buildRoom: (G, ctx, pid, [handIndex, targetIndex = null]) => {
    if (!isActivePlayer(G, pid)) return 'not your turn';
    const p = G.players[pid];
    const card = p.hand[handIndex];
    if (!card || !card.isRoom) return 'invalid card';
    if (isBuildBlocked(G)) return 'build blocked this turn';
    const allowed = 1 + extraBuildsFor(G, pid);
    if (p.buildsThisTurn >= allowed) return 'no builds left';
    if (!buildRoom(G, pid, handIndex, targetIndex)) return 'cannot build here';
    G.logs.push(`${pid === 0 ? 'You' : `Player ${pid}`} built ${card.name}`);
    onBuildRoom(G, ctx, pid, activeRoom(p.dungeon[p.dungeon.length - 1]) || card);
    p.passed = true;
    return null;
  },

  playSpell: (G, ctx, pid, [handIndex, target = null]) => {
    if (!isActivePlayer(G, pid)) return 'not your turn';
    const p = G.players[pid];
    const card = p.hand[handIndex];
    if (!card || !card.isSpell) return 'invalid card';
    if (!spellAllowedInPhase(card.category, G.phase)) return 'spell not allowed in this phase';
    p.hand.splice(handIndex, 1);
    G.decks.spellDiscard.push(card);
    G.logs.push(`${pid === 0 ? 'You' : `Player ${pid}`} cast ${card.name}`);
    castSpell(G, ctx, pid, card, target);
    p.passed = true;
    return null;
  },

  resolveNextHero: (G, ctx, pid) => {
    if (!isActivePlayer(G, pid)) return 'not your turn';
    resolveAdventureForPlayer(G, ctx, pid);
    return null;
  },

  pass: (G, ctx, pid) => {
    if (!isActivePlayer(G, pid)) return 'not your turn';
    G.players[pid].passed = true;
    G.logs.push(`${pid === 0 ? 'You' : `Player ${pid}`} passed`);
    return null;
  }
};

const VALID_MOVE_TYPES = new Set(Object.keys(MOVE_HANDLERS));

export function applyMove(state, move, playerID) {
  const G = cloneState(state.G);
  const ctx = { ...state.ctx };
  // Re-attach ctx on G for helper compatibility (some helpers read G.activePlayer/G.phase)
  G.activePlayer = ctx.activePlayer;

  if (!move || typeof move !== 'object' || !move.type) {
    return { state: { G, ctx }, error: 'invalid move shape' };
  }
  if (!VALID_MOVE_TYPES.has(move.type)) {
    return { state: { G, ctx }, error: `unknown move type: ${move.type}` };
  }
  if (G.gameOver) {
    return { state: { G, ctx }, error: 'game is over' };
  }

  const args = Array.isArray(move.args) ? move.args : [];
  const handler = MOVE_HANDLERS[move.type];
  const err = handler(G, ctx, Number(playerID), args);
  if (err) return { state: { G, ctx }, error: err };

  // BOSS phase is special: ends when all *human* players have picked. AI picks
  // are auto-filled in endPhaseSetup. Other phases end when all non-eliminated
  // players have passed.
  let phaseEnded = false;
  if (G.phase === PHASE.BOSS) {
    const humans = Object.values(G.players).filter(p => !p.isAI);
    phaseEnded = humans.every(p => p.boss !== null);
  } else {
    phaseEnded = phaseComplete(G);
  }

  if (phaseEnded) {
    advancePhase(G, ctx);
    // BEGINNING and END auto-advance immediately (their endIf is always true).
    while ((G.phase === PHASE.BEGINNING || G.phase === PHASE.END) && !G.gameOver) {
      // BEGINNING and END have no moves; they transition straight on.
      advancePhase(G, ctx);
    }
  } else {
    // Advance the active player within the same phase.
    const nxt = nextXPActivePlayer(G, ctx.activePlayer);
    if (nxt != null) {
      ctx.activePlayer = nxt;
      ctx.currentPlayer = nxt;
      G.activePlayer = nxt;
    }
  }

  return { state: { G, ctx } };
}

// Deep clone the game state. JSON round-trip is sufficient because G contains
// only plain data (no functions, no Dates, no class instances).
function cloneState(G) {
  return JSON.parse(JSON.stringify(G));
}

// ---------------------------------------------------------------------------
// playerView: hide opponent hands
// ---------------------------------------------------------------------------
export function playerView(G, playerID) {
  const me = String(playerID);
  const filtered = { ...G };
  filtered.players = { ...filtered.players };
  Object.keys(filtered.players).forEach(pid => {
    if (pid !== me) {
      const p = filtered.players[pid];
      filtered.players[pid] = { ...p, hand: (p.hand || []).map(() => ({ hidden: true })) };
    }
  });
  return filtered;
}

// ---------------------------------------------------------------------------
// legalMoves: enumerate legal moves for a player (used by AI bots in solo).
// ---------------------------------------------------------------------------
export function legalMoves(G, ctx, playerID) {
  const pid = Number(playerID);
  const p = G.players[pid];
  if (!p || p.eliminated || G.gameOver) return [];
  const phase = G.phase;
  const moves = [];

  if (phase === PHASE.BOSS) {
    const available = G.bossPicks.filter(b =>
      !Object.values(G.players).some(pl => pl.boss?.id === b.id)
    );
    for (const b of available) moves.push({ type: 'pickBoss', args: [b.id] });
    return moves;
  }

  if (!isActivePlayer(G, pid)) return moves;

  if (phase === PHASE.SETUP) {
    p.hand.forEach((c, i) => {
      if (c.isRoom && !c.advanced) moves.push({ type: 'buildInitialRoom', args: [i] });
    });
    return moves;
  }

  if (phase === PHASE.BUILD) {
    if (!isBuildBlocked(G)) {
      const allowed = 1 + extraBuildsFor(G, pid);
      if (p.buildsThisTurn < allowed) {
        p.hand.forEach((c, i) => {
          if (c.isRoom) moves.push({ type: 'buildRoom', args: [i, null] });
        });
      }
    }
    p.hand.forEach((c, i) => {
      if (c.isSpell && spellAllowedInPhase(c.category, PHASE.BUILD)) {
        moves.push({ type: 'playSpell', args: [i, null] });
      }
    });
    moves.push({ type: 'pass', args: [] });
    return moves;
  }

  if (phase === PHASE.BAIT) {
    p.hand.forEach((c, i) => {
      if (c.isSpell && spellAllowedInPhase(c.category, PHASE.BAIT)) {
        moves.push({ type: 'playSpell', args: [i, null] });
      }
    });
    moves.push({ type: 'pass', args: [] });
    return moves;
  }

  if (phase === PHASE.ADVENTURE) {
    p.hand.forEach((c, i) => {
      if (c.isSpell && spellAllowedInPhase(c.category, PHASE.ADVENTURE)) {
        moves.push({ type: 'playSpell', args: [i, null] });
      }
    });
    if (p.entrance.length > 0) moves.push({ type: 'resolveNextHero', args: [] });
    moves.push({ type: 'pass', args: [] });
    return moves;
  }

  return [];
}

export const GAME_META = { name: GAME_NAME, minPlayers: MIN_PLAYERS, maxPlayers: MAX_PLAYERS };