// useKeyboardShortcuts.js - Desktop keyboard navigation & shortcuts for Boss Monster.
// Keys: 1-9 (select card), Space (Pass/Done/Resolve), Esc (close/deselect),
// M (mute toggle), Tab / Shift-Tab (cycle dungeon rooms), R/S (switch tabs).
import { useEffect, useRef } from 'react';
import { isMuted, setMuted } from '../audio.js';

export function getDigitKey(e) {
  if (e.key >= '1' && e.key <= '9') {
    return parseInt(e.key, 10);
  }
  if (e.code && e.code.startsWith('Digit')) {
    const d = parseInt(e.code.replace('Digit', ''), 10);
    if (d >= 1 && d <= 9) return d;
  }
  if (e.code && e.code.startsWith('Numpad')) {
    const d = parseInt(e.code.replace('Numpad', ''), 10);
    if (d >= 1 && d <= 9) return d;
  }
  return null;
}

export function useKeyboardShortcuts({
  enabled = true,
  hand = [],
  handTab = 'rooms',
  setHandTab,
  selectedCard = null,
  setSelectedCard,
  dungeonRooms = [],
  setInspect,
  setPreview,
  canPass = false,
  onPass,
  canResolveHero = false,
  onResolveHero,
  optionsOpen = false,
  setOptionsOpen,
  rulesOpen = false,
  setRulesOpen,
  galleryOpen = false,
  setGalleryOpen,
  emotesOpen = false,
  setEmotesOpen,
  onToggleEmotes,
  inspectOpen = false,
  onCloseInspect,
  onCancelSelection,
  onToggleMute,
}) {
  const currentInspectRoomIdx = useRef(-1);

  useEffect(() => {
    if (!enabled) return;

    const onKeyDown = (e) => {
      // Don't intercept shortcuts when typing in inputs/textareas
      const tag = e.target?.tagName?.toLowerCase();
      if (tag === 'input' || tag === 'textarea' || tag === 'select') {
        if (e.key === 'Escape') {
          e.target.blur();
        }
        return;
      }

      // 1. ESCAPE: close overlays, modal, or cancel selection
      if (e.key === 'Escape') {
        e.preventDefault();
        if (emotesOpen) { setEmotesOpen?.(false); return; }
        if (rulesOpen) { setRulesOpen?.(false); return; }
        if (galleryOpen) { setGalleryOpen?.(false); return; }
        if (optionsOpen) { setOptionsOpen?.(false); return; }
        if (inspectOpen) { onCloseInspect?.(); return; }
        onCancelSelection?.();
        return;
      }

      // 2. M / m: Toggle Mute
      if (e.key === 'm' || e.key === 'M') {
        e.preventDefault();
        const next = !isMuted();
        setMuted(next);
        onToggleMute?.(next);
        return;
      }

      // 3. E / e: Toggle Emotes
      if ((e.key === 'e' || e.key === 'E') && onToggleEmotes) {
        e.preventDefault();
        onToggleEmotes();
        return;
      }

      // 4. TAB / SHIFT+TAB: Cycle dungeon rooms for inspection
      if (e.key === 'Tab') {
        if (dungeonRooms && dungeonRooms.length > 0) {
          e.preventDefault();
          const step = e.shiftKey ? -1 : 1;
          const nextIdx = (currentInspectRoomIdx.current + step + dungeonRooms.length) % dungeonRooms.length;
          currentInspectRoomIdx.current = nextIdx;
          const target = dungeonRooms[nextIdx];
          if (target) {
            setInspect?.({ card: target, kind: 'room' });
            setPreview?.({ card: target, kind: 'room' });
          }
        }
        return;
      }

      // 5. R / S: Switch Hand Tabs
      if ((e.key === 'r' || e.key === 'R') && setHandTab) {
        setHandTab('rooms');
        return;
      }
      if ((e.key === 's' || e.key === 'S') && setHandTab) {
        setHandTab('spells');
        return;
      }

      // 5. SPACE: Pass, Done, or Advance Hero
      if (e.key === ' ' || e.code === 'Space') {
        e.preventDefault();
        if (canResolveHero && onResolveHero) {
          onResolveHero();
          return;
        }
        if (canPass && onPass) {
          onPass();
          return;
        }
        return;
      }

      // 6. 1-9: Select card from hand in current tab
      const num = getDigitKey(e);
      if (num != null) {
        const visibleCards = (hand || [])
          .map((c, i) => ({ c, i }))
          .filter(({ c }) => handTab === 'rooms' ? c.isRoom : c.isSpell);

        const target = visibleCards[num - 1];
        if (target) {
          e.preventDefault();
          if (selectedCard === target.i) {
            setSelectedCard?.(null);
          } else {
            setSelectedCard?.(target.i);
            setPreview?.({ card: target.c, kind: target.c.isSpell ? 'spell' : 'room' });
          }
        }
      }
    };

    window.addEventListener('keydown', onKeyDown);
    return () => window.removeEventListener('keydown', onKeyDown);
  }, [
    enabled, hand, handTab, setHandTab, selectedCard, setSelectedCard, dungeonRooms,
    setInspect, setPreview, canPass, onPass, canResolveHero, onResolveHero,
    optionsOpen, setOptionsOpen, rulesOpen, setRulesOpen, galleryOpen, setGalleryOpen,
    emotesOpen, setEmotesOpen, onToggleEmotes,
    inspectOpen, onCloseInspect, onCancelSelection, onToggleMute,
  ]);
}
