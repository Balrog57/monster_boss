// MainMenu.jsx - APK main menu: 2x2 SINGLE PLAYER / MULTIPLAYER / OPTIONS.
import React, { useEffect, useState } from 'react';
import { playMusic, playSfx, SFX, isMuted, setMuted } from '../audio.js';
import GameStage from '../components/game/GameStage.jsx';
import s from './MainMenu.module.css';

export default function MainMenu({ onStart, onMultiplayer }) {
  const [view, setView] = useState('root'); // root | options | settings
  const [muted, setMutedState] = useState(isMuted());

  useEffect(() => {
    if (!isMuted()) playMusic('music_main', 0.35);
  }, []);

  const click = (fn) => () => { playSfx(SFX.BUTTON); fn(); };

  const toggleMute = () => {
    const next = !muted;
    setMuted(next);
    setMutedState(next);
    if (!next) playSfx(SFX.BUTTON, 0.5);
  };

  return (
    <GameStage bg="/ui/backgrounds/menu_bg.jpg">
      <div className={s.layout} id="main-content">
        <img src="/ui/logos/bm_logo.png" alt="Boss Monster" className={s.logo} />

        {view !== 'root' && (
          <button className={s.back} onClick={click(() => setView(view === 'settings' ? 'options' : 'root'))} type="button" aria-label="Retour" />
        )}

        {view === 'root' && (
          <div className={s.grid} role="navigation">
            <button className={s.cell} type="button" onClick={click(onStart)}>
              <img src="/ui/buttons/boss_icon.png" alt="" />
              <span>SINGLE PLAYER</span>
            </button>
            <button className={s.cell} type="button" onClick={click(onMultiplayer)}>
              <img src="/ui/buttons/boss_multi_icon.png" alt="" />
              <span>MULTIPLAYER</span>
            </button>
            <button className={s.cell} type="button" onClick={click(() => setView('options'))}>
              <img src="/ui/buttons/options_icon.png" alt="" />
              <span>OPTIONS</span>
            </button>
            <div className={`${s.cell} ${s.dead}`} aria-hidden="true">
              <img src="/ui/buttons/inapp_icon.png" alt="" />
              <span>IN-APP STORE</span>
            </div>
          </div>
        )}

        {view === 'options' && (
          <div className={s.stack}>
            <button className={s.wide} type="button" onClick={click(() => setView('settings'))}>SETTINGS</button>
            <button className={s.wide} type="button" onClick={click(() => setView('root'))}>TUTORIAL</button>
            <button className={s.wide} type="button" disabled>CARD GALLERY</button>
            <button className={s.wide} type="button" disabled>CREDITS</button>
          </div>
        )}

        {view === 'settings' && (
          <div className={s.settings}>
            <div className={s.setRow}>
              <span className={s.setLabel}>MUSIC / SOUND</span>
              <button className={`${s.choice} ${!muted ? s.choiceOn : ''}`} type="button" onClick={() => { if (muted) toggleMute(); }}>ON</button>
              <button className={`${s.choice} ${muted ? s.choiceOn : ''}`} type="button" onClick={() => { if (!muted) toggleMute(); }}>OFF</button>
            </div>
          </div>
        )}
      </div>
    </GameStage>
  );
}
