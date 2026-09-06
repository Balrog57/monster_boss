// engine.js - Core game engine for Boss Monster with rule-correct turn structure.
//
// This engine is stateless helpers over a boardgame.io G object.
// It does not mutate G unless explicitly noted.

import { PHASE, TREASURE_NAMES, playerOrderByXP, totalSouls, totalWounds, drawCards, refillDeckFromDiscard } from './cardData.js';
import { onRoomDestroyed, gainCoin } from './minibosses.js';
import { imperiatrixDamageBonus, killaDamageBonus, scottDamageBonus } from './expansionBosses.js';

function zaraCountsAllTreasures(stack) {
  const mb = stack?.miniboss;
  return mb && !mb.faceDown && mb.card?.id === 'RMB202' && mb.level >= 1;
}

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

/** Always 5 APK dungeon frames; rooms pack against the boss (right). */
export const DUNGEON_SLOTS = 5;

/** Visual index of the only empty slot that may receive a new entrance room. */
export function extendVisualIndex(dungeon) {
  const len = dungeon?.length || 0;
  if (len >= DUNGEON_SLOTS) return null;
  if (len === 0) return DUNGEON_SLOTS - 1;
  return DUNGEON_SLOTS - len - 1;
}

/** Map a visual slot (0 = far left) to a dungeon stack index, or null if empty. */
export function dungeonIndexFromVisual(dungeon, visualIndex) {
  const offset = DUNGEON_SLOTS - (dungeon?.length || 0);
  const di = visualIndex - offset;
  return di >= 0 ? di : null;
}

function playerOf(G, playerId) {
  return G.players[playerId] || G.players[String(playerId)];
}

/** All treasure icons in a dungeon (boss + visible rooms). Duplicates count. */
export function dungeonTreasures(G, playerId) {
  const p = playerOf(G, playerId);
  if (!p || !p.boss) return [];
  const treasures = [...(p.boss.treasures || [])];
  (p.dungeon || []).forEach((stack, i) => {
    const room = activeRoom(stack);
    if (!room) return;
    const suppressed = G.effects?.roomTreasureSuppressed?.some(
      (e) => Number(e.playerId) === Number(playerId) && e.roomIndex === i,
    );
    if (zaraCountsAllTreasures(stack)) {
      if (!suppressed) treasures.push(1, 2, 3, 4);
    } else if (!suppressed) {
      for (const t of room.treasures || []) treasures.push(t);
    }
    for (const e of G.effects?.roomExtraTreasures || []) {
      if (Number(e.playerId) === Number(playerId) && e.roomIndex === i) {
        treasures.push(...(e.treasures || []));
      }
    }
  });
  return treasures;
}

function treasureKey(treasure) {
  if (typeof treasure === 'number') return treasure;
  const i = TREASURE_NAMES.indexOf(treasure);
  return i > 0 ? i : treasure;
}

export function treasureCount(G, playerId, treasure) {
  const key = treasureKey(treasure);
  let count = dungeonTreasures(G, playerId).filter(t => t === key).length;
  // Jackpot Stash (BMA030): treasure values doubled this turn
  const doubled = G.effects?.treasureDoubled;
  if (doubled?.some(id => String(id) === String(playerId))) count *= 2;
  return count;
}

/** { 1: cleric, 2: fighter, 3: mage, 4: thief } counts for HUD readout. */
export function treasureCountsByType(G, playerId) {
  const counts = {
    1: treasureCount(G, playerId, 1),
    2: treasureCount(G, playerId, 2),
    3: treasureCount(G, playerId, 3),
    4: treasureCount(G, playerId, 4),
  };
  if (G.largeGame || setsHasExplorer(G)) counts[5] = treasureCount(G, playerId, 5);
  return counts;
}

function setsHasExplorer(G) {
  return Object.values(G.players || {}).some((p) =>
    (p.boss?.treasures || []).includes(5) || (p.dungeon || []).some((s) => (activeRoom(s)?.treasures || []).includes(5))
  );
}

function heroLureTreasure(hero) {
  if (hero.hybrid && Array.isArray(hero.treasures) && hero.treasures.length > 1) {
    return hero.treasures;
  }
  return [hero.treasure ?? 1];
}

function lureByHighestHybrid(G, treasures) {
  return lureByHighest(G, (pid) => treasures.reduce((sum, t) => sum + treasureCount(G, pid, t), 0));
}

function lureTiedPlayers(G, getCount) {
  // Players tied for highest matching treasure (large-game split uses this list).
  const order = playerOrderByXP(G.players);
  let bestCount = -1;
  let candidates = [];
  for (const pid of order) {
    const p = G.players[pid];
    if (p?.eliminated) continue;
    const count = getCount(pid);
    if (count <= 0) continue;
    if (count > bestCount) {
      bestCount = count;
      candidates = [pid];
    } else if (count === bestCount) {
      candidates.push(pid);
    }
  }
  if (candidates.length < 2 || bestCount <= 0) return [];
  return candidates;
}

function assignLure(G, hero, getCount, splitState, splitKey) {
  const targetPid = lureByHighest(G, getCount);
  if (targetPid != null) {
    return { hero, targetPlayerId: targetPid, stayInTown: false };
  }
  if (G.largeGame) {
    const tied = lureTiedPlayers(G, getCount);
    if (tied.length >= 2) {
      const treasure = splitKey ?? hero.treasure ?? hero.class;
      const heroesOfType = G.town.filter((h) => {
        if (hero.hybrid) {
          const ht = heroLureTreasure(hero);
          return ht.some((t) => heroLureTreasure(h).includes(t));
        }
        if (hero.dark) return h.dark;
        const tKey = Number(treasure);
        return (h.treasure ?? h.class) === tKey || h.class === treasure;
      });
      if (heroesOfType.length >= tied.length) {
        if (!splitState[splitKey]) splitState[splitKey] = { tied, next: 0 };
        const st = splitState[splitKey];
        const pid = st.tied[st.next % st.tied.length];
        st.next += 1;
        return { hero, targetPlayerId: pid, stayInTown: false };
      }
    }
  }
  return { hero, targetPlayerId: null, stayInTown: true };
}

function splitLureForLargeGame(G, treasure, tiedPids) {
  const heroesOfType = G.town.filter((h) => heroLureTreasure(h).includes(treasure));
  if (!heroesOfType.length || tiedPids.length < 2) return [];
  const order = playerOrderByXP(G.players).filter((pid) => tiedPids.includes(pid));
  const assignments = [];
  let hi = 0;
  const perPlayer = Math.floor(heroesOfType.length / tiedPids.length);
  if (perPlayer < 1) return [];
  for (const pid of order) {
    for (let n = 0; n < perPlayer && hi < heroesOfType.length; n++) {
      assignments.push({ hero: heroesOfType[hi], targetPlayerId: pid, stayInTown: false });
      hi += 1;
    }
  }
  return assignments;
}

function lureByHighest(G, getCount) {
  // Official bait: highest matching treasure wins. Any treasure tie → stay in town
  // (no wounds/souls tie-break for standard heroes). See docs/rules/rules.md.
  const order = playerOrderByXP(G.players);
  let bestPid = null;
  let bestCount = 0;
  let tied = false;
  for (const pid of order) {
    const p = G.players[pid];
    if (p?.eliminated) continue;
    const count = getCount(pid);
    if (count > bestCount) {
      bestCount = count;
      bestPid = pid;
      tied = false;
    } else if (count === bestCount && count > 0) {
      tied = true;
    }
  }
  if (bestCount <= 0 || tied) return null;
  return bestPid;
}

export function resolveBait(G) {
  // For each hero in town (FIFO order), determine target dungeon.
  // Standard heroes: go to dungeon with the highest matching treasure count.
  //   Ties for highest treasure → stays in Town (official rules).
  // The Fool (class "The Fool", treasure 0): goes to the player with the fewest
  //   souls. Tie = stays in town.
  const lureAssignments = [];
  const splitState = {};
  for (const hero of G.town) {
    if (hero.id === 'KSA014' || hero.class === 'The Fool' || (hero.treasure === 0 && hero.id !== 'KSA016' && hero.id !== 'KSA017')) {
      // Demigod: fewest wounds. The Fool: fewest souls.
      const order = playerOrderByXP(G.players);
      const useWounds = hero.id === 'KSA014';
      let bestVal = Infinity;
      let target = null;
      let tied = false;
      for (const pid of order) {
        const v = useWounds ? totalWounds(G.players[pid]) : totalSouls(G.players[pid]);
        if (v < bestVal) { bestVal = v; target = pid; tied = false; }
        else if (v === bestVal) { tied = true; }
      }
      if (target != null && !tied) {
        lureAssignments.push({ hero, targetPlayerId: target, stayInTown: false });
      } else {
        lureAssignments.push({ hero, targetPlayerId: null, stayInTown: true });
      }
      continue;
    }

    let assignment;
    if (hero.id === 'KSA016') {
      assignment = assignLure(G, hero, (pid) => treasureCount(G, pid, 1) + treasureCount(G, pid, 2), splitState, 'mh');
    } else if (hero.id === 'KSA017') {
      assignment = assignLure(G, hero, (pid) => treasureCount(G, pid, 3) + treasureCount(G, pid, 4), splitState, 'tm');
    } else if (hero.hybrid) {
      const treasures = heroLureTreasure(hero);
      assignment = assignLure(
        G,
        hero,
        (pid) => treasures.reduce((sum, t) => sum + treasureCount(G, pid, t), 0),
        splitState,
        `hybrid-${treasures.join('-')}`,
      );
    } else {
      const t = hero.treasure ?? hero.class;
      assignment = assignLure(G, hero, (pid) => treasureCount(G, pid, t), splitState, String(t));
    }
    lureAssignments.push(assignment);
  }
  return lureAssignments;
}

export function canBuildRoom(G, playerId, handIndex, targetIndex = null) {
  const p = playerOf(G, playerId);
  if (!p) return false;
  const card = p.hand[handIndex];
  if (!card || !card.isRoom) return false;
  if (G.effects.buildBlocked) return false;
  const allowedBuilds = 1 + (G.effects.extraBuild?.filter(id => id === playerId).length || 0);
  if ((p.buildsThisTurn || 0) >= allowedBuilds) return false;
  const visible = countVisibleRooms(p.dungeon);
  if (!card.advanced) {
    // Ordinary room: can build at end or over any existing stack.
    if (visible >= 5 && targetIndex === null) return false; // cannot extend beyond 5 visible
    if (fetidBlocksMonsterBuild(p, card, targetIndex)) return false;
    return true;
  }
  // Advanced room: must be built over an active room with matching treasure.
  // Hypercube (CRL011): may build over any room.
  if (card.id === 'CRL011') {
    if (targetIndex == null) return false;
    if (fetidBlocksMonsterBuild(p, card, targetIndex)) return false;
    return !!activeRoom(p.dungeon[targetIndex]);
  }
  if (p.dungeon.length === 0) return false;
  const idx = targetIndex ?? p.dungeon.length - 1;
  const target = activeRoom(p.dungeon[idx]);
  if (!target) return false;
  // Neanderthal Cave (BMA018): "You cannot build an Advanced Room on
  // Neanderthal Cave."
  if (target.id === 'BMA018') return false;
  const match = card.treasures?.some(t => (target.treasures || []).includes(t));
  if (!match) return false;
  if (fetidBlocksMonsterBuild(p, card, idx)) return false;
  return true;
}

/** Fetid Beast (RMB025): Monster Rooms may not be built adjacent to it. */
function fetidBlocksMonsterBuild(p, card, targetIndex) {
  if (card.type !== 'monster' || card.id === 'RMB025') return false;
  if (targetIndex == null && !card.advanced) {
    // New stack at entrance (index 0); adjacent becomes current index 0.
    return activeRoom(p.dungeon[0])?.id === 'RMB025';
  }
  const idx = targetIndex ?? p.dungeon.length - 1;
  for (const j of [idx - 1, idx + 1]) {
    if (j >= 0 && j < p.dungeon.length && activeRoom(p.dungeon[j])?.id === 'RMB025') return true;
  }
  return false;
}

export function buildRoom(G, playerId, handIndex, targetIndex = null) {
  const p = playerOf(G, playerId);
  if (!p) return false;
  const card = p.hand[handIndex];
  if (!canBuildRoom(G, playerId, handIndex, targetIndex)) return false;
  p.hand.splice(handIndex, 1);
  let builtIndex;
  if (!card.advanced) {
    // Ordinary: if targetIndex provided, push on stack; else insert new stack
    // at the LEFT (entrance side) per official rules: "build additional new
    // rooms to the left" (left = entrance = index 0).
    if (targetIndex != null) {
      if (!p.dungeon[targetIndex]) return false;
      p.dungeon[targetIndex].push(card);
      builtIndex = targetIndex;
    } else {
      p.dungeon.unshift([card]); // insert at entrance (left)
      builtIndex = 0;
    }
  } else {
    const idx = targetIndex ?? p.dungeon.length - 1;
    const oldTop = activeRoom(p.dungeon[idx]);
    G.decks.roomDiscard.push(oldTop);
    p.dungeon[idx].push(card);
    builtIndex = idx;
  }
  p.buildsThisTurn = (p.buildsThisTurn || 0) + 1;
  // Goblin Market (RMB023): build adjacent → gain 2 coins per Market.
  for (const j of [builtIndex - 1, builtIndex + 1]) {
    if (j >= 0 && j < p.dungeon.length && activeRoom(p.dungeon[j])?.id === 'RMB023') {
      gainCoin(G, playerId, 2, 'Goblin Market');
    }
  }
  return true;
}

export function destroyRoom(G, playerId, roomIndex) {
  const p = G.players[playerId];
  const stack = p.dungeon[roomIndex];
  if (!stack || stack.length === 0) return null;
  const destroyed = stack.pop();
  G.decks.roomDiscard.push(destroyed);
  // Cursed Tomb (TNL054): opponents discard 2 Room cards when this is destroyed by another effect.
  if (destroyed?.id === 'TNL054') {
    for (const [opid, op] of Object.entries(G.players || {})) {
      if (Number(opid) === Number(playerId) || op.eliminated) continue;
      let n = 0;
      while (n < 2) {
        const ri = (op.hand || []).findIndex((c) => c.isRoom);
        if (ri < 0) break;
        G.decks.roomDiscard.push(op.hand.splice(ri, 1)[0]);
        n += 1;
      }
      if (n) G.logs.push(`Cursed Tomb: Player ${opid} discarded ${n} Room(s).`);
    }
  }
  if (stack.length === 0) {
    onRoomDestroyed(G, playerId, stack);
    p.dungeon.splice(roomIndex, 1);
    if (G.adventure && Number(G.adventure.playerId) === Number(playerId)) {
      const adv = G.adventure;
      if (adv.roomIndex === roomIndex) {
        adv.roomIndex = Math.min(roomIndex, p.dungeon.length - 1);
        G.logs.push(`${adv.hero?.name || 'Hero'} exits the destroyed room.`);
      } else if (adv.roomIndex > roomIndex) {
        adv.roomIndex -= 1;
      }
    }
  } else {
    const uncovered = activeRoom(stack);
    applyRoomUncovered(G, playerId, roomIndex, uncovered);
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
  // Garbage Chute (RMB041): once per turn when a Room is destroyed, gain 2 coins.
  for (const [pid, owner] of Object.entries(G.players || {})) {
    for (const s of owner.dungeon || []) {
      const r = activeRoom(s);
      if (r?.id === 'RMB041' && !r.usedThisTurn) {
        gainCoin(G, pid, 2, 'Garbage Chute');
        r.usedThisTurn = true;
        break;
      }
    }
  }
  // Black Market (RMB033): once per turn, pay 1 coin to draw a spell when any room is destroyed.
  for (const [pid, owner] of Object.entries(G.players || {})) {
    for (const s of owner.dungeon || []) {
      const r = activeRoom(s);
      if (r?.id === 'RMB033' && !r.usedThisTurn && (owner.coins || 0) >= 1) {
        owner.coins -= 1;
        const spell = G.decks.spells.pop();
        if (spell) {
          owner.hand.push(spell);
          G.logs.push(`Black Market: Player ${pid} paid 1 Coin, drew ${spell.name}.`);
        }
        r.usedThisTurn = true;
        break;
      }
    }
  }
  return destroyed;
}

export function applyRoomUncovered(G, playerId, roomIndex, uncovered) {
  if (!uncovered) return;
  const p = G.players[playerId];
  if (uncovered.onUncover === 'draw-room') {
    const card = G.decks.rooms.pop();
    if (card) { p.hand.push(card); G.logs.push(`${uncovered.name} uncovered: drew ${card.name}.`); }
  }
  if (uncovered.id === 'TNL044') {
    G.effects.roomDamageBonus = G.effects.roomDamageBonus || [];
    G.effects.roomDamageBonus.push({ playerId, roomIndex, amount: 3 });
    G.logs.push('Spiked Pit: +3 damage until end of turn.');
  }
  if (uncovered.id === 'TNL036') {
    const card = G.decks.spells.pop();
    if (card) { p.hand.push(card); G.logs.push(`Sorcerobe School uncovered: drew ${card.name}.`); }
  }
  if (uncovered.id === 'TNL027') {
    const others = (p.dungeon || []).map((s, i) => ({ i, room: activeRoom(s) }))
      .filter((o) => o.room && o.i !== roomIndex && o.room.type === 'monster');
    if (others.length) {
      const pick = others[0];
      G.effects.roomDamageBonus = G.effects.roomDamageBonus || [];
      G.effects.roomDamageBonus.push({ playerId, roomIndex: pick.i, amount: 3 });
      G.logs.push(`Shrooman Cave: ${pick.room.name} +3 until end of turn.`);
    }
  }
  if (uncovered.id === 'CRL014') {
    G.effects.roomDamageBonus = G.effects.roomDamageBonus || [];
    G.effects.roomDamageBonus.push({ playerId, roomIndex, amount: uncovered.damage || 1 });
    G.logs.push('Caged Gundarf: damage doubled until end of turn.');
  }
  if (uncovered.id === 'CRL015') {
    const card = G.decks.spells.pop();
    if (card) { p.hand.push(card); G.logs.push(`Celestial Map: drew ${card.name}.`); }
    destroyRoom(G, playerId, roomIndex);
    return;
  }
  if (uncovered.id === 'CRL016') {
    if (G.adventure && Number(G.adventure.playerId) === Number(playerId) && G.adventure.hero) {
      G.adventure.hp -= 3;
      G.logs.push(`Darkling Lair: 3 damage to ${G.adventure.hero.name} (HP ${G.adventure.hp}).`);
    } else if ((p.entrance || []).length) {
      const hero = p.entrance[0];
      hero._entranceHp = Math.max(0, (hero._entranceHp ?? hero.hp) - 3);
      G.logs.push(`Darkling Lair: 3 damage to ${hero.name} at entrance.`);
      if (hero._entranceHp <= 0) {
        p.entrance.shift();
        G.decks.heroDiscard = G.decks.heroDiscard || [];
        G.decks.heroDiscard.push(hero);
        G.logs.push(`Darkling Lair: ${hero.name} died at the entrance.`);
      }
    }
  }
  if (uncovered.id === 'RMB018') {
    // Optional heal handled only on build with choice; uncover uses same optional auto if miniboss in hand
    const mbIdx = (p.hand || []).findIndex((c) => c.isMiniboss || c.levels);
    if (mbIdx >= 0 && (p.wounds || []).length) {
      const discarded = p.hand.splice(mbIdx, 1)[0];
      G.decks.minibossDiscard = G.decks.minibossDiscard || [];
      G.decks.minibossDiscard.push(discarded);
      const soul = healOneWound(p);
      if (soul) G.logs.push(`Vampire Lab: discarded ${discarded.name}, healed a Wound.`);
    }
  }
  if (uncovered.id === 'CRL013') {
    const opts = (G.decks.roomDiscard || [])
      .map((card, i) => ({ card, pile: 'room', pileIndex: i }))
      .filter((o) => o.card?.advanced);
    if (opts.length === 1) {
      const card = G.decks.roomDiscard.splice(opts[0].pileIndex, 1)[0];
      p.hand.push(card);
      G.logs.push(`Crash Site: recovered ${card.name}.`);
    } else if (opts.length > 1) {
      G.pendingChoice = {
        type: 'recover-card',
        resume: false,
        playerId: Number(playerId),
        bossName: 'Crash Site',
        message: 'Crash Site: choose an Advanced Room from the discard',
        options: opts,
      };
    } else {
      G.logs.push('Crash Site: no Advanced Room in discard.');
    }
  }
  if (uncovered.id === 'RMB028') {
    applyDragonsNestBoost(G, playerId, uncovered);
  }
}

export function applyDragonsNestBoost(G, playerId, nestRoom) {
  const p = G.players[playerId];
  if (!p) return;
  G.effects.roomDamageBonus = G.effects.roomDamageBonus || [];
  let boosted = 0;
  (p.dungeon || []).forEach((s, i) => {
    const r = activeRoom(s);
    if (!r || r === nestRoom || r.type !== 'monster') return;
    const amount = (r.treasures || []).length;
    if (!amount) return;
    G.effects.roomDamageBonus.push({ playerId, roomIndex: i, amount });
    boosted += 1;
  });
  if (boosted) G.logs.push(`Dragon's Nest: boosted ${boosted} Monster Room(s) by their treasure icons.`);
}

function ignoresRoomAbilityText(G, playerId, hero) {
  if (hero?.id === 'KSA017' || hero?.item?.id === 'THK014') return true;
  return G.effects?.ignoreAbilityPids?.some((id) => String(id) === String(playerId)) ?? false;
}

export function roomDamageWithModifiers(G, playerId, roomIndex, hero) {
  const p = G.players[playerId] || G.players[String(playerId)];
  const room = activeRoom(p.dungeon[roomIndex]);
  if (!room) return 0;
  let dmg = room.damage || 0;
  const skipAbilities = ignoresRoomAbilityText(G, playerId, hero);

  // Monster's Ballroom: damage = number of active monster rooms (ability text)
  if (room.id === 'BMA020' && !skipAbilities) {
    const monsterCount = allActiveRooms(p.dungeon).filter(r => r && r.type === 'monster').length;
    dmg = monsterCount;
  }

  // Goblin Suit: ignore ordinary Monster Rooms
  if (hero?.item?.id === 'THK005' && room.type === 'monster' && !room.advanced) {
    dmg = 0;
  }

  // Star of Invulnerability: ignore damage from the first three rooms
  if (hero?.item?.id === 'THK019' && roomIndex < 3) {
    dmg = 0;
  }

  // Monster Hunter: Monster Rooms deal -1
  if (hero?.id === 'KSA016' && room.type === 'monster') {
    dmg = Math.max(0, dmg - 1);
  }

  // Passive adjacency bonuses (ability text)
  if (!skipAbilities) {
    for (let i = 0; i < p.dungeon.length; i++) {
      if (i === roomIndex) continue;
      const other = activeRoom(p.dungeon[i]);
      if (!other) continue;
      if (other.id === 'BMA015' && Math.abs(i - roomIndex) === 1 && room.type === 'monster') dmg += 1; // Goblin Armory
      if (other.id === 'BMA029' && i === roomIndex - 1 && room.type === 'trap') dmg += 2; // Dizzygas Hallway
      if (other.id === 'CRL008' && Math.abs(i - roomIndex) === 1) dmg += 1; // Invasion Swarm
      if (other.id === 'RMB024' && i === roomIndex - 1 && room.type === 'monster') dmg += 2; // Power Leech (room to the right of leech)
      if (other.id === 'TNL023' && i === roomIndex + 1 && room.type === 'monster') dmg += 2; // Goblin Nursery (left of nursery)
      if (other.id === 'TNL028' && room.type === 'monster') dmg += 1; // Goblin Mess Hall
    }
  }

  // Reactor Core: Advanced Rooms in your dungeon have +1
  if (!skipAbilities) {
    const hasReactor = (p.dungeon || []).some((s) => activeRoom(s)?.id === 'CRL009');
    if (hasReactor && room.advanced) dmg += 1;
    // Alien Ooze: +1 if another Explorer treasure room exists
    if (room.id === 'CRL005') {
      const otherExplorer = (p.dungeon || []).some((s, i) => {
        if (i === roomIndex) return false;
        const r = activeRoom(s);
        return r && (r.treasures || []).includes(5);
      });
      if (otherExplorer) dmg += 1;
    }
    // Magipede / Elemental Generator: +1 per Spell in hand
    if (room.id === 'RMB039' || room.id === 'TNL038') {
      dmg += (p.hand || []).filter((c) => c.isSpell).length;
    }
    // Doppelganger Hive: +1 per hero lured this turn
    if (room.id === 'RMB029') {
      const key = String(playerId);
      dmg += G.luredThisTurn?.[playerId] || G.luredThisTurn?.[key] || 0;
    }
    // The Dreadmill: +1 per coin on room
    if (room.id === 'RMB048') {
      dmg += room.coinsOn || 0;
    }
  }

  // Spell/ability damage bonuses
  if (G.effects.roomDamageBonus) {
    for (const e of G.effects.roomDamageBonus) {
      if (e.playerId === playerId && e.roomIndex === roomIndex) dmg += e.amount;
    }
  }

  if (G.effects.ordinaryMonsterBonus?.some((id) => String(id) === String(playerId)) && room.type === 'monster' && !room.advanced) {
    dmg += 1;
  }

  // Scythe (KSA005): last room +3 after level-up
  if (p.scytheBoost && roomIndex === p.dungeon.length - 1) dmg += 3;

  dmg += imperiatrixDamageBonus(G, playerId, room);
  dmg += killaDamageBonus(G, playerId, roomIndex);
  dmg += scottDamageBonus(G, playerId, room);

  const stack = p.dungeon[roomIndex];
  const mb = stack?.miniboss;
  if (mb && !mb.faceDown && mb.card?.id === 'RMB201') dmg += mb.level >= 2 ? 2 : 1;

  const shadowCorridor = p.dungeon.some((s) => activeRoom(s)?.id === 'TNL102');
  if (shadowCorridor && room.type === 'trap' && !room.advanced) dmg += 1;

  return Math.max(0, dmg);
}

export function heroHealthWithModifiers(G, hero) {
  let hp = hero.hp;
  if (G.effects.heroHealthBonus) {
    for (const e of G.effects.heroHealthBonus) {
      if (e.heroId === hero.id) hp += e.amount;
    }
  }
  const pid = G.adventure?.playerId;
  if (G.effects.staffHealingPids?.some((id) => String(id) === String(pid))) hp += 2;
  const itemId = hero.item?.id;
  if (itemId === 'THK007') hp += 5; // Oversized Sword
  if (itemId === 'THK006') {
    const p = pid != null ? playerOf(G, pid) : null;
    if (p) hp += allActiveRooms(p.dungeon).filter(r => r && r.type === 'monster').length;
  }
  return hp;
}

export function isRoomDeactivated(G, playerId, roomIndex) {
  return G.effects.deactivatedRooms?.some(e => e.playerId === playerId && e.roomIndex === roomIndex) ?? false;
}

export function checkEndGame(G) {
  const players = Object.values(G.players);
  const alive = players.filter(p => !p.eliminated);
  if (!G.largeGame) {
    for (const p of alive) {
      if (totalWounds(p) >= 5 && !p.woundImmuneThisTurn) p.eliminated = true;
    }
  }
  const stillAlive = players.filter(p => !p.eliminated);
  const heroDecksEmpty = (G.decks?.heroes?.length || 0) === 0 && (G.decks?.epics?.length || 0) === 0;

  if (G.largeGame) {
    const scored = stillAlive.map((p) => ({
      p,
      pid: parseInt(Object.keys(G.players).find((id) => G.players[id] === p)),
      score: totalSouls(p) - totalWounds(p),
      souls: totalSouls(p),
    }));
    const maxSouls = Math.max(...scored.map((s) => s.souls), 0);
    if (maxSouls >= 10 || heroDecksEmpty) {
      scored.sort((a, b) => b.score - a.score || (a.p.boss?.xp || 0) - (b.p.boss?.xp || 0));
      return { gameOver: true, winner: scored[0]?.pid ?? null };
    }
    return { gameOver: false, winner: null };
  }

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

  // Hero exhaustion safeguard: when all heroes have been drawn and no more can arrive or explore
  const noMoreHeroes = heroDecksEmpty && (G.decks?.heroDiscard?.length || 0) === 0
    && (G.town?.length || 0) === 0
    && stillAlive.every(p => (p.entrance?.length || 0) === 0)
    && !G.adventure;
  if (noMoreHeroes) {
    const scored = stillAlive.map((p) => ({
      pid: parseInt(Object.keys(G.players).find((id) => G.players[id] === p)),
      score: totalSouls(p) - totalWounds(p),
      xp: p.boss?.xp || 0,
    })).sort((a, b) => b.score - a.score || a.xp - b.xp);
    if (scored.length > 0) {
      return { gameOver: true, winner: scored[0].pid };
    }
  }

  return { gameOver: false, winner: null };
}

/** Flip a Wound face-down: it becomes a Soul (Vampire Bordello, Staff of Healing, etc.). */
export function healOneWound(player) {
  if (!player?.wounds?.length) return null;
  const w = player.wounds.pop();
  const soul = { souls: w.souls || 1, name: w.name, class: w.class, faceDown: true };
  player.souls = player.souls || [];
  player.souls.push(soul);
  return soul;
}
