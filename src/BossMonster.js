// BossMonster.js - boardgame.io game definition with rule-correct base engine.
//
// Uses standard boardgame.io turn ordering: `turn.order` drives ctx.currentPlayer
// in descending XP order. `activePlayers: { currentPlayer: 'main' }` makes only
// the current player active. The phase endIf checks that all non-eliminated
// players have `passed === true`.

import { INVALID_MOVE } from 'boardgame.io/core';
import {
  BOSSES, ROOMS, SPELLS, HEROES, PHASE, SPELL_CATEGORY,
  getExpandedDeck, shuffle, drawCards, playerOrderByXP, totalSouls, totalWounds
} from './cardData.js';
import { castSpell, emptyEffects, isBuildBlocked, extraBuildsFor, isRoomDeactivated, isNoEntry } from './spellEffects.js';
import { onBuildRoom, onHeroDiedInRoom, processLevelUp } from './roomAbilities.js';
import {
  activeRoom, allActiveRooms, countVisibleRooms, dungeonTreasures,
  resolveBait, buildRoom, heroHealthWithModifiers,
  roomDamageWithModifiers, checkEndGame
} from './engine.js';
import { aiEnumerate, aiChooseBoss as aiPickBoss } from './ai.js';

const HERO_COUNTS = {
  2: { ordinary: 13, epic: 8 },
  3: { ordinary: 17, epic: 12 },
  4: { ordinary: 25, epic: 16 }
};

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

export const BossMonster = {
  name: 'boss-monster',

  minPlayers: 2,
  maxPlayers: 4,

  setup: ({ ctx }, setupData = {}) => {
    const numPlayers = (setupData?.numPlayers) || ctx.numPlayers || 2;

    const roomDeck = shuffle(getExpandedDeck(ROOMS).map(r => ({ ...r, isRoom: true })));
    const spellDeck = shuffle(getExpandedDeck(SPELLS).map(s => ({ ...s, isSpell: true })));
    const ordinaryHeroes = shuffle(getExpandedDeck(filterHeroesByPlayerCount(HEROES.filter(h => !h.epic), numPlayers)).map(h => ({ ...h, epic: false, wounds: 1, souls: 1 })));
    const epicHeroes = shuffle(getExpandedDeck(filterHeroesByPlayerCount(HEROES.filter(h => h.epic), numPlayers)).map(h => ({ ...h, epic: true, wounds: 2, souls: 2 })));

    const players = {};
    for (let i = 0; i < numPlayers; i++) {
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

    return {
      players,
      bossPicks: dealBossCards(numPlayers),
      numPlayers,
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
  },

  phases: {
    [PHASE.BOSS]: {
      start: true,
      moves: {
        pickBoss: ({ G, ctx, playerID }, bossId) => {
          const pid = playerID != null ? playerID : ctx.playerID;
          const p = G.players[pid];
          if (!p || p.boss) return INVALID_MOVE;
          const boss = G.bossPicks.find(b => b.id === bossId);
          if (!boss) return INVALID_MOVE;
          if (Object.values(G.players).some(pl => pl.boss?.id === bossId && pl !== p)) return INVALID_MOVE;
          p.boss = { ...boss };
          G.logs.push(`${pid === 0 ? 'You' : `Player ${pid}`} chose ${boss.name}`);
        }
      },
      next: PHASE.SETUP,
      endIf: ({ G }) => G.players && Object.values(G.players)
        .filter(p => !p.isAI)
        .every(p => p.boss !== null),
      onEnd: ({ G, ctx }) => {
        for (let i = 0; i < ctx.numPlayers; i++) {
          if (!G.players[i].boss) {
            const available = G.bossPicks.filter(b =>
              !Object.values(G.players).some(pl => pl.boss?.id === b.id)
            );
            if (available.length > 0) {
              const chosen = aiPickBoss(available);
              G.players[i].boss = { ...chosen };
              G.logs.push(`Player ${i} chose ${chosen.name}`);
            }
          }
        }
        for (let i = 0; i < ctx.numPlayers; i++) {
          const p = G.players[i];
          drawCards(G.decks.rooms, 5).forEach(c => p.hand.push(c));
          drawCards(G.decks.spells, 2).forEach(c => p.hand.push(c));
        }
        drawCards(G.decks.rooms, 4).forEach(c => G.decks.roomDiscard.push(c));
        drawCards(G.decks.spells, 2).forEach(c => G.decks.spellDiscard.push(c));
        G.xpOrder = playerOrderByXP(G.players);
        G.logs.push('Setup: hands dealt, discard seeded.');
      }
    },

    [PHASE.SETUP]: {
      moves: {
        buildInitialRoom: ({ G, ctx, playerID }, handIndex) => {
          const pid = playerID != null ? playerID : ctx.playerID;
          if (String(pid) !== String(G.activePlayer)) return INVALID_MOVE;
          const p = G.players[pid];
          const card = p.hand[handIndex];
          if (!card || !card.isRoom || card.advanced) return INVALID_MOVE;
          if (p.dungeon.length >= 1) return INVALID_MOVE;
          buildRoom(G, pid, handIndex, null);
          G.logs.push(`${pid === 0 ? 'You' : `Player ${pid}`} built ${card.name} face down`);
          p.passed = true;
        }
      },
      next: PHASE.BEGINNING,
      endIf: ({ G }) => G.players && Object.values(G.players).every(p => p.eliminated || p.passed),
      onBegin: ({ G, ctx }) => {
        G.phase = PHASE.SETUP;
        G.xpOrder = playerOrderByXP(G.players);
        G.activePlayer = G.xpOrder[0] ?? 0;
        G.logs.push('Setup: each player builds one room face-down in XP order.');
        for (const p of Object.values(G.players)) p.passed = false;
      },
      onEnd: ({ G, ctx }) => {
        for (const pid of playerOrderByXP(G.players)) {
          const room = activeRoom(G.players[pid].dungeon[0]);
          if (room) {
            G.logs.push(`Revealed ${room.name} for Player ${pid}`);
            onBuildRoom(G, ctx, pid, room);
          }
        }
        G.effects = emptyEffects();
      }
    },

    [PHASE.BEGINNING]: {
      moves: { pass: ({ G, ctx, playerID }) => { G.players[playerID != null ? playerID : ctx.playerID].passed = true; } },
      next: PHASE.BUILD,
      endIf: ({ G }) => true,
      onBegin: ({ G, ctx }) => {
        G.turn += 1;
        G.phase = PHASE.BEGINNING;
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
    },

    [PHASE.BUILD]: {
      moves: {
        buildRoom: ({ G, ctx, playerID }, handIndex, targetIndex = null) => {
          const pid = playerID != null ? playerID : ctx.playerID;
          if (String(pid) !== String(G.activePlayer)) return INVALID_MOVE;
          const p = G.players[pid];
          const card = p.hand[handIndex];
          if (!card || !card.isRoom) return INVALID_MOVE;
          if (isBuildBlocked(G)) return INVALID_MOVE;
          const allowed = 1 + extraBuildsFor(G, pid);
          if (p.buildsThisTurn >= allowed) return INVALID_MOVE;

          if (!buildRoom(G, pid, handIndex, targetIndex)) return INVALID_MOVE;
          G.logs.push(`${pid === 0 ? 'You' : `Player ${pid}`} built ${card.name}`);
          onBuildRoom(G, ctx, pid, activeRoom(p.dungeon[p.dungeon.length - 1]) || card);
          p.passed = true;
        },
        playSpell: ({ G, ctx, playerID }, handIndex, target = null) => {
          const pid = playerID != null ? playerID : ctx.playerID;
          if (String(pid) !== String(G.activePlayer)) return INVALID_MOVE;
          const p = G.players[pid];
          const card = p.hand[handIndex];
          if (!card?.isSpell) return INVALID_MOVE;
          if (!spellAllowedInPhase(card.category, PHASE.BUILD)) return INVALID_MOVE;
          p.hand.splice(handIndex, 1);
          G.decks.spellDiscard.push(card);
          G.logs.push(`${pid === 0 ? 'You' : `Player ${pid}`} cast ${card.name}`);
          castSpell(G, ctx, pid, card, target);
          p.passed = true;
        },
        pass: ({ G, ctx, playerID }) => {
          const pid = playerID != null ? playerID : ctx.playerID;
          if (String(pid) !== String(G.activePlayer)) return INVALID_MOVE;
          G.players[pid].passed = true;
          G.logs.push(`${pid === 0 ? 'You' : `Player ${pid}`} passed`);
        }
      },
      next: PHASE.BAIT,
      endIf: ({ G }) => G.players && Object.values(G.players).every(p => p.eliminated || p.passed),
      onBegin: ({ G, ctx }) => {
        G.phase = PHASE.BUILD;
        G.logs.push(`--- Turn ${G.turn} - Build Phase ---`);
        G.xpOrder = playerOrderByXP(G.players);
        G.activePlayer = G.xpOrder[0] ?? 0;
        for (const p of Object.values(G.players)) p.passed = false;
      },
      onEnd: ({ G, ctx }) => {
        for (const pid of playerOrderByXP(G.players)) {
          const p = G.players[pid];
          for (const stack of p.dungeon) {
            const room = activeRoom(stack);
            if (room) onBuildRoom(G, ctx, pid, room);
          }
          if (countVisibleRooms(p.dungeon) >= 5 && !p.leveledUp) {
            p.leveledUp = true;
            G.logs.push(`${pid === 0 ? 'You' : `Player ${pid}`} LEVELED UP!`);
            processLevelUp(G, ctx, pid);
          }
        }
      }
    },

    [PHASE.BAIT]: {
      moves: {
        playSpell: ({ G, ctx, playerID }, handIndex, target = null) => {
          const pid = playerID != null ? playerID : ctx.playerID;
          if (String(pid) !== String(G.activePlayer)) return INVALID_MOVE;
          const p = G.players[pid];
          const card = p.hand[handIndex];
          if (!card?.isSpell) return INVALID_MOVE;
          if (!spellAllowedInPhase(card.category, PHASE.BAIT)) return INVALID_MOVE;
          p.hand.splice(handIndex, 1);
          G.decks.spellDiscard.push(card);
          G.logs.push(`${pid === 0 ? 'You' : `Player ${pid}`} cast ${card.name}`);
          castSpell(G, ctx, pid, card, target);
          p.passed = true;
        },
        pass: ({ G, ctx, playerID }) => {
          const pid = playerID != null ? playerID : ctx.playerID;
          if (String(pid) !== String(G.activePlayer)) return INVALID_MOVE;
          G.players[pid].passed = true;
        }
      },
      next: PHASE.ADVENTURE,
      endIf: ({ G }) => G.players && Object.values(G.players).every(p => p.eliminated || p.passed),
      onBegin: ({ G, ctx }) => {
        G.phase = PHASE.BAIT;
        G.logs.push(`--- Turn ${G.turn} - Bait Phase ---`);
        G.xpOrder = playerOrderByXP(G.players);
        G.activePlayer = G.xpOrder[0] ?? 0;
        for (const p of Object.values(G.players)) p.passed = false;
      },
      onEnd: ({ G, ctx }) => {
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
    },

    [PHASE.ADVENTURE]: {
      moves: {
        playSpell: ({ G, ctx, playerID }, handIndex, target = null) => {
          const pid = playerID != null ? playerID : ctx.playerID;
          if (String(pid) !== String(G.activePlayer)) return INVALID_MOVE;
          const p = G.players[pid];
          const card = p.hand[handIndex];
          if (!card?.isSpell) return INVALID_MOVE;
          if (!spellAllowedInPhase(card.category, PHASE.ADVENTURE)) return INVALID_MOVE;
          p.hand.splice(handIndex, 1);
          G.decks.spellDiscard.push(card);
          G.logs.push(`${pid === 0 ? 'You' : `Player ${pid}`} cast ${card.name}`);
          castSpell(G, ctx, pid, card, target);
        },
        resolveNextHero: ({ G, ctx, playerID }) => {
          const pid = playerID != null ? playerID : ctx.playerID;
          if (String(pid) !== String(G.activePlayer)) return INVALID_MOVE;
          resolveAdventureForPlayer(G, ctx, pid);
        },
        pass: ({ G, ctx, playerID }) => {
          const pid = playerID != null ? playerID : ctx.playerID;
          if (String(pid) !== String(G.activePlayer)) return INVALID_MOVE;
          G.players[pid].passed = true;
        }
      },
      next: PHASE.END,
      endIf: ({ G }) => G.players && Object.values(G.players).every(p => p.eliminated || p.passed),
      onBegin: ({ G, ctx }) => {
        G.phase = PHASE.ADVENTURE;
        G.logs.push(`--- Turn ${G.turn} - Adventure Phase ---`);
        G.xpOrder = playerOrderByXP(G.players);
        G.activePlayer = G.xpOrder[0] ?? 0;
        for (const p of Object.values(G.players)) p.passed = false;
      },
      onEnd: ({ G, ctx }) => {}
    },

    [PHASE.END]: {
      moves: { pass: ({ G, ctx, playerID }) => { G.players[playerID != null ? playerID : ctx.playerID].passed = true; } },
      next: PHASE.BEGINNING,
      endIf: ({ G }) => true,
      onBegin: ({ G, ctx }) => {
        G.phase = PHASE.END;
        G.logs.push(`--- Turn ${G.turn} - End Phase ---`);
        G.effects = emptyEffects();
        const result = checkEndGame(G);
        if (result.gameOver) {
          G.gameOver = true;
          G.winner = result.winner;
          G.logs.push(`Game Over! Player ${result.winner} wins!`);
        }
      }
    }
  },

  turn: {
    order: {
      first: ({ G }) => (G.xpOrder && G.xpOrder[0] != null) ? G.xpOrder[0] : 0,
      next: ({ G, ctx }) => {
        if (!G || !G.players) return 0;
        const cur = parseInt(ctx.currentPlayer);
        const order = G.xpOrder || [0, 1];
        for (let i = 1; i <= order.length; i++) {
          const candidate = order[(order.indexOf(cur) + i) % order.length];
          if (candidate != null && !G.players[candidate]?.eliminated && !G.players[candidate]?.passed) {
            return candidate;
          }
        }
        return cur;
      }
    },
    activePlayers: { currentPlayer: 'main' }
  },

  ai: {
    enumerate: ({ G, ctx }, playerID) => {
      return aiEnumerate(G, ctx, playerID);
    }
  },

  endIf: ({ G }) => {
    if (G.gameOver) return { winner: G.winner };
    return false;
  },

  playerView: ({ G, playerID }) => {
    const me = String(playerID);
    const filtered = { ...G };
    filtered.players = { ...filtered.players };
    Object.keys(filtered.players).forEach(pid => {
      if (pid !== me) {
        const p = filtered.players[pid];
        filtered.players[pid] = { ...p, hand: p.hand.map(() => ({ hidden: true })) };
      }
    });
    return filtered;
  }
};

export default BossMonster;
