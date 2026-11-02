extends RefCounted
## Pilotage IA par images (Match.ai_step_mode, BoardUI.spread_ai) : memes coups, meme ordre, memes tirages qu'en synchrone.
## Parties a graine fixe jouees deux fois (synchrone / une tranche d'IA par image) ; la suite des coups (imbriques compris) et l'etat final doivent etre egaux.
## Appele par goldens.gd : `load("res://godot/tests/goldens_stepai.gd").new().run(_ok, self)`.

const SoakSeed = preload("res://godot/tests/soak_seed.gd")
const AI = preload("res://godot/scripts/AI.gd")

## Enregistre chaque apply_move, imbriques compris (l'IA de la construction joue a l'interieur du coup qui la declenche).
class Rec extends "res://godot/scripts/GameManager.gd":
	var seq: Array = []
	func apply_move(pid: int, move: Dictionary) -> bool:
		if _ai_pending and not _ai_driving:
			flush_ai() # le coup entrant termine d'abord le pilotage IA : ses coups precedent donc celui-ci dans la liste
		var i := seq.size() # a l'entree : en synchrone un coup se termine apres les coups IA imbriques, en images avant
		seq.append("%d:%s:%s" % [pid, move.get("type", ""), str(move.get("args", []))])
		var ok: bool = super.apply_move(pid, move)
		seq[i] += ":" + str(ok)
		return ok

var _ok: Callable
var host: Node
var _probes := 0 # coups humains arrives pendant un pilotage IA en attente

func run(ok: Callable, h: Node) -> void:
	_ok = ok
	host = h
	for cfg in [[2, ["base"], 0, 1000], [4, ["crash-landing"], 0, 1001], [6, ["crash-landing"], 0, 1000], [6, ["crash-landing"], 1, 1001]]:
		var sync := _play(cfg[0], cfg[1], cfg[2], cfg[3], false)
		_probes = 0
		var step := _play(cfg[0], cfg[1], cfg[2], cfg[3], true)
		var tag := "%d joueurs, %d humain, graine %d" % [cfg[0], cfg[2], cfg[3]]
		_ok.call(sync["done"] and step["done"], "pilotage IA par images : %s, partie terminee" % tag)
		_ok.call(sync["seq"] == step["seq"], "pilotage IA par images : %s, memes coups dans le meme ordre (%d)" % [tag, (sync["seq"] as Array).size()])
		_ok.call(sync["state"] == step["state"], "pilotage IA par images : %s, meme etat final" % tag)
		if cfg[2] == 1:
			_ok.call(_probes > 0, "pilotage IA par images : un coup humain arrive pendant le pilotage et le termine d'abord (%d)" % _probes)

func _play(n: int, sets: Array, humans: int, game_seed: int, step: bool) -> Dictionary:
	var m = Rec.new()
	host.add_child(m)
	SoakSeed.seed_game(m, game_seed)
	Match._tuid_seq = 0 # compteur statique des identifiants de cible : il fait partie de l'etat compare
	m.ai_step_mode = step
	m.ai_step_budget_us = 0 # une seule tranche de boucle par image : le plus de reports possible
	m.start_new_game(n, humans, sets)
	var steps := 0
	while m.G.get("gameOver") == null and steps < 12000:
		steps += 1
		if m.ai_pending():
			m.drive_ai_step()
		elif not _act(m, humans, step):
			break
	var out := {"done": m.G.get("gameOver") != null, "seq": m.seq, "state": hash(var_to_str(m.G))}
	SoakSeed.unseed()
	m.queue_free()
	return out

## Un pas de decision hors Match._drive_ai (reprend soak_runner / perf_bench) ; faux si la partie cale.
func _act(m, humans: int, step: bool) -> bool:
	var phase: String = m.G["phase"]
	var pc: Dictionary = m.G.get("pendingChoice", {})
	if not pc.is_empty():
		var owner := int(pc.get("playerId", 0))
		if not (m.legal_moves(owner) as Array).is_empty():
			var cmv = AI.pick_move(m, owner)
			if cmv == null or not m.apply_move(owner, cmv):
				m.apply_move(owner, m.legal_moves(owner)[0])
			return true
	if phase == "boss":
		for pid in m.G["players"]:
			var moves: Array = m.legal_moves(int(pid))
			if not moves.is_empty():
				m.apply_move(int(pid), moves[0])
				return true
		return false
	if phase == "build" or phase == "setup":
		for pid in m.G["players"]:
			if bool((m.G["players"][pid] as Dictionary).get("isAI", false)) or (m.legal_moves(int(pid)) as Array).is_empty():
				continue
			var mv = AI.pick_move(m, int(pid))
			if mv == null:
				mv = {"type": "passBuild", "args": []}
			if m.apply_move(int(pid), mv):
				# Deux coups humains perimes juste apres : en mode images, celui qui suit un DONE arrive pendant le pilotage et doit le terminer avant d'etre juge.
				for _i in 2:
					_probes += 1 if m.ai_pending() else 0
					m.apply_move(int(pid), {"type": "passBuild", "args": []})
				return true
		return humans == 0 or _ai_respond(m)
	if phase != "adventure":
		return false
	return _adventure(m)

## Avec un humain, _drive_ai s'arrete a son siege : une IA qui doit repondre (pile de sorts...) joue ici.
func _ai_respond(m) -> bool:
	for pid in m.G["players"]:
		var bm = AI.pick_move(m, int(pid))
		if bm != null and m.apply_move(int(pid), bm):
			return true
		for pm in m.legal_moves(int(pid)):
			if str((pm as Dictionary).get("type", "")) in ["pass", "passBuild"] and m.apply_move(int(pid), pm):
				return true
	return false

func _adventure(m) -> bool:
	var ap: int = m.active_player()
	var amoves: Array = m.legal_moves(ap)
	var mv = null
	if not amoves.is_empty():
		mv = AI.pick_move(m, ap)
		if mv == null:
			mv = amoves[0]
		if AI.score_move(m, ap, mv) >= 0.0 and m.apply_move(ap, mv):
			return true
	for pid in m.G["players"]:
		for pm in m.legal_moves(int(pid)):
			if str((pm as Dictionary).get("type", "")) in ["pass", "passBuild"] and m.apply_move(int(pid), pm):
				return true
	if mv != null and m.apply_move(ap, mv):
		return true
	for pid in m.G["players"]:
		var pmoves: Array = m.legal_moves(int(pid))
		if not pmoves.is_empty() and m.apply_move(int(pid), pmoves[0]):
			return true
	return false
