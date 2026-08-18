// MyDungeon.jsx - Player dungeon track (entrance left, boss right).
import React from 'react';
import DungeonTrack from './DungeonTrack.jsx';

export default function MyDungeon({
  me, phase, isMyTurn, selectedCard, onSelectTarget, onInspect, onActivateRoom, activateSourceRoom,
}) {
  return (
    <DungeonTrack
      player={me}
      size="md"
      isMine
      phase={phase}
      isMyTurn={isMyTurn}
      selectedCard={selectedCard}
      activateSourceRoom={activateSourceRoom}
      onSelectTarget={onSelectTarget}
      onActivateRoom={onActivateRoom}
      onInspect={onInspect}
      paddedBottom
    />
  );
}
