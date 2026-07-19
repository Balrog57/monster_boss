// Hand.jsx - The player's hand strip + pass action.
import React from 'react';
import { PHASE } from '../../cardData.js';
import { countVisibleRooms } from '../../engine.js';
import Card from './Card.jsx';
import s from './Hand.module.css';

export default function Hand({ me, phase, isMyTurn, selectedCard, onSelect, onBuild, onBuildInitial, onSpell, onPass, onInspect }) {
  return (
    <div className={s.panel} aria-label="Votre main">
      <div className={s.header}>
        <span className={s.title}>Votre Main ({me.hand.length})</span>
        {isMyTurn && phase !== PHASE.BOSS && (
          <button className={s.passBtn} onClick={() => { onSelect(null); onPass(); }} type="button">
            ⏭ Passer
          </button>
        )}
        {selectedCard != null && (
          <span className={s.hint}>
            Cliquez sur une salle du donjon (avancée) ou sur + (ordinaire)
          </span>
        )}
      </div>
      <div className={s.row}>
        {me.hand.length === 0 && <div className={s.empty}>Main vide</div>}
        {me.hand.map((c, i) => {
          // SETUP: only non-advanced rooms. BUILD: any room (advanced rooms
          // are built over existing stacks via the select-then-target flow).
          const canBuildRoom = phase === PHASE.SETUP
            ? (c.isRoom && !c.advanced)
            : c.isRoom;
          const canBuild = isMyTurn && canBuildRoom && (phase === PHASE.BUILD || phase === PHASE.SETUP);
          const canSpell = isMyTurn && c.isSpell;
          return (
            <button
              key={`hand-${c.id}-${i}`}
              className={s.cardBtn}
              disabled={!canBuild && !canSpell}
              onClick={() => {
                if (canBuild && (phase === PHASE.BUILD || phase === PHASE.SETUP)) {
                  if (phase === PHASE.SETUP) {
                    onBuildInitial(i);
                  } else if (c.advanced || countVisibleRooms(me.dungeon) >= 5) {
                    onSelect(i);
                  } else {
                    onBuild(i);
                    onSelect(null);
                  }
                } else if (canSpell) {
                  onSpell(i);
                }
              }}
              title={c.name}
              aria-label={c.name + (canBuild || canSpell ? '' : ' (non jouable)')}
              type="button"
            >
              <Card
                card={c}
                kind={c.isRoom ? 'room' : c.isSpell ? 'spell' : 'hero'}
                size="md"
                selected={selectedCard === i}
                onInspect={onInspect}
                dim={!canBuild && !canSpell}
                style={{ marginRight: -30 }}
              />
            </button>
          );
        })}
      </div>
    </div>
  );
}