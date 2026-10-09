// useMediaQuery.js - SSR-safe hook that returns whether a media query matches.
//
// Usage:
//   const isMobile = useMediaQuery('(max-width: 640px)');
//   const prefersReducedMotion = useMediaQuery('(prefers-reduced-motion: reduce)');
import { useEffect, useState } from 'react';
import { breakpoints } from '../../design/theme.js';

export function useMediaQuery(query) {
  const [matches, setMatches] = useState(() => {
    if (typeof window === 'undefined' || !window.matchMedia) return false;
    return window.matchMedia(query).matches;
  });

  useEffect(() => {
    if (typeof window === 'undefined' || !window.matchMedia) return;
    const mql = window.matchMedia(query);
    const handler = (e) => setMatches(e.matches);
    handler(mql); // sync initial state after mount
    mql.addEventListener('change', handler);
    return () => mql.removeEventListener('change', handler);
  }, [query]);

  return matches;
}

// Convenience helpers backed by the design-token breakpoints.
export const useIsMobile = () => useMediaQuery(`(max-width: ${breakpoints.sm}px)`);
export const useIsTablet = () => useMediaQuery(`(max-width: ${breakpoints.md}px)`);
export const useIsDesktop = () => useMediaQuery(`(min-width: ${breakpoints.lg}px)`);
export const usePrefersReducedMotion = () => useMediaQuery('(prefers-reduced-motion: reduce)');

export default useMediaQuery;