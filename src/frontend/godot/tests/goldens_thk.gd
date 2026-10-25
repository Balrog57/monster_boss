extends RefCounted
## Goldens de l'extension wiki Tools of Hero-Kind (THK : 20 Objets, 4 salles avancees, Excavation). Hors APK : tout ce qui suit n'existe que
## derriere la case wiki (pseudo-paquet `tools-wiki`) ; le paquet « tools » seul garde le comportement inerte de l'APK (voir goldens_decks).
## References : docs/rules/rules.md (Items + FAQ des cartes THK), texte des cartes (cards.json).
## Appele par goldens.gd : `load("res://godot/tests/goldens_thk.gd").new().run(_ok, self)`.

var _ok: Callable
var host: Node

func run(ok: Callable, h: Node) -> void:
	_ok = ok
	host = h
	_t_gating_and_apk_inert()
	_t_attach_rules()
	_t_scorekeeping_rules()
	_t_power_ups_flow()
	_t_power_ups_hooks()
	_t_power_ups_damage()
	_t_rewards_simple()
	_t_rewards_targeted()
	_t_reward_ring()
	_t_rooms()
	_t_excavation()
	_t_ai_legal_moves()

# --- fabriques d'etats minimaux ----------------------------------------------------------------------------------------

func _card(arr: Array, id: String) -> Dictionary:
	for c in arr:
		if str((c as Dictionary).get("id", "")) == id:
			return (c as Dictionary).duplicate(true)
	push_error("carte introuvable " + id)
	return {}

func _room(id: String) -> Dictionary:
	var r := _card(CardDB.rooms, id)
	r["isRoom"] = true
	return r

func _item(id: String) -> Dictionary:
	return _card(CardDB.items, id)

func _hero(id: String) -> Dictionary:
	var h := _card(CardDB.heroes, id)
	h["souls"] = 2 if bool(h.get("epic", false)) else 1
	h["wounds"] = h["souls"]
	return h

func _plain(id: String, type: String = "monster", treasures: Array = [1], damage: int = 1, advanced: bool = false) -> Dictionary:
	return {"id": id, "name": id, "type": type, "advanced": advanced, "treasures": treasures, "damage": damage, "isRoom": true}

func _spl(id: String) -> Dictionary:
	return {"id": id, "name": id, "isSpell": true, "category": 3}

func _player(pid: int, dungeon: Array = []) -> Dictionary:
	var stacks: Array = []
	for r in dungeon:
		stacks.append([r])
	return {"id": pid, "boss": _card(CardDB.bosses, "BMA001" if pid == 0 else "BMA002"), "dungeon": stacks, "hand": [], "souls": [], "wounds": [],
		"entrance": [], "eliminated": false, "leveledUp": false, "buildsThisTurn": 0, "coins": 3, "items": []}

func _G(players: Array, sets: Array = ["base", "tools", "tools-wiki"]) -> Dictionary:
	var ps := {}
	for p in players:
		ps[int((p as Dictionary)["id"])] = p
	var spells: Array = []
	for i in 8:
		spells.append(_spl("SP%d" % i))
	return {"players": ps, "town": [], "townItems": [], "log": [], "logs": [], "adventure": {}, "turn": 3, "phase": "build", "activePlayer": 0,
		"buildOrder": [0, 1], "buildIndex": 0, "sets": sets, "effects": SpellEffects.empty_effects(), "stack": [], "pendingChoice": {}, "choiceQueue": [],
		"decks": {"rooms": [], "spells": spells, "heroes": [], "epics": [], "items": [], "roomDiscard": [], "spellDiscard": [], "heroDiscard": []}}

func _match(G: Dictionary) -> Node:
	var m = load("res://godot/scripts/Match.gd").new()
	host.add_child(m)
	m.G = G
	return m

## Une vraie partie 2 joueurs (case wiki), videe pour un scenario d'aventure : phase Adventure, joueur 0 actif.
func _live() -> Array:
	var m = load("res://godot/scripts/Match.gd").new()
	host.add_child(m)
	var G: Dictionary = m.new_match(2, 1, ["tools-wiki"])
	for pid in [0, 1]:
		var p: Dictionary = G["players"][pid]
		p["boss"] = _card(CardDB.bosses, "BMA001" if pid == 0 else "BMA002")
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

func _with_item(h: Dictionary, id: String) -> Dictionary:
	h["item"] = _item(id)
	return h

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

## Un pas d'aventure : le heros avance d'une salle, puis les deux joueurs passent les fenetres de pause (apres les degats, avant la sortie)
## jusqu'a ce que le heros attende le pas suivant (ou qu'un choix s'ouvre).
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

func _n_spells(G: Dictionary, pid: int) -> int:
	return TnlAbilities.spells_in_hand(_p(G, pid))

func _n_rooms(G: Dictionary, pid: int) -> int:
	return _hand(G, pid).filter(func(c): return bool((c as Dictionary).get("isRoom", false))).size()

## Un Objet face visible dans le scorekeeping de `pid`, en service (acquis aux tours precedents).
func _owned(G: Dictionary, pid: int, id: String, face_down: bool = false) -> Dictionary:
	var it := _item(id)
	it["faceDown"] = face_down
	it["acquiredTurn"] = 1
	(_p(G, pid)["items"] as Array).append(it)
	return it

func _use(G: Dictionary, pid: int, id: String) -> Variant:
	return ThkAbilities.use_item(G, pid, id)

func _is_deactivated(G: Dictionary, pid: int, idx: int) -> bool:
	return BossEngine.is_room_deactivated(G, pid, idx)

func _count_prefix(arr: Array, prefix: String) -> int:
	var n := 0
	for c in arr:
		if str((c as Dictionary).get("id", "")).begins_with(prefix):
			n += 1
	return n

# --- gating : l'APK n'a pas change d'un octet -------------------------------------------------------------------------------

func _t_gating_and_apk_inert() -> void:
	var m1 = load("res://godot/scripts/Match.gd").new()
	host.add_child(m1)
	var G1: Dictionary = m1.new_match(2, 1, ["tools"])
	_ok.call(not ThkAbilities.active(G1) and not Match.wiki_active(G1), "THK : le paquet « tools » seul n'active pas la case wiki (comportement de l'APK)")
	var exc1: Dictionary = {}
	for sc in (G1["decks"]["spells"] as Array):
		if str((sc as Dictionary).get("id", "")) == "THK025":
			exc1 = sc
	_ok.call(not exc1.is_empty() and not CardDB.can_play_spell(exc1, "build") and not CardDB.can_play_spell(exc1, "adventure"), "THK025 : Excavation injouable sans la case wiki")
	var items_before: int = (G1["decks"]["items"] as Array).size() + (G1.get("itemQueue", []) as Array).size()
	m1._reveal_items()
	_ok.call((G1.get("itemQueue", []) as Array).size() >= 1 and not G1.has("townItems") and (G1["decks"]["items"] as Array).size() + (G1["itemQueue"] as Array).size() == items_before,
		"THK sans case wiki : l'Objet revele va dans la file inerte, rien ne s'attache")
	var killed_apk := true
	for h in (G1["town"] as Array):
		killed_apk = killed_apk and not (h as Dictionary).has("item")
	_ok.call(killed_apk, "THK sans case wiki : aucun heros ne porte d'Objet")
	_ok.call(ThkAbilities.use_moves(G1, G1["players"][0], 0).is_empty() and ThkAbilities.cheat_code(G1, 0) == false and not ThkAbilities.spells_blocked(G1, 0), "THK sans case wiki : aucun crochet n'agit")
	# case wiki : le pseudo-paquet pose aussi « tools »
	var m2 = load("res://godot/scripts/Match.gd").new()
	host.add_child(m2)
	var G2: Dictionary = m2.new_match(2, 1, ["tools-wiki"])
	_ok.call(ThkAbilities.active(G2) and (G2["sets"] as Array).has("tools") and Match.wiki_active(G2), "THK avec la case wiki : pseudo-paquet actif, paquet « tools » pose, mode wiki")
	_ok.call((G2["decks"]["items"] as Array).size() + (G2.get("townItems", []) as Array).size() + _n_attached(G2) == 20, "THK avec la case wiki : les 20 Objets sont dans la pioche, la ville ou sur un heros")
	_ok.call(_count_prefix(G2["decks"]["rooms"], "THK") == 4, "THK avec la case wiki : les 4 salles avancees sont dans la pioche")
	var excs: Array = (G2["decks"]["spells"] as Array).filter(func(c): return str((c as Dictionary).get("id", "")) == "THK025")
	_ok.call(excs.size() == 2 and excs.all(func(c): return CardDB.can_play_spell(c, "build") and CardDB.can_play_spell(c, "adventure")), "THK025 : 2 Excavation jouables avec la case wiki")
	_ok.call((G2.get("itemQueue", []) as Array).is_empty(), "THK avec la case wiki : plus de file inerte")

func _n_attached(G: Dictionary) -> int:
	var n := 0
	for h in (G["town"] as Array):
		if (h as Dictionary).has("item"):
			n += 1
	return n

# --- regles d'attache --------------------------------------------------------------------------------------------------------

func _t_attach_rules() -> void:
	var cl1 := _hero("BMA056")
	var cl2 := _hero("BMA057")
	var fi := _hero("BMA062")
	var G := _G([_player(0), _player(1)])
	G["town"] = [fi, cl1, cl2]
	G["townItems"] = [_item("THK001")] # treasure 1
	ThkAbilities.attach_all(G)
	_ok.call(ThkAbilities.item_id(cl1) == "THK001" and not fi.has("item") and not cl2.has("item") and (G["townItems"] as Array).is_empty(),
		"THK : un Objet s'attache au heros le plus ancien de la ville dont l'icone correspond")
	G["townItems"] = [_item("THK002")] # treasure 1 aussi : cl1 est pris, cl2 suit
	ThkAbilities.attach_all(G)
	_ok.call(ThkAbilities.item_id(cl2) == "THK002", "THK : un seul Objet par heros (le suivant prend le heros suivant)")
	G["town"] = [fi]
	G["townItems"] = [_item("THK004")] # treasure 1, aucun Clerc
	ThkAbilities.attach_all(G)
	_ok.call(not fi.has("item") and (G["townItems"] as Array).size() == 1, "THK : pas de heros correspondant -> l'Objet reste en ville")
	var fool := _hero("BMA080")
	G["town"] = [fool]
	ThkAbilities.attach_all(G)
	_ok.call(not fool.has("item"), "THK : un heros « ? » ne prend que les Objets Universels")
	G["townItems"] = [_item("THK017")] # Boots, universel
	ThkAbilities.attach_all(G)
	_ok.call(ThkAbilities.item_id(fool) == "THK017" and (G["townItems"] as Array).is_empty(), "THK : un Objet Universel s'attache a un heros « ? »")
	var star := _card(CardDB.heroes, "KSA016")
	G["town"] = [star]
	G["townItems"] = [_item("THK018")]
	ThkAbilities.attach_all(G)
	_ok.call(ThkAbilities.is_star(star) and not star.has("item"), "THK : un heros a etoile (capacite propre) ne prend jamais d'Objet")
	var hybrid := _hero("BMA062")
	hybrid["treasures"] = [1, 2]
	G["town"] = [hybrid]
	G["townItems"] = [_item("THK005")] # treasure 2
	ThkAbilities.attach_all(G)
	_ok.call(ThkAbilities.item_id(hybrid) == "THK005", "THK : un heros hybride prend un Objet de l'une de ses icones")
	# revelation en debut de tour : les Objets avant les heros, 2 Objets a 4 joueurs
	var G4 := _G([_player(0), _player(1), _player(2), _player(3)])
	(G4["decks"] as Dictionary)["items"] = [_item("THK001"), _item("THK005"), _item("THK010"), _item("THK013")]
	ThkAbilities.reveal_items(G4)
	_ok.call((G4["townItems"] as Array).size() == 2 and (G4["decks"]["items"] as Array).size() == 2, "THK : 2 Objets reveles par tour a 4 joueurs (aucun heros pour les prendre)")
	var G2 := _G([_player(0), _player(1)])
	(G2["decks"] as Dictionary)["items"] = [_item("THK001"), _item("THK005")]
	ThkAbilities.reveal_items(G2)
	_ok.call((G2["townItems"] as Array).size() == 1 and (G2["decks"]["items"] as Array).size() == 1, "THK : 1 Objet revele par tour a 2 joueurs")
	# un heros arrive en ville apres l'Objet : il le prend (Match._reveal_heroes_in_town -> attach_all)
	var hm := _match(G2)
	var ncl := _hero("BMA058")
	(G2["decks"] as Dictionary)["heroes"] = [ncl]
	(G2["decks"] as Dictionary)["epics"] = []
	G2["townItems"] = [_item("THK001")]
	hm._reveal_heroes_in_town()
	_ok.call(ThkAbilities.item_id(ncl) == "THK001", "THK : l'Objet encore en ville s'attache au heros qui arrive (BMA058 Cleric)")

# --- scorekeeping -------------------------------------------------------------------------------------------------------------

func _t_scorekeeping_rules() -> void:
	var G := _G([_player(0), _player(1)])
	var m := _match(G)
	# premier Objet gagne : face visible, sans choix
	var r1 = ThkAbilities.claim_item(G, 0, _item("THK005"))
	var p0 := _p(G, 0)
	_ok.call(r1 == null and (p0["items"] as Array).size() == 1 and not bool(p0["items"][0]["faceDown"]), "THK : le premier Objet gagne est place face visible")
	_ok.call(not ThkAbilities.item_usable(G, 0, p0["items"][0]) , "THK : un Objet acquis ce tour n'est pas utilisable (a partir du tour suivant)")
	G["turn"] = 4
	_ok.call(ThkAbilities.item_usable(G, 0, p0["items"][0]) and not ThkAbilities.use_moves(G, p0, 0).is_empty(), "THK : utilisable des le tour suivant (coup useItem offert)")
	# deuxieme Objet : choix A (utiliser) / B (retourner l'ancien) / C (garder l'ancien)
	var r2 = ThkAbilities.claim_item(G, 0, _item("THK012"))
	var ch: Dictionary = r2 if r2 is Dictionary else {}
	_ok.call(str(ch.get("step", "")) == "thk_claim" and (ch["options"] as Array).size() == 3, "THK : un second Objet face visible ouvre le choix du livret (utiliser / retourner / garder)")
	var modes: Array = []
	for o in (ch["options"] as Array):
		modes.append(str(o["mode"]))
	_ok.call(modes == ["use", "swap", "keep"], "THK : options du choix de reclamation = use, swap, keep")
	ThkAbilities.resolve_pick(G, 0, ch, 2) # keep
	_ok.call((p0["items"] as Array).size() == 2 and not bool(p0["items"][0]["faceDown"]) and bool(p0["items"][1]["faceDown"]), "THK : « garder » -> l'ancien reste face visible, le nouveau va face cachee")
	var face_up := (p0["items"] as Array).filter(func(it): return not bool((it as Dictionary)["faceDown"])).size()
	_ok.call(face_up == 1, "THK : un seul Objet face visible par scorekeeping")
	# swap
	var G2 := _G([_player(0), _player(1)])
	ThkAbilities.claim_item(G2, 0, _item("THK005"))
	G2["turn"] = 4
	var c2: Dictionary = ThkAbilities.claim_item(G2, 0, _item("THK012"))
	ThkAbilities.resolve_pick(G2, 0, c2, 1)
	var its: Array = _p(G2, 0)["items"]
	_ok.call(bool(its[0]["faceDown"]) and not bool(its[1]["faceDown"]) and str(its[1]["id"]) == "THK012", "THK : « retourner » -> l'ancien face cachee, le nouveau face visible")
	# use : l'ancien est joue maintenant (Goblin Suit : +1 aux salles Monster ordinaires), le nouveau est face visible
	var G3 := _G([_player(0), _player(1)])
	ThkAbilities.claim_item(G3, 0, _item("THK005"))
	G3["turn"] = 4
	var c3: Dictionary = ThkAbilities.claim_item(G3, 0, _item("THK012"))
	ThkAbilities.resolve_pick(G3, 0, c3, 0)
	var its3: Array = _p(G3, 0)["items"]
	_ok.call(bool(its3[0]["faceDown"]) and not bool(its3[1]["faceDown"]) and (SpellEffects._effects(G3)["ordinaryMonsterBonus"] as Array).has(0), "THK : « utiliser » -> la capacite de l'ancien est jouee, le nouveau reste face visible")
	# jouer une capacite de Boss retourne l'Objet face cachee ; il ne se rejoue plus
	var G4 := _G([_player(0), _player(1)])
	_owned(G4, 0, "THK012")
	var left_before: int = (G4["decks"]["spells"] as Array).size()
	var n_before: int = _n_spells(G4, 0)
	_ok.call(_use(G4, 0, "THK012") == null and bool(_p(G4, 0)["items"][0]["faceDown"]) and _n_spells(G4, 0) == n_before + 1 and (G4["decks"]["spells"] as Array).size() == left_before - 1, "THK : useItem retourne l'Objet face cachee et joue sa capacite")
	_ok.call(ThkAbilities.use_moves(G4, _p(G4, 0), 0).is_empty(), "THK : un Objet face cachee n'offre plus de coup useItem")
	# les coups useItem sont dans legal_moves (phase Construction)
	var G5 := _G([_player(0), _player(1)])
	_owned(G5, 0, "THK012")
	var m5 := _match(G5)
	_ok.call(m5.legal_moves(0).any(func(mv): return str((mv as Dictionary)["type"]) == "useItem" and str(mv["args"][0]) == "THK012"), "THK : useItem apparait dans legal_moves (Construction)")
	var G5b := _G([_player(0), _player(1)], ["base", "tools"])
	_owned(G5b, 0, "THK012")
	var m5b := _match(G5b)
	_ok.call(not m5b.legal_moves(0).any(func(mv): return str((mv as Dictionary)["type"]) == "useItem"), "THK sans case wiki : aucun coup useItem")
	m5.apply_move(0, {"type": "useItem", "args": ["THK012"]})
	_ok.call(bool(_p(G5, 0)["items"][0]["faceDown"]), "THK : apply_move useItem joue la capacite")

# --- Objets : Power-Up joues par le moteur (aventure complete) -------------------------------------------------------------------

func _t_power_ups_flow() -> void:
	# THK001 Extra Life : le heros tue retourne en ville, l'Objet est garde (face visible) ; le tueur ne gagne pas d'ame
	var lv := _live()
	var m: Node = lv[0]
	var G: Dictionary = lv[1]
	var hero := _with_item(_hero("BMA056"), "THK001")
	_dungeon(G, 0, [_plain("M", "monster", [1], 9)])
	_entrance(G, 0, hero)
	_next(m)
	_drain(m)
	var p0 := _p(G, 0)
	_ok.call((p0["souls"] as Array).is_empty() and (G["town"] as Array).has(hero) and ThkAbilities.item_id(hero) != "THK001", "THK001 Extra Life : le heros qui devait mourir retourne en ville (sans Objet), aucune ame")
	var kept := (p0["items"] as Array).filter(func(it): return str((it as Dictionary).get("id", "")) == "THK001")
	_ok.call(kept.size() == 1 and not bool(kept[0]["faceDown"]), "THK001 Extra Life : « You get to keep this Item » (scorekeeping, face visible)")
	_ok.call(not (G["decks"]["heroDiscard"] as Array).has(hero), "THK001 Extra Life : le heros n'est pas defausse")
	# un heros tue sans Extra Life : ses ames et son Objet vont au tueur (face visible)
	var lv2 := _live()
	var m2: Node = lv2[0]
	var G2: Dictionary = lv2[1]
	var victim := _with_item(_hero("BMA062"), "THK005")
	_dungeon(G2, 0, [_plain("M", "trap", [1], 9)])
	_entrance(G2, 0, victim)
	_next(m2)
	_drain(m2)
	var k2 := (_p(G2, 0)["items"] as Array).filter(func(it): return str((it as Dictionary).get("id", "")) == "THK005")
	_ok.call(k2.size() == 1 and not bool(k2[0]["faceDown"]) and not (_p(G2, 0)["souls"] as Array).is_empty(), "THK : le heros tue -> son Objet va face visible chez le tueur, avec l'ame")
	# un heros qui survit : l'Objet va face cachee dans le scorekeeping (THK007 Oversized Sword : +5 PV)
	var lv3 := _live()
	var m3: Node = lv3[0]
	var G3: Dictionary = lv3[1]
	var sw := _with_item(_hero("BMA062"), "THK007") # 4 PV + 5
	_dungeon(G3, 0, [_plain("M", "trap", [1], 6)])
	_entrance(G3, 0, sw)
	_next(m3)
	_ok.call(int(G3["adventure"].get("hp", 0)) == 4 + 5 - 6, "THK007 Oversized Sword : +5 PV au heros (4 + 5 - 6 degats = 3)")
	_next(m3)
	_drain(m3)
	var s3 := (_p(G3, 0)["items"] as Array).filter(func(it): return str((it as Dictionary).get("id", "")) == "THK007")
	_ok.call(s3.size() == 1 and bool(s3[0]["faceDown"]), "THK : un heros qui survit -> son Objet va face cachee dans le scorekeeping du proprietaire du donjon")
	# THK008 Vorpal Blade : le heros blesse le proprietaire ; l'Objet va face cachee
	var lv4 := _live()
	var m4: Node = lv4[0]
	var G4: Dictionary = lv4[1]
	var vb := _with_item(_hero("BMA066"), "THK008") # Fighter, 8 PV, treasure 2
	_dungeon(G4, 0, [_plain("M", "trap", [1], 1)])
	_entrance(G4, 0, vb)
	_next(m4)
	_next(m4)
	_drain(m4)
	var v4 := (_p(G4, 0)["items"] as Array).filter(func(it): return str((it as Dictionary).get("id", "")) == "THK008")
	_ok.call(v4.size() == 1 and bool(v4[0]["faceDown"]), "THK008 Vorpal Blade : l'Objet va face cachee apres le passage du heros")
	# THK017 Boots of Jumping : le heros ignore la salle qui suit chaque salle qu'il survit
	var lv5 := _live()
	var m5: Node = lv5[0]
	var G5: Dictionary = lv5[1]
	var bt := _with_item(_hero("BMA074"), "THK017") # Thief 4 PV
	_dungeon(G5, 0, [_plain("A", "trap", [1], 1), _plain("B", "trap", [1], 3), _plain("C", "trap", [1], 1)])
	_entrance(G5, 0, bt)
	_next(m5) # salle A : 1 degat
	_next(m5) # il survit : B est ignoree -> C : 1 degat
	_ok.call(int(G5["adventure"].get("hp", 0)) == 4 - 1 - 1, "THK017 Boots of Jumping : la salle suivante (B, 3 degats) est ignoree (4 - 1 - 1 = 2)")
	# THK016 The Bomb : le heros qui entre dans la derniere salle la detruit, aucun degat
	var lv6 := _live()
	var m6: Node = lv6[0]
	var G6: Dictionary = lv6[1]
	var bomb := _with_item(_hero("BMA074"), "THK016")
	_dungeon(G6, 0, [_plain("A", "trap", [1], 1), _plain("B", "trap", [1], 3)])
	_entrance(G6, 0, bomb)
	_next(m6)
	_next(m6)
	_drain(m6)
	_ok.call((_p(G6, 0)["dungeon"] as Array).size() == 1 and (G6["decks"]["roomDiscard"] as Array).any(func(c): return str((c as Dictionary).get("id", "")) == "B"), "THK016 The Bomb : la derniere salle est detruite")
	_ok.call((_p(G6, 0)["wounds"] as Array).size() >= 1 or int(G6["adventure"].get("hp", 0)) == 3, "THK016 The Bomb : aucun degat de la salle detruite (le heros atteint le Boss avec 3 PV)")
	# Revue : Tax Collector (choix d'affaiblissement ouvert avant la 1re salle) puis reprise : The Bomb doit encore se declencher sur la 1re salle
	var lv6b := _live()
	var m6b: Node = lv6b[0]
	var G6b: Dictionary = lv6b[1]
	var tcb := _with_item(_hero("RMB119"), "THK016")
	_dungeon(G6b, 0, [_plain("B1", "trap", [1], 3)])
	_entrance(G6b, 0, tcb)
	G6b["adventure"] = {"playerId": 0, "hero": tcb, "roomIndex": -1, "hp": 9, "pause": null}
	m6b._advance_adventure_room()
	_ok.call(str(_pending(G6b).get("step", "")) == "hero_weaken", "Revue : Tax Collector ouvre son choix avant la 1re salle")
	m6b._resolve_choice(0, -1)
	_ok.call((_p(G6b, 0)["dungeon"] as Array).is_empty() and int(G6b["adventure"].get("hp", 0)) == 9, "Revue : apres l'affaiblissement, The Bomb detruit la 1re (et derniere) salle sans degats")
	# affaibli a 0 PV : il meurt avant d'entrer (aucun degat de salle, aucune salle de mort)
	var lv6c := _live()
	var m6c: Node = lv6c[0]
	var G6c: Dictionary = lv6c[1]
	var tcc := _hero("RMB119")
	_dungeon(G6c, 0, [_plain("C1", "trap", [1], 3)])
	_entrance(G6c, 0, tcc)
	G6c["adventure"] = {"playerId": 0, "hero": tcc, "roomIndex": -1, "hp": 1, "pause": null}
	m6c._advance_adventure_room()
	m6c._resolve_choice(0, 0)
	_ok.call(int(G6c.get("adventure", {}).get("hp", 0)) <= 0 and not bool((G6c.get("adventure", {}) as Dictionary).get("weakenResume", false)) and (_p(G6c, 0)["dungeon"] as Array).size() == 1, "Revue : affaibli a 0 PV, le heros meurt sans subir la salle (hp 0, pas -3)")
	# THK011 Magic Mirror : l'ordre du donjon est inverse avant la premiere salle
	var lv7 := _live()
	var m7: Node = lv7[0]
	var G7: Dictionary = lv7[1]
	var mir := _with_item(_hero("BMA068"), "THK011")
	_dungeon(G7, 0, [_plain("A", "trap", [1], 1), _plain("B", "trap", [1], 1), _plain("C", "trap", [1], 1)])
	_entrance(G7, 0, mir)
	_next(m7)
	var order: Array = []
	for st in (_p(G7, 0)["dungeon"] as Array):
		order.append(str(BossEngine.active_room(st).get("id", "")))
	_ok.call(order == ["C", "B", "A"], "THK011 Magic Mirror : l'ordre des salles est inverse avant que le heros entre")
	# THK004 Staff of Healing : tout heros a l'entree entre avec +2 PV ce tour
	var lv8 := _live()
	var m8: Node = lv8[0]
	var G8: Dictionary = lv8[1]
	var other := _hero("BMA062") # 4 PV
	var staff := _with_item(_hero("BMA056"), "THK004")
	_dungeon(G8, 0, [_plain("A", "trap", [1], 1)])
	_entrance(G8, 0, other)
	_entrance(G8, 0, staff)
	_next(m8)
	_ok.call(int(G8["adventure"].get("hp", 0)) == 4 + 2 - 1, "THK004 Staff of Healing : le heros entre avec +2 PV (4 + 2 - 1 = 5)")
	# THK006 Claws of the Berserker : +1 PV par salle Monster du donjon
	var lv9 := _live()
	var m9: Node = lv9[0]
	var G9: Dictionary = lv9[1]
	var cl := _with_item(_hero("BMA062"), "THK006")
	_dungeon(G9, 0, [_plain("A", "monster", [1], 1), _plain("B", "monster", [1], 1), _plain("C", "trap", [1], 1)])
	_entrance(G9, 0, cl)
	_next(m9)
	_ok.call(int(G9["adventure"].get("hp", 0)) == 4 + 2 - 1, "THK006 Claws of the Berserker : +1 PV par salle Monster (4 + 2 - 1 = 5)")
	# THK015 Ten Foot Pole / THK018 Pet Monster : desactive la premiere salle Trap / Monster a l'entree du heros
	var lv10 := _live()
	var m10: Node = lv10[0]
	var G10: Dictionary = lv10[1]
	_dungeon(G10, 0, [_plain("M", "monster", [1], 1), _plain("T", "trap", [1], 1), _plain("T2", "trap", [1], 1)])
	_entrance(G10, 0, _with_item(_hero("BMA076"), "THK015"))
	_next(m10)
	_ok.call(_is_deactivated(G10, 0, 1) and not _is_deactivated(G10, 0, 2) and not _is_deactivated(G10, 0, 0), "THK015 Ten Foot Pole : la premiere salle Trap du donjon est desactivee")
	var lv11 := _live()
	var m11: Node = lv11[0]
	var G11: Dictionary = lv11[1]
	_dungeon(G11, 0, [_plain("T", "trap", [1], 1), _plain("M", "monster", [1], 1), _plain("M2", "monster", [1], 1)])
	_entrance(G11, 0, _with_item(_hero("BMA062"), "THK018"))
	_next(m11)
	_ok.call(_is_deactivated(G11, 0, 1) and not _is_deactivated(G11, 0, 2) and not _is_deactivated(G11, 0, 0), "THK018 Pet Monster : la premiere salle Monster du donjon est desactivee")
	# THK010 Ice Rod : toute salle que le heros survit est desactivee jusqu'a la fin du tour
	var lv12 := _live()
	var m12: Node = lv12[0]
	var G12: Dictionary = lv12[1]
	_dungeon(G12, 0, [_plain("A", "trap", [1], 1), _plain("B", "trap", [1], 1)])
	_entrance(G12, 0, _with_item(_hero("BMA070"), "THK010"))
	_next(m12)
	_next(m12)
	_ok.call(_is_deactivated(G12, 0, 0), "THK010 Ice Rod : la salle survecue est desactivee jusqu'a la fin du tour")
	# THK003 Inquisitor's Robes : la premiere salle avancee survecue est detruite (une seule fois)
	var lv13 := _live()
	var m13: Node = lv13[0]
	var G13: Dictionary = lv13[1]
	_dungeon(G13, 0, [_plain("N", "trap", [1], 1), _plain("ADV1", "trap", [1], 1, true), _plain("ADV2", "trap", [1], 1, true)])
	_entrance(G13, 0, _with_item(_hero("BMA060"), "THK003")) # 8 PV
	_next(m13)
	_next(m13)
	_next(m13)
	var left13: Array = []
	for st in (_p(G13, 0)["dungeon"] as Array):
		var rv = BossEngine.active_room(st)
		if rv != null:
			left13.append(str(rv.get("id", "")))
	_ok.call(not left13.has("ADV1") and left13.has("ADV2") and left13.has("N"), "THK003 Inquisitor's Robes : seule la premiere salle avancee survecue est detruite")
	# THK013 Bag of Holding : une salle a 2 icones de tresor ou plus survecue est detruite
	var lv14 := _live()
	var m14: Node = lv14[0]
	var G14: Dictionary = lv14[1]
	_dungeon(G14, 0, [_plain("ONE", "trap", [1], 1), _plain("TWO", "trap", [1, 2], 1)])
	_entrance(G14, 0, _with_item(_hero("BMA076"), "THK013")) # Thief treasure 4
	_next(m14)
	_next(m14)
	_next(m14)
	var left14: Array = []
	for st in (_p(G14, 0)["dungeon"] as Array):
		var rv2 = BossEngine.active_room(st)
		if rv2 != null:
			left14.append(str(rv2.get("id", "")))
	_ok.call(left14.has("ONE") and not left14.has("TWO"), "THK013 Bag of Holding : la salle a 2 icones de tresor est detruite, pas celle a 1")

# --- Objets : Power-Up au niveau des crochets ----------------------------------------------------------------------------------

func _t_power_ups_hooks() -> void:
	# THK002 Holy Hand Grenade : le proprietaire du donjon defausse 2 salles au hasard
	var G := _G([_player(0), _player(1)])
	_hand(G, 0).append_array([_plain("R1"), _plain("R2"), _plain("R3")])
	ThkAbilities.on_hero_survived(G, 0, _with_item(_hero("BMA056"), "THK002"))
	_ok.call(_n_rooms(G, 0) == 1 and (G["decks"]["roomDiscard"] as Array).size() == 2, "THK002 Holy Hand Grenade : 2 salles defaussees au hasard par le proprietaire du donjon")
	_ok.call((_p(G, 0)["items"] as Array).size() == 1 and bool(_p(G, 0)["items"][0]["faceDown"]), "THK002 : l'Objet va face cachee dans le scorekeeping")
	# THK009 Antimagic Lizard : 2 sorts au hasard
	var G9 := _G([_player(0), _player(1)])
	_hand(G9, 0).append_array([_spl("A"), _spl("B"), _spl("C")])
	ThkAbilities.on_hero_survived(G9, 0, _with_item(_hero("BMA068"), "THK009"))
	_ok.call(_n_spells(G9, 0) == 1 and (G9["decks"]["spellDiscard"] as Array).size() == 2, "THK009 Antimagic Lizard : 2 sorts defausses au hasard")
	# THK012 Necronomicon : chaque adversaire pioche un sort
	var G12 := _G([_player(0), _player(1), _player(2)])
	ThkAbilities.on_hero_survived(G12, 0, _with_item(_hero("BMA070"), "THK012"))
	_ok.call(_n_spells(G12, 0) == 0 and _n_spells(G12, 1) == 1 and _n_spells(G12, 2) == 1, "THK012 Necronomicon : chaque adversaire pioche un sort, pas le proprietaire")
	# THK008 Vorpal Blade : Blessure supplementaire jusqu'a la fin du tour (en tete de pile), comptee pour les 5 Blessures
	var G8 := _G([_player(0), _player(1)])
	var w8: Array = _p(G8, 0)["wounds"]
	w8.append({"name": "x", "wounds": 1, "souls": 0, "turn": 3})
	ThkAbilities.on_hero_survived(G8, 0, _with_item(_hero("BMA064"), "THK008"))
	_ok.call(CardDB.total_wounds(_p(G8, 0)) == 2 and bool(w8[0].get("thkTemp", false)), "THK008 Vorpal Blade : +1 Blessure en tete de pile")
	ThkAbilities.on_turn_start(G8)
	_ok.call(CardDB.total_wounds(_p(G8, 0)) == 1 and w8.size() == 1, "THK008 Vorpal Blade : la Blessure supplementaire disparait au debut du tour suivant")
	# THK011/THK015/THK018/THK007 : bonus et desactivations au debut de l'aventure
	var G7 := _G([_player(0, [_plain("A", "trap"), _plain("B", "monster"), _plain("C", "monster")]), _player(1)])
	_ok.call(ThkAbilities.on_hero_start(G7, 0, _with_item(_hero("BMA062"), "THK007")) == 5, "THK007 Oversized Sword : +5 PV au debut de l'aventure")
	ThkAbilities.on_hero_start(G7, 0, _with_item(_hero("BMA062"), "THK018"))
	_ok.call(_is_deactivated(G7, 0, 1) and not _is_deactivated(G7, 0, 0), "THK018 Pet Monster : premiere salle Monster desactivee")
	# THK010 Ice Rod et THK017 Boots en crochet de sortie de salle
	var G10 := _G([_player(0, [_plain("A", "trap"), _plain("B", "trap"), _plain("C", "trap")]), _player(1)])
	var ir := _with_item(_hero("BMA070"), "THK010")
	_adv(G10, 0, ir, 1, 3)
	ThkAbilities.on_room_exit(G10, 0, 0, 1)
	_ok.call(_is_deactivated(G10, 0, 0), "THK010 Ice Rod : on_room_exit desactive la salle survecue")
	var G17 := _G([_player(0, [_plain("A", "trap"), _plain("B", "trap"), _plain("C", "trap")]), _player(1)])
	_adv(G17, 0, _with_item(_hero("BMA074"), "THK017"), 1, 3)
	_ok.call(ThkAbilities.on_room_exit(G17, 0, 0, 1) == 2, "THK017 Boots of Jumping : la salle suivante est ignoree (indice 1 -> 2)")
	(SpellEffects._effects(G17)["deactivatedRooms"] as Array).append({"playerId": 0, "roomIndex": 1})
	_adv(G17, 0, _with_item(_hero("BMA074"), "THK017"), 1, 3)
	_ok.call(ThkAbilities.on_room_exit(G17, 0, 0, 1) == 2, "THK017 Boots of Jumping : une salle desactivee reste « la prochaine salle » (ignoree)")
	# THK014 Cheat Code : le texte des salles du donjon est ignore tant que le heros y est
	var G14 := _G([_player(0, [_plain("A")]), _player(1)])
	_adv(G14, 0, _with_item(_hero("BMA076"), "THK014"), 0, 4)
	_ok.call(ThkAbilities.cheat_code(G14, 0) and BossEngine.abilities_locked(G14, 0) and not ThkAbilities.cheat_code(G14, 1), "THK014 Cheat Code : texte des salles ignore dans le donjon du heros seulement")
	G14["adventure"] = {}
	_ok.call(not ThkAbilities.cheat_code(G14, 0), "THK014 Cheat Code : plus d'effet sans heros")
	# THK020 Ring of Invisibility : pas de sorts pendant l'aventure tant que le heros est a l'entree ou dans le donjon
	var G20 := _G([_player(0), _player(1)])
	_entrance(G20, 0, _with_item(_hero("BMA080"), "THK020"))
	G20["phase"] = "adventure"
	_ok.call(ThkAbilities.spells_blocked(G20, 0) and not ThkAbilities.spells_blocked(G20, 1), "THK020 Ring of Invisibility : sorts interdits au proprietaire du donjon")
	G20["phase"] = "build"
	_ok.call(not ThkAbilities.spells_blocked(G20, 0), "THK020 Ring of Invisibility : seulement pendant la phase d'aventure")
	var mr := _match(G20)
	G20["phase"] = "adventure"
	(_hand(G20, 0)).append({"id": "BMA043", "name": "Spell", "isSpell": true, "category": 3})
	_ok.call(not mr.legal_moves(0).any(func(mv): return str((mv as Dictionary)["type"]) == "playSpell"), "THK020 Ring of Invisibility : aucun coup playSpell")

func _t_power_ups_damage() -> void:
	var rooms := [_plain("M1", "monster", [1], 3), _plain("T1", "trap", [1], 2), _plain("A1", "monster", [1], 4, true), _plain("M2", "monster", [1], 3), _plain("M3", "monster", [1], 3)]
	var G := _G([_player(0, rooms), _player(1)])
	var p0 := _p(G, 0)
	# THK005 Goblin Suit : aucune blessure des salles Monster ordinaires
	var gob := _with_item(_hero("BMA062"), "THK005")
	_ok.call(BossEngine.room_damage_with_modifiers(G, p0, 0, gob) == 0, "THK005 Goblin Suit : salle Monster ordinaire -> 0 degat")
	_ok.call(BossEngine.room_damage_with_modifiers(G, p0, 1, gob) == 2, "THK005 Goblin Suit : une salle Trap inflige ses degats")
	_ok.call(BossEngine.room_damage_with_modifiers(G, p0, 2, gob) == 4, "THK005 Goblin Suit : une salle Monster avancee inflige ses degats")
	_ok.call(BossEngine.room_damage_with_modifiers(G, p0, 0, _hero("BMA062")) == 3, "THK005 : un heros sans Objet subit les degats")
	# THK019 Star of Invulnerability : aucun degat des trois premieres salles
	var star := _with_item(_hero("BMA056"), "THK019")
	var dm: Array = []
	for i in 5:
		dm.append(BossEngine.room_damage_with_modifiers(G, p0, i, star))
	_ok.call(dm == [0, 0, 0, 3, 3], "THK019 Star of Invulnerability : les 3 premieres salles n'infligent rien (%s)" % str(dm))
	(SpellEffects._effects(G)["deactivatedRooms"] as Array).append({"playerId": 0, "roomIndex": 0})
	_ok.call(BossEngine.room_damage_with_modifiers(G, p0, 3, star) == 0, "THK019 : une salle desactivee ne compte pas parmi les trois premieres")
	# THK006 Claws : +1 PV par salle Monster visible et active du donjon
	var G6 := _G([_player(0, [_plain("A", "monster"), _plain("B", "monster"), _plain("C", "trap")]), _player(1)])
	var claw := _with_item(_hero("BMA062"), "THK006")
	_adv(G6, 0, claw, 0, 4)
	ThkAbilities.sync_hero(G6)
	_ok.call(int(G6["adventure"]["hp"]) == 6, "THK006 Claws of the Berserker : +2 PV pour deux salles Monster")
	_p(G6, 0)["dungeon"].remove_at(0)
	ThkAbilities.sync_hero(G6)
	_ok.call(int(G6["adventure"]["hp"]) == 5, "THK006 : le bonus suit le nombre de salles Monster (une detruite -> 5)")
	# THK016 The Bomb : derniere salle detruite sans degats
	var G16 := _G([_player(0, [_plain("A", "trap"), _plain("B", "trap")]), _player(1)])
	var bh := _with_item(_hero("BMA076"), "THK016")
	_adv(G16, 0, bh, 0, 4)
	_ok.call(ThkAbilities.on_room_enter(G16, 0, 0, _plain("A", "trap")) == "", "THK016 The Bomb : rien tant que ce n'est pas la derniere salle")
	_ok.call(ThkAbilities.on_room_enter(G16, 0, 1, _plain("B", "trap")) == "bomb" and (_p(G16, 0)["dungeon"] as Array).size() == 1, "THK016 The Bomb : la derniere salle est detruite")

# --- Objets : capacites de Boss (« Reward ») ------------------------------------------------------------------------------------

func _t_rewards_simple() -> void:
	# THK001 Extra Life
	var G1 := _G([_player(0), _player(1)])
	_owned(G1, 0, "THK001")
	_use(G1, 0, "THK001")
	_ok.call(ThkAbilities.wound_immune(G1, 0) and not ThkAbilities.wound_immune(G1, 1), "THK001 Extra Life (Boss) : pas de defaite par Blessures ce tour")
	# THK002 Holy Hand Grenade : chaque adversaire defausse une salle
	var G2 := _G([_player(0), _player(1), _player(2)])
	_hand(G2, 1).append_array([_plain("R1"), _plain("R2")])
	_hand(G2, 2).append_array([_plain("R3")])
	_owned(G2, 0, "THK002")
	_use(G2, 0, "THK002")
	_ok.call(_n_rooms(G2, 1) == 1 and _n_rooms(G2, 2) == 0 and _n_rooms(G2, 0) == 0, "THK002 Holy Hand Grenade (Boss) : chaque adversaire defausse une salle au hasard")
	# THK004 Staff of Healing : soigne une Blessure ordinaire
	var G4 := _G([_player(0), _player(1)])
	var hurt := _hero("BMA056")
	_p(G4, 0)["wounds"] = [{"name": "Cleric", "wounds": 1, "souls": 1, "hero": hurt, "turn": 1}]
	_owned(G4, 0, "THK004")
	_use(G4, 0, "THK004")
	_ok.call((_p(G4, 0)["wounds"] as Array).is_empty() or not (_pending(G4).is_empty()), "THK004 Staff of Healing (Boss) : soigne une Blessure ordinaire")
	if not _pending(G4).is_empty():
		_match(G4)._resolve_choice(0, 0)
	_ok.call((_p(G4, 0)["wounds"] as Array).is_empty(), "THK004 : la Blessure est soignee")
	var G4b := _G([_player(0), _player(1)])
	_owned(G4b, 0, "THK004")
	_ok.call(ThkAbilities.effect_check(G4b, 0, "THK004") != "" and ThkAbilities.use_moves(G4b, _p(G4b, 0), 0).is_empty(), "THK004 : sans Blessure ordinaire, la capacite n'est pas offerte")
	# THK005 Goblin Suit : toutes vos salles Monster ordinaires +1
	var G5 := _G([_player(0, [_plain("M", "monster", [1], 2), _plain("T", "trap", [1], 2), _plain("AM", "monster", [1], 2, true)]), _player(1)])
	_owned(G5, 0, "THK005")
	_use(G5, 0, "THK005")
	var p5 := _p(G5, 0)
	_ok.call(BossEngine.room_damage_with_modifiers(G5, p5, 0, null) == 3 and BossEngine.room_damage_with_modifiers(G5, p5, 1, null) == 2 and BossEngine.room_damage_with_modifiers(G5, p5, 2, null) == 2,
		"THK005 Goblin Suit (Boss) : +1 aux salles Monster ordinaires seulement")
	# THK012 Necronomicon : piocher un sort
	var G12 := _G([_player(0), _player(1)])
	_owned(G12, 0, "THK012")
	_use(G12, 0, "THK012")
	_ok.call(_n_spells(G12, 0) == 1, "THK012 Necronomicon (Boss) : pioche un sort")
	# THK013 Bag of Holding : une salle a 2 icones depuis la defausse (1 seule candidate : prise d'office)
	var G13 := _G([_player(0), _player(1)])
	(G13["decks"] as Dictionary)["roomDiscard"] = [_plain("ONE", "trap", [1], 1), _plain("TWO", "trap", [1, 2], 1)]
	_owned(G13, 0, "THK013")
	_use(G13, 0, "THK013")
	_ok.call(_ids(_hand(G13, 0)) == ["TWO"] and _ids(G13["decks"]["roomDiscard"]) == ["ONE"], "THK013 Bag of Holding (Boss) : la salle a 2 icones de tresor rejoint la main")
	var G13b := _G([_player(0), _player(1)])
	(G13b["decks"] as Dictionary)["roomDiscard"] = [_plain("ONE", "trap", [1], 1)]
	_owned(G13b, 0, "THK013")
	_ok.call(ThkAbilities.effect_check(G13b, 0, "THK013") != "", "THK013 : aucune salle a 2 icones dans la defausse -> injouable")
	# THK017 Boots : le heros ignore la prochaine salle
	var G17 := _G([_player(0, [_plain("A"), _plain("B")]), _player(1)])
	_adv(G17, 0, _hero("BMA062"), 0, 4)
	_owned(G17, 0, "THK017")
	_use(G17, 0, "THK017")
	_ok.call(bool(G17["adventure"].get("thkSkip", false)) and ThkAbilities.on_room_exit(G17, 0, 0, 1) == 2, "THK017 Boots of Jumping (Boss) : le heros ignore la prochaine salle")
	# THK007 Oversized Sword : un heros dans un donjon +5
	var G7 := _G([_player(0, [_plain("A")]), _player(1)])
	_adv(G7, 1, _hero("BMA062"), 0, 4)
	(G7["adventure"] as Dictionary)["playerId"] = 0
	_owned(G7, 1, "THK007")
	_use(G7, 1, "THK007")
	_ok.call(int(G7["adventure"]["hp"]) == 9, "THK007 Oversized Sword (Boss) : le heros actif gagne 5 PV")
	# THK016 The Bomb : detruit une salle de votre donjon, 5 degats au heros qui s'y trouve
	var G16 := _G([_player(0, [_plain("A"), _plain("B")]), _player(1)])
	_adv(G16, 0, _hero("BMA076"), 1, 8)
	_owned(G16, 0, "THK016")
	_use(G16, 0, "THK016")
	_ok.call((_p(G16, 0)["dungeon"] as Array).size() == 1 and int(G16["adventure"]["hp"]) == 3, "THK016 The Bomb (Boss) : salle detruite, 5 degats au heros qui s'y trouve (8 -> 3)")
	var G16b := _G([_player(0, [_plain("A")]), _player(1)])
	_owned(G16b, 0, "THK016")
	_ok.call(ThkAbilities.effect_check(G16b, 0, "THK016") != "", "THK016 : sans heros dans votre donjon, injouable")

func _t_rewards_targeted() -> void:
	# THK003 Inquisitor's Robes : detruit une salle avancee de n'importe quel donjon
	var G3 := _G([_player(0, [_plain("N"), _plain("ADV", "trap", [1], 1, true)]), _player(1)])
	_owned(G3, 0, "THK003")
	_use(G3, 0, "THK003")
	if not _pending(G3).is_empty():
		_match(G3)._resolve_choice(0, 0)
	_ok.call((_p(G3, 0)["dungeon"] as Array).size() == 1 and _ids(G3["decks"]["roomDiscard"]) == ["ADV"], "THK003 Inquisitor's Robes (Boss) : une salle avancee est detruite")
	var G3b := _G([_player(0, [_plain("N")]), _player(1)])
	_owned(G3b, 0, "THK003")
	_ok.call(ThkAbilities.effect_check(G3b, 0, "THK003") != "", "THK003 : sans salle avancee, injouable")
	# THK006 Claws : +1 PV par salle Monster de VOTRE donjon au heros choisi (heros en ville : PV retenus pour son entree)
	var G6 := _G([_player(0, [_plain("A", "monster"), _plain("B", "monster")]), _player(1)])
	var townie := _hero("BMA062")
	G6["town"] = [townie]
	_owned(G6, 0, "THK006")
	_use(G6, 0, "THK006")
	var held := TnlAbilities._list(G6, "heroHp")
	_ok.call(held.any(func(e): return str((e as Dictionary)["heroId"]) == str(townie["id"]) and int((e as Dictionary)["amount"]) == 2), "THK006 Claws of the Berserker (Boss) : le heros choisi gagne +2 PV (PV retenus)")
	# THK008 Vorpal Blade : tue un heros qui a subi au moins la moitie de ses PV ; le tueur recupere ames et Objet
	var G8 := _G([_player(0), _player(1)])
	var weak := _with_item(_hero("BMA056"), "THK005")
	weak["hp"] = 2 # 4 PV imprimes, 2 de degats
	var healthy := _hero("BMA056")
	G8["town"] = [healthy, weak]
	_owned(G8, 0, "THK008")
	_ok.call(ThkAbilities.vorpal_targets(G8).size() == 1, "THK008 Vorpal Blade : seul un heros ayant subi au moins la moitie de ses PV est ciblable")
	_use(G8, 0, "THK008")
	_ok.call(_pending(G8).is_empty() and not (G8["town"] as Array).has(weak) and (_p(G8, 0)["souls"] as Array).size() == 1, "THK008 Vorpal Blade (Boss) : le heros blesse est tue, son ame va au tueur")
	_ok.call((_p(G8, 0)["items"] as Array).any(func(it): return str((it as Dictionary).get("id", "")) == "THK005"), "THK008 : l'Objet du heros tue est recupere")
	var G8b := _G([_player(0), _player(1)])
	G8b["town"] = [_hero("BMA056")]
	_owned(G8b, 0, "THK008")
	_ok.call(ThkAbilities.effect_check(G8b, 0, "THK008") != "", "THK008 : aucun heros blesse -> injouable")
	# THK009 Antimagic Lizard : un adversaire defausse un sort
	var G9 := _G([_player(0), _player(1)])
	_hand(G9, 1).append_array([_spl("A"), _spl("B")])
	_owned(G9, 0, "THK009")
	_use(G9, 0, "THK009")
	_ok.call(_n_spells(G9, 1) == 1, "THK009 Antimagic Lizard (Boss) : l'adversaire defausse un sort au hasard")
	# THK010 Ice Rod : desactive une salle d'un adversaire
	var G10 := _G([_player(0, [_plain("Mine")]), _player(1, [_plain("Theirs")])])
	_owned(G10, 0, "THK010")
	_use(G10, 0, "THK010")
	_ok.call(_pending(G10).is_empty() and _is_deactivated(G10, 1, 0) and not _is_deactivated(G10, 0, 0), "THK010 Ice Rod (Boss) : une salle adverse est desactivee jusqu'a la fin du tour")
	# THK011 Magic Mirror : copie la capacite d'un Objet face visible (ici Necronomicon d'un adversaire)
	var G11 := _G([_player(0), _player(1)])
	_owned(G11, 1, "THK012")
	_owned(G11, 0, "THK011")
	_use(G11, 0, "THK011")
	_ok.call(_pending(G11).is_empty() and _n_spells(G11, 0) == 1, "THK011 Magic Mirror (Boss) : copie la capacite de Necronomicon (pioche un sort)")
	_ok.call(not bool(_p(G11, 1)["items"][0]["faceDown"]), "THK011 : l'Objet copie reste face visible")
	var G11b := _G([_player(0), _player(1)])
	_owned(G11b, 0, "THK011")
	_ok.call(ThkAbilities.effect_check(G11b, 0, "THK011") != "", "THK011 : aucun Objet face visible a copier -> injouable")
	# THK014 Cheat Code : ignore le texte d'une salle jusqu'a la fin du tour
	var G14 := _G([_player(0, [_plain("Mine")]), _player(1)])
	_owned(G14, 0, "THK014")
	_use(G14, 0, "THK014")
	_ok.call(TnlAbilities.no_text(BossEngine.active_room(_p(G14, 0)["dungeon"][0])), "THK014 Cheat Code (Boss) : le texte de la salle est ignore")
	# THK015 Ten Foot Pole : desactive une salle Trap ; THK018 Pet Monster : une salle Monster
	var G15 := _G([_player(0, [_plain("M", "monster"), _plain("T", "trap")]), _player(1)])
	_owned(G15, 0, "THK015")
	_use(G15, 0, "THK015")
	_ok.call(_is_deactivated(G15, 0, 1) and not _is_deactivated(G15, 0, 0), "THK015 Ten Foot Pole (Boss) : une salle Trap est desactivee")
	var G18 := _G([_player(0, [_plain("M", "monster"), _plain("T", "trap")]), _player(1)])
	_owned(G18, 0, "THK018")
	_use(G18, 0, "THK018")
	_ok.call(_is_deactivated(G18, 0, 0) and not _is_deactivated(G18, 0, 1), "THK018 Pet Monster (Boss) : une salle Monster est desactivee")
	# THK019 Star of Invulnerability : retire du jeu un heros qui a survecu a votre donjon ce tour
	var G19 := _G([_player(0), _player(1)])
	var surv := _hero("BMA056")
	_p(G19, 0)["wounds"] = [{"name": "Cleric", "wounds": 1, "souls": 1, "hero": surv, "turn": 3}]
	_owned(G19, 0, "THK019")
	_use(G19, 0, "THK019")
	_ok.call((_p(G19, 0)["wounds"] as Array).is_empty() and not (G19["decks"]["heroDiscard"] as Array).has(surv), "THK019 Star of Invulnerability (Boss) : le heros qui a survecu est retire du jeu (plus de Blessure)")
	var G19b := _G([_player(0), _player(1)])
	_owned(G19b, 0, "THK019")
	_ok.call(ThkAbilities.effect_check(G19b, 0, "THK019") != "", "THK019 : aucun heros n'a survecu ce tour -> injouable")

func _t_reward_ring() -> void:
	# THK020 Ring of Invisibility : annule un sort joue pendant VOTRE phase d'aventure
	var G := _G([_player(0), _player(1)])
	G["phase"] = "adventure"
	G["stack"] = [{"type": "spell", "playerId": 1, "card": _spl("Bolt")}]
	G["stackActivePlayer"] = 0
	_owned(G, 0, "THK020")
	_ok.call(ThkAbilities.effect_check(G, 0, "THK020") == "" and not ThkAbilities.use_moves(G, _p(G, 0), 0).is_empty(), "THK020 Ring of Invisibility (Boss) : jouable en reponse a un sort adverse")
	_use(G, 0, "THK020")
	_ok.call((G["stack"] as Array).is_empty() and _ids(G["decks"]["spellDiscard"]) == ["Bolt"], "THK020 Ring of Invisibility (Boss) : le sort est annule")
	# par le moteur : la pile est vide apres l'annulation, la main revient au joueur de phase (pas de fenetre de reponse rouverte)
	var Ge := _G([_player(0, [_plain("A")]), _player(1)])
	_adv(Ge, 0, _hero("BMA062"), 0, 4)
	Ge["stack"] = [{"id": "spell-x", "type": "spell", "playerId": 1, "card": _spl("Bolt"), "target": {}, "resolved": false}]
	Ge["stackActivePlayer"] = 0
	Ge["stackReturnPlayer"] = 1
	Ge["stackPassed"] = {"1": true, 1: true}
	Ge["activePlayer"] = 0
	_owned(Ge, 0, "THK020")
	var me := _match(Ge)
	_ok.call(me.legal_moves(0).any(func(mv): return str((mv as Dictionary)["type"]) == "useItem"), "THK020 Ring of Invisibility : useItem offert en reponse dans la Spell Battle")
	_ok.call(me.apply_move(0, {"type": "useItem", "args": ["THK020"]}) and (Ge["stack"] as Array).is_empty() and int(Ge["activePlayer"]) == 0 and Ge.get("stackReturnPlayer") == null,
		"THK020 Ring of Invisibility : sort annule, la main revient au joueur de phase (pile vide, aucune fenetre rouverte)")
	var Gb := _G([_player(0), _player(1)])
	Gb["phase"] = "build"
	_owned(Gb, 0, "THK020")
	_ok.call(ThkAbilities.effect_check(Gb, 0, "THK020") != "", "THK020 : sans sort sur la pile, injouable")

# --- salles avancees -----------------------------------------------------------------------------------------------------------------

func _t_rooms() -> void:
	# THK021 Orcish Smithy : Construction, une fois par tour, attache un Objet de la ville a n'importe quel heros (meme a etoile)
	var smithy := _room("THK021")
	var G := _G([_player(0, [smithy]), _player(1)])
	var p0 := _p(G, 0)
	var star := _card(CardDB.heroes, "KSA016")
	var plain_h := _hero("BMA062")
	G["town"] = [star]
	G["townItems"] = [_item("THK001")]
	_ok.call(ThkAbilities.check(G, p0, 0, 0, smithy) == "", "THK021 Orcish Smithy : activable en Construction avec un Objet libre et un heros sans Objet")
	_ok.call(RoomAbilities.activate_room_ability(G, 0, 0) == null, "THK021 : activation via RoomAbilities")
	_ok.call(ThkAbilities.item_id(star) == "THK001" and (G["townItems"] as Array).is_empty(), "THK021 : l'Objet s'attache au heros choisi (meme a etoile, quel que soit le tresor)")
	_ok.call(ThkAbilities.check(G, p0, 0, 0, smithy) != "", "THK021 : une fois par tour")
	smithy["usedThisTurn"] = false
	G["townItems"] = [_item("THK005")]
	G["town"] = [star, plain_h]
	_ok.call(RoomAbilities.activate_room_ability(G, 0, 0) == null and _pending(G).is_empty() and ThkAbilities.item_id(plain_h) == "THK005", "THK021 : seuls les heros sans Objet sont proposes (un seul : choisi d'office)")
	G["phase"] = "adventure"
	smithy["usedThisTurn"] = false
	_ok.call(ThkAbilities.check(G, p0, 0, 0, smithy) != "", "THK021 : Construction seulement")
	var G0 := _G([_player(0, [_room("THK021")]), _player(1)], ["base", "tools"])
	_ok.call(ThkAbilities.check(G0, _p(G0, 0), 0, 0, _top(G0, 0, 0)) != "" and RoomAbilities.activate_room_ability(G0, 0, 0) != null, "THK021 sans case wiki : aucune capacite")
	# THK022 Burial Mound : defausse 2 salles pour retourner face visible un Objet face cachee (si aucun Objet face visible)
	var mound := _room("THK022")
	var G2 := _G([_player(0, [mound]), _player(1)])
	_owned(G2, 0, "THK012", true)
	_hand(G2, 0).append_array([_plain("R1"), _plain("R2"), _plain("R3")])
	_ok.call(ThkAbilities.check(G2, _p(G2, 0), 0, 0, mound) == "", "THK022 Burial Mound : activable avec 2 salles en main et un Objet face cachee")
	RoomAbilities.activate_room_ability(G2, 0, 0)
	_drain(_match(G2), 0)
	_ok.call(not bool(_p(G2, 0)["items"][0]["faceDown"]) and _n_rooms(G2, 0) == 1 and (G2["decks"]["roomDiscard"] as Array).size() == 2, "THK022 Burial Mound : 2 salles defaussees, l'Objet est retourne face visible")
	mound["usedThisTurn"] = false
	_ok.call(ThkAbilities.check(G2, _p(G2, 0), 0, 0, mound) != "", "THK022 : refuse quand un Objet est deja face visible")
	var G2b := _G([_player(0, [_room("THK022")]), _player(1)])
	_owned(G2b, 0, "THK012", true)
	_hand(G2b, 0).append(_plain("R1"))
	_ok.call(ThkAbilities.check(G2b, _p(G2b, 0), 0, 0, _top(G2b, 0, 0)) != "", "THK022 : moins de 2 salles en main -> refuse")
	# THK023 Artificer's Workbench : retourne un Objet face visible face cachee pour piocher un sort (sans declencher sa capacite)
	var bench := _room("THK023")
	var G3 := _G([_player(0, [bench]), _player(1)])
	_owned(G3, 0, "THK005")
	_ok.call(ThkAbilities.check(G3, _p(G3, 0), 0, 0, bench) == "", "THK023 Artificer's Workbench : activable avec un Objet face visible")
	_ok.call(RoomAbilities.activate_room_ability(G3, 0, 0) == null and bool(_p(G3, 0)["items"][0]["faceDown"]) and _n_spells(G3, 0) == 1 and not (SpellEffects._effects(G3)["ordinaryMonsterBonus"] as Array).has(0),
		"THK023 : l'Objet est retourne face cachee, un sort est pioche, la capacite n'est PAS declenchee")
	_ok.call(ThkAbilities.check(G3, _p(G3, 0), 0, 0, bench) != "", "THK023 : une fois par tour / plus d'Objet face visible")
	# THK024 Magnetic Ceiling : quand un heros portant un Objet y entre, vous pouvez le prendre (face cachee)
	var ceil := _room("THK024")
	var G4 := _G([_player(0, [ceil]), _player(1)])
	var carrier := _with_item(_hero("BMA062"), "THK005")
	_adv(G4, 0, carrier, 0, 4)
	_ok.call(ThkAbilities.on_room_enter(G4, 0, 0, ceil) == "pending" and str(_pending(G4).get("step", "")) == "thk_ceiling" and bool(_pending(G4).get("optional", false)), "THK024 Magnetic Ceiling : choix facultatif quand un heros avec Objet entre")
	ThkAbilities.resolve_pick(G4, 0, _pending(G4), 0)
	_ok.call(ThkAbilities.item_id(carrier) == "" and (_p(G4, 0)["items"] as Array).size() == 1 and bool(_p(G4, 0)["items"][0]["faceDown"]), "THK024 : l'Objet va face cachee dans votre scorekeeping")
	var G4b := _G([_player(0, [_room("THK024")]), _player(1)])
	var carrier2 := _with_item(_hero("BMA062"), "THK005")
	_adv(G4b, 0, carrier2, 0, 4)
	ThkAbilities.on_room_enter(G4b, 0, 0, _top(G4b, 0, 0))
	ThkAbilities.resolve_pick(G4b, 0, _pending(G4b), -1)
	_ok.call(ThkAbilities.item_id(carrier2) == "THK005" and (_p(G4b, 0)["items"] as Array).is_empty(), "THK024 : refuser laisse l'Objet au heros")
	var G4c := _G([_player(0, [_room("THK024")]), _player(1)])
	_adv(G4c, 0, _hero("BMA062"), 0, 4)
	_ok.call(ThkAbilities.on_room_enter(G4c, 0, 0, _top(G4c, 0, 0)) == "", "THK024 : rien si le heros ne porte pas d'Objet")
	# integration moteur : le choix de la salle puis ses degats (Match._thk_resume_enter)
	var lv := _live()
	var m: Node = lv[0]
	var G5: Dictionary = lv[1]
	_dungeon(G5, 0, [_room("THK024")])
	var carrier3 := _with_item(_hero("BMA062"), "THK005")
	_entrance(G5, 0, carrier3)
	_next(m)
	_ok.call(str(_pending(G5).get("step", "")) == "thk_ceiling", "THK024 Magnetic Ceiling : le moteur ouvre le choix a l'entree du heros")
	_drain(m, 0)
	_ok.call((_p(G5, 0)["items"] as Array).any(func(it): return str((it as Dictionary).get("id", "")) == "THK005"), "THK024 : choix resolu par le moteur, l'Objet est dans le scorekeeping")

func _top(G: Dictionary, pid: int, idx: int) -> Dictionary:
	return BossEngine.active_room(((G["players"][pid] as Dictionary)["dungeon"] as Array)[idx])

# --- THK025 Excavation ---------------------------------------------------------------------------------------------------------------

func _t_excavation() -> void:
	var G := _G([_player(0), _player(1)])
	var a := _owned(G, 0, "THK005", true)
	var b := _owned(G, 1, "THK010", false)
	var c := _owned(G, 1, "THK012", true)
	var opts := SpellTargeting.enumerate_targets("any-item", G, _p(G, 0), 0)
	var keyed: Array = []
	for o in opts:
		keyed.append("%d:%d:%s" % [int(o["targetPlayerId"]), int(o["itemIndex"]), str(o["flipTo"])])
	_ok.call(keyed.has("0:0:false") and keyed.has("1:0:true") and not keyed.has("1:1:false"), "THK025 Excavation (flipTo = faceDown vise) : face visible proposee seulement s'il n'y a pas deja un Objet face visible chez le proprietaire")
	_ok.call(SpellEffects._excavation(G, 0, {}, {"targetPlayerId": 0, "itemIndex": 0, "flipTo": false}), "THK025 Excavation : le sort se resout")
	_ok.call(not bool(a["faceDown"]), "THK025 : Objet retourne face visible")
	SpellEffects._excavation(G, 0, {}, {"targetPlayerId": 1, "itemIndex": 0, "flipTo": true})
	_ok.call(bool(b["faceDown"]), "THK025 : Objet adverse retourne face cachee")
	SpellEffects._excavation(G, 0, {}, {"targetPlayerId": 1, "itemIndex": 1, "flipTo": false})
	SpellEffects._excavation(G, 0, {}, {"targetPlayerId": 1, "itemIndex": 0, "flipTo": false})
	_ok.call(ThkAbilities.face_up_item(_p(G, 1)) == c and bool(b["faceDown"]), "THK025 : jamais deux Objets face visible chez le meme joueur")
	# jouable via le moteur (case wiki) : coup playSpell offert, absent sans la case
	var Gm := _G([_player(0), _player(1)])
	var exc := _card(CardDB.spells, "THK025")
	exc["isSpell"] = true
	exc["thkLive"] = true
	_hand(Gm, 0).append(exc)
	_owned(Gm, 1, "THK010", false)
	var mm := _match(Gm)
	_ok.call(mm.legal_moves(0).any(func(mv): return str((mv as Dictionary)["type"]) == "playSpell"), "THK025 : Excavation jouable (coup playSpell) avec la case wiki")
	var Gn := _G([_player(0), _player(1)], ["base", "tools"])
	var exc2 := _card(CardDB.spells, "THK025")
	exc2["isSpell"] = true
	_hand(Gn, 0).append(exc2)
	_owned(Gn, 1, "THK010", false)
	var mn := _match(Gn)
	_ok.call(not mn.legal_moves(0).any(func(mv): return str((mv as Dictionary)["type"]) == "playSpell"), "THK025 sans case wiki : toujours injouable")

# --- IA : les coups useItem sont notes (le soak par paquet est dans soak_runner / tools/run_godot_tests.py) -------------------------------------------------------------

func _t_ai_legal_moves() -> void:
	var G := _G([_player(0), _player(1)])
	G["phase"] = "build"
	_owned(G, 0, "THK012") # Necronomicon : toujours rentable (pioche un sort)
	var m := _match(G)
	var moves: Array = m.legal_moves(0)
	var use_moves := moves.filter(func(mv): return str((mv as Dictionary)["type"]) == "useItem")
	_ok.call(use_moves.size() == 1, "THK IA : le coup useItem est un coup legal")
	var s := AI.score_move(m, 0, use_moves[0]) if use_moves.size() == 1 else -1000.0
	_ok.call(s > 0.0, "THK IA : Necronomicon est joue (score > 0)")
	var Gx := _G([_player(0), _player(1)])
	Gx["phase"] = "build"
	_owned(Gx, 0, "THK001") # Extra Life : ne sert que si la defaite par Blessures menace
	var mx := _match(Gx)
	var ux: Array = mx.legal_moves(0).filter(func(mv): return str((mv as Dictionary)["type"]) == "useItem")
	_ok.call(ux.size() == 1 and AI.score_move(mx, 0, ux[0]) <= 0.0, "THK IA : Extra Life n'est pas gaspille sans menace de defaite")
