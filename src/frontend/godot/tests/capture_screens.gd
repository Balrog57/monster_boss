extends Node
## Capture des ecrans du jeu Godot pour comparaison avec les frames de l'APK (docs/reference/apk_orig/, voir INDEX.md).
## A lancer FENETRE (le moteur de rendu headless ne capture pas) :
##   godot --path src/frontend --resolution 1920x1080 res://godot/tests/CaptureScreens.tscn [-- --out=<dossier>]
## Sortie : docs/reference/godot_screens/godot_<nom de la frame APK>.png (hors de src/, donc hors du pck web).
## Parties graine fixe, etats injectes dans GameManager.G (meme technique que ui_smoke.gd), souris reelle (push_input) pour glisser / appui long.

const GameManager = preload("res://godot/scripts/GameManager.gd")
const OUT_DIR := "res://../../docs/reference/godot_screens"

var out_dir := ""
var only := ""   # --only=online : seulement les ecrans multijoueur
var gm: GameManager
var board
var main_scene
var n_shots := 0

func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout

func _frames(n: int = 4) -> void:
	for i in n:
		await get_tree().process_frame

func _shot(name: String) -> void:
	await _frames(3)
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img.get_size() != Vector2i(1920, 1080):
		img.resize(1920, 1080, Image.INTERPOLATE_BILINEAR)
	DirAccess.make_dir_recursive_absolute(out_dir)
	img.save_png("%s/godot_%s.png" % [out_dir, name])
	n_shots += 1
	print("Captured: ", name)

func _ready() -> void:
	out_dir = ProjectSettings.globalize_path(OUT_DIR)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_dir = a.substr(6)
		elif a.begins_with("--only="):
			only = a.substr(7)
	AudioServer.set_bus_mute(0, true)
	await _wait(0.3)
	if only == "online":
		await _online_menus()
		print("ONLINE SCREENS CAPTURED: ", n_shots)
		get_tree().quit(0)
		return
	await _menus()
	await _online_menus()
	await _board_shots()
	await _states()
	await _end_screens()
	print("ALL GODOT SCREENS CAPTURED: ", n_shots)
	get_tree().quit(0)

# ---------------------------------------------------------------------------------------------------------------------
# Menus (menu principal, carrousel joueurs...)
# ---------------------------------------------------------------------------------------------------------------------

func _menus() -> void:
	main_scene = load("res://godot/scenes/Main.tscn").instantiate()
	add_child(main_scene)
	await _wait(0.5)
	await _shot("menu_main_single_multiplayer_options_store")
	main_scene.show_solo_count()
	await _wait(0.4)
	await _shot("menu_player_count_carousel_4_left_2_center_3_right")
	main_scene.show_options()
	await _wait(0.4)
	await _shot("menu_options")
	main_scene.queue_free()
	main_scene = null
	await _frames()

## Ecrans multijoueur (OnlineMenus.gd) : pas de frame APK de reference, comparaison a la specification C# (MultiplayerScene, MenuOnlineScene, ...).
class FakeOnline extends RefCounted:
	var current_G := {"gameOver": null, "turnDeadline": 0}
	var current_awaited := [0]
	var current_moves := []
	var player_id := 0
	var clock_offset_ms := 0

func _label_buttons() -> Dictionary:
	var out := {}
	for b in main_scene.find_children("*", "TextureButton", true, false):
		if b.get_child_count() > 0 and b.get_child(0) is Label and (b.get_child(0) as Label).name == "Label":
			out[(b.get_child(0) as Label).text] = b
	return out

func _online_menus() -> void:
	main_scene = load("res://godot/scenes/Main.tscn").instantiate()
	add_child(main_scene)
	await _wait(0.5)
	main_scene.profile = {"name": "Zed the Wise", "avatar": "avatar_gorgona"}
	main_scene.online.match_id = "KWPF"
	main_scene.online.player_id = 0
	main_scene.show_multi()
	await _wait(0.3)
	await _shot("online_multiplayer_scene_decks_closed")
	await _wait(1.8)
	await _shot("online_multiplayer_scene_play_online_pass_and_play")
	main_scene.menus.show_online()
	await _wait(0.4)
	await _shot("online_menu_worldwide_with_friends_change_user")
	main_scene.menus.msg_box("NETWORK ERROR", "Unable to join public rooms")
	await _wait(0.3)
	await _shot("online_message_box_network_error")
	main_scene.menus.show_profile(true, false)
	await _wait(0.4)
	await _shot("online_change_name_avatar")
	main_scene.find_children("*", "LineEdit", true, false)[0].grab_focus()
	await _wait(0.2)
	await _shot("online_change_name_avatar_entry_focused")
	main_scene.menus.show_friends()
	await _wait(0.4)
	await _shot("online_with_friends_new_game_room_code")
	_label_buttons()["ROOM CODE"].pressed.emit()
	await _wait(0.8)
	var e: LineEdit = main_scene.find_children("*", "LineEdit", true, false)[0] # le nom « Entry » peut etre pris par l'ecran precedent (libere en fin d'image)
	await _shot("online_with_friends_room_code_entry_empty")
	e.grab_focus()
	e.text = "KWPF"
	await _wait(0.2)
	await _shot("online_with_friends_room_code_entry_typed")
	main_scene.show_solo_count("online")
	await _wait(0.4)
	await _shot("online_new_game_how_many_players")
	var o = main_scene.online
	o.is_host = true
	main_scene.show_waiting()
	await _wait(0.2)
	var seat := func(n, av, w, d, bot): return {"name": n, "bot": bot, "connected": true, "avatar": av, "wins": w, "defeats": d}
	var free := {"name": null, "bot": false, "connected": false, "avatar": "", "wins": 0, "defeats": 0}
	o.lobby_changed.emit({"status": "open", "numPlayers": 4, "host": 0, "seats": [seat.call("Zed the Wise", "avatar_gorgona", 12, 7, false), free, free, free]})
	await _wait(0.5)
	await _shot("online_waiting_room_host_alone_start_with_bots")
	o.lobby_changed.emit({"status": "open", "numPlayers": 4, "host": 0, "seats": [seat.call("Zed the Wise", "avatar_gorgona", 12, 7, false), seat.call("player_k3x9", "avatar_robobo", 0, 2, false), seat.call("A very long username that never ends", "avatar_croak", 105, 3, false), free]})
	await _wait(0.5)
	await _shot("online_waiting_room_three_players_ok")
	main_scene.queue_free()
	main_scene = null
	await _frames()
	# compte a rebours sur un plateau
	await _new_game()
	var fake := FakeOnline.new()
	fake.current_G["turnDeadline"] = int(Time.get_unix_time_from_system() * 1000.0) + 42500
	var cd = load("res://godot/scripts/CountDown.gd").new(fake)
	board.add_child(cd)
	await _wait(0.6)
	await _shot("online_countdown_over_board")
	fake.current_G["turnDeadline"] = int(Time.get_unix_time_from_system() * 1000.0) + 3500
	await _wait(0.6)
	await _shot("online_countdown_under_5s")
	await _teardown()

# ---------------------------------------------------------------------------------------------------------------------
# Plateau
# ---------------------------------------------------------------------------------------------------------------------

func _teardown() -> void:
	Engine.time_scale = 1.0
	if board != null and is_instance_valid(board):
		board.queue_free()
	if gm != null and is_instance_valid(gm):
		gm.queue_free()
	board = null
	gm = null
	await _frames(2)

func _act_simple() -> void:
	var G: Dictionary = gm.G
	var phase: String = G.get("phase", "")
	var me: Dictionary = (G["players"] as Dictionary)[0]
	var pc: Dictionary = G.get("pendingChoice", {})
	if board._last_phase != phase and phase != "":
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
	if phase == "boss" and me.get("boss") == null and not board._boss_cards.is_empty():
		board._boss_cards[0].card_clicked.emit(null)
		board._confirm_btn.pressed.emit()

## Partie neuve (graine fixe) amenee au debut de la construction du tour 1. stop_at = "boss" / "discard" : s'arrete plus tot (ecrans de debut).
func _new_game(seed_: int = 424242, stop_at := "") -> void:
	await _teardown()
	seed(seed_)
	CardDB._rng.seed = seed_
	gm = GameManager.new()
	add_child(gm)
	gm.rng.seed = seed_
	gm.start_new_game(2, 1, ["base"])
	board = load("res://godot/scenes/Board.tscn").instantiate()
	board.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(board)
	board.skip_animations = true
	board.setup(gm, func(): pass)
	await _wait(0.1)
	if stop_at == "boss":
		return
	for step in 150:
		var G: Dictionary = gm.G
		if stop_at == "discard" and board._is_opening_discard_for_me():
			return
		if (str(G.get("phase", "")) == "build" or (str(G.get("phase", "")) == "setup" and bool(G.get("setupBuild", false)))) and (G.get("pendingChoice", {}) as Dictionary).is_empty() and int((G["players"][0] as Dictionary).get("buildsThisTurn", 0)) == 0 and not gm.legal_moves(0).is_empty():
			board.set_process(false)
			return
		await _wait(0.05)
		_act_simple()
		board._process(0.21)
	var Gd: Dictionary = gm.G
	push_error("capture : la construction du tour 1 n'a pas ete atteinte (phase=%s pc=%s builds=%s moves=%d popup=%s)" % [Gd.get("phase"), str(Gd.get("pendingChoice", {})).substr(0, 200), (Gd["players"][0] as Dictionary).get("buildsThisTurn"), gm.legal_moves(0).size(), board._popup_kind])

func _me() -> Dictionary:
	return gm.G["players"][0]

func _foe() -> Dictionary:
	return gm.G["players"][1]

## Cartes de la pioche (une copie) : salles ordinaires / avancees, sorts, par id ou au hasard (graine fixe).
func _take(kind: String, id := "") -> Dictionary:
	var deck: Array = gm.G["decks"][kind]
	for i in deck.size():
		if id == "" or str((deck[i] as Dictionary).get("id", "")) == id:
			return deck.pop_at(i)
	return {}

## Main de n cartes : on garde la main courante, on complete (salles / sorts en alternance) ou on retire.
func _hand_n(n: int, spells := -1) -> void:
	var hand: Array = _me()["hand"]
	while hand.size() > n:
		hand.pop_back()
	var k := 0
	while hand.size() < n:
		var kind := "spells" if (spells >= 0 and k < spells) else "rooms"
		if spells < 0:
			kind = "spells" if k % 3 == 2 else "rooms"
		hand.append(_take(kind))
		k += 1

func _heroes_town(n: int, epic := false, from := 0) -> void:
	var town: Array = gm.G["town"]
	town.clear()
	var pool: Array = CardDB.heroes.filter(func(h): return bool((h as Dictionary).get("epic", false)) == epic)
	for i in n:
		town.append((pool[(from + i) % pool.size()] as Dictionary).duplicate(true))

func _room_proto(type_: String, advanced := false, skip := 0) -> Dictionary:
	for r in CardDB.rooms:
		var d: Dictionary = r
		if str(d.get("type", "")) == type_ and bool(d.get("advanced", false)) == advanced and str(d.get("set", "base")) == "base":
			if skip == 0:
				var c: Dictionary = d.duplicate(true)
				c["isRoom"] = true
				c["faceDown"] = false
				return c
			skip -= 1
	return {}

func _dungeon_fill(pl: Dictionary, n: int, face_down := false) -> void:
	var dng: Array = pl["dungeon"]
	dng.clear()
	for i in n:
		var r := _room_proto("monster" if i % 2 == 0 else "trap", false, i / 2)
		r["faceDown"] = face_down
		dng.push_front([r])

## Etendue horizontale de la main (bords des cartes tournees) : comparee aux chiffres de INDEX.md.
func _hand_span() -> String:
	var x0 := 9999.0
	var x1 := 0.0
	for c in _hand_cards():
		var cc := c as Control
		var r := cc.get_global_transform() * Rect2(Vector2.ZERO, cc.size)
		x0 = minf(x0, r.position.x)
		x1 = maxf(x1, r.end.x)
	return "%d cartes x %d..%d" % [_hand_cards().size(), x0, x1]

func _settle(n: int = 5) -> void:
	board.refresh()
	await _frames(n)
	await _wait(0.12)

func _mouse(pos: Vector2, pressed: bool, motion: bool, mask: int = 0) -> void:
	var ev: InputEventMouse
	if motion:
		var m := InputEventMouseMotion.new()
		m.button_mask = mask
		ev = m
	else:
		var b := InputEventMouseButton.new()
		b.button_index = MOUSE_BUTTON_LEFT
		b.pressed = pressed
		b.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		ev = b
	ev.position = pos
	ev.global_position = pos
	get_viewport().push_input(ev, true)
	await get_tree().process_frame

func _hand_cards() -> Array:
	return board.hand_layer.get_children().filter(func(c): return not c.is_queued_for_deletion())

func _buttons(n: Node, out: Array = []) -> Array:
	for c in n.get_children():
		if c is BaseButton:
			out.append(c)
		_buttons(c, out)
	return out

func _board_shots() -> void:
	# --- debut de partie : choix du boss, defausse de 2 cartes
	await _new_game(424242, "boss")
	await _shot("boss_pick_carousel")
	await _new_game(424242, "discard")
	await _settle()
	await _shot("discard_hand_7cards")

	# --- tour 1 : donjons vides, main de 5
	await _new_game()
	await _settle()
	await _shot("build_t1_empty_dungeons_5_slot_outlines_room_deck_pile_in_opponent_row")

	# --- main en eventail : 5, 6, 7, 8 cartes (ville 3 heros ordinaires puis epiques)
	_heroes_town(3)
	_dungeon_fill(_me(), 2)
	_dungeon_fill(_foe(), 3)
	_hand_n(5, 1)
	await _settle()
	print("SPAN ", _hand_span())
	await _shot("build_t3_hand_5cards_mage_thief_cleric_in_town")
	_hand_n(6, 2)
	await _settle()
	print("SPAN ", _hand_span())
	await _shot("build_t5_hand_6_cards_wide_fan_playable_rooms_colored_spells_grey")
	_heroes_town(4, true)
	_dungeon_fill(_me(), 3)
	_dungeon_fill(_foe(), 4)
	_hand_n(7, 2)
	await _settle()
	print("SPAN ", _hand_span())
	await _shot("build_t6_hand_7_cards_fan_epic_heroes_gold_cards_in_town")
	_heroes_town(5, true)
	_dungeon_fill(_foe(), 5)
	_hand_n(8, 3)
	await _settle()
	await _frames(3)
	var sc: ScrollContainer = board._town_scroll
	sc.scroll_vertical = int(sc.get_v_scroll_bar().max_value)
	await _frames(3)
	print("SPAN ", _hand_span())
	await _shot("build_t7_hand_8_cards_wide_fan_hero_column_overflow_scrolled")

	# --- bulle de mise en garde (PASS TURN alors qu'une salle peut etre construite)
	board._on_pass_pressed()
	await _frames(3)
	for l in board._warn.find_children("*", "Label", true, false):
		print("DBG warn label size=", (l as Label).size, " lines=", (l as Label).get_line_count(), " lh=", (l as Label).get_line_height(), " font_h=", (l as Label).get_theme_font("font").get_height(21), " text=", (l as Label).text.json_escape())
	await _shot("build_t7_pass_warning_bubble_8_card_hand_fan")
	board._warn_hide()

	# --- carte selectionnee (survol / appui) puis glisser au-dessus d'un emplacement, puis appui long
	_hand_n(6, 2)
	_heroes_town(3)
	_dungeon_fill(_me(), 1)
	_dungeon_fill(_foe(), 3)
	await _settle()
	var hand: Array = _me()["hand"]
	var idx := -1
	for i in hand.size():
		if gm.can_build_room_at(0, i, (_me()["dungeon"] as Array).size()) and not bool((hand[i] as Dictionary).get("advanced", false)):
			idx = i
			break
	var card: CardUI = _hand_cards()[idx]
	var c0 := card.get_global_rect().get_center()
	await _mouse(Vector2(c0.x, c0.y - 60.0), false, true, 0) # survol : la carte monte
	await _wait(0.3)
	await _shot("build_card_selected_in_hand")
	await _mouse(Vector2(1000, 400), false, true, 0)
	await _wait(0.3)
	var slot_c: Vector2 = (board._dungeon_slots[3] as Control).get_global_rect().get_center()
	await _mouse(c0, true, false)
	for k in range(1, 9):
		await _mouse(c0.lerp(slot_c, float(k) / 8.0), false, true, MOUSE_BUTTON_MASK_LEFT)
	await _wait(0.2)
	await _shot("build_dragging_card_over_slot_midway")
	await _mouse(c0, false, false) # annule (relache sur la main)
	await _settle()
	card = _hand_cards()[idx]
	c0 = card.get_global_rect().get_center()
	await _mouse(c0, true, false)
	await _wait(1.1)
	await _shot("build_longpress_card_zoom_preview")
	await _mouse(c0, false, false)
	await _frames(3)
	# appui long sur un sort grise (construction)
	var gi := -1
	for i in hand.size():
		if bool((hand[i] as Dictionary).get("isSpell", false)):
			gi = i
	if gi >= 0:
		c0 = _hand_cards()[gi].get_global_rect().get_center()
		await _mouse(c0, true, false)
		await _wait(1.1)
		await _shot("longpress_motivation_spell_zoom_greyscale_unplayable_in_build_phase")
		await _mouse(c0, false, false)
		await _frames(3)

	# --- salles empilees : salle posee sur une salle visible (la plus ancienne dessine son bandeau)
	var over := _room_proto("trap", false, 1)
	((_me()["dungeon"] as Array)[0] as Array).push_back(over)
	((_foe()["dungeon"] as Array)[1] as Array).push_back(_room_proto("monster", false, 2))
	await _settle()
	await _shot("stacked_rooms_older_card_peeks_header_strip")

	# --- Level up : zoom du boss
	board._on_level_up_pressed()
	await _frames(3)
	await _shot("levelup_button_tap_shows_boss_card_zoom_with_levelup_text")
	board._zoom_hide()

func _states() -> void:
	# --- fenetre d'aventure : barre de temps verte au-dessus du heros, sort dore en main
	await _new_game()
	board.win_time_scale = 1.0
	var G: Dictionary = gm.G
	var me := _me()
	var foe := _foe()
	(foe["hand"] as Array).clear()
	_dungeon_fill(foe, 0)
	_dungeon_fill(me, 3)
	_heroes_town(3)
	var hero: Dictionary = (CardDB.heroes[5] as Dictionary).duplicate(true)
	(me["entrance"] as Array).clear()
	(me["entrance"] as Array).append(hero)
	G["phase"] = "adventure"
	G.erase("buildWindow")
	G["adventure"] = {"playerId": 0, "hero": hero, "roomIndex": 1, "hp": 12, "pause": "post-damage"}
	G["adventurePausePassed"] = {"1": true, 1: true}
	G["activePlayer"] = 0
	_hand_n(5, 2)
	await _settle()
	board._process(0.4)
	await _frames(3)
	await _shot("adv_timer_bar_full_green_above_hero_card")
	for i in 5:
		board._process(0.4)
	await _frames(2)
	await _shot("adv_timer_bar_nearly_empty")

	# --- pile de sorts au centre avec barre de temps
	await _new_game()
	board.win_time_scale = 1.0
	G = gm.G
	me = _me()
	(_foe()["hand"] as Array).clear()
	_dungeon_fill(_me(), 2)
	_dungeon_fill(_foe(), 2)
	_hand_n(5, 2)
	var spell := _take("spells", "BMA050") # Motivation
	if spell.is_empty():
		spell = (CardDB.spells[0] as Dictionary).duplicate(true)
	spell["isSpell"] = true
	G["stack"] = [{"id": "spell-x-1", "type": "spell", "playerId": 1, "card": spell, "target": {}, "resolved": false}]
	G["stackPassed"] = {"1": true, 1: true}
	G["stackReturnPlayer"] = 1
	G["stackActivePlayer"] = 1
	G["activePlayer"] = 0
	(me["hand"] as Array).append(_take("spells", "BMA043")) # Counterspell
	await _settle()
	board._process(0.5)
	board._process(0.5)
	await _frames(3)
	await _shot("spell_stack_motivation_in_center_with_green_timer_bar")
	board._notice_ai(1, {"type": "playSpell", "args": []})
	await _frames(3)
	await _shot("spellbattle_has_played_a_spell_notice_top_right_exhaustion_stack")

	# --- capacite de salle adverse (notice + carte de la salle soulevee)
	await _new_game()
	_dungeon_fill(_me(), 2)
	_dungeon_fill(_foe(), 3)
	_hand_n(5, 1)
	await _settle()
	board._notice_ai(1, {"type": "activateRoom", "args": [0]})
	await _frames(3)
	await _shot("notice_opponent_has_played_a_room_ability_mimic_vault_glow")

	# --- heros assignes aux donjons (leurre) : cartes en eventail a l'entree des deux couloirs
	for k in 3:
		(_me()["entrance"] as Array).append((CardDB.heroes[k] as Dictionary).duplicate(true))
	for k in 2:
		(_foe()["entrance"] as Array).append((CardDB.heroes[4 + k] as Dictionary).duplicate(true))
	gm.G["phase"] = "adventure"
	await _settle()
	if board._notice != null and is_instance_valid(board._notice):
		board._notice.free()
	board._notice = null
	await _frames(2)
	await _shot("bait_phase_heroes_assigned_to_dungeons")
	gm.G["phase"] = "build"
	(_me()["entrance"] as Array).clear()
	(_foe()["entrance"] as Array).clear()
	await _settle()

	# --- sort Freeze resolu : glace sur une salle adverse (la notice est partie)
	if board._notice != null and is_instance_valid(board._notice):
		board._notice.free()
	board._notice = null
	for sl in board._foe_slots:
		var cu: Array = (sl as Control).find_children("*", "CardUI", true, false)
		if not cu.is_empty():
			(cu[0] as CardUI).set_frozen(true)
			break
	await _frames(3)
	await _shot("spell_freeze_resolved_target_room_frozen_ice")

	# --- coups portes : ames / blessures
	var G2: Dictionary = gm.G
	for i in 3:
		(_me()["wounds"] as Array).append({"name": "x", "wounds": 1})
	for i in 4:
		(_me()["souls"] as Array).append({"name": "x", "souls": 1})
	(_foe()["souls"] as Array).append({"name": "x", "souls": 1})
	(_foe()["wounds"] as Array).append({"name": "x", "wounds": 1})
	(_foe()["wounds"] as Array).append({"name": "x", "wounds": 1})
	await _settle()
	await _shot("adv_t10_cleric_reaches_boss_wound_taken_boss_wounds_x5")
	G2["players"][1]["eliminated"] = true
	await _settle()
	await _shot("adv_boss_dead_rip_tombstone_hero_card_stack_town_left")

	# --- menus en jeu : pause, parametres, galerie
	await _new_game()
	_hand_n(5, 1)
	await _settle()
	board._on_menu_pressed()
	await _frames(4)
	await _shot("menu_paused_resume_card_gallery_settings_quit_game")
	var menu = board._popup.find_children("*", "Control", true, false).filter(func(c): return c.get_script() != null and str(c.get_script().resource_path).ends_with("InGameMenu.gd"))[0]
	menu.page = "settings"
	menu._build()
	await _frames(4)
	await _shot("menu_settings_music_sound_game_speed_toggles_back_arrow")
	menu.page = "main"
	menu._build()
	menu._open_gallery()
	await _frames(6)
	await _shot("menu_card_gallery_boss_cards_grid_left_tabs")
	var g = menu.gallery
	g.select_tab(1)
	await _frames(6)
	await _shot("menu_card_gallery_room_cards_tab")
	g.close_gallery()
	board._popup_close()

func _end_screens() -> void:
	await _new_game()
	_hand_n(5, 1)
	gm.G["gameOver"] = {"winner": 0, "reason": "souls"}
	await _settle(8)
	await _wait(0.6)
	await _shot("gameover_lose_opponent_is_the_winner_gold_crystals_ok_button")
	await _new_game()
	gm.G["gameOver"] = {"winner": 1, "reason": "wounds"}
	await _settle(8)
	await _wait(0.6)
	await _shot("gameover_lose_you_lose_tombstone")
	await _teardown()
