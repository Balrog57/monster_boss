// TownPanel.jsx - Left APK column: HEROES IN TOWN.
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
    </div>
  );
}

export default function TownPanel({ me, town, phase, isMyTurn, onResolve, onInspect }) {
  return (
    <div className={s.col} aria-label="Héros en ville">
      <img
        src={town.some((h) => h.epic) ? '/ui/ingame/epic_heroes_in_town_top.png' : '/ui/ingame/heroes_in_town_top.png'}
        alt="Heroes in Town"
        className={s.banner}
      />
      <div className={s.townCol}>
        {town.map((h, i) => (
          <HeroCard key={`town-${h.id}-${i}`} hero={h} onInspect={onInspect} />
        ))}
      </div>
      {me.entrance.length > 0 && phase === PHASE.ADVENTURE && isMyTurn && (
        <button className={s.resolveBtn} onClick={onResolve} type="button" aria-label="Résoudre le héros" />
      )}
    </div>
  );
}
