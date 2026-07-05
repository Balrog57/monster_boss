// audio.js - Lightweight sound manager for Boss Monster.
// Wraps HTMLAudioElement with cached instances and a mute toggle.
// Sounds are stored under /assets/audio/{music,sfx}/ (APK-extracted, see tools/).

const SFX_BASE = '/assets/audio/sfx/';
const MUSIC_BASE = '/assets/audio/music/';

const sfxCache = {};
let musicEl = null;
let muted = false;

function path(kind, name) {
  const ext = kind === 'music' ? '.mp3' : '.wav';
  return (kind === 'music' ? MUSIC_BASE : SFX_BASE) + name + ext;
}

// Play a one-shot sound effect. Returns the Audio node (for volume control).
export function playSfx(name, volume = 0.6) {
  if (muted) return null;
  let el = sfxCache[name];
  if (!el) {
    el = new Audio(path('sfx', name));
    sfxCache[name] = el;
  }
  el.currentTime = 0;
  el.volume = volume;
  el.play().catch(() => { /* autoplay may block until user gesture */ });
  return el;
}

// Start looping background music. Replaces any current track.
export function playMusic(name, volume = 0.4) {
  if (muted) return;
  if (!musicEl) {
    musicEl = new Audio();
    musicEl.loop = true;
  }
  const src = path('music', name);
  if (musicEl.dataset.src !== src) {
    musicEl.src = src;
    musicEl.dataset.src = src;
    musicEl.volume = volume;
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
  if (muted) {
    if (musicEl) musicEl.pause();
  } else if (musicEl && musicEl.dataset.src) {
    musicEl.play().catch(() => {});
  }
}

export function isMuted() { return muted; }

// Named SFX constants (keep names in sync with files under assets/audio/sfx/)
export const SFX = {
  CARD_PLAY: 'sfx_activatecard',
  CARD_FLIP: 'ui_card_flip',
  BUTTON: 'ui_button_select',
  ROOM_FALL: 'sfx_room_fall',
  HERO_DEATH: 'char_hero_death',
  HERO_HURT: 'char_hero_hurt',
  LEVEL_UP: 'sting_levelup',
  WIN: 'sting_player_win',
  LOSE: 'sting_player_lose',
};
