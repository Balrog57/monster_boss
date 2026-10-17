extends Control
## Galerie de cartes de l'APK (GalleryScene) : colonne d'onglets a gauche (dos de carte : BOSS, ROOM DECK, SPELL DECK, HERO, EPIC HERO),
## titre « BOSS CARDS » & co, grille de cartes sur 2 lignes qui defile horizontalement, un clic ouvre la carte en grand.
## Seuls les paquets de l'APK (base, Player's Choice, Hidden Heroes, Tools) ; les extensions du wiki si l'option « Wiki expansions » est cochee.
## Accessible depuis le menu en jeu (engrenage) et depuis OPTIONS du menu principal ; `closed` puis liberation a la fermeture.

signal closed

const UiKit = preload("res://godot/scripts/UiKit.gd")
const Profile = preload("res://godot/scripts/Profile.gd")
const UI := "res://assets/ui/"
const APK_SETS := ["base", "players-choice", "hidden-heroes", "tools"]
## [titre, dos de carte de l'onglet, genre pour CardDB.card_image]
const TABS := [["BOSS CARDS", "back-boss", "boss"], ["ROOM CARDS", "back-room", "room"], ["SPELL CARDS", "back-spell", "spell"],
	["HERO CARDS", "back-hero", "hero"], ["EPIC HERO CARDS", "back-epic", "epic-hero"]]
const CARD := Vector2(280, 400)       # APK : cadre noir compris x 235..514 (280 de large), 400 de haut
const PITCH := Vector2(310, 410)       # ItemSize de l'APK : 310 x 410 (cartes a l'echelle ~0,82)

var tab := 0
var title_label: Label
var scroll: ScrollContainer
var tab_buttons: Array = []
var _detail: Control
var _tab_box: Control
var cards_shown := 0

func _ready() -> void:
	size = Vector2(1920, 1080)
	mouse_filter = Control.MOUSE_FILTER_STOP # bloque ce qui est dessous (plateau ou menu)
	_build()

func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Color.BLACK
	bg.size = Vector2(1920, 1080)
	add_child(bg)
	UiKit.image(self, UI + "backgrounds/gallery_bg.webp", Vector2(0, 105), Vector2(1920, 975)).modulate = Color(0.3, 0.3, 0.3) # APK : fond presque noir (~13 contre 64)
	UiKit.image(self, UI + "ingame/bg_top.webp", Vector2(175, -15), Vector2(1745, 77))
	UiKit.image(self, UI + "ingame/card_gallery_top.webp", Vector2.ZERO, Vector2(175, 96))
	title_label = UiKit.label(self, "", 29, Color.WHITE, Vector2(136, 9), 1745.0, UiKit.FONT_A, HORIZONTAL_ALIGNMENT_CENTER) # APK : titre 231 x 20 px centre en (1008, 30)
	UiKit.image(self, UI + "navigation/bm_logo.webp", Vector2(1590, 45), Vector2(260, 105))
	var panel := ColorRect.new()
	panel.color = Color(0, 0, 0, 0.4)
	panel.position = Vector2(0, 70)
	panel.size = Vector2(175, 1010)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	var line := ColorRect.new()
	line.color = Color(0.85, 0.65, 0.2, 0.85)
	line.position = Vector2(175, 0)
	line.size = Vector2(2, 1080)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(line)
	var back := UiKit.texture_button(self, UI + "buttons/back_bt.webp", UI + "buttons/back_bt_pressed.webp", Vector2(200, 101))
	back.name = "Back"
	back.pressed.connect(close_gallery)
	# Onglets : une pile verticale de dos de carte (defilable : le 5e depasse en bas comme dans l'APK)
	var tabs_scroll := ScrollContainer.new()
	tabs_scroll.position = Vector2(0, 100)
	tabs_scroll.size = Vector2(172, 980)
	tabs_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tabs_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	add_child(tabs_scroll)
	_tab_box = Control.new()
	_tab_box.custom_minimum_size = Vector2(172, 1200)
	tabs_scroll.add_child(_tab_box)
	for i in TABS.size():
		var b := TextureButton.new()
		b.texture_normal = UiKit.tex(CardDB.card_image("", str(TABS[i][1])))
		b.ignore_texture_size = true
		b.stretch_mode = TextureButton.STRETCH_SCALE
		b.size = Vector2(135, 188)
		b.position = Vector2(19, 20 + 230.0 * i)
		b.name = "Tab%d" % i
		var idx := i
		b.pressed.connect(func(): select_tab(idx))
		_tab_box.add_child(b)
		tab_buttons.append(b)
	scroll = ScrollContainer.new()
	scroll.position = Vector2(200, 215)
	scroll.size = Vector2(1720, 865)
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	scroll.gui_input.connect(func(ev: InputEvent): # molette : defilement horizontal
		if ev is InputEventMouseButton and ev.pressed:
			if ev.button_index == MOUSE_BUTTON_WHEEL_DOWN or ev.button_index == MOUSE_BUTTON_WHEEL_RIGHT:
				scroll.scroll_horizontal += 220
			elif ev.button_index == MOUSE_BUTTON_WHEEL_UP or ev.button_index == MOUSE_BUTTON_WHEEL_LEFT:
				scroll.scroll_horizontal = maxi(0, scroll.scroll_horizontal - 220))
	add_child(scroll)
	select_tab(0)

## Cartes de l'onglet : [dictionnaire, genre] ; jeu de base + paquets APK (+ wiki si l'option est cochee).
func cards_for(t: int) -> Array:
	var allowed: Array = APK_SETS.duplicate()
	if bool(Profile.load_settings().get("extensions", false)):
		allowed.append_array(["next-level", "crash-landing", "minibosses"])
	var src: Array = [CardDB.bosses, CardDB.rooms, CardDB.spells, CardDB.heroes, CardDB.heroes][t]
	var out: Array = []
	for c in src:
		var d: Dictionary = c
		if not (str(d.get("set", "base")) in allowed):
			continue
		if t >= 3 and bool(d.get("epic", false)) != (t == 4):
			continue
		out.append(d)
	return out

func select_tab(t: int) -> void:
	tab = clampi(t, 0, TABS.size() - 1)
	title_label.text = str(TABS[tab][0])
	for i in tab_buttons.size():
		var b: TextureButton = tab_buttons[i]
		b.modulate = Color.WHITE if i == tab else Color(0.62, 0.62, 0.62)
		var sel := i == tab
		b.size = Vector2(150, 210) if sel else Vector2(135, 188)
		b.position = Vector2(12 if sel else 19, 10 if sel else 20) + Vector2(0, 230.0 * i)
		var old := b.get_node_or_null("Sel")
		if old != null:
			old.queue_free()
		if sel: # cadre blanc de l'onglet choisi
			var f := Panel.new()
			f.name = "Sel"
			var sb := StyleBoxFlat.new()
			sb.bg_color = Color(0, 0, 0, 0)
			sb.border_color = Color.WHITE
			sb.set_border_width_all(4)
			sb.set_corner_radius_all(6)
			f.add_theme_stylebox_override("panel", sb)
			f.size = b.size
			f.mouse_filter = Control.MOUSE_FILTER_IGNORE
			b.add_child(f)
	var content := scroll.get_node_or_null("Grid")
	if content != null:
		scroll.remove_child(content)
		content.queue_free()
	var list := cards_for(tab)
	cards_shown = list.size()
	var grid := Control.new()
	grid.name = "Grid"
	grid.custom_minimum_size = Vector2(60.0 + PITCH.x * ceilf(list.size() / 2.0), 830)
	scroll.add_child(grid)
	for k in list.size():
		var d: Dictionary = list[k]
		var t_rect := TextureRect.new()
		t_rect.texture = UiKit.tex(CardDB.card_image(str(d.get("id", "")), str(TABS[tab][2])))
		t_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t_rect.stretch_mode = TextureRect.STRETCH_SCALE
		t_rect.position = Vector2(35.0 + PITCH.x * float(k / 2), 15.0 + PITCH.y * float(k % 2))
		t_rect.size = CARD
		t_rect.tooltip_text = str(d.get("name", ""))
		t_rect.mouse_filter = Control.MOUSE_FILTER_PASS
		t_rect.set_meta("card", d)
		var press := [Vector2.ZERO]
		t_rect.gui_input.connect(func(ev: InputEvent): # un clic (sans glisser) ouvre la carte en grand
			if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
				if ev.pressed:
					press[0] = ev.global_position
				elif (ev.global_position - (press[0] as Vector2)).length() < 12.0:
					show_detail(d, t_rect.texture))
		grid.add_child(t_rect)
	scroll.scroll_horizontal = 0

func show_detail(card: Dictionary, texture: Texture2D) -> void:
	if _detail != null and is_instance_valid(_detail):
		return
	AudioManager.play_sfx("ui_button_select")
	_detail = Control.new()
	_detail.size = Vector2(1920, 1080)
	_detail.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.78)
	dim.size = Vector2(1920, 1080)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_detail.add_child(dim)
	var z := UiKit.zoom_texture(texture, Vector2(560, 780))
	z.position = Vector2(960, 540) - z.size / 2.0
	_detail.add_child(z)
	_detail.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed:
			close_detail())
	_detail.set_meta("card", card)
	add_child(_detail)

func close_detail() -> void:
	if _detail != null and is_instance_valid(_detail):
		_detail.queue_free()
	_detail = null

func close_gallery() -> void:
	if _detail != null and is_instance_valid(_detail):
		close_detail()
		return
	AudioManager.play_sfx("ui_button_goback")
	closed.emit()
	queue_free()
