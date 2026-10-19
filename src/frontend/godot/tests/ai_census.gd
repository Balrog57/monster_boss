extends Node
## Recensement de l'IA : quelles cartes / capacites l'IA se voit offrir (coup legal) mais ne choisit jamais ?
## Joue des parties IA-vs-IA (meme boucle que BoardUI._process) et compte, par carte, les parties ou un coup l'impliquant etait legal
## (« offert ») et celles ou l'IA l'a choisi (« choisi »). Outil de developpement, hors `tools/run_godot_tests.py`.
## Usage : godot --headless --path src/frontend res://godot/tests/AiCensus.tscn -- --sets=next-level,crash-landing --games=20 [--players=2] [--seed=1]
## Sortie : une ligne par cle `type:id` jamais choisie alors qu'elle a ete offerte, puis les cartes jamais offertes, puis « CENSUS PASS » ou
## « CENSUS FAIL » (code de sortie 1) : echec si une carte des paquets demandes est offerte mais jamais choisie, OU jamais offerte (y compris le
## pouvoir de niveau 3 d'un miniboss), sans figurer dans ALLOW. Cles des minibosses par carte : `buildMiniboss:<id>`, `promoteMiniboss:<id>:<niveau vise>`,
## `activateMiniboss:<id>:<niveau>` ; compteur « niveau 3 atteint » par miniboss (parties ou il a ete revele au niveau 3).

const MAX_STEPS := 4000

## Cartes dont l'IA ne joue jamais la capacite, a dessein : situation rare ou condition tres etroite (id de carte -> raison).
const ALLOW := {
	"CRL012": "The Omega 42 : ne rejoue un effet que contre une salle avancee morte en main (2 offres sur 60 parties)",
	"TNL041": "Wreck Room : detruit une salle quasi inutile, seulement donjon plein + main <= 3 + salle ordinaire de rechange (jamais reunis sur 60 parties)",
	"RMB055": "Spike : niveau 2 = 2 degats au heros qui meurt exactement ; niveau 3 = renvoie un miniboss adverse promu (offert 1 fois sur 60 parties)",
	"RMB056": "Kid Croak : niveau 3 = +/-1 aux Monster seulement si cela tranche la mort du heros (offert 1 fois sur 60 parties)",
	"RMB058": "Rocky : niveau 3 = sauve un heros de justesse (5) ; condition tres etroite (offert 1 fois sur 60 parties)",
	"TNL022": "Rust Monster Pen : -1 a une Trap ne sert qu'a sauver de justesse (marge exactement 0) un heros d'un donjon adverse ; choisi 2 fois sur 10 offres avec next-level+crash-landing, 0 sur 12 offres avec next-level seul (60 parties)",
	"TNL040": "Bullet Builder : -1 a une Monster, meme condition (marge exactement 0 chez l'adversaire) ; choisi 1 fois sur 11 offres avec next-level+crash-landing, 0 sur 8 offres avec next-level seul (60 parties)",
	"TNL048": "The Smashinator : +6 mais detruit le reste du donjon, joue seulement pour tuer un heros avec 3 blessures ou plus ; choisi 3 fois sur 20 offres avec next-level seul, 0 sur 3 offres avec tous les paquets (60 parties)",
	"TNL063": "Oh, Yeah! : l'echange de deux salles ne vaut que par les bonus de voisinage (gain > 0 jamais vu sur 137 offres en construction) et la destruction exige 2 de vos salles detruites ce tour (jamais reunie) ; choisi 2 fois sur 14 avec next-level seul, 0 sur 14 avec next-level+crash-landing (60 parties)",
	"RMB053": "The Keystone : se detruit pour 1 Coin par salle restante, joue seulement en construction avec 3 salles restantes ou plus et un miniboss a poser ; choisi 2 fois sur 21 offres avec minibosses seul, 0 sur 17 offres avec tous les paquets (60 parties)",
	"RMB026": "Training Camp : double la salle Monster la plus forte, joue seulement si cela tue le heros de mon donjon ; choisi 2 fois sur 33 offres avec minibosses seul (180 parties : seeds 1-20 et 101-140), 0 sur 13 offres sur les seeds 1-20",
	"THK005": "Goblin Suit (Boss) : +1 a mes Monster ordinaires, joue seulement si cela tue le heros adverse qui atteindrait le Boss ; choisi 1 fois sur 24 offres avec tools-wiki (180 parties : seeds 1-20 et 101-140, 2 a 4 joueurs), 0 sur 7 offres sur les seeds 1-20",
	"THK006": "Claws of the Berserker (Boss) : +1 PV par salle Monster a un heros, joue seulement pour sauver de la marge exacte le heros qui blesserait un adversaire ; choisi 3 fois sur 25 offres avec tools-wiki seul (180 parties), 0 sur 10 offres avec tools-wiki+next-level (120 parties : seeds 1-40)",
	"THK020": "Ring of Invisibility (Boss) : annule un sort adverse joue pendant MA phase d'aventure, donc exige un Anneau en service ET un sort adverse sur la pile : offert 6 fois sur 180 parties avec tools-wiki seul (choisi 4 fois), 0 offre sur 120 parties avec tools-wiki+crash-landing (seeds 1-40)",
	"THK007": "Oversized Sword (Boss) : +5 PV a un heros, joue seulement pour sauver de la marge exacte le heros qui blesserait un adversaire (heros d'un donjon adverse) ; choisi 5 fois sur 22 offres avec tools-wiki (180 parties), 0 sur 5 offres sur les seeds 1-20",
	"THK017": "Boots of Jumping (Boss) : le heros adverse ignore sa prochaine salle, joue seulement si cela le sauve de la marge exacte ; choisi 1 fois sur 21 offres avec tools-wiki (180 parties), 0 sur 15 offres sur les seeds 101-140",
	"THK018": "Pet Monster (Boss) : desactive la pire salle Monster restante devant le heros adverse, joue seulement si cela le sauve de la marge exacte ; choisi 2 fois sur 36 offres avec tools-wiki (180 parties), 0 sur 23 offres sur les seeds 101-140",
	"THK022": "Burial Mound : defausse 2 salles pour remettre un Objet en service, joue seulement avec 5 cartes en main ou plus ; choisi 4 fois sur 10 offres avec tools-wiki seul, 0 sur 2 offres avec tous les paquets (60 parties)",
	"RMB059": "Cerebella : niveau 3 = les heros ignorent leur texte dans un donjon ; sans objet quand aucun heros n'a de capacite de carte (les heros RMB n'en ont pas, hors les noirs dont le paiement en Coins n'est pas valorise par l'IA) : offert 8 fois sur 60 parties, 0 choix",
}
const SoakSeed = preload("res://godot/tests/soak_seed.gd")

var offered: Dictionary = {}   # cle -> nombre de parties ou le coup a ete legal
var chosen: Dictionary = {}    # cle -> nombre de parties ou l'IA l'a choisi
var _g_offered: Dictionary = {}
var _g_chosen: Dictionary = {}
var level3: Dictionary = {}    # id de miniboss -> nombre de parties ou il a atteint le niveau 3 (revele)
var _g_level3: Dictionary = {}
var _m = null
var _count := ""   # --count=useItem : affiche choisi/offert (en parties) de chaque cle commencant par ce prefixe
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
		elif a.begins_with("--count="):
			_count = a.substr(8)
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
			_g_level3 = {}
			if _play(n, sets, seed0 + g):
				done += 1
			else:
				stuck += 1
				print("CENSUS BLOQUEE seed=", seed0 + g, " joueurs=", n, " phase=", _m.G.get("phase") if is_instance_valid(_m) else "?")
			for k in _g_offered:
				offered[k] = int(offered.get(k, 0)) + 1
			for k in _g_chosen:
				chosen[k] = int(chosen.get(k, 0)) + 1
			for k in _g_level3:
				level3[k] = int(level3.get(k, 0)) + 1
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
	if _count != "":
		var lines: Array = []
		for k in offered:
			if str(k).begins_with(_count):
				lines.append("%s %d/%d" % [k, int(chosen.get(k, 0)), int(offered[k])])
		lines.sort()
		print("CENSUS compteurs (choisi/offert en parties) : ", lines)
	print("CENSUS jamais choisi: ", never)
	print("CENSUS rarement choisi (<25%): ", rare)
	var unseen: Array = []
	var card_set: Dictionary = {}   # id -> paquet
	for list in [CardDB.rooms, CardDB.spells, CardDB.minibosses, CardDB.items]:
		for c in list:
			var d: Dictionary = c
			var id := str(d.get("id", ""))
			card_set[id] = _pack_of(d, sets)
			if not sets.has(card_set[id]) or card_set[id] == "base":
				continue
			var seen := false
			for k in offered:
				seen = seen or (":" + str(k) + ":").contains(":" + id + ":")
			if not seen:
				unseen.append(id + " " + str(d.get("name", "")))
	print("CENSUS jamais offert (cartes du/des paquets): ", unseen)
	var mb_l3: Array = []   # minibosses des paquets demandes dont le pouvoir de niveau 3 n'a jamais ete offert
	if sets.has(Minibosses.SET_ID):
		var l3_line: Array = []
		for c in CardDB.minibosses:
			var mid := str((c as Dictionary).get("id", ""))
			l3_line.append("%s %s: niveau 3 atteint %d, offert %d" % [mid, str((c as Dictionary).get("name", "")), int(level3.get(mid, 0)), int(offered.get("activateMiniboss:%s:3" % mid, 0))])
			if not offered.has("activateMiniboss:%s:3" % mid):
				mb_l3.append(mid)
		print("CENSUS minibosses (niveau 3 atteint / pouvoir de niveau 3 offert, en parties): ", l3_line)
	# Verdict : une cle jamais choisie n'est tolerable que si la carte est dans ALLOW ; seules les cartes des paquets demandes comptent.
	var failed: Array = []
	var allowed: Array = []
	for u in unseen:   # une carte d'un paquet wiki demande qui n'est jamais offerte echoue, sauf ligne ALLOW chiffree (les decks de l'APK ont leur propre IA : ApkAI)
		var uid: String = str(u).split(" ")[0]
		if Match.APK_SETS.has(card_set[uid]):
			continue
		if ALLOW.has(uid):
			allowed.append("%s (jamais offert) : %s" % [uid, ALLOW[uid]])
		else:
			failed.append("%s jamais offert" % uid)
	for mid in mb_l3:
		if ALLOW.has(mid):
			allowed.append("%s (pouvoir de niveau 3 jamais offert) : %s" % [mid, ALLOW[mid]])
		else:
			failed.append("%s : pouvoir de niveau 3 jamais offert" % mid)
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

## Paquet recense d'une carte : les cartes « tools » (THK) sont des cartes WIKI quand la case wiki (`tools-wiki`) est demandee ; sans elle, c'est le deck inerte de l'APK.
func _pack_of(d: Dictionary, sets: Array) -> String:
	var st := str(d.get("set", "base"))
	return ThkAbilities.SET_ID if st == "tools" and sets.has(ThkAbilities.SET_ID) else st

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
		"useItem": # Tools of Hero-Kind : capacite de Boss d'un Objet face visible
			return t + ":" + str(a[0])
		"resolveChoice": # Magnetic Ceiling (declencheur facultatif) : prendre l'Objet du heros (indice >= 0) plutot que refuser (-1)
			var pc: Dictionary = G.get("pendingChoice", {})
			if str(pc.get("step", "")) == "thk_ceiling" and not a.is_empty() and int(a[0]) >= 0:
				return "resolveChoice:THK024"
		"rmbBoss":
			return t + ":" + str(a[0])
		"rmbPay":
			return t + ":RMB046"
		"payDarkHero", "payDarkCoins":
			return t + ":" + str(a[2])
		"buildMiniboss": # [carte de la main, emplacement]
			var bi := int(a[0]) if not a.is_empty() else -1
			if bi >= 0 and bi < hand.size():
				return t + ":" + str((hand[bi] as Dictionary).get("id", ""))
		"promoteMiniboss": # [emplacement, carte a defausser (Calabeza) ou -1] ; le niveau vise = niveau actuel + 1
			var pi := int(a[0]) if not a.is_empty() else -1
			if pi >= 0 and pi < dungeon.size():
				var pm: Dictionary = Minibosses.revealed(BossEngine.active_room(dungeon[pi]))
				if not pm.is_empty():
					return t + ":" + Minibosses.mb_id(pm) + ":" + str(Minibosses.level(pm) + 1)
		"rmbCancel", "docScarecrow", "discardForCoin", "timebenderCancel":
			return t + ":"
	return ""

func _note_levels(m) -> void:
	for e in Minibosses.all_mbs(m.G):
		if Minibosses.level((e as Dictionary)["mb"]) >= 3:
			_g_level3[Minibosses.mb_id((e as Dictionary)["mb"])] = true

func _on_decision(m, pid: int, moves: Array, best) -> void:
	_note_levels(m)
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
	var wiki := func(c): return str((c as Dictionary).get("set", "base")) != "base" and sets.has(_pack_of(c as Dictionary, sets))
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
		print("  pausePassed=", m.G.get("adventurePausePassed"), " stackActive=", m.G.get("stackActivePlayer"), " stackReturn=", m.G.get("stackReturnPlayer"), " log=", (m.G.get("log", []) as Array).slice(-8))
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
