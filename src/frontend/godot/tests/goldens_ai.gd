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
