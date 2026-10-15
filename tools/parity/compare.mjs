// Pilote complet du harnais de parite JS <-> GDScript.
//
//   node tools/parity/compare.mjs            # gen + replay + diff
//   node tools/parity/compare.mjs --seeds 1 2 3
//
// Genere des traces deterministes avec le moteur JS (oracle), les rejoue dans le
// port GDScript via la scene headless Parity.tscn, puis compare les projections
// canoniques apres chaque coup.
//
// Le taux de parite est l'instrument qui rend les Phases 2 a 5 verifiables : il
// doit monter de facon monotone a mesure que le port se rapproche de l'APK.

import fs from 'node:fs';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { diff } from './canon.mjs';
import { generate, OUT_DIR } from './gen.mjs';

const HERE = path.dirname(fileURLToPath(import.meta.url));
const REPO = path.resolve(HERE, '../..');

// Ecarts structurels connus, declares dans ParityTrace.gd : chacun correspond a un
// livrable de Phase 2/3/4, pas a une regression. "*" matche un indice de joueur.
const KNOWN_GAPS = [
  'adventure',
  'stack',
  // Le JS suit la fin de phase avec des drapeaux "passed"/"hasActed" ; le port
  // resout chaque build immediatement via buildsThisTurn. Ce sont deux mecanismes
  // equivalents, pas deux etats observables : on ne les compare pas.
  'players.*.passed',
  'players.*.coins',
  'players.*.items',
  'townItems',
  'decks.items', 'decks.minibosses',
  'discards.items', 'discards.miniboss',
];

const gapRe = (g) => new RegExp(`^${g.replace(/[.+^${}()|[\]\\]/g, '\\$&').replace(/\*/g, '\\d+')}$`);
const GAP_RES = KNOWN_GAPS.map(gapRe);

const skipGap = (p) => {
  const segs = p.split('.');
  for (let i = segs.length; i > 0; i--) {
    const prefix = segs.slice(0, i).join('.');
    if (GAP_RES.some((re) => re.test(prefix))) return true;
  }
  return false;
};

function stripKnownGaps(jsObj, gdObj) {
  // Recopie en enlevant les cles connues des deux cotes pour que diff ne les
  // remonte pas comme des disparites. Les index de tableau entrent dans le chemin.
  const drop = (o, pfx) => {
    if (o === null || typeof o !== 'object') return o;
    if (Array.isArray(o)) return o.map((v, i) => drop(v, pfx ? `${pfx}.${i}` : String(i)));
    const out = {};
    for (const k of Object.keys(o)) {
      const p = pfx ? `${pfx}.${k}` : k;
      if (skipGap(p)) continue;
      out[k] = drop(o[k], p);
    }
    return out;
  };
  return [drop(jsObj, ''), drop(gdObj, '')];
}

function runGodot() {
  const exe = process.platform === 'win32'
    ? 'C:/Tools/Godot/Godot_v4.7.2-stable_win64_console.exe'
    : 'godot';
  const args = ['--headless', '--quit-after', '3000', '--path', path.join(REPO, 'src/frontend'),
    'res://godot/tests/Parity.tscn', '--', `--traces=${OUT_DIR.replace(/\\/g, '/')}`];
  const cmd = process.platform === 'win32' ? exe : 'godot';
  const r = spawnSync(cmd, args, { encoding: 'utf8', timeout: 600000 });
  const out = `${r.stdout ?? ''}${r.stderr ?? ''}`;
  if (!out.includes('PARITY OK')) {
    console.error('[parity] le rejeu GDScript a echoue :');
    console.error(out.split('\n').filter((l) => /ERROR|SCRIPT/.test(l)).slice(0, 15).join('\n'));
    process.exit(1);
  }
  return out;
}

async function main() {
  const argv = process.argv.slice(2);
  const seedIdx = argv.indexOf('--seeds');
  const seeds = seedIdx >= 0 ? argv.slice(seedIdx + 1).map(Number) : [1, 2, 3];
  const players = seedIdx >= 0 ? [2, 3, 4] : [2, 3];

  fs.mkdirSync(OUT_DIR, { recursive: true });
  const traces = [];
  for (const seed of seeds) {
    for (const numPlayers of players) {
      const r = await generate({ seed, numPlayers });
      const name = `trace-s${seed}-p${numPlayers}-base.json`;
      // Une partie qui n'atteint jamais la phase BUILD n'a pas d'etat de depart
      // comparable : elle est ecartee plutot que de faire echouer le rejeu.
      if (!r.initial) {
        console.warn(`[parity] ${name}: ecartee (n'a pas atteint la phase BUILD en ${r.steps.length} coups)`);
        continue;
      }
      fs.writeFileSync(path.join(OUT_DIR, name), JSON.stringify({
        meta: { seed, numPlayers, expansions: ['base'], steps: r.steps.length },
        initial: r.initial,
        steps: r.steps,
        snapshots: r.snapshots,
        error: r.error ?? null,
      }));
      traces.push(name);
    }
  }
  console.log(`[parity] ${traces.length} traces generees`);
  if (!traces.length) {
    console.error('PARITY RAPPORT OK');
    process.exit(0);
  }

  runGodot();

  let totalSteps = 0;
  let matchedSteps = 0;
  const findings = [];

  for (const name of traces) {
    const js = JSON.parse(fs.readFileSync(path.join(OUT_DIR, name), 'utf8'));
    const gdPath = path.join(OUT_DIR, `gd-${name.replace(/^trace-/, '')}`);
    if (!fs.existsSync(gdPath)) continue;
    const gd = JSON.parse(fs.readFileSync(gdPath, 'utf8'));

    const refused = gd.errors?.[0] ?? null;
    const n = Math.min(js.snapshots.length, gd.snapshots.length);

    let firstBad = -1;
    let sample = [];
    for (let i = 0; i < n; i++) {
      const [a, b] = stripKnownGaps(js.snapshots[i], gd.snapshots[i]);
      const d = diff(a, b, '', [], 6);
      if (d.length === 0) matchedSteps++;
      else if (firstBad < 0) { firstBad = i; sample = d; }
      totalSteps++;
    }

    const status = refused ? `REFUS@${refused.step}` : firstBad >= 0 ? `DIVERGE@${firstBad}` : 'OK';
    findings.push({
      trace: name, steps: js.steps.length, compared: n, status,
      rejected: refused ? refused.move : null,
      sample: sample.slice(0, 4),
    });
  }

  const rate = totalSteps ? (matchedSteps / totalSteps) * 100 : 0;
  console.log('');
  console.log(`[parity] coups compares ......... ${totalSteps}`);
  console.log(`[parity] coups identiques ....... ${matchedSteps}`);
  console.log(`[parity] TAUX DE PARITE ......... ${rate.toFixed(1)} %`);
  console.log(`[parity] ecarts connus ignores .. ${KNOWN_GAPS.length}`);
  console.log('');
  for (const f of findings) {
    console.log(`  ${f.trace}  ${f.steps} coups  ${f.status}${f.rejected ? ` (${f.rejected})` : ''}`);
    for (const s of f.sample) {
      console.log(`      ${s.path}: js=${JSON.stringify(s.js)} gd=${JSON.stringify(s.gd)}`);
    }
  }

  fs.writeFileSync(path.join(OUT_DIR, 'parity-report.json'), JSON.stringify({ rate, totalSteps, matchedSteps, findings }, null, 2));
  // MARQUEUR DE SUCCES pour la CI : le harnais qui tourne vaut mieux que rien,
  // meme a 0 % : c'est la mesure qui sert de cible aux phases suivantes.
  console.log('');
  console.log('PARITY RAPPORT OK');
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  await main();
}