class_name Match
extends Node
## Match — autorité locale solo (miroir de src/backend/game/reducer.js).
## Boucle : BOSS -> SETUP (salle initiale) -> BUILD -> BAIT -> ADVENTURE (pas-a-pas) -> END.
## shortcut: effets de sorts salles avançés non portés (fodder/discard uniquement), à porter depuis spellEffects.js / roomAbilities.js quand la boucle tourne.

signal state_changed

const BossEngine = preload("res://godot/scripts/BossEngine.gd")

const WIN_SOULS := 10

## Salles du base set ayant une abilite activable (roomAbilities.js:activateRoomAbility).
const ACTIVATABLE_ROOMS := ["BMA009", "BMA013", "BMA024", "BMA027", "BMA028",
	"BMA030", "BMA032", "BMA038"]

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
	# Un choix en attente gele la partie (miroir reducer.js: early return sur pendingChoice).
	var pc: Dictionary = G.get("pendingChoice", {})
	if not pc.is_empty():
		# Choix ouvert : la partie est gelee (miroir reducer.js: early return global).
		# Seul le joueur concerne peut agir, uniquement pour resoudre.
		if int(pc.get("playerId", -1)) != pid:
			return out
		var opts: Array = pc.get("options", []) as Array
		var n: int = opts.size()
		if n == 0:
			out.append({"type": "resolveChoice", "args": [-1]})
		else:
			for i in n:
				out.append({"type": "resolveChoice", "args": [i]})
			# Un choix facultatif propose en plus l'option "passer" (index -1).
			if bool(pc.get("optional", false)):
				out.append({"type": "resolveChoice", "args": [-1]})
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
			if int(p.get("buildsThisTurn", 0)) == 0 and BossEngine.can_build_room(p, G, pid):
				for i in (p.get("hand", []) as Array).size():
					var c: Dictionary = (p["hand"] as Array)[i]
					if c.get("isRoom", false):
						out.append({"type": "buildRoom", "args": [i]})
			# Sorts jouables en phase BUILD (miroir reducer.js:playSpell).
			if not SpellEffects._effects(G).get("buildBlocked", false):
				for i in (p.get("hand", []) as Array).size():
					var c: Dictionary = (p["hand"] as Array)[i]
					if not c.get("isSpell", false):
						continue
					for t in SpellTargeting.spell_targets_for(G, p, pid, str(c.get("id", ""))):
						out.append({"type": "playSpell", "args": [i, t]})
			# Abilites de salle activables (miroir reducer.js:activateRoom).
			for i in (p.get("dungeon", []) as Array).size():
				var room = BossEngine.active_room((p["dungeon"] as Array)[i])
				if room == null:
					continue
				var rd: Dictionary = room
				if ACTIVATABLE_ROOMS.has(str(rd.get("id", ""))) and not bool(rd.get("usedThisTurn", false)):
					out.append({"type": "activateRoom", "args": [i]})
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
		"resolveChoice":
			_resolve_choice(pid, int(move["args"][0]))
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
		"playSpell":
			var si := int(move["args"][0])
			var target: Dictionary = move["args"][1] if move["args"].size() > 1 and move["args"][1] != null else {}
			var spell: Dictionary = (p["hand"] as Array)[si]
			if SpellEffects.cast_spell(G, pid, spell, target):
				(p["hand"] as Array).remove_at(si)
				_log("Joueur %d joue %s." % [pid, spell.get("name", "?")])
				# Jouer un sort est une action de build : le joueur a fini son tour.
				p["buildsThisTurn"] = maxi(1, int(p.get("buildsThisTurn", 0)))
				_end_build_for(pid)
		"activateRoom":
			var ri := int(move["args"][0])
			var err = RoomAbilities.activate_room_ability(G, pid, ri, int(move["args"][1]) if move["args"].size() > 1 else -1)
			if err != null:
				_log(str(err))
				p["buildsThisTurn"] = maxi(1, int(p.get("buildsThisTurn", 0)))
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

## Resout le pendingChoice courant, puis reprend le flux (miroir de la resolution JS).
func _resolve_choice(pid: int, index: int) -> void:
	var pc: Dictionary = G.get("pendingChoice", {})
	if pc.is_empty():
		return
	var p: Dictionary = G["players"][pid]
	var opts: Array = pc.get("options", [])
	var kind := str(pc.get("type", ""))
	# -1 = passer / option facultative
	var valid := index >= -1 and (index < opts.size() or index == -1)
	if not valid:
		return
	match kind:
		"recover-card":
			if index >= 0:
				var got = RoomAbilities.take_discard_card(G, p, opts[index])
				if got != null:
					_log("%s : %s recupere." % [str(pc.get("bossName", "")), str((got as Dictionary).get("name", "?"))])
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
		"pick-hero":
			if index >= 0:
				var o: Dictionary = opts[index]
				var ti := int(o.get("townIndex", o.get("index", -1)))
				var town: Array = G.get("town", [])
				if ti >= 0 and ti < town.size():
					var hero: Dictionary = town[ti]
					town.remove_at(ti)
					var entrance: Array = p.get("entrance", []) as Array
					entrance.append(hero)
					p["entrance"] = entrance
		"pick-opponent", "discard-spell-opponent":
			pass
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
				var o: Dictionary = opts[index]
				var decks: Dictionary = G.get("decks", {})
				var pile: Array = decks.get("rooms", [])
				var pile_idx := int(o.get("pileIndex", -1))
				var from_discard := str(o.get("pile", "")) == "discard"
				if from_discard:
					pile = decks.get("roomDiscard", [])
				decks["rooms" if not from_discard else "roomDiscard"] = pile
				if pile_idx >= 0 and pile_idx < pile.size() and RoomAbilities.pile_index_matches(pile, o):
					var card: Dictionary = pile[pile_idx]
					pile.remove_at(pile_idx)
					var hand: Array = p.get("hand", [])
					p["hand"] = hand
					hand.append(card)
					_log("%s : %s recherche." % [str(pc.get("bossName", "")), str(card.get("name", "?"))])
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
						var destroyed: Dictionary = BossEngine.destroy_room(tp, ri)
						_log("%s : %s detruit par le joueur %d." % [str(pc.get("bossName", "")), str(destroyed.get("name", "?")), target])
				# Adversaires suivants dans la file (Robobo)
				var rq: Array = G.get("roboboQueue", [])
				if not rq.is_empty():
					var next_pid := int(rq.pop_front())
					G["roboboQueue"] = rq
					var nxt: Variant = RoomAbilities.robobo_choice(G, next_pid)
					if nxt != null and not (nxt as Dictionary).is_empty():
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
						souls.append({"souls": 1, "name": hero.get("name", "?"), "faceDown": true})
					_log("%s : %s detruit en ville." % [str(pc.get("bossName", "")), str(hero.get("name", "?"))])
		"swap-rooms":
			if index >= 0 and index < opts.size():
				_swap_rooms(p, (opts[index] as Dictionary))
	G["pendingChoice"] = {}
	# Reprend la file de choix en attente, sinon on repart d'un etat propre.
	var queue: Array = G.get("choiceQueue", [])
	if not queue.is_empty():
		G["pendingChoice"] = queue.pop_front()
	state_changed.emit()
	# Le choix venait de suspendre la phase BUILD : il faut la reprendre, sinon
	# personne ne construit plus et la partie se fige (reducer.js rejoue la phase).
	if G.get("pendingChoice", {}) == {} and G.get("phase", "") == CardDB.PHASE["BUILD"]:
		_end_build_for(pid)

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
	# Attend que chaque joueur ait construit (si possible) ou passe.
	# Ne depend pas de can_build_room : un joueur dont le donjon est plein doit
	# pouvoir passer, sinon la phase build ne se termine jamais.
	for pid in G["players"]:
		var p: Dictionary = G["players"][pid]
		if p.get("eliminated", false) or p.get("isAI", false):
			continue
		if int(p.get("buildsThisTurn", 0)) == 0:
			return # attend le choix humain

	# Les IA construisent ou passent
	for pid in G["players"]:
		var p: Dictionary = G["players"][pid]
		if p.get("eliminated", false) or not p.get("isAI", false):
			continue
		if int(p.get("buildsThisTurn", 0)) == 0:
			if BossEngine.can_build_room(p, G, int(pid)):
				_ai_build(int(pid))
			else:
				p["buildsThisTurn"] = 1 # rien a construire : passe

	# Reveal des salles face-down puis level-up (reducer.js:endPhaseBuild)
	if _reveal_and_level_up():
		return

	# Phase 3 : BAIT (Leurre)
	G["phase"] = CardDB.PHASE["BAIT"]
	_log("Tour %d — phase BAIT (Leurre)." % G["turn"])
	_resolve_bait()

	# Phase 4 : ADVENTURE (Aventure)
	G["phase"] = CardDB.PHASE["ADVENTURE"]
	_log("Phase ADVENTURE : les héros avancent.")
	if not _any_heroes_in_dungeons():
		_check_end_or_next_turn()

## Fin de phase BUILD : revele les salles face-down puis declenche le level-up
## (reducer.js:endPhaseBuild). Renvoie true si un choix est en attente.
func _reveal_and_level_up() -> bool:
	for pid in CardDB.order_by_xp(G["players"]):
		var p: Dictionary = G["players"][pid]
		if p.get("eliminated", false):
			continue
		for stack in (p.get("dungeon", []) as Array):
			var room = BossEngine.active_room(stack)
			if room == null or not (room as Dictionary).get("faceDown", false):
				continue
			var r: Dictionary = room
			r["faceDown"] = false
			_log("Salle révélée : %s pour le joueur %s" % [str(r.get("name", "?")), str(pid)])
			var choice = RoomAbilities.on_build_room(G, int(pid), r)
			if choice != null:
				G["pendingChoice"] = choice
				return true
		if BossEngine.count_visible_rooms(p["dungeon"]) >= 5 and not p.get("leveledUp", false):
			p["leveledUp"] = true
			_log("Joueur %s EST MONTÉ EN NIVEAU !" % str(pid))
			var choice = RoomAbilities.process_level_up(G, int(pid))
			if choice != null:
				G["pendingChoice"] = choice
				return true
	return false

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
	var dungeon: Array = p.get("dungeon", [])
	var death_room: Dictionary = {}
	var death_index := -1
	for i in dungeon.size():
		if hp <= 0:
			break
		var room = BossEngine.active_room((dungeon as Array)[i])
		if room == null:
			continue
		hp -= BossEngine.room_damage_with_modifiers(G, p, i, hero)
		death_room = room as Dictionary
		death_index = i
	if hp <= 0:
		(p["souls"] as Array).append({"name": hero.get("name", "?"), "souls": BossEngine.hero_souls(hero)})
		_log("Âme capturée ! (%d/%d)" % [CardDB.total_souls(p), WIN_SOULS])
		# Ability "hero dies in this room" (roomAbilities.js:onHeroDiedInRoom).
		if not death_room.is_empty():
			var choice = RoomAbilities.on_hero_died_in_room(G, pid, death_room)
			if choice != null:
				G["pendingChoice"] = choice
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

## Departage officiel (engine.js:checkEndGame) : ecart ames-blessures le plus haut ;
## a egalite, le boss de plus faible XP l'emporte.
func _tie_break_players(pids: Array) -> int:
	var best_pid := int(pids[0])
	var best_diff := -999
	var best_xp := 999999
	for pid in pids:
		var p: Dictionary = G["players"][pid]
		var diff := CardDB.total_souls(p) - CardDB.total_wounds(p)
		var xp := int((p.get("boss", {}) as Dictionary).get("xp", 0))
		if diff > best_diff or (diff == best_diff and xp < best_xp):
			best_diff = diff
			best_xp = xp
			best_pid = int(pid)
	return best_pid
