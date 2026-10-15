using DBMGameModel.Logic;
using DBMGameModel.Logic.Abilities.Targets;
using DBMGameProject.AI;
using DBMGameProject.Services.PlayerInteraction;

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
        base.InternalResolveTarget(target, r =>
        {
            var list = r?.ToList();
            callback(list);
            Trace.Add(s, "decision", new
            {
                decision = "resolveTarget", player = playerOwner.PlayerId, targetId = target.UniqueID, amount = target.TargetsAmount,
                owner = (target.Ability?.AbilityOwner as LogicCardBase) is LogicCardBase o ? Trace.C(o) : null,
                chosen = list?.Cast<LogicCardBase>().Select(Trace.C).ToArray(),
            });
        }, canBeCanceled);
    }
}
