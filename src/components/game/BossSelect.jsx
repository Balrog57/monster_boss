// BossSelect.jsx - BOSS phase: pick a boss card (APK-style, full-screen or in-board).
import React from 'react';
import { TREASURE_NAMES, bossTheme, getCardImage } from '../../cardData.js';
import Card from './Card.jsx';
import s from './BossSelect.module.css';

export default function BossSelect({ G, me, onPick, onInspect, inBoard = false }) {
  const available = G.bossPicks.filter(b =>
    !Object.values(G.players).some(p => p.boss?.id === b.id)
  );
  const pickedBoss = me.boss;

  if (inBoard) {
    return (
      <div className={s.inBoard} role="dialog" aria-label="Choose your boss">
        <div className={s.inBoardHeader}>YOU ARE {pickedBoss ? pickedBoss.name.toUpperCase() : '...'}</div>
        <div className={s.inBoardRow}>
          {available.map((b) => {
            const taken = Object.values(G.players).some(p => p.boss?.id === b.id && p !== me);
            const isMine = me.boss?.id === b.id;
            return (
              <div key={b.id} className={`${s.inBoardSlot} ${taken ? s.taken : ''}`}>
                {taken ? (
                  <img src={getCardImage('', 'back-boss')} alt="" className={s.backBoss} />
                ) : (
                  <>
                    <Card card={b} kind="boss" size="lg" onInspect={onInspect} onClick={undefined} />
                    {!isMine && (
                      <button
                        type="button"
                        className={s.playBossBtn}
                        onClick={() => onPick(b.id)}
                        aria-label={`Play ${b.name}`}
                      >
                        PLAY BOSS MONSTER!
                      </button>
                    )}
                    {isMine && <div className={s.playBossTag}>YOUR BOSS</div>}
                  </>
                )}
              </div>
            );
          })}
        </div>
        {!me.boss && <p className={s.inBoardHint}>Choose a boss and tap PLAY BOSS MONSTER!</p>}
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
