import React from 'react';
import s from './AdventurePauseBanner.module.css';

export default function AdventurePauseBanner({
  adventure,
  adventurePausePassed,
  playerId,
  onPass,
}) {
  if (!adventure || !adventure.pause) return null;

  const pidKey = String(playerId);
  const hasPassed = !!adventurePausePassed?.[pidKey];
  const isCastingWindow = !hasPassed;
  const pauseType = adventure.pause === 'post-damage' ? 'Hero Damaged' : 'Before Leaving Room';

  return (
    <div className={s.banner} role="region" aria-label="Adventure Phase Pause">
      <div className={s.content}>
        <div className={s.badge}>{pauseType}</div>
        <div className={s.info}>
          <span className={s.heroName}>{adventure.hero?.name || 'Hero'}</span>
          <span className={s.hp}>HP: {adventure.hp}</span>
          <span className={s.prompt}>
            {isCastingWindow
              ? 'You may play Spells or Abilities now, or Pass.'
              : 'Waiting for other players...'}
          </span>
        </div>
        {isCastingWindow && (
          <button
            type="button"
            className={s.passBtn}
            onClick={onPass}
          >
            PASS / CONTINUE
          </button>
        )}
      </div>
    </div>
  );
}
