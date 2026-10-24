extends Control
## CreditsScene de l'APK (CreditsScene.cs ; CreditRollBehavior.cs) : OPTIONS > CREDITS. Cet ecran se pose PAR-DESSUS l'ecran OPTIONS (Push sans transition :
## OptionsScene.cs:95-102), sous un voile noir ; main.go(show_options) le referme en fondu noir de 1,0 s (CreditsScene.cs:129-133). Aucune musique, aucun son a l'ouverture.
## Repere de l'APK : 1440 x 1080 ; Godot : 1920 x 1080, donc x_godot = x_apk + DX (le y est inchange).
## Tout le texte est arcadepix en MAJUSCULES, base 21 px (Main.gd : arcadepix 21 x echelle) ; 21 x 1,4 = 29,4 -> 29 et 21 x 1,3 = 27,3 -> 27 (la taille d'une police Godot est entiere).

signal closed

const UiKit = preload("res://godot/scripts/UiKit.gd")
const UI := "res://assets/ui/"
const DATA := "res://assets/data/credits.json"          # Content/Common/credits.json (CreditsScene.cs:50)

const DX := 240.0                                       # (1920 - 1440) / 2
const MIDDLE := 720.0                                   # VirtualWidth / 2 (CreditsScene.cs:85)
const SPEED := 100.0                                    # px/s : increment = ms x 0,1 (CreditRollBehavior.cs:38-39)
const VEIL_ALPHA := 0.7                                 # CreateBlackBack : teinte noire alpha 0,7 (CreditsScene.cs:45 ; ControlsFactory.cs:117-127)
const VEIL_FADE := 0.3                                  # FadeBehavior(0,3 s) : opacite 0 -> 1 (CreditsScene.cs:47-49,308-311)
const LOGO_Y := 170.0                                   # logo_small centre en (VirtualWidth / 2 ; 170) (CreditsScene.cs:69-70)
const LOGO_DELAY := 880.0                               # CreditRollBehavior.Delay, decremente de `increment` (px) : 880 / 100 px/s = 8,8 s (CreditsScene.cs:63-66 ; CreditRollBehavior.cs:44-48)
const ROLL_Y0 := 1180.0                                 # VirtualHeight + 100 (CreditsScene.cs:77)
const FOOT_Y0 := 4620.0                                 # CreditsScene.cs:108
const FOOT_MIN_Y := 400.0                               # footerCreditRollBehavior.MinY (CreditsScene.cs:102-105)
const DRAG_DOWN_MAX_LOGO_Y := 150.0                     # glisser vers le bas seulement si le logo est monte sous 150 (CreditsScene.cs:146)
const Y_OFFSET := 40.0                                  # interligne des H2 / noms / fin de paragraphe / pied (CreditsScene.cs:81 ; AddParagraph :255,268,294 ; AddFooter :215)
const H1_Y_OFFSET := 80.0                               # CreditsScene.cs:82,183 (+ la moitie, 40, quand H1 > 40 caracteres : :184-187)
const H1_X := 290.0                                     # CreateArcadepixTB(currentPosition.X + 290, ...) (CreditsScene.cs:175)
const H1_W := 600.0                                     # CreditsScene.cs:179
const H1_SCALE := 1.4                                   # CreditsScene.cs:175
const W := 1090.0                                       # largeur des H2 / noms (CreditsScene.cs:84,212,252)
const TXT_SCALE := 1.3                                  # H2 et noms (CreditsScene.cs:209,249,263)
const BASE := 21.0                                      # taille de base arcadepix
const SEP_DX := -10.0                                   # separateur : middle - 10 (CreditsScene.cs:197)
const TEXT_DY := -5.0                                   # Godot pose les glyphes d'arcadepix ~5 px plus bas que Wave dans la meme boite (frames APK flow_02_build / apk_build_03_pass1 : haut de POWERED BY a y 405 contre 411, haut de H1 / noms 5 px plus bas par rapport au separateur)
const PISTACHIO := Color("bfca7a")                      # CustomColors.PistachioColor (CustomColors.cs:18 ; CreditsScene.cs:209,249)
const BACK_POS := Vector2(20, 22)                       # fleche de retour habituelle de Main.gd (le C# : CreateEmptyBackButton, CreditsScene.cs:129 ; ControlsFactory.cs:243-254)

## CreditRollBehavior (CreditRollBehavior.cs:30-80) : `node.position.y` = Transform2D.Y, bornes MinY / MaxY, evenements BeginToMove / MinReached.
class Roll:
	var node: Control
	var delay := 0.0
	var min_y := -INF
	var active := true
	var begun := false
	var reached := false
	var on_begin := Callable()
	var on_min := Callable()

	func move(inc: float) -> void:
		if delay > 0.0:
			delay -= inc
			return
		if not begun:
			begun = true
			if on_begin.is_valid():
				on_begin.call()
		if node.position.y > min_y: # MaxY = float.MaxValue : jamais atteint
			node.position.y -= inc
		elif not reached:
			reached = true
			if on_min.is_valid():
				on_min.call()

var logo := Roll.new()
var roll := Roll.new()
var footer := Roll.new()
var veil: ColorRect
var touch_on := false   # touchGestures.IsActive : faux jusqu'au premier mouvement du logo, refaux quand le pied atteint MinY (CreditsScene.cs:113-116,137-141,168-171)
var dragging := false
var _font: Font

func _ready() -> void:
	name = "CreditsScreen"
	position = Vector2.ZERO
	size = Vector2(1920, 1080) # Main n'a pas de taille de layout propre : tailles explicites (comme Main.go)
	mouse_filter = Control.MOUSE_FILTER_STOP # le rectangle tactile couvre l'ecran (CreditsScene.cs:117-121) : rien ne passe a OPTIONS dessous
	_font = UiKit.font(UiKit.FONT_A)
	veil = ColorRect.new()
	veil.name = "Veil"
	veil.color = Color(0, 0, 0, 0)
	veil.size = Vector2(1920, 1080)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(veil)
	create_tween().tween_property(veil, "color:a", VEIL_ALPHA, VEIL_FADE) # opacite 0 -> 1 lineaire sur un panneau noir de teinte 0,7 : alpha 0 -> 0,7
	var data := load_data()
	_build_logo(data)
	_build_roll(data)
	_build_footer(data)
	logo.delay = LOGO_DELAY
	footer.min_y = FOOT_MIN_Y
	logo.on_begin = func(): touch_on = true
	footer.on_min = func():
		touch_on = false
		roll.active = true
	var back := TextureButton.new()
	back.name = "Back"
	back.texture_normal = load(UI + "buttons/back_bt.webp")
	back.texture_pressed = load(UI + "buttons/back_bt_pressed.webp")
	back.position = BACK_POS
	back.pressed.connect(func():
		AudioManager.play_sfx("ui_button_goback") # ui_button_goback (ControlsFactory.cs:245)
		closed.emit())
	add_child(back)

func _process(delta: float) -> void:
	var inc := delta * 1000.0 * 0.1 # CreditRollBehavior.Update (:36-40)
	for r in [logo, roll, footer]:
		if (r as Roll).active:
			(r as Roll).move(inc)

# --- glisser (TouchGestures, CreditsScene.cs:143-171) ---------------------------------------

func _gui_input(event: InputEvent) -> void:
	if not touch_on:
		return
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		dragging = event.pressed
		for r in [logo, roll, footer]:
			(r as Roll).active = not dragging # TouchPressed : tout s'arrete ; TouchReleased : tout repart
		accept_event()
	elif event is InputEventMouseMotion and dragging:
		var num: float = -(event as InputEventMouseMotion).relative.y # DeltaTranslation.Y x -1
		if logo.node.position.y < DRAG_DOWN_MAX_LOGO_Y or num > 0.0:
			for r in [logo, roll, footer]:
				(r as Roll).move(num)
		accept_event()

# --- donnees ---------------------------------------------------------------------------------

## credits.json : cles a casse variable ("Width" / "width") ; Newtonsoft les lit sans tenir compte de la casse.
static func ci(d: Dictionary, key: String) -> Variant:
	for k in d:
		if str(k).to_lower() == key.to_lower():
			return d[k]
	return null

static func load_data() -> Dictionary:
	var txt := FileAccess.get_file_as_string(DATA).trim_prefix("﻿")
	var parsed = JSON.parse_string(txt)
	return parsed if parsed is Dictionary else {}

## Atlas.Gradients / InGameGUI / Common (CreditsScene.cs:57,194,214) : les trois atlas sont ranges en dossiers sous assets/ui/.
func _tex(atlas_name: String) -> Texture2D:
	for dir in ["gradients", "ingame", "navigation", "buttons"]:
		var p := "%s%s/%s.webp" % [UI, dir, atlas_name]
		if ResourceLoader.exists(p):
			return load(p)
	return null

func _anchor(node_name: String, y: float) -> Control:
	var c := Control.new()
	c.name = node_name
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.position = Vector2(0, y)
	add_child(c)
	return c

## Image centree en (cx_apk ; cy) dans le repere de `parent` (Origin = Vector2.Center, taille native du sprite).
func _image(parent: Control, atlas_name: String, cx_apk: float, cy: float) -> void:
	var t := _tex(atlas_name)
	if t == null:
		return
	var r := TextureRect.new()
	r.texture = t
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.position = Vector2(cx_apk + DX, cy) - t.get_size() / 2.0
	parent.add_child(r)

func _build_logo(data: Dictionary) -> void:
	var lg: Variant = ci(data, "Logo")
	logo.node = _anchor("Logo", LOGO_Y)
	if lg is Dictionary:
		_image(logo.node, str(ci(lg, "Path")), MIDDLE, 0.0) # CreditsScene.cs:62,67-73

## Un TextDrawableBlock : boite de largeur `w_apk` (avant echelle), texte centre dans la boite, echelle `scale` ; coin haut-gauche (x_apk ; y).
func _text(parent: Control, kind: String, text: String, x_apk: float, y: float, w_apk: float, scale: float, color: Color, wrap := false) -> void:
	var size := int(BASE * scale)
	var l := Label.new()
	l.name = kind
	l.set_meta("kind", kind)
	l.text = text.to_upper() # ToUpperInvariant (CreditsScene.cs:178,211,251,264)
	l.add_theme_font_override("font", _font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var x := x_apk + DX
	if wrap:
		# TextWrapping + LineSpacing 8 (CreditsScene.cs:177-180) : le C# ajoute une espace apres chaque mot, y compris le dernier, avant de centrer la ligne
		# (TextControl.UpdateSize : text5 = $"{stringBuilder2}{text4} ") ; la ligne visible est donc decalee de la moitie d'une espace vers la gauche.
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.add_theme_constant_override("line_spacing", 0) # pas de ligne de l'APK : (FontHeight + LineSpacing 8) x 1,4 = 40 px (mesure sur flow_02_build.png) ; arcadepix 29 fait deja 40 px de haut dans Godot
		x -= _font.get_string_size(" ", HORIZONTAL_ALIGNMENT_LEFT, -1, size).x / 2.0
	l.position = Vector2(x, y + TEXT_DY)
	l.custom_minimum_size.x = w_apk * scale
	l.size.x = w_apk * scale
	parent.add_child(l)

## H2 / noms : CreateArcadepixTB(currentPosition.X = 0, ...), Width 1090, echelle 1,3, centres dans la boite (la boite part de x = 0 : axe = 1090 x 1,3 / 2 = 708,5 ; mesure sur la frame APK : ~949).
func _line(parent: Control, kind: String, text: String, y: float, color: Color) -> void:
	_text(parent, kind, text, 0.0, y, W, TXT_SCALE, color)

func _build_roll(data: Dictionary) -> void:
	roll.node = _anchor("Roll", ROLL_Y0)
	var y := 0.0
	for e in (ci(data, "Element") as Array):
		var el: Dictionary = e
		var sep: Variant = ci(el, "SeparatorImg")
		if sep is Dictionary: # AddSeparatorImg : centre (middle - 10 ; y + Height / 2), puis y += Height (CreditsScene.cs:192-203)
			var sh := float(ci(sep, "Height"))
			_image(roll.node, str(ci(sep, "Path")), MIDDLE + SEP_DX, y + sh / 2.0)
			y += sh
		var h1: Variant = ci(el, "H1")
		if h1 != null: # AddH1 (CreditsScene.cs:173-190)
			_text(roll.node, "h1", str(h1), H1_X, y, H1_W, H1_SCALE, Color.WHITE, true)
			y += H1_Y_OFFSET
			if str(h1).length() > 40:
				y += floorf(H1_Y_OFFSET / 2.0)
		var paras: Variant = ci(el, "Paragraph")
		if paras is Array: # AddParagraph (CreditsScene.cs:242-297)
			for p in (paras as Array):
				var h2: Variant = ci(p, "H2")
				if h2 != null:
					_line(roll.node, "h2", str(h2), y, PISTACHIO)
					y += Y_OFFSET
				var names: Variant = ci(p, "Names")
				if names is Array:
					for n in (names as Array):
						if str(n) != "": # un nom vide garde son interligne (TextDrawableBlock vide)
							_line(roll.node, "name", str(n), y, Color.WHITE)
						y += Y_OFFSET
			y += Y_OFFSET # fin du paragraphe
	roll.node.set_meta("end_y", y)

func _build_footer(data: Dictionary) -> void:
	footer.node = _anchor("Footer", FOOT_Y0)
	var ft: Variant = ci(data, "Footer")
	if not (ft is Dictionary):
		return
	var y := 0.0
	var h2: Variant = ci(ft, "H2")
	if h2 != null: # AddFooter (CreditsScene.cs:205-240)
		_line(footer.node, "h2", str(h2), y, PISTACHIO)
		y += Y_OFFSET
	var img: Variant = ci(ft, "Img")
	if img is Dictionary:
		var iw := float(ci(img, "Width"))
		var ih := float(ci(img, "Height"))
		_image(footer.node, str(ci(img, "Path")), MIDDLE - floorf(iw / 2.0), y + ih / 2.0) # x = middle - Width / 2 (centre du sprite, CreditsScene.cs:223) : 700
