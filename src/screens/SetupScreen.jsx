// SetupScreen.jsx - APK "HOW MANY PLAYERS?"
import React, { useState } from 'react';
import { playSfx, SFX } from '../audio.js';
import { BOSSES } from '../cardData.js';
import GameStage from '../components/game/GameStage.jsx';
import Card from '../components/game/Card.jsx';
import s from './SetupScreen.module.css';

const FANS = [
  { n: 2, bossId: 'BMA006' },
  { n: 3, bossId: 'BMA005' },
  { n: 4, bossId: 'BMA001' },
  { n: 5, bossId: 'CRL001' },
  { n: 6, bossId: 'CRL001' },
];

export default function SetupScreen({ onStartLocal, onBack }) {
  const [n, setN] = useState(2);

  const onOk = () => {
    playSfx(SFX.BUTTON);
    onStartLocal(n, null, 1);
  };

  const onBackClick = () => {
    playSfx(SFX.BUTTON);
    onBack();
  };

  return (
    <GameStage bg="/ui/backgrounds/menu_bg.webp">
      <div className={s.layout} id="main-content">
        <img src="/ui/logos/bm_logo.webp" alt="" className={s.logo} />
        <button className={s.back} onClick={onBackClick} type="button" aria-label="Back" />

        <div className={s.prompt}>HOW MANY PLAYERS?</div>
        <div className={s.fans} role="radiogroup" aria-label="How many players">
          {FANS.map(({ n: v, bossId }) => {
            const boss = BOSSES.find((b) => b.id === bossId) || BOSSES[0];
            const on = n === v;
            return (
              <button
                key={v}
                className={`${s.fan} ${on ? s.fanOn : s.fanOff}`}
                onClick={() => { playSfx(SFX.BUTTON); setN(v); }}
                type="button"
                role="radio"
                aria-checked={on}
              >
                <span className={`${s.num} ${on ? s.numOn : ''}`}>{v}</span>
                <Card card={boss} kind="boss" size="lg" />
              </button>
            );
          })}
        </div>
        <div className={s.hint}>
          {n === 2 ? 'YOU VS 1 AI' : `YOU VS ${n - 1} AI`}
        </div>
        <button className={s.ok} onClick={onOk} type="button" aria-label="OK" />
      </div>
    </GameStage>
  );
}
