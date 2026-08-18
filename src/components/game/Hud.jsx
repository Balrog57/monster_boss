// Hud.jsx - Top APK strip: phase banner centered, options gear right.
import React, { useState, useEffect } from 'react';
import { PHASE } from '../../cardData.js';
import s from './Hud.module.css';

const PHASE_IMAGES = {
  [PHASE.SETUP]: '/ui/ingame/build_phase.png',
  [PHASE.BUILD]: '/ui/ingame/build_phase.png',
  [PHASE.BAIT]: '/ui/ingame/bait_phase.png',
  [PHASE.ADVENTURE]: '/ui/ingame/adventure_phase.png',
};

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

export default function Hud({ phase, isMyTurn, turnDeadline, notification, onOptions }) {
  const phaseImg = PHASE_IMAGES[phase];
  const remaining = useCountdown(turnDeadline);
  const showTimer = phase === PHASE.BUILD && remaining != null;
  const low = showTimer && remaining <= 10;
  return (
    <div className={s.hud} role="status" aria-live="polite" aria-label={`Phase ${phase}`}>
      <div className={s.left}>
        {showTimer && (
          <div
            className={`${s.timer} ${low ? s.timerLow : ''}`}
            style={{ backgroundImage: 'url(/ui/ingame/done_button_timer.png)' }}
            aria-label={`${remaining} secondes restantes`}
          >
            {remaining}s
          </div>
        )}
      </div>
      <div className={`${s.phaseBadge} ${isMyTurn ? s.myTurn : s.theirTurn}`}>
        {phaseImg && <img src={phaseImg} alt={phase} className={s.phaseImg} />}
      </div>
      <div className={s.right}>
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
      </div>
      {notification && <div className={s.toast} role="alert">{notification}</div>}
    </div>
  );
}
