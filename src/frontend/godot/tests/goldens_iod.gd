extends RefCounted
## Goldens de l'extension wiki Implements of Destruction (IOD : 24 Objets + 5 Boss). Hors APK : tout ce qui suit n'existe que derriere la case wiki
## (pseudo-paquet `iod`). Une carte = au moins un golden pour le Power-Up (Objets) puis pour la capacite de Boss (Reward).
## References : docs/rules/rules.md (section Items), texte des cartes (cards.json). Non jouee : IOD018 (sixieme salle), IOD011, IOD007, IOD023, IOD026.
## Appele par goldens.gd : `load("res://godot/tests/goldens_iod.gd").new().run(_ok, self)`.

var _ok: Callable
var host: Node

func run(ok: Callable, h: Node) -> void:
	_ok = ok
	host = h
	_t_gating()
	_t_claim_rules()
	_t_hero_boosts()
	_t_skips()
	_t_damage_items()
	_t_hand_items()
	_t_room_items()
	_t_hero_items()
	_t_bosses()
	_t_flow()

# --- fabriques ------------------------------------------------------------------------------------------------------------------

func _item(id: String) -> Dictionary:
	for c in CardDB.items:
		if str((c as Dictionary).get("id", "")) == id:
			return (c as Dictionary).duplicate(true)
	push_error("objet introuvable " + id)
	return {}

func _boss(id: String) -> Dictionary:
	for c in CardDB.bosses:
		if str((c as Dictionary).get("id", "")) == id:
			return (c as Dictionary).duplicate(true)
	push_error("boss introuvable " + id)
	return {}

func _h(id: String, hp: int = 6, treasure: int = 2, epic: bool = false) -> Dictionary:
	return {"id": id, "name": id, "hp": hp, "treasure": treasure, "treasures": [treasure], "class": "x", "souls": 2 if epic else 1, "wounds": 2 if epic else 1, "epic": epic}

func _with(h: Dictionary, id: String) -> Dictionary:
	h["item"] = _item(id)
	return h

func _plain(id: String, type: String = "trap", treasures: Array = [1], damage: int = 1, advanced: bool = false) -> Dictionary:
	return {"id": id, "name": id, "type": type, "advanced": advanced, "treasures": treasures, "damage": damage, "isRoom": true}

func _spl(id: String) -> Dictionary:
	return {"id": id, "name": id, "isSpell": true, "category": 3}

func _player(pid: int, dungeon: Array = []) -> Dictionary:
	var stacks: Array = []
	for r in dungeon:
		stacks.append([r])
	var boss: Dictionary = {"id": "BMA001", "name": "B", "xp": 900, "treasures": [1]} if pid == 0 else {"id": "BMA002", "name": "B2", "xp": 800, "treasures": [3]}
	return {"id": pid, "boss": boss, "dungeon": stacks, "hand": [], "souls": [], "wounds": [], "entrance": [], "eliminated": false, "leveledUp": false, "buildsThisTurn": 0, "coins": 3, "items": []}

func _G(players: Array, sets: Array = ["base", "iod", "crash-landing"]) -> Dictionary:
	var ps := {}
	for p in players:
		ps[int((p as Dictionary)["id"])] = p
	var spells: Array = []
	for i in 8:
		spells.append(_spl("SP%d" % i))
	var rooms: Array = []
	for i in 8:
		rooms.append(_plain("RD%d" % i))
	return {"players": ps, "town": [], "townItems": [], "log": [], "logs": [], "adventure": {}, "turn": 3, "phase": "build", "activePlayer": 0,
		"buildOrder": [0, 1], "buildIndex": 0, "sets": sets, "effects": SpellEffects.empty_effects(), "stack": [], "pendingChoice": {}, "choiceQueue": [],
		"decks": {"rooms": rooms, "spells": spells, "heroes": [], "epics": [], "items": [], "roomDiscard": [], "spellDiscard": [], "heroDiscard": []}}

func _match(G: Dictionary) -> Node:
	var m = load("res://godot/scripts/Match.gd").new()
	host.add_child(m)
	m.G = G
	return m

## Une vraie partie 2 joueurs (iod + crash-landing), videe pour un scenario : phase Adventure, joueur 0 actif.
func _live() -> Array:
	var m = load("res://godot/scripts/Match.gd").new()
	host.add_child(m)
	var G: Dictionary = m.new_match(2, 1, ["iod", "crash-landing"])
	for pid in [0, 1]:
		var p: Dictionary = G["players"][pid]
		p["boss"] = _player(pid)["boss"]
		p["leveledUp"] = false
		p["dungeon"] = []
		p["entrance"] = []
		p["hand"] = []
		p["wounds"] = []
		p["souls"] = []
		p["items"] = []
		p["coins"] = 3
	G["town"] = []
	G["townItems"] = []
	G["adventure"] = {}
	G["pendingChoice"] = {}
	G["choiceQueue"] = []
	G["stack"] = []
	G["phase"] = "adventure"
	G["activePlayer"] = 0
	G["turn"] = 3
	return [m, G]

func _dungeon(G: Dictionary, pid: int, rooms: Array) -> void:
	var stacks: Array = []
	for r in rooms:
		stacks.append([r])
	(G["players"][pid] as Dictionary)["dungeon"] = stacks

func _adv(G: Dictionary, pid: int, hero: Dictionary, idx: int, hp: int) -> void:
	G["adventure"] = {"playerId": pid, "hero": hero, "roomIndex": idx, "hp": hp, "pause": "post-damage"}
	G["phase"] = "adventure"
	G["activePlayer"] = pid

func _entrance(G: Dictionary, pid: int, hero: Dictionary) -> void:
	((G["players"][pid] as Dictionary)["entrance"] as Array).append(hero)

func _next(m: Node, pid: int = 0) -> bool:
	var ok: bool = m.apply_move(pid, {"type": "adventureNext", "args": []})
	for _r in 6:
		var adv: Dictionary = m.G.get("adventure", {})
		if adv.is_empty() or adv.get("pause") == null or not (m.G["pendingChoice"] as Dictionary).is_empty():
			break
		for q in [0, 1]:
			m.apply_move(q, {"type": "pass", "args": []})
	return ok

func _drain(m: Node, idx: int = 0) -> int:
	var n := 0
	while not (m.G["pendingChoice"] as Dictionary).is_empty() and n < 30:
		var pc: Dictionary = m.G["pendingChoice"]
		var i := idx if idx < (pc.get("options", []) as Array).size() else 0
		m._resolve_choice(int(pc["playerId"]), i)
		n += 1
	return n

func _pending(G: Dictionary) -> Dictionary:
	return G["pendingChoice"] as Dictionary

func _p(G: Dictionary, pid: int) -> Dictionary:
	return G["players"][pid] as Dictionary

func _hand(G: Dictionary, pid: int) -> Array:
	return _p(G, pid)["hand"] as Array

func _ids(arr: Array) -> Array:
	var out: Array = []
	for c in arr:
		out.append(str((c as Dictionary).get("id", "")))
	return out

func _owned(G: Dictionary, pid: int, id: String, face_down: bool = false) -> Dictionary:
	var it := _item(id)
	it["faceDown"] = face_down
	it["acquiredTurn"] = 1
	(_p(G, pid)["items"] as Array).append(it)
	return it

func _use(G: Dictionary, pid: int, id: String) -> Variant:
	return ThkAbilities.use_item(G, pid, id)

## Joue l'Objet `id` puis resout le choix ouvert par l'option `idx` (par la Match du plateau).
func _use_pick(G: Dictionary, pid: int, id: String, idx: int = 0) -> void:
	_use(G, pid, id)
	if not _pending(G).is_empty():
		_match(G)._resolve_choice(int(_pending(G)["playerId"]), idx)

func _deactivated(G: Dictionary, pid: int, idx: int) -> bool:
	return BossEngine.is_room_deactivated(G, pid, idx)

func _wounds(G: Dictionary, pid: int, n: int) -> void:
	for i in n:
		(_p(G, pid)["wounds"] as Array).append({"name": "w", "wounds": 1, "souls": 1, "hero": _h("W%d" % i), "turn": 1})

func _souls(G: Dictionary, pid: int, n: int) -> void:
	for i in n:
		(_p(G, pid)["souls"] as Array).append({"souls": 1, "name": "s", "class": "x", "faceDown": true, "hero": _h("S%d" % i)})

# --- gating -------------------------------------------------------------------------------------------------------------------------

func _t_gating() -> void:
	var m1 = load("res://godot/scripts/Match.gd").new()
	host.add_child(m1)
	var G1: Dictionary = m1.new_match(2, 1, ["iod"])
	_ok.call(ThkAbilities.active(G1) and Match.wiki_active(G1) and not (G1["sets"] as Array).has("tools"), "IOD : le pseudo-paquet `iod` active le moteur des Objets et le mode wiki, sans poser « tools »")
	var deck_ids := _ids(G1["decks"]["items"]) + _ids(G1.get("townItems", [])) + _attached(G1)
	_ok.call(deck_ids.size() == 17 and not deck_ids.any(func(i): return str(i).begins_with("THK")), "IOD sans Crash Landing : 17 Objets (4 Explorer ecartes, 3 non implementes hors pioche), aucun Objet THK (%d)" % deck_ids.size())
	var explorers := 0
	for i in deck_ids:
		explorers += 1 if int(_item(str(i)).get("treasure", 0)) == 5 else 0
	_ok.call(explorers == 0, "IOD sans Crash Landing : aucun Objet Explorer")
	var boss_ids := _ids(G1["bossPicks"])
	_ok.call(not boss_ids.has("IOD025") and not boss_ids.has("IOD026") and boss_ids.has("IOD029"), "IOD sans Crash Landing : Banseer Bivan (IOD025) est ecarte, Malakill (non implemente) aussi")
	var m2 = load("res://godot/scripts/Match.gd").new()
	host.add_child(m2)
	var G2: Dictionary = m2.new_match(2, 1, ["iod", "crash-landing"])
	var ids2 := _ids(G2["decks"]["items"]) + _ids(G2.get("townItems", [])) + _attached(G2)
	_ok.call(ids2.size() == 20 and _ids(G2["bossPicks"]).has("IOD025"), "IOD avec Crash Landing : 20 Objets jouables et Banseer Bivan")
	# sans la case wiki (paquet de l'APK seul) : aucun Objet IOD
	var m3 = load("res://godot/scripts/Match.gd").new()
	host.add_child(m3)
	var G3: Dictionary = m3.new_match(2, 1, ["players-choice", "hidden-heroes", "tools"])
	_ok.call(not ThkAbilities.active(G3) and not _ids(G3["decks"]["items"]).any(func(i): return str(i).begins_with("IOD")), "IOD : jamais dans les paquets de l'APK")
	# Objets THK ecartes si IOD est actif sans la case Tools
	var m4 = load("res://godot/scripts/Match.gd").new()
	host.add_child(m4)
	var G4: Dictionary = m4.new_match(2, 1, ["iod", "tools"])
	_ok.call(not (_ids(G4["decks"]["items"]) + _ids(G4.get("townItems", [])) + _attached(G4)).any(func(i): return str(i).begins_with("THK")), "IOD + tools sans tools-wiki : les Objets THK restent inertes (ecartes)")
	# les 29 cartes ont un drapeau implemented coherent et un Objet = un Power-Up + un Reward dans le texte
	var items := CardDB.items.filter(func(c): return str((c as Dictionary).get("set", "")) == "iod")
	_ok.call(items.size() == 24 and items.all(func(c): return str((c as Dictionary).get("description", "")).contains("Power-Up:") and str((c as Dictionary).get("description", "")).contains("Reward:")), "IOD : 24 Objets, chacun avec Power-Up et Reward")

func _attached(G: Dictionary) -> Array:
	var out: Array = []
	for h in (G["town"] as Array):
		if (h as Dictionary).has("item"):
			out.append(str(h["item"]["id"]))
	return out

# --- reclamation d'Objet : Pandora's Box et Banseer Bivan ----------------------------------------------------------------------------

func _t_claim_rules() -> void:
	# IOD019 Pandora's Box : « You must take this Item face-up », les Objets suivants partent face cachee tant qu'elle est face visible
	var G := _G([_player(0), _player(1)])
	var first := _owned(G, 0, "IOD012")
	var r = ThkAbilities.claim_item(G, 0, _item("IOD019"))
	var items: Array = _p(G, 0)["items"]
	_ok.call(r == null and bool(first["faceDown"]) and not bool(items[1]["faceDown"]) and str(items[1]["id"]) == "IOD019", "IOD019 Pandora's Box : prise face visible, l'Objet face visible precedent passe face cachee")
	var r2 = ThkAbilities.claim_item(G, 0, _item("IOD013"))
	_ok.call(r2 == null and bool(_p(G, 0)["items"][2]["faceDown"]), "IOD019 Pandora's Box : tant qu'elle est face visible, tout nouvel Objet est place face cachee")
	# Reward : defausser un sort pour la retourner face cachee
	G["turn"] = 4
	var pm := _match(G)
	_hand(G, 0).append(_spl("DX"))
	_ok.call(ThkAbilities.effect_check(G, 0, "IOD019") == "" and not ThkAbilities.use_moves(G, _p(G, 0), 0).is_empty(), "IOD019 Pandora's Box (Boss) : jouable avec un sort en main")
	_use_pick(G, 0, "IOD019")
	_ok.call(bool(_p(G, 0)["items"][1]["faceDown"]) and _hand(G, 0).is_empty() and (G["decks"]["spellDiscard"] as Array).size() == 1, "IOD019 Pandora's Box (Boss) : un sort defausse, l'Objet est retourne face cachee")
	var G0 := _G([_player(0), _player(1)])
	_owned(G0, 0, "IOD019")
	_ok.call(ThkAbilities.effect_check(G0, 0, "IOD019") != "", "IOD019 : sans sort en main, la capacite n'est pas offerte")
	pm.queue_free()
	# IOD025 Banseer Bivan : deux Objets face visible
	var GB := _G([_player(0), _player(1)])
	_p(GB, 0)["iodBoss"] = {"IOD025": true}
	_p(GB, 0)["leveledUp"] = true
	ThkAbilities.claim_item(GB, 0, _item("IOD012"))
	ThkAbilities.claim_item(GB, 0, _item("IOD013"))
	var ups := (_p(GB, 0)["items"] as Array).filter(func(it): return not bool((it as Dictionary)["faceDown"]))
	_ok.call(ups.size() == 2, "IOD025 Banseer Bivan : deux Objets face visible sans choix")
	var ch = ThkAbilities.claim_item(GB, 0, _item("IOD001"))
	_ok.call(ch is Dictionary and str((ch as Dictionary)["step"]) == "thk_iod_claim2" and ((ch as Dictionary)["options"] as Array).size() == 3, "IOD025 Banseer Bivan : un troisieme Objet ouvre le choix de celui qui part face cachee")
	ThkAbilities.resolve_pick(GB, 0, ch, 2) # le nouveau part face cachee
	var ups2 := (_p(GB, 0)["items"] as Array).filter(func(it): return not bool((it as Dictionary)["faceDown"]))
	_ok.call(ups2.size() == 2 and (_p(GB, 0)["items"] as Array).size() == 3, "IOD025 Banseer Bivan : jamais plus de deux Objets face visible")
	var GN := _G([_player(0), _player(1)])
	ThkAbilities.claim_item(GN, 0, _item("IOD012"))
	var ch1 = ThkAbilities.claim_item(GN, 0, _item("IOD013"))
	_ok.call(ch1 is Dictionary and str((ch1 as Dictionary)["step"]) == "thk_claim", "IOD : sans Banseer Bivan, le choix classique du livret (un seul Objet face visible)")
	# les capacites des deux Objets face visible sont offertes
	G["turn"] = 9
	_p(GB, 0)["items"] = []
	_owned(GB, 0, "IOD005")
	_owned(GB, 0, "IOD008")
	GB["turn"] = 4
	_hand(GB, 0).append(_plain("R"))
	_ok.call(ThkAbilities.use_moves(GB, _p(GB, 0), 0).size() == 2, "IOD025 Banseer Bivan : les deux Objets face visible offrent un coup useItem")

# --- Objets qui donnent des PV : Mega Hammer, Angel Wings, Divining Rod, Doppelganger Cloak, Flying Saucer ------------------------------------

func _t_hero_boosts() -> void:
	# IOD001 Mega Hammer : double la Sante du heros
	var lv := _live()
	var m: Node = lv[0]
	var G: Dictionary = lv[1]
	_dungeon(G, 0, [_plain("A", "trap", [1], 3)])
	_entrance(G, 0, _with(_h("H1", 6, 2), "IOD001"))
	_next(m)
	_ok.call(int(G["adventure"]["hp"]) == 12 - 3, "IOD001 Mega Hammer (Power-Up) : Sante doublee (6 -> 12, 3 degats = 9)")
	# Reward : +2 par Blessure a un heros
	var G1 := _G([_player(0), _player(1)])
	_wounds(G1, 0, 3)
	var townie := _h("T1")
	G1["town"] = [townie]
	_owned(G1, 0, "IOD001")
	_use_pick(G1, 0, "IOD001")
	_ok.call(TnlAbilities._list(G1, "heroHp").any(func(e): return int((e as Dictionary)["amount"]) == 6 and str((e as Dictionary)["heroId"]) == "T1"), "IOD001 Mega Hammer (Boss) : +2 par Blessure (3 -> +6)")
	var G1b := _G([_player(0), _player(1)])
	G1b["town"] = [townie]
	_owned(G1b, 0, "IOD001")
	_ok.call(ThkAbilities.effect_check(G1b, 0, "IOD001") != "", "IOD001 : sans Blessure, la capacite de Boss n'est pas offerte")
	# IOD012 Angel Wings : +X (X = vos Ames)
	var lv2 := _live()
	var G2: Dictionary = lv2[1]
	_souls(G2, 0, 3)
	_dungeon(G2, 0, [_plain("A", "trap", [1], 2)])
	_entrance(G2, 0, _with(_h("H2", 5, 1), "IOD012"))
	_next(lv2[0])
	_ok.call(int(G2["adventure"]["hp"]) == 5 + 3 - 2, "IOD012 Angel Wings (Power-Up) : +3 PV avec 3 Ames")
	var G2b := _G([_player(0), _player(1)])
	_souls(G2b, 0, 2)
	G2b["town"] = [_h("T2")]
	_owned(G2b, 0, "IOD012")
	_use_pick(G2b, 0, "IOD012")
	_ok.call(TnlAbilities._list(G2b, "heroHp").any(func(e): return int((e as Dictionary)["amount"]) == 2), "IOD012 Angel Wings (Boss) : +2 PV avec 2 Ames")
	# IOD013 Divining Rod : +1 par type de tresor du donjon (Boss compris)
	var lv3 := _live()
	var G3: Dictionary = lv3[1]
	_dungeon(G3, 0, [_plain("A", "trap", [2], 1), _plain("B", "trap", [2, 3], 1), _plain("C", "trap", [4], 1)]) # Fighter, Mage, Thief + Boss Cleric = 4 types
	_entrance(G3, 0, _with(_h("H3", 5, 4), "IOD013"))
	_next(lv3[0])
	_ok.call(int(G3["adventure"]["hp"]) == 5 + 4 - 1, "IOD013 Divining Rod (Power-Up) : +1 par type de tresor, Boss compris (4)")
	var G3b := _G([_player(0, [_plain("A", "trap", [2]), _plain("B", "trap", [2])]), _player(1)])
	G3b["town"] = [_h("T3")]
	_owned(G3b, 0, "IOD013")
	_use_pick(G3b, 0, "IOD013")
	_ok.call(TnlAbilities._list(G3b, "heroHp").any(func(e): return int((e as Dictionary)["amount"]) == 2), "IOD013 Divining Rod (Boss) : 2 types (Fighter + Cleric du Boss) -> +2")
	# IOD020 Doppelganger Cloak : la plus haute Sante (ville et donjons)
	var lv4 := _live()
	var G4: Dictionary = lv4[1]
	G4["town"] = [_h("BIG", 12, 3)]
	_entrance(G4, 1, _h("MID", 9, 1))
	_dungeon(G4, 0, [_plain("A", "trap", [1], 2)])
	_entrance(G4, 0, _with(_h("H4", 4, 1), "IOD020"))
	_next(lv4[0])
	_ok.call(int(G4["adventure"]["hp"]) == 12 - 2, "IOD020 Doppelganger Cloak (Power-Up) : Sante = la plus haute de la ville et des donjons (12)")
	var G4b := _G([_player(0), _player(1)])
	var cl := _h("CL", 5, 3)
	var other := _h("OT", 5, 2)
	G4b["town"] = [cl, other]
	_owned(G4b, 0, "IOD020")
	_ok.call(ThkAbilities.effect_check(G4b, 0, "IOD020") == "", "IOD020 Doppelganger Cloak (Boss) : jouable en Construction avec un heros en ville")
	_use(G4b, 0, "IOD020")
	var pc4 := _pending(G4b)
	var pick := 0
	for i in (pc4["options"] as Array).size():
		var o: Dictionary = pc4["options"][i]
		if str((o["card"] as Dictionary)["id"]) == "CL" and int(o["type"]) == 4:
			pick = i
	_match(G4b)._resolve_choice(0, pick)
	_ok.call(int(cl.get("iodLure", 0)) == 4 and int(cl.get("iodLureTurn", -1)) == 3, "IOD020 Doppelganger Cloak (Boss) : le heros n'est leurre que par le type choisi")
	# le leurre suit : un seul type compte (Thief), le donjon J1 a plus de Thief que J0
	var GL := _G([_player(0, [_plain("A", "trap", [2])]), _player(1, [_plain("B", "trap", [4]), _plain("C", "trap", [4])])])
	var order := CardDB.order_by_xp(GL["players"])
	var lured := _h("LU", 5, 2)
	lured["iodLure"] = 4
	lured["iodLureTurn"] = 3
	_ok.call(BossEngine.lure_target(GL["players"], order, 2, lured, GL) == 1 and BossEngine.lure_target(GL["players"], order, 2, _h("NL", 5, 2), GL) == 0, "IOD020 : le heros ne compte que le type designe pour le leurre (sans Reward il va chez J0, Fighter)")
	lured["iodLureTurn"] = 2
	_ok.call(BossEngine.lure_target(GL["players"], order, 2, lured, GL) == 0, "IOD020 : le choix expire a la fin du tour")
	# IOD024 Flying Saucer : +3 si le donjon n'a que des salles ordinaires
	var lv5 := _live()
	var G5: Dictionary = lv5[1]
	_dungeon(G5, 0, [_plain("A", "trap", [5], 1)])
	_entrance(G5, 0, _with(_h("H5", 5, 5), "IOD024"))
	_next(lv5[0])
	_ok.call(int(G5["adventure"]["hp"]) == 5 + 3 - 1, "IOD024 Flying Saucer (Power-Up) : +3 avec des salles ordinaires seulement")
	var lv5b := _live()
	var G5b: Dictionary = lv5b[1]
	_dungeon(G5b, 0, [_plain("A", "trap", [5], 1), _plain("ADV", "trap", [5], 1, true)])
	_entrance(G5b, 0, _with(_h("H5b", 5, 5), "IOD024"))
	_next(lv5b[0])
	_ok.call(int(G5b["adventure"]["hp"]) == 5 - 1, "IOD024 Flying Saucer : une salle avancee annule le +3")
	var G5c := _G([_player(0), _player(1)])
	(G5c["decks"] as Dictionary)["rooms"] = [_plain("N1"), _plain("ADV1", "monster", [1], 1, true), _plain("N2"), _plain("ADV2", "trap", [2], 1, true)]
	_owned(G5c, 0, "IOD024")
	_use_pick(G5c, 0, "IOD024", 1)
	_ok.call(_ids(_hand(G5c, 0)) == ["ADV2"] and (G5c["decks"]["rooms"] as Array).size() == 3, "IOD024 Flying Saucer (Boss) : une salle Advanced de la pioche de salles rejoint la main")
	var G5d := _G([_player(0), _player(1)])
	(G5d["decks"] as Dictionary)["rooms"] = [_plain("N1")]
	_owned(G5d, 0, "IOD024")
	_ok.call(ThkAbilities.effect_check(G5d, 0, "IOD024") != "", "IOD024 : pas de salle Advanced dans la pioche -> injouable")

# --- sauts de salles : Energy Bow, Portal Wand, Secret Map, Minotaur's Mantle (2e passage) ---------------------------------------------------

func _t_skips() -> void:
	# IOD003 Energy Bow : les trois dernieres salles sont ignorees
	var lv := _live()
	var G: Dictionary = lv[1]
	_dungeon(G, 0, [_plain("A", "trap", [1], 1), _plain("B", "trap", [1], 1), _plain("C", "trap", [1], 5), _plain("D", "trap", [1], 5), _plain("E", "trap", [1], 5)])
	_entrance(G, 0, _with(_h("H1", 6, 2), "IOD003"))
	_next(lv[0])
	_next(lv[0])
	_next(lv[0])
	_drain(lv[0])
	_ok.call((_p(G, 0)["wounds"] as Array).size() >= 1 and (_p(G, 0)["souls"] as Array).is_empty(), "IOD003 Energy Bow (Power-Up) : le heros ignore C, D, E (2 degats, il survit)")
	# Reward : un heros a l'entree d'un autre donjon
	var G1 := _G([_player(0), _player(1, [_plain("A"), _plain("B"), _plain("C"), _plain("D")])])
	var tgt := _h("X", 6, 2)
	_entrance(G1, 1, tgt)
	_owned(G1, 0, "IOD003")
	_use_pick(G1, 0, "IOD003")
	_ok.call(int(tgt.get("iodBow", -1)) == 3, "IOD003 Energy Bow (Boss) : le heros designe est marque pour le tour")
	_adv(G1, 1, tgt, 0, 6)
	_ok.call(IodAbilities.on_room_exit(G1, 1, -1, 0) == 0 and IodAbilities.on_room_exit(G1, 1, 0, 1) == 4, "IOD003 Energy Bow : donjon de 4 salles, seule la premiere est jouee (apres elle, on saute a la fin)")
	var G1b := _G([_player(0), _player(1)])
	_owned(G1b, 0, "IOD003")
	_ok.call(ThkAbilities.effect_check(G1b, 0, "IOD003") != "", "IOD003 : aucun heros a l'entree d'un autre donjon -> injouable")
	# IOD006 Portal Wand : une salle ignoree par sort en main, en commencant par la premiere
	var lv2 := _live()
	var G2: Dictionary = lv2[1]
	_dungeon(G2, 0, [_plain("A", "trap", [1], 5), _plain("B", "trap", [1], 5), _plain("C", "trap", [1], 1)])
	_hand(G2, 0).append_array([_spl("S1"), _spl("S2")])
	_entrance(G2, 0, _with(_h("H2", 4, 3), "IOD006"))
	_next(lv2[0])
	_ok.call(int(G2["adventure"]["hp"]) == 4 - 1 and int(G2["adventure"]["roomIndex"]) == 2, "IOD006 Portal Wand (Power-Up) : 2 sorts en main -> les 2 premieres salles sont ignorees")
	var G2b := _G([_player(0), _player(1, [_plain("A"), _plain("B")])])
	var h2 := _h("Y", 6, 3)
	_entrance(G2b, 1, h2)
	_owned(G2b, 0, "IOD006")
	_use_pick(G2b, 0, "IOD006")
	_ok.call(bool(h2.get("iodSkip", false)), "IOD006 Portal Wand (Boss) : un heros qui n'est pas encore entre ignorera la prochaine salle")
	_adv(G2b, 1, h2, -1, 6)
	_ok.call(ThkAbilities.on_room_exit(G2b, 1, -1, 0) == 1 and not h2.has("iodSkip"), "IOD006 : la marque est consommee a l'entree (la 1re salle est ignoree)")
	var G2c := _G([_player(0), _player(1, [_plain("A"), _plain("B")])])
	var zh := _h("Z", 6, 3)
	_entrance(G2c, 1, zh)
	_adv(G2c, 1, zh, 0, 6)
	_owned(G2c, 0, "IOD006")
	_use_pick(G2c, 0, "IOD006")
	_ok.call(bool(G2c["adventure"].get("thkSkip", false)), "IOD006 Portal Wand (Boss) : sur le heros actif, comme Boots of Jumping")
	# IOD016 Secret Map : ignore les salles dont le tresor correspond a un heros de l'entree
	var lv3 := _live()
	var G3: Dictionary = lv3[1]
	_dungeon(G3, 0, [_plain("A", "trap", [4], 5), _plain("B", "trap", [1], 1), _plain("C", "trap", [2], 5), _plain("D", "trap", [3], 1)])
	_entrance(G3, 0, _with(_h("H3", 6, 4), "IOD016"))
	_entrance(G3, 0, _h("H3b", 6, 2)) # un Fighter attend aussi a l'entree
	_next(lv3[0])
	_ok.call(int(G3["adventure"]["roomIndex"]) == 1, "IOD016 Secret Map (Power-Up) : A (Thief) est ignoree, B (Cleric) est la premiere salle jouee")
	_next(lv3[0])
	_ok.call(int(G3["adventure"]["roomIndex"]) == 3 and int(G3["adventure"]["hp"]) == 6 - 1 - 1, "IOD016 Secret Map (Power-Up) : C (Fighter, tresor d'un autre heros de l'entree) est ignoree aussi")
	var G3b := _G([_player(0, [_plain("A"), _plain("B"), _plain("C")]), _player(1)])
	_owned(G3b, 0, "IOD016")
	_use_pick(G3b, 0, "IOD016", 0)
	_ok.call(_ids(_p(G3b, 0)["dungeon"].map(func(s): return s[0])) == ["C", "B", "A"] or _ids(_p(G3b, 1)["dungeon"].map(func(s): return s[0])) == [], "IOD016 Secret Map (Boss) : la premiere et la derniere salle d'un donjon sont echangees")
	# IOD002 Minotaur's Mantle : la premiere salle Fighter est desactivee
	var G4 := _G([_player(0, [_plain("A", "trap", [1]), _plain("F1", "trap", [2]), _plain("F2", "monster", [2])]), _player(1)])
	IodAbilities.on_hero_start(G4, 0, _with(_h("H4", 5, 2), "IOD002"), 5)
	_ok.call(_deactivated(G4, 0, 1) and not _deactivated(G4, 0, 2) and not _deactivated(G4, 0, 0), "IOD002 Minotaur's Mantle (Power-Up) : la premiere salle Fighter est desactivee")
	# Reward : une salle traversee deux fois par tous les heros
	var lv5 := _live()
	var G5: Dictionary = lv5[1]
	_dungeon(G5, 0, [_plain("A", "trap", [1], 1), _plain("B", "trap", [1], 2)])
	_entrance(G5, 0, _h("H5", 9, 3))
	_owned(G5, 0, "IOD002")
	G5["phase"] = "build"
	_use_pick(G5, 0, "IOD002", 1) # option B
	G5["phase"] = "adventure"
	_next(lv5[0])
	_next(lv5[0])
	_next(lv5[0])
	_ok.call(int(G5["adventure"]["hp"]) == 9 - 1 - 2 - 2, "IOD002 Minotaur's Mantle (Boss) : la salle B (2 degats) est traversee deux fois (9 - 1 - 2 - 2 = 4)")

# --- degats : Whip, Force Field, Flame of Achoom, Blast Box --------------------------------------------------------------------------------

func _t_damage_items() -> void:
	# IOD004 Tamer's Whip : base 1 pour les salles Monster tant que le heros est a l'entree
	var G := _G([_player(0, [_plain("M", "monster", [1], 4), _plain("T", "trap", [1], 4), _plain("MA", "monster", [1], 3, true)]), _player(1)])
	var p0 := _p(G, 0)
	_entrance(G, 0, _with(_h("H1", 9, 2), "IOD004"))
	_ok.call(BossEngine.room_damage_with_modifiers(G, p0, 0, null) == 1 and BossEngine.room_damage_with_modifiers(G, p0, 1, null) == 4 and BossEngine.room_damage_with_modifiers(G, p0, 2, null) == 1,
		"IOD004 Tamer's Whip (Power-Up) : les salles Monster (avancee comprise) ont une base de 1, les Trap gardent leurs degats")
	(G["effects"]["ordinaryMonsterBonus"] as Array).append(0)
	_ok.call(BossEngine.room_damage_with_modifiers(G, p0, 0, null) == 2, "IOD004 : les bonus s'ajoutent a la base de 1")
	G["effects"]["ordinaryMonsterBonus"] = []
	_p(G, 0)["entrance"] = []
	_ok.call(BossEngine.room_damage_with_modifiers(G, p0, 0, null) == 4, "IOD004 : sans le heros a l'entree, degats imprimes")
	# Reward : une salle Monster +X, X = salles Monster du donjon
	var G1 := _G([_player(0, [_plain("M1", "monster", [1], 1), _plain("M2", "monster", [1], 2), _plain("T", "trap", [1], 1)]), _player(1)])
	_owned(G1, 0, "IOD004")
	_use(G1, 0, "IOD004")
	var pc := _pending(G1)
	_ok.call(not pc.is_empty() and (pc["options"] as Array).size() == 2, "IOD004 Tamer's Whip (Boss) : choix parmi les salles Monster de votre donjon")
	_match(G1)._resolve_choice(0, 1)
	_ok.call(BossEngine.room_damage_with_modifiers(G1, _p(G1, 0), 1, null) == 2 + 2, "IOD004 Tamer's Whip (Boss) : la salle choisie gagne +2 (deux salles Monster)")
	# IOD022 Force Field : -2 des salles Advanced
	var G2 := _G([_player(0, [_plain("N", "trap", [1], 3), _plain("ADV", "trap", [1], 4, true), _plain("ADV1", "trap", [1], 1, true)]), _player(1)])
	var ff := _with(_h("H2", 9, 5), "IOD022")
	var d2: Array = []
	for i in 3:
		d2.append(BossEngine.room_damage_with_modifiers(G2, _p(G2, 0), i, ff))
	_ok.call(d2 == [3, 2, 0], "IOD022 Force Field (Power-Up) : -2 degats des salles Advanced, jamais en dessous de 0 (%s)" % str(d2))
	var G2b := _G([_player(0), _player(1, [_plain("ADV", "trap", [1], 4, true), _plain("N", "trap", [1], 3)])])
	var tg := _h("TG", 9, 5)
	_entrance(G2b, 1, tg)
	_owned(G2b, 0, "IOD022")
	_use_pick(G2b, 0, "IOD022")
	_ok.call(BossEngine.room_damage_with_modifiers(G2b, _p(G2b, 1), 0, tg) == 0 and BossEngine.room_damage_with_modifiers(G2b, _p(G2b, 1), 1, tg) == 3, "IOD022 Force Field (Boss) : le heros designe ignore les degats des salles Advanced jusqu'a la fin du tour")
	G2b["turn"] = 4
	_ok.call(BossEngine.room_damage_with_modifiers(G2b, _p(G2b, 1), 0, tg) == 4, "IOD022 : l'effet expire au tour suivant")
	# IOD008 Flame of Achoom : ignore le texte des salles qui modifient les AUTRES salles (Goblin Armory BMA015, Dizzygas BMA029, Invasion Swarm CRL008)
	var arm := _plain("BMA015", "monster", [1], 1)
	var G3 := _G([_player(0, [arm, _plain("M", "monster", [1], 2)]), _player(1)])
	var flame := _with(_h("H3", 9, 3), "IOD008")
	_ok.call(BossEngine.room_damage_with_modifiers(G3, _p(G3, 0), 1, _h("N", 9, 3)) == 3 and BossEngine.room_damage_with_modifiers(G3, _p(G3, 0), 1, flame) == 2, "IOD008 Flame of Achoom (Power-Up) : Goblin Armory ne donne plus +1 a la salle voisine")
	var G3b := _G([_player(0, [_plain("CRL008", "trap", [5], 1), _plain("ADV", "trap", [1], 2, true), _plain("CRL009", "trap", [5], 1)]), _player(1)])
	_ok.call(BossEngine.room_damage_with_modifiers(G3b, _p(G3b, 0), 1, _h("N2")) == 4 and BossEngine.room_damage_with_modifiers(G3b, _p(G3b, 0), 1, flame) == 2, "IOD008 Flame of Achoom : Reactor Core et Invasion Swarm ignores")
	_ok.call(not G3b.has("iodFlame") and not G3.has("iodFlame"), "IOD008 : aucun drapeau transitoire ne survit au calcul")
	# Reward : vos salles Mage donnent +1 aux voisines jusqu'a la fin du tour
	var G3c := _G([_player(0, [_plain("MG", "trap", [3], 1), _plain("X", "trap", [1], 1), _plain("Y", "trap", [1], 1)]), _player(1)])
	_owned(G3c, 0, "IOD008")
	_use(G3c, 0, "IOD008")
	var p3 := _p(G3c, 0)
	_ok.call(BossEngine.room_damage_with_modifiers(G3c, p3, 1, null) == 2 and BossEngine.room_damage_with_modifiers(G3c, p3, 2, null) == 1 and BossEngine.room_damage_with_modifiers(G3c, p3, 0, null) == 1,
		"IOD008 Flame of Achoom (Boss) : la salle Mage donne +1 a sa voisine seulement (pas a elle-meme, pas aux autres)")
	# IOD015 Blast Box : la salle ou le heros meurt est detruite (apres son declencheur de mort)
	var lv := _live()
	var G4: Dictionary = lv[1]
	_dungeon(G4, 0, [_plain("A", "trap", [4], 1), _plain("DEATH", "trap", [4], 9)])
	_entrance(G4, 0, _with(_h("H4", 4, 4), "IOD015"))
	_next(lv[0])
	_next(lv[0])
	_drain(lv[0])
	_ok.call((_p(G4, 0)["dungeon"] as Array).size() == 1 and _ids(G4["decks"]["roomDiscard"]).has("DEATH") and not (_p(G4, 0)["souls"] as Array).is_empty(), "IOD015 Blast Box (Power-Up) : la salle ou le heros meurt est detruite, l'ame est gagnee")
	# Reward : detruire la salle d'un heros, qui meurt
	var lv2 := _live()
	var G5: Dictionary = lv2[1]
	_dungeon(G5, 1, [_plain("A", "trap", [1], 1), _plain("B", "trap", [1], 1)])
	_entrance(G5, 1, _h("H5", 8, 2))
	_owned(G5, 0, "IOD015")
	G5["activePlayer"] = 1
	G5["phase"] = "adventure"
	lv2[0].apply_move(1, {"type": "adventureNext", "args": []})
	var hero_room_n := (_p(G5, 1)["dungeon"] as Array).size()
	_use(G5, 0, "IOD015")
	_ok.call((_p(G5, 1)["dungeon"] as Array).size() == hero_room_n - 1 and int(G5["adventure"]["hp"]) <= 0, "IOD015 Blast Box (Boss) : la salle du heros est detruite et le heros est tue (hp %d)" % int(G5["adventure"]["hp"]))
	var G6 := _G([_player(0), _player(1)])
	_owned(G6, 0, "IOD015")
	_ok.call(ThkAbilities.effect_check(G6, 0, "IOD015") != "", "IOD015 : sans heros dans une salle, injouable")

# --- cartes en main : Surprise Box, Shining Armor, Antifreeze, Super Magnet -------------------------------------------------------------------

func _t_hand_items() -> void:
	# IOD005 Surprise Box : personne ne joue de sort tant que le heros est a l'entree (ou dans) un donjon
	var G := _G([_player(0), _player(1)])
	_entrance(G, 1, _with(_h("H1", 5, 3), "IOD005"))
	G["phase"] = "adventure"
	_ok.call(ThkAbilities.spells_blocked(G, 0) and ThkAbilities.spells_blocked(G, 1), "IOD005 Surprise Box (Power-Up) : aucun sort pour personne (adventure)")
	G["phase"] = "build"
	var m := _match(G)
	_hand(G, 0).append({"id": "BMA046", "name": "Spell", "isSpell": true, "category": 1})
	_ok.call(ThkAbilities.spells_blocked(G, 0) and not m.legal_moves(0).any(func(mv): return str((mv as Dictionary)["type"]) == "playSpell"), "IOD005 Surprise Box : aussi en Construction, aucun coup playSpell")
	_p(G, 1)["entrance"] = []
	_ok.call(not ThkAbilities.spells_blocked(G, 0), "IOD005 : sans le heros, les sorts sont permis")
	# Reward : defausser la main, repiocher autant de salles et de sorts
	var G1 := _G([_player(0), _player(1)])
	_hand(G1, 0).append_array([_plain("R1"), _plain("R2"), _spl("S1")])
	_owned(G1, 0, "IOD005")
	_use(G1, 0, "IOD005")
	var rn := _hand(G1, 0).filter(func(c): return bool((c as Dictionary).get("isRoom", false))).size()
	var sn := _hand(G1, 0).filter(func(c): return bool((c as Dictionary).get("isSpell", false))).size()
	_ok.call(rn == 2 and sn == 1 and not _ids(_hand(G1, 0)).has("R1") and not _ids(_hand(G1, 0)).has("S1"), "IOD005 Surprise Box (Boss) : main defaussee, 2 salles et 1 sort repioches")
	# IOD010 Shining Armor : le heros n'est pas ciblable par les sorts
	var G2 := _G([_player(0), _player(1)])
	var armored := _with(_h("AR", 5, 1), "IOD010")
	var bare := _h("BR", 5, 1)
	_entrance(G2, 1, armored)
	_entrance(G2, 1, bare)
	G2["town"] = [_with(_h("AT", 5, 1), "IOD010"), _h("BT", 5, 1)]
	var t1 := SpellTargeting.spell_targets_for(G2, _p(G2, 0), 0, "BMA041") # Assassin : un heros du donjon adverse
	var t2 := SpellTargeting.spell_targets_for(G2, _p(G2, 0), 0, "BMA051") # Princess in Peril : un heros de la ville
	_ok.call(t1.size() == 1 and str(t1[0]["heroId"]) == "BR" and t2.size() == 1 and int(t2[0]["townIndex"]) == 1, "IOD010 Shining Armor (Power-Up) : ni les heros du donjon ni ceux de la ville ne sont ciblables (sort BMA041 / BMA051)")
	var G2b := _G([_player(0), _player(1)], ["base", "tools"])
	_entrance(G2b, 1, _with(_h("AR", 5, 1), "IOD010"))
	_ok.call(SpellTargeting.spell_targets_for(G2b, _p(G2b, 0), 0, "BMA041").size() == 1, "IOD010 : sans la case wiki, l'Objet n'a aucun effet")
	# Reward : un sort de la defausse
	var G3 := _G([_player(0), _player(1)])
	(G3["decks"] as Dictionary)["spellDiscard"] = [_spl("D1")]
	_owned(G3, 0, "IOD010")
	_use(G3, 0, "IOD010")
	if not _pending(G3).is_empty():
		_match(G3)._resolve_choice(0, 0)
	_ok.call(_ids(_hand(G3, 0)) == ["D1"] and (G3["decks"]["spellDiscard"] as Array).is_empty(), "IOD010 Shining Armor (Boss) : un sort de la defausse rejoint la main")
	var G3b := _G([_player(0), _player(1)])
	_owned(G3b, 0, "IOD010")
	_ok.call(ThkAbilities.effect_check(G3b, 0, "IOD010") != "", "IOD010 : defausse de sorts vide -> injouable")
	# IOD017 Antifreeze : les salles desactivees sont detruites quand le heros est a l'entree
	var G4 := _G([_player(0, [_plain("A"), _plain("B"), _plain("C")]), _player(1)])
	(SpellEffects._effects(G4)["deactivatedRooms"] as Array).append_array([{"playerId": 0, "roomIndex": 0}, {"playerId": 0, "roomIndex": 2}, {"playerId": 1, "roomIndex": 0}])
	IodAbilities.on_hero_start(G4, 0, _with(_h("H4", 5, 0), "IOD017"), 5)
	_ok.call(_ids(_p(G4, 0)["dungeon"].map(func(s): return s[0])) == ["B"] and _ids(G4["decks"]["roomDiscard"]).size() == 2, "IOD017 Antifreeze (Power-Up) : les salles desactivees de votre donjon sont detruites")
	# Reward : reactive les salles, un sort par salle reactivee
	var G5 := _G([_player(0, [_plain("A"), _plain("B")]), _player(1, [_plain("Z")])])
	(SpellEffects._effects(G5)["deactivatedRooms"] as Array).append_array([{"playerId": 0, "roomIndex": 0}, {"playerId": 0, "roomIndex": 1}, {"playerId": 1, "roomIndex": 0}])
	_owned(G5, 0, "IOD017")
	_use(G5, 0, "IOD017")
	_ok.call(not _deactivated(G5, 0, 0) and not _deactivated(G5, 0, 1) and _deactivated(G5, 1, 0) and TnlAbilities.spells_in_hand(_p(G5, 0)) == 2, "IOD017 Antifreeze (Boss) : vos salles sont reactivees (pas celles des autres), 2 sorts pioches")
	var G5b := _G([_player(0, [_plain("A")]), _player(1)])
	_owned(G5b, 0, "IOD017")
	_ok.call(ThkAbilities.effect_check(G5b, 0, "IOD017") != "", "IOD017 : aucune salle desactivee chez vous -> injouable")
	# IOD014 Super Magnet : desactive les salles a 2 icones ou plus
	var G6 := _G([_player(0, [_plain("A", "trap", [1]), _plain("B", "trap", [1, 2]), _plain("C", "trap", [2, 3, 4])]), _player(1)])
	IodAbilities.on_hero_start(G6, 0, _with(_h("H6", 5, 4), "IOD014"), 5)
	_ok.call(not _deactivated(G6, 0, 0) and _deactivated(G6, 0, 1) and _deactivated(G6, 0, 2), "IOD014 Super Magnet (Power-Up) : les salles a deux icones ou plus sont desactivees")
	# Reward : un joueur, un type : les heros ignorent ces icones (leurre)
	var G7 := _G([_player(0, [_plain("A", "trap", [2])]), _player(1, [_plain("B", "trap", [2]), _plain("C", "trap", [2])])])
	_owned(G7, 0, "IOD014")
	_use(G7, 0, "IOD014")
	var pc := _pending(G7)
	var idx := 0
	for i in (pc["options"] as Array).size():
		var o: Dictionary = pc["options"][i]
		if int(o["targetPlayerId"]) == 1 and int(o["treasure"]) == 2:
			idx = i
	_match(G7)._resolve_choice(0, idx)
	_ok.call(BossEngine.treasure_count(_p(G7, 1), 2, G7) == 0 and BossEngine.treasure_count(_p(G7, 0), 2, G7) == 1, "IOD014 Super Magnet (Boss) : les icones Fighter du donjon de J2 sont ignorees, pas celles de J1")
	G7["effects"] = SpellEffects.empty_effects()
	_ok.call(BossEngine.treasure_count(_p(G7, 1), 2, G7) == 2, "IOD014 : l'effet expire a la fin du tour")

# --- salles : Stun Gun, (Laser Drill / Crystal Ball non jouees) -------------------------------------------------------------------------

func _t_room_items() -> void:
	# IOD021 Stun Gun : le heros qui survit a une salle Monster Advanced la renvoie dans votre main
	var lv := _live()
	var G: Dictionary = lv[1]
	_dungeon(G, 0, [_plain("ADVM", "monster", [5], 1, true), _plain("B", "trap", [5], 1)])
	_entrance(G, 0, _with(_h("H1", 6, 5), "IOD021"))
	_next(lv[0])
	_next(lv[0])
	_drain(lv[0])
	_ok.call(_ids(_hand(G, 0)).has("ADVM") and (_p(G, 0)["dungeon"] as Array).size() == 1, "IOD021 Stun Gun (Power-Up) : la salle Monster Advanced survecue revient dans la main")
	var lv2 := _live()
	var G2: Dictionary = lv2[1]
	_dungeon(G2, 0, [_plain("ADVT", "trap", [5], 1, true), _plain("B", "trap", [5], 1)])
	_entrance(G2, 0, _with(_h("H2", 6, 5), "IOD021"))
	_next(lv2[0])
	_next(lv2[0])
	_drain(lv2[0])
	_ok.call(not _ids(_hand(G2, 0)).has("ADVT"), "IOD021 Stun Gun : une salle Advanced Trap reste en place")
	# Reward (Construction) : chaque adversaire renvoie une salle Advanced
	var G3 := _G([_player(0, [_plain("MINE", "trap", [1], 1, true)]), _player(1, [_plain("N"), _plain("AD1", "trap", [1], 1, true), _plain("AD2", "monster", [1], 1, true)]), _player(2, [_plain("AD3", "trap", [1], 1, true)])])
	_owned(G3, 0, "IOD021")
	_use(G3, 0, "IOD021")
	var pc := _pending(G3)
	_ok.call(not pc.is_empty() and int(pc["playerId"]) == 1 and (pc["options"] as Array).size() == 2, "IOD021 Stun Gun (Boss) : l'adversaire choisit lui-meme parmi ses salles Advanced")
	var m3 := _match(G3)
	m3._resolve_choice(1, 0)
	var pc2 := _pending(G3)
	_ok.call(not pc2.is_empty() and int(pc2["playerId"]) == 2 or _ids(_hand(G3, 2)) == ["AD3"], "IOD021 Stun Gun (Boss) : puis le second adversaire (une seule salle Advanced : renvoyee d'office)")
	_drain(m3)
	_ok.call(_hand(G3, 1).size() == 1 and _hand(G3, 2).size() == 1 and (_p(G3, 0)["dungeon"] as Array).size() == 1, "IOD021 Stun Gun (Boss) : chaque adversaire a repris une salle Advanced, la votre reste")
	G3["phase"] = "adventure"
	_ok.call(ThkAbilities.effect_check(G3, 0, "IOD021") != "", "IOD021 : Construction seulement")

# --- heros : Lich Crown, Pandora's Box (Power-Up), Heart Container non jouee ----------------------------------------------------------------

func _t_hero_items() -> void:
	# IOD009 Lich Crown : le heros qui allait mourir retourne en ville, il garde l'Objet
	var lv := _live()
	var G: Dictionary = lv[1]
	_dungeon(G, 0, [_plain("A", "trap", [1], 9)])
	var h := _with(_h("H1", 4, 1), "IOD009")
	_entrance(G, 0, h)
	_next(lv[0])
	_drain(lv[0])
	_ok.call((G["town"] as Array).has(h) and ThkAbilities.item_id(h) == "IOD009" and (_p(G, 0)["souls"] as Array).is_empty(), "IOD009 Lich Crown (Power-Up) : le heros retourne en ville avec son Objet, aucune ame")
	_ok.call(not (G["decks"]["heroDiscard"] as Array).has(h) and (_p(G, 0)["items"] as Array).is_empty(), "IOD009 : « You keep this Item » (pas defausse, pas dans le scorekeeping)")
	# Reward : un heros face cachee (la source), un autre heros subit sa Sante en degats
	var G2 := _G([_player(0), _player(1)])
	var dead := _h("DEAD", 7, 1)
	(_p(G2, 1)["souls"] as Array).append(CardDB.soul_entry(dead))
	var victim := _h("VIC", 20, 2)
	var weak := _h("WEAK", 5, 2)
	G2["town"] = [victim, weak]
	_owned(G2, 0, "IOD009")
	_use(G2, 0, "IOD009")
	var pc := _pending(G2)
	_ok.call(not pc.is_empty() and (pc["options"] as Array).size() == 1 or str(pc.get("step", "")) == "thk_iod_lich2", "IOD009 Lich Crown (Boss) : un heros face cachee (une seule source, choisie d'office)")
	var pc2 := _pending(G2)
	var vi := 0
	for i in (pc2["options"] as Array).size():
		if str((pc2["options"][i]["card"] as Dictionary)["id"]) == "VIC":
			vi = i
	_match(G2)._resolve_choice(0, vi)
	_ok.call(BossEngine.hero_hp(victim) == 13 and (G2["town"] as Array).has(victim), "IOD009 Lich Crown (Boss) : 7 degats (Sante de la source) -> 20 - 7 = 13")
	var G2b := _G([_player(0), _player(1)])
	(_p(G2b, 1)["souls"] as Array).append(CardDB.soul_entry(_h("D2", 9, 1)))
	G2b["town"] = [weak]
	var weak2: Dictionary = G2b["town"][0]
	_owned(G2b, 0, "IOD009")
	_use(G2b, 0, "IOD009")
	_drain(_match(G2b))
	_ok.call(not (G2b["town"] as Array).has(weak2) and not (_p(G2b, 0)["souls"] as Array).is_empty(), "IOD009 Lich Crown (Boss) : un heros reduit a 0 PV meurt, son ame va au proprietaire de l'Objet")
	# IOD019 Pandora's Box (Power-Up) : peut tuer un autre heros de l'entree
	var G3 := _G([_player(0), _player(1)])
	var victim3 := _h("OTHER", 5, 2)
	_entrance(G3, 0, _with(_h("H3", 5, 0), "IOD019"))
	_entrance(G3, 0, victim3)
	IodAbilities.on_hero_start(G3, 0, _p(G3, 0)["entrance"][0], 5)
	var pc3 := _pending(G3)
	_ok.call(str(pc3.get("step", "")) == "thk_kill" and bool(pc3.get("optional", false)) and (pc3["options"] as Array).size() == 1, "IOD019 Pandora's Box (Power-Up) : choix facultatif de tuer l'autre heros de l'entree")
	_match(G3)._resolve_choice(0, 0)
	_ok.call(not (_p(G3, 0)["entrance"] as Array).has(victim3) and not (_p(G3, 0)["souls"] as Array).is_empty(), "IOD019 Pandora's Box (Power-Up) : l'autre heros est tue, son ame va au proprietaire du donjon")

# --- Boss -----------------------------------------------------------------------------------------------------------------------------------

func _t_bosses() -> void:
	# IOD027 Franz : chaque usage d'un Objet fait piocher un sort
	var G := _G([_player(0), _player(1)])
	var p0 := _p(G, 0)
	p0["boss"] = _boss("IOD027")
	_ok.call(RoomAbilities.process_level_up(G, 0) == null and IodAbilities.has_boss(p0, "IOD027"), "IOD027 Franz : la montee de niveau pose le drapeau « pour le reste de la partie »")
	_owned(G, 0, "IOD008")
	_use(G, 0, "IOD008")
	_ok.call(TnlAbilities.spells_in_hand(p0) == 1, "IOD027 Franz : un sort est pioche a chaque usage de la capacite de Boss d'un Objet")
	var G0 := _G([_player(0), _player(1)])
	_owned(G0, 0, "IOD008")
	_use(G0, 0, "IOD008")
	_ok.call(TnlAbilities.spells_in_hand(_p(G0, 0)) == 0, "IOD027 : sans Franz, aucune pioche")
	# IOD025 Banseer Bivan : drapeau via la montee de niveau
	var GB := _G([_player(0), _player(1)])
	_p(GB, 0)["boss"] = _boss("IOD025")
	RoomAbilities.process_level_up(GB, 0)
	_ok.call(IodAbilities.face_up_limit(_p(GB, 0)) == 2 and IodAbilities.face_up_limit(_p(GB, 1)) == 1, "IOD025 Banseer Bivan : deux Objets face visible apres la montee de niveau")
	# IOD028 Lady Vix : un Objet face visible d'un heros de la ville ou d'un autre joueur
	var GV := _G([_player(0), _player(1)])
	_p(GV, 0)["boss"] = _boss("IOD028")
	var carrier := _with(_h("CAR", 5, 2), "IOD003")
	GV["town"] = [carrier]
	_owned(GV, 1, "IOD012")
	_owned(GV, 1, "IOD013", true) # face cachee : pas ciblable
	var cv = RoomAbilities.process_level_up(GV, 0)
	_ok.call(cv is Dictionary and (cv["options"] as Array).size() == 2, "IOD028 Lady Vix : un Objet de heros en ville et un Objet face visible adverse (la face cachee est exclue)")
	GV["pendingChoice"] = cv
	var vi := 0
	for i in (cv["options"] as Array).size():
		if int(cv["options"][i]["fromPid"]) == -1:
			vi = i
	_match(GV)._resolve_choice(0, vi)
	_ok.call(not carrier.has("item") and (_p(GV, 0)["items"] as Array).size() == 1 and not bool(_p(GV, 0)["items"][0]["faceDown"]) and str(_p(GV, 0)["items"][0]["id"]) == "IOD003", "IOD028 Lady Vix : l'Objet du heros de la ville rejoint votre scorekeeping, face visible")
	# IOD029 Umbra : un Objet face visible de n'importe quel scorekeeping
	var GU := _G([_player(0), _player(1)])
	_p(GU, 0)["boss"] = _boss("IOD029")
	_owned(GU, 0, "IOD005")
	_owned(GU, 1, "IOD012")
	var cu = RoomAbilities.process_level_up(GU, 0)
	_ok.call(cu is Dictionary and (cu["options"] as Array).size() == 1 or _ids(_p(GU, 0)["items"]).has("IOD012"), "IOD029 Umbra : l'Objet face visible adverse est pris (une seule candidate)")
	if cu is Dictionary:
		GU["pendingChoice"] = cu
		_match(GU)._resolve_choice(0, 0)
	var mine := _p(GU, 0)["items"] as Array
	var up := mine.filter(func(it): return not bool((it as Dictionary)["faceDown"]))
	_ok.call(up.size() == 1 and str(up[0]["id"]) == "IOD012" and (_p(GU, 1)["items"] as Array).is_empty(), "IOD029 Umbra : l'Objet adverse est face visible chez vous (l'excedent repart face cachee)")

# --- parties completes ---------------------------------------------------------------------------------------------------------------------

func _t_flow() -> void:
	# une partie wiki iod : les Objets IOD sont reveles et attaches
	var m = load("res://godot/scripts/Match.gd").new()
	host.add_child(m)
	var G: Dictionary = m.new_match(2, 1, ["iod", "crash-landing"])
	var ids := _ids(G["decks"]["items"]) + _ids(G.get("townItems", [])) + _attached(G)
	_ok.call(ids.size() == 20 and ids.all(func(i): return str(i).begins_with("IOD")) and not ids.any(func(i): return ["IOD007", "IOD011", "IOD018", "IOD023"].has(i)), "IOD : partie wiki iod+crash-landing, 20 Objets IOD (les 4 non implementes sont hors pioche)")
	# les 24 Objets s'attachent selon l'icone (Explorer -> heros Explorer)
	var cl := _h("EXH", 5, 5)
	var G2 := _G([_player(0), _player(1)])
	G2["town"] = [cl]
	G2["townItems"] = [_item("IOD021")]
	ThkAbilities.attach_all(G2)
	_ok.call(ThkAbilities.item_id(cl) == "IOD021", "IOD : un Objet Explorer s'attache a un heros Explorer")
