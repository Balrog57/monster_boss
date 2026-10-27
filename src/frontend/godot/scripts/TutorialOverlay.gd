extends Control
## TUTORIEL de l'APK 2.2.6 (GamePlayTutScene + scenes Scenes.Tutorial), pose par-dessus le plateau normal.
## Aucun moteur touche : le plateau ne fait que consulter `BoardUI.tutorial_gate` (= gate() ci-dessous) a quelques points sensibles ; hors tutoriel la garde est vide.
##
## Chaque scene de l'APK est une scene modale (TutorialBaseScene) posee sur le jeu fige : voile mascara_black, bulle (BalloonEntity), mains hand.webp qui
## tremblent, entites « attachees » (AttachEntity) dessinees AU-DESSUS du voile = ici des trous dans le voile. Un tap saute la frappe (AsSkippableTask),
## le tap suivant passe a la suite (CreateBackTapTask). Les 19 etapes s'enchainent par l'ETAT de la partie (G), pas par la chronologie de l'APK : si l'IA ou
## le hasard s'ecarte (seuls les tirages forces sont garantis, GameManager.start_tutorial), une etape dont la condition ne se produit pas est simplement ignoree
## et ne bloque jamais le joueur (voir _poll et _holding). Cas ou une etape saute :
##  - BMA022 / une carte imposee absente de la main : sa scene et sa restriction sautent (_forced_id ne renvoie rien) ;
##  - p25 (blessure de l'IA) : seulement si le heros 068 survit au donjon adverse, donc seulement si le sort BMA041 a ete joue (declenchee sans delai des que la
##    blessure existe et que les animations sont finies, meme si le moteur a deja change de tour : l'APK la montre au NextStep suivant, cs:223) ;
##  - p26 (ame) : seulement si le heros 064 meurt, donc si la capacite de BMA027 a ete jouee ;
##  - p29 : seulement si l'effet du sort BMA041 s'est resolu ; p28 : seulement si le sort est arrive sur la pile ;
##  - p27 / p23 : consignes qui retiennent la partie (run = faux) tant que le coup demande est legal ; des qu'il ne l'est plus, la partie reprend.
## Apres le LEVEL UP (p30 + p31) la garde est retiree et le jeu continue normalement.

const UiKit = preload("res://godot/scripts/UiKit.gd")
const BossEngine = preload("res://godot/scripts/BossEngine.gd")

signal tick(dt: float)  # horloge unique des scenes : _process(delta) ou step(dt) (tests)
signal tapped

const DIR := "res://assets/ui/tutorial/"
const FONT := "res://assets/fonts/arcadepix.fnt"
const VEIL := Color(0, 0, 0, 165.0 / 255.0) # mascara_black : l'extraction webp lit alpha 0, l'APK affiche un voile de 165/255 (mesure sur le cadre de mascara_00)
const TYPE_CPS := 15.0                      # AnimatedWritingBehavior.cs:11 : 15 lettres par seconde
const AFTER_TYPE := 0.2                     # TutorialIntroScene.cs:100 : Delay(0,2 s) apres la frappe
const FADE_IN := 0.2                        # ModalTransitionsTime : CrossFade de 0,2 s a l'ouverture d'une scene (GamePlayTutScene.cs:136-142)
const HINT_TIME := 0.5                      # HideWhenTouchBehavior.cs:36-37 : entree et sortie de la bulle du boss
const SHAKE_AMP := 20.0                     # ShakeBehavior (TutorialFactory.cs:30-35) : amplitude 20, pas de decroissance
const SHAKE_W := 7.2                        # VelocityFactor 0,12 x 60 images/s
const NAG := 8.0                            # delai sans action avant de rejouer la consigne (p23 / p27) : l'APK la rejoue a chaque tour de la barre de temps

# Idees d'etapes (APK) et cartes imposees (GamePlayTutScene.cs:13-37)
const CARD_DISCARD := ["BMA026", "BMA055"]
const FIRST_ROOM := "BMA034"  # GamePlayTutScene.cs:186
const SECOND_ROOM := "BMA016" # :195
const THIRD_ROOM := "BMA027"  # :204 (aussi la salle a activer, FIRST_ROOM_PLAYED :36)
const SPELL := "BMA041"       # :230
const HERO_KILLED := "BMA064" # FIRST_HERO_KILLED
const HERO_SPELL := "BMA068"  # SECOND_HERO_KILLED

# Bulles : BalloonFactory.cs:27-59 ; rectangle de texte (largeur, hauteur), sprite natif, marge horizontale.
const BALLOONS := {
	"medium": {"rect": Vector2(608, 225), "tex": "txt_bg_medium", "hm": 0.0},
	"long": {"rect": Vector2(880, 213), "tex": "txt_bg_long", "hm": 0.0},
	"large": {"rect": Vector2(777, 360), "tex": "txt_bg_large", "hm": 0.0},
	"globe": {"rect": Vector2(690, 360), "tex": "globe_bg_large", "hm": 13.5},
}
const TEXT_SIZE := 25 # arcadepix 21 x 1,2 (BalloonFactory textScale 1,2)

# King Croak (TutorialIntroScene.cs:144-161) : 7 images 63 x 62 de kingcroak_anim, 8 images/s, boucle
const KING_POS := Vector2(349, 343) # APK (100,343) + 240 ; +9 en x : decalage mesure par correlation sur tut_11..20 (Godot 9 px trop a gauche)
const KING_FRAME := Vector2(63, 62)
const KING_SCALE := 8.7
const KING_REGIONS := [Vector2(2, 2), Vector2(67, 2), Vector2(132, 2), Vector2(2, 66), Vector2(67, 66), Vector2(132, 66), Vector2(2, 130)] # kingcroak_anim.xml : 01,04,07,10,13,15,18
const KING_FPS := 8.0

# Textes : TutorialStringFactory.cs:9-149, mot pour mot (fautes de l'APK comprises)
const TEXT := {
	"page01": ["OH, THERE YOU ARE, FINALLY! I DON'T HAVE ALL DAY, YOU KNOW. I'VE GOT TRAPS TO OIL, MONSTERS TO FEED, AND KOBOLDS TO FLOG. SO LETS GET ON WITH IT!"],
	"page02": ["WELCOME TO ARCADIA. LAND OF MAGIC, ADVENTURE, AND BLAH, BLAH BLAH. BUT HONESTLY, THIS PLACE IS INFESTED WITH HEROES! YOU CAN'T THROW A LIGHTNING BOLT WITHOUT SKEWERING SOME BAND OF BRAVE IDIOTS."],
	"page03": ["THAT'S WHERE WE COME IN. AS BOSSES, IT'S OUR JOB TO BUILD DUNGEONS, LURE HEROES, AND DESTROY THEM. IF YOU'RE GOING TO JOIN US, YOU MIGHT AS WELL LEARN FROM THE BEST: ME."],
	"page04": ["WHEN HEROES DIE IN YOUR DUNGEON, YOU EARN SOULS. WHEN THEY SURVIVE YOUR DUNGEON, YOU GET WOUNDS."],
	"page05": ["YOU WIN THE GAME IF YOU EARN TEN SOULS:"],
	"page08": ["YOU LOSE IF YOU GAIN FIVE WOUNDS:\n\n\n", "\n\n\nOR IF ANOTHER BOSS EARNS TEN SOULS BEFORE YOU!"],
	"page13": ["THEN IT'S TIME FOR THE MEAT OF THE GAME: BUILDING ROOMS! AS THE BUILD PHASE BEGINS, DRAG THIS CARD TO BUILD IT ON THE FIRST SLOT.", "THIS CARD TRIGGERS AN AUTOMATIC ABILITY WHEN IS BUILT, THAT ALLOWS TO BUILD AN ADDITIONAL ROOM."],
	"page16": ["YOU HAVE REACHED THE BUILD PHASE. BUILD THIS ROOM IN THE THIRD SLOT. IT WILL BE USEFUL NEXT!"],
	"page18": ["WHEN THE \"PASS TURN\" BUTTON CHANGES TO \"DONE!\", THIS MEANS THAT YOUR ROOMS ARE READY TO BE BUILT. PRESS TO FINISH YOUR BUILDING TURN."],
	"page19": ["NOW YOU CAN BUILD AN EXTRA ROOM! DRAG THIS ROOM TO THE SECOND SLOT."],
	"page19_a": ["\nAT THE BEGINNING OF THE BUILD PHASE, YOU WILL DRAW ONE ROOM CARD!"],
	"page20": ["THE HEROES SHOW UP IN TOWN EVERY TURN, EACH KIND OF HERO WANTS A DIFFERENT TYPE OF TREASURE:"],
	"page21": ["\nIF YOU HAVE THE MOST OF A PARTICULAR TREASURE ICON, ALL HEROES OF THAT TYPE WILL BE LURED TO YOUR DUNGEON DURING THE BAIT PHASE!"],
	"page22": ["NOW THE ADVENTURE PHASE BEGINS! LURED HEROES ENTER DUNGEONS ONE BY ONE AND TAKE DAMAGE IN EVERY ROOM.\n\nTO KILL A HERO, YOUR ROOMS NEED TO DEAL DAMAGE EQUAL TO THE HERO'S HEALTH. LOOKS LIKE THIS JERK IS GOING TO SURVIVE."],
	"page23": ["\nNOW LISTEN, WE HAVE TO BE FAST, HIT THIS ROOM BEFORE IT'S TOO LATE."],
	"page24": ["TAP THE ROOM DESCRIPTION AND YOU WILL RELEASE HELL ON THIS HERO.\nREMEMBER THAT SOME ABILITIES ARE TRIGGERED BY THEIR OWN, SO YOU DON'T HAVE TO DO ANYTHING."],
	"page25": ["HAHAHAHAHAHAHAHAHAHA, THAT WILL TEACH HER NOT MESSING WITH CROAKS."],
	"page26": ["SPLENDIT, NOW I'M ONE STEP CLOSER TO VICTORY."],
	"page27": ["\nLOOKS LIKE SOMEONE HAS VISIT, NOW DRAG THIS SPELL TO THIS OBTRUSIVE MAGE."],
	"page28": ["WHEN THIS BAR IS COMPLETILY DEPLEATED, THE SPELL WILL TAKE IT'S EFFECT, IF ANYONE GOT SOMETHING ELSE TO DRAG, NOW IT'S TIME. I DIDN'T THINK SO."],
	"page29": ["HAHA! LOOK WHAT YOU DID! NOW HE WON'T BE ABLE TO KILL THIS HERO, SO EVIL."],
	"page30": ["WOW!! LOOK AT THAT, THAT'S A BIG DUNGEON!! ALL FIVE SLOTS ARE BUILT, WHEN THIS HAPPENDS FOR THE FIRST TIME, YOU ARE ABLE TO RISE YOUR BOSS SPECIAL ABILITY."],
	"page31": ["YOU DON'T KNOW THE VAST EXTENSION OF YOUR POWERS? HIT ME AND I WILL TELL YOU WHAT I CAN DO FOR THIS DUNGEON."],
}
const WRONG_PICK := ["NO, THAT WON'T HAPPEN.", "YOU DON'T REALLY KNOW ANYTHING, RIGHT?", "REALLY? ARE YOU SURE? I DON'T THINK SO.", "OBEY MINION!!!"] # TutorialStringFactory.cs:11
const RIGHT_PICK := ["WELL DONE, MINION.", "YOU ARE GOING TO GET FAR.", "FOR SURE. GREAT CHOICE!", "THAT'S MY MINION!"] # TutorialStringFactory.cs:17
const DISCARD_TEXT := "YOU START WITH SEVEN CARDS. DISCARD TWO AND KEEP FIVE YOU LIKE BEST. AS YOU DON'T KNOW ANYTHING, CHOOSE THE ONES I HAVE SELECTED FOR YOU." # TutorialStringFactory.cs:23
const HIT_DONE := "\nNOW HIT \"DONE\" TO CONTINUE." # TutorialStringFactory.cs:143
const CLICK_CONTINUE := "HIT CONTINUE, MINION" # TutorialStringFactory.cs:148

class Hand extends Node2D:
	## hand.webp 184 x 106, doigt vers la DROITE. Verticale : rotation -90 degres autour de (1,0) = coin haut droit (TutorialBaseScene.cs:152-161) -> le doigt monte ;
	## retournee (FlipHorizontally avant la rotation) -> le doigt descend. Pointeur de carte : enfant de la carte (repere de la carte 350 x 488, echelle de la carte).
	var spr := Sprite2D.new()
	var anchor := Vector2.ZERO
	var vertical := false
	var card: Control = null
	var card_id := ""
	var local := Vector2.ZERO
	var krot := 0.0
	var t := 0.0
	var fade := -1.0

	func _init(tex: Texture2D, flip: bool, vert: bool) -> void:
		spr.texture = tex
		spr.centered = false
		spr.flip_h = flip
		vertical = vert
		if vert:
			rotation = -PI / 2.0
			spr.position = Vector2(-tex.get_width(), 0)
		add_child(spr)

	func update(dt: float) -> void:
		t += dt
		var o := 20.0 * sin(7.2 * t) # ShakeBehavior (amplitude 20, 7,2 rad/s : constantes de TutorialOverlay) : horizontal sauf main verticale / pointeur (alors LocalY)
		if card_id != "":
			if is_instance_valid(card):
				var k := card.size.x / 350.0
				global_transform = card.get_global_transform() * Transform2D(krot, Vector2(k, k), 0.0, card.size / 2.0 + (local + Vector2(0, o)) * k)
		else:
			position = anchor + (Vector2(0, o) if vertical else Vector2(o, 0))
		if fade >= 0.0:
			fade += dt
			modulate.a = clampf(1.0 - fade / 0.5, 0.0, 1.0) # FadeBehavior 0,5 s (AddCarouselCardsBehavior.cs:127)

var board: BoardUI
var manual := false          # tests : l'horloge vient de step(dt) et non de _process
var _done := {}              # etape -> deja montree (ou sautee)
var _scene: Control          # scene modale en cours (null = aucune)
var _veil: Control
var _holes: Array = []       # rectangles « attaches » : dessines au-dessus du voile
var _sprites: Array = []     # sprites « attaches » (boss) : recopies au-dessus du voile, sans le decor autour (tut_108 / tut_126)
var _blank := true           # intro : colonnes sans noms de boss ni pioches, decor noir (BoardUI, gate « intro_blank »), jusqu'a la fin de l'intro apres le choix du boss
var _mask = null             # position (Vector2) de mascara_00, null = voile plein ecran (mascara_black)
var _mask_tex: Texture2D
var _fade := 0.0
var _skip := false
var _tap_wait := false
var _detail: Control         # icones de la scene (ames, blessures, tresors) : retirees au debut de l'etape suivante
var _hands: Array = []       # mains de la scene courante
var _scene_ptr: Hand         # pointeur pose sur la carte imposee pendant une scene de glisser
var _king: TextureRect
var _king_t := 0.0
var _ptr_layer: Control      # pointeurs de la defausse d'ouverture (au-dessous des scenes)
var _ptrs := {}              # id de carte -> Hand
var _ptr_gone := {}          # id de carte -> pointeur retire (carte choisie)
var _hint: Control           # bulle du boss (bonne / mauvaise carte)
var _hint_age := 0.0
var _disc_t := 0.0           # delai avant DiscardTwoCards (0,9 s)
var _hold_t := 0.0
var _stable := {}
var _lvl_done := false
var _frozen: Control         # carte piochee figee pendant la scene p19_a (rendue au vol a la fin ou a la sortie)
var _finished := false

func _ready() -> void:
	_mask_tex = UiKit.tex(DIR + "mascara_00.webp") # chargee des le debut : a sa 1re utilisation (p05) le voile affichait un rectangle blanc jusqu'au redessin suivant
	z_index = 105
	size = Vector2(1920, 1080)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ptr_layer = Control.new()
	_ptr_layer.size = size
	_ptr_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_ptr_layer)
	if board != null:
		board.room_detail_shown.connect(_on_room_detail)

func _process(delta: float) -> void:
	if not manual:
		step(delta)

## Fait avancer le tutoriel de `dt` secondes (une image) : animations, minuteries, declenchement des etapes.
func step(dt: float) -> void:
	if _finished or board == null or board.game_manager == null:
		return
	tick.emit(dt)
	_animate(dt)
	var G := _G()
	if G.is_empty():
		return
	if _scene == null:
		_clocks(dt)
		_poll()

# ---------------------------------------------------------------------------------------------------------------------
# Etat de la partie
# ---------------------------------------------------------------------------------------------------------------------

func _G() -> Dictionary:
	return board.game_manager.G

func _p(pid: int) -> Dictionary:
	return ((_G().get("players", {}) as Dictionary).get(pid, {}) as Dictionary)

func _phase() -> String:
	return str(_G().get("phase", ""))

func _turn() -> int:
	return int(_G().get("turn", 0))

## Les restrictions de l'APK ne valent que pour la 1re partie du tutoriel (NumberOfTurns == 0, GamePlayTutScene.cs:181,310,376,400 ; ici G.turn <= 1).
func _restricted() -> bool:
	return not _finished and _G().get("gameOver") == null and _turn() <= 1

func _hand_idx(id: String) -> int:
	var hand: Array = _p(0).get("hand", [])
	for i in hand.size():
		if str((hand[i] as Dictionary).get("id", "")) == id:
			return i
	return -1

## Noeud (visible) de la carte `id` dans la main affichee, null si absente / pas encore posee (pioche en vol).
func _card_node(id: String) -> Control:
	for c in board.hand_layer.get_children():
		if c is CardUI and not c.is_queued_for_deletion() and c.visible and str((c as CardUI).card_dict.get("id", "")) == id:
			return c as Control
	return null

func _hand_rect() -> Rect2:
	var r := Rect2()
	var first := true
	for c in board.hand_layer.get_children():
		if c is CardUI and not c.is_queued_for_deletion() and c.visible:
			var cr := (c as Control).get_global_rect()
			r = cr if first else r.merge(cr)
			first = false
	return r.intersection(Rect2(0, 0, 1920, 1080)) if not first else Rect2()

func _discard_pending() -> bool:
	var pc: Dictionary = _G().get("pendingChoice", {})
	return str(pc.get("type", "")) == "opening-discard" and int(pc.get("playerId", -1)) == 0

## Carte que le joueur doit glisser a cet instant (CardExtractBehavior.ForcedToExtractCard, GamePlayTutScene.cs:186,195,204,230), "" = aucune.
## Une carte imposee absente de la main = pas de restriction (etape sautee).
func _forced_id() -> String:
	if not _restricted():
		return ""
	var G := _G()
	var p0 := _p(0)
	var fid := ""
	match _phase():
		"setup":
			if int(p0.get("buildsThisTurn", 0)) == 0:
				fid = FIRST_ROOM
		"build":
			if int(p0.get("buildsThisTurn", 0)) == 0:
				if G.get("setupForced") != null and _turn() == 0:
					fid = SECOND_ROOM
				elif _turn() == 1 and board.game_manager.active_player() == 0:
					fid = THIRD_ROOM
		"adventure":
			if _spell_window():
				fid = SPELL
	return fid if fid != "" and _hand_idx(fid) >= 0 else ""

## Le heros 068 attend a l'entree du donjon adverse, sort jouable (CheckPlaySpellCondition, GamePlayTutScene.cs:396-405 : InsideDungeonSlot == null).
func _spell_window() -> bool:
	var G := _G()
	if _phase() != "adventure" or not _restricted() or not (G.get("adventure", {}) as Dictionary).is_empty() or not (G.get("stack", []) as Array).is_empty():
		return false
	if board.game_manager.active_player() != 1 or _hand_idx(SPELL) < 0:
		return false
	var ent: Array = _p(1).get("entrance", [])
	if ent.is_empty() or str((ent[0] as Dictionary).get("id", "")) != HERO_SPELL:
		return false
	var hi := _hand_idx(SPELL)
	for m in board.game_manager.legal_moves(0):
		var md: Dictionary = m
		if str(md.get("type", "")) == "playSpell" and int((md.get("args", [-1]) as Array)[0]) == hi:
			return true
	return false

## Le heros 064 est dans BMA027 et la capacite de la salle est jouable (CheckPlayRoomAbilityCondition, :386-394).
func _hit_state() -> bool:
	var G := _G()
	var adv: Dictionary = G.get("adventure", {})
	if not _restricted() or adv.is_empty() or str((adv.get("hero", {}) as Dictionary).get("id", "")) != HERO_KILLED:
		return false
	if int(adv.get("roomIndex", -1)) != 0 or str(adv.get("pause", "")) != "post-damage" or not (G.get("stack", []) as Array).is_empty():
		return false
	for m in board.game_manager.legal_moves(0):
		var md: Dictionary = m
		if str(md.get("type", "")) == "activateRoom" and int((md.get("args", [-1]) as Array)[0]) == 0:
			return true
	return false

## Consigne qui retient la partie : le heros n'avance pas tant que le joueur n'a pas joue le coup demande.
func _holding() -> bool:
	return _hit_state() or _spell_window() or _spell_up()

## Le sort BMA041 vient d'etre joue et attend sur la pile : la partie reste figee jusqu'a la scene p28 (sinon l'IA et la passe automatique resolvent la pile avant qu'on la montre).
func _spell_up() -> bool:
	var st: Array = _G().get("stack", [])
	return _restricted() and bool(_done.get("adv27", false)) and not bool(_done.get("adv28", false)) and not st.is_empty() and str(((st[st.size() - 1] as Dictionary).get("card", {}) as Dictionary).get("id", "")) == SPELL # l'entree de pile est « spell-<carte>-<n> » : la carte est dans « card »

func _busy_anim() -> bool:
	return board._animating_hero or board._bait_active()

## Condition vraie depuis `secs` secondes de suite (laisse finir les animations avant une scene).
func _since(key: String, cond: bool, secs: float) -> bool:
	if not cond:
		_stable.erase(key)
		return false
	if not _stable.has(key):
		_stable[key] = 0.0
	return float(_stable[key]) >= secs

func _clocks(dt: float) -> void:
	for k in _stable.keys():
		_stable[k] = float(_stable[k]) + dt
	if bool(_done.get("intro2", false)) and not bool(_done.get("discard", false)) and _discard_pending():
		_disc_t += dt
	if _holding():
		_hold_t += dt
	else:
		_hold_t = 0.0
	if _hint != null:
		_hint_age += dt # l'APK n'a aucun minuteur : la bulle ne se ferme qu'au toucher hors d'elle (HideWhenTouchBehavior)

# ---------------------------------------------------------------------------------------------------------------------
# Declenchement des etapes (ordre de l'APK, chacune une seule fois)
# ---------------------------------------------------------------------------------------------------------------------

func _poll() -> void:
	if _finished or _scene != null:
		return
	var G := _G()
	if G.is_empty():
		return
	if G.get("gameOver") != null:
		_finish()
		return
	var p0 := _p(0)
	var phase := _phase()
	var turn := _turn()
	var builds := int(p0.get("buildsThisTurn", 0))
	var pc: Dictionary = G.get("pendingChoice", {})
	var idle: bool = not _busy_anim()
	# Consigne qui retient la partie et que le joueur n'execute pas : on la rejoue (l'APK la rejoue a chaque tour de la barre de temps)
	if _hold_t >= NAG and _holding():
		_hold_t = 0.0
		if _spell_window() and _done.has("adv27"):
			_drag_scene("page27", SPELL, true, [board._lane[0]["entrance"].get_global_rect()])
			return
		if _hit_state() and _done.has("adv23"):
			_adv(23)
			return
	# 1. Intro avant le carrousel (TutorialIntroScene isFirstPart, GamePlayTutScene.cs:165-171)
	if not _done.has("intro1"):
		_done["intro1"] = true
		_intro1()
		return
	# 2. Intro apres le choix du boss (cs:150-160)
	if not _done.has("intro2"):
		if p0.get("boss") != null:
			_done["intro2"] = true
			_intro2()
		return
	# 3. Defausse d'ouverture : DiscardTwoCards 0,9 s apres l'ouverture du selecteur
	if not _done.has("discard"):
		if _discard_pending():
			if _disc_t >= 0.9:
				_done["discard"] = true
				_discard()
		elif phase != "boss":
			_done["discard"] = true # defausse deja faite sans la scene : on ne la rejoue pas
		return
	# 4. Construction (cs:184-208) et boutons DONE (cs:336-361)
	var fid := _forced_id()
	if phase == "setup" and pc.is_empty():
		if not _done.has("build1") and fid == FIRST_ROOM and _card_node(fid) != null:
			_done["build1"] = true
			_drag_scene("page13", fid, false)
			return
		if not _done.has("done1") and builds >= 1 and board.pass_shown():
			_done["done1"] = true
			_done_scene(true, false)
			return
	if phase == "build" and G.get("setupForced") != null and turn == 0:
		if not _done.has("build2") and fid == SECOND_ROOM and _card_node(fid) != null:
			_done["build2"] = true
			_drag_scene("page19", fid, false)
			return
		if not _done.has("done2") and builds >= 1 and board.pass_shown():
			_done["done2"] = true
			_done_scene(false, false)
			return
	if phase == "build" and turn == 1 and board.game_manager.active_player() == 0:
		# 5. Debut du tour 1 : carte piochee (TutorialFirstDrawedCardScene, cs:372-380), puis leurre (cs:211), puis 3e salle (cs:204)
		if not _done.has("firstdraw") and builds == 0:
			if _hand_idx("BMA022") < 0:
				_done["firstdraw"] = true # carte absente (tirage different) : etape sautee
			else:
				# tut_58..63 : la scene s'ouvre quand la carte retournee est grande au centre, le vol vers la main attend la fin de la scene (sans animation : carte deja dans la main)
				var dh := _drawn_holder("BMA022")
				if dh != null or (_card_node("BMA022") != null and board._draw_hide.is_empty()):
					_done["firstdraw"] = true
					_firstdraw(dh)
					return
		if _done.has("firstdraw") and not _done.has("bait") and builds == 0 and not (G.get("town", []) as Array).is_empty() and board._draw_hide.is_empty():
			_done["bait"] = true
			_bait()
			return
		if _done.has("bait") and not _done.has("build3") and fid == THIRD_ROOM and _card_node(fid) != null and board._draw_hide.is_empty():
			_done["build3"] = true
			_drag_scene("page16", fid, false)
			return
		if not _done.has("done3") and builds >= 1 and board.pass_shown():
			_done["done3"] = true
			_done_scene(false, false)
			return
	# 6. Aventure du heros 064 (cs:236-251, 269-277)
	if phase == "adventure" and turn == 1 and idle:
		var adv: Dictionary = G.get("adventure", {})
		if not _done.has("adv22") and board.game_manager.active_player() == 0 and adv.is_empty() and (p0.get("souls", []) as Array).is_empty() and not (_p(0).get("entrance", []) as Array).is_empty():
			_done["adv22"] = true
			_adv(22)
			return
		if not _done.has("adv23") and _hit_state():
			_done["adv23"] = true
			_adv(23)
			return
	# 7. Ame de 064 (p26, cs:219), sort sur 068 (p27, cs:231), pile (p28, cs:313), effet (p29, cs:321), blessure de l'IA (p25, cs:223)
	if _restricted():
		var soul064 := _has_hero(p0.get("souls", []), HERO_KILLED)
		if not _done.has("adv26") and soul064 and idle and pc.is_empty(): # APK : aucun delai, au NextStep suivant la mort (cs:219) ; l'ame est un etat permanent
			_done["adv26"] = true
			_adv(26)
			return
		if not _done.has("adv27") and idle and (_done.has("adv26") or not soul064) and _spell_window():
			_done["adv27"] = true
			_drag_scene("page27", SPELL, true, [board._lane[0]["entrance"].get_global_rect()])
			return
		var st: Array = G.get("stack", [])
		var spell_up: bool = _spell_up()
		if not _done.has("adv28") and _since("p28", spell_up, 0.5): # MyHand_CardDropped : 0,5 s apres le depot
			_done["adv28"] = true
			_adv(28)
			return
		if not _done.has("adv29") and _done.has("adv28") and st.is_empty() and _health_bonus():
			_done["adv29"] = true
			_adv(29)
			return
	# p25 (cs:223) : hors du bloc « restreint », au NextStep qui suit la blessure et sans delai ; _ai_wound_068 lit un etat permanent (le moteur enchaine le tour suivant en quelques ms)
	if not _done.has("adv25") and _ai_wound_068() and idle and pc.is_empty():
		_done["adv25"] = true
		_adv(25)
		return
	# 8. Premier LEVEL UP du boss humain (TutorialLevelUpScene, cs:361-370)
	if not _done.has("lvl") and bool(p0.get("leveledUp", false)) and idle:
		_done["lvl"] = true
		_levelup()

## Ames / blessures : entrees {hero: carte, souls, ...} (Match._capture : la carte du heros est dans « hero »).
func _has_hero(arr: Array, id: String) -> bool:
	for h in arr:
		if str(((h as Dictionary).get("hero", h) as Dictionary).get("id", "")) == id:
			return true
	return false

## Le heros 068 a survecu au donjon de l'IA au tour 1 (CheckFirstWoundHero, NumberOfTurns == 0). L'entree de blessure porte le tour (Match._finish_hero) : l'etat reste vrai
## apres le changement de tour, donc la condition est captee meme si aucune image ne tombe dans la fenetre « blessure posee, tour pas change ».
func _ai_wound_068() -> bool:
	for w in _p(1).get("wounds", []):
		var wd := w as Dictionary
		if str((wd.get("hero", {}) as Dictionary).get("id", "")) == HERO_SPELL and int(wd.get("turn", 99)) <= 1:
			return true
	return false

## L'effet de BMA041 (+3 PV) est applique au heros 068 (CheckSpellAbilityEffect, cs:407-415) : SpellEffects._assassin le note dans effects.heroHealthBonus.
func _health_bonus() -> bool:
	for e in ((_G().get("effects", {}) as Dictionary).get("heroHealthBonus", []) as Array):
		if str((e as Dictionary).get("heroId", "")) == HERO_SPELL:
			return true
	return false

func _on_room_detail(di: int) -> void:
	if _finished or _scene != null or not bool(_done.get("adv23", false)) or not _hit_state():
		return
	var dun: Array = _p(0).get("dungeon", [])
	if di < 0 or di >= dun.size():
		return
	var top = BossEngine.active_room(dun[di])
	if top != null and str((top as Dictionary).get("id", "")) == THIRD_ROOM: # OnRoomDetailShow : p24 sur la salle BMA027 avec le heros 064 dedans
		_hold_t = 0.0
		_adv(24)

# ---------------------------------------------------------------------------------------------------------------------
# Garde du plateau (BoardUI._tg)
# ---------------------------------------------------------------------------------------------------------------------

## kind : run (la partie avance-t-elle ?), input (le plateau lit-il les clics ?), carousel (le choix du boss peut-il s'ouvrir ?), boss (boss force),
## levelup / choice (banniere LEVEL UP et choix de niveau), tap / drag (carte de la main), drop (emplacement), move (coup de sort), spell_drop (point de depot),
## pass (DONE), undo (reprise d'une pose).
func gate(kind: String, arg = null):
	if _finished or board == null or board.game_manager == null:
		return "" if kind == "boss" else kind != "intro_blank"
	match kind:
		"intro_blank":
			return _blank
		"run":
			_poll()
			return _scene == null and not _holding()
		"input":
			return _scene == null
		"carousel":
			return _done.has("intro1") and _scene == null
		"zoom_scale":
			return 1.62
		"boss":
			return "BMA003" # GamePlayTutScene.cs:115 (HUMAN_PLAYER)
		"levelup":
			return _lvl_done
		"choice":
			return _lvl_done or not bool(_p(0).get("leveledUp", false))
		"tap":
			return _gate_tap(arg as Dictionary)
		"drag":
			if not _restricted():
				return true
			var hand: Array = _p(0).get("hand", [])
			var ok := int(arg) < hand.size() and _forced_id() != "" and str((hand[int(arg)] as Dictionary).get("id", "")) == _forced_id()
			if not ok:
				_reinforce() # CardExtractBehavior.InvalidCardPlayed -> ShowReinforcementScene (cs:280-309)
			return ok
		"drop":
			return not _restricted() or (arg as DungeonSlot).current_stack.is_empty() # BuildRoomHandSceneBehavior.cs:174 : pose sur un emplacement occupe interdite
		"move":
			if not _restricted():
				return true
			var mv: Dictionary = arg
			var a: Array = mv.get("args", [])
			return str(mv.get("type", "")) == "playSpell" and a.size() > 1 and a[1] is Dictionary and str((a[1] as Dictionary).get("heroId", "")) == HERO_SPELL and int(a[0]) == _hand_idx(SPELL) and _spell_window()
		"spell_drop":
			if not _restricted() or _forced_id() != SPELL:
				return true
			var ent: Control = board._lane[0]["entrance"]
			return ent.get_global_rect().grow(80.0).has_point(arg as Vector2)
		"pass":
			if _restricted() and _forced_id() != "":
				_reinforce() # DoneHaltButton_PressedWhenLocked (cs:278-281)
				return false
			return true
		"undo":
			return not _restricted()
	return true

func _gate_tap(d: Dictionary) -> bool:
	if _scene != null:
		return false
	var card: Dictionary = d.get("card", {})
	var id := str(card.get("id", ""))
	if _discard_pending():
		return _discard_tap(id, int(d.get("idx", -1)))
	if not _restricted():
		return true
	return _forced_id() != "" and id == _forced_id()

## TutorialSelectorComponent.UpdateSelectedCards : seules les 2 cartes designees se choisissent (jamais deselectionnees), les autres affichent une moquerie.
func _discard_tap(id: String, idx: int) -> bool:
	if not CARD_DISCARD.has(id):
		_show_hint(WRONG_PICK[randi() % WRONG_PICK.size()])
		return false
	var picked: Array = board.discard_pick
	if picked.has(idx):
		if picked.size() == 2:
			_show_hint(CLICK_CONTINUE)
		return false
	_show_hint(CLICK_CONTINUE if picked.size() + 1 == 2 else RIGHT_PICK[randi() % RIGHT_PICK.size()])
	return true

## Rappel (scenes de renfort : le texte s'affiche d'un coup, TutorialDragCardScene isReinforcement) apres une carte invalide ou un DONE verrouille (cs:283-309).
func _reinforce() -> void:
	if _scene != null or _finished or board.game_manager == null:
		return
	var fid := _forced_id()
	if fid == "":
		if _restricted() and board.pass_shown() and (_phase() == "setup" or _phase() == "build"):
			_done_scene(false, true)
		return
	match _phase():
		"setup":
			_drag_scene("page13", fid, true)
		"build":
			_drag_scene("page19" if _G().get("setupForced") != null and _turn() == 0 else "page16", fid, true)

# ---------------------------------------------------------------------------------------------------------------------
# Scenes (une par etape de l'APK)
# ---------------------------------------------------------------------------------------------------------------------

func _intro1() -> void:
	_begin()
	var lb := _balloon("globe", Vector2(1140, 350)) # TutorialIntroScene.cs:47 : BubbleGlobeLarge (900,350) + 240
	_add_king()
	for p in ["page01", "page02", "page03"]:
		await _text_step(lb, {"text": TEXT[p][0], "hands": [{"pos": Vector2(1040, 485)}]}) # :57 main (800,485)
	_end()
	board.refresh() # le carrousel des bosses peut s'ouvrir

func _intro2() -> void:
	_begin()
	# tut_17..20 : la zone de jeu est noire (le plateau n'est pas encore distribue), les panneaux restent sous le voile
	var black: Control = board.make_intro_field() # decor mesure sur tut_17 (bandes, filets or) : le meme que le fond noir de l'intro 1 (BoardUI)
	_scene.add_child(black)
	_scene.move_child(black, 0)
	var lb := _balloon("globe", Vector2(1140, 350))
	_add_king()
	await _text_step(lb, {"text": TEXT["page04"][0], "hands": [{"pos": Vector2(1040, 485)}]})
	# p05 : mascara_00 a (LimitedRightEdge - 439, 528), main a (LimitedRightEdge - 395, 640) ; 10 ames depuis (690,385) (:72-75,120)
	await _text_step(lb, {"text": TEXT["page05"][0], "mask": Vector2(1481, 528), "finish": _load_icons.bind("soul"), "hands": [{"pos": Vector2(1525, 640)}]})
	# p08 : mascara_00 a y 442, main a y 580 ; 5 blessures depuis (750,347) puis la pierre tombale ; le 2e texte prolonge le 1er (:81-83,136)
	await _text_step(lb, {"text": TEXT["page08"][0], "second": TEXT["page08"][1], "mask": Vector2(1481, 442), "finish": _load_icons.bind("wound"), "hands": [{"pos": Vector2(1525, 580)}]})
	_end()
	_blank = false # tut_21 : les noms de boss et les pioches apparaissent avec la defausse d'ouverture
	board.refresh()

## TutorialDiscardTwoCardsScene : bulle medium (VirtualWidth x 0,5, 200), main verticale a (VirtualWidth x 0,5, VirtualWidth x 0,4)
func _discard() -> void:
	_begin()
	var lb := _balloon("medium", Vector2(960, 200))
	await _text_step(lb, {"text": DISCARD_TEXT, "delay": false, "hands": [{"pos": Vector2(960, 576), "vertical": true}]})
	_end()

## TutorialDragCardScene : bulle long (VirtualWidth x 0,5, 645), main d'index sur la carte imposee (local (50,-450), rotation +90 degres, secousse verticale), retiree a la fin de la scene.
func _drag_scene(page: String, fid: String, reinf: bool, extra: Array = []) -> void:
	var node := _card_node(fid)
	if node == null:
		return # carte absente : scene sautee, la restriction tombe aussi (_forced_id)
	_begin([_hand_rect()] + extra)
	var lb := _balloon("long", Vector2(960, 645))
	var msgs: Array = TEXT[page]
	for i in (1 if reinf else msgs.size()):
		var m: String = msgs[i]
		await _text_step(lb, {"text": m, "start": m.length() if reinf else 0, "after": _drag_pointer.bind(fid), "hands": []})
	if _scene_ptr != null:
		_scene_ptr.queue_free() # TutorialDragCardScene.End : RemoveChild(handPointer)
		_scene_ptr = null
	_end()

func _drag_pointer(fid: String) -> void:
	if _scene_ptr == null and _scene != null:
		_scene_ptr = _card_hand(fid, Vector2(50, -450), PI / 2.0, _scene)

## TutorialDoneButtonScene : bulle long (VirtualWidth x 0,5, 226), main verticale + retournee a (centre du bouton + (-50,-210)) : le doigt vise le bouton.
func _done_scene(first: bool, reinf: bool) -> void:
	var btn: Control = board.btn_pass
	var r := btn.get_global_rect()
	_begin([r])
	var lb := _balloon("long", Vector2(960, 226))
	var text: String = TEXT["page18"][0] if first else HIT_DONE
	await _text_step(lb, {"text": text, "start": text.length() if reinf else 0, "hands": [{"pos": r.get_center() + Vector2(-50, -210), "flip": true, "vertical": true}]})
	_end()

## TutorialFirstDrawedCardScene : bulle medium (VirtualWidth x 0,5, VirtualHeight x 0,15), main retournee a (VirtualWidth x 0,65, VirtualHeight x 0,35) ; la main est « attachee ».
func _firstdraw(holder: Control = null) -> void:
	var holes: Array = [_hand_rect()]
	if holder != null:
		_frozen = holder
		holder.process_mode = Node.PROCESS_MODE_DISABLED # fige son vol (le tween suit le noeud) : la carte reste au centre, au-dessus du voile (tut_63)
		holes.append(holder.get_global_rect())
	_begin(holes)
	var lb := _balloon("medium", Vector2(960, 162))
	await _text_step(lb, {"text": TEXT["page19_a"][0], "delay": false, "hands": [{"pos": Vector2(1176, 378), "flip": true}]})
	_end()
	_thaw()

func _thaw() -> void:
	if _frozen != null and is_instance_valid(_frozen):
		_frozen.process_mode = Node.PROCESS_MODE_INHERIT
	_frozen = null

func _exit_tree() -> void:
	_thaw()

## Carte piochee en vol (BoardUI._show_draw) deja retournee face visible au centre, ou null.
func _drawn_holder(id: String) -> Control:
	for h in get_tree().get_nodes_in_group("drawn_card"):
		var c := h as Control
		if c != null and str(c.get_meta("draw_id", "")) == id and c.get_child_count() > 1 and (c.get_child(1) as Control).visible and c.scale.x > 0.99:
			return c
	return null

## TutorialBaitScene : colonne HEROES IN TOWN attachee, bulle large (800,350), main retournee a (LimitedLeftEdge + 200, 320), icones a (bulle + (-240,60)).
func _bait() -> void:
	_begin([Rect2(0, 0, 183, 903)])
	var lb := _balloon("large", Vector2(1040, 350))
	var hands := [{"pos": Vector2(200, 320), "flip": true}]
	await _text_step(lb, {"text": TEXT["page20"][0], "finish": _show_treasures, "hands": hands})
	await _text_step(lb, {"text": TEXT["page21"][0], "hands": hands})
	_end()

## TutorialAdventureScene (isReinforcement par defaut : le texte s'affiche d'un coup), positions du C# (+ 240 en x).
func _adv(n: int) -> void:
	var holes: Array = []
	var sprites: Array = []
	var kind := "long"
	var c := Vector2(960, 540)
	var hands: Array = []
	match n:
		22: # cs:236 : le heros et le total de degats ; bulle large (600,250), mains (320,700) et (LimitedRightEdge - 710, 490)
			var lane: Dictionary = board._lane[1]
			holes = [(lane["entrance"] as Control).get_global_rect(), Rect2((lane["root"] as Control).global_position + Vector2(1355, 12), UiKit.tex(board.TEX_TOTAL_DAMAGE).get_size())]
			kind = "large"
			c = Vector2(840, 250)
			# BUG DE L'APK reproduit : UpdateCommonVisibility applique le retournement / la rotation / l'origine de la main 2 a la transform de la main 1
			# (TutorialBaseScene.cs:165-167) : la main 1 est retournee (doigt vers la gauche, sur le heros), la main 2 reste normale (doigt vers la droite, sur les degats).
			hands = [{"pos": Vector2(560, 700), "flip": true}, {"pos": Vector2(1210, 490)}]
		23: # cs:247 : la salle de BMA027 et la barre de temps ; bulle medium (salle + (0,-350)), main (salle + (-250,0))
			var s := _slot_node(0)
			var rc := s.get_global_rect() if s != null else Rect2(840, 640, 130, 180)
			holes = [rc]
			if board._win_bar.visible:
				holes.append(board._win_bar.get_global_rect())
			kind = "medium"
			c = rc.get_center() + Vector2(0, -350)
			hands = [{"pos": rc.get_center() + Vector2(-250, 0)}]
		24: # cs:334 : bulle long (VirtualWidth/2, VirtualHeight/2 - 350), main (centre + (-300, 200))
			c = Vector2(960, 190)
			hands = [{"pos": Vector2(660, 740)}]
		25: # cs:223 : boss adverse + panneau OneOpponentDetail (1709,60) ; bulle medium (panneau + (-550,100)), main (panneau + (-200,50))
			holes = [Rect2(1708, 62, 212, 435)] # tut_126 (Pillow) : panneau y 60..497 ; le boss seul est eclairci, pas sa plateforme
			sprites = [board._lane[0]["sprite"]]
			kind = "medium"
			c = Vector2(1159, 160)
			hands = [{"pos": Vector2(1509, 110)}]
		26: # cs:219 : mon boss + panneau ChallengerDetail (1709,483) ; bulle medium (panneau + (-550,200)), main (panneau + (-200,150))
			holes = [Rect2(1708, 483, 212, 549)] # tut_108 (Pillow) : panneau + LevelUpBg (TopRightPanelEntity.cs:146-151) = y 483..1032, bouton LEVEL UP compris
			sprites = [board._lane[1]["sprite"]]
			kind = "medium"
			c = Vector2(1159, 683)
			hands = [{"pos": Vector2(1509, 633)}]
		28: # cs:313 : le sort sur la pile, la main et la barre ; bulle long (VirtualWidth/2, VirtualHeight/2 - 400), main (400,350)
			if board._stack_ui != null and is_instance_valid(board._stack_ui):
				for k in board._stack_ui.get_children():
					if k is Control and (k as Control).visible:
						holes.append((k as Control).get_global_rect())
			holes.append(_hand_rect())
			if board._win_bar.visible:
				holes.append(board._win_bar.get_global_rect())
			c = Vector2(960, 140)
			hands = [{"pos": Vector2(640, 350)}]
		29: # cs:321 : bulle long (VirtualWidth x 0,6, 150), main verticale (200,350)
			c = Vector2(1104, 150)
			hands = [{"pos": Vector2(440, 350), "vertical": true}]
	_begin(holes, sprites)
	var lb := _balloon(kind, c)
	var text: String = TEXT["page%d" % n][0]
	await _text_step(lb, {"text": text, "start": text.length(), "hands": hands})
	_end()

## TutorialLevelUpScene : le boss et le bouton LEVEL UP attaches ; p30 bulle long (VirtualWidth x 0,5, 400) main (LimitedLeftEdge + 150, 640) ;
## p31 bulle long (LeftEdge + 500, 580) mains (LimitedRightEdge - 395, 950) et (LimitedRightEdge - 550, 780).
func _levelup() -> void:
	_begin([(board._lane[1]["platform"] as Control).get_global_rect(), board.levelup_btn.get_global_rect()])
	var lb := _balloon("long", Vector2(960, 400))
	await _text_step(lb, {"text": TEXT["page30"][0], "hands": [{"pos": Vector2(150, 640)}]})
	lb.get_parent().queue_free() # p31 : une nouvelle bulle remplace la premiere (cs: EntityManager.Remove(balloon))
	lb = _balloon("long", Vector2(500, 580))
	await _text_step(lb, {"text": TEXT["page31"][0], "hands": [{"pos": Vector2(1525, 950)}, {"pos": Vector2(1370, 780)}]})
	_end()
	_lvl_done = true
	_finish() # le jeu continue normalement : banniere LEVEL UP puis choix de niveau

# ---------------------------------------------------------------------------------------------------------------------
# Briques de scene
# ---------------------------------------------------------------------------------------------------------------------

func _begin(holes: Array = [], sprites: Array = []) -> void:
	if _scene != null:
		_scene.queue_free()
	_scene = Control.new()
	_scene.name = "TutorialScene"
	_scene.size = Vector2(1920, 1080)
	_scene.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scene.modulate.a = 0.0
	_fade = 0.0
	add_child(_scene)
	_veil = Control.new()
	_veil.size = Vector2(1920, 1080)
	_veil.mouse_filter = Control.MOUSE_FILTER_STOP # TutorialBaseScene.cs:84-97 : un rectangle plein ecran capte les taps
	_veil.gui_input.connect(_on_veil_input)
	_veil.draw.connect(_draw_veil)
	_scene.add_child(_veil)
	_holes = holes.filter(func(r): return r is Rect2 and (r as Rect2).has_area())
	_sprites = sprites.filter(func(n): return n is TextureRect and is_instance_valid(n) and (n as TextureRect).visible and (n as TextureRect).texture != null)
	_mask = null
	_hands.clear()
	_scene_ptr = null
	_king = null
	_detail = null
	_skip = false
	_tap_wait = false
	_hint_clear()
	_veil.queue_redraw()

func _end() -> void:
	if _scene != null:
		_scene.queue_free()
	_scene = null
	_veil = null
	_hands.clear()
	_scene_ptr = null
	_king = null
	_detail = null
	_tap_wait = false

func _on_veil_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		_veil.accept_event()
		if not (ev as InputEventMouseButton).pressed:
			tap()

## Un tap : fin de la frappe / de l'attente en cours (TrySkip), ou passage a la suite si la scene attend un tap (CreateBackTapTask). Public : les tests tapent par ici.
func tap() -> void:
	if _tap_wait:
		_tap_wait = false
		tapped.emit()
	else:
		_skip = true

## Voile (TutorialBaseScene.cs:70-80) : mascara_black plein ecran = tout l'ecran moins les entites attachees ; mascara_00 = cadre noir a trou cale a droite.
func _draw_veil() -> void:
	var rects: Array = [Rect2(0, 0, 1920, 1080)]
	if _mask != null:
		var m: Vector2 = _mask
		# mascara_00 (439 x 313) : l'extraction a une colonne transparente et un pixel (0,0) transparent -> sprite (1,0,438,313) a (x+1, y) + bandes noires autour, pas de bande a droite
		rects = [Rect2(0, 0, m.x + 1.0, 1080), Rect2(m.x + 1.0, 0, 1920.0 - m.x - 1.0, m.y), Rect2(m.x + 1.0, m.y + 313.0, 1920.0 - m.x - 1.0, 1080.0 - m.y - 313.0)]
		if _mask_tex != null:
			_veil.draw_texture_rect_region(_mask_tex, Rect2(m.x + 1.0, m.y, 438, 313), Rect2(1, 0, 438, 313))
	else:
		for h in _holes:
			rects = _minus(rects, h as Rect2)
	for r in rects:
		_veil.draw_rect(r as Rect2, VEIL)
	if _mask == null:
		for sp in _sprites:
			if is_instance_valid(sp): # recopie du sprite au-dessus du voile : l'entite attachee de l'APK n'eclaircit pas le decor derriere elle
				var t := sp as TextureRect
				_veil.draw_texture_rect(t.texture, Rect2(t.global_position - _veil.global_position, t.size), false)

static func _minus(rects: Array, h: Rect2) -> Array:
	var out: Array = []
	for r in rects:
		var rr: Rect2 = r
		if not rr.intersects(h):
			out.append(rr)
			continue
		var i := rr.intersection(h)
		if i.position.y > rr.position.y:
			out.append(Rect2(rr.position.x, rr.position.y, rr.size.x, i.position.y - rr.position.y))
		if i.end.y < rr.end.y:
			out.append(Rect2(rr.position.x, i.end.y, rr.size.x, rr.end.y - i.end.y))
		if i.position.x > rr.position.x:
			out.append(Rect2(rr.position.x, i.position.y, i.position.x - rr.position.x, i.size.y))
		if i.end.x < rr.end.x:
			out.append(Rect2(i.end.x, i.position.y, rr.end.x - i.end.x, i.size.y))
	return out

## Bulle (BalloonEntity.cs:69-87) : origine au centre ; le texte part a (-0,45 L + marge, -0,32 H) du centre, largeur 0,8 L x 1,2 d'echelle, police arcadepix x 1,2, interligne 6.
func _balloon(kind: String, center: Vector2) -> Label:
	var d: Dictionary = BALLOONS[kind]
	var rect: Vector2 = d["rect"]
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scene.add_child(holder)
	var tx := UiKit.tex(DIR + str(d["tex"]) + ".webp")
	if tx != null:
		var t := TextureRect.new()
		t.texture = tx
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		t.position = center - tx.get_size() / 2.0
		t.size = tx.get_size()
		holder.add_child(t)
	var lb := Label.new()
	lb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lb.add_theme_font_override("font", load(FONT)) # police nue (UiKit.font ajoute un repli qui grandit la ligne de 25 a 35 px : l'APK a 21 x 1,2 + 6 x 1,2 = 32 px par ligne)
	lb.add_theme_font_size_override("font_size", TEXT_SIZE)
	lb.add_theme_color_override("font_color", Color.WHITE)
	lb.add_theme_constant_override("line_spacing", 7)
	lb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lb.position = center + Vector2(rect.x * -0.45 + float(d["hm"]), rect.y * -0.32)
	lb.custom_minimum_size = Vector2(rect.x * 0.8 * 1.2, 0)
	lb.size = Vector2(rect.x * 0.8 * 1.2, rect.y)
	lb.visible_characters = 0
	holder.add_child(lb)
	return lb

func _add_king() -> void:
	var at := AtlasTexture.new()
	at.atlas = UiKit.tex(DIR + "kingcroak_anim.webp")
	at.region = Rect2(KING_REGIONS[0], KING_FRAME)
	_king = TextureRect.new()
	_king.texture = at
	_king.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_king.stretch_mode = TextureRect.STRETCH_SCALE
	_king.flip_h = true # Effect = FlipHorizontally
	_king.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST # AddressMode.PointClamp
	_king.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_king.position = KING_POS
	_king.size = KING_FRAME * KING_SCALE
	_scene.add_child(_king) # devant la bulle (LocalDrawOrder -0,5 contre -0,1)
	_king_t = 0.0

func _mk_hand(spec: Dictionary) -> Hand:
	var h := Hand.new(UiKit.tex(DIR + "hand.webp"), bool(spec.get("flip", false)), bool(spec.get("vertical", false)))
	h.anchor = spec["pos"]
	h.position = h.anchor
	_scene.add_child(h)
	return h

func _show_hands(specs: Array) -> void:
	for h in _hands:
		if is_instance_valid(h):
			(h as Node).queue_free()
	_hands.clear()
	for s in specs:
		_hands.append(_mk_hand(s as Dictionary))

## Pointeur pose sur une carte de la main (enfant de la carte dans l'APK : suit son echelle et sa rotation).
func _card_hand(fid: String, local: Vector2, rot: float, parent: Node) -> Hand:
	var node := _card_node(fid)
	if node == null:
		return null
	var h := Hand.new(UiKit.tex(DIR + "hand.webp"), false, false)
	h.card = node
	h.card_id = fid
	h.local = local
	h.krot = rot
	parent.add_child(h)
	h.update(0.0)
	return h

## Une etape de texte (CreateShowTextTask) : mains et masque remis a zero, frappe (un tap la saute), 0,2 s, tache de fin (icones...), 2e texte, mains, puis attente d'un tap.
## sp : text, start (lettres deja affichees), delay, second, mask, finish (Callable), after (Callable), hands.
func _text_step(lb: Label, sp: Dictionary) -> void:
	_show_hands([])
	if _detail != null:
		_detail.queue_free() # l'APK retire le detail au debut de l'etape suivante
		_detail = null
	_mask = sp.get("mask", null)
	_veil.queue_redraw()
	_skip = false
	var text: String = sp["text"]
	await _type(lb, text, int(sp.get("start", 0)))
	if bool(sp.get("delay", true)):
		await _wait(AFTER_TYPE)
	if sp.has("finish"):
		_skip = false
		await (sp["finish"] as Callable).call()
	if sp.has("second"):
		_skip = false
		await _type(lb, text + str(sp["second"]), text.length())
	if sp.has("after"):
		(sp["after"] as Callable).call()
	_show_hands(sp.get("hands", []))
	_skip = false
	_tap_wait = true
	await tapped

## AnimatedWritingBehavior.Update : lettres = (int)(ecoule x 15), reprise a `start` ; un tap affiche tout.
func _type(lb: Label, text: String, start: int) -> void:
	lb.text = text
	var total := text.length()
	var t := float(start) / TYPE_CPS
	lb.visible_characters = mini(start, total)
	while true:
		var dt: float = await tick
		if _skip:
			break
		t += dt
		var n := int(t * TYPE_CPS)
		if n >= total:
			break
		lb.visible_characters = n
	lb.visible_characters = -1

func _wait(sec: float) -> void:
	var t := 0.0
	while t < sec and not _skip:
		t += await tick

## 10 ames (SoulLoadingComponent) ou 5 blessures + pierre tombale (WoundLoadingComponent) : vides en parallele (0,2 s), pleines une a une (0,2 s), lueurs en parallele ; un tap termine.
func _load_icons(kind: String) -> void:
	var soul := kind == "soul"
	var n := 10 if soul else 5
	var base := Vector2(930, 385) if soul else Vector2(990, 347) # Position + 240, origine centre, icones espacees de 50
	_detail = Control.new()
	_detail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scene.add_child(_detail)
	var offs: Array = []
	var ons: Array = []
	var glows: Array = []
	var last: TextureRect = null
	for i in n:
		offs.append(_icon(DIR + ("soul_empty.webp" if soul else "wound_empty.webp"), base + Vector2(50 * i, 0)))
	for i in n:
		ons.append(_icon(DIR + ("soul.webp" if soul else "wound.webp"), base + Vector2(50 * i, 0)))
	if soul:
		for i in n:
			glows.append(_icon(DIR + "soul_glow.webp", base + Vector2(50 * i, 0)))
	else:
		last = _icon(DIR + "boss_tombstone.webp", base + Vector2(50 * n, 0), true) # origine (0, 0,5) : bord gauche, milieu
	await _fade_all(offs, 0.2)
	for o in ons:
		await _fade_all([o], 0.2)
	await _fade_all(glows if soul else [last], 0.2)
	for g in offs + ons + glows + ([last] if last != null else []):
		(g as CanvasItem).modulate.a = 1.0 # FinishState

func _icon(path: String, center: Vector2, left_mid := false) -> TextureRect:
	var tx := UiKit.tex(path)
	var t := TextureRect.new()
	t.texture = tx
	t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST # AddressMode.PointClamp
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.size = tx.get_size()
	t.position = center - (Vector2(0, tx.get_height() / 2.0) if left_mid else tx.get_size() / 2.0)
	t.modulate.a = 0.0
	_detail.add_child(t)
	return t

func _fade_all(nodes: Array, dur: float) -> void:
	var t := 0.0
	while t < dur and not _skip:
		t += await tick
		for n in nodes:
			(n as CanvasItem).modulate.a = clampf(t / dur, 0.0, 1.0)
	if _skip:
		for n in nodes:
			(n as CanvasItem).modulate.a = 1.0

## TutorialBaitScene.CreateShowDetailTask : fighter, thief, cleric, mage a (bulle + (-240,60)) + 160 n, decalages 3/6/0/6, fondu 0,5 s.
func _show_treasures() -> void:
	_detail = Control.new()
	_detail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scene.add_child(_detail)
	_detail.modulate.a = 0.0
	var ys := [3.0, 6.0, 0.0, 6.0]
	var names := ["icon_fighter", "icon_thief", "icon_cleric", "icon_mage"]
	for i in 4:
		var tx := UiKit.tex(DIR + names[i] + ".webp")
		var t := TextureRect.new()
		t.texture = tx
		t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		t.size = tx.get_size()
		t.position = Vector2(800 + 160 * i, 410 + float(ys[i])) - tx.get_size() / 2.0
		_detail.add_child(t)
	var t0 := 0.0
	while t0 < 0.5 and not _skip:
		t0 += await tick
		_detail.modulate.a = clampf(t0 / 0.5, 0.0, 1.0)
	_detail.modulate.a = 1.0

func _slot_node(di: int) -> Control:
	for s in board._dungeon_slots:
		if (s as DungeonSlot).slot_index == di and not (s as DungeonSlot).current_stack.is_empty():
			return s as Control
	return null

## Bulle du boss (BossHint, boss_globe) : meme geometrie que « HEY! YOU CAN BUILD A ROOM! » (BoardUI._warn_show) ; entre en 0,5 s (opacite 0,5 -> 1, echelle 0,7 -> 1,
## CubicEase InOut) et ne se ferme qu'a un appui hors d'elle (fondu de sortie 0,5 s), jamais d'elle-meme (HideWhenTouchBehavior.cs).
func _show_hint(text: String) -> void:
	_hint_clear()
	var b := Control.new()
	b.name = "BossHint"
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.position = Vector2(1285, 589) # tut_26 (Pillow) : cadre blanc x 1285..1516, y 593..719 ; la bulle de la partie normale (1230, 542) n'est pas celle du tutoriel
	b.size = Vector2(238, 150)
	UiKit.image(b, board.UI_DIR + "boss_globe.webp", Vector2.ZERO, Vector2(238, 150))
	var t := UiKit.label(b, text, 21, Color.WHITE, Vector2(33, 6), 170.0, UiKit.FONT_A, HORIZONTAL_ALIGNMENT_CENTER) # texte plus etroit que la bulle : tut_26 coupe « HIT / CONTINUE, / MINION »
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.add_theme_constant_override("line_spacing", -4)
	t.custom_minimum_size = Vector2(170.0, 118.0)
	t.size = Vector2(170.0, 118.0)
	t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(b)
	_hint = b
	_hint_age = 0.0
	if not board.skip_animations:
		b.pivot_offset = b.size / 2.0
		b.modulate.a = 0.5
		b.scale = Vector2(0.7, 0.7)
		var tw := b.create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(b, "modulate:a", 1.0, HINT_TIME)
		tw.tween_property(b, "scale", Vector2.ONE, HINT_TIME)

func _hint_clear() -> void:
	if _hint != null and is_instance_valid(_hint):
		_hint.queue_free()
	_hint = null

func _input(ev: InputEvent) -> void:
	if _hint == null or not is_instance_valid(_hint) or _hint_age < HINT_TIME or _hint.has_meta("closing"):
		return
	if not (ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed) or _hint.get_global_rect().has_point((ev as InputEventMouseButton).position):
		return
	if board.skip_animations: # ZoomOutWhenTouchOutside : un toucher hors de la bulle la ferme en fondu
		_hint_clear()
		return
	var h := _hint
	h.set_meta("closing", true)
	var tw := h.create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(h, "modulate:a", 0.0, HINT_TIME)
	tw.tween_callback(func():
		if _hint == h:
			_hint_clear())

# ---------------------------------------------------------------------------------------------------------------------
# Animations (King Croak, mains, pointeurs de defausse)
# ---------------------------------------------------------------------------------------------------------------------

func _animate(dt: float) -> void:
	if _scene != null:
		_fade = minf(_fade + dt / FADE_IN, 1.0)
		_scene.modulate.a = _fade
		if _fade < 1.0 and _veil != null:
			_veil.queue_redraw() # le voile se redessine pendant le fondu (1re image d'une texture neuve)
		for h in _hands:
			if is_instance_valid(h):
				(h as Hand).update(dt)
		if _scene_ptr != null and is_instance_valid(_scene_ptr):
			if not is_instance_valid(_scene_ptr.card):
				_scene_ptr.card = _card_node(_scene_ptr.card_id)
			_scene_ptr.update(dt)
		if _king != null and is_instance_valid(_king):
			_king_t += dt
			var f := int(_king_t * KING_FPS) % KING_REGIONS.size()
			(_king.texture as AtlasTexture).region = Rect2(KING_REGIONS[f], KING_FRAME)
	_update_pointers(dt)

## Pointeurs de la defausse d'ouverture (AddCarouselCardsBehavior.InTutorialModeAddHandsToDiscardCards) : sur BMA026 et BMA055, local (-50,400), rotation -90 degres,
## retires avec un fondu de 0,5 s quand la carte est choisie (TutorialSelectorComponent.RemoveHandPointerFromCard).
func _update_pointers(dt: float) -> void:
	var live := _discard_pending() and bool(_done.get("intro2", false))
	for id in CARD_DISCARD:
		var node := _card_node(id) if live else null
		if node == null or _ptr_gone.has(id):
			if _ptrs.has(id):
				(_ptrs[id] as Node).queue_free()
				_ptrs.erase(id)
			continue
		if not _ptrs.has(id):
			var h := Hand.new(UiKit.tex(DIR + "hand.webp"), false, false)
			h.card_id = id
			h.local = Vector2(-50, 400)
			h.krot = -PI / 2.0
			_ptr_layer.add_child(h)
			_ptrs[id] = h
		var ptr: Hand = _ptrs[id]
		ptr.card = node # la main est reconstruite a chaque refresh : on suit le nouveau noeud
		if ptr.fade < 0.0 and board.discard_pick.has((node as CardUI).hand_index):
			ptr.fade = 0.0
		ptr.update(dt)
		if ptr.fade >= 0.5:
			_ptr_gone[id] = true
	if not live:
		for id in _ptrs.keys():
			(_ptrs[id] as Node).queue_free()
		_ptrs.clear()

func _finish() -> void:
	if _finished:
		return
	_finished = true
	if _scene != null:
		_scene.queue_free()
		_scene = null
	if board != null and is_instance_valid(board):
		board.tutorial_gate = Callable() # le jeu continue normalement
		board.refresh()
	queue_free()
