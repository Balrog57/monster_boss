extends Control
## Main — menu facon APK (menu_bg + logo + 4 boutons).
## SINGLE PLAYER : 2/3/4 joueurs = vous + 1 a 3 IA.
## MULTIPLAYER : entre amis uniquement (salon prive + code), pseudo + avatar.
## IN-APP STORE supprime -> RULES (icone livre rules_icon.webp).
## shortcut: pas de matchmaking mondial (bouton WORLDWIDE volontairement absent).

const EXT_PACKS := ["hidden-heroes", "tools", "players-choice", "next-level", "minibosses", "crash-landing"]

var game_manager: GameManager
var online: OnlineClient
var board: Control
var net_err_lbl: Label = null
var use_extensions := false
var server_host := "http://127.0.0.1:8000"
var profile := {"name": "Joueur", "avatar": "avatar_draculord"}
var selected_avatar := "avatar_draculord"

func _ready() -> void:
	game_manager = GameManager.new()
	add_child(game_manager)
	online = OnlineClient.new()
	add_child(online)
	var settings := Profile.load_settings()
	server_host = str(settings.get("host", server_host))
	use_extensions = bool(settings.get("extensions", false))
	profile = Profile.load_profile()
	selected_avatar = str(profile.get("avatar", selected_avatar))
	show_menu()

func _clear() -> void:
	for c in get_children():
		if c != game_manager and c != online:
			c.queue_free()
	board = null

func _active_sets() -> Array:
	return EXT_PACKS if use_extensions else []

# --- widgets ---------------------------------------------------------------

func _bg(path: String) -> TextureRect:
	var t := TextureRect.new()
	t.set_anchors_preset(Control.PRESET_FULL_RECT)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_SCALE
	if ResourceLoader.exists(path):
		t.texture = load(path)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t

func _screen(bg_path: String) -> VBoxContainer:
	_clear()
	if bg_path != "":
		add_child(_bg(bg_path))
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 14)
	center.add_child(v)
	return v

func _menu_btn(text: String, icon_path: String = "") -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(460, 72)
	b.add_theme_font_size_override("font_size", 28)
	if icon_path != "" and ResourceLoader.exists(icon_path):
		b.icon = load(icon_path)
		b.expand_icon = true
	return b

func _title_label(text: String, size: int = 40) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	return l

func _back_btn(where: Callable) -> Button:
	var b := Button.new()
	b.text = "Retour"
	b.pressed.connect(where)
	return b

# --- menu principal ----------------------------------------------------------

func show_menu() -> void:
	online.stop_lobby_poll()
	online.stop_state_poll()
	_net_disconnect()
	var v := _screen("res://assets/ui/backgrounds/menu_bg.webp")
	if ResourceLoader.exists("res://assets/ui/navigation/bm_logo.webp"):
		var logo := TextureRect.new()
		logo.texture = load("res://assets/ui/navigation/bm_logo.webp")
		logo.custom_minimum_size = Vector2(520, 130)
		logo.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(logo)
	else:
		v.add_child(_title_label("BOSS MONSTER", 72))
	var single := _menu_btn("SINGLE PLAYER", "res://assets/ui/navigation/boss_icon.webp")
	single.pressed.connect(func(): show_solo_count())
	v.add_child(single)
	var multi := _menu_btn("MULTIPLAYER", "res://assets/ui/navigation/boss_multi_icon.webp")
	multi.pressed.connect(func(): show_multi())
	v.add_child(multi)
	var opts := _menu_btn("OPTIONS", "res://assets/ui/navigation/options_icon.webp")
	opts.pressed.connect(func(): show_options())
	v.add_child(opts)
	var rules := _menu_btn("RULES", "res://assets/ui/navigation/rules_icon.webp")
	rules.pressed.connect(func(): show_rules())
	v.add_child(rules)

# --- solo : HOW MANY PLAYERS? -------------------------------------------------

func show_solo_count() -> void:
	var v := _screen("res://assets/ui/backgrounds/menu_bg.webp")
	v.add_child(_title_label("HOW MANY PLAYERS?"))
	for n in [2, 3, 4]:
		var b := _menu_btn("%d  (vous + %d IA)" % [n, n - 1])
		var count := n
		b.pressed.connect(func(): show_setup(count, 1))
		v.add_child(b)
	v.add_child(_back_btn(func(): show_menu()))

func show_setup(num_players: int, human_count: int) -> void:
	var v := _screen("res://assets/ui/backgrounds/menu_bg.webp")
	if human_count < num_players:
		v.add_child(_title_label("Solo : vous contre %d IA." % (num_players - human_count), 26))
	else:
		v.add_child(_title_label("Multijoueur local : %d humains." % num_players, 26))
	v.add_child(_title_label("Paquets : %s." % ("base + extensions" if use_extensions else "base"), 20))
	var start := _menu_btn("OK")
	start.pressed.connect(func(): start_match(num_players, human_count))
	v.add_child(start)
	v.add_child(_back_btn(func(): show_menu()))

func start_match(num_players: int, human_count: int) -> void:
	_clear()
	game_manager.start_new_game(num_players, human_count, _active_sets())
	_open_board(game_manager)

func _open_board(gm: GameManager) -> void:
	var board_scene = load("res://godot/scenes/Board.tscn")
	board = board_scene.instantiate()
	board.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(board)
	board.setup(gm, func(): show_menu())

# --- multi : WITH FRIENDS / CHANGE USER/AVATAR ---------------------------------

func show_multi() -> void:
	var v := _screen("res://assets/ui/backgrounds/multiplayer_bg.webp")
	v.add_child(_title_label("%s" % profile.get("name", "Joueur"), 28))
	var friends := _menu_btn("WITH FRIENDS")
	friends.pressed.connect(func(): show_friends())
	v.add_child(friends)
	var change := _menu_btn("CHANGE USER/AVATAR")
	change.pressed.connect(func(): show_profile())
	v.add_child(change)
	v.add_child(_back_btn(func(): show_menu()))

func show_profile() -> void:
	var v := _screen("res://assets/ui/backgrounds/multiplayer_bg.webp")
	v.add_child(_title_label("INSERT USERNAME", 28))
	var edit := LineEdit.new()
	edit.text = str(profile.get("name", "Joueur"))
	edit.max_length = 16
	edit.custom_minimum_size = Vector2(460, 56)
	edit.add_theme_font_size_override("font_size", 28)
	v.add_child(edit)
	v.add_child(_title_label("SELECT AVATAR", 28))
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	v.add_child(grid)
	var thumbs: Array = []
	for aid in Profile.AVATARS:
		var t := TextureRect.new()
		t.custom_minimum_size = Vector2(96, 96)
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		if ResourceLoader.exists(Profile.avatar_path(aid)):
			t.texture = load(Profile.avatar_path(aid))
		t.mouse_filter = Control.MOUSE_FILTER_STOP
		var id := aid
		t.gui_input.connect(func(ev: InputEvent): _on_avatar_click(ev, id, thumbs))
		t.set_meta("aid", aid)
		grid.add_child(t)
		thumbs.append(t)
	_refresh_thumbs(thumbs)
	var ok := _menu_btn("OK")
	ok.pressed.connect(func():
		profile["name"] = edit.text
		profile["avatar"] = selected_avatar
		Profile.save_profile(str(profile["name"]), selected_avatar)
		show_multi())
	v.add_child(ok)
	v.add_child(_back_btn(func(): show_multi()))

func _on_avatar_click(ev: InputEvent, aid: String, thumbs: Array) -> void:
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT and ev.pressed:
		selected_avatar = aid
		_refresh_thumbs(thumbs)

func _refresh_thumbs(thumbs: Array) -> void:
	for t in thumbs:
		(t as TextureRect).modulate = Color(1.0, 0.85, 0.3) if str((t as TextureRect).get_meta("aid")) == selected_avatar else Color(1, 1, 1)

# --- amis : CREATE / JOIN + salon d'attente -------------------------------------

func show_friends() -> void:
	online.stop_state_poll()
	var v := _screen("res://assets/ui/backgrounds/multiplayer_bg.webp")
	v.add_child(_title_label("WITH FRIENDS (2-4)", 32))
	for n in [2, 3, 4]:
		var b := _menu_btn("CREATE %dJ" % n)
		var count := n
		b.pressed.connect(func(): _create_online(count))
		v.add_child(b)
	v.add_child(_title_label("Code ami :", 22))
	var code := LineEdit.new()
	code.placeholder_text = "ABC123"
	code.max_length = 6
	code.custom_minimum_size = Vector2(460, 56)
	code.add_theme_font_size_override("font_size", 28)
	code.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(code)
	var join := _menu_btn("JOIN")
	join.pressed.connect(func(): _join_online(code.text))
	v.add_child(join)
	var err := _title_label("", 20)
	v.add_child(err)
	_net_error_to(err)
	v.add_child(_back_btn(func(): show_menu()))

func _net_error_to(lbl: Label) -> void:
	_net_disconnect()
	net_err_lbl = lbl
	online.request_error.connect(_on_net_error)

func _net_disconnect() -> void:
	if online != null and online.request_error.is_connected(_on_net_error):
		online.request_error.disconnect(_on_net_error)
	net_err_lbl = null

func _on_net_error(msg: String) -> void:
	if is_instance_valid(net_err_lbl):
		net_err_lbl.text = "Erreur : %s" % msg

func _create_online(count: int) -> void:
	online.host = server_host
	online.player_name = str(profile.get("name", "Joueur"))
	if not await online.create_lobby(count, _active_sets()):
		return
	show_waiting()

func _join_online(code: String) -> void:
	online.host = server_host
	if not await online.join_lobby(code, str(profile.get("name", "Joueur"))):
		return
	show_waiting()

func show_waiting() -> void:
	_net_disconnect()
	var v := _screen("res://assets/ui/backgrounds/multiplayer_bg.webp")	v.add_child(_title_label("Code salon :", 24))
	var code_lbl := _title_label(online.match_id, 64)
	v.add_child(code_lbl)
	var seats_lbl := _title_label("...", 24)
	v.add_child(seats_lbl)
	v.add_child(_title_label("Donnez ce code a vos amis. 60 s par tour.", 18))
	var cancel := Button.new()
	cancel.text = "Quitter"
	cancel.pressed.connect(func(): _leave_waiting())
	v.add_child(cancel)
	if not online.lobby_changed.is_connected(_on_lobby_changed):
		online.lobby_changed.connect(_on_lobby_changed)
	if not online.request_error.is_connected(_on_waiting_error):
		online.request_error.connect(_on_waiting_error)
	online.start_lobby_poll()
	online.fetch_lobby()
	# Les callbacks retrouvent les labels via le groupe.
	seats_lbl.add_to_group("waiting_seats")

func _leave_waiting() -> void:
	online.stop_lobby_poll()
	online.stop_state_poll()
	online.leave_match()
	if online.lobby_changed.is_connected(_on_lobby_changed):
		online.lobby_changed.disconnect(_on_lobby_changed)
	if online.request_error.is_connected(_on_waiting_error):
		online.request_error.disconnect(_on_waiting_error)
	if online.state_received.is_connected(_on_first_state):
		online.state_received.disconnect(_on_first_state)
	show_friends()

func _on_waiting_error(msg: String) -> void:
	for n in get_tree().get_nodes_in_group("waiting_seats"):
		(n as Label).text = "Erreur : %s" % msg

func _on_lobby_changed(info: Dictionary) -> void:
	var names: Array = []
	for s in info.get("seats", []):
		names.append(str((s as Dictionary).get("name", "?")) if (s as Dictionary).get("name") != null else "...")
	var txt := "%d/%d : %s" % [names.filter(func(n): return n != "...").size(), info.get("numPlayers", 0), " / ".join(names)]
	for n in get_tree().get_nodes_in_group("waiting_seats"):
		(n as Label).text = txt
	if str(info.get("status", "")) == "running":
		online.stop_lobby_poll()
		if online.lobby_changed.is_connected(_on_lobby_changed):
			online.lobby_changed.disconnect(_on_lobby_changed)
		# Premier etat via le polling (reessaie tout seul si le reseau rate).
		if not online.state_received.is_connected(_on_first_state):
			online.state_received.connect(_on_first_state)
		online.start_state_poll()
		online.fetch_state()

func _on_first_state() -> void:
	if online.current_G.is_empty():
		return
	if online.state_received.is_connected(_on_first_state):
		online.state_received.disconnect(_on_first_state)
	if online.request_error.is_connected(_on_waiting_error):
		online.request_error.disconnect(_on_waiting_error)
	start_online_match()

func start_online_match() -> void:
	_clear()
	var ogm := OnlineGameManager.new()
	add_child(ogm)
	ogm.setup_online(online, online.player_id)
	online.start_state_poll()
	_open_board(ogm)

# --- options / regles ------------------------------------------------------------

func show_options() -> void:
	var v := _screen("res://assets/ui/backgrounds/menu_bg.webp")
	v.add_child(_title_label("OPTIONS", 36))
	v.add_child(_title_label("Serveur multi :", 20))
	var host := LineEdit.new()
	host.text = server_host
	host.custom_minimum_size = Vector2(460, 48)
	v.add_child(host)
	var ext := CheckBox.new()
	ext.text = "Extensions du wiki"
	ext.button_pressed = use_extensions
	ext.toggled.connect(func(on: bool):
		use_extensions = on
		Profile.save_settings(server_host, use_extensions))
	v.add_child(ext)
	var save := _menu_btn("OK")
	save.pressed.connect(func():
		server_host = host.text
		Profile.save_settings(server_host, use_extensions)
		show_menu())
	v.add_child(save)
	v.add_child(_back_btn(func(): show_menu()))

func show_rules() -> void:
	var v := _screen("res://assets/ui/backgrounds/menu_bg.webp")
	v.add_child(_title_label("RULES", 36))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(900, 600)
	v.add_child(scroll)
	var body := Label.new()
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.text = _load_rules_text()
	scroll.add_child(body)
	v.add_child(_back_btn(func(): show_menu()))

func _load_rules_text() -> String:
	var f := FileAccess.open("res://godot/data/rules.txt", FileAccess.READ)
	if f == null:
		return "Regles introuvables (godot/data/rules.txt)."
	return f.get_as_text()
