// DarkHeroPayOverlay.jsx - Pay a Dark Hero (+3 HP) by discarding a matching Room.
import React from 'react';
import Card from './Card.jsx';
import s from './SpellTargetOverlay.module.css';

export default function DarkHeroPayOverlay({ room, targets, onConfirm, onCancel }) {
  if (!room || !targets?.length) return null;

  return (
    <div className={s.overlay} role="dialog" aria-label="Pay Dark Hero">
      <div className={s.panel}>
        <div className={s.header}>
          <span className={s.spellName}>Dark Hero</span>
          <span className={s.label}>Discard {room.name} — choose a Dark Hero to empower (+3 HP)</span>
        </div>
        <div className={s.targets}>
          {targets.map((t, i) => (
            <button
              key={`${t.kind}-${t.ownerId}-${t.index ?? 'adv'}`}
              className={s.targetBtn}
              type="button"
              onClick={() => onConfirm(t)}
              title={t.label}
            >
              {t.hero ? (
                <Card card={t.hero} kind={t.hero.epic ? 'epic-hero' : 'hero'} size="sm" />
              ) : null}
              <span className={s.targetLabel}>{t.label}</span>
            </button>
          ))}
        </div>
        <button className={s.cancelBtn} onClick={onCancel} type="button">
          Cancel
        </button>
      </div>
    </div>
  );
}
