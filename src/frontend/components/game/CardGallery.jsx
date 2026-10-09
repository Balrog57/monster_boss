// CardGallery.jsx - Comprehensive card almanac & browser (bosses, rooms, spells, heroes, minibosses, items).
import React, { useMemo, useState, useEffect } from 'react';
import { BOSSES, ROOMS, SPELLS, HEROES, ITEMS, MINIBOSSES, EXPANSION_PACKS } from '../../../backend/game/cardData.js';
import Card from './Card.jsx';
import DetailPanel from './DetailPanel.jsx';
import s from './CardGallery.module.css';

const TABS = [
  { id: 'boss', label: 'BOSSES', cards: BOSSES, kind: 'boss' },
  { id: 'room', label: 'SALLES', cards: ROOMS, kind: 'room' },
  { id: 'spell', label: 'SORTS', cards: SPELLS, kind: 'spell' },
  { id: 'hero', label: 'HÉROS', cards: HEROES, kind: 'hero' },
  { id: 'miniboss', label: 'MINIBOSS', cards: MINIBOSSES, kind: 'miniboss' },
  { id: 'item', label: 'OBJETS', cards: ITEMS, kind: 'item' },
];

const SETS = [
  { id: 'all', label: 'TOUS' },
  { id: 'base', label: 'BASE' },
  ...EXPANSION_PACKS.map((p) => ({ id: p.id, label: p.label })),
];

const TREASURE_FILTERS = [
  { id: 'all', label: 'TOUS TRÉSORS' },
  { id: 'Cleric', label: 'FOI', icon: '/ui/icons/treasure_holy.webp' },
  { id: 'Fighter', label: 'FORCE', icon: '/ui/icons/treasure_weapon.webp' },
  { id: 'Mage', label: 'MAGIE', icon: '/ui/icons/treasure_book.webp' },
  { id: 'Thief', label: 'OR', icon: '/ui/icons/treasure_coin.webp' },
];

function cardKind(card, tabKind) {
  if (tabKind === 'hero') return card.epic ? 'epic-hero' : 'hero';
  return tabKind;
}

export default function CardGallery({ open, onClose }) {
  const [tab, setTab] = useState('boss');
  const [setId, setSetId] = useState('all');
  const [treasure, setTreasure] = useState('all');
  const [query, setQuery] = useState('');
  const [inspect, setInspect] = useState(null);

  const inspectRef = React.useRef(inspect);
  inspectRef.current = inspect;

  // Close gallery on Escape key only when no inspect card detail is open
  useEffect(() => {
    if (!open) return;
    const onKey = (e) => {
      if (e.key === 'Escape') {
        if (inspectRef.current) {
          e.preventDefault();
          e.stopPropagation();
          setInspect(null);
        } else {
          onClose();
        }
      }
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [open, onClose]);

  const current = TABS.find((t) => t.id === tab) || TABS[0];

  const cards = useMemo(() => {
    let list = current.cards || [];
    if (setId !== 'all') {
      list = list.filter((c) => (c.set || 'base') === setId);
    }
    if (treasure !== 'all') {
      list = list.filter((c) => {
        if (c.treasure === treasure || c.treasureType === treasure || c.class === treasure) return true;
        if (Array.isArray(c.treasures) && c.treasures.includes(treasure)) return true;
        if (typeof c.treasures === 'object' && c.treasures && c.treasures[treasure] > 0) return true;
        if (c.description && c.description.toLowerCase().includes(treasure.toLowerCase())) return true;
        return false;
      });
    }
    if (query.trim()) {
      const q = query.trim().toLowerCase();
      list = list.filter((c) => {
        const name = (c.name || '').toLowerCase();
        const desc = (c.description || c.levelUpDesc || '').toLowerCase();
        const sub = (c.subtitle || '').toLowerCase();
        const id = (c.id || '').toLowerCase();
        return name.includes(q) || desc.includes(q) || sub.includes(q) || id.includes(q);
      });
    }
    return list;
  }, [current, setId, treasure, query]);

  if (!open) return null;

  return (
    <div className={s.backdrop} onClick={onClose} role="presentation">
      <div
        className={s.panel}
        onClick={(e) => e.stopPropagation()}
        role="dialog"
        aria-modal="true"
        aria-label="Almanach et galerie de cartes"
      >
        <div className={s.header}>
          <img src="/ui/ingame/card_gallery_top.webp" alt="" className={s.headerArt} />
          <span className={s.title}>ALMANACH & GALERIE DES CARTES</span>
          <button className={s.close} type="button" onClick={onClose} aria-label="Fermer" />
        </div>

        {/* Top Type Tabs */}
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
              {t.label} ({(t.cards || []).length})
            </button>
          ))}
        </div>

        {/* Filter Controls Row */}
        <div className={s.controlsBar}>
          <div className={s.searchWrap}>
            <input
              type="text"
              className={s.searchInput}
              placeholder="Rechercher par nom, effet, sous-type, id..."
              value={query}
              onChange={(e) => setQuery(e.target.value)}
              aria-label="Recherche de cartes"
            />
            {query && (
              <button
                type="button"
                className={s.clearBtn}
                onClick={() => setQuery('')}
                aria-label="Effacer la recherche"
              >
                ✕
              </button>
            )}
          </div>

          <div className={s.treasuresRow}>
            {TREASURE_FILTERS.map((tf) => (
              <button
                key={tf.id}
                type="button"
                className={`${s.treasureBtn} ${treasure === tf.id ? s.treasureBtnOn : ''}`}
                onClick={() => setTreasure(tf.id)}
                title={`Filtrer par trésor: ${tf.label}`}
              >
                {tf.icon && <img src={tf.icon} alt="" className={s.treasureIcon} />}
                <span>{tf.label}</span>
              </button>
            ))}
          </div>

          <div className={s.countBadge}>
            {cards.length} carte(s)
          </div>
        </div>

        {/* Sets Filter */}
        <div className={s.sets} role="group" aria-label="Filtre d'extensions">
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

        {/* Cards Grid */}
        <div className={s.grid} role="list">
          {cards.map((card) => {
            const kind = cardKind(card, current.kind);
            return (
              <button
                key={card.id}
                type="button"
                className={s.tile}
                onClick={() => setInspect({ card, kind })}
                aria-label={`${card.name} (${card.id})`}
              >
                <Card card={card} kind={kind} size="sm" />
                <span className={s.tileName}>{card.name}</span>
                <span className={s.tileId}>{card.id}</span>
              </button>
            );
          })}
          {cards.length === 0 && (
            <div className={s.empty}>
              <p>Aucune carte ne correspond aux filtres actuels.</p>
              <button
                type="button"
                className={s.resetBtn}
                onClick={() => { setSetId('all'); setTreasure('all'); setQuery(''); }}
              >
                Réinitialiser les filtres
              </button>
            </div>
          )}
        </div>
      </div>
      <DetailPanel inspect={inspect} onClose={() => setInspect(null)} />
    </div>
  );
}
