// MainMenu.jsx - Welcome screen with logo, background, and Start button.
import React, { useEffect } from 'react';
import { playMusic, playSfx, SFX } from '../audio.js';

export default function MainMenu({ onStart }) {
  useEffect(() => {
    playMusic('music_main', 0.35);
  }, []);

  return (
    <div style={S.screen}>
      {/* Background image (APK: Common/menu_bg.png.wpk) */}
      <img
        src="/assets/ui/backgrounds/menu_bg.jpg"
        alt=""
        style={S.bg}
        onError={(e) => { e.currentTarget.style.display = 'none'; }}
      />
      <div style={S.overlay} />

      <div style={S.content}>
        {/* Boss Monster logo */}
        <img
          src="/assets/ui/logos/bm_logo.png"
          alt="Boss Monster"
          style={S.logo}
          onError={(e) => {
            e.currentTarget.style.display = 'none';
            e.currentTarget.nextSibling.style.display = 'block';
          }}
        />
        <h1 style={S.logoFallback}>BOSS MONSTER</h1>

        <p style={S.tagline}>Le jeu de construction de donjon</p>

        <button
          style={S.startBtn}
          onClick={() => { playSfx(SFX.BUTTON); onStart(); }}
          onMouseDown={(e) => { e.currentTarget.src = '/assets/ui/buttons/intro_start_btn_pressed.png'; }}
          onMouseUp={(e) => { e.currentTarget.src = '/assets/ui/buttons/intro_start_btn.png'; }}
          onMouseLeave={(e) => { e.currentTarget.src = '/assets/ui/buttons/intro_start_btn.png'; }}
        >
          <img
            src="/assets/ui/buttons/intro_start_btn.png"
            alt="Démarrer"
            style={S.btnImg}
            onError={(e) => {
              e.currentTarget.style.display = 'none';
              e.currentTarget.parentElement.classList.add('fallback');
            }}
          />
          <span style={S.btnText}>DÉMARRER</span>
        </button>
      </div>

      <div style={S.footer}>v1.0 · Fan recreation · Cartes © Brotherwise Games</div>
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
  logo: {
    width: 'min(560px, 70vw)',
    height: 'auto',
    filter: 'drop-shadow(0 4px 24px rgba(225,29,72,0.5))'
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
  startBtn: {
    background: 'none',
    border: 'none',
    padding: 0,
    cursor: 'pointer',
    position: 'relative',
    display: 'inline-flex',
    alignItems: 'center',
    justifyContent: 'center',
    marginTop: 24
  },
  btnImg: {
    width: 'min(360px, 50vw)',
    height: 'auto',
    display: 'block'
  },
  btnText: {
    position: 'absolute',
    color: '#FCD34D',
    fontWeight: 800,
    fontSize: 22,
    fontFamily: "'arcadepix', sans-serif",
    letterSpacing: 2,
    pointerEvents: 'none',
    textShadow: '0 2px 4px rgba(0,0,0,0.8)'
  },
  footer: {
    position: 'absolute',
    bottom: 16,
    color: '#6B7280',
    fontSize: 12,
    zIndex: 2
  }
};
