// OptionsOverlay.jsx - In-game options panel (volume + mute), styled with the
// APK settings slider assets. Toggled from the HUD options button.
import React, { useState } from 'react';
import { getVolume, setVolume, isMuted, setMuted, playSfx, SFX } from '../../audio.js';
import s from './OptionsOverlay.module.css';

export default function OptionsOverlay({ open, onClose }) {
  const [vol, setVol] = useState(() => Math.round(getVolume() * 100));
  const [mute, setMute] = useState(() => isMuted());
  if (!open) return null;

  const handleVol = (e) => {
    const v = Number(e.target.value);
    setVol(v);
    setVolume(v / 100);
  };
  const handleMute = () => {
    const m = !mute;
    setMute(m);
    setMuted(m);
    if (!m) playSfx(SFX.BUTTON, 0.4);
  };

  return (
    <div className={s.backdrop} onClick={onClose} role="presentation">
      <div className={s.panel} onClick={(e) => e.stopPropagation()} role="dialog" aria-label="Options">
        <div className={s.header}>
          <img src="/ui/buttons/options_icon.png" alt="" className={s.headerIcon} />
          <span className={s.title}>OPTIONS</span>
          <button className={s.close} onClick={onClose} aria-label="Fermer" type="button">✕</button>
        </div>

        <div className={s.row}>
          <span className={s.label}>🔊 Volume principal</span>
          <div className={s.sliderWrap}>
            <input
              type="range"
              min="0"
              max="100"
              value={vol}
              onChange={handleVol}
              className={s.slider}
              aria-label="Volume principal"
            />
            <span className={s.volVal}>{vol}%</span>
          </div>
        </div>

        <div className={s.row}>
          <span className={s.label}>🔇 Couper le son</span>
          <button
            className={`${s.toggle} ${mute ? s.toggleOn : ''}`}
            onClick={handleMute}
            aria-pressed={mute}
            type="button"
          >
            {mute ? 'OUI' : 'NON'}
          </button>
        </div>

        <button className={s.ok} onClick={onClose} type="button">OK</button>
      </div>
    </div>
  );
}
