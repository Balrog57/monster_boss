// TownPanel.jsx - Town column + player's entrance box.
import React from 'react';
import { PHASE } from '../../cardData.js';
import Card from './Card.jsx';
import s from './TownPanel.module.css';

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
              <Card key={`ent-${i}`} card={h} kind={h.epic ? 'epic-hero' : 'hero'} size="sm" onInspect={onInspect} style={{ marginRight: -20 }} />
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
            <Card
              key={`town-${h.id}-${i}`}
              card={h}
              kind={h.epic ? 'epic-hero' : 'hero'}
              size="sm"
              onInspect={onInspect}
              style={{ marginRight: -20 }}
            />
          ))}
        </div>
      </div>
    </div>
  );
}