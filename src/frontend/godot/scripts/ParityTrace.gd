class_name ParityTrace
extends RefCounted
## Rejoue une trace generee par tools/parity/gen.mjs dans le moteur GDScript et
## produit la meme projection canonique que tools/parity/canon.mjs.
##
## Le harnais de parite compare des invariants, pas des dictionnaires bruts : les
## deux moteurs stockent l'etat differemment (logs/log, activePlayer/xpOrder,
## adventure inexistant cote GDScript). Voir tools/parity/canon.mjs.
##
## Les noms de coups ne sont pas identiques non plus : le JS repond a un choix
## par "resolveLevelUpChoice", le port par "resolveChoice".

# Les deux moteurs nomment differemment la resolution d'un choix en attente.
const MOVE_ALIASES := {
	"resolveLevelUpChoice": "resolveChoice",
	"pass": "passBuild",
	"resolveNextHero": "adventureNext",
}

# Differences structurelles connues, declarees ici pour ne pas les compter comme
# des regressions. Chaque entree est un ecart de Phase 2/3/4, pas un bug du
# harnais. Voir docs/ROADMAP.md.
const KNOWN_GAPS := [
	"adventure",
	"stack",
	"players.0.coins",
	"players.0.items",
	"players.0.passed",
	"townItems",
	"decks.items",
	"decks.minibosses",
	"discards.items",
	"discards.miniboss",
]


static func _arr(v) -> Array:
	return v if v is Array else []


static func _int(v) -> int:
	if v is float or v is int:
		return int(v)
	return 0


static func _id(v):
	if v == null:
		return null
	if v is Dictionary and v.has("id"):
		return v["id"]
	return v


## Un slot de donjon peut contenir une pile de salles empilees, ou une salle
## seule selon le moteur. On normalise en tableau dans les deux cas.
static func _stack(v) -> Array:
	if v is Array:
		return v
	return [v] if v != null else []


static func _dungeon(rooms: Array) -> Array:
	var out: Array = []
	for slot in rooms:
		var stack: Array = []
		for r in _stack(slot):
			var d: Dictionary = r if r is Dictionary else {}
			stack.append({
				"id": d.get("id", null),
				"dmg": _int(d.get("damage", 0)),
				"vis": d.get("visible", false) == true,
				"act": d.get("activated", false) == true,
				"used": d.get("usedThisTurn", false) == true,
			})
		out.append(stack)
	return out


static func _dungeon_ids(rooms: Array) -> Array:
	var out: Array = []
	for slot in rooms:
		for r in _stack(slot):
			out.append((r as Dictionary).get("id", null) if r is Dictionary else null)
	out.sort()
	return out


## Meme projection que canon.mjs, champ par champ et dans le meme ordre.
static func canon(G: Dictionary) -> Dictionary:
	var players: Array = []
	var pids: Array = (G.get("players", {}) as Dictionary).keys()
	pids.sort_custom(func(a, b): return int(a) < int(b))
	for pid in pids:
		var p: Dictionary = G["players"][pid]
		var hand: Array = []
		for c in _arr(p.get("hand", [])):
			hand.append((c as Dictionary).get("id", null))
		var entrance: Array = []
		for h in _arr(p.get("entrance", [])):
			entrance.append("%s:%d" % [(h as Dictionary).get("id", null), _int((h as Dictionary).get("wounds", 0))])
		var items: Array = []
		for i in _arr(p.get("items", [])):
			items.append(_id(i))
		var boss: Dictionary = p.get("boss", null) if p.get("boss", null) is Dictionary else {}
		players.append({
			"id": _int(pid),
			"souls": _arr(p.get("souls", [])).size(),
			"wounds": _arr(p.get("wounds", [])).size(),
			"coins": p.get("coins", null),
			"eliminated": p.get("eliminated", false) == true,
			"leveledUp": p.get("leveledUp", false) == true,
			"builds": _int(p.get("buildsThisTurn", 0)),
			"passed": p.get("passed", false) == true,
			"boss": boss.get("id", null),
			"bossXp": _int(boss.get("xp", 0)) if not boss.is_empty() else null,
			"hand": hand,
			"dungeon": _dungeon(_arr(p.get("dungeon", []))),
			"dungeonIds": _dungeon_ids(_arr(p.get("dungeon", []))),
			"entrance": entrance,
			"items": items,
		})

	var decks: Dictionary = G.get("decks", {}) as Dictionary
	var pc: Dictionary = G.get("pendingChoice", {}) as Dictionary
	# Match.active_player() lit xpOrder[0] et non activePlayer : on reproduit sa
	# convention, sinon le champ "active" serait une divergence permanente.
	var xp: Array = _arr(G.get("xpOrder", []))
	var active: Variant = G.get("activePlayer", null)
	if active == null:
		active = _int(xp[0]) if not xp.is_empty() else 0
	var town: Array = []
	for h in _arr(G.get("town", [])):
		var hd: Dictionary = h as Dictionary
		town.append({
			"id": hd.get("id", null),
			"name": hd.get("name", null),
			"wounds": _int(hd.get("wounds", 0)),
			"epic": hd.get("epic", false) == true,
		})
	var town_items: Array = []
	for i in _arr(G.get("townItems", [])):
		town_items.append(_id(i))

	return {
		"phase": G.get("phase", null),
		"turn": _int(G.get("turn", 0)),
		"active": active,
		"gameOver": G.get("gameOver", null) != null,
		"winner": G.get("winner", null),
		"pendingChoice": ({"type": pc.get("type", null), "playerId": pc.get("playerId", null), "options": _arr(pc.get("options", [])).size()} if not pc.is_empty() else null),
		"players": players,
		"town": town,
		"townItems": town_items,
		"decks": {
			"rooms": _arr(decks.get("rooms", [])).size(),
			"spells": _arr(decks.get("spells", [])).size(),
			"heroes": _arr(decks.get("heroes", [])).size(),
			"epics": _arr(decks.get("epics", [])).size(),
			"items": _arr(decks.get("items", [])).size(),
			"minibosses": _arr(decks.get("minibosses", [])).size(),
		},
		"discards": {
			"room": _arr(decks.get("roomDiscard", [])).size(),
			"spell": _arr(decks.get("spellDiscard", [])).size(),
			"hero": _arr(decks.get("heroDiscard", [])).size(),
			"items": _arr(decks.get("itemsDiscard", [])).size(),
			"miniboss": _arr(decks.get("minibossDiscard", [])).size(),
		},
		"stack": _arr(G.get("stack", [])).size(),
		"adventure": null,
	}


## Adapte un etat JS aux conventions de stockage du port GDScript.
## Les deux moteurs n'ont jamais partage la meme forme d'etat : on convertit
## une fois ici plutot que de disperser des .get() defensifs partout.
## Les cles d'objet JS sont toujours des chaines ; Match.gd indexe les joueurs
## par un int (players[i]). On retranscrit les cles numeriques en int.
static func _rekey(src: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for k in src.keys():
		if k is String and str(k).is_valid_int():
			out[int(k)] = src[k]
		else:
			out[k] = src[k]
	return out


## JSON.parse renvoie tous les nombres en float : "args":[0] redevient [0.0] et
## str([0.0]) != str([0]), donc apply_move ne trouve plus le coup dans legal_moves.
## Les arguments de coups sont des index, des ids et des booleens de tri : on peut
## tous les remettre en int sans perte.
static func _coerce(v) -> Variant:
	if v is float:
		return int(v) if v == floor(v) else v
	if v is Array:
		return v.map(func(x): return _coerce(x))
	if v is Dictionary:
		var d: Dictionary = {}
		for k in (v as Dictionary).keys():
			d[k] = _coerce((v as Dictionary)[k])
		return d
	return v


static func adopt(js_G: Dictionary) -> Dictionary:
	var G: Dictionary = js_G.duplicate(true)
	# Match._log() lit G["log"] ; le JS stocke "logs".
	G["log"] = _arr(G.get("logs", []))
	G.erase("logs")
	# Match.legal_moves() fait .is_empty() sur pendingChoice ; le JS y met null.
	if G.get("pendingChoice", null) == null:
		G["pendingChoice"] = {}
	if G.get("choiceQueue", null) == null or not (G["choiceQueue"] is Array):
		G["choiceQueue"] = []
	if G.get("roboboQueue", null) == null or not (G["roboboQueue"] is Array):
		G["roboboQueue"] = []
	# Convention opposee : le JS met gameOver=false tant que la partie tourne, le
	# port teste "G.get('gameOver') != null" pour savoir si elle est finie.
	if G.get("gameOver", null) == false:
		G["gameOver"] = null
	if not G.has("stack") or not (G["stack"] is Array):
		G["stack"] = []
	if not G.has("stackPassed") or not (G["stackPassed"] is Dictionary):
		G["stackPassed"] = {}
	# JSON.parse renvoie des nombres en float : on remet des ints la ou le port
	# compare par egalite (phase, xpOrder, numero de joueur).
	G["turn"] = _int(G.get("turn", 0))
	G["xpOrder"] = (G.get("xpOrder", []) as Array).map(func(v): return _int(v))
	# Indexation par identifiant de joueur.
	for k in ["players", "stackPassed", "adventurePausePassed"]:
		if G.get(k, null) is Dictionary:
			G[k] = _rekey(G[k] as Dictionary)
	for pid in G.get("players", {}):
		(G["players"][pid] as Dictionary)["id"] = int(pid)
	# Le port joue automatiquement les sieges IA ; le JS non (son IA est appelee
	# par le pilote qui genere la trace). On desactive l'auto-jeu, sinon le
	# moteur avancerait de plusieurs phases pendant que la trace conduit les coups.
	# Le port gere le tour de BUILD avec buildOrder/buildIndex (BuildPhase_a est
	# sequentiel). Ces cles n'existent pas cote JS : sans elles, _advance_build()
	# croit la phase terminee et passe directement au leurre.
	var order: Array = []
	for pid in CardDB.order_by_xp(G["players"]):
		var i := int(pid)
		if (G["players"][i] as Dictionary).get("eliminated", false):
			continue
		order.append(i)
	var active := _int(G.get("activePlayer", order[0] if not order.is_empty() else 0))
	var idx := order.find(active)
	if idx > 0:
		var rotated: Array = []
		for j in range(idx, order.size()):
			rotated.append(order[j])
		for j in range(0, idx):
			rotated.append(order[j])
		order = rotated
	G["buildOrder"] = order
	G["buildIndex"] = 0

	G["autoAI"] = false
	# Le port n'a pas d'etat d'aventure persistant : Match.resout l'aventure en
	# un seul pas. On retire la cle pour ne pas laisser un etat faux.
	G["adventure"] = {}
	return G


## Rejoue une trace. Retourne { snapshots, errors }.
static func replay(trace: Dictionary) -> Dictionary:
	# "match" est un mot reserve GDScript : la variable locale s'appelle run.
	var run := Match.new()
	var initial = trace.get("initial", null)
	if not (initial is Dictionary):
		return {
			"snapshots": [],
			"errors": [{"step": -1, "reason": "trace sans etat initial (n'a jamais atteint la phase BUILD)"}],
		}
	run.G = adopt((initial as Dictionary).get("G", {}) as Dictionary)

	var snapshots: Array = [canon(run.G)]
	var errors: Array = []

	var step_index := -1
	for step in _arr(trace.get("steps", [])):
		step_index += 1
		var s: Dictionary = step as Dictionary
		var pid: int = _int(s.get("pid", 0))
		var move: Dictionary = (s.get("move", {}) as Dictionary).duplicate(true)
		var t: String = str(move.get("type", ""))
		if MOVE_ALIASES.has(t):
			t = str(MOVE_ALIASES[t])
			move["type"] = t
		if move.has("args"):
			move["args"] = _coerce(move["args"])

		if not run.apply_move(pid, move):
			# Si c'est un pass de priorite non requis par le port (ex: sort resolu de facon synchrone),
			# on conserve l'etat courant et on avance l'index de snapshot en accord avec le JS.
			if t == "passBuild" or t == "pass":
				snapshots.append(canon(run.G))
				continue
			var pl: Dictionary = (run.G.get("players", {}) as Dictionary).get(pid, {}) as Dictionary
			errors.append({
				"step": step_index,
				"pid": pid,
				"move": str(move.get("type", "")),
				"args": move.get("args", []),
				"reason": "coup refuse (legal_moves ne le propose pas)",
				"legal": run.legal_moves(pid).map(func(m): return str((m as Dictionary).get("type", ""))).slice(0, 8),
				"state": {
					"phase": run.G.get("phase", null),
					"gameOver": run.G.get("gameOver", null),
					"pendingChoice": run.G.get("pendingChoice", {}),
					"hasPlayer": (run.G.get("players", {}) as Dictionary).has(pid),
					"eliminated": pl.get("eliminated", null),
					"boss": pl.get("boss", null),
					"active": run.active_player(),
					"buildOrder": run.G.get("buildOrder", []),
					"buildIndex": run.G.get("buildIndex", -1),
					"autoAI": run.G.get("autoAI", null),
				},
			})
			# On arrete la trace : rejouer un coup refuse n'aurait aucun sens et
			# toutes les divergences suivantes seraient du bruit.
			break

		snapshots.append(canon(run.G))

	return { "snapshots": snapshots, "errors": errors }