// RulesOverlay.jsx - APK-styled reader for docs/rules/rules.md
import React, { useMemo, useState } from 'react';
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
  const [active, setActive] = useState(sections[0]?.id || 'base');
  if (!open) return null;
  const current = sections.find((sec) => sec.id === active) || sections[0];

  return (
    <div className={s.backdrop} role="dialog" aria-label="Rules" aria-modal="true">
      <div className={s.panel}>
        <div className={s.header}>
          <img src="/ui/ingame/spells_icon.webp" alt="" className={s.headerIcon} />
          <span className={s.title}>RULES</span>
          <button className={s.close} type="button" onClick={onClose} aria-label="Close" />
        </div>
        <div className={s.body}>
          <nav className={s.toc} aria-label="Rule sections">
            {sections.map((sec) => (
              <button
                key={sec.id}
                type="button"
                className={`${s.tocBtn} ${sec.id === current.id ? s.tocOn : ''}`}
                onClick={() => setActive(sec.id)}
              >
                {sec.title}
              </button>
            ))}
          </nav>
          <div className={s.article}>
            <h2>{current.title}</h2>
            <div
              className={s.prose}
              dangerouslySetInnerHTML={{ __html: renderBody(current.body || []) }}
            />
          </div>
        </div>
      </div>
    </div>
  );
}
