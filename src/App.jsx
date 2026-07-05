import { Client } from 'boardgame.io/react';
import { Local } from 'boardgame.io/multiplayer';
import { BossMonster } from './BossMonster.js';
import AppBoard from './AppBoard.jsx';

// Single shared Local() master so all clients connect to the same game state.
const multiplayer = Local();

const BossMonsterClient = Client({
  game: BossMonster,
  board: AppBoard,
  multiplayer,
  numPlayers: 2,
  debug: false
});

export default function App() {
  return (
    <div style={{ minHeight: '100vh', background: '#0E0E0E' }}>
      <BossMonsterClient playerID="0" />
    </div>
  );
}
