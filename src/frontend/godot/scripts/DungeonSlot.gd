class_name DungeonSlot
extends Control
## Emplacement de salle dans le donjon (5 emplacements par boss).

const GameManager = preload("res://godot/scripts/GameManager.gd")
const BossEngine = preload("res://godot/scripts/BossEngine.gd")
## Gère la réception du drag-and-drop de cartes depuis la main.

signal room_dropped(hand_index: int, slot_index: int)
signal activate_requested(slot_index: int)

@export var slot_index: int = 0
var game_manager: GameManager
var player_id: int = 0
var current_stack: Array = []
var activatable := false
var _glow: TextureRect

@onready var slot_frame: TextureRect = $SlotFrame
@onready var slot_label: Label = $SlotLabel
@onready var card_container: CenterContainer = $CardContainer
@onready var border: ReferenceRect = $Border

var _card_ui_scene = preload("res://godot/scenes/Card.tscn")

func _ready() -> void:
	custom_minimum_size = Vector2(127, 175)
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
		slot_label.visible = false # l'APK n'ecrit pas « Room N » sur les emplacements

	for child in card_container.get_children():
		child.queue_free()
	var old_badge := get_node_or_null("MbBadge")
	if old_badge != null:
		remove_child(old_badge)
		old_badge.queue_free()

	var active_room = BossEngine.active_room(current_stack) if not current_stack.is_empty() else null
	if active_room != null:
		if slot_frame:
			slot_frame.visible = false
		var card_ui = _card_ui_scene.instantiate()
		card_ui.default_size = custom_minimum_size
		card_container.add_child(card_ui)
		card_ui.is_in_hand = false
		card_ui.setup(active_room)
		if border:
			border.border_color = Color(0.4, 0.8, 0.4, 0.0) # pas de liseré : seul le halo d'une salle activable est visible
		tooltip_text = str(active_room.get("name", ""))
		if game_manager != null and Minibosses.active(game_manager.G): # Rise of the Minibosses : le miniboss attache a la salle, avec son niveau
			var badge := Minibosses.make_badge(active_room, true)
			if badge != null:
				add_child(badge)
				tooltip_text += "\n" + Minibosses.badge_tooltip(active_room, true)
	else:
		if slot_frame:
			slot_frame.visible = true
		if border:
			border.border_color = Color(0.5, 0.45, 0.35, 0.4)
		tooltip_text = ""
	_update_glow()

## BoardUI l'allume quand la salle a un coup activateRoom legal pour le joueur affiche (halo vert pulse, comme l'APK).
func set_activatable(on: bool) -> void:
	activatable = on
	_update_glow()

func _update_glow() -> void:
	var show_it := activatable and not current_stack.is_empty()
	tooltip_text = tooltip_text.replace("
Click to use its ability", "")
	if _glow == null:
		if not show_it:
			return
		_glow = TextureRect.new()
		_glow.texture = load("res://assets/ui/ingame/card_border_ability_pulse.webp")
		_glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_glow.stretch_mode = TextureRect.STRETCH_SCALE
		_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_glow.position = Vector2(-4, 96)
		_glow.size = Vector2(custom_minimum_size.x + 8, 60)
		add_child(_glow)
		var tw := _glow.create_tween().set_loops()
		tw.tween_property(_glow, "modulate:a", 0.4, 0.6).set_trans(Tween.TRANS_SINE)
		tw.tween_property(_glow, "modulate:a", 1.0, 0.6).set_trans(Tween.TRANS_SINE)
	_glow.visible = show_it
	if show_it and not tooltip_text.contains("Click"):
		tooltip_text += "\nClick to use its ability"

func _gui_input(event: InputEvent) -> void:
	# Clic (gauche ou droit) sur une salle activable : BoardUI choisit le coup (et la cible s'il y en a plusieurs).
	if event is InputEventMouseButton and event.pressed and activatable \
			and (event.button_index == MOUSE_BUTTON_LEFT or event.button_index == MOUSE_BUTTON_RIGHT) and not current_stack.is_empty():
		accept_event()
		activate_requested.emit(slot_index)

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
