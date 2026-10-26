extends Control
## Main — menus clones de l'APK 2.2.6 (maquette 1920x1080 : coordonnees absolues relevees sur docs/reference/*.png).
## Ecran titre (TAP TO START) -> menu 2x2 -> HOW MANY PLAYERS? -> SELECT EXPANSIONS ; OPTIONS ; RULES.
## SINGLE PLAYER : 2/3/4 joueurs = vous + 1 a 3 IA ; 5/6 joueurs seulement avec Crash Landing coche (Match.setup_error).
## MULTIPLAYER : PLAY ONLINE (entre amis, salon prive a code de 4 lettres) / PASS AND PLAY ; ecrans dans OnlineMenus.gd (clones de l'APK).
## IN-APP STORE supprime -> RULES ; tout est gratuit et debloque.
## WORLDWIDE (hors APK) : liste des salons publics du serveur, sans comptes ; CREATE PUBLIC GAME = NEW GAME avec le mode « public ».

## Extensions du wiki hors APK (bascule « Options »).
const EXT_PACKS := ["next-level", "minibosses", "crash-landing", "iod"]
## Paquet de l'APK dont les cartes ne se jouent QUE derriere la case wiki (Tools of Hero-Kind : l'APK ne les joue pas) : grise sans la case.
const WIKI_GATED := ["tools"]
## Paquets de l'APK (ExpansionScene) : le jeu de base est toujours present, les autres se combinent librement.
## Boutique supprimee : tout est debloque (ToolsHeroKind, « COMING SOON » dans l'APK, est jouable ici : Match gere deja les Items).
const APK_DECKS := [
	{"id": "tools", "name": "TOOLS OF HERO KIND", "info": "20 item cards", "playable": true, "art": "tools_of_hero_front", "desc": "Adds 20 Item cards. One Item is revealed each turn: Heroes carry Power-Ups, and killing them earns the Reward. The APK leaves the Items inert: they are only played with the wiki expansions option checked."},
	{"id": "players-choice", "name": "THE PLAYER'S CHOICE", "info": "7 bosses, 3 epic heroes, 1 spell", "playable": true, "art": "the_players_choice_front", "desc": "Cards chosen by the community: 7 new Bosses, 3 Epic Heroes and 1 Spell."},
	{"id": "hidden-heroes", "name": "HIDDEN HEROES", "info": "+41 new heroes", "playable": true, "art": "hidden_heroes_front", "desc": "An alternate set of 41 Heroes, hidden in the shadows of Arcadia's dungeons, that replace their base set counterparts."},
	# Extension du wiki hors APK (livret docs/rules « The Next Level » + FAQ) : paquets de heros TNL (noirs, hybrides), defausse amorcee, main de depart de 7.
	{"id": "next-level", "name": "THE NEXT LEVEL", "info": "13 bosses, 43 rooms, 17 spells, 42 heroes - wiki", "playable": true},
	# Extension du wiki hors APK, selectionnable seule (en plus de la bascule « Extensions du wiki » qui active tous les paquets wiki).
	{"id": "crash-landing", "name": "CRASH LANDING", "info": "3 bosses, 13 rooms, 5 spells, 12 heroes - wiki", "playable": true,
		"desc": "3 bosses, 13 rooms, 5 spells and 12 heroes. Unlocks 5 and 6 player games (only with the base game, Hidden Heroes and Tools): nobody is eliminated, and the game ends at 10 souls or when both hero decks run out."},
	# Extension du wiki hors APK (livret « Rise of the Minibosses » + guide officieux) : minibosses (niveaux 1-3), Coins, paquet de heros RMB, 3 Coins au depart.
	{"id": "minibosses", "name": "MINIBOSSES", "info": "12 bosses, 42 rooms, 15 spells, 42 heroes, 10 minibosses - wiki", "playable": true},
	# Mini-extension du wiki hors APK (2017) : 24 Objets + 5 Boss, jouee par IodAbilities (meme mecanique d'Objets que Tools of Hero-Kind). Sans Crash Landing, les Objets Explorer et Banseer Bivan sont ecartes.
	{"id": "iod", "name": "IMPLEMENTS OF DESTRUCTION", "info": "5 bosses, 24 items - wiki", "playable": true},
]

const GameManager = preload("res://godot/scripts/GameManager.gd")
const OnlineClient = preload("res://godot/scripts/OnlineClient.gd")
const OnlineGameManager = preload("res://godot/scripts/OnlineGameManager.gd")
const Profile = preload("res://godot/scripts/Profile.gd")
const UiKit = preload("res://godot/scripts/UiKit.gd")
const CardGallery = preload("res://godot/scripts/CardGallery.gd")
const OnlineMenus = preload("res://godot/scripts/OnlineMenus.gd")
const CountDown = preload("res://godot/scripts/CountDown.gd")
const CreditsScreen = preload("res://godot/scripts/CreditsScreen.gd")
const TutorialOverlay = preload("res://godot/scripts/TutorialOverlay.gd")

const UI := "res://assets/ui/"
const FONT_A := "res://assets/fonts/arcadepix.fnt"   # texte plein (bandeaux, ON/OFF)
const FONT_B := "res://assets/fonts/arcadepix2.fnt"  # texte strie (boutons, libelles)
const GOLD := Color("cdb15f")
## Carrousel « HOW MANY PLAYERS? » : carte du dessus (ou "" = dos) de chaque eventail.
## 5 et 6 (Crash Landing) : pas de frame APK, les trois boss CRL.
const FANS := {2: ["BMA006", "BMA002", ""], 3: ["BMA005", "", ""], 4: ["BMA001", "", ""], 5: ["CRL002", "CRL001", ""], 6: ["CRL001", "CRL002", "CRL003"]}

var game_manager: GameManager
var online: OnlineClient
var board: Control
var menus: OnlineMenus
var use_extensions := false
var apk_decks: Array = [] # ids des paquets APK coches (voir APK_DECKS)
var server_host := "http://127.0.0.1:8000"
var players := 2 # choix courant de « HOW MANY PLAYERS? »
var _setup_players := 2 # nombre de joueurs de l'ecran SELECT EXPANSIONS (pour le message d'erreur 5-6)
var dyn_root: Control # contenu redessine a chaque clic (eventails, tuiles)
var _gray: ShaderMaterial
var _fade_layer: CanvasLayer # voile noir des transitions : survit a _clear()
var _fading := false
var profile := {"name": "Player", "avatar": "avatar_draculord"}

func _ready() -> void:
	game_manager = GameManager.new()
	add_child(game_manager)
	online = OnlineClient.new()
	add_child(online)
	menus = OnlineMenus.new(self)
	online.evicted.connect(_on_seat_taken)
	online.session_lost.connect(_on_session_lost)
	online.link_changed.connect(_on_link_changed)
	if OS.has_feature("web"):
		var origin = JavaScriptBridge.eval("window.location.origin")
		if origin != null and str(origin) != "" and str(origin) != "null":
			server_host = str(origin)
	var settings := Profile.load_settings()
	if not OS.has_feature("web") and settings.has("host") and str(settings["host"]) != "": # web : toujours l'origine de la page (un hote enregistre par une ancienne session ne compte pas)
		server_host = str(settings["host"])
	use_extensions = bool(settings.get("extensions", false))
	apk_decks = (settings.get("decks", []) as Array).filter(func(d): return _deck_playable(str(d)))
	profile = Profile.load_profile()
	_fade_layer = CanvasLayer.new()
	_fade_layer.layer = 128
	add_child(_fade_layer)
	show_title()

func _clear() -> void:
	for c in get_children():
		if c != game_manager and c != online and c != _fade_layer:
			c.queue_free()
	board = null

func _deck_playable(id: String) -> bool:
	for d in APK_DECKS:
		if str((d as Dictionary)["id"]) == id:
			return bool((d as Dictionary)["playable"])
	return false

func _active_sets() -> Array:
	# Les paquets du wiki ne comptent que si l'option « Extensions du wiki » est cochee.
	var sets: Array = apk_decks.filter(func(d): return use_extensions or not (EXT_PACKS.has(d) or WIKI_GATED.has(d)))
	if sets.has("tools"):
		sets.append(ThkAbilities.SET_ID) # case wiki cochee : les Objets et les salles THK se jouent (ThkAbilities)
	if sets.has("players-choice") and use_extensions:
		sets.append(PcwAbilities.SET_ID) # case wiki cochee : les 6 cartes KSA que l'APK ne joue pas (PcwAbilities)
	return sets

# --- transitions ----------------------------------------------------------------

## ColorFadeTransition(noir, NormalTransitionsTime 1,0 s) des Push / Pop entre menus : noir 0 -> 1 en 0,5 s sur l'ecran source, `swap` change d'ecran, puis noir 1 -> 0 en 0,5 s,
## lineaire (DBMBaseScene.cs:19 ; ColorFadeTransition.cs:40-47,61 ; ScreenTransition.cs:28,109). Une transition en cours refuse tout nouvel ordre (ScreenContextManager.cs:233-236).
## Les Push / Pop / To sans transition = coupure nette (ScreenContextManager.cs:237-240 ; fleche de retour : ControlsFactory.cs:238 ; Expansions -> partie : ExpansionScene.cs:117-128) appellent show_* directement.
func go(swap: Callable) -> void:
	if _fading:
		return
	_fading = true
	var veil := ColorRect.new()
	veil.color = Color(0, 0, 0, 0)
	veil.size = Vector2(1920, 1080)
	_fade_layer.add_child(veil) # mouse_filter STOP par defaut : aucun clic pendant la transition
	var tw := create_tween()
	tw.tween_property(veil, "color:a", 1.0, 0.5)
	tw.tween_callback(swap)
	tw.tween_property(veil, "color:a", 0.0, 0.5)
	tw.tween_callback(func():
		veil.queue_free()
		_fading = false)

func is_fading() -> bool:
	return _fading

# --- widgets ---------------------------------------------------------------

func _bg(path: String) -> TextureRect:
	var t := TextureRect.new()
	t.set_anchors_preset(Control.PRESET_FULL_RECT)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_SCALE
	if ResourceLoader.exists(path):
		t.texture = load(path)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t

# --- widgets APK (positions absolues en 1920x1080) -------------------------------

func _font(path: String) -> Font:
	return load(path) as Font

func _tex(path: String, pos: Vector2, sz: Vector2 = Vector2.ZERO) -> TextureRect:
	var t := TextureRect.new()
	t.texture = load(UI + path)
	if sz != Vector2.ZERO:
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_SCALE
		t.size = sz
	t.position = pos
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t

## Texte centre dans le rectangle (pos, sz).
func _lbl(text: String, size: int, color: Color, pos: Vector2, sz: Vector2, font: String = FONT_B, align: int = HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", _font(font))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.position = pos
	l.size = sz
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

## Zone cliquable invisible.
func _hit(pos: Vector2, sz: Vector2, cb: Callable, sfx: String = "ui_button_select") -> Button:
	var b := Button.new()
	for n in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
		b.add_theme_stylebox_override(n, StyleBoxEmpty.new())
	b.focus_mode = Control.FOCUS_NONE
	b.position = pos
	b.size = sz
	if sfx != "":
		b.pressed.connect(func(): AudioManager.play_sfx(sfx))
	b.pressed.connect(cb)
	return b

func _img_btn(normal: String, pressed: String, pos: Vector2, cb: Callable, sz: Vector2 = Vector2.ZERO, sfx: String = "ui_button_select") -> TextureButton:
	var b := TextureButton.new()
	b.texture_normal = load(UI + normal)
	b.texture_pressed = load(UI + pressed)
	if sz != Vector2.ZERO:
		b.ignore_texture_size = true
		b.stretch_mode = TextureButton.STRETCH_SCALE
		b.size = sz
	b.position = pos
	b.pressed.connect(func(): AudioManager.play_sfx(sfx))
	b.pressed.connect(cb)
	return b

## BlinkBehavior (WaveEngine) : opacite lineaire 0 -> 1 en `d` s puis 1 -> 0 en `d` s, en boucle (BlinkBehavior.cs:36-60).
func _blink(n: CanvasItem, d: float) -> void:
	var tw := n.create_tween().set_loops()
	tw.tween_property(n, "modulate:a", 1.0, d)
	tw.tween_property(n, "modulate:a", 0.0, d)

func _flicker(n: Node) -> void:
	var tw := n.create_tween().set_loops()
	tw.tween_property(n, "modulate:a", 0.78, 0.35).set_trans(Tween.TRANS_SINE)
	tw.tween_property(n, "modulate:a", 1.0, 0.25).set_trans(Tween.TRANS_SINE)

## Decor commun (menu_bg + torches + logo) ; back = fleche verte en haut a gauche (Callable invalide = pas de fleche).
## small_logo : MultiplayerScene (CreateLogo(false) : logo_small a taille native, haut-centre a y = 10).
func _apk_screen(back: Callable, small_logo: bool = false) -> void:
	_clear()
	add_child(_bg(UI + "backgrounds/menu_bg.webp"))
	for x in [713, 992]: # torch.webp : socle a (820|1100, 900) dans la maquette
		var t := _tex("gradients/torch.webp", Vector2(x, 690))
		add_child(t)
		_flicker(t)
	if small_logo:
		add_child(_tex("gradients/logo_small.webp", Vector2(616, 10)))
	else:
		add_child(_tex("navigation/bm_logo.webp", Vector2(705, 42), Vector2(540, 218)))
	if back.is_valid():
		add_child(_img_btn("buttons/back_bt.webp", "buttons/back_bt_pressed.webp", Vector2(20, 22), back, Vector2.ZERO, "ui_button_goback"))

func _band(text: String) -> void:
	add_child(_tex("gradients/bg_txt.webp", Vector2(394, 298)))
	add_child(_lbl(text, 21, GOLD, Vector2(394, 298), Vector2(1132, 64), FONT_A))

func _ok_btn(cb: Callable) -> void:
	add_child(_img_btn("buttons/ok_bt.webp", "buttons/ok_bt_pressed.webp", Vector2(1697, 960), cb))

# --- ecran titre -------------------------------------------------------------------

func show_title() -> void:
	_clear()
	AudioManager.play_music("music_main")  # APK IntroScene
	add_child(_bg(UI + "backgrounds/intro_bg.webp"))
	for x in [424, 1094]:
		var c := _tex("gradients/candle.webp", Vector2(x, 484)) # bougies statiques : ControlsFactory.cs:369-377 (aucun scintillement)
		add_child(c)
	var eyes := _tex("gradients/monster_eyes.webp", Vector2(898, 733)) # x 898 : points rouges APK mesures en (924|985, 759) contre (931|993) a 905
	eyes.modulate.a = 0.0 # invisibles au depart : BlinkBehavior(5 s), Opacity MinOpacity 0 (IntroScene.cs:49-55, BlinkBehavior.cs:36-60)
	add_child(eyes)
	_blink(eyes, 5.0)
	add_child(_tex("navigation/bm_logo.webp", Vector2(537, 78), Vector2(850, 343)))
	var tap := _lbl("TAP TO START", 42, Color("bfca7a"), Vector2(547, 600), Vector2(800, 86), FONT_A) # x 547 : texte APK centre vers x 948 (CreateArcadepixTB(515, 620) + decalage 240) ; arcadepix x2 = 42, PistachioColor #bfca7a (IntroScene.cs:57, CustomColors.cs:18)
	tap.modulate.a = 0.0
	add_child(tap)
	_blink(tap, 0.3) # BlinkBehavior(0,3 s) (IntroScene.cs:59)
	add_child(_hit(Vector2.ZERO, Vector2(1920, 1080), func(): go(show_menu), "")) # IntroScene.cs:107-114 (ColorFade 1,0 s) ; aucun son au tap (IntroScene.cs ne joue que la musique, :84)

# --- menu principal ----------------------------------------------------------

## Bouton pierre noire (button.webp) : sprite a taille native 504 x 192, coin haut-gauche a `pos` ; icone a ipos (relatif au sprite, isz = taille si redimensionnee) ; texte centre en x = tcx, releves par correlation sur 11_menu.png
## (sprites en (458|988, 314|524), icones boss/multi/options en (489,369) (1014,377) (482,581)).
func _stone_btn(text: String, icon: String, ipos: Vector2, tcx: float, pos: Vector2, cb: Callable, isz: Vector2 = Vector2.ZERO) -> void:
	var b := _img_btn("buttons/button.webp", "buttons/button_pressed.webp", pos, cb)
	var ic := _tex("navigation/" + icon, ipos, isz)
	b.add_child(ic)
	var lb := _lbl(text, 32, Color.WHITE, Vector2(tcx - 250, 6), Vector2(500, 180), FONT_A) # 32 = arcadepix 21 x 1,5 (ButtonWithDecoratorEntity.cs:39)
	b.add_child(lb)
	# appui : texte et icone descendent de 3 px, pas de changement de couleur (ButtonWithDecoratorEntity.cs:49-51)
	b.button_down.connect(func():
		ic.position.y += 3.0
		lb.position.y += 3.0)
	b.button_up.connect(func():
		ic.position.y -= 3.0
		lb.position.y -= 3.0)
	add_child(b)

func show_menu() -> void:
	online.stop_lobby_poll()
	online.stop_state_poll()
	AudioManager.play_music("music_main")  # APK IntroScene
	_apk_screen(func(): go(show_title)) # la fleche du menu appelle NavigatedBack = Pop ColorFade (MainMenuScene.cs:49-54,199-202)
	_stone_btn("SINGLE PLAYER", "boss_icon.webp", Vector2(31, 55), 294, Vector2(458, 314), _solo_pressed) # MainMenuScene.cs:84-87
	_stone_btn("MULTIPLAYER", "boss_multi_icon.webp", Vector2(26, 63), 329, Vector2(988, 314), func(): go(show_multi)) # MainMenuScene.cs:92-104
	_stone_btn("OPTIONS", "options_icon.webp", Vector2(24, 57), 269, Vector2(458, 524), func(): go(show_options)) # MainMenuScene.cs:107-112
	_stone_btn("RULES", "rules_icon.webp", Vector2(23, 46), 308, Vector2(988, 524), func(): go(show_rules), Vector2(96, 96)) # icone 64 -> 96 px : encre 80 px de haut comme inapp_icon (60 x 81) ; emplacement du store : MainMenuScene.cs:114-119

# --- solo : HOW MANY PLAYERS? -------------------------------------------------

## SINGLE PLAYER (MainMenuScene.cs:60-88) : au 1er lancement l'APK propose le tutoriel (OK -> GamePlayTutScene sans transition ; CANCEL -> drapeau a faux, puis le choix
## du nombre de joueurs) ; ensuite le bouton va directement a HOW MANY PLAYERS?.
func _solo_pressed() -> void:
	if not Profile.first_gameplay():
		go(show_solo_count)
		return
	_confirm_box("TUTORIAL", "DO YOU WANT TO PLAY A TUTORIAL GAME?", start_tutorial, func():
		Profile.set_first_gameplay(false)
		go(show_solo_count))

## ConfirmationBoxScene : meme boite que OnlineMenus.msg_box (voile 0,7, bande winner_bg, titre dore sur bg_txt, message x 1,5) avec deux boutons OK / CANCEL
## (ConfirmationBoxScene.cs : centres a 0,35 et 0,65 de la largeur, 0,56 de la hauteur = (744 ; 604,8) et (1176 ; 604,8)).
func _confirm_box(title: String, text: String, ok: Callable, cancel: Callable) -> Control:
	var dim := ColorRect.new()
	dim.name = "ConfirmationBox"
	dim.color = Color(0, 0, 0, 0.7)
	dim.size = Vector2(1920, 1080)
	add_child(dim)
	UiKit.cross_fade_in(dim)
	dim.add_child(_tex("gradients/winner_bg.webp", Vector2(960.0 - 956.5, 486.0 - 94.0), Vector2(1913.0, 188.0)))
	dim.add_child(_tex("gradients/bg_txt.webp", Vector2(394, 75.6 - 32.0)))
	var tl := menus._t(title.to_upper(), 2.0, GOLD, Vector2(394, 75.6 - 32.0), 1132.0, HORIZONTAL_ALIGNMENT_CENTER)
	tl.size.y = 64.0
	tl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	dim.add_child(tl)
	var ml := menus._t(text, 1.5, Color.WHITE, Vector2(160, 480.6 - 40.0), 1600.0, HORIZONTAL_ALIGNMENT_CENTER)
	ml.size.y = 80.0
	ml.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ml.name = "Message"
	dim.add_child(ml)
	for spec in [["Ok", "OK", 744.0, ok], ["Cancel", "CANCEL", 1176.0, cancel]]:
		var cb: Callable = spec[3]
		var b := TextureButton.new()
		b.texture_normal = load(UI + "ingame/bt_apply_effects.webp")
		b.texture_pressed = load(UI + "ingame/bt_apply_effects_pressed.webp")
		b.position = Vector2(float(spec[2]) - 200.0, 604.8 - 51.5)
		b.focus_mode = Control.FOCUS_NONE
		b.name = str(spec[0])
		var l := menus._t(str(spec[1]), 1.5, Color.WHITE, Vector2.ZERO, 400.0, HORIZONTAL_ALIGNMENT_CENTER)
		l.size.y = 103.0
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		b.add_child(l)
		b.pressed.connect(func(): AudioManager.play_sfx("ui_button_select"))
		b.pressed.connect(func():
			dim.queue_free()
			cb.call())
		dim.add_child(b)
	return dim

## Partie tutoriel (GamePlayTutScene) : pioches forcees (GameManager.start_tutorial), TutorialOverlay monte sur le plateau AVANT setup().
func start_tutorial() -> void:
	Profile.set_first_gameplay(false) # GamePlayTutScene.cs:79-86 : le constructeur consomme le drapeau
	_clear()
	game_manager.start_tutorial()
	_open_board(game_manager, true)

## mode : "solo" (vous + IA), "pass" (PASS AND PLAY : tous les sieges humains sur le meme ecran), "online" (NEW GAME : salon prive, nombre de sieges),
## "public" (CREATE PUBLIC GAME de WORLDWIDE : meme parcours, salon visible dans la liste).
func show_solo_count(mode: String = "solo") -> void:
	_apk_screen(func(): _count_back(mode))
	_band("HOW MANY PLAYERS?")
	players = mini(players, Match.max_players(_active_sets())) # 5-6 : seulement si Crash Landing est coche
	if use_extensions and Match.max_players(_active_sets()) < 5: # case wiki cochee, Crash Landing pas encore : on dit ou se debloquent 5-6 joueurs (sans la case wiki, ecran inchange)
		add_child(_note_box("Hint56", "5-6 players: tick Crash Landing in SELECT EXPANSIONS", GOLD, Color.WHITE, Vector2(560, 925), Vector2(800, 52)))
	dyn_root = Control.new()
	add_child(dyn_root)
	_draw_fans()
	_ok_btn(func(): go(func(): show_setup(players, players if mode == "pass" else 1, mode))) # PlayerNumberScene.cs:48-54 (ColorFade 1,0 s)

## Cartouche sombre a bord colore (le decor du menu est clair) ; police par defaut (accents et guillemets absents de arcadepix).
func _note_box(node_name: String, text: String, border: Color, font_color: Color, pos: Vector2, sz: Vector2) -> Panel:
	var box := Panel.new()
	box.name = node_name
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.05, 0.07, 0.94)
	sb.border_color = border
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(12)
	box.add_theme_stylebox_override("panel", sb)
	box.position = pos
	box.size = sz
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 24)
	l.add_theme_color_override("font_color", font_color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size = sz - Vector2(24, 0)
	l.position = Vector2(12, 0)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(l)
	return box

func _count_back(mode: String) -> void:
	match mode:
		"pass": show_multi()
		"online": show_friends()
		"public": menus.show_public()
		_: show_menu()

## Nombres proposes : 2-4, plus 5-6 quand Crash Landing est coche.
func _count_ring() -> Array:
	return [2, 3, 4, 5, 6] if Match.max_players(_active_sets()) >= 5 else [2, 3, 4]

## Carrousel (4 | 2 | 3, ou 6 | 2 | 3 ... avec 5-6) : l'eventail du centre est le choix courant (colore), les autres sont ternes.
func _draw_fans() -> void:
	for c in dyn_root.get_children():
		dyn_root.remove_child(c)
		c.queue_free()
	var ring := _count_ring()
	var i := ring.find(players)
	var k := ring.size()
	for slot in [[ring[(i + k - 1) % k], 577.0, 200.0], [players, 958.0, 310.0], [ring[(i + 1) % k], 1335.0, 200.0]]:
		var n: int = slot[0]
		var cx: float = slot[1]
		var sel: bool = n == players
		dyn_root.add_child(_fan(Vector2(cx, 625 if sel else 600), slot[2], FANS[n], sel))
		if sel:
			dyn_root.add_child(_tex("navigation/bg_number.webp", Vector2(922, 371)))
			dyn_root.add_child(_lbl(str(n), 56, GOLD, Vector2(922, 371), Vector2(77, 77)))
		else:
			dyn_root.add_child(_lbl(str(n), 32, Color.WHITE, Vector2(cx - 32, 415), Vector2(80, 44), FONT_A)) # arcadepix blanc (PlayerNumberDeckEntity.cs:66) ; 32 px donne l'encre 21 x 21 mesuree sur la capture APK (a 42 px : 28 x 28)
			dyn_root.add_child(_hit(Vector2(cx - 110, 480), Vector2(220, 240), func():
				players = n
				_draw_fans()))

func _fan(c: Vector2, h: float, all_ids: Array, sel: bool) -> Control:
	var ids := all_ids.slice(0, 2) if sel else all_ids
	var root := Control.new()
	root.position = c
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rots := [-6.0, 9.0] if sel else [-10.0, 3.0, 8.0]
	for k in range(ids.size() - 1, -1, -1): # le fond d'abord, la carte du dessus en dernier
		var path: String = CardDB.card_image(str(ids[k]), "boss" if ids[k] != "" else "back-boss")
		var t := TextureRect.new()
		t.texture = load(path)
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_SCALE
		t.size = Vector2(h * 0.717, h)
		t.pivot_offset = t.size / 2
		t.position = -t.size / 2 + Vector2(k * (42 if sel else 10), -k * (12 if sel else 2))
		t.rotation_degrees = rots[k]
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if not sel:
			t.material = _gray_mat()
		root.add_child(t)
	return root

func _gray_mat() -> ShaderMaterial:
	if _gray == null:
		var sh := Shader.new()
		sh.code = "shader_type canvas_item;\nvoid fragment() { vec4 c = texture(TEXTURE, UV); float g = dot(c.rgb, vec3(0.3, 0.59, 0.11)) * 0.65; COLOR = vec4(vec3(g), c.a); }"
		_gray = ShaderMaterial.new()
		_gray.shader = sh
	return _gray

# --- SELECT EXPANSIONS ------------------------------------------------------------

func _is_wiki(d: Dictionary) -> bool:
	return EXT_PACKS.has(d["id"])

func show_setup(num_players: int, human_count: int, mode: String = "solo") -> void:
	_apk_screen(func(): show_solo_count(mode))
	_band("SELECT EXPANSIONS")
	_setup_players = num_players
	dyn_root = Control.new()
	add_child(dyn_root)
	_draw_tiles()
	_ok_btn(func():
		if Match.setup_error(num_players, _active_sets()) != "":
			return # 5-6 joueurs avec un paquet non pris en charge : le message est affiche, on ne lance rien
		if mode == "online" or mode == "public":
			await menus.create_room(num_players, mode == "public")
		else:
			start_match(num_players, human_count))

func _draw_tiles() -> void:
	for c in dyn_root.get_children():
		dyn_root.remove_child(c)
		c.queue_free()
	# Jeu de base d'abord (toujours present), puis les paquets APK ; les paquets du wiki seulement avec l'option.
	var tiles: Array = [{"id": "base", "name": "BOSS MONSTER", "info": "", "art": "full_game_front"}]
	tiles.append_array(APK_DECKS.filter(func(d): return use_extensions or not _is_wiki(d)))
	var s := 1.0 if tiles.size() <= 4 else 0.72
	var pitch := 330.7 * s
	var x0 := (1920.0 - ((tiles.size() - 1) * pitch + 285.0 * s)) / 2.0
	for i in tiles.size():
		_draw_tile(tiles[i], Vector2(x0 + i * pitch, 405.0 if s == 1.0 else 430.0), s)
	var err := Match.setup_error(_setup_players, _active_sets())
	if err != "":
		dyn_root.add_child(_note_box("SetupError", err, Color("e0584c"), Color("ff9a8f"), Vector2(300, 872), Vector2(1320, 76)))

func _draw_tile(d: Dictionary, pos: Vector2, s: float) -> void:
	var id := str(d["id"])
	var gated := WIKI_GATED.has(id) and not use_extensions # THK : grise et non selectionnable sans la case wiki
	var on := id == "base" or (apk_decks.has(id) and not gated)
	var w := 285.0 * s
	var h := 453.0 * s
	dyn_root.add_child(_tex("expansions/bg_expansion_selected.webp" if on else "expansions/bg_expansion.webp", pos, Vector2(w, h)))
	if d.has("art"):
		var art := _tex("expansions/%s.webp" % d["art"], pos + Vector2(15, 13) * s, Vector2(249, 304) * s)
		if gated:
			art.material = _gray_mat()
		dyn_root.add_child(art)
	else: # extension du wiki : pas d'illustration, le nom tient lieu de couverture
		dyn_root.add_child(_lbl(str(d["name"]), int(26 * s), GOLD, pos + Vector2(14, 20) * s, Vector2(257, 280) * s, FONT_A))
	if id == "base":
		return
	if not _is_wiki(d): # les infos des paquets du wiki sont trop longues : elles sont dans la fenetre « ? »
		dyn_root.add_child(_lbl(str(d.get("info", "")).to_upper(), int(17 * s), Color.WHITE, pos + Vector2(14, 322) * s, Vector2(257, 62) * s, FONT_A))
	dyn_root.add_child(_hit(pos, Vector2(w, h - 70 * s), func():
		if gated:
			return
		if apk_decks.has(id):
			apk_decks.erase(id)
		else:
			apk_decks.append(id)
		Profile.save_settings(server_host, use_extensions, apk_decks)
		_draw_tiles()))
	dyn_root.add_child(_lbl("?", int(40 * s), GOLD, pos + Vector2(w / 2 - 25, h - 70 * s), Vector2(50, 60) * s))
	dyn_root.add_child(_hit(pos + Vector2(w / 2 - 35, h - 75 * s), Vector2(70, 70) * s, func(): _deck_popup(d)))

func _deck_popup(d: Dictionary) -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.size = Vector2(1920, 1080)
	add_child(dim)
	var close := func(): dim.queue_free()
	dim.add_child(_hit(Vector2.ZERO, Vector2(1920, 1080), close))
	var p := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.04, 0.06, 0.97)
	sb.border_color = GOLD
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(22)
	p.add_theme_stylebox_override("panel", sb)
	p.position = Vector2(397, 205)
	p.size = Vector2(1126, 657)
	dim.add_child(p)
	if d.has("art"):
		dim.add_child(_tex("expansions/%s.webp" % d["art"], Vector2(440, 240), Vector2(310, 378)))
	dim.add_child(_lbl(str(d["name"]), 36, GOLD, Vector2(790, 235), Vector2(620, 60), FONT_A, HORIZONTAL_ALIGNMENT_LEFT))
	var desc := _lbl(str(d.get("desc", d.get("info", ""))).to_upper(), 24, Color.WHITE, Vector2(790, 310), Vector2(660, 400), FONT_A, HORIZONTAL_ALIGNMENT_LEFT)
	desc.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	dim.add_child(desc)
	dim.add_child(_img_btn("expansions/close_panel.webp", "expansions/close_panel_pressed.webp", Vector2(1418, 220), close))

func start_match(num_players: int, human_count: int) -> void:
	_clear()
	game_manager.start_new_game(num_players, human_count, _active_sets())
	_open_board(game_manager)

func _open_board(gm: GameManager, tutorial := false) -> void:
	var board_scene = load("res://godot/scenes/Board.tscn")
	board = board_scene.instantiate()
	board.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(board)
	if tutorial:
		board.mount_tutorial(TutorialOverlay.new())
	board.setup(gm, func(): _leave_board(gm)) # APK LeaveGameplayScene : retour a l'ecran titre (fin de partie : OK ; menu : QUIT GAME)

# --- multi : voir OnlineMenus.gd (MultiplayerScene, MenuOnlineScene, WithFriends, ChangeNameAvatar, salle d'attente) -----

func show_multi() -> void:
	menus.show_multi()

func show_profile() -> void:
	menus.show_profile()

func show_friends() -> void:
	menus.show_friends()

func show_waiting() -> void:
	menus.show_waiting()

## Un autre onglet a repris notre siege (OnlineClient.evicted) : session oubliee, pas de reconnexion ; on previent puis retour au menu.
func _on_seat_taken() -> void:
	menus.msg_box("SEAT TAKEN ELSEWHERE", "This seat is now used in another tab", func(): go(show_menu))

## Sortie du plateau. En ligne, on quitte aussi la salle et on ferme la liaison (APK Dispose -> onlineService.Disconnect(), GamePlayMOScene.cs:58-68) ;
## sans cela le serveur garde le siege et repond `busy` au prochain create / join. Partie en cours : le siege passe a l'IA (Server.gd `leave`).
func _leave_board(gm: GameManager) -> void:
	if gm is OnlineGameManager:
		online.leave_match()
	show_title()

## Le plateau affiche une partie en ligne encore ouverte (pas terminee).
func _online_game_open() -> bool:
	if board == null or not is_instance_valid(board):
		return false
	var gm = board.get("game_manager")
	return gm is OnlineGameManager and gm.G.get("gameOver") == null

## Session perdue pendant la partie (serveur redemarre, salle expiree ou fermee) : modale de l'APK puis sortie (GamePlayMOScene.cs:92-95, 121-138).
func _on_session_lost() -> void:
	if not _online_game_open():
		return
	var gm: GameManager = board.get("game_manager")
	menus.msg_box("Connection problem", "The connection with the server was lost.", func(): _leave_board(gm))

## Coupure transitoire : Godot reconnecte seul (resume), l'APK sortait. On le dit au joueur.
func _on_link_changed(up: bool) -> void:
	if not _online_game_open():
		return
	var lbl := board.get_node_or_null("Reconnecting")
	if up:
		if lbl != null:
			lbl.queue_free()
	elif lbl == null:
		lbl = UiKit.label(board, "Reconnecting...", 42, Color("cdb15f"), Vector2(560, 12), 800.0, UiKit.FONT_A, HORIZONTAL_ALIGNMENT_CENTER)
		lbl.name = "Reconnecting"
		lbl.z_index = 100

func start_online_match() -> void:
	_clear()
	var ogm := OnlineGameManager.new()
	add_child(ogm)
	ogm.setup_online(online, online.player_id)
	online.start_state_poll()
	_open_board(ogm)
	# Compte a rebours de l'APK (CountDownEntity) a la place du chiffre simple de BoardUI.
	if board.get("timer_label") != null:
		board.timer_label.visible = false
	board.add_child(CountDown.new(online))

# --- options / regles ------------------------------------------------------------

func show_options() -> void:
	var host := LineEdit.new()
	host.text = server_host
	var is_web := OS.has_feature("web")
	var leave := func():
		if not is_web:
			server_host = host.text
		Profile.save_settings(server_host, use_extensions, apk_decks)
		show_menu()
	_apk_screen(leave)
	var decor := get_children() # fond, torches, logo, fleche (et les noeuds d'avant, deja condamnes) : tout ce qui s'ajoute ensuite = commandes d'OPTIONS (masquees par CREDITS)
	# 4 boutons empiles (OptionsScene.cs:55-103) : centre x 960, y 356,4 + 162 n (haut = centre - 72).
	var save_host := func():
		if not is_web:
			server_host = host.text # chaque sortie d'OPTIONS reconstruit l'ecran : on garde le champ serveur
		Profile.save_settings(server_host, use_extensions, apk_decks)
	var tut := UiKit.stone_button(self, "TUTORIAL", Vector2(687, 284))
	tut.name = "Tutorial"
	tut.pressed.connect(func():
		AudioManager.play_sfx("ui_button_select")
		save_host.call()
		start_tutorial()) # OptionsScene.cs:62-67 : To(GamePlayTutScene) sans transition
	var sett := UiKit.stone_button(self, "SETTINGS", Vector2(687, 446))
	sett.name = "Settings"
	sett.pressed.connect(func():
		AudioManager.play_sfx("ui_button_select")
		save_host.call()
		go(show_settings)) # OptionsScene.cs:68-79 : Push ColorFade noir NormalTransitionsTime
	var gal := UiKit.stone_button(self, "CARD GALLERY", Vector2(687, 608))
	gal.name = "CardGallery"
	gal.pressed.connect(func():
		AudioManager.play_sfx("ui_button_select")
		go(func(): add_child(CardGallery.new()))) # OptionsScene.cs:85-90 (ColorFade 1,0 s)
	var cred := UiKit.stone_button(self, "CREDITS", Vector2(687, 770))
	cred.name = "Credits"
	cred.pressed.connect(func():
		AudioManager.play_sfx("ui_button_select")
		save_host.call()
		_open_credits(decor)) # OptionsScene.cs:91-102
	# Controles secondaires discrets (multijoueur / extensions du wiki : hors APK).
	var ext := CheckBox.new()
	ext.text = "Wiki expansions (not in the APK)"
	ext.button_pressed = use_extensions
	ext.add_theme_font_size_override("font_size", 16)
	ext.position = Vector2(30, 1030)
	ext.toggled.connect(func(on: bool):
		use_extensions = on
		Profile.save_settings(server_host, use_extensions, apk_decks))
	add_child(ext)
	host.add_theme_font_size_override("font_size", 16)
	host.position = Vector2(1440, 1034)
	host.size = Vector2(440, 36)
	host.tooltip_text = "Multiplayer server"
	if is_web:
		host.free() # web : le serveur est toujours celui qui sert la page (window.location.origin), pas de champ
	else:
		add_child(host)

## SETTINGS (SettingsScene.cs:58-106) : MUSIC / SOUND / GAME SPEED aux y 360 / 480 / 600 ; la fleche pop en fondu noir 1,0 s vers OPTIONS (:136).
func show_settings() -> void:
	_apk_screen(func(): go(show_options))
	_toggle_row(360, "MUSIC", ["ON", "OFF"], 0 if AudioManager.music_on else 1, func(i: int): AudioManager.set_music_on(i == 0))
	_toggle_row(480, "SOUND", ["ON", "OFF"], 0 if AudioManager.sfx_on else 1, func(i: int): AudioManager.set_sfx_on(i == 0))
	_toggle_row(600, "GAME SPEED", ["SLOW", "NORMAL", "FAST"], Profile.load_speed(), func(i: int): Profile.save_speed(i))

## Push SANS transition (OptionsScene.cs:100-102) : OPTIONS reste dessine derriere le voile, ses boutons et son logo sont masques (ShowButtons(false), :101) ;
## retour = fondu noir 1,0 s vers OPTIONS (CreditsScene.cs:132).
func _open_credits(decor: Array) -> void:
	for c in get_children():
		var is_logo: bool = c is TextureRect and (c as TextureRect).texture != null and (c as TextureRect).texture.resource_path.ends_with("bm_logo.webp")
		if c is CanvasItem and (is_logo or not decor.has(c)):
			(c as CanvasItem).visible = false
	var cs := CreditsScreen.new()
	cs.closed.connect(func(): go(show_options))
	add_child(cs)

## Rangee de segments facon APK : le segment choisi est une pierre verte (settings_bt) dorée, les autres sur une barre mauve.
func _toggle_row(y: int, text: String, opts: Array, sel: int, cb: Callable) -> void:
	add_child(_lbl(text, 36, Color.WHITE, Vector2(260, y - 50), Vector2(450, 100), FONT_B, HORIZONTAL_ALIGNMENT_RIGHT))
	var row := Control.new()
	add_child(row)
	_draw_toggle(row, y, opts, sel, cb)

func _draw_toggle(row: Control, y: int, opts: Array, sel: int, cb: Callable) -> void:
	for c in row.get_children():
		row.remove_child(c)
		c.queue_free()
	var bar := ColorRect.new()
	bar.color = Color(109 / 255.0, 99 / 255.0, 131 / 255.0)
	bar.position = Vector2(760, y - 48)
	bar.size = Vector2(202 * opts.size(), 96)
	row.add_child(bar)
	for i in opts.size():
		var x := 760 + 202 * i
		if i == sel:
			row.add_child(_tex("buttons/settings_bt.webp", Vector2(x, y - 58), Vector2(202, 106)))
		row.add_child(_lbl(str(opts[i]), 34, GOLD if i == sel else Color(0.9, 0.88, 0.96), Vector2(x, y - 48), Vector2(202, 96), FONT_A))
		var idx := i
		row.add_child(_hit(Vector2(x, y - 48), Vector2(202, 96), func():
			cb.call(idx)
			_draw_toggle(row, y, opts, idx, cb)))

## Visionneuse des regles : voir RulesViewer.gd (partagee avec le plateau).
func show_rules(tab: int = 0) -> void:
	_clear()
	var v := RulesViewer.new()
	v.tab = tab
	v.free_on_close = false # reste a l'ecran pendant le fondu au noir (source du ColorFade) ; show_menu -> _clear() la libere au changement d'ecran
	v.closed.connect(func(): go(show_menu)) # sortie en ColorFade comme les autres ecrans du menu
	add_child(v)
