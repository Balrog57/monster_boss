// src/client/useMatch.js - React hook exposing { G, ctx, moves, isActive, isConnected }.
//
// Two modes:
//   - 'online': state comes from the server via Socket.IO. moves emit
//     'match:move' and the server is the authority.
//   - 'local': state is computed locally via server/reducer.js (imported as a
//     pure module). moves apply the reducer directly. AI seats are driven by
//     src/ai.js after each human move.
//
// The returned shape matches what AppBoard.jsx expects so the board works
// unchanged in both modes.
import { useEffect, useRef, useState, useCallback } from 'react';
import { setupMatch, applyMove, playerView, legalMoves } from '../../server/reducer.js';
import { aiEnumerate } from '../ai.js';
import {
  joinMatch, sendMove, subscribeState, subscribeEnded, subscribeErrors, disconnect
} from './socket.js';

const DEFAULT_NUM_PLAYERS = 2;

export function useOnlineMatch({ matchID, playerID, credentials, onExitMatch }) {
  const [G, setG] = useState(null);
  const [ctx, setCtx] = useState(null);
  const [isConnected, setIsConnected] = useState(false);
  const [error, setError] = useState('');

  useEffect(() => {
    let unsubState, unsubEnded, unsubErrors;
    let cancelled = false;

    (async () => {
      try {
        const { G: g, ctx: c } = await joinMatch(matchID, playerID, credentials);
        if (cancelled) return;
        setG(g); setCtx(c); setIsConnected(true);
        unsubState = subscribeState(matchID, ({ G, ctx }) => { setG(G); setCtx(ctx); });
        unsubEnded = subscribeEnded(matchID, ({ winner }) => {
          // The next match:state will carry G.gameOver; nothing to do here.
        });
        unsubErrors = subscribeErrors(matchID, (msg) => setError(msg));
      } catch (e) {
        if (!cancelled) setError(e.message);
      }
    })();

    return () => {
      cancelled = true;
      unsubState && unsubState();
      unsubEnded && unsubEnded();
      unsubErrors && unsubErrors();
      disconnect();
    };
  }, [matchID, playerID, credentials]);

  // moves: thin wrappers that send socket events. The server applies the move
  // and broadcasts the new state back, which updates G/ctx via subscribeState.
  const moves = useRef({}).current;
  for (const type of ['pickBoss', 'buildInitialRoom', 'buildRoom', 'playSpell', 'resolveNextHero', 'pass', 'activateRoom']) {
    moves[type] = (...args) => sendMove(matchID, { type, args });
  }

  const isActive = useCallback(() => {
    if (!G || !ctx) return false;
    return String(ctx.activePlayer) === String(playerID);
  }, [G, ctx, playerID]);

  return { G, ctx, moves, isActive: isActive(), isConnected, error, playerID, onExitMatch };
}

export function useLocalMatch({ numPlayers = DEFAULT_NUM_PLAYERS, onExitMatch }) {
  const [state, setState] = useState(() => setupMatch(numPlayers));
  const [, forceTick] = useState(0);

  const applyAndDriveAI = useCallback((nextState) => {
    setState(nextState);
    // Drive AI moves sequentially until it's the human's turn again or the
    // phase expects a human action. This is a simple loop with a microtask
    // break to let React render the intermediate states.
    const driveAI = (current) => {
      let s = current;
      const step = () => {
        const p = s.G.players[s.ctx.activePlayer];
        if (!p || (p.isAI && !p.eliminated && !s.G.gameOver)) {
          const moves = legalMoves(s.G, s.ctx, s.ctx.activePlayer);
          if (moves.length > 0) {
            const candidates = aiEnumerate(s.G, s.ctx, s.ctx.activePlayer);
            const pick = (candidates && candidates.length > 0)
              ? { type: candidates[0].move, args: candidates[0].args }
              : moves[0];
            const { state: ns, error } = applyMove({ G: s.G, ctx: s.ctx }, pick, s.ctx.activePlayer);
            if (error) { return; }
            s = { G: ns.G, ctx: ns.ctx };
            setState(s);
            setTimeout(step, 300);
            return;
          }
          // AI has no legal moves — pass to advance the phase.
          if (p && p.isAI && !p.passed) {
            const { state: ns } = applyMove({ G: s.G, ctx: s.ctx }, { type: 'pass', args: [] }, s.ctx.activePlayer);
            s = { G: ns.G, ctx: ns.ctx };
            setState(s);
            setTimeout(step, 300);
            return;
          }
        }
      };
      step();
    };
    driveAI(nextState);
  }, []);

  // moves: apply locally via the reducer. playerID is always '0' for the human.
  const moves = useRef({}).current;
  for (const type of ['pickBoss', 'buildInitialRoom', 'buildRoom', 'playSpell', 'resolveNextHero', 'pass', 'activateRoom']) {
    moves[type] = (...args) => {
      const { state: next, error } = applyMove({ G: state.G, ctx: state.ctx }, { type, args }, 0);
      if (error) { console.warn(`[move] ${type} rejected:`, error); return; }
      applyAndDriveAI(next);
    };
  }

  const isActive = String(state.ctx.activePlayer) === '0';

  // playerView-filter the state for the human so opponent hands are hidden,
  // mirroring the online behavior.
  const G = playerView(state.G, '0');

  return { G, ctx: state.ctx, moves, isActive, isConnected: true, error: '', playerID: '0', onExitMatch };
}