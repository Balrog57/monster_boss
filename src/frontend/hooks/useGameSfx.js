// useGameSfx.js - Hook that watches G.logs and triggers contextual SFX.
//
// Parses new log entries since last render and plays the appropriate sound
// based on pattern matching. This keeps SFX triggers decoupled from game logic.
import { useEffect, useRef } from 'react';
import { playSfx, SFX } from '../audio.js';

// Log patterns → SFX mapping (order matters: first match wins)
const LOG_PATTERNS = [
  { re: /LEVELED UP/i, sfx: SFX.LEVEL_UP, vol: 0.7 },
  { re: /defeated!.*soul/i, sfx: SFX.HERO_DEATH, vol: 0.6 },
  { re: /survives!.*wound/i, sfx: SFX.HERO_ATTACK, vol: 0.6 },
  { re: /lured to Player/i, sfx: SFX.HERO_MOVE, vol: 0.4 },
  { re: /enters Player.*dungeon/i, sfx: SFX.HERO_MOVE, vol: 0.35 },
  { re: /deals \d+ damage/i, sfx: SFX.ROOM_PHYSICAL, vol: 0.4 },
  { re: /Revealed .+ for Player/i, sfx: SFX.CARD_FLIP, vol: 0.5 },
  { re: /built a room face down/i, sfx: SFX.ROOM_FALL, vol: 0.5 },
  { re: /cast .+/i, sfx: SFX.SPELL_BUFF, vol: 0.5 },
  { re: /Game Over!.*wins/i, sfx: SFX.WIN, vol: 0.8 },
];

export function useGameSfx(G) {
  const prevLogLen = useRef(0);

  useEffect(() => {
    if (!G || !G.logs) return;
    const logs = G.logs;
    const start = prevLogLen.current;
    prevLogLen.current = logs.length;

    if (start >= logs.length) return; // no new logs

    // Process only the last few new logs (avoid SFX spam on initial load)
    const newLogs = logs.slice(Math.max(start, logs.length - 5));
    for (const log of newLogs) {
      for (const { re, sfx, vol } of LOG_PATTERNS) {
        if (re.test(log)) {
          playSfx(sfx, vol);
          break; // one SFX per log entry
        }
      }
    }
  }, [G?.logs?.length]);
}
