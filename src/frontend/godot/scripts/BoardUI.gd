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
const UiKit = preload("res://godot/scripts/UiKit.gd")
const TimeBar = preload("res://godot/scripts/TimeBar.gd")
const InGameMenu = preload("res://godot/scripts/InGameMenu.gd")
const GameOverBanner = preload("res://godot/scripts/GameOverBanner.gd")

var game_manager: GameManager
var on_exit_callback: Callable
var view_pid: int = 0
var seat_bar: HBoxContainer
var foe_bar: HBoxContainer               # selecteur d'adversaire (3-4 joueurs) : TopRightPanel.ChangeVisibleBoss de l'APK
var foe_pid: int = -1                    # adversaire dont le donjon occupe le couloir du haut
var _foe_follow_seen := -1               # dernier donjon adverse suivi automatiquement (aventure en cours)
var extra_bar: HFlowContainer
var discard_pick: Array = []
var _swap_idx := -1                       # salle de la main a poser des que la reprise de la pose en attente est confirmee (_swap_resume)
var _swap_until := 0                      # delai (ms) apres lequel on abandonne l'attente
var _last_phase: String = ""

const CORE_MOVE_TYPES := ["pickBoss", "buildRoom", "undoBuild", "pass", "passBuild", "adventureNext", "resolveNextHero", "openingDiscard", "resolveLevelUpChoice"]

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
const HERO_CARD := Vector2(136, 196)     # APK : carte de heros a l'entree du donjon / en traversee (x 464..600 pour la premiere)
const HERO_FRONT_X := 464.0
const HERO_IN_SLOT := Vector2(-4.5, -10.5) # decalage d'une carte de heros posee sur un emplacement (127 x 175), centree dessus
const HERO_SPRITE_SCALE := 0.78          # APK HeroCardEntity : le personnage du heros (hero_characters) = 0,39 (echelle de la carte) x 2 (ScaleEffectBehavior a l'entree)
const HERO_SPRITE_DY := -15.0            # centre du personnage par rapport au centre de la salle (APK : un peu au-dessus)
const HERO_HEART := Vector2(55, 48)      # coeur de PV du heros (health_hero_icon x 0,78), centre 117 px au-dessus du personnage (FollowBehavior -150 x 0,78)
const HERO_HEART_DY := -117.0
const ROOM_FOCUS_SCALE := 1.3            # APK CardStackSlotComponent.CreateScaleInTopRoomTask : la salle ou se trouve le heros grossit (x ~1,3), elle reprend sa taille quand il la quitte
const SLOT_STEP := 140.0
const PLAY_CX := 945.0                   # centre de la zone de jeu (entre les deux colonnes)
const STACK_CX := 960.0                  # APK : pile de sorts, zoom central et barre de temps centres au milieu de l'ecran (cadre noir x 785..1135)
const HAND_CARD := Vector2(175, 244)     # APK : carte 350x488 a l'echelle 0,5 (HandEntity.NormalScale), bas de carte sous le bord de l'ecran
const HAND_CX := 960.0                   # HandEntity : x = VirtualWidth * 0,5 (1440 centres dans 1920), y = VirtualHeight * 0,9
const HAND_CY := 972.0
const BIG_CARD := Vector2(232, 324)
const WIKI_BG_IDS := ["bma001", "bma002", "bma003", "bma004", "bma005", "bma006", "bma007", "bma008", "ksa001", "ksa002", "ksa003", "ksa004", "ksa005", "ksa006", "ksa007"] # fonds APK (assets/ui/dungeon) repris par les boss du wiki
const BOSS_SPRITE_SCALE := 1.0          # APK : sprite du boss a sa taille native (King Croak ~175 px, Cleopatra ~200 px sur l'estrade)
const BOSS_SPRITE_MAX_W := 300.0         # largeur de l'estrade : un sprite plus large (KSA005, 333 px) est reduit pour ne pas deborder
const BOSS_CARD := Vector2(362, 506)     # carrousel du choix du boss (apk_boss00) : carte centrale ; les voisines sont reduites et se chevauchent
const BOSS_SIDE_SCALE := [1.0, 0.58, 0.55, 0.52, 0.5, 0.48]
const BOSS_SIDE_X := [0.0, 272.0, 342.0, 378.0, 396.0, 406.0]
const BOSS_CENTER_Y := 562.0
const TEX_TARGET_GLOW := "res://assets/ui/ingame/card_border_yellow_glow.webp"
const TARGET_Z := 60                     # salles / heros / boss ciblables : passent devant le voile du mode ciblage (z 40)
const GOLD := Color(0.95, 0.78, 0.3)
const CREAM := Color(0.93, 0.87, 0.7)
const APK_GOLD := Color(0.804, 0.694, 0.373) # texte or de l'APK (nom du boss, nombres de pioche, « XP ») : (205, 177, 95)

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
var _ui_layer: Control                   # barre de temps, pile de sorts, notices, zoom, glisser (devant la main, derriere les fenetres)
var _win_bar: TimeBar
var win_time_scale := 1.0                # tests : raccourcit les fenetres chronometrees
var _win_t := 0.0
var _win_sig := ""
var _last_ms := 0                        # horloge reelle du dernier _process : Godot plafonne delta a ~0,13 s par image (web a quelques i/s)
var _hand_stale := false                 # un refresh() a ete saute pendant un appui sur une carte de la main (voir _refresh_hand)
var _speed := 1.0                        # GameSettings.GetSpeed : SLOW 1,5 / NORMAL 1 / FAST 0,5 (durees des animations de heros)
var _warn: Control                       # bulle de mise en garde « YOU CAN BUILD A ROOM »
var _warn_t := 0.0
var _gameover: Control
var _press := {}                         # appui sur une carte de la main : {card, idx, pos} (arme le glisser)
var _drag := {}                          # glisser en cours : {idx, preview, frames}
var _zoom: Control                       # zoom d'appui long
var _stack_sig := ""
var _stack_ui: Control
var _notice: Control
var _hand_seen: Array = []               # cartes de la main deja vues (animation de pioche)
var _hand_seen_pid := -1
var _souls_seen := -1
var _wounds_seen := -1
# Choix de la cible sur le plateau : {} = inactif ; sinon {pid, title, hint, entries: [{label, cb, mv, spot}]}.
var _tgt: Dictionary = {}
var _tgt_layer: Control                  # voile + bulle + CANCEL + zones cliquables (un Control par cible affichee)
var _tgt_cancel_btn: Button
var _tgt_spots: Array = []               # [{ctrl, ids}] : ids = indices dans _tgt.entries atteints par cette zone
var _tgt_lifted: Array = []              # noeuds du plateau passes devant le voile (remis a z 0 a la fin)
var _town_header: TextureRect           # « HEROES IN TOWN » ; « EPIC / HEROES IN TOWN » (cadre or) tant qu'un heros epique est en ville
var _town_scroll: ScrollContainer
var _town_drag := {}                     # glisser la colonne HEROES IN TOWN (VerticalScrollQueueComponent) : {y, sv}
var _town_sig := ""                      # heros affiches : la colonne n'est reconstruite (et son defilement garde) que s'ils changent
var _town_ids: Array = []
var _ent_tok: Dictionary = {}            # pid -> cartes de l'entree, alignees sur les heros de `entrance` (la carte du heros qui traverse reste a l'entree)
var _focus := {}                         # {pid, room} : salle agrandie parce que le heros s'y trouve (voir _set_focus)
var _bait_t0 := 0                        # BAIT PHASE : horloge (ms) du debut du leurre, 0 = aucun (voir _refresh_phase_banner)
var _bait_flown := {}                    # cartes deja parties en vol pour ce leurre : {pid:id:rang -> _bait_t0}
var _foe_down := {}                      # emplacement adverse -> salle face cachee au dernier affichage (retournement a la revelation)
var _lvl_busy := false                   # la banniere LEVEL UP passe : le choix de niveau attend sa fin (l'APK enchaine banniere puis choix)
var _lvl_seen := {}                      # pid -> « monte de niveau » deja vu : un passage a vrai joue la banniere LEVEL UP (_show_levelup)
# Carrousel du choix du boss
var _boss_sel := 0
var _boss_cards: Array = []
var _boss_ready := false                 # la rotation est finie et s'est arretee sur le boss tire (PLAY BOSS MONSTER! / pose automatique possibles)
var _boss_name := ""
var _boss_pick_id := ""                  # boss tire par la partie pour le siege affiche (RandomBossSelectionScene) ; le carrousel n'est que decoratif
var _boss_seat := -1                     # siege pour lequel le carrousel a ete construit (-1 = aucun)
var _boss_gen := 0                       # change a chaque carrousel : invalide les minuteries d'un carrousel abandonne
var _boss_tw: Tween
const BOSS_FLIP_TIME := 0.5              # FlipCardBehavior de l'APK : 0,5 s
const BOSS_WAIT_TIME := 0.5              # attente avant la rotation et apres elle
const BOSS_SPIN_TIME := 5.0              # rotation : easing cubique in-out sur 2N + rand(N) cartes
const BOSS_AUTO_TIME := 2.0              # partie a plusieurs (useTimeout) : l'ecran se ferme seul 2 s apres l'arret
var _handing_over := false               # passage de main (hot-seat) en cours : GamePlayPaPScene
var _follow_last := -1                   # dernier siege cible par le suivi hot-seat (un changement manuel de siege tient jusqu'au prochain changement)
# Fenetres de sorts de l'APK (GamePlayBaseScene) : barre verte de 3 s au-dessus du heros (aventure), de 6 s au-dessus de la pile de sorts.
const BAIT_TIME := 1.3                   # plaque BAIT PHASE affichee entre la revelation des salles et l'aventure
const BAIT_FLY := 0.9                    # vol d'une carte de heros depuis la ville jusqu'a l'entree du donjon
const WINDOW_ADVENTURE := 3.0
const WINDOW_STACK := 6.0
const PASS_FAST := 0.45                  # rien a jouer : le siege humain passe presque tout de suite
const GO_FAST := 0.55                    # le heros suivant avance de lui-meme (multiplie par la vitesse de jeu)
const DRAG_SLOP := 12.0                  # glisser d'une carte de la main : au-dela de 12 px
const WARN_TIME := 6.0                   # bulle « YOU CAN BUILD A ROOM » : le 2e appui sur PASS TURN confirme tant qu'elle est la
const TEX_PASS := UI_DIR + "pass_button.webp"
const TEX_DONE := UI_DIR + "done_button_unlimited.webp"
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
	hero_crossing_layer.z_index = 5 # devant la salle agrandie (z 4, voir _apply_focus)
	add_child(hero_crossing_layer)
	_ui_layer = Control.new()
	_ui_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui_layer.size = Vector2(1920, 1080)
	_ui_layer.z_index = 20
	add_child(_ui_layer)
	_win_bar = TimeBar.new()
	_win_bar.visible = false
	_ui_layer.add_child(_win_bar)
	_speed = _speed_factor()

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
	# Entree : APK = les heros en attente sont des CARTES (136 x 196, centrees sur la rangee des emplacements) ; la 1re est devant,
	# x 464..600, les suivantes en eventail derriere elle (voir _refresh_entrances).
	var entrance := Control.new()
	entrance.position = Vector2(HERO_FRONT_X, SLOT_Y[idx] - 10.5)
	entrance.size = HERO_CARD
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
	L["dmg"] = _lbl(root, "0", 19, Color.WHITE, Vector2(1355 + 105 - 25, 20), 50.0, _fa, HORIZONTAL_ALIGNMENT_CENTER) # APK : chiffre centre sur le coeur (y 96 / 532), ~13 px de haut
	_img(root, TEX_XP_BADGE, Vector2(1503, 12))
	L["xp"] = _lbl(root, "0XP", 22, Color.WHITE, Vector2(1509, 12 + 11), 0.0, _fb)
	L["xp_unit"] = _lbl(root, "XP", 22, APK_GOLD, Vector2(1509, 12 + 11), 0.0, _fb) # APK : « XP » en or, les chiffres en blanc (recouvre le « XP » blanc de L["xp"])
	L["lvl"] = _lbl(root, "1", 24, Color.WHITE, Vector2(1503 + 95, 12 + 7), 40.0, _fa, HORIZONTAL_ALIGNMENT_CENTER)
	L["icon"] = _img(root, "", Vector2(1503 + 153 - 13, 12 + 25 - 13), Vector2(26, 26), TextureRect.STRETCH_KEEP_ASPECT_CENTERED)
	return L

func _build_frame() -> void:
	# Colonnes laterales en pierre sombre + traits dores, barres haute et basse.
	for x in [0.0, 1708.0]:
		var w: float = 183.0 if x == 0.0 else 212.0
		var stone := _img(self, "res://assets/ui/ingame/bg_levelup_panel.webp", Vector2(x, 0), Vector2(w, 1080), TextureRect.STRETCH_TILE)
		stone.modulate = Color(0.55, 0.45, 0.7, 0.45)
		_rect(self, Color(0.08, 0.03, 0.12, 0.62), Vector2(x, 0), Vector2(w, 1080)) # APK : panneau translucide, le couloir se devine derriere
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
	_town_header = _img(self, UI_DIR + "heroes_in_town_top.webp", Vector2(0, 0), Vector2(183, 96))
	discard_btn = _tex_button(self, UI_DIR + "discard_pile.webp", "", Vector2(0, 907), Vector2(192, 149))

func _build_right() -> void:
	# --- Boss adverse (positions mesurees sur les frames de l'APK ; polices : arcadepix A pour tout le texte de la colonne)
	_img(self, UI_DIR + "boss_icon.webp", Vector2(1712.5, 74.5), Vector2(43, 43), TextureRect.STRETCH_KEEP_ASPECT_CENTERED)
	foe_name_label = _lbl(self, "", 18, APK_GOLD, Vector2(1762, 75), 150.0, _fa)
	foe_sub_label = _lbl(self, "", 11, Color.WHITE, Vector2(1762, 100), 110.0, _fa)
	foe_sub_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	foe_sub_label.add_theme_constant_override("line_spacing", -4)
	_img(self, TEX_WOUND, Vector2(1715.5, 138), Vector2(27, 35), TextureRect.STRETCH_KEEP_ASPECT_CENTERED)
	foe_wounds_label = _lbl(self, "x0", 18, Color.WHITE, Vector2(1746, 142), 0.0, _fa)
	_img(self, TEX_SOUL, Vector2(1775.5, 137.5), Vector2(29, 34), TextureRect.STRETCH_KEEP_ASPECT_CENTERED)
	foe_souls_label = _lbl(self, "x0", 18, Color.WHITE, Vector2(1806, 142), 0.0, _fa)
	foe_treasures_box = Control.new()
	foe_treasures_box.position = Vector2(1715, 197)
	foe_treasures_box.size = Vector2(202, 68)
	foe_treasures_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(foe_treasures_box)
	_img(foe_treasures_box, UI_DIR + "bg_treasures_boss_profile.webp", Vector2.ZERO, Vector2(202, 68)).modulate = Color(1, 1, 1, 0.6)
	foe_coins_label = _lbl(self, "", 12, GOLD, Vector2(1718, 268))
	# --- Pioches
	_lbl(self, "ROOM DECK", 16, Color.WHITE, Vector2(1718, 286), 0.0, _fa)
	_img(self, UI_DIR + "rooms_icon.webp", Vector2(1717, 315), Vector2(50, 48))
	room_deck_label = _lbl(self, "x0", 20, APK_GOLD, Vector2(1784, 335), 0.0, _fa)
	_lbl(self, "SPELL DECK", 16, Color.WHITE, Vector2(1718, 382), 0.0, _fa)
	_img(self, UI_DIR + "spells_icon.webp", Vector2(1717, 410), Vector2(50, 48))
	spell_deck_label = _lbl(self, "x0", 20, APK_GOLD, Vector2(1784, 431), 0.0, _fa)
	deck_info_label = _lbl(self, "", 13, GOLD, Vector2(1718, 472))
	# --- Mon boss
	_img(self, UI_DIR + "boss_icon.webp", Vector2(1712.5, 507.5), Vector2(43, 43), TextureRect.STRETCH_KEEP_ASPECT_CENTERED)
	sidebar_boss_label = _lbl(self, "", 18, APK_GOLD, Vector2(1762, 508), 150.0, _fa)
	sidebar_sub_label = _lbl(self, "", 11, Color.WHITE, Vector2(1762, 533), 110.0, _fa)
	sidebar_sub_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sidebar_sub_label.add_theme_constant_override("line_spacing", -4)
	_lbl(self, "WOUNDS", 16, Color.WHITE, Vector2(1718, 578), 0.0, _fa)
	wounds_container = HBoxContainer.new()
	wounds_container.position = Vector2(1718, 606)
	wounds_container.add_theme_constant_override("separation", 3)
	add_child(wounds_container)
	_lbl(self, "SOULS", 16, Color.WHITE, Vector2(1718, 642), 0.0, _fa)
	souls_container = HBoxContainer.new()
	souls_container.position = Vector2(1718, 668)
	souls_container.add_theme_constant_override("separation", 0)
	add_child(souls_container)
	_lbl(self, "TREASURES", 16, Color.WHITE, Vector2(1718, 704), 0.0, _fa)
	treasures_container = Control.new()
	treasures_container.position = Vector2(1717, 737)
	treasures_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(treasures_container)
	levelup_btn = _tex_button(self, UI_DIR + "levelup_bt.webp", UI_DIR + "levelup_bt_pressed.webp", Vector2(1722, 978), Vector2(183, 59))

func _build_actions() -> void:
	# PASS TURN / GO centres sur la separation des deux couloirs.
	action_box = HBoxContainer.new()
	action_box.position = Vector2(PLAY_CX - 195, 464) # APK : PASS TURN x 851..1048, y 465..536
	action_box.size = Vector2(400, 82)
	action_box.alignment = BoxContainer.ALIGNMENT_CENTER
	action_box.add_theme_constant_override("separation", 12)
	add_child(action_box)
	btn_advance = _tex_button(action_box, UI_DIR + "go_button.webp", UI_DIR + "go_button_pressed.webp", Vector2.ZERO, Vector2(75, 82))
	btn_pass = _tex_button(action_box, UI_DIR + "pass_button.webp", UI_DIR + "pass_button_pressed.webp", Vector2.ZERO, Vector2(201, 82))
	# Coups propres aux extensions du wiki (aucun equivalent APK) : cachee tant qu'il n'y en a pas.
	bar_box = VBoxContainer.new()
	bar_box.position = Vector2(PLAY_CX - 150, 548) # un seul bouton entre PASS TURN (y <= 536) et les emplacements (y >= 635)
	bar_box.size = Vector2(300, 62)
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
	for gy in [0.0, 398.0]: # filets or du bandeau de la defausse (APK : y 296 et 696)
		var gl := _rect(_dim, Color(0.667, 0.533, 0.2), Vector2(0, gy), Vector2(1523, 2))
		gl.name = "GoldLine"
		gl.visible = false
	_bubble = _img(self, UI_DIR + "top_globe.webp", Vector2(PLAY_CX - 440, 150)) # APK : bulle x 510..1430
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
	phase_banner = _img(self, "", Vector2(PLAY_CX - 210, -62), Vector2(403, 153)) # APK : plaque x 739..1135 (centre 937)
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

## Siege humain que la vue doit montrer (hot-seat, hors aventure) : celui qui doit encore recevoir son boss, poser sa salle initiale,
## repondre a un choix ou jouer son tour de construction ; -1 = aucun changement.
func _follow_target(G: Dictionary) -> int:
	var phase := str(G.get("phase", ""))
	var players: Dictionary = G.get("players", {})
	var humans: Array = []
	for pid in players:
		var q: Dictionary = players[pid]
		if not bool(q.get("isAI", false)) and not bool(q.get("eliminated", false)):
			humans.append(int(pid))
	humans.sort()
	if humans.size() < 2 or G.get("gameOver") != null or not (phase in ["boss", "setup", "build"]):
		return -1
	var t := -1
	var pc: Dictionary = G.get("pendingChoice", {})
	if not pc.is_empty():
		t = int(pc.get("playerId", -1))
	elif phase == "boss":
		for h in humans:
			if (players[h] as Dictionary).get("boss") == null:
				t = h
				break
	elif phase == "setup" and bool(G.get("setupBuild", false)):
		for h in humans:
			if not bool((players[h] as Dictionary).get("passed", false)):
				t = h
				break
	elif phase == "build":
		t = game_manager.active_player()
		if G.has("buildWindow"): # fenetre de sorts avant la revelation : le premier humain qui n'a pas encore passe
			t = -1
			for h in humans:
				if not bool((G["buildWindow"] as Dictionary).get(h, false)):
					t = h
					break
	return t if humans.has(t) else -1

## Passage de main du pass and play (GamePlayPaPScene) quand le joueur actif change : la main sort par le bas (0,5 s), les deux donjons
## s'estompent, la vue passe au nouveau siege, les donjons reviennent et sa main remonte. Le choix manuel d'un siege (barre PLAYER n) tient
## jusqu'au prochain changement de joueur actif. Vrai si l'animation commence (le rafraichissement reprend a mi-course).
func _follow_seat(G: Dictionary) -> bool:
	if _handing_over:
		return false
	var t := _follow_target(G)
	var changed := t != _follow_last
	_follow_last = t
	if not changed or t < 0 or t == view_pid:
		return false
	if skip_animations:
		view_pid = t
		_sync_slot_pids()
		return false
	_handing_over = true
	var lanes: Array = [_lane[0]["root"], _lane[1]["root"]]
	var tw := create_tween()
	tw.tween_property(hand_layer, "position:y", 600.0, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	for l in lanes:
		tw.parallel().tween_property(l, "modulate:a", 0.0, 0.5)
	tw.tween_callback(func():
		view_pid = t
		_sync_slot_pids()
		refresh())
	tw.tween_property(hand_layer, "position:y", 0.0, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	for l in lanes:
		tw.parallel().tween_property(l, "modulate:a", 1.0, 0.5)
	tw.tween_callback(func():
		_handing_over = false
		refresh())
	return true

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
		slot.zoom_on.connect(_zoom_show)
		slot.zoom_off.connect(_zoom_hide)
		slot.room_dropped.connect(func(_h: int, _s: int):
			_play_sfx("res://assets/audio/sfx/sfx_room_physical.wav")
			refresh())
		_dungeon_slots.append(slot)

func _process(delta: float) -> void:
	if game_manager == null or game_manager.G.get("gameOver") != null:
		return
	_tick_warn(delta)
	# Godot plafonne delta (~0,13 s) quand les images sont lentes (web, onglet en arriere-plan) : les fenetres chronometrees (APK : horloge reelle)
	# et l'IA suivent donc l'horloge murale si elle avance plus vite (au plus 1 s par image : un onglet endormi ne vide pas la barre d'un coup).
	var now := Time.get_ticks_msec()
	var dt: float = maxf(delta, minf(float(now - _last_ms) / 1000.0, 1.0)) if _last_ms > 0 else delta
	_last_ms = now
	if _animating_hero:
		return
	if _modal_open() and not _is_online():
		return # menu / regles ouverts : la partie locale est en pause
	if _auto_pass(dt):
		return
	var players: Dictionary = game_manager.G.get("players", {})
	var phase: String = game_manager.G.get("phase", "")
	var pc: Dictionary = game_manager.G.get("pendingChoice", {})
	if phase == "boss" and players.values().any(func(q): return not bool((q as Dictionary).get("isAI", false)) and (q as Dictionary).get("boss") == null):
		return # les humains tirent leur boss d'abord : l'IA ne peut pas prendre celui que le carrousel va designer
	for pid in players:
		if not (players[pid] as Dictionary).get("isAI", false):
			continue
		var moves: Array = game_manager.legal_moves(int(pid))
		var has_ai_choice: bool = not pc.is_empty() and int(pc.get("playerId", -1)) == int(pid)
		# Aventure : l'IA active doit avancer / passer, sinon la partie attend indefiniment (pause : tous les sieges IA passent).
		var adv_turn: bool = phase == "adventure" and pc.is_empty() and (int(pid) == game_manager.active_player() or ((game_manager.G.get("adventure", {}) as Dictionary).get("pause") != null))
		if not moves.is_empty() and (has_ai_choice or phase == "boss" or phase == "build" or adv_turn):
			_ai_timer += dt
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
					_notice_ai(int(pid), mv)
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

## Un seul siege humain hors ligne : le flux de l'APK (aucun bouton GO / PASS en aventure : le heros avance tout seul, une barre de temps
## laisse jouer un sort). Plusieurs humains (siege a siege) ou en ligne : boutons GO / PASS TURN comme avant.
func _apk_flow() -> bool:
	if _is_online():
		return false
	var n := 0
	for pid in (game_manager.G.get("players", {}) as Dictionary):
		if not bool(((game_manager.G["players"] as Dictionary)[pid] as Dictionary).get("isAI", false)):
			n += 1
	return n == 1

## GameSettings.GetSpeed de l'APK : SLOW 1,5 / NORMAL 1 / FAST 0,5 (durees des animations ; les barres de temps ne dependent pas de la vitesse).
func _speed_factor() -> float:
	return [1.5, 1.0, 0.5][Profile.load_speed()]

## La barre de temps s'arrete tant que le joueur manipule une carte (glisse / zoom) ou une fenetre (APK : SlowDown pendant le zoom).
func _win_paused() -> bool:
	return not _drag.is_empty() or _zoom != null or not _tgt.is_empty() or (_popup != null and is_instance_valid(_popup))

func _win_hide() -> void:
	if _win_bar != null:
		_win_bar.visible = false

## Barre verte : au-dessus du heros qui traverse (ou de son jeton a l'entree), au-dessus de la pile de sorts quand elle est ouverte.
func _win_show(want: float, stack_open: bool) -> void:
	_win_bar.visible = true
	_win_bar.frac = 1.0 - _win_t / maxf(want, 0.001)
	var anchor := Vector2(STACK_CX + 2.0, 198.0)
	if not stack_open:
		var adv: Dictionary = game_manager.G.get("adventure", {})
		var apid: int = int(adv.get("playerId", game_manager.active_player())) if not adv.is_empty() else game_manager.active_player()
		if _hero_pawn != null and is_instance_valid(_hero_pawn):
			anchor = _hero_pawn.global_position + Vector2(HERO_CARD.x / 2.0, HERO_CARD.y / 2.0 + HERO_SPRITE_DY + HERO_HEART_DY - 50.0) # au-dessus du coeur de PV du personnage
		else:
			var ent: Control = (_lane[1 if apid == view_pid else 0] as Dictionary)["entrance"]
			anchor = ent.global_position + Vector2(HERO_CARD.x / 2.0, -60.0)
	_win_bar.position = anchor - _win_bar.size / 2.0

## Automatisation UI de l'aventure et de la pile de sorts (aucune regle changee). Un humain qui n'a RIEN a jouer passe presque tout de suite ;
## flux APK : le heros suivant avance de lui-meme, et s'il y a un sort / une capacite a jouer, la barre de temps (3 s ; 6 s sur la pile)
## ouvre la fenetre, puis le jeu continue (passe / GO envoyes a la fin). Legacy (siege a siege, en ligne) : PASS TURN / GO manuels.
func _auto_pass(delta: float) -> bool:
	var G: Dictionary = game_manager.G
	var stack_open: bool = not (G.get("stack", []) as Array).is_empty()
	var phase := str(G.get("phase", ""))
	if not (G.get("pendingChoice", {}) as Dictionary).is_empty() or (phase != "adventure" and not stack_open):
		_auto_timer = 0.0
		_win_t = 0.0
		_win_sig = ""
		_win_hide()
		return false
	var apk := _apk_flow()
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
	var adv: Dictionary = G.get("adventure", {})
	var pause = adv.get("pause")
	for pid in pids:
		var moves: Array = game_manager.legal_moves(int(pid))
		if moves.is_empty():
			continue
		var decision := _has_decision(moves)
		var go_mv = null
		var pass_mv = null
		for m in moves:
			var t := str((m as Dictionary).get("type", ""))
			if t in GO_TYPES and go_mv == null:
				go_mv = m
			elif t in PASS_TYPES and pass_mv == null:
				pass_mv = m
		if (go_mv == null and pass_mv == null) or not apk and (go_mv != null or decision):
			continue
		# Fenetre chronometree. APK : UNE barre de 3 s par pas du heros (CreateWaitAndMoveHeroToNextSlotTask), qui est la fenetre ou l'humain peut jouer
		# un sort ; c'est la pause post-damage de Godot (fenetre de sorts de l'oracle), un sort jouable ou non, sans lien avec la vitesse de jeu
		# (GetSpeed ne touche que les animations). Le GO qui la precede et la pause pre-exit passent vite. Pile de sorts : barre de 6 s si un sort est jouable.
		var timed: bool = apk and ((not stack_open and str(pause) == "post-damage") or (stack_open and decision and str(pause) != "pre-exit"))
		var want: float = (WINDOW_STACK if stack_open else WINDOW_ADVENTURE) * win_time_scale if timed else (GO_FAST * _speed if go_mv != null else PASS_FAST)
		# APK : la barre repart a zero a chaque pas du heros et a chaque sort / capacite jouee (pile), jamais parce qu'un siege passe ou qu'une ligne de journal s'ajoute.
		var key := JSON.stringify([phase, G.get("turn"), adv.get("playerId"), adv.get("roomIndex"), pause, (G.get("stack", []) as Array).size(), int(pid)])
		if key != _win_sig: # un pas du heros ou un sort / une capacite sur la pile rouvre une fenetre complete
			_win_sig = key
			_win_t = 0.0
		if not _win_paused():
			_win_t += delta
		if timed:
			_win_show(want, stack_open)
		else:
			_win_hide()
		if _win_t < want:
			return false # on laisse les IA passer pendant ce temps
		_win_t = 0.0
		_win_sig = ""
		_win_hide()
		var mv: Dictionary = ((go_mv if go_mv != null else pass_mv) as Dictionary).duplicate()
		if game_manager.apply_move(int(pid), mv):
			refresh()
		return true
	_auto_timer = 0.0
	_win_t = 0.0
	_win_sig = ""
	_win_hide()
	return false

# ---------------------------------------------------------------------------------------------------------------------
# Rafraichissement
# ---------------------------------------------------------------------------------------------------------------------

func refresh() -> void:
	if game_manager == null or game_manager.G.is_empty():
		return

	var G: Dictionary = game_manager.G
	if _zoom == null or not _zoom.has_meta("levelup"): # le zoom de LEVEL UP survit aux refresh (l'IA joue, state_changed) jusqu'au clic suivant
		_zoom_hide() # la main est reconstruite : un zoom d'appui long ne peut plus etre relache
	if _is_online():
		view_pid = _my_pid()
		_sync_slot_pids()
	elif _follow_seat(G):
		return # passage de main en cours : la vue est rafraichie a mi-course
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
		_show_gameover(G)
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
	_track_levelup(G)
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
	_apply_focus() # les emplacements adverses viennent d'etre reconstruits
	_refresh_overlay(G, phase)
	_refresh_hand(G, p, phase, my_moves)
	_refresh_activatable(my_moves)
	_refresh_undoable(my_moves)

	_target_sync(my_moves)
	var carousel := _carousel_active(G, phase)
	action_box.visible = not carousel and G.get("gameOver") == null and _tgt.is_empty() # plus rien a jouer a l'ecran de fin ; CANCEL remplace PASS TURN en ciblage
	var can_go := _has_any(my_moves, GO_TYPES)
	var can_pass := _has_any(my_moves, PASS_TYPES)
	var apk := _apk_flow() # APK : ni GO ni PASS TURN en aventure ni sur la pile de sorts (barre de temps), voir _auto_pass
	var stack_open: bool = not (G.get("stack", []) as Array).is_empty()
	btn_advance.visible = (phase == "adventure" or can_go) and not apk
	btn_advance.disabled = not can_go
	btn_advance.modulate = Color.WHITE if can_go else Color(0.5, 0.5, 0.5, 0.75)
	if phase == "adventure": # PASS TURN seulement s'il reste quelque chose a decider (sort / capacite)
		btn_pass.visible = can_pass and _has_decision(my_moves) and not apk
	elif stack_open:
		btn_pass.visible = can_pass and not apk
	else:
		btn_pass.visible = can_pass # pas de PASS TURN quand passer est illegal (choix en attente, pas mon tour de construire)
	_style_pass_button((phase == "build" or phase == "setup") and not stack_open) # DoneButtonEntity : DONE! ferme le tour de construction
	if _warn != null and not _can_still_build(my_moves):
		_warn_hide() # j'ai construit / ce n'est plus mon tour : la mise en garde n'a plus lieu d'etre
	_refresh_stack_cards(G)
	_track_hand_draw(G, p, phase)
	_refresh_choice_popup(G, my_moves)
	_refresh_extra_bar(G, my_moves)
	if not _drag.is_empty():
		_drag_refresh()
	_swap_resume()

func _carousel_active(G: Dictionary, phase: String) -> bool:
	return G.get("gameOver") == null and (_boss_pending(G) or _is_opening_discard_for_me())

## Le siege affiche doit encore recevoir son boss (carrousel) ; un siege qui a deja le sien voit le plateau.
func _boss_pending(G: Dictionary) -> bool:
	return G.get("gameOver") == null and str(G.get("phase", "")) == "boss" and ((G.get("players", {}) as Dictionary).get(view_pid, {}) as Dictionary).get("boss") == null

## Un seul humain (solo) : PLAY BOSS MONSTER! ; plusieurs (pass and play / en ligne) : l'ecran se ferme seul.
func _boss_solo(G: Dictionary) -> bool:
	return (G.get("players", {}) as Dictionary).values().filter(func(q): return not bool((q as Dictionary).get("isAI", false))).size() == 1

func _refresh_overlay(G: Dictionary, phase: String) -> void:
	var over: bool = G.get("gameOver") != null
	var boss_pick := _boss_pending(G)
	var discard := _is_opening_discard_for_me() and not over
	_dim.visible = boss_pick or discard
	# APK : choix du boss = tout l'ecran s'assombrit (panneaux et plaque de phase compris) ; defausse d'ouverture = seulement le bandeau
	# des cartes (y 296..696, filets or), le reste du plateau reste visible et la plaque de phase est cachee.
	_dim.color = Color(0, 0, 0, 0.92 if boss_pick else 0.88)
	_dim.position = Vector2.ZERO if boss_pick else Vector2(184, 296)
	_dim.size = Vector2(1920, 1080) if boss_pick else Vector2(1523, 400)
	for gl in _dim.get_children():
		gl.visible = discard
	phase_banner.visible = not over and not discard
	phase_banner.modulate.a = 0.25 if boss_pick else 1.0
	top_menu_btn.modulate.a = 0.25 if boss_pick else 1.0
	_bubble.visible = discard
	_carousel_text.visible = boss_pick or discard
	_confirm_btn.visible = (boss_pick and _boss_ready and _boss_solo(G)) or (discard and discard_pick.size() == 2) # fin de partie : GameOverBanner (bouton OK)
	_confirm_btn.text = "PLAY BOSS MONSTER!" if boss_pick else "CONTINUE"
	# APK : PLAY BOSS MONSTER! est une grande pierre au centre du bas de l'ecran (apk game_01_boss), CONTINUE reste plus petit.
	_confirm_btn.custom_minimum_size = Vector2(400, 92) if boss_pick else Vector2(220, 54)
	_confirm_btn.size = _confirm_btn.custom_minimum_size
	_confirm_btn.add_theme_font_size_override("font_size", 28 if boss_pick else 24)
	_confirm_btn.position = Vector2(PLAY_CX - 200, 923) if boss_pick else Vector2(PLAY_CX - 110, 730)
	_style_confirm(discard)
	_style_boss_label(boss_pick)
	if boss_pick:
		_carousel_text.position = Vector2(PLAY_CX - 600, 108)
		_carousel_text.size = Vector2(1200, 90)
		_set_carousel_text("YOU ARE [color=#f0c040]%s[/color]" % (_boss_name if _boss_ready else "..."), 56)
	elif discard:
		_set_carousel_text("SELECT [color=#f0c040]2[/color] CARDS TO DISCARD", 21)
		_carousel_text.position = Vector2(STACK_CX + 2 - 465, 204) # APK : texte centre en x 962, y 215
		_carousel_text.size = Vector2(931, 50)

## CONTINUE de la defausse d'ouverture : le losange de l'APK (continue_button, libelle compris, x 1540 y 410) ; PLAY BOSS MONSTER! reste la pierre.
func _style_confirm(diamond: bool) -> void:
	_confirm_btn.clip_text = diamond # le libelle (invisible) ne doit pas elargir le losange
	if diamond:
		for n in ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed"]:
			var sb := StyleBoxTexture.new()
			sb.texture = _tex(UI_DIR + ("continue_button_pressed.webp" if n in ["pressed", "hover_pressed"] else "continue_button.webp"))
			if n == "hover":
				sb.modulate_color = Color(1.2, 1.15, 1.0)
			_confirm_btn.add_theme_stylebox_override(n, sb)
		for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
			_confirm_btn.add_theme_color_override(c, Color(0, 0, 0, 0)) # le libelle est dans l'image
		_confirm_btn.custom_minimum_size = Vector2(131, 173)
		_confirm_btn.size = Vector2(131, 173)
		_confirm_btn.position = Vector2(1540, 410)
	else:
		for n in ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed"]:
			_confirm_btn.remove_theme_stylebox_override(n)
		for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
			_confirm_btn.remove_theme_color_override(c)

## PLAY BOSS MONSTER! : « PLAY » blanc, « BOSS MONSTER! » or (APK) ; le texte du bouton (lu par les tests) est cache, deux libelles le remplacent.
func _style_boss_label(on: bool) -> void:
	var box := _confirm_btn.get_node_or_null("BossLabel") as HBoxContainer
	if box == null:
		box = HBoxContainer.new()
		box.name = "BossLabel"
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.alignment = BoxContainer.ALIGNMENT_CENTER
		box.add_theme_constant_override("separation", 0)
		box.set_anchors_preset(Control.PRESET_FULL_RECT)
		_confirm_btn.add_child(box)
		_lbl(box, "PLAY ", 28, Color.WHITE, Vector2.ZERO, 0.0, _fb)
		_lbl(box, "BOSS MONSTER!", 28, GOLD, Vector2.ZERO, 0.0, _fb)
	box.visible = on
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		if on:
			_confirm_btn.add_theme_color_override(c, Color(0, 0, 0, 0))
		elif not _confirm_btn.clip_text: # le losange gere lui-meme ses couleurs (_style_confirm)
			_confirm_btn.remove_theme_color_override(c)

func _set_carousel_text(bb: String, font_size: int) -> void:
	_carousel_text.add_theme_font_size_override("normal_font_size", font_size)
	_carousel_text.text = "[center]%s[/center]" % bb

func _refresh_lane_badges(idx: int, pl: Dictionary) -> void:
	var L: Dictionary = _lane[idx]
	var boss = pl.get("boss")
	(L["dmg"] as Label).text = str(_get_total_dungeon_damage(pl))
	var xp_n := int((boss as Dictionary).get("xp", 0)) if boss != null else 0
	(L["xp"] as Label).text = "%dXP" % xp_n
	var xp_digits := str(xp_n)
	(L["xp_unit"] as Label).position.x = (L["xp"] as Label).position.x + _fb.get_string_size(xp_digits, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
	(L["xp_unit"] as Label).text = "XP"
	(L["lvl"] as Label).text = "2" if bool(pl.get("leveledUp", false)) else "1"
	var tr: Array = (boss as Dictionary).get("treasures", []) if boss != null else []
	(L["icon"] as TextureRect).texture = _tex(str(TREASURE_TEX.get(int(tr[0]) if not tr.is_empty() else 0, "")))

## Un boss vient de monter de niveau (leveledUp passe a vrai) : banniere LEVEL UP dans son couloir. Le premier refresh ne fait que memoriser.
func _track_levelup(G: Dictionary) -> void:
	for pid in (G.get("players", {}) as Dictionary):
		var pl: Dictionary = G["players"][pid]
		var now := bool(pl.get("leveledUp", false))
		if _lvl_seen.has(pid) and now and not bool(_lvl_seen[pid]) and not skip_animations and pl.get("boss") != null:
			_show_levelup(int(pid), pl["boss"])
		_lvl_seen[pid] = now

## LevelUpBanner de l'APK (DungeonFrameEntity.CreateLevelUpAnimationTask) : le portrait du boss (xxx_hr) entre par la droite du couloir devant
## une etoile qui tourne, avec la plaque « <BOSS> HAS ACTIVATED / LEVEL UP!! » ; 0,5 s d'entree, 1 s d'arret, 0,5 s de sortie. Decoupe au
## couloir (couches DungeonTop / BottomScissor). Positions : portrait x droit 1886 -> 991, plaque x gauche 2586 -> 251, bas du portrait y 446 (haut) / 881 (bas).
func _show_levelup(pid: int, boss: Dictionary) -> void:
	var idx := 1 if pid == view_pid else (0 if pid == foe_pid else -1)
	if idx < 0:
		return
	_play_sfx("res://assets/audio/sfx/sting_levelup.wav")
	_lvl_busy = true
	var clip := Control.new()
	clip.name = "LevelUpBanner"
	clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip.clip_contents = true
	clip.position = Vector2(184, LANE_Y[idx])
	clip.size = Vector2(1523, LANE_H[idx])
	_ui_layer.add_child(clip)
	var bottom := float(LANE_Y[idx]) + 384.0 - clip.position.y
	var bx := 1886.0 - clip.position.x # bord droit du portrait, repere du decoupage
	var tex := _tex("res://assets/ui/characters/%s_hr.webp" % str(boss.get("id", "")).to_lower())
	var boss_node: Control = null
	if tex != null:
		boss_node = Control.new()
		boss_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
		boss_node.size = tex.get_size()
		clip.add_child(boss_node)
		var shine := Control.new() # 4 quarts de bg_lu_shine_cuarto tournes de 90 degres, l'etoile tourne (Spinner)
		shine.mouse_filter = Control.MOUSE_FILTER_IGNORE
		shine.position = tex.get_size() / 2.0
		boss_node.add_child(shine)
		for q in 4:
			var quarter := _img(shine, "res://assets/ui/gradients/bg_lu_shine_cuarto.webp", Vector2(-463, -465), Vector2(463, 465))
			quarter.pivot_offset = Vector2(463, 465)
			quarter.rotation = float(q) * PI / 2.0
			quarter.modulate.a = 0.7
		shine.create_tween().set_loops().tween_property(shine, "rotation", TAU, 8.0).from(0.0)
		var spr := _img(boss_node, "", Vector2.ZERO, tex.get_size())
		spr.texture = tex
		boss_node.position = Vector2(bx, bottom - tex.get_size().y)
	var panel := Control.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.size = Vector2(531, 136)
	clip.add_child(panel)
	UiKit.ninepatch(panel, "ninepatch/bg_levelup_banner.webp", Vector2.ZERO, Vector2(531, 136), Vector4(0, 1, 0, 1))
	var nm := str(boss.get("name", "")).strip_edges().to_upper()
	var nl := _lbl(panel, nm, 30, APK_GOLD, Vector2(40, 22), 0.0, _fa)
	_lbl(panel, "HAS ACTIVATED", 22, APK_GOLD, Vector2(40 + _fa.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x + 14.0, 30), 0.0, _fa)
	nl.name = "BossName"
	_lbl(panel, "LEVEL UP!!", 50, Color.WHITE, Vector2(70, 62), 0.0, _fa)
	panel.position = Vector2(2586.0 - clip.position.x, bottom - 200.0)
	var tw := clip.create_tween().set_parallel(true)
	if boss_node != null:
		tw.tween_property(boss_node, "position:x", 991.0 - clip.position.x - boss_node.size.x, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(panel, "position:x", 251.0 - clip.position.x, 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.chain().tween_interval(1.0)
	tw.chain().tween_property(panel, "position:x", 2586.0 - clip.position.x, 0.33).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	if boss_node != null:
		tw.tween_property(boss_node, "position:x", bx, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(func():
		clip.queue_free()
		_lvl_busy = false
		refresh()) # le choix de niveau (pendingChoice) peut s'afficher

func _refresh_town(G: Dictionary) -> void:
	var town: Array = G.get("town", [])
	var sig := JSON.stringify(town)
	if sig == _town_sig:
		return # memes heros : on garde les cartes (et le defilement de la colonne)
	_town_sig = sig
	var epic: bool = town.any(func(h): return bool((h as Dictionary).get("epic", false)))
	_town_header.texture = _tex(UI_DIR + ("epic_heroes_in_town_top.webp" if epic else "heroes_in_town_top.webp"))
	var keep_sv := _town_scroll.scroll_vertical
	for c in town_container.get_children():
		town_container.remove_child(c) # tout de suite : les zones de ciblage lisent les positions des nouvelles cartes
		c.queue_free()
	var pool := _town_ids.duplicate()
	var fresh := -1 # dernier heros arrive (absent de la ville precedente)
	var ids: Array = []
	for hi in town.size():
		var hero: Dictionary = town[hi]
		var hero_card = _card_scene.instantiate()
		hero_card.default_size = Vector2(154, 215)
		town_container.add_child(hero_card)
		hero_card.is_in_hand = false
		hero_card.setup(hero)
		hero_card.long_pressed.connect(_zoom_show)
		hero_card.long_released.connect(func(_c): _zoom_hide())
		ids.append(hero.get("id", hero))
		var k := pool.find(ids[hi])
		if k >= 0:
			pool.remove_at(k)
		else:
			fresh = hi
	_town_ids = ids
	_town_restore(keep_sv, fresh)

## Apres la mise en page des cartes : le defilement d'avant est restitue, et un heros qui vient d'arriver est amene a l'ecran
## (VerticalScrollQueueComponent.CreateShowBottomTask).
func _town_restore(sv: int, fresh: int) -> void:
	for i in 2:
		await get_tree().process_frame
	if not is_instance_valid(_town_scroll):
		return
	_town_scroll.scroll_vertical = sv
	if fresh >= 0 and fresh < town_container.get_child_count():
		_town_scroll.ensure_control_visible(town_container.get_child(fresh))

## Glisser (ou molette) dans la colonne HEROES IN TOWN : la colonne suit le doigt (VerticalScrollQueueComponent, TouchMoved) ; sous 12 px
## c'est un clic (la carte garde son appui long). Pas de rebond elastique (l'APK ramene la colonne dans [810 - hauteur, 0]).
func _town_input(event: InputEvent) -> void:
	if _town_scroll == null or _popup != null or _modal_open():
		_town_drag = {}
		return
	var rect := Rect2(_town_scroll.position, _town_scroll.size)
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		var pos: Vector2 = (make_input_local(event) as InputEventMouse).position
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_town_drag = {"y": pos.y, "sv": _town_scroll.scroll_vertical, "moved": false} if mb.pressed and rect.has_point(pos) else {}
		elif mb.pressed and (mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN) and rect.has_point(pos):
			_town_scroll.scroll_vertical += (-115 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else 115) # un demi-pas de carte
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and not _town_drag.is_empty():
		if not ((event as InputEventMouseMotion).button_mask & MOUSE_BUTTON_MASK_LEFT):
			_town_drag = {}
			return
		var dy: float = (make_input_local(event) as InputEventMouse).position.y - float(_town_drag["y"])
		if absf(dy) >= 12.0:
			_town_drag["moved"] = true
		if bool(_town_drag["moved"]):
			_town_scroll.scroll_vertical = int(float(_town_drag["sv"]) - dy)

func _refresh_entrances(p: Dictionary, foe: Dictionary) -> void:
	var rows := [[1, p], [0, foe]]
	for r in rows:
		var box: Control = (_lane[int(r[0])] as Dictionary)["entrance"]
		for c in box.get_children():
			box.remove_child(c)
			c.queue_free()
		var ents: Array = (r[1] as Dictionary).get("entrance", [])
		var pid_key: int = view_pid if int(r[0]) == 1 else foe_pid
		var pitch := clampf(30.0 + 6.0 * float(ents.size() - 2), 30.0, 48.0) # APK : 30 px de debord pour 2 cartes, 48 pour 5
		var toks: Array = []
		toks.resize(ents.size())
		var flying: bool = _bait_t0 > 0 and Time.get_ticks_msec() - _bait_t0 < int(BAIT_TIME * 1000.0)
		for k in range(ents.size() - 1, -1, -1): # la derniere d'abord : la premiere reste au premier plan
			var tok := _create_entrance_card(ents[k])
			tok.position = Vector2(-pitch * float(k), 0.0)
			box.add_child(tok)
			toks[k] = tok
			if flying: # carte arrivee par le leurre : cachee, un double vole depuis la ville (voir _fly_hero_card)
				tok.modulate.a = 0.0
				_fly_hero_card(pid_key, ents[k], k, tok)
		_ent_tok[pid_key] = toks

## Double de la carte d'entree qui vole de la colonne HEROES IN TOWN jusqu'a sa place (un seul par heros et par leurre, meme si l'entree est
## reconstruite entre-temps) ; l'ecart entre cartes d'un meme couloir decale les departs.
func _fly_hero_card(pid: int, hero: Dictionary, k: int, tok: Control) -> void:
	var gk := "%d:%s:%d" % [pid, str(hero.get("id", "")), k]
	if _bait_flown.get(gk, 0) == _bait_t0:
		return
	_bait_flown[gk] = _bait_t0
	var ghost := _create_entrance_card(hero)
	ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hero_crossing_layer.add_child(ghost)
	ghost.global_position = Vector2(23.0, 107.0)
	var tw := ghost.create_tween()
	tw.tween_interval(0.12 * float(k))
	tw.tween_property(ghost, "global_position", tok.global_position, BAIT_FLY).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_callback(ghost.queue_free)

func _create_entrance_card(hero: Dictionary) -> Control:
	var c = _card_scene.instantiate()
	c.default_size = HERO_CARD
	c.size = HERO_CARD
	c.is_in_hand = false
	c.setup(hero)
	c.long_pressed.connect(_zoom_show)
	c.long_released.connect(func(_c): _zoom_hide())
	return c

func _refresh_boss_platforms(p: Dictionary, foe: Dictionary) -> void:
	_set_boss(_lane[1], p.get("boss"), bool(p.get("eliminated", false)))
	_set_boss(_lane[0], foe.get("boss"), bool(foe.get("eliminated", false)))

## dead : boss elimine (5 blessures) = pierre tombale RIP a la place du sprite (APK bosses_tombstone).
func _set_boss(L: Dictionary, boss, dead := false) -> void:
	var sprite: TextureRect = L["sprite"]
	var plat: Control = L["platform"]
	var cont: CenterContainer = L["container"]
	var tex: Texture2D = null
	if boss != null:
		var bid := str(boss.get("id", "")).to_lower()
		var bg := _tex("res://assets/ui/dungeon/%s_bg.webp" % bid)
		if bg == null: # boss du wiki sans fond APK : un des fonds APK, choisi d'apres l'id (toujours le meme pour un boss)
			bg = _tex("res://assets/ui/dungeon/%s_bg.webp" % WIKI_BG_IDS[absi(bid.hash()) % WIKI_BG_IDS.size()])
		(L["bg"] as TextureRect).texture = bg
		tex = _tex("res://assets/ui/characters/%s_character.webp" % bid)
		if tex != null:
			for child in cont.get_children():
				child.queue_free()
		else:
			_ensure_boss_card(cont, boss, L["root"] == (_lane[0] as Dictionary)["root"])
	else:
		tex = _tex(TEX_UNKNOWN_BOSS)
	if dead:
		tex = _tex(UI_DIR + "bosses_tombstone.webp")
	sprite.visible = tex != null
	if tex != null:
		sprite.texture = tex
		sprite.size = tex.get_size() * minf(BOSS_SPRITE_SCALE, BOSS_SPRITE_MAX_W / tex.get_size().x)
		sprite.position = Vector2((plat.size.x - sprite.size.x) / 2.0, plat.size.y - sprite.size.y)
		if dead:
			sprite.position.x = plat.size.x - sprite.size.x + 2.0 # APK : la pierre tombale est collee au bord droit du couloir (x ~1707)

## Boss sans sprite (wiki) : sa carte tient la place du sprite APK (a 1920x1080 : le mien x 1465..1610 / y 690..850, l'adversaire
## x 1470..1640 / y 270..440), carte 5:7 centree dans cette zone. Le conteneur centre la carte : on le decale pour viser le centre voulu.
func _ensure_boss_card(container: CenterContainer, boss_dict: Dictionary, is_foe: bool) -> void:
	for c in container.get_children():
		c.queue_free()
	var area := Rect2(1470, 270, 170, 170) if is_foe else Rect2(1465, 690, 145, 160)
	var plat := container.get_parent() as Control
	container.position = area.get_center() - ((plat.get_parent() as Control).position + plat.position) - plat.size / 2.0
	var boss_ui = _card_scene.instantiate()
	boss_ui.default_size = Vector2(area.size.y * 5.0 / 7.0, area.size.y)
	container.add_child(boss_ui)
	boss_ui.is_in_hand = false
	boss_ui.setup(boss_dict)

func _refresh_foe_dungeon(foe: Dictionary) -> void:
	var prev_down := _foe_down.duplicate()
	var holder: Control = _lane[0]["slots"]
	for c in holder.get_children():
		c.queue_free()
	_foe_slots.clear()

	var dungeon: Array = foe.get("dungeon", [])
	var off: int = maxi(0, CardDB.DUNGEON_SLOTS - dungeon.size())
	for j in CardDB.DUNGEON_SLOTS:
		_foe_down[j] = false
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
				DungeonSlot.add_under_cards(slot_ctrl, dungeon[di], _card_scene, SLOT_SIZE)
				var room_ui = _card_scene.instantiate()
				room_ui.default_size = SLOT_SIZE
				slot_ctrl.add_child(room_ui)
				room_ui.size = SLOT_SIZE
				room_ui.is_in_hand = false
				room_ui.setup(r)
				room_ui.add_lane_badge()
				room_ui.mouse_filter = Control.MOUSE_FILTER_PASS
				room_ui.long_pressed.connect(_zoom_show)
				room_ui.long_released.connect(func(_c): _zoom_hide())
				room_ui.set_frozen(BossEngine.is_room_deactivated(game_manager.G, foe_pid, di))
				room_ui.set_face_down_scale()
				var fd: bool = room_ui.card_data != null and room_ui.card_data.face_down
				if bool(prev_down.get(j, false)) and not fd and not skip_animations:
					room_ui.flip_in() # revelation : la salle adverse se retourne
				_foe_down[j] = fd
				if Minibosses.active(game_manager.G): # Rise of the Minibosses : le miniboss de la salle adverse (nom cache tant qu'il est face cache)
					var mb_badge := Minibosses.make_badge(r, false)
					if mb_badge != null:
						slot_ctrl.add_child(mb_badge)
						slot_ctrl.tooltip_text = Minibosses.badge_tooltip(r, false)
		holder.add_child(slot_ctrl)
		_foe_slots.append(slot_ctrl)

## Main du joueur : eventail en bas ; carrousel central pour le choix du boss et la defausse d'ouverture.
func _refresh_hand(G: Dictionary, p: Dictionary, phase: String, my_moves: Array) -> void:
	# Un appui est en cours sur une carte de la main : la reconstruire (coup de l'IA, rafraichissement) detruirait la carte qui doit voir le
	# relachement, donc le clic serait perdu (il en fallait un 2e). On attend le relachement (_press_clear) ; un glisser, lui, reconstruit.
	if not _press.is_empty() and _drag.is_empty() and phase != "boss" and G.get("gameOver") == null and hand_layer.get_child_count() > 0:
		_hand_stale = true
		return
	_hand_stale = false
	var boss_pick := _boss_pending(G)
	if boss_pick and _boss_seat == view_pid and not _boss_cards.is_empty() and hand_layer.get_child_count() > 0 			and (G.get("bossPicks", []) as Array).any(func(b): return str((b as Dictionary).get("id", "")) == _boss_pick_id):
		return # le carrousel tourne : un rafraichissement (coup de l'IA, journal) ne doit pas le reconstruire
	for c in hand_layer.get_children():
		c.queue_free()
	_boss_cards.clear()

	if G.get("gameOver") != null:
		return
	if boss_pick:
		_build_boss_carousel(G, my_moves)
		return
	_boss_stop()

	# Cartes jouables maintenant (construire / sort / capacite de la main) : les autres sont grisees comme dans l'APK.
	var playable: Dictionary = {}
	for m in my_moves:
		var hi: int = hand_idx_of(m as Dictionary)
		if hi >= 0:
			playable[hi] = true
	var hand: Array = p.get("hand", [])
	if not _moves_of(my_moves, "undoBuild").is_empty(): # APK : toute salle de la main reste prenable, elle remplace la pose en attente
		for hi in hand.size():
			if bool((hand[hi] as Dictionary).get("isRoom", false)) and not bool((hand[hi] as Dictionary).get("isMiniboss", false)):
				playable[hi] = true
	var discarding := _is_opening_discard_for_me()
	var sz := BIG_CARD if discarding else HAND_CARD
	var cards: Array = []
	for i in hand.size():
		var card_dict: Dictionary = hand[i]
		var card_ui = _spawn_card(card_dict, i, sz)
		var idx := i
		card_ui.card_clicked.connect(func(_data): _on_hand_card_clicked(idx, card_dict))
		card_ui.press_started.connect(_on_hand_press)
		card_ui.long_pressed.connect(_zoom_show)
		card_ui.long_released.connect(func(_c): _zoom_hide())
		if discard_pick.has(idx):
			card_ui.modulate = Color(1.3, 1.3, 0.4, 1.0)
			var glow := card_ui.get_node_or_null("GlowRect")
			if glow != null:
				glow.visible = true
		elif not discarding and (phase == "build" or phase == "setup" or phase == "adventure") and not playable.has(i):
			card_ui.set_greyed(true) # APK : carte injouable = grisee (toute la main pendant l'aventure sans sort jouable)
		elif not discarding and (phase == "adventure" or not (G.get("stack", []) as Array).is_empty()) and bool(card_dict.get("isSpell", false)):
			card_ui.set_gold(true) # APK : sort jouable pendant l'aventure ou une pile de sorts = cadre dore
		cards.append(card_ui)
	if discarding:
		_place_cards(cards, sz, 125.0, 1000.0, 338.0)
		for i in cards.size():
			if discard_pick.has(i):
				(cards[i] as Control).position.y -= 30.0
	else:
		_place_fan(cards, sz)

func _spawn_card(data: Dictionary, hand_idx: int, sz: Vector2) -> Control:
	var card_ui = _card_scene.instantiate()
	card_ui.default_size = sz
	hand_layer.add_child(card_ui)
	card_ui.size = sz
	card_ui.setup(data, hand_idx)
	return card_ui

# --- Choix du boss (RandomBossSelectionScene) : le boss est tire AU HASARD par la partie avant le carrousel, qui n'est que decoratif.
# Pool = propositions repetees jusqu'a >= 8 cartes, depart aleatoire, 0,5 s, cartes face cachee, rotation de 5 s (easing cubique) sur
# 2N + rand(N) cartes, 0,5 s, puis l'indice est force sur le vrai boss (face visible). Un seul humain : PLAY BOSS MONSTER! ; sinon fermeture seule apres 2 s.

func _boss_card_rect(d: int) -> Rect2:
	var k := mini(absi(d), BOSS_SIDE_X.size() - 1)
	var sz := BOSS_CARD * float(BOSS_SIDE_SCALE[k])
	return Rect2(Vector2(PLAY_CX + signf(d) * float(BOSS_SIDE_X[k]) - sz.x / 2.0, BOSS_CENTER_Y - sz.y / 2.0), sz)

func _boss_stop() -> void:
	_boss_gen += 1
	if _boss_tw != null:
		_boss_tw.kill()
	_boss_tw = null
	_boss_seat = -1
	_boss_ready = false
	_boss_pick_id = ""
	_boss_name = ""

func _build_boss_carousel(G: Dictionary, my_moves: Array) -> void:
	_boss_stop()
	_boss_cards.clear()
	var cands: Array = []
	for m in my_moves:
		if str((m as Dictionary).get("type", "")) == "pickBoss":
			cands.append(str(((m as Dictionary)["args"] as Array)[0]))
	var picks: Array = G.get("bossPicks", [])
	if cands.is_empty() or picks.is_empty():
		return
	_boss_seat = view_pid
	_boss_pick_id = str(cands[game_manager.rng.randi_range(0, cands.size() - 1)])
	var pool: Array = picks.duplicate()
	while pool.size() < 8:
		pool.append_array(picks)
	for b in pool:
		var c = _spawn_card(b, -1, BOSS_CARD)
		c.custom_minimum_size = Vector2.ZERO # la taille change avec la distance au centre
		c.mouse_entered.disconnect(c._on_mouse_entered) # pas de zoom / premier plan au survol : l'ordre du carrousel prime
		c.mouse_exited.disconnect(c._on_mouse_exited)
		_boss_cards.append(c)
	var n := pool.size()
	_boss_sel = game_manager.rng.randi_range(0, n - 1)
	_boss_layout(false)
	if skip_animations:
		for c in _boss_cards:
			_boss_flip_card(c, true, false)
		_boss_snap(false)
		return
	var steps := 2 * n + game_manager.rng.randi_range(0, n - 1)
	var start := _boss_sel
	_boss_tw = create_tween()
	_boss_tw.tween_interval(BOSS_WAIT_TIME)
	_boss_tw.tween_callback(func():
		for c in _boss_cards:
			if is_instance_valid(c):
				_boss_flip_card(c, true, true))
	_boss_tw.tween_interval(BOSS_FLIP_TIME)
	_boss_tw.tween_method(_boss_spin.bind(start, n), 0.0, float(steps), BOSS_SPIN_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_boss_tw.tween_interval(BOSS_WAIT_TIME)
	_boss_tw.tween_callback(func(): _boss_snap(true))

## Un cran de rotation : v = nombre de cartes deja passees depuis la carte de depart.
func _boss_spin(v: float, start: int, n: int) -> void:
	var i := posmod(start + int(v), n)
	if i != _boss_sel and _boss_cards.size() == n:
		_boss_sel = i
		_play_sfx("res://assets/audio/sfx/ui_button_select.wav")
		_boss_layout(true)

## Retourne une carte (rotation autour de l'axe vertical : largeur -> 0, changement de texture, 0 -> pleine largeur).
func _boss_flip_card(c: CardUI, to_back: bool, animate: bool) -> void:
	if not c.has_meta("face"):
		c.set_meta("face", c.texture_rect.texture)
	var tex: Texture2D = _tex(CardDB.card_image("", "back-boss")) if to_back else (c.get_meta("face") as Texture2D)
	if not animate:
		c.texture_rect.texture = tex
		return
	c.pivot_offset = c.size / 2.0
	var tw := c.create_tween().set_trans(Tween.TRANS_SINE)
	tw.tween_property(c, "scale:x", 0.0, BOSS_FLIP_TIME / 2.0).set_ease(Tween.EASE_IN)
	tw.tween_callback(func(): c.texture_rect.texture = tex)
	tw.tween_property(c, "scale:x", 1.0, BOSS_FLIP_TIME / 2.0).set_ease(Tween.EASE_OUT)

## Fin de la rotation : l'indice est force sur le vrai boss (la carte la plus proche), carte face visible, nom du boss.
func _boss_snap(animate: bool) -> void:
	var n := _boss_cards.size()
	var half := int(n * 0.5)
	var best := -1
	for i in n:
		if str((_boss_cards[i] as CardUI).card_dict.get("id", "")) == _boss_pick_id and (best < 0 or absi(posmod(i - _boss_sel + half, n) - half) < absi(posmod(best - _boss_sel + half, n) - half)):
			best = i
	if best < 0:
		return
	_boss_sel = best
	_boss_layout(false)
	var boss: Dictionary = (_boss_cards[best] as CardUI).card_dict
	_boss_flip_card(_boss_cards[best], false, animate)
	_boss_name = str(boss.get("name", "")).to_upper()
	_boss_ready = true
	_play_sfx("res://assets/audio/sfx/boss_female_intro.wav" if ["BMA006", "BMA007", "BMA008"].has(_boss_pick_id) else "res://assets/audio/sfx/boss_male_intro.wav")
	_refresh_overlay(game_manager.G, "boss")
	if _boss_solo(game_manager.G):
		if animate:
			_confirm_btn.modulate.a = 0.0
			create_tween().tween_property(_confirm_btn, "modulate:a", 1.0, 0.4) # le bouton apparait en fondu
		else:
			_confirm_btn.modulate.a = 1.0
	elif animate:
		var gen := _boss_gen
		get_tree().create_timer(BOSS_AUTO_TIME).timeout.connect(func():
			if gen == _boss_gen:
				_boss_confirm())
	else:
		_boss_confirm.call_deferred()

func _boss_layout(animate: bool) -> void:
	var n := _boss_cards.size()
	var half := int(n * 0.5)
	var rel: Array = []
	for i in n:
		rel.append(posmod(i - _boss_sel + half, n) - half) # distance signee au centre, le carrousel boucle
	var order: Array = range(n)
	order.sort_custom(func(a: int, b: int): return absi(int(rel[a])) > absi(int(rel[b]))) # la plus eloignee au fond
	for k in order.size():
		var c: Control = _boss_cards[int(order[k])]
		hand_layer.move_child(c, k)
		var d: int = int(rel[int(order[k])])
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

## Le boss tire est le notre : le coup part (PLAY BOSS MONSTER! en solo, minuterie en pass and play). Pas avant la fin de la rotation.
func _boss_confirm() -> void:
	if not _boss_ready:
		return
	_boss_ready = false # un seul appui / une seule minuterie compte
	_do({"type": "pickBoss", "args": [_boss_pick_id]})

func _input(event: InputEvent) -> void:
	# Un nouvel appui gauche alors qu'un appui est encore arme : le relachement precedent s'est perdu (hors canvas / fenetre).
	if not _press.is_empty() and _drag.is_empty() and event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		_press = {}
		_press_recheck.call_deferred() # apres _gui_input : si ce nouvel appui est sur une carte de la main, _on_hand_press a rearme _press
	if _zoom != null and event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		_zoom_hide() # le zoom de LEVEL UP part au clic suivant (le zoom d'appui long se ferme deja au relachement)
	if not _press.is_empty() or not _drag.is_empty():
		_drag_input(event)
	_town_input(event)

## Aligne les cartes (chevauchement si necessaire) autour de PLAY_CX, sur une ligne (ecran de defausse d'ouverture).
func _place_cards(cards: Array, sz: Vector2, step_max: float, span_max: float, top_y: float) -> void:
	var n := cards.size()
	if n == 0:
		return
	var step := step_max if n == 1 else minf(step_max, (span_max - sz.x) / float(n - 1))
	var x0 := PLAY_CX - (step * (n - 1) + sz.x) / 2.0
	for i in n:
		(cards[i] as Control).position = Vector2(x0 + step * i, top_y)

## Main en eventail : transcription de CardPositionComponent de l'APK (HandEntity : RotationMax 9 deg, MaxDistanceBtwCards 250,
## DistanceUnselectedFactor 0,8, ArcHeight -30) ; centres des cartes, repere ecran 1920x1080. La carte survolee monte en entier,
## se redresse et passe au premier plan (z_index de CardUI).
func _place_fan(cards: Array, sz: Vector2) -> void:
	var n := cards.size()
	if n == 0:
		return
	var half := minf(float(n - n % 2) * 250.0 * 0.8, 1200.0) * 0.5 # largeur utile : 1200 = 900 (HandEntity) x 1920/1440
	var rot_inc := 9.0 * clampf(float(n) / 11.2, 0.0, 1.0) / float(n) # 11,2 = 1,4 x 8 cartes visibles (900 / 125)
	for i in n:
		var c: Control = cards[i]
		var cx := HAND_CX + lerpf(-half, half, float(i + 1) / float(n + 1))
		var cy := HAND_CY - 30.0 * sin(PI / float(n) * (float(i) + 0.5))
		c.position = Vector2(cx, cy) - sz / 2.0
		c.rotation_degrees = rot_inc * (float(i) - float(n) * 0.5)
		(c as CardUI).hover_scale = 1.0 # l'APK ne grossit pas la carte touchee : elle monte seulement
		var base_y := c.position.y
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
	var prev := _last_phase
	_last_phase = phase
	var key := "build" if (phase == "setup" or phase == "boss") else phase
	if PHASE_BANNERS.has(key):
		phase_banner.texture = _tex(PHASE_BANNERS[key])
	# APK : entre la revelation des salles et l'aventure, la plaque BAIT PHASE s'affiche pendant que les heros de la ville volent vers les
	# donjons (leurre). Le moteur n'a pas cette phase : l'interface montre la plaque et le vol, sans retarder la partie.
	if key == "adventure" and prev == "build" and not skip_animations:
		_bait_t0 = Time.get_ticks_msec()
		phase_banner.texture = _tex(PHASE_BANNERS["bait"])
		var tw := phase_banner.create_tween()
		tw.tween_interval(BAIT_TIME)
		tw.tween_callback(_bait_end)

func _bait_end() -> void:
	_bait_t0 = 0
	if _last_phase == "adventure":
		phase_banner.texture = _tex(PHASE_BANNERS["adventure"])
	for k in _ent_tok:
		for t in (_ent_tok[k] as Array):
			if t != null and is_instance_valid(t):
				(t as Control).modulate.a = 1.0

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

## Les icones apparues depuis le dernier rafraichissement (from -> to) s'allument : flash blanc qui retombe.
func _flash_icons(box: Container, from: int, to: int) -> void:
	if from < 0 or to <= from:
		return
	for i in range(from, mini(to, box.get_child_count())):
		var ic: Control = box.get_child(i)
		ic.modulate = Color(3.0, 3.0, 2.2)
		ic.create_tween().tween_property(ic, "modulate", Color.WHITE, 0.9)

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

## Un nom trop long pour la colonne (1762..1912) est reduit pour y tenir (l'APK ne deborde pas).
func _fit_label(l: Label, max_w: float, base: int) -> void:
	var f: Font = l.get_theme_font("font")
	var sz := base
	while sz > 9 and f.get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x > max_w:
		sz -= 1
	l.add_theme_font_size_override("font_size", sz)

func _refresh_sidebar(G: Dictionary, p: Dictionary, foe: Dictionary) -> void:
	# Mon boss
	var pb = p.get("boss")
	sidebar_boss_label.text = str(pb.get("name", "")).to_upper() if pb != null else ""
	_fit_label(sidebar_boss_label, 150.0, 18)
	sidebar_sub_label.text = str(pb.get("subtitle", "")) if pb != null else ""
	var n_souls: int = CardDB.total_souls(p, game_manager.G)
	var n_wounds: int = CardDB.total_wounds(p)
	_icon_row(souls_container, 10, n_souls, TEX_SOUL, TEX_SOUL_EMPTY, Vector2(19, 26))
	_icon_row(wounds_container, 5, n_wounds, TEX_WOUND, TEX_WOUND_EMPTY, Vector2(21, 27))
	if not skip_animations: # APK : le cristal / la goutte gagnes s'allument
		_flash_icons(souls_container, _souls_seen, mini(n_souls, 10))
		_flash_icons(wounds_container, _wounds_seen, mini(n_wounds, 5))
	_souls_seen = n_souls
	_wounds_seen = n_wounds
	_fill_treasures(treasures_container, BossEngine.treasure_counts(p),
		[[3, Vector2(0, 0)], [4, Vector2(0, 54)], [2, Vector2(0, 101)], [1, Vector2(0, 153)], [5, Vector2(0, 200)]], 30.0)

	# Boss adverse
	var fb = foe.get("boss")
	foe_name_label.text = str(fb.get("name", "")).to_upper() if fb != null else ""
	_fit_label(foe_name_label, 150.0, 18)
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
			pawn.global_position = (slots_list[death_idx + vis_off] as Control).global_position + HERO_IN_SLOT
		else:
			pawn.global_position = entrance_ctrl.global_position
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
			var target_pos := target_slot.global_position + HERO_IN_SLOT

			tw.tween_callback(func(): _play_sfx("res://assets/audio/sfx/char_hero_move.wav"))
			tw.tween_property(pawn, "global_position", target_pos, 0.35 * _speed).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)

			tw.tween_callback(func():
				var sfx_path := "res://assets/audio/sfx/sfx_room_magic.wav" if is_magic else "res://assets/audio/sfx/sfx_room_physical.wav"
				_play_sfx(sfx_path)
				_set_focus(pid, slot_idx)
				_show_floating_dmg(pawn, dmg)
			)
			current_hp -= dmg
			tw.tween_interval(0.25 * _speed)

	if killed:
		tw.tween_callback(func():
			_set_focus(pid, -1) # APK JumpAndFade : la salle reprend sa taille pendant que le heros saute
			_play_sfx("res://assets/audio/sfx/char_hero_death.wav"))
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
		tw.tween_callback(func(): _set_focus(pid, -1))
		tw.tween_property(pawn, "global_position", boss_pos, 0.35 * _speed).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		tw.tween_callback(func():
			_play_sfx("res://assets/audio/sfx/char_hero_attack.wav")
			_shake_node(boss_sprite)
			boss_sprite.modulate = Color(1.8, 0.45, 0.45) # APK CreateBossHitAnimationTask : le boss touche rougeoie (calque additif) puis revient
			boss_sprite.create_tween().tween_property(boss_sprite, "modulate", Color.WHITE, 0.6)
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
		if not _focus.is_empty() and not _animating_hero:
			_set_focus(-1, -1) # plus de heros dans le donjon : la salle agrandie reprend sa taille
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
		return (L["entrance"] as Control).global_position
	var sl := _slot_at(pid, room)
	if sl != null:
		return sl.global_position + HERO_IN_SLOT
	return (L["platform"] as Control).global_position + Vector2(25, 25)

func _animate_step(hero: Dictionary, pid: int, from_room: int, to_room: int, hp_before: int, hp_after: int) -> void:
	_animating_hero = true
	if _hero_pawn == null or not is_instance_valid(_hero_pawn):
		_hero_pawn = _create_hero_pawn(hero, hp_before)
		_hero_pawn_hp = _hero_pawn.find_child("Hp", true, false)
		hero_crossing_layer.add_child(_hero_pawn)
		_hero_pawn.global_position = _step_target(pid, -1)
	var pawn := _hero_pawn
	var hp_lbl := _hero_pawn_hp
	var target := _step_target(pid, to_room)
	var dmg := hp_before - hp_after
	var lane_idx := 1 if pid == view_pid else 0
	var tw := create_tween()
	tw.tween_callback(func(): _play_sfx("res://assets/audio/sfx/char_hero_move.wav"))
	tw.tween_property(pawn, "global_position", target, 0.4 * _speed).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback(func():
		var room_ctrl: Control = _slot_at(pid, to_room) # les emplacements adverses sont reconstruits a chaque refresh : on ne garde pas de reference
		if dmg > 0 and room_ctrl != null:
			var dgn: Array = ((game_manager.G.get("players", {}) as Dictionary).get(pid, {}) as Dictionary).get("dungeon", [])
			var room_dict = BossEngine.active_room(dgn[to_room]) if to_room < dgn.size() else null
			var is_monster: bool = room_dict != null and str((room_dict as Dictionary).get("type", "")) == "monster"
			_play_sfx("res://assets/audio/sfx/sfx_room_magic.wav" if is_monster else "res://assets/audio/sfx/sfx_room_physical.wav")
			_show_floating_dmg(pawn, dmg)
			var badge: Label = (_lane[lane_idx] as Dictionary)["dmg"]
			badge.modulate = Color(1, 0.35, 0.3)
			badge.create_tween().tween_property(badge, "modulate", Color.WHITE, 0.5)
		_set_focus(pid, to_room) # APK : la salle ou entre le heros grossit
		if is_instance_valid(hp_lbl):
			hp_lbl.text = str(maxi(hp_after, 0)))
	tw.tween_interval(0.3 * _speed)
	tw.tween_callback(func():
		_animating_hero = false
		refresh())

## Personnage du heros (hero_characters de l'APK) : sa carte reste a l'entree du donjon, c'est ce personnage qui traverse les salles, avec
## au-dessus de lui un coeur rouge portant ses PV restants (HeroCardEntity.HeroCharacter + heroHeart). Le noeud fait la taille d'une carte
## de heros et se place comme elle (HERO_IN_SLOT : centre sur la salle) ; le personnage est un peu au-dessus du centre.
func _hero_sprite(hero: Dictionary) -> Texture2D:
	var t := _tex("res://assets/ui/characters/heroes/%s_character.webp" % str(hero.get("id", "")).to_lower())
	if t == null: # heros du wiki sans sprite APK : l'icone de sa classe
		t = _tex("res://assets/ui/icons/icon_%s.webp" % str({1: "cleric", 2: "fighter", 3: "mage", 4: "thief"}.get(int(hero.get("treasure", 0)), "")))
	return t

func _create_hero_pawn(hero: Dictionary, hp: int) -> Control:
	var ctrl := Control.new()
	ctrl.custom_minimum_size = HERO_CARD
	ctrl.size = HERO_CARD
	ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cy := HERO_CARD.y / 2.0 + HERO_SPRITE_DY
	var tex := _hero_sprite(hero)
	if tex != null:
		var sz := tex.get_size() * HERO_SPRITE_SCALE
		if tex.get_size().y > 100.0: # icone de classe (haute) : ramenee a la taille d'un personnage
			sz = tex.get_size() * (64.0 / tex.get_size().y)
		var spr := _img(ctrl, "", Vector2(HERO_CARD.x / 2.0 - sz.x / 2.0, cy - sz.y / 2.0), sz)
		spr.name = "Sprite"
		spr.texture = tex
	var heart := Control.new()
	heart.name = "HeroHeart"
	heart.mouse_filter = Control.MOUSE_FILTER_IGNORE
	heart.size = HERO_HEART
	heart.position = Vector2(HERO_CARD.x / 2.0 - HERO_HEART.x / 2.0, cy + HERO_HEART_DY - HERO_HEART.y / 2.0)
	ctrl.add_child(heart)
	_img(heart, UI_DIR + "health_hero_icon.webp", Vector2.ZERO, HERO_HEART)
	var hp_lbl := _lbl(heart, str(hp), 24, Color.WHITE, Vector2(0, 11), HERO_HEART.x, _fa, HORIZONTAL_ALIGNMENT_CENTER)
	hp_lbl.name = "Hp"
	ctrl.set_meta("heart_anchor", heart) # _show_floating_dmg : le « -N » part du coeur
	return ctrl

## Salle ou se trouve le heros : elle grossit (APK : CreateScaleInTopRoomTask / ScaleOut), les autres reprennent leur taille.
## Les emplacements adverses sont reconstruits a chaque refresh : refresh() rappelle _apply_focus.
func _set_focus(pid: int, room: int) -> void:
	_focus = {"pid": pid, "room": room} if room >= 0 else {}
	_apply_focus(true)

func _apply_focus(animate := false) -> void:
	for pid in [view_pid, foe_pid]:
		var want: int = int(_focus.get("room", -1)) if not _focus.is_empty() and int(_focus["pid"]) == int(pid) else -1
		var target: Control = _slot_at(int(pid), want) if want >= 0 else null
		for sl in _lane_slots(int(pid)):
			if not is_instance_valid(sl):
				continue
			var c := sl as Control
			var big := c == target
			var sc := Vector2.ONE * (ROOM_FOCUS_SCALE if big else 1.0)
			c.pivot_offset = c.size / 2.0
			c.z_index = 4 if big else 0
			if c.scale.is_equal_approx(sc):
				continue
			if c.has_meta("focus_tw"):
				(c.get_meta("focus_tw") as Tween).kill()
			if animate and not skip_animations:
				var tw := c.create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
				tw.tween_property(c, "scale", sc, 0.3)
				c.set_meta("focus_tw", tw)
			else:
				c.scale = sc

## HeartDecrementEmitter de l'APK : un coeur « -N » part de la salle / du boss, monte de 140 px en 1,3 s et s'estompe sur la fin (coeur vide health_hero_trans_icon).
func _show_floating_dmg(parent: Control, dmg: int, color := Color(1.0, 1.0, 1.0)) -> void:
	var heart := Control.new()
	heart.name = "HeartFx"
	heart.mouse_filter = Control.MOUSE_FILTER_IGNORE
	heart.size = Vector2(70, 62)
	UiKit.image(heart, UI_DIR + "health_hero_trans_icon.webp", Vector2.ZERO, Vector2(70, 62)).modulate = color
	UiKit.label(heart, "-%d" % dmg, 24, color, Vector2(0, 17), 70.0, UiKit.FONT_A, HORIZONTAL_ALIGNMENT_CENTER)
	_ui_layer.add_child(heart)
	if parent.has_meta("heart_anchor"): # le coeur de PV du heros : le « -N » en part
		var anchor := parent.get_meta("heart_anchor") as Control
		heart.global_position = anchor.global_position + anchor.size / 2.0 - Vector2(35.0, 31.0)
	else:
		heart.global_position = parent.global_position + Vector2(parent.size.x / 2.0 - 35.0, -20.0)
	var tw := heart.create_tween().set_parallel(true)
	tw.tween_property(heart, "position:y", heart.position.y - 140.0, 1.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(heart, "modulate:a", 0.0, 0.26).set_delay(1.04)
	tw.chain().tween_callback(heart.queue_free)

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

## Emplacements dont la salle du dessus est une pose en attente : un clic la reprend (BoardUI._on_slot_activate).
func _refresh_undoable(my_moves: Array) -> void:
	var und: Dictionary = {}
	for m in _moves_of(my_moves, "undoBuild"):
		und[int(((m as Dictionary)["args"] as Array)[0])] = true
	for slot in _dungeon_slots:
		var sl: DungeonSlot = slot
		sl.set_undoable(und.has(sl.slot_index) and not sl.current_stack.is_empty())

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

## Liste de boutons pierre pour les choix qui ne sont PAS des cartes (oui / non, joueur, variante...) : bulle (top_globe) avec le titre,
## puis une pile de boutons. L'APK n'a pas de liste : un choix de cartes passe par le carrousel central (_popup_cards).
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

## Carrousel central de cartes (APK CarouselSelectorEntity + CardSelectorComponent, comme « SELECT 2 CARDS TO DISCARD ») : voile, bulle de
## titre (top_globe), cartes a l'echelle 0,7 dont la touchee passe a 1,2 avec un halo dore (retoucher = deselectionner) ; CONTINUE joue
## la carte choisie. `skip_cb` valide = le choix peut etre refuse (canBeCanceled) : le bouton est alors present meme sans carte (SKIP) ;
## sinon il n'apparait qu'une fois une carte choisie (IsContinueButtonVisible). items : [{card: Dictionary, cb: Callable}].
func _popup_cards(kind: String, title: String, items: Array, skip_cb: Callable = Callable()) -> void:
	var pop := _popup_begin(kind, 0.6)
	_img(pop, UI_DIR + "top_globe.webp", Vector2(PLAY_CX - 465, 150))
	var tl := _lbl(pop, title.to_upper(), 26 if title.length() <= 44 else 21, Color.WHITE, Vector2(PLAY_CX - 430, 150 + 14), 860.0, _fa, HORIZONTAL_ALIGNMENT_CENTER)
	tl.custom_minimum_size.y = 110.0
	tl.size.y = 110.0
	tl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var n := items.size()
	var cw := 245.0 if n <= 5 else maxf(125.0, 1400.0 / float(n) - 10.0) # 350 x 0,7 ; plus petites (et chevauchees) au-dela de 5 cartes
	var sz := Vector2(cw, cw * 488.0 / 350.0)
	var step := 0.0 if n < 2 else minf(cw + 25.0, (1400.0 - cw) / float(n - 1))
	var x0 := PLAY_CX - (step * float(n - 1) + cw) / 2.0
	var st := {"sel": -1}
	var cards: Array = []
	var btn := Button.new()
	btn.name = "CardsContinue"
	btn.custom_minimum_size = Vector2(220, 54)
	btn.size = Vector2(220, 54)
	btn.position = Vector2(PLAY_CX - 110, 905)
	btn.add_theme_font_size_override("font_size", 24)
	var update := func():
		for k in cards.size():
			var on: bool = k == int(st["sel"])
			var cu: CardUI = cards[k]
			cu.scale = Vector2.ONE * (1.2 / 0.7 if on else 1.0)
			cu.z_index = 10 if on else 0
			cu.modulate = Color(1.3, 1.3, 0.55) if on else Color.WHITE
			if cu.glow_rect != null:
				cu.glow_rect.visible = on
		btn.visible = int(st["sel"]) >= 0 or skip_cb.is_valid()
		btn.text = "CONTINUE" if int(st["sel"]) >= 0 else "SKIP"
	for i in n:
		var cu: CardUI = _card_scene.instantiate()
		cu.default_size = sz
		pop.add_child(cu)
		cu.size = sz
		cu.setup(items[i]["card"])
		cu.position = Vector2(x0 + step * float(i), 560.0 - sz.y / 2.0)
		cu.mouse_entered.disconnect(cu._on_mouse_entered) # pas de grossissement au survol : l'echelle dit « choisie »
		cu.mouse_exited.disconnect(cu._on_mouse_exited)
		var idx := i
		cu.card_clicked.connect(func(_d):
			_play_sfx("res://assets/audio/sfx/ui_button_select.wav")
			st["sel"] = -1 if int(st["sel"]) == idx else idx
			update.call())
		cards.append(cu)
	btn.pressed.connect(func():
		_play_sfx("res://assets/audio/sfx/ui_button_select.wav")
		if int(st["sel"]) >= 0:
			((items[int(st["sel"])] as Dictionary)["cb"] as Callable).call()
		elif skip_cb.is_valid():
			skip_cb.call())
	pop.add_child(btn)
	update.call()

## Carte d'une entree de choix (propre a l'entree, ou portee par la cible du coup : sort sur une carte, ame, pile...) ; {} si aucune.
func _entry_card(e: Dictionary) -> Dictionary:
	var c = e.get("card")
	if c is Dictionary and not (c as Dictionary).is_empty():
		return c
	var a: Array = (e.get("mv", {}) as Dictionary).get("args", [])
	if a.size() > 1 and a[1] is Dictionary:
		var tc = (a[1] as Dictionary).get("card")
		if tc is Dictionary and not (tc as Dictionary).is_empty():
			return tc
	return {}

# ---------------------------------------------------------------------------------------------------------------------
# Ciblage sur le plateau (APK) : voile leger, bulle de titre, cibles legales en surbrillance doree et cliquables, CANCEL.
# Si une cible n'a pas de representation sur le plateau (ames, defausse, pile...) : carrousel de cartes (_popup_cards) quand chaque
# entree porte une carte, liste de boutons (_popup_list) sinon.
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
		var items: Array = []
		for e in entries:
			var ec := _entry_card(e)
			if ec.is_empty():
				items = []
				break
			items.append({"card": ec, "cb": (e as Dictionary)["cb"]})
		if items.is_empty():
			_popup_list("target", title, entries, cancel_cb)
		else:
			_popup_cards("target", title, items, cancel_cb)
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
	dim.gui_input.connect(_target_dim_input)
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

## Les zones sont reposees apres chaque rafraichissement : un appui qui arrive pendant ce remplacement tombe sur le voile et serait perdu
## (il fallait cliquer 2 fois). Le voile rejoue alors la zone qui contient le point.
func _target_dim_input(ev: InputEvent) -> void:
	if not (ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT):
		return
	for s in _tgt_spots:
		var ctrl = s["ctrl"]
		if is_instance_valid(ctrl) and (ctrl as Control).get_global_rect().has_point((ev as InputEventMouseButton).global_position):
			_target_pick(s["ids"])
			return

func _target_cancel() -> void:
	_play_sfx("res://assets/audio/sfx/ui_button_goback.wav")
	var skip: Callable = _tgt.get("choice", Callable())
	_target_end()
	if skip.is_valid():
		skip.call() # choix en attente : CANCEL joue le SKIP (le coup rafraichit)
		return
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
		"free": # prochain emplacement libre du donjon (a l'entree, a gauche des salles posees)
			var fpid := int(spot["pid"])
			if _spot_lane(fpid) < 0:
				return null
			var fdun: Array = ((G["players"] as Dictionary)[fpid] as Dictionary).get("dungeon", [])
			var fslots: Array = _lane_slots(fpid)
			var fi: int = maxi(0, CardDB.DUNGEON_SLOTS - fdun.size()) - 1
			return fslots[fi] if fdun.size() < CardDB.DUNGEON_SLOTS and fi >= 0 and fi < fslots.size() and is_instance_valid(fslots[fi]) else null
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
		if _tgt.has("choice"):
			_target_end() # choix sur le plateau resolu ailleurs
		if _popup_kind == "choice":
			_popup_close() # carrousel central + bouton CONTINUE pour la defausse d'ouverture (_refresh_overlay)
		return
	var sig := JSON.stringify([pc.get("type"), pc.get("message"), cmoves])
	if _tgt.has("choice") and str(_tgt.get("sig", "")) != sig:
		_target_end() # un autre choix a pris la place de celui que le ciblage montrait : ses zones sont caduques
	if _popup_kind in ["menu", "quit", "target"] or not _tgt.is_empty():
		return # un menu ouvert par le joueur reste devant ; le choix reapparait a la fermeture (refresh)
	if _popup_kind == "choice" and sig == _choice_sig:
		return
	if _lvl_busy:
		return # banniere LEVEL UP en cours : le choix suivra (refresh a sa fin)
	var opts: Array = pc.get("options", [])
	var entries: Array = []
	var board: Array = [] # options hors SKIP, avec leur zone du plateau
	var items: Array = [] # options hors SKIP, avec leur carte (carrousel)
	var all_cards := true
	var skip := Callable()
	for m in cmoves:
		var mv: Dictionary = (m as Dictionary).duplicate()
		var i := int((mv.get("args", [0]) as Array)[0])
		var e := {"label": _option_label(opts, i), "mv": mv, "cb": func(): _do(mv)} # mv : _target_sync ferme le ciblage des que le coup n'est plus legal
		entries.append(e)
		if i < 0:
			skip = e["cb"]
			continue
		if i < opts.size() and opts[i] is Dictionary:
			e["spot"] = _spot_of_target(opts[i], _my_pid())
			board.append(e)
			var oc = (opts[i] as Dictionary).get("card")
			if oc is Dictionary and not (oc as Dictionary).is_empty():
				items.append({"card": oc, "cb": e["cb"]})
			else:
				all_cards = false
		else:
			board.append({"spot": {}})
			all_cards = false
	var title := str(pc.get("message", "")) if str(pc.get("message", "")) != "" else "CHOOSE"
	# APK (RearrangeSelector/CardSelector) : si chaque option est une zone du plateau, on la designe dessus, SKIP = CANCEL
	var on_board := not board.is_empty()
	for e in board:
		on_board = on_board and not (e["spot"] as Dictionary).is_empty()
	if on_board:
		_target_list(title, title, board, skip)
	elif all_cards and not items.is_empty(): # APK : CardSelector dans le carrousel central, SKIP = canBeCanceled
		_popup_cards("choice", title, items, skip)
	else:
		_popup_list("choice", title, entries) # pas des cartes (oui / non, joueur...) : boutons pierre
	if not _tgt.is_empty():
		_tgt["choice"] = skip
		_tgt["sig"] = sig
		_tgt_cancel_btn.visible = skip.is_valid() # choix obligatoire : pas de CANCEL
		return
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
		var pid := int(o.get("targetPlayerId", _my_pid()))
		var pl: Dictionary = (game_manager.G.get("players", {}) as Dictionary).get(pid, {})
		var dun: Array = pl.get("dungeon", [])
		if o.has("roomIndex") and int(o["roomIndex"]) < dun.size() and int(o["roomIndex"]) >= 0:
			var r = BossEngine.active_room(dun[int(o["roomIndex"])])
			if r != null and str((r as Dictionary).get("name", "")) != "":
				return "%s (P%d)" % [str((r as Dictionary)["name"]), pid + 1]
		if o.has("targetPlayerId"):
			return "Player %d" % (int(o["targetPlayerId"]) + 1)
	return "Choice %d" % (i + 1)

## Coups propres aux extensions du wiki (Minibosses, TNL...) : aucun equivalent APK. Les coups d'une carte de la main (DISCARD: +1 COIN,
## capacites de main, poser un miniboss...) sont dans le menu de la carte (clic, voir _build_over_menu / _play_hand_menu) ; les sorts
## (clic sur la carte) et les capacites de salle (clic sur la salle) n'ont pas de bouton. Les autres (boss, paiement, miniboss en place)
## tiennent derriere UN seul bouton « EXTRA MOVES » sous PASS TURN : aucune grille de boutons sur le donjon.
func _refresh_extra_bar(G: Dictionary, my_moves: Array) -> void:
	for c in extra_bar.get_children():
		c.queue_free()
	if not (G.get("pendingChoice", {}) as Dictionary).is_empty():
		extra_bar.visible = false
		return
	var entries: Array = []
	var hand: Array = ((G.get("players", {}) as Dictionary).get(_my_pid(), {}) as Dictionary).get("hand", [])
	for m in my_moves:
		if not (m is Dictionary) or str((m as Dictionary).get("type", "")) in CORE_MOVE_TYPES + HAND_CLICK_TYPES + ["activateRoom"] or hand_idx_of(m) >= 0:
			continue
		var mv := (m as Dictionary).duplicate()
		entries.append({"label": _move_label(mv, G, hand), "cb": func(): _do(mv)})
	if not entries.is_empty():
		var b := Button.new()
		b.text = "EXTRA MOVES (%d)" % entries.size()
		b.custom_minimum_size = Vector2(300, 62)
		b.add_theme_font_size_override("font_size", 22)
		b.pressed.connect(func():
			_play_sfx("res://assets/audio/sfx/ui_button_select.wav")
			_popup_list("target", "EXTRA MOVES", entries, func(): _popup_close()))
		extra_bar.add_child(b)
	extra_bar.visible = not entries.is_empty()

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
		# Autres coups de cette salle en main (CRL007 Frostman Lander, DISCARD: +1 COIN des Minibosses...) : proposes avec les emplacements.
		var uses := _hand_moves(idx)
		# Plusieurs emplacements possibles (Boss.CanBuildRoom : n'importe quelle salle visible peut etre recouverte, meme hors donjon plein) :
		# on demande lequel, l'emplacement libre compris ; un seul (fin de donjon) = pose directe.
		var plain := {}
		var over: Array = []
		var builds: Array = _moves_of(game_manager.legal_moves(_my_pid()), "buildRoom").filter(func(m): return int(((m as Dictionary).get("args", [-1]) as Array)[0]) == idx)
		if builds.is_empty() and uses.is_empty() and not bool(card.get("isMiniboss", false)): # limite de poses atteinte : la pose en attente est reprise, puis cette salle se pose (APK CheckMaxBuildRooms)
			var undo: Dictionary = game_manager.pending_undo(_my_pid())
			if not undo.is_empty():
				_swap_idx = idx
				_swap_until = Time.get_ticks_msec() + 3000
				_play_sfx("res://assets/audio/sfx/sfx_room_physical.wav")
				_do(undo) # en ligne la reprise n'est confirmee que par l'etat suivant : _swap_resume rejoue le clic alors
				return
		for m in _moves_of(game_manager.legal_moves(_my_pid()), "buildRoom"):
			var a: Array = (m as Dictionary).get("args", [])
			if a.is_empty() or int(a[0]) != idx:
				continue
			if a.size() > 1 and a[1] != null:
				over.append(m)
			else:
				plain = m
		if not over.is_empty() or not uses.is_empty():
			_build_over_menu(card, over, plain, uses)
			return
		_play_sfx("res://assets/audio/sfx/sfx_room_physical.wav")
		if game_manager.build_room_at(_my_pid(), idx, target_slot):
			refresh() # apply_move n'emet pas toujours state_changed en fin de coup (transition de phase)
	else:
		_play_from_hand(idx)

## Suite d'un clic sur une salle qui remplace la pose en attente : une fois la reprise visible dans l'etat, la salle se pose normalement.
func _swap_resume() -> void:
	if _swap_idx < 0:
		return
	var idx := _swap_idx
	if Time.get_ticks_msec() > _swap_until:
		_swap_idx = -1
		return
	if not game_manager.pending_undo(_my_pid()).is_empty():
		return # pas encore confirmee (serveur)
	_swap_idx = -1
	var hand := _my_hand()
	if idx < hand.size():
		_on_hand_card_clicked(idx, hand[idx])

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
	_play_hand_menu(hand[idx], cands)

## Fenetre « construire par-dessus » : une entree par salle recouvrable (equivalent du glisser-deposer sur l'emplacement).
## `plain` : le coup « emplacement libre » (fin de donjon) quand il est legal, propose en premier. `uses` : autres coups de la carte
## (capacite de main, DISCARD: +1 COIN...), ajoutes en fin de liste ; l'entree unique est jouee directement.
func _build_over_menu(card: Dictionary, over: Array, plain: Dictionary = {}, uses: Array = []) -> void:
	var dungeon: Array = ((game_manager.G.get("players", {}) as Dictionary).get(_my_pid(), {}) as Dictionary).get("dungeon", [])
	var entries: Array = []
	var on_board := uses.is_empty() # avec d'autres coups, une liste : les entrees sans zone du plateau ne s'allument pas
	if not plain.is_empty():
		var pmv: Dictionary = plain.duplicate()
		entries.append({"label": "NEW ROOM (FREE SLOT)", "mv": pmv, "spot": {"k": "free", "pid": _my_pid()} if on_board else {}, "cb": func():
			_play_sfx("res://assets/audio/sfx/sfx_room_physical.wav")
			_do(pmv)})
	for c in over:
		var mv: Dictionary = (c as Dictionary).duplicate()
		var ti := int((mv["args"] as Array)[1])
		var host = BossEngine.active_room(dungeon[ti]) if ti >= 0 and ti < dungeon.size() else null
		entries.append({"label": "ON %s" % (str((host as Dictionary).get("name", "Room %d" % (ti + 1))) if host != null else "Room %d" % (ti + 1)), "mv": mv,
			"spot": {"k": "room", "pid": _my_pid(), "idx": ti} if on_board else {}, "cb": func():
			_play_sfx("res://assets/audio/sfx/sfx_room_physical.wav")
			_do(mv)})
	for u in uses:
		entries.append(_hand_entry(card, u))
	if entries.is_empty():
		return
	if entries.size() == 1: # un seul coup possible : on le joue directement
		(entries[0]["cb"] as Callable).call()
		return
	_target_list("%s - build over a Room" % str(card.get("name", "")) if on_board else str(card.get("name", "")),
		("Select a Room to build over" if plain.is_empty() else "Select a Room to build over, or the free slot") if on_board else "Build, or choose an action", entries, func(): _popup_close())

## Indice de la carte de la main a laquelle un coup est attache (construire, sort, capacites de main des extensions, defausse contre
## 1 piece...), -1 si le coup n'est lie a aucune carte de la main (boss, salle, paiement) : ceux-la vont dans le bouton EXTRA MOVES.
static func hand_idx_of(m: Dictionary) -> int:
	var a: Array = m.get("args", [])
	match str(m.get("type", "")):
		"playSpell", "useHandRoom", "buildRoom", "buildMiniboss", "discardForCoin", "rmbHand", "payDarkHero", "docScarecrow", "timebenderCancel", "antimagicCancel":
			return int(a[0]) if not a.is_empty() and a[0] is int else -1
		"rmbCancel", "promoteMiniboss": # [salle, carte] ; promotion contre une carte (alt >= 0) ou 1 piece (-1)
			return int(a[1]) if a.size() > 1 and a[1] is int else -1
	return -1

## Coups legaux autres que construire (sort, capacite de main, defausse contre 1 piece...) de la carte `idx` de la main.
func _hand_moves(idx: int) -> Array:
	var cands: Array = []
	for mv in game_manager.legal_moves(_my_pid()):
		var m: Dictionary = mv
		if str(m.get("type", "")) != "buildRoom" and hand_idx_of(m) == idx:
			cands.append(m)
	return cands

## Entree de menu d'un coup de la main : sort / capacite ciblee (zone du plateau si elle en a une) ou coup d'extension (libelle de _move_label).
func _hand_entry(card: Dictionary, c: Dictionary) -> Dictionary:
	var mv: Dictionary = c.duplicate()
	var margs: Array = mv.get("args", [])
	var is_spell: bool = str(mv.get("type", "")) in HAND_CLICK_TYPES
	return {"label": _target_label(mv, card) if is_spell else _move_label(mv, game_manager.G, _my_hand()), "mv": mv,
		"spot": _spot_of_target(margs[1] as Dictionary, _my_pid()) if is_spell and margs.size() > 1 and margs[1] is Dictionary else {}, "cb": func():
		_play_sfx("res://assets/audio/sfx/sfx_room_magic.wav")
		_do(mv)}

## Fenetre de ciblage (une entree par coup) d'une carte de la main.
func _play_hand_menu(card: Dictionary, cands: Array) -> void:
	var entries: Array = []
	for c in cands:
		entries.append(_hand_entry(card, c))
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
	for m in _moves_of(game_manager.legal_moves(_my_pid()), "undoBuild"): # clic sur la pose en attente : elle revient en main
		if int(((m as Dictionary)["args"] as Array)[0]) == di:
			_play_sfx("res://assets/audio/sfx/sfx_room_physical.wav")
			_do(m)
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
	if _warn == null and _can_still_build(game_manager.legal_moves(_my_pid())):
		_warn_show() # APK : « HEY! YOU CAN BUILD A ROOM! STILL WANT TO PASS? », un 2e appui confirme
		return
	_warn_hide()
	if _is_online():
		_do({"type": "pass", "args": []})
	else:
		if game_manager.apply_move(_my_pid(), {"type": "passBuild", "args": []}):
			refresh()

# ---------------------------------------------------------------------------------------------------------------------
# Interactions de l'APK : glisser-deposer, zoom d'appui long, pile de sorts, notices de l'adversaire, pioche, mise en garde, fin de partie
# ---------------------------------------------------------------------------------------------------------------------

func _can_drag() -> bool:
	var G: Dictionary = game_manager.G
	return G.get("gameOver") == null and not _carousel_active(G, str(G.get("phase", ""))) and str(G.get("phase", "")) in ["build", "setup", "adventure"] \
		and _tgt.is_empty() and not _modal_open() and (_popup == null or not is_instance_valid(_popup))

func _on_hand_press(card: Control, at: Vector2) -> void:
	_press = {"card": card, "idx": (card as CardUI).hand_index, "pos": at}

## Relachement jamais livre (pointeur sorti du canvas / fenetre perdue) : on abandonne l'appui pour que la main puisse se rafraichir.
func _notification(what: int) -> void:
	if what in [NOTIFICATION_WM_MOUSE_EXIT, NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_WINDOW_FOCUS_OUT] and _drag.is_empty() and not _press.is_empty():
		_press_clear()

func _press_recheck() -> void:
	if _press.is_empty() and _hand_stale:
		_press_clear()

## Fin de l'appui : la main saute-t-elle un rafraichissement, on le rejoue apres le traitement du relachement (le clic de la carte passe d'abord).
func _press_clear() -> void:
	_press = {}
	if _hand_stale:
		_hand_stale = false
		refresh.call_deferred()

## Glisser une carte de la main (appui + deplacement > 12 px) : carte zoomee (cadre noir) accrochee au curseur ; salle = l'emplacement
## accepte s'allume en dore, sort = les cibles du plateau s'allument en dore ; relacher sur une cible joue le coup (voir _drag_end).
func _drag_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var m := event as InputEventMouseMotion
		if _drag.is_empty():
			if not (m.button_mask & MOUSE_BUTTON_MASK_LEFT) or _press.is_empty():
				_press_clear()
				return
			if m.global_position.distance_to(_press["pos"]) >= DRAG_SLOP and _can_drag():
				_drag_begin()
		if not _drag.is_empty():
			_drag_move(m.global_position)
	elif event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT and not (event as InputEventMouseButton).pressed:
		if not _drag.is_empty():
			_press = {} # _drag_end rafraichit : la main doit etre reconstruite tout de suite
			_drag_end((event as InputEventMouseButton).global_position)
		_press_clear()

func _my_hand() -> Array:
	return ((game_manager.G.get("players", {}) as Dictionary).get(_my_pid(), {}) as Dictionary).get("hand", [])

func _drag_begin() -> void:
	var idx: int = int(_press["idx"])
	var hand := _my_hand()
	var ci = _press["card"]
	if idx < 0 or idx >= hand.size():
		_press_clear()
		return
	if is_instance_valid(ci):
		(ci as CardUI).suppress_click = true
	_zoom_hide()
	var greyed: bool = is_instance_valid(ci) and (ci as CardUI).texture_rect != null and (ci as CardUI).texture_rect.material != null
	# APK (CardExtractBehavior.ExtractCard) : la carte tiree reprend l'echelle de la main (ToScale = NormalScale, rotation 0), cadre noir fin ;
	# la grande apercu 350 x 490 est le zoom d'appui long, pas le glisser.
	var prev := UiKit.zoom_card(hand[idx], HAND_CARD, greyed, 4.0)
	prev.modulate = Color(1, 1, 1, 0.96)
	_ui_layer.add_child(prev)
	_drag = {"idx": idx, "preview": prev, "frames": []}
	_drag_move(_press["pos"])
	_drag_refresh()

func _drag_move(pos: Vector2) -> void:
	var prev: Control = _drag["preview"]
	prev.position = Vector2(clampf(pos.x - prev.size.x / 2.0, 0.0, 1920.0 - prev.size.x), clampf(pos.y - prev.size.y * 0.62, 0.0, 1080.0 - prev.size.y))

## (Re)allume les cibles du glisser : emplacements de salle acceptes (le prochain emplacement libre + les salles recouvrables) ou
## zones du plateau des cibles d'un sort. Appele au debut du glisser et apres chaque rafraichissement (les noeuds changent).
func _drag_refresh() -> void:
	for f in (_drag["frames"] as Array):
		if is_instance_valid(f):
			(f as Node).queue_free()
	_drag["frames"] = []
	var idx: int = int(_drag["idx"])
	var hand := _my_hand()
	if idx >= hand.size():
		_drag_clear()
		return
	var cards := hand_layer.get_children().filter(func(c): return not c.is_queued_for_deletion())
	if idx < cards.size():
		(cards[idx] as Control).modulate.a = 0.3 # la carte quitte la main
	var seen := {}
	if bool((hand[idx] as Dictionary).get("isRoom", false)):
		var dungeon: Array = ((game_manager.G["players"] as Dictionary)[_my_pid()] as Dictionary).get("dungeon", [])
		var off: int = maxi(0, CardDB.DUNGEON_SLOTS - dungeon.size())
		var advanced := bool((hand[idx] as Dictionary).get("advanced", false))
		for j in _dungeon_slots.size():
			var slot: DungeonSlot = _dungeon_slots[j]
			var filled := not slot.current_stack.is_empty()
			# salle avancee : les salles recouvrables ; ordinaire : les salles recouvrables (DungeonSlot.CheckRoomCanBeBuilt, meme donjon
			# non plein) et le prochain emplacement libre ; _can_drop_data ne garde que ceux que le moteur accepte
			var wanted: bool = filled or (not advanced and dungeon.size() < CardDB.DUNGEON_SLOTS and j == off - 1)
			if wanted and slot._can_drop_data(Vector2.ZERO, {"type": "card", "hand_index": idx}):
				(_drag["frames"] as Array).append(_gold_frame(Rect2(slot.global_position, slot.size)))
		return
	for c in _hand_moves(idx):
		var margs: Array = (c as Dictionary).get("args", [])
		var spot: Dictionary = _spot_of_target(margs[1] as Dictionary, _my_pid()) if margs.size() > 1 and margs[1] is Dictionary else {}
		if spot.is_empty():
			continue
		var node := _spot_node(spot)
		if node != null and not seen.has(node.get_instance_id()):
			seen[node.get_instance_id()] = true
			(_drag["frames"] as Array).append(_gold_frame(_spot_rect(spot, node)))

## Cadre dore de cible (APK : bordure doree sur la salle / le heros que le sort peut viser) ; ne bloque pas la souris.
func _gold_frame(r: Rect2, red := false) -> Control:
	var f := Control.new()
	f.mouse_filter = Control.MOUSE_FILTER_IGNORE
	f.position = r.position - Vector2(8, 8)
	f.size = r.size + Vector2(16, 16)
	var glow := TextureRect.new()
	glow.texture = _tex(TEX_TARGET_GLOW if not red else UI_DIR + "card_border_red.webp")
	glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glow.stretch_mode = TextureRect.STRETCH_SCALE
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow.set_anchors_preset(Control.PRESET_FULL_RECT)
	f.add_child(glow)
	f.draw.connect(func(): f.draw_rect(Rect2(Vector2(7, 7), f.size - Vector2(14, 14)), Color(0.9, 0.2, 0.2) if red else GOLD, false, 3.0))
	f.name = "RedFrame" if red else "GoldFrame"
	_ui_layer.add_child(f)
	if not red: # cibles possibles : cadre dore qui pulse ; cibles touchees par la carte jouee (BorderStyles.Red) : cadre rouge fixe
		var tw := f.create_tween().set_loops()
		tw.tween_property(f, "modulate:a", 0.55, 0.5).set_trans(Tween.TRANS_SINE)
		tw.tween_property(f, "modulate:a", 1.0, 0.5).set_trans(Tween.TRANS_SINE)
	return f

func _drag_clear() -> void:
	if _drag.is_empty():
		return
	for f in (_drag["frames"] as Array):
		if is_instance_valid(f):
			(f as Node).queue_free()
	if is_instance_valid(_drag["preview"]):
		(_drag["preview"] as Node).queue_free()
	_drag = {}

## Relachement : salle -> l'emplacement sous le curseur (DungeonSlot._drop_data) ; sort -> la cible sous le curseur (_spell_drop).
func _drag_end(pos: Vector2) -> void:
	var idx: int = int(_drag["idx"])
	var hand := _my_hand()
	var is_room: bool = idx < hand.size() and bool((hand[idx] as Dictionary).get("isRoom", false))
	_drag_clear()
	if idx < hand.size() and pos.y < 940.0: # relacher sur la main = annuler
		if is_room:
			var data := {"type": "card", "hand_index": idx}
			for slot in _dungeon_slots:
				if Rect2((slot as Control).global_position, (slot as Control).size).has_point(pos):
					if (slot as DungeonSlot)._can_drop_data(Vector2.ZERO, data):
						(slot as DungeonSlot)._drop_data(Vector2.ZERO, data)
					break
		else:
			_spell_drop(idx, pos)
	refresh() # remet la main en place (carte revenue) quoi qu'il arrive

## Sort lache a `pos` : un seul coup (sort sans cible) = joue n'importe ou sur le plateau ; sinon la cible sous le curseur ;
## plusieurs coups sur la meme cible = petite liste ; cibles sans representation (ames, pile...) = la liste centrale.
func _spell_drop(idx: int, pos: Vector2) -> void:
	var cands := _hand_moves(idx)
	if cands.is_empty():
		return
	var inside := Rect2(184, 62, 1523, 890).has_point(pos)
	var hits: Array = []
	var unspotted := 0
	for c in cands:
		var margs: Array = (c as Dictionary).get("args", [])
		var spot: Dictionary = _spot_of_target(margs[1] as Dictionary, _my_pid()) if margs.size() > 1 and margs[1] is Dictionary else {}
		if spot.is_empty():
			unspotted += 1
			continue
		var node := _spot_node(spot)
		if node != null and _spot_rect(spot, node).has_point(pos):
			hits.append(c)
	if cands.size() == 1 and inside:
		_play_sfx("res://assets/audio/sfx/sfx_room_magic.wav")
		_do(cands[0])
	elif hits.size() == 1:
		_play_sfx("res://assets/audio/sfx/sfx_room_magic.wav")
		_do(hits[0])
	elif hits.size() > 1:
		var card: Dictionary = _my_hand()[idx]
		var entries: Array = []
		for h in hits:
			var mv: Dictionary = (h as Dictionary).duplicate()
			entries.append({"label": _target_label(mv, card), "cb": func(): _do(mv)})
		_popup_list("target", str(card.get("name", "")), entries, func(): _popup_close())
	elif unspotted > 0 and inside:
		_play_from_hand(idx)

## Zoom d'appui long (ou clic droit maintenu) : la carte en grand dans son cadre noir au-dessus de la main, le reste de la main s'assombrit.
func _zoom_show(card: Control) -> void:
	var ci := card as CardUI
	if ci == null or ci.card_dict.is_empty() or bool(ci.card_dict.get("faceDown", false)):
		return # une salle adverse face cachee ne se devoile pas
	_zoom_hide()
	var greyed: bool = ci.texture_rect != null and ci.texture_rect.material != null
	_zoom = UiKit.zoom_card(ci.card_dict, UiKit.ZOOM_CARD, greyed)
	_zoom.position = Vector2(clampf(ci.get_global_rect().get_center().x - _zoom.size.x / 2.0, 190.0, 1707.0 - _zoom.size.x), 295.0) # APK : cadre noir de 350 x 490 dont le haut est a y ~295
	_ui_layer.add_child(_zoom)
	hand_layer.modulate = Color(0.6, 0.6, 0.6)

func _zoom_hide() -> void:
	if _zoom != null and is_instance_valid(_zoom):
		for f in (_zoom.get_meta("frames", []) as Array):
			if is_instance_valid(f):
				(f as Node).queue_free()
		_zoom.queue_free()
	_zoom = null
	if hand_layer != null:
		hand_layer.modulate = Color.WHITE

## Pile de sorts (Spell Battle) : les sorts en attente au centre de l'ecran, dans leur cadre noir (la barre de temps est au-dessus).
func _refresh_stack_cards(G: Dictionary) -> void:
	var stack: Array = G.get("stack", [])
	var sig := ""
	for e in stack:
		sig += str((e as Dictionary).get("id", "")) + ","
	if sig == _stack_sig:
		return
	_stack_sig = sig
	if _stack_ui != null and is_instance_valid(_stack_ui):
		_ui_layer.remove_child(_stack_ui)
		_stack_ui.queue_free()
	_stack_ui = null
	if stack.is_empty():
		return
	_stack_ui = Control.new()
	_stack_ui.name = "StackCards"
	_stack_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stack_ui.size = Vector2(1920, 1080)
	_ui_layer.add_child(_stack_ui)
	var n := stack.size()
	var csz := UiKit.ZOOM_CARD * (1.0 if n <= 2 else 0.72)
	for i in n:
		var card: Dictionary = ((stack[i] as Dictionary).get("card", {}) as Dictionary)
		if card.is_empty():
			continue
		var z := UiKit.zoom_card(card, csz)
		var cx := STACK_CX + (float(i) - float(n - 1) / 2.0) * (z.size.x + 16.0)
		z.position = Vector2(cx - z.size.x / 2.0, 498.0 - z.size.y / 2.0)
		if bool((stack[i] as Dictionary).get("canceled", false)):
			z.modulate = Color(0.5, 0.5, 0.5)
		_stack_ui.add_child(z)
		var owner_pid := int((stack[i] as Dictionary).get("playerId", -1))
		if owner_pid != _my_pid(): # APK : sort / capacite de l'adversaire = son portrait rond (BossOwnerIcon) a cheval sur le haut de la carte
			z.add_child(_owner_badge(owner_pid, z.size.x / 2.0))

## Portrait rond du boss (avatar de profil, cercle rouge) ; centre en (cx, 0) du parent.
func _owner_badge(pid: int, cx: float) -> Control:
	var boss = ((game_manager.G.get("players", {}) as Dictionary).get(pid, {}) as Dictionary).get("boss")
	var nm := str((boss as Dictionary).get("name", "")).to_lower() if boss != null else ""
	var tex: Texture2D = null
	for k in ["anererak", "cerebellus", "cleopatra", "croak", "draculord", "gorgona", "robobo", "seducia", "xyzax"]:
		if nm.contains(k):
			tex = _tex("res://assets/ui/avatar/avatar_%s.webp" % k)
	if tex == null:
		tex = _tex(UI_DIR + "boss_icon.webp")
	var ring := Panel.new()
	ring.name = "OwnerBadge"
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring.size = Vector2(64, 64)
	ring.position = Vector2(cx - 32.0, -12.0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.05, 0.05)
	sb.set_corner_radius_all(32)
	sb.set_border_width_all(4)
	sb.border_color = Color(0.78, 0.25, 0.25)
	ring.add_theme_stylebox_override("panel", sb)
	ring.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	var pic := TextureRect.new()
	pic.texture = tex
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pic.position = Vector2(2, 2)
	pic.size = Vector2(60, 60)
	ring.add_child(pic)
	return ring

## « <adversaire> HAS PLAYED A SPELL / ROOM ABILITY » : notice sombre en haut a droite (BubblesFactory.CreatePlayBubble), 2,5 s.
func _notice_ai(pid: int, mv: Dictionary) -> void:
	if pid == _my_pid():
		return
	var t := str(mv.get("type", ""))
	var pl: Dictionary = (game_manager.G.get("players", {}) as Dictionary).get(pid, {})
	var args: Array = mv.get("args", [])
	var ai := -1 if args.is_empty() or not (args[0] is int) else int(args[0])
	var card = null # la carte de la capacite (appelee avant le coup) : un appui sur la bulle la montre (ShowBubleDetail)
	var spot := {} # ce que la carte jouee touche : cadre rouge sur le plateau pendant le zoom (ShowBubleDetail : HighLightCards Red)
	if t in ["playSpell", "useHandRoom"] and args.size() > 1 and args[1] is Dictionary:
		spot = _spot_of_target(args[1], pid)
	if t in ["playSpell", "useHandRoom"]:
		var hand: Array = pl.get("hand", [])
		card = hand[ai] if ai >= 0 and ai < hand.size() else null
	elif t == "activateRoom":
		var dng: Array = pl.get("dungeon", [])
		card = BossEngine.active_room(dng[ai]) if ai >= 0 and ai < dng.size() else null
	if t == "playSpell":
		_show_notice("SPELL", card, spot)
	elif t in ["activateRoom", "useHandRoom"]:
		_show_notice("ROOM ABILITY", card, spot)

func _show_notice(what: String, card = null, spot := {}) -> void:
	if _notice != null and is_instance_valid(_notice):
		_ui_layer.remove_child(_notice)
		_notice.queue_free()
	var n := Control.new()
	n.name = "Notice"
	n.mouse_filter = Control.MOUSE_FILTER_STOP if card is Dictionary else Control.MOUSE_FILTER_IGNORE
	n.position = Vector2(1458, 63) # APK : boite x 1458..1672, y 65..194, queue jusqu'a 1692
	n.size = Vector2(234, 136)
	if card is Dictionary:
		n.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		n.gui_input.connect(func(ev: InputEvent):
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
				n.accept_event()
				_notice_zoom(card, spot))
	UiKit.image(n, UI_DIR + "action_bubble.webp", Vector2.ZERO, Vector2(234, 136))
	var fx := UiKit.image(n, UI_DIR + "action_bubble_effect.webp", Vector2.ZERO, Vector2(234, 136))
	fx.create_tween().set_loops().tween_property(fx, "modulate:a", 0.15, 0.6).from(1.0).set_trans(Tween.TRANS_SINE)
	UiKit.label(n, "HAS PLAYED A", 17, Color.WHITE, Vector2(0, 41), 216.0, UiKit.FONT_A, HORIZONTAL_ALIGNMENT_CENTER)
	UiKit.label(n, what, 21, APK_GOLD, Vector2(0, 64), 216.0, UiKit.FONT_A, HORIZONTAL_ALIGNMENT_CENTER)
	_ui_layer.add_child(n)
	_notice = n
	var tw := n.create_tween()
	tw.tween_interval(2.5)
	tw.tween_property(n, "modulate:a", 0.0, 0.4)
	tw.tween_callback(n.queue_free)

## Appui sur la bulle de l'adversaire : la carte jouee en grand au centre de l'ecran (GamePlayBaseScene.ShowBubleDetail), jusqu'au clic suivant.
func _notice_zoom(card: Dictionary, spot := {}) -> void:
	_zoom_hide()
	_zoom = UiKit.zoom_card(card, UiKit.ZOOM_CARD)
	_zoom.set_meta("levelup", true) # survit aux refresh (l'IA continue de jouer) ; _input le ferme au clic suivant
	_zoom.position = Vector2(STACK_CX - _zoom.size.x / 2.0, 498.0 - _zoom.size.y / 2.0)
	_ui_layer.add_child(_zoom)
	if not spot.is_empty():
		var node := _spot_node(spot)
		if node != null:
			_zoom.set_meta("frames", [_gold_frame(_spot_rect(spot, node), true)])

## Nouvelles cartes en main (pioche) : dos de carte au centre (une rangee, plus petit s'il y en a plusieurs), la carte se retourne puis
## rejoint la main (DrawCardEmitter). Pas pendant le choix du boss / la defausse d'ouverture ; pas sans animations.
func _track_hand_draw(G: Dictionary, p: Dictionary, phase: String) -> void:
	var hand: Array = p.get("hand", [])
	var seen_before := _hand_seen.duplicate()
	var same_seat := _hand_seen_pid == view_pid
	_hand_seen = hand.duplicate()
	_hand_seen_pid = view_pid
	if skip_animations or not same_seat or seen_before.is_empty() or phase == "boss" or phase == "setup" or _is_opening_discard_for_me() or G.get("gameOver") != null:
		return
	var counts := {}
	for c in seen_before:
		counts[c] = int(counts.get(c, 0)) + 1
	var fresh: Array = []
	for c in hand:
		if int(counts.get(c, 0)) > 0:
			counts[c] = int(counts[c]) - 1
		else:
			fresh.append(c)
	if not fresh.is_empty() and fresh.size() <= 4:
		_show_draw(fresh)

func _show_draw(cards: Array) -> void:
	var n := cards.size()
	var sc := lerpf(0.37, 1.0, 1.0 / float(n))
	var csz := UiKit.ZOOM_CARD * sc
	for i in n:
		var card: Dictionary = cards[i]
		var holder := Control.new()
		holder.name = "DrawnCard"
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var back := UiKit.zoom_back("back-spell" if bool(card.get("isSpell", false)) else "back-room", csz)
		var face := UiKit.zoom_card(card, csz)
		face.visible = false
		holder.add_child(back)
		holder.add_child(face)
		holder.size = back.size
		holder.pivot_offset = back.size / 2.0
		var cx := lerpf(400.0, 1490.0, float(i + 1) / float(n + 1))
		holder.position = Vector2(cx, 520.0) - back.size / 2.0
		_ui_layer.add_child(holder)
		var tw := holder.create_tween()
		tw.tween_interval(0.12 * i)
		tw.tween_interval(0.45) # le dos de carte
		tw.tween_property(holder, "scale:x", 0.0, 0.12)
		tw.tween_callback(func():
			back.visible = false
			face.visible = true)
		tw.tween_property(holder, "scale:x", 1.0, 0.12)
		tw.tween_interval(0.6)
		tw.set_parallel(true)
		tw.tween_property(holder, "position:y", 1000.0, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		tw.tween_property(holder, "modulate:a", 0.0, 0.3)
		tw.chain().tween_callback(holder.queue_free)

## Bulle de mise en garde de mon boss (APK : BossHint) quand on veut passer alors qu'une salle peut encore etre construite.
func _can_still_build(moves: Array) -> bool:
	var G: Dictionary = game_manager.G
	return str(G.get("phase", "")) in ["build", "setup"] and (G.get("stack", []) as Array).is_empty() and not G.has("buildWindow") and _has_any(moves, ["buildRoom"])

func _warn_show() -> void:
	_warn_hide()
	var b := Control.new()
	b.name = "PassWarning"
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.position = Vector2(1230, 542) # APK : bulle x 1231..1461, y 548..673 (queue jusqu'a 692)
	b.size = Vector2(238, 150)
	UiKit.image(b, UI_DIR + "boss_globe.webp", Vector2.ZERO, Vector2(238, 150))
	# 4 lignes comme l'APK (le retour a la ligne automatique debordait de la bulle)
	var t := UiKit.label(b, "HEY! YOU CAN\nBUILD A\nROOM! STILL\nWANT TO PASS?", 21, Color.WHITE, Vector2(2, 6), 232.0, UiKit.FONT_A, HORIZONTAL_ALIGNMENT_CENTER)
	t.add_theme_constant_override("line_spacing", -4)
	t.custom_minimum_size = Vector2(232.0, 118.0)
	t.size = Vector2(232.0, 118.0)
	t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_ui_layer.add_child(b)
	_warn = b
	_warn_t = WARN_TIME

func _warn_hide() -> void:
	if _warn != null and is_instance_valid(_warn):
		_ui_layer.remove_child(_warn)
		_warn.queue_free()
	_warn = null
	_warn_t = 0.0

func _tick_warn(delta: float) -> void:
	if _warn != null:
		_warn_t -= delta
		if _warn_t <= 0.0:
			_warn_hide()

## PASS TURN -> DONE! (fenetre de sorts apres ma construction, salles encore face cachee).
func _style_pass_button(done: bool) -> void:
	var b := btn_pass as TextureButton
	b.texture_normal = _tex(TEX_DONE if done else TEX_PASS)
	b.texture_pressed = _tex(UI_DIR + ("done_button_unlimited_pressed.webp" if done else "pass_button_pressed.webp"))

## Fin de partie (WinnerScene / LoseScene) : bandeau noir, boss gagnant, cristaux, OK -> retour a l'ecran titre.
func _show_gameover(G: Dictionary) -> void:
	if _animating_hero or (_gameover != null and is_instance_valid(_gameover)):
		return # la derniere traversee se joue d'abord (refresh a sa fin)
	_win_hide()
	_warn_hide()
	_drag_clear()
	_zoom_hide()
	phase_banner.visible = false # APK : plus de bandeau de phase sur l'ecran de fin
	var w := int((G["gameOver"] as Dictionary).get("winner", -1))
	var players: Dictionary = G.get("players", {})
	var boss = (players[w] as Dictionary).get("boss") if players.has(w) else null
	var lose: bool = (_apk_flow() or _is_online()) and w != _my_pid()
	_gameover = GameOverBanner.new()
	_gameover.z_index = 90
	add_child(_gameover)
	_gameover.build(str((boss as Dictionary).get("name", "")) if boss != null else "PLAYER %d" % (w + 1), str((boss as Dictionary).get("id", "")) if boss != null else "", lose)
	_gameover.ok_pressed.connect(_confirm_quit)

# ---------------------------------------------------------------------------------------------------------------------
# Menu en jeu (engrenage) : PAUSED = RESUME / CARD GALLERY / RULES / SETTINGS / QUIT GAME (InGameMenu), regles superposees au plateau
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
	var menu := InGameMenu.new()
	pop.add_child(menu)
	menu.resume_requested.connect(_close_menu)
	menu.rules_requested.connect(_open_rules)
	menu.quit_requested.connect(_open_quit_confirm)
	menu.speed_changed.connect(func(): _speed = _speed_factor())

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

## APK (GamePlayBaseScene.ShowZoomCard) : LEVEL UP montre mon boss en grand (x1,3), cadre noir 450 x 632 en bas a droite (x 1280..1730, y 444..1076).
func _on_level_up_pressed() -> void:
	_play_sfx("res://assets/audio/sfx/sting_levelup.wav")
	var boss = (((game_manager.G.get("players", {}) as Dictionary).get(_my_pid(), {}) as Dictionary)).get("boss")
	if boss == null:
		return
	_zoom_hide()
	_zoom = UiKit.zoom_card(boss, UiKit.ZOOM_CARD * 1.3)
	_zoom.set_meta("levelup", true)
	_zoom.position = Vector2(1730.0 - _zoom.size.x, 1076.0 - _zoom.size.y) # APK : bord droit x 1730, bas y 1076 (couvre le bouton)
	_ui_layer.add_child(_zoom)

func _get_total_dungeon_damage(player_dict: Dictionary) -> int:
	var total := 0
	for stack in player_dict.get("dungeon", []):
		var r = BossEngine.active_room(stack)
		if r != null and not bool((r as Dictionary).get("faceDown", false)):
			total += int((r as Dictionary).get("damage", 0))
	return total
