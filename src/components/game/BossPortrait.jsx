// BossPortrait.jsx - The Boss card itself, shown in a dungeon.
// Uses APK avatar images when available, falls back to card image.
import React from 'react';
import { getCardImage } from '../../cardData.js';
import s from './BossPortrait.module.css';

const BOSS_AVATARS = {
  BMA001: '/ui/avatar/avatar_draculord.webp',
  BMA002: '/ui/avatar/avatar_xyzax.webp',
  BMA003: '/ui/avatar/avatar_croak.webp',
  BMA004: '/ui/avatar/avatar_robobo.webp',
  BMA005: '/ui/avatar/avatar_cerebellus.webp',
  BMA006: '/ui/avatar/avatar_seducia.webp',
  BMA007: '/ui/avatar/avatar_cleopatra.webp',
  BMA008: '/ui/avatar/avatar_gorgona.webp',
};

const HAS_SPRITE = new Set([
  'bma001', 'bma002', 'bma003', 'bma004', 'bma005', 'bma006', 'bma007', 'bma008',
  'ksa001', 'ksa002', 'ksa003', 'ksa004', 'ksa005', 'ksa006', 'ksa007',
]);

export default function BossPortrait({ boss, theme, size = 130, onInspect, useAvatar = false, variant = 'card' }) {
  if (!boss) return null;
  const idLower = String(boss.id || '').toLowerCase();
  const avatarSrc = BOSS_AVATARS[boss.id];
  const cardSrc = getCardImage(boss.id, 'boss');
  const hasSprite = HAS_SPRITE.has(idLower);
  const charSrc = hasSprite ? `/ui/characters/${idLower}_character.webp` : null;
  const sprite = variant === 'sprite' && hasSprite;
  const src = sprite ? charSrc : (useAvatar && avatarSrc ? avatarSrc : cardSrc);
  return (
    <div
      className={`${s.portrait} ${sprite ? s.sprite : ''}`}
      style={{
        width: size,
        border: sprite ? 'none' : `3px solid ${theme?.color || '#f1e17c'}`,
        boxShadow: sprite ? 'none' : `0 0 12px ${theme?.glow || 'rgba(241,225,124,0.3)'}, 2px 2px 0px rgba(0,0,0,0.5)`,
        cursor: onInspect ? 'pointer' : 'default',
      }}
      onClick={onInspect ? () => onInspect({ card: boss, kind: 'boss' }) : undefined}
      role={onInspect ? 'button' : undefined}
      tabIndex={onInspect ? 0 : undefined}
      aria-label={`Boss portrait ${boss.name}`}
      title={boss.name}
    >
      {src && (
        <img
          src={src}
          alt={boss.name}
          onError={(e) => {
            if (cardSrc && !e.currentTarget.src.includes(cardSrc)) {
              e.currentTarget.src = cardSrc;
            } else {
              e.currentTarget.style.display = 'none';
            }
          }}
        />
      )}
    </div>
  );
}