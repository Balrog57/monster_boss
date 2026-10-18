extends RefCounted
## Goldens de l'extension Rise of the Minibosses (RMB, 121 cartes : 12 boss, 42 salles, 15 sorts, 42 heros, 10 minibosses). Hors APK.
## References, par priorite : docs/rules/rules.md (livret Minibosses, guide officieux : Minibosses / Coins / sequence de jeu), texte des cartes
## (cards.json, wiki).
## Appele par goldens.gd : `load("res://godot/tests/goldens_rmb.gd").new().run(_ok, self)`.

var _ok: Callable
var host: Node

func run(ok: Callable, h: Node) -> void:
	_ok = ok
	host = h
	_t_data()
	_t_new_match_decks()
	_t_setup_hands()
	_t_build_miniboss()
	_t_build_restrictions()
	_t_reveal_and_discard()
	_t_promote()
	_t_calabeza_promote()
	_t_attached_to_top_room()
	_t_destroyed_miniboss()
	_t_swap_and_deactivate()
	_t_level_one_passives()
	_t_level_two_triggers()
	_t_level_two_activations()
	_t_level_three_each()
	_t_activation_guards()
	_t_miniboss_hand_and_state()
	_t_boss_flags_and_klonos()
	_t_boss_coin_triggers()
	_t_boss_oculus_croak_scott()
	_t_boss_active_powers()
	_t_rooms_build_effects()
	_t_rooms_uncover_effects()
	_t_rooms_passive_damage()
	_t_rooms_destroy_for_coins()
	_t_rooms_hero_dependent()
	_t_rooms_discard_and_coin_costs()
	_t_rooms_triggers()
	_t_rooms_hand_abilities()
	_t_rooms_paywall_cavern_guardtower()
	_t_rooms_efreet_blackmarket()
	_t_stack_probe_identity()
	_t_spell_phases_and_targets()
	_t_spells_economy()
	_t_spells_rooms()
	_t_spells_heroes()
	_t_spells_stack_and_traitor()
	_t_heroes()
	_t_state_roundtrip()
	_t_ui_labels_and_menu()
	_t_ui_board()
	_t_ai_soak_rmb()
	_t_ai_soak_each_boss()
	_t_ai_soak_all_packs()

# --- fabriques d'etats minimaux ----------------------------------------------------------------------

func _card(arr: Array, id: String) -> Dictionary:
	for c in arr:
		if str((c as Dictionary).get("id", "")) == id:
			return (c as Dictionary).duplicate(true)
	push_error("carte introuvable " + id)
	return {}

func _room(id: String) -> Dictionary:
	var r := _card(CardDB.rooms, id)
	r["isRoom"] = true
	return r

func _spell(id: String) -> Dictionary:
	var s := _card(CardDB.spells, id)
	s["isSpell"] = true
	return s

## Carte miniboss de la main / de la pioche (isRoom + isMiniboss, comme Match._room_card).
func _minicard(id: String) -> Dictionary:
	var c := _card(CardDB.minibosses, id)
	c["isRoom"] = true
	c["isMiniboss"] = true
	return c

## Salle generique (id hors RMB : aucun declencheur) : id, type, tresors, degats.
func _plain(id: String, type: String = "monster", treasures: Array = [1], damage: int = 1, advanced: bool = false) -> Dictionary:
	return {"id": id, "name": id, "type": type, "advanced": advanced, "treasures": treasures, "damage": damage, "isRoom": true}

func _spl(id: String) -> Dictionary:
	return {"id": id, "name": id, "isSpell": true, "category": 3}

func _hero(id: String) -> Dictionary:
	var h := _card(CardDB.heroes, id)
	h["souls"] = 2 if bool(h.get("epic", false)) else 1
	h["wounds"] = h["souls"]
	return h

## Un miniboss attache a une salle : `lvl` niveau, `fd` face cachee, `since` tour de revelation.
func _with_mb(room: Dictionary, mid: String, lvl: int = 1, fd: bool = false, since: int = 0) -> Dictionary:
	room["mb"] = {"card": _minicard(mid), "level": lvl, "faceDown": fd, "since": since, "usedTurn": -1}
	return room

func _mbr(mid: String, lvl: int = 1, type: String = "monster", treasures: Array = [1], damage: int = 2) -> Dictionary:
	return _with_mb(_plain("H" + mid, type, treasures, damage), mid, lvl)

func _player(pid: int, boss_id: String, dungeon: Array = [], coins: int = 3) -> Dictionary:
	var stacks: Array = []
	for r in dungeon:
		stacks.append((r as Array) if r is Array else [r])
	return {"id": pid, "boss": _card(CardDB.bosses, boss_id), "dungeon": stacks, "hand": [], "souls": [], "wounds": [],
		"entrance": [], "eliminated": false, "leveledUp": false, "buildsThisTurn": 0, "coins": coins}

func _G(players: Array) -> Dictionary:
	var ps := {}
	for p in players:
		ps[int((p as Dictionary)["id"])] = p
	return {"players": ps, "town": [], "log": [], "logs": [], "adventure": {}, "turn": 3, "phase": "adventure", "sets": ["base", "minibosses"],
		"effects": SpellEffects.empty_effects(), "stack": [], "pendingChoice": {}, "choiceQueue": [],
		"decks": {"rooms": [], "spells": [], "heroes": [], "epics": [], "items": [], "roomDiscard": [], "spellDiscard": [], "heroDiscard": []}}

func _match(G: Dictionary) -> Node:
	var m = load("res://godot/scripts/Match.gd").new()
	host.add_child(m)
	m.G = G
	return m

func _build_phase(G: Dictionary, active: int = 0) -> void:
	G["phase"] = "build"
	G["activePlayer"] = active
	G["buildOrder"] = [0, 1]
	G["buildIndex"] = active

## Un heros actif dans le donjon de `pid`, dans la salle `idx`, avec `hp` PV.
func _adventure(G: Dictionary, pid: int, hero: Dictionary, idx: int, hp: int) -> void:
	var p: Dictionary = G["players"][pid]
	(p["entrance"] as Array).append(hero)
	G["adventure"] = {"playerId": pid, "hero": hero, "roomIndex": idx, "hp": hp, "pause": "post-damage"}
	G["phase"] = "adventure"
	G["activePlayer"] = pid

func _hand(G: Dictionary, pid: int) -> Array:
	return (G["players"][pid] as Dictionary)["hand"] as Array

func _coins(G: Dictionary, pid: int) -> int:
	return int((G["players"][pid] as Dictionary).get("coins", 0))

func _ids(arr: Array) -> Array:
	var out: Array = []
	for c in arr:
		out.append(str((c as Dictionary).get("id", "")))
	return out

func _decks(G: Dictionary, key: String) -> Array:
	return (G["decks"] as Dictionary)[key] as Array

func _types(moves: Array, t: String) -> Array:
	return moves.filter(func(mv): return str((mv as Dictionary)["type"]) == t)

## Resout les choix en attente avec l'option `idx` (0 par defaut) en passant par Match._resolve_choice (chemin reel).
func _drain(m: Node, idx: int = 0) -> int:
	var n := 0
	while not (m.G["pendingChoice"] as Dictionary).is_empty() and n < 30:
		var pc: Dictionary = m.G["pendingChoice"]
		var i := idx if idx < (pc.get("options", []) as Array).size() else 0
		m._resolve_choice(int(pc["playerId"]), i)
		n += 1
	return n

func _pending(G: Dictionary) -> Dictionary:
	return G["pendingChoice"] as Dictionary

func _fill(G: Dictionary, key: String, n: int, kind: String = "room") -> void:
	for i in n:
		(G["decks"][key] as Array).append(_plain("%s%d" % [key, i]) if kind == "room" else _spl("%s%d" % [key, i]))

func _act(G: Dictionary, pid: int, idx: int, other: int = -1) -> Variant:
	return RoomAbilities.activate_room_ability(G, pid, idx, other)

func _top(G: Dictionary, pid: int, idx: int) -> Dictionary:
	return BossEngine.active_room(((G["players"][pid] as Dictionary)["dungeon"] as Array)[idx])

func _count(arr: Array, prefix: String) -> int:
	var n := 0
	for c in arr:
		if str((c as Dictionary).get("id", "")).begins_with(prefix):
			n += 1
	return n

func _sum_q(arr: Array, prefix: String) -> int:
	var n := 0
	for c in arr:
		if str((c as Dictionary).get("id", "")).begins_with(prefix):
			n += int((c as Dictionary).get("quantity", 1))
	return n

func _int_list(a: Array) -> Array:
	var out: Array = []
	for x in a:
		out.append(int(x))
	return out

func _log_has(G: Dictionary, text: String) -> bool:
	for line in (G.get("logs", []) as Array):
		if str(line).contains(text):
			return true
	return false

# --- donnees + composition des paquets ---------------------------------------------------------------------

func _t_data() -> void:
	_ok.call(_count(CardDB.bosses, "RMB") == 12 and _count(CardDB.rooms, "RMB") == 42 and _count(CardDB.spells, "RMB") == 15 and _count(CardDB.heroes, "RMB") == 42 and CardDB.minibosses.size() == 10,
		"RMB : 12 boss, 42 salles, 15 sorts, 42 heros, 10 minibosses (121 cartes)")
	_ok.call(_sum_q(CardDB.rooms, "RMB") == 72 and _sum_q(CardDB.minibosses, "RMB") == 10 and _sum_q(CardDB.spells, "RMB") == 30 and _sum_q(CardDB.heroes, "RMB") == 42,
		"livret : pioche de salles de 82 cartes (72 salles + 10 minibosses), 30 sorts, 42 heros")
	var levels_ok := true
	for m in CardDB.minibosses:
		levels_ok = levels_ok and ((m as Dictionary)["levels"] as Array).size() == 3
	_ok.call(levels_ok, "chaque miniboss a trois niveaux")
	_ok.call(CardDB.can_play_spell(_spell("RMB066"), "build") and not CardDB.can_play_spell(_spell("RMB066"), "adventure"), "Internship (Build) : construction seulement")
	_ok.call(CardDB.can_play_spell(_spell("RMB070"), "adventure") and not CardDB.can_play_spell(_spell("RMB070"), "build"), "Ambush (Adventure) : aventure seulement")
	_ok.call(CardDB.can_play_spell(_spell("RMB065"), "build") and CardDB.can_play_spell(_spell("RMB065"), "adventure"), "Windfall (les deux phases)")
	_ok.call(not CardDB.can_play_spell(_spell("RMB077"), "build", 0) and CardDB.can_play_spell(_spell("RMB077"), "build", 1), "Short Circuit : un sort adverse doit attendre sur la pile")
	var gaps := 0
	for id in RmbSpells.TARGETS.keys():
		if _card(CardDB.spells, str(id)).is_empty():
			gaps += 1
	_ok.call(gaps == 0 and RmbSpells.TARGETS.size() == 15, "les 15 sorts RMB ont un ciblage")
	_ok.call(RmbAbilities.ACTIVATED.size() == 14 and RmbAbilities.HAND.size() == 3, "14 salles a capacite activee + 3 capacites de main")

func _t_new_match_decks() -> void:
	var m = load("res://godot/scripts/Match.gd").new()
	host.add_child(m)
	for n in [2, 3, 4]:
		var G: Dictionary = m.new_match(n, 1, ["minibosses"])
		var heroes: Array = G["decks"]["heroes"]
		var epics: Array = G["decks"]["epics"]
		var want_o: int = {2: 13, 3: 17, 4: 25}[n]
		var want_e: int = {2: 9, 3: 13, 4: 17}[n]
		_ok.call(heroes.size() == want_o and epics.size() == want_e, "%dj RMB : %d ordinaires + %d epiques (obtenu %d + %d)" % [n, want_o, want_e, heroes.size(), epics.size()])
		var all_rmb := true
		for h in heroes + epics:
			all_rmb = all_rmb and str((h as Dictionary).get("set", "")) == "minibosses"
		_ok.call(all_rmb, "%dj RMB : un seul paquet de heros (celui de RMB, pas le BMA)" % n)
		var ids: Array = _ids(heroes + epics)
		var stars := true
		for sid in ["RMB084", "RMB090", "RMB096", "RMB102", "RMB104", "RMB107", "RMB111", "RMB115", "RMB119"]:
			stars = stars and ids.has(sid)
		_ok.call(stars, "%dj RMB : les heros a etoile (noirs, hybrides, Fool) sont toujours inclus" % n)
		var rooms: Array = G["decks"]["rooms"]
		var minis := rooms.filter(func(c): return bool((c as Dictionary).get("isMiniboss", false)))
		_ok.call(bool(Minibosses.active(G)) and minis.size() == 10 and _count(rooms, "RMB") == 82 and _count(rooms, "BMA") > 0 and _count(G["decks"]["spells"], "RMB") == 30,
			"%dj RMB : 72 salles + 10 minibosses dans la pioche de salles, 30 sorts, melanges au jeu de base" % n)
		var coins_ok := true
		for pid in G["players"]:
			coins_ok = coins_ok and int((G["players"][pid] as Dictionary).get("coins", -1)) == 3
		_ok.call(coins_ok, "%dj RMB : chaque joueur commence avec 3 Coins" % n)
	var plain: Dictionary = m.new_match(2, 1, ["base"])
	var no_minis: bool = (plain["decks"]["rooms"] as Array).filter(func(c): return (c as Dictionary).has("isMiniboss")).is_empty()
	_ok.call(not Minibosses.active(plain) and no_minis and not (plain["players"][0] as Dictionary).has("coins") and (plain["decks"]["heroes"] as Array).size() == 13, "sans RMB : paquets de base inchanges, ni Coins ni miniboss")
	var both: Dictionary = m.new_match(2, 1, ["next-level", "minibosses"])
	var only_tnl := true
	for h in (both["decks"]["heroes"] as Array) + (both["decks"]["epics"] as Array):
		only_tnl = only_tnl and str((h as Dictionary).get("set", "")) == "next-level"
	_ok.call(only_tnl and _count(both["decks"]["rooms"], "RMB") == 82 and _count(both["decks"]["rooms"], "TNL") == 75, "TNL + RMB : un seul paquet de heros (TNL), salles des deux extensions")
	m.queue_free()

## Livret : 5 salles + 2 sorts sans defausse (main de 7), 3 Coins ; defausse amorcee par 4 salles + 2 sorts.
func _t_setup_hands() -> void:
	var m = load("res://godot/scripts/Match.gd").new()
	host.add_child(m)
	var G: Dictionary = m.new_match(2, 2, ["minibosses"])
	for pid in [0, 1]:
		var pick: Dictionary = (G["bossPicks"] as Array)[0]
		m.apply_move(pid, {"type": "pickBoss", "args": [pick["id"]]})
	_ok.call(_hand(G, 0).size() == 7 and _hand(G, 1).size() == 7 and _pending(G).is_empty(), "RMB : main de depart de 7 cartes, sans defausse d'ouverture")
	_ok.call(_decks(G, "roomDiscard").size() == 4 and _decks(G, "spellDiscard").size() == 2, "RMB : defausse amorcee par 4 salles + 2 sorts")
	_ok.call(_coins(G, 0) == 3 and _coins(G, 1) == 3, "RMB : 3 Coins au depart")
	m.queue_free()

# --- minibosses : pose, revelation, promotion -----------------------------------------------------------------------------

## Livret : « instead of your normal build, build a Miniboss face-down over any Room » ; il ne se pose PAS comme une salle.
func _t_build_miniboss() -> void:
	var host_room := _plain("A", "monster", [1], 2)
	var p0 := _player(0, "BMA001", [host_room])
	var p1 := _player(1, "BMA002")
	var G := _G([p0, p1])
	_build_phase(G)
	p0["hand"] = [_minicard("RMB055"), _plain("R")]
	var m := _match(G)
	var moves: Array = m.legal_moves(0)
	var builds := _types(moves, "buildMiniboss")
	_ok.call(builds.size() == 1 and str((builds[0] as Dictionary)["args"]) == "[0, 0]", "pose d'un miniboss : un coup par salle porteuse possible (obtenu %d)" % builds.size())
	var as_room := _types(moves, "buildRoom").filter(func(mv): return int((mv as Dictionary)["args"][0]) == 0)
	_ok.call(as_room.is_empty() and not BossEngine.can_build_room(p0, G, 0, 0, -1), "un miniboss ne se construit pas comme une salle")
	_ok.call(_types(m.legal_moves(1), "buildMiniboss").is_empty(), "pas de pose hors de son tour de construction")
	_ok.call(m.apply_move(0, {"type": "buildMiniboss", "args": [0, 0]}), "buildMiniboss applique")
	var mb: Dictionary = host_room["mb"]
	_ok.call(bool(mb["faceDown"]) and int(mb["level"]) == 1 and _hand(G, 0).size() == 1 and int(p0["buildsThisTurn"]) == 1, "le miniboss est pose face cachee au niveau 1 et consomme la construction")
	_ok.call(int(G["activePlayer"]) == 0 and m.apply_move(0, {"type": "passBuild", "args": []}), "le joueur garde la main jusqu'a DONE")
	_ok.call(int(G["activePlayer"]) == 1, "le tour de construction passe au joueur suivant")
	_ok.call(Minibosses.host_slots(G, 0).is_empty(), "une pile qui porte deja un miniboss ne peut plus en recevoir")

func _t_build_restrictions() -> void:
	var a := _with_mb(_plain("A"), "RMB055", 1)
	var p0 := _player(0, "BMA001", [a, _plain("B"), _plain("C"), _plain("D"), _plain("E")])
	var G := _G([p0, _player(1, "BMA002")])
	_build_phase(G)
	var slots: Array = Minibosses.host_slots(G, 0).map(func(o): return int((o as Dictionary)["roomIndex"]))
	_ok.call(slots == [2, 3, 4], "ni sur une salle qui porte un miniboss, ni a cote d'elle (obtenu %s)" % str(slots))
	(G["effects"]["deactivatedRooms"] as Array).append({"playerId": 0, "roomIndex": 2})
	_top(G, 0, 3)["faceDown"] = true
	slots = Minibosses.host_slots(G, 0).map(func(o): return int((o as Dictionary)["roomIndex"]))
	_ok.call(slots == [4], "ni sur une salle desactivee, ni sur une salle face cachee (obtenu %s)" % str(slots))
	p0["hand"] = [_minicard("RMB056")]
	var m := _match(G)
	_ok.call(not _types(m.legal_moves(0), "buildMiniboss").is_empty(), "controle : une pose reste possible")
	(G["effects"] as Dictionary)["buildBlocked"] = true
	_ok.call(_types(m.legal_moves(0), "buildMiniboss").is_empty(), "construction bloquee (Kobold Strike) : pas de miniboss non plus")
	(G["effects"] as Dictionary)["buildBlocked"] = false
	p0["buildsThisTurn"] = 1
	_ok.call(_types(m.legal_moves(0), "buildMiniboss").is_empty(), "une seule construction par tour")
	p0["buildsThisTurn"] = 0
	G["phase"] = "adventure"
	_ok.call(_types(m.legal_moves(0), "buildMiniboss").is_empty(), "pas de pose hors de la phase de construction")

## « Pay one Coin to reveal your Miniboss when Rooms are revealed » ; sans Coin il est defausse (livret : « discarded from play »).
func _t_reveal_and_discard() -> void:
	var room := _with_mb(_plain("A"), "RMB055", 1, true)
	var p0 := _player(0, "BMA001", [room], 3)
	var G := _G([p0, _player(1, "BMA002")])
	_build_phase(G)
	var m := _match(G)
	m._reveal_and_level_up()
	var mb: Dictionary = room["mb"]
	_ok.call(not bool(mb["faceDown"]) and _coins(G, 0) == 2 and int(mb["since"]) == 3, "revelation : 1 Coin paye, miniboss face visible, tour de revelation memorise")
	var room2 := _with_mb(_plain("B"), "RMB056", 1, true)
	var q0 := _player(0, "BMA001", [room2], 0)
	var G2 := _G([q0, _player(1, "BMA002")])
	_build_phase(G2)
	var m2 := _match(G2)
	m2._reveal_and_level_up()
	_ok.call(not room2.has("mb") and _decks(G2, "roomDiscard").size() == 1 and bool((_decks(G2, "roomDiscard")[0] as Dictionary).get("isMiniboss", false)) and _coins(G2, 0) == 0,
		"sans Coin : le miniboss est defausse (pile de defausse des salles), rien n'est paye")
	# King Croak (RMB005) : « Minibosses that you build start on Level 2 »
	var room3 := _plain("C")
	var k0 := _player(0, "BMA001", [room3], 3)
	k0["rmbBoss"] = {"RMB005": true}
	var G3 := _G([k0, _player(1, "BMA002")])
	_build_phase(G3)
	k0["hand"] = [_minicard("RMB057")]
	_match(G3).apply_move(0, {"type": "buildMiniboss", "args": [0, 0]})
	_ok.call(int((room3["mb"] as Dictionary)["level"]) == 2, "King Croak : les minibosses poses commencent au niveau 2")

## Promotion : 1 Coin, un miniboss par tour, jamais le tour de sa revelation, jamais au niveau 3.
func _t_promote() -> void:
	var room := _with_mb(_plain("A"), "RMB055", 1, false, 1)
	var p0 := _player(0, "BMA001", [room], 3)
	var G := _G([p0, _player(1, "BMA002")])
	_build_phase(G)
	var m := _match(G)
	var moves := _types(m.legal_moves(0), "promoteMiniboss")
	_ok.call(moves.size() == 1 and str((moves[0] as Dictionary)["args"]) == "[0, -1]", "promotion proposee (1 Coin) pour un miniboss revele un tour plus tot")
	_ok.call(m.apply_move(0, {"type": "promoteMiniboss", "args": [0, -1]}), "promoteMiniboss applique")
	_ok.call(int((room["mb"] as Dictionary)["level"]) == 2 and _coins(G, 0) == 2, "niveau 2, 1 Coin paye")
	_ok.call(_types(m.legal_moves(0), "promoteMiniboss").is_empty(), "une seule promotion par tour")
	G["effects"] = SpellEffects.empty_effects() # tour suivant
	G["turn"] = 4
	(room["mb"] as Dictionary)["since"] = 4
	_ok.call(_types(m.legal_moves(0), "promoteMiniboss").is_empty(), "un miniboss ne peut etre revele et promu le meme tour")
	(room["mb"] as Dictionary)["since"] = 3
	_ok.call(_types(m.legal_moves(0), "promoteMiniboss").size() == 1, "promotion de nouveau possible un tour apres")
	m.apply_move(0, {"type": "promoteMiniboss", "args": [0, -1]})
	G["effects"] = SpellEffects.empty_effects()
	_ok.call(int((room["mb"] as Dictionary)["level"]) == 3 and _types(m.legal_moves(0), "promoteMiniboss").is_empty(), "niveau 3 : pas de promotion de plus")
	(room["mb"] as Dictionary)["level"] = 1
	p0["coins"] = 0
	_ok.call(_types(m.legal_moves(0), "promoteMiniboss").is_empty(), "sans Coin : pas de promotion")
	p0["coins"] = 2
	(room["mb"] as Dictionary)["faceDown"] = true
	_ok.call(_types(m.legal_moves(0), "promoteMiniboss").is_empty(), "un miniboss face cache ne se promeut pas")
	(room["mb"] as Dictionary)["faceDown"] = false
	G["phase"] = "adventure"
	_ok.call(_types(m.legal_moves(0), "promoteMiniboss").is_empty(), "la promotion se fait pendant la construction seulement")
	_build_phase(G, 1)
	_ok.call(_types(m.legal_moves(0), "promoteMiniboss").is_empty(), "pas hors de son tour de construction")

## Calabeza (RMB002) : une fois par tour, une salle Monster defaussee remplace le Coin de la promotion.
func _t_calabeza_promote() -> void:
	var room := _with_mb(_plain("A"), "RMB058", 1, false, 1)
	var p0 := _player(0, "RMB002", [room], 0)
	p0["rmbBoss"] = {"RMB002": true}
	p0["hand"] = [_plain("M1", "monster"), _plain("T1", "trap"), _minicard("RMB056")]
	var G := _G([p0, _player(1, "BMA002")])
	_build_phase(G)
	var m := _match(G)
	var moves := _types(m.legal_moves(0), "promoteMiniboss")
	_ok.call(moves.size() == 1 and str((moves[0] as Dictionary)["args"]) == "[0, 0]", "Calabeza : seule une salle Monster (ni Trap ni miniboss) remplace le Coin")
	m.apply_move(0, {"type": "promoteMiniboss", "args": [0, 0]})
	_ok.call(int((room["mb"] as Dictionary)["level"]) == 2 and _hand(G, 0).size() == 2 and _decks(G, "roomDiscard").size() == 1 and _coins(G, 0) == 0, "Calabeza : niveau 2 sans payer de Coin")
	var p1 := _player(1, "BMA002", [_with_mb(_plain("B"), "RMB058", 1, false, 1)], 0)
	p1["hand"] = [_plain("M2", "monster")]
	var G2 := _G([_player(0, "BMA001"), p1])
	_build_phase(G2, 1)
	_ok.call(_types(_match(G2).legal_moves(1), "promoteMiniboss").is_empty(), "sans Calabeza : pas de promotion sans Coin")

# --- le miniboss suit la salle du sommet --------------------------------------------------------------------------------------------

## Guide officieux : « If a Room is built on top of one with a Miniboss, the Miniboss jumps underneath the Room that has just been built. »
func _t_attached_to_top_room() -> void:
	var a := _with_mb(_plain("A", "monster", [1, 2], 2), "RMB056", 1, false, 1) # Kid Croak : +1 Fighter
	var p0 := _player(0, "BMA001", [a], 3)
	var up := _plain("U", "trap", [1], 3, true)
	p0["hand"] = [up]
	var G := _G([p0, _player(1, "BMA002")])
	_build_phase(G)
	var m := _match(G)
	_ok.call(m.apply_move(0, {"type": "buildRoom", "args": [0, 0]}), "salle avancee posee face cachee par-dessus la salle au miniboss")
	_ok.call(a.has("mb") and not up.has("mb"), "tant que la nouvelle salle est face cachee, le miniboss reste en dessous")
	m._reveal_and_level_up()
	_ok.call(up.has("mb") and not a.has("mb"), "a la revelation, le miniboss saute sous la nouvelle salle du sommet")
	_ok.call(BossEngine.room_treasures(up).has(2) and BossEngine.room_damage_with_modifiers(G, p0, 0, null) == 3, "ses effets suivent (icone Fighter ; la salle du dessous ne compte plus)")
	# Rocky niveau 1 : « You may build any Room on top of this one, regardless of treasure icon »
	var r := _with_mb(_plain("R", "monster", [1], 2), "RMB058", 1)
	var q := _player(0, "BMA001", [r], 3)
	var adv_room := _plain("X", "trap", [4], 3, true)
	q["hand"] = [adv_room]
	var G2 := _G([q, _player(1, "BMA002")])
	_build_phase(G2)
	_ok.call(BossEngine.can_build_room(q, G2, 0, 0, 0), "Rocky : une salle avancee se construit par-dessus, sans icone commune")
	r.erase("mb")
	_ok.call(not BossEngine.can_build_room(q, G2, 0, 0, 0), "sans Rocky : l'icone commune est exigee")
	_with_mb(r, "RMB058", 1, true)
	_ok.call(not BossEngine.can_build_room(q, G2, 0, 0, 0), "Rocky face cachee : aucun effet")

func _t_destroyed_miniboss() -> void:
	var under := _plain("UNDER")
	var top := _with_mb(_plain("TOP"), "RMB055", 2)
	var p0 := _player(0, "BMA001", [[under, top]], 3)
	var G := _G([p0, _player(1, "BMA002")])
	var d = BossEngine.destroy_room(p0, 0, G)
	_ok.call(d != null and not (d as Dictionary).has("mb") and under.has("mb") and int((under["mb"] as Dictionary)["level"]) == 2, "salle detruite : le miniboss saute sur la salle decouverte (meme niveau)")
	var G2 := _G([_player(0, "BMA001", [_with_mb(_plain("ONLY"), "RMB057", 3)]), _player(1, "BMA002")])
	var p2: Dictionary = G2["players"][0]
	var d2 = BossEngine.destroy_room(p2, 0, G2)
	BossEngine.discard_room_to_pile(G2["decks"], d2)
	_ok.call((p2["dungeon"] as Array).is_empty() and _ids(_decks(G2, "roomDiscard")).has("RMB057") and not (d2 as Dictionary).has("mb"), "derniere salle de la pile detruite : le miniboss est defausse")
	var odd := _with_mb(_plain("ODD"), "RMB059", 1)
	odd["coins"] = 2
	BossEngine.discard_room_to_pile(G2["decks"], odd)
	_ok.call(not odd.has("mb") and not odd.has("coins") and _ids(_decks(G2, "roomDiscard")).has("RMB059"), "defausse directe : miniboss rendu a la defausse, Coins posees perdues")

func _t_swap_and_deactivate() -> void:
	var a := _with_mb(_plain("A", "monster", [1], 2), "RMB055", 1)
	var b := _plain("B", "monster", [2], 2)
	var p0 := _player(0, "BMA001", [a, b], 3)
	var G := _G([p0, _player(1, "BMA002")])
	TnlAbilities.swap_stacks(G, 0, 0, 1)
	_ok.call(_top(G, 0, 1).has("mb") and not _top(G, 0, 0).has("mb"), "echange de deux piles : le miniboss voyage avec sa salle")
	(G["effects"]["deactivatedRooms"] as Array).append({"playerId": 0, "roomIndex": 1})
	_ok.call(BossEngine.room_damage_with_modifiers(G, p0, 1, null) == 0, "salle desactivee : degats nuls, son miniboss aussi (+1 compris)")
	G["effects"]["deactivatedRooms"] = []
	_ok.call(BossEngine.room_damage_with_modifiers(G, p0, 1, null) == 3, "une fois reactivee : 2 + 1 de Spike")

# --- niveau 1 : toujours actifs ------------------------------------------------------------------------------------------------------

func _t_level_one_passives() -> void:
	var dmg_cases := {"RMB055": 3, "RMB061": 3, "RMB063": 3} # salle de 2 degats : +1
	for mid in dmg_cases.keys():
		var room := _with_mb(_plain("H", "monster", [1], 2), str(mid), 1)
		var p0 := _player(0, "BMA001", [room], 3)
		var G := _G([p0, _player(1, "BMA002")])
		_ok.call(BossEngine.room_damage_with_modifiers(G, p0, 0, null) == int(dmg_cases[mid]), "%s niveau 1 : la salle a +1" % mid)
		(room["mb"] as Dictionary)["faceDown"] = true
		_ok.call(BossEngine.room_damage_with_modifiers(G, p0, 0, null) == 2, "%s face cache : aucun bonus" % mid)
	var ms := _with_mb(_plain("H", "monster", [1, 3, 4], 2), "RMB062", 1)
	var pm := _player(0, "BMA001", [ms], 3)
	_ok.call(BossEngine.room_damage_with_modifiers(_G([pm, _player(1, "BMA002")]), pm, 0, null) == 5, "RMB062 Mageseeker niveau 1 : +1 par icone de tresor (3 icones)")
	var icons := {"RMB056": 2, "RMB057": 1, "RMB059": 3, "RMB060": 4}
	for mid in icons.keys():
		var room := _with_mb(_plain("H", "trap", [1] if int(icons[mid]) != 1 else [2], 1), str(mid), 1)
		var p0 := _player(0, "BMA001", [room], 3)
		p0["boss"]["treasures"] = []
		var G := _G([p0, _player(1, "BMA002")])
		var base_n := BossEngine.treasure_count(p0, int(icons[mid]), G)
		_ok.call(base_n == 1, "%s niveau 1 : une icone %s de plus (%d)" % [mid, CardDB.TREASURE_NAMES[int(icons[mid])], base_n])
	# Icicle Man niveau 1 : le texte des heros reste actif (KSA017 Trap Master verrouille toujours les capacites)
	var ic := _with_mb(_plain("H"), "RMB061", 1)
	var pi := _player(0, "BMA001", [ic], 3)
	var Gi := _G([pi, _player(1, "BMA002")])
	_adventure(Gi, 0, _hero("KSA017"), 0, 13)
	_ok.call(BossEngine.abilities_locked(Gi, 0), "Icicle Man niveau 1 : le heros garde son texte")
	# Jinx niveau 1 : une salle de plus au debut du BUILD, puis defausse d'une salle
	var jx := _with_mb(_plain("H"), "RMB064", 1)
	var pj := _player(0, "BMA001", [jx], 3)
	pj["hand"] = [_plain("K1"), _plain("K2")]
	var Gj := _G([pj, _player(1, "BMA002")])
	_fill(Gj, "rooms", 3)
	var choices := Minibosses.on_build_start(Gj)
	_ok.call(_hand(Gj, 0).size() == 3 and choices.size() == 1 and str((choices[0] as Dictionary)["step"]) == "rmb_cost", "Jinx niveau 1 : pioche une salle puis doit en defausser une")
	TnlAbilities.resolve_pick(Gj, 0, choices[0], 0)
	_ok.call(_hand(Gj, 0).size() == 2 and _decks(Gj, "roomDiscard").size() == 1, "Jinx : la salle defaussee part en defausse")

func _t_level_two_triggers() -> void:
	# Paddywhack : une fois par tour, un Coin de plus quand on en gagne
	var room := _with_mb(_plain("A"), "RMB060", 2)
	var p0 := _player(0, "BMA001", [room], 0)
	var G := _G([p0, _player(1, "BMA002")])
	Minibosses.gain_coin(G, 0, 1, "test")
	Minibosses.gain_coin(G, 0, 2, "test")
	_ok.call(_coins(G, 0) == 4, "Paddywhack niveau 2 : +1 Coin supplementaire, une seule fois par tour (1+1, puis 2 : total 4)")
	(room["mb"] as Dictionary)["faceDown"] = true
	var G1 := _G([_player(0, "BMA001", [room], 0), _player(1, "BMA002")])
	Minibosses.gain_coin(G1, 0, 1, "test")
	_ok.call(_coins(G1, 0) == 1, "Paddywhack face cache : pas de bonus")
	(room["mb"] as Dictionary)["faceDown"] = false
	(room["mb"] as Dictionary)["level"] = 1
	var G2 := _G([_player(0, "BMA001", [room], 0), _player(1, "BMA002")])
	Minibosses.gain_coin(G2, 0, 1, "test")
	_ok.call(_coins(G2, 0) == 1, "Paddywhack niveau 1 : pas de bonus (niveau 2 requis)")
	# Cerebella niveau 2 : sort pioche quand un heros meurt dans la salle
	var cr := _with_mb(_plain("A"), "RMB059", 2)
	var pc := _player(0, "BMA001", [cr, _plain("B")], 0)
	var Gc := _G([pc, _player(1, "BMA002")])
	_fill(Gc, "spells", 2, "spell")
	var hero := _hero("RMB080")
	_adventure(Gc, 0, hero, 0, 0)
	var mc := _match(Gc)
	mc._finish_hero(0, hero, 0, cr)
	_ok.call(_hand(Gc, 0).size() == 1 and bool((_hand(Gc, 0)[0] as Dictionary).get("isSpell", false)), "Cerebella niveau 2 : un sort est pioche quand un heros meurt dans la salle")
	(cr["mb"] as Dictionary)["level"] = 1
	var hero2 := _hero("RMB081")
	_adventure(Gc, 0, hero2, 0, 0)
	mc._finish_hero(0, hero2, 0, cr)
	_ok.call(_hand(Gc, 0).size() == 1, "Cerebella niveau 1 : rien")
	# Rocky niveau 2 : une AUTRE salle est traitee comme venant d'etre construite (choix facultatif)
	var rk := _with_mb(_plain("A"), "RMB058", 2)
	var other := _room("RMB040") # Delver's Quarry : « when you build ... draw a Room card »
	var pr := _player(0, "BMA001", [rk, other], 0)
	var Gr := _G([pr, _player(1, "BMA002")])
	_fill(Gr, "rooms", 3)
	var h3 := _hero("RMB082")
	_adventure(Gr, 0, h3, 0, 0)
	var mr := _match(Gr)
	mr._finish_hero(0, h3, 0, rk)
	var pcr := _pending(Gr)
	_ok.call(str(pcr.get("type", "")) == "tnl-pick" and bool(pcr.get("optional", false)) and (pcr["options"] as Array).size() == 1, "Rocky niveau 2 : choix facultatif d'une autre salle")
	_drain(mr)
	_ok.call(_hand(Gr, 0).size() == 1, "Rocky niveau 2 : Delver's Quarry rejoue son effet « build » (une salle piochee)")
	# Brassknuckle niveau 2 : une fois par tour, pioche une salle et peut la construire tout de suite
	var bk := _with_mb(_plain("A", "monster", [1], 2), "RMB063", 2)
	var pb := _player(0, "BMA001", [bk, _plain("B", "trap", [2], 1)], 0)
	var Gb := _G([pb, _player(1, "BMA002")])
	_fill(Gb, "rooms", 3)
	var h4 := _hero("RMB083")
	_adventure(Gb, 0, h4, 0, 0)
	var mbk := _match(Gb)
	mbk._finish_hero(0, h4, 0, bk)
	_ok.call(_hand(Gb, 0).size() == 1 and str(_pending(Gb).get("step", "")) == "rmb_build_slot" and bool(_pending(Gb).get("optional", false)), "Brassknuckle niveau 2 : une salle est piochee, construction immediate facultative")
	mbk._resolve_choice(0, -1)
	var h5 := _hero("RMB085")
	_adventure(Gb, 0, h5, 0, 0)
	mbk._finish_hero(0, h5, 0, bk)
	_ok.call(_hand(Gb, 0).size() == 1 and _pending(Gb).is_empty(), "Brassknuckle : une seule fois par tour")
	# Icicle Man niveau 2 : le texte des heros est ignore (Trap Master ne verrouille plus)
	var ic := _with_mb(_plain("H"), "RMB061", 2)
	var pi := _player(0, "BMA001", [ic], 0)
	var Gi := _G([pi, _player(1, "BMA002")])
	_adventure(Gi, 0, _hero("KSA017"), 0, 13)
	_ok.call(not BossEngine.abilities_locked(Gi, 0) and Minibosses.hero_text_ignored(Gi, 0), "Icicle Man niveau 2 : le texte des heros du donjon est ignore")
	var hm := _hero("KSA016") # Monster Hunter : -1 degat des salles Monster
	var pk := _player(0, "BMA001", [_with_mb(_plain("M", "monster", [1], 3), "RMB061", 2)], 0)
	var Gk := _G([pk, _player(1, "BMA002")])
	_ok.call(BossEngine.room_damage_with_modifiers(Gk, pk, 0, hm) == 4, "Icicle Man niveau 2 : la resistance du Monster Hunter est ignoree (3 + 1, sans le -1)")

func _t_level_two_activations() -> void:
	# Spike niveau 2 : defausse une carte, 2 degats au heros de cette salle (une fois par tour)
	var sp := _with_mb(_plain("A"), "RMB055", 2)
	var p0 := _player(0, "BMA001", [sp], 3)
	p0["hand"] = [_plain("K1"), _spl("S1")]
	var G := _G([p0, _player(1, "BMA002")])
	_adventure(G, 0, _hero("RMB087"), 0, 5)
	var m := _match(G)
	_ok.call(not _types(m.legal_moves(0), "activateMiniboss").is_empty(), "Spike niveau 2 : pouvoir propose quand un heros est dans la salle")
	_ok.call(m.apply_move(0, {"type": "activateMiniboss", "args": [0, 2]}), "Spike : pouvoir utilise")
	_ok.call(str(_pending(G).get("step", "")) == "rmb_cost" and (_pending(G)["options"] as Array).size() == 2, "Spike : choix de la carte a defausser")
	m._resolve_choice(0, 1)
	_ok.call(int(G["adventure"]["hp"]) == 3 and _hand(G, 0).size() == 1 and _decks(G, "spellDiscard").size() == 1, "Spike : 2 degats au heros, la carte choisie est defaussee")
	_ok.call(_types(m.legal_moves(0), "activateMiniboss").is_empty(), "Spike : une seule fois par tour")
	var G0 := _G([_player(0, "BMA001", [_with_mb(_plain("A"), "RMB055", 2)]), _player(1, "BMA002")])
	(G0["players"][0]["hand"] as Array).append(_plain("K"))
	G0["phase"] = "adventure"
	_ok.call(Minibosses.check_activate(G0, G0["players"][0], 0, 0, 2) != "", "Spike niveau 2 : sans heros dans la salle, rien")
	# Kid Croak niveau 2 : echange deux salles d'un donjon, pendant la construction
	var kc := _with_mb(_plain("A", "monster", [1], 2), "RMB056", 2)
	var kb := _plain("B", "trap", [2], 3)
	var pk := _player(0, "BMA001", [kc, kb], 3)
	var Gk := _G([pk, _player(1, "BMA002")])
	_build_phase(Gk)
	_ok.call(Minibosses.activate(Gk, 0, 0, 2) == null, "Kid Croak niveau 2 : echange accepte")
	_ok.call(_top(Gk, 0, 0) == kb and _top(Gk, 0, 1) == kc, "Kid Croak niveau 2 : les deux salles ont change de place (un seul donjon et une seule paire : sans choix)")
	Gk["phase"] = "adventure"
	(kc["mb"] as Dictionary)["usedTurn"] = -1
	_ok.call(Minibosses.check_activate(Gk, pk, 0, 1, 2) != "", "Kid Croak niveau 2 : pendant la construction seulement")
	# Draculad niveau 2 : renvoie en ville le heros de votre donjon
	var dr := _with_mb(_plain("A"), "RMB057", 2)
	var pd := _player(0, "BMA001", [dr], 3)
	var Gd := _G([pd, _player(1, "BMA002")])
	var hd := _hero("RMB088")
	_adventure(Gd, 0, hd, 0, 4)
	_ok.call(Minibosses.activate(Gd, 0, 0, 2) == null and (Gd["adventure"] as Dictionary).is_empty() and (Gd["town"] as Array).has(hd) and (pd["entrance"] as Array).is_empty(), "Draculad niveau 2 : le heros retourne en ville, sans ame ni blessure")
	_ok.call(Minibosses.check_activate(Gd, pd, 0, 0, 2) != "", "Draculad : une seule fois par tour (et plus de heros)")
	# Mageseeker niveau 2 : defausse un sort pour annuler un sort adverse (reponse sur la pile)
	var mg := _with_mb(_plain("A"), "RMB062", 2)
	var pg := _player(0, "BMA001", [mg], 3)
	var pg1 := _player(1, "BMA002")
	pg["hand"] = [_spl("MINE")]
	var Gg := _G([pg, pg1])
	_build_phase(Gg)
	var theirs := _spl("THEIRS")
	Gg["stack"] = [{"id": "st1", "type": "spell", "playerId": 1, "card": theirs, "target": {}, "resolved": false}]
	Gg["activePlayer"] = 0
	Gg["stackReturnPlayer"] = 1
	var mm := _match(Gg)
	var cancels := _types(mm.legal_moves(0), "rmbCancel")
	_ok.call(cancels.size() == 1, "Mageseeker niveau 2 : reponse possible quand un sort adverse attend sur la pile")
	_ok.call(mm.apply_move(0, {"type": "rmbCancel", "args": [0, 0]}) and (Gg["stack"] as Array).is_empty() and _ids(_decks(Gg, "spellDiscard")).has("THEIRS") and _ids(_decks(Gg, "spellDiscard")).has("MINE"),
		"Mageseeker : le sort adverse est annule, les deux sorts partent en defausse")
	_ok.call(int((mg["mb"] as Dictionary)["usedTurn"]) == 3, "Mageseeker : utilise ce tour")
	# Jinx niveau 2 : une copie de plus de chaque icone imprimee
	var jx := _with_mb(_plain("A", "trap", [1, 2], 1), "RMB064", 2)
	var pj := _player(0, "BMA001", [jx], 3)
	pj["boss"]["treasures"] = []
	var Gj := _G([pj, _player(1, "BMA002")])
	_ok.call(BossEngine.treasure_count(pj, 1, Gj) == 2 and BossEngine.treasure_count(pj, 2, Gj) == 2, "Jinx niveau 2 : icones imprimees doublees")
	(jx["mb"] as Dictionary)["level"] = 1
	_ok.call(BossEngine.treasure_count(pj, 1, Gj) == 1, "Jinx niveau 1 : pas de doublement")

## Chaque pouvoir de niveau 3 : effet, puis retour au niveau 1.
func _t_level_three_each() -> void:
	# Spike : un miniboss choisi retourne dans la main de son proprietaire
	var sp := _with_mb(_plain("A"), "RMB055", 3)
	var rk := _with_mb(_plain("B"), "RMB058", 1)
	var G := _G([_player(0, "BMA001", [sp]), _player(1, "BMA002", [rk])])
	var m := _match(G)
	_ok.call(Minibosses.activate(G, 0, 0, 3) == null and str(_pending(G).get("step", "")) == "rmb_mb_return" and (_pending(G)["options"] as Array).size() == 2, "Spike niveau 3 : choix d'un miniboss en jeu (le sien compris)")
	_ok.call(int((sp["mb"] as Dictionary)["level"]) == 1, "Spike : retour au niveau 1 des l'utilisation")
	m._resolve_choice(0, 1)
	_ok.call(not rk.has("mb") and _ids(_hand(G, 1)).has("RMB058"), "Spike niveau 3 : le miniboss choisi retourne dans la main de son proprietaire")
	# Kid Croak : +1 / -1 a toutes les salles Monster d'un donjon
	var kc := _with_mb(_plain("A", "monster", [1], 2), "RMB056", 3)
	var km := _plain("B", "monster", [2], 2)
	var kt := _plain("T", "trap", [2], 2)
	var Gk := _G([_player(0, "BMA001", [kc, km, kt]), _player(1, "BMA002", [_plain("O", "monster", [1], 3)])])
	var mk := _match(Gk)
	Minibosses.activate(Gk, 0, 0, 3)
	_ok.call(str(_pending(Gk).get("step", "")) == "rmb_croak" and (_pending(Gk)["options"] as Array).size() == 4, "Kid Croak niveau 3 : un donjon et +1 ou -1 (4 choix)")
	mk._resolve_choice(0, 3) # donjon adverse -1 (l'ordre des options : p0 +1, p0 -1, p1 +1, p1 -1)
	var opp: Dictionary = _top(Gk, 1, 0)
	_ok.call(int(opp.get("dealDamage", 0)) == -1 and int(km.get("dealDamage", 0)) == 0, "Kid Croak : les salles Monster du donjon choisi ont -1 (les Traps et l'autre donjon, rien)")
	# Draculad : regarde la main d'un adversaire, peut prendre un sort ou une salle
	var dr := _with_mb(_plain("A"), "RMB057", 3)
	var pd1 := _player(1, "BMA002")
	pd1["hand"] = [_spl("SP"), _plain("RM")]
	var Gd := _G([_player(0, "BMA001", [dr]), pd1])
	var md := _match(Gd)
	Minibosses.activate(Gd, 0, 0, 3)
	_ok.call(str(_pending(Gd).get("step", "")) == "rmb_steal" and bool(_pending(Gd).get("optional", false)) and (_pending(Gd)["options"] as Array).size() == 2, "Draculad niveau 3 : l'adversaire est auto, puis une carte facultative a prendre")
	md._resolve_choice(0, 0)
	_ok.call(_hand(Gd, 0).size() == 1 and _hand(Gd, 1).size() == 1, "Draculad : la carte passe de la main de l'adversaire a la votre")
	# Rocky : un heros d'un donjon +5 jusqu'a la fin du tour
	var ro := _with_mb(_plain("A"), "RMB058", 3)
	var G3 := _G([_player(0, "BMA001", [ro]), _player(1, "BMA002", [_plain("B")])])
	var hr := _hero("RMB090")
	(G3["players"][1]["entrance"] as Array).append(hr)
	Minibosses.activate(G3, 0, 0, 3)
	_ok.call(TnlAbilities.on_hero_start(G3, 1, hr) == 5 and int((ro["mb"] as Dictionary)["level"]) == 1, "Rocky niveau 3 : +5 PV au heros (verses a son entree dans le donjon), retour niveau 1")
	# Cerebella : les heros ignorent tout texte dans un donjon jusqu'a la fin du tour
	var ce := _with_mb(_plain("A"), "RMB059", 3)
	var Gc := _G([_player(0, "BMA001", [ce]), _player(1, "BMA002", [_plain("B")])])
	var mc := _match(Gc)
	Minibosses.activate(Gc, 0, 0, 3)
	_ok.call(str(_pending(Gc).get("step", "")) == "rmb_dungeon", "Cerebella niveau 3 : choix d'un donjon")
	mc._resolve_choice(0, 1)
	_ok.call(Minibosses.hero_text_ignored(Gc, 1) and not Minibosses.hero_text_ignored(Gc, 0), "Cerebella : le texte des heros est ignore dans le donjon choisi")
	# Paddywhack : tue le heros de cette salle (par apply_move : le heros meurt et rapporte une ame)
	var pw := _with_mb(_plain("A", "monster", [1], 1), "RMB060", 3)
	var Gp := _G([_player(0, "BMA001", [pw]), _player(1, "BMA002")])
	var mp := _match(Gp)
	_adventure(Gp, 0, _hero("RMB091"), 0, 7)
	var kill := _types(mp.legal_moves(0), "activateMiniboss").filter(func(mv): return int((mv as Dictionary)["args"][1]) == 3)
	_ok.call(kill.size() == 1 and mp.apply_move(0, kill[0]), "Paddywhack niveau 3 : coup propose et applique")
	_ok.call((Gp["adventure"] as Dictionary).is_empty() and (Gp["players"][0]["souls"] as Array).size() == 1 and int((pw["mb"] as Dictionary)["level"]) == 1, "Paddywhack : le heros meurt (une ame), le miniboss retombe au niveau 1")
	# Icicle Man : desactive une salle d'un donjon jusqu'a la fin du tour
	var ic := _with_mb(_plain("A"), "RMB061", 3)
	var Gi := _G([_player(0, "BMA001", [ic]), _player(1, "BMA002", [_plain("V", "trap", [1], 4)])])
	var mi := _match(Gi)
	Minibosses.activate(Gi, 0, 0, 3)
	_ok.call(str(_pending(Gi).get("step", "")) == "rmb_room" and (_pending(Gi)["options"] as Array).size() == 2, "Icicle Man niveau 3 : toute salle visible est ciblable")
	var vi := 0
	for i in (_pending(Gi)["options"] as Array).size():
		if int(((_pending(Gi)["options"] as Array)[i] as Dictionary)["targetPlayerId"]) == 1:
			vi = i
	mi._resolve_choice(0, vi)
	_ok.call(BossEngine.is_room_deactivated(Gi, 1, 0) and BossEngine.room_damage_with_modifiers(Gi, Gi["players"][1], 0, null) == 0, "Icicle Man : la salle choisie est desactivee (degats nuls)")
	# Mageseeker : les heros qui entrent dans ce donjon sautent sa premiere salle
	var ms := _with_mb(_plain("A", "monster", [1], 5), "RMB062", 3)
	var second := _plain("B", "monster", [1], 2)
	var Gm := _G([_player(0, "BMA001", [ms, second]), _player(1, "BMA002")])
	var mm := _match(Gm)
	Minibosses.activate(Gm, 0, 0, 3)
	mm._resolve_choice(0, 0)
	_ok.call((Gm["effects"]["skipFirstRoomPids"] as Array).has(0), "Mageseeker niveau 3 : le donjon choisi est memorise jusqu'a la fin du tour")
	var hm := _hero("RMB092")
	(Gm["players"][0]["entrance"] as Array).append(hm)
	Gm["adventure"] = {"playerId": 0, "hero": hm, "roomIndex": -1, "hp": 20, "pause": null}
	mm._advance_adventure_room()
	_ok.call(int(Gm["adventure"]["roomIndex"]) == 1 and int(Gm["adventure"]["hp"]) == 18, "Mageseeker : le heros saute la premiere salle (il entre dans la 2e et subit 2 degats)")
	# Brassknuckle : degats doubles jusqu'a la fin du tour
	var bk := _with_mb(_plain("A", "monster", [1], 3), "RMB063", 3)
	var pb := _player(0, "BMA001", [bk])
	var Gb := _G([pb, _player(1, "BMA002")])
	Minibosses.activate(Gb, 0, 0, 3)
	_ok.call(BossEngine.room_damage_with_modifiers(Gb, pb, 0, null) == 8 and int((bk["mb"] as Dictionary)["level"]) == 1, "Brassknuckle niveau 3 : (3 + 1 de niveau 1 qui reste) doubles = 8, retour niveau 1")
	# Jinx : un heros de la ville va a votre entree
	var jx := _with_mb(_plain("A"), "RMB064", 3)
	var Gj := _G([_player(0, "BMA001", [jx]), _player(1, "BMA002")])
	var tj := _hero("RMB093")
	var tk := _hero("RMB094")
	Gj["town"] = [tj, tk]
	var mj := _match(Gj)
	Minibosses.activate(Gj, 0, 0, 3)
	mj._resolve_choice(0, 1)
	_ok.call((Gj["town"] as Array) == [tj] and (Gj["players"][0]["entrance"] as Array) == [tk], "Jinx niveau 3 : le heros choisi quitte la ville pour votre entree")

func _t_activation_guards() -> void:
	var hid := _with_mb(_plain("A"), "RMB063", 3, true)
	var p0 := _player(0, "BMA001", [hid])
	var G := _G([p0, _player(1, "BMA002")])
	_ok.call(Minibosses.check_activate(G, p0, 0, 0, 3) != "", "un miniboss face cache n'a aucun pouvoir")
	(hid["mb"] as Dictionary)["faceDown"] = false
	_ok.call(Minibosses.check_activate(G, p0, 0, 0, 3) == "", "controle : visible, niveau 3 -> utilisable")
	G["phase"] = "bait"
	_ok.call(Minibosses.check_activate(G, p0, 0, 0, 3) != "", "ni pendant le leurre, ni a un autre moment que Build / Adventure")
	G["phase"] = "adventure"
	(hid["mb"] as Dictionary)["level"] = 2
	_ok.call(Minibosses.check_activate(G, p0, 0, 0, 3) != "", "le niveau 3 exige le niveau 3")
	_ok.call(Minibosses.check_activate(G, p0, 0, 0, 2) != "", "Brassknuckle n'a pas de pouvoir active de niveau 2 (declencheur seulement)")
	(hid["mb"] as Dictionary)["level"] = 3
	(G["effects"]["deactivatedRooms"] as Array).append({"playerId": 0, "roomIndex": 0})
	_ok.call(Minibosses.check_activate(G, p0, 0, 0, 3) != "", "un miniboss sur une salle desactivee est desactive aussi")
	_ok.call(Minibosses.activate(G, 0, 0, 3) is String, "activate refuse proprement (message d'erreur)")

func _t_miniboss_hand_and_state() -> void:
	# Monster Academy / Vampire Lab comptent les minibosses en main ; Ambush les defausse : ils se defaussent dans la pile de salles
	var G := _G([_player(0, "BMA001"), _player(1, "BMA002")])
	var card := _minicard("RMB055")
	(G["players"][0]["hand"] as Array).append(card)
	_ok.call(TnlAbilities.hand_options(G["players"][0], "room").size() == 1, "un miniboss est une carte « salle » pour les defausses (Jinx, Deadly Treadmill...)")
	TnlAbilities.discard_from_hand(G, 0, card)
	_ok.call(_decks(G, "roomDiscard").has(card) and card.has("levels"), "miniboss defausse : pile de defausse des salles")

# --- les 12 boss ----------------------------------------------------------------------------------------------------------------------

func _t_boss_flags_and_klonos() -> void:
	var ids := ["RMB001", "RMB002", "RMB003", "RMB004", "RMB005", "RMB006", "RMB007", "RMB008", "RMB009", "RMB010", "RMB011", "RMB012"]
	var all := true
	for bid in ids:
		var p0 := _player(0, str(bid))
		var G := _G([p0, _player(1, "BMA002")])
		var c = RoomAbilities.process_level_up(G, 0)
		all = all and c == null and RmbAbilities.has_boss(p0, str(bid)) and not RmbAbilities.has_boss(_player(0, str(bid)), str(bid))
	_ok.call(all, "les 12 boss RMB posent leur drapeau « pour le reste de la partie » au level up (rien d'immediat)")
	# Klonos (CRL002) copie le level-up d'un boss RMB : son pouvoir est a lui pour la partie
	var k0 := _player(0, "CRL002")
	var gregore := _player(1, "RMB001")
	var G2 := _G([k0, gregore])
	var c2 = RoomAbilities.process_level_up(G2, 0)
	_ok.call(c2 == null and RmbAbilities.has_boss(k0, "RMB001"), "Klonos copie Gregore : le drapeau est pose chez Klonos")
	var hero := _hero("RMB080")
	k0["dungeon"] = [[_plain("A")]]
	RmbAbilities.on_hero_killed(G2, 0)
	_ok.call(_coins(G2, 0) == 4, "Klonos : le pouvoir copie fonctionne (Gregore : +1 Coin quand il tue un heros)")
	# Klonos copie King Croak : ses minibosses commencent au niveau 2
	var k1 := _player(0, "CRL002", [_plain("R")])
	var G3 := _G([k1, _player(1, "RMB005")])
	RoomAbilities.process_level_up(G3, 0)
	k1["hand"] = [_minicard("RMB058")]
	_build_phase(G3)
	_match(G3).apply_move(0, {"type": "buildMiniboss", "args": [0, 0]})
	_ok.call(int((_top(G3, 0, 0)["mb"] as Dictionary)["level"]) == 2, "Klonos copie King Croak : ses minibosses poses commencent au niveau 2")
	# Klonos copie Scott / Lamia : les passifs suivent aussi
	var k2 := _player(0, "CRL002", [_plain("T", "trap", [4], 2)])
	var G4 := _G([k2, _player(1, "RMB011")])
	RoomAbilities.process_level_up(G4, 0)
	_ok.call(BossEngine.room_damage_with_modifiers(G4, k2, 0, null) == 3, "Klonos copie Scott : ses salles Trap ont +1")

func _t_boss_coin_triggers() -> void:
	# Gregore : une fois par tour, +1 Coin quand il tue un heros
	var room := _plain("A")
	var p0 := _player(0, "RMB001", [room], 0)
	p0["rmbBoss"] = {"RMB001": true}
	var G := _G([p0, _player(1, "BMA002")])
	var m := _match(G)
	var h1 := _hero("RMB080")
	_adventure(G, 0, h1, 0, 0)
	m._finish_hero(0, h1, 0, room)
	var h2 := _hero("RMB081")
	_adventure(G, 0, h2, 0, 0)
	m._finish_hero(0, h2, 0, room)
	_ok.call(_coins(G, 0) == 1, "Gregore : +1 Coin pour le premier heros tue du tour seulement")
	# Lamia / Dr. Deadly : un Coin quand vous construisez une salle Monster / Trap
	var pl := _player(0, "RMB004", [], 0)
	pl["rmbBoss"] = {"RMB004": true, "RMB010": true}
	var Gl := _G([pl, _player(1, "BMA002")])
	RoomAbilities.on_build_room(Gl, 0, _plain("M", "monster"))
	RoomAbilities.on_build_room(Gl, 0, _plain("T", "trap"))
	RoomAbilities.on_build_room(Gl, 0, _plain("M2", "monster"))
	_ok.call(_coins(Gl, 0) == 3, "Lamia (Monster) et Dr. Deadly (Trap) : +1 Coin par salle construite (3 salles)")
	Gl["rmbReplay"] = true
	RoomAbilities.on_build_room(Gl, 0, _plain("M3", "monster"))
	_ok.call(_coins(Gl, 0) == 3, "rejouer l'effet d'une salle (The Omega 42) ne declenche pas les boss")
	# Baron Hex : +1 Coin par sort lance (resolu) ; Alchemist's Lab : une fois par tour, +2 ; Windfall (sans Coin : +3)
	var lab := _room("RMB032")
	var ph := _player(0, "RMB007", [lab], 0)
	ph["rmbBoss"] = {"RMB007": true}
	ph["hand"] = [_spell("RMB065"), _spell("RMB065")]
	var Gh := _G([ph, _player(1, "BMA002")])
	_build_phase(Gh)
	var mh := _match(Gh)
	var cast := _types(mh.legal_moves(0), "playSpell")
	_ok.call(cast.size() == 2 and mh.apply_move(0, cast[0]), "Windfall jouable (aucun Coin en Hoard)")
	mh.apply_move(1, {"type": "pass", "args": []})
	_ok.call(_coins(Gh, 0) == 3 + 1 + 2, "sort lance : Windfall +3, Baron Hex +1, Alchemist's Lab +2 (total %d)" % _coins(Gh, 0))
	_ok.call(_types(mh.legal_moves(0), "playSpell").is_empty(), "Windfall : plus jouable avec des Coins en Hoard")
	ph["coins"] = 0
	ph["hand"] = [_spell("RMB065")]
	var cast2 := _types(mh.legal_moves(0), "playSpell")
	mh.apply_move(0, cast2[0])
	mh.apply_move(1, {"type": "pass", "args": []})
	_ok.call(_coins(Gh, 0) == 4, "Alchemist's Lab : une seule fois par tour (Windfall +3, Baron Hex +1)")
	# Oculus : un sort quand un heros meurt dans une salle avec un miniboss
	var oc := _with_mb(_plain("A"), "RMB055", 1)
	var po := _player(0, "RMB008", [oc, _plain("B")], 0)
	po["rmbBoss"] = {"RMB008": true}
	var Go := _G([po, _player(1, "BMA002")])
	_fill(Go, "spells", 2, "spell")
	var mo := _match(Go)
	var ho := _hero("RMB084")
	_adventure(Go, 0, ho, 0, 0)
	mo._finish_hero(0, ho, 0, oc)
	_ok.call(_hand(Go, 0).size() == 1, "Oculus : un sort pioche quand un heros meurt dans une salle avec un miniboss")
	var plain_room := _top(Go, 0, 1)
	var ho2 := _hero("RMB086")
	_adventure(Go, 0, ho2, 1, 0)
	mo._finish_hero(0, ho2, 0, plain_room)
	_ok.call(_hand(Go, 0).size() == 1, "Oculus : rien dans une salle sans miniboss")

func _t_boss_oculus_croak_scott() -> void:
	# Scott : les salles Trap ont +1 ; un adversaire peut donner 1 Coin pour annuler jusqu'a la fin du tour
	var tr := _plain("T", "trap", [4], 2)
	var mo := _plain("M", "monster", [2], 2)
	var p0 := _player(0, "RMB011", [tr, mo], 0)
	p0["rmbBoss"] = {"RMB011": true}
	var p1 := _player(1, "BMA002", [], 2)
	var G := _G([p0, p1])
	_ok.call(BossEngine.room_damage_with_modifiers(G, p0, 0, null) == 3 and BossEngine.room_damage_with_modifiers(G, p0, 1, null) == 2, "Scott : +1 aux salles Trap seulement")
	var m := _match(G)
	var pay := _types(m.legal_moves(1), "rmbBoss").filter(func(mv): return str((mv as Dictionary)["args"][0]) == "RMB011")
	_ok.call(pay.size() == 1 and _types(m.legal_moves(0), "rmbBoss").filter(func(mv): return str((mv as Dictionary)["args"][0]) == "RMB011").is_empty(), "Scott : seul un adversaire peut payer pour annuler")
	_ok.call(m.apply_move(1, pay[0]) and _coins(G, 1) == 1 and _coins(G, 0) == 1, "l'adversaire donne 1 Coin a Scott")
	_ok.call(BossEngine.room_damage_with_modifiers(G, p0, 0, null) == 2, "Scott : le +1 est annule jusqu'a la fin du tour")
	_ok.call(_types(m.legal_moves(1), "rmbBoss").filter(func(mv): return str((mv as Dictionary)["args"][0]) == "RMB011").is_empty(), "inutile de payer deux fois")

func _t_boss_active_powers() -> void:
	# Belladonna : 2 Coins, un adversaire defausse un sort au hasard (une fois par tour)
	var p0 := _player(0, "RMB003", [], 5)
	p0["rmbBoss"] = {"RMB003": true}
	var p1 := _player(1, "BMA002", [], 0)
	p1["hand"] = [_spl("S1"), _plain("R1")]
	var G := _G([p0, p1])
	_build_phase(G)
	var m := _match(G)
	var mv := _types(m.legal_moves(0), "rmbBoss")
	_ok.call(mv.size() == 1 and str((mv[0] as Dictionary)["args"][0]) == "RMB003", "Belladonna : pouvoir propose (2 Coins, un adversaire a un sort)")
	m.apply_move(0, mv[0])
	_ok.call(_coins(G, 0) == 3 and _hand(G, 1).size() == 1 and _ids(_decks(G, "spellDiscard")).has("S1"), "Belladonna : 2 Coins payes, le sort de l'adversaire est defausse")
	_ok.call(_types(m.legal_moves(0), "rmbBoss").is_empty(), "Belladonna : une fois par tour")
	# Ravenus : 2 Coins, double les degats d'une salle Monster
	var p2 := _player(0, "RMB006", [_plain("M", "monster", [1], 3)], 2)
	p2["rmbBoss"] = {"RMB006": true}
	var G2 := _G([p2, _player(1, "BMA002")])
	var m2 := _match(G2)
	var rv := _types(m2.legal_moves(0), "rmbBoss")
	_ok.call(rv.size() == 1, "Ravenus : pouvoir propose")
	m2.apply_move(0, rv[0])
	_ok.call(BossEngine.room_damage_with_modifiers(G2, p2, 0, null) == 6 and _coins(G2, 0) == 0, "Ravenus : degats doubles (3 -> 6), 2 Coins payes")
	# Kazanna : 2 Coins, pioche un sort
	var p3 := _player(0, "RMB009", [], 2)
	p3["rmbBoss"] = {"RMB009": true}
	var G3 := _G([p3, _player(1, "BMA002")])
	_fill(G3, "spells", 2, "spell")
	var m3 := _match(G3)
	m3.apply_move(0, _types(m3.legal_moves(0), "rmbBoss")[0])
	_ok.call(_hand(G3, 0).size() == 1 and _coins(G3, 0) == 0, "Kazanna : un sort pioche pour 2 Coins")
	# Kirax : 2 Coins, un tresor de plus (au choix) dans le donjon de n'importe quel joueur jusqu'a la fin du tour
	var p4 := _player(0, "RMB012", [], 2)
	p4["rmbBoss"] = {"RMB012": true}
	p4["boss"]["treasures"] = []
	var G4 := _G([p4, _player(1, "BMA002")])
	var m4 := _match(G4)
	m4.apply_move(0, _types(m4.legal_moves(0), "rmbBoss")[0])
	_ok.call(str(_pending(G4).get("step", "")) == "rmb_player" and (_pending(G4)["options"] as Array).size() == 2, "Kirax : choix du donjon")
	m4._resolve_choice(0, 0)
	_ok.call(str(_pending(G4).get("step", "")) == "rmb_icon" and (_pending(G4)["options"] as Array).size() == 4, "Kirax : choix du type de tresor")
	m4._resolve_choice(0, 2)
	_ok.call(BossEngine.treasure_count(p4, 3, G4) == 1, "Kirax : une icone Mage de plus dans le donjon (jusqu'a la fin du tour)")
	m4.G["effects"] = SpellEffects.empty_effects()
	_ok.call(BossEngine.treasure_count(p4, 3, G4) == 0, "Kirax : l'icone disparait au tour suivant")

# --- les 42 salles --------------------------------------------------------------------------------------------------------------------

## « When you build this Room » (la revelation de fin de BUILD appelle RoomAbilities.on_build_room) et « build or uncover ».
func _t_rooms_build_effects() -> void:
	# RMB014 Monster Academy : 2 Coins par miniboss de la main (reveles : ils y restent)
	var ac := _room("RMB014")
	var p0 := _player(0, "BMA001", [ac], 0)
	p0["hand"] = [_minicard("RMB055"), _minicard("RMB056"), _plain("R")]
	var G := _G([p0, _player(1, "BMA002")])
	RoomAbilities.on_build_room(G, 0, ac)
	_ok.call(_coins(G, 0) == 4 and _hand(G, 0).size() == 3, "RMB014 Monster Academy : 2 Coins par miniboss de la main (ils y restent)")
	# RMB015 Ancient Guardtower : choisit un adversaire a la construction ; ce tour seulement, 1 Coin contre un sort au hasard
	var gt := _room("RMB015")
	var q0 := _player(0, "BMA001", [gt], 2)
	var p2 := _player(2, "BMA003")
	var q1 := _player(1, "BMA002")
	q1["hand"] = [_spl("OPP1")]
	p2["hand"] = [_spl("OPP2"), _plain("RR")]
	var G2 := _G([q0, q1, p2])
	var c = RoomAbilities.on_build_room(G2, 0, gt)
	_ok.call(c != null and str(c["step"]) == "rmb_opp" and (c["options"] as Array).size() == 2, "RMB015 Ancient Guardtower : choix de l'adversaire (deux adversaires)")
	TnlAbilities.resolve_pick(G2, 0, c, 1)
	_ok.call(_act(G2, 0, 0) == null, "RMB015 : capacite activable le tour de la construction")
	_ok.call(_coins(G2, 0) == 1 and _coins(G2, 2) == 4 and _ids(_hand(G2, 0)).has("OPP2") and _hand(G2, 2).size() == 1, "RMB015 : 1 Coin donne a l'adversaire designe, un de ses sorts pris")
	_ok.call(_act(G2, 0, 0) is String, "RMB015 : une seule fois")
	gt["usedThisTurn"] = false
	G2["turn"] = 4
	_ok.call(_act(G2, 0, 0) is String, "RMB015 : plus le tour suivant (« once this turn »)")
	# RMB018 Vampire Lab : defausse un miniboss pour soigner une blessure
	var vl := _room("RMB018")
	var p3 := _player(0, "BMA001", [vl], 0)
	p3["hand"] = [_minicard("RMB057")]
	(p3["wounds"] as Array).append({"name": "x", "wounds": 1, "souls": 1, "faceDown": false, "hero": _hero("RMB080")})
	var G3 := _G([p3, _player(1, "BMA002")])
	var c3 = RoomAbilities.on_build_room(G3, 0, vl)
	_ok.call(c3 != null and bool(c3["optional"]), "RMB018 Vampire Lab : choix facultatif d'un miniboss a defausser")
	TnlAbilities.resolve_pick(G3, 0, c3, 0)
	_ok.call((p3["wounds"] as Array).is_empty() and (p3["souls"] as Array).size() == 1 and _hand(G3, 0).is_empty() and _ids(_decks(G3, "roomDiscard")).has("RMB057"), "RMB018 : blessure soignee, miniboss defausse")
	var p3b := _player(0, "BMA001", [_room("RMB018")], 0)
	p3b["hand"] = [_minicard("RMB057")]
	_ok.call(RoomAbilities.on_build_room(_G([p3b, _player(1, "BMA002")]), 0, _top(_G([p3b, _player(1, "BMA002")]), 0, 0)) == null, "RMB018 : sans blessure, rien")
	# RMB020 Minion Clinic : jusqu'a 3 Coins poses dessus, une carte de la defausse par Coin, -1 par Coin
	var mc := _room("RMB020")
	var p4 := _player(0, "BMA001", [mc], 3)
	var G4 := _G([p4, _player(1, "BMA002")])
	_fill(G4, "roomDiscard", 3)
	var m4 := _match(G4)
	G4["pendingChoice"] = RoomAbilities.on_build_room(G4, 0, mc)
	_ok.call(str(_pending(G4).get("step", "")) == "rmb_n" and (_pending(G4)["options"] as Array).size() == 4, "RMB020 Minion Clinic : choix de 0 a 3 Coins")
	m4._resolve_choice(0, 2)
	_ok.call(_coins(G4, 0) == 1 and int(mc["coins"]) == 2 and str(_pending(G4).get("step", "")) == "rmb_recover", "RMB020 : 2 Coins poses sur la salle, premiere carte a recuperer")
	_drain(m4)
	_ok.call(_hand(G4, 0).size() == 2 and _decks(G4, "roomDiscard").size() == 1, "RMB020 : deux cartes de la defausse vont en main")
	_ok.call(BossEngine.room_damage_with_modifiers(G4, p4, 0, null) == 1, "RMB020 : -1 par Coin pose (3 - 2 = 1)")
	# RMB021 Robber's Vault : echange des Hoards (meme sans Coin)
	var rv := _room("RMB021")
	var p5 := _player(0, "BMA001", [rv], 1)
	var G5 := _G([p5, _player(1, "BMA002", [], 5)])
	RoomAbilities.on_build_room(G5, 0, rv)
	_ok.call(_coins(G5, 0) == 5 and _coins(G5, 1) == 1, "RMB021 Robber's Vault : les deux Hoards sont echanges")
	# RMB028 Dragon's Nest : chaque AUTRE salle Monster +1 par icone de tresor, jusqu'a la fin du tour
	var nest := _room("RMB028")
	var m1 := _plain("M1", "monster", [1, 2], 2)
	var tr := _plain("T1", "trap", [2, 3], 2)
	var p6 := _player(0, "BMA001", [nest, m1, tr], 0)
	var G6 := _G([p6, _player(1, "BMA002")])
	RoomAbilities.on_build_room(G6, 0, nest)
	_ok.call(BossEngine.room_damage_with_modifiers(G6, p6, 1, null) == 4 and BossEngine.room_damage_with_modifiers(G6, p6, 2, null) == 2 and BossEngine.room_damage_with_modifiers(G6, p6, 0, null) == 4,
		"RMB028 Dragon's Nest : l'autre salle Monster gagne +2 (2 icones), ni le Trap ni la salle elle-meme")
	# RMB031 Mysterious Portal : defausse un miniboss pour piocher un sort
	var mp := _room("RMB031")
	var p7 := _player(0, "BMA001", [mp], 0)
	p7["hand"] = [_minicard("RMB056")]
	var G7 := _G([p7, _player(1, "BMA002")])
	_fill(G7, "spells", 2, "spell")
	var c7 = RoomAbilities.on_build_room(G7, 0, mp)
	TnlAbilities.resolve_pick(G7, 0, c7, 0)
	_ok.call(_hand(G7, 0).size() == 1 and bool((_hand(G7, 0)[0] as Dictionary).get("isSpell", false)) and _ids(_decks(G7, "roomDiscard")).has("RMB056"), "RMB031 Mysterious Portal : un miniboss defausse, un sort pioche")
	# RMB036 Loot Box : paye 2 Coins, pioche 2 sorts (« build » seulement)
	var lb := _room("RMB036")
	var p8 := _player(0, "BMA001", [lb], 2)
	var G8 := _G([p8, _player(1, "BMA002")])
	_fill(G8, "spells", 3, "spell")
	var c8 = RoomAbilities.on_build_room(G8, 0, lb)
	_ok.call(c8 != null and bool(c8["optional"]), "RMB036 Loot Box : paiement facultatif")
	TnlAbilities.resolve_pick(G8, 0, c8, 0)
	_ok.call(_coins(G8, 0) == 0 and _hand(G8, 0).size() == 2, "RMB036 : 2 Coins payes, 2 sorts")
	var p8b := _player(0, "BMA001", [_room("RMB036")], 1)
	var G8b := _G([p8b, _player(1, "BMA002")])
	_fill(G8b, "spells", 3, "spell")
	_ok.call(RoomAbilities.on_build_room(G8b, 0, _top(G8b, 0, 0)) == null, "RMB036 : sans 2 Coins, rien")
	# RMB037 Crystal Ballroom : jusqu'a 3 Coins poses dessus, un sort par Coin, -1 par Coin
	var cb := _room("RMB037")
	var p9 := _player(0, "BMA001", [cb], 3)
	var G9 := _G([p9, _player(1, "BMA002")])
	_fill(G9, "spells", 4, "spell")
	var m9 := _match(G9)
	G9["pendingChoice"] = RoomAbilities.on_build_room(G9, 0, cb)
	m9._resolve_choice(0, 3)
	_ok.call(_coins(G9, 0) == 0 and _hand(G9, 0).size() == 3 and int(cb["coins"]) == 3 and BossEngine.room_damage_with_modifiers(G9, p9, 0, null) == 0, "RMB037 Crystal Ballroom : 3 Coins -> 3 sorts, degats 3 - 3 = 0")
	# RMB040 Delver's Quarry : pioche une salle
	var dq := _room("RMB040")
	var p10 := _player(0, "BMA001", [dq], 0)
	var G10 := _G([p10, _player(1, "BMA002")])
	_fill(G10, "rooms", 2)
	RoomAbilities.on_build_room(G10, 0, dq)
	_ok.call(_hand(G10, 0).size() == 1, "RMB040 Delver's Quarry : une salle piochee a la construction")
	# RMB050 Trophy Room : 1 Coin par salle multi-tresor du donjon (elle comprise)
	var tro := _room("RMB050")
	var p11 := _player(0, "BMA001", [tro, _room("RMB049"), _plain("S", "trap", [1], 1)], 0)
	var G11 := _G([p11, _player(1, "BMA002")])
	RoomAbilities.on_build_room(G11, 0, tro)
	_ok.call(_coins(G11, 0) == 2, "RMB050 Trophy Room : 2 salles multi-tresor (elle et Personnel Office) -> 2 Coins")

func _t_rooms_uncover_effects() -> void:
	# « build or uncover » : Delver's Quarry, Monster Academy, Trophy Room... se declenchent quand la salle au-dessus est detruite
	var q := _room("RMB040")
	var top := _plain("X")
	var p0 := _player(0, "BMA001", [[q, top]], 0)
	var G := _G([p0, _player(1, "BMA002")])
	_fill(G, "rooms", 2)
	BossEngine.destroy_room(p0, 0, G)
	_ok.call(_hand(G, 0).size() == 1, "RMB040 : decouverte -> pioche une salle")
	var ac := _room("RMB014")
	var p1 := _player(0, "BMA001", [[ac, _plain("Y")]], 0)
	p1["hand"] = [_minicard("RMB055")]
	var G1 := _G([p1, _player(1, "BMA002")])
	BossEngine.destroy_room(p1, 0, G1)
	_ok.call(_coins(G1, 0) == 2, "RMB014 Monster Academy : decouverte -> 2 Coins par miniboss en main")
	var tro := _room("RMB050")
	var p2 := _player(0, "BMA001", [[tro, _plain("Z")]], 0)
	var G2 := _G([p2, _player(1, "BMA002")])
	BossEngine.destroy_room(p2, 0, G2)
	_ok.call(_coins(G2, 0) == 1, "RMB050 Trophy Room : decouverte -> 1 Coin (elle seule est multi-tresor)")
	var vl := _room("RMB018")
	var p3 := _player(0, "BMA001", [[vl, _plain("W")]], 0)
	p3["hand"] = [_minicard("RMB056")]
	(p3["wounds"] as Array).append({"name": "x", "wounds": 1, "souls": 1, "faceDown": false, "hero": _hero("RMB080")})
	var G3 := _G([p3, _player(1, "BMA002")])
	BossEngine.destroy_room(p3, 0, G3)
	_ok.call(not _pending(G3).is_empty() and str(_pending(G3)["step"]) == "rmb_cost", "RMB018 Vampire Lab : decouverte -> meme choix qu'a la construction")
	var nest := _room("RMB028")
	var mon := _plain("M", "monster", [1], 2)
	var p4 := _player(0, "BMA001", [[nest, _plain("V")], mon], 0)
	var G4 := _G([p4, _player(1, "BMA002")])
	BossEngine.destroy_room(p4, 0, G4)
	_ok.call(int(mon.get("dealDamage", 0)) == 1, "RMB028 Dragon's Nest : decouverte -> l'autre salle Monster +1 (une icone)")
	var mpo := _room("RMB031")
	var p5 := _player(0, "BMA001", [[mpo, _plain("U")]], 0)
	p5["hand"] = [_minicard("RMB057")]
	var G5 := _G([p5, _player(1, "BMA002")])
	_fill(G5, "spells", 2, "spell")
	BossEngine.destroy_room(p5, 0, G5)
	_ok.call(str(_pending(G5).get("step", "")) == "rmb_cost", "RMB031 Mysterious Portal : decouverte -> choix facultatif")
	# « build » seulement : Loot Box, Crystal Ballroom, Robber's Vault, Minion Clinic, Ancient Guardtower ne se declenchent pas a la decouverte
	for rid in ["RMB036", "RMB037", "RMB021", "RMB020", "RMB015"]:
		var p6 := _player(0, "BMA001", [[_room(str(rid)), _plain("T")]], 5)
		var G6 := _G([p6, _player(1, "BMA002", [], 2)])
		_fill(G6, "spells", 4, "spell")
		BossEngine.destroy_room(p6, 0, G6)
		_ok.call(_pending(G6).is_empty() and _coins(G6, 0) == 5 and _coins(G6, 1) == 2, "%s : rien a la decouverte (effet « build » seulement)" % rid)

func _t_rooms_passive_damage() -> void:
	# RMB024 Power Leech : la salle a sa droite (vers le boss), si Monster, +2
	var p0 := _player(0, "BMA001", [_room("RMB024"), _plain("M", "monster", [1], 2), _plain("T", "trap", [1], 2)], 0)
	var G := _G([p0, _player(1, "BMA002")])
	_ok.call(BossEngine.room_damage_with_modifiers(G, p0, 1, null) == 4, "RMB024 Power Leech : +2 a la salle Monster de droite")
	var p0b := _player(0, "BMA001", [_room("RMB024"), _plain("T", "trap", [1], 2)], 0)
	_ok.call(BossEngine.room_damage_with_modifiers(_G([p0b, _player(1, "BMA002")]), p0b, 1, null) == 2, "RMB024 : rien pour une salle Trap")
	var p0c := _player(0, "BMA001", [_plain("M", "monster", [1], 2), _room("RMB024")], 0)
	_ok.call(BossEngine.room_damage_with_modifiers(_G([p0c, _player(1, "BMA002")]), p0c, 0, null) == 2, "RMB024 : rien pour la salle de gauche")
	# RMB029 Doppelganger Hive : +1 par heros leurre ce tour ; RMB039 Magipede : +1 par sort en main
	var hive := _room("RMB029")
	var mag := _room("RMB039")
	var p1 := _player(0, "BMA001", [hive, mag], 0)
	p1["hand"] = [_spl("A"), _spl("B"), _plain("C")]
	var G1 := _G([p1, _player(1, "BMA002")])
	G1["luredThisTurn"] = {0: 3}
	_ok.call(BossEngine.room_damage_with_modifiers(G1, p1, 0, null) == 2 + 3, "RMB029 Doppelganger Hive : +1 par heros leurre (3)")
	_ok.call(BossEngine.room_damage_with_modifiers(G1, p1, 1, null) == 2 + 2, "RMB039 Magipede : +1 par sort en main (2)")
	# RMB048 The Dreadmill : un Coin pose a chaque BUILD, +1 par Coin ; sans Coin, elle est detruite
	var dm := _room("RMB048")
	var p2 := _player(0, "BMA001", [dm], 2)
	var G2 := _G([p2, _player(1, "BMA002")])
	Minibosses.on_build_start(G2)
	Minibosses.on_build_start(G2)
	_ok.call(int(dm["coins"]) == 2 and _coins(G2, 0) == 0 and BossEngine.room_damage_with_modifiers(G2, p2, 0, null) == 2 + 2, "RMB048 The Dreadmill : un Coin par BUILD, +1 degat par Coin (2 -> 4)")
	Minibosses.on_build_start(G2)
	_ok.call((p2["dungeon"] as Array).is_empty() and _ids(_decks(G2, "roomDiscard")).has("RMB048"), "RMB048 : impossible de placer un Coin -> la salle est detruite")
	# RMB025 Fetid Beast : pas de salle Monster a cote (la Bete peut se poser a cote d'une salle Monster)
	var beast := _room("RMB025")
	var p3 := _player(0, "BMA001", [_plain("A", "trap", [1], 1), beast], 0)
	p3["hand"] = [_plain("M", "monster", [2], 1), _plain("T", "trap", [2], 1), _plain("AM", "monster", [1], 2, true), _room("RMB025")]
	var G3 := _G([p3, _player(1, "BMA002")])
	_build_phase(G3)
	_ok.call(BossEngine.can_build_room(p3, G3, 0, 1, -1) and not BossEngine.can_build_room(p3, G3, 0, 0, 0) and BossEngine.can_build_room(p3, G3, 0, 0, 1),
		"RMB025 Fetid Beast : pas de salle Monster a cote ; on peut la couvrir, et poser une salle Trap")
	_ok.call(not BossEngine.can_build_room(p3, G3, 0, 2, 0) and BossEngine.can_build_room(p3, G3, 0, 3, -1), "RMB025 : valable aussi pour une salle avancee ; la Bete elle-meme se pose a cote d'un Monster")
	var p3b := _player(0, "BMA001", [beast, _plain("A", "trap", [1], 1)], 0)
	p3b["hand"] = [_plain("M", "monster", [2], 1)]
	_ok.call(not BossEngine.can_build_room(p3b, G3, 0, 0, -1), "RMB025 : une salle Monster ne se pose pas en bout de donjon a cote de la Bete")
	# RMB023 Goblin Market : 2 Coins quand vous construisez une salle a cote
	var market := _room("RMB023")
	var side := _plain("X")
	var far := _plain("Y")
	var p4 := _player(0, "BMA001", [market, side, far], 0)
	var G4 := _G([p4, _player(1, "BMA002")])
	RoomAbilities.on_build_room(G4, 0, side)
	_ok.call(_coins(G4, 0) == 2, "RMB023 Goblin Market : 2 Coins pour une salle construite a cote")
	RoomAbilities.on_build_room(G4, 0, far)
	_ok.call(_coins(G4, 0) == 2, "RMB023 : rien pour une salle non adjacente")

func _t_rooms_destroy_for_coins() -> void:
	# RMB042 Unstable Mine : se detruit, +3 Coins
	var mine := _room("RMB042")
	var p0 := _player(0, "BMA001", [mine], 0)
	var G := _G([p0, _player(1, "BMA002")])
	var m := _match(G)
	_ok.call(not _types(m.legal_moves(0), "activateRoom").is_empty(), "RMB042 : capacite activable (coup activateRoom)")
	_ok.call(_act(G, 0, 0) == null and _coins(G, 0) == 3 and (p0["dungeon"] as Array).is_empty() and _ids(_decks(G, "roomDiscard")).has("RMB042"), "RMB042 Unstable Mine : se detruit, +3 Coins")
	# RMB052 Pixie Fountain : 1 Coin par blessure ; inutile sans blessure
	var px := _room("RMB052")
	var p1 := _player(0, "BMA001", [px], 0)
	var G1 := _G([p1, _player(1, "BMA002")])
	_ok.call(_act(G1, 0, 0) is String and not (p1["dungeon"] as Array).is_empty(), "RMB052 : sans blessure, refuse")
	for i in 2:
		(p1["wounds"] as Array).append({"name": "x", "wounds": 1, "souls": 1, "faceDown": false})
	_ok.call(_act(G1, 0, 0) == null and _coins(G1, 0) == 2, "RMB052 Pixie Fountain : 1 Coin par blessure (2)")
	# RMB053 The Keystone : 1 Coin par salle restante
	var ks := _room("RMB053")
	var p2 := _player(0, "BMA001", [ks, _plain("A"), _plain("B"), _plain("C")], 0)
	var G2 := _G([p2, _player(1, "BMA002")])
	_ok.call(_act(G2, 0, 0) == null and _coins(G2, 0) == 3, "RMB053 The Keystone : 1 Coin par salle restante (3)")
	# RMB013 Spectral Bomb : se detruit, un adversaire defausse un sort au hasard
	var bomb := _room("RMB013")
	var p3 := _player(0, "BMA001", [bomb], 0)
	var p3o := _player(1, "BMA002")
	p3o["hand"] = [_spl("S1"), _plain("RR")]
	var G3 := _G([p3, p3o])
	_ok.call(_act(G3, 0, 0) == null and (p3["dungeon"] as Array).is_empty() and _hand(G3, 1).size() == 1 and _ids(_decks(G3, "spellDiscard")).has("S1"), "RMB013 Spectral Bomb : se detruit, l'adversaire defausse un sort")
	var bomb2 := _room("RMB013")
	var G3b := _G([_player(0, "BMA001", [bomb2]), _player(1, "BMA002")])
	_ok.call(_act(G3b, 0, 0) is String, "RMB013 : refusee quand aucun adversaire n'a de sort")
	# RMB045 Endless Gallery : se detruit, un tresor de plus (au choix) dans le donjon de n'importe quel joueur
	var eg := _room("RMB045")
	var p4 := _player(0, "BMA001", [eg], 0)
	p4["boss"]["treasures"] = []
	var G4 := _G([p4, _player(1, "BMA002")])
	var m4 := _match(G4)
	_act(G4, 0, 0)
	m4._resolve_choice(0, 0)
	m4._resolve_choice(0, 3)
	_ok.call((p4["dungeon"] as Array).is_empty() and BossEngine.treasure_count(p4, 4, G4) == 1, "RMB045 Endless Gallery : se detruit, une icone Thief de plus chez le joueur choisi")
	# RMB022 Minotaur Catacombs : se detruit, le heros de la salle repart du debut du donjon
	var mino := _room("RMB022")
	var p5 := _player(0, "BMA001", [_plain("A", "monster", [1], 1), mino], 0)
	var G5 := _G([p5, _player(1, "BMA002")])
	_adventure(G5, 0, _hero("RMB085"), 1, 6)
	_ok.call(_act(G5, 0, 1) == null and int(G5["adventure"]["roomIndex"]) == -1 and int(G5["adventure"]["hp"]) == 6 and (p5["dungeon"] as Array).size() == 1, "RMB022 Minotaur Catacombs : se detruit, le heros repart de la premiere salle (il garde ses PV)")
	var G5b := _G([_player(0, "BMA001", [_room("RMB022")]), _player(1, "BMA002")])
	_ok.call(_act(G5b, 0, 0) is String, "RMB022 : exige un heros dans la salle")

func _t_rooms_hero_dependent() -> void:
	# RMB043 Sawtooth Pendulum : 1 Coin pour tuer un heros de 3 PV ou moins dans cette salle
	var sw := _room("RMB043")
	var p0 := _player(0, "BMA001", [sw], 1)
	var G := _G([p0, _player(1, "BMA002")])
	_adventure(G, 0, _hero("RMB086"), 0, 4)
	_ok.call(_act(G, 0, 0) is String, "RMB043 : refuse au-dela de 3 PV")
	G["adventure"]["hp"] = 3
	_ok.call(_act(G, 0, 0) == null and int(G["adventure"]["hp"]) == 0 and _coins(G, 0) == 0, "RMB043 Sawtooth Pendulum : 1 Coin, le heros (3 PV) est tue")
	sw["usedThisTurn"] = false
	G["adventure"]["hp"] = 2
	_ok.call(_act(G, 0, 0) is String, "RMB043 : sans Coin, refuse")
	# RMB047 Living Trap : detruit une salle Monster de votre donjon pour tuer le heros de cette salle
	var lt := _room("RMB047")
	var mon := _plain("M", "monster", [1], 2)
	var p1 := _player(0, "BMA001", [lt, mon], 0)
	var G1 := _G([p1, _player(1, "BMA002")])
	var m1 := _match(G1)
	_adventure(G1, 0, _hero("RMB087"), 0, 9)
	_ok.call(m1.apply_move(0, {"type": "activateRoom", "args": [0]}), "RMB047 Living Trap : activee (coup activateRoom)")
	_ok.call((p1["dungeon"] as Array).size() == 1 and (G1["adventure"] as Dictionary).is_empty() and (p1["souls"] as Array).size() == 1, "RMB047 : la salle Monster est detruite, le heros est tue (une ame)")
	# RMB051 Lightning Rod : une fois par tour, +3 Coins quand un heros y meurt
	var rod := _room("RMB051")
	var p2 := _player(0, "BMA001", [rod], 0)
	var G2 := _G([p2, _player(1, "BMA002")])
	var m2 := _match(G2)
	var h1 := _hero("RMB088")
	_adventure(G2, 0, h1, 0, 0)
	m2._finish_hero(0, h1, 0, rod)
	var h2 := _hero("RMB089")
	_adventure(G2, 0, h2, 0, 0)
	m2._finish_hero(0, h2, 0, rod)
	_ok.call(_coins(G2, 0) == 3, "RMB051 Lightning Rod : +3 Coins, une seule fois par tour")
	# RMB034 Mind Thresher : une fois par tour, le heros qui meurt peut quitter la partie contre 2 sorts
	var mt := _room("RMB034")
	var p3 := _player(0, "BMA001", [mt], 0)
	var G3 := _G([p3, _player(1, "BMA002")])
	_fill(G3, "spells", 3, "spell")
	var m3 := _match(G3)
	var h3 := _hero("RMB090")
	_adventure(G3, 0, h3, 0, 0)
	m3._finish_hero(0, h3, 0, mt)
	_ok.call(str(_pending(G3).get("step", "")) == "rmb_mind" and bool(_pending(G3).get("optional", false)) and (p3["souls"] as Array).size() == 1, "RMB034 Mind Thresher : choix facultatif (l'ame est deja acquise)")
	m3._resolve_choice(0, 0)
	_ok.call((p3["souls"] as Array).is_empty() and _hand(G3, 0).size() == 2 and (G3["decks"]["removedHeroes"] as Array).has(h3), "RMB034 : le heros est retire du jeu (plus d'ame), 2 sorts pioches")
	var p3b := _player(0, "BMA001", [_room("RMB034")], 0)
	var G3b := _G([p3b, _player(1, "BMA002")])
	_fill(G3b, "spells", 3, "spell")
	var m3b := _match(G3b)
	var h3b := _hero("RMB091")
	_adventure(G3b, 0, h3b, 0, 0)
	m3b._finish_hero(0, h3b, 0, _top(G3b, 0, 0))
	m3b._resolve_choice(0, -1)
	_ok.call((p3b["souls"] as Array).size() == 1 and _hand(G3b, 0).is_empty(), "RMB034 : on peut refuser (l'ame reste)")
	# RMB030 Foyer Elemental : une fois par tour, +2 Coins quand un heros survit a cette salle
	var fe := _room("RMB030")
	var p4 := _player(0, "BMA001", [fe, _plain("B", "monster", [1], 1)], 0)
	var G4 := _G([p4, _player(1, "BMA002")])
	var m4 := _match(G4)
	var h4 := _hero("RMB092")
	(p4["entrance"] as Array).append(h4)
	G4["adventure"] = {"playerId": 0, "hero": h4, "roomIndex": 0, "hp": 5, "pause": null}
	m4._advance_adventure_room()
	_ok.call(_coins(G4, 0) == 2, "RMB030 Foyer Elemental : +2 Coins quand le heros survit et quitte la salle")
	G4["adventure"]["roomIndex"] = 0
	m4._advance_adventure_room()
	_ok.call(_coins(G4, 0) == 2, "RMB030 : une seule fois par tour")

func _t_rooms_discard_and_coin_costs() -> void:
	# RMB026 Training Camp : defausse un miniboss, double une salle Monster
	var camp := _room("RMB026")
	var big := _plain("M", "monster", [1], 3)
	var p0 := _player(0, "BMA001", [camp, big], 0)
	p0["hand"] = [_minicard("RMB056")]
	var G := _G([p0, _player(1, "BMA002")])
	var m := _match(G)
	_ok.call(_act(G, 0, 0) == null and str(_pending(G).get("step", "")) == "rmb_room" and (_pending(G)["options"] as Array).size() == 2, "RMB026 Training Camp : le miniboss est defausse, choix d'une salle Monster")
	var bi := 0
	for i in (_pending(G)["options"] as Array).size():
		if int(((_pending(G)["options"] as Array)[i] as Dictionary)["roomIndex"]) == 1:
			bi = i
	m._resolve_choice(0, bi)
	_ok.call(BossEngine.room_damage_with_modifiers(G, p0, 1, null) == 6 and _ids(_decks(G, "roomDiscard")).has("RMB056"), "RMB026 : degats de la salle doubles (3 -> 6)")
	_ok.call(_act(G, 0, 0) is String, "RMB026 : une fois par tour (et plus de miniboss)")
	var G0 := _G([_player(0, "BMA001", [_room("RMB026")]), _player(1, "BMA002")])
	_ok.call(_act(G0, 0, 0) is String, "RMB026 : refuse sans miniboss en main")
	# RMB044 The Catapult : defausse un miniboss, desactive une salle adverse
	var cat := _room("RMB044")
	var p1 := _player(0, "BMA001", [cat], 0)
	p1["hand"] = [_minicard("RMB057")]
	var p1o := _player(1, "BMA002", [_plain("V", "trap", [1], 4)])
	var G1 := _G([p1, p1o])
	_ok.call(_act(G1, 0, 0) == null and BossEngine.is_room_deactivated(G1, 1, 0) and BossEngine.room_damage_with_modifiers(G1, p1o, 0, null) == 0, "RMB044 The Catapult : miniboss defausse, la salle adverse est desactivee")
	# RMB054 Pool of Shadows : defausse un sort, +2 Coins
	var pool := _room("RMB054")
	var p2 := _player(0, "BMA001", [pool], 0)
	p2["hand"] = [_spl("S1"), _plain("R")]
	var G2 := _G([p2, _player(1, "BMA002")])
	_ok.call(_act(G2, 0, 0) == null and _coins(G2, 0) == 2 and _hand(G2, 0).size() == 1, "RMB054 Pool of Shadows : un sort defausse, +2 Coins")
	_ok.call(_act(G2, 0, 0) is String, "RMB054 : une fois par tour (et plus de sort)")

func _t_rooms_triggers() -> void:
	# RMB017 Imp Hoard : une fois par tour, la carte defaussee par un adversaire rejoint votre main
	var hoard := _room("RMB017")
	var p0 := _player(0, "BMA001", [hoard], 0)
	var p1 := _player(1, "BMA002")
	p1["hand"] = [_spl("S1"), _spl("S2"), _spl("S3")]
	var G := _G([p0, p1])
	RoomAbilities._discard_random_from(G, 1, true, "test", 0)
	_ok.call(_hand(G, 0).size() == 1 and _decks(G, "spellDiscard").is_empty() and _hand(G, 1).size() == 2, "RMB017 Imp Hoard : la carte defaussee par l'adversaire va dans votre main")
	RoomAbilities._discard_random_from(G, 1, true, "test", 0)
	_ok.call(_hand(G, 0).size() == 1 and _decks(G, "spellDiscard").size() == 1, "RMB017 : une seule fois par tour")
	hoard["usedThisTurn"] = false
	TnlAbilities.discard_from_hand(G, 0, _hand(G, 0)[0])
	_ok.call(_hand(G, 0).is_empty() and _decks(G, "spellDiscard").size() == 2, "RMB017 : vos propres defausses ne comptent pas")
	var chain := _G([_player(0, "BMA001", [_room("RMB017"), _room("RMB013")]), _player(1, "BMA002")])
	chain["players"][1]["hand"] = [_spl("FORCED")]
	_act(chain, 0, 1)
	_ok.call(_ids(_hand(chain, 0)).has("FORCED"), "RMB013 -> RMB017 : le sort force par Spectral Bomb est pris par l'Imp Hoard")
	# RMB041 Garbage Chute : une fois par tour, +2 Coins quand une salle est detruite (n'importe quel donjon)
	var chute := _room("RMB041")
	var p2 := _player(0, "BMA001", [chute], 0)
	var p2o := _player(1, "BMA002", [_plain("A"), _plain("B")])
	var G2 := _G([p2, p2o])
	BossEngine.destroy_room(p2o, 0, G2)
	BossEngine.destroy_room(p2o, 0, G2)
	_ok.call(_coins(G2, 0) == 2, "RMB041 Garbage Chute : +2 Coins, une seule fois par tour, meme pour la salle d'un adversaire")
	# RMB033 Black Market : une fois par tour, 1 Coin pour piocher un sort quand une salle est detruite (facultatif)
	var bm := _room("RMB033")
	var p3 := _player(0, "BMA001", [bm], 2)
	var p3o := _player(1, "BMA002", [_plain("A"), _plain("B")])
	var G3 := _G([p3, p3o])
	_fill(G3, "spells", 3, "spell")
	var m3 := _match(G3)
	BossEngine.destroy_room(p3o, 0, G3)
	_ok.call(str(_pending(G3).get("step", "")) == "rmb_yes" and bool(_pending(G3).get("optional", false)), "RMB033 Black Market : choix facultatif a la destruction d'une salle")
	m3._resolve_choice(0, 0)
	_ok.call(_coins(G3, 0) == 1 and _hand(G3, 0).size() == 1 and bool(bm["usedThisTurn"]), "RMB033 : 1 Coin paye, un sort pioche")
	BossEngine.destroy_room(p3o, 0, G3)
	_ok.call(_pending(G3).is_empty(), "RMB033 : une fois par tour")
	var p3c := _player(0, "BMA001", [_room("RMB033")], 0)
	var p3d := _player(1, "BMA002", [_plain("A")])
	var G3c := _G([p3c, p3d])
	_fill(G3c, "spells", 3, "spell")
	BossEngine.destroy_room(p3d, 0, G3c)
	_ok.call(_pending(G3c).is_empty(), "RMB033 : sans Coin, rien")
	# RMB049 Personnel Office : une fois par tour, +1 Coin quand un adversaire pose ou promeut un miniboss
	var po := _room("RMB049")
	var p4 := _player(0, "BMA001", [po], 0)
	var p4o := _player(1, "BMA002", [_with_mb(_plain("H"), "RMB055", 1, true)], 3)
	var G4 := _G([p4, p4o])
	_build_phase(G4)
	_match(G4)._reveal_and_level_up()
	_ok.call(_coins(G4, 0) == 1, "RMB049 Personnel Office : un adversaire revele un miniboss -> +1 Coin")
	(_top(G4, 1, 0)["mb"] as Dictionary)["since"] = 1
	_ok.call(Minibosses.apply_promote(G4, 1, 0, -1) and _coins(G4, 0) == 1, "RMB049 : une seule fois par tour (la promotion du meme tour ne rapporte plus)")
	po["usedThisTurn"] = false
	G4["effects"] = SpellEffects.empty_effects()
	Minibosses.apply_promote(G4, 1, 0, -1)
	_ok.call(_coins(G4, 0) == 2, "RMB049 : promotion d'un miniboss adverse -> +1 Coin")

func _t_rooms_hand_abilities() -> void:
	# RMB016 Tomb of Terrors : defausse depuis la main pour reprendre une salle ou un sort de la defausse
	var p0 := _player(0, "BMA001", [], 0)
	p0["hand"] = [_room("RMB016")]
	var G := _G([p0, _player(1, "BMA002")])
	var m := _match(G)
	_build_phase(G)
	_ok.call(_types(m.legal_moves(0), "rmbHand").is_empty(), "RMB016 : rien dans les defausses -> pas de coup")
	(G["decks"]["roomDiscard"] as Array).append(_plain("OLD1"))
	(G["decks"]["spellDiscard"] as Array).append(_spl("OLD2"))
	var mv := _types(m.legal_moves(0), "rmbHand")
	_ok.call(mv.size() == 1 and m.apply_move(0, mv[0]), "RMB016 Tomb of Terrors : capacite de main utilisable en construction")
	_ok.call(str(_pending(G).get("step", "")) == "take_discard" and (_pending(G)["options"] as Array).size() == 2, "RMB016 : choix parmi les defausses, sans la Tomb elle-meme")
	m._resolve_choice(0, 1)
	_ok.call(_ids(_hand(G, 0)) == ["OLD2"] and _ids(_decks(G, "roomDiscard")).has("RMB016"), "RMB016 : la carte choisie rejoint la main, la Tomb est defaussee")
	# RMB027 Shrooman Aviary : defausse depuis la main, un heros +3 jusqu'a la fin du tour
	var p1 := _player(0, "BMA001", [], 0)
	p1["hand"] = [_room("RMB027")]
	var G1 := _G([p1, _player(1, "BMA002")])
	var m1 := _match(G1)
	_build_phase(G1)
	_ok.call(_types(m1.legal_moves(0), "rmbHand").is_empty(), "RMB027 : sans heros, pas de coup")
	var th := _hero("RMB093")
	G1["town"] = [th]
	m1.apply_move(0, _types(m1.legal_moves(0), "rmbHand")[0])
	_ok.call(_hand(G1, 0).is_empty() and TnlAbilities.on_hero_start(G1, 0, th) == 3, "RMB027 Shrooman Aviary : un heros +3 PV a son entree dans un donjon")
	# RMB035 Cursed Well : un sort OU 2 Coins
	var p2 := _player(0, "BMA001", [], 0)
	p2["hand"] = [_room("RMB035"), _room("RMB035")]
	var G2 := _G([p2, _player(1, "BMA002")])
	var m2 := _match(G2)
	_build_phase(G2)
	_fill(G2, "spells", 2, "spell")
	var wells := _types(m2.legal_moves(0), "rmbHand")
	_ok.call(wells.size() == 4, "RMB035 Cursed Well : deux modes par carte (sort / Coins)")
	m2.apply_move(0, {"type": "rmbHand", "args": [0, "coins"]})
	_ok.call(_coins(G2, 0) == 2 and _hand(G2, 0).size() == 1, "RMB035 : mode Coins -> +2")
	m2.apply_move(0, {"type": "rmbHand", "args": [0, "spell"]})
	_ok.call(_coins(G2, 0) == 2 and _hand(G2, 0).size() == 1 and bool((_hand(G2, 0)[0] as Dictionary).get("isSpell", false)), "RMB035 : mode sort -> un sort pioche")

func _t_rooms_paywall_cavern_guardtower() -> void:
	# RMB046 Paywall : n'importe quel joueur peut donner des Coins ; -1 par Coin jusqu'a la fin du tour
	var wall := _room("RMB046")
	var p0 := _player(0, "BMA001", [wall], 0)
	var p1 := _player(1, "BMA002", [], 3)
	var G := _G([p0, p1])
	var m := _match(G)
	var pays := _types(m.legal_moves(1), "rmbPay")
	_ok.call(pays.size() == 1 and _types(m.legal_moves(0), "rmbPay").is_empty(), "RMB046 Paywall : un adversaire peut payer (pas le proprietaire)")
	m.apply_move(1, pays[0])
	m.apply_move(1, pays[0])
	_ok.call(_coins(G, 0) == 2 and _coins(G, 1) == 1 and BossEngine.room_damage_with_modifiers(G, p0, 0, null) == 2, "RMB046 : 2 Coins donnes, la salle perd 2 (4 -> 2)")
	G["effects"] = SpellEffects.empty_effects()
	for r in [wall]:
		r["dealDamage"] = 0 # la remise a zero de fin de tour (Match._start_turn)
	_ok.call(BossEngine.room_damage_with_modifiers(G, p0, 0, null) == 4, "RMB046 : malus remis a zero au tour suivant")
	# RMB019 Haunted Cavern : 1 Coin, un heros de l'entree ne peut pas entrer avant le tour suivant
	var cav := _room("RMB019")
	var p2 := _player(0, "BMA001", [cav, _plain("B")], 2)
	var G2 := _G([p2, _player(1, "BMA002")])
	var m2 := _match(G2)
	var ha := _hero("RMB094")
	var hb := _hero("RMB095")
	G2["phase"] = "adventure"
	G2["activePlayer"] = 0
	(p2["entrance"] as Array).append_array([ha, hb])
	_ok.call(_act(G2, 0, 0) == null and str(_pending(G2).get("step", "")) == "rmb_hero" and (_pending(G2)["options"] as Array).size() == 2, "RMB019 Haunted Cavern : 1 Coin, choix d'un heros de l'entree")
	m2._resolve_choice(0, 0)
	_ok.call(_coins(G2, 0) == 1 and Minibosses.hero_blocked(G2, ha) and not Minibosses.hero_blocked(G2, hb), "RMB019 : le heros designe est bloque")
	m2.apply_move(0, {"type": "adventureNext", "args": []})
	_ok.call(is_same(G2["adventure"]["hero"], hb), "RMB019 : l'autre heros entre en premier (le bloque reste a l'entree)")
	G2["adventure"] = {}
	(p2["entrance"] as Array).erase(hb)
	_ok.call(not m2._has_entrance_hero(0) and _types(m2.legal_moves(0), "adventureNext").is_empty(), "RMB019 : plus de heros libre -> aucun coup d'aventure")
	G2["effects"] = SpellEffects.empty_effects()
	_ok.call(m2._has_entrance_hero(0), "RMB019 : au tour suivant (effets remis a zero) il peut entrer")
	var G2b := _G([_player(0, "BMA001", [_room("RMB019")], 0), _player(1, "BMA002")])
	(G2b["players"][0]["entrance"] as Array).append(ha)
	_ok.call(_act(G2b, 0, 0) is String, "RMB019 : refuse sans Coin")

func _t_rooms_efreet_blackmarket() -> void:
	# RMB038 Efreet's Chamber : un heros a l'entree ; pioche un sort (-2) OU defausse un sort (+2)
	var ef := _room("RMB038")
	var p0 := _player(0, "BMA001", [ef], 0)
	p0["hand"] = [_spl("S1")]
	var G := _G([p0, _player(1, "BMA002")])
	_fill(G, "spells", 2, "spell")
	var m := _match(G)
	_ok.call(_act(G, 0, 0) is String, "RMB038 : exige un heros a l'entree")
	G["phase"] = "adventure"
	(p0["entrance"] as Array).append(_hero("RMB096"))
	_ok.call(_act(G, 0, 0) == null and (_pending(G)["options"] as Array).size() == 2, "RMB038 : deux options (piocher un sort / defausser S1)")
	m._resolve_choice(0, 0)
	_ok.call(_hand(G, 0).size() == 2 and BossEngine.room_damage_with_modifiers(G, p0, 0, null) == 0, "RMB038 : un sort pioche, la salle a -2 (2 - 2 = 0)")
	ef["usedThisTurn"] = false
	_act(G, 0, 0)
	var disc := 0
	for i in (_pending(G)["options"] as Array).size():
		if str(((_pending(G)["options"] as Array)[i] as Dictionary).get("mode", "")) == "discard":
			disc = i
	m._resolve_choice(0, disc)
	_ok.call(_hand(G, 0).size() == 1 and BossEngine.room_damage_with_modifiers(G, p0, 0, null) == 2, "RMB038 : un sort defausse, la salle a +2 (-2 + 2 + 2 = 2)")
	_ok.call(_act(G, 0, 0) is String, "RMB038 : une fois par tour")
	# le heros en cours dans le donjon n'est pas « a l'entree »
	var ef2 := _room("RMB038")
	var q0 := _player(0, "BMA001", [ef2], 0)
	var G2 := _G([q0, _player(1, "BMA002")])
	_fill(G2, "spells", 2, "spell")
	_adventure(G2, 0, _hero("RMB097"), 0, 8)
	_ok.call(_act(G2, 0, 0) is String, "RMB038 : le heros deja dans le donjon n'est pas a l'entree")

# --- les 15 sorts ---------------------------------------------------------------------------------------------------------------------

func _targets(G: Dictionary, pid: int, id: String) -> Array:
	return SpellTargeting.spell_targets_for(G, G["players"][pid], pid, id)

func _t_spell_phases_and_targets() -> void:
	var G := _G([_player(0, "BMA001", [_plain("A"), _with_mb(_plain("B"), "RMB055", 2)], 0), _player(1, "BMA002", [_with_mb(_plain("C", "trap", [1], 1), "RMB059", 1)], 3)])
	_ok.call(_targets(G, 0, "RMB065").size() == 1, "Windfall : jouable sans Coin en Hoard")
	G["players"][0]["coins"] = 1
	_ok.call(_targets(G, 0, "RMB065").is_empty(), "Windfall : injouable avec un Coin")
	_ok.call(_targets(G, 0, "RMB066").size() == 1 and _targets(G, 0, "RMB074").size() == 1 and _targets(G, 0, "RMB075").size() == 1, "Internship, Zoning Board, Respawn : sans cible")
	_ok.call(_targets(G, 0, "RMB067").size() == 3 and _targets(G, 0, "RMB076").size() == 3, "Spirit Dragon, Heist : n'importe quelle salle visible (3)")
	_ok.call(_targets(G, 0, "RMB069").size() == 2, "Rage! : un coup par miniboss en jeu (le sien et celui de l'adversaire)")
	_ok.call(_targets(G, 0, "RMB071").size() == 2, "Rebirth : n'importe quel joueur, vous compris")
	var sab := _targets(G, 0, "RMB068")
	_ok.call(sab.size() == 3 and sab.all(func(t): return str((t as Dictionary)["mode"]) == "text"), "Sabotage! : sans plus de minibosses que le proprietaire (1 contre 1), seulement « sans texte »")
	G["players"][1]["dungeon"] = [[_plain("C", "trap", [1], 1)]]
	var sab2 := _targets(G, 0, "RMB068")
	_ok.call(sab2.size() == 4 and sab2.filter(func(t): return str((t as Dictionary)["mode"]) == "deactivate").size() == 1, "Sabotage! : plus de minibosses que le proprietaire de la salle (1 contre 0) -> « desactivee » aussi")
	_ok.call(_targets(G, 0, "RMB070").is_empty() and _targets(G, 0, "RMB072").is_empty(), "Ambush, Smash! : aucun heros dans votre donjon")
	_adventure(G, 0, _hero("RMB098"), 0, 6)
	_ok.call(_targets(G, 0, "RMB072").size() == 1 and _targets(G, 0, "RMB070").is_empty(), "Smash! : 2 degats au heros du donjon ; Ambush : sans salles Monster en main, injouable")
	G["players"][0]["hand"] = [_plain("M1", "monster"), _plain("M2", "monster")]
	_ok.call(_targets(G, 0, "RMB070").size() == 1, "Ambush : deux salles Monster en main suffisent")
	(G["players"][0]["dungeon"] as Array)[0] = [_with_mb(_plain("A"), "RMB056", 1)]
	_ok.call(_targets(G, 0, "RMB072").size() == 2, "Smash! : heros dans une salle avec miniboss -> aussi 4 degats")
	G["players"][0]["coins"] = 2
	_ok.call(_targets(G, 0, "RMB073").size() == 2 * 3, "Pay to Win : vos 2 salles x 0, 1 ou 2 Coins payes")
	_ok.call(_targets(G, 0, "RMB079").size() == 1 * 3, "Armor Up! : le heros x 0, 1 ou 2 Coins")
	_ok.call(_targets(G, 0, "RMB077").is_empty() and _targets(G, 0, "RMB078").is_empty(), "Short Circuit, Traitor : rien a cibler")
	G["players"][1]["dungeon"] = [[_with_mb(_plain("D"), "RMB058", 2)]]
	G["players"][0]["coins"] = 1
	_ok.call(_targets(G, 0, "RMB078").is_empty(), "Traitor : pas assez de Coins pour un miniboss de niveau 2")
	G["players"][0]["coins"] = 2
	G["players"][0]["dungeon"] = [[_plain("A0")], [_plain("FREE")]]
	_ok.call(_targets(G, 0, "RMB078").size() == 1, "Traitor : un miniboss adverse de niveau 2 pour 2 Coins")
	(G["effects"] as Dictionary)["noRoomBuild"] = [0]
	_ok.call(_targets(G, 0, "RMB078").is_empty(), "Traitor : une fois la construction interdite, plus de cible")

func _cast(G: Dictionary, caster: int, id: String, t: Dictionary = {}) -> bool:
	return SpellEffects.cast_spell(G, caster, _spell(id), t)

func _t_spells_economy() -> void:
	# RMB065 Windfall
	var G := _G([_player(0, "BMA001", [], 0), _player(1, "BMA002")])
	_ok.call(_cast(G, 0, "RMB065") and _coins(G, 0) == 3, "RMB065 Windfall : sans Coin, 3 Coins")
	_ok.call(not _cast(G, 0, "RMB065") and _coins(G, 0) == 3, "Windfall : sans effet avec des Coins")
	# RMB073 Pay to Win : +1, et +1 par Coin paye au lancement
	var room := _plain("A", "monster", [1], 2)
	var G2 := _G([_player(0, "BMA001", [room], 3), _player(1, "BMA002")])
	_ok.call(_cast(G2, 0, "RMB073", {"targetPlayerId": 0, "roomIndex": 0, "pay": 2}) and _coins(G2, 0) == 1 and BossEngine.room_damage_with_modifiers(G2, G2["players"][0], 0, null) == 2 + 3, "RMB073 Pay to Win : 2 Coins payes -> +3")
	_cast(G2, 0, "RMB073", {"targetPlayerId": 0, "roomIndex": 0, "pay": 0})
	_ok.call(BossEngine.room_damage_with_modifiers(G2, G2["players"][0], 0, null) == 2 + 4, "RMB073 : sans Coin paye -> +1")
	# RMB079 Armor Up! : +1 a un heros et +2 par Coin
	var h := _hero("RMB099")
	var G3 := _G([_player(0, "BMA001", [], 2), _player(1, "BMA002")])
	G3["town"] = [h]
	_ok.call(_cast(G3, 0, "RMB079", {"heroId": h["id"], "pay": 2}) and _coins(G3, 0) == 0 and TnlAbilities.on_hero_start(G3, 0, h) == 5, "RMB079 Armor Up! : 2 Coins -> +1 +4 = +5 PV")
	# RMB071 Rebirth : defausse la main et repioche autant de salles et de sorts
	var p4 := _player(1, "BMA002")
	p4["hand"] = [_spl("S1"), _plain("R1"), _minicard("RMB055")]
	var G4 := _G([_player(0, "BMA001"), p4])
	_fill(G4, "rooms", 4)
	_fill(G4, "spells", 3, "spell")
	_ok.call(_cast(G4, 0, "RMB071", {"targetPlayerId": 1}), "RMB071 Rebirth : lance")
	var rooms_in := (p4["hand"] as Array).filter(func(c): return bool((c as Dictionary).get("isRoom", false))).size()
	_ok.call(_hand(G4, 1).size() == 3 and rooms_in == 2 and _decks(G4, "roomDiscard").size() == 2 and _decks(G4, "spellDiscard").size() == 1, "Rebirth : 2 salles (le miniboss compte) + 1 sort rediscarded et repioches")
	var G4b := _G([_player(0, "BMA001"), _player(1, "BMA002")])
	G4b["players"][0]["hand"] = [_spl("MINE")]
	_fill(G4b, "spells", 2, "spell")
	_cast(G4b, 0, "RMB071", {"targetPlayerId": 0})
	_ok.call(_hand(G4b, 0).size() == 1 and _ids(_hand(G4b, 0)) != ["MINE"], "Rebirth sur soi-meme : un nouveau sort")

func _t_spells_rooms() -> void:
	# RMB067 Spirit Dragon : un tresor de chaque type a la place de ses icones
	var r := _plain("A", "monster", [3], 2)
	var p0 := _player(0, "BMA001", [r], 0)
	p0["boss"]["treasures"] = []
	var G := _G([p0, _player(1, "BMA002")])
	_ok.call(_cast(G, 0, "RMB067", {"targetPlayerId": 0, "roomIndex": 0}) and BossEngine.room_treasures(r) == [1, 2, 3, 4], "RMB067 Spirit Dragon : un de chaque type")
	# RMB076 Heist : la salle perd ses icones jusqu'a la fin du tour
	var r2 := _plain("B", "monster", [1, 2], 2)
	var G2 := _G([_player(0, "BMA001", [r2], 0), _player(1, "BMA002")])
	_ok.call(_cast(G2, 0, "RMB076", {"targetPlayerId": 0, "roomIndex": 0}) and BossEngine.room_treasures(r2).is_empty(), "RMB076 Heist : la salle n'a plus d'icone de tresor")
	# RMB068 Sabotage! : sans texte (une salle RMB ne s'active plus), ou desactivee quand on a plus de minibosses
	var pool := _room("RMB054")
	var p3 := _player(0, "BMA001", [pool, _with_mb(_plain("M"), "RMB055", 1)], 0)
	p3["hand"] = [_spl("S")]
	var G3 := _G([p3, _player(1, "BMA002", [_plain("T")])])
	_ok.call(_cast(G3, 0, "RMB068", {"mode": "text", "targetPlayerId": 0, "roomIndex": 0}) and _act(G3, 0, 0) is String, "RMB068 Sabotage! : la salle n'a plus de texte, sa capacite est refusee")
	_ok.call(_cast(G3, 0, "RMB068", {"mode": "deactivate", "targetPlayerId": 1, "roomIndex": 0}) and BossEngine.is_room_deactivated(G3, 1, 0), "RMB068 : plus de minibosses que l'adversaire -> salle desactivee")
	_ok.call(not _cast(G3, 0, "RMB068", {"mode": "deactivate", "targetPlayerId": 0, "roomIndex": 1}), "RMB068 : pas de desactivation sans avantage de minibosses")
	# RMB074 Zoning Board : une salle avancee par-dessus n'importe quelle salle ce tour
	var host := _plain("H", "monster", [1], 2)
	var p4 := _player(0, "BMA001", [host], 0)
	p4["hand"] = [_plain("ADV", "trap", [4], 3, true)]
	var G4 := _G([p4, _player(1, "BMA002")])
	_build_phase(G4)
	_ok.call(not BossEngine.can_build_room(p4, G4, 0, 0, 0), "avant Zoning Board : icone commune exigee")
	_cast(G4, 0, "RMB074")
	_ok.call(BossEngine.can_build_room(p4, G4, 0, 0, 0), "RMB074 Zoning Board : sans condition de tresor, ce tour")
	# RMB075 Respawn : toutes vos salles sont traitees comme venant d'etre construites
	var dq := _room("RMB040")
	var p5 := _player(0, "RMB004", [dq, _plain("M", "monster")], 0)
	p5["rmbBoss"] = {"RMB004": true}
	var G5 := _G([p5, _player(1, "BMA002")])
	_fill(G5, "rooms", 3)
	_ok.call(_cast(G5, 0, "RMB075") and _hand(G5, 0).size() == 1 and _coins(G5, 0) == 1, "RMB075 Respawn : Delver's Quarry repioche, Lamia gagne un Coin pour la salle Monster")
	# RMB066 Internship : 3 salles en defausse ; un miniboss parmi elles peut etre construit tout de suite
	var host2 := _plain("H2")
	var p6 := _player(0, "BMA001", [host2], 0)
	var G6 := _G([p6, _player(1, "BMA002")])
	(G6["decks"]["rooms"] as Array).append_array([_plain("X1"), _minicard("RMB059"), _plain("X2")])
	var m6 := _match(G6)
	_ok.call(_cast(G6, 0, "RMB066") and _decks(G6, "roomDiscard").size() == 3 and (_decks(G6, "rooms") as Array).is_empty(), "RMB066 Internship : les 3 premieres salles vont en defausse")
	_ok.call(str(_pending(G6).get("step", "")) == "rmb_sp_intern" and bool(_pending(G6).get("optional", false)), "Internship : un miniboss parmi elles -> construction immediate facultative")
	m6._resolve_choice(0, 0)
	_ok.call(host2.has("mb") and bool((host2["mb"] as Dictionary)["faceDown"]) and _decks(G6, "roomDiscard").size() == 2 and int(p6["buildsThisTurn"]) == 0, "Internship : miniboss pose face cachee en plus de la construction normale")
	var G6b := _G([_player(0, "BMA001", [_plain("H3")], 0), _player(1, "BMA002")])
	(G6b["decks"]["rooms"] as Array).append_array([_plain("Y1"), _plain("Y2"), _plain("Y3")])
	_cast(G6b, 0, "RMB066")
	_ok.call(_pending(G6b).is_empty() and _decks(G6b, "roomDiscard").size() == 3, "Internship : sans miniboss, rien d'autre")

func _t_spells_heroes() -> void:
	# RMB069 Rage! : +1 par niveau a la salle du miniboss ; seul miniboss -> degats doubles
	var room := _with_mb(_plain("A", "monster", [1], 2), "RMB055", 2)
	var G := _G([_player(0, "BMA001", [room], 0), _player(1, "BMA002")])
	_ok.call(_cast(G, 0, "RMB069", {"targetPlayerId": 0, "roomIndex": 0}), "RMB069 Rage! : lance")
	# base 2 + Spike niveau 1 (+1) + Rage (+2) = 5, puis doublement : +5 = 10
	_ok.call(BossEngine.room_damage_with_modifiers(G, G["players"][0], 0, null) == 10, "Rage! : +niveau (2) puis, avec un seul miniboss, degats doubles (5 -> 10)")
	var r1 := _with_mb(_plain("A", "monster", [1], 2), "RMB055", 2)
	var r2 := _with_mb(_plain("B", "monster", [1], 2), "RMB056", 1)
	var G2 := _G([_player(0, "BMA001", [r1, r2], 0), _player(1, "BMA002")])
	_cast(G2, 0, "RMB069", {"targetPlayerId": 0, "roomIndex": 0})
	_ok.call(BossEngine.room_damage_with_modifiers(G2, G2["players"][0], 0, null) == 5, "Rage! avec deux minibosses : +niveau seulement (5)")
	# RMB072 Smash!
	var G3 := _G([_player(0, "BMA001", [_plain("A")], 0), _player(1, "BMA002")])
	_adventure(G3, 0, _hero("RMB100"), 0, 8)
	var hid: String = str(G3["adventure"]["hero"]["id"])
	_ok.call(_cast(G3, 0, "RMB072", {"mode": "own", "heroId": hid}) and int(G3["adventure"]["hp"]) == 6, "RMB072 Smash! : 2 degats au heros de votre donjon")
	_ok.call(not _cast(G3, 0, "RMB072", {"mode": "mb", "heroId": hid, "targetPlayerId": 0}), "Smash! : 4 degats seulement si la salle du heros contient un miniboss")
	var G4 := _G([_player(0, "BMA001", [_plain("A")], 0), _player(1, "BMA002", [_with_mb(_plain("B"), "RMB057", 1)])])
	_adventure(G4, 1, _hero("RMB101"), 0, 9)
	_ok.call(_cast(G4, 0, "RMB072", {"mode": "mb", "heroId": str(G4["adventure"]["hero"]["id"]), "targetPlayerId": 1}) and int(G4["adventure"]["hp"]) == 5, "Smash! : 4 degats a un heros dans la salle d'un miniboss, meme chez un adversaire")
	# RMB070 Ambush : deux salles Monster OU un miniboss defaussees, tue le heros de votre donjon
	var p5 := _player(0, "BMA001", [_plain("A")], 0)
	p5["hand"] = [_plain("M1", "monster"), _plain("M2", "monster"), _minicard("RMB057"), _plain("T", "trap")]
	var G5 := _G([p5, _player(1, "BMA002")])
	var m5 := _match(G5)
	_adventure(G5, 0, _hero("RMB102"), 0, 9)
	var costs := RmbSpells.ambush_costs(p5)
	_ok.call(costs.size() == 2, "RMB070 Ambush : deux couts possibles (les 2 salles Monster, ou le miniboss)")
	_ok.call(_cast(G5, 0, "RMB070", {"heroId": str(G5["adventure"]["hero"]["id"])}) and str(_pending(G5).get("step", "")) == "rmb_sp_ambush", "Ambush : choix du cout")
	m5._resolve_choice(0, 1)
	_ok.call(int(G5["adventure"]["hp"]) == 0 and _hand(G5, 0).size() == 3 and _ids(_decks(G5, "roomDiscard")).has("RMB057"), "Ambush : un miniboss defausse, le heros meurt (hp 0)")
	# l'ordre de resolution passe par la pile : le heros est ensuite tue par Match._finish_hero_if_dead
	m5._finish_hero_if_dead()
	_ok.call((G5["adventure"] as Dictionary).is_empty() and (p5["souls"] as Array).size() == 1, "Ambush : le heros tue donne une ame")

func _t_spells_stack_and_traitor() -> void:
	# RMB077 Short Circuit : jusqu'a la fin du tour, l'adversaire paie 1 Coin par sort, sinon le sort est annule
	for coins in [1, 0]:
		var p0 := _player(0, "BMA001", [], 0)
		p0["hand"] = [_spell("RMB077")]
		var p1 := _player(1, "BMA002", [_plain("T")], coins)
		p1["hand"] = [_spell("RMB074")] # Zoning Board : ignoreTreasureMatch pour son lanceur
		var G := _G([p0, p1])
		_build_phase(G)
		var m := _match(G)
		_ok.call(_types(m.legal_moves(0), "playSpell").is_empty(), "Short Circuit : injouable sans sort adverse sur la pile")
		var play1 := _types(m.legal_moves(1), "playSpell")
		_ok.call(play1.size() == 1 and m.apply_move(1, play1[0]), "l'adversaire lance un sort (Zoning Board)")
		var sc := _types(m.legal_moves(0), "playSpell")
		_ok.call(sc.size() == 1 and str(((sc[0] as Dictionary)["args"][1] as Dictionary)) == str({"targetPlayerId": 1}) and m.apply_move(0, sc[0]), "Short Circuit : joue contre l'adversaire dont le sort attend")
		m.apply_move(1, {"type": "pass", "args": []})
		var ignored: bool = (G["effects"]["ignoreTreasureMatch"] as Array).has(1)
		_ok.call(ignored == (coins == 1) and _coins(G, 1) == 0, "Short Circuit : %s -> le sort adverse %s" % ["1 Coin" if coins == 1 else "aucun Coin", "est paye et resolu" if coins == 1 else "est annule"])
	# RMB078 Traitor : paie (niveau) Coins au proprietaire, prend son miniboss a ce niveau, plus de salle ce tour
	var theirs := _with_mb(_plain("T1"), "RMB058", 2)
	var mine := _plain("M1")
	var p2 := _player(0, "BMA001", [mine], 3)
	var G2 := _G([p2, _player(1, "BMA002", [theirs], 0)])
	_build_phase(G2)
	_ok.call(_cast(G2, 0, "RMB078", {"targetPlayerId": 1, "roomIndex": 0}), "RMB078 Traitor : lance")
	_ok.call(not theirs.has("mb") and mine.has("mb") and int((mine["mb"] as Dictionary)["level"]) == 2 and not bool((mine["mb"] as Dictionary)["faceDown"]), "Traitor : le miniboss passe chez vous, au meme niveau, revele")
	_ok.call(_coins(G2, 0) == 1 and _coins(G2, 1) == 2, "Traitor : 2 Coins (niveau 2) payes au proprietaire")
	p2["hand"] = [_plain("R")]
	_ok.call(not BossEngine.can_build_room(p2, G2, 0, 0, -1), "Traitor : plus de construction de salle ce tour")
	# plusieurs salles d'accueil : choix
	var p3 := _player(0, "BMA001", [_plain("A"), _plain("B")], 3)
	var G3 := _G([p3, _player(1, "BMA002", [_with_mb(_plain("T2"), "RMB059", 1)], 0)])
	var m3 := _match(G3)
	_cast(G3, 0, "RMB078", {"targetPlayerId": 1, "roomIndex": 0})
	_ok.call(str(_pending(G3).get("step", "")) == "rmb_sp_traitor" and (_pending(G3)["options"] as Array).size() == 2, "Traitor : choix de la salle qui recoit le miniboss")
	m3._resolve_choice(0, 1)
	_ok.call(_top(G3, 0, 1).has("mb") and _coins(G3, 0) == 2, "Traitor : le miniboss est pose sur la salle choisie")

# --- heros, etat, interface, IA ----------------------------------------------------------------------------------------------------------

func _t_heroes() -> void:
	var heroes: Array = CardDB.heroes.filter(func(c): return str((c as Dictionary).get("id", "")).begins_with("RMB"))
	var ordinary := heroes.filter(func(c): return not bool((c as Dictionary).get("epic", false)))
	var epic := heroes.filter(func(c): return bool((c as Dictionary).get("epic", false)))
	_ok.call(ordinary.size() == 25 and epic.size() == 17, "42 heros RMB : 24 ordinaires + le Fool, 17 epiques")
	var full := true
	for h in heroes:
		var hd: Dictionary = h
		full = full and int(hd.get("hp", 0)) > 0 and int(hd.get("souls", 0)) == (2 if bool(hd.get("epic", false)) else 1) and int(hd.get("wounds", 0)) == int(hd.get("souls", 0))
	_ok.call(full, "heros RMB : PV, ames et blessures complets")
	# The Fool : lure par le moins d'ames ; heros hybrides : tresors cumules
	var fool := _hero("RMB104")
	_ok.call(CardDB.hero_lure(fool) == "fewerSouls" and int(fool["hp"]) == 2, "RMB104 The Fool : lure par le moins d'ames, 2 PV")
	var a := _player(0, "BMA001", [], 0)
	var b := _player(1, "BMA002", [], 0)
	(a["souls"] as Array).append(CardDB.soul_entry(_hero("RMB080")))
	var G := _G([a, b])
	_ok.call(BossEngine.lure_target(G["players"], [0, 1], 0, fool, G) == 1, "The Fool va chez le joueur qui a le moins d'ames")
	var pal := _hero("RMB107")
	var c := _player(0, "BMA001", [_plain("X", "monster", [1], 1), _plain("Y", "monster", [2], 1)], 0)
	c["boss"]["treasures"] = []
	var d := _player(1, "BMA002", [_plain("Z", "monster", [1], 1)], 0)
	d["boss"]["treasures"] = []
	var G2 := _G([c, d])
	_ok.call(BossEngine.lure_target(G2["players"], [0, 1], 1, pal, G2) == 0, "RMB107 Paladin (Cleric + Fighter) : somme des deux tresors")
	# heros noirs : l'adversaire paie une salle au tresor du heros pour +3 PV
	var dark := _hero("RMB084")
	_ok.call(str((dark["heroAbility"] as Dictionary)["cmd"]) == "DarkHeroPay" and bool(dark["dark"]), "RMB084 Inquisitor : heros noir (capacite DarkHeroPay)")
	var p0 := _player(0, "BMA001", [_plain("A")], 0)
	var p1 := _player(1, "BMA002", [_plain("B")], 0)
	p0["hand"] = [_plain("PAY", "monster", [1], 1), _plain("NOPE", "monster", [2], 1)]
	(p1["entrance"] as Array).append(dark)
	var G3 := _G([p0, p1])
	G3["phase"] = "adventure"
	G3["activePlayer"] = 1
	var m3 := _match(G3)
	var pays := _types(m3.legal_moves(0), "payDarkHero")
	_ok.call(pays.size() == 1 and m3.apply_move(0, pays[0]), "heros noirs RMB : l'adversaire paie une salle au tresor du heros (Cleric)")
	_ok.call(TnlAbilities.on_hero_start(G3, 1, dark) == 3 and _hand(G3, 0).size() == 1, "heros noir : +3 PV a l'entree dans le donjon, la salle est defaussee")
	# Icicle Man ou Cerebella : le texte du heros noir est ignore
	var G4 := _G([_player(0, "BMA001", [_with_mb(_plain("C"), "RMB061", 2)], 0), _player(1, "BMA002", [_plain("D")], 0)])
	G4["phase"] = "adventure"
	(G4["players"][1]["entrance"] as Array).append(_hero("RMB090"))
	(G4["players"][0]["hand"] as Array).append(_plain("PAY", "monster", [2], 1))
	_ok.call(_types(_match(G4).legal_moves(0), "payDarkHero").size() == 1, "controle : le heros noir de l'adversaire est payable")
	(G4["players"][1]["dungeon"] as Array)[0] = [_with_mb(_plain("D"), "RMB061", 2)]
	_ok.call(_types(_match(G4).legal_moves(0), "payDarkHero").is_empty(), "Icicle Man niveau 2 chez le defenseur : le texte du heros noir est ignore, rien a payer")

func _t_state_roundtrip() -> void:
	# L'etat circule en JSON (sauvegarde, reseau) : les minibosses, Coins et sacs d'effets survivent a l'aller-retour.
	var room := _with_mb(_plain("A"), "RMB056", 2)
	var p0 := _player(0, "BMA001", [room], 4)
	var G := _G([p0, _player(1, "BMA002")])
	Minibosses.mark_used(G, 0, "promote")
	var back = JSON.parse_string(JSON.stringify(G))
	var bp: Dictionary = back["players"]["0"]
	var top = BossEngine.active_room((bp["dungeon"] as Array)[0])
	var m := Minibosses.revealed(top)
	_ok.call(Minibosses.mb_id(m) == "RMB056" and Minibosses.level(m) == 2 and int(bp["coins"]) == 4 and bool((back["effects"]["rmb"]["used"] as Dictionary)["0:promote"]), "aller-retour JSON : miniboss, niveau, Coins et sac d'effets conserves")
	_ok.call(BossEngine.room_treasures(top as Dictionary).has(2), "aller-retour JSON : l'icone du miniboss compte toujours")

func _t_ui_labels_and_menu() -> void:
	var G := _G([_player(0, "BMA001", [_with_mb(_plain("A"), "RMB055", 2), _plain("B")]), _player(1, "BMA002", [_plain("C")])])
	G["activePlayer"] = 0
	for t in [{}, {"targetPlayerId": 1, "roomIndex": 0}, {"targetPlayerId": 1, "roomIndex": 0, "pay": 2}, {"heroId": "x", "pay": 1}, {"mode": "deactivate", "targetPlayerId": 0, "roomIndex": 0}]:
		_ok.call(RmbSpells.describe_target(G, t) is String, "libelle de cible RMB %s" % str(t))
	var script: GDScript = load("res://godot/scripts/Main.gd")
	var decks: Array = script.get_script_constant_map()["APK_DECKS"]
	var pack: Dictionary = {}
	for d in decks:
		if str((d as Dictionary)["id"]) == "minibosses":
			pack = d
	_ok.call(not pack.is_empty() and bool(pack["playable"]), "menu : MINIBOSSES est une extension cochable (ecran SELECT EXPANSIONS)")
	_ok.call((script.get_script_constant_map()["EXT_PACKS"] as Array).has("minibosses"), "menu : la bascule « Extensions du wiki » inclut toujours MINIBOSSES")
	var room: Dictionary = _top(G, 0, 0)
	_ok.call(Minibosses.badge_text(room, false) == "Spike  L2" and Minibosses.badge_text(_top(G, 0, 1), true) == "", "badge de salle : nom et niveau du miniboss, rien sans miniboss")
	(room["mb"] as Dictionary)["faceDown"] = true
	_ok.call(Minibosses.badge_text(room, false) == "MINIBOSS (face-down)" and Minibosses.badge_text(room, true).contains("Spike"), "badge : le nom d'un miniboss face cache n'est montre qu'a son proprietaire")
	var lbl := Minibosses.make_badge(room, true)
	_ok.call(lbl != null and lbl.tooltip_text.contains("L1") and lbl.tooltip_text.contains("L3"), "badge : infobulle avec les trois niveaux")
	if lbl != null:
		lbl.free()
	var ui = load("res://godot/scripts/BoardUI.gd").new()
	var hand: Array = [_minicard("RMB056")]
	var lab := {"build": str(ui._move_label({"type": "buildMiniboss", "args": [0, 0]}, G, hand)), "promote": str(ui._move_label({"type": "promoteMiniboss", "args": [0, -1]}, G, hand)),
		"act": str(ui._move_label({"type": "activateMiniboss", "args": [0, 3]}, G, hand)), "coin": str(ui._move_label({"type": "discardForCoin", "args": [0]}, G, hand))}
	_ok.call(str(lab["build"]).contains("Kid Croak") and str(lab["promote"]).contains("Spike") and str(lab["act"]).contains("LEVEL 3") and str(lab["coin"]).contains("Kid Croak"), "libelles des coups RMB : miniboss, salle et niveau nommes (%s)" % str(lab))
	ui.free()

# --- soaks IA-vs-IA (deterministes : soak_seed.gd) -------------------------------------------------------------------------------------------

const SOAK_MAX_STEPS := 4000

func _rmb_card(c) -> bool:
	return str((c as Dictionary).get("set", "")) == "minibosses"

## Paquets 100 % RMB (x3 pour ne pas manquer de cartes) : chaque partie joue beaucoup de salles, de sorts et de minibosses.
func _rmb_only_decks(m: Node) -> void:
	for pile in ["rooms", "spells"]:
		var only: Array = (m.G["decks"][pile] as Array).filter(_rmb_card)
		var deck: Array = []
		for _k in 3:
			for c in only:
				deck.append((c as Dictionary).duplicate())
		m.G["decks"][pile] = CardDB.shuffled(deck)

func _t_ai_soak_rmb() -> void:
	var names := {}
	for c in CardDB.rooms + CardDB.spells + CardDB.bosses + CardDB.minibosses:
		if _rmb_card(c):
			names[str((c as Dictionary)["name"])] = 0
	var finished := 0
	var games := 0
	var promoted := 0
	var revealed := 0
	for n in [2, 2, 2, 2, 3, 3, 3, 3, 4, 4, 4, 4]:
		games += 1
		var m = load("res://godot/scripts/Match.gd").new()
		host.add_child(m)
		load("res://godot/tests/soak_seed.gd").seed_game(m, 1000 + games)
		m.new_match(n, 0, ["minibosses"])
		_rmb_only_decks(m)
		m.G["bossPicks"] = CardDB.shuffled(CardDB.bosses.filter(_rmb_card)).slice(0, n + 2)
		if _play_soak(m):
			finished += 1
		for key in ["logs", "log"]:
			for line in (m.G.get(key, []) as Array):
				for nm in names:
					if str(line).contains(nm):
						names[nm] = int(names[nm]) + 1
				promoted += 1 if str(line).contains("is promoted to level") else 0
				revealed += 1 if str(line).contains("is revealed (level") else 0
		m.queue_free()
	load("res://godot/tests/soak_seed.gd").unseed()
	_ok.call(finished == games, "soak RMB : %d/%d parties IA-vs-IA terminees (pas de blocage)" % [finished, games])
	var touched := 0
	var missing: Array = []
	for nm in names:
		if int(names[nm]) > 0:
			touched += 1
		else:
			missing.append(nm)
	print("SOAK-RMB cartes RMB vues dans les journaux : ", touched, "/", names.size(), " non vues : ", missing, " minibosses reveles=", revealed, " promotions=", promoted)
	_ok.call(touched >= 30, "soak RMB : au moins 30 cartes RMB differentes jouees (%d)" % touched)
	_ok.call(revealed >= 10 and promoted >= 3, "soak RMB : des minibosses sont reveles (%d) et promus (%d)" % [revealed, promoted])

## Chaque boss RMB joue une partie IA-vs-IA (joueur 0) : level-ups et pouvoirs de boss atteints, sans blocage ni erreur.
func _t_ai_soak_each_boss() -> void:
	var bosses: Array = CardDB.bosses.filter(_rmb_card)
	var finished := 0
	var leveled := 0
	for k in bosses.size():
		var m = load("res://godot/scripts/Match.gd").new()
		host.add_child(m)
		load("res://godot/tests/soak_seed.gd").seed_game(m, 3000 + k)
		m.new_match(2, 0, ["minibosses"])
		m.G["bossPicks"] = [bosses[k], bosses[(k + 1) % bosses.size()]]
		_rmb_only_decks(m)
		if _play_soak(m):
			finished += 1
		if bool((m.G["players"][0] as Dictionary).get("leveledUp", false)):
			leveled += 1
		m.queue_free()
	load("res://godot/tests/soak_seed.gd").unseed()
	_ok.call(finished == bosses.size(), "soak RMB (un boss RMB par partie) : %d/%d parties terminees" % [finished, bosses.size()])
	print("SOAK-RMB bosses RMB montes de niveau : ", leveled, "/", bosses.size())
	_ok.call(leveled >= 5, "soak RMB : au moins 5 level-ups de boss RMB atteints (%d)" % leveled)

## Tous les paquets ensemble (APK + TNL + CRL + RMB) : pas de blocage ni d'erreur de script.
func _t_ai_soak_all_packs() -> void:
	var finished := 0
	var games := 0
	var rmb_seen := 0
	for n in [2, 2, 3, 3, 4, 4]:
		games += 1
		var m = load("res://godot/scripts/Match.gd").new()
		host.add_child(m)
		load("res://godot/tests/soak_seed.gd").seed_game(m, 7000 + games)
		m.new_match(n, 0, ["players-choice", "hidden-heroes", "tools", "next-level", "crash-landing", "minibosses"])
		if _play_soak(m):
			finished += 1
		for line in (m.G.get("logs", []) as Array):
			rmb_seen += 1 if str(line).contains("Coin") else 0
		m.queue_free()
	load("res://godot/tests/soak_seed.gd").unseed()
	_ok.call(finished == games, "soak tous paquets (APK + TNL + CRL + RMB) : %d/%d parties terminees" % [finished, games])
	_ok.call(rmb_seen > 0, "soak tous paquets : des Coins circulent (%d lignes)" % rmb_seen)

func _play_soak(m: Node) -> bool:
	var steps := 0
	while m.G.get("gameOver") == null and steps < SOAK_MAX_STEPS:
		var acted := false
		var phase: String = m.G["phase"]
		var pc: Dictionary = m.G.get("pendingChoice", {})
		if not pc.is_empty():
			var owner := int(pc.get("playerId", 0))
			var cmoves: Array = m.legal_moves(owner)
			if not cmoves.is_empty():
				var cm = AI.pick_move(m, owner)
				m.apply_move(owner, cm if cm != null else cmoves[0])
				steps += 1
				continue
		if phase == "boss":
			for pid in m.G["players"]:
				var moves: Array = m.legal_moves(int(pid))
				if not moves.is_empty():
					m.apply_move(int(pid), moves[0])
					acted = true
					break
		elif phase == "build":
			acted = true # Match._drive_ai() fait jouer le joueur actif
		elif phase == "adventure":
			var ap: int = m.active_player()
			var moves2: Array = m.legal_moves(ap)
			var mv = null
			if not moves2.is_empty():
				mv = AI.pick_move(m, ap)
				if mv == null:
					mv = moves2[0]
				# un coup que l'IA juge nocif (score < 0) n'est joue qu'en dernier recours : on laisse d'abord passer ceux qui le peuvent
				if AI.score_move(m, ap, mv) >= 0.0:
					acted = m.apply_move(ap, mv)
			if not acted:
				for pid in m.G["players"]:
					for pm in m.legal_moves(int(pid)):
						if not acted and str((pm as Dictionary).get("type", "")) in ["pass", "passBuild"] and m.apply_move(int(pid), pm):
							acted = true
				if not acted and mv != null:
					acted = m.apply_move(ap, mv)
				if not acted:
					for pid in m.G["players"]:
						var pmoves: Array = m.legal_moves(int(pid))
						if not pmoves.is_empty() and m.apply_move(int(pid), pmoves[0]):
							acted = true
							break
		else:
			break
		steps += 1
		if not acted:
			break
	return m.G.get("gameOver") != null

## Plateau reel (Board.tscn) : le miniboss et son niveau sont visibles sur la salle (le sien, et celui de l'adversaire sans nom tant qu'il est face cache), Coins dans la barre laterale.
func _t_ui_board() -> void:
	var gm = load("res://godot/scripts/GameManager.gd").new()
	host.add_child(gm)
	gm.start_new_game(2, 1, ["minibosses"])
	for pid in [0, 1]:
		var pick: Dictionary = (gm.G["bossPicks"] as Array)[0]
		gm.apply_move(pid, {"type": "pickBoss", "args": [pick["id"]]})
	var G: Dictionary = gm.G
	_with_mb(_plain("MINE", "monster", [1], 2), "RMB057", 2)
	var mine := _with_mb(_plain("MINE", "monster", [1], 2), "RMB057", 2)
	var theirs := _with_mb(_plain("THEIRS", "trap", [2], 2), "RMB058", 1, true)
	G["players"][0]["dungeon"] = [[mine]]
	G["players"][1]["dungeon"] = [[theirs]]
	var board = load("res://godot/scenes/Board.tscn").instantiate()
	host.add_child(board)
	board.setup(gm, func(): pass)
	board.refresh()
	var found := false
	for slot in board._dungeon_slots:
		var b = (slot as Node).get_node_or_null("MbBadge")
		found = found or (b != null and str(b.text).contains("Draculad") and str(b.text).contains("L2"))
	_ok.call(found, "plateau : le badge « Draculad L2 » est pose sur la salle porteuse")
	var foe_found := false
	for slot in board._foe_slots:
		for ch in (slot as Node).get_children():
			foe_found = foe_found or (ch is Label and str(ch.text) == "MINIBOSS (face-down)")
	_ok.call(foe_found, "plateau : le miniboss adverse face cache est montre sans son nom")
	_ok.call(board.deck_info_label.text.contains("COINS: 3"), "plateau : les Coins du joueur sont affiches")
	board.free()
	gm.free()
	AudioManager.stop_music() # le plateau lance la musique : sans cela Godot signale une ressource encore utilisee a la sortie

## Regression (soak graine 103) : pendant une Spell Battle, une capacite RMB n'est proposee que si elle s'applique vraiment (verification pure,
## pas de copie profonde de l'etat qui ferait perdre l'identite du heros actif / de l'entree).
func _t_stack_probe_identity() -> void:
	var cav := _room("RMB019")
	var p0 := _player(0, "BMA001", [cav, _plain("B")], 2)
	var G := _G([p0, _player(1, "BMA002")])
	_adventure(G, 0, _hero("RMB094"), 0, 9)
	G["stack"] = [{"id": "st1", "type": "spell", "playerId": 1, "card": _spl("THEIRS"), "target": {}, "resolved": false}]
	G["activePlayer"] = 0
	var m := _match(G)
	_ok.call(_types(m.legal_moves(0), "activateRoom").is_empty(), "Haunted Cavern : le seul heros de l'entree est celui du donjon -> pas de coup (meme pendant une Spell Battle)")
	(p0["entrance"] as Array).append(_hero("RMB095"))
	var moves := _types(m.legal_moves(0), "activateRoom")
	_ok.call(moves.size() == 1 and RmbAbilities.check(G, p0, 0, 0, cav) == "", "Haunted Cavern : un heros en attente -> coup propose, et il s'applique")
