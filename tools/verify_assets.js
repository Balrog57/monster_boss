#!/usr/bin/env node
// verify_assets.js - Check apk card manifest and key UI assets exist on disk.
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
  '/ui/ingame/room_icon_monster.webp',
  '/ui/ingame/room_icon_trap.webp',
  '/ui/icons/icon_cleric.webp',
];
for (const rel of uiSamples) {
  const r = exists(rel);
  if (!r.ok) missing.push(r.full + (r.empty ? ' (empty)' : ''));
}

if (missing.length) {
  console.error(`[verify_assets] ${missing.length} missing or empty:`);
  missing.slice(0, 20).forEach((m) => console.error('  ', m));
  if (missing.length > 20) console.error(`  ... and ${missing.length - 20} more`);
  process.exit(1);
}

console.log('[verify_assets] OK — all manifest faces/backs and UI samples present.');
process.exit(0);
