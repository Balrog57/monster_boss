// Oracle headless : fait jouer l'IA ORIGINALE (FixedAI -> StatisticAI) de DBMGame.dll 2.2.6
// sur le GameBoard ORIGINAL, et ecrit une trace JSON (voir Trace.cs).
using System.Reflection;
using System.Runtime.Loader;
using System.Text.Json;
using DBMGameModel;
using DBMGameModel.Info;
using DBMGameModel.Logic;
using DBMGameProject.AI;
using DBMGameProject.Extensions;
using DBMGameProject.Services;
using WaveEngine.Framework.Services;
using WRandom = WaveEngine.Framework.Services.Random;

static class Program
{
    static int Main(string[] args)
    {
        int seed = 1, players = 2, maxTurns = 2000;
        string outPath = null, decksArg = "BaseDeck";
        for (int i = 0; i < args.Length; i++)
        {
            switch (args[i])
            {
                case "--seed": seed = int.Parse(args[++i]); break;
                case "--players": players = int.Parse(args[++i]); break;
                case "--out": outPath = args[++i]; break;
                case "--decks": decksArg = args[++i]; break; // ex: BaseDeck,PlayerChoice,HiddenHeros
                case "--max-turns": maxTurns = int.Parse(args[++i]); break;
                default: Console.Error.WriteLine("arg inconnu " + args[i]); return 2;
            }
        }
        if (seed == 0) { Console.Error.WriteLine("seed must be != 0 (RandomProvider.Shuffle throws on 0)"); return 2; }
        if (outPath == null) { Console.Error.WriteLine("--out <file> requis"); return 2; }

        string repo = FindRepoRoot();
        string asmDir = Path.Combine(repo, "apk-original", "extracted_assemblies");
        // Les DLL Xamarin non referencees (Xamarin.Insights, Mono.Android...) sont resolues ici au besoin.
        AssemblyLoadContext.Default.Resolving += (ctx, name) =>
        {
            var p = Path.Combine(asmDir, name.Name + ".dll");
            return File.Exists(p) ? ctx.LoadFromAssemblyPath(p) : null;
        };

        AppDomain.CurrentDomain.FirstChanceException += (_, ev) =>
        {
            if (!ev.Exception.Message.Contains("Xamarin.Insights")) Trace.LastFirstChance = $"{ev.Exception.GetType().Name}: {ev.Exception.Message} @ {Environment.StackTrace}";
        };
        // LogService.LogException (appele quand une capacite leve, p.ex. GameBoard.DestroyRoom sur une salle deja detruite) passe par
        // Xamarin.Insights.Report : sans plateforme ni initialisation il re-leve et tue la trace. On initialise Insights en mode debug.
        var insights = Assembly.LoadFrom(Path.Combine(asmDir, "Xamarin.Insights.dll"));
        const BindingFlags any = BindingFlags.Static | BindingFlags.Public | BindingFlags.NonPublic;
        var device = insights.GetType("Xamarin.InsightsCore.Device");
        device.GetProperty("PlatformServices", any).SetValue(null, Activator.CreateInstance(insights.GetType("Xamarin.InsightsCore.DebugModePlatformServices")));
        var core = device.GetProperty("Core", any).GetValue(null);
        core.GetType().GetMethod("Initialize", new[] { typeof(string) }).Invoke(core, new[] { insights.GetType("Xamarin.Insights").GetField("DebugModeKey", any).GetValue(null) });
        var decks = decksArg.Split(',').Select(d => Enum.Parse<GameDecks>(d.Trim())).ToList();
        var board = Boot(repo, seed, players, decks);
        var trace = new Trace(board, seed, players, decks);
        TracingAI.Trace = trace;
        var result = Play(board, trace, maxTurns);

        Directory.CreateDirectory(Path.GetDirectoryName(Path.GetFullPath(outPath)));
        File.WriteAllText(outPath, JsonSerializer.Serialize(trace.Finish(result)));
        Console.WriteLine($"seed={seed} players={players} decks={decksArg} -> {result} winner={board.Winner?.CardNumber ?? "none"} turns={board.NumberOfTurns} steps={trace.Count} out={outPath}");
        return result == "complete" ? 0 : 1;
    }

    // Reproduit GameFlowTestService.Initialize() (service de test de l'APK), mais avec nos services Wave.
    static GameBoard Boot(string repo, int seed, int players, List<GameDecks> decks)
    {
        // RNG #1 : WaveServices.Random (xorshift de WaveEngine) sert a toutes les decisions de StatisticAI.
        // Le ctor est internal et seede sur Environment.TickCount : on l'appelle par reflexion avec notre graine.
        var wr = (WRandom)typeof(WRandom).GetConstructor(BindingFlags.Instance | BindingFlags.NonPublic, new[] { typeof(int) }).Invoke(new object[] { seed });
        WaveServices.RegisterService(wr);
        // Storage : ctor internal(IIOManager) -> IO fichier minimal sur assets/Content.
        var io = new ContentIO(Path.Combine(repo, "apk-original", "boss-monster-2-2-6", "assets"));
        var storage = (Storage)typeof(Storage).GetConstructor(BindingFlags.Instance | BindingFlags.NonPublic, new[] { typeof(WaveEngine.Common.IO.IIOManager) }).Invoke(new object[] { io });
        WaveServices.RegisterService(storage);
        WaveServices.RegisterService(new CardInfoService()); // vrai service de l'APK, lit les data.json reels
        WaveServices.InitializeServices();
        // ToolsHeroKind (comme PowerUpPack) est « COMING SOON » dans l'APK 2.2.6 : CardInfoService.GetAvailableDecks l'exclut, donc
        // Initialize() ne le charge jamais et GetCardInfoFromDeck leve « Card Deck not found ». Ses data.json existent pourtant (aucune capacite :
        // toutes nulles) : on le charge par reflexion pour mesurer ce que le moteur ferait de ces cartes (objets inertes, voir tools/parity/README.md).
        if (decks.Contains(GameDecks.ToolsHeroKind))
        {
            var cis = WaveServices.GetService<CardInfoService>();
            typeof(CardInfoService).GetMethod("LoadCardDeck", BindingFlags.Instance | BindingFlags.NonPublic)
                .Invoke(cis, new object[] { GameDecks.ToolsHeroKind, "Content/CardDecks/ToolsHeroKind/data.json" });
            // Pas de ai_info.json non plus pour ce paquet : l'IA (RoomCalculator.CalculateRoomValue) leve « CardNumber not found » des qu'une salle
            // THK est en main. Infos IA vides = l'IA les evalue sans facteur ; cela ne change aucune regle, seulement ses choix.
            const BindingFlags inst = BindingFlags.Instance | BindingFlags.NonPublic | BindingFlags.Public;
            var aiRooms = (Dictionary<string, AIRoomInfo>)typeof(CardInfoService).GetField("infoAIRoomsDictionary", inst).GetValue(cis);
            foreach (var r in cis.GetCardInfoFromDeck<RoomInfo>(new[] { GameDecks.ToolsHeroKind }))
            {
                var a = new AIRoomInfo();
                typeof(AIRoomInfo).GetProperty("CardNumber", inst).SetValue(a, r.CardNumber);
                typeof(AIRoomInfo).GetProperty("Factors", inst).SetValue(a, new List<string>());
                aiRooms[r.CardNumber] = a;
            }
            var aiSpells = (Dictionary<string, AISpellInfo>)typeof(CardInfoService).GetField("infoAISpellsDictionary", inst).GetValue(cis);
            foreach (var sp in cis.GetCardInfoFromDeck<SpellInfo>(new[] { GameDecks.ToolsHeroKind }))
            {
                var a = new AISpellInfo();
                typeof(AISpellInfo).GetProperty("CardNumber", inst).SetValue(a, sp.CardNumber);
                typeof(AISpellInfo).GetProperty("Affects", inst).SetValue(a, "Player");
                aiSpells[sp.CardNumber] = a;
            }
        }

        // RNG #2 : RandomProvider (DBMRandom = clone de System.Random) -> melanges des decks et Shuffle() de l'IA.
        RandomProvider.Seed = seed;
        // rndSeed (Shuffle(useSharedRandom:false)) est initialise sur Environment.TickCount : on le fixe.
        typeof(RandomProvider).GetField("rndSeed", BindingFlags.Static | BindingFlags.NonPublic).SetValue(null, new DBMRandom(seed ^ 0x5eed));

        var cards = WaveServices.GetService<CardInfoService>().GetCardInfoFromDeck(decks);
        var board = new GameBoard();
        board.InititalizeGameBoard(players, new List<BossInfo>(), cards); // tous les boss sont IA
        foreach (var b in board.Players) b.PlayerInteraction = new TracingAI(board, b, new TracingBrain());
        return board;
    }

    static string Play(GameBoard board, Trace trace, int maxTurns)
    {
        trace.Phase("init");
        try
        {
            int guard = 0;
            while (board.CurrentGamePhase != GameBoard.GamePhases.EndOfGame && board.NumberOfTurns < maxTurns)
            {
                if (++guard > 200000) return "stuck";
                // NextStep() sort sans executer de phase quand un duel de sorts vient de se terminer (GameBoard.cs:310-318).
                bool executed = !(board.IsSpellBattleActive && board.IsSpellBattleAllReady);
                board.NextStep();
                trace.Phase("nextStep", executed);
                foreach (var p in board.InGamePlayersPriorized.ToList()) p.PlayerInteraction.DoPlayerActions(); // comme GamePlayBaseScene.DoNextStepAndRefresh
            }
        }
        catch (Exception e) { trace.Error(e); return "error"; }
        return board.CurrentGamePhase == GameBoard.GamePhases.EndOfGame ? "complete" : "maxTurns";
    }

    static string FindRepoRoot()
    {
        var d = new DirectoryInfo(AppContext.BaseDirectory);
        while (d != null && !Directory.Exists(Path.Combine(d.FullName, "apk-original"))) d = d.Parent;
        return d?.FullName ?? throw new Exception("repo root (apk-original/) introuvable");
    }
}
