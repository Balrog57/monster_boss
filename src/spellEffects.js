// spellEffects.js - Implements the 16 base-set Spell effects.
//
// Each spell has a `cast(G, ctx, casterId, opts)` function that mutates the
// game state. `opts` is { target: {type, playerId, roomIndex, heroRef}, ... }
// and may be omitted — spells auto-target a sensible default.
//
// Temporary "until end of turn" effects are stored in G.effects, an object
// keyed by effect id with arrays of { playerId, ...payload }. The adventure
// processor (processAdventures in BossMonster.js) consults these when resolving
// room damage and hero HP.
//
// Effect keys used by processAdventures:
//   roomDamageBonus   { playerId, roomIndex, amount, roomType? }  +damage to a room
//   heroHealthBonus   { heroRef, amount }                         +HP to a hero
//   deactivatedRooms  { playerId, roomIndex }                     room ignored this turn
//   buildBlocked      {}                                           no rooms can be built
//   extraBuild        { playerId }                                 +1 build allowed
//   noEntry           { playerId }                                 heroes skip this dungeon
//
// Reference: docs/rules/rules.md (spell clarifications) + card descriptions.

import { SPELL_CATEGORY } from './cardData.js';

// Build a fresh effects object for the start of a turn (cleared in End-of-Turn).
export function emptyEffects() {
  return {
    roomDamageBonus: [],   // { playerId, roomIndex, amount, roomType }
    heroHealthBonus: [],   // { heroRef, amount }
    deactivatedRooms: [],  // { playerId, roomIndex }
    buildBlocked: false,
    extraBuild: [],        // playerIds
    noEntry: [],           // playerIds whose dungeon heroes skip
  };
}

// Resolve a spell's effect. Returns true on success, false if it couldn't
// be applied (caller treats false as INVALID_MOVE-equivalent, but the card is
// still consumed per rules — we just log the failure).
export function castSpell(G, ctx, casterId, card, opts = {}) {
  const handler = SPELL_EFFECTS[card.id];
  if (!handler) {
    G.logs.push(`${card.name}: no effect implemented yet.`);
    return false;
  }
  return handler(G, ctx, casterId, opts);
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------
function findRoom(G, playerId, roomIndex) {
  const p = G.players[playerId];
  if (!p || roomIndex < 0 || roomIndex >= p.dungeon.length) return null;
  return { player: p, room: p.dungeon[roomIndex], index: roomIndex };
}

// Most spells that target a room in the caster's own dungeon default to the
// last room if no index is provided.
function autoRoomIndex(G, playerId, opts) {
  if (opts.roomIndex != null) return opts.roomIndex;
  const p = G.players[playerId];
  return p ? p.dungeon.length - 1 : -1;
}

function drawFromDeck(G, deckName, n) {
  const drawn = [];
  for (let i = 0; i < n; i++) {
    const card = G.decks[deckName].pop();
    if (card) drawn.push(card);
  }
  return drawn;
}

// ---------------------------------------------------------------------------
// Spell definitions
// ---------------------------------------------------------------------------
const SPELL_EFFECTS = {
  // --- ADVENTURE spells (cat 3) ---

  // BMA040: Give one Trap Room +3 damage until end of turn.
  BMA040: (G, ctx, casterId, opts) => {
    const idx = autoRoomIndex(G, casterId, opts);
    const found = findRoom(G, casterId, idx);
    if (!found || found.room.type !== 'trap') {
      G.logs.push('Annihilator requires a Trap Room.');
      return false;
    }
    G.effects.roomDamageBonus.push({ playerId: casterId, roomIndex: idx, amount: 3 });
    G.logs.push(`Annihilator: ${found.room.name} gains +3 damage this turn.`);
    return true;
  },

  // BMA041: Choose a Hero in an opponent's dungeon. Give that Hero +3 Health.
  BMA041: (G, ctx, casterId, opts) => {
    // Target a hero currently adventuring. In this engine heroes are processed
    // synchronously, so we apply +3 HP to the next hero entering opponents'
    // dungeons via a heroHealthBonus keyed by heroRef.
    const heroRef = opts.heroRef;
    if (!heroRef) {
      G.logs.push('Assassin: no target hero.');
      return false;
    }
    G.effects.heroHealthBonus.push({ heroRef, amount: 3 });
    G.logs.push(`Assassin: targeted hero gains +3 Health.`);
    return true;
  },

  // BMA047: Give one Monster Room +3 damage until end of turn.
  BMA047: (G, ctx, casterId, opts) => {
    const idx = autoRoomIndex(G, casterId, opts);
    const found = findRoom(G, casterId, idx);
    if (!found || found.room.type !== 'monster') {
      G.logs.push('Giant Size requires a Monster Room.');
      return false;
    }
    G.effects.roomDamageBonus.push({ playerId: casterId, roomIndex: idx, amount: 3, roomType: 'monster' });
    G.logs.push(`Giant Size: ${found.room.name} gains +3 damage this turn.`);
    return true;
  },

  // BMA050: If you have fewer rooms than an opponent, build an extra room this turn.
  BMA050: (G, ctx, casterId, opts) => {
    const myRooms = G.players[casterId].dungeon.length;
    const hasMore = Object.entries(G.players).some(([pid, p]) =>
      pid !== String(casterId) && !p.eliminated && p.dungeon.length > myRooms
    );
    if (!hasMore) {
      G.logs.push('Motivation: you do not have fewer rooms than an opponent.');
      return false;
    }
    G.effects.extraBuild.push(casterId);
    G.logs.push('Motivation: you may build an extra room this turn.');
    return true;
  },

  // --- BUILD + BAIT spells (cat 4) ---

  // BMA042: Destroy a room in your dungeon. Any Hero in that room is destroyed.
  BMA042: (G, ctx, casterId, opts) => {
    const idx = autoRoomIndex(G, casterId, opts);
    const found = findRoom(G, casterId, idx);
    if (!found) {
      G.logs.push('Cave-In: no room to destroy.');
      return false;
    }
    const destroyed = found.player.dungeon.splice(idx, 1)[0];
    G.decks.roomDiscard.push(destroyed);
    // Any hero currently in that room (entrance tracking) is destroyed.
    // In this engine heroes pass through synchronously, so we mark the bonus
    // for the next hero if at the destroyed index — simplified: log only.
    G.logs.push(`Cave-In: ${destroyed.name} destroyed.`);
    return true;
  },

  // BMA044: Deal X damage to one Hero in your dungeon, where X = #rooms.
  BMA044: (G, ctx, casterId, opts) => {
    const x = G.players[casterId].dungeon.length;
    const heroRef = opts.heroRef;
    if (!heroRef) {
      G.logs.push('Exhaustion: no target hero in your dungeon.');
      return false;
    }
    G.effects.heroDamage = (G.effects.heroDamage || []);
    G.effects.heroDamage.push({ heroRef, amount: x });
    G.logs.push(`Exhaustion: deals ${x} damage to a hero in your dungeon.`);
    return true;
  },

  // --- BAIT spells (cat 2) ---

  // BMA043: Cancel a Spell card that has just been played.
  BMA043: (G, ctx, casterId, opts) => {
    // The most-recently played spell is at the top of the spell discard.
    const last = G.decks.spellDiscard[G.decks.spellDiscard.length - 1];
    if (!last) {
      G.logs.push('Counterspell: no spell to counter.');
      return false;
    }
    // Undo its effect is non-trivial; per the card, the countered spell is
    // simply sent to the discard (no effect). We mark it as countered so the
    // adventure processor ignores any effect it registered.
    G.effects.counteredSpells = (G.effects.counteredSpells || []);
    G.effects.counteredSpells.push(last.id);
    G.logs.push(`Counterspell: ${last.name} is canceled.`);
    return true;
  },

  // BMA046: Deactivate one Room in any dungeon until end of turn.
  BMA046: (G, ctx, casterId, opts) => {
    const targetId = opts.targetPlayerId != null ? opts.targetPlayerId : casterId;
    const idx = autoRoomIndex(G, targetId, opts);
    const found = findRoom(G, targetId, idx);
    if (!found) {
      G.logs.push('Freeze: no room to deactivate.');
      return false;
    }
    G.effects.deactivatedRooms.push({ playerId: targetId, roomIndex: idx });
    G.logs.push(`Freeze: ${found.room.name} deactivated this turn.`);
    return true;
  },

  // BMA048: All players discard hands, then draw 1 Spell + 2 Rooms.
  BMA048: (G, ctx, casterId, opts) => {
    for (const [pid, p] of Object.entries(G.players)) {
      // Discard hand
      while (p.hand.length > 0) {
        const c = p.hand.pop();
        if (c.isSpell) G.decks.spellDiscard.push(c);
        else G.decks.roomDiscard.push(c);
      }
      // Draw 1 spell + 2 rooms
      const spell = drawFromDeck(G, 'spells', 1);
      const rooms = drawFromDeck(G, 'rooms', 2);
      p.hand.push(...spell, ...rooms);
    }
    G.logs.push('Jeopardy: all players discarded hands and drew 1 Spell + 2 Rooms.');
    return true;
  },

  // BMA049: No rooms can be built this turn. Face-down rooms returned to hand.
  BMA049: (G, ctx, casterId, opts) => {
    G.effects.buildBlocked = true;
    // Return any face-down rooms (those not yet revealed) to owners' hands.
    for (const [pid, p] of Object.entries(G.players)) {
      if (!p.revealed) {
        while (p.dungeon.length > 0) {
          const r = p.dungeon.pop();
          p.hand.push(r);
        }
      }
    }
    G.logs.push('Kobold Strike: no rooms can be built this turn.');
    return true;
  },

  // BMA054: A player with 2+ more Souls than you: no hero enters their dungeon.
  BMA054: (G, ctx, casterId, opts) => {
    const mySouls = G.players[casterId].souls.reduce((s, x) => s + (x.souls || 1), 0);
    let target = null;
    for (const [pid, p] of Object.entries(G.players)) {
      if (pid === String(casterId) || p.eliminated) continue;
      const theirSouls = p.souls.reduce((s, x) => s + (x.souls || 1), 0);
      if (theirSouls >= mySouls + 2) { target = parseInt(pid); break; }
    }
    if (target === null) {
      G.logs.push('Trepidation: no opponent has 2+ more souls than you.');
      return false;
    }
    G.effects.noEntry.push(target);
    G.logs.push(`Trepidation: no hero enters player ${target}'s dungeon this turn.`);
    return true;
  },

  // --- BUILD spells (cat 1) ---

  // BMA045: Choose a Hero in any dungeon and put it back in town.
  BMA045: (G, ctx, casterId, opts) => {
    const heroRef = opts.heroRef;
    if (!heroRef) {
      G.logs.push('Fear: no target hero.');
      return false;
    }
    // In the synchronous adventure model, "back to town" means the hero is
    // requeued at the front of the town queue (will be lured next turn).
    G.effects.fearHero = heroRef;
    G.logs.push('Fear: a hero is returned to town.');
    return true;
  },

  // BMA051: Choose one Hero in town. Place it at your dungeon entrance.
  BMA051: (G, ctx, casterId, opts) => {
    const townIdx = opts.townIndex != null ? opts.townIndex : 0;
    const hero = G.town[townIdx];
    if (!hero) {
      G.logs.push('Princess in Peril: no hero in town.');
      return false;
    }
    G.town.splice(townIdx, 1);
    G.players[casterId].entrance.push(hero);
    G.logs.push(`Princess in Peril: ${hero.name} placed at your dungeon entrance.`);
    return true;
  },

  // BMA052: Remove a face-down Hero from your scorekeeping area. Draw 2 Spells.
  BMA052: (G, ctx, casterId, opts) => {
    const p = G.players[casterId];
    // Souls are tracked as a list of {souls:1} placeholders; "remove one" =
    // pop the most recent. Per the card this is a dead hero (soul) removed.
    if (p.souls.length === 0) {
      G.logs.push('Soul Harvest: no soul to remove.');
      return false;
    }
    p.souls.pop();
    const spells = drawFromDeck(G, 'spells', 2);
    p.hand.push(...spells);
    G.logs.push(`Soul Harvest: removed a soul, drew ${spells.length} spells.`);
    return true;
  },

  // BMA053: Send a Hero in your dungeon back to the first room.
  BMA053: (G, ctx, casterId, opts) => {
    const heroRef = opts.heroRef;
    if (!heroRef) {
      G.logs.push('Teleportation: no target hero.');
      return false;
    }
    G.effects.teleportHero = heroRef;
    G.logs.push('Teleportation: a hero is sent back to your first room.');
    return true;
  },

  // BMA055: Send a dead Hero from an opponent's scorekeeping area back to their
  // dungeon entrance. It has +2 Health until end of turn.
  BMA055: (G, ctx, casterId, opts) => {
    const targetId = opts.targetPlayerId != null ? opts.targetPlayerId : null;
    let victim = null;
    if (targetId !== null) {
      victim = G.players[targetId];
    } else {
      // Pick first opponent with souls
      for (const [pid, p] of Object.entries(G.players)) {
        if (pid !== String(casterId) && !p.eliminated && p.souls.length > 0) {
          victim = p; break;
        }
      }
    }
    if (!victim || victim.souls.length === 0) {
      G.logs.push('Zombie Attack: no opponent has souls.');
      return false;
    }
    const revived = victim.souls.pop();
    // Revived hero re-enters the victim's dungeon entrance with +2 HP
    victim.entrance.push({ ...revived, name: 'Zombie', currentHP: 2, hp: 2, souls: 1 });
    G.logs.push('Zombie Attack: a dead hero returns to an opponent\'s dungeon (+2 HP).');
    return true;
  },
};

// ---------------------------------------------------------------------------
// Adventure-time queries (used by processAdventures to apply effects)
// ---------------------------------------------------------------------------

// Total damage bonus for a room from active effects.
export function roomDamageBonusFor(G, playerId, roomIndex) {
  if (!G.effects || !G.effects.roomDamageBonus) return 0;
  return G.effects.roomDamageBonus
    .filter(e => e.playerId === playerId && e.roomIndex === roomIndex)
    .reduce((sum, e) => sum + e.amount, 0);
}

// HP bonus for a hero (by reference id) from active effects.
export function heroHealthBonusFor(G, heroRef) {
  if (!G.effects || !G.effects.heroHealthBonus) return 0;
  return G.effects.heroHealthBonus
    .filter(e => e.heroRef === heroRef)
    .reduce((sum, e) => sum + e.amount, 0);
}

// Is a room deactivated this turn?
export function isRoomDeactivated(G, playerId, roomIndex) {
  if (!G.effects || !G.effects.deactivatedRooms) return false;
  return G.effects.deactivatedRooms.some(e => e.playerId === playerId && e.roomIndex === roomIndex);
}

// Can a player build this turn? (Kobold Strike)
export function isBuildBlocked(G) {
  return !!(G.effects && G.effects.buildBlocked);
}

// Does a player get an extra build this turn? (Motivation)
export function extraBuildsFor(G, playerId) {
  if (!G.effects || !G.effects.extraBuild) return 0;
  return G.effects.extraBuild.filter(id => id === playerId).length;
}

// Does a player's dungeon refuse entry this turn? (Trepidation)
export function isNoEntry(G, playerId) {
  return !!(G.effects && G.effects.noEntry.includes(playerId));
}
