// RulesOverlay.jsx - Full-stage rulebook with quick-jump tabs, clean typography, and search/filter.
import React, { useState, useMemo, useRef } from 'react';
import { playSfx, SFX } from '../../audio.js';
import rulesMd from '../../../docs/rules/rules.md?raw';
import s from './RulesOverlay.module.css';

const SECTION_TITLES = {
  base: 'Base Set',
  'advanced-faq': 'Advanced FAQ',
  'the-next-level': 'The Next Level',
  'next-level': 'The Next Level',
  minibosses: 'Minibosses',
  'crash-landing': 'Crash Landing',
  'unofficial-guide': 'Reference Guide',
};

const SECTION_ORDER = [
  'base',
  'advanced-faq',
  'the-next-level',
  'next-level',
  'minibosses',
  'crash-landing',
  'unofficial-guide',
];

function parseSections(md) {
  const lines = String(md || '').split(/\r?\n/);
  const sections = [];
  let current = { id: 'intro', title: 'Boss Monster', body: [] };
  for (const line of lines) {
    const m = line.match(/^##\s+(.+)/);
    if (m) {
      if (current.body.length || current.id !== 'intro') sections.push(current);
      const title = m[1].trim();
      const id = title.toLowerCase().replace(/\s+/g, '-');
      current = { id, title: SECTION_TITLES[id] || title, body: [] };
    } else {
      current.body.push(line);
    }
  }
  sections.push(current);
  const filtered = sections.filter((sec) => sec.body.join('').trim() && sec.id !== 'intro');
  filtered.sort((a, b) => {
    const ia = SECTION_ORDER.indexOf(a.id);
    const ib = SECTION_ORDER.indexOf(b.id);
    return (ia < 0 ? 99 : ia) - (ib < 0 ? 99 : ib);
  });
  return filtered;
}

function esc(t) {
  return String(t)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;');
}

function formatInline(text) {
  let res = esc(text);
  res = res.replace(/\*\*(.+?)\*\*/g, '<strong>$1</strong>');
  res = res.replace(/\*([^*]+?)\*/g, '<em>$1</em>');
  res = res.replace(/`([^`]+?)`/g, '<code class="' + s.code + '">$1</code>');
  return res;
}

function isBullet(line) {
  return /^[●•\-*]\s+/.test(line) || /^\d+\.\s+/.test(line) || line === '' || line === '●' || line === '•';
}

function stripBullet(line) {
  return line.replace(/^[●•\-*]\s*/, '').replace(/^\d+\.\s*/, '').trim();
}

function renderBody(lines) {
  const html = [];
  let paras = [];
  let list = [];
  let isNumbered = false;

  const flushPara = () => {
    const t = paras.join(' ').replace(/\s+/g, ' ').trim();
    if (t) html.push(`<p>${formatInline(t)}</p>`);
    paras = [];
  };

  const flushList = () => {
    if (!list.length) return;
    const tag = isNumbered ? 'ol' : 'ul';
    html.push(`<${tag}>${list.map((item) => `<li>${formatInline(item)}</li>`).join('')}</${tag}>`);
    list = [];
    isNumbered = false;
  };

  for (let i = 0; i < lines.length; i++) {
    const raw = lines[i];
    const t = raw.trim();

    if (!t) {
      flushList();
      flushPara();
      continue;
    }

    if (t === '---' || t === '***') {
      flushList();
      flushPara();
      html.push('<hr />');
      continue;
    }

    if (t.startsWith('### ')) {
      flushList();
      flushPara();
      html.push(`<h3>${formatInline(t.slice(4).trim())}</h3>`);
      continue;
    }

    if (t.startsWith('#### ')) {
      flushList();
      flushPara();
      html.push(`<h4>${formatInline(t.slice(5).trim())}</h4>`);
      continue;
    }

    if (t.startsWith('> ')) {
      flushList();
      flushPara();
      html.push(`<blockquote class="${s.callout}">${formatInline(t.slice(2).trim())}</blockquote>`);
      continue;
    }

    if (isBullet(t)) {
      flushPara();
      if (/^\d+\.\s+/.test(t) && !list.length) isNumbered = true;
      const item = stripBullet(t);
      if (item) list.push(item);
      continue;
    }

    flushList();
    paras.push(t);
  }

  flushList();
  flushPara();
  return html.join('');
}

export default function RulesOverlay({ open, onClose }) {
  const sections = useMemo(() => parseSections(rulesMd), []);
  const [activeTab, setActiveTab] = useState('base');
  const scrollRef = useRef(null);

  if (!open) return null;

  const close = () => {
    playSfx(SFX.BUTTON);
    onClose();
  };

  const selectTab = (id) => {
    playSfx(SFX.BUTTON);
    setActiveTab(id);
    if (scrollRef.current) {
      scrollRef.current.scrollTop = 0;
    }
  };

  const activeSection = sections.find((sec) => sec.id === activeTab) || sections[0];

  return (
    <div className={s.page} role="dialog" aria-label="Rules" aria-modal="true">
      <header className={s.header}>
        <img src="/ui/ingame/spells_icon.webp" alt="" className={s.headerIcon} />
        <h1 className={s.title}>RULES</h1>
        <button className={s.close} type="button" onClick={close} aria-label="Close">
          ×
        </button>
      </header>

      <nav className={s.tabs} role="tablist" aria-label="Rulebook sections">
        {sections.map((sec) => (
          <button
            key={sec.id}
            type="button"
            role="tab"
            aria-selected={sec.id === (activeSection?.id || 'base')}
            className={`${s.tab} ${sec.id === (activeSection?.id || 'base') ? s.tabActive : ''}`}
            onClick={() => selectTab(sec.id)}
          >
            {sec.title}
          </button>
        ))}
      </nav>

      <div className={s.scroll} ref={scrollRef}>
        {activeSection && (
          <section key={activeSection.id} className={s.section}>
            <h2>{activeSection.title}</h2>
            <div
              className={s.prose}
              dangerouslySetInnerHTML={{ __html: renderBody(activeSection.body || []) }}
            />
          </section>
        )}
      </div>
    </div>
  );
}
