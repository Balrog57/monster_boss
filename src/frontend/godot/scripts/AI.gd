class_name AI
extends RefCounted
## Intelligence Artificielle authentique pour Boss Monster.
## Calibrée et transposée d'après le code C# décompilé de l'APK originale 2.2.6 :
## - StatisticAI.cs, RoomCalculator.cs, DungeonSlotCalculator.cs
## - DiscardCalculator.cs, DrawCalculator.cs, AbilityCalculator.cs

const BossEngine = preload("res://godot/scripts/BossEngine.gd")

## Decisions deterministes de construction / defausse / pioche : voir ApkAI.gd (FixedAI de l'oracle). Ici : l'aiguillage,
## les sorts, les capacites et les choix (TriggerCalculator / AbilityCalculator, etapes suivantes du portage).

## Selectionne les 2 cartes de main a defausser lors de la phase de setup (FixedAI.DiscardCards, DiscardCalculator.cs).
static func select_opening_discards(hand: Array, p: Dictionary, G: Dictionary) -> Array:
	if hand.size() <= 2:
		return [0, 1] if hand.size() == 2 else [0]
	return ApkAI.opening_discards(G, p, hand, 2)

## Observateur facultatif (tests/ai_census.gd) : appele avec (match_obj, pid, moves, coup choisi) a chaque decision. Aucun effet sur le jeu.
static var trace: Callable = Callable()

## Choisit le meilleur coup légal parmi les options offertes.
static func pick_move(match_obj, pid: int):
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
	var builds: Array = []
	var others: Array = []
	for m in moves:
		(builds if str((m as Dictionary).get("type", "")) == "buildRoom" else others).append(m)
	var best = null
	var best_score := 0.0
	for m in others:
		var s := score_move(match_obj, pid, m)
		if best == null or s > best_score:
			best_score = s
			best = m
	# AIPlayerInteraction.InternalDoPlayerActions : une capacite d'abord (UseAbility), PUIS la construction (BuildRoom) ; les deux ne se comparent jamais.
	if not builds.is_empty() and (best == null or str((best as Dictionary).get("type", "")) in ["passBuild", "pass", "adventureNext", "resolveNextHero"]):
		var plan := ApkAI.plan(match_obj.G, pid, builds)
		if int(plan["pick"]) >= 0:
			best = builds[int(plan["pick"])]
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
			return 1000.0 + _score_choice(G, p, pid, int(args[0]) if not args.is_empty() else -1)

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
			var target: Dictionary = args[1] if args.size() > 1 and args[1] != null else {}
			# Politique de l'IA pendant une Spell Battle (AbilityCalculator.CalculateAbilityAndTargetValue : si
			# IsSpellBattleActive, seuls BMA043 et BMA025 sont evalues). La regle, elle, autorise toute reponse legale.
			if not (G.get("stack", []) as Array).is_empty() and not ["BMA043", "RMB077"].has(str(spell.get("id", ""))): # RMB077 Short Circuit (wiki) : seconde reponse de l'IA
				return -50.0
			return _score_spell(spell, target, p, G, pid)

		"activateRoom":
			var room_idx := int(args[0]) if not args.is_empty() else -1
			if not (G.get("stack", []) as Array).is_empty():
				var sroom = BossEngine.active_room((p.get("dungeon", []) as Array)[room_idx]) if room_idx >= 0 and room_idx < (p.get("dungeon", []) as Array).size() else null
				if sroom == null or str((sroom as Dictionary).get("id", "")) != "BMA025":
					return -50.0 # meme politique : en Spell Battle l'IA n'active que All-Seeing Eye
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
	return 0.0

## Départage les options d'un pendingChoice (TriggerCalculator.cs : CheckBMA001/004/005/007/022).
## Les parties aléatoires du C# (Shuffle) deviennent "la première option" : le moteur reste déterministe.
static func _score_choice(G: Dictionary, p: Dictionary, pid: int, idx: int) -> float:
	var pc: Dictionary = G.get("pendingChoice", {})
	var opts: Array = pc.get("options", [])
	if idx < 0 or idx >= opts.size():
		return -1.0 # "passer" : dernier recours
	var o: Dictionary = opts[idx]
	var card: Dictionary = o.get("card", {}) as Dictionary
	var turn := int(G.get("turn", 0))
	var phase_str := "early" if turn <= 1 else ("mid" if turn <= 4 else "late")
	match str(pc.get("type", "")):
		"discard-spell": # SelectSpellToDiscard : BMA048/BMA049 d'abord
			return 100.0 if str(card.get("id", "")) in ["BMA048", "BMA049"] else 0.0
		"pick-opponent": # CheckBMA012 (Succubus Spa) : l'adversaire au meilleur score (ames - blessures) qui a des cartes, puis le plus de sorts
			if str(pc.get("action", "")) != "steal-random":
				return 0.0
			var vic: Dictionary = (G.get("players", {}) as Dictionary).get(int(o.get("targetPlayerId", -1)), {}) as Dictionary
			if (vic.get("hand", []) as Array).is_empty():
				return 0.0
			return 1000.0 + float(CardDB.total_souls(vic, G) - CardDB.total_wounds(vic)) * 10.0 + float(_spells_in_hand(vic))
		"steal-card": # CheckBMA001 : un sort de l'adversaire au meilleur score, sinon sa meilleure salle
			var opp: Dictionary = (G.get("players", {}) as Dictionary).get(int(o.get("fromPid", -1)), {}) as Dictionary
			var opp_rank := float(CardDB.total_souls(opp, G)) * 10.0 + float(_spells_in_hand(opp))
			if bool(card.get("isSpell", false)):
				return 100000.0 + opp_rank
			return opp_rank + _calculate_room_value(card, p, G, phase_str) / 1000.0
		"draw-type": # DrawCalculator.CalculateDeckDrawValue : P(pioche salle) ; pick_move tire au sort (rng <= p), ici la probabilite
			var p_room := ApkAI.draw_room_probability(G, p, pid)
			return p_room if str(o.get("pile", "")) == "rooms" else 1.0 - p_room
		"heal-wound": # CheckBMA014 : on retourne le heros qui rapporte le plus d'ames
			return float(BossEngine.hero_souls(card))
		"destroy-room": # CheckBMA004 : salle avancée d'abord, la moins précieuse
			var tp: Dictionary = (G.get("players", {}) as Dictionary).get(int(o.get("targetPlayerId", pid)), {}) as Dictionary
			return (1000.0 if bool(card.get("advanced", false)) else 0.0) - _calculate_room_value(card, tp, G, phase_str)
		"search-advanced": # CheckBMA003/007 : salle constructible (trésor commun), la plus précieuse
			var fits := false
			for stack in (p.get("dungeon", []) as Array):
				var r = BossEngine.active_room(stack)
				if r == null:
					continue
				for t in card.get("treasures", []):
					if ((r as Dictionary).get("treasures", []) as Array).has(t):
						fits = true
			return (1000.0 if fits else 0.0) + _calculate_room_value(card, p, G, phase_str)
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

static func _spells_in_hand(p: Dictionary) -> int:
	var n := 0
	for c in (p.get("hand", []) as Array):
		if bool((c as Dictionary).get("isSpell", false)):
			n += 1
	return n

## Valeur de base d'une salle (RoomCalculator.CalculateRoomValue), pour les choix de cartes de TriggerCalculator.
static func _calculate_room_value(room: Dictionary, _p: Dictionary, _G: Dictionary, phase_str: String) -> float:
	return ApkAI.base_value(room, phase_str)

## Scoring des sorts d'après AbilityCalculator.cs
static func _score_spell(spell: Dictionary, target: Dictionary, p: Dictionary, G: Dictionary, pid: int) -> float:
	var sid := str(spell.get("id", ""))
	if TnlSpells.TARGETS.has(sid):
		return TnlSpells.score_spell(G, p, pid, sid, target)
	if RmbSpells.TARGETS.has(sid):
		return RmbSpells.score_spell(G, p, pid, sid, target)
	match sid:
		"BMA043": # Counterspell : une cible = un sort adverse en attente (SpellCardJustPlayed)
			return 150.0 if target.has("stackId") else 0.0 # Contre-sort prioritaire !
		"BMA040", "BMA047": # Buff salle (+3 DMG)
			if not (p.get("entrance", []) as Array).is_empty() and target.get("roomIndex") != null:
				return 100.0
			return 10.0
		"BMA041", "BMA045": # Buff héros (+HP) sur donjon adverse
			# Si un adversaire tue de justesse un héros, le buff le blesse !
			for oid in G.get("players", {}):
				if int(oid) != pid:
					var op: Dictionary = G["players"][oid]
					if not (op.get("entrance", []) as Array).is_empty():
						return 120.0
			return 0.0
		"BMA042": # Détruit salle
			return 60.0 if target.get("roomIndex") != null else 10.0
		"BMA048": # Jeopardy
			return 80.0 if (p.get("hand", []) as Array).size() <= 2 else 10.0
		"BMA049": # Kobold Strike
			return 70.0
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
		"KSA013": # T.P.K. : AbilityCalculator.CheckKSA013 la joue toujours (valeur 1.0), sans condition
			return 90.0
		_:
			return 20.0

## Scoring d'activation de salle d'après AbilityCalculator.cs
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
		"BMA027": # Bottomless Pit
			return 95.0 if phase == "adventure" else -10.0
		"BMA028": # Monster Ballroom
			return 85.0 if phase == "adventure" else -10.0
		"BMA025": # All-Seeing Eye
			return 110.0 if not (G.get("stack", []) as Array).is_empty() else -10.0
		"BMA024": # Witch's Kitchen
			return 45.0 if phase == "build" else -10.0
		"BMA009": # Dark Altar
			return 25.0
		"CRL012": # The Omega 42 (hors APK) : rejouer un effet coute une salle avancee, a ne faire qu'avec une carte avancee dont on n'a pas l'usage
			var adv_n: int = (p.get("hand", []) as Array).filter(func(c): return bool((c as Dictionary).get("advanced", false))).size()
			return AiWiki.BUILD_FIRST if phase == "build" and adv_n >= 1 and (adv_n >= 2 or AiWiki.dead_advanced(G, p, _pid) >= 1) else -5.0
		"BMA039": # Zombie Prison : AbilityCalculator.CheckBMA039 ne joue jamais en Setup/Early
			return 20.0 if int(G.get("turn", 0)) > 1 else -10.0
		_:
			if rid.begins_with("TNL"):
				return TnlAbilities.score_activate(G, p, _pid, rid, room_idx)
			if rid.begins_with("RMB"):
				return RmbAbilities.score_activate(G, p, _pid, rid, room_idx)
			return 5.0
