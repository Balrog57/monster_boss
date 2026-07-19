// Spinner.jsx - Animated loading indicator.
// Props: size: 'sm'|'md'|'lg', label: string (optional caption, renders a full centered block)
import React from 'react';
import s from './Spinner.module.css';

const SIZE = { sm: s.sm, md: '', lg: s.lg };

export default function Spinner({ size = 'md', label, className = '', ...rest }) {
  if (label) {
    return (
      <div className={s.centerWrap} role="status" aria-live="polite" {...rest}>
        <div className={[s.spinner, SIZE[size], className].filter(Boolean).join(' ')} aria-hidden="true" />
        <span className={s.label}>{label}</span>
      </div>
    );
  }
  return (
    <div
      className={[s.spinner, SIZE[size], className].filter(Boolean).join(' ')}
      role="status"
      aria-label="Chargement"
      {...rest}
    />
  );
}