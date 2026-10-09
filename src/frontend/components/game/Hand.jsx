// Hand.jsx - Bottom APK strip with ROOMS / SPELLS tabs.
// Rooms are selected on tap, then placed on a dungeon slot (never auto-played).
import React, { useState } from 'react';
import { PHASE, canPlaySpell } from '../../../backend/game/cardData.js';
import Card from './Card.jsx';
import s from './Hand.module.css';

export default function Hand({
  me, phase, isMyTurn, canAct = isMyTurn, selectedCard, onSelect, onSpell, onPass, onInspect, onHover,
  showPass = true, stackLength = 0, activeTab, onTabChange, spellsBlocked = false,
  anySelectable = false, spellSelectable = false,
}) {
  const [internalTab, setInternalTab] = useState('rooms');
  const tab = activeTab !== undefined ? activeTab : internalTab;
  const setTab = onTabChange || setInternalTab;

  const rooms = me.hand.map((c, i) => ({ c, i })).filter(({ c }) => c.isRoom);
  const spells = me.hand.map((c, i) => ({ c, i })).filter(({ c }) => c.isSpell);
  const shown = tab === 'rooms' ? rooms : spells;

  const canPickRoom = isMyTurn && (phase === PHASE.BUILD || phase === PHASE.SETUP);
  const canPickSpell = canAct && !spellsBlocked && (phase === PHASE.BUILD || phase === PHASE.ADVENTURE);

  return (
    <div className={s.panel} aria-label="Hand">
      <div className={s.tabs}>
        <button
          type="button"
          className={`${s.tab} ${tab !== 'rooms' ? s.tabOff : ''}`}
          onClick={() => setTab('rooms')}
          aria-label="Rooms"
          aria-pressed={tab === 'rooms'}
          title="Rooms [R]"
        >
          <span className={s.tabKeyBadge}>R</span>
        </button>
        <button
          type="button"
          className={`${s.tab} ${s.tabSpells} ${tab !== 'spells' ? s.tabOff : ''}`}
          onClick={() => setTab('spells')}
          aria-label="Spells"
          aria-pressed={tab === 'spells'}
          title="Spells [S]"
        >
          <span className={s.tabKeyBadge}>S</span>
        </button>
      </div>
      <div className={s.row}>
        {shown.map(({ c, i }, idx) => {
          const canBuild = canPickRoom && c.isRoom && (phase === PHASE.SETUP ? !c.advanced : true);
          const canSpell = canPickSpell && c.isSpell && canPlaySpell(c, phase, stackLength);
          // Doc Scarecrow may discard any card; Dr. Timebender any Spell, even
          // one that would be illegal to cast right now.
          const armedAny = anySelectable;
          const armedSpell = anySelectable || (spellSelectable && c.isSpell);
          const live = canBuild || canSpell || armedAny || (spellSelectable && c.isSpell);
          return (
            <div
              key={`hand-${c.id}-${i}`}
              className={`${s.cardBtn} ${canBuild ? s.draggable : ''}`}
              draggable={canBuild}
              onDragStart={canBuild ? (e) => {
                e.dataTransfer.setData('text/plain', String(i));
                e.dataTransfer.effectAllowed = 'copyMove';
                onSelect(i);
              } : undefined}
            >
              {idx < 9 && (
                <span className={s.keyBadge} aria-hidden="true">{idx + 1}</span>
              )}
              <Card
                card={c}
                kind={c.isRoom ? 'room' : 'spell'}
                size="md"
                selected={selectedCard === i}
                onClick={live ? () => {
                  if (armedAny) {
                    if (c.isSpell) { onSelect(null); onSpell(i); }
                    else onSelect(selectedCard === i ? null : i);
                    return;
                  }
                  if (armedSpell) { onSelect(null); onSpell(i); return; }
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
        >
          <span className={s.passKeyBadge}>SPACE</span>
        </button>
      )}
    </div>
  );
}
