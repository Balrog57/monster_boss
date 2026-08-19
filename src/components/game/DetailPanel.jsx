// DetailPanel.jsx - Card inspection overlay.
// Props: inspect: { card, kind } | null, onClose: () => void
import React, { useEffect, useRef } from 'react';
import { TREASURE_NAMES, getCardImage, getWikiCardImage, getApkCardImage } from '../../cardData.js';
import s from './DetailPanel.module.css';

export default function DetailPanel({ inspect, onClose }) {
  const closeBtnRef = useRef(null);

  // Focus the close button on open + Escape to close.
  useEffect(() => {
    if (!inspect) return;
    const t = setTimeout(() => closeBtnRef.current?.focus(), 20);
    const onKey = (e) => { if (e.key === 'Escape') onClose(); };
    document.addEventListener('keydown', onKey);
    return () => { clearTimeout(t); document.removeEventListener('keydown', onKey); };
  }, [inspect, onClose]);

  if (!inspect) return null;
  const { card, kind } = inspect;
  const imageKind = kind === 'epic-hero' ? 'epic-hero' : kind;
  const imgPath = getCardImage(card?.id, imageKind);
  const wikiSrc = getWikiCardImage(card?.id, imageKind);

  return (
    <div className={s.overlay} onClick={onClose} role="presentation">
      <div
        className={s.panel}
        onClick={(e) => e.stopPropagation()}
        role="dialog"
        aria-modal="true"
        aria-label={card?.name || 'Card details'}
        tabIndex={-1}
      >
        <div className={s.header}>
          <span className={s.title}>{card?.name || 'Card'}</span>
          <button className={s.close} onClick={onClose} aria-label="Close" type="button" ref={closeBtnRef}>×</button>
        </div>
        <div className={s.imgWrap}>
          <img src={imgPath} alt={card?.name} className={s.img} onError={(e) => {
            const apkSrc = getApkCardImage(card?.id, imageKind);
            if (apkSrc && e.currentTarget.src && e.currentTarget.src.includes('/cards/')) {
              e.currentTarget.src = apkSrc;
              return;
            }
            if (wikiSrc && e.currentTarget.src && e.currentTarget.src.includes('/apk_cards/')) {
              e.currentTarget.src = wikiSrc;
              return;
            }
            e.currentTarget.style.display = 'none';
          }} />
        </div>
        <div className={s.meta}>
          {card?.type && <div><strong>Type:</strong> {card.type}{card.advanced ? ' (advanced)' : ''}</div>}
          {card?.damage != null && <div><strong>Damage:</strong> {card.damage}</div>}
          {card?.treasures && <div><strong>Treasure:</strong> {card.treasures.map(t => TREASURE_NAMES[t] || t).join(', ')}</div>}
          {card?.category != null && <div><strong>Category:</strong> {card.category}</div>}
          {card?.xp != null && <div><strong>XP:</strong> {card.xp}</div>}
          {card?.hp != null && <div><strong>HP:</strong> {card.hp}</div>}
          {card?.isItem && <div><strong>Item:</strong> {card.subtitle || 'Tools of Hero-Kind'}</div>}
        </div>
        {card?.description && <div className={s.desc}>{card.description}</div>}
        {card?.levelUpDesc && <div className={s.desc}><em><strong>Level Up:</strong> {card.levelUpDesc}</em></div>}
      </div>
    </div>
  );
}