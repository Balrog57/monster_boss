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
@export var hover_scale := 1.2 # CardPositionComponent.cs:35 (SelectedScale 1,2)

var card_data: CardData
var card_dict: Dictionary = {}
var hand_index: int = -1
var is_in_hand: bool = true

@onready var texture_rect: TextureRect = $TextureRect
@onready var title_label: Label = $TitleLabel
@onready var stat_label: Label = $StatLabel
@onready var border: ReferenceRect = $Border
@onready var glow_rect: TextureRect = get_node_or_null("GlowRect")

const LONG_PRESS_TIME := 1.0             # APK : appui long 1,0 s (CardCarrouselEntity.cs:124, LongTouchBehavior) ; CLICK_SLOP : en dessous, c'est un clic (au relachement)
const CLICK_SLOP := 12.0

var suppress_click := false               # BoardUI l'active quand un glisser a commence : le relachement n'est pas un clic
var _pressed := false
var _long := false
var _press_pos := Vector2.ZERO
var _press_id := 0
var _rest_scale := Vector2.ONE             # echelle au repos (dos de carte pose en salle : voir set_face_down_scale)
var _gold: TextureRect
var _frozen: TextureRect
var greyed := false                        # etat cible du grisage (le fondu peut etre en cours)
var _grey_tw: Tween
static var _gray_shader: Shader

## Carte injouable : desaturee + opacite 0,8 (l'APK grise les cartes que l'on ne peut pas jouer maintenant, CardAttributesComponent.cs:73-96).
## animate : fondu depuis l'etat oppose ; elapsed : secondes deja ecoulees (la main est reconstruite a chaque refresh, le fondu reprend a mi-course).
func set_greyed(on: bool, animate := false, elapsed := 0.0) -> void:
	if texture_rect == null:
		texture_rect = get_node_or_null("TextureRect")
	if texture_rect == null:
		return
	if _grey_tw != null:
		_grey_tw.kill()
		_grey_tw = null
	var was := greyed
	greyed = on
	var mat := texture_rect.material as ShaderMaterial
	if mat == null:
		if _gray_shader == null:
			_gray_shader = Shader.new()
			_gray_shader.code = "shader_type canvas_item;
uniform float amt = 0.0;
void fragment() { vec4 c = texture(TEXTURE, UV); float g = dot(c.rgb, vec3(0.3, 0.59, 0.11)) * 0.62; COLOR = vec4(mix(vec3(g), c.rgb, amt), c.a); }"
		mat = ShaderMaterial.new()
		mat.shader = _gray_shader
		texture_rect.material = mat
	if not animate or was == on:
		mat.set_shader_parameter("amt", 0.0 if on else 1.0)
		modulate.a = 0.8 if on else 1.0
		if not on:
			texture_rect.material = null
		return
	_grey_tw = create_tween()
	# tween_method sur le temps t (0 -> 0,5 s, repris a `elapsed`) : la courbe est exacte meme si la main est reconstruite en cours de fondu.
	# Amount : ColorFadeBehavior 0,5 s, CubicEase EaseOut appliquee a la progression (ColorFadeBehavior.cs:35,56) -> vers le gris 1 - f^3 (EASE_IN), vers la couleur 1 - (1-f)^3 (EASE_OUT).
	# Opacite : FadeBehavior 0,3 s lineaire (CardEntity.cs:69 ; FadeBehavior.cs:87), MinOpacity 0,8 (CardAttributesComponent.cs:83).
	_grey_tw.tween_method(func(t: float):
		var f := minf(t / 0.5, 1.0)
		mat.set_shader_parameter("amt", 1.0 - pow(f, 3.0) if on else 1.0 - pow(1.0 - f, 3.0))
		modulate.a = lerpf(1.0 if on else 0.8, 0.8 if on else 1.0, minf(t / 0.3, 1.0)), elapsed, 0.5, maxf(0.5 - elapsed, 0.001))
	if not on:
		_grey_tw.tween_callback(func(): texture_rect.material = null)

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

## APK : une salle posee face cachee est le dos de carte a l'echelle 0,5 (350 x 488 -> 175 x 244, CardStackSlotComponent.cs:139-140), plus grand que la salle
## visible (0,37) ; elle est centree sur l'emplacement et retrouve la taille de la salle une fois retournee.
func set_face_down_scale() -> void:
	var down: bool = card_data != null and card_data.face_down
	_rest_scale = Vector2(175.0 / default_size.x, 244.0 / default_size.y) if down else Vector2.ONE
	scale = _rest_scale

## Retournement d'une salle qui vient d'etre revelee (APK CreateFlipUpTopRoomTask, CardStackSlotComponent.cs:274-296, tous les joueurs en meme temps) : la salle en attente est a l'echelle 0,5
## (:139-140), elle se retourne en 0,5 s (FlipCardBehavior, CardEntity.cs:72, sans EasingFunction : pitch lineaire donc largeur en cosinus) puis reprend sa taille en 0,3 s (ScaleOut, CardEntity.cs:71, lineaire).
func flip_in(duration := 0.5, hold := 0.0) -> void:
	AudioManager.play_sfx("ui_card_slide_up") # FlipCardBehavior.cs:113 (CardStackSlotComponent.cs:283 : CreateFaceUpTask de la salle revelee)
	var target := _rest_scale
	var big := Vector2(175.0 / default_size.x, 244.0 / default_size.y)
	var back := TextureRect.new() # la face cachee, qui se referme avant que la face visible s'ouvre
	back.texture = load(CardDB.card_image("", "back-room"))
	back.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	back.stretch_mode = TextureRect.STRETCH_SCALE
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back.size = default_size
	add_child(back)
	scale = big
	var tw := create_tween()
	tw.tween_property(self, "scale:x", 0.0, duration / 2.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_callback(back.queue_free)
	tw.tween_property(self, "scale:x", big.x, duration / 2.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if hold > 0.0: # salle a declencheur de construction : elle reste agrandie pendant la bulle de capacite de l'adversaire
		tw.tween_interval(hold)
	tw.tween_property(self, "scale", target, 0.3)

## Gel de l'APK (Freeze) : voile de glace (frozzen_card) par-dessus la salle ; animate : il apparait en fondu lineaire de 0,5 s (CardStackSlotComponent.cs:102 ; DungeonFrameEntity.cs:341),
## et s'efface de la meme facon au degel (CardStackSlotComponent.cs:98 CreateFadeOutTask, meme FadeBehavior de 0,5 s). L'appelant passe animate = (le gel vient de changer).
## Il grossit avec la salle ou se trouve le heros (1 -> 1,35, CubicEase, DungeonFrameEntity.cs:336-340) : ici il est enfant de la salle, qui grossit deja (BoardUI._apply_focus).
func set_frozen(on: bool, animate := false) -> void:
	if (on or animate) and _frozen == null:
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
		if on and animate:
			_frozen.modulate.a = 0.0
			_frozen.create_tween().tween_property(_frozen, "modulate:a", 1.0, 0.5)
	if _frozen == null:
		return
	if on or not animate:
		_frozen.visible = on
	else: # degel : la carte est reconstruite a chaque affichage, le voile est donc recree pour s'effacer
		var ghost := _frozen
		_frozen = null
		var tw := ghost.create_tween()
		tw.tween_property(ghost, "modulate:a", 0.0, 0.5)
		tw.tween_callback(ghost.queue_free)

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

## Coeur de valeur modifiee (SlotRoomCardEntity.cs:24-30, HeroCardEntity.cs:79-86) : HeartEntity en (-115, 195) de la carte 350 x 488, echelle 1,3, chiffre or ;
## degats courants d'une salle, PV d'un heros dope (`buff`). L'appelant ne l'ajoute que si la valeur differe de l'imprimee.
func add_heart(value: int, buff := false) -> void:
	var old := get_node_or_null("ValueHeart")
	if old != null:
		remove_child(old)
		old.queue_free()
	var k := default_size / Vector2(350.0, 488.0)
	var s := 1.3 * k.x
	var h := Control.new()
	h.name = "ValueHeart"
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.position = default_size / 2.0 + Vector2(-115.0, 195.0) * k
	add_child(h)
	for it in [["res://assets/ui/gradients/health_room_icon_glow.webp", Vector2(90, 82)], ["res://assets/ui/ingame/%s.webp" % ("health_hero_buff_icon" if buff else "health_room_icon"), Vector2(70, 62)]]:
		var t := TextureRect.new()
		t.texture = load(it[0])
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_SCALE
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		t.size = (it[1] as Vector2) * s
		t.position = -t.size / 2.0
		h.add_child(t)
	var lb := Label.new()
	lb.text = str(value)
	lb.add_theme_font_override("font", load("res://assets/fonts/arcadepix.fnt"))
	lb.add_theme_font_size_override("font_size", maxi(8, roundi(22.0 * s)))
	lb.add_theme_color_override("font_color", Color(0.804, 0.694, 0.373))
	lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lb.position = Vector2(-22.0, -15.0) * s
	lb.size = Vector2(40.0 * s, 24.0 * s)
	h.add_child(lb)

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

## CardMoveBehavior.cs:13,129-133 : a chaque image valeur += (cible - valeur) x min(ms x 0,009 ; 1), donc 14,4 % par image de 16 ms (pas de duree : ~0,3 s pour 95 %).
## `prop` = chemin de propriete de `n` ; un lerp encore en cours sur la meme propriete est remplace (le Refresh de CardPositionComponent change la cible).
static func lerp_vers(n: Node, prop: String, cible) -> void:
	var cle := "lerp_" + prop.replace(":", "_")
	if n.has_meta(cle) and is_instance_valid(n.get_meta(cle)):
		(n.get_meta(cle) as Tween).kill()
	var dep = n.get_indexed(prop)
	var tw := n.create_tween()
	n.set_meta(cle, tw)
	tw.tween_method(func(t: float): n.set_indexed(prop, lerp(dep, cible, 1.0 - pow(0.856, t / 0.016))), 0.0, 0.48, 0.48) # 0,856 = 1 - 0,009 x 16
	tw.tween_callback(func(): n.set_indexed(prop, cible))

## Carte de la main : BoardUI choisit la carte survolee (CardHoverBehavior.ResolveCollision : centre le plus proche du pointeur parmi celles qui se chevauchent)
## et appelle set_hovered ; l'entree / sortie native du controle (la carte du dessus) est alors ignoree.
var hover_managed := false

func _on_mouse_entered() -> void:
	if not hover_managed:
		set_hovered(true)

func _on_mouse_exited() -> void:
	if not hover_managed:
		set_hovered(false)

func set_hovered(on: bool) -> void:
	if on:
		_hover_in()
	else:
		_hover_out()

func _hover_in() -> void:
	z_index = 20
	if glow_rect:
		glow_rect.visible = true
	if border:
		border.border_color = Color(1.0, 0.85, 0.2, 1.0)
	lerp_vers(self, "scale", _rest_scale * hover_scale)
	card_hovered.emit(card_data, true)

func _hover_out() -> void:
	z_index = 0
	if glow_rect:
		glow_rect.visible = false
	if border:
		border.border_color = Color(0.4, 0.4, 0.5, 0.5)
	lerp_vers(self, "scale", _rest_scale)
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
