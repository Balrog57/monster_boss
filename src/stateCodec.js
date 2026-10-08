// stateCodec.js — JSON round-trip codec that survives array-attached properties.
//
// Dungeon stacks are Arrays with a `.miniboss` own property (see
// src/minibosses.js attachMiniboss). A plain JSON.stringify/array drops every
// non-index property, so the miniboss silently vanished on each clone, on each
// Postgres save/load and on every socket payload. This codec wraps such arrays
// as `{ __a: [...items], ...extras }` on the way out and restores them on the
// way in.

const WRAP = '__a';

function isIndexKey(key, length) {
  if (!/^(0|[1-9]\d*)$/.test(key)) return false;
  return Number(key) < length;
}

function replacer(_key, value) {
  if (Array.isArray(value)) {
    const extras = {};
    let hasExtras = false;
    for (const k of Object.keys(value)) {
      if (k === WRAP) continue;
      if (isIndexKey(k, value.length)) continue;
      extras[k] = value[k];
      hasExtras = true;
    }
    if (!hasExtras) return value;
    return { [WRAP]: value.slice(), ...extras };
  }
  return value;
}

function reviver(_key, value) {
  if (value && typeof value === 'object' && !Array.isArray(value) && Array.isArray(value[WRAP])) {
    const arr = value[WRAP];
    for (const k of Object.keys(value)) {
      if (k === WRAP) continue;
      arr[k] = value[k];
    }
    return arr;
  }
  return value;
}

/** JSON-safe copy (array extras wrapped). Use before persisting or emitting. */
export function encodeState(value) {
  return JSON.parse(JSON.stringify(value, replacer));
}

/** Game-state copy (array extras restored). Idempotent. */
export function decodeState(value) {
  return JSON.parse(JSON.stringify(value, replacer), reviver);
}

/** JSON text in the encoded form — for db columns. */
export function stringifyState(value) {
  return JSON.stringify(value, replacer);
}

/** Parse JSON text produced by stringifyState (or a plain legacy payload). */
export function parseState(text) {
  return JSON.parse(text, reviver);
}
