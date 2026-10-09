// OptionsOverlay.jsx - In-game options panel with granular volume, mute, track selector.
// Styled with the APK settings slider assets. Toggled from HUD options or ESC.
import React, { useState } from 'react';
import {
  getVolume, setVolume,
  getMusicVolume, setMusicVolume,
  getSfxVolume, setSfxVolume,
  isMuted, setMuted,
  isMusicMuted, setMusicMuted,
  isSfxMuted, setSfxMuted,
  playMusic, playSfx, SFX,
  MUSIC_TRACKS, getCurrentMusicTrack,
} from '../../audio.js';
import s from './OptionsOverlay.module.css';

export default function OptionsOverlay({ open, onClose, onOpenRules, onOpenGallery, onQuit }) {
  const [vol, setVol] = useState(() => Math.round(getVolume() * 100));
  const [musVol, setMusVol] = useState(() => Math.round(getMusicVolume() * 100));
  const [fxVol, setFxVol] = useState(() => Math.round(getSfxVolume() * 100));
  const [mute, setMute] = useState(() => isMuted());
  const [musMute, setMusMute] = useState(() => isMusicMuted());
  const [fxMute, setFxMute] = useState(() => isSfxMuted());
  const [currentTrack, setCurrentTrack] = useState(() => getCurrentMusicTrack());

  if (!open) return null;

  const handleMasterVol = (e) => {
    const v = Number(e.target.value);
    setVol(v);
    setVolume(v / 100);
  };

  const handleMusicVol = (e) => {
    const v = Number(e.target.value);
    setMusVol(v);
    setMusicVolume(v / 100);
  };

  const handleSfxVol = (e) => {
    const v = Number(e.target.value);
    setFxVol(v);
    setSfxVolume(v / 100);
  };

  const handleMuteAll = () => {
    const next = !mute;
    setMute(next);
    setMuted(next);
    setMusMute(next);
    setFxMute(next);
    if (!next) playSfx(SFX.BUTTON, 0.4);
  };

  const handleMusicMute = () => {
    const next = !musMute;
    setMusMute(next);
    setMusicMuted(next);
    if (!next) playSfx(SFX.BUTTON, 0.4);
  };

  const handleSfxMute = () => {
    const next = !fxMute;
    setFxMute(next);
    setSfxMuted(next);
    if (!next) playSfx(SFX.BUTTON, 0.4);
  };

  const handleTrackChange = (trackId) => {
    setCurrentTrack(trackId);
    playMusic(trackId, 0.35);
  };

  const testSfx = () => {
    playSfx(SFX.BUTTON_FINISH, 0.7);
  };

  return (
    <div className={s.backdrop} onClick={onClose} role="presentation">
      <div className={s.panel} onClick={(e) => e.stopPropagation()} role="dialog" aria-label="Options">
        <div className={s.header}>
          <img src="/ui/buttons/options_icon.webp" alt="" className={s.headerIcon} />
          <span className={s.title}>OPTIONS AUDIO & JEU</span>
          <button className={s.close} onClick={onClose} aria-label="Close" type="button">X</button>
        </div>

        {/* Master Volume */}
        <div className={s.row}>
          <span className={s.label}>VOLUME GÉNÉRAL</span>
          <div className={s.sliderWrap}>
            <input
              type="range"
              min="0"
              max="100"
              value={vol}
              onChange={handleMasterVol}
              className={s.slider}
              aria-label="Master volume"
            />
            <span className={s.volVal}>{vol}%</span>
          </div>
        </div>

        {/* Music Volume & Toggle */}
        <div className={s.row}>
          <span className={s.label}>MUSIQUE</span>
          <div className={s.sliderWrap}>
            <input
              type="range"
              min="0"
              max="100"
              value={musVol}
              onChange={handleMusicVol}
              className={s.slider}
              aria-label="Music volume"
            />
            <span className={s.volVal}>{musVol}%</span>
            <button
              className={`${s.miniToggle} ${musMute ? s.toggleOn : ''}`}
              onClick={handleMusicMute}
              aria-pressed={musMute}
              type="button"
              title="Couper la musique"
            >
              {musMute ? 'OFF' : 'ON'}
            </button>
          </div>
        </div>

        {/* SFX Volume & Toggle */}
        <div className={s.row}>
          <span className={s.label}>BRUITAGES (SFX)</span>
          <div className={s.sliderWrap}>
            <input
              type="range"
              min="0"
              max="100"
              value={fxVol}
              onChange={handleSfxVol}
              className={s.slider}
              aria-label="SFX volume"
            />
            <span className={s.volVal}>{fxVol}%</span>
            <button
              className={`${s.miniToggle} ${fxMute ? s.toggleOn : ''}`}
              onClick={handleSfxMute}
              aria-pressed={fxMute}
              type="button"
              title="Couper les bruitages"
            >
              {fxMute ? 'OFF' : 'ON'}
            </button>
          </div>
        </div>

        {/* Music Track Selector */}
        <div className={s.row}>
          <span className={s.label}>PISTE MUSICALE</span>
          <div className={s.trackRow}>
            {MUSIC_TRACKS.map((t) => (
              <button
                key={t.id}
                type="button"
                className={`${s.trackBtn} ${currentTrack === t.id ? s.trackBtnOn : ''}`}
                onClick={() => handleTrackChange(t.id)}
              >
                {t.label}
              </button>
            ))}
          </div>
        </div>

        {/* Test SFX & Global Mute Row */}
        <div className={s.buttonRow}>
          <button type="button" className={s.subBtn} onClick={testSfx}>
            🔊 TESTER LE SON
          </button>
          <button
            className={`${s.subBtn} ${mute ? s.toggleOn : ''}`}
            onClick={handleMuteAll}
            aria-pressed={mute}
            type="button"
          >
            {mute ? '🔇 TOUT COUPER' : '🔊 ACTIF'}
          </button>
        </div>

        <button className={s.ok} onClick={onClose} type="button" aria-label="OK">OK</button>

        {onOpenRules && (
          <button
            className={s.rules}
            type="button"
            onClick={() => { playSfx(SFX.BUTTON); onOpenRules(); }}
          >
            RÈGLES DU JEU
          </button>
        )}
        {onOpenGallery && (
          <button
            className={s.rules}
            type="button"
            onClick={() => { playSfx(SFX.BUTTON); onOpenGallery(); }}
          >
            ALMANACH DES CARTES
          </button>
        )}
        {onQuit && (
          <button className={s.rules} type="button" onClick={() => { playSfx(SFX.BUTTON); onQuit(); }}>
            QUITTER AU MENU
          </button>
        )}
      </div>
    </div>
  );
}
