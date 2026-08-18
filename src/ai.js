// ai.js - Rule-correct AI for Boss Monster.
//
// The AI uses the boardgame.io enumerate hook to provide legal moves for bot players.
// It evaluates board state and picks sensible actions:
//   - Build rooms that maximize treasure coverage, damage, or advance the dungeon.
//   - Cast spells when useful (Annihilator/Giant Size before a hero enters, etc.).
//   - Pass when no good action remains.

import { activeRoom, allActiveRooms, countVisibleRooms, dungeonTreasures, canBuildRoom } from './engine.js';
import { totalSouls, totalWounds, playerOrderByXP, SPELL_CATEGORY, PHASE } from './cardData.js';

export function aiChooseBoss(availableBosses) {
  return [...availableBosses].sort((a, b) => b.xp - a.xp)[0];
}

export function aiEnumerate(G, ctx, playerID) {
  if (!G || !G.players) return [];
  const pid = parseInt(playerID);
  const p = G.players[pid];
  const phase = (ctx && ctx.phase) || G.phase;
  const moves = [];

  if (!p || p.eliminated) return moves;

  // Only act when it's this AI's turn in sequential phases
  if ((phase === PHASE.SETUP || phase === PHASE.BUILD || phase === PHASE.ADVENTURE) && !isActivePlayer(G, pid)) {
    return moves;
  }

  if (phase === PHASE.BOSS) {
    const available = G.bossPicks.filter(b =>
      !Object.values(G.players).some(pl => pl.boss?.id === b.id)
    );
    if (available.length > 0) {
      moves.push({ move: 'pickBoss', args: [aiChooseBoss(available).id] });
    }
    return moves;
  }

  if (phase === PHASE.SETUP) {
    const idx = p.hand.findIndex(c => c.isRoom && !c.advanced);
    if (idx >= 0) moves.push({ move: 'buildInitialRoom', args: [idx] });
    return moves;
  }

  if (phase === PHASE.BUILD) {
    const buildAction = chooseBuild(G, pid);
    if (buildAction) moves.push(buildAction);
    const spellAction = chooseSpell(G, pid, phase);
    if (spellAction) moves.push(spellAction);
    moves.push({ move: 'pass', args: [] });
    return moves;
  }

  if (phase === PHASE.BAIT) {
    const spellAction = chooseSpell(G, pid, phase);
    if (spellAction) moves.push(spellAction);
    moves.push({ move: 'pass', args: [] });
    return moves;
  }

  if (phase === PHASE.ADVENTURE) {
    const spellAction = chooseSpell(G, pid, phase);
    if (spellAction) moves.push(spellAction);
    if (p.entrance.length > 0) {
      moves.push({ move: 'resolveNextHero', args: [] });
    } else {
      // No heroes to resolve — pass to advance the phase.
      moves.push({ move: 'pass', args: [] });
    }
    return moves;
  }

  return moves;
}

function isActivePlayer(G, pid) {
  // The custom reducer sets G.activePlayer (a single number). boardgame.io used
  // to set G.currentOrder + G.currentIndex; fall back to those for any legacy
  // code path that still uses boardgame.io.
  if (G.activePlayer != null) return String(G.activePlayer) === String(pid);
  if (G.currentOrder && G.currentOrder.length) return G.currentOrder[G.currentIndex] === pid;
  return true;
}

function chooseBuild(G, pid) {
  const p = G.players[pid];
  if (countVisibleRooms(p.dungeon) >= 5) return null;
  if (p.buildsThisTurn >= 1 + (G.effects.extraBuild?.filter(id => id === pid).length || 0)) return null;

  // Find all buildable rooms and target indices
  const candidates = [];
  for (let hi = 0; hi < p.hand.length; hi++) {
    const card = p.hand[hi];
    if (!card || !card.isRoom) continue;

    if (card.advanced) {
      // Can only build over an existing stack with matching treasure
      for (let ti = 0; ti < p.dungeon.length; ti++) {
        if (canBuildRoom(G, pid, hi, ti)) candidates.push({ handIndex: hi, targetIndex: ti, card });
      }
    } else {
      // Ordinary: append new stack or build over existing stack
      const visible = countVisibleRooms(p.dungeon);
      if (visible < 5) candidates.push({ handIndex: hi, targetIndex: null, card });
      for (let ti = 0; ti < p.dungeon.length; ti++) {
        if (canBuildRoom(G, pid, hi, ti)) candidates.push({ handIndex: hi, targetIndex: ti, card });
      }
    }
  }

  if (candidates.length === 0) return null;

  // Score candidates
  const scored = candidates.map(c => {
    const { card, targetIndex } = c;
    let score = 0;
    // Prefer rooms with damage
    score += (card.damage || 0) * 2;
    // Prefer advanced rooms that improve dungeon
    if (card.advanced) score += 5;
    // Prefer covering gaps where treasure is weak
    const currentTreasures = dungeonTreasures(G, pid);
    for (const t of card.treasures || []) {
      if (!currentTreasures.includes(t)) score += 3;
    }
    // Prefer building toward 5 rooms for level up
    const newVisible = countVisibleRooms(p.dungeon) + (targetIndex === null ? 1 : 0);
    if (newVisible >= 5 && !p.leveledUp) score += 20;
    else if (newVisible >= 4) score += 5;
    return { ...c, score };
  });

  scored.sort((a, b) => b.score - a.score);
  const best = scored[0];
  return { move: 'buildRoom', args: [best.handIndex, best.targetIndex] };
}

function chooseSpell(G, pid, phase) {
  const p = G.players[pid];
  const spells = p.hand
    .map((c, i) => ({ c, i }))
    .filter(({ c }) => c.isSpell && spellAllowedInPhaseLocal(c.category, phase));
  if (spells.length === 0) return null;

  // Score each spell based on situation
  const scored = spells.map(({ c, i }) => {
    let score = 0;
    let target = null;

    switch (c.id) {
      case 'BMA040': // Annihilator: +3 to trap room if heroes incoming
        target = bestRoomTarget(G, pid, 'trap');
        if (target != null && G.players[pid].entrance.length > 0) score = 10;
        break;
      case 'BMA047': // Giant Size: +3 to monster room if heroes incoming
        target = bestRoomTarget(G, pid, 'monster');
        if (target != null && G.players[pid].entrance.length > 0) score = 10;
        break;
      case 'BMA042': // Cave-In: destroy a low-value room
        target = worstRoomTarget(G, pid);
        if (target != null) score = 6;
        break;
      case 'BMA046': // Freeze: deactivate opponent's strong room before adventure
        target = bestOpponentRoomToDeactivate(G, pid);
        if (target != null) score = 8;
        break;
      case 'BMA050': // Motivation: extra build if behind
        const myRooms = countVisibleRooms(p.dungeon);
        const behind = Object.values(G.players).some(op => !op.eliminated && op !== p && countVisibleRooms(op.dungeon) > myRooms);
        if (behind) score = 7;
        break;
      case 'BMA051': // Princess in Peril: pull a hero if town has matching treasure
        if (G.town.length > 0 && p.dungeon.length > 0) {
          const hero = G.town.find(h => {
            const treasures = dungeonTreasures(G, pid);
            return treasures.includes(h.treasure);
          });
          if (hero) { target = { townIndex: G.town.indexOf(hero) }; score = 9; }
        }
        break;
      case 'BMA052': // Soul Harvest: remove soul for 2 spells if hand is low
        if (p.souls.length > 0 && p.hand.length < 4) score = 5;
        break;
      case 'BMA054': // Trepidation: block leader
        const leader = Object.values(G.players)
          .filter(op => !op.eliminated && op !== p)
          .sort((a, b) => totalSouls(b) - totalSouls(a))[0];
        if (leader && totalSouls(leader) >= totalSouls(p) + 2) score = 8;
        break;
      default:
        break;
    }
    return { i, score, target };
  }).filter(s => s.score > 0);

  if (scored.length === 0) return null;
  scored.sort((a, b) => b.score - a.score);
  const best = scored[0];
  return { move: 'playSpell', args: [best.i, best.target] };
}

function bestRoomTarget(G, pid, type) {
  const p = G.players[pid];
  let best = null;
  let bestDmg = -1;
  for (let i = 0; i < p.dungeon.length; i++) {
    const room = activeRoom(p.dungeon[i]);
    if (!room || room.type !== type) continue;
    if ((room.damage || 0) > bestDmg) {
      bestDmg = room.damage || 0;
      best = i;
    }
  }
  return best != null ? { roomIndex: best } : null;
}

function worstRoomTarget(G, pid) {
  const p = G.players[pid];
  let worst = null;
  let worstScore = Infinity;
  for (let i = 0; i < p.dungeon.length; i++) {
    const room = activeRoom(p.dungeon[i]);
    if (!room) continue;
    const score = (room.damage || 0) + (room.treasures?.length || 0) * 2;
    if (score < worstScore) {
      worstScore = score;
      worst = i;
    }
  }
  return worst != null ? { roomIndex: worst } : null;
}

function bestOpponentRoomToDeactivate(G, pid) {
  let best = null;
  let bestDmg = -1;
  for (const [opid, op] of Object.entries(G.players)) {
    if (parseInt(opid) === pid || op.eliminated) continue;
    for (let i = 0; i < op.dungeon.length; i++) {
      const room = activeRoom(op.dungeon[i]);
      if (!room) continue;
      if ((room.damage || 0) > bestDmg && op.entrance.length > 0) {
        bestDmg = room.damage || 0;
        best = { targetPlayerId: parseInt(opid), roomIndex: i };
      }
    }
  }
  return best;
}

function spellAllowedInPhaseLocal(category, phase) {
  if (category === SPELL_CATEGORY.ANY) return true;
  if (category === SPELL_CATEGORY.BUILD_BAIT) return phase === PHASE.BUILD || phase === PHASE.BAIT;
  if (category === SPELL_CATEGORY.ADVENTURE_BUILD) return phase === PHASE.ADVENTURE || phase === PHASE.BUILD;
  if (category === SPELL_CATEGORY.BUILD) return phase === PHASE.BUILD;
  if (category === SPELL_CATEGORY.BAIT) return phase === PHASE.BAIT;
  if (category === SPELL_CATEGORY.ADVENTURE) return phase === PHASE.ADVENTURE;
  return false;
}

export function aiSetupBuild(G, ctx, pid) {
  const p = G.players[pid];
  const basic = p.hand.findIndex(c => c.isRoom && !c.advanced);
  if (basic >= 0) {
    return { move: 'buildInitialRoom', args: [basic] };
  }
  return null;
}
