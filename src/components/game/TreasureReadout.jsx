// TreasureReadout - APK-style 4-icon treasure totals next to a dungeon.
import React from 'react';
import s from './TreasureReadout.module.css';

const ICONS = {
  1: { on: '/ui/ingame/icon_treasure_cleric.webp', off: '/ui/ingame/icon_treasure_cleric_empty.webp', label: 'Cleric' },
  2: { on: '/ui/ingame/icon_treasure_fighter.webp', off: '/ui/ingame/icon_treasure_fighter_empty.webp', label: 'Fighter' },
  3: { on: '/ui/ingame/icon_treasure_mage.webp', off: '/ui/ingame/icon_treasure_mage_empty.webp', label: 'Mage' },
  4: { on: '/ui/ingame/icon_treasure_thief.webp', off: '/ui/ingame/icon_treasure_thief_empty.webp', label: 'Thief' },
  5: { on: '/ui/ingame/icon_treasure_explorer.webp', off: '/ui/ingame/icon_treasure_explorer_empty.webp', label: 'Explorer' },
};

export default function TreasureReadout({ counts = {}, compact = false }) {
  const types = counts[5] != null ? [1, 2, 3, 4, 5] : [1, 2, 3, 4];
  return (
    <div className={`${s.row} ${compact ? s.compact : ''}`} aria-label="Dungeon treasures">
      {types.map((t) => {
        const n = counts[t] || 0;
        const icon = ICONS[t];
        if (!icon) return null;
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

export function SoulWoundPiles({ souls = [], wounds = [] }) {
  const soulList = Array.isArray(souls) ? souls : [];
  const woundList = Array.isArray(wounds) ? wounds : [];
  const soulN = soulList.length || (typeof souls === 'number' ? souls : 0);
  const woundN = woundList.length || (typeof wounds === 'number' ? wounds : 0);

  return (
    <div className={s.piles}>
      <div className={s.pile} aria-label={`${soulN} souls`}>
        {soulList.length > 0
          ? soulList.map((entry, i) => (
            <img
              key={`s${i}`}
              src={entry.faceDown !== false ? '/ui/ingame/souls_icon.webp' : '/ui/ingame/wound_icon.webp'}
              alt=""
              title={entry.faceDown !== false ? 'Face-down soul' : entry.name || 'Soul'}
              className={entry.tpk ? s.tpk : ''}
            />
          ))
          : Array.from({ length: 10 }, (_, i) => (
            <img
              key={`s${i}`}
              src={i < soulN ? '/ui/ingame/souls_icon.webp' : '/ui/ingame/souls_icon_empty.webp'}
              alt=""
            />
          ))}
      </div>
      <div className={s.pile} aria-label={`${woundN} wounds`}>
        {woundList.length > 0
          ? woundList.map((entry, i) => (
            <img
              key={`w${i}`}
              src="/ui/ingame/wound_icon.webp"
              alt=""
              title={entry.name || 'Wound'}
            />
          ))
          : Array.from({ length: 5 }, (_, i) => (
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
