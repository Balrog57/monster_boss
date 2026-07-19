// OpponentRow.jsx - Compact strip showing each opponent's dungeon.
import React from 'react';
import { bossTheme } from '../../cardData.js';
import Card from './Card.jsx';
import BossPortrait from './BossPortrait.jsx';
import s from './OpponentRow.module.css';

export default function OpponentRow({ opponents, onInspect }) {
  return (
    <div className={s.row} aria-label="Donjons adverses">
      {opponents.map((p, idx) => {
        const t = bossTheme(p.boss);
        return (
          <div
            key={`opp-${idx}`}
            className={s.dungeon}
            style={{ borderTop: `3px solid ${t.color}`, background: `linear-gradient(180deg, ${t.glow} 0%, rgba(15,12,22,0.9) 100%)` }}
            aria-label={`Donjon de ${p.boss?.name || `joueur ${idx}`}`}
          >
            <div className={s.header}>
              <BossPortrait boss={p.boss} theme={t} size={50} onInspect={onInspect} />
              <div style={{ flex: 1 }}>
                <div className={s.name} style={{ color: t.color }}>{p.boss?.name}</div>
                <div className={s.meta}>
                  {p.boss?.xp} XP · {p.souls.length} âmes · {p.wounds.length} blessures
                  {p.eliminated && <span className={s.elim}>ÉLIMINÉ</span>}
                  {p.leveledUp && <span className={s.level}>LVL UP</span>}
                </div>
              </div>
            </div>
            <div className={s.rooms}>
              {p.dungeon.length === 0 && <div className={s.empty}>Donjon vide</div>}
              {p.dungeon.map((stack, i) => {
                const r = Array.isArray(stack) ? stack[stack.length - 1] : stack;
                return <Card key={`op-${i}`} card={r} kind="room" size="xs" onInspect={onInspect} style={{ marginRight: -16 }} />;
              })}
            </div>
          </div>
        );
      })}
    </div>
  );
}