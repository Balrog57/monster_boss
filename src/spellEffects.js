// spellEffects.js - Implements the 16 base-set Spell effects for the new engine.
//
// Spells are resolved immediately when played. Target objects use:
//   { roomIndex, targetPlayerId, heroId, townIndex }

import { activeRoom, buildRoom, healOneWound, destroyRoom } from './engine.js';
import { drawCards } from './cardData.js';
import { gainCoin } from './minibosses.js';
import { applyGenericSpell } from './expansionEffects.js';
import { onExpansionCastSpell, onExpansionBossKill } from './expansionBosses.js';
import { applyItemReward, takeHeroItem } from './items.js';

export function emptyEffects() {
  return {
    roomDamageBonus: [],   // { playerId, roomIndex, amount }
    heroHealthBonus: [],   // { heroId, amount }
    heroDamage: [],        // { heroId, amount } — consumed by resolveOneHero
    deactivatedRooms: [],    // { playerId, roomIndex }
    buildBlocked: false,
    extraBuild: [],        // playerIds
    noEntry: [],           // playerIds
    teleportHero: null,    // heroId — consumed by resolveOneHero
    counteredSpells: [],    // spell IDs that were countered
    treasureDoubled: [],   // playerIds whose treasure counts are doubled this turn
    staffHealingPids: [],  // Staff of Healing: +2 HP to heroes entering these dungeons
    ordinaryMonsterBonus: [], // Goblin Suit reward: +1 ordinary monster damage
    ignoreAbilityPids: [], // Cheat Code reward: ignore room ability text
  };
}

export function castSpell(G, ctx, casterId, card, target) {
  // Normalize null/undefined target to {} so spell handlers can safely read
  // target.roomIndex, target.heroId, etc. without null checks.
  const t = target || {};
  onExpansionCastSpell(G, casterId);
  const handler = SPELL_EFFECTS[card.id];
  if (handler) {
    return handler(G, ctx, casterId, t);
  }
  if (applyGenericSpell(G, ctx, casterId, card, t)) {
    return true;
  }
  G.logs.push(`${card.name}: no effect implemented yet.`);
  return false;
}

function findRoom(G, playerId, roomIndex) {
  const p = G.players[playerId];
  if (!p || roomIndex < 0 || roomIndex >= p.dungeon.length) return null;
  return activeRoom(p.dungeon[roomIndex]);
}

function autoRoomIndex(G, playerId, target) {
  if (target && target.roomIndex != null) return target.roomIndex;
  return G.players[playerId].dungeon.length - 1;
}

function totalSouls(p) {
  return p.souls.reduce((s, x) => s + (x.souls || 1), 0);
}

const SPELL_EFFECTS = {
  // BMA040: Annihilator — Trap Room +3 damage until end of turn
  BMA040: (G, ctx, casterId, target) => {
    const idx = autoRoomIndex(G, casterId, target);
    const room = findRoom(G, casterId, idx);
    if (!room || room.type !== 'trap') {
      G.logs.push('Annihilator requires a Trap Room.');
      return false;
    }
    G.effects.roomDamageBonus.push({ playerId: casterId, roomIndex: idx, amount: 3 });
    G.logs.push(`Annihilator: ${room.name} gains +3 damage this turn.`);
    return true;
  },

  // BMA041: Assassin — target hero in any opponent's dungeon gains +3 HP
  BMA041: (G, ctx, casterId, target) => {
    const heroId = target.heroId;
    if (!heroId) {
      G.logs.push('Assassin: no target hero.');
      return false;
    }
    for (const [opid, op] of Object.entries(G.players)) {
      if (Number(opid) === Number(casterId)) continue;
      if (op.entrance.some(h => h.id === heroId)) {
        G.effects.heroHealthBonus.push({ heroId, amount: 3 });
        G.logs.push('Assassin: targeted hero gains +3 Health.');
        return true;
      }
      if (G.adventure && Number(G.adventure.playerId) === Number(opid) && G.adventure.hero?.id === heroId) {
        G.effects.heroHealthBonus.push({ heroId, amount: 3 });
        G.adventure.hp += 3;
        G.logs.push('Assassin: targeted hero gains +3 Health.');
        return true;
      }
    }
    G.logs.push('Assassin: target hero not found in an opponent\'s dungeon.');
    return false;
  },

  // BMA047: Giant Size — Monster Room +3 damage until end of turn
  BMA047: (G, ctx, casterId, target) => {
    const idx = autoRoomIndex(G, casterId, target);
    const room = findRoom(G, casterId, idx);
    if (!room || room.type !== 'monster') {
      G.logs.push('Giant Size requires a Monster Room.');
      return false;
    }
    G.effects.roomDamageBonus.push({ playerId: casterId, roomIndex: idx, amount: 3 });
    G.logs.push(`Giant Size: ${room.name} gains +3 damage this turn.`);
    return true;
  },

  // BMA050: Motivation — extra build if you have fewer rooms
  BMA050: (G, ctx, casterId, target) => {
    const myRooms = countVisibleRooms(G.players[casterId].dungeon);
    const hasMore = Object.entries(G.players).some(([pid, p]) =>
      pid !== String(casterId) && !p.eliminated && countVisibleRooms(p.dungeon) > myRooms
    );
    if (!hasMore) {
      G.logs.push('Motivation: you do not have fewer rooms than an opponent.');
      return false;
    }
    G.effects.extraBuild.push(casterId);
    G.logs.push('Motivation: you may build an extra room this turn.');
    return true;
  },

  // BMA042: Cave-In — destroy a room in your dungeon; heroes in that room die
  BMA042: (G, ctx, casterId, target) => {
    const p = G.players[casterId];
    const idx = target.roomIndex != null ? target.roomIndex : p.dungeon.length - 1;
    if (idx < 0 || idx >= p.dungeon.length) {
      G.logs.push('Cave-In: no room to destroy.');
      return false;
    }
    if (G.adventure && Number(G.adventure.playerId) === Number(casterId) && G.adventure.roomIndex === idx) {
      const hero = G.adventure.hero;
      G.adventure = null;
      const ei = p.entrance.findIndex(h => h.id === hero.id);
      if (ei >= 0) p.entrance.splice(ei, 1);
      for (let i = 0; i < (hero.souls || 1); i++) {
        p.souls.push({ souls: 1, name: hero.name, class: hero.class, faceDown: true });
      }
      if (hero.item) {
        applyItemReward(G, casterId, hero.item);
        takeHeroItem(p, hero);
      }
      onExpansionBossKill(G, casterId);
      G.decks.heroDiscard.push(hero);
      G.logs.push(`Cave-In: ${hero.name} in that room is destroyed.`);
    }
    const stack = p.dungeon[idx];
    const destroyed = stack.pop();
    G.decks.roomDiscard.push(destroyed);
    if (stack.length === 0) p.dungeon.splice(idx, 1);
    if (G.adventure && Number(G.adventure.playerId) === Number(casterId) && G.adventure.roomIndex > idx) {
      G.adventure.roomIndex -= 1;
    }
    G.logs.push(`Cave-In: ${destroyed.name} destroyed.`);
    return true;
  },

  // BMA044: Exhaustion — X damage to one hero in your dungeon, X = visible rooms
  BMA044: (G, ctx, casterId, target) => {
    const x = countVisibleRooms(G.players[casterId].dungeon);
    const heroId = target.heroId;
    if (!heroId) {
      G.logs.push('Exhaustion: no target hero.');
      return false;
    }
    if (G.adventure && Number(G.adventure.playerId) === Number(casterId) && G.adventure.hero?.id === heroId) {
      G.adventure.hp -= x;
      G.logs.push(`Exhaustion: deals ${x} damage to ${G.adventure.hero.name} (HP ${G.adventure.hp}).`);
      return true;
    }
    G.effects.heroDamage.push({ heroId, amount: x });
    G.logs.push(`Exhaustion: deals ${x} damage to a hero in your dungeon.`);
    return true;
  },

  // BMA043 is handled directly in reducer playSpell (stack cancel) — not via castSpell.
  // BMA046: Freeze — deactivate one room until end of turn
  BMA046: (G, ctx, casterId, target) => {
    const targetId = target.targetPlayerId != null ? target.targetPlayerId : casterId;
    const idx = autoRoomIndex(G, targetId, target);
    if (!findRoom(G, targetId, idx)) {
      G.logs.push('Freeze: no room to deactivate.');
      return false;
    }
    G.effects.deactivatedRooms.push({ playerId: targetId, roomIndex: idx });
    G.logs.push(`Freeze: room at index ${idx} deactivated this turn.`);
    return true;
  },

  // BMA048: Jeopardy — all discard hands, draw 1 spell + 2 rooms
  BMA048: (G, ctx, casterId, target) => {
    for (const p of Object.values(G.players)) {
      while (p.hand.length > 0) {
        const c = p.hand.pop();
        if (c.isSpell) G.decks.spellDiscard.push(c);
        else G.decks.roomDiscard.push(c);
      }
      const spell = drawCards(G.decks.spells, 1);
      const rooms = drawCards(G.decks.rooms, 2);
      p.hand.push(...spell, ...rooms);
    }
    G.logs.push('Jeopardy: all players discarded hands and drew 1 Spell + 2 Rooms.');
    return true;
  },

  // BMA049: Kobold Strike — no rooms can be built this turn; undo face-down builds this turn
  BMA049: (G, ctx, casterId, target) => {
    G.effects.buildBlocked = true;
    for (const p of Object.values(G.players)) {
      const returned = [];
      for (let i = p.dungeon.length - 1; i >= 0; i--) {
        const stack = p.dungeon[i];
        while (stack.length > 0) {
          const top = stack[stack.length - 1];
          if (!top?.faceDown || !top?.builtThisTurn) break;
          returned.push(stack.pop());
        }
        if (stack.length === 0) p.dungeon.splice(i, 1);
      }
      if (returned.length) {
        p.hand.push(...returned);
        p.buildsThisTurn = Math.max(0, (p.buildsThisTurn || 0) - returned.length);
        G.logs.push(`Kobold Strike: ${returned.length} room(s) returned to hand.`);
      }
    }
    G.logs.push('Kobold Strike: no rooms can be built this turn.');
    return true;
  },

  // BMA054: Trepidation — player with 2+ more souls cannot be entered
  BMA054: (G, ctx, casterId, target) => {
    const mySouls = totalSouls(G.players[casterId]);
    let targetId = target.targetPlayerId != null ? target.targetPlayerId : null;
    if (targetId == null) {
      for (const [pid, p] of Object.entries(G.players)) {
        if (pid === String(casterId) || p.eliminated) continue;
        if (totalSouls(p) >= mySouls + 2) { targetId = parseInt(pid); break; }
      }
    }
    const victim = targetId != null ? G.players[targetId] : null;
    if (!victim || totalSouls(victim) < mySouls + 2) {
      G.logs.push('Trepidation: no opponent has 2+ more souls than you.');
      return false;
    }
    G.effects.noEntry.push(Number(targetId));
    G.logs.push(`Trepidation: no hero enters player ${targetId}'s dungeon this turn.`);
    return true;
  },

  // BMA045: Fear — return a hero in any dungeon to town
  BMA045: (G, ctx, casterId, target) => {
    const heroId = target.heroId;
    if (!heroId) {
      G.logs.push('Fear: no target hero.');
      return false;
    }
    if (G.adventure?.hero?.id === heroId) {
      const hero = G.adventure.hero;
      G.adventure = null;
      G.town.unshift(hero);
      G.logs.push(`Fear: ${hero.name} returned to town.`);
      return true;
    }
    for (const p of Object.values(G.players)) {
      const idx = p.entrance.findIndex(h => h.id === heroId);
      if (idx >= 0) {
        const hero = p.entrance.splice(idx, 1)[0];
        G.town.unshift(hero);
        G.logs.push(`Fear: ${hero.name} returned to town.`);
        return true;
      }
    }
    G.logs.push('Fear: target hero not found.');
    return false;
  },

  // BMA051: Princess in Peril — move a hero from town to your entrance
  BMA051: (G, ctx, casterId, target) => {
    const townIdx = target.townIndex != null ? target.townIndex : 0;
    const hero = G.town[townIdx];
    if (!hero) {
      G.logs.push('Princess in Peril: no hero in town.');
      return false;
    }
    G.town.splice(townIdx, 1);
    G.players[casterId].entrance.push(hero);
    G.logs.push(`Princess in Peril: ${hero.name} placed at your entrance.`);
    return true;
  },

  // BMA052: Soul Harvest — remove a soul, draw 2 spells
  BMA052: (G, ctx, casterId, target) => {
    const p = G.players[casterId];
    const idx = target.soulIndex != null ? target.soulIndex : (p.souls.length ? p.souls.length - 1 : -1);
    if (idx < 0 || !p.souls[idx] || p.souls[idx].tpk || p.souls[idx].faceDown === false) {
      G.logs.push('Soul Harvest: no soul to remove.');
      return false;
    }
    const removed = p.souls.splice(idx, 1)[0];
    const spells = drawCards(G.decks.spells, 2);
    p.hand.push(...spells);
    G.logs.push(`Soul Harvest: removed ${removed.name || 'a Hero'}, drew ${spells.length} spells.`);
    return true;
  },

  // BMA053: Teleportation — send a hero in your dungeon back to first room
  BMA053: (G, ctx, casterId, target) => {
    const heroId = target.heroId;
    if (!heroId) {
      G.logs.push('Teleportation: no target hero.');
      return false;
    }
    if (G.adventure && Number(G.adventure.playerId) === Number(casterId) && G.adventure.hero?.id === heroId) {
      G.adventure.roomIndex = -1;
      G.adventure.mazeSentBack = {};
      G.logs.push('Teleportation: hero restarts at the first room.');
      return true;
    }
    const p = G.players[casterId];
    const idx = p.entrance.findIndex(h => h.id === heroId);
    if (idx < 0) {
      G.logs.push('Teleportation: target hero not in your dungeon.');
      return false;
    }
    G.effects.teleportHero = heroId;
    G.logs.push('Teleportation: hero will restart at the first room.');
    return true;
  },

  // BMA055: Zombie Attack — dead hero returns to opponent's entrance with +2 HP
  BMA055: (G, ctx, casterId, target) => {
    const targetId = target.targetPlayerId != null ? target.targetPlayerId : null;
    const pileName = target.pile || 'souls';
    let victim = targetId !== null ? G.players[targetId] : null;
    let soulIndex = target.soulIndex;
    if (!victim) {
      for (const [pid, p] of Object.entries(G.players)) {
        if (pid === String(casterId) || p.eliminated) continue;
        if ((p.souls || []).some((s) => !s.tpk)) {
          victim = p;
          soulIndex = p.souls.findIndex((s) => !s.tpk);
          break;
        }
        if ((p.wounds || []).length) {
          victim = p;
          soulIndex = 0;
          break;
        }
      }
    }
    const pile = victim?.[pileName] || victim?.souls;
    if (!victim || soulIndex == null || !pile?.[soulIndex]) {
      G.logs.push('Zombie Attack: no opponent has a dead Hero.');
      return false;
    }
    const revived = pile.splice(soulIndex, 1)[0];
    const origHero = G.decks.heroDiscard.find(h => h.name === (revived.name || ''))
      || (G.decks.heroes || []).find(h => h.name === revived.name);
    const baseHP = origHero?.hp || revived.hp || 4;
    victim.entrance.push({
      ...(origHero || {}),
      ...revived,
      name: revived.name || origHero?.name || 'Zombie',
      hp: baseHP + 2,
      souls: origHero?.souls || 1,
      wounds: origHero?.wounds || 1,
    });
    G.logs.push(`Zombie Attack: ${revived.name || 'a dead Hero'} returns to player ${targetId ?? '?'}'s dungeon (+2 HP).`);
    return true;
  },

  KSA013: (G, ctx, casterId) => {
    const p = G.players[casterId];
    p.souls.push({ souls: 0, name: 'T.P.K.', tpk: true });
    G.logs.push('T.P.K. is placed in your scorekeeping area.');
    return true;
  },

  THK025: (G, ctx, casterId, target) => {
    const pid = target.targetPlayerId != null ? target.targetPlayerId : casterId;
    const idx = target.itemIndex != null ? target.itemIndex : 0;
    const owner = G.players[pid];
    const it = owner?.items?.[idx];
    if (!it) {
      G.logs.push('Excavation: no item to flip.');
      return true;
    }
    it.faceDown = !it.faceDown;
    G.logs.push(`Excavation: flipped ${it.name} ${it.faceDown ? 'face-down' : 'face-up'}.`);
    return true;
  },

  TNL201: (G, ctx, casterId) => {
    const p = G.players[casterId];
    const spells = drawCards(G.decks.spells, 2);
    p.hand.push(...spells);
    G.logs.push(`Dark Pact: drew ${spells.length} Spell(s).`);
    return true;
  },

  TNL057: (G, ctx, casterId, target) => {
    const p = G.players[casterId];
    let hero = null;
    if (G.adventure && Number(G.adventure.playerId) === Number(casterId) && G.adventure.hero?.id === target?.heroId) {
      hero = G.adventure.hero;
      G.adventure = null;
    } else {
      const idx = p.entrance.findIndex((h) => h.id === target?.heroId);
      if (idx >= 0) hero = p.entrance.splice(idx, 1)[0];
    }
    if (!hero) {
      G.logs.push('Another Castle: no Hero in your dungeon.');
      return false;
    }
    const opps = Object.keys(G.players).filter((id) => Number(id) !== Number(casterId) && !G.players[id].eliminated);
    const dest = target?.targetPlayerId != null ? target.targetPlayerId : opps[0];
    if (dest == null) {
      G.town.push(hero);
      G.logs.push('Another Castle: no opponent — Hero returned to town.');
      return true;
    }
    G.players[dest].entrance.push(hero);
    G.logs.push(`Another Castle: ${hero.name} sent to Player ${dest}'s entrance.`);
    return true;
  },

  CRL201: (G, ctx, casterId, target) => {
    const townIdx = target.townIndex != null ? target.townIndex : 0;
    const hero = G.town[townIdx];
    if (!hero) {
      G.logs.push('Abduction: no hero in town.');
      return false;
    }
    G.town.splice(townIdx, 1);
    G.players[casterId].entrance.push(hero);
    G.logs.push(`Abduction: ${hero.name} placed at your entrance.`);
    return true;
  },

  CRL029: (G, ctx, casterId, target) => {
    const heroId = target.heroId;
    if (heroId) {
      G.effects.heroDamage.push({ heroId, amount: 99 });
      G.logs.push('Finish Him!: finished target hero.');
      return true;
    }
    G.logs.push('Finish Him!: no hero targeted.');
    return false;
  },

  CRL030: (G, ctx, casterId, target) => {
    const heroId = target.heroId;
    const wounds = (G.players[casterId]?.wounds || []).length;
    if (!heroId || wounds <= 0) {
      G.logs.push('Essence Transfer: no wounds or no hero.');
      return false;
    }
    G.effects.heroHealthBonus.push({ heroId, amount: wounds });
    G.logs.push(`Essence Transfer: target hero gains +${wounds} Health.`);
    return true;
  },

  CRL031: (G, ctx, casterId) => {
    const soul = healOneWound(G.players[casterId]);
    G.logs.push(soul ? 'Healing Tank: healed a Wound.' : 'Healing Tank: no Wounds to heal.');
    return true;
  },

  CRL032: (G, ctx, casterId, target) => {
    const tid = target.targetPlayerId != null ? target.targetPlayerId : casterId;
    const ri = target.roomIndex != null ? target.roomIndex : 0;
    const r = findRoom(G, tid, ri);
    if (r) {
      r.treasures = [...(r.treasures || []), 5];
      G.logs.push(`Meteorite: ${r.name} gained Explorer treasure until end of turn.`);
      return true;
    }
    return false;
  },

  TNL056: (G, ctx, casterId, target) => {
    const oppId = target.targetPlayerId;
    const opp = G.players[oppId];
    if (opp) {
      const roomIdx = opp.hand.findIndex((c) => c.isRoom);
      if (roomIdx >= 0) {
        const stolen = opp.hand.splice(roomIdx, 1)[0];
        G.players[casterId].hand.push(stolen);
        G.logs.push(`All Your Base: took ${stolen.name} from Player ${oppId}.`);
        return true;
      }
    }
    G.logs.push('All Your Base: no Room to take.');
    return true;
  },

  TNL058: (G, ctx, casterId, target) => {
    const tid = target.targetPlayerId != null ? target.targetPlayerId : casterId;
    const ri = target.roomIndex != null ? target.roomIndex : 0;
    G.effects.deactivatedRooms.push({ playerId: tid, roomIndex: ri });
    G.logs.push('Fairy Fountain: Room does zero damage this turn.');
    return true;
  },

  TNL059: (G, ctx, casterId, target) => {
    const heroId = target.heroId;
    if (heroId) {
      G.effects.heroDamage.push({ heroId, amount: 99 });
      G.logs.push("It's On!: killed target hero.");
      return true;
    }
    return false;
  },

  TNL060: (G, ctx, casterId) => {
    const drawn = drawCards(G.decks.rooms, 3);
    G.players[casterId].hand.push(...drawn);
    G.logs.push(`Hiring Spree: drew ${drawn.length} Room(s).`);
    return true;
  },

  TNL061: (G, ctx, casterId, target) => {
    const heroId = target.heroId;
    if (heroId) {
      G.effects.heroDamage.push({ heroId, amount: 3 });
      G.logs.push('Lightning Bolt!: dealt 3 damage to hero.');
      return true;
    }
    return false;
  },

  TNL062: (G, ctx, casterId, target) => {
    const tid = target.targetPlayerId != null ? target.targetPlayerId : casterId;
    const ri = target.roomIndex != null ? target.roomIndex : 0;
    G.effects.deactivatedRooms.push({ playerId: tid, roomIndex: ri });
    G.logs.push('Meddling Kids!: Room has no ability text this turn.');
    return true;
  },

  TNL063: (G, ctx, casterId) => {
    const p = G.players[casterId];
    if (p.dungeon.length >= 2) {
      const tmp = p.dungeon[0];
      p.dungeon[0] = p.dungeon[1];
      p.dungeon[1] = tmp;
      G.logs.push('Oh, Yeah!: swapped placement of two Rooms.');
      return true;
    }
    return false;
  },

  TNL064: (G, ctx, casterId) => {
    G.effects.staffHealingPids = G.effects.staffHealingPids || [];
    G.effects.staffHealingPids.push(Number(casterId));
    G.logs.push('Party Up: Heroes entering this dungeon gain +1 Health.');
    return true;
  },

  TNL065: (G, ctx, casterId) => {
    if (G.adventure && Number(G.adventure.playerId) === Number(casterId)) {
      G.adventure.hp = G.adventure.hero?.hp || 10;
      G.adventure.roomIndex = -1;
      G.effects.noEntry.push(Number(casterId));
      G.logs.push('Pause: Hero returned to entrance at full Health; no heroes may enter until next turn.');
      return true;
    }
    return false;
  },

  TNL066: (G, ctx, casterId, target) => {
    const heroId = target.heroId;
    if (heroId && G.adventure?.hero?.id === heroId) {
      G.adventure = null;
      G.logs.push('Pity: removed Hero from the game.');
      return true;
    }
    return false;
  },

  TNL067: (G, ctx, casterId, target) => {
    const ri = target.roomIndex != null ? target.roomIndex : 0;
    const r = findRoom(G, casterId, ri);
    if (r) {
      r.treasures = [...(r.treasures || []), 1, 2, 3, 4];
      G.logs.push(`Secret Stash: ${r.name} gained one of each treasure icon.`);
      return true;
    }
    return false;
  },

  TNL068: (G, ctx, casterId) => {
    if (G.adventure) {
      G.adventure.roomIndex += 1;
      G.logs.push('Shortcut!: Hero skips the next Room.');
      return true;
    }
    return false;
  },

  TNL069: (G, ctx, casterId, target) => {
    const ri = autoRoomIndex(G, casterId, target);
    G.effects.roomDamageBonus.push({ playerId: casterId, roomIndex: ri, amount: 2 });
    G.logs.push('Super Effective!: Room deals +2 damage until end of turn.');
    return true;
  },

  TNL201: (G, ctx, casterId) => {
    for (const [opid, op] of Object.entries(G.players)) {
      if (Number(opid) !== Number(casterId)) {
        const si = op.hand.findIndex((c) => c.isSpell);
        if (si >= 0) {
          const discarded = op.hand.splice(si, 1)[0];
          G.decks.spellDiscard.push(discarded);
          G.logs.push(`Instant Karma: Player ${opid} discarded ${discarded.name}.`);
        }
      }
    }
    return true;
  },

  TNL202: (G, ctx, casterId, target) => {
    const p = G.players[casterId];
    const a = target?.roomA ?? 0;
    const b = target?.roomB ?? 1;
    if (!p.dungeon[a] || !p.dungeon[b] || a === b) {
      G.logs.push('Dungeon Shift: invalid rooms.');
      return false;
    }
    const tmp = p.dungeon[a];
    p.dungeon[a] = p.dungeon[b];
    p.dungeon[b] = tmp;
    G.logs.push('Dungeon Shift: swapped two Rooms in your dungeon.');
    return true;
  },

  RMB065: (G, ctx, casterId) => {
    const p = G.players[casterId];
    if ((p.coins || 0) === 0) {
      gainCoin(G, casterId, 3, 'Windfall');
      return true;
    }
    gainCoin(G, casterId, 1, 'Windfall');
    return true;
  },

  RMB066: (G, ctx, casterId) => {
    const drawn = drawCards(G.decks.rooms, 3);
    const monster = drawn.find((c) => c.type === 'monster');
    if (monster) {
      G.players[casterId].hand.push(monster);
      G.logs.push(`Internship: took ${monster.name} into hand.`);
    }
    drawn.filter((c) => c !== monster).forEach((c) => G.decks.roomDiscard.push(c));
    return true;
  },

  RMB067: (G, ctx, casterId, target) => {
    const tid = target.targetPlayerId != null ? target.targetPlayerId : casterId;
    const ri = target.roomIndex != null ? target.roomIndex : 0;
    const r = findRoom(G, tid, ri);
    if (r) {
      r.treasures = [...(r.treasures || []), 1, 2, 3, 4];
      G.logs.push(`Spirit Dragon: ${r.name} gained one of each treasure icon.`);
      return true;
    }
    return false;
  },

  RMB068: (G, ctx, casterId, target) => {
    const tid = target.targetPlayerId != null ? target.targetPlayerId : casterId;
    const ri = target.roomIndex != null ? target.roomIndex : 0;
    G.effects.deactivatedRooms.push({ playerId: tid, roomIndex: ri });
    G.logs.push('Sabotage!: Room has no ability text this turn.');
    return true;
  },

  RMB069: (G, ctx, casterId) => {
    const p = G.players[casterId];
    (p.dungeon || []).forEach((stack, i) => {
      const mb = stack?.miniboss;
      if (mb) {
        G.effects.roomDamageBonus.push({ playerId: casterId, roomIndex: i, amount: mb.level || 1 });
      }
    });
    G.logs.push('Rage!: Miniboss rooms gain +1 damage per level.');
    return true;
  },

  RMB072: (G, ctx, casterId, target) => {
    const heroId = target.heroId;
    if (heroId) {
      G.effects.heroDamage.push({ heroId, amount: 2 });
      G.logs.push('Smash!: dealt 2 damage to Hero.');
      return true;
    }
    return false;
  },

  RMB073: (G, ctx, casterId, target) => {
    const ri = autoRoomIndex(G, casterId, target);
    G.effects.roomDamageBonus.push({ playerId: casterId, roomIndex: ri, amount: 1 });
    G.logs.push('Pay to Win: Room gains +1 damage.');
    return true;
  },

  RMB075: (G, ctx, casterId) => {
    G.logs.push('Respawn: all Rooms treated as just built.');
    return true;
  },

  RMB076: (G, ctx, casterId, target) => {
    const tid = target.targetPlayerId != null ? target.targetPlayerId : casterId;
    const ri = target.roomIndex != null ? target.roomIndex : 0;
    const r = findRoom(G, tid, ri);
    if (r) {
      r.treasures = [];
      G.logs.push(`Heist: ${r.name}'s treasure icons negated this turn.`);
      return true;
    }
    return false;
  },

  RMB077: (G, ctx, casterId) => {
    if (G.stack?.length > 0) {
      const top = G.stack[G.stack.length - 1];
      if (top && top.type === 'spell') {
        top.resolved = true;
        G.effects.counteredSpells.push(top.card?.id);
        G.logs.push(`Short Circuit: countered ${top.card?.name || 'Spell'}.`);
        return true;
      }
    }
    G.logs.push('Short Circuit: no Spell to counter.');
    return false;
  },

  RMB079: (G, ctx, casterId, target) => {
    const heroId = target.heroId;
    if (heroId) {
      G.effects.heroHealthBonus.push({ heroId, amount: 1 });
      G.logs.push('Armor Up!: Hero gains +1 Health.');
      return true;
    }
    return false;
  },

  RMB301: (G, ctx, casterId) => {
    gainCoin(G, casterId, 2, 'Mint Condition');
    return true;
  },
};

function countVisibleRooms(dungeon) {
  let n = 0;
  for (const stack of dungeon) if (activeRoom(stack)) n++;
  return n;
}

export function roomDamageBonusFor(G, playerId, roomIndex) {
  if (!G.effects?.roomDamageBonus) return 0;
  return G.effects.roomDamageBonus
    .filter(e => e.playerId === playerId && e.roomIndex === roomIndex)
    .reduce((sum, e) => sum + e.amount, 0);
}

export function heroHealthBonusFor(G, heroId) {
  if (!G.effects?.heroHealthBonus) return 0;
  return G.effects.heroHealthBonus
    .filter(e => e.heroId === heroId)
    .reduce((sum, e) => sum + e.amount, 0);
}

export function heroDamageFor(G, heroId) {
  if (!G.effects?.heroDamage) return 0;
  return G.effects.heroDamage
    .filter(e => e.heroId === heroId)
    .reduce((sum, e) => sum + e.amount, 0);
}

export function consumeHeroDamage(G, heroId) {
  if (!G.effects?.heroDamage) return;
  G.effects.heroDamage = G.effects.heroDamage.filter(e => e.heroId !== heroId);
}

export function isRoomDeactivated(G, playerId, roomIndex) {
  return G.effects?.deactivatedRooms?.some(e => e.playerId === playerId && e.roomIndex === roomIndex) ?? false;
}

export function isBuildBlocked(G) {
  return !!G.effects?.buildBlocked;
}

export function extraBuildsFor(G, playerId) {
  return G.effects?.extraBuild?.filter(id => id === playerId).length || 0;
}

export function isNoEntry(G, playerId) {
  return G.effects?.noEntry?.includes(playerId) ?? false;
}

export function isCountered(G, spellId) {
  return G.effects?.counteredSpells?.includes(spellId) ?? false;
}
