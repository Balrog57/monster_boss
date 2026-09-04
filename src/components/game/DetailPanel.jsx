// DetailPanel.jsx - Card inspection overlay with full stats, resources, and authentic art.
// Props: inspect: { card, kind } | null, onClose: () => void
import React, { useEffect, useRef } from 'react';
import {
  TREASURE_NAMES,
  TREASURE_RESOURCE_LABEL,
  treasureIcon,
  roomTypeIcon,
  getCardImage,
  getWikiCardImage,
  getApkCardImage,
} from '../../cardData.js';
import s from './DetailPanel.module.css';

export default function DetailPanel({ inspect, onClose }) {
  const closeBtnRef = useRef(null);

  // Focus the close button on open + Escape to close.
  useEffect(() => {
    if (!inspect) return;
    const t = setTimeout(() => closeBtnRef.current?.focus(), 20);
    const onKey = (e) => { if (e.key === 'Escape') onClose(); };
    document.addEventListener('keydown', onKey);
    return () => { clearTimeout(t); document.removeEventListener('keydown', onKey); };
  }, [inspect, onClose]);

  if (!inspect) return null;
  const { card, kind } = inspect;
  const imageKind = kind === 'epic-hero' ? 'epic-hero' : kind;
  const imgPath = getCardImage(card?.id, imageKind);
  const wikiSrc = getWikiCardImage(card?.id, imageKind);

  // Normalize treasures
  const treasures = card?.treasures || (card?.treasure != null ? [card.treasure] : []);
  const isHero = kind === 'hero' || kind === 'epic-hero' || card?.hp != null;
  const isRoom = kind === 'room' || card?.damage != null;
  const isBoss = kind === 'boss' || card?.xp != null;
  const isSpell = kind === 'spell' || card?.category != null;
  const isItem = kind === 'item' || card?.isItem;

  return (
    <div className={s.overlay} onClick={onClose} role="presentation">
      <div
        className={s.panel}
        onClick={(e) => e.stopPropagation()}
        role="dialog"
        aria-modal="true"
        aria-label={card?.name || 'Card details'}
        tabIndex={-1}
      >
        <div className={s.header}>
          <div>
            <div className={s.title}>{card?.name || 'Card'}</div>
            {card?.subtitle && <div className={s.subtitle}>{card.subtitle}</div>}
          </div>
          <button className={s.close} onClick={onClose} aria-label="Close" type="button" ref={closeBtnRef}>×</button>
        </div>

        <div className={s.imgWrap}>
          <img
            src={imgPath}
            alt={card?.name || 'card'}
            className={s.img}
            onError={(e) => {
              const apkSrc = getApkCardImage(card?.id, imageKind);
              if (apkSrc && e.currentTarget.src && e.currentTarget.src.includes('/cards/')) {
                e.currentTarget.src = apkSrc;
                return;
              }
              if (wikiSrc && e.currentTarget.src && e.currentTarget.src.includes('/apk_cards/')) {
                e.currentTarget.src = wikiSrc;
                return;
              }
              e.currentTarget.style.display = 'none';
            }}
          />
        </div>

        {/* Dynamic Characteristics & Stats */}
        <div className={s.statsSection}>
          <div className={s.sectionHeader}>Caractéristiques / Stats</div>
          <div className={s.statsGrid}>
            {/* Hero Stats */}
            {isHero && (
              <>
                <div className={s.statBadge} title="Points de vie">
                  <img src="/ui/ingame/health_hero_icon.webp" alt="HP" className={s.statIcon} />
                  <span><strong>{card.hp} PV</strong> (Health)</span>
                </div>
                {card.souls != null && (
                  <div className={s.statBadge} title="Âmes rapportées si éliminé">
                    <img src="/ui/ingame/souls_icon.webp" alt="Souls" className={s.statIcon} />
                    <span><strong>{card.souls}</strong> Âme{card.souls > 1 ? 's' : ''}</span>
                  </div>
                )}
                {card.wounds != null && (
                  <div className={s.statBadge} title="Blessures infligées au boss">
                    <img src="/ui/ingame/wound_icon.webp" alt="Wounds" className={s.statIcon} />
                    <span><strong>{card.wounds}</strong> Blessure{card.wounds > 1 ? 's' : ''}</span>
                  </div>
                )}
                {card.playerCount != null && (
                  <div className={s.statBadge} title="Nombre minimum de joueurs pour apparaître">
                    <span>👥 Min. <strong>{card.playerCount}+</strong> Joueurs</span>
                  </div>
                )}
              </>
            )}

            {/* Room Stats */}
            {isRoom && (
              <>
                <div className={s.statBadge} title="Type de salle">
                  <img src={roomTypeIcon(card.type, card.advanced)} alt="Type" className={s.statIcon} />
                  <span><strong>{card.advanced ? 'Avancée' : 'Ordinaire'}</strong> {card.type === 'trap' ? 'Piège' : 'Monstre'}</span>
                </div>
                {card.damage != null && (
                  <div className={s.statBadge} title="Dégâts infligés aux héros entrants">
                    <img src="/ui/ingame/health_room_icon.webp" alt="Damage" className={s.statIcon} />
                    <span><strong>{card.damage}</strong> Dégâts (Damage)</span>
                  </div>
                )}
              </>
            )}

            {/* Boss Stats */}
            {isBoss && (
              <>
                {card.xp != null && (
                  <div className={s.statBadge} title="Points d'expérience (détermine l'ordre du tour)">
                    <img src="/ui/gradients/sandclock_icon.webp" alt="XP" className={s.statIcon} />
                    <span><strong>{card.xp} XP</strong></span>
                  </div>
                )}
              </>
            )}

            {/* Spell Stats */}
            {isSpell && (
              <div className={s.statBadge} title="Phase de lancement autorisée">
                <img src="/ui/ingame/spells_icon.webp" alt="Spell" className={s.statIcon} />
                <span>
                  {card.category === 3
                    ? 'Phase Aventure uniquement'
                    : card.category === 1 || card.category === 2
                    ? 'Phase Construction'
                    : 'Phase Construction ou Aventure'}
                </span>
              </div>
            )}

            {/* Item Stats */}
            {isItem && (
              <div className={s.statBadge} title="Objet d'équipement">
                <span>⚔️ Équipement de Héros (Item)</span>
              </div>
            )}
          </div>

          {/* Treasure & Resources Sought or Provided */}
          {treasures.length > 0 && (
            <div className={s.treasureSection}>
              <div className={s.treasureLabel}>
                {isHero ? 'Ressource cherchée (Lured by):' : isRoom ? 'Trésors offerts aux héros (Provides):' : 'Trésor du Boss:'}
              </div>
              <div className={s.treasureList}>
                {treasures.map((t, idx) => (
                  <div key={idx} className={s.treasureItem}>
                    <img src={treasureIcon(t)} alt="" className={s.treasureIconImg} />
                    <span><strong>{TREASURE_NAMES[t] || t}</strong> — {TREASURE_RESOURCE_LABEL[t] || 'Ressource'}</span>
                  </div>
                ))}
              </div>
            </div>
          )}
        </div>

        {/* Ability / Rule description */}
        {card?.description && (
          <div className={s.desc}>
            <div className={s.descLabel}>Effet / Description :</div>
            <div className={s.descContent}>{card.description}</div>
          </div>
        )}

        {card?.levelUpDesc && (
          <div className={`${s.desc} ${s.levelUpDesc}`}>
            <div className={s.descLabel}>★ Montée de Niveau (Level Up) :</div>
            <div className={s.descContent}>{card.levelUpDesc}</div>
          </div>
        )}
      </div>
    </div>
  );
}