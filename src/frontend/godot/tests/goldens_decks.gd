extends RefCounted
## Goldens des paquets APK supplementaires (PlayerChoice = KSA, HiddenHeros = BMH, ToolsHeroKind = THK).
## Chaque cas cite la classe C# (apk-original/decompiled/DBMGame) dont il fige le comportement.
## Appele par goldens.gd : `load("res://godot/tests/goldens_decks.gd").new().run(_ok, self)`.

var _ok: Callable
var host: Node

func run(ok: Callable, h: Node) -> void:
	_ok = ok
	host = h
	_t_hero_rules_keyed_by_kind()
	_t_new_match_decks()
	_t_items_revealed_each_turn()
	_t_passive_levelups()
	_t_levelup_brothers_wise()
	_t_levelup_kawnee()
	_t_levelup_hellcow()
	_t_tpk_spell()
	_t_trap_master_locks_rooms()
	_t_monster_hunter_resists_monsters()
	_t_thk_inert()
	_t_oracle_giant_size_any_room_type()
	_t_oracle_trepidation_after_hero()
	_t_oracle_empty_adventure_window()

# --- fabrique d'etats minimaux ----------------------------------------------------------------------

func _card(arr: Array, id: String) -> Dictionary:
	for c in arr:
		if str((c as Dictionary).get("id", "")) == id:
			return (c as Dictionary).duplicate(true)
	push_error("carte introuvable " + id)
	return {}

func _room(id: String, type: String, treasures: Array, damage: int = 1) -> Dictionary:
	return {"id": id, "name": id, "type": type, "advanced": false, "treasures": treasures, "damage": damage, "isRoom": true}

func _hero(id: String) -> Dictionary:
	var h := _card(CardDB.heroes, id)
	h["souls"] = 2 if bool(h.get("epic", false)) else 1
	h["wounds"] = h["souls"]
	return h

func _player(pid: int, boss_id: String, dungeon: Array = []) -> Dictionary:
	var stacks: Array = []
	for r in dungeon:
		stacks.append([r])
	return {"id": pid, "boss": _card(CardDB.bosses, boss_id), "dungeon": stacks, "hand": [], "souls": [], "wounds": [],
		"entrance": [], "eliminated": false, "leveledUp": false, "buildsThisTurn": 0}

func _G(players: Array) -> Dictionary:
	var ps := {}
	for p in players:
		ps[int((p as Dictionary)["id"])] = p
	return {"players": ps, "town": [], "log": [], "logs": [], "adventure": {}, "turn": 1, "phase": "adventure",
		"effects": SpellEffects.empty_effects(),
		"decks": {"rooms": [], "spells": [], "heroes": [], "epics": [], "items": [], "roomDiscard": [], "spellDiscard": [], "heroDiscard": []}}

func _match(G: Dictionary) -> Node:
	var m = load("res://godot/scripts/Match.gd").new()
	host.add_child(m)
	m.G = G
	return m

# --- BMH / regles de heros par type de condition --------------------------------------------------------

## BMH0xx remplace BMA0xx (ReplacesCardNumber) ; LuredByFewerSouls / LuredByWounds / LuredByTreasures se lisent sur la carte, pas sur l'id.
func _t_hero_rules_keyed_by_kind() -> void:
	_ok.call(CardDB.base_id("BMH080") == "BMA080" and CardDB.base_id("KSA014") == "KSA014", "BMH080 -> BMA080 (identite de base)")
	_ok.call(CardDB.hero_lure(_card(CardDB.heroes, "BMH080")) == "fewerSouls", "BMH080 The Fool : LuredByFewerSouls")
	_ok.call(CardDB.hero_lure(_card(CardDB.heroes, "KSA014")) == "wounds", "KSA014 Demigod : LuredByWounds")
	_ok.call(CardDB.hero_lure(_card(CardDB.heroes, "BMH056")) == "treasures", "BMH056 : LuredByTreasures")
	_ok.call(str(_card(CardDB.heroes, "BMH056").get("replaces", "")) == "BMA056", "BMH056 remplace BMA056")
	var p0 := _player(0, "BMA001")
	var p1 := _player(1, "BMA002")
	var G := _G([p0, p1])
	var order := [0, 1]
	var fool := _card(CardDB.heroes, "BMH080")
	_ok.call(BossEngine.lure_target(G["players"], order, 0, fool, G) == -1, "BMH080 : egalite d'ames, reste en ville")
	(p0["souls"] as Array).append({"souls": 1})
	_ok.call(BossEngine.lure_target(G["players"], order, 0, fool, G) == 1, "BMH080 : va chez le joueur au moins d'ames")
	var demigod := _card(CardDB.heroes, "KSA014")
	(p0["wounds"] as Array).append({"wounds": 1})
	(p1["wounds"] as Array).append({"wounds": 1})
	(p1["wounds"] as Array).append({"wounds": 1})
	_ok.call(BossEngine.lure_target(G["players"], order, 0, demigod, G) == 0, "KSA014 : va chez le joueur au moins de blessures")
	# KSA016 Monster Hunter : Cleric + Fighter cumules (HeroInfo.Treasures = [1, 2]).
	var q0 := _player(0, "BMA003", [_room("A", "trap", [1, 2])])
	var q1 := _player(1, "BMA004", [_room("B", "trap", [1])])
	q0["boss"]["treasures"] = []
	q1["boss"]["treasures"] = []
	var G2 := _G([q0, q1])
	var hunter := _card(CardDB.heroes, "KSA016")
	_ok.call(BossEngine.lure_target(G2["players"], order, 1, hunter, G2) == 0, "KSA016 : tresors Cleric + Fighter additionnes")

# --- composition des paquets -------------------------------------------------------------------------------

func _count_prefix(arr: Array, prefix: String) -> int:
	var n := 0
	for c in arr:
		if str((c as Dictionary).get("id", "")).begins_with(prefix):
			n += 1
	return n

## CardInfoService.GetCardInfoFromDeck + GameBoardExtensions.InternalInititalizeGameBoard.
func _t_new_match_decks() -> void:
	var m = load("res://godot/scripts/Match.gd").new()
	host.add_child(m)
	var base: Dictionary = m.new_match(2, 1, ["base"])
	_ok.call((base["decks"]["heroes"] as Array).size() == 13 and (base["decks"]["epics"] as Array).size() == 8, "base 2j : 13 ordinaires + 8 epiques")
	_ok.call((base["decks"]["items"] as Array).is_empty(), "base : aucun objet")
	var hh: Dictionary = m.new_match(2, 1, ["hidden-heroes"])
	var all_h: Array = (hh["decks"]["heroes"] as Array) + (hh["decks"]["epics"] as Array)
	_ok.call(all_h.size() == 21 and _count_prefix(all_h, "BMH") == 21 and _count_prefix(all_h, "BMA") == 0,
		"HiddenHeros : les BMH remplacent les BMA (21 heros a 2j, aucun BMA)")
	var pc: Dictionary = m.new_match(2, 1, ["players-choice"])
	_ok.call((pc["decks"]["epics"] as Array).size() == 11 and _count_prefix(pc["decks"]["epics"], "KSA") == 3, "PlayerChoice : 3 epiques KSA en plus des 8")
	_ok.call(_count_prefix(pc["decks"]["spells"], "KSA") == 1, "PlayerChoice : T.P.K. dans la pioche de sorts")
	var picks: Array = pc["bossPicks"]
	_ok.call(picks.size() == CardDB.bosses.filter(func(b): return (b as Dictionary).get("set", "base") in ["base", "players-choice"]).size(), "tous les boss des paquets choisis sont proposes")
	var pc3: Dictionary = m.new_match(3, 1, ["players-choice", "hidden-heroes"])
	_ok.call((pc3["decks"]["heroes"] as Array).size() == 17 and (pc3["decks"]["epics"] as Array).size() == 15,
		"PlayerChoice + HiddenHeros 3j : 17 ordinaires, 12 + 3 epiques")
	var tools: Dictionary = m.new_match(2, 1, ["tools"])
	_ok.call((tools["decks"]["items"] as Array).size() == 20, "ToolsHeroKind : 20 objets")
	_ok.call(_count_prefix(tools["decks"]["rooms"], "THK") == 4, "ToolsHeroKind : 4 salles")
	m.queue_free()

## GameBoard.RevealItems : 1 objet par tour, 2 a 4 joueurs ; RevealedItemsQueue, jamais attache a un heros (FlipItem leve NotImplemented).
func _t_items_revealed_each_turn() -> void:
	var m = load("res://godot/scripts/Match.gd").new()
	host.add_child(m)
	m.new_match(2, 1, ["tools"])
	m._reveal_items()
	_ok.call((m.G["itemQueue"] as Array).size() == 1 and (m.G["decks"]["items"] as Array).size() == 19, "2 joueurs : 1 objet revele")
	m.new_match(4, 1, ["tools"])
	m._reveal_items()
	_ok.call((m.G["itemQueue"] as Array).size() == 2 and (m.G["decks"]["items"] as Array).size() == 18, "4 joueurs : 2 objets reveles")
	for n in [5, 6]: # livret « Beginning of Turn » : trois objets pour 5-6 joueurs (avec Crash Landing, seul moyen d'y jouer)
		m.new_match(n, 1, ["crash-landing", "tools"])
		m._reveal_items()
		_ok.call((m.G["itemQueue"] as Array).size() == 3 and (m.G["decks"]["items"] as Array).size() == 17, "%d joueurs : 3 objets reveles" % n)
	m.queue_free()

# --- bosses PlayerChoice -----------------------------------------------------------------------------------

func _t_passive_levelups() -> void:
	# KSA001 Kirax : AddTreasuresToDungeon (passif, une fois monte de niveau).
	var kirax := _player(0, "KSA001", [_room("A", "trap", [2])])
	var G := _G([kirax, _player(1, "BMA001")])
	var before := BossEngine.dungeon_treasures(kirax, G)
	kirax["leveledUp"] = true
	var after := BossEngine.dungeon_treasures(kirax, G)
	before.sort()
	after.sort()
	_ok.call(before == [2, 4] and after == [1, 2, 2, 3, 4], "KSA001 : +Cleric/Mage/Fighter au level-up (%s -> %s)" % [str(before), str(after)])
	# KSA005 Scythe : LastRoomDealDamage(3) = la salle du fond (index Godot le plus grand) ; BMA... pas les autres.
	var scythe := _player(0, "KSA005", [_room("A", "trap", [1]), _room("B", "trap", [1]), _room("C", "trap", [1])])
	var G2 := _G([scythe, _player(1, "BMA001")])
	_ok.call(BossEngine.room_damage_with_modifiers(G2, scythe, 2, {}) == 1, "KSA005 avant level-up : aucun bonus")
	scythe["leveledUp"] = true
	_ok.call(BossEngine.room_damage_with_modifiers(G2, scythe, 2, {}) == 4, "KSA005 : +3 a la derniere salle")
	_ok.call(BossEngine.room_damage_with_modifiers(G2, scythe, 0, {}) == 1, "KSA005 : les autres salles inchangees")
	# KSA006 Jarin : AddSoulsToBoss(1).
	var jarin := _player(0, "KSA006")
	var G3 := _G([jarin, _player(1, "BMA001")])
	_ok.call(CardDB.total_souls(jarin, G3) == 0, "KSA006 avant level-up : 0 ame")
	jarin["leveledUp"] = true
	_ok.call(CardDB.total_souls(jarin, G3) == 1, "KSA006 : +1 ame (passif)")
	# KSA007 Elicon : MultiplyTreasuresDungeon(2) jusqu'a la fin du tour, ni boss ni sorts.
	var elicon := _player(0, "KSA007", [_room("A", "trap", [1])])
	var G4 := _G([elicon, _player(1, "BMA001")])
	elicon["leveledUp"] = true
	_ok.call(RoomAbilities.process_level_up(G4, 0) == null, "KSA007 : aucun choix")
	_ok.call(BossEngine.treasure_count(elicon, 1, G4) == 2 and BossEngine.treasure_count(elicon, 4, G4) == 1, "KSA007 : tresors des salles x2, pas ceux du boss")

## KSA003 The Brothers Wise : PutCardInHand(SpellInDeck BoardDeck), CanAvoid.
func _t_levelup_brothers_wise() -> void:
	var p0 := _player(0, "KSA003")
	var G := _G([p0, _player(1, "BMA001")])
	_ok.call(RoomAbilities.process_level_up(G, 0) == null, "KSA003 sans sort en pioche : capacite ignoree")
	for i in 3:
		(G["decks"]["spells"] as Array).append({"id": "S%d" % i, "name": "S%d" % i, "isSpell": true})
	var c = RoomAbilities.process_level_up(G, 0)
	_ok.call(c != null and str(c["type"]) == "search-spell" and bool(c["optional"]) and (c["options"] as Array).size() == 3, "KSA003 : choix facultatif parmi la pioche")
	var m := _match(G)
	G["pendingChoice"] = c
	m._resolve_choice(0, 1)
	_ok.call((p0["hand"] as Array).size() == 1 and str(p0["hand"][0]["id"]) == "S1" and (G["decks"]["spells"] as Array).size() == 2, "KSA003 : le sort choisi passe en main")
	m.queue_free()

## KSA004 Kaw'nee : PlaceAtScorekeep(FaceDown) d'un heros ORDINAIRE mort chez un adversaire.
func _t_levelup_kawnee() -> void:
	var p0 := _player(0, "KSA004")
	var p1 := _player(1, "BMA001")
	var G := _G([p0, p1])
	_ok.call(RoomAbilities.process_level_up(G, 0) == null, "KSA004 sans heros adverse mort : capacite ignoree")
	(p1["souls"] as Array).append(CardDB.soul_entry(_hero("BMA056")))
	for _i in 2:
		(p1["souls"] as Array).append(CardDB.soul_entry(_hero("BMA081"))) # epique : 2 ames, jamais volable
	# Un seul heros ordinaire (un adversaire) : ComposedTargetProvider.TryToAutoresolve le prend d'office, sans choix.
	_ok.call(RoomAbilities.process_level_up(G, 0) == null, "KSA004 : candidat unique auto-resolu")
	_ok.call((p1["souls"] as Array).size() == 2 and (p0["souls"] as Array).size() == 1 and CardDB.total_souls(p0, G) == 1, "KSA004 : le heros change de scorekeeping")
	# Deux candidats : choix facultatif, les epiques restent non volables.
	(p1["souls"] as Array).append(CardDB.soul_entry(_hero("BMA056")))
	(p1["souls"] as Array).append(CardDB.soul_entry(_hero("BMA056")))
	var c = RoomAbilities.process_level_up(G, 0)
	_ok.call(c != null and str(c["type"]) == "steal-hero" and (c["options"] as Array).size() == 2, "KSA004 : seuls les heros ordinaires sont proposes")

## KSA002 Hellcow : RearrangeDungeon, tout le donjon d'un joueur, ordre = slots C# (Dungeon[0] = fond = index Godot le plus grand).
func _t_levelup_hellcow() -> void:
	var p0 := _player(0, "KSA002", [_room("A", "trap", [1]), _room("B", "trap", [1]), _room("C", "trap", [1])])
	p0["isAI"] = true # l'IA et l'oracle choisissent eux-memes ; un siege humain est autoresolu (voir plus bas)
	var G := _G([p0, _player(1, "BMA001")])
	var c = RoomAbilities.process_level_up(G, 0)
	_ok.call(c != null and str(c["type"]) == "rearrange-dungeon" and str(c["step"]) == "order" and (c["options"] as Array).size() == 3,
		"KSA002 : un seul donjon ciblable = pas de choix de donjon, ordre des salles")
	var m := _match(G)
	G["pendingChoice"] = c
	m._resolve_choice(0, _option_of(c, "A")) # A au fond
	_ok.call(str(G["pendingChoice"].get("step", "")) == "order" and (G["pendingChoice"]["options"] as Array).size() == 2, "KSA002 : choix suivant")
	m._resolve_choice(0, _option_of(G["pendingChoice"], "B")) # puis B ; C est place d'office
	var ids: Array = []
	for st in p0["dungeon"]:
		ids.append(str(st[0]["id"]))
	_ok.call(G["pendingChoice"].is_empty() and ids == ["C", "B", "A"], "KSA002 : A au fond, B, C a l'entree (obtenu %s)" % str(ids))
	# Un adversaire ET soi-meme ciblables : choix du donjon d'abord.
	var p2 := _player(0, "KSA002", [_room("A", "trap", [1]), _room("B", "trap", [1])])
	p2["isAI"] = true
	var p3 := _player(1, "BMA001", [_room("X", "trap", [1]), _room("Y", "trap", [1])])
	var G2 := _G([p2, p3])
	var c2 = RoomAbilities.process_level_up(G2, 0)
	_ok.call(c2 != null and str(c2["step"]) == "dungeon" and (c2["options"] as Array).size() == 2, "KSA002 : choix du donjon (le sien ou celui d'un adversaire)")
	# Une salle en attente AVANT une salle visible (trou) : Target1.Count != DungeonSize, donjon non ciblable (RoomInDungeon : !PendingToBeBuilt).
	(p3["dungeon"][1][0] as Dictionary)["faceDown"] = true
	var c3 = RoomAbilities.process_level_up(G2, 0)
	_ok.call(c3 != null and c3["step"] == "order", "KSA002 : donjon adverse avec salle en attente avant une salle visible ignore")
	# Salle en attente en FIN de donjon (nouvelle salle de ce tour) : DungeonSize l'ignore, les salles avant elle restent ciblables.
	(p3["dungeon"][1][0] as Dictionary)["faceDown"] = false
	(p3["dungeon"][0][0] as Dictionary)["faceDown"] = true
	var c4 = RoomAbilities.process_level_up(G2, 0)
	_ok.call(c4 != null and c4["step"] == "dungeon" and (c4["options"] as Array).size() == 2, "KSA002 : salle en attente en fin de donjon, le reste du donjon adverse est ciblable")
	# Siege humain, un seul donjon ciblable : ComposedTargetProvider.TryToAutoresolve, les salles sont prises dans l'ordre de GetAvailableTargets (inverse du donjon).
	var ph := _player(0, "KSA002", [_room("A", "trap", [1]), _room("B", "trap", [1]), _room("C", "trap", [1])])
	var GH := _G([ph, _player(1, "BMA001")])
	var hids: Array = []
	_ok.call(RoomAbilities.process_level_up(GH, 0) == null, "KSA002 humain : un seul donjon ciblable, aucun choix")
	for st in ph["dungeon"]:
		hids.append(str(st[0]["id"]))
	_ok.call(hids == ["C", "B", "A"], "KSA002 humain : donjon inverse par l'autoresolution (obtenu %s)" % str(hids))
	m.queue_free()
	_t_levelup_hellcow_pending()

## X-M30 (GameBoard.RevealAllRoomCards:928-967) : EnqueueAbilityTransaction resout les cibles de Hellcow AU MOMENT du level-up, pendant la boucle sur Players. Un joueur
## traite apres lui a encore son emplacement construit ce tour PendingToBeBuilt : DungeonSize l'ignore et RoomInDungeon (!PendingToBeBuilt) aussi.
func _t_levelup_hellcow_pending() -> void:
	var p0 := _player(0, "KSA002", [_room("A", "trap", [1]), _room("B", "trap", [1]), _room("C", "trap", [1]), _room("D", "trap", [1]), _room("E", "trap", [1])])
	p0["isAI"] = true
	(p0["dungeon"][0][0] as Dictionary)["faceDown"] = true # 5e emplacement C# construit ce tour : declenche le level-up
	var p1 := _player(1, "BMA001", [_room("X", "trap", [1]), _room("Y", "trap", [1]), _room("Z", "trap", [1])])
	(p1["dungeon"][0][0] as Dictionary)["faceDown"] = true # nouvelle salle de l'adversaire traite apres
	var G := _G([p0, p1])
	G["apkSeats"] = [0, 1]
	var m := _match(G)
	var lv: Dictionary = {}
	for it in m._build_reveal_queue():
		if str((it as Dictionary).get("kind", "")) == "levelup" and int(it["pid"]) == 0:
			lv = it
	_ok.call(not lv.is_empty() and ((lv.get("pend", {}) as Dictionary).get("1", []) as Array) == [0] and not (lv["pend"] as Dictionary).has("0"),
		"KSA002 X-M30 : a l'instant du level-up, seul l'emplacement de l'adversaire traite apres est en attente (obtenu %s)" % str(lv.get("pend")))
	var pend: Dictionary = lv.get("pend", {})
	var c = RoomAbilities.process_level_up(G, 0, {}, pend)
	_ok.call(c != null and c["step"] == "dungeon" and (c["options"] as Array).size() == 2, "KSA002 X-M30 : les deux donjons restent ciblables")
	var c2 = RoomAbilities.rearrange_choice(G, 0, 1, [], pend)
	var idxs: Array = []
	for o in (c2["options"] as Array):
		idxs.append(int((o as Dictionary)["roomIndex"]))
	idxs.sort()
	_ok.call(c2 != null and idxs == [1, 2], "KSA002 X-M30 : la salle en attente de l'adversaire n'est pas proposee (obtenu %s)" % str(idxs))
	var cold = RoomAbilities.rearrange_choice(G, 0, 1, [], {})
	_ok.call((cold["options"] as Array).size() == 3, "KSA002 sans instantane : tout est revele, 3 salles (ancien comportement de Godot)")
	G["pendingChoice"] = c2
	m._resolve_choice(0, 0) # Z (index Godot 2 = emplacement C# 0) d'abord ; Y est place d'office
	var ids: Array = []
	for st in p1["dungeon"]:
		ids.append(str(st[0]["id"]))
	_ok.call(ids == ["X", "Y", "Z"] or ids == ["X", "Z", "Y"], "KSA002 X-M30 : la salle en attente reste a sa place (obtenu %s)" % str(ids))
	m.queue_free()

func _option_of(choice: Dictionary, room_id: String) -> int:
	var opts: Array = choice["options"]
	for i in opts.size():
		if str(((opts[i] as Dictionary)["card"] as Dictionary).get("id", "")) == room_id:
			return i
	return -1

# --- T.P.K. --------------------------------------------------------------------------------------------------

func _t_tpk_spell() -> void:
	var tpk := _card(CardDB.spells, "KSA013")
	tpk["isSpell"] = true
	_ok.call(CardDB.can_play_spell(tpk, "build") and CardDB.can_play_spell(tpk, "adventure"), "T.P.K. : jouable en construction et en aventure")
	var p0 := _player(0, "BMA001")
	var p1 := _player(1, "BMA002")
	var G := _G([p0, p1])
	_ok.call(SpellTargeting.spell_targets_for(G, p0, 0, "KSA013") == [{"targetPlayerId": 0}], "T.P.K. : BossOwner = le lanceur")
	G["aiTargetsAllBosses"] = true
	_ok.call(SpellTargeting.spell_targets_for(G, p0, 0, "KSA013").size() == 2, "T.P.K. (IA de l'oracle) : tous les joueurs")
	(G["decks"]["spellDiscard"] as Array).append(tpk)
	SpellEffects.cast_spell(G, 0, tpk, {"targetPlayerId": 0})
	_ok.call((G["decks"]["spellDiscard"] as Array).is_empty() and (p0["untilEndSpells"] as Array).size() == 1, "T.P.K. quitte la defausse pour rester chez le lanceur")
	_ok.call(CardDB.total_souls(p0, G) == 0, "T.P.K. : sans les 4 classes, aucun bonus")
	for hid in ["BMA056", "BMA062", "BMA068"]: # Cleric, Fighter, Mage
		(p0["souls"] as Array).append(CardDB.soul_entry(_hero(hid)))
	_ok.call(CardDB.total_souls(p0, G) == 3, "T.P.K. : 3 classes sur 4, aucun bonus")
	(p0["souls"] as Array).append(CardDB.soul_entry(_hero("BMA074"))) # Thief
	_ok.call(CardDB.total_souls(p0, G) == 4 + 2, "T.P.K. : Cleric + Fighter + Mage + Thief = +2 ames")
	# La cible est lue sur le scorekeeping du joueur designe (IA APK : premier joueur par PlayerId), le bonus va au proprietaire du sort.
	var G2 := _G([_player(0, "BMA001"), _player(1, "BMA002")])
	G2["aiTargetsAllBosses"] = true
	for hid in ["BMA056", "BMA062", "BMA068", "BMA074"]:
		(G2["players"][0]["souls"] as Array).append(CardDB.soul_entry(_hero(hid)))
	var tpk2 := tpk.duplicate(true)
	SpellEffects.cast_spell(G2, 1, tpk2, {"targetPlayerId": 0})
	_ok.call(CardDB.total_souls(G2["players"][1], G2) == 2 and CardDB.total_souls(G2["players"][0], G2) == 4, "T.P.K. : bonus au lanceur, condition sur la cible")
	# Hero a deux classes (KSA016 [Cleric, Fighter]) : un seul heros couvre deux types.
	var G3 := _G([_player(0, "BMA001"), _player(1, "BMA002")])
	G3["players"][0]["untilEndSpells"] = [{"card": tpk.duplicate(true), "target": 0}]
	for hid in ["KSA016", "KSA017"]: # [1,2] et [3,4]
		for _i in 2:
			(G3["players"][0]["souls"] as Array).append(CardDB.soul_entry(_hero(hid)))
	_ok.call(CardDB.total_souls(G3["players"][0], G3) == 4 + 2, "T.P.K. : Monster Hunter (Cleric/Fighter) + Trap Master (Mage/Thief) suffisent")

# --- heros du PlayerChoice -----------------------------------------------------------------------------------

## KSA017 Trap Master : ThisHeroEntersDungeon -> DeactivateDungeonAbility (Ability.IsLocked : CheckConditions faux).
func _t_trap_master_locks_rooms() -> void:
	var p0 := _player(0, "BMA001", [_room("BMA009", "trap", [1])])
	var G := _G([p0, _player(1, "BMA002")])
	(G["decks"]["roomDiscard"] as Array).append(_room("D", "trap", [1]))
	_ok.call(RoomAbilities.activate_room_ability(G.duplicate(true), 0, 0) == null, "sans Trap Master : Dark Altar s'active")
	var tm := _hero("KSA017")
	G["adventure"] = {"playerId": 0, "hero": tm, "roomIndex": 0, "hp": 13, "pause": null}
	_ok.call(BossEngine.abilities_locked(G, 0) and not BossEngine.abilities_locked(G, 1), "KSA017 : verrouille le donjon qu'il traverse")
	_ok.call(RoomAbilities.activate_room_ability(G, 0, 0) != null, "KSA017 : capacite activable refusee")
	# Bonus passifs de salles (Goblin Armory +1 aux Monster adjacents) ignores.
	var p2 := _player(0, "BMA001", [_room("M", "monster", [1], 2), _room("BMA015", "monster", [1], 1)])
	var G2 := _G([p2, _player(1, "BMA002")])
	_ok.call(BossEngine.room_damage_with_modifiers(G2, p2, 0, {}) == 3, "Goblin Armory : +1 sans Trap Master")
	G2["adventure"] = {"playerId": 0, "hero": tm, "roomIndex": 0, "hp": 13, "pause": null}
	_ok.call(BossEngine.room_damage_with_modifiers(G2, p2, 0, tm) == 2, "Goblin Armory verrouillee : pas de bonus")

## KSA016 Monster Hunter : HeroResistDamageRoomType(1, Monster), seulement si la salle inflige des degats.
func _t_monster_hunter_resists_monsters() -> void:
	var p0 := _player(0, "BMA001", [_room("M", "monster", [1], 3), _room("T", "trap", [1], 3), _room("Z", "monster", [1], 0)])
	var G := _G([p0, _player(1, "BMA002")])
	var mh := _hero("KSA016")
	_ok.call(BossEngine.room_damage_with_modifiers(G, p0, 0, mh) == 2, "KSA016 : Monster 3 -> 2")
	_ok.call(BossEngine.room_damage_with_modifiers(G, p0, 1, mh) == 3, "KSA016 : Trap inchange")
	_ok.call(BossEngine.room_damage_with_modifiers(G, p0, 2, mh) == 0, "KSA016 : salle a 0 degat : pas de soin")
	_ok.call(BossEngine.room_damage_with_modifiers(G, p0, 0, {}) == 3, "autre heros : Monster 3")

# --- ToolsHeroKind ---------------------------------------------------------------------------------------------

## data.json THK : toutes les capacites (salles, sort, objets) sont nulles ; l'APK ne charge d'ailleurs pas ce paquet (COMING SOON).
func _t_thk_inert() -> void:
	var exc := _card(CardDB.spells, "THK025")
	exc["isSpell"] = true
	_ok.call(not CardDB.can_play_spell(exc, "build") and not CardDB.can_play_spell(exc, "adventure"), "THK025 Excavation : injouable (Ability nulle)")
	var G := _G([_player(0, "BMA001", [_room("THK021", "monster", [2], 0)]), _player(1, "BMA002")])
	_ok.call(RoomAbilities.activate_room_ability(G, 0, 0) != null, "THK021 : aucune capacite activable")


# --- ecarts de l'IA de l'oracle (wide s5-p2, decks s1-p3) --------------------------------------------------------------------

## BMA047 Giant Size = RoomInDungeon[True,1,Any,Monster,Any] : GetAvailableTargets ne propose que des Monster. Mais l'IA de l'APK
## (AbilityCalculator.CheckBMA040And047) retient la liste de salles TRAP de sa branche « heros actif » pour les DEUX sorts et
## AbilitySelectedInformation / DealDamageToRoom ne revalident rien : l'oracle peut donc buffer une Trap. Le harnais l'ouvre par
## G.aiTargetsAnyRoomType (comme T.P.K. / aiTargetsAllBosses) ; un humain garde le ciblage Monster.
func _t_oracle_giant_size_any_room_type() -> void:
	var p0 := _player(0, "BMA001", [_room("T", "trap", [1], 2), _room("M", "monster", [1], 2)])
	var p1 := _player(1, "BMA002")
	var G := _G([p0, p1])
	var gs := _card(CardDB.spells, "BMA047")
	gs["isSpell"] = true
	_ok.call(SpellTargeting.spell_targets_for(G, p0, 0, "BMA047") == [{"targetPlayerId": 0, "roomIndex": 1}], "Giant Size (humain) : seule la salle Monster est ciblable")
	_ok.call(not SpellEffects.cast_spell(G, 0, gs, {"targetPlayerId": 0, "roomIndex": 0}) and _dmg(G, p0, 0) == 2, "Giant Size sans drapeau : refuse une Trap")
	G["aiTargetsAnyRoomType"] = true
	_ok.call(SpellTargeting.spell_targets_for(G, p0, 0, "BMA047").size() == 2, "Giant Size (IA de l'oracle) : les 2 salles sont ciblables")
	_ok.call(SpellEffects.cast_spell(G, 0, gs, {"targetPlayerId": 0, "roomIndex": 0}) and _dmg(G, p0, 0) == 5, "Giant Size (IA de l'oracle) sur une Trap : +3 degats, sans revalidation")

func _dmg(G: Dictionary, p: Dictionary, i: int) -> int:
	return BossEngine.room_damage_with_modifiers(G, p, i, {})

## BMA054 Trepidation (ForceSkipAdventure) : joue pendant la fenetre APRES la mort d'un heros (AdventurePhase_c -> _b, activeHero nul), ChooseNextActiveHero
## renvoie directement en AdventurePhase_a (aucun heros designe, donc rien a retirer) ; les heros restent a l'entree (oracle decks s1-p3).
## Joue avant la designation du premier heros, ProccessActiveHero retire le heros designe.
func _t_oracle_trepidation_after_hero() -> void:
	var tp := _card(CardDB.spells, "BMA054")
	tp["isSpell"] = true
	for after in [false, true]:
		var p0 := _player(0, "BMA001")
		(p0["entrance"] as Array).append_array([_hero("BMA056"), _hero("BMA062"), _hero("BMA068")])
		var p1 := _player(1, "BMA002")
		(p1["souls"] as Array).append_array([{"souls": 1}, {"souls": 1}])
		var G := _G([p0, p1])
		G["activePlayer"] = 0
		if after:
			G["afterHero"] = true
		SpellEffects.cast_spell(G, 1, tp, {"targetPlayerId": 0})
		var left: int = (p0["entrance"] as Array).size()
		_ok.call(left == (3 if after else 2), "Trepidation %s : %d heros restent a l'entree" % ["apres un heros (aucun designe)" if after else "avant le 1er heros (le designe est retire)", left])

## Sans heros, l'oracle ouvre quand meme les fenetres AdventurePhase_a/b : un joueur peut y activer une salle (Dark Altar, oracle wide s5-p2).
func _t_oracle_empty_adventure_window() -> void:
	var p0 := _player(0, "BMA001", [_room("BMA009", "trap", [1])])
	var G := _G([p0, _player(1, "BMA002")])
	G["phase"] = "adventure"
	(G["decks"]["heroes"] as Array).append(_hero("BMA056")) # pioche non epuisee : la fin de partie « heros epuises » ne s'applique pas
	var m := _match(G)
	_ok.call(not m._adventure_window_has_actions(), "sans heros ni action (defausse vide) : pas de fenetre")
	(G["decks"]["roomDiscard"] as Array).append(_room("D", "trap", [1]))
	_ok.call(m._adventure_window_has_actions(), "Dark Altar activable : fenetre ouverte")
	m._init_adventure_phase()
	_ok.call(str(G["phase"]) == "adventure" and G.get("gameOver") == null and m.legal_moves(0).any(func(mv): return str((mv as Dictionary)["type"]) == "activateRoom"), "sans heros : la phase reste ouverte (activateRoom disponible)")
	m.apply_move(0, {"type": "activateRoom", "args": [0]})
	m.apply_move(m.active_player(), {"type": "pass", "args": []}) # R-D67 : l'adversaire laisse passer la capacite (pile)
	m.apply_move(0, {"type": "pass", "args": []})
	m.apply_move(1, {"type": "pass", "args": []})
	_ok.call(int(G["turn"]) == 2 and str(G["phase"]) == "build", "les joueurs passent : le tour se termine normalement (tour 2)")
	m.queue_free()
