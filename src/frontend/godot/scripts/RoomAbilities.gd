class_name RoomAbilities
extends RefCounted
## Abilities des salles du base set (BMA) ; reference : le C# de l'APK.
## Chaque fonction renvoie null si tout s'est bien passe, ou un message d'erreur.

static func _player(G: Dictionary, pid: int) -> Dictionary:
	var players: Dictionary = G.get("players", {})
	return players.get(pid, players.get(str(pid), {})) as Dictionary

## `pub` non vide : ligne privee (voir Match._log) ; `owners` = sieges qui lisent `t`, les autres lisent `pub`.
static func _log(G: Dictionary, t: String, pub: String = "", owners: Array = []) -> void:
	var logs: Array = G.get("logs", [])
	G["logs"] = logs
	logs.append({"t": t, "pub": pub, "owners": owners} if pub != "" else t)

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
	if TnlAbilities.active(G): # TNL020 Dragon Graveyard : prendre une carte dans la defausse fait piocher une salle
		TnlAbilities.on_take_from_discard(G, player)
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
		if r != null and str((r as Dictionary).get("id", "")) == "BMA023" and not bool((r as Dictionary).get("faceDown", false)) and not TnlAbilities.no_text(r as Dictionary):
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

# --- capacites activees = transactions de la pile (R-D67, R-E26) ---

## Identifiant stable d'une salle (le compteur de Match, qui ne consomme pas le tirage global) : les indices glissent apres une destruction.
static func room_uid(room: Dictionary) -> int:
	if not room.has("_tuid"):
		Match._tuid_seq += 1
		room["_tuid"] = Match._tuid_seq
	return int(room["_tuid"])

## Room.CanPlayerPlayAbility : une transaction en attente pour cette salle interdit une 2e activation.
static func is_queued(G: Dictionary, room: Dictionary) -> bool:
	if not room.has("_tuid"):
		return false
	for e in (G.get("stack", []) as Array):
		if str((e as Dictionary).get("type", "")) == "ability" and int((e as Dictionary).get("roomUid", -1)) == int(room["_tuid"]):
			return true
	return false

## GameBoard.PlayRoomAbility -> EnqueueAbilityTransaction : l'entree de pile d'une capacite activee. `other` = indice de l'autre salle (Boulder Ramp, Crushinator).
static func make_entry(G: Dictionary, player_id: int, room_index: int, other_room_index: int) -> Dictionary:
	var dungeon: Array = _player(G, player_id).get("dungeon", [])
	var r: Dictionary = BossEngine.active_room(dungeon[room_index])
	var uid := room_uid(r)
	var e := {"id": "ability-%s-%d" % [str(r.get("id", "")), uid], "type": "ability", "playerId": player_id,
		"card": r.duplicate(), "target": {}, "resolved": false, "roomUid": uid}
	if other_room_index >= 0 and other_room_index < dungeon.size():
		e["otherUid"] = room_uid(BossEngine.active_room(dungeon[other_room_index]))
	return e

static func _find_room_by_uid(p: Dictionary, uid: int) -> Array:
	var dungeon: Array = p.get("dungeon", [])
	for i in dungeon.size():
		var st: Array = dungeon[i]
		for k in st.size():
			if int((st[k] as Dictionary).get("_tuid", -1)) == uid:
				return [i, k == st.size() - 1, st[k]]
	return []

## Execute la transaction (AbilityTransaction.Run -> Ability.DoEffect) : null si elle s'est executee, sinon la raison (annulee).
## GameBoard.DestroyRoom -> RemovePendingTransactionsByTarget : une salle detruite annule sa propre capacite (cible « cette salle »), et une salle
## recouverte leve (exception C#, rien ne s'execute) ; Dracolich Lair et Witch's Kitchen ne ciblent pas leur salle, elles s'executent quand meme.
static func run_queued(G: Dictionary, e: Dictionary) -> Variant:
	var pid := int(e.get("playerId", -1))
	var p := _player(G, pid)
	var id := str((e.get("card", {}) as Dictionary).get("id", ""))
	var found := _find_room_by_uid(p, int(e.get("roomUid", -1)))
	if found.is_empty() or not bool(found[1]):
		if id != "BMA013" and id != "BMA024":
			return "room left the game or is covered"
		var r: Dictionary = found[2] if not found.is_empty() else (e["card"] as Dictionary)
		r["usedThisTurn"] = true
		var cerr = _dracolich_lair(G, p, pid, r) if id == "BMA013" else _witchs_kitchen(G, p, pid)
		if cerr != null:
			r["usedThisTurn"] = false
		return cerr
	var other := -1
	if e.has("otherUid"):
		var o := _find_room_by_uid(p, int(e["otherUid"]))
		if o.is_empty():
			return "target room left the game"
		other = int(o[0])
	var err = activate_room_ability(G, pid, int(found[0]), other, true)
	if err != null:
		(found[2] as Dictionary)["usedThisTurn"] = false # IsEffectApplied n'est pose qu'apres DoEffect : une transaction qui echoue ne consomme pas OncePerTurn (R-E29)
	return err

# --- activation d'abilite de salle (base set) ---

## Salles a condition OncePerTurn (Ability.IsEffectApplied) parmi les capacites activables.
const ONCE_PER_TURN := ["BMA013", "BMA024", "BMA025", "CRL012"]

## Active l'abilite de la salle a room_index. Renvoie null si OK, sinon un message d'erreur.
## `queued` = execution d'une transaction deja en file (run_queued) : Ability.DoEffect ne reverifie pas les conditions (Ability.CheckConditions n'est
## testee qu'a la mise en file, Room.CanPlayerPlayAbility) ; une salle gelee ou une capacite verrouillee entre-temps s'execute donc quand meme.
static func activate_room_ability(G: Dictionary, player_id: int, room_index: int, other_room_index: int = -1, queued := false):
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
	if not queued:
		if bool(r.get("usedThisTurn", false)):
			return "already used this turn"
		if is_queued(G, r):
			return "already queued" # Room.CanPlayerPlayAbility : aucune transaction en attente pour cette salle
		if BossEngine.abilities_locked(G, player_id):
			return "abilities locked (Trap Master)" # KSA017 : Ability.IsLocked -> CheckConditions faux
	# Cartes wiki (TNL / RMB / CRL) : glossaire « Face-Down » / « Deactivate » -> une salle face cachee (posee ce tour) ou gelee n'a aucune capacite.
	# Les salles de l'APK gardent leur propre controle plus bas (parite), les coups legaux passent par cette fonction.
	if not queued and ApkAI.is_wiki_card(str(r.get("id", ""))) and (bool(r.get("faceDown", false)) or BossEngine.is_room_deactivated(G, player_id, room_index)):
		return "room is face down or frozen"
	if ThkAbilities.ACTIVATED.has(str(r.get("id", ""))): # Tools of Hero-Kind : Orcish Smithy, Burial Mound, Artificer's Workbench (seulement avec la case wiki)
		return ThkAbilities.activate(G, p, player_id, room_index, r)
	if Minibosses.active(G) and RmbAbilities.ACTIVATED.has(str(r.get("id", ""))): # Rise of the Minibosses : capacites activees des salles RMB
		return RmbAbilities.activate(G, p, player_id, room_index, r)
	if TnlAbilities.active(G):
		if not queued and TnlAbilities.no_text(r): # TNL062 Meddling Kids! : « no ability text » jusqu'a la fin du tour
			return "no ability text (Meddling Kids!)"
		if TnlAbilities.ACTIVATED.has(str(r.get("id", ""))): # The Next Level : capacites activees des salles TNL
			return TnlAbilities.activate(G, p, player_id, room_index, r)

	var id := str(r.get("id", ""))
	if not ApkAI.is_wiki_card(id):
		# GameBoard.PlayRoomAbility (GameBoard.cs:817, « must be in the player dungeon ») : seules les salles de Boss.DungeonActiveRooms (Boss.cs:116 :
		# slot actif, hors PendingToBeBuilt) activent leur capacite ; ThisRoom (ThisRoom.cs) exige aussi le slot actif. Ni salle posee ce tour, ni salle gelee.
		if not queued and (bool(r.get("faceDown", false)) or BossEngine.is_room_deactivated(G, player_id, room_index)):
			return "room is face down or frozen"
		# BMA030 Jackpot Stash : DuringPhase(Build) = BuildPhase_a seule (Conditions/DuringPhase.cs:19) ; aucune autre salle du base set n'a de condition de phase.
		if not queued and id == "BMA030" and str(G.get("phase", "")) != CardDB.PHASE["BUILD"]:
			return "Jackpot Stash: build phase only"
	if ONCE_PER_TURN.has(str(r.get("id", ""))):
		r["usedThisTurn"] = true # data.json : seules BMA013/024/025 portent OncePerTurn (Crushinator et Boulder Ramp sont rejouables)
	match id:
		"BMA009": return _dark_altar(G, p, room_index, player_id, r)
		"BMA025": return _all_seeing_eye(G, p, player_id)
		"BMA027": return _bottomless_pit(G, p, player_id, room_index, r)
		"BMA028": return _boulder_ramp(G, p, player_id, room_index, other_room_index, r)
		"BMA030": return _jackpot_stash(G, p, player_id, room_index)
		"BMA032": return _crushinator(G, p, player_id, room_index, other_room_index)
		"BMA038": return _torture_chamber(G, player_id, room_index)
		"BMA013": return _dracolich_lair(G, p, player_id, r)
		"BMA024": return _witchs_kitchen(G, p, player_id)
		"BMA039": return _zombie_prison(G, p, room_index, player_id, r)
		"CRL012": return _omega_42(G, p, player_id, r)
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
	enqueue_pending(G, {"type": "recover-card", "resume": false, "playerId": player_id, # enqueue : la destruction de l'Autel a pu decouvrir une salle (CRL)
		"bossName": "Dark Altar", "message": "Dark Altar: choose a card from the discard pile",
		"options": opts})
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
	CardDB.discard_add(pile, card)
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
	CardDB.discard_add(pile, card)
	Minibosses.on_hand_discard(G, int(p.get("id", -1)), card) # RMB017 Imp Hoard

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
	adv.erase("dealZero") # un KillHero l'emporte sur un DealHero a 0 PV en attente
	adv["noDeathTrigger"] = true # KillHero = RemoveHeroFromGame + SoulsHeroes.Add : ni HeroDiesInThisRoom ni HeroDiesAnotherRoom (seul ProccessActiveHero les leve)
	var destroyed = BossEngine.destroy_room(p, room_index, G)
	BossEngine.discard_room_to_pile(G.get("decks", {}), destroyed)
	return null

## DealHero / DealRoomsCountToHero (Hero.Deal) : PV bornes a 0, SANS test de mort (DealHero.cs:42-45). Le heros reste en vie a 0 PV : au pas suivant
## (GameBoard.ProccessActiveHero) il passe a la salle d'apres, en subit les degats et meurt DANS cette salle (HeroDiesInThisRoom de celle-ci) ;
## sans salle suivante il meurt sans declencheur. `dealZero` neutralise les tests de mort immediats (Match._finish_hero_if_dead, pause post-damage).
static func deal_hero(adv: Dictionary, amount: int) -> void:
	var was_alive := int(adv.get("hp", 0)) > 0 # deja a 0 PV apres les degats de la salle : il est mort dans CETTE salle (pas de report)
	adv["hp"] = maxi(0, int(adv.get("hp", 0)) - amount)
	if was_alive and int(adv["hp"]) <= 0:
		adv["dealZero"] = true

## BMA028 Boulder Ramp : detruit une autre salle, 5 degats au hero de celle-ci.
static func _boulder_ramp(G: Dictionary, p: Dictionary, player_id: int, room_index: int, other: int, room: Dictionary):
	var dungeon: Array = p.get("dungeon", [])
	if not BossEngine.is_another_room_target(G, player_id, dungeon, room_index, other):
		return "must target another active room" # AnotherRoom.cs : slot C# < DungeonSize, actif, autre que la salle
	if not hero_is_in_room(G, player_id, room_index):
		return "no hero in this room"
	var adv: Dictionary = G.get("adventure", {}) as Dictionary
	deal_hero(adv, 5)
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
	var dungeon: Array = p.get("dungeon", [])
	if not BossEngine.is_another_room_target(G, player_id, dungeon, room_index, other):
		return "must target another active room" # AnotherRoom.cs : slot C# < DungeonSize, actif, autre que la salle
	var destroyed = BossEngine.destroy_room(p, other, G)
	BossEngine.discard_room_to_pile(G.get("decks", {}), destroyed)
	var eff := _effects(G)
	var arr: Array = eff.get("roomDamageBonus", [])
	eff["roomDamageBonus"] = arr
	# DealDamageToDungeon.Execute : slot.Deal(2) sur les 5 emplacements, vides compris (une salle posee plus tard ce tour recoit aussi +2).
	for i in (p.get("dungeon", []) as Array).size():
		arr.append({"playerId": player_id, "roomIndex": i, "amount": 2})
	var eb := BossEngine.empty_slot_bonuses(G, player_id)
	while eb.size() < 5 - (p.get("dungeon", []) as Array).size():
		eb.append(0)
	for k in eb.size():
		eb[k] = int(eb[k]) + 2
	_log(G, "The Crushinator: your Rooms deal +2 damage this turn.")
	return null

## BMA038 Torture Chamber : detruit cette salle, puis DiscardRandomCardFromHand(1, Room) sur un adversaire
## (BossOpponent : tout adversaire, meme sans salle en main ; un seul adversaire = cible automatique).
static func _torture_chamber(G: Dictionary, player_id: int, room_index: int):
	var p := _player(G, player_id)
	var d = BossEngine.destroy_room(p, room_index, G)
	BossEngine.discard_room_to_pile(G.get("decks", {}), d)
	var opps := opponents_with(G, player_id)
	if opps.size() == 1:
		_discard_random_from(G, int((opps[0] as Dictionary)["playerId"]), false, "Torture Chamber", player_id)
	elif opps.size() > 1:
		var opts: Array = []
		for o in opps:
			opts.append({"targetPlayerId": int((o as Dictionary)["playerId"])})
		enqueue_pending(G, {"type": "pick-opponent", "action": "discard-room", "resume": false, "playerId": player_id,
			"bossName": "Torture Chamber", "message": "Torture Chamber: choose an opponent to discard a random Room", "options": opts})
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
			var dcard: Dictionary = hand.pop_at(int(i))
			BossEngine.discard_room_to_pile(G.get("decks", {}), dcard)
			Minibosses.on_hand_discard(G, player_id, dcard) # RMB017 Imp Hoard
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
	enqueue_pending(G, {"type": "revive-hero", "resume": false, "playerId": player_id,
		"bossName": "Zombie Prison", "message": "Zombie Prison: choose a dead Hero to send back to its dungeon",
		"options": opts})
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
	# SendBackToDungeonEntrance.Execute (heros mort du scorekeeping) : Target1.RestoreHealth() avant de rejoindre l'entree (s27-p3@562 :
	# un heros ranime par Zombie Attack (+2 PV) puis tue revient avec ses PV de base).
	hero["hp"] = BossEngine.hero_base_hp(hero)
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
	var kcard: Dictionary = hand.pop_at(at)
	BossEngine.discard_room_to_pile(G.get("decks", {}), kcard)
	Minibosses.on_hand_discard(G, player_id, kcard) # RMB017 Imp Hoard
	var drawn := _draw_into(G, p, "spells", 1)
	if not drawn.is_empty():
		_log(G, "Witch's Kitchen: drew %s." % str((drawn[0] as Dictionary).get("name", "?")), "Witch's Kitchen: drew a Spell.", [player_id])

# --- abilities passives (roomAbilities.js:onBuildRoom / onHeroDiedInRoom) ---

static func _draw_into(G: Dictionary, player: Dictionary, pile: String, n: int) -> Array:
	var decks: Dictionary = G.get("decks", {})
	var out: Array = CardDB.draw_pile(decks, pile, n) # DrawCards -> GameBoard.DrawRooms/DrawSpells (pioche vide : defausses remelangees)
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
	if Minibosses.active(G): # Rise of the Minibosses : boss (Lamia, Dr. Deadly), Goblin Market, salles RMB
		var rmb_choice = RmbAbilities.on_build(G, player_id, room)
		if rmb_choice != null:
			return rmb_choice
	if TnlAbilities.active(G): # The Next Level : salles TNL + effets de boss « quand vous construisez » (Smoake)
		var tnl_choice = TnlAbilities.on_build(G, player_id, room)
		if tnl_choice != null:
			return tnl_choice
	if id == "KSA010" and ThkAbilities.active(G): # Bone Crank (case wiki) : desactive une salle
		return PcwAbilities.on_build(G, player_id, room)
	match id:
		"BMA022": return _dark_laboratory(G, p, player_id)
		"BMA011": return _specters_sanctum(G, p, player_id)
		"BMA036": return _mimic_vault(G, p, player_id)
		"BMA037": return _monstrous_monument(G, p, player_id)
		"BMA034": return _construction_zone(G, player_id)
		"BMA033": return _centipede_tunnel(G, player_id)
		"CRL004": return _alien_excavator(G, player_id)
		"CRL006": # Decoy Garden : gagne 2 tresors Explorer jusqu'a la fin du tour (effacee a _start_turn)
			var extra: Array = (room.get("extraTreasures", []) as Array).duplicate()
			extra.append_array([5, 5]) # « it gains Explorer*2 » a chaque fois que l'effet se declenche (rejeu par The Omega 42 : cumulatif)
			room["extraTreasures"] = extra
			_log(G, "Decoy Garden : Explorer x2 jusqu'a la fin du tour.")
		"CRL010": # Digicron Library : au moins 2 salles avancees visibles (elle comprise) -> 2 sorts
			var adv := 0
			for stack in (p.get("dungeon", []) as Array):
				var top = BossEngine.active_room(stack)
				if top != null and not bool((top as Dictionary).get("faceDown", false)) and bool((top as Dictionary).get("advanced", false)):
					adv += 1
			if adv >= 2:
				_draw_into(G, p, "spells", 2)
				_log(G, "Digicron Library : pioche 2 sorts.")
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
		if str(o.get("id", "")) != "BMA019" or bool(o.get("usedThisTurn", false)) or TnlAbilities.no_text(o):
			continue
		o["usedThisTurn"] = true
		out.append(o)
	return out

static func run_another_room_trigger(G: Dictionary, player_id: int, _room: Dictionary) -> void:
	var drawn := _draw_into(G, _player(G, player_id), "rooms", 1)
	if not drawn.is_empty():
		_log(G, "Beast Menagerie: drew %s." % str((drawn[0] as Dictionary).get("name", "?")), "Beast Menagerie: drew a Room.", [player_id])

## Declenche quand un hero meurt dans cette salle. Renvoie un choix, ou null.
static func on_hero_died_in_room(G: Dictionary, player_id: int, room: Dictionary) -> Variant:
	var p := _player(G, player_id)
	if p.is_empty():
		return null
	var id := str(room.get("id", ""))
	if Minibosses.active(G): # Rise of the Minibosses : minibosses (Rocky, Cerebella, Brassknuckle niveau 2), Oculus, Lightning Rod, Mind Thresher
		Minibosses.on_hero_died(G, player_id, room)
		RmbAbilities.on_hero_died(G, player_id, room)
	if TnlAbilities.is_tnl(room): # The Next Level
		return TnlAbilities.on_hero_died(G, player_id, room)
	if TnlAbilities.no_text(room): # TNL062 Meddling Kids! : les declencheurs du base set sont eteints aussi
		return null
	# Tous les declencheurs HeroDiesInThisRoom du base set portent OncePerTurn (Ability.IsEffectApplied), verifie a la mise en file.
	if ["BMA010", "BMA012", "BMA014", "BMA016", "BMA021"].has(id):
		if bool(room.get("usedThisTurn", false)):
			return null
		# Ability.CheckConditions : sans cible (MinTargetsAmount) l'effet n'est pas applique, donc IsEffectApplied reste faux (R-F26, R-F30)
		if (id == "BMA010" and discard_card_options(G, "room").is_empty()) or (id == "BMA014" and (p.get("wounds", []) as Array).is_empty()):
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

## BMA011 Specter's Sanctum : un adversaire defausse un sort au hasard. BossOpponent propose TOUS les adversaires vivants (sans filtre sur les sorts :
## GameBoard.cs:208, BossOpponent.cs:25), auto-resolu seulement s'il n'y en a qu'un (SingleTargetProvider) ; un adversaire sans sort ne perd rien.
static func _specters_sanctum(G: Dictionary, _p: Dictionary, player_id: int) -> Variant:
	var opps := opponents_with(G, player_id)
	if opps.is_empty():
		return null
	if opps.size() == 1:
		_discard_random_spell_from(G, int((opps[0] as Dictionary)["playerId"]), "Specter's Sanctum", player_id)
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
		if p.get("eliminated", false):
			continue # RoomInDungeon Any : proprietaire + GetOpponents (InGamePlayersPriorized, sans les elimines)
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
		_log(G, "Golem Factory: drew %s." % str((drawn[0] as Dictionary).get("name", "?")), "Golem Factory: drew a Room.", [int(p.get("id", -1))])
	return null

## BMA021 Brainsucker Hive : pioche un sort.
static func _brainsucker_hive(G: Dictionary, p: Dictionary) -> Variant:
	var drawn := _draw_into(G, p, "spells", 1)
	if not drawn.is_empty():
		_log(G, "Brainsucker Hive: drew %s." % str((drawn[0] as Dictionary).get("name", "?")), "Brainsucker Hive: drew a Spell.", [int(p.get("id", -1))])
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
static func _discard_random_spell_from(G: Dictionary, pid: int, label: String, actor: int = -1) -> void:
	_discard_random_from(G, pid, true, label, actor)

## DiscardRandomCardFromHand(1, Spell|Room) : une carte du type voulu, au hasard, vers la defausse correspondante.
## `actor` = joueur dont l'effet force la defausse (TNL014 Imp Temple prend alors la carte en main au lieu de la defausser).
static func _discard_random_from(G: Dictionary, pid: int, spell: bool, label: String, actor: int = -1) -> void:
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
	if TnlAbilities.imp_take(G, actor, card):
		return
	var decks: Dictionary = G.get("decks", {})
	if spell:
		var pile: Array = decks.get("spellDiscard", []) as Array
		decks["spellDiscard"] = pile
		CardDB.discard_add(pile, card)
	else:
		BossEngine.discard_room_to_pile(decks, card)
	Minibosses.on_hand_discard(G, pid, card) # RMB017 Imp Hoard
	_log(G, "%s: player %d discarded %s." % [label, pid, str(card.get("name", "?"))])

## Construit le choix suivant de la file Robobo (adversaires restants).
static func robobo_choice(G: Dictionary, target_pid: int) -> Variant:
	if target_pid < 0 or not (G.get("players", {}) as Dictionary).has(target_pid):
		return {}
	var tp: Dictionary = G["players"][target_pid]
	var dungeon: Array = tp.get("dungeon", [])
	var options: Array = []
	for i in dungeon.size():
		if BossEngine.active_room(dungeon[i]) != null and not BossEngine.is_room_deactivated(G, target_pid, i): # RoomInDungeon : slot.IsActive
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
	if str(boss.get("id", "")).begins_with("TNL"): # The Next Level : TNL000-TNL012
		return TnlAbilities.level_up(G, player_id, p, boss)
	if str(boss.get("id", "")).begins_with("RMB"): # Rise of the Minibosses : RMB001-RMB012 (drapeaux « pour le reste de la partie »)
		return RmbAbilities.level_up(G, player_id, p, boss)
	if str(boss.get("id", "")).begins_with("IOD"): # Implements of Destruction (case wiki) : IOD025-IOD029
		return IodAbilities.level_up(G, player_id, p, boss)
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
			if opts.size() == 1: # SingleTargetProvider.TryToAutoresolve : une seule cible = prise d'office, sans choix ni « passer »
				(p["hand"] as Array).append(spells.pop_at(0))
				_log(G, "The Brothers Wise: the only Spell in the deck goes to the hand.")
				return null
			return {"type": "search-spell", "playerId": player_id, "optional": bool(lu.get("canAvoid", false)),
				"bossName": "The Brothers Wise", "message": "The Brothers Wise: choose a Spell from the deck", "options": opts}
		"PlaceAtScorekeep": # KSA004 Kaw'nee : un heros ORDINAIRE mort (SoulsHeroes) d'un adversaire passe face cachee chez soi
			var opts: Array = []
			for opid in (G.get("players", {}) as Dictionary):
				if int(opid) == player_id or bool((G["players"][opid] as Dictionary).get("eliminated", false)):
					continue # HeroInScorekeep : GetOpponents (sans les elimines)
				var souls: Array = (G["players"][opid] as Dictionary).get("souls", [])
				for i in souls.size():
					var e: Dictionary = souls[i]
					if not bool(e.get("epic", false)):
						opts.append({"card": e.get("hero", e), "fromPid": int(opid), "soulIndex": i,
							"label": "%s (player %d)" % [str(e.get("name", "?")), int(opid) + 1]})
			if opts.is_empty():
				return null
			if opts.size() == 1: # ComposedTargetProvider.TryToAutoresolve : un seul adversaire, un seul heros = pris d'office
				var o1: Dictionary = opts[0]
				var entry: Dictionary = ((G["players"][int(o1["fromPid"])] as Dictionary)["souls"] as Array).pop_at(int(o1["soulIndex"]))
				entry["faceDown"] = true
				(p["souls"] as Array).append(entry)
				_log(G, "Kaw'nee: %s joins player %d's scorekeeping area." % [str(entry.get("name", "?")), player_id])
				return null
			return {"type": "steal-hero", "playerId": player_id, "optional": bool(lu.get("canAvoid", false)),
				"bossName": "Kaw'nee", "message": "Kaw'nee: choose an ordinary Hero in an opponent's scorekeeping area", "options": opts}
		"RearrangeDungeon": # KSA002 Hellcow : n'importe quel donjon, ordre des salles (toutes) au choix
			return rearrange_choice(G, player_id, -1, [])
		"CopyLevelUp": # CRL002 Klonos
			return _klonos(G, player_id)
		"UncoverOpponentRoom": # CRL003 Mando
			return _mando(G, player_id)
		# CRL001 Imperiatrix (RoomsDamagePerTreasure) : passif, lu par BossEngine.room_damage_with_modifiers.
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
	# data.json : CanAvoid = false -> un HUMAIN ne peut pas passer (ShowCardSelector(canBeCanceled = false), TargetResolverBaseSceneBehavior.cs:180-210). Seule l'IA de
	# l'APK abandonne (liste vide -> Cancel(), AbilityTransaction.cs:187-195) : `aiCancel` ouvre le « passer » aux sieges IA et au harnais d'oracle (Match.legal_moves).
	return {"type": "pick-hero", "aiCancel": true, "playerId": player_id, "bossName": "Seducia",
		"message": "Seducia: choose a Hero", "options": options}

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


# --- Crash Landing (CRL) : regle « uncover », salles, capacite de main et level-ups ---
# Hors APK : references = rules.md (section Crash Landing), texte des cartes (wiki), puis le JS (roomAbilities.js / expansionBosses.js).
# Regle « uncover » : une salle est decouverte quand celle qui la couvrait est detruite (BossEngine.destroy_room) ou remontee au sommet de sa pile.

## Un choix cree par une carte CRL reprend la phase BUILD seulement pendant la revelation de fin de BUILD (Match._reveal_and_level_up).
static func _resume(G: Dictionary) -> bool:
	return G.has("revealQueue")

static func _hand_advanced(p: Dictionary) -> Array:
	var out: Array = []
	var hand: Array = p.get("hand", []) as Array
	for i in hand.size():
		if bool((hand[i] as Dictionary).get("isRoom", false)) and bool((hand[i] as Dictionary).get("advanced", false)):
			out.append(i)
	return out

## Salles dont l'effet « when you build this Room » existe dans le moteur (+ drapeaux data `onBuild*`) : cibles de The Omega 42.
static func has_build_effect(room: Dictionary) -> bool:
	if ["BMA011", "BMA022", "BMA033", "BMA034", "BMA036", "BMA037", "CRL004", "CRL006", "CRL010"].has(str(room.get("id", ""))):
		return true
	for k in room.keys():
		if str(k).begins_with("onBuild"):
			return true
	return RmbAbilities.has_build_effect(room)

static func has_uncover_effect(room: Dictionary) -> bool:
	return ["CRL013", "CRL014", "CRL015", "CRL016"].has(str(room.get("id", ""))) or room.has("onUncover") or RmbAbilities.has_uncover_effect(room)

## PV d'un heros +/- delta : le heros actif de l'aventure vit dans adventure.hp, les autres dans leur carte (DealHero -> Hero.Deal).
static func hero_hp_change(G: Dictionary, owner_pid: int, hero: Dictionary, delta: int) -> void:
	var adv: Dictionary = G.get("adventure", {}) as Dictionary
	if not adv.is_empty() and int(adv.get("playerId", -1)) == owner_pid and is_same(adv.get("hero"), hero):
		adv["hp"] = int(adv.get("hp", 0)) + delta
	else:
		hero["hp"] = BossEngine.hero_hp(hero) + delta

## Heros a l'entree du donjon (le heros actif en fait partie : adventure.hero est la meme carte).
static func damage_entrance_hero(G: Dictionary, owner_pid: int, entrance_index: int, amount: int) -> void:
	var entrance: Array = _player(G, owner_pid).get("entrance", []) as Array
	if entrance_index < 0 or entrance_index >= entrance.size():
		return
	var hero: Dictionary = entrance[entrance_index]
	hero_hp_change(G, owner_pid, hero, -amount)
	_log(G, "%d degats a %s." % [amount, str(hero.get("name", "?"))])

## Declencheur « when you uncover this Room » de la salle au sommet de room_index (pile deja mise a jour).
static func on_uncover(G: Dictionary, player_id: int, room_index: int) -> void:
	var p := _player(G, player_id)
	var dungeon: Array = p.get("dungeon", [])
	if room_index < 0 or room_index >= dungeon.size():
		return
	var rv = BossEngine.active_room(dungeon[room_index])
	if rv == null or bool((rv as Dictionary).get("faceDown", false)):
		return
	if BossEngine.abilities_locked(G, player_id) or BossEngine.is_room_deactivated(G, player_id, room_index) or TnlAbilities.no_text(rv as Dictionary):
		return
	var room: Dictionary = rv
	if Minibosses.active(G): # Rise of the Minibosses : « build or uncover » (Monster Academy, Vampire Lab, Dragon's Nest...)
		RmbAbilities.on_uncover(G, player_id, room)
	match str(room.get("id", "")):
		"CRL013": _crash_site(G, p, player_id)
		"CRL014": # Caged Gundarf : degats doubles jusqu'a la fin du tour
			var arr: Array = _effects(G).get("roomDamageBonus", []) as Array
			_effects(G)["roomDamageBonus"] = arr
			# « its damage is doubled » : les degats du moment (imprimes + modificateurs), comme Training Camp / Ravenus (RmbAbilities._room_target « double »)
			arr.append({"playerId": player_id, "roomIndex": room_index, "amount": BossEngine.room_damage_with_modifiers(G, p, room_index, null)})
			_log(G, "Caged Gundarf : degats doubles jusqu'a la fin du tour.")
		"CRL015": # Celestial Map : pioche un sort puis se detruit (la salle du dessous est a son tour decouverte)
			var drawn := _draw_into(G, p, "spells", 1)
			if not drawn.is_empty():
				_log(G, "Celestial Map : pioche %s." % str((drawn[0] as Dictionary).get("name", "?")), "Celestial Map : pioche un sort.", [player_id])
			var destroyed = BossEngine.destroy_room(p, room_index, G)
			BossEngine.discard_room_to_pile(G.get("decks", {}), destroyed)
		"CRL016": # Darkling Lair : 3 degats a un heros du donjon / de l'entree (choix s'il y en a plusieurs)
			var entrance: Array = p.get("entrance", []) as Array
			if entrance.size() == 1:
				damage_entrance_hero(G, player_id, 0, 3)
			elif entrance.size() > 1:
				var opts: Array = []
				for i in entrance.size():
					opts.append({"entranceIndex": i, "card": entrance[i], "label": str((entrance[i] as Dictionary).get("name", "?"))})
				enqueue_pending(G, {"type": "hero-damage", "amount": 3, "resume": _resume(G), "playerId": player_id,
					"bossName": "Darkling Lair", "message": "Darkling Lair: choose a Hero to deal 3 damage to", "options": opts})

## CRL013 Crash Site : cherche une salle avancee dans la defausse (obligatoire, auto s'il n'y en a qu'une).
static func _crash_site(G: Dictionary, p: Dictionary, player_id: int) -> void:
	var opts: Array = discard_card_options(G, "room").filter(func(o): return bool(((o as Dictionary)["card"] as Dictionary).get("advanced", false)))
	if opts.is_empty():
		_log(G, "Crash Site : aucune salle avancee dans la defausse.")
	elif opts.size() == 1:
		var got = take_discard_card(G, p, opts[0])
		if got != null:
			_log(G, "Crash Site : %s recupere." % str((got as Dictionary).get("name", "?")))
	else:
		enqueue_pending(G, {"type": "recover-card", "resume": _resume(G), "playerId": player_id, "bossName": "Crash Site",
			"message": "Crash Site: choose an Advanced Room from the discard pile", "options": opts})

## CRL004 Alien Excavator : (facultatif) remonte une salle couverte de son donjon au sommet de sa pile.
static func _alien_excavator(G: Dictionary, player_id: int) -> Variant:
	var opts := covered_options(G, player_id)
	if opts.is_empty():
		_log(G, "Alien Excavator : aucune salle couverte.")
		return null
	return {"type": "uncover-own-room", "optional": true, "playerId": player_id, "bossName": "Alien Excavator",
		"message": "Alien Excavator: you may uncover a covered Room", "options": opts}

## Salles couvertes (toute la pile sous le sommet) du donjon d'un joueur.
static func covered_options(G: Dictionary, pid: int) -> Array:
	var out: Array = []
	var dungeon: Array = _player(G, pid).get("dungeon", []) as Array
	for i in dungeon.size():
		var stack: Array = dungeon[i]
		for d in range(stack.size() - 1):
			out.append({"targetPlayerId": pid, "roomIndex": i, "depth": d, "card": stack[d],
				"label": "%s (slot %d)" % [str((stack[d] as Dictionary).get("name", "?")), i + 1]})
	return out

## Remonte la salle couverte designee au sommet de sa pile : elle est decouverte (declencheur « uncover »).
static func uncover_move_to_top(G: Dictionary, owner_pid: int, option: Dictionary) -> void:
	var dungeon: Array = _player(G, owner_pid).get("dungeon", []) as Array
	var ri := int(option.get("roomIndex", -1))
	var depth := int(option.get("depth", -1))
	if ri < 0 or ri >= dungeon.size():
		return
	var stack: Array = dungeon[ri]
	if depth < 0 or depth >= stack.size() - 1 or str((stack[depth] as Dictionary).get("id", "")) != str(((option.get("card", {}) as Dictionary)).get("id", "")):
		return
	var card: Dictionary = stack.pop_at(depth)
	stack.append(card)
	_log(G, "%s est decouverte." % str(card.get("name", "?")))
	on_uncover(G, owner_pid, ri)

## Capacite de main CRL007 Frostman Lander : salles avancees ciblables (n'importe quel donjon) pour la desactiver jusqu'a la fin du tour.
static func hand_room_targets(G: Dictionary, hand_index: int, pid: int) -> Array:
	var out: Array = []
	var hand: Array = _player(G, pid).get("hand", []) as Array
	if hand_index < 0 or hand_index >= hand.size() or str((hand[hand_index] as Dictionary).get("id", "")) != "CRL007":
		return out
	for opid in (G.get("players", {}) as Dictionary):
		var op: Dictionary = G["players"][opid]
		if op.get("eliminated", false):
			continue
		for i in (op.get("dungeon", []) as Array).size():
			var r = SpellTargeting._targetable_top(G, int(opid), i, (op["dungeon"] as Array)[i])
			if r != null and bool((r as Dictionary).get("advanced", false)):
				out.append({"targetPlayerId": int(opid), "roomIndex": i})
	return out

static func use_hand_room(G: Dictionary, pid: int, hand_index: int, target: Dictionary) -> void:
	var p := _player(G, pid)
	var hand: Array = p.get("hand", []) as Array
	var card: Dictionary = hand.pop_at(hand_index)
	p["hand"] = hand
	BossEngine.discard_room_to_pile(G.get("decks", {}), card)
	var arr: Array = _effects(G).get("deactivatedRooms", []) as Array
	_effects(G)["deactivatedRooms"] = arr
	arr.append({"playerId": int(target.get("targetPlayerId", pid)), "roomIndex": int(target.get("roomIndex", 0))})
	_log(G, "Frostman Lander : une salle avancee est desactivee jusqu'a la fin du tour.")

## CRL012 The Omega 42 : (une fois par tour) defausse une salle avancee de la main pour rejouer l'effet « build » ou « uncover » d'une salle du donjon.
static func _omega_42(G: Dictionary, p: Dictionary, player_id: int, room: Dictionary) -> Variant:
	var targets: Array = []
	var dungeon: Array = p.get("dungeon", []) as Array
	for i in dungeon.size():
		var rv = BossEngine.active_room(dungeon[i])
		if rv == null or bool((rv as Dictionary).get("faceDown", false)) or BossEngine.is_room_deactivated(G, player_id, i):
			continue
		var rd: Dictionary = rv
		if has_build_effect(rd):
			targets.append({"roomIndex": i, "mode": "build", "card": rd, "label": "%s (build)" % str(rd.get("name", "?"))})
		if has_uncover_effect(rd):
			targets.append({"roomIndex": i, "mode": "uncover", "card": rd, "label": "%s (uncover)" % str(rd.get("name", "?"))})
	if _hand_advanced(p).is_empty():
		room["usedThisTurn"] = false
		return "no Advanced Room to discard"
	if targets.is_empty():
		room["usedThisTurn"] = false
		return "no Room effect to activate"
	if targets.size() == 1:
		var nxt = omega_pick(G, player_id, targets[0])
		if nxt != null:
			enqueue_pending(G, nxt)
		return null
	G["pendingChoice"] = {"type": "omega-refire", "resume": false, "playerId": player_id, "bossName": "The Omega 42",
		"message": "The Omega 42: choose a Room effect to activate", "options": targets}
	return null

## 2e etape d'Omega : la carte avancee a defausser (auto s'il n'y en a qu'une). Renvoie un choix, ou null une fois l'effet rejoue.
static func omega_pick(G: Dictionary, player_id: int, option: Dictionary) -> Variant:
	var p := _player(G, player_id)
	var cands := _hand_advanced(p)
	if cands.is_empty():
		return null
	if cands.size() == 1:
		omega_finish(G, player_id, option, int(cands[0]))
		return null
	var opts: Array = []
	for i in cands:
		opts.append({"card": (p["hand"] as Array)[i], "handIndex": int(i)})
	return {"type": "omega-discard", "resume": false, "playerId": player_id, "bossName": "The Omega 42", "omega": option,
		"message": "The Omega 42: choose an Advanced Room to discard", "options": opts}

static func omega_finish(G: Dictionary, player_id: int, option: Dictionary, hand_index: int) -> void:
	var p := _player(G, player_id)
	var hand: Array = p.get("hand", []) as Array
	if hand_index < 0 or hand_index >= hand.size() or not bool((hand[hand_index] as Dictionary).get("advanced", false)):
		return
	var dungeon: Array = p.get("dungeon", []) as Array
	var ri := int(option.get("roomIndex", -1))
	var room = BossEngine.active_room(dungeon[ri]) if ri >= 0 and ri < dungeon.size() else null
	if room == null:
		return
	var discarded: Dictionary = hand.pop_at(hand_index)
	p["hand"] = hand
	BossEngine.discard_room_to_pile(G.get("decks", {}), discarded)
	_log(G, "The Omega 42 : %s defausse, effet de %s rejoue." % [str(discarded.get("name", "?")), str((room as Dictionary).get("name", "?"))])
	if str(option.get("mode", "build")) == "build":
		G["rmbReplay"] = true # Rise of the Minibosses : on rejoue l'effet de la salle, pas les boss (Lamia, Dr. Deadly)
		var ch = on_build_room(G, player_id, room as Dictionary)
		G.erase("rmbReplay")
		if ch != null:
			(ch as Dictionary)["resume"] = false
			enqueue_pending(G, ch)
	else:
		on_uncover(G, player_id, ri)

## CRL002 Klonos : copie le level-up d'un AUTRE boss en jeu (choix s'il y en a plusieurs). Les level-ups passifs copies restent toute la partie
## (`copiedLevelUps`, lus par BossEngine.level_ups) ; l'effet s'execute aussi tout de suite (process_level_up avec boss_override).
static func _klonos(G: Dictionary, player_id: int) -> Variant:
	var opts: Array = []
	for opid in (G.get("players", {}) as Dictionary):
		var op: Dictionary = G["players"][opid]
		if int(opid) == player_id or op.get("eliminated", false) or not (op.get("boss") is Dictionary) or str((op["boss"] as Dictionary).get("id", "")) == "CRL002":
			continue
		opts.append({"card": op["boss"], "targetPlayerId": int(opid), "label": str((op["boss"] as Dictionary).get("name", "?"))})
	if opts.is_empty():
		_log(G, "Klonos : aucun boss a copier.")
		return null
	if opts.size() == 1:
		return copy_level_up(G, player_id, (opts[0] as Dictionary)["card"])
	return {"type": "pick-boss-levelup", "playerId": player_id, "bossName": "Klonos",
		"message": "Klonos: choose a Boss to copy its Level Up ability", "options": opts}

static func copy_level_up(G: Dictionary, player_id: int, boss: Dictionary) -> Variant:
	var p := _player(G, player_id)
	var lu = boss.get("levelUp")
	if lu is Dictionary:
		var copied: Array = p.get("copiedLevelUps", []) as Array
		p["copiedLevelUps"] = copied
		copied.append((lu as Dictionary).duplicate(true))
	_log(G, "Klonos copie le level-up de %s." % str(boss.get("name", "?")))
	return process_level_up(G, player_id, boss)

## CRL003 Mando : pour CHAQUE adversaire (PlayerId croissant), on peut remonter une de ses salles couvertes au sommet de sa pile.
static func _mando(G: Dictionary, player_id: int) -> Variant:
	var victims: Array = []
	for opid in (G.get("players", {}) as Dictionary):
		if int(opid) != player_id and not bool(G["players"][opid].get("eliminated", false)):
			victims.append(int(opid))
	victims.sort()
	G["mandoQueue"] = {"owner": player_id, "queue": victims}
	return mando_advance(G)

## Prochain adversaire ayant une salle couverte (les autres sont sautes), ou null quand la file est vide.
static func mando_advance(G: Dictionary) -> Variant:
	var st: Dictionary = G.get("mandoQueue", {}) as Dictionary
	var queue: Array = st.get("queue", []) as Array
	while not queue.is_empty():
		var opts := covered_options(G, int(queue.pop_front()))
		if not opts.is_empty():
			return {"type": "uncover-room", "optional": true, "resume": _resume(G), "playerId": int(st.get("owner", 0)), "bossName": "Mando",
				"message": "Mando: you may bring a covered Room to the top of its stack", "options": opts}
	G.erase("mandoQueue")
	return null


## PV courants d'un heros d'un donjon (le heros actif de l'aventure : adventure.hp ; les autres : leur carte).
static func current_hero_hp(G: Dictionary, owner_pid: int, hero: Dictionary) -> int:
	var adv: Dictionary = G.get("adventure", {}) as Dictionary
	if not adv.is_empty() and int(adv.get("playerId", -1)) == owner_pid and is_same(adv.get("hero"), hero):
		return int(adv.get("hp", 0))
	return BossEngine.hero_hp(hero)
