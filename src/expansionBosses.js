// Expansion boss level-ups and ongoing abilities (TNL / RMB / CRL).
import { activeRoom, destroyRoom, healOneWound, dungeonTreasures } from './engine.js';
import { drawCards } from './cardData.js';
import { gainCoin } from './minibosses.js';

function player(G, playerId) {
  return G.players[playerId] ?? G.players[String(playerId)];
}

function bossOptions(G, excludePid) {
  return Object.entries(G.players)
    .filter(([pid, p]) => !p.eliminated && Number(pid) !== Number(excludePid) && p.boss)
    .map(([pid, p]) => ({ boss: p.boss, playerId: Number(pid) }));
}

export function processExpansionLevelUp(G, playerId, boss) {
  const p = player(G, playerId);
  if (!p || !boss) return null;
  const id = boss.id;

  switch (id) {
    case 'TNL000': { // Mirrax — copy another boss treasure
      const opts = bossOptions(G, playerId);
      if (!opts.length) {
        G.logs.push('Mirrax: no other Boss to copy treasure from.');
        return null;
      }
      if (opts.length === 1) {
        const t = opts[0].boss.treasures?.[0] || 1;
        p.bonusTreasures = [...(p.bonusTreasures || []), t];
        G.logs.push(`Mirrax: gained treasure type ${t}.`);
        return null;
      }
      return {
        type: 'pick-boss-treasure',
        playerId: Number(playerId),
        bossName: 'Mirrax',
        message: 'Mirrax: choose a Boss to copy its treasure icon',
        options: opts,
      };
    }
    case 'TNL001': // Doc Scarecrow — mark hero unlureable
      p.docScarecrow = true;
      G.logs.push('Doc Scarecrow: you may mark a town Hero unlureable each Build phase.');
      return null;
    case 'TNL002': // Belladonna — heal wound
      healOneWound(p);
      G.logs.push('Belladonna: healed a Wound.');
      return null;
    case 'TNL003': // Torix — recover destroyed monsters
      p.recoverDestroyedMonsters = true;
      G.logs.push('Torix: you may recover destroyed Monster Rooms.');
      return null;
    case 'TNL004': // Killa — last room +3 if 3+ wounds
      p.killaBoost = true;
      G.logs.push('Killa: last room +3 when you have 3+ Wounds.');
      return null;
    case 'TNL005': // Shellda — EOT swap rooms
      p.shelldaSwap = true;
      G.logs.push('Shellda: may swap two Rooms in a dungeon at end of turn.');
      return null;
    case 'TNL006': // Smoake — draw on build monster
      p.smoakeDraw = true;
      G.logs.push('Smoake: draw a Room when you build a Monster Room.');
      return null;
    case 'TNL007': { // Eclipse — discard hand, draw 3 spells
      p.hand.filter((c) => c.isSpell).forEach((c) => G.decks.spellDiscard.push(c));
      p.hand = p.hand.filter((c) => !c.isSpell);
      const drawn = drawCards(G.decks.spells, 3);
      p.hand.push(...drawn);
      G.logs.push(`Eclipse: drew ${drawn.length} Spell(s).`);
      return null;
    }
    case 'TNL008': // Dr. Timebender — cancel opponent spell once/turn
      p.timebenderCancel = true;
      G.logs.push('Dr. Timebender: may cancel an opponent Spell once per turn.');
      return null;
    case 'TNL009': // Porkus — draw spell if behind on souls
      p.porkusDraw = true;
      G.logs.push('Porkus: may draw a Spell at end of turn if behind on Souls.');
      return null;
    case 'TNL010': { // Necromancer boss — remove soul, search hero
      const souls = (p.souls || []).map((s, i) => ({ soul: s, index: i }))
        .filter((o) => !o.soul.tpk && o.soul.faceDown !== false);
      if (!souls.length) {
        G.logs.push('Necromancer: no face-down Hero to remove.');
        return null;
      }
      return {
        type: 'remove-soul-search-hero',
        playerId: Number(playerId),
        bossName: boss.name,
        message: 'Remove a face-down Hero, then search Hero decks',
        options: souls,
      };
    }
    case 'TNL011': // Grave Robber — draw room on kill
      p.drawRoomOnKill = true;
      G.logs.push('Grave Robber: draw a Room when you kill a Hero.');
      return null;
    case 'TNL012': // Azarella — +3 on uncover when destroy
      p.azarellaUncover = true;
      G.logs.push('Azarella: uncovered Rooms gain +3 until end of turn.');
      return null;
    case 'RMB001':
      p.gregoreCoin = true;
      G.logs.push('Gregore: gain a Coin when you kill a Hero (once per turn).');
      return null;
    case 'RMB002':
      p.calabezaPromote = true;
      G.logs.push('Calabeza: may discard a Monster Room to promote a Miniboss.');
      return null;
    case 'RMB003':
      p.belladonnaForce = true;
      G.logs.push('Belladonna: may pay 2 Coins to force an opponent to discard a Spell.');
      return null;
    case 'RMB004': // Lamia
      p.lamiaCoin = true;
      G.logs.push('Lamia: gain (c) whenever you build a Monster Room.');
      return null;
    case 'RMB005': // King Croak
      p.croakMinibossLevel2 = true;
      G.logs.push('King Croak: Minibosses that you build start on Level 2.');
      return null;
    case 'RMB006': // Ravenus
      p.ravenusDouble = true;
      G.logs.push('Ravenus: may pay 2 Coins to double the damage of a Monster Room.');
      return null;
    case 'RMB007': // Baron Hex
      p.baronHexCoin = true;
      G.logs.push('Baron Hex: gain (c) whenever you cast a Spell.');
      return null;
    case 'RMB008': // Oculus
      p.oculusSpell = true;
      G.logs.push('Oculus: draw a Spell when a Hero dies in a room with a Miniboss.');
      return null;
    case 'RMB009': // Kazanna
      p.kazannaSpell = true;
      G.logs.push('Kazanna: may pay 2 Coins to draw a Spell.');
      return null;
    case 'RMB010': // Dr. Deadly
      p.deadlyTrapCoin = true;
      G.logs.push('Dr. Deadly: gain (c) whenever you build a Trap Room.');
      return null;
    case 'RMB011': // Scott
      p.scottTrapBonus = true;
      G.logs.push('Scott: your Trap Rooms have +1 damage.');
      return null;
    case 'RMB012': // Kirax
      p.kiraxKillCoin = true;
      G.logs.push('Kirax: gain (c) when a Hero dies in your dungeon (once per turn).');
      return null;
    case 'CRL001':
      p.imperiatrix = true;
      G.logs.push('Imperiatrix: Rooms gain +1 per Explorer treasure icon.');
      return null;
    case 'CRL002': {
      const opts = bossOptions(G, playerId);
      if (!opts.length) return null;
      if (opts.length === 1) {
        p.copiedLevelUp = opts[0].boss.id;
        G.logs.push(`Klonos: copied ${opts[0].boss.name} level-up.`);
        return null;
      }
      return {
        type: 'pick-boss-levelup',
        playerId: Number(playerId),
        bossName: 'Klonos',
        message: 'Klonos: choose a Boss to copy its Level Up ability',
        options: opts,
      };
    }
    case 'CRL003': {
      const options = [];
      for (const [opid, op] of Object.entries(G.players)) {
        if (Number(opid) === Number(playerId) || op.eliminated) continue;
        (op.dungeon || []).forEach((stack, ri) => {
          if (stack.length > 1) {
            const covered = stack[stack.length - 2];
            options.push({ targetPlayerId: Number(opid), roomIndex: ri, room: covered });
          }
        });
      }
      if (!options.length) {
        G.logs.push('Mando: no covered Rooms to bring to top.');
        return null;
      }
      return {
        type: 'uncover-room',
        playerId: Number(playerId),
        bossName: 'Mando',
        message: 'Bring one covered Room to the top of each opponent dungeon (optional)',
        optional: true,
        options,
      };
    }
    default:
      return undefined;
  }
}

export function onExpansionBossKill(G, playerId, deathRoom = null) {
  const p = player(G, playerId);
  if (!p) return;
  if (p.gregoreCoin && !p._gregoreUsed) {
    p._gregoreUsed = true;
    gainCoin(G, playerId, 1, 'Gregore');
  }
  if (p.kiraxKillCoin && !p._kiraxUsed) {
    p._kiraxUsed = true;
    gainCoin(G, playerId, 1, 'Kirax');
  }
  if (p.oculusSpell && (deathRoom?.miniboss || G.adventure?.room?.miniboss)) {
    const card = G.decks.spells.pop();
    if (card) {
      p.hand.push(card);
      G.logs.push(`Oculus: drew ${card.name}.`);
    }
  }
  if (p.drawRoomOnKill) {
    const card = G.decks.rooms.pop();
    if (card) {
      p.hand.push(card);
      G.logs.push(`Grave Robber: drew ${card.name}.`);
    }
  }
}

export function onExpansionBuildMonster(G, playerId, room) {
  const p = player(G, playerId);
  if (!p || room?.type !== 'monster') return;
  if (p.smoakeDraw) {
    const card = G.decks.rooms.pop();
    if (card) {
      p.hand.push(card);
      G.logs.push(`Smoake: drew ${card.name}.`);
    }
  }
  if (p.lamiaCoin) {
    gainCoin(G, playerId, 1, 'Lamia');
  }
}

export function onExpansionBuildRoom(G, playerId, room) {
  const p = player(G, playerId);
  if (!p || !room) return;
  if (room.type === 'monster') {
    onExpansionBuildMonster(G, playerId, room);
  }
  if (room.type === 'trap' && p.deadlyTrapCoin) {
    gainCoin(G, playerId, 1, 'Dr. Deadly');
  }
}

export function onExpansionCastSpell(G, playerId) {
  const p = player(G, playerId);
  if (!p) return;
  if (p.baronHexCoin) {
    gainCoin(G, playerId, 1, 'Baron Hex');
  }
}

export function scottDamageBonus(G, playerId, room) {
  const p = player(G, playerId);
  if (!p?.scottTrapBonus || !room || room.type !== 'trap' || p._scottCanceledThisTurn) return 0;
  return 1;
}

export function imperiatrixDamageBonus(G, playerId, room) {
  const p = player(G, playerId);
  if (!p?.imperiatrix || !room) return 0;
  const explorers = (room.treasures || []).filter((t) => t === 5).length;
  return explorers;
}

export function killaDamageBonus(G, playerId, roomIndex) {
  const p = player(G, playerId);
  if (!p?.killaBoost) return 0;
  const wounds = (p.wounds || []).length;
  if (wounds < 3) return 0;
  if (roomIndex === p.dungeon.length - 1) return 3;
  return 0;
}

export function resolveExpansionLevelUpChoice(G, choice, optionIndex) {
  const opt = choice.options?.[optionIndex];
  const p = player(G, choice.playerId);
  if (!p || !opt) return;
  switch (choice.type) {
    case 'pick-boss-treasure': {
      const t = opt.boss.treasures?.[0] || 1;
      p.bonusTreasures = [...(p.bonusTreasures || []), t];
      G.logs.push(`Mirrax: gained treasure type ${t}.`);
      break;
    }
    case 'pick-boss-levelup':
      p.copiedLevelUp = opt.boss.id;
      G.logs.push(`Klonos: copied ${opt.boss.name} level-up.`);
      break;
    case 'uncover-room': {
      const stack = G.players[opt.targetPlayerId]?.dungeon[opt.roomIndex];
      if (stack?.length > 1) {
        const covered = stack.splice(stack.length - 2, 1)[0];
        stack.push(covered);
        G.logs.push(`Mando: uncovered ${covered.name} in Player ${opt.targetPlayerId}'s dungeon.`);
      }
      break;
    }
    default:
      break;
  }
}
