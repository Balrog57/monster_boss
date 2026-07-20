// GameOverScreen.jsx - Victory or Defeat screen shown when the game ends.
import React, { useEffect } from 'react';
import { Button, ErrorBoundary } from '../components/ui';
import { playSfx, SFX, stopMusic } from '../audio.js';
import { getCardImage } from '../cardData.js';
import s from './GameOverScreen.module.css';

export default function GameOverScreen({ winner, players, playerID, onReplay, onMenu }) {
  const iWon = String(winner) === String(playerID);
  const winnerPlayer = players[winner];
  const winnerName = winnerPlayer?.boss?.name || `Joueur ${winner}`;
  const winnerBossImg = winnerPlayer?.boss ? getCardImage(winnerPlayer.boss.id, 'boss') : null;

  useEffect(() => {
    stopMusic();
    playSfx(iWon ? SFX.WIN : SFX.LOSE, 0.7);
  }, [iWon]);

  // Scoreboard: rank players by souls, then wounds (fewer = better)
  const ranked = Object.entries(players)
    .map(([pid, p]) => ({
      pid,
      name: p.boss?.name || `Joueur ${pid}`,
      souls: (p.souls || []).length,
      wounds: (p.wounds || []).length,
      eliminated: p.eliminated,
      isMe: pid === String(playerID),
    }))
    .sort((a, b) => b.souls - a.souls || a.wounds - b.wounds);

  return (
    <ErrorBoundary>
      <div className={`${s.screen} ${iWon ? s.winBg : s.loseBg}`} role="dialog" aria-live="assertive">
        <div className={s.content}>
          {/* Winner boss portrait with APK shine effect */}
          {winnerBossImg && (
            <div className={s.bossShowcase}>
              {iWon && <img src="/ui/gradients/winner_boss_shine.png" alt="" className={s.shine} aria-hidden="true" />}
              <img
                src={winnerBossImg}
                alt={winnerName}
                className={`${s.bossImg} ${iWon ? '' : s.bossDefeated}`}
              />
            </div>
          )}

          <h1 className={`${s.title} ${iWon ? s.win : s.lose}`}>
            {iWon ? '🏆 VICTOIRE !' : '💀 DÉFAITE'}
          </h1>
          <p className={s.headline}>
            {iWon ? `${winnerName} a conquis le donjon !` : `${winnerName} a triomphé`}
          </p>

          <div className={s.scoreboard} aria-label="Scores finaux">
            <div className={s.scoreHeader}>Scores finaux</div>
            {ranked.map((p, idx) => (
              <div
                key={p.pid}
                className={[s.scoreRow, p.isMe ? s.me : '', p.eliminated && !iWon ? s.dim : ''].filter(Boolean).join(' ')}
              >
                <span className={s.rank}>{idx + 1}.</span>
                <span className={s.playerName}>
                  {p.name}{p.isMe && ' (vous)'}{p.eliminated && ' †'}
                </span>
                <span className={s.statLabel}>âmes</span>
                <span className={s.statVal}>{p.souls}</span>
                <span className={s.statLabel}>blessures</span>
                <span className={`${s.statVal} ${s.wounds}`}>{p.wounds}</span>
              </div>
            ))}
          </div>

          <div className={s.actions}>
            <Button variant="primary" onClick={onReplay}>Rejouer</Button>
            <Button variant="ghost" onClick={onMenu}>Menu principal</Button>
          </div>
        </div>
      </div>
    </ErrorBoundary>
  );
}