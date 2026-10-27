extends RefCounted
## Ecrans multijoueur de l'APK 2.2.6 (maquette 1920x1080, coordonnees de decompiled/DBMGame/) :
##   MultiplayerScene (PLAY ONLINE / PLAY WITH FRIENDS) -> MenuOnlineScene (WORLDWIDE / WITH FRIENDS / CHANGE USER/AVATAR)
##   -> WORLDWIDE : liste des salons publics (hors APK, voir show_public) ; CREATE PUBLIC GAME reprend NEW GAME avec `public`
##   -> WithFriendsOnlineScene (NEW GAME / ROOM CODE) -> WaitingPrivateRoomScene ; ChangeNameAvatarScene ; MessageBoxScene.
## Repere : l'APK dessine dans 1440x1080 (Game.VIEWPORT_WIDTH) et un ecran 16:9 montre 240 px de plus de chaque cote : x ecran = x APK + 240 pour les
## constantes en dur (ex. champ de saisie (210,375) -> 450 ; les positions « VirtualWidth * 0.5 » = 720 donnent 960). Toutes les coordonnees ci-dessous sont en px ecran.
## `m` = Main (decor, widgets absolus, navigation) ; l'API d'OnlineClient (create_lobby / join_lobby / start_match / leave_match / try_resume) est inchangee.
## Hors APK : WORLDWIDE (l'APK sans paquets ouvrait « NETWORK ERROR / Unable to join public rooms ») liste les salons publics du serveur (listRooms / rooms, sans comptes).
## Fondus : Main.go (ColorFade 1,0 s) entre les ecrans en ligne, UiKit.cross_fade_in (0,2 s) pour les modales ; la fleche de retour coupe net (comme l'APK).

const UiKit = preload("res://godot/scripts/UiKit.gd")
const Profile = preload("res://godot/scripts/Profile.gd")

const UI := "res://assets/ui/"
const A := "res://assets/fonts/arcadepix.fnt"            # 21 px a l'echelle 1 (CreateArcadepixTB : le facteur d'echelle multiplie la taille)
const BOOKMAN := "res://assets/fonts/bookman_old_style.fnt" # 24 px a l'echelle 1
const GOLD := Color("cdb15f")
const AV_STEP := 240.0
const AV_ORIGIN_X := 400.0 # AvatarScrollComponent a (160, 620) APK
const ROW_Y := [394.0, 525.0, 652.0, 779.0]            # OnlinePanelEntity : 300 + 94 + i * 127 (+ 4 pour i > 0)
const ROW_STEP_BIG := 83.0 # 6 lignes (5-6 joueurs) dans le cadre 300-904 : pas de 83 px, avatar a 0,29
const CODE_LEN := 4
const WAIT_LINK_GRACE_S := 10.0     # salle d'attente : liaison coupee depuis ce delai = « NETWORK ERROR » et retour (WaitingRoomBaseScene.OnDisconnect) ; une coupure breve est toleree
const PUBLIC_REFRESH_S := 5.0       # liste publique : le serveur pousse chaque changement, on redemande quand meme toutes les 5 s
const PUBLIC_UNREACHABLE_S := 3.0   # liaison absente depuis ce delai : « UNABLE TO REACH THE SERVER »
const PACK_ABBR := {"tools": "THK", "players-choice": "PC", "hidden-heroes": "HH", "next-level": "TNL", "crash-landing": "CRL", "minibosses": "RMB", "iod": "IOD"}
const BIG_GAME_MSG := "5 or 6 players need Crash Landing, with the base game, Hidden Heroes and Tools only" # (police arcadepix : pas d'accents, d'ou pas le texte de Match.setup_error)

var m # Main (type volontairement libre : on appelle ses utilitaires _tex / _hit / _img_btn / _clear ...)
var _busy := false
var _rows: Array = []     # salle d'attente : {avatar, name, wins, defeats}
var _wait_ok: TextureButton = null
var _wait_bots: TextureButton = null
var _wait_err_shown := false
var _wait_title: Control = null # salon public : titre de la salle (champ modifiable pour l'hote, simple texte pour les autres)
var _bgn: Control = null  # fond de l'ecran courant (un clic dessus deselectionne le champ de saisie)
var _pub_filter := ""      # texte du filtre de la liste publique
var _pub: Dictionary = {} # liste publique : {scroll, box, status, thumb, sig, loaded, down, since}

func _init(main) -> void:
	m = main

# --- briques --------------------------------------------------------------------

## Texte arcadepix a l'echelle `scale` (taille = 21 x echelle), coin haut-gauche en `pos`, largeur `w` (0 = au plus juste).
func _t(text: String, scale: float, color: Color, pos: Vector2, w: float = 0.0, align: int = HORIZONTAL_ALIGNMENT_LEFT, font: String = A) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", UiKit.font(font))
	l.add_theme_font_size_override("font_size", roundi((24.0 if font == BOOKMAN else 21.0) * scale))
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = align as HorizontalAlignment
	l.position = pos
	if w > 0.0:
		l.size.x = w
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

## Decor des scenes en ligne : multiplayer_bg, petit logo (CreateLogo(false) : haut-centre a y = 10), fleche de retour (80,70).
func _screen(back: Callable) -> void:
	m._clear()
	_bgn = m._bg(UI + "backgrounds/multiplayer_bg.webp")
	m.add_child(_bgn)
	m.add_child(m._tex("gradients/logo_small.webp", Vector2(960.0 - 344.0, 10.0)))
	if back.is_valid():
		var bk: TextureButton = m._img_btn("buttons/back_bt.webp", "buttons/back_bt_pressed.webp", Vector2(20, 22), back, Vector2.ZERO, "ui_button_goback")
		bk.name = "Back"
		m.add_child(bk)

## ButtonWithLabelEntity : bg_bt_multi (619x177, taille native) centre en (cx, cy), libelle arcadepix x 1.3 centre ; `pressed_color` = couleur pendant l'appui.
func _label_btn(text: String, cx: float, cy: float, cb: Callable, pressed_color: Color = Color.WHITE, s: float = 1.0, text_scale: float = 1.3, parent: Node = null) -> TextureButton:
	var b := TextureButton.new()
	b.texture_normal = load(UI + "navigation/bg_bt_multi.webp")
	b.texture_pressed = load(UI + "navigation/bg_bt_multi_pressed.webp")
	b.position = Vector2(cx - 309.5 * s, cy - 88.5 * s)
	b.scale = Vector2(s, s)
	b.focus_mode = Control.FOCUS_NONE
	var l := _t(text, text_scale, Color.WHITE, Vector2.ZERO, 619.0, HORIZONTAL_ALIGNMENT_CENTER)
	l.size.y = 177.0
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.name = "Label"
	b.add_child(l)
	b.button_down.connect(func(): l.add_theme_color_override("font_color", pressed_color))
	b.button_up.connect(func(): l.add_theme_color_override("font_color", Color.WHITE))
	b.button_down.connect(func(): AudioManager.play_sfx("ui_button_select")) # a l'appui (ButtonBaseEntity.cs:185)
	b.pressed.connect(cb)
	(parent if parent != null else m).add_child(b)
	return b

## Boite modale de l'APK (MessageBoxScene) : voile noir 0,7, bande winner_bg etiree x 1,82, titre dore sur bg_txt (y 7 %), message x 1,5, bouton OK.
func msg_box(title: String, text: String, ok: Callable = Callable()) -> Control:
	var dim := ColorRect.new()
	dim.name = "MessageBox"
	dim.color = Color(0, 0, 0, 0.7)
	dim.size = Vector2(1920, 1080)
	m.add_child(dim)
	UiKit.cross_fade_in(dim) # DBMBaseScene.cs:55-67 : Push(modale, CrossFade 0,2 s)
	dim.add_child(m._tex("gradients/winner_bg.webp", Vector2(960.0 - 956.5, 486.0 - 94.0), Vector2(1913.0, 188.0)))
	if title != "":
		dim.add_child(m._tex("gradients/bg_txt.webp", Vector2(394, 75.6 - 32.0)))
		var tl := _t(title.to_upper(), 2.0, GOLD, Vector2(394, 75.6 - 32.0), 1132.0, HORIZONTAL_ALIGNMENT_CENTER)
		tl.size.y = 64.0
		tl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		dim.add_child(tl)
	var ml := _t(text, 1.5, Color.WHITE, Vector2(160, 480.6 - 40.0), 1600.0, HORIZONTAL_ALIGNMENT_CENTER)
	ml.size.y = 80.0
	ml.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ml.name = "Message"
	dim.add_child(ml)
	var close := func():
		dim.queue_free()
		if ok.is_valid():
			ok.call()
	var b := TextureButton.new()
	b.texture_normal = load(UI + "ingame/bt_apply_effects.webp")
	b.texture_pressed = load(UI + "ingame/bt_apply_effects_pressed.webp")
	b.position = Vector2(960.0 - 200.0, 604.8 - 51.5)
	b.focus_mode = Control.FOCUS_NONE
	b.name = "Ok"
	var ol := _t("OK", 1.5, Color.WHITE, Vector2.ZERO, 400.0, HORIZONTAL_ALIGNMENT_CENTER)
	ol.size.y = 103.0
	ol.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	b.add_child(ol)
	b.button_down.connect(func():
		AudioManager.play_sfx("ui_button_select")
		ol.position.y += 3.0) # shiftTextWhenPressed (MessageBoxScene.cs:88)
	b.button_up.connect(func(): ol.position.y -= 3.0)
	b.pressed.connect(close)
	dim.add_child(b)
	return dim

## Champ de saisie (TextEntryEntity) : ninepatch code_area_inact 994x113 (code_area_act au focus), texte arcadepix x 1,3 a (54, 44).
func _entry(pos: Vector2, text: String, color: Color, placeholder: String = "") -> LineEdit:
	var box := UiKit.ninepatch(m, "ninepatch/code_area_inact.webp", pos, Vector2(994, 113), Vector4(10, 10, 10, 10))
	var le := LineEdit.new()
	le.name = "Entry"
	le.text = text
	le.placeholder_text = placeholder
	le.position = pos + Vector2(54, 40)
	le.size = Vector2(884, 34)
	le.max_length = Profile.NAME_MAX
	le.context_menu_enabled = false
	for n in ["normal", "focus", "read_only"]:
		le.add_theme_stylebox_override(n, StyleBoxEmpty.new())
	le.add_theme_font_override("font", UiKit.font(A))
	le.add_theme_font_size_override("font_size", 27)
	for c in ["font_color", "font_uneditable_color", "caret_color"]:
		le.add_theme_color_override(c, color)
	le.add_theme_color_override("font_placeholder_color", color)
	le.add_theme_color_override("font_selected_color", Color.BLACK)
	le.add_theme_color_override("selection_color", color)
	le.add_theme_constant_override("caret_width", 3)
	var wbox: WeakRef = weakref(box) # le champ perd le focus en etant libere : le cadre a pu l'etre avant
	le.focus_entered.connect(func(): if wbox.get_ref() != null: (wbox.get_ref() as NinePatchRect).texture = UiKit.np_tex("ninepatch/code_area_act.webp"))
	le.focus_exited.connect(func(): if wbox.get_ref() != null: (wbox.get_ref() as NinePatchRect).texture = UiKit.np_tex("ninepatch/code_area_inact.webp"))
	le.text_submitted.connect(func(_s): le.release_focus())
	le.set_meta("box", box)
	m.add_child(le)
	return le

## Un clic hors du champ le deselectionne (APK : TouchPressed sur le fond -> IsFocus = false).
func _blur_on_background(le: LineEdit) -> void:
	_bgn.mouse_filter = Control.MOUSE_FILTER_STOP
	_bgn.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and is_instance_valid(le):
			le.release_focus())

# --- MultiplayerScene : PLAY ONLINE / PLAY WITH FRIENDS ------------------------------

const DECKS := {
	2: {"ids": ["BMA006", "BMA002"], "close": [Vector2(0, 0), Vector2(50.0 / 3.0, 0)], "open": [Vector2(0, 0), Vector2(50, 0)],
		"crot": [-0.1, 0.05], "orot": [-0.15, 0.2], "order": [1, 0]},
	4: {"ids": ["BMA007", "BMA002", "BMA001", "BMA006"], "close": [Vector2(0, 0), Vector2(50.0 / 3.0, 0), Vector2(-50.0 / 3.0, 12.5), Vector2(50.0 / 3.0, 12.5)],
		"open": [Vector2(0, 0), Vector2(50, 0), Vector2(-50, 12.5), Vector2(100, 12.5)],
		"crot": [-0.1, 0.05, -0.2, 0.15], "orot": [-0.15, 0.2, -0.35, 0.35], "order": [3, 1, 0, 2]}, # du fond vers l'avant (DrawOrder .33 .32 .31 .30)
}

func show_multi() -> void:
	m._apk_screen(func(): m.show_menu())
	_deck_btn(1260.0, 4, "PLAY ONLINE", "Play online two to six player games", func():
		if Profile.has_profile():
			m.go(show_online) # MultiplayerScene.cs:56 (ColorFade 1,0 s)
		else: # pas encore de pseudo : ChangeNameAvatarScene(canGoBack: false, setDefaultValues: true) d'abord
			m.go(func(): show_profile(false, true))) # MultiplayerScene.cs:60-62
	_deck_btn(660.0, 2, "PLAY WITH FRIENDS", "Play in a private room, by code", func(): # hors APK : remplace PASS AND PLAY (un seul ecran) ; chacun joue depuis son navigateur
		if Profile.has_profile():
			m.go(show_friends)
		else:
			m.go(func(): show_profile(false, true)))

## ButtonWithDeckEntity : big_button 504x400 centre en (cx, 540), titre (-305,-170) x 1,3, sous-titre Bookman (-250,-125) ; eventail de bosses a (0, +80) x 0,7.
func _deck_btn(cx: float, count: int, title: String, sub: String, cb: Callable) -> void:
	var b := TextureButton.new()
	b.name = title
	b.texture_normal = load(UI + "navigation/big_button.webp")
	b.texture_pressed = load(UI + "navigation/big_button_selected.webp")
	b.position = Vector2(cx - 252.0, 340.0)
	b.focus_mode = Control.FOCUS_NONE
	m.add_child(b)
	var spec: Dictionary = DECKS[count]
	var cards: Array = []
	var centre := Vector2(252.0, 280.0) # (0, 80) sous le centre du bouton
	var card_sz := Vector2(300, 430) * 0.56
	for i in (spec["order"] as Array):
		var id: String = (spec["ids"] as Array)[i]
		var path: String = CardDB.card_image(id, "boss")
		var t := TextureRect.new()
		t.texture = load(path) if ResourceLoader.exists(path) else null
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_SCALE
		t.size = card_sz
		t.pivot_offset = card_sz / 2.0
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		t.set_meta("i", i)
		b.add_child(t)
		cards.append(t)
	var tl := _t(title, 1.3, Color.WHITE, Vector2(cx - 305.0, 370.0) - b.position, 637.0, HORIZONTAL_ALIGNMENT_CENTER)
	tl.name = "Title"
	b.add_child(tl)
	var sl := _t(sub, 1.0, Color.WHITE, Vector2(cx - 250.0, 415.0) - b.position, 490.0, HORIZONTAL_ALIGNMENT_CENTER, BOOKMAN)
	sl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.add_child(sl)
	var state := {"tw": null}
	var move := func(expand: bool, dur: float, delay: float):
		if state["tw"] != null:
			(state["tw"] as Tween).kill()
		var tw := b.create_tween().set_parallel(true)
		state["tw"] = tw
		for c in cards:
			var i: int = c.get_meta("i")
			var p: Vector2 = (spec["open"] if expand else spec["close"])[i] * 0.7
			var r: float = (spec["orot"] if expand else spec["crot"])[i]
			tw.tween_property(c, "position", centre + p - card_sz / 2.0, dur).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_property(c, "rotation_degrees", rad_to_deg(r), dur).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	for c in cards: # eventail ferme, puis ouvert apres 0,5 s sur 1 s (MultiplayerScene.Start)
		var i: int = c.get_meta("i")
		c.position = centre + (spec["close"] as Array)[i] * 0.7 - card_sz / 2.0
		c.rotation_degrees = rad_to_deg((spec["crot"] as Array)[i])
	move.call(true, 1.0, 0.5)
	b.button_down.connect(func():
		tl.add_theme_color_override("font_color", GOLD)
		move.call(false, 1.0, 0.0))
	b.button_up.connect(func():
		tl.add_theme_color_override("font_color", Color.WHITE)
		move.call(true, 1.0, 0.0))
	b.button_down.connect(func(): AudioManager.play_sfx("ui_button_select"))
	b.pressed.connect(cb)

# --- MenuOnlineScene -------------------------------------------------------------

func show_online() -> void:
	_screen(func(): show_multi())
	_label_btn("WORLDWIDE", 960, 388.8, func(): m.go(show_public), GOLD) # hors APK : liste des salons publics
	_label_btn("WITH FRIENDS", 960, 583.2, func(): m.go(show_friends), GOLD) # MenuOnlineScene.cs:63 (ColorFade 1,0 s)
	_label_btn("CHANGE USER/AVATAR", 960, 777.6, func(): m.go(func(): show_profile(true, false)), GOLD) # MenuOnlineScene.cs:73

# --- WORLDWIDE : salons publics (hors APK) ----------------------------------------

## Liste defilante dans le cadre de la salle d'attente : TITRE / HOST / FREE (sieges libres / total) / PACKS + JOIN par ligne. Le serveur POUSSE `rooms` a chaque
## changement (OnlineClient.rooms_received) ; une minuterie redemande la liste toutes les PUBLIC_REFRESH_S et signale un serveur injoignable.
func show_public() -> void:
	var o = m.online
	_prepare_client()
	_screen(func():
		_leave_public()
		show_online())
	_panel_plain()
	m.add_child(_t("PUBLIC GAMES", 1.3, Color.WHITE, Vector2(420, 330)))
	for h in [["HOST", 830.0], ["FREE", 1070.0], ["PACKS", 1190.0]]:
		m.add_child(_t(h[0], 1.0, Color.WHITE, Vector2(h[1], 340)))
	var scroll := ScrollContainer.new()
	scroll.name = "Rooms"
	scroll.position = Vector2(391, 392)
	scroll.size = Vector2(1138, 509)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER # pas de barre grise : un filet dore (thumb) la remplace
	m.add_child(scroll)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	box.custom_minimum_size.x = 1138.0
	scroll.add_child(box)
	var thumb := ColorRect.new()
	thumb.color = GOLD
	thumb.size = Vector2(4, 40)
	thumb.position = Vector2(1522, 392)
	thumb.visible = false
	thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_child(thumb)
	var status := _t("LOADING...", 1.3, Color.WHITE, Vector2(390, 590), 1140.0, HORIZONTAL_ALIGNMENT_CENTER)
	status.name = "Status"
	m.add_child(status)
	_pub = {"scroll": scroll, "box": box, "status": status, "thumb": thumb, "sig": "", "loaded": false, "down": 0.0, "since": 0.0, "rooms": []}
	scroll.get_v_scroll_bar().value_changed.connect(func(_v): _update_thumb())
	var flt := _filter_edit(Vector2(390, 975), Vector2(340, 60), "FILTER", _pub_filter) # le texte survit a un aller-retour par une salle
	flt.name = "Filter"
	flt.text_changed.connect(func(t: String):
		_pub_filter = t
		_render_rooms())
	var btn := _label_btn("CREATE PUBLIC GAME", 960, 1005, func():
		_leave_public()
		m.go(func(): m.show_solo_count("public")), GOLD, 0.7, 1.8) # NEW GAME : meme parcours (joueurs 2-4, 5-6 avec Crash Landing, packs), puis create_room(n, true)
	btn.name = "CreatePublic"
	if o.rooms_received.is_connected(_on_rooms):
		o.rooms_received.disconnect(_on_rooms)
	o.rooms_received.connect(_on_rooms)
	var tick := Timer.new() # libere avec l'ecran (Main._clear)
	tick.wait_time = 0.5
	tick.timeout.connect(_public_tick)
	m.add_child(tick)
	tick.start()
	o.watch_rooms()

## Filtre de la liste publique (cote client) : le texte doit figurer, sans casse, dans le titre ou le nom de l'hote ; un entier N garde aussi les salons de N places.
static func filter_rooms(rooms: Array, q: String) -> Array:
	var f := q.strip_edges().to_lower()
	if f == "":
		return rooms
	return rooms.filter(func(e): return e is Dictionary and (str(e.get("title", "")).to_lower().contains(f) or str(e.get("host", "")).to_lower().contains(f) or (f.is_valid_int() and int(e.get("numPlayers", 0)) == int(f))))

## Champ de saisie compact (filtre de la liste, titre de la salle) : pas de grand cadre comme `_entry`, meme police.
func _filter_edit(pos: Vector2, size: Vector2, placeholder: String, text := "") -> LineEdit:
	var le := LineEdit.new()
	le.position = pos
	le.size = size
	le.text = text
	le.placeholder_text = placeholder
	le.max_length = 25
	le.context_menu_enabled = false
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.35)
	sb.border_color = GOLD
	sb.set_border_width_all(2)
	sb.content_margin_left = 14
	for n in ["normal", "focus", "read_only"]:
		le.add_theme_stylebox_override(n, sb)
	le.add_theme_font_override("font", UiKit.font(A))
	le.add_theme_font_size_override("font_size", 24)
	for c in ["font_color", "caret_color"]:
		le.add_theme_color_override(c, Color.WHITE)
	le.add_theme_color_override("font_placeholder_color", Color(1, 1, 1, 0.5))
	le.text_submitted.connect(func(_s): le.release_focus())
	m.add_child(le)
	return le

func _leave_public() -> void:
	var o = m.online
	if o.rooms_received.is_connected(_on_rooms):
		o.rooms_received.disconnect(_on_rooms)
	o.unwatch_rooms()
	_pub = {}

func _public_tick() -> void:
	if _busy or not is_instance_valid(_pub.get("box")):
		return
	var o = m.online
	if o.connected:
		_pub["down"] = 0.0
		_pub["since"] = float(_pub["since"]) + 0.5
		if float(_pub["since"]) >= PUBLIC_REFRESH_S:
			_pub["since"] = 0.0
			o.watch_rooms()
		return
	_pub["down"] = float(_pub["down"]) + 0.5
	o.watch_rooms() # rouvre la liaison si elle ne se rouvre pas toute seule
	if float(_pub["down"]) >= PUBLIC_UNREACHABLE_S:
		_show_rows([])
		_pub["sig"] = ""
		_pub["rooms"] = []
		_pub["loaded"] = false
		(_pub["status"] as Label).text = "UNABLE TO REACH THE SERVER"
		(_pub["status"] as Label).visible = true

func _on_rooms(rooms: Array) -> void:
	if not is_instance_valid(_pub.get("box")):
		return
	_pub["loaded"] = true
	_pub["down"] = 0.0
	var sig := JSON.stringify(rooms)
	if sig == _pub["sig"]:
		return
	_pub["sig"] = sig
	_pub["rooms"] = rooms
	_render_rooms()

## Affiche la liste recue au travers du filtre (un changement de texte rappelle ceci sans nouvelle liste).
func _render_rooms() -> void:
	if not is_instance_valid(_pub.get("box")) or not bool(_pub.get("loaded", false)):
		return
	var rooms: Array = _pub["rooms"]
	var shown := filter_rooms(rooms, _pub_filter)
	_show_rows(shown)
	var status: Label = _pub["status"]
	status.text = "NO PUBLIC GAMES YET\nCREATE ONE BELOW" if rooms.is_empty() else "NO MATCHING GAMES"
	status.visible = shown.is_empty()

func _show_rows(rooms: Array) -> void:
	var box: VBoxContainer = _pub["box"]
	var scroll: ScrollContainer = _pub["scroll"]
	var sv := scroll.scroll_vertical
	for c in box.get_children():
		box.remove_child(c)
		c.queue_free()
	for e in rooms:
		if e is Dictionary:
			box.add_child(_public_row(e))
	scroll.set_deferred("scroll_vertical", sv)
	_update_thumb.call_deferred()

## Filet dore a droite du cadre : position / taille du contenu defilant (cache s'il tient en entier).
func _update_thumb() -> void:
	if not is_instance_valid(_pub.get("box")):
		return
	var scroll: ScrollContainer = _pub["scroll"]
	var thumb: ColorRect = _pub["thumb"]
	var content := float((_pub["box"] as Control).size.y)
	var view := scroll.size.y
	thumb.visible = content > view + 1.0
	if thumb.visible:
		thumb.size.y = maxf(30.0, view * view / content)
		thumb.position.y = 392.0 + (view - thumb.size.y) * float(scroll.scroll_vertical) / (content - view)

func _pack_text(sets: Array) -> String:
	var out: Array = []
	for s in sets:
		if not str(s).ends_with("-wiki"): # paquets internes des cases wiki (tools-wiki...) : deja couverts par leur paquet
			out.append(PACK_ABBR.get(str(s), str(s).left(3).to_upper()))
	return " ".join(out) if not out.is_empty() else "BASE"

func _public_row(e: Dictionary) -> Control:
	var code := str(e.get("code", ""))
	var row := Control.new()
	row.name = "Room_" + code
	row.custom_minimum_size = Vector2(1138, ROW_STEP_BIG)
	var sep := ColorRect.new()
	sep.color = Color(120.0 / 255.0, 155.0 / 255.0, 161.0 / 255.0)
	sep.position = Vector2(0, ROW_STEP_BIG - 3.0)
	sep.size = Vector2(1138, 2)
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(sep)
	var cells := [ # [texte, echelle, x (ligne), largeur, y] : colonnes TITRE 420 / HOST 830 / FREE 1070 / PACKS 1190 (ecran)
		[str(e.get("title", "?")).left(25), 1.1, 29.0, 395.0, 28.0],
		[str(e.get("host", "?")).left(25), 1.0, 439.0, 230.0, 29.0],
		["%d/%d" % [int(e.get("free", 0)), int(e.get("numPlayers", 0))], 1.0, 679.0, 100.0, 29.0],
		[_pack_text(e.get("sets", [])), 1.0, 799.0, 170.0, 29.0],
	]
	for c in cells:
		var l := _t(str(c[0]), float(c[1]), Color.WHITE, Vector2(float(c[2]), float(c[4])), float(c[3]))
		l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		row.add_child(l)
	var join := _label_btn("JOIN", 1048.0, 40.0, func(): join_public(code), GOLD, 0.24, 5.2, row)
	join.name = "Join"
	return row

func join_public(code: String) -> void:
	if _busy:
		return
	_busy = true
	_prepare_client()
	var ok: bool = await m.online.join_lobby(code, str(m.profile.get("name", "Player")))
	_busy = false
	if ok:
		_leave_public()
		m.online.public_room = true
		m.go(show_waiting) # ColorFade 1,0 s comme WithFriendsOnlineScene.cs:56
		return
	var text := "Unable to join public room" # DBMBaseScene.cs:79-80 ; « Room is full » (:75)
	match str(m.online.last_error_code):
		"not_found": text = "This game is no longer open" # pas d'equivalent : l'APK n'a pas de liste publique
		"full": text = "Room is full"
	msg_box("NETWORK ERROR", text, func(): m.online.watch_rooms()) # la liste se met a jour tout de suite

# --- ChangeNameAvatarScene -------------------------------------------------------

## Selecteur horizontal d'avatars (AvatarScrollComponent) : pas 240, echelle 0,7 / 0,9 (0,3 s), glissement avec inertie et rappel aux bords.
class AvatarScroll extends Control:
	const STEP := 240.0
	const ORIGIN_X := 400.0   # origine du composant (160, 620) APK = (400, 620) ecran ; les avatars sont a y = 745
	var ids: Array = []
	var selected := ""
	var cont: Control
	var _items: Dictionary = {}
	var _bgs: Dictionary = {}
	var _max_left := 0.0
	var _drag := false
	var _moved := 0.0
	var _inertia := 0.0
	var _clamp := false

	func _init(p_ids: Array, p_selected: String) -> void:
		ids = p_ids
		selected = p_selected if p_selected in p_ids else (p_ids[0] as String)
		position = Vector2(0, 585)
		size = Vector2(1920, 371)
		clip_contents = true
		cont = Control.new()
		cont.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(cont)
		_max_left = -float(ids.size()) * STEP + 1440.0 * 0.95 # VirtualWidth APK x 0,95
		cont.position.x = -(float(ids.find(selected)) * STEP - 100.0) # l'avatar choisi est d'abord a x = 500 (pas de borne a l'ouverture, comme l'APK)
		for i in ids.size():
			var id: String = ids[i]
			var it := Control.new()
			it.size = Vector2(282, 282)
			it.pivot_offset = Vector2(141, 141)
			it.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var bg := TextureRect.new()
			bg.texture = load(UI + "avatar/avatar_bg_selected.webp" if id == selected else UI + "avatar/avatar_bg.webp")
			bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
			it.add_child(bg)
			var av := TextureRect.new()
			av.texture = load(Profile.avatar_path(id))
			av.position = Vector2(4, 4)
			av.mouse_filter = Control.MOUSE_FILTER_IGNORE
			it.add_child(av)
			it.position = Vector2(ORIGIN_X + float(i) * STEP - 141.0, 160.0 - 141.0)
			it.scale = Vector2.ONE * (0.9 if id == selected else 0.7)
			cont.add_child(it)
			_items[id] = it
			_bgs[id] = bg

	func _centre_of(id: String) -> Vector2:
		return Vector2(ORIGIN_X + cont.position.x + float(ids.find(id)) * STEP, 160.0)

	func select(id: String) -> void:
		if id == selected or not _items.has(id):
			return
		_scale_to(selected, 0.7, UI + "avatar/avatar_bg.webp")
		selected = id
		_scale_to(id, 0.9, UI + "avatar/avatar_bg_selected.webp")

	func _scale_to(id: String, s: float, bg_path: String) -> void:
		(_bgs[id] as TextureRect).texture = load(bg_path)
		var tw := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(_items[id], "scale", Vector2.ONE * s, 0.3)

	func _gui_input(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			if ev.pressed:
				_drag = true
				_moved = 0.0
				_inertia = 0.0
			else:
				_drag = false
				if _moved < 12.0: # tap : l'avatar sous le doigt
					for id in ids:
						var half := 141.0 * (_items[id] as Control).scale.x
						var c := _centre_of(id)
						if absf(ev.position.x - c.x) <= half and absf(ev.position.y - c.y) <= half:
							select(id)
							break
		elif ev is InputEventMouseMotion and _drag:
			var dx: float = (ev as InputEventMouseMotion).relative.x
			_moved += absf(dx)
			var nx := cont.position.x + dx
			_clamp = nx < _max_left or nx > 0.0
			_inertia = 0.0 if _clamp else dx
			cont.position.x = clampf(nx, _max_left - 200.0, 200.0)

	func _process(_delta: float) -> void:
		if _drag:
			return
		var x := cont.position.x
		if _clamp:
			var target := 0.0 if x > 0.0 else _max_left
			cont.position.x = lerpf(x, target, 0.4)
			if absf(cont.position.x - target) < 0.8:
				_clamp = false
		elif absf(_inertia) > 0.01:
			var nx := x + _inertia
			if nx > 0.0 or nx < _max_left:
				_inertia = 0.0
			else:
				cont.position.x = nx
				_inertia = lerpf(_inertia, 0.0, 0.1)

## `can_back` : fleche de retour (faux au premier passage) ; `defaults` : pseudo « player_xxxx » et avatar au hasard (APK : setDefaultValues).
func show_profile(can_back: bool = true, defaults: bool = false) -> void:
	if defaults:
		m.profile = Profile.random_profile()
	_screen(func(): show_online() if can_back else null)
	if not can_back: # premier passage : pas de fleche
		m.get_child(m.get_child_count() - 1).queue_free()
	m.add_child(_t("INSERT USERNAME", 1.3, Color.WHITE, Vector2(450, 330)))
	m.add_child(_t("SELECT AVATAR", 1.3, Color.WHITE, Vector2(450, 540)))
	var edit := _entry(Vector2(450, 375), str(m.profile.get("name", "")), GOLD)
	_blur_on_background(edit)
	UiKit.ninepatch(m, "ninepatch/avatars_bg.webp", Vector2(0, 585), Vector2(1920, 371), Vector4(0, 3, 0, 3))
	var scroll := AvatarScroll.new(Profile.PICKER, str(m.profile.get("avatar", "")))
	scroll.name = "AvatarScroll"
	scroll.gui_input.connect(func(_ev): edit.release_focus())
	m.add_child(scroll)
	m._ok_btn(func():
		if edit.text != "": # APK : un nom vide n'enregistre rien ; un nom d'espaces est accepte (ChangeNameAvatarScene.cs:104-109)
			m.profile["name"] = edit.text.left(Profile.NAME_MAX)
			m.profile["avatar"] = scroll.selected
			Profile.save_profile(str(m.profile["name"]), scroll.selected)
		show_online())

# --- WithFriendsOnlineScene ------------------------------------------------------

func show_friends() -> void:
	m.online.stop_state_poll()
	_screen(func(): show_online())
	var edit := _entry(Vector2(450, 720), "", Color.WHITE, "INSERT ROOM CODE") # fondu apres un appui sur ROOM CODE
	var box: NinePatchRect = edit.get_meta("box")
	edit.max_length = 0 # TextEntryEntity : aucune limite (WithFriendsOnlineScene.cs:131-136)
	edit.editable = false
	edit.mouse_filter = Control.MOUSE_FILTER_IGNORE
	edit.modulate.a = 0.0
	box.modulate.a = 0.0
	_blur_on_background(edit) # le code est sensible a la casse : rien n'est mis en majuscules
	var ok: TextureButton = m._img_btn("buttons/ok_bt.webp", "buttons/ok_bt_pressed.webp", Vector2(1697, 960), func(): join_room(edit.text))
	m.add_child(ok)
	ok.modulate.a = 0.0
	ok.disabled = true
	var ui := {"code_btn": null, "shown": false}
	# La saisie du code se montre / se cache ; le bouton ROOM CODE reste enfonce tant qu'elle est visible (StayPressed).
	var show_code := func(show: bool):
		ui["shown"] = show
		edit.editable = show
		edit.mouse_filter = Control.MOUSE_FILTER_STOP if show else Control.MOUSE_FILTER_IGNORE
		ok.disabled = not show
		(ui["code_btn"] as TextureButton).texture_normal = load(UI + ("navigation/bg_bt_multi_pressed.webp" if show else "navigation/bg_bt_multi.webp"))
		if not show:
			edit.release_focus()
		var tw: Tween = m.create_tween().set_parallel(true)
		tw.tween_property(box, "modulate:a", 1.0 if show else 0.0, 0.5)
		tw.tween_property(edit, "modulate:a", 1.0 if show else 0.0, 0.5)
		tw.tween_property(ok, "modulate:a", 1.0 if show else 0.0, 0.3)
	_label_btn("NEW GAME", 960, 378, func():
		if ui["shown"]:
			show_code.call(false)
		m.go(func(): m.show_solo_count("online"))) # WithFriendsOnlineScene.cs:75 (ColorFade 1,0 s)
	ui["code_btn"] = _label_btn("ROOM CODE", 960, 594, func(): show_code.call(true))
	if m.online.has_saved_session(): # hors APK : reprise de la partie en cours (rechargement de page, relance du jeu)
		_label_btn("RESUME", 390.0 + 216.5, 950.0 + 62.0, func(): resume_room(), GOLD, 0.7, 1.9).name = "Resume"

# --- creation / jonction d'une salle ----------------------------------------------

func _prepare_client() -> void:
	var o = m.online
	o.host = m.server_host
	o.player_name = str(m.profile.get("name", "Player"))
	o.player_avatar = str(m.profile.get("avatar", ""))
	var st := Profile.load_stats()
	o.player_wins = int(st["wins"])
	o.player_defeats = int(st["defeats"])

## `is_public` : salon visible dans WORLDWIDE (CREATE PUBLIC GAME), titre par defaut « <pseudo>'s game » ; sinon salon prive a code.
func create_room(count: int, is_public: bool = false) -> void:
	if _busy:
		return
	var back := func(): m.show_setup(count, "public" if is_public else "online") # APK : l'erreur laisse sur SELECT EXPANSIONS (ExpansionScene.GoToNexScene)
	var setup_err := Match.setup_error(count, m._active_sets()) # 5-6 joueurs : Crash Landing obligatoire (le serveur refuse aussi : bad_setup)
	if setup_err != "":
		msg_box("INVALID SETUP", BIG_GAME_MSG, back)
		return
	_busy = true
	_prepare_client()
	var ok: bool = await m.online.create_lobby(count, m._active_sets(), 0, is_public, "%s's game" % m.online.player_name)
	_busy = false
	if ok:
		m.go(show_waiting) # ExpansionScene.cs:153 (ColorFade 1,0 s)
	elif str(m.online.last_error_code) == "bad_setup":
		msg_box("INVALID SETUP", BIG_GAME_MSG, back)
	else:
		msg_box("NETWORK ERROR", "Unable to create public room" if is_public else "Unable to create private room", back)

func join_room(code: String) -> void:
	if _busy:
		return
	if code.strip_edges().length() != CODE_LEN:
		msg_box("NETWORK ERROR", "Invalid Code")
		return
	_busy = true
	_prepare_client()
	var ok: bool = await m.online.join_lobby(code, str(m.profile.get("name", "Player")))
	_busy = false
	if ok:
		m.go(show_waiting) # WithFriendsOnlineScene.cs:56 (ColorFade 1,0 s)
		return
	var text := "Unable to join private room"
	match str(m.online.last_error_code):
		"not_found": text = "Invalid Code"
		"full": text = "Room is full"
	msg_box("NETWORK ERROR", text)

func resume_room() -> void:
	if _busy:
		return
	_busy = true
	m.online.host = m.server_host
	var ok: bool = await m.online.try_resume()
	_busy = false
	if ok:
		m.go(show_waiting)
	else:
		msg_box("NETWORK ERROR", "Unable to resume the game", func(): show_friends())

# --- WaitingPrivateRoomScene -----------------------------------------------------

func show_waiting() -> void:
	var o = m.online
	_screen(func(): leave_waiting())
	_wait_err_shown = false
	var n_rows := maxi(4, o.current_num_players) # 5-6 joueurs (Crash Landing) : 6 lignes plus serrees dans le meme cadre
	var big := n_rows > 4
	if not big:
		UiKit.ninepatch(m, "ninepatch/searching_bg.webp", Vector2(390, 300), Vector2(1140, 604), Vector4(10, 0, 10, 0))
	else:
		_panel_plain()
		for i in range(1, n_rows):
			var sep := ColorRect.new()
			sep.color = Color(120.0 / 255.0, 155.0 / 255.0, 161.0 / 255.0)
			sep.position = Vector2(391, ROW_Y[0] + ROW_STEP_BIG * i - 3.0)
			sep.size = Vector2(1138, 2)
			sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
			m.add_child(sep)
	_wait_title = null
	if o.public_room: # salon public : le titre remplace l'en-tete ; l'hote le modifie (Entree ou perte du focus valide, le serveur nettoie : 25 caracteres, texte seul)
		if bool(o.is_host):
			var le := _filter_edit(Vector2(410, 318), Vector2(740, 52), "ROOM TITLE", str(o.current_title))
			le.name = "RoomTitle"
			le.focus_exited.connect(func(): _rename_room(le, le.text)) # Entree relache le focus (_filter_edit) : une seule voie
			_wait_title = le
		else:
			_wait_title = _t(str(o.current_title), 1.3, Color.WHITE, Vector2(420, 330), 740.0)
			(_wait_title as Label).clip_text = true
			m.add_child(_wait_title)
	else:
		m.add_child(_t("WAITING FRIENDS...", 1.3, Color.WHITE, Vector2(420, 330)))
	m.add_child(_t("WINS", 1.0, Color.WHITE, Vector2(1190, 340)))
	m.add_child(_t("DEFEATS", 1.0, Color.WHITE, Vector2(1370, 340)))
	_rows = []
	for i in n_rows:
		var y: float = ROW_Y[i] if not big else ROW_Y[0] + ROW_STEP_BIG * i
		var ty := y + (40.0 if not big else 25.0)
		var av := TextureRect.new()
		av.texture = load(UI + "avatar/avatar_none.webp")
		av.position = Vector2(410, y)
		av.scale = Vector2(0.45, 0.45) if not big else Vector2(0.29, 0.29)
		av.mouse_filter = Control.MOUSE_FILTER_IGNORE
		m.add_child(av)
		var nm := _t("", 1.3, Color.WHITE, Vector2(580, ty), 520.0)
		nm.clip_text = true
		m.add_child(nm)
		var w := _t("", 1.3, Color.WHITE, Vector2(1040, ty), 208.0, HORIZONTAL_ALIGNMENT_RIGHT)
		m.add_child(w)
		var d := _t("", 1.3, Color.WHITE, Vector2(1270, ty), 208.0, HORIZONTAL_ALIGNMENT_RIGHT)
		m.add_child(d)
		_rows.append({"avatar": av, "name": nm, "wins": w, "defeats": d})
	# RoomCodeEntity
	UiKit.ninepatch(m, "ninepatch/code_area_inact.webp", Vector2(390, 950), Vector2(974, 113), Vector4(10, 10, 10, 10))
	m.add_child(_t("ROOM CODE:", 1.3, Color.WHITE, Vector2(440, 990)))
	var code := _t(str(o.match_id), 1.8, GOLD, Vector2(715, 980))
	code.name = "RoomCode"
	m.add_child(code)
	# OK : maitre de salle seulement et plus d'un humain (WaitingPrivateRoomScene.ShowOkButton)
	_wait_ok = m._img_btn("buttons/ok_bt.webp", "buttons/ok_bt_pressed.webp", Vector2(1697, 960), func(): o.start_match())
	m.add_child(_wait_ok)
	_wait_ok.modulate.a = 0.0
	_wait_ok.disabled = true
	# Hors APK : lancer tout de suite, les sieges vides deviennent des IA (hote seulement).
	_wait_bots = _label_btn("START WITH BOTS", 1370.0 + 161.0, 966.0 + 46.0, func(): o.start_match(), GOLD, 0.52, 2.2)
	_wait_bots.name = "StartWithBots"
	_wait_bots.visible = false
	if o.lobby_changed.is_connected(_on_lobby_changed):
		o.lobby_changed.disconnect(_on_lobby_changed)
	o.lobby_changed.connect(_on_lobby_changed)
	if o.request_error.is_connected(_on_waiting_error):
		o.request_error.disconnect(_on_waiting_error)
	o.request_error.connect(_on_waiting_error)
	if not o.link_changed.is_connected(_on_waiting_link):
		o.link_changed.connect(_on_waiting_link)
	_update_waiting({"status": o.current_status, "seats": o.current_seats, "host": o.current_host, "title": o.current_title})
	o.start_lobby_poll()
	o.fetch_lobby()

## Cadre de la salle d'attente SANS separateurs de lignes : la texture porte les 4 separateurs (y 91, 219, 347, 475 de la texture) ; on n'en garde que l'en-tete,
## une bande sans trait etiree, le bas. Les lignes (6 places, ou la liste publique defilante) tracent leurs propres separateurs.
func _panel_plain() -> void:
	for part in [[0, 92, 300.0, 92.0], [93, 125, 392.0, 509.0], [601, 3, 901.0, 3.0]]:
		UiKit.ninepatch(m, "ninepatch/searching_bg.webp", Vector2(390, part[2]), Vector2(1140, part[3]), Vector4(10, 0, 10, 0)).region_rect = Rect2(0, part[0], 21, part[1]) # (np_tex rogne deja 2 px a gauche et 1 en haut : x 0-21, traits a y 90, 218, 346, 474, 602)

## Envoie le nouveau titre ; sur refus (vide, partie lancee) le champ reprend le titre du serveur.
func _rename_room(le: LineEdit, t: String) -> void:
	le.release_focus()
	var o = m.online
	if not le.is_inside_tree() or t.strip_edges() == str(o.current_title) or not o.connected:
		return
	if not await o.set_title(t) and is_instance_valid(le):
		le.text = str(o.current_title)

func leave_waiting() -> void:
	var o = m.online
	var was_public: bool = o.public_room # leave_match() l'efface
	o.stop_lobby_poll()
	o.stop_state_poll()
	o.leave_match(was_public) # retour a la liste publique : la liaison est reutilisee
	if o.lobby_changed.is_connected(_on_lobby_changed):
		o.lobby_changed.disconnect(_on_lobby_changed)
	_unwatch_waiting_errors()
	if o.state_received.is_connected(_on_first_state):
		o.state_received.disconnect(_on_first_state)
	show_public() if was_public else show_friends()

func _unwatch_waiting_errors() -> void:
	var o = m.online
	if o.request_error.is_connected(_on_waiting_error):
		o.request_error.disconnect(_on_waiting_error)
	if o.link_changed.is_connected(_on_waiting_link):
		o.link_changed.disconnect(_on_waiting_link)

## Salle morte (fermee, jeton refuse) ou liaison perdue pour de bon : « NETWORK ERROR », OK ramene a l'ecran precedent (APK : Pop).
## Toute autre erreur du serveur (demarrage refuse...) garde la salle : le OK ne fait rien.
func _on_waiting_error(msg: String) -> void:
	if msg.contains("reconnexion") or _wait_err_shown: # coupure passagere : le client rouvre tout seul
		return
	_wait_err_shown = true
	var o = m.online
	var room_gone: bool = str(o.match_id) == ""
	var dead: bool = room_gone or not o.connected
	var text := "Room closed" if room_gone else ("Unable to join public room" if o.public_room else "Unable to join private room")
	msg_box("NETWORK ERROR", text, func():
		_wait_err_shown = false
		if dead:
			leave_waiting())

## Liaison coupee en salle d'attente (U-C34) : on laisse WAIT_LINK_GRACE_S au client pour se reconnecter tout seul.
func _on_waiting_link(up: bool) -> void:
	if up:
		return
	m.get_tree().create_timer(WAIT_LINK_GRACE_S).timeout.connect(func():
		if is_instance_valid(_wait_ok) and not m.online.connected and m.online.match_id != "":
			_on_waiting_error("connexion perdue"))

func _on_lobby_changed(info: Dictionary) -> void:
	_update_waiting(info)
	if str(info.get("status", "")) == "running":
		var o = m.online
		o.stop_lobby_poll()
		if o.lobby_changed.is_connected(_on_lobby_changed):
			o.lobby_changed.disconnect(_on_lobby_changed)
		# Premier etat via le polling (reessaie tout seul si le reseau rate).
		if not o.state_received.is_connected(_on_first_state):
			o.state_received.connect(_on_first_state)
		o.start_state_poll()
		o.fetch_state()

func _on_first_state() -> void:
	var o = m.online
	if o.current_G.is_empty():
		return
	if o.state_received.is_connected(_on_first_state):
		o.state_received.disconnect(_on_first_state)
	_unwatch_waiting_errors()
	m.start_online_match()

## OnlinePanelEntity.UpdatePanel : 4 lignes (6 avec 5-6 joueurs) (avatar, pseudo <= 25 car., victoires, defaites) ; siege libre = « WAITING... ».
## Ligne en or : l'APK dore le joueur MECENE (IsBacker, OnlinePanelEntity.cs:91) ; les mecenes n'existent plus ici, la ligne de l'hote est doree a la place (ajout hors APK).
func _update_waiting(info: Dictionary) -> void:
	var title := str(info.get("title", ""))
	if is_instance_valid(_wait_title) and title != "":
		if _wait_title is LineEdit:
			if not (_wait_title as LineEdit).has_focus():
				(_wait_title as LineEdit).text = title
		else:
			(_wait_title as Label).text = title
	var seats: Array = info.get("seats", [])
	var host := int(info.get("host", -1))
	var humans := 0
	for i in _rows.size():
		if not is_instance_valid((_rows[i] as Dictionary)["name"]):
			return
		var r: Dictionary = _rows[i]
		var s = seats[i] if i < seats.size() else null
		var taken: bool = s is Dictionary and (s as Dictionary).get("name") != null
		var col := GOLD if (taken and i == host) else Color.WHITE
		var av := "avatar_none"
		if taken:
			var sd: Dictionary = s
			var want := str(sd.get("avatar", ""))
			if ResourceLoader.exists(Profile.avatar_path(want)):
				av = want
			(r["name"] as Label).text = str(sd.get("name", "?")).left(25)
			(r["wins"] as Label).text = str(int(sd.get("wins", 0)))
			(r["defeats"] as Label).text = str(int(sd.get("defeats", 0)))
			if not bool(sd.get("bot", false)):
				humans += 1
		else:
			(r["name"] as Label).text = "WAITING..."
			(r["wins"] as Label).text = "0"
			(r["defeats"] as Label).text = "0"
		(r["avatar"] as TextureRect).texture = load(Profile.avatar_path(av))
		for k in ["name", "wins", "defeats"]:
			((r[k]) as Label).add_theme_color_override("font_color", col)
	var open_host: bool = bool(m.online.is_host) and str(info.get("status", "")) != "running"
	if is_instance_valid(_wait_bots):
		_wait_bots.visible = open_host
	if is_instance_valid(_wait_ok):
		var show := open_host and humans > 1
		_wait_ok.disabled = not show
		var tw := _wait_ok.create_tween()
		tw.tween_property(_wait_ok, "modulate:a", 1.0 if show else 0.0, 0.3)
