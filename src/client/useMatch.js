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
import { setupMatch, applyMove, playerView, legalMoves, pickOpeningDiscardIndices } from '../../server/reducer.js';
import { aiEnumerate, aiPickMove } from '../ai.js';
import { aiResolveLevelUpChoice } from '../roomAbilities.js';
import { aiDelayMs } from '../audio.js';
import {
  joinMatch, sendMove, subscribeState, subscribeEnded, subscribeErrors, subscribeNotifications, disconnect
} from './socket.js';

const DEFAULT_NUM_PLAYERS = 2;

export function useOnlineMatch({ matchID, playerID, credentials, onExitMatch }) {
  const [G, setG] = useState(null);
  const [ctx, setCtx] = useState(null);
  const [isConnected, setIsConnected] = useState(false);
  const [error, setError] = useState('');
  const [turnDeadline, setTurnDeadline] = useState(null);
  const [notification, setNotification] = useState('');

  useEffect(() => {
    let unsubState, unsubEnded, unsubErrors, unsubNotif;
    let cancelled = false;
    let notifTimeout = null;

    (async () => {
      try {
        const { G: g, ctx: c, turnDeadline: td } = await joinMatch(matchID, playerID, credentials);
        if (cancelled) return;
        setG(g); setCtx(c); setTurnDeadline(td || null); setIsConnected(true);
        unsubState = subscribeState(matchID, ({ G, ctx, turnDeadline }) => {
          setG(G); setCtx(ctx); setTurnDeadline(turnDeadline || null);
        });
        unsubEnded = subscribeEnded(matchID, ({ winner }) => {
          // The next match:state will carry G.gameOver; nothing to do here.
        });
        unsubErrors = subscribeErrors(matchID, (msg) => setError(msg));
        unsubNotif = subscribeNotifications(matchID, (message) => {
          setNotification(message);
          clearTimeout(notifTimeout);
          notifTimeout = setTimeout(() => setNotification(''), 5000);
        });
      } catch (e) {
        if (!cancelled) setError(e.message);
      }
    })();

    return () => {
      cancelled = true;
      clearTimeout(notifTimeout);
      unsubState && unsubState();
      unsubEnded && unsubEnded();
      unsubErrors && unsubErrors();
      unsubNotif && unsubNotif();
      disconnect();
    };
  }, [matchID, playerID, credentials]);

  // moves: thin wrappers that send socket events. The server applies the move
  // and broadcasts the new state back, which updates G/ctx via subscribeState.
  const moves = useRef({}).current;
  for (const type of ['pickBoss', 'buildInitialRoom', 'buildRoom', 'playSpell', 'resolveNextHero', 'pass', 'activateRoom', 'resolveLevelUpChoice', 'openingDiscard']) {
    moves[type] = (...args) => sendMove(matchID, { type, args });
  }

  const isActive = useCallback(() => {
    if (!G || !ctx) return false;
    return String(ctx.activePlayer) === String(playerID);
  }, [G, ctx, playerID]);

  return { G, ctx, moves, isActive: isActive(), isConnected, error, playerID, onExitMatch, turnDeadline, notification };
}

export function useLocalMatch({ numPlayers = DEFAULT_NUM_PLAYERS, setupData = {}, onExitMatch }) {
  const [state, setState] = useState(() => setupMatch(numPlayers, setupData));
  const [, forceTick] = useState(0);

  const applyAndDriveAI = useCallback((nextState) => {
    setState(nextState);
    const driveAI = (current) => {
      let s = current;
      let steps = 0;
      const step = () => {
        if (s.G.gameOver || steps++ > 80) return;
        if (s.G.pendingChoice) {
          const choicePid = s.G.pendingChoice.playerId;
          const choicePlayer = s.G.players[choicePid];
          if (choicePlayer && choicePlayer.isAI) {
            if (s.G.pendingChoice.type === 'opening-discard') {
              const pair = pickOpeningDiscardIndices(choicePlayer.hand);
              if (!pair) return;
              const { state: ns, error } = applyMove({ G: s.G, ctx: s.ctx }, { type: 'openingDiscard', args: pair }, choicePid);
              if (!error) {
                s = { G: ns.G, ctx: ns.ctx };
                setState(s);
                setTimeout(step, aiDelayMs());
              }
              return;
            }
            const optIdx = aiResolveLevelUpChoice(s.G, s.G.pendingChoice);
            const { state: ns, error } = applyMove({ G: s.G, ctx: s.ctx }, { type: 'resolveLevelUpChoice', args: [optIdx] }, choicePid);
            if (!error) {
              s = { G: ns.G, ctx: ns.ctx };
              setState(s);
              setTimeout(step, aiDelayMs());
              return;
            }
          }
          return;
        }
        const p = s.G.players[s.ctx.activePlayer];
        if (!p || !p.isAI || p.eliminated) return;
        const moves = legalMoves(s.G, s.ctx, s.ctx.activePlayer);
        if (moves.length > 0) {
          const pick = aiPickMove(s.G, s.ctx, s.ctx.activePlayer) || moves[0];
          const { state: ns, error } = applyMove({ G: s.G, ctx: s.ctx }, pick, s.ctx.activePlayer);
          if (error) {
            const fallback = moves.find((m) => m.type === 'pass') || moves.find((m) => JSON.stringify(m) !== JSON.stringify(pick));
            if (!fallback) return;
            const retry = applyMove({ G: s.G, ctx: s.ctx }, fallback, s.ctx.activePlayer);
            if (retry.error) return;
            s = { G: retry.state.G, ctx: retry.state.ctx };
            setState(s);
            setTimeout(step, aiDelayMs());
            return;
          }
          s = { G: ns.G, ctx: ns.ctx };
          setState(s);
          setTimeout(step, aiDelayMs());
          return;
        }
        if (!p.passed) {
          const { state: ns, error } = applyMove({ G: s.G, ctx: s.ctx }, { type: 'pass', args: [] }, s.ctx.activePlayer);
          if (error) return;
          s = { G: ns.G, ctx: ns.ctx };
          setState(s);
          setTimeout(step, aiDelayMs());
        }
      };
      step();
    };
    driveAI(nextState);
  }, []);

  // moves: apply locally via the reducer. playerID is always '0' for the human.
  const moves = useRef({}).current;
  for (const type of ['pickBoss', 'buildInitialRoom', 'buildRoom', 'playSpell', 'resolveNextHero', 'pass', 'activateRoom', 'resolveLevelUpChoice', 'openingDiscard']) {
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