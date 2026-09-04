// CardGallery.jsx - APK-style card browser (bosses, rooms, spells, heroes, items).
import React, { useMemo, useState } from 'react';
import { BOSSES, ROOMS, SPELLS, HEROES, ITEMS, EXPANSION_PACKS } from '../../cardData.js';
import Card from './Card.jsx';
import DetailPanel from './DetailPanel.jsx';
import s from './CardGallery.module.css';

const TABS = [
  { id: 'boss', label: 'BOSSES', cards: BOSSES, kind: 'boss' },
  { id: 'room', label: 'ROOMS', cards: ROOMS, kind: 'room' },
  { id: 'spell', label: 'SPELLS', cards: SPELLS, kind: 'spell' },
  { id: 'hero', label: 'HEROES', cards: HEROES, kind: 'hero' },
  { id: 'item', label: 'ITEMS', cards: ITEMS, kind: 'item' },
];

const SETS = [
  { id: 'all', label: 'ALL' },
  { id: 'base', label: 'BASE' },
  ...EXPANSION_PACKS.map((p) => ({ id: p.id, label: p.label })),
];

function cardKind(card, tabKind) {
  if (tabKind === 'hero') return card.epic ? 'epic-hero' : 'hero';
  return tabKind;
}

export default function CardGallery({ open, onClose }) {
  const [tab, setTab] = useState('boss');
  const [setId, setSetId] = useState('all');
  const [inspect, setInspect] = useState(null);

  const current = TABS.find((t) => t.id === tab) || TABS[0];
  const cards = useMemo(() => {
    const list = current.cards || [];
    if (setId === 'all') return list;
    return list.filter((c) => (c.set || 'base') === setId);
  }, [current, setId]);

  if (!open) return null;

  return (
    <div className={s.backdrop} onClick={onClose} role="presentation">
      <div
        className={s.panel}
        onClick={(e) => e.stopPropagation()}
        role="dialog"
        aria-modal="true"
        aria-label="Card gallery"
      >
        <div className={s.header}>
          <img src="/ui/ingame/card_gallery_top.webp" alt="" className={s.headerArt} />
          <span className={s.title}>CARD GALLERY</span>
          <button className={s.close} type="button" onClick={onClose} aria-label="Close" />
        </div>

        <div className={s.tabs} role="tablist">
          {TABS.map((t) => (
            <button
              key={t.id}
              className={`${s.tab} ${tab === t.id ? s.tabOn : ''}`}
              type="button"
              role="tab"
              aria-selected={tab === t.id}
              onClick={() => setTab(t.id)}
            >
              {t.label}
            </button>
          ))}
        </div>

        <div className={s.sets} role="group" aria-label="Expansion filter">
          {SETS.map((p) => (
            <button
              key={p.id}
              className={`${s.set} ${setId === p.id ? s.setOn : ''}`}
              type="button"
              aria-pressed={setId === p.id}
              onClick={() => setSetId(p.id)}
            >
              {p.label}
            </button>
          ))}
        </div>

        <div className={s.grid} role="list">
          {cards.map((card) => {
            const kind = cardKind(card, current.kind);
            return (
              <button
                key={card.id}
                type="button"
                className={s.tile}
                onClick={() => setInspect({ card, kind })}
                aria-label={card.name}
              >
                <Card card={card} kind={kind} size="sm" />
                <span className={s.tileName}>{card.name}</span>
              </button>
            );
          })}
          {cards.length === 0 && <div className={s.empty}>No cards in this filter.</div>}
        </div>
      </div>
      <DetailPanel inspect={inspect} onClose={() => setInspect(null)} />
    </div>
  );
}
