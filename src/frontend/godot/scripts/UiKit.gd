extends RefCounted
## Petits utilitaires d'interface partages par le plateau, le menu en jeu, la galerie et l'ecran de fin
## (polices pixel de l'APK, textures, libelles, cartes zoomees avec le cadre noir de l'APK, rangee ON/OFF).

const FONT_A := "res://assets/fonts/arcadepix.fnt"   # texte plein (titres, ON / OFF)
const FONT_B := "res://assets/fonts/arcadepix2.fnt"  # texte strie (boutons, libelles)
const UI := "res://assets/ui/"
const GOLD := Color("cdb15f")                        # or de l'APK : CustomColors.cs:16
const PISTACHIO := Color("bfca7a")                   # CustomColors.cs:18
const SIDE_PANELS := Color("180a18")                 # SidePanelsBackColor, CustomColors.cs:20 : fond des panneaux lateraux (alpha 0,85 : TopLeftPanelEntity.cs:110, OneOpponentDetail.cs:71)
const LOADING_BG := Color("270000")                  # LoadingBg, CustomColors.cs:22 (LoadingScene.cs:24)
const TUTORIAL_BG := Color("e2bc54")                 # TutorialBg, CustomColors.cs:24 (aucun appelant dans l'APK decompile)
const BOSS_COLORS := {1: Color("34495c"), 2: Color("5e2a2f"), 3: Color("52506a"), 4: Color("74635d")} # GetBossTreasureColor (cs:58-77) : Cleric, Fighter, Mage, Thief (CardDB.TREASURE_NAMES)

## GetBossTreasureColor (CustomColors.cs:58-77) : le premier tresor present dans l'ordre Cleric, Fighter, Mage, Thief ; noir sans boss (OneOpponentDetail.cs:218).
static func boss_treasure_color(boss) -> Color:
	if boss == null:
		return Color.BLACK
	var tr: Array = ((boss as Dictionary).get("treasures", []) as Array).map(func(v): return int(v)) # le JSON donne des flottants : Array.has(2) est faux sur [2.0]
	for t in [1, 2, 3, 4]:
		if tr.has(t):
			return BOSS_COLORS[t]
	return Color.BLACK

const ZOOM_CARD := Vector2(354, 494)                 # zoom d'une carte (appui long, glisser, pioche, pile de sorts) ; la carte porte deja son bord noir de 16 px (mesure APK : boss x 1,3 = 460 de large, bord 21 ; pile de salles x 1,56 = 552, bord 27)
const ZOOM_PAD := 0.0                                # plus de cadre noir en plus : celui de l'APK est le bord de la carte (avant : 10 px de cadre autour d'une carte de 330 x 470)

static var _fonts := {}

## TouchOutBehavior.cs:55-85 : tant que le doigt est pose, on retient si sa derniere position est HORS de la zone ; la fermeture part au RELACHEMENT (pas a l'appui),
## et seulement si cette derniere position etait dehors. `inside` : Callable(Vector2) -> bool (la zone et ses colliders externes, AddCollider).
class TouchOut extends RefCounted:
	var out := false
	## Vrai quand `ev` est le relachement gauche d'un appui dont la derniere position etait hors de la zone.
	func feed(ev: InputEvent, inside: Callable) -> bool:
		if ev is InputEventMouseButton and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			var mb := ev as InputEventMouseButton
			if mb.pressed:
				out = not bool(inside.call(mb.global_position))
				return false
			var fired := out
			out = false
			return fired
		if ev is InputEventMouseMotion and ((ev as InputEventMouseMotion).button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
			out = not bool(inside.call((ev as InputEventMouseMotion).global_position))
		return false

## Police pixel + police par defaut pour les glyphes absents (accents francais, etc.).
static func font(path: String) -> Font:
	if not _fonts.has(path):
		var fv := FontVariation.new()
		fv.base_font = load(path)
		fv.fallbacks = [ThemeDB.fallback_font]
		_fonts[path] = fv
	return _fonts[path]

## CrossFadeTransition(ModalTransitionsTime 0,2 s) : la modale apparait en fondu lineaire sur l'ecran dessous (DBMBaseScene.cs:17 ; CrossFadeTransition.cs:35,40 ;
## ModalSceneService.cs:89,112-115). `n` doit deja etre dans l'arbre ; la fermeture d'une modale est une coupure (Pop sans transition).
static func cross_fade_in(n: CanvasItem) -> void:
	n.modulate.a = 0.0
	n.create_tween().tween_property(n, "modulate:a", 1.0, 0.2)

static var _tex_memo := {} # chemin -> texture (ou null) : exists + load() coutent ~1 ms en wasm

static func tex(path: String) -> Texture2D:
	if not _tex_memo.has(path):
		_tex_memo[path] = load(path) if ResourceLoader.exists(path) else null
	return _tex_memo[path]

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

static var _premult: CanvasItemMaterial

## Wave stocke ses textures en alpha PREMULTIPLIE (SpriteBatch : src + dst x (1 - alpha)) : la barre (18, 12, 32, alpha 0,5) sur (9, 9, 9) donne (22, 16, 36) sur l'APK, comme mesure ;
## le melange standard de Godot donnerait (14, 10, 21).
static func premult_mat() -> CanvasItemMaterial:
	if _premult == null:
		_premult = CanvasItemMaterial.new()
		_premult.blend_mode = CanvasItemMaterial.BLEND_MODE_PREMULT_ALPHA
	return _premult

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
static func texture_button(parent: Node, normal: String, pressed: String, pos: Vector2, sz: Vector2 = Vector2.ZERO, sfx: String = "") -> TextureButton: # sfx : a l'APPUI (ButtonBaseEntity.SetPressedState :185)
	var b := TextureButton.new()
	b.texture_normal = tex(normal)
	if sfx != "":
		b.button_down.connect(func(): AudioManager.play_sfx(sfx))
	if pressed != "":
		b.texture_pressed = tex(pressed)
	b.ignore_texture_size = true
	b.stretch_mode = TextureButton.STRETCH_SCALE
	b.position = pos
	b.size = sz if sz != Vector2.ZERO else (b.texture_normal.get_size() if b.texture_normal != null else Vector2(100, 100))
	parent.add_child(b)
	return b

## Bouton pierre de l'APK (options_bt) avec libelle : un vrai `Button` (texte lisible par les tests), style = la texture.
## `sfx` : joue a l'APPUI (ButtonBaseEntity.SetPressedState), pas au relachement. StayPressed (ButtonBaseEntity.cs:201) : apres un clic le bouton reste enfonce.
static func stone_button(parent: Node, text: String, pos: Vector2, sz: Vector2 = Vector2(546, 144), font_size: int = 27, sfx: String = "ui_button_select", stay: bool = true) -> Button: # 27 = arcadepix 21 x 1,3 (PauseScene.cs:52, LabelAndBackground.cs:70)
	var b := Button.new()
	b.text = text
	b.position = pos
	b.size = sz
	b.custom_minimum_size = sz
	b.focus_mode = Control.FOCUS_NONE
	for n in ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed"]:
		var sb := StyleBoxTexture.new()
		sb.texture = tex(UI + ("buttons/options_bt_pressed.webp" if n in ["pressed", "hover_pressed"] else "buttons/options_bt.webp"))
		sb.content_margin_bottom = 4.0 # l'encre APK est centree ~2 px plus haut qu'avec arcadepix centre par Godot (mesure : TUTORIAL APK y 346..364, Godot 345..362 a 6 px)
		sb.content_margin_right = 6.0 # et 3 px plus a gauche (APK x 875..1039, Godot 879..1041) : la largeur du texte APK compte l'interlettre final
		if n == "hover":
			sb.modulate_color = Color(1.25, 1.2, 1.05)
		b.add_theme_stylebox_override(n, sb)
	b.add_theme_font_override("font", font(FONT_A)) # arcadepix (Fonts.cs:6-12, LabelAndBackground.cs:89-91), pas arcadepix2
	b.add_theme_font_size_override("font_size", font_size)
	for c in ["font_color", "font_hover_color", "font_focus_color"]:
		b.add_theme_color_override(c, Color.WHITE) # repos blanc : ButtonWithLabelEntity.cs:21
	for c in ["font_pressed_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(c, GOLD) # appuye or #cdb15f : ButtonWithLabelEntity.cs:32
	if sfx != "":
		b.button_down.connect(func(): AudioManager.play_sfx(sfx))
	if stay:
		var rest := {"normal": b.get_theme_stylebox("normal"), "hover": b.get_theme_stylebox("hover")}
		b.pressed.connect(func():
			for n in ["normal", "hover"]: # StayPressed : le fond et l'or restent
				b.add_theme_stylebox_override(n, b.get_theme_stylebox("pressed"))
			for c in ["font_color", "font_hover_color"]:
				b.add_theme_color_override(c, GOLD))
		# `IsPressed = false` quand l'ecran redevient actif (OptionsScene.cs:107-114, PauseScene.cs:104-111)
		b.set_meta("unpress", func():
			for n in ["normal", "hover"]:
				b.add_theme_stylebox_override(n, rest[n])
			for c in ["font_color", "font_hover_color"]:
				b.add_theme_color_override(c, Color.WHITE))
	parent.add_child(b)
	return b

## Carte zoomee (cadre noir arrondi de l'APK) : racine de taille `sz` + 2 x ZOOM_PAD ; la carte est un CardUI sans souris.
static func zoom_card(card: Dictionary, sz: Vector2 = ZOOM_CARD, greyed: bool = false, pad: float = ZOOM_PAD) -> Control:
	var root := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.02, 0.03, 0.97)
	sb.set_corner_radius_all(int(16.0 * sz.x / 354.0))
	root.add_theme_stylebox_override("panel", sb)
	root.size = sz + Vector2(pad, pad) * 2.0
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var c = load("res://godot/scenes/Card.tscn").instantiate()
	c.default_size = sz
	root.add_child(c)
	c.position = Vector2(pad, pad)
	c.size = sz
	c.is_in_hand = false
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.set_process_input(false)
	c.setup(card)
	if BossEngine.hero_hp(card) > BossEngine.hero_base_hp(card):
		c.add_heart(BossEngine.hero_hp(card), true) # HeroCardEntity.cs:79-86 : le zoom d'un heros aux PV gagnes garde son coeur de buff
	if greyed:
		c.set_greyed(true)
	root.set_meta("card", c)
	# CardUI._ready (lance a l'entree dans l'arbre, apres les lignes ci-dessus) remet mouse_filter a STOP : la carte zoomee / glissee recevait le survol (echelle 1,15 + liseré or).
	root.ready.connect(func():
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		c.set_process_input(false))
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

## BackEase de l'APK (BackEase.cs:21-22, EasingFunctionBase.cs:24-31) : EaseIn(t) = t^3 - a t sin(pi t), EaseOut(t) = 1 - EaseIn(1 - t). `Tween.TRANS_BACK` a un recul fixe (1,70158), il ne convient pas.
static func back_ease(t: float, amp: float, ease_out: bool) -> float:
	var u := 1.0 - t if ease_out else t
	var v := u * u * u - amp * u * sin(PI * u)
	return 1.0 - v if ease_out else v

## CarrouselDragBehavior.DoCarouselIndexAnimation (cs:109-121) : a chaque image l'indice garde 20 % de moins de l'ecart, et se cale quand l'ecart tombe a 0,05 ; ecart restant apres x (0..1) de la course.
const CAROUSEL_FRAMES := 13.4 # ln(0,05) / ln(0,8) images a 60 Hz, soit 0,22 s
static func tween_carousel(tw: Tween, node: Object, prop: String, to: Variant) -> MethodTweener:
	var from: Variant = node.get_indexed(prop)
	return tw.tween_method(func(x: float): node.set_indexed(prop, to if x >= 1.0 else lerp(from, to, 1.0 - pow(0.8, x * CAROUSEL_FRAMES))), 0.0, 1.0, CAROUSEL_FRAMES / 60.0)

## Equivalent de `tween_property(node, prop, to, dur)` avec un BackEase d'amplitude `amp` (a chainer avec .set_delay).
static func tween_back(tw: Tween, node: Object, prop: String, to: Variant, dur: float, amp: float, ease_out: bool) -> MethodTweener:
	var from: Variant = node.get_indexed(prop)
	return tw.tween_method(func(x: float): node.set_indexed(prop, lerp(from, to, back_ease(x, amp, ease_out))), 0.0, 1.0, dur)

## Rangee de segments facon APK (ecran SETTINGS, SettingButtonDecorator) : barre = ninepatch settings_text_bg de 204 px par segment (hauteur 97), le segment choisi
## porte la bulle verte settings_bt (204 x 110, 5 px plus haut) et son texte or decale de -5 px par-dessus le texte blanc ; polices x 1,4 (29 px).
## Absolu en 1920x1080 : libelle a droite de x=710, segments a partir de x=760, centre vertical y.
static func toggle_row(parent: Control, y: int, text: String, opts: Array, sel: int, cb: Callable) -> void:
	var l := label(parent, text, 40, Color.WHITE, Vector2(265, y - 44), 450.0, FONT_B, HORIZONTAL_ALIGNMENT_RIGHT) # APK : libelle 6 px plus bas que la bascule, bord droit a x=710
	var fv := FontVariation.new() # APK : arcadepix2 x1,4 (taille 40) dont l'avance suit l'encre du glyphe, pas la case (mesure sur 03_settings)
	fv.base_font = load(FONT_B)
	fv.fallbacks = [ThemeDB.fallback_font]
	fv.spacing_glyph = -4
	l.add_theme_font_override("font", fv)
	l.add_theme_constant_override("outline_size", 0)
	l.custom_minimum_size.y = 100.0
	l.size.y = 100.0
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var row := Control.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(row)
	draw_toggle(row, y, opts, sel, cb)

const SEG := 204.0 # SettingButtonDecorator.WIDTH_PER_BUTTON

static func draw_toggle(row: Control, y: int, opts: Array, sel: int, cb: Callable) -> void:
	for c in row.get_children():
		row.remove_child(c)
		c.queue_free()
	ninepatch(row, "ninepatch/settings_text_bg.webp", Vector2(760, y - 48.5), Vector2(SEG * opts.size(), 97), Vector4(5, 5, 5, 5)).material = premult_mat()
	for i in opts.size():
		var x := 760.0 + SEG * i
		var chosen := i == sel
		for gold in ([false, true] if chosen else [false]):
			if gold:
				image(row, UI + "buttons/settings_bt.webp", Vector2(x, y - 60), Vector2(SEG, 110)) # le texte blanc (ordre -0,1) reste sous le bouton (-0,2), l'or (-0,3) par-dessus
			var l := label(row, str(opts[i]), 29, GOLD if gold else Color.WHITE, Vector2(x - 50, y - 48 - (5 if gold else 0)), 300.0, FONT_A, HORIZONTAL_ALIGNMENT_CENTER)
			l.add_theme_constant_override("outline_size", 0)
			l.custom_minimum_size.y = 96.0
			l.size.y = 96.0
			l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		var hit := Button.new()
		for n in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
			hit.add_theme_stylebox_override(n, StyleBoxEmpty.new())
		hit.focus_mode = Control.FOCUS_NONE
		hit.position = Vector2(x, y - 48)
		hit.size = Vector2(SEG, 96)
		hit.name = "Seg%d" % i
		var idx := i
		# A l'APPUI (TouchPressed) : l'option change tout de suite ; le son seulement si elle change (SettingButtonDecorator.cs:132)
		hit.button_down.connect(func():
			if idx != sel:
				AudioManager.play_sfx("ui_button_select")
			cb.call(idx)
			draw_toggle(row, y, opts, idx, cb))
		row.add_child(hit)
