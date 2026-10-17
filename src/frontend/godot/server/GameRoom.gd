class_name GameRoom
extends RefCounted
## GameRoom — une salle : sieges, partie Match.gd autoritaire, bots, minuteur de decision.
## Le serveur (Server.gd) ne fait que router les messages ; toute la logique de jeu est ici.

const MatchScript = preload("res://godot/scripts/Match.gd")
const AI = preload("res://godot/scripts/AI.gd")
const ViewFilter = preload("res://godot/server/ViewFilter.gd")
const NetCodec = preload("res://godot/scripts/NetCodec.gd")

const MAX_AI_STEPS_PER_TICK := 400 # bot_delay = 0 (tests) : plafond de coups IA par image

var code := ""
var num_players := 2
var sets: Array = []
var seats: Array = [] # {name, bot, taken, token, conn, auto, left, avatar, wins, defeats}
var host := 0
var status := "open" # open | running | finished
var m = null # Match
var turn_timeout_ms := 60000 # 0 = pas de minuteur
var adventure_timeout_ms := 10000
var bot_delay_ms := 350
var send: Callable # (conn_id: int, msg: Dictionary)
var last_activity_ms := 0
var deadline_ms := 0 # horloge unix en ms ; 0 = personne n'est attendu
var awaited_seats: Array = [] # sieges humains dont une decision bloque la partie (calcule avec deadline_ms)
var _next_ai_ms := 0
var _dirty := false

func _init(p_code: String, p_players: int, p_sets: Array) -> void:
	code = p_code
	num_players = clampi(p_players, 2, 4)
	sets = p_sets
	for i in num_players:
		seats.append({"name": "", "bot": false, "taken": false, "token": "", "conn": -1, "auto": false, "left": false, "avatar": "", "wins": 0, "defeats": 0})
	last_activity_ms = _now()

static func _now() -> int:
	return int(Time.get_unix_time_from_system() * 1000.0)

func dispose() -> void:
	if m != null:
		m.free()
		m = null

# --- sieges -----------------------------------------------------------------

func add_bots(count: int) -> void:
	var i := num_players - 1
	while count > 0 and i >= 1:
		if not seats[i]["taken"]:
			seats[i].merge({"bot": true, "taken": true, "name": "IA %d" % i}, true)
			count -= 1
		i -= 1

func free_seat() -> int:
	for i in num_players:
		if not seats[i]["taken"]:
			return i
	return -1

func has_active_human() -> bool: # un humain qui n'a pas abandonne (connecte ou pas : il peut revenir)
	for s in seats:
		if not s["bot"] and s["taken"] and not s["left"]:
			return true
	return false

func humans_connected() -> int:
	var c := 0
	for s in seats:
		if not s["bot"] and s["taken"] and int(s["conn"]) >= 0:
			c += 1
	return c

## Prend le premier siege libre ; renvoie {"seat", "token"} ou {} si plein / deja lance.
func join(pname: String, conn: int, prof: Dictionary = {}) -> Dictionary:
	var i := free_seat()
	if status != "open" or i < 0:
		return {}
	var token := _token()
	seats[i].merge({"name": pname, "taken": true, "token": token, "conn": conn, "auto": false, "left": false,
		"avatar": str(prof.get("avatar", "")), "wins": int(prof.get("wins", 0)), "defeats": int(prof.get("defeats", 0))}, true)
	if i == 0 or not seats[host]["taken"]:
		host = i
	touch()
	_dirty = true
	return {"seat": i, "token": token}

## Reprise d'un siege avec son jeton (reconnexion / rechargement de page). Rend le siege au joueur.
func resume(seat: int, token: String, conn: int) -> bool:
	if seat < 0 or seat >= num_players:
		return false
	var s: Dictionary = seats[seat]
	if s["bot"] or not s["taken"] or s["left"] or str(s["token"]) == "" or str(s["token"]) != token:
		return false
	s["conn"] = conn
	s["auto"] = false
	touch()
	if status == "running" and m != null:
		_reset_deadline() # le joueur de retour repart avec un delai complet
	_dirty = true
	return true

func detach(conn: int) -> void:
	for s in seats:
		if int(s["conn"]) == conn:
			s["conn"] = -1
			_dirty = true

func seat_of(conn: int) -> int:
	for i in num_players:
		if int(seats[i]["conn"]) == conn:
			return i
	return -1

## Depart volontaire : en salle d'attente le siege est libere, en partie l'IA le garde pour de bon.
func leave(seat: int) -> void:
	var s: Dictionary = seats[seat]
	if status == "open":
		s.merge({"name": "", "taken": false, "token": "", "conn": -1, "avatar": "", "wins": 0, "defeats": 0}, true)
	else:
		s.merge({"conn": -1, "token": "", "left": true, "auto": true}, true)
	_dirty = true

func touch() -> void:
	last_activity_ms = _now()

static func _token() -> String:
	return Crypto.new().generate_random_bytes(16).hex_encode()

# --- demarrage --------------------------------------------------------------

## Lance la partie ; les sieges vides deviennent des IA.
func start() -> bool:
	if status != "open":
		return false
	var humans := 0
	for i in num_players:
		if not seats[i]["taken"]:
			seats[i].merge({"bot": true, "taken": true, "name": "IA %d" % i}, true)
		if not seats[i]["bot"]:
			humans += 1
	if humans == 0:
		return false
	m = MatchScript.new()
	m.rng.randomize()
	m.new_match(num_players, humans, sets)
	for i in num_players: # new_match suppose des humains contigus : on fixe isAI siege par siege
		(m.G["players"][i] as Dictionary)["isAI"] = bool(seats[i]["bot"])
	status = "running"
	touch()
	_reset_deadline()
	_dirty = true
	return true

# --- coups ------------------------------------------------------------------

static func _trim(args) -> Array:
	var a: Array = args.duplicate() if args is Array else []
	while not a.is_empty() and a[a.size() - 1] == null:
		a.pop_back()
	return a

## Valide un coup recu d'un client : il doit etre EXACTEMENT un coup de Match.legal_moves(seat).
## On applique alors la version du serveur (jamais celle du client). Renvoie "" ou un message d'erreur.
func submit_move(seat: int, move: Dictionary) -> String:
	if status != "running" or m == null:
		return "partie non en cours"
	var type := str(move.get("type", ""))
	var args := _trim(move.get("args", []))
	for lm in m.legal_moves(seat):
		# NetCodec.decode : les cartes du moteur portent des flottants entiers (2.0) que le client a recus en entiers.
		if str((lm as Dictionary).get("type", "")) == type and _trim(NetCodec.decode((lm as Dictionary).get("args", []))) == args:
			if not m.apply_move(seat, lm):
				return "coup refuse"
			seats[seat]["auto"] = false # le joueur a repris la main
			_after_move()
			return ""
	return "coup illegal"

func _after_move() -> void:
	touch()
	_dirty = true
	if m.G.get("gameOver") != null:
		status = "finished"
		deadline_ms = 0
	else:
		_reset_deadline()

# --- IA / minuteur ----------------------------------------------------------

func _is_ai(pid: int) -> bool:
	var s: Dictionary = seats[pid]
	return bool(s["bot"]) or bool(s["auto"])

func _pass_move(moves: Array):
	for mv in moves:
		if str((mv as Dictionary).get("type", "")) in ["pass", "passBuild"]:
			return mv
	return null

## Fait jouer le siege par l'IA (ou "passer" si pass_only). Faux si rien n'a pu etre applique.
func _ai_play(pid: int, pass_only: bool) -> bool:
	var moves: Array = m.legal_moves(pid)
	if moves.is_empty():
		return false
	var cands: Array = []
	if pass_only and _pass_move(moves) != null:
		cands.append(_pass_move(moves))
	else:
		cands.append(AI.pick_move(m, pid))
	cands.append(moves[0])
	for mv in cands:
		if mv != null and m.apply_move(pid, mv):
			_after_move()
			return true
	return false

func _in_adventure_pause() -> bool:
	var adv: Dictionary = m.G.get("adventure", {}) as Dictionary
	return str(m.G.get("phase", "")) == "adventure" and adv.has("pause") and adv["pause"] != null and (m.G.get("stack", []) as Array).is_empty()

## Un coup d'IA pour un siege qui est IA (bot ou prise de relais). Meme politique que le harnais Soak.
func _ai_step() -> bool:
	var G: Dictionary = m.G
	if G.get("gameOver") != null:
		return false
	var pc: Dictionary = G.get("pendingChoice", {})
	if not pc.is_empty():
		var owner := int(pc.get("playerId", -1))
		return _is_ai(owner) and _ai_play(owner, false)
	var phase := str(G.get("phase", ""))
	if phase == "boss" or phase == "setup":
		for pid in num_players:
			if _is_ai(pid) and _ai_play(pid, false):
				return true
		return false
	var ap: int = m.active_player()
	if phase == "build":
		if G.has("buildWindow") and (G.get("stack", []) as Array).is_empty():
			for pid in num_players:
				if _is_ai(pid) and not bool((G["buildWindow"] as Dictionary).get(pid, false)) and _ai_play(pid, true):
					return true
			return false
		return _is_ai(ap) and _ai_play(ap, false)
	if phase == "adventure":
		if _in_adventure_pause():
			for pid in num_players:
				if _is_ai(pid) and _ai_play(pid, pid != ap):
					return true
			return false
		return _is_ai(ap) and _ai_play(ap, false)
	return false

## Humains (non IA) dont une decision bloque la partie maintenant.
func _awaited() -> Array:
	var out: Array = []
	for pid in num_players:
		if not _is_ai(pid) and not (m.legal_moves(pid) as Array).is_empty():
			out.append(pid)
	var G: Dictionary = m.G
	var pc: Dictionary = G.get("pendingChoice", {})
	if not pc.is_empty():
		return out.filter(func(p): return p == int(pc.get("playerId", -1)))
	var phase := str(G.get("phase", ""))
	if phase == "boss" or phase == "setup" or _in_adventure_pause():
		return out
	if phase == "build" and G.has("buildWindow") and (G.get("stack", []) as Array).is_empty():
		return out
	return out.filter(func(p): return p == m.active_player())

func _reset_deadline() -> void:
	awaited_seats = _awaited() if status == "running" and m != null else []
	if turn_timeout_ms <= 0 or awaited_seats.is_empty():
		deadline_ms = 0
	else:
		deadline_ms = _now() + (adventure_timeout_ms if _in_adventure_pause() else turn_timeout_ms)

## Appelee a chaque image par le serveur. Renvoie vrai si l'etat a change (a diffuser).
func tick() -> bool:
	if status == "running":
		var now := _now()
		if now >= _next_ai_ms:
			var steps := 0
			var limit := MAX_AI_STEPS_PER_TICK if bot_delay_ms <= 0 else 1
			while steps < limit and status == "running" and _ai_step():
				steps += 1
			if steps > 0:
				_next_ai_ms = now + bot_delay_ms
		if status == "running" and deadline_ms > 0 and now >= deadline_ms:
			for pid in _awaited():
				seats[pid]["auto"] = true # l'IA joue pour lui jusqu'a ce qu'il rejoue ou se reconnecte
				m._log("Joueur %d n'a pas répondu à temps — l'IA prend le relais." % pid)
			_dirty = true
			_reset_deadline()
	var d := _dirty
	_dirty = false
	return d

# --- messages ---------------------------------------------------------------

func lobby_msg() -> Dictionary:
	var out: Array = []
	for s in seats:
		out.append({"name": (str(s["name"]) if s["taken"] else null), "bot": s["bot"], "connected": int(s["conn"]) >= 0 or bool(s["bot"]),
			"avatar": s["avatar"], "wins": s["wins"], "defeats": s["defeats"]})
	return {"t": "lobby", "code": code, "status": status, "numPlayers": num_players, "seats": out, "sets": sets, "host": host}

func state_msg(seat: int) -> Dictionary:
	var msg := lobby_msg()
	msg["t"] = "state"
	msg["seat"] = seat
	msg["view"] = NetCodec.encode(ViewFilter.for_seat(m.G, seat))
	msg["moves"] = m.legal_moves(seat)
	msg["deadline"] = deadline_ms
	msg["awaited"] = awaited_seats
	msg["serverTime"] = _now()
	return msg

## Message adapte a l'etat de la salle pour un siege (lobby avant la partie, etat filtre ensuite).
func message_for(seat: int) -> Dictionary:
	return lobby_msg() if status == "open" or m == null else state_msg(seat)

func broadcast() -> void:
	for i in num_players:
		var conn := int(seats[i]["conn"])
		if conn >= 0:
			send.call(conn, message_for(i))
