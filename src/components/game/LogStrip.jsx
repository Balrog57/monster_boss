// LogStrip.jsx - Last few game-log lines.
import React from 'react';
import s from './LogStrip.module.css';

export default function LogStrip({ logs }) {
  return (
    <div className={s.strip} role="log" aria-live="polite" aria-label="Game log">
      {(logs || []).slice(-4).map((l, i) => (
        <div key={`${i}-${l}`} className={s.line}>{l}</div>
      ))}
    </div>
  );
}