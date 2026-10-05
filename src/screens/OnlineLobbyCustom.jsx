// OnlineLobbyCustom.jsx - Private 1v1 salon: create or join by 6-character code.
import React, { useState, useEffect } from 'react';
import GameStage from '../components/game/GameStage.jsx';
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
  const [name, setName] = useState(() => localStorage.getItem('bm_player_name') || '');
  const [code, setCode] = useState('');
  const [numPlayers, setNumPlayers] = useState(2);
  const [error, setError] = useState('');
  const [busy, setBusy] = useState(false);
  const [waiting, setWaiting] = useState(null); // { matchID, playerID, credentials, numPlayers }
  const [seats, setSeats] = useState([]);

  const updateName = (val) => {
    setName(val);
    localStorage.setItem('bm_player_name', val);
  };

  useEffect(() => {
    if (!waiting) return undefined;
    let cancelled = false;
    const tick = async () => {
      try {
        const row = await api(`/matches/${waiting.matchID}`);
        if (cancelled) return;
        setSeats(row.seats || []);
        const filled = (row.seats || []).filter((seat) => seat.name).length;
        const needed = waiting.numPlayers || 2;
        if (filled >= needed) {
          playSfx(SFX.BUTTON);
          const session = { matchID: waiting.matchID, playerID: waiting.playerID, credentials: waiting.credentials, numPlayers: needed };
          localStorage.setItem('bm_online_session', JSON.stringify(session));
          onJoined(session);
        }
      } catch {
        /* keep polling */
      }
    };
    tick();
    const id = setInterval(tick, 1200);
    return () => { cancelled = true; clearInterval(id); };
  }, [waiting, onJoined]);

  const addBot = async () => {
    if (!waiting) return;
    try {
      await api(`/matches/${waiting.matchID}/bot`, { method: 'POST' });
      playSfx(SFX.BUTTON);
      const row = await api(`/matches/${waiting.matchID}`);
      setSeats(row.seats || []);
    } catch (e) {
      setError('Impossible d\'ajouter un Bot: ' + (e.message || e));
    }
  };

  const removeBot = async (seatId) => {
    if (!waiting) return;
    try {
      await api(`/matches/${waiting.matchID}/bot/${seatId}`, { method: 'DELETE' });
      playSfx(SFX.BUTTON);
      const row = await api(`/matches/${waiting.matchID}`);
      setSeats(row.seats || []);
    } catch (e) {
      setError('Impossible de retirer le Bot: ' + (e.message || e));
    }
  };

  const create = async () => {
    if (!name.trim() || busy) return;
    setBusy(true); setError('');
    try {
      const { matchID } = await api('/matches', {
        method: 'POST',
        body: { numPlayers, setupData: { online: true, expansions: ['hidden-heroes', 'tools', 'players-choice'] } },
      });
      const { playerID, credentials } = await api(`/matches/${matchID}/join`, {
        method: 'POST', body: { playerName: name.trim() },
      });
      playSfx(SFX.BUTTON);
      const session = { matchID, playerID, credentials, numPlayers };
      localStorage.setItem('bm_online_session', JSON.stringify(session));
      setWaiting(session);
    } catch (e) {
      setError('Create failed: ' + (e.message || e));
    } finally { setBusy(false); }
  };

  const join = async () => {
    const salon = code.trim().toUpperCase();
    if (!name.trim()) { setError('Enter your name'); return; }
    if (salon.length < 4) { setError('Enter the room code'); return; }
    setBusy(true); setError('');
    try {
      const { playerID, credentials } = await api(`/matches/${salon}/join`, {
        method: 'POST', body: { playerName: name.trim() },
      });
      playSfx(SFX.BUTTON);
      const row = await api(`/matches/${salon}`);
      const session = { matchID: salon, playerID, credentials, numPlayers: row.numPlayers || 2 };
      localStorage.setItem('bm_online_session', JSON.stringify(session));
      onJoined(session);
    } catch (e) {
      setError('Join failed: ' + (e.message || e));
    } finally { setBusy(false); }
  };

  return (
    <GameStage bg="/ui/backgrounds/multiplayer_bg.webp">
      <div className={s.stage} id="main-content">
        <button className={s.back} type="button" aria-label="Back" onClick={() => { playSfx(SFX.BUTTON); onBack(); }} />
        <img src="/ui/logos/bm_logo.webp" alt="" className={s.logo} />

        {error && <div className={s.error} role="alert">{error}</div>}

        {waiting ? (
          <div className={s.waiting}>
            <div className={s.kicker}>SEARCHING / EN ATTENTE</div>
            <div className={s.codeBox}>{waiting.matchID}</div>
            <p className={s.hint}>Partagez ce code ou ajoutez un Bot IA pour lancer la partie immédiatement.</p>

            <div className={s.seatsList}>
              {seats.map((seat, idx) => (
                <div key={seat.id} className={s.seatRow}>
                  <span className={s.seatNum}>Siège {idx + 1}</span>
                  <span className={s.seatName}>
                    {seat.name ? (seat.isBot ? `🤖 ${seat.name}` : `👤 ${seat.name}`) : '⏳ En attente...'}
                  </span>
                  {seat.isBot && (
                    <button
                      type="button"
                      className={s.removeBotBtn}
                      onClick={() => removeBot(seat.id)}
                      title="Retirer ce Bot"
                      aria-label={`Retirer le bot du siège ${idx + 1}`}
                    >
                      ✕
                    </button>
                  )}
                </div>
              ))}
            </div>

            {seats.some((seat) => !seat.name && !seat.isBot) && (
              <button
                type="button"
                className={s.addBotBtn}
                onClick={addBot}
                aria-label="Ajouter un Bot IA"
              >
                + AJOUTER UN BOT IA
              </button>
            )}
          </div>
        ) : (
          <div className={s.panel}>
            <label className={s.label} htmlFor="lobby-name">YOUR NAME</label>
            <input
              id="lobby-name"
              className={s.input}
              placeholder="NAME"
              value={name}
              onChange={(e) => updateName(e.target.value)}
              maxLength={16}
              disabled={busy}
            />

            <label className={s.label} htmlFor="lobby-players">PLAYERS</label>
            <select
              id="lobby-players"
              className={s.input}
              value={numPlayers}
              onChange={(e) => setNumPlayers(Number(e.target.value))}
              disabled={busy}
            >
              {[2, 3, 4, 5, 6].map((n) => (
                <option key={n} value={n}>{n} players</option>
              ))}
            </select>

            <button className={s.wide} type="button" disabled={!name.trim() || busy} onClick={create}>
              CREATE ROOM
            </button>

            <div className={s.or}>OR</div>

            <label className={s.label} htmlFor="lobby-code">JOIN BY CODE</label>
            <input
              id="lobby-code"
              className={`${s.input} ${s.codeInput}`}
              placeholder="ABC123"
              value={code}
              onChange={(e) => setCode(e.target.value.toUpperCase())}
              maxLength={6}
              disabled={busy}
              onKeyDown={(e) => { if (e.key === 'Enter') join(); }}
            />
            <button className={s.wide} type="button" disabled={!name.trim() || busy} onClick={join}>
              JOIN
            </button>
          </div>
        )}
      </div>
    </GameStage>
  );
}
