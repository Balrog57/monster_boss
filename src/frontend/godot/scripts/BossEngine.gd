class_name BossEngine
extends RefCounted
## Miroir de src/backend/game/engine.js (stateless sur des Dictionnaires).
## Ne mute que via les callers (Match.gd).

static func active_room(stack: Array):
	if stack.is_empty():
		return null
	return stack[stack.size() - 1]

static func all_active_rooms(dungeon: Array) -> Array:
	var out: Array = []
	for stack in dungeon:
		out.append(active_room(stack))
	return out

static func count_visible_rooms(dungeon: Array) -> int:
	var n := 0
	for r in all_active_rooms(dungeon):
		if r != null:
			n += 1
	return n

static func dungeon_treasures(player: Dictionary) -> Array:
	var out: Array = []
	if player.get("boss") == null:
		return out
	for t in (player["boss"] as Dictionary).get("treasures", []):
		out.append(int(t))
	for stack in player.get("dungeon", []):
		var room = active_room(stack)
		if room == null:
			continue
		for t in (room as Dictionary).get("treasures", []):
			out.append(int(t))
	return out

static func treasure_count(player: Dictionary, treasure: int) -> int:
	var n := 0
	for t in dungeon_treasures(player):
		if int(t) == treasure:
			n += 1
	return n

static func treasure_counts(player: Dictionary) -> Dictionary:
	return {
		1: treasure_count(player, 1),
		2: treasure_count(player, 2),
		3: treasure_count(player, 3),
		4: treasure_count(player, 4),
	}

static func can_build_room(player: Dictionary) -> bool:
	return count_visible_rooms(player.get("dungeon", [])) < CardDB.DUNGEON_SLOTS

## Lure APK : le héros va chez le joueur non-éliminé avec le max du trésor demandé.
## Égalité -> reste en ville (retour -1).
static func lure_target(players: Dictionary, order: Array, treasure: int) -> int:
	var best := -1
	var best_n := -1
	var tied := false
	for pid in order:
		var p: Dictionary = players[pid]
		if p.get("eliminated", false):
			continue
		var n := treasure_count(p, treasure)
		if n > best_n:
			best_n = n
			best = int(pid)
			tied = false
		elif n == best_n:
			tied = true
	if tied:
		return -1
	return best

static func hero_souls(hero: Dictionary) -> int:
	return int(hero.get("souls", 1))

static func hero_wounds(hero: Dictionary) -> int:
	return int(hero.get("wounds", 1))
