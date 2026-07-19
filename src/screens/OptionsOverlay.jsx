// OptionsOverlay.jsx - Sound toggle (music + SFX) shown from the main menu.
import React, { useState } from 'react';
import { Modal, Button } from '../components/ui';
import { isMuted, setMuted, playSfx, SFX } from '../audio.js';
import s from './OptionsOverlay.module.css';

export default function OptionsOverlay({ onClose }) {
  const [muted, setMutedState] = useState(isMuted());

  const toggle = () => {
    const next = !muted;
    setMuted(next);
    setMutedState(next);
    if (!next) playSfx(SFX.BUTTON, 0.5);
  };

  return (
    <Modal open onClose={onClose} title="Options" width="narrow">
      <div className={s.row}>
        <div className={s.rowLabel}>
          <span className={s.icon} aria-hidden="true">{muted ? '🔇' : '🔊'}</span>
          <span>Son {muted ? '(coupé)' : '(activé)'}</span>
        </div>
        <button
          className={`${s.toggle} ${muted ? s.off : s.on}`}
          onClick={toggle}
          role="switch"
          aria-checked={!muted}
          aria-label="Activer le son"
          type="button"
        >
          <span className={`${s.knob} ${muted ? s.off : s.on}`} aria-hidden="true" />
        </button>
      </div>

      <p className={s.hint}>Coupe la musique et les effets sonores.</p>

      <Button variant="primary" block onClick={onClose}>Terminé</Button>
    </Modal>
  );
}