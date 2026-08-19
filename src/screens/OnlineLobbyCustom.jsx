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
  const [error, setError] = useState('');
  const [busy, setBusy] = useState(false);
  const [waiting, setWaiting] = useState(null); // { matchID, playerID, credentials }

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
        const filled = (row.seats || []).filter((seat) => seat.name).length;
        if (!cancelled && filled >= 2) {
          playSfx(SFX.BUTTON);
          onJoined({ matchID: waiting.matchID, playerID: waiting.playerID, credentials: waiting.credentials, numPlayers: 2 });
        }
      } catch {
        /* keep polling */
      }
    };
    tick();
    const id = setInterval(tick, 1500);
    return () => { cancelled = true; clearInterval(id); };
  }, [waiting, onJoined]);

  const create = async () => {
    if (!name.trim() || busy) return;
    setBusy(true); setError('');
    try {
      const { matchID } = await api('/matches', {
        method: 'POST',
        body: { numPlayers: 2, setupData: { online: true } },
      });
      const { playerID, credentials } = await api(`/matches/${matchID}/join`, {
        method: 'POST', body: { playerName: name.trim() },
      });
      playSfx(SFX.BUTTON);
      setWaiting({ matchID, playerID, credentials });
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
      onJoined({ matchID: salon, playerID, credentials, numPlayers: 2 });
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
            <div className={s.kicker}>SEARCHING</div>
            <div className={s.codeBox}>{waiting.matchID}</div>
            <p className={s.hint}>Give this code to your opponent. The game starts when they join.</p>
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
