// Screen.jsx - Full-viewport screen wrapper with optional background image + overlay.
//
// Props:
//   bg:        string (image URL) | null  (optional background, with dark overlay)
//   bgOpacity: number 0..1                (overlay opacity; default 0.5)
//   width:     'narrow' | 'default' | 'wide'
//   align:     'center' | 'top'           (vertical; default 'center')
//   children, id, className, ...rest
//
// Accessibility: when `id="main-content"` is passed, the skip-link targets it.
import React from 'react';
import s from './Screen.module.css';

const WIDTH = { narrow: s.narrow, wide: s.wide, default: '' };
const ALIGN = { center: s.centerVert, top: s.top };

export default function Screen({ bg, bgOpacity, width = 'default', align = 'center', children, className = '', ...rest }) {
  return (
    <div className={[s.screen, ALIGN[align], className].filter(Boolean).join(' ')} {...rest}>
      {bg && (
        <img
          src={bg}
          alt=""
          aria-hidden="true"
          className={s.bg}
          style={bgOpacity != null ? { opacity: bgOpacity } : undefined}
          onError={(e) => { e.currentTarget.style.display = 'none'; }}
        />
      )}
      {bg && <div className={s.overlay} aria-hidden="true" />}
      <div className={[s.content, WIDTH[width]].filter(Boolean).join(' ')}>
        {children}
      </div>
    </div>
  );
}