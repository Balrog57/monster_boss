// OnlineLobbyCustom.jsx - Custom lobby UI for 1v1 online matches.
//
// Production states handled:
//   - Loading: initial match list fetch shows spinner
//   - Empty: no open matches shows friendly EmptyState
//   - Error: server unreachable shows error banner with retry
//   - Busy: create/join buttons show loading spinner and disable
//   - Stale: refresh button + 3s polling keeps the list fresh
import React, { useState, useEffect, useCallback, useMemo } from 'react';
import { Screen, Button, Badge, Spinner, EmptyState, ErrorBoundary } from '../components/ui';
import { playSfx, SFX } from '../audio.js';
import s from './OnlineLobbyCustom.module.css';

const SERVER = window.location.origin;

async function api(path, opts = {}) {
  const res = await fetch(SERVER + '/lobby' + path, {
    method: opts.method || 'GET',
    headers: { 'Content-Type': 'application/json' },
    body: opts.body ? JSON.stringify(opts.body) : undefined,
  });
  if (!res.ok) {
    const msg = await res.text().catch(() => res.statusText);
    throw new Error(msg);
  }
  return res.json();
}

export default function OnlineLobbyCustom({ onJoined, onBack }) {
  const [name, setName] = useState('');
  const [matches, setMatches] = useState([]);
  const [error, setError] = useState('');
  const [busy, setBusy] = useState(false);
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);

  const refresh = useCallback(async (silent = false) => {
    if (!silent) setRefreshing(true);
    try {
      const list = await api('/matches?game=boss-monster');
      setMatches(list.filter(m => m.status !== 'finished'));
      setError('');
    } catch (e) {
      setError('Serveur injoignable. Lancez le serveur puis réessayez.');
    } finally {
      setLoading(false);
      setRefreshing(false);
    }
  }, []);

  useEffect(() => {
    refresh();
    const interval = setInterval(() => refresh(true), 3000);
    return () => clearInterval(interval);
  }, [refresh]);

  const canCreate = name.trim().length > 0 && !busy;

  const create = async () => {
    if (!canCreate) return;
    setBusy(true); setError('');
    try {
      const { matchID } = await api('/matches', { method: 'POST', body: { numPlayers: 2 } });
      const { playerID, credentials } = await api(`/matches/${matchID}/join`, {
        method: 'POST', body: { playerName: name.trim() }
      });
      playSfx(SFX.BUTTON);
      onJoined({ matchID, playerID, credentials, numPlayers: 2 });
    } catch (e) {
      setError('Création échouée: ' + (e.message || e));
    } finally { setBusy(false); }
  };

  const join = async (matchID) => {
    if (!name.trim()) { setError('Entrez votre nom'); return; }
    setBusy(true); setError('');
    try {
      const { playerID, credentials } = await api(`/matches/${matchID}/join`, {
        method: 'POST', body: { playerName: name.trim() }
      });
      playSfx(SFX.BUTTON);
      onJoined({ matchID, playerID, credentials, numPlayers: 2 });
    } catch (e) {
      setError('Rejoindre échoué: ' + (e.message || e));
    } finally { setBusy(false); }
  };

  const openMatches = useMemo(() => matches, [matches]);

  return (
    <ErrorBoundary>
      <Screen id="main-content" bg="/ui/backgrounds/multiplayer_bg.jpg" bgOpacity={0.4}>
        <h1 className={s.title}>Partie en ligne 1v1</h1>
        <p className={s.subtitle}>Créez un lobby et attendez qu'un adversaire vous rejoigne</p>

        {error && (
          <div role="alert" style={{
            color: 'var(--bm-danger)', fontSize: 'var(--bm-text-base)',
            background: 'rgba(127,29,29,0.4)', padding: 'var(--bm-space-3) var(--bm-space-6)',
            borderRadius: 'var(--bm-radius-md)', width: '100%', textAlign: 'center'
          }}>
            {error}
          </div>
        )}

        <label className="visually-hidden" htmlFor="lobby-name">Votre nom</label>
        <input
          id="lobby-name"
          className={s.input}
          placeholder="Votre nom"
          value={name}
          onChange={(e) => setName(e.target.value)}
          maxLength={16}
          onKeyDown={(e) => { if (e.key === 'Enter') create(); }}
          disabled={busy}
        />

        <div className={s.section}>
          <div className={s.sectionTitle}>Créer un lobby 1v1</div>
          <Button variant="success" block size="lg" loading={busy} disabled={!canCreate} onClick={create}>
            + Créer la partie
          </Button>
        </div>

        <div className={s.divider}>
          <span className={s.dividerLine} />
          <span className={s.dividerText}>ou</span>
          <span className={s.dividerLine} />
        </div>

        <div className={s.section}>
          <div className={s.sectionTitle}>
            Lobbies ouverts ({openMatches.length})
            <button className={s.refreshBtn} onClick={() => refresh()} aria-label="Rafraîchir la liste" type="button">
              ↻{refreshing ? '…' : ''}
            </button>
          </div>

          {loading ? (
            <Spinner label="Chargement des parties…" />
          ) : openMatches.length === 0 ? (
            <EmptyState
              icon="🏰"
              title="Aucun lobby ouvert"
              hint="Créez-en un et partagez le code à votre adversaire."
            />
          ) : (
            openMatches.map((m) => {
              const seats = m.seats || [];
              const open = seats.filter(seat => !seat.name);
              const full = open.length === 0;
              return (
                <div key={m.id} className={s.matchRow}>
                  <div className={s.matchInfo}>
                    <div className={s.matchCode}>Code: {m.id.slice(0, 6).toUpperCase()}</div>
                    <div className={s.matchSeats}>
                      {seats.filter(seat => seat.name).length}/{seats.length} joueurs
                      {full ? ' · complet' : ''}
                    </div>
                  </div>
                  {full ? (
                    <Badge variant="outline">complet</Badge>
                  ) : (
                    <button className={s.joinBtn} disabled={busy} onClick={() => join(m.id)} type="button">
                      Rejoindre
                    </button>
                  )}
                </div>
              );
            })
          )}
        </div>

        <Button variant="ghost" onClick={() => { playSfx(SFX.BUTTON); onBack(); }}>
          ← Retour
        </Button>
      </Screen>
    </ErrorBoundary>
  );
}