// roomAbilities.js - Room build triggers, hero-death triggers, activated abilities,
// and Boss Level Ups.
//
// Ability types:
//   - "when you build this room" → onBuildRoom (fires at reveal, once)
//   - "destroy this room: X" / "destroy another room: X" → activated abilities,
//     triggered via the activateRoom move (player chooses which room to destroy)
//   - passive damage/treasure modifiers → handled in engine.js (roomDamageWithModifiers)
//   - "when a hero dies in this room" → onHeroDiedInRoom

import { activeRoom, allActiveRooms, destroyRoom, countVisibleRooms, dungeonTreasures, healOneWound } from './engine.js';
export { dungeonTreasures };
import { drawCards, PHASE, HEROES } from './cardData.js';
import { dungeonIgnoresRoomAbilities, heroIgnoresRoomAbilities } from './items.js';

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

// Returns null normally, or a pendingChoice object if a player choice is needed.
export function onBuildRoom(G, ctx, playerId, room) {
  const player = G.players[playerId];
  if (!player) return null;

  switch (room.id) {
    case 'BMA022': { // Dark Laboratory: draw 2 spells, discard 1 (player chooses)
      const spells = drawCards(G.decks.spells, 2);
      player.hand.push(...spells);
      if (spells.length >= 2) {
        // Return a pending choice — the player must choose which spell to discard
        return {
          type: 'discard-spell',
          playerId: Number(playerId),
          bossId: 'BMA022',
          bossName: 'Dark Laboratory',
          message: 'Dark Laboratory: choose a spell to discard',
          options: spells.map(c => ({ card: c })),
        };
      } else if (spells.length === 1) {
        // Only 1 drawn — auto-discard it
        const di = player.hand.indexOf(spells[0]);
        if (di >= 0) player.hand.splice(di, 1);
        G.decks.spellDiscard.push(spells[0]);
        G.logs.push(`Dark Laboratory: drew 1 spell, auto-discarded ${spells[0].name}.`);
      }
      break;
    }
    case 'BMA011': { // Specter's Sanctum: choose an opponent → they discard a random spell
      const opps = opponentsWith(G, playerId, (p) => (p.hand || []).some((c) => c.isSpell));
      if (!opps.length) {
        G.logs.push("Specter's Sanctum: no opponent has a Spell.");
        break;
      }
      if (opps.length === 1) {
        discardRandomSpellFrom(G, opps[0][0], "Specter's Sanctum");
        break;
      }
      return pickOpponentChoice(G, playerId, "Specter's Sanctum", 'Choose an opponent to discard a random Spell', 'discard-spell', opps);
    }
    case 'BMA036': { // Mimic Vault: choose one ordinary Hero in town
      const ordinary = (G.town || []).map((hero, i) => ({ card: hero, townIndex: i })).filter((o) => !o.card.epic);
      if (ordinary.length === 1) {
        const hero = G.town.splice(ordinary[0].townIndex, 1)[0];
        player.entrance.push(hero);
        G.logs.push(`Mimic Vault: ${hero.name} moved to Player ${playerId}'s entrance.`);
      } else if (ordinary.length > 1) {
        return {
          type: 'pick-hero',
          playerId: Number(playerId),
          bossName: 'Mimic Vault',
          message: 'Mimic Vault: choose an ordinary Hero in town',
          options: ordinary,
        };
      }
      break;
    }
    case 'BMA037': { // Monstrous Monument: recover a Monster Room from discard
      const opts = discardCardOptions(G, 'monster');
      if (opts.length === 1) {
        takeDiscardCard(G, player, opts[0]);
        G.logs.push(`Monstrous Monument: recovered ${opts[0].card.name}.`);
      } else if (opts.length > 1) {
        return {
          type: 'recover-card',
          playerId: Number(playerId),
          bossName: 'Monstrous Monument',
          message: 'Monstrous Monument: choose a Monster Room from the discard',
          options: opts,
        };
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
    case 'BMA024': // Witch's Kitchen: once per turn, discard a monster to draw a spell
      // Activated ability — handled in activateRoomAbility, not on build.
      break;
    case 'BMA026': // Liger's Den: once per turn when you play a spell, draw a spell
      // Passive — hooked in playSpell (reducer). Once-per-turn via usedThisTurn.
      break;
    case 'BMA033': { // Centipede Tunnel: you may swap two rooms in any dungeon
      const options = listDungeonRoomOptions(G);
      if (options.length < 2) {
        G.logs.push('Centipede Tunnel: not enough rooms to swap.');
        break;
      }
      return {
        type: 'swap-rooms',
        playerId: Number(playerId),
        bossName: 'Centipede Tunnel',
        message: 'Choose the first room to swap (or skip)',
        optional: true,
        options,
      };
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

export function onHeroDiedInRoom(G, ctx, playerId, room, hero) {
  const player = G.players[playerId];
  if (!player) return;
  if (heroIgnoresRoomAbilities(hero)) return;

  switch (room.id) {
    case 'BMA010': { // Open Grave: choose a Room from the discard
      const opts = discardCardOptions(G, 'room');
      if (opts.length === 1) {
        takeDiscardCard(G, player, opts[0]);
        G.logs.push(`Open Grave: recovered ${opts[0].card.name}.`);
      } else if (opts.length > 1) {
        enqueuePending(G, {
          type: 'recover-card',
          resume: false,
          playerId: Number(playerId),
          bossName: 'Open Grave',
          message: 'Open Grave: choose a Room from the discard pile',
          options: opts,
        });
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
    case 'BMA014': { // Vampire Bordello: heal one wound (flip to soul)
      const soul = healOneWound(player);
      if (soul) G.logs.push(`Vampire Bordello: healed ${soul.name || 'a Wound'} (${soul.souls} soul).`);
      break;
    }
    case 'BMA012': { // Succubus Spa: choose an opponent → steal a random card
      const opps = opponentsWith(G, playerId, (p) => (p.hand || []).length > 0);
      if (!opps.length) {
        G.logs.push('Succubus Spa: no opponent has a card.');
        break;
      }
      if (opps.length === 1) {
        stealRandomCardFrom(G, playerId, opps[0][0], 'Succubus Spa');
        break;
      }
      enqueuePending(G, pickOpponentChoice(
        G, playerId, 'Succubus Spa', 'Choose an opponent to steal a random card from', 'steal-random', opps, { resume: false }
      ));
      break;
    }
    default:
      break;
  }
}

function opponentsWith(G, playerId, pred) {
  return Object.entries(G.players).filter(
    ([pid, p]) => Number(pid) !== Number(playerId) && !p.eliminated && pred(p)
  );
}

function pickOpponentChoice(G, playerId, bossName, message, action, opps, extra = {}) {
  return {
    type: 'pick-opponent',
    playerId: Number(playerId),
    bossName,
    message,
    action,
    options: opps.map(([id, p]) => ({ targetPlayerId: Number(id), card: p.boss })),
    ...extra,
  };
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

function finishChoice(G) {
  const next = (G.choiceQueue || []).shift();
  G.pendingChoice = next || null;
  if (!G.choiceQueue?.length) G.choiceQueue = null;
}

function discardRandomSpellFrom(G, pid, label) {
  const opp = G.players[pid];
  const spells = (opp?.hand || []).map((c, i) => ({ c, i })).filter(({ c }) => c.isSpell);
  if (!spells.length) return;
  const pick = spells[Math.floor(Math.random() * spells.length)];
  const discarded = opp.hand.splice(pick.i, 1)[0];
  G.decks.spellDiscard.push(discarded);
  G.logs.push(`${label}: player ${pid} discarded ${discarded.name}.`);
}

function stealRandomCardFrom(G, casterId, pid, label) {
  const opp = G.players[pid];
  if (!opp?.hand?.length) return;
  const idx = Math.floor(Math.random() * opp.hand.length);
  const stolen = opp.hand.splice(idx, 1)[0];
  G.players[casterId].hand.push(stolen);
  G.logs.push(`${label}: took ${stolen.name} from player ${pid}.`);
}

function discardRandomRoomFromHand(G, pid, label) {
  const opp = G.players[pid];
  const rooms = (opp?.hand || []).map((c, i) => ({ c, i })).filter(({ c }) => c.isRoom);
  if (!rooms.length) return;
  const pick = rooms[Math.floor(Math.random() * rooms.length)];
  const discarded = opp.hand.splice(pick.i, 1)[0];
  G.decks.roomDiscard.push(discarded);
  G.logs.push(`${label}: player ${pid} discarded ${discarded.name}.`);
}

function searchAdvancedChoice(G, playerId, roomType, bossName) {
  const kind = roomType === 'monster' ? 'Monster' : 'Trap';
  const options = [];
  (G.decks.rooms || []).forEach((card, i) => {
    if (card.advanced && card.type === roomType) options.push({ card, pile: 'deck', pileIndex: i });
  });
  (G.decks.roomDiscard || []).forEach((card, i) => {
    if (card.advanced && card.type === roomType) options.push({ card, pile: 'discard', pileIndex: i });
  });
  if (!options.length) {
    G.logs.push(`${bossName}: no Advanced ${kind} Room to search.`);
    return null;
  }
  return {
    type: 'search-advanced',
    optional: true,
    playerId: Number(playerId),
    bossName,
    roomType,
    message: `${bossName}: choose an Advanced ${kind} Room (or skip)`,
    options,
  };
}

function takePileCard(pile, option) {
  if (!pile) return null;
  let idx = option.pileIndex;
  if (pile[idx]?.id !== option.card?.id) {
    idx = pile.findIndex((c) => c.id === option.card?.id && c.name === option.card?.name);
  }
  if (idx < 0) return null;
  return pile.splice(idx, 1)[0];
}

function matchingBuildSlots(player, card) {
  return (player.dungeon || []).map((stack, i) => ({ roomIndex: i, room: activeRoom(stack) }))
    .filter((o) => o.room && (card.treasures || []).some((t) => (o.room.treasures || []).includes(t)));
}

function seduciaHeroOptions(G) {
  const options = (G.town || []).map((hero, i) => ({ card: hero, source: 'town', townIndex: i }));
  (G.decks.heroes || []).forEach((hero, i) => options.push({ card: hero, source: 'deck', pile: 'heroes', deckIndex: i }));
  (G.decks.epics || []).forEach((hero, i) => options.push({ card: hero, source: 'deck', pile: 'epics', deckIndex: i }));
  return options;
}

function ordinarySoulOptions(G, playerId) {
  const options = [];
  for (const [id, p] of Object.entries(G.players)) {
    if (Number(id) === Number(playerId) || p.eliminated) continue;
    (p.souls || []).forEach((s, i) => {
      if ((s.souls || 1) === 1 && !s.tpk) {
        options.push({
          card: soulAsCard(s),
          fromPid: Number(id),
          soulIndex: i,
          pile: 'souls',
        });
      }
    });
  }
  return options;
}

function deadHeroOptions(G, playerId) {
  const options = [];
  for (const [id, p] of Object.entries(G.players)) {
    if (Number(id) === Number(playerId) || p.eliminated) continue;
    (p.souls || []).forEach((s, i) => {
      if (!s.tpk) options.push({ card: soulAsCard(s), fromPid: Number(id), soulIndex: i, pile: 'souls' });
    });
    (p.wounds || []).forEach((s, i) => {
      options.push({ card: soulAsCard(s), fromPid: Number(id), soulIndex: i, pile: 'wounds' });
    });
  }
  return options;
}

function soulAsCard(s) {
  const orig = HEROES.find((h) => h.name === s.name || h.id === s.id);
  return {
    ...(orig || {}),
    name: s.name || orig?.name || 'Hero',
    class: s.class || orig?.class,
    hp: orig?.hp || 4,
    id: orig?.id || s.id,
  };
}

function reviveFromSoul(soul, hpBonus = 0) {
  const card = soulAsCard(soul);
  return { ...card, hp: (card.hp || 4) + hpBonus, souls: card.souls || soul.souls || 1 };
}

function makeDestroyRoomChoice(G, oppPid, bossName) {
  const opp = G.players[oppPid];
  const options = (opp?.dungeon || []).map((stack, i) => ({ roomIndex: i, room: activeRoom(stack) })).filter((o) => o.room);
  if (!options.length) return null;
  return {
    type: 'destroy-room',
    playerId: Number(oppPid),
    bossId: 'BMA004',
    bossName,
    message: `${bossName}: Player ${oppPid} must choose a room to destroy`,
    options,
  };
}

function nextRoboboChoice(G) {
  while ((G.roboboQueue || []).length) {
    const next = G.roboboQueue.shift();
    const choice = makeDestroyRoomChoice(G, next, 'Robobo');
    if (choice) return choice;
  }
  G.roboboQueue = null;
  return null;
}

function handRoomOptions(player) {
  return (player.hand || []).map((c, i) => ({ card: c, handIndex: i })).filter((o) => o.card.isRoom);
}

function heroesWithoutItem(G) {
  const opts = [];
  (G.town || []).forEach((h, i) => {
    if (!h.item) opts.push({ card: h, source: 'town', index: i });
  });
  for (const [id, p] of Object.entries(G.players)) {
    if (p.eliminated) continue;
    (p.entrance || []).forEach((h, i) => {
      if (!h.item) opts.push({ card: h, source: 'entrance', playerId: Number(id), index: i });
    });
  }
  if (G.adventure?.hero && !G.adventure.hero.item) {
    opts.push({ card: G.adventure.hero, source: 'adventure' });
  }
  return opts;
}

function locateHero(G, opt) {
  if (opt.source === 'town') return G.town[opt.index];
  if (opt.source === 'adventure') return G.adventure?.hero;
  if (opt.source === 'entrance') return G.players[opt.playerId]?.entrance?.[opt.index];
  return null;
}

function markRoomUsed(G, playerId, roomIndex) {
  if (roomIndex == null) return;
  const r = activeRoom(G.players[playerId]?.dungeon?.[roomIndex]);
  if (r) r.usedThisTurn = true;
}

function attachSmithyItem(G, playerId, itemIndex, heroOpt, roomIndex) {
  const item = (G.townItems || []).splice(itemIndex, 1)[0];
  const hero = locateHero(G, heroOpt);
  if (!item || !hero) {
    if (item) G.townItems.splice(itemIndex, 0, item);
    return false;
  }
  hero.item = item;
  markRoomUsed(G, playerId, roomIndex);
  G.logs.push(`Orcish Smithy: attached ${item.name} to ${hero.name}.`);
  return true;
}

// Returns null if auto-resolved, or a pendingChoice object if the player
// must make a choice (the reducer will pause and wait for resolveLevelUpChoice).
export function processLevelUp(G, ctx, playerId) {
  const player = G.players[playerId];
  if (!player || !player.boss) return null;

  const bid = player.boss.id;
  switch (bid) {
    case 'BMA001': { // Draculord: take a card from an opponent (player chooses)
      const opponents = Object.entries(G.players).filter(
        ([pid, p]) => pid !== String(playerId) && !p.eliminated && p.hand.length > 0
      );
      if (opponents.length === 0) { G.logs.push('Draculord: no opponent cards to take.'); return null; }
      // Gather all opponent hand cards as options
      const options = [];
      for (const [pid, opp] of opponents) {
        for (let i = 0; i < opp.hand.length; i++) {
          options.push({ card: opp.hand[i], fromPid: Number(pid), handIndex: i });
        }
      }
      if (options.length === 0) return null;
      return {
        type: 'steal-card',
        playerId: Number(playerId),
        bossId: 'BMA001',
        bossName: 'Draculord',
        message: 'Draculord: choose a card to steal from an opponent',
        options,
      };
    }
    case 'BMA002': { // Xyzax: recover 2 cards from discard
      const opts = discardCardOptions(G, 'any');
      if (opts.length === 0) { G.logs.push('Xyzax: discard piles are empty.'); return null; }
      if (opts.length <= 2) {
        for (const opt of opts) {
          takeDiscardCard(G, player, opt);
          G.logs.push(`Xyzax: recovered ${opt.card.name}.`);
        }
        return null;
      }
      return {
        type: 'recover-card',
        playerId: Number(playerId),
        bossName: 'Xyzax',
        message: 'Xyzax: choose a card from the discard (2 remaining)',
        remaining: 2,
        options: opts,
      };
    }
    case 'BMA003': // King Croak: search Advanced Monster Room, may immediately build it
      return searchAdvancedChoice(G, playerId, 'monster', 'King Croak');
    case 'BMA004': { // Robobo: each opponent destroys one room (opponent chooses)
      const opponents = Object.entries(G.players).filter(
        ([pid, opp]) => Number(pid) !== Number(playerId) && !opp.eliminated && opp.dungeon.length > 0
      );
      if (opponents.length === 0) { G.logs.push('Robobo: no opponent rooms to destroy.'); return null; }
      G.roboboQueue = opponents.slice(1).map(([pid]) => Number(pid));
      return makeDestroyRoomChoice(G, Number(opponents[0][0]), 'Robobo');
    }
    case 'BMA005': { // Cerebellus: draw 3 spells, discard 1 (player chooses)
      const drawn = drawCards(G.decks.spells, 3);
      player.hand.push(...drawn);
      if (drawn.length >= 2) {
        return {
          type: 'discard-spell',
          playerId: Number(playerId),
          bossId: 'BMA005',
          bossName: 'Cerebellus',
          message: 'Cerebellus: choose a spell to discard',
          options: drawn.map(c => ({ card: c })),
        };
      } else if (drawn.length === 1) {
        const di = player.hand.indexOf(drawn[0]);
        if (di >= 0) player.hand.splice(di, 1);
        G.decks.spellDiscard.push(drawn[0]);
        G.logs.push(`Cerebellus: drew 1 spell, auto-discarded ${drawn[0].name}.`);
      }
      return null;
    }
    case 'BMA006': { // Seducia: search town or the Hero decks
      const options = seduciaHeroOptions(G);
      if (!options.length) {
        G.logs.push('Seducia: no Hero in town or the Hero decks.');
        return null;
      }
      return {
        type: 'pick-hero',
        optional: true,
        playerId: Number(playerId),
        bossName: 'Seducia',
        message: 'Seducia: choose a Hero in town or the Hero decks (or skip)',
        options,
      };
    }
    case 'BMA007': // Cleopatra: search Advanced Trap Room, may immediately build it
      return searchAdvancedChoice(G, playerId, 'trap', 'Cleopatra');
    case 'BMA008': { // Gorgona: kill a hero in town
      if (G.town.length > 1) {
        return {
          type: 'kill-hero',
          playerId: Number(playerId),
          bossName: 'Gorgona',
          message: 'Gorgona: choose a Hero in town to destroy',
          options: G.town.map((hero, i) => ({ card: hero, townIndex: i })),
        };
      }
      if (G.town.length === 1) {
        const hero = G.town.shift();
        for (let i = 0; i < (hero.souls || 1); i++) player.souls.push({ souls: 1, name: hero.name, class: hero.class });
        G.logs.push(`Gorgona: killed ${hero.name}.`);
      }
      return null;
    }
    case 'KSA001': { // Kirax: extra Cleric/Fighter/Mage treasures
      const extra = [1, 2, 3];
      player.boss.treasures = [...(player.boss.treasures || []), ...extra];
      G.logs.push('Kirax: dungeon now also has Cleric, Fighter, and Mage treasure.');
      return null;
    }
    case 'KSA002': { // Hellcow: choose any dungeon and rearrange its rooms
      return hellcowRearrangeChoice(G, playerId);
    }
    case 'KSA003': { // The Brothers Wise: search spell deck
      if (G.decks.spells.length === 0) { G.logs.push('The Brothers Wise: spell deck is empty.'); return null; }
      return {
        type: 'search-spell',
        playerId: Number(playerId),
        bossId: 'KSA003',
        bossName: 'The Brothers Wise',
        message: 'The Brothers Wise: choose a Spell from the deck',
        options: G.decks.spells.map((card, i) => ({ card, deckIndex: i })),
      };
    }
    case 'KSA004': { // Kaw'nee: steal an ordinary soul from an opponent
      const options = ordinarySoulOptions(G, playerId);
      if (!options.length) {
        G.logs.push("Kaw'nee: no ordinary Hero to steal.");
        return null;
      }
      if (options.length === 1) {
        const opt = options[0];
        const stolen = G.players[opt.fromPid].souls.splice(opt.soulIndex, 1)[0];
        player.souls.push(stolen);
        G.logs.push(`Kaw'nee: stole ${stolen.name || 'a Hero'} from player ${opt.fromPid}.`);
        return null;
      }
      return {
        type: 'pick-soul',
        action: 'steal',
        playerId: Number(playerId),
        bossName: "Kaw'nee",
        message: "Kaw'nee: choose an ordinary Hero to steal",
        options,
      };
    }
    case 'KSA005': { // Scythe: last room +3 forever
      player.scytheBoost = true;
      G.logs.push('Scythe: the last room of your dungeon has +3 damage.');
      return null;
    }
    case 'KSA006': { // Jarin: +1 soul forever
      player.bonusSouls = (player.bonusSouls || 0) + 1;
      G.logs.push('Jarin: you have +1 Soul for the rest of the game.');
      return null;
    }
    case 'KSA007': { // Elicon: double treasure until end of turn
      G.effects.treasureDoubled = G.effects.treasureDoubled || [];
      G.effects.treasureDoubled.push(Number(playerId));
      G.logs.push('Elicon: your room treasures are doubled until end of turn.');
      return null;
    }
    default:
      return null;
  }
}

function discardCardOptions(G, kind) {
  const opts = [];
  const rooms = G.decks.roomDiscard || [];
  const spells = G.decks.spellDiscard || [];
  if (kind !== 'spell') {
    rooms.forEach((card, i) => {
      if (kind === 'monster' && card.type !== 'monster') return;
      if (kind === 'room' && !(card.isRoom || card.type)) return;
      opts.push({ card, pile: 'room', pileIndex: i });
    });
  }
  if (kind !== 'room' && kind !== 'monster') {
    spells.forEach((card, i) => opts.push({ card, pile: 'spell', pileIndex: i }));
  }
  return opts;
}

function takeDiscardCard(G, player, option) {
  const pile = option.pile === 'spell' ? G.decks.spellDiscard : G.decks.roomDiscard;
  let idx = option.pileIndex;
  if (pile[idx]?.id !== option.card?.id) {
    idx = pile.findIndex((c) => c.id === option.card?.id && c.name === option.card?.name);
  }
  if (idx < 0) return null;
  const card = pile.splice(idx, 1)[0];
  player.hand.push(card);
  return card;
}

export function hauntedLibraryChoice(playerId) {
  return {
    type: 'haunted-library',
    resume: false,
    playerId: Number(playerId),
    bossName: 'Haunted Library',
    message: 'Draw from the Room deck or the Spell deck?',
    options: [
      { label: 'Room deck', deck: 'rooms' },
      { label: 'Spell deck', deck: 'spells' },
    ],
  };
}

function hellcowRearrangeChoice(G, playerId) {
  const targets = Object.entries(G.players)
    .filter(([, p]) => !p.eliminated && (p.dungeon || []).length >= 2)
    .map(([id, p]) => ({ targetPlayerId: Number(id), card: p.boss }));
  if (!targets.length) {
    G.logs.push('Hellcow: no dungeon with 2+ rooms to rearrange.');
    return null;
  }
  if (targets.length === 1) {
    return makeRearrangeChoice(G, playerId, targets[0].targetPlayerId, true);
  }
  return {
    type: 'pick-dungeon',
    optional: true,
    playerId: Number(playerId),
    bossName: 'Hellcow',
    message: 'Choose a dungeon to rearrange (or skip)',
    options: targets,
  };
}

function makeRearrangeChoice(G, chooserId, targetPlayerId, optional) {
  const p = G.players[targetPlayerId];
  return {
    type: 'rearrange-dungeon',
    optional: !!optional,
    playerId: Number(chooserId),
    targetPlayerId: Number(targetPlayerId),
    bossName: 'Hellcow',
    message: 'Click rooms in the new order (entrance → boss)',
    picked: [],
    options: (p.dungeon || []).map((stack, i) => ({ roomIndex: i, room: activeRoom(stack) })).filter((o) => o.room),
  };
}

// Resolve a pending level-up choice. Called by the reducer's resolveLevelUpChoice move.
function listDungeonRoomOptions(G) {
  const options = [];
  for (const [pid, p] of Object.entries(G.players)) {
    if (p.eliminated) continue;
    (p.dungeon || []).forEach((stack, i) => {
      const room = activeRoom(stack);
      if (room) options.push({ playerId: Number(pid), roomIndex: i, room });
    });
  }
  return options;
}

function applyWitchKitchenDiscard(G, player, handIndex) {
  const discarded = player.hand.splice(handIndex, 1)[0];
  G.decks.roomDiscard.push(discarded);
  const spell = drawCards(G.decks.spells, 1)[0];
  if (spell) player.hand.push(spell);
  G.logs.push(`Witch's Kitchen: discarded ${discarded.name}${spell ? `, drew ${spell.name}` : ''}.`);
}

function heroIsInRoom(G, playerId, roomIndex) {
  const adv = G.adventure;
  return !!(adv && Number(adv.playerId) === Number(playerId) && adv.roomIndex === roomIndex && adv.hero);
}

export function resolveLevelUpChoice(G, ctx, playerId, optionIndex) {
  const choice = G.pendingChoice;
  if (!choice) return 'no pending choice';
  if (Number(playerId) !== choice.playerId) return 'not your choice to make';
  if (optionIndex < 0 && choice.optional) {
    if (choice.type === 'build-over' && choice.card) {
      const player = G.players[playerId];
      player.hand.push({ ...choice.card, isRoom: true });
      G.logs.push(`${choice.bossName}: ${choice.card.name} added to hand.`);
    } else {
      G.logs.push(`${choice.bossName || 'Ability'}: skipped.`);
    }
    finishChoice(G);
    return null;
  }
  const option = choice.options[optionIndex];
  if (!option) return 'invalid option';

  switch (choice.type) {
    case 'discard-spell': {
      const player = G.players[playerId];
      const card = option.card;
      const idx = player.hand.findIndex(c => c.name === card.name && c.isSpell);
      if (idx >= 0) {
        const discarded = player.hand.splice(idx, 1)[0];
        G.decks.spellDiscard.push(discarded);
        G.logs.push(`${choice.bossName}: discarded ${discarded.name}.`);
      }
      if (choice.thenCancel) {
        const top = G.stack?.pop();
        if (top?.card) {
          G.decks.spellDiscard.push(top.card);
          G.logs.push(`${choice.bossName}: cancelled ${top.card.name}.`);
        } else {
          G.logs.push(`${choice.bossName}: cancelled a spell.`);
        }
        G._spellCancelled = true;
        markRoomUsed(G, playerId, choice.roomIndex);
      }
      break;
    }
    case 'steal-card': {
      const player = G.players[playerId];
      const { fromPid, handIndex } = option;
      const opp = G.players[fromPid];
      if (opp && opp.hand[handIndex]) {
        const stolen = opp.hand.splice(handIndex, 1)[0];
        player.hand.push(stolen);
        G.logs.push(`Draculord: took ${stolen.name} from player ${fromPid}.`);
      }
      break;
    }
    case 'destroy-room': {
      const ownerId = option.playerId ?? playerId;
      const { roomIndex } = option;
      const room = activeRoom(G.players[ownerId]?.dungeon?.[roomIndex]);
      if (room) {
        destroyRoom(G, ownerId, roomIndex);
        G.logs.push(`${choice.bossName || 'Robobo'}: player ${ownerId} destroyed ${room.name}.`);
      }
      const next = nextRoboboChoice(G);
      if (next) {
        G.pendingChoice = next;
        return null;
      }
      break;
    }
    case 'search-spell': {
      const player = G.players[playerId];
      const { deckIndex, card } = option;
      const idx = deckIndex != null ? deckIndex : G.decks.spells.findIndex(c => c.id === card?.id);
      if (idx >= 0) {
        const taken = G.decks.spells.splice(idx, 1)[0];
        player.hand.push(taken);
        G.logs.push(`${choice.bossName}: took ${taken.name} from the Spell deck.`);
      }
      break;
    }
    case 'swap-rooms': {
      if (!choice.first) {
        G.pendingChoice = {
          ...choice,
          first: { playerId: option.playerId, roomIndex: option.roomIndex },
          message: 'Choose the second room to swap',
          optional: false,
          options: choice.options.filter((_, i) => i !== optionIndex),
        };
        return null;
      }
      const a = choice.first;
      const b = option;
      const pa = G.players[a.playerId];
      const pb = G.players[b.playerId];
      if (!pa?.dungeon[a.roomIndex] || !pb?.dungeon[b.roomIndex]) return 'invalid rooms';
      const nameA = activeRoom(pa.dungeon[a.roomIndex])?.name;
      const nameB = activeRoom(pb.dungeon[b.roomIndex])?.name;
      const tmp = pa.dungeon[a.roomIndex];
      pa.dungeon[a.roomIndex] = pb.dungeon[b.roomIndex];
      pb.dungeon[b.roomIndex] = tmp;
      G.logs.push(`Centipede Tunnel: swapped ${nameA} and ${nameB}.`);
      break;
    }
    case 'discard-monster': {
      const player = G.players[playerId];
      const idx = option.handIndex != null
        ? option.handIndex
        : player.hand.findIndex((c) => c.id === option.card?.id && c.type === 'monster');
      if (idx < 0 || !player.hand[idx]) return 'card not in hand';
      applyWitchKitchenDiscard(G, player, idx);
      const r = activeRoom(player.dungeon[choice.roomIndex]);
      if (r) r.usedThisTurn = true;
      break;
    }
    case 'recover-card': {
      const player = G.players[playerId];
      const taken = takeDiscardCard(G, player, option);
      if (taken) G.logs.push(`${choice.bossName}: recovered ${taken.name}.`);
      const left = (choice.remaining || 1) - 1;
      if (left > 0) {
        const opts = (choice.options || []).filter((_, i) => i !== optionIndex);
        if (opts.length) {
          G.pendingChoice = {
            ...choice,
            remaining: left,
            options: opts,
            message: `${choice.bossName}: choose a card from the discard (${left} remaining)`,
          };
          return null;
        }
      }
      break;
    }
    case 'pick-hero': {
      const player = G.players[playerId];
      let hero = null;
      if (option.source === 'deck' || option.pile) {
        const pile = option.pile === 'epics' ? G.decks.epics : G.decks.heroes;
        hero = takePileCard(pile, { pileIndex: option.deckIndex, card: option.card });
      } else {
        const idx = option.townIndex;
        if (idx == null || !G.town[idx]) return 'invalid hero';
        hero = G.town.splice(idx, 1)[0];
      }
      if (!hero) return 'invalid hero';
      player.entrance.push(hero);
      G.logs.push(`${choice.bossName}: ${hero.name} moved to your entrance.`);
      break;
    }
    case 'kill-hero': {
      const player = G.players[playerId];
      const idx = option.townIndex;
      if (idx == null || !G.town[idx]) return 'invalid hero';
      const hero = G.town.splice(idx, 1)[0];
      for (let i = 0; i < (hero.souls || 1); i++) player.souls.push({ souls: 1, name: hero.name, class: hero.class });
      G.logs.push(`Gorgona: killed ${hero.name}.`);
      break;
    }
    case 'pick-dungeon': {
      G.pendingChoice = makeRearrangeChoice(G, playerId, option.targetPlayerId, false);
      return null;
    }
    case 'rearrange-dungeon': {
      const picked = [...(choice.picked || []), option.roomIndex];
      const remaining = choice.options.filter((_, i) => i !== optionIndex);
      if (remaining.length === 0) {
        const p = G.players[choice.targetPlayerId];
        p.dungeon = picked.map((i) => p.dungeon[i]);
        G.logs.push(`Hellcow: rearranged Player ${choice.targetPlayerId}'s dungeon.`);
        break;
      }
      G.pendingChoice = {
        ...choice,
        optional: false,
        picked,
        options: remaining,
        message: `Hellcow: ${remaining.length} room(s) left (entrance → boss)`,
      };
      return null;
    }
    case 'haunted-library': {
      const player = G.players[playerId];
      const deckName = option.deck === 'spells' ? 'spells' : 'rooms';
      const card = G.decks[deckName]?.pop();
      if (card) {
        player.hand.push(card);
        G.logs.push(`Haunted Library: drew ${card.name} from the ${deckName === 'spells' ? 'Spell' : 'Room'} deck.`);
      }
      const next = (G.hauntedWaiters || []).shift();
      if (next != null) {
        G.pendingChoice = hauntedLibraryChoice(next);
        return null;
      }
      G.hauntedWaiters = null;
      break;
    }
    case 'pick-opponent': {
      const targetId = option.targetPlayerId;
      if (choice.action === 'discard-spell') discardRandomSpellFrom(G, targetId, choice.bossName);
      else if (choice.action === 'steal-random') stealRandomCardFrom(G, playerId, targetId, choice.bossName);
      else if (choice.action === 'discard-room') discardRandomRoomFromHand(G, targetId, choice.bossName);
      if (choice.destroyRoomIndex != null) destroyRoom(G, playerId, choice.destroyRoomIndex);
      break;
    }
    case 'search-advanced': {
      const player = G.players[playerId];
      const pile = option.pile === 'discard' ? G.decks.roomDiscard : G.decks.rooms;
      const card = takePileCard(pile, option);
      if (!card) return 'card not found';
      const matches = matchingBuildSlots(player, card);
      if (matches.length) {
        G.pendingChoice = {
          type: 'build-over',
          optional: true,
          playerId: Number(playerId),
          bossName: choice.bossName,
          card,
          message: `${choice.bossName}: build ${card.name} over a matching room (or keep in hand)`,
          options: matches,
        };
        return null;
      }
      player.hand.push({ ...card, isRoom: true });
      G.logs.push(`${choice.bossName}: ${card.name} added to hand.`);
      break;
    }
    case 'build-over': {
      const player = G.players[playerId];
      const card = choice.card;
      const idx = option.roomIndex;
      if (!player.dungeon[idx]) return 'invalid room';
      player.dungeon[idx].push({ ...card, isRoom: true });
      G.logs.push(`${choice.bossName}: built ${card.name} over ${option.room?.name || 'a room'}.`);
      break;
    }
    case 'pick-soul': {
      const from = G.players[option.fromPid];
      const pileName = option.pile || 'souls';
      const pile = from?.[pileName];
      if (!pile || option.soulIndex == null || !pile[option.soulIndex]) return 'invalid hero';
      const soul = pile.splice(option.soulIndex, 1)[0];
      if (choice.action === 'steal') {
        G.players[playerId].souls.push(soul);
        G.logs.push(`${choice.bossName}: stole ${soul.name || 'a Hero'} from player ${option.fromPid}.`);
      } else {
        from.entrance = from.entrance || [];
        from.entrance.push(reviveFromSoul(soul, choice.hpBonus || 0));
        G.logs.push(`${choice.bossName}: sent ${soul.name || 'a Hero'} to Player ${option.fromPid}'s entrance.`);
        if (choice.destroyRoomIndex != null) destroyRoom(G, playerId, choice.destroyRoomIndex);
      }
      break;
    }
    case 'discard-hand-rooms': {
      const player = G.players[playerId];
      let idx = option.handIndex;
      if (player.hand[idx]?.id !== option.card?.id) {
        idx = player.hand.findIndex((c) => c.id === option.card?.id && c.isRoom);
      }
      if (idx < 0) return 'card not in hand';
      const discarded = player.hand.splice(idx, 1)[0];
      G.decks.roomDiscard.push(discarded);
      const left = (choice.remaining || 1) - 1;
      if (left > 0) {
        const opts = handRoomOptions(player);
        if (opts.length) {
          G.pendingChoice = {
            ...choice,
            remaining: left,
            options: opts,
            message: `${choice.bossName}: discard another Room (${left} remaining)`,
          };
          return null;
        }
      }
      markRoomUsed(G, playerId, choice.roomIndex);
      if (choice.then === 'recover-room') {
        const opts = discardCardOptions(G, 'room');
        if (opts.length === 1) {
          takeDiscardCard(G, player, opts[0]);
          G.logs.push(`${choice.bossName}: recovered ${opts[0].card.name}.`);
        } else if (opts.length > 1) {
          G.pendingChoice = {
            type: 'recover-card',
            resume: false,
            playerId: Number(playerId),
            bossName: choice.bossName,
            message: `${choice.bossName}: choose a Room from the discard`,
            options: opts,
          };
          return null;
        }
      } else if (choice.then === 'flip-item-up') {
        const items = (player.items || []).map((it, i) => ({ card: it, itemIndex: i })).filter((o) => o.card.faceDown);
        if (items.length === 1) {
          items[0].card.faceDown = false;
          G.logs.push(`${choice.bossName}: flipped ${items[0].card.name} face-up.`);
        } else if (items.length > 1) {
          G.pendingChoice = {
            type: 'pick-item',
            action: 'flip-up',
            resume: false,
            playerId: Number(playerId),
            bossName: choice.bossName,
            message: `${choice.bossName}: choose a face-down Item to flip up`,
            options: items,
          };
          return null;
        } else {
          G.logs.push(`${choice.bossName}: no face-down item to flip.`);
        }
      }
      break;
    }
    case 'pick-item': {
      const player = G.players[playerId];
      const item = (player.items || [])[option.itemIndex] || option.card;
      if (!item) return 'invalid item';
      if (choice.action === 'flip-up') item.faceDown = false;
      else item.faceDown = true;
      G.logs.push(`${choice.bossName}: flipped ${item.name} ${item.faceDown ? 'face-down' : 'face-up'}.`);
      if (choice.action === 'flip-down') {
        const spell = drawCards(G.decks.spells, 1)[0];
        if (spell) {
          player.hand.push(spell);
          G.logs.push(`${choice.bossName}: drew ${spell.name}.`);
        }
      }
      markRoomUsed(G, playerId, choice.roomIndex);
      break;
    }
    case 'deactivate-room': {
      G.effects.deactivatedRooms = G.effects.deactivatedRooms || [];
      G.effects.deactivatedRooms.push({ playerId: option.playerId, roomIndex: option.roomIndex });
      G.logs.push(`${choice.bossName}: ${option.room?.name || 'a room'} deactivated.`);
      break;
    }
    case 'smithy-item': {
      const heroes = heroesWithoutItem(G);
      if (!heroes.length) return 'no hero without an item';
      if (heroes.length === 1) {
        attachSmithyItem(G, playerId, option.itemIndex, heroes[0], choice.roomIndex);
        break;
      }
      G.pendingChoice = {
        type: 'smithy-hero',
        resume: false,
        playerId: Number(playerId),
        bossName: 'Orcish Smithy',
        message: 'Orcish Smithy: choose a Hero to attach the Item',
        itemIndex: option.itemIndex,
        roomIndex: choice.roomIndex,
        options: heroes,
      };
      return null;
    }
    case 'smithy-hero': {
      attachSmithyItem(G, playerId, choice.itemIndex, option, choice.roomIndex);
      break;
    }
    default:
      return 'unknown choice type';
  }
  finishChoice(G);
  return null;
}

// AI auto-resolve: returns the best option index for a pending choice.
export function aiResolveLevelUpChoice(G, choice) {
  if (!choice || !choice.options || choice.options.length === 0) return 0;
  switch (choice.type) {
    case 'discard-spell': {
      // Discard the spell with lowest strategic value (first one is fine)
      return 0;
    }
    case 'steal-card': {
      // Steal the first available card (can't know value in real game either)
      return Math.floor(Math.random() * choice.options.length);
    }
    case 'destroy-room': {
      // Destroy the weakest room (lowest damage)
      let weakest = 0;
      let minDmg = Infinity;
      choice.options.forEach((opt, i) => {
        const dmg = opt.room?.damage || 0;
        if (dmg < minDmg) { minDmg = dmg; weakest = i; }
      });
      return weakest;
    }
    case 'search-spell': {
      return 0;
    }
    case 'swap-rooms': {
      if (choice.optional && !choice.first) {
        const own = (choice.options || []).filter((o) => Number(o.playerId) === Number(choice.playerId));
        if (own.length < 2) return -1;
      }
      if (choice.first) {
        const same = (choice.options || []).findIndex((o) => Number(o.playerId) === Number(choice.first.playerId));
        return same >= 0 ? same : 0;
      }
      const own = (choice.options || []).filter((o) => Number(o.playerId) === Number(choice.playerId));
      if (own.length >= 1) return choice.options.indexOf(own[0]);
      return 0;
    }
    case 'discard-monster':
      return 0;
    case 'recover-card':
      return 0;
    case 'pick-hero':
    case 'kill-hero':
      return 0;
    case 'pick-dungeon': {
      const opp = (choice.options || []).findIndex((o) => Number(o.targetPlayerId) !== Number(choice.playerId));
      return opp >= 0 ? opp : 0;
    }
    case 'rearrange-dungeon':
      return Math.max(0, (choice.options || []).length - 1);
    case 'haunted-library':
      return 1;
    case 'search-advanced':
    case 'build-over':
    case 'pick-opponent':
    case 'pick-soul':
    case 'discard-hand-rooms':
    case 'pick-item':
    case 'deactivate-room':
    case 'smithy-item':
    case 'smithy-hero':
      return 0;
    default:
      return 0;
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
  if (room.usedThisTurn) return 'already used this turn';
  if (G.phase === PHASE.ADVENTURE && dungeonIgnoresRoomAbilities(G, playerId)) {
    return 'activated abilities cannot be used';
  }

  switch (room.id) {
    case 'BMA009': { // Dark Altar: destroy this room → choose a card from the discard
      destroyRoom(G, playerId, roomIndex);
      const opts = discardCardOptions(G, 'any');
      if (opts.length === 0) {
        G.logs.push('Dark Altar: discard piles are empty.');
        return null;
      }
      if (opts.length === 1) {
        takeDiscardCard(G, player, opts[0]);
        G.logs.push(`Dark Altar: recovered ${opts[0].card.name}.`);
        return null;
      }
      G.pendingChoice = {
        type: 'recover-card',
        resume: false,
        playerId: Number(playerId),
        bossName: 'Dark Altar',
        message: 'Dark Altar: choose a card from the discard pile',
        options: opts,
      };
      return null;
    }
    case 'BMA027': { // Bottomless Pit: destroy this room → kill a Hero in this room
      if (!heroIsInRoom(G, playerId, roomIndex)) return 'no hero in this room';
      G.adventure.hp = 0;
      G._deathRoom = room;
      G.logs.push(`Bottomless Pit: killed ${G.adventure.hero.name}.`);
      destroyRoom(G, playerId, roomIndex);
      return null;
    }
    case 'BMA028': { // Boulder Ramp: destroy another room → 5 damage to a hero in this room
      if (otherRoomIndex == null || otherRoomIndex === roomIndex) return 'must target another room';
      const other = activeRoom(player.dungeon[otherRoomIndex]);
      if (!other) return 'no room at other index';
      if (!heroIsInRoom(G, playerId, roomIndex)) return 'no hero in this room';
      G.adventure.hp -= 5;
      G._deathRoom = room;
      G.logs.push(`Boulder Ramp: dealt 5 damage to ${G.adventure.hero.name} (HP ${G.adventure.hp}).`);
      destroyRoom(G, playerId, otherRoomIndex);
      G.logs.push(`Boulder Ramp: destroyed ${other.name}.`);
      room.usedThisTurn = true;
      return null;
    }
    case 'BMA030': { // Jackpot Stash: destroy this room → double treasure value this turn
      // Mark this player's treasures as doubled for bait resolution this turn.
      if (!G.effects.treasureDoubled) G.effects.treasureDoubled = [];
      G.effects.treasureDoubled.push(playerId);
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
      room.usedThisTurn = true;
      return null;
    }
    case 'BMA038': { // Torture Chamber: destroy this room → choose opponent, they discard a random room
      const opps = opponentsWith(G, playerId, (p) => (p.hand || []).some((c) => c.isRoom));
      if (!opps.length) {
        G.logs.push('Torture Chamber: no opponent has a Room to discard.');
        destroyRoom(G, playerId, roomIndex);
        return null;
      }
      if (opps.length === 1) {
        discardRandomRoomFromHand(G, opps[0][0], 'Torture Chamber');
        destroyRoom(G, playerId, roomIndex);
        return null;
      }
      G.pendingChoice = pickOpponentChoice(
        G, playerId, 'Torture Chamber', 'Choose an opponent to discard a random Room', 'discard-room', opps,
        { resume: false, destroyRoomIndex: roomIndex }
      );
      return null;
    }
    case 'BMA039': { // Zombie Prison: choose a dead Hero in an opponent's scorekeeping area
      const options = deadHeroOptions(G, playerId);
      if (!options.length) return 'no dead hero in an opponent\'s scorekeeping area';
      if (options.length === 1) {
        const opt = options[0];
        const from = G.players[opt.fromPid];
        const soul = from[opt.pile].splice(opt.soulIndex, 1)[0];
        from.entrance = from.entrance || [];
        from.entrance.push(reviveFromSoul(soul, 0));
        G.logs.push(`Zombie Prison: sent ${soul.name || 'a Hero'} to Player ${opt.fromPid}'s entrance.`);
        destroyRoom(G, playerId, roomIndex);
        return null;
      }
      G.pendingChoice = {
        type: 'pick-soul',
        action: 'revive',
        resume: false,
        playerId: Number(playerId),
        bossName: 'Zombie Prison',
        message: 'Zombie Prison: choose a dead Hero to send back',
        options,
        destroyRoomIndex: roomIndex,
      };
      return null;
    }
    case 'BMA013': { // Dracolich Lair: discard 2 rooms → recover a room from discard
      const roomsInHand = handRoomOptions(player);
      if (roomsInHand.length < 2) return 'not enough rooms in hand';
      G.pendingChoice = {
        type: 'discard-hand-rooms',
        resume: false,
        playerId: Number(playerId),
        bossName: 'Dracolich Lair',
        message: 'Dracolich Lair: discard 2 Room cards (2 remaining)',
        remaining: 2,
        then: 'recover-room',
        roomIndex,
        options: roomsInHand,
      };
      return null;
    }
    case 'BMA024': { // Witch's Kitchen: discard a Monster Room to draw a Spell
      if (G.phase !== PHASE.BUILD) return 'only during the Build phase';
      const monsters = player.hand.map((c, i) => ({ c, i })).filter(({ c }) => c.isRoom && c.type === 'monster');
      if (!monsters.length) return 'no monster room in hand';
      if (monsters.length === 1) {
        applyWitchKitchenDiscard(G, player, monsters[0].i);
        room.usedThisTurn = true;
        return null;
      }
      G.pendingChoice = {
        type: 'discard-monster',
        resume: false,
        playerId: Number(playerId),
        bossName: "Witch's Kitchen",
        message: 'Discard a Monster Room to draw a Spell',
        options: monsters.map(({ c, i }) => ({ card: c, handIndex: i })),
        roomIndex,
      };
      return null;
    }
    case 'BMA025': { // All-Seeing Eye: discard a Spell to cancel an opponent's Spell
      if (!(G.stack?.length)) return 'no spell to cancel';
      const spells = player.hand.map((c, i) => ({ card: c, handIndex: i })).filter((o) => o.card.isSpell);
      if (!spells.length) return 'no spell to discard';
      if (spells.length === 1) {
        const discarded = player.hand.splice(spells[0].handIndex, 1)[0];
        G.decks.spellDiscard.push(discarded);
        const top = G.stack.pop();
        if (top?.card) {
          G.decks.spellDiscard.push(top.card);
          G.logs.push(`All-Seeing Eye: discarded ${discarded.name} to cancel ${top.card.name}.`);
        } else {
          G.logs.push(`All-Seeing Eye: discarded ${discarded.name} to cancel a spell.`);
        }
        G._spellCancelled = true;
        room.usedThisTurn = true;
        return null;
      }
      G.pendingChoice = {
        type: 'discard-spell',
        resume: false,
        thenCancel: true,
        playerId: Number(playerId),
        bossName: 'All-Seeing Eye',
        message: 'All-Seeing Eye: choose a Spell to discard',
        options: spells,
        roomIndex,
      };
      return null;
    }
    case 'THK021': { // Orcish Smithy: attach an unattached town Item to any Hero
      if (G.phase !== PHASE.BUILD) return 'only during the Build phase';
      const items = G.townItems || [];
      if (!items.length) return 'no unattached item in town';
      const heroes = heroesWithoutItem(G);
      if (!heroes.length) return 'no hero without an item';
      if (items.length === 1 && heroes.length === 1) {
        attachSmithyItem(G, playerId, 0, heroes[0], roomIndex);
        return null;
      }
      if (items.length === 1) {
        G.pendingChoice = {
          type: 'smithy-hero',
          resume: false,
          playerId: Number(playerId),
          bossName: 'Orcish Smithy',
          message: 'Orcish Smithy: choose a Hero to attach the Item',
          itemIndex: 0,
          roomIndex,
          options: heroes,
        };
        return null;
      }
      G.pendingChoice = {
        type: 'smithy-item',
        resume: false,
        playerId: Number(playerId),
        bossName: 'Orcish Smithy',
        message: 'Orcish Smithy: choose an unattached Item',
        roomIndex,
        options: items.map((it, i) => ({ card: it, itemIndex: i })),
      };
      return null;
    }
    case 'THK022': { // Burial Mound: discard 2 rooms, flip a face-down Item face-up
      const roomsInHand = handRoomOptions(player);
      if (roomsInHand.length < 2) return 'not enough rooms in hand';
      G.pendingChoice = {
        type: 'discard-hand-rooms',
        resume: false,
        playerId: Number(playerId),
        bossName: 'Burial Mound',
        message: 'Burial Mound: discard 2 Room cards (2 remaining)',
        remaining: 2,
        then: 'flip-item-up',
        roomIndex,
        options: roomsInHand,
      };
      return null;
    }
    case 'THK023': { // Artificer's Workbench: flip a face-up Item face-down, draw a Spell
      const items = (player.items || []).map((it, i) => ({ card: it, itemIndex: i })).filter((o) => !o.card.faceDown);
      if (!items.length) return 'no face-up item';
      if (items.length === 1) {
        items[0].card.faceDown = true;
        const spell = drawCards(G.decks.spells, 1)[0];
        if (spell) {
          player.hand.push(spell);
          G.logs.push(`Artificer's Workbench: flipped ${items[0].card.name} face-down, drew ${spell.name}.`);
        } else {
          G.logs.push(`Artificer's Workbench: flipped ${items[0].card.name} face-down.`);
        }
        room.usedThisTurn = true;
        return null;
      }
      G.pendingChoice = {
        type: 'pick-item',
        action: 'flip-down',
        resume: false,
        playerId: Number(playerId),
        bossName: "Artificer's Workbench",
        message: "Artificer's Workbench: choose a face-up Item to flip down",
        options: items,
        roomIndex,
      };
      return null;
    }
    default:
      return 'no activated ability for this room';
  }
}
