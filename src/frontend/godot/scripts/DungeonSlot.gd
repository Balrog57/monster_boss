class_name DungeonSlot
extends Control
## Emplacement de salle dans le donjon (5 emplacements par boss).

const GameManager = preload("res://godot/scripts/GameManager.gd")
const BossEngine = preload("res://godot/scripts/BossEngine.gd")
## Gère la réception du drag-and-drop de cartes depuis la main.

signal room_dropped(hand_index: int, slot_index: int)

@export var slot_index: int = 0
var game_manager: GameManager
var player_id: int = 0
var current_stack: Array = []

@onready var background: ColorRect = $Background
@onready var slot_label: Label = $SlotLabel
@onready var card_container: CenterContainer = $CardContainer
@onready var border: ReferenceRect = $Border

var _card_ui_scene = preload("res://godot/scenes/Card.tscn")

func _ready() -> void:
	custom_minimum_size = Vector2(145, 205)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_update_view()

func setup(p_gm: GameManager, p_slot_idx: int, p_pid: int = 0) -> void:
	game_manager = p_gm
	slot_index = p_slot_idx
	player_id = p_pid
	_update_view()

func set_stack(stack: Array) -> void:
	current_stack = stack
	_update_view()

func _update_view() -> void:
	if not is_inside_tree():
		return
	if slot_label:
		slot_label.text = "Salle %d" % (slot_index + 1)
	
	for child in card_container.get_children():
		child.queue_free()

	var active_room = BossEngine.active_room(current_stack) if not current_stack.is_empty() else null
	if active_room != null:
		var card_ui = _card_ui_scene.instantiate()
		card_container.add_child(card_ui)
		card_ui.is_in_hand = false
		card_ui.setup(active_room)
		if border:
			border.border_color = Color(0.4, 0.8, 0.4, 0.9)
	else:
		if border:
			border.border_color = Color(0.4, 0.4, 0.5, 0.5)

## Vérifie si la carte draguée peut être posée sur cet emplacement
func _can_drop_data(_at_position: Vector2, data) -> bool:
	if not (data is Dictionary) or data.get("type") != "card":
		return false
	if game_manager == null:
		return false
	var hand_idx = int(data.get("hand_index", -1))
	return game_manager.can_build_room_at(player_id, hand_idx, slot_index)

## Réceptionne le drop et effectue la construction
func _drop_data(_at_position: Vector2, data) -> void:
	if not _can_drop_data(_at_position, data):
		return
	var hand_idx = int(data.get("hand_index", -1))
	room_dropped.emit(hand_idx, slot_index)
	game_manager.build_room_at(player_id, hand_idx, slot_index)
	
	# Feedback visuel fluide (flash vert)
	if border:
		var orig_col = border.border_color
		border.border_color = Color(0.2, 1.0, 0.3, 1.0)
		var t = create_tween()
		t.tween_property(border, "border_color", orig_col, 0.4)
