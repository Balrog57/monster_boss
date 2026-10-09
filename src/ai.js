// ai.js - Rule-correct AI for Boss Monster (solo mode).
import { activeRoom, countVisibleRooms, dungeonTreasures, resolveBait } from './engine.js';
import { PHASE, canPlaySpell } from './cardData.js';
import { legalMoves } from '../server/reducer.js';

export function aiChooseBoss(availableBosses) {
  return [...availableBosses].sort((a, b) => b.xp - a.xp)[0];
}

/** Pick the best legal move for a bot player. */
export function aiPickMove(G, ctx, playerID) {
  const moves = legalMoves(G, ctx, playerID);
  if (!moves.length) return null;

  // Shared per-search memo: resolveBait is O(town x players) and docScarecrow
  // moves are (hand x town), so recomputing it per move would be quadratic.
  const memo = {};
  let best = moves[0];
  let bestScore = scoreMove(G, ctx, Number(playerID), moves[0], memo);
  for (let i = 1; i < moves.length; i++) {
    const sc = scoreMove(G, ctx, Number(playerID), moves[i], memo);
    if (sc > bestScore) {
      bestScore = sc;
      best = moves[i];
    }
  }
  return best;
}

/** Relative value of a hand card — used to pick the cheapest card to spend. */
function discardCost(card) {
  if (!card) return 9;
  if (card.isMiniboss) return 12; // a Miniboss in hand is a build, never fodder
  if (card.isRoom) {
    return (card.damage || 0) * 0.7 + (card.advanced ? 2.5 : 0) + (card.treasures?.length || 0) * 0.6;
  }
  if (card.isSpell) return 1.5;
  return 1;
}

function scoreMove(G, ctx, pid, move, memo = {}) {
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
      const turn = G.turn || 1;
      const isEarly = turn <= 1;
      const isMid = turn > 1 && turn <= 4;
      
      // Damage scoring aligned with APK RoomCalculator (scaled / 10)
      const dmg = card.damage || 0;
      let score = 0;
      if (isEarly) {
        score = [0, 2.5, 10, 15, 17.5, 20][Math.min(dmg, 5)] || (dmg * 4);
      } else if (isMid) {
        score = [0, 2.5, 7.5, 17.5, 20, 20][Math.min(dmg, 5)] || (dmg * 4);
      } else {
        score = [0, 2.5, 7.5, 17.5, 20, 20][Math.min(dmg, 5)] || (dmg * 4);
      }
      if (card.advanced) score += 5;

      // Build-over penalty aligned with APK CalculateBuildOverPenalty
      if (move.args[1] != null && p.dungeon[move.args[1]]) {
        const oldRoom = activeRoom(p.dungeon[move.args[1]]);
        if (oldRoom) {
          if (oldRoom.advanced) {
            score -= 30; // buildOverAdvancedPenalty
          } else if (!oldRoom.advanced && card.advanced) {
            score += 0; // Natural upgrade: 0 penalty
          } else {
            score -= (oldRoom.damage || 0) * 2;
          }
        }
      }

      const treasures = dungeonTreasures(G, pid);
      for (const t of card.treasures || []) {
        if (!treasures.includes(t)) score += (isEarly ? 1 : 3);
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
    case 'buildMiniboss':
      return 6;
    case 'promoteMiniboss':
      return 5;
    case 'activateMiniboss':
      return 8;
    case 'payDarkHero':
      return 7;
    case 'resolveNextHero':
      return G.adventure && Number(G.adventure.playerId) === pid ? 5 : 8;
    case 'openingDiscard':
      return 1;
    case 'resolveLevelUpChoice':
      return 1;
    case 'docScarecrow': {
      // Costs a card: only worth it when this specific Hero would be lured into
      // our dungeon this turn and our Rooms alone cannot kill it.
      const [handIdx, townIdx] = move.args || [];
      const card = p.hand[handIdx];
      const hero = G.town[townIdx];
      if (!card || !hero || hero.noLureThisTurn) return -10;
      if (!memo.bait) memo.bait = resolveBait(G);
      const incoming = memo.bait.find(a =>
        Number(a.targetPlayerId) === pid && !a.stayInTown && a.hero && a.hero.id === hero.id);
      if (!incoming) return -10;
      const hp = incoming.hero.hp ?? incoming.hero.wounds ?? 0;
      const ourDamage = (p.dungeon || []).reduce((s, st) => s + (activeRoom(st)?.damage || 0), 0);
      if (ourDamage >= hp) return -10; // we would kill it anyway
      return 6 - discardCost(card) * 0.5;
    }
    case 'timebenderCancel': {
      // Costs a Spell: only cancel when the top Spell on the stack targets us.
      const top = G.stack?.[G.stack.length - 1];
      if (!top || Number(top.playerId) === pid) return -10;
      const t = top.target || {};
      const us = [t.ownerId, t.playerId, t.targetPlayerId, t.dungeonId, t.adventureOwnerId]
        .some(v => v != null && Number(v) === pid);
      if (!us) return -10;
      const card = p.hand[move.args[0]];
      if (!card?.isSpell) return -10;
      return 11 - discardCost(card) * 0.5;
    }
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
    case 'BMA048': { // Jeopardy: everyone cycles hands — best with a small hand
      return p.hand.length <= 2 ? 4 : 1;
    }
    case 'BMA049': { // Kobold Strike: undo this turn's face-down builds — only when it hurts opponents, not us
      const hasFreshBuild = (pl) => (pl.dungeon || []).some((s) => {
        const r = activeRoom(s);
        return r?.faceDown && r?.builtThisTurn;
      });
      const oppBuilt = Object.entries(G.players).some(([oid, op]) => Number(oid) !== Number(pid) && !op.eliminated && hasFreshBuild(op));
      return oppBuilt && !hasFreshBuild(p) ? 6 : -2;
    }
    case 'BMA050': {
      const myRooms = countVisibleRooms(p.dungeon);
      const behind = Object.values(G.players).some(op => !op.eliminated && op !== p && countVisibleRooms(op.dungeon) > myRooms);
      return behind ? 7 : -2;
    }
    case 'BMA053': { // Teleportation: restart a hero at the first room (re-farm entries)
      return target?.heroId != null ? 1 : -2;
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
