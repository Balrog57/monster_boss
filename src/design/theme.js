// theme.js - JS bridge to the CSS design tokens.
//
// Most styling should live in *.module.css files using `var(--bm-*)`. This
// module is for the few cases that need token values in JS:
//   - Dynamic styles computed from game data (e.g. treasureTheme colors)
//   - Inline styles that can't be replaced without a larger refactor
//   - Canvas/SVG fills
//
// The values mirror tokens.css exactly — keep them in sync when changing one.
// If a value diverges, the CSS file is the source of truth.

export const colors = {
  bg900: '#06040a',
  bg800: '#0a0a0f',
  bg700: '#15121f',
  bg600: '#1f1a2e',
  bg500: '#1a1525',
  accent: '#7c3aed',
  accentDark: '#5b21b6',
  gold: '#fcd34d',
  goldDark: '#f59e0b',
  success: '#10b981',
  successDark: '#047857',
  danger: '#f87171',
  dangerDark: '#dc2626',
  rust: '#e11d48',
  text900: '#f3f4f6',
  text700: '#d1d5db',
  text500: '#a1a1aa',
  text400: '#9ca3af',
  text300: '#6b7280',
  border900: '#2d2540',
  border500: '#4b5563',
};

// Treasure class -> theme (matches cardData.js TREASURE_THEME).
// Used for dungeon tinting and boss portraits.
export const treasureTheme = {
  1: { name: 'Cleric',  color: '#FBBF24', glow: 'rgba(251,191,36,0.25)' },
  2: { name: 'Fighter', color: '#EF4444', glow: 'rgba(239,68,68,0.25)' },
  3: { name: 'Mage',    color: '#3B82F6', glow: 'rgba(59,130,246,0.25)' },
  4: { name: 'Thief',   color: '#10B981', glow: 'rgba(16,185,129,0.25)' },
};

export function bossTheme(boss) {
  if (!boss || !boss.treasures || !boss.treasures.length) return treasureTheme[1];
  return treasureTheme[boss.treasures[0]] || treasureTheme[1];
}

// Breakpoints (px). Mirror the CSS vars --bm-bp-*.
export const breakpoints = {
  sm: 640,
  md: 768,
  lg: 1024,
  xl: 1280,
};