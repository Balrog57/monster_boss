// Hand-discard room abilities ("you may discard this from your hand to…")
// plus a few end-of-turn / build-phase hooks for remaining expansion rooms.
import { activeRoom, destroyRoom } from './engine.js';
import { drawCards, PHASE } from './cardData.js';
import { gainCoin } from './minibosses.js';
import { addHeroHealthBonus } from './items.js';

export const HAND_ABILITY_ROOM_IDS = new Set([
  'CRL007', // Frostman Lander
  'RMB016', // Tomb of Terrors
  'RMB027', // Shrooman Aviary
  'RMB035', // Cursed Well
  'TNL031', // Antimagic Zone
]);

export function canUseHandRoom(G, playerId, handIndex) {
  const p = G.players[playerId];
  const card = p?.hand?.[handIndex];
  if (!card?.isRoom || !HAND_ABILITY_ROOM_IDS.has(card.id)) return false;
  if (card.id === 'TNL031') return (G.stack?.length || 0) > 0;
  return G.phase === PHASE.BUILD || G.phase === PHASE.ADVENTURE || G.phase === PHASE.BAIT;
}

/**
 * Discard a hand-ability Room and apply its effect.
 * target: { playerId, roomIndex } | { heroId } | { choice: 'spell'|'coins' } | { pile, card }
 */
export function useHandRoomAbility(G, ctx, playerId, handIndex, target = {}) {
  const player = G.players[playerId];
  if (!player) return 'invalid player';
  const card = player.hand[handIndex];
  if (!card?.isRoom || !HAND_ABILITY_ROOM_IDS.has(card.id)) return 'invalid hand room';
  if (card.id === 'TNL031' && !(G.stack?.length)) return 'no spell on the stack';
  if (card.id !== 'TNL031'
      && G.phase !== PHASE.BUILD
      && G.phase !== PHASE.ADVENTURE
      && G.phase !== PHASE.BAIT) {
    return 'wrong phase';
  }

  player.hand.splice(handIndex, 1);
  G.decks.roomDiscard.push(card);

  switch (card.id) {
    case 'CRL007': {
      const options = listDungeonRooms(G).filter((o) => o.room?.advanced);
      if (!options.length) {
        G.logs.push('Frostman Lander: no Advanced Room to deactivate.');
        break;
      }
      if (options.length === 1 || (target.playerId != null && target.roomIndex != null)) {
        const opt = options.length === 1
          ? options[0]
          : options.find((o) => Number(o.playerId) === Number(target.playerId) && o.roomIndex === target.roomIndex);
        if (!opt) {
          // put card back? already discarded — pick first
          deactivate(G, options[0], 'Frostman Lander');
          break;
        }
        deactivate(G, opt, 'Frostman Lander');
        break;
      }
      G.pendingChoice = {
        type: 'deactivate-room',
        resume: false,
        playerId: Number(playerId),
        bossName: 'Frostman Lander',
        message: 'Frostman Lander: choose an Advanced Room to deactivate',
        options,
      };
      break;
    }
    case 'RMB016': {
      const rooms = (G.decks.roomDiscard || []).map((c, i) => ({ card: c, pile: 'room', pileIndex: i }));
      const spells = (G.decks.spellDiscard || []).map((c, i) => ({ card: c, pile: 'spell', pileIndex: i }));
      // Exclude the Frostman/Tomb card we just put on room discard (last index)
      const opts = [...rooms.slice(0, -1), ...spells];
      if (!opts.length) {
        G.logs.push('Tomb of Terrors: discard piles empty.');
        break;
      }
      if (opts.length === 1) {
        takeFromDiscard(G, player, opts[0]);
        G.logs.push(`Tomb of Terrors: took ${opts[0].card.name} from discard.`);
        break;
      }
      G.pendingChoice = {
        type: 'recover-card',
        resume: false,
        playerId: Number(playerId),
        bossName: 'Tomb of Terrors',
        message: 'Tomb of Terrors: choose a card from the discard',
        options: opts,
      };
      break;
    }
    case 'RMB027': {
      const heroes = listHeroes(G);
      if (!heroes.length) {
        G.logs.push('Shrooman Aviary: no Hero to buff.');
        break;
      }
      if (heroes.length === 1 || target.heroId) {
        const h = heroes.length === 1 ? heroes[0] : heroes.find((x) => x.heroId === target.heroId) || heroes[0];
        addHeroHealthBonus(G, h.heroId, 3);
        G.logs.push(`Shrooman Aviary: ${h.hero.name} +3 Health.`);
        break;
      }
      G.pendingChoice = {
        type: 'hero-health-bonus',
        resume: false,
        playerId: Number(playerId),
        bossName: 'Shrooman Aviary',
        message: 'Shrooman Aviary: choose a Hero for +3 Health',
        bonus: 3,
        options: heroes,
      };
      break;
    }
    case 'RMB035': {
      if (target.choice === 'spell') {
        const spell = drawCards(G.decks.spells, 1)[0];
        if (spell) {
          player.hand.push(spell);
          G.logs.push(`Cursed Well: drew ${spell.name}.`);
        }
      } else {
        gainCoin(G, playerId, 2, 'Cursed Well');
      }
      break;
    }
    case 'TNL031': {
      const top = (G.stack || []).pop();
      if (top?.card) {
        G.decks.spellDiscard.push(top.card);
        G.logs.push(`Antimagic Zone: cancelled ${top.card.name}.`);
      } else {
        G.logs.push('Antimagic Zone: nothing on the stack.');
      }
      G._spellCancelled = true;
      break;
    }
    default:
      return 'unknown hand ability';
  }
  return null;
}

function deactivate(G, opt, label) {
  G.effects.deactivatedRooms = G.effects.deactivatedRooms || [];
  G.effects.deactivatedRooms.push({ playerId: opt.playerId, roomIndex: opt.roomIndex });
  G.logs.push(`${label}: deactivated ${opt.room?.name}.`);
}

function listDungeonRooms(G) {
  const opts = [];
  for (const [pid, p] of Object.entries(G.players || {})) {
    if (p.eliminated) continue;
    (p.dungeon || []).forEach((s, i) => {
      const room = activeRoom(s);
      if (room) opts.push({ playerId: Number(pid), roomIndex: i, room });
    });
  }
  return opts;
}

function listHeroes(G) {
  const heroes = [];
  for (const pl of Object.values(G.players || {})) {
    for (const h of pl.entrance || []) heroes.push({ hero: h, heroId: h.id });
  }
  for (const h of G.town || []) heroes.push({ hero: h, heroId: h.id });
  if (G.adventure?.hero) heroes.push({ hero: G.adventure.hero, heroId: G.adventure.hero.id });
  return heroes;
}

function takeFromDiscard(G, player, option) {
  const pile = option.pile === 'spell' ? G.decks.spellDiscard : G.decks.roomDiscard;
  let idx = option.pileIndex;
  if (pile[idx]?.id !== option.card?.id) {
    idx = pile.findIndex((c) => c.id === option.card?.id);
  }
  if (idx < 0) return null;
  const card = pile.splice(idx, 1)[0];
  player.hand.push(card);
  notifyTookFromDiscard(G, player);
  return card;
}

/** Dragon Graveyard (TNL020): once per turn after taking from discard, draw a Room. */
export function notifyTookFromDiscard(G, player) {
  if (!player) return;
  const pid = Object.keys(G.players).find((id) => G.players[id] === player);
  for (const stack of player.dungeon || []) {
    const room = activeRoom(stack);
    if (room?.id === 'TNL020' && !room.usedThisTurn) {
      const drawn = G.decks.rooms.pop();
      if (drawn) {
        player.hand.push(drawn);
        G.logs.push(`Dragon Graveyard: drew ${drawn.name}.`);
      }
      room.usedThisTurn = true;
      break;
    }
  }
  void pid;
}

/** End-of-turn: Inner Sanctum / Blockpile Puzzle. */
export function processEndOfTurnRooms(G) {
  for (const [pid, p] of Object.entries(G.players || {})) {
    if (p.eliminated) continue;
    for (const stack of p.dungeon || []) {
      const room = activeRoom(stack);
      if (room?.id === 'TNL018' && !room._enteredThisTurn) {
        const drawn = G.decks.rooms.pop();
        if (drawn) {
          p.hand.push(drawn);
          G.logs.push(`Inner Sanctum: drew ${drawn.name}.`);
        }
      }
    }
    const hasBlockpile = (p.dungeon || []).some((s) => activeRoom(s)?.id === 'TNL047');
    if (hasBlockpile && p.dungeon.length) {
      let worst = 0;
      let minDmg = Infinity;
      p.dungeon.forEach((s, i) => {
        const r = activeRoom(s);
        const d = r?.damage ?? 99;
        if (d < minDmg) { minDmg = d; worst = i; }
      });
      const doomed = activeRoom(p.dungeon[worst]);
      destroyRoom(G, Number(pid), worst);
      G.logs.push(`Blockpile Puzzle: destroyed ${doomed?.name || 'a Room'}.`);
    }
  }
}

/** Dreadmill: once per Build phase place a coin or destroy. */
export function processDreadmills(G) {
  for (const [pid, p] of Object.entries(G.players || {})) {
    if (p.eliminated) continue;
    for (let i = p.dungeon.length - 1; i >= 0; i--) {
      const room = activeRoom(p.dungeon[i]);
      if (room?.id !== 'RMB048') continue;
      if ((p.coins || 0) >= 1) {
        p.coins -= 1;
        room.coinsOn = (room.coinsOn || 0) + 1;
        G.logs.push(`The Dreadmill: placed a Coin (${room.coinsOn} on room).`);
      } else {
        G.logs.push('The Dreadmill: no Coin — destroyed.');
        destroyRoom(G, Number(pid), i);
      }
    }
  }
}

/** Personnel Office: opponent built/promoted a miniboss. */
export function notifyOpponentMiniboss(G, actorId) {
  for (const [pid, p] of Object.entries(G.players || {})) {
    if (Number(pid) === Number(actorId) || p.eliminated) continue;
    for (const stack of p.dungeon || []) {
      const room = activeRoom(stack);
      if (room?.id === 'RMB049' && !room.usedThisTurn) {
        gainCoin(G, pid, 1, 'Personnel Office');
        room.usedThisTurn = true;
        break;
      }
    }
  }
}
