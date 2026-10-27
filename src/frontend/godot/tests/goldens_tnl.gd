extends RefCounted
## Goldens de l'extension The Next Level (TNL, hors APK). References, par priorite : docs/rules/rules.md (livret TNL + FAQ des cartes), texte des
## cartes (cards.json).
## Appele par goldens.gd : `load("res://godot/tests/goldens_tnl.gd").new().run(_ok, self)`.

var _ok: Callable
var host: Node

func run(ok: Callable, h: Node) -> void:
	_ok = ok
	host = h
	_t_data()
	_t_new_match_decks()
	_t_setup_hands()
	# bosses
	_t_mirrax()
	_t_scarecrow()
	_t_belladonna()
	_t_torix()
	_t_torix_jeopardy()
	_t_killa()
	_t_shellda()
	_t_end_of_turn_resume()
	_t_smoake()
	_t_kazanna()
	_t_timebender()
	_t_nicolius()
	_t_porkus()
	_t_angstigoth()
	_t_eclipse()
	# salles : construction / decouverte
	_t_build_effects()
	_t_uncover_effects()
	_t_incubus_gym()
	_t_megaworm()
	# salles : capacites activees
	_t_dark_portal()
	_t_observatory_treadmill()
	_t_lost_library()
	_t_save_point()
	_t_wreck_chomper_smashinator()
	_t_decapitator_frostbat()
	_t_rust_bullet()
	_t_arena()
	_t_werewolf_den()
	_t_haunted_hall_warp_tube()
	_t_antimagic_zone()
	# salles : passifs / declencheurs
	_t_hero_dies_triggers()
	_t_once_per_turn_death_triggers()
	_t_bom_boy_and_bridge()
	_t_passive_damage()
	_t_spellslime_hall_of_mirrors()
	_t_imp_temple_dragon_graveyard()
	_t_cursed_tomb()
	_t_inner_sanctum_blockpile()
	_t_hatchlings_hoard()
	# sorts
	_t_spell_phases()
	_t_all_your_base()
	_t_another_castle()
	_t_fairy_fountain()
	_t_its_on()
	_t_hiring_spree()
	_t_lightning_bolt()
	_t_meddling_kids()
	_t_meddling_kids_base_passives()
	_t_oh_yeah()
	_t_party_up_pause()
	_t_pity_undead()
	_t_secret_stash_super_effective()
	_t_shortcut()
	_t_arbitrages_wiki()
	_t_surprise_gift()
	_t_wild_monster()
	_t_audit_lot21()
	# heros
	_t_lure_kinds()
	_t_dark_heroes()
	_t_hero_abilities()
	_t_necromancer()
	_t_hero_hp_effects()
	_t_torix_via_apply_move()
	_t_ui_labels_and_menu()
	_t_ai_soak_tnl()
	_t_ai_soak_each_boss()

# --- fabriques d'etats minimaux ----------------------------------------------------------------------

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

func _spell(id: String) -> Dictionary:
	var s := _card(CardDB.spells, id)
	s["isSpell"] = true
	return s

## Salle generique (id hors TNL : aucun declencheur) : id, type, tresors, degats.
func _plain(id: String, type: String = "monster", treasures: Array = [1], damage: int = 1, advanced: bool = false) -> Dictionary:
	return {"id": id, "name": id, "type": type, "advanced": advanced, "treasures": treasures, "damage": damage, "isRoom": true}

func _spl(id: String) -> Dictionary:
	return {"id": id, "name": id, "isSpell": true, "category": 3}

func _hero(id: String) -> Dictionary:
	var h := _card(CardDB.heroes, id)
	h["souls"] = 2 if bool(h.get("epic", false)) else 1
	h["wounds"] = h["souls"]
	return h

func _player(pid: int, boss_id: String, dungeon: Array = [], leveled: bool = false) -> Dictionary:
	var stacks: Array = []
	for r in dungeon:
		stacks.append([r])
	return {"id": pid, "boss": _card(CardDB.bosses, boss_id), "dungeon": stacks, "hand": [], "souls": [], "wounds": [],
		"entrance": [], "eliminated": false, "leveledUp": leveled, "buildsThisTurn": 0}

func _G(players: Array) -> Dictionary:
	var ps := {}
	for p in players:
		ps[int((p as Dictionary)["id"])] = p
	return {"players": ps, "town": [], "log": [], "logs": [], "adventure": {}, "turn": 1, "phase": "adventure", "sets": ["base", "next-level"],
		"effects": SpellEffects.empty_effects(), "stack": [], "pendingChoice": {}, "choiceQueue": [],
		"decks": {"rooms": [], "spells": [], "heroes": [], "epics": [], "items": [], "roomDiscard": [], "spellDiscard": [], "heroDiscard": []}}

func _match(G: Dictionary) -> Node:
	var m = load("res://godot/scripts/Match.gd").new()
	host.add_child(m)
	m.G = G
	return m

func _hand(G: Dictionary, pid: int) -> Array:
	return (G["players"][pid] as Dictionary)["hand"] as Array

func _ids(arr: Array) -> Array:
	var out: Array = []
	for c in arr:
		out.append(str((c as Dictionary).get("id", "")))
	return out

func _decks(G: Dictionary, key: String) -> Array:
	return (G["decks"] as Dictionary)[key] as Array

## Resout les choix en attente avec l'option `idx` (0 par defaut) en passant par Match._resolve_choice (chemin reel).
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

func _fill(G: Dictionary, key: String, n: int, kind: String = "room") -> void:
	for i in n:
		(G["decks"][key] as Array).append(_plain("%s%d" % [key, i]) if kind == "room" else _spl("%s%d" % [key, i]))

func _act(G: Dictionary, pid: int, idx: int, other: int = -1) -> Variant:
	return RoomAbilities.activate_room_ability(G, pid, idx, other)

func _count(arr: Array, prefix: String) -> int:
	var n := 0
	for c in arr:
		if str((c as Dictionary).get("id", "")).begins_with(prefix):
			n += 1
	return n

func _sum_q(arr: Array, prefix: String) -> int:
	var n := 0
	for c in arr:
		if str((c as Dictionary).get("id", "")).begins_with(prefix):
			n += int((c as Dictionary).get("quantity", 1))
	return n

# --- donnees + composition des paquets ---------------------------------------------------------------------

func _t_data() -> void:
	_ok.call(_count(CardDB.bosses, "TNL") == 13 and _count(CardDB.rooms, "TNL") == 43 and _count(CardDB.spells, "TNL") == 17 and _count(CardDB.heroes, "TNL") == 42,
		"TNL : 13 boss, 43 salles, 17 sorts, 42 heros (115 cartes)")
	_ok.call(_sum_q(CardDB.rooms, "TNL") == 75 and _sum_q(CardDB.spells, "TNL") == 31 and _sum_q(CardDB.heroes, "TNL") == 42,
		"livret : 75 salles, 31 sorts, 42 heros (The Brothers en un seul exemplaire)")
	_ok.call(_int_list(CardDB.hero_treasures(_card(CardDB.heroes, "TNL100"))) == [1, 4], "Necromancer : Cleric + Thief (carte, pas le wiki)")
	var kids := _spell("TNL062")
	var yeah := _spell("TNL063")
	_ok.call(CardDB.can_play_spell(kids, "build") and CardDB.can_play_spell(kids, "adventure") and CardDB.can_play_spell(yeah, "build") and CardDB.can_play_spell(yeah, "adventure"),
		"Meddling Kids! et Oh, Yeah! : marteau + hache (jouables dans les deux phases)")
	_ok.call(not CardDB.can_play_spell(_spell("TNL066"), "build") and CardDB.can_play_spell(_spell("TNL066"), "adventure") and CardDB.can_play_spell(_spell("TNL070"), "build"),
		"Pity : aventure ; Surprise Gift : construction")
	var gaps := 0
	for id in TnlSpells.TARGETS.keys():
		if _card(CardDB.spells, str(id)).is_empty():
			gaps += 1
	_ok.call(gaps == 0 and TnlSpells.TARGETS.size() == 17, "les 17 sorts TNL ont un ciblage")

func _t_new_match_decks() -> void:
	var m = load("res://godot/scripts/Match.gd").new()
	host.add_child(m)
	for n in [2, 3, 4]:
		var G: Dictionary = m.new_match(n, 1, ["next-level"])
		var heroes: Array = G["decks"]["heroes"]
		var epics: Array = G["decks"]["epics"]
		var want_o: int = {2: 13, 3: 17, 4: 25}[n]
		var want_e: int = {2: 9, 3: 13, 4: 17}[n]
		_ok.call(heroes.size() == want_o and epics.size() == want_e, "%dj TNL : %d ordinaires + %d epiques (obtenu %d + %d)" % [n, want_o, want_e, heroes.size(), epics.size()])
		var all_tnl := true
		for h in heroes + epics:
			all_tnl = all_tnl and str((h as Dictionary).get("set", "")) == "next-level"
		_ok.call(all_tnl, "%dj TNL : un seul paquet de heros (celui de TNL, pas le BMA)" % n)
		var ids: Array = _ids(heroes + epics)
		var stars := true
		for sid in ["TNL077", "TNL083", "TNL089", "TNL095", "TNL097", "TNL100", "TNL104", "TNL108", "TNL112", "TNL114"]:
			stars = stars and ids.has(sid)
		_ok.call(stars, "%dj TNL : les heros a etoile (noirs, hybrides, Fool, Brothers) sont toujours inclus" % n)
		_ok.call(bool(TnlAbilities.active(G)) and _count(G["decks"]["rooms"], "TNL") == 75 and _count(G["decks"]["spells"], "TNL") == 31 and _count(G["decks"]["rooms"], "BMA") > 0,
			"%dj TNL : salles et sorts de TNL melanges a ceux du jeu de base" % n)
	var plain: Dictionary = m.new_match(2, 1, ["base"])
	_ok.call(not TnlAbilities.active(plain) and (plain["decks"]["heroes"] as Array).size() == 13 and (plain["decks"]["epics"] as Array).size() == 8, "sans TNL : paquets de base inchanges")
	m.queue_free()

## Livret p.8 : 5 salles + 2 sorts sans defausse (main de 7) ; defausse amorcee par 4 salles + 2 sorts.
func _t_setup_hands() -> void:
	var m = load("res://godot/scripts/Match.gd").new()
	host.add_child(m)
	var G: Dictionary = m.new_match(2, 2, ["next-level"])
	for pid in [0, 1]:
		var pick: Dictionary = (G["bossPicks"] as Array)[0]
		m.apply_move(pid, {"type": "pickBoss", "args": [pick["id"]]})
	var h0: Array = _hand(G, 0)
	var h1: Array = _hand(G, 1)
	_ok.call(h0.size() == 7 and h1.size() == 7 and str(_pending(G).get("type", "")) == "opening-discard", "TNL : 5 salles + 2 sorts, puis defausse de 2 cartes au choix (comme le jeu de base)")
	_ok.call(_decks(G, "roomDiscard").size() == 4 and _decks(G, "spellDiscard").size() == 2, "TNL : defausse amorcee par 4 salles + 2 sorts")
	m.apply_move(0, {"type": "openingDiscard", "args": [0, 1]})
	m.apply_move(1, {"type": "openingDiscard", "args": [0, 1]})
	_ok.call(_hand(G, 0).size() == 5 and _hand(G, 1).size() == 5 and _pending(G).is_empty(), "TNL : 5 cartes gardees apres la defausse d'ouverture")
	m.queue_free()
	var m2 = load("res://godot/scripts/Match.gd").new()
	host.add_child(m2)
	var G2: Dictionary = m2.new_match(2, 2, ["base"])
	for pid in [0, 1]:
		var pick2: Dictionary = (G2["bossPicks"] as Array)[0]
		m2.apply_move(pid, {"type": "pickBoss", "args": [pick2["id"]]})
	_ok.call(_hand(G2, 0).size() == 7 and str(_pending(G2).get("type", "")) == "opening-discard", "base : main de 7 puis defausse de 2 (inchange)")
	_ok.call(_decks(G2, "roomDiscard").is_empty(), "base : defausse non amorcee (inchange)")
	m2.queue_free()

# --- bosses --------------------------------------------------------------------------------------------------------

func _t_mirrax() -> void:
	var p0 := _player(0, "TNL000")
	var G := _G([p0, _player(1, "BMA001")])
	_ok.call(TnlAbilities.level_up(G, 0, p0, p0["boss"]) == null and (p0["bonusTreasures"] as Array) == [1], "TNL000 Mirrax : un seul autre boss -> copie directe de ses icones")
	var tr := BossEngine.dungeon_treasures(p0, G)
	tr.sort()
	_ok.call(tr == [1, 4], "TNL000 : l'icone copiee compte dans le donjon (Thief + Cleric)")
	var m0 := _player(0, "TNL000")
	var kirax := _player(1, "KSA001", [], true)
	var G2 := _G([m0, kirax, _player(2, "BMA001")])
	var c = TnlAbilities.level_up(G2, 0, m0, m0["boss"])
	_ok.call(c != null and str(c["type"]) == "tnl-pick" and (c["options"] as Array).size() == 2, "TNL000 : choix du boss a copier")
	TnlAbilities.resolve_pick(G2, 0, c, 0)
	_ok.call((m0["bonusTreasures"] as Array).size() == 4, "TNL000 : copier Kirax (monte de niveau) donne toutes ses icones (FAQ)")
	kirax["eliminated"] = true # l'icone reste meme si le boss copie meurt
	_ok.call(BossEngine.treasure_count(m0, 1, G2) == 1 and BossEngine.treasure_count(m0, 2, G2) == 1, "TNL000 : l'icone copiee reste apres la mort du boss copie")

## TNL001 Doc Scarecrow : en construction, defausse une carte -> un heros de la ville ne peut pas etre leurre ce tour (une fois par tour).
func _t_scarecrow() -> void:
	var p0 := _player(0, "TNL001", [], true)
	var p1 := _player(1, "BMA001", [_plain("D2", "monster", [2], 1)])
	p1["boss"]["treasures"] = []
	p0["dungeon"] = [[_plain("D1", "monster", [1], 5)]]
	var G := _G([p0, p1])
	G["phase"] = "build"
	G["activePlayer"] = 0
	G["buildOrder"] = [0, 1]
	G["buildIndex"] = 0
	var h1 := _hero("TNL073") # Cleric (1)
	var h2 := _hero("TNL079") # Fighter (2)
	G["town"] = [h1, h2]
	(p0["hand"] as Array).append(_plain("R1"))
	var m := _match(G)
	var moves: Array = m.legal_moves(0).filter(func(mv): return str((mv as Dictionary)["type"]) == "docScarecrow")
	_ok.call(moves.size() == 2, "TNL001 : un coup par heros de la ville (obtenu %d)" % moves.size())
	_ok.call(m.legal_moves(1).filter(func(mv): return str((mv as Dictionary)["type"]) == "docScarecrow").is_empty(), "TNL001 : seul le possesseur du boss monte de niveau")
	_ok.call(m.apply_move(0, {"type": "docScarecrow", "args": [0, 0]}), "TNL001 : Epouvantail applique")
	_ok.call(_hand(G, 0).is_empty() and _decks(G, "roomDiscard").size() == 1, "TNL001 : la carte est defaussee")
	_ok.call(m.legal_moves(0).filter(func(mv): return str((mv as Dictionary)["type"]) == "docScarecrow").is_empty(), "TNL001 : une seule fois par tour")
	m._resolve_bait()
	var town_ids: Array = _ids(G["town"])
	_ok.call(town_ids.has(str(h1["id"])) and not town_ids.has(str(h2["id"])), "TNL001 : le heros marque reste en ville, l'autre est leurre")
	_ok.call((p1["entrance"] as Array).size() == 1 and (p0["entrance"] as Array).is_empty(), "TNL001 : le heros Fighter va chez le seul donjon a tresor Fighter")
	# sans le boss monte de niveau : rien
	var p2 := _player(0, "TNL001", [], false)
	var G2 := _G([p2, _player(1, "BMA001")])
	G2["phase"] = "build"
	G2["activePlayer"] = 0
	(p2["hand"] as Array).append(_plain("R"))
	G2["town"] = [_hero("TNL073")]
	_ok.call(_match(G2).legal_moves(0).filter(func(mv): return str((mv as Dictionary)["type"]) == "docScarecrow").is_empty(), "TNL001 : pas avant le level up")

func _t_belladonna() -> void:
	var p0 := _player(0, "TNL002")
	var G := _G([p0, _player(1, "BMA001")])
	_ok.call(TnlAbilities.level_up(G, 0, p0, p0["boss"]) == null and (p0["souls"] as Array).is_empty(), "TNL002 Belladonna : aucune blessure, capacite perdue")
	var ordinary := _hero("TNL073")
	var epic := _hero("TNL098")
	for _i in 1:
		(p0["wounds"] as Array).append({"name": "a", "wounds": 1, "souls": 1, "faceDown": false, "hero": ordinary})
	for _i in 2:
		(p0["wounds"] as Array).append({"name": "b", "wounds": 1, "souls": 1, "faceDown": false, "hero": epic})
	var c = TnlAbilities.level_up(G, 0, p0, p0["boss"])
	_ok.call(c != null and (c["options"] as Array).size() == 2, "TNL002 : choix du heros a retourner (un epique permis)")
	TnlAbilities.resolve_pick(G, 0, c, 1)
	_ok.call((p0["wounds"] as Array).size() == 1 and (p0["souls"] as Array).size() == 2 and CardDB.total_wounds(p0) == 1, "TNL002 : l'epique devient 2 ames, ses 2 blessures disparaissent")

## TNL003 Torix : toute salle Monster defaussee ou detruite (celles de tous les joueurs) rejoint sa main.
func _t_torix() -> void:
	var p0 := _player(0, "TNL003")
	var p1 := _player(1, "BMA001", [_plain("mon", "monster"), _plain("trap", "trap")])
	var G := _G([p0, p1])
	TnlAbilities.level_up(G, 0, p0, p0["boss"])
	_ok.call(int(G["decks"]["torixPid"]) == 0, "TNL003 : Torix est actif apres le level up")
	var d1 = BossEngine.destroy_room(p1, 0, G)
	BossEngine.discard_room_to_pile(G["decks"], d1)
	_ok.call(_decks(G, "roomDiscard").is_empty() and not _decks(G, "torixQueue").is_empty(), "TNL003 : la salle Monster detruite n'atteint pas la defausse")
	TnlAbilities.flush_torix(G)
	_ok.call(str(_pending(G).get("step", "")) == "torix" and bool(_pending(G)["optional"]) and int(_pending(G)["playerId"]) == 0 and _hand(G, 0).is_empty() and _decks(G, "torixQueue").is_empty(),
		"TNL003 : « you may » -> la salle est proposee a Torix (facultatif), pas prise d'office")
	_match(G)._resolve_choice(0, 0)
	_ok.call(_ids(_hand(G, 0)) == ["mon"] and _pending(G).is_empty(), "TNL003 : elle rejoint la main de Torix")
	var d2 = BossEngine.destroy_room(p1, 0, G)
	BossEngine.discard_room_to_pile(G["decks"], d2)
	TnlAbilities.flush_torix(G)
	_ok.call(_ids(_decks(G, "roomDiscard")) == ["trap"] and _hand(G, 0).size() == 1 and _pending(G).is_empty(), "TNL003 : une salle Trap va normalement a la defausse")
	# defaussee depuis une main (cout d'une capacite)
	var mon2 := _plain("mon2", "monster")
	BossEngine.discard_room_to_pile(G["decks"], mon2)
	TnlAbilities.flush_torix(G)
	_match(G)._resolve_choice(0, 0)
	_ok.call(_ids(_hand(G, 0)).has("mon2"), "TNL003 : une salle Monster defaussee de la main aussi")
	# refus (« may ») : la salle va a la defausse, la main ne change pas
	var mon3 := _plain("mon3", "monster")
	BossEngine.discard_room_to_pile(G["decks"], mon3)
	TnlAbilities.flush_torix(G)
	var before := _hand(G, 0).size()
	_match(G)._resolve_choice(0, -1)
	_ok.call(_hand(G, 0).size() == before and _ids(_decks(G, "roomDiscard")).has("mon3") and _pending(G).is_empty(), "TNL003 : Torix peut refuser (passer) -> defausse normale")
	# Sans Torix rien ne change
	var G2 := _G([_player(0, "BMA001"), _player(1, "BMA002", [_plain("x", "monster")])])
	BossEngine.discard_room_to_pile(G2["decks"], BossEngine.destroy_room(G2["players"][1], 0, G2))
	_ok.call(_decks(G2, "roomDiscard").size() == 1, "sans Torix : defausse normale")

## Port du JS « Jeopardy terminates when Torix recovers his own Monster Room ».
func _t_torix_jeopardy() -> void:
	var p0 := _player(0, "TNL003")
	var p1 := _player(1, "BMA001")
	var G := _G([p0, p1])
	TnlAbilities.level_up(G, 0, p0, p0["boss"])
	(p0["hand"] as Array).append_array([_plain("m1", "monster"), _plain("t1", "trap")])
	(p1["hand"] as Array).append_array([_spl("s1"), _plain("m2", "monster")])
	_fill(G, "rooms", 6)
	_fill(G, "spells", 3, "spell")
	SpellEffects.cast_spell(G, 1, _spell("BMA048"), {})
	TnlAbilities.flush_torix(G)
	_drain(_match(G))
	_ok.call(_hand(G, 1).size() == 3, "Jeopardy + Torix : 1 sort + 2 salles repioches (obtenu %d)" % _hand(G, 1).size())
	_ok.call(_ids(_hand(G, 0)).has("m1") and _ids(_hand(G, 0)).has("m2") and _hand(G, 0).size() == 5, "Jeopardy + Torix : Torix garde ses salles Monster ET prend celle de l'adversaire")

func _t_killa() -> void:
	var p0 := _player(0, "TNL004", [_plain("A", "trap", [1], 1), _plain("B", "trap", [1], 1), _plain("C", "trap", [1], 2)], true)
	var G := _G([p0, _player(1, "BMA001")])
	for _i in 2:
		(p0["wounds"] as Array).append({"wounds": 1})
	_ok.call(BossEngine.room_damage_with_modifiers(G, p0, 2, {}) == 2, "TNL004 Killa : moins de 3 blessures, aucun bonus")
	(p0["wounds"] as Array).append({"wounds": 1})
	_ok.call(BossEngine.room_damage_with_modifiers(G, p0, 2, {}) == 5 and BossEngine.room_damage_with_modifiers(G, p0, 1, {}) == 1, "TNL004 : 3 blessures, la derniere salle +3, les autres inchangees")
	(SpellEffects._effects(G)["deactivatedRooms"] as Array).append({"playerId": 0, "roomIndex": 2})
	_ok.call(BossEngine.room_damage_with_modifiers(G, p0, 1, {}) == 4, "TNL004 (FAQ) : derniere salle gelee, le bonus passe a l'avant-derniere")

func _t_shellda() -> void:
	var p0 := _player(0, "TNL005", [_plain("a", "trap"), _plain("b")], true)
	var p1 := _player(1, "BMA001", [_plain("c", "trap"), _plain("d")])
	var G := _G([p0, p1])
	var m := _match(G)
	G["phase"] = "end"
	_ok.call(TnlAbilities.end_of_turn(G), "TNL005 Shellda : un choix de fin de tour est ouvert")
	var pc := _pending(G)
	_ok.call(str(pc["type"]) == "tnl-pick" and str(pc["step"]) == "swap_dungeon" and bool(pc["optional"]) and (pc["options"] as Array).size() == 2, "TNL005 : choix du donjon (le sien ou celui d'un adversaire), facultatif")
	m._resolve_choice(0, 0)
	_ok.call(str(_pending(G)["step"]) == "swap_pair", "TNL005 : puis la paire de salles")
	m._resolve_choice(0, 0)
	_ok.call(_ids([(p0["dungeon"] as Array)[0][0], (p0["dungeon"] as Array)[1][0]]) == ["b", "a"], "TNL005 : les deux salles sont echangees")
	_ok.call(_pending(G).is_empty(), "TNL005 : plus de choix en attente")
	# on peut passer, et l'IA passe (option -1 : ai < pass)
	G["phase"] = "end"
	TnlAbilities.end_of_turn(G)
	m._resolve_choice(0, -1)
	_ok.call(_ids([(p0["dungeon"] as Array)[0][0], (p0["dungeon"] as Array)[1][0]]) == ["b", "a"] and _pending(G).is_empty(), "TNL005 : facultatif (passer ne change rien)")
	# aucune paire possible
	var G2 := _G([_player(0, "TNL005", [_plain("a")], true), _player(1, "BMA001", [_plain("c")])])
	_ok.call(not TnlAbilities.end_of_turn(G2), "TNL005 : aucun donjon de 2 salles, aucun choix")

## Match._check_end_or_next_turn : le tour suivant attend la resolution du choix de fin de tour ; jamais de choix derriere une victoire.
func _t_end_of_turn_resume() -> void:
	var p0 := _player(0, "TNL005", [_plain("a", "trap"), _plain("b")], true)
	var p1 := _player(1, "BMA001", [_plain("c", "trap")])
	var G := _G([p0, p1])
	G["decks"]["heroes"] = [_hero("TNL073"), _hero("TNL074"), _hero("TNL075"), _hero("TNL076")]
	_fill(G, "rooms", 6)
	var m := _match(G)
	m._check_end_or_next_turn()
	_ok.call(bool(G.get("tnlEndPending", false)) and not _pending(G).is_empty() and int(G["turn"]) == 1, "TNL005 : le passage au tour suivant attend le choix")
	_drain(m, 0)
	_ok.call(int(G["turn"]) == 2 and not G.has("tnlEndPending") and str(G["phase"]) == "build", "TNL005 : tour 2 une fois le choix resolu")
	# victoire : aucun choix Shellda
	var q0 := _player(0, "TNL005", [_plain("a", "trap"), _plain("b")], true)
	for _i in 10:
		(q0["souls"] as Array).append({"souls": 1})
	var G2 := _G([q0, _player(1, "BMA001", [_plain("c")])])
	G2["decks"]["heroes"] = [_hero("TNL073")]
	var m2 := _match(G2)
	m2._check_end_or_next_turn()
	_ok.call(G2["gameOver"] != null and _pending(G2).is_empty() and int(G2["gameOver"]["winner"]) == 0, "TNL005 : 10 ames -> fin de partie sans choix en suspens")

func _t_smoake() -> void:
	var p0 := _player(0, "TNL006", [], true)
	var G := _G([p0, _player(1, "BMA001")])
	_fill(G, "rooms", 3)
	RoomAbilities.on_build_room(G, 0, _plain("m", "monster"))
	_ok.call(_hand(G, 0).size() == 1, "TNL006 Smoake : une salle Monster construite fait piocher une salle")
	RoomAbilities.on_build_room(G, 0, _plain("t", "trap"))
	_ok.call(_hand(G, 0).size() == 1, "TNL006 : pas pour une salle Trap")
	var q := _player(0, "BMA001")
	var G2 := _G([q, _player(1, "BMA002")])
	_fill(G2, "rooms", 2)
	RoomAbilities.on_build_room(G2, 0, _plain("m", "monster"))
	_ok.call(_hand(G2, 0).is_empty(), "sans Smoake : rien")

func _t_kazanna() -> void:
	var p0 := _player(0, "TNL007")
	var G := _G([p0, _player(1, "BMA001")])
	(p0["hand"] as Array).append_array([_plain("r1"), _spl("old"), _plain("r2")])
	_fill(G, "spells", 5, "spell")
	TnlAbilities.level_up(G, 0, p0, p0["boss"])
	_ok.call(_hand(G, 0).size() == 3 and _hand(G, 0).all(func(c): return bool((c as Dictionary).get("isSpell", false))), "TNL007 Kazanna : main defaussee, 3 sorts pioches")
	_ok.call(_decks(G, "roomDiscard").size() == 2 and _ids(_decks(G, "spellDiscard")) == ["old"], "TNL007 : les cartes de la main vont en defausse")

func _t_timebender() -> void:
	var p0 := _player(0, "TNL008", [], true)
	var p1 := _player(1, "BMA001")
	var G := _G([p0, p1])
	G["phase"] = "build"
	G["activePlayer"] = 0
	(p0["hand"] as Array).append_array([_spl("mine1"), _spl("mine2")])
	G["stack"] = [{"id": "e1", "type": "spell", "playerId": 1, "card": _spl("BMA040"), "target": {}, "resolved": false}]
	G["stackReturnPlayer"] = 1
	var m := _match(G)
	var offered: Array = m.legal_moves(0).filter(func(mv): return str((mv as Dictionary)["type"]) == "timebenderCancel")
	_ok.call(offered.size() == 2, "TNL008 Dr. Timebender : un coup par sort defaussable (obtenu %d)" % offered.size())
	_ok.call(m.apply_move(0, {"type": "timebenderCancel", "args": [0]}), "TNL008 : annulation appliquee")
	_ok.call((G["stack"] as Array).is_empty() and _decks(G, "spellDiscard").size() == 2 and _hand(G, 0).size() == 1, "TNL008 : le sort adverse est annule, le sort paye et le sort annule vont en defausse")
	G["stack"] = [{"id": "e2", "type": "spell", "playerId": 1, "card": _spl("x"), "target": {}, "resolved": false}]
	_ok.call(m.legal_moves(0).filter(func(mv): return str((mv as Dictionary)["type"]) == "timebenderCancel").is_empty(), "TNL008 : une seule fois par tour")
	var q0 := _player(0, "BMA001")
	var G2 := _G([q0, _player(1, "BMA002")])
	G2["phase"] = "build"
	G2["activePlayer"] = 0
	(q0["hand"] as Array).append(_spl("s"))
	G2["stack"] = [{"id": "e3", "type": "spell", "playerId": 1, "card": _spl("x"), "target": {}, "resolved": false}]
	_ok.call(_match(G2).legal_moves(0).filter(func(mv): return str((mv as Dictionary)["type"]) == "timebenderCancel").is_empty(), "TNL008 : pas sans le boss")
	var p2 := _player(0, "TNL008", [], true)
	var G3 := _G([p2, _player(1, "BMA002")])
	G3["phase"] = "build"
	G3["activePlayer"] = 0
	(p2["hand"] as Array).append(_spl("s"))
	G3["stack"] = [{"id": "e4", "type": "spell", "playerId": 0, "card": _spl("x"), "target": {}, "resolved": false}]
	_ok.call(_match(G3).legal_moves(0).filter(func(mv): return str((mv as Dictionary)["type"]) == "timebenderCancel").is_empty(), "TNL008 : seulement contre le sort d'un adversaire")

func _t_nicolius() -> void:
	var p0 := _player(0, "TNL009", [], true)
	var p1 := _player(1, "BMA001")
	var G := _G([p0, p1])
	p0["tnlSoulsStart"] = 0
	p1["tnlSoulsStart"] = 0
	(p1["souls"] as Array).append_array([{"souls": 1}, {"souls": 1}])
	_fill(G, "spells", 2, "spell")
	_ok.call(not TnlAbilities.end_of_turn(G) and _hand(G, 0).size() == 1, "TNL009 Nicolius : un adversaire a 2 ames de plus ce tour -> pioche un sort")
	var q0 := _player(0, "TNL009", [], true)
	var q1 := _player(1, "BMA001")
	var G2 := _G([q0, q1])
	q0["tnlSoulsStart"] = 0
	q1["tnlSoulsStart"] = 0
	(q1["souls"] as Array).append({"souls": 1})
	_fill(G2, "spells", 2, "spell")
	TnlAbilities.end_of_turn(G2)
	_ok.call(_hand(G2, 0).is_empty(), "TNL009 : un ecart de 1 ne suffit pas")
	# les ames du debut de tour ne comptent pas
	var r0 := _player(0, "TNL009", [], true)
	var r1 := _player(1, "BMA001")
	var G3 := _G([r0, r1])
	for _i in 4:
		(r1["souls"] as Array).append({"souls": 1})
	TnlAbilities.on_turn_start(G3)
	_fill(G3, "spells", 2, "spell")
	TnlAbilities.end_of_turn(G3)
	_ok.call(_hand(G3, 0).is_empty() and int(r1["tnlSoulsStart"]) == 4, "TNL009 : seules les ames gagnees CE tour comptent")

func _t_porkus() -> void:
	var p0 := _player(0, "TNL010")
	var G := _G([p0, _player(1, "BMA001")])
	_ok.call(TnlAbilities.level_up(G, 0, p0, p0["boss"]) == null, "TNL010 Porkus : sans heros face cachee, capacite perdue")
	var a := _hero("TNL073")
	var b := _hero("TNL098")
	(p0["souls"] as Array).append(CardDB.soul_entry(a))
	for _i in 2:
		(p0["souls"] as Array).append(CardDB.soul_entry(b))
	G["decks"]["heroes"] = [_hero("TNL074"), _hero("TNL075")]
	G["decks"]["epics"] = [_hero("TNL099")]
	var c = TnlAbilities.level_up(G, 0, p0, p0["boss"])
	_ok.call(c != null and (c["options"] as Array).size() == 2, "TNL010 : choix du heros a retirer (l'epique est permis)")
	var next = TnlAbilities.resolve_pick(G, 0, c, 1)
	_ok.call((p0["souls"] as Array).size() == 1 and _decks(G, "removedHeroes").size() == 1, "TNL010 : l'epique quitte le scorekeeping et le jeu")
	_ok.call(next != null and (next["options"] as Array).size() == 3, "TNL010 : recherche dans les pioches de heros (ordinaires et epiques)")
	TnlAbilities.resolve_pick(G, 0, next, 2)
	_ok.call((p0["souls"] as Array).size() == 3 and CardDB.total_souls(p0, G) == 3 and _decks(G, "epics").is_empty(), "TNL010 : l'epique cherche arrive face cachee (2 ames)")

func _t_angstigoth() -> void:
	var p0 := _player(0, "TNL011", [], true)
	var G := _G([p0, _player(1, "BMA001")])
	_fill(G, "rooms", 3)
	TnlAbilities.on_hero_killed(G, 0)
	TnlAbilities.on_hero_killed(G, 0)
	_ok.call(_hand(G, 0).size() == 1, "TNL011 Angstigoth : une seule salle piochee par tour")
	G["effects"] = SpellEffects.empty_effects()
	TnlAbilities.on_hero_killed(G, 0)
	_ok.call(_hand(G, 0).size() == 2, "TNL011 : de nouveau au tour suivant")

## Port du JS « TNL012 Eclipse gives the uncovered Room +3 when you destroy a Room ».
func _t_eclipse() -> void:
	var p0 := _player(0, "TNL012", [], true)
	var under := _plain("under", "monster", [2], 3)
	var top := _plain("top", "trap", [1], 1)
	p0["dungeon"] = [[under, top]]
	var G := _G([p0, _player(1, "BMA001")])
	BossEngine.destroy_room(p0, 0, G)
	_ok.call((p0["dungeon"] as Array).size() == 1 and int(under.get("dealDamage", 0)) == 3, "TNL012 Eclipse : la salle decouverte gagne +3")
	_ok.call(BossEngine.room_damage_with_modifiers(G, p0, 0, {}) == 6, "TNL012 : +3 jusqu'a la fin du tour (3 + 3)")
	var q0 := _player(0, "BMA001")
	var u2 := _plain("u2", "monster", [2], 3)
	q0["dungeon"] = [[u2, _plain("t2")]]
	BossEngine.destroy_room(q0, 0, _G([q0, _player(1, "BMA002")]))
	_ok.call(int(u2.get("dealDamage", 0)) == 0, "TNL012 : sans le boss, aucun bonus")
	# Revue : une destruction resolue par un choix (Megaworm Burrow, Blockpile Puzzle...) compte pour celui qui choisit : Eclipse seulement si c'est le proprietaire
	for chooser in [0, 1]:
		var e0 := _player(0, "TNL012", [], true)
		var eu := _plain("eu", "monster", [2], 3)
		e0["dungeon"] = [[eu, _plain("et", "trap", [1], 1)]]
		var Ge := _G([e0, _player(1, "BMA001")])
		Ge["pendingChoice"] = {"type": "tnl-pick", "step": "room_target", "playerId": chooser, "optional": true, "resume": false, "ctx": {"then": "destroy"},
			"options": [{"targetPlayerId": 0, "roomIndex": 0}]}
		_match(Ge)._resolve_choice(chooser, 0)
		_ok.call((int(eu.get("dealDamage", 0)) == 3) == (chooser == 0), "TNL012 Eclipse : destruction par choix, +3 seulement si le proprietaire choisit (choisit : %d)" % chooser)

# --- salles : construction / decouverte ----------------------------------------------------------------------------

## Ports des JS : Arcane Crypt, Barbarian Hall, Shrooman Cave, Sorcerobe School, Genie Lounge, Spiked Pit.
func _t_build_effects() -> void:
	var G := _G([_player(0, "BMA001"), _player(1, "BMA002")])
	var crypt := _room("TNL016")
	(G["players"][0]["dungeon"] as Array).append([crypt])
	(G["decks"]["spellDiscard"] as Array).append(_spl("old"))
	var c1 = RoomAbilities.on_build_room(G, 0, crypt)
	_ok.call(c1 != null and str(c1["type"]) == "tnl-pick" and bool(c1["optional"]) and (c1["options"] as Array).size() == 1 and _hand(G, 0).is_empty(),
		"TNL016 Arcane Crypt : « you may » -> meme avec un seul sort, choix facultatif (rien n'est pris d'office)")
	G["pendingChoice"] = c1
	_match(G)._resolve_choice(0, 0)
	_ok.call(_ids(_hand(G, 0)) == ["old"] and _decks(G, "spellDiscard").is_empty(), "TNL016 : le sort choisi est recupere")
	(G["decks"]["spellDiscard"] as Array).append_array([_spl("a"), _spl("b")])
	var c = RoomAbilities.on_build_room(G, 0, crypt)
	_ok.call(c != null and str(c["type"]) == "tnl-pick" and (c["options"] as Array).size() == 2 and bool(c["optional"]), "TNL016 : plusieurs sorts -> choix facultatif")
	G["pendingChoice"] = c
	_match(G)._resolve_choice(0, -1)
	_ok.call(_ids(_hand(G, 0)) == ["old"] and _decks(G, "spellDiscard").size() == 2 and _pending(G).is_empty(), "TNL016 : refuser (passer) ne prend rien")
	# Barbarian Hall
	var hall := _room("TNL024")
	var G2 := _G([_player(0, "BMA001", [hall]), _player(1, "BMA002")])
	_hand(G2, 0).append_array([_spl("s1"), _plain("r1")])
	_ok.call(RoomAbilities.on_build_room(G2, 0, hall) == null and _ids(_hand(G2, 0)) == ["r1"] and _decks(G2, "spellDiscard").size() == 1, "TNL024 Barbarian Hall : le seul sort de la main est defausse (FAQ)")
	var G3 := _G([_player(0, "BMA001", [hall]), _player(1, "BMA002")])
	_hand(G3, 0).append_array([_spl("s1"), _spl("s2")])
	var c3 = RoomAbilities.on_build_room(G3, 0, hall)
	_ok.call(c3 != null and (c3["options"] as Array).size() == 2 and _hand(G3, 0).size() == 2, "TNL024 : deux sorts -> choix du sort a defausser")
	var G3b := _G([_player(0, "BMA001", [hall]), _player(1, "BMA002")])
	_hand(G3b, 0).append(_plain("r"))
	_ok.call(RoomAbilities.on_build_room(G3b, 0, hall) == null and _hand(G3b, 0).size() == 1, "TNL024 (FAQ) : sans sort en main, aucune penalite")
	# Shrooman Cave : une AUTRE salle Monster +3
	var cave := _room("TNL027")
	var other := _plain("o", "monster", [3], 4)
	var G4 := _G([_player(0, "BMA001", [cave, other]), _player(1, "BMA002")])
	_ok.call(RoomAbilities.on_build_room(G4, 0, cave) == null and int(other.get("dealDamage", 0)) == 3 and int(cave.get("dealDamage", 0)) == 0, "TNL027 Shrooman Cave : l'autre salle Monster +3 (jamais elle-meme, FAQ)")
	var G4b := _G([_player(0, "BMA001", [cave, _plain("m1", "monster"), _plain("m2", "monster")]), _player(1, "BMA002")])
	var c4 = RoomAbilities.on_build_room(G4b, 0, cave)
	_ok.call(c4 != null and (c4["options"] as Array).size() == 2, "TNL027 : deux autres salles Monster -> choix")
	# la salle d'un adversaire est aussi une cible
	var G4c := _G([_player(0, "BMA001", [cave]), _player(1, "BMA002", [_plain("foe", "monster")])])
	RoomAbilities.on_build_room(G4c, 0, cave)
	_ok.call(int((G4c["players"][1]["dungeon"][0][0] as Dictionary).get("dealDamage", 0)) == 3, "TNL027 : n'importe quel donjon")
	# Sorcerobe / Genie Lounge / Spiked Pit
	var G5 := _G([_player(0, "BMA001"), _player(1, "BMA002")])
	_fill(G5, "spells", 4, "spell")
	RoomAbilities.on_build_room(G5, 0, _room("TNL036"))
	_ok.call(_hand(G5, 0).size() == 1, "TNL036 Sorcerobe School : pioche un sort")
	RoomAbilities.on_build_room(G5, 0, _room("TNL052"))
	_ok.call(_hand(G5, 0).size() == 1, "TNL052 Genie Lounge : pas de sort pioche quand on en a deja un")
	_hand(G5, 0).clear()
	_hand(G5, 0).append(_plain("r"))
	RoomAbilities.on_build_room(G5, 0, _room("TNL052"))
	_ok.call(_hand(G5, 0).size() == 2, "TNL052 : sans sort en main, pioche un sort")
	var pit := _room("TNL044")
	RoomAbilities.on_build_room(G5, 0, pit)
	_ok.call(int(pit.get("dealDamage", 0)) == 3, "TNL044 Spiked Pit : +3 sur elle-meme")

## « build OR uncover » : la salle decouverte par une destruction declenche son effet (build seul : Incubus Gym, Barbarian Hall...).
func _t_uncover_effects() -> void:
	var G := _G([_player(0, "BMA001"), _player(1, "BMA002")])
	_fill(G, "spells", 3, "spell")
	var p0: Dictionary = G["players"][0]
	var pit := _room("TNL044")
	var lib := _room("TNL036")
	var cave := _room("TNL027")
	var tgt := _plain("tgt", "monster", [1], 2)
	p0["dungeon"] = [[pit, _plain("t1")], [lib, _plain("t2")], [cave, _plain("t3")], [tgt]]
	BossEngine.destroy_room(p0, 0, G)
	_ok.call(int(pit.get("dealDamage", 0)) == 3, "TNL044 : decouverte -> +3")
	BossEngine.destroy_room(p0, 1, G)
	_ok.call(_hand(G, 0).size() == 1, "TNL036 : decouverte -> pioche un sort")
	BossEngine.destroy_room(p0, 2, G)
	_ok.call(not _pending(G).is_empty() and (_pending(G)["options"] as Array).size() == 2, "TNL027 : decouverte -> choix d'une AUTRE salle Monster (Sorcerobe School ou la cible)")
	_match(G)._resolve_choice(0, 1)
	_ok.call(int(tgt.get("dealDamage", 0)) == 3 and int(lib.get("dealDamage", 0)) == 0, "TNL027 : la salle choisie gagne +3")
	# Incubus Gym / Barbarian Hall : build seulement, aucun effet a la decouverte
	var G2 := _G([_player(0, "BMA001"), _player(1, "BMA002")])
	(G2["players"][1]["hand"] as Array).append_array([_plain("x"), _plain("y")])
	G2["players"][0]["dungeon"] = [[_room("TNL019"), _plain("over")]]
	BossEngine.destroy_room(G2["players"][0], 0, G2)
	_ok.call(_pending(G2).is_empty() and _hand(G2, 1).size() == 2, "TNL019 : pas d'effet a la decouverte (build seulement)")
	# Arcane Crypt decouverte : recupere un sort
	var G3 := _G([_player(0, "BMA001"), _player(1, "BMA002")])
	G3["decks"]["spellDiscard"] = [_spl("only")]
	G3["players"][0]["dungeon"] = [[_room("TNL016"), _plain("over")]]
	BossEngine.destroy_room(G3["players"][0], 0, G3)
	_ok.call(not _pending(G3).is_empty() and bool(_pending(G3)["optional"]) and _hand(G3, 0).is_empty(), "TNL016 : decouverte -> choix facultatif d'un sort")
	_drain(_match(G3))
	_ok.call(_ids(_hand(G3, 0)) == ["only"], "TNL016 : decouverte -> recupere le sort choisi")
	# la salle decouverte face cachee ou gelee ne declenche rien
	var G4 := _G([_player(0, "BMA001"), _player(1, "BMA002")])
	_fill(G4, "spells", 2, "spell")
	var hid := _room("TNL036")
	hid["faceDown"] = true
	G4["players"][0]["dungeon"] = [[hid, _plain("over")]]
	BossEngine.destroy_room(G4["players"][0], 0, G4)
	_ok.call(_hand(G4, 0).is_empty(), "salle decouverte encore face cachee : aucun effet")

func _t_incubus_gym() -> void:
	var G := _G([_player(0, "BMA001"), _player(1, "BMA002"), _player(2, "BMA003")])
	_hand(G, 1).append(_plain("a"))
	_hand(G, 2).append_array([_plain("b"), _plain("c"), _spl("s")])
	var gym := _room("TNL019")
	var c = RoomAbilities.on_build_room(G, 0, gym)
	_ok.call(_hand(G, 1).is_empty() and _decks(G, "roomDiscard").size() == 1, "TNL019 Incubus Gym : l'adversaire a une seule salle, elle est defaussee d'office")
	_ok.call(c != null and int(c["playerId"]) == 2 and (c["options"] as Array).size() == 2 and (c["options"] as Array).all(func(o): return bool((o["card"] as Dictionary).get("isRoom", false))),
		"TNL019 : l'autre adversaire choisit parmi ses SALLES (pas son sort)")
	var m := _match(G)
	G["pendingChoice"] = c
	m._resolve_choice(2, 1)
	_ok.call(_ids(_hand(G, 2)) == ["b", "s"] and _decks(G, "roomDiscard").size() == 2, "TNL019 : la salle choisie est defaussee")
	# Imp Temple : la carte va dans la main de l'acteur
	var G2 := _G([_player(0, "BMA001", [_room("TNL014")]), _player(1, "BMA002")])
	_hand(G2, 1).append(_plain("steal"))
	RoomAbilities.on_build_room(G2, 0, gym)
	_ok.call(_ids(_hand(G2, 0)) == ["steal"] and _decks(G2, "roomDiscard").is_empty(), "TNL014 Imp Temple : la salle defaussee de force est prise en main")

func _t_megaworm() -> void:
	var worm := _room("TNL029")
	var victim := _plain("adv", "trap", [3], 4, true)
	var G := _G([_player(0, "BMA001", [worm]), _player(1, "BMA002", [victim])])
	_ok.call(RoomAbilities.on_build_room(G, 0, worm) == null and (G["players"][1]["dungeon"] as Array).is_empty() and _decks(G, "roomDiscard").size() == 1,
		"TNL029 Megaworm Burrow : la seule salle avancee (hors elle-meme) est detruite")
	var G2 := _G([_player(0, "BMA001", [worm]), _player(1, "BMA002", [_plain("advA", "trap", [3], 4, true), _plain("advB", "trap", [3], 4, true), _plain("ord")])])
	var c = RoomAbilities.on_build_room(G2, 0, worm)
	_ok.call(c != null and (c["options"] as Array).size() == 2 and (G2["players"][1]["dungeon"] as Array).size() == 3, "TNL029 : deux salles avancees -> choix, les ordinaires sont exclues")
	var G3 := _G([_player(0, "BMA001", [worm]), _player(1, "BMA002", [_plain("ord")])])
	_ok.call(RoomAbilities.on_build_room(G3, 0, worm) == null and (G3["players"][1]["dungeon"] as Array).size() == 1, "TNL029 : aucune cible, rien")

# --- salles : capacites activees ---------------------------------------------------------------------------------------

func _t_dark_portal() -> void:
	var portal := _room("TNL013")
	var G := _G([_player(0, "BMA001", [portal]), _player(1, "BMA002")])
	G["phase"] = "build"
	_hand(G, 0).append_array([_spl("s1"), _plain("r1")])
	_decks(G, "roomDiscard").append(_plain("rec"))
	_ok.call(_act(G, 0, 0) == null, "TNL013 Dark Portal : activee")
	_ok.call(_ids(_hand(G, 0)) == ["r1", "rec"] and _ids(_decks(G, "spellDiscard")) == ["s1"] and _decks(G, "roomDiscard").is_empty() and bool(portal["usedThisTurn"]),
		"TNL013 : un sort defausse -> une salle de la defausse en main, une fois par tour")
	_ok.call(_act(G, 0, 0) != null, "TNL013 : une seule fois par tour")
	var G2 := _G([_player(0, "BMA001", [_room("TNL013")]), _player(1, "BMA002")])
	G2["phase"] = "build"
	_hand(G2, 0).append(_plain("r1"))
	_decks(G2, "roomDiscard").append(_plain("rec"))
	_ok.call(_act(G2, 0, 0) == "no Spell to discard", "TNL013 : refus sans sort en main")
	# deux sorts : le cout est un choix
	var G3 := _G([_player(0, "BMA001", [_room("TNL013")]), _player(1, "BMA002")])
	G3["phase"] = "build"
	_hand(G3, 0).append_array([_spl("s1"), _spl("s2")])
	_decks(G3, "roomDiscard").append_array([_plain("a"), _plain("b")])
	_ok.call(_act(G3, 0, 0) == null and not _pending(G3).is_empty() and (_pending(G3)["options"] as Array).size() == 2, "TNL013 : deux sorts -> choix du cout")
	var m := _match(G3)
	m._resolve_choice(0, 1)
	_ok.call(str(_pending(G3)["step"]) == "take_discard" and (_pending(G3)["options"] as Array).size() == 2, "TNL013 : puis le choix de la salle a recuperer")
	m._resolve_choice(0, 0)
	_ok.call(_ids(_hand(G3, 0)) == ["s1", "a"], "TNL013 : la salle choisie rejoint la main (le sort 2 a ete defausse)")

func _t_observatory_treadmill() -> void:
	var G := _G([_player(0, "BMA001", [_room("TNL035"), _room("TNL042")]), _player(1, "BMA002")])
	G["phase"] = "build"
	_hand(G, 0).append(_spl("old"))
	_fill(G, "spells", 2, "spell")
	_ok.call(_act(G, 0, 0) == null and _ids(_hand(G, 0)) == ["spells1"] and _ids(_decks(G, "spellDiscard")) == ["old"], "TNL035 Observatory : un sort defausse -> un sort pioche")
	_ok.call(_act(G, 0, 0) != null, "TNL035 : une fois par tour")
	_hand(G, 0).clear()
	_hand(G, 0).append(_plain("hr"))
	_fill(G, "rooms", 2)
	_ok.call(_act(G, 0, 1) == null and _ids(_hand(G, 0)) == ["rooms1"] and _ids(_decks(G, "roomDiscard")) == ["hr"], "TNL042 Deadly Treadmill : une salle defaussee -> une salle piochee")
	_hand(G, 0).clear()
	(G["players"][0]["dungeon"][1][0] as Dictionary)["usedThisTurn"] = false
	_hand(G, 0).append(_spl("s"))
	_ok.call(_act(G, 0, 1) == "no Room to discard", "TNL042 : il faut une carte SALLE a defausser")

func _t_lost_library() -> void:
	var G := _G([_player(0, "BMA001", [_room("TNL032")]), _player(1, "BMA002")])
	G["phase"] = "build"
	_fill(G, "spells", 2, "spell")
	_ok.call(_act(G, 0, 0) == null and (G["players"][0]["dungeon"] as Array).is_empty() and _hand(G, 0).size() == 2, "TNL032 Lost Library : se detruit, pioche 2 sorts")
	var pc := _pending(G)
	_ok.call(str(pc["step"]) == "discard_one" and (pc["options"] as Array).size() == 2 and not bool(pc["resume"]), "TNL032 : puis defausse d'un sort (choix, sans reprise de phase)")
	_match(G)._resolve_choice(0, 0)
	_ok.call(_hand(G, 0).size() == 1 and _decks(G, "spellDiscard").size() == 1, "TNL032 : un sort defausse")

func _t_save_point() -> void:
	var G := _G([_player(0, "BMA001", [_room("TNL055")]), _player(1, "BMA002")])
	G["phase"] = "adventure"
	var played := _spl("played")
	_decks(G, "spellDiscard").append_array([_spl("old"), played])
	_ok.call(_act(G, 0, 0) != null, "TNL055 Save Point : aucun sort joue ce tour -> refus")
	TnlAbilities.on_spell_resolving(G, 0, played)
	_ok.call(_act(G, 0, 0) == null and _ids(_hand(G, 0)) == ["played"] and (G["players"][0]["dungeon"] as Array).is_empty(), "TNL055 : se detruit, reprend le sort joue ce tour (FAQ : pas un ancien)")
	_ok.call(_ids(_decks(G, "spellDiscard")) == ["old"], "TNL055 : l'ancien sort reste en defausse")

func _t_wreck_chomper_smashinator() -> void:
	var G := _G([_player(0, "BMA001", [_room("TNL041"), _plain("victim", "monster", [2], 3)]), _player(1, "BMA002", [_plain("foe")])])
	G["phase"] = "build"
	_fill(G, "rooms", 2)
	_ok.call(_act(G, 0, 0) == null and (G["players"][0]["dungeon"] as Array).size() == 1 and _ids(_decks(G, "roomDiscard")) == ["victim"] and _hand(G, 0).size() == 1, "TNL041 Wreck Room : detruit une AUTRE salle de son donjon -> pioche une salle")
	var G1 := _G([_player(0, "BMA001", [_room("TNL041")]), _player(1, "BMA002", [_plain("foe")])])
	G1["phase"] = "build"
	_ok.call(_act(G1, 0, 0) == "no other Room to destroy", "TNL041 : jamais un donjon adverse, jamais elle-meme")
	var chomper := _room("TNL046")
	var G2 := _G([_player(0, "BMA001", [chomper, _plain("snack")]), _player(1, "BMA002")])
	G2["phase"] = "build"
	_ok.call(_act(G2, 0, 0) == null and (G2["players"][0]["dungeon"] as Array).size() == 1 and int(chomper.get("dealDamage", 0)) == 4, "TNL046 Chump Chomper : +4 jusqu'a la fin du tour")
	var smash := _room("TNL048")
	var G3 := _G([_player(0, "BMA001", [smash, _plain("a"), _plain("b"), _plain("c")]), _player(1, "BMA002")])
	G3["phase"] = "build"
	(G3["players"][0]["dungeon"] as Array)[2].append(_plain("under")) # la pile sous « b » est decouverte, pas detruite (FAQ)
	_ok.call(_act(G3, 0, 0) == null, "TNL048 The Smashinator : activee")
	var d: Array = G3["players"][0]["dungeon"]
	_ok.call(int(smash.get("dealDamage", 0)) == 6 and d.size() == 2, "TNL048 : +6, toutes les AUTRES salles visibles detruites (obtenu %d piles)" % d.size())
	_ok.call(_ids([BossEngine.active_room(d[1])]) == ["b"] or _ids([BossEngine.active_room(d[0])]).size() == 1, "TNL048 : une pile ne perd que sa salle du dessus")
	var G4 := _G([_player(0, "BMA001", [_room("TNL048")]), _player(1, "BMA002")])
	G4["phase"] = "build"
	_ok.call(_act(G4, 0, 0) == "no other visible Room", "TNL048 : refus sans autre salle")

func _t_decapitator_frostbat() -> void:
	var G := _G([_player(0, "BMA001", [_room("TNL045")]), _player(1, "BMA002", [_plain("target", "trap", [3])])])
	G["phase"] = "adventure"
	_ok.call(_act(G, 0, 0) == "Build phase only", "TNL045 Decapitator : phase de construction seulement")
	G["phase"] = "build"
	_ok.call(_act(G, 0, 0) == null and (G["players"][0]["dungeon"] as Array).is_empty(), "TNL045 : se detruit")
	var target: Dictionary = G["players"][1]["dungeon"][0][0]
	_ok.call(BossEngine.room_treasures(target).is_empty() and BossEngine.treasure_count(G["players"][1], 3, G) == 0, "TNL045 : la salle perd son tresor (jusqu'a la fin du tour)")
	# FAQ : un tresor donne APRES (Secret Stash) reste
	SpellEffects.cast_spell(G, 1, _spell("TNL067"), {"roomIndex": 0, "treasure": 2})
	_ok.call(BossEngine.room_treasures(target) == [2], "TNL045 (FAQ) : Secret Stash ajoute ensuite un tresor, il reste")
	# fin de tour
	target.erase("tnl")
	_ok.call(BossEngine.room_treasures(target) == [3, 2] or BossEngine.room_treasures(target).has(3), "TNL045 : le tresor revient au tour suivant")
	var frost := _room("TNL033")
	var G2 := _G([_player(0, "BMA001", [frost]), _player(1, "BMA002", [_plain("t", "monster", [3], 4)])])
	G2["phase"] = "adventure"
	_ok.call(_act(G2, 0, 0) == null and (G2["players"][0]["dungeon"] as Array).is_empty(), "TNL033 Frostbat Cave : se detruit")
	_ok.call((G2["effects"]["deactivatedRooms"] as Array) == [{"playerId": 1, "roomIndex": 0}] and BossEngine.room_damage_with_modifiers(G2, G2["players"][1], 0, {}) == 0, "TNL033 : desactive une salle d'un donjon (aucun degat)")
	var G3 := _G([_player(0, "BMA001", [_room("TNL033")]), _player(1, "BMA002")])
	G3["phase"] = "adventure"
	_ok.call(_act(G3, 0, 0) == "no Room to deactivate", "TNL033 : aucune autre salle -> refus")

func _t_rust_bullet() -> void:
	var pen := _room("TNL022")
	var trap := _plain("trap", "trap", [1], 3)
	var G := _G([_player(0, "BMA001", [pen, trap]), _player(1, "BMA002")])
	G["phase"] = "build"
	_hand(G, 0).append(_plain("mon", "monster"))
	_ok.call(_act(G, 0, 0) == null and _hand(G, 0).is_empty() and _decks(G, "roomDiscard").size() == 1, "TNL022 Rust Monster Pen : defausse une salle Monster")
	_ok.call(BossEngine.room_damage_with_modifiers(G, G["players"][0], 1, {}) == 2, "TNL022 : une salle Trap -1 (3 -> 2)")
	var G0 := _G([_player(0, "BMA001", [_plain("t0", "trap", [1], 0), _room("TNL022")]), _player(1, "BMA002")])
	G0["phase"] = "build"
	_hand(G0, 0).append(_plain("mon", "monster"))
	_act(G0, 0, 1)
	_ok.call(BossEngine.room_damage_with_modifiers(G0, G0["players"][0], 0, {}) == 0, "TNL022 (FAQ) : jamais sous zero")
	var G2 := _G([_player(0, "BMA001", [_room("TNL022")]), _player(1, "BMA002")])
	G2["phase"] = "build"
	_hand(G2, 0).append(_plain("trapcard", "trap"))
	_ok.call(_act(G2, 0, 0) != null, "TNL022 : une salle Trap en main ne paie pas (il faut un Monster)")
	var bullet := _room("TNL040")
	var mon := _plain("mon", "monster", [2], 4)
	var G3 := _G([_player(0, "BMA001", [bullet, mon]), _player(1, "BMA002")])
	G3["phase"] = "build"
	_hand(G3, 0).append(_plain("tr", "trap"))
	_ok.call(_act(G3, 0, 0) == null and BossEngine.room_damage_with_modifiers(G3, G3["players"][0], 1, {}) == 3, "TNL040 Bullet Builder : defausse une salle Trap -> une salle Monster -1")
	_ok.call(_act(G3, 0, 0) != null, "TNL040 : une fois par tour")

func _t_arena() -> void:
	var arena := _room("TNL030")
	var G := _G([_player(0, "BMA001", [arena]), _player(1, "BMA002")])
	G["phase"] = "build"
	_hand(G, 0).append(_plain("mon", "monster", [2], 7))
	_ok.call(_act(G, 0, 0) == null and int(arena.get("dealDamage", 0)) == 7 and _ids(_hand(G, 0)) == ["mon"], "TNL030 The Arena : la salle revelee reste en main (FAQ), +X = sa puissance")
	var G2 := _G([_player(0, "BMA001", [_room("TNL030")]), _player(1, "BMA002")])
	G2["phase"] = "build"
	_hand(G2, 0).append(_plain("tr", "trap"))
	_ok.call(_act(G2, 0, 0) != null, "TNL030 : il faut une salle Monster")

func _t_werewolf_den() -> void:
	var den := _room("TNL053")
	var G := _G([_player(0, "BMA001", [den]), _player(1, "BMA002")])
	G["phase"] = "build"
	_hand(G, 0).append(_plain("card"))
	var hero := _hero("TNL079")
	G["town"] = [hero]
	_ok.call(_act(G, 0, 0) == null and _hand(G, 0).is_empty(), "TNL053 Werewolf Den : defausse une carte")
	_ok.call(TnlAbilities.on_hero_start(G, 1, hero) == 1, "TNL053 : le heros choisi gagne +1 PV jusqu'a la fin du tour (a son entree)")
	# heros deja actif : immediat
	var G2 := _G([_player(0, "BMA001", [_room("TNL053")]), _player(1, "BMA002")])
	G2["phase"] = "adventure"
	var h2 := _hero("TNL073")
	G2["players"][0]["entrance"] = [h2]
	G2["adventure"] = {"playerId": 0, "hero": h2, "roomIndex": 0, "hp": 3, "pause": "post-damage"}
	_hand(G2, 0).append(_plain("card"))
	_act(G2, 0, 0)
	_ok.call(int(G2["adventure"]["hp"]) == 4, "TNL053 : sur le heros actif, +1 PV tout de suite")

func _t_haunted_hall_warp_tube() -> void:
	var hall := _room("TNL017")
	var hero := _hero("TNL073")
	var G := _G([_player(0, "BMA001", [hall, _plain("next")]), _player(1, "BMA002")])
	G["phase"] = "adventure"
	G["players"][0]["entrance"] = [hero]
	G["adventure"] = {"playerId": 0, "hero": hero, "roomIndex": 1, "hp": 3, "pause": "post-damage"}
	_ok.call(_act(G, 0, 0) == "no hero in this room", "TNL017 Haunted Hall : refus si le heros est dans une autre salle")
	G["adventure"]["roomIndex"] = 0
	_ok.call(_act(G, 0, 0) == null, "TNL017 : activee")
	_ok.call((G["adventure"] as Dictionary).is_empty() and _ids(G["town"]) == ["TNL073"] and (G["players"][0]["entrance"] as Array).is_empty() and (G["players"][0]["dungeon"] as Array).size() == 1,
		"TNL017 : se detruit, le heros retourne en ville (sans ame ni blessure)")
	var tube := _room("TNL049")
	var G2 := _G([_player(0, "BMA001", [_plain("first"), tube, _plain("last")]), _player(1, "BMA002")])
	G2["phase"] = "adventure"
	G2["players"][0]["entrance"] = [hero]
	G2["adventure"] = {"playerId": 0, "hero": hero, "roomIndex": 0, "hp": 5, "pause": "post-damage"}
	_ok.call(_act(G2, 0, 1) == "no hero in this room", "TNL049 Warp Tube : le heros doit etre dans CETTE salle")
	G2["adventure"]["roomIndex"] = 1
	_ok.call(_act(G2, 0, 1) == null and int(G2["adventure"]["roomIndex"]) == -1 and (G2["players"][0]["dungeon"] as Array).size() == 2 and int(G2["adventure"]["hp"]) == 5,
		"TNL049 : se detruit, le heros repart de la premiere salle en gardant ses PV")
	var G3 := _G([_player(0, "BMA001", [_room("TNL049")]), _player(1, "BMA002")])
	G3["phase"] = "adventure"
	G3["adventure"] = {"playerId": 0, "hero": hero, "roomIndex": 0, "hp": 0, "pause": "post-damage"}
	_ok.call(_act(G3, 0, 0) != null, "TNL049 : un heros deja a 0 PV ne peut etre sauve par la tube")

func _t_antimagic_zone() -> void:
	var p0 := _player(0, "BMA001")
	var p1 := _player(1, "BMA002")
	var G := _G([p0, p1])
	G["phase"] = "build"
	G["activePlayer"] = 0
	_hand(G, 0).append(_room("TNL031"))
	G["stack"] = [{"id": "e1", "type": "spell", "playerId": 1, "card": _spl("BMA040"), "target": {}, "resolved": false}]
	G["stackReturnPlayer"] = 1
	var m := _match(G)
	var cancels: Array = m.legal_moves(0).filter(func(mv): return str((mv as Dictionary)["type"]) == "antimagicCancel")
	_ok.call(cancels.size() == 1, "TNL031 Antimagic Zone : proposee contre un sort adverse")
	_ok.call(m.apply_move(0, {"type": "antimagicCancel", "args": [0]}), "TNL031 : appliquee")
	_ok.call((G["stack"] as Array).is_empty() and _ids(_decks(G, "spellDiscard")) == ["BMA040"] and _ids(_decks(G, "roomDiscard")) == ["TNL031"] and _hand(G, 0).is_empty(),
		"TNL031 : le sort n'est pas lance (defausse), la salle est defaussee de la main")
	var G2 := _G([_player(0, "BMA001"), _player(1, "BMA002")])
	G2["phase"] = "build"
	G2["activePlayer"] = 0
	_hand(G2, 0).append(_room("TNL031"))
	G2["stack"] = [{"id": "e1", "type": "spell", "playerId": 0, "card": _spl("x"), "target": {}, "resolved": false}]
	_ok.call(_match(G2).legal_moves(0).filter(func(mv): return str((mv as Dictionary)["type"]) == "antimagicCancel").is_empty(), "TNL031 : pas contre son propre sort")
	_ok.call(_match(G2).legal_moves(0).filter(func(mv): return str((mv as Dictionary)["type"]) == "activateRoom").is_empty(), "TNL031 : pas une capacite du donjon")

# --- salles : declencheurs de mort / sortie -------------------------------------------------------------------------------

func _t_hero_dies_triggers() -> void:
	var G := _G([_player(0, "BMA001"), _player(1, "BMA002")])
	G["decks"]["spellDiscard"] = [_spl("played")]
	var c = RoomAbilities.on_hero_died_in_room(G, 0, _room("TNL015"))
	_ok.call(c == null and _ids(_hand(G, 0)) == ["played"], "TNL015 Madman's Manor : recupere un sort de la defausse")
	var G2 := _G([_player(0, "BMA001"), _player(1, "BMA002")])
	_fill(G2, "rooms", 4)
	RoomAbilities.on_hero_died_in_room(G2, 0, _room("TNL025"))
	_ok.call(_hand(G2, 0).size() == 2, "TNL025 Spawn Point : pioche deux salles")
	var G3 := _G([_player(0, "BMA001"), _player(1, "BMA002")])
	_fill(G3, "spells", 4, "spell")
	_hand(G3, 0).append(_spl("keep"))
	var c3 = RoomAbilities.on_hero_died_in_room(G3, 0, _room("TNL039"))
	_ok.call(_hand(G3, 0).size() == 3 and c3 != null and (c3["options"] as Array).size() == 3, "TNL039 Brainsucker Queen : 2 sorts pioches, puis defausse d'un sort (tous les sorts de la main, FAQ)")
	# Wraith's Throne : chaque adversaire defausse un SORT
	var G4 := _G([_player(0, "BMA001"), _player(1, "BMA002"), _player(2, "BMA003")])
	_hand(G4, 1).append_array([_spl("a"), _plain("r")])
	_hand(G4, 2).append_array([_spl("b"), _spl("c")])
	var c4 = RoomAbilities.on_hero_died_in_room(G4, 0, _room("TNL021"))
	_ok.call(_hand(G4, 1).size() == 1 and _ids(_hand(G4, 1)) == ["r"], "TNL021 Wraith's Throne : un adversaire a un seul sort, il le defausse")
	_ok.call(c4 != null and int(c4["playerId"]) == 2 and (c4["options"] as Array).size() == 2, "TNL021 : l'autre choisit son sort")
	# Fangroot Garden : construire une autre salle tout de suite (au-dessus d'une salle existante)
	var G5 := _G([_player(0, "BMA001", [_plain("base", "trap", [1])]), _player(1, "BMA002")])
	_hand(G5, 0).append_array([_plain("n1", "monster"), _plain("n2", "trap")])
	var c5 = RoomAbilities.on_hero_died_in_room(G5, 0, _room("TNL026"))
	_ok.call(c5 != null and bool(c5["optional"]) and (c5["options"] as Array).size() == 2, "TNL026 Fangroot Garden : « you may » (choix facultatif d'une salle de la main)")
	var m5 := _match(G5)
	G5["pendingChoice"] = c5
	m5._resolve_choice(0, 0)
	_ok.call(str(_pending(G5).get("step", "")) == "build_slot" and (_pending(G5)["options"] as Array).size() == 2, "TNL026 : un nouvel emplacement OU par-dessus la salle existante (« build another Room in your dungeon »)")
	m5._resolve_choice(0, 1)
	_ok.call(_pending(G5).is_empty(), "TNL026 : par-dessus la salle existante")
	var stack5: Array = G5["players"][0]["dungeon"][0]
	_ok.call(stack5.size() == 2 and str((stack5[1] as Dictionary)["id"]) == "n1" and not bool((stack5[1] as Dictionary).get("faceDown", false)) and _ids(_hand(G5, 0)) == ["n2"],
		"TNL026 : la salle est construite immediatement, face visible")

func _t_once_per_turn_death_triggers() -> void:
	var G := _G([_player(0, "BMA001"), _player(1, "BMA002")])
	_fill(G, "rooms", 6)
	var spawn := _room("TNL025")
	RoomAbilities.on_hero_died_in_room(G, 0, spawn)
	RoomAbilities.on_hero_died_in_room(G, 0, spawn)
	_ok.call(_hand(G, 0).size() == 2, "TNL025 : une fois par tour")
	var meddled := _room("TNL025")
	TnlAbilities._tag(meddled)["noText"] = true
	RoomAbilities.on_hero_died_in_room(G, 0, meddled)
	_ok.call(_hand(G, 0).size() == 2, "TNL062 : une salle sans texte ne declenche rien")

func _t_bom_boy_and_bridge() -> void:
	var bom := _room("TNL050")
	var G := _G([_player(0, "BMA001", [bom, _plain("next")]), _player(1, "BMA002")])
	RoomAbilities.on_hero_died_in_room(G, 0, bom)
	_ok.call((G["players"][0]["dungeon"] as Array).size() == 1 and _ids(_decks(G, "roomDiscard")) == ["TNL050"], "TNL050 Bom-Boy Factory : se detruit quand un heros y meurt")
	# survie de la salle : le heros la quitte en vie
	var bom2 := _room("TNL050")
	var hero := _hero("TNL073")
	var G2 := _G([_player(0, "BMA001", [bom2, _plain("next")]), _player(1, "BMA002")])
	G2["players"][0]["entrance"] = [hero]
	G2["adventure"] = {"playerId": 0, "hero": hero, "roomIndex": 1, "hp": 4, "pause": null}
	var i := TnlAbilities.on_room_exit(G2, 0, 0, 1)
	_ok.call((G2["players"][0]["dungeon"] as Array).size() == 1 and i == 0 and int(G2["adventure"]["roomIndex"]) == 0, "TNL050 : se detruit quand un heros y survit ; l'index du heros suit le decalage")
	# Collapsing Bridge : une fois par tour, +3 jusqu'a la fin du tour
	var bridge := _room("TNL043")
	var G3 := _G([_player(0, "BMA001", [bridge, _plain("next")]), _player(1, "BMA002")])
	G3["adventure"] = {"playerId": 0, "hero": hero, "roomIndex": 1, "hp": 4, "pause": null}
	TnlAbilities.on_room_exit(G3, 0, 0, 1)
	_ok.call(int(bridge.get("dealDamage", 0)) == 3 and BossEngine.room_damage_with_modifiers(G3, G3["players"][0], 0, {}) == 4, "TNL043 Collapsing Bridge : le heros survit -> +3")
	TnlAbilities.on_room_exit(G3, 0, 0, 1)
	_ok.call(int(bridge.get("dealDamage", 0)) == 3, "TNL043 (FAQ revisee) : une fois par tour")
	# via Match : le heros quitte la salle en vie pendant la progression reelle
	var bridge2 := _room("TNL043")
	var p0 := _player(0, "BMA001", [bridge2, _plain("last")])
	var G4 := _G([p0, _player(1, "BMA002")])
	G4["decks"]["heroDiscard"] = []
	p0["entrance"] = [hero]
	G4["adventure"] = {"playerId": 0, "hero": hero, "roomIndex": 0, "hp": 9, "pause": null, "nearest": 0}
	var m4 := _match(G4)
	m4._advance_adventure_room()
	_ok.call(int(bridge2.get("dealDamage", 0)) == 3 and int(G4["adventure"]["roomIndex"]) == 1, "TNL043 : declenche par la vraie progression du heros (Match._advance_adventure_room)")

# --- salles : bonus passifs ---------------------------------------------------------------------------------------------------

func _t_passive_damage() -> void:
	# Goblin Nursery : la salle a sa GAUCHE (index - 1), si Monster, +2
	var nursery := _room("TNL023")
	var p := _player(0, "BMA001", [_plain("m", "monster", [1], 2), nursery, _plain("t", "trap", [1], 2)])
	var G := _G([p, _player(1, "BMA002")])
	_ok.call(BossEngine.room_damage_with_modifiers(G, p, 0, {}) == 4, "TNL023 Goblin Nursery : la salle Monster a sa gauche +2")
	_ok.call(BossEngine.room_damage_with_modifiers(G, p, 2, {}) == 2 and BossEngine.room_damage_with_modifiers(G, p, 1, {}) == int(nursery["damage"]), "TNL023 : ni la salle Trap a sa droite, ni elle-meme")
	(SpellEffects._effects(G)["deactivatedRooms"] as Array).append({"playerId": 0, "roomIndex": 1})
	_ok.call(BossEngine.room_damage_with_modifiers(G, p, 0, {}) == 2, "TNL023 : desactivee, plus de bonus")
	# Goblin Mess Hall : toutes les AUTRES salles Monster +1
	var p2 := _player(0, "BMA001", [_room("TNL028"), _plain("m", "monster", [1], 2), _plain("t", "trap", [1], 2)])
	var G2 := _G([p2, _player(1, "BMA002")])
	_ok.call(BossEngine.room_damage_with_modifiers(G2, p2, 1, {}) == 3 and BossEngine.room_damage_with_modifiers(G2, p2, 2, {}) == 2 and BossEngine.room_damage_with_modifiers(G2, p2, 0, {}) == 3,
		"TNL028 Goblin Mess Hall : les autres salles Monster +1 (pas les Trap, pas elle-meme)")
	# Elemental Generator : +X, X = sorts en main (FAQ : y compris celui qu'on va lancer)
	var p3 := _player(0, "BMA001", [_room("TNL038")])
	var G3 := _G([p3, _player(1, "BMA002")])
	_ok.call(BossEngine.room_damage_with_modifiers(G3, p3, 0, {}) == 3, "TNL038 Elemental Generator : sans sort, degats imprimes")
	(p3["hand"] as Array).append_array([_spl("a"), _spl("b"), _plain("r")])
	_ok.call(BossEngine.room_damage_with_modifiers(G3, p3, 0, {}) == 5, "TNL038 : +1 par sort en main")
	# Trap Master (KSA017) coupe les bonus de texte des salles
	G3["adventure"] = {"playerId": 0, "hero": _card(CardDB.heroes, "KSA017"), "roomIndex": 0, "hp": 13, "pause": null}
	_ok.call(BossEngine.room_damage_with_modifiers(G3, p3, 0, {}) == 3, "Trap Master : le bonus de l'Elemental Generator est verrouille")

func _t_spellslime_hall_of_mirrors() -> void:
	var slime := _room("TNL034")
	var mirror := _room("TNL037")
	var G := _G([_player(0, "BMA001", [slime]), _player(1, "BMA002", [mirror])])
	_fill(G, "spells", 3, "spell")
	TnlAbilities.on_spell_resolving(G, 0, _spl("a"))
	TnlAbilities.on_spell_resolving(G, 0, _spl("b"))
	_ok.call(int(slime.get("dealDamage", 0)) == 2 and BossEngine.room_damage_with_modifiers(G, G["players"][0], 0, {}) == int(slime["damage"]) + 2, "TNL034 Spellslime Pit : +1 par sort que VOUS jouez")
	_ok.call(_hand(G, 1).size() == 1, "TNL037 Hall of Mirrors : une fois par tour, un sort adverse -> pioche un sort")
	TnlAbilities.on_spell_resolving(G, 1, _spl("c"))
	_ok.call(int(slime.get("dealDamage", 0)) == 2 and _hand(G, 1).size() == 1, "TNL034 / TNL037 : le sort de l'adversaire ne gonfle pas Spellslime, et on ne pioche pas sur son propre sort")

func _t_imp_temple_dragon_graveyard() -> void:
	var imp := _room("TNL014")
	var G := _G([_player(0, "BMA001", [imp]), _player(1, "BMA002")])
	var c := _plain("stolen")
	_hand(G, 1).append(c)
	_ok.call(TnlAbilities.imp_take(G, 0, c) and _ids(_hand(G, 0)) == ["stolen"], "TNL014 Imp Temple : la carte defaussee de force passe dans la main")
	_ok.call(not TnlAbilities.imp_take(G, 0, _plain("second")), "TNL014 : une fois par tour")
	_hand(G, 0).clear()
	G["players"][0]["dungeon"] = [[_plain("noimp")]]
	_ok.call(not TnlAbilities.imp_take(G, 0, _plain("x")), "TNL014 : il faut la salle")
	# via une defausse forcee reelle (Torture Chamber -> imp via RoomAbilities)
	var G2 := _G([_player(0, "BMA001", [_room("TNL014"), _room("BMA038")]), _player(1, "BMA002")])
	_hand(G2, 1).append(_plain("loot"))
	G2["phase"] = "build"
	RoomAbilities._torture_chamber(G2, 0, 1)
	_ok.call(_ids(_hand(G2, 0)) == ["loot"] and _decks(G2, "roomDiscard").size() == 1, "TNL014 : Torture Chamber force la defausse, Imp Temple prend la salle (la chambre est detruite)")
	var dragon := _room("TNL020")
	var G3 := _G([_player(0, "BMA001", [dragon]), _player(1, "BMA002")])
	_fill(G3, "rooms", 3)
	_decks(G3, "spellDiscard").append(_spl("x"))
	RoomAbilities.take_discard_card(G3, G3["players"][0], {"card": _spl("x"), "pile": "spell", "pileIndex": 0})
	_ok.call(_hand(G3, 0).size() == 2, "TNL020 Dragon Graveyard : prendre une carte dans la defausse -> pioche une salle")
	_decks(G3, "spellDiscard").append(_spl("y"))
	RoomAbilities.take_discard_card(G3, G3["players"][0], {"card": _spl("y"), "pile": "spell", "pileIndex": 0})
	_ok.call(_hand(G3, 0).size() == 3, "TNL020 : une seule pioche par tour")

func _t_cursed_tomb() -> void:
	var G := _G([_player(0, "BMA001", [_room("TNL054"), _plain("x")]), _player(1, "BMA002"), _player(2, "BMA003")])
	_hand(G, 1).append_array([_plain("a"), _plain("b"), _plain("c")])
	_hand(G, 2).append(_plain("d"))
	BossEngine.destroy_room(G["players"][0], 0, G)
	_ok.call(_hand(G, 2).is_empty() and _hand(G, 1).size() == 3, "TNL054 Cursed Tomb : un adversaire n'a qu'une salle, elle part ; l'autre doit choisir")
	var pc := _pending(G)
	_ok.call(not pc.is_empty() and int(pc["playerId"]) == 1 and int(pc["ctx"]["remaining"]) == 2, "TNL054 : le choix revient a l'adversaire (deux salles a defausser)")
	var m := _match(G)
	m._resolve_choice(1, 0)
	_ok.call(str(_pending(G).get("step", "")) == "forced" and (_pending(G)["options"] as Array).size() == 2, "TNL054 : puis la seconde carte")
	m._resolve_choice(1, 0)
	_ok.call(_hand(G, 1).size() == 1 and _decks(G, "roomDiscard").size() == 3, "TNL054 : deux salles defaussees au total par l'adversaire")

func _t_inner_sanctum_blockpile() -> void:
	var sanct := _room("TNL018")
	var G := _G([_player(0, "BMA001", [sanct]), _player(1, "BMA002")])
	_fill(G, "rooms", 4)
	TnlAbilities.end_of_turn(G)
	_ok.call(_hand(G, 0).size() == 1, "TNL018 Inner Sanctum : aucun heros n'y est entre -> pioche une salle")
	TnlAbilities.on_room_enter(G, 0, 0, sanct)
	TnlAbilities.end_of_turn(G)
	_ok.call(_hand(G, 0).size() == 1, "TNL018 : un heros y est entre, rien")
	var G2 := _G([_player(0, "BMA001", [_room("TNL047"), _plain("a", "trap", [1], 1), _plain("b", "trap", [1], 3)]), _player(1, "BMA002")])
	_ok.call(TnlAbilities.end_of_turn(G2), "TNL047 Blockpile Puzzle : choix de la salle a detruire en fin de tour")
	var pc := _pending(G2)
	_ok.call(not bool(pc["optional"]) and (pc["options"] as Array).size() == 3, "TNL047 : obligatoire, n'importe laquelle de ses salles (elle-meme comprise, FAQ)")
	var G3 := _G([_player(0, "BMA001", [_room("TNL047")]), _player(1, "BMA002")])
	TnlAbilities.end_of_turn(G3)
	_ok.call((G3["players"][0]["dungeon"] as Array).is_empty() and _pending(G3).is_empty(), "TNL047 : seule salle -> detruite d'office")

func _t_hatchlings_hoard() -> void:
	var hoard := _room("TNL051")
	var p := _player(0, "BMA001", [_plain("a", "trap", [3])])
	(p["hand"] as Array).append(hoard)
	_ok.call(BossEngine.can_build_room(p, {}, 0, 0, 0), "TNL051 Hatchling's Hoard : se pose sur une salle a tresor Mage")
	var q := _player(0, "BMA001", [_plain("a", "trap", [5])])
	(q["hand"] as Array).append(_room("TNL051"))
	_ok.call(not BossEngine.can_build_room(q, {}, 0, 0, 0), "TNL051 : mais pas sur un tresor hors Cleric/Fighter/Mage/Thief")
	var G := _G([_player(0, "BMA001", [hoard]), _player(1, "BMA002")])
	var counts: Array = []
	for t in [1, 2, 3, 4]:
		counts.append(BossEngine.treasure_count(G["players"][0], t, G) - BossEngine.treasure_count(_player(0, "BMA001"), t, G))
	_ok.call(counts == [1, 1, 1, 1], "TNL051 : un tresor de chaque type")

# --- sorts --------------------------------------------------------------------------------------------------------------------------
func _t_spell_phases() -> void:
	for id in ["TNL056", "TNL058", "TNL060", "TNL067", "TNL070"]:
		_ok.call(CardDB.can_play_spell(_spell(id), "build") and not CardDB.can_play_spell(_spell(id), "adventure"), "%s : sort de construction (marteau)" % id)
	for id in ["TNL057", "TNL059", "TNL061", "TNL064", "TNL065", "TNL066", "TNL068", "TNL069", "TNL071", "TNL072"]:
		_ok.call(CardDB.can_play_spell(_spell(id), "adventure") and not CardDB.can_play_spell(_spell(id), "build"), "%s : sort d'aventure (hache)" % id)

func _t_all_your_base() -> void:
	var G := _G([_player(0, "BMA001"), _player(1, "BMA002")])
	_hand(G, 1).append_array([_plain("steal"), _spl("theirs"), _plain("other")])
	_ok.call(SpellEffects.cast_spell(G, 0, _spell("TNL056"), {"targetPlayerId": 1}), "TNL056 All Your Base : lance")
	var pc := _pending(G)
	_ok.call(bool(pc["optional"]) and (pc["options"] as Array).size() == 2, "TNL056 : « you may take one Room card » : seules les salles sont proposees, facultatif")
	_match(G)._resolve_choice(0, 0)
	_ok.call(_ids(_hand(G, 0)) == ["steal"] and _ids(_hand(G, 1)) == ["theirs", "other"], "TNL056 : la salle choisie passe dans la main (port du JS)")

func _t_another_castle() -> void:
	var hero := _hero("TNL073")
	var p0 := _player(0, "BMA001", [_plain("r")])
	var G := _G([p0, _player(1, "BMA002")])
	p0["entrance"] = [hero, _hero("TNL074")]
	SpellEffects.cast_spell(G, 0, _spell("TNL057"), {"targetPlayerId": 1})
	_ok.call(_ids(p0["entrance"]) == ["TNL073", "TNL074"] and (G["players"][1]["entrance"] as Array).is_empty(), "TNL057 Another Castle : un heros A L'ENTREE n'est pas dans le donjon (FAQ) -> rien")
	G["adventure"] = {"playerId": 0, "hero": hero, "roomIndex": 0, "hp": 3, "pause": "post-damage"}
	_ok.call(SpellTargeting.spell_targets_for(G, p0, 0, "TNL057") == [{"targetPlayerId": 1}], "TNL057 : cible = un adversaire (heros dans son donjon)")
	SpellEffects.cast_spell(G, 0, _spell("TNL057"), {"targetPlayerId": 1})
	_ok.call(_ids(G["players"][1]["entrance"]) == ["TNL073"] and _ids(p0["entrance"]) == ["TNL074"] and (G["adventure"] as Dictionary).is_empty(), "TNL057 : le heros part a l'entree de l'adversaire")

func _t_fairy_fountain() -> void:
	var hero := _hero("TNL073")
	var room := _plain("target", "monster", [1], 5)
	var p0 := _player(0, "BMA001", [room])
	var G := _G([p0, _player(1, "BMA002")])
	G["adventure"] = {"playerId": 0, "hero": hero, "roomIndex": -1, "hp": 4, "pause": null}
	_ok.call(SpellEffects.cast_spell(G, 1, _spell("TNL058"), {"targetPlayerId": 0, "roomIndex": 0}), "TNL058 Fairy Fountain : lance")
	_ok.call(BossEngine.room_damage_with_modifiers(G, p0, 0, hero) == 0, "TNL058 : la salle inflige zero degat")
	(room as Dictionary)["dealDamage"] = 4
	_ok.call(BossEngine.room_damage_with_modifiers(G, p0, 0, hero) == 0, "TNL058 (FAQ) : une fois a zero, rien ne la releve")
	TnlAbilities.on_room_enter(G, 0, 0, room)
	_ok.call(int(G["adventure"]["hp"]) == 5, "TNL058 : le heros qui entre gagne +1 PV")
	# couverte / detruite : l'effet cesse
	var top := _plain("top", "monster", [1], 2)
	p0["dungeon"][0].append(top)
	_ok.call(BossEngine.room_damage_with_modifiers(G, p0, 0, hero) == 2, "TNL058 (FAQ) : couverte, l'effet cesse")

func _t_its_on() -> void:
	var hero := _hero("TNL084") # 8 PV
	var p0 := _player(0, "BMA001", [_plain("r")])
	var G := _G([p0, _player(1, "BMA002")])
	p0["entrance"] = [hero]
	G["adventure"] = {"playerId": 0, "hero": hero, "roomIndex": 0, "hp": 5, "pause": "post-damage"}
	_ok.call(SpellTargeting.spell_targets_for(G, p0, 0, "TNL059").is_empty(), "TNL059 It's On! : ni 3 PV ou moins, ni 3 blessures -> injouable")
	G["adventure"]["hp"] = 3
	_ok.call(SpellTargeting.spell_targets_for(G, p0, 0, "TNL059") == [{"heroId": hero["id"]}], "TNL059 : 3 PV ou moins -> ciblable (PV courants, FAQ)")
	_ok.call(SpellEffects.cast_spell(G, 0, _spell("TNL059"), {"heroId": hero["id"]}) and int(G["adventure"]["hp"]) == 0, "TNL059 : le heros est tue")
	G["adventure"]["hp"] = 7
	for _i in 3:
		(p0["wounds"] as Array).append({"wounds": 1})
	_ok.call(SpellTargeting.spell_targets_for(G, p0, 0, "TNL059").size() == 1, "TNL059 : OU 3 blessures ou plus -> n'importe quel heros de votre donjon")

func _t_hiring_spree() -> void:
	var G := _G([_player(0, "BMA001"), _player(1, "BMA002")])
	_fill(G, "rooms", 3)
	SpellEffects.cast_spell(G, 0, _spell("TNL060"), {"targetPlayerId": 1})
	_ok.call(_hand(G, 0).size() == 3 and (_pending(G)["options"] as Array).size() == 3, "TNL060 Hiring Spree : 3 salles piochees, puis on en donne une")
	_match(G)._resolve_choice(0, 1)
	_ok.call(_hand(G, 0).size() == 2 and _hand(G, 1).size() == 1, "TNL060 : une salle de la main passe a l'autre joueur")
	_ok.call(SpellTargeting.spell_targets_for(G, G["players"][0], 0, "TNL060") == [{"targetPlayerId": 1}], "TNL060 : cible = un autre joueur")

func _t_lightning_bolt() -> void:
	var hero := _hero("TNL084")
	var waiting := _hero("TNL073")
	var p0 := _player(0, "BMA001", [_plain("r")])
	var G := _G([p0, _player(1, "BMA002")])
	p0["entrance"] = [hero, waiting]
	G["adventure"] = {"playerId": 0, "hero": hero, "roomIndex": 0, "hp": 8, "pause": "post-damage"}
	_hand(G, 0).append_array([_spl("other")])
	SpellEffects.cast_spell(G, 0, _spell("TNL061"), {"heroId": hero["id"]})
	_ok.call(int(G["adventure"]["hp"]) == 5, "TNL061 Lightning Bolt! : 3 degats au heros de votre donjon")
	var pc := _pending(G)
	_ok.call(bool(pc["optional"]) and (pc["options"] as Array).size() == 1, "TNL061 : defausser un autre sort (facultatif)")
	_match(G)._resolve_choice(0, 0)
	_ok.call(_ids(_decks(G, "spellDiscard")) == ["other"] and TnlAbilities.on_hero_start(G, 0, waiting) == -3, "TNL061 : 3 degats a chaque heros a l'entree (retenus jusqu'a son entree)")
	var G2 := _G([_player(0, "BMA001", [_plain("r")]), _player(1, "BMA002")])
	G2["players"][0]["entrance"] = [hero]
	G2["adventure"] = {"playerId": 0, "hero": hero, "roomIndex": 0, "hp": 8, "pause": "post-damage"}
	SpellEffects.cast_spell(G2, 0, _spell("TNL061"), {"heroId": hero["id"]})
	_ok.call(_pending(G2).is_empty(), "TNL061 : pas de heros a l'entree, pas de choix")

func _t_meddling_kids() -> void:
	var G := _G([_player(0, "BMA001", [_room("TNL035")]), _player(1, "BMA002", [_room("BMA009")])])
	G["phase"] = "build"
	SpellEffects.cast_spell(G, 0, _spell("TNL062"), {"targetPlayerId": 0, "roomIndex": 0})
	_ok.call(_act(G, 0, 0) == "no ability text (Meddling Kids!)", "TNL062 Meddling Kids! : la salle n'a plus de texte (capacite refusee)")
	SpellEffects.cast_spell(G, 0, _spell("TNL062"), {"targetPlayerId": 1, "roomIndex": 0})
	_decks(G, "roomDiscard").append(_plain("x"))
	_ok.call(_act(G, 1, 0) == "no ability text (Meddling Kids!)", "TNL062 : vaut aussi pour une salle du jeu de base (Dark Altar)")
	var G2 := _G([_player(0, "BMA001"), _player(1, "BMA002")])
	_ok.call(SpellTargeting.spell_targets_for(G2, G2["players"][0], 0, "TNL062").is_empty(), "TNL062 : « 3 heros ou plus sont entres » : mode joueur seulement s'il est vrai")
	TnlAbilities._bump(G2, "entered", 1, 3)
	var t: Array = SpellTargeting.spell_targets_for(G2, G2["players"][0], 0, "TNL062")
	_ok.call(t == [{"targetPlayerId": 1, "mode": "nowin"}], "TNL062 : le joueur chez qui 3 heros sont entres est ciblable")
	SpellEffects.cast_spell(G2, 0, _spell("TNL062"), {"targetPlayerId": 1, "mode": "nowin"})
	_ok.call(TnlAbilities.cannot_win(G2, 1), "TNL062 : ce joueur ne peut pas gagner ce tour")
	# 10 ames mais interdit de victoire : la partie continue (FAQ : il garde ses ames)
	var q1 := _player(1, "BMA002", [_plain("c")])
	for _i in 10:
		(q1["souls"] as Array).append({"souls": 1})
	var G3 := _G([_player(0, "BMA001", [_plain("a")]), q1])
	G3["decks"]["heroes"] = [_hero("TNL073"), _hero("TNL074"), _hero("TNL075"), _hero("TNL076")]
	_fill(G3, "rooms", 5)
	TnlAbilities._list(G3, "noWin").append(1)
	var m3 := _match(G3)
	m3._check_end_or_next_turn()
	_ok.call(G3.get("gameOver") == null and (q1["souls"] as Array).size() == 10, "TNL062 : 10 ames mais « cannot win this turn » -> pas de victoire, les ames restent")
	if G3.get("gameOver") == null: # le tour suivant demarre (le heros restant de la pioche arrive en ville)
		m3._check_end_or_next_turn()
	_ok.call(G3.get("gameOver") != null and int(G3["gameOver"]["winner"]) == 1, "TNL062 : il gagne au tour suivant (aucune interdiction ne se reporte)")

## TNL062 sur les passifs / declencheurs du jeu de base (« Room ability text does not include the name, damage, treasure or subtype »).
func _t_meddling_kids_base_passives() -> void:
	var hero := _hero("TNL073")
	var cast := func(G: Dictionary, idx: int) -> void:
		SpellEffects.cast_spell(G, 0, _spell("TNL062"), {"targetPlayerId": 0, "roomIndex": idx})
	# BMA015 Goblin Armory : +1 aux Monster voisines ; sans texte, plus rien (ses propres degats imprimes restent)
	var G := _G([_player(0, "BMA001", [_room("BMA015"), _plain("m", "monster", [1], 2)]), _player(1, "BMA002")])
	var p0: Dictionary = G["players"][0]
	_ok.call(BossEngine.room_damage_with_modifiers(G, p0, 1, hero) == 3, "TNL062 (base) : Goblin Armory donne +1 a la Monster voisine")
	cast.call(G, 0)
	_ok.call(BossEngine.room_damage_with_modifiers(G, p0, 1, hero) == 2, "TNL062 : Goblin Armory sans texte ne donne plus +1")
	_ok.call(BossEngine.room_damage_with_modifiers(G, p0, 0, hero) == int(_room("BMA015")["damage"]), "TNL062 : ses degats imprimes restent")
	# BMA029 Dizzygas Hallway : +2 a la Trap suivante
	var G2 := _G([_player(0, "BMA001", [_room("BMA029"), _plain("t", "trap", [1], 1)]), _player(1, "BMA002")])
	_ok.call(BossEngine.room_damage_with_modifiers(G2, G2["players"][0], 1, hero) == 3, "BMA029 Dizzygas Hallway : +2 a la Trap suivante")
	cast.call(G2, 0)
	_ok.call(BossEngine.room_damage_with_modifiers(G2, G2["players"][0], 1, hero) == 1, "TNL062 : Dizzygas Hallway sans texte ne donne plus +2")
	# BMA020 Monster's Ballroom : degats = nombre de Monster ; sans texte = degats imprimes
	var G3 := _G([_player(0, "BMA001", [_room("BMA020"), _plain("m1"), _plain("m2")]), _player(1, "BMA002")])
	_ok.call(BossEngine.room_damage_with_modifiers(G3, G3["players"][0], 0, hero) == 3, "BMA020 Ballroom : 3 salles Monster = 3 degats")
	cast.call(G3, 0)
	_ok.call(BossEngine.room_damage_with_modifiers(G3, G3["players"][0], 0, hero) == int(_room("BMA020")["damage"]), "TNL062 : Ballroom sans texte = degats imprimes")
	# BMA018 Neanderthal Cave : n'interdit plus les salles avancees
	var G4 := _G([_player(0, "BMA001", [_room("BMA018")]), _player(1, "BMA002")])
	var adv := _plain("adv", "monster", [int((_room("BMA018")["treasures"] as Array)[0])], 3, true)
	(G4["players"][0]["hand"] as Array).append(adv)
	G4["phase"] = "build"
	_ok.call(not BossEngine.can_build_room(G4["players"][0], G4, 0, 0, 0), "BMA018 Neanderthal Cave : pas de salle avancee par-dessus")
	cast.call(G4, 0)
	_ok.call(BossEngine.can_build_room(G4["players"][0], G4, 0, 0, 0), "TNL062 : sans texte, on peut batir une salle avancee par-dessus")
	# BMA023 Haunted Library, BMA031 Recycling Center, BMA016 Golem Factory (declencheur de mort)
	var G5 := _G([_player(0, "BMA001", [_room("BMA023"), _room("BMA031")]), _player(1, "BMA002")])
	_ok.call(RoomAbilities.can_choose_draw(G5["players"][0]), "BMA023 Haunted Library : pioche au choix")
	cast.call(G5, 0)
	_ok.call(not RoomAbilities.can_choose_draw(G5["players"][0]), "TNL062 : Haunted Library sans texte, plus de choix de pioche")
	_fill(G5, "rooms", 4)
	cast.call(G5, 1)
	BossEngine._on_other_room_destroyed(G5, G5["players"][0], _room("BMA018"))
	_ok.call(_hand(G5, 0).is_empty(), "TNL062 : Recycling Center sans texte ne pioche plus")
	var G6 := _G([_player(0, "BMA001"), _player(1, "BMA002")])
	_fill(G6, "rooms", 4)
	var golem := _room("BMA016")
	TnlAbilities._tag(golem)["noText"] = true
	RoomAbilities.on_hero_died_in_room(G6, 0, golem)
	_ok.call(_hand(G6, 0).is_empty() and not bool(golem.get("usedThisTurn", false)), "TNL062 : Golem Factory sans texte ne declenche rien")
	# BMA025 All-Seeing Eye : plus d'annulation possible
	var G7 := _G([_player(0, "BMA001", [_room("BMA025")]), _player(1, "BMA002")])
	cast.call(G7, 0)
	_ok.call(_act(G7, 0, 0) == "no ability text (Meddling Kids!)", "TNL062 : All-Seeing Eye sans texte, capacite refusee")

func _t_oh_yeah() -> void:
	var G := _G([_player(0, "BMA001", [_plain("a"), _plain("b"), _plain("c")]), _player(1, "BMA002", [_plain("x")])])
	var p0: Dictionary = G["players"][0]
	var t: Array = SpellTargeting.spell_targets_for(G, p0, 0, "TNL063")
	_ok.call(t.size() == 3 and (t as Array).all(func(e): return str((e as Dictionary)["mode"]) == "swap"), "TNL063 Oh, Yeah! : 3 echanges possibles, pas de mode destruction (aucune salle detruite)")
	(p0["dungeon"] as Array)[0].append(_plain("under"))
	_ok.call(SpellEffects.cast_spell(G, 0, _spell("TNL063"), {"mode": "swap", "a": 0, "b": 1}), "TNL063 : echange")
	var ids: Array = []
	for st in p0["dungeon"]:
		ids.append(str(BossEngine.active_room(st)["id"]))
	_ok.call(ids == ["b", "under", "c"] and (p0["dungeon"] as Array)[1].size() == 2, "TNL063 : les piles se deplacent ensemble (FAQ)")
	BossEngine.destroy_room(p0, 0, G)
	BossEngine.destroy_room(p0, 0, G)
	var t2: Array = SpellTargeting.spell_targets_for(G, p0, 0, "TNL063")
	_ok.call(t2.any(func(e): return str((e as Dictionary)["mode"]) == "destroy"), "TNL063 : 2 salles detruites ce tour -> detruire une salle de n'importe quel donjon")
	_ok.call(SpellEffects.cast_spell(G, 0, _spell("TNL063"), {"mode": "destroy", "targetPlayerId": 1, "roomIndex": 0}) and (G["players"][1]["dungeon"] as Array).is_empty(), "TNL063 : la salle adverse est detruite")

func _t_party_up_pause() -> void:
	var G := _G([_player(0, "BMA001", [_plain("a")]), _player(1, "BMA002")])
	SpellEffects.cast_spell(G, 0, _spell("TNL064"), {"targetPlayerId": 1})
	var h := _hero("TNL073")
	_ok.call(TnlAbilities.on_hero_start(G, 1, h) == 1 and TnlAbilities.on_hero_start(G, 0, h) == 0, "TNL064 Party Up : chaque heros qui entre dans ce donjon gagne +1 (pas dans l'autre)")
	SpellEffects.cast_spell(G, 0, _spell("TNL064"), {"targetPlayerId": 1})
	_ok.call(TnlAbilities.on_hero_start(G, 1, h) == 2, "TNL064 : deux sorts se cumulent")
	var p0 := _player(0, "BMA001", [_plain("a")])
	var G2 := _G([p0, _player(1, "BMA002")])
	p0["entrance"] = [h, _hero("TNL074")]
	G2["adventure"] = {"playerId": 0, "hero": h, "roomIndex": 0, "hp": 2, "pause": "post-damage"}
	SpellEffects.cast_spell(G2, 0, _spell("TNL065"), {})
	_ok.call((G2["adventure"] as Dictionary).is_empty() and (p0["entrance"] as Array).size() == 2 and (G2["effects"]["skipAdventure"] as Array) == [0],
		"TNL065 Pause : le heros revient a l'entree (pleine sante a sa prochaine entree), aucun heros n'entre ce tour")
	var m := _match(G2)
	_ok.call(not m._has_entrance_hero(0), "TNL065 : Match ne fait plus entrer de heros chez ce joueur ce tour")
	# la sante est rendue : a la prochaine entree le heros repart de ses PV imprimes
	G2["effects"] = SpellEffects.empty_effects()
	_ok.call(m._has_entrance_hero(0) and BossEngine.hero_hp(h) == int(h["hp"]), "TNL065 : au tour suivant ils peuvent entrer, avec leurs PV imprimes")

func _t_pity_undead() -> void:
	var hero := _hero("TNL084")
	var p1 := _player(1, "BMA002", [_plain("r")])
	var G := _G([_player(0, "BMA001"), p1])
	p1["entrance"] = [hero]
	G["adventure"] = {"playerId": 1, "hero": hero, "roomIndex": 0, "hp": 5, "pause": "post-damage"}
	var tg: Array = SpellTargeting.spell_targets_for(G, G["players"][0], 0, "TNL066")
	_ok.call(tg == [{"heroId": hero["id"], "targetPlayerId": 1}], "TNL066 Pity : cible = le heros du donjon d'un adversaire")
	SpellEffects.cast_spell(G, 0, _spell("TNL066"), tg[0])
	_ok.call((G["adventure"] as Dictionary).is_empty() and (p1["entrance"] as Array).is_empty() and _decks(G, "removedHeroes").size() == 1 and _decks(G, "heroDiscard").is_empty(),
		"TNL066 : retire du jeu (ni defausse, ni ame, ni blessure)")
	_ok.call(SpellTargeting.spell_targets_for(G, G["players"][1], 1, "TNL066").is_empty(), "TNL066 : pas dans son propre donjon")
	# Undead Minion
	var victim := _hero("TNL073")
	var big := _hero("TNL098")
	var p0 := _player(0, "BMA001", [_plain("r")])
	var G2 := _G([p0, _player(1, "BMA002")])
	(p0["souls"] as Array).append(CardDB.soul_entry(victim))
	for _i in 2:
		(p0["souls"] as Array).append(CardDB.soul_entry(big))
	var foe := _hero("TNL084")
	p0["entrance"] = [foe]
	G2["adventure"] = {"playerId": 0, "hero": foe, "roomIndex": 0, "hp": 8, "pause": "post-damage"}
	var tg2: Array = SpellTargeting.spell_targets_for(G2, p0, 0, "TNL071")
	_ok.call(tg2.size() == 2, "TNL071 Undead Minion : un coup par heros face cachee (l'epique compte une fois)")
	SpellEffects.cast_spell(G2, 0, _spell("TNL071"), {"soulIndex": 1})
	_ok.call(int(G2["adventure"]["hp"]) == 8 - 11 and (p0["souls"] as Array).size() == 1 and _decks(G2, "removedHeroes").size() == 1, "TNL071 : degats = Sante du heros retire (11), retire du jeu avec toutes ses ames")

func _t_secret_stash_super_effective() -> void:
	var room := _plain("r", "trap", [1], 2)
	var p0 := _player(0, "BMA001", [room])
	var G := _G([p0, _player(1, "BMA002")])
	_ok.call(SpellTargeting.spell_targets_for(G, p0, 0, "TNL067").size() == 4, "TNL067 Secret Stash : un coup par type de tresor")
	SpellEffects.cast_spell(G, 0, _spell("TNL067"), {"roomIndex": 0, "treasure": 3})
	_ok.call(BossEngine.room_treasures(room) == [1, 3] and BossEngine.treasure_count(p0, 3, G) == 1, "TNL067 : un tresor Mage de plus")
	var adv_card := _plain("adv", "trap", [3], 4, true)
	p0["hand"] = [adv_card]
	_ok.call(BossEngine.can_build_room(p0, {}, 0, 0, 0), "TNL067 (FAQ) : permet de poser une salle avancee a ce tresor par-dessus")
	room.erase("extraTreasures")
	_ok.call(BossEngine.room_treasures(room) == [1], "TNL067 : l'effet cesse a la fin du tour")
	# Super Effective!
	var G2 := _G([_player(0, "BMA001", [_plain("r", "trap", [1], 2)]), _player(1, "BMA002")])
	TnlAbilities.on_lured(G2, 0)
	SpellEffects.cast_spell(G2, 0, _spell("TNL069"), {"roomIndex": 0})
	_ok.call(BossEngine.room_damage_with_modifiers(G2, G2["players"][0], 0, {}) == 6, "TNL069 Super Effective! : un seul heros leurre -> +4")
	var G3 := _G([_player(0, "BMA001", [_plain("r", "trap", [1], 2)]), _player(1, "BMA002")])
	TnlAbilities.on_lured(G3, 0)
	TnlAbilities.on_lured(G3, 0)
	SpellEffects.cast_spell(G3, 0, _spell("TNL069"), {"roomIndex": 0})
	_ok.call(BossEngine.room_damage_with_modifiers(G3, G3["players"][0], 0, {}) == 4, "TNL069 : deux heros leurres -> seulement +2")
	var G4 := _G([_player(0, "BMA001", [_plain("r", "trap", [1], 2)]), _player(1, "BMA002")])
	SpellEffects.cast_spell(G4, 0, _spell("TNL069"), {"roomIndex": 0})
	_ok.call(BossEngine.room_damage_with_modifiers(G4, G4["players"][0], 0, {}) == 4, "TNL069 : aucun heros leurre (Princess in Peril...) -> +2")

func _t_shortcut() -> void:
	var hero := _hero("TNL073")
	var rooms: Array = []
	for i in 5:
		rooms.append(_plain("r%d" % i, "monster", [1], 1))
	var p1 := _player(1, "BMA002", rooms)
	var G := _G([_player(0, "BMA001"), p1])
	p1["entrance"] = [hero]
	G["adventure"] = {"playerId": 1, "hero": hero, "roomIndex": 0, "hp": 9, "pause": null, "nearest": 0}
	SpellEffects.cast_spell(G, 0, _spell("TNL068"), {"heroId": hero["id"], "targetPlayerId": 1})
	_ok.call(int(G["adventure"]["skip"]) == 2, "TNL068 Shortcut! : un donjon de cinq salles -> deux salles sautees")
	var m := _match(G)
	m._advance_adventure_room()
	_ok.call(int(G["adventure"]["roomIndex"]) == 3, "TNL068 : le heros saute les deux salles suivantes (index 1 et 2)")
	var small := _player(1, "BMA002", [_plain("a"), _plain("b"), _plain("c")])
	var G2 := _G([_player(0, "BMA001"), small])
	small["entrance"] = [hero]
	G2["adventure"] = {"playerId": 1, "hero": hero, "roomIndex": 0, "hp": 9, "pause": null, "nearest": 0}
	SpellEffects.cast_spell(G2, 0, _spell("TNL068"), {"heroId": hero["id"], "targetPlayerId": 1})
	_ok.call(int(G2["adventure"]["skip"]) == 1, "TNL068 : sinon une seule salle")
	_match(G2)._advance_adventure_room()
	_ok.call(int(G2["adventure"]["roomIndex"]) == 2, "TNL068 : saute la salle d'index 1")

func _t_surprise_gift() -> void:
	var p0 := _player(0, "BMA001")
	var victim := _plain("target", "trap", [1], 1)
	var p1 := _player(1, "BMA002", [victim])
	var G := _G([p0, p1])
	G["phase"] = "build"
	G["activePlayer"] = 0
	G["buildOrder"] = [0, 1]
	G["buildIndex"] = 0
	(p0["hand"] as Array).append_array([_plain("gift", "monster", [3], 5), _plain("gift2", "trap", [2], 1), _plain("adv", "trap", [4], 3, true)])
	var m := _match(G)
	_ok.call(SpellTargeting.spell_targets_for(G, p0, 0, "TNL070") == [{}], "TNL070 Surprise Gift : jouable pendant SA construction")
	_ok.call(SpellEffects.cast_spell(G, 0, _spell("TNL070"), {}), "TNL070 : lance")
	var pc := _pending(G)
	# une seule salle adverse visible : emplacement choisi d'office ; la salle avancee sans tresor commun est exclue
	_ok.call(str(pc["step"]) == "sp_gift_card" and (pc["options"] as Array).size() == 2, "TNL070 : choix de la carte (la salle avancee sans tresor commun est exclue)")
	m._resolve_choice(0, 0)
	var stack: Array = p1["dungeon"][0]
	_ok.call(_pending(G).is_empty() and stack.size() == 2 and bool((stack[1] as Dictionary).get("faceDown", false)) and str((stack[1] as Dictionary)["id"]) == "gift",
		"TNL070 : la salle est posee face cachee par-dessus la salle adverse")
	_ok.call(int(p0["buildsThisTurn"]) == 1 and _hand(G, 0).size() == 2, "TNL070 : elle remplace sa propre construction")
	_ok.call(SpellTargeting.spell_targets_for(G, p0, 0, "TNL070").is_empty(), "TNL070 : plus jouable apres avoir construit")
	_ok.call(G.get("tnlGiftBuilt") == null, "TNL070 : le tour de construction du donneur est cloture (Match avance)")
	# les effets « when you build » s'appliquent a l'adversaire : revelation de fin de phase
	var gift2 := _room("TNL036")
	var q1 := _player(1, "BMA002", [_plain("t", "trap")])
	var G2 := _G([_player(0, "BMA001"), q1])
	_fill(G2, "spells", 2, "spell")
	(q1["dungeon"][0] as Array).append(gift2)
	gift2["faceDown"] = true
	var m2 := _match(G2)
	m2._reveal_and_level_up()
	_ok.call(_hand(G2, 1).size() == 1 and _hand(G2, 0).is_empty() and not bool(gift2.get("faceDown", false)), "TNL070 : « build effects apply to the opponent » : l'adversaire pioche (Sorcerobe School), pas le donneur")

func _t_wild_monster() -> void:
	var p0 := _player(0, "BMA001", [_plain("base", "trap", [1], 1)])
	var G := _G([p0, _player(1, "BMA002")])
	(p0["hand"] as Array).append_array([_plain("mon", "monster", [2], 4), _plain("trapcard", "trap")])
	_ok.call(SpellTargeting.spell_targets_for(G, p0, 0, "TNL072") == [{}], "TNL072 Wild Monster : jouable avec une salle Monster en main")
	SpellEffects.cast_spell(G, 0, _spell("TNL072"), {})
	_ok.call(not _pending(G).is_empty() and bool(_pending(G)["optional"]) and (p0["dungeon"][0] as Array).size() == 1, "TNL072 : « you may » -> la construction est facultative (rien n'est pose d'office)")
	_drain(_match(G))
	var stack: Array = p0["dungeon"][0]
	_ok.call(stack.size() == 2 and str((stack[1] as Dictionary)["id"]) == "mon" and not bool((stack[1] as Dictionary).get("faceDown", false)) and _ids(_hand(G, 0)) == ["trapcard"],
		"TNL072 : une seule salle Monster, un seul emplacement -> construite tout de suite, face visible")
	# effets « build » immediats (FAQ)
	var p1 := _player(0, "BMA001", [_plain("base2", "trap", [1], 1)])
	var G2 := _G([p1, _player(1, "BMA002")])
	_fill(G2, "spells", 2, "spell")
	(p1["hand"] as Array).append(_room("TNL036")) # Sorcerobe School (Monster)
	SpellEffects.cast_spell(G2, 0, _spell("TNL072"), {})
	_drain(_match(G2))
	_ok.call(_hand(G2, 0).size() == 1 and str((_hand(G2, 0)[0] as Dictionary).get("isSpell", false)) == "true", "TNL072 (FAQ) : les effets « when you build this Room » s'appliquent a l'instant")
	# refus : la main et le donjon restent intacts
	var p3 := _player(0, "BMA001", [_plain("base3", "trap", [1], 1)])
	var G4 := _G([p3, _player(1, "BMA002")])
	(p3["hand"] as Array).append(_plain("mon3", "monster"))
	SpellEffects.cast_spell(G4, 0, _spell("TNL072"), {})
	_match(G4)._resolve_choice(0, -1)
	_ok.call(_pending(G4).is_empty() and _ids(_hand(G4, 0)) == ["mon3"] and (p3["dungeon"][0] as Array).size() == 1, "TNL072 : passer -> aucune salle construite, elle reste en main")
	var p2 := _player(0, "BMA001")
	var G3 := _G([p2, _player(1, "BMA002")])
	(p2["hand"] as Array).append(_plain("mon", "monster"))
	_ok.call(SpellTargeting.spell_targets_for(G3, p2, 0, "TNL072").is_empty(), "TNL072 : aucune salle sur laquelle construire -> injouable")

# --- lot 2.1 : correctifs de l'audit (garde commune, Blockpile Puzzle, Fairy Fountain, declencheurs geles, Surprise Gift) -----------------------------

## Gele la salle `idx` du donjon de `pid` (Freeze / Frostbat Cave).
func _freeze(G: Dictionary, pid: int, idx: int) -> void:
	(SpellEffects._effects(G)["deactivatedRooms"] as Array).append({"playerId": pid, "roomIndex": idx})

## Trap Master dans le donjon de `pid` : les capacites des salles sont verrouillees (BossEngine.abilities_locked).
func _lock(G: Dictionary, pid: int) -> void:
	G["adventure"] = {"playerId": pid, "hero": {"id": "TM", "name": "Trap Master", "heroAbility": {"cmd": "DeactivateDungeonAbility"}}, "roomIndex": 0, "hp": 5, "pause": "post-damage"}

func _off(G: Dictionary, mode: String, pid: int = 0, idx: int = 0) -> void:
	if mode == "frozen":
		_freeze(G, pid, idx)
	else:
		_lock(G, pid)

func _t_audit_lot21() -> void:
	# 1. Garde commune : une salle wiki face cachee (posee ce tour) ou gelee n'active pas sa capacite, et le coup n'est pas propose.
	var tread := _room("TNL042")
	var G := _G([_player(0, "BMA001", [tread]), _player(1, "BMA002")])
	G["phase"] = "build"
	G["activePlayer"] = 0
	_hand(G, 0).append(_plain("r1"))
	var m := _match(G)
	var offered := func() -> bool: return m.legal_moves(0).any(func(mv): return str((mv as Dictionary)["type"]) == "activateRoom")
	_ok.call(offered.call(), "garde commune : salle TNL visible -> activateRoom propose")
	tread["faceDown"] = true
	_ok.call(_act(G, 0, 0) == "room is face down or frozen" and not offered.call() and not bool(tread.get("usedThisTurn", false)), "garde commune (TNL042) : face cachee -> refusee et non proposee")
	tread["faceDown"] = false
	_freeze(G, 0, 0)
	_ok.call(_act(G, 0, 0) == "room is face down or frozen" and not offered.call(), "garde commune (TNL042) : gelee -> refusee et non proposee")
	var G2 := _G([_player(0, "BMA001", [_card(CardDB.rooms, "CRL012")]), _player(1, "BMA002")])
	G2["phase"] = "build"
	(G2["players"][0]["dungeon"][0][0] as Dictionary)["faceDown"] = true
	_ok.call(_act(G2, 0, 0) == "room is face down or frozen", "garde commune (CRL012) : face cachee -> refusee")
	var G3 := _G([_player(0, "BMA001", [_room("TNL042")]), _player(1, "BMA002")])
	G3["phase"] = "build"
	_hand(G3, 0).append(_plain("r1"))
	_fill(G3, "rooms", 2)
	_ok.call(_act(G3, 0, 0) == null, "garde commune : visible et degelee -> activee")

	# 2. Blockpile Puzzle : un exemplaire = une destruction (deux exemplaires = deux destructions, options recalculees entre les deux).
	var G4 := _G([_player(0, "BMA001", [_room("TNL047"), _room("TNL047"), _plain("a", "trap", [1], 1), _plain("b", "trap", [1], 3)]), _player(1, "BMA002")])
	_ok.call(TnlAbilities.end_of_turn(G4) and (_pending(G4)["options"] as Array).size() == 4, "TNL047 : deux exemplaires -> premier choix parmi 4 salles")
	var m4 := _match(G4)
	m4._resolve_choice(0, 2) # detruit « a » (index 2)
	_ok.call(not _pending(G4).is_empty() and (_pending(G4)["options"] as Array).size() == 3 and (G4["players"][0]["dungeon"] as Array).size() == 3, "TNL047 : une salle detruite, second choix parmi les 3 restantes")
	m4._resolve_choice(0, 2) # detruit « b » (nouvel index 2)
	var left: Array = (G4["players"][0]["dungeon"] as Array).map(func(st): return (st as Array)[0])
	_ok.call(_pending(G4).is_empty() and _ids(_decks(G4, "roomDiscard")) == ["a", "b"] and _ids(left) == ["TNL047", "TNL047"], "TNL047 : deux destructions au total (les deux Blockpile Puzzle restent)")
	for mode in ["frozen", "locked"]:
		var G5 := _G([_player(0, "BMA001", [_room("TNL047"), _plain("solo")]), _player(1, "BMA002")])
		_off(G5, mode)
		_ok.call(not TnlAbilities.end_of_turn(G5) and (G5["players"][0]["dungeon"] as Array).size() == 2, "TNL047 Blockpile Puzzle (%s) : aucune destruction" % mode)

	# 6. Declencheurs : gel et verrou Trap Master (Inner Sanctum, Imp Temple, Hall of Mirrors, Spellslime Pit, Dragon Graveyard).
	for mode in ["frozen", "locked"]:
		var Gs := _G([_player(0, "BMA001", [_room("TNL018")]), _player(1, "BMA002")])
		_fill(Gs, "rooms", 3)
		_off(Gs, mode)
		TnlAbilities.end_of_turn(Gs)
		_ok.call(_hand(Gs, 0).is_empty(), "TNL018 Inner Sanctum (%s) : aucune pioche" % mode)
		var imp := _room("TNL014")
		var Gi := _G([_player(0, "BMA001", [imp]), _player(1, "BMA002")])
		_off(Gi, mode)
		_ok.call(not TnlAbilities.imp_take(Gi, 0, _plain("x")) and not bool(imp.get("usedThisTurn", false)), "TNL014 Imp Temple (%s) : la carte n'est pas prise" % mode)
		var slime := _room("TNL034")
		var Gm := _G([_player(0, "BMA001", [slime]), _player(1, "BMA002")])
		_off(Gm, mode)
		TnlAbilities.on_spell_resolving(Gm, 0, _spl("a"))
		_ok.call(int(slime.get("dealDamage", 0)) == 0, "TNL034 Spellslime Pit (%s) : pas de +1" % mode)
		var Gh := _G([_player(0, "BMA001", [_room("TNL037")]), _player(1, "BMA002")])
		_fill(Gh, "spells", 3, "spell")
		_off(Gh, mode)
		TnlAbilities.on_spell_resolving(Gh, 1, _spl("b"))
		_ok.call(_hand(Gh, 0).is_empty(), "TNL037 Hall of Mirrors (%s) : aucune pioche" % mode)
		var Gd := _G([_player(0, "BMA001", [_room("TNL020")]), _player(1, "BMA002")])
		_fill(Gd, "rooms", 3)
		_decks(Gd, "spellDiscard").append(_spl("x"))
		_off(Gd, mode)
		RoomAbilities.take_discard_card(Gd, Gd["players"][0], {"card": _spl("x"), "pile": "spell", "pileIndex": 0})
		_ok.call(_hand(Gd, 0).size() == 1, "TNL020 Dragon Graveyard (%s) : pas de pioche" % mode)

	# 4. Fairy Fountain : l'effet prend fin si la salle est couverte ; une fois decouverte (la salle du dessus detruite) elle fait de nouveau ses degats.
	var fairy_room := _plain("fr", "trap", [1], 3)
	var Gf := _G([_player(0, "BMA001"), _player(1, "BMA002")])
	Gf["players"][0]["dungeon"] = [[fairy_room, _plain("cover", "monster", [1], 1)]]
	TnlAbilities._tag(fairy_room)["fairy"] = true
	BossEngine.destroy_room(Gf["players"][0], 0, Gf)
	_ok.call(not TnlAbilities.flag(fairy_room, "fairy") and BossEngine.room_damage_with_modifiers(Gf, Gf["players"][0], 0, {}) == 3, "TNL058 Fairy Fountain : couverte puis decouverte -> l'effet a pris fin (3 degats)")
	var fr2 := _plain("fr2", "trap", [1], 3)
	var Gf2 := _G([_player(0, "BMA001", [fr2]), _player(1, "BMA002")])
	TnlAbilities._tag(fr2)["fairy"] = true
	_ok.call(BossEngine.room_damage_with_modifiers(Gf2, Gf2["players"][0], 0, {}) == 0, "TNL058 : non couverte -> toujours zero degat")

	# 7. Surprise Gift : le sort n'est jouable que si une salle de la main tient sur une salle adverse (avancee : tresor commun).
	var Gg := _G([_player(0, "BMA001"), _player(1, "BMA002", [_plain("host", "trap", [1], 2)])])
	Gg["phase"] = "build"
	Gg["activePlayer"] = 0
	_hand(Gg, 0).append(_plain("adv", "trap", [4], 3, true))
	_ok.call(not TnlSpells.gift_ready(Gg, Gg["players"][0], 0) and TnlSpells.gift_slots(Gg, 0).is_empty(), "TNL070 Surprise Gift : seule une avancee sans tresor commun en main -> injouable")
	_hand(Gg, 0).append(_plain("ord"))
	_ok.call(TnlSpells.gift_ready(Gg, Gg["players"][0], 0) and TnlSpells.gift_slots(Gg, 0).size() == 1, "TNL070 : une salle ordinaire en main -> jouable")

# --- heros ------------------------------------------------------------------------------------------------------------------------------

func _t_lure_kinds() -> void:
	var p0 := _player(0, "BMA001", [_plain("a", "trap", [1])])
	var p1 := _player(1, "BMA002", [_plain("b", "trap", [4])])
	p0["boss"]["treasures"] = []
	p1["boss"]["treasures"] = []
	var G := _G([p0, p1])
	var fool := _hero("TNL097")
	_ok.call(CardDB.hero_lure(fool) == "fewerSouls" and BossEngine.lure_target(G["players"], [0, 1], 0, fool, G) == -1, "TNL097 The Fool : aux moins d'ames ; egalite -> reste en ville")
	(p0["souls"] as Array).append({"souls": 1})
	_ok.call(BossEngine.lure_target(G["players"], [0, 1], 0, fool, G) == 1, "TNL097 : va chez celui qui a le moins d'ames")
	var brothers := _hero("TNL114")
	_ok.call(CardDB.hero_lure(brothers) == "soulsMinusWounds" and BossEngine.lure_target(G["players"], [0, 1], 0, brothers, G) == 0, "TNL114 The Brothers : au plus haut Ames - Blessures")
	(p1["souls"] as Array).append({"souls": 1})
	_ok.call(BossEngine.lure_target(G["players"], [0, 1], 0, brothers, G) == -1, "TNL114 (FAQ) : egalite -> reste en ville")
	(p1["wounds"] as Array).append({"wounds": 1})
	_ok.call(BossEngine.lure_target(G["players"], [0, 1], 0, brothers, G) == 0, "TNL114 : les blessures comptent contre")
	# hybrides : somme des deux tresors
	var q0 := _player(0, "BMA001", [_plain("a", "trap", [1]), _plain("a2", "trap", [3])])
	var q1 := _player(1, "BMA002", [_plain("b", "trap", [3]), _plain("b2", "trap", [3]), _plain("b3", "trap", [1])])
	q0["boss"]["treasures"] = []
	q1["boss"]["treasures"] = []
	var G2 := _G([q0, q1])
	var druid := _hero("TNL108") # Cleric + Mage
	_ok.call(BossEngine.lure_target(G2["players"], [0, 1], 1, druid, G2) == 1, "TNL108 Druid : Cleric + Mage cumules (1 + 1 contre 2 + 1)")
	var q2 := _player(0, "BMA001", [_plain("a", "trap", [1]), _plain("a2", "trap", [4])])
	var G3 := _G([q2, _player(1, "BMA002", [_plain("c", "trap", [4])])])
	q2["boss"]["treasures"] = []
	G3["players"][1]["boss"]["treasures"] = []
	var necro := _hero("TNL100") # Cleric + Thief
	_ok.call(BossEngine.lure_target(G3["players"], [0, 1], 1, necro, G3) == 0, "TNL100 Necromancer : Cleric + Thief cumules (2 vs 1)")
	var sm := _hero("TNL104")
	var arch := _hero("TNL112")
	_ok.call(_int_list(CardDB.hero_treasures(sm)) == [3, 2] and _int_list(CardDB.hero_treasures(arch)) == [2, 4], "TNL104 / TNL112 : deux tresors (hybrides)")

func _t_dark_heroes() -> void:
	var vamp := _hero("TNL077") # Cleric (1), 6 PV
	var owner := _player(0, "BMA001", [_plain("r", "trap", [1], 1)])
	var payer := _player(1, "BMA002")
	var G := _G([owner, payer])
	G["phase"] = "adventure"
	owner["entrance"] = [vamp]
	G["adventure"] = {"playerId": 0, "hero": vamp, "roomIndex": 0, "hp": 2, "pause": "post-damage"}
	G["adventurePausePassed"] = {}
	_hand(G, 1).append_array([_plain("cleric", "trap", [1]), _plain("fighter", "trap", [2])])
	var m := _match(G)
	var pays: Array = m.legal_moves(1).filter(func(mv): return str((mv as Dictionary)["type"]) == "payDarkHero")
	_ok.call(pays.size() == 1 and pays[0]["args"] == [0, 0, "TNL077"], "TNL077 Vampire : un adversaire peut defausser une salle a tresor Cleric (pas Fighter)")
	_ok.call(m.legal_moves(0).filter(func(mv): return str((mv as Dictionary)["type"]) == "payDarkHero").is_empty(), "TNL077 : pas le proprietaire du donjon (« any opponent »)")
	_ok.call(m.apply_move(1, pays[0]), "TNL077 : paiement applique")
	_ok.call(int(G["adventure"]["hp"]) == 5 and _decks(G, "roomDiscard").size() == 1 and _ids(_hand(G, 1)) == ["fighter"], "TNL077 : +3 PV jusqu'a la fin du tour, la salle est defaussee")
	_hand(G, 1).append(_plain("cleric2", "trap", [1]))
	_ok.call(m.legal_moves(1).filter(func(mv): return str((mv as Dictionary)["type"]) == "payDarkHero").is_empty(), "TNL077 (FAQ) : une seule fois par tour et par heros")
	# heros a l'entree (pas encore entre) : +3 retenus pour son entree
	var barb := _hero("TNL083") # Fighter
	var G2 := _G([_player(0, "BMA001", [_plain("r")]), _player(1, "BMA002")])
	G2["phase"] = "adventure"
	G2["players"][0]["entrance"] = [barb]
	_hand(G2, 1).append(_plain("f", "trap", [2]))
	var m2 := _match(G2)
	var mv2: Array = m2.legal_moves(1).filter(func(e): return str((e as Dictionary)["type"]) == "payDarkHero")
	_ok.call(mv2.size() == 1 and m2.apply_move(1, mv2[0]), "TNL083 Barbarian : paye avant son entree")
	_ok.call(TnlAbilities.on_hero_start(G2, 0, barb) == 3, "TNL083 : le bonus de +3 l'attend a l'entree du donjon")
	# Witch / Hitman : memes regles, tresor Mage / Thief
	_ok.call(TnlAbilities.hero_cmd(_hero("TNL089")) == "DarkHeroPay" and TnlAbilities.hero_cmd(_hero("TNL095")) == "DarkHeroPay" and int(_hero("TNL089")["treasure"]) == 3 and int(_hero("TNL095")["treasure"]) == 4,
		"TNL089 Witch (Mage) et TNL095 Hitman (Thief) : memes regles")
	# IA : sauve un heros noir qui va mourir
	var G3 := _G([_player(0, "BMA001", [_plain("r")]), _player(1, "BMA002")])
	G3["phase"] = "adventure"
	G3["players"][0]["entrance"] = [vamp]
	G3["adventure"] = {"playerId": 0, "hero": vamp, "roomIndex": 0, "hp": 0, "pause": "post-damage"}
	_hand(G3, 1).append(_plain("cleric", "trap", [1]))
	var m3 := _match(G3)
	var mv3 = m3.legal_moves(1).filter(func(e): return str((e as Dictionary)["type"]) == "payDarkHero")[0]
	_ok.call(AI.score_move(m3, 1, mv3) > 0.0, "IA : paie pour sauver un heros noir a 0 PV")
	G3["adventure"]["hp"] = 4
	_ok.call(AI.score_move(m3, 1, mv3) < 0.0, "IA : ne paie pas sans raison")

func _t_hero_abilities() -> void:
	# Swordmage : +2 PV a chaque sort joue pendant qu'il est dans le donjon
	var sm := _hero("TNL104")
	var p0 := _player(0, "BMA001", [_plain("r")])
	var G := _G([p0, _player(1, "BMA002")])
	G["adventure"] = {"playerId": 0, "hero": sm, "roomIndex": 0, "hp": 5, "pause": "post-damage"}
	TnlAbilities.on_spell_resolving(G, 1, _spl("x"))
	TnlAbilities.on_spell_resolving(G, 0, _spl("y"))
	_ok.call(int(G["adventure"]["hp"]) == 9, "TNL104 Swordmage : +2 PV par sort, quel que soit le joueur (FAQ)")
	var G1 := _G([_player(0, "BMA001", [_plain("r")]), _player(1, "BMA002")])
	G1["adventure"] = {"playerId": 0, "hero": _hero("TNL084"), "roomIndex": 0, "hp": 5, "pause": "post-damage"}
	TnlAbilities.on_spell_resolving(G1, 1, _spl("x"))
	_ok.call(int(G1["adventure"]["hp"]) == 5, "un autre heros n'est pas affecte")
	# Druid : +X PV = sorts en main du proprietaire du donjon, mis a jour en continu
	var dr := _hero("TNL108")
	var p1 := _player(0, "BMA001", [_plain("r")])
	var G2 := _G([p1, _player(1, "BMA002")])
	(p1["hand"] as Array).append_array([_spl("a"), _spl("b"), _plain("room")])
	G2["adventure"] = {"playerId": 0, "hero": dr, "roomIndex": 0, "hp": 12, "pause": "post-damage"}
	TnlAbilities.sync_hero(G2)
	_ok.call(int(G2["adventure"]["hp"]) == 14, "TNL108 Druid : +X PV (X = 2 sorts en main)")
	(p1["hand"] as Array).pop_front()
	TnlAbilities.sync_hero(G2)
	_ok.call(int(G2["adventure"]["hp"]) == 13, "TNL108 : le bonus baisse quand un sort quitte la main")
	G2["stack"] = [{"id": "e", "type": "spell", "playerId": 0, "card": _spl("c"), "resolved": false}]
	(p1["hand"] as Array).pop_front()
	TnlAbilities.sync_hero(G2)
	_ok.call(int(G2["adventure"]["hp"]) == 13, "TNL108 (FAQ) : le sort en attente compte tant qu'il ne s'est pas resolu")
	# Archer : ignore la derniere salle du donjon
	var archer := _hero("TNL112")
	var rooms: Array = [_plain("a", "trap", [1], 1), _plain("b", "trap", [1], 1), _plain("c", "trap", [1], 99)]
	var p2 := _player(0, "BMA001", rooms)
	var G3 := _G([p2, _player(1, "BMA002")])
	G3["decks"]["heroDiscard"] = []
	p2["entrance"] = [archer]
	G3["adventure"] = {"playerId": 0, "hero": archer, "roomIndex": 0, "hp": 12, "pause": null, "nearest": 0}
	var m := _match(G3)
	m._advance_adventure_room()
	_ok.call(int(G3["adventure"]["roomIndex"]) == 1, "TNL112 Archer : deuxieme salle subie")
	G3["adventure"]["pause"] = null
	m._advance_adventure_room()
	_ok.call((G3["adventure"] as Dictionary).is_empty() and CardDB.total_wounds(p2) == 2 and CardDB.total_souls(p2, G3) == 0,
		"TNL112 : la derniere salle (99 degats) est ignoree, l'Archer survit et blesse le boss")

func _t_necromancer() -> void:
	var necro := _hero("TNL100")
	var a := _hero("TNL073")
	var b := _hero("TNL074")
	var p0 := _player(0, "BMA001", [_plain("r")])
	var G := _G([p0, _player(1, "BMA002")])
	G["decks"]["heroDiscard"] = []
	p0["entrance"] = [necro]
	(p0["souls"] as Array).append(CardDB.soul_entry(a))
	var m := _match(G)
	m._finish_hero(0, necro, 3, {})
	_ok.call((p0["souls"] as Array).is_empty() and CardDB.total_wounds(p0) == 3, "TNL100 Necromancer : survit -> son unique heros face cache est retourne (2 + 1 blessures)")
	_ok.call(_pending(G).is_empty(), "TNL100 : une seule option, resolue d'office")
	var G2 := _G([_player(0, "BMA001", [_plain("r")]), _player(1, "BMA002")])
	G2["decks"]["heroDiscard"] = []
	var q: Dictionary = G2["players"][0]
	(q["souls"] as Array).append(CardDB.soul_entry(a))
	(q["souls"] as Array).append(CardDB.soul_entry(b))
	q["entrance"] = [necro]
	_match(G2)._finish_hero(0, necro, 3, {})
	_ok.call(not _pending(G2).is_empty() and (_pending(G2)["options"] as Array).size() == 2, "TNL100 : plusieurs heros -> choix du joueur")
	var G3 := _G([_player(0, "BMA001", [_plain("r")]), _player(1, "BMA002")])
	G3["decks"]["heroDiscard"] = []
	G3["players"][0]["entrance"] = [necro]
	_match(G3)._finish_hero(0, necro, 0, {})
	_ok.call(CardDB.total_souls(G3["players"][0], G3) == 2, "TNL100 : tue, rien de special")

func _t_hero_hp_effects() -> void:
	var hero := _hero("TNL073")
	var G := _G([_player(0, "BMA001", [_plain("r")]), _player(1, "BMA002")])
	TnlAbilities.add_hero_hp(G, hero, 2)
	TnlAbilities.add_hero_hp(G, hero, -1)
	_ok.call(TnlAbilities.on_hero_start(G, 0, hero) == 1 and TnlAbilities.on_hero_start(G, 0, hero) == 0, "PV retenus : consommes une fois a l'entree")
	_ok.call(TnlAbilities.count_of(G, "entered", 0) == 2, "heros entres comptes par donjon (Meddling Kids!)")
	# Match : adventureNext applique les PV retenus
	var p0 := _player(0, "BMA001", [_plain("r", "trap", [1], 1)])
	var G2 := _G([p0, _player(1, "BMA002")])
	G2["phase"] = "adventure"
	G2["decks"]["heroDiscard"] = []
	p0["entrance"] = [hero]
	TnlAbilities.add_hero_hp(G2, hero, 3)
	G2["activePlayer"] = 0
	G2["xpOrder"] = [0, 1]
	var m := _match(G2)
	_ok.call(m.apply_move(0, {"type": "adventureNext", "args": []}), "adventureNext applique")
	_ok.call(int(G2["adventure"]["hp"]) == int(hero["hp"]) + 3 - 1, "TNL : PV retenus ajoutes a l'entree (hp %d)" % int(G2["adventure"]["hp"]))

# --- IA contre IA, paquets de salles/sorts/boss reduits aux cartes TNL (toutes les capacites TNL sont exercees) ----------------------

const SOAK_MAX_STEPS := 4000

func _t_ai_soak_tnl() -> void:
	var names := {}
	for c in CardDB.rooms + CardDB.spells + CardDB.bosses:
		if str((c as Dictionary).get("set", "")) == "next-level":
			names[str((c as Dictionary)["name"])] = 0
	var finished := 0
	var games := 0
	for n in [2, 2, 2, 2, 3, 3, 3, 3, 4, 4, 4, 4]:
		games += 1
		var m = load("res://godot/scripts/Match.gd").new()
		host.add_child(m)
		load("res://godot/tests/soak_seed.gd").seed_game(m, 1000 + games)
		m.new_match(n, 0, ["next-level"])
		# Paquets 100 % TNL (x3 pour ne pas manquer de cartes) : chaque partie joue beaucoup de salles / sorts TNL.
		var tnl := func(c): return str((c as Dictionary).get("set", "")) == "next-level"
		for pile in ["rooms", "spells"]:
			var only: Array = (m.G["decks"][pile] as Array).filter(tnl)
			var deck: Array = []
			for _k in 3:
				for c in only:
					deck.append((c as Dictionary).duplicate())
			m.G["decks"][pile] = CardDB.shuffled(deck)
		m.G["bossPicks"] = CardDB.shuffled(CardDB.bosses.filter(tnl)).slice(0, n + 2)
		if _play_soak(m):
			finished += 1
		for key in ["logs", "log"]:
			for line in (m.G.get(key, []) as Array):
				for nm in names:
					if str(line).contains(nm):
						names[nm] = int(names[nm]) + 1
		m.queue_free()
	load("res://godot/tests/soak_seed.gd").unseed()
	_ok.call(finished == games, "soak TNL : %d/%d parties IA-vs-IA terminees (pas de blocage)" % [finished, games])
	var touched := 0
	var missing: Array = []
	for nm in names:
		if int(names[nm]) > 0:
			touched += 1
		else:
			missing.append(nm)
	print("SOAK-TNL cartes TNL vues dans les journaux : ", touched, "/", names.size(), " non vues : ", missing)
	_ok.call(touched >= 20, "soak TNL : au moins 20 cartes TNL differentes jouees (%d)" % touched)

func _play_soak(m: Node) -> bool:
	var steps := 0
	while m.G.get("gameOver") == null and steps < SOAK_MAX_STEPS:
		var acted := false
		var phase: String = m.G["phase"]
		var pc: Dictionary = m.G.get("pendingChoice", {})
		if not pc.is_empty():
			var owner := int(pc.get("playerId", 0))
			var cmoves: Array = m.legal_moves(owner)
			if not cmoves.is_empty():
				var cm = AI.pick_move(m, owner)
				m.apply_move(owner, cm if cm != null else cmoves[0])
				steps += 1
				continue
		if phase == "boss":
			for pid in m.G["players"]:
				var moves: Array = m.legal_moves(int(pid))
				if not moves.is_empty():
					m.apply_move(int(pid), moves[0])
					acted = true
					break
		elif phase == "build":
			acted = true # Match._drive_ai() fait jouer le joueur actif
		elif phase == "adventure":
			var ap: int = m.active_player()
			var moves2: Array = m.legal_moves(ap)
			if not moves2.is_empty():
				var mv = AI.pick_move(m, ap)
				if mv == null:
					mv = moves2[0]
				acted = m.apply_move(ap, mv)
			if not acted:
				for pid in m.G["players"]:
					var pmoves: Array = m.legal_moves(int(pid))
					if not pmoves.is_empty() and m.apply_move(int(pid), pmoves[0]):
						acted = true
						break
		else:
			break
		steps += 1
		if not acted:
			break
	return m.G.get("gameOver") != null

## Les tresors venus du JSON sont des flottants (3.0) : on compare des entiers.
func _int_list(arr: Array) -> Array:
	var out: Array = []
	for t in arr:
		out.append(int(t))
	return out

# --- chemin reel (apply_move) et interface ------------------------------------------------------------------------------------------

## Torix via le vrai coup activateRoom : la salle Monster qui se detruit pour payer sa capacite revient dans sa main (flush a la fin du coup).
func _t_torix_via_apply_move() -> void:
	var p0 := _player(0, "TNL003", [_room("TNL033")], true)
	var G := _G([p0, _player(1, "BMA002", [_plain("target", "monster", [3], 4)])])
	TnlAbilities.level_up(G, 0, p0, p0["boss"])
	G["phase"] = "adventure"
	G["activePlayer"] = 0
	var m := _match(G)
	_ok.call(m.apply_move(0, {"type": "activateRoom", "args": [0]}), "Torix : Frostbat Cave activee par apply_move")
	m.apply_move(m.active_player(), {"type": "pass", "args": []}) # R-D67 : capacite en file, l'adversaire passe
	_ok.call(str(_pending(G).get("step", "")) == "torix" and _hand(G, 0).is_empty() and _decks(G, "roomDiscard").is_empty(), "Torix : Frostbat Cave (Monster) detruite par son propre cout est proposee a Torix a la fin du coup")
	_ok.call(m.apply_move(0, {"type": "resolveChoice", "args": [0]}) and _ids(_hand(G, 0)) == ["TNL033"] and _pending(G).is_empty(), "Torix : acceptee via resolveChoice, elle rejoint la main")

func _t_ui_labels_and_menu() -> void:
	var G := _G([_player(0, "BMA001", [_plain("A"), _plain("B")]), _player(1, "BMA002", [_plain("C")])])
	G["activePlayer"] = 0
	(G["players"][0]["souls"] as Array).append(CardDB.soul_entry(_hero("TNL073")))
	for t in [{"mode": "swap", "a": 0, "b": 1}, {"mode": "destroy", "targetPlayerId": 1, "roomIndex": 0}, {"targetPlayerId": 1}, {"roomIndex": 0, "treasure": 3},
			{"soulIndex": 0}, {"heroId": "x"}, {"mode": "nowin", "targetPlayerId": 1}, {}]:
		_ok.call(TnlSpells.describe_target(G, t) is String, "libelle de cible TNL %s" % str(t))
	_ok.call(TnlSpells.describe_target(G, {"targetPlayerId": 1, "roomIndex": 0}).contains("C"), "libelle : la salle ciblee est nommee")
	var script: GDScript = load("res://godot/scripts/Main.gd")
	var decks: Array = script.get_script_constant_map()["APK_DECKS"]
	var tnl: Dictionary = {}
	for d in decks:
		if str((d as Dictionary)["id"]) == "next-level":
			tnl = d
	_ok.call(not tnl.is_empty() and bool(tnl["playable"]), "menu : The Next Level est une extension cochable (ecran SELECT EXPANSIONS)")
	_ok.call((script.get_script_constant_map()["EXT_PACKS"] as Array).has("next-level"), "menu : la bascule « Extensions du wiki » inclut toujours TNL")

## Chaque boss TNL joue une partie IA-vs-IA (joueur 0) : les level-ups / capacites de boss sont atteints au moins quelques fois (pas de blocage ni d'erreur).
func _t_ai_soak_each_boss() -> void:
	var tnl_bosses: Array = CardDB.bosses.filter(func(c): return str((c as Dictionary).get("set", "")) == "next-level")
	var finished := 0
	var leveled := 0
	for k in tnl_bosses.size():
		var m = load("res://godot/scripts/Match.gd").new()
		host.add_child(m)
		load("res://godot/tests/soak_seed.gd").seed_game(m, 3000 + k)
		m.new_match(2, 0, ["next-level"])
		m.G["bossPicks"] = [tnl_bosses[k], tnl_bosses[(k + 1) % tnl_bosses.size()]]
		var tnl := func(c): return str((c as Dictionary).get("set", "")) == "next-level"
		for pile in ["rooms", "spells"]:
			var only: Array = (m.G["decks"][pile] as Array).filter(tnl)
			var deck: Array = []
			for _k in 3:
				for c in only:
					deck.append((c as Dictionary).duplicate())
			m.G["decks"][pile] = CardDB.shuffled(deck)
		if _play_soak(m):
			finished += 1
		if bool((m.G["players"][0] as Dictionary).get("leveledUp", false)):
			leveled += 1
		m.queue_free()
	load("res://godot/tests/soak_seed.gd").unseed()
	_ok.call(finished == tnl_bosses.size(), "soak TNL (un boss TNL par partie) : %d/%d parties terminees" % [finished, tnl_bosses.size()])
	print("SOAK-TNL bosses TNL montes de niveau : ", leveled, "/", tnl_bosses.size())
	# Fumee, pas une statistique : 4 a 6 sur 13 selon la graine de depart (3000/3100/3200/3300), le flux d'alea bouge a chaque correctif de regles.
	_ok.call(leveled >= 3, "soak TNL : au moins 3 level-ups de boss TNL atteints (%d)" % leveled)

# --- arbitrages wiki (docs/rules/arbitrages-wiki.md) : texte imprime lu a la lettre -------------------------------------------------------

func _t_arbitrages_wiki() -> void:
	# TNL012 Eclipse : « when YOU destroy a Room » : une salle detruite par le sort d'un adversaire ne donne rien
	var under := _plain("under", "monster", [2], 3)
	var pe := _player(0, "TNL012", [], true)
	pe["dungeon"] = [[under, _plain("top", "trap", [1], 1)]]
	var Ge := _G([pe, _player(1, "BMA001")])
	TnlAbilities.destroy_actor = 1
	BossEngine.destroy_room(pe, 0, Ge)
	TnlAbilities.destroy_actor = -1
	_ok.call(int(under.get("dealDamage", 0)) == 0, "arbitrage Eclipse : salle detruite par un ADVERSAIRE -> pas de +3")
	var under2 := _plain("under2", "monster", [2], 3)
	var pe2 := _player(0, "TNL012", [], true)
	pe2["dungeon"] = [[under2, _plain("top2", "trap", [1], 1)]]
	var Ge2 := _G([pe2, _player(1, "BMA001")])
	TnlAbilities.destroy_actor = 0
	BossEngine.destroy_room(pe2, 0, Ge2)
	TnlAbilities.destroy_actor = -1
	_ok.call(int(under2.get("dealDamage", 0)) == 3, "arbitrage Eclipse : salle detruite par le proprietaire (son sort) -> +3")
	# TNL055 Save Point : un sort annule a bien ete « played » (la carte part en defausse a l'activation)
	var Gs := _G([_player(0, "BMA001", [_room("TNL055")]), _player(1, "BMA002")])
	var cancelled := _spl("cancelled")
	Gs["stack"] = [{"type": "spell", "card": cancelled, "playerId": 0, "target": {}, "canceled": true}]
	_match(Gs)._resolve_pending_stack()
	_ok.call(_act(Gs, 0, 0) == null and _ids(_hand(Gs, 0)) == ["cancelled"], "arbitrage Save Point : un sort joue puis annule peut etre repris")
	# TNL068 Shortcut! : une salle desactivee reste « a Room it would enter » (elle est sautee) ; cinq salles dont une face cachee = cinq salles
	var hero := _hero("TNL073")
	var rooms: Array = [_plain("a"), _plain("b"), _plain("c")]
	var p1 := _player(1, "BMA002", rooms)
	var G := _G([_player(0, "BMA001"), p1])
	p1["entrance"] = [hero]
	G["adventure"] = {"playerId": 1, "hero": hero, "roomIndex": 0, "hp": 9, "pause": null, "nearest": 0}
	(G["effects"]["deactivatedRooms"] as Array).append({"playerId": 1, "roomIndex": 1})
	SpellEffects.cast_spell(G, 0, _spell("TNL068"), {"heroId": hero["id"], "targetPlayerId": 1})
	_match(G)._advance_adventure_room()
	_ok.call(int(G["adventure"]["roomIndex"]) == 2, "arbitrage Shortcut! : la salle desactivee est la salle sautee (le heros arrive en salle 2)")
	var five: Array = []
	for i in 5:
		five.append(_plain("f%d" % i))
	(five[2] as Dictionary)["faceDown"] = true
	var p5 := _player(1, "BMA002", five)
	var G5 := _G([_player(0, "BMA001"), p5])
	p5["entrance"] = [hero]
	G5["adventure"] = {"playerId": 1, "hero": hero, "roomIndex": 0, "hp": 9, "pause": null, "nearest": 0}
	SpellEffects.cast_spell(G5, 0, _spell("TNL068"), {"heroId": hero["id"], "targetPlayerId": 1})
	_ok.call(int(G5["adventure"]["skip"]) == 2, "arbitrage Shortcut! : cinq salles (dont une face cachee) -> deux salles sautees")
