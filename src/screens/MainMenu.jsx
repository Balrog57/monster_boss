// MainMenu.jsx - Welcome screen with logo, background, and Start button.
import React, { useEffect, useState } from 'react';
import { playMusic, playSfx, SFX, isMuted } from '../audio.js';
import OptionsOverlay from './OptionsOverlay.jsx';

export default function MainMenu({ onStart }) {
  const [showOptions, setShowOptions] = useState(false);

  useEffect(() => {
    if (!isMuted()) playMusic('music_main', 0.35);
  }, []);

  return (
    <div style={S.screen}>
      {/* Background image (APK: Common/menu_bg.png.wpk) */}
      <img
        src="/ui/backgrounds/menu_bg.jpg"
        alt=""
        style={S.bg}
        onError={(e) => { e.currentTarget.style.display = 'none'; }}
      />
      <div style={S.overlay} />

      <div style={S.content}>
        {/* Boss Monster logo = START button (one clickable element) */}
        <button
          style={S.logoBtn}
          onClick={() => { playSfx(SFX.BUTTON); onStart(); }}
          onMouseEnter={(e) => { e.currentTarget.firstChild.style.transform = 'scale(1.04)'; e.currentTarget.firstChild.style.filter = 'drop-shadow(0 4px 28px rgba(225,29,72,0.8))'; }}
          onMouseLeave={(e) => { e.currentTarget.firstChild.style.transform = 'scale(1)'; e.currentTarget.firstChild.style.filter = S.logo.filter; }}
          onMouseDown={(e) => { e.currentTarget.firstChild.style.transform = 'scale(0.98)'; }}
          onMouseUp={(e) => { e.currentTarget.firstChild.style.transform = 'scale(1.04)'; }}
          aria-label="Démarrer le jeu"
        >
          <img
            src="/ui/logos/bm_logo.png"
            alt="Boss Monster - Démarrer"
            style={S.logo}
            onError={(e) => {
              e.currentTarget.style.display = 'none';
              e.currentTarget.parentElement.querySelector('[data-fallback]').style.display = 'block';
            }}
          />
          <h1 style={S.logoFallback} data-fallback>BOSS MONSTER</h1>
        </button>

        <p style={S.tagline}>Le jeu de construction de donjon</p>

        <button style={S.optionsBtn} onClick={() => { playSfx(SFX.BUTTON); setShowOptions(true); }}>
          ⚙ Options
        </button>
      </div>

      <div style={S.footer}>v1.0 · Fan recreation · Cartes © Brotherwise Games</div>

      {showOptions && <OptionsOverlay onClose={() => setShowOptions(false)} />}
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
    opacity: 0.65
  },
  overlay: {
    position: 'absolute',
    inset: 0,
    background: 'linear-gradient(180deg, rgba(10,10,15,0.3) 0%, rgba(10,10,15,0.7) 100%)'
  },
  content: {
    position: 'relative',
    zIndex: 2,
    display: 'flex',
    flexDirection: 'column',
    alignItems: 'center',
    gap: 24
  },
  logoBtn: {
    background: 'none',
    border: 'none',
    padding: 0,
    cursor: 'pointer',
    transition: 'transform 0.15s, filter 0.15s',
    lineHeight: 0
  },
  logo: {
    width: 'min(560px, 70vw)',
    height: 'auto',
    display: 'block',
    filter: 'drop-shadow(0 4px 24px rgba(225,29,72,0.55))',
    transition: 'transform 0.15s, filter 0.15s'
  },
  logoFallback: {
    display: 'none',
    fontSize: 'clamp(40px, 8vw, 80px)',
    fontWeight: 900,
    color: '#E11D48',
    margin: 0,
    textShadow: '0 4px 20px rgba(225,29,72,0.6)',
    fontFamily: "'arcadepix', sans-serif"
  },
  tagline: {
    color: '#D1D5DB',
    fontSize: 18,
    margin: 0,
    fontStyle: 'italic'
  },
  optionsBtn: {
    marginTop: 8,
    background: 'rgba(0,0,0,0.5)',
    border: '1px solid #4B5563',
    color: '#D1D5DB',
    padding: '8px 20px',
    borderRadius: 6,
    cursor: 'pointer',
    fontSize: 14,
    fontWeight: 600
  },
  footer: {
    position: 'absolute',
    bottom: 16,
    color: '#6B7280',
    fontSize: 12,
    zIndex: 2
  }
};
