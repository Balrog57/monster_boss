// GameOverScreen.jsx - Victory or Defeat screen shown when the game ends.
import React, { useEffect } from 'react';
import { ErrorBoundary } from '../components/ui';
import { playSfx, SFX, stopMusic } from '../audio.js';
import { getCardImage } from '../cardData.js';
import s from './GameOverScreen.module.css';

export default function GameOverScreen({ winner, players, playerID, onReplay, onMenu }) {
  const iWon = String(winner) === String(playerID);
  const winnerPlayer = players[winner];
  const winnerName = winnerPlayer?.boss?.name || `Player ${winner}`;
  const winnerBossImg = winnerPlayer?.boss ? getCardImage(winnerPlayer.boss.id, 'boss') : null;

  useEffect(() => {
    stopMusic();
    playSfx(iWon ? SFX.WIN : SFX.LOSE, 0.7);
  }, [iWon]);

  const ranked = Object.entries(players)
    .map(([pid, p]) => ({
      pid,
      name: p.boss?.name || `Player ${pid}`,
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
          {winnerBossImg && (
            <div className={s.bossShowcase}>
              {iWon && <img src="/ui/gradients/winner_boss_shine.webp" alt="" className={s.shine} aria-hidden="true" />}
              <img
                src={winnerBossImg}
                alt={winnerName}
                className={`${s.bossImg} ${iWon ? '' : s.bossDefeated}`}
              />
            </div>
          )}

          <h1 className={`${s.title} ${iWon ? s.win : s.lose}`}>
            {iWon ? 'VICTORY' : 'DEFEAT'}
          </h1>
          <p className={s.headline}>
            {iWon ? `${winnerName} conquered the dungeon!` : `${winnerName} triumphed`}
          </p>

          <div className={s.scoreboard} aria-label="Final scores">
            <div className={s.scoreHeader}>FINAL SCORES</div>
            {ranked.map((p, idx) => (
              <div
                key={p.pid}
                className={[s.scoreRow, p.isMe ? s.me : '', p.eliminated && !iWon ? s.dim : ''].filter(Boolean).join(' ')}
              >
                <span className={s.rank}>{idx + 1}.</span>
                <span className={s.playerName}>
                  {p.name}{p.isMe ? ' (you)' : ''}{p.eliminated ? ' X' : ''}
                </span>
                <span className={s.statLabel}>souls</span>
                <span className={s.statVal}>{p.souls}</span>
                <span className={s.statLabel}>wounds</span>
                <span className={`${s.statVal} ${s.wounds}`}>{p.wounds}</span>
              </div>
            ))}
          </div>

          <div className={s.actions}>
            <button className={s.ok} type="button" onClick={onReplay} aria-label="Play again" />
            <button className={s.menuBtn} type="button" onClick={onMenu}>MAIN MENU</button>
          </div>
        </div>
      </div>
    </ErrorBoundary>
  );
}
