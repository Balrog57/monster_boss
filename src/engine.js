// engine.js - Core game engine for Boss Monster with rule-correct turn structure.
//
// This engine is stateless helpers over a boardgame.io G object.
// It does not mutate G unless explicitly noted.

import { PHASE, TREASURE_NAMES, playerOrderByXP, totalSouls, totalWounds, drawCards, refillDeckFromDiscard } from './cardData.js';

export function activeRoom(stack) {
  if (!Array.isArray(stack) || stack.length === 0) return null;
  return stack[stack.length - 1];
}

export function allActiveRooms(dungeon) {
  // dungeon is an array of room stacks. Return top of each stack.
  return dungeon.map(stack => activeRoom(stack));
}

export function countVisibleRooms(dungeon) {
  return allActiveRooms(dungeon).filter(Boolean).length;
}

export function dungeonTreasures(G, playerId) {
  const p = G.players[playerId];
  if (!p || !p.boss) return [];
  const treasures = new Set(p.boss.treasures || []);
  for (const stack of p.dungeon) {
    const room = activeRoom(stack);
    if (!room) continue;
    for (const t of room.treasures || []) treasures.add(t);
  }
  return [...treasures];
}

export function treasureCount(G, playerId, treasure) {
  return dungeonTreasures(G, playerId).filter(t => t === treasure).length;
}

export function resolveBait(G) {
  // For each hero in town (FIFO order), determine target dungeon.
  // Rule: hero goes to dungeon with most matching treasure. Tie or no match = stays in town.
  const lureAssignments = []; // { hero, targetPlayerId: number|null, stayInTown: boolean }
  for (const hero of G.town) {
    const order = playerOrderByXP(G.players);
    let best = null;
    for (const pid of order) {
      const count = treasureCount(G, pid, hero.class);
      const candidate = { pid, count, wounds: totalWounds(G.players[pid]), souls: totalSouls(G.players[pid]) };
      if (best === null || count > best.count) best = candidate;
    }
    if (best && best.count > 0) {
      lureAssignments.push({ hero, targetPlayerId: best.pid, stayInTown: false });
    } else {
      lureAssignments.push({ hero, targetPlayerId: null, stayInTown: true });
    }
  }
  return lureAssignments;
}

export function canBuildRoom(G, playerId, handIndex, targetIndex = null) {
  const p = G.players[playerId];
  const card = p.hand[handIndex];
  if (!card || !card.isRoom) return false;
  if (G.effects.buildBlocked) return false;
  const allowedBuilds = 1 + (G.effects.extraBuild?.filter(id => id === playerId).length || 0);
  if ((p.buildsThisTurn || 0) >= allowedBuilds) return false;
  const visible = countVisibleRooms(p.dungeon);
  if (!card.advanced) {
    // Ordinary room: can build at end or over any existing stack.
    if (visible >= 5 && targetIndex === null) return false; // cannot extend beyond 5 visible
    return true;
  }
  // Advanced room: must be built over an active room with matching treasure.
  if (p.dungeon.length === 0) return false;
  const idx = targetIndex ?? p.dungeon.length - 1;
  const target = activeRoom(p.dungeon[idx]);
  if (!target) return false;
  const match = card.treasures?.some(t => (target.treasures || []).includes(t));
  if (!match) return false;
  return true;
}

export function buildRoom(G, playerId, handIndex, targetIndex = null) {
  const p = G.players[playerId];
  const card = p.hand[handIndex];
  if (!canBuildRoom(G, playerId, handIndex, targetIndex)) return false;
  p.hand.splice(handIndex, 1);
  if (!card.advanced) {
    // Ordinary: if targetIndex provided, push on stack; else append new stack at end.
    if (targetIndex != null) {
      if (!p.dungeon[targetIndex]) return false;
      p.dungeon[targetIndex].push(card);
    } else {
      p.dungeon.push([card]);
    }
  } else {
    const idx = targetIndex ?? p.dungeon.length - 1;
    const oldTop = activeRoom(p.dungeon[idx]);
    G.decks.roomDiscard.push(oldTop);
    p.dungeon[idx].push(card);
  }
  p.buildsThisTurn = (p.buildsThisTurn || 0) + 1;
  return true;
}

export function destroyRoom(G, playerId, roomIndex) {
  const p = G.players[playerId];
  const stack = p.dungeon[roomIndex];
  if (!stack || stack.length === 0) return null;
  const destroyed = stack.pop();
  G.decks.roomDiscard.push(destroyed);
  if (stack.length === 0) {
    // Remove empty stack and slide right rooms left? Per rules: hole closes, rooms slide right.
    // In our left-to-right order, removing a stack means subsequent stacks shift left (slide right relative to entrance?).
    // We model dungeon from entrance (left) to boss (right). A hole closes -> rooms to the right slide left.
    p.dungeon.splice(roomIndex, 1);
  }
  return destroyed;
}

export function roomDamageWithModifiers(G, playerId, roomIndex, hero) {
  const p = G.players[playerId];
  const room = activeRoom(p.dungeon[roomIndex]);
  if (!room) return 0;
  let dmg = room.damage || 0;

  // Monster's Ballroom: damage = number of active monster rooms
  if (room.id === 'BMA020') {
    const monsterCount = allActiveRooms(p.dungeon).filter(r => r && r.type === 'monster').length;
    dmg = monsterCount;
  }

  // Passive adjacency bonuses
  for (let i = 0; i < p.dungeon.length; i++) {
    if (i === roomIndex) continue;
    const other = activeRoom(p.dungeon[i]);
    if (!other) continue;
    if (other.id === 'BMA015' && Math.abs(i - roomIndex) === 1 && room.type === 'monster') dmg += 1; // Goblin Armory
    if (other.id === 'BMA029' && i === roomIndex - 1 && room.type === 'trap') dmg += 2; // Dizzygas Hallway
  }

  // Spell/ability damage bonuses
  if (G.effects.roomDamageBonus) {
    for (const e of G.effects.roomDamageBonus) {
      if (e.playerId === playerId && e.roomIndex === roomIndex) dmg += e.amount;
    }
  }

  return Math.max(0, dmg);
}

export function heroHealthWithModifiers(G, hero) {
  let hp = hero.hp;
  if (G.effects.heroHealthBonus) {
    for (const e of G.effects.heroHealthBonus) {
      if (e.heroId === hero.id) hp += e.amount;
    }
  }
  return hp;
}

export function isRoomDeactivated(G, playerId, roomIndex) {
  return G.effects.deactivatedRooms?.some(e => e.playerId === playerId && e.roomIndex === roomIndex) ?? false;
}

export function checkEndGame(G) {
  const players = Object.values(G.players);
  const alive = players.filter(p => !p.eliminated);
  for (const p of alive) {
    if (totalWounds(p) >= 5) p.eliminated = true;
  }
  const stillAlive = players.filter(p => !p.eliminated);
  const soulWinners = stillAlive.filter(p => totalSouls(p) >= 10);
  if (soulWinners.length === 1) {
    return { gameOver: true, winner: parseInt(Object.keys(G.players).find(pid => G.players[pid] === soulWinners[0])) };
  }
  if (soulWinners.length > 1) {
    soulWinners.sort((a, b) => {
      const diff = (totalSouls(b) - totalWounds(b)) - (totalSouls(a) - totalWounds(a));
      if (diff !== 0) return diff;
      return (a.boss?.xp || 0) - (b.boss?.xp || 0);
    });
    return { gameOver: true, winner: parseInt(Object.keys(G.players).find(pid => G.players[pid] === soulWinners[0])) };
  }
  if (stillAlive.length <= 1) {
    if (stillAlive.length === 1) {
      return { gameOver: true, winner: parseInt(Object.keys(G.players).find(pid => G.players[pid] === stillAlive[0])) };
    }
    // everyone eliminated: tie-break by souls - wounds then xp
    const ranked = players.map(p => ({
      pid: parseInt(Object.keys(G.players).find(pid => G.players[pid] === p)),
      score: totalSouls(p) - totalWounds(p),
      xp: p.boss?.xp || 0
    })).sort((a, b) => b.score - a.score || a.xp - b.xp);
    return { gameOver: true, winner: ranked[0].pid };
  }
  return { gameOver: false, winner: null };
}
