// audio.js - Lightweight sound manager for Boss Monster.
// Wraps HTMLAudioElement with cached instances and a mute toggle.
// Sounds are stored under /assets/audio/{music,sfx}/ (APK-extracted, see tools/).

const SFX_BASE = '/audio/sfx/';
const MUSIC_BASE = '/audio/music/';

const sfxCache = {};
let musicEl = null;
let muted = false;
let musicMuted = false;
let sfxMuted = false;
let gameSpeed = 'normal';
// Master volume (0..1), persisted across sessions.
let volume = 0.8;
try {
  const stored = Number(localStorage.getItem('bm_volume'));
  if (!Number.isNaN(stored) && stored >= 0 && stored <= 1) volume = stored;
  muted = localStorage.getItem('bm_muted') === '1';
  musicMuted = localStorage.getItem('bm_music_muted') === '1' || muted;
  sfxMuted = localStorage.getItem('bm_sfx_muted') === '1' || muted;
  const speed = localStorage.getItem('bm_speed');
  if (speed === 'slow' || speed === 'normal' || speed === 'fast') gameSpeed = speed;
} catch { /* storage unavailable */ }

function path(kind, name) {
  const ext = kind === 'music' ? '.mp3' : '.wav';
  return (kind === 'music' ? MUSIC_BASE : SFX_BASE) + name + ext;
}

// Play a one-shot sound effect. Returns the Audio node (for volume control).
export function playSfx(name, vol = 0.6) {
  if (muted || sfxMuted) return null;
  let el = sfxCache[name];
  if (!el) {
    el = new Audio(path('sfx', name));
    sfxCache[name] = el;
  }
  el.currentTime = 0;
  el.volume = Math.min(1, vol * volume);
  el.play().catch(() => { /* autoplay may block until user gesture */ });
  return el;
}

// Start looping background music. Replaces any current track.
export function playMusic(name, vol = 0.4) {
  if (muted || musicMuted) return;
  if (!musicEl) {
    musicEl = new Audio();
    musicEl.loop = true;
  }
  const src = path('music', name);
  if (musicEl.dataset.src !== src) {
    musicEl.src = src;
    musicEl.dataset.src = src;
    musicEl.volume = Math.min(1, vol * volume);
    musicEl.play().catch(() => { /* will start after first gesture */ });
  }
}

export function stopMusic() {
  if (musicEl) {
    musicEl.pause();
    musicEl.currentTime = 0;
    musicEl.dataset.src = '';
  }
}

export function setMuted(m) {
  muted = m;
  musicMuted = m;
  sfxMuted = m;
  try {
    localStorage.setItem('bm_muted', m ? '1' : '0');
    localStorage.setItem('bm_music_muted', m ? '1' : '0');
    localStorage.setItem('bm_sfx_muted', m ? '1' : '0');
  } catch { /* ignore */ }
  if (muted || musicMuted) {
    if (musicEl) musicEl.pause();
  } else if (musicEl && musicEl.dataset.src) {
    musicEl.play().catch(() => {});
  }
}

export function isMuted() { return muted; }

export function setMusicMuted(m) {
  musicMuted = m;
  try { localStorage.setItem('bm_music_muted', m ? '1' : '0'); } catch { /* ignore */ }
  muted = musicMuted && sfxMuted;
  try { localStorage.setItem('bm_muted', muted ? '1' : '0'); } catch { /* ignore */ }
  if (musicMuted) {
    if (musicEl) musicEl.pause();
  } else if (musicEl && musicEl.dataset.src) {
    musicEl.play().catch(() => {});
  }
}

export function setSfxMuted(m) {
  sfxMuted = m;
  try { localStorage.setItem('bm_sfx_muted', m ? '1' : '0'); } catch { /* ignore */ }
  muted = musicMuted && sfxMuted;
  try { localStorage.setItem('bm_muted', muted ? '1' : '0'); } catch { /* ignore */ }
}

export function isMusicMuted() { return musicMuted; }
export function isSfxMuted() { return sfxMuted; }

export function setGameSpeed(v) {
  if (v !== 'slow' && v !== 'normal' && v !== 'fast') return;
  gameSpeed = v;
  try { localStorage.setItem('bm_speed', v); } catch { /* ignore */ }
}

export function getGameSpeed() { return gameSpeed; }

export function aiDelayMs() {
  return { slow: 700, normal: 300, fast: 80 }[gameSpeed] || 300;
}

// Master volume control (0..1). Applies to music immediately; SFX on next play.
export function setVolume(v) {
  volume = Math.max(0, Math.min(1, v));
  try { localStorage.setItem('bm_volume', String(volume)); } catch { /* ignore */ }
  if (musicEl) musicEl.volume = Math.min(1, musicEl.volume <= 0 ? 0 : volume * 0.4);
}

export function getVolume() { return volume; }

// Named SFX constants (keep names in sync with files under assets/audio/sfx/)
export const SFX = {
  CARD_PLAY: 'sfx_activatecard',
  CARD_FLIP: 'ui_card_flip',
  CARD_SLIDE_UP: 'ui_card_slide_up',
  CARD_SLIDE_DOWN: 'ui_card_slide_down',
  BUTTON: 'ui_button_select',
  BUTTON_BACK: 'ui_button_goback',
  BUTTON_FINISH: 'ui_button_finish',
  ROOM_FALL: 'sfx_room_fall',
  ROOM_MONSTER_LRG: 'sfx_room_monster_lrg',
  ROOM_MONSTER_MED: 'sfx_room_monster_med',
  ROOM_PHYSICAL: 'sfx_room_physical',
  ROOM_MAGIC: 'sfx_room_magic',
  HERO_DEATH: 'char_hero_death',
  HERO_HURT: 'char_hero_hurt',
  HERO_MOVE: 'char_hero_move',
  HERO_ATTACK: 'char_hero_attack',
  SPELL_BUFF: 'sfx_spell_buff',
  SPELL_DEBUFF: 'sfx_spell_debuff',
  SPELL_SUMMON: 'sfx_spell_summon',
  LEVEL_UP: 'sting_levelup',
  WIN: 'sting_player_win',
  LOSE: 'sting_player_lose',
};

// ---------------------------------------------------------------------------
// Global click SFX: attach a delegated listener that plays a button sound on
// any <button> click (and a flip sound on hand-card buttons). Idempotent.
// ---------------------------------------------------------------------------
let clickListenerInstalled = false;
export function installClickSounds() {
  if (clickListenerInstalled) return;
  clickListenerInstalled = true;
  document.addEventListener('click', (e) => {
    if (muted || sfxMuted) return;
    const btn = e.target.closest('button');
    if (!btn) return;
    // Hand card buttons (cards in play) get the activate-card sound; others
    // get the generic button-select sound.
    const isCard = btn.querySelector('img[alt]') && (btn.title || '').length > 0;
    playSfx(isCard ? SFX.CARD_PLAY : SFX.BUTTON, isCard ? 0.5 : 0.4);
  }, true);
}
