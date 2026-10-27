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

## Tutoriel (TutorialOverlay) : `tutorial_gate` vide = aucun effet, le plateau se comporte exactement comme avant. Rempli par mount_tutorial,
## il est interroge par _tg(genre, argument, defaut) aux points sensibles (voir TutorialOverlay.gate pour la liste des genres).
signal room_detail_shown(di: int) # le zoom d'une salle activable vient de s'afficher (GamePlayTutScene.OnRoomDetailShow)
var tutorial_gate: Callable

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
const ROOM_FOCUS_SCALE := 0.5 / 0.37    # APK CardStackSlotComponent.CreateScaleInTopRoomTask : la salle ou se trouve le heros passe de 0,37 a 0,5 (CardsFactory.cs:100-101, CardStackSlotComponent.cs:112), elle reprend sa taille quand il la quitte
const SLOT_STEP := 140.0
const PLAY_CX := 945.0                   # centre de la zone de jeu (entre les deux colonnes)
const STACK_CX := 960.0                  # APK : pile de sorts, zoom central et barre de temps centres au milieu de l'ecran (cadre noir x 785..1135)
const HAND_CARD := Vector2(175, 244)     # APK : carte 350x488 a l'echelle 0,5 (HandEntity.NormalScale), bas de carte sous le bord de l'ecran
const HAND_CX := 960.0                   # HandEntity : x = VirtualWidth * 0,5 (1440 centres dans 1920), y = VirtualHeight * 0,9
const HAND_CY := 972.0
const BIG_CARD := Vector2(245, 341.6)   # defausse d'ouverture : CarouselSelectorEntity.cs:46-52 NormalScale 0,7 x carte 350 x 488 (APK discard_hand_7cards : face visible 207 x 312 mesure)
const DISCARD_CX := 870.0                # centre de la rangee de defausse : cartes 1 a 7 de x 385 a 1347 sur la frame APK (CarouselSelectorEntity.cs:35 LocalX = -90, decale vers la gauche)
const DISCARD_TOP := 328.0               # haut des cartes de defausse : centre y ~ 499 (MiddleCarrouselEntity.cs:24, y = 498)
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
var _fx_hand: Control                    # particules des cartes selectionnees (ApkParticles), derriere la main et persistantes d'un refresh a l'autre (la main est reconstruite a chaque fois)
var phase_banner: TextureRect
var timer_label: Label
var hero_crossing_layer: Control
var _dim: ColorRect
var _intro_field: Control               # tutoriel : decor de l'ecran noir des intros (bandes + filets or, tut_11..20), voir make_intro_field
var _dim_all: ColorRect                 # tutoriel : voile du carrousel (tut_16), le seul ecran ou le plateau entier est assombri sans bulle
var _bubble: TextureRect
var _carousel_text: RichTextLabel
var _confirm_btn: Button

var foe_name_label: Label
var foe_sub_label: Label
var foe_wounds_label: Label
var foe_souls_label: Label
var foe_coins_label: Label
var foe_treasures_box: Control
var foe_group: Control                   # panneau adverse a 2 joueurs (OneOpponentDetail)
var opp_box: Control                     # 3-4 joueurs : CollapsedOpponentDetail x (N-1), colonne droite (TopRightPanelEntity)
var opp_detail: Control                  # ExpandedOpponentDetail : tire a gauche de la colonne par un second clic sur la vignette choisie
var _opp_open := false
var _opp_gen := 0
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
var _order_cache: Dictionary = {} # pid -> Boss.PlayerId
var _hand_last := -1                     # indice de la carte de la main survolee (CardPositionComponent.lastIndex, int.MinValue = aucune)
var _hand_cur := -1                      # carte de la main sous le curseur a cet instant
var _fan_cards: Array = []               # cartes de la main en eventail (_place_fan) et leur taille
var _fan_sz := Vector2.ZERO
var _sparkle_on := false                 # boucle sfx_sparklecard en cours (surbrillance verte d'une salle ciblable)
var _popup: Control                      # fenetre modale courante (choix, cibles, options, confirmation)
var _popup_kind := ""                    # "choice" | "target" | "menu" | "quit"
var _choice_sig := ""
var _rules: Control                      # RulesViewer superpose au plateau (null si ferme)
var _auto_timer := 0.0                   # delai avant une passe automatique (aventure, rien a decider)
var _hero_pawn: Control                  # pion du heros en aventure : persiste d'une salle a l'autre
var _hero_pawn_hp: Label
var _adv_seen := {}                      # dernier pas d'aventure anime : {pid, hid, room, hp}
var _stone_theme_cache: Theme
var _compact_theme_cache: Theme
var _ui_layer: Control                   # barre de temps, pile de sorts, notices, zoom, glisser (devant la main, derriere les fenetres)
var _win_bar: TimeBar
var win_time_scale := 1.0                # tests : raccourcit les fenetres chronometrees
var _win_t := 0.0
var _win_sig := ""
var _last_ms := 0                        # horloge reelle du dernier _process : Godot plafonne delta a ~0,13 s par image (web a quelques i/s)
var _grey_prev: Dictionary = {}              # main : cle "index:id" -> {g: grise ?, t: ms du dernier changement} (fondu de grisage, voir _refresh_hand)
var _hand_stale := false                 # un refresh() a ete saute pendant un appui sur une carte de la main (voir _refresh_hand)
var _speed := 1.0                        # GameSettings.GetSpeed : SLOW 1,5 / NORMAL 1 / FAST 0,5 (durees des animations de heros)
var _pass_raised_key := ""                # siege/tour/phase ou le 1er appui sur PASS TURN a deja eu lieu (le 2e passe)
var _warn: Control                       # bulle de mise en garde « YOU CAN BUILD A ROOM »
var _warn_t := 0.0
var _pulse_t := 0.0                      # temps depuis l'apparition du bouton PASS TURN / DONE! (pulsation toutes les 5 s)
var _gameover: Control
var _press := {}                         # appui sur une carte de la main : {card, idx, pos} (arme le glisser)
var _drag := {}                          # glisser en cours : {idx, preview, frames}
var _zoom: Control                       # zoom d'appui long
var _stack_sig := ""
var _pass_tw: Tween                      # fondu du bouton PASS TURN / DONE! (voir _set_pass_visible)
var _pass_want := false
var _stack_keys: Array = []              # cartes de la pile au dernier affichage : celles qui arrivent sont animees (_refresh_stack_cards)
var _stack_ui: Control
var _notice: Control
var _hand_seen: Array = []               # cartes de la main deja vues (animation de pioche)
var _hand_seen_pid := -1
var _discard_move := false               # mon dernier coup defausse de la main (resolveChoice, discardForCoin) : les cartes parties sont animees (_show_discard) ; une carte posee ou jouee ne l'est pas
var _deal_pending := false               # le choix du boss vient de finir : toute la main est distribuee (DrawCardEmitter.cs:46-49 : lastHands vide)
var _draw_hide := {}                     # id de carte -> nombre d'exemplaires encore en vol vers la main : leurs cartes restent cachees (voir _refresh_hand)
var _undo_ids: Array = []                # salles de ma pose en attente au dernier affichage : si elles reviennent en main (undoBuild), ce n'est pas une pioche
var _souls_seen := -1
var _wounds_seen := -1
# Choix de la cible sur le plateau : {} = inactif ; sinon {pid, title, hint, entries: [{label, cb, mv, spot}]}.
var _tgt: Dictionary = {}
var _tgt_layer: Control                  # voile + bulle + CANCEL + zones cliquables (un Control par cible affichee)
var _tgt_cancel_btn: Button
var _tgt_spots: Array = []               # [{ctrl, ids}] : ids = indices dans _tgt.entries atteints par cette zone
var _tgt_src: Control                    # salle source de la capacite en cours (bordure verte, grossie)
var _tgt_lifted: Array = []              # noeuds du plateau passes devant le voile (remis a z 0 a la fin)
var _town_header: TextureRect           # « HEROES IN TOWN » ; « EPIC / HEROES IN TOWN » (cadre or) tant qu'un heros epique est en ville
var _town_scroll: ScrollContainer
var _town_drag := {}                     # glisser la colonne HEROES IN TOWN (VerticalScrollQueueComponent) : {y, sv}
var _town_sig := ""                      # heros affiches : la colonne n'est reconstruite (et son defilement garde) que s'ils changent
var _town_ids: Array = []
var _ent_tok: Dictionary = {}            # pid -> cartes de l'entree, alignees sur les heros de `entrance` (la carte du heros qui traverse reste a l'entree)
var _focus := {}                         # {pid, room} : salle agrandie parce que le heros s'y trouve (voir _set_focus)
var _bait_t0 := 0                        # BAIT PHASE : horloge (ms) du debut du leurre, 0 = aucun (voir _refresh_phase_banner)
var _bait_ms := 0                        # duree du leurre (ms) : un vol de BAIT_FLY x vitesse par heros, l'un apres l'autre
var _bait_flown := {}                    # cartes deja parties en vol pour ce leurre : {pid:id:rang -> _bait_t0}
var _bait_landed := {}                   # cartes deja arrivees a l'entree du donjon pour ce leurre : {pid:id:rang -> _bait_t0}
var _phase_tw: Tween                     # saut de la plaque de phase (PhaseTitleControl + JumpBehavior)
var _foe_frozen := {}                    # « adversaire:indice de salle » -> salle gelee au dernier affichage (voile de glace en fondu au gel)
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
# Fenetres de sorts de l'APK (GamePlayBaseScene) : barre verte de 3 s au-dessus du heros (aventure), de 6 s au-dessus de la pile de sorts.
const PHASE_BANNER_Y := -62.0
const DRAW_LAND := 0.3                   # une carte piochee rejoint sa place dans la main : lerp de CardMoveBehavior (0,009 x ms par image, ~0,3 s pour 95 %, CardMoveBehavior.cs:13,129-133)
const BAIT_FLY := 1.0                    # vol d'une carte de heros depuis la ville jusqu'a l'entree du donjon, x vitesse (VerticalScrollQueueComponent.cs:261-262) ; la plaque BAIT PHASE dure tant que les vols (chacun apres le precedent)
const WINDOW_ADVENTURE := 3.0
const WINDOW_STACK := 6.0
const PASS_FAST := 0.45                  # rien a jouer : le siege humain passe presque tout de suite
const GO_FAST := 0.55                    # le heros suivant avance de lui-meme (multiplie par la vitesse de jeu)
const HAND_UPPER := 797.0                # CardExtractBehavior.cs:ResolveDependencies : limite haute de la main (972 - 450/2 + 50) ; au-dessus la carte est extraite, en dessous elle retourne dans la main
const NOTICE_HOLD := 3.5                 # bulle « HAS PLAYED A » : fondu d'entree 0,5 s + 3,0 s (BubblesPlayerEmitter.cs:22) ; la salle reste agrandie pendant ce temps (deduit des captures APK)
const WARN_TIME := 0.5                   # bulle « YOU CAN BUILD A ROOM » (HideWhenTouchBehavior.cs:36-37) : entree et sortie de 0,5 s, fermee par un appui hors de la bulle une fois entree
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
	_fx_hand = Control.new()
	_fx_hand.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fx_hand.size = Vector2(1920, 1080)
	add_child(_fx_hand)
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
	sprite.mouse_filter = Control.MOUSE_FILTER_STOP # DungeonFrameEntity.cs:265-270 : un appui sur le boss montre sa carte
	sprite.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			_boss_zoom(idx))
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
	foe_group = Control.new() # OneOpponentDetail (2 joueurs) ; a 3-4 joueurs, les vignettes opp_box + opp_detail le remplacent
	foe_group.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(foe_group)
	opp_box = Control.new()
	opp_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(opp_box)
	_img(foe_group, UI_DIR + "boss_icon.webp", Vector2(1712.5, 74.5), Vector2(43, 43), TextureRect.STRETCH_KEEP_ASPECT_CENTERED)
	foe_name_label = _lbl(foe_group, "", 18, APK_GOLD, Vector2(1762, 75), 150.0, _fa)
	foe_sub_label = _lbl(foe_group, "", 11, Color.WHITE, Vector2(1762, 100), 110.0, _fa)
	foe_sub_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	foe_sub_label.add_theme_constant_override("line_spacing", -4)
	_img(foe_group, TEX_WOUND, Vector2(1715.5, 138), Vector2(27, 35), TextureRect.STRETCH_KEEP_ASPECT_CENTERED)
	foe_wounds_label = _lbl(foe_group, "x0", 18, Color.WHITE, Vector2(1746, 142), 0.0, _fa)
	_img(foe_group, TEX_SOUL, Vector2(1775.5, 137.5), Vector2(29, 34), TextureRect.STRETCH_KEEP_ASPECT_CENTERED)
	foe_souls_label = _lbl(foe_group, "x0", 18, Color.WHITE, Vector2(1806, 142), 0.0, _fa)
	foe_treasures_box = Control.new()
	foe_treasures_box.position = Vector2(1715, 197)
	foe_treasures_box.size = Vector2(202, 68)
	foe_treasures_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	foe_group.add_child(foe_treasures_box)
	_img(foe_treasures_box, UI_DIR + "bg_treasures_boss_profile.webp", Vector2.ZERO, Vector2(202, 68)).modulate = Color(1, 1, 1, 0.6)
	foe_coins_label = _lbl(foe_group, "", 12, GOLD, Vector2(1718, 268))
	# --- Pioches
	_lbl(foe_group, "ROOM DECK", 16, Color.WHITE, Vector2(1718, 286), 0.0, _fa)
	_img(foe_group, UI_DIR + "rooms_icon.webp", Vector2(1717, 315), Vector2(50, 48))
	room_deck_label = _lbl(foe_group, "x0", 20, APK_GOLD, Vector2(1784, 335), 0.0, _fa)
	_lbl(foe_group, "SPELL DECK", 16, Color.WHITE, Vector2(1718, 382), 0.0, _fa)
	_img(foe_group, UI_DIR + "spells_icon.webp", Vector2(1717, 410), Vector2(50, 48))
	spell_deck_label = _lbl(foe_group, "x0", 20, APK_GOLD, Vector2(1784, 431), 0.0, _fa)
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
	opp_detail = Control.new() # ExpandedOpponentDetail : bg_boss_detail 295 x 451, tire de 498 px depuis le bord droit (ExpandedOpponentComponent.cs:9,43)
	opp_detail.position = Vector2(1422, 55)
	opp_detail.size = Vector2(295, 451)
	opp_detail.visible = false
	opp_detail.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			_opp_toggle()) # ExpandedOpponentDetail.cs:61-64 : un appui sur le panneau le replie
	add_child(opp_detail)

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
func _make_bar_theme(compact := false) -> Theme:
	if compact and _compact_theme_cache != null:
		return _compact_theme_cache
	if _stone_theme_cache != null and not compact:
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
		sb.content_margin_left = 12 if compact else 30 # compact : barre des 4-5 adversaires (6 joueurs) qui doit tenir a gauche de l'engrenage
		sb.content_margin_right = 12 if compact else 30
		sb.content_margin_top = 12
		sb.content_margin_bottom = 12
		if n == "hover":
			sb.modulate_color = Color(1.3, 1.25, 1.05)
		elif n == "disabled":
			sb.modulate_color = Color(0.55, 0.55, 0.55)
		th.set_stylebox(n, "Button", sb)
	th.set_font("font", "Button", _fb)
	th.set_font_size("font_size", "Button", 22 if compact else 24)
	th.set_color("font_color", "Button", Color.WHITE)
	th.set_color("font_hover_color", "Button", GOLD)
	th.set_color("font_pressed_color", "Button", GOLD)
	if compact:
		_compact_theme_cache = th
	else:
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
	_intro_field = make_intro_field()
	_intro_field.visible = false
	add_child(_intro_field)
	_dim_all = ColorRect.new()
	_dim_all.color = Color(0, 0, 0, 0.70) # tut_16 vs tut_11 (Pillow) : colonne de droite 7,9 contre 26,3 hors voile = x 0,30
	_dim_all.size = Vector2(1920, 1080)
	_dim_all.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dim_all.visible = false
	add_child(_dim_all)
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

## Decor de l'ecran noir des intros du tutoriel (tut_11..20, mesure Pillow sous le voile de 165/255 -> couleurs d'origine = valeur / 0,353) :
## cadre du terrain (x 182..1708, y 61..953), bandes (17,3,3) en haut et en bas, (3,0,0) au milieu entre les filets y 296 et 696.
## Public : TutorialOverlay en pose une copie pour l'intro apres le choix du boss.
static func make_intro_field() -> Control:
	var root := Control.new()
	root.name = "IntroField"
	root.size = Vector2(1920, 1080)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var gold := Color8(204, 153, 51) # (72,54,18) / 0,353
	var inner := Color8(153, 119, 34) # (54,42,12) / 0,353
	for r in [[Rect2(184, 63, 1523, 890), Color8(17, 3, 3)], [Rect2(184, 298, 1523, 398), Color8(3, 0, 0)],
			[Rect2(182, 61, 1527, 2), gold], [Rect2(182, 953, 1527, 1), gold], [Rect2(182, 61, 2, 893), gold], [Rect2(1707, 61, 2, 893), gold],
			[Rect2(184, 296, 1523, 2), inner], [Rect2(184, 696, 1523, 2), inner]]:
		var c := ColorRect.new()
		c.position = (r[0] as Rect2).position
		c.size = (r[0] as Rect2).size
		c.color = r[1]
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(c)
	return root

func _build_top() -> void:
	phase_banner = _img(self, "", Vector2(PLAY_CX - 210, PHASE_BANNER_Y), Vector2(403, 153)) # APK : plaque x 739..1135 (centre 937)
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
	foe_bar.grow_horizontal = Control.GROW_DIRECTION_BEGIN # si les boutons depassent 340 px, la barre s'etend vers la gauche (jamais sur l'engrenage)
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
	_speed = _speed_factor() # _ready() tourne avant setup() : en ligne le facteur ne se connait qu'ici
	on_exit_callback = p_exit_cb
	game_manager.state_changed.connect(refresh)
	if _is_online():
		(game_manager as OnlineGameManager).client.remote_play.connect(_on_remote_play)
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

## Reponse de la garde du tutoriel ; `default` quand il n'y en a pas (partie normale).
func _tg(kind: String, arg = null, default = true):
	return tutorial_gate.call(kind, arg) if tutorial_gate.is_valid() else default

## Monte le tutoriel sur ce plateau : a appeler AVANT setup() (la garde « carousel » doit tenir le choix du boss).
func mount_tutorial(ov: Control) -> void:
	ov.name = "TutorialOverlay"
	ov.set("board", self)
	tutorial_gate = Callable(ov, "gate")
	add_child(ov)

func _exit_tree() -> void:
	if _sparkle_on: # quitter la partie en plein ciblage : la boucle ne doit pas survivre au plateau
		_sparkle_on = false
		AudioManager.stop_loop("sfx_sparklecard")

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
		b.pressed.connect(func(): _draw_clear(); view_pid = p; _sync_slot_pids(); refresh())
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
	for c in foe_bar.get_children() + opp_box.get_children():
		c.get_parent().remove_child(c)
		c.queue_free()
	# 3-4 joueurs : vignettes de la colonne droite (TopRightPanelEntity.cs:80-96) ; 5-6 joueurs (hors APK) : boutons P<n> dans la barre du haut
	var panels := others.size() in [2, 3]
	foe_group.visible = not panels
	foe_bar.visible = others.size() > 3
	if not panels:
		_opp_open = false
	_opp_detail_sync()
	if others.size() <= 1:
		return
	foe_bar.theme = _make_bar_theme(others.size() > 3) # 5-6 joueurs : boutons plus serres
	for i in others.size():
		var pid = others[i]
		var b := Button.new()
		var p: int = int(pid)
		b.set_meta("pid", p)
		if panels:
			b.flat = true
			b.focus_mode = Control.FOCUS_NONE
			b.position = Vector2(1708, 60 + 141 * i)
			b.custom_minimum_size = Vector2(212, 141)
			b.size = Vector2(212, 141)
			b.set_meta("selected", p == foe_pid)
			opp_box.add_child(b)
			_opp_bg(b, p)
		else:
			b.text = "P%d" % (p + 1)
			b.disabled = p == foe_pid
			var boss = ((game_manager.G["players"] as Dictionary)[pid] as Dictionary).get("boss")
			b.tooltip_text = "Player %d%s" % [p + 1, " - %s" % str((boss as Dictionary).get("name", "")) if boss != null else ""]
			foe_bar.add_child(b)
		b.pressed.connect(func():
			if _animating_hero or (_hero_pawn != null and is_instance_valid(_hero_pawn)):
				return # un heros traverse le donjon affiche
			if panels and p == foe_pid:
				_opp_toggle() # CollapsedOpponentDetail_TouchTap : second appui sur la vignette choisie = panneau etendu
				return
			foe_pid = p
			refresh())
		if p == game_manager.active_player() and game_manager.G.get("gameOver") == null:
			# CollapsedOpponentDetail.Refresh (cs:331-332) : Emit = boss.IsActivePlayer, emetteur 0,9 x le panneau (cs:204, ECHELLE) centre sur lui (LocalX = -largeur / 2, cs:203).
			# Les boutons P<n> (5-6 joueurs) n'ont leur taille qu'apres la mise en page : l'emetteur suit le bouton.
			var fx := ApkParticles.creer(b, Vector2.ONE)
			var fit := func(sz: Vector2):
				fx.position = sz * 0.5
				fx.set_size(sz * ApkParticles.ECHELLE)
			fit.call(b.get_combined_minimum_size()) # taille de depart (la mise en page n'a pas encore eu lieu), puis la vraie
			b.resized.connect(func(): fit.call(b.size))
			fx.set_emit(true)
		if panels:
			_opp_front(b, p)

const TREASURE_NAMES := {1: "cleric", 2: "fighter", 3: "mage", 4: "thief"}

## Boss d'un adversaire tel que l'APK l'affiche : cache tant que le notre n'est pas choisi.
func _opp_boss(pid: int):
	var G: Dictionary = game_manager.G
	if str(G.get("phase", "")) == "boss" and ((G["players"] as Dictionary)[view_pid] as Dictionary).get("boss") == null:
		return null
	return ((G["players"] as Dictionary)[pid] as Dictionary).get("boss")

## CollapsedOpponentDetail (212 x 141) : fond du boss (bg_<premier tresor>_profile, GetBossProfileBackgroundAsset), 1,05 x 1,01 s'il joue (cs:329-330).
func _opp_bg(b: Button, pid: int) -> void:
	var boss = _opp_boss(pid)
	if boss == null:
		return
	var tr: Array = (boss as Dictionary).get("treasures", [])
	var bg := _img(b, "res://assets/ui/characters/bg_%s_profile.webp" % TREASURE_NAMES.get(int(tr[0]) if not tr.is_empty() else 1, "cleric"), Vector2(1, 0), Vector2(211, 141))
	if pid == game_manager.active_player() and game_manager.G.get("gameOver") == null:
		bg.pivot_offset = Vector2(211, 70.5) # Origin (1, 0,5)
		bg.scale = Vector2(1.05, 1.01)

## Icone + « xN » (IconCounterControlEntity sans maximum, cs:174-181 : texte a largeur de l'icone + 3, centre verticalement, echelle 0,8).
func _opp_count(b: Control, path: String, n: int, pos: Vector2) -> void:
	var t := _img(b, path, pos)
	_lbl(b, "x%d" % n, 16, Color.WHITE, Vector2(pos.x + t.size.x + 3.0, pos.y + (t.size.y - 20.0) / 2.0 - 3.0), 0.0, _fa)

func _opp_front(b: Button, pid: int) -> void:
	var G: Dictionary = game_manager.G
	var pl: Dictionary = (G["players"] as Dictionary)[pid]
	var boss = _opp_boss(pid)
	var sel := pid == foe_pid
	var active := pid == game_manager.active_player() and G.get("gameOver") == null
	if boss != null:
		var bid := str((boss as Dictionary).get("id", "")).to_lower()
		var ip := "res://assets/ui/characters/icon_%s_profile.webp" % bid
		if bool(pl.get("eliminated", false)):
			ip = UI_DIR + "icon_death_profile.webp"
		elif not ResourceLoader.exists(ip):
			ip = UI_DIR + "boss_icon.webp"
		var ic := _img(b, ip, Vector2(3, 5))
		ic.pivot_offset = Vector2(66, ic.size.y / 2.0) # Origin (1, 0,5), LocalX -143, LocalY -38
		ic.scale = Vector2.ONE if active else Vector2(0.83, 0.83)
		var nm := str((boss as Dictionary).get("name", "")).to_upper()
		_lbl(b, nm if nm.length() <= 10 else nm.substr(0, 10) + "...", 16, APK_GOLD if sel else Color.WHITE, Vector2(73, 7.5), 0.0, _fa)
	_opp_count(b, TEX_WOUND, CardDB.total_wounds(pl), Vector2(72, 31.5))
	_opp_count(b, TEX_SOUL, CardDB.total_souls(pl, G), Vector2(141, 31.5))
	var counts: Dictionary = BossEngine.treasure_counts(pl, G)
	for it in [[4, Vector2(14, 73.5), 2.0], [3, Vector2(114, 73.5), 2.0], [2, Vector2(14, 107.5), 6.0], [1, Vector2(114, 103.5), 2.0]]:
		var n := int(counts.get(int(it[0]), 0))
		var base: String = UI_DIR + "icon_treasure_%s" % TREASURE_NAMES[int(it[0])]
		var pos: Vector2 = it[1]
		if n == 0:
			_img(b, base + "_empty.webp", pos)
		elif n <= 4:
			var x := 0.0
			for k in n:
				x += _img(b, base + ".webp", pos + Vector2(x, 0)).size.x + float(it[2])
		else:
			_opp_count(b, base + ".webp", n, pos)
	if not sel: # topMask (cs:296-300) : assombrit les vignettes non choisies
		_rect(b, Color(0, 0, 0, 0.5), Vector2.ZERO, Vector2(212, 141))
	var border := _img(b, UI_DIR + "bg_boss_profile_selected_yellow.webp", Vector2(-8, -8)) # LocalX 2, origine (1, 0,5), 222 x 157
	border.name = "Border"
	border.visible = active

## Un second appui sur la vignette choisie ouvre / ferme ExpandedOpponentDetail.
func _opp_toggle() -> void:
	_opp_open = not _opp_open
	_opp_gen += 1
	_opp_detail_sync(true)
	if _opp_open:
		var gen := _opp_gen
		get_tree().create_timer(60.0).timeout.connect(func(): # ShowHideTaskComponent.cs:56 : repli automatique apres 1 min
			if gen == _opp_gen and _opp_open:
				_opp_toggle())

var _opp_tw: Tween
func _opp_detail_sync(animate := false) -> void:
	var on := _opp_open and foe_pid >= 0
	if on:
		_opp_detail_fill(foe_pid)
	var running := _opp_tw != null and _opp_tw.is_valid() and _opp_tw.is_running()
	if animate and not skip_animations:
		if running:
			_opp_tw.kill()
		_opp_tw = create_tween().set_parallel(true) # ExpandedOpponentComponent.cs:32,42 : 0,5 s, CubicEase (EaseOut), x -> bord droit - 498
		if on:
			opp_detail.visible = true
			opp_detail.position.x = 1920.0
			opp_detail.modulate.a = 0.0
		_opp_tw.tween_property(opp_detail, "position:x", 1422.0 if on else 1920.0, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_opp_tw.tween_property(opp_detail, "modulate:a", 1.0 if on else 0.0, 0.5)
		if not on:
			_opp_tw.chain().tween_callback(func(): opp_detail.visible = false)
	elif not running:
		opp_detail.visible = on
		opp_detail.position.x = 1422.0
		opp_detail.modulate.a = 1.0

## ExpandedOpponentDetail.Refresh : en-tete du boss, XP, blessures, ames, pioches (cartes en main) de l'adversaire choisi.
func _opp_detail_fill(pid: int) -> void:
	for c in opp_detail.get_children():
		opp_detail.remove_child(c)
		c.queue_free()
	var G: Dictionary = game_manager.G
	var pl: Dictionary = (G["players"] as Dictionary)[pid]
	var boss = _opp_boss(pid)
	_img(opp_detail, UI_DIR + "bg_boss_detail.webp", Vector2.ZERO)
	_img(opp_detail, UI_DIR + "boss_icon.webp", Vector2(8, 5), Vector2(43, 43), TextureRect.STRETCH_KEEP_ASPECT_CENTERED)
	if boss != null:
		var nm := str((boss as Dictionary).get("name", "")).to_upper()
		_lbl(opp_detail, nm if nm.length() <= 10 else nm.substr(0, 10) + "...", 18, APK_GOLD, Vector2(62, 17), 0.0, _fa)
		_lbl(opp_detail, str((boss as Dictionary).get("subtitle", "")), 11, Color.WHITE, Vector2(62, 41), 200.0, _fa)
		_lbl(opp_detail, str(int((boss as Dictionary).get("xp", 0))), 16, APK_GOLD, Vector2(67, 59), 0.0, _fa)
		_lbl(opp_detail, "XP", 16, Color.WHITE, Vector2(133, 59), 0.0, _fa)
	_lbl(opp_detail, "WOUNDS", 16, Color.WHITE, Vector2(23, 95), 0.0, _fa)
	var wc := HBoxContainer.new()
	wc.position = Vector2(23, 123)
	wc.add_theme_constant_override("separation", 3)
	opp_detail.add_child(wc)
	_icon_row(wc, 5, CardDB.total_wounds(pl), TEX_WOUND, TEX_WOUND_EMPTY, Vector2(21, 27))
	_lbl(opp_detail, "SOULS", 16, Color.WHITE, Vector2(23, 157), 0.0, _fa)
	var sc := HBoxContainer.new()
	sc.position = Vector2(23, 183)
	sc.add_theme_constant_override("separation", 0)
	opp_detail.add_child(sc)
	_icon_row(sc, 10, CardDB.total_souls(pl, G), TEX_SOUL, TEX_SOUL_EMPTY, Vector2(19, 26))
	var hand: Array = pl.get("hand", [])
	_lbl(opp_detail, "ROOM DECK", 16, Color.WHITE, Vector2(23, 227), 0.0, _fa)
	_img(opp_detail, UI_DIR + "rooms_icon.webp", Vector2(22, 256), Vector2(50, 48))
	_lbl(opp_detail, "x%d" % hand.filter(func(c): return bool((c as Dictionary).get("isRoom", false))).size(), 20, APK_GOLD, Vector2(89, 276), 0.0, _fa)
	_lbl(opp_detail, "SPELL DECK", 16, Color.WHITE, Vector2(23, 327), 0.0, _fa)
	_img(opp_detail, UI_DIR + "spells_icon.webp", Vector2(22, 356), Vector2(50, 48))
	_lbl(opp_detail, "x%d" % hand.filter(func(c): return not bool((c as Dictionary).get("isRoom", false))).size(), 20, APK_GOLD, Vector2(89, 376), 0.0, _fa)
	if Minibosses.active(G): # Rise of the Minibosses (hors APK) : le Hoard adverse, qui est dans foe_group (masque a 3-4 joueurs)
		_lbl(opp_detail, "COINS: %d" % Minibosses.coins(pl), 13, GOLD, Vector2(23, 412))

## Bouton P<n> dore (cible hors ecran) ; vignette : cadre jaune (CollapsedOpponentDetail.HighLightCards, cs:355-364).
func _foe_mark(b: Control, on: bool) -> void:
	var border := b.get_node_or_null("Border") as Control
	if border != null:
		border.visible = on or int(b.get_meta("pid", -1)) == game_manager.active_player()
	if on:
		b.add_theme_color_override("font_color", GOLD)
	else:
		b.remove_theme_color_override("font_color")

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
		slot.zoom_off.connect(_zoom_close)
		slot.zoom_stack.connect(func(di: int): _slot_zoom(view_pid, di))
		slot.room_dropped.connect(func(_h: int, _s: int):
			_play_sfx("ui_card_slide_down") # BuildRoomHandSceneBehavior.cs:182 -> FlipCardBehavior.cs:126 : la salle posee se retourne face cachee
			refresh())
		_dungeon_slots.append(slot)

func _process(delta: float) -> void:
	if game_manager == null or game_manager.G.get("gameOver") != null:
		return
	_tick_warn(delta)
	_tick_pulse(delta)
	_tick_stack_hover()
	_drag_tilt()
	# Godot plafonne delta (~0,13 s) quand les images sont lentes (web, onglet en arriere-plan) : les fenetres chronometrees (APK : horloge reelle)
	# et l'IA suivent donc l'horloge murale si elle avance plus vite (au plus 1 s par image : un onglet endormi ne vide pas la barre d'un coup).
	var now := Time.get_ticks_msec()
	var dt: float = maxf(delta, minf(float(now - _last_ms) / 1000.0, 1.0)) if _last_ms > 0 else delta
	_last_ms = now
	if not _tg("run"):
		return # tutoriel : une scene est affichee (le jeu est fige derriere, GamePlayTutScene.cs:135) ou une consigne attend le joueur
	if _animating_hero or _bait_active():
		return # le heros ne part qu'une fois tous les heros arrives a leur donjon
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
		if phase == "build" and pc.is_empty() and int(pid) != game_manager.active_player() and not game_manager.G.has("buildWindow"):
			continue # IA hors tour : son UseAbility du pas est joue par Match._drive_ai (AIPlayerInteraction.cs:86-101), pas par cette boucle
		var moves: Array = game_manager.legal_moves(int(pid))
		var has_ai_choice: bool = not pc.is_empty() and int(pc.get("playerId", -1)) == int(pid)
		# Aventure : l'IA active doit avancer / passer, sinon la partie attend indefiniment (pause : tous les sieges IA passent).
		var adv_turn: bool = phase == "adventure" and pc.is_empty() and (int(pid) == game_manager.active_player() or ((game_manager.G.get("adventure", {}) as Dictionary).get("pause") != null))
		if not moves.is_empty() and (has_ai_choice or phase == "boss" or phase == "build" or adv_turn):
			_ai_timer += dt
			if _ai_timer > (0.2 if adv_turn else 0.5):
				var mv = AI.pick_move(game_manager, int(pid))
				# Un coup juge nocif par l'IA (score < 0) n'est joue qu'en dernier recours : on prefere passer (comme soak_runner).
				if adv_turn and mv != null and AI.score_move(game_manager, int(pid), mv) < 0.0:
					for m in moves:
						if str((m as Dictionary).get("type", "")) in ["pass", "passBuild"]:
							mv = m
							break
				if mv == null:
					continue # rien a jouer pour ce siege (ses sorts n'ont aucun CheckXXX eligible, il a deja passe) : on regarde les suivants, le minuteur reste arme
				_ai_timer = 0.0
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
		return true # le heros avance de lui-meme apres la barre de 3 s (OnlineFlowManager.cs:227-231, 397-408) ; le serveur attend les sieges (pause d'aventure)
	var n := 0
	for pid in (game_manager.G.get("players", {}) as Dictionary):
		if not bool(((game_manager.G["players"] as Dictionary)[pid] as Dictionary).get("isAI", false)):
			n += 1
	return n == 1

## GameSettings.GetSpeed de l'APK : SLOW 1,5 / NORMAL 1 / FAST 0,5 (durees des animations ; les barres de temps ne dependent pas de la vitesse).
func _speed_factor() -> float:
	if _is_online():
		return 0.5 # GameSettings.cs:45-68 : en partie en ligne (ConnectionStates.InGame) la vitesse est forcee a 0,5
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
	if stack_open:
		# SpellBattleEntity.cs:28-31 : la barre suit la derniere carte posee avec un decalage (0, -300) pris dans le repere de la carte (FollowBehavior.cs:33), donc x echelle de la carte
		var lay := _stack_layout(game_manager.G.get("stack", []) as Array)
		if not lay.is_empty():
			var last: Dictionary = lay[lay.size() - 1]
			anchor = Vector2(float(last["cx"]) + 2.0, 498.0 - 300.0 * float(last["k"]))
	else:
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
	# Meme barre de 3 s avant l'entree d'un heros dans le donjon d'un siege IA (CreateWaitAndMoveHeroToNextSlotTask, InsideDungeonSlot == null) : l'humain peut jouer
	# un sort (ses coups de sort existent deja hors de son tour, Match.legal_moves) ; l'IA attend la fin de la barre. UI seule : le moteur et ses coups legaux ne changent pas.
	var act: int = game_manager.active_player()
	if apk and not stack_open and phase == "adventure" and adv.is_empty() and not pids.is_empty() and bool(((G["players"] as Dictionary).get(act, {}) as Dictionary).get("isAI", false)) \
			and not bool(((G["players"] as Dictionary)[pids[0]] as Dictionary).get("eliminated", false)) \
			and game_manager.legal_moves(act).any(func(m): return str((m as Dictionary).get("type", "")) in GO_TYPES):
		var ekey := JSON.stringify(["ai-entry", G.get("turn"), act, (((G["players"] as Dictionary)[act] as Dictionary).get("entrance", []) as Array).size()])
		if ekey != _win_sig:
			_win_sig = ekey
			_win_t = 0.0
		if not _win_paused():
			_win_t += delta
		var ewant: float = WINDOW_ADVENTURE * win_time_scale
		if _win_t < ewant:
			_win_show(ewant, false)
			return true # l'IA n'avance pas pendant la fenetre
		_win_hide()
		return false
	for pid in pids:
		var moves: Array = _my_moves(int(pid))
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
		# Meme barre avant la 1re salle : heros a l'entree (InsideDungeonSlot == null, GamePlayBaseScene.cs:924-952), le GO d'entree est alors la fin de la fenetre.
		var at_entry: bool = adv.is_empty() and go_mv != null
		var timed: bool = apk and ((not stack_open and (str(pause) == "post-damage" or at_entry)) or (stack_open and decision and str(pause) != "pre-exit"))
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
	if not (G.get("players", {}) as Dictionary).has(view_pid):
		view_pid = 0
		_sync_slot_pids()
	_refresh_seat_bar()
	if _is_online():
		_sync_playing()
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

	if G.get("gameOver") != null or _all_humans_dead(G):
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

	var my_moves: Array = _my_moves(_my_pid())
	_refresh_foe_dungeon(foe_dict)
	_apply_focus() # les emplacements adverses viennent d'etre reconstruits
	_refresh_overlay(G, phase)
	_track_hand_draw(G, p, phase) # avant _refresh_hand : les cartes piochees sont cachees des la reconstruction de la main
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
		_set_pass_visible(can_pass and _has_decision(my_moves) and not apk)
	elif stack_open:
		_set_pass_visible(can_pass and not apk)
	else:
		_set_pass_visible(can_pass) # pas de PASS TURN quand passer est illegal (choix en attente, pas mon tour de construire)
	# BuildRoomHandSceneBehavior.cs:115 : IsPassTurnModeActive = IsPlayerBuildTurn && !IsBuildTurnDone (:41, poses en attente >= MaxBuildRoomLimit) ;
	# DoneButtonBehavior.cs:25-40 : PASS TURN (pass_button) en mode passe, sinon DONE! (done_button_unlimited). Fenetre de sorts apres la derniere pose : pas mon tour de construction -> DONE!.
	_style_pass_button((phase == "build" or phase == "setup") and not stack_open and _builds_done(G, p))
	if _warn != null and not _can_still_build(my_moves):
		_warn_hide() # j'ai construit / ce n'est plus mon tour : la mise en garde n'a plus lieu d'etre
	_refresh_stack_cards(G)
	_refresh_choice_popup(G, my_moves)
	_refresh_extra_bar(G, my_moves)
	if not _drag.is_empty():
		_drag_refresh()
	_swap_resume()

func _carousel_active(G: Dictionary, phase: String) -> bool:
	return G.get("gameOver") == null and (_boss_pending(G) or _is_opening_discard_for_me())

## Le siege affiche doit encore recevoir son boss (carrousel) ; un siege qui a deja le sien voit le plateau.
func _boss_pending(G: Dictionary) -> bool:
	return G.get("gameOver") == null and str(G.get("phase", "")) == "boss" and ((G.get("players", {}) as Dictionary).get(view_pid, {}) as Dictionary).get("boss") == null and _tg("carousel") # tutoriel : le carrousel attend la fin de l'intro

## Un seul humain (solo) : PLAY BOSS MONSTER! ; plusieurs (en ligne) : l'ecran se ferme seul.
func _boss_solo(G: Dictionary) -> bool:
	return (G.get("players", {}) as Dictionary).values().filter(func(q): return not bool((q as Dictionary).get("isAI", false))).size() == 1

func _refresh_overlay(G: Dictionary, phase: String) -> void:
	var over: bool = G.get("gameOver") != null
	var boss_pick := _boss_pending(G)
	var discard := _is_opening_discard_for_me() and not over
	# tutoriel : le carrousel attend la fin des bulles d'intro (_tg), mais l'APK montre deja l'ecran noir du choix du boss (10_tut_a)
	var intro_wait: bool = not boss_pick and G.get("gameOver") == null and str(G.get("phase", "")) == "boss" and ((G.get("players", {}) as Dictionary).get(view_pid, {}) as Dictionary).get("boss") == null
	var full := boss_pick or intro_wait
	_dim.visible = full or discard
	# APK : choix du boss = tout l'ecran s'assombrit (panneaux et plaque de phase compris) ; defausse d'ouverture = seulement le bandeau
	# des cartes (y 296..696, filets or), le reste du plateau reste visible et la plaque de phase est cachee.
	_dim.color = Color(0, 0, 0, 0.92 if full else 0.88)
	_dim.position = Vector2.ZERO if full else Vector2(184, 296)
	_dim.size = Vector2(1920, 1080) if full else Vector2(1523, 400)
	for gl in _dim.get_children():
		gl.visible = discard
	# tutoriel (tut_11..20) : ni voile noir general ni plaque de phase ; decor de l'intro, voile du carrousel seulement quand le choix du boss est a l'ecran
	var intro: bool = full and bool(_tg("intro_blank", null, false))
	_intro_field.visible = intro
	_dim_all.visible = intro and boss_pick
	if intro:
		_dim.visible = false
	phase_banner.visible = not over and not discard and not intro
	phase_banner.modulate.a = 0.25 if full and not intro else 1.0
	top_menu_btn.modulate = Color(0.3, 0.3, 0.3, 1.0) if intro and boss_pick else Color(1, 1, 1, 0.25 if full and not intro else 1.0) # tut_16 : l'engrenage est a 0,30 de sa luminosite (77 / 255)
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
		_carousel_text.position = Vector2(356, 125) # calé sur tut_16 : texte « YOU ARE » a x 665, y 134 (centre 960 : RandomBossSelectionScene.cs:76)
		_carousel_text.size = Vector2(1200, 90)
		_set_carousel_text("YOU ARE [color=#f0c040]%s[/color]" % (_boss_name if _boss_ready else "..."), 42) # RandomBossSelectionScene.cs:76 : bg_txt (960 ; 150) echelle 2 = arcadepix 21 x 2 (mesure tut_16)
	elif discard:
		_set_carousel_text("SELECT [color=#f0c040]2[/color] CARDS TO DISCARD", 21)
		_carousel_text.position = Vector2(STACK_CX + 2 - 465, 204) # APK : texte centre en x 962, y 215
		_carousel_text.size = Vector2(931, 50)

## CONTINUE de la defausse d'ouverture : le losange de l'APK (continue_button, libelle compris, x 1540 y 410) ; PLAY BOSS MONSTER! reste la pierre.
func _style_confirm(diamond: bool, btn: Button = null) -> void:
	if btn == null:
		btn = _confirm_btn
	btn.clip_text = diamond # le libelle (invisible) ne doit pas elargir le losange
	if diamond:
		for n in ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed"]:
			var sb := StyleBoxTexture.new()
			sb.texture = _tex(UI_DIR + ("continue_button_pressed.webp" if n in ["pressed", "hover_pressed"] else "continue_button.webp"))
			if n == "hover":
				sb.modulate_color = Color(1.2, 1.15, 1.0)
			btn.add_theme_stylebox_override(n, sb)
		for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
			btn.add_theme_color_override(c, Color(0, 0, 0, 0)) # le libelle est dans l'image
		btn.custom_minimum_size = Vector2(131, 173)
		btn.size = Vector2(131, 173)
		btn.position = Vector2(1540, 410)
	else:
		for n in ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed"]:
			btn.remove_theme_stylebox_override(n)
		for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
			btn.remove_theme_color_override(c)

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

## Boss.PlayerId (GameBoardExtensions.cs:86-89) : rang XP decroissant fixe a la mise en place, 1..N, ne change plus ensuite.
func _player_order(pid: int) -> int:
	if _order_cache.is_empty():
		var G: Dictionary = game_manager.G
		var xo: Array = G.get("xpOrder", [])
		if xo.size() != (G.get("players", {}) as Dictionary).size() or str(G.get("phase", "")) == "boss":
			return pid + 1
		for k in xo.size():
			_order_cache[int(xo[k])] = k + 1
	return int(_order_cache.get(pid, pid + 1))

func _refresh_lane_badges(idx: int, pl: Dictionary) -> void:
	var L: Dictionary = _lane[idx]
	var boss = pl.get("boss")
	(L["dmg"] as Label).text = str(_get_total_dungeon_damage(pl))
	var xp_n := int((boss as Dictionary).get("xp", 0)) if boss != null else 0
	(L["xp"] as Label).text = "%dXP" % xp_n
	var xp_digits := str(xp_n)
	(L["xp_unit"] as Label).position.x = (L["xp"] as Label).position.x + _fb.get_string_size(xp_digits, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
	(L["xp_unit"] as Label).text = "XP"
	(L["lvl"] as Label).text = str(_player_order(int(pl.get("id", 0)))) # BossXPAndOrderControl.cs:109 : Boss.PlayerId
	var tr: Array = (boss as Dictionary).get("treasures", []) if boss != null else []
	(L["icon"] as TextureRect).texture = _tex(str(TREASURE_TEX.get(int(tr[0]) if not tr.is_empty() else 0, "")))

## Un boss vient de monter de niveau (leveledUp passe a vrai) : banniere LEVEL UP dans son couloir. Le premier refresh ne fait que memoriser.
func _track_levelup(G: Dictionary) -> void:
	for pid in (G.get("players", {}) as Dictionary):
		var pl: Dictionary = G["players"][pid]
		var now := bool(pl.get("leveledUp", false))
		if _lvl_seen.has(pid) and now and not bool(_lvl_seen[pid]) and not skip_animations and pl.get("boss") != null:
			if not _tg("levelup"):
				continue # tutoriel : la banniere attend les consignes (ne pas marquer « vu »)
			_show_levelup(int(pid), pl["boss"])
		_lvl_seen[pid] = now

## LevelUpBanner de l'APK (DungeonFrameEntity.CreateLevelUpAnimationTask) : le portrait du boss (xxx_hr) entre par la droite du couloir
## avec la plaque « <BOSS> HAS ACTIVATED / LEVEL UP!! » ; 0,5 s d'entree, 1 s d'arret, 0,5 s de sortie. Decoupe au couloir (couches
## DungeonTop / BottomScissor). Pied du portrait = LANE_Y + 446 (haut) / 456 (bas) (DungeonFrameEntity.cs:386, frame levelup_10 : bas 952), bord
## droit final 1708 (hors du decoupage a 1707), plaque x gauche final 985 ; ils arrivent de 895 px (X_DISPLACEMENT) a droite, plaque de 700 -> -740
## relatifs au portrait (LevelUpBanner.cs:35-37,150-165). Les 4 quarts de bg_lu_shine_cuarto (LevelUpBanner.cs:60-72) ne se voient sur aucune frame (levelup_09/10) : pas d'etoile.
func _show_levelup(pid: int, boss: Dictionary) -> void:
	var idx := 1 if pid == view_pid else (0 if pid == foe_pid else -1)
	if idx < 0:
		return
	AudioManager.play_sting("sting_levelup") # LevelUpBanner.cs:122 (PlayWithMusicFade) a l'entree de la banniere, DungeonFrameEntity.cs:478-487
	_lvl_busy = true
	var clip := Control.new()
	clip.name = "LevelUpBanner"
	clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip.clip_contents = true
	clip.position = Vector2(184, LANE_Y[idx])
	clip.size = Vector2(1523, LANE_H[idx])
	_ui_layer.add_child(clip)
	var bottom := float(LANE_Y[idx]) + (446.0 if idx == 0 else 456.0) - clip.position.y
	var bx := 1708.0 + 895.0 - clip.position.x # bord droit du portrait au depart (X_DISPLACEMENT = 895), repere du decoupage
	var tex := _tex("res://assets/ui/characters/%s_hr.webp" % str(boss.get("id", "")).to_lower())
	var boss_node: TextureRect = null
	if tex != null:
		boss_node = _img(clip, "", Vector2.ZERO, tex.get_size())
		boss_node.texture = tex
		boss_node.position = Vector2(bx - tex.get_size().x, bottom - tex.get_size().y) # bord droit a bx
	var panel := Control.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.size = Vector2(531, 136)
	clip.add_child(panel)
	UiKit.ninepatch(panel, "ninepatch/bg_levelup_banner.webp", Vector2.ZERO, Vector2(531, 136), Vector4(15, 17, 15, 15)) # reperes du WPK : etirement au pixel (17 ; 18), halo de 13 px autour du cadre (levelup_10 : plaque visible de 108 px)
	var nm := str(boss.get("name", "")).strip_edges().to_upper()
	# tailles / positions mesurees sur levelup_10 (nom 166 px de large, « HAS ACTIVATED » 190, « LEVEL UP!! » 327 ; texte a 27 px du bord de la plaque)
	var nl := _lbl(panel, nm, 23, APK_GOLD, Vector2(24, 26), 0.0, _fa)
	_lbl(panel, "HAS ACTIVATED", 19, APK_GOLD, Vector2(24 + _fa.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 23).x + 22.0, 32), 0.0, _fa)
	nl.name = "BossName"
	_lbl(panel, "LEVEL UP!!", 46, Color.WHITE, Vector2(25, 45), 0.0, _fa)
	if boss_node != null:
		clip.move_child(boss_node, -1) # le portrait recouvre la plaque (frames levelup_09/10)
	var p_in := 985.0 - clip.position.x
	var p_out := p_in + 2335.0 # 895 + 700 + 740 : de -740 a 700 relatifs au portrait, qui recule de 895
	panel.position = Vector2(p_out, bottom - 200.0)
	var tw := clip.create_tween().set_parallel(true)
	if boss_node != null:
		tw.tween_property(boss_node, "position:x", bx - 895.0 - tex.get_size().x, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(panel, "position:x", p_in, 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.chain().tween_interval(1.0)
	tw.chain().tween_property(panel, "position:x", p_out, 0.33).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	if boss_node != null:
		tw.tween_property(boss_node, "position:x", bx - tex.get_size().x, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
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
	var old_y := {} # id -> hauteurs d'avant (CreateReorderTask : les heros restants glissent a leur nouvelle place)
	for j in mini(_town_ids.size(), town_container.get_child_count()):
		var yl: Array = old_y.get(_town_ids[j], [])
		yl.append((town_container.get_child(j) as Control).position.y)
		old_y[_town_ids[j]] = yl
	var moved: Array = []
	for c in town_container.get_children():
		town_container.remove_child(c) # tout de suite : les zones de ciblage lisent les positions des nouvelles cartes
		c.queue_free()
	var pool := _town_ids.duplicate()
	var fresh := -1 # dernier heros arrive (absent de la ville precedente)
	var ids: Array = []
	for hi in range(town.size() - 1, -1, -1): # dernier arrive en haut, le plus ancien (le prochain attire) en bas (CreateReorderTask : y 120 pour le dernier de la liste, +230 par heros plus ancien)
		var hero: Dictionary = town[hi]
		var hero_card = _card_scene.instantiate()
		hero_card.default_size = Vector2(154, 215)
		town_container.add_child(hero_card)
		hero_card.is_in_hand = false
		hero_card.setup(hero)
		_item_tag(hero_card, hero)
		hero_card.long_pressed.connect(_zoom_show)
		hero_card.long_released.connect(func(_c): _zoom_close())
		ids.append(hero.get("id", hero))
		var ci := ids.size() - 1
		var k := pool.find(ids[ci])
		if k >= 0:
			pool.remove_at(k)
			var yl: Array = old_y.get(ids[ci], [])
			if not yl.is_empty():
				moved.append([hero_card, yl.pop_front()])
		else:
			fresh = ci
	_town_ids = ids
	if fresh >= 0 and not skip_animations:
		_play_sfx("ui_shuffle_left") # VerticalScrollQueueComponent.cs:194 : un heros s'ajoute a la file
	_town_restore(keep_sv, fresh, moved)

## Apres la mise en page des cartes : le defilement d'avant est restitue, et un heros qui vient d'arriver est amene a l'ecran
## (VerticalScrollQueueComponent.CreateShowBottomTask).
func _town_restore(sv: int, fresh: int, moved: Array = []) -> void:
	for i in 2:
		await get_tree().process_frame
	if not is_instance_valid(_town_scroll):
		return
	_town_scroll.scroll_vertical = sv
	# VerticalScrollQueueComponent.CreateReorderTask (cs:199-210) : Y local en 0,5 s x vitesse, CubicEase (= EaseOut), tous les heros en parallele
	if not skip_animations:
		for m in moved:
			if not is_instance_valid(m[0]):
				continue # la colonne a ete reconstruite entre-temps
			var hc := m[0] as Control
			if hc.is_inside_tree() and not is_equal_approx(hc.position.y, float(m[1])):
				var to_y := hc.position.y
				hc.position.y = float(m[1])
				hc.create_tween().tween_property(hc, "position:y", to_y, 0.5 * _speed_factor()).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
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
	var seq := 0 # rang de vol : les heros partent l'un apres l'autre (VerticalScrollQueueComponent.cs:229-263)
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
		var flying: bool = _bait_active()
		for k in range(ents.size() - 1, -1, -1): # la derniere d'abord : la premiere reste au premier plan
			var tok := _create_entrance_card(ents[k])
			tok.position = Vector2(-pitch * float(k), 0.0)
			var lane_i := int(r[0])
			tok.card_clicked.connect(func(_d): _queue_clicked(lane_i, ents))
			box.add_child(tok)
			toks[k] = tok
			if flying and _bait_landed.get(_bait_key(pid_key, ents[k], k), 0) != _bait_t0: # carte arrivee par le leurre : cachee jusqu'a l'arrivee de son double, qui vole depuis la ville (voir _fly_hero_card)
				tok.modulate.a = 0.0
				_fly_hero_card(pid_key, ents[k], k, tok, seq + k)
		_ent_tok[pid_key] = toks
		_fx_hero_entry(box, pid_key, ents, toks)
		seq += ents.size()

## Heros qui entre dans le donjon du joueur actif (AdventurePhase_b) : sa carte d'entree emet (HeroesQueueComponent.cs:105-107, 142-145 EmitParticles = true), jusqu'a
## son retrait de la file (ShiftAndRemoveFirstHero, :293-296). Ici : tant que l'aventure de ce joueur a un heros, sur sa carte d'entree. Emetteur 0,9 x la carte (CardEntity.cs:88-91),
## derriere les cartes ; il est un frere de `box` (les jetons sont reconstruits a chaque refresh, pas lui : les particules vivantes ne sautent pas).
func _fx_hero_entry(box: Control, pid: int, ents: Array, toks: Array) -> void:
	var adv: Dictionary = game_manager.G.get("adventure", {})
	var k := -1
	if not adv.is_empty() and adv.get("hero") != null and int(adv.get("playerId", -1)) == pid:
		for i in ents.size():
			if str((ents[i] as Dictionary).get("id", "")) == str((adv["hero"] as Dictionary).get("id", "")):
				k = i
				break
	var par := box.get_parent() as Control
	if k < 0 or k >= toks.size():
		var old := par.get_node_or_null("HeroFx") as ApkParticles
		if old != null:
			old.set_emit(false)
		return
	var fx := ApkParticles.sur(par, "HeroFx", box.position + (toks[k] as Control).position + HERO_CARD * 0.5, HERO_CARD * ApkParticles.ECHELLE, true, false) # (la taille d'un Card.tscn n'est definitive qu'une fois dans l'arbre : constante)
	if fx.get_index() > box.get_index():
		par.move_child(fx, box.get_index())

func _bait_active() -> bool:
	return _bait_t0 > 0 # _bait_end (tween de _bait_ms) le remet a 0 : pas d'horloge reelle, le tween suit delta plafonne (~0,13 s) comme les vols

func _bait_key(pid: int, hero: Dictionary, k: int) -> String:
	return "%d:%s:%d" % [pid, str(hero.get("id", "")), k]

## Double de la carte d'entree qui vole de la colonne HEROES IN TOWN jusqu'a sa place (un seul par heros et par leurre, meme si l'entree est
## reconstruite entre-temps) ; `order` = rang dans la file : chaque vol dure BAIT_FLY x vitesse et attend la fin du precedent.
func _fly_hero_card(pid: int, hero: Dictionary, k: int, tok: Control, order: int) -> void:
	var gk := _bait_key(pid, hero, k)
	if _bait_flown.get(gk, 0) == _bait_t0:
		return
	_bait_flown[gk] = _bait_t0
	var t0 := _bait_t0
	var ghost := _create_entrance_card(hero)
	ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ghost.visible = false
	hero_crossing_layer.add_child(ghost)
	ghost.global_position = Vector2(23.0, 107.0)
	var tw := ghost.create_tween()
	tw.tween_interval(BAIT_FLY * _speed * float(order))
	tw.tween_callback(func(): ghost.visible = true)
	# CubicEase sans mode = EaseOut (VerticalScrollQueueComponent.cs:262 ; EasingFunctionBase.cs:8)
	tw.tween_property(ghost, "global_position", tok.global_position, BAIT_FLY * _speed).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func():
		_bait_landed[gk] = t0
		var toks: Array = _ent_tok.get(pid, [])
		if t0 == _bait_t0 and k < toks.size() and is_instance_valid(toks[k]):
			(toks[k] as Control).modulate.a = 1.0
		ghost.queue_free())

func _create_entrance_card(hero: Dictionary) -> Control:
	var c = _card_scene.instantiate()
	c.default_size = HERO_CARD
	c.size = HERO_CARD
	c.is_in_hand = false
	c.setup(hero)
	if BossEngine.hero_hp(hero) > BossEngine.hero_base_hp(hero):
		c.add_heart(BossEngine.hero_hp(hero), true) # HeroCardEntity.cs:109 : PV gagnes (cardHeart, health_hero_buff_icon, chiffre or)
	_item_tag(c, hero)
	c.long_pressed.connect(_zoom_show)
	c.long_released.connect(func(_c): _zoom_close())
	return c

## Tools of Hero-Kind (case wiki) : le nom de l'Objet attache au heros, en bandeau au pied de sa carte.
func _item_tag(card: Control, hero: Dictionary) -> void:
	var it := ThkAbilities.item_of(hero)
	if it.is_empty():
		return
	var tag := Label.new()
	tag.text = "ITEM: " + str(it.get("name", "?")).to_upper()
	tag.add_theme_font_size_override("font_size", 13)
	tag.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	tag.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	tag.add_theme_constant_override("outline_size", 5)
	tag.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tag.size = Vector2(card.default_size.x if "default_size" in card else 154.0, 34.0)
	tag.position = Vector2(0.0, (card.default_size.y if "default_size" in card else 215.0) - 38.0)
	card.add_child(tag)

func _refresh_boss_platforms(p: Dictionary, foe: Dictionary) -> void:
	_set_boss(_lane[1], p.get("boss"), bool(p.get("eliminated", false)), bool(p.get("leveledUp", false)))
	_set_boss(_lane[0], foe.get("boss"), bool(foe.get("eliminated", false)), bool(foe.get("leveledUp", false)))

## dead : boss elimine (5 blessures) = pierre tombale RIP a la place du sprite (APK bosses_tombstone).
func _set_boss(L: Dictionary, boss, dead := false, lit := false) -> void:
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
	if dead and L.get("dead") == false and sprite.visible and sprite.texture != null and not skip_animations:
		# APK : la pierre tombale apparait en fondu pendant que le boss disparait, 0,5 s lineaire chacun (DungeonFrameEntity.cs:252,297-298,498-501)
		var ghost := TextureRect.new()
		ghost.texture = sprite.texture
		ghost.expand_mode = sprite.expand_mode
		ghost.stretch_mode = sprite.stretch_mode
		ghost.position = sprite.position
		ghost.size = sprite.size
		ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sprite.get_parent().add_child(ghost)
		sprite.get_parent().move_child(ghost, sprite.get_index())
		var gt := ghost.create_tween()
		gt.tween_property(ghost, "modulate:a", 0.0, 0.5)
		gt.tween_callback(ghost.queue_free)
		sprite.modulate.a = 0.0
		sprite.create_tween().tween_property(sprite, "modulate:a", 1.0, 0.5)
	elif not dead:
		sprite.modulate.a = 1.0
	L["dead"] = dead
	sprite.visible = tex != null
	if tex != null:
		sprite.texture = tex
		sprite.size = tex.get_size() * minf(BOSS_SPRITE_SCALE, BOSS_SPRITE_MAX_W / tex.get_size().x)
		sprite.position = Vector2((plat.size.x - sprite.size.x) / 2.0, plat.size.y - sprite.size.y)
		if dead:
			sprite.position.x = plat.size.x - sprite.size.x + 2.0 # APK : la pierre tombale est collee au bord droit du couloir (x ~1707)
	# Boss monte de niveau : <id>_character_glow derriere le sprite, meme centre (DungeonFrameEntity.cs:273-279,484 : FadeBehavior 0,5 s, ouvert par CreateLevelUpAnimationTask)
	var glow_tex: Texture2D = null
	if boss != null and lit and not dead and tex != null:
		glow_tex = _tex("res://assets/ui/characters/%s_character_glow.webp" % str(boss.get("id", "")).to_lower())
	var glow: TextureRect = L.get("glow")
	if glow == null and glow_tex != null:
		glow = TextureRect.new()
		glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		glow.stretch_mode = TextureRect.STRETCH_SCALE
		sprite.get_parent().add_child(glow)
		L["glow"] = glow
	if glow != null:
		sprite.get_parent().move_child(glow, sprite.get_index()) # DrawOrder 9E-05 contre 8E-05 pour le personnage : plus grand = derriere (DungeonFrameEntity.cs:257,273) ; halo plus large que le sprite
	if glow != null:
		var was: bool = glow.visible
		glow.visible = glow_tex != null
		if glow_tex != null:
			glow.texture = glow_tex
			glow.size = glow_tex.get_size() * (sprite.size.x / maxf(sprite.texture.get_size().x, 1.0))
			glow.position = sprite.position + sprite.size / 2.0 - glow.size / 2.0
			if not was and not skip_animations:
				glow.modulate.a = 0.0
				glow.create_tween().tween_property(glow, "modulate:a", 1.0, 0.5)
			elif not was:
				glow.modulate.a = 1.0

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
	var prev_frozen := _foe_frozen.duplicate()
	var holder: Control = _lane[0]["slots"]
	for c in holder.get_children():
		c.queue_free()
	_foe_slots.clear()

	var dungeon: Array = foe.get("dungeon", [])
	var off: int = maxi(0, CardDB.DUNGEON_SLOTS - dungeon.size())
	_foe_down.clear()
	_foe_frozen.clear()
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
				DungeonSlot.add_under_cards(slot_ctrl, dungeon[di], _card_scene, DungeonSlot.CARD_SIZE)
				var room_ui = _card_scene.instantiate()
				room_ui.default_size = DungeonSlot.CARD_SIZE
				room_ui.custom_minimum_size = DungeonSlot.CARD_SIZE
				room_ui.set_meta("fit", DungeonSlot.CARD_SIZE)
				slot_ctrl.add_child(room_ui)
				room_ui.position = (SLOT_SIZE - DungeonSlot.CARD_SIZE) / 2.0
				room_ui.is_in_hand = false
				room_ui.setup(r)
				room_ui.add_lane_badge()
				room_ui.mouse_filter = Control.MOUSE_FILTER_PASS
				room_ui.long_pressed.connect(_zoom_show)
				room_ui.long_released.connect(func(_c): _zoom_close())
				var fpid := foe_pid
				room_ui.card_clicked.connect(func(_d): _slot_zoom(fpid, di)) # clic sans appui long : zoom de la pile
				var fz: bool = BossEngine.is_room_deactivated(game_manager.G, foe_pid, di)
				var fk := "%d:%d" % [foe_pid, di] # par salle (indice du moteur), pas par noeud : les salles glissent d'un noeud a l'autre quand le donjon grandit
				room_ui.set_frozen(fz, fz != bool(prev_frozen.get(fk, false)) and not skip_animations)
				_foe_frozen[fk] = fz
				room_ui.set_face_down_scale()
				var fd: bool = room_ui.card_data != null and room_ui.card_data.face_down
				if not fd and not fz and str(r.get("type", "")) in ["monster", "trap"]:
					var fdmg := BossEngine.room_damage_with_modifiers(game_manager.G, foe, di, null)
					if fdmg != int(r.get("damage", 0)):
						room_ui.add_heart(fdmg) # CardStackSlotComponent.cs:148 : degats courants de la salle du dessus, en or, quand ils different de l'imprime
				if bool(prev_down.get(fk, false)) and not fd and not skip_animations:
					# revelation : la salle adverse se retourne. Si elle declenche « when you build... », la bulle ROOM ABILITY de l'adversaire s'affiche
					# (GamePlayBaseScene.cs:668 : Gameboard_AbilityApplyRequest pour toute capacite) et, sur les captures APK (notice_opponent_has_played_a_room_ability_*,
					# ability_opponent_dark_lab_*), la salle reste agrandie (0,5 : CardStackSlotComponent.cs:138-141, ScaleBehavior.MaxScale 0,5 CardsFactory.cs:101) pendant la bulle.
					var trigger: bool = str((r as Dictionary).get("description", "")).to_lower().begins_with("when you build")
					room_ui.flip_in(0.5, NOTICE_HOLD if trigger else 0.0)
					if trigger:
						_show_notice("ROOM ABILITY", r, {}, foe_pid)
				_foe_down[fk] = fd
				if Minibosses.active(game_manager.G): # Rise of the Minibosses : le miniboss de la salle adverse (nom cache tant qu'il est face cache)
					var mb_badge := Minibosses.make_badge(r, false)
					if mb_badge != null:
						slot_ctrl.add_child(mb_badge)
						slot_ctrl.tooltip_text = Minibosses.badge_tooltip(r, false)
		holder.add_child(slot_ctrl)
		DungeonSlot.fit_cards(slot_ctrl)
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
	var old_fan: Array = []
	if not skip_animations and not _fan_cards.is_empty():
		for oc in _fan_cards:
			if is_instance_valid(oc) and oc is CardUI and (oc as CardUI).card_data != null:
				old_fan.append({"id": (oc as CardUI).card_data.id, "pos": (oc as Control).position, "rot": (oc as Control).rotation_degrees})
	_fan_cards = []
	for c in hand_layer.get_children():
		c.queue_free()
	for e in _fx_hand.get_children(): # carte deselectionnee : Emit = false, les particules vivantes finissent (CardBorderBehavior.cs:42) ; la selection finie, les cartes partent avec leurs particules
		if _is_opening_discard_for_me():
			(e as ApkParticles).set_emit(false) # les cartes encore selectionnees le rallument plus bas (_fx_selected)
		else:
			e.queue_free()
	_boss_cards.clear()

	if boss_pick:
		_grey_prev.clear()
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
	var grey_next: Dictionary = {}
	var hide_idx := {} # cartes piochees encore en vol vers la main (_show_draw) : les derniers exemplaires de chaque id restent cachees
	if not _draw_hide.is_empty():
		var hide_left: Dictionary = _draw_hide.duplicate()
		for i in range(hand.size() - 1, -1, -1):
			var hid := str((hand[i] as Dictionary).get("id", ""))
			if int(hide_left.get(hid, 0)) > 0:
				hide_left[hid] = int(hide_left[hid]) - 1
				hide_idx[i] = hid
	for i in hand.size():
		var card_dict: Dictionary = hand[i]
		var card_ui = _spawn_card(card_dict, i, sz)
		if hide_idx.has(i):
			card_ui.visible = false
			card_ui.set_meta("draw_id", hide_idx[i])
		if discarding and card_ui.border != null:
			card_ui.border.visible = false # tut_26 : pas de filet gris autour des cartes du bandeau de defausse (cadre noir de la carte seul)
		var idx := i
		card_ui.card_clicked.connect(func(_data): _on_hand_card_clicked(idx, card_dict))
		card_ui.press_started.connect(_on_hand_press)
		card_ui.card_hovered.connect(func(_d, on: bool): _hand_hover(idx, on))
		card_ui.long_pressed.connect(_zoom_show)
		card_ui.long_released.connect(func(_c): _zoom_close())
		# APK : carte injouable = grisee (toute la main pendant l'aventure sans sort jouable) ; fondu 0,5 s a chaque changement d'etat (CardAttributesComponent.cs:73-90)
		var grey_now: bool = not discard_pick.has(idx) and not discarding and (phase == "build" or phase == "setup" or phase == "adventure" or G.get("gameOver") != null) and not playable.has(i) # fin de partie : plus rien de jouable, main grisee sous le voile (APK : etat du dernier RefreshCardsStatus, CardAttributesComponent.cs:92-96)
		var gk := "%d:%s" % [i, str(card_dict.get("id", ""))]
		var pv: Dictionary = _grey_prev.get(gk, {"g": grey_now, "t": -100000})
		if bool(pv["g"]) != grey_now:
			pv = {"g": grey_now, "t": Time.get_ticks_msec()}
		grey_next[gk] = pv
		var age := float(Time.get_ticks_msec() - int(pv["t"])) / 1000.0
		if age < 0.5 and not skip_animations:
			card_ui.set_greyed(not grey_now)
			card_ui.set_greyed(grey_now, true, age)
		elif grey_now:
			card_ui.set_greyed(true)
		if discard_pick.has(idx):
			card_ui.modulate = Color.WHITE # tut_26 (mesure Pillow : art de Zombie Attack 152,138,155 des deux cotes) : la carte choisie garde sa luminosite native, le voile ne couvre que les autres
			var glow := card_ui.get_node_or_null("GlowRect")
			if glow != null:
				glow.visible = true
				var gm_ := 20.0 * sz.x / 350.0 # card_border_yellow_glow 390 x 528 pour une carte 350 x 488 : 20 px de halo de chaque cote (CardBorderBehavior.cs:48-50 ; tut_26 : cadre or + halo)
				glow.offset_left = -gm_
				glow.offset_top = -gm_
				glow.offset_right = gm_
				glow.offset_bottom = gm_
		elif not grey_now and not discarding and (phase == "adventure" or not (G.get("stack", []) as Array).is_empty()) and bool(card_dict.get("isSpell", false)):
			card_ui.set_gold(true) # APK : sort jouable pendant l'aventure ou une pile de sorts = cadre dore
		cards.append(card_ui)
	_grey_prev = grey_next
	if discarding:
		_place_cards(cards, sz, 125.0, 1000.0, DISCARD_TOP, DISCARD_CX)
		for i in cards.size():
			if discard_pick.has(i):
				_fx_selected(i, cards[i] as Control)
	else:
		_place_fan(cards, sz, old_fan)

## Carte choisie dans le selecteur (defausse d'ouverture) : bordure YellowGlow (CardSelectorComponent.cs:137) = particules (CardBorderBehavior.cs:48-50 Emit = true).
## Emetteur 0,9 x la carte (CardEntity.cs:88-91, ParticlesParentSizeBehavior), derriere elle ; il survit a la reconstruction de la main.
func _fx_selected(i: int, card: Control) -> void:
	var r := card.get_global_rect()
	ApkParticles.sur(_fx_hand, "sel%d" % i, r.get_center() - _fx_hand.global_position, r.size * ApkParticles.ECHELLE, true, false)

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
	var forced := str(_tg("boss", cands, "")) # tutoriel : le carrousel s'arrete sur King Croak (GamePlayTutScene.cs:115)
	if forced != "" and cands.has(forced):
		_boss_pick_id = forced
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
		_play_sfx("ui_card_slide_down") # CarrouselComponent.FlipAllCards(false) -> FlipCardBehavior.cs:126 (une fois : l'APK le joue pour chaque carte, a l'identique)
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
		_play_sfx("ui_shuffle_left") # CarrouselComponent.cs:125-127 : l'indice grandit a chaque cran
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
	if animate:
		_play_sfx("ui_card_slide_up") # RandomBossSelectionScene.cs:128 -> FlipCardBehavior.cs:113
	_boss_name = str(boss.get("name", "")).to_upper()
	_boss_ready = true
	# RandomBossSelectionScene.cs:128-134 : la voix part une fois la carte retournee (0,5 s) ; CardAssetService.GetBossIntroSound (:246-258, BossInfo.IsMale)
	var intro_voice := AudioManager.boss_voice(_boss_pick_id, "intro")
	if animate:
		var gen0 := _boss_gen
		get_tree().create_timer(BOSS_FLIP_TIME).timeout.connect(func():
			if gen0 == _boss_gen:
				_play_sfx(intro_voice))
	else:
		_play_sfx(intro_voice)
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

## Le boss tire est le notre : le coup part (PLAY BOSS MONSTER! en solo, minuterie en ligne). Pas avant la fin de la rotation.
func _boss_confirm() -> void:
	if not _boss_ready:
		return
	_boss_ready = false # un seul appui / une seule minuterie compte
	_do({"type": "pickBoss", "args": [_boss_pick_id]})

func _input(event: InputEvent) -> void:
	if not _tg("input", event):
		return # tutoriel : une scene est affichee, le tap lui appartient (il ne doit ni fermer le zoom ni armer un glisser)
	_warn_outside(event)
	# Un nouvel appui gauche alors qu'un appui est encore arme : le relachement precedent s'est perdu (hors canvas / fenetre).
	if not _press.is_empty() and _drag.is_empty() and event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		_press = {}
		_press_recheck.call_deferred() # apres _gui_input : si ce nouvel appui est sur une carte de la main, _on_hand_press a rearme _press
	if _slide != null and is_instance_valid(_slide) and event is InputEventMouseButton and (event as InputEventMouseButton).pressed \
			and not SLIDE_RECT.has_point((event as InputEventMouseButton).position) and not _slide_keep.has_point((event as InputEventMouseButton).position):
		_slide_hide() # TouchOutBehavior : un appui hors du bandeau (et hors du bouton qui l'a ouvert, qui le referme lui-meme) le ferme
	var ab = (_zoom.get_meta("ability") if _zoom != null and _zoom.has_meta("ability") else null) # zoom d'une salle activable : un appui sur la bordure de capacite resout
	var hit := false
	if ab != null and event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		var host: Control = ab["host"]
		hit = host.visible and (host == _zoom or host.modulate.a > 0.9) and (ab["rect"] as Rect2).has_point(host.get_global_transform().affine_inverse() * (event as InputEventMouseButton).position)
	if not hit and _zoom != null and _zoom.has_meta("stack") and _zoom_stack_input(event):
		get_viewport().set_input_as_handled()
		return
	if _zoom != null and event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		_zoom_close() # le zoom de LEVEL UP part au clic suivant (le zoom d'appui long se ferme deja au relachement)
		if hit:
			get_viewport().set_input_as_handled() # le clic ne doit pas retomber sur l'emplacement dessous
			_resolve_slot_ability(int(ab["di"]), ab["cands"])
	if not _press.is_empty() or not _drag.is_empty():
		_drag_input(event)
	_town_input(event)

## Aligne les cartes (chevauchement si necessaire) autour de cx, sur une ligne (ecran de defausse d'ouverture).
func _place_cards(cards: Array, sz: Vector2, step_max: float, span_max: float, top_y: float, cx: float = PLAY_CX) -> void:
	var n := cards.size()
	if n == 0:
		return
	var step := step_max if n == 1 else minf(step_max, (span_max - sz.x) / float(n - 1))
	var x0 := cx - (step * (n - 1) + sz.x) / 2.0
	for i in n:
		(cards[i] as Control).position = Vector2(x0 + step * i, top_y)

## Main en eventail : transcription de CardPositionComponent de l'APK (HandEntity : RotationMax 9 deg, MaxDistanceBtwCards 250,
## DistanceUnselectedFactor 0,8, ArcHeight -30) ; centres des cartes, repere ecran 1920x1080. La carte survolee monte en entier,
## se redresse et passe au premier plan (z_index de CardUI).
func _place_fan(cards: Array, sz: Vector2, old: Array = []) -> void:
	_fan_cards = cards
	_fan_sz = sz
	var used := {}
	for i in cards.size():
		var c: Control = cards[i]
		(c as CardUI).hover_scale = 1.0 # l'APK ne grossit pas la carte touchee : elle monte seulement
		var t := _fan_target(i, cards.size(), -1)
		c.position = t[0]
		c.rotation_degrees = t[1]
		for k in old.size(): # CardMoveBehavior : les cartes qui restent glissent de leur ancienne place a la nouvelle (la main est reconstruite a chaque rafraichissement)
			if not used.has(k) and old[k]["id"] == (c as CardUI).card_data.id:
				used[k] = true
				c.position = old[k]["pos"]
				c.rotation_degrees = old[k]["rot"]
				CardUI.lerp_vers(c, "position", t[0])
				CardUI.lerp_vers(c, "rotation_degrees", t[1])
				break

## Position et rotation (degres) de la carte i de la main selon la carte selectionnee `sel` (-1 = aucune) : CardPositionComponent.PositionX / Rotation (cs).
## La selectionnee monte en entier et se redresse ; les autres s'ecartent d'elle (n + 1 places) et ses voisines se redressent aussi.
func _fan_target(i: int, n: int, sel: int) -> Array:
	var slots := float(n) if sel < 0 or sel == i else float(n + 1)
	var k := i + 1 if sel >= 0 and i > sel else i
	var half := minf(float(n - n % 2) * 250.0 * (0.8 if sel < 0 else 1.0), 1200.0) * 0.5 # largeur utile : 1200 = 900 (HandEntity) x 1920/1440
	var cx := HAND_CX + lerpf(-half, half, float(k + 1) / (slots + 1.0))
	var cy := HAND_CY - 30.0 * sin(PI / float(n) * (float(i) + 0.5))
	var rot_inc := 9.0 * clampf(float(n) / 11.2, 0.0, 1.0) / float(n) # 11,2 = 1,4 x 8 cartes visibles (900 / 125)
	var rot := rot_inc * (float(i) - (float(sel) if sel > 1 else float(n) * 0.5))
	if sel >= 0 and absi(i - sel) <= 1:
		rot = 0.0
	var pos := Vector2(cx, cy) - _fan_sz / 2.0
	if i == sel:
		pos.y = 1080.0 - _fan_sz.y - 4.0 # carte entierement visible
	return [pos, rot]

## CardHoverBehavior -> CardPositionComponent.Refresh : toute la main se replace autour de la carte survolee.
func _fan_apply(sel: int) -> void:
	for i in _fan_cards.size():
		var c = _fan_cards[i]
		if is_instance_valid(c):
			var t := _fan_target(i, _fan_cards.size(), sel)
			CardUI.lerp_vers(c, "position", t[0])
			CardUI.lerp_vers(c, "rotation_degrees", t[1])

func _refresh_phase_banner(phase: String) -> void:
	if phase == _last_phase:
		return
	var prev := _last_phase
	_last_phase = phase
	var key := "build" if (phase == "setup" or phase == "boss") else phase
	if prev == "boss" and phase != "boss" and not skip_animations:
		_fade_in_lanes() # fin du choix du boss : les donjons apparaissent en fondu
		_deal_pending = true # puis la main d'ouverture est distribuee
	# APK : entre la revelation des salles et l'aventure, la plaque BAIT PHASE s'affiche pendant que les heros de la ville volent vers les
	# donjons (leurre), l'un apres l'autre. Le moteur n'a pas cette phase : l'interface montre la plaque et les vols, sans retarder la partie.
	var bait_n := 0
	if key == "adventure" and prev == "build" and not skip_animations:
		for q in [view_pid, foe_pid]:
			if int(q) >= 0:
				bait_n += ((game_manager.G.get("players", {}) as Dictionary).get(int(q), {}) as Dictionary).get("entrance", []).size()
	if bait_n > 0:
		_bait_t0 = Time.get_ticks_msec()
		_bait_ms = int(float(bait_n) * BAIT_FLY * _speed * 1000.0)
		key = "bait"
	if PHASE_BANNERS.has(key):
		_set_phase_banner(_tex(PHASE_BANNERS[key]))
	if bait_n > 0:
		var tw := create_tween()
		tw.tween_interval(float(_bait_ms) / 1000.0)
		tw.tween_callback(_bait_end)

func _bait_end() -> void:
	_bait_t0 = 0
	if _last_phase == "adventure":
		_set_phase_banner(_tex(PHASE_BANNERS["adventure"]))
	for k in _ent_tok:
		for t in (_ent_tok[k] as Array):
			if t != null and is_instance_valid(t):
				(t as Control).modulate.a = 1.0

## PhaseTitleControl.Refresh (PhaseTitleControl.cs:80-96) : la plaque precedente saute hors de l'ecran, la nouvelle entre en sautant.
func _set_phase_banner(tex: Texture2D) -> void:
	if tex == phase_banner.texture:
		return
	if _phase_tw != null:
		_phase_tw.kill()
	if skip_animations:
		phase_banner.position.y = PHASE_BANNER_Y
		phase_banner.texture = tex
		return
	_phase_tw = create_tween()
	if phase_banner.texture != null:
		_phase_tw.tween_method(_phase_jump, 1.0, 0.0, 0.5) # JumpBehavior.cs:57 : 0,5 s
	else:
		_phase_jump(0.0) # InitHide (PhaseTitleControl.cs:40) : la plaque entre depuis le haut
	_phase_tw.tween_callback(func(): phase_banner.texture = tex)
	_phase_tw.tween_method(_phase_jump, 0.0, 1.0, 0.5)

## JumpBehavior.Update (JumpBehavior.cs:12,58-62,75-79) : decalage = Lerp(300, 0, BackEase(montee)) vers le haut (DirectionUp), BackEase amplitude 0,4 en EaseOut
## (EasingFunctionBase.cs:8,24 ; BackEase.cs:21-22 : EaseIn(t) = t^3 - 0,4 t sin(pi t), EaseOut(t) = 1 - EaseIn(1 - t)).
func _phase_jump(a: float) -> void:
	var u := 1.0 - a
	phase_banner.position.y = PHASE_BANNER_Y - 300.0 * (u * u * u - 0.4 * u * sin(PI * u))

## DungeonFrameEntity.cs:236 (Opacity 0 + FadeBehavior 0,5 s) ; GamePlayBaseScene.cs:570 puis GamePlaySPScene.cs:69 : mon donjon d'abord, puis celui du haut, 0,5 s chacun.
func _fade_in_lanes() -> void:
	for i in [1, 0]:
		var root: Control = (_lane[i] as Dictionary)["root"]
		root.modulate.a = 0.0
		var tw := root.create_tween()
		tw.tween_interval(0.5 * float(1 - i))
		tw.tween_property(root, "modulate:a", 1.0, 0.5)

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

## Les icones apparues depuis le dernier rafraichissement (from -> to) apparaissent en fondu lineaire de 0,5 s sur l'icone vide
## (IconCounterControlEntity.cs:134,173 : FadeBehavior 0,5 s ; l'icone « allumee » fond par-dessus l'icone vide).
func _flash_icons(box: Container, from: int, to: int, off_path: String) -> void:
	if from < 0 or to <= from:
		return
	var live := box.get_children().filter(func(c): return not c.is_queued_for_deletion()) # _icon_row vient de vider la rangee (queue_free)
	for i in range(from, mini(to, live.size())):
		var ic := live[i] as TextureRect
		var fill := TextureRect.new()
		fill.texture = ic.texture
		fill.expand_mode = ic.expand_mode
		fill.stretch_mode = ic.stretch_mode
		fill.set_anchors_preset(Control.PRESET_FULL_RECT)
		fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ic.texture = _tex(off_path)
		ic.add_child(fill)
		var tw := fill.create_tween()
		tw.tween_property(fill, "modulate:a", 1.0, 0.5).from(0.0)
		tw.tween_callback(func():
			if is_instance_valid(ic):
				ic.texture = fill.texture
			fill.queue_free())

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
	var blank: bool = bool(_tg("intro_blank", null, false)) # tutoriel, intro (tut_11..20) : pas de noms de boss ni de pioches, le plateau n'est pas encore distribue
	sidebar_boss_label.text = str(pb.get("name", "")).to_upper() if pb != null and not blank else ""
	_fit_label(sidebar_boss_label, 150.0, 18)
	sidebar_sub_label.text = str(pb.get("subtitle", "")) if pb != null and not blank else ""
	var n_souls: int = CardDB.total_souls(p, game_manager.G)
	var n_wounds: int = CardDB.total_wounds(p)
	_icon_row(souls_container, 10, n_souls, TEX_SOUL, TEX_SOUL_EMPTY, Vector2(19, 26))
	_icon_row(wounds_container, 5, n_wounds, TEX_WOUND, TEX_WOUND_EMPTY, Vector2(21, 27))
	if not skip_animations: # APK : le cristal / la goutte gagnes s'allument
		_flash_icons(souls_container, _souls_seen, mini(n_souls, 10), TEX_SOUL_EMPTY)
		_flash_icons(wounds_container, _wounds_seen, mini(n_wounds, 5), TEX_WOUND_EMPTY)
	_souls_seen = n_souls
	_wounds_seen = n_wounds
	_fill_treasures(treasures_container, BossEngine.treasure_counts(p, game_manager.G),
		[[3, Vector2(0, 0)], [4, Vector2(0, 54)], [2, Vector2(0, 101)], [1, Vector2(0, 153)], [5, Vector2(0, 200)]], 30.0)

	# Boss adverse
	var fb = foe.get("boss")
	foe_name_label.text = str(fb.get("name", "")).to_upper() if fb != null and not blank else ""
	_fit_label(foe_name_label, 150.0, 18)
	foe_sub_label.text = str(fb.get("subtitle", "")) if fb != null and not blank else ""
	foe_wounds_label.text = "x%d" % CardDB.total_wounds(foe)
	foe_souls_label.text = "x%d" % CardDB.total_souls(foe, game_manager.G)
	_fill_treasures(foe_treasures_box, BossEngine.treasure_counts(foe, game_manager.G),
		[[4, Vector2(8, 6)], [3, Vector2(106, 6)], [2, Vector2(6, 38)], [1, Vector2(106, 38)], [5, Vector2(40, 8)]], 22.0)

	# Pioches
	var decks: Dictionary = G.get("decks", {})
	room_deck_label.text = "x0" if blank else "x%d" % (foe.get("hand", []) as Array).filter(func(c): return bool((c as Dictionary).get("isRoom", false))).size() # OneOpponentDetail.cs:212 : RoomsInHand / SpellsInHand de l'adversaire
	spell_deck_label.text = "x0" if blank else "x%d" % (foe.get("hand", []) as Array).filter(func(c): return not bool((c as Dictionary).get("isRoom", false))).size()
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
		if not (killed and int(lhf.get("deathIndex", -1)) >= 0):
			_play_sfx("char_hero_intro") # GamePlayBaseScene.cs:932-934 : le heros entre dans le donjon
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
		if slot_idx + vis_off < slots_list.size():
			var target_slot: Control = slots_list[slot_idx + vis_off]
			var target_pos := target_slot.global_position + HERO_IN_SLOT

			# MoveHeroToSlot : la salle visitee grossit (et l'ancienne reprend sa taille) pendant la marche (HeroCrossingBehavior.cs:56-63)
			tw.tween_callback(func():
				_play_sfx("char_hero_move") # HeroCrossingBehavior.cs:70 : debut du pas (la position change)
				_set_focus(pid, slot_idx))
			# 1,0 x vitesse, CubicEase sans mode = EaseOut (HeroCrossingBehavior.cs:24,67-68 ; EasingFunctionBase.cs:8) ; aucune pause ensuite (HeroCardEntity.cs:105 : RefreshHeroHeart ne bloque pas, WaitAny)
			tw.tween_property(pawn, "global_position", target_pos, 1.0 * _speed).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

			tw.tween_callback(func():
				_hero_arrive(pid, slot_idx)
				if dmg > 0:
					_play_sfx("char_hero_hurt") # HeartDecrementEmitter.cs:70
				_show_floating_dmg(pawn, dmg)
			)
			current_hp -= dmg

	if killed:
		# JumpAndFade (HeroCrossingBehavior.cs:91-103) : l'ordonnee locale du personnage passe de -40 (HeroCardEntity.cs:55) a -200 puis +400 ; x l'echelle de la carte (HERO_CARD.x / 350) = pixels
		var ky := HERO_CARD.x / 350.0
		tw.tween_callback(func(): _play_sfx("char_hero_death")) # HeroCrossingBehavior.cs:98
		tw.tween_property(pawn, "position:y", pawn.position.y + (-200.0 + 40.0) * ky, 0.5 * _speed).set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_OUT) # HeroCrossingBehavior.cs:93,95-98
		tw.tween_callback(func(): _set_focus(pid, -1)) # ScaleOutAllSlotsTopRoom, en meme temps que la chute (HeroCrossingBehavior.cs:99)
		tw.tween_property(pawn, "modulate:a", 0.0, 0.7 * _speed) # fondu lineaire (HeroCrossingBehavior.cs:94,99)
		tw.parallel().tween_property(pawn, "position:y", pawn.position.y + (400.0 + 40.0) * ky, 0.7 * _speed).set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_IN) # HeroCrossingBehavior.cs:99-102
		tw.tween_callback(func():
			pawn.queue_free()
			_animating_hero = false
			refresh()
		)
	else:
		var boss_pos := boss_platform.global_position + Vector2(25, 25)
		# MoveToBossAndFade (HeroCrossingBehavior.cs:106-118) : 0,5 x vitesse, X en CubicEase EaseOut et Y en EaseIn (:111-116), les salles reprennent leur taille en meme temps (:111), puis fondu 0,5 x vitesse (:117)
		tw.tween_callback(func():
			_set_focus(pid, -1)
			_play_sfx("char_hero_move")) # HeroCrossingBehavior.cs:111
		tw.tween_property(pawn, "global_position:x", boss_pos.x, 0.5 * _speed).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(pawn, "global_position:y", boss_pos.y, 0.5 * _speed).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		tw.tween_callback(func(): _play_sfx("char_hero_attack")) # HeroCrossingBehavior.cs:117
		tw.tween_property(pawn, "modulate:a", 0.0, 0.5 * _speed)
		tw.tween_callback(func():
			# CreateBossHitAnimationTask (DungeonFrameEntity.cs:489-496) : apres le fondu du heros, calque additif + secousse + son
			_boss_hit(boss_sprite)
			var boss_dict: Dictionary = (game_manager.G.get("players", {}) as Dictionary).get(pid, {}).get("boss", {})
			_play_sfx(AudioManager.boss_voice(str(boss_dict.get("id", "")), "hurt")) # DungeonFrameEntity.cs:494,503-510 (CardAssetService.cs:260-272)
			_show_floating_dmg(boss_platform, 1, Color(1, 0.3, 0.3))
		)
		var pl_dict: Dictionary = (game_manager.G.get("players", {}) as Dictionary).get(pid, {})
		if bool(pl_dict.get("eliminated", false)): # DungeonFrameEntity.cs:495,512-519 : boss mort, la voix de mort part apres la secousse (0,44 s), avec la pierre tombale
			var pl_boss = pl_dict.get("boss")
			var dead_voice := AudioManager.boss_voice(str((pl_boss as Dictionary).get("id", "")) if pl_boss != null else "", "death")
			tw.tween_interval(10.0 * PI / 72.0)
			tw.tween_callback(func(): _play_sfx(dead_voice))
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
	tw.tween_callback(func():
		if to_room < 0:
			_play_sfx("char_hero_intro") # GamePlayBaseScene.cs:932-934 : le heros entre dans le donjon, il ne marche pas encore
		elif to_room != from_room:
			_play_sfx("char_hero_move") # HeroCrossingBehavior.cs:70 : debut du pas (la position change)
		_set_focus(pid, to_room)) # APK : la salle ou entre le heros grossit pendant la marche (HeroCrossingBehavior.cs:56-63)
	# 1,0 x vitesse, CubicEase sans mode = EaseOut (HeroCrossingBehavior.cs:24,67-68 ; EasingFunctionBase.cs:8) ; aucune pause ensuite (HeroCardEntity.cs:105 : RefreshHeroHeart ne bloque pas, WaitAny)
	tw.tween_property(pawn, "global_position", target, 1.0 * _speed).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func():
		var room_ctrl: Control = _slot_at(pid, to_room) # les emplacements adverses sont reconstruits a chaque refresh : on ne garde pas de reference
		if to_room >= 0 and to_room != from_room:
			_hero_arrive(pid, to_room) # a chaque arrivee, degats ou non (HeroCrossingBehavior.cs:72-76)
		if to_room >= 0 and dmg != 0:
			_play_sfx("char_hero_hurt" if dmg > 0 else "sfx_spell_buff") # HeartDecrementEmitter.cs:64-70 : PV perdus / rendus a un heros dans le donjon
		if dmg > 0 and room_ctrl != null:
			_show_floating_dmg(pawn, dmg)
			var badge: Label = (_lane[lane_idx] as Dictionary)["dmg"]
			badge.modulate.a = 0.0 # UpdatableTextBlock : le nouveau compteur apparait en fondu lineaire de 0,25 s (UpdatableTextBlock.cs:24,43)
			badge.create_tween().tween_property(badge, "modulate:a", 1.0, 0.25)
		if is_instance_valid(hp_lbl):
			hp_lbl.text = str(maxi(hp_after, 0)))
	tw.tween_callback(func():
		_animating_hero = false
		refresh())

## Arrivee du heros sur une salle (HeroCrossingBehavior.cs:72-76) : char_hero_move puis le son de la categorie de la salle (CardAssetService.GetRoomSound, :328-360), a chaque salle.
func _hero_arrive(pid: int, room: int) -> void:
	_play_sfx("char_hero_move")
	var dgn: Array = ((game_manager.G.get("players", {}) as Dictionary).get(pid, {}) as Dictionary).get("dungeon", [])
	var rd = BossEngine.active_room(dgn[room]) if room >= 0 and room < dgn.size() else null
	_play_sfx(AudioManager.room_sfx(str((rd as Dictionary).get("id", "")) if rd != null else ""))

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
				var tw := c.create_tween() # ScaleEffectBehavior de la carte : 0,3 s (CardEntity.cs:71), sans EasingFunction donc lineaire (ScaleEffectBehavior.cs:57-60)
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

## ShakeBehavior (ShakeBehavior.cs:11,33-34,49-60,63,77) : x = sin(72 rad/s * t) * amplitude, amplitude 20 px diminuee de 2 a chaque demi-periode, fin a 0 : 10 demi-periodes ~0,44 s.
func _shake_node(node: Control) -> void:
	if node == null:
		return
	var half := PI / 72.0
	var tw := create_tween()
	tw.tween_method(_shake_step.bind(node, node.position.x), 0.0, 10.0 * half, 10.0 * half)
	tw.tween_callback(_shake_step.bind(10.0 * half, node, node.position.x))

func _shake_step(t: float, node: Control, orig_x: float) -> void:
	if is_instance_valid(node):
		node.position.x = orig_x + sin(t * 72.0) * maxf(20.0 - 2.0 * floorf(t / (PI / 72.0)), 0.0)

## CreateBossHitAnimationTask (DungeonFrameEntity.cs:489-496) : calque additif du sprite du boss (opacite 1, :493) qui s'efface en 0,25 s lineaire (:284) pendant la secousse.
func _boss_hit(sprite: Control) -> void:
	_shake_node(sprite)
	var tr := sprite as TextureRect
	if tr == null or tr.texture == null or not tr.visible:
		return
	var add := TextureRect.new()
	add.texture = tr.texture
	add.expand_mode = tr.expand_mode
	add.stretch_mode = tr.stretch_mode
	add.size = tr.size
	add.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	add.material = mat
	tr.add_child(add) # enfant du boss (BossCharacter.AddChild, DungeonFrameEntity.cs:285) : il suit la secousse
	var tw := add.create_tween()
	tw.tween_property(add, "modulate:a", 0.0, 0.25).from(1.0)
	tw.tween_callback(add.queue_free)

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

## Coups legaux de l'interface HUMAINE. APK : cartes et capacites ne sont jouables que si un heros est actif (IsAdventureInteractionTurn,
## CardManagerComponent.RefreshCardsStatus:162, HumanPlayerInteraction:140) ; l'IA, elle, joue ces fenetres via DoPlayerActions. `legal_moves`
## reste donc inchange (IA Godot, rejeu de l'oracle) et seule la vue du joueur filtre : cartes grisees, aucune fenetre, aucun clic d'activation.
const NO_HERO_BLOCKED := ["playSpell", "activateRoom", "useHandRoom", "docScarecrow", "payDarkHero", "payDarkCoins", "timebenderCancel", "antimagicCancel",
	"promoteMiniboss", "activateMiniboss", "discardForCoin", "rmbBoss", "rmbHand", "rmbPay", "rmbCancel", "useItem"]

func _my_moves(pid: int) -> Array:
	var moves: Array = game_manager.legal_moves(pid)
	if game_manager.apk_active_hero():
		return moves
	return moves.filter(func(m): return not (str((m as Dictionary).get("type", "")) in NO_HERO_BLOCKED))

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

## Selecteur de cartes de l'APK (CarouselSelectorEntity + CardSelectorComponent, comme « SELECT 2 CARDS TO DISCARD » et le choix de
## Draculord au niveau 2, frames levelup_14 / levelup_selected) : meme bandeau sombre (y 296..696, filets or), meme bulle top_globe, cartes
## BIG_CARD en eventail chevauche (pas 1002 / (n + 1), mesure levelup_14 : 167 pour 5 cartes) sans filet gris ; la carte touchee prend le halo
## dore (retoucher = deselectionner) et passe devant, CONTINUE = le losange continue_button (x 1540 y 410, CarouselSelectorEntity.cs:17-23) ;
## `skip_cb` valide = le choix peut etre refuse (canBeCanceled) : le bouton est alors present meme sans carte (SKIP, pierre), sinon il
## n'apparait qu'une fois une carte choisie (IsContinueButtonVisible). items : [{card: Dictionary, cb: Callable}].
func _popup_cards(kind: String, title: String, items: Array, skip_cb: Callable = Callable()) -> void:
	var pop := _popup_begin(kind, 0.0)
	_carousel_band(pop)
	_img(pop, UI_DIR + "top_globe.webp", Vector2(PLAY_CX - 440, 150)) # levelup_14 : bulle x 510..1430
	var fs := 26 if title.length() <= 44 else 21
	var wrapped := ""
	var line := ""
	for w in title.to_upper().split(" "): # coupe a la main : l'autowrap d'un Label ne coupe pas avec cette police bitmap
		var cand := w if line == "" else line + " " + w
		if line != "" and _fa.get_string_size(cand, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > 930.0:
			wrapped += line + "\n"
			cand = w
		line = cand
	var tl := _lbl(pop, wrapped + line, fs, Color.WHITE, Vector2(STACK_CX + 2 - 445, 156), 890.0, _fa, HORIZONTAL_ALIGNMENT_CENTER)
	tl.custom_minimum_size.y = 110.0
	tl.size.y = 110.0
	tl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var n := items.size()
	var sz := BIG_CARD
	var step := 0.0 if n < 2 else minf(1002.0 / float(n + 1), 250.0)
	var x0 := DISCARD_CX - (step * float(n - 1) + sz.x) / 2.0
	var st := {"sel": -1}
	var cards: Array = []
	var btn := Button.new()
	btn.name = "CardsContinue"
	var update := func():
		for k in cards.size():
			var on: bool = k == int(st["sel"])
			var cu: CardUI = cards[k]
			cu.z_index = 10 if on else 0
			if cu.glow_rect != null:
				cu.glow_rect.visible = on
		btn.visible = int(st["sel"]) >= 0 or skip_cb.is_valid()
		btn.text = "CONTINUE" if int(st["sel"]) >= 0 else "SKIP"
		_style_confirm(int(st["sel"]) >= 0, btn) # losange pour CONTINUE, pierre pour SKIP
		if int(st["sel"]) < 0:
			btn.custom_minimum_size = Vector2(220, 54)
			btn.size = Vector2(220, 54)
			btn.position = Vector2(PLAY_CX - 110, 730)
			btn.add_theme_font_size_override("font_size", 24)
	for i in n:
		var cu: CardUI = _card_scene.instantiate()
		cu.default_size = sz
		pop.add_child(cu)
		cu.size = sz
		cu.setup(items[i]["card"])
		cu.position = Vector2(x0 + step * float(i), DISCARD_TOP)
		if cu.border != null:
			cu.border.visible = false # comme la defausse d'ouverture (tut_26) : pas de filet gris autour des cartes du bandeau
		if cu.glow_rect != null:
			var gm_ := 20.0 * sz.x / 350.0 # halo card_border_yellow_glow : 20 px de chaque cote d'une carte 350 x 488
			cu.glow_rect.offset_left = -gm_
			cu.glow_rect.offset_top = -gm_
			cu.glow_rect.offset_right = gm_
			cu.glow_rect.offset_bottom = gm_
		cu.mouse_entered.disconnect(cu._on_mouse_entered) # pas de grossissement au survol : le halo dit « choisie »
		cu.mouse_exited.disconnect(cu._on_mouse_exited)
		var idx := i
		cu.card_clicked.connect(func(_d):
			if int(st["sel"]) >= 0:
				_play_sfx("ui_button_subselect") # CardSelectorComponent.cs:124,133 : la carte retiree de la selection
			if int(st["sel"]) != idx:
				_play_sfx("ui_button_select") # :135
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
	if td.has("stackId"): # cible sur la pile de sorts : la carte est encadree (SpellBattleHighLightsComponent.HighLightCards)
		return {"k": "stack", "id": str(td["stackId"])}
	for k in ["a", "soulIndex", "itemIndex", "woundIndex"]:
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
func _target_list(title: String, hint: String, entries: Array, cancel_cb: Callable, source := {}) -> void:
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
	_tgt = {"pid": _my_pid(), "title": title, "hint": hint if hint != "" else "Select a target", "entries": entries, "source": source}
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
			_fx_target(n as Control, false)
	_tgt_lifted.clear()
	_tgt_spots.clear()
	if _tgt_layer != null and is_instance_valid(_tgt_layer):
		remove_child(_tgt_layer)
		_tgt_layer.queue_free()
	_tgt_layer = null
	_tgt_cancel_btn = null
	_target_source_off()
	_tgt = {}
	for b in foe_bar.get_children() + opp_box.get_children():
		_foe_mark(b as Control, false)

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
			var i := kids.size() - 1 - int(spot["i"]) # la colonne est inversee (le plus ancien en bas)
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
		"stack":
			if _stack_ui != null and is_instance_valid(_stack_ui):
				for z in _stack_ui.get_children():
					if str(z.get_meta("stack_id", "")) == str(spot["id"]):
						return z as Control
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
			if n != _tgt_src:
				_fx_target(n as Control, false)
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
	_target_source_glow()
	for b in foe_bar.get_children() + opp_box.get_children(): # adversaire hors ecran qui a des cibles : son bouton P<n> / sa vignette est dore
		if b is Button:
			_foe_mark(b, off_screen.has(int((b as Button).get_meta("pid", -1))))

## Salle SOURCE de la capacite en cours de resolution = bordure GreenGlow (TargetResolverBaseSceneBehavior.cs:26,228) ; les cibles, elles, ont la bordure Yellow sans particules (cs:24).
## CardStackSlotComponent.HighLightCards (cs:299-316) : particules (emetteur 0,9 x la salle, CardEntity.cs:88-91), boucle sfx_sparklecard, et la salle grossit (0,37 -> 0,5, ScaleEffectBehavior
## 0,3 s lineaire) ; CleanHighLightCards (cs:326-343) remet tout. `_tgt["source"]` : zone de la salle (cle "k" = room), vide si la source n'est pas une salle du plateau.
func _fx_target(node: Control, on: bool) -> void:
	ApkParticles.sur(node, "TargetFx", node.size * 0.5, node.size * ApkParticles.ECHELLE, on)

func _target_source_glow() -> void:
	var node: Control = null
	var src: Dictionary = _tgt.get("source", {})
	if not src.is_empty():
		node = _spot_node(src)
	if node != null: # passe devant le voile comme les cibles
		node.z_index = TARGET_Z
		if not _tgt_lifted.has(node):
			_tgt_lifted.append(node)
	if node == _tgt_src:
		return
	_target_source_off()
	if node == null:
		return
	_tgt_src = node
	_fx_target(node, true)
	var g := UiKit.image(node, UI_DIR + "card_border_green_glow.webp", Vector2.ZERO, node.size)
	g.name = "SourceGlow"
	if not _border_fit(g, "card_border_green_glow", node.size, DungeonSlot.CARD_SIZE.x):
		g.queue_free()
		return
	node.pivot_offset = node.size / 2.0
	if not skip_animations:
		node.create_tween().tween_property(node, "scale", Vector2.ONE * 0.5 / 0.37, 0.3)
	else:
		node.scale = Vector2.ONE * 0.5 / 0.37
	_sparkle_on = true
	AudioManager.play_loop("sfx_sparklecard")

func _target_source_off() -> void:
	if _tgt_src != null and is_instance_valid(_tgt_src):
		_fx_target(_tgt_src, false)
		_tgt_src.scale = Vector2.ONE
		var g := _tgt_src.get_node_or_null("SourceGlow")
		if g != null:
			g.queue_free()
	_tgt_src = null
	if _sparkle_on:
		_sparkle_on = false
		AudioManager.stop_loop("sfx_sparklecard")

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
	if not _border_fit(glow, "card_border_yellow", sp.size, r.size.x): # cibles = BorderStyles.Yellow (TargetResolverBaseSceneBehavior.cs:24)
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
	if _lvl_busy or not _tg("choice", pc):
		return # banniere LEVEL UP en cours : le choix suivra (refresh a sa fin) ; tutoriel : le choix attend la fin des consignes
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
	if str(pc.get("type", "")) == "steal-card": # texte APK du niveau 2 de Draculord (capture levelup_14), pas la phrase du moteur
		title = "LEVEL UP: TARGET OPPONENT REVEALS HIS OR HER HAND. TAKE ONE CARD AND PUT IT INTO YOUR HAND."
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
	var apk_only: bool = G.has("sets") # l'APK n'a aucun bouton « EXTRA MOVES » : reserve aux paquets wiki (meme regle que Match.gd:1900)
	for st in G.get("sets", []):
		apk_only = apk_only and st in Match.APK_SETS
	if apk_only or not (G.get("pendingChoice", {}) as Dictionary).is_empty():
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
		"useItem":
			return "ITEM: %s" % ThkAbilities.item_name(str(args[0]))
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
		"payDarkCoins":
			return "PAY %d COIN%s (DARK HERO: +%d HEALTH)" % [int(args[0]), "" if int(args[0]) == 1 else "S", int(args[0])]
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
	_discard_move = str(move.get("type", "")) in ["resolveChoice", "discardForCoin"]
	game_manager.apply_move(_my_pid(), move)
	refresh() # toujours : ce qui reste a decider (nouveau choix) doit reapparaitre

func _on_hand_card_clicked(idx: int, card: Dictionary) -> void:
	if not _tg("tap", {"idx": idx, "card": card}):
		return # tutoriel : seule la carte imposee reagit (CardExtractBehavior.cs:216)
	if _is_opening_discard_for_me():
		if discard_pick.has(idx):
			discard_pick.erase(idx)
			_play_sfx("ui_button_subselect") # CardSelectorComponent.cs:120-125 : une carte deselectionnee ne joue que subselect
		else:
			if discard_pick.size() >= 2:
				discard_pick.remove_at(0) # la plus ancienne est remplacee (CardSelectorComponent.cs:128-134)
				_play_sfx("ui_button_subselect")
			discard_pick.append(idx)
			_play_sfx("ui_button_select") # :135
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
		_play_sfx("ui_card_slide_down") # BuildRoomHandSceneBehavior.cs:182 -> FlipCardBehavior.cs:126 : la salle posee se retourne face cachee
		if game_manager.build_room_at(_my_pid(), idx, target_slot):
			refresh() # apply_move n'emet pas toujours state_changed en fin de coup (transition de phase)
	else:
		_play_from_hand(idx)

## CardPositionComponent.Refresh (cs:73-100) : survoler une autre carte de la main joue ui_shuffle_left (indice plus grand, ou depuis « aucune ») ou _right ;
## quitter la main apres en avoir survole une joue ui_card_slide_general. L'evaluation est differee d'une image : sortir d'une carte et entrer dans la voisine est un seul changement.
func _hand_hover(idx: int, on: bool) -> void:
	if on:
		_fan_apply(idx)
		_hand_cur = idx
		if idx != _hand_last:
			_play_sfx("ui_shuffle_left" if idx > _hand_last else "ui_shuffle_right") # CardPositionComponent.cs:79-88
			_hand_last = idx
	elif _hand_cur == idx:
		_fan_apply(-1)
		_hand_cur = -1
		_hand_leave.call_deferred()

func _hand_leave() -> void:
	if _hand_cur < 0 and _hand_last >= 0:
		_play_sfx("ui_card_slide_general") # CardPositionComponent.cs:94-98
		_hand_last = -1

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
	if cands.size() == 1: # aucun son : l'APK ne joue rien pour ses propres sorts (la bulle sfx_activatecard n'existe que pour les adversaires, GamePlayBaseScene.cs:1166)
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
			_play_sfx("ui_card_slide_down") # BuildRoomHandSceneBehavior.cs:182
			_do(pmv)})
	for c in over:
		var mv: Dictionary = (c as Dictionary).duplicate()
		var ti := int((mv["args"] as Array)[1])
		var host = BossEngine.active_room(dungeon[ti]) if ti >= 0 and ti < dungeon.size() else null
		entries.append({"label": "ON %s" % (str((host as Dictionary).get("name", "Room %d" % (ti + 1))) if host != null else "Room %d" % (ti + 1)), "mv": mv,
			"spot": {"k": "room", "pid": _my_pid(), "idx": ti} if on_board else {}, "cb": func():
			_play_sfx("ui_card_slide_down") # BuildRoomHandSceneBehavior.cs:182
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
	for mv in _my_moves(_my_pid()):
		var m: Dictionary = mv
		if str(m.get("type", "")) != "buildRoom" and hand_idx_of(m) == idx and _tg("move", m): # tutoriel : un seul coup de sort permis
			cands.append(m)
	return cands

## Entree de menu d'un coup de la main : sort / capacite ciblee (zone du plateau si elle en a une) ou coup d'extension (libelle de _move_label).
func _hand_entry(card: Dictionary, c: Dictionary) -> Dictionary:
	var mv: Dictionary = c.duplicate()
	var margs: Array = mv.get("args", [])
	var is_spell: bool = str(mv.get("type", "")) in HAND_CLICK_TYPES
	return {"label": _target_label(mv, card) if is_spell else _move_label(mv, game_manager.G, _my_hand()), "mv": mv,
		"spot": _spot_of_target(margs[1] as Dictionary, _my_pid()) if is_spell and margs.size() > 1 and margs[1] is Dictionary else {}, "cb": func():
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
			if _tg("undo"): # tutoriel : la pose imposee ne se reprend pas
				_do(m)
			return
	var cands: Array = []
	for m in _moves_of(_my_moves(_my_pid()), "activateRoom"):
		var a: Array = (m as Dictionary).get("args", [])
		if not a.is_empty() and int(a[0]) == di:
			cands.append(m)
	if cands.is_empty():
		return
	# APK : le 1er appui ouvre le zoom de la pile (DungeonFrame_ShowRoomSlotDetail -> ShowZoom, GamePlayBaseScene.cs:681-718) ; le 2e, sur la bordure
	# de capacite, resout (AbilityPressedAction -> ResolveAndPlayRoomAbility, GamePlayBaseScene.cs:698-708) et ferme le zoom (_input).
	var pl: Dictionary = (game_manager.G.get("players", {}) as Dictionary).get(_my_pid(), {})
	var top = BossEngine.active_room((pl.get("dungeon", []) as Array)[di]) if di < (pl.get("dungeon", []) as Array).size() else null
	if top == null:
		_resolve_slot_ability(di, cands)
		return
	if (pl.get("dungeon", []) as Array)[di].size() > 1: # pile : toutes les salles (CarrouselVerticalComponent), capacite sur celle du dessus
		_slot_zoom(_my_pid(), di, cands)
		room_detail_shown.emit(di)
		return
	_zoom_hide()
	var zs = _tg("zoom_scale", null, 1.0) # tutoriel : le zoom de la salle est 1,62 x plus grand que celui du jeu (tut_100 : boite de capacite 460 px de large, cadre bas a y 985)
	zs = float(zs) if zs is float else 1.0
	var zc: Vector2 = UiKit.ZOOM_CARD * zs
	var pad: float = UiKit.ZOOM_PAD * zs
	_zoom = UiKit.zoom_card(top, zc, false, pad)
	_zoom.set_meta("levelup", true) # survit aux refresh jusqu'au clic suivant (_input)
	var cx := 960.0
	for sl in _dungeon_slots:
		if (sl as DungeonSlot).slot_index == di and not (sl as DungeonSlot).current_stack.is_empty():
			cx = (sl as Control).get_global_rect().get_center().x
	_zoom.position = Vector2(clampf(cx - _zoom.size.x / 2.0, 190.0, 1707.0 - _zoom.size.x), 295.0 if zs == 1.0 else 985.0 - _zoom.size.y)
	_ui_layer.add_child(_zoom)
	_zoom_appear()
	hand_layer.modulate = Color(0.6, 0.6, 0.6)
	_zoom_ability(_zoom, zc, pad, di, cands)
	room_detail_shown.emit(di)

## Resolution de la capacite d'une salle (apres le tap sur la bordure du zoom) : coup direct, ou choix de la salle cible (Centipede Tunnel...).
func _resolve_slot_ability(di: int, cands: Array) -> void:
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
	_target_list("%s - choose a Room" % str((rd as Dictionary).get("name", "")) if rd != null else "Choose a Room", "Choose a Room", entries, func(): _popup_close(), {"k": "room", "pid": _my_pid(), "idx": di})

func _on_confirm_pressed() -> void:
	if game_manager.G.get("gameOver") != null:
		_play_sfx("res://assets/audio/sfx/ui_button_select.wav")
		_confirm_quit()
	elif str(game_manager.G.get("phase", "")) == "boss":
		_play_sfx("ui_button_select") # RandomBossSelectionScene.cs:90 : bouton PLAY BOSS MONSTER! (ButtonBaseEntity.cs:202)
		_boss_confirm()
	else:
		_on_discard_confirm()

func _on_discard_confirm() -> void:
	if discard_pick.size() != 2:
		return
	var pair := discard_pick.duplicate()
	pair.sort()
	_play_sfx("ui_button_select") # bouton CONTINUE du selecteur (CarouselSelectorEntity.cs:21, ButtonBaseEntity.cs:202) ; l'APK n'appelle jamais ui_card_flip
	discard_pick.clear() # avant _do : son refresh reconstruit la main (d'un autre siege), sans la selection de celui-ci
	_do({"type": "openingDiscard", "args": pair})

func _is_opening_discard_for_me() -> bool:
	var pc: Dictionary = game_manager.G.get("pendingChoice", {})
	return str(pc.get("type", "")) == "opening-discard" and int(pc.get("playerId", -1)) == _my_pid()

func _on_advance_pressed() -> void:
	if _animating_hero or _bait_active() or _modal_open() or not _tgt.is_empty():
		return
	_play_sfx("ui_button_select") # DoneButtonEntity.cs:164 ; le pas du heros joue ensuite son propre son (_animate_step), l'ancien char_hero_move ici doublait celui-ci
	if _is_online():
		_do({"type": "resolveNextHero", "args": []})
	else:
		game_manager.apply_move(_my_pid(), {"type": "adventureNext", "args": []})
		refresh()

## Poses faites : BuildRoomHandSceneBehavior.IsBuildTurnDone (:41, poses en attente >= MaxBuildRoomLimit) ou fenetre de sorts apres la derniere pose.
func _builds_done(G: Dictionary, p: Dictionary) -> bool:
	return int(p.get("buildsThisTurn", 0)) >= 1 + BossEngine.extra_builds_for(G, _my_pid()) or G.has("buildWindow")

## Mode « PASS TURN » du bouton central (BuildRoomHandSceneBehavior.cs:115 : IsPlayerBuildTurn && !IsBuildTurnDone) : tour de construction pas encore fait.
func _pass_turn_mode() -> bool:
	var G: Dictionary = game_manager.G
	return str(G.get("phase", "")) in ["build", "setup"] and (G.get("stack", []) as Array).is_empty() and not _builds_done(G, (G.get("players", {}) as Dictionary).get(_my_pid(), {}))

func _on_pass_pressed() -> void:
	if not _tgt.is_empty():
		return
	if not _tg("pass"):
		return # tutoriel : DONE verrouille tant que la pose imposee n'est pas faite (GamePlayTutScene.cs:185,194,203)
	_play_sfx("res://assets/audio/sfx/ui_button_select.wav")
	# DoneButtonEntity.cs:118-143 : en mode PASS TURN le 1er relachement ne passe jamais, il leve le drapeau (ShowHintComponent.Hint, IsRaised) ; la bulle « HEY! YOU CAN
	# BUILD A ROOM! STILL WANT TO PASS? » (GamePlayBaseScene.cs:259-269) n'apparait que si une salle de la main est constructible. Le 2e relachement passe. Le drapeau
	# retombe au tour suivant (CreateShowAndActivateTimer, DoneButtonEntity.cs:177), pas quand la bulle disparait ; en mode DONE! un seul appui passe.
	var raise_key := "%d/%s/%s" % [_my_pid(), game_manager.G.get("turn", 0), game_manager.G.get("phase", "")] # par siege : a plusieurs sieges, le 1er appui du 2e siege ne passe pas d'emblee
	if _pass_turn_mode() and _pass_raised_key != raise_key:
		_pass_raised_key = raise_key
		if _can_still_build(game_manager.legal_moves(_my_pid())):
			_warn_show()
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

## Glisser une carte de la main (appui puis pointeur au-dessus de HAND_UPPER) : carte zoomee (cadre noir) accrochee au curseur ; salle = l'emplacement
## accepte s'allume en dore, sort = les cibles du plateau s'allument en dore ; relacher sur une cible joue le coup (voir _drag_end).
func _drag_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var m := event as InputEventMouseMotion
		if _drag.is_empty():
			if not (m.button_mask & MOUSE_BUTTON_MASK_LEFT) or _press.is_empty():
				_press_clear()
				return
			if m.global_position.y < HAND_UPPER and _can_drag():
				_drag_begin()
		elif m.global_position.y >= HAND_UPPER: # CardExtractBehavior.Update : le doigt redescend sous la limite, la carte est reposee dans la main
			_press = {}
			_drag_end(m.global_position)
			return
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
	if idx < 0 or idx >= hand.size() or not _tg("drag", idx): # tutoriel : seule la carte imposee se glisse
		_press_clear()
		return
	if is_instance_valid(ci):
		(ci as CardUI).suppress_click = true
	_zoom_hide()
	var greyed: bool = is_instance_valid(ci) and (ci as CardUI).greyed
	if greyed: # carte non jouable : pas extraite (CardExtractBehavior.cs:ExtractCard, IsCardEnabled)
		_press_clear()
		return
	# APK (CardExtractBehavior.ExtractCard) : la carte tiree reprend l'echelle de la main (ToScale = NormalScale, rotation 0), cadre noir fin ;
	# la grande apercu 350 x 490 est le zoom d'appui long, pas le glisser.
	var prev := UiKit.zoom_card(hand[idx], HAND_CARD, greyed, 4.0)
	prev.modulate = Color(1, 1, 1, 0.96)
	_ui_layer.add_child(prev)
	_drag = {"idx": idx, "preview": prev, "frames": []}
	_drag_move(_press["pos"])
	_drag_refresh()

## Inclinaison de la carte glissee (CardRotationBehavior.UpdateCardDragEffect, cs:84-111) : rotation autour de Y = (position precedente - position) x 0,005 rad PAR IMAGE, bornee a +-22,5 deg (0,3927 rad) ;
## l'axe X est calcule mais jamais applique (cs:99,106-108), retombe a 0 des que la carte s'arrete. Approximation 2D : largeur x cos(angle), sans la perspective du rendu 3D.
func _drag_tilt() -> void:
	if _drag.is_empty() or not is_instance_valid(_drag["preview"]):
		return
	var prev: Control = _drag["preview"]
	var dx: float = float(_drag.get("lx", prev.position.x)) - prev.position.x
	_drag["lx"] = prev.position.x
	prev.pivot_offset = prev.size / 2.0
	prev.scale.x = cos(clampf(dx * 0.005, -0.3927, 0.3927))

func _drag_move(pos: Vector2) -> void:
	var prev: Control = _drag["preview"]
	prev.position = Vector2(clampf(pos.x - prev.size.x / 2.0, 0.0, 1920.0 - prev.size.x), clampf(pos.y - prev.size.y * 0.62, 0.0, 1080.0 - prev.size.y))
	_drag_hover()

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
			if wanted and _tg("drop", slot) and slot._can_drop_data(Vector2.ZERO, {"type": "card", "hand_index": idx}):
				(_drag["frames"] as Array).append(_slot_frame(slot))
		_drag_hover()
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

## APK : pendant le glisser d'une salle, chaque emplacement ou elle peut se poser porte card_border_yellow_scaled (152 x 203 a sa taille native, centre sur l'emplacement ;
## DungeonFrameEntity.HighLightBuildableSlots, DungeonFrameEntity.cs:320-330 "SlotGlow" IsForceScaled) ; celui que la carte survole passe a card_border_yellow_glow_scaled
## (BuildRoomHandSceneBehavior.cs:120-127). Le cadre est derriere la carte glissee.
func _slot_frame(slot: Control) -> Control:
	var f := TextureRect.new()
	f.texture = _tex(UI_DIR + "card_border_yellow_scaled.webp")
	f.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	f.stretch_mode = TextureRect.STRETCH_SCALE
	f.size = Vector2(152, 203)
	f.position = slot.global_position + slot.size / 2.0 - f.size / 2.0
	f.mouse_filter = Control.MOUSE_FILTER_IGNORE
	f.name = "SlotGlow"
	f.set_meta("slot", slot)
	_ui_layer.add_child(f)
	var prev = _drag.get("preview")
	if prev != null and is_instance_valid(prev):
		_ui_layer.move_child(f, (prev as Control).get_index())
	return f

## Le centre de la carte glissee est-il dans l'emplacement (rectangle x 1,2, EntitiesExtensions.IsContainedByEntity(pos, 1.2f), cs:12-26) ?
func _slot_hovered(slot: Control, card_center: Vector2) -> bool:
	return Rect2(slot.global_position + slot.size / 2.0 - slot.size * 0.6, slot.size * 1.2).has_point(card_center)

func _drag_hover() -> void:
	if _drag.is_empty() or not is_instance_valid(_drag["preview"]):
		return
	var prev: Control = _drag["preview"]
	for f in (_drag["frames"] as Array):
		if is_instance_valid(f) and (f as Node).has_meta("slot"):
			var hot := _slot_hovered((f as Node).get_meta("slot") as Control, prev.position + prev.size / 2.0)
			((f as Node) as TextureRect).texture = _tex(UI_DIR + ("card_border_yellow_glow_scaled.webp" if hot else "card_border_yellow_scaled.webp"))
			# Particules seulement sur l'emplacement survole (SlotGlow pose en YellowGlow : BuildRoomHandSceneBehavior.cs:125-132, DungeonFrameEntity.cs:309-318, CardBorderBehavior.cs:48-50) ;
			# les emplacements simplement constructibles (HighLightBuildableSlots, bordure Yellow) n'en ont pas. Emetteur = l'emplacement (card_slot, ParticlesParentSizeBehavior Scale 1), derriere le cadre.
			var slot := (f as Node).get_meta("slot") as Control
			ApkParticles.sur(f as Control, "SlotFx", (f as Control).size * 0.5, slot.size, hot)

## CardBorderBehavior.cs:31,64-71 : sous l'echelle 0,5 la bordure est la variante _scaled (152 x 203) posee x2,7, soit 152 x 203 pour une salle de couloir (0,37), au lieu de la bordure
## 390 x 528 etiree sur la carte (trait aminci). Vrai si `t` a ete ajuste.
func _border_fit(t: TextureRect, border: String, host: Vector2, card_w: float) -> bool:
	if card_w > 175.5:
		return false
	t.texture = _tex(UI_DIR + border + "_scaled.webp")
	var sz := Vector2(152, 203) * 2.7 * card_w / 350.0
	t.set_anchors_preset(Control.PRESET_TOP_LEFT)
	t.position = (host - sz) / 2.0
	t.size = sz
	return true

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
	if not _border_fit(glow, "card_border_red" if red else "card_border_yellow_glow", f.size, r.size.x):
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
	var prev: Control = _drag["preview"]
	var card_center: Vector2 = prev.position + prev.size / 2.0 if is_instance_valid(prev) else pos
	_drag_clear()
	if idx < hand.size() and pos.y < HAND_UPPER: # relacher sur la main = annuler
		if is_room:
			var data := {"type": "card", "hand_index": idx}
			var target: DungeonSlot = null
			for slot in _dungeon_slots: # le doigt sur un emplacement d'abord, sinon l'emplacement que survole la carte lachee (APK : FindHoverBuildableSlot)
				if Rect2((slot as Control).global_position, (slot as Control).size).has_point(pos):
					target = slot
					break
			if target == null:
				for slot in _dungeon_slots:
					if _slot_hovered(slot as Control, card_center) and (slot as DungeonSlot)._can_drop_data(Vector2.ZERO, data):
						target = slot
						break
			if target != null and _tg("drop", target) and target._can_drop_data(Vector2.ZERO, data):
				target._drop_data(Vector2.ZERO, data)
		else:
			_spell_drop(idx, pos)
	refresh() # remet la main en place (carte revenue) quoi qu'il arrive

## Sort lache a `pos` : un seul coup (sort sans cible) = joue n'importe ou sur le plateau ; sinon la cible sous le curseur ;
## plusieurs coups sur la meme cible = petite liste ; cibles sans representation (ames, pile...) = la liste centrale.
func _spell_drop(idx: int, pos: Vector2) -> void:
	var cands := _hand_moves(idx)
	if cands.is_empty() or not _tg("spell_drop", pos): # tutoriel : le sort doit tomber sur le heros designe
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
		_do(cands[0])
	elif hits.size() == 1:
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
	var greyed: bool = ci.greyed
	_zoom = UiKit.zoom_card(ci.card_dict, UiKit.ZOOM_CARD, greyed)
	_zoom.position = Vector2(clampf(ci.get_global_rect().get_center().x - _zoom.size.x / 2.0, 190.0, 1707.0 - _zoom.size.x), 295.0) # APK : cadre noir de 350 x 490 dont le haut est a y ~295
	_ui_layer.add_child(_zoom)
	_zoom_appear()
	hand_layer.modulate = Color(0.6, 0.6, 0.6)

## AppearBehavior (AppearBehavior.cs:33-41,59-69) : le zoom entre en 0,2 s, CubicEase EaseInOut, opacite 0,5 -> 1 et echelle 0,8 -> 1,3 (soit 0,615 -> 1 de sa taille finale).
## La fermeture est instantanee : AppearOut met l'opacite a 0 sans animation (AppearBehavior.cs:94-101).
func _zoom_appear() -> void:
	if _zoom != null:
		_play_sfx("ui_card_slide_up") # GamePlayBaseScene.cs:1270-1272 (openAction de ShowZoom)
	if skip_animations or _zoom == null:
		return
	_zoom.pivot_offset = _zoom.size / 2.0
	_zoom.scale = Vector2.ONE * (0.8 / 1.3)
	_zoom.modulate.a = 0.5
	var tw := _zoom.create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(_zoom, "scale", Vector2.ONE, 0.2)
	tw.tween_property(_zoom, "modulate:a", 1.0, 0.2)

## Fermeture voulue d'un zoom (relachement de l'appui long, clic suivant) : GamePlayBaseScene.cs:1265-1267 joue ui_card_slide_down ; _zoom_hide, lui, est silencieux (reconstruction, remplacement).
func _zoom_close() -> void:
	if _zoom != null and is_instance_valid(_zoom):
		_play_sfx("ui_card_slide_down")
	_zoom_hide()

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
		sig += "%s:%s," % [str((e as Dictionary).get("id", "")), str((e as Dictionary).get("playerId", ""))]
	if sig == _stack_sig:
		return
	var old_keys := _stack_keys
	_stack_keys = []
	for e in stack:
		_stack_keys.append("%s:%s" % [str((e as Dictionary).get("id", "")), str((e as Dictionary).get("playerId", ""))])
	_stack_sig = sig
	_stack_hover_clear()
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
	var lay := _stack_layout(stack)
	for i in n:
		var card: Dictionary = ((stack[i] as Dictionary).get("card", {}) as Dictionary)
		if card.is_empty():
			continue
		var k: float = float(lay[i]["k"])
		# k = echelle APK de la carte 350 x 488 : 1 = zoom 350 x 490 ; en dessous, la carte nue (pas de cadre noir en plus : IsShadowVisible = false, PlaySpellsInHandSceneBehavior.cs:35 ; APK 176 x 246 a 0,5)
		var z := UiKit.zoom_card(card, UiKit.ZOOM_CARD, false, UiKit.ZOOM_PAD) if k >= 0.99 else UiKit.zoom_card(card, Vector2(350.0, 488.0) * k, false, 0.0)
		var cx: float = float(lay[i]["cx"])
		z.position = Vector2(cx - z.size.x / 2.0, 498.0 - z.size.y / 2.0)
		if bool((stack[i] as Dictionary).get("canceled", false)):
			z.modulate = Color(0.5, 0.5, 0.5)
		_stack_ui.add_child(z)
		z.set_meta("stack_id", str((stack[i] as Dictionary).get("id", "")))
		var owner_pid := int((stack[i] as Dictionary).get("playerId", -1))
		if not skip_animations and not old_keys.has(_stack_keys[i]) and str((stack[i] as Dictionary).get("type", "")) == "spell" and owner_pid == _my_pid():
			# mon sort qui vient d'etre joue : ScaleEffectBehavior 0 -> 1 en 0,3 s lineaire (PlaySpellsInHandSceneBehavior.cs:37 ; CardEntity.cs:71 ; ScaleEffectBehavior.cs:57-60)
			z.pivot_offset = z.size / 2.0
			z.scale = Vector2.ZERO
			z.create_tween().tween_property(z, "scale", Vector2.ONE, 0.3)
		if owner_pid != _my_pid(): # APK : sort / capacite de l'adversaire = son portrait rond (BossOwnerIcon) a cheval sur le haut de la carte
			z.add_child(_owner_badge(owner_pid, z.size.x / 2.0))

## SimpleHoverBehavior sur la pile (SpellBattleEntity.cs:49 ; SpellBattleHighLightsComponent.cs:49-77) : survol d'une carte = bordure rouge sur elle et sur ce qu'elle vise.
## Les cartes de la pile ignorent la souris (elles ne volent aucun clic) : le survol est lu a chaque image.
var _stack_hov := -1
var _stack_hov_fx: Array = []

func _stack_hover_clear() -> void:
	for f in _stack_hov_fx:
		if is_instance_valid(f):
			(f as Node).queue_free()
	_stack_hov_fx = []
	_stack_hov = -1

func _tick_stack_hover() -> void:
	var want := -1
	if _stack_ui != null and is_instance_valid(_stack_ui) and _tgt.is_empty() and _drag.is_empty() and not _modal_open():
		var mp := get_global_mouse_position()
		for i in range(_stack_ui.get_child_count() - 1, -1, -1):
			if (_stack_ui.get_child(i) as Control).get_global_rect().has_point(mp):
				want = i
				break
	if want == _stack_hov:
		return
	_stack_hover_clear()
	_stack_hov = want
	if want < 0:
		return
	var z := _stack_ui.get_child(want) as Control
	_stack_hov_fx.append(UiKit.image(z, UI_DIR + "card_border_red.webp", Vector2(-2, -2), z.size + Vector2(4, 4))) # BorderStyles.Red : 354 x 492 pour une carte 350 x 488
	for e in (game_manager.G.get("stack", []) as Array):
		if str((e as Dictionary).get("id", "")) == str(z.get_meta("stack_id", "")) and (e as Dictionary).get("target") is Dictionary:
			var spot := _spot_of_target((e as Dictionary)["target"], int((e as Dictionary).get("playerId", -1)))
			var node := _spot_node(spot) if not spot.is_empty() else null
			if node != null and node != z:
				_stack_hov_fx.append(_gold_frame(_spot_rect(spot, node), true))

## Disposition de la pile de sorts (SimplePositionComponent.Refresh, SimplePositionComponent.cs:49-77) : une seule carte garde l'echelle avec laquelle elle est arrivee (mon sort : echelle de la
## main 0,5, PlaySpellsInHandSceneBehavior.cs:33-39 ; sort adverse ou capacite : 1, GamePlayBaseScene.cs:644) ; plusieurs : echelle 0,6 (Scale par defaut), centres de -x/2 a +x/2 avec
## x = min(200 par carte, largeur 900 x 1920/1440). Renvoie [{cx, k}] dans l'ordre de la pile.
func _stack_layout(stack: Array) -> Array:
	var n := stack.size()
	var out: Array = []
	for i in n:
		var e: Dictionary = stack[i]
		var k := 0.6
		var cx := STACK_CX
		if n == 1:
			k = 0.5 if str(e.get("type", "")) == "spell" and int(e.get("playerId", -1)) == _my_pid() else 1.0
		else:
			var span := minf(float(n) * 200.0, 1200.0)
			cx = STACK_CX + lerpf(-span / 2.0, span / 2.0, float(i) / float(n - 1))
		out.append({"cx": cx, "k": k})
	return out

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
func _notice_ai(pid: int, mv: Dictionary, shown = null) -> void:
	if pid == _my_pid():
		return
	var t := str(mv.get("type", ""))
	var pl: Dictionary = (game_manager.G.get("players", {}) as Dictionary).get(pid, {})
	var args: Array = mv.get("args", [])
	var ai := -1 if args.is_empty() or not (args[0] is int) else int(args[0])
	var card = shown # la carte de la capacite (appelee avant le coup) : un appui sur la bulle la montre (ShowBubleDetail) ; en ligne `shown` vient du serveur (main adverse cachee)
	var spot := {} # ce que la carte jouee touche : cadre rouge sur le plateau pendant le zoom (ShowBubleDetail : HighLightCards Red)
	if t in ["playSpell", "useHandRoom"] and args.size() > 1 and args[1] is Dictionary:
		spot = _spot_of_target(args[1], pid)
	if t in ["playSpell", "useHandRoom"]:
		var hand: Array = pl.get("hand", [])
		if card == null:
			card = hand[ai] if ai >= 0 and ai < hand.size() else null
	elif t == "activateRoom":
		var dng: Array = pl.get("dungeon", [])
		if card == null:
			card = BossEngine.active_room(dng[ai]) if ai >= 0 and ai < dng.size() else null
		# « Destroy this Room: ... » : la salle est l'une de ses propres cibles de commande (GetCommandTargets) ; le zoom de la bulle la montre cerclee de rouge
		# (ShowBubleDetail, GamePlayBaseScene.cs:1249-1260 ; capture ability_bottomless_pit_activated_red_glow_*)
		if card is Dictionary and str((card as Dictionary).get("description", "")).to_lower().begins_with("destroy this room"):
			spot = {"self": true}
	var against: Array = []
	if t in ["playSpell", "useHandRoom"] and args.size() > 1 and args[1] is Dictionary and (args[1] as Dictionary).has("targetPlayerId") and int((args[1] as Dictionary)["targetPlayerId"]) != pid:
		against = [int((args[1] as Dictionary)["targetPlayerId"])] # Ability.GetAgainstPlayers sans le joueur lui-meme (GamePlaySPScene.cs:109-113) ; cible explicite seulement
	if t == "playSpell":
		_show_notice("SPELL", card, spot, pid, against)
	elif t in ["activateRoom", "useHandRoom"]:
		_show_notice("ROOM ABILITY", card, spot, pid, against)

## Coup d'un autre siege en ligne (humain distant ou IA du serveur) : meme bulle que la boucle IA locale.
func _on_remote_play(play: Dictionary) -> void:
	_notice_ai(int(play.get("seat", -1)), play.get("move", {}) as Dictionary, play.get("card"))

## « IS PLAYING! » (IsPlayingOnlineBubbleSceneBehavior) : une bulle par adversaire dont la decision retient la partie. Elle s'efface quand une bulle de coup entre
## (BubblesPlayerEmitter.UpdateBubbleTask) et revient apres elle. Meme boite et meme place que la bulle de coup.
var _playing: Dictionary = {}

func _playing_hide(pid: int) -> void:
	var old: Control = _playing.get(pid)
	_playing.erase(pid)
	if is_instance_valid(old):
		old.create_tween().tween_property(old, "modulate:a", 0.0, 0.5)
		old.get_tree().create_timer(0.5).timeout.connect(old.queue_free)

func _sync_playing() -> void:
	var want: Array = (game_manager as OnlineGameManager).awaited_others() if _is_online() and game_manager.G.get("gameOver") == null else []
	for pid in _playing.keys():
		if not want.has(pid):
			_playing_hide(pid)
	var ids: Array = (game_manager.G.get("players", {}) as Dictionary).keys()
	ids.sort()
	ids.erase(view_pid)
	for pid in want:
		if _playing.has(pid) or _notice_cur.has(pid) or not ids.has(pid):
			continue
		_playing[pid] = _playing_bubble(pid, ids.find(pid))

func _playing_bubble(pid: int, idx: int) -> Control:
	var n := Control.new()
	n.name = "IsPlaying%d" % pid
	n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	n.position = Vector2(1458, 63 + 138 * idx)
	n.size = Vector2(234, 136)
	UiKit.image(n, UI_DIR + "action_bubble.webp", Vector2.ZERO, Vector2(234, 136))
	UiKit.label(n, "   IS\nPLAYING!", 21, Color.WHITE, Vector2(-12, 56), 190.0, UiKit.FONT_A, HORIZONTAL_ALIGNMENT_CENTER) # BubblesFactory.cs:20-23 (x -215, y -45, largeur 190)
	_ui_layer.add_child(n)
	if not skip_animations:
		n.modulate.a = 0.0
		var tw := n.create_tween()
		tw.tween_property(n, "modulate:a", 1.0, 0.5)
		tw.tween_callback(_pulse_rings.bind(n, UI_DIR + "action_bubble_effect.webp", Vector2(236, 132), Vector2(117, 68), 4))
	return n

## Une file par adversaire (BubblesPlayerEmitter.pendingPlayBubbles) : la bulle suivante n'entre qu'apres la sortie de la precedente. `pid` : l'adversaire qui joue (-1 = l'adversaire affiche) ;
## `against` : les pids vises (CreatePlayAgainstBubble : « AGAINST » + leurs icones de boss).
var _notice_cur: Dictionary = {}
var _notice_q: Dictionary = {}

func _notice_reset() -> void:
	for pid in _notice_cur:
		if is_instance_valid(_notice_cur[pid]):
			(_notice_cur[pid] as Node).queue_free()
	_notice_cur = {}
	_notice_q = {}
	_notice = null
	for pid in _playing:
		if is_instance_valid(_playing[pid]):
			(_playing[pid] as Node).queue_free()
	_playing = {}

func _show_notice(what: String, card = null, spot := {}, pid := -1, against := []) -> void:
	if pid < 0:
		pid = foe_pid
	if _notice_cur.has(pid) and is_instance_valid(_notice_cur[pid]):
		(_notice_q.get_or_add(pid, []) as Array).append([what, card, spot, against])
		return
	_playing_hide(pid) # la bulle « IS PLAYING! » s'efface avant l'entree de la bulle de coup
	var ids: Array = (game_manager.G.get("players", {}) as Dictionary).keys()
	ids.sort()
	ids.erase(view_pid)
	var n := Control.new()
	n.name = "Notice"
	n.mouse_filter = Control.MOUSE_FILTER_STOP if card is Dictionary else Control.MOUSE_FILTER_IGNORE
	n.position = Vector2(1458, 63 + 138 * maxi(ids.find(pid), 0)) # APK : boite x 1458..1672, y 65..194, queue jusqu'a 1692 ; un panneau d'adversaire = 138 px (BubblesPlayerEmitter.cs:11,66)
	n.size = Vector2(234, 136)
	if card is Dictionary:
		n.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		n.gui_input.connect(func(ev: InputEvent):
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
				n.accept_event()
				_notice_zoom(card, spot))
	UiKit.image(n, UI_DIR + "action_bubble.webp", Vector2.ZERO, Vector2(234, 136))
	var dy := 0.0 if against.is_empty() else -32.0 # BubblesFactory.cs:55,61 : les deux lignes montent de 33 pour laisser place a AGAINST + icones
	UiKit.label(n, "HAS PLAYED A", 17, Color.WHITE, Vector2(0, 41 + dy), 216.0, UiKit.FONT_A, HORIZONTAL_ALIGNMENT_CENTER)
	UiKit.label(n, what, 21, APK_GOLD, Vector2(0, 64 + dy), 216.0, UiKit.FONT_A, HORIZONTAL_ALIGNMENT_CENTER)
	if not against.is_empty():
		UiKit.label(n, "AGAINST", 17, Color.WHITE, Vector2(0, 58), 216.0, UiKit.FONT_A, HORIZONTAL_ALIGNMENT_CENTER)
		for i in against.size(): # cs:75-91 : icones de 66 de pas, centrees autour de x -85 (origine du sprite 0,97 x 0,77), y +10, echelle 0,9
			var boss = ((game_manager.G.get("players", {}) as Dictionary).get(int(against[i]), {}) as Dictionary).get("boss")
			var ip := "res://assets/ui/characters/icon_%s_profile.webp" % (str((boss as Dictionary).get("id", "")).to_lower() if boss != null else "")
			var ic := UiKit.image(n, ip if ResourceLoader.exists(ip) else UI_DIR + "boss_icon.webp", Vector2.ZERO)
			ic.size *= 0.9 * 0.96
			ic.position = Vector2(227.0 + 0.96 * (-85.0 + 66.0 * (i - against.size() / 2.0)), 104.7 + 9.6) - ic.size / 2.0
	_ui_layer.add_child(n)
	_notice = n
	_notice_cur[pid] = n
	_play_sfx("sfx_activatecard") # BubblesPlayerEmitter.cs:115 : au moment ou la bulle de l'adversaire entre (via GamePlayBaseScene.cs:668,1181)
	if not skip_animations:
		n.modulate.a = 0.0
	var tw := n.create_tween()
	tw.tween_property(n, "modulate:a", 1.0, 0.5) # fondu d'entree 0,5 s (BubbleEntity.cs:67,83)
	if not skip_animations:
		tw.tween_callback(_pulse_rings.bind(n, UI_DIR + "action_bubble_effect.webp", Vector2(236, 132), Vector2(117, 68), 4)) # BubbleEntity.cs:CreateShowTask : PulseBehavior(action_bubble_effect, 4)
	tw.tween_interval(3.0) # PLAY_BUBBLE_TIME (BubblesPlayerEmitter.cs:22,117)
	tw.tween_property(n, "modulate:a", 0.0, 0.5) # fondu de sortie 0,5 s (BubbleEntity.cs:67 ; BubblesPlayerEmitter.cs:118)
	tw.tween_callback(func():
		n.queue_free()
		_notice_cur.erase(pid)
		var q: Array = _notice_q.get(pid, [])
		if not q.is_empty():
			var nx: Array = q.pop_front()
			_show_notice(nx[0], nx[1], nx[2], pid, nx[3])
		elif _is_online():
			_sync_playing())

## Appui sur la bulle de l'adversaire : la carte jouee en grand au centre de l'ecran (GamePlayBaseScene.ShowBubleDetail), jusqu'au clic suivant.
func _notice_zoom(card: Dictionary, spot := {}) -> void:
	_zoom_hide()
	_zoom = UiKit.zoom_card(card, UiKit.ZOOM_CARD)
	_zoom.set_meta("levelup", true) # survit aux refresh (l'IA continue de jouer) ; _input le ferme au clic suivant
	_zoom.position = Vector2(STACK_CX - _zoom.size.x / 2.0, 498.0 - _zoom.size.y / 2.0)
	_ui_layer.add_child(_zoom)
	_zoom_appear()
	if bool(spot.get("self", false)): # BorderStyles.Red sur la carte zoomee elle-meme : card_border_red (354 x 492 pour 350 x 488, CardBorderBehavior.cs:52-53)
		UiKit.image(_zoom, UI_DIR + "card_border_red.webp", Vector2(-2, -2), _zoom.size + Vector2(4, 4)).mouse_filter = Control.MOUSE_FILTER_IGNORE
	elif not spot.is_empty():
		var node := _spot_node(spot)
		if node != null:
			_zoom.set_meta("frames", [_gold_frame(_spot_rect(spot, node), true)])

## Nouvelles cartes en main (pioche, distribution d'ouverture) : le dos de la carte glisse jusqu'au centre, se retourne puis rejoint la main (DrawCardEmitter).
## Pas pendant le choix du boss / la defausse d'ouverture (sauf la distribution elle-meme) ; pas sans animations.
func _track_hand_draw(G: Dictionary, p: Dictionary, phase: String) -> void:
	var hand: Array = p.get("hand", [])
	var discarded := _discard_move
	_discard_move = false
	var seen_before := _hand_seen.duplicate()
	var same_seat := _hand_seen_pid == view_pid
	var deal := _deal_pending and not hand.is_empty() and phase != "boss"
	if deal:
		_deal_pending = false
		seen_before = []
		same_seat = true
	_hand_seen = hand.duplicate()
	_hand_seen_pid = view_pid
	var taken_back := _undo_ids # DrawCardEmitter n'anime que les cartes tirees, pas une salle reprise (Match.undo_build_on)
	_undo_ids = []
	for stack in p.get("dungeon", []):
		var top = BossEngine.active_room(stack)
		if top is Dictionary and (top as Dictionary).has("undoBuild"):
			_undo_ids.append(str((top as Dictionary).get("id", "")))
	if skip_animations or not same_seat or phase == "boss" or G.get("gameOver") != null:
		return
	if not deal and (seen_before.is_empty() or phase == "setup" or _is_opening_discard_for_me()):
		return
	var counts := {}
	for c in seen_before:
		counts[c] = int(counts.get(c, 0)) + 1
	var fresh: Array = []
	for c in hand:
		if int(counts.get(c, 0)) > 0:
			counts[c] = int(counts[c]) - 1
		elif taken_back.has(str((c as Dictionary).get("id", ""))):
			taken_back.erase(str((c as Dictionary).get("id", "")))
		else:
			fresh.append(c)
	var gone: Array = [] # cartes parties de la main (DrawCardEmitter.CreateDiscardRemovedCardsTask, cs:61-83) : ce qui reste de seen_before
	if discarded:
		for c in counts:
			for _k in int(counts[c]):
				gone.append(c)
	if not gone.is_empty():
		_show_discard(gone)
	if not fresh.is_empty():
		_show_draw(fresh)

## Defausse depuis la main (DrawCardEmitter.CreateSingleCardDiscardTask, cs:113-145) : la carte (particules allumees des le depart) va au centre en 0,5 s (rotation 0, echelle ci-dessous, CubicEase),
## attend 2 s + 0,1 s x rang, se retourne (0,5 s), part vers la defausse en bas a gauche (0,5 s, tournee de 90 deg, echelle 0,375), puis les particules s'eteignent et elle s'estompe (FadeBehavior 0,3 s, CardEntity.cs:69).
func _show_discard(cards: Array) -> void:
	var n := cards.size()
	var sc := lerpf(0.37, 1.0, 1.0 / float(n)) # cs:107
	var csz := UiKit.ZOOM_CARD * sc
	for i in n:
		var card: Dictionary = cards[i]
		var from := Vector2(HAND_CX, HAND_CY) # la carte de la main (reconstruite juste apres) : centre, rotation et taille de depart
		var rot := 0.0
		var k0 := HAND_CARD.x / csz.x
		for hn in hand_layer.get_children():
			var cu := hn as CardUI
			if cu != null and not cu.has_meta("discard_taken") and cu.card_dict == card:
				cu.set_meta("discard_taken", true)
				from = cu.get_global_transform() * (cu.size * 0.5)
				rot = cu.rotation_degrees
				break
		var back := UiKit.zoom_back("back-spell" if bool(card.get("isSpell", false)) else "back-room", csz)
		var face := UiKit.zoom_card(card, csz)
		back.visible = false
		var holder := Control.new()
		holder.name = "DiscardedCard"
		holder.add_to_group("discarded_card")
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(back)
		holder.add_child(face)
		holder.size = back.size
		holder.pivot_offset = back.size / 2.0
		holder.position = from - back.size / 2.0
		holder.scale = Vector2.ONE * k0
		holder.rotation_degrees = rot
		_ui_layer.add_child(holder)
		var fx := ApkParticles.creer(_ui_layer, back.size * ApkParticles.ECHELLE) # EmitParticles = true (cs:118)
		fx.position = from
		fx.suit = holder
		fx.set_emit(true)
		_ui_layer.move_child(fx, holder.get_index())
		var cx := lerpf(400.0, 1490.0, float(i + 1) / float(n + 1)) # meme rangee que la pioche (cs:109)
		var tw := holder.create_tween().set_parallel(true)
		tw.tween_property(holder, "position", Vector2(cx, 540.0) - back.size / 2.0, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(holder, "scale", Vector2.ONE, 0.5)
		tw.tween_property(holder, "rotation_degrees", 0.0, 0.5)
		tw.chain().tween_interval(2.0 + 0.1 * float(i))
		tw.chain().tween_property(holder, "scale:x", 0.0, 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN) # CreateFaceDownTask : FlipCardBehavior 0,5 s
		tw.chain().tween_callback(func():
			face.visible = false
			back.visible = true)
		tw.chain().tween_property(holder, "scale:x", 1.0, 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.chain().tween_property(holder, "position", Vector2(72.0, 972.0) - back.size / 2.0, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT) # cs:126 : x = bord gauche + 0,05 L, y = 0,9 H
		tw.tween_property(holder, "scale", Vector2.ONE * (0.375 / sc), 0.5)
		tw.tween_property(holder, "rotation_degrees", 90.0, 0.5)
		tw.chain().tween_callback(fx.finir) # EmitParticles = false (cs:137) : les particules vivantes finissent leur vie
		tw.chain().tween_property(holder, "modulate:a", 0.0, 0.3)
		tw.chain().tween_callback(holder.queue_free)

## DrawCardEmitter.CreateSingleCardDrawTask (DrawCardEmitter.cs:147-165) : la carte part de x = -0,5 L (:23) et glisse en X jusqu'a sa place au centre (0,5 s, CubicEase = EaseOut), se retourne (0,5 s, :157),
## attend 2 s + 0,1 s x rang (:157,100) puis rejoint la main (Attach, :162). La main reelle est reconstruite a part : les cartes qu'elle recoit restent cachees (_draw_hide) jusqu'a l'arrivee.
func _show_draw(cards: Array) -> void:
	var n := cards.size()
	var sc := lerpf(0.37, 1.0, 1.0 / float(n)) # DrawCardEmitter.cs:107
	var csz := UiKit.ZOOM_CARD * sc
	for i in n:
		var card: Dictionary = cards[i]
		var cid := str(card.get("id", ""))
		_draw_hide[cid] = int(_draw_hide.get(cid, 0)) + 1
		var holder := Control.new()
		holder.name = "DrawnCard"
		holder.set_meta("draw_id", cid) # le tutoriel y retrouve la carte piochee (TutorialOverlay._drawn_holder)
		holder.add_to_group("drawn_card")
		holder.tree_exiting.connect(_draw_release.bind(holder, cid)) # filet de securite : un vol interrompu rend quand meme sa carte a la main
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var back := UiKit.zoom_back("back-spell" if bool(card.get("isSpell", false)) else "back-room", csz)
		var face := UiKit.zoom_card(card, csz)
		face.visible = false
		holder.add_child(back)
		holder.add_child(face)
		holder.size = back.size
		holder.pivot_offset = back.size / 2.0
		var cx := lerpf(400.0, 1490.0, float(i + 1) / float(n + 1))
		holder.position = Vector2(-480.0, 540.0) - back.size / 2.0 # DrawInitialPosition (DrawCardEmitter.cs:23) : y = VirtualHeight x 0,5 ; tut_63 et adv_drawn_spell_teleportation_zoom_center : cadre noir y 296..783
		_ui_layer.add_child(holder)
		# Particules de la pioche : EmitParticles = true des la creation de la carte (DrawCardEmitter.cs:153), jusqu'a Attach a la main (CardManagerComponent.cs:108, _draw_land).
		# Emetteur 0,9 x la carte (CardEntity.cs:88-91), derriere elle ; frere du holder (qui se retourne en echelle X) : il suit seulement son centre.
		var fx := ApkParticles.creer(_ui_layer, back.size * ApkParticles.ECHELLE)
		fx.position = holder.position + back.size * 0.5
		fx.suit = holder
		fx.set_emit(true)
		_ui_layer.move_child(fx, holder.get_index())
		holder.set_meta("fx", fx)
		var tw := holder.create_tween()
		tw.tween_property(holder, "position:x", cx - back.size.x / 2.0, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT) # CubicEase sans mode = EaseOut (:156 ; EasingFunctionBase.cs:8)
		tw.tween_callback(func(): _play_sfx("res://assets/audio/sfx/ui_card_slide_up.wav")) # FlipCardBehavior.cs:113
		tw.tween_property(holder, "scale:x", 0.0, 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN) # FlipCardBehavior 0,5 s (CardEntity.cs:72), pivot en pi / 2
		tw.tween_callback(func():
			back.visible = false
			face.visible = true)
		tw.tween_property(holder, "scale:x", 1.0, 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.tween_interval(2.0 + 0.1 * float(i))
		tw.tween_callback(_draw_land.bind(holder, cid))

## Attach a la main (DrawCardEmitter.cs:161-162, ui_card_slide_general) : la carte rejoint sa place dans la main (CardMoveBehavior : lerp 0,009 x ms par image, ~0,3 s pour 95 % du trajet, CardMoveBehavior.cs:13,129-133),
## puis la vraie carte de la main (cachee jusque-la) apparait.
func _draw_land(holder: Control, cid: String) -> void:
	_play_sfx("res://assets/audio/sfx/ui_card_slide_general.wav")
	var fx = holder.get_meta("fx", null) # Attach : EmitParticles = false (CardManagerComponent.cs:108) ; les particules vivantes finissent leur vie
	if fx != null and is_instance_valid(fx):
		(fx as ApkParticles).finir()
	var dest: CardUI = null
	for c in hand_layer.get_children():
		var cu := c as CardUI
		if cu != null and cu.has_meta("draw_id") and str(cu.get_meta("draw_id")) == cid and not cu.has_meta("draw_claimed"):
			cu.set_meta("draw_claimed", true)
			dest = cu
			break
	var tw := holder.create_tween()
	if dest != null:
		tw.tween_property(holder, "position", dest.position + dest.size / 2.0 - holder.size / 2.0, DRAW_LAND).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(holder, "scale", dest.size / holder.size, DRAW_LAND).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(holder, "rotation_degrees", dest.rotation_degrees, DRAW_LAND)
	else:
		tw.tween_property(holder, "modulate:a", 0.0, DRAW_LAND)
	tw.tween_callback(func():
		_draw_release(holder, cid)
		holder.queue_free()
		refresh())

## La carte piochee a fini son vol (ou son holder disparait) : sa vraie carte de la main redevient visible. Une seule fois par holder.
func _draw_release(holder: Control, cid: String) -> void:
	if holder.has_meta("released"):
		return
	holder.set_meta("released", true)
	_draw_hide[cid] = maxi(int(_draw_hide.get(cid, 0)) - 1, 0)
	if int(_draw_hide[cid]) == 0:
		_draw_hide.erase(cid)

## Coupe toute pioche en vol (changement de siege) : holders liberes, plus aucune carte de la main cachee.
func _draw_clear() -> void:
	for h in get_tree().get_nodes_in_group("drawn_card"):
		h.set_meta("released", true)
		h.queue_free()
	for h in get_tree().get_nodes_in_group("discarded_card"):
		h.queue_free()
	_draw_hide.clear()

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
	_warn_t = 0.0
	if not skip_animations: # Show() : opacite 0,5 -> 1 et echelle 0,7 -> 1 en 0,5 s, CubicEase EaseInOut (HideWhenTouchBehavior.cs:25-33,72-82,158-168)
		b.pivot_offset = b.size / 2.0
		b.modulate.a = 0.5
		b.scale = Vector2(0.7, 0.7)
		var tw := b.create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(b, "modulate:a", 1.0, WARN_TIME)
		tw.tween_property(b, "scale", Vector2.ONE, WARN_TIME)

func _warn_hide() -> void:
	if _warn != null and is_instance_valid(_warn):
		_ui_layer.remove_child(_warn)
		_warn.queue_free()
	_warn = null
	_warn_t = 0.0

func _tick_warn(delta: float) -> void:
	if _warn != null:
		_warn_t += delta

## ZoomOutWhenTouchOutside (HideWhenTouchBehavior.cs:101-123) : un appui hors de la bulle, une fois entree, la ferme (fondu de sortie 0,5 s) ; elle ne se ferme jamais d'elle-meme.
func _warn_outside(event: InputEvent) -> void:
	if _warn == null or not is_instance_valid(_warn) or _warn_t < WARN_TIME or _warn.has_meta("closing"):
		return
	if not (event is InputEventMouseButton and (event as InputEventMouseButton).pressed) or _warn.get_global_rect().has_point((event as InputEventMouseButton).position):
		return
	if skip_animations:
		_warn_hide()
		return
	var w := _warn
	w.set_meta("closing", true)
	var tw := w.create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(w, "modulate:a", 0.0, WARN_TIME)
	tw.tween_callback(func():
		if _warn == w:
			_warn_hide())

## DoneButtonEntity.cs:99-107 : minuteur de 5 s en boucle depuis l'apparition du bouton, qui lance PulseBehavior(halt_button_pulse, 3) (PulseBehavior.cs : 3 copies decalees de 0,3 s,
## 2 s chacune, echelle 0,9 -> 1,3 et opacite 1 -> 0 en CubicEase = EaseOut). La barre jaune sous le bouton n'existe qu'avec les delais de tour (70 s, desactives ici) : G-20.
func _tick_pulse(delta: float) -> void:
	if not pass_shown() or btn_pass.button_pressed or skip_animations:
		_pulse_t = 0.0
		return
	_pulse_t += delta
	if _pulse_t < 5.0:
		return
	_pulse_t -= 5.0
	_pulse_rings(btn_pass, UI_DIR + "halt_button_pulse.webp", Vector2(170, 73), btn_pass.size / 2.0, 3)

## PulseBehavior.cs : n copies de la texture centrees en `centre`, la k-ieme part 0,3 s x (k + 1) apres l'appel, 2 s chacune : echelle 0,9 -> 1,3 et opacite 1 -> 0 en CubicEase (EaseOut).
func _pulse_rings(host: Control, path: String, sz: Vector2, centre: Vector2, n: int) -> void:
	for r in n:
		var ring := UiKit.image(host, path, centre - sz / 2.0, sz)
		ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ring.pivot_offset = sz / 2.0
		ring.scale = Vector2(0.9, 0.9)
		ring.modulate.a = 0.0
		var tw := ring.create_tween().set_parallel(true)
		var d := 0.3 * (r + 1)
		tw.tween_callback(func(): ring.modulate.a = 1.0).set_delay(d)
		tw.tween_property(ring, "scale", Vector2(1.3, 1.3), 2.0).set_delay(d).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(ring, "modulate:a", 0.0, 2.0).from(1.0).set_delay(d).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.chain().tween_callback(ring.queue_free)

## PASS TURN / DONE! apparait et disparait en fondu lineaire de 0,15 s (DoneButtonEntity.cs:93 fadeTime ; ButtonBaseEntity.cs:166-175). Seuls les changements d'etat animent (refresh() est appele souvent).
## Etat voulu du bouton (il reste visible jusqu'a la fin de son fondu de sortie).
func pass_shown() -> bool:
	return (_pass_want if _pass_tw != null else btn_pass.visible) and btn_pass.get_parent().is_visible_in_tree()

func _set_pass_visible(want: bool) -> void:
	if want == (_pass_want if _pass_tw != null else btn_pass.visible):
		return
	_pass_want = want
	if _pass_tw != null:
		_pass_tw.kill()
		_pass_tw = null
	if skip_animations or not is_inside_tree():
		btn_pass.visible = want
		btn_pass.modulate.a = 1.0
		return
	if want and not btn_pass.visible:
		btn_pass.modulate.a = 0.0
		btn_pass.visible = true
	_pass_tw = btn_pass.create_tween()
	_pass_tw.tween_property(btn_pass, "modulate:a", 1.0 if want else 0.0, 0.15)
	if not want:
		_pass_tw.tween_callback(func(): btn_pass.visible = false)
	_pass_tw.tween_callback(func(): _pass_tw = null)

## PASS TURN (tour de construction pas encore fait) / DONE! (pose faite ou fenetre de sorts apres la derniere construction) : DoneButtonBehavior.cs:25-40.
func _style_pass_button(done: bool) -> void:
	var b := btn_pass as TextureButton
	b.texture_normal = _tex(TEX_DONE if done else TEX_PASS)
	b.texture_pressed = _tex(UI_DIR + ("done_button_unlimited_pressed.webp" if done else "pass_button_pressed.webp"))

## GamePlayBaseScene.cs:1071-1078 : tous les humains morts en fin de tour -> OnUserPlayerDefeat, meme si les IA continuent (hors ligne seulement).
func _all_humans_dead(G: Dictionary) -> bool:
	if _is_online() or str(G.get("phase", "")) in ["boss", "adventure", "bait"]:
		return false
	var n := 0
	for pid in G.get("players", {}):
		var q: Dictionary = G["players"][pid]
		if not bool(q.get("isAI", false)):
			if not bool(q.get("eliminated", false)):
				return false
			n += 1
	return n > 0

## Fin de partie (WinnerScene / LoseScene) : bandeau noir, boss gagnant, cristaux, OK -> retour a l'ecran titre.
func _show_gameover(G: Dictionary) -> void:
	if _animating_hero or (_gameover != null and is_instance_valid(_gameover)):
		return # la derniere traversee se joue d'abord (refresh a sa fin)
	_win_hide()
	_warn_hide()
	_drag_clear()
	_zoom_hide()
	phase_banner.visible = false # APK : plus de bandeau de phase sur l'ecran de fin
	var w := int((G["gameOver"] as Dictionary).get("winner", -1)) if G.get("gameOver") != null else -1 # -1 : defaite des humains, partie en cours
	var players: Dictionary = G.get("players", {})
	var boss = (players[w] as Dictionary).get("boss") if players.has(w) else null
	if not _over_sting_played:
		_over_sting_played = true
		if w == view_pid: # WinnerScene.cs:121-132 : sting a t = 0 (musique x0,5), puis 0,5 s plus tard la voix de victoire du boss gagnant
			AudioManager.play_sting("sting_player_win")
			var vid := AudioManager.boss_voice(str((boss as Dictionary).get("id", "")) if boss != null else "", "victory")
			get_tree().create_timer(0.5).timeout.connect(func(): AudioManager.play_sfx(vid))
		else:
			AudioManager.play_sting("sting_player_lose") # LoseScene.cs:21 (PlayWithMusicFade)
	var lose: bool = w < 0 or ((_apk_flow() or _is_online()) and w != _my_pid())
	_gameover = GameOverBanner.new()
	_gameover.z_index = 90
	add_child(_gameover)
	UiKit.cross_fade_in(_gameover) # WinnerScene / LoseScene = modales : CrossFade 0,2 s (GamePlayBaseScene.cs:889,895 ; ModalSceneService.cs:112-115)
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

## Echap = touche Retour Android : GamePlayBaseScene.NavigatedBack ouvre la pause (:1172-1179), PauseScene.NavigatedBack ouvre QUIT GAME? (:132-137),
## QuitGameScene.NavigatedBack = CANCEL (:36-46). Les ecrans qui ont une fleche (regles, galerie, reglages) sont traites avant, par Main._unhandled_key_input.
func back_pressed() -> void:
	if _gameover != null and is_instance_valid(_gameover):
		return
	if _popup_kind == "menu":
		_open_quit_confirm()
	else:
		_open_game_menu() # aussi depuis QUIT GAME? (CANCEL) et depuis une partie sans fenetre

func _close_menu() -> void:
	_play_sfx("res://assets/audio/sfx/ui_button_goback.wav")
	_popup_close()
	refresh() # un choix en attente (cache par le menu) reapparait

func _open_game_menu() -> void:
	_play_sfx("res://assets/audio/sfx/ui_button_select.wav")
	var pop := _popup_begin("menu", 0.72)
	var menu := InGameMenu.new()
	pop.add_child(menu)
	UiKit.cross_fade_in(pop) # PauseScene = modale : CrossFade 0,2 s (GamePlayBaseScene.cs:1093-1099 ; ModalSceneService.cs:89,112-115)
	menu.resume_requested.connect(_close_menu)
	menu.rules_requested.connect(_open_rules)
	menu.quit_requested.connect(_open_quit_confirm)
	menu.speed_changed.connect(func(): _speed = _speed_factor())

## RULES : la visionneuse des regles (RulesViewer, la meme que le menu principal) se superpose au plateau ; fermer = retour au menu pause, toujours ouvert dessous.
func _open_rules() -> void:
	if _rules != null and is_instance_valid(_rules):
		return
	_play_sfx("res://assets/audio/sfx/ui_button_select.wav")
	_rules = RulesViewer.new()
	_rules.z_index = 110 # devant le voile du mode ciblage
	_rules.closed.connect(func(): _rules = null)
	add_child(_rules)

## QuitGameScene (MessageBoxScene, :16-27) : bande winner_bg, titre « QUIT GAME? », « ARE YOU SURE YOU WANT TO QUIT? » (QUIT? en or), boutons CANCEL (0,35) / QUIT (0,65) a 0,56 de la hauteur.
func _open_quit_confirm() -> void:
	var pop := _popup_begin("quit", 0.7)
	UiKit.cross_fade_in(pop)
	_img(pop, "res://assets/ui/gradients/winner_bg.webp", Vector2(960.0 - 956.5, 486.0 - 94.0), Vector2(1913.0, 188.0))
	_img(pop, "res://assets/ui/gradients/bg_txt.webp", Vector2(394, 75.6 - 32.0))
	var lines: Array = [["QUIT GAME?", 42, Color("cdb15f"), 960.0, 75.6 - 32.0, 64.0]]
	var m1 := "ARE YOU SURE YOU WANT TO "
	var w1 := _fa.get_string_size(m1, HORIZONTAL_ALIGNMENT_LEFT, -1, 32).x
	var w2 := _fa.get_string_size("QUIT?", HORIZONTAL_ALIGNMENT_LEFT, -1, 32).x
	lines.append([m1, 32, Color.WHITE, 960.0 - (w1 + w2) / 2.0 + w1 / 2.0, 480.6 - 40.0, 80.0])
	lines.append(["QUIT?", 32, Color("cdb15f"), 960.0 + (w1 + w2) / 2.0 - w2 / 2.0, 480.6 - 40.0, 80.0])
	for ln in lines:
		var l := _lbl(pop, ln[0], ln[1], ln[2], Vector2(float(ln[3]) - 800.0, ln[4]), 1600.0, _fa, HORIZONTAL_ALIGNMENT_CENTER)
		l.add_theme_constant_override("outline_size", 0)
		l.size = Vector2(1600.0, ln[5])
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	for spec in [["CANCEL", 744.0, _open_game_menu], ["QUIT", 1176.0, _confirm_quit]]:
		var b := _tex_button(pop, UI_DIR + "bt_apply_effects.webp", UI_DIR + "bt_apply_effects_pressed.webp", Vector2(float(spec[1]) - 200.0, 604.8 - 51.5), Vector2(400, 103))
		var l := _lbl(b, spec[0], 32, Color.WHITE, Vector2.ZERO, 400.0, _fa, HORIZONTAL_ALIGNMENT_CENTER)
		l.add_theme_constant_override("outline_size", 0)
		l.size = Vector2(400, 103)
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		var cb: Callable = spec[2]
		b.pressed.connect(func():
			_play_sfx("res://assets/audio/sfx/ui_button_select.wav")
			cb.call())

func _confirm_quit() -> void:
	_popup_close()
	if on_exit_callback.is_valid():
		on_exit_callback.call()

# ---------------------------------------------------------------------------------------------------------------------
# Zooms de pile et carrousel central (CardZoomComponent + SlotDetailEntity + CarrouselVerticalComponent ; MiddleCarrouselEntity)
# ---------------------------------------------------------------------------------------------------------------------

const STACK_Y := [-700.0, 0.0, 140.0, 175.0, 210.0, 245.0]   # CarrouselVerticalComponent.cs:44-51 : la carte choisie en 1, la precedente s'enfuit vers le haut en 0
const STACK_K := [1.4, 1.2, 1.0, 1.0, 1.0, 1.0]
const STACK_A := [0.0, 1.0, 0.8, 0.6, 0.4, 0.0]
const SLIDE_RECT := Rect2(184, 296, 1523, 400)               # bandeau du carrousel central (mesure APK)
const SLIDE_CX := 940.0                                      # MiddleCarrouselEntity (960, 498) + CarouselShowEntity.LocalX -20
const SLIDE_CY := 498.0
const BOSS_ZOOM_BOTTOM := [661.0, 1076.0]                    # bas du zoom du boss [adverse, mien] : bord droit 1730 ; le mien = LEVEL UP (frame APK), l'adverse 415 px plus haut (sprites 355 / 770)

## Bandeau sombre a deux filets or du carrousel central (MiddleCarouselAnimationBehavior.CreateBackPanel) ; rendu dans un conteneur qui s'ouvre / se ferme en hauteur.
func _carousel_band(parent: Control) -> Control:
	var box := Control.new()
	box.name = "Band"
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.position = SLIDE_RECT.position
	box.size = SLIDE_RECT.size
	box.pivot_offset = SLIDE_RECT.size / 2.0
	parent.add_child(box)
	_rect(box, Color(0, 0, 0, 0.88), Vector2.ZERO, SLIDE_RECT.size)
	for gy in [0.0, SLIDE_RECT.size.y]:
		_rect(box, Color(0.667, 0.533, 0.2), Vector2(0, gy), Vector2(SLIDE_RECT.size.x, 2))
	return box

## Place la pile verticale (index flottant = carte choisie) : CarrouselComponent interpole positions, echelles et opacites entre les rangs voisins.
func _zoom_stack_layout() -> void:
	var st: Dictionary = _zoom.get_meta("stack")
	var k: float = st["k"]
	var idx: float = st["idx"]
	for i in _zoom.get_child_count():
		var z := _zoom.get_child(i) as Control
		var rel := float(i) - idx + 1.0
		z.visible = rel >= 0.0 and rel <= 5.0
		if not z.visible:
			continue
		var a := mini(int(floorf(rel)), 4)
		var f := rel - float(a)
		z.position = Vector2(-z.size.x / 2.0, lerpf(STACK_Y[a], STACK_Y[a + 1], f) * k - z.size.y / 2.0)
		z.scale = Vector2.ONE * lerpf(STACK_K[a], STACK_K[a + 1], f)
		z.modulate.a = lerpf(STACK_A[a], STACK_A[a + 1], f)
		z.z_index = 10 - roundi(rel)

## Zoom d'une pile : cartes empilees verticalement autour de `center` (la premiere devant, a l'echelle 1,2), le reste depasse en dessous ; glisser / molette = defiler.
## Reste ouvert jusqu'a un appui hors de la zone (TouchOutBehavior).
func _zoom_stack(cards: Array, center: Vector2, sz: Vector2, k: float) -> void:
	_zoom_hide()
	var root := Control.new()
	root.name = "StackZoom"
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.position = center
	root.set_meta("levelup", true) # survit aux refresh jusqu'au clic suivant (_input)
	root.set_meta("stack", {"idx": 0.0, "k": k, "rect": Rect2(center - Vector2(200, 300) * k, Vector2(400, 600) * k)}) # collider 400 x 600 de SlotDetailEntity ; k = echelle de l'entite x 1,3 (AppearBehavior)
	for c in cards:
		var z := UiKit.zoom_card(c, sz)
		z.pivot_offset = z.size / 2.0
		root.add_child(z)
	_zoom = root
	_ui_layer.add_child(root)
	_zoom_stack_layout()
	_zoom_appear()
	hand_layer.modulate = Color(0.6, 0.6, 0.6)

## Glisser vertical (CarrouselDragBehavior) et molette dans la zone du zoom de pile ; vrai = evenement consomme. Relachement : la carte la plus proche se cale.
func _zoom_stack_input(event: InputEvent) -> bool:
	var st: Dictionary = _zoom.get_meta("stack")
	var rect: Rect2 = st["rect"]
	var n := _zoom.get_child_count()
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed and rect.has_point(mb.position):
				st["drag"] = {"y": mb.position.y, "i0": float(st["idx"])}
				return true
			if not mb.pressed and st.has("drag"):
				st.erase("drag")
				_zoom_stack_snap(roundf(float(st["idx"])))
				return true
		elif mb.pressed and (mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN) and rect.has_point(mb.position):
			_zoom_stack_snap(clampf(roundf(float(st["idx"])) + (1.0 if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN else -1.0), 0.0, float(n - 1)))
			return true
	elif event is InputEventMouseMotion and st.has("drag"):
		var d: Dictionary = st["drag"]
		st["idx"] = clampf(float(d["i0"]) - ((event as InputEventMouseMotion).position.y - float(d["y"])) / (STACK_Y[2] * float(st["k"])), 0.0, float(n - 1))
		_zoom_stack_layout()
		return true
	return false

func _zoom_stack_snap(target: float) -> void:
	var st: Dictionary = _zoom.get_meta("stack")
	var zoom := _zoom
	if skip_animations:
		st["idx"] = target
		_zoom_stack_layout()
		return
	zoom.create_tween().tween_method(func(v: float):
		st["idx"] = v
		_zoom_stack_layout(), float(st["idx"]), target, 0.15)

## Bordure de capacite sur une carte zoomee (CardAttributesComponent.UpdateRoomAbilityBorder) : un appui dessus resout la capacite (_input). `host` = la carte, `zc` sa taille hors cadre.
func _zoom_ability(host: Control, zc: Vector2, pad: float, di: int, cands: Array) -> void:
	var k := zc / Vector2(350.0, 488.0) # meme repere que DungeonSlot._update_glow : zone de texte a 116/488 sous le centre
	var ab := Rect2(Vector2(pad, pad) + zc / 2.0 + Vector2(0, 116.0 * k.y) - Vector2(306, 102) * k / 2.0, Vector2(306, 102) * k)
	var glow := UiKit.image(host, "res://assets/ui/ingame/card_border_ability_glow.webp", ab.position, ab.size)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	DungeonSlot.add_rings(glow, ab.size) # PulseBehavior : 3 anneaux qui grossissent (CardAttributesComponent.cs:324-327), relances toutes les 3 s (SimpleTimerBehavior, cs:328-331)
	_zoom.set_meta("ability", {"rect": ab, "di": di, "cands": cands, "host": host})

## Clic sur une pile de salles (GamePlayBaseScene.DungeonFrame_ShowRoomSlotDetail, cs:681-718) : toutes les salles de la pile, la plus haute d'abord, a la hauteur de l'emplacement
## (y borne a 400..600). `cands` : coups de capacite de la salle du dessus (zoom d'une salle activable).
func _slot_zoom(pid: int, di: int, cands := []) -> void:
	if _modal_open() or (_popup != null and is_instance_valid(_popup)) or not _tgt.is_empty():
		return
	var dungeon: Array = ((game_manager.G.get("players", {}) as Dictionary).get(pid, {}) as Dictionary).get("dungeon", [])
	if di < 0 or di >= dungeon.size():
		return
	var cards: Array = (dungeon[di] as Array).duplicate()
	cards.reverse()
	if cards.is_empty() or bool((cards[0] as Dictionary).get("faceDown", false)):
		return # pose en attente ou salle adverse face cachee : rien a montrer
	var slots: Array = _dungeon_slots if pid == view_pid else _foe_slots
	var j := di + maxi(0, CardDB.DUNGEON_SLOTS - dungeon.size())
	var at := Vector2(960.0, 500.0)
	if j < slots.size():
		at = (slots[j] as Control).get_global_rect().get_center()
	var sz := UiKit.ZOOM_CARD * 1.3 # AppearBehavior : le conteneur passe a 1,3 (entite a l'echelle 1, cartes a 1) ; frame APK tap_own_dungeon_room : carte du dessus 550 px de large
	var half := sz.x * 0.6 + UiKit.ZOOM_PAD
	_zoom_stack(cards, Vector2(clampf(at.x, 190.0 + half, 1707.0 - half), clampf(at.y, 400.0, 600.0)), sz, 1.3)
	if not cands.is_empty():
		_zoom_ability(_zoom.get_child(0), sz, UiKit.ZOOM_PAD, di, cands)

## Clic sur le boss d'un couloir (DungeonFrameEntity.cs:269 -> GamePlayBaseScene.ShowZoomCard, cs:1221-1244) : sa carte x1,3, bord droit a 1730 ; avec des sorts gardes
## jusqu'a la fin de la partie (Boss.UntilEndOfTurnSpells) : pile boss + sorts a 0,8.
func _boss_zoom(lane: int) -> void:
	var pid := view_pid if lane == 1 else foe_pid
	var pl: Dictionary = (game_manager.G.get("players", {}) as Dictionary).get(pid, {})
	var boss = pl.get("boss") if lane == 1 else _opp_boss(pid)
	if boss == null or _modal_open() or not _tgt.is_empty():
		return
	var cards: Array = [boss]
	for e in (pl.get("untilEndSpells", []) as Array):
		cards.append((e as Dictionary).get("card", {}))
	var bottom: float = BOSS_ZOOM_BOTTOM[lane]
	if cards.size() > 1:
		var sz := UiKit.ZOOM_CARD * 0.832 # 1,3 (Appear) x 0,8 (entite) x 0,8 (cartes creees a maxScale, CardZoomComponent.cs:40)
		_zoom_stack(cards, Vector2(1730.0 - sz.x * 0.6 - UiKit.ZOOM_PAD, bottom - 316.0 - (100.0 if lane == 1 else 0.0)), sz, 1.04)
		return
	_zoom_hide()
	_zoom = UiKit.zoom_card(boss, UiKit.ZOOM_CARD * 1.3)
	_zoom.set_meta("levelup", true)
	_zoom.position = Vector2(1730.0 - _zoom.size.x, bottom - _zoom.size.y)
	_ui_layer.add_child(_zoom)
	_zoom_appear()

## Clic sur la file d'entree (DungeonFrameEntity.cs:382 -> DungeonFrame_ShowDungeonQueue, cs:720-745) : deux heros ou plus = diaporama, un seul = zoom x1,3 au centre.
func _queue_clicked(lane: int, ents: Array) -> void:
	if ents.is_empty() or _modal_open() or (_popup != null and is_instance_valid(_popup)) or not _tgt.is_empty():
		return
	var box: Control = (_lane[lane] as Dictionary)["entrance"]
	var keep := Rect2(box.get_global_rect().get_center() - Vector2(150, 100), Vector2(300, 200)) # collider 300 x 200 de la file
	var heroes := ents.duplicate()
	heroes.reverse()
	if heroes.size() > 1:
		_slide_toggle(heroes, keep)
	elif _slide != null and is_instance_valid(_slide):
		_slide_hide()
	else:
		_zoom_hide()
		_zoom = UiKit.zoom_card(heroes[0], UiKit.ZOOM_CARD * 1.3)
		_zoom.set_meta("levelup", true)
		_zoom.position = Vector2(STACK_CX, 498.0) - _zoom.size / 2.0
		_ui_layer.add_child(_zoom)
		_zoom_appear()
		hand_layer.modulate = Color(0.6, 0.6, 0.6)

## Diaporama du carrousel central (MiddleCarouselShowComponent.ShowSlideShow / CarouselShowComponent) : bandeau qui s'ouvre en 0,5 s, cartes 0,7 x qui arrivent d'en bas
## l'une apres l'autre (1 s, CubicEase) et se rangent en eventail plat ; la carte survolee (apres 0,3 s) passe a 1,2 x, 80 px plus haut. Un appui hors du bandeau le ferme.
## `keep` : zone du bouton / de la file qui l'a ouvert (son propre appui le referme).
func _slide_toggle(cards: Array, keep: Rect2) -> void:
	if _slide != null and is_instance_valid(_slide):
		_slide_hide()
		return
	if cards.is_empty():
		return
	_zoom_hide()
	_slide_keep = keep
	_slide_gen += 1
	_slide_sel = -1
	_slide_hot = false
	_slide_cards = []
	_slide = Control.new()
	_slide.name = "Slideshow"
	_slide.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_slide.size = Vector2(1920, 1080)
	_slide.z_index = 30
	add_child(_slide)
	var band := _carousel_band(_slide)
	if not skip_animations:
		band.scale.y = 0.0
		band.create_tween().tween_property(band, "scale:y", 1.0, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	var n := cards.size()
	var gen := _slide_gen
	for i in n:
		var cu: CardUI = _card_scene.instantiate()
		cu.default_size = BIG_CARD
		_slide.add_child(cu)
		cu.size = BIG_CARD
		cu.pivot_offset = BIG_CARD / 2.0
		cu.setup(cards[i])
		if cu.border != null:
			cu.border.visible = false
		cu.mouse_entered.disconnect(cu._on_mouse_entered) # le survol est celui du carrousel (_slide_set)
		cu.mouse_exited.disconnect(cu._on_mouse_exited)
		var idx := i
		cu.mouse_entered.connect(func(): _slide_hover(idx, gen))
		cu.mouse_exited.connect(func(): _slide_unhover(gen))
		cu.position = Vector2(SLIDE_CX, SLIDE_CY + 1080.0) - BIG_CARD / 2.0 # (0, hauteur de l'ecran) dans le repere du carrousel
		cu.visible = false
		_slide_cards.append(cu)
		# AddCarouselCardsBehavior.cs:76-104 : la carte k est ajoutee quand CubicEase(t / 1 s) depasse k / n
		var t := 0.0 if skip_animations else 1.0 - pow(1.0 - float(i) / float(n), 1.0 / 3.0)
		if t <= 0.0:
			_slide_attach(cu)
		else:
			var cid := cu.get_instance_id() # un Object libere capture dans un lambda fait echouer l'appel : on garde l'id
			get_tree().create_timer(t).timeout.connect(func():
				var c = instance_from_id(cid)
				if gen == _slide_gen and c != null:
					_slide_attach(c))

var _slide: Control
var _slide_cards: Array = []
var _slide_sel := -1
var _slide_hot := false
var _slide_gen := 0
var _slide_keep := Rect2()

func _slide_attach(cu: CardUI) -> void:
	cu.visible = true
	_play_sfx("ui_card_slide_general") # AddCarouselCardsBehavior.cs:93
	_slide_layout()

## CardPositionComponent.PositionX/Y/Scale/DrawOrder (cs:105-145) pour les cartes deja arrivees : MaxDistanceBtwCards 900 plafonne a la largeur utile 1200 ; la carte choisie
## laisse la place d'une carte de plus aux suivantes.
func _slide_layout() -> void:
	var live: Array = _slide_cards.filter(func(c): return (c as Control).visible)
	var n := live.size()
	var half := minf(float(n - n % 2) * 900.0, 1200.0) * 0.5
	for i in n:
		var cu: CardUI = live[i]
		var on := i == _slide_sel
		var num := float(n) if (_slide_sel < 0 or on) else float(n + 1)
		var at := i + (1 if (_slide_sel >= 0 and not on and i > _slide_sel) else 0)
		var c := Vector2(SLIDE_CX + lerpf(-half, half, float(at + 1) / (num + 1.0)), SLIDE_CY - (80.0 if on else 0.0))
		var sc := Vector2.ONE * (1.2 / 0.7 if on else 1.0)
		cu.z_index = 100 if on else (n - i if (_slide_sel >= 0 and i > _slide_sel) else i)
		if skip_animations:
			cu.position = c - BIG_CARD / 2.0
			cu.scale = sc
		else:
			CardUI.lerp_vers(cu, "position", c - BIG_CARD / 2.0) # CardMoveBehavior
			CardUI.lerp_vers(cu, "scale", sc)

func _slide_hover(i: int, gen: int) -> void:
	if gen != _slide_gen:
		return
	if _slide_hot:
		_slide_sel = i
		_slide_layout()
		return
	await get_tree().create_timer(0.3).timeout # CardHoverWithDelayBehavior.TimeBeforeHover
	if gen == _slide_gen and i < _slide_cards.size() and (_slide_cards[i] as Control).is_hovered():
		_slide_hot = true
		_slide_sel = i
		_slide_layout()

func _slide_unhover(gen: int) -> void:
	if gen != _slide_gen:
		return
	_slide_sel = -1
	_slide_layout()
	await get_tree().process_frame
	if gen == _slide_gen and not _slide_cards.any(func(c): return (c as Control).is_hovered()):
		_slide_hot = false

func _slide_hide() -> void:
	var s := _slide
	_slide = null
	_slide_gen += 1
	_slide_sel = -1
	if s == null or not is_instance_valid(s):
		return
	if skip_animations:
		s.queue_free()
		return
	var tw := s.create_tween().set_parallel(true) # CarouselShowComponent.CreateDisappearAnimationTask : fondu 0,1 s ; le bandeau se referme en 0,5 s
	for c in s.get_children():
		if c is CardUI:
			(c as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
			tw.tween_property(c, "modulate:a", 0.0, 0.1)
		else:
			tw.tween_property(c, "scale:y", 0.0, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tw.chain().tween_callback(s.queue_free)

## Defausse (GamePlayBaseScene.TopLeftPanel_ShowDiscardPile, cs:748-766) : salles puis sorts defaussees, en diaporama ; un second appui referme.
func _on_discard_pile_pressed() -> void:
	_play_sfx("res://assets/audio/sfx/ui_button_select.wav")
	if _modal_open() or (_popup != null and is_instance_valid(_popup)):
		return
	var decks: Dictionary = game_manager.G.get("decks", {})
	CardDB.sort_discards(decks)
	var cards: Array = []
	for c in (decks.get("roomDiscard", []) as Array) + (decks.get("spellDiscard", []) as Array):
		var d: Dictionary = (c as Dictionary).duplicate()
		d["faceDown"] = false
		cards.append(d)
	if _slide != null and is_instance_valid(_slide):
		_slide_hide()
	elif not cards.is_empty():
		_slide_toggle(cards, discard_btn.get_global_rect())

## APK (GamePlayBaseScene.ShowZoomCard) : LEVEL UP montre mon boss en grand (x1,3), cadre noir 450 x 632 en bas a droite (x 1280..1730, y 444..1076).
func _on_level_up_pressed() -> void: # pas de son propre (TopRightPanelEntity.cs:155) : le zoom joue ui_card_slide_up (_zoom_appear)
	_boss_zoom(1)

## Badge DAMAGE = AIHelper.GetDungeonDamage (AIHelper.cs:95-117) : salles actives, non en attente, degats modifies (GetTopRoomTotalDamage) ;
## defaut conserve : la salle qui suit un BMA017 Minotaur's Maze (dans l'ordre APK = index Godot decroissant) est comptee deux fois.
func _get_total_dungeon_damage(player_dict: Dictionary) -> int:
	var total := 0
	var dungeon: Array = player_dict.get("dungeon", [])
	var prev_maze := false
	for i in range(dungeon.size() - 1, -1, -1):
		var r = BossEngine.active_room(dungeon[i])
		if r == null or bool((r as Dictionary).get("faceDown", false)) or BossEngine.is_room_deactivated(game_manager.G, int(player_dict.get("id", 0)), i):
			prev_maze = false
			continue
		var d := BossEngine.room_damage_with_modifiers(game_manager.G, player_dict, i, null)
		total += d * (2 if prev_maze else 1)
		prev_maze = str((r as Dictionary).get("id", "")) == "BMA017"
	return total
