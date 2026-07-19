// Layout.jsx - Layout primitives: Stack (column), Cluster (row), Center.
//
// These replace the dozens of `<div style={{display:'flex', flexDirection:'column', gap:N}}>`
// patterns scattered through the codebase. They compose via small CSS
// module classes — no inline styles, no prop spreading of style objects.
//
// API:
//   <Stack gap="5" align="center">...</Stack>
//   <Cluster gap="3" wrap justify="between">...</Cluster>
import React from 'react';
import s from './Stack.module.css';

const GAP = { '2': s.gap2, '3': s.gap3, '4': s.gap4, '5': s.gap5, '6': s.gap6, '8': s.gap8 };
const ALIGN = { center: s.center, start: s.start, end: s.end, stretch: s.stretch };
const JUSTIFY = { between: s.justifyBetween, end: s.justifyEnd };

export function Stack({ gap = '4', align = 'stretch', justify, grow, className = '', as: Tag = 'div', ...rest }) {
  const cls = [s.stack, GAP[gap], ALIGN[align], JUSTIFY[justify] || '', grow ? s.grow : '', className].filter(Boolean).join(' ');
  return <Tag className={cls} {...rest} />;
}

export function Cluster({ gap = '4', wrap = true, align = 'center', justify, className = '', as: Tag = 'div', ...rest }) {
  const cls = [s.cluster, GAP[gap], wrap ? s.wrap : s.nowrap, ALIGN[align], JUSTIFY[justify] || '', className].filter(Boolean).join(' ');
  return <Tag className={cls} {...rest} />;
}

export default Stack;