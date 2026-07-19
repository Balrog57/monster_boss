// MainMenu.jsx - Welcome screen with logo, background, and Start button.
import React, { useEffect, useState } from 'react';
import { Screen, Button } from '../components/ui';
import { playMusic, playSfx, SFX, isMuted } from '../audio.js';
import OptionsOverlay from './OptionsOverlay.jsx';
import s from './MainMenu.module.css';

export default function MainMenu({ onStart }) {
  const [showOptions, setShowOptions] = useState(false);

  useEffect(() => {
    if (!isMuted()) playMusic('music_main', 0.35);
  }, []);

  return (
    <>
      <Screen
        id="main-content"
        bg="/ui/backgrounds/menu_bg.jpg"
        bgOpacity={0.65}
      >
        {/* Boss Monster logo = START button (one clickable element) */}
        <button
          className={s.logoBtn}
          onClick={() => { playSfx(SFX.BUTTON); onStart(); }}
          aria-label="Démarrer le jeu"
          type="button"
        >
          <img
            src="/ui/logos/bm_logo.png"
            alt="Boss Monster - Démarrer"
            className={s.logo}
            onError={(e) => {
              e.currentTarget.style.display = 'none';
              const fb = e.currentTarget.parentElement.querySelector('[data-fallback]');
              if (fb) fb.style.display = 'block';
            }}
          />
          <h1 className={s.logoFallback} data-fallback>BOSS MONSTER</h1>
        </button>

        <p className={s.tagline}>Le jeu de construction de donjon</p>

        <Button variant="ghost" onClick={() => { playSfx(SFX.BUTTON); setShowOptions(true); }}>
          ⚙ Options
        </Button>

        <div className={s.footer}>v1.0 · Fan recreation · Cartes © Brotherwise Games</div>
      </Screen>

      {showOptions && <OptionsOverlay onClose={() => setShowOptions(false)} />}
    </>
  );
}