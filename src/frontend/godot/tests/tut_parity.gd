extends Node
## Parite du TUTORIEL Godot <-> APK (lot L8, T-A07 / T-A31). Pour chaque trace `oracle-tut-*.json` (tools/apk-oracle `--tutorial` : InitializeGameBoardTutorial,
## humain scripte TutorialHumanBrain, IA FixedAI), Godot joue la MEME partie avec son propre moteur ET sa propre IA :
##  - `init` : GameManager.start_tutorial() puis le choix du boss de l'humain (mains d'ouverture avant defausse), meme schema que init_parity.gd (compare_init) ;
##  - `live` : partie jouee de bout en bout (humain scripte comme l'oracle, IA du siege 2 = AI.pick_move = port de FixedAI), photographiee a chaque debut de tour
##    (`turnstart:N`), a chaque leurre (`bait:N`) et apres la defausse d'ouverture (`setup`), + journal des constructions (carte, siege) et des sorts / capacites.
## Aucun coup de l'oracle n'est rejoue ici : seule la consigne de l'humain est ecrite a la main, comme dans GamePlayTutScene. Comparaison : tools/parity/apk.py --tutorial.
##
## Usage : godot --headless --path src/frontend res://godot/tests/TutParity.tscn -- --traces=<dossier absolu>

const MAX_STEPS := 3000

class TutMatch extends GameManager:
	var snap: Callable = Callable()
	var snaps: Dictionary = {}
	var log_moves: Array = []

	func _start_turn() -> void:
		super._start_turn()
		_snap("turnstart")

	func _init_adventure_phase() -> void:
		_snap("bait")
		super._init_adventure_phase()

	func _snap(tag: String) -> void:
		if snap.is_valid():
			snaps["%s:%d" % [tag, maxi(0, int(G.get("turn", 0)) - 1)]] = snap.call()

	func apply_move(pid: int, move: Dictionary) -> bool:
		var t := str(move.get("type", ""))
		var card := ""
		var a: Array = move.get("args", [])
		if t == "buildRoom" and not a.is_empty():
			card = str((((G["players"][pid] as Dictionary)["hand"] as Array)[int(a[0])] as Dictionary).get("id", ""))
		elif t in ["playSpell", "activateRoom"] and not a.is_empty():
			card = str((((G["players"][pid] as Dictionary)["hand"] as Array)[int(a[0])] as Dictionary).get("id", "")) if t == "playSpell" else str((((G["players"][pid] as Dictionary)["dungeon"] as Array)[int(a[0])] as Array).back().get("id", ""))
		var ok := super.apply_move(pid, move)
		if ok and card != "":
			log_moves.append([pid + 1, t, card, int(G.get("turn", 0)) - 1])
		return ok

func _traces_dir() -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--traces="):
			return a.substr(len("--traces="))
	return ""

## [carte, UniqueID, est un sort] (meme forme que init_parity.gd).
func _c(card: Dictionary) -> Array:
	return [str(card.get("id", "")), int(card.get("_uid", 0)), bool(card.get("isSpell", false))]

func _snapshot(decks: Dictionary) -> Dictionary:
	var heroes: Array = (decks["heroes"] as Array).duplicate()
	heroes.reverse()
	var epics: Array = (decks["epics"] as Array).duplicate()
	epics.reverse()
	var out := {"heroes": (heroes + epics).map(_c)}
	for k in ["rooms", "spells", "items"]:
		var a: Array = (decks[k] as Array).duplicate()
		a.reverse()
		out[k] = a.map(_c)
	return out

## Projection canonique (miroir de ApkParityTrace.project et de oracle_proj dans apk.py).
func _project(m: TutMatch) -> Dictionary:
	var G: Dictionary = m.G
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
		var ent: Array = (p.get("entrance", []) as Array).map(func(h): return str((h as Dictionary).get("id", "")))
		ent.sort()
		pl[str(int(pid) + 1)] = {"souls": CardDB.total_souls(p, G), "wounds": CardDB.total_wounds(p), "hand": hand, "spells": sp, "dungeon": dun, "pending": pend, "entrance": ent}
	var dk: Dictionary = G["decks"]
	return {
		"phase": "adventure" if str(G.get("phase", "")) == "bait" else str(G.get("phase", "")), "turn": maxi(0, int(G.get("turn", 0)) - 1),
		"town": (G.get("town", []) as Array).map(func(h): return str((h as Dictionary).get("id", ""))),
		"decks": {"heroes": (dk["heroes"] as Array).size() + (dk["epics"] as Array).size(), "rooms": (dk["rooms"] as Array).size(), "spells": (dk["spells"] as Array).size(),
			"discardRooms": (dk["roomDiscard"] as Array).size(), "discardSpells": (dk["spellDiscard"] as Array).size(), "items": (dk.get("items", []) as Array).size()},
		"players": pl,
	}

## Parite d'initialisation : memes champs que init_parity.gd.
func _init_run() -> Dictionary:
	var m := TutMatch.new()
	add_child(m)
	var G: Dictionary = m.start_tutorial()
	var out := {"bosses": [], "pre": _snapshot(G["decks"])}
	var seats: Array = G["players"].keys()
	seats.sort()
	out["bosses"] = [GameManager.TUT_BOSS_HUMAN, GameManager.TUT_BOSS_AI] # imposes par GamePlayTutScene (HUMAN_PLAYER / IA_PLAYER), pas tires
	G["autoAI"] = false
	for pid in seats:
		(G["players"][pid] as Dictionary)["isAI"] = false # pas de defausse automatique : on lit les mains d'ouverture completes
	m.apply_move(0, {"type": "pickBoss", "args": [GameManager.TUT_BOSS_HUMAN]})
	var rank: Dictionary = {}
	var order: Array = CardDB.order_by_xp(G["players"])
	for i in order.size():
		rank[int(order[i])] = i + 1
	out["rank"] = seats.map(func(p): return rank.get(int(p), 0))
	out["hands"] = seats.map(func(p): return (G["players"][p]["hand"] as Array).map(_c))
	out["post"] = _snapshot(G["decks"])
	m.queue_free()
	return out

# ---------------------------------------------------------------------------------------------------------------------
# Partie jouee : humain scripte (consignes de GamePlayTutScene), IA = AI.pick_move
# ---------------------------------------------------------------------------------------------------------------------

const BUILDS := ["BMA034", "BMA016", "BMA027"] # GamePlayTutScene.cs:186,195,204
const DISCARDS := ["BMA026", "BMA055"]          # :27-29
const HERO_HIT := "BMA064"                      # :39
const HERO_SPELL := "BMA068"                    # :41
const ROOM_HIT := "BMA027"                      # :37
const SPELL := "BMA041"                         # :43

func _hand_ids(m: TutMatch, pid: int) -> Array:
	return ((m.G["players"][pid] as Dictionary)["hand"] as Array).map(func(c): return str((c as Dictionary).get("id", "")))

func _built(m: TutMatch, pid: int) -> int:
	var n := 0
	for st in (m.G["players"][pid] as Dictionary)["dungeon"]:
		if not (st as Array).is_empty():
			n += 1
	return n

## Coup de l'humain scripte, null = aucune consigne (on laisse passer / l'IA jouer).
func _human(m: TutMatch) -> Variant:
	var G: Dictionary = m.G
	var moves: Array = m.legal_moves(0)
	if moves.is_empty():
		return null
	var pc: Dictionary = G.get("pendingChoice", {})
	if str(pc.get("type", "")) == "opening-discard":
		var ids := _hand_ids(m, 0)
		return {"type": "openingDiscard", "args": [ids.find(DISCARDS[0]), ids.find(DISCARDS[1])]} if ids.find(DISCARDS[0]) < ids.find(DISCARDS[1]) else {"type": "openingDiscard", "args": [ids.find(DISCARDS[1]), ids.find(DISCARDS[0])]}
	if not pc.is_empty():
		return null
	var first_turn: bool = int(G.get("turn", 0)) <= 1 # GamePlayTutScene : NumberOfTurns == 0
	var phase := str(G.get("phase", ""))
	if first_turn and (phase == "setup" or phase == "build") and m.active_player() == 0:
		var n := _built(m, 0)
		if n < BUILDS.size():
			var hi := _hand_ids(m, 0).find(BUILDS[n])
			for mv in moves:
				var a: Array = (mv as Dictionary).get("args", [])
				if str((mv as Dictionary)["type"]) == "buildRoom" and a.size() == 1 and int(a[0]) == hi:
					return mv
		for mv in moves:
			if str((mv as Dictionary)["type"]) == "passBuild":
				return mv # DONE
	if first_turn and phase == "adventure":
		var adv: Dictionary = G.get("adventure", {})
		var hid := str(((adv.get("hero", {}) as Dictionary)).get("id", ""))
		if hid == HERO_HIT and not adv.is_empty():
			for mv in moves:
				if str((mv as Dictionary)["type"]) == "activateRoom":
					var dun: Array = (G["players"][0] as Dictionary)["dungeon"]
					var ri := int(((mv as Dictionary)["args"] as Array)[0])
					if ri >= 0 and ri < dun.size() and str(((dun[ri] as Array).back() as Dictionary).get("id", "")) == ROOM_HIT:
						return mv
		var hi2 := _hand_ids(m, 0).find(SPELL)
		var ent: Array = ((G["players"][1] as Dictionary).get("entrance", []) as Array)
		if hi2 >= 0 and adv.is_empty() and m.active_player() == 1 and not ent.is_empty() and str((ent[0] as Dictionary).get("id", "")) == HERO_SPELL:
			for mv in moves:
				var a2: Array = (mv as Dictionary).get("args", [])
				if str((mv as Dictionary)["type"]) == "playSpell" and int(a2[0]) == hi2:
					return mv
	return null

func _is_build(mv: Variant) -> bool:
	return mv != null and str((mv as Dictionary).get("type", "")) in ["buildRoom", "undoBuild", "passBuild", "pass", "adventureNext", "resolveNextHero"]

## Un pas de jeu : humain scripte, puis IA / passes. false = rien a faire.
func _step(m: TutMatch) -> bool:
	var G: Dictionary = m.G
	var phase := str(G.get("phase", ""))
	var pc: Dictionary = G.get("pendingChoice", {})
	if not pc.is_empty():
		var owner := int(pc.get("playerId", 0))
		var hm = _human(m) if owner == 0 else null
		if hm == null:
			hm = AI.pick_move(m, owner)
		if hm == null:
			var cm: Array = m.legal_moves(owner)
			hm = cm[0] if not cm.is_empty() else null
		return hm != null and m.apply_move(owner, hm)
	if phase == "boss":
		return m.apply_move(0, {"type": "pickBoss", "args": [GameManager.TUT_BOSS_HUMAN]})
	var hm2 = _human(m)
	if hm2 != null:
		return m.apply_move(0, hm2)
	if phase == "build" or phase == "setup":
		var ap := m.active_player()
		var mv0 = AI.pick_move(m, ap) if ap == 1 or int(G.get("turn", 0)) > 1 else null # apres le premier tour, le siege 1 joue comme l'oracle (FixedAI : constructions seulement)
		if mv0 != null and (ap == 1 or _is_build(mv0)) and m.apply_move(ap, mv0):
			return true
		return _pass_any(m, [ap, 0, 1])
	if phase == "adventure":
		var apx := m.active_player()
		var ai_mv = AI.pick_move(m, 1) if apx == 1 else null
		if ai_mv != null and AI.score_move(m, 1, ai_mv) >= 0.0 and m.apply_move(1, ai_mv):
			return true
		return _pass_any(m, [0, 1])
	return false

func _pass_any(m: TutMatch, pids: Array) -> bool:
	for pid in pids:
		for mv in m.legal_moves(int(pid)):
			if str((mv as Dictionary)["type"]) in ["passBuild", "pass", "adventureNext", "resolveNextHero"] and m.apply_move(int(pid), mv):
				return true
	return false

func _live_run(last_turn: int) -> Dictionary:
	var m := TutMatch.new()
	add_child(m)
	m.snap = _project.bind(m)
	m.start_tutorial()
	var steps := 0
	var setup_snapped := false
	while m.G.get("gameOver") == null and steps < MAX_STEPS and not m.snaps.has("turnstart:%d" % last_turn):
		steps += 1
		if not _step(m):
			break
		if not setup_snapped and str((m.G.get("pendingChoice", {}) as Dictionary).get("type", "")) != "opening-discard" and str(m.G.get("phase", "")) == "setup" and _hand_ids(m, 0).size() == 5 and _hand_ids(m, 1).size() == 5:
			setup_snapped = true
			m.snaps["setup"] = _project(m)
	if not m.snaps.has("turnstart:%d" % last_turn):
		print("TUT PARITY stuck phase=", m.G.get("phase"), " turn=", m.G.get("turn"), " active=", m.active_player(), " pc=", m.G.get("pendingChoice", {}).get("type"), " moves0=", m.legal_moves(0).map(func(x): return str(x["type"]) + str(x.get("args"))), " moves1=", m.legal_moves(1).map(func(x): return str(x["type"]) + str(x.get("args"))))
	var out := {"snaps": m.snaps, "moves": m.log_moves, "steps": steps, "over": m.G.get("gameOver") != null, "turn": int(m.G.get("turn", 0)), "phase": str(m.G.get("phase", ""))}
	m.queue_free()
	return out

func _ready() -> void:
	var dir := _traces_dir()
	if dir == "" or not DirAccess.dir_exists_absolute(dir):
		print("TUT PARITY FAIL: --traces=<dossier absolu> requis (recu: '%s')" % dir)
		get_tree().quit(1)
		return
	var files := DirAccess.get_files_at(dir)
	files.sort()
	var n := 0
	for f in files:
		if not f.begins_with("oracle-tut-") or not f.ends_with(".json"):
			continue
		var t = JSON.parse_string(FileAccess.get_file_as_string(dir.path_join(f)))
		var res := {"init": _init_run(), "live": _live_run(int(t["turns"]) - 1)}
		var fh := FileAccess.open(dir.path_join("tut-%s" % f.trim_prefix("oracle-tut-")), FileAccess.WRITE)
		fh.store_string(JSON.stringify(res))
		fh.close()
		n += 1
	print("TUT PARITY OK traces=%d" % n)
	get_tree().quit(0)
