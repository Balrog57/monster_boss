// BossPortrait.jsx - The Boss card itself, shown in a dungeon.
// Uses APK avatar images when available, falls back to card image.
import React from 'react';
import { getCardImage } from '../../cardData.js';
import s from './BossPortrait.module.css';

const BOSS_AVATARS = {
  BMA001: '/ui/avatar/avatar_draculord.png',
  BMA002: '/ui/avatar/avatar_xyzax.png',
  BMA003: '/ui/avatar/avatar_croak.png',
  BMA004: '/ui/avatar/avatar_robobo.png',
  BMA005: '/ui/avatar/avatar_cerebellus.png',
  BMA006: '/ui/avatar/avatar_seducia.png',
  BMA007: '/ui/avatar/avatar_cleopatra.png',
  BMA008: '/ui/avatar/avatar_gorgona.png',
};

export default function BossPortrait({ boss, theme, size = 130, onInspect, useAvatar = false }) {
  if (!boss) return null;
  const avatarSrc = BOSS_AVATARS[boss.id];
  const cardSrc = getCardImage(boss.id, 'boss');
  const src = useAvatar && avatarSrc ? avatarSrc : cardSrc;
  return (
    <div
      className={s.portrait}
      style={{
        width: size,
        border: `3px solid ${theme?.color || '#f1e17c'}`,
        boxShadow: `0 0 12px ${theme?.glow || 'rgba(241,225,124,0.3)'}, 2px 2px 0px rgba(0,0,0,0.5)`,
        cursor: onInspect ? 'pointer' : 'default',
      }}
      onClick={onInspect ? () => onInspect({ card: boss, kind: 'boss' }) : undefined}
      role={onInspect ? 'button' : undefined}
      tabIndex={onInspect ? 0 : undefined}
      aria-label={`Portrait du boss ${boss.name}`}
      title={boss.name}
    >
      {src && <img src={src} alt={boss.name} />}
    </div>
  );
}