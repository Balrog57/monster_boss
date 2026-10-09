import { setupMatch, applyMove, legalMoves, pickOpeningDiscardIndices } from '../../../src/backend/game/reducer.js';
import { aiPickMove, aiChooseBoss } from '../../../src/backend/game/ai.js';
import { aiResolveLevelUpChoice } from '../../../src/backend/game/roomAbilities.js';
import { promoteMiniboss as rawPromote, canPromoteMiniboss } from '../../../src/backend/game/minibosses.js';
import { spellsBlockedFor } from '../../../src/backend/game/items.js';

const ALL = ['hidden-heroes', 'tools', 'players-choice', 'next-level', 'minibosses', 'crash-landing'];

function seeded(seed) {
  let s = (seed >>> 0) || 1;
  return () => { s ^= s << 13; s ^= s >>> 17; s ^= s << 5; s >>>= 0; return s / 4294967296; };
}

/** Mirror of server/matches.js checkAndRunBotTurn, synchronous, all-AI. */
function step(G, ctx) {
  let pid = ctx.activePlayer;
  let move = null;

  if (G.pendingChoice) {
    pid = G.pendingChoice.playerId;
    if (G.pendingChoice.type === 'opening-discard') {
      move = { type: 'openingDiscard', args: pickOpeningDiscardIndices(G.players[pid].hand) };
    } else {
      const idx = aiResolveLevelUpChoice(G, G.pendingChoice);
      move = { type: 'resolveLevelUpChoice', args: [idx ?? 0] };
    }
  } else if (!G.stack?.length && G.adventure?.pause) {
    const aiPid = Object.keys(G.players).find((id) => G.players[id].isAI && !G.players[id].eliminated && !G.adventurePausePassed?.[id]);
    if (aiPid == null) return { G, ctx, move: null, pid: null };
    pid = Number(aiPid);
    move = { type: 'pass', args: [] };
  } else if (G.phase === 'boss' && G.players[pid] && !G.players[pid].boss) {
    const available = (G.bossPicks || []).filter((b) => !Object.values(G.players).some((pl) => pl.boss?.id === b.id));
    const chosen = aiChooseBoss(available);
    move = { type: 'pickBoss', args: [chosen?.id] };
  } else {
    move = aiPickMove(G, ctx, pid);
  }

  if (!move) move = { type: 'pass', args: [] };
  return { G, ctx, move, pid };
}

/**
 * The engine draws with Math.random (deck shuffles, random room/spell picks),
 * so an unseeded run is irreproducible across machines and CI. Install the
 * xorshift stream as Math.random for the duration of one game and restore it
 * afterwards, so every case replays identically everywhere.
 */
function installSeededRandom(seed) {
  const rnd = seeded(seed);
  const original = Math.random;
  Math.random = rnd;
  return () => { Math.random = original; };
}

export function playOne({ expansions, numPlayers, seed, maxMoves = 3000 }) {
  const restoreRandom = installSeededRandom(seed);
  try {
    return runGame({ expansions, numPlayers, seed, maxMoves });
  } finally {
    restoreRandom();
  }
}

function runGame({ expansions, numPlayers, seed, maxMoves }) {
  let state = setupMatch(numPlayers, { expansions, humanCount: 0 });
  let moves = 0;
  let nullPicks = 0;
  const seen = new Map();
  for (; moves < maxMoves; moves++) {
    if (state.ctx.gameover || state.G.gameOver) break;
    const { G, ctx } = state;
    const { move, pid } = step(G, ctx);
    if (pid == null) return { ok: false, error: 'AI stall (adventure pause exhausted)', moves, seed };
    if (!move || (move.type === 'pass' && !G.pendingChoice && !G.adventure?.pause && !G.stack?.length)) nullPicks++;

    // Detect a state that stops evolving (same fingerprint repeating).
    const fp = fingerprint(G, ctx);
    const hits = (seen.get(fp) || 0) + 1;
    seen.set(fp, hits);
    if (hits > 25) {
      return { ok: false, error: `deadlock: state repeated ${hits}x at ${fp} (moves=${moves})`, moves, seed, nullPicks };
    }

    const res = applyMove(state, move, pid);
    if (res.error) {
      return {
        ok: false,
        error: `${move.type}(${JSON.stringify(move.args)}): ${res.error}`,
        moves, seed, phase: G.phase, choice: G.pendingChoice?.type, nullPicks,
        dump: dumpState(G, ctx, pid, move),
      };
    }
    state = res.state;
  }
  const over = state.ctx.gameover || state.G.gameOver;
  if (!over) return { ok: false, error: `no terminal state in ${maxMoves} moves (phase=${state.G.phase})`, moves, seed, nullPicks };
  return { ok: true, moves, winner: over.winner, nullPicks, souls: Object.values(state.G.players).map((p) => p.souls?.length || 0) };
}

function fingerprint(G, ctx) {
  const players = Object.values(G.players);
  return [
    `t=${G.turn}`,
    G.phase,
    `act=${ctx.activePlayer}`,
    `adv=${G.adventure ? `${G.adventure.playerId}:${G.adventure.roomIndex}:${G.adventure.hp}` : '-'}`,
    `stk=${G.stack?.length || 0}`,
    `pause=${G.adventure?.pause ? 1 : 0}`,
    ...players.map((p, i) => `${i}[h${p.hand.length}d${p.dungeon.length}e${p.entrance.length}p${p.passed ? 1 : 0}b${p.boss ? 1 : 0}${p.eliminated ? 'X' : ''}]`),
  ].join('|');
}

function probe(G, pid, move) {
  const stack = G.players[pid]?.dungeon?.[move.args?.[0] ?? 0];
  const mb = stack?.miniboss;
  const out = {
    playersKeys: Object.keys(G.players),
    stackCount: G.players[pid]?.dungeon?.length ?? 0,
    ringBlocked: spellsBlockedFor(G, pid),
  };
  if (move.type === 'promoteMiniboss') {
    out.mb = mb ? { id: mb.card?.id, level: mb.level, faceDown: mb.faceDown, isNull: false } : { isNull: true };
    out.stackIsArray = Array.isArray(stack);
    out.cloneHasMb = !!(JSON.parse(JSON.stringify(stack))).miniboss;
    out.clonePlayersIsArray = Array.isArray(G.players);
    out.rawErr = rawPromote(JSON.parse(JSON.stringify(G)), pid, move.args?.[0] ?? 0) ?? null;
    out.rawErrNoClone = rawPromote(G, pid, move.args?.[0] ?? 0) ?? null;
    out.canPromote = canPromoteMiniboss(G, pid, move.args?.[0] ?? 0);
    out.coins = G.players[pid]?.coins;
    out.handHasRing = (G.players[pid]?.hand || []).some((c) => c.id === 'THK020');
    out.entranceItems = (G.players[pid]?.entrance || []).map((h) => h.item?.id).filter(Boolean);
  }
  if (move.type === 'playSpell') {
    out.rawRingErr = spellsBlockedFor(G, pid);
    out.handRing = (G.players[pid]?.hand || []).some((c) => c.id === 'THK020');
    out.entranceItems = (G.players[pid]?.entrance || []).map((h) => h.item?.id).filter(Boolean);
    out.advHeroItem = G.adventure && String(G.adventure.playerId) === String(pid) ? G.adventure.hero?.item?.id : 'not-adventure-player';
    out.npcRing = Object.entries(G.players).map(([k, v]) => `${k}:${(v.entrance || []).map((h) => h.item?.id).filter((x) => x === 'THK020').length}`).join(',');
  }
  return out;
}

function dumpState(G, ctx, pid, move) {
  const p = G.players[pid];
  return {
    move,
    turn: G.turn,
    phase: G.phase,
    active: ctx.activePlayer,
    pid,
    coins: p?.coins,
    logs: (G.logs || []).slice(-15),
    probe: probe(G, pid, move),
    hand: (p?.hand || []).map((c) => `${c.id} ${c.name}`),
    dungeon: (p?.dungeon || []).map((s, idx) => ({
      idx,
      room: s.room?.name || s.name,
      faceDown: s.faceDown,
      advanced: s.advanced,
      mini: s.miniboss
        ? {
            id: s.miniboss.card?.id ?? s.miniboss.id,
            level: s.miniboss.level,
            faceDown: s.miniboss.faceDown,
            usedL3: s.miniboss.usedL3,
            usedThisTurn: s.miniboss.usedThisTurn,
          }
        : null,
    })),
    legalSameType: legalMoveSummary(G, ctx, pid, move.type),
  };
}

function legalMoveSummary(G, ctx, pid, type) {
  return legalMoves(G, ctx, pid).filter((m) => m.type === type);
}

export { ALL as ALL_PACKS };
