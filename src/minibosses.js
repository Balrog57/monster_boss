// minibosses.js - Rise of the Minibosses: Coins, build, reveal, promote, abilities.
import { activeRoom } from './engine.js';
import { drawCards } from './cardData.js';

const TREASURE_MB = {
  RMB056: 2, // Kid Croak — Fighter
  RMB057: 1, // Draculad — Cleric
  RMB059: 3, // Cerebella — Mage
  RMB060: 4, // Paddywhack — Thief
};

const DAMAGE_PLUS_ONE = new Set(['RMB055', 'RMB061', 'RMB063']);

export function initPlayerCoins(player) {
  player.coins = player.coins || 0;
}

export function gainCoin(G, playerId, n = 1, reason = '') {
  const p = G.players[playerId] ?? G.players[String(playerId)];
  if (!p) return;
  p.coins = (p.coins || 0) + n;
  G.logs.push(`${reason || 'Coin'}: Player ${playerId} gains ${n} Coin(s) (total ${p.coins}).`);
  maybePaddywhackBonus(G, playerId, n);
}

function maybePaddywhackBonus(G, playerId, n) {
  if (n < 1) return;
  const p = G.players[playerId] ?? G.players[String(playerId)];
  if (!p) return;
  for (const stack of p.dungeon || []) {
    const mb = stack.miniboss;
    if (!mb || mb.faceDown || mb.card?.id !== 'RMB060' || mb.level < 2) continue;
    if (mb.usedThisTurn) continue;
    mb.usedThisTurn = true;
    p.coins = (p.coins || 0) + 1;
    G.logs.push(`Paddywhack: +1 extra Coin (total ${p.coins}).`);
    return;
  }
}

export function spendCoin(G, playerId, n = 1) {
  const p = G.players[playerId] ?? G.players[String(playerId)];
  if (!p || (p.coins || 0) < n) return false;
  p.coins -= n;
  return true;
}

/** Miniboss attached to a room stack. */
export function getMiniboss(stack) {
  return stack?.miniboss || null;
}

export function attachMiniboss(stack, card, level = 1) {
  stack.miniboss = { card, level, usedL3: false, usedThisTurn: false, faceDown: true };
}

export function canBuildMiniboss(G, playerId) {
  if (G.effects?.buildBlocked) return false;
  const p = G.players[playerId] ?? G.players[String(playerId)];
  if (!p || (p.buildsThisTurn || 0) >= 1) return false;
  if (!(G.decks.minibosses?.length || 0)) return false;
  return (p.dungeon || []).some((stack) => activeRoom(stack) && !stack.miniboss);
}

export function buildMiniboss(G, playerId, handIndex, targetRoomIndex) {
  const p = G.players[playerId] ?? G.players[String(playerId)];
  const stack = p?.dungeon[targetRoomIndex];
  if (!stack || stack.miniboss || !activeRoom(stack)) return false;
  const mbCard = G.decks.minibosses?.pop();
  if (!mbCard) return false;
  const initLevel = p?.croakMinibossLevel2 ? 2 : 1;
  attachMiniboss(stack, mbCard, initLevel);
  p.buildsThisTurn = (p.buildsThisTurn || 0) + 1;
  p.hasActed = true;
  G.logs.push(`Player ${playerId} built ${mbCard.name} face-down on a Room.`);
  return true;
}

/** Reveal miniboss at end of BUILD: pay 1 Coin or discard. */
export function revealMinibosses(G, ctx) {
  for (const pid of Object.keys(G.players)) {
    const p = G.players[pid];
    if (p.eliminated) continue;
    for (const stack of p.dungeon || []) {
      const mb = stack.miniboss;
      if (!mb || !mb.faceDown) continue;
      if (spendCoin(G, pid, 1)) {
        mb.faceDown = false;
        G.logs.push(`${mb.card.name} revealed (Level ${mb.level}).`);
      } else {
        discardMiniboss(stack, G);
        G.logs.push(`${mb.card.name} discarded (no Coin to reveal).`);
      }
    }
  }
}

function discardMiniboss(stack, G) {
  const mb = stack?.miniboss;
  if (!mb) return;
  G.decks.minibossDiscard = G.decks.minibossDiscard || [];
  G.decks.minibossDiscard.push(mb.card);
  delete stack.miniboss;
}

export function canPromoteMiniboss(G, playerId, roomIndex) {
  const stack = G.players[playerId]?.dungeon[roomIndex];
  const mb = stack?.miniboss;
  if (!mb || mb.faceDown || mb.level >= 3) return false;
  return (G.players[playerId]?.coins || 0) >= 1;
}

export function promoteMiniboss(G, playerId, roomIndex) {
  const stack = G.players[playerId]?.dungeon[roomIndex];
  const mb = stack?.miniboss;
  if (!mb || mb.faceDown || mb.level >= 3) return 'cannot promote';
  if (!spendCoin(G, playerId, 1)) return 'need 1 Coin';
  mb.level += 1;
  G.logs.push(`${mb.card.name} promoted to Level ${mb.level}.`);
  if (mb.card.id === 'RMB202' && mb.level === 2) {
    const p = G.players[playerId];
    const drawn = drawCards(G.decks.rooms, 1);
    if (drawn.length) {
      p.hand.push(drawn[0]);
      G.logs.push(`Zara the Zealous: drew ${drawn[0].name}.`);
    }
  }
  return null;
}

function revealedMb(stack) {
  const mb = stack?.miniboss;
  return mb && !mb.faceDown ? mb : null;
}

export function rockyAllowsAnyBuild(stack) {
  const mb = revealedMb(stack);
  return !!(mb && mb.card?.id === 'RMB058' && mb.level >= 1);
}

/** Extra treasure icons from miniboss L1 (and Jinx L2 double). */
export function minibossExtraTreasures(stack) {
  const mb = revealedMb(stack);
  if (!mb) return [];
  const room = activeRoom(stack);
  const extras = [];
  const tid = TREASURE_MB[mb.card.id];
  if (tid != null && mb.level >= 1) extras.push(tid);
  if (mb.card.id === 'RMB064' && mb.level >= 2 && room) {
    extras.push(...(room.treasures || []));
  }
  return extras;
}

export function minibossDamageBonus(stack) {
  const mb = revealedMb(stack);
  if (!mb) return 0;
  if (mb.card.id === 'RMB201') return mb.level >= 2 ? 2 : 1;
  if (DAMAGE_PLUS_ONE.has(mb.card.id) && mb.level >= 1) return 1;
  if (mb.card.id === 'RMB062' && mb.level >= 1) {
    const room = activeRoom(stack);
    return (room?.treasures || []).length;
  }
  return 0;
}

/** Icicle Man L2+: ignore hero ability text in this dungeon. */
export function icicleIgnoresHeroAbilities(G, playerId) {
  if ((G.effects?.ignoreHeroAbilityPids || []).some((id) => Number(id) === Number(playerId))) {
    return true;
  }
  const p = G.players[playerId] ?? G.players[String(playerId)];
  return (p?.dungeon || []).some((stack) => {
    const mb = revealedMb(stack);
    return mb && mb.card?.id === 'RMB061' && mb.level >= 2;
  });
}

function resetMinibossLevel(mb) {
  mb.level = 1;
  mb.usedL3 = false;
  mb.usedThisTurn = false;
}

function listDungeonRoomOptions(G) {
  const options = [];
  for (const [pid, p] of Object.entries(G.players || {})) {
    if (p.eliminated) continue;
    (p.dungeon || []).forEach((stack, i) => {
      if (activeRoom(stack)) {
        options.push({
          playerId: Number(pid),
          roomIndex: i,
          room: activeRoom(stack),
          label: `P${pid}: ${activeRoom(stack).name}`,
        });
      }
    });
  }
  return options;
}

function heroInThisRoom(G, playerId, roomIndex) {
  const adv = G.adventure;
  if (adv && Number(adv.playerId) === Number(playerId) && adv.roomIndex === roomIndex && adv.hero) {
    return { kind: 'adventure', hero: adv.hero };
  }
  return null;
}

function heroesInOwnDungeon(G, playerId) {
  const p = G.players[playerId];
  const opts = [];
  if (G.adventure && Number(G.adventure.playerId) === Number(playerId) && G.adventure.hero) {
    opts.push({ kind: 'adventure', label: `${G.adventure.hero.name} (in dungeon)`, hero: G.adventure.hero });
  }
  (p?.entrance || []).forEach((hero, index) => {
    opts.push({ kind: 'entrance', index, label: `${hero.name} (entrance)`, hero });
  });
  return opts;
}

function listAllMinibosses(G) {
  const opts = [];
  for (const [pid, p] of Object.entries(G.players || {})) {
    if (p.eliminated) continue;
    (p.dungeon || []).forEach((stack, i) => {
      const mb = stack.miniboss;
      if (mb) {
        opts.push({
          playerId: Number(pid),
          roomIndex: i,
          mb,
          label: `P${pid}: ${mb.card?.name || 'Miniboss'} (L${mb.level}${mb.faceDown ? ', hidden' : ''})`,
        });
      }
    });
  }
  return opts;
}

function canActivateL2(G, playerId, roomIndex, mb) {
  if (mb.level < 2 || mb.usedThisTurn) return false;
  const id = mb.card.id;
  if (id === 'RMB055') {
    const p = G.players[playerId];
    return (p?.hand?.length || 0) > 0 && !!heroInThisRoom(G, playerId, roomIndex);
  }
  if (id === 'RMB056') {
    return G.phase === 'build' && listDungeonRoomOptions(G).length >= 2;
  }
  if (id === 'RMB057') {
    return heroesInOwnDungeon(G, playerId).length > 0;
  }
  if (id === 'RMB062') {
    const p = G.players[playerId];
    return (G.stack?.length || 0) > 0 && (p?.hand || []).some((c) => c.isSpell);
  }
  // Passive L2: Rocky, Cerebella, Paddywhack, Icicle, Brassknuckle, Jinx — not activates
  return false;
}

function canActivateL3(G, playerId, roomIndex, mb) {
  if (mb.level < 3 || mb.usedL3) return false;
  const id = mb.card.id;
  if (id === 'RMB201') {
    const p = G.players[playerId];
    const inAdv = G.adventure && Number(G.adventure.playerId) === Number(playerId);
    return inAdv || (p.entrance?.length > 0);
  }
  if (id === 'RMB060') return !!heroInThisRoom(G, playerId, roomIndex);
  if (id === 'RMB064') return (G.town || []).length > 0;
  return true;
}

export function canActivateMiniboss(G, playerId, roomIndex, mode = null) {
  if (G.phase !== 'build' && G.phase !== 'adventure') return false;
  const stack = G.players[playerId]?.dungeon[roomIndex];
  const mb = revealedMb(stack);
  if (!mb) return false;
  if (mode === 'l2') return canActivateL2(G, playerId, roomIndex, mb);
  if (mode === 'l3') return canActivateL3(G, playerId, roomIndex, mb);
  return canActivateL2(G, playerId, roomIndex, mb) || canActivateL3(G, playerId, roomIndex, mb);
}

function applyGrukDamage(G, playerId, option) {
  const p = G.players[playerId];
  if (option.kind === 'adventure' && G.adventure?.hero) {
    G.adventure.hp = Math.max(0, (G.adventure.hp ?? G.adventure.hero.hp) - 5);
    G.logs.push(`Gruk the Greedy: 5 damage to ${G.adventure.hero.name} (HP ${G.adventure.hp}).`);
    return;
  }
  if (option.kind === 'entrance' && p.entrance?.[option.index]) {
    const hero = p.entrance[option.index];
    hero._entranceHp = Math.max(0, (hero._entranceHp ?? hero.hp) - 5);
    G.logs.push(`Gruk the Greedy: 5 damage to ${hero.name} waiting at entrance.`);
    if (hero._entranceHp <= 0) {
      p.entrance.splice(option.index, 1);
      G.decks.heroDiscard.push(hero);
      G.logs.push(`${hero.name} was slain before entering the dungeon.`);
    }
  }
}

function dealDamageInRoom(G, playerId, roomIndex, amount, label) {
  const hit = heroInThisRoom(G, playerId, roomIndex);
  if (!hit || !G.adventure) return false;
  G.adventure.hp = Math.max(0, (G.adventure.hp ?? G.adventure.hero.hp) - amount);
  G.logs.push(`${label}: ${amount} damage to ${G.adventure.hero.name} (HP ${G.adventure.hp}).`);
  return true;
}

function returnHeroToTown(G, playerId, option) {
  const p = G.players[playerId];
  if (option.kind === 'adventure' && G.adventure?.hero) {
    const hero = G.adventure.hero;
    G.adventure = null;
    G.town.push(hero);
    G.logs.push(`Draculad: ${hero.name} returned to town.`);
    return;
  }
  if (option.kind === 'entrance' && p.entrance?.[option.index]) {
    const [hero] = p.entrance.splice(option.index, 1);
    G.town.push(hero);
    G.logs.push(`Draculad: ${hero.name} returned to town.`);
  }
}

function killHeroInThisRoom(G, playerId, roomIndex, label) {
  const hit = heroInThisRoom(G, playerId, roomIndex);
  if (!hit || !G.adventure) return false;
  G.adventure.hp = 0;
  G.logs.push(`${label}: ${G.adventure.hero.name} killed.`);
  return true;
}

function activateL2(G, ctx, playerId, roomIndex, mb, stack) {
  const id = mb.card.id;
  const p = G.players[playerId];

  if (id === 'RMB055') {
    const handOpts = (p.hand || []).map((c, i) => ({ handIndex: i, card: c, label: c.name }));
    if (!handOpts.length || !heroInThisRoom(G, playerId, roomIndex)) return 'cannot activate';
    G.pendingChoice = {
      type: 'mb-spike-discard',
      resume: false,
      playerId: Number(playerId),
      roomIndex,
      bossName: 'Spike',
      message: 'Spike: discard a card',
      options: handOpts,
    };
    return null;
  }

  if (id === 'RMB056') {
    const options = listDungeonRoomOptions(G);
    if (options.length < 2) return 'not enough rooms';
    mb.usedThisTurn = true;
    G.pendingChoice = {
      type: 'swap-rooms',
      resume: false,
      playerId: Number(playerId),
      bossName: 'Kid Croak',
      message: 'Kid Croak: choose the first room to swap',
      optional: false,
      options,
    };
    return null;
  }

  if (id === 'RMB057') {
    const options = heroesInOwnDungeon(G, playerId);
    if (!options.length) return 'no hero';
    if (options.length === 1) {
      returnHeroToTown(G, playerId, options[0]);
      mb.usedThisTurn = true;
      return null;
    }
    G.pendingChoice = {
      type: 'mb-draculad-return',
      resume: false,
      playerId: Number(playerId),
      roomIndex,
      bossName: 'Draculad',
      message: 'Draculad: return a Hero to town',
      options,
    };
    return null;
  }

  if (id === 'RMB062') {
    const si = (p.hand || []).findIndex((c) => c.isSpell);
    if (si < 0 || !(G.stack?.length)) return 'cannot cancel';
    const [discarded] = p.hand.splice(si, 1);
    G.decks.spellDiscard.push(discarded);
    const top = G.stack.pop();
    if (top?.card) {
      G.decks.spellDiscard.push(top.card);
      G.logs.push(`Mageseeker: cancelled ${top.card.name} (discarded ${discarded.name}).`);
    } else {
      G.logs.push(`Mageseeker: discarded ${discarded.name}; nothing on the stack.`);
    }
    mb.usedThisTurn = true;
    G.skipAdvance = true;
    if (G.stackReturnPlayer != null && ctx) {
      ctx.activePlayer = G.stackReturnPlayer;
      ctx.currentPlayer = G.stackReturnPlayer;
      G.activePlayer = G.stackReturnPlayer;
    }
    return null;
  }

  return 'unknown L2';
}

function activateL3(G, ctx, playerId, roomIndex, mb, stack) {
  const id = mb.card.id;
  const p = G.players[playerId];

  if (id === 'RMB201') {
    const options = [];
    if (G.adventure && Number(G.adventure.playerId) === Number(playerId) && G.adventure.hero) {
      options.push({ kind: 'adventure', label: `${G.adventure.hero.name} (in dungeon)` });
    }
    (p.entrance || []).forEach((hero, index) => {
      options.push({ kind: 'entrance', index, label: `${hero.name} (entrance)` });
    });
    if (!options.length) return 'no hero in dungeon';
    if (options.length === 1) {
      applyGrukDamage(G, playerId, options[0]);
      discardMiniboss(stack, G);
      return null;
    }
    G.pendingChoice = {
      type: 'gruk-target',
      playerId: Number(playerId),
      roomIndex,
      message: 'Gruk: choose a Hero in your dungeon',
      options,
    };
    return null;
  }

  mb.usedL3 = true;

  if (id === 'RMB202') {
    for (const [oppId, opp] of Object.entries(G.players)) {
      if (Number(oppId) === Number(playerId) || opp.eliminated) continue;
      const rooms = opp.hand.map((c, i) => ({ c, i })).filter(({ c }) => c.isRoom);
      if (!rooms.length) continue;
      const pick = rooms[Math.floor(Math.random() * rooms.length)];
      const [card] = opp.hand.splice(pick.i, 1);
      G.decks.roomDiscard.push(card);
      G.logs.push(`Zara the Zealous: Player ${oppId} discards ${card.name}.`);
    }
    resetMinibossLevel(mb);
    return null;
  }

  if (id === 'RMB055') {
    const options = listAllMinibosses(G);
    if (!options.length) {
      resetMinibossLevel(mb);
      return null;
    }
    if (options.length === 1) {
      returnMinibossToHand(G, options[0]);
      resetMinibossLevel(mb);
      return null;
    }
    G.pendingChoice = {
      type: 'mb-spike-return',
      resume: false,
      playerId: Number(playerId),
      roomIndex,
      bossName: 'Spike',
      message: 'Spike: choose a Miniboss to return to hand',
      options,
    };
    return null;
  }

  if (id === 'RMB056') {
    const dungeons = Object.entries(G.players)
      .filter(([, op]) => !op.eliminated)
      .map(([pid]) => ({
        targetPlayerId: Number(pid),
        label: `Player ${pid}`,
        amount: 1,
      }));
    const opts = [];
    for (const d of dungeons) {
      opts.push({ ...d, amount: 1, label: `P${d.targetPlayerId} Monster Rooms +1` });
      opts.push({ ...d, amount: -1, label: `P${d.targetPlayerId} Monster Rooms -1` });
    }
    G.pendingChoice = {
      type: 'mb-croak-monsters',
      resume: false,
      playerId: Number(playerId),
      roomIndex,
      bossName: 'Kid Croak',
      message: 'Kid Croak: choose a dungeon and +1 or -1',
      options: opts,
    };
    return null;
  }

  if (id === 'RMB057') {
    const opps = Object.entries(G.players)
      .filter(([oid, op]) => Number(oid) !== Number(playerId) && !op.eliminated)
      .map(([oid, op]) => ({
        targetPlayerId: Number(oid),
        label: `Player ${oid} (${op.hand.length} cards)`,
      }));
    if (!opps.length) {
      resetMinibossLevel(mb);
      return null;
    }
    if (opps.length === 1) {
      offerDraculadSteal(G, playerId, roomIndex, opps[0].targetPlayerId);
      return null;
    }
    G.pendingChoice = {
      type: 'mb-draculad-look',
      resume: false,
      playerId: Number(playerId),
      roomIndex,
      bossName: 'Draculad',
      message: "Draculad: look at an opponent's hand",
      options: opps,
    };
    return null;
  }

  if (id === 'RMB058') {
    const options = [];
    for (const [pid, op] of Object.entries(G.players)) {
      if (op.eliminated) continue;
      if (G.adventure && Number(G.adventure.playerId) === Number(pid) && G.adventure.hero) {
        options.push({
          heroId: G.adventure.hero.id,
          playerId: Number(pid),
          kind: 'adventure',
          label: `${G.adventure.hero.name} (P${pid})`,
        });
      }
      (op.entrance || []).forEach((hero) => {
        options.push({
          heroId: hero.id,
          playerId: Number(pid),
          kind: 'entrance',
          label: `${hero.name} entrance (P${pid})`,
        });
      });
    }
    if (!options.length) {
      resetMinibossLevel(mb);
      return null;
    }
    if (options.length === 1) {
      applyRockyBuff(G, options[0]);
      resetMinibossLevel(mb);
      return null;
    }
    G.pendingChoice = {
      type: 'mb-rocky-buff',
      resume: false,
      playerId: Number(playerId),
      roomIndex,
      bossName: 'Rocky',
      message: 'Rocky: give a Hero +5 Health',
      options,
    };
    return null;
  }

  if (id === 'RMB059') {
    const options = Object.entries(G.players)
      .filter(([, op]) => !op.eliminated)
      .map(([pid]) => ({ targetPlayerId: Number(pid), label: `Player ${pid}` }));
    if (options.length === 1) {
      G.effects.ignoreAbilityPids = G.effects.ignoreAbilityPids || [];
      G.effects.ignoreAbilityPids.push(options[0].targetPlayerId);
      G.logs.push(`Cerebella: Heroes ignore ability text in Player ${options[0].targetPlayerId}'s dungeon.`);
      resetMinibossLevel(mb);
      return null;
    }
    G.pendingChoice = {
      type: 'mb-cerebella-ignore',
      resume: false,
      playerId: Number(playerId),
      roomIndex,
      bossName: 'Cerebella',
      message: 'Cerebella: choose a dungeon',
      options,
    };
    return null;
  }

  if (id === 'RMB060') {
    killHeroInThisRoom(G, playerId, roomIndex, 'Paddywhack');
    resetMinibossLevel(mb);
    return null;
  }

  if (id === 'RMB061') {
    const options = listDungeonRoomOptions(G);
    if (!options.length) {
      resetMinibossLevel(mb);
      return null;
    }
    if (options.length === 1) {
      G.effects.deactivatedRooms = G.effects.deactivatedRooms || [];
      G.effects.deactivatedRooms.push({ playerId: options[0].playerId, roomIndex: options[0].roomIndex });
      G.logs.push(`Icicle Man: deactivated ${options[0].room?.name}.`);
      resetMinibossLevel(mb);
      return null;
    }
    G.pendingChoice = {
      type: 'mb-icicle-deactivate',
      resume: false,
      playerId: Number(playerId),
      roomIndex,
      bossName: 'Icicle Man',
      message: 'Icicle Man: deactivate a Room',
      options,
    };
    return null;
  }

  if (id === 'RMB062') {
    const options = Object.entries(G.players)
      .filter(([, op]) => !op.eliminated)
      .map(([pid]) => ({ targetPlayerId: Number(pid), label: `Player ${pid}` }));
    if (options.length === 1) {
      G.effects.skipFirstRoomPids = G.effects.skipFirstRoomPids || [];
      G.effects.skipFirstRoomPids.push(options[0].targetPlayerId);
      G.logs.push(`Mageseeker: Heroes skip the first room in Player ${options[0].targetPlayerId}'s dungeon.`);
      resetMinibossLevel(mb);
      return null;
    }
    G.pendingChoice = {
      type: 'mb-mage-skip',
      resume: false,
      playerId: Number(playerId),
      roomIndex,
      bossName: 'Mageseeker',
      message: 'Mageseeker: choose a dungeon',
      options,
    };
    return null;
  }

  if (id === 'RMB063') {
    G.effects.roomDamageBonus = G.effects.roomDamageBonus || [];
    const room = activeRoom(stack);
    const amount = room?.damage || 0;
    G.effects.roomDamageBonus.push({ playerId: Number(playerId), roomIndex, amount });
    G.logs.push(`Brassknuckle: doubled ${room?.name || 'room'} damage (+${amount}).`);
    resetMinibossLevel(mb);
    return null;
  }

  if (id === 'RMB064') {
    const options = (G.town || []).map((hero, townIndex) => ({
      townIndex,
      hero,
      label: hero.name,
    }));
    if (!options.length) {
      resetMinibossLevel(mb);
      return null;
    }
    if (options.length === 1) {
      const [hero] = G.town.splice(options[0].townIndex, 1);
      p.entrance.push(hero);
      G.logs.push(`Jinx: ${hero.name} placed at your entrance.`);
      resetMinibossLevel(mb);
      return null;
    }
    G.pendingChoice = {
      type: 'mb-jinx-town',
      resume: false,
      playerId: Number(playerId),
      roomIndex,
      bossName: 'Jinx',
      message: 'Jinx: choose a Hero in town',
      options,
    };
    return null;
  }

  return 'unknown miniboss ability';
}

function returnMinibossToHand(G, opt) {
  const stack = G.players[opt.playerId]?.dungeon?.[opt.roomIndex];
  const mb = stack?.miniboss;
  if (!mb) return;
  const owner = G.players[opt.playerId];
  owner.hand.push(mb.card);
  delete stack.miniboss;
  G.logs.push(`Spike: ${mb.card.name} returned to Player ${opt.playerId}'s hand.`);
}

function offerDraculadSteal(G, playerId, roomIndex, targetPlayerId) {
  const opp = G.players[targetPlayerId];
  const options = (opp?.hand || [])
    .map((c, i) => ({ handIndex: i, card: c, label: c.name }))
    .filter((o) => o.card.isSpell || o.card.isRoom);
  const stack = G.players[playerId]?.dungeon?.[roomIndex];
  const mb = stack?.miniboss;
  if (!options.length) {
    G.logs.push('Draculad: no Spell or Room to take.');
    if (mb) resetMinibossLevel(mb);
    return;
  }
  G.pendingChoice = {
    type: 'mb-draculad-steal',
    resume: false,
    playerId: Number(playerId),
    roomIndex,
    targetPlayerId,
    bossName: 'Draculad',
    message: 'Draculad: take a Spell or Room (or skip)',
    optional: true,
    options,
  };
}

function applyRockyBuff(G, option) {
  G.effects.heroHealthBonus = G.effects.heroHealthBonus || [];
  G.effects.heroHealthBonus.push({ heroId: option.heroId, amount: 5 });
  if (G.adventure?.hero?.id === option.heroId) {
    G.adventure.hp = (G.adventure.hp ?? G.adventure.hero.hp) + 5;
  }
  G.logs.push(`Rocky: ${option.label || 'a Hero'} +5 Health.`);
}

export function activateMiniboss(G, ctx, playerId, roomIndex, mode = null) {
  const stack = G.players[playerId]?.dungeon[roomIndex];
  const mb = revealedMb(stack);
  if (!mb) return 'cannot activate miniboss';

  let useMode = mode;
  if (!useMode) {
    const l2 = canActivateL2(G, playerId, roomIndex, mb);
    const l3 = canActivateL3(G, playerId, roomIndex, mb);
    if (l2 && l3) useMode = 'l3';
    else if (l3) useMode = 'l3';
    else if (l2) useMode = 'l2';
    else return 'cannot activate miniboss';
  }

  if (useMode === 'l2') {
    if (!canActivateL2(G, playerId, roomIndex, mb)) return 'cannot activate miniboss';
    return activateL2(G, ctx, playerId, roomIndex, mb, stack);
  }
  if (!canActivateL3(G, playerId, roomIndex, mb)) return 'cannot activate miniboss';
  return activateL3(G, ctx, playerId, roomIndex, mb, stack);
}

export function resolveGrukTarget(G, playerId, roomIndex, option) {
  applyGrukDamage(G, playerId, option);
  const stack = G.players[playerId]?.dungeon[roomIndex];
  if (stack) discardMiniboss(stack, G);
}

/** Resolve pending choices created by miniboss abilities. Returns true if handled. */
export function resolveMinibossPendingChoice(G, ctx, playerId, optionIndex) {
  const choice = G.pendingChoice;
  if (!choice || !String(choice.type || '').startsWith('mb-')) return false;
  const option = optionIndex < 0 ? null : choice.options?.[optionIndex];
  const stack = G.players[playerId]?.dungeon?.[choice.roomIndex];
  const mb = stack?.miniboss;

  switch (choice.type) {
    case 'mb-spike-discard': {
      if (!option) return true;
      const p = G.players[playerId];
      const [card] = p.hand.splice(option.handIndex, 1);
      if (card?.isRoom) G.decks.roomDiscard.push(card);
      else if (card?.isSpell) G.decks.spellDiscard.push(card);
      else if (card?.isMiniboss) {
        G.decks.minibossDiscard = G.decks.minibossDiscard || [];
        G.decks.minibossDiscard.push(card);
      } else G.decks.roomDiscard.push(card);
      dealDamageInRoom(G, playerId, choice.roomIndex, 2, 'Spike');
      if (mb) mb.usedThisTurn = true;
      break;
    }
    case 'mb-spike-return': {
      if (option) returnMinibossToHand(G, option);
      if (mb) resetMinibossLevel(mb);
      break;
    }
    case 'mb-croak-monsters': {
      if (option) {
        const tid = option.targetPlayerId;
        const op = G.players[tid];
        G.effects.roomDamageBonus = G.effects.roomDamageBonus || [];
        (op?.dungeon || []).forEach((s, i) => {
          const room = activeRoom(s);
          if (room?.type === 'monster') {
            G.effects.roomDamageBonus.push({ playerId: tid, roomIndex: i, amount: option.amount });
          }
        });
        G.logs.push(`Kid Croak: Monster Rooms in Player ${tid}'s dungeon ${option.amount > 0 ? '+' : ''}${option.amount}.`);
      }
      if (mb) resetMinibossLevel(mb);
      break;
    }
    case 'mb-draculad-return': {
      if (option) {
        returnHeroToTown(G, playerId, option);
        if (mb) mb.usedThisTurn = true;
      }
      break;
    }
    case 'mb-draculad-look': {
      if (option) offerDraculadSteal(G, playerId, choice.roomIndex, option.targetPlayerId);
      else if (mb) resetMinibossLevel(mb);
      return true; // offerDraculadSteal may set a new pendingChoice
    }
    case 'mb-draculad-steal': {
      if (option) {
        const opp = G.players[choice.targetPlayerId];
        const [card] = opp.hand.splice(option.handIndex, 1);
        G.players[playerId].hand.push(card);
        G.logs.push(`Draculad: took ${card.name} from Player ${choice.targetPlayerId}.`);
      } else {
        G.logs.push('Draculad: declined to take a card.');
      }
      if (mb) resetMinibossLevel(mb);
      break;
    }
    case 'mb-rocky-rebuild': {
      if (option) {
        const room = activeRoom(G.players[playerId]?.dungeon?.[option.roomIndex]);
        if (room) {
          // Lazy import avoided: caller wires onBuildRoom via choice.rebuildHook
          if (typeof choice.onBuild === 'function') choice.onBuild(G, ctx, playerId, room);
          else G.logs.push(`Rocky: treated ${room.name} as just built.`);
        }
      }
      break;
    }
    case 'mb-rocky-buff': {
      if (option) applyRockyBuff(G, option);
      if (mb) resetMinibossLevel(mb);
      break;
    }
    case 'mb-cerebella-ignore': {
      if (option) {
        G.effects.ignoreAbilityPids = G.effects.ignoreAbilityPids || [];
        G.effects.ignoreAbilityPids.push(option.targetPlayerId);
        G.logs.push(`Cerebella: Heroes ignore ability text in Player ${option.targetPlayerId}'s dungeon.`);
      }
      if (mb) resetMinibossLevel(mb);
      break;
    }
    case 'mb-icicle-deactivate': {
      if (option) {
        G.effects.deactivatedRooms = G.effects.deactivatedRooms || [];
        G.effects.deactivatedRooms.push({ playerId: option.playerId, roomIndex: option.roomIndex });
        G.logs.push(`Icicle Man: deactivated ${option.room?.name || 'a Room'}.`);
      }
      if (mb) resetMinibossLevel(mb);
      break;
    }
    case 'mb-mage-skip': {
      if (option) {
        G.effects.skipFirstRoomPids = G.effects.skipFirstRoomPids || [];
        G.effects.skipFirstRoomPids.push(option.targetPlayerId);
        G.logs.push(`Mageseeker: Heroes skip the first room in Player ${option.targetPlayerId}'s dungeon.`);
      }
      if (mb) resetMinibossLevel(mb);
      break;
    }
    case 'mb-jinx-discard': {
      if (option) {
        const p = G.players[playerId];
        const [card] = p.hand.splice(option.handIndex, 1);
        G.decks.roomDiscard.push(card);
        G.logs.push(`Jinx: discarded ${card.name}.`);
      }
      break;
    }
    case 'mb-jinx-town': {
      if (option) {
        const [hero] = G.town.splice(option.townIndex, 1);
        G.players[playerId].entrance.push(hero);
        G.logs.push(`Jinx: ${hero.name} placed at your entrance.`);
      }
      if (mb) resetMinibossLevel(mb);
      break;
    }
    default:
      return false;
  }

  // Clear pending unless a sub-choice was set (draculad-look)
  if (G.pendingChoice === choice) G.pendingChoice = null;
  return true;
}

/** When a hero dies in a room with Rocky/Cerebella/Brassknuckle L2+. */
export function onMinibossHeroDied(G, ctx, playerId, roomIndex, hero) {
  const stack = G.players[playerId]?.dungeon?.[roomIndex];
  const mb = revealedMb(stack);
  if (!mb || mb.level < 2) return;

  if (mb.card.id === 'RMB059') {
    const spell = drawCards(G.decks.spells, 1)[0];
    if (spell) {
      G.players[playerId].hand.push(spell);
      G.logs.push(`Cerebella: drew ${spell.name}.`);
    }
  }

  if (mb.card.id === 'RMB063' && !mb.usedThisTurn) {
    const room = drawCards(G.decks.rooms, 1)[0];
    if (room) {
      G.players[playerId].hand.push(room);
      G.effects.immediateBuild = G.effects.immediateBuild || [];
      G.effects.immediateBuild.push(Number(playerId));
      G.players[playerId].buildsThisTurn = 0;
      mb.usedThisTurn = true;
      G.logs.push(`Brassknuckle: drew ${room.name}; may immediately build it.`);
    }
  }

  if (mb.card.id === 'RMB058') {
    const options = (G.players[playerId].dungeon || [])
      .map((s, i) => ({ roomIndex: i, room: activeRoom(s), label: activeRoom(s)?.name }))
      .filter((o) => o.room && o.roomIndex !== roomIndex);
    if (!options.length) return;
    if (options.length === 1) {
      G._rockyRebuild = { playerId: Number(playerId), roomIndex: options[0].roomIndex };
      G.logs.push(`Rocky: may treat ${options[0].room.name} as just built.`);
      return;
    }
    G.pendingChoice = {
      type: 'mb-rocky-rebuild',
      resume: false,
      optional: true,
      playerId: Number(playerId),
      roomIndex,
      bossName: 'Rocky',
      message: 'Rocky: treat another Room as just built (or skip)',
      options,
    };
  }
}

/** Jinx L1: draw a Room at start of Build, then discard a Room. */
export function processJinxDraw(G) {
  for (const [pid, p] of Object.entries(G.players || {})) {
    if (p.eliminated) continue;
    for (const stack of p.dungeon || []) {
      const mb = revealedMb(stack);
      if (!mb || mb.card?.id !== 'RMB064' || mb.level < 1) continue;
      const drawn = drawCards(G.decks.rooms, 1)[0];
      if (drawn) {
        p.hand.push(drawn);
        G.logs.push(`Jinx: drew ${drawn.name}.`);
      }
      const roomOpts = (p.hand || [])
        .map((c, i) => ({ handIndex: i, card: c, label: c.name }))
        .filter((o) => o.card.isRoom);
      if (roomOpts.length === 1) {
        const [card] = p.hand.splice(roomOpts[0].handIndex, 1);
        G.decks.roomDiscard.push(card);
        G.logs.push(`Jinx: discarded ${card.name}.`);
      } else if (roomOpts.length > 1) {
        if (G.pendingChoice) {
          G.choiceQueue = G.choiceQueue || [];
          G.choiceQueue.push({
            type: 'mb-jinx-discard',
            resume: false,
            playerId: Number(pid),
            bossName: 'Jinx',
            message: 'Jinx: discard a Room',
            options: roomOpts,
          });
        } else {
          G.pendingChoice = {
            type: 'mb-jinx-discard',
            resume: false,
            playerId: Number(pid),
            bossName: 'Jinx',
            message: 'Jinx: discard a Room',
            options: roomOpts,
          };
        }
      }
      break; // one Jinx per player
    }
  }
}

export function zaraCountsAllTreasures(stack) {
  const mb = stack?.miniboss;
  return mb && !mb.faceDown && mb.card?.id === 'RMB202' && mb.level >= 1;
}

export function onRoomBuiltGainCoin(G, playerId, room) {
  if (room.gainCoin) gainCoin(G, playerId, 1, room.name);
}

export function beginningPhaseCoins(G) {
  for (const [pid, p] of Object.entries(G.players)) {
    if (p.eliminated) continue;
    for (const stack of p.dungeon || []) {
      const room = activeRoom(stack);
      if (room?.coinPerTurn) gainCoin(G, pid, 1, room.name);
    }
  }
}

export function onRoomDestroyed(G, playerId, stack) {
  if (stack?.miniboss && stack.length === 0) {
    discardMiniboss(stack, G);
  }
}

/** Clear once-per-turn miniboss flags at Beginning. */
export function clearMinibossTurnFlags(G) {
  for (const p of Object.values(G.players || {})) {
    for (const stack of p.dungeon || []) {
      if (stack?.miniboss) stack.miniboss.usedThisTurn = false;
    }
  }
}
