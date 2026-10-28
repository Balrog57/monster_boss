class_name IodAbilities
extends RefCounted
## Extension wiki « Implements of Destruction » (IOD : 24 Objets + 5 Boss), jouee seulement derriere la case wiki (pseudo-paquet `iod`).
## Ce sont des Objets du meme type que Tools of Hero-Kind : Power-Up porte par le heros (tant qu'il a l'Objet), Reward = capacite de Boss
## utilisable depuis le scorekeeping une fois l'Objet face visible. Le moteur des Objets est celui de ThkAbilities (attache, revelation, claim,
## useItem, choix « tnl-pick » a etape thk_iod_*) ; ce fichier n'ajoute que les cartes. Les 5 Boss montent de niveau par process_level_up.
## Sources, par priorite : docs/rules/rules.md (section Items), texte des cartes (cards.json, wiki). Pas de livret IOD officiel.
## IOD018 Stolen Blueprints : pas de sixieme salle (5 emplacements fixes, CardDB.DUNGEON_SLOTS) ; voir docs/rules/arbitrages-wiki.md.
## Sans Crash Landing, Match.new_match ecarte les Objets Explorer et Banseer Bivan (livret : « remove the Explorer items and the Boss »).

const SET_ID := "iod"

static func _p(G: Dictionary, pid: int) -> Dictionary:
	return TnlAbilities._player(G, pid)

static func _log(G: Dictionary, t: String, pub: String = "", owners: Array = []) -> void:
	TnlAbilities._log(G, t, pub, owners)

static func _label(c: Dictionary) -> String:
	return str(c.get("name", c.get("id", "?")))

static func _turn(G: Dictionary) -> int:
	return int(G.get("turn", 0))

static func _name(id: String) -> String:
	return ThkAbilities.item_name(id)

static func _list(G: Dictionary, key: String) -> Array:
	var b := ThkAbilities._bag(G)
	if not (b.get(key) is Array):
		b[key] = []
	return b[key] as Array

static func _is_iod(id: String) -> bool:
	return id.begins_with("IOD")

static func _hero_tag(G: Dictionary, h: Dictionary, key: String) -> bool:
	return int(h.get(key, -1)) == _turn(G)

static func has_boss(p: Dictionary, id: String) -> bool:
	return bool((p.get("iodBoss", {}) as Dictionary).get(id, false))

# --- utilitaires de cibles ---------------------------------------------------------------------------------------------------------

## Heros a l'entree (le heros actif en fait partie) des donjons de `pid` (-2 : tous), `except` : le donjon de `pid` exclu.
static func entrance_heroes(G: Dictionary, only: int = -2, except: int = -2) -> Array:
	var out: Array = []
	for opid in TnlAbilities._alive(G):
		if (only != -2 and int(opid) != only) or int(opid) == except:
			continue
		for h in (_p(G, int(opid)).get("entrance", []) as Array):
			out.append({"hero": h, "owner": int(opid)})
	return out

## Options « heros » ; `sign` +1 : aider un heros (le meilleur est celui d'un adversaire), -1 : le blesser (le meilleur est celui de mon donjon).
static func hero_options(G: Dictionary, pid: int, pool: Array, sign: float) -> Array:
	var opts: Array = []
	var a := TnlAbilities.adv(G)
	for e in pool:
		var h: Dictionary = e["hero"]
		var owner := int(e["owner"])
		var w := 0.0
		if owner >= 0:
			var active := not a.is_empty() and is_same(a.get("hero"), h)
			var theirs := owner != pid
			w = (5.0 if active else 1.0) * (1.0 if theirs else -1.0) * sign
		opts.append({"card": h, "ownerPid": owner, "label": "%s (%s)" % [_label(h), "town" if owner < 0 else "P%d" % (owner + 1)], "ai": w})
	return opts

static func treasure_types(G: Dictionary, pid: int) -> int:
	var seen := {}
	for t in BossEngine.dungeon_treasures(_p(G, pid), G):
		if int(t) >= 1:
			seen[int(t)] = true
	return seen.size()

static func _only_ordinary(G: Dictionary, pid: int) -> bool:
	for stack in (_p(G, pid).get("dungeon", []) as Array):
		var rv = BossEngine.active_room(stack)
		if rv != null and bool((rv as Dictionary).get("advanced", false)):
			return false
	return true

static func _highest_hp(G: Dictionary, except: Dictionary) -> int:
	var best := 0
	for h in (G.get("town", []) as Array):
		if not is_same(h, except):
			best = maxi(best, BossEngine.hero_hp(h))
	for e in entrance_heroes(G):
		if not is_same(e["hero"], except):
			best = maxi(best, RoomAbilities.current_hero_hp(G, int(e["owner"]), e["hero"]))
	return best

static func _deactivate(G: Dictionary, pid: int, i: int) -> void:
	(SpellEffects._effects(G)["deactivatedRooms"] as Array).append({"playerId": pid, "roomIndex": i})

static func _deactivated_of(G: Dictionary, pid: int) -> Array:
	return (SpellEffects._effects(G).get("deactivatedRooms", []) as Array).filter(func(e): return int((e as Dictionary).get("playerId", -1)) == pid)

## Salles Advanced visibles (sommets de pile) des donjons des adversaires de `pid`.
static func advanced_rooms(G: Dictionary, pid: int, only: int) -> Array:
	return TnlAbilities.room_options(G, "advanced", -1, -1, only).filter(func(o): return only >= 0 or int((o as Dictionary)["targetPlayerId"]) != pid)

# --- Objets : valeur, verification, effets ---------------------------------------------------------------------------------------------

static func value(id: String) -> float:
	match id:
		"IOD009", "IOD015", "IOD022", "IOD001":
			return 4.0
		"IOD012", "IOD013", "IOD004", "IOD003", "IOD019":
			return 3.0
	return 2.0

## Pure : pourquoi la capacite de Boss de l'Objet `id` n'est pas jouable maintenant ("" = jouable).
static func effect_check(G: Dictionary, pid: int, id: String) -> String:
	var p := _p(G, pid)
	var phase := str(G.get("phase", ""))
	var a := TnlAbilities.adv(G)
	match id:
		"IOD001": return "" if CardDB.total_wounds(p) > 0 and not ThkAbilities.all_heroes(G).is_empty() else "no Wound or no Hero"
		"IOD012": return "" if CardDB.total_souls(p, G) > 0 and not ThkAbilities.all_heroes(G).is_empty() else "no Soul or no Hero"
		"IOD013": return "" if not ThkAbilities.all_heroes(G).is_empty() else "no Hero"
		"IOD002": return "" if not ThkAbilities.room_targets(G, pid, "any", false).is_empty() else "no Room"
		"IOD003": return "" if not entrance_heroes(G, -2, pid).is_empty() else "no Hero at another dungeon's entrance"
		"IOD004": return "" if not ThkAbilities.room_targets(G, pid, "monster", false).is_empty() else "no Monster Room"
		"IOD005": return "" if not (p.get("hand", []) as Array).is_empty() else "empty hand"
		"IOD006": return "" if not entrance_heroes(G).is_empty() else "no Hero in a dungeon"
		"IOD008": return ""
		"IOD009": return "" if not _lich_sources(G).is_empty() and not ThkAbilities.all_heroes(G).is_empty() else "no face-down Hero or no target"
		"IOD010": return "" if not RoomAbilities.discard_card_options(G, "spell").is_empty() else "no Spell in the discard"
		"IOD014": return "" if not _magnet_options(G).is_empty() else "no icon"
		"IOD015": return "" if not _blast_room(G).is_empty() else "no Hero in a Room"
		"IOD016": return "" if not _map_options(G).is_empty() else "no dungeon with two Rooms"
		"IOD017": return "" if not _deactivated_of(G, pid).is_empty() else "no deactivated Room"
		"IOD019": return "" if TnlAbilities.spells_in_hand(p) > 0 else "no Spell to discard"
		"IOD020":
			if phase != "build":
				return "Build phase only"
			return "" if not (G.get("town", []) as Array).is_empty() else "no Hero in town"
		"IOD021":
			if phase != "build":
				return "Build phase only"
			return "" if not advanced_rooms(G, pid, -1).is_empty() else "no opponent Advanced Room"
		"IOD022":
			var pool := entrance_heroes(G, -2, pid)
			return "" if not pool.is_empty() else "no Hero in an opponent's dungeon"
		"IOD024": return "" if not _saucer_options(G).is_empty() else "no Advanced Room in the Room deck"
		"IOD007":
			for o in TnlAbilities._opponents(G, pid):
				if TnlAbilities.spells_in_hand(_p(G, int(o))) > 0:
					return ""
			return "no opponent holds a Spell"
		"IOD011": return "" if not _heart_options(G, pid).is_empty() else "no Soul in an opponent's scorekeeping area"
		"IOD018": return "" if not TnlAbilities.hand_options(p, "room").is_empty() else "no Room in hand"
		"IOD023": return "" if not (p.get("dungeon", []) as Array).is_empty() else "no Room"
	return "unknown Item"

static func _lich_sources(G: Dictionary) -> Array:
	var out: Array = []
	for opid in TnlAbilities._alive(G):
		for h in TnlAbilities._face_down_heroes(_p(G, int(opid))):
			out.append({"hero": h, "owner": int(opid)})
	return out

static func _magnet_options(G: Dictionary) -> Array:
	var out: Array = []
	for opid in TnlAbilities._alive(G):
		var seen := {}
		for t in BossEngine.dungeon_treasures(_p(G, int(opid)), G):
			if int(t) >= 1:
				seen[int(t)] = true
		for t in seen:
			out.append({"targetPlayerId": int(opid), "treasure": int(t)})
	return out

static func _map_options(G: Dictionary) -> Array:
	var out: Array = []
	for opid in TnlAbilities._alive(G):
		if (_p(G, int(opid)).get("dungeon", []) as Array).size() >= 2:
			out.append({"targetPlayerId": int(opid)})
	return out

static func _saucer_options(G: Dictionary) -> Array:
	var out: Array = []
	var deck: Array = (G.get("decks", {}) as Dictionary).get("rooms", [])
	for i in deck.size():
		if bool((deck[i] as Dictionary).get("advanced", false)):
			out.append({"card": deck[i], "pileIndex": i, "label": _label(deck[i]), "ai": TnlAbilities._ai_value(deck[i])})
	return out

## {room, owner, index} de la salle du heros actif (n'importe quel donjon), {} sinon.
static func _blast_room(G: Dictionary) -> Dictionary:
	var a := TnlAbilities.adv(G)
	if a.is_empty() or bool(a.get("roomGone", false)) or int(a.get("hp", 0)) <= 0:
		return {}
	var owner := int(a.get("playerId", -1))
	var d: Array = _p(G, owner).get("dungeon", [])
	var ri := int(a.get("roomIndex", -1))
	if ri < 0 or ri >= d.size() or BossEngine.active_room(d[ri]) == null:
		return {}
	return {"owner": owner, "index": ri}

static func run_effect(G: Dictionary, pid: int, id: String) -> Variant:
	var p := _p(G, pid)
	var name := _name(id)
	match id:
		"IOD001": # Mega Hammer : +2 par Blessure
			var n1 := 2 * CardDB.total_wounds(p)
			return TnlAbilities.ask(G, pid, "thk_iod_hero", hero_options(G, pid, ThkAbilities.all_heroes(G), 1.0), {"id": id, "n": n1}, "%s: choose a Hero (+%d Health)" % [name, n1], name)
		"IOD012": # Angel Wings : +X, X = vos Ames
			var n2 := CardDB.total_souls(p, G)
			return TnlAbilities.ask(G, pid, "thk_iod_hero", hero_options(G, pid, ThkAbilities.all_heroes(G), 1.0), {"id": id, "n": n2}, "%s: choose a Hero (+%d Health)" % [name, n2], name)
		"IOD013": # Divining Rod : +1 par type de tresor
			var n3 := treasure_types(G, pid)
			return TnlAbilities.ask(G, pid, "thk_iod_hero", hero_options(G, pid, ThkAbilities.all_heroes(G), 1.0), {"id": id, "n": n3}, "%s: choose a Hero (+%d Health)" % [name, n3], name)
		"IOD002": # Minotaur's Mantle : une salle traversee deux fois
			return ThkAbilities._ask_room_step(G, pid, "thk_iod_room", id, ThkAbilities.room_targets(G, pid, "any", false), "%s: choose a Room all Heroes pass through twice" % name)
		"IOD004": # Tamer's Whip : +X a une salle Monster, X = salles Monster
			return ThkAbilities._ask_room_step(G, pid, "thk_iod_room", id, ThkAbilities.room_targets(G, pid, "monster", false), "%s: choose a Monster Room (+%d)" % [name, ThkAbilities.monster_rooms(G, pid)])
		"IOD003":
			return TnlAbilities.ask(G, pid, "thk_iod_hero", hero_options(G, pid, entrance_heroes(G, -2, pid), 1.0), {"id": id, "n": 0}, "%s: choose a Hero at another player's entrance (ignores the last three Rooms)" % name, name)
		"IOD006":
			return TnlAbilities.ask(G, pid, "thk_iod_hero", hero_options(G, pid, entrance_heroes(G), 1.0), {"id": id, "n": 0}, "%s: choose a Hero in a dungeon (skips the next Room)" % name, name)
		"IOD022":
			return TnlAbilities.ask(G, pid, "thk_iod_hero", hero_options(G, pid, entrance_heroes(G, -2, pid), 1.0), {"id": id, "n": 0}, "%s: choose a Hero in an opponent's dungeon (ignores Advanced Room damage)" % name, name)
		"IOD005": # Surprise Box : defausse la main, repioche autant de salles et de sorts
			var rooms := ThkAbilities._hand_cards(p, "room")
			var spells := ThkAbilities._hand_cards(p, "spell")
			for c in rooms + spells:
				TnlAbilities.discard_from_hand(G, pid, c)
			TnlAbilities.draw_logged(G, pid, "rooms", rooms.size(), name)
			TnlAbilities.draw_logged(G, pid, "spells", spells.size(), name)
		"IOD008": # Flame of Achoom : vos salles Mage donnent +1 aux voisines
			_list(G, "iodMage").append(pid)
			_log(G, "%s: until end of turn, player %d's Mage Rooms give +1 to adjacent Rooms." % [name, pid + 1])
		"IOD009": # Lich Crown : un heros face cachee (la source), un autre heros subit autant de degats que sa Sante
			var opts: Array = []
			for e in _lich_sources(G):
				var h: Dictionary = e["hero"]
				opts.append({"card": h, "label": "%s (P%d, Health %d)" % [_label(h), int(e["owner"]) + 1, BossEngine.hero_base_hp(h)], "ai": float(BossEngine.hero_base_hp(h))})
			return TnlAbilities.ask(G, pid, "thk_iod_lich1", opts, {}, "%s: choose a face-down Hero" % name, name)
		"IOD010": # Shining Armor : un sort de la defausse
			var sopts := RoomAbilities.discard_card_options(G, "spell")
			for o in sopts:
				(o as Dictionary)["label"] = _label((o as Dictionary)["card"])
				(o as Dictionary)["ai"] = TnlAbilities._ai_value((o as Dictionary)["card"])
			return TnlAbilities.ask(G, pid, "thk_iod_spell", sopts, {}, "%s: take a Spell from the discard pile" % name, name)
		"IOD014": # Super Magnet : un joueur et un type de tresor ignores jusqu'a la fin du tour
			var mopts: Array = []
			for m in _magnet_options(G):
				var md: Dictionary = m
				var tq := int(md["targetPlayerId"])
				var cnt := BossEngine.treasure_count(_p(G, tq), int(md["treasure"]), G)
				md["label"] = "P%d %s (%d)" % [tq + 1, CardDB.TREASURE_NAMES[int(md["treasure"])], cnt]
				md["ai"] = float(cnt) * (-1.0 if tq == pid else 1.0)
				mopts.append(md)
			return TnlAbilities.ask(G, pid, "thk_iod_magnet", mopts, {}, "%s: choose a player and a treasure type to ignore" % name, name)
		"IOD015": # Blast Box : detruit la salle d'un heros, qui meurt
			var br := _blast_room(G)
			var a := TnlAbilities.adv(G)
			TnlAbilities.destroy_room_at(G, int(br["owner"]), int(br["index"]), name)
			a["hp"] = mini(int(a.get("hp", 0)), 0)
			_log(G, "%s: %s is killed." % [name, _label(a["hero"])])
		"IOD016": # Secret Map : echange la premiere et la derniere salle d'un donjon
			var qopts: Array = []
			for m in _map_options(G):
				var qd: Dictionary = m
				var qp := int(qd["targetPlayerId"])
				qd["label"] = "Dungeon of player %d" % (qp + 1)
				qd["ai"] = 1.0 if qp != pid else 0.0
				qopts.append(qd)
			return TnlAbilities.ask(G, pid, "thk_iod_map", qopts, {}, "%s: choose a dungeon (first and last Rooms are switched)" % name, name)
		"IOD017": # Antifreeze : reactive les salles, un sort par salle
			var mine := _deactivated_of(G, pid)
			var arr: Array = SpellEffects._effects(G)["deactivatedRooms"]
			for e in mine:
				arr.erase(e)
			_log(G, "%s: %d Room(s) reactivated." % [name, mine.size()])
			TnlAbilities.draw_logged(G, pid, "spells", mine.size(), name)
		"IOD019": # Pandora's Box : defausser un sort pour la retourner face cachee (le retournement est l'usage de l'Objet)
			var dopts: Array = []
			for c in ThkAbilities._hand_cards(p, "spell"):
				dopts.append({"card": c, "label": _label(c as Dictionary), "ai": -TnlAbilities._ai_value(c as Dictionary)})
			return TnlAbilities.ask(G, pid, "thk_iod_pandora", dopts, {}, "%s: discard a Spell" % name, name)
		"IOD020": # Doppelganger Cloak : un heros de la ville n'est leurre que par un type de tresor
			var lopts: Array = []
			for h in (G.get("town", []) as Array):
				for t in range(1, 6):
					lopts.append({"card": h, "type": t, "label": "%s -> %s" % [_label(h), CardDB.TREASURE_NAMES[t]], "ai": _lure_value(G, pid, h, t)})
			return TnlAbilities.ask(G, pid, "thk_iod_lure", lopts, {}, "%s: choose a Hero in town and the only treasure type that lures it" % name, name)
		"IOD021": # Stun Gun : chaque adversaire renvoie une salle Advanced dans sa main
			var chs: Array = []
			for o in TnlAbilities._opponents(G, pid):
				var ropts := advanced_rooms(G, pid, int(o))
				for r in ropts:
					(r as Dictionary)["ai"] = -float((r as Dictionary).get("ai", 0.0))
				if not ropts.is_empty():
					chs.append(TnlAbilities.ask(G, int(o), "thk_iod_stun", ropts, {}, "%s: choose one of your Advanced Rooms to return to your hand" % name, name))
			return TnlAbilities.flush(G, chs)
		"IOD024": # Flying Saucer : une salle Advanced de la pioche de salles
			return TnlAbilities.ask(G, pid, "thk_iod_search", _saucer_options(G), {}, "%s: choose an Advanced Room from the Room deck" % name, name)
		"IOD007": # Crystal Ball : chaque adversaire qui a un sort en revele un (public), vous en prenez un
			var holders: Array = []
			for o in TnlAbilities._opponents(G, pid):
				if TnlAbilities.spells_in_hand(_p(G, int(o))) > 0:
					holders.append(int(o))
			ThkAbilities._bag(G)["iodCball"] = {"owner": pid, "left": holders.size(), "revealed": []}
			var reveals: Array = []
			for q in holders:
				var ropts: Array = []
				for c in ThkAbilities._hand_cards(_p(G, q), "spell"):
					ropts.append({"card": c, "label": _label(c as Dictionary), "ai": -TnlAbilities._ai_value(c as Dictionary)})
				reveals.append(TnlAbilities.ask(G, q, "thk_iod_cball", ropts, {}, "%s: reveal one of your Spells" % name, name))
			return TnlAbilities.flush(G, reveals)
		"IOD011": # Heart Container : un heros en blessure d'un adversaire revient a l'entree de son donjon avec +3
			return TnlAbilities.ask(G, pid, "thk_iod_heart", _heart_options(G, pid), {}, "%s: choose a Soul in an opponent's scorekeeping area (the Hero returns to their entrance with +3 Health)" % name, name)
		"IOD018": # Stolen Blueprints : construction immediate supplementaire, detruite en fin de tour
			# shortcut: pas de sixieme salle (5 emplacements fixes, CardDB.DUNGEON_SLOTS) : la salle se pose dans les 5 emplacements, y compris par-dessus une salle ; a revoir si un 6e emplacement existe.
			_list(G, "iodBp").append(pid)
			return TnlAbilities.build_choice(G, pid, "any", name)
		"IOD023": # Laser Drill : toutes vos salles sont traitees comme venant d'etre decouvertes
			# shortcut: seules les salles presentes maintenant sont traitees (pas celles posees plus tard dans le tour).
			var dr: Array = p.get("dungeon", [])
			for i in range(dr.size() - 1, -1, -1):
				if i < dr.size():
					_uncover_triggers(G, pid, i)
			_log(G, "%s: all of player %d's Rooms are treated as just uncovered." % [name, pid + 1])
	return null

## Doppelganger Cloak : un heros de la ville leurre vers `pid` par le type `t` (l'IA l'envoie chez un adversaire, pas chez elle).
static func _lure_value(G: Dictionary, pid: int, hero: Dictionary, t: int) -> float:
	var best := -1
	var best_n := -1
	var tied := false
	for q in TnlAbilities._alive(G):
		var n := BossEngine.treasure_count(_p(G, int(q)), t, G)
		if n > best_n:
			best_n = n
			best = int(q)
			tied = false
		elif n == best_n:
			tied = true
	if tied or best < 0:
		return -1.0
	var wounds := float(BossEngine.hero_wounds(hero))
	return (wounds if best != pid else -wounds) + float(best_n) * 0.01

# --- resolution des choix (« tnl-pick » a etape thk_iod_*) -------------------------------------------------------------------------------

static func resolve_pick(G: Dictionary, pid: int, pc: Dictionary, idx: int) -> Variant:
	var opts: Array = pc.get("options", [])
	var ctx: Dictionary = pc.get("ctx", {}) as Dictionary
	var step := str(pc.get("step", ""))
	var p := _p(G, pid)
	var o: Dictionary = (opts[idx] as Dictionary) if idx >= 0 and idx < opts.size() else {}
	var a := TnlAbilities.adv(G)
	match step:
		"thk_iod_hero":
			var hero: Dictionary = o.get("card", {})
			var id := str(ctx.get("id", ""))
			match id:
				"IOD001", "IOD012", "IOD013":
					TnlAbilities.add_hero_hp(G, hero, int(ctx.get("n", 0)))
					_log(G, "%s: %s gets +%d Health until end of turn." % [_name(id), _label(hero), int(ctx.get("n", 0))])
				"IOD003":
					hero["iodBow"] = _turn(G)
					_log(G, "%s: %s ignores the last three Rooms of the dungeon." % [_name(id), _label(hero)])
				"IOD006":
					if not a.is_empty() and is_same(a.get("hero"), hero):
						a["thkSkip"] = true
					else:
						hero["iodSkip"] = true
					_log(G, "%s: %s skips the next Room it would enter." % [_name(id), _label(hero)])
				"IOD022":
					hero["iodNoAdv"] = _turn(G)
					_log(G, "%s: %s ignores damage from Advanced Rooms until end of turn." % [_name(id), _label(hero)])
		"thk_iod_room":
			var tp := int(o.get("targetPlayerId", -1))
			var ri := int(o.get("roomIndex", -1))
			var rv = SpellEffects.find_room(G, tp, ri)
			if rv == null:
				return null
			match str(ctx.get("id", "")):
				"IOD002":
					_list(G, "iodTwice").append({"playerId": tp, "roomIndex": ri})
					_log(G, "%s: Heroes pass through %s twice until end of turn." % [_name("IOD002"), _label(rv as Dictionary)])
				"IOD004":
					var x := ThkAbilities.monster_rooms(G, pid)
					(SpellEffects._effects(G)["roomDamageBonus"] as Array).append({"playerId": tp, "roomIndex": ri, "amount": x})
					_log(G, "%s: %s gets +%d damage until end of turn." % [_name("IOD004"), _label(rv as Dictionary), x])
		"thk_iod_lich1":
			var srcs := ThkAbilities.all_heroes(G)
			var hopts: Array = []
			var x2 := BossEngine.hero_base_hp(o.get("card", {}))
			for e in srcs:
				if is_same(e["hero"], o.get("card", {})):
					continue
				hopts.append_array(hero_options(G, pid, [e], -1.0))
			for ho in hopts:
				(ho as Dictionary)["label"] = "%s (-%d)" % [str((ho as Dictionary).get("label", "")), x2]
			return TnlAbilities.ask(G, pid, "thk_iod_lich2", hopts, {"n": x2}, "%s: choose a Hero to take %d damage" % [_name("IOD009"), x2], _name("IOD009"))
		"thk_iod_lich2":
			var victim: Dictionary = o.get("card", {})
			var owner := int(o.get("ownerPid", -1))
			var dmg := int(ctx.get("n", 0))
			RoomAbilities.hero_hp_change(G, owner, victim, -dmg)
			_log(G, "%s: %s takes %d damage." % [_name("IOD009"), _label(victim), dmg])
			if RoomAbilities.current_hero_hp(G, owner, victim) <= 0:
				return ThkAbilities.kill_hero(G, pid, victim, owner)
		"thk_iod_spell":
			var got = RoomAbilities.take_discard_card(G, p, o)
			if got != null:
				_log(G, "%s: %s taken from the discard pile." % [_name("IOD010"), _label(got as Dictionary)])
		"thk_iod_magnet":
			_list(G, "iodIgnore").append({"playerId": int(o.get("targetPlayerId", -1)), "treasure": int(o.get("treasure", 0))})
			_log(G, "%s: Heroes ignore the %s icons of player %d's dungeon until end of turn." % [_name("IOD014"), CardDB.TREASURE_NAMES[int(o.get("treasure", 0))], int(o.get("targetPlayerId", -1)) + 1])
		"thk_iod_map":
			var qp := int(o.get("targetPlayerId", -1))
			var n := (_p(G, qp).get("dungeon", []) as Array).size()
			if n >= 2 and TnlAbilities.swap_stacks(G, qp, 0, n - 1):
				_log(G, "%s: the first and last Rooms of player %d's dungeon are switched." % [_name("IOD016"), qp + 1])
		"thk_iod_pandora":
			TnlAbilities.discard_from_hand(G, pid, o.get("card", {}))
			_log(G, "%s: a Spell is discarded, the Item is turned face-down." % _name("IOD019"))
		"thk_iod_lure":
			var lh: Dictionary = o.get("card", {})
			lh["iodLure"] = int(o.get("type", 0))
			lh["iodLureTurn"] = _turn(G)
			_log(G, "%s: %s is lured only by %s until end of turn." % [_name("IOD020"), _label(lh), CardDB.TREASURE_NAMES[int(o.get("type", 0))]])
		"thk_iod_stun":
			return_room_to_hand(G, int(o.get("targetPlayerId", -1)), int(o.get("roomIndex", -1)), _name("IOD021"))
		"thk_iod_search":
			var deck: Array = (G.get("decks", {}) as Dictionary).get("rooms", [])
			var pi := int(o.get("pileIndex", -1))
			if pi >= 0 and pi < deck.size() and is_same(deck[pi], o.get("card", {})):
				var c: Dictionary = deck[pi]
				deck.remove_at(pi)
				(p["hand"] as Array).append(c)
				_log(G, "%s: %s is put into player %d's hand." % [_name("IOD024"), _label(c), pid + 1])
		"thk_iod_cball": # Crystal Ball : un adversaire revele un sort (public) ; le dernier ouvre le choix du proprietaire
			var cb: Dictionary = ThkAbilities._bag(G).get("iodCball", {}) as Dictionary
			if cb.is_empty():
				return null
			var shown: Dictionary = o.get("card", {})
			(cb["revealed"] as Array).append({"holder": pid, "card": shown})
			_log(G, "%s: player %d reveals %s." % [_name("IOD007"), pid + 1, _label(shown)])
			cb["left"] = int(cb["left"]) - 1
			if int(cb["left"]) > 0:
				return null
			var topts: Array = []
			for e in (cb["revealed"] as Array):
				topts.append({"card": e["card"], "holder": int(e["holder"]), "label": "%s (P%d)" % [_label(e["card"] as Dictionary), int(e["holder"]) + 1], "ai": TnlAbilities._ai_value(e["card"] as Dictionary)})
			return TnlAbilities.ask(G, int(cb["owner"]), "thk_iod_cball_take", topts, {}, "%s: choose a revealed Spell to put into your hand" % _name("IOD007"), _name("IOD007"))
		"thk_iod_cball_take":
			var took: Dictionary = o.get("card", {})
			var from_pid := int(o.get("holder", -1))
			ThkAbilities._bag(G).erase("iodCball")
			if from_pid >= 0 and TnlAbilities.take_from_hand(G, from_pid, took):
				(p["hand"] as Array).append(took)
				_log(G, "%s: %s goes from player %d's hand into player %d's hand." % [_name("IOD007"), _label(took), from_pid + 1, pid + 1])
		"thk_iod_heart": # Heart Container (Reward) : l'ame d'un adversaire disparait, le heros revient a l'entree de son donjon avec +3 PV
			var back: Dictionary = o.get("card", {})
			var bq := int(o.get("ownerPid", -1))
			if bq < 0 or not TnlAbilities.remove_soul_hero(_p(G, bq), back):
				return null
			(_p(G, bq)["entrance"] as Array).append(back)
			back["heartHp"] = int(back.get("heartHp", 0)) + 3 # sur la carte : survit aux tours (les effets du tour sont remis a zero), lu par hero_health_with_modifiers
			_log(G, "%s: %s returns to the entrance of player %d's dungeon with +3 Health." % [_name("IOD011"), _label(back), bq + 1])
		"thk_iod_mal_item": # Malakill : l'Objet (face visible ou cachee), puis la salle Monster
			var rooms := TnlAbilities.room_options(G, "monster")
			if rooms.is_empty():
				_log(G, "Malakill: no Monster Room.")
				return null
			for r in rooms:
				(r as Dictionary)["ai"] = float(int(((r as Dictionary)["card"] as Dictionary).get("damage", 0))) * (1.0 if int((r as Dictionary)["targetPlayerId"]) == pid else -1.0)
			return TnlAbilities.ask(G, pid, "thk_iod_mal_room", rooms, {"item": o.get("card", {})}, "Malakill: choose a Monster Room to put the Item under (+3)", "Malakill")
		"thk_iod_mal_room":
			var mitem: Dictionary = ctx.get("item", {})
			var host = SpellEffects.find_room(G, int(o.get("targetPlayerId", -1)), int(o.get("roomIndex", -1)))
			var mitems: Array = p.get("items", [])
			var mat := -1
			for k in mitems.size():
				if is_same(mitems[k], mitem):
					mat = k
			if host == null or mat < 0:
				return null
			if (host as Dictionary).has("iodUnder"):
				release_under(G, host as Dictionary)
			mitems.remove_at(mat)
			(host as Dictionary)["iodUnder"] = {"owner": pid, "item": mitem}
			_log(G, "Malakill: an Item is placed under %s (+3 until it is destroyed or covered)." % _label(host as Dictionary), "Malakill: an Item is placed under %s (+3)." % _label(host as Dictionary))
		"thk_iod_claim2": # Banseer Bivan : trois Objets pretendent a deux places face visible, l'un d'eux part face cachee
			var item: Dictionary = ctx.get("item", {})
			var down: Dictionary = o.get("card", {})
			if is_same(down, item):
				ThkAbilities.add_item(G, pid, item, true)
			else:
				down["faceDown"] = true
				ThkAbilities.add_item(G, pid, item, false)
		"thk_iod_take":
			var src: Dictionary = o.get("card", {})
			var taken: Dictionary = {}
			if int(o.get("fromPid", -2)) == -1: # un heros de la ville : l'Objet quitte le heros
				taken = ThkAbilities.detach(o.get("hero", {}))
			else:
				var items: Array = _p(G, int(o.get("fromPid", -1))).get("items", [])
				if items.has(src) and not bool(src.get("faceDown", false)):
					items.erase(src)
					taken = src
			if not taken.is_empty():
				place_face_up(G, pid, taken)
	return null

## Une salle revient dans la main de son proprietaire (Stun Gun) : elle quitte le donjon sans etre « detruite » pour ses declencheurs.
static func return_room_to_hand(G: Dictionary, owner: int, idx: int, label: String) -> bool:
	var op := _p(G, owner)
	var d = BossEngine.destroy_room(op, idx, G, false)
	if d == null:
		return false
	var card: Dictionary = d
	for k in ["usedThisTurn", "extraTreasures", "tnl"]:
		card.erase(k)
	(op["hand"] as Array).append(card)
	_log(G, "%s: %s returns to player %d's hand." % [label, _label(card), owner + 1])
	return true

# --- scorekeeping : Objets face visible ---------------------------------------------------------------------------------------------------

static func face_up_limit(p: Dictionary) -> int:
	return 2 if has_boss(p, "IOD025") else 1

static func face_up_items(p: Dictionary) -> Array:
	return (p.get("items", []) as Array).filter(func(it): return not bool((it as Dictionary).get("faceDown", false)))

## Place `item` face visible chez `pid` : l'excedent face visible repart face cachee (le moins utile d'abord).
static func place_face_up(G: Dictionary, pid: int, item: Dictionary) -> void:
	var p := _p(G, pid)
	var ups := face_up_items(p)
	while ups.size() >= face_up_limit(p):
		var worst: Dictionary = ups[0]
		for it in ups:
			if ThkAbilities.item_value(it) < ThkAbilities.item_value(worst):
				worst = it
		worst["faceDown"] = true
		ups.erase(worst)
		_log(G, "%s is turned face-down." % _label(worst))
	ThkAbilities.add_item(G, pid, item, false)

## Objet gagne (ThkAbilities.claim_item) : Pandora's Box et Banseer Bivan changent les places face visible. Renvoie [pris en charge ?, choix].
static func claim(G: Dictionary, pid: int, item: Dictionary) -> Array:
	var p := _p(G, pid)
	for it in face_up_items(p):
		if str((it as Dictionary).get("id", "")) == "IOD019": # Pandora's Box face visible : tout nouvel Objet part face cachee
			ThkAbilities.add_item(G, pid, item, true)
			return [true, null]
	if str(item.get("id", "")) == "IOD019": # « You must take this Item face-up »
		place_face_up(G, pid, item)
		return [true, null]
	if face_up_limit(p) < 2:
		return [false, null]
	var ups := face_up_items(p)
	if ups.size() < 2:
		ThkAbilities.add_item(G, pid, item, false)
		return [true, null]
	var opts: Array = []
	for it in ups + [item]:
		opts.append({"card": it, "label": "Turn %s face-down" % _label(it as Dictionary), "ai": -ThkAbilities.item_value(it as Dictionary)})
	return [true, TnlAbilities.ask(G, pid, "thk_iod_claim2", opts, {"item": item}, "You claim %s: choose which Item goes face-down" % _label(item), _label(item))]

## Franz : chaque usage de la capacite de Boss d'un Objet fait piocher un sort.
static func on_item_used(G: Dictionary, pid: int) -> void:
	if has_boss(_p(G, pid), "IOD027"):
		TnlAbilities.draw_logged(G, pid, "spells", 1, "Franz")

# --- Boss : montee de niveau --------------------------------------------------------------------------------------------------------------

static func level_up(G: Dictionary, pid: int, p: Dictionary, boss: Dictionary) -> Variant:
	var flags: Dictionary = p.get("iodBoss", {}) as Dictionary
	p["iodBoss"] = flags
	var id := str(boss.get("id", ""))
	flags[id] = true
	var name := str(boss.get("name", id))
	match id:
		"IOD028": # Lady Vix : un Objet face visible d'un heros de la ville ou d'un autre joueur
			var opts: Array = []
			for h in (G.get("town", []) as Array):
				var hi := ThkAbilities.item_of(h)
				if not hi.is_empty():
					opts.append({"card": hi, "hero": h, "fromPid": -1, "label": "%s (on %s)" % [_label(hi), _label(h)], "ai": ThkAbilities.item_value(hi)})
			opts.append_array(_other_items(G, pid))
			return TnlAbilities.ask(G, pid, "thk_iod_take", opts, {}, "%s: take a face-up Item from a Hero in town or another player" % name, name)
		"IOD029": # Umbra : un Objet face visible de n'importe quel scorekeeping
			return TnlAbilities.ask(G, pid, "thk_iod_take", _other_items(G, pid), {}, "%s: choose a face-up Item" % name, name)
		"IOD026": # Malakill : un de vos Objets (visible ou cache) sous une salle Monster, +3 tant qu'elle n'est ni detruite ni couverte
			var mopts: Array = []
			for it in (p.get("items", []) as Array):
				mopts.append({"card": it, "label": _label(it as Dictionary) if not bool((it as Dictionary).get("faceDown", false)) else "%s (face-down)" % _label(it as Dictionary), "ai": -ThkAbilities.item_value(it as Dictionary)})
			if mopts.is_empty():
				_log(G, "%s: level up, but no Item to place." % name)
			return TnlAbilities.ask(G, pid, "thk_iod_mal_item", mopts, {}, "%s: choose one of your Items to place under a Monster Room" % name, name)
		_:
			_log(G, "%s: level up (%s)" % [name, str(boss.get("levelUpDesc", ""))])
	return null

static func _other_items(G: Dictionary, pid: int) -> Array:
	var opts: Array = []
	for q in TnlAbilities._alive(G):
		if int(q) == pid:
			continue
		for it in face_up_items(_p(G, int(q))):
			opts.append({"card": it, "fromPid": int(q), "label": "%s (P%d)" % [_label(it as Dictionary), int(q) + 1], "ai": ThkAbilities.item_value(it as Dictionary)})
	return opts

# --- crochets du moteur ----------------------------------------------------------------------------------------------------------------------

## Power-Up au debut de l'aventure du heros `hero` chez `pid` : PV supplementaires (`hp` = PV deja acquis).
static func on_hero_start(G: Dictionary, pid: int, hero: Dictionary, hp: int) -> int:
	var id := ThkAbilities.item_id(hero)
	var p := _p(G, pid)
	var name := _name(id)
	match id:
		"IOD001": # Mega Hammer : double la Sante
			_log(G, "%s: %s's Health is doubled." % [name, _label(hero)])
			return maxi(hp, 0)
		"IOD012":
			var s := CardDB.total_souls(p, G)
			_log(G, "%s: %s gets +%d Health." % [name, _label(hero), s])
			return s
		"IOD013":
			var t := treasure_types(G, pid)
			_log(G, "%s: %s gets +%d Health." % [name, _label(hero), t])
			return t
		"IOD020": # Doppelganger Cloak : la plus haute Sante (modifiee) de la ville et des donjons
			var best := _highest_hp(G, hero)
			if best > hp:
				_log(G, "%s: %s has Health %d." % [name, _label(hero), best])
				return best - hp
		"IOD024": # Flying Saucer
			if _only_ordinary(G, pid):
				_log(G, "%s: %s gets +3 Health." % [name, _label(hero)])
				return 3
		"IOD002": # Minotaur's Mantle : la premiere salle Fighter est desactivee
			var d: Array = p.get("dungeon", [])
			for i in d.size():
				var rv = BossEngine.active_room(d[i])
				if rv != null and not bool((rv as Dictionary).get("faceDown", false)) and BossEngine.room_treasures(rv as Dictionary).has(2) and not BossEngine.is_room_deactivated(G, pid, i):
					_deactivate(G, pid, i)
					_log(G, "%s: %s is deactivated until end of turn." % [name, _label(rv as Dictionary)])
					break
		"IOD014": # Super Magnet : les salles a deux icones ou plus sont desactivees
			var dm: Array = p.get("dungeon", [])
			for i in dm.size():
				var rm = BossEngine.active_room(dm[i])
				if rm != null and not bool((rm as Dictionary).get("faceDown", false)) and BossEngine.room_treasures(rm as Dictionary).size() >= 2 and not BossEngine.is_room_deactivated(G, pid, i):
					_deactivate(G, pid, i)
					_log(G, "%s: %s is deactivated until end of turn." % [name, _label(rm as Dictionary)])
		"IOD017": # Antifreeze : les salles desactivees sont detruites
			var idxs: Array = []
			for e in _deactivated_of(G, pid):
				idxs.append(int((e as Dictionary).get("roomIndex", -1)))
			idxs.sort()
			idxs.reverse()
			for i in idxs:
				TnlAbilities.destroy_room_at(G, pid, i, name)
		"IOD007": # Crystal Ball : tous les joueurs revelent leurs sorts ; vous defaussez les votres qu'un adversaire a aussi
			var seen := {}
			for q in TnlAbilities._alive(G):
				var names: Array = []
				for c in ThkAbilities._hand_cards(_p(G, int(q)), "spell"):
					names.append(_label(c as Dictionary))
					if int(q) != pid:
						seen[str((c as Dictionary).get("id", ""))] = true
				_log(G, "%s: player %d reveals %s." % [name, int(q) + 1, ", ".join(names) if not names.is_empty() else "no Spell"])
			for c in ThkAbilities._hand_cards(p, "spell"):
				if seen.has(str((c as Dictionary).get("id", ""))) and TnlAbilities.discard_from_hand(G, pid, c as Dictionary):
					_log(G, "%s: %s matches a revealed Spell and is discarded." % [name, _label(c as Dictionary)])
		"IOD023": # Laser Drill : de chaque pile, une salle couverte remonte au sommet
			# shortcut: la salle couverte est choisie automatiquement (la plus forte en degats) ; ouvrir un choix avant la premiere salle si un humain doit decider.
			var dd: Array = p.get("dungeon", [])
			for i in range(dd.size() - 1, -1, -1):
				if i >= dd.size() or (dd[i] as Array).size() < 2:
					continue
				var stack: Array = dd[i]
				var pick := 0
				for k in range(stack.size() - 1):
					if int((stack[k] as Dictionary).get("damage", 0)) > int((stack[pick] as Dictionary).get("damage", 0)):
						pick = k
				RoomAbilities.uncover_move_to_top(G, pid, {"roomIndex": i, "depth": pick, "card": stack[pick]}) # declenche aussi les effets TNL (fire_uncover)
			_log(G, "%s: a covered Room of each stack is brought to the top." % name)
		"IOD019": # Pandora's Box : peut tuer un autre heros de l'entree
			var kopts: Array = []
			for h in (p.get("entrance", []) as Array):
				if not is_same(h, hero):
					kopts.append({"card": h, "ownerPid": pid, "label": _label(h as Dictionary), "ai": 5.0 + float(BossEngine.hero_souls(h as Dictionary))})
			TnlAbilities.emit(G, TnlAbilities.ask(G, pid, "thk_kill", kopts, {}, "%s: you may kill another Hero at the entrance" % name, name, true))
	return 0

## Degats d'une salle `r` (avant les bonus et les malus) : Tamer's Whip fixe a 1 la base des salles Monster tant qu'un de ses heros est a l'entree.
static func base_damage(G: Dictionary, pid: int, r: Dictionary, dmg: int) -> int:
	if str(r.get("type", "")) != "monster":
		return dmg
	for h in (_p(G, pid).get("entrance", []) as Array):
		if ThkAbilities.item_id(h) == "IOD004":
			return 1
	return dmg

## Flame of Achoom : le heros ignore le texte des salles qui modifient les degats des AUTRES salles.
static func flame(hero) -> bool:
	return hero is Dictionary and ThkAbilities.item_id(hero) == "IOD008"

## Super Magnet : les icones de ce type du donjon de `pid` sont ignorees par les heros jusqu'a la fin du tour.
static func icons_ignored(G: Dictionary, pid: int, treasure: int) -> bool:
	for e in _list(G, "iodIgnore"):
		if int((e as Dictionary).get("playerId", -1)) == pid and int((e as Dictionary).get("treasure", -1)) == treasure:
			return true
	return false

## Flame of Achoom (Reward) : +1 aux salles voisines de chaque salle Mage de `pid`, par activation.
static func mage_adjacent(G: Dictionary, pid: int, other: Dictionary) -> int:
	if not BossEngine.room_treasures(other).has(3):
		return 0
	var n := 0
	for q in _list(G, "iodMage"):
		if int(q) == pid:
			n += 1
	return n

## Degats d'une salle pour un heros qui porte (ou subit) un effet IOD (Force Field).
static func adjust_damage(G: Dictionary, r: Dictionary, hero: Dictionary, dmg: int) -> int:
	if bool(r.get("advanced", false)):
		if _hero_tag(G, hero, "iodNoAdv"):
			return 0
		if ThkAbilities.item_id(hero) == "IOD022":
			return dmg - 2
	return dmg

## Surprise Box : personne ne joue de sort tant qu'un heros qui la porte est dans (ou a l'entree de) un donjon.
static func spells_blocked(G: Dictionary) -> bool:
	for e in entrance_heroes(G):
		if ThkAbilities.item_id(e["hero"]) == "IOD005":
			return true
	return false

## Shining Armor : un heros qui la porte n'est pas ciblable par les sorts. `targets` : liste de cibles de sort (SpellTargeting).
static func filter_targets(G: Dictionary, targets: Array) -> Array:
	var out: Array = []
	for t in targets:
		if t is Dictionary and _armored(G, t as Dictionary):
			continue
		out.append(t)
	return out

static func _armored(G: Dictionary, t: Dictionary) -> bool:
	var h = null
	if t.has("townIndex"):
		var town: Array = G.get("town", [])
		var ti := int(t["townIndex"])
		h = town[ti] if ti >= 0 and ti < town.size() else null
	elif t.has("entranceIndex") and t.has("targetPlayerId"):
		var ent: Array = _p(G, int(t["targetPlayerId"])).get("entrance", [])
		var ei := int(t["entranceIndex"])
		h = ent[ei] if ei >= 0 and ei < ent.size() else null
	elif t.has("heroId"):
		for e in entrance_heroes(G):
			if str((e["hero"] as Dictionary).get("id", "")) == str(t["heroId"]):
				h = e["hero"]
		if h == null:
			for x in (G.get("town", []) as Array):
				if str((x as Dictionary).get("id", "")) == str(t["heroId"]):
					h = x
	return h is Dictionary and ThkAbilities.item_id(h) == "IOD010"

## Le heros quitte la salle `prev` en vie (il va en `i`) ; renvoie l'index de salle a jouer. Stun Gun, Mantle (2e passage), Wand, Secret Map, Bow.
static func on_room_exit(G: Dictionary, pid: int, prev: int, i: int) -> int:
	var a := TnlAbilities.adv(G)
	var hero = a.get("hero")
	if a.is_empty() or not (hero is Dictionary):
		return i
	var p := _p(G, pid)
	var id := ThkAbilities.item_id(hero)
	var d: Array = p.get("dungeon", [])
	if prev >= 0 and prev < d.size() and not bool(a.get("thkBombed", false)) and int(a.get("hp", 0)) > 0:
		var rv = BossEngine.active_room(d[prev])
		if rv != null and not bool((rv as Dictionary).get("faceDown", false)) and not BossEngine.is_room_deactivated(G, pid, prev):
			var room: Dictionary = rv
			if id == "IOD021" and bool(room.get("advanced", false)) and str(room.get("type", "")) == "monster": # Stun Gun
				if return_room_to_hand(G, pid, prev, "Stun Gun"):
					return int(a.get("roomIndex", i))
			var done: Array = a.get("iodTwice", [])
			a["iodTwice"] = done
			if not done.has(prev):
				for e in _list(G, "iodTwice"):
					if int((e as Dictionary).get("playerId", -1)) == pid and int((e as Dictionary).get("roomIndex", -1)) == prev:
						done.append(prev)
						_log(G, "%s passes through %s a second time." % [_label(hero), _label(room)])
						return prev
	d = p.get("dungeon", [])
	if prev < 0 and id == "IOD006": # Portal Wand : une salle ignoree par sort en main
		var n := TnlAbilities.spells_in_hand(p)
		if n > 0:
			_log(G, "Portal Wand: %s skips %d Room(s)." % [_label(hero), n])
			i += n
	if id == "IOD016": # Secret Map : les salles au tresor d'un heros de l'entree sont ignorees
		var want: Array = []
		for h in (p.get("entrance", []) as Array):
			for t in CardDB.hero_treasures(h):
				want.append(int(t))
		while i >= 0 and i < d.size():
			var nv = BossEngine.active_room(d[i])
			var hit := false
			if nv != null and not bool((nv as Dictionary).get("faceDown", false)):
				for t in BossEngine.room_treasures(nv as Dictionary):
					hit = hit or want.has(int(t))
			if not hit:
				break
			_log(G, "Secret Map: %s ignores %s." % [_label(hero), _label(nv as Dictionary)])
			i += 1
	if (id == "IOD003" or _hero_tag(G, hero, "iodBow")) and i >= d.size() - 3 and i < d.size(): # Energy Bow : les trois dernieres salles sont ignorees
		_log(G, "Energy Bow: %s ignores the last three Rooms." % _label(hero))
		i = d.size()
	return i

## Lich Crown : un heros qui la porte et allait mourir retourne en ville avec son Objet. Renvoie vrai s'il est sauve.
static func lich_crown(G: Dictionary, pid: int, hero: Dictionary) -> bool:
	if ThkAbilities.item_id(hero) != "IOD009":
		return false
	var town: Array = G.get("town", [])
	G["town"] = town
	town.append(hero)
	_log(G, "Lich Crown: %s returns to town instead of dying (the Item stays attached)." % _label(hero))
	return true

## Blast Box : le heros mort la portait, la salle ou il est mort est detruite (apres son declencheur de mort).
static func blast_death_room(G: Dictionary, pid: int, death_index: int) -> void:
	var d: Array = _p(G, pid).get("dungeon", [])
	if death_index >= 0 and death_index < d.size() and BossEngine.active_room(d[death_index]) != null:
		TnlAbilities.destroy_room_at(G, pid, death_index, "Blast Box")

# --- IOD007 / IOD011 / IOD018 / IOD023 / IOD026 : crochets ------------------------------------------------------------------------------------

## Heros dont l'ame (face cachee) est chez un adversaire de `pid` : cibles du Reward de Heart Container (le moteur garde l'identite de chaque ame).
static func _heart_options(G: Dictionary, pid: int) -> Array:
	var out: Array = []
	for q in TnlAbilities._opponents(G, pid):
		for h in TnlAbilities._face_down_heroes(_p(G, int(q))):
			out.append({"card": h, "ownerPid": int(q), "label": "%s (P%d)" % [_label(h as Dictionary), int(q) + 1], "ai": 0.0})
	return out

## IOD011 Heart Container (Power-Up, un malus) : le heros survit a votre donjon, vous retournez face visible un de vos heros face cachee (livret : face cachee = ame,
## face visible = blessure) : une ame devient une blessure. Appele avant le controle des 5 Blessures.
## shortcut: le heros est choisi automatiquement (celui qui vaut le moins d'ames) ; ouvrir un choix si un humain doit decider.
static func heart_container(G: Dictionary, pid: int) -> void:
	var p := _p(G, pid)
	var worst = null
	for h in TnlAbilities._face_down_heroes(p):
		if worst == null or BossEngine.hero_souls(h as Dictionary) < BossEngine.hero_souls(worst as Dictionary):
			worst = h
	if worst == null:
		return
	TnlAbilities.remove_soul_hero(p, worst)
	for _k in BossEngine.hero_wounds(worst as Dictionary):
		(p["wounds"] as Array).append({"name": (worst as Dictionary).get("name", "?"), "wounds": 1, "souls": 1, "class": (worst as Dictionary).get("class", ""), "faceDown": false, "turn": _turn(G), "hero": worst})
	_log(G, "Heart Container: %s is flipped face-up in player %d's scorekeeping area (Soul -> Wound)." % [_label(worst as Dictionary), pid + 1])

## IOD018 Stolen Blueprints (Power-Up) : le tour ou ce heros arrive en ville (`townTurn`, pose par Match._reveal_heroes_in_town), personne ne peut construire
## une salle dont une icone de tresor correspond a l'une des siennes. Ne bloque que la construction normale et les constructions immediates TNL.
static func blueprints_block(G: Dictionary, card: Dictionary) -> bool:
	for h in (G.get("town", []) as Array):
		if ThkAbilities.item_id(h) != "IOD018" or int((h as Dictionary).get("townTurn", -1)) != _turn(G):
			continue
		for t in CardDB.hero_treasures(h as Dictionary):
			if BossEngine.room_treasures(card).has(int(t)):
				return true
	return false

## IOD018 (Reward) : une salle posee par `pid` apres l'usage de l'Objet est marquee (tour en cours) ; detruite en fin de tour.
static func stamp_built(G: Dictionary, pid: int, card: Dictionary) -> void:
	if _list(G, "iodBp").has(pid):
		card["iodBp"] = _turn(G)

## Fin de tour : les salles marquees par Stolen Blueprints sont detruites. Renvoie vrai si un choix reste en attente.
## shortcut: seuls les sommets de pile sont detruits (une salle marquee couverte ensuite reste) ; 5-6 joueurs : non appele (Match._check_end_big_game).
static func end_of_turn(G: Dictionary) -> bool:
	for pid in TnlAbilities._alive(G):
		var d: Array = _p(G, int(pid)).get("dungeon", [])
		for i in range(d.size() - 1, -1, -1):
			while i < d.size() and int(((d[i] as Array).back() as Dictionary).get("iodBp", -1)) == _turn(G):
				TnlAbilities.destroy_room_at(G, int(pid), i, "Stolen Blueprints")
	return not (G.get("pendingChoice", {}) as Dictionary).is_empty()

## Laser Drill (Reward) : « comme si elle venait d'etre decouverte » pour la salle au sommet de l'emplacement `i`.
static func _uncover_triggers(G: Dictionary, pid: int, i: int) -> void:
	RoomAbilities.on_uncover(G, pid, i)
	if TnlAbilities.active(G):
		TnlAbilities.on_uncover(G, pid, i)

## Malakill : +3 a la salle tant que l'Objet est dessous.
static func under_bonus(room: Dictionary) -> int:
	return 3 if room.has("iodUnder") else 0

## Malakill : la salle est detruite ou couverte, l'Objet retourne face cachee chez son proprietaire.
## shortcut: l'Objet revient toujours face cachee (le livret ne dit pas ou il va) ; le garder face visible exigerait la limite de places face visible.
static func release_under(G: Dictionary, room: Dictionary) -> void:
	var u = room.get("iodUnder")
	room.erase("iodUnder")
	if u is Dictionary:
		ThkAbilities.add_item(G, int((u as Dictionary).get("owner", 0)), (u as Dictionary)["item"], true)

## Malakill : une salle qui porte un Objet et n'est plus au sommet (couverte par une salle revelee) le rend. Appele apres chaque coup.
static func sweep_covered(G: Dictionary) -> void:
	for pid in TnlAbilities._alive(G):
		for stack in (_p(G, int(pid)).get("dungeon", []) as Array):
			if (stack as Array).size() < 2 or bool(((stack as Array).back() as Dictionary).get("faceDown", false)):
				continue
			for k in range((stack as Array).size() - 1):
				if ((stack as Array)[k] as Dictionary).has("iodUnder"):
					release_under(G, (stack as Array)[k] as Dictionary)

# --- IA ---------------------------------------------------------------------------------------------------------------------------------------

## Valeur de la capacite de Boss `id` pour `pid` maintenant (> 0 : a jouer).
static func score_effect(G: Dictionary, p: Dictionary, pid: int, id: String) -> float:
	var f := AiWiki.fate(G)
	var mine := bool(f["active"]) and int(f["owner"]) == pid
	var theirs := bool(f["active"]) and int(f["owner"]) != pid
	var build := str(G.get("phase", "")) == "build"
	var anytime := AiWiki.BUILD_FIRST if build else 12.0
	match id:
		"IOD001": return 40.0 if theirs and AiWiki.saves(f, 2 * CardDB.total_wounds(p)) else -5.0
		"IOD012": return 40.0 if theirs and AiWiki.saves(f, CardDB.total_souls(p, G)) else -5.0
		"IOD013": return 40.0 if theirs and AiWiki.saves(f, treasure_types(G, pid)) else -5.0
		"IOD002": return 55.0 if mine and AiWiki.kills(f, int(f["best"])) else -5.0
		"IOD003": # un heros adverse qui sinon mourrait avant le Boss
			return 40.0 if theirs and AiWiki.saves(f, int(f["best"])) else -5.0
		"IOD004":
			return 50.0 if mine and AiWiki.kills(f, ThkAbilities.monster_rooms(G, pid)) and not ThkAbilities.room_targets(G, pid, "monster", false).is_empty() else -5.0
		"IOD005":
			return anytime if TnlAbilities.spells_in_hand(p) >= 2 and ThkAbilities._hand_cards(p, "room").size() == 0 else -5.0
		"IOD006": return 40.0 if theirs and AiWiki.saves(f, int(f["best"])) else -5.0
		"IOD008": return 45.0 if mine and AiWiki.kills(f, 1) else -5.0
		"IOD009":
			if mine and int(f["margin"]) > 0:
				return 40.0
			return -5.0
		"IOD010": return anytime if not RoomAbilities.discard_card_options(G, "spell").is_empty() and TnlAbilities.spells_in_hand(p) <= 1 else -5.0
		"IOD014": return 30.0 if build and not _magnet_options(G).is_empty() and _best_magnet(G, pid) > 0.0 else -5.0
		"IOD015": # tuer le heros qui atteindrait le Boss de mon donjon, ou celui qui blesserait un adversaire ne vaut rien ici
			return 60.0 if mine and int(f["hp"]) >= 1 and int(f["margin"]) > 0 else -5.0
		"IOD016": return 20.0 if _best_map(G, pid) > 0.0 else -5.0
		"IOD017": return anytime if _deactivated_of(G, pid).size() >= 1 else -5.0
		"IOD019": return 3.0 if TnlAbilities.spells_in_hand(p) >= 3 else -5.0
		"IOD020": return 30.0 if build and _best_lure(G, pid) > 0.0 else -5.0
		"IOD021": return AiWiki.BUILD_FIRST if build and not advanced_rooms(G, pid, -1).is_empty() else -5.0
		"IOD022": return 40.0 if theirs and AiWiki.saves(f, int(f["best"])) else -5.0
		"IOD024": return anytime
		"IOD007": return anytime if TnlAbilities.spells_in_hand(p) <= 3 else -5.0 # un sort adverse de plus en main
		"IOD023": # les salles a effet « uncover » de mon donjon redeclenchent
			for stack in (p.get("dungeon", []) as Array):
				var top = BossEngine.active_room(stack)
				if top != null and RoomAbilities.has_uncover_effect(top as Dictionary):
					return anytime
			return -5.0
		"IOD011", "IOD018": return -5.0 # IOD011 : retirer une ame a un adversaire pour lui rendre un heros a combattre (le heros peut re-mourir chez lui) : gain incertain ; IOD018 : salle detruite en fin de tour
	return -5.0

static func _best_magnet(G: Dictionary, pid: int) -> float:
	var best := 0.0
	for m in _magnet_options(G):
		if int((m as Dictionary)["targetPlayerId"]) != pid:
			best = maxf(best, float(BossEngine.treasure_count(_p(G, int((m as Dictionary)["targetPlayerId"])), int((m as Dictionary)["treasure"]), G)))
	return best

static func _best_map(G: Dictionary, pid: int) -> float:
	var f := AiWiki.fate(G)
	if not bool(f["active"]) or int(f["owner"]) == pid:
		return 0.0
	return 0.0 # echanger les extremites d'un donjon adverse devant son heros n'a pas de gain mesurable simple

static func _best_lure(G: Dictionary, pid: int) -> float:
	var best := -1.0
	for h in (G.get("town", []) as Array):
		for t in range(1, 6):
			best = maxf(best, _lure_value(G, pid, h, t))
	return best
