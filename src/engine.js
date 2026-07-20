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
  // Standard heroes: go to dungeon with the highest matching treasure count.
  //   Tie-break: fewest wounds, then fewest souls. If still tied, stays in town.
  // The Fool (class "The Fool", treasure 0): goes to the player with the fewest
  //   souls. Tie = stays in town.
  const lureAssignments = [];
  for (const hero of G.town) {
    if (hero.class === 'The Fool' || hero.treasure === 0) {
      // The Fool: lured to the player with the fewest souls.
      const order = playerOrderByXP(G.players);
      let fewestSouls = Infinity;
      let target = null;
      let tied = false;
      for (const pid of order) {
        const s = totalSouls(G.players[pid]);
        if (s < fewestSouls) { fewestSouls = s; target = pid; tied = false; }
        else if (s === fewestSouls) { tied = true; }
      }
      if (target != null && !tied) {
        lureAssignments.push({ hero, targetPlayerId: target, stayInTown: false });
      } else {
        lureAssignments.push({ hero, targetPlayerId: null, stayInTown: true });
      }
      continue;
    }

    // Standard hero: highest treasure count wins.
    const order = playerOrderByXP(G.players);
    let best = null;
    for (const pid of order) {
      const count = treasureCount(G, pid, hero.class);
      if (best === null) {
        best = { pid, count, wounds: totalWounds(G.players[pid]), souls: totalSouls(G.players[pid]) };
      } else if (count > best.count) {
        best = { pid, count, wounds: totalWounds(G.players[pid]), souls: totalSouls(G.players[pid]) };
      } else if (count === best.count && count > 0) {
        // Tie-break: fewest wounds, then fewest souls. If still tied, the hero
        // stays in town (no one wins the tie).
        const w = totalWounds(G.players[pid]);
        const s = totalSouls(G.players[pid]);
        if (w < best.wounds || (w === best.wounds && s < best.souls)) {
          best = { pid, count, wounds: w, souls: s };
        } else if (w === best.wounds && s === best.souls) {
          // Exact tie — hero stays in town. Mark best as null to signal this.
          best = null;
          break;
        }
      }
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
    // Neanderthal Cave (BMA018): advanced rooms cannot be built on top of it,
    // but ordinary rooms can (per official rules, ordinary rooms build over
    // anything). No restriction needed here for ordinary rooms.
    return true;
  }
  // Advanced room: must be built over an active room with matching treasure.
  if (p.dungeon.length === 0) return false;
  const idx = targetIndex ?? p.dungeon.length - 1;
  const target = activeRoom(p.dungeon[idx]);
  if (!target) return false;
  // Neanderthal Cave (BMA018): "You cannot build an Advanced Room on
  // Neanderthal Cave."
  if (target.id === 'BMA018') return false;
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
    // Ordinary: if targetIndex provided, push on stack; else insert new stack
    // at the LEFT (entrance side) per official rules: "build additional new
    // rooms to the left" (left = entrance = index 0).
    if (targetIndex != null) {
      if (!p.dungeon[targetIndex]) return false;
      p.dungeon[targetIndex].push(card);
    } else {
      p.dungeon.unshift([card]); // insert at entrance (left)
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
    p.dungeon.splice(roomIndex, 1);
  }
  // Recycling Center (BMA031): when another room is destroyed, draw 2 rooms.
  for (const s of p.dungeon) {
    const r = activeRoom(s);
    if (r && r.id === 'BMA031' && r !== destroyed) {
      for (let i = 0; i < 2; i++) {
        const card = G.decks.rooms.pop();
        if (card) { p.hand.push(card); G.logs.push(`Recycling Center: drew ${card.name}.`); }
      }
      break;
    }
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
    // Official rules: "In the case of a tie, the Boss with the lowest XP value wins."
    // No souls-wounds tiebreaker — just lowest XP.
    soulWinners.sort((a, b) => (a.boss?.xp || 0) - (b.boss?.xp || 0));
    return { gameOver: true, winner: parseInt(Object.keys(G.players).find(pid => G.players[pid] === soulWinners[0])) };
  }
  if (stillAlive.length <= 1) {
    if (stillAlive.length === 1) {
      return { gameOver: true, winner: parseInt(Object.keys(G.players).find(pid => G.players[pid] === stillAlive[0])) };
    }
    // everyone eliminated: tie-break by lowest XP (official: lowest XP wins)
    const ranked = players.map(p => ({
      pid: parseInt(Object.keys(G.players).find(pid => G.players[pid] === p)),
      xp: p.boss?.xp || 0
    })).sort((a, b) => a.xp - b.xp);
    return { gameOver: true, winner: ranked[0].pid };
  }
  return { gameOver: false, winner: null };
}
