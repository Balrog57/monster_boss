// BossSelect.jsx - APK in-board carousel: one face-up boss, backs fanned, PLAY.
import React, { useMemo, useState } from 'react';
import { TREASURE_NAMES, bossTheme, getCardImage } from '../../cardData.js';
import Card from './Card.jsx';
import s from './BossSelect.module.css';

export default function BossSelect({ G, me, onPick, onInspect, inBoard = false }) {
  const available = useMemo(() => G.bossPicks.filter(b =>
    !Object.values(G.players).some(p => p.boss?.id === b.id)
  ), [G.bossPicks, G.players]);

  const pickedBoss = me.boss;
  const [focus, setFocus] = useState(0);
  const focused = available[Math.min(focus, Math.max(0, available.length - 1))] || available[0];

  const cycle = (dir) => {
    if (!available.length) return;
    setFocus((f) => (f + dir + available.length) % available.length);
  };

  if (inBoard) {
    const name = pickedBoss?.name || focused?.name || '...';
    return (
      <div className={s.inBoard} role="dialog" aria-label="Choose your boss">
        <div className={s.inBoardHeader}>YOU ARE {name.toUpperCase()}</div>
        <div className={s.carousel}>
          <button type="button" className={s.carHit} onClick={() => cycle(-1)} aria-label="Previous boss" />
          <div className={s.fan} aria-hidden="true">
            {available.map((b, i) => {
              if (b.id === focused?.id) return null;
              const side = i < (available.indexOf(focused) || 0) ? -1 : 1;
              const dist = Math.abs(i - (available.indexOf(focused) || 0));
              return (
                <img
                  key={b.id}
                  src={getCardImage('', 'back-boss')}
                  alt=""
                  className={s.fanBack}
                  style={{
                    transform: `translateX(${side * dist * 48}px) scale(${1 - dist * 0.08})`,
                    zIndex: 4 - dist,
                  }}
                />
              );
            })}
          </div>
          {focused && !pickedBoss && (
            <div className={s.focusCard}>
              <Card card={focused} kind="boss" size="xl" onInspect={onInspect} onClick={undefined} />
            </div>
          )}
          {pickedBoss && (
            <div className={s.focusCard}>
              <Card card={pickedBoss} kind="boss" size="xl" onInspect={onInspect} onClick={undefined} />
            </div>
          )}
          <button type="button" className={`${s.carHit} ${s.carHitRight}`} onClick={() => cycle(1)} aria-label="Next boss" />
        </div>
        {!pickedBoss && focused && (
          <button
            type="button"
            className={s.playBossBtn}
            onClick={() => onPick(focused.id)}
            aria-label={`Play ${focused.name}`}
          >
            PLAY BOSS MONSTER!
          </button>
        )}
        {pickedBoss && <div className={s.playBossTag}>YOUR BOSS</div>}
      </div>
    );
  }

  return (
    <div className={s.screen}>
      <img src="/ui/logos/bm_logo.webp" alt="" className={s.logo} />
      <h1 className={s.title}>CHOOSE YOUR BOSS</h1>
      <p className={s.subtitle}>More bosses are revealed as others choose</p>
      <div className={s.grid} role="radiogroup" aria-label="Boss choice">
        {G.bossPicks.map((b) => {
          const t = bossTheme(b);
          const picked = me.boss?.id === b.id;
          const taken = Object.values(G.players).some(p => p.boss?.id === b.id && p !== me);
          return (
            <button
              key={b.id}
              className={`${s.bossCard} ${picked ? s.picked : ''} ${taken ? s.taken : ''}`}
              onClick={() => { if (!taken && !me.boss) onPick(b.id); }}
              disabled={taken || !!me.boss}
              role="radio"
              aria-checked={picked}
              aria-label={`Boss ${b.name}, XP ${b.xp}, treasures ${b.treasures.map(x => TREASURE_NAMES[x]).join(', ')}${picked ? ' (selected)' : taken ? ' (taken)' : ''}`}
              type="button"
            >
              <Card card={b} kind="boss" size="xl" onInspect={onInspect} onClick={undefined} style={{ pointerEvents: 'none' }} />
              <div className={s.bossName} style={{ color: t.color }}>{b.name}</div>
              <div className={s.bossMeta}>XP {b.xp} · {b.treasures.map(x => TREASURE_NAMES[x]).join(', ')}</div>
              {picked && <div className={s.pickedTag}>SELECTED</div>}
            </button>
          );
        })}
      </div>
    </div>
  );
}
