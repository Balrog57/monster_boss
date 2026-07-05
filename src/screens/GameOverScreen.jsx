// GameOverScreen.jsx - Victory or Defeat screen shown when the game ends.
import React, { useEffect } from 'react';
import { playSfx, SFX, stopMusic } from '../audio.js';

export default function GameOverScreen({ winner, players, playerID, onReplay, onMenu }) {
  const iWon = String(winner) === String(playerID);
  const winnerPlayer = players[winner];
  const winnerName = winnerPlayer?.boss?.name || `Joueur ${winner}`;

  useEffect(() => {
    stopMusic();
    playSfx(iWon ? SFX.WIN : SFX.LOSE, 0.7);
  }, [iWon]);

  // Scoreboard: rank players by souls, then wounds (fewer = better)
  const ranked = Object.entries(players)
    .map(([pid, p]) => ({
      pid,
      name: p.boss?.name || `Joueur ${pid}`,
      souls: p.souls.length,
      wounds: p.wounds.length,
      eliminated: p.eliminated,
      isMe: pid === String(playerID),
    }))
    .sort((a, b) => b.souls - a.souls || a.wounds - b.wounds);

  return (
    <div style={{ ...S.screen, background: iWon ? S.winBg : S.loseBg }}>
      <div style={S.overlay} />

      <div style={S.content}>
        <h1 style={{ ...S.title, color: iWon ? '#FCD34D' : '#F87171' }}>
          {iWon ? '🏆 VICTOIRE !' : '💀 DÉFAITE'}
        </h1>
        <p style={S.headline}>
          {iWon
            ? 'Vous avez conquis le donjon !'
            : `${winnerName} a triomphé`}
        </p>

        <div style={S.scoreboard}>
          <div style={S.scoreHeader}>Scores finaux</div>
          {ranked.map((p, idx) => (
            <div
              key={p.pid}
              style={{
                ...S.scoreRow,
                background: p.isMe ? 'rgba(252,211,77,0.12)' : 'transparent',
                opacity: p.eliminated && !iWon ? 0.5 : 1
              }}
            >
              <span style={S.rank}>{idx + 1}.</span>
              <span style={S.playerName}>
                {p.name}{p.isMe && ' (vous)'}{p.eliminated && ' †'}
              </span>
              <span style={S.statLabel}>âmes</span>
              <span style={S.statVal}>{p.souls}</span>
              <span style={S.statLabel}>blessures</span>
              <span style={{ ...S.statVal, color: '#F87171' }}>{p.wounds}</span>
            </div>
          ))}
        </div>

        <div style={S.actions}>
          <button style={S.btn} onClick={onReplay}>Rejouer</button>
          <button style={{ ...S.btn, ...S.btnSecondary }} onClick={onMenu}>Menu principal</button>
        </div>
      </div>
    </div>
  );
}

const S = {
  screen: {
    position: 'fixed',
    inset: 0,
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    overflow: 'hidden'
  },
  winBg: 'radial-gradient(ellipse at center, #2a1f0a 0%, #0a0a0f 70%)',
  loseBg: 'radial-gradient(ellipse at center, #2a0a0a 0%, #0a0a0f 70%)',
  overlay: {
    position: 'absolute',
    inset: 0,
    pointerEvents: 'none'
  },
  content: {
    position: 'relative',
    zIndex: 2,
    display: 'flex',
    flexDirection: 'column',
    alignItems: 'center',
    gap: 20,
    maxWidth: 560,
    padding: 24
  },
  title: {
    fontSize: 56,
    fontWeight: 900,
    margin: 0,
    fontFamily: "'arcadepix', sans-serif",
    textShadow: '0 4px 24px rgba(0,0,0,0.6)'
  },
  headline: {
    fontSize: 20,
    color: '#D1D5DB',
    margin: 0
  },
  scoreboard: {
    width: '100%',
    background: 'rgba(0,0,0,0.5)',
    border: '1px solid #3d3050',
    borderRadius: 12,
    padding: 16,
    marginTop: 8
  },
  scoreHeader: {
    fontSize: 13,
    fontWeight: 700,
    color: '#9CA3AF',
    textTransform: 'uppercase',
    letterSpacing: 1,
    marginBottom: 12,
    textAlign: 'center'
  },
  scoreRow: {
    display: 'grid',
    gridTemplateColumns: '28px 1fr auto auto auto auto',
    alignItems: 'center',
    gap: 8,
    padding: '8px 12px',
    borderRadius: 6,
    fontSize: 14
  },
  rank: { color: '#6B7280', fontWeight: 700 },
  playerName: { color: '#E4E4E7', fontWeight: 600 },
  statLabel: { color: '#6B7280', fontSize: 12 },
  statVal: { color: '#FCD34D', fontWeight: 800, minWidth: 24, textAlign: 'right' },
  actions: {
    display: 'flex',
    gap: 12,
    marginTop: 12
  },
  btn: {
    background: 'linear-gradient(135deg, #7C3AED, #5B21B6)',
    color: '#fff',
    border: 'none',
    borderRadius: 8,
    padding: '12px 24px',
    fontWeight: 800,
    fontSize: 15,
    cursor: 'pointer'
  },
  btnSecondary: {
    background: 'rgba(30,27,46,0.8)',
    border: '1px solid #4B5563'
  }
};
