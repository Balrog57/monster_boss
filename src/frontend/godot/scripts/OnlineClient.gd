class_name OnlineClient
extends Node
## Client WebSocket du serveur Godot headless (godot/server/Server.gd ; protocole : godot/server/PROTOCOL.md).
## Meme interface publique que l'ancien pont REST (signaux, current_G, current_moves...) : Main.gd et BoardUI.gd
## n'ont rien a changer. Le serveur POUSSE lobby et etat ; start/stop_*_poll et fetch_* ne font que demander
## une resynchronisation. Reconnexion automatique avec le jeton de siege ; la session est gardee dans user://
## pour reprendre apres un rechargement de page (try_resume).

signal lobby_changed(info: Dictionary)
signal state_received
signal request_error(message: String)
signal _reply(kind: String, data: Dictionary)

const NetCodec = preload("res://godot/scripts/NetCodec.gd")
const Profile = preload("res://godot/scripts/Profile.gd")

const DEFAULT_URL := "ws://localhost:8091"
## Ancienne valeur par defaut du serveur Node (REST) : n'est plus une adresse valide, on prend l'URL par defaut.
const LEGACY_HOST := "http://127.0.0.1:8000"
const SESSION_PATH := "user://online_session.cfg"
const REQUEST_TIMEOUT_S := 8.0
const PING_EVERY_S := 20.0
## Onglet de navigateur en arriere-plan : requestAnimationFrame / minuteurs sont suspendus ou ralentis. Une image qui arrive apres un
## trou aussi long (delta) declenche un ping immediat ; sans aucun paquet pendant PONG_TIMEOUT_S ensuite, la liaison est reputee morte
## (le serveur a pu la couper apres IDLE_TIMEOUT_MS) et on la rouvre avec le jeton de siege.
const SLEEP_GAP_S := 5.0
const PONG_TIMEOUT_S := 8.0

var host: String = "" # URL du serveur : ws(s)://hote:port, ou http(s)://hote (web : devient ws(s)://hote/ws)
var match_id: String = ""
var player_id: int = -1
var credentials: String = "" # jeton de siege
var player_name: String = ""
var player_avatar: String = "" # profil cosmetique envoye au serveur (salle d'attente : avatar, victoires, defaites)
var player_wins := 0
var player_defeats := 0
var last_error_code := "" # `code` de la derniere erreur serveur ("not_found", "full"...), "" si c'etait un probleme de liaison
var current_G: Dictionary = {}
var current_ctx: Dictionary = {}
var current_moves: Array = []
var current_seats: Array = []
var current_status: String = ""
var current_num_players: int = 0
var current_host := -1 # siege de l'hote (donne par le lobby)
var current_awaited: Array = [] # sieges humains attendus par le serveur (compte a rebours) ; vide si le serveur ne le dit pas
var clock_offset_ms := 0 # horloge serveur - horloge locale (ms), pour afficher le delai restant
var count_results := true # faux dans les tests : ne touche pas aux compteurs du profil
var _result_for := "" # code de la salle dont le resultat est deja compte dans Profile
var connected := false
var is_host := false

var _ws: WebSocketPeer = null
var _url := ""
var _call_id := 0
var _ping_in := PING_EVERY_S
var _pong_wait := 0.0 # > 0 : un ping attend sa reponse depuis ce nombre de secondes
var _retry_in := 0.0
var _retry_n := 0
var _resume_on_open := false # reconnexion apres une coupure : renvoyer resume des l'ouverture
var _want_open := false # une session est en cours : on reconnecte si la liaison tombe
var _last_fight := 0 # signature du dernier lastHeroFight recu (le serveur le garde dans G : on ne rejoue pas l'animation)

## URL du serveur : `host` explicite, sinon reglage de projet bossmonster/online/server_url, sinon
## (web) meme hote que la page sur /ws, sinon ws://localhost:8091.
func server_url() -> String:
	var h := host.strip_edges()
	if h == "" or h == LEGACY_HOST:
		h = str(ProjectSettings.get_setting("bossmonster/online/server_url", ""))
	if (h == "" or h == LEGACY_HOST) and OS.has_feature("web"):
		var origin = JavaScriptBridge.eval("window.location.origin")
		if origin != null and str(origin) != "" and str(origin) != "null":
			h = str(origin)
	if h == "" or h == LEGACY_HOST:
		return DEFAULT_URL
	if h.begins_with("https://"):
		h = "wss://" + h.substr(8)
	elif h.begins_with("http://"):
		h = "ws://" + h.substr(7)
	elif not (h.begins_with("ws://") or h.begins_with("wss://")):
		h = "ws://" + h
	# Origine web nue (http(s)://hote) : le proxy inverse sert le websocket sur /ws.
	if h.find("/", h.find("://") + 3) < 0 and OS.has_feature("web"):
		h += "/ws"
	return h

# --- liaison ----------------------------------------------------------------

func _process(delta: float) -> void:
	if _ws == null:
		if _want_open and _retry_in > 0.0:
			_retry_in -= delta
			if _retry_in <= 0.0:
				_open()
		return
	_ws.poll()
	match _ws.get_ready_state():
		WebSocketPeer.STATE_OPEN:
			if not connected:
				connected = true
				_retry_n = 0
				if _resume_on_open and match_id != "" and credentials != "":
					_send({"t": "resume", "code": match_id, "seat": player_id, "token": credentials})
				_reply.emit("open", {})
			var waited := _pong_wait
			while _ws.get_available_packet_count() > 0:
				_pong_wait = 0.0 # n'importe quel paquet prouve que la liaison vit
				waited = 0.0
				var pkt := _ws.get_packet()
				if _ws.was_string_packet():
					_on_message(NetCodec.parse_message(pkt.get_string_from_utf8()))
			if delta > SLEEP_GAP_S:
				_ping_in = 0.0
			_ping_in -= delta
			if _ping_in <= 0.0:
				_ping_in = PING_EVERY_S
				_send({"t": "ping"})
				if _pong_wait <= 0.0:
					_pong_wait = 0.001
			elif waited > 0.0:
				_pong_wait = waited + delta
				if _pong_wait > PONG_TIMEOUT_S:
					_pong_wait = 0.0
					_ws.close() # le STATE_CLOSED qui suit relance la reconnexion (resume)
		WebSocketPeer.STATE_CLOSED:
			var was_open := connected
			connected = false
			_pong_wait = 0.0
			_ws = null
			_reply.emit("closed", {})
			_resume_on_open = match_id != ""
			if _want_open:
				if was_open:
					request_error.emit("connexion perdue, reconnexion...")
				_schedule_retry()

func _schedule_retry() -> void:
	_retry_n += 1
	_retry_in = minf(1.0 * _retry_n, 8.0)

func _open() -> void:
	_ws = WebSocketPeer.new()
	_ws.inbound_buffer_size = 4 << 20 # un etat complet depasse largement les 64 Kio par defaut
	_ws.max_queued_packets = 256
	_url = server_url()
	if _ws.connect_to_url(_url) != OK:
		_ws = null
		_schedule_retry()

func _send(msg: Dictionary) -> bool:
	if _ws == null or _ws.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return false
	return _ws.send_text(JSON.stringify(msg)) == OK

## Attend l'ouverture de la liaison (avec delai). Faux si impossible.
func _ensure_open() -> bool:
	if connected:
		return true
	_want_open = true
	if _ws == null:
		_open()
	var id := _arm_timeout()
	while true:
		var r: Array = await _reply
		if r[0] == "open":
			return true
		if r[0] == "timeout" and r[1].get("id", -1) == id:
			return false
		if r[0] == "closed" and _ws == null and _retry_n >= 2:
			return false
	return false

func _arm_timeout() -> int:
	_call_id += 1
	var id := _call_id
	get_tree().create_timer(REQUEST_TIMEOUT_S).timeout.connect(func(): _reply.emit("timeout", {"id": id}))
	return id

## Envoie `msg` et attend la reponse `ok_kind` (ou une erreur). Renvoie le dictionnaire recu, {} si echec.
func _call(msg: Dictionary, ok_kind: String) -> Dictionary:
	if not await _ensure_open():
		request_error.emit("connexion impossible (%s)" % server_url())
		_want_open = match_id != ""
		return {}
	var id := _arm_timeout()
	_send(msg)
	while true:
		var r: Array = await _reply
		if r[0] == ok_kind:
			return r[1]
		if r[0] == "error":
			return {}
		if r[0] == "timeout" and r[1].get("id", -1) == id:
			request_error.emit("le serveur ne repond pas")
			return {}
	return {}

func _on_message(d: Dictionary) -> void:
	match str(d.get("t", "")):
		"joined":
			match_id = str(d.get("code", ""))
			player_id = int(d.get("seat", -1))
			credentials = str(d.get("token", ""))
			is_host = bool(d.get("host", false))
			_save_session()
			_reply.emit("joined", d)
		"lobby":
			_store_lobby(d)
		"state":
			_store_lobby(d)
			_store_view(d)
		"error":
			last_error_code = str(d.get("code", ""))
			var bad_token: bool = str(d.get("code", "")) in ["bad_token", "not_found"]
			if bad_token and match_id != "":
				_forget() # la salle n'existe plus ou le jeton n'est plus valide : inutile de reessayer
			request_error.emit(str(d.get("message", "?")))
			_reply.emit("error", d)
		"closed":
			request_error.emit("le salon a ete ferme")
			_forget()
			_reply.emit("closed_room", d)

func _store_lobby(d: Dictionary) -> void:
	current_seats = d.get("seats", [])
	current_status = str(d.get("status", ""))
	current_num_players = int(d.get("numPlayers", 0))
	if d.has("host"): # le lobby donne le siege de l'hote (le "joined" donne un bool)
		current_host = int(d["host"])
		is_host = current_host == player_id
	lobby_changed.emit({"status": current_status, "seats": current_seats, "numPlayers": current_num_players, "host": current_host})

func _store_view(d: Dictionary) -> void:
	current_G = normalize_view(d.get("view", {}))
	if current_G.has("lastHeroFight"):
		var sig := str(current_G["lastHeroFight"]).hash()
		if sig == _last_fight:
			current_G.erase("lastHeroFight")
		else:
			_last_fight = sig
	var deadline := int(d.get("deadline", 0))
	if deadline > 0:
		current_G["turnDeadline"] = deadline
	current_ctx = {"serverTime": int(d.get("serverTime", 0)), "seat": int(d.get("seat", player_id))}
	if int(d.get("serverTime", 0)) > 0:
		clock_offset_ms = int(d["serverTime"]) - int(Time.get_unix_time_from_system() * 1000.0)
	current_awaited = d.get("awaited", [])
	current_moves = d.get("moves", [])
	if str(d.get("status", "")) == "finished":
		_count_result()
		_clear_session() # partie finie : plus rien a reprendre
	state_received.emit()

## Victoire / defaite du joueur local, une seule fois par salle (compteurs de Profile, montres dans la salle d'attente).
func _count_result() -> void:
	var over = current_G.get("gameOver")
	if not count_results or match_id == "" or match_id == _result_for or not (over is Dictionary):
		return
	_result_for = match_id
	Profile.record_result(int((over as Dictionary).get("winner", -1)) == player_id, match_id)

## La vue serveur est deja au format de Match.G (cles entieres restaurees par NetCodec) ; on ne garde que
## le contrat historique : gameOver = null tant que la partie court.
static func normalize_view(view) -> Dictionary:
	if not (view is Dictionary):
		return {}
	var g: Dictionary = (view as Dictionary).duplicate()
	if not g.has("gameOver"):
		g["gameOver"] = null
	return g

# --- API historique ---------------------------------------------------------

func start_lobby_poll() -> void:
	pass # le serveur pousse le lobby

func stop_lobby_poll() -> void:
	pass

func start_state_poll() -> void:
	pass

func stop_state_poll() -> void:
	pass

## Cree un salon (amis uniquement) et prend le siege 0. `bots` : sieges IA deja remplis.
func create_lobby(num_players: int, expansions: Array, bots: int = 0) -> bool:
	return await _enter({"t": "create", "name": player_name, "players": num_players, "sets": expansions, "bots": bots}.merged(_profile_fields()))

func join_lobby(code: String, pname: String) -> bool:
	player_name = pname
	return await _enter({"t": "join", "name": pname, "code": code.strip_edges().to_upper()}.merged(_profile_fields()))

func _profile_fields() -> Dictionary:
	return {"avatar": player_avatar, "wins": player_wins, "defeats": player_defeats}

func _enter(msg: Dictionary) -> bool:
	current_G = {}
	current_moves = []
	last_error_code = ""
	var r := await _call(msg, "joined")
	if r.is_empty():
		if match_id == "":
			_want_open = false
		return false
	_want_open = true
	return true

## Demande au serveur de renvoyer lobby / etat (le client est pousse, c'est un simple rafraichissement).
func fetch_lobby() -> void:
	if match_id != "":
		_send({"t": "sync"})

func fetch_state() -> void:
	fetch_lobby()

## L'hote lance la partie sans attendre les sieges vides (ils deviennent des IA).
func start_match() -> void:
	_send({"t": "start"})

func leave_match() -> void:
	_send({"t": "leave"})
	_forget()
	if _ws != null:
		_ws.close()

func send_move(move: Dictionary) -> void:
	if match_id == "":
		return
	if not _send({"t": "move", "move": move}):
		request_error.emit("connexion perdue")

func _forget() -> void:
	match_id = ""
	credentials = ""
	player_id = -1
	_want_open = false
	_clear_session()

# --- reprise apres rechargement ---------------------------------------------

func _save_session() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("session", "url", server_url())
	cfg.set_value("session", "code", match_id)
	cfg.set_value("session", "seat", player_id)
	cfg.set_value("session", "token", credentials)
	cfg.save(SESSION_PATH)

func _clear_session() -> void:
	if FileAccess.file_exists(SESSION_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SESSION_PATH))

func has_saved_session() -> bool:
	var cfg := ConfigFile.new()
	return cfg.load(SESSION_PATH) == OK and str(cfg.get_value("session", "token", "")) != ""

## Reprend la partie sauvegardee (rechargement de page, relance du jeu). Vrai si le siege est retrouve ;
## le serveur renvoie alors lobby / etat (signaux habituels).
func try_resume() -> bool:
	var cfg := ConfigFile.new()
	if cfg.load(SESSION_PATH) != OK:
		return false
	host = str(cfg.get_value("session", "url", host))
	var code := str(cfg.get_value("session", "code", ""))
	var seat := int(cfg.get_value("session", "seat", -1))
	var token := str(cfg.get_value("session", "token", ""))
	if code == "" or token == "":
		return false
	var r := await _call({"t": "resume", "code": code, "seat": seat, "token": token}, "joined")
	if r.is_empty():
		_forget()
		return false
	_want_open = true
	return true
