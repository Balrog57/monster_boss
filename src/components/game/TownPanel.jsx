// TownPanel.jsx - Left APK column: HEROES IN TOWN + items.
import React from 'react';
import { PHASE, treasureIcon, TREASURE_NAMES } from '../../cardData.js';
import Card from './Card.jsx';
import s from './TownPanel.module.css';

function HeroCard({ hero, onInspect }) {
  return (
    <div className={s.heroWrap}>
      <Card card={hero} kind={hero.epic ? 'epic-hero' : 'hero'} size="xs" onInspect={onInspect} />
      <img
        className={s.treasureIcon}
        src={treasureIcon(hero.treasure)}
        alt={TREASURE_NAMES[hero.treasure] || ''}
        title={TREASURE_NAMES[hero.treasure]}
      />
      {hero.item && (
        <div className={s.attachedItem} title={hero.item.name}>
          <Card card={hero.item} kind="item" size="xs" onInspect={onInspect} />
        </div>
      )}
    </div>
  );
}

export default function TownPanel({ me, playerId, town, townItems = [], phase, isMyTurn, adventure, onResolve, onInspect }) {
  const showGo = phase === PHASE.ADVENTURE && isMyTurn && !adventure?.pause && (
    me.entrance.length > 0 || (adventure && String(adventure.playerId) === String(playerId))
  );
  return (
    <div className={s.col} aria-label="Heroes in town">
      <div className={s.townCol}>
        {town.map((h, i) => (
          <HeroCard key={`town-${h.id}-${i}`} hero={h} onInspect={onInspect} />
        ))}
        {townItems.map((it, i) => (
          <div key={`item-${it.id}-${i}`} className={s.itemWrap} title={it.name}>
            <Card card={it} kind="item" size="xs" onInspect={onInspect} />
          </div>
        ))}
      </div>
      {showGo && (
        <button className={s.resolveBtn} onClick={onResolve} type="button" aria-label="Continue adventure" />
      )}
    </div>
  );
}
