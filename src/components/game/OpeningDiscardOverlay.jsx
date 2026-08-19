// OpeningDiscardOverlay.jsx - APK "SELECT 2 CARDS TO DISCARD" after boss reveal.
import React, { useState } from 'react';
import Card from './Card.jsx';
import s from './OpeningDiscardOverlay.module.css';

export default function OpeningDiscardOverlay({ hand, onConfirm }) {
  const [picked, setPicked] = useState([]);

  const toggle = (i) => {
    setPicked((cur) => {
      let next;
      if (cur.includes(i)) next = cur.filter((x) => x !== i);
      else if (cur.length >= 2) next = [cur[1], i];
      else next = [...cur, i];
      if (next.length === 2) {
        const [a, b] = next;
        setTimeout(() => onConfirm(a, b), 0);
      }
      return next;
    });
  };

  const kindOf = (c) => (c?.isSpell ? 'spell' : c?.type === 'trap' ? 'trap' : 'room');

  return (
    <div className={s.overlay}>
      <div className={s.prompt}>SELECT 2 CARDS TO DISCARD</div>
      <div className={s.row}>
        {(hand || []).map((card, i) => (
          <button
            key={`${card.id}-${i}`}
            type="button"
            className={`${s.slot} ${picked.includes(i) ? s.on : ''}`}
            onClick={() => toggle(i)}
          >
            <Card card={card} kind={kindOf(card)} size="md" selected={picked.includes(i)} />
          </button>
        ))}
      </div>
      <button
        type="button"
        className={s.ok}
        disabled={picked.length !== 2}
        onClick={() => picked.length === 2 && onConfirm(picked[0], picked[1])}
        aria-label="OK"
      />
    </div>
  );
}
