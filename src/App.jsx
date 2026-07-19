import React, { useState } from 'react';
import AppBoard from './AppBoard.jsx';
import MainMenu from './screens/MainMenu.jsx';
import SetupScreen from './screens/SetupScreen.jsx';
import OnlineLobbyCustom from './screens/OnlineLobbyCustom.jsx';
import { ErrorBoundary, Spinner, Button, Screen } from './components/ui';
import { useOnlineMatch, useLocalMatch } from './client/useMatch.js';
import { stopMusic } from './audio.js';

const MENU = 'menu';
const SETUP = 'setup';
const LOBBY = 'lobby';
const GAME = 'game';

export default function App() {
  const [screen, setScreen] = useState(MENU);
  const [numPlayers, setNumPlayers] = useState(2);
  const [match, setMatch] = useState(null);

  const goMenu = () => { stopMusic(); setScreen(MENU); setMatch(null); };

  return (
    <ErrorBoundary>
      {screen === MENU && (
        <div style={{ minHeight: '100vh', background: 'var(--bm-bg-800)' }}>
          <MainMenu onStart={() => setScreen(SETUP)} />
        </div>
      )}

      {screen === SETUP && (
        <div style={{ minHeight: '100vh', background: 'var(--bm-bg-800)' }}>
          <SetupScreen
            onStartLocal={(n) => { setNumPlayers(n); setMatch(null); setScreen(GAME); }}
            onStartOnline={() => setScreen(LOBBY)}
            onBack={() => setScreen(MENU)}
          />
        </div>
      )}

      {screen === LOBBY && (
        <div style={{ minHeight: '100vh', background: 'var(--bm-bg-800)' }}>
          <OnlineLobbyCustom
            onJoined={(m) => { setMatch(m); setScreen(GAME); }}
            onBack={() => setScreen(SETUP)}
          />
        </div>
      )}

      {screen === GAME && (
        <div style={{ minHeight: '100vh', background: 'var(--bm-bg-800)' }}>
          <ErrorBoundary>
            {match ? (
              <OnlineGame match={match} onExitToMenu={goMenu} onReplay={() => setScreen(LOBBY)} />
            ) : (
              <LocalGame numPlayers={numPlayers} onExitToMenu={goMenu} onReplay={() => setScreen(SETUP)} />
            )}
          </ErrorBoundary>
        </div>
      )}
    </ErrorBoundary>
  );
}

function LocalGame({ numPlayers, onExitToMenu, onReplay }) {
  const m = useLocalMatch({ numPlayers, onExitMatch: onReplay });
  if (!m.G) {
    return (
      <Screen width="narrow">
        <Spinner label="Préparation de la partie…" />
      </Screen>
    );
  }
  return <AppBoard {...m} />;
}

function OnlineGame({ match, onExitToMenu, onReplay }) {
  const m = useOnlineMatch({
    matchID: match.matchID,
    playerID: String(match.playerID),
    credentials: match.credentials,
    onExitMatch: onReplay,
  });

  if (!m.G) {
    return (
      <Screen width="narrow" align="top">
        <h1 style={{ color: 'var(--bm-gold)', fontFamily: 'var(--bm-font-display)', fontSize: 'var(--bm-text-3xl)' }}>
          Connexion à la partie…
        </h1>
        <Spinner size="lg" />
        {m.error && (
          <div role="alert" style={{
            color: 'var(--bm-danger)', fontSize: 'var(--bm-text-md)',
            background: 'rgba(127,29,29,0.3)', padding: 'var(--bm-space-5)',
            borderRadius: 'var(--bm-radius-md)', width: '100%', textAlign: 'center'
          }}>
            {m.error}
          </div>
        )}
        <Button variant="ghost" onClick={onReplay}>Retour au lobby</Button>
      </Screen>
    );
  }
  return <AppBoard {...m} />;
}