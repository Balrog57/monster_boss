// SetupScreen.jsx - APK "HOW MANY PLAYERS?" (2 / 3 / 4) then OK.
import React, { useState } from 'react';
import { playSfx, SFX } from '../audio.js';
import GameStage from '../components/game/GameStage.jsx';
import s from './SetupScreen.module.css';

export default function SetupScreen({ onStartLocal, onBack }) {
  const [n, setN] = useState(2);

  return (
    <GameStage bg="/ui/backgrounds/menu_bg.jpg">
      <div className={s.layout} id="main-content">
        <img src="/ui/logos/bm_logo.png" alt="" className={s.logo} />
        <button className={s.back} onClick={() => { playSfx(SFX.BUTTON); onBack(); }} type="button" aria-label="Retour" />

        <div className={s.prompt}>HOW MANY PLAYERS?</div>
        <div className={s.nums} role="radiogroup" aria-label="Nombre de joueurs">
          {[2, 3, 4].map((v) => (
            <button
              key={v}
              className={`${s.num} ${n === v ? s.numOn : ''}`}
              onClick={() => { playSfx(SFX.BUTTON); setN(v); }}
              type="button"
              role="radio"
              aria-checked={n === v}
            >
              {v}
            </button>
          ))}
        </div>
        <div className={s.hint}>{n === 2 ? 'You vs 1 AI' : n === 3 ? 'You vs 2 AI' : 'You vs 3 AI'}</div>

        <button
          className={s.ok}
          onClick={() => { playSfx(SFX.BUTTON); onStartLocal(n); }}
          type="button"
          aria-label="OK"
        />
      </div>
    </GameStage>
  );
}
