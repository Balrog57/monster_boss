// src/client/socket.js - Thin Socket.IO client wrapper for online matches.
//
// Wraps socket.io-client and exposes a minimal API: connect, joinMatch,
// sendMove, subscribe to state, leaveMatch. State subscriptions receive the
// playerView-filtered G + ctx from the server.
import { io } from 'socket.io-client';

const SERVER = window.location.origin;

let socket = null;

export function getSocket() {
  if (!socket) {
    socket = io(SERVER, { path: '/socket.io', transports: ['websocket', 'polling'] });
  }
  return socket;
}

export function joinMatch(matchID, playerID, credentials) {
  return new Promise((resolve, reject) => {
    const s = getSocket();
    const onState = ({ G, ctx, matchID: mid, turnDeadline }) => {
      if (mid === matchID) {
        s.off('match:state', onState);
        resolve({ G, ctx, turnDeadline });
      }
    };
    s.on('match:state', onState);
    s.on('match:error', ({ message }) => reject(new Error(message)));
    s.emit('match:join', { matchID, playerID, credentials });
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
  const wrapped = ({ G, ctx, matchID: mid, turnDeadline }) => { if (mid === matchID) handler({ G, ctx, turnDeadline }); };
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

export function disconnect() {
  if (socket) { socket.disconnect(); socket = null; }
}