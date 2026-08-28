// items.js - Tools of Hero-Kind: town attach, power-ups, rewards, room locks.
import { activeRoom, destroyRoom } from './engine.js';
import { drawCards } from './cardData.js';

/** Official: 1 Item (2 in a 4-player game) when Heroes are revealed. */
export function itemRevealCount(numPlayers) {
  return Number(numPlayers) >= 4 ? 2 : 1;
}

export function heroIgnoresRoomAbilities(hero) {
  return hero?.id === 'KSA017' || hero?.item?.id === 'THK014';
}

/** Trap Master / Cheat Code in this dungeon (entrance or currently resolving). */
export function dungeonIgnoresRoomAbilities(G, playerId) {
  const p = G.players[playerId] ?? G.players[String(playerId)];
  if (!p) return false;
  if ((p.entrance || []).some(heroIgnoresRoomAbilities)) return true;
  if (G.adventure && String(G.adventure.playerId) === String(playerId) && heroIgnoresRoomAbilities(G.adventure.hero)) {
    return true;
  }
  if (G.effects?.ignoreAbilityPids?.some((id) => String(id) === String(playerId))) return true;
  return false;
}

/** Ring of Invisibility: no spells while the hero is at the entrance or in the dungeon. */
export function spellsBlockedFor(G, playerId) {
  const p = G.players[playerId] ?? G.players[String(playerId)];
  if (!p) return false;
  if ((p.entrance || []).some((h) => h.item?.id === 'THK020')) return true;
  if (G.adventure && String(G.adventure.playerId) === String(playerId) && G.adventure.hero?.item?.id === 'THK020') {
    return true;
  }
  return false;
}

function oldestHeroWithoutItem(town, treasure) {
  if (!Array.isArray(town)) return null;
  if (treasure === 0) return town.find((h) => !h.item) || null;
  return town.find((h) => !h.item && h.treasure === treasure) || null;
}

/** Attach a newly revealed Item, or leave it unattached in town. */
export function tryAttachRevealedItem(G, item) {
  const hero = oldestHeroWithoutItem(G.town, item.treasure ?? 0);
  if (!hero) {
    G.townItems.push(item);
    return false;
  }
  hero.item = item;
  G.logs.push(`${item.name} attaches to ${hero.name}`);
  return true;
}

/** When a Hero arrives in town, attach a matching (or Universal) unattached Item. */
export function tryAttachItemsToHero(G, hero) {
  if (!hero || hero.item) return;
  const items = G.townItems || [];
  let idx = items.findIndex((it) => it.treasure === hero.treasure);
  if (idx < 0) idx = items.findIndex((it) => it.treasure === 0);
  if (idx < 0) return;
  const item = items.splice(idx, 1)[0];
  hero.item = item;
  G.logs.push(`${item.name} attaches to ${hero.name}`);
}

function deactivateFirstOfType(G, playerId, type, label) {
  const p = G.players[playerId] ?? G.players[String(playerId)];
  if (!p) return;
  G.effects.deactivatedRooms = G.effects.deactivatedRooms || [];
  for (let i = 0; i < p.dungeon.length; i++) {
    const room = activeRoom(p.dungeon[i]);
    if (room && room.type === type && !G.effects.deactivatedRooms.some((e) => String(e.playerId) === String(playerId) && e.roomIndex === i)) {
      G.effects.deactivatedRooms.push({ playerId, roomIndex: i });
      G.logs.push(`${label}: ${room.name} deactivated.`);
      return;
    }
  }
}

function otherPlayers(G, pid) {
  const n = Number(pid);
  return Object.keys(G.players)
    .map(Number)
    .filter((id) => id !== n && !G.players[id]?.eliminated);
}

function discardRandomOfKind(player, decks, kind, n, logName) {
  const logs = [];
  for (let k = 0; k < n; k++) {
    const idxs = player.hand.map((c, i) => ((kind === 'room' ? c.isRoom : c.isSpell) ? i : -1)).filter((i) => i >= 0);
    if (!idxs.length) break;
    const pick = idxs[Math.floor(Math.random() * idxs.length)];
    const card = player.hand.splice(pick, 1)[0];
    if (kind === 'room') decks.roomDiscard.push(card);
    else decks.spellDiscard.push(card);
    logs.push(card.name);
  }
  return logs;
}

/** Power-ups that fire when the Hero first enters the dungeon. */
export function applyHeroEnterDungeon(G, playerId, hero) {
  const itemId = hero?.item?.id;
  const p = G.players[playerId] ?? G.players[String(playerId)];
  if (!p || !itemId) return;

  if (itemId === 'THK011' && p.dungeon.length > 1) {
    p.dungeon.reverse();
    G.logs.push(`Magic Mirror: ${p.boss?.name || 'dungeon'} rooms reversed.`);
  }
  if (itemId === 'THK015') deactivateFirstOfType(G, playerId, 'trap', 'Ten Foot Pole');
  if (itemId === 'THK018') deactivateFirstOfType(G, playerId, 'monster', 'Pet Monster');
  if (itemId === 'THK004') {
    G.effects.staffHealingPids = G.effects.staffHealingPids || [];
    G.effects.staffHealingPids.push(playerId);
    G.logs.push('Staff of Healing: Heroes entering this dungeon have +2 Health.');
  }
}

/**
 * Called when a Hero is about to take damage in a room.
 * Returns { skipDamage } when The Bomb destroys the last room.
 */
export function onHeroEnterRoom(G, playerId, roomIndex, room, hero) {
  if (!room || !hero) return { skipDamage: false };
  if (heroIgnoresRoomAbilities(hero) || dungeonIgnoresRoomAbilities(G, playerId)) {
    return { skipDamage: false };
  }

  if (room.id === 'THK024' && hero.item && !room.usedThisTurn) {
    const p = G.players[playerId] ?? G.players[String(playerId)];
    p.items = p.items || [];
    p.items.push({ ...hero.item, faceDown: true });
    G.logs.push(`Magnetic Ceiling: took ${hero.item.name} face-down.`);
    hero.item = null;
    if (G.adventure?.hero) G.adventure.hero.item = null;
    room.usedThisTurn = true;
  }

  if (hero.item?.id === 'THK016') {
    const p = G.players[playerId] ?? G.players[String(playerId)];
    if (roomIndex === p.dungeon.length - 1) {
      G.logs.push(`The Bomb: destroyed ${room.name} (no damage).`);
      destroyRoom(G, playerId, roomIndex);
      return { skipDamage: true };
    }
  }
  return { skipDamage: false };
}

/** Power-ups after a Hero survives a room (still alive). */
export function onHeroSurvivedRoom(G, playerId, roomIndex, room, hero, adv) {
  if (!room || !hero?.item) return;
  const itemId = hero.item.id;

  if (itemId === 'THK003' && room.advanced && !hero._inquisitorFired) {
    hero._inquisitorFired = true;
    G.logs.push(`Inquisitor's Robes: destroyed ${room.name}.`);
    destroyRoom(G, playerId, roomIndex);
  }
  if (itemId === 'THK010') {
    G.effects.deactivatedRooms = G.effects.deactivatedRooms || [];
    G.effects.deactivatedRooms.push({ playerId, roomIndex });
    G.logs.push(`Ice Rod: ${room.name} deactivated.`);
  }
  if (itemId === 'THK013' && (room.treasures || []).length >= 2) {
    G.logs.push(`Bag of Holding: destroyed ${room.name}.`);
    destroyRoom(G, playerId, roomIndex);
  }
  if (itemId === 'THK017' && adv) {
    adv.skipNext = true;
    G.logs.push(`Boots of Jumping: ${hero.name} will skip the next room.`);
  }
}

function claimItem(player, item) {
  player.items = player.items || [];
  player.items.push({ ...item, faceDown: false });
}

/** Extra Life / kill: keep the Item and apply its Reward. */
export function applyItemReward(G, playerId, item) {
  if (!item) return;
  const p = G.players[playerId] ?? G.players[String(playerId)];
  const id = item.id;
  const opps = otherPlayers(G, playerId);

  switch (id) {
    case 'THK001':
      p.woundImmuneThisTurn = true;
      G.logs.push('Extra Life: you cannot lose to Wounds this turn.');
      break;
    case 'THK002':
      for (const oid of opps) {
        const names = discardRandomOfKind(G.players[oid], G.decks, 'room', 1, '');
        if (names.length) G.logs.push(`Holy Hand Grenade: player ${oid} discarded ${names.join(', ')}.`);
      }
      break;
    case 'THK003':
      for (const oid of opps) {
        const idx = G.players[oid].dungeon.findIndex((stack) => activeRoom(stack)?.advanced);
        if (idx >= 0) {
          const room = activeRoom(G.players[oid].dungeon[idx]);
          destroyRoom(G, oid, idx);
          G.logs.push(`Inquisitor's Robes: destroyed ${room.name} in player ${oid}'s dungeon.`);
          break;
        }
      }
      break;
    case 'THK004': {
      const wi = p.wounds.findIndex((w) => (w.wounds || 1) === 1);
      if (wi >= 0) {
        p.wounds.splice(wi, 1);
        G.logs.push('Staff of Healing: healed an ordinary Wound.');
      }
      break;
    }
    case 'THK005':
      G.effects.ordinaryMonsterBonus = G.effects.ordinaryMonsterBonus || [];
      G.effects.ordinaryMonsterBonus.push(playerId);
      G.logs.push('Goblin Suit: ordinary Monster Rooms have +1 damage.');
      break;
    case 'THK009':
      for (const oid of opps) {
        const names = discardRandomOfKind(G.players[oid], G.decks, 'spell', 1, '');
        if (names.length) G.logs.push(`Antimagic Lizard: player ${oid} discarded ${names.join(', ')}.`);
      }
      break;
    case 'THK010':
      for (const oid of opps) {
        if (G.players[oid].dungeon.length) {
          G.effects.deactivatedRooms = G.effects.deactivatedRooms || [];
          G.effects.deactivatedRooms.push({ playerId: oid, roomIndex: 0 });
          G.logs.push(`Ice Rod: deactivated a room in player ${oid}'s dungeon.`);
          break;
        }
      }
      break;
    case 'THK012': {
      const spell = drawCards(G.decks.spells, 1)[0];
      if (spell) {
        p.hand.push(spell);
        G.logs.push(`Necronomicon: drew ${spell.name}.`);
      }
      break;
    }
    case 'THK013': {
      const idx = G.decks.roomDiscard.findIndex((r) => (r.treasures || []).length >= 2);
      if (idx >= 0) {
        const card = G.decks.roomDiscard.splice(idx, 1)[0];
        p.hand.push(card);
        G.logs.push(`Bag of Holding: took ${card.name} from the discard.`);
      }
      break;
    }
    case 'THK014':
      G.effects.ignoreAbilityPids = G.effects.ignoreAbilityPids || [];
      G.effects.ignoreAbilityPids.push(playerId);
      G.logs.push('Cheat Code: ignore room ability text until end of turn.');
      break;
    case 'THK015':
      for (const oid of opps) {
        deactivateFirstOfType(G, oid, 'trap', 'Ten Foot Pole');
        break;
      }
      break;
    case 'THK018':
      for (const oid of opps) {
        deactivateFirstOfType(G, oid, 'monster', 'Pet Monster');
        break;
      }
      break;
    default:
      G.logs.push(`Item reward: ${item.name}`);
      break;
  }
}

export function applyItemSurvivePowerUp(G, playerId, hero) {
  const itemId = hero?.item?.id;
  if (!itemId) return;
  const p = G.players[playerId] ?? G.players[String(playerId)];

  if (itemId === 'THK002') {
    const names = discardRandomOfKind(p, G.decks, 'room', 2, '');
    if (names.length) G.logs.push(`Holy Hand Grenade: discarded ${names.join(', ')}.`);
  }
  if (itemId === 'THK008') {
    p.wounds.push({ wounds: 1, name: 'Vorpal Blade', temp: true });
    G.logs.push('Vorpal Blade: +1 Wound until end of turn.');
  }
  if (itemId === 'THK009') {
    const names = discardRandomOfKind(p, G.decks, 'spell', 2, '');
    if (names.length) G.logs.push(`Antimagic Lizard: discarded ${names.join(', ')}.`);
  }
  if (itemId === 'THK012') {
    for (const oid of otherPlayers(G, playerId)) {
      const spell = drawCards(G.decks.spells, 1)[0];
      if (spell) {
        G.players[oid].hand.push(spell);
        G.logs.push(`Necronomicon: player ${oid} drew ${spell.name}.`);
      }
    }
  }
}

export function takeHeroItem(player, hero) {
  if (!hero?.item) return;
  claimItem(player, hero.item);
  hero.item = null;
}
