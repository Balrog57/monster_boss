// roomAbilities.js - Room passive/build/hero-death abilities + boss level-ups.
//
// Rooms have three kinds of abilities (see docs/rules/rules.md):
//   1. Passive modifiers  - affect adventure resolution (damage, treasure)
//   2. "When you build"   - fire immediately when the room is built
//   3. "When a hero dies" - fire when a hero is killed in the room
//
// Activated "destroy this room" abilities (Dark Altar, Bottomless Pit, etc.)
// require interactive target selection that the current UI doesn't expose;
// they are stubbed for a future pass.
//
// Boss level-up abilities fire when a Boss reaches 5 rooms (see processLevelUp).

import { ROOMS, BOSSES } from './cardData.js';

// ---------------------------------------------------------------------------
// Passive room modifiers (queried by processAdventures)
// ---------------------------------------------------------------------------

// Total damage dealt by a room, accounting for passive modifiers from other
// rooms in the same dungeon:
//   Goblin Armory:   +1 to adjacent Monster rooms
//   Dizzygas Hallway:+2 to the next room if it's a Trap room
//   Monster's Ballroom: damage = number of Monster rooms in the dungeon
export function roomDamageWithModifiers(G, playerId, roomIndex, baseDamage) {
  const dungeon = G.players[playerId]?.dungeon || [];
  const room = dungeon[roomIndex];
  if (!room) return baseDamage;

  // Monster's Ballroom: dynamic damage
  if (room.id === 'BMA020') {
    const monsterCount = dungeon.filter(r => r.type === 'monster').length;
    baseDamage = monsterCount;
  }

  // Scan other rooms for modifiers targeting this one.
  let bonus = 0;
  for (let i = 0; i < dungeon.length; i++) {
    if (i === roomIndex) continue;
    const other = dungeon[i];
    // Goblin Armory: adjacent monster rooms get +1
    if (other.id === 'BMA015' && Math.abs(i - roomIndex) === 1 && room.type === 'monster') {
      bonus += 1;
    }
    // Dizzygas Hallway: the NEXT room (higher index), if it's a trap, gets +2
    if (other.id === 'BMA029' && i === roomIndex - 1 && room.type === 'trap') {
      bonus += 2;
    }
  }
  return baseDamage + bonus;
}

// Effective treasure types a dungeon lures with. Dragon Hatchery (BMA035)
// contributes all four treasure types.
export function dungeonTreasures(G, playerId) {
  const boss = G.players[playerId]?.boss;
  let treasures = new Set(boss?.treasures || []);
  for (const room of G.players[playerId]?.dungeon || []) {
    if (room.id === 'BMA035') {
      treasures = new Set([...treasures, 1, 2, 3, 4]);
    }
  }
  return [...treasures];
}

// ---------------------------------------------------------------------------
// "When you build this room" abilities
// ---------------------------------------------------------------------------
export function onBuildRoom(G, ctx, playerId, room) {
  const player = G.players[playerId];
  if (!player) return;

  switch (room.id) {
    case 'BMA022': // Dark Laboratory: draw 2 spells, discard 1 spell
      for (let i = 0; i < 2; i++) {
        const s = G.decks.spells.pop();
        if (s) player.hand.push(s);
      }
      // Discard a spell (the first spell in hand that isn't the room we built)
      const spellIdx = player.hand.findIndex(c => c.isSpell);
      if (spellIdx >= 0) {
        const discarded = player.hand.splice(spellIdx, 1)[0];
        G.decks.spellDiscard.push(discarded);
        G.logs.push(`Dark Laboratory: ${playerId == 0 ? 'You' : `AI ${playerId}`} drew 2 spells, discarded ${discarded.name}.`);
      }
      break;

    case 'BMA011': // Specter's Sanctum: an opponent discards a random Spell
      discardRandomSpellFromOpponent(G, playerId);
      break;

    case 'BMA036': // Mimic Vault: move an ordinary hero from town to your entrance
      if (G.town.length > 0) {
        const idx = G.town.findIndex(h => !h.epic);
        if (idx >= 0) {
          const hero = G.town.splice(idx, 1)[0];
          player.entrance.push(hero);
          G.logs.push(`Mimic Vault: ${hero.name} moved to ${playerId == 0 ? 'your' : `AI ${playerId}'s`} entrance.`);
        }
      }
      break;

    case 'BMA037': { // Monstrous Monument: recover a Monster Room from discard
      const idx = G.decks.roomDiscard.findIndex(r => r.type === 'monster');
      if (idx >= 0) {
        const recovered = G.decks.roomDiscard.splice(idx, 1)[0];
        player.hand.push(recovered);
        G.logs.push(`Monstrous Monument: recovered ${recovered.name} from discard.`);
      }
      break;
    }

    case 'BMA034': // Construction Zone: build an additional room this turn
      player.buildsThisTurn = (player.buildsThisTurn || 0) - 1; // grant a free build
      G.logs.push('Construction Zone: an additional room may be built this turn.');
      break;

    case 'BMA019': { // Beast Menagerie: when you build another Monster room, draw a room
      // Already building a room; if THIS is a monster room and Beast Menagerie
      // exists elsewhere, handled below. Beast Menagerie itself is a trap, so
      // building it doesn't trigger itself. We handle the "other monster room"
      // case in the buildRoom move by checking for Beast Menagerie presence.
      break;
    }

    default:
      // Rooms without a build trigger, or whose triggers need UI.
      break;
  }

  // Beast Menagerie trigger: if the built room is a monster and BM is in dungeon
  if (room.type === 'monster') {
    const hasBM = player.dungeon.some(r => r.id === 'BMA019');
    if (hasBM && room.id !== 'BMA019') {
      const card = G.decks.rooms.pop();
      if (card) {
        player.hand.push(card);
        G.logs.push(`Beast Menagerie: drew a Room card (${card.name}).`);
      }
    }
  }
}

function discardRandomSpellFromOpponent(G, casterId) {
  const opponents = Object.entries(G.players).filter(
    ([pid]) => pid !== String(casterId) && !G.players[pid].eliminated
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

// ---------------------------------------------------------------------------
// "When a hero dies in this room" abilities (fire during processAdventures)
// ---------------------------------------------------------------------------
export function onHeroDiedInRoom(G, ctx, playerId, room, hero) {
  const player = G.players[playerId];
  if (!player) return;

  switch (room.id) {
    case 'BMA010': { // Open Grave: recover a Room card from discard
      const idx = G.decks.roomDiscard.findIndex(r => r.isRoom || r.type);
      if (idx >= 0) {
        const recovered = G.decks.roomDiscard.splice(idx, 1)[0];
        player.hand.push(recovered);
        G.logs.push(`Open Grave: recovered ${recovered.name} from discard.`);
      }
      break;
    }
    case 'BMA016': { // Golem Factory: draw a Room card
      const card = G.decks.rooms.pop();
      if (card) {
        player.hand.push(card);
        G.logs.push(`Golem Factory: drew a Room card (${card.name}).`);
      }
      break;
    }
    case 'BMA021': { // Brainsucker Hive: may draw a Spell card
      const card = G.decks.spells.pop();
      if (card) {
        player.hand.push(card);
        G.logs.push(`Brainsucker Hive: drew a Spell card (${card.name}).`);
      }
      break;
    }
    case 'BMA014': // Vampire Bordello: heal one Wound
      if (player.wounds.length > 0) {
        player.wounds.pop();
        G.logs.push(`Vampire Bordello: ${playerId == 0 ? 'You' : `AI ${playerId}`} healed a wound.`);
      }
      break;
    case 'BMA012': // Succubus Spa: take a random card from an opponent's hand
      stealRandomCardFromOpponent(G, playerId);
      break;
    default:
      break;
  }
}

function stealRandomCardFromOpponent(G, casterId) {
  const opponents = Object.entries(G.players).filter(
    ([pid]) => pid !== String(casterId) && !G.players[pid].eliminated
  );
  for (const [pid, opp] of opponents) {
    if (opp.hand.length > 0) {
      const idx = Math.floor(Math.random() * opp.hand.length);
      const stolen = opp.hand.splice(idx, 1)[0];
      G.players[casterId].hand.push(stolen);
      G.logs.push(`Succubus Spa: took a card (${stolen.name}) from player ${pid}.`);
      return;
    }
  }
}

// ---------------------------------------------------------------------------
// Boss Level Up (fires when a Boss reaches 5 rooms)
// ---------------------------------------------------------------------------
export function processLevelUp(G, ctx, playerId) {
  const player = G.players[playerId];
  if (!player || !player.boss) return;

  const bid = player.boss.id;
  switch (bid) {
    case 'BMA001': // Draculord: take a card from an opponent's hand
      takeCardFromOpponentHand(G, playerId);
      break;
    case 'BMA002': { // Xyzax: recover 2 cards from discard
      for (let i = 0; i < 2; i++) {
        const c = G.decks.spellDiscard.pop() || G.decks.roomDiscard.pop();
        if (c) {
          player.hand.push(c);
          G.logs.push(`Xyzax: recovered ${c.name} from discard.`);
        }
      }
      break;
    }
    case 'BMA003': { // King Croak: search for an Advanced Monster Room
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
        const destroyed = opp.dungeon.pop();
        G.decks.roomDiscard.push(destroyed);
        G.logs.push(`Robobo: player ${pid} destroyed ${destroyed.name}.`);
      }
      break;
    case 'BMA005': { // Cerebellus: draw 3 spells, discard 1
      const drawn = [];
      for (let i = 0; i < 3; i++) {
        const s = G.decks.spells.pop();
        if (s) { player.hand.push(s); drawn.push(s); }
      }
      if (drawn.length > 0) {
        const discard = drawn[0];
        const di = player.hand.indexOf(discard);
        if (di >= 0) player.hand.splice(di, 1);
        G.decks.spellDiscard.push(discard);
        G.logs.push(`Cerebellus: drew 3 spells, discarded ${discard.name}.`);
      }
      break;
    }
    case 'BMA006': { // Seducia: move a hero from town/deck to your entrance
      if (G.town.length > 0) {
        const hero = G.town.shift();
        player.entrance.push(hero);
        G.logs.push(`Seducia: ${hero.name} moved to your entrance.`);
      } else if (G.decks.heroes.length > 0) {
        const hero = G.decks.heroes.pop();
        player.entrance.push(hero);
        G.logs.push(`Seducia: searched the deck and found ${hero.name}.`);
      }
      break;
    }
    case 'BMA007': { // Cleopatra: search for an Advanced Trap Room
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
        player.souls.push({ souls: hero.souls || 1, name: hero.name });
        G.logs.push(`Gorgona: killed ${hero.name} (claimed ${hero.souls || 1} soul).`);
      }
      break;
    }
    default:
      break;
  }
}

function takeCardFromOpponentHand(G, casterId) {
  const opponents = Object.entries(G.players).filter(
    ([pid]) => pid !== String(casterId) && !G.players[pid].eliminated
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
