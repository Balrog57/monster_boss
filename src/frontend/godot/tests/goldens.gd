extends Node
## Goldens — invariants de l'engine.
## But : verrouiller les regles du port GDScript (Match.gd) contre les regressions.
## Lance par res://godot/tests/Goldens.tscn (headless).

var _failed: Array = []
var _passed := 0

func _ready() -> void:
	_t_tie_break_souls_minus_wounds()
	_t_tie_break_highest_boss_xp()
	_t_base_decks_exclude_not_in_game_cards()
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
	_t_spell_cave_in_kills_hero_in_room()
	_t_spell_motivation_extra_build()
	_t_spell_jeopardy_all_players()
	_t_spell_unknown_returns_false()
	_t_spell_empty_effects_shape()
	_t_play_spell_appears_in_legal_moves()
	_t_play_spell_consumes_card()
	_t_room_ability_dark_altar()
	_t_room_ability_jackpot_stash()
	_t_lure_jackpot_stash_doubles_room_treasures()
	_t_lure_fool_fewest_souls()
	_t_freeze_room_deals_no_damage()
	_t_destroy_slot_shifts_effects_and_replays_hero()
	_t_xyzax_recovers_two_cards()
	_t_seducia_picks_from_hero_deck()
	_t_full_dungeon_ordinary_over_stack()
	_t_build_window_after_last_build()
	_t_build_window_ai_plays_spell()
	_t_choice_in_build_window_keeps_window()
	_t_ability_kill_finishes_hero()
	_t_zombie_attack_returns_whole_hero()
	_t_reveal_heroes_counts_eliminated_and_effects_expire()
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
	_t_choice_dark_altar()
	_t_choice_dark_laboratory()
	_t_choice_all_seeing_eye()
	_t_spell_phase_windows()
	_t_freeze_offturn_in_adventure()
	_t_spell_target_room_active_only()
	_t_stack_resolution_order()
	_t_counterspell_stack_chain()
	_t_spell_battle_open_responses()
	_t_choice_draculord()
	_t_choice_robobo()
	_t_choice_cleopatra_forced_build()
	_t_room_damage_goblin_dizzygas_target_type()
	_t_build_specters_sanctum_choice_discards()
	_t_specters_sanctum_offers_all_opponents()
	_t_choice_dracolich_lair()
	_t_room_zombie_prison()
	_t_room_beast_menagerie()
	_t_room_torture_chamber_discards_room()
	_t_build_motivation_extra_room()
	_t_setup_avoid_mulligan()
	_t_setup_parallel_first_room()
	_t_extra_build_phase_construction_zone()
	_t_build_offturn_spell_window()
	_t_human_build_waits_for_done()
	_t_destroy_recycling_center_draws_two()
	_t_crushinator_repeatable_fear_active_hero()
	_t_trepidation_skips_adventure()
	_t_minotaur_maze_sends_hero_back()
	_t_reveal_levelup_before_room_trigger()
	_t_witchs_kitchen_choice()
	_t_died_brainsucker_once_per_turn()
	_t_pit_kill_no_death_trigger_on_next_room()
	_t_destroy_hero_slot_traverses_empty_slots()
	_t_exhaustion_ignores_frozen_rooms()
	_t_vampire_bordello_choice_flips_whole_hero()
	_t_neanderthal_cave_accepts_ordinary_over()
	_t_kobold_strike_returns_rooms_to_hand()
	_t_hero_deck_is_never_reshuffled()
	_t_spell_room_buff_survives_destruction()
	_t_dragon_hatchery_all_four_treasures()
	_t_trepidation_removes_active_hero_only_in_pre_adventure()
	_t_entrance_persists_across_turns()
	_t_haunted_library_chooses_draw()
	_t_succubus_spa_steals_random_card()

	load("res://godot/tests/goldens_decks.gd").new().run(_ok, self) # paquets APK : PlayerChoice (KSA), HiddenHeros (BMH), ToolsHeroKind (THK)
	load("res://godot/tests/goldens_tnl.gd").new().run(_ok, self) # extension The Next Level (TNL, hors APK)
	load("res://godot/tests/goldens_crl.gd").new().run(_ok, self) # extension wiki Crash Landing (CRL, hors APK)
	load("res://godot/tests/goldens_rmb.gd").new().run(_ok, self) # extension wiki Rise of the Minibosses (RMB, hors APK)
	load("res://godot/tests/goldens_undo.gd").new().run(_ok, self) # APK : pool de boss complet, pose de salle revocable jusqu'a DONE
	load("res://godot/tests/goldens_ai.gd").new().run(_ok, self) # IA : cartes wiki jouees dans la bonne situation, construction immediate dans un nouvel emplacement

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

## Match.gd:_tie_break_players — ecart ames-blessures d'abord, puis XP boss la plus haute (APK : GetLessExperiencePlayerToWin trie par PlayerId,
## attribue par XP decroissante).
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

func _t_tie_break_highest_boss_xp() -> void:
	var m = Match.new()
	add_child(m)
	m.G = {
		"players": {
			0: {"boss": {"xp": 40}, "souls": _n_souls(10), "wounds": _n_wounds(0), "eliminated": false},
			1: {"boss": {"xp": 50}, "souls": _n_souls(10), "wounds": _n_wounds(0), "eliminated": false},
			2: {"boss": {"xp": 50}, "souls": _n_souls(10), "wounds": _n_wounds(0), "eliminated": false},
		},
		"phase": "end", "gameOver": null, "turn": 1,
	}
	_ok(m._tie_break_players([0, 1]) == 1, "tie_break: a egalite d'ames, XP 40 vs 50 -> le 50 gagne (attendu 1)")
	_ok(m._tie_break_players([0, 1, 2]) == 1, "tie_break: XP egale entre 1 et 2 -> l'ordre des sieges (attendu 1)")
	m.queue_free()

## CardInfoService.notInGameCards : BMA023 / BMA033 ne sont jamais distribuees ; il reste 71 salles dans la pioche du jeu de base.
func _t_base_decks_exclude_not_in_game_cards() -> void:
	var m = Match.new()
	add_child(m)
	m.new_match(2, 1, ["base"])
	var ids: Array = (m.G["decks"]["rooms"] as Array).map(func(r): return str((r as Dictionary).get("id", "")))
	_ok(not ids.has("BMA023") and not ids.has("BMA033"), "pioche de salles : ni BMA023 ni BMA033")
	_ok(ids.size() == 71, "pioche de salles du jeu de base : 71 cartes (obtenu %d)" % ids.size())
	m.queue_free()

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
	return {"id": id, "name": id, "type": t, "advanced": advanced, "treasures": treasures, "damage": 1, "isRoom": true}

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
	var t := SpellTargeting.spell_targets_for(_spell_G(me), me, 0, "BMA048")
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
	_ok(int(trap.get("dealDamage", 0)) == 3 and BossEngine.room_damage_with_modifiers(G, G["players"][0], 0, {}) == 4, "Annihilator pose +3 degats sur la carte (Room.DealDamage)")
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

## BMA042 Cave-In : detruit la salle et le heros qui s'y trouve (KillHeroInRoom + DestroyRoom).
func _t_spell_cave_in_kills_hero_in_room() -> void:
	var G := _spell_state([[_room("A", "trap", false, [1])], [_room("B", "trap", false, [1])]])
	G["adventure"] = {"playerId": 0, "hero": {"id": "H", "name": "H"}, "roomIndex": 1, "hp": 5, "pause": null}
	_ok(SpellEffects.cast_spell(G, 0, {"id": "BMA042"}, {"roomIndex": 1}), "Cave-In accepte")
	_ok(int((G["adventure"] as Dictionary)["hp"]) == 0, "Cave-In tue le heros de la salle detruite")
	_ok(((G["players"][0] as Dictionary)["dungeon"] as Array).size() == 1, "Cave-In detruit la salle")
	var G2 := _spell_state([[_room("A", "trap", false, [1])], [_room("B", "trap", false, [1])]])
	G2["adventure"] = {"playerId": 0, "hero": {"id": "H", "name": "H"}, "roomIndex": 0, "hp": 5, "pause": null}
	SpellEffects.cast_spell(G2, 0, {"id": "BMA042"}, {"roomIndex": 1})
	_ok(int((G2["adventure"] as Dictionary)["hp"]) == 5, "Cave-In epargne un heros dans une autre salle")

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
	# Spell Battle (GameBoard.OnAbilityApplyRequest) : le sort reste sur la pile tant que l'adversaire n'a pas passe.
	_ok(m.apply_move(1, {"type": "pass", "args": []}), "l'adversaire passe")
	_ok(m.active_player() == 0, "la main revient au joueur de phase")
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
		if n == 5: # GameBoard.RevealAllRoomCards : le level-up part a la revelation du slot qui porte le donjon a 5
			((((G["players"][0] as Dictionary)["dungeon"] as Array)[4] as Array)[0] as Dictionary)["faceDown"] = true
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
	((G["players"][1] as Dictionary)["hand"] as Array).append({"id": "SP2", "name": "Ice", "isSpell": true})
	var c = RoomAbilities.process_level_up(G, 0)
	_ok(c != null and str((c as Dictionary).get("type", "")) == "steal-card",
		"Draculord ouvre un choix steal-card")
	var opts: Array = (c as Dictionary).get("options", [])
	_ok(opts.size() == 2 and str((opts[0] as Dictionary).get("card", {}).get("name", "")) == "Fire",
		"les cartes adverses sont proposees")

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
	_ok(c != null and not bool((c as Dictionary).get("optional", false)), "le choix est obligatoire (CanAvoid=false)")
	var opts: Array = (c as Dictionary).get("options", [])
	_ok(opts.size() == 2, "seules les 2 salles Monster avancees sont proposees")
	_ok(str((opts[0] as Dictionary).get("pile", "")) == "deck"
		and str((opts[1] as Dictionary).get("pile", "")) == "discard", "pioche et defausse incluses")
	# Cleopatra cherche des Traps.
	var G2 := _levelup_G("BMA007", 5)
	(G2["decks"]["rooms"] as Array).append(_room("AdvTrap", "trap", true, [1]))
	(G2["decks"]["roomDiscard"] as Array).append(_room("AdvTrap2", "trap", true, [2]))
	var c2 = RoomAbilities.process_level_up(G2, 0)
	_ok(c2 != null and str((c2 as Dictionary).get("roomType", "")) == "trap", "Cleopatra cherche des Traps")

func _t_levelup_robobo_targets_opponent() -> void:
	var G := _levelup_G("BMA004", 5)
	# Un adversaire a une salle, l'autre est vide : file = 1 seul adversaire.
	((G["players"][1] as Dictionary)["dungeon"] as Array).append([_room("V", "trap", false, [1])])
	((G["players"][1] as Dictionary)["dungeon"] as Array).append([_room("V2", "trap", false, [1])])
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
	# Defausse vide : abilite inutilisable (Ability.CheckConditions), la salle reste en place.
	var G := _ability_G("BMA009")
	_ok(RoomAbilities.activate_room_ability(G, 0, 0) != null, "Dark Altar refuse avec une defausse vide")
	_ok(((G["players"][0] as Dictionary)["dungeon"] as Array).size() == 1, "la salle n'est pas detruite")
	_ok(not bool(BossEngine.active_room(((G["players"][0] as Dictionary)["dungeon"] as Array)[0]).get("usedThisTurn", false)),
		"l'activation refusee n'est pas consommee")
	# Une seule carte dans la defausse : auto-resolue, l'Altar detruit rejoint la defausse.
	var G1 := _ability_G("BMA009")
	(G1["decks"]["roomDiscard"] as Array).append(_room("X", "trap", false, [1]))
	_ok(RoomAbilities.activate_room_ability(G1, 0, 0) == null, "Dark Altar (1 carte) s'active")
	_ok(((G1["players"][0] as Dictionary)["dungeon"] as Array).is_empty(), "Dark Altar detruit sa salle")
	_ok(_card_ids((G1["players"][0] as Dictionary)["hand"] as Array) == ["X"], "la carte de la defausse est recuperee (pas l'Altar)")
	_ok((G1["decks"]["roomDiscard"] as Array).size() == 1, "l'Altar detruit est en defausse")
	# Defausse pre-remplie a 2 cartes : plusieurs options -> l'engine ouvre un choix.
	var G2 := _ability_G("BMA009")
	(G2["decks"]["roomDiscard"] as Array).append_array([_room("X", "trap", false, [1]), _room("Y", "trap", false, [1])])
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
		"decks": {"rooms": [], "spells": [], "heroes": [], "epics": [], "roomDiscard": [_room("X", "trap", false, [1])], "spellDiscard": [], "heroDiscard": []},
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

## BMA034 Construction Zone : ExtraBuildTurn -> PendingExtraBuiltTurns (ExtraBuildPhase), sans toucher au tour courant.
func _t_build_construction_zone_refunds_build() -> void:
	var G := _ability_G("BMA034")
	(G["players"][0] as Dictionary)["buildsThisTurn"] = 1
	RoomAbilities.on_build_room(G, 0, _room("BMA034", "trap", false, [1]))
	var q: Array = G.get("forcedBuilds", [])
	_ok(q.size() == 1 and int((q[0] as Dictionary)["playerId"]) == 0 and str((q[0] as Dictionary)["cardId"]) == "", "Construction Zone empile un tour de construction supplementaire")
	_ok(int((G["players"][0] as Dictionary)["buildsThisTurn"]) == 1, "Construction Zone ne rend plus la construction du tour")

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

## --- pendingChoice : Dark Altar, Dark Laboratory, All-Seeing Eye, Draculord, Robobo, Cleopatra (C# = verite) ---

func _hand_ids(pid: int, m) -> Array:
	return _card_ids((m.G["players"][pid] as Dictionary)["hand"] as Array)

func _card_ids(arr: Array) -> Array:
	var out: Array = []
	for c in arr:
		out.append(str((c as Dictionary).get("id", "")))
	return out

func _choice_moves(m, pid: int) -> Array:
	var out: Array = []
	for mv in m.legal_moves(pid):
		if str((mv as Dictionary).get("type", "")) == "resolveChoice":
			out.append(int(((mv as Dictionary)["args"] as Array)[0]))
	return out

func _has_move(m, pid: int, kind: String) -> bool:
	for mv in m.legal_moves(pid):
		if str((mv as Dictionary).get("type", "")) == kind:
			return true
	return false

## BMA009 : cibles resolues AVANT la destruction -> l'Altar n'est pas une option ; resume=false ->
## resoudre le choix ne referme pas la phase BUILD.
func _t_choice_dark_altar() -> void:
	var m = _match_with_spell()
	var p0: Dictionary = m.G["players"][0]
	p0["hand"] = []
	p0["dungeon"] = [[_room("BMA009", "trap", false, [1])]]
	(m.G["decks"]["roomDiscard"] as Array).append(_room("RD", "trap", false, [1]))
	(m.G["decks"]["spellDiscard"] as Array).append({"id": "SD", "name": "Spell D", "isSpell": true})
	_ok(_has_move(m, 0, "activateRoom"), "Dark Altar activable avec une defausse non vide")
	_ok(m.apply_move(0, {"type": "activateRoom", "args": [0]}), "activateRoom Dark Altar applique")
	var pc: Dictionary = m.G.get("pendingChoice", {})
	_ok(str(pc.get("type", "")) == "recover-card" and int(pc.get("playerId", -1)) == 0, "choix recover-card pour le proprietaire")
	var opts: Array = pc.get("options", [])
	_ok(opts.size() == 2, "exactement les 2 cartes de la defausse (salle + sort), pas l'Altar")
	_ok(str(((opts[0] as Dictionary)["card"] as Dictionary).get("id", "")) == "RD"
		and str(((opts[1] as Dictionary)["card"] as Dictionary).get("id", "")) == "SD", "ordre salles puis sorts")
	_ok(_choice_moves(m, 0) == [0, 1], "legal_moves du proprietaire : resolveChoice 0 et 1")
	_ok(m.legal_moves(1).is_empty(), "l'autre joueur n'a aucun coup")
	_ok(m.apply_move(0, {"type": "resolveChoice", "args": [1]}), "resolveChoice applique")
	_ok(_hand_ids(0, m) == ["SD"], "le sort choisi est en main")
	_ok((m.G["decks"]["roomDiscard"] as Array).size() == 2, "RD et l'Altar detruit sont en defausse")
	_ok(str(m.G.get("phase", "")) == "build", "resume=false : la phase BUILD reste ouverte")
	m.queue_free()
	# Defausse vide : plus d'activation proposee (Ability.CheckConditions).
	var m2 = _match_with_spell()
	(m2.G["players"][0] as Dictionary)["dungeon"] = [[_room("BMA009", "trap", false, [1])]]
	_ok(not _has_move(m2, 0, "activateRoom"), "defausse vide : Dark Altar non activable")
	m2.queue_free()

## BMA022 : DiscardSomeCardFromHand(1, Spell) = tous les sorts de la main (pas seulement les 2 pioches).
func _t_choice_dark_laboratory() -> void:
	var G := _ability_G("BMA022")
	var p0: Dictionary = G["players"][0]
	(p0["hand"] as Array).append({"id": "OLD", "name": "Old", "isSpell": true})
	(G["decks"]["spells"] as Array).append_array([{"id": "A", "name": "A", "isSpell": true}, {"id": "B", "name": "B", "isSpell": true}])
	var c = RoomAbilities.on_build_room(G, 0, _room("BMA022", "trap", false, [1]))
	_ok(c != null and ((c as Dictionary)["options"] as Array).size() == 3, "3 options : l'ancien sort + les 2 pioches")
	var ids: Array = []
	for o in ((c as Dictionary)["options"] as Array):
		ids.append(str(((o as Dictionary)["card"] as Dictionary).get("id", "")))
	_ok(ids.has("OLD") and ids.has("A") and ids.has("B"), "l'ancien sort fait partie des options (%s)" % str(ids))
	# Resolution via le moteur : le sort choisi part en defausse.
	var m = _match_with_spell()
	m.G = _choice_G("discard-spell", (c as Dictionary)["options"] as Array, p0["hand"] as Array)
	_ok(_choice_moves(m, 0) == [0, 1, 2], "legal_moves : une resolution par option")
	var chosen: String = ids[0]
	_ok(m.apply_move(0, {"type": "resolveChoice", "args": [0]}), "resolveChoice applique")
	_ok(_hand_ids(0, m).size() == 2 and not _hand_ids(0, m).has(chosen), "le sort choisi quitte la main")
	m.queue_free()
	# Un seul sort en main apres pioche (pioche vide) : defausse automatique.
	var G1 := _ability_G("BMA022")
	(G1["players"][0]["hand"] as Array).append({"id": "ONLY", "name": "Only", "isSpell": true})
	_ok(RoomAbilities.on_build_room(G1, 0, _room("BMA022", "trap", false, [1])) == null, "1 sort en main : aucun choix")
	_ok((G1["decks"]["spellDiscard"] as Array).size() == 1 and ((G1["players"][0] as Dictionary)["hand"] as Array).is_empty(),
		"le sort unique est defausse")

## BMA025 : defausse un sort pour annuler le dernier sort ADVERSE de la pile.
func _t_choice_all_seeing_eye() -> void:
	var m = _match_with_spell()
	var p0: Dictionary = m.G["players"][0]
	(m.G["players"][1] as Dictionary)["isAI"] = false # sinon _drive_ai jouerait le tour du lanceur
	p0["dungeon"] = [[_room("BMA025", "trap", true, [3])]]
	p0["hand"] = [{"id": "S1", "name": "S1", "isSpell": true}, {"id": "S2", "name": "S2", "isSpell": true}]
	var theirs := {"id": "BMA040", "name": "Annihilator", "isSpell": true}
	m.G["stack"] = [{"id": "x", "type": "spell", "playerId": 0, "card": {"id": "OWN", "name": "Own", "isSpell": true}, "target": {}, "resolved": false}]
	m.G["activePlayer"] = 0
	m.G["stackReturnPlayer"] = 1
	_ok(not _has_move(m, 0, "activateRoom"), "pas d'activation sur son propre sort")
	m.G["stack"] = [{"id": "y", "type": "spell", "playerId": 1, "card": theirs, "target": {}, "resolved": false}]
	_ok(_has_move(m, 0, "activateRoom"), "activation proposee face a un sort adverse")
	_ok(m.apply_move(0, {"type": "activateRoom", "args": [0]}), "activateRoom All-Seeing Eye applique")
	var pc: Dictionary = m.G.get("pendingChoice", {})
	_ok(str(pc.get("type", "")) == "discard-spell" and bool(pc.get("thenCancel", false)), "choix discard-spell + annulation")
	_ok((pc.get("options", []) as Array).size() == 2, "les 2 sorts de la main sont proposes")
	_ok(_choice_moves(m, 0) == [0, 1] and m.legal_moves(1).is_empty(), "seul le proprietaire resout")
	_ok(m.apply_move(0, {"type": "resolveChoice", "args": [1]}), "resolveChoice applique")
	_ok(_hand_ids(0, m) == ["S1"], "S2 est defausse")
	_ok((m.G["stack"] as Array).is_empty(), "le sort adverse est retire de la pile")
	_ok((m.G["decks"]["spellDiscard"] as Array).size() == 2, "sort defausse + sort annule en defausse")
	_ok(int(m.G.get("activePlayer", -1)) == 1, "la main revient au lanceur du sort")
	_ok(str(m.G.get("phase", "")) == "build", "la phase BUILD reste ouverte")
	_ok(bool(BossEngine.active_room((p0["dungeon"] as Array)[0]).get("usedThisTurn", false)), "une fois par tour")
	m.queue_free()
	# Un seul sort en main : defausse automatique.
	var G1 := _ability_G("BMA025")
	(G1["players"][0]["hand"] as Array).append({"id": "ONLY", "name": "Only", "isSpell": true})
	G1["stack"] = [{"id": "z", "type": "spell", "playerId": 1, "card": theirs, "target": {}, "resolved": false}]
	_ok(RoomAbilities.activate_room_ability(G1, 0, 0) == null and (G1["stack"] as Array).is_empty(), "1 sort : annulation directe")
	_ok((G1["decks"]["spellDiscard"] as Array).size() == 2, "les 2 sorts sont en defausse")
	# Sans sort en main : impossible.
	var G2 := _ability_G("BMA025")
	G2["stack"] = [{"id": "z", "type": "spell", "playerId": 1, "card": theirs, "target": {}, "resolved": false}]
	_ok(RoomAbilities.activate_room_ability(G2, 0, 0) != null, "sans sort en main : refuse")

# --- Spell Battle (GameBoard.EnqueueAbilityTransaction / OnAbilityApplyRequest / NextStep) ---

## Sort de test sans effet (categorie 4 = Build/Adventure) : seul l'ordre de resolution nous interesse.
func _zspell(id: String) -> Dictionary:
	return {"id": id, "name": id, "isSpell": true, "category": 4}

func _counter() -> Dictionary:
	return {"id": "BMA043", "name": "Counterspell", "isSpell": true, "category": 2}

## 3 joueurs (rang 0,1,2), phase BUILD, le joueur 0 a la main : decor d'une Spell Battle.
func _battle_match(phase: String = "build") -> Node:
	var m = load("res://godot/scripts/Match.gd").new()
	add_child(m)
	var pl := {}
	for i in 3:
		pl[i] = {"boss": {"xp": 300 - i}, "dungeon": [[_room("R%d" % i, "trap", false, [1])]], "hand": [], "souls": [],
			"wounds": [], "eliminated": false, "leveledUp": false, "buildsThisTurn": 0, "isAI": false, "entrance": []}
	m.G = {"players": pl, "xpOrder": [0, 1, 2], "buildOrder": [0, 1, 2], "buildIndex": 0, "activePlayer": 0,
		"decks": {"rooms": [], "spells": [], "heroes": [], "epics": [], "roomDiscard": [], "spellDiscard": [], "heroDiscard": []},
		"town": [], "turn": 1, "phase": phase, "gameOver": null, "log": [], "effects": SpellEffects.empty_effects(),
		"stack": [], "stackPassed": {}}
	return m

func _play(m, pid: int, spell_id: String, target_stack_id: String = "") -> bool:
	var hand: Array = (m.G["players"][pid] as Dictionary)["hand"]
	for mv in m.legal_moves(pid):
		var md: Dictionary = mv
		if str(md["type"]) != "playSpell":
			continue
		var idx := int((md["args"] as Array)[0])
		if str((hand[idx] as Dictionary).get("id", "")) != spell_id:
			continue
		var t = (md["args"] as Array)[1]
		if target_stack_id == "" or (t is Dictionary and str((t as Dictionary).get("stackId", "")) == target_stack_id):
			return m.apply_move(pid, md)
	return false

func _pass(m, pid: int) -> bool:
	return m.apply_move(pid, {"type": "pass", "args": []})

func _stack_ids(m) -> Array:
	return (m.G["stack"] as Array).map(func(e): return str(((e as Dictionary)["card"] as Dictionary)["id"]))

func _resolved_order(m) -> Array:
	var out: Array = []
	for l in (m.G["log"] as Array):
		var s := str(l)
		if s.begins_with("Le sort ") and s.ends_with(" se résout."):
			out.append(s.substr(8, s.length() - 8 - 11))
	return out

## Fenetres de jeu = DuringPhase de l'Ability (pas SpellCategory) : Freeze (categorie 2, sans condition) est jouable
## partout ; Fear/Teleportation (categorie 1) seulement en aventure ; Kobold Strike en construction ; Counterspell exige un sort en attente.
func _t_spell_phase_windows() -> void:
	var b: String = CardDB.PHASE["BUILD"]
	var a: String = CardDB.PHASE["ADVENTURE"]
	_ok(CardDB.can_play_spell({"id": "BMA046", "category": 2}, a) and CardDB.can_play_spell({"id": "BMA046", "category": 2}, b), "Freeze : build ET aventure")
	_ok(CardDB.can_play_spell({"id": "BMA048", "category": 2}, a) and CardDB.can_play_spell({"id": "BMA052", "category": 1}, a), "Jeopardy / Soul Harvest : sans condition de phase")
	_ok(CardDB.can_play_spell({"id": "BMA045", "category": 1}, a) and not CardDB.can_play_spell({"id": "BMA045", "category": 1}, b), "Fear : aventure seulement")
	_ok(CardDB.can_play_spell({"id": "BMA049", "category": 2}, b) and not CardDB.can_play_spell({"id": "BMA049", "category": 2}, a), "Kobold Strike : build seulement")
	_ok(not CardDB.can_play_spell({"id": "BMA043", "category": 2}, a, 0) and CardDB.can_play_spell({"id": "BMA043", "category": 2}, a, 1), "Counterspell : seulement avec un sort en attente")

## Freeze hors tour en aventure (traces APK s3-p2 seq 53 / s2-p3 seq 172) : le lanceur n'est pas le joueur actif.
func _t_freeze_offturn_in_adventure() -> void:
	var m = _battle_match("adventure")
	m.G["activePlayer"] = 0
	(m.G["players"][1] as Dictionary)["hand"] = [{"id": "BMA046", "name": "Freeze", "isSpell": true, "category": 2}]
	_ok(_has_move(m, 1, "playSpell"), "Freeze jouable en aventure par un joueur hors tour")
	m.queue_free()

## RoomInDungeon : ni salle face cachee (PendingToBeBuilt), ni emplacement deja gele (IsActive).
func _t_spell_target_room_active_only() -> void:
	var m = _battle_match()
	var p0: Dictionary = m.G["players"][0]
	var hidden := _room("HID", "trap", false, [1])
	hidden["faceDown"] = true
	p0["dungeon"] = [[_room("A", "trap", false, [1])], [hidden], [_room("B", "monster", false, [1])]]
	var t := SpellTargeting.enumerate_targets("any-room", m.G, p0, 0)
	var mine := t.filter(func(x): return int((x as Dictionary)["targetPlayerId"]) == 0)
	_ok(mine.size() == 2, "salle face cachee non ciblable")
	(SpellEffects._effects(m.G)["deactivatedRooms"] as Array).append({"playerId": 0, "roomIndex": 0})
	t = SpellTargeting.enumerate_targets("any-room", m.G, p0, 0)
	mine = t.filter(func(x): return int((x as Dictionary)["targetPlayerId"]) == 0)
	_ok(mine.size() == 1 and int((mine[0] as Dictionary)["roomIndex"]) == 2, "emplacement gele non ciblable")
	_ok(SpellTargeting.enumerate_targets("any-room-trap", m.G, p0, 0).filter(func(x): return int((x as Dictionary)["targetPlayerId"]) == 0).is_empty(), "trap gelee / cachee exclue d'any-room-trap")
	m.queue_free()

## Ordre de resolution = PendingAbilityTransactions : joueur du tour en tete (LIFO entre ses sorts), les autres a la suite
## par rang de joueur. Ni LIFO pur (ZD,ZC,ZB,ZA) ni FIFO pur (ZA,ZB,ZC,ZD).
func _t_stack_resolution_order() -> void:
	var m = _battle_match()
	(m.G["players"][0] as Dictionary)["hand"] = [_zspell("ZA"), _zspell("ZC")]
	(m.G["players"][1] as Dictionary)["hand"] = [_zspell("ZB")]
	(m.G["players"][2] as Dictionary)["hand"] = [_zspell("ZD")]
	_ok(_play(m, 0, "ZA"), "joueur du tour : ZA")
	_ok(int(m.active_player()) == 1, "le rang 1 repond en premier")
	_ok(_play(m, 1, "ZB"), "joueur 1 repond : ZB")
	_ok(_stack_ids(m) == ["ZA", "ZB"], "hors-tour apres le sort du joueur du tour")
	_ok(int(m.active_player()) == 0 and _play(m, 0, "ZC"), "la fenetre est rouverte : ZC")
	_ok(_stack_ids(m) == ["ZC", "ZA", "ZB"], "le joueur du tour passe en tete (LIFO entre ses sorts)")
	_ok(_pass(m, 1), "1 passe")
	_ok(_play(m, 2, "ZD"), "joueur 2 repond : ZD")
	_ok(_stack_ids(m) == ["ZC", "ZA", "ZB", "ZD"], "rang 2 apres le rang 1")
	_ok(_pass(m, 0) and _pass(m, 1), "tous passent")
	_ok((m.G["stack"] as Array).is_empty() and _resolved_order(m) == ["ZC", "ZA", "ZB", "ZD"], "resolution dans l'ordre de la liste : %s" % str(_resolved_order(m)))
	_ok(int(m.active_player()) == 0, "la main revient au joueur du tour")
	m.queue_free()

## Counterspell = transaction de la pile (contrable), replacee JUSTE AVANT sa cible ; elle annule la cible, qui part en defausse.
func _t_counterspell_stack_chain() -> void:
	var m = _battle_match()
	(m.G["players"][0] as Dictionary)["hand"] = [_zspell("ZA")]
	(m.G["players"][1] as Dictionary)["hand"] = [_counter()]
	(m.G["players"][2] as Dictionary)["hand"] = [_counter()]
	_ok(_play(m, 0, "ZA"), "ZA")
	var za_id := str(((m.G["stack"] as Array)[0] as Dictionary)["id"])
	_ok(SpellTargeting.stack_spell_entries(m.G, 0).is_empty(), "on ne contre pas son propre sort")
	_ok(_play(m, 1, "BMA043", za_id), "joueur 1 contre ZA")
	_ok(_stack_ids(m) == ["BMA043", "ZA"], "Counterspell juste avant sa cible")
	var c1_id := str(((m.G["stack"] as Array)[0] as Dictionary)["id"])
	_ok(_pass(m, 0), "0 passe")
	_ok(_play(m, 2, "BMA043", c1_id), "joueur 2 contre le Counterspell")
	_ok(_stack_ids(m) == ["BMA043", "BMA043", "ZA"], "contre-contre-sort en tete")
	_ok(_pass(m, 0) and _pass(m, 1), "tous passent")
	_ok((m.G["stack"] as Array).is_empty(), "pile resolue")
	_ok(_resolved_order(m) == ["Counterspell", "ZA"], "le 2e Counterspell annule le 1er : ZA se resout (%s)" % str(_resolved_order(m)))
	_ok((m.G["decks"]["spellDiscard"] as Array).size() == 3, "3 cartes en defausse")
	# Un seul Counterspell : ZA ne se resout jamais.
	var m2 = _battle_match()
	(m2.G["players"][0] as Dictionary)["hand"] = [_zspell("ZA")]
	(m2.G["players"][1] as Dictionary)["hand"] = [_counter()]
	_ok(_play(m2, 0, "ZA") and _play(m2, 1, "BMA043"), "ZA puis Counterspell")
	_ok(_pass(m2, 0) and _pass(m2, 2), "0 et 2 passent")
	_ok(not _resolved_order(m2).has("ZA") and (m2.G["decks"]["spellDiscard"] as Array).size() == 2, "ZA annule : defausse sans effet")
	m.queue_free()
	m2.queue_free()

## Tout sort legal repond (pas seulement Counterspell / All-Seeing Eye) ; l'IA, elle, s'en tient a sa politique (AbilityCalculator).
func _t_spell_battle_open_responses() -> void:
	var m = _battle_match()
	(m.G["players"][0] as Dictionary)["hand"] = [_zspell("ZA")]
	(m.G["players"][1] as Dictionary)["hand"] = [{"id": "BMA046", "name": "Freeze", "isSpell": true, "category": 2}, {"id": "BMA049", "name": "Kobold", "isSpell": true, "category": 2}]
	_ok(_play(m, 0, "ZA"), "ZA ouvre la Spell Battle")
	_ok(_has_move(m, 1, "playSpell") and _has_move(m, 1, "pass"), "le repondant peut jouer un sort quelconque ou passer")
	_ok(m.legal_moves(2).is_empty(), "seul le repondant courant agit")
	var mv_ai = AI.pick_move(m, 1)
	_ok(mv_ai != null and str((mv_ai as Dictionary)["type"]) == "pass", "l'IA passe (pas de Counterspell en main)")
	(m.G["players"][1] as Dictionary)["hand"].append(_counter())
	mv_ai = AI.pick_move(m, 1)
	var picked_id := ""
	if mv_ai != null and str((mv_ai as Dictionary)["type"]) == "playSpell":
		picked_id = str(((m.G["players"][1] as Dictionary)["hand"][int(((mv_ai as Dictionary)["args"] as Array)[0])] as Dictionary)["id"])
	_ok(picked_id == "BMA043", "l'IA contre")
	m.queue_free()

## BMA001 : cartes (salles et sorts) des adversaires vivants ; une seule carte = prise automatique.
func _t_choice_draculord() -> void:
	var G := _levelup_G("BMA001", 5)
	var p1: Dictionary = G["players"][1]
	(p1["hand"] as Array).append_array([_room("R1", "trap", false, [1]), {"id": "SP1", "name": "Fire", "isSpell": true}])
	var c = RoomAbilities.process_level_up(G, 0)
	_ok(c != null and ((c as Dictionary)["options"] as Array).size() == 2, "salle et sort adverses proposes")
	var m = _match_with_spell()
	m.G = G
	m.G["pendingChoice"] = c
	m.G["phase"] = "end"
	_ok(_choice_moves(m, 0) == [0, 1] and m.legal_moves(1).is_empty(), "legal_moves du chooser uniquement")
	_ok(m.apply_move(0, {"type": "resolveChoice", "args": [1]}), "resolveChoice applique")
	_ok(_hand_ids(0, m) == ["SP1"] and _hand_ids(1, m) == ["R1"], "la carte volee passe en main")
	m.queue_free()
	var G1 := _levelup_G("BMA001", 5)
	((G1["players"][1] as Dictionary)["hand"] as Array).append({"id": "SP1", "name": "Fire", "isSpell": true})
	_ok(RoomAbilities.process_level_up(G1, 0) == null and ((G1["players"][0] as Dictionary)["hand"] as Array).size() == 1,
		"une seule carte : prise automatique")
	var G2 := _levelup_G("BMA001", 5)
	((G2["players"][1] as Dictionary)["hand"] as Array).append_array([{"id": "A", "isSpell": true}, {"id": "B", "isSpell": true}])
	(G2["players"][1] as Dictionary)["eliminated"] = true
	_ok(RoomAbilities.process_level_up(G2, 0) == null, "adversaire elimine ignore")

## BMA004 : chaque adversaire (PlayerId croissant) detruit une salle de SON donjon ; 0 salle = saute,
## 1 salle = auto ; la salle detruite va en defausse.
func _t_choice_robobo() -> void:
	var G := _levelup_G("BMA004", 5)
	var players: Dictionary = G["players"]
	for pid in [2, 3, 4]:
		players[pid] = {"id": pid, "boss": {"id": "BMA002", "name": "Z", "xp": 300}, "dungeon": [], "hand": [], "souls": [],
			"wounds": [], "entrance": [], "items": [], "eliminated": false, "buildsThisTurn": 0, "leveledUp": false}
	(players[1]["dungeon"] as Array).append_array([[_room("A1", "trap", false, [1])], [_room("A2", "trap", true, [1])]])
	# joueur 2 : aucune salle (saute) ; joueur 3 : une seule (auto) ; joueur 4 : deux (choix).
	(players[3]["dungeon"] as Array).append([_room("C1", "trap", false, [1])])
	(players[4]["dungeon"] as Array).append_array([[_room("D1", "trap", false, [1])], [_room("D2", "trap", false, [1])]])
	var c = RoomAbilities.process_level_up(G, 0)
	_ok(c != null and int((c as Dictionary)["playerId"]) == 1, "le premier adversaire choisit")
	var opts: Array = (c as Dictionary)["options"]
	_ok(opts.size() == 2 and str(((opts[1] as Dictionary)["card"] as Dictionary).get("name", "")) == "A2", "ses salles actives sont proposees")
	var m = _match_with_spell()
	m.G = G
	m.G["pendingChoice"] = c
	m.G["phase"] = "end"
	_ok(m.legal_moves(0).is_empty() and _choice_moves(m, 1) == [0, 1], "seul l'adversaire concerne a des coups")
	_ok(m.apply_move(1, {"type": "resolveChoice", "args": [0]}), "l'adversaire resout")
	_ok((players[1]["dungeon"] as Array).size() == 1, "A1 detruite")
	_ok((players[3]["dungeon"] as Array).is_empty(), "joueur 3 : salle unique detruite automatiquement")
	var pc2: Dictionary = m.G.get("pendingChoice", {})
	_ok(int(pc2.get("playerId", -1)) == 4 and str(pc2.get("type", "")) == "destroy-room", "joueur 2 saute, joueur 4 choisit")
	_ok(m.apply_move(4, {"type": "resolveChoice", "args": [1]}), "le joueur 4 resout")
	_ok((m.G.get("pendingChoice", {}) as Dictionary).is_empty(), "file terminee")
	var names: Array = []
	for r in (m.G["decks"]["roomDiscard"] as Array):
		names.append(str((r as Dictionary).get("name", "")))
	_ok(names == ["A1", "C1", "D2"], "les salles detruites sont en defausse (%s)" % str(names))
	m.queue_free()

## BMA007 : choix obligatoire (CanAvoid=false) parmi les pieges avances (pioche + defausse) ; la carte
## va en main et declenche un tour de construction supplementaire limite a cette carte (BuildRoomBy).
func _t_choice_cleopatra_forced_build() -> void:
	var G := _levelup_G("BMA007", 5)
	(G["decks"]["rooms"] as Array).append_array([_room("Ord", "trap", false, [1]), _room("AdvMon", "monster", true, [1]),
		_room("AdvT1", "trap", true, [1])])
	(G["decks"]["roomDiscard"] as Array).append(_room("AdvT2", "trap", true, [2]))
	var c = RoomAbilities.process_level_up(G, 0)
	var opts: Array = (c as Dictionary)["options"]
	_ok(opts.size() == 2 and not bool((c as Dictionary).get("optional", false)), "2 pieges avances, pas de 'passer'")
	var m = _match_with_spell()
	var p0: Dictionary = G["players"][0]
	m.G = G
	m.G["phase"] = "build"
	m.G["pendingChoice"] = c
	_ok(_choice_moves(m, 0) == [0, 1], "legal_moves : une resolution par option, sans -1")
	(p0["hand"] as Array).append(_room("Other", "trap", false, [1]))
	p0["leveledUp"] = true
	_ok(m.apply_move(0, {"type": "resolveChoice", "args": [0]}), "resolveChoice applique")
	_ok(_hand_ids(0, m).has("AdvT1") and (G["decks"]["rooms"] as Array).size() == 2, "AdvT1 quitte la pioche pour la main")
	# Fin de la revelation : le tour de construction supplementaire demarre, seule la carte imposee est constructible.
	_ok(str(G.get("forcedBuild", "")) == "AdvT1" and int(m.active_player()) == 0, "tour supplementaire force sur AdvT1")
	var builds: Array = []
	for mv in m.legal_moves(0):
		if str((mv as Dictionary)["type"]) == "buildRoom":
			builds.append(int(((mv as Dictionary)["args"] as Array)[0]))
	_ok(not builds.is_empty(), "un tour de construction est propose")
	var forced_idx: int = _hand_ids(0, m).find("AdvT1")
	_ok(builds.all(func(i): return i == forced_idx), "seule AdvT1 est constructible (%s)" % str(builds))
	m.queue_free()
	# Une seule candidate : prise automatique + construction forcee, sans choix.
	var G1 := _levelup_G("BMA007", 5)
	(G1["decks"]["roomDiscard"] as Array).append(_room("Solo", "trap", true, [1]))
	_ok(RoomAbilities.process_level_up(G1, 0) == null, "candidate unique : auto-resolue")
	_ok(_card_ids((G1["players"][0] as Dictionary)["hand"] as Array) == ["Solo"] and (G1["forcedBuilds"] as Array).size() == 1,
		"Solo en main + construction forcee")

## BMA015 / BMA029 : le type filtre (Monster / Trap) est celui de la salle CIBLE, pas de la salle source
## (C# AdjacentsRoom[Monster] / NextRoom[Trap] + DealDamageToRoom). Index Godot 0 = entree du heros.
func _t_room_damage_goblin_dizzygas_target_type() -> void:
	var G := _ability_G("X")
	var p: Dictionary = G["players"][0]
	p["dungeon"] = [[_room("T", "trap", false, [1])], [_room("BMA015", "monster", false, [1])], [_room("M", "monster", false, [1])]]
	_ok(BossEngine.room_damage_with_modifiers(G, p, 0, null) == 1, "Goblin Armory : une salle Trap adjacente ne gagne rien")
	_ok(BossEngine.room_damage_with_modifiers(G, p, 2, null) == 2, "Goblin Armory : une salle Monster adjacente gagne +1")
	_ok(BossEngine.room_damage_with_modifiers(G, p, 1, null) == 1, "Goblin Armory ne se buffe pas elle-meme")
	p["dungeon"] = [[_room("BMA029", "trap", false, [1])], [_room("M", "monster", false, [1])], [_room("T", "trap", false, [1])]]
	_ok(BossEngine.room_damage_with_modifiers(G, p, 1, null) == 1, "Dizzygas : la salle suivante non-Trap ne gagne rien")
	p["dungeon"] = [[_room("BMA029", "trap", false, [1])], [_room("T", "trap", false, [1])]]
	_ok(BossEngine.room_damage_with_modifiers(G, p, 1, null) == 3, "Dizzygas : la salle Trap suivante gagne +2")

## BMA011 Specter's Sanctum : avec 2+ adversaires ayant un sort, le choix pick-opponent defausse
## un sort au hasard chez l'adversaire designe (action discard-spell).
func _t_build_specters_sanctum_choice_discards() -> void:
	var m = _match_with_spell()
	var spell := {"id": "S", "name": "S", "isSpell": true}
	(m.G["players"][1] as Dictionary)["hand"] = [spell.duplicate()]
	m.G["players"][2] = {"boss": {"xp": 300, "treasures": [1]}, "dungeon": [], "hand": [spell.duplicate()],
		"souls": [], "wounds": [], "eliminated": false, "leveledUp": false, "buildsThisTurn": 0, "isAI": true, "entrance": []}
	var choice = RoomAbilities.on_build_room(m.G, 0, _room("BMA011", "monster", false, [1]))
	_ok(choice is Dictionary and str((choice as Dictionary).get("action", "")) == "discard-spell"
		and ((choice as Dictionary).get("options", []) as Array).size() == 2, "Specter's Sanctum : choix pick-opponent avec action")
	RoomAbilities.enqueue_pending(m.G, choice)
	_ok(m.apply_move(0, {"type": "resolveChoice", "args": [1]}), "resolveChoice pick-opponent applique")
	_ok((m.G["players"][2]["hand"] as Array).is_empty() and not (m.G["players"][1]["hand"] as Array).is_empty(),
		"le sort de l'adversaire designe (joueur 2) est defausse")
	_ok((m.G["decks"]["spellDiscard"] as Array).size() == 1, "le sort est en defausse")
	m.queue_free()

## BMA011 : le choix propose tous les adversaires vivants, meme sans sort (BossOpponent) ; en choisir un sans sort ne fait rien ; un seul adversaire est auto-resolu.
func _t_specters_sanctum_offers_all_opponents() -> void:
	var m = _match_with_spell()
	var spell := {"id": "S", "name": "S", "isSpell": true}
	(m.G["players"][1] as Dictionary)["hand"] = [spell.duplicate()]
	m.G["players"][2] = {"boss": {"xp": 300, "treasures": [1]}, "dungeon": [], "hand": [],
		"souls": [], "wounds": [], "eliminated": false, "leveledUp": false, "buildsThisTurn": 0, "isAI": true, "entrance": []}
	var choice = RoomAbilities.on_build_room(m.G, 0, _room("BMA011", "monster", false, [1]))
	_ok(choice is Dictionary and ((choice as Dictionary).get("options", []) as Array).size() == 2, "Specter's Sanctum : les 2 adversaires sont proposes, l'un sans sort")
	RoomAbilities.enqueue_pending(m.G, choice)
	var opts: Array = (choice as Dictionary)["options"]
	var idx_nospell := 0 if int((opts[0] as Dictionary)["targetPlayerId"]) == 2 else 1
	_ok(m.apply_move(0, {"type": "resolveChoice", "args": [idx_nospell]}), "resolveChoice sur l'adversaire sans sort")
	_ok(((m.G["players"][1] as Dictionary)["hand"] as Array).size() == 1 and (m.G["decks"]["spellDiscard"] as Array).is_empty(), "adversaire sans sort designe : aucune defausse")
	var m2 = _match_with_spell()
	(m2.G["players"][1] as Dictionary)["hand"] = []
	_ok(RoomAbilities.on_build_room(m2.G, 0, _room("BMA011", "monster", false, [1])) == null, "un seul adversaire : auto-resolu, sans choix")
	m.queue_free()
	m2.queue_free()

## BMA013 Dracolich Lair : le joueur choisit les 2 salles defaussees ; le choix dans la defausse est
## resolu AVANT (il ne propose pas les 2 salles qu'on vient de defausser).
func _t_choice_dracolich_lair() -> void:
	var m = _match_with_spell()
	var p0: Dictionary = m.G["players"][0]
	p0["dungeon"] = [[_room("BMA013", "monster", true, [1])]]
	p0["hand"] = [_room("R1", "trap", false, [1]), _room("R2", "trap", false, [1]), _room("R3", "trap", false, [1])]
	_ok(not _has_move(m, 0, "activateRoom"), "Dracolich Lair : defausse vide, non activable")
	(m.G["decks"]["roomDiscard"] as Array).append(_room("D1", "trap", false, [1]))
	(m.G["decks"]["roomDiscard"] as Array).append(_room("D2", "trap", false, [1]))
	_ok(_has_move(m, 0, "activateRoom"), "Dracolich Lair activable (2 salles en main, defausse non vide)")
	_ok(m.apply_move(0, {"type": "activateRoom", "args": [0]}), "activateRoom Dracolich Lair applique")
	var pc: Dictionary = m.G.get("pendingChoice", {})
	_ok(str(pc.get("type", "")) == "dracolich-discard" and (pc.get("options", []) as Array).size() == 3,
		"3 paires de salles proposees")
	_ok(m.apply_move(0, {"type": "resolveChoice", "args": [2]}), "paire R2+R3 choisie")
	_ok(_hand_ids(0, m) == ["R1"], "seules R2 et R3 sont defaussees")
	pc = m.G.get("pendingChoice", {})
	_ok(str(pc.get("type", "")) == "recover-card" and (pc.get("options", []) as Array).size() == 2,
		"choix dans la defausse d'avant (D1, D2), sans R2/R3")
	_ok(m.apply_move(0, {"type": "resolveChoice", "args": [1]}), "D2 recuperee")
	_ok(_hand_ids(0, m) == ["R1", "D2"], "D2 en main")
	_ok((m.G["decks"]["roomDiscard"] as Array).size() == 3, "D1, R2, R3 en defausse")
	m.queue_free()

## BMA039 Zombie Prison : detruit la salle, renvoie un heros mort d'un adversaire a l'entree de SON donjon.
func _t_room_zombie_prison() -> void:
	var m = _match_with_spell()
	var p0: Dictionary = m.G["players"][0]
	var p1: Dictionary = m.G["players"][1]
	p0["dungeon"] = [[_room("BMA039", "monster", false, [1])]]
	_ok(not _has_move(m, 0, "activateRoom"), "Zombie Prison : aucun heros mort chez l'adversaire, non activable")
	var hero := {"id": "H1", "name": "Hero1", "hp": 4, "souls": 1}
	p1["souls"] = [{"name": "Hero1", "souls": 1, "faceDown": true, "hero": hero}]
	(m.G["decks"]["heroDiscard"] as Array).append(hero)
	_ok(_has_move(m, 0, "activateRoom"), "Zombie Prison activable avec un heros mort chez l'adversaire")
	_ok(m.apply_move(0, {"type": "activateRoom", "args": [0]}), "activateRoom Zombie Prison applique")
	_ok((p0["dungeon"] as Array).is_empty() and (m.G["decks"]["roomDiscard"] as Array).size() == 1, "la salle est detruite puis defaussee")
	_ok((p1["souls"] as Array).is_empty(), "l'ame du heros est retiree de l'adversaire")
	_ok((p1["entrance"] as Array).size() == 1 and (m.G["decks"]["heroDiscard"] as Array).is_empty(),
		"le heros est a l'entree du donjon de l'adversaire (pas de l'activateur)")
	_ok((p0["entrance"] as Array).is_empty(), "l'activateur ne recoit pas le heros")
	m.queue_free()

## BMA019 Beast Menagerie (GameBoard.RevealAllRoomCards -> WhenYouBuildAnotherRoom) : OncePerTurn + un slot Monster
## encore en attente (celui qu'on revele compte) -> pioche une salle.
func _t_room_beast_menagerie() -> void:
	var G := _ability_G("BMA019")
	G["decks"]["rooms"] = [_room("D1", "trap", false, [1]), _room("D2", "trap", false, [1])]
	var menagerie: Dictionary = G["players"][0]["dungeon"][0][0]
	menagerie["type"] = "monster"
	var fresh := _room("M", "monster", false, [1])
	fresh["faceDown"] = true
	G["players"][0]["dungeon"].append([fresh])
	RoomAbilities.on_build_another_room(G, 0, fresh)
	_ok((G["players"][0]["hand"] as Array).size() == 1, "Beast Menagerie : salle Monster en attente -> pioche 1 salle")
	fresh["faceDown"] = true
	RoomAbilities.on_build_another_room(G, 0, fresh)
	_ok((G["players"][0]["hand"] as Array).size() == 1, "Beast Menagerie : une seule fois par tour")
	menagerie["usedThisTurn"] = false
	fresh["type"] = "trap"
	RoomAbilities.on_build_another_room(G, 0, fresh)
	_ok((G["players"][0]["hand"] as Array).size() == 1, "Beast Menagerie : rien si la salle en attente n'est pas un Monster")

## BMA038 Torture Chamber : DiscardRandomCardFromHand(1, Room) sur l'adversaire (un seul -> auto), la salle est detruite.
func _t_room_torture_chamber_discards_room() -> void:
	var G := _ability_G("BMA038")
	G["players"][1]["hand"] = [_room("R1", "trap", false, [1]), {"id": "S", "name": "S", "isSpell": true}]
	_ok(RoomAbilities.activate_room_ability(G, 0, 0) == null, "Torture Chamber s'active")
	var h: Array = G["players"][1]["hand"]
	_ok(h.size() == 1 and bool((h[0] as Dictionary).get("isSpell", false)), "l'adversaire defausse sa SALLE (le sort reste)")
	_ok((G["decks"]["roomDiscard"] as Array).size() == 2 and (G["players"][0]["dungeon"] as Array).is_empty(),
		"salle detruite + salle defaussee en defausse de salles")

## BMA050 Motivation (BuildExtraRoom : MaxBuildRoomLimit++) : le joueur garde la main pour une 2e construction.
func _t_build_motivation_extra_room() -> void:
	var m = _match_with_spell()
	m.G["autoAI"] = false
	var p0: Dictionary = m.G["players"][0]
	p0["hand"] = [_room("N1", "trap", false, [1]), _room("N2", "trap", false, [1])]
	(m.G["effects"]["extraBuild"] as Array).append(0)
	m.G["buildOrder"] = [0, 1]
	m.G["buildIndex"] = 0
	m.G["activePlayer"] = 0
	_ok(m.apply_move(0, {"type": "buildRoom", "args": [0]}), "Motivation : 1re construction")
	_ok(m.active_player() == 0 and _has_move(m, 0, "buildRoom"), "Motivation : le joueur garde la main pour la 2e")
	_ok(m.apply_move(0, {"type": "buildRoom", "args": [0]}), "Motivation : 2e construction")
	_ok(m.active_player() == 0 and not _has_move(m, 0, "buildRoom") and _has_move(m, 0, "passBuild"), "apres la 2e construction le joueur attend DONE")
	_ok(m.apply_move(0, {"type": "passBuild", "args": []}), "DONE")
	_ok(m.active_player() == 1, "apres DONE la main passe")
	m.queue_free()

## GameBoard.AvoidMulliganCondition : >= 4 salles avancees ou >= 4 salles au meme tresor => remelange.
func _t_setup_avoid_mulligan() -> void:
	var adv4: Array = [_room("A1", "trap", true, [1]), _room("A2", "trap", true, [2]), _room("A3", "trap", true, [3]),
		_room("A4", "trap", true, [4]), _room("N", "trap", false, [1])]
	_ok(Match._bad_opening_rooms(adv4), "4 salles avancees : mauvaise main")
	adv4.pop_front()
	_ok(not Match._bad_opening_rooms(adv4), "3 salles avancees : main acceptee")
	var fighters: Array = [_room("F1", "trap", false, [2, 2]), _room("F2", "trap", false, [2, 3]), _room("F3", "trap", false, [1, 2]),
		_room("F4", "trap", false, [2]), _room("X", "trap", false, [3])]
	_ok(Match._bad_opening_rooms(fighters), "4 salles portant le meme tresor (une salle compte une fois) : mauvaise main")
	fighters[3] = _room("F4", "trap", false, [1])
	_ok(not Match._bad_opening_rooms(fighters), "3 salles au meme tresor : main acceptee")
	var m = Match.new()
	add_child(m)
	m.rng.seed = 7
	var deck: Array = []
	for i in 20:
		deck.append(_room("N%d" % i, "trap", false, [1 + i % 4]))
	for i in 5:
		deck.append(_room("B%d" % i, "trap", true, [1]))   # sommet de pioche = fin du tableau : 5 avancees tirees d'abord
	var hand: Array = m._draw_opening_rooms(deck)
	_ok(hand.size() == 5 and not Match._bad_opening_rooms(hand), "la main redistribuee n'est plus mauvaise")
	_ok(deck.size() == 20, "les 5 salles rendues sont dans la pioche (pioche = 25 - 5)")
	m.queue_free()

func _setup_match(n: int) -> Node:
	var m = Match.new()
	add_child(m)
	var players := {}
	for i in n:
		players[i] = {"id": i, "boss": {"id": "B%d" % i, "name": "B%d" % i, "xp": 300 - i * 10, "treasures": [1]}, "dungeon": [],
			"hand": [_room("O%d" % i, "trap", false, [1]), _room("P%d" % i, "trap", false, [1]), _room("V%d" % i, "trap", true, [1]),
				{"id": "S%d" % i, "name": "S", "isSpell": true}],
			"souls": [], "wounds": [], "eliminated": false, "leveledUp": false, "buildsThisTurn": 0, "isAI": false, "entrance": []}
	var rooms: Array = []
	for i in 12:
		rooms.append(_room("D%d" % i, "trap", false, [1]))
	m.G = {"players": players, "decks": {"rooms": rooms, "spells": [], "heroes": [], "epics": [], "roomDiscard": [], "spellDiscard": [], "heroDiscard": []},
		"town": [], "turn": 0, "phase": "setup", "gameOver": null, "log": [], "effects": SpellEffects.empty_effects(), "autoAI": false,
		"stack": [], "stackPassed": {}, "pendingChoice": {}, "choiceQueue": []}
	return m

## Setup_b : chaque joueur pose une salle ordinaire en parallele (sans ordre), face cachee ; Setup_c revele puis le tour 1 commence.
func _t_setup_parallel_first_room() -> void:
	var m = _setup_match(3)
	m._begin_setup_build()
	_ok(str(m.G["phase"]) == "setup", "phase setup apres la defausse d'ouverture")
	var builds: Array = []
	for mv in m.legal_moves(2):
		if str((mv as Dictionary)["type"]) == "buildRoom":
			builds.append(int(((mv as Dictionary)["args"] as Array)[0]))
	_ok(builds == [0, 1] and _has_move(m, 2, "passBuild"), "le dernier joueur peut construire d'abord : salles ordinaires seulement (%s)" % str(builds))
	_ok(not _has_move(m, 2, "playSpell"), "pas de sort pendant Setup_b")
	_ok(m.apply_move(2, {"type": "buildRoom", "args": [1]}), "joueur 2 construit")
	var d2: Array = (m.G["players"][2] as Dictionary)["dungeon"]
	_ok(d2.size() == 1 and bool((d2[0][0] as Dictionary).get("faceDown", false)), "salle initiale posee face cachee")
	_ok(m.legal_moves(2).size() == 2 and _has_move(m, 2, "passBuild") and _has_move(m, 2, "undoBuild") and not _has_move(m, 2, "buildRoom") and str(m.G["phase"]) == "setup", "une seule salle par joueur ; il attend DONE (ou reprend sa salle)")
	_ok(m.apply_move(2, {"type": "passBuild", "args": []}), "joueur 2 : DONE")
	_ok(m.legal_moves(2).is_empty() and str(m.G["phase"]) == "setup", "DONE donne : la phase attend les autres")
	_ok(m.apply_move(0, {"type": "passBuild", "args": []}), "joueur 0 ne construit pas")
	_ok(str(m.G["phase"]) == "setup", "joueur 1 n'a pas encore joue")
	_ok(m.apply_move(1, {"type": "buildRoom", "args": [0]}), "joueur 1 construit")
	_ok(str(m.G["phase"]) == "setup", "joueur 1 n'a pas encore appuye sur DONE")
	_ok(m.apply_move(1, {"type": "passBuild", "args": []}), "joueur 1 : DONE")
	_ok(str(m.G["phase"]) == "build" and int(m.G["turn"]) == 1, "Setup_c puis BeginningOfTurn : tour 1 en phase BUILD")
	_ok(not bool((d2[0][0] as Dictionary).get("faceDown", true)), "les salles initiales sont revelees")
	_ok(int(m.active_player()) == 0, "le premier joueur du rang XP ouvre BuildPhase_a")
	m.queue_free()

## ExtraBuildPhase : Construction Zone revelee => le joueur rejoue un tour de construction apres la revelation, avant le leurre ;
## sans salle constructible le tour est saute.
func _t_extra_build_phase_construction_zone() -> void:
	for with_room in [true, false]:
		var m = _match_with_spell()
		m.G["autoAI"] = false
		var p0: Dictionary = m.G["players"][0]
		var cz := _room("BMA034", "trap", false, [2, 4])
		cz["faceDown"] = true
		p0["dungeon"] = [[cz]]
		p0["hand"] = [_room("Next", "trap", false, [1])] if with_room else []
		p0["buildsThisTurn"] = 1
		m.G["buildOrder"] = [0, 1]
		m.G["buildIndex"] = 2
		m._close_build_phase()
		if with_room:
			_ok(str(m.G["phase"]) == "build" and str(m.G.get("forcedBuild", "x")) == "" and int(m.active_player()) == 0, "ExtraBuildPhase : tour de construction du proprietaire")
			_ok(int(p0["buildsThisTurn"]) == 0 and _has_move(m, 0, "buildRoom"), "il peut poser une salle de plus")
			_ok(not _has_move(m, 1, "passBuild"), "les autres joueurs n'ont pas la main")
			_ok(m.apply_move(0, {"type": "buildRoom", "args": [0]}), "construction supplementaire")
			_ok(m.apply_move(0, {"type": "passBuild", "args": []}), "DONE du tour supplementaire")
		_ok(str(m.G["phase"]) != "build" and (m.G.get("forcedBuilds", []) as Array).is_empty(),
			"la phase se referme ensuite (leurre)" if with_room else "sans salle constructible l'extra est saute")
		m.queue_free()

## DoneButtonEntity : la pose d'une salle par un humain ne finit pas son tour (DONE = passBuild) ; les salles sont revelees ensemble ensuite.
func _t_human_build_waits_for_done() -> void:
	var m = _match_with_spell()
	var p0: Dictionary = m.G["players"][0]
	p0["hand"] = [_room("N1", "trap", false, [1])]
	m.G["buildOrder"] = [0, 1]
	m.G["buildIndex"] = 0
	m.G["activePlayer"] = 0
	_ok(m.apply_move(0, {"type": "buildRoom", "args": [0]}), "l'humain pose sa salle")
	var built: Dictionary = (p0["dungeon"] as Array)[0][0]
	_ok(int(m.active_player()) == 0 and str(m.G["phase"]) == "build" and bool(built.get("faceDown", false)), "il garde la main, salle face cachee, pas de revelation")
	_ok(not _has_move(m, 0, "buildRoom") and _has_move(m, 0, "passBuild"), "plus de construction mais DONE (passBuild)")
	_ok(m.apply_move(0, {"type": "passBuild", "args": []}), "DONE")
	_ok(not bool(built.get("faceDown", true)) and str(m.G["phase"]) != "build", "le tour passe (l'IA construit) et les salles sont revelees")
	m.queue_free()
	# Dernier constructeur humain avec un sort en main : son DONE vaut deja « pret », pas de fenetre rien que pour lui.
	var m2 = _match_with_spell()
	m2.G["buildOrder"] = [1, 0]
	m2.G["buildIndex"] = 1
	m2.G["activePlayer"] = 0
	_ok(m2.apply_move(0, {"type": "passBuild", "args": []}), "DONE du dernier constructeur")
	_ok(not m2.G.has("buildWindow"), "pas de fenetre de sorts ouverte pour le seul siege qui vient de passer")
	m2.queue_free()

## Hors tour, un joueur vivant peut jouer un sort en BUILD (ouverture d'une Spell Battle) mais ni construire ni « passer » ;
## la main revient au joueur du tour (stack_return_control). Un siege IA n'ouvre pas de Spell Battle hors tour (politique).
func _t_build_offturn_spell_window() -> void:
	var m = _match_with_spell()
	m.G["buildOrder"] = [0, 1]
	m.G["buildIndex"] = 0
	m.G["activePlayer"] = 0
	(m.G["players"][0] as Dictionary)["hand"] = []
	var p1: Dictionary = m.G["players"][1]
	p1["isAI"] = false
	p1["hand"] = [{"id": "BMA050", "name": "Motivation", "isSpell": true}, _room("InHand", "trap", false, [1])]
	_ok(_has_move(m, 1, "playSpell"), "un joueur hors tour peut jouer un sort en BUILD")
	_ok(not _has_move(m, 1, "passBuild") and not _has_move(m, 1, "pass") and not _has_move(m, 1, "buildRoom"), "hors tour : ni passer ni construire")
	var spell_move: Dictionary = {}
	for mv in m.legal_moves(1):
		if str((mv as Dictionary)["type"]) == "playSpell":
			spell_move = mv
			break
	_ok(m.apply_move(1, spell_move), "le sort hors tour est joue")
	_ok(not (m.G["stack"] as Array).is_empty() and int(m.active_player()) == 0, "le joueur du tour repond en premier")
	_ok(m.apply_move(0, {"type": "pass", "args": []}), "il passe")
	_ok((m.G["stack"] as Array).is_empty() and int(m.active_player()) == 0, "pile resolue : la main revient au joueur du tour")
	p1["isAI"] = true
	p1["hand"] = [{"id": "BMA050", "name": "Motivation", "isSpell": true}]
	_ok(m.legal_moves(1).is_empty(), "un siege IA n'agit pas hors tour")
	m.queue_free()

## GameBoard.AssignHeroesToDungeons / Boss.GetDungeonTreasures : TreasuresMultiplier (Jackpot Stash) double les
## tresors des SALLES (pas ceux du boss) et departage un leurre autrement a egalite ; une egalite laisse le heros en ville.
func _t_lure_jackpot_stash_doubles_room_treasures() -> void:
	var G := _ability_G("BMA010")
	var p1: Dictionary = G["players"][1]
	p1["boss"] = {"treasures": [1]}
	(G["players"][0] as Dictionary)["boss"] = {"treasures": []}
	p1["dungeon"] = [[_room("Y", "trap", false, [1])]]
	var order := [0, 1]
	var hero := {"id": "BMA056", "treasure": 1}
	_ok(BossEngine.lure_target(G["players"], order, 1, hero, G) == 1, "joueur 1 : 2 tresors clerc contre 1")
	(G["players"][0] as Dictionary)["dungeon"] = [[_room("X", "trap", false, [1])]]
	(G["players"][0] as Dictionary)["boss"] = {"treasures": [1]}
	_ok(BossEngine.lure_target(G["players"], order, 1, hero, G) == -1, "egalite 2-2 : le heros reste en ville")
	(SpellEffects._effects(G)["treasureDoubled"] as Array).append(0)
	_ok(BossEngine.lure_target(G["players"], order, 1, hero, G) == 0, "Jackpot Stash : salles x2 (3 contre 2), pas le boss")

## The Fool (BMA080, LuredByFewerSouls) va chez le joueur au MOINS d'ames ; egalite = reste en ville.
func _t_lure_fool_fewest_souls() -> void:
	var G := _ability_G("BMA010")
	var fool := {"id": "BMA080", "treasure": 0}
	var order := [0, 1]
	_ok(BossEngine.lure_target(G["players"], order, 0, fool, G) == -1, "Fool : egalite d'ames -> reste en ville")
	((G["players"][0] as Dictionary)["souls"] as Array).append({"souls": 1})
	_ok(BossEngine.lure_target(G["players"], order, 0, fool, G) == 1, "Fool : joueur 1 a moins d'ames")

## RevealHeroes revele Players.Count heros (eliminés compris) ; les effets « jusqu'a la fin du tour » expirent au tour suivant.
func _t_reveal_heroes_counts_eliminated_and_effects_expire() -> void:
	var m = load("res://godot/scripts/Match.gd").new()
	add_child(m)
	m.G = _ability_G("BMA010")
	(m.G["players"][1] as Dictionary)["eliminated"] = true
	m.G["log"] = []
	var heroes: Array = []
	for i in 5:
		heroes.append({"id": "H%d" % i, "treasure": 1})
	m.G["decks"]["heroes"] = heroes
	m.G["decks"]["epics"] = []
	m._reveal_heroes_in_town()
	_ok((m.G["town"] as Array).size() == 2, "2 heros reveles pour 2 joueurs dont 1 elimine")
	(SpellEffects._effects(m.G)["treasureDoubled"] as Array).append(0)
	m.G["setupBuild"] = false
	m._start_turn()
	_ok((SpellEffects._effects(m.G)["treasureDoubled"] as Array).is_empty(), "effets de tour remis a zero au debut du tour suivant")
	m.queue_free()

# --- Aventure / heros / fenetre de sorts (parite APK) ---

## Freeze = DeactivateRoom (DungeonSlot.IsActive=false) : le heros ne subit aucun degat dans la salle gelee.
func _t_freeze_room_deals_no_damage() -> void:
	var G := _ability_G("BMA010")
	var p: Dictionary = G["players"][0]
	_ok(BossEngine.room_damage_with_modifiers(G, p, 0, {}) == 1, "salle non gelee : degats normaux")
	SpellEffects.cast_spell(G, 0, {"id": "BMA046"}, {"roomIndex": 0})
	_ok(BossEngine.room_damage_with_modifiers(G, p, 0, {}) == 0, "Freeze : la salle gelee ne fait aucun degat")

## DestroyRoom (Dungeon.Remove + Add) : les effets indexes suivent leur slot, et le heros dont un slot est detruit DEVANT
## lui (lastActiveHeroSlotIndex perime) RESUBIT sa salle ; derriere lui, sa salle garde sa position.
func _t_destroy_slot_shifts_effects_and_replays_hero() -> void:
	var G := _ability_G("BMA010")
	var p: Dictionary = G["players"][0]
	p["dungeon"] = [[_room("A", "trap", false, [1])], [_room("B", "trap", false, [1])], [_room("C", "trap", false, [1])]]
	((G["effects"] as Dictionary)["deactivatedRooms"] as Array).append({"playerId": 0, "roomIndex": 2})
	G["adventure"] = {"playerId": 0, "hero": {"id": "H"}, "roomIndex": 0, "hp": 5, "pause": null}
	var gone = BossEngine.destroy_room(p, 1, G)
	_ok(gone != null and int((((G["effects"] as Dictionary)["deactivatedRooms"] as Array)[0] as Dictionary)["roomIndex"]) == 1,
		"slot detruit : l'index du Freeze se decale")
	_ok(bool((G["adventure"] as Dictionary).get("replay", false)), "slot detruit devant le heros : il rejoue sa salle")
	G["adventure"] = {"playerId": 0, "hero": {"id": "H"}, "roomIndex": 1, "hp": 5, "pause": null}
	BossEngine.destroy_room(p, 0, G)
	_ok(int((G["adventure"] as Dictionary)["roomIndex"]) == 0 and not (G["adventure"] as Dictionary).has("replay"),
		"slot detruit derriere le heros : sa salle garde sa position")
	var used := {"id": "X", "usedThisTurn": true}
	BossEngine.discard_room_to_pile(G["decks"], used)
	_ok(not used.has("usedThisTurn"), "salle defaussee : capacite remise a neuf")

## Xyzax (CardInDeck 2 DiscardPile) : DEUX cartes recuperees, la 2e est un nouveau choix.
func _t_xyzax_recovers_two_cards() -> void:
	var m = load("res://godot/scripts/Match.gd").new()
	add_child(m)
	m.G = _ability_G("BMA010")
	m.G["phase"] = "adventure"
	m.G["log"] = []
	m.G["choiceQueue"] = []
	m.G["decks"]["roomDiscard"] = [_room("R1", "trap", false, [1]), _room("R2", "trap", false, [1]), _room("R3", "trap", false, [1])]
	m.G["pendingChoice"] = RoomAbilities._xyzax(m.G, m.G["players"][0])
	m._resolve_choice(0, 0)
	var pc: Dictionary = m.G["pendingChoice"]
	_ok(str(pc.get("type", "")) == "recover-card" and (pc.get("options", []) as Array).size() == 2, "Xyzax : 2e choix ouvert")
	m._resolve_choice(0, 0)
	_ok((m.G["pendingChoice"] as Dictionary).is_empty() and ((m.G["players"][0] as Dictionary)["hand"] as Array).size() == 2,
		"Xyzax : deux cartes en main")
	m.queue_free()

## Seducia (HeroUnassigned = ville OU pioche de heros) : un heros choisi dans la pioche rejoint l'entree.
func _t_seducia_picks_from_hero_deck() -> void:
	var m = load("res://godot/scripts/Match.gd").new()
	add_child(m)
	m.G = _ability_G("BMA010")
	m.G["phase"] = "adventure"
	m.G["log"] = []
	m.G["choiceQueue"] = []
	m.G["decks"]["heroes"] = [{"id": "BMA081", "name": "H81"}]
	m.G["pendingChoice"] = RoomAbilities._seducia(m.G, 0)
	m._resolve_choice(0, 0)
	_ok(((m.G["players"][0] as Dictionary)["entrance"] as Array).size() == 1 and (m.G["decks"]["heroes"] as Array).is_empty(),
		"Seducia : le heros quitte la pioche pour l'entree")
	m.queue_free()

## DungeonSlot.CheckRoomCanBeBuilt : donjon plein, une salle ordinaire se pose par-dessus une pile, BMA018 comprise
## (CannotBuildRoom[Advanced, Any] ne refuse que les salles avancees ; oracle APK s5-p4 seq 509 : BMA009 sur BMA018).
func _t_full_dungeon_ordinary_over_stack() -> void:
	var m = _match_with_spell()
	var p: Dictionary = m.G["players"][0]
	p["id"] = 0
	p["dungeon"] = []
	for i in 5:
		(p["dungeon"] as Array).append([_room("BMA018" if i == 2 else "R%d" % i, "trap", false, [1])])
	p["hand"] = [_room("N", "trap", false, [1])]
	m.G["activePlayer"] = 0
	m.G["buildOrder"] = [0, 1]
	m.G["buildIndex"] = 0
	var n := 0
	var bad := false
	for mv in m.legal_moves(0):
		if str((mv as Dictionary).get("type", "")) != "buildRoom":
			continue
		var args: Array = (mv as Dictionary)["args"]
		n += 1
		bad = bad or args.size() < 2
	_ok(n == 5 and not bad, "donjon plein : 5 recouvrements possibles (BMA018 comprise), trouve %d" % n)
	m.queue_free()

## Fenetre de sorts apres la derniere construction (ActivePlayer == null) : ouverte si un siege non-IA a un sort jouable.
func _t_build_window_after_last_build() -> void:
	var m = _match_with_spell()
	m.G["activePlayer"] = 1
	m.G["buildOrder"] = [0, 1]
	m.G["buildIndex"] = 1
	m._advance_build()
	_ok(m.G.has("buildWindow") and str(m.G["phase"]) == "build", "fenetre de sorts ouverte apres la derniere construction")
	var types: Array = []
	for mv in m.legal_moves(0):
		types.append(str((mv as Dictionary).get("type", "")))
	_ok(types.has("playSpell") and types.has("passBuild") and not types.has("buildRoom"), "fenetre : sorts et 'pret', pas de construction")
	_ok(m.legal_moves(1).is_empty(), "fenetre : le siege IA passe d'office")
	m.queue_free()
	var m2 = _match_with_spell()
	((m2.G["players"][0] as Dictionary)["hand"] as Array).clear()
	m2._open_build_window()
	_ok(not m2.G.has("buildWindow"), "aucun sort jouable : pas de fenetre")
	m2.queue_free()

## Fenetre de sorts apres la derniere construction : l'IA y joue aussi (AIPlayerInteraction.InternalDoPlayerActions : UseAbility sans condition de joueur actif ;
## oracle-s2-p2 step 41, oracle-s3-p3 step 170). Elle choisit son sort par AI.pick_move, puis passe quand elle n'en a plus.
func _t_build_window_ai_plays_spell() -> void:
	var m = _match_with_spell()
	((m.G["players"][0] as Dictionary)["hand"] as Array).clear()
	((m.G["players"][1] as Dictionary)["hand"] as Array).append({"id": "BMA048", "name": "Jeopardy", "isSpell": true})
	m.G["activePlayer"] = 0 # le dernier constructeur est l'humain (il a appuye sur DONE)
	m.G["buildOrder"] = [1, 0]
	m.G["buildIndex"] = 1
	m._advance_build()
	var stack: Array = m.G.get("stack", [])
	_ok(m.G.has("buildWindow") and stack.size() == 1 and int((stack[0] as Dictionary).get("playerId", -1)) == 1
		and ((m.G["players"][1] as Dictionary)["hand"] as Array).is_empty(), "fenetre : le siege IA joue son sort (Jeopardy) sur la pile")
	m.queue_free()
	var m2 = _match_with_spell()
	((m2.G["players"][0] as Dictionary)["hand"] as Array).clear()
	m2.G["activePlayer"] = 0
	m2.G["buildOrder"] = [1, 0]
	m2.G["buildIndex"] = 1
	m2._advance_build()
	_ok(not m2.G.has("buildWindow") and str(m2.G["phase"]) != "build", "ni humain ni IA n'a de sort : pas de fenetre, la phase se referme")
	m2.queue_free()

## Un choix ouvert pendant la fenetre de sorts (sort ou capacite jouee par un siege, IA comprise) reprend la fenetre une fois resolu : la phase
## BUILD ne se referme pas d'office (sinon buildWindow resterait pose pendant l'aventure et la partie calerait).
func _t_choice_in_build_window_keeps_window() -> void:
	var spell := {"id": "BMA040", "name": "Annihilator", "isSpell": true}
	var m = load("res://godot/scripts/Match.gd").new()
	add_child(m)
	m.G = _choice_G("discard-spell", [{"card": spell}], [spell])
	m.G["buildWindow"] = {1: true}
	_ok(m.apply_move(0, {"type": "resolveChoice", "args": [0]}), "choix resolu dans la fenetre")
	_ok(m.G.has("buildWindow") and str(m.G["phase"]) == "build", "la fenetre reste ouverte tant que le siege 0 n'a pas passe")
	m.apply_move(0, {"type": "passBuild", "args": []})
	_ok(not m.G.has("buildWindow") and str(m.G["phase"]) != "build", "tous ont passe : la fenetre se ferme, la phase aussi")
	m.queue_free()

## Capacite de salle qui tue le heros (Bottomless Pit) : il meurt tout de suite (KillHeroInRoom), ame comptee.
func _t_ability_kill_finishes_hero() -> void:
	var m = load("res://godot/scripts/Match.gd").new()
	add_child(m)
	m.G = _ability_G("BMA027")
	var hero := {"id": "H", "name": "H", "souls": 1, "hp": 5}
	var p: Dictionary = m.G["players"][0]
	p["entrance"] = [hero]
	m.G["phase"] = "adventure"
	m.G["log"] = []
	m.G["activePlayer"] = 0
	m.G["adventure"] = {"playerId": 0, "hero": hero, "roomIndex": 0, "hp": 5, "pause": "post-damage"}
	_ok(m.apply_move(0, {"type": "activateRoom", "args": [0]}), "Bottomless Pit activable")
	_ok((m.G["adventure"] as Dictionary).is_empty() and (p["souls"] as Array).size() == 1, "heros tue par la capacite : ame immediate")
	m.queue_free()

## Zombie Attack (SendBackToDungeonEntrance) : le heros ENTIER revient (toutes ses ames), avec +2 PV.
func _t_zombie_attack_returns_whole_hero() -> void:
	var hero := {"id": "H", "name": "H", "souls": 2, "hp": 4}
	var G := _spell_state([])
	var foe: Dictionary = G["players"][1]
	foe["souls"] = [{"souls": 1, "hero": hero}, {"souls": 1, "hero": hero}]
	_ok(SpellEffects.cast_spell(G, 0, {"id": "BMA055"}, {"targetPlayerId": 1, "soulIndex": 0, "pile": "souls"}), "Zombie Attack accepte")
	_ok((foe["souls"] as Array).is_empty() and (foe["entrance"] as Array).size() == 1
		and BossEngine.hero_hp((foe["entrance"] as Array)[0]) == 6, "heros entier renvoye a l'entree avec +2 PV")

## BMA031 Recycling Center : DestroyRoom (checkTriggers) -> 2 salles piochees ; ChooseAndDestroyRoom (Robobo) : aucun declencheur.
func _t_destroy_recycling_center_draws_two() -> void:
	var G := _ability_G("BMA030")
	((G["players"][0] as Dictionary)["dungeon"] as Array).append([_room("BMA031", "trap", true, [1])])
	(G["decks"]["rooms"] as Array).append_array([_room("A", "trap", false, [1]), _room("B", "trap", false, [1]), _room("C", "trap", false, [1])])
	_ok(RoomAbilities.activate_room_ability(G, 0, 0) == null, "Jackpot Stash s'active avec un Recycling Center")
	_ok(((G["players"][0] as Dictionary)["hand"] as Array).size() == 2 and (G["decks"]["rooms"] as Array).size() == 1,
		"Recycling Center : 2 salles piochees quand une autre salle est detruite")
	var G2 := _ability_G("BMA030")
	((G2["players"][0] as Dictionary)["dungeon"] as Array).append([_room("BMA031", "trap", true, [1])])
	(G2["decks"]["rooms"] as Array).append_array([_room("A", "trap", false, [1]), _room("B", "trap", false, [1])])
	RoomAbilities.destroy_room_choice(G2, 0, 0, "Robobo")
	_ok(((G2["players"][0] as Dictionary)["hand"] as Array).is_empty(), "ChooseAndDestroyRoom (Robobo) ne declenche pas le Recycling Center")

## BMA032 n'a pas OncePerTurn (data.json) : rejouable ; BMA045 Fear sur le heros actif met fin a son aventure sans ame ni blessure.
func _t_crushinator_repeatable_fear_active_hero() -> void:
	var G := _ability_G("BMA032")
	var dg: Array = (G["players"][0] as Dictionary)["dungeon"]
	dg.append([_room("X", "trap", false, [1])])
	dg.append([_room("Y", "trap", false, [1])])
	_ok(RoomAbilities.activate_room_ability(G, 0, 0, 1) == null and RoomAbilities.activate_room_ability(G, 0, 0, 1) == null,
		"Crushinator s'active deux fois dans le tour")
	var G2 := _ability_G("BMA032")
	var hero := {"id": "H1", "name": "H1", "hp": 4}
	(G2["players"][1] as Dictionary)["entrance"] = [hero]
	G2["adventure"] = {"playerId": 1, "hero": hero, "roomIndex": 0, "hp": 4, "pause": "post-damage"}
	_ok(SpellEffects.cast_spell(G2, 0, {"id": "BMA045"}, {"heroId": "H1"}), "Fear accepte")
	_ok((G2["adventure"] as Dictionary).is_empty() and (G2["town"] as Array).size() == 1
		and ((G2["players"][1] as Dictionary)["entrance"] as Array).is_empty(), "Fear : le heros actif quitte l'aventure et retourne en ville")

## BMA054 Trepidation (Boss.ForceSkipAdventure) : les heros de la cible restent a l'entree, elle n'a plus rien a jouer en aventure.
func _t_trepidation_skips_adventure() -> void:
	var m = Match.new()
	add_child(m)
	m.G = {"players": {0: {"id": 0, "entrance": [{"id": "H1"}], "eliminated": false}}, "effects": SpellEffects.empty_effects()}
	_ok(m._has_entrance_hero(0), "heros a l'entree : il agit")
	_ok(SpellEffects.cast_spell(m.G, 1, {"id": "BMA054"}, {"targetPlayerId": 0}), "Trepidation accepte")
	_ok(not m._has_entrance_hero(0) and ((m.G["players"][0] as Dictionary)["entrance"] as Array).size() == 1,
		"Trepidation : plus d'aventure pour la cible, le heros reste a l'entree")

## BMA017 Minotaur's Maze : la premiere fois que le heros y entre, il recule d'une salle (et la re-subit) ; ensuite il avance normalement.
func _t_minotaur_maze_sends_hero_back() -> void:
	var m = Match.new()
	add_child(m)
	var hero := {"id": "H", "name": "H", "hp": 20}
	m.G = {"players": {0: {"id": 0, "dungeon": [[_room("A", "monster", false, [1])], [_room("BMA017", "trap", false, [1])], [_room("C", "trap", false, [1])]],
		"entrance": [hero], "hand": [], "souls": [], "wounds": []}},
		"log": [], "effects": SpellEffects.empty_effects(), "decks": {"heroDiscard": []}, "adventure": {"playerId": 0, "hero": hero, "roomIndex": -1, "hp": 20, "pause": null}}
	var seen: Array = []
	for _k in 5:
		m._advance_adventure_room()
		seen.append(int((m.G["adventure"] as Dictionary)["roomIndex"]))
	_ok(seen == [0, 1, 0, 1, 2], "Minotaur's Maze : A, Maze, A, Maze, C (obtenu %s)" % str(seen))

## EnqueueAbilityTransaction : une transaction du meme joueur passe AVANT celles deja en file => le level-up (mis en file apres
## le declencheur de la 5e salle) s'execute avant lui.
func _t_reveal_levelup_before_room_trigger() -> void:
	var G := _levelup_G("BMA005", 5)
	var last: Dictionary = ((((G["players"][0] as Dictionary)["dungeon"] as Array)[4] as Array)[0] as Dictionary)
	last["id"] = "BMA022"
	last["faceDown"] = true
	for i in 6:
		(G["decks"]["spells"] as Array).append({"id": "S%d" % i, "name": "S%d" % i, "isSpell": true})
	var m = Match.new()
	add_child(m)
	m.G = G
	_ok(m._reveal_and_level_up(), "la revelation ouvre un choix")
	_ok(str((G["pendingChoice"] as Dictionary).get("bossName", "")) == "Cerebellus", "le level-up (Cerebellus) passe avant la Dark Laboratory")

## Bottomless Pit detruit son slot en tuant le heros : plus de salle pour la mort (TopRoom == null), la salle suivante (Golem Factory) ne se declenche pas.
func _t_pit_kill_no_death_trigger_on_next_room() -> void:
	var m = Match.new()
	add_child(m)
	var hero := {"id": "H", "name": "H", "hp": 9, "souls": 1, "wounds": 1}
	var p := {"id": 0, "dungeon": [[_room("A", "trap", false, [1])], [_room("BMA027", "trap", false, [1])], [_room("BMA016", "monster", false, [1])]],
		"entrance": [hero], "hand": [], "souls": [], "wounds": []}
	m.G = {"players": {0: p}, "log": [], "logs": [], "effects": SpellEffects.empty_effects(), "town": [], "turn": 1,
		"decks": {"rooms": [_room("D", "trap", false, [1])], "spells": [], "roomDiscard": [], "spellDiscard": [], "heroDiscard": []},
		"adventure": {"playerId": 0, "hero": hero, "roomIndex": 1, "hp": 5, "pause": "post-damage"}}
	_ok(RoomAbilities.activate_room_ability(m.G, 0, 1) == null, "Bottomless Pit s'active")
	m._finish_hero_if_dead()
	_ok((p["hand"] as Array).is_empty() and (p["souls"] as Array).size() == 1, "ame capturee, aucune pioche Golem Factory")

## BMA024 Witch's Kitchen : RoomInHand(Monster) se choisit ; une seule salle Monster en main = defausse automatique.
func _t_witchs_kitchen_choice() -> void:
	var G := _ability_G("BMA024", [_room("M1", "monster", false, [1]), _room("M2", "monster", false, [1]), _room("T", "trap", false, [1])])
	(G["decks"]["spells"] as Array).append({"id": "S1", "name": "S1", "isSpell": true})
	_ok(RoomAbilities.activate_room_ability(G, 0, 0) == null, "Witch's Kitchen s'active")
	var pc: Dictionary = G.get("pendingChoice", {}) as Dictionary
	_ok(str(pc.get("type", "")) == "kitchen-discard" and (pc["options"] as Array).size() == 2, "deux salles Monster : choix ouvert")
	RoomAbilities.kitchen_discard(G, 0, (pc["options"] as Array)[1])
	var hand: Array = (G["players"][0] as Dictionary)["hand"]
	_ok(_card_ids(hand) == ["M1", "T", "S1"] and (G["decks"]["roomDiscard"] as Array).size() == 1, "la salle choisie (M2) est defaussee, un sort est pioche")

## Brainsucker Hive / Open Grave / Succubus Spa / Vampire Bordello : OncePerTurn eux aussi (data.json), pas seulement Golem Factory.
func _t_died_brainsucker_once_per_turn() -> void:
	var G := _ability_G("BMA021")
	for i in 4:
		(G["decks"]["spells"] as Array).append({"id": "S%d" % i, "name": "S%d" % i, "isSpell": true})
	var room: Dictionary = BossEngine.active_room(((G["players"][0] as Dictionary)["dungeon"] as Array)[0])
	RoomAbilities.on_hero_died_in_room(G, 0, room)
	RoomAbilities.on_hero_died_in_room(G, 0, room)
	_ok(((G["players"][0] as Dictionary)["hand"] as Array).size() == 1, "Brainsucker Hive : une seule pioche par tour")

# --- Parite APK (graines larges 4-7) : regles corrigees ---

## GameBoard.DestroyRoom (Dungeon.Remove + Add, 5 slots fixes) : le slot du heros passe en fin de liste, le heros le suit
## (InsideDungeonSlot) : il traverse les emplacements vides (5 - taille restante, un pas chacun, sans degat) puis repart de l'entree.
## Oracle s4-p2 seq 198-201 : 2 pas vides, puis BMA032 (et non la salle suivante).
func _t_destroy_hero_slot_traverses_empty_slots() -> void:
	var m = Match.new()
	add_child(m)
	var hero := {"id": "H", "name": "H", "hp": 20}
	var G := _ability_G("BMA010")
	var p: Dictionary = G["players"][0]
	p["dungeon"] = [[_room("A", "trap", false, [1])], [_room("B", "trap", false, [1])], [_room("C", "trap", false, [1])]]
	p["entrance"] = [hero]
	G["log"] = []
	G["adventure"] = {"playerId": 0, "hero": hero, "roomIndex": 0, "hp": 9, "pause": null}
	m.G = G
	BossEngine.destroy_room(p, 0, G) # le heros se tient dans la salle detruite : B, C restent
	var steps := 0
	while int((G["adventure"] as Dictionary)["roomIndex"]) < 0 and steps < 10:
		(G["adventure"] as Dictionary)["pause"] = null
		m._advance_adventure_room()
		steps += 1
		if int((G["adventure"] as Dictionary)["roomIndex"]) < 0:
			_ok(int((G["adventure"] as Dictionary)["hp"]) == 9, "emplacement vide : aucun degat")
	_ok(steps == 4, "heros dans le slot detruit : 5 - 2 = 3 emplacements vides traverses puis la 1re salle (pas " + str(steps) + ")")
	_ok(int((G["adventure"] as Dictionary)["roomIndex"]) == 0 and int((G["adventure"] as Dictionary)["hp"]) == 8,
		"puis il repart de l'entree : la 1re salle restante lui inflige ses degats")
	_ok(not (G["adventure"] as Dictionary).has("roomGone"), "le heros a quitte le slot disparu : sa mort retrouve une salle")
	m.queue_free()

## DealRoomsCountToHero (Exhaustion) : X = Boss.DungeonActiveRooms, donc sans les slots geles par Freeze (oracle s5-p4 seq 283).
func _t_exhaustion_ignores_frozen_rooms() -> void:
	var G := _ability_G("BMA010")
	var p: Dictionary = G["players"][0]
	p["dungeon"] = [[_room("A", "trap", false, [1])], [_room("B", "trap", false, [1])], [_room("C", "trap", false, [1])]]
	var hero := {"id": "H", "name": "H", "hp": 10}
	G["adventure"] = {"playerId": 0, "hero": hero, "roomIndex": 1, "hp": 10, "pause": null}
	((G["effects"] as Dictionary)["deactivatedRooms"] as Array).append({"playerId": 0, "roomIndex": 2})
	_ok(SpellEffects.cast_spell(G, 0, {"id": "BMA044", "name": "Exhaustion"}, {"heroId": "H"}), "Exhaustion accepte")
	_ok(int((G["adventure"] as Dictionary)["hp"]) == 8, "2 salles actives (la 3e est gelee) : 2 degats, pas 3")

## FlipHero (Vampire Bordello) : HeroInScorekeep[Owner, Alive] -> le joueur CHOISIT le heros vivant a retourner ; un epique
## passe en entier (toutes ses blessures, toutes ses ames). Oracle s5-p4 seq 335-337 : BMA073 retourne, pas la derniere blessure.
func _t_vampire_bordello_choice_flips_whole_hero() -> void:
	var G := _ability_G("BMA014")
	var p: Dictionary = G["players"][0]
	var h1 := {"id": "H1", "name": "H1", "souls": 1, "wounds": 1}
	var h2 := {"id": "H2", "name": "H2", "epic": true, "souls": 2, "wounds": 2}
	p["wounds"] = [{"name": "H1", "wounds": 1, "souls": 1, "hero": h1}, {"name": "H2", "wounds": 1, "souls": 1, "hero": h2},
		{"name": "H2", "wounds": 1, "souls": 1, "hero": h2}]
	var room: Dictionary = BossEngine.active_room((p["dungeon"] as Array)[0])
	var choice = RoomAbilities.on_hero_died_in_room(G, 0, room)
	_ok(choice != null and str((choice as Dictionary).get("type", "")) == "heal-wound" and ((choice as Dictionary)["options"] as Array).size() == 2,
		"2 heros vivants : un choix, une option par heros (pas par blessure)")
	var m = Match.new()
	add_child(m)
	G["log"] = []
	G["choiceQueue"] = []
	G["phase"] = "adventure"
	G["pendingChoice"] = choice
	m.G = G
	m._resolve_choice(0, 1)
	_ok(CardDB.total_wounds(p) == 1 and CardDB.total_souls(p) == 2 and (p["wounds"] as Array).size() == 1,
		"l'epique choisi est retourne en entier : -2 blessures, +2 ames ; H1 reste blesse")
	m.queue_free()
	# Un seul heros vivant : retourne d'office (TryToAutoresolve).
	var G2 := _ability_G("BMA014")
	var p2: Dictionary = G2["players"][0]
	p2["wounds"] = [{"name": "H1", "wounds": 1, "souls": 1, "hero": h1}]
	var room2: Dictionary = BossEngine.active_room((p2["dungeon"] as Array)[0])
	_ok(RoomAbilities.on_hero_died_in_room(G2, 0, room2) == null and CardDB.total_souls(p2) == 1 and CardDB.total_wounds(p2) == 0,
		"un seul heros vivant : retourne sans choix")

## Room.Deal : le +3 d'Annihilator/Giant Size reste sur la carte tant qu'elle n'est pas dans un donjon a la fin du tour (Boss.RestoreDungeon).
## Oracle s34-p3 : un Bottomless Pit buffe puis detruit au tour 2 frappe encore a 4 quand il est reconstruit au tour 5.
func _t_spell_room_buff_survives_destruction() -> void:
	var G := _spell_state([[_room("T", "trap", false, [1])], [_room("U", "trap", false, [1])]])
	var p: Dictionary = G["players"][0]
	_ok(SpellEffects.cast_spell(G, 0, {"id": "BMA040"}, {"roomIndex": 0}), "Annihilator joue")
	var card = BossEngine.destroy_room(p, 0, G)
	BossEngine.discard_room_to_pile(G["decks"], card)
	p["dungeon"] = [[card]]
	_ok(BossEngine.room_damage_with_modifiers(G, p, 0, {}) == 4, "salle detruite puis reconstruite : le +3 est reste sur la carte")
	var m = _match_with_spell()
	m.G["autoAI"] = false
	var kept := _room("K", "trap", false, [1])
	kept["dealDamage"] = 3
	(m.G["players"][0] as Dictionary)["dungeon"] = [[kept]]
	m._start_turn()
	_ok(not kept.has("dealDamage"), "fin de tour : les salles encore en donjon repartent a leurs degats de base")
	m.queue_free()

## BMA049 Kobold Strike (UndoBuildRoom) : la salle posee ce tour revient dans la MAIN de son proprietaire, face visible (pas defaussee).
## Oracle s11-p3 seq 37 : BMA010 rend a P1.
func _t_kobold_strike_returns_rooms_to_hand() -> void:
	var G := _spell_state()
	var built := _room("B", "trap", false, [1])
	built["faceDown"] = true
	built["builtThisTurn"] = true
	(G["players"][1] as Dictionary)["dungeon"] = [[built], [_room("Old", "trap", false, [1])]]
	_ok(SpellEffects.cast_spell(G, 0, {"id": "BMA049"}, {}), "Kobold Strike accepte")
	var foe: Dictionary = G["players"][1]
	_ok((foe["dungeon"] as Array).size() == 1 and (foe["hand"] as Array).size() == 1 and (G["decks"]["roomDiscard"] as Array).is_empty(),
		"la salle face cachee du tour revient en main (slot supprime, rien en defausse)")
	_ok(not (foe["hand"][0] as Dictionary).has("faceDown") and not (foe["hand"][0] as Dictionary).has("builtThisTurn"), "elle redevient une carte de main ordinaire")
	_ok(BossEngine.is_build_blocked(G), "plus aucune construction ce tour")

## GameBoard.RevealHeroes : pioche de heros vide => « No more heroes in deck », la defausse de heros n'est jamais remelangee.
func _t_hero_deck_is_never_reshuffled() -> void:
	var m = load("res://godot/scripts/Match.gd").new()
	add_child(m)
	m.G = _ability_G("BMA010")
	m.G["log"] = []
	m.G["decks"]["heroes"] = []
	m.G["decks"]["epics"] = []
	m.G["decks"]["heroDiscard"] = [{"id": "H1", "treasure": 1}, {"id": "H2", "treasure": 1}]
	m._reveal_heroes_in_town()
	_ok((m.G["town"] as Array).is_empty() and (m.G["decks"]["heroDiscard"] as Array).size() == 2, "aucun heros revele : la defausse reste en l'etat")
	m.queue_free()

## CannotBuildRoom[Advanced, Any] (BMA018) ne refuse que les salles AVANCEES : une ordinaire se pose par-dessus (oracle s5-p4 seq 509).
func _t_neanderthal_cave_accepts_ordinary_over() -> void:
	var cave := _room("BMA018", "monster", false, [1])
	var ordinary := _room("O", "trap", false, [2])
	_ok(BossEngine.can_build_room(_player([[cave]], [ordinary]), {}, 0, 0, 0), "BMA018 accepte une salle ordinaire")

## BMA035 Dragon Hatchery : aucune capacite, mais les 4 types de tresor (data.json Treasures [1,3,2,4]) : toute salle avancee s'y batit.
func _t_dragon_hatchery_all_four_treasures() -> void:
	var hatchery := _room("BMA035", "monster", false, [1, 3, 2, 4])
	for t in [1, 2, 3, 4]:
		_ok(BossEngine.can_build_room(_player([[hatchery]], [_room("X", "trap", true, [t])]), {}, 0, 0, 0),
			"Dragon Hatchery accepte une salle avancee au tresor %d" % t)

## Trepidation joue pendant la fenetre pre-aventure de la cible : son heros actif (deja designe) est retire du jeu, les suivants restent
## a l'entree ; joue ailleurs, tous restent (oracle s5-p3 seq 265 / s7-p4 seq 489).
func _t_trepidation_removes_active_hero_only_in_pre_adventure() -> void:
	var G := _ability_G("BMA010")
	G["phase"] = CardDB.PHASE["ADVENTURE"]
	G["activePlayer"] = 0
	(G["players"][0] as Dictionary)["entrance"] = [{"id": "H1"}, {"id": "H2"}]
	_ok(SpellEffects.cast_spell(G, 1, {"id": "BMA054"}, {"targetPlayerId": 0}), "Trepidation accepte")
	var ent: Array = (G["players"][0] as Dictionary)["entrance"]
	_ok(ent.size() == 1 and str((ent[0] as Dictionary)["id"]) == "H2", "cible active : son heros actif est retire du jeu, le suivant reste")
	var G2 := _ability_G("BMA010")
	G2["phase"] = CardDB.PHASE["ADVENTURE"]
	G2["activePlayer"] = 1
	(G2["players"][0] as Dictionary)["entrance"] = [{"id": "H1"}, {"id": "H2"}]
	SpellEffects.cast_spell(G2, 1, {"id": "BMA054"}, {"targetPlayerId": 0})
	_ok(((G2["players"][0] as Dictionary)["entrance"] as Array).size() == 2, "cible pas encore active : ses heros restent a l'entree")

## EntranceQueue persiste d'un tour a l'autre (seul RemoveHeroFromGame la vide) : les heros laisses par Trepidation entrent au tour suivant.
func _t_entrance_persists_across_turns() -> void:
	var m = _match_with_spell()
	m.G["autoAI"] = false
	(m.G["players"][0] as Dictionary)["entrance"] = [{"id": "H1", "name": "H1"}]
	m.G["decks"]["rooms"] = [_room("R", "trap", false, [1]), _room("R2", "trap", false, [1])]
	m._start_turn()
	_ok(((m.G["players"][0] as Dictionary)["entrance"] as Array).size() == 1, "le heros reste a l'entree au debut du tour suivant")
	m.queue_free()

## BMA023 Haunted Library (Boss.IsCanChooseCardToDraw) : le joueur choisit sa pioche de debut de tour ; les autres piochent une salle.
func _t_haunted_library_chooses_draw() -> void:
	var m = _match_with_spell()
	m.G["autoAI"] = false
	(m.G["players"][0] as Dictionary)["hand"] = []
	(m.G["players"][0] as Dictionary)["dungeon"] = [[_room("BMA023", "trap", false, [3])]]
	m.G["decks"]["rooms"] = [_room("R1", "trap", false, [1]), _room("R2", "trap", false, [1])]
	m.G["decks"]["spells"] = [{"id": "S1", "name": "S1", "isSpell": true}]
	m._start_turn()
	var pc: Dictionary = m.G.get("pendingChoice", {})
	_ok(str(pc.get("type", "")) == "draw-type" and int(pc.get("playerId", -1)) == 0 and (pc["options"] as Array).size() == 2,
		"Haunted Library : choix de pioche ouvert pour son proprietaire")
	_ok(((m.G["players"][0] as Dictionary)["hand"] as Array).is_empty() and ((m.G["players"][1] as Dictionary)["hand"] as Array).size() == 1,
		"les autres joueurs ont pioche une salle ; le proprietaire n'a pas encore pioche")
	_ok(m.legal_moves(1).is_empty() and m.legal_moves(0).size() == 2, "partie gelee : seul le proprietaire repond (salle ou sort)")
	m._resolve_choice(0, 1)
	var hand0: Array = (m.G["players"][0] as Dictionary)["hand"]
	_ok(hand0.size() == 1 and bool((hand0[0] as Dictionary).get("isSpell", false)), "pioche dans la pioche de sorts")
	_ok((m.G["decks"]["rooms"] as Array).size() == 1 and (m.G["pendingChoice"] as Dictionary).is_empty(), "pas de pioche de salle en plus, choix clos")
	_ok(not RoomAbilities.can_choose_draw({"dungeon": [[{"id": "BMA023", "faceDown": true}]]}), "face cachee (pas encore revelee) : pas de choix")
	m.queue_free()

## BMA012 Succubus Spa : BossOpponent + PickRandomCardFromHand(1, Any) : une carte au hasard (salle OU sort) de l'adversaire passe dans la main.
func _t_succubus_spa_steals_random_card() -> void:
	var G := _ability_G("BMA012")
	var victim: Dictionary = G["players"][1]
	victim["hand"] = [_room("R", "trap", false, [1]), {"id": "S", "name": "S", "isSpell": true, "_oid": 7}]
	var room: Dictionary = BossEngine.active_room(((G["players"][0] as Dictionary)["dungeon"] as Array)[0])
	G["forcedRandom"] = [7] # crochet de rejeu : l'oracle a pris le sort
	_ok(RoomAbilities.on_hero_died_in_room(G, 0, room) == null, "deux joueurs : adversaire auto-designe, aucun choix")
	var mine: Array = (G["players"][0] as Dictionary)["hand"]
	_ok(mine.size() == 1 and str((mine[0] as Dictionary).get("id", "")) == "S" and (victim["hand"] as Array).size() == 1,
		"le sort tire passe de la main de l'adversaire a celle du proprietaire")
	room["usedThisTurn"] = false
	G["forcedRandom"] = [999] # rejeu : aucune carte n'a bouge dans la trace oracle
	RoomAbilities.on_hero_died_in_room(G, 0, room)
	_ok(mine.size() == 1, "rejeu : pas de carte forcee = pas de vol")
	# 3 joueurs : l'adversaire se choisit.
	var G3 := _ability_G("BMA012")
	G3["players"][2] = {"id": 2, "dungeon": [], "hand": [_room("Q", "trap", false, [1])], "souls": [], "wounds": [], "entrance": [], "items": [], "eliminated": false}
	var room3: Dictionary = BossEngine.active_room(((G3["players"][0] as Dictionary)["dungeon"] as Array)[0])
	var choice = RoomAbilities.on_hero_died_in_room(G3, 0, room3)
	_ok(choice != null and str((choice as Dictionary).get("type", "")) == "pick-opponent" and str((choice as Dictionary).get("action", "")) == "steal-random"
		and ((choice as Dictionary)["options"] as Array).size() == 2, "3 joueurs : choix de l'adversaire")
	var m = Match.new()
	add_child(m)
	G3["log"] = []
	G3["choiceQueue"] = []
	G3["phase"] = "adventure"
	G3["pendingChoice"] = choice
	m.G = G3
	m._resolve_choice(0, 1)
	_ok(((G3["players"][0] as Dictionary)["hand"] as Array).size() == 1 and ((G3["players"][2] as Dictionary)["hand"] as Array).is_empty(),
		"la carte de l'adversaire choisi rejoint la main du proprietaire")
	m.queue_free()
