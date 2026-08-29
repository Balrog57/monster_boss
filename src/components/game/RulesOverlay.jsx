// RulesOverlay.jsx - Full-stage rulebook: one scrollable page, close with X.
import React, { useMemo } from 'react';
import { playSfx, SFX } from '../../audio.js';
import rulesMd from '../../../docs/rules/rules.md?raw';
import s from './RulesOverlay.module.css';

const SECTION_TITLES = {
  'advanced-faq': 'Advanced FAQ',
  base: 'Base Set',
  'crash-landing': 'Crash Landing',
  minibosses: 'Minibosses',
  'next-level': 'The Next Level',
  'unofficial-guide': 'Unofficial Guide',
};

const SECTION_ORDER = [
  'base',
  'advanced-faq',
  'crash-landing',
  'minibosses',
  'next-level',
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

function isBullet(line) {
  return /^[●•\-*]\s+/.test(line) || line === '' || line === '●' || line === '•';
}

function stripBullet(line) {
  return line.replace(/^[●•\-*]\s*/, '').trim();
}

function isCardHeading(line, next) {
  const t = line.trim();
  if (!t || isBullet(t) || t.length > 48 || /[.!?:]$/.test(t) || /^\d+$/.test(t)) return false;
  if (/^(©|http|www\.|•)/i.test(t)) return false;
  const n = (next || '').trim();
  return isBullet(n) || n === '' || n === '●';
}

function renderBody(lines) {
  const html = [];
  let paras = [];
  let list = [];
  const flushPara = () => {
    const t = paras.join(' ').replace(/\s+/g, ' ').trim();
    if (t) html.push(`<p>${esc(t)}</p>`);
    paras = [];
  };
  const flushList = () => {
    if (!list.length) return;
    html.push(`<ul>${list.map((item) => `<li>${esc(item)}</li>`).join('')}</ul>`);
    list = [];
  };
  for (let i = 0; i < lines.length; i++) {
    const raw = lines[i];
    const t = raw.trim();
    if (!t) {
      flushList();
      flushPara();
      continue;
    }
    if (t === '' || t === '●' || t === '•') continue;
    if (isCardHeading(t, lines[i + 1])) {
      flushList();
      flushPara();
      html.push(`<h3>${esc(t)}</h3>`);
      continue;
    }
    if (isBullet(t)) {
      flushPara();
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
  if (!open) return null;

  const close = () => {
    playSfx(SFX.BUTTON);
    onClose();
  };

  return (
    <div className={s.page} role="dialog" aria-label="Rules" aria-modal="true">
      <header className={s.header}>
        <img src="/ui/ingame/spells_icon.webp" alt="" className={s.headerIcon} />
        <h1 className={s.title}>RULES</h1>
        <button className={s.close} type="button" onClick={close} aria-label="Close">
          ×
        </button>
      </header>
      <div className={s.scroll}>
        {sections.map((sec) => (
          <section key={sec.id} className={s.section}>
            <h2>{sec.title}</h2>
            <div
              className={s.prose}
              dangerouslySetInnerHTML={{ __html: renderBody(sec.body || []) }}
            />
          </section>
        ))}
      </div>
    </div>
  );
}
