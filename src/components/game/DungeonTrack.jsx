// DungeonTrack.jsx - One dungeon row: 5 ghost slots, rooms packed against the
// boss (right). Matches APK 2.2.6: tap a selected hand room, then tap a slot.
import React, { useEffect, useRef, useState } from 'react';
import { PHASE, bossTheme } from '../../cardData.js';
import { allActiveRooms, DUNGEON_SLOTS, extendVisualIndex, dungeonIndexFromVisual } from '../../engine.js';
import Card from './Card.jsx';
import BossPortrait from './BossPortrait.jsx';
import TreasureReadout from './TreasureReadout.jsx';
import s from './DungeonTrack.module.css';

export default function DungeonTrack({
  player,
  playerId,
  size = 'md',
  isMine = false,
  phase,
  isMyTurn = false,
  selectedCard = null,
  activateSourceRoom = null,
  roomAbilityMoves = [],
  onSelectTarget,
  onActivateRoom,
  onInspect,
  onHover,
  paddedBottom = false,
  adventure = null,
  treasures = {},
  buildTargets = null,
  minibossActions = null,
  onBuildMiniboss,
  onPromoteMiniboss,
  onActivateMiniboss,
}) {
  const theme = bossTheme(player.boss);
  const dungeon = player.dungeon || [];
  const rooms = allActiveRooms(dungeon);
  const damage = rooms.reduce((n, r) => n + (r?.damage || 0), 0);
  const canActivate = isMine && (phase === PHASE.BUILD || phase === PHASE.ADVENTURE);
  const bossIdLower = String(player.boss?.id || '').toLowerCase();
  const HAS_DUNGEON_BG = new Set([
    'bma001', 'bma002', 'bma003', 'bma004', 'bma005', 'bma006', 'bma007', 'bma008',
    'ksa001', 'ksa002', 'ksa003', 'ksa004', 'ksa005', 'ksa006', 'ksa007',
  ]);
  const dungeonBg = HAS_DUNGEON_BG.has(bossIdLower)
    ? `/ui/dungeon/${bossIdLower}_bg.webp`
    : '/ui/dungeon/bma001_bg.webp';

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

  const [dragOverSlot, setDragOverSlot] = useState(null);
  const entranceHeroes = player.entrance || [];
  const extendVis = extendVisualIndex(dungeon);
  const placing = isMine && isMyTurn && selectedCard != null && activateSourceRoom == null
    && (phase === PHASE.BUILD || phase === PHASE.SETUP);
  const selectedHandCard = (isMine && selectedCard != null && player.hand) ? player.hand[selectedCard] : null;

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
        <img
          src={`${dungeonBg}?v=etc1`}
          alt=""
          className={s.bgImg}
          draggable={false}
          onError={(e) => { e.currentTarget.style.display = 'none'; }}
        />
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
              const isDragOver = dragOverSlot === `empty-${i}`;
              return (
                <button
                  key={`empty-${i}`}
                  type="button"
                  className={`${s.empty} ${canPlace ? s.emptyValid : ''} ${isDragOver ? s.dropHover : ''}`}
                  disabled={!canPlace}
                  onClick={canPlace ? () => onSelectTarget(null) : undefined}
                  onDragOver={canPlace ? (e) => {
                    e.preventDefault();
                    e.dataTransfer.dropEffect = 'copy';
                    if (dragOverSlot !== `empty-${i}`) setDragOverSlot(`empty-${i}`);
                  } : undefined}
                  onDragLeave={() => {
                    if (dragOverSlot === `empty-${i}`) setDragOverSlot(null);
                  }}
                  onDrop={canPlace ? (e) => {
                    e.preventDefault();
                    setDragOverSlot(null);
                    onSelectTarget(null);
                  } : undefined}
                  title={canPlace && selectedHandCard ? `Construire ${selectedHandCard.name} (+${selectedHandCard.damage || 0} Dégâts)` : undefined}
                  aria-label={canPlace ? 'Build new room here' : 'Empty room slot'}
                >
                  {canPlace && (isDragOver || (placing && isExtend)) && selectedHandCard && (
                    <div className={s.previewBadge}>
                      +{selectedHandCard.damage || 0} DMG
                    </div>
                  )}
                </button>
              );
            }
            const stack = dungeon[di];
            const r = Array.isArray(stack) ? stack[stack.length - 1] : stack;
            const mb = stack?.miniboss;
            if (!r) {
              return <div key={`empty-${i}`} className={s.empty} aria-hidden="true" />;
            }
            const stackDepth = Array.isArray(stack) ? stack.length : 1;
            const hasAbility = roomAbilityMoves.some(m => m.args[0] === di);
            const isSource = activateSourceRoom === di;
            const isTargetCandidate = activateSourceRoom != null && roomAbilityMoves.some(m => m.args[0] === activateSourceRoom && m.args[1] === di);
            const overwriteOk = placing && (buildTargets?.overwrites || []).includes(di);
            const isDragOverRoom = dragOverSlot === `room-${di}`;
            const dmgDiff = selectedHandCard ? (selectedHandCard.damage || 0) - (r.damage || 0) : 0;
            const inThisDungeon = adventure && String(adventure.playerId) === String(playerId);
            const showHeroes = (di === 0 && entranceHeroes.length > 0 && !inThisDungeon)
              || (inThisDungeon && (adventure.roomIndex === di || (adventure.roomIndex < 0 && di === 0)));
            return (
              <div
                key={`room-${r.id}-${di}`}
                className={`${s.slot} ${isSource ? s.source : ''} ${isTargetCandidate || overwriteOk ? s.target : ''} ${overwriteOk ? s.emptyValid : ''} ${isDragOverRoom ? s.dropHover : ''}`}
                onDragOver={overwriteOk ? (e) => {
                  e.preventDefault();
                  e.dataTransfer.dropEffect = 'copy';
                  if (dragOverSlot !== `room-${di}`) setDragOverSlot(`room-${di}`);
                } : undefined}
                onDragLeave={() => {
                  if (dragOverSlot === `room-${di}`) setDragOverSlot(null);
                }}
                onDrop={overwriteOk ? (e) => {
                  e.preventDefault();
                  setDragOverSlot(null);
                  onSelectTarget(di);
                } : undefined}
                title={
                  overwriteOk && selectedHandCard
                    ? `Améliorer avec ${selectedHandCard.name} (${dmgDiff >= 0 ? '+' : ''}${dmgDiff} Dégâts)`
                    : placing && !overwriteOk && selectedHandCard?.advanced
                      ? `Incompatible : ${selectedHandCard.name} nécessite un trésor en commun`
                      : undefined
                }
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
                {overwriteOk && (isDragOverRoom || placing) && selectedHandCard && (
                  <div className={s.previewBadge}>
                    {dmgDiff >= 0 ? `+${dmgDiff}` : dmgDiff} DMG
                  </div>
                )}
                {stackDepth > 1 && <div className={s.stack}>×{stackDepth}</div>}
                {mb && (
                  <button
                    type="button"
                    className={`${s.miniboss} ${mb.faceDown ? s.minibossDown : ''}`}
                    title={mb.faceDown ? 'Face-down Miniboss' : `${mb.card?.name || 'Miniboss'} Lv${mb.level}`}
                    onClick={(e) => {
                      e.stopPropagation();
                      if (mb.card) onInspect?.({ card: mb.card, kind: 'miniboss' });
                    }}
                  >
                    {mb.faceDown ? '?' : `MB${mb.level}`}
                  </button>
                )}
                {isMine && isMyTurn && minibossActions?.build?.includes(di) && (
                  <button
                    type="button"
                    className={s.mbBuild}
                    title="Build Miniboss on this Room"
                    onClick={(e) => { e.stopPropagation(); onBuildMiniboss?.(di); }}
                  >
                    +MB
                  </button>
                )}
                {isMine && isMyTurn && minibossActions?.promote?.includes(di) && (
                  <button
                    type="button"
                    className={s.mbPromote}
                    title="Promote Miniboss (1 Coin)"
                    onClick={(e) => { e.stopPropagation(); onPromoteMiniboss?.(di); }}
                  >
                    ↑
                  </button>
                )}
                {isMine && isMyTurn && minibossActions?.activate?.includes(di) && (
                  <button
                    type="button"
                    className={s.mbActivate}
                    title="Activate Level 3 Miniboss"
                    onClick={(e) => { e.stopPropagation(); onActivateMiniboss?.(di); }}
                  >
                    L3
                  </button>
                )}
                {showHeroes && (
                  <div className={s.heroes} aria-label="Heroes at entrance">
                    {(inThisDungeon && adventure.hero ? [adventure.hero] : entranceHeroes).slice(0, 3).map((h, hi) => (
                      <div key={`ent-${h.id}-${hi}`} className={s.heroWrap}>
                        {inThisDungeon && adventure.hp != null && (
                          <div className={s.heroHpBadge} title={`Hero Health: ${adventure.hp}`}>
                            <span className={s.heroHpText}>{adventure.hp}</span>
                          </div>
                        )}
                        <Card
                          card={h}
                          kind={h.epic ? 'epic-hero' : 'hero'}
                          size="xs"
                          onInspect={onInspect}
                          onHover={onHover}
                        />
                      </div>
                    ))}
                  </div>
                )}
                {hasAbility && canActivate && activateSourceRoom == null && (
                  <button
                    className={s.activateBtn}
                    onClick={(e) => { e.stopPropagation(); onActivateRoom(di, null); }}
                    title={`Activer: ${r.name}`}
                    aria-label={`Activate ${r.name}`}
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
