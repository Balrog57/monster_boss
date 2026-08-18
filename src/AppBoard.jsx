// AppBoard.jsx - Game board orchestrator.
//
// Composes the focused game components (Hud, OpponentRow, MyDungeon, TownPanel,
// Hand, LogStrip, BossSelect, DetailPanel) and wires their interactions. The
// state shape { G, ctx, moves, playerID, isActive, onExitMatch } is provided by
// useOnlineMatch / useLocalMatch (see src/client/useMatch.js).
import React, { useState, useEffect, useRef } from 'react';
import { PHASE } from './cardData.js';
import { treasureCountsByType } from './engine.js';
import { playMusic, playSfx, SFX } from './audio.js';
import { useGameSfx } from './hooks/useGameSfx.js';
import {
  BossSelect, Hud, OpponentRow, MyDungeon, TownPanel, Hand, LogStrip, DetailPanel,
  SpellTargetOverlay, spellNeedsTarget, LevelUpChoiceOverlay, PhaseBanner, OptionsOverlay,
  GameStage, StatsSidebar
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
    return <GameStage bg="/ui/backgrounds/gallery_bg.jpg"><div className={s.loading}>Chargement…</div></GameStage>;
  }
  const pidKey = String(playerID);
  const me = G.players[pidKey];
  if (!me) {
    return <GameStage bg="/ui/backgrounds/gallery_bg.jpg"><div className={s.loading}>Chargement…</div></GameStage>;
  }
  const phase = ctx.phase || G.phase;
  const activePid = G.activePlayer != null ? String(G.activePlayer) : (ctx.currentPlayer != null ? String(ctx.currentPlayer) : '0');
  const isMyTurn = activePid === pidKey;
  const opponentEntries = Object.entries(G.players).filter(([id]) => id !== pidKey);
  const opponents = opponentEntries.map(([, p]) => p);
  const oppIds = opponentEntries.map(([id]) => id);

  // BOSS phase: dedicated selection screen
  if (phase === PHASE.BOSS) {
    return (
      <GameStage bg="/ui/backgrounds/intro_bg.jpg">
        <BossSelect G={G} me={me} onPick={(id) => moves.pickBoss(id)} onInspect={setInspect} />
        <DetailPanel inspect={inspect} onClose={() => setInspect(null)} />
      </GameStage>
    );
  }

  const myTreasures = treasureCountsByType(G, pidKey);
  const oppTreasures = opponents.map((p) => {
    const id = Object.keys(G.players).find((k) => G.players[k] === p);
    return treasureCountsByType(G, id);
  });

  return (
    <GameStage bg="/ui/backgrounds/gallery_bg.jpg">
      <div className={s.board} id="main-content">
      <div className={s.hud}>
      <Hud
        phase={phase}
        isMyTurn={isMyTurn}
        turnDeadline={turnDeadline}
        notification={notification}
        onOptions={() => setOptionsOpen(true)}
      />
      </div>

      <div className={s.town}>
        <TownPanel
          me={me}
          town={G.town}
          phase={phase}
          isMyTurn={isMyTurn}
          onResolve={() => moves.resolveNextHero()}
          onInspect={setInspect}
        />
      </div>

      <div className={s.opponents}>
      <OpponentRow opponents={opponents} onInspect={setInspect} />
      </div>

        <div className={s.dungeon}>
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
              moves.activateRoom(roomIdx, otherIdx);
              setActivateSourceRoom(null);
            } else {
              const stack = me.dungeon[roomIdx];
              const r = Array.isArray(stack) ? stack[stack.length - 1] : stack;
              if (r && NEEDS_OTHER_TARGET.has(r.id)) {
                setActivateSourceRoom(roomIdx);
              } else {
                moves.activateRoom(roomIdx, null);
              }
            }
          }}
          onInspect={setInspect}
        />
        <div className={s.hand}>
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
        </div>
        </div>

      <div className={s.discard} aria-label="Discard pile">
        <img src="/ui/ingame/discard_pile.png" alt="" className={s.discardArt} />
        <img src="/ui/ingame/discard_pile_legend.png" alt="Discard pile" className={s.discardLabel} />
        <div className={s.log}><LogStrip logs={G.logs} /></div>
      </div>

      <div className={s.stats}>
        <StatsSidebar
          me={me}
          opponents={opponents}
          oppIds={oppIds}
          myTreasures={myTreasures}
          oppTreasures={oppTreasures}
          decks={G.decks}
          activePid={activePid}
          meId={pidKey}
          onInspect={(payload) => setInspect(payload)}
          onLevelUp={() => setInspect({ card: me.boss, kind: 'boss' })}
        />
      </div>

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
    </GameStage>
  );
}