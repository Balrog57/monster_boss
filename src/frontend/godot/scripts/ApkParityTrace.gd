extends RefCounted
## Rejoue une trace de l'ORACLE APK (tools/apk-oracle : DBMGame.dll 2.2.6 headless)
## dans le moteur GDScript (Match.gd) et enregistre, apres chaque step de
## l'oracle, une projection canonique de l'etat Godot. La comparaison se fait
## cote Node (tools/parity/apk.mjs) : ce fichier ne juge rien, il rejoue.
##
## Le harnais ne corrige AUCUNE regle. Il injecte seulement les conditions
## initiales (bosses, ordre des pioches) et transmet les choix de l'oracle sous
## forme de coups Godot. Un coup que Godot ne propose pas => evenement REFUS.
##
## Conventions :
##  - pid Godot = playerId oracle - 1 ; la projection ressort en playerId oracle.
##  - chaque carte porte "_oid" (id d'instance de l'oracle) pour la retrouver.
##  - les pioches oracle sont "sommet en premier" ; Godot pioche en pop_back, on
##    inverse donc les tableaux.
##  - Match._start_turn() est retenu (ApkMatch) jusqu'au step BeginningOfTurn de
##    l'oracle : Godot enchaine sinon directement la defausse d'ouverture et le
##    debut de tour.

## Match dont le demarrage de tour est differe (voir ci-dessus) et qui photographie l'etat
## aux deux points ou Godot enchaine plusieurs phases d'un coup : fin du BUILD (apres leurre,
## avant l'aventure) et debut de tour. Godot peut en effet derouler tout un tour dans un seul
## coup (ex. aucun heros dans les donjons) alors que l'oracle expose chaque phase.
class ApkMatch extends Match:
	var hold_start := true
	var held := false
	var snap: Callable = Callable()
	var snaps: Dictionary = {}

	func _start_turn() -> void:
		if hold_start:
			held = true
			return
		super._start_turn()
		_snap("turnstart")

	func _init_adventure_phase() -> void:
		_snap("bait")
		super._init_adventure_phase()

	func _snap(tag: String) -> void:
		if snap.is_valid():
			snaps["%s:%d" % [tag, maxi(0, int(G.get("turn", 0)) - 1)]] = snap.call()

	func release_start() -> void:
		hold_start = false
		if held:
			held = false
			_start_turn()


var run: ApkMatch
var inject := false
var events: Array = []
var proj: Dictionary = {}
var unmapped: Dictionary = {}
var stats := {"decisionsSkipped": 0, "readySkipped": 0, "forcedPass": 0, "autoResolved": 0, "injected": 0, "refus": 0}
var _tbl: Dictionary = {}
var _steps: Array = []
var _prev_players: Array = []


# --- construction de la partie ---------------------------------------------

func _index_cards() -> void:
	for kind in ["bosses", "rooms", "spells", "heroes"]:
		var m := {}
		for c in (CardDB.get(kind) as Array):
			m[str((c as Dictionary).get("id", ""))] = c
		_tbl[kind] = m


func _mk(code: String, oid: int, kind: String) -> Dictionary:
	var src: Dictionary = (_tbl[kind] as Dictionary).get(code, {})
	if src.is_empty():
		unmapped[code] = kind
		src = {"id": code, "name": "?" + code}
	var d: Dictionary = src.duplicate(true)
	d["_oid"] = oid
	match kind:
		"rooms":
			d["isRoom"] = true
		"spells":
			d["isSpell"] = true
		"heroes":
			# Meme convention que Match.new_match.
			var epic: bool = bool(d.get("epic", false))
			d["souls"] = 2 if epic else 1
			d["wounds"] = 2 if epic else 1
	return d


func _deck(list: Array, kind: String) -> Array:
	var out: Array = []
	for c in list:
		out.append(_mk(str((c as Dictionary)["card"]), int((c as Dictionary)["id"]), kind))
	out.reverse()
	return out


## Usage : Apk.new().replay(trace, inject_setup_rooms) (une instance par rejeu).
func replay(trace: Dictionary, inject_setup_rooms: bool) -> Dictionary:
	inject = inject_setup_rooms
	_index_cards()
	var initial: Dictionary = trace["initial"]
	var meta: Dictionary = trace.get("meta", {})
	var players := {}
	for b in (initial["bosses"] as Array):
		var bd: Dictionary = b
		var pid := int(bd["playerId"]) - 1
		players[pid] = {
			"id": pid, "boss": _mk(str(bd["card"]), int(bd["id"]), "bosses"),
			"dungeon": [], "hand": [], "souls": [], "wounds": [], "eliminated": false,
			"leveledUp": false, "buildsThisTurn": 0, "isAI": false, "entrance": [],
		}
	_steps = trace["steps"]
	# Pioches : celles de l'oracle APRES la distribution d'ouverture (AvoidMulliganCondition remelange le
	# paquet quand une main est mauvaise ; `initial` ne suffit alors plus). Repli sur `initial`.
	var orders: Dictionary = {}
	var opening_hands := {}
	for st in _steps:
		var sd: Dictionary = st
		if orders.is_empty() and sd.has("deckOrders"):
			orders = sd["deckOrders"]
		if str(sd["kind"]) == "decision" and str(sd["phase"]) == "Setup_a" and str((sd["detail"] as Dictionary)["decision"]) == "discard":
			opening_hands[int((sd["detail"] as Dictionary)["player"]) - 1] = (sd["detail"] as Dictionary)["options"]
	var from_deal: bool = orders.is_empty() or opening_hands.size() != players.size()
	if from_deal:
		orders = {"rooms": initial["deckRooms"], "spells": initial["deckSpells"], "heroes": initial["deckHeroes"]}
	run = ApkMatch.new()
	run.snap = project
	run.G = {
		"players": players, "bossPicks": [], "numPlayers": players.size(),
		"xpOrder": CardDB.order_by_xp(players),
		"decks": {
			"rooms": _deck(orders["rooms"], "rooms"),
			"spells": _deck(orders["spells"], "spells"),
			# Une seule pioche heros, dans l'ordre oracle (Godot a deux pioches : ordinaires puis epiques).
			"heroes": _deck(orders["heroes"], "heroes"), "epics": [],
			"roomDiscard": [], "spellDiscard": [], "heroDiscard": [],
		},
		"town": [], "turn": 0, "phase": CardDB.PHASE["SETUP"], "gameOver": null, "log": [], "autoAI": false,
		"stack": [], "stackPassed": {}, "pendingChoice": {}, "choiceQueue": [], "roboboQueue": [],
	}
	run.rng.seed = int(meta.get("seed", 1))
	seed(int(meta.get("seed", 1))) # randi()/randf() globaux du moteur (tirages « au hasard ») : rejeu reproductible
	if from_deal:
		run._deal_opening_hands()
	else:
		# Mains d'ouverture = ce que l'oracle a effectivement distribue (options de sa defausse d'ouverture).
		for pid in opening_hands.keys():
			var hand: Array = []
			for c in (opening_hands[pid] as Array):
				var code := str((c as Dictionary)["card"])
				var kind := "spells" if (_tbl["spells"] as Dictionary).has(code) else "rooms"
				hand.append(_mk(code, int((c as Dictionary)["id"]), kind))
			(run.G["players"][pid] as Dictionary)["hand"] = hand
		run._queue_next_opening_discard()

	proj["0"] = project()
	for i in _steps.size():
		var s: Dictionary = _steps[i]
		match str(s["kind"]):
			"phase":
				_on_phase(s)
			"action":
				_on_action(i, s)
			"decision":
				_on_decision(i, s)
		proj[str(int(s["seq"]))] = project()
		_prev_players = s["players"]
	var snaps: Dictionary = run.snaps
	run.free()
	return {"unmapped": unmapped.keys(), "events": events, "stats": stats, "proj": proj, "snaps": snaps}


# --- projection canonique (miroir de oracleProj dans apk.mjs) ----------------

func project() -> Dictionary:
	var G: Dictionary = run.G
	var ph := str(G.get("phase", ""))
	if run.hold_start:
		ph = "setup"
	if G.get("gameOver") != null:
		ph = "over"
	elif ph == "bait":
		ph = "adventure"
	var pl := {}
	for pid in (G["players"] as Dictionary).keys():
		var p: Dictionary = G["players"][pid]
		var hand: Array = []
		var sp: Array = []
		for c in (p.get("hand", []) as Array):
			if bool((c as Dictionary).get("isSpell", false)):
				sp.append(str((c as Dictionary).get("id", "")))
			else:
				hand.append(str((c as Dictionary).get("id", "")))
		hand.sort()
		sp.sort()
		# Godot : index 0 = entree ; oracle : slot 0 = fond. On inverse, piles sommet en premier.
		var dun: Array = []
		var pend: Array = []
		var d: Array = p.get("dungeon", [])
		for k in range(d.size() - 1, -1, -1):
			var stack: Array = d[k]
			if stack.is_empty():
				continue
			var codes: Array = []
			for j in range(stack.size() - 1, -1, -1):
				codes.append(str((stack[j] as Dictionary).get("id", "")))
			dun.append(codes)
			pend.append(bool((stack[stack.size() - 1] as Dictionary).get("faceDown", false)))
		var ent: Array = []
		for h in (p.get("entrance", []) as Array):
			ent.append(str((h as Dictionary).get("id", "")))
		ent.sort()
		pl[str(int(pid) + 1)] = {
			"souls": CardDB.total_souls(p), "wounds": CardDB.total_wounds(p),
			"hand": hand, "spells": sp, "dungeon": dun, "pending": pend, "entrance": ent,
		}
	var dk: Dictionary = G["decks"]
	var hero = null
	var adv: Dictionary = G.get("adventure", {})
	if not adv.is_empty() and adv.has("hero"):
		hero = {"card": str((adv["hero"] as Dictionary).get("id", "")), "hp": int(adv.get("hp", 0))}
	var town: Array = []
	for h in (G.get("town", []) as Array):
		town.append(str((h as Dictionary).get("id", "")))
	var winner = null
	if G.get("gameOver") != null:
		winner = int((G["gameOver"] as Dictionary).get("winner", -1)) + 1
	var active = null
	if ph == "build" or ph == "adventure":
		active = run.active_player() + 1
	return {
		"phase": ph, "turn": maxi(0, int(G.get("turn", 0)) - 1), "active": active,
		"town": town, "hero": hero, "winner": winner,
		"decks": {
			"heroes": (dk["heroes"] as Array).size() + (dk["epics"] as Array).size(),
			"rooms": (dk["rooms"] as Array).size(), "spells": (dk["spells"] as Array).size(),
			"discardRooms": (dk["roomDiscard"] as Array).size(), "discardSpells": (dk["spellDiscard"] as Array).size(),
		},
		"players": pl,
	}


# --- evenements --------------------------------------------------------------

func _legal_types(pid: int) -> Array:
	var out: Array = []
	for m in run.legal_moves(pid):
		var t := str((m as Dictionary).get("type", ""))
		if not out.has(t):
			out.append(t)
	return out.slice(0, 10)


func _refus(s: Dictionary, move: String, pid: int, reason: String) -> void:
	stats["refus"] += 1
	events.append({
		"type": "REFUS", "seq": int(s["seq"]), "phase": str(s["phase"]), "move": move, "player": pid + 1,
		"reason": reason, "legal": _legal_types(pid) if pid >= 0 and (run.G["players"] as Dictionary).has(pid) else [],
		"godotPhase": str(run.G.get("phase", "")), "godotActive": run.active_player() + 1,
	})


func _note(s: Dictionary, kind: String, msg: String) -> void:
	events.append({"type": kind, "seq": int(s["seq"]), "phase": str(s["phase"]), "msg": msg})


func _has_legal(pid: int, type: String) -> bool:
	for m in run.legal_moves(pid):
		if str((m as Dictionary).get("type", "")) == type:
			return true
	return false


## Applique le premier coup legal de ce type ; sinon REFUS.
func _apply_type(pid: int, type: String, s: Dictionary) -> bool:
	for m in run.legal_moves(pid):
		if str((m as Dictionary).get("type", "")) == type:
			if run.apply_move(pid, m):
				return true
			break
	_refus(s, type, pid, "aucun coup '%s' legal" % type)
	return false


func _apply_move(pid: int, move: Dictionary, s: Dictionary, label: String) -> bool:
	if run.apply_move(pid, move):
		return true
	_refus(s, label, pid, "coup refuse (absent de legal_moves) args=%s" % str(move.get("args", [])))
	return false


# --- recherche d'instances ---------------------------------------------------

func _hand_index(pid: int, oid: int) -> int:
	var hand: Array = (run.G["players"][pid] as Dictionary).get("hand", [])
	for i in hand.size():
		if int((hand[i] as Dictionary).get("_oid", -1)) == oid:
			return i
	return -1


func _stack_index(pid: int, oid: int) -> int:
	if not (run.G["players"] as Dictionary).has(pid):
		return -1
	var d: Array = (run.G["players"][pid] as Dictionary).get("dungeon", [])
	for i in d.size():
		for c in (d[i] as Array):
			if int((c as Dictionary).get("_oid", -1)) == oid:
				return i
	return -1


func _oids(chosen: Variant) -> Array:
	var out: Array = []
	if chosen is Array:
		for c in chosen:
			out.append(int((c as Dictionary)["id"]))
	return out


## Instances de cartes que designe une cible/option Godot (pour la rapprocher du choix oracle).
func _refs(t: Variant, owner_pid: int) -> Array:
	var out: Array = []
	if not (t is Dictionary):
		return out
	var td: Dictionary = t
	var G: Dictionary = run.G
	for key in ["card", "hero"]:
		if td.get(key) is Dictionary and (td[key] as Dictionary).has("_oid"):
			out.append(int((td[key] as Dictionary)["_oid"]))
	var tp := int(td.get("targetPlayerId", td.get("fromPid", owner_pid)))
	if td.has("targetPlayerId") and (G["players"] as Dictionary).has(tp):
		out.append(int(((G["players"][tp] as Dictionary).get("boss", {}) as Dictionary).get("_oid", -1)))
	if td.has("roomIndex") and (G["players"] as Dictionary).has(tp):
		var d: Array = (G["players"][tp] as Dictionary).get("dungeon", [])
		var ri := int(td["roomIndex"])
		if ri >= 0 and ri < d.size() and not (d[ri] as Array).is_empty():
			out.append(int(((d[ri] as Array).back() as Dictionary).get("_oid", -1)))
	var ti := int(td.get("townIndex", -1))
	var town: Array = G.get("town", [])
	if ti >= 0 and ti < town.size():
		out.append(int((town[ti] as Dictionary).get("_oid", -1)))
	if td.has("heroId"):
		for pid in (G["players"] as Dictionary).keys():
			for h in ((G["players"][pid] as Dictionary).get("entrance", []) as Array):
				if str((h as Dictionary).get("id", "")) == str(td["heroId"]):
					out.append(int((h as Dictionary).get("_oid", -1)))
	if td.has("handIndex") and (G["players"] as Dictionary).has(tp):
		var hh: Array = (G["players"][tp] as Dictionary).get("hand", [])
		# handIndices = option multi-cartes (ex. paire de Dracolich Lair) ; sinon handIndex seul.
		for hi in (td["handIndices"] if td.get("handIndices") is Array else [td["handIndex"]]):
			if int(hi) >= 0 and int(hi) < hh.size():
				out.append(int((hh[int(hi)] as Dictionary).get("_oid", -1)))
	return out


func _intersects(a: Array, b: Array) -> bool:
	for x in a:
		if b.has(x):
			return true
	return false


func _nested(i: int) -> Array:
	var s: Dictionary = _steps[i]
	var out: Array = []
	for k in range(i + 1, _steps.size()):
		var n: Dictionary = _steps[k]
		if int(n["depth"]) <= int(s["depth"]):
			break
		out.append(n)
	return out


# --- phases ------------------------------------------------------------------

## Godot enchaine parfois la fin d'un tour dans un seul coup (ex. aucun heros attire : pas
## d'aventure). Il est alors DEJA au tour suivant alors que l'oracle deroule encore le sien :
## on ne pilote plus rien tant que l'oracle n'a pas rattrape (sinon on jouerait dans le mauvais tour).
func _ahead(s: Dictionary) -> bool:
	if run.hold_start or str(s["phase"]) == "EndOfTurnPhase":
		return false
	return maxi(0, int(run.G.get("turn", 0)) - 1) > int(s["turn"])


func _on_phase(s: Dictionary) -> void:
	if _ahead(s):
		if str(s["phase"]) in ["AdventurePhase_c"]:
			_refus(s, "adventureNext", int(s["activePlayer"]) - 1 if s["activePlayer"] != null else -1, "Godot a deja termine ce tour (il est au tour %d, l'oracle au tour %d)" % [int(run.G.get("turn", 0)) - 1, int(s["turn"])])
		return
	match str(s["phase"]):
		"BeginningOfTurn":
			if run.hold_start:
				run.release_start()
		"BuildPhase_a":
			if s["activePlayer"] != null:
				_sync_build(int(s["activePlayer"]) - 1, s)
			elif str(s["nextPhase"]) == "BuildPhase_b":
				_sync_build(-1, s)
		"ExtraBuildPhase":
			_note(s, "NOTE", "ExtraBuildPhase : pas d'equivalent harnais")
		"AdventurePhase_b":
			# Plus de heros pour ce joueur : Godot attend son "pass".
			if s["activeHero"] == null and s["activePlayer"] != null:
				var ap := int(s["activePlayer"]) - 1
				if str(run.G.get("phase", "")) == "adventure" and run.active_player() == ap and _adventure_idle(ap):
					_auto_resolve(s)
					_apply_type(ap, "pass", s)
		"AdventurePhase_a":
			if s["activePlayer"] == null:
				_end_adventure(s)
		"AdventurePhase_c":
			_adv_step(s)


## BuildPhase_a : Godot attend un coup de chaque joueur ; l'oracle a "passe" pour ceux qui n'ont pas construit.
func _sync_build(target: int, s: Dictionary) -> void:
	for _k in 8:
		if str(run.G.get("phase", "")) != "build" or not (run.G.get("pendingChoice", {}) as Dictionary).is_empty():
			return
		var cur: int = run.active_player()
		if target >= 0 and cur == target:
			return
		# Godot a deja depasse la cible (l'oracle repete parfois le meme joueur apres une fenetre de sorts).
		var order: Array = run.G.get("buildOrder", [])
		if target >= 0 and order.find(target) >= 0 and order.find(target) <= order.find(cur):
			return
		stats["forcedPass"] += 1
		_note(s, "FORCED-PASS", "oracle a avance (cible joueur %d) ; Godot fait passer le joueur %d" % [target + 1, cur + 1])
		if not _apply_type(cur, "passBuild", s):
			return


func _adventure_idle(pid: int) -> bool:
	var p: Dictionary = run.G["players"][pid]
	return (p.get("entrance", []) as Array).is_empty() and (run.G.get("adventure", {}) as Dictionary).is_empty()


func _end_adventure(s: Dictionary) -> void:
	for _k in 8:
		if str(run.G.get("phase", "")) != "adventure" or run.G.get("gameOver") != null:
			return
		var cur: int = run.active_player()
		stats["forcedPass"] += 1
		_note(s, "FORCED-PASS", "fin d'aventure oracle ; Godot toujours en ADVENTURE (joueur %d)" % (cur + 1))
		_auto_resolve(s)
		if not _apply_type(cur, "pass", s):
			return


func _adv_step(s: Dictionary) -> void:
	var pid := int(s["activePlayer"]) - 1
	if str(run.G.get("phase", "")) != "adventure":
		_refus(s, "adventureNext", pid, "Godot n'est pas en ADVENTURE")
		return
	_auto_resolve(s)
	if _apply_type(pid, "adventureNext", s):
		_settle()


## Les fenetres de pause d'aventure de Godot (post-damage, pre-exit) correspondent aux
## fenetres de sorts de l'oracle : tout le monde passe, jusqu'au prochain pas de salle.
func _settle() -> void:
	for _k in 12:
		var adv: Dictionary = run.G.get("adventure", {})
		if adv.is_empty() or adv.get("pause") == null:
			return
		var did := false
		for pid in (run.G["players"] as Dictionary).keys():
			if _has_legal(int(pid), "pass"):
				run.apply_move(int(pid), {"type": "pass", "args": []})
				did = true
		if not did:
			return


## Un choix en attente gele Godot ; si l'oracle ne l'a pas resolu, on prend l'option 0 pour continuer.
func _auto_resolve(s: Dictionary) -> void:
	for _k in 6:
		var pc: Dictionary = run.G.get("pendingChoice", {})
		if pc.is_empty():
			return
		var pid := int(pc.get("playerId", -1))
		var legal: Array = run.legal_moves(pid)
		if legal.is_empty():
			return
		stats["autoResolved"] += 1
		_note(s, "AUTO-CHOICE", "choix Godot '%s' non resolu par l'oracle -> option %s" % [str(pc.get("type", "")), str((legal[0] as Dictionary).get("args", []))])
		if not run.apply_move(pid, legal[0]):
			return


# --- actions -----------------------------------------------------------------

func _on_action(i: int, s: Dictionary) -> void:
	var d: Dictionary = s["detail"]
	var act := str(d["action"])
	var pid := int(d["player"]) - 1
	if _ahead(s) and act != "spellBattleReady":
		_refus(s, act, pid, "Godot a deja termine ce tour (il est au tour %d, l'oracle au tour %d)" % [int(run.G.get("turn", 0)) - 1, int(s["turn"])])
		return
	match act:
		"buildRoom":
			_build(s, d, pid)
		"playRoomAbility":
			_ability(i, s, d, pid)
		"playSpell":
			_spell(i, s, d, pid)
		"spellBattleReady":
			# Godot n'a de "fenetre de sorts" que quand la pile n'est pas vide.
			# L'ordre des "pret" de l'oracle n'est pas celui des repondants de Godot (ancre = joueur actif) :
			# chaque "pret" fait passer le repondant que Godot attend. Le "pret" du lanceur n'a pas
			# d'equivalent (Godot le fait passer d'office) et tombe a vide.
			var responder: int = run.active_player()
			if not (run.G["stack"] as Array).is_empty() and _has_legal(responder, "pass"):
				_apply_type(responder, "pass", s)
			else:
				stats["readySkipped"] += 1
		_:
			_refus(s, act, pid, "action non portee par le harnais")


func _prev_slot_rooms(player_id: int, slot: int) -> Array:
	for p in _prev_players:
		if int((p as Dictionary)["playerId"]) == player_id:
			var dg: Array = (p as Dictionary)["dungeon"]
			if slot >= 0 and slot < dg.size():
				return (dg[slot] as Dictionary)["rooms"]
	return []


func _build(s: Dictionary, d: Dictionary, pid: int) -> void:
	var oid := int((d["room"] as Dictionary)["id"])
	var hi := _hand_index(pid, oid)
	var label := "buildRoom(%s)" % str((d["room"] as Dictionary)["card"])
	if hi < 0:
		_refus(s, label, pid, "carte absente de la main Godot")
		return
	# Premiere salle de l'oracle (Setup_b). Godot n'a pas cette etape : REFUS, ou injection explicite.
	if str(s["phase"]).begins_with("Setup") and inject:
		var p: Dictionary = run.G["players"][pid]
		var card: Dictionary = (p["hand"] as Array).pop_at(hi)
		card["faceDown"] = false
		(p["dungeon"] as Array).push_front([card])
		# Revelation de Setup_c avec la logique de Godot elle-meme (effet "quand tu construis").
		var choice = RoomAbilities.on_build_room(run.G, pid, card)
		if choice is Dictionary:
			RoomAbilities.enqueue_pending(run.G, choice)
		stats["injected"] += 1
		_note(s, "INJECT", "salle initiale %s posee par le harnais (pas de phase Setup_b dans Godot)%s" % [str(card.get("id", "?")), (" ; choix en attente '%s'" % str((choice as Dictionary).get("type", ""))) if choice is Dictionary else ""])
		return
	var args: Array = [hi]
	var under := _prev_slot_rooms(pid + 1, int(d["slot"]))
	if not under.is_empty():
		var gi := _stack_index(pid, int((under[0] as Dictionary)["id"]))
		if gi >= 0:
			args.append(gi)
	_auto_resolve(s)
	_apply_move(pid, {"type": "buildRoom", "args": args}, s, label)


func _ability(i: int, s: Dictionary, d: Dictionary, pid: int) -> void:
	var room: Dictionary = d["room"]
	var label := "activateRoom(%s)" % str(room["card"])
	var si := _stack_index(pid, int(room["id"]))
	if si < 0:
		_refus(s, label, pid, "salle absente du donjon Godot")
		return
	var args: Array = [si]
	var code := str(room["card"])
	if code == "BMA028" or code == "BMA032":
		var other := -1
		for n in _nested(i):
			var nd: Dictionary = (n as Dictionary)["detail"]
			if str(nd.get("decision", "")) == "resolveTarget":
				for oid in _oids(nd.get("chosen")):
					other = _stack_index(pid, int(oid))
					if other >= 0:
						break
			if other >= 0:
				break
		if other < 0:
			_refus(s, label, pid, "salle cible introuvable dans les decisions imbriquees de l'oracle")
			return
		args.append(other)
	_auto_resolve(s)
	_apply_move(pid, {"type": "activateRoom", "args": args}, s, label)


func _spell(i: int, s: Dictionary, d: Dictionary, pid: int) -> void:
	var oid := int((d["spell"] as Dictionary)["id"])
	var label := "playSpell(%s)" % str((d["spell"] as Dictionary)["card"])
	var hi := _hand_index(pid, oid)
	if hi < 0:
		_refus(s, label, pid, "sort absent de la main Godot")
		return
	var wanted: Array = []
	for n in _nested(i):
		var nd: Dictionary = (n as Dictionary)["detail"]
		if str(nd.get("decision", "")) == "resolveTarget":
			wanted.append_array(_oids(nd.get("chosen")))
	var cands: Array = []
	for m in run.legal_moves(pid):
		var md: Dictionary = m
		if str(md.get("type", "")) == "playSpell" and int((md["args"] as Array)[0]) == hi:
			cands.append(md)
	if cands.is_empty():
		_refus(s, label, pid, "aucun playSpell legal pour cette carte")
		return
	var pick: Dictionary = cands[0]
	for m in cands:
		var a: Array = (m as Dictionary)["args"]
		if a.size() > 1 and _intersects(_refs(a[1], pid), wanted):
			pick = m
			break
	if not run.apply_move(pid, pick):
		_refus(s, label, pid, "coup refuse")


# --- decisions ---------------------------------------------------------------

func _on_decision(_i: int, s: Dictionary) -> void:
	var d: Dictionary = s["detail"]
	var pid := int(d["player"]) - 1
	var kind := str(d["decision"])
	var G: Dictionary = run.G
	var pc: Dictionary = G.get("pendingChoice", {})
	if kind == "chooseDraw":
		_refus(s, "chooseDraw", pid, "Godot n'a pas de choix du type de pioche")
		return
	if pc.is_empty() or int(pc.get("playerId", -1)) != pid:
		stats["decisionsSkipped"] += 1
		return
	var chosen := _oids(d.get("chosen"))
	if str(pc.get("type", "")) == "opening-discard":
		if kind != "discard" or chosen.size() != 2:
			stats["decisionsSkipped"] += 1
			return
		var a := _hand_index(pid, int(chosen[0]))
		var b := _hand_index(pid, int(chosen[1]))
		if a < 0 or b < 0:
			_refus(s, "openingDiscard", pid, "cartes a defausser absentes de la main Godot")
			return
		_apply_move(pid, {"type": "openingDiscard", "args": [mini(a, b), maxi(a, b)]}, s, "openingDiscard")
		return
	var opts: Array = pc.get("options", [])
	var m := _match_options(opts, pid, chosen, d.get("chosen"))
	var pick: int = m["pick"]
	var ptype := str(pc.get("type", ""))
	if pick == -2:
		# Cible sans equivalent Godot (boss ou salle proprietaire, resolue implicitement) : on la consomme
		# et on garde le choix Godot en attente pour la decision oracle suivante.
		if not chosen.is_empty() and _implicit_target(chosen, d):
			stats["decisionsSkipped"] += 1
			_note(s, "DECISION-SKIPPED", "cible oracle %s (boss/salle proprietaire) sans equivalent ; choix Godot '%s' reste en attente" % [str(chosen), ptype])
			return
		_note(s, "CHOICE-UNMATCHED", "choix Godot '%s' : aucune option ne correspond a la decision oracle (%s) ; options=%s" % [ptype, str(chosen), str(opts.map(func(o): return _refs(o, pid)))])
		pick = -1 if (bool(pc.get("optional", false)) or opts.is_empty()) else 0
	elif not m["exact"] or not (m["ties"] as Array).is_empty():
		_note(s, "CHOICE-APPROX", "choix Godot '%s' : option %d retenue (%s)%s" % [ptype, pick, str(m["how"]), (" ; ex aequo " + str(m["ties"])) if not (m["ties"] as Array).is_empty() else ""])
	_apply_move(pid, {"type": "resolveChoice", "args": [pick]}, s, "resolveChoice(%s)" % ptype)


## Choisit l'option dont les cartes designees recouvrent le mieux le choix oracle :
## 1) meme ensemble d'instances (exact) 2) meme multiensemble de codes carte 3) plus grand recouvrement.
func _match_options(opts: Array, pid: int, chosen: Array, chosen_cards: Variant) -> Dictionary:
	var want := chosen.duplicate()
	want.sort()
	var codes: Array = []
	for c in (chosen_cards if chosen_cards is Array else []):
		codes.append(str((c as Dictionary)["card"]))
	codes.sort()
	var best := -2
	var best_score := 0
	var how := ""
	var ties: Array = []
	for k in opts.size():
		var refs: Array = []
		for r in _refs(opts[k], pid):
			if not refs.has(r):
				refs.append(r)
		var inter := 0
		for r in refs:
			if chosen.has(r):
				inter += 1
		var rs := refs.duplicate()
		rs.sort()
		var rc: Array = []
		for r in refs:
			rc.append(_code_of(int(r)))
		rc.sort()
		# tiers : 3 = ensemble exact, 2 = memes codes, 1 = recouvrement (moins d'extras d'abord)
		var tier := 3 if (inter > 0 and rs == want) else (2 if (not codes.is_empty() and rc == codes) else (1 if inter > 0 else 0))
		var score := tier * 1000 + inter * 10 - (refs.size() - inter)
		if tier == 0:
			continue
		if score > best_score:
			best = k
			best_score = score
			how = ["", "recouvrement partiel", "memes codes carte", "ensemble exact"][tier]
			ties = []
		elif score == best_score:
			ties.append(k)
	return {"pick": best, "exact": best_score >= 3000, "how": how, "ties": ties}


## Code carte d'une instance Godot (mains, donjons, ville, defausses), "" si introuvable.
func _code_of(oid: int) -> String:
	var G: Dictionary = run.G
	var piles: Array = [G.get("town", [])]
	for pid in (G["players"] as Dictionary).keys():
		var p: Dictionary = G["players"][pid]
		piles.append([p.get("boss", {})])
		piles.append(p.get("hand", []))
		piles.append(p.get("entrance", []))
		for st in (p.get("dungeon", []) as Array):
			piles.append(st)
	for k in (G.get("decks", {}) as Dictionary).values():
		if k is Array:
			piles.append(k)
	for pile in piles:
		for c in (pile as Array):
			if c is Dictionary and int((c as Dictionary).get("_oid", -1)) == oid:
				return str((c as Dictionary).get("id", ""))
	return ""


## Toutes les cibles designent un boss ou la salle proprietaire de la capacite.
func _implicit_target(chosen: Array, d: Dictionary) -> bool:
	var ok := {}
	if d.get("owner") is Dictionary:
		ok[int((d["owner"] as Dictionary)["id"])] = true
	for pid in (run.G["players"] as Dictionary).keys():
		ok[int(((run.G["players"][pid] as Dictionary).get("boss", {}) as Dictionary).get("_oid", -1))] = true
	for c in chosen:
		if not ok.has(int(c)):
			return false
	return true
