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
    if (currentPhase === PHASE.BUILD) return cat === SPELL_CATEGORY.BUILD || cat === SPELL_CATEGORY.ANY || cat === SPELL_CATEGORY.BUILD_BAIT || cat === SPELL_CATEGORY.ADVENTURE_BUILD;
    if (currentPhase === PHASE.BAIT) return cat === SPELL_CATEGORY.BAIT || cat === SPELL_CATEGORY.ANY || cat === SPELL_CATEGORY.BUILD_BAIT;
    if (currentPhase === PHASE.ADVENTURE) return cat === SPELL_CATEGORY.ADVENTURE || cat === SPELL_CATEGORY.ANY || cat === SPELL_CATEGORY.ADVENTURE_BUILD;
    return false;
  });

  if (playableSpells.length === 0) return null;
  return playableSpells[0].idx;
}

// ============================================================
// AI TURN RESOLUTION (called from phase onBegin hooks)
// ============================================================
// Applies an AI player's build + spell actions directly to G. Used so AI
// opponents actually construct dungeons and cast spells each turn (previously
// the AI only acted via the debug-only enumerate bot, so it never built).

function aiResolveBuild(G, ctx, pid) {
  const player = G.players[pid];
  if (!player || player.eliminated) return;
  const allowed = 1 + extraBuildsFor(G, pid);

  // Build up to `allowed` rooms: prefer high-damage, then advanced rooms that
  // share a treasure type with the last built room.
  for (let n = 0; n < allowed; n++) {
    if (player.dungeon.length >= 5) break;
    if (isBuildBlocked(G)) break;
    const idx = aiBuildRoom(G, ctx, pid);
    if (idx === null) break;
    const card = player.hand[idx];
    if (!card || !card.isRoom) break;

    // Apply the build (mirror of the buildRoom move logic).
    if (card.advanced && player.dungeon.length > 0) {
      const lastRoom = player.dungeon[player.dungeon.length - 1];
      const lastTreasures = lastRoom.treasures || [];
      const cardTreasures = card.treasures || [];
      if (cardTreasures.some(t => lastTreasures.includes(t))) {
        G.decks.roomDiscard.push(lastRoom);
        player.dungeon[player.dungeon.length - 1] = card;
      } else {
        break; // can't place advanced room, stop
      }
    } else {
      player.dungeon.push(card);
    }
    player.hand.splice(idx, 1);
    player.buildsThisTurn = (player.buildsThisTurn || 0) + 1;
    G.logs.push(`AI ${pid} built ${card.name}`);
    onBuildRoom(G, ctx, pid, card);
    // Level up at 5 rooms.
    if (player.dungeon.length >= 5 && !player.leveledUp) {
      player.leveledUp = true;
      const spell = G.decks.spells.pop();
      if (spell) player.hand.push(spell);
      G.logs.push(`AI ${pid} LEVELED UP!`);
      processLevelUp(G, ctx, pid);
    }
  }

  // Cast one build-phase spell if useful (50% chance to avoid over-spamming).
  if (Math.random() < 0.5) {
    const spellIdx = aiPlaySpell(G, ctx, pid);
    if (spellIdx !== null) {
      const card = player.hand[spellIdx];
      if (card && card.isSpell && spellAllowedInPhase(card.category, PHASE.BUILD)) {
        player.hand.splice(spellIdx, 1);
        G.decks.spellDiscard.push(card);
        G.logs.push(`AI ${pid} cast ${card.name}`);
        castSpell(G, ctx, pid, card);
      }
    }
  }
  // AI is done with its build turn.
  player.passed = true;
}

function aiResolveBait(G, ctx, pid) {
  const player = G.players[pid];
  if (!player || player.eliminated) return;
  // Occasionally cast a bait-phase spell (30% chance).
  if (Math.random() < 0.3) {
    const spellIdx = aiPlaySpell(G, ctx, pid);
    if (spellIdx !== null) {
      const card = player.hand[spellIdx];
      if (card && card.isSpell && spellAllowedInPhase(card.category, PHASE.BAIT)) {
        player.hand.splice(spellIdx, 1);
        G.decks.spellDiscard.push(card);
        G.logs.push(`AI ${pid} cast ${card.name}`);
        castSpell(G, ctx, pid, card);
      }
    }
  }
  // AI is done baiting.
  player.passed = true;
}

// ============================================================
// ADVENTURE PROCESSING
// ============================================================
function processAdventures(G, ctx) {
  // Process every hero currently in town, one at a time. Each hero is lured to
  // the dungeon that best matches its class (or, if none match, to the player
  // with the most wounds), then walks that dungeon taking damage. Per the rules
  // the adventure order is by player XP, but since heroes are independent we
  // just drain the town queue.
  const townCount = G.town.length;

  for (let h = 0; h < townCount; h++) {
    if (G.town.length === 0) break;

    // If every player is eliminated, stop.
    const anyAlive = Object.values(G.players).some(p => !p.eliminated);
    if (!anyAlive) break;

    const hero = G.town[0];
    const heroClass = hero.class;

    // Heroes are lured to the dungeon with the most matching treasure icons
    // for their class. Ties: fewest wounds, then fewest souls, then lowest XP.
    // If no dungeon has a matching treasure, the hero goes to the player with
    // the MOST wounds (then most souls).
    let targetPlayer = null;
    let best = null;
    let anyMatch = false;

    for (const [pidStr, p] of Object.entries(G.players)) {
      if (p.eliminated) continue;
      const pid = parseInt(pidStr);
      const treasures = dungeonTreasures(G, pid);
      const matchCount = treasures.filter(t => t === heroClass).length;
      const candidate = {
        pid,
        matchCount,
        wounds: totalWounds(p),
        souls: totalSouls(p),
        xp: p.boss?.xp || 0,
      };
      if (matchCount > 0) anyMatch = true;
      const better = (cur, cand, attr) =>
        attr === 'match' ? cand.matchCount > cur.matchCount
        : attr === 'wounds' ? cand.wounds < cur.wounds
        : attr === 'souls' ? cand.souls < cur.souls
        : cand.xp < cur.xp;
      if (best === null) {
        best = candidate;
      } else if (anyMatch && candidate.matchCount > 0) {
        // Lure comparison: most matches, then fewest wounds/souls, low XP
        if (better(best, candidate, 'match')) best = candidate;
        else if (candidate.matchCount === best.matchCount) {
          if (better(best, candidate, 'wounds')) best = candidate;
          else if (candidate.wounds === best.wounds) {
            if (better(best, candidate, 'souls')) best = candidate;
            else if (candidate.souls === best.souls && better(best, candidate, 'xp')) best = candidate;
          }
        }
      }
    }

    if (anyMatch) {
      targetPlayer = best.pid;
    } else {
      // No luring treasure: hero goes to player with most wounds, then most souls.
      targetPlayer = Object.entries(G.players)
        .filter(([_, p]) => !p.eliminated)
        .map(([pidStr, p]) => ({ pid: parseInt(pidStr), w: totalWounds(p), s: totalSouls(p) }))
        .sort((a, b) => b.w - a.w || b.s - a.s)[0]?.pid;
    }

    // Trepidation: a no-entry dungeon refuses the hero, who waits in town.
    if (isNoEntry(G, targetPlayer)) {
      G.logs.push(`${hero.name} waits at the entrance of player ${targetPlayer}'s dungeon (Trepidation).`);
      // Hero stays in town for next turn: don't shift, move to next hero slot.
      // Requeue: move this hero to the back of town so we don't loop on it.
      G.town.push(G.town.shift());
      continue;
    }

    const target = G.players[targetPlayer];
    G.logs.push(`${hero.name} enters ${targetPlayer === 0 ? 'your' : `AI ${targetPlayer}'s`} dungeon`);

    // Process through dungeon rooms
    let heroHP = hero.currentHP || hero.hp;
    let heroDefeated = false;
    const heroRef = hero.id + '-' + h; // stable ref for effect targeting
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
    if (totalWounds(target) >= 5) {
      target.eliminated = true;
      G.logs.push(`${targetPlayer === 0 ? 'You' : `AI ${targetPlayer}`} have been eliminated!`);
    }
  } // end for each hero in town

  checkWinConditions(G, ctx);
}

function totalSouls(p) {
  return p.souls.reduce((sum, s) => sum + (s.souls || 1), 0);
}
function totalWounds(p) {
  return p.wounds.reduce((sum, w) => sum + (w.wounds || 1), 0);
}

// Win conditions per docs/rules/rules.md (End of Turn Phase, lines 121-124):
//   i.  5+ Wounds -> eliminated (loses regardless of Soul count)
//   ii. 10+ Souls AND <5 Wounds -> wins
//   iii.Tie-break: Souls minus Wounds, then lowest XP
function checkWinConditions(G, ctx) {
  // Mark eliminated (5+ wounds). Done inline during adventure too, but re-check
  // here for safety.
  for (const p of Object.values(G.players)) {
    if (!p.eliminated && totalWounds(p) >= 5) {
      p.eliminated = true;
    }
  }

  // Look for an outright winner: 10+ souls and not eliminated.
  const winners = Object.entries(G.players)
    .filter(([_, p]) => !p.eliminated && totalSouls(p) >= 10)
    .map(([pid]) => parseInt(pid));
  if (winners.length === 1) {
    G.gameOver = true;
    G.winner = winners[0];
    G.logs.push(`Game Over! ${G.winner === 0 ? 'You win' : `AI ${G.winner} wins`} with ${totalSouls(G.players[G.winner])} souls!`);
    return;
  }
  if (winners.length > 1) {
    // Tie-break: souls - wounds, then lowest XP
    winners.sort((a, b) => {
      const sa = totalSouls(G.players[a]) - totalWounds(G.players[a]);
      const sb = totalSouls(G.players[b]) - totalWounds(G.players[b]);
      if (sb !== sa) return sb - sa;
      return (G.players[a].boss?.xp || 0) - (G.players[b].boss?.xp || 0);
    });
    G.gameOver = true;
    G.winner = winners[0];
    G.logs.push(`Game Over! ${G.winner === 0 ? 'You win' : `AI ${G.winner} wins`} on tie-break!`);
    return;
  }

  // No soul winner. If all-but-one are eliminated, the survivor wins.
  const alive = Object.entries(G.players)
    .filter(([_, p]) => !p.eliminated)
    .map(([pid]) => parseInt(pid));
  if (alive.length <= 1) {
    if (alive.length === 1) {
      G.gameOver = true;
      G.winner = alive[0];
      G.logs.push(`Game Over! ${G.winner === 0 ? 'You win' : `AI ${G.winner} wins`} (last standing)!`);
    } else {
      // Everyone eliminated: most souls wins, tie-break by souls-wounds then XP.
      const ranked = Object.entries(G.players).map(([pid, p]) => ({
        pid: parseInt(pid),
        s: totalSouls(p),
        sw: totalSouls(p) - totalWounds(p),
        xp: p.boss?.xp || 0,
      })).sort((a, b) => b.sw - a.sw || a.xp - b.xp || b.s - a.s);
      G.gameOver = true;
      G.winner = ranked[0].pid;
      G.logs.push(`Game Over! ${G.winner === 0 ? 'You win' : `AI ${G.winner} wins`} with ${ranked[0].s} souls.`);
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
      // BOSS phase ends when every non-AI player has picked a boss. In solo
      // mode only player 0 is human, so it ends when player 0 picks (AI bosses
      // are auto-assigned in onEnd). In online mode all seats are human, so all
      // must pick.
      endIf: ({ G }) => G.players && Object.values(G.players)
        .filter(p => !p.isAI)
        .every(p => p.boss !== null),
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

        // Seed the discard pile: 4 random Rooms + 2 random Spells face-up
        // (per rules.md setup: "Set up the discard pile with 4 random Room
        // and 2 random Spell cards face-up in the pile.")
        for (let j = 0; j < 4; j++) {
          const card = G.decks.rooms.pop();
          if (card) G.decks.roomDiscard.push(card);
        }
        for (let j = 0; j < 2; j++) {
          const card = G.decks.spells.pop();
          if (card) G.decks.spellDiscard.push(card);
        }
        G.logs.push('Setup: discard pile seeded with 4 Rooms + 2 Spells.');
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
      // Build ends when every non-eliminated player has passed. AI players
      // are auto-passed by aiResolveBuild in onBegin.
      endIf: ({ G }) => G.players && Object.values(G.players).every(p => p.eliminated || p.passed),
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

        // AI opponents build rooms and cast build spells.
        for (let i = 1; i < ctx.numPlayers; i++) {
          aiResolveBuild(G, ctx, i);
        }
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
      // Bait ends when every non-eliminated player has passed. AI auto-passed
      // by aiResolveBait in onBegin.
      endIf: ({ G }) => G.players && Object.values(G.players).every(p => p.eliminated || p.passed),
      onBegin: ({ G, ctx }) => {
        G.logs.push(`--- Turn ${G.turn} - Bait Phase ---`);
        G.phase = PHASE.BAIT;

        // Fill town with heroes: one hero per surviving player per turn
        // (per the rules — town = #players, not a fixed 5). This balances the
        // early game so a freshly-built dungeon isn't overwhelmed.
        const aliveCount = Object.values(G.players).filter(p => !p.eliminated).length;
        const target = Math.max(1, aliveCount);
        while (G.town.length < target && (G.decks.heroes.length > 0 || G.decks.epics.length > 0)) {
          if (G.decks.heroes.length > 0 && Math.random() < 0.7) {
            G.town.push(G.decks.heroes.pop());
          } else if (G.decks.epics.length > 0) {
            G.town.push(G.decks.epics.pop());
          } else {
            G.town.push(G.decks.heroes.pop());
          }
        }

        Object.values(G.players).forEach(p => p.passed = false);

        // AI opponents may cast bait-phase spells.
        for (let i = 1; i < ctx.numPlayers; i++) {
          aiResolveBait(G, ctx, i);
        }
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
      // Adventure auto-resolves in onBegin; end only after it has run.
      endIf: ({ G }) => G.adventureResolved === true,
      onBegin: ({ G, ctx }) => {
        G.logs.push(`--- Turn ${G.turn} - Adventure Phase ---`);
        G.phase = PHASE.ADVENTURE;
        G.adventureResolved = false;

        // Process every hero in town through the lured dungeon. processAdventures
        // also runs checkWinConditions when done.
        processAdventures(G, ctx);

        Object.values(G.players).forEach(p => p.passed = false);

        G.adventureResolved = true;
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