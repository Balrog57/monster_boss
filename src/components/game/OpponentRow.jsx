// OpponentRow.jsx - Opponent dungeon tracks stacked (APK top row).
import React from 'react';
import DungeonTrack from './DungeonTrack.jsx';
import s from './OpponentRow.module.css';

export default function OpponentRow({ opponents, oppIds = [], treasures = [], adventure, onInspect, onHover }) {
  return (
    <div className={s.row} aria-label="Opponent dungeons">
      {opponents.map((p, idx) => (
        <DungeonTrack
          key={`opp-${idx}`}
          player={p}
          playerId={oppIds[idx]}
          size={opponents.length > 1 ? 'sm' : 'md'}
          treasures={treasures[idx]}
          adventure={adventure}
          onInspect={onInspect}
          onHover={onHover}
        />
      ))}
    </div>
  );
}
