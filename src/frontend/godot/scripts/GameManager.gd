class_name GameManager
extends "res://godot/scripts/Match.gd"
## GameManager.gd — Gestionnaire global du jeu Boss Monster (Godot 4).
## Orchestre les phases : SETUP -> BEGINNING -> BUILD -> BAIT (Leurre) -> ADVENTURE -> END.
## Gère le recouvrement des salles ordinaires et avancées, le calcul des trésors,
## et la boucle d'aventure avec attribution des âmes (victoire à 10) et blessures (défaite à 5).

signal phase_changed(new_phase: String)
signal hero_lured(hero: Dictionary, target_player: int)
signal hero_adventured(hero: Dictionary, player_id: int, killed: bool, hp_remaining: int)
signal game_finished(winner_id: int, reason: String)

func _ready() -> void:
	super._ready()

## Démarre une nouvelle partie
func start_new_game(num_players: int = 2, p_human_count: int = 1, p_sets: Array = ["base"]) -> Dictionary:
	var state = new_match(num_players, p_human_count, p_sets)
	phase_changed.emit(state.get("phase", ""))
	return state

## Vérifie si une salle en main peut être construite sur un emplacement spécifique.
## slot_index == -1 ou slot_index >= dungeon.size() indique un nouvel emplacement de donjon.
func can_build_room_at(pid: int, hand_idx: int, slot_idx: int = -1) -> bool:
	if G.get("gameOver") != null:
		return false
	var players: Dictionary = G.get("players", {})
	if not players.has(pid):
		return false
	var p: Dictionary = players[pid]
	var hand: Array = p.get("hand", [])
	if hand_idx < 0 or hand_idx >= hand.size():
		return false
	var card: Dictionary = hand[hand_idx]
	if not card.get("isRoom", false):
		return false
	if int(p.get("buildsThisTurn", 0)) >= 1 and G.get("phase") != "setup":
		return false

	var dungeon: Array = p.get("dungeon", [])
	var is_adv: bool = bool(card.get("isAdvanced", card.get("advanced", false)))

	# Construction sur un emplacement existant (recouvrement)
	if slot_idx >= 0 and slot_idx < dungeon.size():
		var stack: Array = dungeon[slot_idx]
		var active = BossEngine.active_room(stack)
		if active == null:
			return true
		if is_adv:
			# Salle avancée : doit partager au moins un type de trésor avec la salle active
			var card_treasures: Array = card.get("treasures", [])
			var active_treasures: Array = (active as Dictionary).get("treasures", [])
			for t in card_treasures:
				if int(t) in active_treasures:
					return true
			return false
		else:
			# Salle ordinaire : peut recouvrir n'importe quelle salle existante
			return true
	else:
		# Nouvel emplacement
		if is_adv:
			# Une salle avancée NE PEUT PAS être posée sur un emplacement vide
			return false
		return BossEngine.count_visible_rooms(dungeon) < CardDB.DUNGEON_SLOTS

## Construit une salle sur un emplacement spécifique (nouvel emplacement ou recouvrement)
func build_room_at(pid: int, hand_idx: int, slot_idx: int = -1) -> bool:
	if not can_build_room_at(pid, hand_idx, slot_idx):
		return false
	var p: Dictionary = G["players"][pid]
	var card: Dictionary = (p["hand"] as Array).pop_at(hand_idx)
	var dungeon: Array = p["dungeon"]
	
	if slot_idx >= 0 and slot_idx < dungeon.size():
		# Recouvrement
		(dungeon[slot_idx] as Array).append(card)
		_log("Joueur %d améliore l'emplacement %d avec %s%s." % [
			pid, slot_idx + 1, card.get("name", "?"),
			" (Salle Avancée)" if card.get("isAdvanced", false) else ""
		])
	else:
		# Nouvelle salle construite à l'entrée (index 0)
		dungeon.push_front([card])
		_log("Joueur %d construit %s." % [pid, card.get("name", "?")])

	p["buildsThisTurn"] = int(p.get("buildsThisTurn", 0)) + 1

	if G["phase"] == "setup" and _all_have_initial_room():
		_start_turn()
	elif G["phase"] == "build":
		_end_build_for(pid)

	state_changed.emit()
	return true

## Phase de leurre : détermine pour chaque héros en ville quel donjon l'attire
func calculate_lure() -> Array:
	var results: Array = []
	var town: Array = G.get("town", [])
	var order := _turn_order()
	for hero in town:
		var treasure := int((hero as Dictionary).get("treasure", 1))
		var target := BossEngine.lure_target(G["players"], order, treasure)
		results.append({"hero": hero, "target": target})
	return results

## Résolution d'un héros dans le donjon avec détail des étapes
func advance_hero_in_dungeon(pid: int, hero: Dictionary) -> Dictionary:
	var p: Dictionary = G["players"][pid]
	var hp := BossEngine.hero_wounds(hero)
	var initial_hp := hp
	var rooms_hit: Array = []

	for i in (p.get("dungeon", []) as Array).size():
		if hp <= 0:
			break
		var stack: Array = p["dungeon"][i]
		var room = BossEngine.active_room(stack)
		if room == null:
			continue
		var dmg := int((room as Dictionary).get("damage", 0))
		hp -= dmg
		rooms_hit.append({"room": room.get("name", "?"), "damage": dmg, "hp_after": max(0, hp)})

	var killed := hp <= 0
	if killed:
		(p["souls"] as Array).append({"name": hero.get("name", "?"), "souls": BossEngine.hero_souls(hero)})
		_log("%s vaincu dans le donjon du joueur %d ! (+%d âme)" % [
			hero.get("name", "?"), pid, BossEngine.hero_souls(hero)
		])
	else:
		(p["wounds"] as Array).append({"name": hero.get("name", "?"), "wounds": 1})
		_log("%s atteint le boss du joueur %d et inflige 1 blessure ! (%d/5)" % [
			hero.get("name", "?"), pid, CardDB.total_wounds(p)
		])
		if CardDB.total_wounds(p) >= 5:
			p["eliminated"] = true
			_log("Joueur %d a succombé à ses blessures !" % pid)

	hero_adventured.emit(hero, pid, killed, hp)
	return {
		"hero": hero,
		"player_id": pid,
		"killed": killed,
		"initial_hp": initial_hp,
		"remaining_hp": hp,
		"rooms_traversed": rooms_hit
	}
