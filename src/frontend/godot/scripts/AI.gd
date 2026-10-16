class_name AI
extends RefCounted
## Intelligence Artificielle authentique pour Boss Monster.
## Calibrée et transposée d'après le code C# décompilé de l'APK originale 2.2.6 :
## - StatisticAI.cs, RoomCalculator.cs, DungeonSlotCalculator.cs
## - DiscardCalculator.cs, DrawCalculator.cs, AbilityCalculator.cs

const BossEngine = preload("res://godot/scripts/BossEngine.gd")

# Constantes de scoring APK RoomCalculator
const EARLY_DAMAGE_VALUE := [0.0, 25.0, 100.0, 150.0, 175.0, 200.0]
const MID_DAMAGE_VALUE := [0.0, 25.0, 75.0, 175.0, 200.0, 200.0]
const LATE_DAMAGE_VALUE := [0.0, 25.0, 75.0, 175.0, 200.0, 200.0]

const EARLY_TREASURE_VALUE := [100.0, 50.0, 0.0, 0.0, 0.0]
const MID_TREASURE_VALUE := [0.0, 25.0, 100.0, 100.0, 125.0, 200.0]
const LATE_TREASURE_VALUE := [100.0, 75.0, 75.0, 0.0, 0.0]

const BUILD_OVER_ADVANCED_PENALTY := 300.0
const INVALID_DIZZYGAS_SETUP := -1000.0
const INVALID_DIZZYGAS := -100.0
const VALID_DIZZYGAS := 100.0
const INVALID_GOBLIN_ARMORY := -100.0
const VALID_GOBLIN_ARMORY := 100.0
const EARLY_BAIT_MODIFIER := -100.0
const MID_BAIT_MODIFIER := -100.0

static func choose_boss(picks: Array):
	var best = null
	for b in picks:
		if best == null or int((b as Dictionary).get("xp", 0)) > int((best as Dictionary).get("xp", 0)):
			best = b
	return best

## Sélectionne les 2 cartes de main à défausser lors de la phase de setup (DiscardCalculator.cs).
static func select_opening_discards(hand: Array, p: Dictionary, G: Dictionary) -> Array:
	if hand.size() <= 2:
		return [0, 1] if hand.size() == 2 else [0]
	var scores: Array = []
	var best_room_val := 50.0
	for i in hand.size():
		var c: Dictionary = hand[i]
		if c.get("isRoom", false):
			var r_val := _calculate_room_value(c, p, G, "setup")
			if not BossEngine.can_build_room(p, G, int(p.get("pid", 0))) or bool(c.get("advanced", false)):
				r_val -= 100.0
			scores.append({"idx": i, "score": r_val})
			if r_val > best_room_val:
				best_room_val = r_val
		else:
			# Keep spell factor pour le setup = 0.4 * best_room_val (DiscardCalculator.cs)
			var s_val := best_room_val * 0.4
			scores.append({"idx": i, "score": s_val})
	
	# Tri par score croissant : défausse les 2 plus faibles
	scores.sort_custom(func(a, b): return a["score"] < b["score"])
	var res := [scores[0]["idx"], scores[1]["idx"]]
	res.sort()
	return res

## Choisit le meilleur coup légal parmi les options offertes.
static func pick_move(match_obj, pid: int):
	var moves: Array = match_obj.legal_moves(pid)
	if moves.is_empty():
		return null
	var p: Dictionary = (match_obj.G["players"] as Dictionary)[pid]
	var best = moves[0]
	var best_score := score_move(match_obj, pid, moves[0])
	for i in range(1, moves.size()):
		var s := score_move(match_obj, pid, moves[i])
		if s > best_score:
			best_score = s
			best = moves[i]
	return best

## Évalue et note un coup légal (StatisticAI.cs, RoomCalculator.cs, AbilityCalculator.cs).
static func score_move(match_obj, pid: int, move: Dictionary) -> float:
	var G: Dictionary = match_obj.G
	var p: Dictionary = (G["players"] as Dictionary)[pid]
	var phase: String = str(G.get("phase", ""))
	var turn: int = int(G.get("turn", 0))
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
			var hand_idx := int(args[0]) if not args.is_empty() else -1
			var hand: Array = p.get("hand", [])
			if hand_idx < 0 or hand_idx >= hand.size():
				return -100.0
			var room: Dictionary = hand[hand_idx]
			var slot_target := int(args[1]) if args.size() > 1 and args[1] != null else 0
			return _score_build_room(room, p, G, phase, turn, slot_target)

		"playSpell":
			var hand_idx := int(args[0]) if not args.is_empty() else -1
			var hand: Array = p.get("hand", [])
			if hand_idx < 0 or hand_idx >= hand.size():
				return 0.0
			var spell: Dictionary = hand[hand_idx]
			var target: Dictionary = args[1] if args.size() > 1 and args[1] != null else {}
			# Politique de l'IA pendant une Spell Battle (AbilityCalculator.CalculateAbilityAndTargetValue : si
			# IsSpellBattleActive, seuls BMA043 et BMA025 sont evalues). La regle, elle, autorise toute reponse legale.
			if not (G.get("stack", []) as Array).is_empty() and str(spell.get("id", "")) != "BMA043":
				return -50.0
			return _score_spell(spell, target, p, G, pid)

		"activateRoom":
			var room_idx := int(args[0]) if not args.is_empty() else -1
			if not (G.get("stack", []) as Array).is_empty():
				var sroom = BossEngine.active_room((p.get("dungeon", []) as Array)[room_idx]) if room_idx >= 0 and room_idx < (p.get("dungeon", []) as Array).size() else null
				if sroom == null or str((sroom as Dictionary).get("id", "")) != "BMA025":
					return -50.0 # meme politique : en Spell Battle l'IA n'active que All-Seeing Eye
			return _score_activate_room(room_idx, p, G, pid)

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
		"draw-type": # DrawCalculator.CalculateDeckDrawValue : P(pioche salle) ; l'IA C# tire au sort, ici on suit la probabilite
			var buildable := 0
			var hand: Array = p.get("hand", [])
			for hi in hand.size():
				if bool((hand[hi] as Dictionary).get("isRoom", false)) and BossEngine.can_build_room(p, G, pid, hi):
					buildable += 1
			var p_room := 1.0 if buildable == 0 else ((0.75 if buildable == 1 else (0.25 if turn <= 1 else 0.15)) if phase_str != "late" else 0.1)
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
	return 0.0

static func _spells_in_hand(p: Dictionary) -> int:
	var n := 0
	for c in (p.get("hand", []) as Array):
		if bool((c as Dictionary).get("isSpell", false)):
			n += 1
	return n

## Scoring d'une salle à construire d'après RoomCalculator.cs
static func _score_build_room(room: Dictionary, p: Dictionary, G: Dictionary, phase: String, turn: int, target_slot: int) -> float:
	var is_setup := (phase == "setup" or turn <= 0)
	var is_early := (turn <= 1)
	var is_mid := (turn > 1 and turn <= 4)
	var phase_str := "setup" if is_setup else ("early" if is_early else ("mid" if is_mid else "late"))

	var score := _calculate_room_value(room, p, G, phase_str)

	# 1. Pénalité de construction par-dessus (BuildOverPenalty)
	var dungeon: Array = p.get("dungeon", [])
	if target_slot < dungeon.size():
		var old_room = BossEngine.active_room(dungeon[target_slot])
		if old_room != null:
			var old_dict: Dictionary = old_room
			if bool(old_dict.get("advanced", false)):
				score -= BUILD_OVER_ADVANCED_PENALTY
			elif not bool(old_dict.get("advanced", false)) and bool(room.get("advanced", false)):
				score += 0.0 # Upgrade naturel : 0 pénalité
			else:
				score -= float(old_dict.get("damage", 0)) * 50.0

	# 2. Facteur de leurre de héros (BaitHeroFactor)
	if not is_setup:
		var bait_mod := EARLY_BAIT_MODIFIER if is_early else MID_BAIT_MODIFIER
		score += _bait_hero_factor(room, p, G, bait_mod)

	# 3. Synergies de cartes décompilées
	var card_id := str(room.get("id", ""))
	if card_id == "BMA029": # Dizzygas Hallway
		if dungeon.is_empty() or is_setup:
			score += INVALID_DIZZYGAS_SETUP
		else:
			var prev_room = BossEngine.active_room(dungeon[0])
			if prev_room != null and str((prev_room as Dictionary).get("type", "")) == "trap":
				score += VALID_DIZZYGAS
			else:
				score += INVALID_DIZZYGAS
	elif card_id == "BMA015": # Goblin Armory
		if not dungeon.is_empty():
			var prev_room = BossEngine.active_room(dungeon[0])
			if prev_room != null and str((prev_room as Dictionary).get("type", "")) == "monster":
				score += VALID_GOBLIN_ARMORY
			else:
				score += INVALID_GOBLIN_ARMORY
	elif card_id == "BMA034": # Construction Zone
		# Combo avec salle avancée en main
		for h in p.get("hand", []):
			if bool((h as Dictionary).get("advanced", false)):
				score += 100.0
				break

	# 4. Bonus d'atteinte de 5 salles (Level-Up rush)
	var cur_vis: int = BossEngine.count_visible_rooms(p.get("dungeon", []))
	if cur_vis + 1 >= 5 and not p.get("leveledUp", false):
		score += 250.0

	return maxf(0.0, score)

## Calcul de base valeur salle selon tables décompilées
static func _calculate_room_value(room: Dictionary, _p: Dictionary, _G: Dictionary, phase_str: String) -> float:
	var dmg: int = clampi(int(room.get("damage", 0)), 0, 5)
	var treasures: Array = room.get("treasures", [])
	var t_count: int = clampi(treasures.size(), 0, 4)

	var score := 0.0
	match phase_str:
		"setup", "early":
			score += EARLY_DAMAGE_VALUE[dmg]
			score += EARLY_TREASURE_VALUE[t_count]
		"mid":
			score += MID_DAMAGE_VALUE[dmg]
			score += MID_TREASURE_VALUE[t_count]
		"late":
			score += LATE_DAMAGE_VALUE[dmg]
			score += LATE_TREASURE_VALUE[t_count]

	if bool(room.get("advanced", false)):
		score += 30.0

	return score

## Vérifie si la salle va attirer un héros mortel ou au contraire un héros qu'on tue (BaitHeroFactor.cs)
static func _bait_hero_factor(room: Dictionary, p: Dictionary, G: Dictionary, bait_factor: float) -> float:
	var town: Array = G.get("town", [])
	if town.is_empty():
		return 0.0

	var factor := 0.0
	var room_treasures: Array = room.get("treasures", [])
	var dungeon_dmg := _get_total_dungeon_damage(p) + int(room.get("damage", 0))
	var p_wounds: int = CardDB.total_wounds(p)

	for h in town:
		var hero: Dictionary = h
		var h_treasures: Array = hero.get("treasures", [hero.get("treasure", 1)])
		var matches := false
		for t in room_treasures:
			if h_treasures.has(t) or h_treasures.has(int(t)):
				matches = true
				break
		if matches:
			var hp: int = BossEngine.hero_wounds(hero)
			if hp > dungeon_dmg:
				# Le héros survivrait et blesserait le boss : pénalité sévère
				factor += bait_factor * (float(p_wounds) + 1.0)
			else:
				# Le boss tue le héros et prend son âme : bonus
				factor += 50.0

	return factor

static func _get_total_dungeon_damage(p: Dictionary) -> int:
	var total := 0
	for stack in p.get("dungeon", []):
		var r = BossEngine.active_room(stack)
		if r != null:
			total += int((r as Dictionary).get("damage", 0))
	return total

## Scoring des sorts d'après AbilityCalculator.cs
static func _score_spell(spell: Dictionary, target: Dictionary, p: Dictionary, G: Dictionary, pid: int) -> float:
	var sid := str(spell.get("id", ""))
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
		"BMA024": # Dark Laboratory
			return 45.0 if phase == "build" else -10.0
		"BMA009": # Witch's Kitchen
			return 25.0
		"BMA039": # Zombie Prison : AbilityCalculator.CheckBMA039 ne joue jamais en Setup/Early
			return 20.0 if int(G.get("turn", 0)) > 1 else -10.0
		_:
			return 5.0
