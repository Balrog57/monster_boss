import React from 'react';
import { createRoot } from 'react-dom/client';
import App from './App.jsx';
import { installClickSounds } from './audio.js';

// Design system foundation: tokens first, then global base styles.
import './design/tokens/tokens.css';
import './design/global.css';

// Wire button/click sound effects globally (respects mute toggle).
installClickSounds();

const container = document.getElementById('app');
const root = createRoot(container);
root.render(
  <React.StrictMode>
    <a href="#main-content" className="skip-link">Aller au contenu</a>
    <App />
  </React.StrictMode>
);

// Register the service worker (PWA / offline cache). Skipped in dev to avoid
// stale-cache interference with Vite HMR.
if (import.meta.env.PROD && 'serviceWorker' in navigator) {
  window.addEventListener('load', () => {
    navigator.serviceWorker.register('/sw.js').catch((err) => {
      console.warn('[sw] registration failed:', err);
    });
  });
}
