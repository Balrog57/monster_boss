// Projection canonique de l'etat de partie : la SEULE surface comparee entre
// le moteur JS et le port GDScript. Les deux moteurs ont des formes d'etat
// differentes (logs/log, activePlayer/xpOrder[0], decks incomplets), donc on
// compare des invariants, pas des dictionnaires bruts.
//
// Toute divergence de forme qui n'affecte pas ces champs est hors scope.

const arr = (v) => (Array.isArray(v) ? v : []);
const num = (v) => (typeof v === 'number' && Number.isFinite(v) ? v : 0);
const bool = (v) => v === true;
const id = (v) => (v === null || v === undefined ? null : (v.id ?? v));

// Le donjon est un tableau de SALLES (slots), chaque slot contenant la pile de
// salles empilees (reducer.js : une salle peut se poser sur une autre).
// On garde l'ordre des slots (c'est une regle du jeu) et on expose aussi les ids
// en multiset trie, pour distinguer "salles differentes" de "ordre different".
const slots = (rooms) => arr(rooms).map((s) => (Array.isArray(s) ? s : [s]));

const dungeon = (rooms) =>
  slots(rooms).map((stack) =>
    stack.map((r) => ({
      id: r?.id ?? null,
      dmg: num(r?.damage),
      vis: bool(r?.visible),
      act: bool(r?.activated),
      used: bool(r?.usedThisTurn),
    })),
  );

const dungeonIds = (rooms) => slots(rooms).flatMap((s) => s.map((r) => r?.id ?? null)).sort();

export function canon(G, ctx) {
  const players = Object.keys(G.players || {})
    .sort((a, b) => Number(a) - Number(b))
    .map((pid) => {
      const p = G.players[pid];
      return {
        id: Number(pid),
        souls: arr(p?.souls).length,
        wounds: arr(p?.wounds).length,
        coins: p?.coins ?? null,
        eliminated: bool(p?.eliminated),
        leveledUp: bool(p?.leveledUp),
        builds: num(p?.buildsThisTurn),
        passed: bool(p?.passed),
        boss: p?.boss?.id ?? null,
        bossXp: p?.boss?.xp ?? null,
        hand: arr(p?.hand).map((c) => c?.id ?? null),
        dungeon: dungeon(p?.dungeon),
        dungeonIds: dungeonIds(p?.dungeon),
        entrance: arr(p?.entrance).map((h) => `${h?.id ?? null}:${num(h?.wounds)}`),
        items: arr(p?.items).map((i) => id(i)),
      };
    });

  const decks = G.decks || {};
  const pending = G.pendingChoice && Object.keys(G.pendingChoice).length > 0 ? G.pendingChoice : null;

  return {
    phase: G.phase ?? null,
    turn: num(G.turn),
    active: G.activePlayer ?? ctx?.activePlayer ?? null,
    gameOver: G.gameOver === true || (G.gameOver && typeof G.gameOver === 'object') ? true : false,
    winner: G.winner ?? null,
    pendingChoice: pending
      ? { type: pending.type ?? null, playerId: pending.playerId ?? null, options: arr(pending.options).length }
      : null,
    players,
    town: arr(G.town).map((h) => ({ id: h?.id ?? null, name: h?.name ?? null, wounds: num(h?.wounds), epic: bool(h?.epic) })),
    townItems: arr(G.townItems).map((i) => id(i)),
    decks: {
      rooms: arr(decks.rooms).length,
      spells: arr(decks.spells).length,
      heroes: arr(decks.heroes).length,
      epics: arr(decks.epics).length,
      items: arr(decks.items).length,
      minibosses: arr(decks.minibosses).length,
    },
    discards: {
      room: arr(decks.roomDiscard).length,
      spell: arr(decks.spellDiscard).length,
      hero: arr(decks.heroDiscard).length,
      items: arr(decks.itemsDiscard).length,
      miniboss: arr(decks.minibossDiscard).length,
    },
    stack: arr(G.stack).length,
    adventure: G.adventure && !G.adventure.pause
      ? { pid: G.adventure.playerId ?? null, room: G.adventure.roomIndex ?? null }
      : null,
  };
}

// Marche dans deux projections et renvoie les divergences en { chemin, js, gd }.
// Les cles absentes des deux cotes sont ignorees (avant que la Phase 2/3/4 ne
// les porte), une valeur presente d'un seul cote est une divergence.
export function diff(a, b, path = '', out = [], limit = 12) {
  if (out.length >= limit) return out;
  const isObj = (v) => v !== null && typeof v === 'object';
  if (isObj(a) && isObj(b)) {
    for (const k of new Set([...Object.keys(a), ...Object.keys(b)])) {
      diff(a[k], b[k], path ? `${path}.${k}` : k, out, limit);
      if (out.length >= limit) return out;
    }
    return out;
  }
  const sa = JSON.stringify(a ?? null);
  const sb = JSON.stringify(b ?? null);
  if (sa !== sb) out.push({ path, js: a ?? null, gd: b ?? null });
  return out;
}