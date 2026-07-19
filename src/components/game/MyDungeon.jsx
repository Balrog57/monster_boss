// MyDungeon.jsx - The player's own dungeon with boss portrait.
import React from 'react';
import { PHASE, bossTheme } from '../../cardData.js';
import { countVisibleRooms } from '../../engine.js';
import Card from './Card.jsx';
import BossPortrait from './BossPortrait.jsx';
import s from './MyDungeon.module.css';

export default function MyDungeon({ me, phase, isMyTurn, selectedCard, onSelectTarget, onInspect }) {
  const theme = bossTheme(me.boss);

  return (
    <div className={s.wrap} aria-label="Votre donjon">
      <div className={s.header}>
        <span className={s.title} style={{ color: theme.color }}>Mon Donjon</span>
        {me.leveledUp && <span className={s.level}>LEVEL UP</span>}
        <span className={s.subtitle}>Les héros arrivent par la gauche →</span>
      </div>
      <div className={s.body}>
        {me.dungeon.length === 0 && (
          <div className={s.empty}>
            {phase === PHASE.SETUP || phase === PHASE.BUILD
              ? (isMyTurn ? '🃏 Cliquez sur une salle dans votre main' : '⏳ En attente...')
              : 'Donjon vide'}
          </div>
        )}
        <div className={s.entrance} aria-label="Entrée du donjon">
          <div className={s.entranceLabel}>ENTRÉE</div>
        </div>
        <div className={s.roomsRow}>
          {me.dungeon.map((stack, i) => {
            const r = Array.isArray(stack) ? stack[stack.length - 1] : stack;
            const stackDepth = Array.isArray(stack) ? stack.length : 1;
            const canTarget = phase === PHASE.BUILD && isMyTurn && r;
            return (
              <div key={`room-${i}`} className={s.roomSlot}>
                <Card
                  card={r}
                  kind="room"
                  size="lg"
                  selected={selectedCard === i}
                  onInspect={onInspect}
                  onClick={canTarget ? () => onSelectTarget(i) : undefined}
                  style={{ position: 'relative', zIndex: i + 1 }}
                />
                {stackDepth > 1 && <div className={s.stackBadge}>×{stackDepth}</div>}
              </div>
            );
          })}
          {me.dungeon.length < 5 && phase === PHASE.BUILD && isMyTurn && (
            <button
              className={s.emptySlot}
              onClick={() => onSelectTarget(null)}
              aria-label="Construire une salle ordinaire ici"
              type="button"
            >
              <div className={s.emptySlotPlus}>+</div>
              <div className={s.emptySlotLabel}>Construire</div>
            </button>
          )}
        </div>
        <div className={s.bossWrap}>
          <BossPortrait boss={me.boss} theme={theme} size={120} onInspect={onInspect} />
        </div>
      </div>
    </div>
  );
}