// SetupScreen.jsx - Choose game mode: Solo (1v1 vs AI) or Online (human vs human).
import React from 'react';
import { Screen, Button } from '../components/ui';
import { playSfx, SFX } from '../audio.js';
import s from './SetupScreen.module.css';

export default function SetupScreen({ onStartLocal, onStartOnline, onBack }) {
  return (
    <Screen
      id="main-content"
      bg="/ui/backgrounds/intro_bg.jpg"
      bgOpacity={0.5}
    >
      <h1 className={s.title}>Nouvelle Partie</h1>
      <p className={s.subtitle}>Choisissez le mode de jeu</p>

      <div className={s.sectionTitle}>Solo / Local</div>

      <button className={`${s.modeCard} ${s.solo}`} type="button"
        onClick={() => { playSfx(SFX.BUTTON); onStartLocal(2); }}
        aria-label="1 contre 1, vous contre une IA"
      >
        <div className={s.optionLabel}>1 contre 1</div>
        <div className={s.optionSub}>Vous contre 1 IA</div>
      </button>

      <button className={`${s.modeCard} ${s.solo}`} type="button"
        onClick={() => { playSfx(SFX.BUTTON); onStartLocal(3); }}
        aria-label="1 contre 2 IA, 3 joueurs total"
      >
        <div className={s.optionLabel}>1 contre 2 IA</div>
        <div className={s.optionSub}>3 joueurs total</div>
      </button>

      <button className={`${s.modeCard} ${s.solo}`} type="button"
        onClick={() => { playSfx(SFX.BUTTON); onStartLocal(4); }}
        aria-label="1 contre 3 IA, 4 joueurs total"
      >
        <div className={s.optionLabel}>1 contre 3 IA</div>
        <div className={s.optionSub}>4 joueurs total</div>
      </button>

      <div className={s.sectionTitle}>En ligne</div>

      <button className={`${s.modeCard} ${s.online}`} type="button"
        onClick={() => { playSfx(SFX.BUTTON); onStartOnline(); }}
        aria-label="Multijoueur en ligne, 2 à 4 joueurs humains via lobby"
      >
        <div className={s.optionLabel}>🌐 Multijoueur</div>
        <div className={s.optionSub}>2 à 4 joueurs humains (lobby)</div>
      </button>

      <Button variant="ghost" onClick={() => { playSfx(SFX.BUTTON); onBack(); }}>
        ← Retour
      </Button>
    </Screen>
  );
}