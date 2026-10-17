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
##   --players=P    2|3|4 (defaut : alterne 2,2,3,4)               --humans=H    sieges humains (defaut 1 ; 0 = IA seulement)
##   --sets=a,b     paquets (ex. players-choice,hidden-heroes,tools,next-level,crash-landing,minibosses ; defaut base)
##   --style=S      random | spells | passive (defaut : alterne)    --turns=N     arrete apres N tours au lieu d'aller a la fin
##   --anim         animations de traversee des heros reelles (temps accelere x6) pour toutes les parties
## Chaque anomalie est affichee avec sa graine : « [seed=7 players=3 ...] ... » = la commande pour la rejouer.

const GameManager = preload("res://godot/scripts/GameManager.gd")

const DUNGEON_N := 5
const MAX_STEPS := 6000
const STUCK_ITERS := 150
const ANIM_TIME_SCALE := 6.0
const BOSS_WAIT := 0.9                # retournement du carrousel : 0,65 s de jeu (le temps est deja accelere par ANIM_TIME_SCALE)
const STYLES := {
	"random": {"build": 3.0, "drop": 3.0, "spell": 2.0, "ability": 2.0, "extra": 1.5, "pass": 1.0, "go": 3.0, "noise": 0.08},
	"spells": {"build": 1.5, "drop": 1.5, "spell": 6.0, "ability": 6.0, "extra": 4.0, "pass": 0.4, "go": 3.0, "noise": 0.08},
	"passive": {"build": 4.0, "drop": 2.0, "spell": 0.0, "ability": 0.0, "extra": 0.0, "pass": 3.0, "go": 3.0, "noise": 0.04},
}
const CORE_TYPES := ["pickBoss", "buildRoom", "pass", "passBuild", "adventureNext", "resolveNextHero", "openingDiscard", "resolveLevelUpChoice", "resolveChoice", "playSpell", "useHandRoom", "activateRoom"]

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
	var d := {"turns": 0, "games": 0, "seed": -1, "players": 0, "humans": 1, "sets": ["base"], "style": "", "anim": false}
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
	return d

func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout

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
	var games: Array = []
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
		games.append({"seed": 25, "players": 2, "humans": 1, "sets": ["players-choice", "hidden-heroes", "tools", "next-level", "crash-landing", "minibosses"], "style": "spells", "anim": false, "turns": 5})
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
	var moves: Array = gm.legal_moves(pid)
	var pc: Dictionary = G.get("pendingChoice", {})
	if not pc.is_empty():
		await _act_choice(pid, pc, moves)
		return
	if str(G.get("phase", "")) == "boss":
		if board._boss_flipping: # PLAY BOSS MONSTER! presse : les cartes se retournent (animation), on attend la fin
			await _wait(0.1)
			return
		var cards := _hand_cards()
		if _check(not cards.is_empty(), "choix du boss : aucune carte a l'ecran"):
			await _act_boss_pick(pid, G, rng.randi_range(0, cards.size() - 1))
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

## Carrousel du choix du boss : un clic sur une carte la ramene au centre (les autres sont reduites et derriere), PLAY BOSS MONSTER! valide.
func _act_boss_pick(pid: int, G: Dictionary, k: int) -> void:
	var picks: Array = G["bossPicks"]
	var bc: Array = board._boss_cards
	if not _check(bc.size() == picks.size() and k < bc.size(), "choix du boss : %d cartes pour %d propositions" % [bc.size(), picks.size()]):
		return
	var want := str((picks[k] as Dictionary).get("id", ""))
	(bc[k] as CardUI).card_clicked.emit(null)
	if not board.skip_animations:
		await _wait(0.4)
	_check(board._boss_sel == k, "choix du boss : clic sur la carte %d, centre = %d" % [k, board._boss_sel])
	_check_boss_layout()
	_check(board._confirm_btn.visible and board._confirm_btn.text == "PLAY BOSS MONSTER!", "choix du boss : bouton PLAY BOSS MONSTER! absent")
	var before := _sig()
	board._confirm_btn.pressed.emit()
	_cov("boss_pick")
	if not board.skip_animations: # retournement des autres cartes (0,65 s de jeu) puis le coup part
		_check(board._boss_flipping, "choix du boss : pas de retournement des autres cartes")
		await _wait(BOSS_WAIT)
	_check(_sig() != before, "choix du boss : PLAY BOSS MONSTER! n'a eu aucun effet")
	var boss = (G["players"][pid] as Dictionary).get("boss")
	_check(boss != null and str((boss as Dictionary).get("id", "")) == want, "choix du boss : le boss choisi n'est pas la carte centrale (%s)" % want)

## Geometrie du carrousel : carte centrale pleine taille au centre ; les autres plus petites, de part et d'autre, la plus proche devant.
func _check_boss_layout() -> void:
	var bc: Array = board._boss_cards
	var cards := _hand_cards()
	for i in bc.size():
		var c: Control = bc[i]
		var d: int = i - board._boss_sel
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
	# Mon couloir : 3 emplacements remplis, piles de 1, 2 et 3 salles -> 0, 1 et 2 salles recouvertes
	var seen := {}
	for sl in board._dungeon_slots:
		var d := sl as DungeonSlot
		var unders := d.get_children().filter(func(c): return c.is_in_group("under_card"))
		var want: int = maxi(d.current_stack.size() - 1, 0)
		_check(unders.size() == want, "pile de %d salles : %d cartes recouvertes dessinees (%d attendues)" % [d.current_stack.size(), unders.size(), want])
		for k in unders.size(): # la plus profonde d'abord, chacune 28 px plus haut que la suivante
			var depth := unders.size() - k
			_check(is_equal_approx((unders[k] as Control).position.y, -28.0 * depth) and (unders[k] as Control).mouse_filter == Control.MOUSE_FILTER_IGNORE, "carte recouverte %d a y=%s (-%d attendu)" % [k, (unders[k] as Control).position.y, 28 * depth])
		if not unders.is_empty():
			_check(unders[unders.size() - 1].get_index() < d.card_container.get_index(), "la salle recouverte doit etre derriere la salle du dessus")
		seen[unders.size()] = true
	_check(seen.has(0) and seen.has(1) and seen.has(2), "piles : tailles vues %s" % str(seen.keys()))
	# Couloir adverse (Controls simples) : memes cartes recouvertes
	var foe_unders := 0
	for sc in board._foe_slots:
		foe_unders += (sc as Control).get_children().filter(func(c): return c.is_in_group("under_card")).size()
	_check(foe_unders == 3, "couloir adverse : %d cartes recouvertes (3 attendues)" % foe_unders)
	# Un rafraichissement ne duplique pas les cartes recouvertes
	board.refresh()
	await get_tree().process_frame
	var again := 0
	for sl in board._dungeon_slots:
		again += (sl as Control).get_children().filter(func(c): return c.is_in_group("under_card") and not c.is_queued_for_deletion()).size()
	_check(again == 3, "piles : %d cartes recouvertes apres un 2e rafraichissement (3 attendues)" % again)
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
	for k in extras.size():
		var ki := k
		out.append({"kind": "extra", "w": _style_w("extra"), "desc": "coup extension %s" % str(extras[k]["type"]), "run": func(): await _do_extra(ki)})
	if has_go and not board._apk_flow():
		out.append({"kind": "go", "w": _style_w("go"), "desc": "GO", "run": func(): await _do_button(board.btn_advance, "GO")})
	elif has_go:
		_cov("go_auto") # flux APK : pas de bouton GO, le heros suivant avance de lui-meme (board._process / _auto_pass)
	if has_pass and board.btn_pass.visible:
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
		btn.pressed.emit()

func _do_build_click(pid: int, idx: int) -> void:
	var cards := _hand_cards()
	var hand: Array = gm.G["players"][pid]["hand"]
	if _check(idx < cards.size() and cards.size() == hand.size(), "construire : la main affichee (%d) != main reelle (%d)" % [cards.size(), hand.size()]):
		_check((cards[idx] as CardUI).texture_rect.material == null, "construire : la carte %d est grisee alors que le coup est legal" % idx)
		var dsize: int = (gm.G["players"][pid]["dungeon"] as Array).size()
		if not gm.can_build_room_at(pid, idx, dsize):
			# legal_moves propose buildRoom mais BossEngine.can_build_room(carte) refuse (ex. apres Kobold Strike : buildBlocked) : anomalie MOTEUR
			_engine_note("buildRoom legal mais can_build_room refuse (buildBlocked=%s)" % str((gm.G.get("effects", {}) as Dictionary).get("buildBlocked")))
			_cancelled = true
			return
		var n_menu := _n_build_targets(pid, idx) + _n_hand_uses(pid, idx) # comptes AVANT le clic : une pose directe change les coups legaux
		(cards[idx] as CardUI).card_clicked.emit(null)
		await _pick_target(n_menu, "construire (carte %d)" % idx) # plusieurs emplacements (A3) : le joueur choisit lequel

## Emplacements de construction offerts par le moteur pour la carte `idx` (salles recouvrables + emplacement libre).
func _n_build_targets(pid: int, idx: int) -> int:
	return gm.legal_moves(pid).filter(func(m): return m["type"] == "buildRoom" and int(m["args"][0]) == idx).size()

## Autres coups de la carte `idx` (sort, capacite de main, DISCARD: +1 COIN...) : entrees de son menu, avec ou sans construction.
func _n_hand_uses(pid: int, idx: int) -> int:
	return gm.legal_moves(pid).filter(func(m): return m["type"] != "buildRoom" and BoardUI.hand_idx_of(m) == idx).size()

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
	_check((cards[idx] as CardUI).texture_rect.material == null, "carte jouable %s grisee" % cname)
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
	if _check(btn.visible and btn.text == "CONTINUE" and (cards[k] as CardUI).scale.x > 1.5, "%s : carte choisie sans CONTINUE ni agrandissement" % what):
		(cards[k] as CardUI).card_clicked.emit(null) # re-appui = deselection
		_check(btn.visible == has_skip and (cards[k] as CardUI).scale.x == 1.0, "%s : la deselection ne remet pas l'etat initial" % what)
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
		var gold := _buttons(board.foe_bar).filter(func(b): return (b as Button).has_theme_color_override("font_color") and not (b as Button).disabled)
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
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT if rng.randf() < 0.7 else MOUSE_BUTTON_RIGHT
	ev.pressed = true
	slot._gui_input(ev)
	await _pick_target(cands.size(), "capacite salle %d" % di)

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
	board._on_hand_card_clicked(int(order[2]), hand[int(order[2])]) # une 3e est ignoree
	_check(board.discard_pick.size() == 2, "defausse : 3 cartes selectionnables")
	var n_before := hand.size()
	board._confirm_btn.pressed.emit()
	await get_tree().process_frame
	_check((gm.G["players"][pid]["hand"] as Array).size() == n_before - 2 or not (gm.G.get("pendingChoice", {}) as Dictionary).is_empty(), "defausse : la main n'a pas perdu 2 cartes")
	_check(board.discard_pick.is_empty(), "defausse : selection non remise a zero")
	_cov("opening_discard")

## Gestes parasites : ne doivent rien casser ni changer l'etat de la partie.
func _noise(pid: int) -> void:
	var G: Dictionary = gm.G
	var s0 := _sig()
	match rng.randi_range(0, 6):
		0: # clic sur une carte de la main sans coup legal
			var hand: Array = G["players"][pid]["hand"]
			var playable := {}
			for m in gm.legal_moves(pid):
				if BoardUI.hand_idx_of(m) >= 0:
					playable[BoardUI.hand_idx_of(m)] = true
			for i in hand.size():
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
				if not (sl as DungeonSlot).activatable:
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
		3: # pile de defausse : la fenetre se ferme et se libere
			board._on_discard_pile_pressed()
			await get_tree().process_frame
			var dlgs: Array = board.get_children().filter(func(c): return c is AcceptDialog and not c.is_queued_for_deletion())
			if _check(dlgs.size() == 1, "pile de defausse : %d fenetres ouvertes" % dlgs.size()):
				(dlgs[0] as AcceptDialog).get_ok_button().pressed.emit()
				await get_tree().process_frame
				await get_tree().process_frame
				var left: Array = board.get_children().filter(func(c): return c is AcceptDialog and not c.is_queued_for_deletion())
				_check(left.is_empty(), "pile de defausse : la fenetre fermee n'est pas liberee (%d restent)" % left.size())
			_check(_sig() == s0, "pile de defausse : l'etat a change")
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
			var fb: Container = board.foe_bar
			var bs := _buttons(fb).filter(func(b): return not (b as Button).disabled)
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
	var want_cards := 0
	if not over:
		want_cards = (G["bossPicks"] as Array).size() if phase == "boss" else (p["hand"] as Array).size()
	var got_cards := _hand_cards().size()
	_check(got_cards == want_cards, "main : %d cartes a l'ecran pour %d (phase %s, siege %d)" % [got_cards, want_cards, phase, pid])
	# pioches, ville
	var decks: Dictionary = G["decks"]
	_check(board.room_deck_label.text == "x%d" % (decks["rooms"] as Array).size(), "pioche de salles : %s != x%d" % [board.room_deck_label.text, (decks["rooms"] as Array).size()])
	_check(board.spell_deck_label.text == "x%d" % (decks["spells"] as Array).size(), "pioche de sorts : %s != x%d" % [board.spell_deck_label.text, (decks["spells"] as Array).size()])
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
	var my_moves: Array = gm.legal_moves(pid)
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
		_check(not board.btn_pass.is_visible_in_tree(), "aventure : PASS TURN visible (l'APK n'en a pas, voir la barre de temps)")
	var pass_vis: bool = board.btn_pass.is_visible_in_tree()
	if pass_vis:
		_check(can_pass and not over, "bouton PASS TURN visible alors que passer est illegal (phase %s, fin=%s, siege %d)" % [phase, over, pid])
	var extra_vis: bool = board.extra_bar.visible and board.extra_bar.get_children().filter(func(c): return not c.is_queued_for_deletion()).size() > 0
	_check(extra_vis == (extras > 0 and pc.is_empty()), "barre d'extensions : %s pour %d coups d'extension" % ["visible" if extra_vis else "cachee", extras])
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
		_check(board._confirm_btn.visible and board._confirm_btn.text == "PLAY BOSS MONSTER!", "choix du boss : bouton PLAY BOSS MONSTER! absent")
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
	_check((L["lvl"] as Label).text == ("2" if bool(pl.get("leveledUp", false)) else "1"), "%s : niveau %s pour leveledUp=%s" % [what, (L["lvl"] as Label).text, pl.get("leveledUp")])
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
			_check(_hand_cards().is_empty(), "fin de partie : cartes encore en main a l'ecran")
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
			var yes := _buttons(board._popup)
			if _check(board._popup_kind == "quit" and yes.size() == 2, "fin de partie : confirmation de sortie absente"):
				(yes[0] as Button).pressed.emit()
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
			if me.get("boss") == null:
				if not board._boss_cards.is_empty():
					board._boss_cards[0].card_clicked.emit(null)
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
				board._on_pass_pressed()
		"adventure":
			var types: Array = gm.legal_moves(0).map(func(m): return m["type"])
			if types.has("adventureNext"):
				board._on_advance_pressed()
			elif types.has("passBuild") or types.has("pass"):
				board._on_pass_pressed()

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
	gm.start_new_game(2, 1, ["players-choice", "hidden-heroes", "tools", "next-level", "crash-landing", "minibosses"])
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
		main.start_match(n, 1)
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
		var yes := _buttons(board._popup)
		if _check(yes.size() == 2, "Main : confirmation de sortie"):
			(yes[0] as Button).pressed.emit()
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
	(me["entrance"] as Array).append(h_a)
	(foe["entrance"] as Array).append(h_b)
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
	board._target_list("test", "Select a target", entries, Callable())
	for i in 3:
		await get_tree().process_frame
	_check(board._tgt_spots.size() == specs.size() - 1, "zones allumees : %d (%d attendues, 2 coups sur la salle)" % [board._tgt_spots.size(), specs.size() - 1])
	var lifted: Array = board._tgt_lifted.duplicate()
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

## Carrousel du choix du boss (apk_boss00) : carte centrale, voisines reduites, clic / selection, validation, boss adverse cache.
func _check_boss_carousel() -> void:
	_tag = "[boss-carousel]"
	await _teardown()
	CardDB._rng.seed = 99
	gm = GameManager.new()
	add_child(gm)
	gm.start_new_game(2, 1, ["base"])
	board = load("res://godot/scenes/Board.tscn").instantiate()
	board.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(board)
	board.skip_animations = true
	board.setup(gm, func(): quit_calls += 1)
	await _wait(0.1)
	var picks: Array = gm.G["bossPicks"]
	var bc: Array = board._boss_cards
	if not _check(picks.size() >= 3 and bc.size() == picks.size() and board._boss_sel == 0, "carrousel : %d cartes pour %d propositions (centre %d)" % [bc.size(), picks.size(), board._boss_sel]):
		return
	_check_boss_layout()
	await _check_boss_drag()
	_check_boss_layout()
	_check(board._confirm_btn.visible and board._confirm_btn.text == "PLAY BOSS MONSTER!" and board._confirm_btn.size.x >= 390.0, "carrousel : bouton PLAY BOSS MONSTER! absent")
	_check(board._dim.visible and board._dim.size == Vector2(1920, 1080), "carrousel : tout l'ecran doit s'assombrir (panneaux et plaque compris)")
	_check(board.foe_name_label.text == "", "carrousel : le boss adverse est visible")
	for k in [1, bc.size() - 1, 0]:
		(bc[k] as CardUI).card_clicked.emit(null)
		await get_tree().process_frame
		_check(board._boss_sel == k, "carrousel : clic sur la carte %d, centre %d" % [k, board._boss_sel])
		_check_boss_layout()
	board._boss_select(99) # hors limites : borne
	_check(board._boss_sel == bc.size() - 1, "carrousel : selection hors limites non bornee (%d)" % board._boss_sel)
	board._boss_select(-3)
	_check(board._boss_sel == 0, "carrousel : selection negative non bornee (%d)" % board._boss_sel)
	(bc[1] as CardUI).card_clicked.emit(null)
	_check(gm.G["players"][0].get("boss") == null, "carrousel : un clic sur une carte ne doit pas valider le boss")
	var want := str((picks[1] as Dictionary).get("id", ""))
	board._confirm_btn.pressed.emit()
	await get_tree().process_frame
	var boss = gm.G["players"][0].get("boss")
	_check(boss != null and str((boss as Dictionary).get("id", "")) == want, "carrousel : PLAY BOSS MONSTER! n'a pas valide la carte centrale (%s)" % want)
	_check(board._boss_sel == 0, "carrousel : centre non remis a zero")
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

func _check_boss_drag() -> void:
	var bc: Array = board._boss_cards
	board._boss_select(0)
	# glisser vers la gauche de ~100 px depuis le vide (hors cartes) : carte suivante au centre
	await _drag(Vector2(1500, 840), Vector2(1400, 840))
	_check(board._boss_sel == 1, "glisser : -100 px -> carte %d (1 attendue)" % board._boss_sel)
	# vers la droite de 200 px : deux crans en arriere, borne a 0
	await _drag(Vector2(1000, 840), Vector2(1200, 840))
	_check(board._boss_sel == 0, "glisser : +200 px -> carte %d (0 attendue, borne)" % board._boss_sel)
	# un petit tremblement de clic (< seuil) ne change rien
	await _drag(Vector2(1000, 840), Vector2(1006, 840), null, 2)
	_check(board._boss_sel == 0 and board._boss_drag.is_empty(), "glisser : un tremblement de 6 px a bouge le carrousel (%d)" % board._boss_sel)
	# depart hors de la zone des cartes : ignore
	await _drag(Vector2(100, 200), Vector2(-100, 200))
	_check(board._boss_sel == 0, "glisser : depart hors zone a bouge le carrousel")
	# relachement HORS de la zone (et de l'ecran) : le glisser se termine quand meme, on garde les crans deja faits
	await _drag(Vector2(1500, 840), Vector2(1380, 840), Vector2(-50, 2000))
	_check(board._boss_sel == 1 and board._boss_drag.is_empty(), "glisser : relachement hors ecran, carte %d, glisser en cours %s" % [board._boss_sel, str(board._boss_drag)])
	# bouton relache sans evenement de relachement (fenetre quittee) : un mouvement sans masque termine le glisser
	await _mouse(Vector2(1500, 840), true, false)
	await _mouse(Vector2(1480, 840), false, true, 0)
	await _mouse(Vector2(1200, 840), false, true, MOUSE_BUTTON_MASK_LEFT) # ne doit plus rien faire
	_check(board._boss_sel == 1 and board._boss_drag.is_empty(), "glisser : un mouvement sans bouton gauche n'a pas termine le glisser (carte %d)" % board._boss_sel)
	await _mouse(Vector2(1200, 840), false, false)
	# appui sur une voisine puis glisser : le glisser est relatif a la carte centrale de l'appui, pas a la carte touchee
	board._boss_select(0)
	var neighbour := (bc[1] as Control).get_global_rect().get_center()
	await _drag(neighbour, neighbour + Vector2(-100, 0))
	_check(board._boss_sel == 1, "glisser depuis une voisine : carte %d (1 attendue)" % board._boss_sel)
	board._boss_select(0)
	_cov("boss_drag")

## Retournement des autres cartes apres PLAY BOSS MONSTER! (animations reelles) : dos de carte, nom du boss, puis le coup part.
func _check_boss_flip() -> void:
	_tag = "[boss-flip]"
	await _teardown()
	CardDB._rng.seed = 123
	gm = GameManager.new()
	add_child(gm)
	gm.start_new_game(2, 1, ["base"])
	board = load("res://godot/scenes/Board.tscn").instantiate()
	board.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(board)
	board.skip_animations = false
	board.set_process(false) # l'IA ne joue pas pendant ce test
	board.setup(gm, func(): quit_calls += 1)
	await _wait(0.1)
	var picks: Array = (gm.G["bossPicks"] as Array).duplicate(true) # le coup consomme les propositions
	var bc: Array = board._boss_cards.duplicate()
	board._boss_select(1)
	await _wait(0.3)
	board._confirm_btn.pressed.emit()
	_check(board._boss_flipping and gm.G["players"][0].get("boss") == null, "retournement : doit preceder le coup")
	_check(board._carousel_text.text.contains(str((picks[1] as Dictionary).get("name", "")).to_upper()), "retournement : nom du boss absent (%s)" % board._carousel_text.text)
	board._confirm_btn.pressed.emit() # un 2e appui ne fait rien
	await _wait(0.45)
	var back_tex: Texture2D = load(CardDB.card_image("", "back-boss"))
	var backs := 0
	for i in bc.size():
		if is_instance_valid(bc[i]) and not (bc[i] as Node).is_queued_for_deletion() and (bc[i] as CardUI).texture_rect.texture == back_tex:
			backs += 1
			_check(i != 1, "retournement : la carte choisie est retournee")
	_check(backs == bc.size() - 1, "retournement : %d dos de carte pour %d cartes retournables" % [backs, bc.size() - 1])
	await _wait(0.4)
	var boss = gm.G["players"][0].get("boss")
	_check(boss != null and str((boss as Dictionary).get("id", "")) == str((picks[1] as Dictionary).get("id", "")) and not board._boss_flipping, "retournement : le boss n'a pas ete valide (boss=%s flipping=%s phase=%s)" % [str(boss), board._boss_flipping, gm.G.get("phase")])
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
	_check(not board.btn_pass.is_visible_in_tree() and not board.btn_advance.is_visible_in_tree(), "fenetres : PASS TURN / GO visibles en aventure (flux APK)")
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
		_check(not board.btn_pass.is_visible_in_tree(), "pile : PASS TURN visible (flux APK : barre de temps)")
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
	await _mouse(start + Vector2(0, -160), false, true, MOUSE_BUTTON_MASK_LEFT)
	_check(not board._drag.is_empty(), "glisser : pas de glisser en cours apres 160 px")
	var frames: Array = board._drag.get("frames", [])
	var n_frames := _n_build_targets(0, idx) # le prochain emplacement libre + les salles recouvrables (Boss.CanBuildRoom)
	_check(frames.size() == n_frames and n_frames == 1 + dsize, "glisser : %d emplacements dores pour une salle (%d attendus)" % [frames.size(), 1 + dsize])
	var prev: Control = board._drag.get("preview")
	_check(prev != null and absf(prev.size.x - (board.HAND_CARD.x + 8.0)) < 1.0, "glisser : la carte tiree n'a pas la taille de la main (APK : NormalScale)")
	await _mouse(start + Vector2(0, -20), false, false)
	_check(board._drag.is_empty() and (me["hand"] as Array).size() == n_hand and (me["dungeon"] as Array).size() == dsize, "glisser : relacher sur la main doit annuler")
	_check(board.hand_layer.get_children().filter(func(c): return not c.is_queued_for_deletion() and c.modulate.a < 0.9).is_empty(), "glisser : la carte annulee n'est pas revenue dans la main")
	# salle : depot sur l'emplacement dore
	card = _hand_cards()[idx]
	start = card.get_global_rect().get_center()
	var slot_c: Vector2 = (board._dungeon_slots[maxi(0, DUNGEON_N - dsize - 1)] as Control).get_global_rect().get_center() # le prochain emplacement libre
	await _mouse(start, true, false)
	for k in range(1, 7):
		await _mouse(start.lerp(slot_c, float(k) / 6.0), false, true, MOUSE_BUTTON_MASK_LEFT)
	_check(not board._drag.is_empty(), "glisser : salle - glisser perdu en route")
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
	var last: Control = board.town_container.get_child(board.town_container.get_child_count() - 1)
	_check(sc.scroll_vertical > 0 and sc.get_global_rect().grow(2.0).encloses(last.get_global_rect()), "ville : le heros arrive n'est pas amene a l'ecran (defilement %d)" % sc.scroll_vertical)
	_cov("town_scroll")
	# --- bulle « HAS PLAYED A ... » de l'adversaire : un appui montre la carte (au centre), le clic suivant la ferme
	var spell: Dictionary = ((G["decks"]["spells"] as Array)[0] as Dictionary).duplicate(true)
	(foe["hand"] as Array).append(spell)
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
	board._notice_ai(1, {"type": "activateRoom", "args": [0]})
	_check(board._notice != null and is_instance_valid(board._notice) and board._notice.mouse_filter == Control.MOUSE_FILTER_STOP, "bulle de capacite de salle adverse : pas cliquable")
	_cov("notice_tap")
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
		_check(btn.text == "CONTINUE" and (cards[1] as CardUI).scale.x > 1.6 and (cards[0] as CardUI).scale.x == 1.0, "carrousel : la carte choisie n'est pas agrandie / CONTINUE absent")
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
	board._on_pass_pressed()
	_check(board._warn != null and _sig() == s0, "mise en garde : la bulle n'apparait pas au 1er appui (ou la partie a avance)")
	var lbls: Array = board._warn.find_children("*", "Label", true, false)
	_check(lbls.size() == 1 and (lbls[0] as Label).text.replace("\n", " ") == "HEY! YOU CAN BUILD A ROOM! STILL WANT TO PASS?", "mise en garde : texte de la bulle")
	board._on_pass_pressed()
	_check(board._warn == null and _sig() != s0, "mise en garde : le 2e appui doit passer")
	_cov("pass_warning")
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
	if _check(gm.G.has("buildWindow") and ki >= 0, "DONE : la fenetre de sorts apres construction n'est pas ouverte"):
		var tex_done: Texture2D = board._tex(board.TEX_DONE)
		_check(board.btn_pass.is_visible_in_tree() and (board.btn_pass as TextureButton).texture_normal == tex_done, "DONE : PASS TURN ne devient pas DONE!")
		var s1 := _sig()
		board._on_pass_pressed()
		_check(board._warn == null and _sig() != s1 and not gm.G.has("buildWindow"), "DONE : le bouton DONE! ne referme pas la fenetre")
		_cov("done_button")

## Galerie de cartes : 5 onglets (BOSS / ROOM / SPELL / HERO / EPIC HERO), grille, paquets de l'APK (+ wiki selon l'option), fermeture ;
## ouverte depuis le menu en jeu et depuis OPTIONS du menu principal.
func _check_gallery() -> void:
	_tag = "[gallery]"
	await _new_game()
	board.set_process(false)
	var ext: bool = bool(Profile.load_settings().get("extensions", false))
	var allowed: Array = ["base", "players-choice", "hidden-heroes", "tools"]
	if ext:
		allowed.append_array(["next-level", "crash-landing", "minibosses"])
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
		for c in sources[t]:
			var d: Dictionary = c
			if not (str(d.get("set", "base")) in allowed):
				continue
			if t >= 3 and bool(d.get("epic", false)) != (t == 4):
				continue
			want += 1
		_check(g.cards_shown == want and want > 0, "galerie : onglet %d : %d cartes pour %d attendues" % [t, g.cards_shown, want])
		var grid = g.scroll.get_node_or_null("Grid")
		_check(grid != null and grid.get_child_count() == want, "galerie : grille de %d cartes pour %d" % [grid.get_child_count() if grid != null else -1, want])
	g.select_tab(0)
	var tile = g.scroll.get_node("Grid").get_child(0)
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
		await get_tree().process_frame
		_check(main.get_children().any(func(c): return c.get_script() != null and str(c.get_script().resource_path).ends_with("CardGallery.gd")), "galerie : non ouverte depuis OPTIONS")
		_cov("gallery_options")
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
	var pp = main.find_child("PASS AND PLAY", true, false)
	if _check(po != null and pp != null, "multi : boutons PLAY ONLINE / PASS AND PLAY"):
		_check(po.get_children().filter(func(c): return c is TextureRect).size() == 4 and pp.get_children().filter(func(c): return c is TextureRect).size() == 2, "multi : eventails de 4 et 2 bosses")
		_check(is_equal_approx(po.position.x + 252.0, 1260.0) and is_equal_approx(pp.position.x + 252.0, 660.0) and is_equal_approx(po.position.y + 200.0, 540.0), "multi : boutons centres en (1260,540) et (660,540)")
		po.button_down.emit()
		_check((po.get_node("Title") as Label).get_theme_color("font_color") == Color("cdb15f"), "multi : titre dore pendant l'appui")
		po.button_up.emit()
		_check((po.get_node("Title") as Label).get_theme_color("font_color") == Color.WHITE, "multi : titre blanc au relachement")
		# sans pseudo enregistre : ChangeNameAvatarScene d'abord, sans fleche de retour
		po.pressed.emit()
		await _wait(0.2)
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
	# MenuOnlineScene : WORLDWIDE (erreur APK), CHANGE USER/AVATAR (avec fleche), WITH FRIENDS
	var lb := _label_buttons(main)
	if _check(lb.has("WORLDWIDE") and lb.has("WITH FRIENDS") and lb.has("CHANGE USER/AVATAR"), "menu en ligne : boutons %s" % str(lb.keys())):
		var b0: TextureButton = lb["WORLDWIDE"]
		_check(is_equal_approx(b0.position.x + 309.5, 960.0) and is_equal_approx(b0.position.y + 88.5, 388.8), "menu en ligne : WORLDWIDE en (960, 388,8)")
		b0.pressed.emit()
		await get_tree().process_frame
		var mb = main.find_child("MessageBox", true, false)
		if _check(mb != null, "menu en ligne : WORLDWIDE n'ouvre pas la boite d'erreur"):
			var mt := _texts_of(mb)
			_check(mt.has("NETWORK ERROR") and mt.has("Unable to join public rooms"), "boite d'erreur : textes %s" % str(mt))
			(mb.get_node("Ok") as TextureButton).pressed.emit()
			await get_tree().process_frame
			await get_tree().process_frame
			_check(main.find_child("MessageBox", true, false) == null, "boite d'erreur : OK ne la ferme pas")
		lb["CHANGE USER/AVATAR"].pressed.emit()
		await _wait(0.2)
		_check(_tb_by_texture(main, "back_bt.webp") != null and (main.find_child("Entry", true, false) as LineEdit).text == "Zed", "profil (depuis le menu) : fleche de retour et pseudo enregistre")
		_tb_by_texture(main, "back_bt.webp").pressed.emit()
		await _wait(0.2)
		_label_buttons(main)["WITH FRIENDS"].pressed.emit()
	await _wait(0.2)
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
		await _wait(0.2)
		_check(_texts_of(main).has("HOW MANY PLAYERS?"), "amis : NEW GAME n'ouvre pas le choix du nombre de joueurs")
		_cov("menus_friends")
	# PASS AND PLAY : choix du nombre de joueurs, extensions, partie a sieges tous humains
	main.show_multi()
	await _wait(0.2)
	main.find_child("PASS AND PLAY", true, false).pressed.emit()
	await _wait(0.2)
	_check(_texts_of(main).has("HOW MANY PLAYERS?"), "pass and play : choix du nombre de joueurs")
	main.players = 3
	main.show_setup(3, 3, "pass")
	await _wait(0.2)
	_check(_texts_of(main).has("SELECT EXPANSIONS"), "pass and play : choix des extensions")
	_tb_by_texture(main, "ok_bt.webp").pressed.emit()
	await _wait(0.4)
	if _check(main.board != null and is_instance_valid(main.board), "pass and play : pas de plateau"):
		var pls: Dictionary = main.game_manager.G["players"]
		_check(pls.size() == 3 and pls.values().all(func(p): return not bool(p.get("isAI", false))), "pass and play : les 3 sieges doivent etre humains")
		_cov("menus_pass_and_play")
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

## Ecran de fin : bandeau du vainqueur (nom, IS THE WINNER!, boss agrandi, 10 cristaux, OK), « YOU LOSE » avec la pierre tombale ;
## boss elimine = pierre tombale RIP a la place du sprite.
func _check_gameover_banner() -> void:
	_tag = "[gameover]"
	await _new_game()
	board.set_process(false)
	var G: Dictionary = gm.G
	var boss = G["players"][0].get("boss")
	G["gameOver"] = {"winner": 0, "reason": "souls"}
	board.refresh()
	await get_tree().process_frame
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
	board.refresh()
	await get_tree().process_frame
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
	board._notice_ai(1, {"type": "playSpell", "args": []})
	var notice = board._ui_layer.find_child("Notice", true, false)
	var texts: Array = notice.find_children("*", "Label", true, false).map(func(l): return (l as Label).text) if notice != null else []
	_check(texts == ["HAS PLAYED A", "SPELL"], "notice adverse : %s" % str(texts))
	board._notice_ai(0, {"type": "playSpell", "args": []}) # mon propre coup : pas de notice
	await _wait(0.1)
	board.skip_animations = true
	_cov("effects")

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

## Choix du boss : (1) l'IA prend le boss que le joueur vient de valider pendant le retournement (0,65 s) -> le titre montrait ce boss, puis
## « ... », et le joueur restait sans boss ; l'IA attend desormais que le coup du joueur soit joue. (2) l'IA retire une AUTRE carte : celle du
## centre reste au centre (les indices se decalaient).
func _check_boss_race() -> void:
	_tag = "[boss-race]"
	await _teardown()
	CardDB._rng.seed = 99
	gm = GameManager.new()
	add_child(gm)
	gm.start_new_game(2, 1, ["base"])
	board = load("res://godot/scenes/Board.tscn").instantiate()
	board.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(board)
	board.skip_animations = false # retournement reel ; board._process tourne (l'IA joue)
	board.setup(gm, func(): quit_calls += 1)
	var picks: Array = gm.G["bossPicks"]
	var ai_mv = AI.pick_move(gm, 1)
	if not _check(ai_mv != null and str(ai_mv["type"]) == "pickBoss", "course : l'IA ne propose pas de pickBoss"):
		return
	var ai_id := str((ai_mv["args"] as Array)[0])
	var idx := -1
	for i in picks.size():
		if str((picks[i] as Dictionary)["id"]) == ai_id:
			idx = i
	var ai_name := str((picks[idx] as Dictionary)["name"]).to_upper()
	board._boss_select(idx) # le boss que l'IA va prendre
	board._confirm_btn.pressed.emit()
	var titles: Array = []
	for f in 90: # ~1,5 s : l'IA joue a 0,5 s, le retournement finit a 0,65 s
		await get_tree().process_frame
		if str(gm.G.get("phase")) == "boss":
			titles.append([board._boss_flipping, board._carousel_text.text])
		await _wait(0.016)
	var me_boss = gm.G["players"][0].get("boss")
	var foe_boss = gm.G["players"][1].get("boss")
	_check(me_boss != null and str((me_boss as Dictionary).get("id", "")) == ai_id, "course : le boss valide par le joueur ne lui est pas revenu (%s)" % str(me_boss.get("name") if me_boss != null else "aucun"))
	_check(foe_boss != null and str((foe_boss as Dictionary).get("id", "")) != ai_id, "course : l'IA a pris le meme boss que le joueur")
	for t in titles: # retournement : le nom du boss valide ; sinon « ... » (jamais le boss d'un autre)
		_check(str(t[1]).contains(ai_name) if bool(t[0]) else str(t[1]).contains("..."), "course : titre %s (retournement %s)" % [str(t[1]), str(t[0])])
	# (2) la carte du centre ne bouge pas quand l'IA retire une autre carte
	await _teardown()
	CardDB._rng.seed = 99
	gm = GameManager.new()
	add_child(gm)
	gm.start_new_game(2, 1, ["base"])
	board = load("res://godot/scenes/Board.tscn").instantiate()
	board.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(board)
	board.skip_animations = true
	board.set_process(false)
	board.setup(gm, func(): quit_calls += 1)
	await _wait(0.1)
	picks = gm.G["bossPicks"]
	var keep := str((picks[picks.size() - 1] as Dictionary)["id"])
	board._boss_select(picks.size() - 1)
	var taken := str((picks[0] as Dictionary)["id"])
	gm.apply_move(1, {"type": "pickBoss", "args": [taken]})
	board.refresh()
	await get_tree().process_frame
	var now_picks: Array = gm.G["bossPicks"]
	_check(not now_picks.is_empty() and str((now_picks[board._boss_sel] as Dictionary)["id"]) == keep, "course : la carte du centre a change quand l'IA a pris une autre carte")
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
	await _check_window_clock()
	await _check_single_click()
	await _check_choice_target()
	await _check_drag_and_zoom()
	await _check_done_and_warning()
	await _check_apk_gaps()
	await _check_gallery()
	await _check_online_menus()
	await _check_gameover_banner()
	await _check_effects()
	await _check_crossing_ui()
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
		_check((cards[0] as Control).size == Vector2(175, 244), "carte de main %s != 175x244" % (cards[0] as Control).size)
		_check_fan(cards)
	_check(board.extra_bar.get_child_count() == 0 or not board.extra_bar.visible, "bouton non-APK visible en partie de base")
	# 1) Sort sans cible : un clic sur la carte le joue (aucun bouton « Sort : ... »)
	var idx := _take_spell("BMA050") # Motivation : phase de construction, sans cible
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
		var acts := gm.legal_moves(0).filter(func(m): return m["type"] == "activateRoom" and int(m["args"][0]) == 0)
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
		var cb := _buttons(board._popup)
		(cb[1] as Button).pressed.emit() # NO
		await get_tree().process_frame
		_check(board._popup_kind == "menu" and quit_calls == q0, "NO : retour au menu attendu")
		board._open_quit_confirm()
		await get_tree().process_frame
		cb = _buttons(board._popup)
		(cb[0] as Button).pressed.emit() # YES
		await get_tree().process_frame
		_check(quit_calls == q0 + 1, "YES : callback de sortie non appele")
