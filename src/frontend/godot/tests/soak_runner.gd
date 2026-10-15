extends Node
## Soak : partie 2j IA-vs-IA. Scène exécutée en headless avec autoloads.
## Usage : godot --headless --path src/frontend res://godot/tests/Soak.tscn

const CardData = preload("res://godot/scripts/CardData.gd")
const GameManager = preload("res://godot/scripts/GameManager.gd")
const AI = preload("res://godot/scripts/AI.gd")

func _ready() -> void:
	print("CARDS bosses=", CardDB.bosses.size(), " rooms=", CardDB.rooms.size(), " heroes=", CardDB.heroes.size(), " spells=", CardDB.spells.size())
	if CardDB.bosses.size() < 10 or CardDB.rooms.size() < 20 or CardDB.heroes.is_empty():
		print("SOAK ECHEC : cards.json incomplet")
		get_tree().quit(1)
		return
	# Test CardData Resource instantiation (Étape 2)
	var card_sample = CardDB.get_card_data("BMA001")
	if card_sample == null or card_sample.title != "Draculord":
		print("SOAK ECHEC : CardData non instanciable pour BMA001")
		get_tree().quit(1)
		return
	print("CARD_DATA OK: id=", card_sample.id, " title=", card_sample.title, " type=", card_sample.card_type, " xp=", card_sample.xp)

	var room_sample = CardDB.get_card_data("BMA009")
	if room_sample == null or room_sample.title != "Dark Altar" or room_sample.damage != 1:
		print("SOAK ECHEC : CardData non instanciable pour BMA009")
		get_tree().quit(1)
		return
	print("CARD_DATA ROOM OK: id=", room_sample.id, " title=", room_sample.title, " dmg=", room_sample.damage)

	var m = GameManager.new()
	add_child(m)
	m.start_new_game(2, 0)
	var steps := 0
	while m.G.get("gameOver") == null and steps < 500:
		var acted := false
		var phase: String = m.G["phase"]
		# Un choix en attente se resout en priorite, quel que soit le joueur concerne.
		var pc: Dictionary = m.G.get("pendingChoice", {})
		if not pc.is_empty():
			var owner := int(pc.get("playerId", 0))
			var cmoves: Array = m.legal_moves(owner)
			if not cmoves.is_empty():
				m.apply_move(owner, cmoves[0])
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
			# Les deux sieges sont IA : Match._drive_ai() fait jouer le joueur actif
			# (BuildPhase_a est sequentiel). Soumettre un coup pour un joueur non
			# actif serait refuse, on n'a donc rien a faire ici.
			acted = true
		elif phase == "adventure":
			var ap := m.active_player()
			var moves := m.legal_moves(ap)
			print("SOAK ap=", ap, " moves=", moves)
			if not moves.is_empty():
				var mv = AI.pick_move(m, ap)
				if mv == null:
					mv = moves[0]
				if m.apply_move(ap, mv):
					acted = true
			if not acted:
				for pid in m.G["players"]:
					var pmoves: Array = m.legal_moves(int(pid))
					if not pmoves.is_empty():
						if m.apply_move(int(pid), pmoves[0]):
							acted = true
							break
		else:
			break
		steps += 1
		if not acted:
			break
	print("SOAK steps=", steps, " turn=", m.G.get("turn", -1), " gameOver=", m.G.get("gameOver"))
	if m.G.get("gameOver") == null:
		print("SOAK INCOMPLET (phase=", m.G.get("phase"), ")")
		for pid in m.G["players"]:
			var pl: Dictionary = m.G["players"][pid]
			print("  P", pid, " builds=", pl.get("buildsThisTurn"), " eliminated=", pl.get("eliminated"),
				" canBuild=", BossEngine.can_build_room(pl, m.G, int(pid)),
				" hand=", (pl.get("hand", []) as Array).size(),
				" dungeon=", (pl.get("dungeon", []) as Array).size())
		print("  pending=", m.G.get("pendingChoice"), " active=", m.G.get("activePlayer"),
			" stack=", (m.G.get("stack", []) as Array).size(), " stackReturn=", m.G.get("stackReturnPlayer"),
			" adventure=", m.G.get("adventure"), " pause=", (m.G.get("adventure", {}) as Dictionary).get("pause"))
		print("  movesP0=", m.legal_moves(0).size(), " movesP1=", m.legal_moves(1).size())
		print("  iaP0=", AI.pick_move(m, 0))
		get_tree().quit(1)
	else:
		print("SOAK OK")
		get_tree().quit(0)
