extends RefCounted
## Goldens APK : pool de boss complet (RandomBossSelectionScene / GameBoardExtensions) et pose de salle revocable jusqu'a DONE
## (BuildRoomHandSceneBehavior.MyHand_CardDropped / CheckMaxBuildRooms / UndoBuild).
## Appele par goldens.gd : `load("res://godot/tests/goldens_undo.gd").new().run(_ok, self)`.

var _ok: Callable
var host: Node

func run(ok: Callable, h: Node) -> void:
	_ok = ok
	host = h
	_t_boss_pool_is_complete()
	_t_build_undo_restores_hand()
	_t_build_over_undo_restores_slot()
	_t_undo_locked_by_spell()
	_t_undo_setup_and_done()
	_t_undo_never_for_ai()
	_t_swap_build()

func _room(id: String) -> Dictionary:
	return {"id": id, "name": id, "type": "trap", "advanced": false, "treasures": [1], "damage": 1, "isRoom": true}

func _match(dungeon: Array, hand: Array) -> Node:
	var m = load("res://godot/scripts/Match.gd").new()
	host.add_child(m)
	m.G = {
		"players": {
			0: {"boss": {"xp": 300, "treasures": [1]}, "dungeon": dungeon, "hand": hand, "souls": [], "wounds": [],
				"eliminated": false, "leveledUp": false, "buildsThisTurn": 0, "isAI": false, "entrance": []},
			1: {"boss": {"xp": 300, "treasures": [1]}, "dungeon": [[_room("F")]], "hand": [], "souls": [], "wounds": [],
				"eliminated": false, "leveledUp": false, "buildsThisTurn": 0, "isAI": true, "entrance": []},
		},
		"decks": {"rooms": [], "spells": [], "heroes": [], "epics": [], "roomDiscard": [], "spellDiscard": [], "heroDiscard": []},
		"town": [], "turn": 1, "phase": "build", "gameOver": null, "log": [], "effects": SpellEffects.empty_effects(),
	}
	return m

func _types(m, pid: int) -> Array:
	return m.legal_moves(pid).map(func(mv): return str((mv as Dictionary).get("type", "")))

func _p(m, pid: int = 0) -> Dictionary:
	return m.G["players"][pid]

func _ids(arr: Array) -> Array:
	return arr.map(func(c): return str((c as Dictionary).get("id", "")))

# --- 1) boss : tous les boss des paquets choisis ---------------------------------------------------------

func _t_boss_pool_is_complete() -> void:
	var m = load("res://godot/scripts/Match.gd").new()
	host.add_child(m)
	var base_ids: Array = CardDB.bosses.filter(func(b): return (b as Dictionary).get("set", "base") == "base").map(func(b): return str((b as Dictionary)["id"]))
	for n in [2, 3, 4]:
		var ids: Array = _ids((m.new_match(n, 1, ["base"]))["bossPicks"])
		ids.sort()
		var want := base_ids.duplicate()
		want.sort()
		_ok.call(ids == want and ids.size() >= 8, "%d joueurs : le carrousel propose les %d boss du jeu de base (obtenu %d)" % [n, base_ids.size(), ids.size()])
	# humain + IA : chacun retire son boss du pool, les autres boss restent proposes
	var G: Dictionary = m.new_match(2, 1, ["base"])
	var first: String = str((G["bossPicks"] as Array)[0]["id"])
	m.apply_move(0, {"type": "pickBoss", "args": [first]})
	_ok.call((G["bossPicks"] as Array).size() == base_ids.size() - 1 and not _ids(G["bossPicks"]).has(first), "pickBoss retire le boss pris du pool")
	m.queue_free()

# --- 2) pose -> reprise ------------------------------------------------------------------------------------

func _t_build_undo_restores_hand() -> void:
	var m = _match([], [_room("A"), _room("B")])
	_ok.call(not _types(m, 0).has("undoBuild"), "undo : rien a reprendre avant la pose")
	_ok.call(m.apply_move(0, {"type": "buildRoom", "args": [0]}), "undo : pose de A")
	_ok.call(_p(m)["buildsThisTurn"] == 1 and (_p(m)["dungeon"] as Array).size() == 1 and (_p(m)["hand"] as Array).size() == 1, "undo : A posee")
	var t: Array = _types(m, 0)
	_ok.call(t.has("undoBuild") and not t.has("buildRoom"), "undo : reprise proposee, plus de pose (limite atteinte)")
	_ok.call(m.apply_move(0, {"type": "undoBuild", "args": [0]}), "undo : undoBuild applique")
	_ok.call((_p(m)["dungeon"] as Array).is_empty() and _ids(_p(m)["hand"]) == ["B", "A"], "undo : A revient en main, emplacement supprime")
	var a: Dictionary = (_p(m)["hand"] as Array)[1]
	_ok.call(not a.has("faceDown") and not a.has("builtThisTurn") and not a.has("undoBuild"), "undo : A est une carte de main ordinaire")
	_ok.call(_p(m)["buildsThisTurn"] == 0 and _types(m, 0).has("buildRoom") and not _types(m, 0).has("undoBuild"), "undo : buildsThisTurn remis, pose a nouveau legale")
	_ok.call(not m.apply_move(0, {"type": "undoBuild", "args": [0]}), "undo : rien a reprendre une 2e fois")
	# remplacement : B prend la place de A
	_ok.call(m.apply_move(0, {"type": "buildRoom", "args": [1]}) and m.apply_move(0, {"type": "undoBuild", "args": [0]}) and m.apply_move(0, {"type": "buildRoom", "args": [0]}), "undo : A reprise puis B posee")
	_ok.call(str(((_p(m)["dungeon"] as Array)[0] as Array)[0]["id"]) == "B" and _p(m)["buildsThisTurn"] == 1, "undo : B occupe l'emplacement")
	m.queue_free()

func _t_build_over_undo_restores_slot() -> void:
	var base := _room("OLD")
	var m = _match([[base]], [_room("A")])
	var over := {"type": "buildRoom", "args": [0, 0]}
	_ok.call(m.apply_move(0, over), "recouvrement : A posee sur OLD")
	var stack: Array = (_p(m)["dungeon"] as Array)[0]
	_ok.call(stack.size() == 2 and bool((stack[1] as Dictionary).get("faceDown", false)), "recouvrement : A face cachee sur OLD")
	_ok.call(m.apply_move(0, {"type": "undoBuild", "args": [0]}), "recouvrement : reprise")
	stack = (_p(m)["dungeon"] as Array)[0]
	_ok.call(stack.size() == 1 and str((stack[0] as Dictionary)["id"]) == "OLD" and not bool((stack[0] as Dictionary).get("faceDown", false)), "recouvrement : OLD est de nouveau la salle visible")
	_ok.call(_ids(_p(m)["hand"]) == ["A"] and _p(m)["buildsThisTurn"] == 0, "recouvrement : A en main, buildsThisTurn remis")
	m.queue_free()

# --- 3) reprise interdite apres un sort / DONE / pour l'IA ---------------------------------------------

func _t_undo_locked_by_spell() -> void:
	var m = _match([], [_room("A"), {"id": "BMA050", "name": "Motivation", "isSpell": true}])
	m.apply_move(0, {"type": "buildRoom", "args": [0]})
	_ok.call(_types(m, 0).has("undoBuild"), "sort : reprise possible avant tout sort")
	var spell: Dictionary = {}
	for mv in m.legal_moves(0):
		if str((mv as Dictionary).get("type", "")) == "playSpell":
			spell = mv
			break
	_ok.call(not spell.is_empty() and m.apply_move(0, spell), "sort : Motivation jouee apres la pose")
	m.apply_move(1, {"type": "pass", "args": []}) # l'adversaire laisse resoudre
	_ok.call(not _types(m, 0).has("undoBuild") and not m.apply_move(0, {"type": "undoBuild", "args": [0]}), "sort : plus de reprise apres un sort (pose definitive)")
	m.queue_free()

func _human_setup(): # partie reelle 2 joueurs (1 humain) amenee a la pose initiale ; null si la main n'a pas de salle ordinaire
	var m = load("res://godot/scripts/Match.gd").new()
	host.add_child(m)
	var G: Dictionary = m.new_match(2, 1, ["base"])
	for pid in [0, 1]:
		m.apply_move(pid, {"type": "pickBoss", "args": [str((G["bossPicks"] as Array)[0]["id"])]})
	if not (G.get("pendingChoice", {}) as Dictionary).is_empty():
		m.apply_move(0, {"type": "openingDiscard", "args": [0, 1]})
	if str(G.get("phase", "")) == "setup" and _types(m, 0).has("buildRoom"):
		return m
	m.queue_free()
	return null

func _t_undo_setup_and_done() -> void:
	var m = null
	for i in 30:
		m = _human_setup()
		if m != null:
			break
	_ok.call(m != null, "setup : une main avec une salle ordinaire a ete tiree")
	if m == null:
		return
	var hand_before: int = (_p(m)["hand"] as Array).size()
	var first: Dictionary = {}
	for mv in m.legal_moves(0):
		if str((mv as Dictionary).get("type", "")) == "buildRoom":
			first = mv
			break
	_ok.call(m.apply_move(0, first) and str(m.G["phase"]) == "setup" and _types(m, 0).has("undoBuild") and _types(m, 0).has("passBuild"), "setup : pose, reprise et DONE proposes")
	_ok.call(m.apply_move(0, {"type": "undoBuild", "args": [0]}), "setup : reprise")
	_ok.call((_p(m)["hand"] as Array).size() == hand_before and (_p(m)["dungeon"] as Array).is_empty() and _p(m)["buildsThisTurn"] == 0 and _types(m, 0).has("buildRoom"), "setup : main et donjon restaures, pose a nouveau legale")
	m.apply_move(0, first)
	_ok.call(m.apply_move(0, {"type": "passBuild", "args": []}), "setup : DONE")
	_ok.call(not _types(m, 0).has("undoBuild") and not m.apply_move(0, {"type": "undoBuild", "args": [0]}), "setup : plus de reprise apres DONE")
	m.queue_free()

func _t_undo_never_for_ai() -> void:
	var pending := _room("A")
	pending.merge({"faceDown": true, "builtThisTurn": true, "undoBuild": 1})
	var m = _match([[pending.duplicate()]], [])
	_ok.call(_types(m, 0).has("undoBuild"), "IA : (controle) un siege humain a la reprise")
	var ai: Dictionary = _p(m, 1)
	ai["dungeon"] = [[pending.duplicate()]]
	m.G["activePlayer"] = 1
	m.G["buildOrder"] = [1, 0]
	m.G["buildIndex"] = 0
	_ok.call(not _types(m, 1).has("undoBuild") and not m.apply_move(1, {"type": "undoBuild", "args": [0]}), "IA : jamais de reprise")
	var pick = AI.pick_move(m, 1)
	_ok.call(pick == null or str((pick as Dictionary)["type"]) != "undoBuild", "IA : pick_move ne choisit pas undoBuild")
	m.queue_free()

## GameManager.swap_build : clic / depot d'une autre salle = reprise de la pose en attente puis pose (un seul geste), sans salle perdue.
func _t_swap_build() -> void:
	var gm = load("res://godot/scripts/GameManager.gd").new()
	host.add_child(gm)
	gm.G = _match([], [_room("A"), _room("B")]).G
	gm.apply_move(0, {"type": "buildRoom", "args": [0]})
	_ok.call(not gm.pending_undo(0).is_empty() and gm.can_swap_build_at(0, 0, 1) and not gm.can_build_room_at(0, 0, 1), "swap : B peut remplacer A en attente")
	_ok.call(gm.swap_build(0, 0, 1), "swap : B remplace A")
	var d: Array = _p(gm)["dungeon"]
	_ok.call(d.size() == 1 and str((d[0] as Array)[0]["id"]) == "B" and _ids(_p(gm)["hand"]) == ["A"] and _p(gm)["buildsThisTurn"] == 1, "swap : B posee, A revenue en main, une seule pose comptee")
	# pose par-dessus une salle visible : la salle recouverte reste en place apres le swap
	var gm2 = load("res://godot/scripts/GameManager.gd").new()
	host.add_child(gm2)
	gm2.G = _match([[_room("OLD")]], [_room("A"), _room("B")]).G
	gm2.apply_move(0, {"type": "buildRoom", "args": [0]}) # A sur le nouvel emplacement (0)
	_ok.call(gm2.swap_build(0, 0, 1), "swap : B remplace A, posee sur OLD (l'emplacement de A disparait, OLD glisse en 0)")
	var d2: Array = _p(gm2)["dungeon"]
	_ok.call(d2.size() == 1 and _ids(_p(gm2)["hand"]) == ["A"] and _ids(d2[0]) == ["OLD", "B"] and bool(((d2[0] as Array).back() as Dictionary).get("faceDown", false)), "swap : B face cachee sur OLD, A en main")
	gm.queue_free()
	gm2.queue_free()
