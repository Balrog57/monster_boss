// OnlineLobby.jsx - Create or join an online match via the boardgame.io Lobby API.
//
// Flow: enter a player name -> Create (picks 2/3/4 seats) or Join (enter match code).
// On success, calls onJoined({ matchID, playerID, credentials, numPlayers }).
import React, { useState, useEffect } from 'react';
import { LobbyClient } from 'boardgame.io/client';
import { playSfx, SFX } from '../audio.js';

const SERVER = window.location.hostname === 'localhost'
  ? 'http://localhost:8000'
  : window.location.origin; // same-origin when served by the boardgame.io server

export default function OnlineLobby({ onJoined, onBack }) {
  const [name, setName] = useState('');
  const [matches, setMatches] = useState([]);
  const [error, setError] = useState('');
  const [busy, setBusy] = useState(false);
  const lobby = useState(() => new LobbyClient({ server: SERVER }))[0];

  const refresh = async () => {
    try {
      const { matches } = await lobby.listMatches('boss-monster');
      setMatches(matches || []);
    } catch (e) {
      setError('Serveur injoignable. Lancez "npm run serve".');
    }
  };

  useEffect(() => { refresh(); }, []);

  const create = async (numPlayers) => {
    if (!name.trim()) { setError('Entrez votre nom'); return; }
    setBusy(true); setError('');
    try {
      const matchID = await lobby.createMatch('boss-monster', { numPlayers });
      const { playerCredentials, playerID } = await lobby.joinMatch(
        'boss-monster', matchID, { playerID: '0', playerName: name.trim() }
      );
      playSfx(SFX.BUTTON);
      onJoined({ matchID, playerID, credentials: playerCredentials, numPlayers });
    } catch (e) {
      setError('Création échouée: ' + (e.message || e));
    } finally {
      setBusy(false);
    }
  };

  const join = async (matchID, playerID) => {
    if (!name.trim()) { setError('Entrez votre nom'); return; }
    setBusy(true); setError('');
    try {
      const { playerCredentials } = await lobby.joinMatch(
        'boss-monster', matchID, { playerID: String(playerID), playerName: name.trim() }
      );
      playSfx(SFX.BUTTON);
      onJoined({ matchID, playerID: String(playerID), credentials: playerCredentials, numPlayers: 0 });
    } catch (e) {
      setError('Rejoindre échoué: ' + (e.message || e));
    } finally {
      setBusy(false);
    }
  };

  return (
    <div style={S.screen}>
      <img src="/assets/ui/backgrounds/multiplayer_bg.jpg" alt="" style={S.bg}
        onError={(e) => { e.currentTarget.style.display = 'none'; }} />
      <div style={S.overlay} />
      <div style={S.content}>
        <h1 style={S.title}>Partie en ligne</h1>
        {error && <div style={S.error}>{error}</div>}

        <input
          style={S.input}
          placeholder="Votre nom"
          value={name}
          onChange={(e) => setName(e.target.value)}
          maxLength={16}
        />

        <div style={S.section}>
          <div style={S.sectionTitle}>Créer une partie</div>
          <div style={S.row}>
            {[2, 3, 4].map((n) => (
              <button key={n} style={S.createBtn} disabled={busy} onClick={() => create(n)}>
                {n} joueurs
              </button>
            ))}
          </div>
        </div>

        <div style={S.section}>
          <div style={S.sectionTitle}>
            Parties ouvertes ({matches.length})
            <button style={S.refreshBtn} onClick={refresh}>↻</button>
          </div>
          {matches.length === 0 && <div style={S.empty}>Aucune partie. Créez-en une !</div>}
          {matches.map((m) => {
            const seats = Array.from({ length: m.players.length }, (_, i) => i);
            const open = seats.filter((i) => !m.players[i]?.name);
            return (
              <div key={m.matchID} style={S.matchRow}>
                <span style={S.matchCode}>Code: {m.matchID.slice(0, 6)}</span>
                <span style={S.matchSeats}>
                  {m.players.filter(p => p.name).length}/{m.players.length} joueurs
                </span>
                {open.length > 0 ? (
                  <button style={S.joinBtn} disabled={busy} onClick={() => join(m.matchID, open[0])}>
                    Rejoindre (siège {open[0] + 1})
                  </button>
                ) : (
                  <span style={S.full}>complet</span>
                )}
              </div>
            );
          })}
        </div>

        <button style={S.backBtn} onClick={() => { playSfx(SFX.BUTTON); onBack(); }}>
          ← Retour
        </button>
      </div>
    </div>
  );
}

const S = {
  screen: { position: 'fixed', inset: 0, display: 'flex', alignItems: 'center', justifyContent: 'center', background: '#0a0a0f', overflow: 'auto' },
  bg: { position: 'absolute', inset: 0, width: '100%', height: '100%', objectFit: 'cover', opacity: 0.4 },
  overlay: { position: 'absolute', inset: 0, background: 'rgba(10,10,15,0.7)' },
  content: { position: 'relative', zIndex: 2, display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 14, maxWidth: 480, width: '90%', padding: 24 },
  title: { margin: 0, color: '#FCD34D', fontFamily: "'arcadepix', sans-serif", fontSize: 32 },
  error: { color: '#F87171', fontSize: 13, background: 'rgba(127,29,29,0.4)', padding: '6px 12px', borderRadius: 6 },
  input: { width: '100%', padding: '10px 14px', borderRadius: 6, border: '1px solid #4B5563', background: '#1a1525', color: '#F3F4F6', fontSize: 15, boxSizing: 'border-box' },
  section: { width: '100%', marginTop: 8 },
  sectionTitle: { fontSize: 12, fontWeight: 700, color: '#9CA3AF', textTransform: 'uppercase', letterSpacing: 1, marginBottom: 8, display: 'flex', alignItems: 'center', gap: 8 },
  row: { display: 'flex', gap: 10, justifyContent: 'center' },
  createBtn: { flex: 1, padding: '12px', background: 'linear-gradient(135deg, #7C3AED, #5B21B6)', color: '#fff', border: 'none', borderRadius: 6, cursor: 'pointer', fontWeight: 700, fontSize: 14 },
  refreshBtn: { background: 'none', border: '1px solid #4B5563', color: '#9CA3AF', borderRadius: 4, cursor: 'pointer', padding: '2px 8px' },
  empty: { color: '#6B7280', fontSize: 13, fontStyle: 'italic', textAlign: 'center', padding: 16 },
  matchRow: { display: 'flex', alignItems: 'center', gap: 12, padding: '8px 12px', background: 'rgba(30,27,46,0.6)', borderRadius: 6, marginBottom: 6 },
  matchCode: { color: '#FCD34D', fontWeight: 700, fontFamily: 'monospace', flex: 1 },
  matchSeats: { color: '#A1A1AA', fontSize: 13 },
  joinBtn: { background: '#1f3a1f', color: '#10B981', border: '1px solid #10B981', borderRadius: 4, padding: '4px 12px', cursor: 'pointer', fontSize: 12 },
  full: { color: '#6B7280', fontSize: 12 },
  backBtn: { marginTop: 8, background: 'none', border: '1px solid #4B5563', color: '#9CA3AF', padding: '8px 20px', borderRadius: 6, cursor: 'pointer', fontSize: 14 },
};
