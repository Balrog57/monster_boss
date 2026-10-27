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
var scroll: Control
var tab_buttons: Array = []
var _detail: Control
var _tab_box: Control
var cards_shown := 0
var _scroll_pos := [0.0, 0.0, 0.0, 0.0, 0.0] # position (x de la grille) de chaque onglet
var _pos := 0.0                     # x de la grille : 0 = debut, negatif = defile
var _min := 0.0
var _max := 0.0
var _vel := 0.0                     # inertie (px par image a 60 i/s)
var _dragging := false
var _fade_id := 0                   # fondu entre onglets en cours (toucher bloque pendant le fondu, GalleryScene.cs:347-433)
var _fading := false
var _detail_closing := false
var _sel_tile: TextureRect          # tuile touchee (agrandie, cadre jaune)
var _sel_idx := [-1, -1, -1, -1, -1] # tuile choisie de chaque onglet : chaque onglet a son propre ScrollCardBehavior, la selection survit au changement d'onglet (ScrollListBehavior.cs:160-183)
var _tpos := 0.0                    # y de la colonne d'onglets : 0 = debut, negatif = defile
var _tvel := 0.0
var _tdrag := false                 # un glissement a commence dans la colonne d'onglets
var _tmoved := 0.0                  # distance parcourue : au-dela de 12 px ce n'est plus un clic sur un onglet
var _tclip: Control
const TAB_MIN := -596.0             # MinPosition = -TotalHeight + 1080 x 0,3, TotalHeight = 4 x 230 (GalleryScene.cs:197)
const TAB_AMP := 100.0              # Amplitude (GalleryScene.cs:186)

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
	# Onglets : une pile verticale de dos de carte, defilable comme l'APK (ScrollListBehavior Vertical : course 596 px, depassement de 100 px, ressort 0,4, inertie 0,1)
	_tclip = Control.new()
	_tclip.position = Vector2(0, 100)
	_tclip.size = Vector2(172, 980)
	_tclip.clip_contents = true
	_tclip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_tclip)
	_tab_box = Control.new()
	_tab_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tclip.add_child(_tab_box)
	for i in TABS.size():
		var b := TextureButton.new()
		b.texture_normal = UiKit.tex(CardDB.card_image("", str(TABS[i][1])))
		b.ignore_texture_size = true
		b.stretch_mode = TextureButton.STRETCH_SCALE
		b.size = Vector2(135, 188)
		b.position = Vector2(19, 20 + 230.0 * i)
		b.name = "Tab%d" % i
		var idx := i
		b.pressed.connect(func():
			if _tmoved < 12.0:
				select_tab(idx, true))
		_tab_box.add_child(b)
		tab_buttons.append(b)
	scroll = Control.new() # defilement maison : ScrollListBehavior.cs:193-252 (inertie, depassement, ressort) ; la grille s'y deplace
	scroll.position = Vector2(200, 215)
	scroll.size = Vector2(1720, 865)
	scroll.clip_contents = true
	scroll.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseMotion and (ev.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0 and not _fading:
			_dragging = true # TouchMoved : position += glissement, inertie = dernier glissement (:171-179)
			_vel = ev.relative.x
			_set_pos(_pos + ev.relative.x)
		elif ev is InputEventMouseButton and ev.pressed: # molette (hors APK)
			if ev.button_index == MOUSE_BUTTON_WHEEL_DOWN or ev.button_index == MOUSE_BUTTON_WHEEL_RIGHT:
				_set_pos(_pos - 220.0)
			elif ev.button_index == MOUSE_BUTTON_WHEEL_UP or ev.button_index == MOUSE_BUTTON_WHEEL_LEFT:
				_set_pos(_pos + 220.0))
	add_child(scroll)
	select_tab(0)

## Glissement vertical de la colonne d'onglets (TouchMoved : position += glissement, inertie = dernier glissement) ; molette hors APK.
func _input(ev: InputEvent) -> void:
	if _detail != null and is_instance_valid(_detail):
		return
	var in_col := Rect2(0, 100, 172, 980).has_point(get_local_mouse_position())
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		if ev.pressed and in_col:
			_tdrag = true
			_tmoved = 0.0
			_tvel = 0.0
		elif not ev.pressed:
			_tdrag = false
	elif ev is InputEventMouseMotion and _tdrag and (ev.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		_tmoved += absf(ev.relative.y)
		_tvel = ev.relative.y
		_set_tpos(_tpos + ev.relative.y)
	elif ev is InputEventMouseButton and ev.pressed and in_col: # molette (hors APK)
		if ev.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_set_tpos(maxf(_tpos - 100.0, TAB_MIN))
		elif ev.button_index == MOUSE_BUTTON_WHEEL_UP:
			_set_tpos(minf(_tpos + 100.0, 0.0))

func _set_tpos(v: float) -> void:
	_tpos = clampf(v, TAB_MIN - TAB_AMP, TAB_AMP)
	_tab_box.position.y = _tpos

## Cartes de l'onglet : [dictionnaire, genre] ; jeu de base + paquets APK (+ wiki si l'option est cochee).
func cards_for(t: int) -> Array:
	var allowed: Array = APK_SETS.duplicate()
	if bool(Profile.load_settings().get("extensions", false)):
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

## L'onglet choisi prend l'echelle 0,42 au lieu de 0,37 en 0,2 s (cubique, EaseIn) et le cadre jaune en fondu de 0,5 s ; l'ancien repart de meme (GalleryScene.cs:190-191,
## ScrollItemComponent.cs:42-52). A l'ouverture BOSS est deja choisi (GalleryScene.Start :474, SetSelected(0)). user : appui sur l'onglet (son ui_button_select, :352).
func select_tab(t: int, user := false) -> void:
	if _fading and user:
		return
	_scroll_pos[tab] = _pos
	var prev := tab
	_fade_id += 1
	_fading = false
	scroll.modulate.a = 1.0
	tab = clampi(t, 0, TABS.size() - 1)
	if user:
		AudioManager.play_sfx("ui_button_select")
	title_label.text = str(TABS[tab][0])
	for i in tab_buttons.size():
		var b: TextureButton = tab_buttons[i]
		var sel := i == tab
		var old := b.get_node_or_null("Sel")
		if old != null and sel:
			continue # deja choisi : rien ne bouge
		if b.has_meta("tw"):
			(b.get_meta("tw") as Tween).kill()
		var tw := b.create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		b.set_meta("tw", tw)
		tw.tween_property(b, "size", Vector2(153, 213) if sel else Vector2(135, 188), 0.2) # 135 x 0,42 / 0,37 = 153
		tw.tween_property(b, "position", Vector2(10 if sel else 19, 8 if sel else 20) + Vector2(0, 230.0 * i), 0.2)
		if old != null: # l'ancien cadre s'efface en 0,5 s
			old.name = "SelOld" # le nom « Sel » doit etre libre pour le nouveau cadre
			_fade_out_free(old)
		if sel: # cadre jaune de l'onglet choisi (les autres n'ont pas de cadre)
			b.add_child(_border("Sel", 0.5))
	if user and tab != prev and scroll.get_node_or_null("Grid") != null: # fondu de sortie 0,5 s, puis d'entree 0,5 s (GalleryScene.cs:347-433)
		var id := _fade_id
		_fading = true
		var tw := create_tween()
		tw.tween_property(scroll, "modulate:a", 0.0, 0.5)
		await tw.finished
		if id != _fade_id or not is_instance_valid(self):
			return
		_fill_grid()
		var tw2 := create_tween()
		tw2.tween_property(scroll, "modulate:a", 1.0, 0.5)
		await tw2.finished
		if id == _fade_id:
			_fading = false
		return
	_fill_grid()

func _fade_out_free(n: CanvasItem) -> void:
	var tw := n.create_tween()
	tw.tween_property(n, "modulate:a", 0.0, 0.5)
	tw.tween_callback(n.queue_free)

func _fill_grid() -> void:
	var t := tab
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
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
		t_rect.set_meta("k", k)
		var press := [Vector2.ZERO]
		t_rect.gui_input.connect(func(ev: InputEvent): # un clic (sans glisser) ouvre la carte en grand
			if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
				if ev.pressed:
					press[0] = ev.global_position
				elif (ev.global_position - (press[0] as Vector2)).length() < 12.0:
					var from := t_rect.get_global_rect() # echelle avant l'agrandissement (CardPosition / OriginalScale, GalleryScene.cs:457-468)
					_select_tile(t_rect)
					show_detail(d, t_rect.texture, from))
		grid.add_child(t_rect)
		if k == int(_sel_idx[tab]): # la selection de l'onglet est gardee (ScrollListBehavior.previousSelected) : tuile deja agrandie, cadre deja la
			_sel_tile = t_rect
			var sz := CARD * (0.85 / 0.8)
			t_rect.size = sz
			t_rect.position = (t_rect.get_meta("base") as Rect2).get_center() - sz / 2.0
			t_rect.add_child(_border("Sel"))
	_max = 0.0 # ScrollCardBehavior : MinPosition = -TotalWidth + largeur / 2, TotalWidth = ((n - 1) / Lignes) x 310 (GalleryScene.cs:452-453, ScrollListBehavior.cs:54)
	_min = -float((tiles.size() - 1) / 2) * PITCH.x + 960.0
	_vel = 0.0
	if int(_sel_idx[tab]) < 0:
		_sel_tile = null
	_pos = _scroll_pos[t]
	grid.position.x = _pos

func _clamp_pos(v: float) -> float:
	return maxf(minf(v, _max + 100.0), _min - 100.0) # amplitude 100 (GalleryScene.cs:441)

func _set_pos(v: float) -> void:
	var grid := scroll.get_node_or_null("Grid")
	_pos = _clamp_pos(v)
	if grid != null:
		grid.position.x = _pos

func _process(delta: float) -> void:
	var f := minf(delta, 0.1) * 60.0 # les constantes de l'APK sont par image a 60 i/s
	if _tdrag and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_tdrag = false
	if not _tdrag: # meme ressort / inertie que la grille (ScrollListBehavior.Update :207-227)
		if _tpos > 0.0:
			_set_tpos(lerpf(_tpos, 0.0, 1.0 - pow(0.6, f)))
		elif _tpos < TAB_MIN:
			_set_tpos(lerpf(_tpos, TAB_MIN, 1.0 - pow(0.6, f)))
		elif absf(_tvel) > 0.01:
			_set_tpos(_tpos + _tvel * f)
			_tvel *= pow(0.9, f)
		else:
			_tvel = 0.0
	if _dragging and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_dragging = false
	if _dragging:
		return
	if _pos > _max:
		_set_pos(lerpf(_pos, _max, 1.0 - pow(0.6, f))) # ressort 0,4 par image
	elif _pos < _min:
		_set_pos(lerpf(_pos, _min, 1.0 - pow(0.6, f)))
	elif absf(_vel) > 0.01:
		_set_pos(_pos + _vel * f)
		_vel *= pow(0.9, f) # inertie x 0,9 par image
	else:
		_vel = 0.0

## Cadre jaune card_border_yellow (354 x 492 pour une carte de 350 x 488), pose a l'echelle 0,89 de la carte (ScrollItemComponent.cs:66) ;
## fade > 0 : apparition lineaire (FadeBehavior 0,5 s, ScrollItemComponent.cs:60).
func _border(nm: String, fade := 0.0, inner := 0.89) -> TextureRect:
	var f := TextureRect.new()
	f.name = nm
	f.texture = UiKit.tex(UI + "ingame/card_border_yellow.webp")
	f.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	f.stretch_mode = TextureRect.STRETCH_SCALE
	var k := inner * Vector2(354.0 / 350.0, 492.0 / 488.0) # ancres : le cadre suit la taille de la tuile pendant l'agrandissement
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

## Carte touchee : echelle 0,85 au lieu de 0,8 (x 1,0625, 0,2 s, cubique EaseIn) + cadre jaune en fondu de 0,5 s ; la precedente revient a 0,8 et son cadre s'efface en 0,5 s
## (ScrollListBehavior.cs:106,160-183, ScrollItemComponent.cs:42-52).
func _select_tile(t: TextureRect) -> void:
	_sel_idx[tab] = int(t.get_meta("k"))
	if t == _sel_tile:
		return
	if _sel_tile != null and is_instance_valid(_sel_tile):
		_scale_tile(_sel_tile, 1.0)
		var old := _sel_tile.get_node_or_null("Sel")
		if old != null:
			old.name = "SelOld"
			_fade_out_free(old)
	_sel_tile = t
	_scale_tile(t, 0.85 / 0.8)
	t.add_child(_border("Sel", 0.5))

func _scale_tile(t: TextureRect, k: float) -> void:
	var base: Rect2 = t.get_meta("base")
	var sz := base.size * k
	var tw := t.create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
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
	dim.color = Color(0, 0, 0, 0.7) # CardDetailScene.cs:45 : voile a 0,7 des l'ouverture (scene empilee sans transition)
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
	z.add_child(_border("Frame", 0.3, 1.0)) # BorderStyle = Yellow : sprite card_border_yellow en fondu de 0,3 s (CardDetailScene.cs:87)
	_detail.add_child(z)
	_detail.set_meta("card", card)
	var back_out := func():
		if not _detail_closing:
			_detail_closing = true
			AudioManager.play_sfx("ui_button_goback") # CardDetailScene.cs:74
			_animate_detail(0.0, from.position - global_position, from.size, close_detail)
	_detail.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed:
			back_out.call())
	# Fleche posee par-dessus le voile (CardDetailScene.cs:51-56) : celle de la galerie reste assombrie dessous
	var db := UiKit.texture_button(_detail, UI + "buttons/back_bt.webp", UI + "buttons/back_bt_pressed.webp", Vector2(200, 101))
	db.name = "DetailBack"
	db.pressed.connect(back_out)
	add_child(_detail)
	var big := Vector2(350, 488) * 1.8 # CardDetailScene.cs:84-91 : carte 350 x 488 a l'echelle 1,8, soit 630 x 878
	_animate_detail(0.7, Vector2(960, 540) - big / 2.0, big)

func _animate_detail(dim_alpha: float, pos: Vector2, sz: Vector2, then: Callable = Callable()) -> void:
	var z: Control = _detail.get_child(1)
	var tw := _detail.create_tween().set_parallel(true) # mouvement lineaire (MovementBehavior)
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
		AudioManager.play_sfx("ui_button_goback") # CardDetailScene.cs:74
		close_detail()
		return
	AudioManager.play_sfx("ui_button_goback")
	closed.emit()
	queue_free()
