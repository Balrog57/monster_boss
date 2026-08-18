// DetailPanel.jsx - Card inspection overlay.
// Props: inspect: { card, kind } | null, onClose: () => void
import React, { useEffect, useRef } from 'react';
import { TREASURE_NAMES, getCardImage } from '../../cardData.js';
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
  const imgPath = getCardImage(card?.id, kind === 'epic-hero' ? 'epic-hero' : kind);

  return (
    <div className={s.overlay} onClick={onClose} role="presentation">
      <div
        className={s.panel}
        onClick={(e) => e.stopPropagation()}
        role="dialog"
        aria-modal="true"
        aria-label={card?.name || 'Détail de la carte'}
        tabIndex={-1}
      >
        <div className={s.header}>
          <span className={s.title}>{card?.name || 'Carte'}</span>
          <button className={s.close} onClick={onClose} aria-label="Fermer" type="button" ref={closeBtnRef}>×</button>
        </div>
        <div className={s.imgWrap}>
          <img src={imgPath} alt={card?.name} className={s.img} onError={(e) => { e.currentTarget.style.display = 'none'; }} />
        </div>
        <div className={s.meta}>
          {card?.type && <div><strong>Type:</strong> {card.type}{card.advanced ? ' (avancée)' : ''}</div>}
          {card?.damage != null && <div><strong>Dégât:</strong> {card.damage}</div>}
          {card?.treasures && <div><strong>Trésor:</strong> {card.treasures.map(t => TREASURE_NAMES[t] || t).join(', ')}</div>}
          {card?.category != null && <div><strong>Catégorie:</strong> {['ANY', 'BUILD', 'BAIT', 'ADVENTURE', 'BUILD_BAIT', 'ADV_BUILD'][card.category]}</div>}
          {card?.xp != null && <div><strong>XP:</strong> {card.xp}</div>}
          {card?.hp != null && <div><strong>HP:</strong> {card.hp}</div>}
        </div>
        {card?.description && <div className={s.desc}>{card.description}</div>}
        {card?.levelUpDesc && <div className={s.desc}><em><strong>Level Up:</strong> {card.levelUpDesc}</em></div>}
      </div>
    </div>
  );
}