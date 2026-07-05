import React from 'react';
import {
  BOSSES, ROOMS, SPELLS, HEROES, TREASURE_NAMES, PHASE, getCardImage
} from './cardData.js';

function Card({ card, kind = 'room', faceDown = false, size = 'md', onClick, selected = false, dim = false, style = {} }) {
  const src = faceDown ? getCardImage('', `back-${kind}`) : getCardImage(card?.id, kind === 'epic-hero' ? 'epic-hero' : kind);
  const sizes = {
    xs: { width: 50, font: 9 },
    sm: { width: 70, font: 10 },
    md: { width: 100, font: 11 },
    lg: { width: 140, font: 12 },
    xl: { width: 200, font: 13 }
  };
  const s = sizes[size] || sizes.md;
  const ratio = 1.4;
  return (
    <div
      onClick={onClick}
      style={{
        width: s.width,
        height: s.width * ratio,
        borderRadius: 8,
        overflow: 'hidden',
        boxShadow: selected ? '0 0 0 3px #F59E0B, 0 4px 12px rgba(0,0,0,0.5)' : '0 4px 12px rgba(0,0,0,0.4)',
        opacity: dim ? 0.55 : 1,
        transition: 'transform 0.12s, box-shadow 0.12s',
        cursor: onClick ? 'pointer' : 'default',
        background: '#111',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        ...style
      }}
    >
      {src ? (
        <img
          src={src}
          alt={card?.name || 'card'}
          style={{ width: '100%', height: '100%', objectFit: 'cover', display: 'block' }}
          loading="lazy"
          onError={(e) => { e.currentTarget.style.display = 'none'; }}
        />
      ) : (
        <div style={{ color: '#fff', fontSize: s.font, textAlign: 'center', padding: 6 }}>{card?.name || '?'}</div>
      )}
    </div>
  );
}

function Soul({ n }) {
  const src = '/assets/ui/icons/soul.png';
  return (
    <div style={{ display: 'flex', alignItems: 'center', gap: 2 }}>
      <img src={src} width={18} height={18} alt="soul" />
      <span style={{ color: '#FCD34D', fontWeight: 700, fontSize: 13 }}>{n}</span>
    </div>
  );
}
function Wound({ n }) {
  const src = '/assets/ui/icons/wound.png';
  return (
    <div style={{ display: 'flex', alignItems: 'center', gap: 2 }}>
      <img src={src} width={18} height={18} alt="wound" />
      <span style={{ color: '#F87171', fontWeight: 700, fontSize: 13 }}>{n}</span>
    </div>
  );
}

export default function AppBoard({ G, ctx, moves, events, playerID }) {
  const me = G.players[playerID];
  const phase = G.phase;

  // Boss selection
  if (phase === PHASE.BOSS) {
    return (
      <div style={styles.screen}>
        <h1 style={styles.title}>Choisir votre Boss</h1>
        <div style={styles.rowCenter}>
          {G.bossPicks.map(b => (
            <button
              key={b.id}
              onClick={() => moves.pickBoss(b.id)}
              style={{ ...styles.cardBtn, margin: 12 }}
            >
              <Card card={b} kind="boss" size="xl" />
              <div style={styles.label}>{b.name}</div>
            </button>
          ))}
        </div>
      </div>
    );
  }

  // Determine AI status text
  const aiText = ctx.currentPlayer === playerID ? 'Your turn' : `Player ${ctx.currentPlayer} turn`;

  return (
    <div style={styles.screen}>
      {/* Header */}
      <div style={styles.header}>
        <div style={styles.phaseBadge}>{phase.toUpperCase()} — Tour {G.turn}</div>
        <div style={{ display: 'flex', gap: 16, alignItems: 'center' }}>
          <Soul n={me.souls.length} />
          <Wound n={me.wounds.length} />
          <span style={{ color: '#9CA3AF', fontSize: 13 }}>{aiText}</span>
        </div>
      </div>

      <div style={styles.main}>
        {/* Town */}
        <div style={styles.panel}>
          <div style={styles.panelTitle}>Ville / Town</div>
          <div style={styles.row}>
            {G.town.length === 0 && <div style={styles.empty}>Aucun héros</div>}
            {G.town.map((h, i) => (
              <Card
                key={`${h.id}-${i}`}
                card={h}
                kind={h.epic ? 'epic-hero' : 'hero'}
                size="md"
                style={{ marginRight: -30 }}
              />
            ))}
          </div>
        </div>

        {/* Opponent dungeons */}
        {Object.entries(G.players)
          .filter(([pid]) => parseInt(pid) !== playerID)
          .map(([pid, p]) => (
            <div key={pid} style={styles.panel}>
              <div style={styles.panelTitle}>
                Joueur {pid} — {p.boss?.name || 'Boss'} | <Soul n={p.souls.length} /> <Wound n={p.wounds.length} />
              </div>
              <div style={styles.dungeon}>
                {p.dungeon.length === 0 && <div style={styles.empty}>Pas de donjon</div>}
                {p.dungeon.map((r, i) => (
                  <Card
                    key={`${pid}-${r.id}-${i}`}
                    card={r}
                    kind="room"
                    size="sm"
                    faceDown={phase === PHASE.SETUP && !p.revealed}
                    style={{ marginRight: -24 }}
                  />
                ))}
              </div>
            </div>
          ))}

        {/* My dungeon */}
        <div style={styles.myPanel}>
          <div style={styles.panelTitle}>Mon Donjon — {me.boss?.name || 'Boss'}</div>
          <div style={styles.dungeon}>
            {me.dungeon.length === 0 && <div style={styles.empty}>Construisez des salles</div>}
            {me.dungeon.map((r, i) => (
              <Card
                key={`me-${r.id}-${i}`}
                card={r}
                kind="room"
                size="lg"
                selected={G.selectedCard === i}
                style={{ marginRight: -36, zIndex: i }}
              />
            ))}
            {me.dungeon.length < 5 && phase === PHASE.BUILD && (
              <div style={{ ...styles.dropZone, width: 100, height: 140 }} onClick={() => {}}/>
            )}
          </div>
        </div>

        {/* Hand */}
        <div style={styles.handPanel}>
          <div style={styles.panelTitle}>Main</div>
          <div style={styles.row}>
            {me.hand.length === 0 && <div style={styles.empty}>Vide</div>}
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
                style={{ ...styles.cardBtn, marginRight: -28 }}
              >
                <Card
                  card={c}
                  kind={c.isRoom ? 'room' : c.isSpell ? 'spell' : 'hero'}
                  size="md"
                  selected={G.selectedCard === i}
                  dim={ctx.currentPlayer !== playerID}
                />
              </button>
            ))}
          </div>
        </div>
      </div>

      {/* Footer actions */}
      <div style={styles.footer}>
        <button style={styles.btn} onClick={() => moves.pass()} disabled={ctx.currentPlayer !== playerID}>Passer</button>
        <button style={styles.btn} onClick={() => moves.playSpell(G.selectedCard)} disabled={ctx.currentPlayer !== playerID || G.selectedCard === null}>Lancer Sort</button>
      </div>

      {/* Logs */}
      <div style={styles.logs}>
        {G.logs.slice(-12).map((l, i) => (
          <div key={i} style={styles.log}>{l}</div>
        ))}
      </div>

      {G.gameOver && (
        <div style={styles.modal}>
          <div style={styles.modalBox}>
            <h2>{G.winner === parseInt(playerID) ? 'Victoire !' : 'Défaite...'}</h2>
            <p>{G.winner === parseInt(playerID) ? 'Vous avez gagné.' : `Joueur ${G.winner} gagne.`}</p>
            <button style={styles.btn} onClick={() => window.location.reload()}>Rejouer</button>
          </div>
        </div>
      )}
    </div>
  );
}

const styles = {
  screen: {
    minHeight: '100vh',
    background: '#0E0E0E',
    color: '#F3F4F6',
    fontFamily: "'Space Grotesk', sans-serif",
    display: 'flex',
    flexDirection: 'column'
  },
  title: {
    fontFamily: "'Space Grotesk', sans-serif",
    fontSize: 36,
    fontWeight: 700,
    textAlign: 'center',
    margin: '24px 0',
    color: '#E11D48'
  },
  header: {
    display: 'flex',
    justifyContent: 'space-between',
    alignItems: 'center',
    padding: '12px 20px',
    borderBottom: '1px solid #27272A',
    background: '#18181B'
  },
  phaseBadge: {
    background: '#7C3AED',
    color: '#fff',
    padding: '6px 14px',
    borderRadius: 999,
    fontWeight: 700,
    fontSize: 13,
    textTransform: 'uppercase',
    letterSpacing: 0.5
  },
  main: {
    flex: 1,
    padding: 16,
    display: 'flex',
    flexDirection: 'column',
    gap: 14,
    overflowY: 'auto'
  },
  panel: {
    background: '#18181B',
    borderRadius: 12,
    padding: 12,
    border: '1px solid #27272A'
  },
  myPanel: {
    background: '#24132A',
    borderRadius: 12,
    padding: 12,
    border: '1px solid #4C1D95'
  },
  handPanel: {
    background: '#111827',
    borderRadius: 12,
    padding: 12,
    border: '1px solid #1F2937',
    minHeight: 170
  },
  panelTitle: {
    fontSize: 13,
    fontWeight: 700,
    color: '#A1A1AA',
    marginBottom: 8,
    textTransform: 'uppercase',
    letterSpacing: 0.5,
    display: 'flex',
    gap: 8,
    alignItems: 'center'
  },
  row: {
    display: 'flex',
    gap: 6,
    flexWrap: 'wrap',
    alignItems: 'flex-start'
  },
  rowCenter: {
    display: 'flex',
    justifyContent: 'center',
    alignItems: 'center',
    flexWrap: 'wrap',
    gap: 12
  },
  dungeon: {
    display: 'flex',
    flexWrap: 'wrap',
    gap: 6,
    alignItems: 'flex-start'
  },
  cardBtn: {
    background: 'none',
    border: 'none',
    padding: 0,
    margin: 0,
    outline: 'none'
  },
  empty: {
    color: '#6B7280',
    fontSize: 13,
    fontStyle: 'italic'
  },
  label: {
    textAlign: 'center',
    marginTop: 6,
    fontSize: 13,
    color: '#E4E4E7'
  },
  dropZone: {
    border: '2px dashed #4B5563',
    borderRadius: 8,
    background: '#111827'
  },
  footer: {
    display: 'flex',
    gap: 12,
    padding: '12px 20px',
    borderTop: '1px solid #27272A',
    background: '#18181B'
  },
  btn: {
    background: '#7C3AED',
    color: '#fff',
    border: 'none',
    borderRadius: 8,
    padding: '10px 18px',
    fontWeight: 700,
    cursor: 'pointer',
    fontFamily: "'Space Grotesk', sans-serif"
  },
  logs: {
    background: '#0B0B0C',
    padding: '10px 16px',
    maxHeight: 120,
    overflowY: 'auto',
    fontFamily: "'JetBrains Mono', monospace",
    fontSize: 11,
    color: '#9CA3AF'
  },
  log: {
    marginBottom: 3
  },
  modal: {
    position: 'fixed',
    inset: 0,
    background: 'rgba(0,0,0,0.75)',
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    zIndex: 100
  },
  modalBox: {
    background: '#18181B',
    padding: 32,
    borderRadius: 16,
    textAlign: 'center',
    border: '1px solid #7C3AED'
  }
};
