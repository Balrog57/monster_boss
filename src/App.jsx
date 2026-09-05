import React, { useState, useEffect } from 'react';
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
  const [menuView, setMenuView] = useState('intro');
  const [numPlayers, setNumPlayers] = useState(2);
  const [expansions, setExpansions] = useState([]);
  const [humanCount, setHumanCount] = useState(1);
  const [match, setMatch] = useState(null);

  const goMenu = () => {
    stopMusic();
    localStorage.removeItem('bm_online_session');
    setMenuView('root');
    setScreen(MENU);
    setMatch(null);
  };

  useEffect(() => {
    try {
      const raw = localStorage.getItem('bm_online_session');
      if (raw) {
        const saved = JSON.parse(raw);
        if (saved?.matchID && saved.credentials) {
          setMatch(saved);
          setScreen(GAME);
        }
      }
    } catch { /* ignore */ }
  }, []);

  return (
    <ErrorBoundary>
      {screen === MENU && (
          <MainMenu
            initialView={menuView}
            onStart={() => setScreen(SETUP)}
            onMultiplayer={() => setScreen(LOBBY)}
          />
      )}

      {screen === SETUP && (
          <SetupScreen
            onStartLocal={(n, packs, humanCount) => {
              setNumPlayers(n);
              setExpansions(packs);
              setHumanCount(humanCount ?? 1);
              setMatch(null);
              setScreen(GAME);
            }}
            onBack={() => { setMenuView('root'); setScreen(MENU); }}
          />
      )}

      {screen === LOBBY && (
        <OnlineLobbyCustom
          onJoined={(m) => { setMatch(m); setScreen(GAME); }}
          onBack={() => { setMenuView('root'); setScreen(MENU); }}
        />
      )}

      {screen === GAME && (
          <ErrorBoundary>
            {match ? (
              <OnlineGame match={match} onExitToMenu={goMenu} onReplay={() => setScreen(LOBBY)} />
            ) : (
              <LocalGame numPlayers={numPlayers} expansions={expansions} humanCount={humanCount} onExitToMenu={goMenu} onReplay={() => setScreen(SETUP)} />
            )}
          </ErrorBoundary>
      )}
    </ErrorBoundary>
  );
}

function LocalGame({ numPlayers, expansions, humanCount = 1, onExitToMenu, onReplay }) {
  const [viewingPlayer, setViewingPlayer] = useState('0');
  const m = useLocalMatch({
    numPlayers,
    setupData: { expansions, humanCount },
    viewingPlayer,
    onExitMatch: onReplay,
  });
  if (!m.G) {
    return (
      <Screen width="narrow">
        <Spinner label="Preparing game…" />
      </Screen>
    );
  }
  const active = String(m.ctx?.activePlayer ?? '0');
  const showPass = Number(viewingPlayer) !== Number(active) && !m.G.players[active]?.isAI;
  return (
    <>
      {showPass && (
        <Screen width="narrow">
          <h2 style={{ color: 'var(--bm-gold)' }}>Pass device to Player {Number(active) + 1}</h2>
          <Button onClick={() => setViewingPlayer(active)}>I am Player {Number(active) + 1}</Button>
        </Screen>
      )}
      {!showPass && (
        <AppBoard
          {...m}
          playerID={viewingPlayer}
          onExitToMenu={onExitToMenu}
          onSwitchPlayer={humanCount > 1 ? setViewingPlayer : undefined}
        />
      )}
    </>
  );
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