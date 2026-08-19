// PhaseBanner.jsx - Full-screen phase transition banner.
// Slams in with the phase name + APK phase art whenever the active phase
// changes to a major phase, holds briefly, then fades away. Purely cosmetic.
import React, { useEffect, useRef, useState } from 'react';
import { PHASE } from '../../cardData.js';
import s from './PhaseBanner.module.css';

const PHASE_META = {
  [PHASE.BUILD]: { label: 'BUILD PHASE', img: '/ui/ingame/build_phase.webp', accent: 'var(--bm-gold-500, #f1e17c)' },
  [PHASE.BAIT]: { label: 'BAIT PHASE', img: '/ui/ingame/bait_phase.webp', accent: 'var(--bm-success, #d2eb6d)' },
  [PHASE.ADVENTURE]: { label: 'ADVENTURE PHASE', img: '/ui/ingame/adventure_phase.webp', accent: 'var(--bm-danger, #ffb3ae)' },
};

export default function PhaseBanner({ phase }) {
  const [visible, setVisible] = useState(false);
  const [shown, setShown] = useState(null);
  const prev = useRef(null);

  useEffect(() => {
    // Only banner for major, player-facing phases and only on actual change.
    if (phase && PHASE_META[phase] && phase !== prev.current) {
      setShown(phase);
      setVisible(true);
      const t = setTimeout(() => setVisible(false), 1500);
      prev.current = phase;
      return () => clearTimeout(t);
    }
    prev.current = phase;
  }, [phase]);

  if (!visible || !shown || !PHASE_META[shown]) return null;
  const meta = PHASE_META[shown];

  return (
    <div className={s.overlay} aria-hidden="true">
      <div className={s.banner} style={{ borderColor: meta.accent }}>
        <img src={meta.img} alt="" className={s.img} />
        <span className={s.label} style={{ color: meta.accent }}>{meta.label}</span>
      </div>
    </div>
  );
}
