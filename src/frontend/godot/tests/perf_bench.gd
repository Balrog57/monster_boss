extends Node
## Banc de perf (mesure seulement, jamais dans run_godot_tests.py) : parties IA-vs-IA a graine fixe, temps mural de chaque Match.apply_move.
## Usage (depuis src/frontend, TOUJOURS sous timeout : Godot 4.7.2 ne rend pas la main sur --import) :
##   godot --headless --path . res://godot/tests/PerfBench.tscn -- --sets=crash-landing --players=6 [--runs=3] [--seed=1000] [--humans=0|1] [--ui] [--top=10] [--ship-all]
##   --runs=K   K parties, graines seed..seed+K-1          --humans=1   le siege 0 est « humain » (l'IA ne joue pas pour lui dans Match._drive_ai : le banc le fait)
##   --ui       un vrai Board.tscn est branche (state_changed -> BoardUI.refresh, comme en jeu) et pilote par board._process() comme ui_smoke ;
##              avant la coalescence de BoardUI._refresh_soon, le refresh() declenche par state_changed etait compte DANS l'apply_move qui l'emet (colonnes ref) ;
##              depuis, le signal ne fait que differer un refresh() (ref ~ 0) et son cout se lit dans la ligne « frame (_process) ».
## Mesure : le chronometrage est dans le banc (sous-classe BenchGM qui enveloppe apply_move), aucun script du jeu n'est touche.
## Un apply_move « externe » inclut les apply_move imbriques (Match._drive_ai : les IA de la construction jouent a l'interieur du coup qui les declenche) : colonnes sub.

const GameManager = preload("res://godot/scripts/GameManager.gd")
const AI = preload("res://godot/scripts/AI.gd")
const SoakSeed = preload("res://godot/tests/soak_seed.gd")

const MAX_STEPS := 20000

## GameManager dont apply_move est chronometre. Les appels imbriques (depth > 0) sont comptes dans l'appel externe.
class BenchGM extends "res://godot/scripts/GameManager.gd":
	var depth := 0
	var recs: Array = []
	var sub_n := 0
	var sub_us := 0
	var ref_n := 0   # refresh() declenches par state_changed
	var ref_us := 0
	var _ref_t0 := 0
	var digest := 0 # empreinte de la suite des coups appliques (etiquette, resultat) : deux versions du moteur jouent la meme partie si elle est identique
	var ref_each: Array = [] # duree de chaque refresh() declenche par state_changed

	func ref_begin() -> void:
		_ref_t0 = Time.get_ticks_usec()

	func ref_end() -> void:
		ref_each.append(Time.get_ticks_usec() - _ref_t0)
		ref_us += Time.get_ticks_usec() - _ref_t0
		ref_n += 1

	func apply_move(pid: int, move: Dictionary) -> bool:
		var top := depth == 0
		var label := ""
		var phase := ""
		if top:
			label = _label(pid, move)
			phase = str(G.get("phase", ""))
			sub_n = 0
			sub_us = 0
		var r0 := ref_us
		var n0 := ref_n
		depth += 1
		var t0 := Time.get_ticks_usec()
		var ok: bool = super.apply_move(pid, move)
		var dt := Time.get_ticks_usec() - t0
		depth -= 1
		if top:
			digest = hash([digest, label, ok])
			recs.append({"label": label, "phase": phase, "turn": int(G.get("turn", 0)), "us": dt, "ok": ok, "sub_n": sub_n, "sub_us": sub_us, "ref_n": ref_n - n0, "ref_us": ref_us - r0})
		elif depth == 1:
			sub_n += 1
			sub_us += dt
		return ok

	## type + carte visee (main / salle) pour le classement des coups lents.
	func _label(pid: int, move: Dictionary) -> String:
		var t := str(move.get("type", ""))
		var a: Array = move.get("args", [])
		var p: Dictionary = (G.get("players", {}) as Dictionary).get(pid, {})
		var c := ""
		if t in ["buildRoom", "playSpell", "useHandRoom"] and not a.is_empty() and int(a[0]) >= 0 and int(a[0]) < (p.get("hand", []) as Array).size():
			c = str(((p["hand"] as Array)[int(a[0])] as Dictionary).get("id", "?"))
		elif t == "activateRoom" and not a.is_empty() and int(a[0]) >= 0 and int(a[0]) < (p.get("dungeon", []) as Array).size():
			var r = BossEngine.active_room((p["dungeon"] as Array)[int(a[0])])
			c = str((r as Dictionary).get("id", "?")) if r != null else "?"
		elif t == "resolveChoice":
			c = str((G.get("pendingChoice", {}) as Dictionary).get("type", "?"))
		elif t in ["adventureNext", "resolveNextHero", "pass"]:
			var adv: Dictionary = G.get("adventure", {})
			c = "pause=%s" % str(adv.get("pause", "-")) if not adv.is_empty() else "no-hero"
		return "%s P%d %s" % [t, pid, c]

var gm: BenchGM
var board
var ai_us: Array = []     # AI.pick_move (+ score_move) hors apply_move
var frame_us: Array = []  # --ui : un pas de board._process
var ref_each: Array = []
var all_recs: Array = []
var ui_mode := false
var humans := 0
var sets: Array = ["base"]
var players := 6
var top_n := 10
var games := 0

func _ready() -> void:
	var runs := 3
	var first_seed := 1000
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--players="):
			players = clampi(int(a.substr(10)), 2, 6)
		elif a.begins_with("--sets="):
			sets = Array(a.substr(7).split(",", false))
		elif a.begins_with("--runs="):
			runs = maxi(1, int(a.substr(7)))
		elif a.begins_with("--seed="):
			first_seed = int(a.substr(7))
		elif a.begins_with("--humans="):
			humans = clampi(int(a.substr(9)), 0, 1)
		elif a.begins_with("--top="):
			top_n = maxi(1, int(a.substr(6)))
		elif a == "--ui":
			ui_mode = true
		elif a == "--ship-all": # paquets fermes (CardDB.SHIPPED_SETS), comme les soaks
			CardDB.ship_all = true
	if Match.setup_error(players, sets) != "":
		print("PERF ECHEC : ", Match.setup_error(players, sets))
		get_tree().quit(1)
		return
	for r in runs:
		if not await _play(first_seed + r):
			print("PERF ECHEC : partie non terminee (graine ", first_seed + r, ")")
			get_tree().quit(1)
			return
	_report()
	SoakSeed.unseed()
	get_tree().quit(0)

func _play(game_seed: int) -> bool:
	gm = BenchGM.new()
	add_child(gm)
	SoakSeed.seed_game(gm, game_seed)
	board = null
	if ui_mode:
		gm.state_changed.connect(gm.ref_begin) # avant Board.setup : encadre le refresh() branche par setup()
		board = load("res://godot/scenes/Board.tscn").instantiate()
		board.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(board)
		board.skip_animations = true
		board.win_time_scale = 0.12 # fenetres chronometrees raccourcies, comme ui_smoke
		board.set_process(false)
		gm.start_new_game(players, humans, sets)
		board.setup(gm, func(): pass)
		gm.state_changed.connect(gm.ref_end)
		await get_tree().process_frame
	else:
		gm.start_new_game(players, humans, sets)
	var t0 := Time.get_ticks_msec()
	var steps := 0
	while gm.G.get("gameOver") == null and steps < MAX_STEPS:
		steps += 1
		if ui_mode:
			var f0 := Time.get_ticks_usec()
			board._process(0.21)
			frame_us.append(Time.get_ticks_usec() - f0)
			await get_tree().process_frame
			if board._animating_hero:
				continue
			if not _human_act() and frame_us.size() > 1 and _stuck():
				break
		elif not _soak_step():
			break
	var done: bool = gm.G.get("gameOver") != null
	if not done:
		var G: Dictionary = gm.G
		print("PERF CALE phase=%s active=%s pending=%s window=%s stack=%d moves=%s" % [G.get("phase"), gm.active_player(), G.get("pendingChoice"), G.get("buildWindow"), (G.get("stack", []) as Array).size(), (G["players"] as Dictionary).keys().map(func(q): return (gm.legal_moves(int(q)) as Array).map(func(m): return m["type"]))])
	print("PERF game seed=%d players=%d humans=%d ui=%s steps=%d turn=%s done=%s wall=%.1fs apply_move=%d digest=%d state=%d" % [game_seed, players, humans, ui_mode, steps, gm.G.get("turn", -1), done, (Time.get_ticks_msec() - t0) / 1000.0, gm.recs.size(), gm.digest, hash(var_to_str(gm.G))])
	all_recs.append_array(gm.recs)
	ref_each.append_array(gm.ref_each)
	games += 1
	if board != null:
		board.queue_free()
	gm.queue_free()
	await get_tree().process_frame
	return done

var _last_sig := ""
var _same := 0
func _stuck() -> bool:
	var sig := str([gm.G.get("phase"), gm.G.get("turn"), (gm.G.get("log", []) as Array).size(), gm.recs.size()])
	_same = _same + 1 if sig == _last_sig else 0
	_last_sig = sig
	return _same > 400

## Sieges « humains » (--humans=1) : l'IA ne joue pas pour eux dans Match._drive_ai ni dans BoardUI ; le banc leur applique AI.pick_move. Vrai si un coup a ete joue.
func _human_act() -> bool:
	for pid in gm.G["players"]:
		if bool((gm.G["players"][pid] as Dictionary).get("isAI", false)):
			continue
		var phase: String = gm.G["phase"]
		var pc: Dictionary = gm.G.get("pendingChoice", {})
		if not pc.is_empty() and int(pc.get("playerId", -1)) != int(pid):
			continue
		if not phase in ["boss", "setup", "build"] and pc.is_empty():
			continue
		var moves: Array = gm.legal_moves(int(pid))
		if moves.is_empty():
			continue
		var mv = moves[0] if phase == "boss" else _timed_pick(int(pid))
		if mv == null:
			for m in moves:
				if str((m as Dictionary).get("type", "")) in ["pass", "passBuild"]:
					mv = m
					break
		if mv != null and gm.apply_move(int(pid), mv):
			return true
	return false

func _timed_pick(pid: int):
	var t0 := Time.get_ticks_usec()
	var mv = AI.pick_move(gm, pid)
	ai_us.append(Time.get_ticks_usec() - t0)
	return mv

## Un pas de soak_runner._play (meme ordre de decision), humains en plus. Faux si la partie cale.
func _soak_step() -> bool:
	var m := gm
	var phase: String = m.G["phase"]
	var pc: Dictionary = m.G.get("pendingChoice", {})
	if not pc.is_empty():
		var owner := int(pc.get("playerId", 0))
		var cmoves: Array = m.legal_moves(owner)
		if not cmoves.is_empty():
			var cmv = _timed_pick(owner)
			if cmv == null or not m.apply_move(owner, cmv):
				m.apply_move(owner, cmoves[0])
			return true
	if phase == "boss":
		for pid in m.G["players"]:
			var moves: Array = m.legal_moves(int(pid))
			if not moves.is_empty():
				m.apply_move(int(pid), moves[0])
				return true
		return false
	if phase == "build" or phase == "setup":
		if _human_act() or humans == 0: # IA seules : Match._drive_ai joue la construction ; rien a faire ici
			return true
		for pid in m.G["players"]: # avec un humain, _drive_ai s'arrete a son siege : une IA qui doit repondre (pile de sorts...) joue ici
			var bm = AI.pick_move(m, int(pid))
			if bm != null and m.apply_move(int(pid), bm):
				return true
			for pm in m.legal_moves(int(pid)):
				if str((pm as Dictionary).get("type", "")) in ["pass", "passBuild"] and m.apply_move(int(pid), pm):
					return true
		return false
	if phase != "adventure":
		return false
	var ap := m.active_player()
	var amoves := m.legal_moves(ap)
	var mv = null
	var acted := false
	if not amoves.is_empty():
		mv = _timed_pick(ap)
		if mv == null:
			mv = amoves[0]
		if AI.score_move(m, ap, mv) >= 0.0 and m.apply_move(ap, mv):
			acted = true
	if not acted:
		for pid in m.G["players"]:
			for pm in m.legal_moves(int(pid)):
				if not acted and str((pm as Dictionary).get("type", "")) in ["pass", "passBuild"] and m.apply_move(int(pid), pm):
					acted = true
		if not acted and mv != null and m.apply_move(ap, mv):
			acted = true
		if not acted:
			for pid in m.G["players"]:
				var pmoves: Array = m.legal_moves(int(pid))
				if not pmoves.is_empty() and m.apply_move(int(pid), pmoves[0]):
					return true
	return acted

# --- Rapport ---
static func _pct(sorted: Array, q: float) -> float:
	return float(sorted[mini(sorted.size() - 1, int(q * sorted.size()))]) / 1000.0

func _stats(label: String, us: Array) -> void:
	if us.is_empty():
		print("PERF %-22s n=0" % label)
		return
	var s := us.duplicate()
	s.sort()
	var tot := 0
	for v in s:
		tot += int(v)
	print("PERF %-22s n=%-5d p50=%7.2f p95=%7.2f p99=%7.2f max=%7.2f ms  total=%8.1f ms  >50ms=%d" % [label, s.size(), _pct(s, 0.5), _pct(s, 0.95), _pct(s, 0.99), float(s[-1]) / 1000.0, tot / 1000.0, s.filter(func(v): return v > 50000).size()])

func _report() -> void:
	var us: Array = all_recs.map(func(r): return r["us"])
	print("PERF ==== players=%d sets=%s humans=%d ui=%s games=%d ====" % [players, ",".join(sets), humans, ui_mode, games])
	_stats("apply_move (externe)", us)
	_stats("apply_move sans sub", all_recs.map(func(r): return r["us"] - r["sub_us"]))
	_stats("AI.pick_move", ai_us)
	if ui_mode:
		_stats("refresh (1 appel, signal)", ref_each)
		_stats("refresh (somme / coup)", all_recs.filter(func(r): return r["ref_n"] > 0).map(func(r): return r["ref_us"]))
		_stats("frame (_process)", frame_us)
		var emits := 0
		for r in all_recs:
			emits += int(r["ref_n"])
		print("PERF refresh par apply_move externe : %.2f (via state_changed)" % (float(emits) / maxf(1.0, all_recs.size())))
	var by_phase := {}
	for r in all_recs:
		var k := "%s%s" % [r["phase"], " (avec sub)" if int(r["sub_n"]) > 0 else ""]
		if not by_phase.has(k):
			by_phase[k] = []
		by_phase[k].append(r["us"])
	for k in by_phase:
		_stats("  phase " + k, by_phase[k])
	var sorted_recs := all_recs.duplicate()
	sorted_recs.sort_custom(func(x, y): return x["us"] > y["us"])
	print("PERF -- %d coups les plus lents (ms ; sub = apply_move imbriques ; ref = refresh via signal)" % top_n)
	for r in sorted_recs.slice(0, top_n):
		print("PERF %8.2f ms  turn=%-2d %-9s %-40s sub=%d/%.2f ms  ref=%d/%.2f ms" % [float(r["us"]) / 1000.0, r["turn"], r["phase"], r["label"], r["sub_n"], float(r["sub_us"]) / 1000.0, r["ref_n"], float(r["ref_us"]) / 1000.0])
	print("PERF OK")
