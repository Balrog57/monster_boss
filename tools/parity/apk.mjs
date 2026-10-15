// Parite Godot <-> APK ORIGINALE (oracle = DBMGame.dll 2.2.6 headless, tools/apk-oracle).
//
//   npm run test:parity:apk
//   node tools/parity/apk.mjs [--seeds 1 2 3] [--players 2 3] [--skip-gen]
//
// 1. genere les traces oracle (seeds x joueurs, BaseDeck) dans tools/parity/out/apk/
// 2. Godot (ApkParity.tscn) rejoue chaque trace (aucune aide) et enregistre sa projection
//    apres chaque step de l'oracle
// 3. ce script projette l'etat de l'oracle de la meme facon, compare aux points de
//    controle (voir README.md) et ecrit tools/parity/out/apk/report.json
//
// Le harnais ne corrige aucune regle : il rapporte.

import fs from 'node:fs';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import { fileURLToPath, pathToFileURL } from 'node:url';

const HERE = path.dirname(fileURLToPath(import.meta.url));
const REPO = path.resolve(HERE, '../..');
export const OUT = path.join(HERE, 'out', 'apk');

// --- projection de l'oracle (miroir de ApkParityTrace.project) ---------------

const PHASE = {
  Setup_a: 'setup', Setup_b: 'setup', Setup_c: 'setup',
  BeginningOfTurn: 'build', BuildPhase_a: 'build', BuildPhase_b: 'build', ExtraBuildPhase: 'build',
  BaitPhase: 'adventure', AdventurePhase_a: 'adventure', AdventurePhase_b: 'adventure', AdventurePhase_c: 'adventure',
  EndOfTurnPhase: 'end', EndOfGame: 'over',
};

export function oracleProj(step, trace) {
  const players = {};
  for (const p of step.players) {
    const slots = p.dungeon.filter((s) => s.rooms.length > 0); // slot 0 = fond, comme Godot inverse
    players[p.playerId] = {
      souls: p.souls, wounds: p.wounds,
      hand: p.hand.map((c) => c.card).sort(),
      spells: p.spells.map((c) => c.card).sort(),
      dungeon: slots.map((s) => s.rooms.map((r) => r.card)),
      pending: slots.map((s) => !!s.pending),
      entrance: p.entrance.map((h) => h.card).sort(),
    };
  }
  const dc = step.deckCounts;
  return {
    phase: PHASE[step.phase], turn: step.turn, active: step.activePlayer,
    town: step.heroesInTown.map((h) => h.card),
    hero: step.activeHero ? { card: step.activeHero.card, hp: step.activeHero.hp } : null,
    winner: step.phase === 'EndOfGame' ? trace.winner?.playerId ?? null : null,
    decks: { heroes: dc.heroes, rooms: dc.rooms, spells: dc.spells, discardRooms: dc.discardRooms, discardSpells: dc.discardSpells },
    players,
  };
}

// --- points de controle -------------------------------------------------------

const DECKS = ['decks'];
const P = (...f) => f.map((x) => `players.*.${x}`);
const KINDS = {
  setup: ['phase', ...DECKS, ...P('hand', 'spells')],
  turnstart: ['phase', 'turn', 'town', ...DECKS, ...P('souls', 'wounds', 'hand', 'spells', 'dungeon', 'entrance')],
  build: ['phase', 'turn', 'active', ...P('hand', 'spells', 'dungeon', 'pending')],
  bait: ['phase', 'turn', 'town', ...DECKS, ...P('souls', 'wounds', 'hand', 'spells', 'dungeon', 'entrance')],
  adv: ['phase', 'hero', ...P('souls', 'wounds')],
  over: ['phase', 'winner', ...P('souls', 'wounds')],
};

function checkKind(steps, i) {
  const s = steps[i];
  if (s.kind === 'decision' && s.detail.decision === 'discard' && s.phase === 'Setup_a') {
    const later = steps.slice(i + 1).some((n) => n.kind === 'decision' && n.detail.decision === 'discard' && n.phase === 'Setup_a');
    return later ? null : 'setup';
  }
  if (s.kind !== 'phase') return null;
  switch (s.phase) {
    case 'BeginningOfTurn': return 'turnstart';
    case 'BuildPhase_a': return s.activePlayer != null ? 'build' : null;
    case 'BaitPhase': return 'bait';
    case 'AdventurePhase_c': return 'adv';
    case 'EndOfGame': return 'over';
    default: return null;
  }
}

// Apres une fenetre de sorts, l'oracle repete le joueur actif alors que Godot a deja passe au suivant : `active` n'est plus comparable.
function skipFields(steps, i, kind) {
  if (kind !== 'build') return [];
  const ap = steps[i].activePlayer;
  for (let j = i - 1; j >= 0 && steps[j].kind !== 'phase'; j--) {
    const d = steps[j].detail;
    if (d?.action === 'spellBattleReady' || (d?.action === 'buildRoom' && d.player === ap)) return ['active'];
  }
  return [];
}

function flatten(o, prefix = '', out = {}) {
  if (o !== null && typeof o === 'object' && !Array.isArray(o)) {
    for (const k of Object.keys(o)) flatten(o[k], prefix ? `${prefix}.${k}` : k, out);
  } else out[prefix] = o;
  return out;
}
const specRe = (spec) => new RegExp(`^${spec.replace(/\./g, '\\.').replace(/\*/g, '[^.]+')}(\\.|$)`);
const group = (p) => p.replace(/^players\.[^.]+\./, 'players.*.').replace(/^decks\..*/, 'decks');

export function diffProj(o, g, kind, skip = []) {
  const fo = flatten(o);
  const fg = flatten(g);
  const res = KINDS[kind].filter((k) => !skip.includes(k)).map(specRe);
  const out = [];
  for (const p of Object.keys(fo)) {
    if (!res.some((re) => re.test(p))) continue;
    if (JSON.stringify(fo[p]) === JSON.stringify(fg[p] ?? null)) continue;
    out.push({ field: p, group: group(p), oracle: fo[p], godot: fg[p] ?? null });
  }
  return out;
}

// --- comparaison d'une trace ---------------------------------------------------

function compareTrace(trace, gd) {
  const steps = trace.steps;
  const checks = [];
  let matched = 0;
  let firstDivergence = null;
  const firstByField = {};
  for (let i = 0; i < steps.length; i++) {
    const kind = checkKind(steps, i);
    if (!kind) continue;
    const s = steps[i];
    // turnstart/bait : Godot enchaine parfois plusieurs phases en un coup, on compare a sa photo prise au bon moment.
    const g = kind === 'turnstart' || kind === 'bait' ? gd.snaps[`${kind}:${s.turn}`] : gd.proj[String(s.seq)];
    const diffs = g ? diffProj(oracleProj(s, trace), g, kind, skipFields(steps, i, kind)) : [{ field: '(point non atteint par Godot)', group: '-', oracle: null, godot: null }];
    checks.push({ seq: s.seq, kind, ok: diffs.length === 0 });
    if (diffs.length === 0) { matched++; continue; }
    const d = diffs[0];
    const rec = { seq: s.seq, turn: s.turn, phase: s.phase, check: kind, field: d.field, oracle: d.oracle, godot: d.godot, moreFields: diffs.length - 1 };
    if (!firstDivergence) firstDivergence = rec;
    for (const x of diffs) firstByField[x.group] ??= { seq: s.seq, phase: s.phase, field: x.field, oracle: x.oracle, godot: x.godot };
  }
  const refus = gd.events.filter((e) => e.type === 'REFUS');
  const firstRefus = refus[0] ?? null;
  const first = [firstRefus && { k: 'REFUS', seq: firstRefus.seq }, firstDivergence && { k: 'DIVERGE', seq: firstDivergence.seq }]
    .filter(Boolean).sort((a, b) => a.seq - b.seq)[0];
  return {
    status: first ? `${first.k}@${first.seq}` : 'OK',
    firstRefus, firstDivergence, firstByField,
    refusCount: refus.length, checks: checks.length, matched,
    notes: gd.events.filter((e) => e.type !== 'REFUS').length,
    stats: gd.stats,
  };
}

// --- orchestration --------------------------------------------------------------

function generate(seeds, players) {
  fs.mkdirSync(OUT, { recursive: true });
  for (const f of fs.readdirSync(OUT)) if (/^(oracle|gd-).*\.json$|^report\.json$/.test(f)) fs.unlinkSync(path.join(OUT, f));
  const names = [];
  for (const seed of seeds) {
    for (const n of players) {
      const name = `oracle-s${seed}-p${n}.json`;
      const r = spawnSync('dotnet', ['run', '--project', 'tools/apk-oracle', '-v', 'q', '--', '--seed', String(seed), '--players', String(n), '--out', path.join(OUT, name)],
        { cwd: REPO, encoding: 'utf8' });
      const out = `${r.stdout ?? ''}${r.stderr ?? ''}`.trim();
      if (!fs.existsSync(path.join(OUT, name))) { console.error(`[apk-parity] oracle ${name} ECHEC\n${out}`); process.exit(1); }
      console.log(`[apk-parity] ${out.split('\n').pop()}`);
      names.push(name);
    }
  }
  return names;
}

function godotExe() {
  if (process.env.GODOT) return process.env.GODOT;
  const win = 'C:/Tools/Godot/Godot_v4.7.2-stable_win64_console.exe';
  return process.platform === 'win32' && fs.existsSync(win) ? win : 'godot';
}

function runGodot() {
  const args = ['--headless', '--path', path.join(REPO, 'src/frontend'), 'res://godot/tests/ApkParity.tscn', '--', `--traces=${OUT.replace(/\\/g, '/')}`];
  const r = spawnSync(godotExe(), args, { encoding: 'utf8', timeout: 900000, shell: godotExe() === 'godot' && process.platform === 'win32' });
  const out = `${r.stdout ?? ''}${r.stderr ?? ''}`;
  if (!out.includes('APK PARITY OK')) {
    console.error('[apk-parity] le rejeu Godot a echoue :');
    console.error(out.split('\n').filter((l) => /ERROR|SCRIPT|FAIL/.test(l)).slice(0, 20).join('\n') || out.slice(-2000));
    process.exit(1);
  }
  return out.split('\n').filter((l) => /SCRIPT ERROR|^ERROR|Parse Error/.test(l));
}

const fmt = (v) => { const s = JSON.stringify(v); return s.length > 70 ? `${s.slice(0, 67)}...` : s; };

async function main() {
  const argv = process.argv.slice(2);
  const list = (flag, dflt) => { const i = argv.indexOf(flag); if (i < 0) return dflt; const out = []; for (let k = i + 1; k < argv.length && !argv[k].startsWith('--'); k++) out.push(Number(argv[k])); return out; };
  const seeds = list('--seeds', [1, 2, 3]);
  const players = list('--players', [2, 3]);
  const names = argv.includes('--skip-gen') ? fs.readdirSync(OUT).filter((f) => /^oracle-.*\.json$/.test(f)) : generate(seeds, players);

  const godotErrors = runGodot();
  const traces = [];
  const unmapped = new Set();
  for (const name of names) {
    const trace = JSON.parse(fs.readFileSync(path.join(OUT, name), 'utf8'));
    const id = name.replace(/^oracle-/, '');
    const entry = { trace: name.replace(/^oracle-|\.json$/g, ''), seed: trace.meta.seed, players: trace.meta.players, oracleSteps: trace.steps.length, oracleResult: trace.result, oracleTurns: trace.turns };
    const gd = JSON.parse(fs.readFileSync(path.join(OUT, `gd-${id}`), 'utf8'));
    gd.unmapped.forEach((c) => unmapped.add(c));
    Object.assign(entry, compareTrace(trace, gd));
    traces.push(entry);
  }

  const report = { generatedAt: new Date().toISOString(), godot: godotExe(), godotScriptErrors: godotErrors.length, unmappedCards: [...unmapped].sort(), traces };
  fs.writeFileSync(path.join(OUT, 'report.json'), JSON.stringify(report, null, 2));

  console.log('');
  console.log(`[apk-parity] cartes non mappees: ${report.unmappedCards.length ? report.unmappedCards.join(', ') : 'aucune'}   erreurs de script Godot: ${godotErrors.length}`);
  console.log('');
  console.log('trace      checks ok/total  refus  statut         premiere divergence d\'etat');
  for (const r of traces) {
    const d = r.firstDivergence;
    console.log(`${r.trace.padEnd(10)} ${String(r.matched).padStart(5)}/${String(r.checks).padEnd(5)}   ${String(r.refusCount).padStart(5)}  ${r.status.padEnd(13)}  ${d ? `seq ${d.seq} ${d.phase} ${d.field} oracle=${fmt(d.oracle)} godot=${fmt(d.godot)}` : '-'}`);
    if (r.firstRefus) { const f = r.firstRefus; console.log(`           premier REFUS: seq ${f.seq} ${f.phase} P${f.player} ${f.move} (${f.reason}; godot phase=${f.godotPhase} actif=P${f.godotActive} legal=[${f.legal.join(',')}])`); }
  }
  console.log('');
  console.log('== premiere divergence par groupe de champs (trace@seq) : classe les causes, au-dela de la toute premiere');
  const groups = {};
  for (const t of traces) for (const [g, v] of Object.entries(t.firstByField)) (groups[g] ??= []).push(`${t.trace}@${v.seq}`);
  for (const [g, v] of Object.entries(groups).sort((a, b) => b[1].length - a[1].length)) console.log(`  ${g.padEnd(22)} ${v.length}/${traces.length}  ${v.join(' ')}`);
  console.log('');
  console.log(`[apk-parity] rapport: ${path.join(OUT, 'report.json')}`);
  console.log('APK PARITY RAPPORT OK');
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) await main();
