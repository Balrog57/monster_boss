extends Node
## Test en ligne : serveur Godot dans le processus, deux OnlineClient reels (WebSocket sur localhost).
##  1. filtrage des vues (aucun id cache), sur des parties locales IA-vs-IA (base puis extensions TNL/CRL) ;
##  2. partie complete a 2 clients (chacun joue via AI.gd depuis SA vue) -> meme fin de partie ;
##     reconnexion avec jeton en cours de partie ;
##  3. rechargement de page (nouvelle instance + try_resume) ;
##  4. minuteur : l'IA prend le relais d'un humain muet, le joueur reprend la main a la reconnexion ;
##  5. onglet endormi : un grand trou entre deux images declenche un ping, une liaison muette est rouverte avec le jeton.
## Usage : godot --headless --path src/frontend res://godot/tests/OnlineTest.tscn   -> "ONLINE OK"

const Server = preload("res://godot/server/Server.gd")
const GameRoom = preload("res://godot/server/GameRoom.gd")
const ViewFilter = preload("res://godot/server/ViewFilter.gd")
const NetCodec = preload("res://godot/scripts/NetCodec.gd")
const OnlineClient = preload("res://godot/scripts/OnlineClient.gd")
const OnlineGameManager = preload("res://godot/scripts/OnlineGameManager.gd")
const GameManager = preload("res://godot/scripts/GameManager.gd")
const AI = preload("res://godot/scripts/AI.gd")

const GAME_TIMEOUT_S := 150.0

var server
var url := ""
var _fails: Array = []
var _priv_lines := 0 # lignes de journal privees verifiees
var _mb_tagged := 0 # minibosses face caches verifies

func _ready() -> void:
	_check_filter_unit()
	if _fails.is_empty():
		await _run_network()
	if _fails.is_empty():
		print("ONLINE OK")
		get_tree().quit(0)
	else:
		for f in _fails:
			print("ONLINE ECHEC : ", f)
		get_tree().quit(1)

func _expect(cond: bool, msg: String) -> bool:
	if not cond:
		_fails.append(msg)
	return cond

# --- 1. filtrage des vues -------------------------------------------------------

## Parties de filtrage : graines FIXES (deterministe), et on rejoue d'autres graines tant que la couverture exigee
## (assez de vues verifiees, ligne privee, miniboss face cache) n'est pas atteinte, avec un plafond. Avant : une seule partie
## aleatoire, donc un echec rare quand elle finissait trop tot ou quand le miniboss (pose une seule fois au pas 40) n'avait pas de salle.
const FILTER_MAX_GAMES := 8

func _check_filter_unit() -> void:
	_check_room_view()
	for sets in [["base"], ["next-level", "crash-landing", "players-choice", "hidden-heroes", "minibosses", "tools-wiki"]]:
		var checks := 0
		var priv_before := _priv_lines
		for g in FILTER_MAX_GAMES:
			checks += _filter_game(sets, 7000 + g)
			if not _fails.is_empty():
				return
			if checks > 10 and _priv_lines > priv_before and (not sets.has("minibosses") or _mb_tagged > 0):
				break
		_expect(checks > 10, "filtre : trop peu de verifications (%d)" % checks)
		_expect(_priv_lines > priv_before, "filtre : aucune ligne de journal privee rencontree (%s)" % str(sets))
	_expect(_mb_tagged > 0, "filtre : aucun miniboss face cachee rencontre")

## Une partie IA-vs-IA a 3 joueurs (graine `rng_seed`) ; renvoie le nombre de vues verifiees.
func _filter_game(sets: Array, rng_seed: int) -> int:
	seed(rng_seed) # randi() global (capacites de salle)
	CardDB._rng.seed = rng_seed # melanges des pioches
	var m = GameManager.new()
	add_child(m)
	m.rng.seed = rng_seed # Match._ready l'a randomise
	m.start_new_game(3, 0, sets)
	var steps := 0
	var checks := 0
	var mb_done := not sets.has("minibosses")
	var mb_pids := {}
	while m.G.get("gameOver") == null and steps < 4000 and _fails.is_empty():
		steps += 1
		if not mb_done and steps >= 40: # l'IA pose rarement un miniboss : on en pose un face cache chez chaque joueur (des qu'il a une salle)
			for pid in m.G["players"]:
				if mb_pids.has(pid):
					continue
				for stack in m.G["players"][pid]["dungeon"]:
					if not Minibosses.stack_has_mb(stack):
						Minibosses.attach(m.G, int(pid), BossEngine.active_room(stack), (CardDB.minibosses[0] as Dictionary).duplicate(true), true)
						mb_pids[pid] = true
						break
			mb_done = mb_pids.size() == m.G["players"].size()
		if steps % 25 == 1 or (checks < 400 and _has_facedown_mb(m.G)):
			_check_view(m.G, str(sets))
			checks += 1
		var pc: Dictionary = m.G.get("pendingChoice", {})
		var order: Array = [int(pc.get("playerId", 0))] if not pc.is_empty() else [m.active_player()]
		for pid in m.G["players"]:
			order.append(int(pid))
		var moved := false
		for pid in order:
			var mv = AI.pick_move(m, pid)
			if mv != null and m.apply_move(pid, mv):
				moved = true
				break
		if not moved:
			break
	m.queue_free()
	return checks

## Vue d'une salle adverse : dos seul si face cachee, miniboss face cache reduit a un marqueur, miniboss revele public.
func _check_room_view() -> void:
	var mb := {"card": {"id": "RMB055", "name": "Spike"}, "level": 1, "faceDown": true}
	var down: Dictionary = ViewFilter._room_view({"id": "X", "name": "Secret", "faceDown": true, "mb": mb})
	_expect(JSON.stringify(down) == JSON.stringify({"faceDown": true, "hidden": true, "mb": {"faceDown": true, "hidden": true}}), "salle face cachee + miniboss : %s" % JSON.stringify(down))
	var up: Dictionary = ViewFilter._room_view({"id": "X", "name": "Visible", "mb": mb})
	_expect(up["name"] == "Visible" and up["mb"] == {"faceDown": true, "hidden": true} and not JSON.stringify(up).contains("Spike"), "salle visible + miniboss face cache : %s" % JSON.stringify(up))
	var shown := {"card": {"id": "RMB055", "name": "Spike"}, "level": 2, "faceDown": false}
	var pub: Dictionary = ViewFilter._room_view({"id": "X", "mb": shown})
	_expect(pub["mb"] == shown, "miniboss revele : doit rester public")
	var plain := {"id": "Y", "name": "Plain"}
	_expect(ViewFilter._room_view(plain) == plain and not ViewFilter._room_view({"id": "Z", "faceDown": true}).has("mb"), "salle sans miniboss")

func _has_facedown_mb(G: Dictionary) -> bool:
	for pid in G["players"]:
		for stack in G["players"][pid].get("dungeon", []):
			for r in stack:
				if bool(((r as Dictionary).get("mb", {}) as Dictionary).get("faceDown", false)):
					return true
	return false

## Marque chaque carte cachee d'un jeton unique, filtre, et verifie que le jeton n'apparait que pour son proprietaire.
func _check_view(G: Dictionary, label: String) -> void:
	for k in G:
		_expect(ViewFilter.is_known_key(str(k)), "cle de G inconnue du filtre : '%s' (ViewFilter.PUBLIC_KEYS/FILTERED_KEYS)" % k)
	for pid in G["players"]:
		for k in G["players"][pid]:
			_expect(ViewFilter.is_known_player_key(str(k)), "cle de joueur inconnue du filtre : '%s' (ViewFilter.PLAYER_PUBLIC_KEYS/PLAYER_HIDDEN_KEYS)" % k)
	var g: Dictionary = G.duplicate(true)
	var tags: Array = [] # {tag, owner} ; owner -1 = jamais visible
	var tag := func(card, owner: int):
		if card is Dictionary:
			var t := "SECRET%d;" % tags.size()
			(card as Dictionary)["_secret"] = t
			tags.append({"tag": t, "owner": owner})
	for pid in g["players"]:
		var p: Dictionary = g["players"][pid]
		for c in p.get("hand", []):
			tag.call(c, int(pid))
		for stack in p.get("dungeon", []):
			for r in stack:
				if r is Dictionary and bool((r as Dictionary).get("faceDown", false)):
					tag.call(r, int(pid))
				# miniboss pose face cachee (sur une salle visible ou non) : seul son proprietaire en voit la carte
				var mb = (r as Dictionary).get("mb") if r is Dictionary else null
				if mb is Dictionary and bool((mb as Dictionary).get("faceDown", false)):
					tag.call((mb as Dictionary).get("card"), int(pid))
					_mb_tagged += 1
	for pile in ["rooms", "spells", "heroes", "epics", "items"]:
		for c in g["decks"].get(pile, []):
			tag.call(c, -1)
	var pc: Dictionary = g.get("pendingChoice", {})
	for o in pc.get("options", []):
		tag.call(o, int(pc.get("playerId", -1)))
	for q in ["choiceQueue", "revealQueue", "forcedBuilds"]:
		if g.get(q) is Array:
			for e in g[q]:
				tag.call(e, -1)
	for viewer in g["players"]:
		var view := ViewFilter.for_seat(g, int(viewer))
		var js := JSON.stringify(view)
		for t in tags:
			var seen: bool = js.contains(t["tag"])
			var should: bool = int(t["owner"]) == int(viewer)
			# Un choix en attente peut montrer a son proprietaire des cartes adverses (Cerebellus : sorts de la main adverse) : regle du jeu.
			if seen and not should and int(t["owner"]) >= 0 and int(pc.get("playerId", -1)) == int(viewer):
				continue
			if seen != should:
				var at := js.find(t["tag"])
				_expect(false, "[%s] fuite/perte : %s (proprietaire %d) %s pour le siege %d : %s" % [label, t["tag"], t["owner"], "visible" if seen else "absent", viewer, js.substr(maxi(0, at - 200), 300) if seen else ""])
				return
		# journaux : une ligne privee montre son texte complet aux seuls proprietaires, sa variante publique aux autres
		for lk in ["log", "logs"]:
			var src: Array = (g.get(lk, []) as Array).slice(-ViewFilter.LOG_TAIL)
			var shown: Array = view.get(lk, [])
			if not _expect(shown.size() == src.size(), "[%s] %s : taille %d au lieu de %d" % [label, lk, shown.size(), src.size()]):
				return
			for i in src.size():
				var e = src[i]
				if not (e is Dictionary):
					_expect(shown[i] is String and shown[i] == str(e), "[%s] %s : ligne publique alteree : %s" % [label, lk, shown[i]])
					continue
				_priv_lines += 1
				var mine: bool = int(viewer) in (e["owners"] as Array)
				_expect(e["pub"] != e["t"], "[%s] ligne privee sans variante publique distincte : %s" % [label, e["t"]])
				_expect(shown[i] is String and shown[i] == (e["t"] if mine else e["pub"]), "[%s] %s : le siege %d voit '%s' (prive : '%s')" % [label, lk, viewer, shown[i], e["t"]])
		# aller-retour JSON : ce que recoit le client == la vue
		var back = NetCodec.decode(JSON.parse_string(JSON.stringify(NetCodec.encode(view))))
		var want := JSON.stringify(NetCodec.encode(NetCodec.decode(view))) # normalise aussi les flottants entiers du JSON de donnees
		var got := JSON.stringify(NetCodec.encode(back))
		if want != got:
			var i := 0
			while i < mini(want.length(), got.length()) and want[i] == got[i]:
				i += 1
			_expect(false, "[%s] aller-retour JSON/NetCodec different : ...%s | ...%s" % [label, want.substr(maxi(0, i - 60), 120), got.substr(maxi(0, i - 60), 120)])
		_expect((back["players"] as Dictionary).has(int(viewer)), "[%s] players n'a pas de cles entieres" % label)

# --- 2..4. reseau -----------------------------------------------------------------

func _start_server() -> bool:
	server = Server.new()
	server.auto_start = false
	server.bot_delay_ms = 0
	add_child(server)
	var prng := RandomNumberGenerator.new() # le randi() global est seme par les parties de filtrage : le port doit rester aleatoire
	prng.randomize()
	for _i in 20:
		var port := prng.randi_range(20000, 40000)
		if server.start(port) == OK:
			url = "ws://127.0.0.1:%d" % port
			return true
	return false

func _client(pname: String) -> OnlineClient:
	var c := OnlineClient.new()
	c.host = url
	c.player_name = pname
	c.player_avatar = "avatar_croak"
	c.count_results = false # ne pas polluer les compteurs WINS / DEFEATS du vrai profil (user://profile.cfg)
	add_child(c)
	return c

func _wait(cond: Callable, timeout_s: float) -> bool:
	var t0 := Time.get_ticks_msec()
	while not cond.call():
		if (Time.get_ticks_msec() - t0) / 1000.0 > timeout_s:
			return false
		await get_tree().process_frame
	return true

## Un joueur automatique : joue via AI.gd a partir de SA vue, un coup en attente a la fois.
class Driver extends RefCounted:
	var client: OnlineClient
	var ogm
	var serial := 0
	var waiting := false
	var moves_sent := 0
	var paused := false
	var last: Array = []
	func _init(c: OnlineClient, g) -> void:
		client = c
		ogm = g
		client.state_received.connect(func(): serial += 1; waiting = false)
	func step() -> void:
		if paused or waiting or client.current_G.is_empty() or client.current_G.get("gameOver") != null:
			return
		if client.current_moves.is_empty():
			return
		var mv = AI.pick_move(ogm, client.player_id)
		if mv == null:
			mv = client.current_moves[0]
		waiting = true
		moves_sent += 1
		last.append(JSON.stringify(mv))
		if last.size() > 6:
			last.pop_front()
		client.send_move(mv)

func _run_network() -> void:
	if not _expect(_start_server(), "serveur : port indisponible"):
		return
	seed(4242) # melanges de la partie en ligne reproductibles (le temps reseau, lui, ne l'est pas)
	CardDB._rng.seed = 4242
	await _scenario_full_game()
	if _fails.is_empty():
		await _scenario_reload()
	if _fails.is_empty():
		await _scenario_timeout()
	if _fails.is_empty():
		await _scenario_sleep()
	if _fails.is_empty():
		await _scenario_bruteforce()
	if FileAccess.file_exists(OnlineClient.SESSION_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(OnlineClient.SESSION_PATH))
	server.stop()

func _scenario_full_game() -> void:
	var c0 := _client("Alice")
	var c1 := _client("Bob")
	var lobbies: Array = []
	c0.lobby_changed.connect(func(info): lobbies.append(info))
	if not _expect(await c0.create_lobby(2, ["players-choice"]), "create_lobby a echoue"):
		return
	var code := c0.match_id
	_expect(code.length() == 4 and code == code.to_upper() and code.to_upper().strip_edges().length() == 4 and not code.contains("I") and not code.contains("O") and code.unicode_at(0) >= 65 and code.unicode_at(0) <= 90, "code salon de 4 lettres majuscules : %s" % code)
	_expect(c0.player_id == 0, "l'hote prend le siege 0")
	# mauvais code puis bon code
	var errs: Array = []
	c1.request_error.connect(func(msg): errs.append(msg))
	_expect(not await c1.join_lobby("ZZZZ", "Bob"), "join d'un salon inconnu doit echouer")
	_expect(not errs.is_empty(), "erreur remontee par request_error")
	_expect(c1.last_error_code == "not_found", "code d'erreur not_found (boite « Invalid Code ») : %s" % c1.last_error_code)
	_expect(await c1.join_lobby(code, "Bob"), "join_lobby a echoue")
	_expect(c1.player_id == 1, "le 2e joueur prend le siege 1")
	if not _fails.is_empty():
		return
	if not _expect(await _wait(func(): return not c0.current_G.is_empty() and not c1.current_G.is_empty(), 10.0), "pas d'etat initial recu"):
		return
	_expect(lobbies.any(func(i): return str(i["status"]) == "open"), "lobby 'open' non diffuse a l'hote")
	# profil cosmetique (salle d'attente) : avatar du joueur dans les sieges, hote du lobby, sieges attendus + decalage d'horloge
	var open_lobby = lobbies.filter(func(i): return str(i["status"]) == "open").back()
	_expect(int(open_lobby.get("host", -1)) == 0, "le lobby donne le siege de l'hote")
	_expect(str((open_lobby["seats"][0] as Dictionary).get("avatar", "")) == "avatar_croak", "avatar absent des sieges du lobby : %s" % str(open_lobby["seats"]))
	_expect(c1.current_awaited is Array and c1.clock_offset_ms > -5000 and c1.clock_offset_ms < 5000, "awaited / decalage d'horloge : %s %d" % [str(c1.current_awaited), c1.clock_offset_ms])
	var g1: Dictionary = c1.current_G
	_expect((g1["players"] as Dictionary).has(1), "G.players a des cles entieres cote client")
	var opp_hand: Array = (g1["players"][0] as Dictionary).get("hand", [])
	_expect(opp_hand.all(func(c): return c.keys() == ["hidden"]), "main adverse non masquee")
	_expect((g1["decks"]["rooms"] as Array).all(func(c): return c.keys() == ["hidden"]), "pioche non masquee")

	var gm0 := OnlineGameManager.new()
	var gm1 := OnlineGameManager.new()
	add_child(gm0)
	add_child(gm1)
	gm0.setup_online(c0, 0)
	gm1.setup_online(c1, 1)
	var d0 := Driver.new(c0, gm0)
	var d1 := Driver.new(c1, gm1)
	var room = server.get_room(code)
	var t0 := Time.get_ticks_msec()
	var dropped := false
	var sampled := 0
	while room.status != "finished" and _fails.is_empty():
		if (Time.get_ticks_msec() - t0) / 1000.0 > GAME_TIMEOUT_S:
			_expect(false, "partie trop longue (phase %s tour %s, coups %d/%d) derniers coups d0=%s d1=%s ; actif=%s pc=%s ; log=%s" % [room.m.G.get("phase"), room.m.G.get("turn"), d0.moves_sent, d1.moves_sent, d0.last, d1.last, room.m.active_player(), room.m.G.get("pendingChoice", {}).get("type"), (room.m.G.get("log", []) as Array).slice(-4)])
			return
		d0.step()
		d1.step()
		# reconnexion avec jeton en pleine partie : on coupe la liaison du joueur 1
		if not dropped and d1.moves_sent >= 10:
			dropped = true
			d1.paused = true
			c1._ws.close()
			if not _expect(await _wait(func(): return not c1.connected, 5.0), "coupure non detectee"):
				return
			_expect(await _wait(func(): return room.seats[1]["conn"] == -1, 5.0), "serveur : siege 1 devrait etre detache")
			var serial := d1.serial
			if not _expect(await _wait(func(): return c1.connected and d1.serial > serial, 15.0), "reconnexion automatique avec jeton echouee"):
				return
			d1.paused = false
			d1.waiting = false
		# echantillonne l'etat serveur reel pour le filtrage (les parties locales ci-dessus couvrent le reste)
		if room.m != null and Engine.get_process_frames() % 40 == 0 and sampled < 40:
			_check_view(room.m.G, "serveur")
			sampled += 1
		await get_tree().process_frame
	_expect(dropped, "la reconnexion n'a pas ete exercee (partie trop courte)")
	if not _fails.is_empty():
		return
	# les deux clients doivent recevoir l'etat final
	_expect(await _wait(func(): return c0.current_G.get("gameOver") != null and c1.current_G.get("gameOver") != null, 10.0), "un client n'a pas recu la fin de partie")
	if not _fails.is_empty():
		return
	var go0: Dictionary = c0.current_G["gameOver"]
	var go1: Dictionary = c1.current_G["gameOver"]
	var gos: Dictionary = room.m.G["gameOver"]
	_expect(JSON.stringify(go0) == JSON.stringify(go1) and JSON.stringify(go0) == JSON.stringify(gos), "gameOver different entre clients/serveur")
	for pid in [0, 1]:
		for key in ["souls", "wounds"]:
			_expect(JSON.stringify(c0.current_G["players"][pid][key]) == JSON.stringify(c1.current_G["players"][pid][key]), "%s du siege %d different entre les deux clients" % [key, pid])
		_expect(JSON.stringify(c0.current_G["players"][pid]["boss"]) == JSON.stringify(c1.current_G["players"][pid]["boss"]), "boss du siege %d different" % pid)
	_expect(c0.current_G["turn"] == c1.current_G["turn"] and c0.current_G["turn"] == room.m.G["turn"], "numero de tour different")
	print("ONLINE game: tours=%d gameOver=%s coups=%d+%d" % [room.m.G["turn"], JSON.stringify(gos), d0.moves_sent, d1.moves_sent])
	# un coup illegal est refuse et n'altere pas la partie ; la partie finie n'accepte plus rien
	c0.send_move({"type": "pickBoss", "args": ["BMA001"]})
	await get_tree().create_timer(0.3).timeout
	_expect(JSON.stringify(room.m.G["gameOver"]) == JSON.stringify(gos), "etat modifie apres la fin")
	c0.queue_free()
	c1.queue_free()

func _scenario_reload() -> void:
	var a := _client("Alice")
	var b := _client("Bob")
	if not _expect(await a.create_lobby(2, []), "reload : create"):
		return
	var code := a.match_id
	_expect(await b.join_lobby(code, "Bob"), "reload : join")
	await _wait(func(): return not b.current_G.is_empty(), 5.0)
	var token := b.credentials
	b.free() # rechargement de page : l'ancien client disparait sans "leave"
	await _wait(func(): return server.get_room(code).seats[1]["conn"] == -1, 5.0)
	var b2 := _client("")
	if not _expect(b2.has_saved_session(), "session non sauvegardee"):
		return
	_expect(await b2.try_resume(), "try_resume a echoue")
	_expect(b2.match_id == code and b2.player_id == 1 and b2.credentials == token, "siege non retrouve apres rechargement")
	_expect(await _wait(func(): return not b2.current_G.is_empty(), 5.0), "pas d'etat apres reprise")
	# un faux jeton est refuse
	var evil := _client("Eve")
	var errs: Array = []
	evil.request_error.connect(func(msg): errs.append(msg))
	evil.match_id = ""
	var r: Dictionary = await evil._call({"t": "resume", "code": code, "seat": 0, "token": "00"}, "joined")
	_expect(r.is_empty() and not errs.is_empty(), "un jeton invalide doit etre refuse")
	_expect(int(server.get_room(code).seats[0]["conn"]) >= 0 and int(server.get_room(code).seats[1]["conn"]) >= 0, "les deux sieges restent connectes")
	a.queue_free()
	b2.queue_free()
	evil.queue_free()

## Anti-force-brute : au-dela de 5 echecs join/resume par seconde (serveur) -> `busy` ; 5 echecs sur une connexion -> coupee ;
## puis un bon join passe (fenetre de 1 s ecoulee), meme avec des wins/defeats de mauvais type (ignores -> 0).
func _scenario_bruteforce() -> void:
	var host := _client("Hote")
	if not _expect(await host.create_lobby(3, []), "bruteforce : create"):
		return
	await get_tree().create_timer(1.1).timeout # fenetre propre
	var a := _client("Brute")
	for i in 5:
		_expect(not await a.join_lobby("QQQQ", "Brute") and a.last_error_code == "not_found", "bruteforce : essai %d -> %s" % [i, a.last_error_code])
	_expect(await _wait(func(): return not a.connected, 3.0), "bruteforce : 5 echecs doivent couper la connexion")
	var b := _client("Joueur")
	_expect(not await b.join_lobby("QQQQ", "Joueur") and b.last_error_code == "busy", "bruteforce : au-dela de la limite serveur -> busy (%s)" % b.last_error_code)
	b.match_id = ""
	await get_tree().create_timer(1.1).timeout
	var r: Dictionary = await b._call({"t": "join", "name": "Joueur", "code": host.match_id, "wins": [1], "defeats": {"x": 1}}, "joined")
	if _expect(not r.is_empty(), "bruteforce : un bon join doit passer une fois la fenetre ecoulee"):
		var seat: Dictionary = server.get_room(host.match_id).seats[int(r["seat"])]
		_expect(int(seat["wins"]) == 0 and int(seat["defeats"]) == 0, "wins/defeats de mauvais type -> 0 : %s" % str(seat))
	host.queue_free()
	a.queue_free()
	b.queue_free()

func _scenario_timeout() -> void:
	var c := _client("Seul")
	if not _expect(await c.create_lobby(2, [], 1), "timeout : create (1 IA)"):
		return
	var code := c.match_id
	# turnTimeout est une option de create ; on la fixe sur la salle deja creee (cote serveur) pour le test
	var room = server.get_room(code)
	room.turn_timeout_ms = 1000
	room.adventure_timeout_ms = 1000
	room.bot_delay_ms = 150 # l'IA joue lentement : on a le temps de lire le journal avant qu'il defile
	if not _expect(await _wait(func(): return not c.current_G.is_empty(), 5.0), "timeout : pas d'etat"):
		return
	room._reset_deadline()
	_expect(int(c.current_G.get("turnDeadline", 0)) > 0 or room.deadline_ms > 0, "un delai doit courir pour l'humain")
	# l'humain ne fait rien : l'IA prend le relais (choix du boss)
	_expect(await _wait(func(): return bool(room.seats[0]["auto"]), 6.0), "l'IA n'a pas pris le relais apres le delai")
	_expect(await _wait(func(): return c.current_G.get("players", {}).get(0, {}).get("boss") != null, 6.0), "le boss n'a pas ete choisi par l'IA")
	_expect(str(c.current_G.get("log", [])).contains("prend le relais"), "journal : prise de relais non annoncee : %s" % str(c.current_G.get("log", [])).right(300))
	# reconnexion : le joueur reprend son siege
	c._ws.close()
	await _wait(func(): return not c.connected, 5.0)
	var serial: int = int(c.current_ctx.get("serverTime", 0))
	_expect(await _wait(func(): return c.connected and int(c.current_ctx.get("serverTime", 0)) != serial and not bool(room.seats[0]["auto"]), 10.0), "le siege n'a pas ete rendu a la reconnexion")
	c.queue_free()

func _scenario_sleep() -> void:
	var c := _client("Dormeur")
	if not _expect(await c.create_lobby(2, [], 1), "sommeil : create"):
		return
	_expect(await _wait(func(): return not c.current_G.is_empty(), 5.0), "sommeil : pas d'etat")
	# onglet reveille apres un long trou : ping immediat, la reponse du serveur remet le compteur a zero
	c._process(30.0)
	_expect(c._pong_wait > 0.0, "sommeil : aucun ping apres un long trou")
	_expect(await _wait(func(): return c._pong_wait == 0.0, 5.0) and c.connected, "sommeil : pong non recu")
	# liaison morte en silence (le serveur l'a coupee pendant le sommeil) : plus de paquet apres le ping -> fermeture puis resume
	c._pong_wait = c.PONG_TIMEOUT_S - 0.05
	var serial := int(c.current_ctx.get("serverTime", 0))
	_expect(await _wait(func(): return not c.connected, 5.0), "sommeil : liaison muette non detectee")
	_expect(await _wait(func(): return c.connected and int(c.current_ctx.get("serverTime", 0)) != serial, 10.0), "sommeil : pas de reconnexion avec jeton")
	c.queue_free()
