// TownPanel.jsx - Left APK column: HEROES IN TOWN + items.
import React from 'react';
import { PHASE, treasureIcon, TREASURE_NAMES } from '../../../backend/game/cardData.js';
import Card from './Card.jsx';
import s from './TownPanel.module.css';

function HeroCard({ hero, index, onInspect, onHover, targetable = false, onSelect }) {
  return (
    <div className={targetable ? `${s.heroWrap} ${s.heroTarget}` : s.heroWrap}>
      {targetable && (
        <button
          type="button"
          className={s.heroHit}
          aria-label={`Choose ${hero.name}`}
          onClick={() => onSelect(index)}
        />
      )}
      <Card
        card={hero}
        kind={hero.epic ? 'epic-hero' : 'hero'}
        size="xs"
        onInspect={onInspect}
        onHover={onHover}
      />
      <img
        className={s.treasureIcon}
        src={treasureIcon(hero.treasure)}
        alt={TREASURE_NAMES[hero.treasure] || ''}
        title={TREASURE_NAMES[hero.treasure]}
      />
      {hero.item && (
        <div className={s.attachedItem} title={hero.item.name}>
          <Card card={hero.item} kind="item" size="xs" onInspect={onInspect} onHover={onHover} />
        </div>
      )}
    </div>
  );
}

export default function TownPanel({ me, playerId, town, townItems = [], phase, isMyTurn, adventure, hasPendingChoice = false, targetable = false, onHeroSelect, onResolve, onInspect, onHover }) {
  const showGo = !hasPendingChoice && phase === PHASE.ADVENTURE && isMyTurn && !adventure?.pause && (
    me.entrance.length > 0 || (adventure && String(adventure.playerId) === String(playerId))
  );
  return (
    <div className={s.col} aria-label="Heroes in town">
      <div className={s.townCol}>
        {town.map((h, i) => (
          <HeroCard
            key={`town-${h.id}-${i}`}
            hero={h}
            index={i}
            targetable={targetable}
            onSelect={onHeroSelect}
            onInspect={onInspect}
            onHover={onHover}
          />
        ))}
        {townItems.map((it, i) => (
          <div key={`item-${it.id}-${i}`} className={s.itemWrap} title={it.name}>
            <Card card={it} kind="item" size="xs" onInspect={onInspect} onHover={onHover} />
          </div>
        ))}
      </div>
      {showGo && (
        <button className={s.resolveBtn} onClick={onResolve} type="button" aria-label="Continue adventure" />
      )}
    </div>
  );
}
