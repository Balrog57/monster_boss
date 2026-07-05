import React, { useState, useEffect, useRef } from 'react';
import {
  BOSSES, ROOMS, SPELLS, HEROES, TREASURE_NAMES, PHASE, getCardImage
} from './cardData.js';
import { playMusic, playSfx, SFX } from './audio.js';

// ---------------------------------------------------------------------------
// Card image component. `kind` selects the folder; `faceDown` renders a back.
// ---------------------------------------------------------------------------
function Card({ card, kind = 'room', faceDown = false, size = 'md', onClick, onInspect, selected = false, dim = false, style = {} }) {
  const src = faceDown
    ? getCardImage('', `back-${kind === 'epic-hero' ? 'hero' : kind}`)
    : getCardImage(card?.id, kind === 'epic-hero' ? 'epic-hero' : kind);
  const sizes = {
    xs: { width: 48 },
    sm: { width: 76 },
    md: { width: 110 },
    lg: { width: 150 },
    xl: { width: 210 }
  };
  const s = sizes[size] || sizes.md;
  const ratio = 1.4;
  return (
    <div
      style={{
        width: s.width,
        height: s.width * ratio,
        borderRadius: 6,
        overflow: 'hidden',
        boxShadow: selected ? '0 0 0 3px #F59E0B, 0 6px 14px rgba(0,0,0,0.6)' : '0 4px 12px rgba(0,0,0,0.5)',
        opacity: dim ? 0.55 : 1,
        transition: 'transform 0.12s, box-shadow 0.12s',
        cursor: onClick ? 'pointer' : 'default',
        background: '#111',
        position: 'relative',
        ...style
      }}
      onClick={onClick}
    >
      {src ? (
        <img
          src={src}
          alt={card?.name || 'card'}
          style={{ width: '100%', height: '100%', objectFit: 'cover', display: 'block', pointerEvents: 'none' }}
          loading="lazy"
          onError={(e) => { e.currentTarget.style.display = 'none'; }}
        />
      ) : (
        <div style={{ color: '#fff', fontSize: 10, textAlign: 'center', padding: 6, position: 'absolute', inset: 0, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
          {card?.name || '?'}
        </div>
      )}
      {onInspect && card && !faceDown && (
        <span
          onClick={(e) => { e.stopPropagation(); onInspect(card, kind); }}
          style={{
            position: 'absolute', top: 3, right: 3,
            width: 20, height: 20, borderRadius: '50%',
            background: 'rgba(0,0,0,0.7)', color: '#FCD34D',
            border: '1px solid #FCD34D', cursor: 'pointer',
            fontSize: 12, lineHeight: '20px', padding: 0, textAlign: 'center',
            fontWeight: 700, userSelect: 'none'
          }}
          title="Inspecter"
        >i</span>
      )}
    </div>
  );
}

// ---------------------------------------------------------------------------
// HUD counters
// ---------------------------------------------------------------------------
function Soul({ n }) {
  return (
    <div style={{ display: 'flex', alignItems: 'center', gap: 4 }}>
      <img src="/assets/ui/icons/soul.png" width={20} height={20} alt="soul" />
      <span style={{ color: '#FCD34D', fontWeight: 700, fontSize: 16 }}>{n}</span>
    </div>
  );
}
function Wound({ n }) {
  return (
    <div style={{ display: 'flex', alignItems: 'center', gap: 4 }}>
      <img src="/assets/ui/icons/wound.png" width={20} height={20} alt="wound" />
      <span style={{ color: '#F87171', fontWeight: 700, fontSize: 16 }}>{n}</span>
    </div>
  );
}

const TREASURE_ICON = { 1: 'cleric', 2: 'fighter', 3: 'mage', 4: 'thief' };

// ---------------------------------------------------------------------------
// Main board — landscape layout.
// Grid:  [ opponent strip ]   (top)
//        [ town | detail panel ]   (middle)
//        [ my dungeon ]   (bottom)
//        [ hand | HUD ]   (footer)
// ---------------------------------------------------------------------------
export default function AppBoard({ G, ctx, moves, events, playerID, isActive }) {
  const [inspect, setInspect] = useState(null); // { card, kind }
  const lastPhase = useRef(null);

  // Start dungeon music once gameplay begins (after boss selection).
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

  const mySouls = me.souls.length;
  const myWounds = me.wounds.length;

  // ----- Boss selection -----
  if (phase === PHASE.BOSS) {
    return (
      <div style={S.screen}>
        <h1 style={S.title}>Choisir votre Boss</h1>
        <div style={S.rowCenter}>
          {G.bossPicks.map(b => (
            <button
              key={b.id}
              onClick={() => moves.pickBoss(b.id)}
              onDoubleClick={() => setInspect({ card: b, kind: 'boss' })}
              style={S.cardBtn}
            >
              <Card card={b} kind="boss" size="xl" onInspect={setInspect} onClick={() => setInspect({ card: b, kind: 'boss' })} />
              <div style={S.label}>{b.name}</div>
              <div style={S.subLabel}>XP {b.xp} · Trésor {b.treasures.map(t => TREASURE_NAMES[t]).join(', ')}</div>
            </button>
          ))}
        </div>
        <DetailPanel inspect={inspect} onClose={() => setInspect(null)} />
      </div>
    );
  }

  const isMyTurn = String(ctx.currentPlayer) === pidKey;
  const opponents = Object.entries(G.players).filter(([pid]) => pid !== pidKey);

  return (
    <div style={S.screen}>
      {/* ===== HUD strip ===== */}
      <div style={S.hud}>
        <div style={S.phaseBadge}>{(phase || '').toUpperCase()}</div>
        <div style={S.hudStat}>Tour {G.turn}</div>
        <div style={S.hudStat}>{isMyTurn ? 'À vous de jouer' : `Joueur ${ctx.currentPlayer}`}</div>
        <div style={{ display: 'flex', gap: 18, marginLeft: 'auto', alignItems: 'center' }}>
          <Soul n={mySouls} />
          <Wound n={myWounds} />
          <span style={S.hudStat}>{me.boss?.name || 'Boss'} ({me.boss?.xp || 0} XP)</span>
          <span style={S.hudStat}>Donjon {me.dungeon.length}/5</span>
          <span style={S.hudStat}>Pioche R:{G.decks.rooms.length} S:{G.decks.spells.length} H:{G.decks.heroes.length}</span>
        </div>
      </div>

      {/* ===== Opponent strip (top) ===== */}
      <div style={S.oppStrip}>
        {opponents.map(([pid, p]) => (
          <div key={pid} style={S.oppPanel}>
            <div style={S.oppHeader}>
              <span style={S.oppName}>Joueur {pid} — {p.boss?.name || 'Boss'}</span>
              <Soul n={p.souls.length} />
              <Wound n={p.wounds.length} />
              {p.eliminated && <span style={S.elimTag}>ÉLIMINÉ</span>}
            </div>
            <div style={S.dungeonRow}>
              {p.dungeon.length === 0 && <div style={S.empty}>Donjon vide</div>}
              {p.dungeon.map((r, i) => (
                <Card
                  key={`${pid}-${r.id}-${i}`}
                  card={r}
                  kind="room"
                  size="sm"
                  faceDown={phase === PHASE.SETUP && !p.revealed}
                  onInspect={setInspect}
                  style={{ marginRight: -28 }}
                />
              ))}
            </div>
          </div>
        ))}
      </div>

      {/* ===== Middle: town + detail panel ===== */}
      <div style={S.middleRow}>
        <div style={S.townPanel}>
          <div style={S.panelTitle}>Ville / Town ({G.town.length})</div>
          <div style={S.townRow}>
            {G.town.length === 0 && <div style={S.empty}>Aucun héros en ville</div>}
            {G.town.map((h, i) => (
              <Card
                key={`town-${h.id}-${i}`}
                card={h}
                kind={h.epic ? 'epic-hero' : 'hero'}
                size="md"
                onInspect={setInspect}
                style={{ marginRight: -32 }}
              />
            ))}
          </div>
          {me.entrance.length > 0 && (
            <div style={{ marginTop: 8 }}>
              <div style={S.panelTitle}>À votre entrée</div>
              <div style={S.townRow}>
                {me.entrance.map((h, i) => (
                  <Card key={`entr-${i}`} card={h} kind={h.epic ? 'epic-hero' : 'hero'} size="sm" onInspect={setInspect} style={{ marginRight: -20 }} />
                ))}
              </div>
            </div>
          )}
        </div>
        <DetailPanel inspect={inspect} onClose={() => setInspect(null)} />
      </div>

      {/* ===== My dungeon (bottom) ===== */}
      <div style={S.myDungeonPanel}>
        <div style={S.panelTitle}>
          Mon Donjon — {me.boss?.name || 'Boss'}
          {me.leveledUp && <span style={S.levelTag}>LEVEL UP</span>}
        </div>
        <div style={S.myDungeonRow}>
          {me.dungeon.length === 0 && <div style={S.empty}>Construisez des salles</div>}
          {me.dungeon.map((r, i) => (
            <Card
              key={`me-${r.id}-${i}`}
              card={r}
              kind="room"
              size="lg"
              selected={G.selectedCard === i}
              onInspect={setInspect}
              style={{ marginRight: -40, zIndex: i }}
            />
          ))}
          {me.dungeon.length < 5 && phase === PHASE.BUILD && (
            <div style={S.dropZone}>+</div>
          )}
        </div>
      </div>

      {/* ===== Hand + actions ===== */}
      <div style={S.handPanel}>
        <div style={S.panelTitle}>
          Main ({me.hand.length})
          <span style={{ ...S.hint, marginLeft: 8 }}>clic pour jouer · bouton (i) pour inspecter</span>
        </div>
        <div style={S.handRow}>
          {me.hand.length === 0 && <div style={S.empty}>Main vide</div>}
          {me.hand.map((c, i) => (
            <button
              key={`hand-${c.id}-${i}`}
              onClick={() => {
                if (c.isRoom && (phase === PHASE.BUILD || phase === PHASE.SETUP)) {
                  if (phase === PHASE.SETUP) moves.buildInitialRoom(i);
                  else moves.buildRoom(i);
                } else if (c.isSpell) {
                  moves.playSpell(i);
                } else {
                  moves.selectCard(i);
                }
              }}
              style={S.cardBtn}
              title={c.name}
            >
              <Card
                card={c}
                kind={c.isRoom ? 'room' : c.isSpell ? 'spell' : 'hero'}
                size="md"
                selected={G.selectedCard === i}
                dim={!isMyTurn}
                onInspect={setInspect}
                style={{ marginRight: -30 }}
              />
            </button>
          ))}
        </div>
        <div style={S.actions}>
          <button style={S.btn} onClick={() => moves.pass()} disabled={!isMyTurn}>Passer</button>
          <button style={S.btn} onClick={() => { if (G.selectedCard !== null) moves.playSpell(G.selectedCard); }} disabled={!isMyTurn || G.selectedCard === null}>Lancer Sort</button>
        </div>
      </div>

      {/* ===== Log (collapsible bottom strip) ===== */}
      <div style={S.logStrip}>
        {G.logs.slice(-6).map((l, i) => (
          <div key={i} style={S.logLine}>{l}</div>
        ))}
      </div>

      {/* Game-over is handled by App.jsx's GameOverScreen overlay */}
    </div>
  );
}

// ---------------------------------------------------------------------------
// Detail panel — shows a card's full image + name + effect text.
// ---------------------------------------------------------------------------
function DetailPanel({ inspect, onClose }) {
  if (!inspect) return null;
  const { card, kind } = inspect;
  const src = getCardImage(card?.id, kind === 'epic-hero' ? 'epic-hero' : kind);
  return (
    <div style={S.detailPanel}>
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
      {card?.levelUpDesc && <div style={S.detailDesc}><em>{card.levelUpDesc}</em></div>}
    </div>
  );
}

// ===========================================================================
// Styles
// ===========================================================================
const S = {
  screen: {
    minHeight: '100vh',
    background: 'radial-gradient(ellipse at top, #1a1025 0%, #0a0a0f 70%)',
    color: '#F3F4F6',
    fontFamily: "'Segoe UI', 'Space Grotesk', sans-serif",
    display: 'flex',
    flexDirection: 'column',
    overflow: 'hidden'
  },
  title: {
    fontSize: 34,
    fontWeight: 800,
    textAlign: 'center',
    margin: '20px 0',
    color: '#E11D48',
    textShadow: '0 2px 8px rgba(225,29,72,0.4)'
  },
  // HUD
  hud: {
    display: 'flex',
    alignItems: 'center',
    gap: 16,
    padding: '8px 16px',
    background: 'linear-gradient(180deg, #1f1a2e 0%, #15121f 100%)',
    borderBottom: '1px solid #2d2540',
    flexShrink: 0
  },
  phaseBadge: {
    background: 'linear-gradient(135deg, #7C3AED, #5B21B6)',
    color: '#fff',
    padding: '6px 14px',
    borderRadius: 6,
    fontWeight: 800,
    fontSize: 13,
    textTransform: 'uppercase',
    letterSpacing: 1,
    boxShadow: '0 2px 6px rgba(124,58,237,0.4)'
  },
  hudStat: { fontSize: 13, color: '#A1A1AA', fontWeight: 600 },
  // Opponent strip
  oppStrip: {
    display: 'flex',
    gap: 10,
    padding: '10px 16px',
    flexShrink: 0
  },
  oppPanel: {
    flex: 1,
    background: 'rgba(30,27,46,0.6)',
    borderRadius: 8,
    padding: 10,
    border: '1px solid #2d2540'
  },
  oppHeader: {
    display: 'flex',
    alignItems: 'center',
    gap: 12,
    marginBottom: 6,
    fontSize: 13
  },
  oppName: { fontWeight: 700, color: '#E4E4E7' },
  elimTag: { color: '#F87171', fontWeight: 700, fontSize: 11 },
  dungeonRow: { display: 'flex', alignItems: 'flex-start' },
  // Middle row: town + detail
  middleRow: {
    display: 'flex',
    gap: 12,
    padding: '0 16px',
    flex: '1 1 auto',
    minHeight: 0
  },
  townPanel: {
    flex: '1 1 auto',
    background: 'rgba(20,18,30,0.7)',
    borderRadius: 8,
    padding: 10,
    border: '1px solid #2d2540'
  },
  townRow: { display: 'flex', alignItems: 'flex-start' },
  // Detail panel
  detailPanel: {
    width: 240,
    flexShrink: 0,
    background: 'rgba(15,12,22,0.9)',
    borderRadius: 8,
    padding: 10,
    border: '1px solid #3d3050',
    display: 'flex',
    flexDirection: 'column',
    gap: 8
  },
  detailHeader: {
    display: 'flex',
    justifyContent: 'space-between',
    alignItems: 'center'
  },
  detailTitle: { fontWeight: 700, fontSize: 14, color: '#FCD34D' },
  closeBtn: {
    background: 'none', border: 'none', color: '#9CA3AF',
    fontSize: 22, cursor: 'pointer', lineHeight: 1, padding: '0 4px'
  },
  detailImgWrap: {
    width: '100%', aspectRatio: '1.4', borderRadius: 6,
    overflow: 'hidden', background: '#111'
  },
  detailImg: { width: '100%', height: '100%', objectFit: 'cover', display: 'block' },
  detailMeta: { fontSize: 12, color: '#D1D5DB', display: 'flex', flexDirection: 'column', gap: 2 },
  detailDesc: {
    fontSize: 12, color: '#A1A1AA', lineHeight: 1.4,
    background: 'rgba(0,0,0,0.3)', padding: 8, borderRadius: 4,
    fontStyle: 'normal'
  },
  // My dungeon
  myDungeonPanel: {
    padding: '8px 16px',
    flexShrink: 0
  },
  myDungeonRow: { display: 'flex', alignItems: 'flex-start' },
  levelTag: {
    background: '#F59E0B', color: '#000', fontSize: 10, fontWeight: 800,
    padding: '2px 6px', borderRadius: 4, marginLeft: 8
  },
  // Hand
  handPanel: {
    padding: '8px 16px',
    background: 'linear-gradient(180deg, #14111e 0%, #0d0b14 100%)',
    borderTop: '1px solid #2d2540',
    flexShrink: 0
  },
  handRow: { display: 'flex', alignItems: 'flex-start', flexWrap: 'nowrap', overflowX: 'auto', paddingBottom: 4 },
  actions: { display: 'flex', gap: 10, marginTop: 8 },
  hint: { fontSize: 11, color: '#6B7280', fontWeight: 400, textTransform: 'none' },
  // Misc
  panelTitle: {
    fontSize: 12, fontWeight: 700, color: '#A1A1AA',
    marginBottom: 6, textTransform: 'uppercase', letterSpacing: 0.8,
    display: 'flex', alignItems: 'center', gap: 8
  },
  rowCenter: {
    display: 'flex', justifyContent: 'center', alignItems: 'flex-start',
    flexWrap: 'wrap', gap: 16
  },
  cardBtn: { background: 'none', border: 'none', padding: 0, margin: 0, outline: 'none', cursor: 'pointer' },
  empty: { color: '#6B7280', fontSize: 12, fontStyle: 'italic' },
  label: { textAlign: 'center', marginTop: 8, fontSize: 14, fontWeight: 700, color: '#E4E4E7' },
  subLabel: { textAlign: 'center', fontSize: 11, color: '#9CA3AF' },
  dropZone: {
    width: 100, height: 140, borderRadius: 6,
    border: '2px dashed #4B5563', background: 'rgba(30,41,59,0.4)',
    display: 'flex', alignItems: 'center', justifyContent: 'center',
    color: '#6B7280', fontSize: 32
  },
  btn: {
    background: 'linear-gradient(135deg, #7C3AED, #5B21B6)',
    color: '#fff', border: 'none', borderRadius: 6,
    padding: '8px 16px', fontWeight: 700, fontSize: 13, cursor: 'pointer'
  },
  // Log
  logStrip: {
    background: 'rgba(0,0,0,0.4)',
    padding: '6px 16px',
    maxHeight: 90,
    overflowY: 'auto',
    fontFamily: "'Consolas', monospace",
    fontSize: 11,
    color: '#9CA3AF',
    flexShrink: 0
  },
  logLine: { marginBottom: 2, lineHeight: 1.4 },
  // Modal
  modal: {
    position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.8)',
    display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 100
  },
  modalBox: {
    background: '#1a1525', padding: 36, borderRadius: 12, textAlign: 'center',
    border: '1px solid #7C3AED', boxShadow: '0 0 40px rgba(124,58,237,0.4)'
  }
};
