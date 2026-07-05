// cardData.js - loads the generated card data and provides game helpers
import cardData from './cardData.json';

export const BOSSES = cardData.bosses;
export const ROOMS = cardData.rooms;
export const SPELLS = cardData.spells;
export const HEROES = cardData.heroes;

export const TREASURE_NAMES = ['?', 'Cleric', 'Fighter', 'Mage', 'Thief'];
export const ROOM_TYPE = { MONSTER: 'monster', TRAP: 'trap' };
export const SPELL_CATEGORY = {
  ANY: 0,
  BUILD: 1,
  BAIT: 2,
  ADVENTURE: 3,
  BUILD_BAIT: 4,
  ADVENTURE_BUILD: 5
};
export function getCardImage(id, kind) {
  // Map card id to actual extracted asset path
  const base = '/assets/cards/';
  const prefix = (id || '').toString().toUpperCase();
  const mappedName = cardData.nameMap?.[prefix] || prefix;
  // Epic hero path uses folder epic-heroes
  if (kind === 'epic-hero') return base + 'epic-heroes/' + prefix + '_' + mappedName + '.jpg';
  const file = prefix + '_' + mappedName + '.jpg';
  switch (kind) {
    case 'boss': return base + 'bosses/' + file;
    case 'room': return base + 'rooms/' + file;
    case 'spell': return base + 'spells/' + file;
    case 'hero': return base + 'heroes/' + file;
    case 'epic-hero': return base + 'epic-heroes/' + file;
    case 'back-room': return base + 'backs/back_room.jpg';
    case 'back-boss': return base + 'backs/back_boss.jpg';
    case 'back-spell': return base + 'backs/back_spell.jpg';
    case 'back-hero': return base + 'backs/back_ordinary_hero.jpg';
    case 'back-epic': return base + 'backs/back_epic_hero.jpg';
    default: return '';
  }
}

export const PHASE = {
  BOSS: 'boss',
  SETUP: 'setup',
  BUILD: 'build',
  BAIT: 'bait',
  ADVENTURE: 'adventure',
  END: 'end'
};

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

export function treasureIcon(treasure) {
  return `/assets/ui/icons/treasure_${treasure}.png`;
}

export function roomTypeIcon(type) {
  return `/assets/ui/icons/${type}.png`;
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