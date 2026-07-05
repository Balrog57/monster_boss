import { Client } from 'boardgame.io/react';
import { Local } from 'boardgame.io/multiplayer';
import { BossMonster } from './BossMonster.js';
import AppBoard from './AppBoard.jsx';

const BossMonsterClient = Client({
  game: BossMonster,
  board: AppBoard,
  multiplayer: Local(),
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
