// spellTargeting.js - Spell target requirements shared by UI and legalMoves.
import { activeRoom } from './engine.js';

export const SPELL_TARGETS = {
  BMA040: { type: 'own-room-trap', label: 'Choose a Trap Room' },
  BMA041: { type: 'hero-opponent-dungeon', label: 'Choose a Hero in an opponent\'s dungeon' },
  BMA042: { type: 'own-room', label: 'Choose a room to destroy' },
  BMA044: { type: 'hero-own-dungeon', label: 'Choose a Hero in your dungeon' },
  BMA045: { type: 'hero-any-dungeon', label: 'Choose a Hero to send back to town' },
  BMA046: { type: 'any-room', label: 'Choose a room to deactivate' },
  BMA047: { type: 'own-room-monster', label: 'Choose a Monster Room' },
  BMA051: { type: 'hero-town', label: 'Choose a Hero in town' },
  BMA053: { type: 'hero-own-dungeon', label: 'Choose a Hero in your dungeon' },
  BMA055: { type: 'opponent', label: 'Choose an opponent' },
};

export function spellNeedsTarget(spellId) {
  return !!SPELL_TARGETS[spellId];
}

function stackTop(stack) {
  return Array.isArray(stack) ? stack[stack.length - 1] : stack;
}

/** Raw target objects for reducer moves: { roomIndex, heroId, townIndex, targetPlayerId } */
export function enumerateTargets(type, G, me, playerId) {
  const targets = [];
  const pid = Number(playerId);

  switch (type) {
    case 'own-room':
      me.dungeon.forEach((stack, i) => {
        if (stackTop(stack)) targets.push({ roomIndex: i });
      });
      break;
    case 'own-room-trap':
      me.dungeon.forEach((stack, i) => {
        const r = stackTop(stack);
        if (r && r.type === 'trap') targets.push({ roomIndex: i });
      });
      break;
    case 'own-room-monster':
      me.dungeon.forEach((stack, i) => {
        const r = stackTop(stack);
        if (r && r.type === 'monster') targets.push({ roomIndex: i });
      });
      break;
    case 'any-room':
      for (const [opid, op] of Object.entries(G.players)) {
        op.dungeon.forEach((stack, i) => {
          if (stackTop(stack)) {
            targets.push({ targetPlayerId: Number(opid), roomIndex: i });
          }
        });
      }
      break;
    case 'hero-opponent-dungeon':
      for (const [opid, op] of Object.entries(G.players)) {
        if (Number(opid) === pid || op.eliminated) continue;
        for (const h of op.entrance) {
          targets.push({ heroId: h.id });
        }
        if (G.adventure && Number(G.adventure.playerId) === Number(opid) && G.adventure.hero) {
          targets.push({ heroId: G.adventure.hero.id });
        }
      }
      break;
    case 'hero-own-dungeon':
      for (const h of me.entrance) {
        targets.push({ heroId: h.id });
      }
      if (G.adventure && Number(G.adventure.playerId) === pid && G.adventure.hero) {
        targets.push({ heroId: G.adventure.hero.id });
      }
      break;
    case 'hero-any-dungeon':
      for (const [opid, op] of Object.entries(G.players)) {
        for (const h of op.entrance) {
          targets.push({ heroId: h.id });
        }
        if (G.adventure && Number(G.adventure.playerId) === Number(opid) && G.adventure.hero) {
          targets.push({ heroId: G.adventure.hero.id });
        }
      }
      break;
    case 'hero-town':
      G.town.forEach((_, i) => targets.push({ townIndex: i }));
      break;
    case 'opponent':
      for (const [opid, op] of Object.entries(G.players)) {
        if (Number(opid) === pid || op.eliminated) continue;
        targets.push({ targetPlayerId: Number(opid) });
      }
      break;
    default:
      break;
  }
  return targets;
}

/** UI-friendly targets with cards and labels. */
export function getSpellTargetOptions(type, G, me, playerId) {
  const pid = Number(playerId);
  const targets = [];

  switch (type) {
    case 'own-room':
    case 'own-room-trap':
    case 'own-room-monster': {
      const filter = type === 'own-room-trap' ? 'trap' : type === 'own-room-monster' ? 'monster' : null;
      me.dungeon.forEach((stack, i) => {
        const r = stackTop(stack);
        if (!r || (filter && r.type !== filter)) return;
        targets.push({
          key: `room-${i}`, card: r, kind: 'room',
          value: { roomIndex: i }, label: r.name,
        });
      });
      break;
    }
    case 'any-room':
      for (const [opid, op] of Object.entries(G.players)) {
        op.dungeon.forEach((stack, i) => {
          const r = stackTop(stack);
          if (!r) return;
          const owner = Number(opid) === pid ? 'You' : `P${opid}`;
          targets.push({
            key: `room-${opid}-${i}`, card: r, kind: 'room',
            value: { targetPlayerId: Number(opid), roomIndex: i },
            label: `${r.name} (${owner})`,
          });
        });
      }
      break;
    case 'hero-opponent-dungeon':
      for (const [opid, op] of Object.entries(G.players)) {
        if (Number(opid) === pid || op.eliminated) continue;
        for (const h of op.entrance) {
          targets.push({
            key: `hero-${opid}-${h.id}`, card: h, kind: h.epic ? 'epic-hero' : 'hero',
            value: { heroId: h.id }, label: h.name,
          });
        }
        if (G.adventure && Number(G.adventure.playerId) === Number(opid) && G.adventure.hero) {
          const h = G.adventure.hero;
          targets.push({
            key: `adv-${opid}-${h.id}`, card: h, kind: h.epic ? 'epic-hero' : 'hero',
            value: { heroId: h.id }, label: `${h.name} (in dungeon)`,
          });
        }
      }
      break;
    case 'hero-own-dungeon':
      for (const h of me.entrance) {
        targets.push({
          key: `hero-${h.id}`, card: h, kind: h.epic ? 'epic-hero' : 'hero',
          value: { heroId: h.id }, label: h.name,
        });
      }
      if (G.adventure && Number(G.adventure.playerId) === pid && G.adventure.hero) {
        const h = G.adventure.hero;
        targets.push({
          key: `adv-${h.id}`, card: h, kind: h.epic ? 'epic-hero' : 'hero',
          value: { heroId: h.id }, label: `${h.name} (in dungeon)`,
        });
      }
      break;
    case 'hero-any-dungeon':
      for (const [opid, op] of Object.entries(G.players)) {
        for (const h of op.entrance) {
          targets.push({
            key: `hero-${opid}-${h.id}`, card: h, kind: h.epic ? 'epic-hero' : 'hero',
            value: { heroId: h.id }, label: h.name,
          });
        }
        if (G.adventure && Number(G.adventure.playerId) === Number(opid) && G.adventure.hero) {
          const h = G.adventure.hero;
          targets.push({
            key: `adv-${opid}-${h.id}`, card: h, kind: h.epic ? 'epic-hero' : 'hero',
            value: { heroId: h.id }, label: `${h.name} (in dungeon)`,
          });
        }
      }
      break;
    case 'hero-town':
      G.town.forEach((h, i) => {
        targets.push({
          key: `town-${i}`, card: h, kind: h.epic ? 'epic-hero' : 'hero',
          value: { townIndex: i }, label: h.name,
        });
      });
      break;
    case 'opponent':
      for (const [opid, op] of Object.entries(G.players)) {
        if (Number(opid) === pid || op.eliminated) continue;
        targets.push({
          key: `opp-${opid}`, card: op.boss, kind: 'boss',
          value: { targetPlayerId: Number(opid) },
          label: op.boss?.name || `Player ${opid}`,
        });
      }
      break;
    default:
      break;
  }
  return targets;
}

export function spellTargetsFor(G, player, playerId, spellId) {
  const req = SPELL_TARGETS[spellId];
  if (!req) return [null];
  return enumerateTargets(req.type, G, player, playerId);
}
