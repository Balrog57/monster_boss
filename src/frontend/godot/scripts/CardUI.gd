class_name CardUI
extends Control
## Composant visuel d'une carte Boss Monster (Card.tscn).

const CardData = preload("res://godot/scripts/CardData.gd")
## Gère l'affichage (TextureRect + Labels), le zoom au survol et le drag-and-drop.

signal card_clicked(card_data: CardData)
signal card_hovered(card_data: CardData, is_hovered: bool)
signal press_started(card: Control, at: Vector2) ## bouton gauche enfonce sur la carte (BoardUI arme le glisser-deposer)
signal long_pressed(card: Control)        ## appui long (~0,8 s sans bouger) ou clic droit maintenu : zoom de la carte
signal long_released(card: Control)       ## fin du maintien : le zoom se ferme

@export var default_size := Vector2(140, 200)
@export var hover_scale := 1.15
@export var hover_duration := 0.15

var card_data: CardData
var card_dict: Dictionary = {}
var hand_index: int = -1
var is_in_hand: bool = true

@onready var texture_rect: TextureRect = $TextureRect
@onready var title_label: Label = $TitleLabel
@onready var stat_label: Label = $StatLabel
@onready var border: ReferenceRect = $Border
@onready var glow_rect: TextureRect = get_node_or_null("GlowRect")

const LONG_PRESS_TIME := 0.8             # APK : appui long ~1 s ; CLICK_SLOP : en dessous, c'est un clic (au relachement)
const CLICK_SLOP := 12.0

var suppress_click := false               # BoardUI l'active quand un glisser a commence : le relachement n'est pas un clic
var _pressed := false
var _long := false
var _press_pos := Vector2.ZERO
var _press_id := 0
var _tween: Tween
var _rest_scale := Vector2.ONE             # echelle au repos (dos de carte pose en salle : voir set_face_down_scale)
var _gold: TextureRect
var _frozen: TextureRect
static var _gray_mat: ShaderMaterial

## Carte injouable : desaturee (l'APK grise les cartes que l'on ne peut pas jouer maintenant).
func set_greyed(on: bool) -> void:
	if _gray_mat == null:
		var sh := Shader.new()
		sh.code = "shader_type canvas_item;
void fragment() { vec4 c = texture(TEXTURE, UV); float g = dot(c.rgb, vec3(0.3, 0.59, 0.11)) * 0.62; COLOR = vec4(vec3(g), c.a); }"
		_gray_mat = ShaderMaterial.new()
		_gray_mat.shader = sh
	if texture_rect == null:
		texture_rect = get_node_or_null("TextureRect")
	if texture_rect != null:
		texture_rect.material = _gray_mat if on else null

## Cadre dore de l'APK (sort jouable pendant l'aventure) : card_border_yellow (354x492 pour une carte de 350x488).
func set_gold(on: bool) -> void:
	if on and _gold == null:
		_gold = TextureRect.new()
		_gold.texture = load("res://assets/ui/ingame/card_border_yellow.webp")
		_gold.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_gold.stretch_mode = TextureRect.STRETCH_SCALE
		_gold.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_gold.name = "GoldFrame"
		var k := Vector2(size.x / 350.0, size.y / 488.0) if size.x > 0.0 else Vector2.ONE
		_gold.position = Vector2(-2, -2) * k
		_gold.size = Vector2(354, 492) * k
		add_child(_gold)
	if _gold != null:
		_gold.visible = on

## APK : une salle posee face cachee est le dos de carte a l'echelle 0,5 de la main (175 x 244), plus grand que l'emplacement (127 x 175) ;
## elle est centree sur l'emplacement et retrouve la taille de l'emplacement une fois retournee.
func set_face_down_scale() -> void:
	var down: bool = card_data != null and card_data.face_down
	_rest_scale = Vector2(175.0 / 127.0, 244.0 / 175.0) if down else Vector2.ONE
	scale = _rest_scale

## Gel de l'APK (Freeze) : voile de glace (frozzen_card) par-dessus la salle.
func set_frozen(on: bool) -> void:
	if on and _frozen == null:
		_frozen = TextureRect.new()
		_frozen.texture = load("res://assets/ui/ingame/frozzen_card.webp")
		_frozen.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_frozen.stretch_mode = TextureRect.STRETCH_SCALE
		_frozen.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_frozen.name = "Frozen"
		var k := default_size.x / 127.0
		_frozen.position = Vector2(-6, -6) * k
		_frozen.size = default_size + Vector2(12, 12) * k
		add_child(_frozen)
	if _frozen != null:
		_frozen.visible = on

func _ready() -> void:
	custom_minimum_size = default_size
	pivot_offset = default_size / 2.0
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_process_input(false) # active seulement pendant un appui (voir _on_gui_input)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	gui_input.connect(_on_gui_input)

func setup(data, p_hand_index: int = -1) -> void:
	hand_index = p_hand_index
	if data is CardData:
		card_data = data
	elif data is Dictionary:
		card_dict = data
		card_data = CardData.from_dict(data)

	if not is_inside_tree():
		await ready

	_update_view()

func _update_view() -> void:
	if card_data == null:
		return
	
	var has_tex: bool = false
	if texture_rect:
		if card_data.texture:
			texture_rect.texture = card_data.texture
			has_tex = true
		elif card_data.texture_path != "" and ResourceLoader.exists(card_data.texture_path):
			texture_rect.texture = load(card_data.texture_path)
			has_tex = true

	if card_data.face_down:
		if title_label:
			title_label.visible = false
		if stat_label:
			stat_label.visible = false
		tooltip_text = "Face-down Room"
		return

	if title_label:
		title_label.visible = not has_tex
		title_label.text = card_data.title
	
	if stat_label:
		stat_label.visible = not has_tex
		if card_data.card_type == "room":
			stat_label.text = "%d DMG" % card_data.damage
			if card_data.is_advanced:
				stat_label.text += " (ADV)"
		elif card_data.card_type == "hero":
			stat_label.text = "%d HP" % card_data.health
		elif card_data.card_type == "boss":
			stat_label.text = "%d XP" % card_data.xp
		elif card_data.card_type == "spell":
			stat_label.text = "SPELL"
		else:
			stat_label.text = ""

## Pastille ronde de type de salle posee sur le coin haut-gauche des salles des couloirs (APK : monstre / pieges, doree = avancee).
func add_lane_badge() -> void:
	if card_data == null or card_data.face_down or not (card_data.card_type in ["monster", "trap"]):
		return
	var tex_path := "res://assets/ui/ingame/room_icon_%s%s.webp" % ["advanced_" if card_data.is_advanced else "", card_data.card_type]
	if not ResourceLoader.exists(tex_path):
		return
	var k := default_size.x / 127.0
	var t := TextureRect.new()
	t.name = "TypeBadge"
	t.texture = load(tex_path)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_SCALE
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.position = Vector2(-9, -12) * k
	t.size = Vector2(39, 39) * k
	add_child(t)

func _on_mouse_entered() -> void:
	z_index = 20
	if glow_rect:
		glow_rect.visible = true
	if border:
		border.border_color = Color(1.0, 0.85, 0.2, 1.0)
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "scale", _rest_scale * hover_scale, hover_duration)
	card_hovered.emit(card_data, true)

func _on_mouse_exited() -> void:
	z_index = 0
	if glow_rect:
		glow_rect.visible = false
	if border:
		border.border_color = Color(0.4, 0.4, 0.5, 0.5)
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "scale", _rest_scale, hover_duration)
	card_hovered.emit(card_data, false)

func _on_gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
		_pressed = true
		_long = false
		suppress_click = false
		_press_pos = mb.global_position
		_press_id += 1
		set_process_input(true)
		press_started.emit(self, _press_pos)
		var id := _press_id
		get_tree().create_timer(LONG_PRESS_TIME).timeout.connect(func():
			if _pressed and id == _press_id and not suppress_click and not _long:
				_long = true
				long_pressed.emit(self))
	elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed and not _long and not _pressed:
		_long = true
		set_process_input(true)
		long_pressed.emit(self)

## Relachement ou deplacement vus meme hors de la carte (le glisser la quitte) : un clic = relachement sans glisser ni appui long.
func _input(event: InputEvent) -> void:
	if not _pressed and not _long:
		set_process_input(false)
		return
	if event is InputEventMouseMotion:
		if _pressed and (event as InputEventMouseMotion).global_position.distance_to(_press_pos) >= CLICK_SLOP:
			suppress_click = true
	elif event is InputEventMouseButton and not (event as InputEventMouseButton).pressed:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and _pressed:
			var was_long := _long
			var moved := mb.global_position.distance_to(_press_pos) >= CLICK_SLOP
			_pressed = false
			_long = false
			set_process_input(false)
			if was_long:
				long_released.emit(self)
			elif not suppress_click and not moved:
				card_clicked.emit(card_data)
		elif mb.button_index == MOUSE_BUTTON_RIGHT and _long and not _pressed:
			_long = false
			set_process_input(false)
			long_released.emit(self)
