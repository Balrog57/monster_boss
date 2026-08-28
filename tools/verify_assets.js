#!/usr/bin/env node
// verify_assets.js - Check apk card manifest, base-set data, and key UI assets.
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const root = path.join(__dirname, '..');
const assetsDir = path.join(root, 'assets');

function exists(rel) {
  const full = path.join(assetsDir, rel.replace(/^\//, ''));
  if (!fs.existsSync(full)) return { ok: false, full };
  const stat = fs.statSync(full);
  if (stat.size <= 0) return { ok: false, full, empty: true };
  return { ok: true, full };
}

const manifest = JSON.parse(
  fs.readFileSync(path.join(root, 'src', 'apkCardManifest.json'), 'utf8')
);
const cardData = JSON.parse(
  fs.readFileSync(path.join(root, 'src', 'cardData.json'), 'utf8')
);

const missing = [];
for (const rel of Object.values(manifest.faces || {})) {
  const r = exists('/apk_cards/' + rel);
  if (!r.ok) missing.push(r.full + (r.empty ? ' (empty)' : ''));
}
for (const rel of Object.values(manifest.backs || {})) {
  const r = exists('/apk_cards/' + rel);
  if (!r.ok) missing.push(r.full + (r.empty ? ' (empty)' : ''));
}

const uiSamples = [
  '/ui/ingame/pass_button.webp',
  '/ui/ingame/discard_pile.webp',
  '/ui/ingame/card_slot.webp',
  '/ui/ingame/room_icon_monster.webp',
  '/ui/ingame/room_icon_trap.webp',
  '/ui/icons/icon_cleric.webp',
];
for (const rel of uiSamples) {
  const r = exists(rel);
  if (!r.ok) missing.push(r.full + (r.empty ? ' (empty)' : ''));
}

function collect(list) {
  return (list || []).filter((c) => !c.set || c.set === 'base');
}
const bosses = collect(cardData.bosses);
const rooms = collect(cardData.rooms);
const spells = collect(cardData.spells);
const heroes = collect(cardData.heroes);

const dataIssues = [];
if (bosses.length !== 8) dataIssues.push(`expected 8 base bosses, got ${bosses.length}`);
if (rooms.length < 31) dataIssues.push(`expected ≥31 base rooms, got ${rooms.length}`);
if (spells.length < 16) dataIssues.push(`expected ≥16 base spells, got ${spells.length}`);
if (heroes.length < 41) dataIssues.push(`expected ≥41 base heroes (BMA056–096), got ${heroes.length}`);

for (const c of [...bosses, ...rooms, ...spells, ...heroes]) {
  const stem = String(c.id).toLowerCase();
  const rel = (manifest.faces || {})[stem] || (manifest.faces || {})[stem + 'a'];
  if (!rel) dataIssues.push(`no APK face for ${c.id}`);
  if (!c.name) dataIssues.push(`${c.id} missing name`);
}

if (missing.length || dataIssues.length) {
  if (missing.length) {
    console.error(`[verify_assets] ${missing.length} missing or empty files:`);
    missing.slice(0, 20).forEach((m) => console.error('  ', m));
    if (missing.length > 20) console.error(`  ... and ${missing.length - 20} more`);
  }
  if (dataIssues.length) {
    console.error(`[verify_assets] ${dataIssues.length} card-data issues:`);
    dataIssues.slice(0, 20).forEach((m) => console.error('  ', m));
    if (dataIssues.length > 20) console.error(`  ... and ${dataIssues.length - 20} more`);
  }
  process.exit(1);
}

console.log(`[verify_assets] OK — base set ${bosses.length} bosses, ${rooms.length} rooms, ${spells.length} spells, ${heroes.length} heroes; all APK faces present.`);
process.exit(0);
