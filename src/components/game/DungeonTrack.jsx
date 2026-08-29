// DungeonTrack.jsx - One dungeon row: 5 ghost slots, rooms packed against the
// boss (right). Matches APK 2.2.6: tap a selected hand room, then tap a slot.
import React, { useEffect, useRef, useState } from 'react';
import { PHASE, bossTheme } from '../../cardData.js';
import { allActiveRooms, DUNGEON_SLOTS, extendVisualIndex, dungeonIndexFromVisual } from '../../engine.js';
import Card from './Card.jsx';
import BossPortrait from './BossPortrait.jsx';
import TreasureReadout from './TreasureReadout.jsx';
import s from './DungeonTrack.module.css';

const ACTIVATED_ROOMS = new Set([
  'BMA009', 'BMA013', 'BMA024', 'BMA025', 'BMA027', 'BMA028',
  'BMA030', 'BMA032', 'BMA038', 'BMA039',
  'THK021', 'THK022', 'THK023',
]);

export default function DungeonTrack({
  player,
  playerId,
  size = 'md',
  isMine = false,
  phase,
  isMyTurn = false,
  selectedCard = null,
  activateSourceRoom = null,
  onSelectTarget,
  onActivateRoom,
  onInspect,
  onHover,
  paddedBottom = false,
  adventure = null,
  treasures = {},
  buildTargets = null,
}) {
  const theme = bossTheme(player.boss);
  const dungeon = player.dungeon || [];
  const rooms = allActiveRooms(dungeon);
  const damage = rooms.reduce((n, r) => n + (r?.damage || 0), 0);
  const canActivate = isMine && isMyTurn && (phase === PHASE.BUILD || phase === PHASE.ADVENTURE);
  const dungeonBg = player.boss?.id
    ? `/ui/dungeon/${String(player.boss.id).toLowerCase()}_bg.webp`
    : null;

  const [hurt, setHurt] = useState(false);
  const prevWounds = useRef(player.wounds?.length || 0);
  useEffect(() => {
    const w = player.wounds?.length || 0;
    if (w > prevWounds.current) {
      setHurt(true);
      const t = setTimeout(() => setHurt(false), 650);
      prevWounds.current = w;
      return () => clearTimeout(t);
    }
    prevWounds.current = w;
  }, [player.wounds?.length]);

  const entranceHeroes = player.entrance || [];
  const extendVis = extendVisualIndex(dungeon);
  const placing = isMine && isMyTurn && selectedCard != null && activateSourceRoom == null
    && (phase === PHASE.BUILD || phase === PHASE.SETUP);

  return (
    <div
      className={`${s.track} ${paddedBottom ? s.padded : ''} ${isMine ? s.mine : s.opp}`}
      style={{
        '--accent': theme.color,
        '--slot-w': size === 'sm' ? '112px' : '140px',
      }}
      aria-label={`${player.boss?.name || 'Player'} dungeon`}
    >
      {dungeonBg && (
        <img src={`${dungeonBg}?v=etc1`} alt="" className={s.bgImg} draggable={false} />
      )}
      <div className={s.meta}>
        <span className={s.metaItem} title="Dungeon damage">{damage}</span>
        <span className={s.metaXp}>{player.boss?.xp || 0} XP</span>
        <TreasureReadout counts={treasures} compact />
      </div>

      <div className={s.body}>
        <div className={s.rooms}>
          {Array.from({ length: DUNGEON_SLOTS }, (_, i) => {
            const di = dungeonIndexFromVisual(dungeon, i);
            if (di == null) {
              const isExtend = extendVis === i;
              const canPlace = placing && isExtend && (buildTargets?.extend !== false);
              return (
                <button
                  key={`empty-${i}`}
                  type="button"
                  className={`${s.empty} ${canPlace ? s.emptyValid : ''}`}
                  disabled={!canPlace}
                  onClick={canPlace ? () => onSelectTarget(null) : undefined}
                  aria-label={canPlace ? 'Build new room here' : 'Empty room slot'}
                />
              );
            }
            const stack = dungeon[di];
            const r = Array.isArray(stack) ? stack[stack.length - 1] : stack;
            if (!r) {
              return <div key={`empty-${i}`} className={s.empty} aria-hidden="true" />;
            }
            const stackDepth = Array.isArray(stack) ? stack.length : 1;
            const hasAbility = ACTIVATED_ROOMS.has(r.id);
            const isSource = activateSourceRoom === di;
            const isTargetCandidate = activateSourceRoom != null && di !== activateSourceRoom;
            const overwriteOk = placing && (buildTargets?.overwrites || []).includes(di);
            const inThisDungeon = adventure && String(adventure.playerId) === String(playerId);
            const showHeroes = (di === 0 && entranceHeroes.length > 0 && !inThisDungeon)
              || (inThisDungeon && (adventure.roomIndex === di || (adventure.roomIndex < 0 && di === 0)));
            return (
              <div
                key={`room-${r.id}-${di}`}
                className={`${s.slot} ${isSource ? s.source : ''} ${isTargetCandidate || overwriteOk ? s.target : ''} ${overwriteOk ? s.emptyValid : ''}`}
              >
                <Card
                  card={r}
                  kind="room"
                  size={size}
                  faceDown={!!r.faceDown}
                  selected={isSource || overwriteOk}
                  onInspect={onInspect}
                  onHover={onHover}
                  onClick={
                    overwriteOk ? () => onSelectTarget(di)
                      : isTargetCandidate ? () => onActivateRoom(activateSourceRoom, di)
                        : undefined
                  }
                />
                {stackDepth > 1 && <div className={s.stack}>×{stackDepth}</div>}
                {showHeroes && (
                  <div className={s.heroes} aria-label="Heroes at entrance">
                    {(inThisDungeon && adventure.hero ? [adventure.hero] : entranceHeroes).slice(0, 3).map((h, hi) => (
                      <Card
                        key={`ent-${h.id}-${hi}`}
                        card={h}
                        kind={h.epic ? 'epic-hero' : 'hero'}
                        size="xs"
                        onInspect={onInspect}
                        onHover={onHover}
                      />
                    ))}
                  </div>
                )}
                {hasAbility && canActivate && activateSourceRoom == null && (
                  <button
                    className={s.activateBtn}
                    onClick={(e) => { e.stopPropagation(); onActivateRoom(di, null); }}
                    title={`Activer: ${r.name}`}
                    type="button"
                  />
                )}
              </div>
            );
          })}
        </div>
        <div className={`${s.boss} ${hurt ? s.hurt : ''} ${player.leveledUp ? s.leveled : ''}`}>
          <BossPortrait
            boss={player.boss}
            theme={theme}
            size={isMine ? 168 : 140}
            onInspect={onInspect}
            useAvatar
            variant="sprite"
          />
        </div>
      </div>
    </div>
  );
}
