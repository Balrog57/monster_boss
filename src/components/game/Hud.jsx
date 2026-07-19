// Hud.jsx - Top status bar showing phase, turn, souls, wounds, boss, mute.
import React from 'react';
import { isMuted, setMuted, playSfx, SFX } from '../../audio.js';
import s from './Hud.module.css';

export default function Hud({ phase, turn, isMyTurn, activePid, me, dungeonCount }) {
  return (
    <div className={s.hud} role="status" aria-live="polite" aria-label={`Phase ${phase}, tour ${turn}`}>
      <div className={`${s.phaseBadge} ${isMyTurn ? s.myTurn : s.theirTurn}`}>
        {phase.toUpperCase()}
      </div>
      <div className={s.hudLabel}>Tour {turn}</div>
      <div className={`${s.turnIndicator} ${isMyTurn ? s.myTurnText : s.theirTurnText}`}>
        {isMyTurn ? '▶ À votre tour' : `Joueur ${activePid} joue`}
      </div>
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
    </div>
  );
}