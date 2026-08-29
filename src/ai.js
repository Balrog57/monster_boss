// ai.js - Rule-correct AI for Boss Monster (solo mode).
import { activeRoom, countVisibleRooms, dungeonTreasures } from './engine.js';
import { PHASE, canPlaySpell } from './cardData.js';
import { legalMoves } from '../server/reducer.js';

export function aiChooseBoss(availableBosses) {
  return [...availableBosses].sort((a, b) => b.xp - a.xp)[0];
}

/** Pick the best legal move for a bot player. */
export function aiPickMove(G, ctx, playerID) {
  const moves = legalMoves(G, ctx, playerID);
  if (!moves.length) return null;

  let best = moves[0];
  let bestScore = scoreMove(G, ctx, Number(playerID), moves[0]);
  for (let i = 1; i < moves.length; i++) {
    const sc = scoreMove(G, ctx, Number(playerID), moves[i]);
    if (sc > bestScore) {
      bestScore = sc;
      best = moves[i];
    }
  }
  return best;
}

function scoreMove(G, ctx, pid, move) {
  const p = G.players[pid];
  const phase = ctx?.phase || G.phase;

  switch (move.type) {
    case 'pickBoss': {
      const boss = G.bossPicks.find(b => b.id === move.args[0]);
      return boss ? boss.xp * 10 : 0;
    }
    case 'buildInitialRoom':
    case 'buildRoom': {
      const card = p.hand[move.args[0]];
      if (!card) return 0;
      let score = (card.damage || 0) * 2;
      if (card.advanced) score += 5;
      const treasures = dungeonTreasures(G, pid);
      for (const t of card.treasures || []) {
        if (!treasures.includes(t)) score += 3;
      }
      const newVisible = countVisibleRooms(p.dungeon) + (move.args[1] == null ? 1 : 0);
      if (newVisible >= 5 && !p.leveledUp) score += 25;
      return score;
    }
    case 'playSpell': {
      const card = p.hand[move.args[0]];
      const target = move.args[1];
      if (!card) return 0;
      return scoreSpell(G, pid, phase, card, target);
    }
    case 'activateRoom':
      return scoreActivate(G, pid, move.args[0], move.args[1]);
    case 'resolveNextHero':
      return G.adventure && Number(G.adventure.playerId) === pid ? 5 : 8;
    case 'openingDiscard':
      return 1;
    case 'resolveLevelUpChoice':
      return 1;
    case 'pass':
      return -1;
    default:
      return 0;
  }
}

function scoreSpell(G, pid, phase, card, target) {
  const p = G.players[pid];
  if (!canPlaySpell(card, phase, G.stack?.length || 0)) return 0;

  switch (card.id) {
    case 'BMA040':
    case 'BMA047':
      return p.entrance.length > 0 && target?.roomIndex != null ? 10 : 0;
    case 'BMA042':
      return target?.roomIndex != null ? 6 : 0;
    case 'BMA044':
      return target?.heroId != null ? 7 : 0;
    case 'BMA046':
      return target?.roomIndex != null ? 8 : 0;
    case 'BMA050': {
      const myRooms = countVisibleRooms(p.dungeon);
      const behind = Object.values(G.players).some(op => !op.eliminated && op !== p && countVisibleRooms(op.dungeon) > myRooms);
      return behind ? 7 : 0;
    }
    case 'BMA051':
      return target?.townIndex != null ? 9 : 0;
    case 'BMA052':
      return target?.soulIndex != null && p.hand.length < 4 ? 5 : 0;
    case 'BMA054':
      return target?.targetPlayerId != null ? 8 : 0;
    case 'BMA055':
      return target?.soulIndex != null || target?.targetPlayerId != null ? 7 : 0;
    case 'BMA041':
      return target?.heroId != null ? 6 : 0;
    case 'BMA045':
      return target?.heroId != null ? 5 : 0;
    case 'BMA043':
      return G.stack?.length ? 12 : 0;
    default:
      return target == null ? 2 : 0;
  }
}

function scoreActivate(G, pid, roomIndex, otherIndex) {
  const p = G.players[pid];
  const room = activeRoom(p.dungeon[roomIndex]);
  if (!room) return -20;
  if (room.id === 'BMA027' && G.adventure && Number(G.adventure.playerId) === Number(pid)) return 9;
  if (room.id === 'BMA028' && otherIndex != null && G.adventure && Number(G.adventure.playerId) === Number(pid)) return 8;
  if (room.id === 'BMA025' && G.stack?.length) return 11;
  if (room.id === 'BMA024' && G.phase === PHASE.BUILD) return 4;
  if (room.id === 'THK021' && (G.townItems || []).length) return 6;
  if (room.id === 'THK022' || room.id === 'THK023') return 5;
  if (room.id === 'BMA009' && (G.decks.roomDiscard?.length || G.decks.spellDiscard?.length)) return 2;
  // Destroying your own rooms is usually worse than passing.
  return -8;
}

/** Legacy enumerate hook — returns scored moves for compatibility. */
export function aiEnumerate(G, ctx, playerID) {
  const pick = aiPickMove(G, ctx, playerID);
  if (!pick) return [];
  return [{ move: pick.type, args: pick.args }];
}

export function aiSetupBuild(G, ctx, pid) {
  const p = G.players[pid];
  const basic = p.hand.findIndex(c => c.isRoom && !c.advanced);
  if (basic >= 0) {
    return { move: 'buildInitialRoom', args: [basic] };
  }
  return null;
}
