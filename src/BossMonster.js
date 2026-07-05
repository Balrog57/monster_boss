import { INVALID_MOVE } from 'boardgame.io/core';
import {
  BOSSES,
  ROOMS,
  SPELLS,
  HEROES,
  TREASURE_NAMES,
  ROOM_TYPE,
  SPELL_CATEGORY,
  PHASE,
  getExpandedDeck,
  shuffle,
  drawCards
} from './cardData.js';
import {
  castSpell,
  emptyEffects,
  roomDamageBonusFor,
  heroHealthBonusFor,
  isRoomDeactivated,
  isBuildBlocked,
  extraBuildsFor,
  isNoEntry,
} from './spellEffects.js';
import {
  roomDamageWithModifiers,
  dungeonTreasures,
  onBuildRoom,
  onHeroDiedInRoom,
  processLevelUp,
} from './roomAbilities.js';

// Does a spell's category allow it in the given phase?
// Combined categories (BUILD_BAIT=4, ADVENTURE_BUILD=5) are accepted in either
// of their constituent phases; ANY=0 is accepted everywhere.
function spellAllowedInPhase(category, phase) {
  if (category === SPELL_CATEGORY.ANY) return true;
  if (category === SPELL_CATEGORY.BUILD_BAIT) return phase === PHASE.BUILD || phase === PHASE.BAIT;
  if (category === SPELL_CATEGORY.ADVENTURE_BUILD) return phase === PHASE.ADVENTURE || phase === PHASE.BUILD;
  if (category === SPELL_CATEGORY.BUILD) return phase === PHASE.BUILD;
  if (category === SPELL_CATEGORY.BAIT) return phase === PHASE.BAIT;
  if (category === SPELL_CATEGORY.ADVENTURE) return phase === PHASE.ADVENTURE;
  return false;
}

// ============================================================
// AI HELPERS
// ============================================================
function aiChooseBoss(availableBosses) {
  // Prefer higher XP bosses
  return [...availableBosses].sort((a, b) => b.xp - a.xp)[0];
}

function aiBuildRoom(G, ctx, playerID) {
  const player = G.players[playerID];
  if (!player || player.hand.length === 0) return null;

  // Find buildable rooms in hand
  const buildable = player.hand
    .map((card, idx) => ({ card, idx }))
    .filter(({ card }) => {
      if (!card.isRoom) return false;
      if (card.advanced) {
        // Advanced room - needs matching treasure type in dungeon
        if (player.dungeon.length === 0) return false;
        const lastRoom = player.dungeon[player.dungeon.length - 1];
        const lastTreasures = lastRoom.treasures || [];
        const cardTreasures = card.treasures || [];
        return cardTreasures.some(t => lastTreasures.includes(t));
      }
      return true; // Basic room can always be built
    });

  if (buildable.length === 0) return null;

  // Prefer advanced rooms, then highest damage
  buildable.sort((a, b) => {
    const aAdv = a.card.advanced ? 1 : 0;
    const bAdv = b.card.advanced ? 1 : 0;
    if (bAdv !== aAdv) return bAdv - aAdv;
    return (b.card.damage || 0) - (a.card.damage || 0);
  });

  return buildable[0].idx;
}

function aiPlaySpell(G, ctx, playerID) {
  const player = G.players[playerID];
  if (!player) return null;

  const spells = player.hand
    .map((card, idx) => ({ card, idx }))
    .filter(({ card }) => card.isSpell);

  if (spells.length === 0) return null;

  // Check spell category matches phase
  const currentPhase = G.phase;
  const playableSpells = spells.filter(({ card }) => {
    const cat = card.category;
    if (currentPhase === PHASE.BUILD) return cat === SPELL_CATEGORY.BUILD || cat === SPELL_CATEGORY.ANY;
    if (currentPhase === PHASE.BAIT) return cat === SPELL_CATEGORY.BAIT || cat === SPELL_CATEGORY.ANY;
    if (currentPhase === PHASE.ADVENTURE) return cat === SPELL_CATEGORY.ADVENTURE || cat === SPELL_CATEGORY.ANY;
    return false;
  });

  if (playableSpells.length === 0) return null;
  return playableSpells[0].idx;
}

// ============================================================
// ADVENTURE PROCESSING
// ============================================================
function processAdventures(G, ctx) {
  const processNext = () => {
    if (G.adventureIndex >= G.adventureOrder.length) {
      checkWinConditions(G, ctx);
      return;
    }

    const playerID = G.adventureOrder[G.adventureIndex];
    const player = G.players[playerID];

    if (player.eliminated || G.town.length === 0) {
      G.adventureIndex++;
      processNext();
      return;
    }

    // Hero chooses dungeon based on treasure types
    const hero = G.town[0];
    const heroClass = hero.class;

    // Find target player (best matching treasure types)
    let targetPlayer = null;
    let maxMatch = 0;

    for (const [pid, p] of Object.entries(G.players)) {
      if (p.eliminated) continue;
      // Use dungeonTreasures so Dragon Hatchery's all-4-types lure applies.
      const treasures = dungeonTreasures(G, parseInt(pid));
      const matchCount = treasures.filter(t => t === heroClass).length;
      if (matchCount > maxMatch) {
        maxMatch = matchCount;
        targetPlayer = parseInt(pid);
      }
    }

    // If no match, hero goes to player with most wounds
    if (targetPlayer === null) {
      targetPlayer = G.adventureOrder.reduce((a, b) => {
        const woundsA = G.players[a].wounds.reduce((sum, w) => sum + (w.wounds || 1), 0);
        const woundsB = G.players[b].wounds.reduce((sum, w) => sum + (w.wounds || 1), 0);
        return woundsB > woundsA ? b : a;
      });
    }

    // Trepidation: a no-entry dungeon refuses the hero, who waits in town.
    if (isNoEntry(G, targetPlayer)) {
      G.logs.push(`${hero.name} waits at the entrance of player ${targetPlayer}'s dungeon (Trepidation).`);
      G.adventureIndex++;
      processNext();
      return;
    }

    const target = G.players[targetPlayer];
    G.logs.push(`${hero.name} enters ${targetPlayer === 0 ? 'your' : `AI ${targetPlayer}`}'s dungeon`);

    // Process through dungeon rooms
    let heroHP = hero.currentHP || hero.hp;
    let heroDefeated = false;
    const heroRef = hero.id + '-' + G.adventureIndex; // stable ref for effect targeting
    // Assassin: hero HP bonus from active effects.
    heroHP += heroHealthBonusFor(G, heroRef);
    let deathRoom = null; // room that dealt the killing blow (for hero-death abilities)

    for (let i = 0; i < target.dungeon.length && heroHP > 0; i++) {
      // Freeze: deactivated rooms deal no damage and grant no abilities this turn.
      if (isRoomDeactivated(G, targetPlayer, i)) {
        G.logs.push(`${target.dungeon[i].name} is deactivated (Freeze) — no effect.`);
        continue;
      }
      const room = target.dungeon[i];
      let roomDamage = room.damage || 0;
      // Passive room modifiers (Goblin Armory, Dizzygas Hallway, Monster's Ballroom).
      roomDamage = roomDamageWithModifiers(G, targetPlayer, i, roomDamage);
      // Annihilator / Giant Size: +damage bonus from active spell effects.
      roomDamage += roomDamageBonusFor(G, targetPlayer, i);

      heroHP -= roomDamage;
      G.logs.push(`${room.name} deals ${roomDamage} damage to ${hero.name} (HP: ${heroHP})`);
      if (heroHP <= 0) deathRoom = room;
    }

    if (heroHP <= 0) {
      // Hero defeated - player gets souls
      const souls = hero.souls || 1;
      for (let i = 0; i < souls; i++) {
        target.souls.push({ souls: 1 });
      }
      G.logs.push(`${hero.name} defeated! ${targetPlayer === 0 ? 'You' : `AI ${targetPlayer}`} gain ${souls} soul(s).`);
      heroDefeated = true;
      // "When a hero dies in this room" abilities (Open Grave, Golem Factory,
      // Brainsucker Hive, Vampire Bordello, Succubus Spa).
      if (deathRoom) onHeroDiedInRoom(G, ctx, targetPlayer, deathRoom, hero);
    } else {
      // Hero survives - player takes wounds
      const wounds = hero.wounds || 1;
      for (let i = 0; i < wounds; i++) {
        target.wounds.push({ wounds: 1 });
      }
      G.logs.push(`${hero.name} survives! ${targetPlayer === 0 ? 'You' : `AI ${targetPlayer}`} take ${wounds} wound(s).`);
    }

    // Remove hero from town
    G.town.shift();
    G.decks.heroDiscard.push(hero);

    // Check if target player eliminated (5 wounds)
    const totalWounds = target.wounds.reduce((sum, w) => sum + (w.wounds || 1), 0);
    if (totalWounds >= 5) {
      target.eliminated = true;
      G.logs.push(`${targetPlayer === 0 ? 'You' : `AI ${targetPlayer}`} have been eliminated!`);
    }

    G.adventureIndex++;
    processNext();
  };

  processNext();
}

function checkWinConditions(G, ctx) {
  const alivePlayers = Object.entries(G.players)
    .filter(([_, p]) => !p.eliminated)
    .map(([pid, _]) => parseInt(pid));

  if (alivePlayers.length <= 1) {
    if (alivePlayers.length === 1) {
      G.gameOver = true;
      G.winner = alivePlayers[0];
      G.logs.push(`Game Over! ${G.winner === 0 ? 'You win!' : `AI ${G.winner} wins!`}`);
    } else {
      // All eliminated - most souls wins
      let maxSouls = -1;
      let winner = 0;
      for (const [pid, p] of Object.entries(G.players)) {
        const souls = p.souls.reduce((sum, s) => sum + (s.souls || 1), 0);
        if (souls > maxSouls) {
          maxSouls = souls;
          winner = parseInt(pid);
        }
      }
      G.gameOver = true;
      G.winner = winner;
      G.logs.push(`Game Over! ${G.winner === 0 ? 'You win!' : `AI ${G.winner} wins!`} with ${maxSouls} souls.`);
    }
  }
}

// ============================================================
// MAIN GAME DEFINITION
// ============================================================
export const BossMonster = {
  name: 'boss-monster',

  setup: ({ ctx }, setupData = {}) => {
    const numPlayers = (setupData && setupData.numPlayers) || ctx.numPlayers || 2;

    // Build decks with quantities
    let roomDeck = getExpandedDeck(ROOMS).map(r => ({ ...r, isRoom: true }));
    let spellDeck = getExpandedDeck(SPELLS).map(s => ({ ...s, isSpell: true }));
    let heroDeck = getExpandedDeck(HEROES).map(h => ({ ...h, epic: false, currentHP: h.hp, wounds: 1, souls: 1 }));
    let epicHeroDeck = getExpandedDeck(HEROES.filter(h => h.epic)).map(h => ({ ...h, epic: true, currentHP: h.hp, wounds: 2, souls: 2 }));

    // Shuffle all decks
    roomDeck = shuffle(roomDeck);
    spellDeck = shuffle(spellDeck);
    heroDeck = shuffle(heroDeck);
    epicHeroDeck = shuffle(epicHeroDeck);

    // Separate ordinary and epic heroes
    const ordinaryHeroes = heroDeck;
    const epicHeroes = epicHeroDeck;

    // Initialize players
    const players = {};
    for (let i = 0; i < numPlayers; i++) {
      players[i] = {
        boss: null,
        dungeon: [],
        hand: [],
        souls: [],
        wounds: [],
        deactivated: [],
        entrance: [],
        eliminated: false,
        leveledUp: false,
        isAI: i > 0,
        passed: false
      };
    }

    // Boss picks: numPlayers + 2 bosses available
    const bossPicks = shuffle(BOSSES).slice(0, Math.min(numPlayers + 2, BOSSES.length));

    return {
      players,
      bossPicks,
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
      round: 0,
      buildOrder: [],
      buildIndex: 0,
      adventureOrder: [],
      adventureIndex: 0,
      logs: ["Welcome to Boss Monster!"],
      gameOver: false,
      winner: null,
      selectedCard: null,
      effects: emptyEffects()
    };
  },

  phases: {
    // ==================== BOSS SELECTION ====================
    [PHASE.BOSS]: {
      start: true,
      moves: {
        pickBoss: ({ G, ctx, playerID }, bossId) => {
          const pid = playerID != null ? playerID : ctx.playerID;
          const boss = G.bossPicks.find(b => b.id === bossId);
          if (!boss) return INVALID_MOVE;

          G.players[pid].boss = { ...boss };
          G.logs.push(`${pid === 0 ? 'You' : `AI ${pid}`} chose ${boss.name}`);
        }
      },
      next: PHASE.SETUP,
      // BOSS phase ends once the human (player 0) has picked; AI bosses are
      // auto-assigned in onEnd.
      endIf: ({ G }) => G.players && G.players[0] && G.players[0].boss !== null,
      onEnd: ({ G, ctx }) => {
        // AI players pick bosses
        for (let i = 1; i < ctx.numPlayers; i++) {
          if (!G.players[i].boss) {
            const available = G.bossPicks.filter(b =>
              !Object.values(G.players).some(p => p.boss?.id === b.id)
            );
            if (available.length > 0) {
              const chosen = aiChooseBoss(available);
              G.players[i].boss = { ...chosen };
              G.logs.push(`AI ${i} chose ${chosen.name}`);
            }
          }
        }

        // Deal initial hands: 5 rooms + 2 spells each
        for (let i = 0; i < ctx.numPlayers; i++) {
          const player = G.players[i];
          for (let j = 0; j < 5; j++) {
            const card = G.decks.rooms.pop();
            if (card) player.hand.push(card);
          }
          for (let j = 0; j < 2; j++) {
            const card = G.decks.spells.pop();
            if (card) player.hand.push(card);
          }
        }
      }
    },

    // ==================== INITIAL BUILD (SETUP) ====================
    [PHASE.SETUP]: {
      moves: {
        buildInitialRoom: ({ G, ctx, playerID }, handIndex) => {
          const pid = playerID != null ? playerID : ctx.playerID;
          const player = G.players[pid];
          if (!player || handIndex < 0 || handIndex >= player.hand.length) return INVALID_MOVE;

          const card = player.hand[handIndex];
          if (!card.isRoom) return INVALID_MOVE;
          if (card.advanced) return INVALID_MOVE; // Can't build advanced initially

          player.dungeon.push(card);
          player.hand.splice(handIndex, 1);
          G.logs.push(`${pid == 0 ? 'You' : `AI ${pid}`} built ${card.name} face down`);
        }
      },
      next: PHASE.BUILD,
      endIf: ({ G }) => G.players && Object.values(G.players).every(p => p.dungeon.length >= 2),
      onBegin: ({ G, ctx }) => {
        G.phase = PHASE.SETUP;
        G.logs.push("Build Phase: Each player builds 2 rooms face down");
        // AI builds initial rooms
        for (let i = 1; i < ctx.numPlayers; i++) {
          const player = G.players[i];
          const basicRooms = player.hand
            .map((c, idx) => ({ card: c, idx }))
            .filter(({ card }) => card.isRoom && !card.advanced);
          for (let j = 0; j < 2 && basicRooms.length > 0; j++) {
            const { card, idx } = basicRooms.pop();
            player.dungeon.push(card);
            player.hand.splice(idx, 1);
            G.logs.push(`AI ${i} built ${card.name} face down`);
          }
        }
      }
    },

    // ==================== BUILD PHASE ====================
    [PHASE.BUILD]: {
      moves: {
        selectCard: ({ G, ctx }, handIndex) => {
          G.selectedCard = handIndex;
        },

        buildRoom: ({ G, ctx, playerID }, handIndex) => {
          const pid = playerID != null ? playerID : ctx.playerID;
          const player = G.players[pid];
          if (!player || handIndex < 0 || handIndex >= player.hand.length) return INVALID_MOVE;

          const card = player.hand[handIndex];
          if (!card.isRoom) return INVALID_MOVE;

          // Kobold Strike: no rooms can be built this turn.
          if (isBuildBlocked(G)) {
            G.logs.push("No rooms can be built this turn (Kobold Strike).");
            return INVALID_MOVE;
          }

          // Per turn: normally 1 build. Motivation grants extras.
          const buildsThisTurn = player.buildsThisTurn || 0;
          const allowed = 1 + extraBuildsFor(G, pid);
          if (buildsThisTurn >= allowed) {
            G.logs.push("Already built the maximum rooms this turn.");
            return INVALID_MOVE;
          }

          // Check if advanced room
          if (card.advanced) {
            if (player.dungeon.length === 0) return INVALID_MOVE;
            const lastRoom = player.dungeon[player.dungeon.length - 1];
            const lastTreasures = lastRoom.treasures || [];
            const cardTreasures = card.treasures || [];
            if (!cardTreasures.some(t => lastTreasures.includes(t))) {
              G.logs.push("Must share treasure type with room being replaced!");
              return INVALID_MOVE;
            }
            // Replace the last room
            G.decks.roomDiscard.push(lastRoom);
            player.dungeon[player.dungeon.length - 1] = card;
          } else {
            // Build new room at end of dungeon
            if (player.dungeon.length >= 5) return INVALID_MOVE;
            player.dungeon.push(card);
          }
          player.buildsThisTurn = buildsThisTurn + 1;

          player.hand.splice(handIndex, 1);
          G.selectedCard = null;
          G.logs.push(`${pid == 0 ? 'You' : `AI ${pid}`} built ${card.name}`);

          // "When you build this room" abilities (Dark Laboratory, Specter's
          // Sanctum, Mimic Vault, etc.) and Beast Menagerie's cross-trigger.
          onBuildRoom(G, ctx, pid, card);

          // Level Up at 5 rooms: trigger the Boss's unique ability.
          if (player.dungeon.length >= 5 && !player.leveledUp) {
            player.leveledUp = true;
            const spell = G.decks.spells.pop();
            if (spell) player.hand.push(spell);
            G.logs.push(`${pid == 0 ? 'You' : `AI ${pid}`} LEVELED UP!`);
            processLevelUp(G, ctx, pid);
          }
        },

        playSpell: ({ G, ctx, playerID }, handIndex) => {
          const pid = playerID != null ? playerID : ctx.playerID;
          const player = G.players[pid];
          if (!player || handIndex < 0 || handIndex >= player.hand.length) return INVALID_MOVE;

          const card = player.hand[handIndex];
          if (!card.isSpell) return INVALID_MOVE;

          // Check spell category matches phase (incl. combined categories)
          if (!spellAllowedInPhase(card.category, PHASE.BUILD)) {
            G.logs.push("This spell cannot be played during Build phase!");
            return INVALID_MOVE;
          }

          player.hand.splice(handIndex, 1);
          G.decks.spellDiscard.push(card);
          G.selectedCard = null;
          G.logs.push(`${pid == 0 ? 'You' : `AI ${pid}`} cast ${card.name}`);
          castSpell(G, ctx, pid, card);
        },

        pass: ({ G, ctx, playerID }) => {
          const pid = playerID != null ? playerID : ctx.playerID;
          G.players[pid].passed = true;
          G.logs.push(`${pid == 0 ? 'You' : `AI ${pid}`} passed`);
        }
      },
      next: PHASE.BAIT,
      // Build ends when the human (player 0) passes; AI is auto-resolved.
      endIf: ({ G }) => G.players && G.players[0] && G.players[0].passed,
      onBegin: ({ G, ctx }) => {
        G.turn++;
        G.logs.push(`--- Turn ${G.turn} - Build Phase ---`);
        G.phase = PHASE.BUILD;
        // Clear all "until end of turn" effects from the previous turn.
        G.effects = emptyEffects();
        // Reset per-turn build counters.
        Object.values(G.players).forEach(p => { p.buildsThisTurn = 0; });

        // Draw cards: 1 room + 1 spell each
        for (let i = 0; i < ctx.numPlayers; i++) {
          const player = G.players[i];
          const room = G.decks.rooms.pop();
          if (room) player.hand.push(room);
          const spell = G.decks.spells.pop();
          if (spell) player.hand.push(spell);
        }

        // Reset passed flags
        Object.values(G.players).forEach(p => p.passed = false);
      },
      onEnd: ({ G, ctx }) => {
        // Reveal dungeons (face up)
        Object.values(G.players).forEach(p => p.revealed = true);
        // Reset passed flags so the next phase's endIf doesn't fire instantly.
        Object.values(G.players).forEach(p => p.passed = false);
      }
    },

    // ==================== BAIT PHASE ====================
    [PHASE.BAIT]: {
      moves: {
        selectCard: ({ G, ctx }, handIndex) => {
          G.selectedCard = handIndex;
        },

        playSpell: ({ G, ctx, playerID }, handIndex) => {
          const pid = playerID != null ? playerID : ctx.playerID;
          const player = G.players[pid];
          if (!player || handIndex < 0 || handIndex >= player.hand.length) return INVALID_MOVE;

          const card = player.hand[handIndex];
          if (!card.isSpell) return INVALID_MOVE;

          if (!spellAllowedInPhase(card.category, PHASE.BAIT)) {
            G.logs.push("This spell cannot be played during Bait phase!");
            return INVALID_MOVE;
          }

          player.hand.splice(handIndex, 1);
          G.decks.spellDiscard.push(card);
          G.selectedCard = null;
          G.logs.push(`${pid == 0 ? 'You' : `AI ${pid}`} cast ${card.name}`);
          castSpell(G, ctx, pid, card);
        },

        pass: ({ G, ctx, playerID }) => {
          const pid = playerID != null ? playerID : ctx.playerID;
          G.players[pid].passed = true;
          G.logs.push(`${pid == 0 ? 'You' : `AI ${pid}`} done baiting`);
        }
      },
      next: PHASE.ADVENTURE,
      // Bait ends when the human (player 0) passes; AI is auto-resolved.
      endIf: ({ G }) => G.players && G.players[0] && G.players[0].passed,
      onBegin: ({ G, ctx }) => {
        G.logs.push(`--- Turn ${G.turn} - Bait Phase ---`);
        G.phase = PHASE.BAIT;

        // Fill town with heroes
        while (G.town.length < 5 && (G.decks.heroes.length > 0 || G.decks.epics.length > 0)) {
          if (G.decks.heroes.length > 0 && Math.random() < 0.7) {
            G.town.push(G.decks.heroes.pop());
          } else if (G.decks.epics.length > 0) {
            G.town.push(G.decks.epics.pop());
          } else {
            G.town.push(G.decks.heroes.pop());
          }
        }

        Object.values(G.players).forEach(p => p.passed = false);
      },
      onEnd: ({ G, ctx }) => {
        // Reset passed flags for the adventure phase resolution.
        Object.values(G.players).forEach(p => p.passed = false);
      }
    },

    // ==================== ADVENTURE PHASE ====================
    [PHASE.ADVENTURE]: {
      moves: {
        selectCard: ({ G, ctx }, handIndex) => {
          G.selectedCard = handIndex;
        },

        playSpell: ({ G, ctx, playerID }, handIndex) => {
          const pid = playerID != null ? playerID : ctx.playerID;
          const player = G.players[pid];
          if (!player || handIndex < 0 || handIndex >= player.hand.length) return INVALID_MOVE;

          const card = player.hand[handIndex];
          if (!card.isSpell) return INVALID_MOVE;

          if (!spellAllowedInPhase(card.category, PHASE.ADVENTURE)) {
            G.logs.push("This spell cannot be played during Adventure phase!");
            return INVALID_MOVE;
          }

          player.hand.splice(handIndex, 1);
          G.decks.spellDiscard.push(card);
          G.selectedCard = null;
          G.logs.push(`${pid == 0 ? 'You' : `AI ${pid}`} cast ${card.name}`);
          castSpell(G, ctx, pid, card);
        },

        pass: ({ G, ctx, playerID }) => {
          const pid = playerID != null ? playerID : ctx.playerID;
          G.players[pid].passed = true;
          G.logs.push(`${pid == 0 ? 'You' : `AI ${pid}`} passed`);
        }
      },
      next: PHASE.BUILD,
      // Adventure auto-resolves in onBegin, so end immediately after.
      endIf: () => true,
      onBegin: ({ G, ctx }) => {
        G.logs.push(`--- Turn ${G.turn} - Adventure Phase ---`);
        G.phase = PHASE.ADVENTURE;

        // Determine adventure order (most wounds first, tie = most souls)
        G.adventureOrder = Object.keys(G.players)
          .map(i => parseInt(i))
          .sort((a, b) => {
            const woundsA = G.players[a].wounds.reduce((sum, w) => sum + (w.wounds || 1), 0);
            const woundsB = G.players[b].wounds.reduce((sum, w) => sum + (w.wounds || 1), 0);
            if (woundsB !== woundsA) return woundsB - woundsA;
            const soulsA = G.players[a].souls.reduce((sum, s) => sum + (s.souls || 1), 0);
            const soulsB = G.players[b].souls.reduce((sum, s) => sum + (s.souls || 1), 0);
            return soulsB - soulsA;
          });

        G.adventureIndex = 0;

        // Process all adventures
        processAdventures(G, ctx);

        Object.values(G.players).forEach(p => p.passed = false);

        // Check win conditions
        checkWinConditions(G, ctx);
      }
    }
  },

  turn: {
    // Keep all players active in every phase so the human (and AI) can dispatch
    // moves. Phase progression is driven by `endIf` + per-player `passed` flags.
    activePlayers: { all: 'main' },
    order: {
      first: ({ G, ctx }) => (G.adventureOrder && G.adventureOrder[0] !== undefined ? G.adventureOrder[0] : 0),
      next: ({ G, ctx }) => {
        if (!G.adventureOrder || G.adventureOrder.length === 0) return 0;
        const idx = G.adventureOrder.indexOf(ctx.currentPlayer);
        if (idx >= 0 && idx < G.adventureOrder.length - 1) {
          return G.adventureOrder[idx + 1];
        }
        return G.adventureOrder[0];
      }
    }
  },

  ai: {
    enumerate: ({ G, ctx }, playerID) => {
      const pid = playerID != null ? playerID : ctx.playerID;
      const player = G.players[pid];
      if (!player || !player.isAI) return [];

      const moves = [];
      // Prefer ctx.phase (the authoritative boardgame.io phase); fall back to
      // the custom G.phase mirror for safety.
      const currentPhase = ctx.phase || G.phase;

      if (currentPhase === PHASE.BOSS) {
        const available = G.bossPicks.filter(b =>
          !Object.values(G.players).some(p => p.boss?.id === b.id)
        );
        available.forEach(b => moves.push({ move: 'pickBoss', args: [b.id] }));
      } else if (currentPhase === PHASE.SETUP) {
        const basicRooms = player.hand
          .map((c, idx) => ({ card: c, idx }))
          .filter(({ card }) => card.isRoom && !card.advanced);
        basicRooms.forEach(({ idx }) => moves.push({ move: 'buildInitialRoom', args: [idx] }));
      } else if (currentPhase === PHASE.BUILD) {
        const buildIdx = aiBuildRoom(G, ctx, pid);
        if (buildIdx !== null) moves.push({ move: 'buildRoom', args: [buildIdx] });
        const spellIdx = aiPlaySpell(G, ctx, pid);
        if (spellIdx !== null) moves.push({ move: 'playSpell', args: [spellIdx] });
        moves.push({ move: 'pass', args: [] });
      } else if (currentPhase === PHASE.BAIT) {
        const spellIdx = aiPlaySpell(G, ctx, pid);
        if (spellIdx !== null) moves.push({ move: 'playSpell', args: [spellIdx] });
        moves.push({ move: 'pass', args: [] });
      } else if (currentPhase === PHASE.ADVENTURE) {
        const spellIdx = aiPlaySpell(G, ctx, pid);
        if (spellIdx !== null) moves.push({ move: 'playSpell', args: [spellIdx] });
        moves.push({ move: 'pass', args: [] });
      }

      return moves;
    }
  },

  endIf: ({ G, ctx }) => {
    if (G.gameOver) return { winner: G.winner };
    return false;
  },

  playerView: ({ G, ctx, playerID }) => {
    // Hide other players' hands. playerID may arrive as string or number.
    const me = String(playerID);
    const filtered = { ...G };
    if (filtered.players) {
      filtered.players = { ...filtered.players };
      Object.keys(filtered.players).forEach(pid => {
        if (pid !== me) {
          const p = filtered.players[pid];
          const hand = (p && Array.isArray(p.hand)) ? p.hand : [];
          filtered.players[pid] = {
            ...p,
            hand: hand.map(() => ({ hidden: true }))
          };
        }
      });
    }
    return filtered;
  }
};

export default BossMonster;