// src/BossMonster.js - Re-exports the reducer-based game definition.
//
// The game logic now lives in server/reducer.js (pure, framework-free). This
// shim keeps the named exports that other modules historically imported, so
// existing imports continue to work during the migration.
export {
  setupMatch,
  applyMove,
  playerView,
  legalMoves,
  GAME_META
} from '../server/reducer.js';

// Backward-compat: some old code imported the game name/limits from here.
export const GAME_NAME = GAME_META?.name || 'boss-monster';
export const MIN_PLAYERS = GAME_META?.minPlayers || 2;
export const MAX_PLAYERS = GAME_META?.maxPlayers || 4;
export default GAME_META;