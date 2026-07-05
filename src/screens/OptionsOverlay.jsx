// OptionsOverlay.jsx - Sound toggle (music + SFX) shown from the main menu.
import React, { useState, useEffect } from 'react';
import { isMuted, setMuted, playSfx, SFX } from '../audio.js';

export default function OptionsOverlay({ onClose }) {
  const [muted, setMutedState] = useState(isMuted());

  const toggle = () => {
    const next = !muted;
    setMuted(next);
    setMutedState(next);
    if (!next) playSfx(SFX.BUTTON, 0.5); // confirm sound re-enabled
  };

  return (
    <div style={S.overlay} onClick={onClose}>
      <div style={S.box} onClick={(e) => e.stopPropagation()}>
        <div style={S.header}>
          <h2 style={S.title}>Options</h2>
          <button style={S.closeBtn} onClick={onClose}>×</button>
        </div>

        <div style={S.row}>
          <div style={S.rowLabel}>
            <span style={S.icon}>{muted ? '🔇' : '🔊'}</span>
            <span>Son {muted ? '(coupé)' : '(activé)'}</span>
          </div>
          <button
            style={{ ...S.toggleBtn, background: muted ? '#3a1f1f' : '#1f3a1f', borderColor: muted ? '#F87171' : '#10B981' }}
            onClick={toggle}
          >
            <span style={{ ...S.toggleKnob, transform: muted ? 'translateX(0)' : 'translateX(28px)' }} />
          </button>
        </div>

        <p style={S.hint}>
          Coupe la musique et les effets sonores.
        </p>

        <button style={S.doneBtn} onClick={onClose}>Terminé</button>
      </div>
    </div>
  );
}

const S = {
  overlay: {
    position: 'fixed',
    inset: 0,
    background: 'rgba(0,0,0,0.7)',
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    zIndex: 50
  },
  box: {
    background: '#1a1525',
    border: '1px solid #4C1D95',
    borderRadius: 12,
    padding: 24,
    minWidth: 360,
    maxWidth: '90vw',
    boxShadow: '0 8px 40px rgba(124,58,237,0.4)'
  },
  header: {
    display: 'flex',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 20
  },
  title: {
    margin: 0,
    color: '#FCD34D',
    fontSize: 26,
    fontFamily: "'arcadepix', sans-serif"
  },
  closeBtn: {
    background: 'none',
    border: 'none',
    color: '#9CA3AF',
    fontSize: 28,
    cursor: 'pointer',
    lineHeight: 1,
    padding: '0 4px'
  },
  row: {
    display: 'flex',
    justifyContent: 'space-between',
    alignItems: 'center',
    padding: '12px 0',
    borderTop: '1px solid #2d2540'
  },
  rowLabel: {
    display: 'flex',
    alignItems: 'center',
    gap: 12,
    color: '#E4E4E7',
    fontSize: 16
  },
  icon: { fontSize: 22 },
  toggleBtn: {
    width: 60,
    height: 30,
    borderRadius: 999,
    border: '2px solid',
    cursor: 'pointer',
    padding: 2,
    position: 'relative',
    transition: 'background 0.2s, border-color 0.2s'
  },
  toggleKnob: {
    display: 'block',
    width: 22,
    height: 22,
    borderRadius: '50%',
    background: '#F3F4F6',
    transition: 'transform 0.2s',
    boxShadow: '0 1px 3px rgba(0,0,0,0.4)'
  },
  hint: {
    color: '#6B7280',
    fontSize: 12,
    margin: '12px 0 20px'
  },
  doneBtn: {
    width: '100%',
    background: 'linear-gradient(135deg, #7C3AED, #5B21B6)',
    color: '#fff',
    border: 'none',
    borderRadius: 8,
    padding: '10px',
    fontWeight: 800,
    fontSize: 14,
    cursor: 'pointer'
  }
};
