extends Control
## Galerie de cartes de l'APK (GalleryScene) : colonne d'onglets a gauche (dos de carte : BOSS, ROOM DECK, SPELL DECK, HERO, EPIC HERO),
## titre « BOSS CARDS » & co, grille de cartes sur 2 lignes qui defile horizontalement, un clic ouvre la carte en grand.
## Seuls les paquets de l'APK (base, Player's Choice, Hidden Heroes ; pas les Tools, GetAvailableDecks les ecarte) ; les extensions du wiki (apres les cartes APK) si l'option « Wiki expansions » est cochee.
## Ordre APK : numero de carte decroissant ; BMA023 / BMA033 masquees (notInGameCards).
## Art alternatif (ScrollCardBehavior.AddElements) : Room et Spell ont une tuile par exemplaire (quantity) si une image « b » existe ; l'art est cyclique, num % (AlternativeArts + 1) + 1 (1 -> a, 2 -> b, ...).
## AlternativeArts n'est pas dans cards.json : on le deduit des images bma0XXb.webp extraites (tools/verify_assets.py les exige d'apres BaseDeck/data.json) ; sans art alternatif, une seule tuile.
## Accessible depuis le menu en jeu (engrenage) et depuis OPTIONS du menu principal ; `closed` puis liberation a la fermeture.

signal closed

const UiKit = preload("res://godot/scripts/UiKit.gd")
const Profile = preload("res://godot/scripts/Profile.gd")
const UI := "res://assets/ui/"
const APK_SETS := ["base", "players-choice", "hidden-heroes"]
const HIDDEN_IDS := ["BMA023", "BMA033"]
const GOLD := Color(1.0, 0.85, 0.1)  # cadre jaune de l'APK (onglet choisi, carte en grand)
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
var _scroll_pos := [0, 0, 0, 0, 0] # position horizontale de chaque onglet
var _detail_closing := false
var _sel_tile: TextureRect          # tuile touchee (agrandie, cadre jaune)

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
	UiKit.image(self, UI + "ingame/bg_top.webp", Vector2(175, 0), Vector2(1920, 77)) # taille native en (175, 0) : ecart 0,0 sur la capture APK (filet orange y 61-62 ; avant : etire en (175, -15), filet y 46-47)
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
		b.pressed.connect(func(): select_tab(idx, true))
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
	if bool(Profile.load_settings().get("extensions", true)):
		allowed.append_array(["next-level", "crash-landing", "minibosses", "tools", "iod", "players-choice-wiki"])
	var src: Array = [CardDB.bosses, CardDB.rooms, CardDB.spells, CardDB.heroes, CardDB.heroes][t]
	var out: Array = []
	for c in src:
		var d: Dictionary = c
		if not (str(d.get("set", "base")) in allowed) or str(d.get("id", "")) in HIDDEN_IDS:
			continue
		if t >= 3 and bool(d.get("epic", false)) != (t == 4):
			continue
		out.append(d)
	# APK : CardNumber decroissant ; les cartes du wiki (hors APK) viennent apres, dans le meme ordre.
	out.sort_custom(func(a, b):
		var wa: bool = not (str(a.get("set", "base")) in APK_SETS)
		var wb: bool = not (str(b.get("set", "base")) in APK_SETS)
		return str(a.get("id", "")) > str(b.get("id", "")) if wa == wb else wb)
	return out

## user : onglet choisi par un appui. A l'ouverture l'APK n'affiche ni cadre ni agrandissement sur BOSS (capture menu_card_gallery_boss_cards_grid_left_tabs) ;
## un onglet touche prend l'echelle 0,42 au lieu de 0,37 (GalleryScene.cs:177-178) et le cadre jaune (ScrollItemComponent.cs:42-52).
func select_tab(t: int, user := false) -> void:
	_scroll_pos[tab] = scroll.scroll_horizontal
	tab = clampi(t, 0, TABS.size() - 1)
	title_label.text = str(TABS[tab][0])
	for i in tab_buttons.size():
		var b: TextureButton = tab_buttons[i]
		var sel := i == tab and user
		b.size = Vector2(153, 213) if sel else Vector2(135, 188) # 135 x 0,42 / 0,37 = 153 (GalleryScene.cs:177-178)
		b.position = Vector2(10 if sel else 19, 8 if sel else 20) + Vector2(0, 230.0 * i)
		var old := b.get_node_or_null("Sel")
		if old != null:
			old.name = "SelOld" # libere en fin d'image : le nom « Sel » doit etre libre pour le nouveau cadre
			old.queue_free()
		if sel: # cadre jaune de l'onglet choisi (les autres n'ont pas de cadre)
			b.add_child(_border("Sel", 0.5))
	var content := scroll.get_node_or_null("Grid")
	if content != null:
		scroll.remove_child(content)
		content.queue_free()
	var list := cards_for(tab)
	cards_shown = list.size()
	var tiles: Array = [] # [carte, id de l'image] ; plusieurs tuiles par carte avec art alternatif
	for c in list:
		var d: Dictionary = c
		var id := str(d.get("id", ""))
		var alts := 0
		while tab in [1, 2] and ResourceLoader.exists("res://assets/apk_cards/base/%s%s.webp" % [id.to_lower(), char(98 + alts)]):
			alts += 1
		var num := 0
		for _i in (int(d.get("quantity", 1)) if alts > 0 else 1):
			num = num % (alts + 1) + 1
			tiles.append([d, id if num == 1 else id + char(96 + num)])
	var grid := Control.new()
	grid.name = "Grid"
	grid.custom_minimum_size = Vector2(60.0 + PITCH.x * ceilf(tiles.size() / 2.0), 830)
	scroll.add_child(grid)
	for k in tiles.size():
		var d: Dictionary = tiles[k][0]
		var t_rect := TextureRect.new()
		t_rect.texture = UiKit.tex(CardDB.card_image(str(tiles[k][1]), str(TABS[tab][2])))
		t_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t_rect.stretch_mode = TextureRect.STRETCH_SCALE
		t_rect.position = Vector2(35.0 + PITCH.x * float(k / 2), 15.0 + PITCH.y * float(k % 2))
		t_rect.size = CARD
		t_rect.tooltip_text = str(d.get("name", ""))
		t_rect.mouse_filter = Control.MOUSE_FILTER_PASS
		t_rect.set_meta("card", d)
		t_rect.set_meta("base", Rect2(t_rect.position, t_rect.size))
		var press := [Vector2.ZERO]
		t_rect.gui_input.connect(func(ev: InputEvent): # un clic (sans glisser) ouvre la carte en grand
			if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
				if ev.pressed:
					press[0] = ev.global_position
				elif (ev.global_position - (press[0] as Vector2)).length() < 12.0:
					var from := t_rect.get_global_rect() # echelle avant l'agrandissement (CardPosition / OriginalScale, GalleryScene.cs:451-456)
					_select_tile(t_rect)
					show_detail(d, t_rect.texture, from))
		grid.add_child(t_rect)
	scroll.scroll_horizontal = 0
	await get_tree().process_frame # la plage de defilement n'existe qu'apres la mise en page
	if tab == t and is_instance_valid(grid):
		scroll.scroll_horizontal = _scroll_pos[tab]

## Cadre jaune card_border_yellow (354 x 492 pour une carte de 350 x 488), pose a l'echelle 0,89 de la carte (ScrollItemComponent.cs:63) ;
## fade > 0 : apparition lineaire (FadeBehavior 0,5 s, ScrollItemComponent.cs:56).
func _border(nm: String, fade := 0.0) -> TextureRect:
	var f := TextureRect.new()
	f.name = nm
	f.texture = UiKit.tex(UI + "ingame/card_border_yellow.webp")
	f.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	f.stretch_mode = TextureRect.STRETCH_SCALE
	var k := 0.89 * Vector2(354.0 / 350.0, 492.0 / 488.0) # ancres : le cadre suit la taille de la tuile pendant l'agrandissement
	f.anchor_left = (1.0 - k.x) / 2.0
	f.anchor_right = 1.0 - f.anchor_left
	f.anchor_top = (1.0 - k.y) / 2.0
	f.anchor_bottom = 1.0 - f.anchor_top
	f.offset_left = 0.0
	f.offset_right = 0.0
	f.offset_top = 0.0
	f.offset_bottom = 0.0
	f.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if fade > 0.0:
		f.modulate.a = 0.0
		f.create_tween().tween_property(f, "modulate:a", 1.0, fade)
	return f

## Carte touchee : echelle 0,85 au lieu de 0,8 (x 1,0625, 0,2 s) + cadre jaune ; la precedente revient a 0,8 (GalleryScene.cs:445-446, ScrollItemComponent.cs:31-40).
func _select_tile(t: TextureRect) -> void:
	if t == _sel_tile:
		return
	if _sel_tile != null and is_instance_valid(_sel_tile):
		_scale_tile(_sel_tile, 1.0)
		_sel_tile.get_node("Sel").name = "SelOld"
		_sel_tile.get_node("SelOld").queue_free()
	_sel_tile = t
	_scale_tile(t, 0.85 / 0.8)
	t.add_child(_border("Sel", 0.5))

func _scale_tile(t: TextureRect, k: float) -> void:
	var base: Rect2 = t.get_meta("base")
	var sz := base.size * k
	var tw := t.create_tween().set_parallel(true)
	tw.tween_property(t, "size", sz, 0.2)
	tw.tween_property(t, "position", base.get_center() - sz / 2.0, 0.2)

## APK : la carte glisse de sa tuile au centre (~1,8x, 0,2 s), cadre jaune, fond noir a 0,7 ; un clic la ramene a sa tuile puis ferme.
func show_detail(card: Dictionary, texture: Texture2D, from: Rect2 = Rect2()) -> void:
	if _detail != null and is_instance_valid(_detail):
		return
	AudioManager.play_sfx("ui_button_select")
	_detail_closing = false
	if from.size == Vector2.ZERO:
		from = Rect2(Vector2(960, 540) - CARD / 2.0, CARD)
	_detail = Control.new()
	_detail.size = Vector2(1920, 1080)
	_detail.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0)
	dim.size = Vector2(1920, 1080)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_detail.add_child(dim)
	var z := TextureRect.new()
	z.texture = texture
	z.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	z.stretch_mode = TextureRect.STRETCH_SCALE
	z.mouse_filter = Control.MOUSE_FILTER_IGNORE
	z.position = from.position - global_position
	z.size = from.size
	var frame := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	sb.border_color = GOLD
	sb.set_border_width_all(4)
	frame.add_theme_stylebox_override("panel", sb)
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	z.add_child(frame)
	_detail.add_child(z)
	_detail.set_meta("card", card)
	_detail.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and not _detail_closing:
			_detail_closing = true
			_animate_detail(0.0, from.position - global_position, from.size, close_detail))
	add_child(_detail)
	var big := CARD * 1.8
	_animate_detail(0.7, Vector2(960, 540) - big / 2.0, big)

func _animate_detail(dim_alpha: float, pos: Vector2, sz: Vector2, then: Callable = Callable()) -> void:
	var z: Control = _detail.get_child(1)
	var tw := _detail.create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(_detail.get_child(0), "color:a", dim_alpha, 0.2)
	tw.tween_property(z, "position", pos, 0.2)
	tw.tween_property(z, "size", sz, 0.2)
	if then.is_valid():
		tw.chain().tween_callback(then)

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
