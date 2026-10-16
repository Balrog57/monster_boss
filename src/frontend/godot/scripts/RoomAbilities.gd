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

## Boss.IsCanChooseCardToDraw : une salle ACTIVE (DungeonActiveRooms : face visible, non gelee) porte ChooseCardToDraw (BMA023 Haunted Library).
static func can_choose_draw(p: Dictionary) -> bool:
	for stack in (p.get("dungeon", []) as Array):
		var r = BossEngine.active_room(stack)
		if r != null and str((r as Dictionary).get("id", "")) == "BMA023" and not bool((r as Dictionary).get("faceDown", false)):
			return true
	return false

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

## Salles a condition OncePerTurn (Ability.IsEffectApplied) parmi les capacites activables.
const ONCE_PER_TURN := ["BMA013", "BMA024", "BMA025"]

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
	if BossEngine.abilities_locked(G, player_id):
		return "abilities locked (Trap Master)" # KSA017 : Ability.IsLocked -> CheckConditions faux

	if ONCE_PER_TURN.has(str(r.get("id", ""))):
		r["usedThisTurn"] = true # data.json : seules BMA013/024/025 portent OncePerTurn (Crushinator et Boulder Ramp sont rejouables)
	var id := str(r.get("id", ""))
	match id:
		"BMA009": return _dark_altar(G, p, room_index, player_id, r)
		"BMA025": return _all_seeing_eye(G, p, player_id)
		"BMA027": return _bottomless_pit(G, p, player_id, room_index, r)
		"BMA028": return _boulder_ramp(G, p, player_id, room_index, other_room_index, r)
		"BMA030": return _jackpot_stash(G, p, player_id, room_index)
		"BMA032": return _crushinator(G, p, player_id, room_index, other_room_index)
		"BMA038": return _torture_chamber(G, player_id)
		"BMA013": return _dracolich_lair(G, p, player_id, r)
		"BMA024": return _witchs_kitchen(G, p, player_id)
		"BMA039": return _zombie_prison(G, p, room_index, player_id, r)
	r["usedThisTurn"] = false
	return "no activated ability"

## BMA009 Dark Altar : detruit cette salle, recupere une carte de la defausse.
## C# (data.json BMA009 + AbilityTransaction.PrepareResolveTargetActionsQueue) : toutes les
## cibles sont resolues AVANT l'execution des effets. Le choix dans la defausse se fait donc
## sans l'Altar (detruit ensuite) et une defausse vide rend l'abilite inutilisable
## (Ability.CheckConditions : CardInDeck exige >= 1 cible). Une seule carte = auto-resolue.
static func _dark_altar(G: Dictionary, p: Dictionary, room_index: int, player_id: int, room: Dictionary):
	var opts := discard_card_options(G, "any")
	if opts.is_empty():
		room["usedThisTurn"] = false
		return "discard piles are empty"
	var destroyed = BossEngine.destroy_room(p, room_index, G)
	BossEngine.discard_room_to_pile(G.get("decks", {}), destroyed)
	if opts.size() == 1:
		var got = take_discard_card(G, p, opts[0])
		if got != null:
			_log(G, "Dark Altar: recovered %s." % str((got as Dictionary).get("name", "?")))
		return null
	G["pendingChoice"] = {"type": "recover-card", "resume": false, "playerId": player_id,
		"bossName": "Dark Altar", "message": "Dark Altar: choose a card from the discard pile",
		"options": opts}
	return null

## BMA025 All-Seeing Eye : defausse un sort de la main pour annuler le dernier sort adverse
## de la pile (C# : SpellInHand(Owner) + LastSpellPlayed = dernier sort dont le proprietaire
## n'est pas celui de la salle). Un seul sort en main = defausse automatique.
static func _all_seeing_eye(G: Dictionary, p: Dictionary, player_id: int):
	if _last_opponent_spell_index(G, player_id) < 0:
		return "no opponent Spell to cancel"
	var opts := _hand_spell_options(p)
	if opts.is_empty():
		return "no Spell to discard"
	if opts.size() == 1:
		_discard_hand_card(G, p, (opts[0] as Dictionary)["card"])
		cancel_last_opponent_spell(G, player_id, "All-Seeing Eye")
		return null
	G["pendingChoice"] = {"type": "discard-spell", "resume": false, "thenCancel": true, "playerId": player_id,
		"bossName": "All-Seeing Eye", "message": "All-Seeing Eye: choose a Spell to discard",
		"options": opts}
	return null

## Peut-on activer l'All-Seeing Eye ? (sort adverse sur la pile + un sort en main)
static func can_cancel_spell(G: Dictionary, player_id: int) -> bool:
	return _last_opponent_spell_index(G, player_id) >= 0 and not _hand_spell_options(_player(G, player_id)).is_empty()

## Index (dans G.stack) du dernier sort joue par un autre joueur, -1 si aucun.
static func _last_opponent_spell_index(G: Dictionary, player_id: int) -> int:
	var stack: Array = G.get("stack", [])
	for i in range(stack.size() - 1, -1, -1):
		var e: Dictionary = stack[i]
		if str(e.get("type", "")) == "spell" and int(e.get("playerId", -1)) != player_id:
			return i
	return -1

## Annule le dernier sort adverse de la pile (le sort part en defausse sans effet).
static func cancel_last_opponent_spell(G: Dictionary, player_id: int, label: String) -> void:
	var i := _last_opponent_spell_index(G, player_id)
	if i < 0:
		return
	var stack: Array = G["stack"]
	var e: Dictionary = stack[i]
	stack.remove_at(i)
	var card: Dictionary = e.get("card", {})
	var decks: Dictionary = G.get("decks", {})
	var pile: Array = decks.get("spellDiscard", [])
	decks["spellDiscard"] = pile
	pile.append(card)
	_log(G, "%s: %s annule." % [label, str(card.get("name", "?"))])
	# Meme reprise que le Counterspell.
	stack_return_control(G)

## Rend la main apres un Counterspell / une annulation / la resolution de la pile.
## Pile vide = Spell Battle terminee (GameBoard.NextStep : IsSpellBattleActive=false, le flux de phase
## reprend sans changer de joueur) : la main revient au joueur de phase (stackActivePlayer), pas au lanceur,
## sinon un sort lance hors de son tour laisse activePlayer sur le lanceur et la partie cale.
## Pile non vide : le lanceur du dernier sort reprend la main pour la suite des reponses.
static func stack_return_control(G: Dictionary) -> void:
	if (G.get("stack", []) as Array).is_empty():
		if G.get("stackActivePlayer", null) != null:
			G["activePlayer"] = int(G["stackActivePlayer"])
		elif G.get("stackReturnPlayer", null) != null:
			G["activePlayer"] = int(G["stackReturnPlayer"])
		G.erase("stackActivePlayer")
		G["stackReturnPlayer"] = null
		G["stackPassed"] = {}
	elif G.get("stackReturnPlayer", null) != null:
		G["activePlayer"] = int(G["stackReturnPlayer"])

static func _hand_spell_options(p: Dictionary) -> Array:
	var opts: Array = []
	for c in (p.get("hand", []) as Array):
		if bool((c as Dictionary).get("isSpell", false)):
			opts.append({"card": c})
	return opts

## Defausse une carte precise de la main vers la pile de sorts/salles.
static func _discard_hand_card(G: Dictionary, p: Dictionary, card: Dictionary) -> void:
	var hand: Array = p.get("hand", []) as Array
	p["hand"] = hand
	var at := hand.find(card)
	if at >= 0:
		hand.remove_at(at)
	var decks: Dictionary = G.get("decks", {})
	var pile_name := "spellDiscard" if bool(card.get("isSpell", false)) else "roomDiscard"
	var pile: Array = decks.get(pile_name, []) as Array
	decks[pile_name] = pile
	pile.append(card)

## Choix "defausse un sort de ta main" (DiscardSomeCardFromHand(1, Spell)) : le C# propose TOUS les
## sorts en main (SpellInHand Owner), pas seulement ceux qui viennent d'etre pioches.
## Un seul sort en main = defausse automatique (TryToAutoresolve), aucun = rien.
static func _spell_discard_choice(G: Dictionary, p: Dictionary, player_id: int, boss_id: String, label: String) -> Variant:
	var opts := _hand_spell_options(p)
	if opts.size() >= 2:
		return {"type": "discard-spell", "playerId": player_id, "bossId": boss_id, "bossName": label,
			"message": "%s: choose a spell to discard" % label, "options": opts}
	if opts.size() == 1:
		var card: Dictionary = (opts[0] as Dictionary)["card"]
		_discard_hand_card(G, p, card)
		_log(G, "%s: auto-discarded %s." % [label, str(card.get("name", "?"))])
	return null

## BMA027 Bottomless Pit : detruit cette salle, tue le hero qui s'y trouve.
static func _bottomless_pit(G: Dictionary, p: Dictionary, player_id: int, room_index: int, room: Dictionary):
	if not hero_is_in_room(G, player_id, room_index):
		return "no hero in this room"
	var adv: Dictionary = G.get("adventure", {}) as Dictionary
	_log(G, "Bottomless Pit: killed %s." % str((adv.get("hero", {}) as Dictionary).get("name", "?")))
	adv["hp"] = 0
	var destroyed = BossEngine.destroy_room(p, room_index, G)
	BossEngine.discard_room_to_pile(G.get("decks", {}), destroyed)
	return null

## BMA028 Boulder Ramp : detruit une autre salle, 5 degats au hero de celle-ci.
static func _boulder_ramp(G: Dictionary, p: Dictionary, player_id: int, room_index: int, other: int, room: Dictionary):
	if other < 0 or other == room_index:
		return "must target another room"
	var dungeon: Array = p.get("dungeon", [])
	if other < 0 or other >= dungeon.size():
		return "no room at other index"
	if BossEngine.active_room(dungeon[other]) == null:
		return "no room at other index"
	if not hero_is_in_room(G, player_id, room_index):
		return "no hero in this room"
	var adv: Dictionary = G.get("adventure", {}) as Dictionary
	adv["hp"] = int(adv.get("hp", 0)) - 5
	_log(G, "Boulder Ramp: dealt 5 damage to %s (HP %d)." % [str((adv.get("hero", {}) as Dictionary).get("name", "?")), int(adv.get("hp", 0))])
	var destroyed = BossEngine.destroy_room(p, other, G)
	if destroyed != null:
		BossEngine.discard_room_to_pile(G.get("decks", {}), destroyed)
		_log(G, "Boulder Ramp: destroyed %s." % str((destroyed as Dictionary).get("name", "?")))
	return null

## BMA030 Jackpot Stash : detruit cette salle, double les tresors ce tour.
static func _jackpot_stash(G: Dictionary, p: Dictionary, player_id: int, room_index: int):
	var eff := _effects(G)
	var arr: Array = eff.get("treasureDoubled", [])
	eff["treasureDoubled"] = arr
	arr.append(player_id)
	_log(G, "Jackpot Stash: treasure values doubled until end of turn.")
	var destroyed = BossEngine.destroy_room(p, room_index, G)
	BossEngine.discard_room_to_pile(G.get("decks", {}), destroyed)
	return null

## BMA032 The Crushinator : detruit une autre salle, vos salles font +2 degats.
static func _crushinator(G: Dictionary, p: Dictionary, player_id: int, room_index: int, other: int):
	if other < 0 or other == room_index:
		return "must target another room"
	var dungeon: Array = p.get("dungeon", [])
	if other < 0 or other >= dungeon.size() or BossEngine.active_room(dungeon[other]) == null:
		return "no room at other index"
	var destroyed = BossEngine.destroy_room(p, other, G)
	BossEngine.discard_room_to_pile(G.get("decks", {}), destroyed)
	var eff := _effects(G)
	var arr: Array = eff.get("roomDamageBonus", [])
	eff["roomDamageBonus"] = arr
	for i in (p.get("dungeon", []) as Array).size():
		arr.append({"playerId": player_id, "roomIndex": i, "amount": 2})
	_log(G, "The Crushinator: your Rooms deal +2 damage this turn.")
	return null

## BMA038 Torture Chamber : detruit cette salle, puis DiscardRandomCardFromHand(1, Room) sur un adversaire
## (BossOpponent : tout adversaire, meme sans salle en main ; un seul adversaire = cible automatique).
static func _torture_chamber(G: Dictionary, player_id: int):
	var p := _player(G, player_id)
	var room_index := -1
	var dungeon: Array = p.get("dungeon", [])
	for i in dungeon.size():
		if str(((BossEngine.active_room(dungeon[i]) as Dictionary) if BossEngine.active_room(dungeon[i]) != null else {}).get("id", "")) == "BMA038":
			room_index = i
			break
	if room_index < 0:
		return "no room at index"
	var d = BossEngine.destroy_room(p, room_index, G)
	BossEngine.discard_room_to_pile(G.get("decks", {}), d)
	var opps := opponents_with(G, player_id)
	if opps.size() == 1:
		_discard_random_from(G, int((opps[0] as Dictionary)["playerId"]), false, "Torture Chamber")
	elif opps.size() > 1:
		var opts: Array = []
		for o in opps:
			opts.append({"targetPlayerId": int((o as Dictionary)["playerId"])})
		G["pendingChoice"] = {"type": "pick-opponent", "action": "discard-room", "resume": false, "playerId": player_id,
			"bossName": "Torture Chamber", "message": "Torture Chamber: choose an opponent to discard a random Room", "options": opts}
	return null

## BMA013 Dracolich Lair : defausse 2 salles de la main (choix du joueur) puis recupere une salle de la defausse.
## C# (data.json BMA013) : RoomInHand(AllRequired=True, 2) puis RoomInDeck(1, DiscardPile). Ability.CheckConditions
## exige donc 2 salles en main ET 1 salle en defausse ; toutes les cibles sont resolues AVANT
## l'execution : le choix dans la defausse ne voit pas les 2 salles qu'on vient de defausser.
static func _dracolich_lair(G: Dictionary, p: Dictionary, player_id: int, room: Dictionary):
	var hand: Array = p.get("hand", [])
	var idxs: Array = []
	for i in hand.size():
		if bool((hand[i] as Dictionary).get("isRoom", false)):
			idxs.append(i)
	var pile_opts := discard_card_options(G, "room")
	if idxs.size() < 2 or pile_opts.is_empty():
		room["usedThisTurn"] = false
		return "Dracolich Lair needs two Rooms in hand and a Room in the discard pile"
	var opts: Array = []
	for a in idxs.size():
		for b in range(a + 1, idxs.size()):
			var ca: Dictionary = hand[idxs[a]]
			var cb: Dictionary = hand[idxs[b]]
			# card/handIndex designent les 2 cartes (cf. ApkParityTrace._refs) ; handIndices sert a la resolution.
			opts.append({"card": ca, "handIndex": idxs[b], "handIndices": [idxs[a], idxs[b]],
				"label": "%s + %s" % [str(ca.get("name", "?")), str(cb.get("name", "?"))]})
	G["pendingChoice"] = {"type": "dracolich-discard", "resume": false, "playerId": player_id,
		"bossName": "Dracolich Lair", "message": "Dracolich Lair: choose two Rooms to discard",
		"pileOptions": pile_opts, "options": opts}
	return null

## Suite de Dracolich Lair : defausse la paire choisie, puis ouvre (ou resout) le choix dans la defausse.
static func dracolich_discard(G: Dictionary, player_id: int, option: Dictionary, pile_opts: Array) -> void:
	var p := _player(G, player_id)
	var hand: Array = p.get("hand", []) as Array
	var idxs: Array = (option.get("handIndices", []) as Array).duplicate()
	idxs.sort()
	idxs.reverse()
	for i in idxs:
		if int(i) >= 0 and int(i) < hand.size():
			BossEngine.discard_room_to_pile(G.get("decks", {}), hand.pop_at(int(i)))
	p["hand"] = hand
	if pile_opts.size() == 1:
		var got = take_discard_card(G, p, pile_opts[0])
		if got != null:
			_log(G, "Dracolich Lair: recovered %s." % str((got as Dictionary).get("name", "?")))
	elif not pile_opts.is_empty():
		enqueue_pending(G, {"type": "recover-card", "resume": false, "playerId": player_id,
			"bossName": "Dracolich Lair", "message": "Dracolich Lair: choose a Room from the discard pile",
			"options": pile_opts})

## BMA039 Zombie Prison : detruit cette salle, renvoie un heros mort du scorekeeping d'un adversaire
## a l'entree du donjon de cet adversaire (C# : ThisRoom + HeroInScorekeep[Opponent, Dead] ->
## DestroyRoom + SendBackToDungeonEntrance : ames retirees, heros remis dans l'EntranceQueue du detenteur).
## Aucun heros mort chez un adversaire = abilite inutilisable (Ability.CheckConditions).
static func _zombie_prison(G: Dictionary, p: Dictionary, room_index: int, player_id: int, room: Dictionary):
	var opts: Array = []
	for pid in (G.get("players", {}) as Dictionary):
		if int(pid) == player_id or bool((G["players"][pid] as Dictionary).get("eliminated", false)):
			continue
		var seen: Array = []
		for e in ((G["players"][pid] as Dictionary).get("souls", []) as Array):
			var h = (e as Dictionary).get("hero")
			if h is Dictionary and not seen.has(h):
				seen.append(h)
				opts.append({"targetPlayerId": int(pid), "card": h})
	if opts.is_empty():
		room["usedThisTurn"] = false
		return "no dead Hero in an opponent's scorekeeping area"
	BossEngine.discard_room_to_pile(G.get("decks", {}), BossEngine.destroy_room(p, room_index, G))
	if opts.size() == 1:
		zombie_prison_send_back(G, opts[0])
		return null
	G["pendingChoice"] = {"type": "revive-hero", "resume": false, "playerId": player_id,
		"bossName": "Zombie Prison", "message": "Zombie Prison: choose a dead Hero to send back to its dungeon",
		"options": opts}
	return null

static func zombie_prison_send_back(G: Dictionary, option: Dictionary) -> void:
	var tp := _player(G, int(option.get("targetPlayerId", -1)))
	var hero: Dictionary = option.get("card", {}) as Dictionary
	if tp.is_empty() or hero.is_empty():
		return
	var souls: Array = tp.get("souls", []) as Array
	var left := BossEngine.hero_souls(hero)
	for i in range(souls.size() - 1, -1, -1):
		if left > 0 and (souls[i] as Dictionary).get("hero") == hero:
			souls.remove_at(i)
			left -= 1
	tp["souls"] = souls
	var discard: Array = G.get("decks", {}).get("heroDiscard", []) as Array
	var at := discard.find(hero)
	if at >= 0:
		discard.remove_at(at)
	var entrance: Array = tp.get("entrance", []) as Array
	entrance.append(hero)
	tp["entrance"] = entrance
	_log(G, "Zombie Prison: %s est renvoye a l'entree du donjon du joueur %d." % [str(hero.get("name", "?")), int(option.get("targetPlayerId", -1))])

## BMA024 Witch's Kitchen : defausse une salle Monster pour piocher un sort.
static func _witchs_kitchen(G: Dictionary, p: Dictionary, player_id: int):
	var hand: Array = p.get("hand", [])
	var opts: Array = []
	for i in hand.size():
		var c: Dictionary = hand[i]
		if str(c.get("type", "")) == "monster" and bool(c.get("isRoom", false)):
			opts.append({"card": c, "handIndex": i})
	if opts.is_empty():
		return "no Monster Room in hand"
	# RoomInHand(Monster, Owner) : la salle a defausser se choisit (auto si une seule).
	if opts.size() == 1:
		kitchen_discard(G, player_id, opts[0])
		return null
	G["pendingChoice"] = {"type": "kitchen-discard", "resume": false, "playerId": player_id,
		"bossName": "Witch's Kitchen", "message": "Witch's Kitchen: choose a Monster Room to discard", "options": opts}
	return null

## Suite de Witch's Kitchen : defausse la salle choisie puis pioche un sort.
static func kitchen_discard(G: Dictionary, player_id: int, option: Dictionary) -> void:
	var p := _player(G, player_id)
	var hand: Array = p.get("hand", []) as Array
	var at := hand.find(option.get("card", {}))
	if at < 0:
		return
	BossEngine.discard_room_to_pile(G.get("decks", {}), hand.pop_at(at))
	var drawn := _draw_into(G, p, "spells", 1)
	if not drawn.is_empty():
		_log(G, "Witch's Kitchen: drew %s." % str((drawn[0] as Dictionary).get("name", "?")))

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
		"BMA034": return _construction_zone(G, player_id)
		"BMA033": return _centipede_tunnel(G, player_id)
	return null

## GameBoard.RevealAllRoomCards -> CheckTriggerInDungeon<WhenYouBuildAnotherRoom>(player, topRoom) :
## chaque AUTRE salle active (face visible) du donjon reagit. BMA019 Beast Menagerie : OncePerTurn +
## HasPendingRoomToBuild(Monster) (un slot encore en attente, y compris celui revele, a une salle Monster
## au sommet) -> pioche 1 salle. A appeler AVANT que `room` ne passe face visible.
static func on_build_another_room(G: Dictionary, player_id: int, room: Dictionary) -> void:
	for o in another_room_triggers(G, player_id):
		run_another_room_trigger(G, player_id, o)

## Conditions des declencheurs WhenYouBuildAnotherRoom, evaluees AU MOMENT DE LA FILE (CheckTriggerInRoom) : renvoie les
## salles dont la transaction part en file (l'effet, lui, s'execute plus tard : run_another_room_trigger).
static func another_room_triggers(G: Dictionary, player_id: int) -> Array:
	var out: Array = []
	var p := _player(G, player_id)
	if p.is_empty():
		return out
	var pending_monster := false
	for stack in (p.get("dungeon", []) as Array):
		var top = BossEngine.active_room(stack)
		if top != null and bool((top as Dictionary).get("faceDown", false)) and str((top as Dictionary).get("type", "")) == "monster":
			pending_monster = true
			break
	if not pending_monster:
		return out
	for stack in (p.get("dungeon", []) as Array):
		var other = BossEngine.active_room(stack)
		if other == null or bool((other as Dictionary).get("faceDown", false)):
			continue
		var o: Dictionary = other
		if str(o.get("id", "")) != "BMA019" or bool(o.get("usedThisTurn", false)):
			continue
		o["usedThisTurn"] = true
		out.append(o)
	return out

static func run_another_room_trigger(G: Dictionary, player_id: int, _room: Dictionary) -> void:
	var drawn := _draw_into(G, _player(G, player_id), "rooms", 1)
	if not drawn.is_empty():
		_log(G, "Beast Menagerie: drew %s." % str((drawn[0] as Dictionary).get("name", "?")))

## Declenche quand un hero meurt dans cette salle. Renvoie un choix, ou null.
static func on_hero_died_in_room(G: Dictionary, player_id: int, room: Dictionary) -> Variant:
	var p := _player(G, player_id)
	if p.is_empty():
		return null
	var id := str(room.get("id", ""))
	# Tous les declencheurs HeroDiesInThisRoom du base set portent OncePerTurn (Ability.IsEffectApplied), verifie a la mise en file.
	if ["BMA010", "BMA012", "BMA014", "BMA016", "BMA021"].has(id):
		if bool(room.get("usedThisTurn", false)):
			return null
		room["usedThisTurn"] = true
	match id:
		"BMA010": return _open_grave(G, p, player_id)
		"BMA012": return _succubus_spa(G, player_id)
		"BMA016": return _golem_factory(G, p, room)
		"BMA021": return _brainsucker_hive(G, p)
		"BMA014": return _vampire_bordello(G, p, player_id)
	return null

## BMA022 Dark Laboratory : pioche 2 sorts, puis defausse 1 sort de la main (tous les sorts, cf. C#).
static func _dark_laboratory(G: Dictionary, p: Dictionary, player_id: int) -> Variant:
	_draw_into(G, p, "spells", 2)
	return _spell_discard_choice(G, p, player_id, "BMA022", "Dark Laboratory")

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
	return {"type": "pick-opponent", "action": "discard-spell", "playerId": player_id, "bossName": "Specter's Sanctum",
		"message": "Choose an opponent to discard a random Spell", "options": opts}

## BMA012 Succubus Spa : BossOwner + BossOpponent + PickRandomCardFromHand(1, Any). L'adversaire designe (auto s'il n'y en a qu'un,
## TryToAutoresolve ; tout adversaire est ciblable meme sans carte) perd une carte AU HASARD (salle ou sort) qui rejoint la main du proprietaire.
static func _succubus_spa(G: Dictionary, player_id: int) -> Variant:
	var opps := opponents_with(G, player_id)
	if opps.is_empty():
		return null
	if opps.size() == 1:
		steal_random_card(G, player_id, int((opps[0] as Dictionary)["playerId"]), "Succubus Spa")
		return null
	var opts: Array = []
	for o in opps:
		opts.append({"targetPlayerId": int((o as Dictionary)["playerId"])})
	return {"type": "pick-opponent", "action": "steal-random", "playerId": player_id, "bossName": "Succubus Spa",
		"message": "Succubus Spa: choose an opponent to take a random card from", "options": opts}

## PickRandomCardFromHand.Execute : une carte au hasard parmi toutes les cartes (salles et sorts) de la main de la victime.
static func steal_random_card(G: Dictionary, thief_pid: int, victim_pid: int, label: String) -> void:
	var victim := _player(G, victim_pid)
	var thief := _player(G, thief_pid)
	var hand: Array = victim.get("hand", []) as Array
	if hand.is_empty() or thief.is_empty():
		return
	var pick: int = randi() % hand.size()
	# Crochet de rejeu (harnais de parite APK) : G["forcedRandom"] = _oid des cartes tirees par l'oracle, dans l'ordre. Absent => hasard.
	var forced := -1
	for f in (G.get("forcedRandom", []) as Array):
		for i in hand.size():
			if forced < 0 and int((hand[i] as Dictionary).get("_oid", -1)) == int(f):
				forced = i
	if forced >= 0:
		pick = forced
	elif G.has("forcedRandom"):
		return # rejeu APK : aucune carte n'a change de main (l'IA oracle a designe son propre boss : transaction sans effet net)
	var card: Dictionary = hand[pick]
	hand.remove_at(pick)
	victim["hand"] = hand
	var mine: Array = thief.get("hand", []) as Array
	thief["hand"] = mine
	mine.append(card)
	_log(G, "%s: player %d took %s from player %d." % [label, thief_pid, str(card.get("name", "?")), victim_pid])

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

## BMA034 Construction Zone : ExtraBuildTurn(BossOwner) = PendingExtraBuiltTurns.Add -> ExtraBuildPhase (Match._start_forced_build).
static func _construction_zone(G: Dictionary, player_id: int) -> Variant:
	var queue: Array = G.get("forcedBuilds", []) as Array
	G["forcedBuilds"] = queue
	queue.append({"playerId": player_id, "cardId": ""})
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
static func _golem_factory(G: Dictionary, p: Dictionary, _room: Dictionary) -> Variant:
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

## BMA014 Vampire Bordello : soigne une blessure (retourne une ame face cachee). C# : HeroInScorekeep[Owner, Alive] + FlipHero,
## le joueur CHOISIT le heros vivant a retourner (auto s'il n'y en a qu'un : TryToAutoresolve).
static func _vampire_bordello(G: Dictionary, p: Dictionary, player_id: int) -> Variant:
	var heroes := BossEngine.wound_heroes(p)
	if heroes.size() > 1:
		var opts: Array = []
		for h in heroes:
			opts.append({"card": h, "label": str((h as Dictionary).get("name", "?"))})
		return {"type": "heal-wound", "playerId": player_id, "bossName": "Vampire Bordello",
			"message": "Vampire Bordello: choose a Hero to flip", "options": opts}
	var soul = BossEngine.heal_one_wound(p)
	if soul != null:
		_log(G, "Vampire Bordello: healed a Wound (%d soul)." % int((soul as Dictionary).get("souls", 1)))
	return null

## Defausse un sort au hasard de la main d'un joueur.
static func _discard_random_spell_from(G: Dictionary, pid: int, label: String) -> void:
	_discard_random_from(G, pid, true, label)

## DiscardRandomCardFromHand(1, Spell|Room) : une carte du type voulu, au hasard, vers la defausse correspondante.
static func _discard_random_from(G: Dictionary, pid: int, spell: bool, label: String) -> void:
	var opp := _player(G, pid)
	var hand: Array = opp.get("hand", []) as Array
	var idxs: Array = []
	for i in hand.size():
		if bool((hand[i] as Dictionary).get("isSpell", false)) == spell:
			idxs.append(i)
	if idxs.is_empty():
		return
	var pick: int = idxs[randi() % idxs.size()]
	# Crochet de rejeu (harnais de parite APK) : G["forcedRandom"] = _oid des cartes tirees par l'oracle, dans l'ordre. Absent => hasard.
	for f in (G.get("forcedRandom", []) as Array):
		var hit := idxs.filter(func(i): return int((hand[i] as Dictionary).get("_oid", -1)) == int(f))
		if not hit.is_empty():
			pick = hit[0]
			break
	var card: Dictionary = hand[pick]
	hand.remove_at(pick)
	opp["hand"] = hand
	var decks: Dictionary = G.get("decks", {})
	if spell:
		var pile: Array = decks.get("spellDiscard", []) as Array
		decks["spellDiscard"] = pile
		pile.append(card)
	else:
		BossEngine.discard_room_to_pile(decks, card)
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
			options.append({"targetPlayerId": target_pid, "roomIndex": i, "card": BossEngine.active_room(dungeon[i])})
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
	# Autres bosses (KSA / extensions) : LevelUpAbility de l'APK, lu dans cards.json (`levelUp`), pas par id de carte.
	var lu = boss.get("levelUp")
	if lu is Dictionary:
		return _apk_level_up(G, player_id, p, lu as Dictionary)
	return null

## Commandes de level-up du PlayerChoice. AddTreasuresToDungeon / LastRoomDealDamage / AddSoulsToBoss sont des effets PASSIFS
## (IPassive*Command, valables tant que Boss.IsLevelUpUnlocked) : lus par BossEngine.dungeon_treasures / room_damage_with_modifiers /
## CardDB.passive_souls, rien a executer ici. Les autres ouvrent un choix (`optional` = Ability.CanAvoid) ; aucune cible = capacite ignoree.
static func _apk_level_up(G: Dictionary, player_id: int, p: Dictionary, lu: Dictionary) -> Variant:
	match str(lu.get("cmd", "")):
		"MultiplyTreasuresDungeon": # KSA007 Elicon : tresors des salles x N jusqu'a la fin du tour (DungeonSlot.TreasuresMultiplier)
			(_effects(G)["treasureDoubled"] as Array).append(player_id)
			_log(G, "Elicon: treasure of every Room doubled until end of turn.")
		"PutCardInHand": # KSA003 The Brothers Wise : un sort de la pioche de sorts (SpellInDeck BoardDeck) vers la main
			var spells: Array = (G.get("decks", {}) as Dictionary).get("spells", [])
			var opts: Array = []
			for i in spells.size():
				opts.append({"card": spells[i], "pile": "deck", "pileIndex": i})
			if opts.is_empty():
				return null
			return {"type": "search-spell", "playerId": player_id, "optional": bool(lu.get("canAvoid", false)),
				"bossName": "The Brothers Wise", "message": "The Brothers Wise: choose a Spell from the deck", "options": opts}
		"PlaceAtScorekeep": # KSA004 Kaw'nee : un heros ORDINAIRE mort (SoulsHeroes) d'un adversaire passe face cachee chez soi
			var opts: Array = []
			for opid in (G.get("players", {}) as Dictionary):
				if int(opid) == player_id:
					continue
				var souls: Array = (G["players"][opid] as Dictionary).get("souls", [])
				for i in souls.size():
					var e: Dictionary = souls[i]
					if not bool(e.get("epic", false)):
						opts.append({"card": e.get("hero", e), "fromPid": int(opid), "soulIndex": i,
							"label": "%s (player %d)" % [str(e.get("name", "?")), int(opid) + 1]})
			if opts.is_empty():
				return null
			return {"type": "steal-hero", "playerId": player_id, "optional": bool(lu.get("canAvoid", false)),
				"bossName": "Kaw'nee", "message": "Kaw'nee: choose an ordinary Hero in an opponent's scorekeeping area", "options": opts}
		"RearrangeDungeon": # KSA002 Hellcow : n'importe quel donjon, ordre des salles (toutes) au choix
			return rearrange_choice(G, player_id, -1, [])
	return null

## KSA002 : etape 1 (target_pid < 0) = choisir le donjon ; ensuite on designe les salles dans l'ordre C# des slots (Dungeon[0] = fond =
## index Godot le plus grand). La derniere salle restante est placee d'office. Une seule salle / un seul donjon candidat = sans choix.
static func rearrange_choice(G: Dictionary, player_id: int, target_pid: int, picked: Array) -> Variant:
	var players: Dictionary = G.get("players", {})
	if target_pid < 0:
		var opts: Array = []
		for opid in players:
			var d: Array = (players[opid] as Dictionary).get("dungeon", [])
			if (players[opid] as Dictionary).get("eliminated", false) or _rearrangeable(G, int(opid)).is_empty():
				continue
			opts.append({"targetPlayerId": int(opid), "card": BossEngine.active_room(d[d.size() - 1]), "label": "Dungeon of player %d" % (int(opid) + 1)})
		if opts.is_empty():
			return null
		if opts.size() == 1:
			return rearrange_choice(G, player_id, int((opts[0] as Dictionary)["targetPlayerId"]), [])
		return {"type": "rearrange-dungeon", "step": "dungeon", "playerId": player_id, "bossName": "Hellcow",
			"message": "Hellcow: choose a dungeon to rearrange", "options": opts}
	var rooms: Array = _rearrangeable(G, target_pid)
	var left: Array = []
	for i in rooms:
		if not picked.has(i):
			left.append(i)
	if left.size() <= 1:
		_apply_rearrange(G, target_pid, picked + left)
		return null
	var opts2: Array = []
	var dungeon: Array = (players[target_pid] as Dictionary).get("dungeon", [])
	for i in left:
		opts2.append({"targetPlayerId": target_pid, "roomIndex": i, "card": BossEngine.active_room(dungeon[i])})
	return {"type": "rearrange-dungeon", "step": "order", "playerId": player_id, "bossName": "Hellcow", "targetPlayerId": target_pid,
		"picked": picked, "message": "Hellcow: choose the Room that comes next from the back of the dungeon", "options": opts2}

## Slots ciblables par RoomInDungeon (actifs, non en attente de revelation, non geles) ; seul un donjon ENTIEREMENT ciblable peut etre
## reordonne (RearrangeDungeon.Execute exige Target1.Count == DungeonSize). Renvoie les index Godot du fond vers l'entree.
static func _rearrangeable(G: Dictionary, pid: int) -> Array:
	var d: Array = (G["players"][pid] as Dictionary).get("dungeon", [])
	var out: Array = []
	for i in range(d.size() - 1, -1, -1):
		var r = BossEngine.active_room(d[i])
		if r == null or bool((r as Dictionary).get("faceDown", false)) or BossEngine.is_room_deactivated(G, pid, i):
			return []
		out.append(i)
	return out

## Dungeon[i] = piles dans l'ordre choisi (indices Godot, fond d'abord) : meme resultat que les echanges de RearrangeDungeon.Execute.
static func _apply_rearrange(G: Dictionary, pid: int, order: Array) -> void:
	var p: Dictionary = G["players"][pid]
	var old: Array = (p.get("dungeon", []) as Array).duplicate()
	var d: Array = p["dungeon"]
	var moved := {}
	for k in order.size():
		d[old.size() - 1 - k] = old[int(order[k])]
		moved[int(order[k])] = old.size() - 1 - k
	for key in ["deactivatedRooms", "roomDamageBonus"]: # effets indexes par slot : ils suivent leur DungeonSlot
		for e in (_effects(G).get(key, []) as Array):
			if int((e as Dictionary).get("playerId", -1)) == pid and moved.has(int((e as Dictionary).get("roomIndex", -1))):
				e["roomIndex"] = moved[int(e["roomIndex"])]
	_log(G, "Hellcow: dungeon of player %d rearranged." % pid)

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
	# C# CardInHand(1, Opponent) : une seule carte adverse = cible auto-resolue (TryToAutoresolve).
	if opts.size() == 1:
		var o: Dictionary = opts[0]
		var oh: Array = (G["players"][int(o["fromPid"])] as Dictionary)["hand"]
		var hand: Array = _player(G, player_id).get("hand", []) as Array
		_player(G, player_id)["hand"] = hand
		hand.append(oh.pop_at(int(o["handIndex"])))
		_log(G, "Draculord: took %s from player %d." % [str((o["card"] as Dictionary).get("name", "?")), int(o["fromPid"])])
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

## BMA003 King Croak / BMA007 Cleopatra : cherche une salle avancee (RoomInDeck Advanced + PutCardInHand + BuildRoomBy).
## C# : CanAvoid=false -> la cible est OBLIGATOIRE (pas de "passer", malgre le "may" du texte) ; aucune
## candidate = abilite ignoree (CheckConditions) ; une seule candidate = auto-resolue.
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
	if options.size() == 1:
		take_searched_room(G, player_id, options[0], boss_name)
		return null
	return {"type": "search-advanced", "playerId": player_id, "bossName": boss_name,
		"roomType": room_type, "message": "%s: choose an Advanced %s Room" % [boss_name, kind],
		"options": options}

## PutCardInHand + BuildRoomBy : la salle va en main et le joueur obtient un tour de construction
## supplementaire force sur ce numero de carte (Boss.ForcedToBuildRoom, GameBoard.PendingExtraBuiltTurns).
## Match._start_forced_build joue ce tour apres la revelation de fin de phase BUILD.
static func take_searched_room(G: Dictionary, player_id: int, option: Dictionary, label: String) -> Variant:
	var player := _player(G, player_id)
	var decks: Dictionary = G.get("decks", {})
	var from_discard := str(option.get("pile", "")) == "discard"
	var pile: Array = decks.get("roomDiscard" if from_discard else "rooms", [])
	decks["roomDiscard" if from_discard else "rooms"] = pile
	if not pile_index_matches(pile, option):
		return null
	var card: Dictionary = pile[int(option["pileIndex"])]
	pile.remove_at(int(option["pileIndex"]))
	var hand: Array = player.get("hand", []) as Array
	player["hand"] = hand
	hand.append(card)
	var forced: Array = G.get("forcedBuilds", []) as Array
	G["forcedBuilds"] = forced
	forced.append({"playerId": player_id, "cardId": str(card.get("id", ""))})
	_log(G, "%s: %s recherche, construction forcee." % [label, str(card.get("name", "?"))])
	return card

## BMA004 Robobo : chaque adversaire detruit une salle de son choix (BossOpponents + ChooseAndDestroyRoom).
## Ordre = PlayerId croissant (GameBoard.GetOpponents), adversaires elimines exclus.
static func _robobo(G: Dictionary, player_id: int) -> Variant:
	var victims: Array = []
	for opid in (G.get("players", {}) as Dictionary):
		if int(opid) != player_id and not bool(G["players"][opid].get("eliminated", false)):
			victims.append(int(opid))
	victims.sort()
	if victims.is_empty():
		_log(G, "Robobo: no opponent rooms to destroy.")
		return null
	G["roboboQueue"] = victims
	return robobo_advance(G)

## Avance la file Robobo : saute les adversaires sans salle (DungeonSize <= 0), auto-detruit quand
## il n'y a qu'une salle (TryToAutoresolve), sinon renvoie le choix de l'adversaire concerne.
static func robobo_advance(G: Dictionary) -> Variant:
	var raw_queue = G.get("roboboQueue", [])
	var queue: Array = raw_queue if raw_queue is Array else []
	G["roboboQueue"] = queue
	while not queue.is_empty():
		var choice: Dictionary = robobo_choice(G, int(queue.pop_front())) as Dictionary
		var opts: Array = choice.get("options", []) as Array
		if opts.is_empty():
			continue
		if opts.size() > 1:
			return choice
		var o: Dictionary = opts[0]
		destroy_room_choice(G, int(o["targetPlayerId"]), int(o["roomIndex"]), "Robobo")
	return null

## Detruit la salle choisie (sans declencheur, checkTriggers:false) et l'envoie a la defausse.
static func destroy_room_choice(G: Dictionary, target_pid: int, room_index: int, label: String) -> void:
	var tp := _player(G, target_pid)
	var destroyed = BossEngine.destroy_room(tp, room_index, G, false)
	if destroyed == null:
		return
	BossEngine.discard_room_to_pile(G.get("decks", {}), destroyed)
	_log(G, "%s: %s detruit par le joueur %d." % [label, str((destroyed as Dictionary).get("name", "?")), target_pid])

## BMA005 Cerebellus : pioche 3 sorts, puis defausse 1 sort de la main (DiscardSomeCardFromHand, comme Dark Laboratory).
static func _cerebellus(G: Dictionary, p: Dictionary, player_id: int) -> Variant:
	_draw_into(G, p, "spells", 3)
	return _spell_discard_choice(G, p, player_id, "BMA005", "Cerebellus")

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
			souls.append(CardDB.soul_entry(hero))
		_log(G, "Gorgona: killed %s." % str(hero.get("name", "?")))
	return null