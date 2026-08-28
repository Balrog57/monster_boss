// CardPreview.jsx - Large APK-style preview of the hovered / selected card
// (bottom-right of the play area).
import React from 'react';
import Card from './Card.jsx';
import s from './CardPreview.module.css';

export default function CardPreview({ inspect }) {
  if (!inspect?.card) return null;
  const { card, kind } = inspect;
  return (
    <div className={s.wrap} aria-hidden="true">
      <Card card={card} kind={kind || 'room'} size="xl" />
    </div>
  );
}
