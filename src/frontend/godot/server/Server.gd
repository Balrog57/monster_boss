extends Node
## Server — serveur multijoueur Boss Monster (Godot headless). TCPServer + WebSocketPeer, messages JSON texte.
## Lancement : godot --headless --path src/frontend res://godot/server/Server.tscn -- --port=8091
## Options : --port --turn-timeout=70 --adventure-timeout=10 --bot-delay=350 --ttl=3600 --max-rooms=200 --seat-grace=30 --public-idle=120
## Protocole : voir PROTOCOL.md. Ce noeud route seulement ; la logique de partie est dans GameRoom.gd.

const GameRoom = preload("res://godot/server/GameRoom.gd")
const NetCodec = preload("res://godot/scripts/NetCodec.gd")
const MatchScript = preload("res://godot/scripts/Match.gd")

## Paquets acceptes dans create.sets (le jeu de base est toujours present, voir Match.new_match).
const KNOWN_SETS := ["players-choice", "hidden-heroes", "tools", "tools-wiki", "next-level", "minibosses", "crash-landing", "iod", "players-choice-wiki"]
## Code de salon : 4 lettres comme l'APK (OnlineService.GetNewRoomName, RndWord(4)) ; sans I ni O (confusion avec 1 et 0).
const CODE_ALPHABET := "ABCDEFGHJKLMNPQRSTUVWXYZ"
const CODE_LENGTH := 4
const MAX_MSGS_PER_SEC := 60
## Taille maximale d'une trame texte (un message client legitime fait quelques centaines d'octets). Au-dela : fermeture 1009.
## inbound_buffer_size (64 Kio) est un second filet : Godot coupe lui-meme en 1009 « Message too big » une trame qui ne tient pas.
const MAX_PACKET_BYTES := 16384
const INBOUND_BUFFER_BYTES := 1 << 16
## Anti-force-brute des codes de salon (24^4 = 331 776) : par CONNEXION, 5 echecs join/resume coupent la connexion (1008) ; le
## nombre de connexions neuves par IP est borne par nginx (limit_req). Le compteur global n'est plus qu'une soupape : il etait a 5/s
## et un seul client pouvait donc faire repondre `busy` a tout le monde (audit 3.0 §5.2). Godot ne donne pas l'IP reelle derriere
## nginx (get_connected_host = l'IP de nginx) : pas de compteur par IP cote serveur.
const MAX_FAILED_JOINS_PER_CONN := 5
const GLOBAL_FAILED_JOINS_PER_SEC := 100
## Liste publique : 50 salles au plus ; titre de salle comme les noms (25 caracteres).
const MAX_LISTED_ROOMS := 50
const TITLE_MAX := 25
## Connexion muette (les clients envoient ping toutes les 20 s). Large a dessein : un onglet en arriere-plan est suspendu par le
## navigateur et n'envoie plus rien ; couper trop vite le ferait passer pour deconnecte (le client rouvre de toute facon avec resume).
const IDLE_TIMEOUT_MS := 120000

var port := 8091
var auto_start := true # faux : un test pilote start() lui-meme
var turn_timeout_s := 70
var adventure_timeout_s := 10
var bot_delay_ms := 350
var room_ttl_s := 3600 # salle sans humain connecte, inactive depuis
var finished_ttl_s := 600
var max_rooms := 200
var max_conns := 512
var max_failed_joins_global_per_sec := GLOBAL_FAILED_JOINS_PER_SEC
var seat_grace_s := 30 # salle d'attente : siege non-hote sans connexion libere apres ce delai (un rechargement de page reprend avant)
var public_idle_s := 120 # salle publique ouverte sans aucun humain connecte depuis ce delai : fermee
var gc_interval_ms := 5000
var rooms_push_interval_ms := 250 # au plus un controle / push de la liste publique par intervalle

var _tcp := TCPServer.new()
var _conns := {} # id -> {ws, room, born, seen, window_start, window_count}
var _rooms := {} # code -> GameRoom
var _next_id := 1
var _gc_at := 0
var _fail_window_start := 0
var _fail_count := 0
var _rooms_push_at := 0
var _rooms_sig := ""

func _ready() -> void:
	if not auto_start:
		return
	for a in OS.get_cmdline_user_args():
		var kv := a.lstrip("-").split("=", true, 1)
		if kv.size() == 2 and kv[1].is_valid_int():
			match kv[0]:
				"port": port = int(kv[1])
				"turn-timeout": turn_timeout_s = int(kv[1])
				"adventure-timeout": adventure_timeout_s = int(kv[1])
				"bot-delay": bot_delay_ms = int(kv[1])
				"ttl": room_ttl_s = int(kv[1])
				"max-rooms": max_rooms = int(kv[1])
				"seat-grace": seat_grace_s = int(kv[1])
				"public-idle": public_idle_s = int(kv[1])
	Engine.max_fps = 60 # boucle headless : sinon l'image tourne a 100 % CPU
	if start(port) != OK:
		push_error("Server : impossible d'ecouter sur le port %d" % port)
		get_tree().quit(1)

func start(p_port: int) -> Error:
	port = p_port
	var err := _tcp.listen(port)
	if err == OK:
		print("SERVER listening on port %d" % port)
	return err

func stop() -> void:
	for id in _conns.keys():
		(_conns[id]["ws"] as WebSocketPeer).close(1001, "serveur arrete")
	_conns.clear()
	_tcp.stop()
	for r in _rooms.values():
		(r as GameRoom).dispose()
	_rooms.clear()

func _exit_tree() -> void:
	stop()

func room_count() -> int:
	return _rooms.size()

func get_room(code: String):
	return _rooms.get(code, null)

# --- boucle -------------------------------------------------------------------

func _process(_delta: float) -> void:
	if not _tcp.is_listening():
		return
	while _tcp.is_connection_available():
		var s := _tcp.take_connection()
		if _conns.size() >= max_conns:
			s.disconnect_from_host()
			continue
		var ws := WebSocketPeer.new()
		ws.outbound_buffer_size = 2 << 20 # un etat complet depasse les 64 Kio par defaut
		ws.inbound_buffer_size = INBOUND_BUFFER_BYTES
		ws.accept_stream(s)
		var now := Time.get_ticks_msec()
		_conns[_next_id] = {"ws": ws, "room": "", "born": now, "seen": now, "window_start": now, "window_count": 0}
		_next_id += 1
	var now := Time.get_ticks_msec()
	for id in _conns.keys():
		var c: Dictionary = _conns[id]
		var ws: WebSocketPeer = c["ws"]
		ws.poll()
		match ws.get_ready_state():
			WebSocketPeer.STATE_OPEN:
				if c.get("kill", false):
					ws.close(1008, "trop d'essais")
					continue
				while ws.get_available_packet_count() > 0 and not c.get("kill", false): # kill : on n'execute plus rien de ce qui suit
					var pkt := ws.get_packet()
					if not ws.was_string_packet():
						continue
					if pkt.size() > MAX_PACKET_BYTES:
						ws.close(1009, "message trop gros")
						break
					c["seen"] = now
					if now - int(c["window_start"]) > 1000:
						c["window_start"] = now
						c["window_count"] = 0
					c["window_count"] = int(c["window_count"]) + 1
					if int(c["window_count"]) > MAX_MSGS_PER_SEC:
						ws.close(1008, "trop de messages")
						break
					_on_message(id, NetCodec.parse_message(pkt.get_string_from_utf8()))
				if now - int(c["seen"]) > IDLE_TIMEOUT_MS:
					ws.close(1001, "inactif")
			WebSocketPeer.STATE_CLOSED:
				_drop(id)
	for code in _rooms.keys():
		var r: GameRoom = _rooms[code]
		if r.tick():
			r.broadcast()
	if now >= _gc_at:
		_gc_at = now + gc_interval_ms
		_collect_rooms()
	if now >= _rooms_push_at:
		_rooms_push_at = now + rooms_push_interval_ms
		_push_rooms()

func _drop(id: int) -> void:
	var c: Dictionary = _conns.get(id, {})
	_conns.erase(id)
	var r = _rooms.get(str(c.get("room", "")), null)
	if r != null:
		(r as GameRoom).detach(id)

## Salles sans humain depuis trop longtemps (en memoire uniquement, pas de base) ; sieges fantomes des salles d'attente.
func _collect_rooms() -> void:
	var now := int(Time.get_unix_time_from_system() * 1000.0)
	for code in _rooms.keys():
		var r: GameRoom = _rooms[code]
		var idle := now - r.last_activity_ms
		var gone: bool = r.humans_connected() == 0 and (idle > room_ttl_s * 1000 or not r.has_active_human())
		if r.status == "finished" and idle > finished_ttl_s * 1000:
			gone = true
		if r.public and r.status == "open" and r.empty_since_ms > 0 and r.humans_connected() == 0 and now - r.empty_since_ms > public_idle_s * 1000:
			gone = true
		if not gone:
			r.release_ghosts(seat_grace_s * 1000) # _dirty : le tick suivant diffuse le lobby aux sieges restants
		if gone:
			_close_room(code)

## `except` : connexion qui part d'elle-meme (l'hote qui quitte) : elle ne recoit pas `closed`.
func _close_room(code: String, except: int = -1) -> void:
	var r: GameRoom = _rooms.get(code)
	if r == null:
		return
	for s in r.seats:
		if int(s["conn"]) >= 0:
			if int(s["conn"]) != except:
				_send(int(s["conn"]), {"t": "closed", "code": code})
			if _conns.has(int(s["conn"])):
				_conns[int(s["conn"])]["room"] = ""
	r.dispose()
	_rooms.erase(code)

# --- liste publique -------------------------------------------------------------

## Salles publiques ouvertes avec au moins un siege libre (50 au plus). Rien de secret : ni jeton, ni connexion, ni detail de siege.
func public_rooms() -> Array:
	var out: Array = []
	for r in _rooms.values():
		if (r as GameRoom).public and r.status == "open":
			var e: Dictionary = r.list_entry()
			if int(e["free"]) > 0:
				out.append(e)
				if out.size() >= MAX_LISTED_ROOMS:
					break
	return out

## Pousse `rooms` aux connexions sans salle qui ont demande la liste, quand elle a change (regroupe creation, jonction, depart,
## demarrage, fermeture, liberation de siege fantome en un seul message par intervalle).
func _push_rooms() -> void:
	var list := public_rooms()
	var sig := JSON.stringify(list)
	if sig == _rooms_sig:
		return
	_rooms_sig = sig
	for id in _conns.keys():
		var c: Dictionary = _conns[id]
		if c.get("watch", false) and str(c["room"]) == "":
			_send(id, {"t": "rooms", "rooms": list})

# --- envoi --------------------------------------------------------------------

func _send(id: int, msg: Dictionary) -> void:
	var c: Dictionary = _conns.get(id, {})
	if c.is_empty():
		return
	var ws: WebSocketPeer = c["ws"]
	if ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
		ws.send_text(JSON.stringify(msg))

func _error(id: int, text: String, kind: String = "") -> void:
	_send(id, {"t": "error", "message": text, "code": kind})

# --- messages -----------------------------------------------------------------

static func _clean_name(v) -> String:
	var n := _sane_title(str(v)) # meme nettoyage que les titres (le nom apparait dans la liste publique et dans le titre par defaut) ; 25 caracteres comme l'APK (OnlinePanelEntity)
	return n if n != "" else "Joueur"

## Titre de salon public (affiche dans la liste de tout le monde) : texte seulement, 25 caracteres au plus. Les caracteres de controle,
## les formats invisibles (Cc, Cf, Zl, Zp : U+00AD, 061C, 200B-200F, 2028-202E, 2060-206F, FEFF...) sont retires : ils falsifieraient l'affichage.
## Renvoie "" si rien ne reste.
static func _sane_title(v) -> String:
	if not (v is String):
		return ""
	var t := ""
	for ch in (v as String):
		var cp := ch.unicode_at(0)
		if cp < 32 or (cp >= 127 and cp < 160) or cp == 0xAD or cp == 0x61C or (cp >= 0x200B and cp <= 0x200F) or (cp >= 0x2028 and cp <= 0x202E) or (cp >= 0x2060 and cp <= 0x206F) or cp == 0xFEFF:
			continue # shortcut: Cf rares (U+0600-0605, 06DD, 070F, 180E, E0001, E0020-E007F) non filtres, a ajouter si l'affichage les montre
		t += ch
	return t.strip_edges().left(TITLE_MAX).strip_edges()

## Titre de creation : defaut « <hote>'s game » si vide.
static func _clean_title(v, host_name: String) -> String:
	var t := _sane_title(v)
	return t if t != "" else ("%s's game" % host_name).left(TITLE_MAX)

## Avatar (nom de fichier sans chemin), victoires et defaites declares par le client : purement cosmetiques (salle d'attente).
static func _clean_profile(d: Dictionary) -> Dictionary:
	var av := str(d.get("avatar", ""))
	var ok := av.length() > 0 and av.length() <= 32
	for ch in av:
		if not (ch in "abcdefghijklmnopqrstuvwxyz_"):
			ok = false
	var w = d.get("wins", 0)
	var df = d.get("defeats", 0)
	return {"avatar": av if ok else "", "wins": clampi(int(w) if typeof(w) in [TYPE_INT, TYPE_FLOAT] else 0, 0, 99999), "defeats": clampi(int(df) if typeof(df) in [TYPE_INT, TYPE_FLOAT] else 0, 0, 99999)}

## Vrai si le serveur a deja eu un nombre anormal d'echecs join/resume dans la seconde en cours (soupape globale, voir les constantes).
func _join_throttled() -> bool:
	var now := Time.get_ticks_msec()
	if now - _fail_window_start > 1000:
		_fail_window_start = now
		_fail_count = 0
	return _fail_count >= max_failed_joins_global_per_sec

func _join_failed(id: int, text: String, kind: String, count_global := true) -> void:
	if count_global:
		_fail_count += 1
	_error(id, text, kind)
	var c: Dictionary = _conns[id]
	c["fails"] = int(c.get("fails", 0)) + 1
	if int(c["fails"]) >= MAX_FAILED_JOINS_PER_CONN:
		c["kill"] = true # coupee a l'image suivante : l'erreur doit partir avant la trame de fermeture

func _new_code() -> String:
	var bytes := Crypto.new().generate_random_bytes(CODE_LENGTH)
	var code := ""
	for b in bytes:
		code += CODE_ALPHABET[b % CODE_ALPHABET.length()]
	return code if not _rooms.has(code) else _new_code()

func _on_message(id: int, d: Dictionary) -> void:
	if d.is_empty():
		_error(id, "message invalide", "bad_message")
		return
	var c: Dictionary = _conns[id]
	var room: GameRoom = _rooms.get(str(c["room"]), null)
	match str(d.get("t", "")):
		"ping":
			_send(id, {"t": "pong"})
		"create":
			if room != null:
				return _error(id, "deja dans une salle", "busy")
			if _rooms.size() >= max_rooms:
				return _error(id, "serveur plein", "full")
			var sets: Array = []
			for s in (d.get("sets", []) if d.get("sets", []) is Array else []):
				if str(s) in KNOWN_SETS and not sets.has(str(s)):
					sets.append(str(s))
			var n := clampi(int(d.get("players", 2)), 2, 6)
			var setup_err := MatchScript.setup_error(n, sets) # 5-6 joueurs : Crash Landing obligatoire, paquets limites (sinon la salle serait plafonnee a 4)
			if setup_err != "":
				return _error(id, setup_err, "bad_setup")
			var r := GameRoom.new(_new_code(), n, sets)
			var host_name := _clean_name(d.get("name", ""))
			var pub = d.get("public", false)
			r.public = typeof(pub) == TYPE_BOOL and pub # strictement le booleen JSON : le texte « true » ne rend pas la salle publique
			r.title = _clean_title(d.get("title", ""), host_name)
			r.send = _send
			r.add_bots(clampi(int(d.get("bots", 0)), 0, n - 1))
			r.bot_delay_ms = bot_delay_ms
			var tt := int(d.get("turnTimeout", turn_timeout_s))
			r.turn_timeout_ms = clampi(tt, 0, 600) * 1000
			r.adventure_timeout_ms = adventure_timeout_s * 1000
			_rooms[r.code] = r
			_join(id, r, host_name, _clean_profile(d))
		"listRooms":
			if room == null:
				c["watch"] = true # recevra `rooms` a chaque changement tant qu'il n'est dans aucune salle
			_send(id, {"t": "rooms", "rooms": public_rooms()})
		"setTitle":
			if room == null or room.seat_of(id) != room.host:
				return _error(id, "reserve a l'hote", "forbidden")
			if room.status != "open":
				return _error(id, "la partie est lancee", "bad_state")
			var nt := _sane_title(d.get("title"))
			if nt == "":
				return _error(id, "titre invalide", "bad_message")
			room.title = nt
			_send(id, {"t": "titled", "title": nt})
			room.broadcast() # le `lobby` porte le titre ; la liste publique est repoussee au prochain intervalle (sa signature change)
		"join":
			if room != null:
				return _error(id, "deja dans une salle", "busy")
			if _join_throttled():
				return _join_failed(id, "trop d'essais, reessayez plus tard", "busy", false)
			var r: GameRoom = _rooms.get(str(d.get("code", "")).strip_edges().to_upper(), null)
			if r == null:
				return _join_failed(id, "salon introuvable", "not_found")
			if r.status != "open" or r.free_seat() < 0:
				return _error(id, "salon complet ou deja lance", "full")
			_join(id, r, _clean_name(d.get("name", "")), _clean_profile(d))
		"resume":
			if _join_throttled():
				return _join_failed(id, "trop d'essais, reessayez plus tard", "busy", false)
			var r: GameRoom = _rooms.get(str(d.get("code", "")).strip_edges().to_upper(), null)
			var seat := int(d.get("seat", -1))
			if room != null and room == r and room.seat_of(id) == seat:
				return _send(id, room.message_for(seat)) # reprise redondante (reconnexion automatique du client)
			if r == null or room != null:
				return _join_failed(id, "salon introuvable", "not_found")
			var old := int(r.seats[seat]["conn"]) if seat >= 0 and seat < r.num_players else -1
			if not r.resume(seat, str(d.get("token", "")), id):
				return _join_failed(id, "jeton invalide", "bad_token")
			if old >= 0 and old != id and _conns.has(old):
				_conns[old]["room"] = ""
				(_conns[old]["ws"] as WebSocketPeer).close(1000, "siege repris ailleurs")
			c["room"] = r.code
			c["watch"] = false
			_send(id, {"t": "joined", "code": r.code, "seat": seat, "token": d.get("token", ""), "host": seat == r.host})
			_send(id, r.message_for(seat))
			r.broadcast() # les autres voient le retour (connected)
		"start":
			if room == null or room.seat_of(id) != room.host:
				return _error(id, "reserve a l'hote", "forbidden")
			if not room.start():
				return _error(id, "impossible de lancer", "bad_state")
			room.broadcast()
		"move":
			if room == null or room.seat_of(id) < 0:
				return _error(id, "pas de siege", "no_seat")
			var mv = d.get("move", {})
			if not (mv is Dictionary):
				return _error(id, "coup invalide", "bad_move")
			var err := room.submit_move(room.seat_of(id), mv)
			if err != "":
				_error(id, err, "illegal")
				_send(id, room.message_for(room.seat_of(id))) # resynchronise le client
			else:
				room.broadcast()
		"sync":
			if room != null and room.seat_of(id) >= 0:
				_send(id, room.message_for(room.seat_of(id)))
		"leave":
			if room == null or room.seat_of(id) < 0:
				return
			var seat := room.seat_of(id)
			if room.status == "open" and seat == room.host:
				var nh := room.next_host(seat) # APK : le maitre de salle part, Photon en designe un autre (WaitingPrivateRoomScene.cs:41-47)
				if nh < 0:
					_close_room(room.code, id) # plus aucun autre humain connecte : la salle se ferme
					return
				room.host = nh
			c["room"] = ""
			room.leave(seat)
			room.broadcast()
			if not room.has_active_human():
				_close_room(room.code)
		_:
			_error(id, "message inconnu", "bad_message")

func _join(id: int, r: GameRoom, pname: String, prof: Dictionary) -> void:
	var j := r.join(pname, id, prof)
	if j.is_empty():
		_error(id, "salon complet", "full")
		return
	_conns[id]["room"] = r.code
	_conns[id]["watch"] = false # dans une salle : plus de push `rooms`
	_send(id, {"t": "joined", "code": r.code, "seat": j["seat"], "token": j["token"], "host": int(j["seat"]) == r.host})
	if r.free_seat() < 0 and r.status == "open":
		r.start()
	r.broadcast()
