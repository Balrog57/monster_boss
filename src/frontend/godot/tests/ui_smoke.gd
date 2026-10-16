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
var quit_calls := 0

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
	board.setup(gm, func(): quit_calls += 1)
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
	if _fails.is_empty():
		await _extra_checks()

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

# --- Interactions sans bouton non-APK : sort par clic sur la carte, capacite par clic sur la salle, menu, regles, confirmation ---

func _check(cond: bool, msg: String) -> bool:
	if not cond:
		_fails.append(msg)
	return cond

func _take_spell(id: String) -> int:
	var G: Dictionary = gm.G
	var deck: Array = G["decks"]["spells"]
	for i in deck.size():
		if str((deck[i] as Dictionary).get("id", "")) == id:
			var hand: Array = G["players"][0]["hand"]
			hand.append(deck.pop_at(i))
			board.refresh()
			return hand.size() - 1
	return -1

func _buttons(n: Node, out: Array = []) -> Array:
	for c in n.get_children():
		if c is Button:
			out.append(c)
		_buttons(c, out)
	return out

## Partie neuve amenee au debut de la construction du tour 1 (aucun choix en attente) : etat comparable d'un lancement a l'autre.
func _new_game() -> void:
	if board != null:
		board.queue_free()
		gm.queue_free()
		await get_tree().process_frame
	CardDB._rng.seed = 424242
	gm = GameManager.new()
	add_child(gm)
	gm.start_new_game(2, 1, ["base"])
	board = load("res://godot/scenes/Board.tscn").instantiate()
	board.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(board)
	board.skip_animations = true
	board.setup(gm, func(): quit_calls += 1)
	await _wait(0.1)
	for step in 600:
		var G: Dictionary = gm.G
		if str(G.get("phase", "")) == "build" and (G.get("pendingChoice", {}) as Dictionary).is_empty() and int((G["players"][0] as Dictionary).get("buildsThisTurn", 0)) == 0 and not gm.legal_moves(0).is_empty():
			return
		await _wait(0.05)
		_act()
	_fails.append("partie neuve : la construction du tour 1 n'a pas ete atteinte")

## Apres un sort / une capacite : la pile (Spell Battle) et les choix en attente se vident (l'IA repond, l'humain passe).
func _drain() -> void:
	for i in 300:
		if (gm.G.get("stack", []) as Array).is_empty() and (gm.G.get("pendingChoice", {}) as Dictionary).is_empty():
			return
		await _wait(0.05)
		_act()
	_fails.append("pile / choix jamais resolus apres un sort")

func _extra_checks() -> void:
	await _new_game()
	var G: Dictionary = gm.G
	var me: Dictionary = G["players"][0]
	board.refresh()
	# Main : cartes ~210x300 a 1920x1080
	var cards: Array = board.hand_layer.get_children().filter(func(c): return not c.is_queued_for_deletion())
	if _check(not cards.is_empty(), "main vide a l'ecran"):
		_check((cards[0] as Control).size == Vector2(210, 300), "carte de main %s != 210x300" % (cards[0] as Control).size)
	_check(board.extra_bar.get_child_count() == 0 or not board.extra_bar.visible, "bouton non-APK visible en partie de base")
	# 1) Sort sans cible : un clic sur la carte le joue (aucun bouton « Sort : ... »)
	var idx := _take_spell("BMA050") # Motivation : phase de construction, sans cible
	if _check(idx >= 0, "BMA050 introuvable dans la pioche de sorts"):
		var n_before := (me["hand"] as Array).size()
		var legal := gm.legal_moves(0).filter(func(m): return m["type"] == "playSpell" and int(m["args"][0]) == idx)
		if _check(legal.size() == 1, "BMA050 : %d coups playSpell (1 attendu)" % legal.size()):
			board._on_hand_card_clicked(idx, (me["hand"] as Array)[idx])
			await get_tree().process_frame
			_check((me["hand"] as Array).size() == n_before - 1, "clic sur le sort : la carte n'a pas ete jouee")
			_check(board._popup_kind == "", "popup inattendu pour un sort sans cible")
			await _drain()
	# 2) Sort a cible multiple : fenetre de ciblage, choix d'une cible ; CANCEL la referme sans jouer
	var town: Array = G["town"]
	while town.size() < 2: # le tour 1 peut commencer avec la ville vide : on y met deux heros pour avoir plusieurs cibles
		town.append((CardDB.heroes[town.size()] as Dictionary).duplicate(true))
	idx = _take_spell("BMA051")
	if _check(idx >= 0, "BMA051 introuvable dans la pioche de sorts"):
		var n2 := (me["hand"] as Array).size()
		board._on_hand_card_clicked(idx, (me["hand"] as Array)[idx])
		await get_tree().process_frame
		if _check(board._popup_kind == "target", "sort a cibles multiples : pas de fenetre de ciblage (popup=%s)" % board._popup_kind):
			var btns := _buttons(board._popup)
			_check(btns.size() == town.size() + 1, "ciblage : %d boutons (%d attendus)" % [btns.size(), town.size() + 1])
			(btns[btns.size() - 1] as Button).pressed.emit() # CANCEL
			await get_tree().process_frame
			_check(board._popup_kind == "" and (me["hand"] as Array).size() == n2, "CANCEL : popup ferme et carte conservee")
			board._on_hand_card_clicked(idx, (me["hand"] as Array)[idx])
			await get_tree().process_frame
			btns = _buttons(board._popup)
			(btns[0] as Button).pressed.emit() # premiere cible
			await get_tree().process_frame
			_check(board._popup_kind == "" and (me["hand"] as Array).size() == n2 - 1, "cible choisie : le sort doit etre joue")
			await _drain()
	# 3) Capacite de salle : halo + clic gauche sur la salle (aucun bouton « Capacite : ... »)
	var done := false
	for rid in Match.ACTIVATABLE_ROOMS:
		if not str(rid).begins_with("BMA") or done:
			continue
		var proto: Dictionary = {}
		for r in CardDB.rooms:
			if str((r as Dictionary).get("id", "")) == rid:
				proto = (r as Dictionary).duplicate(true)
				break
		if proto.is_empty():
			continue
		proto["faceDown"] = false
		proto.erase("usedThisTurn")
		(me["dungeon"] as Array).push_front([proto])
		board.refresh()
		var acts := gm.legal_moves(0).filter(func(m): return m["type"] == "activateRoom" and int(m["args"][0]) == 0)
		if acts.is_empty():
			(me["dungeon"] as Array).pop_front()
			board.refresh()
			continue
		done = true
		var slot: DungeonSlot = null
		for sl in board._dungeon_slots:
			if (sl as DungeonSlot).slot_index == 0 and not (sl as DungeonSlot).current_stack.is_empty():
				slot = sl
		if _check(slot != null, "salle activable %s : aucun emplacement" % rid) and _check(slot.activatable, "salle activable %s : pas de halo" % rid):
			var log_n := (G.get("log", []) as Array).size()
			var ev := InputEventMouseButton.new()
			ev.button_index = MOUSE_BUTTON_LEFT
			ev.pressed = true
			slot._gui_input(ev)
			await get_tree().process_frame
			var changed: bool = (G.get("log", []) as Array).size() != log_n or bool((proto).get("usedThisTurn", false)) or board._popup_kind != "" or not (G.get("pendingChoice", {}) as Dictionary).is_empty()
			_check(changed, "clic gauche sur la salle %s : capacite non declenchee" % rid)
			if board._popup_kind == "choice": # la capacite ouvre un choix : il s'affiche en popup centre, avec un bouton par option
				_check(not _buttons(board._popup).is_empty(), "choix en attente : popup sans bouton")
			await _drain()
	_check(done, "aucune salle activable trouvee pour le test de clic")
	board._popup_close()
	# 4) Menu engrenage : ouvre une fenetre (ne quitte PAS), OK referme
	var q0 := quit_calls
	board._on_menu_pressed()
	_check(board._popup_kind == "menu" and quit_calls == q0, "engrenage : menu non ouvert ou sortie directe")
	board._close_menu()
	_check(board._popup_kind == "", "menu non referme")
	# 5) Regles en superposition (le plateau reste en place), puis fermeture
	board._on_menu_pressed()
	board._open_rules()
	await get_tree().process_frame
	_check(board._rules != null and is_instance_valid(board._rules) and board._rules.get_parent() == board, "regles : pas de superposition sur le plateau")
	_check(board.hand_layer != null and is_instance_valid(board.hand_layer) and board.is_inside_tree(), "regles : plateau detruit")
	board._rules.close_viewer()
	await get_tree().process_frame
	_check(board._rules == null and board._popup_kind == "menu", "regles : fermeture -> retour au menu")
	# 6) QUIT TO MENU : confirmation, NO revient au menu, YES quitte
	var rbtns := _buttons(board._popup)
	var quit_btn: Button = null
	for b in rbtns:
		if (b as Button).text == "QUIT TO MENU":
			quit_btn = b
	if _check(quit_btn != null, "bouton QUIT TO MENU absent"):
		quit_btn.pressed.emit()
		await get_tree().process_frame
		_check(board._popup_kind == "quit" and quit_calls == q0, "confirmation de sortie absente")
		var cb := _buttons(board._popup)
		(cb[1] as Button).pressed.emit() # NO
		await get_tree().process_frame
		_check(board._popup_kind == "menu" and quit_calls == q0, "NO : retour au menu attendu")
		board._open_quit_confirm()
		await get_tree().process_frame
		cb = _buttons(board._popup)
		(cb[0] as Button).pressed.emit() # YES
		await get_tree().process_frame
		_check(quit_calls == q0 + 1, "YES : callback de sortie non appele")
