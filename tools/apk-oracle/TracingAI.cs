using DBMGameModel;
using DBMGameModel.Logic;
using DBMGameModel.Logic.Abilities;
using DBMGameModel.Logic.Abilities.Targets;
using DBMGameProject.AI;
using DBMGameProject.AI.Statistics;
using DBMGameProject.Services.PlayerInteraction;
using WaveEngine.Framework.Services;

// Sous-classe de l'AIPlayerInteraction ORIGINALE : meme comportement (on appelle toujours base),
// on ajoute seulement l'enregistrement des actions/decisions (le GameBoardFlowLogger de l'APK est
// compile en [Conditional("TESTING"/"WINDOWS")] donc inactif dans la DLL livree).
sealed class TracingAI : AIPlayerInteraction
{
    public static Trace Trace;
    public TracingAI(GameBoard g, Boss owner, AIBrain brain) : base(g, owner, brain) { }

    void Wrap(string kind, object detail, Action body)
    {
        int s = Trace.Begin();
        Trace.Depth++;
        try { body(); }
        finally { Trace.Depth--; Trace.Add(s, kind, detail); }
    }

    public override void BuildRoom(Room roomToBeBuilt, DungeonSlot dungeonSlot = null)
    {
        int idx = dungeonSlot == null ? -1 : playerOwner.Dungeon.IndexOf(dungeonSlot);
        Wrap("action", new { action = "buildRoom", player = playerOwner.PlayerId, room = Trace.C(roomToBeBuilt), slot = idx }, () => base.BuildRoom(roomToBeBuilt, dungeonSlot));
    }

    public override bool UndoBuildRoom(Room roomToUndoBuild)
    {
        bool r = false;
        Wrap("action", new { action = "undoBuildRoom", player = playerOwner.PlayerId, room = roomToUndoBuild == null ? null : Trace.C(roomToUndoBuild) }, () => r = base.UndoBuildRoom(roomToUndoBuild));
        return r;
    }

    public override void PlayRoomAbility(Room room) =>
        Wrap("action", new { action = "playRoomAbility", player = playerOwner.PlayerId, room = Trace.C(room) }, () => base.PlayRoomAbility(room));

    public override void PlaySpell(Spell spell) =>
        Wrap("action", new { action = "playSpell", player = playerOwner.PlayerId, spell = Trace.C(spell) }, () => base.PlaySpell(spell));

    public override bool SetSpellBattleReady()
    {
        bool r = false;
        Wrap("action", new { action = "spellBattleReady", player = playerOwner.PlayerId }, () => r = base.SetSpellBattleReady());
        return r;
    }

    protected override void InternalChooseCardTypeToDraw(Action<bool> drawRoom)
    {
        int s = Trace.Begin();
        base.InternalChooseCardTypeToDraw(r => { drawRoom(r); Trace.Add(s, "decision", new { decision = "chooseDraw", player = playerOwner.PlayerId, drawRoom = r }); });
    }

    protected override void InternalDiscardCardsInHand(List<ILogicCard> options, int amount, Action<IEnumerable<ILogicCard>> callback)
    {
        int s = Trace.Begin();
        var opts = options.Cast<LogicCardBase>().Select(Trace.C).ToArray();
        base.InternalDiscardCardsInHand(options, amount, r =>
        {
            var list = r?.ToList();
            callback(list);
            Trace.Add(s, "decision", new { decision = "discard", player = playerOwner.PlayerId, amount, options = opts, chosen = list?.Cast<LogicCardBase>().Select(Trace.C).ToArray() });
        });
    }

    protected override void InternalResolveTarget(BaseTargetProvider target, Action<IEnumerable<ILogicCard>> callback, bool canBeCanceled = true)
    {
        int s = Trace.Begin();
        int draws0 = RandomProvider.NumberOfCallsToNext; // trace seulement : la cible vient-elle d'un Shuffle() (TriggerCalculator) ?
        base.InternalResolveTarget(target, r =>
        {
            bool shuffled = RandomProvider.NumberOfCallsToNext != draws0; // lu AVANT callback(list) : les effets ulterieurs (melanges de pioche) ne comptent pas
            var list = r?.ToList();
            callback(list);
            Trace.Add(s, "decision", new
            {
                decision = "resolveTarget", player = playerOwner.PlayerId, targetId = target.UniqueID, amount = target.TargetsAmount,
                owner = (target.Ability?.AbilityOwner as LogicCardBase) is LogicCardBase o ? Trace.C(o) : null,
                chosen = list?.Cast<LogicCardBase>().Select(Trace.C).ToArray(), shuffled,
            });
        }, canBeCanceled);
    }
}

// FixedAI (celle de l'oracle) dont SEUL SelectAbilityToUse est reecrit, a l'identique de StatisticAI.SelectAbilityToUse (StatisticAI.cs:58-70) :
// memes appels dans le meme ordre (CalculateAbilityStatistics -> les Check* consomment le RNG comme avant, puis UN WaveServices.Random.NextDouble()
// pour la roulette RandomSelection, StatisticAI.cs:100-115), donc le comportement de l'oracle ne change pas. En plus : trace de l'ensemble des
// capacites eligibles (carte + cibles preregles par SetSelectedTargets) avant le tirage. AIHelper est internal : GetUsableAbilities est recopie (AIHelper.cs:20-31).
sealed class TracingBrain : AIBrain
{
    readonly FixedAI inner = new FixedAI();

    public DeckType SelectWhereToDrawFrom(GameBoard g, Boss p) => inner.SelectWhereToDrawFrom(g, p);
    public IEnumerable<ILogicCard> DiscardCards(GameBoard g, Boss p, IEnumerable<ILogicCard> c, int amount) => inner.DiscardCards(g, p, c, amount);
    public Room SelectRoomToBuild(GameBoard g, Boss p) => inner.SelectRoomToBuild(g, p);
    public DungeonSlot SelectPositionToBuild(GameBoard g, Boss p, Room r) => inner.SelectPositionToBuild(g, p, r);
    public IEnumerable<ILogicCard> SelectTriggerTargets(GameBoard g, Boss p, BaseTargetProvider t) => inner.SelectTriggerTargets(g, p, t);
    public IEnumerable<ILogicCard> SelectCommandTargets(GameBoard g, BaseTargetProvider t) => inner.SelectCommandTargets(g, t);

    public AbilitySelectedInformation SelectAbilityToUse(GameBoard gameState, Boss player)
    {
        var usable = new List<Ability>();
        usable.AddRange(player.DungeonActiveRooms.Where(d => d.CanPlayerPlayAbility(gameState)).Select(d => d.Ability));
        usable.AddRange(player.SpellsInHand.Where(s => s.CanPlayerPlayAbility(gameState)).Select(s => s.Ability));
        IEnumerable<Tuple<double, AbilitySelectedInformation>> stats = null;
        if (usable.Count != 0)
            stats = StatisticsCalculator.CalculateAbilityStatistics(gameState, player, usable);
        var list = stats?.ToList();
        AbilitySelectedInformation result = null;
        if (list != null)
        {
            double num = WaveServices.Random.NextDouble();
            foreach (var element in list)
            {
                result = element.Item2;
                if (!(num <= element.Item1)) { num -= element.Item1; continue; }
                break;
            }
        }
        var eligible = (list ?? new()).Select(t => Describe(t.Item2));
        TracingAI.Trace.AbilityChoice(player, usable.Select(a => (LogicCardBase)a.AbilityOwner), eligible, list == null ? -1 : list.FindIndex(t => t.Item2 == result));
        return result;
    }

    static object Describe(AbilitySelectedInformation info)
    {
        var owner = (LogicCardBase)info.Ability.AbilityOwner;
        // cibles preregles : par effet, par fournisseur de cible, les cartes retenues (GetSelectedTargets)
        var targets = info.PossibleAbilityTargets.Select(e => e.Item2.Select(tp =>
            (info.GetSelectedTargets(tp.Item1) ?? Enumerable.Empty<ILogicCard>()).Cast<LogicCardBase>().Select(Trace.C).ToArray()).ToArray()).ToArray();
        return new { kind = owner is Room ? "room" : "spell", card = Trace.C(owner), targets };
    }
}
