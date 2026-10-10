extends Node
## Soak : partie 2j IA-vs-IA. Scène exécutée en headless avec autoloads.
## Usage : godot --headless --path godot res://godot/tests/Soak.tscn

func _ready() -> void:
	print("CARDS bosses=", CardDB.bosses.size(), " rooms=", CardDB.rooms.size(), " heroes=", CardDB.heroes.size(), " spells=", CardDB.spells.size())
	if CardDB.bosses.size() < 10 or CardDB.rooms.size() < 20 or CardDB.heroes.is_empty():
		print("SOAK ECHEC : cards.json incomplet")
		get_tree().quit(1)
		return
	# Test CardData Resource instantiation (Étape 2)
	var card_sample: CardData = CardDB.get_card_data("BMA001")
	if card_sample == null or card_sample.title != "Draculord":
		print("SOAK ECHEC : CardData non instanciable pour BMA001")
		get_tree().quit(1)
		return
	print("CARD_DATA OK: id=", card_sample.id, " title=", card_sample.title, " type=", card_sample.card_type, " xp=", card_sample.xp)

	var room_sample: CardData = CardDB.get_card_data("BMA009")
	if room_sample == null or room_sample.title != "Dark Altar" or room_sample.damage != 1:
		print("SOAK ECHEC : CardData non instanciable pour BMA009")
		get_tree().quit(1)
		return
	print("CARD_DATA ROOM OK: id=", room_sample.id, " title=", room_sample.title, " dmg=", room_sample.damage)

	var m: GameManager = GameManager.new()
	add_child(m)
	m.start_new_game(2, 0)
	var steps := 0
	while m.G.get("gameOver") == null and steps < 500:
		var acted := false
		var phase: String = m.G["phase"]
		if phase == "boss":
			for pid in m.G["players"]:
				var moves := m.legal_moves(int(pid))
				if not moves.is_empty():
					m.apply_move(int(pid), moves[0])
					acted = true
					break
		elif phase == "setup" or phase == "build":
			for pid in m.G["players"]:
				var mv = AI.pick_move(m, int(pid))
				if mv != null:
					m.apply_move(int(pid), mv)
					acted = true
		elif phase == "adventure":
			m.apply_move(0, {"type": "adventureNext", "args": []})
			acted = true
		else:
			break
		steps += 1
		if not acted:
			break
	print("SOAK steps=", steps, " turn=", m.G.get("turn", -1), " gameOver=", m.G.get("gameOver"))
	if m.G.get("gameOver") == null:
		print("SOAK INCOMPLET (phase=", m.G.get("phase"), ")")
		get_tree().quit(1)
	else:
		print("SOAK OK")
		get_tree().quit(0)
