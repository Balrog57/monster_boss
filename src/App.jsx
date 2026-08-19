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
  const [expansions, setExpansions] = useState([]);
  const [match, setMatch] = useState(null);

  const goMenu = () => { stopMusic(); setScreen(MENU); setMatch(null); };

  return (
    <ErrorBoundary>
      {screen === MENU && (
          <MainMenu
            onStart={() => setScreen(SETUP)}
            onMultiplayer={() => setScreen(LOBBY)}
          />
      )}

      {screen === SETUP && (
          <SetupScreen
            onStartLocal={(n, packs) => {
              setNumPlayers(n);
              setExpansions(packs);
              setMatch(null);
              setScreen(GAME);
            }}
            onBack={() => setScreen(MENU)}
          />
      )}

      {screen === LOBBY && (
        <OnlineLobbyCustom
          onJoined={(m) => { setMatch(m); setScreen(GAME); }}
          onBack={() => setScreen(MENU)}
        />
      )}

      {screen === GAME && (
          <ErrorBoundary>
            {match ? (
              <OnlineGame match={match} onExitToMenu={goMenu} onReplay={() => setScreen(LOBBY)} />
            ) : (
              <LocalGame numPlayers={numPlayers} expansions={expansions} onExitToMenu={goMenu} onReplay={() => setScreen(SETUP)} />
            )}
          </ErrorBoundary>
      )}
    </ErrorBoundary>
  );
}

function LocalGame({ numPlayers, expansions, onExitToMenu, onReplay }) {
  const m = useLocalMatch({ numPlayers, setupData: { expansions }, onExitMatch: onReplay });
  if (!m.G) {
    return (
      <Screen width="narrow">
        <Spinner label="Preparing game…" />
      </Screen>
    );
  }
  return <AppBoard {...m} onExitToMenu={onExitToMenu} />;
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
          Connecting…
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
        <Button variant="ghost" onClick={onReplay}>Back to lobby</Button>
      </Screen>
    );
  }
  return <AppBoard {...m} onExitToMenu={onExitToMenu} />;
}