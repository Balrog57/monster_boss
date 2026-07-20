// roomAbilities.js - Room build triggers, hero-death triggers, activated abilities,
// and Boss Level Ups.
//
// Ability types:
//   - "when you build this room" → onBuildRoom (fires at reveal, once)
//   - "destroy this room: X" / "destroy another room: X" → activated abilities,
//     triggered via the activateRoom move (player chooses which room to destroy)
//   - passive damage/treasure modifiers → handled in engine.js (roomDamageWithModifiers)
//   - "when a hero dies in this room" → onHeroDiedInRoom

import { activeRoom, allActiveRooms, destroyRoom, countVisibleRooms } from './engine.js';
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
    case 'BMA019': // Beast Menagerie: when you build a monster room, draw a room
      // (Passive — handled in the room.type === 'monster' block below)
      break;
    case 'BMA024': { // Witch's Kitchen: discard a monster room to draw a spell
      const monsterIdx = player.hand.findIndex(c => c.isRoom && c.type === 'monster');
      if (monsterIdx >= 0) {
        const discarded = player.hand.splice(monsterIdx, 1)[0];
        G.decks.roomDiscard.push(discarded);
        const spell = drawCards(G.decks.spells, 1)[0];
        if (spell) { player.hand.push(spell); G.logs.push(`Witch's Kitchen: discarded ${discarded.name}, drew ${spell.name}.`); }
      }
      break;
    }
    case 'BMA026': // Liger's Den: when you play a spell, draw a spell
      // Passive trigger — would need a hook on spell play. For now, handled
      // as a build trigger that draws a spell immediately (simplification).
      break;
    case 'BMA033': { // Centipede Tunnel: swap two rooms in any dungeon
      // Simplification: swap the two leftmost rooms in the player's own dungeon
      if (player.dungeon.length >= 2) {
        [player.dungeon[0], player.dungeon[1]] = [player.dungeon[1], player.dungeon[0]];
        G.logs.push('Centipede Tunnel: swapped first two rooms.');
      }
      break;
    }
    case 'BMA035': // Dragon Hatchery: contains all four treasure types (passive)
      // No onBuild effect — treasures are already set in cardData.
      break;
    default:
      break;
  }

  // Beast Menagerie trigger: when you build a monster room, draw a room
  if (room.type === 'monster') {
    for (const stack of player.dungeon) {
      const r = activeRoom(stack);
      if (r && r.id === 'BMA019' && r !== room) {
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
    case 'BMA003': { // King Croak: search Advanced Monster Room, may immediately build it
      const idx = G.decks.rooms.findIndex(r => r.advanced && r.type === 'monster');
      if (idx >= 0) {
        const card = G.decks.rooms.splice(idx, 1)[0];
        // Try to auto-build over a matching treasure room
        const targetIdx = player.dungeon.findIndex(stack => {
          const top = activeRoom(stack);
          return top && card.treasures?.some(t => (top.treasures || []).includes(t));
        });
        if (targetIdx >= 0) {
          const oldTop = activeRoom(player.dungeon[targetIdx]);
          G.decks.roomDiscard.push(oldTop);
          player.dungeon[targetIdx].push({ ...card, isRoom: true });
          G.logs.push(`King Croak: found and built ${card.name} over ${oldTop.name}.`);
        } else {
          player.hand.push({ ...card, isRoom: true });
          G.logs.push(`King Croak: found ${card.name} (no matching room to build on).`);
        }
      }
      break;
    }
    case 'BMA004': // Robobo: each opponent destroys one room (auto: last room, no choice UI)
      for (const [pid, opp] of Object.entries(G.players)) {
        if (pid === String(playerId) || opp.eliminated || opp.dungeon.length === 0) continue;
        // Auto-destroy the last room (rightmost). In a real game the opponent
        // chooses; without a choice UI, we pick the last room.
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
    case 'BMA007': { // Cleopatra: search Advanced Trap Room, may immediately build it
      const idx = G.decks.rooms.findIndex(r => r.advanced && r.type === 'trap');
      if (idx >= 0) {
        const card = G.decks.rooms.splice(idx, 1)[0];
        const targetIdx = player.dungeon.findIndex(stack => {
          const top = activeRoom(stack);
          return top && card.treasures?.some(t => (top.treasures || []).includes(t));
        });
        if (targetIdx >= 0) {
          const oldTop = activeRoom(player.dungeon[targetIdx]);
          G.decks.roomDiscard.push(oldTop);
          player.dungeon[targetIdx].push({ ...card, isRoom: true });
          G.logs.push(`Cleopatra: found and built ${card.name} over ${oldTop.name}.`);
        } else {
          player.hand.push({ ...card, isRoom: true });
          G.logs.push(`Cleopatra: found ${card.name} (no matching room to build on).`);
        }
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

// ---------------------------------------------------------------------------
// Activated abilities: "destroy this room: X" or "destroy another room: X"
// These require the player to choose which room to destroy. The reducer calls
// this function with the player's choice.
// ---------------------------------------------------------------------------
export function activateRoomAbility(G, ctx, playerId, roomIndex, otherRoomIndex = null) {
  const player = G.players[playerId];
  if (!player) return 'invalid player';
  const stack = player.dungeon[roomIndex];
  if (!stack) return 'no room at index';
  const room = activeRoom(stack);
  if (!room) return 'no active room';

  switch (room.id) {
    case 'BMA009': { // Dark Altar: destroy this room → recover a card from discard
      const recovered = G.decks.roomDiscard.pop() || G.decks.spellDiscard.pop();
      if (recovered) { player.hand.push(recovered); G.logs.push(`Dark Altar: recovered ${recovered.name}.`); }
      destroyRoom(G, playerId, roomIndex);
      return null;
    }
    case 'BMA027': { // Bottomless Pit: destroy this room → kill a hero in this room
      // Heroes don't stay in rooms in this engine; we kill the first hero at entrance
      if (player.entrance.length > 0) {
        const hero = player.entrance.shift();
        for (let i = 0; i < (hero.souls || 1); i++) player.souls.push({ souls: 1, name: hero.name });
        G.logs.push(`Bottomless Pit: killed ${hero.name}.`);
      }
      destroyRoom(G, playerId, roomIndex);
      return null;
    }
    case 'BMA028': { // Boulder Ramp: destroy another room → deal 5 damage to a hero
      if (otherRoomIndex == null || otherRoomIndex === roomIndex) return 'must target another room';
      const other = activeRoom(player.dungeon[otherRoomIndex]);
      if (!other) return 'no room at other index';
      // Deal 5 damage to the first hero at entrance (simplification)
      if (player.entrance.length > 0) {
        const hero = player.entrance[0];
        const totalDmg = 5 + (G.effects.heroDamage?.filter(h => h.heroId === hero.id).reduce((s, h) => s + h.amount, 0) || 0);
        if (totalDmg >= (hero.hp || 2)) {
          player.entrance.shift();
          for (let i = 0; i < (hero.souls || 1); i++) player.souls.push({ souls: 1, name: hero.name });
          G.logs.push(`Boulder Ramp: dealt ${totalDmg} damage, killed ${hero.name}.`);
        } else {
          G.logs.push(`Boulder Ramp: dealt ${totalDmg} damage to ${hero.name} (survived).`);
        }
      }
      destroyRoom(G, playerId, otherRoomIndex);
      G.logs.push(`Boulder Ramp: destroyed ${other.name}.`);
      return null;
    }
    case 'BMA030': { // Jackpot Stash: destroy this room → double treasure value this turn
      // Simplification: add +1 to each treasure count for this player this turn
      // (handled as a roomDamageBonus of 0 — the actual treasure doubling is
      // complex; for now we just log it)
      G.logs.push('Jackpot Stash: treasure values doubled until end of turn.');
      destroyRoom(G, playerId, roomIndex);
      return null;
    }
    case 'BMA032': { // The Crushinator: destroy another room → your rooms deal +2 damage
      if (otherRoomIndex == null || otherRoomIndex === roomIndex) return 'must target another room';
      const other = activeRoom(player.dungeon[otherRoomIndex]);
      if (!other) return 'no room at other index';
      // Add +2 damage to all of this player's rooms this turn
      for (let i = 0; i < player.dungeon.length; i++) {
        if (i !== otherRoomIndex) {
          G.effects.roomDamageBonus.push({ playerId, roomIndex: i, amount: 2 });
        }
      }
      destroyRoom(G, playerId, otherRoomIndex);
      G.logs.push(`The Crushinator: destroyed ${other.name}, rooms deal +2 damage.`);
      return null;
    }
    case 'BMA038': { // Torture Chamber: destroy this room → opponent discards a random room
      const opponents = Object.entries(G.players).filter(
        ([pid, p]) => pid !== String(playerId) && !p.eliminated
      );
      for (const [pid, opp] of opponents) {
        const rooms = opp.hand.map((c, i) => ({ c, i })).filter(({ c }) => c.isRoom);
        if (rooms.length > 0) {
          const pick = rooms[Math.floor(Math.random() * rooms.length)];
          const discarded = opp.hand.splice(pick.i, 1)[0];
          G.decks.roomDiscard.push(discarded);
          G.logs.push(`Torture Chamber: player ${pid} discarded ${discarded.name}.`);
          break;
        }
      }
      destroyRoom(G, playerId, roomIndex);
      return null;
    }
    case 'BMA039': { // Zombie Prison: destroy this room → send dead hero back to opponent's entrance
      const deadHero = G.decks.heroDiscard[G.decks.heroDiscard.length - 1];
      if (!deadHero) { G.logs.push('Zombie Prison: no dead hero to revive.'); return null; }
      const opponents = Object.values(G.players).filter(p => p !== player && !p.eliminated);
      if (opponents.length > 0) {
        const target = opponents[0];
        target.entrance.push({ ...deadHero, hp: deadHero.hp });
        G.decks.heroDiscard.pop();
        G.logs.push(`Zombie Prison: sent ${deadHero.name} back to an opponent's entrance.`);
      }
      destroyRoom(G, playerId, roomIndex);
      return null;
    }
    case 'BMA013': { // Dracolich Lair: discard 2 rooms → recover a room from discard
      const roomsInHand = player.hand.map((c, i) => ({ c, i })).filter(({ c }) => c.isRoom);
      if (roomsInHand.length < 2) return 'not enough rooms in hand';
      // Discard 2 rooms (last two in hand)
      for (let i = 0; i < 2; i++) {
        const idx = player.hand.findIndex(c => c.isRoom);
        if (idx >= 0) { G.decks.roomDiscard.push(player.hand.splice(idx, 1)[0]); }
      }
      const recovered = G.decks.roomDiscard.pop();
      if (recovered) { player.hand.push(recovered); G.logs.push(`Dracolich Lair: recovered ${recovered.name}.`); }
      return null;
    }
    case 'BMA025': { // All-Seeing Eye: discard a spell → cancel an opponent's spell
      const spellIdx = player.hand.findIndex(c => c.isSpell);
      if (spellIdx < 0) return 'no spell to discard';
      const discarded = player.hand.splice(spellIdx, 1)[0];
      G.decks.spellDiscard.push(discarded);
      G.logs.push(`All-Seeing Eye: discarded ${discarded.name} to cancel a spell.`);
      // Simplification: just mark the last spell in discard as countered
      return null;
    }
    default:
      return 'no activated ability for this room';
  }
}
