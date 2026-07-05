// SetupScreen.jsx - Choose number of players (2/3/4 = vs 1/2/3 AI).
import React from 'react';
import { playSfx, SFX } from '../audio.js';

export default function SetupScreen({ onStart, onBack }) {
  const options = [
    { total: 2, ai: 1, label: '2 Joueurs', sub: 'Vous vs 1 IA' },
    { total: 3, ai: 2, label: '3 Joueurs', sub: 'Vous vs 2 IA' },
    { total: 4, ai: 3, label: '4 Joueurs', sub: 'Vous vs 3 IA' },
  ];

  return (
    <div style={S.screen}>
      <img
        src="/assets/ui/backgrounds/intro_bg.jpg"
        alt=""
        style={S.bg}
        onError={(e) => { e.currentTarget.style.display = 'none'; }}
      />
      <div style={S.overlay} />

      <div style={S.content}>
        <h1 style={S.title}>Nouvelle Partie</h1>
        <p style={S.subtitle}>Choisissez le nombre de joueurs</p>

        <div style={S.options}>
          {options.map((opt) => (
            <button
              key={opt.total}
              style={S.optionBtn}
              onClick={() => { playSfx(SFX.BUTTON); onStart(opt.total); }}
            >
              <div style={S.optionLabel}>{opt.label}</div>
              <div style={S.optionSub}>{opt.sub}</div>
            </button>
          ))}
        </div>

        <button style={S.backBtn} onClick={() => { playSfx(SFX.BUTTON); onBack(); }}>
          ← Retour
        </button>
      </div>
    </div>
  );
}

const S = {
  screen: {
    position: 'fixed',
    inset: 0,
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    background: '#0a0a0f',
    overflow: 'hidden'
  },
  bg: {
    position: 'absolute',
    inset: 0,
    width: '100%',
    height: '100%',
    objectFit: 'cover',
    opacity: 0.5
  },
  overlay: {
    position: 'absolute',
    inset: 0,
    background: 'rgba(10,10,15,0.6)'
  },
  content: {
    position: 'relative',
    zIndex: 2,
    display: 'flex',
    flexDirection: 'column',
    alignItems: 'center',
    gap: 20
  },
  title: {
    fontSize: 44,
    fontWeight: 900,
    color: '#FCD34D',
    margin: 0,
    fontFamily: "'arcadepix', sans-serif",
    textShadow: '0 3px 12px rgba(252,211,77,0.4)'
  },
  subtitle: {
    color: '#9CA3AF',
    fontSize: 16,
    margin: 0
  },
  options: {
    display: 'flex',
    gap: 24,
    marginTop: 16,
    flexWrap: 'wrap',
    justifyContent: 'center'
  },
  optionBtn: {
    width: 220,
    padding: '28px 24px',
    background: 'linear-gradient(135deg, #1f1a2e 0%, #2d2540 100%)',
    border: '2px solid #4C1D95',
    borderRadius: 12,
    cursor: 'pointer',
    display: 'flex',
    flexDirection: 'column',
    alignItems: 'center',
    gap: 8,
    transition: 'transform 0.15s, border-color 0.15s, box-shadow 0.15s',
    color: '#F3F4F6',
    fontFamily: "'Segoe UI', sans-serif"
  },
  optionLabel: {
    fontSize: 24,
    fontWeight: 800,
    color: '#FCD34D'
  },
  optionSub: {
    fontSize: 13,
    color: '#A1A1AA'
  },
  backBtn: {
    marginTop: 20,
    background: 'none',
    border: '1px solid #4B5563',
    color: '#9CA3AF',
    padding: '8px 20px',
    borderRadius: 6,
    cursor: 'pointer',
    fontSize: 14
  }
};
