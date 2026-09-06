#!/usr/bin/env node
/** Build docs/card-matrix.json — compliance inventory per card ID. */
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.join(__dirname, '..');
const OUT = path.join(ROOT, 'docs', 'card-matrix.json');

const cardData = JSON.parse(fs.readFileSync(path.join(ROOT, 'src', 'cardData.json'), 'utf8'));
const nameMap = cardData.nameMap || {};

const CORRUPT = /\]\]$/;
const EXP_SETS = new Set(['next-level', 'minibosses', 'crash-landing']);
const TAGGED_KEYS = [
  'genericSpell', 'genericLevelUp', 'gainCoin',
  'onBuildDrawRoom', 'onBuildDrawSpell', 'onBuildHealWound', 'onBuildExtraBuild',
  'onUncover', 'onHeroDieDrawSpell', 'onHeroDieDrawRoom',
  'destroyOnHeroDie', 'destroyOnHeroSurvive',
];

function loadHandlerIds() {
  const ids = new Set();
  const files = [
    'src/expansionBosses.js',
    'src/roomAbilities.js',
    'src/spellEffects.js',
    'src/minibosses.js',
  ];
  const caseRe = /\bcase\s+['"]([A-Z]{3}\d{3}[A-Z]?)['"]/g;
  const keyRe = /^\s*([A-Z]{3}\d{3}[A-Z]?)\s*:/gm;
  for (const rel of files) {
    const full = path.join(ROOT, rel);
    if (!fs.existsSync(full)) continue;
    const src = fs.readFileSync(full, 'utf8');
    for (const re of [caseRe, keyRe]) {
      re.lastIndex = 0;
      let m;
      while ((m = re.exec(src))) ids.add(m[1]);
    }
  }
  return ids;
}

const HANDLER_IDS = loadHandlerIds();

function cardImagePath(id, section, card) {
  const slug = nameMap[id] || id.toLowerCase();
  const dir = section === 'heroes' && card.epic ? 'epic-heroes'
    : section === 'bosses' ? 'bosses'
    : section === 'rooms' ? 'rooms'
    : section === 'spells' ? 'spells'
    : section === 'items' ? 'items'
    : card.epic ? 'epic-heroes' : 'heroes';
  return path.join(ROOT, 'assets', 'cards', dir, `${id}_${slug}.webp`);
}

function textField(card, section) {
  if (section === 'bosses') return card.levelUpDesc || '';
  if (section === 'spells' || section === 'rooms') return card.description || '';
  if (section === 'minibosses') return (card.levels || []).map((l) => l.description).join(' ');
  return '';
}

function inferStatus(card, section) {
  const text = textField(card, section);
  if (CORRUPT.test(text)) return 'data-corrupt';
  if (card.implemented === true || card.effect || card.handler) return 'explicit';
  if (HANDLER_IDS.has(card.id)) return 'explicit';
  if (TAGGED_KEYS.some((k) => card[k])) return 'tagged';
  if (card.dark) return 'tagged';
  if (EXP_SETS.has(card.set)) return 'expansion-pending';
  if (section === 'heroes' && card.hp != null) return 'stat-only';
  return 'base-implicit';
}

const matrix = { generatedAt: new Date().toISOString(), cards: {} };
const sections = ['bosses', 'rooms', 'spells', 'heroes', 'items', 'minibosses'];

for (const section of sections) {
  for (const card of cardData[section] || []) {
    const id = card.id;
    const img = cardImagePath(id, section, card);
    matrix.cards[id] = {
      id,
      name: card.name,
      section,
      set: card.set || 'base',
      text: textField(card, section),
      textCorrupt: CORRUPT.test(textField(card, section)),
      status: inferStatus(card, section),
      hasArt: fs.existsSync(img),
      tags: Object.keys(card).filter((k) => k.startsWith('on') || k.startsWith('generic') || k === 'gainCoin' || k === 'effect'),
    };
  }
}

const summary = { total: 0, corrupt: 0, missingArt: 0, expansionPending: 0 };
for (const row of Object.values(matrix.cards)) {
  summary.total += 1;
  if (row.textCorrupt) summary.corrupt += 1;
  if (!row.hasArt && EXP_SETS.has(row.set)) summary.missingArt += 1;
  if (row.status === 'expansion-pending') summary.expansionPending += 1;
}
matrix.summary = summary;

fs.mkdirSync(path.dirname(OUT), { recursive: true });
fs.writeFileSync(OUT, JSON.stringify(matrix, null, 2) + '\n');
console.log(`[card-matrix] ${summary.total} cards, corrupt=${summary.corrupt}, expansion-pending=${summary.expansionPending}, missing expansion art=${summary.missingArt}`);
if (summary.corrupt > 0) process.exit(1);
