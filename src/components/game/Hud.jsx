// Hud.jsx - Top status bar showing phase, turn, souls, wounds, boss, mute,
// turn countdown timer (server-authoritative deadline) and reconnection toasts.
import React, { useState, useEffect } from 'react';
import { PHASE } from '../../cardData.js';
import { isMuted, setMuted, playSfx, SFX } from '../../audio.js';
import s from './Hud.module.css';

const PHASE_IMAGES = {
  [PHASE.BUILD]: '/ui/ingame/build_phase.png',
  [PHASE.BAIT]: '/ui/ingame/bait_phase.png',
  [PHASE.ADVENTURE]: '/ui/ingame/adventure_phase.png',
};

// Countdown derived from the server-provided turnDeadline (epoch ms).
function useCountdown(deadline) {
  const [remaining, setRemaining] = useState(null);
  useEffect(() => {
    if (!deadline) { setRemaining(null); return; }
    const tick = () => setRemaining(Math.max(0, Math.ceil((deadline - Date.now()) / 1000)));
    tick();
    const id = setInterval(tick, 1000);
    return () => clearInterval(id);
  }, [deadline]);
  return remaining;
}

export default function Hud({ phase, turn, isMyTurn, activePid, me, dungeonCount, turnDeadline, notification, onOptions }) {
  const phaseImg = PHASE_IMAGES[phase];
  const remaining = useCountdown(turnDeadline);
  const showTimer = phase === PHASE.BUILD && remaining != null;
  const low = showTimer && remaining <= 10;
  return (
    <div className={s.hud} role="status" aria-live="polite" aria-label={`Phase ${phase}, tour ${turn}`}>
      <div className={`${s.phaseBadge} ${isMyTurn ? s.myTurn : s.theirTurn}`}>
        {phaseImg && <img src={phaseImg} alt="" className={s.phaseImg} />}
        {phase.toUpperCase()}
      </div>
      <div className={s.hudLabel}>Tour {turn}</div>
      <div className={`${s.turnIndicator} ${isMyTurn ? s.myTurnText : s.theirTurnText}`}>
        {isMyTurn ? '▶ À votre tour' : (
          <span className={s.waiting}>
            <img src="/ui/gradients/sandclock_icon.png" alt="" className={s.sandclock} />
            En attente…
          </span>
        )}
      </div>
      {showTimer && (
        <div
          className={`${s.timer} ${low ? s.timerLow : ''}`}
          style={{ backgroundImage: 'url(/ui/ingame/done_button_timer.png)' }}
          aria-label={`${remaining} secondes restantes`}
        >
          ⏳ {remaining}s
        </div>
      )}
      <div className={s.spacer} />
      <div className={s.stat} aria-label={`${me.souls.length} âmes, ${me.wounds.length} blessures`}>
        <img src="/ui/icons/soul.png" width={20} height={20} alt="" aria-hidden="true" />
        <span className={s.num}>{me.souls.length}</span>
        <span className={s.sep}>·</span>
        <img src="/ui/icons/wound.png" width={20} height={20} alt="" aria-hidden="true" />
        <span className={`${s.num} ${s.danger}`}>{me.wounds.length}</span>
      </div>
      <div className={s.stat}>{me.boss?.name} · {me.boss?.xp} XP</div>
      <div className={s.stat}>Donjon {dungeonCount}/5</div>
      <button
        className={s.muteBtn}
        onClick={() => { const m = !isMuted(); setMuted(m); if (!m) playSfx(SFX.BUTTON, 0.4); }}
        title={isMuted() ? 'Activer le son' : 'Couper le son'}
        aria-label={isMuted() ? 'Activer le son' : 'Couper le son'}
        aria-pressed={!isMuted()}
        type="button"
      >
        {isMuted() ? '🔇' : '🔊'}
      </button>
      {onOptions && (
        <button
          className={s.optionsBtn}
          onClick={onOptions}
          title="Options"
          aria-label="Ouvrir les options"
          type="button"
        >
          <img src="/ui/ingame/bt_options.png" alt="" className={s.optionsIcon} />
        </button>
      )}
      {notification && <div className={s.toast} role="alert">{notification}</div>}
    </div>
  );
}