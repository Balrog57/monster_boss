// SpellTargetOverlay.jsx - Targeting overlay for spells that require a choice.
import React from 'react';
import Card from './Card.jsx';
import { SPELL_TARGETS, getSpellTargetOptions, spellNeedsTarget } from '../../spellTargeting.js';
import s from './SpellTargetOverlay.module.css';

export { spellNeedsTarget };

export default function SpellTargetOverlay({ spell, G, me, playerID, onConfirm, onCancel }) {
  const req = SPELL_TARGETS[spell.id];
  if (!req) return null;

  const targets = getSpellTargetOptions(req.type, G, me, playerID);

  return (
    <div className={s.overlay} role="dialog" aria-label={req.label}>
      <div className={s.panel}>
        <div className={s.header}>
          <span className={s.spellName}>{spell.name}</span>
          <span className={s.label}>{req.label}</span>
        </div>
        <div className={s.targets}>
          {targets.length === 0 && (
            <div className={s.empty}>No valid targets</div>
          )}
          {targets.map((t) => (
            <button
              key={t.key}
              className={s.targetBtn}
              onClick={() => onConfirm(t.value)}
              type="button"
              title={t.label}
            >
              {t.card ? (
                <Card card={t.card} kind={t.kind} size="sm" />
              ) : (
                <span className={s.targetLabel}>{t.label}</span>
              )}
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
