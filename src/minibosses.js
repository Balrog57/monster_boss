// minibosses.js - Rise of the Minibosses: Coins, build, reveal, promote.
import { activeRoom } from './engine.js';
import { drawCards } from './cardData.js';

export function initPlayerCoins(player) {
  player.coins = player.coins || 0;
}

export function gainCoin(G, playerId, n = 1, reason = '') {
  const p = G.players[playerId] ?? G.players[String(playerId)];
  if (!p) return;
  p.coins = (p.coins || 0) + n;
  G.logs.push(`${reason || 'Coin'}: Player ${playerId} gains ${n} Coin(s) (total ${p.coins}).`);
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
  stack.miniboss = { card, level, usedL3: false, faceDown: true };
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
  attachMiniboss(stack, mbCard);
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

export function canActivateMiniboss(G, playerId, roomIndex) {
  if (G.phase !== 'build' && G.phase !== 'adventure') return false;
  const stack = G.players[playerId]?.dungeon[roomIndex];
  const mb = stack?.miniboss;
  if (!mb || mb.faceDown || mb.level < 3 || mb.usedL3) return false;
  if (mb.card.id === 'RMB201') {
    const p = G.players[playerId];
    const inAdv = G.adventure && Number(G.adventure.playerId) === Number(playerId);
    return inAdv || (p.entrance?.length > 0);
  }
  return true;
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

export function activateMiniboss(G, ctx, playerId, roomIndex) {
  const stack = G.players[playerId]?.dungeon[roomIndex];
  const mb = stack?.miniboss;
  if (!canActivateMiniboss(G, playerId, roomIndex)) return 'cannot activate miniboss';
  const p = G.players[playerId];

  if (mb.card.id === 'RMB201') {
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

  if (mb.card.id === 'RMB202') {
    for (const [oppId, opp] of Object.entries(G.players)) {
      if (Number(oppId) === Number(playerId) || opp.eliminated) continue;
      const rooms = opp.hand.map((c, i) => ({ c, i })).filter(({ c }) => c.isRoom);
      if (!rooms.length) continue;
      const pick = rooms[Math.floor(Math.random() * rooms.length)];
      const [card] = opp.hand.splice(pick.i, 1);
      G.decks.roomDiscard.push(card);
      G.logs.push(`Zara the Zealous: Player ${oppId} discards ${card.name}.`);
    }
    mb.level = 1;
    mb.usedL3 = false;
    return null;
  }

  return 'unknown miniboss ability';
}

export function resolveGrukTarget(G, playerId, roomIndex, option) {
  applyGrukDamage(G, playerId, option);
  const stack = G.players[playerId]?.dungeon[roomIndex];
  if (stack) discardMiniboss(stack, G);
}

export function zaraCountsAllTreasures(stack) {
  const mb = stack?.miniboss;
  return mb && !mb.faceDown && mb.card?.id === 'RMB202' && mb.level >= 1;
}

export function minibossDamageBonus(stack) {
  const mb = stack?.miniboss;
  if (!mb || mb.faceDown) return 0;
  if (mb.card.id === 'RMB201') return mb.level >= 2 ? 2 : 1;
  return 0;
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
