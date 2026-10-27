extends Node
## Test en ligne : serveur Godot dans le processus, deux OnlineClient reels (WebSocket sur localhost).
##  1. filtrage des vues (aucun id cache), sur des parties locales IA-vs-IA (base puis extensions TNL/CRL) ;
##  2. partie complete a 2 clients (chacun joue via AI.gd depuis SA vue) -> meme fin de partie ;
##     reconnexion avec jeton en cours de partie ;
##  3. rechargement de page (nouvelle instance + try_resume) ;
##  4. minuteur : l'IA prend le relais d'un humain muet, le joueur reprend la main a la reconnexion ;
##  6. 5 et 6 joueurs (Crash Landing) : refus sans CRL / avec un paquet non pris en charge (`bad_setup`), filtrage des vues a 5-6 sieges,
##     partie complete (1 humain + IA) jusqu'a la fin, sur le nombre de sieges demande.
##  5. onglet endormi : un grand trou entre deux images declenche un ping, une liaison muette est rouverte avec le jeton.
##  7. anti-force-brute par connexion (un joueur innocent n'est pas bloque), rafale coupee a 5 reponses, soupape globale ;
##  8. lobby public (lot 3.1) : listRooms / push `rooms`, salon prive jamais liste, 50 entrees au plus, sortie de liste quand plein / demarre ;
##  9. sieges fantomes liberes apres la grace (rechargement dans la grace = siege repris, hote jamais libere), salle publique vide fermee ;
## 10. taille maximale de message (1009) et debit par connexion (1008) ;
## 11. lot 3.2 : API client du lobby public (watch_rooms / rooms_received / create_lobby public / join_lobby / reconnexion qui redemande la liste) ;
## 12. lot 3.3 (audit 3.0 §4.3, test INVERSE) : deux connexions sur le meme jeton -> la plus ancienne est evincee et NE se reconnecte PAS (plus de boucle).
## 13. lot 3.5 : titre de salon modifiable par l'hote (`setTitle`, nettoyage serveur), filtre de la liste publique, plafond de connexions du serveur.
## Usage : godot --headless --path src/frontend res://godot/tests/OnlineTest.tscn   -> "ONLINE OK"

const Server = preload("res://godot/server/Server.gd")
const GameRoom = preload("res://godot/server/GameRoom.gd")
const ViewFilter = preload("res://godot/server/ViewFilter.gd")
const NetCodec = preload("res://godot/scripts/NetCodec.gd")
const OnlineClient = preload("res://godot/scripts/OnlineClient.gd")
const OnlineGameManager = preload("res://godot/scripts/OnlineGameManager.gd")
const GameManager = preload("res://godot/scripts/GameManager.gd")
const AI = preload("res://godot/scripts/AI.gd")
const OnlineMenus = preload("res://godot/scripts/OnlineMenus.gd")
const Profile = preload("res://godot/scripts/Profile.gd")

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
	_check_stack_and_boss_picks()
	_check_g_keys_classified()
	_check_apk_skipped_hero_view()
	for sets in [["base"], ["next-level", "crash-landing", "players-choice", "hidden-heroes", "minibosses", "tools-wiki", "iod", "players-choice-wiki", "classic-wiki", "choose-wiki", "machinations-wiki", "unlimited-wiki"]]:
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
	for n in [5, 6]: # 5-6 joueurs (Crash Landing) : memes verifications de fuite sur 5 / 6 sieges
		var big_checks: int = _filter_game(["crash-landing"], 7100 + n, n)
		_expect(big_checks > 10, "filtre %d joueurs : trop peu de verifications (%d)" % [n, big_checks])

## Toute cle de G doit etre classee par ViewFilter (liste blanche : une cle inconnue est jetee en ligne, cf. apkSkippedHero). Union de
## (a) les cles du G initial de vraies parties (base, puis tous les paquets) et (b) les ecritures statiques `G["cle"] =` des scripts du moteur et du serveur
## (affectation de premier niveau seulement : `G["a"]["b"] =` et `G["a"] ==` ne sont pas capturees).
func _check_g_keys_classified() -> void:
	var keys := {}
	for sets in [["base"], ["next-level", "crash-landing", "players-choice", "hidden-heroes", "minibosses", "tools-wiki", "iod", "players-choice-wiki", "classic-wiki", "choose-wiki", "machinations-wiki", "unlimited-wiki"]]:
		var m = GameManager.new()
		add_child(m)
		m.start_new_game(3, 0, sets)
		for k in m.G:
			keys[str(k)] = "G initial " + str(sets)
		m.queue_free()
	var re := RegEx.create_from_string(r"\bG\[\"([A-Za-z_0-9]+)\"\]\s*(?:[-+*|]?=)(?!=)")
	var n_files := 0
	for dir in ["res://godot/scripts/", "res://godot/server/"]:
		for f in DirAccess.get_files_at(dir):
			if f.get_extension() != "gd":
				continue
			n_files += 1
			var src := FileAccess.get_file_as_string(dir + f)
			for r in re.search_all(src):
				if not keys.has(r.get_string(1)):
					keys[r.get_string(1)] = dir + f
	_expect(n_files > 20 and keys.size() > 30, "cles de G : balayage trop maigre (%d fichiers, %d cles)" % [n_files, keys.size()])
	var missing: Array = []
	for k in keys:
		if not ViewFilter.is_known_key(k):
			missing.append("%s (%s)" % [k, keys[k]])
	_expect(missing.is_empty(), "cles de G non classees dans ViewFilter (PUBLIC_KEYS / FILTERED_KEYS / DROPPED_KEYS) : %s" % ", ".join(missing))

## Regression : apkSkippedHero (Trepidation) doit survivre a la vue d'un siege, sinon Match.apk_active_hero() grise tout cote client en ligne.
func _check_apk_skipped_hero_view() -> void:
	var g := {"players": {0: {"id": 0}, 1: {"id": 1}}, "apkSkippedHero": 1, "phase": "build"}
	for seat in [0, 1]:
		var v := ViewFilter.for_seat(g, seat)
		_expect(v.has("apkSkippedHero") and int(v["apkSkippedHero"]) == 1, "apkSkippedHero perdu dans la vue du siege %d : %s" % [seat, str(v.get("apkSkippedHero"))])

## Une partie IA-vs-IA a 3 joueurs (graine `rng_seed`) ; renvoie le nombre de vues verifiees.
func _filter_game(sets: Array, rng_seed: int, players: int = 3) -> int:
	seed(rng_seed) # randi() global (capacites de salle)
	CardDB._rng.seed = rng_seed # melanges des pioches
	var m = GameManager.new()
	add_child(m)
	m.rng.seed = rng_seed # Match._ready l'a randomise
	m.start_new_game(players, 0, sets)
	var steps := 0
	var checks := 0
	var mb_done := not sets.has("minibosses")
	var mb_pids := {}
	while m.G.get("gameOver") == null and steps < 4000 * (3 if players >= 5 else 1) and _fails.is_empty():
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

## N-A69 : `stack` et `bossPicks` ne laissent fuir aucune carte cachee. Les sorts et capacites en pile sont publics (un sort est montre des qu'il est pose, APK
## comme Godot) ; seuls les `picks` d'une capacite en file (cartes de la main comprises) restent a l'activateur. Le pool de bosses est le meme pour tous les sieges
## pendant la phase `boss` (l'APK montre tous les bosses dans le carrousel) puis il est vide : les bosses non pris ne se devinent pas.
func _check_stack_and_boss_picks() -> void:
	var spell := {"id": "BMA001", "name": "Public spell", "isSpell": true}
	var g := {"phase": "boss", "numPlayers": 2, "bossPicks": [{"id": "BOSS1", "name": "Un"}, {"id": "BOSS2", "name": "Deux"}],
		"players": {0: {"id": 0, "hand": [{"id": "H0", "_secret": "SECRET0;"}], "dungeon": []}, 1: {"id": 1, "hand": [{"id": "H1", "_secret": "SECRET1;"}], "dungeon": []}},
		"stack": [{"id": "spell-1", "type": "spell", "playerId": 0, "card": spell, "target": {"roomIndex": 0}, "resolved": false},
			{"id": "ability-R-1", "type": "ability", "playerId": 0, "card": {"id": "R"}, "target": {"roomIndex": 1}, "picks": ["hand:SECRET0;"], "resolved": false}]}
	var v0 := ViewFilter.for_seat(g, 0)
	var v1 := ViewFilter.for_seat(g, 1)
	_expect(JSON.stringify(v0["stack"]) == JSON.stringify(g["stack"]), "stack : l'activateur doit voir sa pile telle quelle")
	_expect(not JSON.stringify(v1).contains("SECRET0;") and not JSON.stringify(v1["stack"]).contains("picks"), "stack : les cibles memorisees de l'activateur ne doivent pas fuir")
	_expect(v1["stack"][0] == g["stack"][0] and v1["stack"][1]["card"] == g["stack"][1]["card"] and v1["stack"][1]["target"] == g["stack"][1]["target"], "stack : sort, carte de la capacite et salle visee restent publics")
	_expect(JSON.stringify(v0["bossPicks"]) == JSON.stringify(g["bossPicks"]) and JSON.stringify(v1["bossPicks"]) == JSON.stringify(g["bossPicks"]), "bossPicks : meme pool pour tous les sieges en phase boss")
	g["phase"] = "build"
	_expect((ViewFilter.for_seat(g, 0)["bossPicks"] as Array).is_empty() and (ViewFilter.for_seat(g, 1)["bossPicks"] as Array).is_empty(), "bossPicks : vide des que la phase boss est finie")

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
		# N-A69 : pile et pool de bosses (voir _check_stack_and_boss_picks)
		for e in view.get("stack", []):
			var had_picks: bool = (g["stack"] as Array).any(func(s): return (s as Dictionary).get("id") == (e as Dictionary).get("id") and (s as Dictionary).has("picks"))
			_expect((e as Dictionary).has("picks") == (had_picks and int((e as Dictionary).get("playerId", -1)) == int(viewer)), "[%s] stack : `picks` visibles par un autre siege (%d) : %s" % [label, viewer, JSON.stringify(e)])
		_expect(JSON.stringify(view.get("bossPicks", [])) == JSON.stringify(g.get("bossPicks", []) if str(g.get("phase", "")) == "boss" else []), "[%s] bossPicks : vue differente du pool (phase boss) ou non vide ensuite" % label)

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
	for n in [5, 6]:
		if _fails.is_empty():
			await _scenario_big_game(n)
	if _fails.is_empty():
		await _scenario_reload()
	if _fails.is_empty():
		await _scenario_timeout()
	if _fails.is_empty():
		await _scenario_deadline_window()
	if _fails.is_empty():
		await _scenario_leave_and_lost()
	if _fails.is_empty():
		_scenario_profile_counts()
	if _fails.is_empty():
		await _scenario_sleep()
	if _fails.is_empty():
		await _scenario_bruteforce()
	if _fails.is_empty():
		await _scenario_lobby()
	if _fails.is_empty():
		await _scenario_ghosts()
	if _fails.is_empty():
		await _scenario_limits()
	if _fails.is_empty():
		await _scenario_conn_cap()
	if _fails.is_empty():
		await _scenario_title()
		await _scenario_host_public()
	if _fails.is_empty():
		await _scenario_public_client()
	if _fails.is_empty():
		await _scenario_eviction()
	if _fails.is_empty():
		await _scenario_adventure_expiry()
		_scenario_plays()
		await _scenario_player_left()
	if _fails.is_empty():
		await _scenario_version()
	if _fails.is_empty():
		await _scenario_away()
	if _fails.is_empty():
		await _scenario_abandon()
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
	_expect(code.length() == 4 and code == code.to_lower() and code.strip_edges().length() == 4 and not code.contains("0"), "code salon de 4 caracteres minuscules a-z 1-9 : %s" % code)
	_expect(c0.player_id == 0, "l'hote prend le siege 0")
	# mauvais code puis bon code
	var errs: Array = []
	c1.request_error.connect(func(msg): errs.append(msg))
	_expect(not await c1.join_lobby("ZZZZ", "Bob"), "join d'un salon inconnu doit echouer")
	_expect(not errs.is_empty(), "erreur remontee par request_error")
	_expect(c1.last_error_code == "not_found", "code d'erreur not_found (boite « Invalid Code ») : %s" % c1.last_error_code)
	_expect(await c1.join_lobby(code, "Bob"), "join_lobby a echoue")
	_expect(c1.player_id == 1, "le 2e joueur prend le siege 1")
	c0.start_match() # salle pleine : l'hote lance (WaitingPrivateRoomScene), plus de demarrage automatique
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

## 5-6 joueurs : le serveur refuse sans Crash Landing (ou avec un paquet non pris en charge) au lieu de plafonner a 4 ; avec CRL, une salle de n sieges
## (n - 1 IA) joue une partie complete et Match.new_match cree bien n joueurs.
func _scenario_big_game(n: int) -> void:
	var bad := _client("Refus")
	for sets in [[], ["tools"], ["crash-landing", "next-level"], ["crash-landing", "minibosses"], ["crash-landing", "players-choice"]]:
		_expect(not await bad.create_lobby(n, sets, 1) and bad.last_error_code == "bad_setup", "%d joueurs %s : refus attendu (bad_setup), obtenu '%s'" % [n, str(sets), bad.last_error_code])
	bad.queue_free()
	if not _fails.is_empty():
		return
	var c0 := _client("Alice")
	if not _expect(await c0.create_lobby(n, ["crash-landing"], n - 1), "%d joueurs : create_lobby a echoue (%s)" % [n, c0.last_error_code]):
		return
	var room = server.get_room(c0.match_id)
	_expect(room.num_players == n and room.seats.size() == n, "%d joueurs : %d sieges attendus, obtenu %d" % [n, n, room.seats.size()])
	c0.start_match() # l'hote lance : plus de demarrage automatique a la salle pleine
	if not _expect(await _wait(func(): return not c0.current_G.is_empty() and room.m != null, 10.0), "%d joueurs : la partie n'a pas demarre" % n):
		return
	_expect(int(room.m.G["numPlayers"]) == n and (room.m.G["players"] as Dictionary).size() == n, "%d joueurs : Match a %d joueurs" % [n, (room.m.G["players"] as Dictionary).size()])
	_expect((c0.current_G["players"] as Dictionary).size() == n, "%d joueurs : la vue du client a %d joueurs" % [n, (c0.current_G["players"] as Dictionary).size()])
	var gm0 := OnlineGameManager.new()
	add_child(gm0)
	gm0.setup_online(c0, 0)
	var d0 := Driver.new(c0, gm0)
	var t0 := Time.get_ticks_msec()
	var sampled := 0
	while room.status != "finished" and _fails.is_empty():
		if (Time.get_ticks_msec() - t0) / 1000.0 > GAME_TIMEOUT_S:
			_expect(false, "%d joueurs : partie trop longue (phase %s tour %s, coups %d, actif=%s)" % [n, room.m.G.get("phase"), room.m.G.get("turn"), d0.moves_sent, room.m.active_player()])
			break
		d0.step()
		if room.m != null and Engine.get_process_frames() % 40 == 0 and sampled < 20:
			_check_view(room.m.G, "serveur %d joueurs" % n)
			sampled += 1
		await get_tree().process_frame
	if _fails.is_empty():
		_expect(await _wait(func(): return c0.current_G.get("gameOver") != null, 10.0), "%d joueurs : le client n'a pas recu la fin de partie" % n)
		_expect(JSON.stringify(c0.current_G.get("gameOver")) == JSON.stringify(room.m.G["gameOver"]), "%d joueurs : gameOver different entre client et serveur" % n)
		for pid in room.m.G["players"]:
			_expect(not bool((room.m.G["players"][pid] as Dictionary).get("eliminated", false)), "%d joueurs : le siege %d ne devrait jamais etre elimine" % [n, pid])
		print("ONLINE %d joueurs: tours=%d gameOver=%s coups=%d" % [n, room.m.G["turn"], JSON.stringify(room.m.G["gameOver"]), d0.moves_sent])
	c0.queue_free()

func _scenario_reload() -> void:
	var a := _client("Alice")
	var b := _client("Bob")
	if not _expect(await a.create_lobby(2, []), "reload : create"):
		return
	var code := a.match_id
	_expect(await b.join_lobby(code, "Bob"), "reload : join")
	a.start_match()
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

## Anti-force-brute PAR CONNEXION (lot 3.1). Avant : un compteur global de 5 echecs/s faisait repondre `busy` a tout le monde, y compris
## a un joueur innocent (audit 3.0 §5.2-1 ; l'ancienne version de ce test attendait d'ailleurs ce `busy` pour le client suivant).
func _scenario_bruteforce() -> void:
	var host := _client("Hote")
	if not _expect(await host.create_lobby(4, []), "bruteforce : create"):
		return
	var a := _client("Brute")
	for i in 5:
		_expect(not await a.join_lobby("QQQQ", "Brute") and a.last_error_code == "not_found", "bruteforce : essai %d -> %s" % [i, a.last_error_code])
	_expect(await _wait(func(): return not a.connected, 3.0), "bruteforce : 5 echecs doivent couper la connexion")
	# un joueur innocent, dans la meme seconde, n'est PAS bloque par les echecs d'un autre ; wins/defeats de mauvais type -> 0
	var b := _client("Joueur")
	var r: Dictionary = await b._call({"t": "join", "name": "Joueur", "code": host.match_id, "wins": [1], "defeats": {"x": 1}}, "joined")
	if _expect(not r.is_empty(), "bruteforce : un joueur innocent doit pouvoir rejoindre juste apres les echecs d'un autre (%s)" % b.last_error_code):
		var seat: Dictionary = server.get_room(host.match_id).seats[int(r["seat"])]
		_expect(int(seat["wins"]) == 0 and int(seat["defeats"]) == 0, "wins/defeats de mauvais type -> 0 : %s" % str(seat))
	# rafale : 30 join rates dans une seule image -> exactement 5 reponses `not_found`, puis fermeture 1008 (avant : jusqu'a 60/s traites)
	var burst := await _raw()
	for i in 30:
		burst.send({"t": "join", "code": "QQQQ", "name": "Rafale"})
	_expect(await _wait(func(): return burst.closed, 3.0), "bruteforce : rafale non coupee")
	_expect(burst.close_code == 1008, "bruteforce : rafale coupee en %d au lieu de 1008" % burst.close_code)
	_expect(burst.count("error") == 5, "bruteforce : %d reponses a la rafale (5 attendues)" % burst.count("error"))
	# soupape globale (reglee a 8/s ici) : 2 connexions font 10 echecs, puis un join valide dans la meme seconde -> `busy` ; la fenetre passee, ca joue
	server.max_failed_joins_global_per_sec = 8
	var x1 := await _raw()
	var x2 := await _raw()
	var x3 := await _raw()
	for i in 5:
		x1.send({"t": "join", "code": "QQQQ", "name": "X1"})
		x2.send({"t": "join", "code": "QQQQ", "name": "X2"})
	_expect(await _wait(func(): return x1.closed and x2.closed, 3.0), "soupape : x1 / x2 non coupes")
	x3.send({"t": "join", "code": host.match_id, "name": "X3"}) # < 1 s apres les echecs : meme fenetre
	_expect(await _wait(func(): return x3.count("error") > 0, 3.0), "soupape : pas de reponse")
	_expect(x3.last("error").get("code", "") == "busy", "soupape globale : busy attendu, obtenu %s" % str(x3.last("error")))
	await get_tree().create_timer(1.1).timeout
	x3.send({"t": "join", "code": host.match_id, "name": "X3"})
	_expect(await _wait(func(): return x3.count("joined") > 0, 3.0), "soupape : le join valide doit passer une fois la fenetre ecoulee")
	server.max_failed_joins_global_per_sec = Server.GLOBAL_FAILED_JOINS_PER_SEC
	for n in [burst, x1, x2, x3]:
		n.queue_free()
	host.queue_free()
	a.queue_free()
	b.queue_free()

# --- lot 3.1 : lobby public, nettoyage, limites ----------------------------------------

## Connexion WebSocket brute (message par message, sans la logique du client de jeu) : garde tout ce qui arrive.
class Raw extends Node:
	var ws := WebSocketPeer.new()
	var msgs: Array = []
	var closed := false
	var close_code := -1
	func open(url: String) -> void:
		ws.outbound_buffer_size = 1 << 20
		ws.inbound_buffer_size = 1 << 20
		ws.connect_to_url(url)
	func _process(_d: float) -> void:
		ws.poll()
		_drain()
		if ws.get_ready_state() == WebSocketPeer.STATE_CLOSED and not closed:
			_drain()
			closed = true
			close_code = ws.get_close_code()
	func _drain() -> void:
		while ws.get_available_packet_count() > 0:
			var d = JSON.parse_string(ws.get_packet().get_string_from_utf8())
			if d is Dictionary:
				msgs.append(d)
	func is_open() -> bool:
		return ws.get_ready_state() == WebSocketPeer.STATE_OPEN
	func send(d: Dictionary) -> void:
		if str(d.get("t", "")) in ["create", "join", "resume", "listRooms"] and not d.has("v"):
			d["v"] = NetCodec.PROTOCOL_VERSION # le serveur refuse ces messages sans version (N-A46) ; un test de version passe sa propre cle `v`
		ws.send_text(JSON.stringify(d))
	func count(t: String) -> int:
		return msgs.filter(func(m): return m.get("t", "") == t).size()
	func last(t: String) -> Dictionary:
		for i in range(msgs.size() - 1, -1, -1):
			if msgs[i].get("t", "") == t:
				return msgs[i]
		return {}

func _raw() -> Raw:
	var r := Raw.new()
	add_child(r)
	r.open(url)
	await _wait(func(): return r.is_open(), 5.0)
	return r

## Entree de la derniere liste `rooms` recue par `r` pour ce code ({} si absente).
func _listed(r: Raw, code: String) -> Dictionary:
	for e in r.last("rooms").get("rooms", []):
		if str(e.get("code", "")) == code:
			return e
	return {}

func _in_any_rooms_msg(r: Raw, code: String) -> bool:
	for m in r.msgs:
		if m.get("t", "") == "rooms" and JSON.stringify(m).contains(code):
			return true
	return false

func _create_raw(msg: Dictionary) -> Raw:
	var r := await _raw()
	msg["t"] = "create"
	r.send(msg)
	await _wait(func(): return r.count("joined") > 0 or r.count("error") > 0, 5.0)
	return r

func _scenario_lobby() -> void:
	server.rooms_push_interval_ms = 50
	var by := await _raw() # n'a jamais demande la liste : ne doit jamais recevoir `rooms`
	var watcher := await _raw()
	watcher.send({"t": "listRooms"})
	_expect(await _wait(func(): return watcher.count("rooms") > 0, 5.0), "lobby : pas de reponse a listRooms")
	var host := await _create_raw({"name": "Alice", "players": 3, "sets": [], "public": true, "title": "  Salon du mardi  "})
	if not _expect(host.count("joined") > 0, "lobby : create public refuse : %s" % str(host.last("error"))):
		return
	var code: String = host.last("joined")["code"]
	_expect(await _wait(func(): return not _listed(watcher, code).is_empty(), 5.0), "lobby : push `rooms` non recu apres la creation")
	var e := _listed(watcher, code)
	var keys: Array = e.keys()
	keys.sort()
	_expect(keys == ["code", "free", "host", "numPlayers", "sets", "status", "title"], "lobby : champs de l'entree : %s" % str(keys))
	_expect(e.get("title") == "Salon du mardi" and e.get("host") == "Alice" and int(e.get("numPlayers", 0)) == 3 and int(e.get("free", 0)) == 2 and e.get("status") == "open" and e.get("sets") == [], "lobby : entree %s" % str(e))
	_expect(not JSON.stringify(watcher.last("rooms")).contains(str(server.get_room(code).seats[0]["token"])), "lobby : un jeton fuit dans la liste")
	# salon prive (champ absent, ou texte « true » : seul le booleen JSON compte) : jamais liste, ni en reponse ni en push
	var priv := await _create_raw({"name": "Prive", "players": 3, "sets": []})
	var priv2 := await _create_raw({"name": "Prive2", "players": 3, "sets": [], "public": "true", "title": "secret"})
	var pcode: String = priv.last("joined")["code"]
	var pcode2: String = priv2.last("joined")["code"]
	# titre par defaut, titre trop long, setup invalide refuse meme en public
	var zed := await _create_raw({"name": "Zed", "players": 2, "sets": [], "public": true})
	var longt := await _create_raw({"name": "Long", "players": 2, "sets": [], "public": true, "title": "x".repeat(40)})
	# variantes de jeu (TNL) : jetons « -wiki » conserves dans la salle, inconnus ecartes, aussi a 5-6 joueurs (ce ne sont pas des paquets)
	var vroom := await _create_raw({"name": "Var", "players": 2, "sets": ["hard-wiki", "unlimited-wiki", "bogus-wiki"], "public": true})
	var vcode: String = vroom.last("joined")["code"]
	_expect(server.get_room(vcode) != null and server.get_room(vcode).sets == ["hard-wiki", "unlimited-wiki"] and (server.get_room(vcode).lobby_msg()["sets"] as Array).has("hard-wiki"), "lobby : variantes de jeu dans la salle : %s" % str(server.get_room(vcode).sets if server.get_room(vcode) != null else "?"))
	var vbig := await _create_raw({"name": "VarBig", "players": 5, "sets": ["crash-landing", "choose-wiki"]})
	_expect(vbig.count("joined") > 0, "lobby : 5 joueurs + Crash Landing + variante : %s" % str(vbig.last("error")))
	var bad := await _create_raw({"name": "Bad", "players": 5, "sets": [], "public": true})
	_expect(bad.last("error").get("code", "") == "bad_setup" and bad.count("joined") == 0, "lobby : create public invalide : %s" % str(bad.last("error")))
	var zcode: String = zed.last("joined")["code"]
	var lcode: String = longt.last("joined")["code"]
	_expect(await _wait(func(): return not _listed(watcher, zcode).is_empty() and not _listed(watcher, lcode).is_empty(), 5.0), "lobby : push des salons suivants non recu")
	_expect(_listed(watcher, zcode).get("title") == "Zed's game", "lobby : titre par defaut : %s" % str(_listed(watcher, zcode)))
	_expect(str(_listed(watcher, lcode).get("title", "")).length() == 25, "lobby : titre tronque a 25 : %s" % str(_listed(watcher, lcode)))
	_expect(not _in_any_rooms_msg(watcher, pcode) and not _in_any_rooms_msg(watcher, pcode2), "lobby : un salon prive est apparu dans un push")
	var late := await _raw()
	late.send({"t": "listRooms"})
	await _wait(func(): return late.count("rooms") > 0, 5.0)
	_expect(not _in_any_rooms_msg(late, pcode) and not _in_any_rooms_msg(late, pcode2) and not _listed(late, code).is_empty(), "lobby : listRooms d'un 2e client")
	# un client qui a demande la liste puis rejoint une salle ne recoit plus de push
	var g1 := await _raw()
	g1.send({"t": "listRooms"})
	await _wait(func(): return g1.count("rooms") > 0, 5.0)
	g1.send({"t": "join", "code": code, "name": "Bob"})
	_expect(await _wait(func(): return g1.count("joined") > 0, 5.0), "lobby : join de la salle publique")
	var n_rooms := g1.count("rooms")
	_expect(await _wait(func(): return int(_listed(watcher, code).get("free", 0)) == 1, 5.0), "lobby : free doit tomber a 1 apres une jonction")
	# remplir la salle : elle demarre et disparait de la liste (push, et reponse a un nouveau listRooms)
	var g2 := await _raw()
	g2.send({"t": "join", "code": code, "name": "Carl"})
	_expect(await _wait(func(): return g2.count("joined") > 0, 5.0), "lobby : 2e jonction")
	_expect(server.get_room(code).status == "open", "lobby : la salle pleine attend l'hote (plus de demarrage automatique)")
	host.send({"t": "start"})
	_expect(await _wait(func(): return server.get_room(code).status == "running", 5.0), "lobby : l'hote lance la salle pleine")
	_expect(await _wait(func(): return _listed(watcher, code).is_empty(), 5.0), "lobby : une salle pleine / demarree doit disparaitre de la liste")
	late.send({"t": "listRooms"})
	var before := late.count("rooms")
	await _wait(func(): return late.count("rooms") > before, 5.0)
	_expect(_listed(late, code).is_empty(), "lobby : listRooms ne doit pas lister une salle demarree")
	await get_tree().create_timer(0.3).timeout
	_expect(g1.count("rooms") == n_rooms, "lobby : un client en salle recoit encore des `rooms`")
	_expect(by.count("rooms") == 0, "lobby : un client qui n'a pas demande la liste a recu `rooms`")
	# plafond de 50 entrees
	var many: Array = []
	for i in 55:
		many.append(await _raw())
	for i in many.size():
		many[i].send({"t": "create", "name": "M%d" % i, "players": 2, "sets": [], "public": true})
	_expect(await _wait(func(): return many.all(func(m): return m.count("joined") > 0), 10.0), "lobby : 55 creations publiques")
	watcher.send({"t": "listRooms"})
	var before_w := watcher.count("rooms")
	await _wait(func(): return watcher.count("rooms") > before_w, 5.0)
	_expect(watcher.last("rooms")["rooms"].size() == 50, "lobby : %d entrees au lieu de 50" % watcher.last("rooms")["rooms"].size())
	await get_tree().create_timer(0.3).timeout # le push de la liste a 50 entrees part (au plus un par intervalle), puis les fermetures le suivent
	_expect(watcher.msgs.any(func(m): return m.get("t", "") == "rooms" and (m["rooms"] as Array).size() == 50), "lobby : push de 50 entrees non recu")
	for m in many: # l'hote qui quitte une salle d'attente la ferme
		m.send({"t": "leave"})
	_expect(await _wait(func(): return (watcher.last("rooms")["rooms"] as Array).size() <= 4, 10.0), "lobby : les salles fermees doivent quitter la liste (%d)" % watcher.last("rooms")["rooms"].size())
	for m in many:
		m.queue_free()
	for n in [by, watcher, host, priv, priv2, zed, longt, bad, late, g1, g2]:
		n.queue_free()
	server.rooms_push_interval_ms = 250

## Sieges fantomes (onglet ferme sans `leave`) liberes apres la grace ; un rechargement dans la grace reprend son siege ; l'hote n'est jamais libere ;
## salle publique ouverte sans humain fermee apres public_idle_s.
func _scenario_ghosts() -> void:
	server.seat_grace_s = 2
	server.gc_interval_ms = 100
	server.public_idle_s = 1
	var h := await _create_raw({"name": "Hote", "players": 3, "sets": []})
	var code: String = h.last("joined")["code"]
	var g := await _raw()
	g.send({"t": "join", "code": code, "name": "Fantome"})
	await _wait(func(): return g.count("joined") > 0, 5.0)
	var token: String = g.last("joined")["token"]
	var room = server.get_room(code)
	# rechargement dans la grace : le siege est repris
	g.ws.close()
	_expect(await _wait(func(): return room.seats[1]["conn"] == -1, 3.0), "fantome : detach non vu")
	var g2 := await _raw()
	g2.send({"t": "resume", "code": code, "seat": 1, "token": token})
	_expect(await _wait(func(): return g2.count("joined") > 0, 3.0), "fantome : resume dans la grace refuse : %s" % str(g2.last("error")))
	await get_tree().create_timer(0.5).timeout
	_expect(bool(room.seats[1]["taken"]) and int(room.seats[1]["conn"]) >= 0, "fantome : le siege repris doit rester occupe")
	# onglet ferme pour de bon : siege libere apres la grace, lobby diffuse, ancien jeton mort
	g2.ws.close()
	_expect(await _wait(func(): return not bool(room.seats[1]["taken"]), 8.0), "fantome : siege non libere apres la grace")
	_expect(await _wait(func(): return h.last("lobby").get("seats", [{}, {}])[1].get("name", "x") == null, 3.0), "fantome : le lobby de l'hote n'a pas ete mis a jour")
	var g3 := await _raw()
	g3.send({"t": "resume", "code": code, "seat": 1, "token": token})
	_expect(await _wait(func(): return g3.count("error") > 0, 3.0) and g3.last("error").get("code", "") == "bad_token", "fantome : l'ancien jeton doit etre mort")
	# l'hote absent garde son siege et sa salle privee (il peut partager le code dans une autre appli)
	h.ws.close()
	await get_tree().create_timer(3.0).timeout
	_expect(server.get_room(code) != null and bool(room.seats[0]["taken"]), "fantome : l'hote absent ne doit pas perdre sa salle privee")
	# salle publique : plus aucun humain connecte -> fermee apres public_idle_s, et retiree de la liste
	var watcher := await _raw()
	watcher.send({"t": "listRooms"})
	var p := await _create_raw({"name": "Pub", "players": 3, "sets": [], "public": true})
	var pcode: String = p.last("joined")["code"]
	_expect(await _wait(func(): return not _listed(watcher, pcode).is_empty(), 3.0), "fantome : salle publique non listee")
	await get_tree().create_timer(1.5).timeout
	_expect(server.get_room(pcode) != null, "fantome : une salle publique avec son hote connecte ne doit pas etre fermee")
	p.ws.close()
	_expect(await _wait(func(): return server.get_room(pcode) == null, 6.0), "fantome : salle publique vide non fermee")
	_expect(await _wait(func(): return _listed(watcher, pcode).is_empty(), 3.0), "fantome : salle publique fermee encore listee")
	server.seat_grace_s = 30
	server.gc_interval_ms = 5000
	server.public_idle_s = 120
	for n in [h, g, g2, g3, watcher, p]:
		n.queue_free()

## Taille maximale d'un message (16 Kio, puis le tampon d'entree) et limite de debit par connexion (60 messages/s).
func _scenario_limits() -> void:
	var ok := await _raw()
	ok.send({"t": "create", "name": "N".repeat(5000), "players": 2, "sets": [], "title": "T".repeat(5000)}) # gros mais sous la borne : accepte, puis nettoye
	_expect(await _wait(func(): return ok.count("joined") > 0, 3.0), "limites : un message de 10 Kio doit passer : %s" % str(ok.last("error")))
	_expect(str(server.get_room(ok.last("joined")["code"]).seats[0]["name"]).length() == 25, "limites : nom non tronque")
	var big := await _raw()
	big.send({"t": "ping", "pad": "x".repeat(20000)})
	_expect(await _wait(func(): return big.closed, 3.0) and big.close_code == 1009, "limites : 20 Kio -> fermeture 1009 attendue (code %d)" % big.close_code)
	_expect(big.count("pong") == 0, "limites : un message trop gros ne doit pas etre traite")
	var huge := await _raw()
	huge.send({"t": "ping", "pad": "x".repeat(300000)})
	# 300 Kio > tampon d'entree : Godot coupe lui-meme (1009 cote serveur) ; le client voit la liaison tomber (code de fermeture -1 ou 1009)
	_expect(await _wait(func(): return huge.closed, 3.0) and huge.close_code in [1009, -1], "limites : 300 Kio -> fermeture attendue (closed=%s code %d)" % [huge.closed, huge.close_code])
	var flood := await _raw()
	for i in 100:
		flood.send({"t": "ping"})
	_expect(await _wait(func(): return flood.closed, 3.0) and flood.close_code == 1008, "limites : 100 messages dans la seconde -> fermeture 1008 attendue (code %d)" % flood.close_code)
	_expect(flood.count("pong") <= Server.MAX_MSGS_PER_SEC, "limites : %d reponses a la rafale (plafond %d)" % [flood.count("pong"), Server.MAX_MSGS_PER_SEC])
	for n in [ok, big, huge, flood]:
		n.queue_free()

## Lot 3.2 : le lobby public cote client contre le vrai serveur. `watch_rooms` n'attend rien (l'ecran lit `connected`) ; la liste arrive par `rooms_received`
## (reponse puis pushes) ; un salon prive n'y figure pas ; join_lobby rejoint la salle d'un autre client ; une liaison coupee se rouvre et redemande la liste.
func _scenario_public_client() -> void:
	server.rooms_push_interval_ms = 50
	var host := _client("Alice")
	var priv := _client("Secret")
	var guest := _client("Bob")
	var lists: Array = []
	guest.rooms_received.connect(func(rs): lists.append(rs))
	guest.watch_rooms()
	if not _expect(await _wait(func(): return guest.connected and not lists.is_empty(), 5.0), "lobby client : pas de liste initiale"):
		return
	_expect(await priv.create_lobby(3, []), "lobby client : create prive")
	_expect(await host.create_lobby(3, ["players-choice"], 0, true, "Duel du soir"), "lobby client : create public")
	var code := host.match_id
	_expect(host.public_room and not priv.public_room, "lobby client : public_room")
	_expect(await _wait(func(): return (lists.back() as Array).any(func(e): return e["code"] == code), 5.0), "lobby client : push `rooms` non recu apres la creation")
	var e: Dictionary = (lists.back() as Array).filter(func(x): return x["code"] == code)[0]
	_expect(e["title"] == "Duel du soir" and e["host"] == "Alice" and int(e["free"]) == 2 and int(e["numPlayers"]) == 3 and e["sets"] == ["players-choice"], "lobby client : entree %s" % str(e))
	_expect(not lists.any(func(rs): return (rs as Array).any(func(x): return x["code"] == priv.match_id)), "lobby client : salon prive liste")
	# liaison coupee : elle se rouvre toute seule et redemande la liste (rooms_received) tant que l'ecran est ouvert
	var n_lists := lists.size()
	guest._ws.close()
	_expect(await _wait(func(): return not guest.connected, 5.0), "lobby client : coupure non vue")
	_expect(await _wait(func(): return guest.connected and lists.size() > n_lists, 10.0), "lobby client : la liaison ne se rouvre pas / la liste n'est pas redemandee")
	# JOIN d'une salle d'un autre client : siege 1, le client ne regarde plus la liste
	_expect(await guest.join_lobby(code, "Bob"), "lobby client : join de la salle publique")
	_expect(guest.player_id == 1 and not guest._watching and server.get_room(code).seats[1]["name"] == "Bob", "lobby client : mauvais siege apres le join")
	n_lists = lists.size()
	await get_tree().create_timer(0.3).timeout
	_expect(lists.size() == n_lists, "lobby client : un client en salle recoit encore des listes")
	# quitter la salle d'attente libere le siege TOUT DE SUITE (avant : close() jetait `leave`, siege fantome jusqu'a la fin de la grace de 30 s), liaison gardee ou fermee
	guest.leave_match(true)
	_expect(await _wait(func(): return not bool(server.get_room(code).seats[1]["taken"]), 3.0) and guest.connected, "lobby client : leave_match(true) ne libere pas le siege / ferme la liaison")
	_expect(await guest.join_lobby(code, "Bob"), "lobby client : re-join apres leave")
	guest.leave_match()
	_expect(await _wait(func(): return not bool(server.get_room(code).seats[1]["taken"]), 3.0), "lobby client : leave_match() ne libere pas le siege")
	_expect(await _wait(func(): return not guest.connected, 3.0) and guest._ws == null, "lobby client : leave_match() doit fermer la liaison apres le depart de `leave`")
	# join d'un code inconnu depuis la liste : echec propre, il continue de suivre la liste
	var late := _client("Cara")
	var late_lists: Array = []
	late.rooms_received.connect(func(rs): late_lists.append(rs))
	late.watch_rooms()
	_expect(await _wait(func(): return late.connected and not late_lists.is_empty(), 5.0), "lobby client : 2e observateur")
	_expect(not await late.join_lobby("ZZZZ", "Cara") and late.last_error_code == "not_found" and late._watching and late._want_open, "lobby client : echec de join depuis la liste")
	late.unwatch_rooms() # sans salle : la liaison est fermee
	_expect(await _wait(func(): return not late.connected, 5.0) and not late._want_open, "lobby client : unwatch_rooms doit fermer la liaison")
	for c in [host, priv, guest, late]:
		c.queue_free()
	server.rooms_push_interval_ms = 250

## Lot 3.3 (audit 3.0 §4.3, test INVERSE de l'ancien « la boucle existe ») : un deuxieme onglet reprend le MEME siege avec le meme jeton ; le serveur evince
## le premier en 1000 « siege repris ailleurs ». Avant : le client evince se reconnectait apres 1 s et evincait l'autre, sans fin. Maintenant il ne se
## reconnecte PAS : session oubliee, signal `evicted`, le siege reste au 2e onglet, sans le moindre changement de connexion ensuite.
func _scenario_eviction() -> void:
	var a := _client("Alice")
	var b := _client("Bob")
	if not _expect(await a.create_lobby(2, []), "eviction : create"):
		return
	_expect(await b.join_lobby(a.match_id, "Bob"), "eviction : join")
	var room = server.get_room(a.match_id)
	var token := b.credentials
	var evicted := [0]
	b.evicted.connect(func(): evicted[0] += 1)
	# « deuxieme onglet » : meme session que Bob (c'etait le fichier de session partage), il reprend le siege 1
	var b2 := _client("")
	b2.match_id = b.match_id
	b2.player_id = b.player_id
	b2.credentials = b.credentials
	b2._resume_on_open = true
	_expect(await b2._ensure_open(), "eviction : ouverture du 2e onglet")
	_expect(await _wait(func(): return evicted[0] > 0, 5.0), "eviction : le client evince n'a pas ete prevenu (evicted)")
	_expect(b.match_id == "" and b.credentials == "" and b.player_id == -1 and not b._want_open and not b.connected, "eviction : le client evince doit oublier sa session et ne plus vouloir se reconnecter")
	# 3 s d'observation (la boucle d'avant evincait environ une fois par seconde) : plus aucun changement de connexion sur le siege
	var conn: int = int(room.seats[1]["conn"])
	var changes := 0
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 3000:
		await get_tree().process_frame
		if int(room.seats[1]["conn"]) != conn:
			changes += 1
			conn = int(room.seats[1]["conn"])
	print("ONLINE eviction : %d changement(s) de connexion du siege 1 en 3 s apres l'eviction, evicted=%d" % [changes, evicted[0]])
	_expect(changes == 0 and evicted[0] == 1, "eviction : la boucle existe encore (%d changements, %d evictions)" % [changes, evicted[0]])
	_expect(b2.connected and b2.match_id == a.match_id and bool(room.seats[1]["taken"]) and str(room.seats[1]["token"]) == token and conn >= 0, "eviction : le siege doit rester au 2e onglet, jeton intact")
	for n in [a, b, b2]:
		n.queue_free()

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
	# l'humain ne fait rien : l'IA ne joue QUE la decision expiree (choix du boss), puis il reprend la main (N-B15)
	_expect(await _wait(func(): return c.current_G.get("players", {}).get(0, {}).get("boss") != null, 6.0), "le boss n'a pas ete choisi par l'IA")
	_expect(not bool(room.seats[0]["auto"]), "timeout : le siege ne doit pas passer en auto apres un seul depassement")
	_expect(str(c.current_G.get("log", [])).contains("prend le relais"), "journal : prise de relais non annoncee : %s" % str(c.current_G.get("log", [])).right(300))
	# l'humain est de nouveau attendu : un second depassement (nouvelle decision) est constate separement
	var windows := {}
	_expect(await _wait(func():
		if room.awaited_seats.has(0):
			windows[room.deadline_ms] = true
		return windows.size() >= 3, 12.0), "timeout : l'humain n'a pas ete attendu a nouveau (%d fenetres)" % windows.size())
	_expect(not bool(room.seats[0]["auto"]), "timeout : auto reste faux tant que la liaison est ouverte")
	# reconnexion : le joueur reprend son siege
	c._ws.close()
	await _wait(func(): return not c.connected, 5.0)
	var serial: int = int(c.current_ctx.get("serverTime", 0))
	_expect(await _wait(func(): return c.connected and int(c.current_ctx.get("serverTime", 0)) != serial and not bool(room.seats[0]["auto"]), 10.0), "le siege n'a pas ete rendu a la reconnexion")
	c.queue_free()

## Salle isolee (sans reseau) menee jusqu'au tour de construction du siege 0 humain, avec une pose possible.
func _room_at_human_build() -> GameRoom:
	var room := GameRoom.new("TST1", 2, [])
	room.seats[0].merge({"name": "H", "taken": true, "token": "t", "conn": 99}, true)
	room.add_bots(1)
	room.bot_delay_ms = 0
	room.start()
	for _i in 600:
		room.tick()
		var G: Dictionary = room.m.G
		if G.get("gameOver") != null:
			return null
		if str(G.get("phase", "")) == "build" and room.m.active_player() == 0 and not G.has("buildWindow") and (G.get("stack", []) as Array).is_empty() \
				and (room.m.legal_moves(0) as Array).any(func(mv): return str(mv["type"]) == "buildRoom"):
			return room
		if room._awaited().has(0):
			var mv = AI.pick_move(room.m, 0)
			if mv == null or room.submit_move(0, mv) != "":
				return null
	return null

## N-B16 / N-B15 : le delai appartient a la fenetre de decision ; un depassement ne joue qu'une decision.
func _scenario_deadline_window() -> void:
	var room := _room_at_human_build()
	if not _expect(room != null, "delai : tour de construction humain introuvable"):
		return
	_expect(room.turn_timeout_ms == 70000, "delai : defaut attendu 70 s (barre DONE de l'APK)")
	var d0: int = room.deadline_ms
	_expect(d0 > 0 and room.awaited_seats.has(0), "delai : aucun delai pour le constructeur")
	await get_tree().create_timer(0.05).timeout
	var build: Dictionary = (room.m.legal_moves(0) as Array).filter(func(mv): return str(mv["type"]) == "buildRoom")[0]
	_expect(room.submit_move(0, build) == "", "delai : buildRoom refuse")
	_expect(room.deadline_ms == d0, "delai : buildRoom ne doit pas repousser l'echeance")
	var undo: Array = (room.m.legal_moves(0) as Array).filter(func(mv): return str(mv["type"]) == "undoBuild")
	if _expect(not undo.is_empty(), "delai : undoBuild non propose apres la pose"):
		_expect(room.submit_move(0, undo[0]) == "", "delai : undoBuild refuse")
		_expect(room.deadline_ms == d0, "delai : undoBuild ne doit pas repousser l'echeance")
	# resume d'un autre siege : pas de delai neuf
	room.seats[1].merge({"bot": false, "taken": true, "token": "u", "conn": 98}, true)
	room.resume(1, "u", 98)
	_expect(room.deadline_ms == d0, "delai : un resume ne doit pas repousser l'echeance")
	room.seats[1]["bot"] = true
	# echeance : seule la decision expiree est jouee (DONE), le siege reste humain
	var turn_before := int(room.m.G.get("turn", 0))
	room.deadline_ms = GameRoom._now() - 1
	room.tick()
	_expect(not bool(room.seats[0]["auto"]), "timeout : le siege connecte ne doit pas passer en auto")
	_expect(str(room.m.G.get("log", [])).contains("pas répondu à temps"), "timeout : journal")
	_expect(room.m.active_player() != 0 or int(room.m.G.get("turn", 0)) != turn_before or room.m.G.has("buildWindow") or str(room.m.G.get("phase", "")) != "build", "timeout : le DONE automatique n'a pas ete joue")
	for _i in 200: # l'IA ne joue plus pour lui
		room.tick()
	_expect(not bool(room.seats[0]["auto"]), "timeout : auto apparu apres les ticks")
	room.dispose()

## N-B11 / N-B08 : apres `leave` on peut creer une autre salle ; salle fermee / perdue en partie -> session_lost.
func _scenario_leave_and_lost() -> void:
	var c := _client("Sortant")
	if not _expect(await c.create_lobby(2, [], 1), "leave : create"):
		return
	var first := c.match_id
	_expect(await _wait(func(): return not c.current_G.is_empty(), 5.0), "leave : pas d'etat")
	c.leave_match() # sortie du plateau (Main._leave_board)
	_expect(c.match_id == "" and not c.has_saved_session(), "leave : session non oubliee")
	_expect(await _wait(func(): return not c.connected, 5.0), "leave : liaison non fermee")
	_expect(await c.create_lobby(2, [], 1), "leave : la creation suivante doit reussir (pas de busy)")
	_expect(c.match_id != "" and c.match_id != first, "leave : nouvelle salle attendue")
	# salle fermee cote serveur pendant la partie : session_lost
	var lost := [0]
	c.session_lost.connect(func(): lost[0] += 1)
	var id_at_error := ["?"]
	c.request_error.connect(func(_m): id_at_error[0] = c.match_id)
	server._close_room(c.match_id)
	_expect(await _wait(func(): return id_at_error[0] != "?", 3.0) and id_at_error[0] == "", "N-B33 : request_error d'une salle fermee doit voir match_id vide (l'ecran d'attente en deduit « Room closed »)")
	_expect(await _wait(func(): return lost[0] == 1, 3.0) and c.match_id == "", "session_lost : salle fermee non signalee")
	# salle inconnue au resume (serveur redemarre) : session_lost
	c._on_message({"t": "joined", "code": "ZZZZ", "seat": 0, "token": "x"})
	c._on_message({"t": "error", "code": "not_found", "message": "salon introuvable"})
	_expect(lost[0] == 2, "session_lost : not_found non signale")
	c.queue_free()

## S-11 : defaite comptee au debut, annulee a la victoire (une seule fois par salle). Sauvegarde et restaure le profil reel.
func _scenario_profile_counts() -> void:
	var existed := FileAccess.file_exists(Profile.SAVE_PATH)
	var backup: PackedByteArray = FileAccess.get_file_as_bytes(Profile.SAVE_PATH) if existed else PackedByteArray()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Profile.SAVE_PATH))
	Profile.record_start("AAAA")
	Profile.record_start("AAAA")
	_expect(Profile.load_stats() == {"wins": 0, "defeats": 1}, "stats : debut = 1 defaite (une fois) : %s" % str(Profile.load_stats()))
	Profile.record_result(true, "AAAA")
	Profile.record_result(true, "AAAA")
	_expect(Profile.load_stats() == {"wins": 1, "defeats": 0}, "stats : victoire annule la defaite : %s" % str(Profile.load_stats()))
	Profile.record_start("BBBB")
	Profile.record_result(false, "BBBB")
	_expect(Profile.load_stats() == {"wins": 1, "defeats": 1}, "stats : defaite non doublee : %s" % str(Profile.load_stats()))
	Profile.record_result(false, "CCCC") # partie jamais vue demarrer (reprise tardive)
	_expect(Profile.load_stats()["defeats"] == 2, "stats : defaite sans debut compte une fois")
	if existed:
		var f := FileAccess.open(Profile.SAVE_PATH, FileAccess.WRITE)
		f.store_buffer(backup)
		f.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Profile.SAVE_PATH))

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

## Plafond de connexions du serveur (max_conns) : au-dela, la liaison est refusee des l'acceptation TCP. Le serveur Godot ne voit que l'adresse de
## nginx, donc AUCUN plafond par IP ici : le 429 par IP (limit_req / limit_conn) vit dans deploy/nginx.conf, que l'on verifie en texte.
func _scenario_conn_cap() -> void:
	server.max_conns = 0
	var refused := Raw.new()
	add_child(refused)
	refused.open(url)
	_expect(await _wait(func(): return refused.closed, 5.0) and not refused.msgs.size() > 0, "plafond : une connexion au-dela de max_conns doit etre refusee")
	server.max_conns = 512
	var ok := await _raw()
	ok.send({"t": "ping"})
	_expect(await _wait(func(): return ok.count("pong") > 0, 3.0), "plafond : la connexion doit repasser une fois le plafond releve")
	refused.queue_free()
	ok.queue_free()
	var path := ProjectSettings.globalize_path("res://").path_join("../../deploy/nginx.conf")
	if FileAccess.file_exists(path):
		var conf := FileAccess.get_file_as_string(path)
		for needle in ["limit_req_status 429;", "limit_conn_status 429;", "limit_req_zone  $binary_remote_addr zone=bm_ws:10m   rate=5r/s;", "limit_conn bm_conn 20;"]:
			_expect(conf.contains(needle), "nginx : limite par IP absente de deploy/nginx.conf : %s" % needle)

## Titre de salon (lot 3.5) : `setTitle` reserve a l'hote d'une salle d'attente, texte nettoye cote serveur (frontiere de confiance), repousse dans la liste.
func _scenario_title() -> void:
	server.rooms_push_interval_ms = 50
	var watcher := await _raw()
	watcher.send({"t": "listRooms"})
	var host := await _create_raw({"name": "Alice", "players": 2, "sets": [], "public": true, "title": "Avant"})
	var code: String = host.last("joined")["code"]
	_expect(await _wait(func(): return _listed(watcher, code).get("title", "") == "Avant", 3.0), "titre : salon initial non liste")
	host.send({"t": "setTitle", "title": "  Apres  "})
	_expect(await _wait(func(): return host.count("titled") > 0, 3.0) and host.last("titled").get("title", "") == "Apres", "titre : `titled` attendu avec le titre nettoye : %s" % str(host.last("titled")))
	_expect(await _wait(func(): return _listed(watcher, code).get("title", "") == "Apres", 3.0), "titre : la liste publique doit pousser le nouveau titre")
	_expect(host.last("lobby").get("title", "") == "Apres", "titre : le `lobby` porte le titre : %s" % str(host.last("lobby")))
	# nettoyage : caracteres de controle et surcharges bidi retires, 25 caracteres au plus
	host.send({"t": "setTitle", "title": "A" + char(7) + "B" + char(0x202E) + "C" + char(0x200B) + "D
" + "x".repeat(40)})
	_expect(await _wait(func(): return host.count("titled") > 1, 3.0) and host.last("titled").get("title", "") == ("ABCDx" + "x".repeat(20)), "titre : controle / bidi / longueur : %s" % str(host.last("titled")))
	# refus : pas une chaine, vide apres nettoyage -> bad_message, titre inchange
	var n_err := host.count("error")
	host.send({"t": "setTitle", "title": 12345})
	host.send({"t": "setTitle", "title": char(7) + char(0x202E) + "  "})
	host.send({"t": "setTitle"})
	_expect(await _wait(func(): return host.count("error") >= n_err + 3, 3.0), "titre : trois refus attendus")
	_expect(host.msgs.filter(func(m): return m.get("t", "") == "error").slice(n_err).all(func(m): return m.get("code", "") == "bad_message"), "titre : bad_message attendu")
	_expect(server.get_room(code).title == "ABCDx" + "x".repeat(20), "titre : un titre refuse ne doit rien changer")
	# un invite ne renomme pas ; hors salle non plus
	var guest := await _raw()
	var lone := await _raw()
	lone.send({"t": "setTitle", "title": "Pirate"})
	_expect(await _wait(func(): return lone.count("error") > 0, 3.0) and lone.last("error").get("code", "") == "forbidden", "titre : hors salle -> forbidden")
	var room3 := await _create_raw({"name": "Trio", "players": 3, "sets": [], "public": true, "title": "Trio"})
	var code3: String = room3.last("joined")["code"]
	guest.send({"t": "join", "code": code3, "name": "Bob"})
	await _wait(func(): return guest.count("joined") > 0, 3.0)
	guest.send({"t": "setTitle", "title": "Pirate"})
	_expect(await _wait(func(): return guest.count("error") > 0, 3.0) and guest.last("error").get("code", "") == "forbidden" and server.get_room(code3).title == "Trio", "titre : un invite ne renomme pas")
	# partie lancee : bad_state
	room3.send({"t": "start"})
	await _wait(func(): return server.get_room(code3).status == "running", 3.0)
	room3.send({"t": "setTitle", "title": "Tard"})
	_expect(await _wait(func(): return room3.last("error").get("code", "") == "bad_state", 3.0) and server.get_room(code3).title == "Trio", "titre : salle lancee -> bad_state")
	# API client
	var c := _client("Carol")
	if _expect(await c.create_lobby(2, [], 0, true, "Carol's game"), "titre : create_lobby public"):
		_expect(await c.set_title("Renomme"), "titre : set_title de l'hote")
		_expect(await _wait(func(): return c.current_title == "Renomme", 3.0), "titre : current_title du client")
		_expect(not await c.set_title("  "), "titre : set_title vide refuse")
	# filtre de la liste (cote client)
	var rooms := [{"title": "Salon du mardi", "host": "Alice", "numPlayers": 3}, {"title": "Duel", "host": "Bob", "numPlayers": 2}, {"title": "Foo", "host": "ALICIA", "numPlayers": 4}]
	_expect(OnlineMenus.filter_rooms(rooms, "").size() == 3 and OnlineMenus.filter_rooms(rooms, "  ").size() == 3, "filtre : vide = tout")
	_expect(OnlineMenus.filter_rooms(rooms, "MARDI").size() == 1 and OnlineMenus.filter_rooms(rooms, "ali").size() == 2, "filtre : titre / hote sans casse")
	_expect(OnlineMenus.filter_rooms(rooms, "2").size() == 1 and OnlineMenus.filter_rooms(rooms, "4").size() == 1 and OnlineMenus.filter_rooms(rooms, "zzz").is_empty(), "filtre : nombre de places / aucun resultat")
	server.rooms_push_interval_ms = 250
	for n in [watcher, host, guest, lone, room3, c]:
		n.queue_free()

## Salle isolee a 2 humains (connexions factices 98 / 99), menee jusqu'a une pause d'aventure ou les deux sont attendus ; null si la graine n'en donne pas.
func _room_at_adventure_pause() -> GameRoom:
	var room := GameRoom.new("TST2", 2, [])
	for i in 2:
		room.seats[i].merge({"name": "H%d" % i, "taken": true, "token": "t%d" % i, "conn": 98 + i}, true)
	room.start()
	for _i in 4000:
		var G: Dictionary = room.m.G
		if G.get("gameOver") != null:
			break
		if room._in_adventure_pause() and room.awaited_seats.size() == 2 and room.deadline_ms > 0:
			return room
		var aw: Array = room._awaited()
		if aw.is_empty():
			break
		var pid: int = aw[0]
		var mv = AI.pick_move(room.m, pid)
		if mv == null or room.submit_move(pid, mv) != "":
			mv = (room.m.legal_moves(pid) as Array)[0]
			if room.submit_move(pid, mv) != "":
				break
	room.dispose()
	return null

## N-B15 : deux humains dans une pause d'aventure, le delai expire. Seule la decision expiree est jouee (les passes de la pause), aucun siege ne passe en `auto`,
## un nouveau delai court, et l'IA ne joue pas ensuite a la place des humains (avant 10184ad : `auto` permanent des le premier depassement).
func _scenario_adventure_expiry() -> void:
	var room: GameRoom = null
	for _try in 6:
		room = _room_at_adventure_pause()
		if room != null:
			break
	if not _expect(room != null, "pause d'aventure : introuvable a 2 humains"):
		return
	_expect(room.adventure_timeout_ms == 10000, "pause d'aventure : delai de 10 s attendu")
	var log_before := (room.m.G.get("log", []) as Array).size()
	room.deadline_ms = GameRoom._now() - 1
	room.tick()
	_expect(str(room.m.G.get("log", [])).contains("pas répondu à temps"), "pause d'aventure : prise de relais non journalisee")
	_expect((room.m.G.get("log", []) as Array).size() > log_before, "pause d'aventure : aucune decision jouee a l'echeance")
	for i in 2:
		_expect(not bool(room.seats[i]["auto"]), "pause d'aventure : le siege %d connecte ne doit pas passer en auto" % i)
	_expect(room.deadline_ms == 0 or room.deadline_ms > GameRoom._now(), "pause d'aventure : un nouveau delai doit courir (ou personne n'est attendu)")
	# les humains sont de nouveau seuls maitres : sans autre echeance, 300 ticks ne changent rien a la partie
	var snap := JSON.stringify(NetCodec.encode(room.m.G.get("log", [])))
	for _i in 300:
		room.tick()
	_expect(JSON.stringify(NetCodec.encode(room.m.G.get("log", []))) == snap, "pause d'aventure : l'IA a continue de jouer pour un humain connecte")
	for i in 2:
		_expect(not bool(room.seats[i]["auto"]), "pause d'aventure : siege %d en auto apres les ticks" % i)
	room.dispose()

## N-B24 : les sorts / capacites joues sont notes (carte comprise, la main est cachee aux autres) et diffuses ; le client ne les emet qu'une fois et jamais pour son propre siege.
func _scenario_plays() -> void:
	var room := GameRoom.new("TST3", 2, [])
	room.seats[0].merge({"name": "H", "taken": true, "token": "t", "conn": 99}, true)
	room.add_bots(1)
	room.bot_delay_ms = 0
	room.start()
	for _i in 6000:
		if not room._plays.is_empty() or room.m.G.get("gameOver") != null:
			break
		room.tick()
		var aw: Array = room._awaited()
		if not aw.is_empty():
			var mv = AI.pick_move(room.m, aw[0])
			if mv == null or room.submit_move(aw[0], mv) != "":
				break
	if _expect(not room._plays.is_empty(), "plays : aucun sort / capacite note en 6000 coups"):
		var p: Dictionary = room._plays[0]
		_expect(str(p["move"]["type"]) in ["playSpell", "useHandRoom", "activateRoom"] and (p["card"] as Dictionary).has("id") and int(p["n"]) == 1, "plays : entree mal formee : %s" % str(p).left(200))
		var msg := room.state_msg(1 - int(p["seat"]))
		_expect((msg["plays"] as Array).size() >= 1 and int(msg["plays"][0]["n"]) == 1, "plays : absent de l'etat envoye")
	room.dispose()
	var c := OnlineClient.new()
	c.player_id = 0
	add_child(c)
	var got: Array = []
	c.remote_play.connect(func(p): got.append(int(p["n"])))
	c._emit_plays([{"n": 4, "seat": 1}]) # premier etat : repere seulement
	c._emit_plays([{"n": 4, "seat": 1}, {"n": 5, "seat": 1}, {"n": 6, "seat": 0}])
	c._emit_plays([{"n": 5, "seat": 1}, {"n": 6, "seat": 0}, {"n": 7, "seat": 1}])
	_expect(got == [5, 7], "plays : le client doit emettre une fois les coups des autres sieges (%s)" % str(got))
	c.queue_free()

## N-A40 : un humain quitte en pleine partie -> `left` dans le lobby de l'autre, signal player_left une seule fois (jamais pour une simple coupure).
func _scenario_player_left() -> void:
	var a := _client("Alice")
	if not _expect(await a.create_lobby(2, []), "left : create"):
		return
	var b := _client("Bob")
	_expect(await b.join_lobby(a.match_id, "Bob"), "left : join")
	a.start_match()
	_expect(await _wait(func(): return not a.current_G.is_empty() and not b.current_G.is_empty(), 5.0), "left : la partie ne demarre pas")
	var left: Array = []
	a.player_left.connect(func(seat, pname): left.append([seat, pname]))
	b._ws.close() # simple coupure : le siege n'est pas abandonne
	await _wait(func(): return not b.connected, 3.0)
	await get_tree().create_timer(0.3).timeout
	_expect(left.is_empty(), "left : une coupure ne doit pas signaler un depart")
	await _wait(func(): return b.connected, 6.0)
	b.leave_match()
	_expect(await _wait(func(): return left.size() == 1, 3.0), "left : player_left non emis")
	_expect(left == [[1, "Bob"]], "left : mauvais siege / nom %s" % str(left))
	_expect(bool((a.current_seats[1] as Dictionary).get("left", false)), "left : `left` absent du lobby")
	a.queue_free()
	b.queue_free()

## N-A46 : create / join / resume / listRooms doivent porter la version du protocole ; sinon `error` `version`, rien n'est cree ni liste. ping n'est pas concerne.
func _scenario_version() -> void:
	var r := await _raw()
	var rooms_before: int = server.room_count()
	for bad in [null, 0, NetCodec.PROTOCOL_VERSION + 1, "1", [1]]:
		for t in ["create", "join", "resume", "listRooms"]:
			var n := r.count("error")
			r.send({"t": t, "name": "V", "players": 2, "sets": [], "code": "abcd", "seat": 0, "token": "x", "v": bad})
			_expect(await _wait(func(): return r.count("error") > n, 3.0) and r.last("error").get("code", "") == "version", "version : %s avec v=%s doit etre refuse (version)" % [t, str(bad)])
	var n0 := r.count("error")
	r.ws.send_text(JSON.stringify({"t": "listRooms"})) # sans le champ v (ancien client)
	r.ws.send_text(JSON.stringify({"t": "create", "name": "V", "players": 2, "sets": []}))
	_expect(await _wait(func(): return r.count("error") >= n0 + 2, 3.0), "version : un message sans `v` doit etre refuse")
	_expect(r.count("rooms") == 0 and r.count("joined") == 0 and server.room_count() == rooms_before, "version : refus sans effet (ni salle ni liste)")
	r.send({"t": "ping"})
	_expect(await _wait(func(): return r.count("pong") > 0, 3.0), "version : ping n'exige pas la version")
	r.send({"t": "create", "name": "V", "players": 2, "sets": []})
	_expect(await _wait(func(): return r.count("joined") > 0, 3.0), "version : create avec la bonne version")
	r.send({"t": "leave"})
	# client perime : create_lobby echoue et le code d'erreur est `version` (les menus affichent « Game updated. »)
	var c := _client("Perime")
	c.protocol_version = NetCodec.PROTOCOL_VERSION + 1
	_expect(not await c.create_lobby(2, []) and c.last_error_code == "version" and c.match_id == "", "version : un client perime doit etre refuse (%s)" % c.last_error_code)
	c.queue_free()
	# onglet perime qui reprend sa session apres une mise a jour du serveur : `resume` refuse -> session perdue (pas de plateau fige sur une liaison vivante)
	var s := _client("Stale")
	if _expect(await s.create_lobby(2, []), "version : create du client perime"):
		var lost := [0]
		s.session_lost.connect(func(): lost[0] += 1)
		s.protocol_version = NetCodec.PROTOCOL_VERSION + 1
		s._ws.close() # la reconnexion automatique envoie `resume` avec la mauvaise version
		_expect(await _wait(func(): return lost[0] == 1 and s.match_id == "" and s.last_error_code == "version", 8.0), "version : un `resume` refuse pour version doit perdre la session (%d, %s)" % [lost[0], s.last_error_code])
	s.queue_free()
	r.queue_free()

## N-A71 : `away` (pagehide de l'onglet en salle d'attente) libere le siege apres --away-grace au lieu de --seat-grace ; un `resume` dans le delai le garde.
## N-A43 : le lobby porte `public` (survit a une reprise apres rechargement).
func _scenario_away() -> void:
	server.away_grace_s = 3
	server.seat_grace_s = 30
	server.gc_interval_ms = 100
	var a := _client("Hote")
	if not _expect(await a.create_lobby(4, [], 0, true, "Pub"), "away : create"):
		return
	var room = server.get_room(a.match_id)
	a.public_room = false # reprise apres rechargement : le client a perdu l'info
	a.fetch_lobby()
	_expect(await _wait(func(): return a.public_room, 3.0), "lobby : `public` doit rendre le drapeau au client")
	var peers: Array = []
	for nm in ["B", "C", "D"]:
		var p := _client(nm)
		_expect(await p.join_lobby(a.match_id, nm), "away : join %s" % nm)
		peers.append(p)
	var b: OnlineClient = peers[0]
	var cc: OnlineClient = peers[1]
	var d: OnlineClient = peers[2]
	_expect(not bool(room.seats[1]["away"]), "away : drapeau absent au depart")
	for p in [b, d]:
		p._on_pagehide([])
	_expect(await _wait(func(): return bool(room.seats[1]["away"]) and bool(room.seats[3]["away"]), 3.0), "away : le serveur n'a pas note le pagehide")
	_expect(not bool(room.seats[2]["away"]), "away : seul l'onglet qui l'annonce est marque")
	for p in [b, cc]: # B et C ferment l'onglet (pas de reconnexion) ; D : liaison coupee puis rouverte seule (resume), modele du rechargement
		p._want_open = false
		p._ws.close()
	d._ws.close()
	_expect(await _wait(func(): return not bool(room.seats[1]["taken"]), 8.0), "away : le siege de B doit etre libere apres le delai court")
	_expect(bool(room.seats[2]["taken"]), "away : C (fermeture sans pagehide) garde son siege jusqu'a --seat-grace")
	_expect(await _wait(func(): return d.connected, 5.0), "away : D doit se reconnecter (resume)")
	await get_tree().create_timer(3.5).timeout
	_expect(bool(room.seats[3]["taken"]) and int(room.seats[3]["conn"]) >= 0 and not bool(room.seats[3]["away"]), "away : D (resume dans le delai) garde son siege et perd la marque")
	server.away_grace_s = 10
	server.gc_interval_ms = 5000
	for n in [a, b, cc, d]:
		n.queue_free()

## N-B49 / N-B05 : un humain sans liaison depuis --abandon-grace en partie est declare parti (`left`) ; avant, `resume` le rend.
func _scenario_abandon() -> void:
	server.abandon_grace_s = 3
	var a := _client("Alice")
	if not _expect(await a.create_lobby(3, []), "abandon : create"):
		return
	var b := _client("Bob")
	var c := _client("Cara")
	_expect(await b.join_lobby(a.match_id, "Bob") and await c.join_lobby(a.match_id, "Cara"), "abandon : joins")
	a.start_match()
	_expect(await _wait(func(): return not a.current_G.is_empty() and not b.current_G.is_empty() and not c.current_G.is_empty(), 5.0), "abandon : la partie ne demarre pas")
	var room = server.get_room(a.match_id)
	var token := b.credentials
	var left: Array = []
	a.player_left.connect(func(seat, pname): left.append([seat, pname]))
	b._want_open = false # B ferme l'onglet sans `leave`
	b._ws.close()
	c._ws.close() # C perd sa liaison : reconnexion automatique en ~1 s, bien avant le delai
	_expect(await _wait(func(): return c.connected, 5.0), "abandon : C doit se reconnecter")
	_expect(await _wait(func(): return left.size() == 1, 8.0), "abandon : B absent plus que le delai doit etre signale parti")
	_expect(left == [[1, "Bob"]], "abandon : mauvais siege / nom %s" % str(left))
	_expect(bool(room.seats[1]["left"]) and bool(room.seats[1]["auto"]) and not bool(room.seats[2]["left"]), "abandon : seul B est parti (l'IA garde son siege)")
	var r := await _raw()
	r.send({"t": "resume", "code": a.match_id, "seat": 1, "token": token})
	_expect(await _wait(func(): return r.count("error") > 0, 3.0) and r.last("error").get("code", "") == "bad_token", "abandon : l'ancien jeton de B doit etre mort")
	server.abandon_grace_s = 120
	for n in [a, b, c, r]:
		n.queue_free()

## Revue : noms nettoyes comme les titres (U+061C, 2028/2029, 2060-2064, 00AD), hote parti d'une salle publique (le role passe), hote qui quitte
## (pas de `closed` pour lui, liaison et `_want_open` du client gardes).
func _scenario_host_public() -> void:
	_expect(Server._clean_name("Al" + char(0x61C) + char(0x2028) + char(0x2029) + char(0x2060) + char(0x2064) + char(0xAD) + "ice") == "Alice", "nom : points de code invisibles non retires")
	_expect(Server._clean_name(char(0x202E) + char(7)) == "Joueur", "nom : vide apres nettoyage -> Joueur")
	_expect(Server._sane_title("A" + char(0x61C) + char(0x2029) + char(0x2062) + char(0xAD) + "B") == "AB", "titre : U+061C / 2029 / 2062 / 00AD")
	server.seat_grace_s = 1
	server.gc_interval_ms = 100
	var host := await _create_raw({"name": "Hote" + char(0x2028) + "X", "players": 3, "sets": [], "public": true, "title": ""})
	var code: String = host.last("joined")["code"]
	var room = server.get_room(code)
	_expect(room.title == "HoteX's game" and room.seats[0]["name"] == "HoteX", "nom : titre par defaut et siege nettoyes : %s / %s" % [room.title, room.seats[0]["name"]])
	var guest := await _raw()
	guest.send({"t": "join", "code": code, "name": "Invite"})
	await _wait(func(): return guest.count("joined") > 0, 3.0)
	host.ws.close() # l'hote tombe sans `leave` : apres la grace, le role passe a l'invite connecte
	_expect(await _wait(func(): return room.host == 1, 6.0), "hote : le role doit passer a l'humain connecte")
	_expect(await _wait(func(): return guest.last("lobby").get("host", -1) == 1, 3.0), "hote : le lobby de l'invite doit annoncer le nouvel hote")
	guest.send({"t": "start"})
	_expect(await _wait(func(): return room.status == "running", 3.0), "hote : le nouvel hote doit pouvoir lancer")
	# l'hote qui quitte lui-meme sa salle publique : pas de `closed` pour lui, les autres sont prevenus
	var h2 := await _create_raw({"name": "Hote2", "players": 3, "sets": [], "public": true})
	var code2: String = h2.last("joined")["code"]
	var g2 := await _raw()
	g2.send({"t": "join", "code": code2, "name": "Invite2"})
	await _wait(func(): return g2.count("joined") > 0, 3.0)
	h2.send({"t": "leave"})
	# U-C29 : le role passe a l'humain connecte (APK : Photon designe un nouveau maitre), la salle reste ouverte
	_expect(await _wait(func(): return int(g2.last("lobby").get("host", -1)) == 1, 3.0), "hote : le role doit passer a l'invite quand l'hote quitte")
	await get_tree().create_timer(0.3).timeout
	_expect(g2.count("closed") == 0 and h2.count("closed") == 0 and server.get_room(code2) != null, "hote : la salle doit rester ouverte, sans `closed`")
	var g3 := await _raw() # un arrivant prend le siege 0 libre sans voler le role d'hote
	g3.send({"t": "join", "code": code2, "name": "Invite3"})
	await _wait(func(): return g3.count("joined") > 0, 3.0)
	_expect(g3.last("joined").get("seat", -1) == 0 and server.get_room(code2).host == 1 and g3.last("joined").get("host", true) == false, "hote : un arrivant au siege 0 ne doit pas devenir hote")
	g3.send({"t": "leave"})
	await _wait(func(): return server.get_room(code2).seats[0]["taken"] == false, 3.0)
	g2.send({"t": "leave"}) # l'hote reste seul : plus personne a qui passer le role, la salle se ferme
	_expect(await _wait(func(): return server.get_room(code2) == null, 3.0), "hote : la salle d'un hote seul qui quitte doit se fermer")
	# client : `closed` recu apres notre depart ne remet pas _want_open a zero
	var c := _client("Carol")
	if _expect(await c.create_lobby(2, [], 0, true, "Carol"), "hote : create_lobby public"):
		var pub: bool = c.public_room
		c.leave_match(pub)
		c.watch_rooms()
		c._on_message({"t": "closed", "code": "ZZZZ"})
		_expect(c._want_open, "client : `closed` apres notre depart ne doit pas couper la reconnexion automatique")
	server.seat_grace_s = 30
	server.gc_interval_ms = 5000
	for n in [host, guest, h2, g2, g3, c]:
		n.queue_free()
