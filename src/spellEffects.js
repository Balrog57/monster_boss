// spellEffects.js - Implements the 16 base-set Spell effects for the new engine.
//
// Spells are resolved immediately when played. Target objects use:
//   { roomIndex, targetPlayerId, heroId, townIndex }

import { activeRoom, buildRoom } from './engine.js';
import { drawCards } from './cardData.js';

export function emptyEffects() {
  return {
    roomDamageBonus: [],   // { playerId, roomIndex, amount }
    heroHealthBonus: [],   // { heroId, amount }
    heroDamage: [],        // { heroId, amount } — consumed by resolveOneHero
    deactivatedRooms: [],    // { playerId, roomIndex }
    buildBlocked: false,
    extraBuild: [],        // playerIds
    noEntry: [],           // playerIds
    teleportHero: null,    // heroId — consumed by resolveOneHero
    counteredSpells: [],    // spell IDs that were countered
    treasureDoubled: [],   // playerIds whose treasure counts are doubled this turn
  };
}

export function castSpell(G, ctx, casterId, card, target) {
  // Normalize null/undefined target to {} so spell handlers can safely read
  // target.roomIndex, target.heroId, etc. without null checks.
  const t = target || {};
  const handler = SPELL_EFFECTS[card.id];
  if (!handler) {
    G.logs.push(`${card.name}: no effect implemented yet.`);
    return false;
  }
  return handler(G, ctx, casterId, t);
}

function findRoom(G, playerId, roomIndex) {
  const p = G.players[playerId];
  if (!p || roomIndex < 0 || roomIndex >= p.dungeon.length) return null;
  return activeRoom(p.dungeon[roomIndex]);
}

function autoRoomIndex(G, playerId, target) {
  if (target && target.roomIndex != null) return target.roomIndex;
  return G.players[playerId].dungeon.length - 1;
}

function totalSouls(p) {
  return p.souls.reduce((s, x) => s + (x.souls || 1), 0);
}

const SPELL_EFFECTS = {
  // BMA040: Annihilator — Trap Room +3 damage until end of turn
  BMA040: (G, ctx, casterId, target) => {
    const idx = autoRoomIndex(G, casterId, target);
    const room = findRoom(G, casterId, idx);
    if (!room || room.type !== 'trap') {
      G.logs.push('Annihilator requires a Trap Room.');
      return false;
    }
    G.effects.roomDamageBonus.push({ playerId: casterId, roomIndex: idx, amount: 3 });
    G.logs.push(`Annihilator: ${room.name} gains +3 damage this turn.`);
    return true;
  },

  // BMA041: Assassin — target hero in any dungeon gains +3 HP
  BMA041: (G, ctx, casterId, target) => {
    const heroId = target.heroId;
    if (!heroId) {
      G.logs.push('Assassin: no target hero.');
      return false;
    }
    G.effects.heroHealthBonus.push({ heroId, amount: 3 });
    G.logs.push('Assassin: targeted hero gains +3 Health.');
    return true;
  },

  // BMA047: Giant Size — Monster Room +3 damage until end of turn
  BMA047: (G, ctx, casterId, target) => {
    const idx = autoRoomIndex(G, casterId, target);
    const room = findRoom(G, casterId, idx);
    if (!room || room.type !== 'monster') {
      G.logs.push('Giant Size requires a Monster Room.');
      return false;
    }
    G.effects.roomDamageBonus.push({ playerId: casterId, roomIndex: idx, amount: 3 });
    G.logs.push(`Giant Size: ${room.name} gains +3 damage this turn.`);
    return true;
  },

  // BMA050: Motivation — extra build if you have fewer rooms
  BMA050: (G, ctx, casterId, target) => {
    const myRooms = countVisibleRooms(G.players[casterId].dungeon);
    const hasMore = Object.entries(G.players).some(([pid, p]) =>
      pid !== String(casterId) && !p.eliminated && countVisibleRooms(p.dungeon) > myRooms
    );
    if (!hasMore) {
      G.logs.push('Motivation: you do not have fewer rooms than an opponent.');
      return false;
    }
    G.effects.extraBuild.push(casterId);
    G.logs.push('Motivation: you may build an extra room this turn.');
    return true;
  },

  // BMA042: Cave-In — destroy a room in your dungeon
  BMA042: (G, ctx, casterId, target) => {
    const p = G.players[casterId];
    const idx = target.roomIndex != null ? target.roomIndex : p.dungeon.length - 1;
    if (idx < 0 || idx >= p.dungeon.length) {
      G.logs.push('Cave-In: no room to destroy.');
      return false;
    }
    const stack = p.dungeon[idx];
    const destroyed = stack.pop();
    G.decks.roomDiscard.push(destroyed);
    if (stack.length === 0) p.dungeon.splice(idx, 1);
    G.logs.push(`Cave-In: ${destroyed.name} destroyed.`);
    return true;
  },

  // BMA044: Exhaustion — X damage to one hero in your dungeon, X = visible rooms
  BMA044: (G, ctx, casterId, target) => {
    const x = countVisibleRooms(G.players[casterId].dungeon);
    const heroId = target.heroId;
    if (!heroId) {
      G.logs.push('Exhaustion: no target hero.');
      return false;
    }
    G.effects.heroDamage.push({ heroId, amount: x });
    G.logs.push(`Exhaustion: deals ${x} damage to a hero in your dungeon.`);
    return true;
  },

  // BMA043: Counterspell — cancel the last spell played
  BMA043: (G, ctx, casterId, target) => {
    const last = G.decks.spellDiscard[G.decks.spellDiscard.length - 1];
    if (!last) {
      G.logs.push('Counterspell: no spell to counter.');
      return false;
    }
    // Remove the last applied effect of that spell if possible (simplified).
    G.effects.counteredSpells = (G.effects.counteredSpells || []);
    G.effects.counteredSpells.push(last.id);
    G.logs.push(`Counterspell: ${last.name} is canceled.`);
    return true;
  },

  // BMA046: Freeze — deactivate one room until end of turn
  BMA046: (G, ctx, casterId, target) => {
    const targetId = target.targetPlayerId != null ? target.targetPlayerId : casterId;
    const idx = autoRoomIndex(G, targetId, target);
    if (!findRoom(G, targetId, idx)) {
      G.logs.push('Freeze: no room to deactivate.');
      return false;
    }
    G.effects.deactivatedRooms.push({ playerId: targetId, roomIndex: idx });
    G.logs.push(`Freeze: room at index ${idx} deactivated this turn.`);
    return true;
  },

  // BMA048: Jeopardy — all discard hands, draw 1 spell + 2 rooms
  BMA048: (G, ctx, casterId, target) => {
    for (const p of Object.values(G.players)) {
      while (p.hand.length > 0) {
        const c = p.hand.pop();
        if (c.isSpell) G.decks.spellDiscard.push(c);
        else G.decks.roomDiscard.push(c);
      }
      const spell = drawCards(G.decks.spells, 1);
      const rooms = drawCards(G.decks.rooms, 2);
      p.hand.push(...spell, ...rooms);
    }
    G.logs.push('Jeopardy: all players discarded hands and drew 1 Spell + 2 Rooms.');
    return true;
  },

  // BMA049: Kobold Strike — no rooms can be built this turn
  BMA049: (G, ctx, casterId, target) => {
    G.effects.buildBlocked = true;
    // Return any face-down rooms to hand? In our engine rooms are built immediately on stack.
    // Simplified: just block future builds.
    G.logs.push('Kobold Strike: no rooms can be built this turn.');
    return true;
  },

  // BMA054: Trepidation — player with 2+ more souls cannot be entered
  BMA054: (G, ctx, casterId, target) => {
    const mySouls = totalSouls(G.players[casterId]);
    let targetId = null;
    for (const [pid, p] of Object.entries(G.players)) {
      if (pid === String(casterId) || p.eliminated) continue;
      if (totalSouls(p) >= mySouls + 2) { targetId = parseInt(pid); break; }
    }
    if (targetId === null) {
      G.logs.push('Trepidation: no opponent has 2+ more souls than you.');
      return false;
    }
    G.effects.noEntry.push(targetId);
    G.logs.push(`Trepidation: no hero enters player ${targetId}'s dungeon this turn.`);
    return true;
  },

  // BMA045: Fear — return a hero in any dungeon to town
  BMA045: (G, ctx, casterId, target) => {
    const heroId = target.heroId;
    if (!heroId) {
      G.logs.push('Fear: no target hero.');
      return false;
    }
    // Find hero in an entrance and return to town.
    for (const p of Object.values(G.players)) {
      const idx = p.entrance.findIndex(h => h.id === heroId);
      if (idx >= 0) {
        const hero = p.entrance.splice(idx, 1)[0];
        G.town.unshift(hero);
        G.logs.push(`Fear: ${hero.name} returned to town.`);
        return true;
      }
    }
    G.logs.push('Fear: target hero not found.');
    return false;
  },

  // BMA051: Princess in Peril — move a hero from town to your entrance
  BMA051: (G, ctx, casterId, target) => {
    const townIdx = target.townIndex != null ? target.townIndex : 0;
    const hero = G.town[townIdx];
    if (!hero) {
      G.logs.push('Princess in Peril: no hero in town.');
      return false;
    }
    G.town.splice(townIdx, 1);
    G.players[casterId].entrance.push(hero);
    G.logs.push(`Princess in Peril: ${hero.name} placed at your entrance.`);
    return true;
  },

  // BMA052: Soul Harvest — remove a soul, draw 2 spells
  BMA052: (G, ctx, casterId, target) => {
    const p = G.players[casterId];
    if (p.souls.length === 0) {
      G.logs.push('Soul Harvest: no soul to remove.');
      return false;
    }
    p.souls.pop();
    const spells = drawCards(G.decks.spells, 2);
    p.hand.push(...spells);
    G.logs.push(`Soul Harvest: removed a soul, drew ${spells.length} spells.`);
    return true;
  },

  // BMA053: Teleportation — send a hero in your dungeon back to first room
  BMA053: (G, ctx, casterId, target) => {
    const heroId = target.heroId;
    if (!heroId) {
      G.logs.push('Teleportation: no target hero.');
      return false;
    }
    const p = G.players[casterId];
    const idx = p.entrance.findIndex(h => h.id === heroId);
    if (idx < 0) {
      G.logs.push('Teleportation: target hero not at your entrance.');
      return false;
    }
    // Mark hero to restart from first room. We'll track via an effect flag.
    G.effects.teleportHero = heroId;
    G.logs.push('Teleportation: hero will restart at the first room.');
    return true;
  },

  // BMA055: Zombie Attack — dead hero returns to opponent's entrance with +2 HP
  BMA055: (G, ctx, casterId, target) => {
    const targetId = target.targetPlayerId != null ? target.targetPlayerId : null;
    let victim = null;
    if (targetId !== null) victim = G.players[targetId];
    else {
      for (const [pid, p] of Object.entries(G.players)) {
        if (pid !== String(casterId) && !p.eliminated && p.souls.length > 0) { victim = p; break; }
      }
    }
    if (!victim || victim.souls.length === 0) {
      G.logs.push('Zombie Attack: no opponent has souls.');
      return false;
    }
    const revived = victim.souls.pop();
    // Revive with the hero's original HP + 2 (per official rules: "+2 Health
    // until end of turn"). The soul entry stores the hero's name; we look up
    // the original hero from the discard pile to get the base HP.
    const origHero = G.decks.heroDiscard.find(h => h.name === (revived.name || ''));
    const baseHP = origHero?.hp || 2;
    victim.entrance.push({ ...revived, name: revived.name || 'Zombie', hp: baseHP + 2, souls: 1, wounds: 1 });
    G.logs.push('Zombie Attack: a dead hero returns to an opponent\'s dungeon (+2 HP).');
    return true;
  },
};

function countVisibleRooms(dungeon) {
  let n = 0;
  for (const stack of dungeon) if (activeRoom(stack)) n++;
  return n;
}

export function roomDamageBonusFor(G, playerId, roomIndex) {
  if (!G.effects?.roomDamageBonus) return 0;
  return G.effects.roomDamageBonus
    .filter(e => e.playerId === playerId && e.roomIndex === roomIndex)
    .reduce((sum, e) => sum + e.amount, 0);
}

export function heroHealthBonusFor(G, heroId) {
  if (!G.effects?.heroHealthBonus) return 0;
  return G.effects.heroHealthBonus
    .filter(e => e.heroId === heroId)
    .reduce((sum, e) => sum + e.amount, 0);
}

export function heroDamageFor(G, heroId) {
  if (!G.effects?.heroDamage) return 0;
  return G.effects.heroDamage
    .filter(e => e.heroId === heroId)
    .reduce((sum, e) => sum + e.amount, 0);
}

export function isRoomDeactivated(G, playerId, roomIndex) {
  return G.effects?.deactivatedRooms?.some(e => e.playerId === playerId && e.roomIndex === roomIndex) ?? false;
}

export function isBuildBlocked(G) {
  return !!G.effects?.buildBlocked;
}

export function extraBuildsFor(G, playerId) {
  return G.effects?.extraBuild?.filter(id => id === playerId).length || 0;
}

export function isNoEntry(G, playerId) {
  return G.effects?.noEntry?.includes(playerId) ?? false;
}

export function isCountered(G, spellId) {
  return G.effects?.counteredSpells?.includes(spellId) ?? false;
}
