import React, { useState, useRef, useEffect } from 'react';
import { Client } from 'boardgame.io/react';
import { Local } from 'boardgame.io/multiplayer';
import { BossMonster } from './BossMonster.js';
import AppBoard from './AppBoard.jsx';
import MainMenu from './screens/MainMenu.jsx';
import SetupScreen from './screens/SetupScreen.jsx';
import GameOverScreen from './screens/GameOverScreen.jsx';
import { playMusic, stopMusic } from './audio.js';

// Screen states
const MENU = 'menu';
const SETUP = 'setup';
const GAME = 'game';

export default function App() {
  const [screen, setScreen] = useState(MENU);
  const [numPlayers, setNumPlayers] = useState(2);
  const [gameKey, setGameKey] = useState(0); // force fresh Client per match

  const goMenu = () => { stopMusic(); setScreen(MENU); };

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
          onStart={(n) => {
            setNumPlayers(n);
            setGameKey((k) => k + 1);
            setScreen(GAME);
          }}
          onBack={() => setScreen(MENU)}
        />
      </div>
    );
  }

  return (
    <div style={{ minHeight: '100vh', background: '#0a0a0f' }}>
      <GameContainer
        key={gameKey}
        numPlayers={numPlayers}
        onExitToMenu={goMenu}
        onReplay={() => {
          // Replay returns to setup so the player can pick player count again
          // and start a fresh match cleanly.
          setGameKey((k) => k + 1);
          setScreen(SETUP);
        }}
      />
    </div>
  );
}

// Builds the boardgame.io client once per mount and wraps the board so we can
// detect game-over via a ref callback. The wrapper (BoardWithGameOver) reads
// G from props each render and signals up when G.gameOver flips to true.
function GameContainer({ numPlayers, onExitToMenu, onReplay }) {
  // The boardgame.io Client must be created at module/setup time. We create it
  // lazily on first render and stash it in a ref keyed by numPlayers.
  const clientRef = useRef(null);
  if (clientRef.current === null) {
    const multiplayer = Local();
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
  const cbRef = useRef(null);
  cbRef.current = (G) => {
    if (G && G.gameOver && !firedRef.current) {
      firedRef.current = true;
      // Snapshot the players object so the overlay has a stable copy.
      const playersCopy = {};
      for (const [pid, p] of Object.entries(G.players || {})) {
        playersCopy[pid] = { boss: p.boss, souls: [...p.souls], wounds: [...p.wounds], eliminated: p.eliminated };
      }
      setGameOverData({ winner: G.winner, players: playersCopy });
    }
  };
  // Expose the callback to the board via a module-level variable (the board
  // is created by Client and we can't pass props through it; we use a shared
  // ref object that the board reads on each render).
  gameOverCbRef.current = cbRef.current;

  return (
    <>
      <BossMonsterClient playerID="0" />
      {gameOverData && (
        <GameOverScreen
          winner={gameOverData.winner}
          players={gameOverData.players}
          playerID="0"
          onReplay={() => { firedRef.current = false; setGameOverData(null); onReplay(); }}
          onMenu={onExitToMenu}
        />
      )}
    </>
  );
}

// Module-level ref the BoardWithGameOver writes to (set by GameContainer).
const gameOverCbRef = { current: null };

// Drop-in replacement for AppBoard that signals game-over via the shared ref.
function BoardWithGameOver(props) {
  if (props && props.G) {
    if (gameOverCbRef.current) gameOverCbRef.current(props.G);
  }
  return <AppBoard {...props} />;
}
