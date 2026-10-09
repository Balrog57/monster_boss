// GameOverScreen.jsx - Victory or Defeat screen shown when the game ends,
// with comprehensive score breakdown, souls by class, and most lethal room.
import React, { useEffect, useState, useMemo } from 'react';
import { ErrorBoundary } from '../components/ui';
import { playSfx, SFX, stopMusic } from '../audio.js';
import { getCardImage } from '../../backend/game/cardData.js';
import s from './GameOverScreen.module.css';

const TREASURE_ICONS = {
  Cleric: '/ui/icons/treasure_holy.webp',
  Fighter: '/ui/icons/treasure_weapon.webp',
  Mage: '/ui/icons/treasure_book.webp',
  Thief: '/ui/icons/treasure_coin.webp',
};

export default function GameOverScreen({ winner, players, playerID, onReplay, onMenu }) {
  const [activeTab, setActiveTab] = useState('scores');
  const iWon = String(winner) === String(playerID);
  const winnerPlayer = players[winner];
  const winnerName = winnerPlayer?.boss?.name || `Player ${winner}`;
  const winnerBossImg = winnerPlayer?.boss ? getCardImage(winnerPlayer.boss.id, 'boss') : null;

  useEffect(() => {
    stopMusic();
    playSfx(iWon ? SFX.WIN : SFX.LOSE, 0.7);
    const timer = setTimeout(() => {
      const isFemale = winnerPlayer?.boss?.name?.match(/Cleopatra|Seducia|Gorgona|Bella/i);
      if (iWon) {
        playSfx(isFemale ? SFX.BOSS_FEMALE_VICTORY : SFX.BOSS_MALE_VICTORY, 0.7);
      } else {
        playSfx(isFemale ? SFX.BOSS_FEMALE_DEATH : SFX.BOSS_MALE_DEATH, 0.7);
      }
    }, 600);
    return () => clearTimeout(timer);
  }, [iWon, winnerPlayer]);

  const playerStats = useMemo(() => {
    return Object.entries(players || {}).map(([pid, p]) => {
      const souls = p.souls || [];
      const wounds = p.wounds || [];

      const soulsByClass = { Cleric: 0, Fighter: 0, Mage: 0, Thief: 0 };
      let epicSouls = 0;
      for (const hero of souls) {
        const cls = hero.class || hero.treasure || hero.treasureType;
        if (cls && soulsByClass[cls] !== undefined) {
          soulsByClass[cls] += 1;
        }
        if (hero.epic) epicSouls += 1;
      }

      let totalDungeonDmg = 0;
      let topRoom = null;
      let topDmg = -1;
      if (Array.isArray(p.dungeon)) {
        for (const stack of p.dungeon) {
          const top = Array.isArray(stack) ? stack[stack.length - 1] : stack;
          if (top) {
            const dmg = top.damage || 0;
            totalDungeonDmg += dmg;
            if (dmg > topDmg) {
              topDmg = dmg;
              topRoom = top;
            }
          }
        }
      }

      return {
        pid,
        name: p.boss?.name || `Player ${pid}`,
        soulsCount: souls.length,
        woundsCount: wounds.length,
        eliminated: p.eliminated,
        isMe: pid === String(playerID),
        soulsByClass,
        epicSouls,
        totalDungeonDmg,
        topRoomName: topRoom ? topRoom.name : '—',
        topRoomDmg: topDmg >= 0 ? topDmg : 0,
      };
    }).sort((a, b) => b.soulsCount - a.soulsCount || a.woundsCount - b.woundsCount);
  }, [players, playerID]);

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
                onError={(e) => { e.currentTarget.style.display = 'none'; }}
              />
            </div>
          )}

          <h1 className={`${s.title} ${iWon ? s.win : s.lose}`}>
            {iWon ? 'VICTORY' : 'DEFEAT'}
          </h1>
          <p className={s.headline}>
            {iWon ? `${winnerName} conquered the dungeon!` : `${winnerName} triumphed`}
          </p>

          {/* Navigation tabs */}
          <div className={s.tabBar} role="tablist">
            <button
              type="button"
              role="tab"
              aria-selected={activeTab === 'scores'}
              className={`${s.tabBtn} ${activeTab === 'scores' ? s.tabBtnOn : ''}`}
              onClick={() => setActiveTab('scores')}
            >
              CLASSEMENT FINAL
            </button>
            <button
              type="button"
              role="tab"
              aria-selected={activeTab === 'stats'}
              className={`${s.tabBtn} ${activeTab === 'stats' ? s.tabBtnOn : ''}`}
              onClick={() => setActiveTab('stats')}
            >
              BILAN STATISTIQUE
            </button>
          </div>

          {activeTab === 'scores' && (
            <div className={s.scoreboard} aria-label="Final scores">
              <div className={s.scoreHeader}>SCORES & RANGS</div>
              {playerStats.map((p, idx) => (
                <div
                  key={p.pid}
                  className={[s.scoreRow, p.isMe ? s.me : '', p.eliminated && !iWon ? s.dim : ''].filter(Boolean).join(' ')}
                >
                  <span className={s.rank}>{idx + 1}.</span>
                  <span className={s.playerName}>
                    {p.name}{p.isMe ? ' (vous)' : ''}{p.eliminated ? ' ☠ ÉLIMINÉ' : ''}
                  </span>
                  <span className={s.statLabel}>Âmes</span>
                  <span className={s.statVal}>{p.soulsCount}</span>
                  <span className={s.statLabel}>Blessures</span>
                  <span className={`${s.statVal} ${s.wounds}`}>{p.woundsCount} / 5</span>
                </div>
              ))}
            </div>
          )}

          {activeTab === 'stats' && (
            <div className={s.statsBoard} aria-label="Detailed statistics">
              <div className={s.scoreHeader}>DÉTAIL DES CONQUÊTES</div>
              <div className={s.statsGrid}>
                {playerStats.map((p) => (
                  <div key={p.pid} className={`${s.statCard} ${p.isMe ? s.statCardMe : ''}`}>
                    <div className={s.statCardTitle}>
                      {p.name} {p.isMe ? '(Vous)' : ''}
                    </div>

                    {/* Classes breakdown */}
                    <div className={s.statRow}>
                      <span className={s.statSubLabel}>Âmes capturées :</span>
                      <div className={s.iconsRow}>
                        {Object.entries(p.soulsByClass).map(([cls, count]) => (
                          <div key={cls} className={s.iconGroup} title={`${cls}: ${count}`}>
                            <img src={TREASURE_ICONS[cls]} alt={cls} className={s.miniIcon} />
                            <span>{count}</span>
                          </div>
                        ))}
                      </div>
                    </div>

                    {/* Epic Heroes */}
                    <div className={s.statRow}>
                      <span className={s.statSubLabel}>Héros Épiques vaincus :</span>
                      <span className={s.statNum}>🏆 {p.epicSouls}</span>
                    </div>

                    {/* Most lethal room */}
                    <div className={s.statRow}>
                      <span className={s.statSubLabel}>Salle la plus meurtrière :</span>
                      <span className={s.statHighlight}>
                        {p.topRoomName} ({p.topRoomDmg} DMG)
                      </span>
                    </div>

                    {/* Total Dungeon damage */}
                    <div className={s.statRow}>
                      <span className={s.statSubLabel}>Puissance totale du donjon :</span>
                      <span className={s.statNum}>{p.totalDungeonDmg} Dégâts</span>
                    </div>
                  </div>
                ))}
              </div>
            </div>
          )}

          <div className={s.actions}>
            <button className={s.ok} type="button" onClick={onReplay} aria-label="Play again" title="Rejouer" />
            <button className={s.menuBtn} type="button" onClick={onMenu}>MENU PRINCIPAL</button>
          </div>
        </div>
      </div>
    </ErrorBoundary>
  );
}
