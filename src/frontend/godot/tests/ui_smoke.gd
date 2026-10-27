extends Node
## Smoke test UI : Board.tscn pilote comme un joueur humain, via les memes points d'entree que les vrais clics
## (clic carte de la main, depot sur un emplacement, clic sur une salle, boutons GO / PASS TURN, popups de choix / de cible,
## selecteur de sieges et d'adversaire, menu engrenage, pile de defausse...). Un « humain simule » joue au HASARD (graine fixee)
## parmi les actions legales de l'UI, des parties COMPLETES jusqu'a l'ecran de fin, et verifie apres chaque geste :
##   - aucune erreur script / moteur (Logger) ; partie jamais bloquee ; l'ecran reflete l'etat (phase, main, donjons, pioches,
##     ames / blessures, badges, boutons GO / PASS, popup de choix, ecran de fin) ; un geste legal doit avoir un effet.
## Les REGLES ne sont jamais testees ici (le moteur est verifie par les autres suites) : une anomalie du moteur est seulement signalee.
##
## Usage (depuis src/frontend) :
##   godot --headless --path . res://godot/tests/UiSmoke.tscn                     -> "UISMOKE OK" (CI : 1 partie animee de 3 tours + checks + 5 parties completes)
##   ... -- --games=30 --players=2                       campagne lourde : 30 parties completes a 2 joueurs (graines seed..seed+29)
##   ... -- --games=10 --players=3 --humans=2            3 joueurs dont 2 humains (siege a siege : selecteur de sieges)
## Options (toutes optionnelles ; --games=K ou --seed=N lance la campagne SEULE, sans les checks de base) :
##   --games=K      nombre de parties (defaut 1 avec --seed)      --seed=N      graine de la 1re partie (puis N+1, ...)
##   --players=P    2|3|4|5|6 (defaut : alterne 2,2,3,4 ; 5-6 exigent --sets=crash-landing, voir Match.setup_error)               --humans=H    sieges humains (defaut 1 ; 0 = IA seulement)
##   --sets=a,b     paquets (ex. players-choice,hidden-heroes,tools,tools-wiki,next-level,crash-landing,minibosses ; defaut base)
##   --style=S      random | spells | passive (defaut : alterne)    --turns=N     arrete apres N tours au lieu d'aller a la fin
##   --anim         animations de traversee des heros reelles (temps accelere x6) pour toutes les parties
##   --only=NAME    une seule verification supplementaire (ex. --only=public_lobby, --only=online_menus ou --only=apk_particles : appelle _check_NAME), pour iterer vite
## Chaque anomalie est affichee avec sa graine : « [seed=7 players=3 ...] ... » = la commande pour la rejouer.

const GameManager = preload("res://godot/scripts/GameManager.gd")
const OnlineMenus = preload("res://godot/scripts/OnlineMenus.gd")
const Server = preload("res://godot/server/Server.gd")
const OnlineClient = preload("res://godot/scripts/OnlineClient.gd")
const TutorialScript = preload("res://godot/scripts/TutorialOverlay.gd")

const DUNGEON_N := 5
const MAX_STEPS := 6000
const STUCK_ITERS := 150
const ANIM_TIME_SCALE := 6.0
const STYLES := {
	"random": {"build": 3.0, "drop": 3.0, "spell": 2.0, "ability": 2.0, "extra": 1.5, "pass": 1.0, "go": 3.0, "noise": 0.08},
	"spells": {"build": 1.5, "drop": 1.5, "spell": 6.0, "ability": 6.0, "extra": 4.0, "pass": 0.4, "go": 3.0, "noise": 0.08},
	"passive": {"build": 4.0, "drop": 2.0, "spell": 0.0, "ability": 0.0, "extra": 0.0, "pass": 3.0, "go": 3.0, "noise": 0.04},
}
const CORE_TYPES := ["pickBoss", "buildRoom", "undoBuild", "pass", "passBuild", "adventureNext", "resolveNextHero", "openingDiscard", "resolveLevelUpChoice", "resolveChoice", "playSpell", "useHandRoom", "activateRoom"]

## Compte les erreurs moteur / script (en headless, un SCRIPT ERROR n'arrete pas le processus).
class ErrLogger extends Logger:
	var errors: Array = []
	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, _bt: Array) -> void:
		errors.append("%s:%d %s %s (%s)" % [file, line, code, rationale, function])

var _log := ErrLogger.new()
var _fails: Array = []
var gm: GameManager
var board
var quit_calls := 0
var cfg := {}
var cov := {}                 # chemins UI exerces : compteurs affiches en fin de campagne
var rng := RandomNumberGenerator.new()
var _tag := ""                # [seed=... players=...] de la partie en cours
var _style := "random"
var _acts_turn := 0
var _acts_turn_no := -1
var _dbg := ""
var _cancelled := false       # un CANCEL de ciblage vient d'avoir lieu : « sans effet » est alors normal

func _ready() -> void:
	cfg = _parse_args()
	OS.add_logger(_log)
	var t0 := Time.get_ticks_msec()
	await _main()
	OS.remove_logger(_log)
	for e in _log.errors.slice(0, 15):
		_fails.append("erreur runtime : " + e)
	var keys := cov.keys()
	keys.sort()
	print("UISMOKE couverture : ", ", ".join(keys.map(func(k): return "%s=%d" % [k, cov[k]])))
	print("UISMOKE duree : %.1fs" % ((Time.get_ticks_msec() - t0) / 1000.0))
	if _fails.is_empty():
		print("UISMOKE OK")
		get_tree().quit(0)
	else:
		for f in _fails.slice(0, 40):
			print("UISMOKE ECHEC : ", f)
		get_tree().quit(1)

func _parse_args() -> Dictionary:
	var d := {"turns": 0, "games": 0, "seed": -1, "players": 0, "humans": 1, "sets": ["base"], "style": "", "anim": false, "only": ""}
	for a in OS.get_cmdline_user_args():
		if not a.begins_with("--"):
			continue
		var kv: PackedStringArray = a.substr(2).split("=", true, 1)
		var v: String = kv[1] if kv.size() > 1 else "true"
		match kv[0]:
			"turns", "games", "seed", "players", "humans":
				d[kv[0]] = int(v)
			"sets":
				d["sets"] = Array(v.split(",", false))
			"style", "playstyle":
				d["style"] = v
			"anim":
				d["anim"] = true
			"only":
				d["only"] = v
	var err := Match.setup_error(int(d["players"]), d["sets"])
	if err != "":
		print("UISMOKE ECHEC : ", err)
		get_tree().quit(1)
	return d

func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout

## Attend la fin d'une transition ColorFade de Main (1,0 s, APK : Main.go) ; les durees de l'APK ne sont pas raccourcies.
func _nav(main) -> void:
	await get_tree().process_frame
	var t0 := Time.get_ticks_msec()
	while (main.is_fading() or main._fade_layer.get_child_count() > 0) and Time.get_ticks_msec() - t0 < 4000: # horloge reelle : la transition dure 1,0 s quel que soit le nombre d'images
		await get_tree().process_frame
	await get_tree().process_frame
	_check(not main.is_fading(), "transition : le voile reste bloque apres 4 s")

func _fail(msg: String) -> void:
	if _fails.size() < 60:
		_fails.append("%s %s" % [_tag, msg])

func _check(cond: bool, msg: String) -> bool:
	if not cond:
		_fail(msg)
	return cond

## Anomalie du MOTEUR (hors perimetre UI : le moteur est verifie contre l'APK) : signalee, jamais bloquante.
func _engine_note(msg: String) -> void:
	var k := "MOTEUR: " + msg
	if not cov.has(k):
		print("UISMOKE %s %s" % [_tag, k])
	_cov(k)

func _cov(k: String) -> void:
	cov[k] = int(cov.get(k, 0)) + 1

# ---------------------------------------------------------------------------------------------------------------------
# Orchestration
# ---------------------------------------------------------------------------------------------------------------------

func _main() -> void:
	AudioManager.rec_enabled = true # espion de lecture (rien ne s'entend en headless) : voir _check_audio
	var games: Array = []
	if str(cfg["only"]) != "":
		await call("_check_" + str(cfg["only"]))
		return
	if int(cfg["games"]) > 0 or int(cfg["seed"]) >= 0:
		var n: int = maxi(1, int(cfg["games"]))
		var s0: int = maxi(0, int(cfg["seed"]))
		for i in n:
			games.append(_game_cfg(i, s0 + i))
	else:
		# CI : parties animees (traversee des heros reelle) puis campagne courte (sans animation : tours entiers en quelques secondes).
		games.append({"seed": 11, "players": 2, "humans": 1, "sets": ["base"], "style": "random", "anim": true, "turns": 3})
		games.append({"seed": 21, "players": 2, "humans": 1, "sets": ["base"], "style": "spells", "anim": false, "turns": 0})
		games.append({"seed": 22, "players": 2, "humans": 1, "sets": ["players-choice", "hidden-heroes", "tools"], "style": "random", "anim": false, "turns": 0})
		games.append({"seed": 23, "players": 3, "humans": 1, "sets": ["base"], "style": "spells", "anim": false, "turns": 0})
		games.append({"seed": 24, "players": 4, "humans": 2, "sets": ["base"], "style": "random", "anim": false, "turns": 4})
		games.append({"seed": 25, "players": 2, "humans": 1, "sets": ["players-choice", "hidden-heroes", "tools", "tools-wiki", "next-level", "crash-landing", "minibosses"], "style": "spells", "anim": false, "turns": 5})
		games.append({"seed": 26, "players": 2, "humans": 1, "sets": ["tools-wiki"], "style": "spells", "anim": false, "turns": 5}) # Tools of Hero-Kind (wiki) : Objets, useItem, salles THK
		games.append({"seed": 27, "players": 2, "humans": 1, "sets": ["iod", "crash-landing"], "style": "spells", "anim": false, "turns": 5}) # Implements of Destruction (wiki) : Objets IOD, useItem, boss de niveau
		games.append({"seed": 28, "players": 2, "humans": 1, "sets": ["players-choice", "players-choice-wiki"], "style": "spells", "anim": false, "turns": 5}) # Player's Choice (wiki) : Ghoulyard, Bone Crank, Agent of Evil, Pixel Lincoln
		games.append({"seed": 29, "players": 5, "humans": 1, "sets": ["crash-landing"], "style": "random", "anim": false, "turns": 4}) # 5-6 joueurs (Crash Landing)
		games.append({"seed": 30, "players": 6, "humans": 2, "sets": ["crash-landing", "tools"], "style": "spells", "anim": false, "turns": 4})
		games.append({"seed": 31, "players": 6, "humans": 6, "sets": ["crash-landing"], "style": "random", "anim": false, "turns": 3}) # Pass and Play a 6 : barre des 6 sieges + barre des 5 adversaires
	for g in games:
		await _play_game(g)
		if not _log.errors.is_empty():
			return
	if _fails.is_empty() and int(cfg["games"]) == 0 and int(cfg["seed"]) < 0:
		await _extra_checks()

func _game_cfg(i: int, seed_: int) -> Dictionary:
	var styles := ["random", "spells", "passive"]
	var counts := [2, 2, 3, 4]
	return {
		"seed": seed_,
		"players": int(cfg["players"]) if int(cfg["players"]) >= 2 else int(counts[i % counts.size()]),
		"humans": int(cfg["humans"]),
		"sets": cfg["sets"],
		"style": str(cfg["style"]) if str(cfg["style"]) != "" else str(styles[i % styles.size()]),
		"anim": bool(cfg["anim"]),
		"turns": int(cfg["turns"]),
	}

func _teardown() -> void:
	Engine.time_scale = 1.0
	if board != null and is_instance_valid(board):
		board.queue_free()
	if gm != null and is_instance_valid(gm):
		gm.queue_free()
	board = null
	gm = null
	await get_tree().process_frame

func _start(g: Dictionary) -> void:
	await _teardown()
	seed(int(g["seed"]))
	CardDB._rng.seed = int(g["seed"])
	rng.seed = int(g["seed"]) * 7919 + 13
	gm = GameManager.new()
	add_child(gm)
	gm.rng.seed = int(g["seed"]) # Match._ready l'a randomise
	gm.start_new_game(int(g["players"]), int(g["humans"]), g["sets"])
	board = load("res://godot/scenes/Board.tscn").instantiate()
	board.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(board)
	board.skip_animations = not bool(g["anim"])
	board.win_time_scale = 0.12 # fenetres chronometrees (3 s / 6 s) raccourcies pour les parties completes ; _check_windows teste les vraies durees
	board.set_process(false) # on appelle board._process(dt) a la main : rapide et reproductible
	board.setup(gm, func(): quit_calls += 1)
	if bool(g["anim"]):
		Engine.time_scale = ANIM_TIME_SCALE
	await get_tree().process_frame

## Une partie complete (ou limitee a g.turns tours) jouee par l'humain simule. Les anomalies vont dans _fails avec la graine.
func _play_game(g: Dictionary) -> void:
	var tag := "[seed=%d players=%d humans=%d sets=%s style=%s%s]" % [g["seed"], g["players"], g["humans"], ",".join(g["sets"]), g["style"], " anim" if g["anim"] else ""]
	_tag = tag
	_style = str(g["style"])
	var n_fail := _fails.size()
	var t0 := Time.get_ticks_msec()
	await _start(g)
	var last_sig := ""
	var stuck := 0
	var steps := 0
	var anim_t0 := 0
	var finished := false
	while steps < MAX_STEPS:
		var G: Dictionary = gm.G
		if _fails.size() > n_fail or not _log.errors.is_empty():
			break
		if G.get("gameOver") != null:
			finished = true
			break
		if int(g["turns"]) > 0 and int(G.get("turn", 0)) >= int(g["turns"]) and str(G.get("phase", "")) == "build" and (G.get("pendingChoice", {}) as Dictionary).is_empty():
			finished = true
			break
		steps += 1
		await get_tree().process_frame
		if board._animating_hero:
			if anim_t0 == 0:
				anim_t0 = Time.get_ticks_msec()
				_cov("anim_hero")
			elif Time.get_ticks_msec() - anim_t0 > 30000:
				_fail("animation de heros jamais terminee (30 s)")
				break
			continue
		anim_t0 = 0
		board._process(0.21) # IA + passes automatiques de l'UI (dt proche d'un vrai pas : l'IA passe avant la passe auto de 0,45 s)
		await get_tree().process_frame
		_check_ui()
		if _fails.size() > n_fail:
			break
		if board._animating_hero: # le pas de l'IA vient de lancer une animation : le joueur attend (GO est ignore pendant l'animation)
			continue
		await _act()
		await get_tree().process_frame
		_check_ui()
		G = gm.G
		var adv_sig: Dictionary = (G.get("adventure", {}) as Dictionary).duplicate()
		adv_sig.erase("hero")
		var sig := JSON.stringify([G.get("phase"), G.get("turn"), (G.get("log", []) as Array).size(), (G.get("log", []) as Array).slice(-1), G.get("pendingChoice", {}), adv_sig, G.get("adventurePausePassed"), (G.get("stack", []) as Array).size()])
		stuck = stuck + 1 if sig == last_sig else 0
		last_sig = sig
		if stuck > STUCK_ITERS:
			var adv: Dictionary = (G.get("adventure", {}) as Dictionary).duplicate()
			adv.erase("hero")
			var legal := {}
			for pid in G["players"]:
				legal[pid] = (gm.legal_moves(int(pid)) as Array).map(func(m): return m["type"])
			_fail("partie bloquee : phase %s tour %s anim=%s actif=%s popup=%s adv=%s pile=%d coups=%s btn(go=%s/%s pass=%s) log=%s" % [G.get("phase"), G.get("turn"), board._animating_hero, gm.active_player(), board._popup_kind, JSON.stringify(adv), (G.get("stack", []) as Array).size(), JSON.stringify(legal), board.btn_advance.visible, board.btn_advance.disabled, board.btn_pass.visible, JSON.stringify((G["log"] as Array).slice(-3))])
			break
	if _fails.size() > n_fail or not _log.errors.is_empty():
		return
	if not finished:
		_fail("partie trop longue : %d gestes sans fin (tour %s phase %s)" % [steps, gm.G.get("turn"), gm.G.get("phase")])
		return
	_cov("games")
	await _check_final(int(g["turns"]) == 0)
	print("UISMOKE %s tours=%s gestes=%d %.1fs%s" % [tag, gm.G.get("turn"), steps, (Time.get_ticks_msec() - t0) / 1000.0, "" if _fails.size() == n_fail else " ECHEC"])

# ---------------------------------------------------------------------------------------------------------------------
# Le joueur simule
# ---------------------------------------------------------------------------------------------------------------------

func _hand_cards() -> Array:
	return board.hand_layer.get_children().filter(func(c): return not c.is_queued_for_deletion())

## Selecteur d'adversaire : vignettes de la colonne droite (3-4 joueurs) ou boutons P<n> de la barre du haut (5-6) ; `selected` = deja affiche.
func _foe_buttons() -> Array:
	return (_buttons(board.foe_bar) + _buttons(board.opp_box)).filter(func(b): return not (b as Button).disabled and not bool((b as Button).get_meta("selected", false)))

func _buttons(n: Node, out: Array = []) -> Array:
	for c in n.get_children():
		if c.is_queued_for_deletion():
			continue
		if c is Button:
			out.append(c)
		_buttons(c, out)
	return out

func _sig() -> String:
	var G: Dictionary = gm.G
	var adv: Dictionary = (G.get("adventure", {}) as Dictionary).duplicate()
	adv.erase("hero")
	var hands := {}
	for pid in G["players"]:
		var pl: Dictionary = G["players"][pid]
		hands[pid] = [(pl["hand"] as Array).size(), pl.get("passed"), pl.get("hasActed"), pl.get("buildsThisTurn"), (pl["dungeon"] as Array).size(), pl.get("coins")]
	return JSON.stringify([G.get("phase"), G.get("turn"), (G.get("log", []) as Array).size(), (G.get("log", []) as Array).slice(-2), G.get("pendingChoice", {}), adv, G.get("adventurePausePassed"), (G.get("stack", []) as Array).size(), G.get("stackPassed"), G.get("buildWindow"), (G.get("logs", []) as Array).size(), (G["decks"]["roomDiscard"] as Array).size(), (G["decks"]["spellDiscard"] as Array).size(), hands])

## Un siege humain qui a quelque chose a faire (au hasard s'il y en a plusieurs) ; -1 si aucun.
func _pick_actor() -> int:
	var humans: Array = []
	for pid in gm.G["players"]:
		if not bool(gm.G["players"][pid].get("isAI", false)):
			humans.append(int(pid))
	for i in range(humans.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = humans[i]
		humans[i] = humans[j]
		humans[j] = t
	if humans.has(board.view_pid) and rng.randf() < 0.8: # on reste sur le siege affiche tant qu'il a quelque chose a faire
		humans.erase(board.view_pid)
		humans.push_front(board.view_pid)
	for pid in humans:
		if not gm.legal_moves(int(pid)).is_empty():
			return int(pid)
	return -1

func _act() -> void:
	var G: Dictionary = gm.G
	if int(G.get("turn", 0)) != _acts_turn_no:
		_acts_turn_no = int(G.get("turn", 0))
		_acts_turn = 0
	var pid := _pick_actor()
	if pid < 0:
		return
	if pid != board.view_pid: # hotseat : on bascule de siege avec le selecteur
		var found := false
		for b in _buttons(board.seat_bar):
			if (b as Button).text == "PLAYER %d" % (pid + 1):
				found = true
				if _check(not (b as Button).disabled and board.seat_bar.visible, "selecteur de sieges : bouton PLAYER %d inutilisable" % (pid + 1)):
					(b as Button).pressed.emit()
					_cov("seat_switch")
		_check(found, "selecteur de sieges : pas de bouton pour le siege humain %d" % (pid + 1))
		await get_tree().process_frame
		_check(board.view_pid == pid, "selecteur de sieges : vue %d au lieu de %d" % [board.view_pid, pid])
		return
	var moves: Array = _ui_moves(pid)
	var pc: Dictionary = G.get("pendingChoice", {})
	if not pc.is_empty():
		await _act_choice(pid, pc, moves)
		return
	if str(G.get("phase", "")) == "boss":
		await _act_boss_pick(pid, G)
		return
	_acts_turn += 1
	var actions := _build_actions(pid, moves)
	if actions.is_empty():
		return
	var a: Dictionary = _weighted(actions)
	var before := _sig()
	_cancelled = false
	_dbg = ""
	await a["run"].call()
	if bool(a.get("effect", true)) and not _cancelled:
		if _sig() == before and a["kind"] == "go":
			_dbg += " activePlayer=%s xpOrder=%s adv=%s passed=%s log=%s" % [gm.G.get("activePlayer"), gm.G.get("xpOrder"), JSON.stringify((gm.G.get("adventure", {}) as Dictionary).get("playerId")), gm.G.get("adventurePausePassed"), JSON.stringify((gm.G["log"] as Array).slice(-9))]
		if not _check(_sig() != before, "geste « %s » sans effet alors qu'il est legal (%s phase %s, pile %d, coups %s)" % [a["desc"], _dbg, G.get("phase"), (G.get("stack", []) as Array).size(), JSON.stringify(moves.map(func(m): return m["type"]))]):
			return
	_cov(str(a["kind"]))

## Carrousel du choix du boss (RandomBossSelectionScene) : le boss est tire au hasard, la rotation s'arrete dessus ; un seul humain valide par
## PLAY BOSS MONSTER!, plusieurs humains : la pose part seule apres 2 s (pas de bouton).
func _act_boss_pick(pid: int, G: Dictionary) -> void:
	var picks: Array = G["bossPicks"]
	var bc: Array = board._boss_cards
	if not _check(bc.size() == _boss_pool_size(picks.size()), "choix du boss : %d cartes a l'ecran pour %d propositions" % [bc.size(), picks.size()]):
		return
	if not board._boss_ready: # rotation en cours (animations reelles) : le bouton ne doit pas etre la, on attend l'arret
		_check(not board._confirm_btn.visible, "choix du boss : PLAY BOSS MONSTER! visible pendant la rotation")
		await _wait(0.1)
		return
	var want: String = board._boss_pick_id
	_check(picks.any(func(b): return str((b as Dictionary).get("id", "")) == want), "choix du boss : le boss tire n'est plus propose (%s)" % want)
	_check(str((bc[board._boss_sel] as CardUI).card_dict.get("id", "")) == want, "choix du boss : la rotation ne s'est pas arretee sur le boss tire (%s)" % want)
	_check_boss_layout()
	var solo := _humans() == 1
	_check(board._confirm_btn.visible == solo, "choix du boss : bouton PLAY BOSS MONSTER! %s" % ("absent en solo" if solo else "present avec plusieurs humains"))
	if solo:
		var before := _sig()
		board._confirm_btn.pressed.emit()
		_check(_sig() != before, "choix du boss : PLAY BOSS MONSTER! n'a eu aucun effet")
	else:
		var t := 0.0
		while (G["players"][pid] as Dictionary).get("boss") == null and t < 4.0: # 2 s de temps de jeu apres l'arret
			await _wait(0.1)
			t += 0.1
		_check(t >= 1.9 or board.skip_animations, "choix du boss : pose automatique avant les 2 s (%.1f)" % t)
	_cov("boss_pick")
	var boss = (G["players"][pid] as Dictionary).get("boss")
	_check(boss != null and str((boss as Dictionary).get("id", "")) == want, "choix du boss : le boss pose n'est pas le boss tire (%s)" % want)

func _humans() -> int:
	return (gm.G["players"] as Dictionary).values().filter(func(q): return not bool((q as Dictionary).get("isAI", false))).size()

## Cartes du carrousel : propositions repetees jusqu'a 8 au moins.
func _boss_pool_size(n: int) -> int:
	var total := n
	while total < 8:
		total += n
	return total

## Geometrie du carrousel : carte centrale pleine taille au centre ; les autres plus petites, de part et d'autre, la plus proche devant.
func _check_boss_layout() -> void:
	var bc: Array = board._boss_cards
	var cards := _hand_cards()
	for i in bc.size():
		var c: Control = bc[i]
		var d: int = posmod(i - board._boss_sel + bc.size() / 2, bc.size()) - bc.size() / 2 # le carrousel boucle
		var cx := c.position.x + c.size.x / 2.0
		if d == 0:
			_check(c.size.is_equal_approx(board.BOSS_CARD) and absf(cx - board.PLAY_CX) < 1.0, "carrousel : carte centrale %s en x=%.0f" % [c.size, cx])
			_check(cards.back() == c, "carrousel : la carte centrale n'est pas au premier plan")
		else:
			_check(c.size.x < board.BOSS_CARD.x * 0.7 and (cx - board.PLAY_CX) * d > 0.0, "carrousel : voisine %d mal placee (taille %s, x=%.0f)" % [d, c.size, cx])
	_cov("boss_layout")

## Eventail de la main = CardPositionComponent : x = 960 + lerp(-h, h, (i+1)/(n+1)) avec h = min((n - n%2) * 200, 1200) / 2, rotation
## 9 deg x min(n/11,2, 1) / n x (i - n/2), arc de 30 px (centres des cartes).
func _check_fan(cards: Array) -> void:
	var n := cards.size()
	var half := minf(float(n - n % 2) * 200.0, 1200.0) * 0.5
	var rot_inc := 9.0 * clampf(float(n) / 11.2, 0.0, 1.0) / float(n)
	for i in n:
		var c: Control = cards[i]
		var want_x := 960.0 + lerpf(-half, half, float(i + 1) / float(n + 1))
		var want_y := 972.0 - 30.0 * sin(PI / float(n) * (float(i) + 0.5))
		var ctr := c.position + c.size / 2.0
		_check(absf(ctr.x - want_x) < 0.5 and absf(ctr.y - want_y) < 0.5, "main : carte %d/%d centree en %s au lieu de (%.1f, %.1f)" % [i, n, ctr, want_x, want_y])
		_check(absf(c.rotation_degrees - rot_inc * (float(i) - float(n) * 0.5)) < 0.01, "main : carte %d/%d tournee de %.2f deg" % [i, n, c.rotation_degrees])
		if i > 0:
			_check((cards[i - 1] as Control).get_index() < c.get_index(), "main : ordre d'empilement des cartes")
	_cov("hand_fan")

## Pile de salles (salle avancee sur une autre) : la salle recouverte depasse de 28 px au-dessus de celle du dessus, dans MON couloir
## (DungeonSlot) comme dans celui de l'adversaire ; une pile simple n'a aucune carte dessous.
func _check_stacks() -> void:
	_tag = "[stacks]"
	await _teardown()
	CardDB._rng.seed = 77
	gm = GameManager.new()
	add_child(gm)
	gm.rng.seed = 77 # Match._ready l'a randomise : le tirage du boss doit etre reproductible
	gm.start_new_game(2, 1, ["base"])
	board = load("res://godot/scenes/Board.tscn").instantiate()
	board.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(board)
	board.skip_animations = true
	board.setup(gm, func(): quit_calls += 1)
	await _wait(0.1)
	var rooms: Array = CardDB.rooms.filter(func(r): return not bool(r.get("advanced", r.get("isAdvanced", false))))
	var adv: Array = CardDB.rooms.filter(func(r): return bool(r.get("advanced", r.get("isAdvanced", false))))
	if not _check(rooms.size() > 4 and adv.size() > 2, "piles : pas assez de salles dans CardDB"):
		return
	for pid in [0, 1]:
		var r1: Dictionary = (rooms[0] as Dictionary).duplicate(true)
		var r2: Dictionary = (adv[0] as Dictionary).duplicate(true)
		var r3: Dictionary = (adv[1] as Dictionary).duplicate(true)
		var r4: Dictionary = (rooms[1] as Dictionary).duplicate(true)
		for r in [r1, r2, r3, r4]:
			(r as Dictionary)["faceDown"] = false
		(gm.G["players"][pid] as Dictionary)["dungeon"] = [[r4], [r1, r2], [r1.duplicate(true), r2.duplicate(true), r3]]
	board.foe_pid = 1
	board.refresh()
	await get_tree().process_frame
	# Mon couloir : 3 emplacements remplis, piles de 1, 2 et 3 salles -> 0, 1 et 1 salle recouverte (l'APK n'en montre qu'une, Take(2))
	var seen := {}
	for sl in board._dungeon_slots:
		var d := sl as DungeonSlot
		var unders := d.get_children().filter(func(c): return c.is_in_group("under_card"))
		var want: int = mini(maxi(d.current_stack.size() - 1, 0), DungeonSlot.MAX_PEEK)
		_check(unders.size() == want, "pile de %d salles : %d cartes recouvertes dessinees (%d attendues)" % [d.current_stack.size(), unders.size(), want])
		for k in unders.size(): # la plus profonde d'abord, chacune 28 px plus haut que la suivante
			var depth := unders.size() - k
			var want_y: float = (d.custom_minimum_size.y - DungeonSlot.CARD_SIZE.y) / 2.0 - 28.0 * depth # DIFF_BENEATH = -28 sous la salle du dessus, centree sur l'emplacement
			_check(is_equal_approx((unders[k] as Control).position.y, want_y) and (unders[k] as Control).mouse_filter == Control.MOUSE_FILTER_IGNORE, "carte recouverte %d a y=%s (%s attendu)" % [k, (unders[k] as Control).position.y, want_y])
		if not unders.is_empty():
			_check(unders[unders.size() - 1].get_index() < d.card_container.get_index(), "la salle recouverte doit etre derriere la salle du dessus")
		seen[unders.size()] = true
	_check(seen.has(0) and seen.has(1), "piles : tailles vues %s" % str(seen.keys()))
	# Couloir adverse (Controls simples) : memes cartes recouvertes
	var foe_unders := 0
	for sc in board._foe_slots:
		foe_unders += (sc as Control).get_children().filter(func(c): return c.is_in_group("under_card")).size()
	_check(foe_unders == 2, "couloir adverse : %d cartes recouvertes (2 attendues)" % foe_unders)
	# Un rafraichissement ne duplique pas les cartes recouvertes
	board.refresh()
	await get_tree().process_frame
	var again := 0
	for sl in board._dungeon_slots:
		again += (sl as Control).get_children().filter(func(c): return c.is_in_group("under_card") and not c.is_queued_for_deletion()).size()
	_check(again == 2, "piles : %d cartes recouvertes apres un 2e rafraichissement (2 attendues)" % again)
	_cov("stacked_rooms")

func _weighted(items: Array) -> Dictionary:
	var tot := 0.0
	for it in items:
		tot += float(it["w"])
	var r := rng.randf() * tot
	for it in items:
		r -= float(it["w"])
		if r <= 0.0:
			return it
	return items[items.size() - 1]

func _style_w(kind: String) -> float:
	var w: float = float((STYLES[_style] as Dictionary).get(kind, 1.0))
	if _acts_turn > 40 and kind == "pass":
		return 100.0 # garde-fou : un tour ne dure pas indefiniment
	if _acts_turn > 40 and kind in ["spell", "ability", "extra", "build", "drop", "noise"]:
		return 0.0
	return w

## Actions UI possibles a partir des coups legaux du moteur : {kind, w, desc, run}.
func _build_actions(pid: int, moves: Array) -> Array:
	var out: Array = []
	var G: Dictionary = gm.G
	var me: Dictionary = G["players"][pid]
	var by_hand := {}   # indice de main -> coups playSpell / useHandRoom
	var by_slot := {}   # salle -> coups activateRoom
	var extras: Array = []
	var has_pass := false
	var has_go := false
	for m in moves:
		var t := str(m["type"])
		var a: Array = m.get("args", [])
		var hk: int = BoardUI.hand_idx_of(m)
		if t != "buildRoom" and hk >= 0: # sort, capacite de main, DISCARD: +1 COIN... : menu de la carte
			if not by_hand.has(hk):
				by_hand[hk] = []
			(by_hand[hk] as Array).append(m)
			continue
		match t:
			"buildRoom":
				if a.size() > 1 and a[1] != null:
					out.append({"kind": "drop", "w": _style_w("drop"), "desc": "depot salle %d sur %d" % [a[0], a[1]], "run": func(): await _do_drop(pid, int(a[0]), int(a[1]))})
				else:
					out.append({"kind": "build", "w": _style_w("build"), "desc": "construire salle %d" % int(a[0]), "run": func(): await _do_build_click(pid, int(a[0]))})
			"activateRoom":
				if not by_slot.has(int(a[0])):
					by_slot[int(a[0])] = []
				(by_slot[int(a[0])] as Array).append(m)
			"pass", "passBuild":
				has_pass = true
			"adventureNext", "resolveNextHero":
				has_go = true
			_:
				if not CORE_TYPES.has(t):
					extras.append(m)
	for idx in by_hand:
		var cands: Array = by_hand[idx]
		var hi: int = idx
		out.append({"kind": "spell", "w": _style_w("spell") * (1.0 + 0.2 * cands.size()), "desc": "carte main %d (%d coups)" % [hi, cands.size()], "run": func(): await _do_hand(pid, hi, cands)})
	for di in by_slot:
		var cands: Array = by_slot[di]
		var d: int = di
		out.append({"kind": "ability", "w": _style_w("ability"), "desc": "capacite salle %d (%d coups)" % [d, cands.size()], "run": func(): await _do_slot(pid, d, cands)})
	for k in (0 if _apk_only_sets() else extras.size()): # APK : pas de bouton EXTRA MOVES
		var ki := k
		out.append({"kind": "extra", "w": _style_w("extra"), "desc": "coup extension %s" % str(extras[k]["type"]), "run": func(): await _do_extra(ki)})
	if has_go and not board._apk_flow():
		out.append({"kind": "go", "w": _style_w("go"), "desc": "GO", "run": func(): await _do_button(board.btn_advance, "GO")})
	elif has_go:
		_cov("go_auto") # flux APK : pas de bouton GO, le heros suivant avance de lui-meme (board._process / _auto_pass)
	if has_pass and board.pass_shown():
		out.append({"kind": "pass", "w": _style_w("pass"), "desc": "PASS TURN", "effect": false, "run": func(): await _do_button(board.btn_pass, "PASS TURN")})
	elif has_pass:
		_cov("pass_auto") # bouton cache : l'UI doit passer toute seule (board._process / _auto_pass), sinon le garde-fou « bloquee » le dira
	if out.is_empty() and rng.randf() < 0.85:
		return out # rien a faire (on attend l'IA) : on ne multiplie pas les gestes parasites
	out.append({"kind": "noise", "w": _style_w("noise"), "desc": "geste parasite", "effect": false, "run": func(): await _noise(pid)})
	return out

func _do_button(btn: BaseButton, label: String) -> void:
	if _check(btn.visible and not btn.disabled and btn.is_visible_in_tree(), "bouton %s indisponible alors que le coup est legal" % label):
		_dbg = "vue=%d actif=%d animating=%s modal=%s" % [board.view_pid, gm.active_player(), board._animating_hero, board._modal_open()]
		if btn == board.btn_pass:
			_press_pass()
		else:
			btn.pressed.emit()

## PASS TURN en mode « tour de construction pas fait » : le 1er appui leve seulement le drapeau (DoneButtonEntity.cs:118-143), le 2e passe ; DONE! passe d'un appui.
func _press_pass() -> void:
	var s0 := _sig()
	board._on_pass_pressed()
	if _sig() == s0 and board._pass_turn_mode():
		board._on_pass_pressed()

func _do_build_click(pid: int, idx: int) -> void:
	var cards := _hand_cards()
	var hand: Array = gm.G["players"][pid]["hand"]
	if _check(idx < cards.size() and cards.size() == hand.size(), "construire : la main affichee (%d) != main reelle (%d)" % [cards.size(), hand.size()]):
		_check(not (cards[idx] as CardUI).greyed, "construire : la carte %d est grisee alors que le coup est legal" % idx)
		var dsize: int = (gm.G["players"][pid]["dungeon"] as Array).size()
		if not gm.can_build_room_at(pid, idx, dsize):
			# legal_moves propose buildRoom mais BossEngine.can_build_room(carte) refuse (ex. apres Kobold Strike : buildBlocked) : anomalie MOTEUR
			_engine_note("buildRoom legal mais can_build_room refuse (buildBlocked=%s)" % str((gm.G.get("effects", {}) as Dictionary).get("buildBlocked")))
			_cancelled = true
			return
		var n_menu := _n_build_targets(pid, idx) + _n_hand_uses(pid, idx) # comptes AVANT le clic : une pose directe change les coups legaux
		(cards[idx] as CardUI).card_clicked.emit(null)
		await _pick_target(n_menu, "construire (carte %d)" % idx) # plusieurs emplacements (A3) : le joueur choisit lequel

## Coups que l'interface HUMAINE offre (APK : ni sort ni capacite sans heros actif, BoardUI._my_moves) ; `gm.legal_moves` reste celui du moteur.
func _ui_moves(pid: int) -> Array:
	return board._my_moves(pid) if board != null else gm.legal_moves(pid)

## Emplacements de construction offerts par le moteur pour la carte `idx` (salles recouvrables + emplacement libre).
func _n_build_targets(pid: int, idx: int) -> int:
	return _ui_moves(pid).filter(func(m): return m["type"] == "buildRoom" and int(m["args"][0]) == idx).size()

## Autres coups de la carte `idx` (sort, capacite de main, DISCARD: +1 COIN...) : entrees de son menu, avec ou sans construction.
func _n_hand_uses(pid: int, idx: int) -> int:
	return _ui_moves(pid).filter(func(m): return m["type"] != "buildRoom" and BoardUI.hand_idx_of(m) == idx).size()

func _do_drop(pid: int, idx: int, ti: int) -> void:
	if rng.randf() < 0.4: # variante au clic : fenetre « construire par-dessus » (une entree par salle recouvrable + l'emplacement libre)
		var n_over := _n_build_targets(pid, idx) + _n_hand_uses(pid, idx)
		var cards := _hand_cards()
		if _check(idx < cards.size(), "construire par-dessus : carte %d absente" % idx):
			(cards[idx] as CardUI).card_clicked.emit(null)
			await _pick_target(n_over, "construire par-dessus (carte %d)" % idx)
			_cov("build_over_click")
		return
	var slot: DungeonSlot = null
	for sl in board._dungeon_slots:
		if (sl as DungeonSlot).slot_index == ti and not (sl as DungeonSlot).current_stack.is_empty():
			slot = sl
	if not _check(slot != null, "depot : aucun emplacement affiche pour la salle %d du donjon" % ti):
		return
	var data := {"type": "card", "hand_index": idx}
	if _check(slot._can_drop_data(Vector2.ZERO, data), "depot : la salle %d refuse la carte %d alors que le coup est legal" % [ti, idx]):
		slot._drop_data(Vector2.ZERO, data)

func _do_hand(pid: int, idx: int, cands: Array) -> void:
	var cards := _hand_cards()
	var hand: Array = gm.G["players"][pid]["hand"]
	if not _check(idx < cards.size() and cards.size() == hand.size(), "carte jouable : main affichee (%d) != main reelle (%d)" % [cards.size(), hand.size()]):
		return
	var cname := str(hand[idx].get("name"))
	_check(not (cards[idx] as CardUI).greyed, "carte jouable %s grisee" % cname)
	# une salle a capacite de main (CRL007) propose aussi BUILD en phase de construction
	var phase := str(gm.G.get("phase", ""))
	var n_build: int = _n_build_targets(pid, idx) if (phase == "build" or phase == "setup") and bool(hand[idx].get("isRoom", false)) else 0
	(cards[idx] as CardUI).card_clicked.emit(null)
	await _pick_target(cands.size() + n_build, "carte %s" % cname)

## Apres un clic qui peut ouvrir un choix de cible : plusieurs coups = les cibles s'allument sur le plateau (clic sur l'une, ou CANCEL) ;
## sans representation a l'ecran (ames, defausse...), la liste centrale (une pierre par cible + CANCEL).
func _pick_target(n_cands: int, what: String) -> void:
	for i in 3: # les zones de ciblage sont posees apres la mise en page des conteneurs
		await get_tree().process_frame
	if n_cands <= 1:
		_check(board._popup_kind != "target" and (board._tgt.is_empty() or board._tgt.has("choice")), "%s : fenetre / mode de ciblage pour un seul coup" % what)
		return
	if not board._tgt.is_empty():
		await _pick_on_board(n_cands, what)
		return
	if not _check(board._popup_kind == "target", "%s : %d cibles mais pas de choix de cible (popup=%s)" % [what, n_cands, board._popup_kind]):
		return
	if board._popup.get_node_or_null("CardsContinue") != null: # cibles qui sont des cartes : carrousel central, SKIP = CANCEL
		await _pick_in_cards(n_cands, true, false, what)
		return
	var btns := _buttons(board._popup)
	if not _check(btns.size() == n_cands + 1, "%s : %d boutons de ciblage pour %d cibles (+ CANCEL)" % [what, btns.size(), n_cands]):
		return
	_cov("target_popup")
	if rng.randf() < 0.2:
		var s0 := _sig()
		(btns[btns.size() - 1] as Button).pressed.emit() # CANCEL
		await get_tree().process_frame
		_check(board._popup_kind == "" and _sig() == s0, "%s : CANCEL doit refermer sans jouer" % what)
		_cov("target_cancel")
		_cancelled = true
		return
	(btns[rng.randi_range(0, n_cands - 1)] as Button).pressed.emit()
	await get_tree().process_frame
	_check(board._popup_kind != "target", "%s : la fenetre de ciblage ne se ferme pas apres le choix" % what)

## Carrousel central de cartes (popup « CardsContinue ») : une carte par option, le bouton n'est la qu'avec une carte choisie ou un SKIP possible.
## skip_plays : SKIP joue un coup (choix en attente) ; sinon c'est un CANCEL qui referme sans rien jouer.
func _pick_in_cards(n_pick: int, has_skip: bool, skip_plays: bool, what: String) -> void:
	var pop: Control = board._popup
	var btn: Button = pop.get_node_or_null("CardsContinue")
	var cards := pop.get_children().filter(func(c): return c is CardUI)
	if not (_check(btn != null and cards.size() == n_pick, "%s : %d cartes au carrousel pour %d options" % [what, cards.size(), n_pick]) \
			and _check(btn.visible == has_skip and btn.text == "SKIP", "%s : bouton SKIP %s alors que SKIP %s" % [what, btn.visible, has_skip])):
		return
	_cov("cards_popup")
	var s0 := _sig()
	if has_skip and rng.randf() < 0.2:
		btn.pressed.emit()
		await get_tree().process_frame
		if skip_plays:
			_check(_sig() != s0, "%s : SKIP sans effet" % what)
			_cov("cards_skip")
		else:
			_check(board._popup_kind == "" and _sig() == s0, "%s : CANCEL doit refermer sans jouer" % what)
			_cancelled = true
		return
	var k := rng.randi_range(0, cards.size() - 1)
	(cards[k] as CardUI).card_clicked.emit(null)
	if _check(btn.visible and btn.text == "CONTINUE" and (cards[k] as CardUI).glow_rect.visible, "%s : carte choisie sans CONTINUE ni halo dore" % what):
		(cards[k] as CardUI).card_clicked.emit(null) # re-appui = deselection
		_check(btn.visible == has_skip and not (cards[k] as CardUI).glow_rect.visible, "%s : la deselection ne remet pas l'etat initial" % what)
		(cards[k] as CardUI).card_clicked.emit(null)
		var pc0: Dictionary = (gm.G.get("pendingChoice", {}) as Dictionary).duplicate(true)
		btn.pressed.emit()
		await get_tree().process_frame
		# un choix en plusieurs etapes (tnl-pick : cout puis cible) laisse un nouveau popup de choix, different du precedent
		var chained: bool = skip_plays and not (gm.G.get("pendingChoice", {}) as Dictionary).is_empty() and gm.G["pendingChoice"] != pc0
		_check((board._popup_kind == "" or chained) and _sig() != s0, "%s : CONTINUE n'a pas joue la carte choisie" % what)

## Vrai clic gauche a la position (coordonnees du plateau 1920x1080) via le viewport : passe par le voile, les zones et les boutons.
func _click_at(pos: Vector2) -> void:
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.position = pos
		ev.global_position = pos
		ev.pressed = pressed
		get_viewport().push_input(ev, true)
		await get_tree().process_frame

## Mode ciblage sur le plateau : chaque coup legal correspond a une zone allumee ; le voile bloque le reste ; on clique une zone au hasard.
func _pick_on_board(n_cands: int, what: String, mandatory := false) -> void: # mandatory : choix en attente sans SKIP, pas de CANCEL
	_cov("target_board")
	var spots: Array = board._tgt_spots
	if spots.is_empty(): # cibles chez un adversaire non affiche (3-4 joueurs) : son bouton P<n> est dore, on le choisit
		var gold := _foe_buttons().filter(func(b): return (b as Button).has_theme_color_override("font_color"))
		if _check(not gold.is_empty(), "%s : aucune cible a l'ecran et aucun adversaire dore" % what):
			(gold[0] as Button).pressed.emit()
			for i in 3:
				await get_tree().process_frame
			spots = board._tgt_spots
			_cov("target_foe_switch")
	var total := 0
	for sp in spots:
		total += (sp["ids"] as Array).size()
		var r: Rect2 = (sp["ctrl"] as Control).get_global_rect()
		_check(r.size.x > 20.0 and r.size.y > 20.0 and Rect2(-20, -20, 1960, 1120).encloses(r), "%s : zone de ciblage hors ecran %s" % [what, r])
	_check(not spots.is_empty() and total <= n_cands, "%s : %d cibles allumees pour %d coups" % [what, total, n_cands])
	if spots.is_empty():
		board._target_cancel()
		_cancelled = true
		return
	_check(board._tgt_cancel_btn != null and board._tgt_cancel_btn.is_visible_in_tree() != mandatory and not board.action_box.visible, "%s : CANCEL absent/present a tort ou PASS TURN encore visible en ciblage" % what)
	var s0 := _sig()
	var hand := _hand_cards()
	if not hand.is_empty() and not cov.has("target_blocked"): # le voile bloque la main : un clic sur une carte ne joue rien et ne ferme pas le mode
		await _click_at((hand[hand.size() / 2] as Control).get_global_rect().get_center())
		_check(not board._tgt.is_empty() and _sig() == s0 and board._popup_kind == "", "%s : un clic sur la main pendant le ciblage a eu un effet" % what)
		_cov("target_blocked")
	if rng.randf() < 0.2 and not board._tgt.has("choice"): # un choix en attente a son propre test CANCEL (_act_choice)
		board._tgt_cancel_btn.pressed.emit()
		await get_tree().process_frame
		_check(board._tgt.is_empty() and _sig() == s0 and board._popup_kind == "", "%s : CANCEL doit refermer sans jouer" % what)
		_cov("target_board_cancel")
		_cancelled = true
		return
	var pick: Dictionary = spots[rng.randi_range(0, spots.size() - 1)]
	await _click_at((pick["ctrl"] as Control).get_global_rect().get_center())
	if not board._tgt.is_empty() and board._popup_kind == "target": # une zone, plusieurs coups (mode, paiement...) : petite liste de ces coups
		var btns := _buttons(board._popup)
		if _check(btns.size() == (pick["ids"] as Array).size() + 1, "%s : zone a %d coups mais %d boutons" % [what, (pick["ids"] as Array).size(), btns.size()]):
			_cov("target_spot_multi")
			(btns[rng.randi_range(0, btns.size() - 2)] as Button).pressed.emit()
			await get_tree().process_frame
	_check((board._tgt.is_empty() or board._tgt.has("choice")) and board._popup_kind != "target", "%s : le clic sur une cible allumee n'a pas joue le coup" % what) # le coup peut ouvrir un choix sur le plateau
	_check(_sig() != s0, "%s : cible choisie sur le plateau sans effet" % what)

func _do_slot(pid: int, di: int, cands: Array) -> void:
	var slot: DungeonSlot = null
	for sl in board._dungeon_slots:
		if (sl as DungeonSlot).slot_index == di and not (sl as DungeonSlot).current_stack.is_empty():
			slot = sl
	if not _check(slot != null, "capacite : aucun emplacement pour la salle %d" % di):
		return
	if not _check(slot.activatable, "capacite : la salle %d n'a pas de halo alors qu'elle est activable" % di):
		return
	_dbg = "salle %s" % str(BossEngine.active_room(slot.current_stack).get("id"))
	var s0 := _sig()
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT if rng.randf() < 0.7 else MOUSE_BUTTON_RIGHT
	ev.pressed = true
	slot._gui_input(ev)
	# APK : 1er appui = zoom de la pile, 2e appui sur la bordure de capacite = resolution (GamePlayBaseScene.cs:681-718)
	await get_tree().process_frame
	if not _check(board._zoom != null and is_instance_valid(board._zoom) and board._zoom.has_meta("ability"), "capacite salle %d : pas de zoom au 1er appui" % di):
		return
	_check(_sig() == s0, "capacite salle %d : jouee des le 1er appui" % di)
	var ab: Rect2 = board._zoom.get_meta("ability")["rect"]
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = (board._zoom.get_meta("ability")["host"] as Control).get_global_transform() * ab.get_center() # la carte du dessus (pile : enfant du zoom)
	board._input(click)
	_check(board._zoom == null, "capacite salle %d : le zoom reste apres le tap sur la bordure" % di)
	await _pick_target(cands.size(), "capacite salle %d" % di)

func _apk_only_sets() -> bool:
	var G: Dictionary = board.game_manager.G
	var a: bool = G.has("sets") # meme regle que BoardUI._refresh_extra_bar
	for st in G.get("sets", []):
		a = a and st in Match.APK_SETS
	return a

func _do_extra(k: int) -> void:
	var open: Array = board.extra_bar.get_children().filter(func(c): return not c.is_queued_for_deletion())
	if not _check(open.size() == 1 and board.extra_bar.visible, "coup d'extension %d : %d boutons EXTRA MOVES (1 attendu)" % [k, open.size()]):
		return
	(open[0] as Button).pressed.emit() # un seul bouton ; chaque coup est une ligne de sa liste
	await get_tree().process_frame
	if not _check(board._popup_kind == "target", "coup d'extension %d : liste EXTRA MOVES absente" % k):
		return
	var btns := _buttons(board._popup)
	if _check(k < btns.size() - 1, "coup d'extension %d : %d lignes seulement" % [k, btns.size() - 1]):
		(btns[k] as Button).pressed.emit()
		_cov("extra_moves_menu")

func _act_choice(pid: int, pc: Dictionary, moves: Array) -> void:
	var typ := str(pc.get("type", ""))
	if typ == "opening-discard":
		await _act_discard(pid)
		return
	var cm := moves.filter(func(m): return str(m["type"]) in ["resolveChoice", "resolveLevelUpChoice"])
	if not _check(not cm.is_empty(), "choix en attente (%s) sans coup legal pour le siege %d" % [typ, pid]):
		return
	if rng.randf() < 0.08: # le menu engrenage ouvert devant un choix le masque, la fermeture le ramene
		board._on_menu_pressed()
		await get_tree().process_frame
		_check(board._popup_kind == "menu", "menu non ouvert devant un choix en attente")
		board._process(1.0)
		_check(gm.G.get("pendingChoice", {}) == pc, "partie non mise en pause par le menu")
		board._on_menu_pressed()
		await get_tree().process_frame
		_cov("menu_over_choice")
	if not board._tgt.is_empty(): # options = zones du plateau (salles, heros) : bordures dorees, SKIP = CANCEL
		var n_pick := cm.filter(func(m): return int((m["args"] as Array)[0]) >= 0).size()
		var has_skip := n_pick < cm.size()
		_check(board._tgt.has("choice") and board._tgt_cancel_btn.visible == has_skip, "choix « %s » sur le plateau : CANCEL %s alors que SKIP %s" % [typ, board._tgt_cancel_btn.visible, has_skip])
		var b0 := _sig()
		if has_skip and rng.randf() < 0.2:
			board._tgt_cancel_btn.pressed.emit() # CANCEL = SKIP
			await get_tree().process_frame
			_check(board._tgt.is_empty() and _sig() != b0, "choix « %s » : CANCEL (SKIP) sans effet" % typ)
			_cov("choice_board_skip")
		else:
			await _pick_on_board(n_pick, "choix « %s »" % typ, not has_skip)
		_cov("choice_board:" + typ)
		return
	if not _check(board._popup_kind == "choice", "choix en attente « %s » (%s) : pas de popup (popup=%s)" % [typ, str(pc.get("message", "")).left(50), board._popup_kind]):
		return
	if board._popup.get_node_or_null("CardsContinue") != null: # options = cartes : carrousel central (APK CardSelector), SKIP = canBeCanceled
		var n_cards := cm.filter(func(m): return int((m["args"] as Array)[0]) >= 0).size()
		await _pick_in_cards(n_cards, n_cards < cm.size(), true, "choix « %s »" % typ)
		_cov("choice_cards:" + typ)
		return
	var btns := _buttons(board._popup)
	if not _check(btns.size() == cm.size(), "choix « %s » : %d boutons pour %d options" % [typ, btns.size(), cm.size()]):
		return
	var before := _sig()
	(btns[rng.randi_range(0, btns.size() - 1)] as Button).pressed.emit()
	_cov("choice:" + typ)
	await get_tree().process_frame
	_check(_sig() != before, "choix « %s » : le bouton n'a eu aucun effet" % typ)

func _act_discard(pid: int) -> void:
	var hand: Array = gm.G["players"][pid]["hand"]
	var cards := _hand_cards()
	if not _check(cards.size() == hand.size() and hand.size() >= 2, "defausse d'ouverture : %d cartes a l'ecran pour une main de %d" % [cards.size(), hand.size()]):
		return
	_check(hand.size() == 7, "defausse d'ouverture : 5 salles + 2 sorts = 7 cartes dans tous les modes (%d)" % hand.size()) # TNL / RMB inclus : plus de grosse main sans choix
	var i0 := rng.randi_range(0, hand.size() - 1)
	board._on_hand_card_clicked(i0, hand[i0])
	board._on_hand_card_clicked(i0, hand[i0]) # re-clic = deselection
	_check(board.discard_pick.is_empty(), "defausse : un 2e clic doit deselectionner")
	var order: Array = range(hand.size())
	for i in range(order.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = order[i]
		order[i] = order[j]
		order[j] = t
	board._on_hand_card_clicked(int(order[0]), hand[int(order[0])])
	await get_tree().process_frame
	_check(not board._confirm_btn.visible, "defausse : CONTINUE visible avec une seule carte choisie")
	board._on_hand_card_clicked(int(order[1]), hand[int(order[1])])
	await get_tree().process_frame
	_check(board._confirm_btn.visible and board._confirm_btn.is_visible_in_tree(), "defausse : CONTINUE absent avec 2 cartes choisies")
	_check(board._confirm_btn.size == Vector2(131, 173) and board._confirm_btn.position == Vector2(1540, 410), "defausse : CONTINUE n'est pas le losange de l'APK (%s a %s)" % [board._confirm_btn.size, board._confirm_btn.position])
	_check(board._dim.visible and board._dim.size == Vector2(1523, 400) and not board.phase_banner.visible, "defausse : seul le bandeau des cartes s'assombrit, sans plaque de phase")
	board._on_hand_card_clicked(int(order[2]), hand[int(order[2])]) # une 3e remplace la plus ancienne (CardSelectorComponent.cs:128-134)
	_check(board.discard_pick == [int(order[1]), int(order[2])], "defausse : la 3e carte doit remplacer la plus ancienne (%s)" % str(board.discard_pick))
	_check(_emitting(board._fx_hand).size() == 2, "defausse : une carte choisie doit emettre (YellowGlow, CardBorderBehavior.cs:48-50), %d emetteur(s) actifs pour 2 cartes" % _emitting(board._fx_hand).size())
	var n_before := hand.size()
	board._confirm_btn.pressed.emit()
	await get_tree().process_frame
	_check((gm.G["players"][pid]["hand"] as Array).size() == n_before - 2 or not (gm.G.get("pendingChoice", {}) as Dictionary).is_empty(), "defausse : la main n'a pas perdu 2 cartes")
	_check(board.discard_pick.is_empty(), "defausse : selection non remise a zero")
	_check(_emitting(board._fx_hand).is_empty(), "defausse : plus de carte choisie, plus d'emission")
	_cov("opening_discard")

## Gestes parasites : ne doivent rien casser ni changer l'etat de la partie.
func _noise(pid: int) -> void:
	var G: Dictionary = gm.G
	var s0 := _sig()
	match rng.randi_range(0, 6):
		0: # clic sur une carte de la main sans coup legal
			var hand: Array = G["players"][pid]["hand"]
			var playable := {}
			for m in _ui_moves(pid):
				if BoardUI.hand_idx_of(m) >= 0:
					playable[BoardUI.hand_idx_of(m)] = true
			var can_undo: bool = _ui_moves(pid).any(func(m): return str((m as Dictionary).get("type", "")) == "undoBuild")
			for i in hand.size():
				if can_undo and bool((hand[i] as Dictionary).get("isRoom", false)): # pose en attente : toute salle de la main la remplace (undoBuild + buildRoom)
					continue
				if not playable.has(i):
					board._on_hand_card_clicked(i, hand[i])
					_cov("noise_dead_card")
					break
			await get_tree().process_frame
			_check(_sig() == s0 and board._popup_kind == "", "clic sur une carte injouable : l'etat a change ou un popup s'est ouvert")
		1: # clic sur la salle non activable / un emplacement vide
			var ev := InputEventMouseButton.new()
			ev.button_index = MOUSE_BUTTON_LEFT
			ev.pressed = true
			for sl in board._dungeon_slots:
				if not (sl as DungeonSlot).activatable and not (sl as DungeonSlot).undoable: # (une pose en attente se reprend d'un clic : undoBuild)
					(sl as DungeonSlot)._gui_input(ev)
			await get_tree().process_frame
			_check(_sig() == s0 and board._popup_kind == "", "clic sur des salles non activables : effet inattendu")
			_cov("noise_dead_slot")
		2: # bouton LEVEL UP (cosmetique : le niveau est automatique)
			board.levelup_btn.pressed.emit()
			await get_tree().process_frame
			_check(_sig() == s0, "bouton LEVEL UP : l'etat a change")
			var click := InputEventMouseButton.new() # le zoom du boss part au clic suivant (sinon la barre de temps reste en pause)
			click.button_index = MOUSE_BUTTON_LEFT
			click.pressed = true
			board._input(click)
			_check(board._zoom == null, "bouton LEVEL UP : le zoom reste apres un clic")
			_cov("levelup_click")
		3: # pile de defausse : diaporama central (rien de modal), le second appui le referme
			var decks: Dictionary = board.game_manager.G["decks"]
			(decks["roomDiscard"] as Array).append(CardDB.rooms[0].duplicate(true))
			(decks["spellDiscard"] as Array).append(CardDB.spells[0].duplicate(true))
			var n0: int = (decks["roomDiscard"] as Array).size() + (decks["spellDiscard"] as Array).size() - 2
			var s1 := _sig()
			board._on_discard_pile_pressed()
			await get_tree().process_frame
			if _check(board._slide != null and is_instance_valid(board._slide), "pile de defausse : diaporama absent"):
				_check(board._slide_cards.size() == n0 + 2, "pile de defausse : %d cartes au lieu de %d" % [board._slide_cards.size(), n0 + 2])
				board._on_discard_pile_pressed()
				await get_tree().process_frame
				_check(board._slide == null, "pile de defausse : le second appui ne referme pas")
			_check(board.get_children().filter(func(c): return c is AcceptDialog).is_empty(), "pile de defausse : fenetre residuelle")
			_check(_sig() == s1, "pile de defausse : l'etat a change")
			_cov("discard_pile")
		4: # menu engrenage : ouvre, la partie est en pause, referme
			board._on_menu_pressed()
			await get_tree().process_frame
			if _check(board._popup_kind == "menu", "engrenage : menu non ouvert"):
				if not cov.has("pause_menu") or rng.randf() < 0.1:
					_check_pause_menu()
				board._process(1.0)
				_check(_sig() == s0, "engrenage : la partie avance malgre le menu ouvert")
				board._on_menu_pressed()
				await get_tree().process_frame
				_check(board._popup_kind == "" or board._popup_kind == "choice", "engrenage : menu non referme (%s)" % board._popup_kind)
			_cov("menu_toggle")
		5: # regles superposees
			board._on_menu_pressed()
			board._open_rules()
			await get_tree().process_frame
			if _check(board._rules != null and is_instance_valid(board._rules), "regles : non ouvertes"):
				board._process(1.0)
				_check(_sig() == s0, "regles : la partie avance derriere la fenetre")
				board._rules.close_viewer()
				await get_tree().process_frame
				_check(board._rules == null, "regles : reference non liberee")
			board._popup_close()
			board.refresh()
			_cov("rules_toggle")
		6: # selecteur d'adversaire (3-4 joueurs)
			var bs := _foe_buttons()
			if not bs.is_empty():
				(bs[rng.randi_range(0, bs.size() - 1)] as Button).pressed.emit()
				await get_tree().process_frame
				_cov("foe_switch")
	if board._popup_kind == "menu":
		board._popup_close()
		board.refresh()

## Menu en jeu de l'APK : PAUSED = RESUME / CARD GALLERY / RULES / SETTINGS / QUIT GAME ; SETTINGS = MUSIC / SOUND / GAME SPEED + MASTER VOLUME
## (le curseur agit sur AudioManager ; valeurs d'origine rendues ensuite, rien n'est ecrit sur disque). Appelee avec le menu ouvert.
func _check_pause_menu() -> void:
	var texts: Array = _buttons(board._popup).map(func(b): return (b as Button).text)
	_check(texts == ["RESUME", "CARD GALLERY", "RULES", "SETTINGS", "QUIT GAME"], "menu en jeu : boutons %s" % str(texts))
	var title = board._popup.find_child("Title", true, false)
	_check(title != null and (title as Label).text == "PAUSED", "menu en jeu : titre PAUSED absent")
	var settings: Button = null
	for b in _buttons(board._popup):
		if (b as Button).text == "SETTINGS":
			settings = b
	if not _check(settings != null, "menu en jeu : SETTINGS absent"):
		return
	settings.pressed.emit()
	var sl: Array = []
	var stack: Array = [board._popup]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is HSlider:
			sl.append(n)
		stack.append_array(n.get_children())
	if _check(sl.size() == 1, "reglages : %d curseurs de volume (1 attendu)" % sl.size()):
		var orig: float = AudioManager.master_volume
		(sl[0] as HSlider).value = 0.37
		_check(absf(AudioManager.master_volume - 0.37) < 0.001, "reglages : le curseur ne regle pas le volume maitre (%s)" % AudioManager.master_volume)
		(sl[0] as HSlider).value = 0.0
		_check(AudioServer.is_bus_mute(0), "reglages : volume 0 = bus Master non coupe")
		AudioManager.master_volume = orig
		AudioManager._apply()
	# bascules MUSIC / SOUND / GAME SPEED : 2 + 2 + 3 segments ; GAME SPEED agit sur la vitesse des animations
	var segs: Array = board._popup.find_children("Seg*", "Button", true, false)
	_check(segs.size() == 7, "reglages : %d segments de bascule (7 attendus)" % segs.size())
	var speed0: int = Profile.load_speed()
	if segs.size() == 7:
		(segs[4] as Button).pressed.emit() # SLOW
		_check(Profile.load_speed() == 0 and is_equal_approx(board._speed, 1.5), "reglages : GAME SPEED SLOW non pris en compte (%s)" % board._speed)
		(segs[6] as Button).pressed.emit() # FAST
		_check(Profile.load_speed() == 2 and is_equal_approx(board._speed, 0.5), "reglages : GAME SPEED FAST non pris en compte")
		Profile.save_speed(speed0)
		board._speed = board._speed_factor()
	var back = board._popup.find_child("Back", true, false)
	if _check(back != null, "reglages : fleche de retour absente"):
		(back as TextureButton).pressed.emit()
		var texts2: Array = _buttons(board._popup).map(func(b): return (b as Button).text)
		_check(texts2.has("RESUME"), "reglages : la fleche ne ramene pas au menu PAUSED")
	_cov("pause_menu")

# ---------------------------------------------------------------------------------------------------------------------
# Coherence ecran / etat
# ---------------------------------------------------------------------------------------------------------------------

func _check_ui() -> void:
	var G: Dictionary = gm.G
	if board._animating_hero or board._modal_open() or not (G.get("players", {}) as Dictionary).has(board.view_pid):
		return
	var over: bool = G.get("gameOver") != null
	var pid: int = board.view_pid
	var p: Dictionary = G["players"][pid]
	var phase := str(G.get("phase", ""))
	var pc: Dictionary = G.get("pendingChoice", {})
	if not over:
		_check(board._last_phase == phase, "ecran fige : bandeau %s != phase %s (tour %s)" % [board._last_phase, phase, G.get("turn")])
	# main / propositions de boss
	var want_cards: int = (p["hand"] as Array).size() # APK : la main reste dessinee sous le voile de l'ecran de fin
	if not over and phase == "boss" and p.get("boss") == null:
		want_cards = _boss_pool_size((G["bossPicks"] as Array).size())
	var got_cards := _hand_cards().size()
	_check(got_cards == want_cards, "main : %d cartes a l'ecran pour %d (phase %s, siege %d)" % [got_cards, want_cards, phase, pid])
	# barres du haut (5-6 joueurs) : un bouton par adversaire, tous entre la barre de sieges et l'engrenage
	if board.foe_bar.visible:
		var foes := _buttons(board.foe_bar)
		_check(foes.size() == (G["players"] as Dictionary).size() - 1, "selecteur d'adversaire : %d boutons pour %d joueurs" % [foes.size(), (G["players"] as Dictionary).size()])
		var left_edge := 1e9
		for b in foes:
			left_edge = minf(left_edge, (b as Button).get_global_rect().position.x)
			_check((b as Button).get_global_rect().end.x <= board.top_menu_btn.position.x, "selecteur d'adversaire : %s deborde sur l'engrenage" % (b as Button).text)
		for b in _buttons(board.seat_bar):
			if board.seat_bar.visible:
				_check((b as Button).get_global_rect().end.x <= left_edge, "barres du haut : %s chevauche le selecteur d'adversaire" % (b as Button).text)
	# pioches, ville
	var decks: Dictionary = G["decks"]
	var foe_hand: Array = ((G["players"] as Dictionary).get(board.foe_pid, {}) as Dictionary).get("hand", []) # OneOpponentDetail.cs:212 : cartes en main de l'adversaire
	var foe_rooms: int = foe_hand.filter(func(c): return bool((c as Dictionary).get("isRoom", false))).size()
	_check(board.room_deck_label.text == "x%d" % foe_rooms, "salles en main adverses : %s != x%d" % [board.room_deck_label.text, foe_rooms])
	_check(board.spell_deck_label.text == "x%d" % (foe_hand.size() - foe_rooms), "sorts en main adverses : %s != x%d" % [board.spell_deck_label.text, foe_hand.size() - foe_rooms])
	var dead := {"phase": "build", "players": {0: {"eliminated": true, "isAI": false}, 1: {"eliminated": false, "isAI": true}}} # GamePlayBaseScene.cs:1071-1078
	_check(board._all_humans_dead(dead) and not board._all_humans_dead({"phase": "adventure", "players": dead["players"]}), "defaite des humains en fin de tour : _all_humans_dead")
	_check(not board._all_humans_dead({"phase": "build", "players": {0: {"eliminated": false, "isAI": false}}}), "un humain vivant : pas de defaite")
	var town_n: int = board.town_container.get_children().filter(func(c): return not c.is_queued_for_deletion()).size()
	_check(town_n == (G["town"] as Array).size(), "heros en ville : %d affiches pour %d" % [town_n, (G["town"] as Array).size()])
	# ames / blessures
	var souls: int = board.souls_container.get_children().filter(func(c): return (c as TextureRect).texture == board._tex(board.TEX_SOUL)).size()
	var wounds: int = board.wounds_container.get_children().filter(func(c): return (c as TextureRect).texture == board._tex(board.TEX_WOUND)).size()
	_check(souls == mini(10, CardDB.total_souls(p, G)), "ames : %d icones pour %d" % [souls, CardDB.total_souls(p, G)])
	_check(wounds == mini(5, CardDB.total_wounds(p)), "blessures : %d icones pour %d" % [wounds, CardDB.total_wounds(p)]) # la rangee s'arrete a 5 (un heros epique peut en infliger 2)
	# badges de couloir + bouton LEVEL UP
	var foe_dict: Dictionary = {}
	var foe_pid: int = board.foe_pid
	if (G["players"] as Dictionary).has(foe_pid):
		foe_dict = G["players"][foe_pid]
	_check_lane(1, p, "mon couloir")
	if not foe_dict.is_empty():
		_check(foe_pid != pid, "adversaire affiche = mon propre siege (%d)" % pid)
		if not (phase == "boss" and p.get("boss") == null):
			_check_lane(0, foe_dict, "couloir adverse (siege %d)" % foe_pid)
	var can_lvl: bool = BossEngine.count_visible_rooms(p.get("dungeon", [])) >= 5
	_check((board.levelup_btn.modulate.r > 1.0) == can_lvl, "bouton LEVEL UP : %s avec %d salles visibles" % ["allume" if board.levelup_btn.modulate.r > 1.0 else "eteint", BossEngine.count_visible_rooms(p.get("dungeon", []))])
	# donjons : mon couloir (emplacements) et celui de l'adversaire affiche
	var dungeon: Array = p["dungeon"]
	var off: int = maxi(0, CardDB.DUNGEON_SLOTS - dungeon.size())
	for j in board._dungeon_slots.size():
		var sl: DungeonSlot = board._dungeon_slots[j]
		var di: int = j - off
		var want: String = _stack_sig(dungeon[di]) if di >= 0 and di < dungeon.size() else ""
		_check(_stack_sig(sl.current_stack) == want, "emplacement %d de mon donjon : %s != %s" % [j, _stack_sig(sl.current_stack), want])
		_check(sl.player_id == pid, "emplacement %d : player_id %d != siege affiche %d" % [j, sl.player_id, pid])
	if not foe_dict.is_empty():
		var fd: Array = foe_dict["dungeon"]
		var shown := 0
		for s in board._foe_slots:
			shown += (s as Control).get_children().filter(func(c): return c is CardUI and not c.is_in_group("under_card") and not c.is_queued_for_deletion()).size()
		_check(shown == fd.size(), "donjon adverse (siege %d) : %d salles affichees pour %d" % [foe_pid, shown, fd.size()])
	# boutons
	var my_moves: Array = _ui_moves(pid)
	var can_go := false
	var can_pass := false
	var extras := 0
	for m in my_moves:
		var t := str(m["type"])
		can_go = can_go or t in ["adventureNext", "resolveNextHero"]
		can_pass = can_pass or t in ["pass", "passBuild"]
		if not CORE_TYPES.has(t) and BoardUI.hand_idx_of(m) < 0:
			extras += 1
	var carousel: bool = (phase == "boss" or board._is_opening_discard_for_me()) and not over
	var go_usable: bool = board.btn_advance.is_visible_in_tree() and not board.btn_advance.disabled
	_check(go_usable == (can_go and not carousel and not board._apk_flow()), "bouton GO : %s alors que le coup est %s" % ["utilisable" if go_usable else "inutilisable", "legal" if can_go else "illegal"])
	if board._apk_flow() and phase == "adventure":
		_check(not board.pass_shown(), "aventure : PASS TURN visible (l'APK n'en a pas, voir la barre de temps)")
	var pass_vis: bool = board.pass_shown()
	if pass_vis:
		_check(can_pass and not over, "bouton PASS TURN visible alors que passer est illegal (phase %s, fin=%s, siege %d)" % [phase, over, pid])
	var extra_vis: bool = board.extra_bar.visible and board.extra_bar.get_children().filter(func(c): return not c.is_queued_for_deletion()).size() > 0
	_check(extra_vis == (extras > 0 and pc.is_empty() and not _apk_only_sets()), "barre d'extensions : %s pour %d coups d'extension" % ["visible" if extra_vis else "cachee", extras])
	_check(board.extra_bar.get_children().filter(func(c): return not c.is_queued_for_deletion()).size() <= 1, "barre d'extensions : plusieurs boutons (une grille couvre le donjon)")
	_check_no_slot_cover()
	# popup de choix <-> choix en attente
	var mine: bool = not pc.is_empty() and int(pc.get("playerId", -1)) == pid and str(pc.get("type", "")) != "opening-discard" and not my_moves.is_empty()
	if board._popup_kind == "choice":
		_check(mine, "popup de choix affiche sans choix en attente pour le siege %d" % pid)
	elif board._popup_kind == "":
		_check(not mine or board._tgt.has("choice"), "choix en attente (%s) sans popup" % str(pc.get("type", "")))
	elif board._popup_kind == "target":
		_check(false, "fenetre de ciblage restee ouverte")
	_check(board._tgt.is_empty() or (mine and board._tgt.has("choice")), "mode de ciblage reste ouvert apres le geste") # sauf le choix en attente designe sur le plateau
	if phase == "boss" and not over and p.get("boss") == null:
		_check(board.foe_name_label.text == "" and board._lane[0]["sprite"].texture == board._tex(board.TEX_UNKNOWN_BOSS), "choix du boss : le boss adverse n'est pas cache")
		_check(board._confirm_btn.visible == (board._boss_ready and _humans() == 1), "choix du boss : bouton PLAY BOSS MONSTER! mal affiche (pret %s)" % board._boss_ready)
	# aventure : le donjon traverse est a l'ecran (le mien ou l'adversaire affiche) quand les pions sont animes
	var adv: Dictionary = G.get("adventure", {})
	if not board.skip_animations and not adv.is_empty() and adv.get("hero") != null:
		var ap := int(adv.get("playerId", -1))
		_check(ap == pid or ap == foe_pid, "aventure dans le donjon du siege %d mais l'adversaire affiche est %d" % [ap, foe_pid])
	if bool(p.get("leveledUp", false)):
		_cov("level_up_seen")
	# ecran de fin
	if over:
		_check(not board.action_box.visible, "fin de partie : boutons de jeu encore visibles")

func _stack_sig(stack: Array) -> String:
	var s := ""
	for r in stack:
		s += "%s%s," % [str((r as Dictionary).get("id", "")), "v" if bool((r as Dictionary).get("faceDown", false)) else "^"]
	return s

func _check_lane(idx: int, pl: Dictionary, what: String) -> void:
	var L: Dictionary = board._lane[idx]
	var boss = pl.get("boss")
	var dmg: int = board._get_total_dungeon_damage(pl)
	_check((L["dmg"] as Label).text == str(dmg), "%s : DAMAGE %s != %d" % [what, (L["dmg"] as Label).text, dmg])
	_check((L["lvl"] as Label).text == str(board._player_order(int(pl.get("id", 0)))), "%s : ordre de jeu %s (BossXPAndOrderControl.cs:109)" % [what, (L["lvl"] as Label).text])
	if boss != null:
		_check((L["xp"] as Label).text == "%dXP" % int((boss as Dictionary).get("xp", 0)), "%s : XP %s != %s" % [what, (L["xp"] as Label).text, (boss as Dictionary).get("xp")])

## Fin de partie : ecran « WINS », retour au menu par le menu engrenage (YES), plus aucun geste possible.
func _check_final(full: bool) -> void:
	var G: Dictionary = gm.G
	await get_tree().process_frame
	if G.get("gameOver") != null:
		var t_wait := Time.get_ticks_msec() + 20000
		while board._gameover == null and Time.get_ticks_msec() < t_wait: # la derniere traversee de heros se joue d'abord
			await get_tree().process_frame
		_check_ui()
		var gb = board._gameover
		if _check(gb != null and is_instance_valid(gb), "fin de partie : bandeau du vainqueur absent"):
			_check(_hand_cards().size() == (G["players"][board._my_pid()]["hand"] as Array).size(), "fin de partie : la main doit rester a l'ecran sous le voile (APK)")
			var w := int(G["gameOver"].get("winner", -1))
			var wboss = G["players"][w].get("boss") if G["players"].has(w) else null
			var lose: bool = board._apk_flow() and w != 0
			if gb.title_label != null and wboss != null and not lose:
				_check(gb.title_label.text == str((wboss as Dictionary).get("name", "")), "fin de partie : nom du vainqueur « %s » au lieu de %s" % [gb.title_label.text, (wboss as Dictionary).get("name", "")])
			elif lose:
				_check(gb.title_label.text.contains("YOU LOSE"), "fin de partie : « YOU LOSE » absent (%s)" % gb.title_label.text)
			_check(gb.get_node_or_null("WinnerText") != null or lose, "fin de partie : « IS THE WINNER! » absent")
			_check(gb.ok_btn != null and gb.ok_btn.is_visible_in_tree(), "fin de partie : bouton OK absent")
			_check(not board._confirm_btn.visible and not board._bubble.visible, "fin de partie : ancien bandeau / bouton MENU encore la")
			for pid in G["players"]:
				_check(gm.legal_moves(int(pid)).is_empty(), "fin de partie : le siege %d a encore des coups legaux" % pid)
			_cov("game_over_screen")
			# OK -> retour a l'ecran titre (callback de sortie)
			var qm := quit_calls
			if gb.ok_btn != null:
				gb.ok_btn.pressed.emit()
				_check(quit_calls == qm + 1, "fin de partie : OK ne ramene pas a l'ecran titre")
				_cov("game_over_ok")
	if full or G.get("gameOver") != null:
		# retour au menu : engrenage -> QUIT GAME -> YES
		var q0 := quit_calls
		board._on_menu_pressed()
		await get_tree().process_frame
		var quit_btn: Button = null
		for b in _buttons(board._popup):
			if (b as Button).text == "QUIT GAME":
				quit_btn = b
		if _check(quit_btn != null, "fin de partie : menu sans QUIT GAME"):
			quit_btn.pressed.emit()
			await get_tree().process_frame
			var yes: Array = board._popup.find_children("*", "TextureButton", true, false).slice(0, 2) # QUIT GAME? : [CANCEL, QUIT]
			yes.reverse()
			if _check(board._popup_kind == "quit" and yes.size() == 2, "fin de partie : confirmation de sortie absente"):
				(yes[0] as BaseButton).pressed.emit()
				_check(quit_calls == q0 + 1, "fin de partie : retour au menu non declenche")
				_cov("quit_to_menu")
	if G.get("gameOver") != null:
		# heros : plus de pion qui traine une fois l'ecran de fin pose (les etiquettes flottantes ont 1 s de vie)
		var t_end := Time.get_ticks_msec() + int(12000.0 / maxf(Engine.time_scale, 1.0))
		while board._animating_hero and Time.get_ticks_msec() < t_end: # la derniere traversee se joue jusqu'au bout meme apres la fin de partie
			await get_tree().process_frame
		await _wait(1.2) # temps de jeu (le minuteur suit Engine.time_scale)
		_check(board._hero_pawn == null or not is_instance_valid(board._hero_pawn), "fin de partie : un pion de heros reste a l'ecran")
		_check(not board._animating_hero, "fin de partie : animation de heros jamais terminee")
		var stray: int = board.hero_crossing_layer.get_children().filter(func(c): return not c.is_queued_for_deletion()).size()
		var left: Array = board.hero_crossing_layer.get_children().filter(func(c): return not c.is_queued_for_deletion())
		var what: Array = left.map(func(c): return "%s a=%s y=%s" % [c.get_class(), c.modulate.a, c.global_position.y])
		_check(stray == 0, "fin de partie : %d elements d'animation restent a l'ecran %s" % [stray, str(what)])

# ---------------------------------------------------------------------------------------------------------------------
# Interactions de base (partie neuve deterministe) : sort sans / avec cible, capacite par clic, menu, regles, sortie
# ---------------------------------------------------------------------------------------------------------------------

## Joueur « premier coup legal » deterministe, pour amener une partie neuve au debut de la construction (voir _new_game).
func _act_simple() -> void:
	var G: Dictionary = gm.G
	var phase: String = G.get("phase", "")
	var me: Dictionary = (G["players"] as Dictionary)[0]
	var pc: Dictionary = G.get("pendingChoice", {})
	if board._last_phase != phase and phase != "":
		board.refresh()
	if not pc.is_empty():
		if board._is_opening_discard_for_me():
			board._on_hand_card_clicked(0, (me["hand"] as Array)[0])
			board._on_hand_card_clicked(1, (me["hand"] as Array)[1])
			board._on_discard_confirm()
		elif int(pc.get("playerId", -1)) == 0:
			var mv: Array = gm.legal_moves(0)
			if not mv.is_empty():
				board._do(mv[0])
		return
	if not (G.get("stack", []) as Array).is_empty(): # Spell Battle : le joueur doit repondre (passer)
		if gm.legal_moves(0).any(func(m): return m["type"] == "pass"):
			board._on_pass_pressed()
		return
	match phase:
		"boss":
			if me.get("boss") == null and board._boss_ready:
				board._confirm_btn.pressed.emit()
		"setup", "build":
			var builds := int(me.get("buildsThisTurn", 0))
			var want_build: bool = (phase == "build" and builds == 0) or (phase == "setup" and bool(G.get("setupBuild", false)) and builds == 0)
			if want_build:
				var hand: Array = me["hand"]
				for i in hand.size():
					if (hand[i] as Dictionary).get("isRoom", false) and gm.can_build_room_at(0, i, (me["dungeon"] as Array).size()):
						board._on_hand_card_clicked(i, hand[i])
						if not board._tgt.is_empty(): # plusieurs emplacements possibles : la 1re entree est l'emplacement libre
							(board._tgt["entries"][0]["cb"] as Callable).call()
						return
			if not gm.legal_moves(0).is_empty():
				_press_pass()
		"adventure":
			var types: Array = gm.legal_moves(0).map(func(m): return m["type"])
			if types.has("adventureNext"):
				board._on_advance_pressed()
			elif types.has("passBuild") or types.has("pass"):
				board._on_pass_pressed()

## Motivation (OpponnentDungeonSizeMoreThan(1)) n'est jouable que si un adversaire a au moins une salle de plus : on en pose deux chez le siege 1.
func _foe_rooms(G: Dictionary) -> void:
	var foe_dungeon: Array = (G["players"][1] as Dictionary)["dungeon"]
	for i in 2:
		foe_dungeon.append([(CardDB.rooms[i] as Dictionary).duplicate(true)])

func _take_spell(id: String) -> int:
	var G: Dictionary = gm.G
	var deck: Array = G["decks"]["spells"]
	for i in deck.size():
		if str((deck[i] as Dictionary).get("id", "")) == id:
			var hand: Array = G["players"][0]["hand"]
			hand.append(deck.pop_at(i))
			board.refresh()
			return hand.size() - 1
	return -1

## Partie neuve amenee au debut de la construction du tour 1 (aucun choix en attente) : etat comparable d'un lancement a l'autre.
func _new_game() -> void:
	await _teardown()
	CardDB._rng.seed = 424242
	gm = GameManager.new()
	add_child(gm)
	gm.rng.seed = 424242 # Match._ready l'a randomise : le tirage du boss doit etre reproductible
	gm.start_new_game(2, 1, ["base"])
	board = load("res://godot/scenes/Board.tscn").instantiate()
	board.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(board)
	board.skip_animations = true
	board.setup(gm, func(): quit_calls += 1)
	await _wait(0.1)
	for step in 600:
		var G: Dictionary = gm.G
		if str(G.get("phase", "")) == "build" and (G.get("pendingChoice", {}) as Dictionary).is_empty() and int((G["players"][0] as Dictionary).get("buildsThisTurn", 0)) == 0 and not gm.legal_moves(0).is_empty():
			return
		await _wait(0.05)
		_act_simple()
	_fail("partie neuve : la construction du tour 1 n'a pas ete atteinte")

## Apres un sort / une capacite : la pile (Spell Battle) et les choix en attente se vident (l'IA repond, l'humain passe).
func _drain() -> void:
	for i in 300:
		if (gm.G.get("stack", []) as Array).is_empty() and (gm.G.get("pendingChoice", {}) as Dictionary).is_empty():
			return
		await _wait(0.05)
		_act_simple()
	_fail("pile / choix jamais resolus apres un sort")

## CRL007 Frostman Lander (salle a capacite de main) : en construction, un clic propose BUILD ou une cible (avant : la pose gagnait toujours).
func _check_hand_room() -> void:
	_tag = "[crash-landing]"
	await _teardown()
	CardDB._rng.seed = 7
	gm = GameManager.new()
	add_child(gm)
	gm.rng.seed = 7 # Match._ready l'a randomise : le tirage du boss doit etre reproductible
	gm.start_new_game(2, 1, ["crash-landing"])
	board = load("res://godot/scenes/Board.tscn").instantiate()
	board.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(board)
	board.skip_animations = true
	board.setup(gm, func(): quit_calls += 1)
	await _wait(0.1)
	for step in 600:
		var Gs: Dictionary = gm.G
		if str(Gs.get("phase", "")) == "build" and (Gs.get("pendingChoice", {}) as Dictionary).is_empty() and int((Gs["players"][0] as Dictionary).get("buildsThisTurn", 0)) == 0 and not gm.legal_moves(0).is_empty():
			break
		await _wait(0.05)
		_act_simple()
	var G: Dictionary = gm.G
	var me: Dictionary = G["players"][0]
	var foe: Dictionary = G["players"][1]
	var adv_room: Dictionary = {}
	for r in CardDB.rooms:
		if bool((r as Dictionary).get("advanced", false)):
			adv_room = (r as Dictionary).duplicate(true)
			break
	adv_room["faceDown"] = false
	(foe["dungeon"] as Array).push_front([adv_room])
	var proto: Dictionary = {}
	for r in CardDB.rooms:
		if str((r as Dictionary).get("id", "")) == "CRL007":
			proto = (r as Dictionary).duplicate(true)
	if not _check(not proto.is_empty(), "CRL007 introuvable"):
		return
	proto["isRoom"] = true
	(me["hand"] as Array).append(proto)
	board.refresh()
	var idx: int = (me["hand"] as Array).size() - 1
	var uses := gm.legal_moves(0).filter(func(m): return m["type"] == "useHandRoom" and int(m["args"][0]) == idx)
	if _check(not uses.is_empty(), "CRL007 : aucun coup useHandRoom legal en construction"):
		board._on_hand_card_clicked(idx, (me["hand"] as Array)[idx])
		await get_tree().process_frame
		if _check(board._popup_kind == "target", "CRL007 en construction : un clic doit proposer BUILD / cible (popup=%s)" % board._popup_kind):
			var btns := _buttons(board._popup)
			var n_b := _n_build_targets(0, idx) # emplacements (libre + recouvrables) d'abord, puis les cibles de la capacite
			_check(btns.size() == n_b + uses.size() + 1, "CRL007 : %d boutons (%d emplacements + %d cibles + CANCEL attendus)" % [btns.size(), n_b, uses.size()])
			if btns.size() > n_b:
				(btns[n_b] as Button).pressed.emit() # premiere cible
				await get_tree().process_frame
				_check(board._popup_kind == "" and not (me["hand"] as Array).has(proto), "CRL007 : la capacite n'a pas ete utilisee (carte encore en main)")
				_cov("hand_room_menu")

## Aucun bouton visible (hors fenetres et main) ne recouvre un emplacement de donjon, le mien comme celui de l'adversaire.
func _check_no_slot_cover() -> void:
	var rects: Array = []
	for sl in board._dungeon_slots:
		rects.append((sl as Control).get_global_rect())
	for sc in board._foe_slots:
		rects.append((sc as Control).get_global_rect())
	var stack: Array = [board]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			if c.is_queued_for_deletion() or c == board._popup or c == board.hand_layer or c in board._dungeon_slots or c in board._foe_slots:
				continue
			stack.append(c)
			if c is BaseButton and (c as Control).is_visible_in_tree():
				for r in rects:
					if (c as Control).get_global_rect().intersects(r):
						_fail("le bouton « %s » (%s) recouvre un emplacement de donjon %s" % [str(c.get("text")), c.name, r])
						return

## Extensions du wiki, tous paquets : les coups « DISCARD: +1 COIN » ne forment plus de grille sur le plateau (menu de la carte de la main,
## qui joue toujours le coup), et un boss du wiki a un fond de donjon APK et sa carte a la place du sprite.
func _check_wiki_ui() -> void:
	_tag = "[all-packs ui]"
	await _teardown()
	CardDB._rng.seed = 31
	gm = GameManager.new()
	add_child(gm)
	gm.rng.seed = 31 # Match._ready l'a randomise : le tirage du boss doit etre reproductible
	gm.start_new_game(2, 1, ["players-choice", "hidden-heroes", "tools", "tools-wiki", "next-level", "crash-landing", "minibosses"])
	board = load("res://godot/scenes/Board.tscn").instantiate()
	board.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(board)
	board.skip_animations = true
	board.setup(gm, func(): quit_calls += 1)
	await _wait(0.1)
	for step in 600:
		var Gs: Dictionary = gm.G
		if str(Gs.get("phase", "")) == "build" and (Gs.get("pendingChoice", {}) as Dictionary).is_empty() and int((Gs["players"][0] as Dictionary).get("buildsThisTurn", 0)) == 0 and not gm.legal_moves(0).is_empty():
			break
		await _wait(0.05)
		_act_simple()
	board.refresh()
	await get_tree().process_frame
	await get_tree().process_frame
	var me: Dictionary = gm.G["players"][0]
	var coin_moves := gm.legal_moves(0).filter(func(m): return m["type"] == "discardForCoin")
	if _check(not coin_moves.is_empty(), "tous paquets : aucun coup DISCARD: +1 COIN en construction"):
		_check_no_slot_cover()
		_check(board.extra_bar.get_children().filter(func(c): return not c.is_queued_for_deletion()).size() <= 1, "tous paquets : plusieurs boutons d'extension")
		var idx: int = int(coin_moves[0]["args"][0])
		for cm in coin_moves: # de preference une salle aussi constructible : son menu a au moins deux entrees
			if _n_build_targets(0, int(cm["args"][0])) + _n_hand_uses(0, int(cm["args"][0])) >= 2:
				idx = int(cm["args"][0])
				break
		var menu := _n_build_targets(0, idx) + _n_hand_uses(0, idx) >= 2 # sinon l'unique coup (DISCARD) est joue directement
		var coins0 := int(me.get("coins", 0))
		var n_hand := (me["hand"] as Array).size()
		(_hand_cards()[idx] as CardUI).card_clicked.emit(null)
		await get_tree().process_frame
		if menu:
			var entry: Button = null
			if _check(board._popup_kind == "target", "tous paquets : le clic sur la salle de la main n'ouvre pas son menu (popup=%s)" % board._popup_kind):
				for b in _buttons(board._popup):
					if "+1 COIN" in (b as Button).text:
						entry = b
			if not _check(entry != null, "tous paquets : pas d'entree DISCARD: +1 COIN dans le menu de la carte"):
				return
			entry.pressed.emit()
			await get_tree().process_frame
		_check(int(me.get("coins", 0)) == coins0 + 1 and (me["hand"] as Array).size() == n_hand - 1, "tous paquets : DISCARD: +1 COIN sans effet")
		_cov("coin_discard_menu" if menu else "coin_discard_direct")
	# Boss du wiki (aucune image de personnage APK) : fond de donjon jamais vide, carte du boss dans la zone du sprite APK
	var wiki := CardDB.bosses.filter(func(b): return not ResourceLoader.exists("res://assets/ui/characters/%s_character.webp" % str(b.get("id", "")).to_lower()))
	if _check(not wiki.is_empty(), "aucun boss du wiki sans sprite APK"):
		for lane in [0, 1]:
			var L: Dictionary = board._lane[lane]
			var area := Rect2(1470, 270, 170, 170) if lane == 0 else Rect2(1465, 690, 145, 160)
			for b in wiki.slice(0, 6):
				board._set_boss(L, b)
				await get_tree().process_frame
				await get_tree().process_frame
				_check((L["bg"] as TextureRect).texture != null, "fond de donjon vide pour le boss %s (couloir %d)" % [str(b.get("id")), lane])
				var cards := (L["container"] as Control).get_children().filter(func(c): return c is CardUI and not c.is_queued_for_deletion())
				if _check(cards.size() == 1, "boss %s : %d cartes a la place du sprite" % [str(b.get("id")), cards.size()]):
					var gr: Rect2 = (cards[0] as Control).get_global_rect()
					_check(area.grow(4.0).encloses(gr), "boss %s : carte %s hors de la zone du sprite %s (couloir %d)" % [str(b.get("id")), gr, area, lane])
		_cov("wiki_boss_bg")

## Parcours Main : plateau lance depuis le menu, quelques gestes, QUIT -> menu, nouvelle partie (le plateau precedent doit disparaitre proprement).
func _check_main_flow() -> void:
	_tag = "[main]"
	await _teardown()
	var main = load("res://godot/scenes/Main.tscn").instantiate()
	add_child(main)
	await _wait(0.3)
	for n in [2, 3]:
		main.start_match(n)
		await _wait(0.3)
		if not _check(main.board != null and is_instance_valid(main.board), "Main.start_match(%d) : pas de plateau" % n):
			break
		gm = main.game_manager
		board = main.board
		board.skip_animations = true
		for i in 60:
			await _wait(0.04)
			_act_simple()
		_check(main.board.get_children().filter(func(c): return c is AcceptDialog).is_empty(), "Main : fenetre residuelle")
		board._open_quit_confirm()
		await get_tree().process_frame
		var yes: Array = board._popup.find_children("*", "TextureButton", true, false) # QUIT GAME? : [CANCEL, QUIT]
		if _check(yes.size() == 2, "Main : confirmation de sortie"):
			(yes[1] as BaseButton).pressed.emit()
		await _wait(0.3)
		_check(main.board == null, "retour au menu : le plateau n'est pas libere")
		_cov("main_flow")
	board = null
	gm = null
	main.queue_free()
	await get_tree().process_frame

## Zones de ciblage de tous les genres (salle, heros chez moi / chez l'adversaire, ville, boss), plusieurs coups sur une meme zone,
## repli sur la liste centrale sans zone, et remise a z 0 des noeuds du plateau a la fin.
func _check_target_spots() -> void:
	_tag = "[target-spots]"
	var G: Dictionary = gm.G
	var me: Dictionary = G["players"][0]
	var foe: Dictionary = G["players"][1]
	var h_a: Dictionary = (CardDB.heroes[5] as Dictionary).duplicate(true)
	var h_b: Dictionary = (CardDB.heroes[6] as Dictionary).duplicate(true)
	(me["entrance"] as Array).clear() # (des heros attires plus haut peuvent porter le meme id que h_a / h_b : la zone viserait le mauvais exemplaire)
	(foe["entrance"] as Array).clear()
	(me["entrance"] as Array).append(h_a)
	(foe["entrance"] as Array).append(h_b)
	if (G["town"] as Array).is_empty(): # la ville depend de la main tiree (sorts joues plus haut) : la zone « town » veut un heros
		(G["town"] as Array).append((CardDB.heroes[7] as Dictionary).duplicate(true))
	board.refresh()
	for i in 2:
		await get_tree().process_frame
	var hits: Array = []
	var specs: Array = [["room", {"roomIndex": 0}], ["hero mine", {"heroId": h_a["id"]}], ["hero foe", {"heroId": h_b["id"]}],
		["town", {"townIndex": 0}], ["me", {"targetPlayerId": 0}], ["foe boss", {"targetPlayerId": 1}], ["room b", {"roomIndex": 0, "mode": "b"}]]
	var entries: Array = []
	for sp in specs:
		var lbl: String = sp[0]
		var spot: Dictionary = board._spot_of_target(sp[1], 0)
		_check(not spot.is_empty(), "zone de ciblage « %s » : aucune zone pour %s" % [lbl, str(sp[1])])
		entries.append({"label": lbl, "spot": spot, "cb": func(): hits.append(lbl)})
	board._target_list("test", "Select a target", entries, Callable(), {"k": "room", "pid": 0, "idx": 0}) # la salle 0 est aussi la source de la capacite
	for i in 3:
		await get_tree().process_frame
	_check(board._tgt_spots.size() == specs.size() - 1, "zones allumees : %d (%d attendues, 2 coups sur la salle)" % [board._tgt_spots.size(), specs.size() - 1])
	_check(AudioManager.loop_count("sfx_sparklecard") == 1, "ciblage : la boucle sfx_sparklecard doit tourner (salle source en GreenGlow), compteur %d" % AudioManager.loop_count("sfx_sparklecard")) # CardStackSlotComponent.cs:312
	var lifted: Array = board._tgt_lifted.duplicate()
	var fx_nodes: Array = lifted.filter(func(n): return is_instance_valid(n) and not _emitting(n).is_empty())
	_check(fx_nodes.size() == 1 and fx_nodes[0] is DungeonSlot, "ciblage : seule la salle SOURCE emet (GreenGlow, TargetResolverBaseSceneBehavior.cs:228), %d noeud(s) emetteur(s)" % fx_nodes.size())
	for sp in board._tgt_spots.duplicate():
		var ids: Array = sp["ids"]
		await _click_at((sp["ctrl"] as Control).get_global_rect().get_center())
		if ids.size() > 1: # deux coups sur la salle : petite liste (CANCEL la referme et laisse le ciblage ouvert)
			if _check(board._popup_kind == "target" and _buttons(board._popup).size() == 3, "zone a 2 coups : petite liste attendue"):
				(_buttons(board._popup)[2] as Button).pressed.emit()
				await get_tree().process_frame
				_check(board._popup_kind == "" and not board._tgt.is_empty(), "zone a 2 coups : CANCEL doit garder le ciblage")
				board._target_pick(ids)
				await get_tree().process_frame
				(_buttons(board._popup)[0] as Button).pressed.emit()
				board._popup_close() # le vrai coup (_do) referme la liste ; ici les rappels de test ne jouent rien
				await get_tree().process_frame
	hits.sort()
	var want := ["foe boss", "hero foe", "hero mine", "me", "room", "town"]
	_check(hits.size() == 6 or hits.size() == 7, "zones cliquees : %s" % str(hits))
	for w in want:
		_check(hits.has(w), "zone « %s » : clic sans effet (%s)" % [w, str(hits)])
	board._target_cancel()
	await get_tree().process_frame
	_check(board._tgt.is_empty(), "ciblage : mode non referme")
	_check(AudioManager.loop_count("sfx_sparklecard") == 0, "ciblage ferme : la boucle sfx_sparklecard doit s'arreter") # CardStackSlotComponent.cs:334
	_check(fx_nodes.all(func(n): return not is_instance_valid(n) or _emitting(n).is_empty()), "ciblage ferme : la salle doit cesser d'emettre (CardStackSlotComponent.cs:331-334)")
	for n in lifted:
		if is_instance_valid(n):
			_check((n as CanvasItem).z_index == 0, "ciblage : un noeud du plateau reste devant le voile (z %d)" % (n as CanvasItem).z_index)
	# sans zone (ex. ames, pile) : repli sur la liste centrale
	var called: Array = []
	board._target_list("test", "x", [{"label": "A", "cb": func(): called.append(1)}], Callable())
	_check(board._popup_kind == "target" and board._tgt.is_empty(), "cible sans zone : la liste centrale est attendue")
	board._popup_close()
	(me["entrance"] as Array).clear()
	(foe["entrance"] as Array).clear()
	board.refresh()
	_cov("target_spots_synthetic")

## Carrousel du choix du boss (RandomBossSelectionScene), sans animations : le boss est tire au hasard, le carrousel (>= 8 cartes) est
## deja arrete dessus, face visible, les autres cartes face cachee ; aucun clic ne change la carte ; PLAY BOSS MONSTER! (solo) valide.
func _check_boss_carousel() -> void:
	_tag = "[boss-carousel]"
	await _teardown()
	CardDB._rng.seed = 99
	gm = GameManager.new()
	add_child(gm)
	gm.rng.seed = 5
	gm.start_new_game(2, 1, ["base"])
	board = load("res://godot/scenes/Board.tscn").instantiate()
	board.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(board)
	board.skip_animations = true
	board.setup(gm, func(): quit_calls += 1)
	await _wait(0.1)
	var picks: Array = gm.G["bossPicks"]
	var bc: Array = board._boss_cards
	if not _check(picks.size() >= 3 and bc.size() == _boss_pool_size(picks.size()) and bc.size() >= 8, "carrousel : %d cartes pour %d propositions" % [bc.size(), picks.size()]):
		return
	var want: String = board._boss_pick_id
	_check(board._boss_ready and str((bc[board._boss_sel] as CardUI).card_dict.get("id", "")) == want, "carrousel : arret sur le boss tire (%s)" % want)
	_check_boss_layout()
	var back_tex: Texture2D = load(CardDB.card_image("", "back-boss"))
	var backs := bc.filter(func(c): return (c as CardUI).texture_rect.texture == back_tex).size()
	_check(backs == bc.size() - 1 and (bc[board._boss_sel] as CardUI).texture_rect.texture != back_tex, "carrousel : seule la carte du boss tire est face visible (%d dos)" % backs)
	_check(board._confirm_btn.visible and board._confirm_btn.text == "PLAY BOSS MONSTER!" and board._confirm_btn.size.x >= 390.0, "carrousel : bouton PLAY BOSS MONSTER! absent")
	_check(board._dim.visible and board._dim.size == Vector2(1920, 1080), "carrousel : tout l'ecran doit s'assombrir (panneaux et plaque compris)")
	_check(board.foe_name_label.text == "", "carrousel : le boss adverse est visible")
	_check(board._carousel_text.text.contains(str((bc[board._boss_sel] as CardUI).card_dict.get("name", "")).to_upper()), "carrousel : nom du boss absent (%s)" % board._carousel_text.text)
	# pas de choix du joueur : un clic sur une voisine ne change rien
	var sel0: int = board._boss_sel
	(bc[(sel0 + 1) % bc.size()] as CardUI).card_clicked.emit(null)
	await get_tree().process_frame
	_check(board._boss_sel == sel0 and board._boss_pick_id == want and gm.G["players"][0].get("boss") == null, "carrousel : un clic a change la selection ou valide le boss")
	# le tirage est aleatoire : plusieurs tirages successifs ne donnent pas toujours le meme boss
	var seen := {}
	for k in 12:
		board._boss_stop()
		board.refresh()
		seen[board._boss_pick_id] = true
	_check(seen.size() > 1, "carrousel : 12 tirages, toujours le meme boss (%s)" % str(seen.keys()))
	want = board._boss_pick_id
	board._confirm_btn.pressed.emit()
	await get_tree().process_frame
	var boss = gm.G["players"][0].get("boss")
	_check(boss != null and str((boss as Dictionary).get("id", "")) == want, "carrousel : PLAY BOSS MONSTER! n'a pas valide le boss tire (%s)" % want)
	_check(board._boss_seat == -1 and not board._boss_ready, "carrousel : etat du tirage non remis a zero")
	_cov("boss_carousel")

## Evenements souris reels (push_input avec masque de boutons) : appui, mouvements, relachement.
func _mouse(pos: Vector2, pressed: bool, motion: bool, mask: int = 0) -> void:
	var ev: InputEventMouse
	if motion:
		var m := InputEventMouseMotion.new()
		m.button_mask = mask
		ev = m
	else:
		var b := InputEventMouseButton.new()
		b.button_index = MOUSE_BUTTON_LEFT
		b.pressed = pressed
		b.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		ev = b
	ev.position = pos
	ev.global_position = pos
	get_viewport().push_input(ev, true)
	await get_tree().process_frame

func _drag(from: Vector2, to: Vector2, release_at = null, steps: int = 6) -> void:
	await _mouse(from, true, false)
	for k in range(1, steps + 1):
		await _mouse(from.lerp(to, float(k) / float(steps)), false, true, MOUSE_BUTTON_MASK_LEFT)
	await _mouse(release_at if release_at != null else to, false, false)

## Sequence du carrousel avec animations reelles (temps accelere) : 0,5 s, cartes face cachee, rotation, arret sur le boss tire face visible, puis
## PLAY BOSS MONSTER! (qui ne marche qu'une fois la rotation finie). Plusieurs humains : pose automatique apres 2 s et passage de main.
func _check_boss_flip() -> void:
	_tag = "[boss-flip]"
	await _teardown()
	CardDB._rng.seed = 123
	gm = GameManager.new()
	add_child(gm)
	gm.rng.seed = 123 # Match._ready l'a randomise : le tirage du boss doit etre reproductible
	gm.start_new_game(2, 1, ["base"])
	board = load("res://godot/scenes/Board.tscn").instantiate()
	board.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(board)
	board.skip_animations = false
	board.set_process(false) # l'IA ne joue pas pendant ce test
	Engine.time_scale = ANIM_TIME_SCALE
	board.setup(gm, func(): quit_calls += 1)
	await _wait(0.1)
	var bc: Array = board._boss_cards.duplicate()
	var want: String = board._boss_pick_id
	var back_tex: Texture2D = load(CardDB.card_image("", "back-boss"))
	_check(not board._boss_ready and bc.size() >= 8 and not board._confirm_btn.visible, "sequence : la rotation ne doit pas etre finie au depart")
	_check(bc.all(func(c): return (c as CardUI).texture_rect.texture != back_tex), "sequence : les cartes sont d'abord face visible (attente de 0,5 s)")
	await _wait(1.2) # 0,5 s + retournement de 0,5 s
	_check(not board._boss_ready and bc.all(func(c): return (c as CardUI).texture_rect.texture == back_tex), "sequence : toutes les cartes doivent etre face cachee pendant la rotation")
	var sels := {}
	var t := 0.0
	while not board._boss_ready and t < 12.0:
		sels[board._boss_sel] = true
		board._confirm_btn.pressed.emit() # un appui pendant la rotation ne fait rien
		await _wait(0.1)
		t += 0.1
	_check(board._boss_ready, "sequence : la rotation ne s'est jamais arretee")
	_check(sels.size() >= 8, "sequence : la rotation n'a parcouru que %d cartes" % sels.size())
	_check(gm.G["players"][0].get("boss") == null, "sequence : un appui pendant la rotation a valide le boss")
	await _wait(0.4)
	_check(str((bc[board._boss_sel] as CardUI).card_dict.get("id", "")) == want and (bc[board._boss_sel] as CardUI).texture_rect.texture != back_tex, "sequence : arret sur le boss tire, face visible")
	_check(bc.filter(func(c): return (c as CardUI).texture_rect.texture == back_tex).size() == bc.size() - 1, "sequence : les autres cartes restent face cachee")
	_check(board._confirm_btn.visible and board._carousel_text.text.contains(str((bc[board._boss_sel] as CardUI).card_dict.get("name", "")).to_upper()), "sequence : bouton et nom du boss attendus apres l'arret")
	board._confirm_btn.pressed.emit()
	board._confirm_btn.pressed.emit() # un 2e appui ne fait rien
	await get_tree().process_frame
	var boss = gm.G["players"][0].get("boss")
	_check(boss != null and str((boss as Dictionary).get("id", "")) == want, "sequence : le boss tire n'a pas ete valide (boss=%s)" % str(boss))
	# plusieurs humains : pas de bouton, la pose part seule apres 2 s
	await _teardown()
	CardDB._rng.seed = 321
	gm = GameManager.new()
	add_child(gm)
	gm.rng.seed = 321 # Match._ready l'a randomise : le tirage du boss doit etre reproductible
	gm.start_new_game(2, 2, ["base"])
	board = load("res://godot/scenes/Board.tscn").instantiate()
	board.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(board)
	board.skip_animations = false
	board.set_process(false)
	Engine.time_scale = ANIM_TIME_SCALE
	board.setup(gm, func(): quit_calls += 1)
	await _wait(0.1)
	t = 0.0
	while not board._boss_ready and t < 12.0:
		_check(not board._confirm_btn.visible, "hot-seat : PLAY BOSS MONSTER! visible")
		await _wait(0.1)
		t += 0.1
	var want1: String = board._boss_pick_id
	_check(board._boss_ready and not board._confirm_btn.visible and gm.G["players"][0].get("boss") == null, "hot-seat : arret sans bouton, boss pas encore pose")
	await _wait(1.5)
	_check(gm.G["players"][0].get("boss") == null, "hot-seat : la pose automatique est partie avant les 2 s")
	await _wait(1.0)
	var b0 = gm.G["players"][0].get("boss")
	_check(b0 != null and str((b0 as Dictionary).get("id", "")) == want1, "hot-seat : le boss tire n'a pas ete pose apres 2 s")
	_cov("boss_flip")

# ---------------------------------------------------------------------------------------------------------------------
# UI de l'APK : fenetres chronometrees, glisser-deposer, appui long, DONE / mise en garde, galerie, ecran de fin
# ---------------------------------------------------------------------------------------------------------------------

func _right_click(pos: Vector2, pressed: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_RIGHT
	ev.pressed = pressed
	ev.position = pos
	ev.global_position = pos
	get_viewport().push_input(ev, true)
	await get_tree().process_frame

## Barre verte de l'aventure (3 s, au-dessus du heros) et de la pile de sorts (6 s) : visible tant qu'un sort est jouable, pas de PASS TURN,
## cadre dore sur le sort jouable, le jeu continue (passe envoye) quand elle est vide. Etat construit a la main ; temps simule avec _process(dt).
## Etat d'aventure construit a la main : un heros dans ma premiere salle, Giant Size en main, l'IA n'a rien a jouer (la fenetre ne depend que
## du joueur). Renvoie l'index du sort dans la main (-1 si introuvable).
func _adventure_window_setup() -> int:
	await _new_game()
	board.set_process(false)
	board.win_time_scale = 1.0
	var G: Dictionary = gm.G
	var me: Dictionary = G["players"][0]
	var foe: Dictionary = G["players"][1]
	(foe["hand"] as Array).clear() # l'IA n'a rien a jouer : la fenetre ne depend que du joueur
	(foe["dungeon"] as Array).clear()
	var room: Dictionary = {}
	for r in CardDB.rooms:
		if str((r as Dictionary).get("type", "")) == "monster" and not bool((r as Dictionary).get("advanced", false)):
			room = (r as Dictionary).duplicate(true)
			break
	room["faceDown"] = false
	(me["dungeon"] as Array).push_front([room])
	var hero: Dictionary = (CardDB.heroes[5] as Dictionary).duplicate(true)
	(me["entrance"] as Array).clear()
	(me["entrance"] as Array).append(hero)
	G["phase"] = "adventure"
	G.erase("buildWindow")
	G["adventure"] = {"playerId": 0, "hero": hero, "roomIndex": 0, "hp": 12, "pause": "post-damage"}
	G["adventurePausePassed"] = {"1": true, 1: true} # l'IA a deja passe : la fenetre n'attend que le joueur
	G["activePlayer"] = 0
	var gi := _take_spell("BMA047") # Giant Size : +3 degats a une salle de monstres (cibles : la salle posee)
	board.refresh()
	await get_tree().process_frame
	return gi

## Barre de 3 s aussi avant l'entree d'un heros dans le donjon d'un siege IA (APK : CreateWaitAndMoveHeroToNextSlotTask) : l'IA attend, puis le heros entre.
func _check_ai_entry_window() -> void:
	_tag = "[ai-entry-window]"
	if not _check(await _adventure_window_setup() >= 0, "fenetre d'entree IA : Giant Size introuvable"):
		return
	var G: Dictionary = gm.G
	var foe: Dictionary = G["players"][1]
	(foe["entrance"] as Array).append(((G["players"][0] as Dictionary)["entrance"] as Array).pop_back())
	G["adventure"] = {}
	G["adventurePausePassed"] = {}
	G["activePlayer"] = 1
	board.refresh()
	board._process(1.0)
	board._process(1.0)
	_check(board._win_bar.visible and G["adventure"].is_empty() and absf(board._win_bar.frac - (1.0 - 2.0 / 3.0)) < 0.08, "fenetre d'entree IA : barre absente ou IA deja avancee (frac %.2f)" % board._win_bar.frac)
	board._process(1.0)
	board._process(0.5)
	_check((foe["entrance"] as Array).is_empty() and not board._win_bar.visible, "fenetre d'entree IA : le heros n'est pas entre a la fin de la barre")
	_cov("window_ai_entry")

func _check_windows() -> void:
	_tag = "[windows]"
	var gi := await _adventure_window_setup()
	if not _check(gi >= 0, "fenetres : Giant Size introuvable"):
		return
	var G: Dictionary = gm.G
	var me: Dictionary = G["players"][0]
	var moves: Array = gm.legal_moves(0)
	if not _check(board._has_decision(moves) and moves.any(func(m): return m["type"] == "pass"), "fenetres : aucun sort jouable / pas de passe dans la fenetre construite"):
		return
	var cards := _hand_cards()
	var gold = (cards[gi] as CardUI).get_node_or_null("GoldFrame")
	_check(gold != null and gold.visible, "fenetres : le sort jouable n'a pas de cadre dore")
	for i in cards.size():
		if bool((me["hand"][i] as Dictionary).get("isRoom", false)):
			var gf = (cards[i] as CardUI).get_node_or_null("GoldFrame")
			_check(gf == null or not gf.visible, "fenetres : cadre dore sur une salle")
	_check(not board.pass_shown() and not board.btn_advance.is_visible_in_tree(), "fenetres : PASS TURN / GO visibles en aventure (flux APK)")
	board._process(0.5)
	_check(board._win_bar.visible, "fenetres : barre de temps absente")
	var f0: float = board._win_bar.frac
	board._process(0.5)
	board._process(0.5)
	board._process(0.5)
	_check(board._win_bar.visible and board._win_bar.frac < f0 and absf(board._win_bar.frac - (1.0 - 2.0 / 3.0)) < 0.08, "fenetres : la barre ne se vide pas a 3 s (frac %.2f)" % board._win_bar.frac)
	var bp: Vector2 = board._win_bar.global_position
	_check(bp.y > 0.0 and bp.y < 1000.0 and bp.x > 150.0 and bp.x < 1707.0, "fenetres : barre hors du plateau %s" % bp)
	# un glisser en cours fige la barre (APK : SlowDown pendant le zoom)
	board._zoom = Control.new()
	var f1: float = board._win_bar.frac
	board._process(0.5)
	_check(is_equal_approx(board._win_bar.frac, f1), "fenetres : la barre avance pendant un zoom")
	board._zoom.free()
	board._zoom = null
	board._process(0.5)
	board._process(0.5)
	_check(str(gm.G["adventure"].get("pause")) == "pre-exit" and not board._win_bar.visible, "fenetres : la fin de la barre n'a pas fait passer la fenetre (pause=%s)" % str(gm.G["adventure"].get("pause")))
	_cov("window_adventure")
	# pile de sorts : sort adverse en attente, Counterspell jouable, 6 s
	await _new_game()
	board.set_process(false)
	board.win_time_scale = 1.0
	G = gm.G
	me = G["players"][0]
	((G["players"][1] as Dictionary)["hand"] as Array).clear()
	((G["players"][1] as Dictionary)["dungeon"] as Array).clear()
	var ci := _take_spell("BMA043") # Counterspell
	var spell: Dictionary = {}
	for sp in CardDB.spells:
		if str((sp as Dictionary).get("id", "")) == "BMA050":
			spell = (sp as Dictionary).duplicate(true)
	spell["isSpell"] = true
	G["stack"] = [{"id": "spell-BMA050-1", "type": "spell", "playerId": 1, "card": spell, "target": {}, "resolved": false}]
	G["stackPassed"] = {"1": true, 1: true}
	G["stackReturnPlayer"] = 1
	G["stackActivePlayer"] = 1
	G["activePlayer"] = 0
	board.refresh()
	await get_tree().process_frame
	if _check(ci >= 0 and gm.legal_moves(0).any(func(m): return m["type"] == "playSpell"), "pile : Counterspell non jouable sur la pile construite"):
		_check(board._stack_ui != null and board._stack_ui.get_child_count() == 1, "pile : le sort en attente n'est pas au centre")
		# APK : sort adverse a l'echelle 1 (zoom 350 x 490), mon sort a l'echelle de la main 0,5 ; plusieurs cartes = 0,6 espacees de 200 (SimplePositionComponent)
		var lay1: Array = board._stack_layout([{"type": "spell", "playerId": 1}])
		var lay0: Array = board._stack_layout([{"type": "spell", "playerId": board._my_pid()}])
		var lay3: Array = board._stack_layout([{"type": "spell", "playerId": 1}, {"type": "spell", "playerId": 0}, {"type": "spell", "playerId": 1}])
		_check(is_equal_approx(float(lay1[0]["k"]), 1.0) and is_equal_approx(float(lay0[0]["k"]), 0.5) and is_equal_approx(float(lay3[2]["k"]), 0.6) and is_equal_approx(float(lay3[2]["cx"]) - float(lay3[0]["cx"]), 600.0), "pile : disposition APK de la pile de sorts")
		_check(not board.pass_shown(), "pile : PASS TURN visible (flux APK : barre de temps)")
		board._process(0.5)
		_check(board._win_bar.visible and absf(board._win_bar.position.x + board._win_bar.size.x / 2.0 - board.STACK_CX) < 3.0, "pile : barre au-dessus de la pile absente")
		var fr: float = board._win_bar.frac
		for i in 5:
			board._process(0.5)
		_check(board._win_bar.visible and absf(board._win_bar.frac - (1.0 - 3.0 / 6.0)) < 0.1 and board._win_bar.frac < fr, "pile : la barre n'est pas a la moitie apres 3 s (%.2f)" % board._win_bar.frac)
		for i in 8:
			board._process(0.5)
		_check((gm.G.get("stack", []) as Array).is_empty() or bool((gm.G.get("stackPassed", {}) as Dictionary).get("0", gm.G["stackPassed"].get(0, false))), "pile : la fin de la barre n'a pas fait passer le joueur")
		_cov("window_stack")

## Vrai glisser-deposer a la souris (push_input) : une salle vers l'emplacement dore, annulation sur la main, un sort vers sa cible,
## sort hors cible sans effet ; appui long et clic droit = zoom ; un clic simple joue encore un sort sans cible.
func _check_drag_and_zoom() -> void:
	_tag = "[drag]"
	await _new_game()
	var G: Dictionary = gm.G
	var me: Dictionary = G["players"][0]
	var hand: Array = me["hand"]
	var dsize: int = (me["dungeon"] as Array).size()
	var idx := -1
	for i in hand.size():
		if gm.can_build_room_at(0, i, dsize) and not bool((hand[i] as Dictionary).get("advanced", false)):
			idx = i
	if not _check(idx >= 0, "glisser : aucune salle construisible"):
		return
	hand.push_back(hand.pop_at(idx)) # la carte a glisser est la derniere : au premier plan de l'eventail
	idx = hand.size() - 1
	board.refresh()
	await get_tree().process_frame
	await get_tree().process_frame
	var card: CardUI = _hand_cards()[idx]
	var start := card.get_global_rect().get_center()
	var n_hand := hand.size()
	# salle : annulation (relache sur la main)
	await _mouse(start, true, false)
	await _mouse(start + Vector2(0, -40), false, true, MOUSE_BUTTON_MASK_LEFT)
	await _mouse(Vector2(start.x, 700), false, true, MOUSE_BUTTON_MASK_LEFT) # CardExtractBehavior : la carte sort de la main au-dessus de y 797
	_check(not board._drag.is_empty(), "glisser : pas de glisser en cours au-dessus de la limite de la main")
	var frames: Array = board._drag.get("frames", [])
	var n_frames := _n_build_targets(0, idx) # le prochain emplacement libre + les salles recouvrables (Boss.CanBuildRoom)
	_check(frames.size() == n_frames and n_frames == 1 + dsize, "glisser : %d emplacements dores pour une salle (%d attendus)" % [frames.size(), 1 + dsize])
	var prev: Control = board._drag.get("preview")
	_check(prev != null and absf(prev.size.x - (board.HAND_CARD.x + 8.0)) < 1.0, "glisser : la carte tiree n'a pas la taille de la main (APK : NormalScale)")
	await _mouse(start, false, false) # sur la main (y >= 940, CardExtractBehavior.cs:~176 upperLimit) : annule
	_check(board._drag.is_empty() and (me["hand"] as Array).size() == n_hand and (me["dungeon"] as Array).size() == dsize, "glisser : relacher sur la main doit annuler")
	_check(board.hand_layer.get_children().filter(func(c): return not c.is_queued_for_deletion() and c.modulate.a < 0.5).is_empty(), "glisser : la carte annulee n'est pas revenue dans la main")
	# salle : depot sur l'emplacement dore
	card = _hand_cards()[idx]
	start = card.get_global_rect().get_center()
	var slot_c: Vector2 = (board._dungeon_slots[maxi(0, DUNGEON_N - dsize - 1)] as Control).get_global_rect().get_center() # le prochain emplacement libre
	await _mouse(start, true, false)
	for k in range(1, 7):
		await _mouse(start.lerp(slot_c, float(k) / 6.0), false, true, MOUSE_BUTTON_MASK_LEFT)
	_check(not board._drag.is_empty(), "glisser : salle - glisser perdu en route")
	# APK : l'emplacement survole par la carte porte card_border_yellow_glow_scaled, les autres card_border_yellow_scaled (BuildRoomHandSceneBehavior.cs:120-127)
	var glows: Array = board._ui_layer.find_children("SlotGlow", "TextureRect", true, false).filter(func(f): return not f.is_queued_for_deletion() and str((f as TextureRect).texture.resource_path).ends_with("card_border_yellow_glow_scaled.webp"))
	_check(glows.size() == 1, "glisser : %d emplacements au cadre lumineux sous la carte (1 attendu)" % glows.size())
	var slot_fx: Array = _emitting(board._ui_layer)
	_check(slot_fx.size() == 1 and (slot_fx[0] as Node).get_parent() == glows[0], "glisser : seul l'emplacement survole emet (BuildRoomHandSceneBehavior.cs:125-132), %d emetteur(s)" % slot_fx.size())
	await _mouse(slot_c, false, false)
	_check((me["dungeon"] as Array).size() == dsize + 1 and (me["hand"] as Array).size() == n_hand - 1, "glisser : la salle n'a pas ete construite sur l'emplacement vise")
	_check(board._drag.is_empty() and board._ui_layer.find_children("GoldFrame", "Control", true, false).is_empty(), "glisser : cadres dores restes apres le depot")
	_cov("drag_room")
	# sorts : Freeze (n'importe quelle phase, cible = une salle), deux salles posees = deux cibles
	await _new_game()
	G = gm.G
	me = G["players"][0]
	var protos: Array = CardDB.rooms.filter(func(r): return not bool((r as Dictionary).get("advanced", false)))
	for k in 2:
		var pr: Dictionary = (protos[k] as Dictionary).duplicate(true)
		pr["faceDown"] = false
		(me["dungeon"] as Array).push_front([pr])
	var gi := _take_spell("BMA046")
	if not _check(gi >= 0, "glisser : Freeze introuvable"):
		return
	board.refresh()
	await get_tree().process_frame
	await get_tree().process_frame
	var cands: Array = gm.legal_moves(0).filter(func(m): return m["type"] == "playSpell" and int(m["args"][0]) == gi)
	if not _check(cands.size() >= 2, "glisser : Freeze a %d cibles (2+ attendues)" % cands.size()):
		return
	card = _hand_cards()[gi]
	start = card.get_global_rect().get_center()
	var n_before: int = (me["hand"] as Array).size()
	# relache hors cible (plusieurs cibles) : rien ne se joue
	await _mouse(start, true, false)
	for k in range(1, 5):
		await _mouse(start.lerp(Vector2(300, 300), float(k) / 4.0), false, true, MOUSE_BUTTON_MASK_LEFT)
	var nf: int = (board._drag.get("frames", []) as Array).size()
	_check(nf >= 2, "glisser : %d cibles dorees pour Freeze (2+ attendues)" % nf)
	await _mouse(Vector2(300, 300), false, false)
	_check((me["hand"] as Array).size() == n_before and (gm.G.get("stack", []) as Array).is_empty(), "glisser : un sort lache hors cible a ete joue")
	# relache sur la salle ciblee
	card = _hand_cards()[gi]
	start = card.get_global_rect().get_center()
	var tgt_slot: DungeonSlot = null
	for sl in board._dungeon_slots:
		if not (sl as DungeonSlot).current_stack.is_empty():
			tgt_slot = sl
			break
	var tc := tgt_slot.get_global_rect().get_center()
	await _mouse(start, true, false)
	for k in range(1, 7):
		await _mouse(start.lerp(tc, float(k) / 6.0), false, true, MOUSE_BUTTON_MASK_LEFT)
	await _mouse(tc, false, false)
	_check((me["hand"] as Array).size() == n_before - 1, "glisser : le sort lache sur sa cible n'a pas ete joue")
	await _drain()
	var fz = tgt_slot.find_child("Frozen", true, false)
	_check(fz != null and fz.visible, "glace : la salle ciblee par Freeze n'est pas couverte de glace")
	_cov("drag_spell")
	# appui long (zoom) puis relachement : aucun clic ; clic droit maintenu = zoom aussi
	board.refresh()
	await get_tree().process_frame
	card = _hand_cards()[_hand_cards().size() - 1]
	start = card.get_global_rect().get_center()
	var s0 := _sig()
	await _mouse(start, true, false)
	await _wait(1.0)
	_check(board._zoom != null and board._zoom.size.x > 340.0 and board.hand_layer.modulate.r < 0.9, "appui long : pas de zoom / main non assombrie")
	await _mouse(start, false, false)
	_check(board._zoom == null and board.hand_layer.modulate.r > 0.99 and _sig() == s0, "appui long : le relachement doit fermer le zoom sans jouer")
	await _right_click(start, true)
	_check(board._zoom != null, "clic droit : pas de zoom")
	await _right_click(start, false)
	_check(board._zoom == null, "clic droit : zoom reste ouvert")
	_cov("long_press")
	# relachement jamais livre (pointeur hors fenetre) : la perte de focus abandonne l'appui, le rafraichissement suivant reconstruit la main
	board.refresh()
	await get_tree().process_frame
	card = _hand_cards()[_hand_cards().size() - 1]
	await _mouse(card.get_global_rect().get_center(), true, false)
	board.refresh()
	_check(not board._press.is_empty() and is_instance_valid(card) and card in _hand_cards(), "appui en cours : la main doit rester figee")
	board.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	board.refresh()
	await get_tree().process_frame
	_check(board._press.is_empty() and not (is_instance_valid(card) and card in _hand_cards()), "perte de focus : l'appui doit etre abandonne et la main reconstruite")
	await _mouse(Vector2(5, 5), false, false) # relachement tardif sans effet
	# un clic simple joue encore un sort sans cible
	await _new_game()
	G = gm.G
	me = G["players"][0]
	var mi := _take_spell("BMA050")
	_foe_rooms(G)
	board.refresh()
	await get_tree().process_frame
	await get_tree().process_frame
	var nh: int = (me["hand"] as Array).size()
	var pc: Vector2 = _hand_cards()[mi].get_global_rect().get_center()
	await _click_at(pc)
	_check((me["hand"] as Array).size() == nh - 1, "clic : le sort sans cible n'a pas ete joue a la souris")
	await _drain()
	_cov("click_spell")

## Ecarts APK refermes : colonne HEROES IN TOWN (glisser / molette / arrivee d'un heros), carrousel pour les choix de cartes, bulle de l'adversaire
## (un appui montre la carte jouee), construction par-dessus une salle sans donjon plein (Boss.CanBuildRoom : l'emplacement libre est un choix).
func _check_apk_gaps() -> void:
	_tag = "[gaps]"
	await _new_game()
	board.set_process(false)
	var G: Dictionary = gm.G
	var me: Dictionary = G["players"][0]
	var foe: Dictionary = G["players"][1]
	# --- HEROES IN TOWN : 5 heros depassent la colonne ; molette, glisser, et un nouvel arrivant est amene a l'ecran
	var town: Array = G["town"]
	while town.size() < 5:
		town.append((CardDB.heroes[town.size()] as Dictionary).duplicate(true))
	board.refresh()
	for i in 4:
		await get_tree().process_frame
	var sc: ScrollContainer = board._town_scroll
	_check(sc.get_v_scroll_bar().max_value - sc.get_v_scroll_bar().page > 10.0, "ville : %d heros ne depassent pas la colonne" % town.size())
	sc.scroll_vertical = 0
	var centre := sc.get_global_rect().get_center()
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel.pressed = true
	wheel.position = centre
	wheel.global_position = centre
	board._input(wheel)
	_check(sc.scroll_vertical > 0, "ville : la molette ne defile pas la colonne")
	sc.scroll_vertical = 0
	var s0 := _sig()
	await _drag(centre, centre + Vector2(0, -150))
	_check(sc.scroll_vertical > 100 and board._zoom == null and _sig() == s0, "ville : glisser 150 px vers le haut -> defilement %d" % sc.scroll_vertical)
	sc.scroll_vertical = 0
	town.append((CardDB.heroes[town.size()] as Dictionary).duplicate(true))
	board.refresh()
	for i in 4:
		await get_tree().process_frame
	var last: Control = board.town_container.get_child(0) # le dernier arrive est en haut de la colonne (VerticalScrollQueueComponent.CreateReorderTask)
	_check(sc.scroll_vertical == 0 and sc.get_global_rect().grow(2.0).encloses(last.get_global_rect()), "ville : le heros arrive n'est pas amene a l'ecran (defilement %d)" % sc.scroll_vertical)
	_cov("town_scroll")
	# --- bulle « HAS PLAYED A ... » de l'adversaire : un appui montre la carte (au centre), le clic suivant la ferme
	var spell: Dictionary = ((G["decks"]["spells"] as Array)[0] as Dictionary).duplicate(true)
	(foe["hand"] as Array).append(spell)
	board._notice_reset()
	board._notice_ai(1, {"type": "playSpell", "args": [(foe["hand"] as Array).size() - 1, {}]})
	if _check(board._notice != null and is_instance_valid(board._notice) and board._notice.mouse_filter == Control.MOUSE_FILTER_STOP, "bulle de sort adverse : pas cliquable"):
		var tap := InputEventMouseButton.new()
		tap.button_index = MOUSE_BUTTON_LEFT
		tap.pressed = true
		board._notice.gui_input.emit(tap)
		if _check(board._zoom != null and Rect2(0, 0, 1920, 1080).encloses(Rect2(board._zoom.position, board._zoom.size)), "bulle : l'appui ne montre pas la carte"):
			board.refresh()
			_check(board._zoom != null, "bulle : le zoom ne survit pas a un refresh")
			board._input(tap)
			_check(board._zoom == null, "bulle : le clic suivant ne ferme pas le zoom")
	var room: Dictionary = (CardDB.rooms[0] as Dictionary).duplicate(true)
	room["faceDown"] = false
	(foe["dungeon"] as Array).push_front([room])
	board._notice_reset()
	board._notice_ai(1, {"type": "activateRoom", "args": [0]})
	_check(board._notice != null and is_instance_valid(board._notice) and board._notice.mouse_filter == Control.MOUSE_FILTER_STOP, "bulle de capacite de salle adverse : pas cliquable")
	_cov("notice_tap")
	# Bottomless Pit (« Destroy this Room ») : le zoom de la bulle porte le cadre rouge card_border_red (ShowBubleDetail, GamePlayBaseScene.cs:1249-1260)
	var pit: Dictionary = {}
	for rc in CardDB.rooms:
		if str((rc as Dictionary).get("id", "")) == "BMA027":
			pit = (rc as Dictionary).duplicate(true)
	pit["faceDown"] = false
	(foe["dungeon"] as Array).push_front([pit])
	board._notice_reset()
	board._notice_ai(1, {"type": "activateRoom", "args": [0]})
	var tap2 := InputEventMouseButton.new()
	tap2.button_index = MOUSE_BUTTON_LEFT
	tap2.pressed = true
	board._notice.gui_input.emit(tap2)
	var red := false
	for t in (board._zoom.find_children("*", "TextureRect", true, false) if board._zoom != null else []):
		red = red or ((t as TextureRect).texture != null and (t as TextureRect).texture.resource_path.ends_with("card_border_red.webp"))
	_check(red, "bulle de capacite « Destroy this Room » : le zoom n'a pas le cadre rouge")
	board._zoom_hide()
	(foe["dungeon"] as Array).pop_front() # retire Bottomless Pit
	# degel : le voile de glace s'efface en fondu de 0,5 s au lieu de disparaitre (CardStackSlotComponent.cs:98)
	var fcard: CardUI = (load("res://godot/scenes/Card.tscn") as PackedScene).instantiate()
	board.add_child(fcard)
	fcard.set_frozen(true, false)
	fcard.set_frozen(false, true)
	var ghost = fcard.find_child("Frozen", true, false)
	_check(ghost != null and ghost.visible and fcard._frozen == null, "degel : le voile de glace doit rester le temps de son fondu")
	fcard.queue_free()
	# --- choix de cartes : carrousel central ; autre chose que des cartes : boutons pierre
	G["pendingChoice"] = {"type": "ui-test", "playerId": 0, "message": "Choose one Hero", "optional": true, "options": [{"card": town[0]}, {"card": town[1]}, {"card": town[2]}]}
	board.refresh()
	await get_tree().process_frame
	var btn: Button = board._popup.get_node_or_null("CardsContinue") if board._popup != null else null
	if _check(board._popup_kind == "choice" and btn != null, "choix de cartes : pas de carrousel (popup=%s)" % board._popup_kind):
		var cards: Array = board._popup.get_children().filter(func(c): return c is CardUI)
		_check(cards.size() == 3 and btn.visible and btn.text == "SKIP", "carrousel : %d cartes, bouton %s/%s (3, SKIP attendus)" % [cards.size(), btn.visible, btn.text])
		for c in cards:
			_check(Rect2(0, 0, 1920, 1080).encloses((c as Control).get_global_rect()), "carrousel : carte hors ecran %s" % (c as Control).get_global_rect())
		(cards[1] as CardUI).card_clicked.emit(null)
		_check(btn.text == "CONTINUE" and (cards[1] as CardUI).glow_rect.visible and not (cards[0] as CardUI).glow_rect.visible, "carrousel : la carte choisie n'a pas de halo / CONTINUE absent")
		_cov("cards_carousel")
	G["pendingChoice"] = {"type": "ui-test", "playerId": 0, "message": "Pick a side", "options": [{"label": "Left"}, {"label": "Right"}]}
	board.refresh()
	await get_tree().process_frame
	_check(board._popup_kind == "choice" and board._popup.get_node_or_null("CardsContinue") == null and _buttons(board._popup).size() == 2, "choix sans cartes : les boutons pierre doivent rester")
	G.erase("pendingChoice")
	board._popup_close()
	board.refresh()
	# --- A3 : salle ordinaire par-dessus une salle visible, donjon non plein ; un clic demande l'emplacement (le libre compris)
	var idx := -1
	for i in (me["hand"] as Array).size():
		var hc: Dictionary = (me["hand"] as Array)[i]
		if bool(hc.get("isRoom", false)) and not bool(hc.get("advanced", false)) and not bool(hc.get("isMiniboss", false)):
			idx = i
			break
	if not _check(idx >= 0, "A3 : aucune salle ordinaire en main"):
		return
	var host: Dictionary = (CardDB.rooms[1] as Dictionary).duplicate(true)
	host["faceDown"] = false
	(me["dungeon"] as Array).push_front([host])
	board.refresh()
	var dn: int = (me["dungeon"] as Array).size()
	var mvs := gm.legal_moves(0).filter(func(m): return m["type"] == "buildRoom" and int(m["args"][0]) == idx)
	var n_over := mvs.filter(func(m): return (m["args"] as Array).size() > 1).size()
	if not _check(dn < 5 and n_over >= 1 and mvs.size() == n_over + 1, "A3 : %d coups de construction (%d par-dessus) pour un donjon de %d salles" % [mvs.size(), n_over, dn]):
		return
	board._on_hand_card_clicked(idx, (me["hand"] as Array)[idx])
	for i in 3:
		await get_tree().process_frame
	if _check(not board._tgt.is_empty() and (board._tgt["entries"] as Array).size() == mvs.size() and board._tgt_spots.size() == mvs.size(), "A3 : le clic doit proposer %d emplacements sur le plateau (%d zones)" % [mvs.size(), board._tgt_spots.size()]):
		var hand_n: int = (me["hand"] as Array).size()
		var ti := int(((board._tgt["entries"][1]["mv"] as Dictionary)["args"] as Array)[1])
		var h0: int = ((me["dungeon"] as Array)[ti] as Array).size()
		await _click_at((board._tgt_spots[1]["ctrl"] as Control).get_global_rect().get_center())
		_check((me["hand"] as Array).size() == hand_n - 1 and ((me["dungeon"] as Array)[ti] as Array).size() == h0 + 1 and (me["dungeon"] as Array).size() == dn, "A3 : la salle n'a pas ete posee par-dessus la salle %d" % ti)
		_cov("build_over_not_full")

## PASS TURN : tant qu'une salle peut etre construite, le 1er appui montre la bulle de mon boss, le 2e confirme ; apres ma construction
## avec un sort jouable, PASS TURN devient DONE!.
func _check_done_and_warning() -> void:
	_tag = "[done]"
	await _new_game()
	board.set_process(false)
	var s0 := _sig()
	_check(board.btn_pass.is_visible_in_tree(), "mise en garde : PASS TURN absent en construction")
	_check((board.btn_pass as TextureButton).texture_normal == board._tex(board.TEX_PASS), "PASS TURN : avant ma pose le bouton doit etre PASS TURN (BuildRoomHandSceneBehavior.cs:115)")
	board._on_pass_pressed()
	_check(board._warn != null and _sig() == s0, "mise en garde : la bulle n'apparait pas au 1er appui (ou la partie a avance)")
	var lbls: Array = board._warn.find_children("*", "Label", true, false)
	_check(lbls.size() == 1 and (lbls[0] as Label).text.replace("\n", " ") == "HEY! YOU CAN BUILD A ROOM! STILL WANT TO PASS?", "mise en garde : texte de la bulle")
	board._on_pass_pressed()
	_check(board._warn == null and _sig() != s0, "mise en garde : le 2e appui doit passer")
	_cov("pass_warning")
	# Aucune salle constructible : PASS TURN demande quand meme deux appuis (DoneButtonEntity.cs:118-143), sans bulle (GamePlayBaseScene.cs:259-269)
	await _new_game()
	board.set_process(false)
	var hand0: Array = gm.G["players"][0]["hand"]
	gm.G["players"][0]["hand"] = hand0.filter(func(c): return not bool((c as Dictionary).get("isRoom", false)))
	board.refresh()
	s0 = _sig()
	board._on_pass_pressed()
	_check(board._warn == null and _sig() == s0, "PASS TURN sans salle constructible : le 1er appui ne doit ni passer ni montrer la bulle")
	board._on_pass_pressed()
	_check(board._warn == null and _sig() != s0, "PASS TURN sans salle constructible : le 2e appui doit passer")
	await _new_game()
	board.set_process(false)
	var G: Dictionary = gm.G
	var me: Dictionary = G["players"][0]
	var ki := _take_spell("BMA049") # Kobold Strike : sans cible, jouable en construction -> fenetre de sorts apres ma construction
	board.refresh()
	var built := false
	var hand: Array = me["hand"]
	for i in hand.size():
		if (hand[i] as Dictionary).get("isRoom", false) and gm.can_build_room_at(0, i, (me["dungeon"] as Array).size()):
			board._on_hand_card_clicked(i, hand[i])
			if not board._tgt.is_empty(): # plusieurs emplacements possibles : la 1re entree est l'emplacement libre
				(board._tgt["entries"][0]["cb"] as Callable).call()
			built = true
			break
	if not _check(built, "DONE : aucune salle construisible"):
		return
	await get_tree().process_frame
	# APK : poser la salle ne finit pas le tour ; le bouton DONE! le finit, et le joueur peut encore jouer un sort avant
	if _check(not gm.G.has("buildWindow") and ki >= 0 and gm.active_player() == 0 and int(me.get("buildsThisTurn", 0)) == 1, "DONE : la pose a rendu la main (ou ouvert la fenetre)"):
		var tex_done: Texture2D = board._tex(board.TEX_DONE)
		_check(board.btn_pass.is_visible_in_tree() and (board.btn_pass as TextureButton).texture_normal == tex_done, "DONE : le bouton doit etre DONE! apres ma pose")
		_check(gm.legal_moves(0).any(func(m): return m["type"] == "playSpell") and gm.legal_moves(0).any(func(m): return m["type"] == "passBuild") and not gm.legal_moves(0).any(func(m): return m["type"] == "buildRoom"), "DONE : sorts et DONE seulement apres la pose")
		var s1 := _sig()
		board._on_pass_pressed()
		_check(board._warn == null and _sig() != s1 and (gm.active_player() != 0 or gm.G.has("buildWindow") or str(gm.G["phase"]) != "build"), "DONE : le bouton DONE! ne termine pas le tour")
		if gm.G.has("buildWindow"): # l'IA construit apres moi : fenetre de sorts avant la revelation, un 2e DONE! la ferme
			# (l'IA y joue aussi : un sort ou une capacite de sa part ouvre une Spell Battle / un choix a resoudre avant que DONE! ne ferme la fenetre)
			for _k in 12:
				if not gm.G.has("buildWindow"):
					break
				s1 = _sig()
				board._on_pass_pressed()
				board._process(0.6)
				await get_tree().process_frame
			_check(not gm.G.has("buildWindow"), "DONE : le bouton DONE! ne referme pas la fenetre")
		_cov("done_button")

## Corrections de relecture : reprise d'une pose (pas de pioche animee), cle PASS TURN par siege, pioche coupee au changement de siege,
## RULES en ColorFade (la visionneuse reste sous le fondu), nouvel ordre de transition refuse pendant un fondu et voile qui bloque les clics.
func _check_review_fixes() -> void:
	_tag = "[review]"
	await _new_game()
	board.set_process(false)
	board.skip_animations = false # la pioche animee est coupee en mode sans animation : elle doit l'etre ici aussi pour la reprise
	board.refresh()
	var me: Dictionary = gm.G["players"][0]
	var hand: Array = me["hand"]
	var bi := -1
	for i in hand.size():
		if (hand[i] as Dictionary).get("isRoom", false) and gm.can_build_room_at(0, i, (me["dungeon"] as Array).size()):
			bi = i
			break
	if _check(bi >= 0, "reprise : aucune salle construisible"):
		board._on_hand_card_clicked(bi, hand[bi])
		if not board._tgt.is_empty():
			(board._tgt["entries"][0]["cb"] as Callable).call()
		await get_tree().process_frame
		var und: Array = gm.legal_moves(0).filter(func(m): return m["type"] == "undoBuild")
		if _check(not und.is_empty(), "reprise : pas de coup undoBuild apres la pose"):
			var n0 := (me["hand"] as Array).size()
			board._on_slot_activate(int((und[0]["args"] as Array)[0]))
			await get_tree().process_frame
			_check((me["hand"] as Array).size() == n0 + 1, "reprise : la salle n'est pas revenue en main")
			_check(board._draw_hide.is_empty() and get_tree().get_nodes_in_group("drawn_card").is_empty(), "reprise : la salle reprise ne doit pas etre animee comme une pioche")
			var hidden := _hand_hidden()
			_check(hidden == 0, "reprise : %d carte(s) de la main cachee(s) (salle reprise injouable)" % hidden)
			_cov("undo_not_drawn")
		# vraie pioche : carte cachee le temps du vol, rendue par _draw_clear
		(me["hand"] as Array).append(CardDB.rooms[0].duplicate(true))
		board.refresh()
		_check(not board._draw_hide.is_empty() and not get_tree().get_nodes_in_group("drawn_card").is_empty(), "pioche : aucune animation pour une vraie carte tiree")
		board._draw_clear()
		board.refresh()
		await get_tree().process_frame
		_check(board._draw_hide.is_empty() and _hand_hidden() == 0, "pioche coupee : la main doit etre entierement visible")
		_cov("draw_clear")
	# PASS TURN : le 1er appui d'un siege leve son drapeau, quel que soit celui de l'autre siege
	await _new_game()
	board.set_process(false)
	board._on_pass_pressed()
	var k0: String = board._pass_raised_key
	gm.G["players"][1]["buildsThisTurn"] = 0 # siege 2 (pass and play) : pas encore construit, donc mode PASS TURN
	board.view_pid = 1
	board._sync_slot_pids()
	board._on_pass_pressed()
	_check(k0 != "" and board._pass_raised_key != k0 and board._pass_raised_key.begins_with("1/"), "PASS TURN : la cle du drapeau doit dependre du siege (%s puis %s)" % [k0, board._pass_raised_key])
	_cov("pass_key_seat")
	# RULES (menu) : la visionneuse reste a l'ecran sous le voile jusqu'au changement d'ecran
	await _teardown()
	var main = load("res://godot/scenes/Main.tscn").instantiate()
	add_child(main)
	await _wait(0.3)
	main.show_rules()
	await get_tree().process_frame
	var rv = main.get_children().filter(func(c): return c is RulesViewer)
	if _check(rv.size() == 1, "RULES : visionneuse absente"):
		(rv[0] as RulesViewer).close_viewer()
		await _wait(0.2)
		_check(main.is_fading() and is_instance_valid(rv[0]) and not rv[0].is_queued_for_deletion(), "RULES : la visionneuse doit rester a l'ecran pendant le fondu")
		var calls := [0]
		main.go(func(): calls[0] += 1)
		var veil: Control = main._fade_layer.get_child(0)
		_check(main._fade_layer.get_child_count() == 1 and veil.mouse_filter == Control.MOUSE_FILTER_STOP, "transition : un go() pendant un fondu doit etre refuse, le voile bloque les clics")
		await _nav(main)
		_check(calls[0] == 0, "transition : l'ordre recu pendant le fondu a ete execute")
		_check(not is_instance_valid(rv[0]) or rv[0].is_queued_for_deletion(), "RULES : la visionneuse n'est pas liberee apres le fondu")
		_cov("rules_fade")
	# W-19 : apres TAP TO START, un seul clic sur MULTIPLAYER pendant l'eclaircie du fondu doit ouvrir l'ecran multijoueur
	main.show_title()
	await _wait(0.1)
	await _click_at(Vector2(960, 540))
	await _wait(0.75) # 2e moitie du fondu (0,5 -> 1,0 s) : le menu est visible, le voile ne doit plus bloquer
	var mp: Control = null
	for c in main.get_children():
		if c is TextureButton and (c as TextureButton).get_children().any(func(k): return k is Label and (k as Label).text == "MULTIPLAYER"):
			mp = c
	if _check(mp != null and main._fade_layer.get_child_count() == 1, "W-19 : menu absent apres TAP TO START"):
		_check((main._fade_layer.get_child(0) as Control).mouse_filter == Control.MOUSE_FILTER_IGNORE, "W-19 : le voile bloque encore les clics dans l'eclaircie")
		await _click_at(mp.get_global_rect().get_center())
		await _nav(main)
		_check(main.find_child("PLAY ONLINE", true, false) != null, "W-19 : un seul clic sur MULTIPLAYER n'ouvre pas l'ecran multijoueur")
	main.queue_free()
	await get_tree().process_frame

## Cartes de la main du plateau cachees (visible = false).
func _hand_hidden() -> int:
	var n := 0
	for c in board.hand_layer.get_children():
		if not (c as CanvasItem).visible:
			n += 1
	return n

## Galerie de cartes : 5 onglets (BOSS / ROOM / SPELL / HERO / EPIC HERO), grille, paquets de l'APK (+ wiki selon l'option), fermeture ;
## ouverte depuis le menu en jeu et depuis OPTIONS du menu principal.
func _check_gallery() -> void:
	_tag = "[gallery]"
	await _new_game()
	board.set_process(false)
	var ext: bool = bool(Profile.load_settings().get("extensions", false))
	var allowed: Array = ["base", "players-choice", "hidden-heroes"] # APK : les Tools ne sont pas dans la galerie (ils s'y ajoutent avec la case wiki : jouables derriere elle)
	if ext:
		allowed.append_array(["next-level", "crash-landing", "minibosses", "tools", "iod", "players-choice-wiki"])
	board._on_menu_pressed()
	await get_tree().process_frame
	var gal_btn: Button = null
	for b in _buttons(board._popup):
		if (b as Button).text == "CARD GALLERY":
			gal_btn = b
	if not _check(gal_btn != null, "galerie : bouton CARD GALLERY absent du menu en jeu"):
		return
	gal_btn.pressed.emit()
	await get_tree().process_frame
	var gal = board._popup.find_children("*", "Control", true, false).filter(func(c): return c.get_script() != null and str(c.get_script().resource_path).ends_with("CardGallery.gd"))
	if not _check(gal.size() == 1, "galerie : non ouverte depuis le menu en jeu (%d)" % gal.size()):
		return
	var g = gal[0]
	var want_titles := ["BOSS CARDS", "ROOM CARDS", "SPELL CARDS", "HERO CARDS", "EPIC HERO CARDS"]
	_check(g.tab_buttons.size() == 5, "galerie : %d onglets (5 attendus)" % g.tab_buttons.size())
	var sources: Array = [CardDB.bosses, CardDB.rooms, CardDB.spells, CardDB.heroes, CardDB.heroes]
	for t in 5:
		g.select_tab(t)
		await get_tree().process_frame
		_check(g.title_label.text == want_titles[t], "galerie : titre « %s » au lieu de %s" % [g.title_label.text, want_titles[t]])
		var want := 0
		var want_tiles := 0 # Room/Spell : une tuile par exemplaire si une image « b » (art alternatif) existe
		for c in sources[t]:
			var d: Dictionary = c
			if not (str(d.get("set", "base")) in allowed) or str(d.get("id", "")) in ["BMA023", "BMA033"]: # notInGameCards de l'APK
				continue
			if t >= 3 and bool(d.get("epic", false)) != (t == 4):
				continue
			want += 1
			var alt: bool = t in [1, 2] and ResourceLoader.exists("res://assets/apk_cards/base/%sb.webp" % str(d.get("id", "")).to_lower())
			want_tiles += int(d.get("quantity", 1)) if alt else 1
		_check(g.cards_shown == want and want > 0, "galerie : onglet %d : %d cartes pour %d attendues" % [t, g.cards_shown, want])
		var grid = g.scroll.get_node_or_null("Grid")
		_check(grid != null and grid.get_child_count() == want_tiles, "galerie : grille de %d tuiles pour %d" % [grid.get_child_count() if grid != null else -1, want_tiles])
	g.select_tab(0)
	var order: Array = g.cards_for(0).map(func(c): return str(c["id"]))
	_check(order.size() > 1 and order[0] == "KSA007" and order[1] == "KSA006", "galerie : ordre APK (CardNumber decroissant), Elicon puis Jarin en tete : %s" % [order.slice(0, 3)])
	_check(g.tab_buttons[0].get_node_or_null("Sel") == null, "galerie : l'onglet BOSS n'a pas de cadre jaune a l'ouverture (capture APK)")
	g.select_tab(2, true) # onglet touche : cadre jaune (ScrollItemComponent) ; select_tab(0) ci-dessus ne le portait pas
	_check(g.tab_buttons[2].get_node_or_null("Sel") != null, "galerie : l'onglet touche prend le cadre jaune")
	g.select_tab(0)
	var tile = g.scroll.get_node("Grid").get_child(0)
	var tile2 = g.scroll.get_node("Grid").get_child(1)
	g._select_tile(tile)
	g._select_tile(tile2)
	_check(tile2.get_node_or_null("Sel") != null and tile.get_node_or_null("Sel") == null, "galerie : seule la derniere tuile touchee porte le cadre jaune (0,85 / 0,8)")
	g.show_detail(tile.get_meta("card"), tile.texture)
	_check(g._detail != null, "galerie : le detail d'une carte ne s'ouvre pas")
	g.close_gallery() # ferme d'abord le detail
	_check(g._detail == null and is_instance_valid(g), "galerie : la fermeture du detail ne doit pas fermer la galerie")
	var closed := [false]
	g.closed.connect(func(): closed[0] = true)
	g.get_node("Back").pressed.emit()
	await get_tree().process_frame
	_check(closed[0], "galerie : la fleche de retour ne ferme pas")
	_cov("gallery")
	board._popup_close()
	# depuis OPTIONS du menu principal
	var main = load("res://godot/scenes/Main.tscn").instantiate()
	add_child(main)
	await _wait(0.2)
	main.show_options()
	await get_tree().process_frame
	var ob = main.find_child("CardGallery", true, false)
	if _check(ob != null, "galerie : bouton CARD GALLERY absent de OPTIONS"):
		(ob as Button).pressed.emit()
		await _nav(main)
		_check(main.get_children().any(func(c): return c.get_script() != null and str(c.get_script().resource_path).ends_with("CardGallery.gd")), "galerie : non ouverte depuis OPTIONS")
		_cov("gallery_options")
	main.queue_free()
	await get_tree().process_frame

## OPTIONS > CREDITS (CreditsScreen.gd ; CreditsScene.cs, CreditRollBehavior.cs) : 4e bouton d'OPTIONS, textes de credits.json, logo immobile 8,8 s puis qui monte (100 px/s),
## pied arrete a y = 400, glisser, retour en fondu noir vers OPTIONS. Le temps est avance a la main (_process(dt)) : la scene ne tourne pas seule.
func _check_credits() -> void:
	_tag = "[credits]"
	await _teardown()
	var CS = load("res://godot/scripts/CreditsScreen.gd")
	var main = load("res://godot/scenes/Main.tscn").instantiate()
	add_child(main)
	await _wait(0.2)
	main.show_options()
	await get_tree().process_frame
	var cb = main.find_child("Credits", true, false)
	var gal = main.find_child("CardGallery", true, false)
	# 4 boutons empiles au centre x 960, y 356,4 + 162 n (OptionsScene.cs:55-103) ; les reglages sont dans SETTINGS
	var stack: Array = ["Tutorial", "Settings", "CardGallery", "Credits"].map(func(n): return main.find_child(n, true, false))
	_check(stack.all(func(b): return b is Button and is_equal_approx(b.position.x + b.size.x / 2.0, 960.0)), "options : les 4 boutons ne sont pas centres sur x = 960")
	_check(stack.all(func(b): return b is Button) and is_equal_approx(stack[0].position.y + stack[0].size.y / 2.0, 356.0) and is_equal_approx(stack[3].position.y - stack[0].position.y, 486.0), "options : empilement TUTORIAL / SETTINGS / CARD GALLERY / CREDITS hors APK")
	_check(main.find_children("*", "Label", true, false).all(func(l): return (l as Label).text != "MUSIC"), "options : MUSIC doit etre dans SETTINGS")
	if stack[1] is Button:
		(stack[1] as Button).pressed.emit()
		await _nav(main)
		_check(main.find_children("*", "Label", true, false).filter(func(l): return (l as Label).text in ["MUSIC", "SOUND", "GAME SPEED"]).size() == 3, "settings : MUSIC / SOUND / GAME SPEED absents")
		main.show_options()
		await get_tree().process_frame
		cb = main.find_child("Credits", true, false)
		gal = main.find_child("CardGallery", true, false)
	if not _check(cb is Button and (cb as Button).text == "CREDITS" and gal != null, "credits : bouton CREDITS absent d'OPTIONS"):
		main.queue_free()
		return
	_check(is_equal_approx(cb.position.y - gal.position.y, 162.0) and is_equal_approx(cb.position.x, gal.position.x), "credits : CREDITS pas 162 px sous CARD GALLERY (%s / %s)" % [cb.position, gal.position]) # OptionsScene.cs:55-57
	_check(Rect2(0, 0, 1920, 1080).encloses(Rect2(cb.position, cb.size)), "credits : bouton hors ecran")
	for c in main.find_children("*", "Control", true, false):
		if c != cb and (c is Button or c is CheckBox or c is LineEdit) and (c as Control).visible:
			_check(not (c as Control).get_global_rect().intersects(Rect2(cb.position, cb.size)), "credits : le bouton CREDITS chevauche %s" % c.name)
	cb.pressed.emit()
	await get_tree().process_frame
	_check(not main.is_fading(), "credits : l'ouverture est un Push sans transition")
	var cs = main.find_child("CreditsScreen", true, false)
	if not _check(cs != null, "credits : ecran non ouvert"):
		main.queue_free()
		return
	cs.set_process(false)
	cs.roll.node.position.y = 1180.0 # une image s'est ecoulee avant set_process(false) : retour a l'etat de depart
	cs.footer.node.position.y = 4620.0
	cs.logo.delay = 880.0
	_check(not cb.visible and not gal.visible, "credits : les boutons d'OPTIONS restent visibles")
	await _wait(0.45)
	_check(is_equal_approx(cs.veil.color.a, 0.7) and cs.veil.color.r == 0.0, "credits : voile noir alpha 0,7 apres 0,3 s : %s" % cs.veil.color)
	_check(cs.veil.get_global_rect() == Rect2(0, 0, 1920, 1080) and cs.get_global_rect() == Rect2(0, 0, 1920, 1080), "credits : le voile ne couvre pas l'ecran (%s)" % cs.veil.get_global_rect())
	# textes : un libelle par H1 / H2 / nom non vide de credits.json (cles a casse variable)
	var data: Dictionary = CS.load_data()
	var n_h1 := 0
	var n_h2 := 0
	var n_names := 0
	for e in CS.ci(data, "Element"):
		if CS.ci(e, "H1") != null:
			n_h1 += 1
		var paras = CS.ci(e, "Paragraph")
		for p in (paras if paras is Array else []):
			if CS.ci(p, "H2") != null:
				n_h2 += 1
			var nms = CS.ci(p, "Names")
			for n in (nms if nms is Array else []):
				if str(n) != "":
					n_names += 1
	var labels: Array = cs.find_children("*", "Label", true, false)
	var by_kind := {"h1": [], "h2": [], "name": []}
	for l in labels:
		(by_kind[str(l.get_meta("kind"))] as Array).append(l)
	_check(n_h1 == 3 and n_h2 == 16 and n_names == 45, "credits : donnees inattendues (h1 %d, h2 %d, noms %d)" % [n_h1, n_h2, n_names])
	_check((by_kind["h1"] as Array).size() == n_h1 and (by_kind["h2"] as Array).size() == n_h2 + 1 and (by_kind["name"] as Array).size() == n_names, "credits : %d H1 / %d H2 (+ pied) / %d noms affiches" % [(by_kind["h1"] as Array).size(), (by_kind["h2"] as Array).size(), (by_kind["name"] as Array).size()])
	var all_up := true
	for l in labels:
		all_up = all_up and (l as Label).text == (l as Label).text.to_upper() and (l as Label).text != ""
	_check(all_up, "credits : texte non MAJUSCULE ou vide")
	var powered: Label = cs.footer.node.find_children("*", "Label", true, false)[0]
	_check(powered.text == "POWERED BY" and powered.get_theme_color("font_color") == Color("bfca7a"), "credits : pied sans POWERED BY (%s)" % powered.text)
	for l in labels: # rien ne deborde en largeur ; axe des noms 1090 x 1,3 / 2 + 240 = 948,5 (frame APK : ~949)
		var r := Rect2((l as Label).position, (l as Label).size)
		_check(r.position.x >= 0.0 and r.end.x <= 1920.0, "credits : %s deborde en largeur %s" % [(l as Label).text, r])
		if l.get_meta("kind") != "h1":
			_check(is_equal_approx(r.position.x + r.size.x / 2.0, 948.5), "credits : axe de %s en %f (948,5 attendu)" % [(l as Label).text, r.position.x + r.size.x / 2.0])
	# defilement : le rouleau part tout de suite de y = 1180, le logo attend 8,8 s, le pied part de 4620
	_check(is_equal_approx(cs.logo.node.position.y, 170.0) and is_equal_approx(cs.roll.node.position.y, 1180.0) and is_equal_approx(cs.footer.node.position.y, 4620.0), "credits : positions de depart (logo %f, rouleau %f, pied %f)" % [cs.logo.node.position.y, cs.roll.node.position.y, cs.footer.node.position.y])
	for i in 80:
		cs._process(0.1) # 8,0 s
	_check(is_equal_approx(cs.logo.node.position.y, 170.0), "credits : le logo bouge avant 8,8 s (%f)" % cs.logo.node.position.y)
	_check(absf(cs.roll.node.position.y - (1180.0 - 800.0)) < 0.01 and absf(cs.footer.node.position.y - (4620.0 - 800.0)) < 0.01, "credits : le rouleau / le pied ne montent pas a 100 px/s (%f, %f)" % [cs.roll.node.position.y, cs.footer.node.position.y])
	_check(not cs.touch_on, "credits : glisser actif avant que le logo monte")
	for i in 15:
		cs._process(0.1) # 9,5 s
	_check(cs.logo.node.position.y < 170.0 and cs.logo.node.position.y > 90.0 and cs.touch_on, "credits : le logo ne monte pas apres 8,8 s (%f, glisser %s)" % [cs.logo.node.position.y, str(cs.touch_on)])
	# glisser : vers le haut = les trois rouleaux montent de ce delta ; vers le bas seulement si le logo est sous y = 150 ; l'appui fige le defilement
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	cs._gui_input(press)
	var mv := InputEventMouseMotion.new()
	var ry0: float = cs.roll.node.position.y
	mv.relative = Vector2(0, -30)
	cs._gui_input(mv)
	_check(absf(cs.roll.node.position.y - (ry0 - 30.0)) < 0.01, "credits : glisser vers le haut de 30 px : rouleau %f -> %f" % [ry0, cs.roll.node.position.y])
	cs._process(0.1)
	_check(absf(cs.roll.node.position.y - (ry0 - 30.0)) < 0.01, "credits : le defilement ne se fige pas pendant l'appui")
	mv.relative = Vector2(0, 20)
	cs._gui_input(mv)
	_check(absf(cs.roll.node.position.y - (ry0 - 10.0)) < 0.01, "credits : glisser vers le bas refuse alors que le logo est sous 150 (%f)" % cs.logo.node.position.y)
	var ly: float = cs.logo.node.position.y
	cs.logo.node.position.y = 200.0
	var ry1: float = cs.roll.node.position.y
	cs._gui_input(mv)
	_check(is_equal_approx(cs.roll.node.position.y, ry1), "credits : glisser vers le bas accepte alors que le logo est au-dessus de 150")
	cs.logo.node.position.y = ly
	press.pressed = false
	cs._gui_input(press)
	var ry2: float = cs.roll.node.position.y
	cs._process(0.1)
	_check(absf(cs.roll.node.position.y - (ry2 - 10.0)) < 0.01, "credits : le defilement ne repart pas au relachement")
	# le pied s'arrete a MinY = 400 (au plus un pas de depassement), le glisser est alors coupe
	for i in 700:
		if cs.footer.reached:
			break
		cs._process(0.1)
	var fy: float = cs.footer.node.position.y
	_check(cs.footer.reached and fy <= 400.0 and fy > 389.0 and not cs.touch_on, "credits : pied non arrete a 400 (y=%f, touche=%s)" % [fy, str(cs.touch_on)])
	for i in 20:
		cs._process(0.1)
	_check(is_equal_approx(cs.footer.node.position.y, fy), "credits : le pied bouge apres MinY")
	_cov("credits")
	# retour : fondu noir 1,0 s vers OPTIONS reconstruit
	cs.get_node("Back").pressed.emit()
	await _nav(main)
	_check(main.find_child("CreditsScreen", true, false) == null, "credits : ecran encore la apres le retour")
	var btns: Array = main.find_children("*", "Button", true, false).filter(func(b): return (b as Button).text == "CREDITS" or (b as Button).text == "CARD GALLERY") # les noeuds de l'ancien ecran portent encore le nom : le nouveau devient « Credits2 »
	_check(btns.size() == 2 and btns.all(func(b): return (b as Button).visible), "credits : OPTIONS n'est pas restaure (%d boutons visibles)" % btns.size())
	_cov("credits_back")
	main.queue_free()
	await get_tree().process_frame

## Ecrans multijoueur de l'APK (OnlineMenus.gd) : MultiplayerScene, ChangeNameAvatar, MenuOnline, WithFriends, boite d'erreur, salle d'attente,
## PASS AND PLAY, compte a rebours. Le profil reel (user://profile.cfg) est sauvegarde puis remis en place.
func _texts_of(root: Node) -> Array:
	return root.find_children("*", "Label", true, false).map(func(l): return (l as Label).text)

func _tb_by_texture(root: Node, suffix: String) -> TextureButton:
	for b in root.find_children("*", "TextureButton", true, false):
		var t = (b as TextureButton).texture_normal
		if t != null and str(t.resource_path).ends_with(suffix):
			return b
	return null

## Boutons a libelle (bg_bt_multi) de l'ecran courant, par texte.
func _label_buttons(root: Node) -> Dictionary:
	var out := {}
	for b in root.find_children("*", "TextureButton", true, false):
		if b.get_child_count() > 0 and b.get_child(0) is Label and (b.get_child(0) as Label).name == "Label":
			out[(b.get_child(0) as Label).text] = b
	return out

func _check_online_menus() -> void:
	_tag = "[online-menus]"
	await _teardown()
	var Profile = load("res://godot/scripts/Profile.gd")
	var cfg_path: String = ProjectSettings.globalize_path(Profile.SAVE_PATH)
	var backup := PackedByteArray()
	if FileAccess.file_exists(cfg_path):
		backup = FileAccess.get_file_as_bytes(cfg_path)
		DirAccess.remove_absolute(cfg_path)
	var main = load("res://godot/scenes/Main.tscn").instantiate()
	add_child(main)
	await _wait(0.3)
	# MultiplayerScene : deux boutons avec eventail de bosses
	main.show_multi()
	await _wait(0.2)
	var po = main.find_child("PLAY ONLINE", true, false)
	var pp = main.find_child("PLAY WITH FRIENDS", true, false)
	if _check(po != null and pp != null, "multi : boutons PLAY ONLINE / PLAY WITH FRIENDS"):
		_check(po.get_children().filter(func(c): return c is TextureRect).size() == 4 and pp.get_children().filter(func(c): return c is TextureRect).size() == 2, "multi : eventails de 4 et 2 bosses")
		_check(is_equal_approx(po.position.x + 252.0, 1260.0) and is_equal_approx(pp.position.x + 252.0, 660.0) and is_equal_approx(po.position.y + 200.0, 540.0), "multi : boutons centres en (1260,540) et (660,540)")
		po.button_down.emit()
		_check((po.get_node("Title") as Label).get_theme_color("font_color") == Color("cdb15f"), "multi : titre dore pendant l'appui")
		po.button_up.emit()
		_check((po.get_node("Title") as Label).get_theme_color("font_color") == Color.WHITE, "multi : titre blanc au relachement")
		# sans pseudo enregistre : ChangeNameAvatarScene d'abord, sans fleche de retour
		po.pressed.emit()
		await _nav(main)
		var scroll = main.find_child("AvatarScroll", true, false)
		if _check(scroll != null, "profil : selecteur d'avatars absent au premier passage"):
			_check(scroll.ids.size() == 9 and not scroll.ids.has("avatar_none"), "profil : 9 avatars reguliers, pas d'avatar_none")
			_check(_tb_by_texture(main, "back_bt.webp") == null, "profil : pas de fleche de retour au premier passage")
			_check(str(main.profile["name"]).begins_with("player_") and str(main.profile["name"]).length() == 11, "profil : pseudo par defaut player_xxxx : %s" % main.profile["name"])
			_check(_texts_of(main).has("INSERT USERNAME") and _texts_of(main).has("SELECT AVATAR"), "profil : libelles APK")
			var old_av := str(scroll.selected)
			scroll.select("avatar_gorgona" if old_av != "avatar_gorgona" else "avatar_croak")
			await _wait(0.45)
			var new_av := str(scroll.selected)
			_check(is_equal_approx((scroll._items[new_av] as Control).scale.x, 0.9) and is_equal_approx((scroll._items[old_av] as Control).scale.x, 0.7), "profil : avatar choisi a l'echelle 0,9, l'ancien a 0,7")
			var edit: LineEdit = main.find_child("Entry", true, false)
			edit.text = "Zed"
			_tb_by_texture(main, "ok_bt.webp").pressed.emit()
			await _wait(0.2)
			var saved: Dictionary = Profile.load_profile()
			_check(saved["name"] == "Zed" and saved["avatar"] == new_av and Profile.has_profile(), "profil : OK n'enregistre pas le profil : %s" % str(saved))
			_cov("menus_profile")
	# MenuOnlineScene : WORLDWIDE (liste des salons publics), CHANGE USER/AVATAR (avec fleche), WITH FRIENDS
	var lb := _label_buttons(main)
	if _check(lb.has("WORLDWIDE") and lb.has("WITH FRIENDS") and lb.has("CHANGE USER/AVATAR"), "menu en ligne : boutons %s" % str(lb.keys())):
		var b0: TextureButton = lb["WORLDWIDE"]
		_check(is_equal_approx(b0.position.x + 309.5, 960.0) and is_equal_approx(b0.position.y + 88.5, 388.8), "menu en ligne : WORLDWIDE en (960, 388,8)")
		main.server_host = "ws://127.0.0.1:1" # aucun serveur : la liste doit le dire (pas de boite d'erreur APK)
		b0.pressed.emit()
		await _nav(main)
		_check(main.find_child("MessageBox", true, false) == null, "WORLDWIDE : la boite « Unable to join public rooms » ne doit plus s'ouvrir")
		var pt := _texts_of(main)
		_check(pt.has("PUBLIC GAMES") and pt.has("HOST") and pt.has("FREE") and pt.has("PACKS") and main.find_child("CreatePublic", true, false) != null, "WORLDWIDE : liste publique absente %s" % str(pt))
		_check(_tb_by_texture(main, "back_bt.webp") != null, "WORLDWIDE : fleche de retour absente")
		await _wait(OnlineMenus.PUBLIC_UNREACHABLE_S + 1.0)
		_check(_texts_of(main).has("UNABLE TO REACH THE SERVER"), "WORLDWIDE : serveur injoignable non signale : %s" % str(_texts_of(main)))
		_cov("menus_public_unreachable")
		_tb_by_texture(main, "back_bt.webp").pressed.emit()
		await _wait(0.2)
		lb = _label_buttons(main)
		_check(lb.has("WORLDWIDE") and not main.online._watching and not main.online.connected, "WORLDWIDE : la fleche ne ramene pas au menu en ligne / la liaison reste ouverte")
		lb["CHANGE USER/AVATAR"].pressed.emit()
		await _nav(main)
		_check(_tb_by_texture(main, "back_bt.webp") != null and (main.find_child("Entry", true, false) as LineEdit).text == "Zed", "profil (depuis le menu) : fleche de retour et pseudo enregistre")
		_tb_by_texture(main, "back_bt.webp").pressed.emit()
		await _wait(0.2)
		_label_buttons(main)["WITH FRIENDS"].pressed.emit()
	await _nav(main)
	# WithFriendsOnlineScene : NEW GAME / ROOM CODE, saisie du code qui apparait en fondu
	var wf := _label_buttons(main)
	if _check(wf.has("NEW GAME") and wf.has("ROOM CODE"), "amis : boutons %s" % str(wf.keys())):
		var entry: LineEdit = main.find_child("Entry", true, false)
		_check(entry != null and entry.modulate.a == 0.0 and not entry.editable, "amis : la saisie du code est cachee au depart")
		wf["ROOM CODE"].pressed.emit()
		await _wait(0.7)
		_check(entry.modulate.a > 0.99 and entry.editable and entry.placeholder_text == "INSERT ROOM CODE", "amis : ROOM CODE ne fait pas apparaitre la saisie")
		entry.text = "ab"
		entry.text_changed.emit("ab")
		_check(entry.text == "AB", "amis : code en majuscules")
		_tb_by_texture(main, "ok_bt.webp").pressed.emit() # 2 lettres : « Invalid Code » sans reseau
		await get_tree().process_frame
		var mb2 = main.find_child("MessageBox", true, false)
		_check(mb2 != null and _texts_of(mb2).has("Invalid Code"), "amis : code invalide : boite « Invalid Code »")
		if mb2 != null:
			(mb2.get_node("Ok") as TextureButton).pressed.emit()
			await get_tree().process_frame
		wf["NEW GAME"].pressed.emit()
		await _nav(main)
		_check(_texts_of(main).has("HOW MANY PLAYERS?"), "amis : NEW GAME n'ouvre pas le choix du nombre de joueurs")
		_cov("menus_friends")
	# Tools of Hero-Kind : les Objets ne se jouent que derriere la case wiki (sans elle la tuile est grisee, « tools » reste inerte pour l'APK)
	var saved_decks: Array = main.apk_decks.duplicate()
	var saved_ext: bool = main.use_extensions
	main.apk_decks = ["tools"]
	main.use_extensions = false
	_check(not (main._active_sets() as Array).has("tools") and not (main._active_sets() as Array).has("tools-wiki"), "case wiki decochee : la tuile Tools n'ajoute aucun paquet")
	main.use_extensions = true
	_check((main._active_sets() as Array).has("tools") and (main._active_sets() as Array).has("tools-wiki"), "case wiki cochee : Tools ajoute tools + tools-wiki")
	# Implements of Destruction (iod) et cartes wiki du Player's Choice : meme regle, derriere la case wiki
	main.apk_decks = ["players-choice"]
	main.use_extensions = false
	_check(not (main._active_sets() as Array).has("players-choice-wiki"), "case wiki decochee : Player's Choice n'ajoute pas players-choice-wiki")
	main.use_extensions = true
	_check((main._active_sets() as Array).has("players-choice-wiki"), "case wiki cochee : Player's Choice ajoute players-choice-wiki (6 cartes manquantes)")
	main.apk_decks = ["iod"]
	_check((main._active_sets() as Array).has("iod"), "tuile Implements of Destruction : ajoute le paquet iod")
	main.apk_decks = saved_decks
	main.use_extensions = saved_ext
	# PLAY WITH FRIENDS (remplace PASS AND PLAY) : profil existant -> WITH FRIENDS (NEW GAME / ROOM CODE) ; plus de partie a sieges tous humains sur un ecran
	main.show_multi()
	await _wait(0.2)
	_check(main.find_child("PASS AND PLAY", true, false) == null, "multi : PASS AND PLAY doit avoir disparu")
	main.find_child("PLAY WITH FRIENDS", true, false).pressed.emit()
	await _nav(main)
	_check(_texts_of(main).has("NEW GAME") and _texts_of(main).has("ROOM CODE"), "multi : PLAY WITH FRIENDS ouvre NEW GAME / ROOM CODE")
	_cov("menus_play_with_friends")
	main._clear()
	await get_tree().process_frame
	# salle d'attente : 4 lignes, hote en or, « WAITING... », OK pour l'hote seulement avec plus d'un humain
	var o = main.online
	o.match_id = "ABCD"
	o.player_id = 0
	o.is_host = true
	main.show_waiting()
	await get_tree().process_frame
	var seat := func(n, av, w, d): return {"name": n, "bot": false, "connected": true, "avatar": av, "wins": w, "defeats": d}
	var free := {"name": null, "bot": false, "connected": false, "avatar": "", "wins": 0, "defeats": 0}
	o.lobby_changed.emit({"status": "open", "numPlayers": 4, "host": 0, "seats": [seat.call("Alice", "avatar_croak", 3, 1), free, free, free]})
	var rows: Array = main.menus._rows
	if _check(rows.size() == 4, "salle : 4 lignes"):
		_check((rows[0]["name"] as Label).text == "Alice" and (rows[0]["wins"] as Label).text == "3" and (rows[0]["defeats"] as Label).text == "1", "salle : ligne de l'hote")
		_check((rows[1]["name"] as Label).text == "WAITING..." and ((rows[1]["avatar"] as TextureRect).texture as Texture2D).resource_path.ends_with("avatar_none.webp"), "salle : siege libre = WAITING... + avatar_none")
		_check(((rows[0]["avatar"] as TextureRect).texture as Texture2D).resource_path.ends_with("avatar_croak.webp"), "salle : avatar du joueur")
		_check((rows[0]["name"] as Label).get_theme_color("font_color") == Color("cdb15f") and (rows[1]["name"] as Label).get_theme_color("font_color") == Color.WHITE, "salle : ligne de l'hote en or")
		_check(main.menus._wait_ok.disabled and main.menus._wait_bots.visible, "salle : OK cache avec un seul humain, START WITH BOTS pour l'hote")
		o.lobby_changed.emit({"status": "open", "numPlayers": 4, "host": 0, "seats": [seat.call("Alice", "avatar_croak", 3, 1), seat.call("Bob", "avatar_robobo", 0, 2), free, free]})
		await _wait(0.4)
		_check((rows[1]["name"] as Label).text == "Bob" and not main.menus._wait_ok.disabled and main.menus._wait_ok.modulate.a > 0.99, "salle : OK pour l'hote avec 2 humains")
		o.is_host = false
		o.lobby_changed.emit({"status": "open", "numPlayers": 4, "host": 0, "seats": [seat.call("Alice", "avatar_croak", 3, 1), seat.call("Bob", "avatar_robobo", 0, 2), free, free]})
		_check(main.menus._wait_ok.disabled and not main.menus._wait_bots.visible, "salle : ni OK ni START WITH BOTS pour un invite")
	var wt := _texts_of(main)
	_check(wt.has("ROOM CODE:") and wt.has("ABCD") and wt.has("WAITING FRIENDS..."), "salle : code et titre")
	_cov("menus_waiting")
	# compte a rebours (CountDownEntity)
	var cd = load("res://godot/scripts/CountDown.gd").new(o)
	main.add_child(cd)
	o.current_G = {"gameOver": null, "turnDeadline": int(Time.get_unix_time_from_system() * 1000.0) + 7500}
	o.current_awaited = [0]
	o.clock_offset_ms = 0
	var rem: int = cd.remaining()
	_check(rem >= 7 and rem <= 8, "compte a rebours : %d s restantes pour mon siege" % rem)
	cd._process(0.0)
	await _wait(0.4)
	_check(cd._digits.text == str(rem) and cd.modulate.a > 0.99, "compte a rebours : chiffres et fondu")
	o.current_awaited = [1]
	_check(cd.remaining() == -1, "compte a rebours : cache quand ce n'est pas mon siege")
	o.current_awaited = [0]
	o.current_G["gameOver"] = {"winner": 0}
	_check(cd.remaining() == -1, "compte a rebours : cache en fin de partie")
	_cov("menus_countdown")
	o.current_G = {}
	o.match_id = ""
	o.is_host = false
	main.queue_free()
	await get_tree().process_frame
	DirAccess.remove_absolute(cfg_path)
	if backup.size() > 0:
		var f := FileAccess.open(cfg_path, FileAccess.WRITE)
		f.store_buffer(backup)
		f.close()

## WORLDWIDE contre un VRAI serveur (dans le processus) : la liste affiche le salon public cree par un autre client (titre, hote, sieges libres / total, packs),
## un salon prive n'y figure pas, JOIN rejoint la salle (salle d'attente), la fleche de la salle d'attente ramene a la liste, CREATE PUBLIC GAME cree un salon visible des autres.
func _check_public_lobby() -> void:
	_tag = "[public-lobby]"
	await _teardown()
	var sess_path: String = ProjectSettings.globalize_path(OnlineClient.SESSION_PATH)
	var sess_backup := PackedByteArray()
	if FileAccess.file_exists(sess_path):
		sess_backup = FileAccess.get_file_as_bytes(sess_path)
	var srv = Server.new()
	srv.auto_start = false
	srv.bot_delay_ms = 0
	srv.rooms_push_interval_ms = 50
	add_child(srv)
	var prng := RandomNumberGenerator.new()
	prng.randomize()
	var url := ""
	for _i in 20:
		var port := prng.randi_range(20000, 40000)
		if srv.start(port) == OK:
			url = "ws://127.0.0.1:%d" % port
			break
	if not _check(url != "", "lobby public : aucun port libre pour le serveur de test"):
		srv.queue_free()
		return
	var other := OnlineClient.new() # « un autre client » : l'hote du salon public
	other.host = url
	other.player_name = "Hosty"
	other.player_avatar = "avatar_croak"
	other.count_results = false
	add_child(other)
	var main = load("res://godot/scenes/Main.tscn").instantiate()
	add_child(main)
	await _wait(0.3)
	main.server_host = url
	main.profile = {"name": "Zed", "avatar": "avatar_gorgona"}
	main.online.count_results = false
	main.menus.show_online()
	await _wait(0.2)
	_label_buttons(main)["WORLDWIDE"].pressed.emit()
	await _nav(main)
	# liste vide : message clair, pas de ligne
	var empty_ok := await _wait_until(func(): return _texts_of(main).any(func(t): return str(t).begins_with("NO PUBLIC GAMES YET")), 5.0)
	_check(empty_ok and main.find_children("Room_*", "Control", true, false).is_empty(), "lobby public : liste vide non signalee %s" % str(_texts_of(main)))
	# un salon prive (jamais liste) puis un public cree par l'autre client
	var priv := OnlineClient.new()
	priv.host = url
	priv.player_name = "Secret"
	priv.count_results = false
	add_child(priv)
	_check(await priv.create_lobby(3, []), "lobby public : creation du salon prive")
	_check(await other.create_lobby(3, ["players-choice"], 0, true, "Duel du soir"), "lobby public : creation du salon public")
	var code: String = other.match_id
	var row_ok := await _wait_until(func(): return main.find_child("Room_" + code, true, false) != null, 5.0)
	if _check(row_ok, "lobby public : le salon public n'apparait pas dans la liste (push `rooms`)"):
		var row = main.find_child("Room_" + code, true, false)
		var rt := _texts_of(row)
		_check(rt.has("Duel du soir") and rt.has("Hosty") and rt.has("2/3") and rt.has("PC") and row.find_child("Join", true, false) != null, "lobby public : ligne %s" % str(rt))
		_check(main.find_child("Room_" + priv.match_id, true, false) == null, "lobby public : un salon prive est liste")
		_check(not (main.find_child("Status", true, false) as Label).visible, "lobby public : message « liste vide » encore affiche")
		# filtre : un texte absent masque la ligne (message dedie), le titre (sans casse) la garde
		var flt := main.find_child("Filter", true, false) as LineEdit
		flt.text = "zzz"
		flt.text_changed.emit("zzz")
		await _wait(0.1)
		_check(main.find_child("Room_" + code, true, false) == null and (main.find_child("Status", true, false) as Label).visible and (main.find_child("Status", true, false) as Label).text == "NO MATCHING GAMES", "lobby public : le filtre ne masque pas la ligne")
		flt.text = "DUEL"
		flt.text_changed.emit("DUEL")
		await _wait(0.1)
		_check(main.find_child("Room_" + code, true, false) != null and not (main.find_child("Status", true, false) as Label).visible, "lobby public : le filtre sur le titre doit garder la ligne")
		flt.text = ""
		flt.text_changed.emit("")
		row = main.find_child("Room_" + code, true, false)
		_cov("menus_public_filter")
		# JOIN : rejoint la salle publique d'un autre client -> salle d'attente existante
		(row.find_child("Join", true, false) as TextureButton).pressed.emit()
		var o = main.online
		await _wait_until(func(): return o.match_id == code, 5.0)
		await _nav(main)
		_check(o.match_id == code and o.player_id == 1 and bool(srv.get_room(code).seats[1]["taken"]) and str(srv.get_room(code).seats[1]["name"]) == "Zed", "lobby public : JOIN n'a pas pris le siege 1 de la salle de l'autre client (%s)" % o.match_id)
		var wt := _texts_of(main)
		_check(wt.has("Duel du soir") and wt.has(code), "lobby public : JOIN n'ouvre pas la salle d'attente %s" % str(wt))
		_check(await _wait_until(func(): return main.menus._rows.size() == 4 and (main.menus._rows[0]["name"] as Label).text == "Hosty" and (main.menus._rows[1]["name"] as Label).text == "Zed", 5.0), "lobby public : salle d'attente sans l'hote et moi")
		_cov("menus_public_join")
		# fleche de la salle d'attente : retour a la liste (pas a WITH FRIENDS), siege libere
		_tb_by_texture(main, "back_bt.webp").pressed.emit()
		await _wait(0.3)
		_check(main.find_child("CreatePublic", true, false) != null and _texts_of(main).has("PUBLIC GAMES"), "lobby public : la fleche de la salle d'attente ne ramene pas a la liste")
		_check(await _wait_until(func(): return not bool(srv.get_room(code).seats[1]["taken"]), 5.0), "lobby public : le siege n'est pas libere au depart")
		_check(await _wait_until(func(): return main.find_child("Room_" + code, true, false) != null, 8.0), "lobby public : la liste ne revient pas apres le retour (reconnexion)")
	# CREATE PUBLIC GAME : meme parcours que NEW GAME (nombre de joueurs puis extensions) puis salon visible des autres
	main.find_child("CreatePublic", true, false).pressed.emit()
	await _nav(main)
	_check(_texts_of(main).has("HOW MANY PLAYERS?"), "CREATE PUBLIC GAME : pas de choix du nombre de joueurs")
	main.players = 3
	_tb_by_texture(main, "back_bt.webp").pressed.emit()
	await _wait(0.2)
	_check(_texts_of(main).has("PUBLIC GAMES"), "CREATE PUBLIC GAME : la fleche du choix de joueurs ne ramene pas a la liste")
	main.find_child("CreatePublic", true, false).pressed.emit()
	await _nav(main)
	main.players = 3
	main.show_setup(3, "public")
	await _wait(0.2)
	_tb_by_texture(main, "ok_bt.webp").pressed.emit()
	var mine = main.online
	await _wait_until(func(): return mine.match_id != "", 5.0)
	await _nav(main)
	_check(mine.match_id != "" and mine.player_id == 0 and bool(mine.is_host) and mine.public_room, "CREATE PUBLIC GAME : salon non cree (%s)" % mine.match_id)
	var made = srv.get_room(mine.match_id)
	_check(made != null and made.public and made.title == "Zed's game" and main.find_child("RoomTitle", true, false) != null and (main.find_child("RoomTitle", true, false) as LineEdit).text == "Zed's game", "CREATE PUBLIC GAME : salon public a titre par defaut attendu")
	# l'hote renomme sa salle depuis la salle d'attente (perte du focus = validation) ; le serveur nettoie
	var rt_edit := main.find_child("RoomTitle", true, false) as LineEdit
	rt_edit.text = "  Nouveau titre  "
	rt_edit.focus_exited.emit()
	_check(await _wait_until(func(): return made.title == "Nouveau titre" and rt_edit.text == "Nouveau titre", 5.0), "salle d'attente : le titre modifie n'est pas pris (%s)" % made.title)
	_cov("menus_public_title")
	_cov("menus_public_create")
	# l'autre client le voit dans la liste du serveur
	var seen := OnlineClient.new()
	seen.host = url
	add_child(seen)
	var lists: Array = []
	seen.rooms_received.connect(func(rs): lists.append(rs))
	seen.watch_rooms()
	_check(await _wait_until(func(): return not lists.is_empty() and (lists.back() as Array).any(func(e): return e["code"] == mine.match_id and e["title"] == "Nouveau titre"), 5.0), "CREATE PUBLIC GAME : le salon n'est pas dans la liste d'un autre client")
	seen.unwatch_rooms()
	for c in [seen, priv, other]:
		c._forget()
		c.queue_free()
	mine._forget()
	main.queue_free()
	await get_tree().process_frame
	srv.stop()
	srv.queue_free()
	if sess_backup.size() > 0:
		var fa := FileAccess.open(sess_path, FileAccess.WRITE)
		fa.store_buffer(sess_backup)
		fa.close()
	elif FileAccess.file_exists(sess_path):
		DirAccess.remove_absolute(sess_path)

## Partie en ligne a 3 humains contre un VRAI serveur : bulle « IS PLAYING! » des adversaires attendus, bulle « HAS PLAYED A... » d'un coup distant,
## message « X has left the game. » quand un adversaire part (il en reste un autre), puis fin de partie quand le dernier adversaire part.
func _check_online_game() -> void:
	_tag = "[online-game]"
	await _teardown()
	var sess_path: String = ProjectSettings.globalize_path(OnlineClient.SESSION_PATH)
	var sess_backup := PackedByteArray()
	if FileAccess.file_exists(sess_path):
		sess_backup = FileAccess.get_file_as_bytes(sess_path)
	var srv = Server.new()
	srv.auto_start = false
	srv.bot_delay_ms = 0
	add_child(srv)
	var prng := RandomNumberGenerator.new()
	prng.randomize()
	var url := ""
	for _i in 20:
		var port := prng.randi_range(20000, 40000)
		if srv.start(port) == OK:
			url = "ws://127.0.0.1:%d" % port
			break
	if not _check(url != "", "partie en ligne : aucun port libre"):
		srv.queue_free()
		return
	var guests: Array = []
	for nm in ["Bobby", "Cara"]:
		var c := OnlineClient.new()
		c.host = url
		c.player_name = nm
		c.count_results = false
		add_child(c)
		guests.append(c)
	var main = load("res://godot/scenes/Main.tscn").instantiate()
	add_child(main)
	await _wait(0.3)
	main.server_host = url
	main.profile = {"name": "Zed", "avatar": "avatar_gorgona"}
	main.online.count_results = false
	main.online.host = url
	# N-B33 : salle d'attente dont la salle est fermee -> « Room closed » (match_id deja vide) ; OK ramene a WITH FRIENDS
	_check(await main.online.create_lobby(3, []), "salle fermee : creation")
	main.show_waiting()
	await _wait(0.2)
	srv._close_room(main.online.match_id)
	_check(await _wait_until(func(): return _texts_of(main).has("Room closed"), 5.0), "salle fermee : « Room closed » attendu %s" % str(_texts_of(main)))
	(main.find_child("Ok", true, false) as TextureButton).pressed.emit()
	await _nav(main)
	_check(_texts_of(main).has("NEW GAME") and main.find_child("MessageBox", true, false) == null, "salle fermee : OK doit ramener a WITH FRIENDS %s" % str(_texts_of(main)))
	_cov("online_room_closed")
	await _wait_until(func(): return not main.online.connected, 5.0) # leave_match ferme la liaison apres le depart de `leave`
	_check(await main.online.create_lobby(3, []), "partie en ligne : creation")
	_check(await guests[0].join_lobby(main.online.match_id, "Bobby") and await guests[1].join_lobby(main.online.match_id, "Cara"), "partie en ligne : jonctions")
	_check(await _wait_until(func(): return not main.online.current_G.is_empty(), 5.0), "partie en ligne : pas d'etat")
	main.start_online_match()
	await _wait(0.3)
	var b = main.board
	if not _check(b != null and is_instance_valid(b), "partie en ligne : pas de plateau"):
		return
	_check(b._apk_flow() and not b.btn_advance.visible, "N-B18 : en ligne, flux APK (pas de bouton GO, le heros avance apres la barre de 3 s)")
	# phase de boss : les deux adversaires sont attendus -> deux bulles « IS PLAYING! »
	_check(await _wait_until(func(): return b._playing.size() == 2, 5.0), "IS PLAYING : une bulle par adversaire attendu (%d)" % b._playing.size())
	_check(_texts_of(b).filter(func(t): return str(t).ends_with("PLAYING!")).size() == 2, "IS PLAYING : texte absent %s" % str(_texts_of(b)))
	_cov("online_is_playing")
	# un coup distant : la bulle de coup remplace « IS PLAYING! » de cet adversaire
	var spell: Dictionary = (CardDB.spells[0] as Dictionary).duplicate(true)
	main.online.remote_play.emit({"n": 99, "seat": 1, "move": {"type": "playSpell", "args": [0]}, "card": spell})
	await _wait(0.2)
	_check(b._notice_cur.has(1) and is_instance_valid(b._notice_cur[1]) and not b._playing.has(1), "bulle distante : « HAS PLAYED A SPELL » attendue pour le siege 1 (playing=%s)" % str(b._playing.keys()))
	_cov("online_remote_notice")
	# un adversaire quitte : il reste un autre humain -> simple message, la partie continue
	guests[0].leave_match()
	_check(await _wait_until(func(): return main.find_child("MessageBox", true, false) != null, 5.0), "depart : message absent")
	_check(_texts_of(main).has("Bobby has left the game.") and main.board != null, "depart : « Bobby has left the game. » attendu %s" % str(_texts_of(main)))
	(main.find_child("Ok", true, false) as TextureButton).pressed.emit()
	await _wait(0.2)
	_check(main.board != null and is_instance_valid(main.board) and main.find_child("MessageBox", true, false) == null, "depart : OK doit garder la partie")
	# le dernier adversaire part : fin de partie, OK ramene au titre
	guests[1].leave_match()
	_check(await _wait_until(func(): return _texts_of(main).any(func(t): return str(t).begins_with("No players to play with.")), 5.0), "depart : « No players to play with. » attendu %s" % str(_texts_of(main)))
	(main.find_child("Ok", true, false) as TextureButton).pressed.emit()
	await _wait(0.4)
	_check(main.board == null or not is_instance_valid(main.board), "depart : OK doit quitter la partie")
	_cov("online_player_left")
	for c in guests:
		c._forget()
		c.queue_free()
	main.queue_free()
	await get_tree().process_frame
	srv.stop()
	srv.queue_free()
	if sess_backup.size() > 0:
		var fa := FileAccess.open(sess_path, FileAccess.WRITE)
		fa.store_buffer(sess_backup)
		fa.close()
	elif FileAccess.file_exists(sess_path):
		DirAccess.remove_absolute(sess_path)

## Attend `cond` (horloge reelle) ; faux apres `timeout_s`.
func _wait_until(cond: Callable, timeout_s: float) -> bool:
	var t0 := Time.get_ticks_msec()
	while not cond.call():
		if (Time.get_ticks_msec() - t0) / 1000.0 > timeout_s:
			return false
		await get_tree().process_frame
	return true

## Ecran de fin : bandeau du vainqueur (nom, IS THE WINNER!, boss agrandi, 10 cristaux, OK), « YOU LOSE » avec la pierre tombale ;
## boss elimine = pierre tombale RIP a la place du sprite.
func _check_gameover_banner() -> void:
	_tag = "[gameover]"
	await _new_game()
	board.set_process(false)
	var G: Dictionary = gm.G
	var boss = G["players"][0].get("boss")
	G["gameOver"] = {"winner": 0, "reason": "souls"}
	var m0: int = AudioManager.rec.size()
	board.refresh()
	await get_tree().process_frame
	var ev: Array = AudioManager.rec.slice(m0)
	_check(ev.has("sting:sting_player_win") and not ev.has("sting:sting_player_lose"), "fin gagnee : sting_player_win attendu (WinnerScene.cs:125), vu %s" % str(ev))
	_check(AudioManager.duck_gain() < 1.0, "fin gagnee : la musique doit baisser sous le sting (AudioService.cs:159)")
	await _wait(0.7) # la voix du boss part 0,5 s apres le sting (WinnerScene.cs:127-130)
	ev = AudioManager.rec.slice(m0)
	_check(ev.has("sfx:" + AudioManager.boss_voice(str((boss as Dictionary).get("id", "")), "victory")), "fin gagnee : voix de victoire du boss absente, vu %s" % str(ev))
	var gb = board._gameover
	if _check(gb != null and is_instance_valid(gb), "fin : bandeau absent"):
		_check(gb.title_label.text == str((boss as Dictionary).get("name", "")), "fin : nom du vainqueur %s" % gb.title_label.text)
		_check(gb.get_node_or_null("WinnerText") != null and gb.get_node_or_null("BossSprite") != null, "fin : « IS THE WINNER! » ou boss absent")
		_check(gb._crystals.size() == 10, "fin : %d cristaux (10 attendus)" % gb._crystals.size())
		var p0: Vector2 = (gb._crystals[0] as Control).position
		gb._process(1.0)
		_check(not (gb._crystals[0] as Control).position.is_equal_approx(p0), "fin : les cristaux ne tournent pas")
		_check(gb.find_children("*", "Label", true, false).size() == 1, "fin : texte parasite (score ?) sur le bandeau")
		var q0 := quit_calls
		gb.ok_btn.pressed.emit()
		_check(quit_calls == q0 + 1, "fin : OK n'appelle pas la sortie (ecran titre)")
	await _new_game()
	board.set_process(false)
	G = gm.G
	G["gameOver"] = {"winner": 1, "reason": "wounds"}
	m0 = AudioManager.rec.size()
	board.refresh()
	await get_tree().process_frame
	await _wait(0.7)
	ev = AudioManager.rec.slice(m0)
	_check(ev.has("sting:sting_player_lose") and not ev.any(func(e): return str(e).begins_with("sfx:boss_")), "fin perdue : sting_player_lose seul attendu (LoseScene.cs:21, pas de voix), vu %s" % str(ev))
	gb = board._gameover
	_check(gb != null and gb.title_label.text.contains("YOU LOSE") and gb.get_node_or_null("Tombstone") != null, "fin : ecran perdu (YOU LOSE + tombe) absent")
	_cov("gameover_banner")
	# boss elimine : pierre tombale
	await _new_game()
	board.set_process(false)
	G = gm.G
	G["players"][1]["eliminated"] = true
	board.refresh()
	var spr: TextureRect = board._lane[0]["sprite"]
	_check(spr.texture == board._tex(board.UI_DIR + "bosses_tombstone.webp"), "boss mort : pas de pierre tombale RIP")
	_cov("tombstone")

## Traversee d'un heros (APK HeroCardEntity) : sa carte reste a l'entree, un personnage et un coeur de PV traversent le donjon, la salle visitee
## grossit puis reprend sa taille quand le heros part.
func _check_crossing_ui() -> void:
	_tag = "[crossing]"
	await _new_game()
	board.set_process(false)
	board.skip_animations = false
	var G: Dictionary = gm.G
	var me: Dictionary = G["players"][0]
	var dng: Array = me["dungeon"]
	dng.clear()
	for i in 3:
		var r: Dictionary = (CardDB.rooms[i] as Dictionary).duplicate(true)
		r["isRoom"] = true
		r["faceDown"] = false
		dng.push_front([r])
	var hero: Dictionary = (CardDB.heroes[5] as Dictionary).duplicate(true)
	(me["entrance"] as Array).clear()
	(me["entrance"] as Array).append(hero)
	G["phase"] = "adventure"
	G.erase("buildWindow")
	var hp0: int = BossEngine.hero_hp(hero)
	G["adventure"] = {"playerId": 0, "hero": hero, "roomIndex": 1, "hp": hp0 - 2, "pause": "post-damage"}
	board.refresh()
	await _wait(1.8)
	var pawn = board._hero_pawn
	if _check(pawn != null and is_instance_valid(pawn), "traversee : pas de personnage de heros dans le donjon"):
		var hp_lbl = (pawn as Control).find_child("Hp", true, false)
		_check(pawn.find_child("HeroHeart", true, false) != null and hp_lbl != null and (hp_lbl as Label).text == str(hp0 - 2), "traversee : coeur de PV du heros absent ou faux")
	var toks: Array = board._ent_tok.get(0, [])
	_check(toks.size() == 1 and toks[0] != null and is_instance_valid(toks[0]), "traversee : la carte du heros doit rester a l'entree")
	var hit: Control = board._slot_at(0, 1)
	_check(hit != null and absf(hit.scale.x - board.ROOM_FOCUS_SCALE) < 0.03, "traversee : la salle visitee n'a pas grossi")
	var other: Control = board._slot_at(0, 0)
	_check(other != null and absf(other.scale.x - 1.0) < 0.01, "traversee : une autre salle a change de taille")
	G.erase("adventure")
	(me["entrance"] as Array).clear()
	board.refresh()
	await _wait(0.6)
	_check(hit != null and absf(hit.scale.x - 1.0) < 0.03, "traversee : la salle ne reprend pas sa taille apres le depart du heros")
	_check(board._hero_pawn == null or not is_instance_valid(board._hero_pawn), "traversee : le personnage reste apres le depart du heros")
	board.skip_animations = true
	_cov("crossing")

## Petites animations : coeur qui monte (degats), cristal qui s'allume, pioche au centre, notice « HAS PLAYED A SPELL ».
func _check_effects() -> void:
	_tag = "[effects]"
	await _new_game()
	board.set_process(false)
	board.skip_animations = false
	var G: Dictionary = gm.G
	var me: Dictionary = G["players"][0]
	board._show_floating_dmg(board._lane[1]["platform"], 2)
	var heart = board._ui_layer.find_child("HeartFx", true, false)
	_check(heart != null, "coeur de degats absent")
	board.refresh()
	var seen_hand: int = (me["hand"] as Array).size()
	var drawn := _take_spell("BMA053")
	await get_tree().process_frame
	_check(drawn >= 0 and board._ui_layer.find_child("DrawnCard", true, false) != null, "pioche : pas de carte au centre pour un nouveau sort en main (main %d)" % seen_hand)
	var in_flight: Array = _hand_cards().filter(func(c): return not c.visible)
	_check(in_flight.size() == 1, "pioche : la carte piochee doit rester cachee dans la main pendant son vol (%d cachee(s))" % in_flight.size())
	await _wait(3.6) # glisse 0,5 s + retournement 0,5 s + attente 2 s + arrivee 0,3 s (DrawCardEmitter.cs:147-165)
	_check(board._ui_layer.find_child("DrawnCard", true, false) == null and _hand_cards().all(func(c): return c.visible), "pioche : la carte piochee n'a pas rejoint la main")
	board._notice_reset()
	board._notice_ai(1, {"type": "playSpell", "args": []})
	var notice = board._ui_layer.find_child("Notice", true, false)
	var texts: Array = notice.find_children("*", "Label", true, false).map(func(l): return (l as Label).text) if notice != null else []
	_check(texts == ["HAS PLAYED A", "SPELL"], "notice adverse : %s" % str(texts))
	board._notice_reset()
	board._notice_ai(0, {"type": "playSpell", "args": []}) # mon propre coup : pas de notice
	await _wait(0.1)
	board.skip_animations = true
	_cov("effects")

## Emetteurs ApkParticles qui emettent sous `root`.
func _emitting(root: Node) -> Array:
	return root.find_children("*", "ApkParticles", true, false).filter(func(e): return (e as ApkParticles).emitting)

## Particules de l'APK (ApkParticles = CreateBackParticles) : pioche, heros qui entre, ecran de victoire ; aucune sur une carte simplement jouable.
## (Defausse d'ouverture, salle ciblable, emplacement survole : verifies dans _act_discard, _check_target_spots, _check_drag_and_zoom.)
func _check_apk_particles() -> void:
	_tag = "[particles]"
	await _new_game()
	board.set_process(false)
	var G: Dictionary = gm.G
	var me: Dictionary = G["players"][0]
	board.refresh()
	await get_tree().process_frame
	_check(board.hand_layer.find_children("*", "ApkParticles", true, false).is_empty() and _emitting(board).is_empty(), "particules : une carte simplement jouable ne doit rien emettre (%d emetteur(s))" % _emitting(board).size())
	# pioche : emet de la creation de la carte jusqu'a son arrivee en main (DrawCardEmitter.cs:153, CardManagerComponent.cs:108)
	board.skip_animations = false
	_take_spell("BMA053")
	await get_tree().process_frame
	var fx: Array = _emitting(board._ui_layer)
	if _check(fx.size() == 1, "particules : la carte piochee doit emettre (%d emetteur(s))" % fx.size()):
		var e: ApkParticles = fx[0]
		_check(e.amount == ApkParticles.AMOUNT and not e.local_coords and e.texture != null and e.texture.resource_path.ends_with("ui/particle_01.webp"), "particules : reglages (texture, coordonnees monde, quantite)")
		_check(is_equal_approx(e.lifetime * (1.0 - e.lifetime_randomness), 1.5) and is_equal_approx(e.lifetime, 3.0), "particules : vie 1,5-3 s (ParticlesFactory.cs:13-14)")
		_check(e.emission_points.size() == 400 and e.emission_normals.size() == 400, "particules : contour du rectangle en 4 x 100 points")
		var holder := e.get_parent().get_child(e.get_index() + 1) as Control # l'emetteur est juste derriere la carte piochee
		_check(is_equal_approx(absf(e.emission_points[0].x) * 2.0, holder.size.x * ApkParticles.ECHELLE), "particules : emetteur = 0,9 x la carte")
		var v_ok := true
		for v in e.emission_normals:
			v_ok = v_ok and v.x >= -102.01 and v.x <= -41.99 and v.y >= -102.01 and v.y <= -41.99 # [-1,7 ; -0,7] x 60 px/s, haut-gauche
		_check(v_ok, "particules : vitesse par axe dans [-102 ; -42] px/s")
	await _wait(3.6) # vol 0,5 s + retournement 0,5 s + attente 2 s + arrivee 0,3 s
	_check(_emitting(board._ui_layer).is_empty(), "particules : la pioche arrivee en main ne doit plus emettre")
	board.skip_animations = true
	# heros qui entre dans le donjon du joueur actif (HeroesQueueComponent.cs:105-107, 142-145)
	var hero: Dictionary = (CardDB.heroes[5] as Dictionary).duplicate(true)
	(me["entrance"] as Array).clear()
	(me["entrance"] as Array).append(hero)
	G["phase"] = "adventure"
	G["adventure"] = {"playerId": 0, "hero": hero, "roomIndex": -1, "hp": 4, "pause": null}
	board.refresh()
	await get_tree().process_frame
	var hfx: Array = _emitting(board._lane[1]["root"])
	_check(hfx.size() == 1 and (hfx[0] as Node).name == "HeroFx", "particules : le heros qui entre dans mon donjon doit emettre (%d emetteur(s))" % hfx.size())
	_check(_emitting(board._lane[0]["root"]).is_empty(), "particules : le donjon adverse n'a pas de heros qui entre")
	G["adventure"] = {}
	G["phase"] = "build"
	board.refresh()
	_check(_emitting(board._lane[1]["root"]).is_empty(), "particules : plus de heros dans le donjon, plus d'emission (HeroesQueueComponent.cs:293-296)")
	# ecran de victoire du joueur local : emission continue derriere « IS THE WINNER! » (WinnerScene.cs:63-74) ; l'ecran perdu n'en a pas
	G["gameOver"] = {"winner": 0, "reason": "souls"}
	board.refresh()
	await get_tree().process_frame
	var wfx: Array = _emitting(board._gameover)
	_check(wfx.size() == 1 and (wfx[0] as Node).name == "WinnerFx" and (wfx[0] as Node).get_index() < board._gameover.get_node("WinnerText").get_index(), "particules : l'ecran de victoire doit emettre derriere le titre (%d emetteur(s))" % wfx.size())
	await _new_game()
	board.set_process(false)
	gm.G["gameOver"] = {"winner": 1, "reason": "wounds"}
	board.refresh()
	await get_tree().process_frame
	_check(board._gameover != null and board._gameover.find_children("*", "ApkParticles", true, false).is_empty(), "particules : l'ecran perdu ne doit pas emettre")
	_cov("apk_particles")

## Animations de l'APK ajoutees apres coup : defausse de la main (DrawCardEmitter.cs:113-145), inclinaison au glisser
## (CardRotationBehavior), lerp de survol (CardMoveBehavior), reordonnancement de la ville (VerticalScrollQueueComponent.CreateReorderTask), particules du panneau adverse actif.
func _check_apk_anims() -> void:
	_tag = "[anims]"
	await _new_game()
	board.set_process(false)
	board.skip_animations = false
	board.refresh()
	var me: Dictionary = gm.G["players"][0]
	var hand: Array = me["hand"]
	# une carte jouee (aucun coup de defausse) ne s'envole pas vers la defausse
	hand.pop_back()
	board.refresh()
	_check(get_tree().get_nodes_in_group("discarded_card").is_empty(), "defausse : une carte partie sans coup de defausse ne doit pas etre animee")
	# une carte defaussee par un choix : vol, particules allumees des le depart, derriere la carte
	hand.pop_back()
	board._discard_move = true
	board.refresh()
	var flying: Array = get_tree().get_nodes_in_group("discarded_card")
	if _check(flying.size() == 1, "defausse : la carte defaussee doit s'envoler (%d carte(s))" % flying.size()):
		var fxd: Array = _emitting(board._ui_layer)
		_check(fxd.size() == 1 and (fxd[0] as Node).get_index() + 1 == (flying[0] as Node).get_index(), "defausse : les particules doivent emettre des le depart, derriere la carte (%d emetteur(s))" % fxd.size())
		board._draw_clear()
		await get_tree().process_frame
		_check(get_tree().get_nodes_in_group("discarded_card").is_empty(), "defausse : un changement de siege doit couper le vol")
	_cov("discard_anim")
	# CardRotationBehavior : rotation Y = dx x 0,005 par image, bornee a 22,5 deg, retombe a 0 a l'arret
	var pv := Control.new()
	pv.size = Vector2(175, 244)
	add_child(pv)
	board._drag = {"preview": pv}
	pv.position.x = 100.0
	board._drag_tilt()
	pv.position.x = 200.0
	board._drag_tilt()
	_check(is_equal_approx(pv.scale.x, cos(0.3927)), "inclinaison : 100 px par image = borne 22,5 deg (scale.x %.4f)" % pv.scale.x)
	pv.position.x = 190.0
	board._drag_tilt()
	_check(is_equal_approx(pv.scale.x, cos(0.05)), "inclinaison : 10 px par image = 0,05 rad (scale.x %.4f)" % pv.scale.x)
	board._drag_tilt()
	_check(is_equal_approx(pv.scale.x, 1.0), "inclinaison : la carte arretee se redresse")
	board._drag = {}
	pv.queue_free()
	_cov("drag_tilt")
	# CardMoveBehavior : lerp 0,009 x ms par image (14,4 % a 16 ms), cible atteinte exactement
	var mv := Control.new()
	add_child(mv)
	CardUI.lerp_vers(mv, "position:y", 100.0)
	await _wait(0.1)
	_check(mv.position.y > 40.0 and mv.position.y < 90.0, "survol : le lerp doit etre en cours apres 0,1 s (%.1f)" % mv.position.y)
	await _wait(0.6)
	_check(mv.position.y == 100.0, "survol : le lerp doit atteindre sa cible (%.1f)" % mv.position.y)
	mv.queue_free()
	_cov("hover_lerp")
	# ville : un heros reste en ville quand le premier part (leurre) : il glisse a sa nouvelle place au lieu de sauter
	var town: Array = []
	for k in 3:
		town.append((CardDB.heroes[k] as Dictionary).duplicate(true))
	gm.G["town"] = town.duplicate()
	board.refresh()
	await _wait(0.2)
	gm.G["town"] = [town[0], town[1]] # le plus recent (en haut) part : les deux autres remontent
	board.refresh()
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	var c0 := board.town_container.get_child(0) as Control
	_check(c0.position.y > 1.0, "ville : le heros restant doit glisser vers sa place (y %.1f)" % c0.position.y)
	await _wait(0.8)
	_check(is_equal_approx(c0.position.y, 0.0), "ville : le heros doit finir a sa place (y %.1f)" % c0.position.y)
	_cov("town_reorder")
	# panneau adverse actif : particules (3 joueurs = barre d'adversaires)
	await _teardown()
	CardDB._rng.seed = 424242
	gm = GameManager.new()
	add_child(gm)
	gm.rng.seed = 424242
	gm.start_new_game(3, 1, ["base"])
	board = load("res://godot/scenes/Board.tscn").instantiate()
	board.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(board)
	board.skip_animations = true
	board.setup(gm, func(): quit_calls += 1)
	board.set_process(false)
	await _wait(0.2)
	gm.G["activePlayer"] = 1
	board.refresh()
	await _wait(0.1)
	var ffx: Array = _emitting(board.opp_box)
	_check(ffx.size() == 1 and (ffx[0] as Node).get_parent().get_meta("pid") == 1, "panneau adverse : seul l'adversaire actif doit emettre (%d emetteur(s))" % ffx.size())
	if not ffx.is_empty():
		var bt := (ffx[0] as Node).get_parent() as Control
		_check(is_equal_approx(absf((ffx[0] as ApkParticles).emission_points[0].x) * 2.0, bt.size.x * ApkParticles.ECHELLE), "panneau adverse : emetteur = 0,9 x le panneau")
	gm.G["activePlayer"] = 0
	board.refresh()
	_check(_emitting(board.opp_box).is_empty(), "panneau adverse : plus d'emission quand le joueur actif est un autre")
	_cov("foe_particles")

## Fenetres a l'horloge murale : Godot plafonne delta (~0,13 s) quand les images sont lentes (web, onglet en arriere-plan, ~1 image/s) ; une
## fenetre de 3 s durait alors 20-30 s. Ici delta est minuscule mais 0,3 s reelles passent entre deux images : la barre doit suivre l'horloge.
## Une ligne de journal / un siege qui passe ne rouvre pas la fenetre (l'APK ne remet la barre a zero qu'a un pas du heros ou un sort).
func _check_window_clock() -> void:
	_tag = "[window-clock]"
	var gi := await _adventure_window_setup()
	if not _check(gi >= 0, "horloge : Giant Size introuvable"):
		return
	board.win_time_scale = 0.5 # fenetre de 1,5 s
	var G: Dictionary = gm.G
	var n := 0
	for i in 12:
		OS.delay_msec(300)
		(G["log"] as Array).append("ligne de journal %d" % i) # un autre siege a agi : ne doit pas rouvrir la fenetre
		board._process(0.01)
		n += 1
		if i == 1:
			_check(str(G["adventure"].get("pause")) == "post-damage" and board._win_bar.visible and absf(board._win_bar.frac - 0.6) < 0.2, "horloge : apres 0,6 s reelles la barre doit etre a ~60 %% (frac %.2f, pause %s)" % [board._win_bar.frac, str(G["adventure"].get("pause"))])
		if str(G["adventure"].get("pause")) != "post-damage":
			break
	_check(str(G["adventure"].get("pause")) == "pre-exit" and n >= 4 and n <= 7, "horloge : la fenetre de 1,5 s doit finir en 4-7 images lentes de 0,3 s (%d images, pause %s)" % [n, str(G["adventure"].get("pause"))])
	_cov("window_clock")

## Un seul clic (deplacement, appui, relachement) agit : sur une salle de la main avec plusieurs emplacements il ouvre le ciblage « construire
## par-dessus », sur la zone doree il construit. Cas qui perdaient le clic : un rafraichissement (coup de l'IA) entre l'appui et le relachement
## detruisait la carte appuyee ; un appui qui tombait sur le voile pendant la repose des zones.
func _check_single_click() -> void:
	_tag = "[single-click]"
	for variant in ["plain", "refresh-mid-click", "dim-fallback"]:
		await _new_game()
		var me: Dictionary = gm.G["players"][0]
		var hand: Array = me["hand"]
		var idx := -1
		for i in hand.size():
			if bool((hand[i] as Dictionary).get("isRoom", false)) and not bool((hand[i] as Dictionary).get("advanced", false)):
				idx = i
				break
		if not _check(idx >= 0, "clic simple : aucune salle en main"):
			return
		for k in 2: # deux salles de meme type en donjon : la salle de la main peut aller sur l'une, l'autre ou l'emplacement libre
			var host: Dictionary = (hand[idx] as Dictionary).duplicate(true)
			host["faceDown"] = false
			(me["dungeon"] as Array).push_front([host])
		board.refresh()
		await get_tree().process_frame
		await get_tree().process_frame
		var n_targets := _n_build_targets(0, idx)
		if not _check(n_targets >= 3, "clic simple (%s) : %d emplacements seulement" % [variant, n_targets]):
			return
		var dsize: int = (me["dungeon"] as Array).size()
		var pos: Vector2 = (_hand_cards()[idx] as CardUI).get_global_rect().get_center()
		await _mouse(pos, false, true) # survol
		await _mouse(pos, true, false)
		if variant == "refresh-mid-click":
			board.refresh() # l'IA a joue entre l'appui et le relachement
			await get_tree().process_frame
		await _mouse(pos, false, false)
		await get_tree().process_frame
		await get_tree().process_frame
		if not _check(not board._tgt.is_empty(), "clic simple (%s) : un seul clic sur la salle de la main n'a pas ouvert le ciblage" % variant):
			return
		_check(board._tgt_spots.size() == n_targets, "clic simple (%s) : %d zones pour %d emplacements" % [variant, board._tgt_spots.size(), n_targets])
		var free_spot: Dictionary = {}
		for s in board._tgt_spots:
			var e: Dictionary = (board._tgt["entries"] as Array)[int((s["ids"] as Array)[0])]
			if str((e.get("spot", {}) as Dictionary).get("k", "")) == "free":
				free_spot = s
		if not _check(not free_spot.is_empty(), "clic simple (%s) : pas de zone « emplacement libre »" % variant):
			return
		var c2: Vector2 = (free_spot["ctrl"] as Control).get_global_rect().get_center()
		if variant == "dim-fallback":
			var ev := InputEventMouseButton.new() # appui qui atterrit sur le voile (zones en cours de repose) : la zone qui contient le point joue
			ev.button_index = MOUSE_BUTTON_LEFT
			ev.pressed = true
			ev.position = c2
			ev.global_position = c2
			board._target_dim_input(ev)
		else:
			await _mouse(c2, false, true)
			await _mouse(c2, true, false)
			await _mouse(c2, false, false)
		await get_tree().process_frame
		_check(board._tgt.is_empty() and (me["dungeon"] as Array).size() == dsize + 1, "clic simple (%s) : un seul clic sur la zone doree n'a pas construit (donjon %d -> %d)" % [variant, dsize, (me["dungeon"] as Array).size()])
		_cov("single_click_" + variant)

## Choix du boss : l'IA ne prend jamais le boss tire pour le joueur (elle attend que l'humain ait le sien), puis tire au hasard parmi le reste.
func _check_boss_race() -> void:
	_tag = "[boss-race]"
	await _teardown()
	CardDB._rng.seed = 99
	gm = GameManager.new()
	add_child(gm)
	gm.rng.seed = 99 # Match._ready l'a randomise : le tirage du boss doit etre reproductible
	gm.start_new_game(2, 1, ["base"])
	board = load("res://godot/scenes/Board.tscn").instantiate()
	board.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(board)
	board.skip_animations = false # rotation reelle ; board._process tourne (l'IA joue)
	Engine.time_scale = ANIM_TIME_SCALE
	board.setup(gm, func(): quit_calls += 1)
	var ai_mv = AI.pick_move(gm, 1)
	if not _check(ai_mv != null and str(ai_mv["type"]) == "pickBoss", "course : l'IA ne propose pas de pickBoss"):
		return
	var want: String = board._boss_pick_id
	var t := 0.0
	while not board._boss_ready and t < 12.0:
		await _wait(0.1)
		t += 0.1
		_check(gm.G["players"][1].get("boss") == null, "course : l'IA a pris un boss avant le joueur")
	_check(board._boss_ready and gm.G["players"][1].get("boss") == null, "course : l'IA n'attend pas le joueur apres l'arret")
	board._confirm_btn.pressed.emit()
	await _wait(1.0) # l'IA joue a 0,5 s
	var me_boss = gm.G["players"][0].get("boss")
	var foe_boss = gm.G["players"][1].get("boss")
	_check(me_boss != null and str((me_boss as Dictionary).get("id", "")) == want, "course : le boss tire n'est pas revenu au joueur")
	_check(foe_boss != null and str((foe_boss as Dictionary).get("id", "")) != want, "course : l'IA a pris le meme boss que le joueur")
	_cov("boss_race")

## Choix sur le plateau (Centipede Tunnel : echange de 2 salles, y compris chez l'adversaire) : une fois resolu, plus aucune zone doree ni voile,
## et la barre de temps n'est plus figee. Les entrees portent leur coup (mv) : _target_sync ferme le ciblage quand il n'est plus legal.
func _check_choice_target() -> void:
	_tag = "[choice-target]"
	await _new_game()
	board.set_process(false)
	var G: Dictionary = gm.G
	var me: Dictionary = G["players"][0]
	var cent: Dictionary = {}
	for r in CardDB.rooms:
		if str((r as Dictionary).get("id", "")) == "BMA033":
			cent = (r as Dictionary).duplicate(true)
	if not _check(not cent.is_empty(), "choix plateau : BMA033 introuvable"):
		return
	cent["isRoom"] = true
	(me["hand"] as Array).append(cent)
	board.refresh()
	if not _check(gm.build_room_at(0, (me["hand"] as Array).size() - 1, (me["dungeon"] as Array).size()), "choix plateau : Centipede Tunnel non construit"):
		return
	gm.apply_move(0, {"type": "passBuild", "args": []})
	board.refresh()
	await get_tree().process_frame
	for _k in 12: # fenetre de sorts : l'IA y joue (capacite de salle) et resout son propre choix avant la revelation de Centipede Tunnel
		var apc: Dictionary = G.get("pendingChoice", {})
		if (apc.is_empty() and not G.has("buildWindow")) or int(apc.get("playerId", -1)) == 0:
			break
		board._process(0.6)
	var pc: Dictionary = G.get("pendingChoice", {})
	if not _check(str(pc.get("type", "")) == "swap-rooms" and int(pc.get("playerId", -1)) == 0 and board._tgt.has("choice") and board._tgt_spots.size() > 0, "choix plateau : pas de ciblage des salles a echanger (%s)" % str(pc.get("type"))):
		return
	var foe_rooms := 0
	for s in board._tgt_spots:
		var e: Dictionary = (board._tgt["entries"] as Array)[int((s["ids"] as Array)[0])]
		if int((e.get("spot", {}) as Dictionary).get("pid", 0)) != 0:
			foe_rooms += 1
	_check(foe_rooms > 0, "choix plateau : aucune salle adverse proposee")
	# resolu hors de l'UI (autre siege, moteur) : au rafraichissement suivant le ciblage disparait
	var mv: Dictionary = (gm.legal_moves(0).filter(func(m): return m["type"] == "resolveChoice")[0] as Dictionary).duplicate(true)
	gm.apply_move(0, mv)
	board.refresh()
	await get_tree().process_frame
	var pc2: Dictionary = G.get("pendingChoice", {})
	_check(board._tgt.is_empty() or (not pc2.is_empty() and int(pc2.get("playerId", -1)) == 0), "choix plateau : ciblage encore ouvert apres la resolution")
	if board._tgt.is_empty():
		_check(board._tgt_layer == null and board._tgt_spots.is_empty(), "choix plateau : zones dorees / voile restes apres la resolution")
		_check(not board._win_paused(), "choix plateau : la barre de temps reste figee apres la resolution")
	_cov("choice_target_cleared")

func _extra_checks() -> void:
	await _check_stacks()
	await _check_boss_flip()
	await _check_boss_carousel()
	await _check_boss_race()
	await _check_main_flow()
	await _check_hand_room()
	await _check_wiki_ui()
	await _check_windows()
	await _check_ai_entry_window()
	await _check_window_clock()
	await _check_single_click()
	await _check_choice_target()
	await _check_drag_and_zoom()
	await _check_done_and_warning()
	await _check_review_fixes()
	await _check_apk_gaps()
	await _check_gallery()
	await _check_credits()
	await _check_online_menus()
	await _check_public_lobby()
	await _check_online_game()
	await _check_gameover_banner()
	await _check_apk_particles()
	await _check_apk_anims()
	await _check_tutorial()
	await _check_effects()
	await _check_crossing_ui()
	await _check_audio()
	_tag = "[base]"
	await _new_game()
	var G: Dictionary = gm.G
	var me: Dictionary = G["players"][0]
	board.refresh()
	# LEVEL UP : zoom du boss au-dessus du bouton ; il survit a un refresh (l'IA joue, state_changed) et part au clic suivant
	board.levelup_btn.pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	board.refresh()
	await get_tree().process_frame
	if _check(board._zoom != null and is_instance_valid(board._zoom), "LEVEL UP : pas de zoom du boss (ou efface par un refresh)"):
		_check(Rect2(0, 0, 1920, 1080).encloses(Rect2(board._zoom.position, board._zoom.size)), "LEVEL UP : zoom hors ecran %s" % Rect2(board._zoom.position, board._zoom.size))
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = true
		board._input(click)
		_check(board._zoom == null, "LEVEL UP : le zoom reste apres un clic")
	# Main : cartes 175x244 en eventail (CardPositionComponent de l'APK) a 1920x1080
	var cards := _hand_cards()
	if _check(not cards.is_empty(), "main vide a l'ecran"):
		_check((cards[0] as Control).size.is_equal_approx(Vector2(175, 244)), "carte de main %s != 175x244" % (cards[0] as Control).size)
		_check_fan(cards)
	_check(board.extra_bar.get_child_count() == 0 or not board.extra_bar.visible, "bouton non-APK visible en partie de base")
	# 1) Sort sans cible : un clic sur la carte le joue (aucun bouton « Sort : ... »)
	var idx := _take_spell("BMA050") # Motivation : phase de construction, sans cible
	_foe_rooms(G)
	if _check(idx >= 0, "BMA050 introuvable dans la pioche de sorts"):
		var n_before := (me["hand"] as Array).size()
		var legal := gm.legal_moves(0).filter(func(m): return m["type"] == "playSpell" and int(m["args"][0]) == idx)
		if _check(legal.size() == 1, "BMA050 : %d coups playSpell (1 attendu)" % legal.size()):
			board._on_hand_card_clicked(idx, (me["hand"] as Array)[idx])
			await get_tree().process_frame
			_check((me["hand"] as Array).size() == n_before - 1, "clic sur le sort : la carte n'a pas ete jouee")
			_check(board._popup_kind == "", "popup inattendu pour un sort sans cible")
			await _drain()
	# 2) Sort a cible multiple : fenetre de ciblage, choix d'une cible ; CANCEL la referme sans jouer
	var town: Array = G["town"]
	while town.size() < 2: # le tour 1 peut commencer avec la ville vide : on y met deux heros pour avoir plusieurs cibles
		town.append((CardDB.heroes[town.size()] as Dictionary).duplicate(true))
	idx = _take_spell("BMA051")
	if _check(idx >= 0, "BMA051 introuvable dans la pioche de sorts"):
		var n2 := (me["hand"] as Array).size()
		board._on_hand_card_clicked(idx, (me["hand"] as Array)[idx])
		for i in 3:
			await get_tree().process_frame
		if _check(board._popup_kind == "" and not board._tgt.is_empty(), "sort a cibles multiples : pas de ciblage sur le plateau (popup=%s)" % board._popup_kind):
			_check(board._tgt_spots.size() == town.size(), "ciblage : %d zones allumees pour %d heros en ville" % [board._tgt_spots.size(), town.size()])
			_check(board._tgt_cancel_btn != null and board._tgt_cancel_btn.text == "CANCEL" and not board.action_box.visible, "ciblage : CANCEL absent ou PASS TURN visible")
			var s_h := _sig()
			await _click_at((_hand_cards()[0] as Control).get_global_rect().get_center())
			_check(not board._tgt.is_empty() and _sig() == s_h, "ciblage : la main n'est pas bloquee par le voile")
			board._tgt_cancel_btn.pressed.emit() # CANCEL
			await get_tree().process_frame
			_check(board._tgt.is_empty() and board._popup_kind == "" and (me["hand"] as Array).size() == n2, "CANCEL : mode ferme et carte conservee")
			_check(board.action_box.visible, "CANCEL : PASS TURN non restaure")
			board._on_hand_card_clicked(idx, (me["hand"] as Array)[idx])
			for i in 3:
				await get_tree().process_frame
			if _check(not board._tgt_spots.is_empty(), "ciblage : plus de zone apres CANCEL puis nouveau clic"):
				await _click_at(((board._tgt_spots[0]["ctrl"]) as Control).get_global_rect().get_center()) # vrai clic sur la 1re cible
				_check(board._tgt.is_empty() and (me["hand"] as Array).size() == n2 - 1, "cible choisie par un clic : le sort doit etre joue")
			await _drain()
	# 3) Capacite de salle : halo + clic gauche sur la salle (aucun bouton « Capacite : ... »)
	if str(G.get("phase", "")) == "adventure" and not gm.apk_active_hero():
		_check(board._my_moves(0).all(func(m): return not (str(m["type"]) in BoardUI.NO_HERO_BLOCKED)), "aventure sans heros actif : l'interface humaine offre encore un sort / une capacite")
		G["apkSkippedHero"] = gm.active_player() # sans heros actif l'interface humaine n'offre aucune capacite (voir _check_apk_hero_gate) : on en suppose un
	var done := false
	for rid in Match.ACTIVATABLE_ROOMS:
		if not str(rid).begins_with("BMA") or done:
			continue
		var proto: Dictionary = {}
		for r in CardDB.rooms:
			if str((r as Dictionary).get("id", "")) == rid:
				proto = (r as Dictionary).duplicate(true)
				break
		if proto.is_empty():
			continue
		proto["faceDown"] = false
		proto.erase("usedThisTurn")
		(me["dungeon"] as Array).push_front([proto])
		board.refresh()
		var acts: Array = board._my_moves(0).filter(func(m): return m["type"] == "activateRoom" and int(m["args"][0]) == 0)
		if acts.is_empty():
			(me["dungeon"] as Array).pop_front()
			board.refresh()
			continue
		done = true
		var slot: DungeonSlot = null
		for sl in board._dungeon_slots:
			if (sl as DungeonSlot).slot_index == 0 and not (sl as DungeonSlot).current_stack.is_empty():
				slot = sl
		if _check(slot != null, "salle activable %s : aucun emplacement" % rid) and _check(slot.activatable, "salle activable %s : pas de halo" % rid):
			var log_n := (G.get("log", []) as Array).size()
			var ev := InputEventMouseButton.new()
			ev.button_index = MOUSE_BUTTON_LEFT
			ev.pressed = true
			slot._gui_input(ev)
			await get_tree().process_frame
			if _check(board._zoom != null and board._zoom.has_meta("ability"), "clic sur la salle %s : pas de zoom au 1er appui" % rid): # APK : 1er appui = zoom
				var tap := InputEventMouseButton.new()
				tap.button_index = MOUSE_BUTTON_LEFT
				tap.pressed = true
				tap.position = board._zoom.get_global_transform() * (board._zoom.get_meta("ability")["rect"] as Rect2).get_center()
				board._input(tap) # 2e appui, sur la bordure de capacite
				await get_tree().process_frame
			var changed: bool = (G.get("log", []) as Array).size() != log_n or bool((proto).get("usedThisTurn", false)) or board._popup_kind != "" or not (G.get("pendingChoice", {}) as Dictionary).is_empty()
			_check(changed, "clic gauche sur la salle %s : capacite non declenchee" % rid)
			if board._popup_kind == "choice": # la capacite ouvre un choix : il s'affiche en popup centre, avec un bouton par option
				_check(not _buttons(board._popup).is_empty(), "choix en attente : popup sans bouton")
			await _drain()
	_check(done, "aucune salle activable trouvee pour le test de clic")
	board._popup_close()
	await _check_target_spots()
	# 4) Menu engrenage : ouvre une fenetre (ne quitte PAS), OK referme
	var q0 := quit_calls
	board._on_menu_pressed()
	_check(board._popup_kind == "menu" and quit_calls == q0, "engrenage : menu non ouvert ou sortie directe")
	board._close_menu()
	_check(board._popup_kind == "", "menu non referme")
	# 5) Regles en superposition (le plateau reste en place), puis fermeture
	board._on_menu_pressed()
	board._open_rules()
	await get_tree().process_frame
	_check(board._rules != null and is_instance_valid(board._rules) and board._rules.get_parent() == board, "regles : pas de superposition sur le plateau")
	_check(RulesViewer._page_files("base").size() == 24 and board._rules.page_count == 24 and board._rules.page == 0, "regles : onglet BOSS MONSTER = %d pages (24 attendues), page %d" % [board._rules.page_count, board._rules.page])
	board._rules.turn(1)
	_check(board._rules.page == 1, "regles : page suivante")
	board._rules.turn(-2)
	_check(board._rules.page == 0, "regles : retour borne a la premiere page")
	_check(board.hand_layer != null and is_instance_valid(board.hand_layer) and board.is_inside_tree(), "regles : plateau detruit")
	board._rules.close_viewer()
	await get_tree().process_frame
	_check(board._rules == null and board._popup_kind == "menu", "regles : fermeture -> retour au menu")
	# 6) QUIT GAME : confirmation, NO revient au menu, YES quitte
	var quit_btn: Button = null
	for b in _buttons(board._popup):
		if (b as Button).text == "QUIT GAME":
			quit_btn = b
	if _check(quit_btn != null, "bouton QUIT GAME absent"):
		quit_btn.pressed.emit()
		await get_tree().process_frame
		_check(board._popup_kind == "quit" and quit_calls == q0, "confirmation de sortie absente")
		var cb: Array = board._popup.find_children("*", "TextureButton", true, false)
		(cb[0] as BaseButton).pressed.emit() # CANCEL
		await get_tree().process_frame
		_check(board._popup_kind == "menu" and quit_calls == q0, "NO : retour au menu attendu")
		board._open_quit_confirm()
		await get_tree().process_frame
		cb = board._popup.find_children("*", "TextureButton", true, false)
		(cb[1] as BaseButton).pressed.emit() # QUIT
		await get_tree().process_frame
		_check(quit_calls == q0 + 1, "YES : callback de sortie non appele")


# ---------------------------------------------------------------------------------------------------------------------
# Audio (lot 1.4) : rien ne s'entend en headless ; on verifie ce qu'AudioManager recoit (espion `rec`) contre la table de l'APK.
# Chaque ligne cite le C# (apk-original/decompiled/DBMGame) dont elle est tiree ; docs/reference/AUDIO_MATRIX.md detaille la matrice.
# ---------------------------------------------------------------------------------------------------------------------

## Attend la fin de l'animation de heros en cours (le temps de jeu est accelere : on compte les images, pas les secondes).
func _wait_anim() -> void:
	await get_tree().process_frame
	for i in 900:
		if not board._animating_hero:
			return
		await get_tree().process_frame

func _audio_since(m: int) -> Array:
	return AudioManager.rec.slice(m)

func _check_audio() -> void:
	_tag = "[audio]"
	var am = AudioManager
	# 1. fichiers : les 42 SFX et les 2 musiques existent, et tout ce que la campagne a demande existe
	_check(am.SFX_NAMES.size() == 42, "audio : %d SFX listes (42 attendus, Audio.cs)" % am.SFX_NAMES.size())
	for n in am.SFX_NAMES:
		_check(ResourceLoader.exists(am.SFX_DIR + n + ".wav"), "audio : %s.wav absent" % n)
	for n in ["music_main", "music_dungeon_v3"]:
		_check(ResourceLoader.exists(am.MUSIC_DIR + n + ".mp3"), "audio : %s.mp3 absent" % n)
	for e in am.rec:
		var kv: PackedStringArray = str(e).split(":", true, 1)
		var dir: String = am.MUSIC_DIR if kv[0] == "music" else am.SFX_DIR
		var ext := ".mp3" if kv[0] == "music" else ".wav"
		_check(ResourceLoader.exists(dir + kv[1] + ext), "audio : demande inconnue « %s »" % e)
		if not _fails.is_empty():
			break
	for n in am.SFX_NAMES:
		_check(am._cache.has(am.SFX_DIR + n + ".wav") and am._cache[am.SFX_DIR + n + ".wav"] != null, "audio : %s non precharge (LoadingScene.cs:54-56)" % n)
	# 2. volumes et voix
	_check(is_equal_approx(am.music_volume, 1.0), "audio : volume musique %s (APK : 1.0, GameSettings.cs:36 / Game.cs:98)" % am.music_volume)
	_check(am._voices.size() == 10 and am.VOICES == 10, "audio : %d voix (10 attendues, AudioService.cs:97)" % am._voices.size())
	# 3. table salle -> son (CardAssetService.cs:328-360 + RoomCategory des donnees APK)
	var room_want := {"BMA010": "sfx_room_fall", "BMA027": "sfx_room_fall", "BMA012": "sfx_room_monster_med", "BMA009": "sfx_room_undead", "BMA011": "sfx_room_undead",
		"BMA028": "sfx_room_physical", "BMA013": "sfx_room_monster_lrg", "BMA037": "sfx_room_monster_lrg", "BMA023": "sfx_room_magic", "BMA029": "sfx_room_magic",
		"THK021": "sfx_room_physical", "": "sfx_room_physical", "RMB999": "sfx_room_physical"}
	for k in room_want:
		_check(am.room_sfx(k) == room_want[k], "audio : salle « %s » -> %s (attendu %s)" % [k, am.room_sfx(k), room_want[k]])
	var cat_total := 0
	for c in am.ROOM_CATEGORY:
		cat_total += (am.ROOM_CATEGORY[c] as Array).size()
	_check(cat_total == 31, "audio : %d salles categorisees (31 dans BaseDeck)" % cat_total)
	# 4. voix des boss (CardAssetService.cs:246-300, BossInfo.IsMale) : BMA001-005 masculins, BMA006-008 et KSA001-007 feminins dans les donnees APK
	for id in ["BMA001", "BMA005", "TNL001"]:
		_check(am.boss_voice(id, "victory") == "boss_male_victory", "audio : voix de %s" % id)
	for id in ["BMA006", "BMA008", "KSA001", "KSA007"]:
		_check(am.boss_voice(id, "death") == "boss_female_death", "audio : voix de %s" % id)
	# 5. baisse de la musique sous un sting (AudioService.cs:153-164, 209-225) : x0,5 puis retour lineaire en 2 s
	am._duck_left = 0.0
	am.play_sting("sting_levelup")
	_check(is_equal_approx(am.duck_gain(), 0.5), "audio : gain %s au debut du sting (0,5 attendu)" % am.duck_gain())
	_check(is_equal_approx(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music")), linear_to_db(0.5)), "audio : le bus Music ne baisse pas de 6 dB")
	am._process(1.0)
	_check(is_equal_approx(am.duck_gain(), 0.75), "audio : gain %s apres 1 s (0,75 attendu)" % am.duck_gain())
	am._process(1.5)
	_check(is_equal_approx(am.duck_gain(), 1.0) and is_equal_approx(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music")), 0.0), "audio : la musique ne revient pas a 1.0 apres 2 s")
	# 6. boucle a compteur (AudioService.cs:129-143, 166-176)
	am.play_loop("sfx_sparklecard")
	am.play_loop("sfx_sparklecard")
	_check(am.loop_count("sfx_sparklecard") == 2 and am._loops.size() == 1, "audio : deux demandes de boucle = une seule instance")
	am.stop_loop("sfx_sparklecard")
	_check(am.loop_count("sfx_sparklecard") == 1, "audio : la boucle doit continuer tant qu'un demandeur reste")
	am.stop_loop("sfx_sparklecard")
	_check(am.loop_count("sfx_sparklecard") == 0 and am._loops.is_empty(), "audio : la boucle ne s'arrete pas au dernier demandeur")
	# 7. evenements du plateau : un jeu neuf, chaque geste note ce que l'APK joue
	await _new_game()
	board.set_process(false)
	var G: Dictionary = gm.G
	var me: Dictionary = G["players"][0]
	var m: int = am.rec.size()
	board.levelup_btn.pressed.emit() # TopRightPanelEntity.cs:155 (pas de son propre) -> GamePlayBaseScene.cs:779,1272 : zoom = ui_card_slide_up, pas le sting
	await get_tree().process_frame
	var ev := _audio_since(m)
	_check(ev == ["sfx:ui_card_slide_up"], "LEVEL UP : %s (ui_card_slide_up seul attendu)" % str(ev))
	m = am.rec.size()
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	board._input(click)
	ev = _audio_since(m)
	_check(ev == ["sfx:ui_card_slide_down"], "fermeture du zoom : %s (ui_card_slide_down attendu, GamePlayBaseScene.cs:1267)" % str(ev))
	# bulle « HAS PLAYED A » de l'adversaire (BubblesPlayerEmitter.cs:115)
	m = am.rec.size()
	board._notice_reset()
	board._show_notice("SPELL")
	_check(_audio_since(m) == ["sfx:sfx_activatecard"], "bulle adverse : %s (sfx_activatecard attendu)" % str(_audio_since(m)))
	# main : survol d'une carte puis de la suivante, puis sortie (CardPositionComponent.cs:73-100)
	m = am.rec.size()
	board._hand_last = -1
	board._hand_hover(2, true)
	board._hand_hover(2, false)
	board._hand_hover(3, true)
	await get_tree().process_frame
	board._hand_hover(1, true)
	board._hand_hover(1, false)
	await get_tree().process_frame
	ev = _audio_since(m)
	_check(ev == ["sfx:ui_shuffle_left", "sfx:ui_shuffle_left", "sfx:ui_shuffle_right", "sfx:ui_card_slide_general"], "survol de la main : %s" % str(ev))
	# arrivee du heros dans une salle (HeroCrossingBehavior.cs:72-76) : move + son de categorie, meme sans degats ; PV perdus = hurt, rendus = buff
	var dng: Array = me["dungeon"]
	dng.clear()
	var ids := ["BMA010", "BMA013", "BMA023"]
	for rid in ids:
		var r: Dictionary = CardDB.rooms.filter(func(x): return str((x as Dictionary).get("id", "")) == rid)[0].duplicate(true)
		r["isRoom"] = true
		r["faceDown"] = false
		dng.append([r])
	var hero: Dictionary = (CardDB.heroes[5] as Dictionary).duplicate(true)
	(me["entrance"] as Array).clear()
	(me["entrance"] as Array).append(hero)
	G["phase"] = "adventure"
	G.erase("buildWindow")
	var hp0: int = BossEngine.hero_hp(hero)
	board.skip_animations = false
	Engine.time_scale = ANIM_TIME_SCALE
	m = am.rec.size()
	G["adventure"] = {"playerId": 0, "hero": hero, "roomIndex": -1, "hp": hp0, "pause": "pre"}
	board.refresh()
	await _wait_anim()
	ev = _audio_since(m)
	_check(ev.has("sfx:char_hero_intro") and not ev.has("sfx:char_hero_move"), "entree du heros : %s (char_hero_intro seul attendu, GamePlayBaseScene.cs:932-934)" % str(ev))
	# [salle, PV, sons attendus, nombre de char_hero_move] : debut de pas + arrivee quand la salle change (HeroCrossingBehavior.cs:70,75), aucun si seuls les PV changent
	var step_want := [[0, hp0, ["sfx_room_fall"], 2], [1, hp0, ["sfx_room_monster_lrg"], 2], [2, hp0 - 1, ["sfx_room_magic", "char_hero_hurt"], 2], [2, hp0, ["sfx_spell_buff"], 0]]
	for sw in step_want:
		m = am.rec.size()
		(G["adventure"] as Dictionary)["roomIndex"] = sw[0]
		(G["adventure"] as Dictionary)["hp"] = sw[1]
		board.refresh()
		await _wait_anim()
		ev = _audio_since(m)
		for w in sw[2]:
			_check(ev.has("sfx:" + str(w)), "heros en salle %d (pv %d) : %s absent de %s" % [sw[0], sw[1], w, str(ev)])
		_check(ev.count("sfx:char_hero_move") == int(sw[3]), "heros en salle %d (pv %d) : %d char_hero_move attendus, vu %s" % [sw[0], sw[1], sw[3], str(ev)])
	# derniere traversee : le heros atteint le boss mort (APK : hurt puis death, voix selon IsMale)
	var boss_id: String = str(((me["boss"] as Dictionary) if me["boss"] != null else {}).get("id", ""))
	G.erase("adventure")
	(me["entrance"] as Array).clear()
	me["eliminated"] = true
	board.refresh()
	await _wait(0.4)
	m = am.rec.size()
	board._hero_pawn = null
	board._play_hero_crossing_animation({"pid": 0, "hero": hero, "initialHp": hp0, "killed": false, "deathIndex": -1})
	await _wait_anim()
	ev = _audio_since(m)
	for w in ["sfx:char_hero_attack", "sfx:" + am.boss_voice(boss_id, "hurt"), "sfx:" + am.boss_voice(boss_id, "death")]:
		_check(ev.has(w), "hero contre boss mort : %s absent de %s" % [w, str(ev)])
	Engine.time_scale = 1.0
	board.skip_animations = true
	# toute la campagne : musiques, construction (la salle posee se retourne face cachee, BuildRoomHandSceneBehavior.cs:182), clics ; jamais ui_card_flip (aucun appelant dans l'APK)
	for want in ["music:music_main", "music:music_dungeon_v3", "sfx:ui_card_slide_down", "sfx:ui_button_select", "sfx:ui_button_goback"]:
		_check(am.rec.has(want), "audio : %s jamais demande pendant la campagne" % want)
	_check(not am.rec.has("sfx:ui_card_flip"), "audio : ui_card_flip n'est joue nulle part dans l'APK")
	for e in am.rec:
		_cov("snd:" + str(e))
	_cov("audio")

# ---------------------------------------------------------------------------------------------------------------------
# Tutoriel (TutorialOverlay) : jeu de bout en bout par de vrais gestes
# ---------------------------------------------------------------------------------------------------------------------

## Avance le plateau ET le tutoriel de `secs` secondes de jeu (images de dt s) : l'horloge du tutoriel est manuelle (manual = true).
func _tut_pump(ov, secs: float, dt := 0.1) -> void:
	var t := 0.0
	while t < secs:
		t += dt
		if board != null and is_instance_valid(board):
			board._process(dt)
		if is_instance_valid(ov):
			ov.step(dt)
		await get_tree().process_frame

## Etiquette de la bulle de la scene courante (la derniere etiquette arcadepix 25).
func _tut_label(ov) -> Label:
	var out: Label = null
	if not is_instance_valid(ov) or ov._scene == null:
		return out
	for l in ov._scene.find_children("*", "Label", true, false):
		if (l as Label).get_theme_font_size("font_size") == 25 and not l.is_queued_for_deletion():
			out = l
	return out

func _tut_text(ov) -> String:
	var lb := _tut_label(ov)
	return lb.text if lb != null else ""

## Fait defiler la scene modale courante par de vrais taps (un tap saute la frappe, le suivant passe a la bulle suivante) ; rend les textes complets lus.
## typing : verifie aussi que la frappe est progressive avant le 1er tap.
func _tut_scene(ov, typing := false) -> Array:
	var seen: Array = []
	var n := 0
	var first := true
	var sc: int = ov._scene.get_instance_id() if ov._scene != null else 0 # une seule scene : la suivante (declenchee juste apres) est lue par un autre appel
	while is_instance_valid(ov) and sc != 0 and ov._scene != null and ov._scene.get_instance_id() == sc and n < 200:
		n += 1
		if not ov._tap_wait:
			await _tut_pump(ov, 0.3)
			var lb2 := _tut_label(ov)
			if typing and first and lb2 != null and not ov._tap_wait:
				_check(lb2.visible_characters >= 0 and lb2.visible_characters < lb2.text.length(), "tutoriel : la frappe n'est pas progressive (%s / %d)" % [lb2.visible_characters, lb2.text.length()])
			first = false
		if ov._tap_wait and ov._scene != null and ov._scene.get_instance_id() == sc:
			var lb := _tut_label(ov)
			_check(lb != null and lb.visible_characters == -1, "tutoriel : un tap attendu alors que la frappe n'est pas finie")
			if lb != null:
				_check(lb.get_minimum_size().y <= lb.size.y + 1.0 and lb.position.x >= 0.0 and lb.position.x + lb.size.x <= 1920.0 and lb.position.y >= 0.0, "tutoriel : le texte deborde de sa bulle (%s, %s)" % [lb.get_minimum_size(), Rect2(lb.position, lb.size)])
			seen.append(_tut_text(ov))
		await _click_at(Vector2(960, 540))
		await _tut_pump(ov, 0.1)
	_check(not is_instance_valid(ov) or ov._scene == null or ov._scene.get_instance_id() != sc, "tutoriel : la scene ne se ferme pas par des taps (%s)" % str(seen))
	return seen

func _tut_card_node(idx: int) -> CardUI:
	for c in board.hand_layer.get_children():
		if c is CardUI and not c.is_queued_for_deletion() and (c as CardUI).hand_index == idx:
			return c
	return null

## Glisse la carte de main `idx` jusqu'a `to` (appui, mouvements, relachement).
func _tut_drag(idx: int, to: Vector2) -> void:
	var node := _tut_card_node(idx)
	if not _check(node != null, "tutoriel : carte %d absente de la main affichee" % idx):
		return
	var start := node.get_global_rect().get_center()
	await _mouse(start, true, false)
	for k in range(1, 7):
		await _mouse(start.lerp(to, float(k) / 6.0), false, true, MOUSE_BUTTON_MASK_LEFT)
	await _mouse(to, false, false)

func _tut_hand_ids() -> Array:
	return (gm.G["players"][0]["hand"] as Array).map(func(c): return str((c as Dictionary).get("id", "")))

func _tut_btn(root: Node, text: String) -> BaseButton:
	for b in root.find_children("*", "BaseButton", true, false):
		if b is Button and (b as Button).text == text:
			return b
		for l in b.find_children("*", "Label", true, false):
			if (l as Label).text == text:
				return b
	return null

func _tut_step_texts(key: String) -> Array:
	var T = TutorialScript.TEXT
	match key:
		"intro1": return [T["page01"][0], T["page02"][0], T["page03"][0]]
		"intro2": return [T["page04"][0], T["page05"][0], T["page08"][0] + T["page08"][1]]
		"discard": return [TutorialScript.DISCARD_TEXT]
		"build1": return T["page13"]
		"done1": return T["page18"]
		"build2": return T["page19"]
		"done2": return [TutorialScript.HIT_DONE]
		"firstdraw": return T["page19_a"]
		"bait": return [T["page20"][0], T["page21"][0]]
		"build3": return T["page16"]
		"done3": return [TutorialScript.HIT_DONE]
		"adv22": return T["page22"]
		"adv23": return T["page23"]
		"adv24": return T["page24"]
		"adv25": return T["page25"]
		"adv26": return T["page26"]
		"adv27": return T["page27"]
		"adv28": return T["page28"]
		"adv29": return T["page29"]
		"lvl": return [T["page30"][0], T["page31"][0]]
	return []

func _check_tutorial() -> void:
	_tag = "[tutorial]"
	await _teardown()
	var cfg_path: String = ProjectSettings.globalize_path(Profile.SAVE_PATH)
	var backup := PackedByteArray()
	var had := FileAccess.file_exists(cfg_path)
	if had:
		backup = FileAccess.get_file_as_bytes(cfg_path)
		DirAccess.remove_absolute(cfg_path)
	var main = load("res://godot/scenes/Main.tscn").instantiate()
	add_child(main)
	await _wait(0.3)
	await _tut_launch_flag(main)
	await _tut_play(main)
	main.queue_free()
	await get_tree().process_frame
	board = null
	gm = null
	if had:
		var f := FileAccess.open(cfg_path, FileAccess.WRITE)
		f.store_buffer(backup)
		f.close()
	else:
		DirAccess.remove_absolute(cfg_path)
	_cov("tutorial")

## Drapeau de premier lancement : la boite TUTORIAL apparait au 1er SINGLE PLAYER (jamais ensuite), la garde du plateau est vide hors tutoriel.
func _tut_launch_flag(main) -> void:
	_check(Profile.first_gameplay(), "tutoriel : sans profil, le drapeau de premier lancement doit etre vrai")
	main.show_menu()
	await _nav(main)
	var solo := _tut_btn(main, "SINGLE PLAYER")
	if not _check(solo != null, "tutoriel : bouton SINGLE PLAYER introuvable"):
		return
	solo.pressed.emit()
	await get_tree().process_frame
	var box = main.find_child("ConfirmationBox", true, false)
	if _check(box != null, "tutoriel : pas de boite au 1er SINGLE PLAYER"):
		var txt := _texts_of(box)
		_check(txt.has("TUTORIAL") and txt.has("DO YOU WANT TO PLAY A TUTORIAL GAME?"), "tutoriel : textes de la boite %s" % str(txt))
		_check(box.find_child("Ok", true, false) != null and box.find_child("Cancel", true, false) != null, "tutoriel : boutons OK / CANCEL de la boite")
		(box.find_child("Cancel", true, false) as BaseButton).pressed.emit()
		await _nav(main)
		_check(not Profile.first_gameplay(), "tutoriel : CANCEL doit consommer le drapeau")
		_check(_texts_of(main).has("HOW MANY PLAYERS?"), "tutoriel : CANCEL doit mener a HOW MANY PLAYERS?")
	main.show_menu()
	await _nav(main)
	_tut_btn(main, "SINGLE PLAYER").pressed.emit()
	await get_tree().process_frame
	_check(main.find_child("ConfirmationBox", true, false) == null, "tutoriel : la boite ne revient pas apres CANCEL")
	await _nav(main)
	# partie normale : garde vide, aucun tutoriel
	main.start_match(2)
	await _wait(0.3)
	var b = main.board
	if _check(b != null, "tutoriel : partie normale absente"):
		_check(not b.tutorial_gate.is_valid() and b.find_children("TutorialOverlay", "", true, false).is_empty(), "tutoriel : la partie normale porte un tutoriel / une garde")
		_check(b._tg("run") == true and b._tg("input", null) == true and b._tg("drag", 0) == true and str(b._tg("boss", [], "")) == "" and b._tg("levelup") == true, "tutoriel : la garde vide doit tout laisser passer")
	main.show_menu()
	await _nav(main)

func _tut_play(main) -> void:
	# OPTIONS -> TUTORIAL : lance aussi le tutoriel (et le drapeau reste faux)
	main.show_options()
	await _nav(main)
	var ob := _tut_btn(main, "TUTORIAL")
	if _check(ob != null, "tutoriel : bouton TUTORIAL absent des OPTIONS"):
		ob.pressed.emit()
		await _wait(0.3)
		_check(main.board != null and not main.board.find_children("TutorialOverlay", "", true, false).is_empty(), "tutoriel : OPTIONS > TUTORIAL ne lance pas le tutoriel")
	main.show_menu()
	await _nav(main)
	# boite de premier lancement : OK lance le tutoriel
	Profile.set_first_gameplay(true)
	_tut_btn(main, "SINGLE PLAYER").pressed.emit()
	await get_tree().process_frame
	var box = main.find_child("ConfirmationBox", true, false)
	if not _check(box != null, "tutoriel : boite absente (drapeau remis a vrai)"):
		return
	(box.find_child("Ok", true, false) as BaseButton).pressed.emit()
	await _wait(0.3)
	_check(not Profile.first_gameplay(), "tutoriel : OK doit consommer le drapeau")
	board = main.board
	gm = main.game_manager
	if not _check(board != null, "tutoriel : pas de plateau apres OK"):
		return
	var ovs: Array = board.find_children("TutorialOverlay", "", true, false)
	if not _check(ovs.size() == 1, "tutoriel : %d surcouches" % ovs.size()):
		return
	var ov = ovs[0]
	ov.manual = true
	board.skip_animations = true
	board.set_process(false)
	var texts := {}
	var t0 := Time.get_ticks_msec()
	var probed := {}
	var last_sig := ""
	var stuck := 0
	var post := 0
	for it in 5000:
		if not _fails.is_empty() or not _log.errors.is_empty():
			break
		if not is_instance_valid(ov):
			if post == 0:
				probed["turn_end"] = int(gm.G.get("turn", 0))
			post += 1
			if post > 400 or gm.G.get("gameOver") != null: # le jeu continue normalement apres le tutoriel
				break
			board._process(0.21)
			await get_tree().process_frame
			_act_simple()
			continue
		await _tut_pump(ov, 0.1)
		if not is_instance_valid(ov):
			continue
		var G: Dictionary = gm.G
		var me: Dictionary = G["players"][0]
		var sig := JSON.stringify([G.get("phase"), G.get("turn"), (G.get("log", []) as Array).size(), ov._done.size(), ov._scene != null, (me["hand"] as Array).size(), (G.get("stack", []) as Array).size(), G.get("pendingChoice", {})])
		stuck = stuck + 1 if sig == last_sig else 0
		last_sig = sig
		if stuck > 250:
			_fail("tutoriel : partie bloquee (%s) etapes=%s adv=%s" % [sig.left(160), str(ov._done.keys()), str((G.get("adventure", {}) as Dictionary).get("roomIndex"))])
			break
		if ov._scene != null:
			var key: String = str(ov._done.keys().back()) if not ov._done.is_empty() else ""
			if key == "discard" and not texts.has("discard"): # le voile capte les taps : une carte cliquee sous la scene n'est pas choisie
				await _tut_click_card(0)
				_check(board.discard_pick.is_empty(), "tutoriel : un tap sur une carte sous la scene a choisi la carte")
			var seen: Array = await _tut_scene(ov, key == "intro1" and not texts.has("intro1"))
			if not texts.has(key):
				texts[key] = seen
			continue
		var phase := str(G.get("phase", ""))
		if phase == "boss" and me.get("boss") == null:
			if board._boss_ready and board._confirm_btn.visible:
				_check(board._boss_pick_id == "BMA003", "tutoriel : le carrousel doit s'arreter sur King Croak (%s)" % board._boss_pick_id)
				board._confirm_btn.pressed.emit()
			continue
		if ov._discard_pending():
			if ov._done.has("discard") and not probed.has("discard"):
				probed["discard"] = true
				await _tut_discard(ov)
			continue
		var fid: String = ov._forced_id()
		if fid != "":
			await _tut_forced(ov, fid, probed)
			continue
		if ov._hit_state():
			await _tut_hit(ov, probed)
			continue
		if ov._restricted() and (phase == "setup" or phase == "build") and int(me.get("buildsThisTurn", 0)) >= 1 and board.pass_shown() and board.btn_pass.is_visible_in_tree() and gm.active_player() == 0:
			await _click_at(board.btn_pass.get_global_rect().get_center())
			continue
		if not ov._restricted() and not G.get("gameOver"): # reste de la partie : plus aucune consigne, le joueur simule joue
			_act_simple()
	var dt_real := (Time.get_ticks_msec() - t0) / 1000.0
	print("UISMOKE tutoriel : %.1fs, etapes %s" % [dt_real, str(texts.keys())])
	for key in texts:
		var want: Array = _tut_step_texts(key)
		_check(not want.is_empty() and texts[key] == want, "tutoriel : etape %s : textes %s au lieu de %s" % [key, str(texts[key]), str(want)])
	var order := ["intro1", "intro2", "discard", "build1", "done1", "build2", "done2", "firstdraw", "bait", "build3", "done3", "adv22", "adv23", "adv26", "adv27", "adv28", "adv29", "adv25", "lvl"]
	for k in order:
		# adv25 (blessure de l'IA) est exigee comme les autres : graine fixe, le sort BMA041 joue a l'entree donne +3 PV au mage 068 (Match.gd / BossEngine.spend_hero_health_bonus),
		# il survit au donjon de l'IA et devient sa blessure au tour 1 ; l'overlay la capte sur l'etat (blessure + tour), pas sur une fenetre de quelques ms.
		_check(texts.has(k), "tutoriel : l'etape %s n'a jamais ete montree" % k)
	var seen_order: Array = texts.keys().filter(func(k): return order.has(k))
	_check(seen_order == order, "tutoriel : ordre des etapes %s au lieu de %s" % [str(seen_order), str(order)])
	_check(not is_instance_valid(ov), "tutoriel : la surcouche reste apres le LEVEL UP")
	_check(gm.G.get("gameOver") != null or int(gm.G.get("turn", 0)) > int(probed.get("turn_end", 99)), "tutoriel : la partie ne continue pas apres le LEVEL UP (tour %s)" % gm.G.get("turn"))
	_check(not board.tutorial_gate.is_valid() and board._tg("run") == true, "tutoriel : la garde reste apres le LEVEL UP")

## Clic de souris sur la partie gauche (jamais recouverte) de la carte de main `idx` : atteint la bonne carte meme dans l'eventail / la rangee de defausse.
func _tut_click_card(idx: int) -> void:
	var node := _tut_card_node(idx)
	if _check(node != null, "tutoriel : carte %d absente de la main affichee" % idx):
		var r: Rect2 = node.get_global_rect()
		await _click_at(Vector2(r.position.x + 25.0, r.get_center().y))

func _tut_hint_text(ov) -> String:
	if ov._hint == null or not is_instance_valid(ov._hint):
		return ""
	var ls: Array = ov._hint.find_children("*", "Label", true, false)
	return (ls[0] as Label).text if not ls.is_empty() else ""

## Defausse d'ouverture : seules les 2 cartes designees se choisissent (jamais deselectionnees), les autres affichent une moquerie du boss.
func _tut_discard(ov) -> void:
	var hand: Array = gm.G["players"][0]["hand"]
	var rights: Array = []
	var wrongs: Array = []
	for i in hand.size():
		if TutorialScript.CARD_DISCARD.has(str((hand[i] as Dictionary).get("id", ""))):
			rights.append(i)
		else:
			wrongs.append(i)
	if not _check(rights.size() == 2 and hand.size() == 7, "tutoriel : defausse : %d cartes designees dans une main de %d" % [rights.size(), hand.size()]):
		return
	_check(ov._ptrs.size() == 2, "tutoriel : defausse : %d mains sur les cartes designees (2 attendues)" % ov._ptrs.size())
	await _tut_click_card(int(wrongs[0]))
	_check(board.discard_pick.is_empty() and TutorialScript.WRONG_PICK.has(_tut_hint_text(ov)), "tutoriel : defausse : une mauvaise carte doit etre refusee avec une moquerie (%s)" % _tut_hint_text(ov))
	await _tut_click_card(int(rights[0]))
	_check(board.discard_pick.size() == 1 and TutorialScript.RIGHT_PICK.has(_tut_hint_text(ov)), "tutoriel : defausse : la bonne carte doit etre choisie avec un encouragement (%s)" % _tut_hint_text(ov))
	_check(not board._confirm_btn.visible, "tutoriel : defausse : CONTINUE visible avec une seule carte")
	await _tut_click_card(int(rights[0]))
	_check(board.discard_pick.size() == 1, "tutoriel : defausse : la carte choisie ne se deselectionne pas")
	await _tut_pump(ov, 0.7)
	_check(ov._ptrs.size() == 1, "tutoriel : defausse : la main de la carte choisie doit disparaitre (%d restantes)" % ov._ptrs.size())
	await _tut_click_card(int(rights[1]))
	_check(board.discard_pick.size() == 2 and _tut_hint_text(ov) == TutorialScript.CLICK_CONTINUE, "tutoriel : defausse : 2e carte -> HIT CONTINUE, MINION (%s)" % _tut_hint_text(ov))
	await _tut_click_card(int(wrongs[1]))
	_check(board.discard_pick.size() == 2, "tutoriel : defausse : une 3e carte ne se choisit pas")
	_check(board._confirm_btn.visible, "tutoriel : defausse : CONTINUE absent avec 2 cartes")
	await _click_at(board._confirm_btn.get_global_rect().get_center())
	await _tut_pump(ov, 0.3)
	var ids := _tut_hand_ids()
	_check(ids.size() == 5 and not ids.has("BMA026") and not ids.has("BMA055"), "tutoriel : defausse : la main doit garder 5 cartes sans BMA026 / BMA055 (%s)" % str(ids))

## Carte imposee : une mauvaise carte / DONE verrouille -> rappel de la consigne ; la bonne carte se glisse sur son emplacement (ou sur le heros pour le sort).
func _tut_forced(ov, fid: String, probed: Dictionary) -> void:
	var G: Dictionary = gm.G
	var me: Dictionary = G["players"][0]
	var hand: Array = me["hand"]
	var fi: int = ov._hand_idx(fid)
	var spell: bool = fid == TutorialScript.SPELL
	var dsize: int = (me["dungeon"] as Array).size()
	var to: Vector2 = board._lane[0]["entrance"].get_global_rect().get_center() if spell else (board._dungeon_slots[maxi(0, DUNGEON_N - dsize - 1)] as Control).get_global_rect().get_center()
	var key := "%s:%s" % [G.get("phase"), fid]
	if spell and not ov._done.has("adv27"):
		return # les scenes p26 puis p27 passent d'abord (la partie est figee)
	if not probed.has(key):
		probed[key] = true
		var page: String = "page27" if spell else ("page13" if str(G.get("phase")) == "setup" else ("page19" if G.get("setupForced") != null and int(G.get("turn", 0)) == 0 else "page16"))
		var want: String = TutorialScript.TEXT[page][0]
		var n_hand := hand.size()
		# une autre carte de la main : ni glissable ni cliquable (le clic ne fait rien, le glisser rappelle la consigne)
		var other := -1
		for i in hand.size():
			if i != fi:
				other = i
				break
		await _tut_click_card(other)
		_check(ov._scene == null and board._popup_kind == "" and board._tgt.is_empty() and hand.size() == n_hand, "tutoriel : %s : un clic sur une autre carte ne doit rien faire" % key)
		await _tut_drag(other, to)
		await _tut_pump(ov, 0.3)
		_check(board._drag.is_empty() and hand.size() == n_hand and (me["dungeon"] as Array).size() == dsize and (G.get("stack", []) as Array).is_empty(), "tutoriel : %s : une autre carte ne doit pas se glisser" % key)
		if spell: # GamePlayTutScene.ShowReinforcementScene n'a pas de cas aventure : une mauvaise carte est seulement refusee
			_check(ov._scene == null, "tutoriel : %s : pas de rappel en aventure (ShowReinforcementScene)" % key)
		elif _check(ov._scene != null, "tutoriel : %s : pas de rappel de la consigne apres une mauvaise carte" % key):
			var seen := await _tut_scene(ov)
			_check(seen == [want], "tutoriel : %s : rappel %s au lieu de %s" % [key, str(seen), want])
		if not spell and board.pass_shown() and board.btn_pass.is_visible_in_tree():
			var ph0 := str(G.get("phase"))
			await _click_at(board.btn_pass.get_global_rect().get_center())
			await _tut_pump(ov, 0.3)
			_check(str(G.get("phase")) == ph0 and hand.size() == n_hand, "tutoriel : %s : DONE doit rester bloque" % key)
			if _check(ov._scene != null, "tutoriel : %s : DONE bloque sans rappel de la consigne" % key):
				var seen2 := await _tut_scene(ov)
				_check(seen2 == [want], "tutoriel : %s : rappel de DONE %s au lieu de %s" % [key, str(seen2), want])
		if spell:
			# relache loin du heros : rien ne se joue
			await _tut_drag(fi, Vector2(300, 300))
			await _tut_pump(ov, 0.2)
			_check((G.get("stack", []) as Array).is_empty() and ov._hand_idx(fid) >= 0, "tutoriel : %s : un sort lache loin du heros ne doit pas se jouer" % key)
			# la consigne se rejoue au bout de NAG secondes sans geste
			await _tut_pump(ov, TutorialScript.NAG + 0.5)
			if _check(ov._scene != null, "tutoriel : %s : la consigne n'est pas rejouee apres %d s" % [key, int(TutorialScript.NAG)]):
				var seen3 := await _tut_scene(ov)
				_check(seen3 == [want], "tutoriel : %s : rappel p27 %s" % [key, str(seen3)])
		return
	var n0 := hand.size()
	await _tut_drag(fi, to)
	await _tut_pump(ov, 0.2)
	if spell:
		_check(ov._hand_idx(fid) < 0, "tutoriel : %s : le sort glisse sur le heros n'est pas parti de la main" % key)
	else:
		_check(hand.size() == n0 - 1 and (me["dungeon"] as Array).size() == dsize + 1, "tutoriel : %s : la salle n'est pas construite (main %d -> %d, donjon %d -> %d)" % [key, n0, hand.size(), dsize, (me["dungeon"] as Array).size()])

## Hero 064 dans BMA027 : la partie attend le joueur ; la consigne se rejoue au bout de 8 s ; un tap sur la salle ouvre sa description (p24), un tap sur la capacite frappe.
func _tut_hit(ov, probed: Dictionary) -> void:
	var G: Dictionary = gm.G
	if not probed.has("hit"):
		probed["hit"] = true
		var adv0: Dictionary = (G["adventure"] as Dictionary).duplicate()
		adv0.erase("hero")
		await _tut_pump(ov, 3.0)
		var adv1: Dictionary = (G["adventure"] as Dictionary).duplicate()
		adv1.erase("hero")
		_check(adv0 == adv1 and ov._hit_state(), "tutoriel : le heros avance alors que la consigne attend le joueur")
		await _tut_pump(ov, 6.0)
		if _check(ov._scene != null, "tutoriel : la consigne de la salle n'est pas rejouee apres 8 s d'attente"):
			var seen := await _tut_scene(ov)
			_check(seen == [TutorialScript.TEXT["page23"][0]], "tutoriel : rappel p23 %s" % str(seen))
		return
	if ov._scene != null:
		return
	var sl: Control = ov._slot_node(0)
	if not _check(sl != null, "tutoriel : salle BMA027 absente"):
		return
	await _click_at(sl.get_global_rect().get_center())
	await _tut_pump(ov, 0.3)
	if board._zoom == null:
		return
	if not _check(ov._scene != null, "tutoriel : le tap sur la salle n'ouvre pas la scene p24"):
		return
	var seen2 := await _tut_scene(ov)
	_check(seen2 == TutorialScript.TEXT["page24"], "tutoriel : p24 %s" % str(seen2))
	var ab: Rect2 = board._zoom.get_meta("ability")["rect"]
	await _click_at(board._zoom.get_global_transform() * ab.get_center())
	await _tut_pump(ov, 0.3)
	_check(not ov._hit_state(), "tutoriel : le tap sur la capacite n'a pas frappe le heros")
