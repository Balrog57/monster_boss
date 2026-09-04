// server/socket.js - Socket.IO transport for real-time match play.
//
// Events (client -> server):
//   match:join   { matchID, playerID, credentials }
//   match:move   { matchID, move: { type, args } }
//   match:leave  { matchID }
//
// Events (server -> client):
//   match:state   { G, ctx, matchID }      (playerView-filtered for this socket)
//   match:error   { code, message, matchID }
//   match:ended   { winner, matchID }
//   lobby:updated { matches }              (broadcast when lobby state changes)
import { Server as SocketIOServer } from 'socket.io';
import { submitMove, addSocket, removeSocket, loadMatch, broadcastState } from './matches.js';
import { listMatches, fetchMatch as fetchMatchRow } from './db.js';
import { GAME_META } from './reducer.js';

const MAX_MOVES_PER_SEC = Number(process.env.MAX_MOVES_PER_SEC || 10);

export function createSocketIO(httpServer) {
  const io = new SocketIOServer(httpServer, {
    cors: { origin: true, credentials: true },
    path: '/socket.io'
  });

  // Per-socket rate limiter for match:move events.
  const moveTimestamps = new WeakMap();
  function rateLimited(socket) {
    const now = Date.now();
    const ts = moveTimestamps.get(socket) || [];
    const recent = ts.filter(t => now - t < 1000);
    if (recent.length >= MAX_MOVES_PER_SEC) return true;
    recent.push(now);
    moveTimestamps.set(socket, recent);
    return false;
  }

  io.on('connection', (socket) => {
    let joinedMatchID = null;

    socket.on('match:join', async ({ matchID, playerID, credentials } = {}) => {
      if (!matchID || playerID == null || !credentials) {
        socket.emit('match:error', { code: 'bad_request', message: 'matchID, playerID, credentials required' });
        return;
      }
      // Load the match into memory if evicted (reconnect after process restart).
      const match = await loadMatch(matchID);
      if (!match) {
        socket.emit('match:error', { code: 'not_found', message: 'match not found', matchID });
        return;
      }
      // Verify credentials against the DB seat.
      const row = await fetchMatchRow(matchID);
      const seat = row && (row.seats || []).find(s => s.id === Number(playerID));
      if (!seat || seat.credentials !== credentials) {
        socket.emit('match:error', { code: 'forbidden', message: 'invalid credentials', matchID });
        return;
      }
      // Leave any previously joined match room.
      if (joinedMatchID && joinedMatchID !== matchID) {
        removeSocket(joinedMatchID, socket.id);
        socket.leave(`match:${joinedMatchID}`);
      }
      joinedMatchID = matchID;
      socket.join(`match:${matchID}`);
      addSocket(matchID, socket, Number(playerID));
    });

    socket.on('match:move', async ({ matchID, move } = {}) => {
      if (!matchID || !move) {
        socket.emit('match:error', { code: 'bad_request', message: 'matchID and move required' });
        return;
      }
      if (rateLimited(socket)) {
        socket.emit('match:error', { code: 'rate_limited', message: 'too many moves', matchID });
        return;
      }
      const match = await loadMatch(matchID);
      if (!match) {
        socket.emit('match:error', { code: 'not_found', message: 'match not found', matchID });
        return;
      }
      // Find the playerID for this socket within this match.
      const entry = match.sockets.get(socket.id);
      if (!entry) {
        socket.emit('match:error', { code: 'not_joined', message: 'join the match first', matchID });
        return;
      }
      const res = submitMove(matchID, entry.playerID, move);
      if (!res.ok) {
        socket.emit('match:error', { code: 'invalid_move', message: res.error, matchID });
        return;
      }
      broadcastState(matchID);
    });

    socket.on('match:leave', ({ matchID } = {}) => {
      if (!matchID) return;
      removeSocket(matchID, socket.id);
      socket.leave(`match:${matchID}`);
      if (joinedMatchID === matchID) joinedMatchID = null;
    });

    socket.on('disconnect', () => {
      if (joinedMatchID) {
        removeSocket(joinedMatchID, socket.id);
      }
    });
  });

  return io;
}

// Cache fetchMatchRow to avoid a DB round-trip on every join. The matches.js
// loadMatch already populates the registry; credentials are still authoritative
// in the DB. We import lazily to keep the module graph clean.

// Broadcast lobby updates to all clients in a 'lobby' room.
export async function broadcastLobbyUpdate(io) {
  const rows = await listMatches({ gameName: GAME_META.name });
  const payload = rows.map(r => ({
    id: r.id,
    numPlayers: r.num_players,
    status: r.status,
    seats: (r.seats || []).map(s => ({ id: s.id, name: s.name || null, isBot: !!s.is_bot }))
  }));
  io.to('lobby').emit('lobby:updated', { matches: payload });
}
