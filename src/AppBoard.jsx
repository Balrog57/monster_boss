// AppBoard.jsx - Game board orchestrator.
//
// Composes the focused game components (Hud, OpponentRow, MyDungeon, TownPanel,
// Hand, LogStrip, BossSelect, DetailPanel) and wires their interactions. The
// state shape { G, ctx, moves, playerID, isActive, onExitMatch } is provided by
// useOnlineMatch / useLocalMatch (see src/client/useMatch.js).
import React, { useState, useEffect, useRef } from 'react';
import { PHASE } from './cardData.js';
import { countVisibleRooms } from './engine.js';
import { playMusic } from './audio.js';
import {
  BossSelect, Hud, OpponentRow, MyDungeon, TownPanel, Hand, LogStrip, DetailPanel
} from './components/game';
import GameOverScreen from './screens/GameOverScreen.jsx';
import s from './AppBoard.module.css';

export default function AppBoard({ G, ctx, moves, playerID, isActive, onExitMatch }) {
  const [inspect, setInspect] = useState(null);        // { card, kind }
  const [selectedCard, setSelectedCard] = useState(null);
  const [gameOverData, setGameOverData] = useState(null);
  const gameOverFired = useRef(false);
  const lastPhase = useRef(null);

  useEffect(() => {
    const phase = ctx?.phase || G?.phase;
    if (phase && phase !== PHASE.BOSS && lastPhase.current === null) {
      playMusic('music_dungeon_v3', 0.3);
    }
    lastPhase.current = phase;
  }, [ctx?.phase, G?.phase]);

  // Detect end-of-game and surface the GameOverScreen overlay from inside the
  // board so it works whether the board is rendered in solo or online mode.
  useEffect(() => {
    if (G && G.gameOver && !gameOverFired.current) {
      gameOverFired.current = true;
      const playersCopy = {};
      for (const [pid, p] of Object.entries(G.players || {})) {
        playersCopy[pid] = {
          boss: p.boss,
          souls: [...(p.souls || [])],
          wounds: [...(p.wounds || [])],
          eliminated: p.eliminated,
        };
      }
      setGameOverData({ winner: G.winner, players: playersCopy });
    }
  }, [G?.gameOver]);

  if (!G || !G.players) {
    return <div className={s.screen}><div className={s.loading}>Chargement…</div></div>;
  }
  const pidKey = String(playerID);
  const me = G.players[pidKey];
  if (!me) {
    return <div className={s.screen}><div className={s.loading}>Chargement… (joueur {pidKey} introuvable)</div></div>;
  }
  const phase = ctx.phase || G.phase;
  const activePid = G.activePlayer != null ? String(G.activePlayer) : (ctx.currentPlayer != null ? String(ctx.currentPlayer) : '0');
  const isMyTurn = activePid === pidKey;
  const opponents = Object.values(G.players).filter(p => p !== me);

  // BOSS phase: dedicated selection screen
  if (phase === PHASE.BOSS) {
    return (
      <div className={s.screen}>
        <BossSelect G={G} me={me} onPick={(id) => moves.pickBoss(id)} onInspect={setInspect} />
        <DetailPanel inspect={inspect} onClose={() => setInspect(null)} />
      </div>
    );
  }

  // Main game layout
  return (
    <div className={s.screen} id="main-content">
      <Hud
        phase={phase}
        turn={G.turn}
        isMyTurn={isMyTurn}
        activePid={activePid}
        me={me}
        dungeonCount={countVisibleRooms(me.dungeon)}
      />

      <OpponentRow opponents={opponents} onInspect={setInspect} />

      <div className={s.playArea}>
        <MyDungeon
          me={me}
          phase={phase}
          isMyTurn={isMyTurn}
          selectedCard={selectedCard}
          onSelectTarget={(targetIdx) => {
            if (selectedCard != null && selectedCard >= 0) {
              const c = me.hand[selectedCard];
              if (c?.isRoom) {
                moves.buildRoom(selectedCard, targetIdx);
                setSelectedCard(null);
              }
            }
          }}
          onInspect={setInspect}
        />
        <TownPanel
          me={me}
          town={G.town}
          phase={phase}
          isMyTurn={isMyTurn}
          onResolve={() => moves.resolveNextHero()}
          onInspect={setInspect}
        />
      </div>

      <Hand
        me={me}
        phase={phase}
        isMyTurn={isMyTurn}
        selectedCard={selectedCard}
        onSelect={setSelectedCard}
        onBuild={(i) => moves.buildRoom(i)}
        onBuildInitial={(i) => moves.buildInitialRoom(i)}
        onSpell={(i) => moves.playSpell(i)}
        onPass={() => moves.pass()}
        onInspect={setInspect}
      />

      <LogStrip logs={G.logs} />

      <DetailPanel inspect={inspect} onClose={() => setInspect(null)} />

      {gameOverData && (
        <GameOverScreen
          winner={gameOverData.winner}
          players={gameOverData.players}
          playerID={pidKey}
          onReplay={() => { gameOverFired.current = false; setGameOverData(null); if (onExitMatch) onExitMatch(); }}
          onMenu={() => { gameOverFired.current = false; setGameOverData(null); if (onExitMatch) onExitMatch(); }}
        />
      )}
    </div>
  );
}