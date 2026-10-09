// OnlineLobbyCustom.jsx - Modern multiplayer lobby: direct share links, expansion selection, and public rooms list.
import React, { useState, useEffect } from 'react';
import GameStage from '../components/game/GameStage.jsx';
import { playSfx, SFX } from '../audio.js';
import { EXPANSION_PACKS } from '../../backend/game/cardData.js';
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

export default function OnlineLobbyCustom({ onJoined, onBack, initialCode = '' }) {
  const [name, setName] = useState(() => localStorage.getItem('bm_player_name') || '');
  const [code, setCode] = useState(initialCode ? initialCode.toUpperCase() : '');
  const [numPlayers, setNumPlayers] = useState(2);
  const [selectedPacks, setSelectedPacks] = useState(['hidden-heroes', 'tools', 'players-choice']);
  const [isPublic, setIsPublic] = useState(true);
  const [publicMatches, setPublicMatches] = useState([]);
  const [copied, setCopied] = useState(false);
  const [error, setError] = useState('');
  const [busy, setBusy] = useState(false);
  const [waiting, setWaiting] = useState(null); // { matchID, playerID, credentials, numPlayers, expansions }
  const [seats, setSeats] = useState([]);

  const updateName = (val) => {
    setName(val);
    localStorage.setItem('bm_player_name', val);
  };

  const togglePack = (packId) => {
    playSfx(SFX.BUTTON);
    setSelectedPacks((prev) => {
      const next = prev.includes(packId)
        ? prev.filter((p) => p !== packId)
        : [...prev, packId];
      if (!next.includes('crash-landing') && numPlayers > 4) {
        setNumPlayers(4);
      }
      return next;
    });
  };

  // Poll waiting match status when inside a room
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
          const session = {
            matchID: waiting.matchID,
            playerID: waiting.playerID,
            credentials: waiting.credentials,
            numPlayers: needed,
            expansions: waiting.expansions,
          };
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

  // Poll open public matches when browsing the lobby
  useEffect(() => {
    if (waiting) return undefined;
    let cancelled = false;
    const fetchPublic = async () => {
      try {
        const rows = await api('/matches?status=open');
        if (cancelled) return;
        const available = (rows || []).filter(
          (r) => r.isPublic !== false && r.status === 'open' && (r.seats || []).some((s) => !s.name)
        );
        setPublicMatches(available);
      } catch {
        /* ignore */
      }
    };
    fetchPublic();
    const id = setInterval(fetchPublic, 3000);
    return () => { cancelled = true; clearInterval(id); };
  }, [waiting]);

  const copyShareLink = async () => {
    if (!waiting?.matchID) return;
    const url = `${window.location.origin}/?join=${waiting.matchID}`;
    try {
      if (navigator?.clipboard?.writeText) {
        await navigator.clipboard.writeText(url);
      } else {
        const ta = document.createElement('textarea');
        ta.value = url;
        document.body.appendChild(ta);
        ta.select();
        document.execCommand('copy');
        document.body.removeChild(ta);
      }
      playSfx(SFX.BUTTON);
      setCopied(true);
      setTimeout(() => setCopied(false), 2500);
    } catch {
      /* fallback */
    }
  };

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
        body: {
          numPlayers,
          setupData: {
            online: true,
            isPublic,
            expansions: selectedPacks,
          },
        },
      });
      const { playerID, credentials } = await api(`/matches/${matchID}/join`, {
        method: 'POST', body: { playerName: name.trim() },
      });
      playSfx(SFX.BUTTON);
      const session = { matchID, playerID, credentials, numPlayers, expansions: selectedPacks };
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
      const session = {
        matchID: salon,
        playerID,
        credentials,
        numPlayers: row.numPlayers || 2,
        expansions: row.setupData?.expansions || [],
      };
      localStorage.setItem('bm_online_session', JSON.stringify(session));
      onJoined(session);
    } catch (e) {
      setError('Join failed: ' + (e.message || e));
    } finally { setBusy(false); }
  };

  const joinPublicMatch = async (targetId) => {
    if (!name.trim()) {
      setCode(targetId);
      setError('Entrez votre nom ci-dessus puis cliquez sur JOIN.');
      const nameInput = document.getElementById('lobby-name');
      if (nameInput) nameInput.focus();
      return;
    }
    setBusy(true); setError('');
    try {
      const { playerID, credentials } = await api(`/matches/${targetId}/join`, {
        method: 'POST', body: { playerName: name.trim() },
      });
      playSfx(SFX.BUTTON);
      const row = await api(`/matches/${targetId}`);
      const session = {
        matchID: targetId,
        playerID,
        credentials,
        numPlayers: row.numPlayers || 2,
        expansions: row.setupData?.expansions || [],
      };
      localStorage.setItem('bm_online_session', JSON.stringify(session));
      onJoined(session);
    } catch (e) {
      setError('Join failed: ' + (e.message || e));
    } finally { setBusy(false); }
  };

  const maxPlayersAllowed = selectedPacks.includes('crash-landing') ? 6 : 4;
  const playerOptions = [2, 3, 4, 5, 6].filter((p) => p <= maxPlayersAllowed);

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

            <div className={s.shareRow}>
              <button
                type="button"
                className={`${s.copyBtn} ${copied ? s.copiedBtn : ''}`}
                onClick={copyShareLink}
                aria-label="Copier le lien d'invitation"
              >
                {copied ? '✓ LIEN COPIÉ !' : '🔗 COPIER LE LIEN D\'INVITATION'}
              </button>
            </div>

            <p className={s.hint}>Partagez ce code ou le lien direct pour inviter vos amis, ou ajoutez un Bot IA.</p>

            {waiting.expansions && waiting.expansions.length > 0 && (
              <div className={s.roomPacks}>
                <span className={s.roomPacksLabel}>Packs :</span>
                {waiting.expansions.map((id) => {
                  const p = EXPANSION_PACKS.find((pack) => pack.id === id);
                  return (
                    <span key={id} className={s.packBadge}>
                      {p?.label || id}
                    </span>
                  );
                })}
              </div>
            )}

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
          <div className={s.lobbyContainer}>
            {/* Left: Create or Join Panel */}
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

              <div className={s.formRow}>
                <div className={s.formCol}>
                  <label className={s.label} htmlFor="lobby-players">PLAYERS</label>
                  <select
                    id="lobby-players"
                    className={s.input}
                    value={numPlayers}
                    onChange={(e) => setNumPlayers(Number(e.target.value))}
                    disabled={busy}
                  >
                    {playerOptions.map((n) => (
                      <option key={n} value={n}>{n} players</option>
                    ))}
                  </select>
                </div>
                <div className={s.formColPublic}>
                  <label className={s.checkboxLabel}>
                    <input
                      type="checkbox"
                      checked={isPublic}
                      onChange={(e) => setIsPublic(e.target.checked)}
                      disabled={busy}
                    />
                    <span>Partie publique</span>
                  </label>
                </div>
              </div>

              {/* Expansion Selector Chips */}
              <div className={s.expansionsSection}>
                <div className={s.expansionsLabel}>EXTENSIONS / PACKS :</div>
                <div className={s.expansionsGrid}>
                  {EXPANSION_PACKS.map((pack) => {
                    const active = selectedPacks.includes(pack.id);
                    return (
                      <button
                        key={pack.id}
                        type="button"
                        className={`${s.packChip} ${active ? s.packChipActive : ''}`}
                        onClick={() => togglePack(pack.id)}
                        disabled={busy}
                        title={pack.label}
                      >
                        {pack.label}
                      </button>
                    );
                  })}
                </div>
              </div>

              <button className={s.wide} type="button" disabled={!name.trim() || busy} onClick={create}>
                CREATE ROOM
              </button>

              <div className={s.or}>OU REJOINDRE AVEC UN CODE</div>

              <div className={s.joinRow}>
                <input
                  id="lobby-code"
                  className={`${s.input} ${s.codeInput}`}
                  placeholder="CODE"
                  value={code}
                  onChange={(e) => setCode(e.target.value.toUpperCase())}
                  maxLength={6}
                  disabled={busy}
                  onKeyDown={(e) => { if (e.key === 'Enter') join(); }}
                />
                <button className={s.joinBtn} type="button" disabled={!name.trim() || busy} onClick={join}>
                  JOIN
                </button>
              </div>
            </div>

            {/* Right: Public Rooms List */}
            <div className={s.publicPanel}>
              <div className={s.publicHeader}>
                <span className={s.liveIndicator} aria-hidden="true">●</span>
                <span>SALONS PUBLICS EN ATTENTE</span>
                <span className={s.publicCount}>({publicMatches.length})</span>
              </div>

              <div className={s.publicList}>
                {publicMatches.length === 0 ? (
                  <div className={s.noPublicMatches}>
                    <p>Aucun salon public en attente pour le moment.</p>
                    <p className={s.noPublicSub}>Créez une salle pour inviter d'autres joueurs !</p>
                  </div>
                ) : (
                  publicMatches.map((m) => {
                    const hostSeat = (m.seats || []).find((st) => st.name && !st.isBot) || m.seats?.[0];
                    const filledCount = (m.seats || []).filter((st) => st.name).length;
                    const packIds = m.setupData?.expansions || [];
                    return (
                      <div key={m.id} className={s.publicItem}>
                        <div className={s.publicItemTop}>
                          <span className={s.publicItemCode}>{m.id}</span>
                          <span className={s.publicItemHost}>
                            Hôte : <strong>{hostSeat?.name || 'Inconnu'}</strong>
                          </span>
                          <span className={s.publicItemSlots}>
                            {filledCount}/{m.numPlayers} joueurs
                          </span>
                        </div>
                        <div className={s.publicItemBottom}>
                          <div className={s.publicItemPacks}>
                            {packIds.length > 0 ? (
                              packIds.map((pId) => (
                                <span key={pId} className={s.packChipSmall}>
                                  {pId.replace('-heroes', '').replace('players-', '')}
                                </span>
                              ))
                            ) : (
                              <span className={s.packChipSmall}>Base</span>
                            )}
                          </div>
                          <button
                            type="button"
                            className={s.publicJoinBtn}
                            onClick={() => joinPublicMatch(m.id)}
                            disabled={busy}
                          >
                            REJOINDRE
                          </button>
                        </div>
                      </div>
                    );
                  })
                )}
              </div>
            </div>
          </div>
        )}
      </div>
    </GameStage>
  );
}
