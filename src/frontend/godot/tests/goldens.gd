extends Node
## Goldens — invariants de l'engine derives des tests JS (tests/unit/*.test.js).
## But : prouver que le port GDScript (Match.gd) respecte les memes regles que
## src/backend/game (reducer.js / engine.js), avant/pendant le port des modules manquants.
## Lance par res://godot/tests/Goldens.tscn (headless).

var _failed: Array = []
var _passed := 0

func _ready() -> void:
	_t_tie_break_souls_minus_wounds()
	_t_tie_break_lowest_boss_xp()
	_t_ten_souls_wins_under_five_wounds()
	_t_five_wounds_eliminates()
	_t_souls_counting()
	_t_advanced_room_requires_treasures()
	_t_advanced_room_rejects_neanderthal_cave()
	_t_ordinary_room_over_existing_stack()
	_t_heal_one_wound_returns_soul()
	_t_spell_targeting_own_room()
	_t_spell_targeting_any_room_trap()
	_t_spell_targeting_no_target_spell()
	_t_spell_targeting_trepidation()
	_t_spell_annihilator_requires_trap()
	_t_spell_giant_size_requires_monster()
	_t_spell_freeze_deactivates()
	_t_spell_motivation_extra_build()
	_t_spell_jeopardy_all_players()
	_t_spell_unknown_returns_false()
	_t_spell_empty_effects_shape()
	_t_play_spell_appears_in_legal_moves()
	_t_play_spell_consumes_card()
	_t_room_ability_dark_altar()
	_t_room_ability_jackpot_stash()
	_t_room_ability_unknown_rejected()
	_t_activate_room_appears_in_legal_moves()
	_t_pending_choice_freezes_legal_moves()
	_t_resolve_choice_recover_card()
	_t_resolve_choice_discard_spell()
	_t_resolve_choice_clears_pending()
	_t_build_golem_factory_draws_room()
	_t_build_construction_zone_refunds_build()
	_t_build_brainsucker_hive_draws_spell()
	_t_build_dark_laboratory_opens_choice()
	_t_died_vampire_bordello_heals()
	_t_died_golem_factory_once_per_turn()
	_t_levelup_requires_5_visible_rooms()
	_t_levelup_draculord_steals()
	_t_levelup_xyzax_recovers_two()
	_t_levelup_cerebellus_draws_three()
	_t_levelup_gorgona_kills_town_hero()
	_t_levelup_king_croak_searches_advanced()
	_t_levelup_robobo_targets_opponent()
	_t_levelup_unknown_boss_noop()

	print("GOLDENS passed=", _passed, " failed=", _failed.size())
	if _failed.is_empty():
		print("GOLDENS OK")
		get_tree().quit(0)
	else:
		for f in _failed:
			print("ECHEC: ", f)
		get_tree().quit(1)

func _ok(cond: bool, label: String) -> void:
	if cond:
		_passed += 1
	else:
		_failed.append(label)

## Match.gd:_tie_break_players — ecart ames-blessures d'abord, puis XP boss le plus bas.
## (cf. engine-invariants.test.js "breaks ties by souls - wounds first, then lowest boss XP")
func _t_tie_break_souls_minus_wounds() -> void:
	var m = Match.new()
	add_child(m)
	m.G = {
		"players": {
			0: {"boss": {"xp": 400}, "souls": _n_souls(10), "wounds": _n_wounds(2), "eliminated": false},
			1: {"boss": {"xp": 300}, "souls": _n_souls(10), "wounds": _n_wounds(0), "eliminated": false},
		},
		"phase": "end", "gameOver": null, "turn": 1,
	}
	_ok(m._tie_break_players([0, 1]) == 1, "tie_break: ecart ames-blessures gagne (attendu 1)")

func _t_tie_break_lowest_boss_xp() -> void:
	var m = Match.new()
	add_child(m)
	m.G = {
		"players": {
			0: {"boss": {"xp": 500}, "souls": _n_souls(10), "wounds": _n_wounds(1), "eliminated": false},
			1: {"boss": {"xp": 200}, "souls": _n_souls(10), "wounds": _n_wounds(1), "eliminated": false},
		},
		"phase": "end", "gameOver": null, "turn": 1,
	}
	_ok(m._tie_break_players([0, 1]) == 1, "tie_break: XP boss le plus bas gagne (attendu 1)")

## Match.gd:_check_end_or_next_turn — 10 ames avec <5 blessures = victoire.
func _t_ten_souls_wins_under_five_wounds() -> void:
	var m = Match.new()
	add_child(m)
	m.G = {
		"players": {
			0: {"boss": {"xp": 300}, "souls": _n_souls(10), "wounds": _n_wounds(2), "eliminated": false,
				"dungeon": [], "hand": [], "buildsThisTurn": 0, "isAI": false},
			1: {"boss": {"xp": 300}, "souls": _n_souls(2), "wounds": _n_wounds(0), "eliminated": false,
				"dungeon": [], "hand": [], "buildsThisTurn": 0, "isAI": false},
		},
		"decks": {"heroes": [], "epics": [], "rooms": [], "roomDiscard": [], "spellDiscard": [], "heroDiscard": []},
		"town": [], "phase": "end", "gameOver": null, "turn": 1, "log": [],
	}
	m._check_end_or_next_turn()
	var go = m.G.get("gameOver")
	_ok(go != null and int((go as Dictionary).get("winner", -1)) == 0, "10 ames gagne (attendu joueur 0)")

## 5 blessures = elimination.
func _t_five_wounds_eliminates() -> void:
	var m = Match.new()
	add_child(m)
	m.G = {
		"players": {
			0: {"boss": {"xp": 300}, "souls": _n_souls(1), "wounds": _n_wounds(5), "eliminated": false,
				"dungeon": [], "hand": [], "buildsThisTurn": 0, "isAI": false},
			1: {"boss": {"xp": 300}, "souls": _n_souls(1), "wounds": _n_wounds(0), "eliminated": false,
				"dungeon": [], "hand": [], "buildsThisTurn": 0, "isAI": false},
		},
		"decks": {"heroes": [], "epics": [], "rooms": [], "roomDiscard": [], "spellDiscard": [], "heroDiscard": []},
		"town": [], "phase": "end", "gameOver": null, "turn": 1, "log": [],
	}
	m._check_end_or_next_turn()
	_ok(bool((m.G["players"][0] as Dictionary).get("eliminated", false)), "5 blessures -> elimine (attendu true)")

## CardDB.total_souls / total_wounds comptent les tableau entries.
func _t_souls_counting() -> void:
	_ok(CardDB.total_souls({"souls": _n_souls(10)}) == 10, "total_souls == 10")
	_ok(CardDB.total_wounds({"wounds": _n_wounds(5)}) == 5, "total_wounds == 5")

func _n_souls(n: int) -> Array:
	var a := []
	for i in n:
		a.append({"souls": 1})
	return a

func _n_wounds(n: int) -> Array:
	var a := []
	for i in n:
		a.append({"wounds": 1})
	return a

# --- engine.js:canBuildRoom (salles avancees) ---

func _player(dungeon: Array, hand: Array, builds: int = 0) -> Dictionary:
	return {"dungeon": dungeon, "hand": hand, "buildsThisTurn": builds, "id": 0}

func _room(id: String, t: String, advanced: bool, treasures: Array) -> Dictionary:
	return {"id": id, "type": t, "advanced": advanced, "treasures": treasures, "damage": 1, "isRoom": true}

## Une salle avancee ne peut se batir que sur une salle au tresor correspondant.
func _t_advanced_room_requires_treasures() -> void:
	var target := _room("BMA009", "trap", false, [1])
	var adv := _room("X", "trap", true, [2])          # tresor 2, cible n'a que 1
	_ok(not BossEngine.can_build_room(_player([[target]], [adv]), {}, 0, 0, 0),
		"avancee sans tresor commun refusee")
	var adv_ok := _room("X", "trap", true, [1])
	_ok(BossEngine.can_build_room(_player([[target]], [adv_ok]), {}, 0, 0, 0),
		"avancee avec tresor commun acceptee")

## BMA018 Neanderthal Cave : interdit de batir par-dessus.
func _t_advanced_room_rejects_neanderthal_cave() -> void:
	var cave := _room("BMA018", "monster", false, [1])
	var adv := _room("X", "trap", true, [1])
	_ok(not BossEngine.can_build_room(_player([[cave]], [adv]), {}, 0, 0, 0),
		"BMA018 refuse une salle avancee")

## Une salle ordinaire peut recouvrir une pile existante.
func _t_ordinary_room_over_existing_stack() -> void:
	var target := _room("BMA009", "trap", false, [1])
	var ord := _room("Y", "monster", false, [3])
	_ok(BossEngine.can_build_room(_player([[target]], [ord]), {}, 0, 0, 0),
		"ordinaire peut recouvrir")

## engine.js:healOneWound rend une ame face cachee.
func _t_heal_one_wound_returns_soul() -> void:
	var p := {"wounds": [{"name": "X", "wounds": 1}], "souls": []}
	var soul = BossEngine.heal_one_wound(p)
	_ok(soul != null, "healOneWound renvoie une ame")
	_ok(soul != null and bool((soul as Dictionary).get("faceDown", false)), "ame rendue face cachee")
	_ok((p["wounds"] as Array).is_empty(), "blessure retiree")
	_ok((p["souls"] as Array).size() == 1, "ame ajoutee")

# --- spellTargeting.js ---

func _spell_G(me: Dictionary) -> Dictionary:
	return {"players": {0: me, 1: {"dungeon": [], "hand": [], "entrance": [], "souls": [], "wounds": [], "items": [], "eliminated": false}}, "town": []}

## BMA042 (own-room) : uniquement les salles de son propre donjon.
func _t_spell_targeting_own_room() -> void:
	var me := {"dungeon": [[_room("BMA009", "trap", false, [1])]], "hand": [], "entrance": [], "souls": [], "wounds": [], "items": []}
	var t := SpellTargeting.enumerate_targets("own-room", _spell_G(me), me, 0)
	_ok(t.size() == 1 and int((t[0] as Dictionary).get("roomIndex", -1)) == 0, "own-room cible la salle 0")

## BMA040 (any-room-trap) : toutes les salles Trap, tous joueurs confondus.
func _t_spell_targeting_any_room_trap() -> void:
	var me := {"dungeon": [[_room("T", "trap", false, [1])], [_room("M", "monster", false, [1])]], "hand": [], "entrance": [], "souls": [], "wounds": [], "items": []}
	var G := _spell_G(me)
	(G["players"][1] as Dictionary)["dungeon"] = [[_room("T2", "trap", false, [2])]]
	var t := SpellTargeting.enumerate_targets("any-room-trap", G, me, 0)
	_ok(t.size() == 2, "any-room-trap trouve 2 cibles (attendues 2)")
	var has_monster := false
	for x in t:
		if int((x as Dictionary).get("roomIndex", -1)) == 1:
			has_monster = true
	_ok(not has_monster, "any-room-trap exclut les salles Monster")

## Un sort sans cible renvoie [null] (pas de ciblage).
func _t_spell_targeting_no_target_spell() -> void:
	var me := {"dungeon": [], "hand": [], "entrance": [], "souls": [], "wounds": [], "items": []}
	var t := SpellTargeting.spell_targets_for(_spell_G(me), me, 0, "BMA043")
	_ok(t.size() == 1 and (t[0] == null), "sort sans cible -> [null]")

## BMA054 Trepidation : joueur adverse avec 2 ames de plus.
func _t_spell_targeting_trepidation() -> void:
	var me := {"dungeon": [], "hand": [], "entrance": [], "souls": [{"souls": 2}], "wounds": [], "items": []}
	var G := _spell_G(me)
	(G["players"][1] as Dictionary)["souls"] = [{"souls": 4}]
	_ok(SpellTargeting.enumerate_targets("trepidation-player", G, me, 0).size() == 1, "trepidation: 4 >= 2+2 -> cible")
	(G["players"][1] as Dictionary)["souls"] = [{"souls": 3}]
	_ok(SpellTargeting.enumerate_targets("trepidation-player", G, me, 0).is_empty(), "trepidation: 3 < 2+2 -> aucune cible")

# --- spellEffects.gd (base set) ---

func _spell_state(me_rooms: Array = [], my_room_count: int = 0) -> Dictionary:
	var me := {"dungeon": me_rooms, "hand": [], "entrance": [], "souls": [], "wounds": [], "items": [], "eliminated": false}
	var foe := {"dungeon": [], "hand": [], "entrance": [], "souls": [], "wounds": [], "items": [], "eliminated": false}
	for i in my_room_count:
		(foe["dungeon"] as Array).append([_room("F%d" % i, "trap", false, [1])])
	return {"players": {0: me, 1: foe}, "town": [], "effects": SpellEffects.empty_effects(),
		"logs": [], "decks": {"rooms": [], "spells": [], "spellDiscard": [], "roomDiscard": [], "heroDiscard": []}}

## BMA040 Annihilator : exige une salle Trap.
func _t_spell_annihilator_requires_trap() -> void:
	var trap := _room("T", "trap", false, [1])
	var G := _spell_state([[trap]])
	_ok(SpellEffects.cast_spell(G, 0, {"id": "BMA040"}, {"roomIndex": 0}), "Annihilator accepte une Trap Room")
	_ok((G["effects"]["roomDamageBonus"] as Array).size() == 1, "Annihilator pose +3 degats")
	var G2 := _spell_state([[_room("M", "monster", false, [1])]])
	_ok(not SpellEffects.cast_spell(G2, 0, {"id": "BMA040"}, {"roomIndex": 0}), "Annihilator refuse une Monster Room")

## BMA047 Giant Size : exige une salle Monster.
func _t_spell_giant_size_requires_monster() -> void:
	var G := _spell_state([[_room("M", "monster", false, [1])]])
	_ok(SpellEffects.cast_spell(G, 0, {"id": "BMA047"}, {"roomIndex": 0}), "Giant Size accepte une Monster Room")
	var G2 := _spell_state([[_room("T", "trap", false, [1])]])
	_ok(not SpellEffects.cast_spell(G2, 0, {"id": "BMA047"}, {"roomIndex": 0}), "Giant Size refuse une Trap Room")

## BMA046 Freeze : desactive la salle cible.
func _t_spell_freeze_deactivates() -> void:
	var G := _spell_state([[_room("T", "trap", false, [1])]])
	_ok(SpellEffects.cast_spell(G, 0, {"id": "BMA046"}, {"roomIndex": 0}), "Freeze accepte")
	_ok((G["effects"]["deactivatedRooms"] as Array).size() == 1, "Freeze desactive une salle")

## BMA050 Motivation : bonus de construction si moins de salles qu'un adversaire.
func _t_spell_motivation_extra_build() -> void:
	var G := _spell_state([], 1)   # adversaire a 1 salle, moi 0
	_ok(SpellEffects.cast_spell(G, 0, {"id": "BMA050"}, {}), "Motivation accepte quand on a moins de salles")
	_ok((G["effects"]["extraBuild"] as Array).has(0), "Motivation accorde une construction")
	var G2 := _spell_state([[_room("T", "trap", false, [1])]], 1)  # egalite
	_ok(not SpellEffects.cast_spell(G2, 0, {"id": "BMA050"}, {}), "Motivation refuse a egalite")

## BMA048 Jeopardy : tout le monde defausse et pioche 1 sort + 2 salles.
func _t_spell_jeopardy_all_players() -> void:
	var G := _spell_state()
	# 2 joueurs x (1 sort + 2 salles) : le deck doit couvrir les deux tours.
	(G["decks"]["rooms"] as Array).append_array([_room("R1", "trap", false, [1]), _room("R2", "trap", false, [1]),
		_room("R3", "trap", false, [1]), _room("R4", "trap", false, [1])])
	(G["decks"]["spells"] as Array).append_array([{"id": "BMA040", "name": "Annihilator", "isSpell": true},
		{"id": "BMA047", "name": "Giant Size", "isSpell": true}])
	_ok(SpellEffects.cast_spell(G, 0, {"id": "BMA048"}, {}), "Jeopardy accepte")
	_ok(((G["players"][0] as Dictionary)["hand"] as Array).size() == 3, "moi recoit 1 sort + 2 salles")
	_ok(((G["players"][1] as Dictionary)["hand"] as Array).size() == 3, "l'adversaire recoit 1 sort + 2 salles")

## Un sort sans effet implemente renvoie false (et journalise).
func _t_spell_unknown_returns_false() -> void:
	var G := _spell_state()
	_ok(not SpellEffects.cast_spell(G, 0, {"id": "ZZZ999", "name": "Unknown"}, {}), "sort inconnu -> false")
	_ok((G["logs"] as Array).size() == 1, "sort inconnu journalise")

## emptyEffects doit exposer les cles consommees par BossEngine/SpellTargeting.
func _t_spell_empty_effects_shape() -> void:
	var e := SpellEffects.empty_effects()
	for k in ["roomDamageBonus", "heroHealthBonus", "heroDamage", "deactivatedRooms",
			"extraBuild", "noEntry", "buildBlocked"]:
		_ok(e.has(k), "empty_effects contient " + k)

# --- integration : playSpell dans le moteur de jeu ---

func _match_with_spell() -> Node:
	var m = load("res://godot/scripts/Match.gd").new()
	add_child(m)
	m.G = {
		"players": {
			0: {"boss": {"xp": 300, "treasures": [1]}, "dungeon": [[_room("T", "trap", false, [1])]],
				"hand": [{"id": "BMA050", "name": "Motivation", "isSpell": true}], "souls": [], "wounds": [],
				"eliminated": false, "leveledUp": false, "buildsThisTurn": 0, "isAI": false, "entrance": []},
			1: {"boss": {"xp": 300, "treasures": [1]}, "dungeon": [[_room("F", "trap", false, [1])], [_room("F2", "trap", false, [1])]],
				"hand": [], "souls": [], "wounds": [], "eliminated": false, "leveledUp": false,
				"buildsThisTurn": 0, "isAI": true, "entrance": []},
		},
		"decks": {"rooms": [], "spells": [], "heroes": [], "epics": [], "roomDiscard": [], "spellDiscard": [], "heroDiscard": []},
		"town": [], "turn": 1, "phase": "build", "gameOver": null, "log": [], "effects": SpellEffects.empty_effects(),
	}
	return m

## Un sort en main doit apparaitre parmi les coups legaux en phase BUILD.
func _t_play_spell_appears_in_legal_moves() -> void:
	var m = _match_with_spell()
	var spells := 0
	for mv in m.legal_moves(0):
		if str((mv as Dictionary).get("type", "")) == "playSpell":
			spells += 1
	_ok(spells == 1, "Motivation apparait dans les coups legaux (trouve %d)" % spells)
	m.queue_free()

## Jouer le sort le consomme et applique son effet.
func _t_play_spell_consumes_card() -> void:
	var m = _match_with_spell()
	var mv: Dictionary = {}
	for cand in m.legal_moves(0):
		if str((cand as Dictionary).get("type", "")) == "playSpell":
			mv = cand
			break
	_ok(m.apply_move(0, mv), "playSpell applique")
	_ok(((m.G["players"][0] as Dictionary)["hand"] as Array).is_empty(), "le sort est consomme")
	_ok((SpellEffects._effects(m.G)["extraBuild"] as Array).has(0), "Motivation accorde la construction")
	m.queue_free()

# --- roomAbilities.gd (base set) ---

func _ability_G(room_id: String, room_cards: Array = []) -> Dictionary:
	var p := {"id": 0, "dungeon": [[_room(room_id, "trap", false, [1])]], "hand": room_cards,
		"souls": [], "wounds": [], "entrance": [], "items": [], "eliminated": false, "buildsThisTurn": 0}
	return {"players": {0: p, 1: {"id": 1, "dungeon": [], "hand": [], "souls": [], "wounds": [],
		"entrance": [], "items": [], "eliminated": false}},
		"town": [], "logs": [], "adventure": {},
		"effects": SpellEffects.empty_effects(),
		"decks": {"rooms": [], "spells": [], "heroes": [], "roomDiscard": [], "spellDiscard": [], "heroDiscard": []}}

## BMA009 Dark Altar : detruit la salle et recupere une carte de la defausse.
## Apres destruction la defausse contient la carte detruite : avec defausse vide on
## recupere automatiquement, avec 2+ options l'engine ouvre un choix.
## --- Level up des boss (roomAbilities.js:processLevelUp) ---
## Le level-up se declenche a 5 salles visibles et une seule fois par joueur.

func _levelup_G(boss_id: String, visible: int) -> Dictionary:
	var p := {"id": 0, "boss": {"id": boss_id, "name": boss_id, "xp": 300},
		"dungeon": [], "hand": [], "souls": [], "wounds": [], "entrance": [],
		"items": [], "eliminated": false, "buildsThisTurn": 0, "leveledUp": false}
	for i in visible:
		(p["dungeon"] as Array).append([_room("R%d" % i, "trap", false, [1])])
	return {"players": {0: p, 1: {"id": 1, "boss": {"id": "BMA001", "name": "Adv", "xp": 300},
		"dungeon": [], "hand": [], "souls": [], "wounds": [], "entrance": [],
		"items": [], "eliminated": false, "buildsThisTurn": 0, "leveledUp": false}},
		"town": [], "log": [], "logs": [], "adventure": {}, "turn": 1,		"effects": SpellEffects.empty_effects(),
		"decks": {"rooms": [], "spells": [], "heroes": [], "epics": [],
			"roomDiscard": [], "spellDiscard": [], "heroDiscard": []}}

func _t_levelup_requires_5_visible_rooms() -> void:
	for n in [0, 4, 5]:
		var G := _levelup_G("BMA001", n)
		var m = Match.new()
		add_child(m)
		m.G = G
		var opened := m._reveal_and_level_up()
		if n < 5:
			_ok(not opened and not (G["players"][0] as Dictionary).get("leveledUp", false),
				"%d salles visibles : pas de level-up" % n)
		else:
			_ok((G["players"][0] as Dictionary).get("leveledUp", false),
				"5 salles visibles : level-up declenche")
		m.queue_free()

func _t_levelup_draculord_steals() -> void:
	var G := _levelup_G("BMA001", 5)
	((G["players"][1] as Dictionary)["hand"] as Array).append({"id": "SP1", "name": "Fire", "isSpell": true})
	var c = RoomAbilities.process_level_up(G, 0)
	_ok(c != null and str((c as Dictionary).get("type", "")) == "steal-card",
		"Draculord ouvre un choix steal-card")
	var opts: Array = (c as Dictionary).get("options", [])
	_ok(opts.size() == 1 and str((opts[0] as Dictionary).get("card", {}).get("name", "")) == "Fire",
		"la seule carte adverse est proposee")

func _t_levelup_xyzax_recovers_two() -> void:
	# Defausse vide : rien a faire, pas de choix.
	var G0 := _levelup_G("BMA002", 5)
	_ok(RoomAbilities.process_level_up(G0, 0) == null,
		"Xyzax sans defausse : aucun choix")
	# Une seule carte : recuperation automatique, pas de choix.
	var G1 := _levelup_G("BMA002", 5)
	(G1["decks"]["roomDiscard"] as Array).append(_room("A", "trap", false, [1]))
	_ok(RoomAbilities.process_level_up(G1, 0) == null, "Xyzax avec 1 carte : automatique")
	_ok(((G1["players"][0] as Dictionary)["hand"] as Array).size() == 1, "la carte est recuperee en main")
	# 3+ cartes : choix ouvert.
	var G2 := _levelup_G("BMA002", 5)
	for i in 3:
		(G2["decks"]["roomDiscard"] as Array).append(_room("D%d" % i, "trap", false, [1]))
	var c = RoomAbilities.process_level_up(G2, 0)
	_ok(c != null and str((c as Dictionary).get("type", "")) == "recover-card", "Xyzax avec 3+ cartes : choix")
	_ok(int((c as Dictionary).get("remaining", 0)) == 2, "il reste 2 recuperations")

func _t_levelup_cerebellus_draws_three() -> void:
	var G := _levelup_G("BMA005", 5)
	for i in 3:
		(G["decks"]["spells"] as Array).append({"id": "SP%d" % i, "name": "S%d" % i, "isSpell": true})
	var hand: Array = (G["players"][0] as Dictionary)["hand"]
	var c = RoomAbilities.process_level_up(G, 0)
	_ok(hand.size() == 3, "3 sorts sont pioches en main")
	_ok(c != null and str((c as Dictionary).get("type", "")) == "discard-spell",
		"Cerebellus ouvre un choix discard-spell")
	_ok(((c as Dictionary).get("options", []) as Array).size() == 3, "les 3 cartes sont proposees")
	# Un seul sort pioche : defausse automatique, aucun choix.
	var G1 := _levelup_G("BMA005", 5)
	(G1["decks"]["spells"] as Array).append({"id": "SP0", "name": "Only", "isSpell": true})
	_ok(RoomAbilities.process_level_up(G1, 0) == null, "Cerebellus avec 1 sort : automatique")
	_ok(((G1["decks"]["spellDiscard"] as Array)).size() == 1, "le sort unique part en defausse")

func _t_levelup_gorgona_kills_town_hero() -> void:
	# Un seul heros en ville : destruction automatique + ame capturee.
	var G := _levelup_G("BMA008", 5)
	(G["town"] as Array).append({"id": "H1", "name": "Hero", "souls": 2})
	_ok(RoomAbilities.process_level_up(G, 0) == null, "Gorgona avec 1 heros : automatique")
	_ok((G["town"] as Array).is_empty(), "le heros est detruit")
	var souls: Array = (G["players"][0] as Dictionary)["souls"]
	_ok(souls.size() == 2, "ses 2 ames sont capturees")
	# Plusieurs heros : le joueur choisit.
	var G2 := _levelup_G("BMA008", 5)
	(G2["town"] as Array).append({"id": "H1", "name": "A", "souls": 1})
	(G2["town"] as Array).append({"id": "H2", "name": "B", "souls": 1})
	var c = RoomAbilities.process_level_up(G2, 0)
	_ok(c != null and str((c as Dictionary).get("type", "")) == "kill-hero", "Gorgona avec 2 heros : choix")
	_ok(((c as Dictionary).get("options", []) as Array).size() == 2, "les 2 heros sont proposes")

func _t_levelup_king_croak_searches_advanced() -> void:
	var G := _levelup_G("BMA003", 5)
	# Seules les salles avancees du bon type sont proposees.
	(G["decks"]["rooms"] as Array).append(_room("Ord", "trap", false, [1]))
	(G["decks"]["rooms"] as Array).append(_room("AdvMon", "monster", true, [1, 2]))
	(G["decks"]["roomDiscard"] as Array).append(_room("AdvMon2", "monster", true, [1, 3]))
	var c = RoomAbilities.process_level_up(G, 0)
	_ok(c != null and bool((c as Dictionary).get("optional", false)), "le choix est facultatif")
	var opts: Array = (c as Dictionary).get("options", [])
	_ok(opts.size() == 2, "seules les 2 salles Monster avancees sont proposees")
	_ok(str((opts[0] as Dictionary).get("pile", "")) == "deck"
		and str((opts[1] as Dictionary).get("pile", "")) == "discard", "pioche et defausse incluses")
	# Cleopatra cherche des Traps.
	var G2 := _levelup_G("BMA007", 5)
	(G2["decks"]["rooms"] as Array).append(_room("AdvTrap", "trap", true, [1]))
	var c2 = RoomAbilities.process_level_up(G2, 0)
	_ok(c2 != null and str((c2 as Dictionary).get("roomType", "")) == "trap", "Cleopatra cherche des Traps")

func _t_levelup_robobo_targets_opponent() -> void:
	var G := _levelup_G("BMA004", 5)
	# Un adversaire a une salle, l'autre est vide : file = 1 seul adversaire.
	((G["players"][1] as Dictionary)["dungeon"] as Array).append([_room("V", "trap", false, [1])])
	var c = RoomAbilities.process_level_up(G, 0)
	_ok(c != null and str((c as Dictionary).get("type", "")) == "destroy-room", "Robobo ouvre un choix")
	_ok(int((c as Dictionary).get("playerId", -1)) == 1, "l'adversaire detruit sa propre salle")
	_ok((G["roboboQueue"] as Array).is_empty(), "aucun adversaire en file")
	# Aucun donjon adverse : rien a faire.
	var G2 := _levelup_G("BMA004", 5)
	_ok(RoomAbilities.process_level_up(G2, 0) == null, "Robobo sans adversaire : aucun choix")

func _t_levelup_unknown_boss_noop() -> void:
	var G := _levelup_G("XXX999", 5)
	_ok(RoomAbilities.process_level_up(G, 0) == null, "boss inconnu : aucun choix")
	# Un joueur sans boss est ignore.
	var G2 := _levelup_G("BMA001", 5)
	(G2["players"][0] as Dictionary).erase("boss")
	_ok(RoomAbilities.process_level_up(G2, 0) == null, "joueur sans boss : aucun choix")

func _t_room_ability_dark_altar() -> void:
	var G := _ability_G("BMA009")
	_ok(RoomAbilities.activate_room_ability(G, 0, 0) == null, "Dark Altar s'active sans erreur")
	_ok(((G["players"][0] as Dictionary)["dungeon"] as Array).is_empty(), "Dark Altar detruit sa salle")
	# Defausse vide au depart : la carte detruite est la seule option, recuperee en main.
	_ok(((G["players"][0] as Dictionary)["hand"] as Array).size() == 1,
		"la carte detruite est recuperee en main")
	_ok((G["decks"]["roomDiscard"] as Array).is_empty(), "defausse vide apres recuperation")
	# Defausse pre-remplie : plusieurs options -> l'engine ouvre un choix.
	var G2 := _ability_G("BMA009")
	(G2["decks"]["roomDiscard"] as Array).append(_room("X", "trap", false, [1]))
	_ok(RoomAbilities.activate_room_ability(G2, 0, 0) == null, "Dark Altar (multi) s'active")
	var pending: Dictionary = G2.get("pendingChoice", {}) as Dictionary
	_ok(not pending.is_empty() and str(pending.get("type", "")) == "recover-card",
		"plusieurs options -> choix ouvert")

## BMA030 Jackpot Stash : double les tresors du joueur.
func _t_room_ability_jackpot_stash() -> void:
	var G := _ability_G("BMA030")
	var err = RoomAbilities.activate_room_ability(G, 0, 0)
	_ok(err == null, "Jackpot Stash s'active")
	_ok((SpellEffects._effects(G)["treasureDoubled"] as Array).has(0), "Jackpot Stash double les tresors")

## Une salle sans abilite activable renvoie un message, pas une erreur fatale.
func _t_room_ability_unknown_rejected() -> void:
	var G := _ability_G("BMA010")
	var err = RoomAbilities.activate_room_ability(G, 0, 0)
	_ok(err != null, "salle sans abilite -> message d'erreur")
	_ok(not ((G["players"][0] as Dictionary)["dungeon"] as Array).is_empty(), "la salle n'est pas detruite")

## Les salles activables apparaissent dans les coups legaux.
func _t_activate_room_appears_in_legal_moves() -> void:
	var m = load("res://godot/scripts/Match.gd").new()
	add_child(m)
	m.G = {
		"players": {
			0: {"boss": {"xp": 300, "treasures": [1]}, "dungeon": [[_room("BMA009", "trap", false, [1])]],
				"hand": [], "souls": [], "wounds": [], "eliminated": false, "leveledUp": false,
				"buildsThisTurn": 0, "isAI": false, "entrance": []},
			1: {"boss": {"xp": 300, "treasures": [1]}, "dungeon": [], "hand": [], "souls": [],
				"wounds": [], "eliminated": false, "leveledUp": false, "buildsThisTurn": 0,
				"isAI": true, "entrance": []},
		},
		"decks": {"rooms": [], "spells": [], "heroes": [], "epics": [], "roomDiscard": [], "spellDiscard": [], "heroDiscard": []},
		"town": [], "turn": 1, "phase": "build", "gameOver": null, "log": [], "effects": SpellEffects.empty_effects(),
	}
	var found := 0
	for mv in m.legal_moves(0):
		if str((mv as Dictionary).get("type", "")) == "activateRoom":
			found += 1
	_ok(found == 1, "Dark Altar propose activateRoom (trouve %d)" % found)
	m.queue_free()

## Un pendingChoice gele les coups : seuls resolveChoice sont proposes.
func _t_pending_choice_freezes_legal_moves() -> void:
	var m = load("res://godot/scripts/Match.gd").new()
	add_child(m)
	m.G = {
		"players": {
			0: {"boss": {"xp": 300, "treasures": [1]}, "dungeon": [[_room("BMA009", "trap", false, [1])]],
				"hand": [{"id": "BMA050", "name": "Motivation", "isSpell": true}], "souls": [], "wounds": [],
				"eliminated": false, "leveledUp": false, "buildsThisTurn": 0, "isAI": false, "entrance": []},
			1: {"boss": {"xp": 300, "treasures": [1]}, "dungeon": [], "hand": [], "souls": [], "wounds": [],
				"eliminated": false, "leveledUp": false, "buildsThisTurn": 0, "isAI": true, "entrance": []},
		},
		"decks": {"rooms": [], "spells": [], "heroes": [], "epics": [], "roomDiscard": [], "spellDiscard": [], "heroDiscard": []},
		"town": [], "turn": 1, "phase": "build", "gameOver": null, "log": [], "effects": SpellEffects.empty_effects(),
		"pendingChoice": {"type": "recover-card", "playerId": 0, "options": [{"card": _room("X", "trap", false, [1])}]},
	}
	var kinds: Array = []
	for mv in m.legal_moves(0):
		kinds.append(str((mv as Dictionary).get("type", "")))
	_ok(kinds.size() == 1 and kinds[0] == "resolveChoice",
		"pendingChoice gele les coups (trouve %s)" % str(kinds))
	_ok(not kinds.has("playSpell"), "aucun sort pendant un choix")
	m.queue_free()

## resolveChoice 'recover-card' met la carte choisie en main.
func _t_resolve_choice_recover_card() -> void:
	var m = load("res://godot/scripts/Match.gd").new()
	add_child(m)
	var wanted := _room("X", "trap", false, [1])
	m.G = _choice_G("recover-card", [{"card": wanted, "pile": "room", "pileIndex": 0}])
	_ok(m.apply_move(0, {"type": "resolveChoice", "args": [0]}), "resolveChoice applique")
	var hand: Array = (m.G["players"][0] as Dictionary)["hand"]
	_ok(hand.size() == 1 and str((hand[0] as Dictionary).get("id", "")) == "X", "la carte choisie est en main")
	_ok((m.G["decks"]["roomDiscard"] as Array).is_empty(), "la defausse est videe")
	m.queue_free()

## resolveChoice 'discard-spell' retire le sort de la main vers la defausse.
func _t_resolve_choice_discard_spell() -> void:
	var m = load("res://godot/scripts/Match.gd").new()
	add_child(m)
	var spell := {"id": "BMA040", "name": "Annihilator", "isSpell": true}
	m.G = _choice_G("discard-spell", [{"card": spell}], [spell])
	_ok(m.apply_move(0, {"type": "resolveChoice", "args": [0]}), "resolveChoice applique")
	_ok(((m.G["players"][0] as Dictionary)["hand"] as Array).is_empty(), "le sort quitte la main")
	_ok((m.G["decks"]["spellDiscard"] as Array).size() == 1, "le sort va en defausse")
	m.queue_free()

## Apres resolution, pendingChoice est vide et la partie reprend.
func _t_resolve_choice_clears_pending() -> void:
	var m = load("res://godot/scripts/Match.gd").new()
	add_child(m)
	var wanted := _room("X", "trap", false, [1])
	m.G = _choice_G("recover-card", [{"card": wanted, "pile": "room", "pileIndex": 0}])
	m.apply_move(0, {"type": "resolveChoice", "args": [0]})
	_ok((m.G.get("pendingChoice", {}) as Dictionary).is_empty(), "pendingChoice est vide apres resolution")
	var has_choice := false
	for mv in m.legal_moves(0):
		if str((mv as Dictionary).get("type", "")) == "resolveChoice":
			has_choice = true
	_ok(not has_choice, "les coups normaux reprennent")
	m.queue_free()

## --- abilities passives (onBuildRoom / onHeroDiedInRoom) ---

## BMA016 Golem Factory : pioche une salle quand un hero y meurt.
func _t_build_golem_factory_draws_room() -> void:
	var G := _ability_G("BMA016")
	(G["decks"]["rooms"] as Array).append(_room("R", "trap", false, [1]))
	var choice = RoomAbilities.on_hero_died_in_room(G, 0, (BossEngine.active_room(((G["players"][0] as Dictionary)["dungeon"] as Array)[0]) as Dictionary))
	_ok(choice == null, "Golem Factory n'ouvre pas de choix")
	_ok(((G["players"][0] as Dictionary)["hand"] as Array).size() == 1, "Golem Factory pioche une salle")

## Golem Factory ne se declenche qu'une fois par tour.
func _t_died_golem_factory_once_per_turn() -> void:
	var G := _ability_G("BMA016")
	(G["decks"]["rooms"] as Array).append_array([_room("R1", "trap", false, [1]), _room("R2", "trap", false, [1])])
	var room: Dictionary = BossEngine.active_room(((G["players"][0] as Dictionary)["dungeon"] as Array)[0])
	RoomAbilities.on_hero_died_in_room(G, 0, room)
	_ok(room.get("usedThisTurn", false), "la salle est marquee utilisee")
	RoomAbilities.on_hero_died_in_room(G, 0, room)
	_ok(((G["players"][0] as Dictionary)["hand"] as Array).size() == 1, "une seule pioche par tour")

## BMA034 Construction Zone : rend une construction.
func _t_build_construction_zone_refunds_build() -> void:
	var G := _ability_G("BMA034")
	(G["players"][0] as Dictionary)["buildsThisTurn"] = 1
	RoomAbilities.on_build_room(G, 0, _room("BMA034", "trap", false, [1]))
	_ok(int((G["players"][0] as Dictionary)["buildsThisTurn"]) == 0, "Construction Zone rend la construction")

## BMA021 Brainsucker Hive : pioche un sort quand un hero y meurt.
func _t_build_brainsucker_hive_draws_spell() -> void:
	var G := _ability_G("BMA021")
	(G["decks"]["spells"] as Array).append({"id": "BMA040", "name": "Annihilator", "isSpell": true})
	var room: Dictionary = BossEngine.active_room(((G["players"][0] as Dictionary)["dungeon"] as Array)[0])
	RoomAbilities.on_hero_died_in_room(G, 0, room)
	var hand: Array = (G["players"][0] as Dictionary)["hand"]
	_ok(hand.size() == 1 and str((hand[0] as Dictionary).get("id", "")) == "BMA040", "Brainsucker Hive pioche un sort")

## BMA022 Dark Laboratory : ouvre un choix quand 2 sorts sont pioches.
func _t_build_dark_laboratory_opens_choice() -> void:
	var G := _ability_G("BMA022")
	(G["decks"]["spells"] as Array).append_array([
		{"id": "BMA040", "name": "A", "isSpell": true},
		{"id": "BMA047", "name": "B", "isSpell": true}])
	var choice = RoomAbilities.on_build_room(G, 0, _room("BMA022", "trap", false, [1]))
	_ok(choice != null and str((choice as Dictionary).get("type", "")) == "discard-spell",
		"Dark Laboratory ouvre un choix discard-spell")
	_ok(((choice as Dictionary)["options"] as Array).size() == 2, "2 options proposees")

## BMA014 Vampire Bordello : soigne une blessure.
func _t_died_vampire_bordello_heals() -> void:
	var G := _ability_G("BMA014")
	(G["players"][0] as Dictionary)["wounds"] = [{"name": "X", "wounds": 1}]
	var room: Dictionary = BossEngine.active_room(((G["players"][0] as Dictionary)["dungeon"] as Array)[0])
	RoomAbilities.on_hero_died_in_room(G, 0, room)
	var p: Dictionary = G["players"][0]
	_ok((p["wounds"] as Array).is_empty(), "la blessure est retiree")
	_ok(CardDB.total_souls(p) == 1, "une ame face cachee est rendue")

## Etat de test : un joueur 0 avec un pendingChoice qui lui appartient.
## discard_alimentee place les cartes des options dans la defausse correspondante.
func _choice_G(kind: String, options: Array, hand: Array = [], discard_alimentee: bool = true) -> Dictionary:
	var rooms: Array = []
	var spells: Array = []
	for o in options:
		var c: Dictionary = (o as Dictionary).get("card", {}) as Dictionary
		if str((o as Dictionary).get("pile", "room")) == "spell":
			spells.append(c)
		else:
			rooms.append(c)
	return {
		"players": {
			0: {"id": 0, "boss": {"xp": 300, "treasures": [1]}, "dungeon": [], "hand": hand.duplicate(),
				"souls": [], "wounds": [], "eliminated": false, "leveledUp": false, "buildsThisTurn": 0,
				"isAI": false, "entrance": []},
			1: {"id": 1, "boss": {"xp": 300, "treasures": [1]}, "dungeon": [], "hand": [], "souls": [],
				"wounds": [], "eliminated": false, "leveledUp": false, "buildsThisTurn": 0, "isAI": true, "entrance": []},
		},
		"decks": {"rooms": [], "spells": [], "heroes": [], "epics": [],
			"roomDiscard": rooms if discard_alimentee else [], "spellDiscard": spells if discard_alimentee else [], "heroDiscard": []},
		"town": [], "turn": 1, "phase": "build", "gameOver": null, "log": [], "effects": SpellEffects.empty_effects(),
		"pendingChoice": {"type": kind, "playerId": 0, "bossName": "Test", "message": "Choisissez", "options": options},
	}
