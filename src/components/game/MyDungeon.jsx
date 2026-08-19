// MyDungeon.jsx - Player dungeon track (entrance left, boss right).
import React from 'react';
import DungeonTrack from './DungeonTrack.jsx';

export default function MyDungeon({
  me, playerId, phase, isMyTurn, selectedCard, onSelectTarget, onInspect, onActivateRoom, activateSourceRoom, adventure, treasures,
}) {
  return (
    <DungeonTrack
      player={me}
      playerId={playerId}
      size="md"
      isMine
      phase={phase}
      isMyTurn={isMyTurn}
      selectedCard={selectedCard}
      activateSourceRoom={activateSourceRoom}
      onSelectTarget={onSelectTarget}
      onActivateRoom={onActivateRoom}
      onInspect={onInspect}
      adventure={adventure}
      treasures={treasures}
    />
  );
}
