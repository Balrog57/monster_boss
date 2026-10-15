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
## Delegue a BossEngine.can_build_room (miroir de engine.js:canBuildRoom) pour eviter
## toute divergence entre la logique de construction et les regles de l'engine.
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
	if not bool(card.get("isRoom", false)):
		return false
	return BossEngine.can_build_room(p, G, pid, hand_idx, slot_idx)

## Construit une salle sur un emplacement spécifique (nouvel emplacement ou recouvrement).
## Delegue a Match.apply_move : c'est le SEUL chemin de construction. Le build doit
## passer face cachee et l'abilite "quand tu construis cette salle" ne doit se
## declencher qu'a la revelation de fin de phase (BuildPhase_b de l'APK), jamais
## a la pose. Construire ici directement faisait diverger l'UI du moteur.
func build_room_at(pid: int, hand_idx: int, slot_idx: int = -1) -> bool:
	if not can_build_room_at(pid, hand_idx, slot_idx):
		return false
	# legal_moves ne propose qu'un coup [i] pour une salle ordinaire (posee a l'entree) ; [i, cible] n'existe que pour les avancees.
	var card: Dictionary = ((G["players"][pid] as Dictionary)["hand"] as Array)[hand_idx]
	var args: Array = [hand_idx, slot_idx] if bool(card.get("advanced", false)) else [hand_idx]
	return apply_move(pid, {"type": "buildRoom", "args": args})

## Phase de leurre : détermine pour chaque héros en ville quel donjon l'attire
func calculate_lure() -> Array:
	var results: Array = []
	var town: Array = G.get("town", [])
	var order := _turn_order()
	for hero in town:
		var treasure := int((hero as Dictionary).get("treasure", 1))
		var target := BossEngine.lure_target(G["players"], order, treasure, hero, G)
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
