class_name RmbAbilities
extends RefCounted
## Rise of the Minibosses (RMB) : les 42 salles, les 12 boss, les 3 capacites de main et les choix qui en decoulent (etapes « rmb_* » du choix
## generique « tnl-pick », voir TnlAbilities.ask). Pieces, minibosses et crochets du moteur : Minibosses.gd ; sorts : RmbSpells.gd.
## Texte des cartes (cards.json) d'abord ; le JS n'est suivi que quand il le dit aussi (voir les ecarts dans les goldens goldens_rmb.gd).

const ACTIVATED := ["RMB013", "RMB015", "RMB019", "RMB022", "RMB026", "RMB038", "RMB042", "RMB043", "RMB044", "RMB045", "RMB047", "RMB052", "RMB053", "RMB054"]
const HAND := ["RMB016", "RMB027", "RMB035"]

static func _player(G: Dictionary, pid: int) -> Dictionary:
	return TnlAbilities._player(G, pid)

static func _log(G: Dictionary, t: String, pub: String = "", owners: Array = []) -> void:
	TnlAbilities._log(G, t, pub, owners)

static func _label(c: Dictionary) -> String:
	return TnlAbilities._label(c)

## Boss RMB « pour le reste de la partie » : drapeau pose par level_up (aussi par Klonos qui copie un boss RMB) ou boss monte de niveau.
static func has_boss(p: Dictionary, boss_id: String) -> bool:
	if bool((p.get("rmbBoss", {}) as Dictionary).get(boss_id, false)):
		return true
	var b = p.get("boss")
	return b is Dictionary and str((b as Dictionary).get("id", "")) == boss_id and bool(p.get("leveledUp", false))

## Niveau d'un boss RMB (RoomAbilities.process_level_up). Tous les pouvoirs RMB sont « pour le reste de la partie » : un drapeau suffit.
static func level_up(G: Dictionary, pid: int, p: Dictionary, boss: Dictionary) -> Variant:
	var flags: Dictionary = p.get("rmbBoss", {}) as Dictionary
	p["rmbBoss"] = flags
	flags[str(boss.get("id", ""))] = true
	_log(G, "%s: level up (%s)" % [str(boss.get("name", "?")), str(boss.get("levelUpDesc", ""))])
	return null

static func _scott_off(G: Dictionary, pid: int) -> bool:
	return Minibosses.list(G, "scottOff").has(pid)

## Tomb of Terrors : « a room or spell card » de la defausse. Un miniboss n'est pas une salle (livret p.6) : il reste dans la defausse.
static func tomb_options(G: Dictionary) -> Array:
	return RoomAbilities.discard_card_options(G, "any").filter(func(o): return not bool(((o as Dictionary)["card"] as Dictionary).get("isMiniboss", false)))

# --- utilitaires de cibles ---------------------------------------------------------------------------------------------------

static func _ai_player(G: Dictionary, q: int, me: int) -> float:
	var p := _player(G, q)
	return float(CardDB.total_souls(p, G) - CardDB.total_wounds(p)) * (1.0 if q != me else -1.0)

static func opponent_options(G: Dictionary, pid: int, need_spell: bool = false) -> Array:
	var out: Array = []
	for o in TnlAbilities._opponents(G, pid):
		var q := _player(G, int(o))
		if need_spell and TnlAbilities.spells_in_hand(q) == 0:
			continue
		out.append({"targetPlayerId": int(o), "label": "Player %d (%s)" % [int(o) + 1, str((q.get("boss", {}) as Dictionary).get("name", "?"))], "ai": _ai_player(G, int(o), pid)})
	return out

static func player_options(G: Dictionary, pid: int) -> Array:
	var out: Array = []
	for o in TnlAbilities._alive(G):
		var q := _player(G, int(o))
		out.append({"targetPlayerId": int(o), "label": "Player %d (%s)" % [int(o) + 1, str((q.get("boss", {}) as Dictionary).get("name", "?"))], "ai": _ai_player(G, int(o), pid)})
	return out

static func mini_options(p: Dictionary, ai: float = 2.0) -> Array:
	var out: Array = []
	for c in Minibosses.miniboss_cards_in_hand(p):
		out.append({"card": c, "label": _label(c as Dictionary), "ai": ai})
	return out

static func find_hero(G: Dictionary, hero_id: String) -> Dictionary:
	for h in (G.get("town", []) as Array):
		if str((h as Dictionary).get("id", "")) == hero_id:
			return h
	for q in TnlAbilities._alive(G):
		for h in (_player(G, int(q)).get("entrance", []) as Array):
			if str((h as Dictionary).get("id", "")) == hero_id:
				return h
	return {}

## Salles Monster visibles (sommets) du donjon de `pid` : options de choix « rmb_room ».
static func own_monsters(G: Dictionary, pid: int) -> Array:
	var opts := TnlAbilities.room_options(G, "monster", -1, -1, pid)
	var f := AiWiki.fate(G)
	for o in opts:
		(o as Dictionary)["ai"] = float(int(((o as Dictionary)["card"] as Dictionary).get("damage", 0))) + (10.0 if AiWiki.is_ahead(f, pid, int((o as Dictionary)["roomIndex"])) else 0.0)
	return opts

static func opponent_rooms(G: Dictionary, pid: int) -> Array:
	var out: Array = []
	for o in TnlAbilities.room_options(G, "any"):
		if int((o as Dictionary)["targetPlayerId"]) != pid:
			(o as Dictionary)["ai"] = float(int(((o as Dictionary)["card"] as Dictionary).get("damage", 0))) + 2.0 * float(int(((o as Dictionary)["card"] as Dictionary).get("treasures", []).size()))
			out.append(o)
	return out

static func _wound_options(p: Dictionary) -> Array:
	var opts: Array = []
	for h in BossEngine.wound_heroes(p):
		opts.append({"card": h, "label": _label(h as Dictionary), "ai": float(BossEngine.hero_souls(h as Dictionary))})
	return opts

static func _hero_in_room(G: Dictionary, pid: int, idx: int) -> bool:
	return RoomAbilities.hero_is_in_room(G, pid, idx) and int(TnlAbilities.adv(G).get("hp", 0)) > 0

static func _spell_source_left(G: Dictionary) -> bool:
	var d: Dictionary = G.get("decks", {})
	return not (d.get("spells", []) as Array).is_empty() or not (d.get("spellDiscard", []) as Array).is_empty()

## RMB025 Fetid Beast : une salle Monster ne peut etre posee ni a cote de lui. `target_index` < 0 : nouvelle pile en bout de donjon (a cote de la pile 0).
static func fetid_blocks(dungeon: Array, card: Dictionary, target_index: int) -> bool:
	if str(card.get("type", "")) != "monster" or str(card.get("id", "")) == "RMB025":
		return false
	for j in ([0] if target_index < 0 else [target_index - 1, target_index + 1]):
		if j >= 0 and j < dungeon.size():
			var top = BossEngine.active_room(dungeon[j])
			if top != null and str((top as Dictionary).get("id", "")) == "RMB025" and not bool((top as Dictionary).get("faceDown", false)):
				return true
	return false

# --- passifs de salles --------------------------------------------------------------------------------------------------------

## Bonus / malus de degats que les salles RMB donnent a `r` (voisines : Power Leech ; propres : Doppelganger Hive, Magipede, Dreadmill, Minion Clinic, Crystal Ballroom).
static func passive_room_damage(G: Dictionary, player: Dictionary, room_index: int, r: Dictionary, dungeon: Array) -> int:
	var dmg := 0
	var pid := int(player.get("id", 0))
	var rt := str(r.get("type", ""))
	for i in dungeon.size():
		if i != room_index - 1:
			continue
		var other = BossEngine.active_room(dungeon[i])
		if other != null and not bool(G.get("iodFlame", false)) and str((other as Dictionary).get("id", "")) == "RMB024" and rt == "monster" and not bool((other as Dictionary).get("faceDown", false)) \
				and not BossEngine.is_room_deactivated(G, pid, i) and not TnlAbilities.no_text(other as Dictionary):
			dmg += 2 # Power Leech : la salle a sa droite (vers le boss), si Monster, +2
	match str(r.get("id", "")):
		"RMB029": # Doppelganger Hive : +1 par heros leurre dans ce donjon ce tour
			dmg += int((G.get("luredThisTurn", {}) as Dictionary).get(pid, 0))
		"RMB039": # Magipede : +1 par sort en main
			dmg += TnlAbilities.spells_in_hand(player)
		"RMB048": # The Dreadmill : +1 par Coin pose dessus
			dmg += int(r.get("coins", 0))
		"RMB020", "RMB037": # Minion Clinic, Crystal Ballroom : -1 par Coin pose dessus
			dmg -= int(r.get("coins", 0))
	return dmg

## Declencheurs « une salle d'un autre donjon / de ce donjon est detruite » (appele par Minibosses.on_destroy) : Garbage Chute, Black Market.
static func on_destroyed(G: Dictionary, owner: int, destroyed: Dictionary) -> void:
	if not Minibosses.active(G):
		return
	for q in CardDB.order_by_xp(G.get("players", {})):
		var p := _player(G, int(q))
		if bool(p.get("eliminated", false)):
			continue
		var d: Array = p.get("dungeon", [])
		for i in d.size():
			var r = BossEngine.active_room(d[i])
			if r == null or bool((r as Dictionary).get("faceDown", false)) or TnlAbilities.no_text(r as Dictionary) or is_same(r, destroyed):
				continue
			var rd: Dictionary = r
			match str(rd.get("id", "")):
				"RMB041": # Garbage Chute : une fois par tour, +2 Coins
					if not bool(rd.get("usedThisTurn", false)):
						rd["usedThisTurn"] = true
						Minibosses.gain_coin(G, int(q), 2, "Garbage Chute")
				"RMB033": # Black Market : une fois par tour, payer 1 Coin pour piocher un sort (facultatif)
					if not bool(rd.get("usedThisTurn", false)) and Minibosses.coins(p) >= 1 and _spell_source_left(G):
						TnlAbilities.emit(G, TnlAbilities.ask(G, int(q), "rmb_yes", [{"label": "Pay 1 Coin: draw a Spell", "ai": 3.0}], {"then": "blackmarket", "slot": i}, "Black Market: pay 1 Coin to draw a Spell?", "Black Market", true))

## Un joueur vient de poser / promouvoir un miniboss : Personnel Office de ses adversaires (une fois par tour, +1 Coin).
static func on_opponent_miniboss(G: Dictionary, actor: int) -> void:
	for q in TnlAbilities._opponents(G, actor):
		for stack in (_player(G, int(q)).get("dungeon", []) as Array):
			var r = BossEngine.active_room(stack)
			if r != null and str((r as Dictionary).get("id", "")) == "RMB049" and not bool((r as Dictionary).get("faceDown", false)) \
					and not TnlAbilities.no_text(r as Dictionary) and not bool((r as Dictionary).get("usedThisTurn", false)):
				(r as Dictionary)["usedThisTurn"] = true
				Minibosses.gain_coin(G, int(q), 1, "Personnel Office")
				break

## Un heros vient d'etre tue chez `pid` (Gregore : une fois par tour, +1 Coin).
static func on_hero_killed(G: Dictionary, pid: int) -> void:
	if has_boss(_player(G, pid), "RMB001") and not Minibosses.used(G, pid, "gregore"):
		Minibosses.mark_used(G, pid, "gregore")
		Minibosses.gain_coin(G, pid, 1, "Gregore")

## Le heros quitte vivant la salle `prev` du donjon de `pid` : Foyer Elemental (une fois par tour, +2 Coins).
static func on_room_exit(G: Dictionary, pid: int, prev: int) -> void:
	var d: Array = _player(G, pid).get("dungeon", [])
	if prev < 0 or prev >= d.size():
		return
	var r = BossEngine.active_room(d[prev])
	if r != null and str((r as Dictionary).get("id", "")) == "RMB030" and not bool((r as Dictionary).get("faceDown", false)) and not TnlAbilities.no_text(r as Dictionary) \
			and not BossEngine.is_room_deactivated(G, pid, prev) and not BossEngine.abilities_locked(G, pid) and not bool((r as Dictionary).get("usedThisTurn", false)):
		(r as Dictionary)["usedThisTurn"] = true
		Minibosses.gain_coin(G, pid, 2, "Foyer Elemental")

## Un heros meurt dans `room` du donjon de `pid` (declencheurs de salles) : Lightning Rod, Mind Thresher (une fois par tour).
static func on_hero_died(G: Dictionary, pid: int, room: Dictionary) -> void:
	if TnlAbilities.no_text(room):
		return
	var id := str(room.get("id", ""))
	if id != "RMB051" and id != "RMB034":
		return
	if bool(room.get("usedThisTurn", false)):
		return
	var p := _player(G, pid)
	if id == "RMB051": # Lightning Rod : +3 Coins
		room["usedThisTurn"] = true
		Minibosses.gain_coin(G, pid, 3, "Lightning Rod")
		return
	var souls: Array = p.get("souls", [])
	if souls.is_empty() or not ((souls[souls.size() - 1] as Dictionary).get("hero") is Dictionary) or not _spell_source_left(G):
		return
	var hero: Dictionary = (souls[souls.size() - 1] as Dictionary)["hero"]
	TnlAbilities.emit(G, TnlAbilities.ask(G, pid, "rmb_mind", [{"card": hero, "label": "Remove %s from the game: draw 2 Spells" % _label(hero), "ai": -5.0}], {"room": room, "slot": TnlAbilities._index_of_room(p, room)},
		"Mind Thresher: remove %s from the game to draw two Spells?" % _label(hero), "Mind Thresher", true))

# --- construction / decouverte -----------------------------------------------------------------------------------------------------

## « When you build this Room » (RoomAbilities.on_build_room) : boss (Lamia, Dr. Deadly), Goblin Market voisine, effets de la salle. Renvoie un choix, ou null.
static func on_build(G: Dictionary, pid: int, room: Dictionary) -> Variant:
	var p := _player(G, pid)
	if not bool(G.get("rmbReplay", false)): # Omega 42 rejoue l'effet de la salle, pas les boss
		if str(room.get("type", "")) == "monster" and has_boss(p, "RMB004"):
			Minibosses.gain_coin(G, pid, 1, "Lamia")
		if str(room.get("type", "")) == "trap" and has_boss(p, "RMB010"):
			Minibosses.gain_coin(G, pid, 1, "Dr. Deadly")
	if TnlAbilities.no_text(room):
		return null
	_goblin_market(G, pid, room)
	if not str(room.get("id", "")).begins_with("RMB"):
		return null
	return TnlAbilities.flush(G, _build_or_uncover(G, pid, room, true))

## Goblin Market : « whenever you build a Room next to this Room, gain 2 Coins » (pile voisine de celle de la salle posee).
static func _goblin_market(G: Dictionary, pid: int, room: Dictionary) -> void:
	var p := _player(G, pid)
	var d: Array = p.get("dungeon", [])
	var at := TnlAbilities._index_of_room(p, room)
	if at < 0:
		return
	for i in [at - 1, at + 1]:
		if i < 0 or i >= d.size():
			continue
		var m = BossEngine.active_room(d[i])
		if m != null and str((m as Dictionary).get("id", "")) == "RMB023" and not bool((m as Dictionary).get("faceDown", false)) and not TnlAbilities.no_text(m as Dictionary) \
				and not BossEngine.is_room_deactivated(G, pid, i):
			Minibosses.gain_coin(G, pid, 2, "Goblin Market")

## « When you uncover this Room » (RoomAbilities.on_uncover) : memes effets que la construction, sauf ceux limites a « build ».
static func on_uncover(G: Dictionary, pid: int, room: Dictionary) -> void:
	if TnlAbilities.no_text(room) or not str(room.get("id", "")).begins_with("RMB"):
		return
	for c in _build_or_uncover(G, pid, room, false):
		TnlAbilities.emit(G, c)

## Salles RMB dont l'effet « build » (ou « build or uncover ») existe : cibles de The Omega 42.
static func has_build_effect(room: Dictionary) -> bool:
	return ["RMB014", "RMB015", "RMB018", "RMB020", "RMB021", "RMB028", "RMB031", "RMB036", "RMB037", "RMB040", "RMB050"].has(str(room.get("id", "")))

static func has_uncover_effect(room: Dictionary) -> bool:
	return ["RMB014", "RMB018", "RMB028", "RMB031", "RMB040", "RMB050"].has(str(room.get("id", "")))

static func _build_or_uncover(G: Dictionary, pid: int, room: Dictionary, built: bool) -> Array:
	var p := _player(G, pid)
	var out: Array = []
	var coins := Minibosses.coins(p)
	match str(room.get("id", "")):
		"RMB014": # Monster Academy : « for every miniboss you reveal from your hand » : on choisit combien reveler (0..n), 2 Coins chacun, ils restent en main
			var n := Minibosses.miniboss_cards_in_hand(p).size()
			if n > 0:
				var aopts: Array = []
				for k in range(0, n + 1):
					aopts.append({"n": k, "label": "Reveal %d Miniboss(es)" % k, "ai": float(k)})
				out.append(TnlAbilities.ask(G, pid, "rmb_acad", aopts, {}, "Monster Academy: how many Minibosses to reveal from your hand (2 Coins each)?", "Monster Academy"))
		"RMB015": # Ancient Guardtower : choisit un adversaire (cible de la capacite, ce tour seulement)
			if built:
				var opts := opponent_options(G, pid)
				if not opts.is_empty():
					out.append(TnlAbilities.ask(G, pid, "rmb_opp", opts, {"then": "gt", "room": room}, "Ancient Guardtower: choose an opponent", "Ancient Guardtower"))
		"RMB018": # Vampire Lab : defausse un miniboss pour soigner une blessure
			if not BossEngine.wound_heroes(p).is_empty() and not Minibosses.miniboss_cards_in_hand(p).is_empty():
				out.append(TnlAbilities.ask(G, pid, "rmb_cost", mini_options(p, 3.0), {"then": "heal", "label": "Vampire Lab"}, "Vampire Lab: discard a Miniboss to heal a Wound (or skip)", "Vampire Lab", true))
		"RMB020": # Minion Clinic : jusqu'a 3 Coins poses dessus, une carte de la defausse par Coin ; -1 par Coin
			if built and coins > 0:
				out.append(TnlAbilities.ask(G, pid, "rmb_n", _count_options(mini(3, coins)), {"then": "clinic", "room": room}, "Minion Clinic: how many Coins to place on it (up to 3)?", "Minion Clinic"))
		"RMB021": # Robber's Vault : echange son Hoard avec celui d'un autre joueur
			if built:
				var vopts := opponent_options(G, pid)
				for o in vopts:
					(o as Dictionary)["ai"] = float(Minibosses.coins(_player(G, int((o as Dictionary)["targetPlayerId"])))) - float(coins)
				if not vopts.is_empty():
					out.append(TnlAbilities.ask(G, pid, "rmb_opp", vopts, {"then": "vault"}, "Robber's Vault: choose a player to exchange Hoards with", "Robber's Vault"))
		"RMB028": # Dragon's Nest : chaque AUTRE salle Monster de votre donjon +1 par icone de tresor, jusqu'a la fin du tour
			for stack in (p.get("dungeon", []) as Array):
				var o2 = BossEngine.active_room(stack)
				if o2 != null and not is_same(o2, room) and not bool((o2 as Dictionary).get("faceDown", false)) and str((o2 as Dictionary).get("type", "")) == "monster":
					SpellEffects._buff_room_instance(o2, BossEngine.room_treasures(o2 as Dictionary).size())
			_log(G, "Dragon's Nest: the other Monster Rooms gain +1 per treasure icon until end of turn.")
		"RMB031": # Mysterious Portal : defausse un miniboss pour piocher un sort
			if not Minibosses.miniboss_cards_in_hand(p).is_empty() and _spell_source_left(G):
				out.append(TnlAbilities.ask(G, pid, "rmb_cost", mini_options(p, 3.0), {"then": "draw_spell", "label": "Mysterious Portal"}, "Mysterious Portal: discard a Miniboss to draw a Spell (or skip)", "Mysterious Portal", true))
		"RMB036": # Loot Box : payer 2 Coins, piocher 2 sorts
			if built and coins >= 2 and _spell_source_left(G):
				out.append(TnlAbilities.ask(G, pid, "rmb_yes", [{"label": "Pay 2 Coins: draw 2 Spells", "ai": 2.0 if coins >= 3 else -2.0}], {"then": "lootbox"}, "Loot Box: pay 2 Coins and draw two Spells?", "Loot Box", true))
		"RMB037": # Crystal Ballroom : jusqu'a 3 Coins poses dessus, un sort par Coin ; -1 par Coin
			if built and coins > 0:
				out.append(TnlAbilities.ask(G, pid, "rmb_n", _count_options(mini(3, coins)), {"then": "crystal", "room": room}, "Crystal Ballroom: how many Coins to place on it (up to 3)?", "Crystal Ballroom"))
		"RMB040": # Delver's Quarry
			TnlAbilities.draw_logged(G, pid, "rooms", 1, "Delver's Quarry")
		"RMB050": # Trophy Room : 1 Coin par salle multi-tresor du donjon (elle comprise)
			var multi := 0
			for stack in (p.get("dungeon", []) as Array):
				var t = BossEngine.active_room(stack)
				if t != null and not bool((t as Dictionary).get("faceDown", false)) and ((t as Dictionary).get("treasures", []) as Array).size() > 1:
					multi += 1
			Minibosses.gain_coin(G, pid, multi, "Trophy Room")
	return out.filter(func(c): return c != null)

static func _count_options(max_n: int) -> Array:
	var out: Array = []
	for n in range(0, max_n + 1):
		out.append({"n": n, "label": "%d Coin(s)" % n, "ai": 2.0 - absf(float(n) - 2.0)})
	return out

# --- capacites activees des salles --------------------------------------------------------------------------------------------------

## Verifie, sans rien modifier, que la capacite de la salle `idx` est utilisable. Renvoie "" si oui, sinon la raison.
static func check(G: Dictionary, p: Dictionary, pid: int, idx: int, r: Dictionary) -> String:
	var id := str(r.get("id", ""))
	var phase := str(G.get("phase", ""))
	if phase != "build" and phase != "adventure":
		return "Build or Adventure phase only"
	if bool(r.get("faceDown", false)) or bool(r.get("usedThisTurn", false)) or TnlAbilities.no_text(r) or BossEngine.is_room_deactivated(G, pid, idx) or BossEngine.abilities_locked(G, pid):
		return "not available"
	var coins := Minibosses.coins(p)
	match id:
		"RMB013": # Spectral Bomb
			if RoomAbilities.opponents_with(G, pid, true).is_empty():
				return "no opponent has a Spell"
		"RMB015": # Ancient Guardtower : seulement le tour ou elle a ete construite
			var rm: Dictionary = r.get("rmb", {}) as Dictionary
			var tp := _player(G, int(rm.get("gtTarget", -1)))
			if int(rm.get("gtTurn", -1)) != int(G.get("turn", 0)) or tp.is_empty() or bool(tp.get("eliminated", false)) or TnlAbilities.spells_in_hand(tp) == 0 or coins < 1:
				return "no target, no Spell to take or no Coin"
		"RMB019": # Haunted Cavern
			if coins < 1 or _cavern_targets(G, pid).is_empty():
				return "no Coin or no Hero at the entrance"
		"RMB022": # Minotaur Catacombs
			if not _hero_in_room(G, pid, idx):
				return "no Hero in this Room"
		"RMB026": # Training Camp
			if Minibosses.miniboss_cards_in_hand(p).is_empty() or own_monsters(G, pid).is_empty():
				return "no Miniboss to discard or no Monster Room"
		"RMB038": # Efreet's Chamber
			if _entrance_waiting(G, pid) == 0 or (not _spell_source_left(G) and TnlAbilities.spells_in_hand(p) == 0):
				return "no Hero at the entrance or no Spell"
		"RMB043": # Sawtooth Pendulum
			var hp := int(TnlAbilities.adv(G).get("hp", 0))
			if not _hero_in_room(G, pid, idx) or hp > 3 or coins < 1:
				return "no Hero with 3 Health or less in this Room, or no Coin"
		"RMB044": # The Catapult
			if Minibosses.miniboss_cards_in_hand(p).is_empty() or opponent_rooms(G, pid).is_empty():
				return "no Miniboss to discard or no opponent Room"
		"RMB047": # Living Trap
			if not _hero_in_room(G, pid, idx) or own_monsters(G, pid).is_empty():
				return "no Hero in this Room or no Monster Room to destroy"
		"RMB052": # Pixie Fountain
			if CardDB.total_wounds(p) == 0:
				return "no Wound"
		"RMB054": # Pool of Shadows
			if TnlAbilities.spells_in_hand(p) == 0:
				return "no Spell to discard"
		"RMB042", "RMB045", "RMB053":
			pass
		_:
			return "no activated ability"
	return ""

## Heros a l'entree (pas le heros actif du donjon) : cibles de Haunted Cavern, condition d'Efreet's Chamber.
static func _cavern_targets(G: Dictionary, pid: int) -> Array:
	var out: Array = []
	var mine := TnlAbilities.hero_in_dungeon(G, pid)
	for h in (_player(G, pid).get("entrance", []) as Array):
		if is_same(h, mine) or Minibosses.hero_blocked(G, h):
			continue
		out.append({"card": h, "label": _label(h as Dictionary), "ai": float(int((h as Dictionary).get("hp", 0))) * (1.0 if int((h as Dictionary).get("souls", 1)) < 2 else 2.0)})
	return out

static func _entrance_waiting(G: Dictionary, pid: int) -> int:
	var n := 0
	var mine := TnlAbilities.hero_in_dungeon(G, pid)
	for h in (_player(G, pid).get("entrance", []) as Array):
		n += 0 if is_same(h, mine) else 1
	return n

## Active la capacite (deja filtree par RoomAbilities.activate_room_ability : non utilisee, non verrouillee). Renvoie null ou un message d'erreur.
static func activate(G: Dictionary, p: Dictionary, pid: int, idx: int, r: Dictionary) -> Variant:
	var why := check(G, p, pid, idx, r)
	if why != "":
		return why
	var id := str(r.get("id", ""))
	var name := str(r.get("name", id))
	match id:
		"RMB013": # Spectral Bomb : se detruit, un adversaire defausse un sort au hasard
			TnlAbilities.destroy_room_at(G, pid, idx, name)
			force_spell_discard(G, pid, name)
		"RMB015": # Ancient Guardtower : donne 1 Coin a l'adversaire designe, prend un de ses sorts au hasard
			r["usedThisTurn"] = true
			var rm: Dictionary = r.get("rmb", {}) as Dictionary
			var tid := int(rm.get("gtTarget", -1))
			Minibosses.pay_coin(G, pid, 1)
			var tp := _player(G, tid)
			tp["coins"] = Minibosses.coins(tp) + 1
			var spells: Array = (tp.get("hand", []) as Array).filter(func(c): return bool((c as Dictionary).get("isSpell", false)))
			var pick: Dictionary = spells[TnlAbilities._rng_get().randi_range(0, spells.size() - 1)]
			TnlAbilities.take_from_hand(G, tid, pick)
			(p["hand"] as Array).append(pick)
			_log(G, "%s: player %d gives a Coin to player %d and takes %s." % [name, pid + 1, tid + 1, _label(pick)], "%s: player %d gives a Coin to player %d and takes a Spell." % [name, pid + 1, tid + 1], [pid, tid])
		"RMB019": # Haunted Cavern : paie 1 Coin, un heros de l'entree n'entre pas avant le tour suivant
			r["usedThisTurn"] = true
			Minibosses.pay_coin(G, pid, 1)
			TnlAbilities.emit(G, TnlAbilities.ask(G, pid, "rmb_hero", _cavern_targets(G, pid), {"then": "block", "label": name}, "%s: choose a Hero at the entrance" % name, name))
		"RMB022": # Minotaur Catacombs : se detruit, le heros retourne au debut du donjon (il garde ses degats)
			r["usedThisTurn"] = true
			TnlAbilities.warp_hero(G, pid, idx)
		"RMB026": # Training Camp : defausse un miniboss, double une salle Monster
			r["usedThisTurn"] = true
			TnlAbilities.emit(G, TnlAbilities.ask(G, pid, "rmb_cost", mini_options(p, 1.0), {"then": "double_monster", "label": name}, "%s: choose a Miniboss to discard" % name, name))
		"RMB038": # Efreet's Chamber : pioche un sort (-2) OU defausse un sort (+2)
			r["usedThisTurn"] = true
			var opts: Array = []
			if _spell_source_left(G):
				opts.append({"mode": "draw", "label": "Draw a Spell: this Room -2", "ai": -1.0})
			for o in TnlAbilities.hand_options(p, "spell"):
				opts.append({"mode": "discard", "card": (o as Dictionary)["card"], "label": "Discard %s: this Room +2" % str((o as Dictionary)["label"]), "ai": 2.0 + float((o as Dictionary)["ai"])})
			TnlAbilities.emit(G, TnlAbilities.ask(G, pid, "rmb_efreet", opts, {"slot": idx}, "%s: draw a Spell (-2) or discard a Spell (+2)" % name, name))
		"RMB042": # Unstable Mine : se detruit, +3 Coins
			TnlAbilities.destroy_room_at(G, pid, idx, name)
			Minibosses.gain_coin(G, pid, 3, name)
		"RMB043": # Sawtooth Pendulum : paie 1 Coin, tue le heros de cette salle (3 PV ou moins)
			r["usedThisTurn"] = true
			Minibosses.pay_coin(G, pid, 1)
			var a := TnlAbilities.adv(G)
			a["hp"] = 0
			_log(G, "%s: %s is killed." % [name, _label(a.get("hero", {}))])
		"RMB044": # The Catapult : defausse un miniboss, desactive une salle adverse
			r["usedThisTurn"] = true
			TnlAbilities.emit(G, TnlAbilities.ask(G, pid, "rmb_cost", mini_options(p, 1.0), {"then": "deactivate_opp", "label": name}, "%s: choose a Miniboss to discard" % name, name))
		"RMB045": # Endless Gallery : se detruit, un tresor de plus chez un joueur jusqu'a la fin du tour
			TnlAbilities.destroy_room_at(G, pid, idx, name)
			var gal := player_options(G, pid)
			for go in gal:
				(go as Dictionary)["ai"] = _best_icon_gain(G, pid, int((go as Dictionary)["targetPlayerId"]))
			TnlAbilities.emit(G, TnlAbilities.ask(G, pid, "rmb_player", gal, {"label": name}, "%s: choose a dungeon" % name, name))
		"RMB047": # Living Trap : detruit une salle Monster de votre donjon, tue le heros de cette salle
			r["usedThisTurn"] = true
			TnlAbilities.emit(G, TnlAbilities.ask(G, pid, "rmb_room", own_monsters(G, pid), {"then": "living", "label": name, "slot": idx}, "%s: choose a Monster Room to destroy" % name, name))
		"RMB052": # Pixie Fountain : se detruit, 1 Coin par blessure
			var n := CardDB.total_wounds(p)
			TnlAbilities.destroy_room_at(G, pid, idx, name)
			Minibosses.gain_coin(G, pid, n, name)
		"RMB053": # The Keystone : se detruit, 1 Coin par salle restante
			TnlAbilities.destroy_room_at(G, pid, idx, name)
			Minibosses.gain_coin(G, pid, BossEngine.count_visible_rooms(p.get("dungeon", [])), name)
		"RMB054": # Pool of Shadows : defausse un sort, +2 Coins
			r["usedThisTurn"] = true
			TnlAbilities.emit(G, TnlAbilities.ask(G, pid, "rmb_cost", TnlAbilities.hand_options(p, "spell"), {"then": "coins2", "label": name}, "%s: choose a Spell to discard" % name, name))
	return null

## Un adversaire (au choix s'il y en a plusieurs) defausse un sort au hasard : meme choix « pick-opponent » que Specter's Sanctum.
static func force_spell_discard(G: Dictionary, actor: int, label: String) -> void:
	var opps := RoomAbilities.opponents_with(G, actor, true)
	if opps.size() == 1:
		RoomAbilities._discard_random_from(G, int((opps[0] as Dictionary)["playerId"]), true, label, actor)
	elif opps.size() > 1:
		var opts: Array = []
		for o in opps:
			opts.append({"targetPlayerId": int((o as Dictionary)["playerId"])})
		RoomAbilities.enqueue_pending(G, {"type": "pick-opponent", "action": "discard-spell", "resume": false, "playerId": actor, "bossName": label,
			"message": "%s: choose an opponent to discard a random Spell" % label, "options": opts})

# --- boss actives, capacites de main, paiements -------------------------------------------------------------------------------------

static func _active_boss_ok(G: Dictionary, p: Dictionary, pid: int, id: String) -> bool:
	if not has_boss(p, id) or Minibosses.used(G, pid, id) or Minibosses.coins(p) < 2:
		return false
	match id:
		"RMB003":
			return not opponent_options(G, pid, true).is_empty()
		"RMB006":
			return not own_monsters(G, pid).is_empty()
		"RMB009":
			return _spell_source_left(G)
	return id == "RMB012"

static func extra_moves(G: Dictionary, p: Dictionary, pid: int) -> Array:
	var out: Array = []
	var hand: Array = p.get("hand", [])
	var phase := str(G.get("phase", ""))
	for id in ["RMB003", "RMB006", "RMB009", "RMB012"]:
		if _active_boss_ok(G, p, pid, id):
			out.append({"type": "rmbBoss", "args": [id, -1]})
	if Minibosses.coins(p) >= 1:
		for q in TnlAbilities._opponents(G, pid):
			var qp := _player(G, int(q))
			if has_boss(qp, "RMB011") and not _scott_off(G, int(q)):
				out.append({"type": "rmbBoss", "args": ["RMB011", int(q)]}) # Scott : un adversaire donne 1 Coin pour annuler le +1 des Traps
			for i in (qp.get("dungeon", []) as Array).size():
				var r = BossEngine.active_room((qp["dungeon"] as Array)[i])
				if r != null and str((r as Dictionary).get("id", "")) == "RMB046" and not bool((r as Dictionary).get("faceDown", false)) and not TnlAbilities.no_text(r as Dictionary):
					out.append({"type": "rmbPay", "args": [int(q), i]}) # Paywall : n'importe quel joueur peut donner des Coins (-1 par Coin)
	for hi in hand.size():
		var c: Dictionary = hand[hi]
		match str(c.get("id", "")):
			"RMB016":
				if not tomb_options(G).is_empty():
					out.append({"type": "rmbHand", "args": [hi, ""]})
			"RMB027":
				if not TnlAbilities.hero_options(G).is_empty():
					out.append({"type": "rmbHand", "args": [hi, ""]})
			"RMB035":
				if _spell_source_left(G):
					out.append({"type": "rmbHand", "args": [hi, "spell"]})
				out.append({"type": "rmbHand", "args": [hi, "coins"]})
	return out

static func apply_move(G: Dictionary, pid: int, move: Dictionary) -> Variant:
	var args: Array = move.get("args", [])
	var p := _player(G, pid)
	match str(move.get("type", "")):
		"rmbBoss":
			var id := str(args[0])
			if id == "RMB011": # Scott : l'adversaire verse 1 Coin au proprietaire, ses Traps perdent le +1 jusqu'a la fin du tour
				var owner := int(args[1])
				if not Minibosses.pay_coin(G, pid, 1):
					return "no Coin"
				var op := _player(G, owner)
				op["coins"] = Minibosses.coins(op) + 1
				Minibosses.list(G, "scottOff").append(owner)
				_log(G, "Scott: player %d pays a Coin to cancel the +1 of the Trap Rooms of player %d until end of turn." % [pid + 1, owner + 1])
				return null
			if not _active_boss_ok(G, p, pid, id):
				return "cannot use this Boss power"
			Minibosses.pay_coin(G, pid, 2)
			Minibosses.mark_used(G, pid, id)
			match id:
				"RMB003": # Belladonna : un adversaire defausse un sort au hasard
					force_spell_discard(G, pid, "Belladonna")
				"RMB006": # Ravenus : double les degats d'une salle Monster
					TnlAbilities.emit(G, TnlAbilities.ask(G, pid, "rmb_room", own_monsters(G, pid), {"then": "double", "label": "Ravenus"}, "Ravenus: choose a Monster Room to double", "Ravenus"))
				"RMB009": # Kazanna : pioche un sort
					TnlAbilities.draw_logged(G, pid, "spells", 1, "Kazanna")
				"RMB012": # Kirax : un tresor de plus (au choix) dans le donjon de n'importe quel joueur
					TnlAbilities.emit(G, TnlAbilities.ask(G, pid, "rmb_player", player_options(G, pid), {"label": "Kirax"}, "Kirax: choose a dungeon", "Kirax"))
		"rmbPay":
			var owner2 := int(args[0])
			var r2 = BossEngine.active_room((_player(G, owner2).get("dungeon", []) as Array)[int(args[1])]) if int(args[1]) < (_player(G, owner2).get("dungeon", []) as Array).size() else null
			if r2 == null or not Minibosses.pay_coin(G, pid, 1):
				return "cannot pay"
			var op2 := _player(G, owner2)
			op2["coins"] = Minibosses.coins(op2) + 1
			SpellEffects._buff_room_instance(r2, -1)
			_log(G, "Paywall: player %d gives a Coin, %s gets -1 until end of turn." % [pid + 1, _label(r2 as Dictionary)])
		"rmbHand":
			var hi := int(args[0])
			var hand: Array = p.get("hand", [])
			if hi < 0 or hi >= hand.size():
				return "no such card"
			var card: Dictionary = hand[hi]
			var cid := str(card.get("id", ""))
			var pre: Array = tomb_options(G)
			TnlAbilities.discard_from_hand(G, pid, card)
			match cid:
				"RMB016": # Tomb of Terrors : une salle ou un sort de la defausse (pas elle-meme) rejoint la main
					for o in pre:
						(o as Dictionary)["label"] = _label((o as Dictionary)["card"] as Dictionary)
						# une autre Tomb of Terrors ne fait que tourner en rond (defausser l'une pour reprendre l'autre, a l'infini)
						(o as Dictionary)["ai"] = -5.0 if str(((o as Dictionary)["card"] as Dictionary).get("id", "")) == "RMB016" else TnlAbilities._ai_value((o as Dictionary)["card"] as Dictionary)
					TnlAbilities.emit(G, TnlAbilities.ask(G, pid, "take_discard", pre, {"label": "Tomb of Terrors"}, "Tomb of Terrors: choose a card from the discard pile", "Tomb of Terrors"))
				"RMB027": # Shrooman Aviary : un heros +3 jusqu'a la fin du tour
					var hs := TnlAbilities.hero_options(G)
					for h in hs:
						(h as Dictionary)["ai"] = AiWiki.hero_weight(G, pid, h as Dictionary)
					TnlAbilities.emit(G, TnlAbilities.ask(G, pid, "rmb_hero", hs, {"then": "plus", "amount": 3, "label": "Shrooman Aviary"}, "Shrooman Aviary: choose a Hero (+3 Health)", "Shrooman Aviary"))
				"RMB035": # Cursed Well : un sort OU 2 Coins
					if str(args[1]) == "spell":
						TnlAbilities.draw_logged(G, pid, "spells", 1, "Cursed Well")
					else:
						Minibosses.gain_coin(G, pid, 2, "Cursed Well")
	return null

# --- resolution des choix « rmb_* » -------------------------------------------------------------------------------------------------

static func resolve_pick(G: Dictionary, pid: int, pc: Dictionary, idx: int) -> Variant:
	var opts: Array = pc.get("options", [])
	var ctx: Dictionary = pc.get("ctx", {}) as Dictionary
	var p := _player(G, pid)
	var o: Dictionary = (opts[idx] as Dictionary) if idx >= 0 and idx < opts.size() else {}
	var step := str(pc.get("step", ""))
	if step.begins_with("rmb_sp_"):
		return RmbSpells.resolve_pick(G, pid, pc, idx)
	if idx < 0:
		return null # option facultative passee
	match step:
		"rmb_cost": # paie le cout (defausse d'une carte de la main), puis enchaine
			var card: Dictionary = o.get("card", {})
			if not TnlAbilities.discard_from_hand(G, pid, card):
				return null
			return _after_cost(G, pid, ctx, card)
		"rmb_room":
			return _room_target(G, pid, ctx, o)
		"rmb_yes":
			match str(ctx.get("then", "")):
				"lootbox": # Loot Box
					if Minibosses.pay_coin(G, pid, 2):
						TnlAbilities.draw_logged(G, pid, "spells", 2, "Loot Box")
				"blackmarket": # Black Market (une fois par tour, une fois la salle trouvee)
					var rv = SpellEffects.find_room(G, pid, int(ctx.get("slot", -1)))
					if rv != null and not bool((rv as Dictionary).get("usedThisTurn", false)) and Minibosses.pay_coin(G, pid, 1):
						(rv as Dictionary)["usedThisTurn"] = true
						TnlAbilities.draw_logged(G, pid, "spells", 1, "Black Market")
		"rmb_opp":
			var tid := int(o.get("targetPlayerId", -1))
			match str(ctx.get("then", "")):
				"gt": # Ancient Guardtower : l'adversaire choisi, valable ce tour
					var room: Dictionary = ctx.get("room", {})
					room["rmb"] = {"gtTarget": tid, "gtTurn": int(G.get("turn", 0))}
					_log(G, "Ancient Guardtower: player %d is targeted." % (tid + 1))
				"vault": # Robber's Vault : echange des Hoards
					var tp := _player(G, tid)
					var mine := Minibosses.coins(p)
					p["coins"] = Minibosses.coins(tp)
					tp["coins"] = mine
					_log(G, "Robber's Vault: player %d exchanges Hoards with player %d (%d <-> %d)." % [pid + 1, tid + 1, mine, Minibosses.coins(p)])
		"rmb_acad": # Monster Academy : revele n minibosses de la main (publiquement), +2 Coins chacun
			var an := int(o.get("n", 0))
			if an > 0:
				var names: Array = []
				for c in Minibosses.miniboss_cards_in_hand(p).slice(0, an):
					names.append(str((c as Dictionary).get("name", "?")))
				_log(G, "Monster Academy: player %d reveals %s from hand." % [pid + 1, ", ".join(names)])
				Minibosses.gain_coin(G, pid, 2 * an, "Monster Academy")
		"rmb_n": # nombre de Coins poses sur la salle (Minion Clinic, Crystal Ballroom)
			var n := int(o.get("n", 0))
			var rm: Dictionary = ctx.get("room", {})
			if n <= 0 or not Minibosses.pay_coin(G, pid, n):
				return null
			rm["coins"] = int(rm.get("coins", 0)) + n
			if str(ctx.get("then", "")) == "clinic":
				return _recover_step(G, pid, n, "Minion Clinic")
			TnlAbilities.draw_logged(G, pid, "spells", n, "Crystal Ballroom")
		"rmb_recover": # Minion Clinic : une carte de la defausse par Coin pose
			var got = RoomAbilities.take_discard_card(G, p, o)
			if got != null:
				_log(G, "Minion Clinic: %s recovered." % _label(got as Dictionary))
			var left := int(ctx.get("remaining", 1)) - 1
			if left > 0:
				return _recover_step(G, pid, left, "Minion Clinic")
		"rmb_hero":
			var hero: Dictionary = o.get("card", {})
			match str(ctx.get("then", "")):
				"plus":
					var amount := int(ctx.get("amount", 0))
					TnlAbilities.add_hero_hp(G, hero, amount)
					_log(G, "%s: %s gains +%d Health until end of turn." % [str(ctx.get("label", "?")), _label(hero), amount])
				"block":
					Minibosses.list(G, "blocked").append(str(hero.get("id", "")))
					_log(G, "%s: %s cannot enter the dungeon until next turn." % [str(ctx.get("label", "?")), _label(hero)])
		"rmb_efreet": # Efreet's Chamber
			var rv2 = SpellEffects.find_room(G, pid, int(ctx.get("slot", -1)))
			if rv2 == null:
				return null
			if str(o.get("mode", "")) == "draw":
				TnlAbilities.draw_logged(G, pid, "spells", 1, "Efreet's Chamber")
				SpellEffects._buff_room_instance(rv2, -2)
			elif TnlAbilities.discard_from_hand(G, pid, o.get("card", {})):
				SpellEffects._buff_room_instance(rv2, 2)
			_log(G, "Efreet's Chamber: %s %s until end of turn." % [_label(rv2 as Dictionary), "-2" if str(o.get("mode", "")) == "draw" else "+2"])
		"rmb_player": # Endless Gallery / Kirax : le donjon, puis le type de tresor
			var tid2 := int(o.get("targetPlayerId", -1))
			var icons: Array = []
			for t in icon_types(G):
				icons.append({"treasure": t, "targetPlayerId": tid2, "label": str(CardDB.TREASURE_NAMES[t]), "ai": AiWiki.icon_gain(G, pid, tid2, t) + (0.1 if tid2 == pid else 0.0)})
			return TnlAbilities.ask(G, pid, "rmb_icon", icons, {"label": str(ctx.get("label", ""))}, "Choose a treasure type to add to player %d's dungeon" % (tid2 + 1), "Treasure")
		"rmb_icon":
			if str(ctx.get("label", "")) == "Kirax": # icone permanente (aucune duree imprimee) : meme stockage que Mirrax (bonusTreasures)
				var kp := _player(G, int(o.get("targetPlayerId", pid)))
				var ki: Array = kp.get("bonusTreasures", []) as Array
				ki.append(int(o.get("treasure", 1)))
				kp["bonusTreasures"] = ki
				_log(G, "Kirax: a %s treasure is permanently added to player %d's dungeon." % [str(CardDB.TREASURE_NAMES[int(o.get("treasure", 1))]), int(o.get("targetPlayerId", pid)) + 1])
				return null
			Minibosses.list(G, "icons").append({"pid": int(o.get("targetPlayerId", pid)), "treasure": int(o.get("treasure", 1))})
			_log(G, "A %s treasure is added to player %d's dungeon until end of turn." % [str(CardDB.TREASURE_NAMES[int(o.get("treasure", 1))]), int(o.get("targetPlayerId", pid)) + 1])
		"rmb_mind": # Mind Thresher : le heros mort quitte la partie, pioche 2 sorts
			var dead: Dictionary = o.get("card", {})
			if TnlAbilities.remove_soul_hero(p, dead):
				for mt in [SpellEffects.find_room(G, pid, int(ctx.get("slot", -1))), ctx.get("room")]: # « once per turn » : consomme a l'acceptation seulement
					if mt is Dictionary and str((mt as Dictionary).get("id", "")) == "RMB034":
						(mt as Dictionary)["usedThisTurn"] = true
				TnlAbilities._remove_from_game(G, dead)
				_log(G, "Mind Thresher: %s is removed from the game." % _label(dead))
				TnlAbilities.draw_logged(G, pid, "spells", 2, "Mind Thresher")
		"rmb_heal": # Vampire Lab : le heros a retourner face cachee
			BossEngine.heal_one_wound(p, o.get("card", {}))
			_log(G, "Vampire Lab: heals %s." % _label(o.get("card", {})))
		"rmb_swap_d": # Kid Croak niveau 2 : le donjon, puis la paire de salles
			var tp2 := int(o.get("targetPlayerId", -1))
			var d: Array = _player(G, tp2).get("dungeon", [])
			var pairs: Array = []
			for a in d.size():
				for b in range(a + 1, d.size()):
					var ra = SpellTargeting._targetable_top(G, tp2, a, d[a])
					var rb = SpellTargeting._targetable_top(G, tp2, b, d[b])
					if ra != null and rb != null:
						pairs.append({"targetPlayerId": tp2, "a": a, "b": b, "label": "%s <-> %s" % [_label(ra as Dictionary), _label(rb as Dictionary)], "ai": AiWiki.swap_ai(G, pid, tp2, a, b)})
			return TnlAbilities.ask(G, pid, "rmb_swap_p", pairs, ctx, "%s: choose the two Rooms to swap" % str(ctx.get("label", "")), str(ctx.get("label", "")))
		"rmb_swap_p":
			if TnlAbilities.swap_stacks(G, int(o.get("targetPlayerId", -1)), int(o.get("a", -1)), int(o.get("b", -1))):
				_log(G, "%s: two Rooms of player %d's dungeon are swapped." % [str(ctx.get("label", "?")), int(o.get("targetPlayerId", 0)) + 1])
		"rmb_mb_return": # Spike niveau 3 : le miniboss designe retourne dans la main de son proprietaire
			var host = SpellEffects.find_room(G, int(o.get("pid", -1)), int(o.get("idx", -1)))
			var m := Minibosses.mb_of(host)
			if not m.is_empty():
				(host as Dictionary).erase("mb")
				var owner_hand: Array = _player(G, int(o.get("pid", -1))).get("hand", []) as Array
				owner_hand.append(m.get("card", {}))
				_log(G, "Spike: %s returns to player %d's hand." % [Minibosses.mb_name(m), int(o.get("pid", -1)) + 1])
		"rmb_croak": # Kid Croak niveau 3 : +1 / -1 aux salles Monster d'un donjon jusqu'a la fin du tour
			var qid := int(o.get("targetPlayerId", -1))
			for stack in (_player(G, qid).get("dungeon", []) as Array):
				var t = BossEngine.active_room(stack)
				if t != null and not bool((t as Dictionary).get("faceDown", false)) and str((t as Dictionary).get("type", "")) == "monster":
					SpellEffects._buff_room_instance(t, int(o.get("delta", 0)))
			_log(G, "Kid Croak: the Monster Rooms of player %d get %+d until end of turn." % [qid + 1, int(o.get("delta", 0))])
		"rmb_look": # Draculad niveau 3 : regarde la main, peut prendre un sort ou une salle
			var vid := int(o.get("targetPlayerId", -1))
			var cands: Array = []
			for c in (_player(G, vid).get("hand", []) as Array):
				var cd: Dictionary = c
				if bool(cd.get("isSpell", false)) or (bool(cd.get("isRoom", false)) and not bool(cd.get("isMiniboss", false))): # un miniboss n'est pas une salle
					cands.append({"card": cd, "victim": vid, "label": _label(cd), "ai": 1.0 + (3.0 if bool(cd.get("isSpell", false)) else TnlAbilities._ai_value(cd))})
			return TnlAbilities.ask(G, pid, "rmb_steal", cands, {}, "Draculad: take one Spell or Room (or skip)", "Draculad", true)
		"rmb_steal":
			var victim := int(o.get("victim", -1))
			var c2: Dictionary = o.get("card", {})
			if TnlAbilities.take_from_hand(G, victim, c2):
				(p["hand"] as Array).append(c2)
				_log(G, "Draculad: takes %s from player %d." % [_label(c2), victim + 1], "Draculad: takes a card from player %d." % (victim + 1), [pid, victim])
		"rmb_dungeon": # Cerebella (texte des heros ignore) / Mageseeker (les heros sautent la 1re salle) niveau 3
			var did := int(o.get("targetPlayerId", -1))
			if str(ctx.get("then", "")) == "ignore":
				Minibosses.list(G, "ignoreText").append(did)
				_log(G, "Cerebella: Heroes ignore all ability text in player %d's dungeon until end of turn." % (did + 1))
			else:
				(SpellEffects._effects(G)["skipFirstRoomPids"] as Array).append(did)
				_log(G, "Mageseeker: Heroes entering player %d's dungeon skip its first Room until end of turn." % (did + 1))
		"rmb_jinx_hero": # Jinx niveau 3 : un heros de la ville va a votre entree
			var jh: Dictionary = o.get("card", {})
			var town: Array = G.get("town", [])
			var at := town.find(jh)
			if at >= 0:
				town.remove_at(at)
				(p["entrance"] as Array).append(jh)
				_log(G, "Jinx: %s is placed at the entrance of your dungeon." % _label(jh))
		"rmb_build_slot": # Brassknuckle niveau 2 : construit la salle piochee par-dessus une salle
			return TnlAbilities.build_now(G, pid, ctx.get("card", {}), int(o.get("roomIndex", -1)), str(ctx.get("label", "")))
	return null

## « Choisissez une carte de la defausse » `n` fois (Minion Clinic) : options recalculees a chaque carte prise.
static func _recover_step(G: Dictionary, pid: int, n: int, label: String) -> Variant:
	var opts: Array = RoomAbilities.discard_card_options(G, "any")
	if opts.is_empty():
		return null
	for o in opts:
		(o as Dictionary)["label"] = _label((o as Dictionary)["card"] as Dictionary)
		(o as Dictionary)["ai"] = TnlAbilities._ai_value((o as Dictionary)["card"] as Dictionary)
	return TnlAbilities.ask(G, pid, "rmb_recover", opts, {"remaining": n}, "%s: choose a card from the discard pile (%d left)" % [label, n], label)

## Suite d'un cout paye (carte defaussee) : ce que la capacite en fait.
static func _after_cost(G: Dictionary, pid: int, ctx: Dictionary, card: Dictionary) -> Variant:
	var p := _player(G, pid)
	var label := str(ctx.get("label", "?"))
	match str(ctx.get("then", "")):
		"heal": # Vampire Lab : un heros blesse retourne face cachee
			var heroes := _wound_options(p)
			if heroes.size() == 1:
				BossEngine.heal_one_wound(p, (heroes[0] as Dictionary)["card"])
				_log(G, "%s: heals a Wound." % label)
			elif heroes.size() > 1:
				return TnlAbilities.ask(G, pid, "rmb_heal", heroes, {}, "%s: choose a Hero to turn face-down" % label, label)
		"draw_spell":
			TnlAbilities.draw_logged(G, pid, "spells", 1, label)
		"coins2":
			Minibosses.gain_coin(G, pid, 2, label)
		"double_monster":
			return TnlAbilities.ask(G, pid, "rmb_room", own_monsters(G, pid), {"then": "double", "label": label}, "%s: choose a Monster Room to double" % label, label)
		"deactivate_opp":
			return TnlAbilities.ask(G, pid, "rmb_room", opponent_rooms(G, pid), {"then": "deactivate", "label": label}, "%s: choose a Room to deactivate" % label, label)
		"spike": # Spike niveau 2 : 2 degats au heros de cette salle
			var slot := int(ctx.get("slot", -1))
			if _hero_in_room(G, pid, slot):
				var a := TnlAbilities.adv(G)
				a["hp"] = int(a.get("hp", 0)) - 2
				_log(G, "%s: 2 damage to %s (discarded %s)." % [label, _label(a.get("hero", {})), _label(card)])
	return null

## Applique un effet a la salle choisie (ctx.then).
static func _room_target(G: Dictionary, pid: int, ctx: Dictionary, o: Dictionary) -> Variant:
	var tp := int(o.get("targetPlayerId", pid))
	var ri := int(o.get("roomIndex", -1))
	var rv = SpellEffects.find_room(G, tp, ri)
	if rv == null:
		return null
	var room: Dictionary = rv
	var label := str(ctx.get("label", "?"))
	match str(ctx.get("then", "")):
		"double": # les degats actuels s'ajoutent a eux-memes jusqu'a la fin du tour
			var dmg := BossEngine.room_damage_with_modifiers(G, _player(G, tp), ri, null)
			(SpellEffects._effects(G)["roomDamageBonus"] as Array).append({"playerId": tp, "roomIndex": ri, "amount": dmg})
			_log(G, "%s: the damage of %s is doubled until end of turn (+%d)." % [label, _label(room), dmg])
		"deactivate":
			(SpellEffects._effects(G)["deactivatedRooms"] as Array).append({"playerId": tp, "roomIndex": ri})
			_log(G, "%s: %s is deactivated until end of turn." % [label, _label(room)])
		"rebuild": # Rocky niveau 2 : la salle est traitee comme venant d'etre construite
			_log(G, "%s: %s is treated as just built." % [label, _label(room)])
			return RoomAbilities.on_build_room(G, pid, room)
		"living": # Living Trap : la salle Monster est detruite, le heros de la salle meurt
			var slot := int(ctx.get("slot", -1))
			var alive := _hero_in_room(G, pid, slot)
			TnlAbilities.destroy_room_at(G, tp, ri, label)
			if alive:
				var a := TnlAbilities.adv(G)
				a["hp"] = 0
				_log(G, "%s: %s is killed." % [label, _label(a.get("hero", {}))])
	return null

# --- IA (heuristiques maison) ----------------------------------------------------------------------------------------------------------

static func score_move(G: Dictionary, p: Dictionary, pid: int, mtype: String, args: Array) -> float:
	var coins := Minibosses.coins(p)
	var f := AiWiki.fate(G)
	var mine := bool(f["active"]) and int(f["owner"]) == pid
	match mtype:
		"rmbBoss":
			match str(args[0]):
				"RMB003": return 20.0 if coins >= 4 else -5.0
				"RMB006": # Ravenus : double une salle Monster devant le heros de mon donjon s'il survit autrement
					if mine and coins >= 2 and AiWiki.kills(f, int(f["best_monster"])):
						return 60.0
					return 20.0 if mine and coins >= 5 and int(f["margin"]) > 0 and int(f["monsters"]) > 0 else -5.0
				"RMB009": return 15.0 if coins >= 4 else -5.0
				"RMB012": # Kirax (2 Coins) : en construction, une icone de plus sur mon donjon si elle fait venir un heros que je tue
					if str(G.get("phase", "")) == "build" and coins >= 2 and _best_icon_gain(G, pid, pid) >= 1.0:
						return AiWiki.BUILD_FIRST
					return 10.0 if coins >= 5 else -5.0
				"RMB011": # Scott (je donne 1 Coin) : seulement si son +1 aux Traps fait mourir un heros qui blesserait son proprietaire sinon
					return 40.0 if bool(f["active"]) and int(f["owner"]) == int(args[1]) and AiWiki.saves(f, int(f["traps"])) else -10.0
			return -10.0
		"rmbPay": # Paywall : 1 Coin pour -1 a la salle, si cela sauve le heros qui blesserait son proprietaire
			return 30.0 if not mine and bool(f["active"]) and int(f["owner"]) == int(args[0]) and AiWiki.is_ahead(f, int(args[0]), int(args[1])) and AiWiki.saves(f, 1) else -10.0
		"rmbHand":
			var hand: Array = p.get("hand", [])
			var hid := str((hand[int(args[0])] as Dictionary).get("id", ""))
			if hid == "RMB035":
				return 12.0 if coins < 3 else 3.0
			if hid == "RMB027": # Shrooman Aviary : +3 au heros adverse qui meurt de justesse
				return 45.0 if not mine and AiWiki.saves(f, 3) else -5.0
			if hid == "RMB016": # Tomb of Terrors : seulement s'il y a dans les defausses autre chose qu'une autre Tomb of Terrors
				return 4.0 if tomb_options(G).any(func(o): return str(((o as Dictionary)["card"] as Dictionary).get("id", "")) != "RMB016") else -5.0
			return -5.0
	return 0.0

## Capacites de salle activees : valeur pour l'IA (RoomCalculator maison : utiles, sans risque pour soi). `idx` = index de la salle chez `pid` (-1 si inconnu).
static func score_activate(G: Dictionary, p: Dictionary, pid: int, rid: String, idx: int = -1) -> float:
	var phase := str(G.get("phase", ""))
	var f := AiWiki.fate(G)
	var mine := bool(f["active"]) and int(f["owner"]) == pid
	match rid:
		"RMB013": return 8.0
		"RMB015": return 15.0
		"RMB019": return 25.0 if phase == "adventure" else -5.0
		"RMB022": # Minotaur Catacombs : comme Warp Tube, le heros qui survit rejoue les salles deja traversees et y meurt
			return 75.0 if mine and idx > 0 and int(f["margin"]) > 0 and int(f["margin"]) - int(f["behind"]) <= 0 else -10.0
		"RMB026": # Training Camp : double la salle Monster qui fait mourir le heros de mon donjon
			return 60.0 if mine and AiWiki.kills(f, int(f["best_monster"])) else -5.0
		"RMB038": return 6.0
		"RMB042": return 4.0
		"RMB043": return 70.0
		"RMB044": return 6.0
		"RMB045": # Endless Gallery (construction) : une icone de tresor de plus fait venir un heros chez moi
			return AiWiki.BUILD_FIRST if phase == "build" and AiWiki.can_refill(G, p, pid) and _best_icon_gain(G, pid, pid) >= 1.0 else -5.0
		"RMB047": return 60.0
		"RMB052": return 3.0
		"RMB053": # The Keystone : une Coin par salle restante, quand des Coins servent (minibosses en main ou face cachee)
			var rooms := BossEngine.count_visible_rooms(p.get("dungeon", [])) - 1
			return AiWiki.BUILD_FIRST if phase == "build" and AiWiki.can_refill(G, p, pid) and rooms >= 3 and (not Minibosses.miniboss_cards_in_hand(p).is_empty() or Minibosses.facedown_count(p) > 0) else -5.0
		"RMB054": return 10.0
	return -10.0

## « Any treasure type » (Endless Gallery, Kirax) : les 4 types de base, plus Explorer quand Crash Landing est dans la partie.
static func icon_types(G: Dictionary) -> Array:
	return [1, 2, 3, 4, 5] if (G.get("sets", []) as Array).has("crash-landing") else [1, 2, 3, 4]

## Meilleur gain de leurre de `pid` si une icone (parmi les 4 types de base) s'ajoute au donjon de `tp`.
static func _best_icon_gain(G: Dictionary, pid: int, tp: int) -> float:
	var best := -99.0
	for t in icon_types(G):
		best = maxf(best, AiWiki.icon_gain(G, pid, tp, t))
	return best

## Le heros avance du donjon de `pid` de la salle `prev` vers `i` (Match._advance_adventure_room) : Foyer Elemental quand il quitte `prev` vivant ;
## Mageseeker niveau 3 : il saute la premiere salle. Renvoie l'index de salle a jouer.
static func on_advance(G: Dictionary, pid: int, prev: int, i: int) -> int:
	if prev >= 0:
		on_room_exit(G, pid, prev)
	elif prev == -1 and i == 0 and Minibosses.skips_first_room(G, pid):
		_log(G, "Mageseeker: the Hero skips the first Room.")
		return 1
	return i
