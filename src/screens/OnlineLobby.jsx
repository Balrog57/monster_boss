// OnlineLobby.jsx - Create or join a 1v1 online match via the boardgame.io
// Lobby API. The original APK shipped a 1v1 game; this lobby mirrors that.
//
// Flow: enter a player name -> Create (always 2 seats for 1v1) or Join
// (picks the first open seat from any open match).
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
  const [creating, setCreating] = useState(false);
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

  const create = async () => {
    if (!name.trim()) { setError('Entrez votre nom'); return; }
    setBusy(true); setError('');
    try {
      // 1v1 = 2 seats only.
      const matchID = await lobby.createMatch('boss-monster', { numPlayers: 2 });
      const { playerCredentials, playerID } = await lobby.joinMatch(
        'boss-monster', matchID, { playerID: '0', playerName: name.trim() }
      );
      playSfx(SFX.BUTTON);
      onJoined({ matchID, playerID, credentials: playerCredentials, numPlayers: 2 });
    } catch (e) {
      setError('Création échouée: ' + (e.message || e));
    } finally {
      setBusy(false);
      setCreating(false);
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
      onJoined({ matchID, playerID: String(playerID), credentials: playerCredentials, numPlayers: 2 });
    } catch (e) {
      setError('Rejoindre échoué: ' + (e.message || e));
    } finally {
      setBusy(false);
    }
  };

  return (
    <div style={S.screen}>
      <img src="/ui/backgrounds/multiplayer_bg.jpg" alt="" style={S.bg}
        onError={(e) => { e.currentTarget.style.display = 'none'; }} />
      <div style={S.overlay} />
      <div style={S.content}>
        <h1 style={S.title}>Partie en ligne 1v1</h1>
        <p style={S.subtitle}>Créez un lobby et attendez qu'un adversaire vous rejoigne</p>
        {error && <div style={S.error}>{error}</div>}

        <input
          style={S.input}
          placeholder="Votre nom"
          value={name}
          onChange={(e) => setName(e.target.value)}
          maxLength={16}
        />

        <div style={S.section}>
          <div style={S.sectionTitle}>Créer un lobby 1v1</div>
          <button
            style={S.createBtn}
            disabled={busy}
            onClick={() => { setCreating(true); create(); }}
          >
            {creating ? 'Création…' : '+ Créer la partie'}
          </button>
        </div>

        <div style={S.divider}>
          <span style={S.dividerLine} />
          <span style={S.dividerText}>ou</span>
          <span style={S.dividerLine} />
        </div>

        <div style={S.section}>
          <div style={S.sectionTitle}>
            Lobbies ouverts ({matches.length})
            <button style={S.refreshBtn} onClick={refresh}>↻</button>
          </div>
          {matches.length === 0 && <div style={S.empty}>Aucun lobby ouvert. Créez-en un !</div>}
          {matches.map((m) => {
            const seats = Array.from({ length: m.players.length }, (_, i) => i);
            const open = seats.filter((i) => !m.players[i]?.name);
            return (
              <div key={m.matchID} style={S.matchRow}>
                <div style={S.matchInfo}>
                  <div style={S.matchCode}>Code: {m.matchID.slice(0, 6).toUpperCase()}</div>
                  <div style={S.matchSeats}>
                    {m.players.filter(p => p.name).length}/{m.players.length} joueurs
                  </div>
                </div>
                {open.length > 0 ? (
                  <button style={S.joinBtn} disabled={busy} onClick={() => join(m.matchID, open[0])}>
                    Rejoindre
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
  title: { margin: 0, color: '#FCD34D', fontFamily: "'arcadepix', sans-serif", fontSize: 32, textAlign: 'center' },
  subtitle: { color: '#9CA3AF', fontSize: 13, margin: 0, textAlign: 'center' },
  error: { color: '#F87171', fontSize: 13, background: 'rgba(127,29,29,0.4)', padding: '6px 12px', borderRadius: 6 },
  input: { width: '100%', padding: '10px 14px', borderRadius: 6, border: '1px solid #4B5563', background: '#1a1525', color: '#F3F4F6', fontSize: 15, boxSizing: 'border-box' },
  section: { width: '100%', marginTop: 8 },
  sectionTitle: { fontSize: 12, fontWeight: 700, color: '#9CA3AF', textTransform: 'uppercase', letterSpacing: 1, marginBottom: 8, display: 'flex', alignItems: 'center', gap: 8 },
  createBtn: { width: '100%', padding: '14px', background: 'linear-gradient(135deg, #10B981, #047857)', color: '#fff', border: 'none', borderRadius: 6, cursor: 'pointer', fontWeight: 700, fontSize: 15, letterSpacing: 0.5 },
  refreshBtn: { background: 'none', border: '1px solid #4B5563', color: '#9CA3AF', borderRadius: 4, cursor: 'pointer', padding: '2px 8px' },
  empty: { color: '#6B7280', fontSize: 13, fontStyle: 'italic', textAlign: 'center', padding: 16 },
  matchRow: { display: 'flex', alignItems: 'center', gap: 12, padding: '10px 12px', background: 'rgba(30,27,46,0.6)', borderRadius: 6, marginBottom: 6 },
  matchInfo: { display: 'flex', flexDirection: 'column', gap: 2, flex: 1 },
  matchCode: { color: '#FCD34D', fontWeight: 700, fontFamily: 'monospace', fontSize: 14 },
  matchSeats: { color: '#A1A1AA', fontSize: 12 },
  joinBtn: { background: '#1f3a1f', color: '#10B981', border: '1px solid #10B981', borderRadius: 4, padding: '6px 14px', cursor: 'pointer', fontSize: 13, fontWeight: 700 },
  full: { color: '#6B7280', fontSize: 12, fontStyle: 'italic' },
  divider: { display: 'flex', alignItems: 'center', gap: 10, width: '100%', margin: '4px 0' },
  dividerLine: { flex: 1, height: 1, background: '#374151' },
  dividerText: { color: '#6B7280', fontSize: 12, textTransform: 'uppercase', letterSpacing: 1 },
  backBtn: { marginTop: 8, background: 'none', border: '1px solid #4B5563', color: '#9CA3AF', padding: '8px 20px', borderRadius: 6, cursor: 'pointer', fontSize: 14 },
};
