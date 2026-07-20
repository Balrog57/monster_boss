// AppBoard.jsx - Game board orchestrator.
//
// Composes the focused game components (Hud, OpponentRow, MyDungeon, TownPanel,
// Hand, LogStrip, BossSelect, DetailPanel) and wires their interactions. The
// state shape { G, ctx, moves, playerID, isActive, onExitMatch } is provided by
// useOnlineMatch / useLocalMatch (see src/client/useMatch.js).
import React, { useState, useEffect, useRef } from 'react';
import { PHASE } from './cardData.js';
import { countVisibleRooms } from './engine.js';
import { playMusic, playSfx, SFX } from './audio.js';
import { useGameSfx } from './hooks/useGameSfx.js';
import {
  BossSelect, Hud, OpponentRow, MyDungeon, TownPanel, Hand, LogStrip, DetailPanel,
  SpellTargetOverlay, spellNeedsTarget, LevelUpChoiceOverlay, PhaseBanner, OptionsOverlay
} from './components/game';
import GameOverScreen from './screens/GameOverScreen.jsx';
import s from './AppBoard.module.css';

// Rooms that require choosing ANOTHER room to destroy
const NEEDS_OTHER_TARGET = new Set(['BMA028', 'BMA032']);

export default function AppBoard({ G, ctx, moves, playerID, isActive, onExitMatch, turnDeadline, notification }) {
  const [inspect, setInspect] = useState(null);        // { card, kind }
  const [selectedCard, setSelectedCard] = useState(null);
  const [activateSourceRoom, setActivateSourceRoom] = useState(null); // room index awaiting target
  const [spellTarget, setSpellTarget] = useState(null); // { handIndex, card } awaiting target
  const [gameOverData, setGameOverData] = useState(null);
  const [optionsOpen, setOptionsOpen] = useState(false);
  const gameOverFired = useRef(false);
  const lastPhase = useRef(null);

  // Contextual SFX: watch logs and play sounds at the right moments
  useGameSfx(G);

  // Notification sound when it becomes my turn
  const wasMyTurn = useRef(false);
  useEffect(() => {
    const activePid = G?.activePlayer != null ? String(G.activePlayer) : (ctx?.currentPlayer != null ? String(ctx.currentPlayer) : '0');
    const myTurnNow = activePid === String(playerID);
    if (myTurnNow && !wasMyTurn.current && G && !G.gameOver) {
      playSfx(SFX.BUTTON_FINISH, 0.5);
    }
    wasMyTurn.current = myTurnNow;
  }, [G?.activePlayer, ctx?.currentPlayer]);

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
        turnDeadline={turnDeadline}
        notification={notification}
        onOptions={() => setOptionsOpen(true)}
      />

      <OpponentRow opponents={opponents} onInspect={setInspect} />

      <div className={s.playArea}>
        <MyDungeon
          me={me}
          phase={phase}
          isMyTurn={isMyTurn}
          selectedCard={selectedCard}
          activateSourceRoom={activateSourceRoom}
          onSelectTarget={(targetIdx) => {
            if (selectedCard != null && selectedCard >= 0) {
              const c = me.hand[selectedCard];
              if (c?.isRoom) {
                moves.buildRoom(selectedCard, targetIdx);
                setSelectedCard(null);
              }
            }
          }}
          onActivateRoom={(roomIdx, otherIdx) => {
            if (otherIdx != null) {
              // Target selected — fire the ability
              moves.activateRoom(roomIdx, otherIdx);
              setActivateSourceRoom(null);
            } else {
              const stack = me.dungeon[roomIdx];
              const r = Array.isArray(stack) ? stack[stack.length - 1] : stack;
              if (r && NEEDS_OTHER_TARGET.has(r.id)) {
                // Enter target selection mode
                setActivateSourceRoom(roomIdx);
              } else {
                // No target needed — activate immediately
                moves.activateRoom(roomIdx, null);
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
        onSpell={(i) => {
          const card = me.hand[i];
          if (card && spellNeedsTarget(card.id)) {
            setSpellTarget({ handIndex: i, card });
          } else {
            moves.playSpell(i);
          }
        }}
        onPass={() => moves.pass()}
        onInspect={setInspect}
      />

      <LogStrip logs={G.logs} />

      <PhaseBanner phase={phase} />

      <OptionsOverlay open={optionsOpen} onClose={() => setOptionsOpen(false)} />

      <DetailPanel inspect={inspect} onClose={() => setInspect(null)} />

      {spellTarget && (
        <SpellTargetOverlay
          spell={spellTarget.card}
          G={G}
          me={me}
          playerID={playerID}
          onConfirm={(target) => {
            moves.playSpell(spellTarget.handIndex, target);
            setSpellTarget(null);
          }}
          onCancel={() => setSpellTarget(null)}
        />
      )}

      {G.pendingChoice && G.pendingChoice.playerId === Number(playerID) && (
        <LevelUpChoiceOverlay
          choice={G.pendingChoice}
          onResolve={(optionIndex) => moves.resolveLevelUpChoice(optionIndex)}
        />
      )}

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