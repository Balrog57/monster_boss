// Genere des traces deterministes en pilotant le moteur JS (oracle) avec sa
// propre IA, puis enregistre la projection canonique apres chaque coup.
//
// Determinisme : reducer.js/cardData.js melangent avec Math.random(). On
// remplace Math.random par mulberry32 AVANT d'appeler setupMatch, donc une
// graine redonne toujours la meme distribution. C'est indispensable : sans cela
// deux executions de l'JS ne joueraient pas la meme partie, et la comparaison
// avec GDScript n'aurait aucun sens.

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { canon } from './canon.mjs';

const HERE = path.dirname(fileURLToPath(import.meta.url));
export const OUT_DIR = path.join(HERE, 'out');

function mulberry32(seed) {
  let a = seed >>> 0;
  return () => {
    a = (a + 0x6d2b79f5) >>> 0;
    let t = a;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

export async function generate({ seed = 1, numPlayers = 2, expansions = ['base'], maxSteps = 400 } = {}) {
  Math.random = mulberry32(seed);
  // Import dynamique : le moteur lit Math.random a l'appel, pas a l'import,
  // mais on charge quand meme apres le patch pour rester explicite.
  const { setupMatch, applyMove, legalMoves, pickOpeningDiscardIndices } = await import('../../src/backend/game/reducer.js');
  const { aiPickMove } = await import('../../src/backend/game/ai.js');
  const { aiResolveLevelUpChoice } = await import('../../src/backend/game/roomAbilities.js');

  let state = setupMatch(numPlayers, { expansions, humanCount: 0 });
  const steps = [];
  const snapshots = [];

  // La trace demarre en phase BUILD. Tout ce qui precede est volontairement
  // ecarte, car les deux moteurs y divergent LEGITIMEMENT et plus profondement
  // que dans le reste du jeu :
  //  - l'APK n'a pas de phase de pose de salle initiale. GameBoard.GamePhases
  //    enchaine Setup_a (5 salles + 2 sorts + melange de 2), Setup_b (controle),
  //    Setup_c ( revelation) puis BeginningOfTurn. InternalInititalizeGameBoard ne
  //    place aucune salle : la premiere se construit en BuildPhase_a comme les
  //    autres. Le coup "buildInitialRoom" du moteur JS est donc une invention,
  //    et le port GDScript ne l'a plus.
  //  - l'APK n'a pas de coup "pickBoss" non plus : le boss est attribue a
  //    l'initialisation et l'ecran est un caroussel cosmetique.
  // On fige donc l'etat au premier tour de BUILD, ou les deux moteurs doivent
  // reellement concorder.
  let initial = null;

  const buildReady = (G) =>
    G.phase === 'build' &&
    (!G.pendingChoice || Object.keys(G.pendingChoice).length === 0) &&
    Object.values(G.players).every((p) => Array.isArray(p.hand) && p.hand.length > 0 && p.boss);

  for (let n = 0; n < maxSteps; n++) {
    const { G, ctx } = state;
    if (G.gameOver === true || (G.gameOver && typeof G.gameOver === 'object')) break;

    // Gel de l'etat au premier moment ou la comparaison a du sens.
    if (initial === null) {
      if (!buildReady(G)) {
        const m = legalMoves(G, ctx, ctx.activePlayer ?? 0)[0] ?? { type: 'pass', args: [] };
        const pid = ctx.activePlayer ?? 0;
        const r0 = applyMove(state, m, pid);
        if (r0.error) break;
        state = r0.state;
        continue;
      }
      initial = JSON.parse(JSON.stringify(state));
      snapshots.push(canon(state.G, state.ctx));
      continue;
    }

    let pid;
    let move;

    if (G.pendingChoice && Object.keys(G.pendingChoice).length > 0) {
      pid = G.pendingChoice.playerId;
      if (G.pendingChoice.type === 'opening-discard') {
        move = { type: 'openingDiscard', args: pickOpeningDiscardIndices(G.players[pid].hand) };
      } else {
        move = { type: 'resolveLevelUpChoice', args: [aiResolveLevelUpChoice(G, G.pendingChoice)] };
      }
    } else if (G.adventure?.pause) {
      const pausers = Object.keys(G.players).filter((p) => !G.players[p]?.eliminated && !G.adventurePausePassed?.[p]);
      if (pausers.length === 0) break;
      pid = Number(pausers[0]);
      move = { type: 'pass', args: [] };
    } else {
      pid = ctx.activePlayer;
      const moves = legalMoves(G, ctx, pid);
      move = aiPickMove(G, ctx, pid) || (moves.length ? moves[0] : { type: 'pass', args: [] });
      if (move.type === 'pass' && !moves.some((m) => m.type === 'pass')) {
        // Le moteur JS exige un coup qu'il sait resoudre ; on ne devine pas.
        const alt = moves.find((m) => m.type === 'resolveNextHero') || moves[0];
        if (!alt) break;
        move = alt;
      }
    }

    const r = applyMove(state, move, pid);
    if (r.error) {
      return { error: `step ${n}: ${move.type} -> ${r.error}`, steps, snapshots, state, initial };
    }
    steps.push({ pid, move });
    state = r.state;
    snapshots.push(canon(state.G, state.ctx));
  }

  return { steps, snapshots, state, initial };
}

function fileName(seed, numPlayers, expansions) {
  return `trace-s${seed}-p${numPlayers}-${expansions.join('_')}.json`;
}

async function main() {
  const args = process.argv.slice(2);
  const seeds = args.length ? args.map(Number) : [1, 2, 3, 4, 5];
  fs.mkdirSync(OUT_DIR, { recursive: true });

  let totalSteps = 0;
  for (const seed of seeds) {
    for (const numPlayers of [2, 3]) {
      const r = await generate({ seed, numPlayers });
      const name = fileName(seed, numPlayers, ['base']);
      const payload = {
        meta: { seed, numPlayers, expansions: ['base'], steps: r.steps.length },
        // L'etat initial complet : GDScript l'adopte tel quel plutot que de
        // rejouer un PRNG (impossible a reproduire entre Float64 et float32).
        initial: r.initial,
        steps: r.steps,
        snapshots: r.snapshots,
      };
      if (r.error) {
        payload.error = r.error;
        console.error(`[parity] ${name}: INCOMPLET (${r.error}) apres ${r.steps.length} coups`);
      }
      fs.writeFileSync(path.join(OUT_DIR, name), JSON.stringify(payload));
      totalSteps += r.steps.length;
      const phases = new Set(r.snapshots.map((s) => s.phase));
      console.log(`[parity] ${name}: ${r.steps.length} coups, phases=[${[...phases].join(',')}]`);
    }
  }
  console.log(`[parity] ${seeds.length * 2} traces, ${totalSteps} coups au total -> ${OUT_DIR}`);
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  await main();
}