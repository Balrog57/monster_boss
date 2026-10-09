// StatsSidebar.jsx - Right APK HUD: names, wounds/souls, treasures, decks, Level Up.
import React from 'react';
import { countVisibleRooms } from '../../../backend/game/engine.js';
import { getCardImage } from '../../../backend/game/cardData.js';
import TreasureReadout, { SoulWoundPiles } from './TreasureReadout.jsx';
import s from './StatsSidebar.module.css';

const BOSS_TITLES = {
  BMA001: 'Hypnotic Vampire',
  BMA002: 'Demon Overlord',
  BMA003: 'Sultan of the Sewers',
  BMA004: 'Angry Robot',
  BMA005: 'Father Brain',
  BMA006: 'Sorceress of Lust',
  BMA007: 'Mother of Mummies',
  BMA008: 'Queen of Snakes',
};

function PlayerBlock({ player, treasures, active, compact, onInspect, onHover }) {
  if (!player?.boss) return null;
  const portrait = getCardImage(player.boss.id, 'boss');
  return (
    <div className={`${s.block} ${active ? s.active : ''}`}>
      <button
        className={s.nameBtn}
        type="button"
        onClick={onInspect ? () => onInspect({ card: player.boss, kind: 'boss' }) : undefined}
        onMouseEnter={onHover && player.boss ? () => onHover({ card: player.boss, kind: 'boss' }) : undefined}
        onMouseLeave={onHover ? () => onHover(null) : undefined}
      >
        {portrait && <img src={portrait} alt="" className={s.portrait} />}
        <div className={s.nameWrap}>
          <div className={s.name}>{player.boss.name}</div>
          <div className={s.title}>{BOSS_TITLES[player.boss.id] || player.boss.subtitle || ''}</div>
        </div>
      </button>
      <SoulWoundPiles souls={player.souls} wounds={player.wounds} />
      {(player.coins || 0) > 0 && (
        <div className={s.coins} title="Coins">
          <span className={s.coinIcon} aria-hidden>◎</span>
          <span>{player.coins}</span>
        </div>
      )}
      {(player.items || []).length > 0 && (
        <div className={s.items}>
          {player.items.map((it, i) => (
            <img
              key={`item-${it.id}-${i}`}
              src={getCardImage(it.id, 'item')}
              alt={it.name}
              title={it.faceDown ? `${it.name} (face-down)` : it.name}
              className={`${s.item} ${it.faceDown ? s.itemDown : ''}`}
              onMouseEnter={onHover ? () => onHover({ card: it, kind: 'item' }) : undefined}
              onMouseLeave={onHover ? () => onHover(null) : undefined}
              onClick={onInspect ? () => onInspect({ card: it, kind: 'item' }) : undefined}
            />
          ))}
        </div>
      )}
      <TreasureReadout counts={treasures || {}} compact={compact} />
    </div>
  );
}

export default function StatsSidebar({
  me, opponents, oppIds = [], myTreasures, oppTreasures, decks, activePid, meId, onInspect, onHover, onLevelUp,
}) {
  const roomN = decks?.rooms?.length ?? 0;
  const spellN = decks?.spells?.length ?? 0;
  const canLevel = countVisibleRooms(me.dungeon) >= 5 && !me.leveledUp;

  return (
    <aside className={s.side} aria-label="Statistics">
      {opponents.map((p, i) => (
        <PlayerBlock
          key={`opp-stat-${i}`}
          player={p}
          treasures={oppTreasures[i]}
          active={String(activePid) === String(oppIds[i])}
          compact
          onInspect={onInspect}
          onHover={onHover}
        />
      ))}

      <div className={s.decks}>
        <div className={s.deck} title="Room deck">
          <img src="/ui/ingame/rooms_icon.webp" alt="" />
          <span>ROOM DECK ×{roomN}</span>
        </div>
        <div className={s.deck} title="Spell deck">
          <img src="/ui/ingame/spells_icon.webp" alt="" />
          <span>SPELL DECK ×{spellN}</span>
        </div>
      </div>

      <div className={s.meWrap}>
        <div className={s.woundsLabel}>WOUNDS</div>
        <PlayerBlock
          player={me}
          treasures={myTreasures}
          active={String(activePid) === String(meId)}
          onInspect={onInspect}
          onHover={onHover}
        />
        <div className={s.soulsLabel}>SOULS</div>
      </div>

      <button
        className={`${s.levelUp} ${me.leveledUp ? s.levelUpDone : ''} ${canLevel ? s.levelUpReady : ''}`}
        type="button"
        onClick={onLevelUp}
        onMouseEnter={onHover && me?.boss ? () => onHover({ card: me.boss, kind: 'boss' }) : undefined}
        onMouseLeave={onHover ? () => onHover(null) : undefined}
        aria-label="Level Up"
      />
    </aside>
  );
}
