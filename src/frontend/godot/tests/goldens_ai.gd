extends RefCounted
## Goldens de l'IA sur les cartes wiki (TNL / CRL / RMB, hors APK) : chaque carte que l'IA ne jouait jamais a maintenant une situation ou elle la joue
## (score > 0) et une situation voisine ou elle ne la joue pas. Verifie aussi les constructions immediates dans un nouvel emplacement (Fangroot Garden,
## Brassknuckle). Regle de lecture : un coup « de situation » vaut quelque chose seulement s'il change l'issue
## de l'aventure (AiWiki.fate : marge = PV du heros - degats a venir ; <= 0 il meurt, > 0 il blesse le proprietaire du donjon) ou le leurre.
## Appele par goldens.gd : `load("res://godot/tests/goldens_ai.gd").new().run(_ok, self)`.

var _ok: Callable
var host: Node

func run(ok: Callable, h: Node) -> void:
	_ok = ok
	host = h
	_t_fate()
	_t_tnl_rooms_opponent_hero()
	_t_tnl_rooms_my_hero()
	_t_tnl_chomper_smashinator()
	_t_tnl_build_phase_rooms()
	_t_doc_scarecrow()
	_t_tnl_spells()
	_t_crl_omega()
	_t_rmb_rooms()
	_t_rmb_boss_and_hand()
	_t_rmb_spells()
	_t_rmb_miniboss_powers()
	_t_swap_weights()
	_t_build_in_new_slot()
	_t_apk_factors()
	_t_apk_values()
	_t_apk_build_plan()
	_t_apk_discard()
	_t_apk_pick_order()
	_t_apk_spells_checks()
	_t_apk_giant_size_type()
	_t_apk_spell_battle()
	_t_apk_rooms_checks()
	_t_apk_draw_uniform()

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

func _minicard(id: String) -> Dictionary:
	var c := _card(CardDB.minibosses, id)
	c["isRoom"] = true
	c["isMiniboss"] = true
	return c

func _plain(id: String, type: String = "monster", treasures: Array = [1], damage: int = 1, advanced: bool = false) -> Dictionary:
	return {"id": id, "name": id, "type": type, "advanced": advanced, "treasures": treasures, "damage": damage, "isRoom": true}

func _hero(id: String) -> Dictionary:
	var h := _card(CardDB.heroes, id)
	h["souls"] = 2 if bool(h.get("epic", false)) else 1
	h["wounds"] = h["souls"]
	return h

func _with_mb(room: Dictionary, mid: String, lvl: int = 1) -> Dictionary:
	room["mb"] = {"card": _minicard(mid), "level": lvl, "faceDown": false, "since": 0, "usedTurn": -1}
	return room

func _player(pid: int, boss_id: String, dungeon: Array = [], coins: int = 3) -> Dictionary:
	var stacks: Array = []
	for r in dungeon:
		stacks.append([r])
	return {"id": pid, "boss": _card(CardDB.bosses, boss_id), "dungeon": stacks, "hand": [], "souls": [], "wounds": [],
		"entrance": [], "eliminated": false, "leveledUp": false, "buildsThisTurn": 0, "coins": coins}

func _G(players: Array, sets: Array = ["base", "next-level", "minibosses", "crash-landing"]) -> Dictionary:
	var ps := {}
	for p in players:
		ps[int((p as Dictionary)["id"])] = p
	return {"players": ps, "town": [], "log": [], "logs": [], "adventure": {}, "turn": 3, "phase": "adventure", "sets": sets,
		"effects": SpellEffects.empty_effects(), "stack": [], "pendingChoice": {}, "choiceQueue": [],
		"decks": {"rooms": [], "spells": [], "heroes": [], "epics": [], "items": [], "roomDiscard": [], "spellDiscard": [], "heroDiscard": []}}

func _match(G: Dictionary) -> Node:
	var m = load("res://godot/scripts/Match.gd").new()
	host.add_child(m)
	m.G = G
	return m

## Un heros actif dans le donjon de `owner`, dans la salle `idx`, avec `hp` PV (pause apres degats).
func _adventure(G: Dictionary, owner: int, hero: Dictionary, idx: int, hp: int) -> void:
	(G["players"][owner]["entrance"] as Array).append(hero)
	G["adventure"] = {"playerId": owner, "hero": hero, "roomIndex": idx, "hp": hp, "pause": "post-damage"}
	G["activePlayer"] = owner

func _hand(G: Dictionary, pid: int) -> Array:
	return (G["players"][pid] as Dictionary)["hand"] as Array

func _fill_hand(G: Dictionary, pid: int, n: int) -> void:
	for i in n:
		_hand(G, pid).append(_plain("h%d" % i, "monster" if i % 2 == 0 else "trap", [1], 1))

func _mv(t: String, args: Array = []) -> Dictionary:
	return {"type": t, "args": args}

func _act(m: Node, pid: int, idx: int) -> float:
	return AI.score_move(m, pid, _mv("activateRoom", [idx]))

## Scenario type : P0 (l'IA qui decide) et P1 (proprietaire du donjon : trap 2 / monster 3 devant le heros). Le heros est dans la salle 0 avec `hp` PV,
## donc marge = hp - 5 : hp 5 -> 0 (il meurt de justesse), hp 2 -> -3, hp 7 -> +2.
func _opp_scene(hp: int, mine_dungeon: Array = []) -> Dictionary:
	var p1 := _player(1, "BMA002", [_plain("r0", "monster", [1], 1), _plain("t1", "trap", [1], 2), _plain("m2", "monster", [1], 3)])
	var G := _G([_player(0, "BMA001", mine_dungeon), p1])
	_adventure(G, 1, _hero("TNL073"), 0, hp)
	return G

# --- lecture de l'aventure -------------------------------------------------------------------------------------

func _t_fate() -> void:
	var G := _opp_scene(5)
	var f := AiWiki.fate(G)
	_ok.call(bool(f["active"]) and int(f["owner"]) == 1 and int(f["ahead"]) == 5 and int(f["margin"]) == 0 and int(f["best"]) == 3 and int(f["traps"]) == 1 and int(f["monsters"]) == 1,
		"AiWiki.fate : degats a venir 5, marge 0, 1 trap + 1 monster devant le heros")
	_ok.call(AiWiki.saves(f, 1) and not AiWiki.saves(AiWiki.fate(_opp_scene(2)), 1) and AiWiki.kills(AiWiki.fate(_opp_scene(7)), 2) and not AiWiki.kills(AiWiki.fate(_opp_scene(9)), 2),
		"AiWiki.saves / kills : seul un ecart d'au plus x change l'issue")
	var none := AiWiki.fate(_G([_player(0, "BMA001"), _player(1, "BMA002")]))
	_ok.call(not bool(none["active"]) and not AiWiki.saves(none, 99) and not AiWiki.kills(none, 99), "AiWiki.fate : sans heros actif, rien ne change l'issue")

# --- The Next Level : salles activees ---------------------------------------------------------------------------

func _t_tnl_rooms_opponent_hero() -> void:
	var G := _opp_scene(5, [_room("TNL033"), _room("TNL022"), _room("TNL040"), _room("TNL053")])
	_fill_hand(G, 0, 4)
	var m := _match(G)
	_ok.call(_act(m, 0, 0) > 0.0, "IA : Frostbat Cave desactive la salle adverse qui tue le heros de justesse (marge 0)")
	_ok.call(_act(m, 0, 1) > 0.0 and _act(m, 0, 2) > 0.0, "IA : Rust Monster Pen / Bullet Builder (-1 Trap / Monster) quand 1 degat sauve le heros adverse")
	_ok.call(_act(m, 0, 3) > 0.0, "IA : Werewolf Den (+1 PV) donne au heros adverse qui meurt de justesse")
	var G2 := _opp_scene(2, [_room("TNL033"), _room("TNL022"), _room("TNL053")])
	_fill_hand(G2, 0, 4)
	var m2 := _match(G2)
	_ok.call(_act(m2, 0, 0) < 0.0 and _act(m2, 0, 1) < 0.0 and _act(m2, 0, 2) < 0.0, "IA : ... mais pas quand le heros mourra de toute facon (marge -3)")
	var G3 := _opp_scene(5, [_room("TNL022"), _room("TNL053")])
	_fill_hand(G3, 0, 1)
	_ok.call(_act(_match(G3), 0, 0) < 0.0 and _act(_match(G3), 0, 1) < 0.0, "IA : ni Rust Monster Pen ni Werewolf Den sans carte de rechange en main")
	# la cible : la salle adverse la plus dangereuse encore devant le heros
	var G4 := _opp_scene(5, [_room("TNL033")])
	var opts := TnlAbilities.room_options(G4, "any", 0, 0)
	opts.sort_custom(func(a, b): return float((a as Dictionary)["ai"]) > float((b as Dictionary)["ai"]))
	_ok.call(int((opts[0] as Dictionary)["targetPlayerId"]) == 1 and int((opts[0] as Dictionary)["roomIndex"]) == 2, "IA : Frostbat Cave vise la salle de 3 degats encore devant le heros")
	# Werewolf Den : le heros qui compte est celui de l'adversaire
	var hs := TnlAbilities.hero_options(G4)
	_ok.call(hs.size() == 1 and AiWiki.hero_weight(G4, 0, hs[0] as Dictionary) > 0.0 and AiWiki.hero_weight(G4, 1, hs[0] as Dictionary) < 0.0, "IA : +PV pour le heros du donjon adverse, jamais pour le sien")

func _t_tnl_rooms_my_hero() -> void:
	# mon donjon : le heros (7 PV) survivrait a tout -> Haunted Hall le renvoie en ville ; il mourra (3 PV) -> on ne gaspille pas la salle
	var mine := func(hp: int) -> Dictionary:
		var G := _G([_player(0, "BMA001", [_room("TNL017"), _plain("t1", "trap", [1], 2), _plain("m2", "monster", [1], 3)]), _player(1, "BMA002")])
		_adventure(G, 0, _hero("TNL073"), 0, hp)
		return G
	_ok.call(_act(_match(mine.call(7)), 0, 0) > 0.0, "IA : Haunted Hall renvoie en ville le heros qui survivrait a mon donjon")
	_ok.call(_act(_match(mine.call(3)), 0, 0) < 0.0, "IA : ... pas celui qui va mourir")
	# Warp Tube (salle 1, deux salles derriere le heros qui coutent 2 + 2) : 3 PV de marge, 4 degats a rejouer -> il mourrait au second passage
	var G := _G([_player(0, "BMA001", [_plain("a", "trap", [1], 2), _room("TNL049"), _plain("c", "monster", [1], 1)]), _player(1, "BMA002")])
	_adventure(G, 0, _hero("TNL073"), 1, 2)
	_ok.call(int(AiWiki.fate(G)["margin"]) == 1 and int(AiWiki.fate(G)["behind"]) == 2 and _act(_match(G), 0, 1) > 0.0, "IA : Warp Tube renvoie au debut le heros qui y mourrait au second passage")
	_adventure(G, 0, _hero("TNL073"), 1, 9)
	G["adventure"]["hp"] = 9
	_ok.call(_act(_match(G), 0, 1) < 0.0, "IA : ... pas s'il survivrait quand meme")
	# Minotaur Catacombs (RMB022) : meme regle
	var G2 := _G([_player(0, "BMA001", [_plain("a", "trap", [1], 2), _room("RMB022"), _plain("c", "monster", [1], 1)]), _player(1, "BMA002")])
	_adventure(G2, 0, _hero("TNL073"), 1, 2)
	_ok.call(_act(_match(G2), 0, 1) > 0.0, "IA : Minotaur Catacombs (RMB022) suit la regle de Warp Tube")

func _t_tnl_chomper_smashinator() -> void:
	# Chump Chomper (salle 2, devant le heros) : +4 fait mourir le heros (marge 3 -> -1) et une salle deja traversee peut payer
	var G := _G([_player(0, "BMA001", [_plain("a", "trap", [1], 1), _plain("b", "monster", [1], 1), _room("TNL046"), _plain("d", "monster", [1], 1)]), _player(1, "BMA002")])
	_adventure(G, 0, _hero("TNL073"), 1, 5)
	var f := AiWiki.fate(G)
	_ok.call(int(f["margin"]) == 2 and AiWiki.kills(f, 4) and _act(_match(G), 0, 2) > 0.0, "IA : Chump Chomper +4 (en detruisant une salle deja traversee) si cela fait mourir le heros de mon donjon")
	var G2 := _G([_player(0, "BMA001", [_plain("a", "trap", [1], 1), _plain("b", "monster", [1], 1), _room("TNL046"), _plain("d", "monster", [1], 1)]), _player(1, "BMA002")])
	_adventure(G2, 0, _hero("TNL073"), 1, 30)
	_ok.call(_act(_match(G2), 0, 2) < 0.0, "IA : ... pas quand le heros est bien trop solide")
	# Smashinator : seulement pour eviter une blessure grave (3 blessures ou plus)
	var G3 := _G([_player(0, "BMA001", [_plain("a", "trap", [1], 1), _room("TNL048"), _plain("d", "monster", [1], 1)]), _player(1, "BMA002")])
	_adventure(G3, 0, _hero("TNL073"), 0, 7)
	var f3 := AiWiki.fate(G3)
	_ok.call(AiWiki.kills(f3, 6) and _act(_match(G3), 0, 1) < 0.0, "IA : Smashinator detruit tout le donjon : pas sans danger")
	for _w in 3:
		(G3["players"][0]["wounds"] as Array).append({"wounds": 1})
	_ok.call(_act(_match(G3), 0, 1) > 0.0, "IA : ... mais oui a 3 blessures si +6 tue le heros")

func _t_tnl_build_phase_rooms() -> void:
	# Wreck Room : avant de construire, une salle de rien du tout contre une carte, main legere
	var G := _G([_player(0, "BMA001", [_room("TNL041"), _plain("junk", "trap", [1], 0), _plain("b"), _plain("c"), _plain("d")]), _player(1, "BMA002")])
	G["phase"] = "build"
	G["activePlayer"] = 0
	_fill_hand(G, 0, 2)
	var m := _match(G)
	_ok.call(_act(m, 0, 0) >= AiWiki.BUILD_FIRST, "IA : Wreck Room passe avant la construction quand une salle ne vaut rien")
	_fill_hand(G, 0, 3)
	_ok.call(_act(m, 0, 0) < 0.0, "IA : ... pas avec une main bien garnie")
	(G["players"][0]["dungeon"] as Array).remove_at(4)
	(G["players"][0]["dungeon"] as Array).remove_at(3)
	_hand(G, 0).resize(2)
	_ok.call(_act(m, 0, 0) < 0.0, "IA : ... ni tant que le donjon se remplit (detruire une salle retarde le niveau 5 salles)")
	# Decapitator : P1 et moi avons 1 icone Cleric (egalite : le Cleric de la ville reste en ville) ; sans le tresor de la salle de P1 il vient chez moi et y meurt
	var G2 := _G([_player(0, "BMA001", [_room("TNL045"), _plain("mine", "monster", [1], 3), _plain("f1", "monster", [], 0), _plain("f2", "monster", [], 0), _plain("f3", "monster", [], 0)]), _player(1, "BMA002", [_plain("theirs", "monster", [1], 3)])])
	G2["players"][0]["boss"]["treasures"] = []
	G2["players"][1]["boss"]["treasures"] = []
	G2["phase"] = "build"
	G2["activePlayer"] = 0
	var frail := _hero("TNL073") # 4 PV : meurt dans mon donjon (3 + 2 degats)
	G2["town"] = [frail]
	_hand(G2, 0).append(_plain("spare")) # de quoi reboucher l'emplacement que Decapitator libere
	var theirs: Dictionary = G2["players"][1]["dungeon"][0][0]
	_ok.call(is_equal_approx(AiWiki.no_treasure_gain(G2, 0, theirs), 1.0) and not TnlAbilities.flag(theirs, "noTreasure"), "AiWiki.no_treasure_gain : +1 ame attendue, et la simulation ne laisse rien derriere elle")
	_ok.call(_act(_match(G2), 0, 0) >= AiWiki.BUILD_FIRST, "IA : Decapitator (avant de construire) quand il fait venir chez moi un heros qui y meurt")
	var tough := _hero("TNL073")
	tough["hp"] = 40
	G2["town"] = [tough]
	_ok.call(AiWiki.no_treasure_gain(G2, 0, theirs) < 0.0 and _act(_match(G2), 0, 0) < 0.0, "IA : ... pas pour un heros qui survivrait a mon donjon")

# --- Doc Scarecrow ----------------------------------------------------------------------------------------------

func _t_doc_scarecrow() -> void:
	var G := _G([_player(0, "TNL001", [_plain("mine", "trap", [1], 1)]), _player(1, "BMA002")])
	G["players"][0]["boss"]["treasures"] = []
	G["players"][1]["boss"]["treasures"] = []
	G["phase"] = "build"
	G["activePlayer"] = 0
	var strong := _hero("TNL073")
	strong["hp"] = 8
	G["town"] = [strong]
	(G["players"][0]["hand"] as Array).append(_plain("junk", "monster", [1], 0))
	var m := _match(G)
	_ok.call(AiWiki.scarecrow_value(G, 0, 0) > 0.0, "AiWiki : un heros costaud qui irait chez moi vaut un Doc Scarecrow")
	_ok.call(AI.score_move(m, 0, _mv("docScarecrow", [0, 0])) >= AiWiki.BUILD_FIRST - 6.0 * 2.0, "IA : Doc Scarecrow garde hors de portee le heros qui survivrait a mon donjon (avant de construire)")
	var weak := _hero("TNL073")
	weak["hp"] = 1
	G["town"] = [weak]
	_ok.call(AiWiki.scarecrow_value(G, 0, 0) == 0.0 and AI.score_move(m, 0, _mv("docScarecrow", [0, 0])) < 0.0, "IA : ... pas un heros qui mourrait chez moi")
	# un adversaire en tete (8 ames) recevrait l'ame d'un heros fragile
	var G2 := _G([_player(0, "TNL001", [_plain("mine", "trap", [1], 1)]), _player(1, "BMA002", [_plain("theirs", "trap", [1], 3), _plain("theirs2", "trap", [1], 3)])])
	G2["players"][0]["boss"]["treasures"] = []
	G2["players"][1]["boss"]["treasures"] = []
	G2["town"] = [weak]
	for _s in 8:
		(G2["players"][1]["souls"] as Array).append({"souls": 1})
	_ok.call(AiWiki.scarecrow_value(G2, 0, 0) >= 1.0, "AiWiki : on prive d'une ame un adversaire qui a deja 8 ames")

# --- sorts TNL ----------------------------------------------------------------------------------------------------------

func _t_tnl_spells() -> void:
	# Oh, Yeah! (echange) : Goblin Armory gagne un voisin Monster de plus -> +1 degat au total
	var G := _G([_player(0, "BMA001", [_room("BMA015"), _plain("m1", "monster", [1], 2), _plain("m2", "monster", [1], 2)]), _player(1, "BMA002")])
	G["phase"] = "build"
	G["activePlayer"] = 0
	_hand(G, 0).append(_spell("TNL063"))
	var m := _match(G)
	_ok.call(AiWiki.swap_gain(G, 0, 0, 1) == 1, "AiWiki.swap_gain : Goblin Armory entre deux Monster = +1 degat")
	_ok.call(AI.score_move(m, 0, _mv("playSpell", [0, {"mode": "swap", "a": 0, "b": 1}])) >= AiWiki.BUILD_FIRST, "IA : Oh, Yeah! echange deux salles quand l'ordre ajoute des degats")
	_ok.call(AI.score_move(m, 0, _mv("playSpell", [0, {"mode": "swap", "a": 1, "b": 2}])) < 0.0, "IA : ... pas pour un echange sans effet")
	# Surprise Gift : donjon presque plein, salle adverse de 4 degats, salle de 1 degat en main
	var G2 := _G([_player(0, "BMA001", [_plain("a"), _plain("b"), _plain("c"), _plain("d")]), _player(1, "BMA002", [_plain("big", "trap", [1], 4)])])
	G2["phase"] = "build"
	G2["activePlayer"] = 0
	_hand(G2, 0).append(_spell("TNL070"))
	_hand(G2, 0).append(_plain("weak", "monster", [1], 1))
	var m2 := _match(G2)
	_ok.call(AI.score_move(m2, 0, _mv("playSpell", [0, {}])) >= AiWiki.BUILD_FIRST, "IA : Surprise Gift couvre la grosse salle adverse avec une salle de 1 degat (mon donjon est presque plein)")
	(G2["players"][0]["dungeon"] as Array).remove_at(0)
	(G2["players"][0]["dungeon"] as Array).remove_at(0)
	_ok.call(AI.score_move(m2, 0, _mv("playSpell", [0, {}])) < 0.0, "IA : ... pas tant que j'ai de la place chez moi")
	var slots := TnlSpells.gift_slots(G2, 0)
	_ok.call(slots.size() == 1 and float((slots[0] as Dictionary)["ai"]) == 4.0, "Surprise Gift : la salle visee pese ses degats")

# --- The Omega 42 --------------------------------------------------------------------------------------------------------

func _t_crl_omega() -> void:
	var G := _G([_player(0, "BMA001", [_room("CRL012"), _room("BMA022")]), _player(1, "BMA002")])
	G["phase"] = "build"
	G["activePlayer"] = 0
	var m := _match(G)
	var adv1 := _plain("adv1", "trap", [4], 3, true) # tresor 4 : aucune salle du donjon n'en a -> carte morte
	_hand(G, 0).append(adv1)
	_ok.call(AiWiki.dead_advanced(G, G["players"][0], 0) == 1 and _act(m, 0, 0) >= AiWiki.BUILD_FIRST, "IA : The Omega 42 defausse une avancee qui ne peut se construire nulle part")
	_hand(G, 0).clear()
	_hand(G, 0).append(_plain("adv2", "trap", [int((_room("BMA022")["treasures"] as Array)[0])], 3, true))
	_ok.call(AiWiki.dead_advanced(G, G["players"][0], 0) == 0 and _act(m, 0, 0) < 0.0, "IA : ... pas une avancee que je vais construire")
	_hand(G, 0).append(_plain("adv3", "trap", [int((_room("BMA022")["treasures"] as Array)[0])], 3, true))
	_ok.call(_act(m, 0, 0) >= AiWiki.BUILD_FIRST, "IA : ... mais oui avec deux avancees en main")
	# les choix de suite : l'effet qui rapporte le plus, la carte morte d'abord
	G["pendingChoice"] = {"type": "omega-refire", "playerId": 0, "options": [{"roomIndex": 1, "mode": "build", "card": _room("BMA011")}, {"roomIndex": 0, "mode": "build", "card": _room("BMA034")}]}
	var p0: Dictionary = G["players"][0]
	_ok.call(AI._score_choice(G, p0, 0, 1) > AI._score_choice(G, p0, 0, 0), "IA : The Omega 42 rejoue Construction Zone plutot que Specter's Sanctum")
	_hand(G, 0).clear()
	_hand(G, 0).append_array([adv1, _plain("adv4", "trap", [int((_room("BMA022")["treasures"] as Array)[0])], 3, true)])
	G["pendingChoice"] = {"type": "omega-discard", "playerId": 0, "options": [{"card": _hand(G, 0)[1], "handIndex": 1}, {"card": adv1, "handIndex": 0}]}
	_ok.call(AI._score_choice(G, p0, 0, 1) > AI._score_choice(G, p0, 0, 0), "IA : The Omega 42 defausse l'avancee morte")

# --- Rise of the Minibosses ----------------------------------------------------------------------------------------------

func _t_rmb_rooms() -> void:
	# Training Camp : double la salle Monster devant le heros (marge 3, Monster de 3 devant)
	var G := _G([_player(0, "BMA001", [_room("RMB026"), _plain("m", "monster", [1], 3)]), _player(1, "BMA002")])
	_adventure(G, 0, _hero("TNL073"), 0, 6)
	_ok.call(AiWiki.kills(AiWiki.fate(G), 3) and _act(_match(G), 0, 0) > 0.0, "IA : Training Camp double la salle Monster qui fait mourir le heros de mon donjon")
	_adventure(G, 0, _hero("TNL073"), 0, 20)
	_ok.call(_act(_match(G), 0, 0) < 0.0, "IA : ... pas pour un heros qui survit de toute facon")
	# Endless Gallery : une icone Cleric de plus et le heros de la ville vient chez moi (egalite sinon)
	var G2 := _G([_player(0, "BMA001", [_room("RMB045"), _plain("mine", "monster", [1], 3), _plain("f1", "monster", [], 0), _plain("f2", "monster", [], 0), _plain("f3", "monster", [], 0)]), _player(1, "BMA002", [_plain("theirs", "monster", [1], 3)])])
	G2["players"][0]["boss"]["treasures"] = []
	G2["players"][1]["boss"]["treasures"] = []
	G2["phase"] = "build"
	G2["activePlayer"] = 0
	G2["town"] = [_hero("TNL073")] # 4 PV : meurt chez moi
	_hand(G2, 0).append(_plain("spare"))
	_ok.call(AiWiki.icon_gain(G2, 0, 0, 1) > 0.0 and AiWiki.icon_gain(G2, 0, 0, 2) == 0.0, "AiWiki.icon_gain : une icone Cleric fait venir le Cleric chez moi, pas une icone Fighter")
	_ok.call(_act(_match(G2), 0, 0) >= AiWiki.BUILD_FIRST, "IA : Endless Gallery (construction) quand elle gagne un heros")
	var icons: Array = Minibosses.list(G2, "icons")
	_ok.call(icons.is_empty(), "la simulation du leurre n'a laisse aucune icone")
	# The Keystone : des Coins servent (miniboss en main) et le donjon est bien rempli
	var G3 := _G([_player(0, "BMA001", [_room("RMB053"), _plain("a"), _plain("b"), _plain("c"), _plain("d")]), _player(1, "BMA002")])
	G3["phase"] = "build"
	G3["activePlayer"] = 0
	var m3 := _match(G3)
	_ok.call(_act(m3, 0, 0) < 0.0, "IA : The Keystone sans miniboss a payer : non")
	_hand(G3, 0).append(_minicard("RMB055"))
	_ok.call(_act(m3, 0, 0) < 0.0, "IA : ... ni sans salle en main pour reboucher l'emplacement")
	_hand(G3, 0).append(_plain("spare"))
	_ok.call(_act(m3, 0, 0) >= AiWiki.BUILD_FIRST, "IA : The Keystone (1 Coin par salle) quand un miniboss attend ses Coins")

func _t_rmb_boss_and_hand() -> void:
	# Ravenus (2 Coins) double la Monster de 3 qui fait mourir le heros ; Scott (je donne 1 Coin) ; Paywall (1 Coin) ; Shrooman Aviary (+3)
	var G1 := _G([_player(0, "BMA001", [_plain("r0", "monster", [1], 1), _plain("m", "monster", [1], 3)], 4), _player(1, "BMA002")])
	_adventure(G1, 0, _hero("TNL073"), 0, 4)
	_ok.call(AI.score_move(_match(G1), 0, _mv("rmbBoss", ["RMB006", -1])) >= 60.0, "IA : Ravenus (2 Coins) double la Monster qui fait mourir le heros de mon donjon")
	var G1b := _G([_player(0, "BMA001", [_plain("r0", "monster", [1], 1), _plain("m", "monster", [1], 3)], 4), _player(1, "BMA002")])
	_adventure(G1b, 0, _hero("TNL073"), 0, 20)
	_ok.call(AI.score_move(_match(G1b), 0, _mv("rmbBoss", ["RMB006", -1])) < 60.0, "IA : ... pas pour un heros qui survit de toute facon")
	# opposant : Scott est chez P1, ses Traps ont +1, le heros meurt de justesse a cause du +1
	var scott := _player(1, "RMB011", [_plain("t0", "trap", [1], 1), _plain("t1", "trap", [1], 2)], 3)
	scott["leveledUp"] = true
	var G2 := _G([_player(0, "BMA001", [], 3), scott])
	_adventure(G2, 1, _hero("TNL073"), 0, 3)
	var f2 := AiWiki.fate(G2)
	_ok.call(int(f2["traps"]) == 1 and int(f2["margin"]) <= 0 and AiWiki.saves(f2, 1), "scenario Scott : le +1 aux Traps fait mourir le heros de justesse")
	_ok.call(AI.score_move(_match(G2), 0, _mv("rmbBoss", ["RMB011", 1])) > 0.0, "IA : on donne 1 Coin a Scott quand son +1 est ce qui tue le heros")
	var G2b := _G([_player(0, "BMA001", [], 3), scott.duplicate(true)])
	_adventure(G2b, 1, _hero("TNL073"), 0, 20)
	_ok.call(AI.score_move(_match(G2b), 0, _mv("rmbBoss", ["RMB011", 1])) < 0.0, "IA : ... pas s'il meurt de toute facon / survit de toute facon")
	# Paywall (RMB046) est devant le heros adverse : un Coin = -1 degat
	var G3 := _G([_player(0, "BMA001", [], 3), _player(1, "BMA002", [_plain("r0", "monster", [1], 1), _room("RMB046")])])
	_adventure(G3, 1, _hero("TNL073"), 0, 4)
	var pay := AI.score_move(_match(G3), 0, _mv("rmbPay", [1, 1]))
	_ok.call(int(AiWiki.fate(G3)["margin"]) == 0 and pay > 0.0, "IA : Paywall, 1 Coin sauve le heros adverse qui meurt de justesse")
	_adventure(G3, 1, _hero("TNL073"), 0, 1)
	_ok.call(AI.score_move(_match(G3), 0, _mv("rmbPay", [1, 1])) < 0.0, "IA : ... pas s'il mourra quand meme")
	# Shrooman Aviary (+3) depuis la main
	var G4 := _opp_scene(3)
	_hand(G4, 0).append(_room("RMB027"))
	G4["players"][0]["coins"] = 0
	_ok.call(int(AiWiki.fate(G4)["margin"]) == -2 and AI.score_move(_match(G4), 0, _mv("rmbHand", [0, ""])) > 0.0, "IA : Shrooman Aviary (+3) quand cela sauve le heros adverse")
	var G4b := _opp_scene(0)
	_hand(G4b, 0).append(_room("RMB027"))
	_ok.call(AI.score_move(_match(G4b), 0, _mv("rmbHand", [0, ""])) < 0.0, "IA : ... pas s'il lui manque trop de PV")

func _t_rmb_spells() -> void:
	# Short Circuit (reponse a un sort sur la pile) : l'adversaire sans Coin voit son sort annule
	var G := _G([_player(0, "BMA001", [], 3), _player(1, "BMA002", [], 0)])
	G["phase"] = "build"
	G["stack"] = [{"id": "s1", "type": "spell", "playerId": 1, "card": _spell("TNL067"), "target": {}, "resolved": false}]
	_hand(G, 0).append(_spell("RMB077"))
	var m := _match(G)
	_ok.call(AI.score_move(m, 0, _mv("playSpell", [0, {"targetPlayerId": 1}])) >= 100.0, "IA : Short Circuit en reponse quand l'adversaire n'a aucun Coin")
	G["players"][1]["coins"] = 4
	_ok.call(AI.score_move(m, 0, _mv("playSpell", [0, {"targetPlayerId": 1}])) < 10.0, "IA : ... bien moins s'il peut payer")
	# Armor Up! : le moins de Coins qui sauvent le heros adverse
	var G2 := _opp_scene(3)
	_hand(G2, 0).append(_spell("RMB079"))
	G2["players"][0]["coins"] = 3
	var m2 := _match(G2)
	var hid: String = str(G2["adventure"]["hero"]["id"])
	var s0 := AI.score_move(m2, 0, _mv("playSpell", [0, {"heroId": hid, "pay": 0}]))
	var s1 := AI.score_move(m2, 0, _mv("playSpell", [0, {"heroId": hid, "pay": 1}]))
	_ok.call(s0 < 0.0 and s1 > 0.0, "IA : Armor Up! paie 1 Coin quand +1 ne suffit pas (marge -2) et +3 suffit")
	var G2b := _opp_scene(5)
	_hand(G2b, 0).append(_spell("RMB079"))
	G2b["players"][0]["coins"] = 3
	var s2 := AI.score_move(_match(G2b), 0, _mv("playSpell", [0, {"heroId": hid, "pay": 0}]))
	var s3 := AI.score_move(_match(G2b), 0, _mv("playSpell", [0, {"heroId": hid, "pay": 1}]))
	_ok.call(s2 > s3 and s2 > 0.0, "IA : ... et 0 Coin quand +1 suffit")

func _t_rmb_miniboss_powers() -> void:
	var sc := func(G: Dictionary, slot: int, lvl: int) -> float:
		return AI.score_move(_match(G), 0, _mv("activateMiniboss", [slot, lvl]))
	# Draculad niveau 2 : renvoie en ville le heros de mon donjon qui survit
	var G := _G([_player(0, "BMA001", [_with_mb(_plain("h"), "RMB057", 2), _plain("m", "monster", [1], 1)]), _player(1, "BMA002")])
	_adventure(G, 0, _hero("TNL073"), 0, 9)
	_ok.call(sc.call(G, 0, 2) > 0.0, "IA : Draculad (niveau 2) renvoie en ville le heros qui survivrait")
	_adventure(G, 0, _hero("TNL073"), 0, 1)
	_ok.call(sc.call(G, 0, 2) < 0.0, "IA : ... pas celui qui va mourir")
	# Spike niveau 2 : 2 degats au heros de la salle qui le tuent
	var G2b := _G([_player(0, "BMA001", [_with_mb(_plain("h"), "RMB055", 2), _plain("m", "monster", [1], 1)]), _player(1, "BMA002")])
	_adventure(G2b, 0, _hero("TNL073"), 0, 3)
	_ok.call(AiWiki.kills(AiWiki.fate(G2b), 2) and sc.call(G2b, 0, 2) > 0.0, "IA : Spike (niveau 2) quand ses 2 degats tuent le heros de la salle")
	# Rocky niveau 3 : +5 au heros adverse qui meurt de justesse
	var G3 := _G([_player(0, "BMA001", [_with_mb(_plain("h"), "RMB058", 3)]), _player(1, "BMA002", [_plain("r0", "monster", [1], 1), _plain("m", "monster", [1], 4)])])
	_adventure(G3, 1, _hero("TNL073"), 0, 3)
	_ok.call(AiWiki.saves(AiWiki.fate(G3), 5) and sc.call(G3, 0, 3) > 0.0, "IA : Rocky (niveau 3) donne +5 au heros adverse qui meurt de justesse")
	_adventure(G3, 1, _hero("TNL073"), 0, -2)
	_ok.call(sc.call(G3, 0, 3) < 0.0, "IA : ... pas s'il lui manque trop de PV")
	# Icicle Man niveau 3 : desactive la salle adverse qui tue le heros de justesse
	var G4 := _G([_player(0, "BMA001", [_with_mb(_plain("h"), "RMB061", 3)]), _player(1, "BMA002", [_plain("r0", "monster", [1], 1), _plain("m", "monster", [1], 4)])])
	_adventure(G4, 1, _hero("TNL073"), 0, 4)
	_ok.call(sc.call(G4, 0, 3) > 0.0, "IA : Icicle Man (niveau 3) desactive la salle de 4 degats qui tue le heros de justesse")
	# Kid Croak niveau 3 : -1 aux Monster adverses (marge 0 avec 1 Monster devant), niveau 2 : echange gratuit en construction
	var G5 := _G([_player(0, "BMA001", [_with_mb(_plain("h"), "RMB056", 3)]), _player(1, "BMA002", [_plain("r0", "monster", [1], 1), _plain("m", "monster", [1], 4)])])
	_adventure(G5, 1, _hero("TNL073"), 0, 4)
	_ok.call(sc.call(G5, 0, 3) > 0.0, "IA : Kid Croak (niveau 3) enleve 1 aux Monster qui tuent le heros adverse de justesse")
	var G6 := _G([_player(0, "BMA001", [_with_mb(_room("BMA015"), "RMB056", 2), _plain("m1", "monster", [1], 2), _plain("m2", "monster", [1], 2)]), _player(1, "BMA002")])
	G6["phase"] = "build"
	G6["activePlayer"] = 0
	_ok.call(sc.call(G6, 0, 2) >= AiWiki.BUILD_FIRST, "IA : Kid Croak (niveau 2) echange deux salles quand cela ajoute des degats")
	# Cerebella niveau 3 : le heros de mon donjon porte une capacite de carte
	var G7 := _G([_player(0, "BMA001", [_with_mb(_plain("h"), "RMB059", 3)]), _player(1, "BMA002")])
	_adventure(G7, 0, _hero("KSA016"), 0, 9)
	_ok.call(sc.call(G7, 0, 3) > 0.0, "IA : Cerebella (niveau 3) fait perdre sa capacite au Monster Hunter de mon donjon")
	(G7["players"][0]["entrance"] as Array).clear()
	_adventure(G7, 0, _hero("TNL073"), 0, 9)
	_ok.call(sc.call(G7, 0, 3) < 0.0, "IA : ... pas a un heros sans capacite")
	# Spike niveau 3 : renvoie en main un miniboss adverse deja promu
	var G8 := _G([_player(0, "BMA001", [_with_mb(_plain("h"), "RMB055", 3)]), _player(1, "BMA002", [_with_mb(_plain("x"), "RMB058", 2)])])
	_ok.call(sc.call(G8, 0, 3) > 0.0, "IA : Spike (niveau 3) renvoie en main un miniboss adverse de niveau 2")

# --- poids des choix -------------------------------------------------------------------------------------------------------

func _t_swap_weights() -> void:
	# Shellda / Kid Croak : le choix de la paire pese le gain de degats, un echange sans interet pese moins que « passer »
	var G := _G([_player(0, "BMA001", [_room("BMA015"), _plain("m1", "monster", [1], 2), _plain("m2", "monster", [1], 2)]), _player(1, "BMA002")])
	_ok.call(AiWiki.swap_ai(G, 0, 0, 0, 1) == 1.0 and AiWiki.swap_ai(G, 0, 0, 1, 2) < 0.0 and AiWiki.best_swap_ai(G, 0, 0) == 1.0, "AiWiki.swap_ai : +1 degat pour l'echange utile, -1.5 sinon")
	_ok.call(AiWiki.best_swap_ai(G, 0, 1) < 0.0, "AiWiki.swap_ai : rien a gagner dans un donjon adverse vide")

# --- construction immediate dans un nouvel emplacement (Fangroot Garden, Brassknuckle) ----------------------------------------

func _t_build_in_new_slot() -> void:
	var G := _G([_player(0, "BMA001", [_plain("base", "trap", [1], 1)]), _player(1, "BMA002")])
	_hand(G, 0).append(_plain("n1", "monster", [2], 2))
	var card: Dictionary = _hand(G, 0)[0]
	var slots := TnlAbilities.build_slots(G, 0, card, true)
	_ok.call(slots.size() == 2 and int((slots[0] as Dictionary)["roomIndex"]) == -1 and int((slots[1] as Dictionary)["roomIndex"]) == 0, "Fangroot Garden : un nouvel emplacement OU par-dessus une salle")
	_ok.call(TnlAbilities.build_slots(G, 0, card).size() == 1, "Wild Monster (« over an existing Room ») : seulement par-dessus")
	var adv := _plain("adv", "monster", [1], 3, true)
	_ok.call(TnlAbilities.build_slots(G, 0, adv, true).size() == 1, "une salle avancee ne se pose jamais dans un nouvel emplacement")
	# effet : la salle va a l'entree (index 0), la pile existante glisse, les effets indexes et le heros actif suivent
	G["effects"]["deactivatedRooms"].append({"playerId": 0, "roomIndex": 0})
	G["effects"]["roomDamageBonus"].append({"playerId": 0, "roomIndex": 0, "amount": 2})
	_adventure(G, 0, _hero("TNL073"), 0, 5)
	G["adventure"]["nearest"] = 0
	TnlAbilities.build_now(G, 0, card, -1, "Fangroot Garden")
	var d: Array = G["players"][0]["dungeon"]
	_ok.call(d.size() == 2 and str((d[0] as Array)[0]["id"]) == "n1" and not bool((d[0] as Array)[0].get("faceDown", false)) and str((d[1] as Array)[0]["id"]) == "base" and _hand(G, 0).is_empty(),
		"Fangroot Garden : la salle est posee face visible a l'entree du donjon")
	_ok.call(int(G["effects"]["deactivatedRooms"][0]["roomIndex"]) == 1 and int(G["effects"]["roomDamageBonus"][0]["roomIndex"]) == 1 and int(G["adventure"]["roomIndex"]) == 1 and int(G["adventure"]["nearest"]) == 1,
		"... les effets par emplacement et le heros actif glissent d'un cran")
	# dungeon plein : plus de nouvel emplacement
	var full := _G([_player(0, "BMA001", [_plain("a"), _plain("b"), _plain("c"), _plain("d"), _plain("e")]), _player(1, "BMA002")])
	_ok.call(TnlAbilities.build_slots(full, 0, card, true).size() == 5, "donjon plein : seulement par-dessus les 5 salles")
	# de bout en bout : le choix Fangroot propose les deux, l'IA prend le nouvel emplacement
	var G2 := _G([_player(0, "BMA001", [_plain("base", "trap", [1], 1)]), _player(1, "BMA002")])
	_hand(G2, 0).append(_plain("n1", "monster", [2], 2))
	var m2 := _match(G2)
	G2["pendingChoice"] = RoomAbilities.on_hero_died_in_room(G2, 0, _room("TNL026"))
	_ok.call(str(G2["pendingChoice"].get("step", "")) == "build_card", "Fangroot Garden : choix de la salle")
	m2._resolve_choice(0, 0)
	_ok.call(str(G2["pendingChoice"].get("step", "")) == "build_slot" and (G2["pendingChoice"]["options"] as Array).size() == 2, "Fangroot Garden : puis de l'emplacement (nouveau / par-dessus)")
	_ok.call(AI._score_choice(G2, G2["players"][0], 0, 0) > AI._score_choice(G2, G2["players"][0], 0, 1), "IA : prefere le nouvel emplacement quand il y a de la place")
	m2._resolve_choice(0, 0)
	_ok.call((G2["players"][0]["dungeon"] as Array).size() == 2 and str(((G2["players"][0]["dungeon"] as Array)[0] as Array)[0]["id"]) == "n1", "Fangroot Garden : construite dans un nouvel emplacement")
	# Brassknuckle (niveau 2) : « draw a Room card. You may immediately build that Room » -> aussi dans un nouvel emplacement
	var bk := _with_mb(_plain("A", "monster", [1], 2), "RMB063", 2)
	var G3 := _G([_player(0, "BMA001", [bk]), _player(1, "BMA002")])
	(G3["decks"]["rooms"] as Array).append(_plain("drawn", "trap", [2], 2))
	var m3 := _match(G3)
	Minibosses.on_hero_died(G3, 0, bk)
	var pc3: Dictionary = G3["pendingChoice"]
	_ok.call(str(pc3.get("step", "")) == "rmb_build_slot" and (pc3["options"] as Array).size() == 2 and int((pc3["options"] as Array)[0]["roomIndex"]) == -1, "Brassknuckle : la salle piochee peut aller dans un nouvel emplacement ou par-dessus")
	m3._resolve_choice(0, 0)
	_ok.call((G3["players"][0]["dungeon"] as Array).size() == 2 and str(((G3["players"][0]["dungeon"] as Array)[0] as Array)[0]["id"]) == "drawn", "Brassknuckle : construite a l'entree du donjon")


# --- IA de l'APK (ApkAI.gd, FixedAI) : decisions deterministes de construction, de defausse et de pioche ---------------------

## ApkAI.ROOM_FACTORS = ai_info.json de chaque paquet (les assets ne sont pas exportes : la copie est dans le code).
func _t_apk_factors() -> void:
	var seen := 0
	var ok := true
	for deck in ["BaseDeck", "PlayerChoice", "HiddenHeros"]:
		var f := FileAccess.open("res://assets/data/%s/ai_info.json" % deck, FileAccess.READ)
		var d: Dictionary = JSON.parse_string(f.get_as_text())
		for r in d.get("RoomCards", []):
			seen += 1
			ok = ok and ApkAI.ROOM_FACTORS.has(str(r["CardNumber"])) and ApkAI.ROOM_FACTORS[str(r["CardNumber"])] == r["Factors"]
	_ok.call(ok and seen == ApkAI.ROOM_FACTORS.size() and seen == 31, "ApkAI.ROOM_FACTORS == ai_info.json (31 salles BaseDeck ; PlayerChoice et HiddenHeros n'en ont pas)")

func _t_apk_values() -> void:
	var G := _G([_player(0, "BMA001"), _player(1, "BMA002")])
	G["turn"] = 1
	_ok.call(ApkAI.phase(G) == "early", "ApkAI.phase : le 1er tour est Early (NumberOfTurns n'est incremente qu'en fin de tour)")
	G["turn"] = 2
	var mid_ok: bool = ApkAI.phase(G) == "mid"
	G["turn"] = 4
	mid_ok = mid_ok and ApkAI.phase(G) == "mid"
	G["turn"] = 5
	_ok.call(mid_ok and ApkAI.phase(G) == "late", "ApkAI.phase : tours 2-4 Mid, a partir du 5e Late")
	G["phase"] = "setup"
	_ok.call(ApkAI.phase(G) == "setup", "ApkAI.phase : Setup pendant la mise en place")
	# Goblin Armory : 1 degat, 2 tresors, facteur Combo -> early 25+0+25, mid 25+100+0, late 25+75+50
	var gob := _plain("BMA015", "monster", [2, 2], 1)
	_ok.call(ApkAI.base_value(gob, "early") == 50.0 and ApkAI.base_value(gob, "mid") == 125.0 and ApkAI.base_value(gob, "late") == 150.0, "ApkAI.base_value : tables par phase + facteur Combo de Goblin Armory")
	# plus aucun bonus invente : une avancee n'a pas +30
	_ok.call(ApkAI.base_value(_plain("x", "monster", [1], 3, true), "early") == 200.0, "ApkAI.base_value : pas de +30 « avancee » (degats 3 : 150 + 1 tresor : 50)")
	# Mimic Vault (Lure) : -100 en early, +25 en mid, +150 en late
	var mimic := _plain("BMA036", "trap", [1], 0)
	_ok.call(ApkAI.base_value(mimic, "early") == -50.0 and ApkAI.base_value(mimic, "mid") == 50.0 and ApkAI.base_value(mimic, "late") == 225.0, "ApkAI.base_value : facteur Lure par phase")
	# BaitHeroFactor : un heros de la ville que mon SEUL donjon attire, et qui survit : -100 x blessures + 1
	var p0 := _player(0, "BMA001")
	var p1 := _player(1, "BMA002")
	(p0["boss"] as Dictionary)["treasures"] = []
	(p1["boss"] as Dictionary)["treasures"] = []
	p0["wounds"] = [{"wounds": 1}]
	var G2 := _G([p0, p1])
	G2["turn"] = 1
	var hero := {"id": "H", "name": "H", "treasure": 1, "hp": 10, "souls": 1, "wounds": 1}
	G2["town"] = [hero]
	var big := _plain("big", "monster", [1], 4)
	_ok.call(ApkAI.room_value(G2, p0, 0, big, "early", [null]) == 225.0 - 99.0, "ApkAI : leurre d'un heros qui survit = -100 x blessures + 1")
	hero["hp"] = 3
	_ok.call(ApkAI.room_value(G2, p0, 0, big, "early", [null]) == 225.0, "ApkAI : ... aucun malus si le donjon tue le heros (pas de bonus invente non plus)")
	hero["hp"] = 10
	(p1["dungeon"] as Array).append([_plain("o", "monster", [1], 1)])
	_ok.call(ApkAI.room_value(G2, p0, 0, big, "early", [null]) == 225.0, "ApkAI : ... ni si l'adversaire a deja autant de tresors (pas l'unique meilleur appat)")
	# Dizzygas / Goblin Armory : +-100 selon le type de la derniere salle posee (index Godot 0), seulement si le donjon n'est pas plein
	var G3 := _G([_player(0, "BMA001", [_plain("trap1", "trap", [1], 1)]), _player(1, "BMA002")])
	G3["turn"] = 3
	var dz := _plain("BMA029", "trap", [1], 2)
	var base: float = ApkAI.base_value(dz, "mid")
	_ok.call(ApkAI.room_value(G3, G3["players"][0], 0, dz, "mid", [null]) == base + 100.0, "ApkAI : Dizzygas Hallway apres une Trap = +100")
	var G4 := _G([_player(0, "BMA001", [_plain("mon", "monster", [1], 1)]), _player(1, "BMA002")])
	G4["turn"] = 3
	_ok.call(ApkAI.room_value(G4, G4["players"][0], 0, dz, "mid", [null]) == base - 100.0, "ApkAI : ... apres une Monster = -100")
	# Setup : Dizzygas jamais en premier ; Construction Zone +10000 avec une avancee Fighter/Thief en main
	G4["phase"] = "setup"
	_ok.call(ApkAI.room_value(G4, _player(0, "BMA001"), 0, dz, "setup", [null]) == 0.0, "ApkAI : Setup, Dizzygas sur un donjon vide = 0 (-1000, plancher)")
	var cz := _plain("BMA034", "trap", [2, 4], 1)
	var pz := _player(0, "BMA001")
	(pz["hand"] as Array).append(_plain("adv", "monster", [4], 2, true))
	_ok.call(ApkAI.room_value(G4, pz, 0, cz, "setup", [null]) == 10000.0 + ApkAI.base_value(cz, "setup"), "ApkAI : Setup, Construction Zone +10000 avec une avancee Thief en main")
	# construire par-dessus : 300 si l'ancienne est avancee, 0 si ordinaire -> avancee, sinon la valeur de l'ancienne
	var old := _plain("old", "monster", [1], 2)
	_ok.call(ApkAI.over_penalty(big, _plain("a", "monster", [1], 1, true), "early") == 300.0 and ApkAI.over_penalty(_plain("n", "monster", [1], 1, true), old, "early") == 0.0 and ApkAI.over_penalty(big, old, "early") == 150.0, "ApkAI.over_penalty : 300 / 0 / valeur de la salle recouverte")

func _builds(hand_idx: Array, slots: Array = [null]) -> Array:
	var out: Array = []
	for hi in hand_idx:
		for s in slots:
			out.append(_mv("buildRoom", [hi] if s == null else [hi, s]))
	return out

func _t_apk_build_plan() -> void:
	var G := _G([_player(0, "BMA001"), _player(1, "BMA002")])
	G["turn"] = 1
	var hand := _hand(G, 0)
	hand.append(_plain("B", "monster", [1], 2)) # 100 + 50 = 150
	hand.append(_plain("A", "monster", [1, 1], 3)) # 150 + 0 = 150, plus de degats : gagne l'egalite
	hand.append(_plain("C", "monster", [1, 1], 3)) # idem, apres A dans la main
	_ok.call(int(ApkAI.plan(G, 0, _builds([0, 1, 2]))["pick"]) == 1, "FixedAI : egalite de valeur -> degats decroissants, puis ordre de la main")
	hand.clear()
	hand.append(_plain("Z", "monster", [1, 1], 0)) # 0 + 0 = 0
	_ok.call(int(ApkAI.plan(G, 0, _builds([0]))["pick"]) == -1, "FixedAI : aucune construction quand la meilleure salle vaut 0")
	# emplacements : on couvre la salle qui rapporte le moins ; egalite -> degats du dessus croissants, puis index C# croissant (= index Godot decroissant)
	var d3 := _plain("d3", "monster", [1, 1], 3) # 150
	var d2 := _plain("d2", "monster", [1], 2) # 150
	var d1 := _plain("d1", "monster", [1], 1) # 75
	var G2 := _G([_player(0, "BMA001", [d3, d2, d1.duplicate(), d1.duplicate()]), _player(1, "BMA002")])
	G2["turn"] = 1
	_hand(G2, 0).append(_plain("new", "monster", [1], 4)) # 225
	var plan: Dictionary = ApkAI.plan(G2, 0, _builds([0], [0, 1, 2, 3]))
	_ok.call(int(plan["pick"]) == 3, "FixedAI : emplacement = salle recouverte la moins precieuse, egalite -> index C# croissant (pile 3 = la plus ancienne)")
	G2["players"][0]["dungeon"] = [[d3], [d2]]
	plan = ApkAI.plan(G2, 0, _builds([0], [0, 1]))
	_ok.call(int(plan["pick"]) == 1, "FixedAI : egalite de valeur de pose -> le dessus qui fait le moins de degats")
	# les rangs flottants (utilises par la mesure d'accord) ordonnent comme le choix
	var keys: Array = plan["keys"]
	_ok.call(float(keys[1]) > float(keys[0]), "ApkAI.plan : rang flottant coherent avec le choix")
	# Minotaur's Maze : -1000 dans le dernier emplacement (index C# 4)
	var G3 := _G([_player(0, "BMA001", [_plain("a"), _plain("b"), _plain("c"), _plain("d")]), _player(1, "BMA002")])
	G3["turn"] = 3
	_hand(G3, 0).append(_plain("BMA017", "monster", [1], 3))
	var p3 := ApkAI.plan(G3, 0, _builds([0], [null, 0, 1, 2, 3]))
	_ok.call(int(p3["pick"]) in [1, 2, 3, 4], "FixedAI : Minotaur's Maze ne va pas dans le 5e emplacement (nouvel emplacement, index C# 4) quand une pose par-dessus rapporte")
	# Goblin Armory, donjon plein : voisin Monster +500, non-Monster -500, premier emplacement -200
	var rooms: Array = [_plain("t0", "trap", [1], 1), _plain("m1", "monster", [1], 1), _plain("t2", "trap", [1], 1), _plain("t3", "trap", [1], 1), _plain("t4", "trap", [1], 1)]
	var G4 := _G([_player(0, "BMA001", rooms), _player(1, "BMA002")]) # g0 = t0 (la plus recente)
	G4["turn"] = 3
	_hand(G4, 0).append(_plain("BMA015", "monster", [2, 2], 1))
	var p4 := ApkAI.plan(G4, 0, _builds([0], [0, 1, 2, 3, 4]))
	# c = 4 - g, le voisin est c - 1 : la Monster m1 (g1, c3) a pour voisine suivante c4 = g0
	_ok.call(int(p4["pick"]) == 0, "FixedAI : Goblin Armory dans un donjon plein se pose juste apres une Monster")

func _t_apk_discard() -> void:
	var G := _G([_player(0, "BMA001"), _player(1, "BMA002")])
	G["phase"] = "setup"
	var p: Dictionary = G["players"][0]
	var hand := _hand(G, 0)
	hand.append(_plain("r0", "monster", [1], 4)) # 225
	hand.append(_plain("r1", "monster", [1], 1)) # 75
	hand.append(_plain("r2", "monster", [1, 1], 1)) # 25
	hand.append(_plain("r3", "monster", [1], 2)) # 150
	hand.append(_plain("r4", "monster", [1], 3, true)) # 200 - 100 : une avancee ne se batit pas sur un donjon vide
	hand.append(_spell("BMA049")) # 0,4 x 225 = 90
	hand.append(_spell("BMA048"))
	_ok.call(ApkAI.opening_discards(G, p, hand) == [1, 2], "FixedAI : defausse d'ouverture = les 2 valeurs les plus basses (r2 = 25, r1 = 75)")
	hand[2] = _plain("r2", "monster", [1], 4)
	_ok.call(ApkAI.opening_discards(G, p, hand) == [1, 5], "FixedAI : sort = 0,4 x meilleure salle ; egalite stable (premier sort) ; l'avancee non batie vaut 100")
	_ok.call(AI.select_opening_discards(hand, p, G) == [1, 5], "AI.select_opening_discards passe par ApkAI")
	# DrawCalculator : probabilite de piocher une salle selon les salles batissables en main
	var G2 := _G([_player(0, "BMA001"), _player(1, "BMA002")])
	G2["turn"] = 1
	var p2: Dictionary = G2["players"][0]
	_ok.call(ApkAI.draw_room_probability(G2, p2, 0) == 1.0, "ApkAI.draw_room_probability : main sans salle = 1")
	_hand(G2, 0).append(_plain("a"))
	_ok.call(ApkAI.draw_room_probability(G2, p2, 0) == 0.75, "... une salle = 0,75 (Early)")
	_hand(G2, 0).append(_plain("b"))
	var early_two: bool = ApkAI.draw_room_probability(G2, p2, 0) == 0.25
	G2["turn"] = 3
	var mid_two: bool = ApkAI.draw_room_probability(G2, p2, 0) == 0.15
	G2["turn"] = 6
	_ok.call(early_two and mid_two and ApkAI.draw_room_probability(G2, p2, 0) == 0.1, "... deux salles = 0,25 / 0,15 / 0,1 (Early / Mid / Late)")

## InternalDoPlayerActions : une capacite d'abord, PUIS la construction ; la construction ne se compare jamais au score d'un sort.
func _t_apk_pick_order() -> void:
	var G := _G([_player(0, "BMA001", [_plain("d1"), _plain("d2")]), _player(1, "BMA002")], ["base"])
	G["turn"] = 3 # Mid : CheckBMA049 ne joue jamais en Setup / Early ; notre donjon (2 salles) depasse la moyenne adverse (0) d'au moins 1
	G["phase"] = "build"
	G["activePlayer"] = 0
	_hand(G, 0).append(_plain("room", "monster", [1], 4))
	_hand(G, 0).append(_spell("BMA049"))
	var m := _match(G)
	var mv = AI.pick_move(m, 0)
	_ok.call(mv != null and str(mv["type"]) == "playSpell", "IA : en phase de construction, le sort (Kobold Strike) est joue AVANT la construction")
	mv = AI.pick_move(m, 0)
	_ok.call(mv != null and str(mv["type"]) == "buildRoom", "IA : une seule consultation des capacites par fenetre (UseAbility), puis elle construit")
	_hand(G, 0).remove_at(1)
	mv = AI.pick_move(m, 0)
	_ok.call(mv != null and str(mv["type"]) == "buildRoom", "IA : sans capacite, elle construit")
	_hand(G, 0)[0] = _plain("zero", "monster", [], 0) # Mid : 0 degats, 0 tresor = 0
	mv = AI.pick_move(m, 0)
	_ok.call(mv == null or str(mv["type"]) in ["passBuild", "pass"], "IA : une salle qui vaut 0 n'est pas construite (FixedAI)")
	m.queue_free()

# --- sorts et capacites de salle (AbilityCalculator) --------------------------------------------------------------------------------

## Cartes eligibles (ids tries) du joueur `pid` : ApkAI.abilities sur les coups legaux.
func _elig(G: Dictionary, pid: int) -> Array:
	var m := _match(G)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var out: Array = []
	for o in ApkAI.abilities(G, pid, m.legal_moves(pid), rng):
		out.append(str(((o as Dictionary)["card"] as Dictionary)["id"]))
	out.sort()
	m.queue_free()
	return out

## L'entree eligible de la carte `id` (null si absente).
func _entry(G: Dictionary, pid: int, id: String) -> Variant:
	var m := _match(G)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var found = null
	for o in ApkAI.abilities(G, pid, m.legal_moves(pid), rng):
		if str(((o as Dictionary)["card"] as Dictionary)["id"]) == id:
			found = o
	m.queue_free()
	return found

## Scene d'aventure : le heros de P1 est dans la salle 0 de son donjon (trap 2 / monster 3 devant lui, marge = hp - 5), P0 tient `spell_id`.
func _spell_scene(spell_id: String, hp: int, turn := 3) -> Dictionary:
	var G := _opp_scene(hp)
	G["sets"] = ["base"]
	G["turn"] = turn
	_hand(G, 0).append(_spell(spell_id))
	return G

func _t_apk_spells_checks() -> void:
	# CheckBMA041 Assassin : l'adversaire qui attire le heros le tue de justesse (PV apres donjon dans (-3;0])
	_ok.call(_elig(_spell_scene("BMA041", 5), 0) == ["BMA041"], "Assassin : heros a 0 PV apres le donjon adverse -> eligible")
	_ok.call(_elig(_spell_scene("BMA041", 3), 0) == ["BMA041"] and _elig(_spell_scene("BMA041", 2), 0).is_empty(), "Assassin : -2 oui, -3 non (borne ouverte)")
	_ok.call(_elig(_spell_scene("BMA041", 7), 0).is_empty(), "Assassin : le heros survit au donjon adverse -> pas la peine")
	_ok.call(_elig(_spell_scene("BMA041", 5, 1), 0).is_empty(), "Assassin : jamais en Early (CheckBMA041)")
	var e = _entry(_spell_scene("BMA041", 5), 0, "BMA041")
	_ok.call(e != null and e["move"] != null and str((((e["move"] as Dictionary)["args"] as Array)[1] as Dictionary)["heroId"]) == "TNL073" and (e["t"] as Array).size() == 1, "Assassin : cible preregle = le heros actif")
	# CheckBMA046 Freeze : geler la salle la plus dure (monster 3) sauverait le heros
	var f = _entry(_spell_scene("BMA046", 3), 0, "BMA046")
	var ft: Dictionary = (((f["move"] as Dictionary)["args"] as Array)[1] as Dictionary) if f != null and f["move"] != null else {}
	_ok.call(f != null and int(ft.get("roomIndex", -1)) == 2 and int(ft.get("targetPlayerId", -1)) == 1, "Freeze : cible = la salle la plus dure devant le heros")
	_ok.call(_elig(_spell_scene("BMA046", 2), 0).is_empty() and _elig(_spell_scene("BMA046", 5), 0) == ["BMA046"], "Freeze : geler ne sauve pas un heros a -3 ; hp 5 (0 apres donjon) : le gel le sauve")
	# CheckBMA048 Jeopardy : moins de cartes que la moyenne entiere adverse - 1 ; CheckBMA049 Kobold Strike : donjon >= moyenne + 1
	var G := _G([_player(0, "BMA001"), _player(1, "BMA002")], ["base"])
	G["turn"] = 3
	G["phase"] = "build"
	G["activePlayer"] = 0
	_hand(G, 0).append(_spell("BMA048"))
	_fill_hand(G, 1, 2)
	_ok.call(_elig(G, 0) == ["BMA048"], "Jeopardy : 1 carte contre une moyenne adverse de 2 -> eligible (1 <= 2 - 1)")
	_hand(G, 1).clear()
	_fill_hand(G, 1, 1)
	_ok.call(_elig(G, 0).is_empty(), "Jeopardy : 1 carte contre 1 -> pas moins que la moyenne - 1")
	var G2 := _G([_player(0, "BMA001", [_plain("a"), _plain("b")]), _player(1, "BMA002", [_plain("c")])], ["base"])
	G2["turn"] = 3
	G2["phase"] = "build"
	G2["activePlayer"] = 0
	_hand(G2, 0).append(_spell("BMA049"))
	_ok.call(_elig(G2, 0) == ["BMA049"], "Kobold Strike : 2 salles contre 1 -> eligible")
	G2["turn"] = 1
	_ok.call(_elig(G2, 0).is_empty(), "Kobold Strike : jamais en Early")
	# CheckBMA050 Motivation : un adversaire a au moins 1 salle de plus (condition de la carte) et 2 salles constructibles
	var G3 := _G([_player(0, "BMA001", [_plain("a")]), _player(1, "BMA002", [_plain("c"), _plain("d")])], ["base"])
	G3["turn"] = 3
	G3["phase"] = "build"
	G3["activePlayer"] = 0
	_hand(G3, 0).append(_spell("BMA050"))
	_hand(G3, 0).append(_plain("r1", "monster", [1], 2))
	_ok.call(_elig(G3, 0).is_empty(), "Motivation : une seule salle constructible -> non")
	_hand(G3, 0).append(_plain("r2", "trap", [1], 2))
	_ok.call(_elig(G3, 0) == ["BMA050"], "Motivation : deux salles constructibles et un adversaire plus grand -> eligible")
	(G3["players"][1] as Dictionary)["dungeon"] = [[_plain("c")]]
	_ok.call(_elig(G3, 0).is_empty(), "Motivation : aucun adversaire n'a une salle de plus que nous -> condition de la carte fausse")
	# CheckBMA053 Teleportation : jamais jouee (PV apres donjon <= 0 est impossible dans le slot 0)
	var G4 := _G([_player(0, "BMA001", [_plain("a"), _plain("b")]), _player(1, "BMA002")], ["base"])
	G4["turn"] = 6
	_adventure(G4, 0, _hero("TNL073"), 1, 4)
	_hand(G4, 0).append(_spell("BMA053"))
	_ok.call(_elig(G4, 0).is_empty(), "Teleportation : jamais eligible (CheckBMA053)")
	# toute carte sans CheckXXX n'est JAMAIS jouee (AbilityCalculator : `_ => null`)
	var G5 := _G([_player(0, "BMA001", [_plain("a")]), _player(1, "BMA002")], ["base"])
	G5["turn"] = 3
	G5["phase"] = "build"
	G5["activePlayer"] = 0
	_hand(G5, 0).append({"id": "BMA099", "name": "Sans Check", "isSpell": true, "category": 4})
	var m5 := _match(G5)
	var legal_n := 0
	for mv in m5.legal_moves(0):
		legal_n += 1 if str((mv as Dictionary)["type"]) == "playSpell" else 0
	var pick = AI.pick_move(m5, 0)
	_ok.call(legal_n == 1 and _elig(G5, 0).is_empty() and (pick == null or str(pick["type"]) != "playSpell"), "une carte sans CheckXXX est legale mais l'IA ne la joue jamais")
	m5.queue_free()
	# CheckKSA013 T.P.K. : toujours, sur tous les boss
	var G6 := _G([_player(0, "BMA001"), _player(1, "BMA002")], ["base"])
	G6["phase"] = "build"
	G6["activePlayer"] = 0
	_hand(G6, 0).append(_spell("KSA013"))
	var k = _entry(G6, 0, "KSA013")
	_ok.call(k != null and k["move"] != null and (((k["t"] as Array)[0] as Array)[2] as Array).size() == 2, "T.P.K. : toujours eligible, cibles = tous les boss")
	# Exhaustion (BMA044), Late seulement : le heros de NOTRE donjon survivrait avec 1..DungeonSize PV
	var G7 := _G([_player(0, "BMA001", [_plain("a", "monster", [1], 1), _plain("b", "monster", [1], 2)]), _player(1, "BMA002")], ["base"])
	_adventure(G7, 0, _hero("TNL073"), 0, 5) # reste a traverser la salle g1 (2 degats) : 3 PV apres le donjon, 2 salles
	_hand(G7, 0).append(_spell("BMA044"))
	G7["turn"] = 4
	var mid_none: bool = _elig(G7, 0).is_empty()
	G7["turn"] = 6
	_ok.call(mid_none and _elig(G7, 0).is_empty(), "Exhaustion : 3 PV apres donjon > DungeonSize (2) -> non, et jamais avant Late")
	(G7["adventure"] as Dictionary)["hp"] = 4 # 4 - 2 = 2 <= 2 salles
	_ok.call(_elig(G7, 0) == ["BMA044"], "Exhaustion : 2 PV apres donjon <= DungeonSize -> eligible")

## Giant Size ne vise JAMAIS une salle Trap (le bogue de CheckBMA040And047 l.844-847 n'est pas copie), Annihilator jamais une Monster.
func _t_apk_giant_size_type() -> void:
	# le heros de P0 est dans sa salle g0 (monster) ; devant lui : trap (g1, 2 degats), monster (g2, 3 degats)
	for sid in ["BMA047", "BMA040"]:
		var G := _G([_player(0, "BMA001", [_plain("m0", "monster", [1], 1), _plain("t1", "trap", [1], 2), _plain("m2", "monster", [1], 3)]), _player(1, "BMA002")], ["base"])
		G["turn"] = 3
		_adventure(G, 0, _hero("TNL073"), 0, 7) # 7 - 5 = 2 PV apres le donjon : dans (0;3]
		_hand(G, 0).append(_spell(sid))
		var want := "monster" if sid == "BMA047" else "trap"
		var all_ok := true
		var seen := 0
		for seed_i in 30:
			var m := _match(G)
			var rng := RandomNumberGenerator.new()
			rng.seed = seed_i + 1
			for o in ApkAI.abilities(G, 0, m.legal_moves(0), rng):
				seen += 1
				var tgt: Dictionary = (((o as Dictionary)["move"] as Dictionary)["args"] as Array)[1]
				var room: Dictionary = BossEngine.active_room(G["players"][int(tgt["targetPlayerId"])]["dungeon"][int(tgt["roomIndex"])])
				all_ok = all_ok and str(room["type"]) == want
			m.queue_free()
		_ok.call(seen == 30 and all_ok, "%s : la cible est toujours une salle %s (30 tirages)" % [sid, want])

## Spell Battle : seuls Counterspell (BMA043) et All-Seeing Eye (BMA025) sont evalues (AbilityCalculator.cs l.22-30).
func _t_apk_spell_battle() -> void:
	var G := _G([_player(0, "BMA001", [_plain("a")]), _player(1, "BMA002", [_plain("b")])], ["base"])
	G["turn"] = 3
	G["phase"] = "build"
	G["activePlayer"] = 0
	_hand(G, 1).append(_spell("BMA043"))
	_hand(G, 1).append(_spell("BMA046"))
	var jeopardy := _spell("BMA048")
	G["stack"] = [{"id": "spell-x", "type": "spell", "playerId": 0, "card": jeopardy, "target": {}, "resolved": false}]
	var m := _match(G)
	G["activePlayer"] = 1 # le repondant courant
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var opts: Array = ApkAI.abilities(G, 1, m.legal_moves(1), rng)
	_ok.call(opts.size() == 1 and str((opts[0]["card"] as Dictionary)["id"]) == "BMA043", "Spell Battle : sur un Jeopardy adverse (tous les joueurs vises) -> Counterspell seul (Freeze est ignore)")
	G["stack"] = [{"id": "spell-y", "type": "spell", "playerId": 0, "card": _spell("BMA050"), "target": {}, "resolved": false}]
	_ok.call(ApkAI.abilities(G, 1, m.legal_moves(1), rng).is_empty(), "Spell Battle : Motivation adverse ne nous vise pas -> pas de Counterspell")
	G["stack"] = [{"id": "spell-x", "type": "spell", "playerId": 0, "card": jeopardy, "target": {}, "resolved": false}]
	G["turn"] = 1
	_ok.call(ApkAI.abilities(G, 1, m.legal_moves(1), rng).is_empty(), "Spell Battle : pas de Counterspell en Early (CheckBMA043)")
	# All-Seeing Eye : defausse Jeopardy en priorite (puis Kobold Strike, sinon un sort jouable)
	var G2 := _G([_player(0, "BMA001"), _player(1, "BMA002", [_room("BMA025")])], ["base"])
	G2["turn"] = 3
	G2["phase"] = "build"
	G2["activePlayer"] = 1
	_hand(G2, 1).append(_spell("BMA046"))
	_hand(G2, 1).append(_spell("BMA049"))
	_hand(G2, 1).append(_spell("BMA048"))
	G2["stack"] = [{"id": "spell-z", "type": "spell", "playerId": 0, "card": _spell("BMA048"), "target": {}, "resolved": false}]
	var m2 := _match(G2)
	var o2: Array = ApkAI.abilities(G2, 1, m2.legal_moves(1), rng)
	var discarded := ""
	if o2.size() == 1:
		discarded = str(((((o2[0]["t"] as Array)[0] as Array)[2] as Array)[0] as Dictionary)["id"])
	_ok.call(o2.size() == 1 and str((o2[0]["card"] as Dictionary)["id"]) == "BMA025" and discarded == "BMA048", "All-Seeing Eye : un Jeopardy adverse nous vise -> on defausse NOTRE Jeopardy d'abord")
	G2["stack"] = [{"id": "spell-z", "type": "spell", "playerId": 0, "card": _spell("BMA050"), "target": {}, "resolved": false}]
	_ok.call(ApkAI.abilities(G2, 1, m2.legal_moves(1), rng).is_empty(), "All-Seeing Eye : un sort adverse qui ne designe pas notre boss -> non")
	m.queue_free()
	m2.queue_free()

func _t_apk_rooms_checks() -> void:
	# CheckBMA027 Bottomless Pit : le heros est dans CE gouffre et survivrait au reste du donjon
	var G := _G([_player(0, "BMA001", [_room("BMA027"), _plain("t1", "trap", [1], 2)]), _player(1, "BMA002")], ["base"])
	G["turn"] = 3
	_adventure(G, 0, _hero("TNL073"), 0, 6) # reste 2 degats devant lui : 4 PV apres donjon
	_ok.call(_elig(G, 0) == ["BMA027"], "Bottomless Pit : le heros survivrait -> on le jette dans le gouffre")
	(G["adventure"] as Dictionary)["hp"] = 2
	_ok.call(_elig(G, 0).is_empty(), "Bottomless Pit : le reste du donjon le tue de toute facon -> non")
	(G["adventure"] as Dictionary)["hp"] = 6
	(G["adventure"] as Dictionary)["roomIndex"] = 1
	_ok.call(_elig(G, 0).is_empty(), "Bottomless Pit : le heros n'est pas dans le gouffre -> non")
	G["turn"] = 1
	(G["adventure"] as Dictionary)["roomIndex"] = 0
	_ok.call(_elig(G, 0).is_empty(), "Bottomless Pit : jamais en Early")
	# CheckBMA030 Jackpot Stash : jamais pendant l'aventure (phase de construction seulement)
	var G2 := _G([_player(0, "BMA001", [_room("BMA030")]), _player(1, "BMA002")], ["base"])
	G2["turn"] = 3
	_ok.call(_elig(G2, 0).is_empty(), "Jackpot Stash : jamais pendant l'aventure")
	# CheckBMA038 Torture Chamber : Late seulement ; un adversaire doit avoir une salle batissable en main
	var G3 := _G([_player(0, "BMA001", [_room("BMA038")]), _player(1, "BMA002", [_plain("x")])], ["base"])
	G3["phase"] = "build"
	G3["activePlayer"] = 0
	_hand(G3, 1).append(_plain("r", "monster", [1], 2))
	G3["turn"] = 4
	var mid_no: bool = _elig(G3, 0).is_empty()
	G3["turn"] = 6
	_ok.call(mid_no and _elig(G3, 0) == ["BMA038"], "Torture Chamber : Late seulement, adversaire avec une salle batissable")
	_hand(G3, 1).clear()
	_ok.call(_elig(G3, 0).is_empty(), "Torture Chamber : adversaire sans salle batissable -> non")
	# CheckBMA013 Dracolich Lair : 2+ salles en main et une salle batissable dans la defausse, dont la valeur depasse la 2e plus faible de la main
	var G4 := _G([_player(0, "BMA001", [_room("BMA013")]), _player(1, "BMA002")], ["base"])
	G4["turn"] = 3
	G4["phase"] = "build"
	G4["activePlayer"] = 0
	_hand(G4, 0).append(_plain("w1", "monster", [1], 0))
	_hand(G4, 0).append(_plain("w2", "monster", [1], 0))
	(G4["decks"]["roomDiscard"] as Array).append(_plain("good", "monster", [1], 3))
	var d = _entry(G4, 0, "BMA013")
	var recovered := ""
	var tossed := 0
	if d != null:
		recovered = str(((((d["t"] as Array)[1] as Array)[2] as Array)[0] as Dictionary)["id"])
		tossed = (((d["t"] as Array)[0] as Array)[2] as Array).size()
	_ok.call(d != null and recovered == "good" and tossed == 2, "Dracolich Lair : defausse 2 salles faibles pour reprendre la meilleure de la defausse")
	(G4["decks"]["roomDiscard"] as Array).clear()
	_ok.call(_elig(G4, 0).is_empty(), "Dracolich Lair : defausse vide -> non")
	# une salle desactivee (Freeze) n'est pas une capacite jouable (DungeonActiveRooms)
	(G4["decks"]["roomDiscard"] as Array).append(_plain("good", "monster", [1], 3))
	G4["effects"]["deactivatedRooms"].append({"playerId": 0, "roomIndex": 0})
	_ok.call(_elig(G4, 0).is_empty(), "Dracolich Lair desactivee : plus jouable")

## StatisticAI.RandomSelection : tirage UNIFORME parmi les capacites eligibles, une seule consultation par fenetre.
func _t_apk_draw_uniform() -> void:
	var G := _spell_scene("BMA041", 5)
	_hand(G, 0).append(_spell("BMA046")) # Freeze eligible aussi : hp 5 (0 apres donjon), geler la salle la plus dure le sauve
	var m := _match(G)
	var elig := _elig(G, 0)
	_ok.call(elig == ["BMA041", "BMA046"], "deux capacites eligibles (Assassin + Freeze)")
	var counts := {"BMA041": 0, "BMA046": 0}
	for i in 400:
		m.rng.seed = i + 11
		var mv = AI.pick_move(m, 0, false)
		if mv != null and str(mv["type"]) == "playSpell":
			counts[str((_hand(G, 0)[int((mv["args"] as Array)[0])] as Dictionary)["id"])] += 1
	_ok.call(counts["BMA041"] > 140 and counts["BMA046"] > 140 and counts["BMA041"] + counts["BMA046"] == 400, "tirage uniforme : %s sur 400" % str(counts))
	var first = AI.pick_move(m, 0)
	var second = AI.pick_move(m, 0)
	_ok.call(first != null and str(first["type"]) == "playSpell" and (second == null or str(second["type"]) != "playSpell"), "une fois la capacite tiree, la fenetre est consommee (adventureNext / passer)")
	m.queue_free()
