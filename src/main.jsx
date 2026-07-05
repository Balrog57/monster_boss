import React from 'react';
import { createRoot } from 'react-dom/client';
import App from './App.jsx';
import { installClickSounds } from './audio.js';

// Wire button/click sound effects globally (respects mute toggle).
installClickSounds();

const container = document.getElementById('app');
const root = createRoot(container);
root.render(<App />);
