#!/usr/bin/env node
// Lance les suites de tests Godot headless et echoue si un marqueur de succes manque.
// Godot sous Windows ne propage pas toujours le code de sortie : on verifie la sortie.
import { spawnSync } from 'node:child_process';

const SUITES = [
  { scene: 'res://godot/tests/Goldens.tscn', ok: 'GOLDENS OK', label: 'goldens' },
  { scene: 'res://godot/tests/Coverage.tscn', ok: 'COVERAGE OK', label: 'coverage' },
  { scene: 'res://godot/tests/Soak.tscn', ok: 'SOAK OK', label: 'soak' },
];

let failed = 0;
for (const { scene, ok, label } of SUITES) {
  // Un processus Godot residuel (run interrompu) peut verrouiller l'import cache
  // et faire expirer le delai : on nettoie avant chaque suite.
  if (process.platform === 'win32') {
    try { spawnSync('taskkill', ['/F', '/IM', 'Godot*.exe'], { stdio: 'ignore' }); } catch {}
  }
  const r = spawnSync('godot', ['--headless', '--path', 'src/frontend', scene], {
    encoding: 'utf8',
    timeout: 300000,
    shell: process.platform === 'win32',
  });
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