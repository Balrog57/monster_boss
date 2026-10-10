class_name Match
extends Node
## Match — autorité locale solo (miroir de src/backend/game/reducer.js).
## Boucle : BOSS -> SETUP (salle initiale) -> BUILD -> BAIT -> ADVENTURE (pas-a-pas) -> END.
## shortcut: effets de sorts salles avançés non portés (fodder/discard uniquement), à porter depuis spellEffects.js / roomAbilities.js quand la boucle tourne.

signal state_changed

const WIN_SOULS := 10

var G: Dictionary = {}
var human_count := 1
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	rng.randomize()

func new_match(num_players: int = 2, p_human_count: int = 1, p_sets: Array = ["base"]) -> Dictionary:
	human_count = p_human_count
	var n := clampi(num_players, 2, 4)
	var sets := {}
	for s in p_sets:
		sets[String(s)] = true
	if sets.is_empty():
		sets["base"] = true
	var in_sets := func(c): return (c as Dictionary).get("set", "base") in sets
	var bosses: Array = CardDB.bosses.filter(in_sets)
	var rooms: Array = CardDB.rooms.filter(in_sets)
	var spells: Array = CardDB.spells.filter(in_sets)
	var heroes: Array = CardDB.heroes.filter(func(c): return (c as Dictionary).get("set", "base") in sets and not (c as Dictionary).get("epic", false))
	var epics: Array = CardDB.heroes.filter(func(c): return (c as Dictionary).get("set", "base") in sets and (c as Dictionary).get("epic", false))
	var room_deck: Array = CardDB.shuffled(CardDB.expanded_deck(rooms).map(func(r): var d = (r as Dictionary).duplicate(); d["isRoom"] = true; return d))
	var spell_deck: Array = CardDB.shuffled(CardDB.expanded_deck(spells).map(func(s): var d = (s as Dictionary).duplicate(); d["isSpell"] = true; return d))
	var hero_deck: Array = CardDB.shuffled(CardDB.expanded_deck(heroes).map(func(h): var d = (h as Dictionary).duplicate(); d["souls"] = 1; d["wounds"] = 1; return d))
	var epic_deck: Array = CardDB.shuffled(CardDB.expanded_deck(epics).map(func(h): var d = (h as Dictionary).duplicate(); d["souls"] = 2; d["wounds"] = 2; return d))
	# Tailles officielles (base set) selon le nombre de joueurs.
	var counts: Dictionary = CardDB.HERO_COUNTS.get(n, {"ordinary": 13, "epic": 8})
	hero_deck = hero_deck.slice(0, int(counts.get("ordinary", 13)))
	epic_deck = epic_deck.slice(0, int(counts.get("epic", 8)))
	var picks: Array = CardDB.shuffled(bosses).slice(0, n + 2)
	var players := {}
	for i in n:
		players[i] = {
			"boss": null, "dungeon": [], "hand": [],
			"souls": [], "wounds": [], "eliminated": false,
			"leveledUp": false, "buildsThisTurn": 0,
			"isAI": i >= human_count,
			"entrance": [],
		}
	G = {
		"players": players, "bossPicks": picks, "numPlayers": n,
		"xpOrder": [], "decks": {"rooms": room_deck, "spells": spell_deck, "heroes": hero_deck, "epics": epic_deck, "roomDiscard": [], "spellDiscard": [], "heroDiscard": []},
		"town": [], "turn": 0, "phase": CardDB.PHASE["BOSS"], "gameOver": null, "log": [],
	}
	_log("Nouvelle partie : choisissez un boss.")
	state_changed.emit()
	return G

func _log(t: String) -> void:
	(G["log"] as Array).append(t)
	if (G["log"] as Array).size() > 60:
		(G["log"] as Array).pop_front()

func active_player() -> int:
	return int((G.get("xpOrder", []) as Array)[0]) if not (G.get("xpOrder", []) as Array).is_empty() else 0

# --- Coups légaux (miroir legalMoves) ---
func legal_moves(pid: int) -> Array:
	var out: Array = []
	if G.get("gameOver") != null:
		return out
	var players: Dictionary = G["players"]
	if not players.has(pid) or (players[pid] as Dictionary).get("eliminated", false):
		return out
	var p: Dictionary = players[pid]
	var phase: String = G["phase"]
	match phase:
		"boss":
			if p.get("boss") == null:
				for b in G["bossPicks"]:
					out.append({"type": "pickBoss", "args": [(b as Dictionary)["id"]]})
		"setup":
			if BossEngine.count_visible_rooms(p.get("dungeon", [])) == 0:
				for i in (p.get("hand", []) as Array).size():
					var c: Dictionary = (p["hand"] as Array)[i]
					if c.get("isRoom", false):
						out.append({"type": "buildInitialRoom", "args": [i]})
		"build":
			if int(p.get("buildsThisTurn", 0)) == 0 and BossEngine.can_build_room(p):
				for i in (p.get("hand", []) as Array).size():
					var c: Dictionary = (p["hand"] as Array)[i]
					if c.get("isRoom", false):
						out.append({"type": "buildRoom", "args": [i]})
			out.append({"type": "passBuild", "args": []})
		"adventure":
			out.append({"type": "adventureNext", "args": []})
	return out

# --- Application (miroir applyMove) ---
func apply_move(pid: int, move: Dictionary) -> bool:
	var legal := legal_moves(pid)
	var found := false
	for m in legal:
		if (m as Dictionary)["type"] == move["type"] and str((m as Dictionary)["args"]) == str(move.get("args", [])):
			found = true
			break
	if not found:
		return false
	var players: Dictionary = G["players"]
	var p: Dictionary = players[pid]
	match String(move["type"]):
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
		"buildInitialRoom", "buildRoom":
			var idx := int(move["args"][0])
			var card: Dictionary = (p["hand"] as Array).pop_at(idx)
			# Règle officielle APK & JS : nouvelle salle construite à l'entrée (index 0)
			(p["dungeon"] as Array).push_front([card])
			p["buildsThisTurn"] = int(p.get("buildsThisTurn", 0)) + 1
			_log("Joueur %d construit %s." % [pid, card.get("name", "?")])
			if String(move["type"]) == "buildInitialRoom" and _all_have_initial_room():
				_start_turn()
			elif String(move["type"]) == "buildRoom":
				_end_build_for(pid)
		"passBuild":
			_log("Joueur %d passe." % pid)
			_end_build_for(pid)
		"adventureNext":
			_resolve_next_hero()
	return true

func _all_have_boss() -> bool:
	for pid in G["players"]:
		if (G["players"][pid] as Dictionary).get("boss") == null:
			return false
	return true

func _deal_opening_hands() -> void:
	# Distribution officielle APK & règles : 5 salles + 2 sorts (7 cartes), puis défausse de 2 cartes pour 5 en main.
	for pid in G["players"]:
		var p: Dictionary = G["players"][pid]
		var drawn: Array = CardDB.draw_cards(G["decks"]["rooms"], 5) + CardDB.draw_cards(G["decks"]["spells"], 2)
		# Défausse automatique des 2 cartes les moins prioritaires (ou tri par type)
		drawn.sort_custom(func(a, b): return int(a.get("damage", 0)) > int(b.get("damage", 0)))
		var kept: Array = drawn.slice(0, 5)
		var discarded: Array = drawn.slice(5)
		for d in discarded:
			if (d as Dictionary).get("isSpell", false):
				(G["decks"]["spellDiscard"] as Array).append(d)
			else:
				(G["decks"]["roomDiscard"] as Array).append(d)
		p["hand"] = kept
	G["phase"] = CardDB.PHASE["SETUP"]
	G["xpOrder"] = CardDB.order_by_xp(G["players"])
	_log("Mains initiales distribuées (5). Construisez votre première salle.")

func _all_have_initial_room() -> bool:
	for pid in G["players"]:
		if BossEngine.count_visible_rooms((G["players"][pid] as Dictionary).get("dungeon", [])) == 0:
			return false
	return true

func _start_turn() -> void:
	G["turn"] = int(G.get("turn", 0)) + 1
	# Phase 1 : BEGINNING (Début de tour)
	G["phase"] = CardDB.PHASE["BEGINNING"]
	_log("Tour %d — phase BEGINNING." % G["turn"])

	# Arrivée des héros en ville : 1 héros par joueur actif (la ville se cumule d'un tour à l'autre)
	_reveal_heroes_in_town()

	# Chaque joueur non-éliminé pioche 1 carte Salle (en ordre d'XP)
	var order := CardDB.order_by_xp(G["players"])
	for pid in order:
		var p: Dictionary = G["players"][pid]
		if p.get("eliminated", false):
			continue
		p["buildsThisTurn"] = 0
		p["entrance"] = []
		CardDB.refill_from_discard(G["decks"]["rooms"], G["decks"]["roomDiscard"], rng)
		var drawn := CardDB.draw_cards(G["decks"]["rooms"], 1)
		if not drawn.is_empty():
			(p["hand"] as Array).append(drawn[0])

	# Phase 2 : Transition vers BUILD
	G["phase"] = CardDB.PHASE["BUILD"]
	_log("Tour %d — phase BUILD." % G["turn"])

func _reveal_heroes_in_town() -> void:
	var alive_count := 0
	for pid in G["players"]:
		if not (G["players"][pid] as Dictionary).get("eliminated", false):
			alive_count += 1
	var decks: Dictionary = G["decks"]
	for i in alive_count:
		CardDB.refill_from_discard(decks["heroes"], decks["heroDiscard"], rng)
		var drawn := CardDB.draw_cards(decks["heroes"], 1)
		if drawn.is_empty():
			CardDB.refill_from_discard(decks["epics"], decks["heroDiscard"], rng)
			drawn = CardDB.draw_cards(decks["epics"], 1)
		if not drawn.is_empty():
			(G["town"] as Array).append(drawn[0])
	_log("%d héros sont en ville." % (G["town"] as Array).size())

func _end_build_for(_pid: int) -> void:
	# Attend que tous les humains aient construit ou passé
	for pid in G["players"]:
		var p: Dictionary = G["players"][pid]
		if not p.get("eliminated", false) and int(p.get("buildsThisTurn", 0)) == 0 and BossEngine.can_build_room(p) and not p.get("isAI", false):
			return # attend le choix humain

	# Les IA construisent
	for pid in G["players"]:
		var p: Dictionary = G["players"][pid]
		if not p.get("eliminated", false) and p.get("isAI", false) and int(p.get("buildsThisTurn", 0)) == 0 and BossEngine.can_build_room(p):
			_ai_build(int(pid))

	# Phase 3 : BAIT (Leurre)
	G["phase"] = CardDB.PHASE["BAIT"]
	_log("Tour %d — phase BAIT (Leurre)." % G["turn"])
	_resolve_bait()

	# Phase 4 : ADVENTURE (Aventure)
	G["phase"] = CardDB.PHASE["ADVENTURE"]
	_log("Phase ADVENTURE : les héros avancent.")
	if not _any_heroes_in_dungeons():
		_check_end_or_next_turn()

func _ai_build(pid: int) -> void:
	var p: Dictionary = G["players"][pid]
	var best := -1
	var best_dmg := -1
	for i in (p["hand"] as Array).size():
		var c: Dictionary = (p["hand"] as Array)[i]
		if c.get("isRoom", false) and int(c.get("damage", 0)) > best_dmg:
			best_dmg = int(c.get("damage", 0))
			best = i
	if best >= 0:
		var card: Dictionary = (p["hand"] as Array).pop_at(best)
		(p["dungeon"] as Array).push_front([card]) # À l'entrée !
		_log("IA %d construit %s." % [pid, card.get("name", "?")])
	p["buildsThisTurn"] = 1

func _resolve_bait() -> void:
	var remaining_town: Array = []
	var town: Array = G.get("town", [])
	var order := _turn_order()
	for hero in town:
		var treasure := int((hero as Dictionary).get("treasure", 1))
		var target := BossEngine.lure_target(G["players"], order, treasure)
		if target >= 0:
			var target_player: Dictionary = G["players"][target]
			(target_player["entrance"] as Array).append(hero)
			_log("%s est attiré par le donjon du joueur %d !" % [(hero as Dictionary).get("name", "?"), target])
		else:
			# Règle officielle : en cas d'égalité, le héros reste en ville (ne va PAS à la défausse)
			remaining_town.append(hero)
			_log("%s reste en ville (égalité de trésors)." % (hero as Dictionary).get("name", "?"))
	G["town"] = remaining_town

func _any_heroes_in_dungeons() -> bool:
	for pid in G["players"]:
		var p: Dictionary = G["players"][pid]
		if not p.get("eliminated", false) and not (p.get("entrance", []) as Array).is_empty():
			return true
	return false

func _resolve_next_hero() -> void:
	var next_pid := -1
	var hero: Dictionary = {}
	for pid in _turn_order():
		var p: Dictionary = G["players"][pid]
		if not p.get("eliminated", false) and not (p.get("entrance", []) as Array).is_empty():
			next_pid = int(pid)
			hero = (p["entrance"] as Array).pop_front()
			break

	if next_pid < 0:
		_check_end_or_next_turn()
		return

	_fight_hero(next_pid, hero)
	if not _any_heroes_in_dungeons():
		_check_end_or_next_turn()

func _turn_order() -> Array:
	var o: Array = CardDB.order_by_xp(G["players"])
	var t := int(G.get("turn", 1))
	for i in t % max(1, o.size()):
		o.append(o.pop_front())
	return o

func _fight_hero(pid: int, hero: Dictionary) -> void:
	var p: Dictionary = G["players"][pid]
	var hp := BossEngine.hero_wounds(hero)
	_log("%s attaque le donjon du joueur %d (PV %d)." % [hero.get("name", "?"), pid, hp])
	# Le héros parcourt le donjon de l'entrée (index 0) vers le boss
	for stack in p.get("dungeon", []):
		if hp <= 0:
			break
		var room = BossEngine.active_room(stack)
		if room == null:
			continue
		hp -= int((room as Dictionary).get("damage", 0))
	if hp <= 0:
		(p["souls"] as Array).append({"name": hero.get("name", "?"), "souls": BossEngine.hero_souls(hero)})
		_log("Âme capturée ! (%d/%d)" % [CardDB.total_souls(p), WIN_SOULS])
	else:
		(p["wounds"] as Array).append({"name": hero.get("name", "?"), "wounds": 1})
		_log("Le héros survit et blesse le boss ! (%d blessures)" % CardDB.total_wounds(p))
		if CardDB.total_wounds(p) >= 5:
			p["eliminated"] = true
			_log("Joueur %d éliminé !" % pid)
	(G["decks"]["heroDiscard"] as Array).append(hero)

func _check_end_or_next_turn() -> void:
	# Phase 5 : END (Fin de tour et conditions de victoire)
	G["phase"] = CardDB.PHASE["END"]

	# Vérification des éliminations (5 blessures)
	for pid in G["players"]:
		var p: Dictionary = G["players"][pid]
		if CardDB.total_wounds(p) >= 5:
			p["eliminated"] = true

	# Joueurs ayant 10 âmes et moins de 5 blessures (règle GameBoard.cs:1041-1049)
	var winners_10_souls: Array = []
	for pid in G["players"]:
		var p: Dictionary = G["players"][pid]
		if CardDB.total_souls(p) >= WIN_SOULS and CardDB.total_wounds(p) < 5:
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
	if no_more_heroes:
		var win_pid = _tie_break_players(alive_pids)
		G["gameOver"] = {"winner": win_pid, "reason": "héros épuisés"}
		_log("Partie terminée (héros épuisés) : joueur %d gagne !" % win_pid)
		state_changed.emit()
		return

	# Pas de fin de partie -> tour suivant
	_start_turn()
	state_changed.emit()

func _tie_break_players(pids: Array) -> int:
	var best_pid := int(pids[0])
	var best_diff := -999
	var best_xp := -1
	for pid in pids:
		var p: Dictionary = G["players"][pid]
		var diff := CardDB.total_souls(p) - CardDB.total_wounds(p)
		var xp := int(p.get("boss", {}).get("xp", 0))
		if diff > best_diff or (diff == best_diff and xp > best_xp):
			best_diff = diff
			best_xp = xp
			best_pid = int(pid)
	return best_pid
