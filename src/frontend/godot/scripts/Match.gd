class_name Match
extends Node
## Match — autorité locale (règles ; reference : le C# de l'APK, via tools/apk-oracle).
## Boucle : BOSS -> SETUP (salle initiale) -> BUILD -> BAIT -> ADVENTURE (pas-a-pas) -> END.

signal state_changed

const BossEngine = preload("res://godot/scripts/BossEngine.gd")

const WIN_SOULS := 10

## Paquets de l'APK (BaseDeck, PlayerChoice, HiddenHeros, ToolsHeroKind) ; les autres sont des extensions wiki.
const APK_SETS := ["base", "players-choice", "hidden-heroes", "tools"]

## 5-6 joueurs : seulement avec Crash Landing (livret CRL), et seulement avec ces paquets (jeu de base, Hidden Heroes qui le remplace, Tools et CRL) ;
## les autres (Player's Choice, TNL, Minibosses, THK, IOD, Player's Choice wiki) sont refuses (voir setup_error) pour garder le pool exact de 32 + 21 heros.
const BIG_GAME_SETS := ["base", "hidden-heroes", "tools", "crash-landing"]

## Nombre de joueurs maximal selon les paquets choisis : 6 avec Crash Landing, 4 sinon.
static func max_players(p_sets: Array) -> int:
	return 6 if p_sets.has("crash-landing") else 4

## Message d'erreur (vide = acceptable) pour une partie a `num_players` avec `p_sets` : 5-6 joueurs exigent Crash Landing et n'admettent que BIG_GAME_SETS.
## Partage entre Match.new_match (qui ecarte), le serveur et le lobby (qui refusent).
static func setup_error(num_players: int, p_sets: Array) -> String:
	if num_players < 5:
		return ""
	if num_players > 6:
		return "6 joueurs au maximum"
	if not p_sets.has("crash-landing"):
		return "5 ou 6 joueurs : l'extension Crash Landing est obligatoire"
	for s in p_sets:
		if not str(s) in BIG_GAME_SETS:
			return "5 ou 6 joueurs : le paquet « %s » n'est pas pris en charge (seulement Crash Landing, Hidden Heroes et Tools)" % str(s)
	return ""

## Salles du base set ayant une abilite activable (roomAbilities.js:activateRoomAbility).
const ACTIVATABLE_ROOMS := ["BMA009", "BMA013", "BMA024", "BMA027", "BMA028",
	"BMA030", "BMA032", "BMA038", "BMA039", "CRL012",
	# The Next Level (voir TnlAbilities.ACTIVATED)
	"TNL013", "TNL017", "TNL022", "TNL030", "TNL032", "TNL033", "TNL035", "TNL040", "TNL041", "TNL042", "TNL045", "TNL046",
	"TNL048", "TNL049", "TNL053", "TNL055",
	# Rise of the Minibosses (voir RmbAbilities.ACTIVATED)
	"RMB013", "RMB015", "RMB019", "RMB022", "RMB026", "RMB038", "RMB042", "RMB043", "RMB044", "RMB045", "RMB047", "RMB052", "RMB053", "RMB054",
	# Tools of Hero-Kind (voir ThkAbilities.ACTIVATED ; seulement avec la case wiki)
	"THK021", "THK022", "THK023"]

var G: Dictionary = {}
var human_count := 1
var rng := RandomNumberGenerator.new()
var _ai_driving := false

func _ready() -> void:
	rng.randomize()

func new_match(num_players: int = 2, p_human_count: int = 1, p_sets: Array = ["base"]) -> Dictionary:
	human_count = p_human_count
	var n := clampi(num_players, 2, max_players(p_sets)) # 5-6 joueurs sans Crash Landing : repli a 4 (le serveur et le lobby refusent avant, voir setup_error)
	var sets := {}
	for s in p_sets:
		if n < 5 or String(s) in BIG_GAME_SETS: # a 5-6 joueurs un paquet non pris en charge est ecarte (garantit les 32 + 21 heros)
			sets[String(s)] = true
	if sets.has(ThkAbilities.SET_ID):
		sets["tools"] = true # Tools of Hero-Kind wiki : les memes cartes que le paquet de l'APK, jouees par ThkAbilities
	sets["base"] = true # GamePlayBaseScene : cardDecks = { BaseDeck } + les extensions choisies (le jeu de base est toujours present)
	var in_sets := func(c): return (c as Dictionary).get("set", "base") in sets
	var crl: bool = sets.has("crash-landing")
	# IOD (wiki) : « without Crash Landing, remove the Explorer items and Banseer Bivan » (livret des regles, section Items).
	var bosses: Array = CardDB.bosses.filter(func(c): return in_sets.call(c) and (crl or str((c as Dictionary).get("id", "")) != "IOD025") and _playable_wiki(c))
	# CardInfoService.notInGameCards : BMA023 / BMA033 ne sont jamais distribuees (GetCardInfoFromDeck les ecarte, includeExcludedCards est faux en partie).
	var rooms: Array = CardDB.rooms.filter(func(c): return in_sets.call(c) and not (str((c as Dictionary).get("id", "")) in ["BMA023", "BMA033"]))
	var spells: Array = CardDB.spells.filter(in_sets)
	# CardInfoService.GetCardInfoFromDeck : une carte qui en REMPLACE une autre (ReplacesCardNumber : BMH0xx -> BMA0xx) l'ecarte de la pioche.
	var replaced := {}
	for c in CardDB.heroes:
		if (c as Dictionary).has("replaces") and in_sets.call(c):
			replaced[str(c["replaces"])] = true
	# Decks de l'APK (base, PlayerChoice, HiddenHeros, ToolsHeroKind) : GameBoardExtensions.InternalInititalizeGameBoard garde tous les
	# heros dont MinimumPlayers <= nombre de joueurs (ordinaires d'abord, puis epiques). Les autres paquets (wiki) gardent les tailles de base.
	var apk_only := true
	for s in sets:
		apk_only = apk_only and s in APK_SETS
	# The Next Level : « decide on just one Hero and Epic Hero deck to use » -> avec TNL, le paquet de heros TNL remplace celui du jeu de base.
	var tnl: bool = sets.has(TnlAbilities.SET_ID)
	# Rise of the Minibosses : meme regle (un seul paquet de heros) ; avec TNL, le paquet TNL passe devant celui de RMB.
	var rmb: bool = sets.has(Minibosses.SET_ID)
	var hero_ok := func(c, epic: bool) -> bool:
		var d: Dictionary = c
		if not in_sets.call(d) or replaced.has(str(d.get("id", ""))) or bool(d.get("epic", false)) != epic:
			return false
		if (tnl or rmb) and str(d.get("set", "base")) in ["base", "hidden-heroes"]:
			return false
		if tnl and str(d.get("set", "base")) == Minibosses.SET_ID:
			return false
		return not (apk_only or crl) or int(d.get("playerCount", 2)) <= n # CRL : icones de joueurs respectees (les heros CRL, sans icone, sont toujours inclus)
	var heroes: Array = CardDB.heroes.filter(func(c): return hero_ok.call(c, false))
	var epics: Array = CardDB.heroes.filter(func(c): return hero_ok.call(c, true))
	var room_src: Array = CardDB.expanded_deck(rooms)
	if rmb: # les 10 minibosses sont dans la pioche de salles (livret : « Room Deck with 82 cards »)
		room_src.append_array(CardDB.expanded_deck(CardDB.minibosses.filter(in_sets)))
	for i in room_src.size():
		(room_src[i] as Dictionary)["_uid"] = i + 1 # UniqueID de l'APK : numerotation dans l'ordre du paquet avant melange (GetLogicCards)
	var room_deck: Array = CardDB.shuffled(room_src.map(_room_card))
	var thk_live: bool = sets.has(ThkAbilities.SET_ID) # Excavation (THK025) n'est jouable que derriere la case wiki (l'APK : Ability nulle)
	var spell_src: Array = CardDB.expanded_deck(spells)
	for i in spell_src.size():
		(spell_src[i] as Dictionary)["_uid"] = i + 1 # voir room_src
	var spell_deck: Array = CardDB.shuffled(spell_src.map(func(s): var d = (s as Dictionary).duplicate(); d["isSpell"] = true; return d))
	if thk_live:
		for sc in spell_deck:
			if str((sc as Dictionary).get("id", "")) == "THK025":
				sc["thkLive"] = true
	# ItemInfo (ToolsHeroKind) : GameBoard.DeckItems, une carte revelee par tour (2 a 4 joueurs) dans RevealedItemsQueue ; l'APK n'en fait rien d'autre.
	var items: Array = CardDB.items.filter(func(c):
		var d: Dictionary = c
		if not in_sets.call(d) or int(d.get("playerCount", 2)) > n:
			return false
		if not _playable_wiki(d):
			return false
		if str(d.get("set", "")) == IodAbilities.SET_ID and int(d.get("treasure", 0)) == 5 and not crl:
			return false # IOD : sans Crash Landing, pas d'Objets Explorer
		return sets.has(ThkAbilities.SET_ID) or not sets.has(IodAbilities.SET_ID) or not str(d.get("id", "")).begins_with("THK")) # IOD sans tools-wiki : le moteur des Objets est actif, les Objets THK restent ecartes
	var item_deck: Array = CardDB.shuffled(CardDB.expanded_deck(items).map(func(i): var d = (i as Dictionary).duplicate(); d["isItem"] = true; return d))
	var hero_deck: Array = CardDB.shuffled(CardDB.expanded_deck(heroes).map(func(h): var d = (h as Dictionary).duplicate(); d["souls"] = 1; d["wounds"] = 1; return d))
	var epic_deck: Array = CardDB.shuffled(CardDB.expanded_deck(epics).map(func(h): var d = (h as Dictionary).duplicate(); d["souls"] = 2; d["wounds"] = 2; return d))
	# Tailles officielles (base set) selon le nombre de joueurs.
	var counts: Dictionary = CardDB.HERO_COUNTS[n]
	if tnl or rmb: # livrets TNL / RMB : 13+9 / 17+13 / 25+17 heros, les heros a capacite (etoile) toujours inclus
		hero_deck = TnlAbilities.limit_heroes(hero_deck, n, false)
		epic_deck = TnlAbilities.limit_heroes(epic_deck, n, true)
	elif not apk_only and not crl: # (avec CRL, hero_ok a deja filtre par icone : 2-4 = base de n joueurs + 12 heros CRL ; 5-6 = 32 + 21)
		hero_deck = hero_deck.slice(0, int(counts["ordinary"]))
		epic_deck = epic_deck.slice(0, int(counts["epic"]))
	if n >= 5 and (hero_deck.size() != int(counts["ordinary"]) or epic_deck.size() != int(counts["epic"])):
		push_error("5-6 joueurs : pool de heros %d + %d au lieu de %d + %d" % [hero_deck.size(), epic_deck.size(), counts["ordinary"], counts["epic"]])
	# APK (RandomBossSelectionScene, GameBoardExtensions) : le carrousel montre TOUS les boss des paquets choisis ; le boss de l'humain est
	# tire parmi eux, ceux des IA parmi les restants (pickBoss les retire de la liste).
	var picks: Array = CardDB.shuffled(bosses)
	var players := {}
	for i in n:
		players[i] = {
			"id": i,
			"boss": null, "dungeon": [], "hand": [],
			"souls": [], "wounds": [], "eliminated": false,
			"leveledUp": false, "buildsThisTurn": 0,
			"isAI": i >= human_count,
			"entrance": [],
		}
		if rmb:
			players[i]["coins"] = Minibosses.START_COINS # livret RMB : chaque joueur commence avec 3 Coins dans son Hoard
	G = {
		"players": players, "bossPicks": picks, "numPlayers": n, "sets": sets.keys(),
		"xpOrder": [], "decks": {"rooms": room_deck, "spells": spell_deck, "heroes": hero_deck, "epics": epic_deck, "items": item_deck, "roomDiscard": [], "spellDiscard": [], "heroDiscard": []},
		"itemQueue": [],
		"town": [], "turn": 0, "phase": CardDB.PHASE["BOSS"], "gameOver": null, "log": [], "autoAI": true,
		"stack": [], "stackPassed": {},
	}
	_log("Nouvelle partie : choisissez un boss.")
	state_changed.emit()
	return G

## Carte de la pioche de salles : un miniboss (cards.json `minibosses`, il porte `levels`) est une carte « salle » (isRoom) marquee isMiniboss.
static func _room_card(r) -> Dictionary:
	var d: Dictionary = (r as Dictionary).duplicate()
	d["isRoom"] = true
	if d.has("levels"):
		d["isMiniboss"] = true
	return d

## Une ligne de journal est un texte public, ou {"t": texte complet, "pub": variante publique, "owners": [sieges qui voient "t"]}
## quand elle nomme une carte cachee (pioche, pose face cachee...). ViewFilter ne garde "t" que pour les proprietaires.
func _log(t: String, pub: String = "", owners: Array = []) -> void:
	(G["log"] as Array).append({"t": t, "pub": pub, "owners": owners} if pub != "" else t)
	if (G["log"] as Array).size() > 60:
		(G["log"] as Array).pop_front()

## Texte complet d'une ligne de journal (String publique ou entree privee), pour l'affichage local.
static func log_text(e) -> String:
	return str((e as Dictionary).get("t", "")) if e is Dictionary else str(e)

## Joueur actif. Pendant BUILD c'est le joueur dont c'est le tour dans
## buildOrder, qui suit PlayersPriorized de l'APK = OrderBy(PlayerId) = XP
## decroissant. Hors BUILD, c'est G["activePlayer"] ou le premier du rang XP.
func active_player() -> int:
	if G.has("activePlayer") and G["activePlayer"] != null:
		return int(G["activePlayer"])
	var order: Array = G.get("buildOrder", [])
	if str(G.get("phase", "")) == CardDB.PHASE["BUILD"] and not order.is_empty():
		return int(order[clampi(int(G.get("buildIndex", 0)), 0, order.size() - 1)])
	var xp: Array = G.get("xpOrder", [])
	return int(xp[0]) if not xp.is_empty() else 0

# --- Coups légaux (miroir legalMoves) ---
func legal_moves(pid: int) -> Array:
	var out: Array = []
	if G.get("gameOver") != null:
		return out
	var players: Dictionary = G["players"]
	if not players.has(pid) or (players[pid] as Dictionary).get("eliminated", false):
		return out
	# Un choix en attente gele la partie (miroir reducer.js: early return sur pendingChoice).
	var pc: Dictionary = G.get("pendingChoice", {})
	if not pc.is_empty():
		# Choix ouvert : la partie est gelee (miroir reducer.js: early return global).
		# Seul le joueur concerne peut agir, uniquement pour resoudre.
		if int(pc.get("playerId", -1)) != pid:
			return out
		if str(pc.get("type", "")) == "opening-discard":
			var hand_size: int = (players[pid].get("hand", []) as Array).size()
			for i in hand_size:
				for j in range(i + 1, hand_size):
					out.append({"type": "openingDiscard", "args": [i, j]})
			return out
		var opts: Array = pc.get("options", []) as Array
		var n: int = opts.size()
		if n == 0:
			out.append({"type": "resolveChoice", "args": [-1]})
		else:
			for i in n:
				out.append({"type": "resolveChoice", "args": [i]})
			# Un choix facultatif (Ability.CanAvoid) propose en plus l'option "passer" (index -1). `aiCancel` : CanAvoid faux, un humain ne peut pas annuler, mais l'IA de
			# l'APK abandonne en ne designant rien (AbilityTransaction.cs:187-195) : « passer » reserve aux sieges IA et au harnais d'oracle (G.aiMayCancel).
			if bool(pc.get("optional", false)) or (bool(pc.get("aiCancel", false)) and (bool((players[pid] as Dictionary).get("isAI", false)) or bool(G.get("aiMayCancel", false)))):
				out.append({"type": "resolveChoice", "args": [-1]})
		return out
	var p: Dictionary = players[pid]
	var stack: Array = G.get("stack", [])
	if not stack.is_empty():
		if pid != active_player():
			return out
		# Spell Battle (GameBoard.OnAbilityApplyRequest -> PlayerInteraction.AbilityApplyRequest) : tout joueur vivant
		# peut repondre avec N'IMPORTE QUELLE capacite dont les conditions passent (Ability.CheckConditions) : tout sort
		# jouable dans la phase en cours (Counterspell compris) et toute salle activable. Se limiter a Counterspell /
		# All-Seeing Eye est la politique de l'IA (AbilityCalculator.cs), pas une regle : voir AI.score_move.
		out.append_array(_stack_response_moves(p, pid, stack.size()))
		if TnlAbilities.active(G) or Minibosses.active(G): # Antimagic Zone (depuis la main), Dr. Timebender : annulations
			out.append_array(TnlAbilities.stack_moves(G, p, pid))
		if Minibosses.active(G): # Mageseeker niveau 2 : defausse un sort pour annuler un sort adverse
			out.append_array(Minibosses.stack_moves(G, p, pid))
		if ThkAbilities.active(G): # Tools of Hero-Kind : capacite de Boss d'un Objet (Ring of Invisibility annule un sort, Excavation peut etre contree)
			out.append_array(ThkAbilities.use_moves(G, p, pid))
		out.append({"type": "pass", "args": []})
		return out

	var phase: String = G["phase"]
	match phase:
		"boss":
			if p.get("boss") == null:
				for b in G["bossPicks"]:
					out.append({"type": "pickBoss", "args": [(b as Dictionary)["id"]]})
		"setup":
			# Setup_b : tous les joueurs posent une salle ordinaire (donjon vide : aucune salle avancee possible).
			if bool(G.get("setupBuild", false)) and int(p.get("buildsThisTurn", 0)) == 0:
				for i in (p.get("hand", []) as Array).size():
					if BossEngine.can_build_room(p, G, pid, i, -1):
						out.append({"type": "buildRoom", "args": [i]})
				out.append({"type": "passBuild", "args": []})
			elif bool(G.get("setupBuild", false)) and not bool(p.get("isAI", false)) and not bool(p.get("passed", false)):
				out.append({"type": "passBuild", "args": []}) # DONE : un siege humain valide sa salle initiale (DoneButtonEntity)
				out.append_array(_undo_build_moves(p))
		"build":
			# BuildPhase_a : seul le joueur du tour construit (GameBoard.IsPlayerBuildTurn), mais tout joueur vivant
			# peut jouer un sort / une capacite de salle (rien dans GameBoard n'en limite l'usage au joueur actif ;
			# seules les conditions de la capacite comptent). Hors tour il n'y a ni « passer » ni construction.
			# Fenetre de sorts apres la derniere construction (ActivePlayer == null dans l'APK) : personne ne construit.
			var window: bool = G.has("buildWindow")
			var my_turn := pid == active_player() and not window
			# Un siege IA n'a plus de coup apres avoir passe la fenetre de sorts. Hors tour (BuildPhase_a) il a ses sorts / capacites :
			# AIPlayerInteraction.cs:86-101 appelle UseAbility pour TOUTE IA a chaque NextStep (GamePlayBaseScene.cs:864-871), BuildRoom pour l'active seule.
			# AI.pick_move n'y joue que la capacite tiree (une fois par pas) ; _drive_ai l'y pilote.
			if not my_turn and bool(p.get("isAI", false)) and bool(G.get("autoAI", true)) and window and bool((G["buildWindow"] as Dictionary).get(pid, false)):
				return out
			# Boss.CanBuildRoom = Dungeon.Any(slot.CanBuildRoom), sans test de taille : une salle (ordinaire ou avancee) se construit
			# par-dessus une salle face visible meme si le donjon n'est pas plein (DungeonSlot.CheckRoomCanBeBuilt) ; seule la pose
			# en fin de donjon exige un emplacement libre. Boss.BuildRoom : un emplacement explicite ne peut pas suivre le premier
			# vide ; les piles du donjon etant contigues, toute pile existante precede l'emplacement vide.
			# BuildExtraRoom (Motivation) : MaxBuildRoomLimit++ -> plusieurs constructions avant le NextStep.
			if my_turn and not BossEngine.is_build_blocked(G) and int(p.get("buildsThisTurn", 0)) < 1 + BossEngine.extra_builds_for(G, pid):
				var free_slot := BossEngine.can_build_room(p, G, pid)
				for i in (p.get("hand", []) as Array).size():
					var c: Dictionary = (p["hand"] as Array)[i]
					if not c.get("isRoom", false) or bool(c.get("isMiniboss", false)): # un miniboss se pose par buildMiniboss (Minibosses.extra_moves)
						continue
					# Tour de construction supplementaire force (Boss.ForcedToBuildRoom) : seule cette carte.
					if str(G.get("forcedBuild", "")) != "" and str(c.get("id", "")) != str(G["forcedBuild"]):
						continue
					if not c.get("advanced", false):
						if free_slot:
							out.append({"type": "buildRoom", "args": [i]})
						# Salle ordinaire par-dessus une pile existante, donjon plein ou non. Memes coups pour l'IA et l'humain :
						# AI.score_move note [i] (premier emplacement libre) et [i, ti] (perte de la salle ti recouverte, DungeonSlotCalculator).
						for ti in (p.get("dungeon", []) as Array).size():
							if BossEngine.can_build_room(p, G, pid, i, ti):
								out.append({"type": "buildRoom", "args": [i, ti]})
						continue
					# Salle avancee : un coup cible par emplacement au tresor compatible.
					for ti in (p.get("dungeon", []) as Array).size():
						if BossEngine.can_build_room(p, G, pid, i, ti):
							out.append({"type": "buildRoom", "args": [i, ti]})
			# Sorts jouables en phase BUILD (miroir reducer.js:playSpell).
			# Kobold Strike (SkipBuildPhase : MaxBuildRoomLimit = 0) ne bloque que les constructions, pas les sorts de la phase.
			for i in (p.get("hand", []) as Array).size():
				var c: Dictionary = (p["hand"] as Array)[i]
				if not c.get("isSpell", false):
					continue
				if not CardDB.can_play_spell(c, CardDB.PHASE["EXTRA_BUILD"] if G.has("forcedBuild") else CardDB.PHASE["BUILD"], stack.size()):
					continue
				for t in SpellTargeting.spell_targets_for(G, p, pid, str(c.get("id", ""))):
					out.append({"type": "playSpell", "args": [i, t]})
			out.append_array(_hand_room_moves(pid)) # CRL007 Frostman Lander (se defausse de la main)
				# Abilites de salle activables (miroir reducer.js:activateRoom).
			for i in (p.get("dungeon", []) as Array).size():
				var room = BossEngine.active_room((p["dungeon"] as Array)[i])
				if room == null:
					continue
				var rd: Dictionary = room
				var rid := str(rd.get("id", ""))
				if not ACTIVATABLE_ROOMS.has(rid) or bool(rd.get("usedThisTurn", false)):
					continue
				if rid == "BMA030" and G.has("forcedBuild"):
					continue # Jackpot Stash : DuringPhase(Build) = BuildPhase_a seule, pas ExtraBuildPhase
				if ThkAbilities.ACTIVATED.has(rid): # Tools of Hero-Kind : verification pure ; jamais hors de la case wiki
					if ThkAbilities.active(G) and ThkAbilities.check(G, p, pid, i, rd) == "":
						out.append({"type": "activateRoom", "args": [i]})
					continue
				if Minibosses.active(G) and RmbAbilities.ACTIVATED.has(rid): # RMB : verification pure, sans copie de l'etat
					if RmbAbilities.check(G, p, pid, i, rd) == "":
						out.append({"type": "activateRoom", "args": [i]})
					continue
				if rid == "BMA028" or rid == "BMA032":
					for j in (p.get("dungeon", []) as Array).size():
						if j != i and RoomAbilities.activate_room_ability(G.duplicate(true), pid, i, j) == null:
							out.append({"type": "activateRoom", "args": [i, j]})
				else:
					if RoomAbilities.activate_room_ability(G.duplicate(true), pid, i) == null:
						out.append({"type": "activateRoom", "args": [i]})
			if TnlAbilities.active(G): # Doc Scarecrow
				out.append_array(TnlAbilities.extra_moves(G, p, pid))
			if ThkAbilities.active(G): # Tools of Hero-Kind : capacite de Boss d'un Objet
				out.append_array(ThkAbilities.use_moves(G, p, pid))
			if Minibosses.active(G): # Rise of the Minibosses : pose / promotion / pouvoirs des minibosses, capacites de boss et de main, Coins
				out.append_array(Minibosses.extra_moves(G, p, pid, my_turn))
			if my_turn or (window and not bool((G["buildWindow"] as Dictionary).get(pid, false))):
				out.append({"type": "passBuild", "args": []})
				out.append({"type": "pass", "args": []})
			if my_turn:
				out.append_array(_undo_build_moves(p))
		"adventure":
			var adv: Dictionary = G.get("adventure", {})
			var has_pause: bool = adv.has("pause") and adv["pause"] != null

			# Sorts jouables en phase ADVENTURE (Ring of Invisibility : aucun sort pour le proprietaire du donjon)
			var no_spells: bool = ThkAbilities.spells_blocked(G, pid)
			for i in (p.get("hand", []) as Array).size():
				var c: Dictionary = (p["hand"] as Array)[i]
				if not c.get("isSpell", false) or no_spells:
					continue
				if not CardDB.can_play_spell(c, CardDB.PHASE["ADVENTURE"], stack.size()):
					continue
				for t in SpellTargeting.spell_targets_for(G, p, pid, str(c.get("id", ""))):
					out.append({"type": "playSpell", "args": [i, t]})

			out.append_array(_hand_room_moves(pid)) # CRL007 Frostman Lander
				# Capacités de salle activables
			for i in (p.get("dungeon", []) as Array).size():
				var room = BossEngine.active_room((p["dungeon"] as Array)[i])
				if room == null:
					continue
				var rd: Dictionary = room
				var rid := str(rd.get("id", ""))
				if not ACTIVATABLE_ROOMS.has(rid) or bool(rd.get("usedThisTurn", false)):
					continue
				if ThkAbilities.ACTIVATED.has(rid): # Tools of Hero-Kind : verification pure ; jamais hors de la case wiki
					if ThkAbilities.active(G) and ThkAbilities.check(G, p, pid, i, rd) == "":
						out.append({"type": "activateRoom", "args": [i]})
					continue
				if Minibosses.active(G) and RmbAbilities.ACTIVATED.has(rid): # RMB : verification pure, sans copie de l'etat
					if RmbAbilities.check(G, p, pid, i, rd) == "":
						out.append({"type": "activateRoom", "args": [i]})
					continue
				if rid == "BMA028" or rid == "BMA032":
					for j in (p.get("dungeon", []) as Array).size():
						if j != i and RoomAbilities.activate_room_ability(G.duplicate(true), pid, i, j) == null:
							out.append({"type": "activateRoom", "args": [i, j]})
				else:
					if RoomAbilities.activate_room_ability(G.duplicate(true), pid, i) == null:
						out.append({"type": "activateRoom", "args": [i]})

			if ThkAbilities.active(G): # Tools of Hero-Kind : capacite de Boss d'un Objet
				out.append_array(ThkAbilities.use_moves(G, p, pid))
			if TnlAbilities.active(G) or Minibosses.active(G): # paiement des heros noirs (TNL et RMB)
				out.append_array(TnlAbilities.extra_moves(G, p, pid))
			if Minibosses.active(G):
				out.append_array(Minibosses.extra_moves(G, p, pid, false))
			if has_pause:
				var passed_map: Dictionary = G.get("adventurePausePassed", {})
				if not bool(passed_map.get(str(pid), false)) and not bool(passed_map.get(pid, false)):
					out.append({"type": "pass", "args": []})
					out.append({"type": "passBuild", "args": []})
				elif Minibosses.active(G) and bool(p.get("isAI", false)) and bool(G.get("autoAI", true)):
					out.clear() # RMB, politique IA et non regle : un siege IA qui a passe la fenetre ne la rouvre pas (deux Paywall s'echangeaient des Coins sans fin)
				return out

			if pid != active_player():
				# APK (GameBoard.ChooseNextActivePlayer, AdventurePhase_a) : l'aventure est strictement sequentielle, seul ActivePlayer avance ;
				# hors pause et pile, un siege qui n'est pas actif n'a pas de « passe » (il ferait avancer activePlayer depuis le mauvais siege).
				return out

			var has_active_hero := not adv.is_empty() and int(adv.get("playerId", -1)) == pid
			var has_entrance_hero := _has_entrance_hero(pid)

			if has_active_hero or has_entrance_hero:
				out.append({"type": "adventureNext", "args": []})
				out.append({"type": "resolveNextHero", "args": []})
			else:
				out.append({"type": "pass", "args": []})
				out.append({"type": "passBuild", "args": []})
	return out

## Reprise d'une salle posee ce tour (APK BuildRoomHandSceneBehavior.UndoBuild) : la salle est face cachee et provisoire jusqu'a DONE.
## Un coup par emplacement dont le dessus est une pose en attente de ce siege humain (marque undoBuild = rang de la pose ce tour).
## Regle choisie : tout sort / capacite joue ensuite (par n'importe qui) rend les poses definitives (voir _lock_undo).
func _undo_build_moves(p: Dictionary) -> Array:
	var out: Array = []
	if bool(p.get("isAI", false)):
		return out
	var dungeon: Array = p.get("dungeon", [])
	for i in dungeon.size():
		var top = BossEngine.active_room(dungeon[i])
		if top is Dictionary and (top as Dictionary).has("undoBuild") and bool(top.get("faceDown", false)) and bool(top.get("builtThisTurn", false)) and not top.has("mb"):
			out.append({"type": "undoBuild", "args": [i]})
	return out

## Une carte IOD non implementee (implemented=false dans cards.json : texte ambigu ou moteur disproportionne) reste hors des pioches jouables.
static func _playable_wiki(c) -> bool:
	var d: Dictionary = c
	return str(d.get("set", "")) != IodAbilities.SET_ID or bool(d.get("implemented", true))

## Applique la reprise sur un joueur : la salle du dessus de l'emplacement `ui` retourne en fin de main, la salle recouverte
## (s'il y en avait une) redevient visible, buildsThisTurn redescend. Statique : GameManager l'essaie aussi sur une copie.
## Un paquet wiki (TNL / RMB / CRL) est-il en jeu ? Les corrections propres aux cartes wiki n'atteignent jamais une partie APK pure.
static func wiki_active(G: Dictionary) -> bool:
	for s in G.get("sets", []):
		if not (s in APK_SETS):
			return true
	return false

static func undo_build_on(p: Dictionary, ui: int) -> Dictionary:
	var ud: Array = p["dungeon"]
	var ustack: Array = ud[ui]
	var back: Dictionary = ustack.pop_back()
	if ustack.is_empty():
		ud.remove_at(ui)
	for k in ["faceDown", "builtThisTurn", "undoBuild"]:
		back.erase(k)
	(p["hand"] as Array).append(back)
	p["buildsThisTurn"] = maxi(0, int(p.get("buildsThisTurn", 0)) - 1)
	return back

## Verrouille les poses en attente : un sort, une capacite ou un DONE adverse les rend definitives (le coup precedent ne se rejoue pas a l'envers).
## pass / passBuild ne verrouille que le siege qui passe (DONE) ; pose, reprise, choix de boss et defausse d'ouverture n'y touchent pas.
func _lock_undo(pid: int, mtype: String) -> void:
	if mtype in ["buildRoom", "undoBuild", "pickBoss", "openingDiscard"]:
		return
	for q in G["players"]:
		if mtype in ["pass", "passBuild"] and int(q) != pid:
			continue
		for stack in ((G["players"][q] as Dictionary).get("dungeon", []) as Array):
			for r in stack:
				if r is Dictionary:
					(r as Dictionary).erase("undoBuild")

# --- Application (miroir applyMove) ---
static func _is_same_move_type(a: String, b: String) -> bool:
	if a == b:
		return true
	if (a == "pass" or a == "passBuild") and (b == "pass" or b == "passBuild"):
		return true
	if (a == "adventureNext" or a == "resolveNextHero") and (b == "adventureNext" or b == "resolveNextHero"):
		return true
	if (a == "resolveChoice" or a == "resolveLevelUpChoice") and (b == "resolveChoice" or b == "resolveLevelUpChoice"):
		return true
	return false

## Les deux moteurs n'ecrivent pas les arguments de coup de la meme facon :
## le JS envoie buildRoom [index, targetIndex] avec targetIndex=null quand la
## salle est posee sans cible, le port n'emet que [index]. On compare donc en
## ignorant les arguments nuls de fin, sinon le coup est refuse alors qu'il
## signifie exactement la meme chose.
static func _trim_args(args: Variant) -> Array:
	var a: Array = args.duplicate() if args is Array else []
	while not a.is_empty() and a[a.size() - 1] == null:
		a.pop_back()
	return a


func apply_move(pid: int, move: Dictionary) -> bool:
	if ThkAbilities.active(G):
		IodAbilities.sweep_covered(G) # IOD026 Malakill : l'Objet d'une salle couverte rentre avant que le coup ne la decouvre
	var ok := _apply_move_core(pid, move)
	if ok:
		_lock_undo(pid, str(move.get("type", "")))
	if TnlAbilities.active(G):
		TnlAbilities.flush_torix(G) # TNL003 Torix : les salles Monster defaussees / detruites pendant le coup rejoignent sa main
		TnlAbilities.sync_hero(G) # TNL108 Druid : +X PV selon les sorts en main
	if Minibosses.active(G):
		Minibosses.normalize(G) # RMB : le miniboss suit la salle du sommet de sa pile
	if ThkAbilities.active(G):
		ThkAbilities.sync_hero(G) # Claws of the Berserker : +1 PV par salle Monster du donjon
		IodAbilities.sweep_covered(G)
	return ok

func _apply_move_core(pid: int, move: Dictionary) -> bool:
	var legal := legal_moves(pid)
	var wanted := str(_trim_args(move.get("args", [])))
	var found := false
	for m in legal:
		if _is_same_move_type((m as Dictionary)["type"], str(move.get("type", ""))) and str(_trim_args((m as Dictionary).get("args", []))) == wanted:
			found = true
			break
	if not found:
		return false
	var players: Dictionary = G["players"]
	var p: Dictionary = players[pid]
	match String(move["type"]):
		"resolveChoice":
			_resolve_choice(pid, int(move["args"][0]))
		"openingDiscard":
			var a := int(move["args"][0])
			var b := int(move["args"][1])
			_apply_opening_discard(pid, a, b)
			_queue_next_opening_discard()
		"pickBoss":
			var bid := String(move["args"][0])
			for b in G["bossPicks"]:
				if String((b as Dictionary)["id"]) == bid:
					p["boss"] = (b as Dictionary).duplicate()
					(G["bossPicks"] as Array).erase(b)
					break
			_log("Joueur %d choisit %s." % [pid, p["boss"]["name"]])
			if _all_have_boss():
				_deal_opening_hands()
		"buildRoom":
			var idx := int(move["args"][0])
			# Cible optionnelle : index d'emplacement pour recouvrir une salle
			# existante (salle avancee), sinon la salle va a l'entree du donjon.
			var slot := int(move["args"][1]) if move["args"].size() > 1 and move["args"][1] != null else -1
			var hand: Array = p["hand"]
			if idx < 0 or idx >= hand.size():
				return false
			var card: Dictionary = hand.pop_at(idx)
			# Toujours face cachee : l'APK revele en BuildPhase_b et ne declenche
			# "quand tu construis cette salle" qu'a ce moment-la (endPhaseBuild).
			card["faceDown"] = true
			card["builtThisTurn"] = true
			card["undoBuild"] = int(p.get("buildsThisTurn", 0)) + 1 # reprise possible jusqu'au DONE (rang de la pose : la plus ancienne part d'abord)
			if ThkAbilities.active(G):
				IodAbilities.stamp_built(G, pid, card) # IOD018 Stolen Blueprints : une salle posee apres son usage est detruite en fin de tour
			var dungeon: Array = p["dungeon"]
			if slot >= 0 and slot < dungeon.size():
				(dungeon[slot] as Array).append(card)
				_log("Joueur %d améliore l'emplacement %d avec %s." % [pid, slot + 1, str(card.get("name", "?"))], "Joueur %d améliore l'emplacement %d (face cachée)." % [pid, slot + 1], [pid])
			else:
				TnlAbilities.insert_slot(G, pid, card) # DungeonSlot fixes cote APK : les effets indexes par emplacement (Freeze, Sabotage!, Crushinator...) glissent avec leur salle
				_log("Joueur %d place %s face cachée." % [pid, str(card.get("name", "?"))], "Joueur %d place une salle face cachée." % pid, [pid])
			p["buildsThisTurn"] = int(p.get("buildsThisTurn", 0)) + 1
			if bool(G.get("setupBuild", false)):
				_setup_progress()
			elif _can_build_again(pid) or not bool(p.get("isAI", false)):
				# BuildExtraRoom : le joueur garde la main tant qu'il peut (et veut) poser sa salle supplementaire.
				# Un siege humain garde aussi la main apres sa pose : le tour ne finit qu'au bouton DONE (passBuild), il peut encore jouer des sorts.
				state_changed.emit()
				_drive_ai()
			else:
				_advance_build()
		"undoBuild":
			var undo_slot := int(move["args"][0])
			var slot_freed: bool = undo_slot >= 0 and undo_slot < (p["dungeon"] as Array).size() and ((p["dungeon"] as Array)[undo_slot] as Array).size() == 1
			var back := undo_build_on(p, undo_slot)
			if slot_freed:
				TnlAbilities.remove_slot_effects(G, pid, undo_slot)
			_log("Joueur %d reprend %s en main." % [pid, str(back.get("name", "?"))], "Joueur %d reprend une salle posée." % pid, [pid])
			state_changed.emit()
		"playSpell":
			var si := int(move["args"][0])
			var target: Dictionary = move["args"][1] if move["args"].size() > 1 and move["args"][1] != null else {}
			var hand: Array = p["hand"]
			if si < 0 or si >= hand.size():
				return false
			var spell: Dictionary = hand[si]
			if not spell.get("isSpell", false):
				return false
			var sid := str(spell.get("id", ""))
			var stack: Array = G.get("stack", [])
			# Counterspell : sa cible est un sort ADVERSE encore en attente ; lui-meme est une transaction de la pile
			# (donc contrable a son tour), pas une annulation immediate.
			var counter_idx := -1
			if sid == "BMA043":
				counter_idx = _stack_index_of(str(target.get("stackId", "")))
				if counter_idx < 0 or int((stack[counter_idx] as Dictionary).get("playerId", -1)) == pid:
					return false
				target = {"stackId": str(target["stackId"])}
			hand.remove_at(si)
			_log("Joueur %d joue %s." % [pid, spell.get("name", "?")])
			G["stack"] = stack
			if stack.is_empty():
				G["stackActivePlayer"] = active_player()
			G["stackReturnPlayer"] = pid
			var entry := {
				"id": "spell-%s-%d" % [sid, randi()],
				"type": "spell",
				"playerId": pid,
				"card": spell,
				"target": target,
				"resolved": false
			}
			stack.insert(_stack_insert_index(entry, counter_idx), entry)
			if G.has("buildWindow"):
				G["buildWindow"] = _window_auto_passed() # un sort relance la Spell Battle : tout le monde doit re-passer
			_reopen_stack_window(pid)
			return true
		"activateRoom":
			var ri := int(move["args"][0])
			var in_battle := not (G.get("stack", []) as Array).is_empty()
			var act_room = BossEngine.active_room((p["dungeon"] as Array)[ri]) if ri >= 0 and ri < (p["dungeon"] as Array).size() else null
			var act_rid := str((act_room as Dictionary).get("id", "")) if act_room != null else ""
			var err = RoomAbilities.activate_room_ability(G, pid, ri, int(move["args"][1]) if move["args"].size() > 1 else -1)
			if err != null:
				_log(str(err))
				return false
			if G.has("buildWindow"):
				G["buildWindow"] = _window_auto_passed()
			# Une capacite activee pendant une Spell Battle la relance (IsActivatedByUser : PendingSpellBattlePlayers = tous).
			# All-Seeing Eye garde sa propre reprise de main (RoomAbilities.stack_return_control).
			if in_battle and act_rid != "BMA025":
				_reopen_stack_window(pid)
			elif not in_battle:
				_finish_hero_if_dead()
			return true
		"useItem": # Tools of Hero-Kind : capacite de Boss d'un Objet face visible (comme une capacite de salle, voir ThkAbilities.use_moves)
			var in_battle3 := not (G.get("stack", []) as Array).is_empty()
			var uerr = ThkAbilities.use_item(G, pid, str(move["args"][0]))
			if uerr != null:
				_log(str(uerr))
				return false
			if G.has("buildWindow"):
				G["buildWindow"] = _window_auto_passed()
			if in_battle3:
				if not (G.get("stack", []) as Array).is_empty():
					_reopen_stack_window(pid)
				# pile vide = Ring of Invisibility a annule le dernier sort : la main est deja rendue (stack_return_control), rien a rouvrir
			else:
				_finish_hero_if_dead()
			return true
		"useHandRoom": # CRL007 Frostman Lander : defausse depuis la main, desactive une salle avancee jusqu'a la fin du tour
			RoomAbilities.use_hand_room(G, pid, int(move["args"][0]), move["args"][1] if move["args"].size() > 1 and move["args"][1] != null else {})
			if G.has("buildWindow"):
				G["buildWindow"] = _window_auto_passed()
			return true
		"docScarecrow", "payDarkHero", "payDarkCoins", "timebenderCancel", "antimagicCancel": # The Next Level (voir TnlAbilities.extra_moves / stack_moves)
			var terr = TnlAbilities.apply_move(G, pid, move)
			if terr != null:
				_log(str(terr))
				return false
			if G.has("buildWindow"):
				G["buildWindow"] = _window_auto_passed()
			return true
		"buildMiniboss": # Rise of the Minibosses : un miniboss se pose face cachee a la place d'une salle (meme suite qu'un buildRoom)
			if not Minibosses.apply_build(G, pid, int(move["args"][0]), int(move["args"][1])):
				return false
			if _can_build_again(pid) or not bool(p.get("isAI", false)): # humain : fin de tour par DONE (voir buildRoom)
				state_changed.emit()
				_drive_ai()
			else:
				_advance_build()
			return true
		"promoteMiniboss", "activateMiniboss", "discardForCoin", "rmbBoss", "rmbHand", "rmbPay", "rmbCancel": # RMB (voir Minibosses.extra_moves / stack_moves)
			var in_battle2 := not (G.get("stack", []) as Array).is_empty()
			var rerr = Minibosses.apply_move(G, pid, move)
			if rerr != null:
				_log(str(rerr))
				return false
			if G.has("buildWindow"):
				G["buildWindow"] = _window_auto_passed()
			if not in_battle2:
				_finish_hero_if_dead()
			return true
		"pass", "passBuild":
			var stack: Array = G.get("stack", [])
			if not stack.is_empty():
				var sp: Dictionary = G.get("stackPassed", {})
				sp[str(pid)] = true
				sp[pid] = true
				G["stackPassed"] = sp
				if _stack_all_responders_passed():
					_resolve_pending_stack()
				else:
					var next := _next_stack_responder()
					if next >= 0:
						G["activePlayer"] = next
				return true

			if bool(G.get("setupBuild", false)):
				if int(p.get("buildsThisTurn", 0)) == 0:
					_log("Joueur %d ne construit pas de salle initiale." % pid)
				p["buildsThisTurn"] = maxi(1, int(p.get("buildsThisTurn", 0)))
				p["passed"] = true # DONE de la mise en place (remis a faux au debut de l'aventure)
				_setup_progress()
				return true

			if G.has("buildWindow"):
				(G["buildWindow"] as Dictionary)[pid] = true
				_log("Joueur %d : pret (fenetre de sorts avant la revelation)." % pid)
				_build_window_progress()
				return true

			if str(G.get("phase", "")) == CardDB.PHASE["BUILD"]:
				p["buildsThisTurn"] = maxi(1, int(p.get("buildsThisTurn", 0)))
				_log("Joueur %d passe." % pid)
				_advance_build()
				return true

			if str(G.get("phase", "")) == CardDB.PHASE["ADVENTURE"]:
				var adv: Dictionary = G.get("adventure", {})
				if adv.has("pause") and adv["pause"] != null:
					var pm: Dictionary = G.get("adventurePausePassed", {})
					pm[str(pid)] = true
					pm[pid] = true
					G["adventurePausePassed"] = pm
					_check_adventure_pause_passed()
					return true
				else:
					p["passed"] = true
					p["hasActed"] = true
					_advance_adventure_player()
					return true
		"adventureNext", "resolveNextHero":
			G.erase("afterHero") # le heros suivant est designe : on quitte la fenetre « apres un heros » (voir _finish_hero)
			var adv: Dictionary = G.get("adventure", {})
			if adv.is_empty():
				var entrance: Array = p.get("entrance", [])
				if entrance.is_empty():
					return false
				var first := Minibosses.first_free_hero(G, entrance) if Minibosses.active(G) else 0 # RMB019 Haunted Cavern : un heros peut rester a l'entree
				if first < 0:
					return false
				var hero: Dictionary = entrance[first]
				# BMA041 Assassin (DealHero [-3] sur HeroInDungeon = 1er heros de l'entree) : Target1.Deal(-1 * Number) pose +3 PV sur la carte, gardes a
				# l'entree. effects.heroHealthBonus (remis a zero a _start_turn, comme l'Undo de fin de tour) les porte jusqu'ici ; un heros deja en
				# aventure recoit le +3 dans adventure.hp (SpellEffects._assassin) et ne repasse pas par ici : pas de double compte.
				var hp := BossEngine.hero_health_with_modifiers(G, hero)
				if TnlAbilities.active(G) or Minibosses.active(G) or ThkAbilities.active(G):
					hp += TnlAbilities.on_hero_start(G, pid, hero) # PV retenus jusqu'a l'entree (Werewolf Den, Lightning Bolt!, Shrooman Aviary), Party Up
				if ThkAbilities.active(G):
					hp += ThkAbilities.on_hero_start(G, pid, hero, hp) # Staff of Healing, Oversized Sword, Magic Mirror, Ten Foot Pole, Pet Monster
				G["adventure"] = {
					"playerId": pid,
					"hero": hero,
					"roomIndex": -1,
					"hp": hp,
					"pause": null
				}
				if ThkAbilities.active(G):
					ThkAbilities.sync_hero(G) # Claws of the Berserker
				_advance_adventure_room()
			else:
				if int(adv.get("playerId", -1)) != pid or adv.get("pause") != null:
					return false
				_advance_adventure_room()
			return true
	return true

func _all_have_boss() -> bool:
	for pid in G["players"]:
		if (G["players"][pid] as Dictionary).get("boss") == null:
			return false
	return true

## Resout le pendingChoice courant, puis reprend le flux (miroir de la resolution JS).
func _resolve_choice(pid: int, index: int) -> void:
	TnlAbilities.destroy_actor = pid # Eclipse : une destruction resolue par un choix est celle de celui qui choisit
	_resolve_choice_body(pid, index)
	TnlAbilities.destroy_actor = -1

func _resolve_choice_body(pid: int, index: int) -> void:
	var pc: Dictionary = G.get("pendingChoice", {})
	if pc.is_empty():
		return
	var p: Dictionary = G["players"][pid]
	var opts: Array = pc.get("options", [])
	var kind := str(pc.get("type", ""))
	# Un choix ouvert en cours de phase (activation de salle, All-Seeing Eye...) porte resume=false :
	# il ne doit pas refermer la phase BUILD en se resolvant.
	var resume_build := bool(pc.get("resume", true))
	# -1 = passer / option facultative
	var valid := index >= -1 and (index < opts.size() or index == -1)
	if not valid:
		return
	var finish_dead := false # des degats viennent d'etre infliges au heros actif : il meurt apres la remise a zero du choix
	match kind:
		"recover-card":
			if index >= 0:
				var got = RoomAbilities.take_discard_card(G, p, opts[index])
				if got != null:
					_log("%s : %s recupere." % [str(pc.get("bossName", "")), str((got as Dictionary).get("name", "?"))])
				# Xyzax : CardInDeck(2, DiscardPile) = DEUX cartes choisies ; la 2e est un nouveau choix (ou auto s'il n'en reste qu'une).
				if got != null and int(pc.get("remaining", 1)) > 1:
					var rest := RoomAbilities.discard_card_options(G, "any")
					if rest.size() == 1:
						RoomAbilities.take_discard_card(G, p, rest[0])
					elif rest.size() > 1:
						var nxt_pc := pc.duplicate()
						nxt_pc["remaining"] = int(pc["remaining"]) - 1
						nxt_pc["options"] = rest
						var q0: Array = G.get("choiceQueue", []) if G.get("choiceQueue", null) is Array else []
						q0.push_front(nxt_pc)
						G["choiceQueue"] = q0
		"discard-spell":
			if index >= 0:
				var card: Dictionary = (opts[index] as Dictionary).get("card", {})
				var hand: Array = p.get("hand", []) as Array
				var at := hand.find(card)
				if at >= 0:
					hand.remove_at(at)
				p["hand"] = hand
				var decks: Dictionary = G.get("decks", {})
				var pile: Array = decks.get("spellDiscard", [])
				decks["spellDiscard"] = pile
				pile.append(card)
				Minibosses.on_hand_discard(G, pid, card) # RMB017 Imp Hoard
				# All-Seeing Eye : le sort defausse paie l'annulation du dernier sort adverse.
				if bool(pc.get("thenCancel", false)):
					RoomAbilities.cancel_last_opponent_spell(G, pid, "All-Seeing Eye")
		"revive-hero":
			if index >= 0:
				RoomAbilities.zombie_prison_send_back(G, opts[index])
		"kitchen-discard":
			if index >= 0:
				RoomAbilities.kitchen_discard(G, pid, opts[index])
		"dracolich-discard":
			if index >= 0:
				RoomAbilities.dracolich_discard(G, pid, opts[index], pc.get("pileOptions", []))
		"pick-hero":
			if index >= 0:
				var o: Dictionary = opts[index]
				var ti := int(o.get("townIndex", o.get("index", -1)))
				var town: Array = G.get("town", [])
				if str(o.get("source", "")) == "deck":
					# Seducia : HeroUnassigned = ville OU pioche de heros -> la carte quitte la pioche pour l'entree.
					var dk: Array = (G.get("decks", {}) as Dictionary).get(str(o.get("pile", "heroes")), [])
					var di := int(o.get("deckIndex", -1))
					if di >= 0 and di < dk.size():
						var entrance_d: Array = p.get("entrance", []) as Array
						entrance_d.append(dk.pop_at(di))
						p["entrance"] = entrance_d
				elif ti >= 0 and ti < town.size():
					var hero: Dictionary = town[ti]
					town.remove_at(ti)
					var entrance: Array = p.get("entrance", []) as Array
					entrance.append(hero)
					p["entrance"] = entrance
		"pick-opponent", "discard-spell-opponent":
			if index >= 0 and index < opts.size():
				var o: Dictionary = opts[index]
				var target_pid := int(o.get("targetPlayerId", -1))
				var action := str(pc.get("action", ""))
				if target_pid >= 0 and G["players"].has(target_pid) and action == "steal-random":
					RoomAbilities.steal_random_card(G, pid, target_pid, str(pc.get("bossName", "")))
				elif target_pid >= 0 and G["players"].has(target_pid) and (action == "discard-spell" or action == "discard-room"):
					# C# DiscardRandomCardFromHand(1, Spell|Room) sur l'adversaire choisi
					RoomAbilities._discard_random_from(G, target_pid, action == "discard-spell", str(pc.get("bossName", "")), pid)
		"steal-card":
			if index >= 0:
				var o: Dictionary = opts[index]
				var from_pid := int(o.get("fromPid", -1))
				if from_pid >= 0 and G["players"].has(from_pid):
					var op: Dictionary = G["players"][from_pid]
					var oh: Array = op.get("hand", [])
					op["hand"] = oh
					var hi := int(o.get("handIndex", -1))
					if hi >= 0 and hi < oh.size():
						var card = oh.pop_at(hi)
						var hand: Array = p.get("hand", [])
						p["hand"] = hand
						hand.append(card)
						_log("%s : %s vole une carte au joueur %d." % [str(pc.get("bossName", "")), str(pid), from_pid])
		"search-advanced":
			if index >= 0:
				RoomAbilities.take_searched_room(G, pid, opts[index], str(pc.get("bossName", "")))
		"destroy-room":
			if index >= 0:
				var o: Dictionary = opts[index]
				var target := int(o.get("targetPlayerId", pc.get("playerId", -1)))
				var ri := int(o.get("roomIndex", -1))
				if target >= 0 and G["players"].has(target):
					var tp: Dictionary = G["players"][target]
					var td: Array = tp.get("dungeon", [])
					tp["dungeon"] = td
					if ri >= 0 and ri < td.size():
						RoomAbilities.destroy_room_choice(G, target, ri, str(pc.get("bossName", "")))
				# Adversaires suivants dans la file (Robobo) : saute ceux sans salle, auto-detruit les 1-salle.
				var nxt: Variant = RoomAbilities.robobo_advance(G)
				if nxt != null:
					G["pendingChoice"] = nxt
					state_changed.emit()
					return
		"kill-hero":
			if index >= 0:
				var ti := int((opts[index] as Dictionary).get("townIndex", -1))
				var town: Array = G.get("town", [])
				G["town"] = town
				if ti >= 0 and ti < town.size():
					var hero: Dictionary = town[ti]
					town.remove_at(ti)
					var souls: Array = p.get("souls", [])
					p["souls"] = souls
					for i in maxi(int(hero.get("souls", 1)), 1):
						souls.append(CardDB.soul_entry(hero))
					_log("%s : %s detruit en ville." % [str(pc.get("bossName", "")), str(hero.get("name", "?"))])
		"swap-rooms":
			if index >= 0 and index < opts.size():
				_swap_rooms(p, (opts[index] as Dictionary))
		"draw-type":
			if index >= 0:
				_draw_turn_card(p, str((opts[index] as Dictionary).get("pile", "rooms")))
		"heal-wound":
			if index >= 0:
				BossEngine.heal_one_wound(p, (opts[index] as Dictionary).get("card"))
				_log("%s : %s retourne." % [str(pc.get("bossName", "")), str(((opts[index] as Dictionary).get("card", {}) as Dictionary).get("name", "?"))])
		"search-spell": # KSA003 The Brothers Wise : PutCardInHand(SpellInDeck)
			if index >= 0:
				var spells: Array = (G["decks"] as Dictionary).get("spells", [])
				var so: Dictionary = opts[index]
				if RoomAbilities.pile_index_matches(spells, so):
					(p["hand"] as Array).append(spells.pop_at(int(so["pileIndex"])))
					_log("%s : %s pris dans la pioche de sorts." % [str(pc.get("bossName", "")), str((so["card"] as Dictionary).get("name", "?"))], "%s : un sort pris dans la pioche de sorts." % str(pc.get("bossName", "")), [pid])
		"steal-hero": # KSA004 Kaw'nee : PlaceAtScorekeep(FaceDown) d'un heros ordinaire mort adverse
			if index >= 0:
				var ho: Dictionary = opts[index]
				var from_pid := int(ho.get("fromPid", -1))
				if from_pid >= 0 and G["players"].has(from_pid):
					var their: Array = (G["players"][from_pid] as Dictionary).get("souls", [])
					var si := int(ho.get("soulIndex", -1))
					if si >= 0 and si < their.size():
						var entry: Dictionary = their.pop_at(si)
						entry["faceDown"] = true
						(p["souls"] as Array).append(entry)
						_log("%s : %s passe dans le scorekeeping du joueur %d." % [str(pc.get("bossName", "")), str(entry.get("name", "?")), pid])
		"uncover-own-room": # CRL004 Alien Excavator
			if index >= 0:
				RoomAbilities.uncover_move_to_top(G, pid, opts[index])
		"uncover-room": # CRL003 Mando : un adversaire a la fois (file G.mandoQueue), « may » par adversaire
			if index >= 0:
				RoomAbilities.uncover_move_to_top(G, int((opts[index] as Dictionary).get("targetPlayerId", -1)), opts[index])
			var mnext = RoomAbilities.mando_advance(G) if G.has("mandoQueue") else null
			RoomAbilities.enqueue_pending(G, mnext if mnext != null else {})
		"pick-boss-levelup": # CRL002 Klonos
			if index >= 0:
				var knext = RoomAbilities.copy_level_up(G, pid, (opts[index] as Dictionary)["card"])
				RoomAbilities.enqueue_pending(G, knext if knext != null else {})
		"hero-damage": # CRL016 Darkling Lair
			if index >= 0:
				RoomAbilities.damage_entrance_hero(G, pid, int((opts[index] as Dictionary).get("entranceIndex", -1)), int(pc.get("amount", 0)))
				finish_dead = true
		"omega-refire": # CRL012 The Omega 42 : 1re etape (la salle), puis la carte avancee a defausser
			if index >= 0:
				var onext = RoomAbilities.omega_pick(G, pid, opts[index])
				RoomAbilities.enqueue_pending(G, onext if onext != null else {})
		"omega-discard":
			if index >= 0:
				RoomAbilities.omega_finish(G, pid, pc.get("omega", {}), int((opts[index] as Dictionary).get("handIndex", -1)))
		"tnl-pick": # The Next Level : choix generique (TnlAbilities.resolve_pick) ; renvoie l'etape suivante, ou null
			finish_dead = ThkAbilities.active(G) # THK : Vorpal Blade, The Bomb... peuvent tuer le heros actif
			var tnext = TnlAbilities.resolve_pick(G, pid, pc, index)
			if tnext != null:
				G["pendingChoice"] = tnext
				state_changed.emit()
				return
		"rearrange-dungeon": # KSA002 Hellcow : dungeon puis salles dans l'ordre (voir RoomAbilities.rearrange_choice)
			if index >= 0:
				var ro: Dictionary = opts[index]
				var target_pid := int(ro.get("targetPlayerId", -1))
				var picked: Array = (pc.get("picked", []) as Array).duplicate()
				if str(pc.get("step", "")) == "order":
					picked.append(int(ro.get("roomIndex", -1)))
				var more = RoomAbilities.rearrange_choice(G, int(pc.get("playerId", pid)), target_pid, picked)
				if more != null:
					G["pendingChoice"] = more
					state_changed.emit()
					return
	G["pendingChoice"] = {}
	# Reprend la file de choix en attente, sinon on repart d'un etat propre.
	var raw_queue = G.get("choiceQueue", [])
	var queue: Array = raw_queue if raw_queue is Array else []
	if not queue.is_empty():
		G["pendingChoice"] = queue.pop_front()
	G["choiceQueue"] = queue
	state_changed.emit()
	# Le choix venait de suspendre la phase BUILD : il faut la reprendre, sinon
	# personne ne construit plus et la partie se fige. On NE passe pas au joueur
	# suivant ici : le joueur actif a deja consomme son tour, c'est la phase qui
	# doit se clore (revelation groupee puis leurre).
	if finish_dead and (G.get("pendingChoice", {}) as Dictionary).is_empty():
		_finish_hero_if_dead()
		state_changed.emit()
	if (G.get("pendingChoice", {}) as Dictionary).is_empty() and (G.get("adventure", {}) as Dictionary).has("enterPending"):
		_thk_resume_enter() # Magnetic Ceiling / Warlock / Tax Collector resolus : la salle inflige ses degats
		state_changed.emit()
	var cur_pc: Dictionary = G.get("pendingChoice", {}) as Dictionary if G.get("pendingChoice", null) is Dictionary else {}
	if cur_pc.is_empty() and G.has("tnlGiftBuilt"): # TNL070 Surprise Gift : la salle posee chez l'adversaire a consomme le tour de construction
		var gifter := int(G["tnlGiftBuilt"])
		G.erase("tnlGiftBuilt")
		if G.get("phase", "") == CardDB.PHASE["BUILD"] and gifter == active_player() and not _can_build_again(gifter):
			_advance_build()
			return
	if cur_pc.is_empty() and G.get("phase", "") == CardDB.PHASE["BUILD"]:
		if resume_build:
			if G.has("buildWindow"): # choix ouvert par un sort / une capacite joue dans la fenetre de sorts : la fenetre reprend, la phase ne se referme pas d'office
				_build_window_progress()
				_drive_ai()
			else:
				_close_build_phase()
		else:
			_drive_ai() # le choix etait ouvert en cours de tour : l'IA active reprend la main
	elif cur_pc.is_empty() and bool(G.get("setupReveal", false)):
		_finish_setup() # revelation de Setup_c suspendue par un choix
	elif cur_pc.is_empty() and bool(G.get("tnlEndPending", false)):
		G.erase("tnlEndPending")
		_start_turn() # choix de fin de tour TNL resolu (Shellda, Blockpile Puzzle) : le tour suivant commence

## Echange la salle active de deux piles du meme donjon.
func _swap_rooms(p: Dictionary, option: Dictionary) -> void:
	var dungeon: Array = p.get("dungeon", [])
	var a := int(option.get("roomIndex", -1))
	var b := int(option.get("otherRoomIndex", -1))
	if a < 0 or b < 0 or a >= dungeon.size() or b >= dungeon.size() or a == b:
		return
	var sa: Array = dungeon[a]
	var sb: Array = dungeon[b]
	var ta = BossEngine.active_room(sa)
	var tb = BossEngine.active_room(sb)
	if ta == null or tb == null:
		return
	sa[sa.size() - 1] = tb
	sb[sb.size() - 1] = ta
	_log("Centipede Tunnel : %s <-> %s." % [str(ta.get("name", "?")), str(tb.get("name", "?"))])

## GameBoard.AvoidMulliganCondition : main de salles « mauvaise » si >= 4 salles avancees ou >= 4 salles
## portant le meme tresor (Cleric/Fighter/Mage/Thief ; une salle compte une fois par type).
static func _bad_opening_rooms(rooms: Array) -> bool:
	var advanced := 0
	var per_type := {1: 0, 2: 0, 3: 0, 4: 0}
	for r in rooms:
		if bool((r as Dictionary).get("advanced", false)):
			advanced += 1
		var types := {}
		for t in ((r as Dictionary).get("treasures", []) as Array):
			types[int(t)] = true
		for t in per_type.keys():
			if types.has(t):
				per_type[t] += 1
	return advanced >= 4 or per_type.values().any(func(n): return n >= 4)

## AvoidMulliganCondition : tant que la main est mauvaise, les 5 salles retournent au fond de la pioche,
## TOUTE la pioche est remelangee, puis 5 salles sont repiochees (les sorts ne sont pas concernes).
func _draw_opening_rooms(deck: Array) -> Array:
	var hand: Array = CardDB.draw_cards(deck, 5)
	var guard := 0
	while _bad_opening_rooms(hand) and guard < 100:
		guard += 1
		var all: Array = hand + deck
		deck.clear()
		deck.append_array(all)
		for i in range(deck.size() - 1, 0, -1):
			var j := rng.randi_range(0, i)
			var t = deck[i]
			deck[i] = deck[j]
			deck[j] = t
		hand = CardDB.draw_cards(deck, 5)
	return hand

func _deal_opening_hands() -> void:
	# GameBoard Setup_a : par joueur 5 salles + 2 sorts + AvoidMulligan, puis defausse de 2 cartes pour 5 en main.
	G["phase"] = CardDB.PHASE["SETUP"]
	for pid in G["players"]:
		var p: Dictionary = G["players"][pid]
		var drawn: Array = _draw_opening_rooms(G["decks"]["rooms"]) + CardDB.draw_cards(G["decks"]["spells"], 2)
		p["hand"] = drawn
		if p.get("isAI", false): # tous les modes : 5 salles + 2 sorts, puis defausse de 2 cartes (l'IA ici, l'humain via le choix opening-discard)
			var pair = AI.select_opening_discards(drawn, p, G)
			_apply_opening_discard(pid, pair[0], pair[1])
	if _big_hand():
		TnlAbilities.seed_discards(G) # regles TNL / RMB : defausse amorcee par 4 salles et 2 sorts au hasard, face visible
	G["xpOrder"] = CardDB.order_by_xp(G["players"])
	_queue_next_opening_discard()

## Mise en place des livrets TNL et RMB : la defausse est amorcee par 4 salles + 2 sorts au hasard (la defausse de 2 cartes a l'ouverture vaut pour tous les modes).
func _big_hand() -> bool:
	return TnlAbilities.active(G) or Minibosses.active(G)

func _apply_opening_discard(pid: int, a: int, b: int) -> void:
	var p: Dictionary = G["players"][pid]
	var hand: Array = p.get("hand", [])
	if a < 0 or b < 0 or a >= hand.size() or b >= hand.size() or a == b:
		return
	var idxs := [a, b]
	idxs.sort()
	var card_b: Dictionary = hand.pop_at(idxs[1])
	var card_a: Dictionary = hand.pop_at(idxs[0])
	for card in [card_a, card_b]:
		if card.get("isSpell", false):
			(G["decks"]["spellDiscard"] as Array).append(card)
		else:
			(G["decks"]["roomDiscard"] as Array).append(card)
	_log("Joueur %d a défaussé 2 cartes." % pid)

func _queue_next_opening_discard() -> void:
	for pid in G["players"]:
		var p: Dictionary = G["players"][pid]
		if not p.get("eliminated", false) and not p.get("isAI", false) and (p.get("hand", []) as Array).size() > 5:
			G["pendingChoice"] = {
				"type": "opening-discard",
				"playerId": int(pid),
				"message": "SELECT 2 CARDS TO DISCARD"
			}
			state_changed.emit()
			return
	G["pendingChoice"] = {}
	_log("Mains initiales prêtes (5).")
	_begin_setup_build()

## GameBoard Setup_b : IsPlayerBuildTurn est vrai pour TOUS les joueurs, qui posent chacun une salle
## initiale en parallele (sans ordre de tour, MaxBuildRoomLimit = 1). Les salles restent face cachee ;
## Setup_c (_finish_setup) les revele puis enchaine sur BeginningOfTurn.
func _begin_setup_build() -> void:
	G["phase"] = CardDB.PHASE["SETUP"]
	G["setupBuild"] = true
	for pid in G["players"]:
		(G["players"][pid] as Dictionary)["buildsThisTurn"] = 0
	_log("Phase Setup : chaque joueur construit une première salle.")
	state_changed.emit()
	_setup_progress()

## Fait construire les sieges IA (AIPlayerInteraction.InternalDoPlayerActions, Setup_b) puis passe a Setup_c
## quand chaque joueur a construit ou passe.
func _setup_progress() -> void:
	if not bool(G.get("setupBuild", false)):
		return
	if not _ai_driving and bool(G.get("autoAI", true)):
		_ai_driving = true
		for pid in (G["players"] as Dictionary).keys():
			if not bool(G.get("setupBuild", false)):
				break
			var p: Dictionary = G["players"][pid]
			if bool(p.get("isAI", false)) and int(p.get("buildsThisTurn", 0)) == 0:
				var mv = AI.pick_move(self, int(pid))
				if mv == null or not apply_move(int(pid), mv):
					apply_move(int(pid), {"type": "passBuild", "args": []})
		_ai_driving = false
		if str(G.get("phase", "")) == CardDB.PHASE["BUILD"]:
			_drive_ai() # Setup_c a eu lieu pendant la boucle : le premier joueur de BUILD peut etre une IA
	if not bool(G.get("setupBuild", false)):
		return
	for pid in G["players"]:
		var q: Dictionary = G["players"][pid]
		if not bool(q.get("eliminated", false)) and (int(q.get("buildsThisTurn", 0)) == 0 or (not bool(q.get("isAI", false)) and not bool(q.get("passed", false)))):
			return # un siege humain attend son DONE meme apres avoir pose sa salle
	_finish_setup()

## Setup_c : RevealAllRoomCards (declenche « quand tu construis cette salle ») puis BeginningOfTurn.
## Rappelee par _resolve_choice tant qu'un choix de revelation est en attente (la revelation est idempotente).
func _finish_setup() -> void:
	G["setupBuild"] = false
	G["setupReveal"] = true
	if _reveal_and_level_up():
		return
	G.erase("setupReveal")
	# Setup_c puis ExtraBuildPhase (Construction Zone revelee a la mise en place), puis Setup_c a nouveau.
	G["phase"] = CardDB.PHASE["BUILD"]
	if _start_forced_build():
		G["setupForced"] = true
		return
	_start_turn()

func _start_turn() -> void:
	G["setupBuild"] = false
	G["turn"] = int(G.get("turn", 0)) + 1
	if ThkAbilities.active(G):
		ThkAbilities.on_turn_start(G) # la Blessure supplementaire de Vorpal Blade disparait
	# Les effets « jusqu'a la fin du tour » (Jackpot Stash, bonus de degats...) expirent (reducer.js beginPhaseBeginning).
	G["effects"] = SpellEffects.empty_effects()
	# Phase 1 : BEGINNING (Début de tour)
	G["phase"] = CardDB.PHASE["BEGINNING"]
	_log("Tour %d — phase BEGINNING." % G["turn"])
	if TnlAbilities.active(G):
		TnlAbilities.on_turn_start(G) # photographie des ames du debut de tour (Nicolius)

	# Arrivée des héros en ville : 1 héros par joueur actif (la ville se cumule d'un tour à l'autre)
	_reveal_items()
	_reveal_heroes_in_town()

	# Chaque joueur non-éliminé pioche 1 carte Salle (en ordre d'index de joueur, miroir reducer.js)
	var pids: Array = (G.get("players", {}) as Dictionary).keys()
	pids.sort_custom(func(a, b): return int(a) < int(b))
	var choosers: Array = []
	for pid in pids:
		var p: Dictionary = G["players"][pid]
		if p.get("eliminated", false):
			continue
		p["buildsThisTurn"] = 0
		# EntranceQueue persiste (Trepidation : « Any Hero remain at the entrance », GameBoard.ProccessActiveHero) ; seul le retrait d'un heros la vide.
		if not p.has("entrance"):
			p["entrance"] = []
		for stack in (p.get("dungeon", []) as Array):
			for r in stack:
				if r is Dictionary:
					r["usedThisTurn"] = false
					r.erase("extraTreasures"); r.erase("dealDamage"); r.erase("tnl") # Boss.RestoreDungeon (EndOfTurnPhase) : seulement les salles encore en donjon
		# BMA023 Haunted Library (IsCanChooseCardToDraw) : le joueur CHOISIT sa pioche (salle ou sort) ; son choix est pose apres la
		# boucle (GameBoard.BeginningOfTurn : ActionsSequence executee une fois tous les autres joueurs servis).
		if RoomAbilities.can_choose_draw(p):
			choosers.append(int(pid))
			continue
		_draw_turn_card(p, "rooms")

	# Ordre de construction du tour : joueurs vivants par XP decroissant
	# (APK : PlayersPriorized = OrderBy(PlayerId), et PlayerId suit l'XP decroissant).
	var order := CardDB.order_by_xp(G["players"])
	var alive: Array = []
	for pid in order:
		if not (G["players"][pid] as Dictionary).get("eliminated", false):
			alive.append(int(pid))
	G["buildOrder"] = alive
	G["buildIndex"] = 0
	if not alive.is_empty():
		G["activePlayer"] = int(alive[0])

	# Phase 2 : Transition vers BUILD
	G["phase"] = CardDB.PHASE["BUILD"]
	_log("Tour %d — phase BUILD." % G["turn"])
	if not choosers.is_empty():
		var queue: Array = []
		for cid in choosers:
			queue.append({"type": "draw-type", "resume": false, "playerId": cid, "bossName": "Haunted Library",
				"message": "Haunted Library: draw from the Room deck or the Spell deck",
				"options": [{"label": "Room deck", "pile": "rooms"}, {"label": "Spell deck", "pile": "spells"}]})
		G["pendingChoice"] = queue.pop_front()
		G["choiceQueue"] = queue
	if bool(G.erase("lincolnReveal")): # KSA015 Pixel Lincoln : chaque joueur, par XP, choisit combien de sorts piocher (jusqu'a 3)
		var lc = PcwAbilities.lincoln_start(G)
		if lc != null:
			RoomAbilities.enqueue_pending(G, lc as Dictionary)
	if Minibosses.active(G): # Jinx (salle de plus puis defausse), The Dreadmill (un Coin sur la salle, sinon elle est detruite)
		for rc in Minibosses.on_build_start(G):
			RoomAbilities.enqueue_pending(G, rc)
	# Le premier joueur peut etre une IA : on la joue avant de rendre la main.
	_drive_ai()

## Pioche de debut de tour (DrawRooms / DrawSpells : une carte, la defausse remelangee si la pioche est vide).
func _draw_turn_card(p: Dictionary, pile: String) -> void:
	var drawn := CardDB.draw_pile(G["decks"], pile, 1, rng)
	if not drawn.is_empty():
		(p["hand"] as Array).append(drawn[0])

## GameBoard.RevealItems : 1 objet par tour (2-3 joueurs), 2 (4 joueurs) ou 3 (5-6 joueurs, livret « Beginning of Turn »), vers RevealedItemsQueue. Rien ne l'attache a un heros dans l'APK 2.2.6
## (FlipItem.Execute leve NotImplemented, ItemInfo.HeroAbility/BossAbility sont nuls) : ce sont des cartes inertes.
func _reveal_items() -> void:
	if ThkAbilities.active(G): # case wiki : l'Objet rejoint la ville et s'attache a un heros (ThkAbilities)
		ThkAbilities.reveal_items(G)
		return
	var deck: Array = (G["decks"] as Dictionary).get("items", [])
	var queue: Array = G.get("itemQueue", [])
	G["itemQueue"] = queue
	var seats: int = (G["players"] as Dictionary).size()
	for _i in (3 if seats >= 5 else (2 if seats == 4 else 1)):
		if not deck.is_empty():
			queue.append(deck.pop_back())

func _reveal_heroes_in_town() -> void:
	# GameBoard.RevealHeroes : un heros par joueur de la partie (Players.Count), eliminés compris.
	var alive_count: int = (G["players"] as Dictionary).size()
	var decks: Dictionary = G["decks"]
	# GameBoard.RevealHeroes : DeckHeroes vide => « No more heroes in deck » ; la defausse de heros n'est JAMAIS remelangee
	# (contrairement aux pioches de salles/sorts, ReShuffleDiscardsPilesBackToDeck).
	for i in alive_count:
		var drawn := CardDB.draw_cards(decks["heroes"], 1)
		if drawn.is_empty():
			drawn = CardDB.draw_cards(decks["epics"], 1)
		if not drawn.is_empty():
			(G["town"] as Array).append(drawn[0])
			if ThkAbilities.active(G):
				(drawn[0] as Dictionary)["townTurn"] = int(G.get("turn", 0)) # IOD018 Stolen Blueprints : « the turn this Hero enters town »
			if str((drawn[0] as Dictionary).get("id", "")) == "KSA015":
				G["lincolnReveal"] = true # Pixel Lincoln : choix de pioche des joueurs une fois les pioches de debut de tour faites (_start_turn)
	if ThkAbilities.active(G):
		ThkAbilities.attach_all(G) # un Objet encore en ville s'attache aux heros qui viennent d'arriver
	_log("%d héros sont en ville." % (G["town"] as Array).size())

## Le joueur actif vient de consommer son tour de construction : on passe au
## suivant. Quand il n'en reste plus, BuildPhase_b revele TOUTES les salles d'un
## coup, puis on enchaine sur le leurre (miroir de GameBoard.NextStep).
## Vrai si le joueur actif a droit a une autre construction ce tour (Motivation) et un coup de pose legal.
func _can_build_again(pid: int) -> bool:
	if int((G["players"][pid] as Dictionary).get("buildsThisTurn", 0)) >= 1 + BossEngine.extra_builds_for(G, pid):
		return false
	for m in legal_moves(pid):
		if str((m as Dictionary).get("type", "")) == "buildRoom":
			return true
	return false

func _advance_build() -> void:
	var order: Array = G.get("buildOrder", [])
	var done_idx := int(G.get("buildIndex", 0))
	if done_idx < order.size(): # DeactivateLastActivePlayer (GameBoard.cs:1215) : la limite de construction du joueur qui cesse d'etre actif redevient 1
		((G["players"] as Dictionary).get(int(order[done_idx]), {}) as Dictionary).erase("buildLimit")
	G["buildIndex"] = int(G.get("buildIndex", 0)) + 1
	if int(G["buildIndex"]) < order.size():
		# On memorise le joueur actif dans l'etat comme le JS (G.activePlayer),
		# sinon l'etat ne dit pas qui joue.
		G["activePlayer"] = int(order[int(G["buildIndex"])])
		_drive_ai()
		return
	var was_forced := G.has("forcedBuild")
	G.erase("forcedBuild")
	if not was_forced and _open_build_window():
		state_changed.emit()
		_drive_ai() # les sieges IA jouent (ou passent) dans la fenetre
		return
	_close_build_phase()

## GameBoard : apres la derniere construction (ActivePlayer == null, BuildPhase_a) les joueurs peuvent encore jouer des
## sorts AVANT la revelation (BuildPhase_b), IA comprise (AIPlayerInteraction.InternalDoPlayerActions). Ouverte seulement si un
## siege a un sort jouable ; les sieges IA y jouent via _drive_ai (AI.pick_move), sinon passent.
func _open_build_window() -> bool:
	G["buildWindow"] = _window_auto_passed()
	if bool(G.get("autoAI", true)) and G.get("activePlayer") != null:
		(G["buildWindow"] as Dictionary)[int(G["activePlayer"])] = true # le dernier constructeur vient d'appuyer sur DONE : pas de second DONE pour lui
	for pid in G["players"]:
		if (G["buildWindow"] as Dictionary).has(pid):
			continue
		for m in legal_moves(int(pid)):
			if str((m as Dictionary).get("type", "")) == "playSpell":
				return true
	G.erase("buildWindow")
	return false

func _window_auto_passed() -> Dictionary:
	var passed := {}
	for pid in G["players"]:
		var q: Dictionary = G["players"][pid]
		if bool(q.get("eliminated", false)):
			passed[pid] = true
	return passed

## Premier siege IA vivant qui n'a pas encore passe dans la fenetre de sorts (-1 : aucun).
func _window_ai_seat() -> int:
	var passed: Dictionary = G.get("buildWindow", {})
	for pid in G["players"]:
		var q: Dictionary = G["players"][pid]
		if bool(q.get("isAI", false)) and not bool(q.get("eliminated", false)) and not bool(passed.get(pid, false)):
			return int(pid)
	return -1

func _build_window_progress() -> void:
	var passed: Dictionary = G.get("buildWindow", {})
	for pid in G["players"]:
		if not bool((G["players"][pid] as Dictionary).get("eliminated", false)) and not bool(passed.get(pid, false)):
			state_changed.emit()
			return
	G.erase("buildWindow")
	_close_build_phase()

## BuildPhase_b : revelation groupee + level-up, puis BAIT et ADVENTURE.
## Idempotent : appele aussi apres la resolution d'un choix suspendu en phase BUILD.
func _close_build_phase() -> void:
	if _reveal_and_level_up():
		return
	if _start_forced_build():
		return
	if G.erase("setupForced"):
		_start_turn()
		return
	if _king_vote():
		return
	G["phase"] = CardDB.PHASE["BAIT"]
	_log("Tour %d — phase BAIT (Leurre)." % G["turn"])
	_resolve_bait()
	G.erase("kingVote")
	G["phase"] = CardDB.PHASE["ADVENTURE"]
	_log("Phase ADVENTURE : les héros avancent.")
	_init_adventure_phase()

## CRL028 The King : « each player MAY vote » (Bait phase). Un choix facultatif par joueur vivant (XP decroissante) avant le leurre ; les votes vont dans
## G.kingVote (joueur -> cible, lus par BossEngine.lure_tied). Renvoie true tant qu'un vote est en attente (le leurre reprend via _close_build_phase).
func _king_vote() -> bool:
	if G.has("kingVote"):
		return false
	var has_king := false
	for h in (G.get("town", []) as Array):
		has_king = has_king or (CardDB.hero_lure(h as Dictionary) == "vote" and not (TnlAbilities.active(G) and TnlAbilities.no_lure(G, h)))
	if not has_king:
		return false
	G["kingVote"] = {}
	var ballots: Array = []
	for voter in CardDB.order_by_xp(G["players"]):
		if bool((G["players"][voter] as Dictionary).get("eliminated", false)):
			continue
		var opts: Array = []
		for tp in CardDB.order_by_xp(G["players"]):
			if not bool((G["players"][tp] as Dictionary).get("eliminated", false)):
				opts.append({"targetPlayerId": int(tp), "label": "Lure the King to player %d" % (int(tp) + 1), "ai": AiWiki.king_vote_ai(G, int(voter), int(tp))})
		var ballot = TnlAbilities.ask(G, int(voter), "hero_king", opts, {}, "The King: vote for the dungeon he is lured to (or abstain)", "The King", true)
		if ballot is Dictionary:
			ballot["resume"] = true # la resolution du dernier vote relance _close_build_phase
		ballots.append(ballot)
	var first = TnlAbilities.flush(G, ballots)
	if first == null:
		return false
	G["pendingChoice"] = first
	return true

## ExtraBuildPhase (GameBoard.NextStep) : PendingExtraBuiltTurns, alimente par ExtraBuildTurn (Construction Zone,
## cardId vide = n'importe quelle salle) et BuildRoomBy (Cleopatra, King Croak : limite a la carte cherchee,
## Boss.ForcedToBuildRoom). Il se joue apres la revelation et avant le leurre ; en le terminant (build ou passe),
## la phase se referme normalement (BuildPhase_b : nouvelle revelation, puis nouvel extra eventuel, puis BAIT).
## Le siege IA de l'APK ne fait rien s'il n'a aucune salle a poser : un tour sans coup de construction possible
## est saute (c'est le meme etat, sans clic « Done » inutile). Renvoie true si un tour a demarre.
func _start_forced_build() -> bool:
	var raw = G.get("forcedBuilds", [])
	var queue: Array = raw if raw is Array else []
	G["forcedBuilds"] = queue
	while not queue.is_empty():
		var fb: Dictionary = queue.pop_front()
		var pid := int(fb.get("playerId", -1))
		var p: Dictionary = (G["players"] as Dictionary).get(pid, {}) as Dictionary
		if p.is_empty() or p.get("eliminated", false):
			continue
		G["forcedBuild"] = str(fb.get("cardId", ""))
		G["buildOrder"] = [pid]
		G["buildIndex"] = 0
		G["activePlayer"] = pid
		p["buildsThisTurn"] = 0
		var can_build := false
		for m in legal_moves(pid):
			if str((m as Dictionary).get("type", "")) == "buildRoom":
				can_build = true
				break
		if not can_build:
			G.erase("forcedBuild")
			_log("Joueur %d : tour de construction supplementaire sans salle constructible, ignore." % pid)
			continue
		_log("Joueur %d : tour de construction supplementaire." % pid)
		state_changed.emit()
		_drive_ai()
		return true
	return false

## Fin de phase BUILD : revele les salles face-down puis declenche le level-up
## (reducer.js:endPhaseBuild). Renvoie true si un choix est en attente.
func _reveal_and_level_up() -> bool:
	if not G.has("revealQueue"):
		G["revealQueue"] = _build_reveal_queue()
	var queue: Array = G["revealQueue"]
	while not queue.is_empty():
		var it: Dictionary = queue.pop_front()
		var pid := int(it["pid"])
		var choice = null
		match str(it["kind"]):
			"room":
				choice = RoomAbilities.on_build_room(G, pid, it["room"])
			"another":
				RoomAbilities.run_another_room_trigger(G, pid, it["room"])
			"levelup":
				choice = RoomAbilities.process_level_up(G, pid)
		if choice != null:
			if not (it.get("pre", {}) as Dictionary).is_empty():
				choice["apkPre"] = it["pre"]
			G["pendingChoice"] = choice
			return true
	G.erase("revealQueue")
	return false

## GameBoard.RevealAllRoomCards : par joueur (PlayerId croissant) et par slot en attente, retourne la salle et met en file
## ses declencheurs (WhenYouBuildThisRoom, WhenYouBuildAnotherRoom, level-up au 5e slot). EnqueueAbilityTransaction insere
## une transaction AVANT la premiere deja en file du meme PlayerId : elles s'executent donc dans l'ordre inverse de la file.
func _build_reveal_queue() -> Array:
	var out: Array = []
	var by_pid := {}
	var order: Array = CardDB.order_by_xp(G["players"])
	# C# : les cibles se figent en parcourant Players (sieges, `G.apkSeats` du harnais), la file reste triee par PlayerId.
	for pid in G.get("apkSeats", order):
		var p: Dictionary = (G["players"] as Dictionary).get(pid, {})
		if p.is_empty() or p.get("eliminated", false):
			continue
		var mine: Array = []
		var dun: Array = p.get("dungeon", [])
		for si in range(dun.size() - 1, -1, -1): # slots en attente par indice C# croissant (Godot : le slot C# k est a l'indice size-1-k)
			var room = BossEngine.active_room(dun[si])
			if room == null or not (room as Dictionary).get("faceDown", false):
				continue
			var r: Dictionary = room
			mine.append({"pid": int(pid), "kind": "room", "room": r, "pre": ApkAI.reveal_target(G, int(pid), r)}) # cible figee a la mise en file (C#)
			for o in RoomAbilities.another_room_triggers(G, int(pid)): # avant faceDown=false : la salle compte comme « en attente » (C#)
				mine.append({"pid": int(pid), "kind": "another", "room": o})
			r["faceDown"] = false
			r.erase("undoBuild")
			_log("Salle révélée : %s pour le joueur %s" % [str(r.get("name", "?")), str(pid)])
			# Boss.DungeonSize == 5 : le dernier slot C# (indice Godot 0) est revele ; un slot en attente plus profond differe le level-up
			if dun.size() >= 5 and not bool((BossEngine.active_room(dun[0]) as Dictionary).get("faceDown", false)) and not p.get("leveledUp", false):
				p["leveledUp"] = true
				_log("Joueur %s EST MONTÉ EN NIVEAU !" % str(pid))
				mine.append({"pid": int(pid), "kind": "levelup"})
		mine.reverse()
		by_pid[pid] = mine
	for pid in order:
		out.append_array(by_pid.get(pid, []))
	if Minibosses.active(G): # toutes les salles sont revelees : les minibosses sautent sur les nouveaux sommets, puis paient 1 Coin (sinon defausses)
		Minibosses.normalize(G)
		Minibosses.reveal_all(G)
	return out

## Pilote les sieges IA tant que le joueur actif en est une. Comme dans le JS,
## l'IA n'a pas de chemin prive : elle choisit un coup avec AI.pick_move puis le
## soumet par apply_move, donc elle passe par exactement le meme code que le
## joueur humain. (L'ancien _ai_build recopiait la construction a la main et
## sautait la revelation de fin de phase.)
func _drive_ai() -> void:
	if not bool(G.get("autoAI", true)) or _ai_driving:
		return
	_ai_driving = true
	var guard := 0
	while guard < 64:
		guard += 1
		if G.get("gameOver") != null or G.get("pendingChoice", {}) != {}:
			break
		if str(G.get("phase", "")) != CardDB.PHASE["BUILD"]:
			break
		if _ai_offturn():
			continue
		var pid := active_player()
		if G.has("buildWindow") and (G.get("stack", []) as Array).is_empty():
			pid = _window_ai_seat() # fenetre de sorts : c'est le siege IA qui n'a pas passe, pas le dernier constructeur
			if pid < 0:
				break
		var p: Dictionary = (G.get("players", {}) as Dictionary).get(pid, {}) as Dictionary
		if p.is_empty() or not p.get("isAI", false):
			break
		var mv = AI.pick_move(self, pid)
		if mv != null and apply_move(pid, mv):
			continue
		if not apply_move(pid, {"type": "passBuild", "args": []}):
			break
	_ai_driving = false

## Les IA hors tour jouent leur UseAbility du pas (AIPlayerInteraction.cs:86-101, GamePlayBaseScene.cs:864-871). Vrai si l'une a joue.
func _ai_offturn() -> bool:
	if G.has("buildWindow") or G.has("forcedBuild") or not (G.get("stack", []) as Array).is_empty():
		return false
	var ap := active_player()
	var ids: Array = (G["players"] as Dictionary).keys()
	ids.sort()
	for pid in ids:
		if int(pid) == ap or not bool((G["players"][pid] as Dictionary).get("isAI", false)):
			continue
		var mv = AI.pick_move(self, int(pid))
		if mv != null and apply_move(int(pid), mv):
			return true
	return false

func _resolve_bait() -> void:
	var remaining_town: Array = []
	G["luredThisTurn"] = {} # heros leurres par joueur ce tour (CRL031 Healing Tank)
	var town: Array = G.get("town", [])
	var order := CardDB.order_by_xp(G["players"])
	# 5-6 joueurs (livret CRL) : les heros a egalite de tresors sont partages entre les joueurs a egalite (BossEngine.lure_split_targets).
	var split: Dictionary = BossEngine.lure_split_targets(G["players"], order, town, G) if CardDB.big_game(G) else {}
	for i in town.size():
		var hero = town[i]
		if TnlAbilities.active(G) and TnlAbilities.no_lure(G, hero): # TNL001 Doc Scarecrow : ce heros ne peut pas etre leurre ce tour
			remaining_town.append(hero)
			_log("%s ne peut pas etre leurre ce tour (Doc Scarecrow)." % (hero as Dictionary).get("name", "?"))
			continue
		var treasure := int((hero as Dictionary).get("treasure", 1))
		var target: int = int(split[i]) if split.has(i) else BossEngine.lure_target(G["players"], order, treasure, hero, G)
		if target >= 0:
			var target_player: Dictionary = G["players"][target]
			(target_player["entrance"] as Array).append(hero)
			(G["luredThisTurn"] as Dictionary)[target] = int((G["luredThisTurn"] as Dictionary).get(target, 0)) + 1
			if TnlAbilities.active(G):
				TnlAbilities.on_lured(G, target) # Super Effective! : « only one Hero was lured to your dungeon this turn »
			_log("%s est attiré par le donjon du joueur %d !" % [(hero as Dictionary).get("name", "?"), target])
		else:
			remaining_town.append(hero)
			_log("%s reste en ville (égalité de trésors)." % (hero as Dictionary).get("name", "?"))
	G["town"] = remaining_town

func _turn_order() -> Array:
	var o: Array = CardDB.order_by_xp(G["players"])
	var t := int(G.get("turn", 1))
	for i in t % max(1, o.size()):
		o.append(o.pop_front())
	return o


## Capacites « defausser cette salle de la main » (CRL007 Frostman Lander) : une par cible, jouables en BUILD et en ADVENTURE.
func _hand_room_moves(pid: int) -> Array:
	var out: Array = []
	var hand: Array = ((G["players"] as Dictionary)[pid] as Dictionary).get("hand", []) as Array
	for i in hand.size():
		if str((hand[i] as Dictionary).get("id", "")) == "CRL007":
			for t in RoomAbilities.hand_room_targets(G, i, pid):
				out.append({"type": "useHandRoom", "args": [i, t]})
	return out

## Coups de reponse d'un joueur pendant une Spell Battle : sorts jouables dans la phase (cibles comprises) + salles activables.
func _stack_response_moves(p: Dictionary, pid: int, stack_len: int) -> Array:
	var out: Array = []
	var phase := str(G.get("phase", ""))
	if G.has("forcedBuild") and phase == CardDB.PHASE["BUILD"]:
		phase = CardDB.PHASE["EXTRA_BUILD"]
	var hand: Array = p.get("hand", []) as Array
	for i in hand.size():
		var c: Dictionary = hand[i]
		if not c.get("isSpell", false) or not CardDB.can_play_spell(c, phase, stack_len) or ThkAbilities.spells_blocked(G, pid):
			continue
		for t in SpellTargeting.spell_targets_for(G, p, pid, str(c.get("id", ""))):
			out.append({"type": "playSpell", "args": [i, t]})
	var dungeon: Array = p.get("dungeon", []) as Array
	for i in dungeon.size():
		var room = BossEngine.active_room(dungeon[i])
		if room == null:
			continue
		var rd: Dictionary = room
		var rid := str(rd.get("id", ""))
		if bool(rd.get("usedThisTurn", false)) or bool(rd.get("faceDown", false)):
			continue
		if rid == "BMA025":
			if RoomAbilities.can_cancel_spell(G, pid) and not TnlAbilities.no_text(rd):
				out.append({"type": "activateRoom", "args": [i]})
		elif ThkAbilities.ACTIVATED.has(rid): # Tools of Hero-Kind : verification pure
			if ThkAbilities.active(G) and ThkAbilities.check(G, p, pid, i, rd) == "":
				out.append({"type": "activateRoom", "args": [i]})
		elif Minibosses.active(G) and RmbAbilities.ACTIVATED.has(rid): # RMB : verification pure (une copie profonde de l'etat perd l'identite des heros)
			if RmbAbilities.check(G, p, pid, i, rd) == "":
				out.append({"type": "activateRoom", "args": [i]})
		elif ACTIVATABLE_ROOMS.has(rid):
			if rid == "BMA028" or rid == "BMA032":
				for j in dungeon.size():
					if j != i and RoomAbilities.activate_room_ability(G.duplicate(true), pid, i, j) == null:
						out.append({"type": "activateRoom", "args": [i, j]})
			elif RoomAbilities.activate_room_ability(G.duplicate(true), pid, i) == null:
				out.append({"type": "activateRoom", "args": [i]})
	return out

## Rang de joueur = Boss.PlayerId (XP decroissant, voir _stack_response_order).
func _player_rank(pid: int) -> int:
	var xp_order: Array = G.get("xpOrder", [])
	if xp_order.is_empty():
		xp_order = CardDB.order_by_xp(G["players"])
	var r := xp_order.find(pid)
	return r if r >= 0 else 999

func _stack_index_of(stack_id: String) -> int:
	var stack: Array = G.get("stack", [])
	for i in stack.size():
		if str((stack[i] as Dictionary).get("id", "")) == stack_id:
			return i
	return -1

## Position d'une nouvelle transaction dans PendingAbilityTransactions (GameBoard.EnqueueAbilityTransaction) ;
## l'index 0 est resolu en premier (NextStep : First()). Joueur du tour -> tete (donc LIFO entre ses propres sorts) ;
## sinon juste avant le premier sort d'un joueur hors-tour de rang >= au sien qui n'est pas un Counterspell, sinon en fin.
## Un Counterspell est ensuite replace juste avant sa cible (OnAbilityApplyRequest) : il se resout donc avant elle.
## Ce n'est NI du FIFO NI du LIFO pur : le joueur du tour passe devant, les autres suivent par rang de joueur.
func _stack_insert_index(entry: Dictionary, counter_target_idx: int) -> int:
	if counter_target_idx >= 0:
		return counter_target_idx
	var stack: Array = G.get("stack", [])
	var active := -1 if G.has("buildWindow") else int(G.get("stackActivePlayer", -1)) # fenetre apres la derniere construction : ActivePlayer == null (tri PlayerId pur)
	var caster := int(entry.get("playerId", -1))
	if caster == active:
		return 0
	var rank := _player_rank(caster)
	for i in stack.size():
		var t: Dictionary = stack[i]
		var tp := int(t.get("playerId", -1))
		if tp != active and _player_rank(tp) >= rank and str((t.get("card", {}) as Dictionary).get("id", "")) != "BMA043":
			return i
	return stack.size()

## Gestion de la pile de sorts (ordre de resolution : voir _stack_insert_index). Ordre de reponse = GameBoard.OnAbilityApplyRequest :
## InGamePlayersPriorized (PlayerId croissant = rang XP), lanceur exclu ; le joueur du tour n'a aucune priorite.
func _stack_response_order() -> Array:
	var caster := str(G.get("stackReturnPlayer", ""))
	var order: Array = []
	var xp_order: Array = G.get("xpOrder", [])
	if xp_order.is_empty():
		xp_order = CardDB.order_by_xp(G["players"])
	for pid in xp_order:
		var spid := str(pid)
		var ipid := int(pid)
		var pl: Dictionary = (G.get("players", {}) as Dictionary).get(ipid, {}) as Dictionary
		if spid != caster and not pl.is_empty() and not pl.get("eliminated", false):
			order.append(ipid)
	return order

## Un sort / une capacite vient d'etre ajoute : tous les AUTRES joueurs peuvent repondre a nouveau (PendingSpellBattlePlayers
## est reinitialise a chaque capacite activee). S'il n'y a plus personne, la pile se resout.
func _reopen_stack_window(pid: int) -> void:
	G["stackReturnPlayer"] = pid
	var sp: Dictionary = {str(pid): true}
	sp[pid] = true
	G["stackPassed"] = sp
	if not (G.get("pendingChoice", {}) as Dictionary).is_empty():
		return # le joueur garde la main le temps de son choix, puis passe
	var next := _next_stack_responder()
	if next >= 0:
		G["activePlayer"] = next
	else:
		_resolve_pending_stack()

func _next_stack_responder() -> int:
	var passed: Dictionary = G.get("stackPassed", {})
	for pid in _stack_response_order():
		if not bool(passed.get(str(pid), false)) and not bool(passed.get(pid, false)):
			return int(pid)
	return -1

func _stack_all_responders_passed() -> bool:
	var passed: Dictionary = G.get("stackPassed", {})
	for pid in _stack_response_order():
		if not bool(passed.get(str(pid), false)) and not bool(passed.get(pid, false)):
			return false
	return true

func _resolve_pending_stack() -> void:
	var stack: Array = G.get("stack", [])
	while not stack.is_empty():
		var effect: Dictionary = stack.pop_front() # index 0 = prochain a se resoudre (NextStep : PendingAbilityTransactions.First())
		if bool(effect.get("resolved", false)):
			continue
		var etype := str(effect.get("type", ""))
		if etype == "spell":
			var card: Dictionary = effect.get("card", {})
			var caster_id := int(effect.get("playerId", 0))
			var target: Dictionary = effect.get("target", {})
			var decks: Dictionary = G.get("decks", {})
			var sd: Array = decks.get("spellDiscard", [])
			decks["spellDiscard"] = sd
			sd.append(card) # la carte part en defausse a l'activation (OnAbilityApplyRequest), annulee ou non
			if bool(effect.get("canceled", false)):
				if TnlAbilities.active(G):
					TnlAbilities.record_played(G, caster_id, card) # Save Point : un sort annule a bien ete « played » (la carte est en defausse)
				_log("Le sort %s a ete annule." % str(card.get("name", "?")))
				effect["resolved"] = true
				continue
			if Minibosses.active(G) and not Minibosses.pay_short_circuit(G, caster_id): # RMB077 Short Circuit : 1 Coin par sort, sinon il est annule
				effect["resolved"] = true
				continue
			_log("Le sort %s se résout." % str(card.get("name", "?")))
			if TnlAbilities.active(G): # Swordmage +2, Spellslime Pit, Hall of Mirrors : avant les effets du sort (non annule)
				TnlAbilities.on_spell_resolving(G, caster_id, card)
			if str(card.get("id", "")) == "BMA043":
				# CancelSpellAbility.Execute : la transaction cible est annulee (elle reste en liste, mais ne s'executera pas).
				var ti := _stack_index_of(str(target.get("stackId", "")))
				if ti >= 0:
					(stack[ti] as Dictionary)["canceled"] = true
					_log("Counterspell annule %s." % str(((stack[ti] as Dictionary).get("card", {}) as Dictionary).get("name", "?")))
				else:
					_log("Counterspell : cible deja partie.")
			else:
				TnlAbilities.destroy_actor = caster_id
				SpellEffects.cast_spell(G, caster_id, card, target)
				TnlAbilities.destroy_actor = -1
			if Minibosses.active(G):
				Minibosses.on_spell_cast(G, caster_id) # Baron Hex, Alchemist's Lab : un sort vient d'etre lance (resolu, non annule)
			var caster: Dictionary = (G.get("players", {}) as Dictionary).get(caster_id, {}) as Dictionary
			var cdun: Array = caster.get("dungeon", [])
			for k in cdun.size():
				var r = BossEngine.active_room(cdun[k])
				# Ability.CheckConditions : slot actif (non gele) et capacites non verrouillees (Trap Master)
				if r != null and str(r.get("id", "")) == "BMA026" and not bool(r.get("faceDown", false)) and not bool(r.get("usedThisTurn", false)) and not TnlAbilities.no_text(r) and not BossEngine.is_room_deactivated(G, caster_id, k) and not BossEngine.abilities_locked(G, caster_id):
					var drawn = CardDB.draw_pile(decks, "spells", 1, rng)
					if not drawn.is_empty():
						(caster.get("hand", []) as Array).append(drawn[0])
						_log("Liger's Den : pioche un sort.")
					r["usedThisTurn"] = true # OncePerTurn est PAR salle (Ability.CheckConditions) : chaque Liger's Den actif pioche (GameBoard.cs:796, 1290-1305)
		effect["resolved"] = true
	G["stack"] = []
	RoomAbilities.stack_return_control(G)
	_finish_hero_if_dead()

## Résolution d'aventure pas-à-pas (AdventurePhase_a, b, c et fenêtres de pause)
## Heros tue par une capacite / un sort (hp <= 0) : mort immediate (KillHeroInRoom), sans attendre la fin de la pause.
func _finish_hero_if_dead() -> void:
	if TnlAbilities.active(G):
		TnlAbilities.sync_hero(G)
	var adv: Dictionary = G.get("adventure", {})
	if adv.is_empty() or int(adv.get("hp", 1)) > 0:
		adv.erase("dealZero")
		return
	if bool(adv.get("dealZero", false)):
		return # DealHero a mis le heros a 0 PV : il meurt au pas suivant, dans la salle d'apres (voir RoomAbilities.deal_hero)
	var hero: Dictionary = adv.get("hero", {})
	var pid: int = int(adv.get("playerId", 0))
	var death_room: Dictionary = G.get("_deathRoom", {})
	if death_room.is_empty() and not bool(adv.get("roomGone", false)) and not bool(adv.get("noDeathTrigger", false)):
		var p: Dictionary = G["players"][pid]
		var idx: int = int(adv.get("roomIndex", -1))
		var d: Array = p.get("dungeon", [])
		if idx >= 0 and idx < d.size():
			var r = BossEngine.active_room(d[idx])
			if r != null:
				death_room = r
	G.erase("_deathRoom")
	_finish_hero(pid, hero, int(adv.get("hp", 0)), death_room)

func _init_adventure_phase() -> void:
	# AdventurePhase_a : ChooseNextActivePlayer appelle DeactivateLastActivePlayer (GameBoard.cs:1215) pour CHAQUE joueur vivant, ce qui remet
	# MaxBuildRoomLimit a 1 : la limite de Kobold Strike / Motivation survit au tour de construction du joueur, mais pas au tour de jeu.
	for bp in G["players"]:
		(G["players"][bp] as Dictionary).erase("buildLimit")
	G.erase("afterHero")
	G.erase("apkSkippedHero")
	G["adventure"] = {}
	G["adventurePausePassed"] = {}
	var xp: Array = CardDB.order_by_xp(G["players"])
	G["xpOrder"] = xp
	G["activePlayer"] = int(xp[0]) if not xp.is_empty() else 0
	for pid in G["players"]:
		var p: Dictionary = G["players"][pid]
		p["passed"] = false
		p["hasActed"] = false
	if not _has_adventure_work() and not _adventure_window_has_actions():
		_check_end_or_next_turn()

## Sans heros, l'oracle ouvre quand meme les fenetres AdventurePhase_a/b de chaque joueur (oracle wide s5-p2 : Dark Altar active au
## tour 8 sans aucun heros). On garde donc la phase ouverte seulement si un joueur a une action a y jouer (sort, capacite) : sinon
## le tour se termine d'un coup, sans « passer » inutile pour les humains.
func _adventure_window_has_actions() -> bool:
	for pid in G["players"]:
		if bool((G["players"][pid] as Dictionary).get("eliminated", false)):
			continue
		for m in legal_moves(int(pid)):
			if not (str((m as Dictionary).get("type", "")) in ["pass", "passBuild", "adventureNext", "resolveNextHero"]):
				return true
	return false

## Equivalent Godot de `GameBoard.ActiveHero != null` (IsAdventureInteractionTurn, GameBoard.cs:285-293) : un heros est actif, ou designe et sur le point
## d'entrer (AdventurePhase_b), ou une Spell Battle est ouverte. Trepidation joue dans la fenetre pre-aventure de sa cible retire le heros de l'entree
## alors que l'APK le garde actif jusqu'a ProccessActiveHero (flag `apkSkippedHero`, pose par SpellEffects._trepidation). Seule l'interface humaine
## l'interroge (BoardUI : cartes grisees, aucune fenetre d'activation) ; `legal_moves` n'en depend pas (IA et rejeu de l'oracle inchanges).
func apk_active_hero() -> bool:
	if str(G.get("phase", "")) != CardDB.PHASE["ADVENTURE"]:
		return true
	if not (G.get("adventure", {}) as Dictionary).is_empty() or not (G.get("stack", []) as Array).is_empty():
		return true
	var ap := active_player()
	return _has_entrance_hero(ap) or int(G.get("apkSkippedHero", -1)) == ap

## Heros a l'entree du donjon qui vont encore agir ce tour : Trepidation (Boss.ForceSkipAdventure) les laisse a l'entree
## (GameBoard.ChooseNextActiveHero : AdventurePhase_a direct).
func _has_entrance_hero(pid: int) -> bool:
	var p: Dictionary = (G.get("players", {}) as Dictionary).get(pid, {}) as Dictionary
	if Minibosses.active(G) and Minibosses.first_free_hero(G, p.get("entrance", []) as Array) < 0:
		return false # RMB019 Haunted Cavern : les heros restants n'entrent pas ce tour
	return not (p.get("entrance", []) as Array).is_empty() and not ((G.get("effects", {}) as Dictionary).get("skipAdventure", []) as Array).has(pid)

func _has_adventure_work() -> bool:
	if not G.get("adventure", {}).is_empty():
		return true
	for pid in G["players"]:
		var p: Dictionary = G["players"][pid]
		if not p.get("eliminated", false) and _has_entrance_hero(int(pid)):
			return true
	return false

func _advance_adventure_room() -> void:
	var adv: Dictionary = G.get("adventure", {})
	if adv.is_empty():
		return
	var pid: int = int(adv["playerId"])
	var p: Dictionary = G["players"][pid]
	var hero: Dictionary = adv["hero"]
	var dungeon: Array = p.get("dungeon", [])
	var prev: int = int(adv.get("roomIndex", -1))
	var replayed: bool = adv.erase("replay") # replay : voir BossEngine.destroy_room
	var i: int = prev + (0 if replayed else 1)
	var went_back: bool = adv.erase("back") # Minotaur's Maze : recule d'une salle (l'index du pas courant reste celui de la salle du Maze)
	if went_back:
		i -= 2
	# BMA053 Teleportation = MoveHeroToRelativeSlot(5) (Commands/MoveHeroToRelativeSlot.cs:Execute) : le heros va au slot C# min(DungeonSize - 1, slot + 5), soit la 1re salle
	# (index Godot 0). GameBoard.ProccessActiveHero fait ensuite num = slot ; « lastActiveHeroSlotIndex == -1 ou == num » => num-- : depuis la 1re salle (ou avant l'entree,
	# last = -1) le heros avance d'un cran (pas d'effet / il saute la 1re salle) ; ailleurs il retraverse le donjon depuis la 1re salle, PV conserves.
	var eff := SpellEffects._effects(G)
	if eff.get("teleportHero") != null and str(eff["teleportHero"]) == str(hero.get("id", "")):
		eff["teleportHero"] = null
		i = 1 if prev <= 0 else 0
	adv["roomIndex"] = i
	if TnlAbilities.active(G) and not replayed and not went_back:
		# The Next Level : le heros quitte la salle `prev` en vie (Collapsing Bridge, Bom-Boy Factory), puis saute des salles (Shortcut!, Archer).
		i = TnlAbilities.on_room_exit(G, pid, prev, i)
		i = TnlAbilities.skip_rooms(G, pid, hero, i)
		adv["roomIndex"] = i
	if Minibosses.active(G) and not replayed and not went_back:
		i = RmbAbilities.on_advance(G, pid, prev, i) # RMB : Foyer Elemental (le heros survit a la salle), Mageseeker niveau 3 (saute la premiere salle)
		adv["roomIndex"] = i
	if ThkAbilities.active(G) and not replayed and not went_back:
		i = ThkAbilities.on_room_exit(G, pid, prev, i) # THK : Ice Rod, Inquisitor's Robes, Bag of Holding, Boots of Jumping
		adv["roomIndex"] = i

	if i < 0: # emplacement vide traverse apres la destruction de la salle du heros (BossEngine.destroy_room) : aucun degat
		adv["pause"] = "post-damage"
		G["adventurePausePassed"] = {}
		_log("%s traverse un emplacement vide." % str(hero.get("name", "?")))
		return
	adv.erase("roomGone")
	if i >= dungeon.size():
		_finish_hero(pid, hero, int(adv["hp"]), {})
		return

	var room = BossEngine.active_room(dungeon[i])
	if room == null or bool((room as Dictionary).get("deactivated", false)):
		_advance_adventure_room()
		return

	if TnlAbilities.active(G):
		TnlAbilities.on_room_enter(G, pid, i, room as Dictionary) # Fairy Fountain (+1 PV), memoire d'entree (Inner Sanctum)
	if not adv.has("weakened") and TnlAbilities.hero_weakens(hero): # RMB115 Warlock, RMB119 Tax Collector : choix du proprietaire avant la premiere salle
		adv["weakened"] = true
		var wk = TnlAbilities.weaken_choice(G, pid, hero, i)
		if wk != null:
			adv["enterPending"] = i
			adv["weakenResume"] = true # la reprise doit encore jouer les declencheurs d'entree THK (Magnetic Ceiling, The Bomb)
			adv["roomGone"] = true # un affaiblissement a 0 PV tue le heros avant la salle : pas de salle de mort
			RoomAbilities.enqueue_pending(G, wk as Dictionary)
			return
	_enter_room_thk(pid, i, room as Dictionary)

## Declencheurs d'entree THK (Magnetic Ceiling, The Bomb) puis degats de la salle `i`.
func _enter_room_thk(pid: int, i: int, room: Dictionary) -> void:
	var adv: Dictionary = G.get("adventure", {})
	if ThkAbilities.active(G):
		var thk_enter := ThkAbilities.on_room_enter(G, pid, i, room)
		if thk_enter == "pending": # Magnetic Ceiling : le choix est ouvert, la salle est jouee a sa resolution (_thk_resume_enter)
			return
		if thk_enter == "bomb": # The Bomb : la derniere salle est detruite, aucun degat
			adv["pause"] = "post-damage"
			G["adventurePausePassed"] = {}
			return
	_room_damage(pid, i)

## Reprise de la salle `i` apres le choix de Magnetic Ceiling ou de Warlock / Tax Collector.
func _thk_resume_enter() -> void:
	var adv: Dictionary = G.get("adventure", {})
	if adv.is_empty() or not adv.has("enterPending"):
		return
	var i := int(adv["enterPending"])
	var pid := int(adv["playerId"])
	adv.erase("enterPending")
	if adv.erase("weakenResume"):
		if int(adv["hp"]) <= 0: # affaibli a 0 PV : il meurt avant d'entrer (roomGone reste pose, aucun degat de salle)
			adv["pause"] = "post-damage"
			G["adventurePausePassed"] = {}
			return
		adv.erase("roomGone")
		_enter_room_thk(pid, i, BossEngine.active_room((G["players"][pid]["dungeon"] as Array)[i]))
		return
	_room_damage(pid, i)

## Degats de la salle `i` au heros actif de `pid`, puis pause « apres les degats ».
func _room_damage(pid: int, i: int) -> void:
	var adv: Dictionary = G.get("adventure", {})
	var p: Dictionary = G["players"][pid]
	var hero: Dictionary = adv["hero"]
	var room = BossEngine.active_room((p.get("dungeon", []) as Array)[i])
	var dmg := BossEngine.room_damage_with_modifiers(G, p, i, hero)
	adv.erase("dealZero") # la salle suivante recoit le heros a 0 PV : il y meurt (HeroDiesInThisRoom)
	adv["hp"] = int(adv["hp"]) - dmg
	adv["thkDamage"] = int(adv.get("thkDamage", 0)) + dmg # Vorpal Blade : degats deja subis par le heros
	adv["pause"] = "post-damage"
	G["adventurePausePassed"] = {}
	# FirstTimeHeroEnterThisRoom (GameBoard.ProccessActiveHero : slot plus proche du boss que jamais, salle active) :
	# BMA017 Minotaur's Maze = MoveHeroToRelativeSlot(1), le heros recule d'une salle et la re-subit au pas suivant.
	if i > int(adv.get("nearest", -1)):
		adv["nearest"] = i
		if str((room as Dictionary).get("id", "")) == "BMA017" and not BossEngine.is_room_deactivated(G, pid, i) and not TnlAbilities.no_text(room as Dictionary) and int(adv["hp"]) > 0 and i > 0:
			adv["back"] = true
	_log("%s subit %d dégâts dans %s (PV restants : %d)." % [
		hero.get("name", "?"), dmg, (room as Dictionary).get("name", "?"), int(adv["hp"])
	])

func _check_adventure_pause_passed() -> void:
	var adv: Dictionary = G.get("adventure", {})
	if adv.is_empty() or adv.get("pause") == null:
		return
	if TnlAbilities.active(G):
		TnlAbilities.sync_hero(G) # Druid : PV a jour avant de juger la mort
	var pm: Dictionary = G.get("adventurePausePassed", {})
	for pid in G["players"]:
		var pl: Dictionary = G["players"][pid]
		if not pl.get("eliminated", false):
			if not bool(pm.get(str(pid), false)) and not bool(pm.get(int(pid), false)):
				return
	var pause_kind: String = str(adv["pause"])
	if pause_kind == "post-damage":
		if int(adv["hp"]) <= 0 and not bool(adv.get("dealZero", false)):
			var pid: int = int(adv["playerId"])
			var p: Dictionary = G["players"][pid]
			var idx: int = int(adv["roomIndex"])
			var death_room = BossEngine.active_room(p["dungeon"][idx]) if idx < (p["dungeon"] as Array).size() and not bool(adv.get("roomGone", false)) else {}
			_finish_hero(pid, adv["hero"], int(adv["hp"]), death_room if death_room != null else {})
		else:
			adv["pause"] = "pre-exit"
			G["adventurePausePassed"] = {}
	elif pause_kind == "pre-exit":
		adv["pause"] = null
		G["adventurePausePassed"] = {}

func _next_xp_active_player(current: int) -> int:
	var order: Array = G.get("xpOrder", [])
	if order.is_empty():
		order = CardDB.order_by_xp(G["players"])
	var idx := order.find(current)
	for i in range(1, order.size() + 1):
		var candidate: int = int(order[(idx + i) % order.size()])
		var pl: Dictionary = (G.get("players", {}) as Dictionary).get(candidate, {}) as Dictionary
		if not pl.is_empty() and not pl.get("eliminated", false) and not pl.get("passed", false) and not pl.get("hasActed", false):
			return candidate
	return -1

func _advance_adventure_player() -> void:
	G.erase("apkSkippedHero")
	var all_acted := true
	for pid in G["players"]:
		var pl: Dictionary = G["players"][pid]
		if not pl.get("eliminated", false):
			if not pl.get("passed", false) and not pl.get("hasActed", false):
				all_acted = false
				break

	# Une seule ronde (GameBoard.ChooseNextActivePlayer : ne regarde que les joueurs d'indice superieur, jamais en arriere) : un heros
	# ajoute a l'entree d'un joueur qui a deja passe (Zombie Prison) attend le tour suivant (s24-p4@277).
	if all_acted:
		_check_end_or_next_turn()
		return
	var nxt := _next_xp_active_player(active_player())
	if nxt >= 0:
		G["activePlayer"] = nxt

func _finish_hero(pid: int, hero: Dictionary, hp: int, death_room: Dictionary) -> void:
	var p: Dictionary = G["players"][pid]
	var entrance: Array = p.get("entrance", [])
	var at := entrance.find(hero)
	if at >= 0:
		entrance.remove_at(at)
	elif not entrance.is_empty():
		entrance.pop_front()

	BossEngine.spend_hero_health_bonus(G, hero) # BMA041 : le +3 ne survit pas a la fin de l'aventure du heros (Zombie Prison le ressuscite a PV de base)
	SpellEffects._effects(G)["teleportHero"] = null # Teleportation jouee sur un heros qui n'a pas avance depuis : sans objet
	var death_index: int = int(G.get("adventure", {}).get("roomIndex", -1))
	# KSA017 : le declencheur de mort (CheckTriggerInRoom -> CheckConditions) est evalue AVANT RemoveHeroFromGame, donc verrouille.
	var abilities_locked := BossEngine.abilities_locked(G, pid)
	# Fenetre de sorts apres la fin d'un heros (AdventurePhase_c -> _b, activeHero nul) : le heros suivant n'est pas encore designe.
	# Un sort joue ici (Trepidation) ne retire donc pas le prochain heros de l'entree (voir SpellEffects._trepidation).
	G["afterHero"] = true
	G["adventure"] = {}
	G["adventurePausePassed"] = {}

	var dead_item := ThkAbilities.item_id(hero) # IOD015 Blast Box : lu avant que l'Objet quitte le heros
	var returned := hp <= 0 and ThkAbilities.active(G) and ThkAbilities.extra_life(G, pid, hero) # THK001 Extra Life : le heros retourne en ville
	if returned:
		pass
	elif hp <= 0:
		var souls := BossEngine.hero_souls(hero)
		for s in souls:
			(p["souls"] as Array).append(CardDB.soul_entry(hero))
		_log("Âme capturée ! (%d/%d)" % [CardDB.total_souls(p, G), WIN_SOULS])
		if ThkAbilities.active(G): # l'Objet du heros tue : face visible chez le tueur (choix s'il a deja un Objet face visible)
			TnlAbilities.emit(G, ThkAbilities.claim_item(G, pid, ThkAbilities.detach(hero)))
		if TnlAbilities.active(G):
			TnlAbilities.on_hero_killed(G, pid) # TNL011 Angstigoth
		if Minibosses.active(G):
			RmbAbilities.on_hero_killed(G, pid) # RMB001 Gregore
		if not death_room.is_empty() and not abilities_locked:
			_hero_died_trigger(pid, death_room)
		if dead_item == "IOD015" and ThkAbilities.active(G) and not death_room.is_empty():
			IodAbilities.blast_death_room(G, pid, death_index) # Power-Up : la salle ou le heros est mort est detruite
	else:
		var wounds := BossEngine.hero_wounds(hero)
		for w in wounds:
			(p["wounds"] as Array).append({
				"name": hero.get("name", "?"),
				"wounds": 1,
				"souls": 1,
				"class": hero.get("class", ""),
				"faceDown": false,
				"turn": int(G.get("turn", 0)), # tour ou il a survecu (CRL029 Finish Him!)
					"hero": hero # identite du heros blesse (Vampire Bordello : FlipHero cible un heros)
			})
		if ThkAbilities.active(G):
			ThkAbilities.on_hero_survived(G, pid, hero) # THK : Vorpal Blade, Holy Hand Grenade, Antimagic Lizard, Necronomicon ; l'Objet va face cachee
		_log("Le héros survit et blesse le boss ! (%d blessures)" % CardDB.total_wounds(p))
		if CardDB.total_wounds(p) >= 5 and not ThkAbilities.wound_immune(G, pid) and not CardDB.big_game(G): # 5-6 joueurs : plus d'elimination (livret CRL)
			p["eliminated"] = true
			entrance.clear() # GameBoard.ChooseNextActiveHero : !IsAlive => EntranceQueue.Clear()
			_log("Joueur %d éliminé !" % pid)
		if TnlAbilities.active(G) and not bool(p.get("eliminated", false)):
			TnlAbilities.on_hero_survived(G, pid, hero) # TNL100 Necromancer

	if not returned and TnlAbilities.hero_cmd(hero) == TnlAbilities.PRINCE and not bool(p.get("eliminated", false)) and not TnlAbilities.text_ignored(G, pid):
		TnlAbilities.emit(G, TnlAbilities.prince_reward(G, pid)) # CRL017 The Prince : une fois devenu blessure ou ame, le proprietaire du donjon peut piocher
	if not returned:
		(G["decks"]["heroDiscard"] as Array).append(hero)
	G["lastHeroFight"] = {
		"pid": pid,
		"hero": hero,
		"initialHp": BossEngine.hero_hp(hero),
		"killed": (hp <= 0 and not returned),
		"deathIndex": death_index,
	}
	# Le joueur actif vient d'etre elimine : plus aucun coup possible pour lui, la main passe au suivant
	# (sinon l'adversaire qui a encore un heros a l'entree n'a jamais la main et la partie cale).
	if bool(p.get("eliminated", false)) and pid == active_player():
		p["passed"] = true
		_advance_adventure_player()

## Declencheur HeroDiesInThisRoom. Surchargeable : l'APK execute la transaction au NextStep suivant, apres l'ajout de l'ame (voir ApkMatch).
func _hero_died_trigger(pid: int, death_room: Dictionary) -> void:
	var choice = RoomAbilities.on_hero_died_in_room(G, pid, death_room)
	if choice != null:
		RoomAbilities.enqueue_pending(G, choice) # (file derriere un choix deja ouvert, ex. Lightning Bolt!)

func _check_end_or_next_turn() -> void:
	# Phase 5 : END (Fin de tour et conditions de victoire)
	G["phase"] = CardDB.PHASE["END"]

	if CardDB.big_game(G):
		_check_end_big_game()
		return

	# Vérification des éliminations (5 blessures)
	for pid in G["players"]:
		var p: Dictionary = G["players"][pid]
		if CardDB.total_wounds(p) >= 5 and not ThkAbilities.wound_immune(G, int(pid)): # THK001 Extra Life : aucune perte par Blessures ce tour
			p["eliminated"] = true

	# Joueurs ayant 10 âmes et moins de 5 blessures (règle GameBoard.cs:1041-1049)
	var winners_10_souls: Array = []
	for pid in G["players"]:
		var p: Dictionary = G["players"][pid]
		if CardDB.total_souls(p, G) >= WIN_SOULS and (CardDB.total_wounds(p) < 5 or ThkAbilities.wound_immune(G, int(pid))) and not (TnlAbilities.active(G) and TnlAbilities.cannot_win(G, int(pid))): # TNL062 Meddling Kids!
			winners_10_souls.append(int(pid))

	if not winners_10_souls.is_empty():
		var win_pid = _tie_break_players(winners_10_souls)
		G["gameOver"] = {"winner": win_pid, "reason": "10 âmes"}
		_log("Partie terminée : joueur %d gagne avec 10 âmes !" % win_pid)
		state_changed.emit()
		return

	# Vérification des survivants
	var alive_pids: Array = []
	for pid in G["players"]:
		if not (G["players"][pid] as Dictionary).get("eliminated", false):
			alive_pids.append(int(pid))

	if alive_pids.size() == 1:
		G["gameOver"] = {"winner": alive_pids[0], "reason": "dernier survivant"}
		_log("Partie terminée : joueur %d est le dernier survivant !" % alive_pids[0])
		state_changed.emit()
		return
	elif alive_pids.is_empty():
		# Tous éliminés le même tour : départage entre tous les joueurs
		var all_pids: Array = []
		for pid in G["players"]:
			all_pids.append(int(pid))
		var win_pid = _tie_break_players(all_pids)
		G["gameOver"] = {"winner": win_pid, "reason": "départage"}
		_log("Partie terminée : joueur %d gagne au départage !" % win_pid)
		state_changed.emit()
		return

	# Vérification épuisement des héros
	var decks: Dictionary = G["decks"]
	var no_more_heroes: bool = (decks.get("heroes", []) as Array).is_empty() and (decks.get("epics", []) as Array).is_empty() and (G.get("town", []) as Array).is_empty()
	# GameBoard.CheckEndOfGame (APK) ne connait pas la fin « heros epuises » (elle vient du livret) : inactive tant que seuls des paquets APK sont en jeu.
	var apk_only: bool = G.has("sets") # (un etat construit a la main, sans « sets » : regle historique)
	for s in G.get("sets", []):
		apk_only = apk_only and s in APK_SETS
	no_more_heroes = no_more_heroes and not apk_only
	# Crash Landing. SOURCE : docs/rules/rules.md (= rules_crash_landing.pdf), « Changes to Victory Conditions » : dans la partie a 5-6 joueurs, elle se termine
	# quand les pioches de heros ordinaires ET epiques sont epuisees, « Heroes can still be in Town when the game ends » : a 5-6 joueurs c'est
	# _check_end_big_game (sans garde). Ici, 2-4 joueurs avec CRL (le livret n'y prevoit que « Hero stack depleted [...] and any remaining Heroes can't be distributed anymore ») :
	# la regle est reprise MAIS seulement quand plus rien ne peut changer (aucun heros leurre ce tour ni a une entree), sinon un Explorer
	# que personne ne peut leurrer (aucun tresor Explorer, ou egalite) bloquerait la partie pour toujours. Sans Crash Landing : regle APK inchangee.
	if not no_more_heroes and G.get("sets", []).has("crash-landing") and (decks.get("heroes", []) as Array).is_empty() and (decks.get("epics", []) as Array).is_empty():
		var any_lured := false
		for v in (G.get("luredThisTurn", {}) as Dictionary).values():
			any_lured = any_lured or int(v) > 0
		var any_entrance := false
		for pid in G["players"]:
			any_entrance = any_entrance or not ((G["players"][pid] as Dictionary).get("entrance", []) as Array).is_empty()
		no_more_heroes = not any_lured and not any_entrance
	if no_more_heroes:
		var win_pid = _tie_break_players(alive_pids)
		G["gameOver"] = {"winner": win_pid, "reason": "héros épuisés"}
		_log("Partie terminée (héros épuisés) : joueur %d gagne !" % win_pid)
		state_changed.emit()
		return

	# Pas de fin de partie -> tour suivant (The Next Level : effets de fin de tour, dont des choix Shellda / Blockpile Puzzle qui retardent le tour suivant)
	var iod_end := ThkAbilities.active(G) and IodAbilities.end_of_turn(G) # IOD018 : les salles posees grace a Stolen Blueprints sont detruites
	if (TnlAbilities.active(G) and TnlAbilities.end_of_turn(G)) or iod_end:
		G["tnlEndPending"] = true
		state_changed.emit()
		return
	_start_turn()
	state_changed.emit()

## Fin de partie a 5-6 joueurs (livret CRL, « Changes to Victory Conditions » et « End of Game ») : pas d'elimination ; la partie s'arrete en fin de tour
## quand un joueur a au moins 10 ames OU quand les pioches de heros ordinaires et epiques sont toutes deux vides (des heros peuvent rester en ville ou a
## une entree) ; le gagnant est le meilleur total ames - blessures de TOUS les joueurs, a egalite l'XP la plus BASSE.
func _check_end_big_game() -> void:
	var all_pids: Array = []
	for pid in G["players"]:
		all_pids.append(int(pid))
	all_pids.sort()
	var souls_reached := false
	for pid in all_pids:
		souls_reached = souls_reached or CardDB.total_souls(G["players"][pid], G) >= WIN_SOULS
	var decks: Dictionary = G["decks"]
	var exhausted: bool = (decks.get("heroes", []) as Array).is_empty() and (decks.get("epics", []) as Array).is_empty()
	if souls_reached or exhausted:
		var win_pid := _tie_break_players(all_pids, true)
		var reason := "10 âmes" if souls_reached else "héros épuisés"
		G["gameOver"] = {"winner": win_pid, "reason": reason}
		_log("Partie terminée (%s) : joueur %d gagne !" % [reason, win_pid])
		state_changed.emit()
		return
	_start_turn()
	state_changed.emit()

## Departage APK (GameBoard.GetWinnerWhenThereAreVariousCandidates / GetLessExperiencePlayerToWin) : ecart ames-blessures le plus haut ;
## a egalite, PlayerId croissant, or PlayerId est attribue par XP DECROISSANTE (GameBoardExtensions) : le boss de plus HAUTE XP l'emporte.
## A XP egale, l'ordre des sieges (humains d'abord) tranche : `pids` arrive en ordre croissant et `>` est strict.
## `low_xp` (5-6 joueurs, livret CRL : « the Boss with the lowest XP wins ») : a egalite, l'XP la plus BASSE l'emporte ; jamais en 2-4 (APK).
func _tie_break_players(pids: Array, low_xp: bool = false) -> int:
	var best_pid := int(pids[0])
	var best_diff := -999
	var best_xp := 1 << 30 if low_xp else -1
	for pid in pids:
		var p: Dictionary = G["players"][pid]
		var diff := CardDB.total_souls(p, G) - CardDB.total_wounds(p)
		var xp := int((p.get("boss", {}) as Dictionary).get("xp", 0))
		if diff > best_diff or (diff == best_diff and (xp < best_xp if low_xp else xp > best_xp)):
			best_diff = diff
			best_xp = xp
			best_pid = int(pid)
	return best_pid
