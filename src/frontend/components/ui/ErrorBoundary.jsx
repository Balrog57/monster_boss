// ErrorBoundary.jsx - Catches render errors, shows a friendly fallback, lets
// the user try again. Place near the root of each major surface (App, screens).
//
// Props:
//   fallback:  ReactNode | ({error, reset}) => ReactNode  (custom fallback)
//   onError:   (error, info) => void                       (logging hook)
//   children
import React, { Component } from 'react';
import Button from './Button.jsx';
import Screen from './Screen.jsx';

const DefaultFallback = ({ error, reset }) => (
  <Screen width="narrow">
    <h1 style={{ color: 'var(--bm-danger)', fontFamily: 'var(--bm-font-display)', fontSize: 'var(--bm-text-5xl)' }}>
      Quelque chose a planté
    </h1>
    <p style={{ color: 'var(--bm-text-500)' }}>Une erreur inattendue est survenue pendant le rendu.</p>
    {error?.message && (
      <pre style={{
        background: 'rgba(127,29,29,0.2)', padding: 'var(--bm-space-6)',
        borderRadius: 'var(--bm-radius-md)', color: 'var(--bm-danger)',
        fontSize: 'var(--bm-text-sm)', overflow: 'auto', maxWidth: '100%'
      }}>
        {error.message}
      </pre>
    )}
    <Button variant="primary" onClick={reset} block>Recharger l'écran</Button>
  </Screen>
);

export default class ErrorBoundary extends Component {
  state = { error: null };

  static getDerivedStateFromError(error) { return { error }; }

  componentDidCatch(error, info) {
    if (this.props.onError) this.props.onError(error, info);
    else console.error('[ErrorBoundary]', error, info);
  }

  reset = () => { this.setState({ error: null }); };

  render() {
    const { error } = this.state;
    if (error) {
      const Fallback = this.props.fallback || DefaultFallback;
      return typeof Fallback === 'function' ? <Fallback error={error} reset={this.reset} /> : Fallback;
    }
    return this.props.children;
  }
}