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
import { aiPickMove } from '../ai.js';
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
  for (const type of ['pickBoss', 'buildInitialRoom', 'buildRoom', 'buildMiniboss', 'promoteMiniboss', 'activateMiniboss', 'payDarkHero', 'playSpell', 'resolveNextHero', 'pass', 'activateRoom', 'resolveLevelUpChoice', 'openingDiscard']) {
    moves[type] = (...args) => sendMove(matchID, { type, args });
  }

  const isActive = useCallback(() => {
    if (!G || !ctx) return false;
    return String(ctx.activePlayer) === String(playerID);
  }, [G, ctx, playerID]);

  return { G, ctx, moves, isActive: isActive(), isConnected, error, playerID, onExitMatch, turnDeadline, notification };
}

export function useLocalMatch({ numPlayers = DEFAULT_NUM_PLAYERS, setupData = {}, viewingPlayer = '0', onExitMatch }) {
  const [state, setState] = useState(() => setupMatch(numPlayers, setupData));
  // One scheduled AI action per current state; a human response cancels stale work.
  useEffect(() => {
    const { G, ctx } = state;
    if (G.gameOver) return;
    let pid = ctx.activePlayer;
    let move;
    if (G.pendingChoice) {
      pid = G.pendingChoice.playerId;
      if (!G.players[pid]?.isAI) return;
      move = G.pendingChoice.type === 'opening-discard'
        ? { type: 'openingDiscard', args: pickOpeningDiscardIndices(G.players[pid].hand) }
        : { type: 'resolveLevelUpChoice', args: [aiResolveLevelUpChoice(G, G.pendingChoice)] };
    } else if (!G.stack?.length && G.adventure?.pause) {
      pid = Object.keys(G.players).find(id => G.players[id].isAI && !G.players[id].eliminated && !G.adventurePausePassed?.[id]);
      if (pid == null) return;
      move = { type: 'pass', args: [] };
    } else {
      if (!G.players[pid]?.isAI || G.players[pid].eliminated) return;
      move = aiPickMove(G, ctx, pid);
    }
    if (!move) return;
    const timer = setTimeout(() => {
      const result = applyMove(state, move, pid);
      if (result.error) {
        console.error('[AI] Legal move rejected:', result.error);
        return;
      }
      setState(result.state);
    }, aiDelayMs());
    return () => clearTimeout(timer);
  }, [state]);

  // moves: apply locally via the reducer.
  const moves = useRef({}).current;
  for (const type of ['pickBoss', 'buildInitialRoom', 'buildRoom', 'buildMiniboss', 'promoteMiniboss', 'activateMiniboss', 'payDarkHero', 'playSpell', 'resolveNextHero', 'pass', 'activateRoom', 'resolveLevelUpChoice', 'openingDiscard']) {
    moves[type] = (...args) => {
      const actor = Number(viewingPlayer);
      setState(current => {
        const { state: next, error } = applyMove(current, { type, args }, actor);
        if (error) { console.warn(`[move] ${type} rejected:`, error); return current; }
        return next;
      });
    };
  }

  const isActive = String(state.ctx.activePlayer) === String(viewingPlayer);

  const G = playerView(state.G, viewingPlayer);

  return { G, ctx: state.ctx, moves, isActive, isConnected: true, error: '', playerID: viewingPlayer, onExitMatch };
}