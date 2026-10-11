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

## engine.js:canBuildRoom. G et player_id optionnels pour rester compatible avec
## l'ancien appel Match.gd (G absent -> regles de base).
static func can_build_room(player: Dictionary, G: Dictionary = {}, pid: int = -1, hand_index: int = -1, target_index: int = -1) -> bool:
	var dungeon: Array = player.get("dungeon", [])
	if hand_index >= 0:
		var hand: Array = player.get("hand", [])
		if hand_index >= hand.size():
			return false
		var card: Dictionary = hand[hand_index]
		if not bool(card.get("isRoom", false)):
			return false
		if is_build_blocked(G):
			return false
		if pid >= 0 and no_entry(pid, G):
			return false
		var allowed := 1 + (extra_builds_for(G, pid) if pid >= 0 else 0)
		if int(player.get("buildsThisTurn", 0)) >= allowed:
			return false
		var visible := count_visible_rooms(dungeon)
		if not bool(card.get("advanced", false)):
			# Salle ordinaire : possible en fin de donjon ou sur une pile existante.
			if visible >= CardDB.DUNGEON_SLOTS and target_index < 0:
				return false
			return true
		# Salle avancee : doit se batir sur une salle active au tresor correspondant.
		if dungeon.is_empty():
			return false
		var idx := target_index if target_index >= 0 else dungeon.size() - 1
		if idx < 0 or idx >= dungeon.size():
			return false
		var target = active_room(dungeon[idx])
		if target == null:
			return false
		# BMA018 Neanderthal Cave : on ne peut pas batir par-dessus.
		if str((target as Dictionary).get("id", "")) == "BMA018":
			return false
		var treasures_match := false
		for t in card.get("treasures", []):
			if ((target as Dictionary).get("treasures", []) as Array).has(t):
				treasures_match = true
				break
		return treasures_match
	return count_visible_rooms(dungeon) < CardDB.DUNGEON_SLOTS

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

# --- engine.js: index visuel <-> index de donjon (5 emplacements, 0 = fond a gauche) ---

static func extend_visual_index(dungeon: Array):
	var n := dungeon.size()
	if n >= CardDB.DUNGEON_SLOTS:
		return null
	if n == 0:
		return CardDB.DUNGEON_SLOTS - 1
	return CardDB.DUNGEON_SLOTS - n - 1

static func dungeon_index_from_visual(dungeon: Array, visual_index: int):
	var di := visual_index - (CardDB.DUNGEON_SLOTS - dungeon.size())
	return di if di >= 0 else null

# --- engine.js: healOneWound ---

## Retire une blessure du boss et rend l'ame correspondante face cachee.
static func heal_one_wound(player: Dictionary):
	var wounds: Array = player.get("wounds", [])
	if wounds.is_empty():
		return null
	var w: Dictionary = wounds.pop_back()
	var soul := {"souls": int(w.get("souls", 1)), "name": w.get("name", ""), "class": w.get("class", ""), "faceDown": true}
	if not player.has("souls"):
		player["souls"] = []
	(player["souls"] as Array).append(soul)
	return soul

# --- engine.js: isRoomDeactivated / isBuildBlocked ---

static func is_room_deactivated(G: Dictionary, player_id: int, room_index: int) -> bool:
	for e in _effects(G).get("deactivatedRooms", []):
		var d: Dictionary = e
		if int(d.get("playerId", -1)) == int(player_id) and int(d.get("roomIndex", -1)) == room_index:
			return true
	return false

static func is_build_blocked(G: Dictionary) -> bool:
	return bool(_effects(G).get("buildBlocked", false))

static func no_entry(player_id: int, G: Dictionary) -> bool:
	for id in _effects(G).get("noRoomBuild", []):
		if int(id) == int(player_id):
			return true
	return false

static func extra_builds_for(G: Dictionary, player_id: int) -> int:
	var n := 0
	for id in _effects(G).get("extraBuild", []):
		if int(id) == int(player_id):
			n += 1
	return n

## G.effects peut etre absent sur un etat solo minimal.
static func _effects(G: Dictionary) -> Dictionary:
	return G.get("effects", {}) as Dictionary

# --- engine.js: roomDamageWithModifiers (partie regles de base, hors expansions) ---

## Degats d'une salle pour un hero donne, avec les modificateurs de l'engine.
static func room_damage_with_modifiers(G: Dictionary, player: Dictionary, room_index: int, hero) -> int:
	var dungeon: Array = player.get("dungeon", [])
	if room_index < 0 or room_index >= dungeon.size():
		return 0
	var room = active_room(dungeon[room_index])
	if room == null:
		return 0
	var r: Dictionary = room
	var dmg := int(r.get("damage", 0))
	var pid := int(player.get("id", 0))

	# BMA020 Monster's Ballroom : degats = nombre de salles Monster actives
	if str(r.get("id", "")) == "BMA020":
		var n := 0
		for x in all_active_rooms(dungeon):
			if x != null and str((x as Dictionary).get("type", "")) == "monster":
				n += 1
		dmg = n

	# BMA015 Goblin Armory : +1 aux salles Monster adjacentes
	# BMA029 Dizzygas Hallway : +2 aux salles Trap immediatement a droite
	for i in dungeon.size():
		if i == room_index:
			continue
		var other = active_room(dungeon[i])
		if other == null:
			continue
		var o: Dictionary = other
		var ot := str(o.get("type", ""))
		if str(o.get("id", "")) == "BMA015" and absi(i - room_index) == 1 and ot == "monster":
			dmg += 1
		if str(o.get("id", "")) == "BMA029" and i == room_index - 1 and ot == "trap":
			dmg += 2

	# Bonus de degats poses par les sorts/effets
	for e in _effects(G).get("roomDamageBonus", []):
		var ed: Dictionary = e
		if int(ed.get("playerId", -1)) == pid and int(ed.get("roomIndex", -1)) == room_index:
			dmg += int(ed.get("amount", 0))

	# BMA049 Skip Build / BMA043 : degats des salles ordinaires +1
	for id in _effects(G).get("ordinaryMonsterBonus", []):
		if int(id) == pid and str(r.get("type", "")) == "monster" and not bool(r.get("advanced", false)):
			dmg += 1

	return maxi(0, dmg)

# --- engine.js: heroHealthWithModifiers (partie regles de base) ---

static func hero_health_with_modifiers(G: Dictionary, hero: Dictionary) -> int:
	var hp := int(hero.get("hp", 0))
	for e in _effects(G).get("heroHealthBonus", []):
		var ed: Dictionary = e
		if str(ed.get("heroId", "")) == str(hero.get("id", "")):
			hp += int(ed.get("amount", 0))
	return hp

# --- engine.js: destroyRoom / discardRoomToPile ---

## Detruit la salle active de room_index. Renvoie la carte detruite, ou null.
static func destroy_room(player: Dictionary, room_index: int):
	var dungeon: Array = player.get("dungeon", [])
	if room_index < 0 or room_index >= dungeon.size():
		return null
	var stack: Array = dungeon[room_index]
	if stack.is_empty():
		return null
	var destroyed: Dictionary = stack.pop_back()
	if stack.is_empty():
		dungeon.remove_at(room_index)
	return destroyed

static func discard_room_to_pile(decks: Dictionary, card) -> void:
	if card == null:
		return
	var pile: Array = decks.get("roomDiscard", [])
	decks["roomDiscard"] = pile
	pile.append(card)
