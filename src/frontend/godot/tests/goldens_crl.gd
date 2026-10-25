extends RefCounted
## Goldens de l'extension Crash Landing (CRL, 33 cartes : 3 boss, 13 salles, 5 sorts, 12 heros). Hors APK : references = rules.md
## (section « Crash Landing »), puis texte des cartes (wiki).
## Appele par goldens.gd : `load("res://godot/tests/goldens_crl.gd").new().run(_ok, self)`.

var _ok: Callable
var host: Node

func run(ok: Callable, h: Node) -> void:
	_ok = ok
	host = h
	_t_card_data()
	_t_new_match_deck()
	_t_explorer_lure()
	_t_crl_heroes_2_to_4()
	_t_big_game_setup()
	_t_big_game_bait_split()
	_t_big_game_no_elimination()
	_t_big_game_end_and_winner()
	_t_tie_break_xp_direction()
	_t_boss_imperiatrix()
	_t_boss_klonos()
	_t_boss_klonos_queues_choice()
	_t_boss_mando()
	_t_room_alien_excavator()
	_t_room_alien_ooze()
	_t_room_decoy_garden()
	_t_room_frostman_lander()
	_t_room_invasion_swarm()
	_t_room_reactor_core()
	_t_room_digicron_library()
	_t_room_hypercube()
	_t_room_omega_42()
	_t_room_omega_42_choices()
	_t_uncover_crash_site()
	_t_uncover_caged_gundarf()
	_t_uncover_caged_gundarf_modifiers()
	_t_uncover_celestial_map()
	_t_uncover_darkling_lair()
	_t_spell_finish_him()
	_t_spell_essence_transfer()
	_t_spell_healing_tank()
	_t_spell_meteorite()
	_t_spell_not_dead_yet()
	_t_end_of_game_stuck_town()
	_t_heroes_exhausted_end_not_in_apk_mode()
	_t_start_turn_clears_temporary_treasure()
	_t_ai_soak_crl_only()
	_t_heroes_prince_king()

# --- fabrique d'etats minimaux (meme style que goldens_decks.gd) ---------------------------------------------------

func _card(arr: Array, id: String) -> Dictionary:
	for c in arr:
		if str((c as Dictionary).get("id", "")) == id:
			return (c as Dictionary).duplicate(true)
	push_error("carte introuvable " + id)
	return {}

## Salle du jeu (donnees reelles de cards.json) prete a poser.
func _real(id: String) -> Dictionary:
	var r := _card(CardDB.rooms, id)
	r["isRoom"] = true
	return r

func _room(id: String, type: String, treasures: Array, damage: int = 1, advanced: bool = false) -> Dictionary:
	return {"id": id, "name": id, "type": type, "advanced": advanced, "treasures": treasures, "damage": damage, "isRoom": true}

func _spell(id: String) -> Dictionary:
	var s := _card(CardDB.spells, id)
	s["isSpell"] = true
	return s

func _hero(id: String) -> Dictionary:
	var h := _card(CardDB.heroes, id)
	h["souls"] = 2 if bool(h.get("epic", false)) else 1
	h["wounds"] = h["souls"]
	return h

## `dungeon` : une salle par pile, ou une pile (Array de salles, la derniere est le sommet).
func _player(pid: int, boss_id: String, dungeon: Array = []) -> Dictionary:
	var stacks: Array = []
	for r in dungeon:
		stacks.append((r as Array) if r is Array else [r])
	return {"id": pid, "boss": _card(CardDB.bosses, boss_id), "dungeon": stacks, "hand": [], "souls": [], "wounds": [],
		"entrance": [], "eliminated": false, "leveledUp": false, "buildsThisTurn": 0}

func _G(players: Array) -> Dictionary:
	var ps := {}
	for p in players:
		ps[int((p as Dictionary)["id"])] = p
	return {"players": ps, "town": [], "log": [], "logs": [], "adventure": {}, "turn": 1, "phase": "adventure", "sets": ["base", "crash-landing"],
		"effects": SpellEffects.empty_effects(),
		"decks": {"rooms": [], "spells": [], "heroes": [], "epics": [], "items": [], "roomDiscard": [], "spellDiscard": [], "heroDiscard": []}}

func _match(G: Dictionary) -> Node:
	var m = load("res://godot/scripts/Match.gd").new()
	host.add_child(m)
	m.G = G
	return m

func _stack_ids(p: Dictionary, i: int) -> Array:
	var out: Array = []
	for r in (p["dungeon"][i] as Array):
		out.append(str((r as Dictionary).get("id", "")))
	return out

func _dmg(G: Dictionary, p: Dictionary, i: int) -> int:
	return BossEngine.room_damage_with_modifiers(G, p, i, {})

# --- donnees et composition du paquet ------------------------------------------------------------------------------

func _count_set(arr: Array, set_id: String) -> int:
	var n := 0
	for c in arr:
		if str((c as Dictionary).get("set", "")) == set_id:
			n += 1 # la pioche contient deja une carte par exemplaire (expanded_deck)
	return n

func _t_card_data() -> void:
	var bosses: Array = CardDB.bosses.filter(func(c): return str((c as Dictionary).get("set", "")) == "crash-landing")
	var rooms: Array = CardDB.rooms.filter(func(c): return str((c as Dictionary).get("set", "")) == "crash-landing")
	var spells: Array = CardDB.spells.filter(func(c): return str((c as Dictionary).get("set", "")) == "crash-landing")
	var heroes: Array = CardDB.heroes.filter(func(c): return str((c as Dictionary).get("set", "")) == "crash-landing")
	_ok.call(bosses.size() == 3 and rooms.size() == 13 and spells.size() == 5 and heroes.size() == 12, "CRL : 3 boss, 13 salles, 5 sorts, 12 heros (33 cartes)")
	var every_boss_has_levelup := true
	for b in bosses:
		every_boss_has_levelup = every_boss_has_levelup and (b as Dictionary).get("levelUp") is Dictionary and (b["treasures"] as Array).size() == 1 and int(b["treasures"][0]) == 5
	_ok.call(every_boss_has_levelup, "CRL : chaque boss porte un level-up data-driven et le tresor Explorer")
	var explorers := heroes.filter(func(c): return int((c as Dictionary).get("treasure", 0)) == 5)
	_ok.call(explorers.size() == 10 and heroes.filter(func(c): return bool((c as Dictionary).get("epic", false))).size() == 5, "CRL : 10 Explorers + The Prince / The King (Cleric) ; 5 epiques")
	_ok.call(CardDB.TREASURE_NAMES[5] == "Explorer" and BossEngine.treasure_counts(_player(0, "CRL001")).get(5, -1) == 1, "treasure_counts compte le tresor Explorer (le boss CRL001 en porte un)")

## Match.new_match : `crash-landing` ajoute ses cartes aux pioches du jeu de base (jeu de base toujours present, tailles de heros des 2-4 joueurs).
func _t_new_match_deck() -> void:
	var m = load("res://godot/scripts/Match.gd").new()
	host.add_child(m)
	var base: Dictionary = m.new_match(2, 1, ["base"])
	var base_rooms: int = (base["decks"]["rooms"] as Array).size()
	var base_spells: int = (base["decks"]["spells"] as Array).size()
	var crl: Dictionary = m.new_match(2, 1, ["crash-landing"])
	var rooms: Array = crl["decks"]["rooms"]
	var spells: Array = crl["decks"]["spells"]
	_ok.call(rooms.size() == base_rooms + 23 and _count_set(rooms, "crash-landing") == 23, "CRL : 23 exemplaires de salles ajoutes a la pioche")
	_ok.call(spells.size() == base_spells + 7 and _count_set(spells, "crash-landing") == 7, "CRL : 7 exemplaires de sorts ajoutes a la pioche")
	_ok.call(crl["sets"].has("crash-landing") and crl["sets"].has("base"), "G.sets garde les paquets choisis (+ le jeu de base)")
	_ok.call((crl["decks"]["heroes"] as Array).size() == 20 and (crl["decks"]["epics"] as Array).size() == 13, "CRL 2 joueurs : 13 + 8 heros de base (icones de 2 joueurs) + 7 + 5 heros CRL")
	var found_crl_boss := false
	for i in 3: # tous les boss du paquet sont proposes
		var picks: Array = (m.new_match(2, 1, ["crash-landing"]))["bossPicks"]
		for b in picks:
			found_crl_boss = found_crl_boss or str((b as Dictionary).get("id", "")).begins_with("CRL")
	_ok.call(found_crl_boss, "CRL : ses boss entrent dans les propositions de boss")
	m.queue_free()

## Les Explorers (tresor 5) vont chez le joueur qui a le plus de tresor Explorer ; egalite = ils restent en ville.
func _t_explorer_lure() -> void:
	var p0 := _player(0, "CRL001", [_room("A", "trap", [5, 5]), _room("B", "trap", [1])])
	var p1 := _player(1, "BMA001", [_room("C", "trap", [5])])
	var G := _G([p0, p1])
	var explorer := _hero("CRL019")
	_ok.call(int(explorer["treasure"]) == 5 and BossEngine.lure_target(G["players"], [0, 1], 5, explorer, G) == 0, "Explorer : chez le plus de tresors Explorer (3 contre 1)")
	(p1["dungeon"] as Array).append([_room("D", "trap", [5, 5])])
	_ok.call(BossEngine.lure_target(G["players"], [0, 1], 5, explorer, G) == -1, "Explorer : egalite 3 - 3, reste en ville")
	var p2 := _player(0, "BMA001", [_room("A", "trap", [1])])
	var p3 := _player(1, "BMA002", [_room("B", "trap", [1])])
	var G2 := _G([p2, p3])
	G2["town"] = [_hero("CRL019"), _hero("CRL018")]
	var m := _match(G2)
	m._resolve_bait()
	_ok.call((G2["town"] as Array).size() == 2 and (G2["luredThisTurn"] as Dictionary).is_empty(), "sans tresor Explorer : les 2 Explorers restent en ville, aucun leurre compte")
	(p3["dungeon"] as Array).append([_room("E", "trap", [5])])
	m._resolve_bait()
	_ok.call((G2["town"] as Array).is_empty() and (p3["entrance"] as Array).size() == 2 and int(G2["luredThisTurn"][1]) == 2, "un seul donjon avec des Explorers : ils y vont tous les 2 (luredThisTurn[1] = 2)")
	m.queue_free()

## Heros CRL en 2-4 joueurs (livret : « remove all cards with the Three/Four player icons » ; seule l'icone « Five and six players (with Crash Landing) »
## porte les heros CRL, que cette regle ne retire pas) : le paquet de base est filtre par icone (13/8, 17/12, 25/16) et TOUS les heros CRL s'y ajoutent.
func _t_crl_heroes_2_to_4() -> void:
	var m = load("res://godot/scripts/Match.gd").new()
	host.add_child(m)
	for n in [2, 3, 4]:
		var G: Dictionary = m.new_match(n, 1, ["crash-landing"])
		var heroes: Array = G["decks"]["heroes"]
		var epics: Array = G["decks"]["epics"]
		var base_o: int = int(CardDB.HERO_COUNTS[n]["ordinary"])
		var base_e: int = int(CardDB.HERO_COUNTS[n]["epic"])
		_ok.call(heroes.size() == base_o + 7 and epics.size() == base_e + 5, "CRL %d joueurs : %d + %d heros (base filtre par icone + 12 heros CRL)" % [n, base_o + 7, base_e + 5])
		var too_big := 0
		for h in heroes + epics:
			if str((h as Dictionary).get("set", "")) != "crash-landing" and int((h as Dictionary).get("playerCount", 2)) > n:
				too_big += 1
		_ok.call(too_big == 0, "CRL %d joueurs : aucun heros d'icone superieure a %d joueurs" % [n, n])
		_ok.call(_count_set(heroes, "crash-landing") == 7 and _count_set(epics, "crash-landing") == 5, "CRL %d joueurs : les 12 heros CRL sont tous la" % n)
	m.queue_free()

## 5-6 joueurs : plafond selon les paquets, pool exact 32 + 21, 3 objets par tour, paquets non pris en charge ecartes / refuses.
func _t_big_game_setup() -> void:
	var m = load("res://godot/scripts/Match.gd").new()
	host.add_child(m)
	_ok.call(m.max_players(["base"]) == 4 and m.max_players(["crash-landing"]) == 6, "plafond : 4 joueurs, 6 avec Crash Landing")
	_ok.call(m.setup_error(6, ["crash-landing"]) == "" and m.setup_error(5, ["crash-landing", "tools", "hidden-heroes"]) == "" and m.setup_error(4, ["next-level"]) == "",
		"setup_error : 5-6 avec CRL (+ Tools / Hidden Heroes) accepte, 2-4 toujours accepte")
	_ok.call(m.setup_error(5, ["base"]) != "" and m.setup_error(6, []) != "" and m.setup_error(5, ["crash-landing", "next-level"]) != ""
		and m.setup_error(5, ["crash-landing", "minibosses"]) != "" and m.setup_error(5, ["crash-landing", "players-choice"]) != "" and m.setup_error(5, ["crash-landing", "iod"]) != ""
		and m.setup_error(5, ["crash-landing", "tools-wiki"]) != "" and m.setup_error(5, ["crash-landing", "players-choice-wiki"]) != "",
		"setup_error : 5-6 sans CRL, ou avec TNL / Minibosses / Player's Choice / IOD / THK wiki, refuse")
	_ok.call(CardDB.HERO_COUNTS[5] == {"ordinary": 32, "epic": 21} and CardDB.HERO_COUNTS[6] == {"ordinary": 32, "epic": 21}, "HERO_COUNTS : 32 + 21 heros a 5 et 6 joueurs")
	for n in [5, 6]:
		for sets in [["crash-landing"], ["crash-landing", "hidden-heroes"], ["crash-landing", "tools"]]:
			var G: Dictionary = m.new_match(n, 1, sets)
			var heroes: Array = G["decks"]["heroes"]
			var epics: Array = G["decks"]["epics"]
			_ok.call(int(G["numPlayers"]) == n and (G["players"] as Dictionary).size() == n, "%d joueurs %s : %d sieges" % [n, str(sets), n])
			_ok.call(heroes.size() == 32 and epics.size() == 21, "%d joueurs %s : 32 + 21 heros (obtenu %d + %d)" % [n, str(sets), heroes.size(), epics.size()])
			var ids := {}
			for h in heroes + epics:
				ids[str((h as Dictionary)["id"])] = true
			_ok.call(ids.size() == 53, "%d joueurs %s : 53 heros tous differents" % [n, str(sets)])
			_ok.call(_count_set(heroes + epics, "crash-landing") == 12 and _count_set(heroes + epics, "players-choice") == 0, "%d joueurs %s : les 12 heros CRL, aucun Player's Choice" % [n, str(sets)])
			_ok.call((G["bossPicks"] as Array).size() >= n, "%d joueurs %s : assez de boss proposes (%d)" % [n, str(sets), (G["bossPicks"] as Array).size()])
	# paquets non pris en charge ecartes (Match ne plante jamais) ; 5 joueurs sans CRL : repli a 4.
	var G2: Dictionary = m.new_match(6, 1, ["crash-landing", "next-level", "minibosses", "players-choice"])
	_ok.call(not (G2["sets"] as Array).has("next-level") and not (G2["sets"] as Array).has("minibosses") and not (G2["sets"] as Array).has("players-choice")
		and (G2["decks"]["heroes"] as Array).size() == 32 and (G2["decks"]["epics"] as Array).size() == 21, "6 joueurs + TNL / RMB / PC : ecartes, pool 32 + 21")
	var G3: Dictionary = m.new_match(5, 1, ["base"])
	_ok.call(int(G3["numPlayers"]) == 4, "5 joueurs sans CRL : repli a 4 (le serveur refuse avant)")
	# objets : 1 (2-3 joueurs), 2 (4), 3 (5-6)
	for n in [2, 3, 4, 5, 6]:
		m.new_match(n, 1, ["crash-landing", "tools"] if n >= 5 else ["tools"])
		m._reveal_items()
		var want := 3 if n >= 5 else (2 if n == 4 else 1)
		_ok.call((m.G["itemQueue"] as Array).size() == want and (m.G["decks"]["items"] as Array).size() == 20 - want, "%d joueurs : %d objet(s) revele(s) par tour" % [n, want])
	# heros reveles : un par joueur
	m.new_match(6, 1, ["crash-landing"])
	m._reveal_heroes_in_town()
	_ok.call((m.G["town"] as Array).size() == 6, "6 joueurs : 6 heros reveles par tour")
	m.queue_free()

func _big_players(n: int, xps: Array) -> Array:
	var out: Array = []
	for i in n:
		var p := _player(i, "BMA001")
		(p["boss"] as Dictionary)["xp"] = int(xps[i])
		out.append(p)
	return out

func _big_G(players: Array) -> Dictionary:
	var G := _G(players)
	G["numPlayers"] = players.size()
	return G

func _tagged(id: String, tag: int) -> Dictionary:
	var h := _hero(id)
	h["tag"] = tag
	return h

func _tags(arr: Array) -> Array:
	return arr.map(func(h): return int((h as Dictionary).get("tag", -1)))

## Livret CRL (exemple) : 3 joueurs ont chacun 2 tresors Explorer, 7 Explorers en ville : chacun en leurre 2 (par XP, le plus ancien au plus haut XP) ; le dernier arrive reste.
func _t_big_game_bait_split() -> void:
	var ps := _big_players(5, [100, 300, 200, 50, 40])
	for i in 3:
		(ps[i]["dungeon"] as Array).append([_room("A%d" % i, "trap", [5, 5])])
	var G := _big_G(ps)
	var ids := ["CRL018", "CRL019", "CRL020", "CRL021", "CRL022", "CRL023", "CRL019"]
	for i in ids.size():
		(G["town"] as Array).append(_tagged(ids[i], i))
	var m := _match(G)
	m._resolve_bait()
	# ordre d'XP des ex aequo : joueur 1 (300), 2 (200), 0 (100) ; les heros 0..5 leur vont a tour de role, du plus ancien au plus recent
	_ok.call(_tags(ps[1]["entrance"]) == [0, 3] and _tags(ps[2]["entrance"]) == [1, 4] and _tags(ps[0]["entrance"]) == [2, 5], "exemple du livret : 3 ex aequo, 7 Explorers = 2 chacun, par XP decroissante (obtenu %s %s %s)" % [str(_tags(ps[1]["entrance"])), str(_tags(ps[2]["entrance"])), str(_tags(ps[0]["entrance"]))])
	_ok.call(_tags(G["town"]) == [6] and (ps[3]["entrance"] as Array).is_empty() and (ps[4]["entrance"] as Array).is_empty(), "exemple du livret : le dernier Explorer arrive reste en ville")
	_ok.call(int(G["luredThisTurn"][0]) == 2 and int(G["luredThisTurn"][1]) == 2 and int(G["luredThisTurn"][2]) == 2, "luredThisTurn compte 2 heros par joueur a egalite")
	m.queue_free()
	# moins de heros que d'ex aequo : tous restent en ville ; puis un seul gagnant : tout lui revient
	var ps2 := _big_players(5, [100, 300, 200, 50, 40])
	(ps2[0]["dungeon"] as Array).append([_room("A", "trap", [5])])
	(ps2[1]["dungeon"] as Array).append([_room("B", "trap", [5])])
	(ps2[2]["dungeon"] as Array).append([_room("C", "trap", [5])])
	var G2 := _big_G(ps2)
	G2["town"] = [_tagged("CRL018", 0), _tagged("CRL019", 1)]
	var m2 := _match(G2)
	m2._resolve_bait()
	_ok.call((G2["town"] as Array).size() == 2 and (G2["luredThisTurn"] as Dictionary).is_empty(), "3 ex aequo mais 2 Explorers : le partage est impossible, tous restent en ville")
	G2["town"] = [_tagged("CRL018", 0), _tagged("CRL019", 1), _tagged("CRL020", 2), _tagged("CRL021", 3), _tagged("CRL022", 4)]
	(ps2[2]["dungeon"] as Array).append([_room("D", "trap", [5, 5])]) # le joueur 2 passe a 3 tresors Explorer : seul gagnant
	m2._resolve_bait()
	_ok.call((G2["town"] as Array).is_empty() and (ps2[2]["entrance"] as Array).size() == 5, "un seul gagnant en 5-6 : tous les Explorers vont chez lui")
	m2.queue_free()
	# personne n'a de tresor du type (tous a 0) : le heros reste en ville
	var ps3 := _big_players(6, [100, 300, 200, 50, 40, 10])
	var G3 := _big_G(ps3)
	G3["town"] = [_tagged("CRL018", 0)]
	for i in 6:
		(ps3[i]["dungeon"] as Array).append([_room("Z%d" % i, "trap", [1 + i % 2])]) # aucun tresor Explorer
	var m3 := _match(G3)
	m3._resolve_bait()
	_ok.call((G3["town"] as Array).size() == 1, "personne n'a de tresor Explorer (tous a 0) : le heros reste en ville, pas de partage")
	m3.queue_free()
	# deux types disputes en meme temps (Explorer entre P0 et P1, Cleric entre P0 et P2), epique compris dans le meme type : partages separes
	var ps4 := _big_players(5, [100, 300, 200, 50, 40])
	(ps4[0]["dungeon"] as Array).append([_room("A", "trap", [5, 1])])
	(ps4[1]["dungeon"] as Array).append([_room("B", "trap", [5])])
	(ps4[2]["dungeon"] as Array).append([_room("C", "trap", [1])])
	var G4 := _big_G(ps4)
	G4["town"] = [_tagged("CRL018", 0), _tagged("BMA056", 1), _tagged("CRL024", 2), _tagged("BMA056", 3), _tagged("CRL019", 4), _tagged("BMA056", 5)]
	var m4 := _match(G4)
	m4._resolve_bait()
	# Explorers 0, 2, 4 : P1 (300) puis P0 (100), 1 chacun, le plus recent (4) reste ; Clerics 1, 3, 5 : P2 (200) puis P0 (100), le 5 reste
	_ok.call(_tags(ps4[1]["entrance"]) == [0] and _tags(ps4[0]["entrance"]) == [2, 3] and _tags(ps4[2]["entrance"]) == [1] and _tags(G4["town"]) == [4, 5], "deux types a egalite : partages separes, un heros de chaque type reste (obtenu %s %s %s ville %s)" % [str(_tags(ps4[1]["entrance"])), str(_tags(ps4[0]["entrance"])), str(_tags(ps4[2]["entrance"])), str(_tags(G4["town"]))])
	m4.queue_free()
	# 2-4 joueurs (et partie montee a la main sans numPlayers) : l'egalite laisse toujours le heros en ville
	var ps5 := _big_players(4, [100, 300, 200, 50])
	(ps5[0]["dungeon"] as Array).append([_room("A", "trap", [5])])
	(ps5[1]["dungeon"] as Array).append([_room("B", "trap", [5])])
	var G5 := _G(ps5)
	G5["numPlayers"] = 4
	G5["town"] = [_tagged("CRL018", 0), _tagged("CRL019", 1)]
	var m5 := _match(G5)
	m5._resolve_bait()
	_ok.call((G5["town"] as Array).size() == 2 and (G5["luredThisTurn"] as Dictionary).is_empty(), "4 joueurs avec CRL : l'egalite laisse les heros en ville (pas de partage)")
	m5.queue_free()

## 5-6 joueurs : aucune elimination ; 2-4 joueurs avec CRL : 5 blessures eliminent toujours.
func _t_big_game_no_elimination() -> void:
	var ps := _big_players(5, [100, 300, 200, 50, 40])
	var G := _big_G(ps)
	for i in 10:
		(G["decks"]["rooms"] as Array).append(_room("r%d" % i, "trap", [1]))
		(G["decks"]["heroes"] as Array).append(_hero("CRL019"))
	G["phase"] = "end"
	ps[0]["wounds"] = _wounds(5)
	ps[1]["wounds"] = _wounds(7)
	var m := _match(G)
	m._check_end_or_next_turn()
	_ok.call(G.get("gameOver") == null and not bool(ps[0]["eliminated"]) and not bool(ps[1]["eliminated"]), "5 joueurs : 5 ou 7 blessures n'eliminent personne, la partie continue")
	_ok.call(int(G["turn"]) == 2, "5 joueurs : le tour suivant demarre")
	# un heros qui survit ajoute sa blessure sans eliminer
	var hero := _hero("CRL019")
	(ps[0]["entrance"] as Array).append(hero)
	m._finish_hero(0, hero, 2, {})
	_ok.call(not bool(ps[0]["eliminated"]) and CardDB.total_wounds(ps[0]) >= 6, "5 joueurs : un heros survivant blesse sans eliminer (blessures %d)" % CardDB.total_wounds(ps[0]))
	m.queue_free()
	# 4 joueurs avec CRL : elimination inchangee
	var ps4 := _big_players(4, [100, 300, 200, 50])
	var G4 := _G(ps4)
	G4["numPlayers"] = 4
	G4["phase"] = "end"
	ps4[0]["wounds"] = _wounds(5)
	var m4 := _match(G4)
	m4._check_end_or_next_turn()
	_ok.call(bool(ps4[0]["eliminated"]), "4 joueurs avec CRL : 5 blessures eliminent toujours")
	m4.queue_free()
	var ps4b := _big_players(4, [100, 300, 200, 50])
	ps4b[1]["wounds"] = _wounds(4)
	var G4b := _G(ps4b)
	G4b["numPlayers"] = 4
	var m4b := _match(G4b)
	var hero4 := _hero("CRL019")
	(ps4b[1]["entrance"] as Array).append(hero4)
	m4b._finish_hero(1, hero4, 2, {})
	_ok.call(bool(ps4b[1]["eliminated"]), "4 joueurs avec CRL : la 5e blessure d'un heros survivant elimine toujours")
	m4b.queue_free()

func _souls(n: int) -> Array:
	var a: Array = []
	for i in n:
		a.append({"souls": 1})
	return a

func _wounds(n: int) -> Array:
	var a: Array = []
	for i in n:
		a.append({"wounds": 1})
	return a

## 5-6 joueurs : fin de partie quand un joueur a 10 ames (fin de tour) ou quand les deux pioches de heros sont vides (heros encore en ville ou a l'entree) ;
## gagnant = meilleur (ames - blessures) parmi TOUS les joueurs (meme sans 10 ames, meme avec beaucoup de blessures), a egalite l'XP la plus basse.
func _t_big_game_end_and_winner() -> void:
	var ps := _big_players(6, [100, 300, 200, 50, 40, 10])
	var G := _big_G(ps)
	G["phase"] = "end"
	for i in 10:
		(G["decks"]["rooms"] as Array).append(_room("r%d" % i, "trap", [1]))
		(G["decks"]["heroes"] as Array).append(_hero("CRL019"))
	ps[0]["souls"] = _souls(10) # 10 ames mais 6 blessures : 4 net ; ne gagne pas
	ps[0]["wounds"] = _wounds(6)
	ps[1]["souls"] = _souls(9) # 9 - 1 = 8
	ps[1]["wounds"] = _wounds(1)
	ps[2]["souls"] = _souls(5)
	var m := _match(G)
	m._check_end_or_next_turn()
	var go = G.get("gameOver")
	_ok.call(go != null and int(go["winner"]) == 1 and str(go["reason"]) == "10 âmes", "6 joueurs : 10 ames chez P0 (4 net) mais P1 a 8 net : P1 gagne")
	m.queue_free()
	# egalite d'ames - blessures : l'XP la plus basse gagne (P4 xp 40 contre P3 xp 50)
	var ps2 := _big_players(5, [100, 300, 200, 50, 40])
	var G2 := _big_G(ps2)
	G2["phase"] = "end"
	for i in [0, 1, 3, 4]:
		ps2[i]["souls"] = _souls(10)
	var m2 := _match(G2)
	m2._check_end_or_next_turn()
	_ok.call(G2.get("gameOver") != null and int(G2["gameOver"]["winner"]) == 4, "5 joueurs : egalite 10 - 0, l'XP la plus BASSE (40) gagne")
	m2.queue_free()
	# pioches de heros vides : fin meme avec des heros en ville / a l'entree et sans 10 ames
	var ps3 := _big_players(5, [100, 300, 200, 50, 40])
	var G3 := _big_G(ps3)
	G3["phase"] = "end"
	G3["town"] = [_hero("CRL019")]
	(ps3[2]["entrance"] as Array).append(_hero("CRL018"))
	ps3[2]["souls"] = _souls(4)
	ps3[3]["souls"] = _souls(3)
	ps3[3]["wounds"] = _wounds(9) # beaucoup de blessures, jamais elimine
	var m3 := _match(G3)
	m3._check_end_or_next_turn()
	_ok.call(G3.get("gameOver") != null and int(G3["gameOver"]["winner"]) == 2 and str(G3["gameOver"]["reason"]) == "héros épuisés", "5 joueurs : pioches de heros vides, heros restants en ville / a l'entree : fin, P2 (4) gagne")
	m3.queue_free()
	# une pioche non vide : la partie continue
	var ps4 := _big_players(5, [100, 300, 200, 50, 40])
	var G4 := _big_G(ps4)
	G4["phase"] = "end"
	(G4["decks"]["epics"] as Array).append(_hero("CRL024"))
	for i in 10:
		(G4["decks"]["rooms"] as Array).append(_room("r%d" % i, "trap", [1]))
	var m4 := _match(G4)
	m4._check_end_or_next_turn()
	_ok.call(G4.get("gameOver") == null, "5 joueurs : une pioche d'epiques non vide, la partie continue")
	m4.queue_free()

## Egalite : 2-4 joueurs = XP la plus HAUTE (APK, inchange) ; 5-6 joueurs = XP la plus BASSE (livret CRL).
func _t_tie_break_xp_direction() -> void:
	var ps := _big_players(4, [100, 300, 200, 50])
	var m := _match(_G(ps))
	_ok.call(m._tie_break_players([0, 1, 2, 3]) == 1, "2-4 joueurs : a egalite, l'XP la plus haute gagne (APK)")
	_ok.call(m._tie_break_players([0, 1, 2, 3], true) == 3, "5-6 joueurs : a egalite, l'XP la plus basse gagne (livret CRL)")
	m.queue_free()

# --- boss --------------------------------------------------------------------------------------------------------

## CRL001 Imperiatrix : +1 degat par tresor Explorer de chaque salle, une fois montee de niveau (JS : +1 par icone).
func _t_boss_imperiatrix() -> void:
	var p0 := _player(0, "CRL001", [_room("X", "trap", [5, 5], 2), _room("Y", "trap", [1], 2)])
	var G := _G([p0, _player(1, "BMA001")])
	_ok.call(RoomAbilities.process_level_up(G, 0) == null, "CRL001 : level-up sans choix (passif)")
	_ok.call(_dmg(G, p0, 0) == 2, "CRL001 avant le level-up : aucun bonus")
	p0["leveledUp"] = true
	_ok.call(_dmg(G, p0, 0) == 4 and _dmg(G, p0, 1) == 2, "CRL001 : +2 pour deux icones Explorer, 0 pour une salle sans Explorer")
	(p0["dungeon"][1][0] as Dictionary)["extraTreasures"] = [5]
	_ok.call(_dmg(G, p0, 1) == 3, "CRL001 : un tresor Explorer gagne jusqu'a la fin du tour compte aussi")

## CRL002 Klonos : copie le level-up d'un AUTRE boss (passifs conserves pour la partie, effets joues tout de suite).
func _t_boss_klonos() -> void:
	var p0 := _player(0, "CRL002")
	var p1 := _player(1, "KSA006") # Jarin : AddSoulsToBoss(1)
	var G := _G([p0, p1])
	_ok.call(RoomAbilities.process_level_up(G, 0) == null, "CRL002 : un seul boss a copier = copie automatique")
	p0["leveledUp"] = true
	_ok.call((p0["copiedLevelUps"] as Array).size() == 1 and CardDB.total_souls(p0, G) == 1, "CRL002 copie Jarin : +1 ame (passif)")
	p1["eliminated"] = true
	_ok.call(CardDB.total_souls(p0, G) == 1, "CRL002 : la capacite reste meme si le boss copie disparait")
	# Plusieurs boss en jeu : on choisit lequel copier.
	var q0 := _player(0, "CRL002", [_room("A", "trap", [1]), _room("B", "trap", [1]), _room("C", "trap", [1])])
	var q1 := _player(1, "KSA005") # Scythe : LastRoomDealDamage(3)
	var q2 := _player(2, "KSA006")
	var G2 := _G([q0, q1, q2])
	var c = RoomAbilities.process_level_up(G2, 0)
	_ok.call(c != null and str(c["type"]) == "pick-boss-levelup" and (c["options"] as Array).size() == 2, "CRL002 : choix entre les 2 autres boss")
	var m := _match(G2)
	G2["pendingChoice"] = c
	m._resolve_choice(0, 0) # Scythe
	q0["leveledUp"] = true
	_ok.call((G2["pendingChoice"] as Dictionary).is_empty() and _dmg(G2, q0, 2) == 4 and _dmg(G2, q0, 0) == 1, "CRL002 copie Scythe : +3 a la derniere salle")
	m.queue_free()
	# Deux Klonos : aucun boss copiable.
	var G3 := _G([_player(0, "CRL002"), _player(1, "CRL002")])
	_ok.call(RoomAbilities.process_level_up(G3, 0) == null and (G3["players"][0] as Dictionary).get("copiedLevelUps", []).is_empty(), "CRL002 ne copie pas Klonos")

## La capacite copiee ouvre son propre choix (JS : Klonos copie Mirrax -> pick-boss-treasure ; ici KSA003 Brothers Wise).
func _t_boss_klonos_queues_choice() -> void:
	var p0 := _player(0, "CRL002")
	var p1 := _player(1, "KSA003")
	var p2 := _player(2, "KSA006")
	var G := _G([p0, p1, p2])
	for i in 3:
		(G["decks"]["spells"] as Array).append({"id": "S%d" % i, "name": "S%d" % i, "isSpell": true})
	var m := _match(G)
	G["pendingChoice"] = RoomAbilities.process_level_up(G, 0)
	m._resolve_choice(0, 0) # Brothers Wise
	var pc: Dictionary = G["pendingChoice"]
	_ok.call(str(pc.get("type", "")) == "search-spell" and (pc["options"] as Array).size() == 3, "CRL002 : le choix de la capacite copiee enchaine")
	m._resolve_choice(0, 1)
	_ok.call((G["pendingChoice"] as Dictionary).is_empty() and (p0["hand"] as Array).size() == 1, "CRL002 : copie resolue, sort en main")
	m.queue_free()

## CRL003 Mando : « may » remonter une salle couverte au sommet de la pile de CHAQUE adversaire.
func _t_boss_mando() -> void:
	var p0 := _player(0, "CRL003")
	var p1 := _player(1, "BMA001", [[_room("cov", "monster", [3], 4), _room("top", "trap", [1])]])
	var G := _G([p0, p1])
	var c = RoomAbilities.process_level_up(G, 0)
	_ok.call(c != null and str(c["type"]) == "uncover-room" and bool(c["optional"]) and (c["options"] as Array).size() == 1, "CRL003 : choix facultatif parmi les salles couvertes adverses")
	var m := _match(G)
	G["pendingChoice"] = c
	m._resolve_choice(0, 0)
	_ok.call(_stack_ids(p1, 0) == ["top", "cov"] and (G["pendingChoice"] as Dictionary).is_empty(), "CRL003 : la salle couverte passe au sommet")
	# Sans salle couverte : rien a faire.
	var G2 := _G([_player(0, "CRL003"), _player(1, "BMA001", [_room("only", "trap", [1])])])
	_ok.call(RoomAbilities.process_level_up(G2, 0) == null, "CRL003 : aucune salle couverte, capacite ignoree")
	# Trois joueurs : un choix par adversaire (file), on peut passer pour l'un d'eux.
	var q1 := _player(1, "BMA001", [[_room("c1", "trap", [1]), _room("t1", "trap", [1])]])
	var q2 := _player(2, "BMA002", [[_room("c2", "trap", [1]), _room("t2", "trap", [1])]])
	var G3 := _G([_player(0, "CRL003"), q1, q2])
	var m3 := _match(G3)
	G3["pendingChoice"] = RoomAbilities.process_level_up(G3, 0)
	_ok.call(int(G3["pendingChoice"]["options"][0]["targetPlayerId"]) == 1, "CRL003 : le premier adversaire (PlayerId croissant)")
	m3._resolve_choice(0, 0)
	_ok.call(str(G3["pendingChoice"].get("type", "")) == "uncover-room" and int(G3["pendingChoice"]["options"][0]["targetPlayerId"]) == 2, "CRL003 : puis le suivant")
	m3._resolve_choice(0, -1) # passer
	_ok.call(_stack_ids(q1, 0) == ["t1", "c1"] and _stack_ids(q2, 0) == ["c2", "t2"] and (G3["pendingChoice"] as Dictionary).is_empty(), "CRL003 : un seul adversaire touche (le 2e passe)")
	m.queue_free()
	m3.queue_free()

# --- salles ------------------------------------------------------------------------------------------------------

## CRL004 Alien Excavator : « may » remonter une salle couverte de son propre donjon (elle est decouverte).
func _t_room_alien_excavator() -> void:
	var excavator := _real("CRL004")
	var p0 := _player(0, "BMA001", [[_real("CRL014"), excavator]])
	var G := _G([p0, _player(1, "BMA002")])
	var c = RoomAbilities.on_build_room(G, 0, excavator)
	_ok.call(c != null and str(c["type"]) == "uncover-own-room" and bool(c["optional"]) and (c["options"] as Array).size() == 1, "CRL004 : choix facultatif de la salle couverte")
	var m := _match(G)
	G["pendingChoice"] = c
	m._resolve_choice(0, 0)
	_ok.call(_stack_ids(p0, 0) == ["CRL004", "CRL014"], "CRL004 : Caged Gundarf remonte au sommet")
	_ok.call(_dmg(G, p0, 0) == 2, "CRL004 : la salle decouverte declenche son effet (Caged Gundarf : degats doubles)")
	var p1 := _player(0, "BMA001", [[_real("CRL014"), _real("CRL004")]])
	var G2 := _G([p1, _player(1, "BMA002")])
	var m2 := _match(G2)
	G2["pendingChoice"] = RoomAbilities.on_build_room(G2, 0, p1["dungeon"][0][1])
	m2._resolve_choice(0, -1)
	_ok.call(_stack_ids(p1, 0) == ["CRL014", "CRL004"], "CRL004 : on peut refuser")
	var G3 := _G([_player(0, "BMA001", [_real("CRL004")]), _player(1, "BMA002")])
	_ok.call(RoomAbilities.on_build_room(G3, 0, G3["players"][0]["dungeon"][0][0]) == null, "CRL004 : sans salle couverte, rien")
	m.queue_free()
	m2.queue_free()

## CRL005 Alien Ooze : +1 s'il y a une AUTRE salle au tresor Explorer dans le donjon.
func _t_room_alien_ooze() -> void:
	var p0 := _player(0, "BMA001", [_real("CRL005")])
	var G := _G([p0, _player(1, "BMA002")])
	_ok.call(_dmg(G, p0, 0) == 1, "CRL005 seule : degats de base")
	(p0["dungeon"] as Array).append([_room("plain", "trap", [1])])
	_ok.call(_dmg(G, p0, 0) == 1, "CRL005 avec une salle sans Explorer : pas de bonus")
	(p0["dungeon"] as Array).append([_room("alien", "trap", [1, 5])])
	_ok.call(_dmg(G, p0, 0) == 2, "CRL005 avec une autre salle Explorer : +1")
	_ok.call(_dmg(G, p0, 2) == 1, "CRL005 : l'autre salle ne gagne rien")
	(G["effects"]["deactivatedRooms"] as Array).append({"playerId": 0, "roomIndex": 2})
	_ok.call(_dmg(G, p0, 0) == 1, "CRL005 : une salle gelee n'est pas comptee")
	(G["effects"]["deactivatedRooms"] as Array).clear()
	var q0 := _player(0, "CRL001", [_real("CRL005")]) # le boss Explorer n'est pas une salle
	_ok.call(_dmg(_G([q0, _player(1, "BMA002")]), q0, 0) == 1, "CRL005 : un boss n'est pas une salle (regle du texte)")

## CRL006 Decoy Garden : a la construction, Explorer x2 jusqu'a la fin du tour (expire au debut du tour suivant).
func _t_room_decoy_garden() -> void:
	var garden := _real("CRL006")
	var p0 := _player(0, "BMA001", [garden])
	var G := _G([p0, _player(1, "BMA002")])
	_ok.call(BossEngine.treasure_count(p0, 5, G) == 1, "CRL006 avant construction : son Explorer imprime")
	RoomAbilities.on_build_room(G, 0, garden)
	_ok.call(BossEngine.treasure_count(p0, 5, G) == 3, "CRL006 : Explorer x2 en plus (3 au total)")
	var discard := garden.duplicate()
	BossEngine.discard_room_to_pile(G["decks"], discard)
	_ok.call(not discard.has("extraTreasures"), "CRL006 : defaussee, la salle perd ses tresors temporaires")
	# The Omega 42 rejoue « when you build this Room » : la salle gagne Explorer*2 de nouveau (cumul), l'effet n'ecrase plus le precedent
	var garden2 := _real("CRL006")
	var q0 := _player(0, "BMA001", [garden2])
	(q0["hand"] as Array).append(_room("adv", "monster", [2], 3, true))
	var G2 := _G([q0, _player(1, "BMA002")])
	RoomAbilities.on_build_room(G2, 0, garden2)
	RoomAbilities.omega_finish(G2, 0, {"roomIndex": 0, "mode": "build"}, 0)
	_ok.call(BossEngine.treasure_count(q0, 5, G2) == 5 and (garden2["extraTreasures"] as Array).size() == 4, "CRL006 rejoue par The Omega 42 : Explorer*2 de plus (1 imprime + 4 = 5), pas de remplacement")

## CRL007 Frostman Lander : defausse depuis la main -> une salle avancee (n'importe quel donjon) desactivee jusqu'a la fin du tour.
func _t_room_frostman_lander() -> void:
	var p0 := _player(0, "BMA001")
	(p0["hand"] as Array).append(_real("CRL007"))
	var adv := _room("adv", "monster", [3], 5, true)
	var p1 := _player(1, "BMA002", [adv, _room("ord", "monster", [3], 2)])
	var G := _G([p0, p1])
	G["phase"] = "build"
	G["activePlayer"] = 0
	G["buildOrder"] = [0, 1]
	G["buildIndex"] = 0
	var m := _match(G)
	var moves: Array = m.legal_moves(0).filter(func(mv): return str((mv as Dictionary)["type"]) == "useHandRoom")
	_ok.call(moves.size() == 1 and moves[0]["args"][1] == {"targetPlayerId": 1, "roomIndex": 0}, "CRL007 : un coup, seule la salle avancee est ciblable")
	_ok.call(m.apply_move(0, moves[0]), "CRL007 : coup applique")
	_ok.call((p0["hand"] as Array).is_empty() and (G["decks"]["roomDiscard"] as Array).size() == 1 and BossEngine.is_room_deactivated(G, 1, 0), "CRL007 : carte defaussee, salle desactivee")
	_ok.call(_dmg(G, p1, 0) == 0 and _dmg(G, p1, 1) == 2, "CRL007 : la salle desactivee n'inflige rien, l'autre si")
	_ok.call(m.legal_moves(0).filter(func(mv): return str((mv as Dictionary)["type"]) == "useHandRoom").is_empty(), "CRL007 : plus de coup une fois la main vide")
	var p2 := _player(0, "BMA001")
	(p2["hand"] as Array).append(_real("CRL007"))
	var G2 := _G([p2, _player(1, "BMA002", [_room("ord", "monster", [3], 2)])])
	G2["phase"] = "build"
	G2["activePlayer"] = 0
	G2["buildOrder"] = [0, 1]
	G2["buildIndex"] = 0
	var m2 := _match(G2)
	_ok.call(m2.legal_moves(0).filter(func(mv): return str((mv as Dictionary)["type"]) == "useHandRoom").is_empty(), "CRL007 : sans salle avancee en jeu, aucune cible")
	m.queue_free()
	m2.queue_free()

## CRL008 Invasion Swarm : les salles adjacentes ont +1.
func _t_room_invasion_swarm() -> void:
	var p0 := _player(0, "BMA001", [_room("A", "monster", [1], 1), _real("CRL008"), _room("B", "trap", [1], 1), _room("C", "trap", [1], 1)])
	var G := _G([p0, _player(1, "BMA002")])
	_ok.call(_dmg(G, p0, 0) == 2 and _dmg(G, p0, 2) == 2, "CRL008 : +1 aux deux salles adjacentes")
	_ok.call(_dmg(G, p0, 3) == 1 and _dmg(G, p0, 1) == 0, "CRL008 : pas de bonus a distance 2 ni a lui-meme (0 degat)")

## CRL009 Reactor Core : les salles avancees de votre donjon ont +1 (cumulable, pas si gelee).
func _t_room_reactor_core() -> void:
	var p0 := _player(0, "BMA001", [_real("CRL009"), _room("adv", "trap", [1], 3, true), _room("ord", "trap", [1], 3)])
	var G := _G([p0, _player(1, "BMA002")])
	_ok.call(_dmg(G, p0, 1) == 4 and _dmg(G, p0, 2) == 3 and _dmg(G, p0, 0) == 2, "CRL009 : +1 seulement aux salles avancees")
	(p0["dungeon"] as Array).append([_real("CRL009")])
	_ok.call(_dmg(G, p0, 1) == 5, "CRL009 : deux reacteurs = +2")
	(G["effects"]["deactivatedRooms"] as Array).append({"playerId": 0, "roomIndex": 3})
	_ok.call(_dmg(G, p0, 1) == 4, "CRL009 : un reacteur gele ne donne plus de bonus")

## CRL010 Digicron Library : a la construction, avec au moins 2 salles avancees visibles (elle comprise), pioche 2 sorts.
func _t_room_digicron_library() -> void:
	var lib := _real("CRL010")
	var p0 := _player(0, "BMA001", [lib, _room("adv2", "monster", [2], 3, true)])
	var G := _G([p0, _player(1, "BMA002")])
	for i in 4:
		(G["decks"]["spells"] as Array).append({"id": "S%d" % i, "name": "S%d" % i, "isSpell": true})
	RoomAbilities.on_build_room(G, 0, lib)
	_ok.call((p0["hand"] as Array).size() == 2 and (G["decks"]["spells"] as Array).size() == 2, "CRL010 avec une autre salle avancee : 2 sorts")
	var lib2 := _real("CRL010")
	var p1 := _player(0, "BMA001", [lib2])
	var G2 := _G([p1, _player(1, "BMA002")])
	(G2["decks"]["spells"] as Array).append({"id": "S", "name": "S", "isSpell": true})
	RoomAbilities.on_build_room(G2, 0, lib2)
	_ok.call((p1["hand"] as Array).is_empty(), "CRL010 seule : rien")
	var p2 := _player(0, "BMA001", [lib2, _room("adv2", "monster", [2], 3, true)])
	(p2["dungeon"][1][0] as Dictionary)["faceDown"] = true # en attente de revelation : pas comptee
	var G3 := _G([p2, _player(1, "BMA002")])
	(G3["decks"]["spells"] as Array).append({"id": "S", "name": "S", "isSpell": true})
	RoomAbilities.on_build_room(G3, 0, lib2)
	_ok.call((p2["hand"] as Array).is_empty(), "CRL010 : une salle avancee encore face cachee ne compte pas")

## CRL011 Hypercube : se batit sur n'importe quelle salle (tresor ignore) ; les autres avancees exigent toujours un tresor commun.
func _t_room_hypercube() -> void:
	var p0 := _player(0, "BMA001", [_room("host", "trap", [1])])
	(p0["hand"] as Array).append(_real("CRL011"))
	(p0["hand"] as Array).append(_room("other", "trap", [3], 3, true))
	var G := _G([p0, _player(1, "BMA002")])
	_ok.call(BossEngine.can_build_room(p0, G, 0, 0, 0), "CRL011 : se bat sur une salle de tresor different (Explorer sur Cleric)")
	_ok.call(not BossEngine.can_build_room(p0, G, 0, 1, 0), "une autre salle avancee exige un tresor commun")
	(p0["dungeon"] as Array)[0] = [_room("BMA018", "monster", [1], 2)]
	_ok.call(not BossEngine.can_build_room(p0, G, 0, 0, 0), "CRL011 : pas sur Neanderthal Cave (Cannot build over)")
	var p1 := _player(0, "BMA001")
	(p1["hand"] as Array).append(_real("CRL011"))
	_ok.call(not BossEngine.can_build_room(p1, G, 0, 0, 0), "CRL011 : une salle avancee exige un donjon non vide")

## CRL012 The Omega 42 : une fois par tour, defausse une salle avancee de la main pour rejouer un effet « build » / « uncover » d'une salle du donjon.
func _t_room_omega_42() -> void:
	var omega := _real("CRL012")
	var lib := _real("CRL010")
	var p0 := _player(0, "BMA001", [omega, lib, _room("adv2", "monster", [2], 3, true)])
	(p0["hand"] as Array).append(_room("spare", "monster", [2], 3, true))
	var G := _G([p0, _player(1, "BMA002")])
	G["phase"] = "build"
	for i in 3:
		(G["decks"]["spells"] as Array).append({"id": "S%d" % i, "name": "S%d" % i, "isSpell": true})
	var m := _match(G)
	m.G["activePlayer"] = 0
	_ok.call(m.legal_moves(0).any(func(mv): return str((mv as Dictionary)["type"]) == "activateRoom" and (mv["args"] as Array)[0] == 0), "CRL012 : activable (coup activateRoom) avec une salle avancee en main")
	_ok.call(RoomAbilities.activate_room_ability(G, 0, 0) == null, "CRL012 : activation")
	_ok.call((p0["hand"] as Array).size() == 2 and (G["decks"]["roomDiscard"] as Array).size() == 1, "CRL012 : salle avancee defaussee, Digicron Library rejoue : 2 sorts pioches")
	_ok.call(bool(omega.get("usedThisTurn", false)) and RoomAbilities.activate_room_ability(G, 0, 0) == "already used this turn", "CRL012 : une fois par tour")
	m.queue_free()
	# Sans salle avancee en main : refus, la capacite n'est pas consommee (JS : 'no Advanced Room to discard').
	var omega2 := _real("CRL012")
	var q0 := _player(0, "BMA001", [omega2, _real("CRL010")])
	(q0["hand"] as Array).append(_spell("CRL033"))
	var G2 := _G([q0, _player(1, "BMA002")])
	_ok.call(RoomAbilities.activate_room_ability(G2, 0, 0) == "no Advanced Room to discard" and not bool(omega2.get("usedThisTurn", false)), "CRL012 sans salle avancee en main : refus, non consommee")
	# Aucune salle avec effet : refus.
	var omega3 := _real("CRL012")
	var r0 := _player(0, "BMA001", [omega3, _room("plain", "trap", [1])])
	(r0["hand"] as Array).append(_room("spare", "monster", [2], 3, true))
	_ok.call(RoomAbilities.activate_room_ability(_G([r0, _player(1, "BMA002")]), 0, 0) == "no Room effect to activate", "CRL012 sans effet a rejouer : refus")

## Plusieurs cibles / plusieurs cartes avancees : deux choix successifs ; mode « uncover ».
func _t_room_omega_42_choices() -> void:
	var garden := _real("CRL006")
	var p0 := _player(0, "BMA001", [_real("CRL012"), _real("CRL010"), garden])
	(p0["hand"] as Array).append(_room("spare1", "monster", [2], 3, true))
	(p0["hand"] as Array).append(_room("spare2", "monster", [2], 3, true))
	var G := _G([p0, _player(1, "BMA002")])
	var m := _match(G)
	_ok.call(RoomAbilities.activate_room_ability(G, 0, 0) == null, "CRL012 (2 cibles, 2 cartes) : activation")
	var pc: Dictionary = G["pendingChoice"]
	_ok.call(str(pc["type"]) == "omega-refire" and (pc["options"] as Array).size() == 2 and not bool(pc["resume"]), "CRL012 : 1er choix = la salle dont on rejoue l'effet")
	m._resolve_choice(0, 1) # Decoy Garden
	var pc2: Dictionary = G["pendingChoice"]
	_ok.call(str(pc2["type"]) == "omega-discard" and (pc2["options"] as Array).size() == 2, "CRL012 : 2e choix = la salle avancee a defausser")
	m._resolve_choice(0, 1)
	_ok.call((G["pendingChoice"] as Dictionary).is_empty() and (p0["hand"] as Array).size() == 1 and str(p0["hand"][0]["id"]) == "spare1", "CRL012 : la carte choisie (spare2) est defaussee")
	_ok.call((garden.get("extraTreasures", []) as Array).size() == 2, "CRL012 : l'effet de Decoy Garden est rejoue (Explorer x2)")
	# Mode uncover : Crash Site (effet « uncover ») recupere une salle avancee de la defausse.
	var site := _real("CRL013")
	var q0 := _player(0, "BMA001", [_real("CRL012"), site])
	(q0["hand"] as Array).append(_room("spare", "monster", [2], 3, true))
	var G2 := _G([q0, _player(1, "BMA002")])
	(G2["decks"]["roomDiscard"] as Array).append(_room("in_discard", "trap", [1], 2, true))
	_ok.call(RoomAbilities.activate_room_ability(G2, 0, 0) == null, "CRL012 : Crash Site comme seule cible (mode uncover)")
	# La salle avancee est defaussee AVANT l'effet : la defausse a alors 2 candidates (in_discard + la carte payee) -> choix.
	var pc3: Dictionary = G2["pendingChoice"]
	_ok.call(str(pc3["type"]) == "recover-card" and (pc3["options"] as Array).size() == 2, "CRL012 : l'effet « uncover » de Crash Site est rejoue (cout paye d'abord)")
	var m2 := _match(G2)
	m2._resolve_choice(0, 0)
	_ok.call(str(q0["hand"][0]["id"]) == "in_discard", "CRL012 : Crash Site recupere la salle avancee choisie")
	m.queue_free()
	m2.queue_free()

# --- salles « uncover » (declenchees par BossEngine.destroy_room) ----------------------------------------------------

## CRL013 Crash Site : decouverte -> cherche une salle avancee dans la defausse et la prend en main.
func _t_uncover_crash_site() -> void:
	var p0 := _player(0, "BMA001", [[_real("CRL013"), _room("top", "trap", [1])]])
	var G := _G([p0, _player(1, "BMA002")])
	(G["decks"]["roomDiscard"] as Array).append_array([_room("adv3", "monster", [3], 4, true), _room("plain", "trap", [1])])
	BossEngine.destroy_room(p0, 0, G)
	_ok.call((p0["hand"] as Array).size() == 1 and str(p0["hand"][0]["id"]) == "adv3" and (G["decks"]["roomDiscard"] as Array).size() == 1, "CRL013 : la seule salle avancee de la defausse va en main")
	_ok.call(_stack_ids(p0, 0) == ["CRL013"], "CRL013 : la pile n'a plus que la salle decouverte")
	# Plusieurs candidates : choix (recover-card), non bloquant pour la phase (resume = false hors revelation de BUILD).
	var p1 := _player(0, "BMA001", [[_real("CRL013"), _room("top", "trap", [1])]])
	var G2 := _G([p1, _player(1, "BMA002")])
	(G2["decks"]["roomDiscard"] as Array).append_array([_room("advA", "monster", [2], 3, true), _room("advB", "trap", [2], 3, true)])
	BossEngine.destroy_room(p1, 0, G2)
	var pc: Dictionary = G2["pendingChoice"]
	_ok.call(str(pc["type"]) == "recover-card" and (pc["options"] as Array).size() == 2 and not bool(pc["resume"]), "CRL013 : plusieurs salles avancees = choix")
	var m := _match(G2)
	m._resolve_choice(0, 1)
	_ok.call((p1["hand"] as Array).size() == 1 and str(p1["hand"][0]["id"]) == "advB", "CRL013 : la salle choisie va en main")
	m.queue_free()
	var p2 := _player(0, "BMA001", [[_real("CRL013"), _room("top", "trap", [1])]])
	var G3 := _G([p2, _player(1, "BMA002")])
	BossEngine.destroy_room(p2, 0, G3)
	_ok.call((p2["hand"] as Array).is_empty() and not G3.has("pendingChoice"), "CRL013 : defausse sans salle avancee, rien")

## CRL014 Caged Gundarf : decouvert, ses degats sont doubles jusqu'a la fin du tour.
func _t_uncover_caged_gundarf() -> void:
	var p0 := _player(0, "BMA001", [[_real("CRL014"), _room("top", "trap", [1])]])
	var G := _G([p0, _player(1, "BMA002")])
	_ok.call(_dmg(G, p0, 0) == 1, "CRL014 : couvert/avant : 1 degat (la salle du dessus compte)")
	BossEngine.destroy_room(p0, 0, G)
	_ok.call(_stack_ids(p0, 0) == ["CRL014"] and _dmg(G, p0, 0) == 2, "CRL014 : decouvert, degats doubles (1 -> 2)")
	G["effects"] = SpellEffects.empty_effects() # fin du tour
	_ok.call(_dmg(G, p0, 0) == 1, "CRL014 : le bonus disparait avec les effets de fin de tour")

## CRL014 : « its damage is doubled » double les degats du moment, modificateurs compris (Invasion Swarm adjacent : 1 + 1 = 2 -> 4, pas 3).
func _t_uncover_caged_gundarf_modifiers() -> void:
	var p0 := _player(0, "BMA001", [[_real("CRL014"), _room("top", "trap", [1])], _real("CRL008")])
	var G := _G([p0, _player(1, "BMA002")])
	BossEngine.destroy_room(p0, 0, G)
	_ok.call(_stack_ids(p0, 0) == ["CRL014"] and _dmg(G, p0, 0) == 4, "CRL014 + Invasion Swarm adjacent : (1 imprime + 1) doubles = 4, pas 3 (le doublement ne porte pas que sur le degat imprime)")
	G["effects"] = SpellEffects.empty_effects()
	_ok.call(_dmg(G, p0, 0) == 2, "CRL014 : fin de tour, retour a 1 + 1")

## CRL015 Celestial Map : decouverte -> pioche un sort puis se detruit ; la salle du dessous est a son tour decouverte (cascade).
func _t_uncover_celestial_map() -> void:
	var p0 := _player(0, "BMA001", [[_real("CRL014"), _real("CRL015"), _room("top", "trap", [1])]])
	var G := _G([p0, _player(1, "BMA002")])
	(G["decks"]["spells"] as Array).append({"id": "drawn", "name": "Drawn", "isSpell": true})
	var destroyed = BossEngine.destroy_room(p0, 0, G)
	BossEngine.discard_room_to_pile(G["decks"], destroyed)
	_ok.call((p0["hand"] as Array).size() == 1 and str(p0["hand"][0]["id"]) == "drawn", "CRL015 : pioche un sort")
	_ok.call(_stack_ids(p0, 0) == ["CRL014"] and (G["decks"]["roomDiscard"] as Array).size() == 2, "CRL015 : se detruit (defausse : top + Map)")
	_ok.call(_dmg(G, p0, 0) == 2, "CRL015 : cascade, Caged Gundarf decouvert a son tour (degats doubles)")
	var p1 := _player(0, "BMA001", [[_real("CRL015"), _room("top", "trap", [1])]])
	var G2 := _G([p1, _player(1, "BMA002")])
	BossEngine.destroy_room(p1, 0, G2)
	_ok.call((p1["dungeon"] as Array).is_empty(), "CRL015 seule dans sa pile : l'emplacement disparait (JS : dungeon.length 0)")

## CRL016 Darkling Lair : decouverte -> 3 degats a un heros du donjon ou de l'entree (choix s'il y en a plusieurs).
func _t_uncover_darkling_lair() -> void:
	var p0 := _player(0, "BMA001", [[_real("CRL016"), _room("top", "trap", [1])]])
	var G := _G([p0, _player(1, "BMA002")])
	var h1 := _hero("CRL018") # 4 PV
	(p0["entrance"] as Array).append(h1)
	BossEngine.destroy_room(p0, 0, G)
	_ok.call(int(h1["hp"]) == 1, "CRL016 : 3 degats au heros de l'entree (4 -> 1)")
	# Heros en aventure : ses PV vivent dans adventure.hp.
	var p1 := _player(0, "BMA001", [[_real("CRL016"), _room("top", "trap", [1])]])
	var G2 := _G([p1, _player(1, "BMA002")])
	var h2 := _hero("CRL020") # 6 PV
	(p1["entrance"] as Array).append(h2)
	G2["adventure"] = {"playerId": 0, "hero": h2, "roomIndex": 1, "hp": 5, "pause": "post-damage"}
	BossEngine.destroy_room(p1, 0, G2)
	_ok.call(int(G2["adventure"]["hp"]) == 2 and int(h2["hp"]) == 6, "CRL016 : le heros actif perd 3 PV d'aventure (5 -> 2)")
	# Aucun heros : rien. Deux heros : choix, et un heros tue meurt (ame au proprietaire).
	var p2 := _player(0, "BMA001", [[_real("CRL016"), _room("top", "trap", [1])]])
	var G3 := _G([p2, _player(1, "BMA002")])
	BossEngine.destroy_room(p2, 0, G3)
	_ok.call(not G3.has("pendingChoice"), "CRL016 sans heros : rien")
	var p3 := _player(0, "BMA001", [[_real("CRL016"), _room("top", "trap", [1])], [_room("room2", "trap", [1])]])
	var G4 := _G([p3, _player(1, "BMA002")])
	var ha := _hero("CRL018")
	var hb := _hero("CRL019")
	(p3["entrance"] as Array).append_array([ha, hb])
	G4["adventure"] = {"playerId": 0, "hero": ha, "roomIndex": 1, "hp": 2, "pause": "post-damage"}
	var m := _match(G4)
	BossEngine.destroy_room(p3, 0, G4)
	var pc: Dictionary = G4["pendingChoice"]
	_ok.call(str(pc["type"]) == "hero-damage" and (pc["options"] as Array).size() == 2 and int(pc["amount"]) == 3, "CRL016 : choix entre les 2 heros")
	m._resolve_choice(0, 0) # le heros actif (2 PV) meurt
	_ok.call((G4["adventure"] as Dictionary).is_empty() and (p3["souls"] as Array).size() == 1 and (p3["entrance"] as Array).size() == 1, "CRL016 : le heros tue donne une ame au proprietaire du donjon")
	m.queue_free()

# --- sorts -------------------------------------------------------------------------------------------------------

## CRL029 Finish Him! : tue un heros a 2 PV ou moins ; OU, avec moins d'ames que tous les autres, prend un survivant du tour.
func _t_spell_finish_him() -> void:
	var p0 := _player(0, "BMA001")
	var p1 := _player(1, "BMA002")
	var G := _G([p0, p1])
	var weak := _hero("CRL018")
	weak["hp"] = 2
	var strong := _hero("CRL020")
	(p1["entrance"] as Array).append_array([weak, strong])
	var t: Array = SpellTargeting.spell_targets_for(G, p0, 0, "CRL029")
	_ok.call(t == [{"targetPlayerId": 1, "entranceIndex": 0}], "CRL029 : seul le heros a 2 PV ou moins est ciblable (ni %d PV)" % int(strong["hp"]))
	var card := _spell("CRL029")
	SpellEffects.cast_spell(G, 0, card, t[0])
	_ok.call(RoomAbilities.current_hero_hp(G, 1, weak) == 0 and int(strong["hp"]) == 6, "CRL029 : PV a 0 (il meurt dans sa premiere salle)")
	# Heros actif : adventure.hp tombe a 0.
	var h3 := _hero("CRL018")
	var p2 := _player(0, "BMA001")
	var G2 := _G([p2, _player(1, "BMA002")])
	(p2["entrance"] as Array).append(h3)
	G2["adventure"] = {"playerId": 0, "hero": h3, "roomIndex": 0, "hp": 1, "pause": "post-damage"}
	SpellEffects.cast_spell(G2, 1, _spell("CRL029"), {"targetPlayerId": 0, "entranceIndex": 0})
	_ok.call(int(G2["adventure"]["hp"]) == 0, "CRL029 sur le heros actif : adventure.hp = 0")
	_match(G2)._finish_hero_if_dead()
	_ok.call((p2["souls"] as Array).size() == 1 and (G2["adventure"] as Dictionary).is_empty(), "arbitrage Finish Him! : « kill » = PV a 0 dans la salle, le heros meurt aussitot et l'ame va au proprietaire du donjon")
	# Mode « survivant » : il faut avoir MOINS d'ames que chaque autre joueur.
	var q0 := _player(0, "BMA001")
	var q1 := _player(1, "BMA002")
	var q2 := _player(2, "BMA003")
	var G3 := _G([q0, q1, q2])
	var surv := _hero("BMA056")
	(q1["wounds"] as Array).append({"name": "x", "wounds": 1, "souls": 1, "class": "", "faceDown": false, "turn": 1, "hero": surv})
	_ok.call(SpellTargeting.spell_targets_for(G3, q0, 0, "CRL029").is_empty(), "CRL029 survivant : refuse a egalite d'ames (0 contre 0)")
	(q1["souls"] as Array).append({"souls": 1})
	_ok.call(SpellTargeting.spell_targets_for(G3, q0, 0, "CRL029").is_empty(), "CRL029 survivant : refuse si un autre joueur n'a pas plus d'ames que moi")
	(q2["souls"] as Array).append({"souls": 1})
	var ts: Array = SpellTargeting.spell_targets_for(G3, q0, 0, "CRL029")
	_ok.call(ts == [{"targetPlayerId": 1, "woundIndex": 0}], "CRL029 survivant : moins d'ames que tous -> le survivant de ce tour est ciblable")
	(q1["wounds"] as Array)[0]["turn"] = 0
	_ok.call(SpellTargeting.spell_targets_for(G3, q0, 0, "CRL029").is_empty(), "CRL029 survivant : seulement ceux de CE tour")
	(q1["wounds"] as Array)[0]["turn"] = 1
	SpellEffects.cast_spell(G3, 0, _spell("CRL029"), ts[0])
	_ok.call((q1["wounds"] as Array).is_empty() and (q0["souls"] as Array).size() == 1 and bool(q0["souls"][0]["faceDown"]), "CRL029 survivant : le heros passe face cachee chez le lanceur (ame), plus de blessure")

## CRL030 Essence Transfer : +X PV (X = vos blessures) a un heros du donjon d'un adversaire.
func _t_spell_essence_transfer() -> void:
	var p0 := _player(0, "BMA001")
	var p1 := _player(1, "BMA002")
	var G := _G([p0, p1])
	var mine := _hero("CRL018")
	var theirs := _hero("CRL018")
	(p0["entrance"] as Array).append(mine)
	(p1["entrance"] as Array).append(theirs)
	_ok.call(SpellTargeting.spell_targets_for(G, p0, 0, "CRL030").is_empty(), "CRL030 sans blessure : aucun coup (X = 0)")
	(p0["wounds"] as Array).append_array([{"wounds": 1}, {"wounds": 1}])
	var t: Array = SpellTargeting.spell_targets_for(G, p0, 0, "CRL030")
	_ok.call(t == [{"targetPlayerId": 1, "entranceIndex": 0}], "CRL030 : seul le heros d'un adversaire est ciblable")
	SpellEffects.cast_spell(G, 0, _spell("CRL030"), t[0])
	_ok.call(int(theirs["hp"]) == 6 and int(mine["hp"]) == 4, "CRL030 : +2 PV (deux blessures)")
	G["adventure"] = {"playerId": 1, "hero": theirs, "roomIndex": 0, "hp": 3, "pause": "post-damage"}
	SpellEffects.cast_spell(G, 0, _spell("CRL030"), t[0])
	_ok.call(int(G["adventure"]["hp"]) == 5, "CRL030 sur le heros actif : adventure.hp +2")

## CRL031 Healing Tank : si aucun heros n'a ete leurre chez vous, soigne une blessure de heros ordinaire.
func _t_spell_healing_tank() -> void:
	var p0 := _player(0, "BMA001")
	var G := _G([p0, _player(1, "BMA002")])
	var ordinary := _hero("BMA056")
	var epic := _hero("BMA081")
	(p0["wounds"] as Array).append({"name": "e", "wounds": 1, "souls": 2, "class": "", "faceDown": false, "hero": epic})
	_ok.call(SpellTargeting.spell_targets_for(G, p0, 0, "CRL031").is_empty(), "CRL031 : une blessure d'epique ne compte pas (ordinaire seulement)")
	(p0["wounds"] as Array).append({"name": "o", "wounds": 1, "souls": 1, "class": "", "faceDown": false, "hero": ordinary})
	_ok.call(SpellTargeting.spell_targets_for(G, p0, 0, "CRL031") == [{}], "CRL031 : jouable quand aucun heros n'a ete leurre (luredThisTurn absent)")
	G["luredThisTurn"] = {0: 1}
	_ok.call(SpellTargeting.spell_targets_for(G, p0, 0, "CRL031").is_empty(), "CRL031 : un heros a ete leurre chez moi : injouable")
	G["luredThisTurn"] = {1: 3}
	_ok.call(SpellTargeting.spell_targets_for(G, p0, 0, "CRL031") == [{}], "CRL031 : seuls MES leurres comptent")
	SpellEffects.cast_spell(G, 0, _spell("CRL031"), {})
	_ok.call((p0["wounds"] as Array).size() == 1 and (p0["souls"] as Array).size() == 1 and str(p0["souls"][0]["name"]) == str(ordinary["name"]), "CRL031 : la blessure du heros ordinaire devient une ame face cachee")
	# Deux heros ordinaires blesses : choix (heal-wound, sans reprise de phase).
	var p1 := _player(0, "BMA001")
	var G2 := _G([p1, _player(1, "BMA002")])
	var a := _hero("BMA056")
	var b := _hero("BMA062")
	(p1["wounds"] as Array).append_array([{"name": "a", "wounds": 1, "souls": 1, "class": "", "faceDown": false, "hero": a}, {"name": "b", "wounds": 1, "souls": 1, "class": "", "faceDown": false, "hero": b}])
	SpellEffects.cast_spell(G2, 0, _spell("CRL031"), {})
	var pc: Dictionary = G2["pendingChoice"]
	_ok.call(str(pc["type"]) == "heal-wound" and (pc["options"] as Array).size() == 2 and not bool(pc["resume"]), "CRL031 : deux heros blesses = choix du heros a retourner")
	var m := _match(G2)
	m._resolve_choice(0, 1)
	_ok.call((p1["wounds"] as Array).size() == 1 and str(p1["souls"][0]["name"]) == str(b["name"]), "CRL031 : le heros choisi est retourne")
	m.queue_free()

## CRL032 Meteorite : une salle gagne un tresor Explorer jusqu'a la fin du tour (leurre, et salle avancee batie par-dessus).
func _t_spell_meteorite() -> void:
	var p0 := _player(0, "BMA001", [_room("A", "trap", [1])])
	var p1 := _player(1, "BMA002", [_room("B", "trap", [1])])
	var G := _G([p0, p1])
	var t: Array = SpellTargeting.spell_targets_for(G, p0, 0, "CRL032")
	_ok.call(t.size() == 2, "CRL032 : n'importe quelle salle, la sienne ou celle d'un adversaire")
	var card := _spell("CRL032")
	_ok.call(CardDB.can_play_spell(card, "build") and not CardDB.can_play_spell(card, "adventure"), "CRL032 : sort de construction (categorie 1)")
	SpellEffects.cast_spell(G, 0, card, {"targetPlayerId": 0, "roomIndex": 0})
	_ok.call((p0["dungeon"][0][0]["extraTreasures"] as Array) == [5] and (p0["dungeon"][0][0]["treasures"] as Array) == [1], "CRL032 : [1] + Explorer (le JS fait [1, 5])")
	_ok.call(BossEngine.lure_target(G["players"], [0, 1], 5, _hero("CRL019"), G) == 0, "CRL032 : l'Explorer est leurre par la salle qui a recu la meteorite")
	(p0["hand"] as Array).append(_room("adv", "trap", [5], 2, true))
	_ok.call(BossEngine.can_build_room(p0, G, 0, 0, 0), "CRL032 : on peut batir une salle avancee Explorer par-dessus (tresor commun)")
	SpellEffects.cast_spell(G, 0, card, {"targetPlayerId": 0, "roomIndex": 9})
	_ok.call((p0["dungeon"][0][0]["extraTreasures"] as Array) == [5], "CRL032 : cible invalide, sans effet")

## CRL033 Not Dead Yet : X degats (X = vos blessures) a chaque heros de votre donjon ou de votre entree.
func _t_spell_not_dead_yet() -> void:
	var p0 := _player(0, "BMA001", [_room("A", "trap", [1], 0)])
	var G := _G([p0, _player(1, "BMA002")])
	var card := _spell("CRL033")
	_ok.call(SpellTargeting.spell_targets_for(G, p0, 0, "CRL033").is_empty(), "CRL033 : sans blessure ni heros, aucun coup")
	var h1 := _hero("CRL020") # 6 PV
	var h2 := _hero("CRL021") # 6 PV
	(p0["entrance"] as Array).append_array([h1, h2])
	_ok.call(SpellTargeting.spell_targets_for(G, p0, 0, "CRL033").is_empty(), "CRL033 : sans blessure, aucun coup (X = 0)")
	(p0["wounds"] as Array).append_array([{"wounds": 1}, {"wounds": 1}, {"wounds": 1}])
	_ok.call(SpellTargeting.spell_targets_for(G, p0, 0, "CRL033") == [{}], "CRL033 : jouable avec des blessures et un heros")
	G["adventure"] = {"playerId": 0, "hero": h1, "roomIndex": 0, "hp": 6, "pause": "post-damage"}
	SpellEffects.cast_spell(G, 0, card, {})
	_ok.call(int(G["adventure"]["hp"]) == 3 and int(h2["hp"]) == 3, "CRL033 : -3 au heros actif (adventure.hp) et a celui de l'entree")
	# Un heros a l'entree a 0 PV meurt dans sa premiere salle (ame au joueur), meme sans degats.
	var m := _match(G)
	G["adventure"] = {}
	G["phase"] = "adventure"
	G["activePlayer"] = 0
	G["xpOrder"] = [0, 1]
	p0["entrance"] = [h2]
	h2["hp"] = 0
	_ok.call(m.apply_move(0, {"type": "adventureNext", "args": []}), "CRL033 : le heros a 0 PV entre")
	_ok.call(int(G["adventure"]["hp"]) <= 0, "CRL033 : 0 PV - 0 degat de la salle = mort a la premiere salle")
	m.queue_free()

# --- fin de partie / debut de tour -------------------------------------------------------------------------------

## « Heroes can still be in Town when the game ends » : Explorers bloques en ville, pioches vides, plus de leurre = fin de partie.
func _t_end_of_game_stuck_town() -> void:
	var p0 := _player(0, "BMA001", [_room("A", "trap", [1])])
	var p1 := _player(1, "BMA002", [_room("B", "trap", [1])])
	var G := _G([p0, p1])
	G["town"] = [_hero("CRL019")]
	G["luredThisTurn"] = {}
	var m := _match(G)
	m._check_end_or_next_turn()
	_ok.call(G.get("gameOver") != null and str(G["gameOver"]["reason"]).begins_with("h"), "CRL : pioches vides, un Explorer coince en ville, aucun leurre : fin de partie (heros epuises)")
	m.queue_free()
	var G2 := _G([_player(0, "BMA001", [_room("A", "trap", [1])]), _player(1, "BMA002", [_room("B", "trap", [1])])])
	G2["sets"] = ["base"]
	G2["town"] = [_hero("CRL019")]
	G2["luredThisTurn"] = {}
	for i in 3:
		(G2["decks"]["rooms"] as Array).append(_room("r%d" % i, "trap", [1]))
	var m2 := _match(G2)
	m2._check_end_or_next_turn()
	_ok.call(G2.get("gameOver") == null, "hors Crash Landing : regle APK inchangee (la partie continue)")
	m2.queue_free()

## GameBoard.CheckEndOfGame (APK) n'a pas de fin « heros epuises » : pioches et ville vides, la partie continue en mode APK ; avec une extension wiki, elle se termine.
func _t_heroes_exhausted_end_not_in_apk_mode() -> void:
	for sets in [["base"], ["base", "players-choice", "tools"], ["base", "crash-landing"]]:
		var G := _G([_player(0, "BMA001", [_room("A", "trap", [1])]), _player(1, "BMA002", [_room("B", "trap", [1])])])
		G["sets"] = sets
		G["luredThisTurn"] = {}
		for i in 3:
			(G["decks"]["rooms"] as Array).append(_room("r%d" % i, "trap", [1]))
		var m := _match(G)
		m._check_end_or_next_turn()
		_ok.call((G.get("gameOver") != null) == sets.has("crash-landing"), "pioches de heros et ville vides, sets %s : fin « heros epuises » seulement avec une extension" % str(sets))
		m.queue_free()

## Les tresors « jusqu'a la fin du tour » (Decoy Garden, Meteorite) expirent au debut du tour suivant (EndOfTurnPhase : Boss.RestoreDungeon).
func _t_start_turn_clears_temporary_treasure() -> void:
	var garden := _real("CRL006")
	garden["extraTreasures"] = [5, 5]
	var p0 := _player(0, "BMA001", [garden])
	var G := _G([p0, _player(1, "BMA002")])
	for i in 4:
		(G["decks"]["rooms"] as Array).append(_room("r%d" % i, "trap", [1]))
	var m := _match(G)
	G["phase"] = "end"
	m._start_turn()
	_ok.call(not garden.has("extraTreasures") and BossEngine.treasure_count(p0, 5, G) == 1, "debut de tour : extraTreasures effacees")
	m.queue_free()

# --- IA contre IA, paquets de salles/sorts reduits aux cartes CRL (toutes les capacites CRL sont exercees) ---------------

const SOAK_MAX_STEPS := 4000

func _t_ai_soak_crl_only() -> void:
	var names := {}
	for c in CardDB.rooms + CardDB.spells + CardDB.bosses:
		if str((c as Dictionary).get("set", "")) == "crash-landing":
			names[str((c as Dictionary)["name"])] = 0
	var finished := 0
	var games := 0
	for n in [2, 2, 2, 3, 3, 3, 4, 4, 4]:
		games += 1
		var m = load("res://godot/scripts/Match.gd").new()
		host.add_child(m)
		load("res://godot/tests/soak_seed.gd").seed_game(m, 1000 + games)
		m.new_match(n, 0, ["crash-landing"])
		# Paquets 100 % CRL (x3 pour ne pas manquer de cartes) : chaque partie joue beaucoup de salles / sorts CRL.
		var crl := func(c): return str((c as Dictionary).get("set", "")) == "crash-landing"
		for pile in ["rooms", "spells"]:
			var only: Array = (m.G["decks"][pile] as Array).filter(crl)
			var deck: Array = []
			for _k in 3:
				for c in only:
					deck.append((c as Dictionary).duplicate())
			m.G["decks"][pile] = CardDB.shuffled(deck)
		if _play_soak(m):
			finished += 1
		for line in (m.G.get("logs", []) as Array):
			for nm in names:
				if str(line).contains(nm):
					names[nm] = int(names[nm]) + 1
		m.queue_free()
	load("res://godot/tests/soak_seed.gd").unseed()
	_ok.call(finished == games, "soak CRL : %d/%d parties IA-vs-IA terminees (pas de blocage)" % [finished, games])
	var touched := 0
	for nm in names:
		touched += 1 if int(names[nm]) > 0 else 0
	print("SOAK-CRL cartes CRL vues dans les journaux : ", touched, "/", names.size(), " ", names)
	_ok.call(touched >= 10, "soak CRL : au moins 10 cartes CRL differentes jouees (%d)" % touched)

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
				m.apply_move(owner, cmoves[0])
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

# --- heros CRL017 The Prince / CRL028 The King (textes imprimes : arbitrages wiki) ---------------------------------------------------------

func _t_heroes_prince_king() -> void:
	# The Prince : « lured to the dungeon of the player with the fewest total Souls minus Wounds »
	var p0 := _player(0, "BMA001")
	var p1 := _player(1, "BMA002")
	var G := _G([p0, p1])
	(p0["souls"] as Array).append(CardDB.soul_entry(_hero("CRL018")))
	(p1["wounds"] as Array).append({"wounds": 1})
	var prince := _hero("CRL017")
	_ok.call(BossEngine.lure_target(G["players"], CardDB.order_by_xp(G["players"]), 1, prince, G) == 1, "CRL017 The Prince : leurre vers le moins d'ames moins blessures (1 blessure = -1 contre 1 ame = +1)")
	# apres la mort du Prince, le proprietaire du donjon peut piocher 1 salle et 1 sort
	for i in 3:
		(G["decks"]["rooms"] as Array).append(_room("r%d" % i, "trap", [1]))
		(G["decks"]["spells"] as Array).append(_spell("BMA040"))
	(p1["entrance"] as Array).append(prince)
	var m := _match(G)
	m._finish_hero(1, prince, 0, {})
	var pc: Dictionary = G.get("pendingChoice", {}) as Dictionary
	_ok.call(str(pc.get("step", "")) == "hero_prince" and bool(pc.get("optional", false)) and (pc["options"] as Array).size() == 3, "CRL017 : une fois ame, choix facultatif (2 salles, 2 sorts ou un de chaque) pour le proprietaire du donjon")
	m._resolve_choice(1, 2)
	_ok.call((p1["hand"] as Array).size() == 2, "CRL017 : une salle et un sort pioches")
	m.queue_free()
	# The King : vote facultatif de chaque joueur, egalite = reste en ville
	var q0 := _player(0, "BMA001")
	var q1 := _player(1, "BMA002")
	var G2 := _G([q0, q1])
	G2["town"] = [_hero("CRL028")]
	var m2 := _match(G2)
	_ok.call(m2._king_vote() and str((G2["pendingChoice"] as Dictionary).get("step", "")) == "hero_king", "CRL028 The King : un vote par joueur avant le leurre")
	while not (G2["pendingChoice"] as Dictionary).is_empty():
		m2._resolve_choice(int((G2["pendingChoice"] as Dictionary)["playerId"]), 1) # tous votent pour le joueur 1
	_ok.call(BossEngine.lure_target(G2["players"], CardDB.order_by_xp(G2["players"]), 1, G2["town"][0], G2) == 1, "CRL028 : le joueur le plus vote recoit le Roi")
	(G2["kingVote"] as Dictionary)[0] = 0
	_ok.call(BossEngine.lure_target(G2["players"], CardDB.order_by_xp(G2["players"]), 1, G2["town"][0], G2) == -1, "CRL028 : egalite du vote = le Roi reste en ville")
	G2["kingVote"] = {}
	_ok.call(BossEngine.lure_target(G2["players"], CardDB.order_by_xp(G2["players"]), 1, G2["town"][0], G2) == -1, "CRL028 : aucun vote = le Roi reste en ville")
	m2.queue_free()
