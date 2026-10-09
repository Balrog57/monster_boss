// SetupScreen.jsx - Solo match setup: Player count & Expansion pack selection.
import React, { useState } from 'react';
import { playSfx, SFX } from '../audio.js';
import { BOSSES, EXPANSION_PACKS } from '../../backend/game/cardData.js';
import GameStage from '../components/game/GameStage.jsx';
import Card from '../components/game/Card.jsx';
import s from './SetupScreen.module.css';

const FANS = [
  { n: 2, bossId: 'BMA006' },
  { n: 3, bossId: 'BMA005' },
  { n: 4, bossId: 'BMA001' },
  { n: 5, bossId: 'CRL001' },
  { n: 6, bossId: 'CRL001' },
];

export default function SetupScreen({ onStartLocal, onBack }) {
  const [n, setN] = useState(2);
  const [selectedPacks, setSelectedPacks] = useState(['hidden-heroes', 'tools', 'players-choice']);

  const handleSelectN = (val) => {
    playSfx(SFX.BUTTON);
    setN(val);
    if (val > 4 && !selectedPacks.includes('crash-landing')) {
      setSelectedPacks((prev) => [...prev, 'crash-landing']);
    }
  };

  const togglePack = (packId) => {
    playSfx(SFX.BUTTON);
    setSelectedPacks((prev) => {
      const active = prev.includes(packId);
      const next = active ? prev.filter((id) => id !== packId) : [...prev, packId];
      if (active && packId === 'crash-landing' && n > 4) {
        setN(4);
      }
      return next;
    });
  };

  const onOk = () => {
    playSfx(SFX.BUTTON);
    onStartLocal(n, selectedPacks, 1);
  };

  const onBackClick = () => {
    playSfx(SFX.BUTTON);
    onBack();
  };

  return (
    <GameStage bg="/ui/backgrounds/menu_bg.webp">
      <div className={s.layout} id="main-content">
        <img src="/ui/logos/bm_logo.webp" alt="" className={s.logo} />
        <button className={s.back} onClick={onBackClick} type="button" aria-label="Back" />

        <div className={s.prompt}>HOW MANY PLAYERS?</div>
        <div className={s.fans} role="radiogroup" aria-label="How many players">
          {FANS.map(({ n: v, bossId }) => {
            const boss = BOSSES.find((b) => b.id === bossId) || BOSSES[0];
            const on = n === v;
            return (
              <button
                key={v}
                className={`${s.fan} ${on ? s.fanOn : s.fanOff}`}
                onClick={() => handleSelectN(v)}
                type="button"
                role="radio"
                aria-checked={on}
              >
                <span className={`${s.num} ${on ? s.numOn : ''}`}>{v}</span>
                <Card card={boss} kind="boss" size="md" />
              </button>
            );
          })}
        </div>

        {/* Expansion Packs Selector */}
        <div className={s.expansionsContainer}>
          <div className={s.expansionsHeader}>
            <span>EXTENSIONS DISPONIBLES</span>
            <span className={s.expansionsCount}>({selectedPacks.length}/{EXPANSION_PACKS.length} actives)</span>
          </div>

          <div className={s.expansionsRow}>
            {EXPANSION_PACKS.map((pack) => {
              const active = selectedPacks.includes(pack.id);
              return (
                <button
                  key={pack.id}
                  type="button"
                  className={`${s.packCard} ${active ? s.packCardActive : s.packCardInactive}`}
                  onClick={() => togglePack(pack.id)}
                  title={`${pack.label} - ${active ? 'Cliquer pour désactiver' : 'Cliquer pour activer'}`}
                >
                  <div className={s.packCoverWrap}>
                    <img
                      src={pack.cover}
                      alt={pack.label}
                      className={s.packCover}
                      onError={(e) => { e.currentTarget.style.display = 'none'; }}
                    />
                    <div className={`${s.packStateBadge} ${active ? s.packBadgeOn : s.packBadgeOff}`}>
                      {active ? '✓ ACTIF' : 'INACTIF'}
                    </div>
                  </div>
                  <div className={s.packInfo}>
                    <div className={s.packName}>{pack.label}</div>
                    <div className={s.packTag}>{pack.tag}</div>
                  </div>
                </button>
              );
            })}
          </div>
        </div>

        <div className={s.hint}>
          {n === 2 ? 'YOU VS 1 AI' : `YOU VS ${n - 1} AI`}
          <span className={s.hintSep}>•</span>
          <span>{selectedPacks.length} EXTENSION(S) ACTIVÉE(S)</span>
        </div>

        <button className={s.ok} onClick={onOk} type="button" aria-label="OK" />
      </div>
    </GameStage>
  );
}
