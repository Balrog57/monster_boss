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
		if str((G.get("pendingChoice", {}) as Dictionary).get("type", "")) == "draw-type":
			snap_after_draw = true # Haunted Library : la photo attend la pioche choisie (l'oracle a deja pioche au step BeginningOfTurn)
		else:
			_snap("turnstart")

	var snap_after_draw := false

	func _resolve_choice(pid: int, index: int) -> void:
		super._resolve_choice(pid, index)
		if snap_after_draw and str((G.get("pendingChoice", {}) as Dictionary).get("type", "")) != "draw-type":
			snap_after_draw = false
			_snap("turnstart")

	func _init_adventure_phase() -> void:
		_snap("bait")
		super._init_adventure_phase()

	func _snap(tag: String) -> void:
		if snap.is_valid():
			snaps["%s:%d" % [tag, maxi(0, int(G.get("turn", 0)) - 1)]] = snap.call()

	## HeroDiesInThisRoom : l'oracle met la transaction en file pendant ProccessActiveHero (l'ame est deja ajoutee) et ne
	## l'execute qu'au NextStep suivant. On retient donc le declencheur jusqu'au step oracle suivant (ou la fin de tour).
	var held_death: Array = []

	func _hero_died_trigger(pid: int, death_room: Dictionary) -> void:
		held_death.append([pid, death_room])

	func release_death() -> void:
		var q := held_death
		held_death = []
		for e in q:
			super._hero_died_trigger(int(e[0]), e[1])

	func _check_end_or_next_turn() -> void:
		release_death()
		super._check_end_or_next_turn()

	func release_start() -> void:
		hold_start = false
		if held:
			held = false
			_start_turn()


var run: ApkMatch
var events: Array = []
var proj: Dictionary = {}
var unmapped: Dictionary = {}
var stats := {"decisionsSkipped": 0, "readySkipped": 0, "forcedPass": 0, "autoResolved": 0, "refus": 0}
var _tbl: Dictionary = {}
var _steps: Array = []
var _prev_players: Array = []
var _prev_hero_dead := false # le heros actif du dernier step de PHASE oracle avait hp <= 0 (mort en attente de ProccessActiveHero)
var _deferred: Array = [] # decisions oracle d'un autre joueur que le choix Godot en attente (ordre de file different)
# Decisions oracle arrivees AVANT que Godot n'ouvre le choix correspondant (l'oracle les journalise pendant le NextStep
# qui declenche la capacite, Godot ouvre le choix au coup suivant) : rejouees des que le choix existe, 2 steps de phase au plus.
var _late: Array = []
var _losses: Array = [] # [oid, seq] des cartes quittant une main sans cause visible (voir _involuntary_losses)
var _held_pass: Dictionary = {} # derniere passe de Spell Battle retenue jusqu'au prochain step de phase (voir _on_action)
var _held: Dictionary = {} # activation de capacite de salle retenue jusqu'au prochain step de phase (voir _on_action)
var _extra_pid := -1 # joueur du dernier ExtraBuildPhase oracle (voir _close_forced)
## Salles a declencheur (mort de heros, revelation) : l'oracle journalise leurs decisions avant le step qui les execute.
const DEATH_TRIGGERS := ["BMA010", "BMA012", "BMA014", "BMA016", "BMA021", # HeroDiesInThisRoom
	"BMA011", "BMA019", "BMA022", "BMA033", "BMA034", "BMA036", "BMA037"] # WhenYouBuildThisRoom / WhenYouBuildAnotherRoom (revelation)


# --- construction de la partie ---------------------------------------------

func _index_cards() -> void:
	for kind in ["bosses", "rooms", "spells", "heroes", "items"]:
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
		"items":
			d["isItem"] = true
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


## Usage : Apk.new().replay(trace) (une instance par rejeu).
func replay(trace: Dictionary) -> Dictionary:
	_index_cards()
	var initial: Dictionary = trace["initial"]
	var meta: Dictionary = trace.get("meta", {})
	var players := {}
	# Ordre d'insertion = PlayerId croissant, comme Match.new_match (l'oracle liste les bosses par siege) : les effets sur
	# « tous les joueurs » (Jeopardy...) suivent InGamePlayersPriorized, soit l'ordre du dictionnaire cote Godot.
	var bosses: Array = (initial["bosses"] as Array).duplicate()
	bosses.sort_custom(func(a, b): return int((a as Dictionary)["playerId"]) < int((b as Dictionary)["playerId"]))
	for b in bosses:
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
			"items": _deck(orders.get("items", initial.get("deckItems", [])), "items"),
			"roomDiscard": [], "spellDiscard": [], "heroDiscard": [],
		},
		"town": [], "turn": 0, "phase": CardDB.PHASE["SETUP"], "gameOver": null, "log": [], "autoAI": false,
		"stack": [], "stackPassed": {}, "pendingChoice": {}, "choiceQueue": [], "roboboQueue": [], "itemQueue": [],
	}
	run.G["aiTargetsAllBosses"] = true # T.P.K. : l'IA de l'oracle designe tous les joueurs (SpellTargeting "tpk-player")
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

	_losses = _involuntary_losses()
	proj["0"] = project()
	for i in _steps.size():
		var s: Dictionary = _steps[i]
		run.release_death()
		# Un meme exemplaire peut etre perdu, recupere puis re-perdu : on ne propose que les pertes a venir (seq >= step courant), et proches
		# (l'execution suit son journal de decisions de 1 a 2 steps) : une perte lointaine ne doit pas etre jouee par un declencheur anterieur.
		run.G["forcedRandom"] = _losses.filter(func(e): return int((e as Array)[1]) >= int(s["seq"]) and int((e as Array)[1]) <= int(s["seq"]) + 4).map(func(e): return (e as Array)[0])
		if str(s["kind"]) == "phase":
			_release_held()
			_flush_late()
			_age_late()
		# Les decisions de revelation (BuildPhase_a puis _b) peuvent rester en attente a travers le NextStep de B.
		if str(s["kind"]) != "decision" and not (str(s["kind"]) == "phase" and str(s["phase"]) in ["BuildPhase_a", "BuildPhase_b"]):
			_deferred.clear()
		match str(s["kind"]):
			"phase":
				_on_phase(s)
			"action":
				_on_action(i, s)
			"decision":
				_on_decision(i, s)
		proj[str(int(s["seq"]))] = project()
		_dbg(s)
		_refresh_bait_snap(s)
		_prev_players = s["players"]
		if str(s["kind"]) == "phase": # (les decisions d'un NextStep precedent la ligne de phase : leur hp est deja celui du pas en cours)
			_prev_hero_dead = s["activeHero"] != null and int((s["activeHero"] as Dictionary).get("hp", 1)) <= 0
	var snaps: Dictionary = run.snaps
	run.free()
	return {"unmapped": unmapped.keys(), "events": events, "stats": stats, "proj": proj, "snaps": snaps}


## Diagnostic : `--dbg=a-b` (apres `--`) imprime l'etat Godot apres chaque step oracle de seq a..b.
func _dbg(s: Dictionary) -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--dbg="):
			var r := a.substr(6).split("-")
			var q := int(s["seq"])
			if q >= int(r[0]) and q <= int(r[1]):
				var G: Dictionary = run.G
				var adv: Dictionary = G.get("adventure", {})
				print("DBG %d %s %s ph=%s act=%d adv=%s eff=%s pc=%s ent=%s log=%s" % [q, s["kind"], str(s.get("detail", {})).substr(0, 90), G.get("phase"), run.active_player() + 1,
					str(adv.get("hp", "-")) + "@" + str(adv.get("roomIndex", "-")), _eff(), _pcs(), _ents(), str((G["log"] as Array).slice(-3))])


## Harnais : l'oracle a une fenetre de sorts APRES la derniere construction (BuildPhase_a, joueur nul)
## alors que Godot a deja enchaine sur l'aventure (photo « bait » prise avant). Au pas BaitPhase
## on rafraichit donc pioches/mains/sorts/donjon de la photo ; entree, ville, ames restent ceux du leurre.
func _refresh_bait_snap(s: Dictionary) -> void:
	if str(s["kind"]) != "phase" or str(s["phase"]) != "BaitPhase":
		return
	var cur: Dictionary = proj[str(int(s["seq"]))]
	var key := "bait:%d" % int(s["turn"]) # tour ORACLE (Godot peut etre en retard)
	if not run.snaps.has(key) or int(cur["turn"]) != int(s["turn"]): # Godot deja au tour suivant : sa photo « bait » fait foi
		return
	var snap: Dictionary = run.snaps[key]
	for f in ["rooms", "spells", "discardRooms", "discardSpells"]: # pas « heroes » : deja tires au leurre
		snap["decks"][f] = cur["decks"][f]
	for k in (snap["players"] as Dictionary).keys():
		for f in ["hand", "spells", "dungeon", "pending"]:
			snap["players"][k][f] = cur["players"][k][f]


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
			"souls": CardDB.total_souls(p, G), "wounds": CardDB.total_wounds(p),
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
			"items": (dk.get("items", []) as Array).size(),
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
		"godotChoice": str((run.G.get("pendingChoice", {}) as Dictionary).get("type", "")),
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
	# Option ciblant une SALLE du joueur (Robobo...) : le boss n'est pas la cible oracle (sinon une decision « BossOwner » le capte).
	if td.has("targetPlayerId") and not td.has("roomIndex") and (G["players"] as Dictionary).has(tp):
		out.append(int(((G["players"][tp] as Dictionary).get("boss", {}) as Dictionary).get("_oid", -1)))
	if td.has("soulIndex") and (G["players"] as Dictionary).has(tp): # Zombie Attack : ames/blessures -> heros du scorekeeping
		var pile: Array = (G["players"][tp] as Dictionary).get(str(td.get("pile", "souls")), [])
		var si := int(td["soulIndex"])
		if si >= 0 and si < pile.size() and (pile[si] as Dictionary).get("hero") is Dictionary:
			out.append(int(((pile[si] as Dictionary)["hero"] as Dictionary).get("_oid", -1)))
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
	# NextStep() de l'oracle sorti sans executer de phase (fin de duel de sorts) : rien a rejouer.
	if (s.get("detail", {}) as Dictionary).get("executed", true) == false:
		return
	if _ahead(s):
		if str(s["phase"]) in ["AdventurePhase_c"]:
			_refus(s, "adventureNext", int(s["activePlayer"]) - 1 if s["activePlayer"] != null else -1, "Godot a deja termine ce tour (il est au tour %d, l'oracle au tour %d)" % [int(run.G.get("turn", 0)) - 1, int(s["turn"])])
		return
	if str(s["phase"]) != "BuildPhase_a":
		_close_window(s)
	if str(s["phase"]) in ["Setup_c", "BeginningOfTurn", "BuildPhase_b", "BaitPhase"]:
		_close_forced(s)
	match str(s["phase"]):
		"Setup_c", "BeginningOfTurn":
			_close_setup(s)
			if str(s["phase"]) == "BeginningOfTurn" and run.hold_start:
				run.release_start()
		"BuildPhase_a":
			if s["activePlayer"] != null:
				_sync_build(int(s["activePlayer"]) - 1, s)
			elif str(s["nextPhase"]) == "BuildPhase_b":
				_sync_build(-1, s)
		"ExtraBuildPhase":
			_extra_pid = int(s["activePlayer"]) - 1 # Godot a ouvert le tour de construction supplementaire (forcedBuild) : refermer s'il n'est pas joue
			_note(s, "NOTE", "ExtraBuildPhase : tour supplementaire (forcedBuild cote Godot)")
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


## ExtraBuildPhase : l'oracle l'a refermee sans que son IA construise (pas d'action) : Godot attend encore le coup du joueur.
func _close_forced(s: Dictionary) -> void:
	var pid := _extra_pid
	_extra_pid = -1
	for _k in 4:
		if pid < 0 or run.active_player() != pid or not run.G.has("forcedBuild") or str(run.G.get("phase", "")) != "build" 				or not (run.G.get("pendingChoice", {}) as Dictionary).is_empty():
			return
		_note(s, "FORCED-PASS", "tour de construction supplementaire : l'oracle ne construit pas")
		if not _apply_type(run.active_player(), "passBuild", s):
			return


## Setup_b : l'oracle n'impose pas de salle initiale a chaque joueur (l'IA peut s'en abstenir) ; Godot attend un coup de chacun.
func _close_setup(s: Dictionary) -> void:
	for _k in 8:
		if not bool(run.G.get("setupBuild", false)):
			return
		var did := false
		for pid in (run.G["players"] as Dictionary).keys():
			if int(((run.G["players"][pid] as Dictionary).get("buildsThisTurn", 0))) == 0 and _has_legal(int(pid), "passBuild"):
				_note(s, "FORCED-PASS", "salle initiale : l'oracle n'en a pas construit pour le joueur %d" % (int(pid) + 1))
				did = _apply_type(int(pid), "passBuild", s)
				break
		if not did:
			return


## BuildPhase_a : Godot attend un coup de chaque joueur ; l'oracle a "passe" pour ceux qui n'ont pas construit.
func _sync_build(target: int, s: Dictionary) -> void:
	var turn0 := int(run.G.get("turn", 0))
	for _k in 8:
		if str(run.G.get("phase", "")) != "build" or not (run.G.get("pendingChoice", {}) as Dictionary).is_empty():
			return
		if run.G.has("buildWindow"): # fenetre de sorts apres la derniere construction : fermee par _close_window
			return
		# Tour de construction supplementaire de Godot (forcedBuild) ou tour suivant : c'est a l'oracle de piloter.
		if run.G.has("forcedBuild") or int(run.G.get("turn", 0)) != turn0:
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


## Fenetre de sorts avant la revelation (Match._open_build_window) : l'oracle l'a refermee (BuildPhase_b), tout le monde passe.
func _close_window(s: Dictionary) -> void:
	for _k in 12:
		if not run.G.has("buildWindow"):
			return
		_auto_resolve(s)
		var did := false
		for pid in (run.G["players"] as Dictionary).keys():
			if _has_legal(int(pid), "passBuild") and _apply_type(int(pid), "passBuild", s):
				did = true
				break
		if not did:
			return


func _adventure_idle(pid: int) -> bool:
	return not run._has_entrance_hero(pid) and (run.G.get("adventure", {}) as Dictionary).is_empty()


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
	# Trepidation (Boss.ForceSkipAdventure) : ProccessActiveHero « saute » le heros (pas d'entree, flag3) et sort en AdventurePhase_c
	# sans heros ; Godot ne l'a jamais fait entrer (_has_entrance_hero) : rien a rejouer, le `pass` vient au AdventurePhase_b suivant.
	if s["activeHero"] == null and _adventure_idle(pid):
		return
	# Heros tue par une capacite/un sort (hp <= 0) : Godot l'a deja retire et compte l'ame (Match._finish_hero_if_dead), l'oracle ne
	# traite sa mort qu'a ce NextStep (ProccessActiveHero) : rien a rejouer, sinon on ferait entrer le heros suivant avec un pas d'avance.
	if s["activeHero"] == null and _prev_hero_dead and (run.G.get("adventure", {}) as Dictionary).is_empty():
		return
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
			# L'oracle met la capacite en file (transaction) : elle ne s'execute qu'au NextStep suivant, apres d'eventuelles actions
			# de l'IA (ex. construire sur la salle qui va etre detruite). Godot l'applique tout de suite : on retient donc
			# l'activation, ses decisions, jusqu'au prochain step de phase.
			_release_held()
			_held = {"i": i, "s": s, "d": d, "pid": pid, "decs": []}
		"playSpell":
			_spell(i, s, d, pid)
		"spellBattleReady":
			# Godot n'a de "fenetre de sorts" que quand la pile n'est pas vide.
			# L'ordre des "pret" de l'oracle n'est pas celui des repondants de Godot (ancre = joueur actif) :
			# chaque "pret" fait passer le repondant que Godot attend. Le "pret" du lanceur n'a pas
			# d'equivalent (Godot le fait passer d'office) et tombe a vide.
			var responder: int = run.active_player()
			if not _held_pass.is_empty():
				stats["readySkipped"] += 1 # la passe qui resout le sort est deja retenue (le « pret » du lanceur arrive apres)
			elif not (run.G["stack"] as Array).is_empty() and _has_legal(responder, "pass"):
				# Sort joue puis salle posee dans la MEME action IA (liste precalculee, AIPlayerInteraction) : l'oracle execute le sort au
				# NextStep suivant, APRES la construction (sur l'ancienne main). On retient la derniere « passe » qui le resoudrait.
				if _is_last_responder(responder) and _build_follows(i):
					_held_pass = {"pid": responder, "s": s}
				else:
					_apply_type(responder, "pass", s)
			else:
				stats["readySkipped"] += 1
		_:
			_refus(s, act, pid, "action non portee par le harnais")


## Tirages « au hasard » de l'oracle (defausse aleatoire d'un sort...) : instances qui quittent une main sans
## cause visible dans la trace (ni carte jouee/construite par l'action, ni carte designee par une decision).
## Dans l'ordre de la trace ; Godot les force via G["forcedRandom"] (RoomAbilities._discard_random_spell_from).
func _involuntary_losses() -> Array:
	var out: Array = []
	for i in range(1, _steps.size()):
		var s: Dictionary = _steps[i]
		var keep := {}
		var d: Dictionary = s.get("detail", {}) if s.get("detail") is Dictionary else {}
		for key in ["room", "spell"]:
			if d.get(key) is Dictionary:
				keep[int((d[key] as Dictionary)["id"])] = true
		var group: Array = [s]
		group.append_array(_nested(i))
		for n in group:
			var nd = (n as Dictionary).get("detail")
			if nd is Dictionary and (nd as Dictionary).get("chosen") is Array:
				for c in (nd as Dictionary)["chosen"]:
					keep[int((c as Dictionary)["id"])] = true
		var now := {} # oid -> joueur qui la detient : une carte qui CHANGE de main sans cause visible est aussi tiree (Succubus Spa)
		for p in (s["players"] as Array):
			for k in ["hand", "spells"]:
				for c in ((p as Dictionary)[k] as Array):
					now[int((c as Dictionary)["id"])] = int((p as Dictionary)["playerId"])
		for p in ((_steps[i - 1] as Dictionary)["players"] as Array):
			for k in ["hand", "spells"]:
				for c in ((p as Dictionary)[k] as Array):
					var oid := int((c as Dictionary)["id"])
					if (not now.has(oid) or int(now[oid]) != int((p as Dictionary)["playerId"])) and not keep.has(oid):
						out.append([oid, int(s["seq"])])
	return out


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
	var args: Array = [hi]
	var under := _prev_slot_rooms(pid + 1, int(d["slot"]))
	if not under.is_empty():
		var gi := _stack_index(pid, int((under[0] as Dictionary)["id"]))
		if gi >= 0:
			args.append(gi)
	_auto_resolve(s)
	if _held_pass.is_empty():
		_apply_move(pid, {"type": "buildRoom", "args": args}, s, label)
		return
	# Le sort est encore « en file » cote oracle : on construit pendant que la pile Godot attend, puis la main passe au joueur suivant.
	var saved: Array = run.G["stack"]
	run.G["stack"] = []
	run.G["activePlayer"] = int(run.G.get("stackActivePlayer", pid))
	_apply_move(pid, {"type": "buildRoom", "args": args}, s, label)
	run.G["stack"] = saved
	run.G["stackActivePlayer"] = run.active_player()


## La « passe » retenue (voir _on_action) : l'oracle execute le sort en file au NextStep, avant les transactions de capacite.
func _release_held_pass() -> void:
	if _held_pass.is_empty():
		return
	var h := _held_pass
	_held_pass = {}
	var responder := int(h["pid"])
	if (run.G["stack"] as Array).is_empty():
		return
	run.G["activePlayer"] = responder
	if _has_legal(responder, "pass"):
		_apply_type(responder, "pass", h["s"])


func _is_last_responder(responder: int) -> bool:
	var passed: Dictionary = run.G.get("stackPassed", {})
	for p in run._stack_response_order():
		if int(p) != responder and not bool(passed.get(str(p), false)) and not bool(passed.get(p, false)):
			return false
	return true


## Une construction suit-elle (avant le prochain step de phase) et reste-t-il d'autres constructeurs apres elle ?
func _build_follows(i: int) -> bool:
	var order: Array = run.G.get("buildOrder", [])
	var stack: Array = run.G.get("stack", [])
	if str(run.G.get("phase", "")) != "build" or int(run.G.get("buildIndex", 0)) + 1 >= order.size() or stack.is_empty():
		return false
	var last: Dictionary = stack.back()
	# Motivation (BuildExtraRoom) : la 2e construction suit la resolution (autre appel IA), l'ordre naturel de Godot convient.
	if str((last.get("card", {}) as Dictionary).get("id", "")) == "BMA050":
		return false
	for k in range(i + 1, _steps.size()):
		var n: Dictionary = _steps[k]
		if str(n["kind"]) == "phase":
			return false
		var nd: Dictionary = n["detail"] if n.get("detail") is Dictionary else {}
		if str(n["kind"]) == "action" and str(nd.get("action", "")) == "buildRoom":
			return int(nd.get("player", 0)) - 1 == int(last.get("playerId", -1)) # le lanceur construit avec sa liste precalculee
	return false


## Applique l'activation retenue (puis ses decisions) : execution de la transaction cote oracle.
func _release_held() -> void:
	_release_held_pass()
	if _held.is_empty():
		return
	var h := _held
	_held = {}
	if not _stale_hand_targets(h):
		_ability(int(h["i"]), h["s"], h["d"], int(h["pid"]))
	for e in (h["decs"] as Array):
		_on_decision(int((e as Array)[0]), (e as Array)[1])


## Dracolich Lair / Witch's Kitchen : les cibles de la transaction sont designees a la mise en file, mais le build de l'IA
## (action precalculee avant l'activation, AIPlayerInteraction.InternalDoPlayerActions) peut les sortir de la main avant
## l'execution. Aucune annulation (GameBoard.RemovePendingTransactionsByTarget ne vise que defausse/destruction) :
## Effect.Execute defausse les cibles dans l'ordre et s'arrete a la premiere absente (DiscardFromHand leve), sans la suite.
## Ce n'est pas une regle de jeu (un humain attend la fin du Spell Battle) : emulation de l'ordre IA cote harnais.
func _stale_hand_targets(h: Dictionary) -> bool:
	var code := str(((h["d"] as Dictionary)["room"] as Dictionary)["card"])
	if code != "BMA013" and code != "BMA024":
		return false
	var pid := int(h["pid"])
	var oids: Array = []
	for e in (h["decs"] as Array):
		var nd: Dictionary = ((e as Array)[1] as Dictionary)["detail"]
		if int(nd.get("targetId", 0)) == 1:
			for c in _oids(nd.get("chosen")):
				if _code_of(int(c)) in ["", "BMA001"] or not (_tbl["rooms"] as Dictionary).has(_code_of(int(c))):
					continue
				oids.append(c)
	var missing := false
	for c in oids:
		missing = missing or _hand_index(pid, int(c)) < 0
	if not missing:
		return false
	var hand: Array = (run.G["players"][pid] as Dictionary)["hand"]
	for c in oids:
		var hi := _hand_index(pid, int(c))
		if hi < 0:
			break
		BossEngine.discard_room_to_pile(run.G["decks"], hand.pop_at(hi))
	_note(h["s"], "STALE-TARGET", "%s : cible sortie de la main avant l'execution (exception C# apres defausse partielle)" % code)
	return true


func _ability(i: int, s: Dictionary, d: Dictionary, pid: int) -> void:
	var room: Dictionary = d["room"]
	var label := "activateRoom(%s)" % str(room["card"])
	var si := _stack_index(pid, int(room["id"]))
	if si < 0:
		_refus(s, label, pid, "salle absente du donjon Godot")
		return
	var top = ((run.G["players"][pid] as Dictionary)["dungeon"] as Array)[si].back()
	if int((top as Dictionary).get("_oid", -1)) != int(room["id"]):
		# GameBoard.DestroyRoom / ability sur une salle recouverte entre-temps : exception C# loguee, rien ne s'execute.
		_note(s, "FIZZLE", "%s : la salle n'est plus au sommet de son slot (transaction oracle avortee)" % label)
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
	if run.apply_move(pid, {"type": "activateRoom", "args": args}):
		return
	# Activation retenue (voir _on_action) : l'IA oracle a construit entre-temps et Godot a deja passe la main (activation
	# reservee au joueur actif). La transaction oracle s'execute quand meme : on appelle la capacite directement.
	if str(run.G.get("phase", "")) == "build" and RoomAbilities.activate_room_ability(run.G, pid, si, int(args[1]) if args.size() > 1 else -1) == null:
		_note(s, "LATE-ACTIVATE", "%s appliquee hors du tour de construction Godot (transaction oracle en file)" % label)
		return
	_refus(s, label, pid, "coup refuse (absent de legal_moves) args=%s" % str(args))


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
	if str((d["spell"] as Dictionary)["card"]) == "KSA013" and wanted.size() > 1:
		wanted = [wanted[0]] # AbilityCalculator.CheckKSA013 : tous les boss par PlayerId ; SetTarget ne retient que le premier
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

## L'oracle decide dans l'ordre des sieges (Players), alors que ses EFFETS s'executent par PlayerId (GameBoard.
## EnqueueAbilityTransaction) comme la file de choix Godot : une decision d'un autre joueur que le choix en attente
## est gardee jusqu'a ce que Godot ouvre le choix de ce joueur.
func _on_decision(i: int, s: Dictionary) -> void:
	_on_decision_inner(i, s)
	_flush_late()


func _on_decision_inner(i: int, s: Dictionary) -> void:
	if not _held.is_empty() and int(((s["detail"] as Dictionary).get("owner", {}) as Dictionary).get("id", -1)) == int(((_held["d"] as Dictionary)["room"] as Dictionary)["id"]):
		(_held["decs"] as Array).append([i, s])
		return
	_on_decision_now(i, s)
	for _k in 12:
		var pc: Dictionary = run.G.get("pendingChoice", {})
		var hit := -1
		for j in _deferred.size():
			if not pc.is_empty() and int(((_deferred[j] as Dictionary)["detail"] as Dictionary)["player"]) - 1 == int(pc.get("playerId", -1)):
				hit = j
				break
		if hit < 0:
			return
		_on_decision_now(i, _deferred.pop_at(hit))


func _on_decision_now(_i: int, s: Dictionary, age := -1) -> void:
	if not bool(s.get("spellBattle", false)):
		_close_window(s) # decision hors Spell Battle = la revelation a commence : la fenetre de sorts est close
	var d: Dictionary = s["detail"]
	var pid := int(d["player"]) - 1
	var kind := str(d["decision"])
	var G: Dictionary = run.G
	# Goblin Armory / Dizzygas Hallway : passifs de degats (Boss.GetPassiveDamage cree une transaction a chaque calcul de degats et
	# la resout : l'IA « decide » une cible a chaque fois). Aucun choix de joueur : ne jamais les rapprocher d'un choix Godot ouvert.
	if str((d.get("owner", {}) as Dictionary).get("card", "")) in ["BMA015", "BMA029"]:
		return
	var pc: Dictionary = G.get("pendingChoice", {})
	if kind == "chooseDraw":
		# BMA023 : la decision oracle precede le step BeginningOfTurn (Godot n'a pas encore ouvert son choix) -> retenue (_late).
		if str(pc.get("type", "")) != "draw-type" or int(pc.get("playerId", -1)) != pid:
			if age < 2:
				_late.append({"s": s, "age": maxi(age, 0)})
			else:
				_refus(s, "chooseDraw", pid, "aucun choix de pioche Godot ouvert pour ce joueur")
			return
		_apply_move(pid, {"type": "resolveChoice", "args": [0 if bool(d.get("drawRoom", true)) else 1]}, s, "resolveChoice(draw-type)")
		return
	if pc.is_empty() or int(pc.get("playerId", -1)) != pid:
		stats["decisionsSkipped"] += 1
		if kind == "resolveTarget" and DEATH_TRIGGERS.has(str((d.get("owner", {}) as Dictionary).get("card", ""))):
			# Declencheur (mort de heros / revelation) d'un AUTRE joueur que celui du choix ouvert : retenu au-dela des steps de phase
			# (la revelation de Setup_c ouvre plusieurs choix en file, la decision oracle de l'un peut preceder le step qui les ouvre).
			_late.append({"s": s, "age": 0})
		elif not pc.is_empty():
			_deferred.append(s)
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
	if str(pc.get("type", "")) == "rearrange-dungeon" and str((d.get("owner", {}) as Dictionary).get("card", "")) == "KSA002" and kind == "resolveTarget" and int(d.get("targetId", 0)) == 1:
		_rearrange(pid, chosen, s) # KSA002 : une decision oracle = liste ordonnee de salles ; Godot : un choix par etape
		return
	# Le choix Godot ouvert appartient a une AUTRE carte (« bossName » = nom d'une salle/boss different de celui du proprietaire de
	# la decision) : deux capacites en file (Monstrous Monument + King Croak...) peuvent viser la meme carte ; Godot ouvre ses choix dans
	# un autre ordre que l'oracle. La decision attend donc le choix de sa carte (_late) au lieu de resoudre celui-ci.
	var owner_name := _card_name(str((d.get("owner", {}) as Dictionary).get("card", "")))
	var pc_name := str(pc.get("bossName", ""))
	if kind == "resolveTarget" and owner_name != "" and pc_name != "" and pc_name != owner_name and _is_card_name(pc_name):
		stats["decisionsSkipped"] += 1
		if age < 2 and not chosen.is_empty():
			_late.append({"s": s, "age": maxi(age, 0)})
		return
	var opts: Array = pc.get("options", [])
	# Cible implicite (salle proprietaire / boss) qu'aucune option ne designe par instance : ne pas la rapprocher
	# d'une AUTRE copie du meme code (ex. Dark Altar vs un 2e BMA009 en defausse).
	if not chosen.is_empty() and _implicit_target(chosen, d):
		var direct := false
		for o in opts:
			for r in _refs(o, pid):
				direct = direct or chosen.has(r)
		if not direct and str(pc.get("bossName", "")) in ["Mimic Vault", "Open Grave"] and int(d.get("targetId", 0)) == 1:
			# AI APK : cible carte/heros remplie par un boss (Mimic Vault : CheckBMA036 ; Open Grave : TriggerCalculator renvoie des cibles
			# deja calculees pour la meme carte, InternalObtainCalculatedTarget) -> Run() : cibles mal resolues, « Apply ability aborted ».
			# Rien ne s'execute et Ability.IsEffectApplied reste faux : OncePerTurn permet une 2e activation ce tour.
			_abort_trigger(s, d, pid, str(pc.get("bossName", "")))
			return
		if not direct:
			stats["decisionsSkipped"] += 1
			return
	var m := _match_options(opts, pid, chosen, d.get("chosen"))
	if Array(OS.get_cmdline_user_args()).any(func(a): return a.begins_with("--dbg=")):
		print("DBGM seq=%d chosen=%s m=%s pc=%s" % [int(s["seq"]), str(chosen), str(m), _pcs()])
	var pick: int = m["pick"]
	var ptype := str(pc.get("type", ""))
	if pick == -2:
		# L'IA oracle a designe une carte qui n'est meme pas une option (Mimic Vault : un SORT pour HeroInTown) : meme abandon.
		if str(pc.get("bossName", "")) in ["Mimic Vault", "Open Grave"] and int(d.get("targetId", 0)) == 1 and not chosen.is_empty() and not _implicit_target(chosen, d):
			_abort_trigger(s, d, pid, str(pc.get("bossName", "")))
			return
		# Cible sans equivalent Godot (boss ou salle proprietaire, resolue implicitement) : on la consomme
		# et on garde le choix Godot en attente pour la decision oracle suivante.
		if not chosen.is_empty() and _implicit_target(chosen, d):
			stats["decisionsSkipped"] += 1
			_note(s, "DECISION-SKIPPED", "cible oracle %s (boss/salle proprietaire) sans equivalent ; choix Godot '%s' reste en attente" % [str(chosen), ptype])
			return
		# L'oracle decide dans l'ordre de MISE EN FILE des transactions, Godot ouvre ses choix dans l'ordre d'EXECUTION (inverse pour
		# un meme joueur) : cette decision vise sans doute un choix que Godot n'a pas encore ouvert. On la retient (2 steps de phase).
		if age < 2 and not chosen.is_empty():
			_late.append({"s": s, "age": maxi(age, 0)})
			return
		_note(s, "CHOICE-UNMATCHED", "choix Godot '%s' : aucune option ne correspond a la decision oracle (%s) ; options=%s" % [ptype, str(chosen), str(opts.map(func(o): return _refs(o, pid)))])
		if opts.is_empty() or bool(pc.get("optional", false)):
			pick = -1
		else:
			# Decision oracle sans option correspondante : l'IA de l'APK designe parfois une carte hors des cibles valides (p.ex. un boss
			# pour un HeroInTown) ; AbilityTransaction « Apply ability aborted » -> la capacite n'a aucun effet.
			run._resolve_choice(pid, -1)
			return
	elif not m["exact"] or not (m["ties"] as Array).is_empty():
		_note(s, "CHOICE-APPROX", "choix Godot '%s' : option %d retenue (%s)%s" % [ptype, pick, str(m["how"]), (" ; ex aequo " + str(m["ties"])) if not (m["ties"] as Array).is_empty() else ""])
	_apply_move(pid, {"type": "resolveChoice", "args": [pick]}, s, "resolveChoice(%s)" % ptype)
	# Xyzax : une seule decision oracle designe 2 cartes ; Godot pose un 2e choix « recover-card » pour la suivante.
	var pc2: Dictionary = G.get("pendingChoice", {})
	if ptype == "recover-card" and chosen.size() > 1 and str(pc2.get("type", "")) == "recover-card" and int(pc2.get("playerId", -1)) == pid:
		var m2 := _match_options(pc2.get("options", []), pid, chosen, d.get("chosen"))
		if int(m2["pick"]) >= 0:
			_apply_move(pid, {"type": "resolveChoice", "args": [int(m2["pick"])]}, s, "resolveChoice(recover-card)")


## KSA002 Hellcow : `chosen` = salles dans l'ordre des slots (Dungeon[0] = fond). Etape « dungeon » : le joueur qui possede la 1re salle.
func _rearrange(pid: int, chosen: Array, s: Dictionary) -> void:
	for oid in chosen:
		var pc: Dictionary = run.G.get("pendingChoice", {})
		if pc.is_empty() or str(pc.get("type", "")) != "rearrange-dungeon":
			return
		var pick := -1
		var opts: Array = pc.get("options", [])
		for k in opts.size():
			var o: Dictionary = opts[k]
			if str(pc.get("step", "")) == "dungeon":
				if _stack_index(int(o["targetPlayerId"]), int(oid)) >= 0:
					pick = k
			elif int((o["card"] as Dictionary).get("_oid", -1)) == int(oid):
				pick = k
		if pick < 0:
			_note(s, "CHOICE-UNMATCHED", "Hellcow : salle oracle %d absente des options Godot" % int(oid))
			return
		if str(pc.get("step", "")) == "dungeon":
			_apply_move(pid, {"type": "resolveChoice", "args": [pick]}, s, "resolveChoice(rearrange-dungeon)")
			# l'etape « dungeon » ne consomme pas la salle : on la redonne a l'etape « order »
		_apply_move_order(pid, int(oid), s)


func _apply_move_order(pid: int, oid: int, s: Dictionary) -> void:
	var pc: Dictionary = run.G.get("pendingChoice", {})
	if pc.is_empty() or str(pc.get("type", "")) != "rearrange-dungeon" or str(pc.get("step", "")) != "order":
		return
	var opts: Array = pc.get("options", [])
	for k in opts.size():
		if int(((opts[k] as Dictionary)["card"] as Dictionary).get("_oid", -1)) == oid:
			_apply_move(pid, {"type": "resolveChoice", "args": [k]}, s, "resolveChoice(rearrange-order)")
			return


func _card_name(code: String) -> String:
	for kind in ["rooms", "bosses", "spells"]:
		if (_tbl[kind] as Dictionary).has(code):
			return str(((_tbl[kind] as Dictionary)[code] as Dictionary).get("name", ""))
	return ""


func _is_card_name(name: String) -> bool:
	for kind in ["rooms", "bosses"]:
		for c in (_tbl[kind] as Dictionary).values():
			if str((c as Dictionary).get("name", "")) == name:
				return true
	return false


## Transaction avortee cote oracle (cibles mal resolues -> Run() : « Apply ability aborted ») : rien ne s'execute, la capacite OncePerTurn
## reste utilisable ce tour (Ability.IsEffectApplied faux). On ferme le choix Godot sans effet.
func _abort_trigger(s: Dictionary, d: Dictionary, pid: int, boss_name: String) -> void:
	_note(s, "ABORTED", "%s : l'oracle a designe une cible invalide (boss/carte hors options), capacite avortee" % boss_name)
	var oi := _stack_index(pid, int((d.get("owner", {}) as Dictionary).get("id", -1)))
	if oi >= 0:
		(((run.G["players"][pid] as Dictionary)["dungeon"] as Array)[oi].back() as Dictionary).erase("usedThisTurn")
	run._resolve_choice(pid, -1)


## Rejoue les decisions en retard des qu'un choix Godot du bon joueur est ouvert.
func _flush_late() -> void:
	for _k in 6:
		var pc: Dictionary = run.G.get("pendingChoice", {})
		if pc.is_empty() or _late.is_empty():
			return
		var key := str(pc)
		for e in _late.duplicate():
			if int((((e as Dictionary)["s"] as Dictionary)["detail"] as Dictionary)["player"]) - 1 != int(pc.get("playerId", -1)):
				continue
			_late.erase(e)
			_on_decision_now(0, e["s"], int((e as Dictionary)["age"]))
			if str(run.G.get("pendingChoice", {})) != key:
				break # le choix a ete resolu : le suivant (autre type d'options) peut convenir a une autre decision retenue
		if str(run.G.get("pendingChoice", {})) == key:
			return


func _age_late() -> void:
	for e in _late:
		(e as Dictionary)["age"] += 1
	_late = _late.filter(func(e): return int((e as Dictionary)["age"]) < 2)


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


func _eff() -> String:
	var out := {}
	for k in (run.G.get("effects", {}) as Dictionary):
		var v = run.G["effects"][k]
		if (v is Array and not (v as Array).is_empty()) or (v is bool and v):
			out[k] = v
	return JSON.stringify(out)


func _pcs() -> String:
	var pc: Dictionary = run.G.get("pendingChoice", {})
	if pc.is_empty():
		return "-"
	var o: Array = []
	for x in (pc.get("options", []) as Array):
		var c = (x as Dictionary).get("card", (x as Dictionary).get("hero", {}))
		o.append("%s#%s" % [str((c as Dictionary).get("id", "?")) if c is Dictionary else "?", str((c as Dictionary).get("_oid", "?")) if c is Dictionary else "?"])
	return "%s p%d %s" % [str(pc.get("type", "")), int(pc.get("playerId", -1)) + 1, str(o)]


func _ents() -> String:
	var out := []
	for pid in (run.G["players"] as Dictionary):
		out.append("%d:%s" % [int(pid) + 1, ",".join(((run.G["players"][pid] as Dictionary).get("entrance", []) as Array).map(func(h): return str((h as Dictionary).get("id", ""))))])
	return " ".join(out)
