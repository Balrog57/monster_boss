using DBMGameModel.Logic;
using DBMGameModel.Logic.Abilities.Targets;
using DBMGameProject.AI;

// Joueur HUMAIN du tutoriel de l'APK (GamePlayTutScene.cs), scripte comme le joueur qui suit chaque consigne :
//   defausse d'ouverture BMA026 + BMA055 (cs:27-29), puis salles BMA034, BMA016, BMA027 dans les emplacements 1, 2, 3 (cs:186,195,204),
//   capacite de BMA027 quand le heros BMA064 y est (cs:386-394), sort BMA041 sur le heros BMA068 a l'entree du donjon adverse (cs:396-405).
// Tout le reste (hors premier tour, sans consigne) = FixedAI comme un siege IA. Le script s'arrete avec la ligne `NumberOfTurns == 0` : GamePlayTutScene
// ne contraint que le premier tour (cs:181, 310, 376).
sealed class TutorialHumanBrain : AIBrain
{
    readonly FixedAI inner = new FixedAI();
    static readonly string[] Builds = { "BMA034", "BMA016", "BMA027" };
    static readonly string[] Discards = { "BMA026", "BMA055" };

    static int Built(Boss p) => p.Dungeon.Count(s => !s.IsEmpty);

    public DeckType SelectWhereToDrawFrom(GameBoard g, Boss p) => inner.SelectWhereToDrawFrom(g, p);

    public IEnumerable<ILogicCard> DiscardCards(GameBoard g, Boss p, IEnumerable<ILogicCard> cards, int amount)
    {
        var pick = cards.Where(c => Discards.Contains(c.CardNumber)).Take(amount).ToList();
        return pick.Count == amount ? pick : inner.DiscardCards(g, p, cards, amount);
    }

    public Room SelectRoomToBuild(GameBoard g, Boss p)
    {
        int n = Built(p);
        if (g.NumberOfTurns == 0 && n < Builds.Length)
            return p.RoomsInHand.FirstOrDefault(r => r.CardNumber == Builds[n] && p.CanBuildRoom(g, r));
        return inner.SelectRoomToBuild(g, p);
    }

    public DungeonSlot SelectPositionToBuild(GameBoard g, Boss p, Room room)
    {
        int n = Built(p);
        if (g.NumberOfTurns == 0 && n < Builds.Length && room.CardNumber == Builds[n])
        {
            var slot = p.Dungeon[n]; // emplacement 1, 2 puis 3 (index 0, 1, 2)
            if (slot.CanBuildRoom(room) && !slot.PendingToBeBuilt) return slot;
        }
        return inner.SelectPositionToBuild(g, p, room);
    }

    public AbilitySelectedInformation SelectAbilityToUse(GameBoard g, Boss p)
    {
        var hero = g.ActiveHero;
        if (g.NumberOfTurns != 0 || hero == null) return null;
        var top = hero.InsideDungeonSlot?.TopRoom;
        if (hero.CardNumber == "BMA064" && top != null && top.CardNumber == "BMA027" && p.Dungeon.Contains(hero.InsideDungeonSlot) && top.CanPlayerPlayAbility(g))
        {
            var info = new AbilitySelectedInformation(g, top.Ability);
            info.SetSelectedTargets(0, 0, new List<ILogicCard> { top, hero }); // comme AbilityCalculator.CheckBMA027
            return info;
        }
        if (hero.CardNumber == "BMA068" && hero.InsideDungeonSlot == null)
        {
            var spell = p.SpellsInHand.FirstOrDefault(s => s.CardNumber == "BMA041" && s.CanPlayerPlayAbility(g));
            if (spell != null)
            {
                var info = new AbilitySelectedInformation(g, spell.Ability);
                info.SetSelectedTargets(0, 0, new List<ILogicCard> { hero }); // comme AbilityCalculator.CheckBMA041
                return info;
            }
        }
        return null;
    }

    public IEnumerable<ILogicCard> SelectTriggerTargets(GameBoard g, Boss p, BaseTargetProvider t) => inner.SelectTriggerTargets(g, p, t);
    public IEnumerable<ILogicCard> SelectCommandTargets(GameBoard g, BaseTargetProvider t) => inner.SelectCommandTargets(g, t);
}
