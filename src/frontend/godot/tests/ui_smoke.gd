extends Node
## Smoke test UI : Board.tscn pilote comme un joueur humain (solo, 2 joueurs) sur quelques tours.
## Echoue sur toute erreur de script / moteur (Logger), sur un blocage de la partie ou si l'ecran fige
## (phase affichee != phase du jeu). Usage : godot --headless --path src/frontend res://godot/tests/UiSmoke.tscn -> "UISMOKE OK"

const GameManager = preload("res://godot/scripts/GameManager.gd")

var TURNS := 3
const MAX_STEPS := 6000
const STEP_S := 0.06

## Compte les erreurs moteur / script (en headless, un SCRIPT ERROR n'arrete pas le processus).
class ErrLogger extends Logger:
	var errors: Array = []
	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, _bt: Array) -> void:
		errors.append("%s:%d %s %s (%s)" % [file, line, code, rationale, function])

var _log := ErrLogger.new()
var _fails: Array = []
var gm: GameManager
var board

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--turns="):
			TURNS = int(a.substr(8))
	OS.add_logger(_log)
	await _run()
	OS.remove_logger(_log)
	for e in _log.errors.slice(0, 15):
		_fails.append("erreur runtime : " + e)
	if _fails.is_empty():
		print("UISMOKE OK")
		get_tree().quit(0)
	else:
		for f in _fails:
			print("UISMOKE ECHEC : ", f)
		get_tree().quit(1)

func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout

func _run() -> void:
	gm = GameManager.new()
	add_child(gm)
	gm.start_new_game(2, 1, ["base"])
	board = load("res://godot/scenes/Board.tscn").instantiate()
	board.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(board)
	board.skip_animations = false # on veut exercer la traversee des heros meme en headless
	board.setup(gm, func(): pass)
	await _wait(0.1)
	var last_sig := ""
	var stuck := 0
	for step in MAX_STEPS:
		var G: Dictionary = gm.G
		if G.get("gameOver") != null or (int(G.get("turn", 0)) >= TURNS and str(G.get("phase", "")) == "build"):
			break
		if not _log.errors.is_empty():
			return
		await _wait(STEP_S)
		if board._animating_hero:
			continue
		_act()
		await get_tree().process_frame
		# Apres chaque geste, l'ecran doit refleter la phase du jeu (sinon : affichage fige).
		if str(gm.G.get("phase", "")) != board._last_phase and gm.G.get("gameOver") == null and not board._animating_hero:
			_fails.append("ecran fige : bandeau %s != phase %s (tour %s)" % [board._last_phase, gm.G.get("phase"), gm.G.get("turn")])
			return
		# anti-blocage : l'etat du jeu doit evoluer
		var adv_sig: Dictionary = (G.get("adventure", {}) as Dictionary).duplicate()
		adv_sig.erase("hero")
		var sig := JSON.stringify([G.get("phase"), G.get("turn"), (G.get("log", []) as Array).size(), G.get("pendingChoice", {}), adv_sig, G.get("adventurePausePassed"), (G.get("stack", []) as Array).size()])
		stuck = stuck + 1 if sig == last_sig else 0
		last_sig = sig
		if stuck > 200:
			var adv: Dictionary = (G.get("adventure", {}) as Dictionary).duplicate()
			adv.erase("hero")
			_fails.append("partie bloquee en phase %s (tour %s, animation=%s) active=%s adv=%s passedMap=%s stack=%s coups0=%s coups1=%s log=%s" % [G.get("phase"), G.get("turn"), board._animating_hero, gm.active_player(), JSON.stringify(adv), JSON.stringify(G.get("adventurePausePassed")), (G.get("stack", []) as Array).size(), JSON.stringify(gm.legal_moves(0).map(func(m): return m["type"])), JSON.stringify(gm.legal_moves(1).map(func(m): return m["type"])), JSON.stringify((G["log"] as Array).slice(-3))])
			return
	var G: Dictionary = gm.G
	if G.get("gameOver") == null and int(G.get("turn", 0)) < TURNS:
		_fails.append("pas assez de tours joues (tour %s, phase %s)" % [G.get("turn"), G.get("phase")])
		return
	await _wait(0.5)
	# L'affichage doit refleter l'etat final : bandeau de phase = phase du jeu.
	if G.get("gameOver") == null and board._last_phase != str(G.get("phase")):
		_fails.append("ecran fige : bandeau %s != phase %s" % [board._last_phase, G.get("phase")])

## Un geste d'humain par pas, via les memes points d'entree que les clics reels.
func _act() -> void:
	var G: Dictionary = gm.G
	var phase: String = G.get("phase", "")
	var me: Dictionary = (G["players"] as Dictionary)[0]
	var pc: Dictionary = G.get("pendingChoice", {})
	if board._last_phase != phase and phase != "":
		# le rafraichissement qui suit un changement de phase doit avoir eu lieu
		board.refresh()
	if not pc.is_empty():
		if board._is_opening_discard_for_me():
			board._on_hand_card_clicked(0, (me["hand"] as Array)[0])
			board._on_hand_card_clicked(1, (me["hand"] as Array)[1])
			board._on_discard_confirm()
		elif int(pc.get("playerId", -1)) == 0:
			var mv: Array = gm.legal_moves(0)
			if not mv.is_empty():
				board._do(mv[0])
		return
	if not (G.get("stack", []) as Array).is_empty(): # Spell Battle : le joueur doit repondre (passer)
		if gm.legal_moves(0).any(func(m): return m["type"] == "pass"):
			board._on_pass_pressed()
		return
	match phase:
		"boss":
			if me.get("boss") == null:
				var cards: Array = board.hand_layer.get_children().filter(func(c): return not c.is_queued_for_deletion())
				if cards.is_empty():
					_fails.append("aucun boss propose a l'ecran")
				else:
					(cards[0] as Control).card_clicked.emit(null)
		"setup", "build":
			var builds := int(me.get("buildsThisTurn", 0))
			var want_build: bool = (phase == "build" and builds == 0) or (phase == "setup" and bool(G.get("setupBuild", false)) and builds == 0)
			if want_build:
				var hand: Array = me["hand"]
				for i in hand.size():
					if (hand[i] as Dictionary).get("isRoom", false) and gm.can_build_room_at(0, i, (me["dungeon"] as Array).size()):
						board._on_hand_card_clicked(i, hand[i])
						return
			if not gm.legal_moves(0).is_empty():
				board._on_pass_pressed()
		"adventure":
			var types: Array = gm.legal_moves(0).map(func(m): return m["type"])
			if types.has("adventureNext"):
				board._on_advance_pressed()
			elif types.has("passBuild") or types.has("pass"):
				board._on_pass_pressed()
