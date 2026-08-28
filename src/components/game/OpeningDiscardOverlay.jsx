// OpeningDiscardOverlay.jsx - APK "SELECT 2 CARDS TO DISCARD" after boss reveal.
import React, { useState } from 'react';
import Card from './Card.jsx';
import s from './OpeningDiscardOverlay.module.css';

export default function OpeningDiscardOverlay({ hand, onConfirm, onHover }) {
  const [picked, setPicked] = useState([]);

  const toggle = (i) => {
    setPicked((cur) => {
      if (cur.includes(i)) return cur.filter((x) => x !== i);
      if (cur.length >= 2) return [cur[1], i];
      return [...cur, i];
    });
  };

  const kindOf = (c) => (c?.isSpell ? 'spell' : 'room');

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
            <Card
              card={card}
              kind={kindOf(card)}
              size="md"
              selected={picked.includes(i)}
              onHover={onHover}
            />
          </button>
        ))}
        <button
          type="button"
          className={s.continue}
          disabled={picked.length !== 2}
          onClick={() => picked.length === 2 && onConfirm(picked[0], picked[1])}
          aria-label="Continue"
        >
          CONTINUE
        </button>
      </div>
    </div>
  );
}
