import React, { useState, useRef } from 'react';
import { Client } from 'boardgame.io/react';
import { Local, SocketIO } from 'boardgame.io/multiplayer';
import { BossMonster } from './BossMonster.js';
import AppBoard from './AppBoard.jsx';
import MainMenu from './screens/MainMenu.jsx';
import SetupScreen from './screens/SetupScreen.jsx';
import OnlineLobby from './screens/OnlineLobby.jsx';
import GameOverScreen from './screens/GameOverScreen.jsx';
import { playMusic, stopMusic } from './audio.js';

// Screen states
const MENU = 'menu';
const SETUP = 'setup';
const LOBBY = 'lobby';      // online lobby (create/join)
const GAME = 'game';

const ONLINE_SERVER = window.location.hostname === 'localhost'
  ? 'http://localhost:8000'
  : window.location.origin;

export default function App() {
  const [screen, setScreen] = useState(MENU);
  const [mode, setMode] = useState('local'); // 'local' or 'online'
  const [numPlayers, setNumPlayers] = useState(2);
  const [gameKey, setGameKey] = useState(0);
  // Online match params (set by the lobby)
  const [match, setMatch] = useState(null); // { matchID, playerID, credentials, numPlayers }

  const goMenu = () => { stopMusic(); setScreen(MENU); setMatch(null); };

  if (screen === MENU) {
    return (
      <div style={{ minHeight: '100vh', background: '#0a0a0f' }}>
        <MainMenu onStart={() => setScreen(SETUP)} />
      </div>
    );
  }

  if (screen === SETUP) {
    return (
      <div style={{ minHeight: '100vh', background: '#0a0a0f' }}>
        <SetupScreen
          onStartLocal={(n) => {
            setMode('local');
            setNumPlayers(n);
            setGameKey((k) => k + 1);
            setScreen(GAME);
          }}
          onStartOnline={() => {
            setMode('online');
            setScreen(LOBBY);
          }}
          onBack={() => setScreen(MENU)}
        />
      </div>
    );
  }

  if (screen === LOBBY) {
    return (
      <div style={{ minHeight: '100vh', background: '#0a0a0f' }}>
        <OnlineLobby
          onJoined={(m) => {
            setMatch(m);
            setGameKey((k) => k + 1);
            setScreen(GAME);
          }}
          onBack={() => setScreen(SETUP)}
        />
      </div>
    );
  }

  // GAME screen
  return (
    <div style={{ minHeight: '100vh', background: '#0a0a0f' }}>
      <GameContainer
        key={gameKey}
        mode={mode}
        numPlayers={match?.numPlayers || numPlayers}
        match={match}
        onExitToMenu={goMenu}
        onReplay={() => {
          if (mode === 'online') { setScreen(LOBBY); setMatch(null); }
          else { setGameKey((k) => k + 1); setScreen(SETUP); }
        }}
      />
    </div>
  );
}

function GameContainer({ mode, numPlayers, match, onExitToMenu, onReplay }) {
  const clientRef = useRef(null);
  if (clientRef.current === null) {
    const multiplayer = mode === 'online'
      ? SocketIO({ server: ONLINE_SERVER })
      : Local();
    clientRef.current = Client({
      game: BossMonster,
      board: BoardWithGameOver,
      multiplayer,
      numPlayers,
      debug: false,
    });
  }
  const BossMonsterClient = clientRef.current;

  const [gameOverData, setGameOverData] = useState(null);
  const firedRef = useRef(false);
  gameOverCbRef.current = (G) => {
    if (G && G.gameOver && !firedRef.current) {
      firedRef.current = true;
      const playersCopy = {};
      for (const [pid, p] of Object.entries(G.players || {})) {
        playersCopy[pid] = { boss: p.boss, souls: [...p.souls], wounds: [...p.wounds], eliminated: p.eliminated };
      }
      setGameOverData({ winner: G.winner, players: playersCopy });
    }
  };

  const playerID = match?.playerID || '0';

  return (
    <>
      <BossMonsterClient
        playerID={playerID}
        matchID={match?.matchID || 'default'}
        credentials={match?.credentials}
      />
      {gameOverData && (
        <GameOverScreen
          winner={gameOverData.winner}
          players={gameOverData.players}
          playerID={playerID}
          onReplay={() => { firedRef.current = false; setGameOverData(null); onReplay(); }}
          onMenu={onExitToMenu}
        />
      )}
    </>
  );
}

const gameOverCbRef = { current: null };

function BoardWithGameOver(props) {
  if (props && props.G) {
    if (gameOverCbRef.current) gameOverCbRef.current(props.G);
  }
  return <AppBoard {...props} />;
}
