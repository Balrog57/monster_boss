// GameStage.jsx - Fixed 1920×1080 landscape stage, scaled to the window
// (letterboxed). Matches the original Wave Engine / APK viewport.
import React, { useEffect, useState } from 'react';
import s from './GameStage.module.css';

export const STAGE_W = 1920;
export const STAGE_H = 1080;

export default function GameStage({ children, bg, className = '' }) {
  const [scale, setScale] = useState(1);

  useEffect(() => {
    const fit = () => {
      setScale(Math.min(window.innerWidth / STAGE_W, window.innerHeight / STAGE_H));
    };
    fit();
    window.addEventListener('resize', fit);
    return () => window.removeEventListener('resize', fit);
  }, []);

  return (
    <div className={s.letterbox}>
      <div
        className={`${s.stage} ${className}`}
        style={{ transform: `scale(${scale})` }}
      >
        {bg && <img src={bg} alt="" className={s.bg} draggable={false} />}
        {children}
      </div>
    </div>
  );
}
