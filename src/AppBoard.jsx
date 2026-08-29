// AppBoard.jsx - Game board orchestrator (APK 2.2.6 layout).
import React, { useState, useEffect, useRef } from 'react';
import { PHASE } from './cardData.js';
import { treasureCountsByType, canBuildRoom } from './engine.js';
import { playMusic, playSfx, SFX } from './audio.js';
import { useGameSfx } from './hooks/useGameSfx.js';
import {
  BossSelect, Hud, OpponentRow, MyDungeon, TownPanel, Hand, DetailPanel, Card,
  SpellTargetOverlay, spellNeedsTarget, LevelUpChoiceOverlay, OpeningDiscardOverlay, PhaseBanner, OptionsOverlay,
  GameStage, StatsSidebar, CardPreview, RulesOverlay, LogStrip, CardGallery,
} from './components/game';
import GameOverScreen from './screens/GameOverScreen.jsx';
import s from './AppBoard.module.css';

// Rooms that require choosing ANOTHER room to destroy
const NEEDS_OTHER_TARGET = new Set(['BMA028', 'BMA032']);

export default function AppBoard({ G, ctx, moves, playerID, isActive, onExitMatch, onExitToMenu, turnDeadline, notification }) {
  const [inspect, setInspect] = useState(null);        // { card, kind }
  const [preview, setPreview] = useState(null);        // hover { card, kind }
  const [selectedCard, setSelectedCard] = useState(null);
  const [activateSourceRoom, setActivateSourceRoom] = useState(null); // room index awaiting target
  const [spellTarget, setSpellTarget] = useState(null); // { handIndex, card } awaiting target
  const [gameOverData, setGameOverData] = useState(null);
  const [optionsOpen, setOptionsOpen] = useState(false);
  const [rulesOpen, setRulesOpen] = useState(false);
  const [galleryOpen, setGalleryOpen] = useState(false);
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
    return <GameStage bg="/ui/backgrounds/gallery_bg.webp"><div className={s.loading}>Loading…</div></GameStage>;
  }
  const pidKey = String(playerID);
  const me = G.players[pidKey];
  if (!me) {
    return <GameStage bg="/ui/backgrounds/gallery_bg.webp"><div className={s.loading}>Loading…</div></GameStage>;
  }
  const phase = ctx.phase || G.phase;
  const activePid = G.activePlayer != null ? String(G.activePlayer) : (ctx.currentPlayer != null ? String(ctx.currentPlayer) : '0');
  const isMyTurn = activePid === pidKey;
  const opponentEntries = Object.entries(G.players).filter(([id]) => id !== pidKey);
  const opponents = opponentEntries.map(([, p]) => p);
  const oppIds = opponentEntries.map(([id]) => id);

  const myTreasures = treasureCountsByType(G, pidKey);
  const oppTreasures = opponents.map((p) => {
    const id = Object.keys(G.players).find((k) => G.players[k] === p);
    return treasureCountsByType(G, id);
  });

  const discarding = G.pendingChoice?.type === 'opening-discard';
  const roomDiscard = G.decks?.roomDiscard || [];
  const spellDiscard = G.decks?.spellDiscard || [];
  const topDiscard = roomDiscard.length ? roomDiscard[roomDiscard.length - 1] : spellDiscard[spellDiscard.length - 1];
  const discardCount = roomDiscard.length + spellDiscard.length;
  const topDiscardKind = topDiscard?.isSpell ? 'spell' : topDiscard?.isRoom ? 'room' : 'room';

  const selectedHandCard = selectedCard != null ? me.hand[selectedCard] : null;
  const buildTargets = (() => {
    if (selectedCard == null || !selectedHandCard?.isRoom) return { extend: false, overwrites: [] };
    if (phase === PHASE.SETUP) {
      return { extend: !selectedHandCard.advanced && me.dungeon.length === 0, overwrites: [] };
    }
    const overwrites = [];
    for (let ti = 0; ti < (me.dungeon || []).length; ti++) {
      if (canBuildRoom(G, pidKey, selectedCard, ti)) overwrites.push(ti);
    }
    const extend = canBuildRoom(G, pidKey, selectedCard, null);
    return { extend, overwrites };
  })();

  const hoverKind = (c) => {
    if (!c) return 'room';
    if (c.isSpell) return 'spell';
    if (c.isRoom) return 'room';
    if (c.epic) return 'epic-hero';
    if (c.hp != null) return 'hero';
    if (c.xp != null) return 'boss';
    return 'room';
  };
  const previewInspect = preview
    || (selectedHandCard ? { card: selectedHandCard, kind: hoverKind(selectedHandCard) } : null)
    || (me.boss ? { card: me.boss, kind: 'boss' } : null);

  return (
    <GameStage>
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

      {phase === PHASE.BOSS && (
        <div className={s.bossOverlay}>
          <BossSelect G={G} me={me} onPick={(id) => moves.pickBoss(id)} onInspect={setInspect} inBoard />
        </div>
      )}

      <div className={s.play}>
        {phase !== PHASE.BOSS && (
        <>
        <div className={s.town}>
          <TownPanel
            me={me}
            playerId={pidKey}
            town={G.town}
            townItems={G.townItems || []}
            phase={phase}
            isMyTurn={isMyTurn}
            adventure={G.adventure}
            onResolve={() => moves.resolveNextHero()}
            onInspect={setInspect}
          />
        </div>
        <div className={s.opponents}>
          <OpponentRow
            opponents={opponents}
            oppIds={oppIds}
            treasures={oppTreasures}
            adventure={G.adventure}
            onInspect={setInspect}
            onHover={setPreview}
          />
        </div>
        <div className={s.dungeon}>
          <MyDungeon
            me={me}
            playerId={pidKey}
            phase={phase}
            isMyTurn={isMyTurn}
            adventure={G.adventure}
            treasures={myTreasures}
            selectedCard={selectedCard}
            activateSourceRoom={activateSourceRoom}
            buildTargets={buildTargets}
            onHover={setPreview}
            onSelectTarget={(targetIdx) => {
              if (selectedCard != null && selectedCard >= 0) {
                const c = me.hand[selectedCard];
                if (c?.isRoom) {
                  if (phase === PHASE.SETUP) {
                    moves.buildInitialRoom(selectedCard);
                  } else {
                    moves.buildRoom(selectedCard, targetIdx);
                  }
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
        </div>
        {isMyTurn && !discarding && (
          phase === PHASE.BUILD
          || phase === PHASE.ADVENTURE
          || (phase === PHASE.SETUP && !(me.hand || []).some((c) => c.isRoom && !c.advanced))
        ) && (
          <button
            className={s.passCenter}
            type="button"
            onClick={() => { setSelectedCard(null); moves.pass(); }}
            aria-label="Pass turn"
          />
        )}
        {phase !== PHASE.BOSS && !discarding && (
          <CardPreview inspect={previewInspect} />
        )}
        {phase !== PHASE.BOSS && (
          <div className={s.log}>
            <LogStrip logs={G.logs} />
          </div>
        )}
        </>
        )}
      </div>

      {discarding && G.pendingChoice.playerId === Number(playerID) && (
        <OpeningDiscardOverlay
          hand={me.hand}
          onConfirm={(a, b) => moves.openingDiscard(a, b)}
          onHover={setPreview}
        />
      )}

      <div className={s.dock}>
      <div className={s.discard} aria-label="Discard pile">
        {discardCount > 0 && <span className={s.discardCount}>{discardCount}</span>}
        {topDiscard && (
          <button
            type="button"
            className={s.discardTop}
            onClick={() => setInspect({ card: topDiscard, kind: topDiscardKind })}
            aria-label={`Discard pile: ${topDiscard.name}`}
          >
            <Card card={topDiscard} kind={topDiscardKind} size="sm" />
          </button>
        )}
        <img src="/ui/ingame/discard_pile.webp" alt="" className={s.discardArt} />
        <img src="/ui/ingame/discard_pile_legend.webp" alt="Discard pile" className={s.discardLabel} />
      </div>
      <div className={s.hand}>
      {!discarding && phase !== PHASE.BOSS && (
      <Hand
        me={me}
        phase={phase}
        isMyTurn={isMyTurn}
        selectedCard={selectedCard}
        stackLength={G.stack?.length || 0}
        onSelect={setSelectedCard}
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
        onHover={setPreview}
        showPass={false}
      />
      )}
      </div>
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

      <OptionsOverlay
        open={optionsOpen}
        onClose={() => setOptionsOpen(false)}
        onOpenRules={() => { setOptionsOpen(false); setRulesOpen(true); }}
        onOpenGallery={() => { setOptionsOpen(false); setGalleryOpen(true); }}
      />
      <RulesOverlay open={rulesOpen} onClose={() => setRulesOpen(false)} />
      <CardGallery open={galleryOpen} onClose={() => setGalleryOpen(false)} />

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

      {G.pendingChoice && G.pendingChoice.type !== 'opening-discard' && G.pendingChoice.playerId === Number(playerID) && (
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
          onMenu={() => { gameOverFired.current = false; setGameOverData(null); if (onExitToMenu) onExitToMenu(); else if (onExitMatch) onExitMatch(); }}
        />
      )}
      </div>
    </GameStage>
  );
}