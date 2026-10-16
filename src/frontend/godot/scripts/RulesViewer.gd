class_name RulesViewer
extends Control
## Visionneuse des regles (godot/data/rules.txt), un onglet par section (titre en MAJUSCULES).
## Partagee par le menu principal (plein ecran) et le plateau (superposee, sans detruire la partie).
## Se ferme en emettant `closed` puis en se liberant.

signal closed

const UI := "res://assets/ui/"
const FONT_A := "res://assets/fonts/arcadepix.fnt"
const GOLD := Color("cdb15f")

var tab := 0

func _ready() -> void:
	size = Vector2(1920, 1080)
	mouse_filter = Control.MOUSE_FILTER_STOP # bloque les clics vers ce qui est dessous (le plateau)
	_build()

func _build() -> void:
	for c in get_children():
		remove_child(c)
		c.queue_free()
	var bg := ColorRect.new()
	bg.color = Color(0.11, 0.08, 0.15)
	bg.size = Vector2(1920, 1080)
	add_child(bg)
	var top := ColorRect.new()
	top.color = Color(0.18, 0.13, 0.22)
	top.size = Vector2(1920, 92)
	add_child(top)
	add_child(_tex("navigation/rules_icon.webp", Vector2(26, 14), Vector2(64, 64)))
	add_child(_lbl("RULES", 52, GOLD, Vector2(110, 6), Vector2(400, 80), HORIZONTAL_ALIGNMENT_LEFT))
	var close := TextureButton.new()
	close.texture_normal = load(UI + "expansions/close_panel.webp")
	close.texture_pressed = load(UI + "expansions/close_panel_pressed.webp")
	close.ignore_texture_size = true
	close.stretch_mode = TextureButton.STRETCH_SCALE
	close.position = Vector2(1810, 8)
	close.size = Vector2(70, 77)
	close.pressed.connect(func():
		AudioManager.play_sfx("ui_button_goback")
		close_viewer())
	add_child(close)
	var secs := sections()
	tab = clampi(tab, 0, secs.size() - 1)
	var tw := minf(235.0, 1880.0 / secs.size())
	for i in secs.size():
		var x := int(20 + tw * i)
		var r := ColorRect.new()
		r.color = GOLD if i == tab else Color(0.16, 0.12, 0.2)
		r.position = Vector2(x, 106)
		r.size = Vector2(tw - 10, 46)
		add_child(r)
		add_child(_lbl(str(secs[i][0]), 15, Color.BLACK if i == tab else GOLD, Vector2(x, 106), Vector2(tw - 10, 46)))
		var hit := Button.new()
		for n in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
			hit.add_theme_stylebox_override(n, StyleBoxEmpty.new())
		hit.focus_mode = Control.FOCUS_NONE
		hit.position = Vector2(x, 106)
		hit.size = Vector2(tw - 10, 46)
		var idx := i
		hit.pressed.connect(func():
			AudioManager.play_sfx("ui_button_select")
			tab = idx
			_build())
		add_child(hit)
	var panel := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.2, 0.14, 0.22)
	sb.border_color = GOLD
	sb.set_border_width_all(4)
	sb.set_corner_radius_all(26)
	panel.add_theme_stylebox_override("panel", sb)
	panel.position = Vector2(10, 166)
	panel.size = Vector2(1900, 904)
	add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(300, 190)
	scroll.size = Vector2(1320, 860)
	add_child(scroll)
	var body := Label.new()
	body.custom_minimum_size = Vector2(1300, 0)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_size_override("font_size", 24)
	body.text = str(secs[tab][1])
	scroll.add_child(body)

func close_viewer() -> void:
	closed.emit()
	queue_free()

func _tex(path: String, pos: Vector2, sz: Vector2) -> TextureRect:
	var t := TextureRect.new()
	t.texture = load(UI + path)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_SCALE
	t.size = sz
	t.position = pos
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t

func _lbl(text: String, font_size: int, color: Color, pos: Vector2, sz: Vector2, align: int = HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", load(FONT_A) as Font)
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = align as HorizontalAlignment
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.position = pos
	l.size = sz
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

## [[titre, texte], ...] : « INTRO » puis une section par ligne de titre (MAJUSCULES, precedee d'une ligne vide).
static func sections() -> Array:
	var lines := _load_text().split("\n")
	var secs: Array = [["INTRO", ""]]
	for i in lines.size():
		var t := lines[i].strip_edges()
		var letters := 0
		for ch in t:
			letters += 1 if ch.to_upper() != ch.to_lower() else 0
		if t != "" and t == t.to_upper() and letters >= 4 and (i == 0 or lines[i - 1].strip_edges() == ""):
			secs.append([t, ""])
		else:
			secs[-1][1] += lines[i] + "\n"
	return secs

static func _load_text() -> String:
	var f := FileAccess.open("res://godot/data/rules.txt", FileAccess.READ)
	if f == null:
		return "Rules not found (godot/data/rules.txt)."
	return f.get_as_text().replace("", "")
