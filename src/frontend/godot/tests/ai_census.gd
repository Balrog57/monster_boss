extends Node
## Recensement de l'IA : quelles cartes / capacites l'IA se voit offrir (coup legal) mais ne choisit jamais ?
## Joue des parties IA-vs-IA (meme boucle que BoardUI._process) et compte, par carte, les parties ou un coup l'impliquant etait legal
## (« offert ») et celles ou l'IA l'a choisi (« choisi »). Outil de developpement, hors `npm run test:godot:all`.
## Usage : godot --headless --path src/frontend res://godot/tests/AiCensus.tscn -- --sets=next-level,crash-landing --games=20 [--players=2] [--seed=1]
## Sortie : une ligne par cle `type:id` jamais choisie alors qu'elle a ete offerte, puis les cartes jamais offertes, puis « CENSUS PASS » ou
## « CENSUS FAIL » (code de sortie 1) : echec si une carte des paquets demandes est offerte mais jamais choisie sans figurer dans ALLOW.

const MAX_STEPS := 4000

## Cartes dont l'IA ne joue jamais la capacite, a dessein : situation rare ou condition tres etroite (id de carte -> raison).
const ALLOW := {
	"CRL012": "The Omega 42 : ne rejoue un effet que contre une salle avancee morte en main (2 offres sur 60 parties)",
	"TNL041": "Wreck Room : detruit une salle quasi inutile, seulement donjon plein + main <= 3 + salle ordinaire de rechange (jamais reunis sur 60 parties)",
	"RMB055": "Spike : niveau 2 = 2 degats au heros qui meurt exactement ; niveau 3 = renvoie un miniboss adverse promu (offert 1 fois sur 60 parties)",
	"RMB056": "Kid Croak : niveau 3 = +/-1 aux Monster seulement si cela tranche la mort du heros (offert 1 fois sur 60 parties)",
	"RMB058": "Rocky : niveau 3 = sauve un heros de justesse (5) ; condition tres etroite (offert 1 fois sur 60 parties)",
}
const SoakSeed = preload("res://godot/tests/soak_seed.gd")

var offered: Dictionary = {}   # cle -> nombre de parties ou le coup a ete legal
var chosen: Dictionary = {}    # cle -> nombre de parties ou l'IA l'a choisi
var _g_offered: Dictionary = {}
var _g_chosen: Dictionary = {}
var _m = null
var _debug := ""   # --debug=cle : affiche le score de chaque coup offert portant cette cle (phase, marge du heros actif)

func _ready() -> void:
	var sets: Array = ["base"]
	var games := 20
	var counts: Array = [2, 3, 4]
	var seed0 := 1
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--sets="):
			sets = Array(a.substr(7).split(",", false))
		elif a.begins_with("--games="):
			games = int(a.substr(8))
		elif a.begins_with("--players="):
			counts = [int(a.substr(10))]
		elif a.begins_with("--debug="):
			_debug = a.substr(8)
		elif a.begins_with("--seed="):
			seed0 = int(a.substr(7))
	AI.trace = Callable(self, "_on_decision")
	var done := 0
	var stuck := 0
	for g in games:
		for n in counts:
			_g_offered = {}
			_g_chosen = {}
			if _play(n, sets, seed0 + g):
				done += 1
			else:
				stuck += 1
				print("CENSUS BLOQUEE seed=", seed0 + g, " joueurs=", n, " phase=", _m.G.get("phase") if is_instance_valid(_m) else "?")
			for k in _g_offered:
				offered[k] = int(offered.get(k, 0)) + 1
			for k in _g_chosen:
				chosen[k] = int(chosen.get(k, 0)) + 1
	AI.trace = Callable()
	SoakSeed.unseed()
	print("CENSUS sets=", sets, " parties=", done, " bloquees=", stuck)
	var never: Array = []
	var rare: Array = []
	for k in offered:
		if int(chosen.get(k, 0)) == 0:
			never.append("%s (offert %d)" % [k, offered[k]])
		elif float(chosen[k]) < 0.25 * float(offered[k]):
			rare.append("%s (%d/%d)" % [k, chosen[k], offered[k]])
	never.sort()
	rare.sort()
	print("CENSUS jamais choisi: ", never)
	print("CENSUS rarement choisi (<25%): ", rare)
	var unseen: Array = []
	var card_set: Dictionary = {}   # id -> paquet
	for list in [CardDB.rooms, CardDB.spells, CardDB.minibosses]:
		for c in list:
			var d: Dictionary = c
			var id := str(d.get("id", ""))
			card_set[id] = str(d.get("set", "base"))
			if not sets.has(card_set[id]) or card_set[id] == "base":
				continue
			var seen := false
			for k in offered:
				seen = seen or (":" + str(k) + ":").contains(":" + id + ":")
			if not seen:
				unseen.append(id + " " + str(d.get("name", "")))
	print("CENSUS jamais offert (cartes du/des paquets): ", unseen)
	# Verdict : une cle jamais choisie n'est tolerable que si la carte est dans ALLOW ; seules les cartes des paquets demandes comptent.
	var failed: Array = []
	var allowed: Array = []
	for entry in never:
		var key: String = str(entry).split(" (")[0]
		var cid: String = key.split(":")[1] if key.split(":").size() > 1 else ""
		if not card_set.has(cid) or not sets.has(card_set[cid]):
			continue
		if ALLOW.has(cid):
			allowed.append("%s : %s" % [key, ALLOW[cid]])
		else:
			failed.append(key)
	for a in allowed:
		print("CENSUS tolere: ", a)
	if stuck > 0:
		failed.append("%d partie(s) bloquee(s)" % stuck)
	if failed.is_empty():
		print("CENSUS PASS (%d cle(s) tolerees)" % allowed.size())
		get_tree().quit(0)
	else:
		print("CENSUS FAIL: ", failed)
		get_tree().quit(1)

func _key(m, pid: int, mv: Dictionary) -> String:
	var G: Dictionary = m.G
	var p: Dictionary = (G["players"] as Dictionary)[pid]
	var hand: Array = p.get("hand", [])
	var dungeon: Array = p.get("dungeon", [])
	var t := str(mv.get("type", ""))
	var a: Array = mv.get("args", [])
	match t:
		"playSpell", "useHandRoom", "buildRoom", "rmbHand", "antimagicCancel":
			var hi := int(a[0]) if not a.is_empty() else -1
			if hi >= 0 and hi < hand.size():
				return t + ":" + str((hand[hi] as Dictionary).get("id", ""))
		"activateMiniboss":
			var mi := int(a[0]) if not a.is_empty() else -1
			if mi >= 0 and mi < dungeon.size():
				return t + ":" + str(Minibosses.mb_id(Minibosses.revealed(BossEngine.active_room(dungeon[mi])))) + ":" + str(a[1])
		"activateRoom":
			var ri := int(a[0]) if not a.is_empty() else -1
			if ri >= 0 and ri < dungeon.size():
				var r = BossEngine.active_room(dungeon[ri])
				if r != null:
					return t + ":" + str((r as Dictionary).get("id", ""))
		"rmbBoss":
			return t + ":" + str(a[0])
		"rmbPay":
			return t + ":RMB046"
		"payDarkHero":
			return t + ":" + str(a[2])
		"promoteMiniboss", "rmbCancel", "docScarecrow", "discardForCoin", "buildMiniboss", "timebenderCancel":
			return t + ":"
	return ""

func _on_decision(m, pid: int, moves: Array, best) -> void:
	for mv in moves:
		var k := _key(m, pid, mv)
		if k != "":
			_g_offered[k] = true
			if _debug != "" and _debug.split(",").has(k):
				var f := AiWiki.fate(m.G)
				print("DEBUG ", k, " pid=", pid, " phase=", m.G.get("phase"), " score=", AI.score_move(m, pid, mv), " margin=", f["margin"], " owner=", f["owner"], " hand=", (m.G["players"][pid]["hand"] as Array).size(), " best=", AI.score_move(m, pid, best) if best != null else "-", " ", best)
	if best != null:
		var kb := _key(m, pid, best)
		if kb != "":
			if str(m.G.get("phase", "")) == "build" or AI.score_move(m, pid, best) >= 0.0:
				_g_chosen[kb] = true

func _play(n_players: int, sets: Array, s: int) -> bool:
	var m = GameManager.new()
	add_child(m)
	SoakSeed.seed_game(m, s * 10 + n_players)
	_m = m
	m.start_new_game(n_players, 0, sets)
	# Les cartes des paquets wiki sont rares dans une pioche melangee : on en ajoute 2 exemplaires, et les 4 premiers boss sont des boss wiki tournants.
	var wiki := func(c): return str((c as Dictionary).get("set", "base")) != "base" and sets.has(str((c as Dictionary).get("set", "base")))
	for pile in ["rooms", "spells"]:
		var extra: Array = []
		for c in (m.G["decks"][pile] as Array):
			if wiki.call(c):
				extra.append((c as Dictionary).duplicate(true))
				extra.append((c as Dictionary).duplicate(true))
		(m.G["decks"][pile] as Array).append_array(extra)
		m.G["decks"][pile] = CardDB.shuffled(m.G["decks"][pile])
	var wbosses: Array = CardDB.bosses.filter(wiki)
	if not wbosses.is_empty():
		var picks: Array = []
		for k in n_players + 2:
			picks.append(wbosses[(s * 3 + k) % wbosses.size()])
		m.G["bossPicks"] = picks
	var steps := 0
	while m.G.get("gameOver") == null and steps < MAX_STEPS:
		steps += 1
		var G: Dictionary = m.G
		var phase := str(G.get("phase", ""))
		var pc: Dictionary = G.get("pendingChoice", {})
		var acted := false
		if phase == "boss":
			for pid in G["players"]:
				var bm: Array = m.legal_moves(int(pid))
				if not bm.is_empty():
					m.apply_move(int(pid), bm[int(pid) % bm.size()] if not wbosses_empty(sets) else bm[0]) # un boss different par joueur
					acted = true
					break
		else:
			for pid in G["players"]:
				var moves: Array = m.legal_moves(int(pid))
				var has_choice: bool = not pc.is_empty() and int(pc.get("playerId", -1)) == int(pid)
				var adv_turn: bool = phase == "adventure" and pc.is_empty() and (int(pid) == m.active_player() or ((G.get("adventure", {}) as Dictionary).get("pause") != null))
				if moves.is_empty() or not (has_choice or phase == "build" or adv_turn):
					continue
				var mv = AI.pick_move(m, int(pid))
				if adv_turn and mv != null and AI.score_move(m, int(pid), mv) < 0.0:
					for x in moves:
						if str((x as Dictionary).get("type", "")) in ["pass", "passBuild"]:
							mv = x
							break
				var okm: bool = mv != null and m.apply_move(int(pid), mv)
				if _debug == "stuck" and steps > MAX_STEPS - 4:
					print("  step ", steps, " P", pid, " mv=", mv, " ok=", okm)
				if okm:
					acted = true
				break
		if not acted:
			# Repli : le premier joueur qui peut passer, sinon n'importe quel coup.
			for pid in G["players"]:
				for pm in m.legal_moves(int(pid)):
					if not acted and str((pm as Dictionary).get("type", "")) in ["pass", "passBuild"] and m.apply_move(int(pid), pm):
						acted = true
			if not acted:
				break
	var done: bool = m.G.get("gameOver") != null
	if not done and _debug == "stuck":
		print("STUCK steps=", steps, " phase=", m.G.get("phase"), " active=", m.active_player(), " pending=", m.G.get("pendingChoice"), " adventure=", m.G.get("adventure"), " stack=", (m.G.get("stack", []) as Array).size())
		for pid in m.G["players"]:
			print("  P", pid, " moves=", m.legal_moves(int(pid)), " entrance=", (m.G["players"][pid]["entrance"] as Array).size(), " passed=", m.G["players"][pid].get("passed"), " acted=", m.G["players"][pid].get("hasActed"))
		print("  pausePassed=", m.G.get("adventurePausePassed"))
		var mv1: Array = m.legal_moves(1)
		print("  P1 coins=", m.G["players"][1].get("coins"), " apply rmbPay -> ", m.apply_move(1, mv1[0]) if not mv1.is_empty() else "-", " log=", (m.G.get("log", []) as Array).slice(-3))
		for k in 4:
			var c0 := int(m.G["players"][1].get("coins", 0))
			var okk = m.apply_move(1, m.legal_moves(1)[0]) if not m.legal_moves(1).is_empty() else "-"
			print("  apply -> ", okk, " coins ", c0, " -> ", m.G["players"][1].get("coins"), " P0 coins=", m.G["players"][0].get("coins"), " moves1=", m.legal_moves(1).size())
		print("  pick P1 -> ", AI.pick_move(m, 1), " score=", AI.score_move(m, 1, AI.pick_move(m, 1)))
	m.queue_free()
	return done

func wbosses_empty(sets: Array) -> bool:
	return sets.size() <= 1
