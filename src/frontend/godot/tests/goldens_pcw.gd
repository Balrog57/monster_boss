extends RefCounted
## Goldens des 6 cartes « The Player's Choice » (KSA008-KSA012, KSA015) que l'APK ne joue pas : pseudo-paquet `players-choice-wiki`, derriere la case wiki.
## References : texte des cartes (cards.json, wiki « List of Cards »), FAQ de docs/rules/rules.md (Ghoulyard, Trash Compactor, Bone Crank, Pixel Lincoln).
## Appele par goldens.gd : `load("res://godot/tests/goldens_pcw.gd").new().run(_ok, self)`.

var _ok: Callable
var host: Node

func run(ok: Callable, h: Node) -> void:
	_ok = ok
	host = h
	_t_gating()
	_t_rooms_damage()
	_t_bone_crank()
	_t_trash_compactor()
	_t_agent_of_evil()
	_t_pixel_lincoln()

# --- fabriques ---------------------------------------------------------------------------------------------------------------------

func _hero(id: String, hp: int = 6, treasure: int = 2, epic: bool = false) -> Dictionary:
	return {"id": id, "name": id, "hp": hp, "treasure": treasure, "treasures": [treasure], "class": "x", "souls": 2 if epic else 1, "wounds": 2 if epic else 1, "epic": epic}

func _room(id: String) -> Dictionary:
	for c in CardDB.rooms:
		if str((c as Dictionary).get("id", "")) == id:
			var r: Dictionary = (c as Dictionary).duplicate(true)
			r["isRoom"] = true
			return r
	push_error("salle introuvable " + id)
	return {}

func _plain(id: String, type: String = "trap", treasures: Array = [1], damage: int = 1) -> Dictionary:
	return {"id": id, "name": id, "type": type, "advanced": false, "treasures": treasures, "damage": damage, "isRoom": true}

func _player(pid: int, dungeon: Array = []) -> Dictionary:
	var stacks: Array = []
	for r in dungeon:
		stacks.append([r])
	var boss: Dictionary = {"id": "BMA001", "name": "B", "xp": 900 - 100 * pid, "treasures": [1]}
	return {"id": pid, "boss": boss, "dungeon": stacks, "hand": [], "souls": [], "wounds": [], "entrance": [], "eliminated": false, "leveledUp": false, "buildsThisTurn": 0, "coins": 3, "items": []}

func _G(players: Array, sets: Array = ["base", "players-choice", "players-choice-wiki"]) -> Dictionary:
	var ps := {}
	for p in players:
		ps[int((p as Dictionary)["id"])] = p
	var spells: Array = []
	for i in 12:
		spells.append({"id": "SP%d" % i, "name": "SP%d" % i, "isSpell": true, "category": 3})
	return {"players": ps, "town": [], "townItems": [], "log": [], "logs": [], "adventure": {}, "turn": 3, "phase": "build", "activePlayer": 0,
		"buildOrder": [0, 1], "buildIndex": 0, "sets": sets, "effects": SpellEffects.empty_effects(), "stack": [], "pendingChoice": {}, "choiceQueue": [],
		"decks": {"rooms": [], "spells": spells, "heroes": [], "epics": [], "items": [], "roomDiscard": [], "spellDiscard": [], "heroDiscard": []}}

func _match(G: Dictionary) -> Node:
	var m = load("res://godot/scripts/Match.gd").new()
	host.add_child(m)
	m.G = G
	return m

func _live() -> Array:
	var m = load("res://godot/scripts/Match.gd").new()
	host.add_child(m)
	var G: Dictionary = m.new_match(2, 1, ["players-choice", "players-choice-wiki"])
	for pid in [0, 1]:
		var p: Dictionary = G["players"][pid]
		p["boss"] = _player(pid)["boss"]
		p["dungeon"] = []
		p["entrance"] = []
		p["hand"] = []
		p["wounds"] = []
		p["souls"] = []
	G["town"] = []
	G["adventure"] = {}
	G["pendingChoice"] = {}
	G["choiceQueue"] = []
	G["stack"] = []
	G["phase"] = "adventure"
	G["activePlayer"] = 0
	G["turn"] = 3
	return [m, G]

func _p(G: Dictionary, pid: int) -> Dictionary:
	return G["players"][pid] as Dictionary

func _ids(arr: Array) -> Array:
	var out: Array = []
	for c in arr:
		out.append(str((c as Dictionary).get("id", "")))
	return out

func _next(m: Node, pid: int = 0) -> void:
	m.apply_move(pid, {"type": "adventureNext", "args": []})
	for _r in 6:
		var adv: Dictionary = m.G.get("adventure", {})
		if adv.is_empty() or adv.get("pause") == null or not (m.G["pendingChoice"] as Dictionary).is_empty():
			break
		for q in [0, 1]:
			m.apply_move(q, {"type": "pass", "args": []})

# --- gating -------------------------------------------------------------------------------------------------------------------------

func _t_gating() -> void:
	var wiki_ids := ["KSA008", "KSA009", "KSA010", "KSA011", "KSA012", "KSA015"]
	var m1 = load("res://godot/scripts/Match.gd").new()
	host.add_child(m1)
	var G1: Dictionary = m1.new_match(2, 1, ["players-choice"])
	var all1 := _ids(G1["decks"]["rooms"]) + _ids(G1["decks"]["spells"]) + _ids(G1["decks"]["heroes"]) + _ids(G1["decks"]["epics"])
	_ok.call(not wiki_ids.any(func(i): return all1.has(i)) and not (G1["sets"] as Array).has("players-choice-wiki"), "KSA wiki : le paquet APK « players-choice » seul ne contient aucune des 6 cartes")
	var m2 = load("res://godot/scripts/Match.gd").new()
	host.add_child(m2)
	var G2: Dictionary = m2.new_match(2, 1, ["players-choice", "players-choice-wiki"])
	var all2 := _ids(G2["decks"]["rooms"]) + _ids(G2["decks"]["spells"])
	_ok.call(Match.wiki_active(G2) and ThkAbilities.active(G2) and ["KSA008", "KSA009", "KSA010", "KSA011", "KSA012"].all(func(i): return all2.has(i)), "KSA wiki : avec la case wiki, 4 salles et 1 sort rejoignent les pioches")
	var heroes := CardDB.heroes.filter(func(c): return str((c as Dictionary).get("set", "")) == "players-choice-wiki")
	_ok.call(heroes.size() == 1 and str(heroes[0]["id"]) == "KSA015" and bool(heroes[0]["epic"]) and bool(heroes[0]["implemented"]), "KSA015 : Pixel Lincoln est un heros epique du pseudo-paquet")
	_ok.call(CardDB.rooms.filter(func(c): return str((c as Dictionary).get("set", "")) == "players-choice-wiki").size() == 4 and CardDB.spells.filter(func(c): return str((c as Dictionary).get("set", "")) == "players-choice-wiki").size() == 1,
		"KSA wiki : 4 salles + 1 sort + 1 heros (6 cartes manquantes du Player's Choice)")
	# l'APK ne change pas : le paquet PlayerChoice de l'oracle n'a que 7 boss, 3 heros epiques, 1 sort
	var apk := CardDB.bosses.filter(func(c): return str((c as Dictionary).get("set", "")) == "players-choice").size()
	_ok.call(apk == 7, "KSA wiki : le paquet APK « players-choice » garde ses 7 boss")

# --- Ghoulyard, Shark Tank ----------------------------------------------------------------------------------------------------------

func _t_rooms_damage() -> void:
	# KSA008 Ghoulyard : degats doubles contre un heros epique, APRES les autres bonus (FAQ)
	var G := _G([_player(0, [_room("KSA008")]), _player(1)])
	var p0 := _p(G, 0)
	var ord := _hero("O", 9, 1)
	var epic := _hero("E", 9, 1, true)
	_ok.call(BossEngine.room_damage_with_modifiers(G, p0, 0, ord) == 2 and BossEngine.room_damage_with_modifiers(G, p0, 0, epic) == 4, "KSA008 Ghoulyard : 2 degats, 4 contre un heros epique")
	(p0["dungeon"][0][0] as Dictionary)["dealDamage"] = 3 # Giant Size (+3) : (2 + 3) x 2
	_ok.call(BossEngine.room_damage_with_modifiers(G, p0, 0, epic) == 10 and BossEngine.room_damage_with_modifiers(G, p0, 0, ord) == 5, "KSA008 Ghoulyard : les bonus des autres cartes sont appliques avant le doublement (10)")
	TnlAbilities._tag(p0["dungeon"][0][0])["noText"] = true
	_ok.call(BossEngine.room_damage_with_modifiers(G, p0, 0, epic) == 5, "KSA008 Ghoulyard : sans texte (Meddling Kids!), plus de doublement")
	var Gn := _G([_player(0, [_room("KSA008")]), _player(1)], ["base", "players-choice"])
	_ok.call(BossEngine.room_damage_with_modifiers(Gn, _p(Gn, 0), 0, epic) == 2, "KSA008 Ghoulyard : sans la case wiki, aucun effet (carte absente des pioches)")
	# KSA009 Shark Tank : +2 si le heros a deja subi la moitie de sa Sante
	var G2 := _G([_player(0, [_room("KSA009")]), _player(1)])
	var h := _hero("H", 8, 2)
	G2["adventure"] = {"playerId": 0, "hero": h, "roomIndex": 0, "hp": 5, "pause": null}
	_ok.call(BossEngine.room_damage_with_modifiers(G2, _p(G2, 0), 0, h) == 1, "KSA009 Shark Tank : 3 degats subis sur 8 (< la moitie) -> 1 degat")
	G2["adventure"]["hp"] = 4
	_ok.call(BossEngine.room_damage_with_modifiers(G2, _p(G2, 0), 0, h) == 3, "KSA009 Shark Tank : 4 degats subis sur 8 (la moitie) -> 1 + 2 = 3")
	var odd := _hero("OD", 7, 2)
	G2["adventure"] = {"playerId": 0, "hero": odd, "roomIndex": 0, "hp": 4, "pause": null}
	_ok.call(BossEngine.room_damage_with_modifiers(G2, _p(G2, 0), 0, odd) == 1, "KSA009 Shark Tank : 7 PV, 3 degats subis -> la moitie (arrondie au-dessus, 4) n'est pas atteinte")
	var fresh := _hero("FR", 8, 2)
	_ok.call(BossEngine.room_damage_with_modifiers(G2, _p(G2, 0), 0, fresh) == 1, "KSA009 Shark Tank : un heros intact subit 1 degat")

# --- Bone Crank -----------------------------------------------------------------------------------------------------------------------

func _t_bone_crank() -> void:
	var G := _G([_player(0, [_plain("MINE")]), _player(1, [_plain("T1"), _plain("T2")])])
	var crank := _room("KSA010")
	var choice = RoomAbilities.on_build_room(G, 0, crank)
	var pc: Dictionary = choice if choice is Dictionary else {}
	_ok.call(str(pc.get("step", "")) == "thk_pcw_deact" and (pc["options"] as Array).size() == 3, "KSA010 Bone Crank : a la pose, choix d'une salle de n'importe quel donjon (3 candidates)")
	G["pendingChoice"] = pc
	var idx := 0
	for i in (pc["options"] as Array).size():
		if int(pc["options"][i]["targetPlayerId"]) == 1 and int(pc["options"][i]["roomIndex"]) == 1:
			idx = i
	_match(G)._resolve_choice(0, idx)
	_ok.call(BossEngine.is_room_deactivated(G, 1, 1) and not BossEngine.is_room_deactivated(G, 1, 0) and not BossEngine.is_room_deactivated(G, 0, 0), "KSA010 Bone Crank : la salle choisie est desactivee jusqu'a la fin du tour")
	var Gn := _G([_player(0), _player(1)])
	_ok.call(RoomAbilities.on_build_room(Gn, 0, _room("KSA010")) == null, "KSA010 Bone Crank : aucune salle a desactiver -> rien")

# --- Trash Compactor ---------------------------------------------------------------------------------------------------------------------

func _t_trash_compactor() -> void:
	var lv := _live()
	var G: Dictionary = lv[1]
	(_p(G, 0)["dungeon"] as Array).append([_room("KSA011")])
	(_p(G, 0)["entrance"] as Array).append(_hero("H1", 9, 4))
	(_p(G, 0)["entrance"] as Array).append(_hero("H2", 9, 4))
	_next(lv[0])
	_ok.call(int(G["adventure"]["hp"]) == 9 - 3, "KSA011 Trash Compactor : le premier heros subit 3 degats")
	_next(lv[0]) # il survit (6 PV) et sort
	var room: Dictionary = _p(G, 0)["dungeon"][0][0]
	_ok.call(TnlAbilities.zero_damage(room), "KSA011 Trash Compactor : un heros en est sorti vivant -> plus de degats jusqu'a la fin du tour")
	_ok.call(BossEngine.room_damage_with_modifiers(G, _p(G, 0), 0, _hero("H2", 9, 4)) == 0, "KSA011 Trash Compactor : zero degat (les bonus ne le relevent pas)")
	(G["effects"]["roomDamageBonus"] as Array).append({"playerId": 0, "roomIndex": 0, "amount": 3})
	_ok.call(BossEngine.room_damage_with_modifiers(G, _p(G, 0), 0, _hero("H2", 9, 4)) == 0, "KSA011 Trash Compactor : « cannot increase this Room's damage above zero »")
	# un heros qui meurt dedans ne declenche rien
	var lv2 := _live()
	var G2: Dictionary = lv2[1]
	(_p(G2, 0)["dungeon"] as Array).append([_room("KSA011")])
	(_p(G2, 0)["entrance"] as Array).append(_hero("D1", 2, 4))
	_next(lv2[0])
	_next(lv2[0])
	_ok.call(not TnlAbilities.zero_damage(_p(G2, 0)["dungeon"][0][0]), "KSA011 Trash Compactor : un heros qui meurt dans la salle ne la neutralise pas")

# --- Agent of Evil ----------------------------------------------------------------------------------------------------------------------------

func _t_agent_of_evil() -> void:
	var G := _G([_player(0), _player(1), _player(2)])
	G["town"] = [_hero("A", 5, 1), _hero("B", 5, 2)]
	var targets := SpellTargeting.spell_targets_for(G, _p(G, 0), 0, "KSA012")
	_ok.call(targets.size() == 4, "KSA012 Agent of Evil : un heros de la ville x un adversaire (2 x 2 = 4 cibles)")
	var spell := {"id": "KSA012", "name": "Agent of Evil", "isSpell": true, "category": 1}
	(_p(G, 0)["hand"] as Array).append(spell)
	var m := _match(G)
	_ok.call(m.legal_moves(0).any(func(mv): return str((mv as Dictionary)["type"]) == "playSpell"), "KSA012 Agent of Evil : jouable en Construction")
	G["phase"] = "adventure"
	_ok.call(not m.legal_moves(0).any(func(mv): return str((mv as Dictionary)["type"]) == "playSpell"), "KSA012 Agent of Evil : pas en Aventure")
	G["phase"] = "build"
	var ok: bool = m.apply_move(0, {"type": "playSpell", "args": [0, {"townIndex": 1, "targetPlayerId": 2}]})
	for _r in 4:
		for q in [1, 0, 2]:
			if not (G["stack"] as Array).is_empty():
				m.apply_move(q, {"type": "pass", "args": []})
	_ok.call(ok and _ids(_p(G, 2)["entrance"]) == ["B"] and _ids(G["town"]) == ["A"], "KSA012 Agent of Evil : le heros designe va a l'entree du donjon adverse designe")
	_ok.call(PcwAbilities.cast_agent(G, 0, {"townIndex": 0, "targetPlayerId": 0}) == false, "KSA012 Agent of Evil : jamais chez soi")
	# sans la case wiki : la carte n'existe pas
	var Gn := _G([_player(0), _player(1)], ["base", "players-choice"])
	Gn["town"] = [_hero("A", 5, 1)]
	_ok.call(SpellTargeting.spell_targets_for(Gn, _p(Gn, 0), 0, "KSA012").size() == 1, "KSA012 : le ciblage ne depend que de la carte (absente des pioches sans la case wiki)")

# --- Pixel Lincoln ----------------------------------------------------------------------------------------------------------------------------

func _t_pixel_lincoln() -> void:
	var lincoln: Dictionary = {}
	for c in CardDB.heroes:
		if str((c as Dictionary).get("id", "")) == "KSA015":
			lincoln = (c as Dictionary).duplicate(true)
	_ok.call(ThkAbilities.is_star(lincoln) and str(lincoln.get("lure", "")) == "mostCards", "KSA015 Pixel Lincoln : heros a etoile (aucun Objet), leurre « le plus de cartes en main »")
	# leurre : le joueur qui a le plus de cartes en main ; egalite -> reste en ville
	var G := _G([_player(0), _player(1), _player(2)])
	(_p(G, 0)["hand"] as Array).append_array([_plain("a"), _plain("b")])
	(_p(G, 1)["hand"] as Array).append_array([_plain("c"), _plain("d"), _plain("e")])
	(_p(G, 2)["hand"] as Array).append_array([_plain("f")])
	var order := CardDB.order_by_xp(G["players"])
	_ok.call(BossEngine.lure_target(G["players"], order, 0, lincoln, G) == 1, "KSA015 Pixel Lincoln : leurre vers le joueur qui a le plus de cartes en main (3 contre 2 et 1)")
	(_p(G, 2)["hand"] as Array).append_array([_plain("g"), _plain("h")])
	_ok.call(BossEngine.lure_target(G["players"], order, 0, lincoln, G) == -1, "KSA015 Pixel Lincoln : egalite -> il attend en ville")
	# un Objet universel ne s'y attache pas
	var Gi := _G([_player(0), _player(1)])
	Gi["town"] = [lincoln]
	Gi["townItems"] = [{"id": "IOD017", "name": "Antifreeze", "treasure": 0, "treasures": [0], "isItem": true}]
	ThkAbilities.attach_all(Gi)
	_ok.call(not lincoln.has("item") and (Gi["townItems"] as Array).size() == 1, "KSA015 Pixel Lincoln : etoile, un Objet Universel ne s'attache pas")
	# revele en ville : chaque joueur, par XP, choisit combien de sorts piocher (0 a 3)
	var G2 := _G([_player(0), _player(1)])
	var first = PcwAbilities.lincoln_start(G2)
	var fc: Dictionary = first
	_ok.call(str(fc.get("step", "")) == "thk_pcw_lincoln" and (fc["options"] as Array).size() == 4 and int(fc["playerId"]) == int(CardDB.order_by_xp(G2["players"])[0]), "KSA015 Pixel Lincoln : le premier joueur par XP choisit 0 a 3 sorts")
	G2["pendingChoice"] = fc
	var m2 := _match(G2)
	m2._resolve_choice(int(fc["playerId"]), 3)
	var second: Dictionary = G2["pendingChoice"]
	_ok.call(int(second.get("playerId", -1)) != int(fc["playerId"]) and TnlAbilities.spells_in_hand(_p(G2, int(fc["playerId"]))) == 3, "KSA015 Pixel Lincoln : 3 sorts pour le premier, puis c'est au joueur suivant")
	m2._resolve_choice(int(second["playerId"]), 1)
	_ok.call((G2["pendingChoice"] as Dictionary).is_empty() and TnlAbilities.spells_in_hand(_p(G2, int(second["playerId"]))) == 1, "KSA015 Pixel Lincoln : le second pioche 1 sort, la chaine se termine")
	# revele par _reveal_heroes_in_town : le drapeau est pose (le choix est ouvert par _start_turn apres les pioches)
	var G3 := _G([_player(0), _player(1)])
	(G3["decks"] as Dictionary)["heroes"] = []
	(G3["decks"] as Dictionary)["epics"] = [lincoln]
	var m3 := _match(G3)
	m3._reveal_heroes_in_town()
	_ok.call(bool(G3.get("lincolnReveal", false)) and _ids(G3["town"]).has("KSA015"), "KSA015 Pixel Lincoln : la revelation en ville declenche le choix de pioche")
