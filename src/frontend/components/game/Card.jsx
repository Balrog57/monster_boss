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
import { getCardImage, getWikiCardImage, getApkCardImage, treasureIcon } from '../../../backend/game/cardData.js';
import s from './Card.module.css';

const SIZE = { xs: s.xs, sm: s.sm, md: s.md, lg: s.lg, xl: s.xl };

export default function Card({ card, kind = 'room', faceDown = false, size = 'md', selected = false, dim = false, onClick, onInspect, onHover, className = '', style }) {
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

  const [imgFailed, setImgFailed] = React.useState(false);
  React.useEffect(() => {
    setImgFailed(false);
  }, [src]);

  return (
    <div
      className={cls}
      style={style}
      onClick={onClick}
      onMouseEnter={onHover && card ? () => onHover({ card, kind }) : undefined}
      onMouseLeave={onHover ? () => onHover(null) : undefined}
      role={onClick ? 'button' : undefined}
      tabIndex={onClick ? 0 : undefined}
      onKeyDown={onClick ? (e) => { if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); onClick(); } } : undefined}
      aria-label={card?.name || (faceDown ? 'Face-down card' : 'Card')}
    >
      <div className={s.inner}>
        {src && !imgFailed ? (
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
              setImgFailed(true);
            }}
          />
        ) : (
          <div className={`${s.richFallback} ${s[kind] || ''}`}>
            <div className={s.fallbackHeader}>
              <span className={s.fallbackName} title={card?.name}>{card?.name || '?'}</span>
              <span className={s.fallbackTypeBadge}>
                {kind === 'spell' ? 'SORT' : kind === 'boss' ? 'BOSS' : kind === 'hero' || kind === 'epic-hero' ? 'HÉROS' : (card?.advanced ? 'AVANCÉE' : 'SALLE')}
              </span>
            </div>
            <div className={s.fallbackIconArea}>
              <img
                src={
                  kind === 'spell' ? '/ui/ingame/spells_icon.webp'
                  : kind === 'boss' ? '/ui/ingame/boss_icon.webp'
                  : card?.type === 'trap'
                    ? (card?.advanced ? '/ui/ingame/room_icon_advanced_trap.webp' : '/ui/ingame/room_icon_trap.webp')
                    : (card?.advanced ? '/ui/ingame/room_icon_advanced_monster.webp' : '/ui/ingame/room_icon_monster.webp')
                }
                alt=""
                className={s.fallbackIcon}
              />
            </div>
            <div className={s.fallbackDesc}>
              {card?.description || card?.levelUpDesc || (card?.type ? `${card.type} room` : '')}
            </div>
            <div className={s.fallbackFooter}>
              {card?.damage != null && (
                <span className={s.fallbackDamage}>♥ {card.damage}</span>
              )}
              {card?.xp != null && (
                <span className={s.fallbackXp}>{card.xp} XP</span>
              )}
              {card?.hp != null && (
                <span className={s.fallbackHp}>{card.hp} PV</span>
              )}
              {((card?.treasures || (card?.treasure != null ? [card.treasure] : []))).length > 0 && (
                <span className={s.fallbackTreasure}>
                  {(card.treasures || [card.treasure]).map((t, idx) => (
                    <img key={idx} src={treasureIcon(t)} alt="" className={s.fallbackTrIcon} />
                  ))}
                </span>
              )}
            </div>
          </div>
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