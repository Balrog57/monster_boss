// Card.jsx - The card primitive used everywhere in the game.
//
// Props:
//   card:    { id, name, ... } | null  (the card data; null shows back)
//   kind:    'room' | 'boss' | 'spell' | 'hero' | 'epic-hero' | 'back-room' | 'back-boss' | 'back-spell' | 'back-hero' | 'back-epic'
//   faceDown: boolean  (show card back instead of the card image)
//   size:    'xs' | 'sm' | 'md' | 'lg' | 'xl'
//   selected: boolean  (gold ring + lift)
//   dim:     boolean  (reduced opacity — disabled / opponent turn)
//   onClick:  fn | null
//   onInspect: fn(card, kind) | null  (shows the (i) badge that opens detail)
//   className: string
//   style:    object (for layout overrides — margin-left for overlap, zIndex)
import React from 'react';
import { getCardImage, getWikiCardImage, getApkCardImage } from '../../cardData.js';
import s from './Card.module.css';

const SIZE = { xs: s.xs, sm: s.sm, md: s.md, lg: s.lg, xl: s.xl };

export default function Card({ card, kind = 'room', faceDown = false, size = 'md', selected = false, dim = false, onClick, onInspect, className = '', style }) {
  const imageKind = faceDown
    ? `back-${kind === 'epic-hero' ? 'hero' : kind}`
    : (kind === 'epic-hero' ? 'epic-hero' : kind);
  const src = faceDown ? getCardImage('', imageKind) : getCardImage(card?.id, imageKind);
  const wikiSrc = faceDown ? getWikiCardImage('', imageKind) : getWikiCardImage(card?.id, imageKind);

  const cls = [
    s.card,
    SIZE[size] || s.md,
    selected ? s.selected : '',
    dim ? s.dim : '',
    onClick ? s.clickable : '',
    className,
  ].filter(Boolean).join(' ');

  return (
    <div
      className={cls}
      style={style}
      onClick={onClick}
      role={onClick ? 'button' : undefined}
      tabIndex={onClick ? 0 : undefined}
      onKeyDown={onClick ? (e) => { if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); onClick(); } } : undefined}
      aria-label={card?.name || (faceDown ? 'Face-down card' : 'Card')}
    >
      <div className={s.inner}>
        {src ? (
          <img
            src={src}
            alt={card?.name || 'card'}
            className={s.img}
            loading="lazy"
            onError={(e) => {
              const apkSrc = faceDown ? getApkCardImage('', imageKind) : getApkCardImage(card?.id, imageKind);
              if (apkSrc && e.currentTarget.src && e.currentTarget.src.includes('/cards/')) {
                e.currentTarget.src = apkSrc;
                return;
              }
              if (wikiSrc && e.currentTarget.src && e.currentTarget.src.includes('/apk_cards/')) {
                e.currentTarget.src = wikiSrc;
                return;
              }
              e.currentTarget.style.display = 'none';
            }}
          />
        ) : (
          <div className={s.fallback}>{card?.name || '?'}</div>
        )}
      </div>
      {onInspect && card && !faceDown && (
        <button
          className={s.inspect}
          onClick={(e) => { e.stopPropagation(); onInspect({ card, kind }); }}
          aria-label={`Inspect ${card.name}`}
          type="button"
        >
          i
        </button>
      )}
    </div>
  );
}