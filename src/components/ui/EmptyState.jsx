// EmptyState.jsx - Friendly placeholder for empty lists / no-data states.
// Props: icon: ReactNode, title: string, hint?: string, action?: ReactNode
import React from 'react';
import s from './EmptyState.module.css';

export default function EmptyState({ icon, title, hint, action, ...rest }) {
  return (
    <div className={s.wrap} {...rest}>
      {icon && <div className={s.icon} aria-hidden="true">{icon}</div>}
      {title && <div className={s.title}>{title}</div>}
      {hint && <div className={s.hint}>{hint}</div>}
      {action}
    </div>
  );
}