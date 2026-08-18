// OpponentRow.jsx - Opponent dungeon tracks stacked (APK top row).
import React from 'react';
import DungeonTrack from './DungeonTrack.jsx';
import s from './OpponentRow.module.css';

export default function OpponentRow({ opponents, onInspect }) {
  return (
    <div className={s.row} aria-label="Donjons adverses">
      {opponents.map((p, idx) => (
        <DungeonTrack
          key={`opp-${idx}`}
          player={p}
          size={opponents.length > 1 ? 'sm' : 'md'}
          onInspect={onInspect}
        />
      ))}
    </div>
  );
}
