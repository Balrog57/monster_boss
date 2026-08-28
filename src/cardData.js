// cardData.js - loads the generated card data and provides game helpers
//
// The `with { type: 'json' }` import attribute works in both Vite 5+ (client
// bundle) and Node 22+ (server, strict ESM). It is the standard way to import
// JSON across both environments.
import cardData from './cardData.json' with { type: 'json' };
import apkCardManifest from './apkCardManifest.json' with { type: 'json' };

export const BOSSES = cardData.bosses;
export const ROOMS = cardData.rooms;
export const SPELLS = cardData.spells;
export const HEROES = cardData.heroes;
export const ITEMS = cardData.items || [];

export const TREASURE_NAMES = ['?', 'Cleric', 'Fighter', 'Mage', 'Thief'];
export const ROOM_TYPE = { MONSTER: 'monster', TRAP: 'trap' };
export const SPELL_CATEGORY = {
  BUILD: 1,
  BUILD_TPK: 2,
  ADVENTURE: 3,
  BUILD_OR_ADVENTURE: 4,
  ADVENTURE_BUILD: 5,
};

/** Official phase restrictions for spell categories (base set). */
export function spellAllowedInPhase(category, phase) {
  if (category === SPELL_CATEGORY.ADVENTURE_BUILD || category === SPELL_CATEGORY.BUILD_OR_ADVENTURE) {
    return phase === PHASE.BUILD || phase === PHASE.ADVENTURE;
  }
  if (category === SPELL_CATEGORY.BUILD || category === SPELL_CATEGORY.BUILD_TPK) {
    return phase === PHASE.BUILD;
  }
  if (category === SPELL_CATEGORY.ADVENTURE) {
    return phase === PHASE.ADVENTURE;
  }
  return false;
}

/** Counterspell (BMA043) may be played whenever a spell is on the stack. */
export function canPlaySpell(card, phase, stackLength = 0) {
  if (card?.id === 'BMA043' && stackLength > 0) return true;
  return spellAllowedInPhase(card?.category, phase);
}

const APK_BACK = {
  'back-room': 'back_room',
  'back-boss': 'back_boss',
  'back-spell': 'back_spell',
  'back-hero': 'back_ordinary_hero',
  'back-epic': 'back_epic_hero',
  'back-item': 'back_item',
};

export function getWikiCardImage(id, kind) {
  const base = '/cards/';
  const ext = '.webp';
  const prefix = (id || '').toString().toUpperCase();
  const mappedName = cardData.nameMap?.[prefix] || prefix;
  if (kind === 'epic-hero') return base + 'epic-heroes/' + prefix + '_' + mappedName + ext;
  const file = prefix + '_' + mappedName + ext;
  switch (kind) {
    case 'boss': return base + 'bosses/' + file;
    case 'room': return base + 'rooms/' + file;
    case 'spell': return base + 'spells/' + file;
    case 'hero': return base + 'heroes/' + file;
    case 'epic-hero': return base + 'epic-heroes/' + file;
    case 'item': return base + 'items/' + file;
    case 'back-room': return base + 'backs/back_room' + ext;
    case 'back-boss': return base + 'backs/back_boss' + ext;
    case 'back-spell': return base + 'backs/back_spell' + ext;
    case 'back-hero': return base + 'backs/back_ordinary_hero' + ext;
    case 'back-epic': return base + 'backs/back_epic_hero' + ext;
    case 'back-item': return base + 'backs/back_item' + ext;
    default: return '';
  }
}

export function getApkCardImage(id, kind) {
  const faces = apkCardManifest?.faces || {};
  const backs = apkCardManifest?.backs || {};
  if (kind && String(kind).startsWith('back-')) {
    const key = APK_BACK[kind];
    const rel = (key && backs[key]) || (key && faces[key]);
    return rel ? '/apk_cards/' + rel : '';
  }
  if (!id) return '';
  const stem = String(id).toLowerCase();
  const rel = faces[stem] || faces[stem + 'a'];
  return rel ? '/apk_cards/' + rel : '';
}

export function getCardImage(id, kind) {
  return getWikiCardImage(id, kind) || getApkCardImage(id, kind);
}

export const PHASE = {
  BOSS: 'boss',
  SETUP: 'setup',
  BEGINNING: 'beginning',
  BUILD: 'build',
  BAIT: 'bait',
  ADVENTURE: 'adventure',
  END: 'end'
};

export function playerOrderByXP(players) {
  return Object.entries(players)
    .map(([pid, p]) => ({ pid: parseInt(pid), xp: p.boss?.xp || 0, eliminated: p.eliminated }))
    .filter(p => !p.eliminated)
    .sort((a, b) => b.xp - a.xp || a.pid - b.pid)
    .map(p => p.pid);
}

export function totalSouls(p) {
  let n = (p.souls || []).reduce((sum, s) => sum + (s.souls || 1), 0);
  if (p.bonusSouls) n += p.bonusSouls;
  const tpk = (p.souls || []).find(s => s.tpk);
  if (tpk) {
    const classes = new Set((p.souls || []).map(s => s.class).filter(Boolean));
    if (['Cleric', 'Fighter', 'Mage', 'Thief'].every(c => classes.has(c))) n += 2;
  }
  return n;
}

export function totalWounds(p) {
  return p.wounds.reduce((sum, w) => sum + (w.wounds || 1), 0);
}

// 2.2.6 mix packs the player can toggle after "HOW MANY PLAYERS?".
// `expansions == null` means "all packs" (online default / tests).
// `expansions === []` is base set only — Hidden Heroes is not injected.
export const EXPANSION_PACKS = [
  { id: 'hidden-heroes', label: 'HIDDEN HEROES', cover: '/ui/expansions/hh_cover_unlocked.webp' },
  { id: 'tools', label: 'TOOLS OF HERO-KIND', cover: '/ui/expansions/thk_cover_unlocked.webp' },
  { id: 'players-choice', label: "PLAYER'S CHOICE", cover: '/ui/expansions/pc_cover_unlocked.webp' },
];

export function allowedCardSets(expansions) {
  const sets = new Set(['base']);
  const packs = expansions == null ? EXPANSION_PACKS.map((p) => p.id) : expansions;
  for (const id of packs) {
    if (id) sets.add(id);
  }
  return sets;
}

export function cardsInSets(cards, sets) {
  return cards.filter((c) => !c.set || sets.has(c.set));
}

/** Hidden Heroes replaces the base BMA hero deck (same stats, new art). */
export function heroesForSets(heroes, sets) {
  const list = cardsInSets(heroes, sets);
  if (sets.has('hidden-heroes')) return list.filter((h) => h.set !== 'base');
  return list;
}

export function getExpandedDeck(cards) {
  const out = [];
  cards.forEach(c => {
    const qty = c.quantity || 1;
    for (let i = 0; i < qty; i++) out.push({ ...c });
  });
  return out;
}

export function shuffle(deck) {
  const a = [...deck];
  for (let i = a.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [a[i], a[j]] = [a[j], a[i]];
  }
  return a;
}

export function drawCards(deck, count) {
  const drawn = [];
  for (let i = 0; i < count; i++) {
    if (deck.length === 0) break;
    drawn.push(deck.pop());
  }
  return drawn;
}

export function refillDeckFromDiscard(deck, discard) {
  if (deck.length > 0 || discard.length === 0) return;
  while (discard.length > 0) deck.push(discard.pop());
  // Shuffle in place (don't reassign the local variable — the caller's array
  // must be mutated).
  for (let i = deck.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [deck[i], deck[j]] = [deck[j], deck[i]];
  }
}

export const TREASURE_ICON_NAME = { 1: 'cleric', 2: 'fighter', 3: 'mage', 4: 'thief' };
export function treasureIcon(treasure) {
  return `/ui/icons/icon_${TREASURE_ICON_NAME[treasure] || 'cleric'}.webp`;
}

export function roomTypeIcon(type, advanced = false) {
  if (type === 'trap') {
    return advanced ? '/ui/ingame/room_icon_advanced_trap.webp' : '/ui/ingame/room_icon_trap.webp';
  }
  return advanced ? '/ui/ingame/room_icon_advanced_monster.webp' : '/ui/ingame/room_icon_monster.webp';
}

// Boss treasure type -> display theme (name + accent color). Used for dungeon
// panel tinting and the boss portrait banner.
export const TREASURE_THEME = {
  1: { name: 'Cleric', color: '#FBBF24', glow: 'rgba(251,191,36,0.25)' },   // gold
  2: { name: 'Fighter', color: '#EF4444', glow: 'rgba(239,68,68,0.25)' },   // red
  3: { name: 'Mage', color: '#3B82F6', glow: 'rgba(59,130,246,0.25)' },     // blue
  4: { name: 'Thief', color: '#10B981', glow: 'rgba(16,185,129,0.25)' },    // green
};

export function bossTheme(boss) {
  if (!boss || !boss.treasures || !boss.treasures.length) return TREASURE_THEME[1];
  return TREASURE_THEME[boss.treasures[0]] || TREASURE_THEME[1];
}

export default cardData;