// MainMenu.jsx - APK flow: TAP TO START → 2×2 menu (no store / no IAP).
import React, { useEffect, useState } from 'react';
import {
  playMusic, playSfx, SFX, isMusicMuted, isSfxMuted, setMusicMuted, setSfxMuted,
  getGameSpeed, setGameSpeed,
} from '../audio.js';
import GameStage from '../components/game/GameStage.jsx';
import RulesOverlay from '../components/game/RulesOverlay.jsx';
import CardGallery from '../components/game/CardGallery.jsx';
import TutorialOverlay, { TUTORIAL_STORAGE_KEY } from '../components/game/TutorialOverlay.jsx';
import s from './MainMenu.module.css';

function tutorialSeen() {
  try { return localStorage.getItem(TUTORIAL_STORAGE_KEY) === '1'; } catch { return true; }
}

export default function MainMenu({ onStart, onMultiplayer }) {
  const [view, setView] = useState('intro'); // intro | root | options | settings
  const [rulesOpen, setRulesOpen] = useState(false);
  const [galleryOpen, setGalleryOpen] = useState(false);
  const [tutorialOpen, setTutorialOpen] = useState(false);
  const [musicOff, setMusicOff] = useState(isMusicMuted());
  const [sfxOff, setSfxOff] = useState(isSfxMuted());
  const [speed, setSpeed] = useState(getGameSpeed());

  useEffect(() => {
    if (!isMusicMuted()) playMusic('music_main', 0.35);
  }, []);

  const click = (fn) => () => { playSfx(SFX.BUTTON); fn(); };

  if (view === 'intro') {
    return (
      <GameStage bg="/ui/backgrounds/intro_bg.webp">
        <button
          className={s.introHit}
          type="button"
          id="main-content"
          onClick={click(() => {
            setView('root');
            if (!tutorialSeen()) setTutorialOpen(true);
          })}
          aria-label="Tap to start"
        >
          <img src="/ui/logos/bm_logo.webp" alt="Boss Monster" className={s.logo} />
          <span className={s.tap}>TAP TO START</span>
        </button>
      </GameStage>
    );
  }

  return (
    <GameStage bg="/ui/backgrounds/menu_bg.webp">
      <div className={s.layout} id="main-content">
        <img src="/ui/logos/bm_logo.webp" alt="Boss Monster" className={s.logo} />

        <button
          className={s.back}
          onClick={click(() => setView(view === 'settings' ? 'options' : view === 'options' ? 'root' : 'intro'))}
          type="button"
          aria-label="Back"
        />

        {view === 'root' && (
          <div className={s.grid} role="navigation">
            <button className={s.cell} type="button" onClick={click(onStart)}>
              <img src="/ui/buttons/boss_icon.webp" alt="" />
              <span>SINGLE PLAYER</span>
            </button>
            <button className={s.cell} type="button" onClick={click(onMultiplayer)}>
              <img src="/ui/buttons/boss_multi_icon.webp" alt="" />
              <span>MULTIPLAYER</span>
            </button>
            <button className={s.cell} type="button" onClick={click(() => setView('options'))}>
              <img src="/ui/buttons/options_icon.webp" alt="" />
              <span>OPTIONS</span>
            </button>
            <button className={s.cell} type="button" onClick={click(() => setRulesOpen(true))} aria-label="Rules">
              <img src="/ui/ingame/spells_icon.webp" alt="" />
              <span>RULES</span>
            </button>
          </div>
        )}

        {view === 'options' && (
          <div className={s.stack}>
            <button className={s.wide} type="button" onClick={click(() => setView('settings'))}>SETTINGS</button>
            <button className={s.wide} type="button" onClick={click(() => setRulesOpen(true))}>RULES</button>
            <button className={s.wide} type="button" onClick={click(() => setGalleryOpen(true))}>CARD GALLERY</button>
            <button className={s.wide} type="button" onClick={click(() => setTutorialOpen(true))}>HOW TO PLAY</button>
          </div>
        )}

        {view === 'settings' && (
          <div className={s.settings}>
            <div className={s.setRow}>
              <span className={s.setLabel}>MUSIC</span>
              <button className={`${s.choice} ${!musicOff ? s.choiceOn : ''}`} type="button" onClick={() => { setMusicMuted(false); setMusicOff(false); playSfx(SFX.BUTTON); }}>ON</button>
              <button className={`${s.choice} ${musicOff ? s.choiceOn : ''}`} type="button" onClick={() => { setMusicMuted(true); setMusicOff(true); }}>OFF</button>
            </div>
            <div className={s.setRow}>
              <span className={s.setLabel}>SOUND</span>
              <button className={`${s.choice} ${!sfxOff ? s.choiceOn : ''}`} type="button" onClick={() => { setSfxMuted(false); setSfxOff(false); playSfx(SFX.BUTTON); }}>ON</button>
              <button className={`${s.choice} ${sfxOff ? s.choiceOn : ''}`} type="button" onClick={() => { setSfxMuted(true); setSfxOff(true); }}>OFF</button>
            </div>
            <div className={s.setRow}>
              <span className={s.setLabel}>GAME SPEED</span>
              {['slow', 'normal', 'fast'].map((v) => (
                <button
                  key={v}
                  className={`${s.choice} ${speed === v ? s.choiceOn : ''}`}
                  type="button"
                  onClick={() => { setGameSpeed(v); setSpeed(v); playSfx(SFX.BUTTON); }}
                >
                  {v.toUpperCase()}
                </button>
              ))}
            </div>
          </div>
        )}
      </div>
      <RulesOverlay open={rulesOpen} onClose={() => setRulesOpen(false)} />
      <CardGallery open={galleryOpen} onClose={() => setGalleryOpen(false)} />
      <TutorialOverlay open={tutorialOpen} onClose={() => setTutorialOpen(false)} />
    </GameStage>
  );
}
