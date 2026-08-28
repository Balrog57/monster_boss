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
  BOSSES, ROOMS, SPELLS, HEROES, ITEMS, PHASE,
  getExpandedDeck, shuffle, drawCards, playerOrderByXP, totalSouls, totalWounds,
  allowedCardSets, cardsInSets, heroesForSets, EXPANSION_PACKS, spellAllowedInPhase, canPlaySpell,
} from '../src/cardData.js';
import { castSpell, emptyEffects, isBuildBlocked, extraBuildsFor, isRoomDeactivated, isNoEntry, heroDamageFor, consumeHeroDamage } from '../src/spellEffects.js';
import { onBuildRoom, onHeroDiedInRoom, processLevelUp, activateRoomAbility, resolveLevelUpChoice, aiResolveLevelUpChoice } from '../src/roomAbilities.js';
import {
  activeRoom, countVisibleRooms,
  resolveBait, buildRoom, canBuildRoom, heroHealthWithModifiers,
  roomDamageWithModifiers, checkEndGame
} from '../src/engine.js';
import { refillDeckFromDiscard } from '../src/cardData.js';
import { emptyStack, pushEffect, allPassed as stackAllPassed, resolveStack } from '../src/stack.js';
import { spellTargetsFor } from '../src/spellTargeting.js';
import {
  itemRevealCount, tryAttachRevealedItem, tryAttachItemsToHero,
  applyHeroEnterDungeon, onHeroEnterRoom, onHeroSurvivedRoom,
  applyItemReward, applyItemSurvivePowerUp, takeHeroItem, spellsBlockedFor,
  dungeonIgnoresRoomAbilities, heroIgnoresRoomAbilities,
} from '../src/items.js';

// Refill a deck from its discard pile if empty. Called before every draw.
function ensureDeck(decks, name) {
  const deck = decks[name];
  const discardName = name + 'Discard';
  const discard = decks[discardName];
  if (deck && discard) refillDeckFromDiscard(deck, discard);
}

const HERO_COUNTS = {
  2: { ordinary: 13, epic: 8 },
  3: { ordinary: 17, epic: 12 },
  4: { ordinary: 25, epic: 16 }
};

const GAME_NAME = 'boss-monster';
const MIN_PLAYERS = 2;
const MAX_PLAYERS = 4;

function welcomeLog(expansions) {
  const packs = expansions == null ? EXPANSION_PACKS.map((p) => p.id) : expansions;
  const picked = EXPANSION_PACKS.filter((p) => packs.includes(p.id)).map((p) => p.label);
  if (!picked.length) return 'Welcome to Boss Monster! Base set.';
  return `Welcome to Boss Monster! Base + ${picked.join(' + ')}.`;
}

// ---------------------------------------------------------------------------
// setup
// ---------------------------------------------------------------------------
function dealBossCards(numPlayers, bosses) {
  const pool = bosses && bosses.length ? bosses : BOSSES;
  return shuffle(pool).slice(0, Math.min(numPlayers * 2, pool.length));
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
  const sets = allowedCardSets(setupData.expansions);
  const bosses = cardsInSets(BOSSES, sets);
  const rooms = cardsInSets(ROOMS, sets);
  const spells = cardsInSets(SPELLS, sets);
  const heroes = heroesForSets(HEROES, sets);
  const items = cardsInSets(ITEMS, sets);

  const roomDeck = shuffle(getExpandedDeck(rooms).map(r => ({ ...r, isRoom: true })));
  const spellDeck = shuffle(getExpandedDeck(spells).map(s => ({ ...s, isSpell: true })));
  const ordinaryHeroes = shuffle(getExpandedDeck(filterHeroesByPlayerCount(heroes.filter(h => !h.epic), n)).map(h => ({ ...h, epic: false, wounds: 1, souls: 1 })));
  const epicHeroes = shuffle(getExpandedDeck(filterHeroesByPlayerCount(heroes.filter(h => h.epic), n)).map(h => ({ ...h, epic: true, wounds: 2, souls: 2 })));

  const itemDeck = shuffle(getExpandedDeck(items).map(it => ({ ...it, isItem: true })));

  const players = {};
  for (let i = 0; i < n; i++) {
    players[i] = {
      boss: null,
      dungeon: [],
      hand: [],
      souls: [],
      wounds: [],
      entrance: [],
      items: [],
      eliminated: false,
      leveledUp: false,
      buildsThisTurn: 0,
      isAI: setupData.online ? false : i > 0,
      passed: false
    };
  }

  const G = {
    players,
    bossPicks: dealBossCards(n, bosses),
    numPlayers: n,
    xpOrder: playerOrderByXP(players),
    decks: {
      rooms: roomDeck,
      spells: spellDeck,
      heroes: ordinaryHeroes,
      epics: epicHeroes,
      items: itemDeck,
      roomDiscard: [],
      spellDiscard: [],
      heroDiscard: [],
      itemsDiscard: []
    },
    town: [],
    townItems: [],
    stack: emptyStack(),
    stackPassed: {},
    adventure: null,
    turn: 0,
    phase: PHASE.BOSS,
    effects: emptyEffects(),
    logs: [welcomeLog(setupData.expansions)],
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
function pushSpellMoves(G, p, pid, phase, moves) {
  if (spellsBlockedFor(G, pid)) return;
  p.hand.forEach((c, i) => {
    if (!c.isSpell || !canPlaySpell(c, phase, G.stack?.length || 0)) return;
    const targets = spellTargetsFor(G, p, pid, c.id);
    if (!targets.length) return;
    for (const target of targets) {
      moves.push({ type: 'playSpell', args: [i, target] });
    }
  });
}

function pushBuildMoves(G, pid, p, moves) {
  if (isBuildBlocked(G)) return;
  const allowed = 1 + extraBuildsFor(G, pid);
  if (p.buildsThisTurn >= allowed) return;
  p.hand.forEach((c, i) => {
    if (!c.isRoom) return;
    if (canBuildRoom(G, pid, i, null)) {
      moves.push({ type: 'buildRoom', args: [i, null] });
    }
    for (let ti = 0; ti < p.dungeon.length; ti++) {
      if (canBuildRoom(G, pid, i, ti)) {
        moves.push({ type: 'buildRoom', args: [i, ti] });
      }
    }
  });
}

function nextXPActivePlayer(G, current) {
  const order = G.xpOrder || [0, 1];
  const cur = current != null ? current : order[0];
  const idx = order.indexOf(cur);
  for (let i = 1; i <= order.length; i++) {
    const candidate = order[(idx + i) % order.length];
    // Skip eliminated, passed, or players who have already acted (built).
    if (candidate != null && !G.players[candidate]?.eliminated && !G.players[candidate]?.passed && !G.players[candidate]?.hasActed) {
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
  G.activePlayer = ctx.activePlayer;
  for (const p of Object.values(G.players)) {
    p.passed = false;
    p.hasActed = false;
  }
}

function openingDiscardScore(card) {
  if (!card) return 0;
  if (card.isSpell) return 80;
  return (card.damage || 0) * 10 + (card.advanced ? 8 : 0);
}

export function pickOpeningDiscardIndices(hand) {
  const scored = (hand || []).map((c, i) => ({ i, score: openingDiscardScore(c) }));
  scored.sort((a, b) => a.score - b.score);
  if (scored.length < 2) return null;
  return [scored[0].i, scored[1].i];
}

function applyOpeningDiscard(G, pid, a, b) {
  const p = G.players[pid];
  if (!p) return 'invalid player';
  if (a == null || b == null || a === b) return 'pick two different cards';
  if (a < 0 || b < 0 || a >= p.hand.length || b >= p.hand.length) return 'invalid card';
  const idxs = [a, b].sort((x, y) => y - x);
  const names = [];
  for (const i of idxs) {
    const c = p.hand.splice(i, 1)[0];
    names.push(c.name);
    if (c.isSpell) G.decks.spellDiscard.push(c);
    else G.decks.roomDiscard.push(c);
  }
  names.reverse();
  G.logs.push(`${pid === 0 ? 'You' : `Player ${pid}`} discarded ${names.join(' and ')}.`);
  return null;
}

function queueNextOpeningDiscard(G) {
  const next = Object.keys(G.players).map(Number).find((id) => {
    const p = G.players[id];
    return p && !p.eliminated && !p.isAI && p.hand.length > 5;
  });
  G.pendingChoice = next == null ? null : {
    type: 'opening-discard',
    playerId: next,
    message: 'SELECT 2 CARDS TO DISCARD',
  };
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
  // Deal 5 rooms + 2 spells, then discard 2 (APK + physical rules → 5 in hand).
  for (let i = 0; i < ctx.numPlayers; i++) {
    const p = G.players[i];
    drawCards(G.decks.rooms, 5).forEach(c => p.hand.push(c));
    drawCards(G.decks.spells, 2).forEach(c => p.hand.push(c));
    if (p.isAI) {
      const pair = pickOpeningDiscardIndices(p.hand);
      if (pair) applyOpeningDiscard(G, i, pair[0], pair[1]);
    }
  }
  // Seed discard piles
  drawCards(G.decks.rooms, 4).forEach(c => G.decks.roomDiscard.push(c));
  drawCards(G.decks.spells, 2).forEach(c => G.decks.spellDiscard.push(c));
  G.xpOrder = playerOrderByXP(G.players);
  G.logs.push('Setup: hands dealt, discard seeded.');
  queueNextOpeningDiscard(G);
}

function endPhaseSetupBuild(G, ctx) {
  // Reveal face-down rooms in XP order and trigger onBuildRoom
  for (const pid of playerOrderByXP(G.players)) {
    const room = activeRoom(G.players[pid].dungeon[0]);
    if (room) {
      G.logs.push(`Revealed ${room.name} for Player ${pid}`);
      const choice = onBuildRoom(G, ctx, pid, room);
      if (choice) {
        G.pendingChoice = choice;
        return; // wait for player choice before continuing
      }
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
  // Refill hero/epic decks from discard if empty.
  ensureDeck(G.decks, 'heroes');
  ensureDeck(G.decks, 'epics');
  for (let i = 0; i < aliveCount; i++) {
    let hero = null;
    if (G.decks.heroes.length > 0) hero = G.decks.heroes.pop();
    else if (G.decks.epics.length > 0) hero = G.decks.epics.pop();
    if (hero) {
      G.town.push(hero);
      G.logs.push(`${hero.name} arrives in town`);
      tryAttachItemsToHero(G, hero);
    }
  }
  // Tools of Hero-Kind: 1 Item (2 in a 4-player game), not one per player.
  ensureDeck(G.decks, 'items');
  const nItems = itemRevealCount(aliveCount);
  for (let i = 0; i < nItems; i++) {
    const item = G.decks.items.pop();
    if (item) {
      G.logs.push(`${item.name} revealed in town`);
      tryAttachRevealedItem(G, item);
    }
  }
  // Refill room deck from discard if empty.
  ensureDeck(G.decks, 'rooms');
  ensureDeck(G.decks, 'spells');
  for (let i = 0; i < ctx.numPlayers; i++) {
    const p = G.players[i];
    if (p.eliminated) continue;
    // Haunted Library (BMA023): draw from spell deck instead of room deck.
    const hasHauntedLibrary = p.dungeon.some(stack => {
      const r = activeRoom(stack);
      return r && r.id === 'BMA023' && !r.faceDown;
    });
    if (hasHauntedLibrary) {
      const spell = G.decks.spells.pop();
      if (spell) p.hand.push(spell);
    } else {
      const room = G.decks.rooms.pop();
      if (room) p.hand.push(room);
    }
  }
  for (const p of Object.values(G.players)) {
    p.buildsThisTurn = 0;
    p.passed = false;
    p.hasActed = false;
    p.woundImmuneThisTurn = false;
    p.wounds = (p.wounds || []).filter((w) => !w.temp);
    for (const stack of p.dungeon || []) {
      for (const room of stack || []) {
        if (room) room.usedThisTurn = false;
      }
    }
  }
  G.effects = emptyEffects();
  G.xpOrder = playerOrderByXP(G.players);
}

function beginPhaseBuild(G, ctx) {
  beginPhase(G, ctx, PHASE.BUILD);
  G.logs.push(`--- Turn ${G.turn} - Build Phase ---`);
}

function endPhaseBuild(G, ctx) {
  // Reveal face-down rooms and fire onBuildRoom for newly built rooms only.
  // Per official rules: rooms are built face-down during BUILD, then revealed
  // simultaneously at the end of the phase. "When you build this room" effects
  // fire at reveal time, in XP order. Rooms that were already revealed from
  // previous turns do NOT re-trigger.
  for (const pid of playerOrderByXP(G.players)) {
    const p = G.players[pid];
    for (const stack of p.dungeon) {
      const room = activeRoom(stack);
      if (room && room.faceDown) {
        room.faceDown = false;
        G.logs.push(`Revealed ${room.name} for Player ${pid}`);
        const choice = onBuildRoom(G, ctx, pid, room);
        if (choice) {
          G.pendingChoice = choice;
          return; // wait for player choice
        }
      }
    }
    if (countVisibleRooms(p.dungeon) >= 5 && !p.leveledUp) {
      p.leveledUp = true;
      G.logs.push(`Player ${pid} LEVELED UP!`);
      const choice = processLevelUp(G, ctx, pid);
      if (choice) {
        G.pendingChoice = choice;
        return; // wait for player choice
      }
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
    attachMatchingItem(G, assign.hero);
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
  // A phase ends when all non-eliminated players have either passed or acted.
  // `hasActed` is set by buildRoom (BUILD phase) and pass (all phases).
  // `passed` is set only by pass. Either flag indicates the player is done.
  return Object.values(G.players).every(p => p.eliminated || p.passed || p.hasActed);
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
      if (G.pendingChoice) return; // wait for choice resolution
      beginPhaseBeginning(G, ctx);
      break;
    case PHASE.BEGINNING:
      beginPhaseBuild(G, ctx);
      break;
    case PHASE.BUILD:
      endPhaseBuild(G, ctx);
      if (G.pendingChoice) return; // wait for choice resolution
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
// Adventure resolution (one room at a time, matching the APK pause)
// ---------------------------------------------------------------------------
function attachMatchingItem(G, hero) {
  tryAttachItemsToHero(G, hero);
}

function otherPlayer(G, pid) {
  return Object.keys(G.players)
    .map(Number)
    .find(id => id !== Number(pid) && !G.players[id]?.eliminated);
}

function resolvePendingStack(G, ctx) {
  resolveStack(G, ctx, (effect) => {
    if (effect.type === 'spell' && effect.card) {
      G.decks.spellDiscard.push(effect.card);
      G.logs.push(`${effect.card.name} resolves.`);
      castSpell(G, ctx, effect.playerId, effect.card, effect.target);
    }
  });
  G.stackReturnPlayer = null;
}

function finishHero(G, ctx, playerId, hero, heroHP, deathRoom) {
  const p = G.players[playerId];
  const souls = hero.souls || 1;
  const wounds = hero.wounds || 1;
  const ei = p.entrance.findIndex(h => h.id === hero.id && h.name === hero.name);
  if (ei >= 0) p.entrance.splice(ei, 1);
  else if (p.entrance[0]) p.entrance.splice(0, 1);

  if (heroHP <= 0) {
    if (hero.item?.id === 'THK001') {
      G.logs.push(`Extra Life: ${hero.name} returns to town.`);
      applyItemReward(G, playerId, hero.item);
      takeHeroItem(p, hero);
      G.town.push(hero);
      tryAttachItemsToHero(G, hero);
    } else {
      for (let i = 0; i < souls; i++) p.souls.push({ souls: 1, name: hero.name, class: hero.class });
      if (hero.item) {
        applyItemReward(G, playerId, hero.item);
        takeHeroItem(p, hero);
      }
      G.logs.push(`${hero.name} defeated! Player ${playerId} gains ${souls} soul(s).`);
      if (deathRoom && !heroIgnoresRoomAbilities(hero)) onHeroDiedInRoom(G, ctx, playerId, deathRoom, hero);
      G.decks.heroDiscard.push(hero);
    }
  } else {
    applyItemSurvivePowerUp(G, playerId, hero);
    for (let i = 0; i < wounds; i++) p.wounds.push({ wounds: 1, name: hero.name });
    G.logs.push(`${hero.name} survives! Player ${playerId} takes ${wounds} wound(s).`);
    G.decks.heroDiscard.push(hero);
  }
  G.adventure = null;
}

function advanceAdventureRoom(G, ctx) {
  const adv = G.adventure;
  if (!adv) return 'no hero in the dungeon';
  const playerId = adv.playerId;
  const p = G.players[playerId];
  const hero = adv.hero;
  let i = adv.roomIndex + 1;
  while (i < p.dungeon.length && isRoomDeactivated(G, playerId, i)) {
    G.logs.push(`${activeRoom(p.dungeon[i])?.name || 'Room'} is deactivated — skipped`);
    i += 1;
  }
  if (i >= p.dungeon.length) {
    finishHero(G, ctx, playerId, hero, adv.hp, null);
    return null;
  }
  const room = activeRoom(p.dungeon[i]);
  if (adv.skipNext) {
    adv.skipNext = false;
    adv.roomIndex = i;
    G.logs.push(`Boots of Jumping: ${hero.name} ignores ${room?.name || 'a room'}.`);
    return null;
  }
  if (room && room.id === 'BMA017' && !adv.mazeSentBack && i > 0 && !heroIgnoresRoomAbilities(hero)) {
    adv.mazeSentBack = true;
    adv.roomIndex = i - 1;
    G.logs.push(`Minotaur's Maze: ${hero.name} sent back one room!`);
    return null;
  }
  const enter = onHeroEnterRoom(G, playerId, i, room, hero);
  if (enter.skipDamage) {
    adv.roomIndex = i;
    return null;
  }
  const dmg = roomDamageWithModifiers(G, playerId, i, hero);
  adv.hp -= dmg;
  adv.roomIndex = i;
  G.logs.push(`${room?.name || 'Room'} deals ${dmg} damage to ${hero.name} (HP ${adv.hp})`);
  if (adv.hp <= 0) finishHero(G, ctx, playerId, hero, adv.hp, room);
  else onHeroSurvivedRoom(G, playerId, i, room, hero, adv);
  return null;
}

function startAdventure(G, ctx, playerId) {
  const p = G.players[playerId];
  if (!p || p.entrance.length === 0) return 'no heroes at entrance';
  const hero = p.entrance[0];
  G.adventure = {
    playerId,
    hero,
    roomIndex: -1,
    hp: hero.hp,
    mazeSentBack: false,
  };
  G.logs.push(`${hero.name} enters Player ${playerId}'s dungeon`);
  applyHeroEnterDungeon(G, playerId, hero);
  let hp = heroHealthWithModifiers(G, hero);
  const pendingDmg = heroDamageFor(G, hero.id);
  if (pendingDmg > 0) {
    hp -= pendingDmg;
    consumeHeroDamage(G, hero.id);
    G.logs.push(`Exhaustion deals ${pendingDmg} damage to ${hero.name} (HP ${hp})`);
  }
  G.adventure.hp = hp;
  if (hp <= 0) {
    finishHero(G, ctx, playerId, hero, hp, null);
    return null;
  }
  if (G.effects.teleportHero === hero.id) {
    G.adventure.roomIndex = -1;
    G.effects.teleportHero = null;
    G.logs.push('Teleportation: hero starts at the first room.');
  }
  return advanceAdventureRoom(G, ctx);
}

function resolveOneHero(G, ctx, playerId, entranceIndex) {
  // Legacy helper used by tests / leftover calls: resolve the whole dungeon.
  const p = G.players[playerId];
  if (!p || entranceIndex >= p.entrance.length) return;
  startAdventure(G, ctx, playerId);
  while (G.adventure && G.adventure.playerId === playerId) {
    const before = G.adventure.roomIndex;
    advanceAdventureRoom(G, ctx);
    if (G.adventure && G.adventure.roomIndex === before) break;
  }
}

function resolveAdventureForPlayer(G, ctx, playerId) {
  const p = G.players[playerId];
  if (!p) return;
  while (p.entrance.length > 0) {
    resolveOneHero(G, ctx, playerId, 0);
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
    const stack = p.dungeon[p.dungeon.length - 1];
    const newRoom = stack?.[stack.length - 1];
    if (newRoom) newRoom.faceDown = true;
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
    // Mark the newly built room as face-down. It will be revealed at the end
    // of the BUILD phase, at which point onBuildRoom fires.
    const stack = p.dungeon[targetIndex != null ? targetIndex : p.dungeon.length - 1];
    const newRoom = stack[stack.length - 1];
    newRoom.faceDown = true;
    G.logs.push(`${pid === 0 ? 'You' : `Player ${pid}`} built a room face down`);
    // Building consumes the player's build action for this phase. The player
    // has acted — mark it so the phase can end when all have acted.
    p.hasActed = true;
    return null;
  },

  playSpell: (G, ctx, pid, [handIndex, target = null]) => {
    if (!isActivePlayer(G, pid)) return 'not your turn';
    const p = G.players[pid];
    const card = p.hand[handIndex];
    if (!card || !card.isSpell) return 'invalid card';
    if (spellsBlockedFor(G, pid)) return 'cannot play spells while Ring of Invisibility is in your dungeon';
    if (!canPlaySpell(card, G.phase, G.stack?.length || 0)) return 'spell not allowed in this phase';
    p.hand.splice(handIndex, 1);
    G.logs.push(`${pid === 0 ? 'You' : `Player ${pid}`} cast ${card.name}`);

    if (card.id === 'BMA043') {
      const top = (G.stack || []).pop();
      G.decks.spellDiscard.push(card);
      if (top?.card) {
        G.decks.spellDiscard.push(top.card);
        G.logs.push(`Counterspell cancels ${top.card.name}.`);
      } else {
        G.logs.push('Counterspell: nothing on the stack.');
      }
      G.skipAdvance = true;
      if (G.stackReturnPlayer != null) {
        ctx.activePlayer = G.stackReturnPlayer;
        ctx.currentPlayer = G.stackReturnPlayer;
        G.activePlayer = G.stackReturnPlayer;
      }
    } else {
      if (!G.stack) G.stack = emptyStack();
      pushEffect(G, pid, 'spell', card, target);
      G.stackPassed = { [String(pid)]: true };
      G.stackReturnPlayer = pid;
      const opp = otherPlayer(G, pid);
      if (opp != null) {
        ctx.activePlayer = opp;
        ctx.currentPlayer = opp;
        G.activePlayer = opp;
        G.skipAdvance = true;
      } else {
        resolvePendingStack(G, ctx);
      }
    }

    // Liger's Den (BMA026): when you play a spell, draw a spell.
    for (const stack of p.dungeon) {
      const r = activeRoom(stack);
      if (r && r.id === 'BMA026' && !r.faceDown) {
        ensureDeck(G.decks, 'spells');
        const drawn = G.decks.spells.pop();
        if (drawn) { p.hand.push(drawn); G.logs.push(`Liger's Den: drew ${drawn.name}.`); }
        break;
      }
    }
    return null;
  },

  resolveNextHero: (G, ctx, pid) => {
    if (!isActivePlayer(G, pid)) return 'not your turn';
    if (G.stack?.length) return 'stack must resolve first';
    let err;
    if (G.adventure) {
      if (Number(G.adventure.playerId) !== Number(pid)) return 'another hero is in a dungeon';
      err = advanceAdventureRoom(G, ctx);
    } else {
      const p = G.players[pid];
      if (!p || p.entrance.length === 0) return 'no heroes at entrance';
      err = startAdventure(G, ctx, pid);
      if (p.entrance.length === 0 && !G.adventure) p.passed = true;
    }
    if (!err) {
      G.skipAdvance = true;
      const p = G.players[pid];
      if (p && p.entrance.length === 0 && !G.adventure) p.passed = true;
    }
    return err;
  },

  pass: (G, ctx, pid) => {
    if (!isActivePlayer(G, pid)) return 'not your turn';
    if (G.stack?.length) {
      G.stackPassed = G.stackPassed || {};
      G.stackPassed[String(pid)] = true;
      if (stackAllPassed(G, G.players)) resolvePendingStack(G, ctx);
      G.skipAdvance = true;
      if (G.stackReturnPlayer != null) {
        ctx.activePlayer = G.stackReturnPlayer;
        ctx.currentPlayer = G.stackReturnPlayer;
        G.activePlayer = G.stackReturnPlayer;
      }
      return null;
    }
    G.players[pid].passed = true;
    G.players[pid].hasActed = true;
    G.logs.push(`${pid === 0 ? 'You' : `Player ${pid}`} passed`);
    return null;
  },

  openingDiscard: (G, ctx, pid, [a, b]) => {
    if (!G.pendingChoice || G.pendingChoice.type !== 'opening-discard') return 'no opening discard';
    if (Number(pid) !== G.pendingChoice.playerId) return 'not your choice to make';
    const err = applyOpeningDiscard(G, pid, a, b);
    if (err) return err;
    queueNextOpeningDiscard(G);
    return null;
  },

  activateRoom: (G, ctx, pid, [roomIndex, otherRoomIndex = null]) => {
    if (!isActivePlayer(G, pid)) return 'not your turn';
    const err = activateRoomAbility(G, ctx, pid, roomIndex, otherRoomIndex);
    if (err) return err;
    // Activated abilities do NOT pass the turn.
    return null;
  },

  resolveLevelUpChoice: (G, ctx, pid, [optionIndex]) => {
    if (!G.pendingChoice) return 'no pending choice';
    if (Number(pid) !== G.pendingChoice.playerId) return 'not your choice to make';
    const err = resolveLevelUpChoice(G, ctx, pid, optionIndex);
    if (err) return err;
    // After resolving, continue the phase transition that was paused.
    // Re-run endPhaseBuild/endPhaseSetupBuild to process remaining level-ups.
    if (G.phase === PHASE.BUILD || G.phase === PHASE.SETUP) {
      if (G.phase === PHASE.BUILD) {
        endPhaseBuild(G, ctx);
        if (!G.pendingChoice) beginPhaseBait(G, ctx);
      } else {
        endPhaseSetupBuild(G, ctx);
        if (!G.pendingChoice) beginPhaseBeginning(G, ctx);
      }
    }
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

  // Block other moves while a pending choice exists.
  if (G.pendingChoice && move.type !== 'resolveLevelUpChoice' && move.type !== 'openingDiscard') {
    return { state: { G, ctx }, error: 'must resolve pending choice first' };
  }

  const args = Array.isArray(move.args) ? move.args : [];
  const handler = MOVE_HANDLERS[move.type];
  const err = handler(G, ctx, Number(playerID), args);
  if (err) return { state: { G, ctx }, error: err };

  // If a pending choice was just set by the handler (e.g. resolveLevelUpChoice
  // triggered another level-up), return immediately and wait for the player.
  if (G.pendingChoice) {
    return { state: { G, ctx } };
  }

  if (G.skipAdvance) {
    G.skipAdvance = false;
    return { state: { G, ctx } };
  }

  // If the handler moved us into an auto-advance phase (BAIT/BEGINNING/END),
  // auto-advance immediately (e.g. after resolveLevelUpChoice completes BUILD).
  while ((G.phase === PHASE.BEGINNING || G.phase === PHASE.BAIT || G.phase === PHASE.END) && !G.gameOver) {
    advancePhase(G, ctx);
  }
  if (G.pendingChoice) {
    return { state: { G, ctx } };
  }

  // BOSS phase is special: ends when all *human* players have picked. AI picks
  // are auto-filled in endPhaseSetup. Other phases end when all non-eliminated
  // players have passed.
  let phaseEnded = false;
  const adventureLeftover = G.phase === PHASE.ADVENTURE && (
    !!G.adventure || Object.values(G.players).some(p => !p.eliminated && p.entrance?.length > 0)
  );
  if (G.phase === PHASE.BOSS) {
    const humans = Object.values(G.players).filter(p => !p.isAI);
    phaseEnded = humans.every(p => p.boss !== null);
  } else if (adventureLeftover) {
    phaseEnded = false;
    if (phaseComplete(G)) {
      for (const p of Object.values(G.players)) {
        p.passed = false;
        p.hasActed = false;
      }
      const nextPid = G.adventure?.playerId ?? Object.keys(G.players).map(Number).find(id => G.players[id].entrance?.length > 0);
      if (nextPid != null) {
        ctx.activePlayer = nextPid;
        ctx.currentPlayer = nextPid;
        G.activePlayer = nextPid;
      }
    }
  } else {
    phaseEnded = phaseComplete(G);
  }

  if (phaseEnded) {
    advancePhase(G, ctx);
    // BEGINNING, BAIT, and END auto-advance immediately (no player moves).
    while ((G.phase === PHASE.BEGINNING || G.phase === PHASE.BAIT || G.phase === PHASE.END) && !G.gameOver) {
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
// Rooms with activated abilities ("destroy this room: X" or "destroy another room: X").
const ACTIVATED_ABILITY_ROOMS = new Set([
  'BMA009', // Dark Altar
  'BMA013', // Dracolich Lair
  'BMA025', // All-Seeing Eye
  'BMA027', // Bottomless Pit
  'BMA028', // Boulder Ramp
  'BMA030', // Jackpot Stash
  'BMA032', // The Crushinator
  'BMA038', // Torture Chamber
  'BMA039', // Zombie Prison
  'THK021', // Orcish Smithy
  'THK022', // Burial Mound
  'THK023', // Artificer's Workbench
]);

function hasActivatedAbility(roomId) {
  return ACTIVATED_ABILITY_ROOMS.has(roomId);
}

// Rooms whose activated ability destroys ANOTHER room (needs a second target).
const NEEDS_OTHER_TARGET_ROOMS = new Set(['BMA028', 'BMA032']);

// Push legal activateRoom moves for a player's dungeon. Rooms that destroy
// another room (Boulder Ramp, The Crushinator) require a valid other target;
// they are only offered when at least one other room exists.
function canOfferActivatedRoom(G, p, room) {
  if (!room || !hasActivatedAbility(room.id) || room.usedThisTurn || room.faceDown) return false;
  if (G.phase === PHASE.ADVENTURE && dungeonIgnoresRoomAbilities(G, Object.keys(G.players).find((id) => G.players[id] === p))) {
    return false;
  }
  if (room.id === 'THK021') {
    return G.phase === PHASE.BUILD && (G.townItems || []).length > 0;
  }
  if (room.id === 'THK022') {
    return p.hand.filter((c) => c.isRoom).length >= 2 && (p.items || []).some((it) => it.faceDown);
  }
  if (room.id === 'THK023') {
    return (p.items || []).some((it) => !it.faceDown);
  }
  if (room.id === 'BMA013') return p.hand.filter((c) => c.isRoom).length >= 2;
  if (room.id === 'BMA025') return p.hand.some((c) => c.isSpell) && (G.stack?.length || 0) > 0;
  if (room.id === 'BMA027') {
    return (p.entrance || []).length > 0 || (G.adventure && String(G.adventure.playerId) === String(Object.keys(G.players).find((id) => G.players[id] === p)));
  }
  return true;
}

function pushActivateMoves(G, p, moves) {
  p.dungeon.forEach((stack, i) => {
    const room = activeRoom(stack);
    if (!canOfferActivatedRoom(G, p, room)) return;
    if (NEEDS_OTHER_TARGET_ROOMS.has(room.id)) {
      p.dungeon.forEach((_, j) => {
        if (j !== i && activeRoom(p.dungeon[j])) {
          moves.push({ type: 'activateRoom', args: [i, j] });
        }
      });
    } else {
      moves.push({ type: 'activateRoom', args: [i, null] });
    }
  });
}

export function legalMoves(G, ctx, playerID) {
  const pid = Number(playerID);
  const p = G.players[pid];
  if (!p || p.eliminated || G.gameOver) return [];
  const phase = G.phase;
  const moves = [];

  // If there's a pending choice for this player, that's the only legal move.
  if (G.pendingChoice) {
    if (G.pendingChoice.playerId === pid) {
      if (G.pendingChoice.type === 'opening-discard') {
        const n = p.hand.length;
        for (let i = 0; i < n; i++) {
          for (let j = i + 1; j < n; j++) {
            moves.push({ type: 'openingDiscard', args: [i, j] });
          }
        }
      } else {
        (G.pendingChoice.options || []).forEach((_, i) => moves.push({ type: 'resolveLevelUpChoice', args: [i] }));
      }
    }
    return moves;
  }

  if (G.stack?.length) {
    p.hand.forEach((c, i) => {
      if (c.isSpell && c.id === 'BMA043') moves.push({ type: 'playSpell', args: [i, null] });
    });
    moves.push({ type: 'pass', args: [] });
    return moves;
  }

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
    if (!moves.length) moves.push({ type: 'pass', args: [] });
    return moves;
  }

  if (phase === PHASE.BUILD) {
    pushBuildMoves(G, pid, p, moves);
    pushSpellMoves(G, p, pid, PHASE.BUILD, moves);
    pushActivateMoves(G, p, moves);
    moves.push({ type: 'pass', args: [] });
    return moves;
  }

  if (phase === PHASE.BAIT) {
    // Per official rules: "Spell cards cannot be used during the Bait phase."
    // Bait is auto-advancing — no player actions. Return empty so the phase
    // completes immediately via phaseComplete (all players have hasActed=false
    // but BAIT auto-advances via the BEGINNING/END auto-advance loop).
    return moves;
  }

  if (phase === PHASE.ADVENTURE) {
    pushSpellMoves(G, p, pid, PHASE.ADVENTURE, moves);
    if (G.adventure && Number(G.adventure.playerId) === Number(pid)) {
      moves.push({ type: 'resolveNextHero', args: [] });
    } else if (!G.adventure && p.entrance.length > 0) {
      moves.push({ type: 'resolveNextHero', args: [] });
    }
    pushActivateMoves(G, p, moves);
    moves.push({ type: 'pass', args: [] });
    return moves;
  }

  return [];
}

export const GAME_META = { name: GAME_NAME, minPlayers: MIN_PLAYERS, maxPlayers: MAX_PLAYERS };