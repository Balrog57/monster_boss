import React from 'react';
import s from './StackBanner.module.css';

export default function StackBanner({
  stack,
  activePlayer,
  playerId,
  onPass,
}) {
  if (!stack || stack.length === 0) return null;

  const pidKey = Number(playerId);
  const isMyPriority = Number(activePlayer) === pidKey;
  const topItem = stack[stack.length - 1];
  const cardName = topItem?.card?.name || 'Spell/Ability';
  const casterName = topItem?.playerId != null ? `Player ${topItem.playerId}` : 'Player';

  return (
    <div className={s.banner} role="region" aria-label="Spell Stack Active">
      <div className={s.content}>
        <div className={s.badge}>Stack ({stack.length})</div>
        <div className={s.info}>
          <span className={s.spellName}>{cardName}</span>
          <span className={s.caster}>cast by {casterName}</span>
          <span className={s.prompt}>
            {isMyPriority
              ? 'Your priority: Counter/Respond or Pass'
              : `Waiting for Player ${activePlayer} to respond...`}
          </span>
        </div>
        {isMyPriority && (
          <button
            type="button"
            className={s.passBtn}
            onClick={onPass}
          >
            PASS (NO RESPONSE)
          </button>
        )}
      </div>
    </div>
  );
}
