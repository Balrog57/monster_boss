// TownPanel.jsx - Town column + player's entrance box.
import React from 'react';
import { PHASE, treasureIcon, TREASURE_NAMES } from '../../cardData.js';
import Card from './Card.jsx';
import s from './TownPanel.module.css';

// Hero card with its treasure-type icon overlaid (APK shows a small treasure
// badge on every hero so you can tell at a glance which dungeon lures them).
function HeroCard({ hero, onInspect }) {
  return (
    <div className={s.heroWrap}>
      <Card card={hero} kind={hero.epic ? 'epic-hero' : 'hero'} size="sm" onInspect={onInspect} />
      <img
        className={s.treasureIcon}
        src={treasureIcon(hero.treasure)}
        alt={TREASURE_NAMES[hero.treasure] || ''}
        title={TREASURE_NAMES[hero.treasure]}
        loading="lazy"
      />
      {hero.epic && <span className={s.epicBadge}>ÉPIQUE</span>}
    </div>
  );
}

export default function TownPanel({ me, town, phase, isMyTurn, onResolve, onInspect }) {
  return (
    <div className={s.col} aria-label="Ville et votre entrée">
      {me.entrance.length > 0 && (
        <div className={s.entranceBox}>
          <div className={s.entranceHeader}>
            <span className={s.entranceLabel}>À VOTRE ENTRÉE</span>
            {phase === PHASE.ADVENTURE && isMyTurn && (
              <button className={s.resolveBtn} onClick={onResolve} type="button">
                ▶ Résoudre
              </button>
            )}
          </div>
          <div className={s.entranceRow}>
            {me.entrance.map((h, i) => (
              <div key={`ent-${h.id}-${i}`} style={{ marginRight: -20 }}>
                <HeroCard hero={h} onInspect={onInspect} />
              </div>
            ))}
          </div>
        </div>
      )}
      <div className={s.townBox}>
        <div className={s.townHeader}>
          <span className={s.townTitle}>🏰 VILLE</span>
          <span className={s.townCount} aria-label={`${town.length} héros en ville`}>{town.length}</span>
        </div>
        <div className={s.townRow}>
          {town.length === 0 && <div className={s.empty}>Aucun héros en ville</div>}
          {town.map((h, i) => (
            <div key={`town-${h.id}-${i}`} style={{ marginRight: -20 }}>
              <HeroCard hero={h} onInspect={onInspect} />
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}