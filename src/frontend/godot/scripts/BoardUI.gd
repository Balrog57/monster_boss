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
var foe_bar: HBoxContainer               # selecteur d'adversaire (3-4 joueurs) : TopRightPanel.ChangeVisibleBoss de l'APK
var foe_pid: int = -1                    # adversaire dont le donjon occupe le couloir du haut
var _foe_follow_seen := -1               # dernier donjon adverse suivi automatiquement (aventure en cours)
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
const FONT_A := "res://assets/fonts/arcadepix.fnt"
const FONT_B := "res://assets/fonts/arcadepix2.fnt"

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
const HAND_CARD := Vector2(210, 300)     # APK : ~210x300 a 1920x1080, tres chevauchees, bas de carte sous le bord de l'ecran
const BIG_CARD := Vector2(232, 324)
const BOSS_SPRITE_SCALE := 1.0           # APK : sprite du boss a sa taille native (King Croak ~175 px, Cleopatra ~200 px sur l'estrade)
const BOSS_SPRITE_MAX_W := 300.0         # largeur de l'estrade : un sprite plus large (KSA005, 333 px) est reduit pour ne pas deborder
const BOSS_CARD := Vector2(362, 506)     # carrousel du choix du boss (apk_boss00) : carte centrale ; les voisines sont reduites et se chevauchent
const BOSS_SIDE_SCALE := [1.0, 0.58, 0.55, 0.52, 0.5, 0.48]
const BOSS_SIDE_X := [0.0, 272.0, 342.0, 378.0, 396.0, 406.0]
const BOSS_CENTER_Y := 562.0
const TEX_TARGET_GLOW := "res://assets/ui/ingame/card_border_yellow_glow.webp"
const TARGET_Z := 60                     # salles / heros / boss ciblables : passent devant le voile du mode ciblage (z 40)
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
var _popup: Control                      # fenetre modale courante (choix, cibles, options, confirmation)
var _popup_kind := ""                    # "choice" | "target" | "menu" | "quit"
var _choice_sig := ""
var _rules: Control                      # RulesViewer superpose au plateau (null si ferme)
var _auto_timer := 0.0                   # delai avant une passe automatique (aventure, rien a decider)
var _hero_pawn: Control                  # pion du heros en aventure : persiste d'une salle a l'autre
var _hero_pawn_hp: Label
var _adv_seen := {}                      # dernier pas d'aventure anime : {pid, hid, room, hp}
var _stone_theme_cache: Theme
# Choix de la cible sur le plateau : {} = inactif ; sinon {pid, title, hint, entries: [{label, cb, mv, spot}]}.
var _tgt: Dictionary = {}
var _tgt_layer: Control                  # voile + bulle + CANCEL + zones cliquables (un Control par cible affichee)
var _tgt_cancel_btn: Button
var _tgt_spots: Array = []               # [{ctrl, ids}] : ids = indices dans _tgt.entries atteints par cette zone
var _tgt_lifted: Array = []              # noeuds du plateau passes devant le voile (remis a z 0 a la fin)
var _town_scroll: ScrollContainer
var _ent_tok: Dictionary = {}            # pid -> jetons de l'entree, alignes sur les heros de `entrance` (null = pion en marche)
# Carrousel du choix du boss
var _boss_sel := 0
var _boss_cards: Array = []
var _boss_drag := {}
const PASS_TYPES := ["pass", "passBuild"]
const GO_TYPES := ["adventureNext", "resolveNextHero"]
const HAND_CLICK_TYPES := ["playSpell", "useHandRoom"] # jouees en cliquant la carte de la main (pas de bouton)

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
	_town_scroll = scroll
	scroll.position = Vector2(14, 96)
	scroll.size = Vector2(160, 806)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	add_child(scroll)
	scroll.get_v_scroll_bar().value_changed.connect(func(_v: float): _target_apply()) # les zones de ciblage des heros suivent le defilement
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
	# Coups propres aux extensions du wiki (aucun equivalent APK) : cachee tant qu'il n'y en a pas.
	bar_box = VBoxContainer.new()
	bar_box.position = Vector2(330, 548)
	bar_box.size = Vector2(1270, 80)
	bar_box.alignment = BoxContainer.ALIGNMENT_BEGIN
	bar_box.theme = _make_bar_theme()
	add_child(bar_box)
	extra_bar = HFlowContainer.new()
	extra_bar.alignment = FlowContainer.ALIGNMENT_CENTER
	extra_bar.add_theme_constant_override("h_separation", 8)
	extra_bar.add_theme_constant_override("v_separation", 6)
	bar_box.add_child(extra_bar)

## Boutons « pierre » de l'APK (buttons/button.webp en 9-patch) : seat bar, CONTINUE, popups de choix.
func _make_bar_theme() -> Theme:
	if _stone_theme_cache != null:
		return _stone_theme_cache
	var th := Theme.new()
	var tex_n := _tex("res://assets/ui/buttons/button.webp")
	var tex_p := _tex("res://assets/ui/buttons/button_pressed.webp")
	for n in ["normal", "hover", "pressed", "disabled", "focus"]:
		if n == "focus":
			th.set_stylebox(n, "Button", StyleBoxEmpty.new())
			continue
		var sb := StyleBoxTexture.new()
		sb.texture = tex_p if n == "pressed" and tex_p != null else tex_n
		sb.set_texture_margin_all(26)
		sb.content_margin_left = 30
		sb.content_margin_right = 30
		sb.content_margin_top = 12
		sb.content_margin_bottom = 12
		if n == "hover":
			sb.modulate_color = Color(1.3, 1.25, 1.05)
		elif n == "disabled":
			sb.modulate_color = Color(0.55, 0.55, 0.55)
		th.set_stylebox(n, "Button", sb)
	th.set_font("font", "Button", _fb)
	th.set_font_size("font_size", "Button", 24)
	th.set_color("font_color", "Button", Color.WHITE)
	th.set_color("font_hover_color", "Button", GOLD)
	th.set_color("font_pressed_color", "Button", GOLD)
	_stone_theme_cache = th
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
	top_menu_btn.tooltip_text = "Options"
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
	# Selecteur d'adversaire : a gauche de l'engrenage, visible seulement s'il y a plusieurs adversaires
	foe_bar = HBoxContainer.new()
	foe_bar.position = Vector2(1500, 8)
	foe_bar.size = Vector2(340, 50)
	foe_bar.alignment = BoxContainer.ALIGNMENT_END
	foe_bar.add_theme_constant_override("separation", 8)
	foe_bar.theme = _make_bar_theme()
	foe_bar.visible = false
	add_child(foe_bar)

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
	_confirm_btn.pressed.connect(_on_confirm_pressed)
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

## Adversaires du siege affiche (ordre des sieges) ; foe_pid reste valide et suit l'aventure en cours (l'animation doit se jouer
## dans le couloir visible : sans cela, a 3-4 joueurs, seul le premier adversaire etait jamais montre).
func _update_foe(G: Dictionary) -> Array:
	var others: Array = (G["players"] as Dictionary).keys().map(func(k): return int(k)).filter(func(k): return k != view_pid)
	others.sort()
	var follow := -1
	var lhf = G.get("lastHeroFight")
	var adv: Dictionary = G.get("adventure", {})
	if lhf != null and lhf is Dictionary:
		follow = int(lhf.get("pid", -1))
	elif not adv.is_empty() and adv.get("hero") != null:
		follow = int(adv.get("playerId", -1))
	if follow != _foe_follow_seen:
		_foe_follow_seen = follow
		if others.has(follow):
			foe_pid = follow
	if not others.has(foe_pid):
		foe_pid = int(others[0]) if not others.is_empty() else -1
	return others

func _refresh_foe_bar(others: Array) -> void:
	for c in foe_bar.get_children():
		foe_bar.remove_child(c)
		c.queue_free()
	foe_bar.visible = others.size() > 1
	if others.size() <= 1:
		return
	for pid in others:
		var b := Button.new()
		b.text = "P%d" % (int(pid) + 1)
		b.disabled = int(pid) == foe_pid
		var boss = ((game_manager.G["players"] as Dictionary)[pid] as Dictionary).get("boss")
		b.tooltip_text = "Player %d%s" % [int(pid) + 1, " - %s" % str((boss as Dictionary).get("name", "")) if boss != null else ""]
		var p: int = int(pid)
		b.set_meta("pid", p)
		b.pressed.connect(func():
			if _animating_hero or (_hero_pawn != null and is_instance_valid(_hero_pawn)):
				return # un heros traverse le donjon affiche
			foe_pid = p
			refresh())
		foe_bar.add_child(b)

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
		slot.activate_requested.connect(_on_slot_activate)
		slot.room_dropped.connect(func(_h: int, _s: int):
			_play_sfx("res://assets/audio/sfx/sfx_room_physical.wav")
			refresh())
		_dungeon_slots.append(slot)

func _process(delta: float) -> void:
	if game_manager == null or game_manager.G.get("gameOver") != null:
		return
	if _animating_hero:
		return
	if _modal_open() and not _is_online():
		return # menu / regles ouverts : la partie locale est en pause
	if _auto_pass(delta):
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
			if _ai_timer > (0.2 if adv_turn else 0.5):
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

func _modal_open() -> bool:
	return (_popup != null and is_instance_valid(_popup) and (_popup_kind == "menu" or _popup_kind == "quit")) 		or (_rules != null and is_instance_valid(_rules))

## Un coup « decision » = tout sauf passer / avancer (sort, capacite de salle, coups d'extension...).
func _has_decision(moves: Array) -> bool:
	for m in moves:
		var t := str((m as Dictionary).get("type", ""))
		if not (t in PASS_TYPES or t in GO_TYPES):
			return true
	return false

## Automatisation UI de l'aventure (aucune regle changee) : quand un humain n'a RIEN a decider (seulement passer),
## les fenetres de pause apres degats / avant sortie et les passes hors tour se referment toutes seules.
## Le joueur n'appuie que sur GO (un pas de heros) ; PASS TURN n'apparait que s'il peut encore jouer un sort / une capacite.
func _auto_pass(delta: float) -> bool:
	var G: Dictionary = game_manager.G
	if str(G.get("phase", "")) != "adventure" or not (G.get("pendingChoice", {}) as Dictionary).is_empty():
		_auto_timer = 0.0
		return false
	var pids: Array = []
	if _is_online():
		pids = [_my_pid()]
	else:
		for pid in (G.get("players", {}) as Dictionary):
			if not bool(((G["players"] as Dictionary)[pid] as Dictionary).get("isAI", false)):
				pids.append(int(pid))
		var act_pid: int = game_manager.active_player()
		if pids.has(act_pid): # plusieurs humains (hotseat) : le joueur actif d'abord, sinon un siege qui peut toujours « passer » affame les autres
			pids.erase(act_pid)
			pids.push_front(act_pid)
	var in_pause: bool = (G.get("adventure", {}) as Dictionary).get("pause") != null
	for pid in pids:
		# Hors fenetre de pause, un « passe » d'un siege qui n'est pas le joueur actif ferait avancer le pointeur de joueur en pleine
		# traversee d'un autre donjon (le moteur le propose quand meme) : l'UI ne passe automatiquement qu'a son tour.
		if not in_pause and int(pid) != game_manager.active_player():
			continue
		var moves: Array = game_manager.legal_moves(int(pid))
		if moves.is_empty() or _has_decision(moves):
			continue
		var has_go := false
		var pass_mv = null
		for m in moves:
			var t := str((m as Dictionary).get("type", ""))
			if t in GO_TYPES:
				has_go = true
			elif t in PASS_TYPES and pass_mv == null:
				pass_mv = m
		if has_go or pass_mv == null:
			continue
		_auto_timer += delta
		if _auto_timer < 0.45:
			return false # on laisse les IA passer pendant ce temps
		_auto_timer = 0.0
		if game_manager.apply_move(int(pid), (pass_mv as Dictionary).duplicate()):
			refresh()
		return true
	_auto_timer = 0.0
	return false

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
	var others := _update_foe(G)
	_refresh_foe_bar(others)

	var p: Dictionary = (G["players"] as Dictionary)[view_pid]
	var phase: String = G.get("phase", "")

	# Animation de combat / traversée héroïque si en attente
	var lhf = G.get("lastHeroFight")
	if lhf != null and lhf is Dictionary and not _animating_hero:
		G.erase("lastHeroFight")
		_play_hero_crossing_animation(lhf)
	_track_adventure(G)

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

	var foe_dict: Dictionary = {}
	if foe_pid >= 0:
		foe_dict = (G["players"] as Dictionary)[foe_pid]
		if phase == "boss" and p.get("boss") == null: # l'APK cache le boss adverse tant que le notre n'est pas choisi
			foe_dict = foe_dict.duplicate()
			foe_dict["boss"] = null

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

	var my_moves: Array = game_manager.legal_moves(_my_pid())
	_refresh_foe_dungeon(foe_dict)
	_refresh_overlay(G, phase)
	_refresh_hand(G, p, phase, my_moves)
	_refresh_activatable(my_moves)

	_target_sync(my_moves)
	var carousel := _carousel_active(G, phase)
	action_box.visible = not carousel and G.get("gameOver") == null and _tgt.is_empty() # plus rien a jouer a l'ecran de fin ; CANCEL remplace PASS TURN en ciblage
	var can_go := _has_any(my_moves, GO_TYPES)
	var can_pass := _has_any(my_moves, PASS_TYPES)
	btn_advance.visible = phase == "adventure" or can_go
	btn_advance.disabled = not can_go
	btn_advance.modulate = Color.WHITE if can_go else Color(0.5, 0.5, 0.5, 0.75)
	if phase == "adventure": # PASS TURN seulement s'il reste quelque chose a decider (sort / capacite)
		btn_pass.visible = can_pass and _has_decision(my_moves)
	else:
		btn_pass.visible = can_pass # pas de PASS TURN quand passer est illegal (choix en attente, pas mon tour de construire)
	_refresh_choice_popup(G, my_moves)
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
	_confirm_btn.visible = boss_pick or (discard and discard_pick.size() == 2) or over # fin de partie : le meme bouton ramene au menu
	_confirm_btn.text = "PLAY BOSS MONSTER!" if boss_pick else ("MENU" if over else "CONTINUE")
	# APK : PLAY BOSS MONSTER! est une grande pierre au centre du bas de l'ecran (apk game_01_boss), CONTINUE reste plus petit.
	_confirm_btn.custom_minimum_size = Vector2(400, 92) if boss_pick else Vector2(220, 54)
	_confirm_btn.size = _confirm_btn.custom_minimum_size
	_confirm_btn.add_theme_font_size_override("font_size", 28 if boss_pick else 24)
	_confirm_btn.position = Vector2(PLAY_CX - 200, 923) if boss_pick else Vector2(PLAY_CX - 110, 730)
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
		town_container.remove_child(c) # tout de suite : les zones de ciblage lisent les positions des nouvelles cartes
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
			box.remove_child(c)
			c.queue_free()
		var adv: Dictionary = game_manager.G.get("adventure", {})
		var adv_pl = (game_manager.G.get("players", {}) as Dictionary).get(int(adv.get("playerId", -1))) if not adv.is_empty() else null
		var walking: bool = adv_pl != null and is_same(adv_pl, r[1]) and _hero_pawn != null and is_instance_valid(_hero_pawn)
		var skipped := false
		var toks: Array = []
		for hero in (r[1] as Dictionary).get("entrance", []):
			if walking and not skipped and hero == adv.get("hero"): # ce heros est deja le pion qui traverse le donjon
				skipped = true
				toks.append(null)
				continue
			var tok := _create_mini_hero_token(hero)
			box.add_child(tok)
			toks.append(tok)
		_ent_tok[view_pid if int(r[0]) == 1 else foe_pid] = toks

func _create_mini_hero_token(hero: Dictionary) -> Control:
	var c := TextureRect.new()
	c.custom_minimum_size = Vector2(90, 90)
	c.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	c.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var hid := str(hero.get("id", "")).to_lower()
	var sprite_path := "res://assets/ui/characters/heroes/%s_character.webp" % hid
	if ResourceLoader.exists(sprite_path):
		c.texture = load(sprite_path)
	c.tooltip_text = "%s (HP: %s)" % [str(hero.get("name", "Hero")), str(hero.get("health", 4))]
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
		sprite.size = tex.get_size() * minf(BOSS_SPRITE_SCALE, BOSS_SPRITE_MAX_W / tex.get_size().x)
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
				room_ui.add_lane_badge()
				if Minibosses.active(game_manager.G): # Rise of the Minibosses : le miniboss de la salle adverse (nom cache tant qu'il est face cache)
					var mb_badge := Minibosses.make_badge(r, false)
					if mb_badge != null:
						slot_ctrl.add_child(mb_badge)
						slot_ctrl.tooltip_text = Minibosses.badge_tooltip(r, false)
		holder.add_child(slot_ctrl)
		_foe_slots.append(slot_ctrl)

## Main du joueur : eventail en bas ; carrousel central pour le choix du boss et la defausse d'ouverture.
func _refresh_hand(G: Dictionary, p: Dictionary, phase: String, my_moves: Array) -> void:
	for c in hand_layer.get_children():
		c.queue_free()
	_boss_cards.clear()

	if G.get("gameOver") != null:
		return
	if phase == "boss":
		_build_boss_carousel(G.get("bossPicks", []))
		return

	# Cartes jouables maintenant (construire / sort / capacite de la main) : les autres sont grisees comme dans l'APK.
	var playable: Dictionary = {}
	for m in my_moves:
		var mt := str((m as Dictionary).get("type", ""))
		var ma: Array = (m as Dictionary).get("args", [])
		if mt in ["buildRoom", "playSpell", "useHandRoom"] and not ma.is_empty() and ma[0] is int:
			playable[int(ma[0])] = true
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
		elif not discarding and (phase == "build" or phase == "setup" or phase == "adventure") and not playable.has(i):
			card_ui.set_greyed(true) # APK : carte injouable = grisee (toute la main pendant l'aventure sans sort jouable)
		cards.append(card_ui)
	if discarding:
		_place_cards(cards, sz, 125.0, 1000.0, 338.0, false)
		for i in cards.size():
			if discard_pick.has(i):
				(cards[i] as Control).position.y -= 30.0
	else:
		_place_cards(cards, sz, 150.0, 1190.0, 832.0, true)

func _spawn_card(data: Dictionary, hand_idx: int, sz: Vector2) -> Control:
	var card_ui = _card_scene.instantiate()
	card_ui.default_size = sz
	hand_layer.add_child(card_ui)
	card_ui.size = sz
	card_ui.setup(data, hand_idx)
	return card_ui

# --- Choix du boss : carrousel (apk_boss00) ; une carte au centre, les autres reduites et chevauchees de part et d'autre.
# Clic sur une voisine ou glisser pour la ramener au centre ; PLAY BOSS MONSTER! valide la carte centrale. Le boss adverse reste cache.

func _boss_card_rect(d: int) -> Rect2:
	var k := mini(absi(d), BOSS_SIDE_X.size() - 1)
	var sz := BOSS_CARD * float(BOSS_SIDE_SCALE[k])
	return Rect2(Vector2(PLAY_CX + signf(d) * float(BOSS_SIDE_X[k]) - sz.x / 2.0, BOSS_CENTER_Y - sz.y / 2.0), sz)

func _build_boss_carousel(picks: Array) -> void:
	_boss_cards.clear()
	_boss_sel = clampi(_boss_sel, 0, maxi(picks.size() - 1, 0))
	for i in picks.size():
		var c = _spawn_card(picks[i], -1, BOSS_CARD)
		c.custom_minimum_size = Vector2.ZERO # la taille change avec la distance au centre
		c.mouse_entered.disconnect(c._on_mouse_entered) # pas de zoom / premier plan au survol : l'ordre du carrousel prime
		c.mouse_exited.disconnect(c._on_mouse_exited)
		var idx := i
		c.card_clicked.connect(func(_data): _boss_select(idx))
		_boss_cards.append(c)
	_boss_layout(false)

func _boss_layout(animate: bool) -> void:
	var order: Array = range(_boss_cards.size())
	order.sort_custom(func(a: int, b: int): return absi(a - _boss_sel) > absi(b - _boss_sel)) # la plus eloignee au fond
	for k in order.size():
		var c: Control = _boss_cards[int(order[k])]
		hand_layer.move_child(c, k)
		var d: int = int(order[k]) - _boss_sel
		var r := _boss_card_rect(d)
		var shade := 1.0 - 0.08 * float(maxi(absi(d) - 1, 0))
		if c.has_meta("tw"):
			(c.get_meta("tw") as Tween).kill()
		if animate and not skip_animations:
			var tw := c.create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tw.tween_property(c, "position", r.position, 0.22)
			tw.tween_property(c, "size", r.size, 0.22)
			tw.tween_property(c, "modulate", Color(shade, shade, shade), 0.22)
			c.set_meta("tw", tw)
		else:
			c.position = r.position
			c.size = r.size
			c.modulate = Color(shade, shade, shade)

func _boss_select(i: int) -> void:
	i = clampi(i, 0, _boss_cards.size() - 1)
	if i == _boss_sel or _boss_cards.is_empty():
		return
	_boss_sel = i
	_play_sfx("res://assets/audio/sfx/ui_button_select.wav")
	_boss_layout(true)

## PLAY BOSS MONSTER! : le boss de la carte centrale est le notre.
func _boss_confirm() -> void:
	var picks: Array = game_manager.G.get("bossPicks", [])
	if picks.is_empty():
		return
	var bid := str((picks[clampi(_boss_sel, 0, picks.size() - 1)] as Dictionary).get("id", ""))
	var is_fem := ["BMA006", "BMA007", "BMA008"].has(bid)
	_play_sfx("res://assets/audio/sfx/boss_female_intro.wav" if is_fem else "res://assets/audio/sfx/boss_male_intro.wav")
	_boss_sel = 0
	_do({"type": "pickBoss", "args": [bid]})

## Glisser horizontalement dans la zone des cartes : un cran tous les 90 px (gauche = carte suivante).
func _input(event: InputEvent) -> void:
	if _boss_cards.is_empty():
		return
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var pos := get_local_mouse_position()
		_boss_drag = {"x": pos.x} if (event as InputEventMouseButton).pressed and Rect2(184, 280, 1523, 600).has_point(pos) else {}
	elif event is InputEventMouseMotion and not _boss_drag.is_empty():
		var dx := get_local_mouse_position().x - float(_boss_drag["x"])
		if absf(dx) >= 90.0:
			_boss_drag["x"] = get_local_mouse_position().x
			_boss_select(_boss_sel - int(signf(dx)))

## Aligne les cartes (chevauchement si necessaire) autour de PLAY_CX ; `fan` : eventail (cartes legerement tournees vers
## l'exterieur, bords plus bas) ; la carte survolee monte en entier, se redresse et passe au premier plan (z_index de CardUI).
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
			y += pow(i - mid, 2.0) * 1.4
			c.rotation_degrees = (i - mid) * 1.6
			(c as CardUI).hover_scale = 1.04
		c.position = Vector2(x0 + step * i, y)
		if fan:
			var base_y := y
			var base_rot := c.rotation_degrees
			var up_y := 1080.0 - sz.y - 4.0 # carte entierement visible
			c.mouse_entered.connect(func():
				var tw := c.create_tween().set_parallel(true)
				tw.tween_property(c, "position:y", up_y, 0.12)
				tw.tween_property(c, "rotation_degrees", 0.0, 0.12))
			c.mouse_exited.connect(func():
				var tw := c.create_tween().set_parallel(true)
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
		deck_info_label.text = "COINS: %d" % Minibosses.coins(p)
		foe_coins_label.text = "COINS: %d" % Minibosses.coins(foe)

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

	if pid != view_pid and pid != foe_pid:
		return # donjon qui n'est pas a l'ecran
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

	# Pion du heros : celui qui vient de traverser le donjon pas a pas, sinon un nouveau (a la salle de sa mort, ou a l'entree)
	var pawn: Control = _hero_pawn
	if pawn == null or not is_instance_valid(pawn):
		pawn = _create_hero_pawn(hero, initial_hp)
		hero_crossing_layer.add_child(pawn)
		var death_idx: int = int(lhf.get("deathIndex", -1))
		if killed and death_idx >= 0 and death_idx + vis_off < slots_list.size():
			pawn.global_position = (slots_list[death_idx + vis_off] as Control).global_position + Vector2(15, 20)
		else:
			pawn.global_position = entrance_ctrl.global_position + Vector2(10, 10)
	_hero_pawn = null
	_hero_pawn_hp = null

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

## Suit l'aventure en cours : chaque nouveau pas du moteur (heros entre dans une salle) = le pion marche jusqu'a la salle,
## les degats flottent, les PV du pion baissent. Aucune regle : on ne fait que comparer l'etat avec le pas deja montre.
func _track_adventure(G: Dictionary) -> void:
	var adv: Dictionary = G.get("adventure", {})
	if adv.is_empty() or adv.get("hero") == null:
		_adv_seen = {}
		if _hero_pawn != null and not _animating_hero: # heros parti sans combat final montre (sort, renvoi en ville) : plus de pion
			if is_instance_valid(_hero_pawn):
				_hero_pawn.queue_free()
			_hero_pawn = null
			_hero_pawn_hp = null
		return
	var hero: Dictionary = adv["hero"]
	var cur := {"pid": int(adv.get("playerId", 0)), "hid": str(hero.get("id", "")), "room": int(adv.get("roomIndex", -1)), "hp": int(adv.get("hp", 0))}
	if _adv_seen == cur:
		return
	var same_hero: bool = not _adv_seen.is_empty() and _adv_seen["pid"] == cur["pid"] and _adv_seen["hid"] == cur["hid"]
	var prev_room: int = int(_adv_seen["room"]) if same_hero else -1
	var prev_hp: int = int(_adv_seen["hp"]) if same_hero else BossEngine.hero_hp(hero)
	_adv_seen = cur
	if skip_animations or _animating_hero or (cur["pid"] != view_pid and cur["pid"] != foe_pid):
		return
	if cur["room"] == prev_room and cur["hp"] == prev_hp and same_hero:
		return
	_animate_step(hero, int(cur["pid"]), prev_room, int(cur["room"]), prev_hp, int(cur["hp"]))

func _lane_slots(pid: int) -> Array:
	return _dungeon_slots if pid == view_pid else _foe_slots

func _slot_at(pid: int, room: int) -> Control:
	if room < 0:
		return null
	var dng_size: int = ((game_manager.G.get("players", {}) as Dictionary).get(pid, {}) as Dictionary).get("dungeon", []).size()
	var vis: int = room + maxi(0, CardDB.DUNGEON_SLOTS - dng_size)
	var slots: Array = _lane_slots(pid)
	if vis >= 0 and vis < slots.size() and is_instance_valid(slots[vis]):
		return slots[vis]
	return null

func _step_target(pid: int, room: int) -> Vector2:
	var L: Dictionary = _lane[1 if pid == view_pid else 0]
	if room < 0:
		return (L["entrance"] as Control).global_position + Vector2(10, 10)
	var sl := _slot_at(pid, room)
	if sl != null:
		return sl.global_position + Vector2(15, 20)
	return (L["platform"] as Control).global_position + Vector2(25, 25)

func _animate_step(hero: Dictionary, pid: int, from_room: int, to_room: int, hp_before: int, hp_after: int) -> void:
	_animating_hero = true
	if _hero_pawn == null or not is_instance_valid(_hero_pawn):
		_hero_pawn = _create_hero_pawn(hero, hp_before)
		_hero_pawn_hp = _hero_pawn.get_node("Hp")
		hero_crossing_layer.add_child(_hero_pawn)
		_hero_pawn.global_position = _step_target(pid, -1)
		refresh_entrance_only()
	var pawn := _hero_pawn
	var hp_lbl := _hero_pawn_hp
	var target := _step_target(pid, to_room)
	var dmg := hp_before - hp_after
	var lane_idx := 1 if pid == view_pid else 0
	var tw := create_tween()
	tw.tween_callback(func(): _play_sfx("res://assets/audio/sfx/char_hero_move.wav"))
	tw.tween_property(pawn, "global_position", target, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback(func():
		var room_ctrl: Control = _slot_at(pid, to_room) # les emplacements adverses sont reconstruits a chaque refresh : on ne garde pas de reference
		if dmg > 0 and room_ctrl != null:
			var dgn: Array = ((game_manager.G.get("players", {}) as Dictionary).get(pid, {}) as Dictionary).get("dungeon", [])
			var room_dict = BossEngine.active_room(dgn[to_room]) if to_room < dgn.size() else null
			var is_monster: bool = room_dict != null and str((room_dict as Dictionary).get("type", "")) == "monster"
			_play_sfx("res://assets/audio/sfx/sfx_room_magic.wav" if is_monster else "res://assets/audio/sfx/sfx_room_physical.wav")
			_bump_slot(room_ctrl)
			_show_floating_dmg(pawn, dmg)
			var badge: Label = (_lane[lane_idx] as Dictionary)["dmg"]
			badge.modulate = Color(1, 0.35, 0.3)
			badge.create_tween().tween_property(badge, "modulate", Color.WHITE, 0.5)
		if is_instance_valid(hp_lbl):
			hp_lbl.text = "%d HP" % maxi(hp_after, 0))
	tw.tween_interval(0.3)
	tw.tween_callback(func():
		_animating_hero = false
		refresh())

## Les jetons de l'entree ne doivent plus montrer le heros qui marche (voir _refresh_entrances).
func refresh_entrance_only() -> void:
	var G: Dictionary = game_manager.G
	var pl: Dictionary = (G.get("players", {}) as Dictionary).get(view_pid, {})
	_refresh_entrances(pl, (G["players"] as Dictionary)[foe_pid] if foe_pid >= 0 else {})

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
	hp_badge.name = "Hp"
	hp_badge.text = "%d HP" % hp
	hp_badge.add_theme_font_override("font", _fa)
	hp_badge.add_theme_font_size_override("font_size", 18)
	hp_badge.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
	hp_badge.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	hp_badge.add_theme_constant_override("outline_size", 4)
	hp_badge.position = Vector2(4, -22)
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

func _has_any(moves: Array, types: Array) -> bool:
	for m in moves:
		if m is Dictionary and str((m as Dictionary).get("type", "")) in types:
			return true
	return false

## Allume les salles de mon donjon dont la capacite est activable maintenant (clic gauche sur la salle).
func _refresh_activatable(my_moves: Array) -> void:
	var act: Dictionary = {}
	for m in _moves_of(my_moves, "activateRoom"):
		var a: Array = (m as Dictionary).get("args", [])
		if not a.is_empty():
			act[int(a[0])] = true
	for slot in _dungeon_slots:
		var sl: DungeonSlot = slot
		sl.set_activatable(act.has(sl.slot_index) and not sl.current_stack.is_empty())

func _moves_of(moves: Array, mtype: String) -> Array:
	var out: Array = []
	for m in moves:
		if m is Dictionary and str((m as Dictionary).get("type", "")) == mtype:
			out.append(m)
	return out

# ---------------------------------------------------------------------------------------------------------------------
# Fenetres modales (style APK : bulle de titre + boutons pierre) : choix en attente, cibles, options, confirmation
# ---------------------------------------------------------------------------------------------------------------------

func _popup_close() -> void:
	if _popup != null and is_instance_valid(_popup):
		remove_child(_popup)
		_popup.queue_free()
	_popup = null
	_popup_kind = ""
	_choice_sig = ""

## Voile + racine modale (bloque les clics vers le plateau). Un seul popup a la fois.
func _popup_begin(kind: String, dim_alpha: float = 0.62) -> Control:
	_popup_close()
	_popup_kind = kind
	_popup = Control.new()
	_popup.size = Vector2(1920, 1080)
	_popup.mouse_filter = Control.MOUSE_FILTER_STOP
	_popup.z_index = 100 # devant le voile du mode ciblage (z 40) et les cibles (z 60+)
	_popup.theme = _make_bar_theme()
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, dim_alpha)
	dim.size = Vector2(1920, 1080)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_popup.add_child(dim)
	add_child(_popup)
	return _popup

## Popup centre facon « SELECT 2 CARDS TO DISCARD » : bulle (top_globe) avec le titre, puis une pile de boutons pierre.
## entries : [{label, cb}] ; cancel_cb valide = bouton CANCEL en dernier.
func _popup_list(kind: String, title: String, entries: Array, cancel_cb: Callable = Callable()) -> void:
	var pop := _popup_begin(kind)
	var n := entries.size() + (1 if cancel_cb.is_valid() else 0)
	var cols := 1 if n <= 6 else 2
	var rows := ceili(n / float(cols))
	var bw := 640.0 if cols == 1 else 520.0
	var bh := 78.0
	var gap := 12.0
	var list_h := minf(rows * (bh + gap), 560.0)
	var y0 := maxf(30.0, (1080.0 - (137.0 + 24.0 + list_h)) / 2.0)
	_img(pop, UI_DIR + "top_globe.webp", Vector2(PLAY_CX - 465, y0))
	var tl := _lbl(pop, title.to_upper(), 26 if title.length() <= 44 else 21, Color.WHITE, Vector2(PLAY_CX - 430, y0 + 14), 860.0, _fa, HORIZONTAL_ALIGNMENT_CENTER)
	tl.custom_minimum_size.y = 110.0
	tl.size.y = 110.0
	tl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var scroll := ScrollContainer.new()
	var gw := cols * bw + (cols - 1) * gap
	scroll.position = Vector2(PLAY_CX - gw / 2.0, y0 + 137.0 + 24.0)
	scroll.size = Vector2(gw + 16.0, list_h)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	pop.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = cols
	grid.add_theme_constant_override("h_separation", int(gap))
	grid.add_theme_constant_override("v_separation", int(gap))
	scroll.add_child(grid)
	var all: Array = entries.duplicate()
	if cancel_cb.is_valid():
		all.append({"label": "CANCEL", "cb": cancel_cb})
	for e in all:
		var ed: Dictionary = e
		var b := Button.new()
		b.text = str(ed["label"]).to_upper()
		b.custom_minimum_size = Vector2(bw, bh)
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.add_theme_font_size_override("font_size", 24 if b.text.length() <= 30 else 18)
		var cb: Callable = ed["cb"]
		b.pressed.connect(func():
			_play_sfx("res://assets/audio/sfx/ui_button_select.wav")
			cb.call())
		grid.add_child(b)

# ---------------------------------------------------------------------------------------------------------------------
# Ciblage sur le plateau (APK) : voile leger, bulle de titre, cibles legales en surbrillance doree et cliquables, CANCEL.
# La liste centrale (_popup_list) ne sert que si une cible n'a pas de representation sur le plateau (ames, defausse, pile...).
# ---------------------------------------------------------------------------------------------------------------------

## Zone du plateau qui represente une cible de coup (dictionnaire de cible des coups playSpell / useHandRoom) ; {} si aucune.
## {k: room|hero|town|player, pid / idx / hid / eidx / i}. Plusieurs coups peuvent partager une zone (mode, paiement...).
func _spot_of_target(td: Dictionary, caster: int) -> Dictionary:
	for k in ["a", "soulIndex", "itemIndex", "stackId", "woundIndex"]:
		if td.has(k):
			return {}
	if td.has("roomIndex"):
		return {"k": "room", "pid": int(td.get("targetPlayerId", caster)), "idx": int(td["roomIndex"])}
	if td.has("townIndex"):
		return {"k": "town", "i": int(td["townIndex"])}
	if td.has("entranceIndex"):
		return {"k": "hero", "pid": int(td.get("targetPlayerId", caster)), "eidx": int(td["entranceIndex"])}
	if td.has("heroId"):
		for pid in (game_manager.G.get("players", {}) as Dictionary):
			for h in ((game_manager.G["players"] as Dictionary)[pid] as Dictionary).get("entrance", []):
				if str((h as Dictionary).get("id", "")) == str(td["heroId"]):
					return {"k": "hero", "pid": int(pid), "hid": str(td["heroId"])}
		return {}
	if td.has("targetPlayerId"):
		return {"k": "player", "pid": int(td["targetPlayerId"])}
	return {}

## Entree unique des choix de cible : sur le plateau si chaque entree a une zone (entry.spot), sinon la liste centrale.
## entries : [{label, cb, mv?, spot?}] ; hint : texte de la bulle.
func _target_list(title: String, hint: String, entries: Array, cancel_cb: Callable) -> void:
	var on_board := not entries.is_empty()
	for e in entries:
		if (e as Dictionary).get("spot", {}).is_empty():
			on_board = false
	if not on_board:
		_popup_list("target", title, entries, cancel_cb)
		return
	_popup_close()
	_target_end()
	_tgt = {"pid": _my_pid(), "title": title, "hint": hint if hint != "" else "Select a target", "entries": entries}
	_target_open_layer()
	action_box.visible = false # CANCEL prend la place de PASS TURN (refresh le remet a la fin du ciblage)
	_target_apply()
	_target_scroll_town()

func _target_open_layer() -> void:
	_tgt_layer = Control.new()
	_tgt_layer.size = Vector2(1920, 1080)
	_tgt_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_tgt_layer)
	var dim := _rect(_tgt_layer, Color(0, 0, 0, 0.5), Vector2(0, 62), Vector2(1920, 1018)) # laisse libres les barres du haut (selecteurs de sieges)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.z_index = TARGET_Z - 20
	var bubble := _img(_tgt_layer, UI_DIR + "top_globe.webp", Vector2(PLAY_CX - 280, 96), Vector2(560, 82))
	bubble.z_index = TARGET_Z + 10
	var txt := _lbl(_tgt_layer, str(_tgt["hint"]).to_upper(), 20, Color.WHITE, Vector2(PLAY_CX - 250, 104), 500.0, _fa, HORIZONTAL_ALIGNMENT_CENTER)
	txt.custom_minimum_size.y = 62.0
	txt.size.y = 62.0
	txt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	txt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	txt.z_index = TARGET_Z + 11
	_tgt_cancel_btn = Button.new()
	_tgt_cancel_btn.text = "CANCEL"
	_tgt_cancel_btn.theme = _make_bar_theme()
	_tgt_cancel_btn.position = Vector2(PLAY_CX - 100, 466)
	_tgt_cancel_btn.custom_minimum_size = Vector2(200, 68)
	_tgt_cancel_btn.size = Vector2(200, 68)
	_tgt_cancel_btn.z_index = TARGET_Z + 10
	_tgt_cancel_btn.pressed.connect(_target_cancel)
	_tgt_layer.add_child(_tgt_cancel_btn)

func _target_cancel() -> void:
	_play_sfx("res://assets/audio/sfx/ui_button_goback.wav")
	_target_end()
	refresh()

func _target_end() -> void:
	for n in _tgt_lifted:
		if is_instance_valid(n):
			(n as CanvasItem).z_index = 0
	_tgt_lifted.clear()
	_tgt_spots.clear()
	if _tgt_layer != null and is_instance_valid(_tgt_layer):
		remove_child(_tgt_layer)
		_tgt_layer.queue_free()
	_tgt_layer = null
	_tgt_cancel_btn = null
	_tgt = {}
	for b in foe_bar.get_children():
		(b as Control).remove_theme_color_override("font_color")

## Apres chaque refresh : les coups proposes doivent rester legaux (l'IA ou un autre siege a pu jouer), sinon le mode se ferme.
func _target_sync(my_moves: Array) -> void:
	if _tgt.is_empty():
		return
	if int(_tgt["pid"]) != _my_pid() or game_manager.G.get("gameOver") != null:
		_target_end()
		return
	var keep: Array = []
	for e in (_tgt["entries"] as Array):
		if not (e as Dictionary).has("mv") or my_moves.has((e as Dictionary)["mv"]):
			keep.append(e)
	if keep.is_empty():
		_target_end()
		return
	_tgt["entries"] = keep
	_target_apply()

## Les zones se (re)posent apres la mise en page des conteneurs (jetons d'entree, ville) : un seul passage differe par image.
var _tgt_queued := false
func _target_apply() -> void:
	if _tgt.is_empty() or _tgt_queued:
		return
	_tgt_queued = true
	_target_apply_now.call_deferred()

func _target_settle() -> void:
	for i in 2:
		await get_tree().process_frame
	if not _tgt.is_empty() and not _tgt_queued:
		_target_apply_now(false)

func _target_scroll_town() -> void:
	await get_tree().process_frame
	if _tgt.is_empty():
		return
	for e in (_tgt["entries"] as Array):
		var sp: Dictionary = (e as Dictionary)["spot"]
		if str(sp.get("k", "")) == "town":
			var node := _spot_node(sp)
			if node != null:
				_town_scroll.ensure_control_visible(node)
			return

func _spot_lane(pid: int) -> int: # 1 = mon couloir, 0 = couloir adverse affiche, -1 = pas a l'ecran (selecteur d'adversaire)
	return 1 if pid == view_pid else (0 if pid == foe_pid else -1)

## Noeud du plateau represente par une zone (null : pas a l'ecran pour l'instant).
func _spot_node(spot: Dictionary) -> Control:
	var G: Dictionary = game_manager.G
	match str(spot.get("k", "")):
		"room":
			var pid := int(spot["pid"])
			if _spot_lane(pid) < 0:
				return null
			var sl := _slot_at(pid, int(spot["idx"]))
			if sl is DungeonSlot and (sl as DungeonSlot).current_stack.is_empty():
				return null
			return sl
		"town":
			var kids := town_container.get_children().filter(func(c): return not c.is_queued_for_deletion())
			var i := int(spot["i"])
			return kids[i] if i >= 0 and i < kids.size() else null
		"hero":
			var pid2 := int(spot["pid"])
			if _spot_lane(pid2) < 0:
				return null
			var ent: Array = ((G["players"] as Dictionary)[pid2] as Dictionary).get("entrance", [])
			var idx := int(spot.get("eidx", -1))
			if idx < 0:
				for k in ent.size():
					if str((ent[k] as Dictionary).get("id", "")) == str(spot.get("hid", "")):
						idx = k
						break
			if idx < 0 or idx >= ent.size():
				return null
			var adv: Dictionary = G.get("adventure", {})
			if not adv.is_empty() and adv.get("hero") != null and int(adv.get("playerId", -1)) == pid2 \
					and str((adv["hero"] as Dictionary).get("id", "")) == str((ent[idx] as Dictionary).get("id", "")) \
					and _hero_pawn != null and is_instance_valid(_hero_pawn):
				return _hero_pawn
			var toks: Array = _ent_tok.get(pid2, [])
			return toks[idx] if idx < toks.size() and toks[idx] != null and is_instance_valid(toks[idx]) else null
		"player":
			var ln := _spot_lane(int(spot["pid"]))
			return null if ln < 0 else (_lane[ln]["platform"] as Control)
	return null

func _spot_rect(spot: Dictionary, node: Control) -> Rect2:
	var r := node.get_global_rect()
	match str(spot.get("k", "")):
		"town":
			r = r.intersection(_town_scroll.get_global_rect())
		"player":
			var L: Dictionary = _lane[_spot_lane(int(spot["pid"]))]
			if (L["sprite"] as Control).visible:
				r = (L["sprite"] as Control).get_global_rect().intersection((L["root"] as Control).get_global_rect())
	return r

func _target_apply_now(settle := true) -> void:
	_tgt_queued = false
	if _tgt.is_empty() or _tgt_layer == null or not is_instance_valid(_tgt_layer):
		return
	if settle: # les conteneurs (ville, entrees) n'ont leur mise en page definitive qu'apres une ou deux images : on repose les zones ensuite
		_target_settle()
	for n in _tgt_lifted:
		if is_instance_valid(n):
			(n as CanvasItem).z_index = 0
	_tgt_lifted.clear()
	for s in _tgt_spots:
		if is_instance_valid(s["ctrl"]):
			_tgt_layer.remove_child(s["ctrl"])
			(s["ctrl"] as Node).queue_free()
	_tgt_spots.clear()
	var groups := {}
	var off_screen := {}
	var entries: Array = _tgt["entries"]
	for i in entries.size():
		var spot: Dictionary = (entries[i] as Dictionary)["spot"]
		var node := _spot_node(spot)
		if node == null:
			if spot.has("pid"):
				off_screen[int(spot["pid"])] = true
			continue
		var r := _spot_rect(spot, node)
		if r.size.x < 2.0 or r.size.y < 2.0:
			continue
		var key := node.get_instance_id()
		if not groups.has(key):
			groups[key] = {"node": node, "rect": r, "ids": []}
		(groups[key]["ids"] as Array).append(i)
	for key in groups:
		_target_make_spot(groups[key])
	for b in foe_bar.get_children(): # adversaire hors ecran qui a des cibles : son bouton P<n> est dore
		if b is Button and off_screen.has(int((b as Button).get_meta("pid", -1))):
			(b as Button).add_theme_color_override("font_color", GOLD)
		elif b is Button:
			(b as Button).remove_theme_color_override("font_color")

func _target_make_spot(g: Dictionary) -> void:
	var node: Control = g["node"]
	var r: Rect2 = g["rect"]
	var ids: Array = g["ids"]
	node.z_index = TARGET_Z
	_tgt_lifted.append(node)
	var sp := Control.new()
	sp.position = r.position - Vector2(10, 10)
	sp.size = r.size + Vector2(20, 20)
	sp.mouse_filter = Control.MOUSE_FILTER_STOP
	sp.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	sp.z_index = TARGET_Z + 10
	var entries: Array = _tgt["entries"]
	sp.tooltip_text = str((entries[int(ids[0])] as Dictionary).get("label", "")) if ids.size() == 1 else "%d choices" % ids.size()
	var glow := TextureRect.new()
	glow.texture = _tex(TEX_TARGET_GLOW)
	glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glow.stretch_mode = TextureRect.STRETCH_SCALE
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow.set_anchors_preset(Control.PRESET_FULL_RECT)
	sp.add_child(glow)
	sp.draw.connect(func(): sp.draw_rect(Rect2(Vector2(9, 9), sp.size - Vector2(18, 18)), GOLD, false, 4.0)) # trait net sous le halo
	var tw := sp.create_tween().set_loops()
	tw.tween_property(sp, "modulate:a", 0.5, 0.55).set_trans(Tween.TRANS_SINE)
	tw.tween_property(sp, "modulate:a", 1.0, 0.55).set_trans(Tween.TRANS_SINE)
	sp.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			sp.accept_event()
			_target_pick(ids))
	_tgt_layer.add_child(sp)
	_tgt_spots.append({"ctrl": sp, "ids": ids})

## Clic sur une zone : un coup = joue ; plusieurs (meme cible, options differentes) = petite liste de ces coups seulement.
func _target_pick(ids: Array) -> void:
	if _tgt.is_empty():
		return
	var entries: Array = _tgt["entries"]
	_play_sfx("res://assets/audio/sfx/ui_button_select.wav")
	if ids.size() == 1:
		((entries[int(ids[0])] as Dictionary)["cb"] as Callable).call()
		return
	var sub: Array = []
	for i in ids:
		sub.append(entries[int(i)])
	_popup_list("target", str(_tgt["title"]), sub, func(): _popup_close())

## Choix en attente du joueur (pendingChoice : Dark Altar, All-Seeing Eye, level up...) : popup au centre, une pierre par option.
func _refresh_choice_popup(G: Dictionary, my_moves: Array) -> void:
	var pc: Dictionary = G.get("pendingChoice", {})
	var mine := not pc.is_empty() and int(pc.get("playerId", -1)) == _my_pid()
	if not mine:
		discard_pick.clear()
	var cmoves: Array = _moves_of(my_moves, "resolveChoice") + _moves_of(my_moves, "resolveLevelUpChoice")
	if not mine or str(pc.get("type", "")) == "opening-discard" or cmoves.is_empty():
		if _popup_kind == "choice":
			_popup_close() # carrousel central + bouton CONTINUE pour la defausse d'ouverture (_refresh_overlay)
		return
	if _popup_kind in ["menu", "quit", "target"] or not _tgt.is_empty():
		return # un menu ouvert par le joueur reste devant ; le choix reapparait a la fermeture (refresh)
	var sig := JSON.stringify([pc.get("type"), pc.get("message"), cmoves])
	if _popup_kind == "choice" and sig == _choice_sig:
		return
	var opts: Array = pc.get("options", [])
	var entries: Array = []
	for m in cmoves:
		var mv: Dictionary = (m as Dictionary).duplicate()
		entries.append({"label": _option_label(opts, int((mv.get("args", [0]) as Array)[0])), "cb": func(): _do(mv)})
	_popup_list("choice", str(pc.get("message", "")) if str(pc.get("message", "")) != "" else "CHOOSE", entries)
	_choice_sig = sig

func _option_label(opts: Array, i: int) -> String:
	if i < 0:
		return "SKIP"
	if i < opts.size() and opts[i] is Dictionary:
		var o: Dictionary = opts[i]
		for k in ["label", "name"]:
			if str(o.get(k, "")) != "":
				return str(o[k])
		if (o.get("card", {}) as Dictionary).get("name", "") != "":
			return str((o["card"] as Dictionary)["name"])
		if o.has("targetPlayerId"):
			return "Player %d" % (int(o["targetPlayerId"]) + 1)
	return "Choice %d" % (i + 1)

## Coups propres aux extensions du wiki (Minibosses, TNL...) : aucun equivalent APK, boutons pierre discrets sous la separation.
## Les sorts (clic sur la carte) et les capacites de salle (clic sur la salle) n'ont PAS de bouton.
func _refresh_extra_bar(G: Dictionary, my_moves: Array) -> void:
	for c in extra_bar.get_children():
		c.queue_free()
	var shown := false
	var hand: Array = ((G.get("players", {}) as Dictionary).get(_my_pid(), {}) as Dictionary).get("hand", [])
	if not (G.get("pendingChoice", {}) as Dictionary).is_empty():
		extra_bar.visible = false
		return
	for m in my_moves:
		if not (m is Dictionary) or str((m as Dictionary).get("type", "")) in CORE_MOVE_TYPES + HAND_CLICK_TYPES + ["activateRoom"]:
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
		"buildMiniboss", "promoteMiniboss", "activateMiniboss":
			var mdg: Array = ((_G.get("players", {}) as Dictionary).get(_my_pid(), {}) as Dictionary).get("dungeon", [])
			var mslot := int(args[1]) if t == "buildMiniboss" else int(args[0])
			var mroom = BossEngine.active_room(mdg[mslot]) if mslot >= 0 and mslot < mdg.size() else null
			var rname := str((mroom as Dictionary).get("name", "?")) if mroom != null else "?"
			if t == "buildMiniboss":
				return "MINIBOSS: %s -> ON %s (FACE-DOWN, 1 COIN TO REVEAL)" % [hand_name, rname]
			var mname := Minibosses.mb_name(Minibosses.mb_of(mroom))
			if t == "promoteMiniboss":
				var alt := int(args[1]) if args.size() > 1 else -1
				return "PROMOTE %s (%s)" % [mname, "1 COIN" if alt < 0 else "DISCARD %s" % str((hand[alt] as Dictionary).get("name", "?"))]
			return "%s: LEVEL %d POWER" % [mname, int(args[1])]
		"discardForCoin":
			return "DISCARD %s: +1 COIN" % hand_name
		"rmbBoss":
			return "BOSS: %s (%s)" % [str(args[0]), "CANCEL THE TRAPS' +1" if str(args[0]) == "RMB011" else "2 COINS"]
		"rmbHand":
			return "ABILITY: %s%s" % [hand_name, " (%s)" % str(args[1]) if args.size() > 1 and str(args[1]) != "" else ""]
		"rmbPay":
			return "PAY 1 COIN (PAYWALL)"
		"rmbCancel":
			return "MAGESEEKER: DISCARD %s, CANCEL THE SPELL" % (str((hand[int(args[1])] as Dictionary).get("name", "?")) if args.size() > 1 and int(args[1]) < hand.size() else "?")
		"payDarkHero":
			return "PAY %s (DARK HERO)" % hand_name
		"docScarecrow":
			var town: Array = _G.get("town", [])
			var ti := int(args[1]) if args.size() > 1 else -1
			return "SCARECROW: %s -> %s" % [hand_name, str((town[ti] as Dictionary).get("name", "?")) if ti >= 0 and ti < town.size() else "?"]
		"timebenderCancel":
			return "DR. TIMEBENDER: DISCARD %s, CANCEL THE SPELL" % hand_name
		"antimagicCancel":
			return "ANTIMAGIC ZONE: CANCEL THE SPELL"
		_:
			return hand_name if hand_name != "" else t

func _do(move: Dictionary) -> void:
	_popup_close() # une fenetre ouverte pour ce coup (cible, choix) se ferme avec lui
	_target_end()
	game_manager.apply_move(_my_pid(), move)
	refresh() # toujours : ce qui reste a decider (nouveau choix) doit reapparaitre

func _on_hand_card_clicked(idx: int, card: Dictionary) -> void:
	if _is_opening_discard_for_me():
		if discard_pick.has(idx):
			discard_pick.erase(idx)
		elif discard_pick.size() < 2:
			discard_pick.append(idx)
		_play_sfx("res://assets/audio/sfx/ui_button_select.wav")
		refresh()
		return
	if _modal_open() or (_popup != null and is_instance_valid(_popup)) or not _tgt.is_empty():
		return
	var phase: String = game_manager.G.get("phase", "")
	if (phase == "build" or phase == "setup") and card.get("isRoom", false):
		var dungeon: Array = ((game_manager.G["players"] as Dictionary)[_my_pid()] as Dictionary).get("dungeon", [])
		var target_slot := dungeon.size()
		var uses := _hand_moves(idx)
		if not uses.is_empty(): # salle a capacite de main (CRL007 Frostman Lander) : construire OU utiliser (la pose ecrasait la capacite)
			_play_hand_menu(idx, card, uses, game_manager.can_build_room_at(_my_pid(), idx, target_slot))
			return
		if not game_manager.can_build_room_at(_my_pid(), idx, target_slot): # salle avancee / donjon plein : choisir la salle a recouvrir (sinon, glisser-deposer)
			var over: Array = []
			for m in _moves_of(game_manager.legal_moves(_my_pid()), "buildRoom"):
				var a: Array = (m as Dictionary).get("args", [])
				if a.size() > 1 and a[1] != null and int(a[0]) == idx:
					over.append(m)
			if not over.is_empty():
				_build_over_menu(card, over)
				return
		_play_sfx("res://assets/audio/sfx/sfx_room_physical.wav")
		if game_manager.build_room_at(_my_pid(), idx, target_slot):
			refresh() # apply_move n'emet pas toujours state_changed en fin de coup (transition de phase)
	else:
		_play_from_hand(idx)

## Clic sur une carte de la main hors construction : sort (build / aventure / pile) ou capacite jouable depuis la main.
## Un seul coup legal = joue direct ; plusieurs cibles = fenetre de ciblage au centre (comme la bulle d'ouverture).
func _play_from_hand(idx: int) -> void:
	var cands := _hand_moves(idx)
	if cands.is_empty():
		return
	if cands.size() == 1:
		_play_sfx("res://assets/audio/sfx/sfx_room_magic.wav")
		_do(cands[0])
		return
	var hand: Array = ((game_manager.G.get("players", {}) as Dictionary).get(_my_pid(), {}) as Dictionary).get("hand", [])
	_play_hand_menu(idx, hand[idx], cands, false)

## Fenetre « construire par-dessus » : une entree par salle recouvrable (equivalent du glisser-deposer sur l'emplacement).
func _build_over_menu(card: Dictionary, over: Array) -> void:
	if over.size() == 1: # un seul emplacement possible : on construit directement
		_play_sfx("res://assets/audio/sfx/sfx_room_physical.wav")
		_do((over[0] as Dictionary).duplicate())
		return
	var dungeon: Array = ((game_manager.G.get("players", {}) as Dictionary).get(_my_pid(), {}) as Dictionary).get("dungeon", [])
	var entries: Array = []
	for c in over:
		var mv: Dictionary = (c as Dictionary).duplicate()
		var ti := int((mv["args"] as Array)[1])
		var host = BossEngine.active_room(dungeon[ti]) if ti >= 0 and ti < dungeon.size() else null
		entries.append({"label": "ON %s" % (str((host as Dictionary).get("name", "Room %d" % (ti + 1))) if host != null else "Room %d" % (ti + 1)), "mv": mv,
			"spot": {"k": "room", "pid": _my_pid(), "idx": ti}, "cb": func():
			_play_sfx("res://assets/audio/sfx/sfx_room_physical.wav")
			_do(mv)})
	_target_list("%s - build over a Room" % str(card.get("name", "")), "Select a Room to build over", entries, func(): _popup_close())

## Coups legaux (sort / capacite de main) de la carte `idx` de la main.
func _hand_moves(idx: int) -> Array:
	var cands: Array = []
	for mv in game_manager.legal_moves(_my_pid()):
		var m: Dictionary = mv
		var a: Array = m.get("args", [])
		if str(m.get("type", "")) in HAND_CLICK_TYPES and not a.is_empty() and a[0] is int and int(a[0]) == idx:
			cands.append(m)
	return cands

## Fenetre de ciblage (une entree par coup) ; `can_build` : une carte salle peut aussi etre construite (entree BUILD en tete).
func _play_hand_menu(idx: int, card: Dictionary, cands: Array, can_build: bool) -> void:
	var entries: Array = []
	if can_build:
		var dsize: int = (((game_manager.G.get("players", {}) as Dictionary).get(_my_pid(), {}) as Dictionary).get("dungeon", []) as Array).size()
		entries.append({"label": "BUILD THIS ROOM", "cb": func():
			_popup_close()
			_play_sfx("res://assets/audio/sfx/sfx_room_physical.wav")
			if game_manager.build_room_at(_my_pid(), idx, dsize):
				refresh()})
	for c in cands:
		var mv: Dictionary = (c as Dictionary).duplicate()
		var margs: Array = mv.get("args", [])
		entries.append({"label": _target_label(mv, card), "mv": mv,
			"spot": _spot_of_target(margs[1] as Dictionary, _my_pid()) if margs.size() > 1 and margs[1] is Dictionary else {}, "cb": func():
			_play_sfx("res://assets/audio/sfx/sfx_room_magic.wav")
			_do(mv)})
	var hint: String = str((SpellTargeting.SPELL_TARGETS.get(str(card.get("id", "")), {}) as Dictionary).get("label", ""))
	_target_list("%s - %s" % [str(card.get("name", "")), hint] if hint != "" else str(card.get("name", "")), hint, entries, func(): _popup_close())

## Description anglaise d'une cible de sort (listes de SpellTargeting ; extensions : leurs propres describe_target).
func _target_label(m: Dictionary, card: Dictionary) -> String:
	var args: Array = m.get("args", [])
	var t = args[1] if args.size() > 1 else null
	if not (t is Dictionary):
		return str(card.get("name", "OK"))
	var G: Dictionary = game_manager.G
	var pid := _my_pid()
	var sid := str(card.get("id", ""))
	var td: Dictionary = t
	if SpellTargeting.SPELL_TARGETS.has(sid):
		var me: Dictionary = (G["players"] as Dictionary)[pid]
		for o in SpellTargeting.get_spell_target_options(str((SpellTargeting.SPELL_TARGETS[sid] as Dictionary).get("type", "")), G, me, pid):
			if str((o as Dictionary).get("value")) == str(td):
				return str((o as Dictionary).get("label", ""))
	var desc := ""
	if TnlSpells.TARGETS.has(sid):
		desc = TnlSpells.describe_target(G, td)
	elif RmbSpells.TARGETS.has(sid):
		desc = RmbSpells.describe_target(G, td)
	if desc != "":
		return desc
	var parts: Array = []
	if td.has("targetPlayerId"):
		parts.append("Player %d" % (int(td["targetPlayerId"]) + 1))
	if td.has("roomIndex"):
		parts.append("Room %d" % (int(td["roomIndex"]) + 1))
	if td.has("townIndex"):
		var town: Array = G.get("town", [])
		var ti := int(td["townIndex"])
		parts.append(str((town[ti] as Dictionary).get("name", "Hero")) if ti >= 0 and ti < town.size() else "Hero")
	if td.has("soulIndex"):
		parts.append("Soul %d" % (int(td["soulIndex"]) + 1))
	if td.has("stackId"):
		parts.append(str((td.get("card", {}) as Dictionary).get("name", "Spell")))
	return " / ".join(parts) if not parts.is_empty() else str(card.get("name", "OK"))

## Clic sur une salle activable de mon donjon : capacite directe, ou choix de la salle cible (Centipede Tunnel...).
func _on_slot_activate(di: int) -> void:
	if _modal_open() or (_popup != null and is_instance_valid(_popup)) or not _tgt.is_empty():
		return
	var cands: Array = []
	for m in _moves_of(game_manager.legal_moves(_my_pid()), "activateRoom"):
		var a: Array = (m as Dictionary).get("args", [])
		if not a.is_empty() and int(a[0]) == di:
			cands.append(m)
	if cands.is_empty():
		return
	_play_sfx("res://assets/audio/sfx/sfx_room_magic.wav")
	if cands.size() == 1:
		_do(cands[0])
		return
	var dungeon: Array = ((game_manager.G.get("players", {}) as Dictionary).get(_my_pid(), {}) as Dictionary).get("dungeon", [])
	var entries: Array = []
	for c in cands:
		var mv: Dictionary = (c as Dictionary).duplicate()
		var a: Array = mv.get("args", [])
		var tj := int(a[1]) if a.size() > 1 else -1
		var tr = BossEngine.active_room(dungeon[tj]) if tj >= 0 and tj < dungeon.size() else null
		entries.append({"label": str((tr as Dictionary).get("name", "Room %d" % (tj + 1))) if tr != null else "Room %d" % (tj + 1), "mv": mv,
			"spot": {"k": "room", "pid": _my_pid(), "idx": tj}, "cb": func(): _do(mv)})
	var rd = BossEngine.active_room(dungeon[di]) if di >= 0 and di < dungeon.size() else null
	_target_list("%s - choose a Room" % str((rd as Dictionary).get("name", "")) if rd != null else "Choose a Room", "Choose a Room", entries, func(): _popup_close())

func _on_confirm_pressed() -> void:
	if game_manager.G.get("gameOver") != null:
		_play_sfx("res://assets/audio/sfx/ui_button_select.wav")
		_confirm_quit()
	elif str(game_manager.G.get("phase", "")) == "boss":
		_boss_confirm()
	else:
		_on_discard_confirm()

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
	if _animating_hero or _modal_open() or not _tgt.is_empty():
		return
	_play_sfx("res://assets/audio/sfx/char_hero_move.wav")
	if _is_online():
		_do({"type": "resolveNextHero", "args": []})
	else:
		game_manager.apply_move(_my_pid(), {"type": "adventureNext", "args": []})
		refresh()

func _on_pass_pressed() -> void:
	if not _tgt.is_empty():
		return
	_play_sfx("res://assets/audio/sfx/ui_button_select.wav")
	if _is_online():
		_do({"type": "pass", "args": []})
	else:
		if game_manager.apply_move(_my_pid(), {"type": "passBuild", "args": []}):
			refresh()

# ---------------------------------------------------------------------------------------------------------------------
# Menu en jeu (engrenage) : OPTIONS (MUSIC / SOUND), OK, RULES (superpose au plateau), QUIT TO MENU (avec confirmation)
# ---------------------------------------------------------------------------------------------------------------------

func _on_menu_pressed() -> void:
	if _rules != null and is_instance_valid(_rules):
		return
	if _popup_kind == "menu":
		_close_menu()
		return
	_open_game_menu()

func _close_menu() -> void:
	_play_sfx("res://assets/audio/sfx/ui_button_goback.wav")
	_popup_close()
	refresh() # un choix en attente (cache par le menu) reapparait

func _open_game_menu() -> void:
	_play_sfx("res://assets/audio/sfx/ui_button_select.wav")
	var pop := _popup_begin("menu", 0.72)
	var px := PLAY_CX - 360.0
	var py := 120.0
	var panel := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.08, 0.06, 0.98)
	sb.border_color = GOLD
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(14)
	panel.add_theme_stylebox_override("panel", sb)
	panel.position = Vector2(px, py)
	panel.size = Vector2(720, 800)
	pop.add_child(panel)
	_lbl(pop, "OPTIONS", 44, GOLD, Vector2(px + 40, py + 24), 400.0, _fa)
	var close := _tex_button(pop, "res://assets/ui/expansions/close_panel.webp", "res://assets/ui/expansions/close_panel_pressed.webp", Vector2(px + 720 - 100, py + 14), Vector2(70, 77))
	close.pressed.connect(_close_menu)
	_menu_volume(pop, py + 112.0, px)
	_menu_toggle(pop, "MUSIC", py + 232.0, px, AudioManager.music_on, func(on: bool): AudioManager.set_music_on(on))
	_menu_toggle(pop, "SOUND", py + 332.0, px, AudioManager.sfx_on, func(on: bool): AudioManager.set_sfx_on(on))
	var ok := _tex_button(pop, "res://assets/ui/buttons/ok_bt.webp", "res://assets/ui/buttons/ok_bt_pressed.webp", Vector2(PLAY_CX - 103, py + 408), Vector2(206, 99))
	ok.pressed.connect(_close_menu)
	var rules := Button.new()
	rules.text = "RULES"
	rules.custom_minimum_size = Vector2(440, 84)
	rules.size = Vector2(440, 84)
	rules.position = Vector2(PLAY_CX - 220, py + 530)
	rules.pressed.connect(_open_rules)
	pop.add_child(rules)
	var quit := Button.new()
	quit.text = "QUIT TO MENU"
	quit.custom_minimum_size = Vector2(440, 84)
	quit.size = Vector2(440, 84)
	quit.position = Vector2(PLAY_CX - 220, py + 645)
	quit.pressed.connect(_open_quit_confirm)
	pop.add_child(quit)

## MASTER VOLUME (curseur vert + pourcentage, comme l'ecran OPTIONS du jeu) : agit sur le bus Master de AudioManager.
func _menu_volume(pop: Control, y: float, px: float) -> void:
	_lbl(pop, "MASTER VOLUME", 26, Color.WHITE, Vector2(px + 40, y - 4), 400.0, _fb)
	var pct := _lbl(pop, "%d%%" % roundi(AudioManager.master_volume * 100.0), 26, GOLD, Vector2(px + 590, y - 4), 100.0, _fb, HORIZONTAL_ALIGNMENT_RIGHT)
	var sl := HSlider.new()
	sl.min_value = 0.0
	sl.max_value = 1.0
	sl.step = 0.01
	sl.value = AudioManager.master_volume
	sl.position = Vector2(px + 40, y + 38)
	sl.size = Vector2(640, 32)
	sl.focus_mode = Control.FOCUS_NONE
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.2, 0.17, 0.12)
	track.set_corner_radius_all(8)
	track.content_margin_top = 8
	track.content_margin_bottom = 8
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.36, 0.7, 0.2)
	fill.set_corner_radius_all(8)
	fill.content_margin_top = 8
	fill.content_margin_bottom = 8
	sl.add_theme_stylebox_override("slider", track)
	sl.add_theme_stylebox_override("grabber_area", fill)
	sl.add_theme_stylebox_override("grabber_area_highlight", fill)
	sl.value_changed.connect(func(v: float):
		AudioManager.set_master_volume(v, false)
		pct.text = "%d%%" % roundi(v * 100.0))
	sl.drag_ended.connect(func(_changed: bool): AudioManager.set_master_volume(sl.value))
	pop.add_child(sl)

## Ligne « MUSIC / SOUND » : deux segments ON / OFF (le choisi = pierre verte, comme l'ecran OPTIONS du menu).
func _menu_toggle(pop: Control, text: String, y: float, px: float, is_on: bool, cb: Callable) -> void:
	_lbl(pop, text, 34, Color.WHITE, Vector2(px + 40, y - 20), 260.0, _fb)
	var row := Control.new()
	pop.add_child(row)
	_draw_menu_toggle(row, y, px, is_on, cb)

func _draw_menu_toggle(row: Control, y: float, px: float, is_on: bool, cb: Callable) -> void:
	for c in row.get_children():
		row.remove_child(c)
		c.queue_free()
	var x0 := px + 330.0
	_rect(row, Color(109 / 255.0, 99 / 255.0, 131 / 255.0), Vector2(x0, y - 36), Vector2(320, 72))
	for i in 2:
		var sel := (i == 0) == is_on
		var x := x0 + 160.0 * i
		if sel:
			_img(row, "res://assets/ui/buttons/settings_bt.webp", Vector2(x - 2, y - 44), Vector2(164, 88))
		_lbl(row, "ON" if i == 0 else "OFF", 30, GOLD if sel else Color(0.9, 0.88, 0.96), Vector2(x, y - 20), 160.0, _fa, HORIZONTAL_ALIGNMENT_CENTER)
		var hit := Button.new()
		for n in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
			hit.add_theme_stylebox_override(n, StyleBoxEmpty.new())
		hit.focus_mode = Control.FOCUS_NONE
		hit.position = Vector2(x, y - 36)
		hit.size = Vector2(160, 72)
		var turn_on := i == 0
		hit.pressed.connect(func():
			cb.call(turn_on)
			_play_sfx("res://assets/audio/sfx/ui_button_select.wav")
			_draw_menu_toggle(row, y, px, turn_on, cb))
		row.add_child(hit)

## RULES : la visionneuse des regles (RulesViewer, la meme que le menu principal) se superpose au plateau ; fermer = retour au jeu.
func _open_rules() -> void:
	if _rules != null and is_instance_valid(_rules):
		return
	_play_sfx("res://assets/audio/sfx/ui_button_select.wav")
	_rules = RulesViewer.new()
	_rules.z_index = 110 # devant le voile du mode ciblage
	_rules.closed.connect(func(): _rules = null)
	add_child(_rules)

func _open_quit_confirm() -> void:
	_popup_list("quit", "Quit to menu? The current game will be lost", [
		{"label": "YES, QUIT", "cb": _confirm_quit},
		{"label": "NO, KEEP PLAYING", "cb": _open_game_menu},
	])

func _confirm_quit() -> void:
	_popup_close()
	if on_exit_callback.is_valid():
		on_exit_callback.call()

func _on_discard_pile_pressed() -> void:
	_play_sfx("res://assets/audio/sfx/ui_button_select.wav")
	var decks: Dictionary = game_manager.G.get("decks", {})
	var r_disc: Array = decks.get("roomDiscard", [])
	var s_disc: Array = decks.get("spellDiscard", [])
	var h_disc: Array = decks.get("heroDiscard", [])

	var dialog := AcceptDialog.new()
	dialog.title = "DISCARD PILES"
	dialog.size = Vector2i(700, 480)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)

	var lbl := Label.new()
	lbl.text = "Discarded Rooms (%d):\n%s\n\nDiscarded Spells (%d):\n%s\n\nDead Heroes (%d):\n%s" % [
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
	dialog.visibility_changed.connect(func():
		if not dialog.visible:
			dialog.queue_free()) # OK / croix : la fenetre est liberee (sinon une de plus a chaque ouverture)
	dialog.popup_centered()

func _on_level_up_pressed() -> void:
	_play_sfx("res://assets/audio/sfx/sting_levelup.wav")

func _get_total_dungeon_damage(player_dict: Dictionary) -> int:
	var total := 0
	for stack in player_dict.get("dungeon", []):
		var r = BossEngine.active_room(stack)
		if r != null and not bool((r as Dictionary).get("faceDown", false)):
			total += int((r as Dictionary).get("damage", 0))
	return total
