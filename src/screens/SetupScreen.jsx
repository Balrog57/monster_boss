// SetupScreen.jsx - APK "HOW MANY PLAYERS?" then expansion pack select.
import React, { useState } from 'react';
import { playSfx, SFX } from '../audio.js';
import { BOSSES, EXPANSION_PACKS } from '../cardData.js';
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
  const [step, setStep] = useState('players'); // players | expansions
  const [n, setN] = useState(2);
  const [humans, setHumans] = useState(1);
  const [packs, setPacks] = useState([]);

  const togglePack = (id) => {
    playSfx(SFX.BUTTON);
    setPacks((cur) => (cur.includes(id) ? cur.filter((x) => x !== id) : [...cur, id]));
  };

  const onOkPlayers = () => {
    playSfx(SFX.BUTTON);
    setStep('expansions');
  };

  const onOkExpansions = () => {
    playSfx(SFX.BUTTON);
    let selected = [...packs];
    if (n >= 5 && !selected.includes('crash-landing')) {
      selected = [...selected, 'crash-landing'];
    }
    onStartLocal(n, selected, humans);
  };

  const onBackClick = () => {
    playSfx(SFX.BUTTON);
    if (step === 'expansions') setStep('players');
    else onBack();
  };

  return (
    <GameStage bg="/ui/backgrounds/menu_bg.webp">
      <div className={s.layout} id="main-content">
        <img src="/ui/logos/bm_logo.webp" alt="" className={s.logo} />
        <button className={s.back} onClick={onBackClick} type="button" aria-label="Back" />

        {step === 'players' && (
          <>
            <div className={s.prompt}>HOW MANY PLAYERS?</div>
            <div className={s.fans} role="radiogroup" aria-label="How many players">
              {FANS.map(({ n: v, bossId }) => {
                const boss = BOSSES.find((b) => b.id === bossId) || BOSSES[0];
                const on = n === v;
                return (
                  <button
                    key={v}
                    className={`${s.fan} ${on ? s.fanOn : s.fanOff}`}
                    onClick={() => { playSfx(SFX.BUTTON); setN(v); }}
                    type="button"
                    role="radio"
                    aria-checked={on}
                  >
                    <span className={`${s.num} ${on ? s.numOn : ''}`}>{v}</span>
                    <Card card={boss} kind="boss" size="lg" />
                  </button>
                );
              })}
            </div>
            <div className={s.hint}>
              {n === 2 && humans === 1 ? 'You vs 1 AI' : `${humans} human(s), ${Math.max(0, n - humans)} AI`}
              {n >= 5 ? ' — Crash Landing enabled' : ''}
            </div>
            <label className={s.label} htmlFor="setup-humans">HUMAN PLAYERS</label>
            <select
              id="setup-humans"
              className={s.input}
              value={humans}
              onChange={(e) => setHumans(Number(e.target.value))}
            >
              {Array.from({ length: n }, (_, i) => i + 1).map((v) => (
                <option key={v} value={v}>{v}</option>
              ))}
            </select>
            <button className={s.ok} onClick={onOkPlayers} type="button" aria-label="OK" />
          </>
        )}

        {step === 'expansions' && (
          <>
            <div className={s.prompt}>SELECT EXPANSIONS</div>
            <div className={s.packs} role="group" aria-label="Expansion packs">
              {EXPANSION_PACKS.map((pack) => {
                const on = packs.includes(pack.id);
                return (
                  <button
                    key={pack.id}
                    className={`${s.pack} ${on ? s.packOn : ''}`}
                    onClick={() => togglePack(pack.id)}
                    type="button"
                    aria-pressed={on}
                    aria-label={pack.label}
                  >
                    <img src={pack.cover} alt="" draggable={false} />
                  </button>
                );
              })}
            </div>
            <div className={s.hint}>
              {packs.length === 0
                ? 'Base set only'
                : packs.length === 1
                  ? '1 pack selected'
                  : `${packs.length} packs selected`}
            </div>
            <button
              className={s.ok}
              onClick={onOkExpansions}
              type="button"
              aria-label="OK"
            />
          </>
        )}
      </div>
    </GameStage>
  );
}
