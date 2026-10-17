extends RefCounted
## Petits utilitaires d'interface partages par le plateau, le menu en jeu, la galerie et l'ecran de fin
## (polices pixel de l'APK, textures, libelles, cartes zoomees avec le cadre noir de l'APK, rangee ON/OFF).

const FONT_A := "res://assets/fonts/arcadepix.fnt"   # texte plein (titres, ON / OFF)
const FONT_B := "res://assets/fonts/arcadepix2.fnt"  # texte strie (boutons, libelles)
const UI := "res://assets/ui/"
const GOLD := Color(0.95, 0.78, 0.3)
const ZOOM_CARD := Vector2(330, 470)                 # zoom d'une carte (appui long, glisser, pioche, pile de sorts) ; cadre noir compris = 350 x 490 (mesure APK : pile de sorts, appui long)
const ZOOM_PAD := 10.0                               # cadre noir arrondi autour de la carte zoomee

static var _fonts := {}

## Police pixel + police par defaut pour les glyphes absents (accents francais, etc.).
static func font(path: String) -> Font:
	if not _fonts.has(path):
		var fv := FontVariation.new()
		fv.base_font = load(path)
		fv.fallbacks = [ThemeDB.fallback_font]
		_fonts[path] = fv
	return _fonts[path]

static func tex(path: String) -> Texture2D:
	return load(path) if ResourceLoader.exists(path) else null

static func label(parent: Node, text: String, size: int, color: Color, pos: Vector2, width: float = 0.0, font_path: String = FONT_B, align: int = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font(font_path))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	l.add_theme_constant_override("outline_size", 3)
	l.horizontal_alignment = align as HorizontalAlignment
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.position = pos
	if width > 0.0:
		l.custom_minimum_size.x = width
		l.size.x = width
	parent.add_child(l)
	return l

static func image(parent: Node, path: String, pos: Vector2, sz: Vector2 = Vector2.ZERO) -> TextureRect:
	var t := TextureRect.new()
	t.texture = tex(path)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_SCALE
	t.position = pos
	t.size = sz if sz != Vector2.ZERO else (t.texture.get_size() if t.texture != null else Vector2.ZERO)
	parent.add_child(t)
	return t

## Ninepatch de l'APK (WaveEngine) : l'image porte des reperes (1 ligne en haut, 1 en bas, 2 colonnes a gauche) ; le contenu est
## (2,1)..(w-1,h-2) et la zone etiree est le pixel central (marges = `margins` : gauche, haut, droite, bas).
static func np_tex(path: String) -> AtlasTexture:
	var t := tex(UI + path)
	var at := AtlasTexture.new()
	at.atlas = t
	if t != null:
		at.region = Rect2(2, 1, t.get_width() - 2, t.get_height() - 2)
	return at

static func ninepatch(parent: Node, path: String, pos: Vector2, sz: Vector2, margins: Vector4) -> NinePatchRect:
	var n := NinePatchRect.new()
	n.texture = np_tex(path)
	n.patch_margin_left = int(margins.x)
	n.patch_margin_top = int(margins.y)
	n.patch_margin_right = int(margins.z)
	n.patch_margin_bottom = int(margins.w)
	n.position = pos
	n.size = sz
	n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(n)
	return n

## Bouton plat (aucun style Godot) dont le fond est une texture de l'APK ; `pressed` = texture appuyee ("" = aucune).
static func texture_button(parent: Node, normal: String, pressed: String, pos: Vector2, sz: Vector2 = Vector2.ZERO) -> TextureButton:
	var b := TextureButton.new()
	b.texture_normal = tex(normal)
	if pressed != "":
		b.texture_pressed = tex(pressed)
	b.ignore_texture_size = true
	b.stretch_mode = TextureButton.STRETCH_SCALE
	b.position = pos
	b.size = sz if sz != Vector2.ZERO else (b.texture_normal.get_size() if b.texture_normal != null else Vector2(100, 100))
	parent.add_child(b)
	return b

## Bouton pierre de l'APK (options_bt) avec libelle : un vrai `Button` (texte lisible par les tests), style = la texture.
static func stone_button(parent: Node, text: String, pos: Vector2, sz: Vector2 = Vector2(546, 144), font_size: int = 38) -> Button:
	var b := Button.new()
	b.text = text
	b.position = pos
	b.size = sz
	b.custom_minimum_size = sz
	b.focus_mode = Control.FOCUS_NONE
	for n in ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed"]:
		var sb := StyleBoxTexture.new()
		sb.texture = tex(UI + ("buttons/options_bt_pressed.webp" if n in ["pressed", "hover_pressed"] else "buttons/options_bt.webp"))
		if n == "hover":
			sb.modulate_color = Color(1.25, 1.2, 1.05)
		b.add_theme_stylebox_override(n, sb)
	b.add_theme_font_override("font", font(FONT_B))
	b.add_theme_font_size_override("font_size", font_size)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(c, Color.WHITE)
	parent.add_child(b)
	return b

## Carte zoomee (cadre noir arrondi de l'APK) : racine de taille `sz` + 2 x ZOOM_PAD ; la carte est un CardUI sans souris.
static func zoom_card(card: Dictionary, sz: Vector2 = ZOOM_CARD, greyed: bool = false) -> Control:
	var root := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.02, 0.03, 0.97)
	sb.set_corner_radius_all(16)
	root.add_theme_stylebox_override("panel", sb)
	root.size = sz + Vector2(ZOOM_PAD, ZOOM_PAD) * 2.0
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var c = load("res://godot/scenes/Card.tscn").instantiate()
	c.default_size = sz
	root.add_child(c)
	c.position = Vector2(ZOOM_PAD, ZOOM_PAD)
	c.size = sz
	c.is_in_hand = false
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.set_process_input(false)
	c.setup(card)
	if greyed:
		c.set_greyed(true)
	root.set_meta("card", c)
	return root

## Une texture de carte (dos de pioche, carte de galerie) dans le meme cadre noir arrondi.
static func zoom_texture(texture: Texture2D, sz: Vector2 = ZOOM_CARD) -> Control:
	var root := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.02, 0.03, 0.97)
	sb.set_corner_radius_all(16)
	root.add_theme_stylebox_override("panel", sb)
	root.size = sz + Vector2(ZOOM_PAD, ZOOM_PAD) * 2.0
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var t := TextureRect.new()
	t.texture = texture
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_SCALE
	t.position = Vector2(ZOOM_PAD, ZOOM_PAD)
	t.size = sz
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(t)
	root.set_meta("tex", t)
	return root

## Dos de carte zoome (pioche de salles / de sorts).
static func zoom_back(kind: String, sz: Vector2 = ZOOM_CARD) -> Control:
	return zoom_texture(tex(CardDB.card_image("", kind)), sz)

## Rangee de segments facon APK (ecran SETTINGS) : le segment choisi est une pierre verte dorée, les autres sur une barre mauve.
## Absolu en 1920x1080 : libelle a droite de x=710, segments de 202 px a partir de x=760, centre vertical y.
static func toggle_row(parent: Control, y: int, text: String, opts: Array, sel: int, cb: Callable) -> void:
	var l := label(parent, text, 36, Color.WHITE, Vector2(264, y - 44), 450.0, FONT_B, HORIZONTAL_ALIGNMENT_RIGHT) # APK : libelle 6 px plus bas que la bascule, bord droit a x=710
	l.custom_minimum_size.y = 100.0
	l.size.y = 100.0
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var row := Control.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(row)
	_draw_toggle(row, y, opts, sel, cb)

static func _draw_toggle(row: Control, y: int, opts: Array, sel: int, cb: Callable) -> void:
	for c in row.get_children():
		row.remove_child(c)
		c.queue_free()
	var bar := ColorRect.new()
	bar.color = Color(109 / 255.0, 99 / 255.0, 131 / 255.0, 0.2) # APK : barre violette quasi transparente
	bar.position = Vector2(760, y - 48)
	bar.size = Vector2(202 * opts.size(), 96)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(bar)
	for i in opts.size():
		var x := 760 + 202 * i
		if i == sel:
			image(row, UI + "buttons/settings_bt.webp", Vector2(x, y - 58), Vector2(202, 106))
		var l := label(row, str(opts[i]), 34, GOLD if i == sel else Color.WHITE, Vector2(x, y - 48), 202.0, FONT_A, HORIZONTAL_ALIGNMENT_CENTER)
		l.custom_minimum_size.y = 96.0
		l.size.y = 96.0
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		var hit := Button.new()
		for n in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
			hit.add_theme_stylebox_override(n, StyleBoxEmpty.new())
		hit.focus_mode = Control.FOCUS_NONE
		hit.position = Vector2(x, y - 48)
		hit.size = Vector2(202, 96)
		hit.name = "Seg%d" % i
		var idx := i
		hit.pressed.connect(func():
			cb.call(idx)
			AudioManager.play_sfx("ui_button_select")
			_draw_toggle(row, y, opts, idx, cb))
		row.add_child(hit)
