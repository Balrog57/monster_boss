// items.js - Tools of Hero-Kind: town attach, power-ups, rewards, room locks.
import { activeRoom, allActiveRooms, destroyRoom, healOneWound, heroHealthWithModifiers } from './engine.js';
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
  if (!hero || hero.item || hero.dark) return;
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

function enqueuePending(G, choice) {
  if (!choice) return;
  if (G.pendingChoice) {
    G.choiceQueue = G.choiceQueue || [];
    G.choiceQueue.push(choice);
  } else {
    G.pendingChoice = choice;
  }
}

function listRooms(G, pred) {
  const opts = [];
  for (const [pid, p] of Object.entries(G.players)) {
    if (p.eliminated) continue;
    (p.dungeon || []).forEach((stack, i) => {
      const room = activeRoom(stack);
      if (room && pred(room, Number(pid), i)) opts.push({ playerId: Number(pid), roomIndex: i, room });
    });
  }
  return opts;
}

function deactivateRoomNow(G, opt, label) {
  G.effects.deactivatedRooms = G.effects.deactivatedRooms || [];
  G.effects.deactivatedRooms.push({ playerId: opt.playerId, roomIndex: opt.roomIndex });
  G.logs.push(`${label}: ${opt.room?.name || 'a room'} deactivated.`);
}

function offerDeactivate(G, playerId, opts, bossName, message) {
  if (!opts.length) {
    G.logs.push(`${bossName}: no valid room.`);
    return;
  }
  if (opts.length === 1) {
    deactivateRoomNow(G, opts[0], bossName);
    return;
  }
  enqueuePending(G, {
    type: 'deactivate-room',
    resume: false,
    playerId: Number(playerId),
    bossName,
    message,
    options: opts,
  });
}

function listHeroesInDungeons(G, pred = () => true) {
  const opts = [];
  for (const [pid, p] of Object.entries(G.players)) {
    if (p.eliminated) continue;
    if (G.adventure && String(G.adventure.playerId) === pid && G.adventure.hero && pred(G.adventure.hero, Number(pid), G.adventure)) {
      opts.push({ hero: G.adventure.hero, playerId: Number(pid), inAdventure: true, heroId: G.adventure.hero.id });
    }
    (p.entrance || []).forEach((hero) => {
      if (pred(hero, Number(pid), null)) opts.push({ hero, playerId: Number(pid), inAdventure: false, heroId: hero.id });
    });
  }
  return opts;
}

function listFaceUpItems(G) {
  const opts = [];
  for (const [pid, p] of Object.entries(G.players)) {
    (p.items || []).forEach((it, i) => {
      if (!it.faceDown) opts.push({ item: it, playerId: Number(pid), itemIndex: i, label: `${it.name} (P${pid})` });
    });
  }
  (G.townItems || []).forEach((it, i) => {
    opts.push({ item: it, source: 'town', townItemIndex: i, label: `${it.name} (town)` });
  });
  for (const [pid, p] of Object.entries(G.players)) {
    if (G.adventure && String(G.adventure.playerId) === pid && G.adventure.hero?.item && !G.adventure.hero.item.faceDown) {
      opts.push({ item: G.adventure.hero.item, source: 'hero', playerId: Number(pid), label: `${G.adventure.hero.item.name} (on ${G.adventure.hero.name})` });
    }
    (p.entrance || []).forEach((hero) => {
      if (hero.item && !hero.item.faceDown) {
        opts.push({ item: hero.item, source: 'hero', playerId: Number(pid), heroId: hero.id, label: `${hero.item.name} (on ${hero.name})` });
      }
    });
  }
  return opts;
}

export function addHeroHealthBonus(G, heroId, amount) {
  G.effects.heroHealthBonus = G.effects.heroHealthBonus || [];
  G.effects.heroHealthBonus.push({ heroId, amount });
}

export function killHeroInDungeon(G, playerId, hero) {
  const p = G.players[playerId];
  if (!p) return;
  const idx = p.entrance.findIndex((h) => h.id === hero.id);
  if (idx >= 0) p.entrance.splice(idx, 1);
  if (G.adventure?.hero?.id === hero.id) {
    G.adventure = null;
  }
  const item = hero.item ? (takeHeroItem(p, hero) || hero.item) : null;
  const souls = hero.souls || 1;
  for (let i = 0; i < souls; i++) p.souls.push({ souls: 1, name: hero.name, class: hero.class, faceDown: true });
  G.decks.heroDiscard.push(hero);
  G.logs.push(`${hero.name} killed!`);
  if (item) {
    applyItemReward(G, playerId, item);
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
    case 'THK003': {
      const opts = listRooms(G, (room) => room.advanced);
      if (!opts.length) {
        G.logs.push("Inquisitor's Robes: no Advanced Room to destroy.");
      } else if (opts.length === 1) {
        destroyRoom(G, opts[0].playerId, opts[0].roomIndex);
        G.logs.push(`Inquisitor's Robes: destroyed ${opts[0].room.name}.`);
      } else {
        enqueuePending(G, {
          type: 'destroy-room',
          resume: false,
          playerId: Number(playerId),
          bossName: "Inquisitor's Robes",
          message: "Inquisitor's Robes: choose an Advanced Room to destroy",
          options: opts,
        });
      }
      break;
    }
    case 'THK004': {
      const soul = healOneWound(p);
      if (soul) G.logs.push(`Staff of Healing: healed ${soul.name || 'a Wound'} (${soul.souls} soul).`);
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
      offerDeactivate(
        G, playerId,
        listRooms(G, (_, pid) => pid !== Number(playerId)),
        'Ice Rod',
        "Ice Rod: choose a Room in an opponent's dungeon"
      );
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
      const opts = (G.decks.roomDiscard || [])
        .map((card, i) => ({ card, pile: 'room', pileIndex: i }))
        .filter((o) => (o.card.treasures || []).length >= 2);
      if (!opts.length) {
        G.logs.push('Bag of Holding: no dual-treasure Room in the discard.');
      } else if (opts.length === 1) {
        const card = G.decks.roomDiscard.splice(opts[0].pileIndex, 1)[0];
        p.hand.push(card);
        G.logs.push(`Bag of Holding: took ${card.name} from the discard.`);
      } else {
        enqueuePending(G, {
          type: 'recover-card',
          resume: false,
          playerId: Number(playerId),
          bossName: 'Bag of Holding',
          message: 'Bag of Holding: choose a Room with two or more treasures',
          options: opts,
        });
      }
      break;
    }
    case 'THK014':
      G.effects.ignoreAbilityPids = G.effects.ignoreAbilityPids || [];
      G.effects.ignoreAbilityPids.push(playerId);
      G.logs.push('Cheat Code: ignore room ability text until end of turn.');
      break;
    case 'THK015':
      offerDeactivate(
        G, playerId,
        listRooms(G, (room) => room.type === 'trap'),
        'Ten Foot Pole',
        'Ten Foot Pole: choose a Trap Room to deactivate'
      );
      break;
    case 'THK018':
      offerDeactivate(
        G, playerId,
        listRooms(G, (room) => room.type === 'monster'),
        'Pet Monster',
        'Pet Monster: choose a Monster Room to deactivate'
      );
      break;
    case 'THK006': {
      const monsterCount = allActiveRooms(p.dungeon).filter((r) => r && r.type === 'monster').length;
      const heroes = listHeroesInDungeons(G);
      if (!heroes.length || !monsterCount) {
        G.logs.push("Claws of the Berserker: no hero to empower.");
        break;
      }
      if (heroes.length === 1) {
        addHeroHealthBonus(G, heroes[0].heroId, monsterCount);
        G.logs.push(`Claws of the Berserker: ${heroes[0].hero.name} +${monsterCount} Health.`);
        break;
      }
      enqueuePending(G, {
        type: 'hero-health-bonus',
        resume: false,
        playerId: Number(playerId),
        bossName: 'Claws of the Berserker',
        message: 'Choose a Hero (+1 per Monster Room in your dungeon)',
        bonus: monsterCount,
        options: heroes,
      });
      break;
    }
    case 'THK007': {
      const heroes = listHeroesInDungeons(G);
      if (!heroes.length) {
        G.logs.push('Oversized Sword: no hero in a dungeon.');
        break;
      }
      if (heroes.length === 1) {
        addHeroHealthBonus(G, heroes[0].heroId, 5);
        G.logs.push(`Oversized Sword: ${heroes[0].hero.name} +5 Health.`);
        break;
      }
      enqueuePending(G, {
        type: 'hero-health-bonus',
        resume: false,
        playerId: Number(playerId),
        bossName: 'Oversized Sword',
        message: 'Choose a Hero in any dungeon (+5 Health)',
        bonus: 5,
        options: heroes,
      });
      break;
    }
    case 'THK008': {
      const wounded = listHeroesInDungeons(G, (hero, pid) => {
        const maxHp = heroHealthWithModifiers(G, hero);
        const adv = G.adventure?.hero?.id === hero.id ? G.adventure : null;
        const current = adv ? adv.hp : maxHp;
        const taken = maxHp - current;
        return taken >= Math.ceil(maxHp / 2);
      });
      if (!wounded.length) {
        G.logs.push('Vorpal Blade: no wounded Hero to kill.');
        break;
      }
      if (wounded.length === 1) {
        killHeroInDungeon(G, wounded[0].playerId, wounded[0].hero);
        G.logs.push(`Vorpal Blade: killed ${wounded[0].hero.name}.`);
        break;
      }
      enqueuePending(G, {
        type: 'kill-wounded-hero',
        resume: false,
        playerId: Number(playerId),
        bossName: 'Vorpal Blade',
        message: 'Kill a Hero who has taken at least half its Health',
        options: wounded,
      });
      break;
    }
    case 'THK011': {
      const items = listFaceUpItems(G);
      if (!items.length) {
        G.logs.push('Magic Mirror: no face-up Item to copy.');
        break;
      }
      if (items.length === 1) {
        applyItemReward(G, playerId, items[0].item);
        G.logs.push(`Magic Mirror: copied ${items[0].item.name}.`);
        break;
      }
      enqueuePending(G, {
        type: 'copy-item-reward',
        resume: false,
        playerId: Number(playerId),
        bossName: 'Magic Mirror',
        message: 'Copy the Boss Ability of a face-up Item',
        options: items,
      });
      break;
    }
    case 'THK019': {
      const survivors = (G.survivorsThisTurn?.[playerId] || G.survivorsThisTurn?.[String(playerId)] || []);
      if (!survivors.length) {
        G.logs.push('Star of Invulnerability: no Hero survived your dungeon this turn.');
        break;
      }
      if (survivors.length === 1) {
        G.logs.push(`Star of Invulnerability: ${survivors[0].name} removed from the game.`);
        break;
      }
      enqueuePending(G, {
        type: 'remove-survivor',
        resume: false,
        playerId: Number(playerId),
        bossName: 'Star of Invulnerability',
        message: 'Remove a Hero that survived your dungeon this turn',
        options: survivors.map((h) => ({ hero: h })),
      });
      break;
    }
    case 'THK020': {
      const top = G.stack?.[G.stack.length - 1];
      if (!top?.card) {
        G.logs.push('Ring of Invisibility: no Spell to cancel.');
        break;
      }
      G.stack.pop();
      G.decks.spellDiscard.push(top.card);
      G.logs.push(`Ring of Invisibility: cancelled ${top.card.name}.`);
      break;
    }
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
