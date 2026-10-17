class_name DungeonSlot
extends Control
## Emplacement de salle dans le donjon (5 emplacements par boss).

const GameManager = preload("res://godot/scripts/GameManager.gd")
const BossEngine = preload("res://godot/scripts/BossEngine.gd")
## Gère la réception du drag-and-drop de cartes depuis la main.

signal room_dropped(hand_index: int, slot_index: int) ## emis APRES une construction reussie
signal activate_requested(slot_index: int)
signal zoom_on(card: Control)  ## appui long sur la salle : zoom (BoardUI)
signal zoom_off

@export var slot_index: int = 0
var game_manager: GameManager
var player_id: int = 0
var current_stack: Array = []
var activatable := false
var _was_down := false                  # la salle du dessus etait face cachee au dernier affichage : si elle ne l'est plus, elle se retourne (CardUI.flip_in)
var _glow: Control
const PEEK := 28.0                       # APK : la salle recouverte depasse de ~28 px au-dessus de la salle du dessus (1920x1080)
const MAX_PEEK := 2                      # nombre de salles recouvertes dessinees

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
	for c in get_children():
		if c.is_in_group("under_card"):
			remove_child(c)
			c.queue_free()

	var active_room = BossEngine.active_room(current_stack) if not current_stack.is_empty() else null
	if active_room != null:
		if slot_frame:
			slot_frame.visible = false
		var card_ui = _card_ui_scene.instantiate()
		card_ui.default_size = custom_minimum_size
		card_container.add_child(card_ui)
		card_ui.is_in_hand = false
		card_ui.setup(active_room)
		card_ui.add_lane_badge()
		card_ui.mouse_filter = Control.MOUSE_FILTER_PASS # le clic atteint l'emplacement (capacite de la salle)
		card_ui.long_pressed.connect(func(c): zoom_on.emit(c))
		card_ui.long_released.connect(func(_c): zoom_off.emit())
		card_ui.set_frozen(game_manager != null and BossEngine.is_room_deactivated(game_manager.G, player_id, slot_index))
		card_ui.set_face_down_scale()
		var down: bool = card_ui.card_data != null and card_ui.card_data.face_down
		if _was_down and not down and DisplayServer.get_name() != "headless":
			card_ui.flip_in()
		_was_down = down
		add_under_cards(self, current_stack, _card_ui_scene, custom_minimum_size, card_container.get_index())
		if border:
			border.border_color = Color(0.4, 0.8, 0.4, 0.0) # pas de liseré : seul le halo d'une salle activable est visible
		tooltip_text = str(active_room.get("name", ""))
		if game_manager != null and Minibosses.active(game_manager.G): # Rise of the Minibosses : le miniboss attache a la salle, avec son niveau
			var badge := Minibosses.make_badge(active_room, true)
			if badge != null:
				add_child(badge)
				tooltip_text += "\n" + Minibosses.badge_tooltip(active_room, true)
	else:
		_was_down = false
		if slot_frame:
			slot_frame.visible = true
		if border:
			border.border_color = Color(0.5, 0.45, 0.35, 0.4)
		tooltip_text = ""
	_update_glow()

## Salles recouvertes d'une pile (une salle avancee construite sur une autre) : comme l'APK, la plus ancienne depasse de PEEK px
## au-dessus de celle du dessus (son bandeau de titre reste lisible). `at` : rang d'insertion dans `host` (derriere la salle du dessus).
static func add_under_cards(host: Control, stack: Array, card_scene: PackedScene, sz: Vector2, at: int = -1) -> void:
	var older := mini(stack.size() - 1, MAX_PEEK)
	for k in range(older, 0, -1): # la plus profonde d'abord (au fond)
		var c: CardUI = card_scene.instantiate()
		c.default_size = sz
		c.add_to_group("under_card")
		host.add_child(c)
		c.size = sz
		c.position = Vector2(0, -PEEK * k * sz.y / 175.0)
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		c.is_in_hand = false
		c.setup(stack[stack.size() - 1 - k])
		c.add_lane_badge()
		var badge := c.get_node_or_null("TypeBadge")
		if badge != null:
			badge.modulate = Color(0.6, 0.6, 0.6) # APK : pastille de la salle recouverte assombrie
		if at >= 0:
			host.move_child(c, at + (older - k))

## BoardUI l'allume quand la salle a un coup activateRoom legal pour le joueur affiche (halo vert pulse, comme l'APK).
func set_activatable(on: bool) -> void:
	activatable = on
	_update_glow()

## Halo de capacite de l'APK (CardAttributesComponent.UpdateRoomAbilityBorder) : cadre fixe card_border_ability_glow sur la zone de texte
## (a 116/488 sous le centre de la carte) + 3 anneaux card_border_ability_pulse qui grossissent (x1 -> x1,4) en s'estompant sur 2 s,
## decales de 0,3 s, relances toutes les 3 s.
func _update_glow() -> void:
	var show_it := activatable and not current_stack.is_empty()
	tooltip_text = tooltip_text.replace("
Click to use its ability", "")
	if _glow == null:
		if not show_it:
			return
		_glow = Control.new()
		_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var k := Vector2(custom_minimum_size.x / 350.0, custom_minimum_size.y / 488.0) # la carte APK fait 350x488 a l'echelle 1
		var sz := Vector2(306, 102) * k
		var centre := custom_minimum_size / 2.0 + Vector2(0, 116.0 * k.y)
		_glow.position = centre - sz / 2.0
		_glow.size = sz
		add_child(_glow)
		var base := _glow_tex("card_border_ability_glow", sz)
		_glow.add_child(base)
		for r in 3:
			var ring := _glow_tex("card_border_ability_pulse", sz)
			ring.pivot_offset = sz / 2.0
			ring.modulate.a = 0.0
			_glow.add_child(ring)
			var tw := ring.create_tween().set_loops()
			tw.tween_interval(0.3 * r)
			tw.set_parallel(true)
			tw.chain().tween_property(ring, "scale", Vector2(1.4, 1.4), 2.0).from(Vector2.ONE).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			tw.tween_property(ring, "modulate:a", 0.0, 2.0).from(1.0).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			tw.chain().tween_interval(1.0 - 0.3 * r)
	_glow.visible = show_it
	if show_it and not tooltip_text.contains("Click"):
		tooltip_text += "
Click to use its ability"

func _glow_tex(name: String, sz: Vector2) -> TextureRect:
	var t := TextureRect.new()
	t.texture = load("res://assets/ui/ingame/%s.webp" % name)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_SCALE
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.size = sz
	return t

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

## Coup de construction que le moteur propose pour (carte de la main -> cet emplacement) : [i, cible] pour une salle avancee ou une
## salle ordinaire sur un donjon plein, sinon [i] (salle ordinaire posee a l'entree du donjon). {} si aucun.
## (GameManager.build_room_at ne sait emettre que [i] pour une salle ordinaire : le depot sur un donjon plein etait refuse.)
func _drop_move(hand_idx: int) -> Dictionary:
	var fallback := {}
	for m in game_manager.legal_moves(player_id):
		if str((m as Dictionary).get("type", "")) != "buildRoom":
			continue
		var a: Array = (m as Dictionary).get("args", [])
		if a.is_empty() or int(a[0]) != hand_idx:
			continue
		if a.size() > 1 and a[1] != null:
			if int(a[1]) == slot_index:
				return m
		else:
			fallback = m
	return fallback

## Réceptionne le drop et effectue la construction
func _drop_data(_at_position: Vector2, data) -> void:
	if not _can_drop_data(_at_position, data):
		return
	var hand_idx = int(data.get("hand_index", -1))
	var mv := _drop_move(hand_idx)
	if mv.is_empty() or not game_manager.apply_move(player_id, mv):
		return
	room_dropped.emit(hand_idx, slot_index) # BoardUI rafraichit l'ecran (apply_move n'emet pas toujours state_changed en fin de coup)

	# Feedback visuel fluide (flash vert)
	if border:
		var orig_col = border.border_color
		border.border_color = Color(0.2, 1.0, 0.3, 1.0)
		var t = create_tween()
		t.tween_property(border, "border_color", orig_col, 0.4)
