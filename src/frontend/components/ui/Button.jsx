// Button.jsx - Variant-driven button primitive.
//
// Props:
//   variant: 'primary' | 'success' | 'danger' | 'ghost' | 'outline'  (default 'primary')
//   size:    'sm' | 'md' | 'lg'                                       (default 'md')
//   block:   boolean  (full-width)
//   loading: boolean  (shows spinner, disables interaction)
//   icon:    ReactNode (leading icon)
//   ...all native <button> props (onClick, disabled, type, aria-*, etc.)
//
// Accessibility:
//   - `disabled` also sets `aria-busy="true"` when loading
//   - Keyboard focus ring via :focus-visible (gold ring, see global.css)
//   - When `loading`, the label text stays visible but a spinner prepends; the
//     button is not clickable. Screen readers announce the busy state.
import React, { forwardRef } from 'react';
import s from './Button.module.css';

const VARIANT = { primary: s.primary, success: s.success, danger: s.danger, ghost: s.ghost, outline: s.outline };
const SIZE = { sm: s.sm, md: s.md, lg: s.lg };

const Button = forwardRef(function Button(
  { variant = 'primary', size = 'md', block = false, loading = false, icon = null, children, className = '', type = 'button', ...rest },
  ref
) {
  const classes = [
    s.base,
    VARIANT[variant] || s.primary,
    SIZE[size] || s.md,
    block ? s.block : '',
    className,
  ].filter(Boolean).join(' ');

  return (
    <button
      ref={ref}
      type={type}
      className={classes}
      aria-busy={loading || undefined}
      disabled={rest.disabled || loading || undefined}
      {...rest}
    >
      {loading && <span className={s.loader} aria-hidden="true" />}
      {icon && !loading && <span aria-hidden="true">{icon}</span>}
      <span>{children}</span>
    </button>
  );
});

export default Button;