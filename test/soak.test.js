// Deterministic all-AI soak: every configuration must reach a terminal state
// without rejected moves, AI stalls or a frozen state (see test/helpers/aiSoak.js).
import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { playOne, ALL_PACKS } from './helpers/aiSoak.js';

const CASES = [
  { label: 'base only, 2 players', expansions: [], numPlayers: 2 },
  { label: 'base only, 4 players', expansions: [], numPlayers: 4 },
  { label: 'base only, 5 players', expansions: [], numPlayers: 5 },
  { label: 'minibosses, 3 players', expansions: ['minibosses'], numPlayers: 3 },
  { label: 'tools, 3 players', expansions: ['tools'], numPlayers: 3 },
  { label: 'next-level, 3 players', expansions: ['next-level'], numPlayers: 3 },
  { label: 'players-choice, 3 players', expansions: ['players-choice'], numPlayers: 3 },
  { label: 'crash-landing, 3 players', expansions: ['crash-landing'], numPlayers: 3 },
  { label: 'next-level + minibosses, 4 players', expansions: ['next-level', 'minibosses'], numPlayers: 4 },
  { label: 'tools + crash-landing, 4 players', expansions: ['tools', 'crash-landing'], numPlayers: 4 },
  { label: 'all packs, 2 players', expansions: ALL_PACKS, numPlayers: 2 },
  { label: 'all packs, 4 players', expansions: ALL_PACKS, numPlayers: 4 },
  { label: 'default packs, 4 players', expansions: null, numPlayers: 4 },
  { label: 'default packs, 6 players', expansions: null, numPlayers: 6 },
];

for (const [i, c] of CASES.entries()) {
  it(`finishes a game — ${c.label}`, () => {
    const r = playOne({ expansions: c.expansions, numPlayers: c.numPlayers, seed: i + 1 });
    const detail = r.dump ? `\n${JSON.stringify(r.dump, null, 1)}` : '';
    assert.equal(r.ok, true, `${r.error}${detail}`);
    assert.ok(r.moves > 0 && r.moves < 3000, 'the game ran to a terminal state');
    assert.ok(r.winner != null || Array.isArray(r.souls), 'a terminal state was reached');
  });
}
