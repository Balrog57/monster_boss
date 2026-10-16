#!/usr/bin/env node
// Lance les suites de tests Godot headless et echoue si un marqueur de succes manque.
// Godot sous Windows ne propage pas toujours le code de sortie : on verifie la sortie.
import { spawnSync } from 'node:child_process';

const SUITES = [
  { scene: 'res://godot/tests/Goldens.tscn', ok: 'GOLDENS OK', label: 'goldens' },
  { scene: 'res://godot/tests/Coverage.tscn', ok: 'COVERAGE OK', label: 'coverage' },
  { scene: 'res://godot/tests/Soak.tscn', ok: 'SOAK OK', label: 'soak' },
  { scene: 'res://godot/tests/Soak.tscn', ok: 'SOAK OK', label: 'soak APK decks', args: ['--', '--sets=players-choice,hidden-heroes,tools'] },
  { scene: 'res://godot/tests/Soak.tscn', ok: 'SOAK OK', label: 'soak The Next Level', args: ['--', '--sets=next-level', '--runs=4'] },
  { scene: 'res://godot/tests/Soak.tscn', ok: 'SOAK OK', label: 'soak Minibosses', args: ['--', '--sets=minibosses', '--runs=4'] },
  { scene: 'res://godot/tests/Soak.tscn', ok: 'SOAK OK', label: 'soak all packs', args: ['--', '--sets=players-choice,hidden-heroes,tools,next-level,crash-landing,minibosses', '--runs=3'] },
  { scene: 'res://godot/tests/OnlineTest.tscn', ok: 'ONLINE OK', label: 'online' },
  { scene: 'res://godot/tests/UiSmoke.tscn', ok: 'UISMOKE OK', label: 'ui smoke' },
];

let failed = 0;
for (const { scene, ok, label, args = [] } of SUITES) {
  const r = spawnSync('godot', ['--headless', '--path', 'src/frontend', scene, ...args], {
    encoding: 'utf8',
    timeout: 300000,
    shell: process.platform === 'win32',
  });
  // Sous Windows, 'godot' est un godot.cmd : le timeout ne tue que cmd.exe et laisse Godot
  // orphelin (verrou d'import). On tue donc l'arbre de CE run uniquement. Un taskkill global
  // sur Godot*.exe tuait aussi les runs Godot concurrents (editeur, autres suites) et
  // produisait de faux echecs sur l'un ou l'autre.
  if (r.error && process.platform === 'win32' && r.pid) {
    try { spawnSync('taskkill', ['/F', '/T', '/PID', String(r.pid)], { stdio: 'ignore' }); } catch {}
  }
  const out = `${r.stdout ?? ''}${r.stderr ?? ''}`;
  if (out.includes(ok)) {
    console.log(`[godot] ${label}: OK`);
  } else {
    failed++;
    console.error(`[godot] ${label}: ECHEC`);
    console.error(out.split('\n').filter((l) => /ERROR|ECHEC|SCRIPT/.test(l)).slice(0, 10).join('\n'));
  }
}
process.exit(failed ? 1 : 0);