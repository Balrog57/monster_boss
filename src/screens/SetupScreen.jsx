// SetupScreen.jsx - Choose game mode: Solo (1v1 vs AI) or Online (human-vs-human).
import React from 'react';
import { playSfx, SFX } from '../audio.js';

export default function SetupScreen({ onStartLocal, onStartOnline, onBack }) {
  return (
    <div style={S.screen}>
      <img src="/ui/backgrounds/intro_bg.jpg" alt="" style={S.bg}
        onError={(e) => { e.currentTarget.style.display = 'none'; }} />
      <div style={S.overlay} />

      <div style={S.content}>
        <h1 style={S.title}>Nouvelle Partie</h1>
        <p style={S.subtitle}>Choisissez le mode de jeu</p>

        {/* Solo / 1v1 vs AI (only mode the original APK shipped with) */}
        <div style={S.sectionTitle}>Solo</div>
        <button
          style={S.soloBtn}
          onClick={() => { playSfx(SFX.BUTTON); onStartLocal(2); }}
        >
          <div style={S.optionLabel}>1 contre 1</div>
          <div style={S.optionSub}>Vous contre 1 IA</div>
        </button>

        {/* Online 1v1 lobby */}
        <div style={S.sectionTitle}>En ligne</div>
        <button
          style={S.onlineBtn}
          onClick={() => { playSfx(SFX.BUTTON); onStartOnline(); }}
        >
          <div style={S.optionLabel}>🌐 1 contre 1</div>
          <div style={S.optionSub}>Humain vs Humain (lobby)</div>
        </button>

        <button style={S.backBtn} onClick={() => { playSfx(SFX.BUTTON); onBack(); }}>
          ← Retour
        </button>
      </div>
    </div>
  );
}

const S = {
  screen: { position: 'fixed', inset: 0, display: 'flex', alignItems: 'center', justifyContent: 'center', background: '#0a0a0f', overflow: 'auto' },
  bg: { position: 'absolute', inset: 0, width: '100%', height: '100%', objectFit: 'cover', opacity: 0.5 },
  overlay: { position: 'absolute', inset: 0, background: 'rgba(10,10,15,0.6)' },
  content: { position: 'relative', zIndex: 2, display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 16, maxWidth: 560, padding: 24 },
  title: { fontSize: 40, fontWeight: 900, color: '#FCD34D', margin: 0, fontFamily: "'arcadepix', sans-serif", textShadow: '0 3px 12px rgba(252,211,77,0.4)' },
  subtitle: { color: '#9CA3AF', fontSize: 15, margin: 0 },
  sectionTitle: { fontSize: 12, fontWeight: 700, color: '#7C3AED', textTransform: 'uppercase', letterSpacing: 1.5, marginTop: 8, alignSelf: 'flex-start', marginLeft: '10%' },
  soloBtn: { width: 360, padding: '24px 20px', background: 'linear-gradient(135deg, #1f1a2e 0%, #2d2540 100%)', border: '2px solid #4C1D95', borderRadius: 12, cursor: 'pointer', display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 6, color: '#F3F4F6' },
  onlineBtn: { width: 360, padding: '20px', background: 'linear-gradient(135deg, #0f2a1f 0%, #1a3d2e 100%)', border: '2px solid #10B981', borderRadius: 12, cursor: 'pointer', display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 6, color: '#F3F4F6' },
  optionLabel: { fontSize: 20, fontWeight: 800, color: '#FCD34D' },
  optionSub: { fontSize: 12, color: '#A1A1AA' },
  backBtn: { marginTop: 12, background: 'none', border: '1px solid #4B5563', color: '#9CA3AF', padding: '8px 20px', borderRadius: 6, cursor: 'pointer', fontSize: 14 },
};
