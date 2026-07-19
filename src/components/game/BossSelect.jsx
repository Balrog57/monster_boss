// BossSelect.jsx - BOSS phase: pick a boss card.
import React from 'react';
import { TREASURE_NAMES, bossTheme } from '../../cardData.js';
import Card from './Card.jsx';
import s from './BossSelect.module.css';

export default function BossSelect({ G, me, onPick, onInspect }) {
  return (
    <div className={s.screen}>
      <h1 className={s.title}>Choisissez votre Boss</h1>
      <p className={s.subtitle}>D'autres Boss seront révélés à mesure que vous choisissez</p>
      <div className={s.grid} role="radiogroup" aria-label="Choix du Boss">
        {G.bossPicks.map((b) => {
          const t = bossTheme(b);
          const picked = me.boss?.id === b.id;
          const taken = Object.values(G.players).some(p => p.boss?.id === b.id && p !== me);
          return (
            <button
              key={b.id}
              className={s.bossCard}
              onClick={() => { if (!taken && !me.boss) onPick(b.id); }}
              disabled={taken || !!me.boss}
              style={{ borderColor: t.color, boxShadow: `0 0 24px ${t.glow}`, borderWidth: 3 }}
              role="radio"
              aria-checked={picked}
              aria-label={`Boss ${b.name}, XP ${b.xp}, trésors ${b.treasures.map(t => TREASURE_NAMES[t]).join(', ')}${picked ? ' (sélectionné)' : taken ? ' (déjà pris)' : ''}`}
              type="button"
            >
              <Card card={b} kind="boss" size="xl" onInspect={onInspect} onClick={undefined} style={{ pointerEvents: 'none' }} />
              <div className={s.bossName} style={{ color: t.color }}>{b.name}</div>
              <div className={s.bossMeta}>XP {b.xp} · {b.treasures.map(t => TREASURE_NAMES[t]).join(', ')}</div>
              {picked && <div className={s.pickedTag}>✓ Sélectionné</div>}
            </button>
          );
        })}
      </div>
    </div>
  );
}