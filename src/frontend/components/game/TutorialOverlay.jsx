// TutorialOverlay.jsx - First-play tips matching APK in-game language.
import React, { useState } from 'react';
import s from './TutorialOverlay.module.css';

export const TUTORIAL_STORAGE_KEY = 'bm_tutorial_seen';

const STEPS = [
  {
    title: 'Build your dungeon',
    body: 'Each turn you may build one Room to the left of your Boss. Cover a Room to change its Treasure and ability.',
  },
  {
    title: 'Lure Heroes',
    body: 'Heroes in town go to the dungeon with the most matching Treasure. Ties stay in town.',
  },
  {
    title: 'Adventure',
    body: 'Heroes walk your Rooms from the entrance toward your Boss. Knock them out for Souls. Five Wounds and you are out.',
  },
  {
    title: 'Win',
    body: 'First Boss to 10 Souls wins. Play Spells on GO. Destroy Rooms to use their abilities when the card says so.',
  },
];

export default function TutorialOverlay({ open, onClose }) {
  const [step, setStep] = useState(0);
  if (!open) return null;
  const last = step >= STEPS.length - 1;
  const current = STEPS[step];

  const finish = () => {
    try { localStorage.setItem(TUTORIAL_STORAGE_KEY, '1'); } catch { /* ignore */ }
    setStep(0);
    onClose();
  };

  return (
    <div className={s.overlay} role="dialog" aria-label="How to play">
      <div className={s.panel}>
        <div className={s.kicker}>HOW TO PLAY</div>
        <div className={s.title}>{current.title}</div>
        <p className={s.body}>{current.body}</p>
        <div className={s.dots} aria-hidden="true">
          {STEPS.map((_, i) => (
            <span key={i} className={i === step ? s.dotOn : s.dot} />
          ))}
        </div>
        <div className={s.row}>
          <button className={s.ghost} type="button" onClick={finish}>SKIP</button>
          {step > 0 && (
            <button className={s.ghost} type="button" onClick={() => setStep(step - 1)}>BACK</button>
          )}
          <button className={s.primary} type="button" onClick={last ? finish : () => setStep(step + 1)}>
            {last ? 'GOT IT' : 'NEXT'}
          </button>
        </div>
      </div>
    </div>
  );
}
