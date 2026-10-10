class_name CardUI
extends Control
## Composant visuel d'une carte Boss Monster (Card.tscn).
## Gère l'affichage (TextureRect + Labels), le zoom au survol et le drag-and-drop.

signal card_clicked(card_data: CardData)
signal card_hovered(card_data: CardData, is_hovered: bool)

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

var _tween: Tween

func _ready() -> void:
	custom_minimum_size = default_size
	pivot_offset = default_size / 2.0
	mouse_filter = Control.MOUSE_FILTER_STOP
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
	
	if title_label:
		title_label.text = card_data.title
	
	if stat_label:
		if card_data.card_type == "room":
			stat_label.text = "%d DMG" % card_data.damage
			if card_data.is_advanced:
				stat_label.text += " (Adv)"
		elif card_data.card_type == "hero":
			stat_label.text = "%d PV" % card_data.health
		elif card_data.card_type == "boss":
			stat_label.text = "%d XP" % card_data.xp
		elif card_data.card_type == "spell":
			stat_label.text = "SORT"
		else:
			stat_label.text = ""

	if texture_rect:
		if card_data.texture:
			texture_rect.texture = card_data.texture
		elif card_data.texture_path != "" and ResourceLoader.exists(card_data.texture_path):
			texture_rect.texture = load(card_data.texture_path)

func _on_mouse_entered() -> void:
	z_index = 20
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "scale", Vector2.ONE * hover_scale, hover_duration)
	card_hovered.emit(card_data, true)

func _on_mouse_exited() -> void:
	z_index = 0
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "scale", Vector2.ONE, hover_duration)
	card_hovered.emit(card_data, false)

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		card_clicked.emit(card_data)

## Drag-and-drop Godot : retourne les données de drag si la carte est jouable depuis la main
func _get_drag_data(_at_position: Vector2):
	if not is_in_hand or hand_index < 0:
		return null

	var preview := Control.new()
	preview.custom_minimum_size = default_size
	
	var preview_tex := TextureRect.new()
	preview_tex.custom_minimum_size = default_size
	preview_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if texture_rect and texture_rect.texture:
		preview_tex.texture = texture_rect.texture
	preview.add_child(preview_tex)
	
	var preview_lbl := Label.new()
	preview_lbl.text = card_data.title if card_data else ""
	preview_lbl.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	preview_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	preview.add_child(preview_lbl)
	
	preview.modulate = Color(1, 1, 1, 0.8)
	set_drag_preview(preview)

	return {
		"type": "card",
		"hand_index": hand_index,
		"card_data": card_data,
		"card_dict": card_dict
	}
