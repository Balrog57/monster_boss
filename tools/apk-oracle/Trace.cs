// Trace JSON de l'oracle.
//   { meta, initial:{bosses,deckHeroes,deckRooms,deckSpells,deckItems}, steps:[...], result, winner, turns, error? }
// Chaque step = { seq, kind:"phase"|"action"|"decision", ... , phase, nextPhase, turn, activePlayer, activeHero,
//                 heroesInTown, deckCounts, players:[{playerId,card,hand,spells,dungeon,entrance,souls,wounds,...}] }
//  - "phase"    : apres un GameBoard.NextStep() (phase = phase qui vient d'etre executee).
//  - "action"   : buildRoom / undoBuildRoom / playRoomAbility / playSpell / spellBattleReady (virtuals de PlayerInteractionBase).
//  - "decision" : chooseDraw / discard / resolveTarget (ce que l'IA a choisi).
// L'etat d'un step "action"/"decision" est pris APRES la fin de l'appel ; seq est attribue au DEBUT de l'appel,
// donc les steps sont tries par seq (ordre d'invocation) : un sort declenche d'abord son step, puis ses effets imbriques.
using System.Text.Json;
using DBMGameModel.Info;
using DBMGameModel.Logic;

sealed class Trace
{
    readonly GameBoard board;
    readonly object meta;
    readonly object initial;
    readonly List<(int seq, Dictionary<string, object> e)> steps = new();
    int seq, depth;
    object error;

    public int Count => steps.Count;
    public int Depth { get => depth; set => depth = value; }

    public Trace(GameBoard b, int seed, int players, List<GameDecks> decks)
    {
        board = b;
        meta = new
        {
            engine = "DBMGame.dll 2.2.6 (original assemblies, headless on .NET)",
            seed, players, decks = decks.Select(d => d.ToString()).ToArray(),
            ai = "FixedAI (StatisticAI backup), as used by the APK's GameFlowTestService",
            rng = "RandomProvider.Seed=seed (deck shuffles); WaveServices.Random.Reinitialise(seed) (AI choices)",
        };
        initial = new
        {
            bosses = b.Players.Select(p => new { playerId = p.PlayerId, id = p.UniqueID, card = p.CardNumber, name = p.Name }).ToArray(),
            deckHeroes = b.DeckHeroes.Select(C).ToArray(),
            deckRooms = b.DeckRooms.Select(C).ToArray(),
            deckSpells = b.DeckSpells.Select(C).ToArray(),
            deckItems = b.DeckItems.Select(C).ToArray(),
        };
    }

    public int Begin() => ++seq;

    public void Phase(string why, bool executed = true) => Add(Begin(), "phase", new { why, executed }); // executed=false : NextStep() n'a execute aucune phase

    public void Add(int s, string kind, object detail)
    {
        var e = new Dictionary<string, object>
        {
            ["seq"] = s, ["kind"] = kind, ["depth"] = depth,
            ["turn"] = board.NumberOfTurns, ["phase"] = board.CurrentGamePhase.ToString(), ["nextPhase"] = board.NextGamePhase.ToString(),
            ["spellBattle"] = board.IsSpellBattleActive,
            ["activePlayer"] = board.ActivePlayer?.PlayerId,
            ["activeHero"] = board.ActiveHero == null ? null : H(board.ActiveHero),
        };
        if (detail != null) e["detail"] = detail;
        // Ordre reel des pioches une fois la main d'ouverture distribuee (AvoidMulliganCondition remelange le paquet
        // quand une main est "mauvaise" : `initial` ne suffit alors plus a reconstruire les pioches). Sommet en premier.
        if (kind == "phase" && board.CurrentGamePhase == GameBoard.GamePhases.Setup_a && board.NextGamePhase == GameBoard.GamePhases.Setup_b)
            e["deckOrders"] = new { heroes = board.DeckHeroes.Select(C).ToArray(), rooms = board.DeckRooms.Select(C).ToArray(), spells = board.DeckSpells.Select(C).ToArray(), items = board.DeckItems.Select(C).ToArray() };
        e["heroesInTown"] = board.HeroesInTownQueue.Select(C).ToArray();
        e["deckCounts"] = new { heroes = board.DeckHeroes.Count, rooms = board.DeckRooms.Count, spells = board.DeckSpells.Count, items = board.DeckItems.Count, discardRooms = board.DiscardPileRooms.Count, discardSpells = board.DiscardPileSpells.Count };
        e["players"] = board.Players.Select(P).ToArray();
        steps.Add((s, e));
    }

    public void Error(Exception ex) => error = new { type = ex.GetType().Name, message = ex.Message, stack = ex.ToString() };

    public object Finish(string result) => new
    {
        meta, initial, result,
        turns = board.NumberOfTurns,
        winner = board.Winner == null ? null : new { playerId = board.Winner.PlayerId, card = board.Winner.CardNumber, souls = board.Winner.Souls, wounds = board.Winner.Wounds },
        error,
        steps = steps.OrderBy(t => t.seq).Select(t => t.e).ToArray(),
    };

    public static object C(LogicCardBase c) => new { id = c.UniqueID, card = c.CardNumber };

    static object H(Hero h) => new
    {
        id = h.UniqueID, card = h.CardNumber, type = h.HeroType.ToString(), hp = h.CurrentHealth, maxHp = h.InitialHealth,
        souls = h.Souls, wounds = h.Wounds, slot = h.InsideDungeonSlot == null ? (int?)null : SlotIndex(h.InsideDungeonSlot),
    };

    static int? SlotIndex(DungeonSlot s)
    {
        foreach (var p in TracingAI.Trace.board.Players) { int i = p.Dungeon.IndexOf(s); if (i >= 0) return i; }
        return null;
    }

    object P(Boss p) => new
    {
        playerId = p.PlayerId, id = p.UniqueID, card = p.CardNumber, alive = p.IsAlive, active = p.IsActivePlayer,
        souls = p.Souls, wounds = p.Wounds, score = p.Score, levelUpUnlocked = p.IsLevelUpUnlocked, forceSkipAdventure = p.ForceSkipAdventure,
        maxBuildRoomLimit = p.MaxBuildRoomLimit, dungeonSize = p.DungeonSize,
        hand = p.RoomsInHand.Select(C).ToArray(),
        spells = p.SpellsInHand.Select(C).ToArray(),
        dungeon = p.Dungeon.Select(s => new
        {
            rooms = s.RoomStack.Select(r => new { id = r.UniqueID, card = r.CardNumber, damage = r.Damage, used = r.IsAbilityUsed }).ToArray(), // sommet en premier
            pending = s.PendingToBeBuilt, active = s.IsActive, buffDamage = s.BuffDamage, abilityDamage = s.AbilityDamage, treasuresMultiplier = s.TreasuresMultiplier,
        }).ToArray(),
        entrance = p.EntranceQueue.Select(H).ToArray(),
        soulHeroes = p.SoulsHeroes.Select(C).ToArray(),
        woundHeroes = p.WoundsHeroes.Select(C).ToArray(),
        activeItem = p.ActiveItem == null ? null : C(p.ActiveItem),
    };
}
