// BossPortrait.jsx - The Boss card itself, shown in a dungeon.
import React from 'react';
import { getCardImage } from '../../cardData.js';
import s from './BossPortrait.module.css';

export default function BossPortrait({ boss, theme, size = 130, onInspect }) {
  if (!boss) return null;
  const src = getCardImage(boss.id, 'boss');
  return (
    <div
      className={s.portrait}
      style={{
        width: size,
        border: `3px solid ${theme.color}`,
        boxShadow: `0 0 20px ${theme.glow}, var(--bm-shadow-lg)`,
        cursor: onInspect ? 'pointer' : 'default',
      }}
      onClick={onInspect ? () => onInspect({ card: boss, kind: 'boss' }) : undefined}
      role={onInspect ? 'button' : undefined}
      tabIndex={onInspect ? 0 : undefined}
      aria-label={`Portrait du boss ${boss.name}`}
      title={boss.name}
    >
      {src && <img src={src} alt={boss.name} />}
    </div>
  );
}