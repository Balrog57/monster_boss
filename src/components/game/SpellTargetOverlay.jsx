// SpellTargetOverlay.jsx - Targeting overlay for spells that require a choice.
//
// Shown when a player plays a spell that needs a target (room, hero, opponent).
// Renders clickable targets and calls onConfirm(target) or onCancel().
import React from 'react';
import Card from './Card.jsx';
import s from './SpellTargetOverlay.module.css';

// Spell targeting requirements.
// type: 'own-room-trap' | 'own-room-monster' | 'any-room' | 'hero-entrance' |
//        'hero-own-entrance' | 'hero-town' | 'opponent'
export const SPELL_TARGETS = {
  BMA040: { type: 'own-room-trap', label: 'Choisissez une salle Piège' },
  BMA047: { type: 'own-room-monster', label: 'Choisissez une salle Monstre' },
  BMA046: { type: 'any-room', label: 'Choisissez une salle à geler' },
  BMA041: { type: 'hero-entrance', label: 'Choisissez un héros à cibler' },
  BMA044: { type: 'hero-own-entrance', label: 'Choisissez un héros dans votre donjon' },
  BMA045: { type: 'hero-entrance', label: 'Choisissez un héros à renvoyer en ville' },
  BMA051: { type: 'hero-town', label: 'Choisissez un héros en ville' },
  BMA053: { type: 'hero-own-entrance', label: 'Choisissez un héros à téléporter' },
  BMA055: { type: 'opponent', label: 'Choisissez un adversaire' },
};

export function spellNeedsTarget(spellId) {
  return !!SPELL_TARGETS[spellId];
}

export default function SpellTargetOverlay({ spell, G, me, playerID, onConfirm, onCancel }) {
  const req = SPELL_TARGETS[spell.id];
  if (!req) return null;

  const targets = getTargets(req.type, G, me, playerID);

  return (
    <div className={s.overlay} role="dialog" aria-label={req.label}>
      <div className={s.panel}>
        <div className={s.header}>
          <span className={s.spellName}>{spell.name}</span>
          <span className={s.label}>{req.label}</span>
        </div>
        <div className={s.targets}>
          {targets.length === 0 && (
            <div className={s.empty}>Aucune cible valide</div>
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
          ✕ Annuler
        </button>
      </div>
    </div>
  );
}

function getTargets(type, G, me, playerID) {
  const targets = [];
  const pid = Number(playerID);

  switch (type) {
    case 'own-room-trap': {
      me.dungeon.forEach((stack, i) => {
        const r = Array.isArray(stack) ? stack[stack.length - 1] : stack;
        if (r && r.type === 'trap') {
          targets.push({ key: `room-${i}`, card: r, kind: 'room', value: { roomIndex: i }, label: r.name });
        }
      });
      break;
    }
    case 'own-room-monster': {
      me.dungeon.forEach((stack, i) => {
        const r = Array.isArray(stack) ? stack[stack.length - 1] : stack;
        if (r && r.type === 'monster') {
          targets.push({ key: `room-${i}`, card: r, kind: 'room', value: { roomIndex: i }, label: r.name });
        }
      });
      break;
    }
    case 'any-room': {
      for (const [opid, op] of Object.entries(G.players)) {
        op.dungeon.forEach((stack, i) => {
          const r = Array.isArray(stack) ? stack[stack.length - 1] : stack;
          if (r) {
            const owner = Number(opid) === pid ? 'Vous' : `J${opid}`;
            targets.push({
              key: `room-${opid}-${i}`, card: r, kind: 'room',
              value: { targetPlayerId: Number(opid), roomIndex: i },
              label: `${r.name} (${owner})`
            });
          }
        });
      }
      break;
    }
    case 'hero-entrance': {
      for (const [opid, op] of Object.entries(G.players)) {
        op.entrance.forEach((h, i) => {
          targets.push({
            key: `hero-${opid}-${i}`, card: h, kind: h.epic ? 'epic-hero' : 'hero',
            value: { heroId: h.id || h.name },
            label: h.name
          });
        });
      }
      break;
    }
    case 'hero-own-entrance': {
      me.entrance.forEach((h, i) => {
        targets.push({
          key: `hero-${i}`, card: h, kind: h.epic ? 'epic-hero' : 'hero',
          value: { heroId: h.id || h.name },
          label: h.name
        });
      });
      break;
    }
    case 'hero-town': {
      G.town.forEach((h, i) => {
        targets.push({
          key: `town-${i}`, card: h, kind: h.epic ? 'epic-hero' : 'hero',
          value: { townIndex: i },
          label: h.name
        });
      });
      break;
    }
    case 'opponent': {
      for (const [opid, op] of Object.entries(G.players)) {
        if (Number(opid) === pid || op.eliminated) continue;
        targets.push({
          key: `opp-${opid}`, card: op.boss, kind: 'boss',
          value: { targetPlayerId: Number(opid) },
          label: op.boss?.name || `Joueur ${opid}`
        });
      }
      break;
    }
  }
  return targets;
}
