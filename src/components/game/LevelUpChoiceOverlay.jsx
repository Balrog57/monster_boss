// LevelUpChoiceOverlay.jsx - Overlay for level-up choices (BMA001, BMA004, BMA005, BMA022).
//
// Displayed when G.pendingChoice is set and the choice belongs to the human player.
// Shows the available options (cards or rooms) and lets the player pick one.
import React from 'react';
import { getCardImage } from '../../cardData.js';
import s from './LevelUpChoiceOverlay.module.css';

export default function LevelUpChoiceOverlay({ choice, onResolve }) {
  if (!choice || !choice.options || choice.options.length === 0) return null;

  const isRoomChoice = ['destroy-room', 'swap-rooms', 'build-over', 'deactivate-room', 'rearrange-dungeon'].includes(choice.type);
  const title = choice.bossName || 'Choose';

  return (
    <div className={s.overlay}>
      <div className={s.panel}>
        <div className={s.header}>
          <span className={s.bossName}>{title}</span>
          <span className={s.message}>{choice.message}</span>
        </div>

        <div className={s.options}>
          {choice.options.map((opt, i) => {
            if (opt.label && !opt.card && !opt.room) {
              return (
                <button key={i} className={s.optionCard} onClick={() => onResolve(i)} type="button">
                  <span className={s.cardName}>{opt.label}</span>
                </button>
              );
            }
            if (isRoomChoice) {
              const room = opt.room;
              return (
                <button key={i} className={s.roomOption} onClick={() => onResolve(i)} type="button">
                  <img
                    className={s.cardImg}
                    src={getCardImage(room?.id, 'room')}
                    alt={room?.name}
                    onError={(e) => { e.currentTarget.style.display = 'none'; }}
                  />
                  <span className={s.roomName}>
                    {opt.playerId != null ? `P${Number(opt.playerId) + 1} · ` : ''}
                    {room?.name || `Room ${opt.roomIndex + 1}`}
                  </span>
                  <span className={s.roomDamage}>⚔ {room?.damage || 0}</span>
                </button>
              );
            }

            const card = opt.card;
            const kind = card?.isSpell ? 'spell'
              : (card?.isRoom || card?.type === 'monster' || card?.type === 'trap') ? 'room'
              : (card?.isItem || (card?.treasure != null && card?.xp == null && card?.hp == null)) ? 'item'
              : (card?.hp != null || card?.class) ? (card.epic ? 'epic-hero' : 'hero')
              : 'boss';
            const pileTag = opt.pile === 'discard' ? 'Discard' : opt.pile === 'deck' ? 'Deck' : opt.source === 'town' ? 'Town' : opt.source === 'deck' ? 'Hero deck' : '';
            return (
              <button key={i} className={s.optionCard} onClick={() => onResolve(i)} type="button">
                <img
                  className={s.cardImg}
                  src={getCardImage(card?.id, kind)}
                  alt={card?.name}
                  onError={(e) => { e.currentTarget.style.display = 'none'; }}
                />
                <span className={s.cardName}>{card?.name || opt.label || 'Unknown'}</span>
                <span className={s.cardMeta}>
                  {pileTag ? `${pileTag} · ` : ''}
                  {card?.isSpell ? 'Spell' : card?.isRoom ? `Room (${card.type})` : card?.hp != null ? `HP ${card.hp}` : card?.isItem ? 'Item' : ''}
                  {card?.damage ? ` | ⚔${card.damage}` : ''}
                </span>
              </button>
            );
          })}
        </div>
        {choice.optional && (
          <button className={s.cancelBtn} type="button" onClick={() => onResolve(-1)}>
            Skip
          </button>
        )}
      </div>
    </div>
  );
}
