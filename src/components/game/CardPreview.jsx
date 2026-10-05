// CardPreview.jsx - Large APK-style preview of the hovered / selected card with readable effect text.
import React from 'react';
import Card from './Card.jsx';
import s from './CardPreview.module.css';

export default function CardPreview({ inspect }) {
  if (!inspect?.card) return null;
  const { card, kind } = inspect;
  const text = card?.description || card?.levelUpDesc;
  const hasMeta = card.damage != null || card.hp != null || card.xp != null || card.type || card.subtitle;

  return (
    <div className={s.wrap} aria-hidden="true">
      <Card card={card} kind={kind || 'room'} size="xl" />
      {(text || hasMeta) && (
        <div className={s.descBox}>
          <div className={s.descHeader}>
            <span className={s.descTitle}>{card.name}</span>
            {card.subtitle && <span className={s.descSubtitle}>{card.subtitle}</span>}
          </div>
          {hasMeta && (
            <div className={s.descMeta}>
              {card.xp != null && <span className={s.badgeXp}>{card.xp} XP</span>}
              {card.damage != null && <span className={s.badgeDmg}>♥ {card.damage} DÉGÂTS</span>}
              {card.hp != null && <span className={s.badgeHp}>HP {card.hp}</span>}
              {card.type && (
                <span className={s.badgeType}>
                  {card.advanced ? 'Avancée • ' : 'Ordinaire • '}
                  {card.type === 'trap' ? 'Piège' : 'Monstre'}
                </span>
              )}
            </div>
          )}
          {text && <div className={s.descText}>{text}</div>}
        </div>
      )}
    </div>
  );
}
