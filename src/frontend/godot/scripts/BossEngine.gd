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

static func dungeon_treasures(player: Dictionary, G: Dictionary = {}) -> Array:
	var out: Array = []
	if player.get("boss") == null:
		return out
	for t in (player["boss"] as Dictionary).get("treasures", []):
		out.append(int(t))
	# Boss.GetDungeonTreasures : TreasuresMultiplier (Jackpot Stash, MultiplyTreasuresDungeon) ne s'applique
	# qu'aux tresors des salles, pas a ceux du boss.
	var mult := 2 if (_effects(G).get("treasureDoubled", []) as Array).has(int(player.get("id", -1))) else 1
	for stack in player.get("dungeon", []):
		var room = active_room(stack)
		if room == null:
			continue
		for t in (room as Dictionary).get("treasures", []):
			for _i in mult:
				out.append(int(t))
	# CalculatePassiveTreasures : level-up AddTreasuresToDungeon (KSA001 Kirax) une fois monte de niveau.
	var lu = (player["boss"] as Dictionary).get("levelUp")
	if bool(player.get("leveledUp", false)) and lu is Dictionary and str((lu as Dictionary).get("cmd", "")) == "AddTreasuresToDungeon":
		for a in (lu as Dictionary).get("args", []):
			out.append(int(CardDB.TREASURE_NAMES.find(str(a))))
	return out

static func treasure_count(player: Dictionary, treasure: int, G: Dictionary = {}) -> int:
	var n := 0
	for t in dungeon_treasures(player, G):
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
			# Salle ordinaire : en fin de donjon, ou PAR-DESSUS une pile existante (DungeonSlot.CheckRoomCanBeBuilt : pas de slot
			# en attente de revelation ; BMA018 Neanderthal Cave = CannotBuildRoom[Advanced, Any] : elle ne refuse QUE les avancees).
			if target_index < 0:
				return visible < CardDB.DUNGEON_SLOTS
			if target_index >= dungeon.size():
				return false
			var over = active_room(dungeon[target_index])
			return over != null and not bool((over as Dictionary).get("faceDown", false))
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

## Lure APK (BaseLuredCondition.GetBoss) : un seul joueur vivant doit remporter le critere, sinon le heros
## reste en ville (retour -1). LuredByTreasures : max du tresor du heros ; The Fool (BMA080, LuredByFewerSouls) :
## min d'ames (CardDB.total_souls).
static func lure_target(players: Dictionary, order: Array, treasure: int, hero: Dictionary = {}, G: Dictionary = {}) -> int:
	# BaseLuredCondition par type de condition (HeroInfo.LuredCondition), pas par id : BMH0xx = BMA0xx, KSA014 = LuredByWounds.
	var lure := CardDB.hero_lure(hero)
	var htr: Array = CardDB.hero_treasures(hero) if hero.has("treasures") else [treasure]
	var best := -1
	var best_n := -999999
	var tied := false
	for pid in order:
		var p: Dictionary = players[pid]
		if p.get("eliminated", false):
			continue
		var n := 0
		match lure:
			"fewerSouls": # LuredByFewerSouls : min Souls
				n = -CardDB.total_souls(p, G if G.has("players") else {"players": players})
			"wounds": # LuredByWounds : min Wounds
				n = -CardDB.total_wounds(p)
			_: # LuredByTreasures : somme, sur les tresors du heros, des tresors du donjon (heros a deux classes : Monster Hunter...)
				for t in htr:
					n += treasure_count(p, int(t), G)
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

static func hero_hp(hero: Dictionary) -> int:
	return int(hero.get("hp", hero.get("health", 4)))

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

## Heros vivants du scorekeeping (une entree par heros, ordre d'arrivee) : cibles de HeroInScorekeep[Owner, Alive] (Boss.WoundsHeroes).
static func wound_heroes(player: Dictionary) -> Array:
	var out: Array = []
	for w in player.get("wounds", []):
		var h = (w as Dictionary).get("hero")
		if h is Dictionary and not out.has(h):
			out.append(h)
	return out

## Retourne une blessure et rend l'ame correspondante face cachee. FlipHero deplace le HEROS entier de WoundsHeroes vers
## SoulsHeroes (un epique : toutes ses blessures, toutes ses ames) ; `hero` = celui choisi, sinon la derniere blessure.
## Entrees sans identite de heros (etats synthetiques) : une seule blessure, une seule ame.
static func heal_one_wound(player: Dictionary, hero = null):
	var wounds: Array = player.get("wounds", [])
	if wounds.is_empty():
		return null
	if not player.has("souls"):
		player["souls"] = []
	var souls: Array = player["souls"]
	if hero == null:
		hero = (wounds[wounds.size() - 1] as Dictionary).get("hero")
	if not (hero is Dictionary):
		var w: Dictionary = wounds.pop_back()
		var soul := {"souls": int(w.get("souls", 1)), "name": w.get("name", ""), "class": w.get("class", ""), "faceDown": true}
		souls.append(soul)
		return soul
	var last = null
	for i in range(wounds.size() - 1, -1, -1):
		if (wounds[i] as Dictionary).get("hero") == hero:
			wounds.remove_at(i)
	for _k in hero_souls(hero):
		last = {"souls": 1, "name": hero.get("name", ""), "class": hero.get("class", ""), "faceDown": true, "hero": hero}
		souls.append(last)
	return last

# --- engine.js: isRoomDeactivated / isBuildBlocked ---

static func is_room_deactivated(G: Dictionary, player_id: int, room_index: int) -> bool:
	for e in _effects(G).get("deactivatedRooms", []):
		var d: Dictionary = e
		if int(d.get("playerId", -1)) == int(player_id) and int(d.get("roomIndex", -1)) == room_index:
			return true
	return false

## KSA017 Trap Master (ThisHeroEntersDungeon -> DeactivateDungeonAbility) : tant que ce heros est dans le donjon de `player_id`,
## toutes les capacites de ses salles actives sont verrouillees ; GameBoard.RemoveHeroFromGame les deverrouille (UndoEffect).
static func abilities_locked(G: Dictionary, player_id: int) -> bool:
	var adv = G.get("adventure")
	if not (adv is Dictionary) or (adv as Dictionary).is_empty() or int((adv as Dictionary).get("playerId", -1)) != int(player_id):
		return false
	var ha = ((adv as Dictionary).get("hero", {}) as Dictionary).get("heroAbility")
	return ha is Dictionary and str((ha as Dictionary).get("cmd", "")) == "DeactivateDungeonAbility"

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

	# Freeze (DeactivateRoom) : DungeonSlot.IsActive=false -> aucun degat au heros (GameBoard.cs ~1135)
	if is_room_deactivated(G, pid, room_index):
		return 0

	# KSA017 Trap Master : DeactivateDungeonAbility verrouille Ability.IsLocked de chaque salle (CheckConditions faux) :
	# ni capacite, ni declencheur, ni bonus de degats passif (Boss.GetPassiveDamage) tant que le heros est dans le donjon.
	var locked := abilities_locked(G, pid)

	# BMA020 Monster's Ballroom : degats = nombre de salles Monster actives
	if str(r.get("id", "")) == "BMA020" and not locked:
		var n := 0
		for x in all_active_rooms(dungeon):
			if x != null and str((x as Dictionary).get("type", "")) == "monster":
				n += 1
		dmg = n

	# BMA015 Goblin Armory : +1 aux salles Monster adjacentes (AdjacentsRoom[Monster] + DealDamageToRoom 1)
	# BMA029 Dizzygas Hallway : +2 a la salle Trap suivante (NextRoom[Trap] + DealDamageToRoom 2)
	# Le type filtre est celui de la salle CIBLE (r), pas celui de la salle source.
	var rt := str(r.get("type", ""))
	for i in dungeon.size():
		if i == room_index:
			continue
		var other = active_room(dungeon[i])
		if other == null:
			continue
		var o: Dictionary = other
		if is_room_deactivated(G, pid, i):  # AdjacentsRoom/NextRoom ignorent les slots inactifs
			continue
		if locked:
			continue
		if str(o.get("id", "")) == "BMA015" and absi(i - room_index) == 1 and rt == "monster":
			dmg += 1
		if str(o.get("id", "")) == "BMA029" and i == room_index - 1 and rt == "trap":
			dmg += 2

	# Room.Damage = InitialDamage + DealDamage (sorts Annihilator / Giant Size, portes par la carte)
	dmg += int(r.get("dealDamage", 0))
	# Bonus de degats poses par les sorts/effets
	for e in _effects(G).get("roomDamageBonus", []):
		var ed: Dictionary = e
		if int(ed.get("playerId", -1)) == pid and int(ed.get("roomIndex", -1)) == room_index:
			dmg += int(ed.get("amount", 0))

	# BMA049 Skip Build / BMA043 : degats des salles ordinaires +1
	for id in _effects(G).get("ordinaryMonsterBonus", []):
		if int(id) == pid and str(r.get("type", "")) == "monster" and not bool(r.get("advanced", false)):
			dmg += 1

	# Boss.GetPassiveDamage : level-up LastRoomDealDamage (KSA005 Scythe) = +N a la salle du fond (Dungeon.First(), index Godot dernier).
	var lu = (player.get("boss", {}) as Dictionary).get("levelUp")
	if bool(player.get("leveledUp", false)) and lu is Dictionary and str((lu as Dictionary).get("cmd", "")) == "LastRoomDealDamage" \
			and room_index == dungeon.size() - 1:
		dmg += int(((lu as Dictionary).get("args", ["0"]) as Array)[0])

	# GameBoard.ProccessActiveHero : Hero.Ability.GetPassiveDamageCommand ; HeroResistDamageRoomType (KSA016 Monster Hunter) rend N PV
	# si le slot inflige des degats et que la salle est du type : degats totaux - N.
	var ha = (hero as Dictionary).get("heroAbility") if hero is Dictionary else null
	if ha is Dictionary and str((ha as Dictionary).get("cmd", "")) == "HeroResistDamageRoomType" and dmg != 0 \
			and str(r.get("type", "")) == str(((ha as Dictionary).get("args", ["0", ""]) as Array)[1]).to_lower():
		dmg -= int(((ha as Dictionary)["args"] as Array)[0])

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
## G (optionnel) : decale les effets indexes par slot (Freeze, bonus de degats) quand l'emplacement disparait.
## triggers=false : ChooseAndDestroyRoom (Robobo) = DestroyRoom(checkTriggers:false), pas de WhenAnotherRoomIsDestroyed.
static func destroy_room(player: Dictionary, room_index: int, G: Dictionary = {}, triggers := true):
	var dungeon: Array = player.get("dungeon", [])
	if room_index < 0 or room_index >= dungeon.size():
		return null
	var stack: Array = dungeon[room_index]
	if stack.is_empty():
		return null
	var destroyed: Dictionary = stack.pop_back()
	if stack.is_empty():
		dungeon.remove_at(room_index)
		# GameBoard.DestroyRoom : Dungeon.Remove + Add, les slots suivants se tassent ; les effets indexes suivent leur slot.
		var pid := int(player.get("id", 0))
		for key in ["deactivatedRooms", "roomDamageBonus"]:
			var arr: Array = _effects(G).get(key, [])
			for k in range(arr.size() - 1, -1, -1):
				var e: Dictionary = arr[k]
				if int(e.get("playerId", -1)) != pid:
					continue
				if int(e.get("roomIndex", -1)) == room_index:
					arr.remove_at(k)
				elif int(e.get("roomIndex", -1)) > room_index:
					e["roomIndex"] = int(e["roomIndex"]) - 1
		# Heros present dans ce donjon : il garde lastActiveHeroSlotIndex (GameBoard.ProccessActiveHero). Slot detruit
		# DEVANT lui (plus pres du boss = index Godot plus grand) : son index C# baisse de 1, last != num, donc pas de
		# num-- : il RESUBIT sa salle courante (adv.replay). Slot DERRIERE lui : l'index Godot de sa salle baisse de 1.
		var adv: Dictionary = G.get("adventure", {}) as Dictionary
		var h := int(adv.get("roomIndex", -1))
		if not adv.is_empty() and int(adv.get("playerId", -1)) == pid and h >= 0:
			if room_index > h:
				adv["replay"] = true
			elif room_index < h:
				adv["roomIndex"] = h - 1
			else:
				adv["roomGone"] = true # le slot du heros disparait : sa mort n'a plus de salle (InsideDungeonSlot.TopRoom == null)
				if int(adv.get("hp", 0)) > 0:
					# GameBoard.DestroyRoom : le slot passe en fin de liste (Dungeon.Remove + Add, 5 slots fixes), le heros le suit
					# (InsideDungeonSlot) : il traverse les emplacements vides (5 - taille restante, 1 pas chacun) puis repart de
					# l'entree (index C# decroissant) ; voir Match._advance_adventure_room (i < 0 = emplacement vide).
					adv["roomIndex"] = -(5 - dungeon.size()) - 1
	if triggers and not G.is_empty():
		_on_other_room_destroyed(G, player)
	return destroyed

## GameBoard.DestroyRoom -> CheckTriggerInDungeon<WhenAnotherRoomIsDestroyed> : chaque BMA031 Recycling Center
## actif du donjon (la salle detruite n'y est plus) fait piocher 2 salles a son proprietaire (DrawCards 2 Room).
static func _on_other_room_destroyed(G: Dictionary, player: Dictionary) -> void:
	var dungeon: Array = player.get("dungeon", [])
	var deck: Array = (G.get("decks", {}) as Dictionary).get("rooms", []) as Array
	for i in dungeon.size():
		var top = active_room(dungeon[i])
		if top == null or bool((top as Dictionary).get("faceDown", false)) or str((top as Dictionary).get("id", "")) != "BMA031":
			continue
		if is_room_deactivated(G, int(player.get("id", -1)), i):
			continue
		for _k in 2:
			if not deck.is_empty():
				(player.get("hand", []) as Array).append(deck.pop_back())

static func discard_room_to_pile(decks: Dictionary, card) -> void:
	if card == null:
		return
	(card as Dictionary).erase("usedThisTurn") # une salle recuperee puis reconstruite repart avec une capacite neuve
	var pile: Array = decks.get("roomDiscard", [])
	decks["roomDiscard"] = pile
	pile.append(card)
