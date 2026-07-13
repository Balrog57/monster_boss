// roomAbilities.js - Room build triggers, hero-death triggers, and Boss Level Ups.

import { activeRoom, allActiveRooms, destroyRoom } from './engine.js';
import { drawCards } from './cardData.js';

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

  // Spell damage bonuses
  if (G.effects?.roomDamageBonus) {
    for (const e of G.effects.roomDamageBonus) {
      if (e.playerId === playerId && e.roomIndex === roomIndex) dmg += e.amount;
    }
  }

  return Math.max(0, dmg);
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

export function onBuildRoom(G, ctx, playerId, room) {
  const player = G.players[playerId];
  if (!player) return;

  switch (room.id) {
    case 'BMA022': { // Dark Laboratory: draw 2 spells, discard 1
      const spells = drawCards(G.decks.spells, 2);
      player.hand.push(...spells);
      const spellIdx = player.hand.findIndex(c => c.isSpell);
      if (spellIdx >= 0) {
        const discarded = player.hand.splice(spellIdx, 1)[0];
        G.decks.spellDiscard.push(discarded);
        G.logs.push(`Dark Laboratory: Player ${playerId} drew 2 spells, discarded ${discarded.name}.`);
      }
      break;
    }
    case 'BMA011': // Specter's Sanctum: opponent discards a random spell
      discardRandomSpellFromOpponent(G, playerId);
      break;
    case 'BMA036': // Mimic Vault: move ordinary hero from town to entrance
      if (G.town.length > 0) {
        const idx = G.town.findIndex(h => !h.epic);
        if (idx >= 0) {
          const hero = G.town.splice(idx, 1)[0];
          player.entrance.push(hero);
          G.logs.push(`Mimic Vault: ${hero.name} moved to Player ${playerId}'s entrance.`);
        }
      }
      break;
    case 'BMA037': { // Monstrous Monument: recover a Monster Room from discard
      const idx = G.decks.roomDiscard.findIndex(r => r.type === 'monster');
      if (idx >= 0) {
        const recovered = G.decks.roomDiscard.splice(idx, 1)[0];
        player.hand.push(recovered);
        G.logs.push(`Monstrous Monument: recovered ${recovered.name}.`);
      }
      break;
    }
    case 'BMA034': // Construction Zone: build an additional room this turn
      player.buildsThisTurn = Math.max(0, (player.buildsThisTurn || 0) - 1);
      G.logs.push('Construction Zone: an additional room may be built this turn.');
      break;
    default:
      break;
  }

  // Beast Menagerie trigger
  if (room.type === 'monster') {
    for (const stack of player.dungeon) {
      const r = activeRoom(stack);
      if (r && r.id === 'BMA019') {
        const card = G.decks.rooms.pop();
        if (card) {
          player.hand.push(card);
          G.logs.push(`Beast Menagerie: Player ${playerId} drew ${card.name}.`);
        }
        break;
      }
    }
  }
}

function discardRandomSpellFromOpponent(G, casterId) {
  const opponents = Object.entries(G.players).filter(
    ([pid, p]) => pid !== String(casterId) && !p.eliminated
  );
  for (const [pid, opp] of opponents) {
    const spells = opp.hand.map((c, i) => ({ c, i })).filter(({ c }) => c.isSpell);
    if (spells.length > 0) {
      const pick = spells[Math.floor(Math.random() * spells.length)];
      const discarded = opp.hand.splice(pick.i, 1)[0];
      G.decks.spellDiscard.push(discarded);
      G.logs.push(`Specter's Sanctum: player ${pid} discarded ${discarded.name}.`);
      return;
    }
  }
}

export function onHeroDiedInRoom(G, ctx, playerId, room, hero) {
  const player = G.players[playerId];
  if (!player) return;

  switch (room.id) {
    case 'BMA010': { // Open Grave: recover a Room from discard
      const idx = G.decks.roomDiscard.findIndex(r => r.isRoom || r.type);
      if (idx >= 0) {
        const recovered = G.decks.roomDiscard.splice(idx, 1)[0];
        player.hand.push(recovered);
        G.logs.push(`Open Grave: recovered ${recovered.name}.`);
      }
      break;
    }
    case 'BMA016': { // Golem Factory: draw a Room
      const card = G.decks.rooms.pop();
      if (card) {
        player.hand.push(card);
        G.logs.push(`Golem Factory: drew ${card.name}.`);
      }
      break;
    }
    case 'BMA021': { // Brainsucker Hive: draw a Spell
      const card = G.decks.spells.pop();
      if (card) {
        player.hand.push(card);
        G.logs.push(`Brainsucker Hive: drew ${card.name}.`);
      }
      break;
    }
    case 'BMA014': // Vampire Bordello: heal one wound
      if (player.wounds.length > 0) {
        player.wounds.pop();
        G.logs.push(`Vampire Bordello: Player ${playerId} healed a wound.`);
      }
      break;
    case 'BMA012': // Succubus Spa: steal random card from opponent
      stealRandomCardFromOpponent(G, playerId);
      break;
    default:
      break;
  }
}

function stealRandomCardFromOpponent(G, casterId) {
  const opponents = Object.entries(G.players).filter(
    ([pid, p]) => pid !== String(casterId) && !p.eliminated
  );
  for (const [pid, opp] of opponents) {
    if (opp.hand.length > 0) {
      const idx = Math.floor(Math.random() * opp.hand.length);
      const stolen = opp.hand.splice(idx, 1)[0];
      G.players[casterId].hand.push(stolen);
      G.logs.push(`Succubus Spa: took ${stolen.name} from player ${pid}.`);
      return;
    }
  }
}

export function processLevelUp(G, ctx, playerId) {
  const player = G.players[playerId];
  if (!player || !player.boss) return;

  const bid = player.boss.id;
  switch (bid) {
    case 'BMA001': // Draculord: take a card from an opponent
      takeCardFromOpponentHand(G, playerId);
      break;
    case 'BMA002': { // Xyzax: recover 2 cards from discard
      for (let i = 0; i < 2; i++) {
        const c = G.decks.spellDiscard.pop() || G.decks.roomDiscard.pop();
        if (c) {
          player.hand.push(c);
          G.logs.push(`Xyzax: recovered ${c.name}.`);
        }
      }
      break;
    }
    case 'BMA003': { // King Croak: search Advanced Monster Room
      const idx = G.decks.rooms.findIndex(r => r.advanced && r.type === 'monster');
      if (idx >= 0) {
        const card = G.decks.rooms.splice(idx, 1)[0];
        player.hand.push(card);
        G.logs.push(`King Croak: found ${card.name}.`);
      }
      break;
    }
    case 'BMA004': // Robobo: each opponent destroys one room
      for (const [pid, opp] of Object.entries(G.players)) {
        if (pid === String(playerId) || opp.eliminated || opp.dungeon.length === 0) continue;
        const stack = opp.dungeon[opp.dungeon.length - 1];
        const destroyed = stack.pop();
        G.decks.roomDiscard.push(destroyed);
        if (stack.length === 0) opp.dungeon.pop();
        G.logs.push(`Robobo: player ${pid} destroyed ${destroyed.name}.`);
      }
      break;
    case 'BMA005': { // Cerebellus: draw 3 spells, discard 1
      const drawn = drawCards(G.decks.spells, 3);
      player.hand.push(...drawn);
      if (drawn.length > 0) {
        const discard = drawn[0];
        const di = player.hand.indexOf(discard);
        if (di >= 0) player.hand.splice(di, 1);
        G.decks.spellDiscard.push(discard);
        G.logs.push(`Cerebellus: drew 3 spells, discarded ${discard.name}.`);
      }
      break;
    }
    case 'BMA006': { // Seducia: move hero from town/deck to entrance
      if (G.town.length > 0) {
        const hero = G.town.shift();
        player.entrance.push(hero);
        G.logs.push(`Seducia: ${hero.name} moved to entrance.`);
      } else if (G.decks.heroes.length > 0) {
        const hero = G.decks.heroes.pop();
        player.entrance.push(hero);
        G.logs.push(`Seducia: searched the deck and found ${hero.name}.`);
      }
      break;
    }
    case 'BMA007': { // Cleopatra: search Advanced Trap Room
      const idx = G.decks.rooms.findIndex(r => r.advanced && r.type === 'trap');
      if (idx >= 0) {
        const card = G.decks.rooms.splice(idx, 1)[0];
        player.hand.push(card);
        G.logs.push(`Cleopatra: found ${card.name}.`);
      }
      break;
    }
    case 'BMA008': { // Gorgona: kill a hero in town
      if (G.town.length > 0) {
        const hero = G.town.shift();
        for (let i = 0; i < (hero.souls || 1); i++) player.souls.push({ souls: 1, name: hero.name });
        G.logs.push(`Gorgona: killed ${hero.name}.`);
      }
      break;
    }
    default:
      break;
  }
}

function takeCardFromOpponentHand(G, casterId) {
  const opponents = Object.entries(G.players).filter(
    ([pid, p]) => pid !== String(casterId) && !p.eliminated
  );
  for (const [pid, opp] of opponents) {
    if (opp.hand.length > 0) {
      const idx = Math.floor(Math.random() * opp.hand.length);
      const stolen = opp.hand.splice(idx, 1)[0];
      G.players[casterId].hand.push(stolen);
      G.logs.push(`Draculord: took ${stolen.name} from player ${pid}.`);
      return;
    }
  }
}
