extends RefCounted
## Rejoue une trace de l'ORACLE APK (tools/apk-oracle : DBMGame.dll 2.2.6 headless)
## dans le moteur GDScript (Match.gd) et enregistre, apres chaque step de
## l'oracle, une projection canonique de l'etat Godot. La comparaison se fait
## par tools/parity/apk.py : ce fichier ne juge rien, il rejoue.
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
var stats := {"decisionsSkipped": 0, "readySkipped": 0, "forcedPass": 0, "autoResolved": 0, "refus": 0, "passiveSkipped": 0, "spellTargetUnmatched": 0, "skippedBy": {}}
var _skip_key: Dictionary = {} # seq -> classe de la derniere ignorance (pour compter `replayed`)
var _skip_seqs: Dictionary = {} # classe -> {seq: true} (une decision retenue puis re-tentee est comptee plusieurs fois dans `n`)


## Action oracle dont la decision `s` est imbriquee (depth superieur) : « playSpell », « playRoomAbility »... ; « - » = decision de
## declencheur / de phase (depth egal, aucune action parente).
func _parent_action(s: Dictionary) -> String:
	for k in range(_steps.size()):
		if int((_steps[k] as Dictionary)["seq"]) != int(s["seq"]):
			continue
		for j in range(k - 1, -1, -1):
			var p: Dictionary = _steps[j]
			if int(p["depth"]) < int(s["depth"]):
				var pd: Dictionary = p["detail"] if p.get("detail") is Dictionary else {}
				return str(pd.get("action", p["kind"]))
		break
	return "-"


## Plafond d'exemples par classe : 3, ou `-- --skip-ex=N` pour un diagnostic detaille (tous les cas d'une classe).
func _skip_ex() -> int:
	for a in OS.get_cmdline_user_args():
		if str(a).begins_with("--skip-ex="):
			return int(str(a).substr(10))
	return 3


## Compte une decision oracle ignoree (total `decisionsSkipped` + ventilation `skippedBy`, diagnostic seulement : ne change pas le rejeu).
## Cle = « site:decision:tTargetId » ; garde par classe : n, distinct (seq differents), replayed (retenues puis rejouees), cards (« carte@action parente »), ex (3 exemples).
func _skip(site: String, s: Dictionary) -> void:
	var d: Dictionary = s["detail"]
	# BMA020 Monster's Ballroom : degats passifs, decisions de Boss.GetPassiveDamage (comme BMA015/029) : comptees a part.
	if str((d.get("owner", {}) as Dictionary).get("card", "")) == "BMA020":
		stats["passiveSkipped"] += 1
		return
	stats["decisionsSkipped"] += 1
	var key := "%s:%s%s" % [site, str(d["decision"]), (":t%d" % int(d["targetId"])) if d.has("targetId") else ""]
	var by: Dictionary = stats["skippedBy"]
	if not by.has(key):
		by[key] = {"n": 0, "distinct": 0, "replayed": 0, "cards": {}, "ex": []}
	var c: Dictionary = by[key]
	c["n"] += 1
	var card := str((d.get("owner", {}) as Dictionary).get("card", "-"))
	var ck := "%s@%s" % [card, _parent_action(s)]
	(c["cards"] as Dictionary)[ck] = int((c["cards"] as Dictionary).get(ck, 0)) + 1
	var seen: Dictionary = _skip_seqs.get_or_add(key, {})
	seen[int(s["seq"])] = true
	c["distinct"] = seen.size()
	_skip_key[int(s["seq"])] = key
	if (c["ex"] as Array).size() < _skip_ex() and not (c["ex"] as Array).any(func(e): return int(e["seq"]) == int(s["seq"])):
		(c["ex"] as Array).append({"seq": int(s["seq"]), "phase": str(s["phase"]), "player": int(d["player"]), "card": ck, "chosen": _oids(d.get("chosen"))})


var _tbl: Dictionary = {}
var _steps: Array = []
var _prev_players: Array = []
var _prev_hero_dead := false # le heros actif du dernier step de PHASE oracle avait hp <= 0 (mort en attente de ProccessActiveHero)
var _deferred: Array = [] # decisions oracle d'un autre joueur que le choix Godot en attente (ordre de file different)
# Decisions oracle arrivees AVANT que Godot n'ouvre le choix correspondant (l'oracle les journalise pendant le NextStep
# qui declenche la capacite, Godot ouvre le choix au coup suivant) : rejouees des que le choix existe, 2 steps de phase au plus.
var _late: Array = []
var _losses: Array = [] # [oid, seq] des cartes quittant une main sans cause visible (voir _involuntary_losses)
var _ach: Array = [] # trace["abilityChoices"]
var _ach_pos := 0
var _held_pass: Dictionary = {} # derniere passe de Spell Battle retenue jusqu'au prochain step de phase (voir _on_action)
var _held: Dictionary = {} # activation de capacite de salle retenue jusqu'au prochain step de phase (voir _on_action)
var _idle_pid := -1 # joueur sans heros dont le « pass » est differe (voir _pass_idle)
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
	_ai_init()
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
	_ach = trace.get("abilityChoices", []) # choix d'IA oracle (UseAbility) : ensemble des capacites eligibles + tirage, voir _ai_measure_choice
	_ach_pos = 0
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
	run.G["aiMayCancel"] = true # Seducia : l'IA de l'oracle peut ne rien designer (Match.legal_moves, choix `aiCancel`)
	run.G["aiTargetsAnyRoomType"] = true # Giant Size : l'IA de l'oracle peut viser une salle Trap (AbilityCalculator.CheckBMA040And047, sans revalidation)
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
		_ai_flush_choices(int(s["seq"]))
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
				_on_phase(s, i)
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
	_ai_flush_choices(1 << 60)
	var snaps: Dictionary = run.snaps
	run.free()
	var out := {"unmapped": unmapped.keys(), "events": events, "stats": stats, "proj": proj, "snaps": snaps}
	if _ai_on:
		out["aiAgreement"] = {"types": _ai, "by": _ai_by, "unavailable": _ai_unav, "mutations": _ai_mut}
	return out


## Diagnostic : `--dbg=a-b` (apres `--`) imprime l'etat Godot apres chaque step oracle de seq a..b.
func _dbg(s: Dictionary) -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--dbg="):
			var r := a.substr(6).split("-")
			var q := int(s["seq"])
			if q >= int(r[0]) and q <= int(r[1]):
				var G: Dictionary = run.G
				var adv: Dictionary = G.get("adventure", {})
				print("DBG %d %s %s ph=%s act=%d%s adv=%s eff=%s pc=%s ent=%s log=%s" % [q, s["kind"], str(s.get("detail", {})).substr(0, 90), G.get("phase"), run.active_player() + 1,
					(" forced=" + str(G["forcedBuild"]) if G.has("forcedBuild") else "") + (" window" if G.has("buildWindow") else ""),
					str(adv.get("hp", "-")) + "@" + str(adv.get("roomIndex", "-")), _eff(), _pcs(), _ents(), str((G["log"] as Array).slice(-_dbg_log()))])


## `--dbglog=N` : nombre de lignes de journal Godot affichees par `--dbg` (3 par defaut).
func _dbg_log() -> int:
	for a in OS.get_cmdline_user_args():
		if str(a).begins_with("--dbglog="):
			return int(str(a).substr(9))
	return 3


## Harnais : l'oracle a une fenetre de sorts APRES la derniere construction (BuildPhase_a, joueur nul)
## alors que Godot a deja enchaine sur l'aventure (photo « bait » prise avant). Au pas BaitPhase
## on rafraichit donc pioches/mains/sorts/donjon/ames/entree de la photo (une capacite de la fenetre, Zombie Prison, agit AVANT le
## leurre cote oracle) ; la ville reste celle du leurre.
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
		for f in ["hand", "spells", "dungeon", "pending", "souls", "wounds", "entrance"]: # ames / entree : Zombie Prison de la fenetre agit AVANT le leurre cote oracle
			snap["players"][k][f] = cur["players"][k][f]


# --- projection canonique (miroir de oracle_proj dans tools/parity/apk.py) ----------------

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
		var sk: String = _skip_key.get(int(s["seq"]), "") # decision retenue (_late / _deferred) puis finalement rejouee
		if sk != "":
			stats["skippedBy"][sk]["replayed"] += 1
			_skip_key.erase(int(s["seq"]))
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


func _on_phase(s: Dictionary, i := 0) -> void:
	# NextStep() de l'oracle sorti sans executer de phase (fin de duel de sorts) : rien a rejouer.
	if (s.get("detail", {}) as Dictionary).get("executed", true) == false:
		return
	if _ahead(s):
		if str(s["phase"]) in ["AdventurePhase_c"]:
			_refus(s, "adventureNext", int(s["activePlayer"]) - 1 if s["activePlayer"] != null else -1, "Godot a deja termine ce tour (il est au tour %d, l'oracle au tour %d)" % [int(run.G.get("turn", 0)) - 1, int(s["turn"])])
		return
	_pass_idle(s)
	if str(s["phase"]) != "BuildPhase_a":
		_close_window(s)
	if str(s["phase"]) in ["Setup_c", "BeginningOfTurn", "BuildPhase_b", "BaitPhase"]:
		_close_forced(s, i)
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
			# Plus de heros pour ce joueur : Godot attend son "pass". L'oracle le garde actif jusqu'au NextStep suivant (AdventurePhase_a) :
			# un SORT joue entre-temps depend du joueur actif (Trepidation de la cible, s35-p2@233 : Godot ne doit pas avoir deja passe la main) ;
			# le « pass » est alors differe (_pass_idle). Sans sort dans la fenetre, on passe tout de suite : un heros ajoute par une capacite
			# (Zombie Prison, s24-p4@266) ne doit pas entrer, ChooseNextActiveHero (AdventurePhase_b) ayant deja designe personne.
			if s["activeHero"] == null and s["activePlayer"] != null:
				var ap := int(s["activePlayer"]) - 1
				if _window_has_spell(i):
					_idle_pid = ap
				elif str(run.G.get("phase", "")) == "adventure" and run.active_player() == ap and _adventure_idle(ap):
					_auto_resolve(s)
					_apply_type(ap, "pass", s)
		"AdventurePhase_a":
			if s["activePlayer"] == null:
				_end_adventure(s)
		"AdventurePhase_c":
			_adv_step(s)


## Un sort est-il joue avant le prochain NextStep execute (fenetre de sorts du joueur actif de l'oracle) ?
func _window_has_spell(i: int) -> bool:
	for k in range(i + 1, _steps.size()):
		var n: Dictionary = _steps[k]
		var nd: Dictionary = n["detail"] if n.get("detail") is Dictionary else {}
		if str(n["kind"]) == "phase" and nd.get("executed", true) != false:
			return false
		if str(n["kind"]) == "action" and str(nd.get("action", "")) == "playSpell":
			return true
	return false


## Joueur sans heros (AdventurePhase_b) dont le « pass » attend le prochain step de phase execute.
func _pass_idle(s: Dictionary) -> void:
	var ap := _idle_pid
	_idle_pid = -1
	if ap >= 0 and str(run.G.get("phase", "")) == "adventure" and run.active_player() == ap and _adventure_idle(ap):
		_auto_resolve(s)
		_apply_type(ap, "pass", s)


## ExtraBuildPhase : l'oracle l'a refermee sans que son IA construise (pas d'action) : Godot attend encore le coup du joueur.
func _close_forced(s: Dictionary, i: int) -> void:
	var pid := _extra_pid
	_extra_pid = -1
	# Un autre ExtraBuildPhase du meme joueur suit tout de suite (Construction Zone puis niveau King Croak, s38-p3@98-99) : le tour supplementaire
	# ouvert par Godot est celui-la, pas a refermer.
	if i + 1 < _steps.size() and str((_steps[i + 1] as Dictionary)["phase"]) == "ExtraBuildPhase" and int((_steps[i + 1] as Dictionary)["activePlayer"]) - 1 == pid:
		return
	for _k in 4:
		if pid < 0 or run.active_player() != pid or not run.G.has("forcedBuild") or str(run.G.get("phase", "")) != "build" 				or not (run.G.get("pendingChoice", {}) as Dictionary).is_empty():
			return
		_note(s, "FORCED-PASS", "tour de construction supplementaire : l'oracle ne construit pas")
		_ai_pass(run.active_player(), "extra", s)
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
				_ai_pass(int(pid), "setup", s)
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
		_ai_pass(cur, "build", s)
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
			_build(i, s, d, pid)
		"playRoomAbility":
			# L'oracle met la capacite en file (transaction) : elle ne s'execute qu'au NextStep suivant, apres d'eventuelles actions
			# de l'IA (ex. construire sur la salle qui va etre detruite). Godot l'applique tout de suite : on retient donc
			# l'activation, ses decisions, jusqu'au prochain step de phase.
			_release_held()
			# All-Seeing Eye (BMA025) repond a un sort : sa transaction passe DEVANT celle du sort (GameBoard.EnqueueAbilityTransaction : joueur du tour -> tete ;
			# OnAbilityApplyRequest : un Counterspell se replace avant sa cible). La pile Godot rend cet ordre : on l'applique donc sur le champ, pendant que le sort
			# attend encore (les « pret » suivants ne la resolvent qu'ensuite), sans retenue.
			if str((d["room"] as Dictionary)["card"]) == "BMA025" and not (run.G["stack"] as Array).is_empty():
				_ability(i, s, d, pid)
				return
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
					if not _ready_is_own(i):
						_ai_pass(responder, "respond", s, int((s["detail"] as Dictionary)["player"]) - 1)
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
		# Un NextStep execute les transactions mises en file (et decidees) pendant la fenetre precedente : les cartes designees par ces decisions
		# (Draculord : vol d'une carte, s31-p2@185 -> perte vue au step 188) ne sont pas des tirages au hasard.
		if str(s["kind"]) == "phase":
			var seen := 0
			for k in range(i - 1, -1, -1):
				var pk: Dictionary = _steps[k]
				if str(pk["kind"]) == "phase":
					seen += 1
					if seen >= 2:
						break
				elif str(pk["kind"]) == "decision" and (pk["detail"] as Dictionary).get("chosen") is Array:
					for c in (pk["detail"] as Dictionary)["chosen"]:
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


func _build(i: int, s: Dictionary, d: Dictionary, pid: int) -> void:
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
	_release_covered(pid, oid, under)
	if _held_pass.is_empty():
		_build_and_done(pid, args, s, label, i)
		return
	# Le sort est encore « en file » cote oracle : on construit pendant que la pile Godot attend, puis la main passe au joueur suivant.
	var saved: Array = run.G["stack"]
	run.G["stack"] = []
	run.G["activePlayer"] = int(run.G.get("stackActivePlayer", pid))
	_build_and_done(pid, args, s, label, i)
	run.G["stack"] = saved
	run.G["stackActivePlayer"] = run.active_player()


## L'IA de l'oracle termine seule son tour de construction ; cote Godot un siege non-IA le termine par DONE (passBuild) apres sa pose.
func _build_and_done(pid: int, args: Array, s: Dictionary, label: String, i: int) -> void:
	_ai_build(pid, args, s)
	if _apply_move(pid, {"type": "buildRoom", "args": args}, s, label) and not run._can_build_again(pid) and not _builds_again(i, pid):
		_apply_type(pid, "passBuild", s)


## Le meme joueur construit-il encore avant le prochain vrai NextStep (phase executee) ? L'IA de l'oracle joue Motivation (BMA050) APRES sa 1re
## construction puis pose la 2e dans le meme tour (s30-p4@305-314) : Godot attend alors le DONE de ce siege, on ne passe pas encore.
func _builds_again(i: int, pid: int) -> bool:
	for k in range(i + 1, _steps.size()):
		var n: Dictionary = _steps[k]
		var nd: Dictionary = n["detail"] if n.get("detail") is Dictionary else {}
		if str(n["kind"]) == "phase" and nd.get("executed", true) != false:
			return false
		if str(n["kind"]) == "action" and str(nd.get("action", "")) == "buildRoom":
			return int(nd.get("player", 0)) - 1 == pid
	return false


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
func _release_held(with_pass := true) -> void:
	if with_pass:
		_release_held_pass()
	if _held.is_empty():
		return
	var h := _held
	_held = {}
	if not _stale_hand_targets(h):
		_ability(int(h["i"]), h["s"], h["d"], int(h["pid"]))
	for e in (h["decs"] as Array):
		_on_decision(int((e as Array)[0]), (e as Array)[1])


## Capacite NON destructive (Dracolich Lair, Witch's Kitchen) activee puis recouverte par la construction suivante de la meme action IA : l'oracle
## l'execute quand meme (Ability.DoEffect ne regarde pas la position de la salle ; seules les capacites « Destroy this room » levent a l'execution,
## GameBoard.DestroyRoom : Dungeon.First(slot.TopRoom == room), donc FIZZLE dans _ability). Godot n'applique une capacite que sur la salle du dessus : on la
## joue donc juste AVANT la construction qui la recouvre (s36-p4@357-364), sauf si la carte construite est une de ses cibles en main (cas _stale_hand_targets).
func _release_covered(pid: int, built_oid: int, under: Array) -> void:
	if _held.is_empty() or int(_held["pid"]) != pid:
		return
	var room: Dictionary = (_held["d"] as Dictionary)["room"]
	if not str(room["card"]) in ["BMA013", "BMA024"]:
		return
	if not under.any(func(r): return int((r as Dictionary)["id"]) == int(room["id"])):
		return
	for e in (_held["decs"] as Array):
		if _oids(((e as Array)[1] as Dictionary)["detail"].get("chosen")).has(built_oid):
			return
	_release_held(false)


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
	var hit := false
	for m in cands:
		var a: Array = (m as Dictionary)["args"]
		if a.size() > 1 and _intersects(_refs(a[1], pid), wanted):
			pick = m
			hit = true
			break
	if cands.size() > 1 and not wanted.is_empty() and not hit: # diagnostic : cible oracle absente des variantes de playSpell, cands[0] joue
		stats["spellTargetUnmatched"] += 1
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
	var d: Dictionary = s["detail"]
	var pid := int(d["player"]) - 1
	var kind := str(d["decision"])
	var G: Dictionary = run.G
	# Goblin Armory / Dizzygas Hallway : passifs de degats (Boss.GetPassiveDamage cree une transaction a chaque calcul de degats et
	# la resout : l'IA « decide » une cible a chaque fois). Aucun choix de joueur : ne jamais les rapprocher d'un choix Godot ouvert, et
	# ce ne sont pas des decisions de revelation (la fenetre de sorts avant la revelation reste ouverte : Jackpot Stash la precede, s23-p2@330).
	if str((d.get("owner", {}) as Dictionary).get("card", "")) in ["BMA015", "BMA029"]:
		return
	if not bool(s.get("spellBattle", false)):
		_close_window(s) # decision hors Spell Battle = la revelation a commence : la fenetre de sorts est close
	var pc: Dictionary = G.get("pendingChoice", {})
	if kind == "chooseDraw":
		# BMA023 : la decision oracle precede le step BeginningOfTurn (Godot n'a pas encore ouvert son choix) -> retenue (_late).
		if str(pc.get("type", "")) != "draw-type" or int(pc.get("playerId", -1)) != pid:
			if age < 2:
				_late.append({"s": s, "age": maxi(age, 0)})
			else:
				_refus(s, "chooseDraw", pid, "aucun choix de pioche Godot ouvert pour ce joueur")
			return
		_ai_choice(pid, pc, 0 if bool(d.get("drawRoom", true)) else 1, s, "draw")
		_apply_move(pid, {"type": "resolveChoice", "args": [0 if bool(d.get("drawRoom", true)) else 1]}, s, "resolveChoice(draw-type)")
		return
	if pc.is_empty() or int(pc.get("playerId", -1)) != pid:
		var late := kind == "resolveTarget" and DEATH_TRIGGERS.has(str((d.get("owner", {}) as Dictionary).get("card", "")))
		_skip("%s-%s" % ["noChoice" if pc.is_empty() else "otherPlayer", "late" if late else ("dropped" if pc.is_empty() else "deferred")], s)
		if late:
			# Declencheur (mort de heros / revelation) d'un AUTRE joueur que celui du choix ouvert : retenu au-dela des steps de phase
			# (la revelation de Setup_c ouvre plusieurs choix en file, la decision oracle de l'un peut preceder le step qui les ouvre).
			_late.append({"s": s, "age": 0})
		elif not pc.is_empty():
			_deferred.append(s)
		return
	var chosen := _oids(d.get("chosen"))
	if str(pc.get("type", "")) == "opening-discard":
		if kind != "discard" or chosen.size() != 2:
			_skip("openingDiscardMismatch", s)
			return
		var a := _hand_index(pid, int(chosen[0]))
		var b := _hand_index(pid, int(chosen[1]))
		if a < 0 or b < 0:
			_refus(s, "openingDiscard", pid, "cartes a defausser absentes de la main Godot")
			return
		_ai_discard(pid, a, b, s)
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
		_skip("otherCardChoice", s)
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
			_skip("implicitTargetNoOption", s)
			return
	var m := _match_options(opts, pid, chosen, d.get("chosen"))
	if Array(OS.get_cmdline_user_args()).any(func(a): return a.begins_with("--dbg=")):
		print("DBGM seq=%d chosen=%s m=%s pc=%s" % [int(s["seq"]), str(chosen), str(m), _pcs()])
	var pick: int = m["pick"]
	var ptype := str(pc.get("type", ""))
	if pick == -2:
		# Deux transactions ont designe le MEME heros a leur mise en file (Seducia niveau 2 + Mimic Vault, s26-p2@124-127 ; Gorgona + Mimic Vault, s36-p3@186-190) : la 1re execute
		# RemoveHeroFromGame(hero), qui retire aussi les transactions en file ciblant ce heros (GameBoard.cs:743 RemovePendingTransactionsByTarget).
		# La 2e est donc abandonnee ; Godot ouvre son choix apres la 1re et propose un autre heros.
		if ptype in ["pick-hero", "kill-hero"] and not chosen.is_empty() and chosen.all(func(c): return _in_entrance(int(c))):
			_note(s, "CANCELED", "%s : heros %s deja place a l'entree par une transaction precedente (RemovePendingTransactionsByTarget), capacite abandonnee" % [str(pc.get("bossName", "")), str(chosen)])
			run._resolve_choice(pid, -1)
			return
		# L'IA oracle a designe une carte qui n'est meme pas une option (Mimic Vault : un SORT pour HeroInTown) : meme abandon.
		if str(pc.get("bossName", "")) in ["Mimic Vault", "Open Grave"] and int(d.get("targetId", 0)) == 1 and not chosen.is_empty() and not _implicit_target(chosen, d):
			_abort_trigger(s, d, pid, str(pc.get("bossName", "")))
			return
		# Cible sans equivalent Godot (boss ou salle proprietaire, resolue implicitement) : on la consomme
		# et on garde le choix Godot en attente pour la decision oracle suivante.
		if not chosen.is_empty() and _implicit_target(chosen, d):
			_skip("implicitTargetConsumed", s)
			_note(s, "DECISION-SKIPPED", "cible oracle %s (boss/salle proprietaire) sans equivalent ; choix Godot '%s' reste en attente" % [str(chosen), ptype])
			return
		# L'oracle decide dans l'ordre de MISE EN FILE des transactions, Godot ouvre ses choix dans l'ordre d'EXECUTION (inverse pour
		# un meme joueur) : cette decision vise sans doute un choix que Godot n'a pas encore ouvert. On la retient (2 steps de phase).
		if age < 2 and not chosen.is_empty():
			_late.append({"s": s, "age": maxi(age, 0)})
			return
		_note(s, "CHOICE-UNMATCHED", "choix Godot '%s' : aucune option ne correspond a la decision oracle (%s) ; options=%s" % [ptype, str(chosen), str(opts.map(func(o): return _refs(o, pid)))])
		if opts.is_empty() or bool(pc.get("optional", false)) or bool(pc.get("aiCancel", false)):
			pick = -1
		else:
			# Decision oracle sans option correspondante : l'IA de l'APK designe parfois une carte hors des cibles valides (p.ex. un boss
			# pour un HeroInTown) ; AbilityTransaction « Apply ability aborted » -> la capacite n'a aucun effet.
			run._resolve_choice(pid, -1)
			return
	elif not m["exact"] or not (m["ties"] as Array).is_empty():
		_note(s, "CHOICE-APPROX", "choix Godot '%s' : option %d retenue (%s)%s" % [ptype, pick, str(m["how"]), (" ; ex aequo " + str(m["ties"])) if not (m["ties"] as Array).is_empty() else ""])
	if pick >= 0 or (pick == -1 and chosen.is_empty() and (bool(pc.get("optional", false)) or bool(pc.get("aiCancel", false)))): # l'oracle ne designe rien d'un choix facultatif : `targetPass`
		_ai_choice(pid, pc, pick, s, "target")
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


## Le heros `oid` est-il a l'entree d'un donjon ?
func _in_entrance(oid: int) -> bool:
	for pid in (run.G["players"] as Dictionary).keys():
		for h in ((run.G["players"][pid] as Dictionary).get("entrance", []) as Array):
			if int((h as Dictionary).get("_oid", -1)) == oid:
				return true
	return false


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
	return "%s[%s] p%d %s" % [str(pc.get("type", "")), str(pc.get("bossName", "")), int(pc.get("playerId", -1)) + 1, str(o)]


func _ents() -> String:
	var out := []
	for pid in (run.G["players"] as Dictionary):
		out.append("%d:%s" % [int(pid) + 1, ",".join(((run.G["players"][pid] as Dictionary).get("entrance", []) as Array).map(func(h): return str((h as Dictionary).get("id", ""))))])
	return " ".join(out)


# --- accord de l'IA Godot avec l'IA oracle (lot 1.2, `--ai-agreement`) ------------------------------------
## A chaque decision de l'IA oracle (TracingAI), on demande a l'IA Godot (AI.gd) ce qu'elle jouerait sur le MEME etat Godot, juste avant que
## le harnais applique le coup oracle, et on compare. Mesure pure : `legal_moves`, `AI.score_move`, `AI.pick_move` et
## `AI.select_opening_discards` ne modifient rien (garde `hash(G)` avant/apres : `mutations` doit rester 0) et le rejeu ne depend jamais du resultat.
## Sans `--ai-agreement`, aucun de ces appels n'a lieu.
##
## Accord par type (candidats = coups legaux Godot ; departage de l'IA Godot = premier meilleur score, comme AI.pick_move) :
##  - build       : le meilleur buildRoom de Godot est la meme CARTE (code) ET le meme emplacement (pile recouverte, ou « nouvelle pile »).
##  - buildCard   : la meme carte (code), emplacement ignore (une autre copie du meme code est equivalente).
##  - buildSlot   : etant donnee la carte de l'oracle, Godot choisit le meme emplacement parmi les coups de cette carte.
##  - discard     : defausse d'ouverture (AI.select_opening_discards) : meme multiensemble de 2 codes.
##  - sorts / capacites de salle : l'oracle tire UNIFORMEMENT parmi ses capacites eligibles (StatisticAI.SelectAbilityToUse), on compare donc les ENSEMBLES, a
##                  chaque appel d'UseAbility de la trace (cle `abilityChoices`, voir _ai_measure_choice) : usableSet, eligibleSet:*, chosenInSet:*,
##                  spellTarget / activateTarget (+ Shuffle). Les anciens types `spell` / `activate` (meilleur score) n'ont plus de sens.
##  - target      : option d'un choix ouvert (resolveChoice) : meme indice, ou option equivalente (memes codes carte, meme joueur proprietaire,
##                  meme pile : une autre copie du meme code compte comme accord). Cible DETERMINISTE (TriggerCalculator, ou cibles preregles de la capacite tiree).
##  - targetShuffle : meme mesure quand la cible vient d'un tirage (`Shuffle()` : cle `shuffled` de la decision oracle, `shuf` de la reponse Godot) : accord ~ 1/n.
##  - targetPass  : l'oracle ne designe rien d'un choix facultatif (Seducia) : accord si Godot ne designe rien non plus.
##                  `shuffleOracleOnly:*` (cle `by`) = tirage de l'oracle que Godot ne fait pas (diagnostic, doit rester vide).
##  - draw        : type de pioche (Haunted Library) : meme pile.
##  - pass        : le joueur n'a rien joue (passBuild/pass du harnais) : AI.pick_move ne propose aucun coup actif (null ou passBuild/pass/adventureNext).
## `forced` = un seul candidat distinct (accord automatique) ; `nt`/`ntAgree` = decisions a >= 2 candidats distincts. `ties` = desaccords ou
## le coup oracle a le MEME score que le choix Godot (Godot est indifferent, il prend le premier).
const AI_NOTHING := ["passBuild", "pass", "adventureNext", "resolveNextHero", "(none)"]
var _ai_on := false
var _ai_ex := 6
var _ai: Dictionary = {}
var _ai_by: Dictionary = {}
var _ai_unav: Dictionary = {}
var _ai_mut := 0


func _ai_init() -> void:
	var args := OS.get_cmdline_user_args()
	_ai_on = args.has("--ai-agreement")
	AI._sel.clear() # abilitySelected / listes memorisees d'une partie precedente
	AI._memo.clear()
	ApkAI.copy_trap_bug = args.has("--ai-copy-trap-bug") # diagnostic : l'oracle joue Giant Size sur une salle Trap (CheckBMA040And047, l.844-847)
	for a in args:
		if str(a).begins_with("--ai-ex="):
			_ai_ex = int(str(a).substr(8))


func _ai_unavail(type: String) -> void:
	_ai_unav[type] = int(_ai_unav.get(type, 0)) + 1


## Verifie que la requete n'a pas touche l'etat Godot.
func _ai_guard(h: int) -> void:
	if hash(run.G) != h:
		_ai_mut += 1


func _ai_id(c: Variant) -> String:
	return str((c as Dictionary).get("id", "?")) if c is Dictionary else "?"


func _ai_hand_id(pid: int, idx: int) -> String:
	var hand: Array = (run.G["players"][pid] as Dictionary).get("hand", [])
	return _ai_id(hand[idx]) if idx >= 0 and idx < hand.size() else "?"


func _ai_room_id(pid: int, ri: int) -> String:
	var d: Array = (run.G["players"][pid] as Dictionary).get("dungeon", [])
	return _ai_id(BossEngine.active_room(d[ri])) if ri >= 0 and ri < d.size() else "?"


func _ai_score(pid: int, mv: Variant) -> float:
	return 0.0 if str((mv as Dictionary).get("type", "")) == "(none)" else AI.score_move(run, pid, mv)


func _ai_slot(a: Array) -> int:
	return int(a[1]) if a.size() > 1 and a[1] != null else -1


## Cle d'equivalence d'un coup de la decision « capacite » (une meme carte = un meme coup, quelle que soit la copie ou la cible).
func _ai_mv_key(pid: int, mv: Variant) -> String:
	var m: Dictionary = mv
	var t := str(m.get("type", ""))
	var a: Array = m.get("args", [])
	match t:
		"playSpell":
			return "S:" + _ai_hand_id(pid, int(a[0]))
		"activateRoom":
			return "R:" + _ai_room_id(pid, int(a[0]))
	return "-" if AI_NOTHING.has(t) else t


func _ai_strip(v: Variant) -> Variant:
	if v is Dictionary:
		var o := {}
		for k in (v as Dictionary):
			if str(k) != "_oid":
				o[k] = _ai_strip(v[k])
		return o
	if v is Array:
		return (v as Array).map(func(x): return _ai_strip(x))
	return v


## Cle d'une option de choix : codes des cartes designees + joueur proprietaire + pile (deux copies d'un meme code = meme cle).
func _ai_opt_key(opt: Variant, pid: int) -> String:
	if not (opt is Dictionary):
		return str(opt)
	var od: Dictionary = opt
	var codes: Array = []
	for r in _refs(od, pid):
		var c := _code_of(int(r))
		if c != "":
			codes.append(c)
	codes.sort()
	var owner := str(od.get("targetPlayerId", od.get("fromPid", "")))
	var pile := str(od.get("pile", ""))
	if codes.is_empty() and owner == "" and pile == "":
		return str(_ai_strip(od)).substr(0, 80)
	return "%s|p%s|%s" % [",".join(codes), owner, pile]


func _ai_mv_str(pid: int, mv: Variant) -> String:
	if mv == null:
		return "(aucun coup)"
	var m: Dictionary = mv
	var t := str(m.get("type", ""))
	var a: Array = m.get("args", [])
	match t:
		"buildRoom":
			return "buildRoom %s %s" % [_ai_hand_id(pid, int(a[0])), ("sur la pile %d" % _ai_slot(a)) if _ai_slot(a) >= 0 else "nouvelle pile"]
		"playSpell":
			return "playSpell %s%s" % [_ai_hand_id(pid, int(a[0])), (" cible=" + str(a[1]).substr(0, 60)) if a.size() > 1 and a[1] != null else ""]
		"activateRoom":
			return "activateRoom %s" % _ai_room_id(pid, int(a[0]))
	return t


## Etat Godot en bref (diagnostic des desaccords).
func _ai_state(pid: int) -> String:
	var G: Dictionary = run.G
	var p: Dictionary = (G["players"] as Dictionary).get(pid, {})
	var hand := (p.get("hand", []) as Array).map(func(c): return _ai_id(c))
	var dun := (p.get("dungeon", []) as Array).map(func(st): return _ai_id((st as Array).back()) if not (st as Array).is_empty() else "-")
	var ent := (p.get("entrance", []) as Array).map(func(h): return _ai_id(h))
	var town := (G.get("town", []) as Array).map(func(h): return _ai_id(h))
	return "T%d %s P%d hand=[%s] dun=[%s] ent=[%s] town=[%s]" % [maxi(0, int(G.get("turn", 0)) - 1), str(G.get("phase", "")), pid + 1,
		",".join(hand), ",".join(dun), ",".join(ent), ",".join(town)]


func _ai_rec(type: String, agree: bool, s: Dictionary, pid: int, choices: int, oracle: String, godot: String, by := "", tie := false) -> void:
	var c: Dictionary = _ai.get_or_add(type, {"n": 0, "agree": 0, "forced": 0, "nt": 0, "ntAgree": 0, "ties": 0, "ex": []})
	c["n"] += 1
	if agree:
		c["agree"] += 1
	elif tie:
		c["ties"] += 1
	if choices <= 1:
		c["forced"] += 1
	else:
		c["nt"] += 1
		if agree:
			c["ntAgree"] += 1
	if by != "":
		var b: Dictionary = _ai_by.get_or_add(by, {"n": 0, "agree": 0})
		b["n"] += 1
		if agree:
			b["agree"] += 1
	if not agree and (c["ex"] as Array).size() < _ai_ex:
		(c["ex"] as Array).append({"seq": int(s["seq"]), "turn": int(s["turn"]), "phase": str(s["phase"]), "player": pid + 1, "oracle": oracle,
			"godot": godot, "tie": tie, "choices": choices, "state": _ai_state(pid)})


## Construire : carte + emplacement, carte seule, emplacement (carte de l'oracle).
func _ai_build(pid: int, args: Array, s: Dictionary) -> void:
	if not _ai_on:
		return
	var h := hash(run.G)
	var builds: Array = []
	for m in run.legal_moves(pid):
		if str((m as Dictionary).get("type", "")) == "buildRoom":
			builds.append(m)
	if builds.is_empty():
		_ai_unavail("build")
		_ai_guard(h)
		return
	var code := str(((s["detail"] as Dictionary)["room"] as Dictionary)["card"])
	var slot_o := _ai_slot(args)
	var scores: Array = []
	for m in builds:
		scores.append(AI.score_move(run, pid, m))
	var bi := 0
	for k in range(1, builds.size()):
		if float(scores[k]) > float(scores[bi]):
			bi = k
	var ba: Array = (builds[bi] as Dictionary)["args"]
	var gcode := _ai_hand_id(pid, int(ba[0]))
	var gslot := _ai_slot(ba)
	var keys := {}
	var codes := {}
	var same: Array = [] # indices des coups de la carte de l'oracle
	var o_sc := -INF # meilleur score du coup oracle exact / de sa carte
	var c_sc := -INF
	for k in builds.size():
		var a: Array = (builds[k] as Dictionary)["args"]
		var cc := _ai_hand_id(pid, int(a[0]))
		keys["%s:%d" % [cc, _ai_slot(a)]] = true
		codes[cc] = true
		if cc == code:
			same.append(k)
			c_sc = maxf(c_sc, float(scores[k]))
			if _ai_slot(a) == slot_o:
				o_sc = maxf(o_sc, float(scores[k]))
	var ostr := "buildRoom %s %s" % [code, ("sur la pile %d" % slot_o) if slot_o >= 0 else "nouvelle pile"]
	var gstr := _ai_mv_str(pid, builds[bi])
	var top := float(scores[bi])
	_ai_rec("build", gcode == code and gslot == slot_o, s, pid, keys.size(), ostr, gstr, "", o_sc == top)
	_ai_rec("buildCard", gcode == code, s, pid, codes.size(), code, gcode, "", c_sc == top)
	if same.is_empty():
		_ai_unavail("buildSlot")
	else:
		var bj: int = same[0]
		var slots := {}
		for k in same:
			slots[_ai_slot((builds[k] as Dictionary)["args"])] = true
			if float(scores[k]) > float(scores[bj]):
				bj = k
		var js := _ai_slot((builds[bj] as Dictionary)["args"])
		_ai_rec("buildSlot", js == slot_o, s, pid, slots.size(), "%s %s" % [code, ("pile %d" % slot_o) if slot_o >= 0 else "nouvelle pile"],
			"%s %s" % [code, ("pile %d" % js) if js >= 0 else "nouvelle pile"], "", o_sc == float(scores[bj]))
	_ai_guard(h)


## Defausse d'ouverture : AI.select_opening_discards sur la main d'ouverture.
func _ai_discard(pid: int, a: int, b: int, s: Dictionary) -> void:
	if not _ai_on:
		return
	var h := hash(run.G)
	var p: Dictionary = run.G["players"][pid]
	var hand: Array = p.get("hand", [])
	var pair: Array = AI.select_opening_discards(hand, p, run.G)
	var og := [_ai_hand_id(pid, a), _ai_hand_id(pid, b)]
	var gg: Array = []
	for k in pair:
		gg.append(_ai_hand_id(pid, int(k)))
	og.sort()
	gg.sort()
	_ai_rec("discard", og == gg, s, pid, hand.size(), "defausse " + "+".join(og), "defausse " + "+".join(gg))
	_ai_guard(h)


## Choix de capacite de l'IA oracle (UseAbility / repondant de Spell Battle ; cle de tete `abilityChoices` de la trace, ecrite par TracingBrain) : l'oracle tire UNIFORMEMENT
## parmi ses capacites eligibles (StatisticAI.SelectAbilityToUse), l'accord point a point est donc impossible ; on compare les ENSEMBLES. Mesure faite juste AVANT le
## premier step de seq > afterSeq (etat Godot = etat de l'oracle apres le step afterSeq), sans rien modifier (garde hash(G), etat du RNG de la partie restaure).
##  - eligibleSet:<spell|activate|pass> : l'ensemble Godot (ApkAI.abilities) == l'ensemble oracle (memes instances de cartes) ; le suffixe = ce que l'oracle a tire.
##  - chosenInSet:<spell|activate>      : la carte tiree par l'oracle est dans l'ensemble Godot.
##  - spellTarget / activateTarget      : cible preregle Godot pour la carte tiree par l'oracle == celle de l'oracle ; `...Shuffle` : cibles issues d'un `Shuffle()`
##                                         (BMA040, BMA047, BMA009 : tirage au hasard, comptees a part).
func _ai_flush_choices(next_seq: int) -> void:
	if not _ai_on:
		return
	while _ach_pos < _ach.size() and int((_ach[_ach_pos] as Dictionary)["afterSeq"]) < next_seq:
		_ai_measure_choice(_ach[_ach_pos])
		_ach_pos += 1


func _ai_ids(entries: Array, oracle: bool) -> Array:
	var out: Array = []
	for e in entries:
		var c: Dictionary = (e as Dictionary)["card"]
		out.append(int(c["id"]) if oracle else int(c.get("_oid", -1)))
	out.sort()
	return out


func _ai_codes(entries: Array, oracle: bool) -> String:
	var out: Array = []
	for e in entries:
		var c: Dictionary = (e as Dictionary)["card"]
		out.append(str(c["card"]) if oracle else str(c.get("id", "?")))
	return ",".join(out)


## Cibles preregles en cles « effet:fournisseur » -> identifiants d'instances tries (listes vides ignorees).
func _ai_norm_targets(t: Array, oracle: bool) -> String:
	var out := {}
	for i in t.size():
		if oracle:
			for j in (t[i] as Array).size():
				var ids: Array = []
				for c in (t[i][j] as Array):
					ids.append(int((c as Dictionary)["id"]))
				if not ids.is_empty():
					ids.sort()
					out["%d:%d" % [i, j]] = ids
		else:
			var ids2: Array = []
			for c in ((t[i] as Array)[2] as Array):
				ids2.append(int((c as Dictionary).get("_oid", -1)))
			if not ids2.is_empty():
				ids2.sort()
				out["%d:%d" % [int((t[i] as Array)[0]), int((t[i] as Array)[1])]] = ids2
	var keys: Array = out.keys()
	keys.sort()
	return ";".join(keys.map(func(k): return "%s=%s" % [k, str(out[k])]))


func _ai_measure_choice(rec: Dictionary) -> void:
	var G: Dictionary = run.G
	var pid := int(rec["player"]) - 1
	var s := {"seq": int(rec["afterSeq"]), "turn": int(rec["turn"]), "phase": str(rec["phase"])}
	var stack: Array = G.get("stack", [])
	if not (G["players"] as Dictionary).has(pid) or not (G.get("pendingChoice", {}) as Dictionary).is_empty() or G.get("gameOver") != null:
		_ai_unavail("ability:%s" % ("pendingChoice" if not (G.get("pendingChoice", {}) as Dictionary).is_empty() else ("over" if G.get("gameOver") != null else "player")))
		return
	if bool(rec["spellBattle"]) == stack.is_empty():
		_ai_unavail("ability:battle:%s:%s" % [str(rec["phase"]), "stack" if not stack.is_empty() else "nostack"])
		return
	if str(G.get("phase", "")) != ("build" if str(rec["phase"]) == "BuildPhase_a" else "adventure") or maxi(0, int(G.get("turn", 0)) - 1) != int(rec["turn"]):
		_ai_unavail("ability:phase:%s:%s:T%d/%d" % [str(rec["phase"]), str(G.get("phase", "")), maxi(0, int(G.get("turn", 0)) - 1), int(rec["turn"])])
		return
	var h := hash(G)
	var rng_state := run.rng.state
	var scratch := RandomNumberGenerator.new()
	scratch.seed = 12345
	var moves: Array = run._stack_response_moves(G["players"][pid], pid, stack.size()) if not stack.is_empty() else run.legal_moves(pid)
	if rec.get("activePlayer") != null and int(rec["activePlayer"]) != int(rec["player"]): # IsPlayerBuildTurn : seul le joueur actif de l'oracle construit (Godot a deja passe au suivant apres un DONE)
		moves = moves.filter(func(m): return str((m as Dictionary).get("type", "")) != "buildRoom")
	var opts: Array = ApkAI.abilities(G, pid, moves, scratch)
	run.rng.state = rng_state
	AI.remember(run, pid, null) # abilitySelected : remplace a chaque UseAbility (null si l'oracle ne tire rien)
	# Diagnostic de legalite : cartes jouables (CanPlayerPlayAbility) cote oracle / coups legaux Godot, avant les CheckXXX.
	var gp: Dictionary = G["players"][pid]
	var u_g := {}
	for m in moves:
		if ApkAI.is_apk_ability_move(gp, m):
			var ma: Array = (m as Dictionary)["args"]
			var uc = (gp["hand"] as Array)[int(ma[0])] if str((m as Dictionary)["type"]) == "playSpell" else BossEngine.active_room((gp["dungeon"] as Array)[int(ma[0])])
			u_g[int((uc as Dictionary).get("_oid", -1))] = str((uc as Dictionary).get("id", "?"))
	var u_o := {}
	for u in (rec["usable"] as Array):
		u_o[int((u as Dictionary)["id"])] = str((u as Dictionary)["card"])
	# Teleportation (ActiveHeroInDungeon : Hero.IsActiveHero) depend de la fenetre APK, que Godot fusionne (un humain n'a que la fusion) : si l'oracle est deja au joueur
	# actif suivant (le notre n'a plus de heros : Godot a enchaine), ou dans AdventurePhase_c APRES la fin d'un heros (aucun heros actif) alors que Godot est deja
	# dans la fenetre « heros suivant designe » (AdventurePhase_b APK), la carte n'est pas comparable : retiree des DEUX ensembles et comptee a part.
	if stack.is_empty() and str(rec["phase"]) != "BuildPhase_a" and (
			(rec.get("activePlayer") != null and int(rec["activePlayer"]) - 1 != run.active_player())
			or (str(rec["phase"]) == "AdventurePhase_c" and bool(G.get("afterHero", false)) and (G.get("adventure", {}) as Dictionary).is_empty())):
		for k in u_o.keys() + u_g.keys():
			if (u_o.get(k, u_g.get(k)) as String) == "BMA053":
				u_o.erase(k)
				u_g.erase(k)
				_ai_unavail("usableSet:BMA053:window")
	var u_og: Array = u_o.keys()
	u_og.sort()
	var u_gg: Array = u_g.keys()
	u_gg.sort()
	_ai_rec("usableSet", u_og == u_gg, s, pid, 2, "{%s}" % ",".join(u_o.values()), "{%s}" % ",".join(u_g.values()), "usableSet")
	if u_og != u_gg:
		for k in u_o:
			if not u_g.has(k):
				(_ai_by.get_or_add("usableSet-oracleOnly:" + str(u_o[k]), {"n": 0, "agree": 0}))["n"] += 1
		for k in u_g:
			if not u_o.has(k):
				(_ai_by.get_or_add("usableSet-godotOnly:" + str(u_g[k]), {"n": 0, "agree": 0}))["n"] += 1
	var elig: Array = rec["eligible"]
	var ci := int(rec["chosen"])
	var o_ids := _ai_ids(elig, true)
	var g_ids := _ai_ids(opts, false)
	var kind := "pass" if ci < 0 else ("spell" if str((elig[ci] as Dictionary)["kind"]) == "spell" else "activate")
	var same := o_ids == g_ids
	_ai_rec("eligibleSet:" + kind, same, s, pid, 2, "{%s}" % _ai_codes(elig, true), "{%s}" % _ai_codes(opts, false), "eligibleSet:" + kind)
	if not same:
		for e in elig:
			if not g_ids.has(int(((e as Dictionary)["card"] as Dictionary)["id"])):
				(_ai_by.get_or_add("eligibleSet-oracleOnly:" + str(((e as Dictionary)["card"] as Dictionary)["card"]), {"n": 0, "agree": 0}))["n"] += 1
		for e in opts:
			if not o_ids.has(int(((e as Dictionary)["card"] as Dictionary).get("_oid", -1))):
				(_ai_by.get_or_add("eligibleSet-godotOnly:" + str(((e as Dictionary)["card"] as Dictionary).get("id", "?")), {"n": 0, "agree": 0}))["n"] += 1
	if ci >= 0:
		var oc: Dictionary = (elig[ci] as Dictionary)["card"]
		var code := str(oc["card"])
		var at := g_ids.find(int(oc["id"]))
		_ai_rec("chosenInSet:" + kind, at >= 0, s, pid, 2, code, "{%s}" % _ai_codes(opts, false), "chosenInSet:" + code)
		if at >= 0:
			var ge: Dictionary = opts[0]
			for e in opts:
				if int(((e as Dictionary)["card"] as Dictionary).get("_oid", -1)) == int(oc["id"]):
					ge = e
			AI.remember(run, pid, ge) # l'oracle a tire cette capacite : ses cibles preregles servent aux choix qu'elle ouvre (AIPlayerInteraction.InternalResolveTarget)
			var shuffled: bool = ["BMA040", "BMA047", "BMA009"].has(code)
			var ot := _ai_norm_targets(((elig[ci] as Dictionary)["targets"] as Array), true)
			var gt := _ai_norm_targets((ge["t"] as Array), false)
			var ttype := ("spellTarget" if kind == "spell" else "activateTarget") + ("Shuffle" if shuffled else "")
			_ai_rec(ttype, ot == gt, s, pid, 2, "%s %s" % [code, ot], "%s %s" % [code, gt], ttype + ":" + code)
	_ai_guard(h)


## Le joueur n'a rien joue (passBuild/pass rejoue par le harnais) : AI.pick_move proposerait-il un coup actif ?
func _ai_pass(pid: int, site: String, s: Dictionary, oracle_pid := -1) -> void:
	if not _ai_on:
		return
	if oracle_pid >= 0 and oracle_pid != pid: # le repondant que Godot attend n'est pas le joueur de ce « pret » oracle : decision non comparable
		_ai_unavail("pass:" + site + "-order")
		return
	if not (run.G.get("pendingChoice", {}) as Dictionary).is_empty() or not (run.G["players"] as Dictionary).has(pid):
		_ai_unavail("pass")
		return
	var h := hash(run.G)
	var keys := {}
	var n := 0
	for m in run.legal_moves(pid):
		if str((m as Dictionary).get("type", "")) == "undoBuild":
			continue
		n += 1
		keys[_ai_mv_key(pid, m) + (str(m["args"]) if str(m.get("type", "")) == "buildRoom" else "")] = true
	if n == 0:
		_ai_unavail("pass")
		_ai_guard(h)
		return
	keys.erase("-")
	var rng_state := run.rng.state
	var mv = AI.pick_move(run, pid, false)
	run.rng.state = rng_state
	var nothing: bool = mv == null or AI_NOTHING.has(str((mv as Dictionary).get("type", "")))
	_ai_rec("pass", nothing, s, pid, keys.size() + 1, "ne joue rien (%s)" % site, _ai_mv_str(pid, mv) + ("" if nothing else " (score %s)" % str(AI.score_move(run, pid, mv))), "pass:" + site)
	if not nothing: # ce que Godot jouerait a la place (diagnostic)
		var alt: Dictionary = _ai_by.get_or_add("passAlt:%s>%s" % [site, _ai_mv_key(pid, mv)], {"n": 0, "agree": 0})
		alt["n"] += 1
	_ai_guard(h)


## Option d'un choix ouvert (resolveChoice) : AI.pick_move sur le choix en attente. `type` = « target » ou « draw ». Un choix dont la cible vient d'un tirage
## (`Shuffle()` : cle `shuffled` de la decision oracle, ou tirage de l'IA Godot) est compte a part (`targetShuffle`) ; l'abstention de l'oracle sur un choix facultatif
## (`pick` = -1) est `targetPass` (accord : Godot ne designe rien non plus).
func _ai_choice(pid: int, pc: Dictionary, pick: int, s: Dictionary, type: String) -> void:
	if not _ai_on:
		return
	var opts: Array = pc.get("options", [])
	if pick >= opts.size() or (pick < 0 and type != "target"):
		_ai_unavail(type)
		return
	var h := hash(run.G)
	var rng_state := run.rng.state
	AI.last_choice_shuf = false
	var mv = AI.pick_move(run, pid, false)
	run.rng.state = rng_state
	if mv == null or str((mv as Dictionary).get("type", "")) != "resolveChoice":
		_ai_unavail(type)
		_ai_guard(h)
		return
	var gi := int(((mv as Dictionary)["args"] as Array)[0])
	var ko := "(passer)" if pick < 0 else _ai_opt_key(opts[pick], pid)
	var kg := "(passer)" if gi < 0 or gi >= opts.size() else _ai_opt_key(opts[gi], pid)
	var agree := gi == pick or (gi >= 0 and pick >= 0 and kg == ko)
	var tie := false
	if not agree:
		tie = AI.score_move(run, pid, {"type": "resolveChoice", "args": [pick]}) == AI.score_move(run, pid, mv)
	var keys := {}
	for o in opts:
		keys[_ai_opt_key(o, pid)] = true
	var ptype := str(pc.get("type", ""))
	var det = s.get("detail")
	var rtype := type
	if type == "target":
		rtype = "targetPass" if pick < 0 else ("targetShuffle" if (AI.last_choice_shuf or (det is Dictionary and bool((det as Dictionary).get("shuffled", false)))) else "target")
	if type == "target" and det is Dictionary and bool((det as Dictionary).get("shuffled", false)) and not AI.last_choice_shuf: # diagnostic : tirage de l'oracle que Godot ne fait pas
		(_ai_by.get_or_add("shuffleOracleOnly:%s[%s]" % [ptype, str(pc.get("bossName", ""))], {"n": 0, "agree": 0}))["n"] += 1
	_ai_rec(rtype, agree, s, pid, keys.size() + (1 if pick < 0 else 0), "option %d %s" % [pick, ko], "option %d %s" % [gi, kg],
		"%s:%s[%s]" % [rtype, ptype, str(pc.get("bossName", ""))], tie)
	_ai_guard(h)


## Un `spellBattleReady` est « propre » (fin de l'action du joueur) quand l'action IA precedente de meme profondeur est un sort / une capacite de ce
## joueur ; sinon c'est un repondant de la Spell Battle qui n'a rien joue (AbilityApplyRequest : UseAbility null puis SetSpellBattleReady).
func _ready_is_own(i: int) -> bool:
	var s: Dictionary = _steps[i]
	for k in range(i - 1, -1, -1):
		var n: Dictionary = _steps[k]
		if int(n["depth"]) > int(s["depth"]):
			continue
		var nd = n.get("detail")
		return int(n["depth"]) == int(s["depth"]) and str(n["kind"]) == "action" and nd is Dictionary \
			and str((nd as Dictionary).get("action", "")) in ["playSpell", "playRoomAbility"] and (nd as Dictionary).get("player") == (s["detail"] as Dictionary).get("player")
	return false
