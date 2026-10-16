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

const MAX_STEPS := 6000
const STUCK_ITERS := 150
const ANIM_TIME_SCALE := 6.0
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
		match t:
			"buildRoom":
				if a.size() > 1 and a[1] != null:
					out.append({"kind": "drop", "w": _style_w("drop"), "desc": "depot salle %d sur %d" % [a[0], a[1]], "run": func(): await _do_drop(pid, int(a[0]), int(a[1]))})
				else:
					out.append({"kind": "build", "w": _style_w("build"), "desc": "construire salle %d" % int(a[0]), "run": func(): await _do_build_click(pid, int(a[0]))})
			"playSpell", "useHandRoom":
				if not by_hand.has(int(a[0])):
					by_hand[int(a[0])] = []
				(by_hand[int(a[0])] as Array).append(m)
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
	if has_go:
		out.append({"kind": "go", "w": _style_w("go"), "desc": "GO", "run": func(): await _do_button(board.btn_advance, "GO")})
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
		(cards[idx] as CardUI).card_clicked.emit(null)

func _do_drop(pid: int, idx: int, ti: int) -> void:
	if rng.randf() < 0.4: # variante au clic : fenetre « construire par-dessus » (une entree par salle recouvrable)
		var n_over: int = gm.legal_moves(pid).filter(func(m): return m["type"] == "buildRoom" and (m["args"] as Array).size() > 1 and m["args"][1] != null and int(m["args"][0]) == idx).size()
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
	var also_build: bool = (phase == "build" or phase == "setup") and bool(hand[idx].get("isRoom", false)) and gm.can_build_room_at(pid, idx, (gm.G["players"][pid]["dungeon"] as Array).size())
	(cards[idx] as CardUI).card_clicked.emit(null)
	await _pick_target(cands.size() + (1 if also_build else 0), "carte %s" % cname)

## Apres un clic qui peut ouvrir un choix de cible : plusieurs coups = les cibles s'allument sur le plateau (clic sur l'une, ou CANCEL) ;
## sans representation a l'ecran (ames, defausse...), la liste centrale (une pierre par cible + CANCEL).
func _pick_target(n_cands: int, what: String) -> void:
	for i in 3: # les zones de ciblage sont posees apres la mise en page des conteneurs
		await get_tree().process_frame
	if n_cands <= 1:
		_check(board._popup_kind != "target" and board._tgt.is_empty(), "%s : fenetre / mode de ciblage pour un seul coup" % what)
		return
	if not board._tgt.is_empty():
		await _pick_on_board(n_cands, what)
		return
	if not _check(board._popup_kind == "target", "%s : %d cibles mais pas de choix de cible (popup=%s)" % [what, n_cands, board._popup_kind]):
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
func _pick_on_board(n_cands: int, what: String) -> void:
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
	_check(board._tgt_cancel_btn != null and board._tgt_cancel_btn.is_visible_in_tree() and not board.action_box.visible, "%s : CANCEL absent ou PASS TURN encore visible en ciblage" % what)
	var s0 := _sig()
	var hand := _hand_cards()
	if not hand.is_empty() and not cov.has("target_blocked"): # le voile bloque la main : un clic sur une carte ne joue rien et ne ferme pas le mode
		await _click_at((hand[hand.size() / 2] as Control).get_global_rect().get_center())
		_check(not board._tgt.is_empty() and _sig() == s0 and board._popup_kind == "", "%s : un clic sur la main pendant le ciblage a eu un effet" % what)
		_cov("target_blocked")
	if rng.randf() < 0.2:
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
	_check(board._tgt.is_empty() and board._popup_kind != "target", "%s : le clic sur une cible allumee n'a pas joue le coup" % what)
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
	var btns: Array = board.extra_bar.get_children().filter(func(c): return not c.is_queued_for_deletion())
	if _check(k < btns.size() and board.extra_bar.visible, "coup d'extension %d : pas de bouton (%d affiches)" % [k, btns.size()]):
		(btns[k] as Button).pressed.emit()

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
	if not _check(board._popup_kind == "choice", "choix en attente « %s » (%s) : pas de popup (popup=%s)" % [typ, str(pc.get("message", "")).left(50), board._popup_kind]):
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
				if str(m["type"]) in ["buildRoom", "playSpell", "useHandRoom"] and (m["args"] as Array).size() > 0:
					playable[int(m["args"][0])] = true
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
				_check_volume_slider()
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

## MASTER VOLUME du menu en jeu : le curseur agit sur AudioManager (valeur d'origine rendue ensuite, rien n'est ecrit sur disque).
func _check_volume_slider() -> void:
	var sl: Array = []
	var stack: Array = [board._popup]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is HSlider:
			sl.append(n)
		stack.append_array(n.get_children())
	if not _check(sl.size() == 1, "menu : %d curseurs de volume (1 attendu)" % sl.size()):
		return
	var orig: float = AudioManager.master_volume
	(sl[0] as HSlider).value = 0.37
	_check(absf(AudioManager.master_volume - 0.37) < 0.001, "menu : le curseur ne regle pas le volume maitre (%s)" % AudioManager.master_volume)
	(sl[0] as HSlider).value = 0.0
	_check(AudioServer.is_bus_mute(0), "menu : volume 0 = bus Master non coupe")
	AudioManager.master_volume = orig
	AudioManager._apply()
	_cov("volume_slider")

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
			shown += (s as Control).get_children().filter(func(c): return c is CardUI and not c.is_queued_for_deletion()).size()
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
		if not CORE_TYPES.has(t):
			extras += 1
	var carousel: bool = (phase == "boss" or board._is_opening_discard_for_me()) and not over
	var go_usable: bool = board.btn_advance.is_visible_in_tree() and not board.btn_advance.disabled
	_check(go_usable == (can_go and not carousel), "bouton GO : %s alors que le coup est %s" % ["utilisable" if go_usable else "inutilisable", "legal" if can_go else "illegal"])
	var pass_vis: bool = board.btn_pass.is_visible_in_tree()
	if pass_vis:
		_check(can_pass and not over, "bouton PASS TURN visible alors que passer est illegal (phase %s, fin=%s, siege %d)" % [phase, over, pid])
	var extra_vis: bool = board.extra_bar.visible and board.extra_bar.get_children().filter(func(c): return not c.is_queued_for_deletion()).size() > 0
	_check(extra_vis == (extras > 0 and pc.is_empty()), "barre d'extensions : %s pour %d coups d'extension" % ["visible" if extra_vis else "cachee", extras])
	# popup de choix <-> choix en attente
	var mine: bool = not pc.is_empty() and int(pc.get("playerId", -1)) == pid and str(pc.get("type", "")) != "opening-discard" and not my_moves.is_empty()
	if board._popup_kind == "choice":
		_check(mine, "popup de choix affiche sans choix en attente pour le siege %d" % pid)
	elif board._popup_kind == "":
		_check(not mine, "choix en attente (%s) sans popup" % str(pc.get("type", "")))
	elif board._popup_kind == "target":
		_check(false, "fenetre de ciblage restee ouverte")
	_check(board._tgt.is_empty(), "mode de ciblage reste ouvert apres le geste")
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
		_check(board._carousel_text.visible and board._carousel_text.text.contains("WINS"), "fin de partie : bandeau « WINS » absent")
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
		await _wait(0.1)
		_check_ui()
		_check(board._bubble.visible, "fin de partie : bulle de titre absente")
		_check(_hand_cards().is_empty(), "fin de partie : cartes encore en main a l'ecran")
		var w := int(G["gameOver"].get("winner", -1))
		_check(board._carousel_text.text.contains("[color=#f0c040]%d[/color] WINS" % (w + 1)), "fin de partie : mauvais vainqueur affiche (%s, vainqueur siege %d)" % [board._carousel_text.text, w])
		for pid in G["players"]:
			_check(gm.legal_moves(int(pid)).is_empty(), "fin de partie : le siege %d a encore des coups legaux" % pid)
		_cov("game_over_screen")
		# bouton MENU de l'ecran de fin
		var qm := quit_calls
		if _check(board._confirm_btn.visible and board._confirm_btn.text == "MENU", "fin de partie : bouton MENU absent"):
			board._confirm_btn.pressed.emit()
			_check(quit_calls == qm + 1, "fin de partie : le bouton MENU ne ramene pas au menu")
			_cov("game_over_menu_btn")
	if full or G.get("gameOver") != null:
		# retour au menu : engrenage -> QUIT TO MENU -> YES
		var q0 := quit_calls
		board._on_menu_pressed()
		await get_tree().process_frame
		var quit_btn: Button = null
		for b in _buttons(board._popup):
			if (b as Button).text == "QUIT TO MENU":
				quit_btn = b
		if _check(quit_btn != null, "fin de partie : menu sans QUIT TO MENU"):
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
			_check(btns.size() == uses.size() + 2, "CRL007 : %d boutons (BUILD + %d cibles + CANCEL attendus)" % [btns.size(), uses.size()])
			if btns.size() >= 2:
				(btns[1] as Button).pressed.emit() # premiere cible
				await get_tree().process_frame
				_check(board._popup_kind == "" and not (me["hand"] as Array).has(proto), "CRL007 : la capacite n'a pas ete utilisee (carte encore en main)")
				_cov("hand_room_menu")

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
	_check(board._confirm_btn.visible and board._confirm_btn.text == "PLAY BOSS MONSTER!" and board._confirm_btn.size.x >= 390.0, "carrousel : bouton PLAY BOSS MONSTER! absent")
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

func _extra_checks() -> void:
	await _check_boss_carousel()
	await _check_main_flow()
	await _check_hand_room()
	_tag = "[base]"
	await _new_game()
	var G: Dictionary = gm.G
	var me: Dictionary = G["players"][0]
	board.refresh()
	# Main : cartes ~210x300 a 1920x1080
	var cards := _hand_cards()
	if _check(not cards.is_empty(), "main vide a l'ecran"):
		_check((cards[0] as Control).size == Vector2(210, 300), "carte de main %s != 210x300" % (cards[0] as Control).size)
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
	# 6) QUIT TO MENU : confirmation, NO revient au menu, YES quitte
	var quit_btn: Button = null
	for b in _buttons(board._popup):
		if (b as Button).text == "QUIT TO MENU":
			quit_btn = b
	if _check(quit_btn != null, "bouton QUIT TO MENU absent"):
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
