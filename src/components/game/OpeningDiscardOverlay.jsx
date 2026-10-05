// OpeningDiscardOverlay.jsx - APK "SELECT 2 CARDS TO DISCARD" with crystal-clear effect reader.
import React, { useState, useEffect } from 'react';
import Card from './Card.jsx';
import { TREASURE_NAMES } from '../../cardData.js';
import { getDigitKey } from '../../hooks/useKeyboardShortcuts.js';
import s from './OpeningDiscardOverlay.module.css';

export default function OpeningDiscardOverlay({ hand, onConfirm, onHover, onInspect }) {
  const [picked, setPicked] = useState([]);
  const [hoveredCard, setHoveredCard] = useState(hand?.[0] || null);

  const toggle = (i) => {
    setPicked((cur) => {
      if (cur.includes(i)) return cur.filter((x) => x !== i);
      if (cur.length >= 2) return [cur[1], i];
      return [...cur, i];
    });
  };

  useEffect(() => {
    const onKeyDown = (e) => {
      const num = getDigitKey(e);
      if (num != null) {
        const idx = num - 1;
        if (idx >= 0 && idx < (hand || []).length) {
          e.preventDefault();
          toggle(idx);
          setHoveredCard(hand[idx]);
          onHover?.({ card: hand[idx], kind: hand[idx]?.isSpell ? 'spell' : 'room' });
        }
      } else if (e.key === ' ' || e.code === 'Space') {
        if (picked.length === 2) {
          e.preventDefault();
          onConfirm(picked[0], picked[1]);
        }
      }
    };
    window.addEventListener('keydown', onKeyDown);
    return () => window.removeEventListener('keydown', onKeyDown);
  }, [hand, picked, onConfirm, onHover]);

  const kindOf = (c) => (c?.isSpell ? 'spell' : 'room');

  const count = (hand || []).length;
  const cardSize = count > 10 ? 'xs' : count > 7 ? 'sm' : 'md';

  const previewCard = hoveredCard || hand?.[0];

  return (
    <div className={s.overlay} role="dialog" aria-label="Select 2 cards to discard">
      <div className={s.prompt}>SELECT 2 CARDS TO DISCARD</div>

      <div className={s.centerArea}>
        <div className={s.cardsWrapper}>
          <div className={s.cardsList}>
            {(hand || []).map((card, i) => (
              <div key={`${card.id}-${i}`} className={s.cardSlotWrap}>
                {i < 9 && (
                  <span className={s.keyBadge} aria-hidden="true">{i + 1}</span>
                )}
                <div
                  role="button"
                  tabIndex={0}
                  className={`${s.slot} ${picked.includes(i) ? s.on : ''}`}
                  onClick={() => toggle(i)}
                  onKeyDown={(e) => {
                    if (e.key === 'Enter' || e.key === ' ') {
                      e.preventDefault();
                      toggle(i);
                    }
                  }}
                  onMouseEnter={() => {
                    setHoveredCard(card);
                    onHover?.({ card, kind: kindOf(card) });
                  }}
                  aria-label={`Select ${card.name} to discard`}
                  aria-pressed={picked.includes(i)}
                >
                  <Card
                    card={card}
                    kind={kindOf(card)}
                    size={cardSize}
                    selected={picked.includes(i)}
                    onHover={onHover}
                  />
                </div>
              </div>
            ))}
          </div>

          <button
            type="button"
            className={s.continue}
            disabled={picked.length !== 2}
            onClick={() => picked.length === 2 && onConfirm(picked[0], picked[1])}
            aria-label="Continue"
          >
            {picked.length === 2 && <span className={s.continueKeyBadge}>SPACE</span>}
          </button>
        </div>

        {/* Crystal-Clear Effect Reader Bar */}
        {previewCard && (
          <div className={s.effectReader} aria-live="polite">
            <div className={s.readerHeader}>
              <span className={s.readerName}>{previewCard.name}</span>
              {previewCard.subtitle && <span className={s.readerSubtitle}>— {previewCard.subtitle}</span>}
              <span className={s.readerBadge}>
                {previewCard.isSpell ? 'SORT (Spell)' : `${previewCard.advanced ? 'SALLE AVANCÉE' : 'SALLE ORDINAIRE'} (${previewCard.type === 'trap' ? 'Piège' : 'Monstre'})`}
              </span>
              {previewCard.damage != null && (
                <span className={s.readerDamage}>♥ {previewCard.damage} Dégâts</span>
              )}
              {((previewCard.treasures || (previewCard.treasure != null ? [previewCard.treasure] : []))).length > 0 && (
                <span className={s.readerTreasures}>
                  Trésors: {(previewCard.treasures || [previewCard.treasure]).map(t => TREASURE_NAMES[t] || t).join(', ')}
                </span>
              )}
            </div>
            <div className={s.readerDesc}>
              {previewCard.description || 'Aucun effet spécial ou texte de règle sur cette carte.'}
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
