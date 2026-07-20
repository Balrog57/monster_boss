// LevelUpChoiceOverlay.jsx - Overlay for level-up choices (BMA001, BMA004, BMA005, BMA022).
//
// Displayed when G.pendingChoice is set and the choice belongs to the human player.
// Shows the available options (cards or rooms) and lets the player pick one.
import React from 'react';
import { getCardImage } from '../../cardData.js';
import s from './LevelUpChoiceOverlay.module.css';

export default function LevelUpChoiceOverlay({ choice, onResolve }) {
  if (!choice || !choice.options || choice.options.length === 0) return null;

  const isRoomChoice = choice.type === 'destroy-room';

  return (
    <div className={s.overlay}>
      <div className={s.panel}>
        <div className={s.header}>
          <span className={s.bossName}>{choice.bossName} — Level Up!</span>
          <span className={s.message}>{choice.message}</span>
        </div>

        <div className={s.options}>
          {choice.options.map((opt, i) => {
            if (isRoomChoice) {
              const room = opt.room;
              return (
                <button key={i} className={s.roomOption} onClick={() => onResolve(i)}>
                  <img
                    className={s.cardImg}
                    src={getCardImage(room?.id, room?.type === 'trap' ? 'trap' : 'room')}
                    alt={room?.name}
                    onError={(e) => { e.currentTarget.style.display = 'none'; }}
                  />
                  <span className={s.roomName}>{room?.name || `Room ${opt.roomIndex + 1}`}</span>
                  <span className={s.roomDamage}>⚔ {room?.damage || 0} | 🛡 {room?.hp || '—'}</span>
                </button>
              );
            }

            // Card-based choices (discard-spell, steal-card)
            const card = opt.card;
            const kind = card?.isSpell ? 'spell' : card?.isRoom ? (card.type === 'trap' ? 'trap' : 'room') : 'boss';
            return (
              <button key={i} className={s.optionCard} onClick={() => onResolve(i)}>
                <img
                  className={s.cardImg}
                  src={getCardImage(card?.id, kind)}
                  alt={card?.name}
                  onError={(e) => { e.currentTarget.style.display = 'none'; }}
                />
                <span className={s.cardName}>{card?.name || 'Unknown'}</span>
                <span className={s.cardMeta}>
                  {card?.isSpell ? 'Spell' : card?.isRoom ? `Room (${card.type})` : ''}
                  {card?.damage ? ` | ⚔${card.damage}` : ''}
                </span>
              </button>
            );
          })}
        </div>
      </div>
    </div>
  );
}
