import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const ROOT = path.join(path.dirname(fileURLToPath(import.meta.url)), '..');
const MATRIX = path.join(ROOT, 'docs', 'card-matrix.json');

describe('card compliance matrix', () => {
  it('exists and has no corrupt expansion text', () => {
    assert.ok(fs.existsSync(MATRIX), 'run: node tools/generate_card_matrix.js');
    const matrix = JSON.parse(fs.readFileSync(MATRIX, 'utf8'));
    assert.equal(matrix.summary.corrupt, 0, `corrupt cards: ${matrix.summary.corrupt}`);
    assert.ok(matrix.summary.total > 200);
  });
});
