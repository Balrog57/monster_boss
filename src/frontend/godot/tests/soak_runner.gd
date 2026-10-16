extends Node
## Soak : parties IA-vs-IA a 2, 3 et 4 joueurs. Scène exécutée en headless avec autoloads.
## Usage : godot --headless --path src/frontend res://godot/tests/Soak.tscn [-- --players=3] [--runs=10]
## Sans argument : 3 parties a 2, puis a 3, puis a 4 joueurs. --players=N : N seul ; --runs=K : K parties par nombre de joueurs.
## Plafond de pas : une partie a 4 joueurs en demande ~1300 (chaque salle franchie ouvre 2 fenetres de pause que tous les joueurs
## passent), donc 500 coupait des parties qui progressaient ; 4000 ne coupe que de vraies boucles.

const MAX_STEPS := 4000


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

	var counts: Array = [2, 3, 4]
	var runs := 3
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--players="):
			counts = [clampi(int(a.substr(len("--players="))), 2, 4)]
		elif a.begins_with("--runs="):
			runs = maxi(1, int(a.substr(len("--runs="))))
	for n in counts:
		for _r in runs:
			if not _play(n):
				get_tree().quit(1)
				return
	print("SOAK OK")
	get_tree().quit(0)

## Une partie IA-vs-IA a n joueurs ; false (et diagnostic) si elle cale ou depasse MAX_STEPS.
func _play(n_players: int) -> bool:
	var m = GameManager.new()
	add_child(m)
	var sets: Array = ["base"] # `-- --sets=players-choice,hidden-heroes,tools` : meme soak avec les paquets APK
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--sets="):
			sets = Array(a.substr(len("--sets=")).split(",", false))
	m.start_new_game(n_players, 0, sets)
	var steps := 0
	while m.G.get("gameOver") == null and steps < MAX_STEPS:
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
			var mv = null
			if not moves.is_empty():
				mv = AI.pick_move(m, ap)
				if mv == null:
					mv = moves[0]
				# Un coup que l'IA juge nocif (score < 0, ex. une capacite de main qui reboucle avec Torix) n'est joue qu'en dernier recours :
				# on laisse d'abord passer ceux qui le peuvent.
				if AI.score_move(m, ap, mv) >= 0.0 and m.apply_move(ap, mv):
					acted = true
			if not acted:
				# Repli : quelqu'un peut-il passer ? sinon le coup juge nocif de l'actif (dernier recours), sinon n'importe quel premier coup.
				for pid in m.G["players"]:
					for pm in m.legal_moves(int(pid)):
						if not acted and str((pm as Dictionary).get("type", "")) in ["pass", "passBuild"] and m.apply_move(int(pid), pm):
							acted = true
				if not acted and mv != null and m.apply_move(ap, mv):
					acted = true
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
	print("SOAK players=", n_players, " steps=", steps, " turn=", m.G.get("turn", -1), " gameOver=", m.G.get("gameOver"))
	var done: bool = m.G.get("gameOver") != null
	if not done:
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
	m.queue_free()
	return done
