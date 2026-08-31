// Generic handlers for expansion cards tagged from wiki descriptions.
import { activeRoom, destroyRoom, healOneWound } from './engine.js';
import { drawCards } from './cardData.js';
import { gainCoin } from './minibosses.js';

function player(G, playerId) {
  return G.players[playerId] ?? G.players[String(playerId)];
}

function countFromText(text, kind) {
  const d = (text || '').toLowerCase();
  if (kind === 'coin') {
    const explicit = d.match(/gain (\d+) coins?/);
    if (explicit) return Number(explicit[1]);
    const icons = (text || '').match(/\(c\)/gi);
    if (icons?.length) return icons.length;
    if (/gain (a |one |1 )coin/.test(d) || /gain \(c\)/.test(d)) return 1;
    if (/two coins?/.test(d)) return 2;
    return 0;
  }
  const m = d.match(new RegExp(`draw (\\d+|a|one|two|three) ${kind}`));
  if (!m) return 0;
  if (m[1] === 'a' || m[1] === 'one') return 1;
  if (m[1] === 'two') return 2;
  if (m[1] === 'three') return 3;
  return Number(m[1]) || 1;
}

export function applyTaggedOnBuild(G, playerId, room) {
  const p = player(G, playerId);
  if (!p || !room) return;
  const name = room.name || room.id;
  const desc = room.description || '';

  const coins = room.gainCoin || countFromText(desc, 'coin');
  if (coins > 0 && (room.gainCoin || /when you build/i.test(desc))) {
    gainCoin(G, playerId, coins, name);
  }
  if (room.onBuildDrawRoom) {
    const card = G.decks.rooms.pop();
    if (card) {
      p.hand.push(card);
      G.logs.push(`${name}: drew ${card.name}.`);
    }
  }
  if (room.onBuildDrawSpell) {
    const card = G.decks.spells.pop();
    if (card) {
      p.hand.push(card);
      G.logs.push(`${name}: drew ${card.name}.`);
    }
  }
  if (room.onBuildHealWound) {
    const soul = healOneWound(p);
    if (soul) G.logs.push(`${name}: healed a Wound.`);
  }
  if (room.onBuildExtraBuild) {
    p.buildsThisTurn = Math.max(0, (p.buildsThisTurn || 0) - 1);
    G.logs.push(`${name}: may build an additional Room this turn.`);
  }
}

export function applyTaggedOnHeroDie(G, ctx, playerId, room) {
  const p = player(G, playerId);
  if (!p || !room) return;
  const name = room.name || room.id;

  if (room.onHeroDieDrawSpell) {
    const card = G.decks.spells.pop();
    if (card) {
      p.hand.push(card);
      G.logs.push(`${name}: drew ${card.name}.`);
    }
  }
  if (room.onHeroDieDrawRoom) {
    const card = G.decks.rooms.pop();
    if (card) {
      p.hand.push(card);
      G.logs.push(`${name}: drew ${card.name}.`);
    }
  }
  if (room.onHeroDieHealWound) {
    const soul = healOneWound(p);
    if (soul) G.logs.push(`${name}: healed a Wound.`);
  }
}

export function applyTaggedOnHeroDeathDestroy(G, playerId, roomIndex, room) {
  if (!room?.destroyOnHeroDie || roomIndex < 0) return;
  destroyRoom(G, playerId, roomIndex);
  G.logs.push(`${room.name}: destroyed after a Hero died.`);
}

export function applyTaggedOnHeroSurvive(G, playerId, roomIndex, room) {
  if (!room?.destroyOnHeroSurvive || roomIndex < 0) return;
  destroyRoom(G, playerId, roomIndex);
  G.logs.push(`${room.name}: destroyed after a Hero survived.`);
}

export function applyGenericSpell(G, ctx, casterId, card, target) {
  const p = player(G, casterId);
  if (!p || !card?.description) return false;
  const d = card.description.toLowerCase();
  const t = target || {};

  const spellN = countFromText(card.description, 'spell');
  if (spellN > 0 && d.includes('draw')) {
    const drawn = drawCards(G.decks.spells, spellN);
    p.hand.push(...drawn);
    G.logs.push(`${card.name}: drew ${drawn.length} Spell(s).`);
    return true;
  }

  const roomN = countFromText(card.description, 'room');
  if (roomN > 0 && d.includes('draw')) {
    const drawn = drawCards(G.decks.rooms, roomN);
    p.hand.push(...drawn);
    G.logs.push(`${card.name}: drew ${drawn.length} Room(s).`);
    return true;
  }

  const coins = countFromText(card.description, 'coin');
  if (coins > 0 && d.includes('gain')) {
    gainCoin(G, casterId, coins, card.name);
    return true;
  }

  if (/heal a wound/.test(d)) {
    const soul = healOneWound(p);
    G.logs.push(soul ? `${card.name}: healed a Wound.` : `${card.name}: no Wounds to heal.`);
    return true;
  }

  if (d.includes('destroy a room') && t.roomIndex != null && t.targetPlayerId != null) {
    const ri = Number(t.roomIndex);
    const tid = t.targetPlayerId;
    const stack = player(G, tid)?.dungeon?.[ri];
    if (stack?.length) {
      const r = activeRoom(stack);
      destroyRoom(G, tid, ri);
      G.logs.push(`${card.name}: destroyed ${r?.name || 'a Room'}.`);
      return true;
    }
  }

  return false;
}

export function applyTaggedLevelUp(G, playerId, boss) {
  const p = player(G, playerId);
  const desc = boss?.levelUpDesc || '';
  if (!p || !desc || /boss\]\]/i.test(desc)) return false;
  const name = boss.name || boss.id;
  const d = desc.toLowerCase();

  const spellN = countFromText(desc, 'spell');
  if (spellN > 0 && d.includes('draw')) {
    const drawn = drawCards(G.decks.spells, spellN);
    p.hand.push(...drawn);
    G.logs.push(`${name} level up: drew ${drawn.length} Spell(s).`);
    return true;
  }

  const roomN = countFromText(desc, 'room');
  if (roomN > 0 && d.includes('draw')) {
    const drawn = drawCards(G.decks.rooms, roomN);
    p.hand.push(...drawn);
    G.logs.push(`${name} level up: drew ${drawn.length} Room(s).`);
    return true;
  }

  if (/heal a wound/.test(d)) {
    const soul = healOneWound(p);
    G.logs.push(soul ? `${name} level up: healed a Wound.` : `${name} level up: no Wounds to heal.`);
    return true;
  }

  if (/\+1 soul/.test(d) || /one additional soul/.test(d)) {
    p.bonusSouls = (p.bonusSouls || 0) + 1;
    G.logs.push(`${name} level up: +1 Soul for the rest of the game.`);
    return true;
  }

  if (/double (your )?treasure/.test(d)) {
    G.effects.treasureDoubled = G.effects.treasureDoubled || [];
    G.effects.treasureDoubled.push(Number(playerId));
    G.logs.push(`${name} level up: treasures doubled until end of turn.`);
    return true;
  }

  if (/last room.*\+3/.test(d) || /\+3.*last room/.test(d)) {
    p.scytheBoost = true;
    G.logs.push(`${name} level up: last room +3 damage.`);
    return true;
  }

  return false;
}
