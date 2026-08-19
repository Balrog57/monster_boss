// DungeonTrack.jsx - One dungeon row: empty entrance (left) → rooms packed
// against the boss (right) → boss sprite. Matches the APK 2.2.6 board.
import React, { useEffect, useRef, useState } from 'react';
import { PHASE, bossTheme } from '../../cardData.js';
import { allActiveRooms } from '../../engine.js';
import Card from './Card.jsx';
import BossPortrait from './BossPortrait.jsx';
import TreasureReadout from './TreasureReadout.jsx';
import s from './DungeonTrack.module.css';

const SLOTS = 5;
const ACTIVATED_ROOMS = new Set([
  'BMA009', 'BMA013', 'BMA025', 'BMA027', 'BMA028',
  'BMA030', 'BMA032', 'BMA038', 'BMA039',
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
  paddedBottom = false,
  adventure = null,
  treasures = {},
}) {
  const theme = bossTheme(player.boss);
  const dungeon = player.dungeon || [];
  const offset = SLOTS - dungeon.length;
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
          {Array.from({ length: SLOTS }, (_, i) => {
            const di = i - offset;
            if (di < 0) {
              return <div key={`empty-${i}`} className={s.empty} aria-hidden="true" />;
            }
            const stack = dungeon[di];
            const r = Array.isArray(stack) ? stack[stack.length - 1] : stack;
            if (!r) return <div key={`empty-${i}`} className={s.empty} aria-hidden="true" />;
            const stackDepth = Array.isArray(stack) ? stack.length : 1;
            const hasAbility = ACTIVATED_ROOMS.has(r.id);
            const isSource = activateSourceRoom === di;
            const isTargetCandidate = activateSourceRoom != null && di !== activateSourceRoom;
            const canTarget = isMine && phase === PHASE.BUILD && isMyTurn && activateSourceRoom == null;
            const inThisDungeon = adventure && String(adventure.playerId) === String(playerId);
            const showHeroes = (di === 0 && entranceHeroes.length > 0 && !inThisDungeon)
              || (inThisDungeon && (adventure.roomIndex === di || (adventure.roomIndex < 0 && di === 0)));
            return (
              <div
                key={`room-${r.id}-${di}`}
                className={`${s.slot} ${isSource ? s.source : ''} ${isTargetCandidate ? s.target : ''}`}
              >
                <Card
                  card={r}
                  kind="room"
                  size={size}
                  faceDown={!!r.faceDown}
                  selected={selectedCard === di || isSource}
                  onInspect={onInspect}
                  onClick={canTarget ? () => onSelectTarget(di) : isTargetCandidate ? () => onActivateRoom(activateSourceRoom, di) : undefined}
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
