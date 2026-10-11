class_name RoomAbilities
extends RefCounted
## Miroir de src/backend/game/roomAbilities.js — abilities des salles du base set (BMA).
## Chaque fonction renvoie null si tout s'est bien passe, ou un message d'erreur.

static func _player(G: Dictionary, pid: int) -> Dictionary:
	var players: Dictionary = G.get("players", {})
	return players.get(pid, players.get(str(pid), {})) as Dictionary

static func _log(G: Dictionary, t: String) -> void:
	var logs: Array = G.get("logs", [])
	G["logs"] = logs
	logs.append(t)

static func _effects(G: Dictionary) -> Dictionary:
	if not G.has("effects") or (G["effects"] as Dictionary).is_empty():
		G["effects"] = SpellEffects.empty_effects()
	return G["effects"]

## Le hero d'aventure est-il dans cette salle ?
static func hero_is_in_room(G: Dictionary, player_id: int, room_index: int) -> bool:
	var adv: Dictionary = G.get("adventure", {}) as Dictionary
	if adv.is_empty():
		return false
	return int(adv.get("playerId", -1)) == player_id \
		and int(adv.get("roomIndex", -1)) == room_index \
		and not (adv.get("hero", {}) as Dictionary).is_empty()

## Cartes disponibles dans les défausses ('room' | 'spell' | 'monster' | 'any').
static func discard_card_options(G: Dictionary, kind: String) -> Array:
	var decks: Dictionary = G.get("decks", {})
	var opts: Array = []
	var rooms: Array = decks.get("roomDiscard", [])
	var spells: Array = decks.get("spellDiscard", [])
	if kind != "spell":
		for i in rooms.size():
			var c: Dictionary = rooms[i]
			if kind == "monster" and str(c.get("type", "")) != "monster":
				continue
			if kind == "room" and not (bool(c.get("isRoom", false)) or c.has("type")):
				continue
			opts.append({"card": c, "pile": "room", "pileIndex": i})
	if kind != "room" and kind != "monster":
		for i in spells.size():
			opts.append({"card": spells[i], "pile": "spell", "pileIndex": i})
	return opts

## Recupere une carte d'une defausse dans la main. G est l'etat complet (contient G.decks).
static func take_discard_card(G: Dictionary, player: Dictionary, option: Dictionary) -> Variant:
	var decks: Dictionary = G.get("decks", {})
	var pile_name := "spellDiscard" if str(option.get("pile", "room")) == "spell" else "roomDiscard"
	var pile: Array = decks.get(pile_name, [])
	decks[pile_name] = pile
	var want: Dictionary = option.get("card", {}) as Dictionary
	var idx := -1
	if pile_index_matches(pile, option):
		idx = int(option["pileIndex"])
	else:
		for i in pile.size():
			var c: Dictionary = pile[i]
			if str(c.get("id", "")) == str(want.get("id", "")) and str(c.get("name", "")) == str(want.get("name", "")):
				idx = i
				break
	if idx < 0:
		return null
	var card: Dictionary = pile[idx]
	pile.remove_at(idx)
	# Always write the array back: a fresh local from get() is detached from the player.
	var hand: Array = player.get("hand", []) as Array
	hand.append(card)
	player["hand"] = hand
	return card

static func pile_index_matches(pile: Array, option: Dictionary) -> bool:
	var i := int(option.get("pileIndex", -1))
	if i < 0 or i >= pile.size():
		return false
	return str((pile[i] as Dictionary).get("id", "")) == str(((option.get("card", {}) as Dictionary)).get("id", ""))

## Pose un choix en attente (file si un choix est deja ouvert).
static func enqueue_pending(G: Dictionary, choice: Dictionary) -> void:
	if choice.is_empty():
		return
	if G.has("pendingChoice") and not (G["pendingChoice"] as Dictionary).is_empty():
		var q: Array = G.get("choiceQueue", [])
		G["choiceQueue"] = q
		q.append(choice)
	else:
		G["pendingChoice"] = choice

## Adversaires (non elimines) satisfaisant un predicat simple.
static func opponents_with(G: Dictionary, player_id: int, need_spell: bool = false) -> Array:
	var out: Array = []
	for pid in (G.get("players", {}) as Dictionary):
		if int(pid) == player_id:
			continue
		var p: Dictionary = G["players"][pid]
		if p.get("eliminated", false):
			continue
		if need_spell:
			var has := false
			for c in (p.get("hand", []) as Array):
				if bool((c as Dictionary).get("isSpell", false)):
					has = true
					break
			if not has:
				continue
		out.append({"playerId": int(pid), "player": p})
	return out

# --- activation d'abilite de salle (base set) ---

## Active l'abilite de la salle a room_index. Renvoie null si OK, sinon un message d'erreur.
static func activate_room_ability(G: Dictionary, player_id: int, room_index: int, other_room_index: int = -1):
	var p := _player(G, player_id)
	if p.is_empty():
		return "invalid player"
	var dungeon: Array = p.get("dungeon", [])
	if room_index < 0 or room_index >= dungeon.size():
		return "no room at index"
	var room = BossEngine.active_room(dungeon[room_index])
	if room == null:
		return "no active room"
	var r: Dictionary = room
	if bool(r.get("usedThisTurn", false)):
		return "already used this turn"

	var id := str(r.get("id", ""))
	match id:
		"BMA009": return _dark_altar(G, p, room_index, player_id)
		"BMA027": return _bottomless_pit(G, p, room_index, r)
		"BMA028": return _boulder_ramp(G, p, room_index, other_room_index, r)
		"BMA030": return _jackpot_stash(G, p, room_index)
		"BMA032": return _crushinator(G, p, room_index, other_room_index)
		"BMA038": return _torture_chamber(G, player_id)
		"BMA013": return _dracolich_lair(G, p, player_id)
		"BMA024": return _witchs_kitchen(G, p)
	return "no activated ability"

## BMA009 Dark Altar : detruit cette salle, recupere une carte de la defausse.
static func _dark_altar(G: Dictionary, p: Dictionary, room_index: int, player_id: int):
	var destroyed = BossEngine.destroy_room(p, room_index)
	BossEngine.discard_room_to_pile(G.get("decks", {}), destroyed)
	var opts := discard_card_options(G, "any")
	if opts.is_empty():
		_log(G, "Dark Altar: discard piles are empty.")
		return null
	if opts.size() == 1:
		var got = take_discard_card(G, p, opts[0])
		if got != null:
			_log(G, "Dark Altar: recovered %s." % str((got as Dictionary).get("name", "?")))
		return null
	G["pendingChoice"] = {"type": "recover-card", "resume": false, "playerId": player_id,
		"bossName": "Dark Altar", "message": "Dark Altar: choose a card from the discard pile",
		"options": opts}
	return null

## BMA027 Bottomless Pit : detruit cette salle, tue le hero qui s'y trouve.
static func _bottomless_pit(G: Dictionary, p: Dictionary, room_index: int, room: Dictionary):
	if not hero_is_in_room(G, int(p.get("id", 0)), room_index):
		return "no hero in this room"
	var adv: Dictionary = G.get("adventure", {}) as Dictionary
	_log(G, "Bottomless Pit: killed %s." % str((adv.get("hero", {}) as Dictionary).get("name", "?")))
	adv["hp"] = 0
	var destroyed = BossEngine.destroy_room(p, room_index)
	BossEngine.discard_room_to_pile(G.get("decks", {}), destroyed)
	return null

## BMA028 Boulder Ramp : detruit une autre salle, 5 degats au hero de celle-ci.
static func _boulder_ramp(G: Dictionary, p: Dictionary, room_index: int, other: int, room: Dictionary):
	if other < 0 or other == room_index:
		return "must target another room"
	var dungeon: Array = p.get("dungeon", [])
	if other < 0 or other >= dungeon.size():
		return "no room at other index"
	if BossEngine.active_room(dungeon[other]) == null:
		return "no room at other index"
	if not hero_is_in_room(G, int(p.get("id", 0)), room_index):
		return "no hero in this room"
	var adv: Dictionary = G.get("adventure", {}) as Dictionary
	adv["hp"] = int(adv.get("hp", 0)) - 5
	_log(G, "Boulder Ramp: dealt 5 damage to %s (HP %d)." % [str((adv.get("hero", {}) as Dictionary).get("name", "?")), int(adv.get("hp", 0))])
	var destroyed = BossEngine.destroy_room(p, other)
	if destroyed != null:
		BossEngine.discard_room_to_pile(G.get("decks", {}), destroyed)
		_log(G, "Boulder Ramp: destroyed %s." % str((destroyed as Dictionary).get("name", "?")))
	room["usedThisTurn"] = true
	return null

## BMA030 Jackpot Stash : detruit cette salle, double les tresors ce tour.
static func _jackpot_stash(G: Dictionary, p: Dictionary, room_index: int):
	var eff := _effects(G)
	var arr: Array = eff.get("treasureDoubled", [])
	eff["treasureDoubled"] = arr
	arr.append(int(p.get("id", 0)))
	_log(G, "Jackpot Stash: treasure values doubled until end of turn.")
	var destroyed = BossEngine.destroy_room(p, room_index)
	BossEngine.discard_room_to_pile(G.get("decks", {}), destroyed)
	return null

## BMA032 The Crushinator : detruit une autre salle, vos salles font +2 degats.
static func _crushinator(G: Dictionary, p: Dictionary, room_index: int, other: int):
	if other < 0 or other == room_index:
		return "must target another room"
	var dungeon: Array = p.get("dungeon", [])
	if other < 0 or other >= dungeon.size() or BossEngine.active_room(dungeon[other]) == null:
		return "no room at other index"
	var destroyed = BossEngine.destroy_room(p, other)
	BossEngine.discard_room_to_pile(G.get("decks", {}), destroyed)
	var eff := _effects(G)
	var arr: Array = eff.get("roomDamageBonus", [])
	eff["roomDamageBonus"] = arr
	for i in (p.get("dungeon", []) as Array).size():
		arr.append({"playerId": int(p.get("id", 0)), "roomIndex": i, "amount": 2})
	_log(G, "The Crushinator: your Rooms deal +2 damage this turn.")
	return null

## BMA038 Torture Chamber : detruit cette salle, un adversaire defausse une salle au hasard.
static func _torture_chamber(G: Dictionary, player_id: int):
	var p := _player(G, player_id)
	var opps := opponents_with(G, player_id, true)
	var room_index := -1
	var dungeon: Array = p.get("dungeon", [])
	for i in dungeon.size():
		if str(((BossEngine.active_room(dungeon[i]) as Dictionary) if BossEngine.active_room(dungeon[i]) != null else {}).get("id", "")) == "BMA038":
			room_index = i
			break
	if room_index < 0:
		return "no room at index"
	if opps.is_empty():
		_log(G, "Torture Chamber: no opponent has a Spell.")
		var d0 = BossEngine.destroy_room(p, room_index)
		BossEngine.discard_room_to_pile(G.get("decks", {}), d0)
		return null
	var d = BossEngine.destroy_room(p, room_index)
	BossEngine.discard_room_to_pile(G.get("decks", {}), d)
	return null

## BMA013 Dracolich Lair : defausse 2 salles, recupere une salle de la defausse.
static func _dracolich_lair(G: Dictionary, p: Dictionary, player_id: int):
	var hand: Array = p.get("hand", [])
	var discarded := 0
	while discarded < 2:
		var found := -1
		for i in hand.size():
			if bool((hand[i] as Dictionary).get("isRoom", false)):
				found = i
				break
		if found < 0:
			break
		var c: Dictionary = hand[found]
		hand.remove_at(found)
		BossEngine.discard_room_to_pile(G.get("decks", {}), c)
		discarded += 1
	var opts := discard_card_options(G, "room")
	if opts.is_empty():
		_log(G, "Dracolich Lair: no Room in the discard pile.")
		return null
	if opts.size() == 1:
		var got = take_discard_card(G, p, opts[0])
		if got != null:
			_log(G, "Dracolich Lair: recovered %s." % str((got as Dictionary).get("name", "?")))
		return null
	G["pendingChoice"] = {"type": "recover-card", "resume": false, "playerId": player_id,
		"bossName": "Dracolich Lair", "message": "Dracolich Lair: choose a Room from the discard pile",
		"options": opts}
	return null

## BMA024 Witch's Kitchen : defausse une salle Monster pour piocher un sort.
static func _witchs_kitchen(G: Dictionary, p: Dictionary):
	var hand: Array = p.get("hand", [])
	var found := -1
	for i in hand.size():
		var c: Dictionary = hand[i]
		if str(c.get("type", "")) == "monster":
			found = i
			break
	if found < 0:
		return "no Monster Room in hand"
	var card: Dictionary = hand[found]
	hand.remove_at(found)
	BossEngine.discard_room_to_pile(G.get("decks", {}), card)
	var decks: Dictionary = G.get("decks", {})
	var deck: Array = decks.get("spells", [])
	decks["spells"] = deck
	if deck.is_empty():
		_log(G, "Witch's Kitchen: no Spell to draw.")
		return null
	var drawn: Dictionary = deck.pop_back()
	hand.append(drawn)
	_log(G, "Witch's Kitchen: drew %s." % str(drawn.get("name", "?")))
	return null

# --- abilities passives (roomAbilities.js:onBuildRoom / onHeroDiedInRoom) ---

static func _draw_into(G: Dictionary, player: Dictionary, pile: String, n: int) -> Array:
	var decks: Dictionary = G.get("decks", {})
	var deck: Array = decks.get(pile, []) as Array
	decks[pile] = deck
	var out: Array = []
	for i in n:
		if deck.is_empty():
			break
		out.append(deck.pop_back())
	if not out.is_empty():
		var hand: Array = player.get("hand", []) as Array
		hand.append_array(out)
		player["hand"] = hand
	return out

## Declenche a la construction d'une salle. Renvoie un choix a resoudre, ou null.
static func on_build_room(G: Dictionary, player_id: int, room: Dictionary) -> Variant:
	var p := _player(G, player_id)
	if p.is_empty():
		return null
	var id := str(room.get("id", ""))
	match id:
		"BMA022": return _dark_laboratory(G, p, player_id)
		"BMA011": return _specters_sanctum(G, p, player_id)
		"BMA036": return _mimic_vault(G, p, player_id)
		"BMA037": return _monstrous_monument(G, p, player_id)
		"BMA034": return _construction_zone(G, p)
		"BMA033": return _centipede_tunnel(G, player_id)
	return null

## Declenche quand un hero meurt dans cette salle. Renvoie un choix, ou null.
static func on_hero_died_in_room(G: Dictionary, player_id: int, room: Dictionary) -> Variant:
	var p := _player(G, player_id)
	if p.is_empty():
		return null
	var id := str(room.get("id", ""))
	match id:
		"BMA010": return _open_grave(G, p, player_id)
		"BMA016": return _golem_factory(G, p, room)
		"BMA021": return _brainsucker_hive(G, p)
		"BMA014": return _vampire_bordello(G, p)
	return null

## BMA022 Dark Laboratory : pioche 2 sorts, le joueur en defausse 1.
static func _dark_laboratory(G: Dictionary, p: Dictionary, player_id: int) -> Variant:
	var drawn := _draw_into(G, p, "spells", 2)
	if drawn.size() >= 2:
		var opts: Array = []
		for c in drawn:
			opts.append({"card": c})
		return {"type": "discard-spell", "playerId": player_id, "bossId": "BMA022",
			"bossName": "Dark Laboratory",
			"message": "Dark Laboratory: choose a spell to discard", "options": opts}
	if drawn.size() == 1:
		var hand: Array = p.get("hand", []) as Array
		p["hand"] = hand
		var at := hand.find(drawn[0])
		if at >= 0:
			hand.remove_at(at)
		var decks: Dictionary = G.get("decks", {})
		var pile: Array = decks.get("spellDiscard", []) as Array
		decks["spellDiscard"] = pile
		pile.append(drawn[0])
		_log(G, "Dark Laboratory: drew 1 spell, auto-discarded %s." % str((drawn[0] as Dictionary).get("name", "?")))
	return null

## BMA011 Specter's Sanctum : un adversaire defausse un sort au hasard.
static func _specters_sanctum(G: Dictionary, _p: Dictionary, player_id: int) -> Variant:
	var opps := opponents_with(G, player_id, true)
	if opps.is_empty():
		_log(G, "Specter's Sanctum: no opponent has a Spell.")
		return null
	if opps.size() == 1:
		_discard_random_spell_from(G, int((opps[0] as Dictionary)["playerId"]), "Specter's Sanctum")
		return null
	var opts: Array = []
	for o in opps:
		opts.append({"targetPlayerId": int((o as Dictionary)["playerId"])})
	return {"type": "pick-opponent", "playerId": player_id, "bossName": "Specter's Sanctum",
		"message": "Choose an opponent to discard a random Spell", "options": opts}

## BMA036 Mimic Vault : un hero ordinaire de la ville vers ton entree.
static func _mimic_vault(G: Dictionary, p: Dictionary, player_id: int) -> Variant:
	var town: Array = G.get("town", []) as Array
	G["town"] = town
	var ordinary: Array = []
	for i in town.size():
		if not bool((town[i] as Dictionary).get("epic", false)):
			ordinary.append({"card": town[i], "townIndex": i})
	if ordinary.is_empty():
		return null
	if ordinary.size() == 1:
		var o: Dictionary = ordinary[0]
		var ti := int(o["townIndex"])
		var hero: Dictionary = town[ti]
		town.remove_at(ti)
		var entrance: Array = p.get("entrance", []) as Array
		entrance.append(hero)
		p["entrance"] = entrance
		_log(G, "Mimic Vault: %s moved to your entrance." % str(hero.get("name", "?")))
		return null
	return {"type": "pick-hero", "playerId": player_id, "bossName": "Mimic Vault",
		"message": "Mimic Vault: choose an ordinary Hero in town", "options": ordinary}

## BMA037 Monstrous Monument : recupere une salle Monster de la defausse.
static func _monstrous_monument(G: Dictionary, p: Dictionary, player_id: int) -> Variant:
	var opts := discard_card_options(G, "monster")
	if opts.is_empty():
		return null
	if opts.size() == 1:
		var got = take_discard_card(G, p, opts[0])
		if got != null:
			_log(G, "Monstrous Monument: recovered %s." % str((got as Dictionary).get("name", "?")))
		return null
	return {"type": "recover-card", "playerId": player_id, "bossName": "Monstrous Monument",
		"message": "Monstrous Monument: choose a Monster Room from the discard", "options": opts}

## BMA034 Construction Zone : rend une construction deja utilisee.
static func _construction_zone(G: Dictionary, p: Dictionary) -> Variant:
	p["buildsThisTurn"] = maxi(0, int(p.get("buildsThisTurn", 0)) - 1)
	_log(G, "Construction Zone: an additional room may be built this turn.")
	return null

## BMA033 Centipede Tunnel : echange 2 salles (facultatif).
static func _centipede_tunnel(G: Dictionary, player_id: int) -> Variant:
	var options: Array = []
	for pid in (G.get("players", {}) as Dictionary):
		var p: Dictionary = G["players"][pid]
		for i in (p.get("dungeon", []) as Array).size():
			if BossEngine.active_room((p["dungeon"] as Array)[i]) != null:
				options.append({"targetPlayerId": int(pid), "roomIndex": i})
	if options.size() < 2:
		_log(G, "Centipede Tunnel: not enough rooms to swap.")
		return null
	return {"type": "swap-rooms", "playerId": player_id, "bossName": "Centipede Tunnel",
		"message": "Centipede Tunnel: choose a Room to swap", "optional": true, "options": options}

## BMA010 Open Grave : recupere une salle de la defausse.
static func _open_grave(G: Dictionary, p: Dictionary, player_id: int) -> Variant:
	var opts := discard_card_options(G, "room")
	if opts.is_empty():
		return null
	if opts.size() == 1:
		var got = take_discard_card(G, p, opts[0])
		if got != null:
			_log(G, "Open Grave: recovered %s." % str((got as Dictionary).get("name", "?")))
		return null
	return {"type": "recover-card", "playerId": player_id, "bossName": "Open Grave",
		"message": "Open Grave: choose a Room from the discard pile", "options": opts}

## BMA016 Golem Factory : une fois par tour, pioche une salle.
static func _golem_factory(G: Dictionary, p: Dictionary, room: Dictionary) -> Variant:
	if bool(room.get("usedThisTurn", false)):
		return null
	room["usedThisTurn"] = true
	var drawn := _draw_into(G, p, "rooms", 1)
	if not drawn.is_empty():
		_log(G, "Golem Factory: drew %s." % str((drawn[0] as Dictionary).get("name", "?")))
	return null

## BMA021 Brainsucker Hive : pioche un sort.
static func _brainsucker_hive(G: Dictionary, p: Dictionary) -> Variant:
	var drawn := _draw_into(G, p, "spells", 1)
	if not drawn.is_empty():
		_log(G, "Brainsucker Hive: drew %s." % str((drawn[0] as Dictionary).get("name", "?")))
	return null

## BMA014 Vampire Bordello : soigne une blessure (retourne une ame face cachee).
static func _vampire_bordello(G: Dictionary, p: Dictionary) -> Variant:
	var soul = BossEngine.heal_one_wound(p)
	if soul != null:
		_log(G, "Vampire Bordello: healed a Wound (%d soul)." % int((soul as Dictionary).get("souls", 1)))
	return null

## Defausse un sort au hasard de la main d'un joueur.
static func _discard_random_spell_from(G: Dictionary, pid: int, label: String) -> void:
	var opp := _player(G, pid)
	var hand: Array = opp.get("hand", []) as Array
	var idxs: Array = []
	for i in hand.size():
		if bool((hand[i] as Dictionary).get("isSpell", false)):
			idxs.append(i)
	if idxs.is_empty():
		return
	var pick: int = idxs[randi() % idxs.size()]
	var card: Dictionary = hand[pick]
	hand.remove_at(pick)
	opp["hand"] = hand
	var decks: Dictionary = G.get("decks", {})
	var pile: Array = decks.get("spellDiscard", []) as Array
	decks["spellDiscard"] = pile
	pile.append(card)
	_log(G, "%s: player %d discarded %s." % [label, pid, str(card.get("name", "?"))])
## Construit le choix suivant de la file Robobo (adversaires restants).
static func robobo_choice(G: Dictionary, target_pid: int) -> Variant:
	if target_pid < 0 or not (G.get("players", {}) as Dictionary).has(target_pid):
		return {}
	var tp: Dictionary = G["players"][target_pid]
	var dungeon: Array = tp.get("dungeon", [])
	var options: Array = []
	for i in dungeon.size():
		if BossEngine.active_room(dungeon[i]) != null:
			options.append({"targetPlayerId": target_pid, "roomIndex": i})
	if options.is_empty():
		return {}
	return {"type": "destroy-room", "playerId": target_pid, "bossName": "Robobo",
		"message": "Robobo: choose a Room to destroy", "options": options}

static func heroes_without_item(G: Dictionary) -> Array:
	var opts: Array = []
	var town: Array = G.get("town", [])
	G["town"] = town
	for i in town.size():
		if not (town[i] as Dictionary).get("item", false):
			opts.append({"card": town[i], "source": "town", "index": i})
	for pid in (G.get("players", {}) as Dictionary):
		var p: Dictionary = G["players"][pid]
		if p.get("eliminated", false):
			continue
		var entrance: Array = p.get("entrance", [])
		for i in entrance.size():
			if not (entrance[i] as Dictionary).get("item", false):
				opts.append({"card": entrance[i], "source": "entrance", "playerId": int(pid), "index": i})
	var adv: Dictionary = G.get("adventure", {}) as Dictionary
	if not adv.is_empty() and not (adv.get("hero", {}) as Dictionary).get("item", false):
		opts.append({"card": adv.get("hero", {}), "source": "adventure"})
	return opts

## --- Level up des boss (roomAbilities.js:processLevelUp) ---
## Declenche a 5 salles visibles. Renvoie un choix a resoudre, ou null.

static func process_level_up(G: Dictionary, player_id: int, boss_override: Dictionary = {}) -> Variant:
	var p := _player(G, player_id)
	if p.is_empty() or p.get("boss", null) == null:
		return null
	var boss: Dictionary = boss_override if not boss_override.is_empty() else p.get("boss", {}) as Dictionary
	match str(boss.get("id", "")):
		"BMA001": return _draculord(G, player_id)
		"BMA002": return _xyzax(G, p)
		"BMA003": return _search_advanced_choice(G, player_id, "monster", "King Croak")
		"BMA004": return _robobo(G, player_id)
		"BMA005": return _cerebellus(G, p, player_id)
		"BMA006": return _seducia(G, player_id)
		"BMA007": return _search_advanced_choice(G, player_id, "trap", "Cleopatra")
		"BMA008": return _gorgona(G, p)
	return null

## BMA001 Draculord : vole une carte chez un adversaire (le joueur choisit).
static func _draculord(G: Dictionary, player_id: int) -> Variant:
	var opts: Array = []
	for opid in (G.get("players", {}) as Dictionary):
		if int(opid) == player_id:
			continue
		var op: Dictionary = G["players"][opid]
		if op.get("eliminated", false):
			continue
		var hand: Array = op.get("hand", [])
		op["hand"] = hand
		if hand.is_empty():
			continue
		for i in hand.size():
			opts.append({"card": hand[i], "fromPid": int(opid), "handIndex": i})
	if opts.is_empty():
		_log(G, "Draculord: no opponent cards to take.")
		return null
	return {"type": "steal-card", "playerId": player_id, "bossId": "BMA001", "bossName": "Draculord",
		"message": "Draculord: choose a card to steal from an opponent", "options": opts}

## BMA002 Xyzax : recupere 2 cartes de la defausse (automatique si <= 2).
static func _xyzax(G: Dictionary, p: Dictionary) -> Variant:
	var opts := discard_card_options(G, "any")
	if opts.is_empty():
		_log(G, "Xyzax: discard piles are empty.")
		return null
	if opts.size() <= 2:
		for o in opts:
			var got = take_discard_card(G, p, o)
			if got != null:
				_log(G, "Xyzax: recovered %s." % str((got as Dictionary).get("name", "?")))
		return null
	return {"type": "recover-card", "playerId": int(p.get("id", 0)), "bossName": "Xyzax",
		"message": "Xyzax: choose a card from the discard (2 remaining)", "remaining": 2, "options": opts}

## BMA003 King Croak / BMA007 Cleopatra : cherche une salle avancee (facultatif).
static func _search_advanced_choice(G: Dictionary, player_id: int, room_type: String, boss_name: String) -> Variant:
	var kind := "Monster" if room_type == "monster" else "Trap"
	var decks: Dictionary = G.get("decks", {})
	var options: Array = []
	for entry in [["rooms", "deck"], ["roomDiscard", "discard"]]:
		var pile: Array = decks.get(entry[0], [])
		decks[entry[0]] = pile
		for i in pile.size():
			var c: Dictionary = pile[i]
			if bool(c.get("advanced", false)) and str(c.get("type", "")) == room_type:
				options.append({"card": c, "pile": entry[1], "pileIndex": i})
	if options.is_empty():
		_log(G, "%s: no Advanced %s Room to search." % [boss_name, kind])
		return null
	return {"type": "search-advanced", "optional": true, "playerId": player_id, "bossName": boss_name,
		"roomType": room_type, "message": "%s: choose an Advanced %s Room (or skip)" % [boss_name, kind],
		"options": options}

## BMA004 Robobo : chaque adversaire detruit une salle de son choix.
static func _robobo(G: Dictionary, player_id: int) -> Variant:
	var victims: Array = []
	for opid in (G.get("players", {}) as Dictionary):
		if int(opid) == player_id:
			continue
		var op: Dictionary = G["players"][opid]
		if op.get("eliminated", false):
			continue
		var dungeon: Array = op.get("dungeon", [])
		if dungeon.is_empty():
			continue
		victims.append(int(opid))
	if victims.is_empty():
		_log(G, "Robobo: no opponent rooms to destroy.")
		return null
	# file des adversaires restants, dans l'ordre du JS
	G["roboboQueue"] = victims.slice(1)
	var first: int = victims[0]
	var dungeon: Array = (G["players"][first] as Dictionary).get("dungeon", [])
	var options: Array = []
	for i in dungeon.size():
		if BossEngine.active_room(dungeon[i]) != null:
			options.append({"targetPlayerId": first, "roomIndex": i})
	if options.is_empty():
		return null
	return {"type": "destroy-room", "playerId": first, "bossName": "Robobo",
		"message": "Robobo: choose a Room to destroy", "options": options}

## BMA005 Cerebellus : pioche 3 sorts, en defausse 1.
static func _cerebellus(G: Dictionary, p: Dictionary, player_id: int) -> Variant:
	var drawn := _draw_into(G, p, "spells", 3)
	if drawn.size() >= 2:
		var opts: Array = []
		for c in drawn:
			opts.append({"card": c})
		return {"type": "discard-spell", "playerId": player_id, "bossId": "BMA005", "bossName": "Cerebellus",
			"message": "Cerebellus: choose a spell to discard", "options": opts}
	if drawn.size() == 1:
		var card: Dictionary = drawn[0]
		var hand: Array = p.get("hand", [])
		p["hand"] = hand
		var at := hand.find(card)
		if at >= 0:
			hand.remove_at(at)
		var decks: Dictionary = G.get("decks", {})
		var pile: Array = decks.get("spellDiscard", [])
		decks["spellDiscard"] = pile
		pile.append(card)
		_log(G, "Cerebellus: drew 1 spell, auto-discarded %s." % str(card.get("name", "?")))
	return null

## BMA006 Seducia : cherche un heros en ville ou dans la pioche (facultatif).
static func _seducia(G: Dictionary, player_id: int) -> Variant:
	var options: Array = []
	var town: Array = G.get("town", [])
	G["town"] = town
	for i in town.size():
		options.append({"card": town[i], "source": "town", "townIndex": i})
	var decks: Dictionary = G.get("decks", {})
	for pile_name in ["heroes", "epics"]:
		var deck: Array = decks.get(pile_name, [])
		decks[pile_name] = deck
		for i in deck.size():
			options.append({"card": deck[i], "source": "deck", "pile": pile_name, "deckIndex": i})
	if options.is_empty():
		_log(G, "Seducia: no Hero in town or the Hero decks.")
		return null
	return {"type": "pick-hero", "optional": true, "playerId": player_id, "bossName": "Seducia",
		"message": "Seducia: choose a Hero (or skip)", "options": options}

## BMA008 Gorgona : detruit un heros en ville (le joueur choisit si > 1).
static func _gorgona(G: Dictionary, p: Dictionary) -> Variant:
	var town: Array = G.get("town", [])
	G["town"] = town
	if town.size() > 1:
		var options: Array = []
		for i in town.size():
			options.append({"card": town[i], "townIndex": i})
		return {"type": "kill-hero", "playerId": int(p.get("id", 0)), "bossName": "Gorgona",
			"message": "Gorgona: choose a Hero in town to destroy", "options": options}
	if town.size() == 1:
		var hero: Dictionary = town.pop_front()
		var souls: Array = p.get("souls", [])
		p["souls"] = souls
		for i in maxi(int(hero.get("souls", 1)), 1):
			souls.append({"souls": 1, "name": hero.get("name", "?"), "faceDown": true})
		_log(G, "Gorgona: killed %s." % str(hero.get("name", "?")))
	return null