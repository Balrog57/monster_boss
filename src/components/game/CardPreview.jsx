// CardPreview.jsx - Large APK-style preview of the hovered / selected card with readable effect text.
import React from 'react';
import Card from './Card.jsx';
import s from './CardPreview.module.css';

export default function CardPreview({ inspect }) {
  if (!inspect?.card) return null;
  const { card, kind } = inspect;
  const text = card?.description || card?.levelUpDesc;
  return (
    <div className={s.wrap} aria-hidden="true">
      <Card card={card} kind={kind || 'room'} size="xl" />
      {text && (
        <div className={s.descBox}>
          <div className={s.descTitle}>{card.name}</div>
          <div className={s.descText}>{text}</div>
        </div>
      )}
    </div>
  );
}
