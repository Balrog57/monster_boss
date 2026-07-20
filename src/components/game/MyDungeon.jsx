// MyDungeon.jsx - The player's own dungeon with boss portrait.
import React, { useEffect, useRef, useState } from 'react';
import { PHASE, bossTheme } from '../../cardData.js';
import { countVisibleRooms } from '../../engine.js';
import Card from './Card.jsx';
import BossPortrait from './BossPortrait.jsx';
import s from './MyDungeon.module.css';

// Rooms with activated abilities ("destroy this/another room: X")
const ACTIVATED_ROOMS = new Set([
  'BMA009', 'BMA013', 'BMA025', 'BMA027', 'BMA028',
  'BMA030', 'BMA032', 'BMA038', 'BMA039',
]);
// Rooms that require choosing ANOTHER room to destroy
const NEEDS_OTHER_TARGET = new Set(['BMA028', 'BMA032']);

export default function MyDungeon({ me, phase, isMyTurn, selectedCard, onSelectTarget, onInspect, onActivateRoom, activateSourceRoom }) {
  const theme = bossTheme(me.boss);
  const canActivate = isMyTurn && (phase === PHASE.BUILD || phase === PHASE.ADVENTURE);

  // Damage flash: when the wound count goes up, flash the boss portrait red.
  const [hurt, setHurt] = useState(false);
  const prevWounds = useRef(me.wounds.length);
  useEffect(() => {
    const w = me.wounds.length;
    if (w > prevWounds.current) {
      setHurt(true);
      const t = setTimeout(() => setHurt(false), 650);
      prevWounds.current = w;
      return () => clearTimeout(t);
    }
    prevWounds.current = w;
  }, [me.wounds.length]);

  return (
    <div className={s.wrap} aria-label="Votre donjon">
      <div className={s.header}>
        <span className={s.title} style={{ color: theme.color }}>Mon Donjon</span>
        {me.leveledUp && <span className={s.level}>LEVEL UP</span>}
        <span className={s.subtitle}>
          {activateSourceRoom != null ? '⚡ Choisissez une autre salle à détruire' : 'Les héros arrivent par la gauche →'}
        </span>
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
            const canTarget = phase === PHASE.BUILD && isMyTurn && r && activateSourceRoom == null;
            const hasAbility = r && ACTIVATED_ROOMS.has(r.id);
            const isSource = activateSourceRoom === i;
            const isTargetCandidate = activateSourceRoom != null && i !== activateSourceRoom;
            return (
              <div key={`room-${r?.id || 'empty'}-${stackDepth}`} className={`${s.roomSlot} ${s.roomEnter} ${isSource ? s.roomSlotSource : ''} ${isTargetCandidate ? s.roomSlotTarget : ''}`}>
                <Card
                  card={r}
                  kind="room"
                  size="lg"
                  selected={selectedCard === i || isSource}
                  onInspect={onInspect}
                  onClick={canTarget ? () => onSelectTarget(i) : isTargetCandidate ? () => onActivateRoom(activateSourceRoom, i) : undefined}
                  style={{ position: 'relative', zIndex: i + 1 }}
                />
                {stackDepth > 1 && <div className={s.stackBadge}>×{stackDepth}</div>}
                {hasAbility && canActivate && activateSourceRoom == null && (
                  <button
                    className={s.activateBtn}
                    onClick={(e) => {
                      e.stopPropagation();
                      if (NEEDS_OTHER_TARGET.has(r.id)) {
                        // Enter target selection mode
                        onActivateRoom(i, null); // signal: enter targeting mode
                      } else {
                        onActivateRoom(i, null); // no target needed
                      }
                    }}
                    title={`Activer: ${r.name}`}
                    aria-label={`Activer la capacité de ${r.name}`}
                    type="button"
                  >
                    ⚡
                  </button>
                )}
              </div>
            );
          })}
          {me.dungeon.length < 5 && phase === PHASE.BUILD && isMyTurn && activateSourceRoom == null && (
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
        <div className={`${s.bossWrap} ${hurt ? s.bossHurt : ''} ${me.leveledUp ? s.bossLevelUp : ''}`}>
          <BossPortrait boss={me.boss} theme={theme} size={120} onInspect={onInspect} />
        </div>
      </div>
    </div>
  );
}