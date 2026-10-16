class_name BoardUI
extends Control
## Interface principale du plateau de jeu Boss Monster (Board.tscn, tout l'arbre est construit ici).
## Clone de l'UI de l'APK 2.2.6, en coordonnees 1920x1080 (le projet met a l'echelle) :
## - Bandeau de pierre en haut (BUILD / ADVENTURE PHASE), engrenage (menu) en haut a droite.
## - Colonne gauche : HEROES IN TOWN (cartes empilees, defilables) + DISCARD PILE.
## - Deux couloirs : adversaire en haut, joueur en bas, 5 emplacements chacun alignes a droite (vers le boss),
##   badges DAMAGE / XP / niveau, boss sur la droite, bouton PASS TURN sur la separation.
## - Colonne droite : boss adverse (blessures, ames, tresors), ROOM / SPELL DECK, mon boss (WOUNDS, SOULS, TREASURES), LEVEL UP.
## - Main en eventail en bas ; choix du boss (YOU ARE ...) et defausse d'ouverture en carrousel central.
## - Animation de traversee de heros (HeroCrossingBehavior.cs) avec audio et saut mortel.

const GameManager = preload("res://godot/scripts/GameManager.gd")
const OnlineGameManager = preload("res://godot/scripts/OnlineGameManager.gd")
const BossEngine = preload("res://godot/scripts/BossEngine.gd")
const CardData = preload("res://godot/scripts/CardData.gd")

var game_manager: GameManager
var on_exit_callback: Callable
var view_pid: int = 0
var seat_bar: HBoxContainer
var choice_bar: HFlowContainer
var extra_bar: HFlowContainer
var discard_pick: Array = []
var _last_phase: String = ""

const CORE_MOVE_TYPES := ["pickBoss", "buildRoom", "pass", "passBuild", "adventureNext", "resolveNextHero", "openingDiscard", "resolveLevelUpChoice"]

# Textures de l'APK
const UI_DIR := "res://assets/ui/ingame/"
const TEX_SOUL := "res://assets/ui/ingame/souls_icon.webp"
const TEX_SOUL_EMPTY := "res://assets/ui/ingame/souls_icon_empty.webp"
const TEX_WOUND := "res://assets/ui/ingame/wound_icon.webp"
const TEX_WOUND_EMPTY := "res://assets/ui/ingame/wound_icon_empty.webp"
const TEX_TREASURE_CLERIC := "res://assets/ui/ingame/icon_treasure_cleric.webp"
const TEX_TREASURE_FIGHTER := "res://assets/ui/ingame/icon_treasure_fighter.webp"
const TEX_TREASURE_MAGE := "res://assets/ui/ingame/icon_treasure_mage.webp"
const TEX_TREASURE_THIEF := "res://assets/ui/ingame/icon_treasure_thief.webp"
const TEX_TOTAL_DAMAGE := "res://assets/ui/ingame/total_damage.webp"
const TEX_XP_BADGE := "res://assets/ui/ingame/bg_position_exp.webp"
const TEX_UNKNOWN_BOSS := "res://assets/ui/ingame/unknow_boss_character.webp"
const TREASURE_TEX := {1: TEX_TREASURE_CLERIC, 2: TEX_TREASURE_FIGHTER, 3: TEX_TREASURE_MAGE, 4: TEX_TREASURE_THIEF}
const FONT_A := "res://assets/fonts/arcadepix.TTF"
const FONT_B := "res://assets/fonts/arcadepix2.TTF"

const PHASE_BANNERS := {
	"build": "res://assets/ui/ingame/build_phase.webp",
	"bait": "res://assets/ui/ingame/bait_phase.webp",
	"adventure": "res://assets/ui/ingame/adventure_phase.webp",
}

# Geometrie (espace 1920x1080 de l'APK)
const LANE_Y := [62.0, 497.0]            # [adversaire, joueur]
const LANE_H := [435.0, 455.0]
const SLOT_Y := [128.0, 138.0]           # haut des emplacements, relatif au couloir
const SLOT_SIZE := Vector2(127, 175)
const SLOT_X0 := 660.0
const SLOT_STEP := 140.0
const PLAY_CX := 945.0                   # centre de la zone de jeu (entre les deux colonnes)
const HAND_CARD := Vector2(165, 230)
const BIG_CARD := Vector2(232, 324)
const BOSS_SPRITE_SCALE := 0.82
const GOLD := Color(0.95, 0.78, 0.3)
const CREAM := Color(0.93, 0.87, 0.7)

var _fa: Font
var _fb: Font

# Noeuds UI (construits dans _ready)
var top_menu_btn: Button
var town_container: VBoxContainer
var discard_btn: TextureButton
var _lane: Array = [{}, {}]              # [adversaire, joueur] : bg, root, slots, entrance, platform, sprite, container, dmg, xp, lvl, icon
var btn_advance: BaseButton
var btn_pass: BaseButton
var action_box: HBoxContainer
var bar_box: VBoxContainer
var hand_layer: Control
var phase_banner: TextureRect
var timer_label: Label
var hero_crossing_layer: Control
var _dim: ColorRect
var _bubble: TextureRect
var _carousel_text: RichTextLabel
var _confirm_btn: Button

var foe_name_label: Label
var foe_sub_label: Label
var foe_wounds_label: Label
var foe_souls_label: Label
var foe_coins_label: Label
var foe_treasures_box: Control
var sidebar_boss_label: Label
var sidebar_sub_label: Label
var souls_container: HBoxContainer
var wounds_container: HBoxContainer
var treasures_container: Control
var room_deck_label: Label
var spell_deck_label: Label
var deck_info_label: Label
var levelup_btn: TextureButton

var _card_scene = preload("res://godot/scenes/Card.tscn")
var _slot_scene = preload("res://godot/scenes/DungeonSlot.tscn")
var _dungeon_slots: Array = []           # ordre visuel : 0 = fond a gauche, 4 = pres du boss
var _foe_slots: Array = []
var _ai_timer: float = 0.0
var _animating_hero: bool = false
var skip_animations: bool = DisplayServer.get_name() == "headless" # le smoke test le passe a false
var _over_sting_played: bool = false

func _is_online() -> bool:
	return game_manager is OnlineGameManager

func _my_pid() -> int:
	if _is_online():
		return (game_manager as OnlineGameManager).my_pid
	return view_pid

# ---------------------------------------------------------------------------------------------------------------------
# Construction de l'interface
# ---------------------------------------------------------------------------------------------------------------------

func _tex(path: String) -> Texture2D:
	return load(path) if ResourceLoader.exists(path) else null

func _img(parent: Node, path: String, pos: Vector2, sz: Vector2 = Vector2.ZERO, stretch: int = TextureRect.STRETCH_SCALE) -> TextureRect:
	var t := TextureRect.new()
	t.texture = _tex(path)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = stretch as TextureRect.StretchMode
	t.position = pos
	if sz != Vector2.ZERO:
		t.size = sz
	elif t.texture != null:
		t.size = t.texture.get_size()
	parent.add_child(t)
	return t

func _lbl(parent: Node, text: String, font_size: int, color: Color, pos: Vector2, width: float = 0.0, font: Font = null, align: int = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font if font != null else _fb)
	l.add_theme_font_size_override("font_size", font_size)
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

func _rect(parent: Node, color: Color, pos: Vector2, sz: Vector2) -> ColorRect:
	var r := ColorRect.new()
	r.color = color
	r.position = pos
	r.size = sz
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(r)
	return r

func _tex_button(parent: Node, normal: String, pressed: String, pos: Vector2, sz: Vector2) -> TextureButton:
	var b := TextureButton.new()
	b.texture_normal = _tex(normal)
	if pressed != "":
		b.texture_pressed = _tex(pressed)
	b.ignore_texture_size = true
	b.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	b.position = pos
	b.custom_minimum_size = sz
	b.size = sz
	parent.add_child(b)
	return b

## Police pixel + police par defaut pour les glyphes absents (accents francais des libelles de coups).
func _font_with_fallback(path: String) -> Font:
	var fv := FontVariation.new()
	fv.base_font = load(path)
	fv.fallbacks = [ThemeDB.fallback_font]
	return fv

func _ready() -> void:
	_fa = _font_with_fallback(FONT_A)
	_fb = _font_with_fallback(FONT_B)
	_rect(self, Color.BLACK, Vector2.ZERO, Vector2(1920, 1080))
	_lane[0] = _make_lane(0)
	_lane[1] = _make_lane(1)
	_build_frame()
	_build_left()
	_build_right()
	_build_actions()
	_build_overlay()
	hand_layer = Control.new()
	hand_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hand_layer.size = Vector2(1920, 1080)
	add_child(hand_layer)
	_build_top()
	hero_crossing_layer = Control.new()
	hero_crossing_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hero_crossing_layer.size = Vector2(1920, 1080)
	add_child(hero_crossing_layer)

## Un couloir (fond du boss, emplacements, entree des heros, estrade du boss, badges DAMAGE / XP / niveau).
func _make_lane(idx: int) -> Dictionary:
	var L := {}
	var root := Control.new()
	root.position = Vector2(0, LANE_Y[idx])
	root.size = Vector2(1920, LANE_H[idx])
	root.clip_contents = true
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	L["root"] = root
	L["bg"] = _img(root, "", Vector2.ZERO, Vector2(1920, 465))
	var slots := Control.new()
	slots.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(slots)
	L["slots"] = slots
	var entrance := HBoxContainer.new()
	entrance.position = Vector2(215, 285)
	entrance.size = Vector2(420, 100)
	entrance.add_theme_constant_override("separation", 6)
	entrance.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(entrance)
	L["entrance"] = entrance
	var plat := Control.new()
	plat.position = Vector2(1405, 175 + 10 * idx)
	plat.size = Vector2(300, 210)
	plat.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(plat)
	L["platform"] = plat
	var sprite := TextureRect.new()
	sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sprite.stretch_mode = TextureRect.STRETCH_SCALE
	sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plat.add_child(sprite)
	L["sprite"] = sprite
	var cont := CenterContainer.new()
	cont.size = plat.size
	cont.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plat.add_child(cont)
	L["container"] = cont
	# Badges : DAMAGE <coeur n> puis <n>XP + niveau + type de tresor du boss
	_img(root, TEX_TOTAL_DAMAGE, Vector2(1355, 12))
	L["dmg"] = _lbl(root, "0", 26, Color.WHITE, Vector2(1355 + 105 - 25, 12 + 28 - 17), 50.0, _fa, HORIZONTAL_ALIGNMENT_CENTER)
	_img(root, TEX_XP_BADGE, Vector2(1503, 12))
	L["xp"] = _lbl(root, "0XP", 22, Color.WHITE, Vector2(1511, 12 + 11), 0.0, _fb)
	L["lvl"] = _lbl(root, "1", 30, Color.WHITE, Vector2(1503 + 95, 12 + 4), 40.0, _fa, HORIZONTAL_ALIGNMENT_CENTER)
	L["icon"] = _img(root, "", Vector2(1503 + 153 - 13, 12 + 25 - 13), Vector2(26, 26), TextureRect.STRETCH_KEEP_ASPECT_CENTERED)
	return L

func _build_frame() -> void:
	# Colonnes laterales en pierre sombre + traits dores, barres haute et basse.
	for x in [0.0, 1708.0]:
		var w: float = 183.0 if x == 0.0 else 212.0
		var stone := _img(self, "res://assets/ui/ingame/bg_levelup_panel.webp", Vector2(x, 0), Vector2(w, 1080), TextureRect.STRETCH_TILE)
		stone.modulate = Color(0.55, 0.45, 0.7, 1.0)
		_rect(self, Color(0.08, 0.03, 0.12, 0.86), Vector2(x, 0), Vector2(w, 1080))
	_img(self, UI_DIR + "vertical_line.webp", Vector2(183, 0))
	_img(self, UI_DIR + "vertical_line.webp", Vector2(1707, 0))
	_img(self, UI_DIR + "bg_top.webp", Vector2(0, -15), Vector2(1920, 77))
	_img(self, UI_DIR + "bg_bottom.webp", Vector2(0, 953), Vector2(1920, 127))

func _build_left() -> void:
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(14, 96)
	scroll.size = Vector2(160, 806)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	add_child(scroll)
	town_container = VBoxContainer.new()
	town_container.add_theme_constant_override("separation", 15)
	scroll.add_child(town_container)
	_img(self, UI_DIR + "heroes_in_town_top.webp", Vector2(0, 0), Vector2(183, 96))
	discard_btn = _tex_button(self, UI_DIR + "discard_pile.webp", "", Vector2(0, 907), Vector2(192, 149))

func _build_right() -> void:
	# --- Boss adverse
	_img(self, UI_DIR + "boss_icon.webp", Vector2(1716, 74), Vector2(36, 42), TextureRect.STRETCH_KEEP_ASPECT_CENTERED)
	foe_name_label = _lbl(self, "", 20, CREAM, Vector2(1762, 80), 150.0, _fb)
	foe_sub_label = _lbl(self, "", 12, Color.WHITE, Vector2(1762, 106), 110.0, _fb)
	foe_sub_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_img(self, TEX_WOUND, Vector2(1716, 142), Vector2(22, 28), TextureRect.STRETCH_KEEP_ASPECT_CENTERED)
	foe_wounds_label = _lbl(self, "x0", 18, Color.WHITE, Vector2(1746, 144), 0.0, _fa)
	_img(self, TEX_SOUL, Vector2(1782, 142), Vector2(22, 28), TextureRect.STRETCH_KEEP_ASPECT_CENTERED)
	foe_souls_label = _lbl(self, "x0", 18, Color.WHITE, Vector2(1812, 144), 0.0, _fa)
	foe_treasures_box = Control.new()
	foe_treasures_box.position = Vector2(1715, 197)
	foe_treasures_box.size = Vector2(202, 68)
	foe_treasures_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(foe_treasures_box)
	_img(foe_treasures_box, UI_DIR + "bg_treasures_boss_profile.webp", Vector2.ZERO, Vector2(202, 68)).modulate = Color(1, 1, 1, 0.6)
	foe_coins_label = _lbl(self, "", 12, GOLD, Vector2(1718, 268))
	# --- Pioches
	_lbl(self, "ROOM DECK", 18, CREAM, Vector2(1718, 288))
	_img(self, UI_DIR + "rooms_icon.webp", Vector2(1717, 315), Vector2(62, 58))
	room_deck_label = _lbl(self, "x0", 26, Color.WHITE, Vector2(1812, 334), 0.0, _fa)
	_lbl(self, "SPELL DECK", 18, CREAM, Vector2(1718, 384))
	_img(self, UI_DIR + "spells_icon.webp", Vector2(1717, 410), Vector2(62, 58))
	spell_deck_label = _lbl(self, "x0", 26, Color.WHITE, Vector2(1812, 430), 0.0, _fa)
	deck_info_label = _lbl(self, "", 13, GOLD, Vector2(1718, 472))
	# --- Mon boss
	_img(self, UI_DIR + "boss_icon.webp", Vector2(1716, 509), Vector2(36, 42), TextureRect.STRETCH_KEEP_ASPECT_CENTERED)
	sidebar_boss_label = _lbl(self, "", 20, CREAM, Vector2(1762, 513), 150.0, _fb)
	sidebar_sub_label = _lbl(self, "", 12, Color.WHITE, Vector2(1762, 539), 110.0, _fb)
	sidebar_sub_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lbl(self, "WOUNDS", 18, CREAM, Vector2(1718, 580))
	wounds_container = HBoxContainer.new()
	wounds_container.position = Vector2(1718, 606)
	wounds_container.add_theme_constant_override("separation", 3)
	add_child(wounds_container)
	_lbl(self, "SOULS", 18, CREAM, Vector2(1718, 644))
	souls_container = HBoxContainer.new()
	souls_container.position = Vector2(1718, 668)
	souls_container.add_theme_constant_override("separation", 0)
	add_child(souls_container)
	_lbl(self, "TREASURES", 18, CREAM, Vector2(1718, 706))
	treasures_container = Control.new()
	treasures_container.position = Vector2(1717, 737)
	treasures_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(treasures_container)
	levelup_btn = _tex_button(self, UI_DIR + "levelup_bt.webp", UI_DIR + "levelup_bt_pressed.webp", Vector2(1722, 978), Vector2(183, 59))

func _build_actions() -> void:
	# PASS TURN / GO centres sur la separation des deux couloirs.
	action_box = HBoxContainer.new()
	action_box.position = Vector2(PLAY_CX - 200, 459)
	action_box.size = Vector2(400, 82)
	action_box.alignment = BoxContainer.ALIGNMENT_CENTER
	action_box.add_theme_constant_override("separation", 12)
	add_child(action_box)
	btn_advance = _tex_button(action_box, UI_DIR + "go_button.webp", UI_DIR + "go_button_pressed.webp", Vector2.ZERO, Vector2(75, 82))
	btn_pass = _tex_button(action_box, UI_DIR + "pass_button.webp", UI_DIR + "pass_button_pressed.webp", Vector2.ZERO, Vector2(201, 82))
	# Choix en attente / coups supplementaires, juste sous la separation.
	bar_box = VBoxContainer.new()
	bar_box.position = Vector2(330, 548)
	bar_box.size = Vector2(1270, 80)
	bar_box.alignment = BoxContainer.ALIGNMENT_BEGIN
	bar_box.theme = _make_bar_theme()
	add_child(bar_box)
	choice_bar = HFlowContainer.new()
	choice_bar.alignment = FlowContainer.ALIGNMENT_CENTER
	choice_bar.add_theme_constant_override("h_separation", 8)
	choice_bar.add_theme_constant_override("v_separation", 6)
	bar_box.add_child(choice_bar)
	extra_bar = HFlowContainer.new()
	extra_bar.alignment = FlowContainer.ALIGNMENT_CENTER
	extra_bar.add_theme_constant_override("h_separation", 8)
	extra_bar.add_theme_constant_override("v_separation", 6)
	bar_box.add_child(extra_bar)

func _make_bar_theme() -> Theme:
	var th := Theme.new()
	for n in ["normal", "hover", "pressed", "disabled", "focus"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.13, 0.08, 0.18, 0.95) if n != "hover" else Color(0.25, 0.17, 0.3, 0.98)
		sb.border_color = GOLD
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(4)
		sb.content_margin_left = 14
		sb.content_margin_right = 14
		sb.content_margin_top = 6
		sb.content_margin_bottom = 6
		if n == "focus":
			sb.bg_color = Color(0, 0, 0, 0)
		th.set_stylebox(n, "Button", sb)
	th.set_font("font", "Button", _fa)
	th.set_font_size("font_size", "Button", 16)
	th.set_color("font_color", "Button", GOLD)
	th.set_color("font_hover_color", "Button", Color.WHITE)
	return th

func _build_overlay() -> void:
	# Voile de la zone de jeu + titres du carrousel (YOU ARE ... / SELECT 2 CARDS TO DISCARD).
	_dim = ColorRect.new()
	_dim.color = Color(0, 0, 0, 0.6)
	_dim.position = Vector2(184, 62)
	_dim.size = Vector2(1523, 890)
	_dim.visible = false
	add_child(_dim)
	_bubble = _img(self, UI_DIR + "top_globe.webp", Vector2(PLAY_CX - 465, 150))
	_bubble.visible = false
	_carousel_text = RichTextLabel.new()
	_carousel_text.bbcode_enabled = true
	_carousel_text.scroll_active = false
	_carousel_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_carousel_text.add_theme_font_override("normal_font", _fa)
	_carousel_text.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	_carousel_text.add_theme_constant_override("outline_size", 3)
	_carousel_text.visible = false
	add_child(_carousel_text)
	_confirm_btn = Button.new()
	_confirm_btn.text = "CONTINUE"
	_confirm_btn.theme = _make_bar_theme()
	_confirm_btn.position = Vector2(PLAY_CX - 110, 730)
	_confirm_btn.custom_minimum_size = Vector2(220, 54)
	_confirm_btn.size = Vector2(220, 54)
	_confirm_btn.visible = false
	add_child(_confirm_btn)

func _build_top() -> void:
	phase_banner = _img(self, "", Vector2(PLAY_CX - 201, -62), Vector2(403, 153))
	timer_label = _lbl(self, "", 18, GOLD, Vector2(1160, 18))
	# Engrenage (menu) en haut a droite
	top_menu_btn = Button.new()
	top_menu_btn.flat = true
	top_menu_btn.position = Vector2(1860, 8)
	top_menu_btn.size = Vector2(56, 56)
	top_menu_btn.custom_minimum_size = Vector2(56, 56)
	top_menu_btn.tooltip_text = "Menu"
	for n in ["normal", "hover", "pressed", "focus"]:
		top_menu_btn.add_theme_stylebox_override(n, StyleBoxEmpty.new())
	top_menu_btn.draw.connect(_draw_gear.bind(top_menu_btn))
	top_menu_btn.pressed.connect(_on_menu_pressed)
	top_menu_btn.mouse_entered.connect(top_menu_btn.queue_redraw)
	top_menu_btn.mouse_exited.connect(top_menu_btn.queue_redraw)
	add_child(top_menu_btn)
	# Selecteur de donjon (3-4 joueurs)
	seat_bar = HBoxContainer.new()
	seat_bar.position = Vector2(200, 8)
	seat_bar.add_theme_constant_override("separation", 8)
	seat_bar.theme = _make_bar_theme()
	add_child(seat_bar)

func _draw_gear(c: Control) -> void:
	var ctr := c.size / 2.0
	var col := GOLD if not c.is_hovered() else Color(1, 0.9, 0.5)
	for i in 8:
		var d := Vector2.from_angle(TAU * i / 8.0)
		c.draw_line(ctr + d * 14.0, ctr + d * 22.0, col, 8.0)
	c.draw_circle(ctr, 17.0, col)
	c.draw_circle(ctr, 7.0, Color(0.16, 0.09, 0.03))

func setup(p_gm: GameManager, p_exit_cb: Callable) -> void:
	game_manager = p_gm
	on_exit_callback = p_exit_cb
	game_manager.state_changed.connect(refresh)
	btn_advance.pressed.connect(_on_advance_pressed)
	btn_pass.pressed.connect(_on_pass_pressed)
	discard_btn.pressed.connect(_on_discard_pile_pressed)
	levelup_btn.pressed.connect(_on_level_up_pressed)
	_confirm_btn.pressed.connect(_on_discard_confirm)
	_init_dungeon_slots()
	AudioManager.play_music("music_dungeon_v3")
	refresh()

func _play_sfx(path: String) -> void:
	AudioManager.play_sfx(path)

func _refresh_seat_bar() -> void:
	for c in seat_bar.get_children():
		c.queue_free()
	if _is_online():
		seat_bar.visible = false
		return
	var players: Dictionary = game_manager.G.get("players", {})
	var humans: Array = []
	for pid in players:
		if not (players[pid] as Dictionary).get("isAI", false):
			humans.append(int(pid))
	seat_bar.visible = humans.size() > 1
	if humans.size() <= 1:
		return
	humans.sort()
	for pid in humans:
		var b := Button.new()
		b.text = "PLAYER %d" % (pid + 1)
		b.disabled = (pid == view_pid)
		var p: int = int(pid)
		b.pressed.connect(func(): view_pid = p; _sync_slot_pids(); refresh())
		seat_bar.add_child(b)

func _sync_slot_pids() -> void:
	for slot in _dungeon_slots:
		(slot as DungeonSlot).player_id = view_pid

func _slot_pos(j: int, idx: int) -> Vector2:
	return Vector2(SLOT_X0 + SLOT_STEP * j, SLOT_Y[idx])

func _init_dungeon_slots() -> void:
	var holder: Control = _lane[1]["slots"]
	for child in holder.get_children():
		child.queue_free()
	_dungeon_slots.clear()
	for j in CardDB.DUNGEON_SLOTS:
		var slot: DungeonSlot = _slot_scene.instantiate()
		holder.add_child(slot)
		slot.setup(game_manager, j, view_pid)
		slot.position = _slot_pos(j, 1)
		slot.size = SLOT_SIZE
		_dungeon_slots.append(slot)

func _process(delta: float) -> void:
	if game_manager == null or game_manager.G.get("gameOver") != null:
		return
	if _animating_hero:
		return
	var players: Dictionary = game_manager.G.get("players", {})
	var phase: String = game_manager.G.get("phase", "")
	var pc: Dictionary = game_manager.G.get("pendingChoice", {})
	for pid in players:
		if not (players[pid] as Dictionary).get("isAI", false):
			continue
		var moves: Array = game_manager.legal_moves(int(pid))
		var has_ai_choice: bool = not pc.is_empty() and int(pc.get("playerId", -1)) == int(pid)
		# Aventure : l'IA active doit avancer / passer, sinon la partie attend indefiniment (pause : tous les sieges IA passent).
		var adv_turn: bool = phase == "adventure" and pc.is_empty() and (int(pid) == game_manager.active_player() or ((game_manager.G.get("adventure", {}) as Dictionary).get("pause") != null))
		if not moves.is_empty() and (has_ai_choice or phase == "boss" or phase == "build" or adv_turn):
			_ai_timer += delta
			if _ai_timer > 0.5:
				_ai_timer = 0.0
				var mv = AI.pick_move(game_manager, int(pid))
				# Un coup juge nocif par l'IA (score < 0) n'est joue qu'en dernier recours : on prefere passer (comme soak_runner).
				if adv_turn and mv != null and AI.score_move(game_manager, int(pid), mv) < 0.0:
					for m in moves:
						if str((m as Dictionary).get("type", "")) in ["pass", "passBuild"]:
							mv = m
							break
				if mv != null:
					game_manager.apply_move(int(pid), mv)
					refresh()
			return

# ---------------------------------------------------------------------------------------------------------------------
# Rafraichissement
# ---------------------------------------------------------------------------------------------------------------------

func refresh() -> void:
	if game_manager == null or game_manager.G.is_empty():
		return

	var G: Dictionary = game_manager.G
	if _is_online():
		view_pid = _my_pid()
		_sync_slot_pids()
	if not (G.get("players", {}) as Dictionary).has(view_pid):
		view_pid = 0
		_sync_slot_pids()
	_refresh_seat_bar()

	var p: Dictionary = (G["players"] as Dictionary)[view_pid]
	var phase: String = G.get("phase", "")

	# Animation de combat / traversée héroïque si en attente
	var lhf = G.get("lastHeroFight")
	if lhf != null and lhf is Dictionary and not _animating_hero:
		G.erase("lastHeroFight")
		_play_hero_crossing_animation(lhf)

	if G.get("gameOver") != null:
		var w = G["gameOver"].get("winner", -1)
		if not _over_sting_played:
			_over_sting_played = true
			AudioManager.play_sfx("sting_player_win" if int(w) == view_pid else "sting_player_lose")  # APK WinnerScene/LoseScene
	var deadline := int(G.get("turnDeadline", 0))
	if deadline > 0 and G.get("gameOver") == null:
		var now_ms: float = Time.get_unix_time_from_system() * 1000.0
		timer_label.text = "%d" % clampi(int((deadline - now_ms) / 1000.0), 0, 999)
	else:
		timer_label.text = ""

	var foe_pids := (G["players"] as Dictionary).keys().filter(func(k): return int(k) != view_pid)
	var foe_dict: Dictionary = {}
	if not foe_pids.is_empty():
		foe_dict = (G["players"] as Dictionary)[foe_pids[0]]

	_refresh_phase_banner(phase)
	_refresh_lane_badges(1, p)
	_refresh_lane_badges(0, foe_dict)
	_refresh_sidebar(G, p, foe_dict)
	_refresh_town(G)
	_refresh_boss_platforms(p, foe_dict)
	_refresh_entrances(p, foe_dict)

	# Donjon du joueur : salles alignees a droite (la plus recente = la plus a gauche, a l'entree).
	var dungeon: Array = p.get("dungeon", [])
	var n := dungeon.size()
	var off: int = maxi(0, CardDB.DUNGEON_SLOTS - n)
	for j in range(_dungeon_slots.size()):
		var slot: DungeonSlot = _dungeon_slots[j]
		var di := j - off
		if di >= 0 and di < n:
			slot.slot_index = di
			slot.set_stack(dungeon[di])
		else:
			slot.slot_index = n
			slot.set_stack([])

	_refresh_foe_dungeon(foe_dict)
	_refresh_overlay(G, phase)
	_refresh_hand(G, p, phase)

	var carousel := _carousel_active(G, phase)
	var my_moves: Array = game_manager.legal_moves(_my_pid())
	action_box.visible = not carousel
	btn_advance.visible = (phase == "adventure") or _has_move(my_moves, "resolveNextHero")
	btn_pass.visible = (phase == "build" or phase == "setup") or _has_move(my_moves, "pass")
	_refresh_choice_bar(G, my_moves)
	_refresh_extra_bar(G, my_moves)

func _carousel_active(G: Dictionary, phase: String) -> bool:
	return G.get("gameOver") == null and (phase == "boss" or _is_opening_discard_for_me())

func _refresh_overlay(G: Dictionary, phase: String) -> void:
	var over: bool = G.get("gameOver") != null
	var boss_pick := phase == "boss" and not over
	var discard := _is_opening_discard_for_me() and not over
	_dim.visible = boss_pick or discard
	_dim.color = Color(0, 0, 0, 1.0 if boss_pick else 0.6)
	_bubble.visible = discard or over
	_carousel_text.visible = boss_pick or discard or over
	_confirm_btn.visible = discard and discard_pick.size() == 2
	if boss_pick:
		_carousel_text.position = Vector2(PLAY_CX - 600, 108)
		_carousel_text.size = Vector2(1200, 90)
		_set_carousel_text("YOU ARE [color=#f0c040]...[/color]", 56)
	elif discard:
		_set_carousel_text("SELECT [color=#f0c040]2[/color] CARDS TO DISCARD", 26)
		_carousel_text.position = Vector2(PLAY_CX - 465, 150 + 40)
		_carousel_text.size = Vector2(931, 50)
	elif over:
		var go: Dictionary = G["gameOver"]
		_set_carousel_text("PLAYER [color=#f0c040]%d[/color] WINS" % (int(go.get("winner", -1)) + 1), 26)
		_carousel_text.position = Vector2(PLAY_CX - 465, 150 + 40)
		_carousel_text.size = Vector2(931, 50)

func _set_carousel_text(bb: String, font_size: int) -> void:
	_carousel_text.add_theme_font_size_override("normal_font_size", font_size)
	_carousel_text.text = "[center]%s[/center]" % bb

func _refresh_lane_badges(idx: int, pl: Dictionary) -> void:
	var L: Dictionary = _lane[idx]
	var boss = pl.get("boss")
	(L["dmg"] as Label).text = str(_get_total_dungeon_damage(pl))
	(L["xp"] as Label).text = "%dXP" % (int((boss as Dictionary).get("xp", 0)) if boss != null else 0)
	(L["lvl"] as Label).text = "2" if bool(pl.get("leveledUp", false)) else "1"
	var tr: Array = (boss as Dictionary).get("treasures", []) if boss != null else []
	(L["icon"] as TextureRect).texture = _tex(str(TREASURE_TEX.get(int(tr[0]) if not tr.is_empty() else 0, "")))

func _refresh_town(G: Dictionary) -> void:
	for c in town_container.get_children():
		c.queue_free()
	for hero in G.get("town", []):
		var hero_card = _card_scene.instantiate()
		hero_card.default_size = Vector2(154, 215)
		town_container.add_child(hero_card)
		hero_card.is_in_hand = false
		hero_card.setup(hero)

func _refresh_entrances(p: Dictionary, foe: Dictionary) -> void:
	var rows := [[1, p], [0, foe]]
	for r in rows:
		var box: HBoxContainer = (_lane[int(r[0])] as Dictionary)["entrance"]
		for c in box.get_children():
			c.queue_free()
		for hero in (r[1] as Dictionary).get("entrance", []):
			box.add_child(_create_mini_hero_token(hero))

func _create_mini_hero_token(hero: Dictionary) -> Control:
	var c := TextureRect.new()
	c.custom_minimum_size = Vector2(90, 90)
	c.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	c.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var hid := str(hero.get("id", "")).to_lower()
	var sprite_path := "res://assets/ui/characters/heroes/%s_character.webp" % hid
	if ResourceLoader.exists(sprite_path):
		c.texture = load(sprite_path)
	c.tooltip_text = "%s (PV: %s)" % [str(hero.get("name", "Héros")), str(hero.get("health", 4))]
	return c

func _refresh_boss_platforms(p: Dictionary, foe: Dictionary) -> void:
	_set_boss(_lane[1], p.get("boss"))
	_set_boss(_lane[0], foe.get("boss"))

func _set_boss(L: Dictionary, boss) -> void:
	var sprite: TextureRect = L["sprite"]
	var plat: Control = L["platform"]
	var cont: CenterContainer = L["container"]
	var tex: Texture2D = null
	if boss != null:
		var bid := str(boss.get("id", "")).to_lower()
		var bg := _tex("res://assets/ui/dungeon/%s_bg.webp" % bid)
		if bg != null:
			(L["bg"] as TextureRect).texture = bg
		tex = _tex("res://assets/ui/characters/%s_character.webp" % bid)
		if tex != null:
			for child in cont.get_children():
				child.queue_free()
		else:
			_ensure_boss_card(cont, boss)
	else:
		tex = _tex(TEX_UNKNOWN_BOSS)
	sprite.visible = tex != null
	if tex != null:
		sprite.texture = tex
		sprite.size = tex.get_size() * BOSS_SPRITE_SCALE
		sprite.position = Vector2((plat.size.x - sprite.size.x) / 2.0, plat.size.y - sprite.size.y)

func _ensure_boss_card(container: CenterContainer, boss_dict: Dictionary) -> void:
	for c in container.get_children():
		c.queue_free()
	var boss_ui = _card_scene.instantiate()
	container.add_child(boss_ui)
	boss_ui.is_in_hand = false
	boss_ui.setup(boss_dict)

func _refresh_foe_dungeon(foe: Dictionary) -> void:
	var holder: Control = _lane[0]["slots"]
	for c in holder.get_children():
		c.queue_free()
	_foe_slots.clear()

	var dungeon: Array = foe.get("dungeon", [])
	var off: int = maxi(0, CardDB.DUNGEON_SLOTS - dungeon.size())
	for j in CardDB.DUNGEON_SLOTS:
		var slot_ctrl := Control.new()
		slot_ctrl.custom_minimum_size = SLOT_SIZE
		slot_ctrl.size = SLOT_SIZE
		slot_ctrl.position = _slot_pos(j, 0)
		var frame := TextureRect.new()
		frame.set_anchors_preset(Control.PRESET_FULL_RECT)
		frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		frame.stretch_mode = TextureRect.STRETCH_SCALE
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.texture = _tex(UI_DIR + "card_slot.webp")
		slot_ctrl.add_child(frame)

		var di := j - off
		if di >= 0 and di < dungeon.size():
			var r = BossEngine.active_room(dungeon[di])
			if r != null:
				frame.visible = false
				var room_ui = _card_scene.instantiate()
				room_ui.default_size = SLOT_SIZE
				slot_ctrl.add_child(room_ui)
				room_ui.size = SLOT_SIZE
				room_ui.is_in_hand = false
				room_ui.setup(r)
				if Minibosses.active(game_manager.G): # Rise of the Minibosses : le miniboss de la salle adverse (nom cache tant qu'il est face cache)
					var mb_badge := Minibosses.make_badge(r, false)
					if mb_badge != null:
						slot_ctrl.add_child(mb_badge)
						slot_ctrl.tooltip_text = Minibosses.badge_tooltip(r, false)
		holder.add_child(slot_ctrl)
		_foe_slots.append(slot_ctrl)

## Main du joueur : eventail en bas ; carrousel central pour le choix du boss et la defausse d'ouverture.
func _refresh_hand(G: Dictionary, p: Dictionary, phase: String) -> void:
	for c in hand_layer.get_children():
		c.queue_free()

	if G.get("gameOver") != null:
		return
	if phase == "boss":
		var picks: Array = G.get("bossPicks", [])
		var cards: Array = []
		for b in picks:
			var boss_card = _spawn_card(b, -1, Vector2(300, 419))
			var bid = str(b.get("id", ""))
			boss_card.card_clicked.connect(func(_data):
				var is_fem := ["BMA006", "BMA007", "BMA008"].has(bid)
				_play_sfx("res://assets/audio/sfx/boss_female_intro.wav" if is_fem else "res://assets/audio/sfx/boss_male_intro.wav")
				_do({"type": "pickBoss", "args": [bid]})
			)
			cards.append(boss_card)
		_place_cards(cards, Vector2(300, 419), 330.0, 1100.0, 330.0, false)
		return

	var hand: Array = p.get("hand", [])
	var discarding := _is_opening_discard_for_me()
	var sz := BIG_CARD if discarding else HAND_CARD
	var cards: Array = []
	for i in hand.size():
		var card_dict: Dictionary = hand[i]
		var card_ui = _spawn_card(card_dict, i, sz)
		var idx := i
		card_ui.card_clicked.connect(func(_data): _on_hand_card_clicked(idx, card_dict))
		if discard_pick.has(idx):
			card_ui.modulate = Color(1.3, 1.3, 0.4, 1.0)
			var glow := card_ui.get_node_or_null("GlowRect")
			if glow != null:
				glow.visible = true
		if phase == "adventure": # l'APK grise la main pendant l'aventure
			card_ui.modulate = Color(0.55, 0.55, 0.55, 1.0)
		cards.append(card_ui)
	if discarding:
		_place_cards(cards, sz, 125.0, 1000.0, 338.0, false)
		for i in cards.size():
			if discard_pick.has(i):
				(cards[i] as Control).position.y -= 30.0
	else:
		_place_cards(cards, sz, 150.0, 1130.0, 832.0, true)

func _spawn_card(data: Dictionary, hand_idx: int, sz: Vector2) -> Control:
	var card_ui = _card_scene.instantiate()
	card_ui.default_size = sz
	hand_layer.add_child(card_ui)
	card_ui.size = sz
	card_ui.setup(data, hand_idx)
	return card_ui

## Aligne les cartes (chevauchement si necessaire) autour de PLAY_CX ; `fan` : leger eventail et carte survolee qui monte.
func _place_cards(cards: Array, sz: Vector2, step_max: float, span_max: float, top_y: float, fan: bool) -> void:
	var n := cards.size()
	if n == 0:
		return
	var step := step_max if n == 1 else minf(step_max, (span_max - sz.x) / float(n - 1))
	var x0 := PLAY_CX - (step * (n - 1) + sz.x) / 2.0
	var mid := (n - 1) / 2.0
	for i in n:
		var c: Control = cards[i]
		var y := top_y
		if fan:
			y += pow(i - mid, 2.0) * 1.1
			c.rotation_degrees = (i - mid) * 1.1
		c.position = Vector2(x0 + step * i, y)
		if fan:
			var base_y := y
			var base_rot := c.rotation_degrees
			c.mouse_entered.connect(func():
				var tw := create_tween().set_parallel(true)
				tw.tween_property(c, "position:y", base_y - 75.0, 0.12)
				tw.tween_property(c, "rotation_degrees", 0.0, 0.12))
			c.mouse_exited.connect(func():
				var tw := create_tween().set_parallel(true)
				tw.tween_property(c, "position:y", base_y, 0.12)
				tw.tween_property(c, "rotation_degrees", base_rot, 0.12))

func _refresh_phase_banner(phase: String) -> void:
	if phase == _last_phase:
		return
	_last_phase = phase
	var key := "build" if (phase == "setup" or phase == "boss") else phase
	if PHASE_BANNERS.has(key):
		phase_banner.texture = _tex(PHASE_BANNERS[key])

## Remplit une zone d'icones de tresor : chaque type est repete `count` fois (grise si 0).
func _fill_treasures(box: Control, counts: Dictionary, layout: Array, icon_sz: float) -> void:
	for c in box.get_children():
		if c is TextureRect and (c as TextureRect).texture != null and str((c as TextureRect).name).begins_with("T_"):
			c.queue_free()
		elif c is Label:
			c.queue_free()
	for item in layout:
		var tp: int = int(item[0])
		var count: int = int(counts.get(tp, 0))
		var pos: Vector2 = item[1]
		if tp == 5: # Explorer (Crash Landing) : pas d'icone, affiche seulement s'il y en a
			if count > 0:
				_lbl(box, "EXPL x%d" % count, 12, GOLD, pos)
			continue
		for k in range(clampi(count, 1, 5)):
			var t := _img(box, str(TREASURE_TEX[tp]), pos + Vector2(k * (icon_sz + 2.0), 0), Vector2(icon_sz, icon_sz), TextureRect.STRETCH_KEEP_ASPECT_CENTERED)
			t.name = "T_%d_%d" % [tp, k]
			t.modulate = Color(1, 1, 1, 1) if count > 0 else Color(1, 1, 1, 0.3)

func _icon_row(box: Container, total: int, filled: int, on_path: String, off_path: String, sz: Vector2) -> void:
	for c in box.get_children():
		c.queue_free()
	for i in range(total):
		var t := TextureRect.new()
		t.custom_minimum_size = sz
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		t.texture = _tex(on_path if i < filled else off_path)
		box.add_child(t)

func _refresh_sidebar(G: Dictionary, p: Dictionary, foe: Dictionary) -> void:
	# Mon boss
	var pb = p.get("boss")
	sidebar_boss_label.text = str(pb.get("name", "")).to_upper() if pb != null else ""
	sidebar_sub_label.text = str(pb.get("subtitle", "")) if pb != null else ""
	_icon_row(souls_container, 10, CardDB.total_souls(p, game_manager.G), TEX_SOUL, TEX_SOUL_EMPTY, Vector2(18, 24))
	_icon_row(wounds_container, 5, CardDB.total_wounds(p), TEX_WOUND, TEX_WOUND_EMPTY, Vector2(22, 26))
	_fill_treasures(treasures_container, BossEngine.treasure_counts(p),
		[[3, Vector2(0, 0)], [4, Vector2(0, 54)], [2, Vector2(0, 101)], [1, Vector2(0, 153)], [5, Vector2(0, 200)]], 30.0)

	# Boss adverse
	var fb = foe.get("boss")
	foe_name_label.text = str(fb.get("name", "")).to_upper() if fb != null else ""
	foe_sub_label.text = str(fb.get("subtitle", "")) if fb != null else ""
	foe_wounds_label.text = "x%d" % CardDB.total_wounds(foe)
	foe_souls_label.text = "x%d" % CardDB.total_souls(foe, game_manager.G)
	_fill_treasures(foe_treasures_box, BossEngine.treasure_counts(foe),
		[[4, Vector2(8, 6)], [3, Vector2(106, 6)], [2, Vector2(6, 38)], [1, Vector2(106, 38)], [5, Vector2(40, 8)]], 22.0)

	# Pioches
	var decks: Dictionary = G.get("decks", {})
	room_deck_label.text = "x%d" % decks.get("rooms", []).size()
	spell_deck_label.text = "x%d" % decks.get("spells", []).size()
	deck_info_label.text = ""
	foe_coins_label.text = ""
	if Minibosses.active(G): # Rise of the Minibosses : le Hoard de chaque joueur
		deck_info_label.text = "Pièces : %d" % Minibosses.coins(p)
		foe_coins_label.text = "Pièces : %d" % Minibosses.coins(foe)

	# Bouton Level Up : brille si 5 salles
	var can_lvl: bool = BossEngine.count_visible_rooms(p.get("dungeon", [])) >= 5
	levelup_btn.modulate = Color(1.2, 1.2, 0.4, 1.0) if can_lvl else Color(0.7, 0.7, 0.7, 0.8)

func _play_hero_crossing_animation(lhf: Dictionary) -> void:
	if skip_animations:
		return
	var pid: int = int(lhf.get("pid", 0))
	var hero: Dictionary = lhf.get("hero", {})
	var killed: bool = bool(lhf.get("killed", false))
	var path_taken: Array = lhf.get("path", [])
	var initial_hp: int = int(lhf.get("initialHp", 4))

	var is_my_dungeon := (pid == view_pid)
	var slots_list: Array = _dungeon_slots if is_my_dungeon else _foe_slots
	var L: Dictionary = _lane[1 if is_my_dungeon else 0]
	var boss_platform: Control = L["platform"]
	var boss_sprite: Control = L["sprite"]
	var entrance_ctrl: Control = L["entrance"]
	# Les salles sont alignees a droite : index de donjon -> emplacement visuel.
	var dng_size: int = ((game_manager.G.get("players", {}) as Dictionary).get(pid, {}) as Dictionary).get("dungeon", []).size()
	var vis_off: int = maxi(0, CardDB.DUNGEON_SLOTS - dng_size)

	_animating_hero = true

	# Créer le pion héroïque animé
	var pawn := _create_hero_pawn(hero, initial_hp)
	hero_crossing_layer.add_child(pawn)
	pawn.global_position = entrance_ctrl.global_position + Vector2(10, 10)

	var tw := create_tween()
	var current_hp := initial_hp

	for step in path_taken:
		var slot_idx: int = int(step.get("slot", 0))
		var dmg: int = int(step.get("damage", 0))
		var is_magic: bool = bool(step.get("isMagic", false))
		if slot_idx + vis_off < slots_list.size():
			var target_slot: Control = slots_list[slot_idx + vis_off]
			var target_pos := target_slot.global_position + Vector2(15, 20)

			tw.tween_callback(func(): _play_sfx("res://assets/audio/sfx/char_hero_move.wav"))
			tw.tween_property(pawn, "global_position", target_pos, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)

			tw.tween_callback(func():
				var sfx_path := "res://assets/audio/sfx/sfx_room_magic.wav" if is_magic else "res://assets/audio/sfx/sfx_room_physical.wav"
				_play_sfx(sfx_path)
				_bump_slot(target_slot)
				_show_floating_dmg(pawn, dmg)
			)
			current_hp -= dmg
			tw.tween_interval(0.25)

	if killed:
		tw.tween_callback(func(): _play_sfx("res://assets/audio/sfx/char_hero_death.wav"))
		tw.tween_property(pawn, "position:y", pawn.position.y - 100.0, 0.3).set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(pawn, "modulate:v", 1.6, 0.15)
		tw.tween_property(pawn, "position:y", pawn.position.y + 220.0, 0.4).set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(pawn, "modulate:a", 0.0, 0.4)
		tw.tween_callback(func():
			_spawn_flying_soul(pawn.global_position, souls_container.global_position if is_my_dungeon else foe_souls_label.global_position)
			pawn.queue_free()
			_animating_hero = false
			refresh()
		)
	else:
		var boss_pos := boss_platform.global_position + Vector2(25, 25)
		tw.tween_property(pawn, "global_position", boss_pos, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		tw.tween_callback(func():
			_play_sfx("res://assets/audio/sfx/char_hero_attack.wav")
			_shake_node(boss_sprite)
			var boss_dict: Dictionary = (game_manager.G.get("players", {}) as Dictionary).get(pid, {}).get("boss", {})
			var is_female := ["BMA006", "BMA007", "BMA008"].has(str(boss_dict.get("id", "")))
			_play_sfx("res://assets/audio/sfx/boss_female_hurt.wav" if is_female else "res://assets/audio/sfx/boss_male_hurt.wav")
			_show_floating_dmg(boss_platform, 1, Color(1, 0.3, 0.3))
		)
		tw.tween_property(pawn, "modulate:a", 0.0, 0.3)
		tw.tween_callback(func():
			pawn.queue_free()
			_animating_hero = false
			refresh()
		)

func _create_hero_pawn(hero: Dictionary, hp: int) -> Control:
	var ctrl := Control.new()
	ctrl.custom_minimum_size = Vector2(90, 115)

	var tex := TextureRect.new()
	tex.set_anchors_preset(Control.PRESET_FULL_RECT)
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var hid := str(hero.get("id", "")).to_lower()
	var sprite_path := "res://assets/ui/characters/heroes/%s_character.webp" % hid
	if ResourceLoader.exists(sprite_path):
		tex.texture = load(sprite_path)
	ctrl.add_child(tex)

	var hp_badge := Label.new()
	hp_badge.text = "%d PV" % hp
	hp_badge.add_theme_font_size_override("font_size", 14)
	hp_badge.add_theme_color_override("font_color", Color(1, 0.2, 0.2))
	hp_badge.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	hp_badge.add_theme_constant_override("outline_size", 3)
	hp_badge.position = Vector2(10, 0)
	ctrl.add_child(hp_badge)
	return ctrl

func _bump_slot(slot: Control) -> void:
	var orig_scale := slot.scale
	var tw := create_tween()
	tw.tween_property(slot, "scale", orig_scale * 1.08, 0.1)
	tw.tween_property(slot, "scale", orig_scale, 0.12)

func _show_floating_dmg(parent: Control, dmg: int, color := Color(1.0, 0.25, 0.25)) -> void:
	var lbl := Label.new()
	lbl.text = "-%d" % dmg
	lbl.add_theme_font_size_override("font_size", 22)
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	lbl.add_theme_constant_override("outline_size", 4)
	hero_crossing_layer.add_child(lbl)
	lbl.global_position = parent.global_position + Vector2(20, -10)

	var tw := create_tween()
	tw.tween_property(lbl, "position:y", lbl.position.y - 45.0, 0.55)
	tw.parallel().tween_property(lbl, "modulate:a", 0.0, 0.55)
	tw.tween_callback(func(): lbl.queue_free())

func _shake_node(node: Control) -> void:
	if node == null:
		return
	var orig_x := node.position.x
	var tw := create_tween()
	tw.tween_property(node, "position:x", orig_x - 10.0, 0.05)
	tw.tween_property(node, "position:x", orig_x + 10.0, 0.05)
	tw.tween_property(node, "position:x", orig_x - 5.0, 0.05)
	tw.tween_property(node, "position:x", orig_x + 5.0, 0.05)
	tw.tween_property(node, "position:x", orig_x, 0.05)

func _spawn_flying_soul(from_pos: Vector2, to_pos: Vector2) -> void:
	var t := TextureRect.new()
	t.custom_minimum_size = Vector2(26, 26)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if ResourceLoader.exists(TEX_SOUL):
		t.texture = load(TEX_SOUL)
	hero_crossing_layer.add_child(t)
	t.global_position = from_pos
	var tw := create_tween()
	tw.tween_property(t, "global_position", to_pos, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(t, "scale", Vector2.ZERO, 0.15)
	tw.tween_callback(func(): t.queue_free())

func _has_move(moves: Array, mtype: String) -> bool:
	for m in moves:
		if m is Dictionary and str((m as Dictionary).get("type", "")) == mtype:
			return true
	return false

func _moves_of(moves: Array, mtype: String) -> Array:
	var out: Array = []
	for m in moves:
		if m is Dictionary and str((m as Dictionary).get("type", "")) == mtype:
			out.append(m)
	return out

func _refresh_choice_bar(G: Dictionary, my_moves: Array) -> void:
	for c in choice_bar.get_children():
		c.queue_free()
	var pc: Dictionary = G.get("pendingChoice", {})
	if pc.is_empty() or int(pc.get("playerId", -1)) != _my_pid():
		choice_bar.visible = false
		discard_pick.clear()
		return
	if str(pc.get("type", "")) == "opening-discard":
		choice_bar.visible = false # carrousel central + bouton CONTINUE (_refresh_overlay)
		return
	choice_bar.visible = true
	var opts: Array = pc.get("options", [])
	var choice_moves := _moves_of(my_moves, "resolveChoice")
	if not choice_moves.is_empty():
		for m in choice_moves:
			var i: int = int((m as Dictionary).get("args", [0])[0])
			var b := Button.new()
			b.text = _option_label(opts, i)
			b.tooltip_text = str(pc.get("message", ""))
			var mv := (m as Dictionary).duplicate()
			b.pressed.connect(func():
				_play_sfx("res://assets/audio/sfx/ui_button_select.wav")
				_do(mv)
			)
			choice_bar.add_child(b)
		return
	for m in _moves_of(my_moves, "resolveLevelUpChoice"):
		var i: int = int((m as Dictionary).get("args", [0])[0])
		var b := Button.new()
		b.text = _option_label(opts, i)
		var mv := (m as Dictionary).duplicate()
		b.pressed.connect(func():
			_play_sfx("res://assets/audio/sfx/ui_button_select.wav")
			_do(mv)
		)
		choice_bar.add_child(b)

func _option_label(opts: Array, i: int) -> String:
	if i < 0:
		return "Passer"
	if i < opts.size() and opts[i] is Dictionary:
		var o: Dictionary = opts[i]
		for k in ["label", "name"]:
			if str(o.get(k, "")) != "":
				return str(o[k])
		if (o.get("card", {}) as Dictionary).get("name", "") != "":
			return str((o["card"] as Dictionary)["name"])
		if o.has("targetPlayerId"):
			return "Joueur %d" % (int(o["targetPlayerId"]) + 1)
	return "Choix %d" % (i + 1)

func _refresh_extra_bar(G: Dictionary, my_moves: Array) -> void:
	for c in extra_bar.get_children():
		c.queue_free()
	var shown := false
	var hand: Array = ((G.get("players", {}) as Dictionary).get(_my_pid(), {}) as Dictionary).get("hand", [])
	var pc: Dictionary = G.get("pendingChoice", {})
	if not pc.is_empty():
		extra_bar.visible = false
		return
	for m in my_moves:
		if not (m is Dictionary) or str((m as Dictionary).get("type", "")) in CORE_MOVE_TYPES:
			continue
		var b := Button.new()
		b.text = _move_label(m, G, hand)
		var mv := (m as Dictionary).duplicate()
		b.pressed.connect(func():
			_play_sfx("res://assets/audio/sfx/ui_button_select.wav")
			_do(mv)
		)
		extra_bar.add_child(b)
		shown = true
	extra_bar.visible = shown

func _move_label(m: Dictionary, _G: Dictionary, hand: Array) -> String:
	var t := str(m.get("type", ""))
	var args: Array = m.get("args", [])
	var hand_name := ""
	if not args.is_empty() and args[0] is int and int(args[0]) >= 0 and int(args[0]) < hand.size():
		hand_name = str((hand[int(args[0])] as Dictionary).get("name", ""))
	match t:
		"playSpell":
			# Counterspell : une entree par sort adverse en attente, on nomme la cible.
			if args.size() > 1 and args[1] is Dictionary and (args[1] as Dictionary).has("stackId"):
				return "Sort : %s -> %s" % [hand_name, str((((args[1] as Dictionary).get("card", {})) as Dictionary).get("name", "?"))]
			# The Next Level : la cible (salle, joueur, heros...) est decrite, sinon plusieurs boutons identiques.
			if hand_name != "" and args.size() > 1 and args[1] is Dictionary and TnlSpells.TARGETS.has(str((hand[int(args[0])] as Dictionary).get("id", ""))):
				var desc := TnlSpells.describe_target(_G, args[1])
				return "Sort : %s -> %s" % [hand_name, desc] if desc != "" else "Sort : %s" % hand_name
			if hand_name != "" and args.size() > 1 and args[1] is Dictionary and RmbSpells.TARGETS.has(str((hand[int(args[0])] as Dictionary).get("id", ""))):
				var rdesc := RmbSpells.describe_target(_G, args[1])
				return "Sort : %s -> %s" % [hand_name, rdesc] if rdesc != "" else "Sort : %s" % hand_name
			return "Sort : %s" % hand_name
		"activateRoom":
			var dgn: Array = ((_G.get("players", {}) as Dictionary).get(_my_pid(), {}) as Dictionary).get("dungeon", [])
			var ri := int(args[0]) if not args.is_empty() else -1
			var rv = BossEngine.active_room(dgn[ri]) if ri >= 0 and ri < dgn.size() else null
			return "Capacité : %s" % (str((rv as Dictionary).get("name", "?")) if rv != null else hand_name)
		"useHandRoom":
			return "Capacité : %s" % hand_name
		"buildMiniboss", "promoteMiniboss", "activateMiniboss":
			var mdg: Array = ((_G.get("players", {}) as Dictionary).get(_my_pid(), {}) as Dictionary).get("dungeon", [])
			var mslot := int(args[1]) if t == "buildMiniboss" else int(args[0])
			var mroom = BossEngine.active_room(mdg[mslot]) if mslot >= 0 and mslot < mdg.size() else null
			var rname := str((mroom as Dictionary).get("name", "?")) if mroom != null else "?"
			if t == "buildMiniboss":
				return "Miniboss : %s -> sur %s (face cachée, 1 pièce pour la révéler)" % [hand_name, rname]
			var mname := Minibosses.mb_name(Minibosses.mb_of(mroom))
			if t == "promoteMiniboss":
				var alt := int(args[1]) if args.size() > 1 else -1
				return "Promouvoir %s (%s)" % [mname, "1 pièce" if alt < 0 else "défausse %s" % str((hand[alt] as Dictionary).get("name", "?"))]
			return "%s : pouvoir niveau %d" % [mname, int(args[1])]
		"discardForCoin":
			return "Défausser %s : +1 pièce" % hand_name
		"rmbBoss":
			return "Boss : %s (%s)" % [str(args[0]), "annuler le +1 des pièges" if str(args[0]) == "RMB011" else "2 pièces"]
		"rmbHand":
			return "Capacité : %s%s" % [hand_name, " (%s)" % str(args[1]) if args.size() > 1 and str(args[1]) != "" else ""]
		"rmbPay":
			return "Payer 1 pièce (Paywall)"
		"rmbCancel":
			return "Mageseeker : défausse %s, annule le sort" % (str((hand[int(args[1])] as Dictionary).get("name", "?")) if args.size() > 1 and int(args[1]) < hand.size() else "?")
		"payDarkHero":
			return "Payer %s (héros noir)" % hand_name
		"docScarecrow":
			var town: Array = _G.get("town", [])
			var ti := int(args[1]) if args.size() > 1 else -1
			return "Épouvantail : %s -> %s" % [hand_name, str((town[ti] as Dictionary).get("name", "?")) if ti >= 0 and ti < town.size() else "?"]
		"timebenderCancel":
			return "Dr. Timebender : défausse %s, annule le sort" % hand_name
		"antimagicCancel":
			return "Antimagic Zone : annule le sort"
		_:
			return hand_name if hand_name != "" else t

func _do(move: Dictionary) -> void:
	if game_manager.apply_move(_my_pid(), move):
		refresh()

func _on_hand_card_clicked(idx: int, card: Dictionary) -> void:
	if _is_opening_discard_for_me():
		if discard_pick.has(idx):
			discard_pick.erase(idx)
		elif discard_pick.size() < 2:
			discard_pick.append(idx)
		_play_sfx("res://assets/audio/sfx/ui_button_select.wav")
		refresh()
		return
	var phase: String = game_manager.G.get("phase", "")
	if (phase == "build" or phase == "setup") and card.get("isRoom", false):
		var dungeon: Array = ((game_manager.G["players"] as Dictionary)[_my_pid()] as Dictionary).get("dungeon", [])
		var target_slot := dungeon.size()
		_play_sfx("res://assets/audio/sfx/sfx_room_physical.wav")
		if game_manager.build_room_at(_my_pid(), idx, target_slot):
			refresh() # apply_move n'emet pas toujours state_changed en fin de coup (transition de phase)
	elif phase == "build" and card.get("isSpell", false):
		_play_spell_from_hand(idx)

func _play_spell_from_hand(idx: int) -> void:
	var pid := _my_pid()
	for mv in game_manager.legal_moves(pid):
		var m: Dictionary = mv
		if str(m.get("type", "")) != "playSpell":
			continue
		var args: Array = m.get("args", [])
		if not args.is_empty() and int(args[0]) == idx:
			_play_sfx("res://assets/audio/sfx/sfx_room_magic.wav")
			if game_manager.apply_move(pid, m):
				refresh()
			return

func _on_discard_confirm() -> void:
	if discard_pick.size() != 2:
		return
	var pair := discard_pick.duplicate()
	pair.sort()
	_play_sfx("res://assets/audio/sfx/ui_card_flip.wav")
	_do({"type": "openingDiscard", "args": pair})
	discard_pick.clear()

func _is_opening_discard_for_me() -> bool:
	var pc: Dictionary = game_manager.G.get("pendingChoice", {})
	return str(pc.get("type", "")) == "opening-discard" and int(pc.get("playerId", -1)) == _my_pid()

func _on_advance_pressed() -> void:
	_play_sfx("res://assets/audio/sfx/char_hero_move.wav")
	if _is_online():
		_do({"type": "resolveNextHero", "args": []})
	else:
		game_manager.apply_move(_my_pid(), {"type": "adventureNext", "args": []})
		refresh()

func _on_pass_pressed() -> void:
	_play_sfx("res://assets/audio/sfx/ui_button_select.wav")
	if _is_online():
		_do({"type": "pass", "args": []})
	else:
		if game_manager.apply_move(_my_pid(), {"type": "passBuild", "args": []}):
			refresh()

func _on_menu_pressed() -> void:
	_play_sfx("res://assets/audio/sfx/ui_button_goback.wav")
	if on_exit_callback.is_valid():
		on_exit_callback.call()

func _on_discard_pile_pressed() -> void:
	_play_sfx("res://assets/audio/sfx/ui_button_select.wav")
	var decks: Dictionary = game_manager.G.get("decks", {})
	var r_disc: Array = decks.get("roomDiscard", [])
	var s_disc: Array = decks.get("spellDiscard", [])
	var h_disc: Array = decks.get("heroDiscard", [])

	var dialog := AcceptDialog.new()
	dialog.title = "DÉFAUSSES (DISCARD PILES)"
	dialog.size = Vector2i(700, 480)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)

	var lbl := Label.new()
	lbl.text = "Salles défaussées (%d) :\n%s\n\nSorts défaussés (%d) :\n%s\n\nHéros morts (%d) :\n%s" % [
		r_disc.size(),
		", ".join(r_disc.map(func(c): return str((c as Dictionary).get("name", "?")))),
		s_disc.size(),
		", ".join(s_disc.map(func(c): return str((c as Dictionary).get("name", "?")))),
		h_disc.size(),
		", ".join(h_disc.map(func(c): return str((c as Dictionary).get("name", "?"))))
	]
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(660, 400)
	scroll.add_child(lbl)
	vbox.add_child(scroll)
	dialog.add_child(vbox)
	add_child(dialog)
	dialog.popup_centered()

func _on_level_up_pressed() -> void:
	_play_sfx("res://assets/audio/sfx/sting_levelup.wav")
	# Si un choix de level-up est en attente, le mettre en surbrillance
	var pc: Dictionary = game_manager.G.get("pendingChoice", {})
	if not pc.is_empty():
		choice_bar.modulate = Color(1.5, 1.5, 0.5, 1.0)

func _get_total_dungeon_damage(player_dict: Dictionary) -> int:
	var total := 0
	for stack in player_dict.get("dungeon", []):
		var r = BossEngine.active_room(stack)
		if r != null and not bool((r as Dictionary).get("faceDown", false)):
			total += int((r as Dictionary).get("damage", 0))
	return total
