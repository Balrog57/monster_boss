extends RefCounted
## Ecrans multijoueur de l'APK 2.2.6 (maquette 1920x1080, coordonnees de decompiled/DBMGame/) :
##   MultiplayerScene (PLAY ONLINE / PASS AND PLAY) -> MenuOnlineScene (WORLDWIDE / WITH FRIENDS / CHANGE USER/AVATAR)
##   -> WithFriendsOnlineScene (NEW GAME / ROOM CODE) -> WaitingPrivateRoomScene ; ChangeNameAvatarScene ; MessageBoxScene.
## Repere : l'APK dessine dans 1440x1080 (Game.VIEWPORT_WIDTH) et un ecran 16:9 montre 240 px de plus de chaque cote : x ecran = x APK + 240 pour les
## constantes en dur (ex. champ de saisie (210,375) -> 450 ; les positions « VirtualWidth * 0.5 » = 720 donnent 960). Toutes les coordonnees ci-dessous sont en px ecran.
## `m` = Main (decor, widgets absolus, navigation) ; l'API d'OnlineClient (create_lobby / join_lobby / start_match / leave_match / try_resume) est inchangee.
## shortcut: pas de matchmaking mondial, WORLDWIDE ouvre la boite « NETWORK ERROR / Unable to join public rooms » comme l'APK sans paquets.

const UiKit = preload("res://godot/scripts/UiKit.gd")
const Profile = preload("res://godot/scripts/Profile.gd")

const UI := "res://assets/ui/"
const A := "res://assets/fonts/arcadepix.fnt"            # 21 px a l'echelle 1 (CreateArcadepixTB : le facteur d'echelle multiplie la taille)
const BOOKMAN := "res://assets/fonts/bookman_old_style.fnt" # 24 px a l'echelle 1
const GOLD := Color("cdb15f")
const AV_STEP := 240.0
const AV_ORIGIN_X := 400.0 # AvatarScrollComponent a (160, 620) APK
const ROW_Y := [394.0, 525.0, 652.0, 779.0]            # OnlinePanelEntity : 300 + 94 + i * 127 (+ 4 pour i > 0)
const CODE_LEN := 4

var m # Main (type volontairement libre : on appelle ses utilitaires _tex / _hit / _img_btn / _clear ...)
var _busy := false
var _rows: Array = []     # salle d'attente : {avatar, name, wins, defeats}
var _wait_ok: TextureButton = null
var _wait_bots: TextureButton = null
var _wait_err_shown := false
var _bgn: Control = null  # fond de l'ecran courant (un clic dessus deselectionne le champ de saisie)

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
		m.add_child(m._img_btn("buttons/back_bt.webp", "buttons/back_bt_pressed.webp", Vector2(20, 22), back, Vector2.ZERO, "ui_button_goback"))

## ButtonWithLabelEntity : bg_bt_multi (619x177, taille native) centre en (cx, cy), libelle arcadepix x 1.3 centre ; `pressed_color` = couleur pendant l'appui.
func _label_btn(text: String, cx: float, cy: float, cb: Callable, pressed_color: Color = Color.WHITE, s: float = 1.0, text_scale: float = 1.3) -> TextureButton:
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
	b.pressed.connect(func(): AudioManager.play_sfx("ui_button_select"))
	b.pressed.connect(cb)
	m.add_child(b)
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
	b.pressed.connect(func(): AudioManager.play_sfx("ui_button_select"))
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

# --- MultiplayerScene : PLAY ONLINE / PASS AND PLAY ------------------------------

const DECKS := {
	2: {"ids": ["BMA006", "BMA002"], "close": [Vector2(0, 0), Vector2(50.0 / 3.0, 0)], "open": [Vector2(0, 0), Vector2(50, 0)],
		"crot": [-0.1, 0.05], "orot": [-0.15, 0.2], "order": [1, 0]},
	4: {"ids": ["BMA007", "BMA002", "BMA001", "BMA006"], "close": [Vector2(0, 0), Vector2(50.0 / 3.0, 0), Vector2(-50.0 / 3.0, 12.5), Vector2(50.0 / 3.0, 12.5)],
		"open": [Vector2(0, 0), Vector2(50, 0), Vector2(-50, 12.5), Vector2(100, 12.5)],
		"crot": [-0.1, 0.05, -0.2, 0.15], "orot": [-0.15, 0.2, -0.35, 0.35], "order": [3, 1, 0, 2]}, # du fond vers l'avant (DrawOrder .33 .32 .31 .30)
}

func show_multi() -> void:
	m._apk_screen(func(): m.show_menu(), true)
	_deck_btn(1260.0, 4, "PLAY ONLINE", "Play online two to four player games", func():
		if Profile.has_profile():
			m.go(show_online) # MultiplayerScene.cs:56 (ColorFade 1,0 s)
		else: # pas encore de pseudo : ChangeNameAvatarScene(canGoBack: false, setDefaultValues: true) d'abord
			m.go(func(): show_profile(false, true))) # MultiplayerScene.cs:60-62
	_deck_btn(660.0, 2, "PASS AND PLAY", "Play versus another player\n using the same device", func(): m.go(func(): m.show_solo_count("pass"))) # MultiplayerScene.cs:78 (ColorFade 1,0 s)

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
	b.pressed.connect(func(): AudioManager.play_sfx("ui_button_select"))
	b.pressed.connect(cb)

# --- MenuOnlineScene -------------------------------------------------------------

func show_online() -> void:
	_screen(func(): show_multi())
	_label_btn("WORLDWIDE", 960, 388.8, func(): msg_box("NETWORK ERROR", "Unable to join public rooms"), GOLD)
	_label_btn("WITH FRIENDS", 960, 583.2, func(): m.go(show_friends), GOLD) # MenuOnlineScene.cs:63 (ColorFade 1,0 s)
	_label_btn("CHANGE USER/AVATAR", 960, 777.6, func(): m.go(func(): show_profile(true, false)), GOLD) # MenuOnlineScene.cs:73

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
		if edit.text.strip_edges() != "": # APK : un nom vide n'enregistre rien
			m.profile["name"] = edit.text.strip_edges().left(Profile.NAME_MAX)
			m.profile["avatar"] = scroll.selected
			Profile.save_profile(str(m.profile["name"]), scroll.selected)
		show_online())

# --- WithFriendsOnlineScene ------------------------------------------------------

func show_friends() -> void:
	m.online.stop_state_poll()
	_screen(func(): show_online())
	var edit := _entry(Vector2(450, 720), "", Color.WHITE, "INSERT ROOM CODE") # fondu apres un appui sur ROOM CODE
	var box: NinePatchRect = edit.get_meta("box")
	edit.max_length = CODE_LEN
	edit.editable = false
	edit.mouse_filter = Control.MOUSE_FILTER_IGNORE
	edit.modulate.a = 0.0
	box.modulate.a = 0.0
	edit.text_changed.connect(func(t: String):
		if t.to_upper() != t:
			var c := edit.caret_column
			edit.text = t.to_upper()
			edit.caret_column = c)
	_blur_on_background(edit)
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

func create_room(count: int) -> void:
	if _busy:
		return
	_busy = true
	_prepare_client()
	var ok: bool = await m.online.create_lobby(count, m._active_sets())
	_busy = false
	if ok:
		m.go(show_waiting) # ExpansionScene.cs:153 (ColorFade 1,0 s)
	else:
		msg_box("NETWORK ERROR", "Unable to create private room", func(): show_friends())

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
		show_waiting()
	else:
		msg_box("NETWORK ERROR", "Unable to resume the game", func(): show_friends())

# --- WaitingPrivateRoomScene -----------------------------------------------------

func show_waiting() -> void:
	var o = m.online
	_screen(func(): leave_waiting())
	_wait_err_shown = false
	UiKit.ninepatch(m, "ninepatch/searching_bg.webp", Vector2(390, 300), Vector2(1140, 604), Vector4(10, 0, 10, 0))
	m.add_child(_t("WAITING FRIENDS...", 1.3, Color.WHITE, Vector2(420, 330)))
	m.add_child(_t("WINS", 1.0, Color.WHITE, Vector2(1190, 340)))
	m.add_child(_t("DEFEATS", 1.0, Color.WHITE, Vector2(1370, 340)))
	_rows = []
	for i in 4:
		var y: float = ROW_Y[i]
		var av := TextureRect.new()
		av.texture = load(UI + "avatar/avatar_none.webp")
		av.position = Vector2(410, y)
		av.scale = Vector2(0.45, 0.45)
		av.mouse_filter = Control.MOUSE_FILTER_IGNORE
		m.add_child(av)
		var nm := _t("", 1.3, Color.WHITE, Vector2(580, y + 40), 520.0)
		nm.clip_text = true
		m.add_child(nm)
		var w := _t("", 1.3, Color.WHITE, Vector2(1040, y + 40), 208.0, HORIZONTAL_ALIGNMENT_RIGHT)
		m.add_child(w)
		var d := _t("", 1.3, Color.WHITE, Vector2(1270, y + 40), 208.0, HORIZONTAL_ALIGNMENT_RIGHT)
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
	_update_waiting({"status": o.current_status, "seats": o.current_seats, "host": o.current_host})
	o.start_lobby_poll()
	o.fetch_lobby()

func leave_waiting() -> void:
	var o = m.online
	o.stop_lobby_poll()
	o.stop_state_poll()
	o.leave_match()
	if o.lobby_changed.is_connected(_on_lobby_changed):
		o.lobby_changed.disconnect(_on_lobby_changed)
	if o.request_error.is_connected(_on_waiting_error):
		o.request_error.disconnect(_on_waiting_error)
	if o.state_received.is_connected(_on_first_state):
		o.state_received.disconnect(_on_first_state)
	show_friends()

func _on_waiting_error(msg: String) -> void:
	if msg.contains("reconnexion") or _wait_err_shown: # coupure passagere : le client rouvre tout seul
		return
	_wait_err_shown = true
	var room_gone: bool = str(m.online.match_id) == ""
	msg_box("NETWORK ERROR", "Room closed" if room_gone else "Unable to join private room", func():
		_wait_err_shown = false
		if room_gone:
			leave_waiting())

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
	if o.request_error.is_connected(_on_waiting_error):
		o.request_error.disconnect(_on_waiting_error)
	m.start_online_match()

## OnlinePanelEntity.UpdatePanel : 4 lignes (avatar, pseudo <= 25 car., victoires, defaites) ; ligne de l'hote en or ; siege libre = « WAITING... ».
func _update_waiting(info: Dictionary) -> void:
	var seats: Array = info.get("seats", [])
	var host := int(info.get("host", -1))
	var humans := 0
	for i in 4:
		if i >= _rows.size() or not is_instance_valid((_rows[i] as Dictionary)["name"]):
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
