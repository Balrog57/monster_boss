// Modal.jsx - Accessible dialog with focus trap, Escape, backdrop click, scroll lock.
//
// Props:
//   open:     boolean (controlled)
//   onClose:  () => void   (called on Escape, backdrop click, or close button)
//   title:    string | ReactNode
//   width:    'narrow' | 'default' | 'wide'
//   children: dialog body
//   footer:   ReactNode (optional, usually action buttons)
//   closable: boolean (default true; false disables backdrop/Escape close, hides X)
//
// Accessibility:
//   - role="dialog" aria-modal="true" aria-labelledby
//   - Focus trap: focus cycles within the dialog while open
//   - Auto-focus first focusable on open
//   - Escape closes (unless closable=false)
//   - Backdrop click closes (unless closable=false or click started inside panel)
//   - Body scroll locked while open
//   - On close, focus restored to the element that had it before opening
import React, { useEffect, useRef, useState, useCallback } from 'react';
import s from './Modal.module.css';

const WIDTH = { narrow: s.narrow, wide: s.wide, default: '' };

const FOCUSABLE = 'button:not([disabled]), [href], input:not([disabled]), select:not([disabled]), textarea:not([disabled]), [tabindex]:not([tabindex="-1"])';

export default function Modal({ open, onClose, title, width = 'default', closable = true, children, footer, ...rest }) {
  const panelRef = useRef(null);
  const previouslyFocused = useRef(null);
  const [mouseDownInside, setMouseDownInside] = useState(false);

  const close = useCallback(() => {
    if (closable && onClose) onClose();
  }, [closable, onClose]);

  // Lock scroll + restore focus on open/close.
  useEffect(() => {
    if (!open) return;
    previouslyFocused.current = document.activeElement;
    const { overflow } = document.body.style;
    document.body.style.overflow = 'hidden';
    // Focus first focusable in the panel after mount.
    const t = setTimeout(() => {
      const node = panelRef.current;
      if (!node) return;
      const first = node.querySelector(FOCUSABLE);
      if (first) first.focus();
      else panelRef.current.focus();
    }, 20);
    return () => {
      clearTimeout(t);
      document.body.style.overflow = overflow;
      if (previouslyFocused.current && typeof previouslyFocused.current.focus === 'function') {
        try { previouslyFocused.current.focus(); } catch { /* ignore */ }
      }
    };
  }, [open]);

  // Escape to close + focus trap.
  const onKeyDown = useCallback((e) => {
    if (!open) return;
    if (e.key === 'Escape' && closable) { e.stopPropagation(); close(); return; }
    if (e.key === 'Tab') {
      const node = panelRef.current;
      if (!node) return;
      const focusables = Array.from(node.querySelectorAll(FOCUSABLE));
      if (focusables.length === 0) { e.preventDefault(); node.focus(); return; }
      const idx = focusables.indexOf(document.activeElement);
      if (e.shiftKey && (idx === 0 || idx === -1)) {
        e.preventDefault();
        focusables[focusables.length - 1].focus();
      } else if (!e.shiftKey && idx === focusables.length - 1) {
        e.preventDefault();
        focusables[0].focus();
      }
    }
  }, [open, closable, close]);

  useEffect(() => {
    if (!open) return;
    document.addEventListener('keydown', onKeyDown, true);
    return () => document.removeEventListener('keydown', onKeyDown, true);
  }, [onKeyDown, open]);

  if (!open) return null;

  return (
    <div
      className={s.overlay}
      onMouseDown={(e) => setMouseDownInside(e.target === panelRef.current || panelRef.current?.contains(e.target))}
      onMouseUp={(e) => {
        // Only close on backdrop if the mouseDown AND mouseUp were outside the panel.
        if (closable && !mouseDownInside && !panelRef.current?.contains(e.target)) close();
        setMouseDownInside(false);
      }}
      role="presentation"
    >
      <div
        ref={panelRef}
        className={[s.panel, WIDTH[width]].filter(Boolean).join(' ')}
        role="dialog"
        aria-modal="true"
        aria-labelledby={title ? 'bm-modal-title' : undefined}
        tabIndex={-1}
        {...rest}
      >
        {(title || closable) && (
          <div className={s.header}>
            {title && <h2 id="bm-modal-title" className={s.title}>{title}</h2>}
            {closable && (
              <button className={s.close} onClick={close} aria-label="Close" type="button">×</button>
            )}
          </div>
        )}
        <div className={s.body}>{children}</div>
        {footer && <div className={s.footer}>{footer}</div>}
      </div>
    </div>
  );
}