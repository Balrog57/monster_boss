// src/client/socket.js - Thin Socket.IO client wrapper for online matches.
//
// Wraps socket.io-client and exposes a minimal API: connect, joinMatch,
// sendMove, subscribe to state, leaveMatch. State subscriptions receive the
// playerView-filtered G + ctx from the server.
import { io } from 'socket.io-client';
import { decodeState } from '../stateCodec.js';

const SERVER = window.location.origin;

let socket = null;
let session = null;

// The server sends G in the encoded form (arrays with attached properties,
// e.g. dungeon stacks carrying `.miniboss`, are wrapped). Restore them here so
// the UI reads plain dungeon stacks again.
function decodePayload({ G, ctx, ...rest }) {
  return { ...rest, G: G ? decodeState(G) : G, ctx };
}

export function getSocket() {
  if (!socket) {
    socket = io(SERVER, { path: '/socket.io', transports: ['websocket', 'polling'] });
    socket.on('connect', () => {
      if (session) socket.emit('match:join', session);
    });
  }
  return socket;
}

export function joinMatch(matchID, playerID, credentials) {
  return new Promise((resolve, reject) => {
    const s = getSocket();
    session = { matchID, playerID, credentials };
    const onError = ({ message, matchID: mid }) => {
      if (mid && mid !== matchID) return;
      s.off('match:state', onState);
      s.off('match:error', onError);
      reject(new Error(message));
    };
    const onState = (payload) => {
      const { G, ctx, matchID: mid, turnDeadline } = decodePayload(payload);
      if (mid === matchID) {
        s.off('match:state', onState);
        s.off('match:error', onError);
        resolve({ G, ctx, turnDeadline });
      }
    };
    s.on('match:state', onState);
    s.on('match:error', onError);
    if (s.connected) s.emit('match:join', session);
  });
}

export function sendMove(matchID, move) {
  getSocket().emit('match:move', { matchID, move });
}

export function leaveMatch(matchID) {
  if (!socket) return;
  socket.emit('match:leave', { matchID });
}

export function subscribeState(matchID, handler) {
  const s = getSocket();
  const wrapped = (payload) => {
    const { G, ctx, matchID: mid, turnDeadline } = decodePayload(payload);
    if (mid === matchID) handler({ G, ctx, turnDeadline });
  };
  s.on('match:state', wrapped);
  return () => s.off('match:state', wrapped);
}

export function subscribeNotifications(matchID, handler) {
  const s = getSocket();
  const wrapped = ({ message, matchID: mid }) => { if (mid === matchID) handler(message); };
  s.on('match:notification', wrapped);
  return () => s.off('match:notification', wrapped);
}

export function subscribeEnded(matchID, handler) {
  const s = getSocket();
  const wrapped = ({ winner, matchID: mid }) => { if (mid === matchID) handler({ winner }); };
  s.on('match:ended', wrapped);
  return () => s.off('match:ended', wrapped);
}

export function subscribeErrors(matchID, handler) {
  const s = getSocket();
  const wrapped = ({ message, matchID: mid }) => { if (mid === matchID) handler(message); };
  s.on('match:error', wrapped);
  return () => s.off('match:error', wrapped);
}

export function sendEmote(matchID, emote) {
  getSocket().emit('match:emote', { matchID, emote });
}

export function subscribeEmotes(matchID, handler) {
  const s = getSocket();
  const wrapped = ({ playerID, emote, matchID: mid, timestamp }) => {
    if (mid === matchID) handler({ playerID, emote, timestamp });
  };
  s.on('match:emote', wrapped);
  return () => s.off('match:emote', wrapped);
}

export function disconnect() {
  session = null;
  if (socket) { socket.disconnect(); socket = null; }
}
