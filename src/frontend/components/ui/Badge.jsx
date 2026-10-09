// Badge.jsx - Small status/label pill.
// Props: variant: 'default' | 'gold' | 'accent' | 'danger' | 'outline'
import React from 'react';
import s from './Badge.module.css';

const VARIANT = { default: '', gold: s.gold, accent: s.accent, danger: s.danger, outline: s.outline };

export default function Badge({ variant = 'default', children, className = '', ...rest }) {
  return <span className={[s.badge, VARIANT[variant], className].filter(Boolean).join(' ')} {...rest}>{children}</span>;
}