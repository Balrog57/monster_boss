class_name SpellEffects
extends RefCounted
## Miroir de src/backend/game/spellEffects.js — effets des sorts du base set (BMA040-BMA055).
## Chaque fonction renvoie true si le sort a ete resolu, false sinon.
## Les effets persistants sont deposes dans G.effects (miroir de emptyEffects).

static func empty_effects() -> Dictionary:
	return {
		"roomDamageBonus": [], "heroHealthBonus": [], "heroDamage": [],
		"deactivatedRooms": [], "buildBlocked": false, "extraBuild": [],
		"noEntry": [], "teleportHero": null, "counteredSpells": [],
		"treasureDoubled": [], "roomExtraTreasures": [], "roomTreasureSuppressed": [],
		"staffHealingPids": [], "ordinaryMonsterBonus": [], "ignoreAbilityPids": [],
		"immediateBuild": [], "ignoreTreasureMatch": [], "noRoomBuild": [],
		"skipFirstRoomPids": [], "ignoreHeroAbilityPids": [], "skipAdventure": [],
	}

static func _effects(G: Dictionary) -> Dictionary:
	if not G.has("effects") or (G["effects"] as Dictionary).is_empty():
		G["effects"] = empty_effects()
	return G["effects"]

static func _player(G: Dictionary, pid: int) -> Dictionary:
	var players: Dictionary = G.get("players", {})
	return players.get(pid, players.get(str(pid), {})) as Dictionary

static func _log(G: Dictionary, t: String) -> void:
	var logs: Array = G.get("logs", [])
	G["logs"] = logs
	logs.append(t)

static func auto_room_index(G: Dictionary, player_id: int, target: Dictionary) -> int:
	if target.has("roomIndex"):
		return int(target["roomIndex"])
	var p := _player(G, player_id)
	return maxi(0, (p.get("dungeon", []) as Array).size() - 1)

static func find_room(G: Dictionary, player_id: int, room_index: int) -> Variant:
	var p := _player(G, player_id)
	var dungeon: Array = p.get("dungeon", [])
	if room_index < 0 or room_index >= dungeon.size():
		return null
	return BossEngine.active_room(dungeon[room_index])

static func _target_id(target: Dictionary, caster_id: int) -> int:
	return int(target["targetPlayerId"]) if target.has("targetPlayerId") else caster_id

static func _draw(decks: Dictionary, pile: String, n: int) -> Array:
	var deck: Array = decks.get(pile, [])
	decks[pile] = deck
	var out: Array = []
	for i in n:
		if deck.is_empty():
			break
		out.append(deck.pop_back())
	return out

## Point d'entree : resout le sort. Renvoie false si aucun effet pour cette carte.
static func cast_spell(G: Dictionary, caster_id: int, card: Dictionary, target: Dictionary) -> bool:
	var t: Dictionary = target if target != null else {}
	var id := str(card.get("id", ""))
	var fn: Callable = _handler(id)
	if not fn.is_valid():
		_log(G, "%s: no effect implemented yet." % str(card.get("name", id)))
		return false
	return bool(fn.call(G, caster_id, card, t))

## Dispatch : renvoie la fonction d'effet associee a un id de sort.
static func _handler(id: String) -> Callable:
	return {
		"BMA040": _annihilator, "BMA041": _assassin, "BMA042": _cave_in,
		"BMA044": _exhaustion, "BMA045": _fear, "BMA046": _freeze,
		"BMA047": _giant_size, "BMA048": _jeopardy, "BMA049": _kobold_strike,
		"BMA050": _motivation, "BMA051": _princess_in_peril, "BMA052": _soul_harvest,
		"BMA053": _teleportation, "BMA054": _trepidation, "BMA055": _zombie_attack,
		"KSA013": _tpk, "THK025": _excavation,
	}.get(id, Callable())

## DealDamageToRoom (spell) -> Room.Deal : le bonus se grave sur la CARTE (Room.DealDamage), pas sur le slot. Il n'est remis a zero qu'a
## EndOfTurnPhase pour les salles ENCORE dans un donjon (Boss.RestoreDungeon) : une salle detruite ou defaussee avant la fin du tour garde
## son +3 (oracle s34-p3 : le Bottomless Pit buffe au tour 2 frappe encore a 4 quand il est reconstruit au tour 5).
static func _buff_room_instance(room, amount: int) -> void:
	(room as Dictionary)["dealDamage"] = int((room as Dictionary).get("dealDamage", 0)) + amount

# --- BMA040 Annihilator : Trap Room +3 degats jusqu'a la fin du tour ---

static func _annihilator(G: Dictionary, caster_id: int, _card: Dictionary, target: Dictionary) -> bool:
	var tid := _target_id(target, caster_id)
	var idx := auto_room_index(G, tid, target)
	var room = find_room(G, tid, idx)
	if room == null or str((room as Dictionary).get("type", "")) != "trap":
		_log(G, "Annihilator requires a Trap Room.")
		return false
	_buff_room_instance(room, 3)
	_log(G, "Annihilator: %s gains +3 damage this turn." % (room as Dictionary).get("name", "?"))
	return true

# --- BMA041 Assassin : un hero adverse +3 PV ---

static func _assassin(G: Dictionary, caster_id: int, _card: Dictionary, target: Dictionary) -> bool:
	if not target.has("heroId"):
		_log(G, "Assassin: no target hero.")
		return false
	var hero_id: Variant = target["heroId"]
	(_effects(G)["heroHealthBonus"] as Array).append({"heroId": hero_id, "amount": 3})
	var adv: Dictionary = G.get("adventure", {}) as Dictionary
	if not adv.is_empty() and adv.get("hero", {}) is Dictionary \
			and str((adv["hero"] as Dictionary).get("id", "")) == str(hero_id):
		adv["hp"] = int(adv.get("hp", 0)) + 3
	_log(G, "Assassin: targeted hero gains +3 Health.")
	return true

# --- BMA047 Giant Size : Monster Room +3 degats ---

static func _giant_size(G: Dictionary, caster_id: int, _card: Dictionary, target: Dictionary) -> bool:
	var tid := _target_id(target, caster_id)
	var idx := auto_room_index(G, tid, target)
	var room = find_room(G, tid, idx)
	if room == null or str((room as Dictionary).get("type", "")) != "monster":
		_log(G, "Giant Size requires a Monster Room.")
		return false
	_buff_room_instance(room, 3)
	_log(G, "Giant Size: %s gains +3 damage this turn." % (room as Dictionary).get("name", "?"))
	return true

# --- BMA046 Freeze : desactive une salle jusqu'a la fin du tour ---

static func _freeze(G: Dictionary, caster_id: int, _card: Dictionary, target: Dictionary) -> bool:
	var tid := _target_id(target, caster_id)
	var idx := auto_room_index(G, tid, target)
	if find_room(G, tid, idx) == null:
		_log(G, "Freeze: no room to deactivate.")
		return false
	(_effects(G)["deactivatedRooms"] as Array).append({"playerId": tid, "roomIndex": idx})
	_log(G, "Freeze: room at index %d deactivated this turn." % idx)
	return true

# --- BMA050 Motivation : construction supplementaire si moins de salles qu'un adversaire ---

static func _motivation(G: Dictionary, caster_id: int, _card: Dictionary, _target: Dictionary) -> bool:
	var me := _player(G, caster_id)
	var mine := BossEngine.count_visible_rooms(me.get("dungeon", []))
	var has_more := false
	for opid in (G.get("players", {}) as Dictionary):
		if int(opid) == caster_id:
			continue
		var op: Dictionary = G["players"][opid]
		if op.get("eliminated", false):
			continue
		if BossEngine.count_visible_rooms(op.get("dungeon", [])) > mine:
			has_more = true
			break
	if not has_more:
		_log(G, "Motivation: you do not have fewer rooms than an opponent.")
		return false
	(_effects(G)["extraBuild"] as Array).append(caster_id)
	_log(G, "Motivation: you may build an extra room this turn.")
	return true

# --- BMA042 Cave-In : detruit une salle de son donjon ---

static func _cave_in(G: Dictionary, caster_id: int, _card: Dictionary, target: Dictionary) -> bool:
	var p := _player(G, caster_id)
	var dungeon: Array = p.get("dungeon", [])
	var idx := int(target["roomIndex"]) if target.has("roomIndex") else dungeon.size() - 1
	if idx < 0 or idx >= dungeon.size():
		_log(G, "Cave-In: no room to destroy.")
		return false
	# C# KillHeroInRoom puis DestroyRoom : le heros present dans cette salle meurt (meme mecanique que Bottomless Pit).
	var adv: Dictionary = G.get("adventure", {}) as Dictionary
	if not adv.is_empty() and int(adv.get("playerId", -1)) == caster_id and int(adv.get("roomIndex", -1)) == idx:
		adv["hp"] = 0
		_log(G, "Cave-In: %s is destroyed." % str((adv.get("hero", {}) as Dictionary).get("name", "?")))
	var destroyed = BossEngine.destroy_room(p, idx, G)
	if destroyed != null:
		BossEngine.discard_room_to_pile(G.get("decks", {}), destroyed)
		_log(G, "Cave-In: %s destroyed." % (destroyed as Dictionary).get("name", "?"))
	return true

# --- BMA044 Exhaustion : X degats a un hero de son donjon, X = salles visibles ---

static func _exhaustion(G: Dictionary, caster_id: int, _card: Dictionary, target: Dictionary) -> bool:
	# DealRoomsCountToHero : Boss.DungeonActiveRooms = slots actifs (hors Freeze) et non en attente de revelation.
	var x := 0
	var dun: Array = _player(G, caster_id).get("dungeon", [])
	for i in dun.size():
		if BossEngine.active_room(dun[i]) != null and not BossEngine.is_room_deactivated(G, caster_id, i):
			x += 1
	if not target.has("heroId"):
		_log(G, "Exhaustion: no target hero.")
		return false
	var hero_id: Variant = target["heroId"]
	var adv: Dictionary = G.get("adventure", {}) as Dictionary
	if not adv.is_empty() and adv.get("hero") is Dictionary \
			and str((adv["hero"] as Dictionary).get("id", "")) == str(hero_id):
		adv["hp"] = int(adv.get("hp", 0)) - x
		_log(G, "Exhaustion: deals %d damage to %s (HP %d)." % [x, (adv["hero"] as Dictionary).get("name", "?"), int(adv.get("hp", 0))])
		return true
	(_effects(G)["heroDamage"] as Array).append({"heroId": hero_id, "amount": x})
	_log(G, "Exhaustion: deals %d damage to a hero in your dungeon." % x)
	return true

# --- BMA045 Fear : renvoie un hero dans la ville ---

static func _fear(G: Dictionary, caster_id: int, _card: Dictionary, target: Dictionary) -> bool:
	if not target.has("heroId"):
		_log(G, "Fear: no target hero.")
		return false
	var hero_id: Variant = target["heroId"]
	var town: Array = G.get("town", [])
	G["town"] = town
	for opid in (G.get("players", {}) as Dictionary):
		var op: Dictionary = G["players"][opid]
		var entrance: Array = op.get("entrance", [])
		for i in entrance.size():
			if str((entrance[i] as Dictionary).get("id", "")) == str(hero_id):
				var h: Dictionary = entrance[i]
				town.append(h) # PlaceAtTown : HeroesInTownQueue.Add (en fin de file)
				entrance.remove_at(i)
				# PlaceAtTown -> RemoveHeroFromGame : un heros actif quitte l'aventure (NextGamePhase = AdventurePhase_b), sans ame ni blessure.
				var adv: Dictionary = G.get("adventure", {}) as Dictionary
				if not adv.is_empty() and str((adv.get("hero", {}) as Dictionary).get("id", "")) == str(hero_id):
					G["adventure"] = {}
					G["adventurePausePassed"] = {}
				_log(G, "Fear: %s returned to town." % str(h.get("name", "?")))
				return true
	_log(G, "Fear: target hero not found.")
	return false

# --- BMA051 Princess in Peril : un hero de la ville vers votre entree ---

static func _princess_in_peril(G: Dictionary, caster_id: int, _card: Dictionary, target: Dictionary) -> bool:
	var town: Array = G.get("town", [])
	G["town"] = town
	var idx := int(target["townIndex"]) if target.has("townIndex") else 0
	if idx < 0 or idx >= town.size():
		_log(G, "Princess in Peril: no hero in town.")
		return false
	var hero: Dictionary = town[idx]
	town.remove_at(idx)
	var me := _player(G, caster_id)
	var entrance: Array = me.get("entrance", []) as Array
	entrance.append(hero)
	me["entrance"] = entrance
	_log(G, "Princess in Peril: %s placed at your entrance." % str(hero.get("name", "?")))
	return true

# --- BMA052 Soul Harvest : retire une ame face cachee, pioche 2 sorts ---

static func _soul_harvest(G: Dictionary, caster_id: int, _card: Dictionary, target: Dictionary) -> bool:
	var me := _player(G, caster_id)
	var souls: Array = me.get("souls", []) as Array
	me["souls"] = souls
	var idx := int(target["soulIndex"]) if target.has("soulIndex") else souls.size() - 1
	if idx < 0 or idx >= souls.size():
		_log(G, "Soul Harvest: no soul to remove.")
		return false
	var s: Dictionary = souls[idx]
	if bool(s.get("tpk", false)) or s.get("faceDown", true) == false:
		_log(G, "Soul Harvest: no soul to remove.")
		return false
	souls.remove_at(idx)
	var decks: Dictionary = G.get("decks", {})
	var spells := _draw(decks, "spells", 2)
	var hand: Array = me.get("hand", [])
	me["hand"] = hand
	hand.append_array(spells)
	_log(G, "Soul Harvest: removed %s, drew %d spells." % [str(s.get("name", "a Hero")), spells.size()])
	return true

# --- BMA053 Teleportation : renvoie un hero au debut de son donjon ---

static func _teleportation(G: Dictionary, caster_id: int, _card: Dictionary, target: Dictionary) -> bool:
	if not target.has("heroId"):
		_log(G, "Teleportation: no target hero.")
		return false
	var eff := _effects(G)
	eff["teleportHero"] = target["heroId"]
	_log(G, "Teleportation: hero will restart at the first room.")
	return true

# --- BMA048 Jeopardy : tout le monde defausse et pioche 1 sort + 2 salles ---

static func _jeopardy(G: Dictionary, _caster_id: int, _card: Dictionary, _target: Dictionary) -> bool:
	var decks: Dictionary = G.get("decks", {})
	for opid in (G.get("players", {}) as Dictionary):
		var p: Dictionary = G["players"][opid]
		var hand: Array = p.get("hand", [])
		p["hand"] = hand
		var held := hand.duplicate()
		hand.clear()
		for c in held:
			if bool((c as Dictionary).get("isSpell", false)):
				(_decks_pile(decks, "spellDiscard") as Array).append(c)
			else:
				BossEngine.discard_room_to_pile(decks, c)
		hand.append_array(_draw(decks, "spells", 1))
		hand.append_array(_draw(decks, "rooms", 2))
	_log(G, "Jeopardy: all players discarded hands and drew 1 Spell + 2 Rooms.")
	return true

static func _decks_pile(decks: Dictionary, pile: String) -> Array:
	var a: Array = decks.get(pile, [])
	decks[pile] = a
	return a

# --- BMA049 Kobold Strike : plus de construction ce tour, defauste les salles face cachee ---

static func _kobold_strike(G: Dictionary, _caster_id: int, _card: Dictionary, _target: Dictionary) -> bool:
	_effects(G)["buildBlocked"] = true
	for opid in (G.get("players", {}) as Dictionary):
		var p: Dictionary = G["players"][opid]
		var dungeon: Array = p.get("dungeon", [])
		for i in range(dungeon.size() - 1, -1, -1):
			var stack: Array = dungeon[i]
			while stack.size() > 0:
				var top: Dictionary = stack[stack.size() - 1]
				if not bool(top.get("faceDown", false)) or not bool(top.get("builtThisTurn", false)):
					break
				# Boss.UndoBuildRoom : la salle posee ce tour rejoint la main de son proprietaire (RoomsInHand.Add).
				var back: Dictionary = stack.pop_back()
				back.erase("faceDown")
				back.erase("builtThisTurn")
				(p["hand"] as Array).append(back)
			if stack.is_empty():
				dungeon.remove_at(i)
	_log(G, "Kobold Strike: no rooms can be built this turn.")
	return true

# --- BMA054 Trepidation : SkipAdventurePhase -> Boss.ForceSkipAdventure, aucun heros n'entre dans ce donjon ce tour ---

static func _trepidation(G: Dictionary, caster_id: int, _card: Dictionary, target: Dictionary) -> bool:
	var tid := _target_id(target, caster_id)
	var victim := _player(G, tid)
	(_effects(G)["skipAdventure"] as Array).append(tid)
	_log(G, "Trepidation: no Hero enters player %d's dungeon this turn." % tid)
	if victim.is_empty():
		return false
	# Joue pendant la fenetre pre-aventure de la cible : ChooseNextActiveHero a deja designe son heros actif (AdventurePhase_b), que
	# ProccessActiveHero (ForceSkipAdventure) RETIRE DU JEU (RemoveHeroFromGame) ; les suivants restent a l'entree.
	if str(G.get("phase", "")) == CardDB.PHASE["ADVENTURE"] and (G.get("adventure", {}) as Dictionary).is_empty() \
			and int(G.get("stackActivePlayer", G.get("activePlayer", -1))) == tid and not (victim.get("entrance", []) as Array).is_empty():
		(victim["entrance"] as Array).pop_front()
	return true

# --- BMA055 Zombie Attack : un hero mort revient avec +2 PV ---

static func _zombie_attack(G: Dictionary, caster_id: int, _card: Dictionary, target: Dictionary) -> bool:
	var tid := int(target["targetPlayerId"]) if target.has("targetPlayerId") else -1
	var pile_name := str(target.get("pile", "souls"))
	var victim := _player(G, tid) if tid >= 0 else {}
	var soul_index := int(target["soulIndex"]) if target.has("soulIndex") else -1
	if victim.is_empty():
		for opid in (G.get("players", {}) as Dictionary):
			if int(opid) == caster_id:
				continue
			var op: Dictionary = G["players"][opid]
			if op.get("eliminated", false):
				continue
			var so: Array = op.get("souls", [])
			for i in so.size():
				if not bool((so[i] as Dictionary).get("tpk", false)):
					victim = op
					soul_index = i
					pile_name = "souls"
					break
			if not victim.is_empty():
				break
	if victim.is_empty() or soul_index < 0:
		_log(G, "Zombie Attack: no opponent has a dead Hero.")
		return false
	var pile: Array = victim.get(pile_name, [])
	if soul_index >= pile.size():
		_log(G, "Zombie Attack: no opponent has a dead Hero.")
		return false
	var revived: Dictionary = pile[soul_index]
	var entrance: Array = victim.get("entrance", []) as Array
	if pile_name == "souls" and revived.get("hero") is Dictionary:
		# SendBackToDungeonEntrance : le heros ENTIER revient (toutes ses ames quittent le scorekeeping), DealHero -2 = +2 PV.
		var hero: Dictionary = revived["hero"]
		var left := BossEngine.hero_souls(hero)
		for i in range(pile.size() - 1, -1, -1):
			if left > 0 and (pile[i] as Dictionary).get("hero") == hero:
				pile.remove_at(i)
				left -= 1
		var discard: Array = (G.get("decks", {}) as Dictionary).get("heroDiscard", []) as Array
		var at := discard.find(hero)
		if at >= 0:
			discard.remove_at(at)
		var back: Dictionary = hero.duplicate()
		back["hp"] = BossEngine.hero_hp(hero) + 2
		entrance.append(back)
		victim["entrance"] = entrance
		_log(G, "Zombie Attack: %s returns with +2 HP." % str(hero.get("name", "a dead Hero")))
		return true
	pile.remove_at(soul_index)
	entrance.append({"name": revived.get("name", "Zombie"), "hp": int(revived.get("hp", 4)) + 2,
		"souls": 1, "wounds": 1})
	victim["entrance"] = entrance
	_log(G, "Zombie Attack: %s returns with +2 HP." % str(revived.get("name", "a dead Hero")))
	return true

# --- KSA013 T.P.K. : sort IUntilEndOfGameCommand (GameBoard.OnAbilityApplyDone : RemoveRoomOrSpellFromGame puis Boss.UntilEndOfTurnSpells) ---
# Il quitte la defausse pour rester chez le lanceur ; AddSoulsToBossIfTreasures lit le scorekeeping de sa cible (CardDB.passive_souls).

static func _tpk(G: Dictionary, caster_id: int, card: Dictionary, target: Dictionary) -> bool:
	var pile: Array = (G.get("decks", {}) as Dictionary).get("spellDiscard", [])
	var at := pile.rfind(card)
	if at >= 0:
		pile.remove_at(at)
	var me := _player(G, caster_id)
	var list: Array = me.get("untilEndSpells", []) as Array
	me["untilEndSpells"] = list
	list.append({"card": card, "target": _target_id(target, caster_id)})
	_log(G, "T.P.K. : %s garde la carte dans son scorekeeping." % str(me.get("boss", {}).get("name", "?")))
	return true

# --- THK025 Excavation : retourne un objet ---

static func _excavation(G: Dictionary, caster_id: int, _card: Dictionary, target: Dictionary) -> bool:
	var pid := _target_id(target, caster_id)
	var owner := _player(G, pid)
	var items: Array = owner.get("items", []) as Array
	owner["items"] = items
	var idx := int(target["itemIndex"]) if target.has("itemIndex") else 0
	if idx < 0 or idx >= items.size():
		_log(G, "Excavation: no item to flip.")
		return true
	var it: Dictionary = items[idx]
	it["faceDown"] = not bool(it.get("faceDown", false))
	var face := "face-down" if bool(it["faceDown"]) else "face-up"
	_log(G, "Excavation: flipped %s %s." % [str(it.get("name", "?")), face])
	return true
