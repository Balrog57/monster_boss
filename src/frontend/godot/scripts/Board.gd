extends Control
## Board — remplace AppBoard.jsx + 25 composants game (version texte jouable).
## shortcut: visuels cartes WebP / drag-and-drop / overlays (ciblage sorts, level-up, discard 7->5) en phase 2 ; ici boutons + clic.

var match_node: Match
var on_exit: Callable
var status: Label
var hand_box: HBoxContainer
var my_dungeon: HBoxContainer
var foe_dungeon: HBoxContainer
var town_box: HBoxContainer
var log_label: Label
var timer := 0.0

func setup(m: Match, exit_cb: Callable) -> void:
	match_node = m
	on_exit = exit_cb
	_build()
	refresh()
	match_node.state_changed.connect(refresh)

func _build() -> void:
	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 8)
	add_child(root)
	var top := HBoxContainer.new()
	root.add_child(top)
	status = Label.new()
	status.add_theme_font_size_override("font_size", 22)
	top.add_child(status)
	var exit := Button.new()
	exit.text = "Menu"
	exit.pressed.connect(func(): on_exit.call())
	top.add_child(exit)
	root.add_child(_row_label("Donjon adverse (IA) :"))
	foe_dungeon = HBoxContainer.new()
	root.add_child(foe_dungeon)
	root.add_child(_row_label("Ville :"))
	town_box = HBoxContainer.new()
	root.add_child(town_box)
	root.add_child(_row_label("Mon donjon :"))
	my_dungeon = HBoxContainer.new()
	root.add_child(my_dungeon)
	root.add_child(_row_label("Ma main (cliquer pour jouer) :"))
	hand_box = HBoxContainer.new()
	root.add_child(hand_box)
	var adv := Button.new()
	adv.text = "Résoudre héros suivant"
	adv.pressed.connect(func(): _do({"type": "adventureNext", "args": []}))
	root.add_child(adv)
	log_label = Label.new()
	log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(log_label)

func _row_label(t: String) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", 18)
	return l

func _process(delta: float) -> void:
	if match_node == null or match_node.G.get("gameOver") != null:
		return
	# L'IA joue avec un petit délai.
	var players: Dictionary = match_node.G["players"]
	for pid in players:
		if (players[pid] as Dictionary).get("isAI", false):
			var moves := match_node.legal_moves(int(pid))
			if not moves.is_empty() and (match_node.G["phase"] == "boss" or match_node.G["phase"] == "build"):
				timer += delta
				if timer > 0.6:
					timer = 0.0
					var mv = AI.pick_move(match_node, int(pid))
					if mv != null:
						match_node.apply_move(int(pid), mv)
						refresh()
				return

func _do(move: Dictionary) -> void:
	if match_node.apply_move(0, move):
		refresh()

func refresh() -> void:
	if match_node == null or match_node.G.is_empty():
		return
	for c in hand_box.get_children() + my_dungeon.get_children() + foe_dungeon.get_children() + town_box.get_children():
		c.queue_free()
	var p: Dictionary = (match_node.G["players"] as Dictionary)[0]
	var foe: Dictionary = (match_node.G["players"] as Dictionary)[1]
	if match_node.G.get("gameOver") != null:
		var w: int = (match_node.G["gameOver"] as Dictionary).get("winner", -1)
		status.text = "PARTIE TERMINÉE — gagnant : joueur %d (%s)" % [w, (match_node.G["gameOver"] as Dictionary).get("reason", "")]
	else:
		status.text = "Tour %d — phase %s | Âmes %d/10 | Blessures %d/5" % [match_node.G.get("turn", 0), match_node.G.get("phase", "?"), CardDB.total_souls(p), CardDB.total_wounds(p)]
	# Boss picks
	if match_node.G["phase"] == "boss":
		for b in match_node.G["bossPicks"]:
			var btn := Button.new()
			btn.text = "%s (%d XP)" % [(b as Dictionary).get("name", "?"), (b as Dictionary).get("xp", 0)]
			var bid := String((b as Dictionary)["id"])
			btn.pressed.connect(func(): _do({"type": "pickBoss", "args": [bid]}))
			hand_box.add_child(btn)
	else:
		var hand: Array = p.get("hand", [])
		for i in hand.size():
			var c: Dictionary = hand[i]
			var btn := Button.new()
			btn.text = "%s%s" % [c.get("name", "?"), (" [%d dmg]" % int(c.get("damage", 0))) if c.get("isRoom", false) else " (sort)"]
			btn.disabled = match_node.legal_moves(0).filter(func(m): return (m as Dictionary).get("args", []) == [i]).is_empty() and not (match_node.G["phase"] == "build")
			var idx := i
			var is_room: bool = c.get("isRoom", false)
			btn.pressed.connect(func(): _play_hand(idx, is_room))
			hand_box.add_child(btn)
	for stack in foe.get("dungeon", []):
		var r = BossEngine.active_room(stack)
		foe_dungeon.add_child(Label.new())
		(foe_dungeon.get_child(-1) as Label).text = ("[%s %d]" % [r.get("name", "?"), int(r.get("damage", 0))]) if r != null else "[vide]"
	for stack in p.get("dungeon", []):
		var r = BossEngine.active_room(stack)
		my_dungeon.add_child(Label.new())
		(my_dungeon.get_child(-1) as Label).text = ("[%s %d]" % [r.get("name", "?"), int(r.get("damage", 0))]) if r != null else "[vide]"
	for h in match_node.G.get("town", []):
		town_box.add_child(Label.new())
		(town_box.get_child(-1) as Label).text = "%s" % (h as Dictionary).get("name", "?")
	var logs: Array = match_node.G.get("log", [])
	log_label.text = "\n".join(logs.slice(max(0, logs.size() - 4)))

func _play_hand(idx: int, is_room: bool) -> void:
	var phase: String = match_node.G["phase"]
	if phase == "setup":
		_do({"type": "buildInitialRoom", "args": [idx]})
	elif phase == "build":
		if is_room:
			_do({"type": "buildRoom", "args": [idx]})
		else:
			_do({"type": "passBuild", "args": []})
