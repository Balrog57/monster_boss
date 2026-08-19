// TreasureReadout - APK-style 4-icon treasure totals next to a dungeon.
import React from 'react';
import s from './TreasureReadout.module.css';

const ICONS = {
  1: { on: '/ui/ingame/icon_treasure_cleric.webp', off: '/ui/ingame/icon_treasure_cleric_empty.webp', label: 'Cleric' },
  2: { on: '/ui/ingame/icon_treasure_fighter.webp', off: '/ui/ingame/icon_treasure_fighter_empty.webp', label: 'Fighter' },
  3: { on: '/ui/ingame/icon_treasure_mage.webp', off: '/ui/ingame/icon_treasure_mage_empty.webp', label: 'Mage' },
  4: { on: '/ui/ingame/icon_treasure_thief.webp', off: '/ui/ingame/icon_treasure_thief_empty.webp', label: 'Thief' },
};

export default function TreasureReadout({ counts = {}, compact = false }) {
  return (
    <div className={`${s.row} ${compact ? s.compact : ''}`} aria-label="Dungeon treasures">
      {[1, 2, 3, 4].map((t) => {
        const n = counts[t] || 0;
        const icon = ICONS[t];
        return (
          <span key={t} className={s.item} title={`${icon.label}: ${n}`}>
            <img src={n > 0 ? icon.on : icon.off} alt="" />
            <span className={s.num}>{n}</span>
          </span>
        );
      })}
    </div>
  );
}

export function SoulWoundPiles({ souls = 0, wounds = 0 }) {
  const soulN = Array.isArray(souls) ? souls.length : souls;
  const woundN = Array.isArray(wounds) ? wounds.length : wounds;
  return (
    <div className={s.piles}>
      <div className={s.pile} aria-label={`${soulN} souls`}>
        {Array.from({ length: 10 }, (_, i) => (
          <img
            key={`s${i}`}
            src={i < soulN ? '/ui/ingame/souls_icon.webp' : '/ui/ingame/souls_icon_empty.webp'}
            alt=""
          />
        ))}
      </div>
      <div className={s.pile} aria-label={`${woundN} wounds`}>
        {Array.from({ length: 5 }, (_, i) => (
          <img
            key={`w${i}`}
            src={i < woundN ? '/ui/ingame/wound_icon.webp' : '/ui/ingame/wound_icon_empty.webp'}
            alt=""
          />
        ))}
      </div>
    </div>
  );
}
