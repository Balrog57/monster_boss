import React, { useState, useEffect, useRef } from 'react';
import {
  BOSSES, ROOMS, SPELLS, HEROES, TREASURE_NAMES, PHASE, getCardImage, bossTheme
} from './cardData.js';
import { playMusic, playSfx, SFX, isMuted, setMuted } from './audio.js';

// ---------------------------------------------------------------------------
// Card component - large, immersive rendering like the Boss Monster APK
// ---------------------------------------------------------------------------
function Card({ card, kind = 'room', faceDown = false, size = 'md', onClick, onInspect, selected = false, dim = false, style = {} }) {
  const src = faceDown
    ? getCardImage('', `back-${kind === 'epic-hero' ? 'hero' : kind}`)
    : getCardImage(card?.id, kind === 'epic-hero' ? 'epic-hero' : kind);
  // Larger sizes to match the APK feel
  const sizes = {
    xs: { w: 56, label: 9 },
    sm: { w: 90, label: 10 },
    md: { w: 130, label: 11 },
    lg: { w: 170, label: 12 },
    xl: { w: 220, label: 14 }
  };
  const s = sizes[size] || sizes.md;
  const ratio = 1.4;
  const h = s.w * ratio;
  return (
    <div
      style={{
        width: s.w,
        height: h,
        borderRadius: 8,
        overflow: 'visible',
        opacity: dim ? 0.45 : 1,
        transition: 'transform 0.15s, box-shadow 0.15s, opacity 0.15s',
        cursor: onClick ? 'pointer' : 'default',
        position: 'relative',
        ...style
      }}
      onClick={onClick}
    >
      <div style={{
        width: '100%', height: '100%', borderRadius: 8, overflow: 'hidden',
        boxShadow: selected
          ? '0 0 0 4px #F59E0B, 0 0 24px rgba(245,158,11,0.6), 0 8px 20px rgba(0,0,0,0.6)'
          : '0 6px 16px rgba(0,0,0,0.6), inset 0 0 0 2px rgba(255,255,255,0.08)',
        background: '#1a0a1a',
        transform: selected ? 'translateY(-8px)' : 'none',
        transition: 'transform 0.15s, box-shadow 0.15s'
      }}>
        {src ? (
          <img
            src={src}
            alt={card?.name || 'card'}
            style={{ width: '100%', height: '100%', objectFit: 'cover', display: 'block', pointerEvents: 'none' }}
            loading="lazy"
            onError={(e) => { e.currentTarget.style.display = 'none'; }}
          />
        ) : (
          <div style={{
            color: '#fff', fontSize: s.label, textAlign: 'center', padding: 6,
            position: 'absolute', inset: 0, display: 'flex', alignItems: 'center', justifyContent: 'center',
            fontWeight: 700
          }}>
            {card?.name || '?'}
          </div>
        )}
      </div>
      {onInspect && card && !faceDown && (
        <span
          onClick={(e) => { e.stopPropagation(); onInspect(card, kind); }}
          style={{
            position: 'absolute', top: -6, right: -6,
            width: 24, height: 24, borderRadius: '50%',
            background: 'linear-gradient(135deg, #FCD34D, #F59E0B)',
            color: '#000', border: '2px solid #1a0a1a', cursor: 'pointer',
            fontSize: 13, lineHeight: '20px', padding: 0, textAlign: 'center',
            fontWeight: 900, userSelect: 'none', zIndex: 5,
            boxShadow: '0 2px 6px rgba(0,0,0,0.5)'
          }}
          title="Inspecter"
        >i</span>
      )}
    </div>
  );
}

// Big boss portrait (the Boss card itself, shown in dungeon)
function BossPortrait({ boss, theme, size = 130, onInspect }) {
  if (!boss) return null;
  const src = getCardImage(boss.id, 'boss');
  return (
    <div
      onClick={() => onInspect && onInspect({ card: boss, kind: 'boss' })}
      style={{
        width: size, height: size * 1.4, borderRadius: 10,
        overflow: 'hidden', flexShrink: 0, cursor: onInspect ? 'pointer' : 'default',
        border: `3px solid ${theme.color}`,
        boxShadow: `0 0 20px ${theme.glow}, 0 8px 20px rgba(0,0,0,0.6)`,
        background: '#0a0a0f',
        position: 'relative'
      }}
      title={boss.name}
    >
      {src && <img src={src} alt={boss.name} style={{ width: '100%', height: '100%', objectFit: 'cover' }} />}
    </div>
  );
}

// ---------------------------------------------------------------------------
// Main board — APK-style landscape layout
// Top:    opponent dungeon (compact)
// Center: town on the right, my dungeon on the left (hero enters from left)
// Bottom: my hand
// HUD:    always on top
// ---------------------------------------------------------------------------
export default function AppBoard({ G, ctx, moves, events, playerID, isActive }) {
  const [inspect, setInspect] = useState(null); // { card, kind }
  const [selectedCard, setSelectedCard] = useState(null);
  const lastPhase = useRef(null);

  useEffect(() => {
    const phase = ctx?.phase || G?.phase;
    if (phase && phase !== PHASE.BOSS && lastPhase.current === null) {
      playMusic('music_dungeon_v3', 0.3);
    }
    lastPhase.current = phase;
  }, [ctx?.phase, G?.phase]);

  if (!G || !G.players) {
    return <div style={S.screen}>Loading…</div>;
  }
  const pidKey = String(playerID);
  const me = G.players[pidKey];
  if (!me) {
    return <div style={S.screen}>Loading… (no player for {pidKey})</div>;
  }
  const phase = ctx.phase || G.phase;
  const activePid = G.activePlayer != null ? String(G.activePlayer) : (ctx.currentPlayer != null ? String(ctx.currentPlayer) : '0');
  const isMyTurn = activePid === pidKey;

  // Boss selection
  if (phase === PHASE.BOSS) {
    return (
      <div style={S.screen}>
        <h1 style={S.title}>Choisissez votre Boss</h1>
        <p style={S.subtitle}>D'autres Boss seront révélés à mesure que vous choisissez</p>
        <div style={S.bossGrid}>
          {G.bossPicks.map(b => {
            const t = bossTheme(b);
            return (
              <button
                key={b.id}
                onClick={() => moves.pickBoss(b.id)}
                style={{ ...S.bossCard, borderColor: t.color, boxShadow: `0 0 24px ${t.glow}` }}
              >
                <Card card={b} kind="boss" size="xl" onInspect={setInspect} onClick={(e) => { e.stopPropagation(); setInspect({ card: b, kind: 'boss' }); }} />
                <div style={{ ...S.bossName, color: t.color }}>{b.name}</div>
                <div style={S.bossMeta}>XP {b.xp} · {b.treasures.map(t => TREASURE_NAMES[t]).join(', ')}</div>
              </button>
            );
          })}
        </div>
        <DetailPanel inspect={inspect} onClose={() => setInspect(null)} />
      </div>
    );
  }

  const opponents = Object.values(G.players).filter(p => p !== me);
  const theme = bossTheme(me.boss);

  return (
    <div style={S.screen}>
      {/* ============= HUD ============= */}
      <div style={S.hud}>
        <div style={{ ...S.phaseBadge, background: isMyTurn ? 'linear-gradient(135deg, #F59E0B, #DC2626)' : 'linear-gradient(135deg, #7C3AED, #5B21B6)' }}>
          {phase.toUpperCase()}
        </div>
        <div style={S.hudLabel}>Tour {G.turn}</div>
        <div style={{ ...S.hudLabel, color: isMyTurn ? '#FCD34D' : '#A1A1AA', fontWeight: 700 }}>
          {isMyTurn ? "▶ À votre tour" : `Joueur ${activePid} joue`}
        </div>
        <div style={S.hudSpacer} />
        <div style={S.hudStat}>
          <img src="/ui/icons/soul.png" width={20} height={20} alt="soul" style={{ verticalAlign: 'middle' }} />
          <span style={{ color: '#FCD34D', fontWeight: 800, marginLeft: 4, fontSize: 16 }}>{me.souls.length}</span>
          <span style={{ margin: '0 8px', color: '#4B5563' }}>·</span>
          <img src="/ui/icons/wound.png" width={20} height={20} alt="wound" style={{ verticalAlign: 'middle' }} />
          <span style={{ color: '#F87171', fontWeight: 800, marginLeft: 4, fontSize: 16 }}>{me.wounds.length}</span>
        </div>
        <div style={S.hudStat}>{me.boss?.name} · {me.boss?.xp} XP</div>
        <div style={S.hudStat}>Donjon {countVisibleRooms(me.dungeon)}/5</div>
        <button style={S.muteBtn} onClick={() => { const m = !isMuted(); setMuted(m); if (!m) playSfx(SFX.BUTTON, 0.4); }} title="Muet">
          {isMuted() ? '🔇' : '🔊'}
        </button>
      </div>

      {/* ============= Opponent row (top) ============= */}
      <div style={S.oppRow}>
        {opponents.map(p => {
          const t = bossTheme(p.boss);
          return (
            <div key={p} style={{ ...S.oppDungeon, borderTop: `3px solid ${t.color}`, background: `linear-gradient(180deg, ${t.glow} 0%, rgba(15,12,22,0.9) 100%)` }}>
              <div style={S.oppHeader}>
                <BossPortrait boss={p.boss} theme={t} size={50} onInspect={setInspect} />
                <div style={{ flex: 1 }}>
                  <div style={{ ...S.oppName, color: t.color }}>{p.boss?.name}</div>
                  <div style={S.oppMeta}>
                    {p.boss?.xp} XP · {p.souls.length} âmes · {p.wounds.length} blessures
                    {p.eliminated && <span style={S.elimTag}> ÉLIMINÉ</span>}
                    {p.leveledUp && <span style={S.levelTag}> LVL UP</span>}
                  </div>
                </div>
              </div>
              <div style={S.oppRooms}>
                {p.dungeon.length === 0 && <div style={S.empty}>Donjon vide</div>}
                {p.dungeon.map((stack, i) => {
                  const r = Array.isArray(stack) ? stack[stack.length - 1] : stack;
                  return (
                    <Card key={`op-${p.boss?.id}-${i}`} card={r} kind="room" size="xs" onInspect={setInspect} style={{ marginRight: -16 }} />
                  );
                })}
              </div>
            </div>
          );
        })}
      </div>

      {/* ============= Main play area ============= */}
      <div style={S.playArea}>
        {/* Left: my dungeon with boss on the right */}
        <div style={S.myDungeonWrap}>
          <div style={S.dungeonHeader}>
            <span style={{ ...S.dungeonTitle, color: theme.color }}>Mon Donjon</span>
            {me.leveledUp && <span style={S.levelTag}>LEVEL UP</span>}
            <span style={S.dungeonSubtitle}>Les héros arrivent par la gauche →</span>
          </div>
          <div style={S.myDungeon}>
            {me.dungeon.length === 0 && (
              <div style={S.dungeonEmpty}>
                {phase === PHASE.SETUP || phase === PHASE.BUILD
                  ? (isMyTurn ? '🃏 Cliquez sur une salle dans votre main' : '⏳ En attente...')
                  : 'Donjon vide'}
              </div>
            )}
            {/* Entrance zone */}
            <div style={S.entranceMarker}>
              <div style={S.entranceLabel}>ENTRÉE</div>
            </div>
            {/* Stacks of rooms (left to right, boss on the rightmost) */}
            <div style={S.roomsRow}>
              {me.dungeon.map((stack, i) => {
                const r = Array.isArray(stack) ? stack[stack.length - 1] : stack;
                const stackDepth = Array.isArray(stack) ? stack.length : 1;
                const canTarget = phase === PHASE.BUILD && isMyTurn && r;
                return (
                  <div key={`room-${i}`} style={S.roomSlot}>
                    <Card
                      card={r}
                      kind="room"
                      size="lg"
                      selected={G.selectedCard === i}
                      onInspect={setInspect}
                      onClick={canTarget ? () => {
                        if (selectedCard != null && selectedCard >= 0) {
                          const c = me.hand[selectedCard];
                          if (c?.isRoom) {
                            moves.buildRoom(selectedCard, i);
                            setSelectedCard(null);
                          }
                        }
                      } : undefined}
                      style={{ position: 'relative', zIndex: i + 1 }}
                    />
                    {stackDepth > 1 && (
                      <div style={S.stackBadge}>×{stackDepth}</div>
                    )}
                  </div>
                );
              })}
              {/* Empty slot for building */}
              {me.dungeon.length < 5 && phase === PHASE.BUILD && isMyTurn && (
                <div style={S.emptySlot} onClick={() => {
                  if (selectedCard != null) {
                    const c = me.hand[selectedCard];
                    if (c?.isRoom && !c.advanced) {
                      moves.buildRoom(selectedCard, null);
                      setSelectedCard(null);
                    }
                  }
                }}>
                  <div style={S.emptySlotPlus}>+</div>
                  <div style={S.emptySlotLabel}>Construire</div>
                </div>
              )}
            </div>
            {/* Boss portrait on the right */}
            <div style={{ display: 'flex', alignItems: 'center', marginLeft: 16 }}>
              <BossPortrait boss={me.boss} theme={theme} size={120} onInspect={setInspect} />
            </div>
          </div>
        </div>

        {/* Right: Town + entrance */}
        <div style={S.townColumn}>
          {/* My entrance */}
          {me.entrance.length > 0 && (
            <div style={S.entranceBox}>
              <div style={S.entranceHeader}>
                <span style={{ color: '#F87171', fontWeight: 800, fontSize: 12, letterSpacing: 1 }}>À VOTRE ENTRÉE</span>
                {phase === PHASE.ADVENTURE && isMyTurn && (
                  <button style={S.btnPrimary} onClick={() => moves.resolveNextHero()}>
                    ▶ Résoudre
                  </button>
                )}
              </div>
              <div style={S.entranceRow}>
                {me.entrance.map((h, i) => (
                  <Card key={`ent-${i}`} card={h} kind={h.epic ? 'epic-hero' : 'hero'} size="sm" onInspect={setInspect} style={{ marginRight: -20 }} />
                ))}
              </div>
            </div>
          )}
          {/* Town */}
          <div style={S.townBox}>
            <div style={S.townHeader}>
              <span style={S.townTitle}>🏰 VILLE</span>
              <span style={S.townCount}>{G.town.length}</span>
            </div>
            <div style={S.townRow}>
              {G.town.length === 0 && <div style={S.empty}>Aucun héros en ville</div>}
              {G.town.map((h, i) => (
                <Card
                  key={`town-${h.id}-${i}`}
                  card={h}
                  kind={h.epic ? 'epic-hero' : 'hero'}
                  size="sm"
                  onInspect={setInspect}
                  style={{ marginRight: -20 }}
                />
              ))}
            </div>
          </div>
        </div>
      </div>

      {/* ============= Hand + actions ============= */}
      <div style={S.handPanel}>
        <div style={S.handHeader}>
          <span style={S.handTitle}>Votre Main ({me.hand.length})</span>
          {isMyTurn && phase !== PHASE.BOSS && (
            <button style={S.btnPass} onClick={() => { setSelectedCard(null); moves.pass(); }}>
              ⏭ Passer
            </button>
          )}
          {selectedCard != null && (
            <span style={S.handHint}>
              Cliquez sur une salle du donjon (avancée) ou sur + (ordinaire)
            </span>
          )}
        </div>
        <div style={S.handRow}>
          {me.hand.length === 0 && <div style={S.empty}>Main vide</div>}
          {me.hand.map((c, i) => {
            const canBuild = isMyTurn && c.isRoom && (phase === PHASE.BUILD || phase === PHASE.SETUP);
            const canSpell = isMyTurn && c.isSpell;
            return (
              <button
                key={`hand-${c.id}-${i}`}
                disabled={!canBuild && !canSpell}
                onClick={() => {
                  if (canBuild && (phase === PHASE.BUILD || phase === PHASE.SETUP)) {
                    if (phase === PHASE.SETUP) {
                      moves.buildInitialRoom(i);
                    } else if (c.advanced || countVisibleRooms(me.dungeon) >= 5) {
                      setSelectedCard(i);
                    } else {
                      moves.buildRoom(i);
                      setSelectedCard(null);
                    }
                  } else if (canSpell) {
                    moves.playSpell(i);
                  }
                }}
                style={S.cardBtn}
                title={c.name}
              >
                <Card
                  card={c}
                  kind={c.isRoom ? 'room' : c.isSpell ? 'spell' : 'hero'}
                  size="md"
                  selected={selectedCard === i}
                  onInspect={setInspect}
                  style={{ marginRight: -30, cursor: (canBuild || canSpell) ? 'pointer' : 'not-allowed' }}
                />
              </button>
            );
          })}
        </div>
      </div>

      {/* ============= Log ============= */}
      <div style={S.logStrip}>
        {G.logs.slice(-5).map((l, i) => (
          <div key={i} style={S.logLine}>{l}</div>
        ))}
      </div>

      <DetailPanel inspect={inspect} onClose={() => setInspect(null)} />
    </div>
  );
}

function countVisibleRooms(dungeon) {
  return dungeon.reduce((n, stack) => n + (Array.isArray(stack) && stack.length > 0 ? 1 : 0), 0);
}

// ---------------------------------------------------------------------------
// Detail panel
// ---------------------------------------------------------------------------
function DetailPanel({ inspect, onClose }) {
  if (!inspect) return null;
  const { card, kind } = inspect;
  const src = getCardImage(card?.id, kind === 'epic-hero' ? 'epic-hero' : kind);
  return (
    <div style={S.detailOverlay} onClick={onClose}>
      <div style={S.detailPanel} onClick={e => e.stopPropagation()}>
        <div style={S.detailHeader}>
          <span style={S.detailTitle}>{card?.name || 'Carte'}</span>
          <button style={S.closeBtn} onClick={onClose}>×</button>
        </div>
        <div style={S.detailImgWrap}>
          {src && <img src={src} alt={card?.name} style={S.detailImg} />}
        </div>
        <div style={S.detailMeta}>
          {card?.type && <div><strong>Type:</strong> {card.type}{card.advanced ? ' (avancée)' : ''}</div>}
          {card?.damage != null && <div><strong>Dégât:</strong> {card.damage}</div>}
          {card?.treasures && <div><strong>Trésor:</strong> {card.treasures.map(t => TREASURE_NAMES[t] || t).join(', ')}</div>}
          {card?.category != null && <div><strong>Catégorie:</strong> {['ANY','BUILD','BAIT','ADVENTURE','BUILD_BAIT','ADV_BUILD'][card.category]}</div>}
          {card?.xp != null && <div><strong>XP:</strong> {card.xp}</div>}
          {card?.hp != null && <div><strong>HP:</strong> {card.hp}</div>}
        </div>
        {card?.description && <div style={S.detailDesc}>{card.description}</div>}
        {card?.levelUpDesc && <div style={S.detailDesc}><em><strong>Level Up:</strong> {card.levelUpDesc}</em></div>}
      </div>
    </div>
  );
}

// ===========================================================================
// Styles — APK-inspired
// ===========================================================================
const S = {
  screen: {
    minHeight: '100vh',
    width: '100vw',
    background: 'radial-gradient(ellipse at center, #1a1025 0%, #06040a 80%)',
    color: '#F3F4F6',
    fontFamily: "'Segoe UI', 'Space Grotesk', sans-serif",
    display: 'flex',
    flexDirection: 'column',
    overflow: 'hidden'
  },
  title: {
    fontSize: 38, fontWeight: 900, textAlign: 'center', margin: '24px 0 8px',
    color: '#E11D48', textShadow: '0 3px 12px rgba(225,29,72,0.5)',
    fontFamily: "'arcadepix', sans-serif"
  },
  subtitle: { textAlign: 'center', color: '#9CA3AF', fontSize: 14, margin: '0 0 20px' },
  // Boss selection
  bossGrid: { display: 'flex', justifyContent: 'center', flexWrap: 'wrap', gap: 20, padding: '0 40px' },
  bossCard: {
    background: 'rgba(20,18,30,0.8)', border: '2px solid', borderRadius: 12, padding: 12,
    cursor: 'pointer', transition: 'transform 0.15s',
    display: 'flex', flexDirection: 'column', alignItems: 'center'
  },
  bossName: { fontWeight: 800, fontSize: 16, marginTop: 10 },
  bossMeta: { fontSize: 12, color: '#A1A1AA', marginTop: 4 },
  // HUD
  hud: {
    display: 'flex', alignItems: 'center', gap: 14,
    padding: '8px 20px',
    background: 'linear-gradient(180deg, rgba(31,26,46,0.95) 0%, rgba(21,18,31,0.95) 100%)',
    borderBottom: '2px solid #7C3AED',
    boxShadow: '0 2px 12px rgba(124,58,237,0.3)',
    flexShrink: 0, zIndex: 10
  },
  phaseBadge: {
    color: '#fff', padding: '6px 14px', borderRadius: 6,
    fontWeight: 800, fontSize: 13, textTransform: 'uppercase', letterSpacing: 1.5,
    boxShadow: '0 2px 6px rgba(0,0,0,0.4)'
  },
  hudLabel: { fontSize: 13, color: '#A1A1AA', fontWeight: 600 },
  hudSpacer: { flex: 1 },
  hudStat: { fontSize: 13, color: '#D1D5DB', fontWeight: 600, display: 'flex', alignItems: 'center' },
  muteBtn: {
    background: 'rgba(0,0,0,0.3)', border: '1px solid #4B5563',
    color: '#D1D5DB', width: 32, height: 32, borderRadius: 6,
    cursor: 'pointer', fontSize: 16, padding: 0
  },
  // Opponent row
  oppRow: {
    display: 'flex', gap: 12, padding: '8px 20px',
    flexShrink: 0
  },
  oppDungeon: {
    flex: 1, borderRadius: 8, padding: '6px 12px',
    border: '1px solid #2d2540',
    display: 'flex', alignItems: 'center', gap: 12
  },
  oppHeader: { display: 'flex', alignItems: 'center', gap: 10, minWidth: 0, flexShrink: 0 },
  oppName: { fontWeight: 700, fontSize: 13, whiteSpace: 'nowrap' },
  oppMeta: { fontSize: 11, color: '#A1A1AA' },
  oppRooms: { display: 'flex', alignItems: 'center', gap: 0, marginLeft: 'auto' },
  elimTag: { color: '#F87171', fontWeight: 800, fontSize: 10, marginLeft: 6 },
  levelTag: { background: '#F59E0B', color: '#000', fontSize: 10, fontWeight: 800, padding: '2px 6px', borderRadius: 4, marginLeft: 6 },
  // Play area
  playArea: {
    display: 'flex', flex: '1 1 auto', minHeight: 0,
    padding: '8px 20px', gap: 12
  },
  myDungeonWrap: {
    flex: 1, display: 'flex', flexDirection: 'column',
    background: 'linear-gradient(180deg, rgba(30,27,46,0.5) 0%, rgba(15,12,22,0.8) 100%)',
    border: '2px solid #3d3050', borderRadius: 10, padding: 10
  },
  dungeonHeader: { display: 'flex', alignItems: 'center', gap: 12, marginBottom: 6 },
  dungeonTitle: { fontSize: 16, fontWeight: 800, textTransform: 'uppercase', letterSpacing: 1.5 },
  dungeonSubtitle: { fontSize: 11, color: '#6B7280', fontStyle: 'italic' },
  myDungeon: { display: 'flex', alignItems: 'center', flex: 1, minHeight: 0, padding: '8px 0' },
  roomsRow: { display: 'flex', alignItems: 'center', flex: 1, gap: 0 },
  roomSlot: { position: 'relative', marginRight: 12 },
  stackBadge: {
    position: 'absolute', top: -6, right: -6,
    background: '#FCD34D', color: '#000',
    fontSize: 10, fontWeight: 800, padding: '2px 6px', borderRadius: 8,
    border: '2px solid #1a0a1a', zIndex: 10
  },
  emptySlot: {
    width: 120, height: 168, borderRadius: 8,
    border: '2px dashed #4B5563', background: 'rgba(30,41,59,0.3)',
    display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center',
    color: '#6B7280', cursor: 'pointer', transition: 'all 0.15s',
    marginLeft: 8
  },
  emptySlotPlus: { fontSize: 48, fontWeight: 300, lineHeight: 1 },
  emptySlotLabel: { fontSize: 11, marginTop: 4, textTransform: 'uppercase' },
  entranceMarker: {
    width: 70, padding: '8px 6px',
    border: '2px dashed #7C3AED', borderRadius: 8,
    background: 'rgba(124,58,237,0.1)',
    display: 'flex', alignItems: 'center', justifyContent: 'center',
    marginRight: 12, alignSelf: 'stretch'
  },
  entranceLabel: { color: '#A78BFA', fontSize: 11, fontWeight: 800, letterSpacing: 1, textAlign: 'center' },
  dungeonEmpty: { color: '#6B7280', fontSize: 14, fontStyle: 'italic', padding: 20, textAlign: 'center', flex: 1 },
  // Town
  townColumn: { display: 'flex', flexDirection: 'column', gap: 8, width: 320, flexShrink: 0 },
  entranceBox: {
    background: 'linear-gradient(180deg, rgba(127,29,29,0.3) 0%, rgba(20,18,30,0.9) 100%)',
    border: '2px solid #DC2626', borderRadius: 10, padding: 8
  },
  entranceHeader: { display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 6 },
  entranceRow: { display: 'flex', alignItems: 'center' },
  townBox: {
    background: 'linear-gradient(180deg, rgba(20,18,30,0.7) 0%, rgba(10,8,15,0.9) 100%)',
    border: '2px solid #4B5563', borderRadius: 10, padding: 8, flex: 1
  },
  townHeader: { display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 6 },
  townTitle: { color: '#FCD34D', fontWeight: 800, fontSize: 12, letterSpacing: 1.5, textTransform: 'uppercase' },
  townCount: { color: '#FCD34D', fontWeight: 800, fontSize: 16, background: 'rgba(0,0,0,0.4)', padding: '0 8px', borderRadius: 10 },
  townRow: { display: 'flex', alignItems: 'center' },
  // Hand
  handPanel: {
    padding: '8px 20px',
    background: 'linear-gradient(180deg, rgba(20,17,30,0.95) 0%, rgba(8,6,14,0.98) 100%)',
    borderTop: '2px solid #7C3AED',
    flexShrink: 0
  },
  handHeader: { display: 'flex', alignItems: 'center', gap: 12, marginBottom: 6 },
  handTitle: { color: '#A1A1AA', fontWeight: 800, fontSize: 13, letterSpacing: 1.5, textTransform: 'uppercase' },
  handHint: { color: '#FCD34D', fontSize: 12, fontStyle: 'italic' },
  handRow: { display: 'flex', alignItems: 'flex-start', flexWrap: 'nowrap', overflowX: 'auto', paddingBottom: 4, minHeight: 182 },
  btnPass: {
    background: 'linear-gradient(135deg, #DC2626, #991B1B)', color: '#fff', border: 'none',
    borderRadius: 6, padding: '6px 14px', fontWeight: 700, fontSize: 13, cursor: 'pointer',
    marginLeft: 'auto'
  },
  btnPrimary: {
    background: 'linear-gradient(135deg, #7C3AED, #5B21B6)', color: '#fff', border: 'none',
    borderRadius: 6, padding: '6px 12px', fontWeight: 700, fontSize: 11, cursor: 'pointer'
  },
  // Log
  logStrip: {
    background: 'rgba(0,0,0,0.5)', padding: '4px 20px',
    maxHeight: 70, overflowY: 'auto',
    fontFamily: "'Consolas', monospace", fontSize: 11, color: '#9CA3AF',
    borderTop: '1px solid #2d2540', flexShrink: 0
  },
  logLine: { marginBottom: 1, lineHeight: 1.4 },
  // Misc
  empty: { color: '#6B7280', fontSize: 12, fontStyle: 'italic', padding: 8 },
  cardBtn: { background: 'none', border: 'none', padding: 0, margin: 0, outline: 'none' },
  // Detail panel
  detailOverlay: {
    position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.85)',
    display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 100,
    backdropFilter: 'blur(4px)'
  },
  detailPanel: {
    width: 360, maxHeight: '90vh', overflowY: 'auto',
    background: 'linear-gradient(180deg, #1f1a2e 0%, #15121f 100%)',
    borderRadius: 12, padding: 16,
    border: '2px solid #7C3AED', boxShadow: '0 0 40px rgba(124,58,237,0.5)',
    display: 'flex', flexDirection: 'column', gap: 10
  },
  detailHeader: { display: 'flex', justifyContent: 'space-between', alignItems: 'center' },
  detailTitle: { fontWeight: 800, fontSize: 18, color: '#FCD34D' },
  closeBtn: { background: 'none', border: 'none', color: '#9CA3AF', fontSize: 28, cursor: 'pointer', lineHeight: 1, padding: 0 },
  detailImgWrap: { width: '100%', aspectRatio: '1.4', borderRadius: 8, overflow: 'hidden', background: '#111' },
  detailImg: { width: '100%', height: '100%', objectFit: 'cover', display: 'block' },
  detailMeta: { fontSize: 13, color: '#D1D5DB', display: 'flex', flexDirection: 'column', gap: 4 },
  detailDesc: { fontSize: 13, color: '#A1A1AA', lineHeight: 1.5, background: 'rgba(0,0,0,0.3)', padding: 10, borderRadius: 6 }
};
