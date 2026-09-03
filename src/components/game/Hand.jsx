// Hand.jsx - Bottom APK strip with ROOMS / SPELLS tabs.
// Rooms are selected on tap, then placed on a dungeon slot (never auto-played).
import React, { useState } from 'react';
import { PHASE, canPlaySpell } from '../../cardData.js';
import Card from './Card.jsx';
import s from './Hand.module.css';

export default function Hand({
  me, phase, isMyTurn, canAct = isMyTurn, selectedCard, onSelect, onSpell, onPass, onInspect, onHover,
  showPass = true, stackLength = 0,
}) {
  const [tab, setTab] = useState('rooms');
  const rooms = me.hand.map((c, i) => ({ c, i })).filter(({ c }) => c.isRoom);
  const spells = me.hand.map((c, i) => ({ c, i })).filter(({ c }) => c.isSpell);
  const shown = tab === 'rooms' ? rooms : spells;

  const canPickRoom = isMyTurn && (phase === PHASE.BUILD || phase === PHASE.SETUP);
  const canPickSpell = canAct && (phase === PHASE.BUILD || phase === PHASE.ADVENTURE);

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
          const canBuild = canPickRoom && c.isRoom && (phase === PHASE.SETUP ? !c.advanced : true);
          const canSpell = canPickSpell && c.isSpell && canPlaySpell(c, phase, stackLength);
          const live = canBuild || canSpell;
          return (
            <div key={`hand-${c.id}-${i}`} className={s.cardBtn}>
              <Card
                card={c}
                kind={c.isRoom ? 'room' : 'spell'}
                size="md"
                selected={selectedCard === i}
                onClick={live ? () => {
                  if (canBuild) {
                    onSelect(selectedCard === i ? null : i);
                  } else if (canSpell) {
                    onSelect(null);
                    onSpell(i);
                  }
                } : undefined}
                onInspect={onInspect}
                onHover={onHover}
                dim={!live}
              />
            </div>
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
