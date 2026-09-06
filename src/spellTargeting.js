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
  BMA052: { type: 'own-soul', label: 'Choose a face-down Hero' },
  BMA053: { type: 'hero-own-dungeon', label: 'Choose a Hero in your dungeon' },
  BMA054: { type: 'trepidation-player', label: 'Choose a player with 2+ more Souls' },
  BMA055: { type: 'opponent-soul', label: 'Choose a dead Hero' },
  THK025: { type: 'any-item', label: 'Choose an Item to flip' },
  CRL201: { type: 'hero-town', label: 'Choose a Hero in town' },
  CRL029: { type: 'hero-any-dungeon', label: 'Choose a Hero to finish' },
  CRL030: { type: 'hero-opponent-dungeon', label: 'Choose a Hero in an opponent\'s dungeon' },
  CRL032: { type: 'any-room', label: 'Choose a Room' },
  TNL057: { type: 'hero-own-dungeon', label: 'Choose a Hero in your dungeon' },
  TNL058: { type: 'any-room', label: 'Choose a Room' },
  TNL059: { type: 'hero-own-dungeon', label: 'Choose a Hero in your dungeon' },
  TNL061: { type: 'hero-own-dungeon', label: 'Choose a Hero in your dungeon' },
  TNL062: { type: 'any-room', label: 'Choose a Room to silence' },
  TNL066: { type: 'hero-opponent-dungeon', label: 'Choose a Hero in an opponent\'s dungeon' },
  TNL067: { type: 'own-room', label: 'Choose a Room in your dungeon' },
  TNL068: { type: 'hero-any-dungeon', label: 'Choose a Hero to skip a Room' },
  TNL069: { type: 'own-room', label: 'Choose a Room in your dungeon' },
  RMB067: { type: 'any-room', label: 'Choose a Room' },
  RMB068: { type: 'any-room', label: 'Choose a Room to silence' },
  RMB072: { type: 'hero-own-dungeon', label: 'Choose a Hero in your dungeon' },
  RMB073: { type: 'own-room', label: 'Choose a Room in your dungeon' },
  RMB076: { type: 'any-room', label: 'Choose a Room' },
  RMB079: { type: 'hero-any-dungeon', label: 'Choose a Hero' },
  RMB070: { type: 'hero-own-dungeon', label: 'Choose a Hero in your dungeon' },
  RMB071: { type: 'any-player', label: 'Choose a player' },
  RMB078: { type: 'opponent-miniboss', label: "Choose an opponent's Miniboss" },
  TNL070: { type: 'surprise-gift', label: 'Choose a Room and an opponent Room' },
  TNL071: { type: 'undead-minion', label: 'Choose a face-down Hero and a Hero in your dungeon' },
  TNL072: { type: 'wild-monster', label: 'Choose a Monster Room and a target Room' },
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
        const advHeroId = G.adventure && Number(G.adventure.playerId) === Number(opid) ? G.adventure.hero?.id : null;
        for (const h of op.entrance) {
          targets.push({ heroId: h.id });
        }
        if (advHeroId && !op.entrance.some(h => h.id === advHeroId)) {
          targets.push({ heroId: advHeroId });
        }
      }
      break;
    case 'hero-own-dungeon': {
      const advHeroId = G.adventure && Number(G.adventure.playerId) === pid ? G.adventure.hero?.id : null;
      for (const h of me.entrance) {
        targets.push({ heroId: h.id });
      }
      if (advHeroId && !me.entrance.some(h => h.id === advHeroId)) {
        targets.push({ heroId: advHeroId });
      }
      break;
    }
    case 'hero-any-dungeon':
      for (const [opid, op] of Object.entries(G.players)) {
        if (op.eliminated) continue;
        const advHeroId = G.adventure && Number(G.adventure.playerId) === Number(opid) ? G.adventure.hero?.id : null;
        for (const h of op.entrance) {
          targets.push({ heroId: h.id });
        }
        if (advHeroId && !op.entrance.some(h => h.id === advHeroId)) {
          targets.push({ heroId: advHeroId });
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
    case 'any-player':
      for (const [opid, op] of Object.entries(G.players)) {
        if (op.eliminated) continue;
        targets.push({ targetPlayerId: Number(opid) });
      }
      break;
    case 'opponent-miniboss':
      for (const [opid, op] of Object.entries(G.players)) {
        if (Number(opid) === pid || op.eliminated) continue;
        (op.dungeon || []).forEach((stack, i) => {
          const mb = stack?.miniboss;
          if (mb && !mb.faceDown) {
            targets.push({ targetPlayerId: Number(opid), roomIndex: i });
          }
        });
      }
      break;
    case 'surprise-gift':
      me.hand.forEach((c, hi) => {
        if (!c.isRoom) return;
        for (const [opid, op] of Object.entries(G.players)) {
          if (Number(opid) === pid || op.eliminated) continue;
          (op.dungeon || []).forEach((stack, ri) => {
            const top = stackTop(stack);
            if (top && !top.faceDown) {
              targets.push({ handIndex: hi, targetPlayerId: Number(opid), roomIndex: ri });
            }
          });
        }
      });
      break;
    case 'undead-minion': {
      const souls = (me.souls || [])
        .map((s, i) => ({ s, i }))
        .filter(({ s }) => !s.tpk && s.faceDown !== false);
      const heroes = [];
      const advHeroId = G.adventure && Number(G.adventure.playerId) === pid ? G.adventure.hero?.id : null;
      for (const h of me.entrance || []) heroes.push(h.id);
      if (advHeroId) heroes.push(advHeroId);
      for (const { i: soulIndex } of souls) {
        for (const heroId of heroes) {
          targets.push({ soulIndex, heroId });
        }
      }
      break;
    }
    case 'wild-monster':
      me.hand.forEach((c, hi) => {
        if (!c.isRoom || c.type !== 'monster') return;
        me.dungeon.forEach((stack, ri) => {
          if (stackTop(stack)) targets.push({ handIndex: hi, roomIndex: ri });
        });
      });
      break;
    case 'trepidation-player': {
      const mySouls = (me.souls || []).reduce((s, x) => s + (x.souls || 1), 0);
      for (const [opid, op] of Object.entries(G.players)) {
        if (Number(opid) === pid || op.eliminated) continue;
        const theirs = (op.souls || []).reduce((s, x) => s + (x.souls || 1), 0);
        if (theirs >= mySouls + 2) targets.push({ targetPlayerId: Number(opid) });
      }
      break;
    }
    case 'own-soul':
      (me.souls || []).forEach((s, i) => {
        if (!s.tpk && s.faceDown !== false) targets.push({ soulIndex: i });
      });
      break;
    case 'opponent-soul':
      for (const [opid, op] of Object.entries(G.players)) {
        if (Number(opid) === pid || op.eliminated) continue;
        (op.souls || []).forEach((s, i) => {
          if (!s.tpk) targets.push({ targetPlayerId: Number(opid), soulIndex: i, pile: 'souls' });
        });
        (op.wounds || []).forEach((s, i) => {
          targets.push({ targetPlayerId: Number(opid), soulIndex: i, pile: 'wounds' });
        });
      }
      break;
    case 'any-item':
      for (const [opid, op] of Object.entries(G.players)) {
        (op.items || []).forEach((it, i) => {
          targets.push({ targetPlayerId: Number(opid), itemIndex: i });
        });
      }
      break;
    case 'swap-rooms':
      for (let i = 0; i < me.dungeon.length; i++) {
        for (let j = i + 1; j < me.dungeon.length; j++) {
          targets.push({ roomA: i, roomB: j });
        }
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
        const advHero = (G.adventure && Number(G.adventure.playerId) === Number(opid)) ? G.adventure.hero : null;
        if (advHero) {
          targets.push({
            key: `adv-${opid}-${advHero.id}`, card: advHero, kind: advHero.epic ? 'epic-hero' : 'hero',
            value: { heroId: advHero.id }, label: `${advHero.name} (in dungeon)`,
          });
        }
        for (const h of op.entrance) {
          if (advHero && h.id === advHero.id) continue;
          targets.push({
            key: `hero-${opid}-${h.id}`, card: h, kind: h.epic ? 'epic-hero' : 'hero',
            value: { heroId: h.id }, label: h.name,
          });
        }
      }
      break;
    case 'hero-own-dungeon': {
      const advHero = (G.adventure && Number(G.adventure.playerId) === pid) ? G.adventure.hero : null;
      if (advHero) {
        targets.push({
          key: `adv-${advHero.id}`, card: advHero, kind: advHero.epic ? 'epic-hero' : 'hero',
          value: { heroId: advHero.id }, label: `${advHero.name} (in dungeon)`,
        });
      }
      for (const h of me.entrance) {
        if (advHero && h.id === advHero.id) continue;
        targets.push({
          key: `hero-${h.id}`, card: h, kind: h.epic ? 'epic-hero' : 'hero',
          value: { heroId: h.id }, label: h.name,
        });
      }
      break;
    }
    case 'hero-any-dungeon':
      for (const [opid, op] of Object.entries(G.players)) {
        if (op.eliminated) continue;
        const advHero = (G.adventure && Number(G.adventure.playerId) === Number(opid)) ? G.adventure.hero : null;
        if (advHero) {
          targets.push({
            key: `adv-${opid}-${advHero.id}`, card: advHero, kind: advHero.epic ? 'epic-hero' : 'hero',
            value: { heroId: advHero.id }, label: `${advHero.name} (in dungeon)`,
          });
        }
        for (const h of op.entrance) {
          if (advHero && h.id === advHero.id) continue;
          targets.push({
            key: `hero-${opid}-${h.id}`, card: h, kind: h.epic ? 'epic-hero' : 'hero',
            value: { heroId: h.id }, label: h.name,
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
    case 'any-player':
      for (const [opid, op] of Object.entries(G.players)) {
        if (op.eliminated) continue;
        const you = Number(opid) === pid;
        targets.push({
          key: `pl-${opid}`, card: op.boss, kind: 'boss',
          value: { targetPlayerId: Number(opid) },
          label: you ? 'You' : (op.boss?.name || `Player ${opid}`),
        });
      }
      break;
    case 'opponent-miniboss':
      for (const [opid, op] of Object.entries(G.players)) {
        if (Number(opid) === pid || op.eliminated) continue;
        (op.dungeon || []).forEach((stack, i) => {
          const mb = stack?.miniboss;
          if (!mb || mb.faceDown) return;
          targets.push({
            key: `mb-${opid}-${i}`, card: mb.card, kind: 'room',
            value: { targetPlayerId: Number(opid), roomIndex: i },
            label: `${mb.card.name} L${mb.level} (P${opid})`,
          });
        });
      }
      break;
    case 'surprise-gift':
      me.hand.forEach((c, hi) => {
        if (!c.isRoom) return;
        for (const [opid, op] of Object.entries(G.players)) {
          if (Number(opid) === pid || op.eliminated) continue;
          (op.dungeon || []).forEach((stack, ri) => {
            const top = stackTop(stack);
            if (!top || top.faceDown) return;
            targets.push({
              key: `gift-${hi}-${opid}-${ri}`, card: c, kind: 'room',
              value: { handIndex: hi, targetPlayerId: Number(opid), roomIndex: ri },
              label: `${c.name} → ${top.name} (P${opid})`,
            });
          });
        }
      });
      break;
    case 'undead-minion': {
      const souls = (me.souls || [])
        .map((s, i) => ({ s, i }))
        .filter(({ s }) => !s.tpk && s.faceDown !== false);
      const heroes = [];
      const advHero = G.adventure && Number(G.adventure.playerId) === pid ? G.adventure.hero : null;
      for (const h of me.entrance || []) heroes.push(h);
      if (advHero && !heroes.some((h) => h.id === advHero.id)) heroes.push(advHero);
      for (const { s, i: soulIndex } of souls) {
        for (const h of heroes) {
          targets.push({
            key: `undead-${soulIndex}-${h.id}`, card: h, kind: h.epic ? 'epic-hero' : 'hero',
            value: { soulIndex, heroId: h.id },
            label: `${s.name || 'Soul'} → ${h.name}`,
          });
        }
      }
      break;
    }
    case 'wild-monster':
      me.hand.forEach((c, hi) => {
        if (!c.isRoom || c.type !== 'monster') return;
        me.dungeon.forEach((stack, ri) => {
          const top = stackTop(stack);
          if (!top) return;
          targets.push({
            key: `wild-${hi}-${ri}`, card: c, kind: 'room',
            value: { handIndex: hi, roomIndex: ri },
            label: `${c.name} over ${top.name}`,
          });
        });
      });
      break;
    case 'trepidation-player': {
      const mySouls = (me.souls || []).reduce((s, x) => s + (x.souls || 1), 0);
      for (const [opid, op] of Object.entries(G.players)) {
        if (Number(opid) === pid || op.eliminated) continue;
        const theirs = (op.souls || []).reduce((s, x) => s + (x.souls || 1), 0);
        if (theirs < mySouls + 2) continue;
        targets.push({
          key: `trep-${opid}`, card: op.boss, kind: 'boss',
          value: { targetPlayerId: Number(opid) },
          label: `${op.boss?.name || `Player ${opid}`} (${theirs} Souls)`,
        });
      }
      break;
    }
    case 'own-soul':
      (me.souls || []).forEach((s, i) => {
        if (s.tpk) return;
        targets.push({
          key: `soul-${i}`, card: { name: s.name || 'Hero', class: s.class, hp: 1 }, kind: 'hero',
          value: { soulIndex: i },
          label: s.name || 'Hero',
        });
      });
      break;
    case 'opponent-soul':
      for (const [opid, op] of Object.entries(G.players)) {
        if (Number(opid) === pid || op.eliminated) continue;
        (op.souls || []).forEach((s, i) => {
          if (s.tpk) return;
          targets.push({
            key: `osoul-${opid}-${i}`, card: { name: s.name || 'Hero', class: s.class, hp: 1 }, kind: 'hero',
            value: { targetPlayerId: Number(opid), soulIndex: i, pile: 'souls' },
            label: `${s.name || 'Hero'} (P${opid} soul)`,
          });
        });
        (op.wounds || []).forEach((s, i) => {
          targets.push({
            key: `owound-${opid}-${i}`, card: { name: s.name || 'Hero', class: s.class, hp: 1 }, kind: 'hero',
            value: { targetPlayerId: Number(opid), soulIndex: i, pile: 'wounds' },
            label: `${s.name || 'Hero'} (P${opid} wound)`,
          });
        });
      }
      break;
    case 'any-item':
      for (const [opid, op] of Object.entries(G.players)) {
        (op.items || []).forEach((it, i) => {
          const owner = Number(opid) === pid ? 'You' : `P${opid}`;
          targets.push({
            key: `item-${opid}-${i}`, card: it, kind: 'item',
            value: { targetPlayerId: Number(opid), itemIndex: i },
            label: `${it.name} (${owner}${it.faceDown ? ', face-down' : ''})`,
          });
        });
      }
      break;
    case 'swap-rooms':
      for (let i = 0; i < me.dungeon.length; i++) {
        for (let j = i + 1; j < me.dungeon.length; j++) {
          const a = stackTop(me.dungeon[i]);
          const b = stackTop(me.dungeon[j]);
          if (!a || !b) continue;
          targets.push({
            key: `swap-${i}-${j}`,
            card: a,
            kind: 'room',
            value: { roomA: i, roomB: j },
            label: `Swap ${a.name} ↔ ${b.name}`,
          });
        }
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
  if (spellId === 'RMB070') {
    const canPay = (player.hand || []).some((c) => c.isMiniboss)
      || (player.hand || []).filter((c) => c.isRoom && c.type === 'monster').length >= 2;
    if (!canPay) return [];
  }
  if (spellId === 'RMB078') {
    const targets = enumerateTargets(req.type, G, player, playerId);
    return targets.filter((t) => {
      const opp = G.players[t.targetPlayerId];
      const mb = opp?.dungeon?.[t.roomIndex]?.miniboss;
      const cost = mb?.level || 1;
      return (player.coins || 0) >= cost
        && (player.dungeon || []).some((s) => activeRoom(s) && !s.miniboss);
    });
  }
  return enumerateTargets(req.type, G, player, playerId);
}
