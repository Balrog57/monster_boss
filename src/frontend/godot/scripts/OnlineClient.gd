class_name OnlineClient
extends Node
## Pont REST vers le serveur Node (lobby entre amis, polling, sans Socket.IO).
## Endpoints : POST /lobby/matches, POST .../join, GET .../state, POST .../move.
## shortcut: pas de push temps reel — polling 2 s (lobby) / 2,5 s (etat).

signal lobby_changed(info: Dictionary)
signal state_received
signal request_error(message: String)

var host: String = "http://127.0.0.1:8000"
var match_id: String = ""
var player_id: int = -1
var credentials: String = ""
var player_name: String = ""
var current_G: Dictionary = {}
var current_ctx: Dictionary = {}
var current_moves: Array = []
var current_seats: Array = []
var current_status: String = ""
var current_num_players: int = 0

var _busy := false
var _lobby_timer: Timer
var _state_timer: Timer

func _ready() -> void:
	if OS.has_feature("web"):
		var origin = JavaScriptBridge.eval("window.location.origin")
		if origin != null and str(origin) != "" and str(origin) != "null":
			host = str(origin)
	_lobby_timer = Timer.new()
	_lobby_timer.wait_time = 2.0
	_lobby_timer.timeout.connect(func(): fetch_lobby())
	add_child(_lobby_timer)
	_state_timer = Timer.new()
	_state_timer.wait_time = 2.5
	_state_timer.timeout.connect(func(): fetch_state())
	add_child(_state_timer)

func start_lobby_poll() -> void:
	_lobby_timer.start()

func stop_lobby_poll() -> void:
	_lobby_timer.stop()

func start_state_poll() -> void:
	_state_timer.start()

func stop_state_poll() -> void:
	_state_timer.stop()

func _req(method: int, path: String, body = null) -> Dictionary:
	var http := HTTPRequest.new()
	add_child(http)
	var url := host.trim_suffix("/") + path
	var payload := "" if body == null else JSON.stringify(body)
	if http.request(url, ["Content-Type: application/json"], method, payload) != OK:
		http.queue_free()
		return {"ok": false, "error": "connexion impossible (%s)" % host}
	var res: Array = await http.request_completed
	http.queue_free()
	var code: int = res[1]
	var data = JSON.parse_string((res[3] as PackedByteArray).get_string_from_utf8())
	if code < 200 or code >= 300:
		var msg := "erreur %d" % code
		if data is Dictionary and (data as Dictionary).has("message"):
			msg = str((data as Dictionary)["message"])
		return {"ok": false, "error": msg, "status": code}
	return {"ok": true, "status": code, "json": data}

## Cree un salon prive (amis uniquement : isPublic=false) et prend un siege.
func create_lobby(num_players: int, expansions: Array) -> bool:
	var r := await _req(HTTPClient.METHOD_POST, "/lobby/matches", {
		"numPlayers": num_players,
		"setupData": {"isPublic": false, "expansions": expansions},
	})
	if not r.get("ok", false):
		request_error.emit(str(r.get("error", "?")))
		return false
	return await join_lobby(str((r["json"] as Dictionary).get("matchID", "")), player_name)

func join_lobby(code: String, pname: String) -> bool:
	player_name = pname
	var r := await _req(HTTPClient.METHOD_POST, "/lobby/matches/%s/join" % code.strip_edges().to_upper(), {"playerName": pname})
	if not r.get("ok", false):
		request_error.emit(str(r.get("error", "?")))
		return false
	match_id = code.strip_edges().to_upper()
	player_id = int((r["json"] as Dictionary).get("playerID", -1))
	credentials = str((r["json"] as Dictionary).get("credentials", ""))
	return true

func fetch_lobby() -> void:
	if _busy or match_id == "":
		return
	_busy = true
	var r := await _req(HTTPClient.METHOD_GET, "/lobby/matches/%s" % match_id)
	_busy = false
	if not r.get("ok", false):
		request_error.emit(str(r.get("error", "?")))
		return
	var j: Dictionary = r["json"]
	current_seats = j.get("seats", [])
	current_status = str(j.get("status", ""))
	current_num_players = int(j.get("numPlayers", 0))
	lobby_changed.emit({"status": current_status, "seats": current_seats, "numPlayers": current_num_players})

func fetch_state() -> void:
	if _busy or match_id == "" or credentials == "":
		return
	_busy = true
	var path := "/lobby/matches/%s/state?playerID=%d&credentials=%s" % [match_id, player_id, credentials.uri_encode()]
	var r := await _req(HTTPClient.METHOD_GET, path)
	_busy = false
	if not r.get("ok", false):
		request_error.emit(str(r.get("error", "?")))
		return
	_store_view(r["json"])

func leave_match() -> void:
	if match_id == "":
		return
	await _req(HTTPClient.METHOD_POST, "/lobby/matches/%s/leave" % match_id, {
		"playerID": player_id, "credentials": credentials,
	})
	match_id = ""
	credentials = ""
	player_id = -1

func send_move(move: Dictionary) -> void:
	if match_id == "" or credentials == "":
		return
	var r := await _req(HTTPClient.METHOD_POST, "/lobby/matches/%s/move" % match_id, {
		"playerID": player_id, "credentials": credentials, "move": move,
	})
	if not r.get("ok", false):
		request_error.emit(str(r.get("error", "?")))
		fetch_state()
		return
	_store_view(r["json"])

func _store_view(j: Dictionary) -> void:
	current_G = normalize_view(j.get("G", {}))
	if j.has("turnDeadline") and j["turnDeadline"] != null:
		current_G["turnDeadline"] = int(j["turnDeadline"])
	current_ctx = j.get("ctx", {})
	current_moves = _numfix(j.get("moves", []))
	current_status = str(j.get("status", current_status))
	current_seats = j.get("seats", current_seats)
	state_received.emit()

## Normalise la vue serveur (cles texte JSON -> int, logs, fin de partie).
static func normalize_view(view) -> Dictionary:
	if not (view is Dictionary):
		return {}
	var g: Dictionary = _numfix((view as Dictionary).duplicate(true))
	var players_in: Dictionary = g.get("players", {})
	var players := {}
	for k in players_in:
		players[int(str(k))] = players_in[k]
	g["players"] = players
	var order: Array = []
	for pid in g.get("xpOrder", []):
		order.append(int(pid))
	g["xpOrder"] = order
	g["log"] = g.get("logs", [])
	if g.get("gameOver", false):
		g["gameOver"] = {"winner": int(g.get("winner", -1)), "reason": "partie en ligne"}
	else:
		g["gameOver"] = null
	return g

## JSON.parse_string rend des float : reconvertit les entiers exacts.
static func _numfix(v):
	if v is float and v == floor(v):
		return int(v)
	if v is Array:
		var out: Array = []
		for e in v:
			out.append(_numfix(e))
		return out
	if v is Dictionary:
		var out := {}
		for k in v:
			out[k] = _numfix(v[k])
		return out
	return v
