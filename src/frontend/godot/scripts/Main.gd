extends Control
## Main — menus clones de l'APK 2.2.6 (maquette 1920x1080 : coordonnees absolues relevees sur docs/reference/*.png).
## Ecran titre (TAP TO START) -> menu 2x2 -> HOW MANY PLAYERS? -> SELECT EXPANSIONS ; OPTIONS ; RULES.
## SINGLE PLAYER : 2/3/4 joueurs = vous + 1 a 3 IA.
## MULTIPLAYER : entre amis uniquement (salon prive + code), pseudo + avatar (ecrans pas encore refaits a l'APK).
## IN-APP STORE supprime -> RULES ; tout est gratuit et debloque.
## shortcut: pas de matchmaking mondial (bouton WORLDWIDE volontairement absent).

## Extensions du wiki hors APK (bascule « Options »).
const EXT_PACKS := ["next-level", "minibosses", "crash-landing"]
## Paquets de l'APK (ExpansionScene) : le jeu de base est toujours present, les autres se combinent librement.
## Boutique supprimee : tout est debloque (ToolsHeroKind, « COMING SOON » dans l'APK, est jouable ici : Match gere deja les Items).
const APK_DECKS := [
	{"id": "tools", "name": "TOOLS OF HERO KIND", "info": "20 item cards", "playable": true, "art": "tools_of_hero_front", "desc": "Adds 20 Item cards. One Item is revealed each turn: Heroes carry Power-Ups, and killing them earns the Reward."},
	{"id": "players-choice", "name": "THE PLAYER'S CHOICE", "info": "7 bosses, 3 epic heroes, 1 spell", "playable": true, "art": "the_players_choice_front", "desc": "Cards chosen by the community: 7 new Bosses, 3 Epic Heroes and 1 Spell."},
	{"id": "hidden-heroes", "name": "HIDDEN HEROES", "info": "+41 new heroes", "playable": true, "art": "hidden_heroes_front", "desc": "An alternate set of 41 Heroes, hidden in the shadows of Arcadia's dungeons, that replace their base set counterparts."},
	# Extension du wiki hors APK (livret docs/rules « The Next Level » + FAQ) : paquets de heros TNL (noirs, hybrides), defausse amorcee, main de depart de 7.
	{"id": "next-level", "name": "THE NEXT LEVEL", "info": "13 bosses, 43 rooms, 17 spells, 42 heroes - wiki", "playable": true},
	# Extension du wiki hors APK, selectionnable seule (en plus de la bascule « Extensions du wiki » qui active tous les paquets wiki).
	{"id": "crash-landing", "name": "CRASH LANDING", "info": "3 bosses, 13 rooms, 5 spells, 12 heroes - wiki", "playable": true},
	# Extension du wiki hors APK (livret « Rise of the Minibosses » + guide officieux) : minibosses (niveaux 1-3), Coins, paquet de heros RMB, 3 Coins au depart.
	{"id": "minibosses", "name": "MINIBOSSES", "info": "12 bosses, 42 rooms, 15 spells, 42 heroes, 10 minibosses - wiki", "playable": true},
]

const GameManager = preload("res://godot/scripts/GameManager.gd")
const OnlineClient = preload("res://godot/scripts/OnlineClient.gd")
const OnlineGameManager = preload("res://godot/scripts/OnlineGameManager.gd")
const Profile = preload("res://godot/scripts/Profile.gd")
const UiKit = preload("res://godot/scripts/UiKit.gd")
const CardGallery = preload("res://godot/scripts/CardGallery.gd")

const UI := "res://assets/ui/"
const FONT_A := "res://assets/fonts/arcadepix.fnt"   # texte plein (bandeaux, ON/OFF)
const FONT_B := "res://assets/fonts/arcadepix2.fnt"  # texte strie (boutons, libelles)
const GOLD := Color("cdb15f")
## Carrousel « HOW MANY PLAYERS? » : carte du dessus (ou "" = dos) de chaque eventail.
const FANS := {2: ["BMA006", "BMA002", ""], 3: ["BMA005", "", ""], 4: ["BMA001", "", ""]}

var game_manager: GameManager
var online: OnlineClient
var board: Control
var net_err_lbl: Label = null
var use_extensions := false
var apk_decks: Array = [] # ids des paquets APK coches (voir APK_DECKS)
var server_host := "http://127.0.0.1:8000"
var players := 2 # choix courant de « HOW MANY PLAYERS? »
var dyn_root: Control # contenu redessine a chaque clic (eventails, tuiles)
var _gray: ShaderMaterial
var profile := {"name": "Player", "avatar": "avatar_draculord"}
var selected_avatar := "avatar_draculord"

func _ready() -> void:
	game_manager = GameManager.new()
	add_child(game_manager)
	online = OnlineClient.new()
	add_child(online)
	if OS.has_feature("web"):
		var origin = JavaScriptBridge.eval("window.location.origin")
		if origin != null and str(origin) != "" and str(origin) != "null":
			server_host = str(origin)
	var settings := Profile.load_settings()
	if settings.has("host") and str(settings["host"]) != "":
		server_host = str(settings["host"])
	use_extensions = bool(settings.get("extensions", false))
	apk_decks = (settings.get("decks", []) as Array).filter(func(d): return _deck_playable(str(d)))
	profile = Profile.load_profile()
	selected_avatar = str(profile.get("avatar", selected_avatar))
	show_title()

func _clear() -> void:
	for c in get_children():
		if c != game_manager and c != online:
			c.queue_free()
	board = null

func _deck_playable(id: String) -> bool:
	for d in APK_DECKS:
		if str((d as Dictionary)["id"]) == id:
			return bool((d as Dictionary)["playable"])
	return false

func _active_sets() -> Array:
	# Les paquets du wiki ne comptent que si l'option « Extensions du wiki » est cochee.
	return apk_decks.filter(func(d): return use_extensions or not EXT_PACKS.has(d))

## Cases a cocher « select expansions » (ExpansionScene) : un paquet non jouable est affiche grise.
func _add_deck_checks(v: Control) -> void:
	for d in APK_DECKS:
		var dd: Dictionary = d
		if EXT_PACKS.has(dd["id"]) and not use_extensions:
			continue
		var cb := CheckBox.new()
		cb.text = "%s  (%s)" % [str(dd["name"]), str(dd["info"])]
		cb.disabled = not bool(dd["playable"])
		cb.button_pressed = apk_decks.has(str(dd["id"]))
		var did := str(dd["id"])
		cb.toggled.connect(func(on: bool):
			if on and not apk_decks.has(did):
				apk_decks.append(did)
			elif not on:
				apk_decks.erase(did)
			Profile.save_settings(server_host, use_extensions, apk_decks))
		v.add_child(cb)

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
	b.add_theme_font_override("font", _font(FONT_B))
	b.add_theme_font_size_override("font_size", 28)
	if icon_path != "" and ResourceLoader.exists(icon_path):
		b.icon = load(icon_path)
		b.expand_icon = true
	b.pressed.connect(func(): AudioManager.play_sfx("ui_button_select"))
	return b

func _title_label(text: String, size: int = 40) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", _font(FONT_B))
	l.add_theme_font_size_override("font_size", size)
	return l

func _back_btn(where: Callable) -> Button:
	var b := Button.new()
	b.text = "BACK"
	b.add_theme_font_override("font", _font(FONT_B))
	b.pressed.connect(func(): AudioManager.play_sfx("ui_button_goback"))
	b.pressed.connect(where)
	return b

# --- widgets APK (positions absolues en 1920x1080) -------------------------------

func _font(path: String) -> Font:
	return load(path) as Font

func _tex(path: String, pos: Vector2, sz: Vector2 = Vector2.ZERO) -> TextureRect:
	var t := TextureRect.new()
	t.texture = load(UI + path)
	if sz != Vector2.ZERO:
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_SCALE
		t.size = sz
	t.position = pos
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t

## Texte centre dans le rectangle (pos, sz).
func _lbl(text: String, size: int, color: Color, pos: Vector2, sz: Vector2, font: String = FONT_B, align: int = HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", _font(font))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.position = pos
	l.size = sz
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

## Zone cliquable invisible.
func _hit(pos: Vector2, sz: Vector2, cb: Callable, sfx: String = "ui_button_select") -> Button:
	var b := Button.new()
	for n in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
		b.add_theme_stylebox_override(n, StyleBoxEmpty.new())
	b.focus_mode = Control.FOCUS_NONE
	b.position = pos
	b.size = sz
	b.pressed.connect(func(): AudioManager.play_sfx(sfx))
	b.pressed.connect(cb)
	return b

func _img_btn(normal: String, pressed: String, pos: Vector2, cb: Callable, sz: Vector2 = Vector2.ZERO, sfx: String = "ui_button_select") -> TextureButton:
	var b := TextureButton.new()
	b.texture_normal = load(UI + normal)
	b.texture_pressed = load(UI + pressed)
	if sz != Vector2.ZERO:
		b.ignore_texture_size = true
		b.stretch_mode = TextureButton.STRETCH_SCALE
		b.size = sz
	b.position = pos
	b.pressed.connect(func(): AudioManager.play_sfx(sfx))
	b.pressed.connect(cb)
	return b

func _flicker(n: Node) -> void:
	var tw := n.create_tween().set_loops()
	tw.tween_property(n, "modulate:a", 0.78, 0.35).set_trans(Tween.TRANS_SINE)
	tw.tween_property(n, "modulate:a", 1.0, 0.25).set_trans(Tween.TRANS_SINE)

## Decor commun (menu_bg + torches + logo) ; back = fleche verte en haut a gauche (Callable invalide = pas de fleche).
func _apk_screen(back: Callable) -> void:
	_clear()
	add_child(_bg(UI + "backgrounds/menu_bg.webp"))
	for x in [713, 992]: # torch.webp : socle a (820|1100, 900) dans la maquette
		var t := _tex("gradients/torch.webp", Vector2(x, 690))
		add_child(t)
		_flicker(t)
	add_child(_tex("navigation/bm_logo.webp", Vector2(705, 42), Vector2(540, 218)))
	if back.is_valid():
		add_child(_img_btn("buttons/back_bt.webp", "buttons/back_bt_pressed.webp", Vector2(20, 22), back, Vector2.ZERO, "ui_button_goback"))

func _band(text: String) -> void:
	add_child(_tex("gradients/bg_txt.webp", Vector2(394, 298)))
	add_child(_lbl(text, 21, GOLD, Vector2(394, 298), Vector2(1132, 64), FONT_A))

func _ok_btn(cb: Callable) -> void:
	add_child(_img_btn("buttons/ok_bt.webp", "buttons/ok_bt_pressed.webp", Vector2(1697, 960), cb))

# --- ecran titre -------------------------------------------------------------------

func show_title() -> void:
	_clear()
	AudioManager.play_music("music_main")  # APK IntroScene
	add_child(_bg(UI + "backgrounds/intro_bg.webp"))
	for x in [424, 1094]:
		var c := _tex("gradients/candle.webp", Vector2(x, 484))
		add_child(c)
		_flicker(c)
	var eyes := _tex("gradients/monster_eyes.webp", Vector2(905, 733))
	add_child(eyes)
	var blink := eyes.create_tween().set_loops()
	blink.tween_interval(2.5)
	blink.tween_property(eyes, "modulate:a", 0.0, 0.1)
	blink.tween_interval(0.25)
	blink.tween_property(eyes, "modulate:a", 1.0, 0.1)
	add_child(_tex("navigation/bm_logo.webp", Vector2(537, 78), Vector2(850, 343)))
	var tap := _lbl("TAP TO START", 50, Color(0.82, 0.7, 0.36), Vector2(560, 600), Vector2(800, 86))
	add_child(tap)
	_flicker(tap)
	add_child(_hit(Vector2.ZERO, Vector2(1920, 1080), func(): show_menu()))

# --- menu principal ----------------------------------------------------------

## Bouton pierre noire (button.webp) : icone a ipos, texte centre en x = tcx (releve sur 11_menu.png).
func _stone_btn(text: String, icon: String, ipos: Vector2, tcx: float, pos: Vector2, cb: Callable) -> void:
	var b := _img_btn("buttons/button.webp", "buttons/button_pressed.webp", pos, cb, Vector2(500, 180))
	b.add_child(_tex("navigation/" + icon, ipos))
	b.add_child(_lbl(text, 39, Color.WHITE, Vector2(tcx - 250, 10), Vector2(500, 180)))
	add_child(b)

func show_menu() -> void:
	online.stop_lobby_poll()
	online.stop_state_poll()
	_net_disconnect()
	AudioManager.play_music("music_main")  # APK IntroScene
	_apk_screen(func(): show_title())
	_stone_btn("SINGLE PLAYER", "boss_icon.webp", Vector2(30, 49), 292, Vector2(460, 317), func(): show_solo_count())
	_stone_btn("MULTIPLAYER", "boss_multi_icon.webp", Vector2(25, 57), 327, Vector2(990, 317), func(): show_multi())
	_stone_btn("OPTIONS", "options_icon.webp", Vector2(27, 51), 267, Vector2(460, 527), func(): show_options())
	_stone_btn("RULES", "rules_icon.webp", Vector2(40, 58), 306, Vector2(990, 527), func(): show_rules())

# --- solo : HOW MANY PLAYERS? -------------------------------------------------

func show_solo_count() -> void:
	_apk_screen(func(): show_menu())
	_band("HOW MANY PLAYERS?")
	dyn_root = Control.new()
	add_child(dyn_root)
	_draw_fans()
	_ok_btn(func(): show_setup(players, 1))

## Carrousel 4 | 2 | 3 : l'eventail du centre est le choix courant (colore), les autres sont ternes.
func _draw_fans() -> void:
	for c in dyn_root.get_children():
		dyn_root.remove_child(c)
		c.queue_free()
	var ring := [2, 3, 4]
	var i := ring.find(players)
	for slot in [[ring[(i + 2) % 3], 577.0, 200.0], [players, 958.0, 310.0], [ring[(i + 1) % 3], 1335.0, 200.0]]:
		var n: int = slot[0]
		var cx: float = slot[1]
		var sel: bool = n == players
		dyn_root.add_child(_fan(Vector2(cx, 625 if sel else 600), slot[2], FANS[n], sel))
		if sel:
			dyn_root.add_child(_tex("navigation/bg_number.webp", Vector2(922, 371)))
			dyn_root.add_child(_lbl(str(n), 56, GOLD, Vector2(922, 371), Vector2(77, 77)))
		else:
			dyn_root.add_child(_lbl(str(n), 36, Color(0.95, 0.95, 1.0), Vector2(cx - 32, 415), Vector2(80, 44)))
			dyn_root.add_child(_hit(Vector2(cx - 110, 480), Vector2(220, 240), func():
				players = n
				_draw_fans()))

func _fan(c: Vector2, h: float, all_ids: Array, sel: bool) -> Control:
	var ids := all_ids.slice(0, 2) if sel else all_ids
	var root := Control.new()
	root.position = c
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rots := [-6.0, 9.0] if sel else [-10.0, 3.0, 8.0]
	for k in range(ids.size() - 1, -1, -1): # le fond d'abord, la carte du dessus en dernier
		var path: String = CardDB.card_image(str(ids[k]), "boss" if ids[k] != "" else "back-boss")
		var t := TextureRect.new()
		t.texture = load(path)
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_SCALE
		t.size = Vector2(h * 0.717, h)
		t.pivot_offset = t.size / 2
		t.position = -t.size / 2 + Vector2(k * (42 if sel else 10), -k * (12 if sel else 2))
		t.rotation_degrees = rots[k]
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if not sel:
			t.material = _gray_mat()
		root.add_child(t)
	return root

func _gray_mat() -> ShaderMaterial:
	if _gray == null:
		var sh := Shader.new()
		sh.code = "shader_type canvas_item;\nvoid fragment() { vec4 c = texture(TEXTURE, UV); float g = dot(c.rgb, vec3(0.3, 0.59, 0.11)) * 0.65; COLOR = vec4(vec3(g), c.a); }"
		_gray = ShaderMaterial.new()
		_gray.shader = sh
	return _gray

# --- SELECT EXPANSIONS ------------------------------------------------------------

func _is_wiki(d: Dictionary) -> bool:
	return EXT_PACKS.has(d["id"])

func show_setup(num_players: int, human_count: int) -> void:
	_apk_screen(func(): show_solo_count())
	_band("SELECT EXPANSIONS")
	dyn_root = Control.new()
	add_child(dyn_root)
	_draw_tiles()
	_ok_btn(func(): start_match(num_players, human_count))

func _draw_tiles() -> void:
	for c in dyn_root.get_children():
		dyn_root.remove_child(c)
		c.queue_free()
	# Jeu de base d'abord (toujours present), puis les paquets APK ; les paquets du wiki seulement avec l'option.
	var tiles: Array = [{"id": "base", "name": "BOSS MONSTER", "info": "", "art": "full_game_front"}]
	tiles.append_array(APK_DECKS.filter(func(d): return use_extensions or not _is_wiki(d)))
	var s := 1.0 if tiles.size() <= 4 else 0.72
	var pitch := 330.7 * s
	var x0 := (1920.0 - ((tiles.size() - 1) * pitch + 285.0 * s)) / 2.0
	for i in tiles.size():
		_draw_tile(tiles[i], Vector2(x0 + i * pitch, 405.0 if s == 1.0 else 430.0), s)

func _draw_tile(d: Dictionary, pos: Vector2, s: float) -> void:
	var id := str(d["id"])
	var on := id == "base" or apk_decks.has(id)
	var w := 285.0 * s
	var h := 453.0 * s
	dyn_root.add_child(_tex("expansions/bg_expansion_selected.webp" if on else "expansions/bg_expansion.webp", pos, Vector2(w, h)))
	if d.has("art"):
		dyn_root.add_child(_tex("expansions/%s.webp" % d["art"], pos + Vector2(15, 13) * s, Vector2(249, 304) * s))
	else: # extension du wiki : pas d'illustration, le nom tient lieu de couverture
		dyn_root.add_child(_lbl(str(d["name"]), int(26 * s), GOLD, pos + Vector2(14, 20) * s, Vector2(257, 280) * s, FONT_A))
	if id == "base":
		return
	if not _is_wiki(d): # les infos des paquets du wiki sont trop longues : elles sont dans la fenetre « ? »
		dyn_root.add_child(_lbl(str(d.get("info", "")).to_upper(), int(17 * s), Color.WHITE, pos + Vector2(14, 322) * s, Vector2(257, 62) * s, FONT_A))
	dyn_root.add_child(_hit(pos, Vector2(w, h - 70 * s), func():
		if apk_decks.has(id):
			apk_decks.erase(id)
		else:
			apk_decks.append(id)
		Profile.save_settings(server_host, use_extensions, apk_decks)
		_draw_tiles()))
	dyn_root.add_child(_lbl("?", int(40 * s), GOLD, pos + Vector2(w / 2 - 25, h - 70 * s), Vector2(50, 60) * s))
	dyn_root.add_child(_hit(pos + Vector2(w / 2 - 35, h - 75 * s), Vector2(70, 70) * s, func(): _deck_popup(d)))

func _deck_popup(d: Dictionary) -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.size = Vector2(1920, 1080)
	add_child(dim)
	var close := func(): dim.queue_free()
	dim.add_child(_hit(Vector2.ZERO, Vector2(1920, 1080), close))
	var p := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.04, 0.06, 0.97)
	sb.border_color = GOLD
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(22)
	p.add_theme_stylebox_override("panel", sb)
	p.position = Vector2(397, 205)
	p.size = Vector2(1126, 657)
	dim.add_child(p)
	if d.has("art"):
		dim.add_child(_tex("expansions/%s.webp" % d["art"], Vector2(440, 240), Vector2(310, 378)))
	dim.add_child(_lbl(str(d["name"]), 36, GOLD, Vector2(790, 235), Vector2(620, 60), FONT_A, HORIZONTAL_ALIGNMENT_LEFT))
	var desc := _lbl(str(d.get("desc", d.get("info", ""))).to_upper(), 24, Color.WHITE, Vector2(790, 310), Vector2(660, 400), FONT_A, HORIZONTAL_ALIGNMENT_LEFT)
	desc.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	dim.add_child(desc)
	dim.add_child(_img_btn("expansions/close_panel.webp", "expansions/close_panel_pressed.webp", Vector2(1418, 220), close))

func start_match(num_players: int, human_count: int) -> void:
	_clear()
	game_manager.start_new_game(num_players, human_count, _active_sets())
	_open_board(game_manager)

func _open_board(gm: GameManager) -> void:
	var board_scene = load("res://godot/scenes/Board.tscn")
	board = board_scene.instantiate()
	board.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(board)
	board.setup(gm, func(): show_title()) # APK LeaveGameplayScene : retour a l'ecran titre (fin de partie : OK ; menu : QUIT GAME)

# --- multi : WITH FRIENDS / CHANGE USER/AVATAR ---------------------------------

func show_multi() -> void:
	var v := _screen("res://assets/ui/backgrounds/multiplayer_bg.webp")
	v.add_child(_title_label("%s" % profile.get("name", "Player"), 28))
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
	edit.text = str(profile.get("name", "Player"))
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
		var id: String = aid
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
	_add_deck_checks(v)
	for n in [2, 3, 4]:
		var b := _menu_btn("CREATE %dJ" % n)
		var count: int = n
		b.pressed.connect(func(): _create_online(count))
		v.add_child(b)
	v.add_child(_title_label("Friend code:", 22))
	var code := LineEdit.new()
	code.placeholder_text = "ABC123"
	code.max_length = 6
	code.custom_minimum_size = Vector2(460, 56)
	code.add_theme_font_size_override("font_size", 28)
	code.alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(code)
	var join := _menu_btn("JOIN")
	join.pressed.connect(func(): _join_online(code.text))
	v.add_child(join)
	var err := _title_label("", 20)
	if online.has_saved_session():
		var resume := _menu_btn("RESUME")
		resume.pressed.connect(func():
			online.host = server_host
			if await online.try_resume():
				show_waiting()
			elif is_instance_valid(err) and err.text == "":
				err.text = "Error: unable to resume the game")
		v.add_child(resume)
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
		net_err_lbl.text = "Error: %s" % msg

func _create_online(count: int) -> void:
	online.host = server_host
	online.player_name = str(profile.get("name", "Player"))
	if not await online.create_lobby(count, _active_sets()):
		return
	show_waiting()

func _join_online(code: String) -> void:
	online.host = server_host
	if not await online.join_lobby(code, str(profile.get("name", "Player"))):
		return
	show_waiting()

func show_waiting() -> void:
	_net_disconnect()
	var v := _screen("res://assets/ui/backgrounds/multiplayer_bg.webp")
	v.add_child(_title_label("Lobby code:", 24))
	var code_lbl := _title_label(online.match_id, 64)
	v.add_child(code_lbl)
	var seats_lbl := _title_label("...", 24)
	v.add_child(seats_lbl)
	v.add_child(_title_label("Give this code to your friends. 60 s per turn.", 18))
	var bots := _menu_btn("START WITH BOTS")
	bots.visible = online.is_host and online.current_status != "running"
	bots.add_to_group("waiting_start")
	bots.pressed.connect(func(): online.start_match())
	v.add_child(bots)
	var cancel := Button.new()
	cancel.text = "LEAVE"
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
		(n as Label).text = "Error: %s" % msg

func _on_lobby_changed(info: Dictionary) -> void:
	var names: Array = []
	for s in info.get("seats", []):
		names.append(str((s as Dictionary).get("name", "?")) if (s as Dictionary).get("name") != null else "...")
	var txt := "%d/%d : %s" % [names.filter(func(n): return n != "...").size(), info.get("numPlayers", 0), " / ".join(names)]
	for n in get_tree().get_nodes_in_group("waiting_seats"):
		(n as Label).text = txt
	for b in get_tree().get_nodes_in_group("waiting_start"):
		(b as Button).visible = online.is_host and str(info.get("status", "")) != "running"
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
	var host := LineEdit.new()
	host.text = server_host
	var leave := func():
		server_host = host.text
		Profile.save_settings(server_host, use_extensions, apk_decks)
		show_menu()
	_apk_screen(leave)
	_toggle_row(360, "MUSIC", ["ON", "OFF"], 0 if AudioManager.music_on else 1, func(i: int): AudioManager.set_music_on(i == 0))
	_toggle_row(480, "SOUND", ["ON", "OFF"], 0 if AudioManager.sfx_on else 1, func(i: int): AudioManager.set_sfx_on(i == 0))
	_toggle_row(600, "GAME SPEED", ["SLOW", "NORMAL", "FAST"], Profile.load_speed(), func(i: int): Profile.save_speed(i))
	# CARD GALLERY : l'OPTIONS de l'APK l'ouvre aussi (OptionsScene), comme le menu en jeu.
	var gal := UiKit.stone_button(self, "CARD GALLERY", Vector2(687, 730))
	gal.name = "CardGallery"
	gal.pressed.connect(func():
		AudioManager.play_sfx("ui_button_select")
		add_child(CardGallery.new()))
	# Controles secondaires discrets (multijoueur / extensions du wiki : hors APK).
	var ext := CheckBox.new()
	ext.text = "Wiki expansions (not in the APK)"
	ext.button_pressed = use_extensions
	ext.add_theme_font_size_override("font_size", 16)
	ext.position = Vector2(30, 1030)
	ext.toggled.connect(func(on: bool):
		use_extensions = on
		Profile.save_settings(server_host, use_extensions, apk_decks))
	add_child(ext)
	host.add_theme_font_size_override("font_size", 16)
	host.position = Vector2(1440, 1034)
	host.size = Vector2(440, 36)
	host.tooltip_text = "Multiplayer server"
	add_child(host)

## Rangee de segments facon APK : le segment choisi est une pierre verte (settings_bt) dorée, les autres sur une barre mauve.
func _toggle_row(y: int, text: String, opts: Array, sel: int, cb: Callable) -> void:
	add_child(_lbl(text, 36, Color.WHITE, Vector2(260, y - 50), Vector2(450, 100), FONT_B, HORIZONTAL_ALIGNMENT_RIGHT))
	var row := Control.new()
	add_child(row)
	_draw_toggle(row, y, opts, sel, cb)

func _draw_toggle(row: Control, y: int, opts: Array, sel: int, cb: Callable) -> void:
	for c in row.get_children():
		row.remove_child(c)
		c.queue_free()
	var bar := ColorRect.new()
	bar.color = Color(109 / 255.0, 99 / 255.0, 131 / 255.0)
	bar.position = Vector2(760, y - 48)
	bar.size = Vector2(202 * opts.size(), 96)
	row.add_child(bar)
	for i in opts.size():
		var x := 760 + 202 * i
		if i == sel:
			row.add_child(_tex("buttons/settings_bt.webp", Vector2(x, y - 58), Vector2(202, 106)))
		row.add_child(_lbl(str(opts[i]), 34, GOLD if i == sel else Color(0.9, 0.88, 0.96), Vector2(x, y - 48), Vector2(202, 96), FONT_A))
		var idx := i
		row.add_child(_hit(Vector2(x, y - 48), Vector2(202, 96), func():
			cb.call(idx)
			_draw_toggle(row, y, opts, idx, cb)))

## Visionneuse des regles : voir RulesViewer.gd (partagee avec le plateau).
func show_rules(tab: int = 0) -> void:
	_clear()
	var v := RulesViewer.new()
	v.tab = tab
	v.closed.connect(func(): show_menu())
	add_child(v)
