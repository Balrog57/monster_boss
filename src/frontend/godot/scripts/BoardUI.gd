class_name BoardUI
extends Control
## Interface principale du plateau de jeu Boss Monster (Board.tscn).

const GameManager = preload("res://godot/scripts/GameManager.gd")
const OnlineGameManager = preload("res://godot/scripts/OnlineGameManager.gd")
const BossEngine = preload("res://godot/scripts/BossEngine.gd")
## Gère la ville en haut, les 5 emplacements de donjon, la main en bas (drag & drop),
## et les piles de pioche/défausse.

var game_manager: GameManager
var on_exit_callback: Callable
## Siège observé en multijoueur local (hotseat) : chaque humain voit sa main.
## shortcut: pas de multi en ligne côté Godot — le backend Node/Socket.IO existe
## (src/backend/server/) mais n'est pas branché au client ; à porter via WebSocket.
var view_pid: int = 0
var seat_bar: HBoxContainer
## Ligne de choix (pendingChoice serveur) et coups avances (sorts, capacites).
var choice_bar: HBoxContainer
var extra_bar: HBoxContainer
var discard_pick: Array = []

const CORE_MOVE_TYPES := ["pickBoss", "buildInitialRoom", "buildRoom", "pass", "resolveNextHero", "openingDiscard", "resolveLevelUpChoice"]

func _is_online() -> bool:
	return game_manager is OnlineGameManager

func _my_pid() -> int:
	if _is_online():
		return (game_manager as OnlineGameManager).my_pid
	return view_pid

@onready var hud_status: Label = $TopBar/StatusLabel
@onready var hud_stats: Label = $TopBar/StatsLabel
@onready var town_container: HBoxContainer = $TownArea/TownContainer
@onready var dungeon_slots_container: HBoxContainer = $DungeonArea/PlayerDungeon
@onready var foe_dungeon_container: HBoxContainer = $DungeonArea/FoeDungeon
@onready var hand_container: HBoxContainer = $BottomArea/HandScroll/HandContainer
@onready var deck_info_label: Label = $DeckArea/DeckInfoLabel
@onready var discard_info_label: Label = $DeckArea/DiscardInfoLabel
@onready var foe_title: Label = $DungeonArea/FoeTitle
@onready var player_title: Label = $DungeonArea/PlayerTitle
@onready var hand_title: Label = $BottomArea/HandTitle
@onready var btn_advance: Button = $BottomArea/ActionButtons/BtnAdvance
@onready var btn_pass: Button = $BottomArea/ActionButtons/BtnPass
@onready var log_label: Label = $BottomArea/LogLabel

var _card_scene = preload("res://godot/scenes/Card.tscn")
var _slot_scene = preload("res://godot/scenes/DungeonSlot.tscn")
var _dungeon_slots: Array = []
var _ai_timer: float = 0.0

func setup(p_gm: GameManager, p_exit_cb: Callable) -> void:
	game_manager = p_gm
	on_exit_callback = p_exit_cb
	view_pid = 0

	_build_seat_bar()
	choice_bar = HBoxContainer.new()
	choice_bar.add_theme_constant_override("separation", 8)
	var bottom_bar: VBoxContainer = $BottomArea
	bottom_bar.add_child(choice_bar)
	bottom_bar.move_child(choice_bar, 1)
	extra_bar = HBoxContainer.new()
	extra_bar.add_theme_constant_override("separation", 8)
	bottom_bar.add_child(extra_bar)
	bottom_bar.move_child(extra_bar, 2)
	game_manager.state_changed.connect(refresh)
	if btn_advance:
		btn_advance.pressed.connect(_on_advance_pressed)
	if btn_pass:
		btn_pass.pressed.connect(_on_pass_pressed)

	_init_dungeon_slots()
	refresh()

## Barre de sièges hotseat : visible seulement si 2+ humains.
func _build_seat_bar() -> void:
	seat_bar = HBoxContainer.new()
	seat_bar.add_theme_constant_override("separation", 8)
	var bottom: VBoxContainer = $BottomArea
	bottom.add_child(seat_bar)
	bottom.move_child(seat_bar, 0)

func _refresh_seat_bar() -> void:
	for c in seat_bar.get_children():
		c.queue_free()
	if _is_online():
		seat_bar.visible = false
		return
	var players: Dictionary = game_manager.G.get("players", {})
	var humans: Array = []
	for pid in players:
		if not (players[pid] as Dictionary).get("isAI", false):
			humans.append(int(pid))
	seat_bar.visible = humans.size() > 1
	if humans.size() <= 1:
		return
	humans.sort()
	for pid in humans:
		var b := Button.new()
		b.text = "Joueur %d" % (pid + 1)
		b.disabled = (pid == view_pid)
		var p: int = int(pid)
		b.pressed.connect(func(): view_pid = p; _sync_slot_pids(); refresh())
		seat_bar.add_child(b)

func _sync_slot_pids() -> void:
	for slot in _dungeon_slots:
		(slot as DungeonSlot).player_id = view_pid

func _init_dungeon_slots() -> void:
	for child in dungeon_slots_container.get_children():
		child.queue_free()
	_dungeon_slots.clear()

	for i in CardDB.DUNGEON_SLOTS:
		var slot: DungeonSlot = _slot_scene.instantiate()
		dungeon_slots_container.add_child(slot)
		slot.setup(game_manager, i, view_pid)
		_dungeon_slots.append(slot)

func _process(delta: float) -> void:
	if game_manager == null or game_manager.G.get("gameOver") != null:
		return
	# Gestion du tour IA (y compris la salle initiale en phase setup).
	var players: Dictionary = game_manager.G.get("players", {})
	for pid in players:
		if (players[pid] as Dictionary).get("isAI", false):
			var moves := game_manager.legal_moves(int(pid))
			var phase: String = str(game_manager.G.get("phase", ""))
			if not moves.is_empty() and (phase == "boss" or phase == "setup" or phase == "build"):
				_ai_timer += delta
				if _ai_timer > 0.5:
					_ai_timer = 0.0
					var mv = AI.pick_move(game_manager, int(pid))
					if mv != null:
						game_manager.apply_move(int(pid), mv)
						refresh()
				return

func refresh() -> void:
	if game_manager == null or game_manager.G.is_empty():
		return

	var G: Dictionary = game_manager.G
	if _is_online():
		view_pid = _my_pid()
		_sync_slot_pids()
	if not (G.get("players", {}) as Dictionary).has(view_pid):
		view_pid = 0
		_sync_slot_pids()
	_refresh_seat_bar()
	var p: Dictionary = (G["players"] as Dictionary)[view_pid]
	var phase: String = G.get("phase", "")

	# 1. Top HUD
	if G.get("gameOver") != null:
		var w = G["gameOver"].get("winner", -1)
		hud_status.text = "PARTIE TERMINÉE — Gagnant : Joueur %s (%s)" % [str(int(w) + 1), G["gameOver"].get("reason", "")]
	else:
		var timer_str := ""
		var deadline := int(G.get("turnDeadline", 0))
		if deadline > 0:
			var now_ms: float = Time.get_unix_time_from_system() * 1000.0
			var rem_sec := clampi(int((deadline - now_ms) / 1000.0), 0, 999)
			timer_str = " | ⏱️ %ds" % rem_sec
		hud_status.text = "Tour %d — Phase %s — Joueur %d%s" % [G.get("turn", 0), phase.to_upper(), view_pid + 1, timer_str]
	foe_title.text = "AUTRES DONJONS :"
	player_title.text = "DONJON DU JOUEUR %d (glissez vos cartes sur les emplacements) :" % (view_pid + 1)
	hand_title.text = "MAIN DU JOUEUR %d (glissez une salle vers le donjon ou cliquez) :" % (view_pid + 1)
	
	hud_stats.text = "Âmes : %d/10 | Blessures : %d/5 | Boss : %s" % [
		CardDB.total_souls(p),
		CardDB.total_wounds(p),
		p.get("boss", {}).get("name", "Non choisi") if p.get("boss") else "Choix du Boss..."
	]

	# 2. Ville (Héros en attente)
	for c in town_container.get_children():
		c.queue_free()
	for hero in G.get("town", []):
		var hero_card = _card_scene.instantiate()
		town_container.add_child(hero_card)
		hero_card.is_in_hand = false
		hero_card.setup(hero)

	# 3. Donjon du joueur (mise à jour des stacks de chaque slot)
	var dungeon: Array = p.get("dungeon", [])
	for i in range(_dungeon_slots.size()):
		var slot: DungeonSlot = _dungeon_slots[i]
		if i < dungeon.size():
			slot.set_stack(dungeon[i])
		else:
			slot.set_stack([])

	# 4. Autres donjons (résumé, tous les sièges sauf celui observé)
	for c in foe_dungeon_container.get_children():
		c.queue_free()
	for pid in (G["players"] as Dictionary):
		if int(pid) == view_pid:
			continue
		var foe: Dictionary = (G["players"] as Dictionary)[pid]
		for stack in foe.get("dungeon", []):
			var r = BossEngine.active_room(stack)
			var lbl := Label.new()
			if r != null:
				lbl.text = "[J%d %s - %ddmg]" % [int(pid) + 1, r.get("name", "?"), int(r.get("damage", 0))]
			else:
				lbl.text = "[J%d vide]" % [int(pid) + 1]
			lbl.add_theme_font_size_override("font_size", 14)
			foe_dungeon_container.add_child(lbl)

	# 5. Piles de pioche et défausse
	var decks: Dictionary = G.get("decks", {})
	deck_info_label.text = "Pioche Salles : %d\nPioche Sorts : %d\nHéros restants : %d" % [
		decks.get("rooms", []).size(),
		decks.get("spells", []).size(),
		decks.get("heroes", []).size() + decks.get("epics", []).size()
	]
	discard_info_label.text = "Défausse Salles : %d\nDéfausse Sorts : %d\nDéfausse Héros : %d" % [
		decks.get("roomDiscard", []).size(),
		decks.get("spellDiscard", []).size(),
		decks.get("heroDiscard", []).size()
	]

	# 6. Main du joueur (Cartes interactives / Draggables)
	for c in hand_container.get_children():
		c.queue_free()
	
	if phase == "boss":
		# Choix initial de boss
		for b in G.get("bossPicks", []):
			var boss_card = _card_scene.instantiate()
			hand_container.add_child(boss_card)
			boss_card.setup(b)
			var bid = str(b.get("id", ""))
			boss_card.card_clicked.connect(func(_data): _do({"type": "pickBoss", "args": [bid]}))
	else:
		var hand: Array = p.get("hand", [])
		for i in hand.size():
			var card_dict: Dictionary = hand[i]
			var card_ui = _card_scene.instantiate()
			hand_container.add_child(card_ui)
			card_ui.setup(card_dict, i)
			var idx := i
			card_ui.card_clicked.connect(func(_data): _on_hand_card_clicked(idx, card_dict))

	# 7. Boutons d'action (en ligne : le serveur dicte les coups dispos).
	var my_moves: Array = game_manager.legal_moves(_my_pid()) if _is_online() else []
	btn_advance.visible = (phase == "adventure") or _has_move(my_moves, "resolveNextHero")
	btn_pass.visible = (phase == "build") or _has_move(my_moves, "pass")
	_refresh_choice_bar(G, my_moves)
	_refresh_extra_bar(G, my_moves)

	# 8. Logs
	var logs: Array = G.get("log", [])
	log_label.text = "\n".join(logs.slice(max(0, logs.size() - 4)))

func _has_move(moves: Array, mtype: String) -> bool:
	for m in moves:
		if m is Dictionary and str((m as Dictionary).get("type", "")) == mtype:
			return true
	return false

func _moves_of(moves: Array, mtype: String) -> Array:
	var out: Array = []
	for m in moves:
		if m is Dictionary and str((m as Dictionary).get("type", "")) == mtype:
			out.append(m)
	return out

## Barre de choix : defausse initiale (selection 2 cartes) ou choix generique.
func _refresh_choice_bar(G: Dictionary, my_moves: Array) -> void:
	for c in choice_bar.get_children():
		c.queue_free()
	if not _is_online():
		choice_bar.visible = false
		discard_pick.clear()
		return
	var pc: Dictionary = G.get("pendingChoice", {})
	if pc.is_empty() or int(pc.get("playerId", -1)) != _my_pid():
		choice_bar.visible = false
		discard_pick.clear()
		return
	choice_bar.visible = true
	if str(pc.get("type", "")) == "opening-discard":
		var lbl := Label.new()
		lbl.text = "Defausse initiale : cliquez 2 cartes (%d/2)" % discard_pick.size()
		choice_bar.add_child(lbl)
		if discard_pick.size() == 2:
			var ok := Button.new()
			ok.text = "Defausser"
			var pair := discard_pick.duplicate()
			pair.sort()
			ok.pressed.connect(func(): _do({"type": "openingDiscard", "args": pair}))
			choice_bar.add_child(ok)
	else:
		var opts: Array = pc.get("options", [])
		for m in _moves_of(my_moves, "resolveLevelUpChoice"):
			var i: int = int((m as Dictionary).get("args", [0])[0])
			var b := Button.new()
			b.text = _option_label(opts, i)
			var mv := (m as Dictionary).duplicate()
			b.pressed.connect(func(): _do(mv))
			choice_bar.add_child(b)

func _option_label(opts: Array, i: int) -> String:
	if i < 0:
		return "Passer"
	if i < opts.size() and opts[i] is Dictionary:
		var o: Dictionary = opts[i]
		for k in ["label", "name"]:
			if str(o.get(k, "")) != "":
				return str(o[k])
		if (o.get("card", {}) as Dictionary).get("name", "") != "":
			return str((o["card"] as Dictionary)["name"])
		if o.has("targetPlayerId"):
			return "Joueur %d" % (int(o["targetPlayerId"]) + 1)
	return "Choix %d" % (i + 1)

## Coups avances du serveur (sorts, capacites) : un bouton par coup propose.
func _refresh_extra_bar(G: Dictionary, my_moves: Array) -> void:
	for c in extra_bar.get_children():
		c.queue_free()
	if not _is_online():
		extra_bar.visible = false
		return
	var shown := false
	var hand: Array = ((G.get("players", {}) as Dictionary).get(_my_pid(), {}) as Dictionary).get("hand", [])
	for m in my_moves:
		if not (m is Dictionary) or str((m as Dictionary).get("type", "")) in CORE_MOVE_TYPES:
			continue
		var b := Button.new()
		b.text = _move_label(m, G, hand)
		var mv := (m as Dictionary).duplicate()
		b.pressed.connect(func(): _do(mv))
		extra_bar.add_child(b)
		shown = true
	extra_bar.visible = shown

func _move_label(m: Dictionary, _G: Dictionary, hand: Array) -> String:
	var t := str(m.get("type", ""))
	var args: Array = m.get("args", [])
	var hand_name := ""
	if not args.is_empty() and args[0] is int and int(args[0]) >= 0 and int(args[0]) < hand.size():
		hand_name = str((hand[int(args[0])] as Dictionary).get("name", ""))
	match t:
		"playSpell":
			return "Sort : %s" % hand_name
		"useHandRoom", "activateRoom":
			return "Capacite : %s" % hand_name
		"buildMiniboss", "promoteMiniboss", "activateMiniboss":
			return "Miniboss (%s)" % t
		"payDarkHero":
			return "Payer (heros noir)"
		"docScarecrow":
			return "Epouvantail"
		"timebenderCancel":
			return "Contre-sort"
		_:
			return hand_name if hand_name != "" else t

func _do(move: Dictionary) -> void:
	if game_manager.apply_move(_my_pid(), move):
		refresh()

func _on_hand_card_clicked(idx: int, card: Dictionary) -> void:
	if _is_online() and _is_opening_discard_for_me():
		if discard_pick.has(idx):
			discard_pick.erase(idx)
		elif discard_pick.size() < 2:
			discard_pick.append(idx)
		refresh()
		return
	var phase: String = game_manager.G.get("phase", "")
	if phase == "setup":
		game_manager.build_room_at(_my_pid(), idx, 0)
	elif phase == "build" and card.get("isRoom", false):
		# Clic simple : construit sur le premier emplacement disponible
		var dungeon: Array = ((game_manager.G["players"] as Dictionary)[_my_pid()] as Dictionary).get("dungeon", [])
		var target_slot := dungeon.size()
		game_manager.build_room_at(_my_pid(), idx, target_slot)

func _is_opening_discard_for_me() -> bool:
	var pc: Dictionary = game_manager.G.get("pendingChoice", {})
	return str(pc.get("type", "")) == "opening-discard" and int(pc.get("playerId", -1)) == _my_pid()


func _on_advance_pressed() -> void:
	if _is_online():
		_do({"type": "resolveNextHero", "args": []})
	else:
		game_manager.apply_move(_my_pid(), {"type": "adventureNext", "args": []})
		refresh()

func _on_pass_pressed() -> void:
	if _is_online():
		_do({"type": "pass", "args": []})
	else:
		if game_manager.apply_move(_my_pid(), {"type": "passBuild", "args": []}):
			refresh()

func _on_menu_pressed() -> void:
	if on_exit_callback.is_valid():
		on_exit_callback.call()
