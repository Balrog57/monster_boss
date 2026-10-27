class_name AI
extends RefCounted
## Intelligence Artificielle authentique pour Boss Monster.
## Calibrée et transposée d'après le code C# décompilé de l'APK originale 2.2.6 :
## - StatisticAI.cs, RoomCalculator.cs, DungeonSlotCalculator.cs
## - DiscardCalculator.cs, DrawCalculator.cs, AbilityCalculator.cs

const BossEngine = preload("res://godot/scripts/BossEngine.gd")

## Decisions de construction / defausse / pioche (FixedAI de l'oracle) et sorts / capacites de salle (AbilityCalculator, StatisticAI.SelectAbilityToUse) :
## voir ApkAI.gd, qui porte aussi les CIBLES des declencheurs et des commandes (TriggerCalculator, choix ouverts par le moteur). Ici : l'aiguillage et les cartes wiki (AiWiki).

## Selectionne les 2 cartes de main a defausser lors de la phase de setup (FixedAI.DiscardCards, DiscardCalculator.cs).
static func select_opening_discards(hand: Array, p: Dictionary, G: Dictionary) -> Array:
	if hand.size() <= 2:
		return [0, 1] if hand.size() == 2 else [0]
	return ApkAI.opening_discards(G, p, hand, 2)

## Observateur facultatif (tests/ai_census.gd) : appele avec (match_obj, pid, moves, coup choisi) a chaque decision. Aucun effet sur le jeu.
static var trace: Callable = Callable()

## Fenetre de decision deja utilisee : "<instance de partie>:<joueur>" -> cle de la derniere fenetre ou une capacite a ete tiree. L'IA de l'APK
## consulte ses capacites UNE fois par appel de DoPlayerActions (BuildPhase_a, fenetre d'aventure, repondant de Spell Battle), pas en boucle.
static var _used: Dictionary = {}

## `AIPlayerInteraction.abilitySelected` : la capacite que l'IA a tiree en dernier (entree de ApkAI.abilities, cibles preregles), par partie et par joueur. Les choix
## ouverts ensuite par cette capacite (Dracolich Lair, Dark Altar...) lisent ces cibles (StatisticAI : GetSelectedTargets avant TriggerCalculator).
static var _sel: Dictionary = {}
## Construction choisie AVANT la capacite (AIPlayerInteraction.cs:86-101 : UseAbility() et BuildRoom() evaluees sur le meme etat), rejouee apres elle :
## "<partie>:<joueur>" -> {"win": fenetre, "card": salle, "slot": args du coup}.
static var _pre_build: Dictionary = {}
## Liste calculee au premier choix d'une carte a plusieurs choix (Xyzax), par partie et par joueur.
static var _memo: Dictionary = {}
## Mesure seulement : la derniere reponse a un choix venait-elle d'un tirage (`Shuffle()`) ?
static var last_choice_shuf := false

static func _key(match_obj, pid: int) -> String:
	return "%d:%d" % [match_obj.get_instance_id(), pid]

## abilitySelected = l'entree tiree, ou null ({}) quand l'IA n'a rien tire. Appele aussi par le harnais de parite (qui rejoue l'oracle au lieu de tirer).
static func remember(match_obj, pid: int, entry: Variant) -> void:
	_sel[_key(match_obj, pid)] = entry if entry is Dictionary else {}

static func _window_key(G: Dictionary) -> String:
	var adv: Dictionary = G.get("adventure", {}) as Dictionary
	var st: Array = G.get("stack", [])
	var hero_id := str((adv.get("hero", {}) as Dictionary).get("id", "")) if not adv.is_empty() else ""
	# BuildPhase_a : un appel d'UseAbility par NextStep et par IA (GamePlayBaseScene.cs:864-871) -> le joueur actif fait partie de la fenetre.
	var act := str(G.get("activePlayer", "-")) if str(G.get("phase", "")) == "build" else ""
	return "%d|%s|%s|%s|%s|%s|%s" % [int(G.get("turn", 0)), str(G.get("phase", "")), str(adv.get("roomIndex", "-")), hero_id,
		str((st[st.size() - 1] as Dictionary).get("id", "")) if not st.is_empty() else "", str(G.has("buildWindow")), act]

## Choisit le meilleur coup légal parmi les options offertes. `commit` = false : question de mesure, sans memoriser la fenetre de decision.
static func pick_move(match_obj, pid: int, commit := true):
	var moves: Array = match_obj.legal_moves(pid).filter(func(m): return str((m as Dictionary).get("type", "")) != "undoBuild") # reprise de pose : coup d'humain, l'IA n'en use jamais
	if moves.is_empty():
		return null
	var p: Dictionary = (match_obj.G["players"] as Dictionary)[pid]
	if str((moves[0] as Dictionary).get("type", "")) == "pickBoss": # APK : le boss de l'IA est tire au hasard, sans score
		var pick = moves[match_obj.rng.randi_range(0, moves.size() - 1)]
		if trace.is_valid():
			trace.call(match_obj, pid, moves, pick)
		return pick
	var pc: Dictionary = match_obj.G.get("pendingChoice", {})
	if str(pc.get("type", "")) == "draw-type" and int(pc.get("playerId", -1)) == pid: # StatisticAI.SelectWhereToDrawFrom : rng <= p -> pioche de salles
		var want := "rooms" if match_obj.rng.randf() <= ApkAI.draw_room_probability(match_obj.G, p, pid) else "spells"
		for m in moves:
			var oi := int((m as Dictionary).get("args", [-1])[0])
			var opts: Array = pc.get("options", [])
			if oi >= 0 and oi < opts.size() and (str((opts[oi] as Dictionary).get("pile", "")) == "rooms") == (want == "rooms"):
				if trace.is_valid():
					trace.call(match_obj, pid, moves, m)
				return m
	if str(pc.get("type", "")) != "" and str((moves[0] as Dictionary).get("type", "")) == "resolveChoice" and int(pc.get("playerId", -1)) == pid:
		var ch: Variant = ApkAI.choose(match_obj.G, pid, pc, match_obj.rng, _sel.get(_key(match_obj, pid), {}), _memo.get_or_add(_key(match_obj, pid), {}))
		if ch != null:
			for m in moves:
				if int((m as Dictionary)["args"][0]) == int((ch as Dictionary)["idx"]):
					last_choice_shuf = bool((ch as Dictionary)["shuf"])
					if trace.is_valid():
						trace.call(match_obj, pid, moves, m)
					return m
	# IA hors de son tour de construction (BuildPhase_a) : AIPlayerInteraction.cs:86-101 ne lui laisse que UseAbility (pas de BuildRoom), et pas du tout
	# en ExtraBuildPhase. Seule la capacite tiree par StatisticAI.SelectAbilityToUse est jouee ; les sorts hors APK (wiki) restent au joueur actif.
	var off_turn: bool = pc.is_empty() and str(match_obj.G.get("phase", "")) == "build" and not match_obj.G.has("buildWindow") and pid != match_obj.active_player()
	if off_turn and match_obj.G.has("forcedBuild"):
		return null
	var builds: Array = []
	var others: Array = []
	var apk_abilities := false
	for m in moves:
		if str((m as Dictionary).get("type", "")) == "buildRoom":
			builds.append(m)
		elif ApkAI.is_apk_ability_move(p, m):
			apk_abilities = true # sort / capacite d'une carte de l'APK : l'ensemble des capacites eligibles (ApkAI.abilities) les remplace
		else:
			others.append(m)
	var best = null
	var best_score := 0.0
	for m in (others if not off_turn else []):
		var s := score_move(match_obj, pid, m)
		if best == null or s > best_score:
			best_score = s
			best = m
	# StatisticAI.SelectAbilityToUse : tirage UNIFORME parmi les capacites eligibles (AbilityCalculator : toute carte sans CheckXXX n'est jamais jouee), une fois par fenetre.
	if apk_abilities:
		var wkey := "%d:%d" % [match_obj.get_instance_id(), pid]
		var win := _window_key(match_obj.G)
		if str(_used.get(wkey, "")) != win:
			var elig: Array = ApkAI.abilities(match_obj.G, pid, moves, match_obj.rng)
			if commit:
				remember(match_obj, pid, null)
			if commit and (off_turn or not elig.is_empty()):
				_used[wkey] = win # un seul UseAbility par pas ; hors tour, meme sans tirage (sinon la boucle d'IA le redemande a chaque coup)
			if not elig.is_empty():
				var drawn: Dictionary = elig[match_obj.rng.randi_range(0, elig.size() - 1)]
				if commit:
					remember(match_obj, pid, drawn)
				if drawn["move"] != null:
					best = drawn["move"]
					if commit and not off_turn and not builds.is_empty(): # la salle est choisie maintenant, sur l'etat d'avant la capacite
						var pre := int(ApkAI.plan(match_obj.G, pid, builds)["pick"])
						if pre >= 0:
							var pargs: Array = (builds[pre] as Dictionary)["args"]
							_pre_build[wkey] = {"win": win, "card": (p["hand"] as Array)[int(pargs[0])], "args": pargs.slice(1)}
	# AIPlayerInteraction.InternalDoPlayerActions : une capacite d'abord (UseAbility), PUIS la construction (BuildRoom) ; les deux ne se comparent jamais.
	if not builds.is_empty() and (best == null or str((best as Dictionary).get("type", "")) in ["passBuild", "pass", "adventureNext", "resolveNextHero"]):
		var plan := ApkAI.plan(match_obj.G, pid, builds)
		if int(plan["pick"]) >= 0:
			best = builds[int(plan["pick"])]
		var pre: Dictionary = _pre_build.get(_key(match_obj, pid), {}) as Dictionary
		if commit and not pre.is_empty():
			_pre_build.erase(_key(match_obj, pid))
			if str(pre["win"]) == _window_key(match_obj.G): # meme fenetre : la capacite jouee ne change pas le choix deja fait, tant que la salle est encore la
				for m in builds:
					var margs: Array = (m as Dictionary)["args"]
					if ApkAI._same((p["hand"] as Array)[int(margs[0])], pre["card"]) and margs.slice(1) == pre["args"]:
						best = m
						break
	if trace.is_valid():
		trace.call(match_obj, pid, moves, best)
	return best

## Évalue et note un coup légal (StatisticAI.cs, RoomCalculator.cs, AbilityCalculator.cs).
static func score_move(match_obj, pid: int, move: Dictionary) -> float:
	var G: Dictionary = match_obj.G
	var p: Dictionary = (G["players"] as Dictionary)[pid]
	var phase: String = str(G.get("phase", ""))
	var mtype := String(move.get("type", ""))
	var args: Array = move.get("args", [])

	match mtype:
		"resolveChoice", "resolveLevelUpChoice":
			# Résolution immédiate des choix obligatoires ; l'option est départagée par _score_choice.
			return 1000.0 + _score_choice(G, p, pid, int(args[0]) if not args.is_empty() else -1, _sel.get(_key(match_obj, pid), {}))

		"pickBoss":
			var bid := str(args[0]) if not args.is_empty() else ""
			for b in G.get("bossPicks", []):
				if str((b as Dictionary).get("id", "")) == bid:
					return float((b as Dictionary).get("xp", 0)) * 10.0
			return 1.0

		"openingDiscard":
			return 500.0

		"buildRoom":
			# Rang lexicographique (ApkAI.plan) : salle puis emplacement, comme FixedAI. pick_move, lui, applique la regle « rien si le max est 0 ».
			var hand_n := (p.get("hand", []) as Array).size()
			if args.is_empty() or int(args[0]) < 0 or int(args[0]) >= hand_n:
				return -100.0
			var all_builds: Array = match_obj.legal_moves(pid).filter(func(m): return str((m as Dictionary).get("type", "")) == "buildRoom")
			var at := all_builds.find(move)
			if at < 0:
				all_builds.append(move)
				at = all_builds.size() - 1
			return float((ApkAI.plan(G, pid, all_builds)["keys"] as Array)[at])

		"playSpell":
			var hand_idx := int(args[0]) if not args.is_empty() else -1
			var hand: Array = p.get("hand", [])
			if hand_idx < 0 or hand_idx >= hand.size():
				return 0.0
			var spell: Dictionary = hand[hand_idx]
			if not ApkAI.is_wiki_card(str(spell.get("id", ""))):
				return _score_apk_ability(match_obj, pid, move)
			var target: Dictionary = args[1] if args.size() > 1 and args[1] != null else {}
			# Politique de l'IA pendant une Spell Battle pour les cartes wiki : seul RMB077 Short Circuit repond (seconde reponse de l'IA).
			# La regle, elle, autorise toute reponse legale.
			if not (G.get("stack", []) as Array).is_empty() and str(spell.get("id", "")) != "RMB077":
				return -50.0
			return _score_spell(spell, target, p, G, pid)

		"activateRoom":
			var room_idx := int(args[0]) if not args.is_empty() else -1
			if ApkAI.is_apk_ability_move(p, move):
				return _score_apk_ability(match_obj, pid, move)
			if not (G.get("stack", []) as Array).is_empty():
				return -50.0 # Spell Battle : l'IA n'active que All-Seeing Eye (APK, ci-dessus) ; aucune capacite de salle wiki en reponse
			return _score_activate_room(room_idx, p, G, pid)

		"useHandRoom":
			# CRL007 Frostman Lander (hors APK, heuristique maison) : seulement contre la salle avancee d'un adversaire dont un heros est la.
			var tgt: Dictionary = args[1] if args.size() > 1 and args[1] is Dictionary else {}
			var opp: Dictionary = (G["players"] as Dictionary).get(int(tgt.get("targetPlayerId", pid)), {}) as Dictionary
			if int(tgt.get("targetPlayerId", pid)) != pid and phase == "adventure" and not (opp.get("entrance", []) as Array).is_empty():
				return 30.0
			return -50.0
		"passBuild":
			# Stalemate guard / check if building is actually safe or beneficial
			var can_build := false
			for c in p.get("hand", []):
				if (c as Dictionary).get("isRoom", false):
					can_build = true
					break
			if not can_build:
				return 0.0 # Rien à construire, passer est normal
			return -1.0 # Préfère construire si possible

		"adventureNext", "resolveNextHero":
			return 1.0

	if TnlAbilities.is_tnl_move(mtype): # The Next Level (heuristiques maison)
		return TnlAbilities.score_move(G, p, pid, mtype, args)
	if Minibosses.is_rmb_move(mtype): # Rise of the Minibosses (heuristiques maison)
		return Minibosses.score_move(G, p, pid, mtype, args)
	if mtype == "useItem": # Tools of Hero-Kind (heuristiques maison)
		return ThkAbilities.score_move(G, p, pid, mtype, args)
	return 0.0

## Note les options d'un pendingChoice. Les choix de l'APK (TriggerCalculator, cibles de capacites) viennent de ApkAI.choose (pick_move l'appelle directement avec le
## RNG de la partie ; ici un RNG fixe, pour comparer deux options sans tirer). Reste : les choix des cartes wiki (heuristiques maison).
static func _score_choice(G: Dictionary, p: Dictionary, pid: int, idx: int, sel: Dictionary = {}) -> float:
	var pc: Dictionary = G.get("pendingChoice", {})
	var opts: Array = pc.get("options", [])
	var scratch := RandomNumberGenerator.new()
	scratch.seed = 1
	var apk: Variant = ApkAI.choose(G, pid, pc, scratch, sel, {})
	if apk != null:
		return 100.0 if int((apk as Dictionary)["idx"]) == idx else 0.0
	if idx < 0 or idx >= opts.size():
		return -1.0 # "passer" : dernier recours
	var o: Dictionary = opts[idx]
	var card: Dictionary = o.get("card", {}) as Dictionary
	match str(pc.get("type", "")):
		"draw-type": # DrawCalculator.CalculateDeckDrawValue : P(pioche salle) ; pick_move tire au sort (rng <= p), ici la probabilite
			var p_room := ApkAI.draw_room_probability(G, p, pid)
			return p_room if str(o.get("pile", "")) == "rooms" else 1.0 - p_room
		"heal-wound": # CRL031 Healing Tank (hors APK) : on retourne le heros qui rapporte le plus d'ames
			return float(BossEngine.hero_souls(card))
		"omega-discard": # CRL012 The Omega 42 : l'avancee qui ne se construit nulle part d'abord, sinon la moins precieuse
			var hi := int(o.get("handIndex", -1))
			var fits := false
			for ti in (p.get("dungeon", []) as Array).size():
				fits = fits or BossEngine.can_build_room(p, G, pid, hi, ti)
			return (0.0 if fits else 50.0) - TnlAbilities._ai_value(card)
		"omega-refire": # CRL012 : l'effet de construction / decouverte qui rapporte le plus
			return AiWiki.refire_value(card)
		"tnl-pick": # The Next Level : chaque option porte son poids (`ai`) ; defausser / detruire = le moins precieux d'abord
			return float(o.get("ai", 0.0))
	return 0.0

## Scoring des sorts wiki (les sorts de l'APK passent par ApkAI.abilities : AbilityCalculator.cs).
static func _score_spell(spell: Dictionary, target: Dictionary, p: Dictionary, G: Dictionary, pid: int) -> float:
	var sid := str(spell.get("id", ""))
	if TnlSpells.TARGETS.has(sid):
		return TnlSpells.score_spell(G, p, pid, sid, target)
	if RmbSpells.TARGETS.has(sid):
		return RmbSpells.score_spell(G, p, pid, sid, target)
	match sid:
		"THK025": # Excavation (case wiki Tools of Hero-Kind, heuristique maison)
			return ThkAbilities.score_excavation(G, pid, target)
		"CRL029": # Finish Him! (hors APK : heuristique maison) : tuer un heros vaut mieux que reprendre un survivant
			return 100.0 if target.has("entranceIndex") else 60.0
		"CRL030": # Essence Transfer : donne des PV a un heros adverse (blesse l'adversaire)
			return 90.0
		"CRL031": # Healing Tank : conditions deja verifiees par le ciblage
			return 90.0
		"CRL032": # Meteorite : utile seulement sur sa propre salle quand des Explorers attendent en ville
			var wanted := false
			for h in (G.get("town", []) as Array):
				wanted = wanted or int((h as Dictionary).get("treasure", 0)) == 5
			# Avant de construire (ne coute pas la pose) si l'Explorer en plus fait venir un heros que mon donjon tue.
			var mr = SpellEffects.find_room(G, pid, int(target.get("roomIndex", -1))) if wanted and int(target.get("targetPlayerId", pid)) == pid else null
			if mr != null and AiWiki.extra_treasure_gain(G, pid, mr as Dictionary, 5) >= 1.0:
				return AiWiki.BUILD_FIRST
			return 25.0 if wanted and int(target.get("targetPlayerId", pid)) == pid else -20.0
		"CRL033": # Not Dead Yet
			return 100.0
		"KSA012": # Agent of Evil (case wiki, heuristique maison)
			return PcwAbilities.score_agent(G, pid, target)
		_:
			return 20.0

## Scoring d'activation des salles wiki (les salles de l'APK passent par ApkAI.abilities : AbilityCalculator.cs).
static func _score_activate_room(room_idx: int, p: Dictionary, G: Dictionary, _pid: int) -> float:
	var dungeon: Array = p.get("dungeon", [])
	if room_idx < 0 or room_idx >= dungeon.size():
		return -20.0
	var room = BossEngine.active_room(dungeon[room_idx])
	if room == null:
		return -20.0
	var rid := str((room as Dictionary).get("id", ""))
	var phase: String = str(G.get("phase", ""))
	match rid:
		"CRL012": # The Omega 42 (hors APK) : rejouer un effet coute une salle avancee, a ne faire qu'avec une carte avancee dont on n'a pas l'usage
			var adv_n: int = (p.get("hand", []) as Array).filter(func(c): return bool((c as Dictionary).get("advanced", false))).size()
			return AiWiki.BUILD_FIRST if phase == "build" and adv_n >= 1 and (adv_n >= 2 or AiWiki.dead_advanced(G, p, _pid) >= 1) else -5.0
		_:
			if rid.begins_with("TNL"):
				return TnlAbilities.score_activate(G, p, _pid, rid, room_idx)
			if rid.begins_with("RMB"):
				return RmbAbilities.score_activate(G, p, _pid, rid, room_idx)
			if rid.begins_with("THK"):
				return ThkAbilities.score_activate(G, p, _pid, rid)
			return 5.0

## Sort / capacite d'une carte de l'APK : 20 si sa carte est dans l'ensemble des capacites eligibles (ApkAI.abilities), -50 sinon. Le choix, lui, est un tirage
## uniforme dans pick_move ; ce score ne sert qu'aux appelants qui refusent un coup « nocif » (< 0).
static func _score_apk_ability(match_obj, pid: int, move: Dictionary) -> float:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var a: Array = move.get("args", [])
	var kind := "spell" if str(move.get("type", "")) == "playSpell" else "room"
	for o in ApkAI.abilities(match_obj.G, pid, match_obj.legal_moves(pid), rng):
		if str((o as Dictionary)["kind"]) == kind and int((o as Dictionary)["idx"]) == int(a[0]):
			return 20.0
	return -50.0
