// StatsSidebar.jsx - Right APK HUD: names, wounds/souls, treasures, decks, Level Up.
import React from 'react';
import { countVisibleRooms } from '../../engine.js';
import { getCardImage } from '../../cardData.js';
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

function PlayerBlock({ player, treasures, active, compact, onInspect }) {
  if (!player?.boss) return null;
  const portrait = getCardImage(player.boss.id, 'boss');
  return (
    <div className={`${s.block} ${active ? s.active : ''}`}>
      <button
        className={s.nameBtn}
        type="button"
        onClick={onInspect ? () => onInspect({ card: player.boss, kind: 'boss' }) : undefined}
      >
        {portrait && <img src={portrait} alt="" className={s.portrait} />}
        <div className={s.nameWrap}>
          <div className={s.name}>{player.boss.name}</div>
          <div className={s.title}>{BOSS_TITLES[player.boss.id] || player.boss.subtitle || ''}</div>
        </div>
      </button>
      <SoulWoundPiles souls={player.souls} wounds={player.wounds} />
      <TreasureReadout counts={treasures || {}} compact={compact} />
    </div>
  );
}

export default function StatsSidebar({
  me, opponents, oppIds = [], myTreasures, oppTreasures, decks, activePid, meId, onInspect, onLevelUp,
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
        />
        <div className={s.soulsLabel}>SOULS</div>
      </div>

      <button
        className={`${s.levelUp} ${me.leveledUp ? s.levelUpDone : ''} ${canLevel ? s.levelUpReady : ''}`}
        type="button"
        onClick={onLevelUp}
        aria-label="Level Up"
      />
    </aside>
  );
}
