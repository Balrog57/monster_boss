class_name BossEngine
extends RefCounted
## Regles du moteur, stateless sur des Dictionnaires (reference : le C# de l'APK).
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

## Boss.DungeonSize (Boss.cs:135) : dernier emplacement C# non vide et sans salle en attente (face cachee), + 1. Le donjon Godot est range a l'envers
## (index C# = taille - 1 - index Godot) : le plus petit index Godot valide est donc le dernier emplacement C#.
static func apk_dungeon_size(dungeon: Array) -> int:
	for g in dungeon.size():
		var r = active_room(dungeon[g])
		if r != null and not bool((r as Dictionary).get("faceDown", false)):
			return dungeon.size() - g
	return 0

## Condition OpponnentDungeonSizeMoreThan(n) (Conditions/OpponnentDungeonSizeMoreThan.cs) : un adversaire en vie (GetOpponents) a au moins `n` salles
## (DungeonSize) de plus que `pid`.
static func opponent_dungeon_larger(G: Dictionary, pid: int, n: int) -> bool:
	var players: Dictionary = G.get("players", {})
	var mine := apk_dungeon_size((players.get(pid, players.get(str(pid), {})) as Dictionary).get("dungeon", []))
	for opid in players:
		var op: Dictionary = players[opid]
		if int(opid) != pid and not bool(op.get("eliminated", false)) and apk_dungeon_size(op.get("dungeon", [])) - mine >= n:
			return true
	return false

## Cible AnotherRoom (Targets/AnotherRoom.cs) : emplacement C# d'index < DungeonSize, actif (non gele), autre que celui de la salle. Une salle en attente
## AU MILIEU du donjon (avancee posee ce tour sur un emplacement ancien) compte : le C# fait Peek() sans regarder PendingToBeBuilt.
static func is_another_room_target(G: Dictionary, pid: int, dungeon: Array, room_index: int, other: int) -> bool:
	return other != room_index and other >= dungeon.size() - apk_dungeon_size(dungeon) and other < dungeon.size() 		and active_room(dungeon[other]) != null and not is_room_deactivated(G, pid, other)

## Tresors d'une salle : imprimes + gagnes « jusqu'a la fin du tour » (CRL006 Decoy Garden, CRL032 Meteorite : `extraTreasures`).
static func room_treasures(room: Dictionary) -> Array:
	var out: Array = []
	# TNL045 Decapitator : tresor imprime retire jusqu'a la fin du tour (les tresors ajoutes apres, Secret Stash, restent).
	var tag: Dictionary = room.get("tnl", {}) as Dictionary
	var printed: Array = [] if bool(tag.get("noTreasure", false)) else ([1, 2, 3, 4] if bool(tag.get("allTreasures", false)) else (room.get("treasures", []) as Array)) # RMB067 Spirit Dragon : un de chaque type
	for t in printed + (room.get("extraTreasures", []) as Array):
		out.append(int(t)) # JSON donne 3.0 ; Array.has(3) ne compare pas int a float
	if room.has("mb"): # Rise of the Minibosses : icones du miniboss de la salle (niveau 1 ; Jinx niveau 2 : une copie de chaque icone)
		out.append_array(Minibosses.mb_treasures(room, out))
	return out

static func dungeon_treasures(player: Dictionary, G: Dictionary = {}) -> Array:
	var out: Array = []
	if player.get("boss") == null:
		return out
	for t in (player["boss"] as Dictionary).get("treasures", []):
		out.append(int(t))
	for t in (player.get("bonusTreasures", []) as Array): # TNL000 Mirrax : icones copiees d'un autre boss, pour la partie
		out.append(int(t))
	# Boss.GetDungeonTreasures : TreasuresMultiplier (Jackpot Stash, MultiplyTreasuresDungeon) ne s'applique
	# qu'aux tresors des salles, pas a ceux du boss.
	var mult := 2 if (_effects(G).get("treasureDoubled", []) as Array).has(int(player.get("id", -1))) else 1
	var pid_t := int(player.get("id", -1))
	var dun_t: Array = player.get("dungeon", [])
	for i in dun_t.size():
		var room = active_room(dun_t[i])
		# Boss.GetDungeonTreasures (Boss.cs:254) : slot actif et non en attente (face cachee) seulement ; une salle gelee ne donne aucun tresor.
		if room == null or bool((room as Dictionary).get("faceDown", false)) or (not G.is_empty() and is_room_deactivated(G, pid_t, i)):
			continue
		for t in room_treasures(room as Dictionary):
			for _i in mult:
				out.append(int(t))
	if not G.is_empty() and Minibosses.active(G): # RMB012 Kirax / RMB045 Endless Gallery : un tresor de plus jusqu'a la fin du tour
		out.append_array(Minibosses.extra_icons(G, int(player.get("id", -1))))
	# CalculatePassiveTreasures : level-up AddTreasuresToDungeon (KSA001 Kirax) une fois monte de niveau.
	for lu in level_ups(player):
		if str((lu as Dictionary).get("cmd", "")) == "AddTreasuresToDungeon":
			for a in (lu as Dictionary).get("args", []):
				out.append(int(CardDB.TREASURE_NAMES.find(str(a))))
	return out

## Level-ups actifs d'un boss monte de niveau : le sien + ceux copies par Klonos (CRL002 : `copiedLevelUps`, conserves pour toute la partie).
static func level_ups(player: Dictionary) -> Array:
	var out: Array = []
	if not bool(player.get("leveledUp", false)) or not (player.get("boss") is Dictionary):
		return out
	var lu = (player["boss"] as Dictionary).get("levelUp")
	if lu is Dictionary:
		out.append(lu)
	out.append_array(player.get("copiedLevelUps", []) as Array)
	return out

static func treasure_count(player: Dictionary, treasure: int, G: Dictionary = {}) -> int:
	if not G.is_empty() and ThkAbilities.active(G) and IodAbilities.icons_ignored(G, int(player.get("id", -1)), treasure):
		return 0 # IOD014 Super Magnet (Reward) : les heros ignorent ces icones jusqu'a la fin du tour
	var n := 0
	for t in dungeon_treasures(player, G):
		if int(t) == treasure:
			n += 1
	return n

static func treasure_counts(player: Dictionary, G: Dictionary = {}) -> Dictionary:
	return {
		1: treasure_count(player, 1, G),
		2: treasure_count(player, 2, G),
		3: treasure_count(player, 3, G),
		4: treasure_count(player, 4, G),
		5: treasure_count(player, 5, G),
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
		if not bool(card.get("isRoom", false)) or bool(card.get("isMiniboss", false)): # un miniboss n'est pas une salle (Minibosses.apply_build)
			return false
		if is_build_blocked(G):
			return false
		if not G.is_empty() and ThkAbilities.active(G) and IodAbilities.blueprints_block(G, card):
			return false # IOD018 Stolen Blueprints (Power-Up) : aucune salle a l'icone du heros arrive en ville ce tour
		if pid >= 0 and no_entry(pid, G):
			return false
		var allowed := 1 + (extra_builds_for(G, pid) if pid >= 0 else 0)
		if int(player.get("buildsThisTurn", 0)) >= allowed:
			return false
		var visible := count_visible_rooms(dungeon)
		if not G.is_empty() and Minibosses.active(G) and RmbAbilities.fetid_blocks(dungeon, card, target_index):
			return false # RMB025 Fetid Beast : pas de salle Monster a cote
		if not bool(card.get("advanced", false)):
			# Salle ordinaire : en fin de donjon, ou PAR-DESSUS une pile existante (DungeonSlot.CheckRoomCanBeBuilt : pas de slot
			# en attente de revelation ; BMA018 Neanderthal Cave = CannotBuildRoom[Advanced, Any] : elle ne refuse QUE les avancees).
			if target_index < 0 or target_index >= dungeon.size(): # emplacement vide / nouveau = fin de donjon
				return visible < CardDB.DUNGEON_SLOTS
			var over = active_room(dungeon[target_index])
			return over != null and not bool((over as Dictionary).get("faceDown", false))
		# Salle avancee : doit se batir sur une salle active au tresor correspondant.
		if dungeon.is_empty():
			return false
		var idx := target_index if target_index >= 0 else dungeon.size() - 1
		if idx < 0 or idx >= dungeon.size():
			return false
		var target = active_room(dungeon[idx])
		if target == null or bool((target as Dictionary).get("faceDown", false)): # DungeonSlot.CheckRoomCanBeBuilt (l.84) : jamais par-dessus un slot en attente (salle posee ce tour)
			return false
		# BMA018 Neanderthal Cave : on ne peut pas batir par-dessus.
		if str((target as Dictionary).get("id", "")) == "BMA018" and not TnlAbilities.no_text(target as Dictionary): # Meddling Kids! : plus de texte, plus d'interdiction
			return false
		# CRL011 Hypercube : se batit sur n'importe quelle salle, quel que soit le tresor.
		if str(card.get("id", "")) == "CRL011":
			return true
		if not G.is_empty() and Minibosses.active(G) and (Minibosses.rocky_host(target) or (_effects(G).get("ignoreTreasureMatch", []) as Array).has(pid)):
			return true # RMB058 Rocky niveau 1, RMB074 Zoning Board : sans condition de tresor
		var treasures_match := false
		var host_t := room_treasures(target as Dictionary)
		for t in card.get("treasures", []):
			if host_t.has(int(t)):
				treasures_match = true
				break
		return treasures_match
	return count_visible_rooms(dungeon) < CardDB.DUNGEON_SLOTS

## Lure APK (BaseLuredCondition.GetBoss) : un seul joueur vivant doit remporter le critere, sinon le heros
## reste en ville (retour -1). LuredByTreasures : max du tresor du heros ; The Fool (BMA080, LuredByFewerSouls) :
## min d'ames (CardDB.total_souls).
static func lure_target(players: Dictionary, order: Array, treasure: int, hero: Dictionary = {}, G: Dictionary = {}) -> int:
	var tied := lure_tied(players, order, treasure, hero, G)
	return -1 if tied.size() > 1 else (int(tied[0]) if tied.size() == 1 else -1)

## Joueurs vivants a egalite pour le meilleur critere de leurre de ce heros (ordre de `order`, donc XP decroissante) ; un seul = il l'emporte.
## Sert a lure_target (APK : egalite = le heros reste en ville) et au partage des egalites a 5-6 joueurs (lure_split_targets).
static func lure_tied(players: Dictionary, order: Array, treasure: int, hero: Dictionary = {}, G: Dictionary = {}) -> Array:
	# BaseLuredCondition par type de condition (HeroInfo.LuredCondition), pas par id : BMH0xx = BMA0xx, KSA014 = LuredByWounds.
	var lure := CardDB.hero_lure(hero)
	var htr: Array = CardDB.hero_treasures(hero) if hero.has("treasures") else [treasure]
	if hero.has("iodLure") and int(hero.get("iodLureTurn", -1)) == int(G.get("turn", -2)): # IOD020 Doppelganger Cloak : un seul type de tresor
		htr = [int(hero["iodLure"])]
	if lure == "vote": # CRL028 The King : le joueur le plus vote (G.kingVote : joueur -> cible) ; egalite ou aucun vote = reste en ville
		var tally := {}
		for v in (G.get("kingVote", {}) as Dictionary).values():
			tally[int(v)] = int(tally.get(int(v), 0)) + 1
		var top := 0
		for k in tally:
			top = maxi(top, int(tally[k]))
		var voted: Array = []
		for pid in order:
			if top > 0 and int(tally.get(int(pid), 0)) == top and not bool((players[pid] as Dictionary).get("eliminated", false)):
				voted.append(int(pid))
		return voted
	var best_n := -999999
	var tied: Array = []
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
			"mostCards": # KSA015 Pixel Lincoln (hors APK) : le plus de cartes en main
				n = (p.get("hand", []) as Array).size()
			"soulsMinusWounds": # TNL114 The Brothers (hors APK) : le plus haut total Ames - Blessures
				n = CardDB.total_souls(p, G if G.has("players") else {"players": players}) - CardDB.total_wounds(p)
			"fewestSoulsMinusWounds": # CRL017 The Prince : « fewest total Souls minus Wounds »
				n = CardDB.total_wounds(p) - CardDB.total_souls(p, G if G.has("players") else {"players": players})
			"mostIcons": # RMB121 The Progenitors (paraphrase wiki) : « most treasure icons » = toutes classes confondues
				for t in range(1, 6):
					n += treasure_count(p, t, G)
			_: # LuredByTreasures : somme, sur les tresors du heros, des tresors du donjon (heros a deux classes : Monster Hunter...)
				for t in htr:
					n += treasure_count(p, int(t), G)
		if n > best_n:
			best_n = n
			tied = [int(pid)]
		elif n == best_n:
			tied.append(int(pid))
	return tied

## Livret CRL, « Changes to the Bait Phase » (5-6 joueurs) : ex aequo sur un type de tresor => si la ville compte au moins autant de heros de ce
## type que de joueurs a egalite, on les partage : le plus ancien va au joueur a egalite de plus haute XP, le suivant au suivant, et on recommence
## tant que le reste suffit ; le surplus (les plus recents) reste en ville. Donc floor(H / k) heros chacun. Renvoie {index dans `town`: joueur}
## pour les seuls heros partages (les autres suivent lure_target). Sans tresor du type chez personne (tout le monde a 0), le heros reste en ville.
static func lure_split_targets(players: Dictionary, order: Array, town: Array, G: Dictionary = {}) -> Dictionary:
	var groups := {} # (condition, tresors, joueurs a egalite) -> {"tied": [...], "idx": [indices de ville, du plus ancien au plus recent]}
	for i in town.size():
		var hero: Dictionary = town[i]
		var treasure := int(hero.get("treasure", 1))
		var lure := CardDB.hero_lure(hero)
		if lure == "vote": # le Roi : egalite du vote = reste en ville, jamais partage
			continue
		var tied := lure_tied(players, order, treasure, hero, G)
		if tied.size() < 2:
			continue
		if lure == "treasures": # « if no player has treasure of that Hero's type [...] the Hero stays in town »
			var any := false
			for t in (CardDB.hero_treasures(hero) if hero.has("treasures") else [treasure]):
				any = any or treasure_count(players[tied[0]], int(t), G) > 0
			if not any:
				continue
		var key := "%s|%s|%s" % [lure, str(CardDB.hero_treasures(hero) if hero.has("treasures") else [treasure]), str(tied)]
		if not groups.has(key):
			groups[key] = {"tied": tied, "idx": []}
		(groups[key]["idx"] as Array).append(i)
	var out := {}
	for g in groups.values():
		var tied: Array = g["tied"]
		var idx: Array = g["idx"]
		var lured: int = idx.size() - idx.size() % tied.size()
		for j in lured:
			out[int(idx[j])] = int(tied[j % tied.size()])
	return out

static func hero_souls(hero: Dictionary) -> int:
	return int(hero.get("souls", 1))

static func hero_wounds(hero: Dictionary) -> int:
	return int(hero.get("wounds", 1))

static func hero_hp(hero: Dictionary) -> int:
	return int(hero.get("hp", hero.get("health", 4)))

## PV de la carte (Hero.RestoreHealth : CurrentHealth = MaxHealth) : `hp` d'un exemplaire peut avoir ete modifie (Zombie Attack : +2 PV).
static func hero_base_hp(hero: Dictionary) -> int:
	for c in CardDB.heroes:
		if str((c as Dictionary).get("id", "")) == str(hero.get("id", "")):
			return hero_hp(c)
	return hero_hp(hero)

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
	if Minibosses.active(G) and Minibosses.hero_text_ignored(G, int(player_id)): # RMB061 Icicle Man niveau 2, RMB059 Cerebella niveau 3
		return false
	if ThkAbilities.cheat_code(G, int(player_id)): # THK014 Cheat Code : le texte des salles du donjon est ignore tant que ce heros y est
		return true
	return ha is Dictionary and str((ha as Dictionary).get("cmd", "")) == "DeactivateDungeonAbility"

static func is_build_blocked(G: Dictionary) -> bool:
	return bool(_effects(G).get("buildBlocked", false))

static func no_entry(player_id: int, G: Dictionary) -> bool:
	for id in _effects(G).get("noRoomBuild", []):
		if int(id) == int(player_id):
			return true
	return false

## Boss.MaxBuildRoomLimit : propre au joueur, 1 par defaut. Kobold Strike (SkipBuildPhase) le met a 0 pour tous, Motivation (BuildExtraRoom) l'incremente ;
## seule GameBoard.DeactivateLastActivePlayer (:1215, Match._advance_build) le remet a 1, donc il survit au tour courant des joueurs deja passes.
static func build_limit(G: Dictionary, player_id: int) -> int:
	var players: Dictionary = G.get("players", {}) as Dictionary
	var p = players.get(player_id, players.get(str(player_id), {}))
	return int((p as Dictionary).get("buildLimit", 1))

## Constructions permises EN PLUS de la premiere (-1 : limite 0, aucune construction) ; les appelants testent `buildsThisTurn < 1 + extra_builds_for`.
static func extra_builds_for(G: Dictionary, player_id: int) -> int:
	return build_limit(G, player_id) - 1

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
	var thk := ThkAbilities.active(G) # Objets IOD / cartes KSA wiki : jamais hors de la case wiki
	if thk:
		dmg = IodAbilities.base_damage(G, pid, r, dmg) # IOD004 Tamer's Whip : base 1 pour les salles Monster

	# Freeze (DeactivateRoom) : DungeonSlot.IsActive=false -> aucun degat au heros (GameBoard.cs ~1135)
	if is_room_deactivated(G, pid, room_index):
		return 0
	if (TnlAbilities.active(G) or thk) and TnlAbilities.zero_damage(r): # TNL058 Fairy Fountain : degats a zero, rien ne les releve plus
		return 0

	# KSA017 Trap Master : DeactivateDungeonAbility verrouille Ability.IsLocked de chaque salle (CheckConditions faux) :
	# ni capacite, ni declencheur, ni bonus de degats passif (Boss.GetPassiveDamage) tant que le heros est dans le donjon.
	var locked := abilities_locked(G, pid)
	var flame: bool = thk and IodAbilities.flame(hero)

	# TNL062 Meddling Kids! : « no ability text » (pas le nom, ni les degats imprimes, ni le tresor) -> la salle perd son propre bonus passif
	# (Ballroom, Alien Ooze) et ne donne plus rien aux voisines (Goblin Armory, Dizzygas, Invasion Swarm, Reactor Core).
	var own_off := locked or TnlAbilities.no_text(r)

	# BMA020 Monster's Ballroom : degats = nombre de salles Monster actives
	if str(r.get("id", "")) == "BMA020" and not own_off:
		var n := 0
		var act := all_active_rooms(dungeon)
		for k in act.size():
			var x = act[k]
			if x != null and str((x as Dictionary).get("type", "")) == "monster" and not is_room_deactivated(G, pid, k): # RoomDamageEqualToCount : slot.IsActive
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
		if bool(o.get("faceDown", false)):  # Boss.GetPassiveDamage ne parcourt que DungeonActiveRooms : une salle posee ce tour (PendingToBeBuilt) ne donne rien (IA-H18)
			continue
		if thk and absi(i - room_index) == 1:
			dmg += IodAbilities.mage_adjacent(G, pid, o) # IOD008 Flame of Achoom (Reward) : les salles Mage donnent +1 aux voisines
		if locked or TnlAbilities.no_text(o) or flame:  # IOD008 (Power-Up) : le heros ignore le texte des salles qui modifient les autres salles
			continue
		if str(o.get("id", "")) == "BMA015" and absi(i - room_index) == 1 and rt == "monster":
			dmg += 1
		if str(o.get("id", "")) == "BMA029" and i == room_index - 1 and rt == "trap":
			dmg += 2
		if str(o.get("id", "")) == "CRL008" and absi(i - room_index) == 1: # Invasion Swarm : salles adjacentes +1
			dmg += 1
		if str(o.get("id", "")) == "CRL009" and bool(r.get("advanced", false)): # Reactor Core : salles avancees +1
			dmg += 1

	# CRL005 Alien Ooze : +1 s'il y a une AUTRE salle au tresor Explorer dans le donjon (un boss n'est pas une salle).
	if str(r.get("id", "")) == "CRL005" and not own_off:
		for i in dungeon.size():
			var other_ex = active_room(dungeon[i])
			if i != room_index and other_ex != null and not is_room_deactivated(G, pid, i) and room_treasures(other_ex as Dictionary).has(5):
				dmg += 1
				break

	# Room.Damage = InitialDamage + DealDamage (sorts Annihilator / Giant Size, portes par la carte)
	dmg += int(r.get("dealDamage", 0))
	if thk:
		dmg += PcwAbilities.damage_bonus(G, pid, r, hero, own_off) # KSA009 Shark Tank
		dmg += IodAbilities.under_bonus(r) # IOD026 Malakill : +3 tant que l'Objet est sous la salle
	# Bonus de degats poses par les sorts/effets
	for e in _effects(G).get("roomDamageBonus", []):
		var ed: Dictionary = e
		if int(ed.get("playerId", -1)) == pid and int(ed.get("roomIndex", -1)) == room_index:
			dmg += int(ed.get("amount", 0))

	# BMA049 Skip Build / BMA043 : degats des salles ordinaires +1
	for id in _effects(G).get("ordinaryMonsterBonus", []):
		if int(id) == pid and str(r.get("type", "")) == "monster" and not bool(r.get("advanced", false)):
			dmg += 1
	if flame:
		G["iodFlame"] = true # lu par TnlAbilities.passive_damage / RmbAbilities.passive_room_damage : ignorer les AUTRES salles
	if TnlAbilities.active(G): # The Next Level : Goblin Nursery / Mess Hall, Elemental Generator, Killa
		dmg += TnlAbilities.passive_damage(G, player, room_index, r, locked)
	if Minibosses.active(G): # Rise of the Minibosses : niveaux 1 des minibosses, Power Leech, Magipede, Dreadmill, Scott...
		dmg += Minibosses.passive_damage(G, player, room_index, r, locked)
	G.erase("iodFlame")

	# Boss.GetPassiveDamage : level-up LastRoomDealDamage (KSA005 Scythe) = +N a la salle du fond (Dungeon.First(), index Godot dernier).
	for lu in level_ups(player):
		var lcmd := str((lu as Dictionary).get("cmd", ""))
		if lcmd == "LastRoomDealDamage" and room_index == dungeon.size() - 1:
			dmg += int(((lu as Dictionary).get("args", ["0"]) as Array)[0])
		elif lcmd == "RoomsDamagePerTreasure": # CRL001 Imperiatrix : +1 par tresor Explorer de la salle
			var want := int(CardDB.TREASURE_NAMES.find(str(((lu as Dictionary).get("args", ["Explorer"]) as Array)[0])))
			for t in room_treasures(r):
				if int(t) == want:
					dmg += 1

	if thk:
		dmg = PcwAbilities.double_for(r, hero, dmg, own_off) # KSA008 Ghoulyard : apres tous les autres bonus et malus
	# GameBoard.ProccessActiveHero : Hero.Ability.GetPassiveDamageCommand ; HeroResistDamageRoomType (KSA016 Monster Hunter) rend N PV
	# si le slot inflige des degats et que la salle est du type : degats totaux - N.
	var ha = (hero as Dictionary).get("heroAbility") if hero is Dictionary else null
	if ha is Dictionary and str((ha as Dictionary).get("cmd", "")) == "HeroResistDamageRoomType" and dmg != 0 and not (Minibosses.active(G) and Minibosses.hero_text_ignored(G, pid)) \
			and str(r.get("type", "")) == str(((ha as Dictionary).get("args", ["0", ""]) as Array)[1]).to_lower():
		dmg -= int(((ha as Dictionary)["args"] as Array)[0])
	if hero is Dictionary and ThkAbilities.active(G): # Tools of Hero-Kind : Goblin Suit, Star of Invulnerability (Objet porte par le heros)
		dmg = ThkAbilities.adjust_damage(player, G, room_index, r, hero as Dictionary, dmg)

	return maxi(0, dmg)

# --- engine.js: heroHealthWithModifiers (partie regles de base) ---

static func hero_health_with_modifiers(G: Dictionary, hero: Dictionary) -> int:
	var hp := hero_hp(hero) + int(hero.get("heartHp", 0)) # IOD011 Heart Container : +3 porte par la carte jusqu'a sa prochaine entree
	for e in _effects(G).get("heroHealthBonus", []):
		var ed: Dictionary = e
		if str(ed.get("heroId", "")) == str(hero.get("id", "")) and not bool(ed.get("spent", false)):
			hp += int(ed.get("amount", 0))
	return hp

## Le heros quitte l'aventure (mort / blessure, Match._finish_hero) : ses bonus de PV du tour sont perdus, un retour dans le tour
## (BMA039 Zombie Prison : RestoreHealth) repart des PV de base (oracle s3-p3@86 : heros 5 Assassin'e puis ressuscite = PV de base). La liste reste lisible (tutoriel).
static func spend_hero_health_bonus(G: Dictionary, hero: Dictionary) -> void:
	hero.erase("heartHp")
	for e in _effects(G).get("heroHealthBonus", []):
		if str((e as Dictionary).get("heroId", "")) == str(hero.get("id", "")):
			(e as Dictionary)["spent"] = true

# --- engine.js: destroyRoom / discardRoomToPile ---

## DungeonSlot.AbilityDamage des emplacements VIDES du joueur, dans l'ordre de pose (le premier recoit la prochaine salle ; indices C# croissants).
## Godot ne stocke pas les emplacements vides : DealDamageToDungeon (Crushinator) y pose son +2, insert_slot le rend a la salle construite.
## Les entrees absentes valent 0 (les 5 - taille emplacements vides, au plus).
static func empty_slot_bonuses(G: Dictionary, pid: int) -> Array:
	var eff := _effects(G)
	if not eff.has("emptySlotBonus"):
		eff["emptySlotBonus"] = {}
	var m: Dictionary = eff["emptySlotBonus"]
	if not m.has(str(pid)):
		m[str(pid)] = []
	return m[str(pid)]

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
	if not G.is_empty() and ThkAbilities.active(G): # IOD026 Malakill : l'Objet sous la salle detruite (ou sous celle qui se decouvre, donc couverte) retourne chez son proprietaire
		if destroyed.has("iodUnder"):
			IodAbilities.release_under(G, destroyed)
		if not stack.is_empty() and (stack[stack.size() - 1] as Dictionary).has("iodUnder"):
			IodAbilities.release_under(G, stack[stack.size() - 1] as Dictionary)
	if not G.is_empty() and TnlAbilities.active(G): # salles detruites ce tour (Oh, Yeah!), Cursed Tomb
		TnlAbilities.on_destroyed(G, int(player.get("id", 0)), destroyed)
	if stack.is_empty():
		dungeon.remove_at(room_index)
		# GameBoard.DestroyRoom : Dungeon.Remove + Add, les slots suivants se tassent ; les effets indexes suivent leur slot.
		var pid := int(player.get("id", 0))
		var lost_bonus := 0
		for key in ["deactivatedRooms", "roomDamageBonus"]:
			var arr: Array = _effects(G).get(key, [])
			for k in range(arr.size() - 1, -1, -1):
				var e: Dictionary = arr[k]
				if int(e.get("playerId", -1)) != pid:
					continue
				if int(e.get("roomIndex", -1)) == room_index:
					lost_bonus += int(e.get("amount", 0))
					arr.remove_at(k)
				elif int(e.get("roomIndex", -1)) > room_index:
					e["roomIndex"] = int(e["roomIndex"]) - 1
		if lost_bonus > 0: # le DungeonSlot detruit garde son AbilityDamage et passe en fin de liste (vide) : il le rendra a la prochaine pose
			var eb := empty_slot_bonuses(G, pid)
			while eb.size() < 5 - dungeon.size() - 1:
				eb.append(0)
			eb.append(lost_bonus)
		# Heros present dans ce donjon : il garde lastActiveHeroSlotIndex (GameBoard.ProccessActiveHero). Slot detruit
		# DEVANT lui (plus pres du boss = index Godot plus grand) : son index C# baisse de 1, last != num, donc pas de
		# num-- : il RESUBIT sa salle courante (adv.replay). Slot DERRIERE lui : l'index Godot de sa salle baisse de 1.
		var adv: Dictionary = G.get("adventure", {}) as Dictionary
		var h := int(adv.get("roomIndex", -1))
		if not adv.is_empty() and int(adv.get("playerId", -1)) == pid and h >= 0:
			# Hero.NearestBossSlotIndex est un entier C# stocke (GameBoard.cs:1127-1129) : le slot detruit sort de la liste (Dungeon.Remove + Add),
			# DungeonSize baisse de 1 mais la valeur ne bouge pas. En index Godot (entree = 0, g = DungeonSize - 1 - c) elle baisse donc de 1,
			# sinon une salle deja plus pres du boss que le « nearest » perdrait son FirstTimeHeroEnterThisRoom (Minotaur's Maze, s21-p2@518).
			if adv.has("nearest"):
				adv["nearest"] = int(adv["nearest"]) - 1
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
					# Exception : heros au slot C# 4 (donjon plein, entree) => lastActiveHeroSlotIndex == 4 == IndexOf(slot), donc num-- directement
					# (ProccessActiveHero, GameBoard.cs:1108-1116) : aucun pas « vide » (s11-p3@404, s12-p2@814).
					adv["roomIndex"] = -(5 - dungeon.size()) - (0 if dungeon.size() == 4 and h == 0 else 1)
	if triggers and not G.is_empty():
		_on_other_room_destroyed(G, player, destroyed)
	# Regle « uncover » (Crash Landing) : la salle du dessous redevient le sommet de sa pile (l'emplacement n'a pas disparu).
	if not G.is_empty() and not stack.is_empty():
		RoomAbilities.on_uncover(G, int(player.get("id", 0)), room_index)
		if TnlAbilities.active(G): # TNL : « when you build or uncover this Room » + Eclipse
			TnlAbilities.on_uncover(G, int(player.get("id", 0)), room_index)
	if not G.is_empty() and Minibosses.active(G): # RMB : le miniboss saute sur la salle decouverte (ou est defausse) ; Garbage Chute, Black Market
		Minibosses.on_destroy(G, player, destroyed, stack)
	return destroyed

## GameBoard.DestroyRoom -> CheckTriggerInDungeon<WhenAnotherRoomIsDestroyed> : chaque BMA031 Recycling Center
## actif du donjon (la salle detruite n'y est plus) fait piocher 2 salles a son proprietaire (DrawCards 2 Room).
static func _on_other_room_destroyed(G: Dictionary, player: Dictionary, destroyed: Dictionary) -> void:
	var dungeon: Array = player.get("dungeon", [])
	for i in dungeon.size():
		var top = active_room(dungeon[i])
		if top == null or bool((top as Dictionary).get("faceDown", false)) or str((top as Dictionary).get("id", "")) != "BMA031":
			continue
		if is_room_deactivated(G, int(player.get("id", -1)), i) or TnlAbilities.no_text(top as Dictionary):
			continue
		# DestroyRoom defausse la salle AVANT le declencheur : elle fait partie des defausses remelangees si la pioche est vide.
		# Les appelants la defaussent apres coup : le drapeau rend leur discard_room_to_pile sans effet.
		if not destroyed.has("pileEarly"):
			discard_room_to_pile(G.get("decks", {}) as Dictionary, destroyed)
			destroyed["pileEarly"] = true
		# DrawRooms : pioche vide => defausses remelangees (GameBoard.cs:529-545, 1335-1349), puis la suite de la pioche.
		(player.get("hand", []) as Array).append_array(CardDB.draw_pile(G.get("decks", {}) as Dictionary, "rooms", 2))

static func discard_room_to_pile(decks: Dictionary, card) -> void:
	if card == null:
		return
	if (card as Dictionary).erase("pileEarly"): # deja defaussee par _on_other_room_destroyed
		return
	(card as Dictionary).erase("usedThisTurn") # une salle recuperee puis reconstruite repart avec une capacite neuve
	(card as Dictionary).erase("extraTreasures") # tresors « jusqu'a la fin du tour » (Decoy Garden, Meteorite) perdus avec la salle
	(card as Dictionary).erase("tnl") # effets TNL « jusqu'a la fin du tour » (Fairy Fountain, Meddling Kids!, Decapitator) perdus aussi
	if (card as Dictionary).has("mb") or (card as Dictionary).has("coins") or (card as Dictionary).has("rmb"):
		Minibosses.cleanup_discarded(decks, card as Dictionary) # RMB : Coins posees perdues, miniboss defausse
	if TnlAbilities.torix_catch(decks, card as Dictionary): # TNL003 Torix : la salle Monster va dans sa main (voir TnlAbilities.flush_torix)
		return
	var pile: Array = decks.get("roomDiscard", [])
	decks["roomDiscard"] = pile
	CardDB.discard_add(pile, card)
