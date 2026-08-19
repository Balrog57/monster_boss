// Hand.jsx - Bottom APK strip with ROOMS / SPELLS tabs.
import React, { useState } from 'react';
import { PHASE, spellAllowedInPhase, canPlaySpell } from '../../cardData.js';
import { countVisibleRooms } from '../../engine.js';
import Card from './Card.jsx';
import s from './Hand.module.css';

export default function Hand({ me, phase, isMyTurn, selectedCard, onSelect, onBuild, onBuildInitial, onSpell, onPass, onInspect, showPass = true, stackLength = 0 }) {
  const [tab, setTab] = useState('rooms');
  const rooms = me.hand.map((c, i) => ({ c, i })).filter(({ c }) => c.isRoom);
  const spells = me.hand.map((c, i) => ({ c, i })).filter(({ c }) => c.isSpell);
  const shown = tab === 'rooms' ? rooms : spells;

  return (
    <div className={s.panel} aria-label="Hand">
      <div className={s.tabs}>
        <button
          type="button"
          className={`${s.tab} ${tab !== 'rooms' ? s.tabOff : ''}`}
          onClick={() => setTab('rooms')}
          aria-label="Rooms"
          aria-pressed={tab === 'rooms'}
        />
        <button
          type="button"
          className={`${s.tab} ${s.tabSpells} ${tab !== 'spells' ? s.tabOff : ''}`}
          onClick={() => setTab('spells')}
          aria-label="Spells"
          aria-pressed={tab === 'spells'}
        />
      </div>
      <div className={s.row}>
        {shown.map(({ c, i }) => {
          const canBuildRoom = phase === PHASE.SETUP ? (c.isRoom && !c.advanced) : c.isRoom;
          const canBuild = isMyTurn && canBuildRoom && (phase === PHASE.BUILD || phase === PHASE.SETUP);
          const canSpell = isMyTurn && c.isSpell && canPlaySpell(c, phase, stackLength);
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
              aria-label={c.name}
              type="button"
            >
              <Card
                card={c}
                kind={c.isRoom ? 'room' : 'spell'}
                size="md"
                selected={selectedCard === i}
                onInspect={onInspect}
                dim={!canBuild && !canSpell}
              />
            </button>
          );
        })}
      </div>
      {showPass && isMyTurn && phase !== PHASE.BOSS && (
        <button
          className={phase === PHASE.ADVENTURE ? s.doneBtn : s.passBtn}
          onClick={() => { onSelect(null); onPass(); }}
          type="button"
          aria-label={phase === PHASE.ADVENTURE ? 'Done' : 'Pass'}
        />
      )}
    </div>
  );
}
