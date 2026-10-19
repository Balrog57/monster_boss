class_name RulesViewer
extends Control
## Visionneuse des regles : les livrets officiels Brotherwise (assets/rules/<livre>/pNN.webp, generes par tools/render_rules_pages.py), un onglet par livret.
## Partagee par le menu principal (plein ecran) et le plateau (superposee, sans detruire la partie).
## Se ferme en emettant `closed` puis en se liberant (sauf `free_on_close` = false : l'hote la libere, Main la garde sous le ColorFade jusqu'au changement d'ecran).

signal closed

const UI := "res://assets/ui/"
const FONT_A := "res://assets/fonts/arcadepix.fnt"
const GOLD := Color("cdb15f")
const BOOKS := [["base", "BOSS MONSTER"], ["next-level", "THE NEXT LEVEL"], ["minibosses", "RISE OF THE MINIBOSSES"], ["crash-landing", "CRASH LANDING"]]

var tab := 0
var free_on_close := true
var page := 0 # page courante (0 = premiere) ; reinitialisee au changement d'onglet
var page_count := 0 # pages du livret de l'onglet courant

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
	top.size = Vector2(1920, 128)
	add_child(top)
	var back := TextureButton.new() # fleche verte de tous les ecrans du menu : back_bt a (20, 22), son ui_button_goback (MainMenuScene.cs:49-54)
	back.texture_normal = load(UI + "buttons/back_bt.webp")
	back.texture_pressed = load(UI + "buttons/back_bt_pressed.webp")
	back.position = Vector2(20, 22)
	back.pressed.connect(func():
		AudioManager.play_sfx("ui_button_goback")
		close_viewer())
	add_child(back)
	add_child(_lbl("RULES", 42, GOLD, Vector2(0, 22), Vector2(1920, 98))) # titre arcadepix x2 = 42, or #cdb15f, centre : ne chevauche pas la fleche (x 20-141)
	tab = clampi(tab, 0, BOOKS.size() - 1)
	var tw := minf(470.0, 1880.0 / BOOKS.size())
	for i in BOOKS.size():
		var x := int(20 + tw * i)
		var r := ColorRect.new()
		r.color = GOLD if i == tab else Color(0.16, 0.12, 0.2)
		r.position = Vector2(x, 136)
		r.size = Vector2(tw - 10, 46)
		add_child(r)
		add_child(_lbl(str(BOOKS[i][1]), 21, Color.BLACK if i == tab else GOLD, Vector2(x, 136), Vector2(tw - 10, 46)))
		var hit := Button.new()
		for n in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
			hit.add_theme_stylebox_override(n, StyleBoxEmpty.new())
		hit.focus_mode = Control.FOCUS_NONE
		hit.position = Vector2(x, 136)
		hit.size = Vector2(tw - 10, 46)
		var idx := i
		hit.pressed.connect(func():
			AudioManager.play_sfx("ui_button_select")
			tab = idx
			page = 0
			_build())
		add_child(hit)
	var panel := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.2, 0.14, 0.22)
	sb.border_color = GOLD
	sb.set_border_width_all(4)
	sb.set_corner_radius_all(26)
	panel.add_theme_stylebox_override("panel", sb)
	panel.position = Vector2(10, 192)
	panel.size = Vector2(1900, 878)
	add_child(panel)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var files := _page_files(str(BOOKS[tab][0]))
	page_count = files.size()
	page = clampi(page, 0, maxi(page_count - 1, 0))
	if page_count == 0:
		return
	var pg := TextureRect.new() # une seule page chargee a la fois (livret) : ratio conserve, la plus grande qui tienne dans le panneau
	pg.texture = load("res://assets/rules/%s/%s" % [BOOKS[tab][0], files[page]])
	pg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pg.position = Vector2(170, 200)
	pg.size = Vector2(1580, 818)
	pg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(pg)
	add_child(_lbl("%d / %d" % [page + 1, page_count], 24, GOLD, Vector2(710, 1026), Vector2(500, 40)))
	if page > 0:
		add_child(_arrow(false, Vector2(30, 582)))
	if page < page_count - 1:
		add_child(_arrow(true, Vector2(1769, 582)))

func _arrow(next: bool, pos: Vector2) -> TextureButton:
	var b := TextureButton.new()
	b.texture_normal = load(UI + "buttons/back_bt.webp") # fleche « retour » de l'APK, retournee pour « suivant »
	b.texture_pressed = load(UI + "buttons/back_bt_pressed.webp")
	b.flip_h = next
	b.position = pos
	b.pressed.connect(func(): turn(1 if next else -1))
	return b

func turn(d: int) -> void:
	var np := clampi(page + d, 0, page_count - 1)
	if np == page:
		return
	AudioManager.play_sfx("ui_button_select")
	page = np
	_build()

var _press := Vector2.ZERO

func _input(e: InputEvent) -> void: # fleches clavier, molette, glisse horizontal : tournent les pages
	if e is InputEventKey and e.pressed and not e.echo and (e.keycode == KEY_LEFT or e.keycode == KEY_RIGHT):
		turn(1 if e.keycode == KEY_RIGHT else -1)
		get_viewport().set_input_as_handled()
	elif e is InputEventMouseButton and e.pressed and (e.button_index == MOUSE_BUTTON_WHEEL_UP or e.button_index == MOUSE_BUTTON_WHEEL_DOWN):
		turn(1 if e.button_index == MOUSE_BUTTON_WHEEL_DOWN else -1)
		get_viewport().set_input_as_handled()
	elif e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		if e.pressed:
			_press = e.position
		else:
			var d: Vector2 = e.position - _press
			if absf(d.x) > 150 and absf(d.x) > 2 * absf(d.y):
				turn(-1 if d.x > 0 else 1)

## pNN.webp du dossier, tries. ResourceLoader.list_directory rend les noms d'origine aussi dans un export (pas de .import/.remap).
static func _page_files(book: String) -> PackedStringArray:
	var out := PackedStringArray()
	for f in ResourceLoader.list_directory("res://assets/rules/" + book):
		if f.ends_with(".webp"):
			out.append(f)
	out.sort()
	return out

func close_viewer() -> void:
	closed.emit()
	if free_on_close:
		queue_free()

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
