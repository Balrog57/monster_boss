class_name TnlAbilities
extends RefCounted
## Extension « Boss Monster 2 : The Next Level » (TNL, 115 cartes : 13 boss, 43 salles, 17 sorts, 42 heros), hors APK.
## Sources, par priorite : docs/rules/rules.md (section The Next Level + FAQ des cartes), texte des cartes (cards.json, wiki), puis le JS.
## Tout le code TNL vit ici et dans TnlSpells.gd ; le moteur n'appelle ce module qu'a travers de petits crochets gardes par
## `TnlAbilities.active(G)` (le set `next-level` est choisi), donc le jeu de base et les paquets de l'APK ne changent pas d'un octet.
## Effets « jusqu'a la fin du tour » : sac `G.effects.tnl` (remis a zero a chaque tour avec G.effects) et sous-dict `tnl` des cartes.

const SET_ID := "next-level"
const DARK_PAY := "DarkHeroPay"

static var _rng := RandomNumberGenerator.new()
static var _rng_ready := false

static func active(G: Dictionary) -> bool:
	return (G.get("sets", []) as Array).has(SET_ID)

static func _rng_get() -> RandomNumberGenerator:
	if not _rng_ready:
		_rng.randomize()
		_rng_ready = true
	return _rng

# --- acces d'etat -------------------------------------------------------------------------------------------

static func _player(G: Dictionary, pid: int) -> Dictionary:
	var players: Dictionary = G.get("players", {})
	return players.get(pid, players.get(str(pid), {})) as Dictionary

## `pub` non vide : ligne privee (voir Match._log) ; `owners` = sieges qui lisent `t`, les autres lisent `pub`.
static func _log(G: Dictionary, t: String, pub: String = "", owners: Array = []) -> void:
	var logs: Array = G.get("logs", [])
	G["logs"] = logs
	logs.append({"t": t, "pub": pub, "owners": owners} if pub != "" else t)

static func _pids(G: Dictionary) -> Array:
	var out: Array = []
	for k in (G.get("players", {}) as Dictionary).keys():
		out.append(int(k))
	out.sort()
	return out

static func _alive(G: Dictionary) -> Array:
	return _pids(G).filter(func(pid): return not bool(_player(G, int(pid)).get("eliminated", false)))

static func _opponents(G: Dictionary, pid: int) -> Array:
	return _alive(G).filter(func(o): return int(o) != pid)

static func adv(G: Dictionary) -> Dictionary:
	var a = G.get("adventure")
	return a as Dictionary if a is Dictionary else {}

## Heros actif dans le donjon de `pid` ({} si aucun). Le heros a l'entree n'est PAS « dans le donjon » (glossaire Entrance).
static func hero_in_dungeon(G: Dictionary, pid: int) -> Dictionary:
	var a := adv(G)
	if a.is_empty() or int(a.get("playerId", -1)) != pid:
		return {}
	var h = a.get("hero")
	return h as Dictionary if h is Dictionary else {}

## Sac d'effets du tour (G.effects est remplace par empty_effects() a chaque _start_turn).
static func _bag(G: Dictionary) -> Dictionary:
	var eff: Dictionary = SpellEffects._effects(G)
	var b = eff.get("tnl")
	if not (b is Dictionary):
		b = {}
		eff["tnl"] = b
	return b as Dictionary

static func _list(G: Dictionary, key: String) -> Array:
	var b := _bag(G)
	if not (b.get(key) is Array):
		b[key] = []
	return b[key] as Array

static func _map(G: Dictionary, key: String) -> Dictionary:
	var b := _bag(G)
	if not (b.get(key) is Dictionary):
		b[key] = {}
	return b[key] as Dictionary

static func used(G: Dictionary, pid: int, key: String) -> bool:
	return bool(_map(G, "used").get("%d:%s" % [pid, key], false))

static func mark_used(G: Dictionary, pid: int, key: String) -> void:
	_map(G, "used")["%d:%s" % [pid, key]] = true

static func _bump(G: Dictionary, key: String, pid: int, n: int = 1) -> int:
	var m := _map(G, key)
	m[pid] = int(m.get(pid, 0)) + n
	return int(m[pid])

static func count_of(G: Dictionary, key: String, pid: int) -> int:
	return int(_map(G, key).get(pid, 0))

static func is_tnl(card: Dictionary) -> bool:
	return str(card.get("id", "")).begins_with("TNL")

static func _tag(r: Dictionary) -> Dictionary:
	var t = r.get("tnl")
	if not (t is Dictionary):
		t = {}
		r["tnl"] = t
	return t as Dictionary

static func flag(r: Dictionary, key: String) -> bool:
	return bool((r.get("tnl", {}) as Dictionary).get(key, false))

## « No ability text » (Meddling Kids!) : ni capacite, ni declencheur, ni bonus passif de la salle.
static func no_text(r: Dictionary) -> bool:
	return flag(r, "noText")

static func has_boss(p: Dictionary, boss_id: String) -> bool:
	if bool((p.get("tnlBoss", {}) as Dictionary).get(boss_id, false)):
		return true
	var b = p.get("boss")
	return b is Dictionary and str((b as Dictionary).get("id", "")) == boss_id and bool(p.get("leveledUp", false))

## Premier argument numerique de la capacite du heros (cards.json `heroAbility.args`), ou `fallback`.
static func hero_arg(hero, fallback: int) -> int:
	if not (hero is Dictionary) or not ((hero as Dictionary).get("heroAbility") is Dictionary):
		return fallback
	var args: Array = ((hero as Dictionary)["heroAbility"] as Dictionary).get("args", []) as Array
	return int(args[0]) if not args.is_empty() else fallback

## Rise of the Minibosses : les capacites des heros de ce donjon sont ignorees (Icicle Man niveau 2, Cerebella niveau 3).
static func text_ignored(G: Dictionary, pid: int) -> bool:
	return Minibosses.active(G) and Minibosses.hero_text_ignored(G, pid)

static func hero_cmd(hero) -> String:
	if not (hero is Dictionary):
		return ""
	var ha = (hero as Dictionary).get("heroAbility")
	return str((ha as Dictionary).get("cmd", "")) if ha is Dictionary else ""

static func _label(c: Dictionary) -> String:
	return str(c.get("name", c.get("id", "?")))

static func _ai_value(c: Dictionary) -> float:
	## Valeur d'une carte pour le choix de l'IA (a defausser : le moins precieux d'abord).
	if bool(c.get("isSpell", false)):
		return 1.0
	if bool(c.get("isMiniboss", false)): # Rise of the Minibosses : une carte precieuse (pas de degats ni de tresor imprimes)
		return 2.5
	return float(int(c.get("damage", 0))) + 0.5 * float((c.get("treasures", []) as Array).size()) + (1.0 if bool(c.get("advanced", false)) else 0.0)

# --- cartes en main / pioches -------------------------------------------------------------------------------

static func hand_options(p: Dictionary, kind: String) -> Array:
	var out: Array = []
	for c in (p.get("hand", []) as Array):
		var d: Dictionary = c
		var ok := false
		match kind:
			"spell": ok = bool(d.get("isSpell", false))
			"room": ok = bool(d.get("isRoom", false))
			"monster": ok = bool(d.get("isRoom", false)) and str(d.get("type", "")) == "monster"
			"trap": ok = bool(d.get("isRoom", false)) and str(d.get("type", "")) == "trap"
			_: ok = true
		if ok:
			out.append({"card": d, "label": _label(d), "ai": -_ai_value(d)})
	return out

static func _to_discard(G: Dictionary, card: Dictionary) -> void:
	var decks: Dictionary = G.get("decks", {})
	if bool(card.get("isSpell", false)):
		var pile: Array = decks.get("spellDiscard", [])
		decks["spellDiscard"] = pile
		pile.append(card)
	else:
		BossEngine.discard_room_to_pile(decks, card)

## Retire `card` de la main de `pid` (sans la defausser). Faux si elle n'y est plus.
static func take_from_hand(G: Dictionary, pid: int, card: Dictionary) -> bool:
	var p := _player(G, pid)
	var hand: Array = p.get("hand", []) as Array
	var at := hand.find(card)
	if at < 0:
		return false
	hand.remove_at(at)
	p["hand"] = hand
	return true

static func discard_from_hand(G: Dictionary, pid: int, card: Dictionary) -> bool:
	if not take_from_hand(G, pid, card):
		return false
	_to_discard(G, card)
	Minibosses.on_hand_discard(G, pid, card) # RMB017 Imp Hoard
	return true

## Pioche `n` cartes (la defausse est remelangee quand la pioche est vide, comme DrawRooms / DrawSpells).
static func draw(G: Dictionary, pid: int, pile: String, n: int) -> Array:
	var p := _player(G, pid)
	var decks: Dictionary = G.get("decks", {})
	var deck: Array = decks.get(pile, [])
	decks[pile] = deck
	var disc_key := "roomDiscard" if pile == "rooms" else "spellDiscard"
	var disc: Array = decks.get(disc_key, [])
	decks[disc_key] = disc
	var out: Array = []
	for _i in n:
		if deck.is_empty():
			CardDB.refill_from_discard(deck, disc, _rng_get())
		if deck.is_empty():
			break
		out.append(deck.pop_back())
	var hand: Array = p.get("hand", []) as Array
	hand.append_array(out)
	p["hand"] = hand
	return out

static func draw_logged(G: Dictionary, pid: int, pile: String, n: int, label: String) -> Array:
	var got := draw(G, pid, pile, n)
	if not got.is_empty():
		_log(G, "%s: draws %d card(s)." % [label, got.size()])
	return got

static func spells_in_hand(p: Dictionary) -> int:
	var n := 0
	for c in (p.get("hand", []) as Array):
		if bool((c as Dictionary).get("isSpell", false)):
			n += 1
	return n

# --- choix generiques « tnl-pick » -----------------------------------------------------------------------------

## Cree un choix (ou le resout d'office s'il n'a qu'une option obligatoire : TryToAutoresolve). `resume` = faux pour tout
## choix ouvert hors de la revelation de fin de BUILD, comme les autres capacites (voir RoomAbilities._resume).
static func ask(G: Dictionary, pid: int, step: String, options: Array, ctx: Dictionary, message: String, label: String, optional: bool = false) -> Variant:
	if options.is_empty():
		return null
	var pc := {"type": "tnl-pick", "step": step, "ctx": ctx, "playerId": pid, "bossName": label, "message": message,
		"options": options, "optional": optional, "resume": G.has("revealQueue")}
	if options.size() == 1 and not optional:
		return resolve_pick(G, pid, pc, 0)
	return pc

## Livre un choix issu d'une capacite activee / d'un declencheur (file si un choix est deja ouvert).
static func emit(G: Dictionary, choice) -> void:
	if choice is Dictionary and not (choice as Dictionary).is_empty():
		RoomAbilities.enqueue_pending(G, choice as Dictionary)

## Plusieurs choix a la suite : renvoie le premier, les suivants partent en file (pour les retours « on_build » lus par la revelation).
static func flush(G: Dictionary, list: Array) -> Variant:
	var chs: Array = list.filter(func(c): return c is Dictionary and not (c as Dictionary).is_empty())
	if chs.is_empty():
		return null
	var first = chs.pop_front()
	if not chs.is_empty():
		var q: Array = G.get("choiceQueue", []) if G.get("choiceQueue", null) is Array else []
		G["choiceQueue"] = q
		q.append_array(chs)
	return first

# --- cibles de salles --------------------------------------------------------------------------------------------

## Sommets de piles CIBLABLES (actifs, face visible, non geles) : kind = any | trap | monster | advanced.
static func room_options(G: Dictionary, kind: String, exclude_pid: int = -1, exclude_idx: int = -1, only_pid: int = -1) -> Array:
	var out: Array = []
	for opid in _alive(G):
		if only_pid >= 0 and int(opid) != only_pid:
			continue
		var d: Array = _player(G, int(opid)).get("dungeon", [])
		for i in d.size():
			if int(opid) == exclude_pid and i == exclude_idx:
				continue
			var rv = SpellTargeting._targetable_top(G, int(opid), i, d[i])
			if rv == null:
				continue
			var r: Dictionary = rv
			match kind:
				"trap": if str(r.get("type", "")) != "trap": continue
				"monster": if str(r.get("type", "")) != "monster": continue
				"advanced": if not bool(r.get("advanced", false)): continue
			out.append({"targetPlayerId": int(opid), "roomIndex": i, "card": r, "label": "%s (P%d)" % [_label(r), int(opid) + 1],
				"ai": (1.0 if int(opid) != exclude_pid else -1.0) * (float(int(r.get("damage", 0))) + (2.0 if bool(r.get("advanced", false)) else 0.0))})
	return out

static func destroy_room_at(G: Dictionary, pid: int, idx: int, label: String) -> Dictionary:
	var p := _player(G, pid)
	var d = BossEngine.destroy_room(p, idx, G)
	if d == null:
		return {}
	BossEngine.discard_room_to_pile(G.get("decks", {}), d)
	_log(G, "%s: %s destroyed." % [label, _label(d as Dictionary)])
	return d as Dictionary

static func _index_of_room(p: Dictionary, room: Dictionary) -> int:
	var dungeon: Array = p.get("dungeon", [])
	for i in dungeon.size():
		var rv = BossEngine.active_room(dungeon[i])
		if rv != null and is_same(rv, room):
			return i
	return -1

# --- niveau des boss ---------------------------------------------------------------------------------------------

## Level up d'un boss TNL (RoomAbilities.process_level_up). Les capacites « pour le reste de la partie » sont des drapeaux
## `p.tnlBoss[id]` lus par has_boss ; Klonos (CRL002) qui copie un boss TNL passe par la meme porte.
static func level_up(G: Dictionary, pid: int, p: Dictionary, boss: Dictionary) -> Variant:
	var id := str(boss.get("id", ""))
	var flags: Dictionary = p.get("tnlBoss", {}) as Dictionary
	p["tnlBoss"] = flags
	flags[id] = true
	match id:
		"TNL000": return _mirrax(G, pid)
		"TNL002": return _belladonna(G, pid, p)
		"TNL003":
			(G["decks"] as Dictionary)["torixPid"] = pid # Torix : toute salle Monster defaussee / detruite -> sa main (voir flush_torix)
		"TNL007": # Kazanna : defausse la main, pioche 3 sorts
			var hand: Array = (p.get("hand", []) as Array).duplicate()
			(p["hand"] as Array).clear()
			for c in hand:
				_to_discard(G, c as Dictionary)
			draw_logged(G, pid, "spells", 3, "Kazanna")
		"TNL010": return _porkus(G, pid, p)
	return null

static func _boss_icons(q: Dictionary) -> Array:
	var out: Array = []
	var b = q.get("boss")
	if not (b is Dictionary):
		return out
	for t in ((b as Dictionary).get("treasures", []) as Array):
		out.append(int(t))
	var lu = (b as Dictionary).get("levelUp")
	if bool(q.get("leveledUp", false)) and lu is Dictionary and str((lu as Dictionary).get("cmd", "")) == "AddTreasuresToDungeon":
		for a in ((lu as Dictionary).get("args", []) as Array):
			out.append(int(CardDB.TREASURE_NAMES.find(str(a))))
	for t in (q.get("bonusTreasures", []) as Array):
		out.append(int(t))
	return out

## TNL000 Mirrax : copie les icones de tresor d'un AUTRE boss en jeu (elles restent meme s'il meurt ; Kirax : toutes ses icones).
static func _mirrax(G: Dictionary, pid: int) -> Variant:
	var opts: Array = []
	for oid in _alive(G):
		if int(oid) == pid:
			continue
		var q := _player(G, int(oid))
		var icons := _boss_icons(q)
		if icons.is_empty():
			continue
		opts.append({"label": "%s (P%d)" % [str((q.get("boss", {}) as Dictionary).get("name", "?")), int(oid) + 1], "icons": icons, "card": q.get("boss", {}),
			"ai": float(icons.size())})
	if opts.is_empty():
		_log(G, "Mirrax: no other Boss to copy.")
		return null
	return ask(G, pid, "mirrax", opts, {}, "Mirrax: choose a Boss to copy its treasure icons", "Mirrax")

static func _belladonna(G: Dictionary, pid: int, p: Dictionary) -> Variant:
	var heroes := BossEngine.wound_heroes(p)
	if heroes.is_empty():
		_log(G, "Belladonna: no Wound to heal.")
		return null
	var opts: Array = []
	for h in heroes:
		opts.append({"card": h, "label": _label(h as Dictionary), "ai": float(BossEngine.hero_souls(h as Dictionary))})
	return ask(G, pid, "heal", opts, {}, "Belladonna: choose a Hero to turn face-down", "Belladonna")

static func _face_down_heroes(p: Dictionary) -> Array:
	var out: Array = []
	for e in (p.get("souls", []) as Array):
		var h = (e as Dictionary).get("hero")
		if h is Dictionary and not bool((e as Dictionary).get("tpk", false)) and not out.has(h):
			out.append(h)
	return out

## Retire du scorekeeping toutes les ames d'un heros (Hero.Souls entrees) ; renvoie vrai s'il y etait.
static func remove_soul_hero(p: Dictionary, hero: Dictionary) -> bool:
	var souls: Array = p.get("souls", []) as Array
	var removed := false
	for i in range(souls.size() - 1, -1, -1):
		if (souls[i] as Dictionary).get("hero") == hero:
			souls.remove_at(i)
			removed = true
	p["souls"] = souls
	return removed

static func _remove_from_game(G: Dictionary, hero: Dictionary) -> void:
	var decks: Dictionary = G.get("decks", {})
	var gone: Array = decks.get("removedHeroes", [])
	decks["removedHeroes"] = gone
	gone.append(hero)

## TNL010 Porkus : retire un heros face cachee du jeu, puis en cherche un autre dans les pioches de heros (face cachee chez soi).
static func _porkus(G: Dictionary, pid: int, p: Dictionary) -> Variant:
	var opts: Array = []
	for h in _face_down_heroes(p):
		opts.append({"card": h, "label": _label(h as Dictionary), "ai": -float(BossEngine.hero_souls(h as Dictionary))})
	if opts.is_empty():
		_log(G, "Porkus: no face-down Hero to remove.")
		return null
	return ask(G, pid, "porkus_remove", opts, {}, "Porkus: choose a face-down Hero to remove from the game", "Porkus")

static func _porkus_search(G: Dictionary, pid: int) -> Variant:
	var opts: Array = []
	var decks: Dictionary = G.get("decks", {})
	for pile in ["heroes", "epics"]:
		var deck: Array = decks.get(pile, [])
		for i in deck.size():
			var h: Dictionary = deck[i]
			opts.append({"card": h, "label": _label(h), "pile": pile, "deckIndex": i, "ai": float(BossEngine.hero_souls(h)) * 10.0 + float(int(h.get("hp", 0))) / 100.0})
	return ask(G, pid, "porkus_search", opts, {}, "Porkus: choose a Hero from the Hero decks", "Porkus")

# --- Torix : les salles Monster defaussees / detruites rejoignent sa main --------------------------------------------

## Appele par BossEngine.discard_room_to_pile : la carte attend dans `torixQueue` (elle n'est pas posee en defausse).
static func torix_catch(decks: Dictionary, card: Dictionary) -> bool:
	if not decks.has("torixPid") or str(card.get("type", "")) != "monster":
		return false
	var q: Array = decks.get("torixQueue", [])
	decks["torixQueue"] = q
	q.append(card)
	return true

## Fin de coup : les salles attrapees partent dans la main de Torix (« you may » : toujours pris), sinon en defausse.
static func flush_torix(G: Dictionary) -> void:
	var decks: Dictionary = G.get("decks", {})
	var q: Array = decks.get("torixQueue", [])
	if q.is_empty():
		return
	var owner := _player(G, int(decks.get("torixPid", -1)))
	var held: Array = q.duplicate()
	q.clear()
	for c in held:
		var card: Dictionary = c
		if owner.is_empty() or bool(owner.get("eliminated", false)):
			var pile: Array = decks.get("roomDiscard", [])
			decks["roomDiscard"] = pile
			pile.append(card)
			continue
		var hand: Array = owner.get("hand", []) as Array
		hand.append(card)
		owner["hand"] = hand
		_log(G, "Torix Uz'Kali: %s joins his hand." % _label(card))

# --- declencheurs : construction / decouverte ---------------------------------------------------------------------

## « When you build this Room » (RoomAbilities.on_build_room, a la revelation ou en construction immediate) + boss en cours (Smoake).
## Renvoie un choix a resoudre, ou null.
static func on_build(G: Dictionary, pid: int, room: Dictionary) -> Variant:
	var p := _player(G, pid)
	if str(room.get("type", "")) == "monster" and has_boss(p, "TNL006"):
		draw_logged(G, pid, "rooms", 1, "Smoake") # « you may » : toujours pris
	if not is_tnl(room) or no_text(room):
		return null
	var list: Array = _build_or_uncover(G, pid, room, true)
	return flush(G, list)

## Declencheur « when you uncover this Room » (appele par BossEngine.destroy_room, pile deja mise a jour) + Eclipse (boss).
static func on_uncover(G: Dictionary, pid: int, room_index: int) -> void:
	var p := _player(G, pid)
	var dungeon: Array = p.get("dungeon", [])
	if room_index < 0 or room_index >= dungeon.size():
		return
	var rv = BossEngine.active_room(dungeon[room_index])
	if rv == null or bool((rv as Dictionary).get("faceDown", false)):
		return
	var room: Dictionary = rv
	if has_boss(p, "TNL012"):
		SpellEffects._buff_room_instance(room, 3) # Eclipse : la salle decouverte gagne +3 jusqu'a la fin du tour
		_log(G, "Eclipse: %s gains +3 until end of turn." % _label(room))
	if not is_tnl(room) or no_text(room) or BossEngine.abilities_locked(G, pid) or BossEngine.is_room_deactivated(G, pid, room_index):
		return
	for c in _build_or_uncover(G, pid, room, false):
		emit(G, c)

## Effets communs « build or uncover » (et « build » seul pour Incubus Gym, Barbarian Hall, Megaworm Burrow, Genie Lounge).
static func _build_or_uncover(G: Dictionary, pid: int, room: Dictionary, built: bool) -> Array:
	var p := _player(G, pid)
	var out: Array = []
	match str(room.get("id", "")):
		"TNL016": # Arcane Crypt : recupere un sort de la defausse
			out.append(recover_choice(G, pid, "spell", "Arcane Crypt"))
		"TNL027": # Shrooman Cave : une AUTRE salle Monster +3 jusqu'a la fin du tour (la FAQ interdit de se cibler)
			var idx := _index_of_room(p, room)
			out.append(ask(G, pid, "room_target", room_options(G, "monster", pid, idx), {"then": "buff", "amount": 3},
				"Shrooman Cave: choose another Monster Room (+3)", "Shrooman Cave"))
		"TNL036": # Sorcerobe School
			draw_logged(G, pid, "spells", 1, "Sorcerobe School")
		"TNL044": # Spiked Pit : +3 sur elle-meme
			SpellEffects._buff_room_instance(room, 3)
			_log(G, "Spiked Pit: +3 until end of turn.")
		"TNL019": # Incubus Gym : chaque adversaire defausse une salle (build uniquement)
			if built:
				out.append_array(each_opponent_discard(G, pid, "room", 1, "Incubus Gym"))
		"TNL024": # Barbarian Hall : defausse un sort s'il y en a (build uniquement)
			if built:
				out.append(discard_spell_choice(G, pid, "Barbarian Hall"))
		"TNL029": # Megaworm Burrow : detruit une salle avancee (build uniquement)
			if built:
				out.append(ask(G, pid, "room_target", room_options(G, "advanced", pid, _index_of_room(p, room)), {"then": "destroy", "label": "Megaworm Burrow"},
					"Megaworm Burrow: choose an Advanced Room to destroy", "Megaworm Burrow"))
		"TNL052": # Genie Lounge : pioche un sort si la main n'en a pas (build uniquement)
			if built and spells_in_hand(p) == 0:
				draw_logged(G, pid, "spells", 1, "Genie Lounge")
	return out

## Choix « recupere une carte de la defausse » (kind = spell | room), auto s'il n'y a qu'une carte.
static func recover_choice(G: Dictionary, pid: int, kind: String, label: String) -> Variant:
	var opts: Array = RoomAbilities.discard_card_options(G, kind)
	if opts.is_empty():
		_log(G, "%s: nothing to recover." % label)
		return null
	for o in opts:
		(o as Dictionary)["label"] = _label((o as Dictionary)["card"] as Dictionary)
		(o as Dictionary)["ai"] = _ai_value((o as Dictionary)["card"] as Dictionary)
	return ask(G, pid, "take_discard", opts, {"label": label}, "%s: choose a card from the discard pile" % label, label)

## Defausse un sort au choix (auto s'il n'y en a qu'un ; rien s'il n'y en a aucun).
static func discard_spell_choice(G: Dictionary, pid: int, label: String) -> Variant:
	var opts := hand_options(_player(G, pid), "spell")
	return ask(G, pid, "discard_one", opts, {"label": label}, "%s: choose a Spell to discard" % label, label)

# --- defausses forcees (Incubus Gym, Wraith's Throne, Cursed Tomb) + Imp Temple -------------------------------------------

## TNL014 Imp Temple : « une fois par tour, quand vous forcez un adversaire a defausser, prenez la carte en main ». Renvoie vrai si prise.
static func imp_take(G: Dictionary, actor: int, card: Dictionary) -> bool:
	if actor < 0 or not active(G):
		return false
	var p := _player(G, actor)
	for stack in (p.get("dungeon", []) as Array):
		var rv = BossEngine.active_room(stack)
		if rv == null:
			continue
		var r: Dictionary = rv
		if str(r.get("id", "")) != "TNL014" or bool(r.get("faceDown", false)) or no_text(r) or bool(r.get("usedThisTurn", false)):
			continue
		r["usedThisTurn"] = true
		var hand: Array = p.get("hand", []) as Array
		hand.append(card)
		p["hand"] = hand
		_log(G, "Imp Temple: %s goes to player %d's hand instead." % [_label(card), actor + 1])
		return true
	return false

## La carte quitte la main de la victime : Imp Temple de l'acteur la prend, sinon defausse (Torix compris).
static func _forced_take(G: Dictionary, actor: int, victim: int, card: Dictionary) -> void:
	if not take_from_hand(G, victim, card):
		return
	if imp_take(G, actor, card):
		return
	_to_discard(G, card)
	Minibosses.on_hand_discard(G, victim, card) # RMB017 Imp Hoard
	_log(G, "Player %d discards %s." % [victim + 1, _label(card)])

## `victim` defausse `count` cartes de type kind (room | spell) a son choix ; auto quand tout doit partir.
static func force_discard(G: Dictionary, actor: int, victim: int, kind: String, count: int, label: String) -> Variant:
	var cands := hand_options(_player(G, victim), kind)
	if cands.is_empty() or count <= 0:
		return null
	if cands.size() <= count:
		for o in cands:
			_forced_take(G, actor, victim, (o as Dictionary)["card"] as Dictionary)
		return null
	return ask(G, victim, "forced", cands, {"actor": actor, "kind": kind, "remaining": count, "label": label},
		"%s: discard %d %s card(s)" % [label, count, kind], label)

static func each_opponent_discard(G: Dictionary, actor: int, kind: String, count: int, label: String) -> Array:
	var out: Array = []
	for o in _opponents(G, actor):
		var c = force_discard(G, actor, int(o), kind, count, label)
		if c != null:
			out.append(c)
	return out

## Une salle de `pid` vient d'etre detruite (BossEngine.destroy_room) : compte pour Oh, Yeah! ; Cursed Tomb se venge.
static func on_destroyed(G: Dictionary, pid: int, room: Dictionary) -> void:
	_bump(G, "destroyed", pid)
	if str(room.get("id", "")) == "TNL054" and not no_text(room):
		on_cursed_tomb_destroyed(G, pid)

## TNL020 Dragon Graveyard : une fois par tour, prendre une carte dans la defausse fait piocher une salle.
static func on_take_from_discard(G: Dictionary, player: Dictionary) -> void:
	for stack in (player.get("dungeon", []) as Array):
		var rv = BossEngine.active_room(stack)
		if rv == null:
			continue
		var r: Dictionary = rv
		if str(r.get("id", "")) == "TNL020" and not bool(r.get("faceDown", false)) and not no_text(r) and not bool(r.get("usedThisTurn", false)):
			r["usedThisTurn"] = true
			draw_logged(G, int(player.get("id", -1)), "rooms", 1, "Dragon Graveyard")
			return

## Mise en place TNL : la defausse est amorcee par 4 salles et 2 sorts au hasard (face visible).
static func seed_discards(G: Dictionary) -> void:
	var decks: Dictionary = G.get("decks", {})
	var rooms: Array = decks.get("rooms", [])
	var spells: Array = decks.get("spells", [])
	var rd: Array = decks.get("roomDiscard", [])
	var sd: Array = decks.get("spellDiscard", [])
	decks["roomDiscard"] = rd
	decks["spellDiscard"] = sd
	for _i in 4:
		if not rooms.is_empty():
			rd.append(rooms.pop_back())
	for _i in 2:
		if not spells.is_empty():
			sd.append(spells.pop_back())

const HERO_COUNTS := {2: {"ordinary": 13, "epic": 9}, 3: {"ordinary": 17, "epic": 13}, 4: {"ordinary": 25, "epic": 17}}

## Livret TNL : 13 heros + 9 epiques (2 joueurs), 17 + 13 (3), 25 + 17 (4). Les heros marques d'une etoile (noirs, hybrides, Fool, Brothers) sont
## toujours inclus ; les autres completent au hasard. Le tout est remelange (la pioche se tire par la fin).
static func limit_heroes(deck: Array, n: int, epic: bool) -> Array:
	var want := int((HERO_COUNTS.get(n, HERO_COUNTS[2]) as Dictionary)["epic" if epic else "ordinary"])
	var special: Array = []
	var plain: Array = []
	for h in deck:
		var d: Dictionary = h
		if bool(d.get("dark", false)) or bool(d.get("hybrid", false)) or d.has("lure") or d.has("heroAbility"):
			special.append(d)
		else:
			plain.append(d)
	var out: Array = special.slice(0, want)
	out.append_array(plain.slice(0, want - out.size()))
	out.shuffle()
	return out

## TNL054 Cursed Tomb : detruite par l'effet d'une autre carte -> chaque adversaire de son proprietaire defausse deux salles.
static func on_cursed_tomb_destroyed(G: Dictionary, pid: int) -> void:
	for c in each_opponent_discard(G, pid, "room", 2, "Cursed Tomb"):
		emit(G, c)

# --- declencheurs : heros mort / survivant / quitte la salle --------------------------------------------------------------

static func on_hero_died(G: Dictionary, pid: int, room: Dictionary) -> Variant:
	if no_text(room):
		return null
	var id := str(room.get("id", ""))
	if ["TNL015", "TNL021", "TNL025", "TNL026", "TNL039"].has(id): # « once per turn, if a Hero dies in this Room »
		if bool(room.get("usedThisTurn", false)):
			return null
		room["usedThisTurn"] = true
	match id:
		"TNL015": return recover_choice(G, pid, "spell", "Madman's Manor")
		"TNL021": return flush(G, each_opponent_discard(G, pid, "spell", 1, "Wraith's Throne"))
		"TNL025": draw_logged(G, pid, "rooms", 2, "Spawn Point")
		"TNL026": return build_choice(G, pid, "any", "Fangroot Garden")
		"TNL039":
			draw_logged(G, pid, "spells", 2, "Brainsucker Queen")
			return discard_spell_choice(G, pid, "Brainsucker Queen")
		"TNL050": # Bom-Boy Factory : se detruit quand un heros y meurt (ou y survit, voir on_room_exit)
			var p := _player(G, pid)
			var at := _index_of_room(p, room)
			if at >= 0:
				destroy_room_at(G, pid, at, "Bom-Boy Factory")
	return null

## Un heros vient d'etre tue chez `pid` (Angstigoth : une fois par tour, piocher une salle).
static func on_hero_killed(G: Dictionary, pid: int) -> void:
	var p := _player(G, pid)
	if has_boss(p, "TNL011") and not used(G, pid, "angstigoth"):
		mark_used(G, pid, "angstigoth")
		draw_logged(G, pid, "rooms", 1, "Angstigoth")

## Un heros a survecu au donjon de `pid` (Necromancer : retourner un heros face cachee face visible).
static func on_hero_survived(G: Dictionary, pid: int, hero: Dictionary) -> void:
	if hero_cmd(hero) != "FlipSoulOnSurvive" or text_ignored(G, pid):
		return
	var p := _player(G, pid)
	if bool(p.get("eliminated", false)):
		return
	var opts: Array = []
	for h in _face_down_heroes(p):
		opts.append({"card": h, "label": _label(h as Dictionary), "ai": -float(BossEngine.hero_souls(h as Dictionary))})
	emit(G, ask(G, pid, "unflip", opts, {}, "Necromancer: choose a face-down Hero to turn face-up", "Necromancer"))

## Le heros quitte la salle `prev` en vie (il entre dans `i`) : Collapsing Bridge, Bom-Boy Factory. Renvoie l'index de salle a jouer.
## La FAQ : « survives this Room » = sort de la salle sans mourir, pas du donjon entier ; une salle passee (Shortcut!, Archer) ne compte pas.
static func on_room_exit(G: Dictionary, pid: int, prev: int, i: int) -> int:
	var p := _player(G, pid)
	var dungeon: Array = p.get("dungeon", [])
	var a := adv(G)
	if prev < 0 or prev >= dungeon.size():
		return i
	var rv = BossEngine.active_room(dungeon[prev])
	if rv != null:
		var room: Dictionary = rv
		if not (BossEngine.is_room_deactivated(G, pid, prev) or no_text(room) or BossEngine.abilities_locked(G, pid)):
			match str(room.get("id", "")):
				"TNL043": # Collapsing Bridge : une fois par tour, +3 jusqu'a la fin du tour
					if not bool(room.get("usedThisTurn", false)):
						room["usedThisTurn"] = true
						SpellEffects._buff_room_instance(room, 3)
						_log(G, "Collapsing Bridge: +3 until end of turn.")
				"TNL050":
					destroy_room_at(G, pid, prev, "Bom-Boy Factory")
	return int(a.get("roomIndex", i)) if not a.is_empty() else i

## Un heros entre dans la salle `room` (avant les degats) : Fairy Fountain +1 ; memorise l'entree pour Inner Sanctum.
static func on_room_enter(G: Dictionary, pid: int, room_index: int, room: Dictionary) -> void:
	_tag(room)["entered"] = true
	if flag(room, "fairy") and not BossEngine.is_room_deactivated(G, pid, room_index):
		var a := adv(G)
		a["hp"] = int(a.get("hp", 0)) + 1
		_log(G, "Fairy Fountain: %s gains +1 Health." % str((a.get("hero", {}) as Dictionary).get("name", "?")))

## Indice de salle suivant une serie de sauts : Shortcut! (`skip` du heros actif) et Archer (derniere salle ignoree).
static func skip_rooms(G: Dictionary, pid: int, hero: Dictionary, i: int) -> int:
	var a := adv(G)
	var dungeon: Array = _player(G, pid).get("dungeon", [])
	if i < 0: # emplacement vide traverse (salle detruite sous le heros) : rien a sauter
		return i
	var skips := int(a.get("skip", 0))
	while skips > 0 and i < dungeon.size():
		var rv = BossEngine.active_room(dungeon[i])
		if rv != null and not BossEngine.is_room_deactivated(G, pid, i):
			skips -= 1
			_log(G, "%s skips %s." % [str(hero.get("name", "?")), _label(rv as Dictionary)])
		i += 1
	a.erase("skip")
	if hero_cmd(hero) == "SkipLastRoom" and i == dungeon.size() - 1 and not text_ignored(G, pid):
		_log(G, "%s ignores the last Room of the dungeon." % str(hero.get("name", "?")))
		i += 1
	return i

# --- bonus passifs de degats ---------------------------------------------------------------------------------------------

## Damage d'une salle a 0 (Fairy Fountain) : « once zero, later effects cannot increase it ».
static func zero_damage(room: Dictionary) -> bool:
	return flag(room, "fairy")

## Bonus de degats passifs TNL pour la salle `room_index` de `player` (appele par BossEngine.room_damage_with_modifiers).
static func passive_damage(G: Dictionary, player: Dictionary, room_index: int, r: Dictionary, locked: bool) -> int:
	var dmg := 0
	var pid := int(player.get("id", 0))
	var dungeon: Array = player.get("dungeon", [])
	var rt := str(r.get("type", ""))
	if not locked:
		if str(r.get("id", "")) == "TNL038" and not no_text(r): # Elemental Generator : +X, X = sorts en main
			dmg += spells_in_hand(player)
		for i in dungeon.size():
			if i == room_index:
				continue
			var other = BossEngine.active_room(dungeon[i])
			if other == null or BossEngine.is_room_deactivated(G, pid, i) or bool((other as Dictionary).get("faceDown", false)) or no_text(other as Dictionary):
				continue
			match str((other as Dictionary).get("id", "")):
				"TNL023": # Goblin Nursery : la salle a sa gauche (index - 1), si Monster, +2
					if i == room_index + 1 and rt == "monster":
						dmg += 2
				"TNL028": # Goblin Mess Hall : toutes les AUTRES salles Monster +1
					if rt == "monster":
						dmg += 1
	# TNL004 Killa : avec 3 blessures ou plus, la derniere salle (la plus proche du boss, non gelee) +3
	if has_boss(player, "TNL004") and CardDB.total_wounds(player) >= 3 and room_index == last_active_index(G, player):
		dmg += 3
	return dmg

## Derniere salle (index le plus grand = contre le boss) non gelee ; -1 si aucune.
static func last_active_index(G: Dictionary, player: Dictionary) -> int:
	var pid := int(player.get("id", 0))
	var dungeon: Array = player.get("dungeon", [])
	for i in range(dungeon.size() - 1, -1, -1):
		var rv = BossEngine.active_room(dungeon[i])
		if rv != null and not bool((rv as Dictionary).get("faceDown", false)) and not BossEngine.is_room_deactivated(G, pid, i):
			return i
	return -1

# --- heros : PV, debut d'aventure, capacites ----------------------------------------------------------------------------------

## PV supplementaires jusqu'a la fin du tour : immediat pour le heros actif, sinon retenus pour son entree dans le donjon.
static func add_hero_hp(G: Dictionary, hero: Dictionary, amount: int) -> void:
	var a := adv(G)
	var ah = a.get("hero")
	if ah is Dictionary and str((ah as Dictionary).get("id", "")) == str(hero.get("id", "")) and int(a.get("hp", 1)) > -999:
		a["hp"] = int(a.get("hp", 0)) + amount
		return
	_list(G, "heroHp").append({"heroId": str(hero.get("id", "")), "amount": amount})

## Bonus de PV d'un heros qui commence son aventure chez `pid` (PV retenus, Party Up) ; compte aussi les entrees du tour.
static func on_hero_start(G: Dictionary, pid: int, hero: Dictionary) -> int:
	var bonus := 0
	var held := _list(G, "heroHp")
	for k in range(held.size() - 1, -1, -1):
		if str((held[k] as Dictionary).get("heroId", "")) == str(hero.get("id", "")):
			bonus += int((held[k] as Dictionary).get("amount", 0))
			held.remove_at(k)
	for q in _list(G, "party"):
		if int(q) == pid:
			bonus += 1
	_bump(G, "entered", pid)
	return bonus

## Druid : +X PV, X = sorts en main du proprietaire du donjon (+ ses sorts en attente sur la pile : « baisse des qu'il se resout »).
## Le bonus applique est memorise (adv.druid) pour n'ajuster que l'ecart.
static func sync_hero(G: Dictionary) -> void:
	var a := adv(G)
	if a.is_empty() or hero_cmd(a.get("hero")) != "HealthPerSpellInHand" or text_ignored(G, int(a.get("playerId", -1))):
		return
	var pid := int(a.get("playerId", -1))
	var x := spells_in_hand(_player(G, pid))
	for e in (G.get("stack", []) as Array):
		if str((e as Dictionary).get("type", "")) == "spell" and int((e as Dictionary).get("playerId", -1)) == pid and not bool((e as Dictionary).get("canceled", false)):
			x += 1
	a["hp"] = int(a.get("hp", 0)) + x - int(a.get("druid", 0))
	a["druid"] = x

## Un sort va se resoudre (non annule) : Swordmage +2, Spellslime Pit +1, Hall of Mirrors (pioche), memoire de Save Point.
static func on_spell_resolving(G: Dictionary, caster: int, card: Dictionary) -> void:
	var a := adv(G)
	if not a.is_empty() and hero_cmd(a.get("hero")) == "HealthPerSpell" and not text_ignored(G, int(a.get("playerId", -1))):
		var bonus := hero_arg(a.get("hero"), 2) # Swordmage : +2 PV a chaque sort (non annule) joue pendant qu'il est dans le donjon
		a["hp"] = int(a.get("hp", 0)) + bonus
		_log(G, "%s gains +%d Health." % [str((a["hero"] as Dictionary).get("name", "?")), bonus])
	_list(G, "played").append({"pid": caster, "card": card})
	for pid in _alive(G):
		var p := _player(G, int(pid))
		for stack in (p.get("dungeon", []) as Array):
			var rv = BossEngine.active_room(stack)
			if rv == null or bool((rv as Dictionary).get("faceDown", false)) or no_text(rv as Dictionary):
				continue
			var r: Dictionary = rv
			match str(r.get("id", "")):
				"TNL034": # Spellslime Pit : chaque sort que VOUS jouez, +1
					if int(pid) == caster:
						SpellEffects._buff_room_instance(r, 1)
				"TNL037": # Hall of Mirrors : une fois par tour, quand un adversaire joue un sort, pioche un sort
					if int(pid) != caster and not bool(r.get("usedThisTurn", false)):
						r["usedThisTurn"] = true
						draw_logged(G, int(pid), "spells", 1, "Hall of Mirrors")

static func cannot_win(G: Dictionary, pid: int) -> bool:
	return _list(G, "noWin").has(pid)

## Heros ecartes du leurre ce tour (Doc Scarecrow).
static func no_lure(G: Dictionary, hero: Dictionary) -> bool:
	return _list(G, "noLure").has(str(hero.get("id", "")))

static func on_lured(G: Dictionary, pid: int) -> void:
	_bump(G, "lured", pid)

# --- debut / fin de tour -----------------------------------------------------------------------------------------------------

## Debut de tour : photographie les ames (Nicolius).
static func on_turn_start(G: Dictionary) -> void:
	for pid in _pids(G):
		var p := _player(G, int(pid))
		p["tnlSoulsStart"] = CardDB.total_souls(p, G)

## Fin de tour (avant le tour suivant, partie non terminee) : Inner Sanctum, Nicolius, puis les choix Shellda / Blockpile Puzzle.
## Renvoie vrai si un choix est ouvert (le passage au tour suivant attend sa resolution, voir Match._resolve_choice).
static func end_of_turn(G: Dictionary) -> bool:
	if not active(G):
		return false
	for pid in _alive(G):
		var p := _player(G, int(pid))
		for stack in (p.get("dungeon", []) as Array):
			var rv = BossEngine.active_room(stack)
			if rv != null and str((rv as Dictionary).get("id", "")) == "TNL018" and not bool((rv as Dictionary).get("faceDown", false)) \
					and not no_text(rv as Dictionary) and not flag(rv as Dictionary, "entered"):
				draw_logged(G, int(pid), "rooms", 1, "Inner Sanctum") # aucun heros n'y est entre ce tour
		if has_boss(p, "TNL009"):
			var mine := CardDB.total_souls(p, G) - int(p.get("tnlSoulsStart", 0))
			var behind := false
			for oid in _opponents(G, int(pid)):
				var q := _player(G, int(oid))
				if CardDB.total_souls(q, G) - int(q.get("tnlSoulsStart", 0)) >= mine + 2:
					behind = true
			if behind:
				draw_logged(G, int(pid), "spells", 1, "Nicolius")
	for pid in _alive(G):
		var p2 := _player(G, int(pid))
		if has_boss(p2, "TNL005"):
			emit(G, _shellda_choice(G, int(pid)))
		for stack in (p2.get("dungeon", []) as Array):
			var rv2 = BossEngine.active_room(stack)
			if rv2 != null and str((rv2 as Dictionary).get("id", "")) == "TNL047" and not bool((rv2 as Dictionary).get("faceDown", false)) and not no_text(rv2 as Dictionary):
				var opts := room_options(G, "any", -1, -1, int(pid))
				for o in opts:
					(o as Dictionary)["ai"] = -float(int(((o as Dictionary)["card"] as Dictionary).get("damage", 0)))
				emit(G, ask(G, int(pid), "room_target", opts, {"then": "destroy", "label": "Blockpile Puzzle"},
					"Blockpile Puzzle: destroy a Room in your dungeon", "Blockpile Puzzle"))
				break
	return not (G.get("pendingChoice", {}) as Dictionary).is_empty()

## Shellda : echanger deux salles d'un donjon (facultatif) ; d'abord le donjon, puis la paire.
static func _shellda_choice(G: Dictionary, pid: int) -> Variant:
	var opts: Array = []
	for oid in _alive(G):
		var d: Array = _player(G, int(oid)).get("dungeon", [])
		if d.size() >= 2:
			opts.append({"targetPlayerId": int(oid), "label": "Dungeon of player %d" % (int(oid) + 1), "ai": -5.0})
	if opts.is_empty():
		return null
	return ask(G, pid, "swap_dungeon", opts, {}, "Shellda: swap two Rooms in a dungeon (or skip)", "Shellda", true)

## Echange les PILES (« Room stacks always move together ») ; les effets indexes par emplacement suivent leur salle.
static func swap_stacks(G: Dictionary, pid: int, a: int, b: int) -> bool:
	var d: Array = _player(G, pid).get("dungeon", [])
	if a == b or a < 0 or b < 0 or a >= d.size() or b >= d.size():
		return false
	var t = d[a]
	d[a] = d[b]
	d[b] = t
	for key in ["deactivatedRooms", "roomDamageBonus"]:
		for e in (SpellEffects._effects(G).get(key, []) as Array):
			if int((e as Dictionary).get("playerId", -1)) == pid:
				var ri := int((e as Dictionary).get("roomIndex", -1))
				if ri == a:
					e["roomIndex"] = b
				elif ri == b:
					e["roomIndex"] = a
	return true

# --- construction immediate (Fangroot Garden, Wild Monster) -----------------------------------------------------------------

## Emplacements ou `card` peut etre pose MAINTENANT par-dessus (sommet visible, ni gele ni en attente ; avancee : tresor commun).
static func build_slots(G: Dictionary, pid: int, card: Dictionary) -> Array:
	var out: Array = []
	if BossEngine.is_build_blocked(G) or not bool(card.get("isRoom", false)):
		return out
	var dungeon: Array = _player(G, pid).get("dungeon", [])
	for i in dungeon.size():
		var rv = SpellTargeting._targetable_top(G, pid, i, dungeon[i])
		if rv == null:
			continue
		var host: Dictionary = rv
		if bool(card.get("advanced", false)):
			if str(host.get("id", "")) == "BMA018":
				continue
			var ok := false
			for t in (card.get("treasures", []) as Array):
				ok = ok or BossEngine.room_treasures(host).has(int(t))
			if not ok:
				continue
		out.append({"roomIndex": i, "card": host, "label": "over %s" % _label(host), "ai": -float(int(host.get("damage", 0)))})
	return out

## Choix « construire immediatement une salle » : `kind` = any | monster ; d'abord la carte, puis l'emplacement. Null s'il n'y a rien a poser.
static func build_choice(G: Dictionary, pid: int, kind: String, label: String) -> Variant:
	var opts: Array = []
	for o in hand_options(_player(G, pid), "monster" if kind == "monster" else "room"):
		if not build_slots(G, pid, (o as Dictionary)["card"] as Dictionary).is_empty():
			(o as Dictionary)["ai"] = _ai_value((o as Dictionary)["card"] as Dictionary)
			opts.append(o)
	if opts.is_empty():
		_log(G, "%s: no Room can be built." % label)
		return null
	return ask(G, pid, "build_card", opts, {"label": label}, "%s: choose a Room to build over an existing Room" % label, label, kind == "any")

## Pose `card` (venant de la main) face visible par-dessus l'emplacement `slot` ; ses effets « build » s'appliquent a l'instant.
static func build_now(G: Dictionary, pid: int, card: Dictionary, slot: int, label: String) -> Variant:
	var p := _player(G, pid)
	var dungeon: Array = p.get("dungeon", [])
	if slot < 0 or slot >= dungeon.size() or not take_from_hand(G, pid, card):
		return null
	card["faceDown"] = false
	card.erase("builtThisTurn")
	(dungeon[slot] as Array).append(card)
	_log(G, "%s: %s built over the Room in slot %d." % [label, _label(card), slot + 1])
	return RoomAbilities.on_build_room(G, pid, card)

# --- activation des salles du donjon --------------------------------------------------------------------------------------------

const ACTIVATED := ["TNL013", "TNL017", "TNL022", "TNL030", "TNL032", "TNL033", "TNL035", "TNL040", "TNL041", "TNL042", "TNL045", "TNL046",
	"TNL048", "TNL049", "TNL053", "TNL055"]

## Active la capacite de la salle `room_index` (appelee par RoomAbilities.activate_room_ability, deja filtree : non utilisee, non verrouillee,
## texte actif). Toutes les cibles sont verifiees AVANT tout cout ; les choix suivent (tnl-pick). Renvoie null ou un message d'erreur.
static func activate(G: Dictionary, p: Dictionary, pid: int, room_index: int, r: Dictionary) -> Variant:
	var id := str(r.get("id", ""))
	var phase := str(G.get("phase", ""))
	if phase != "build" and phase != "adventure":
		return "Room abilities can only be used in the Build or Adventure phase"
	match id:
		"TNL013": # Dark Portal : defausse un sort -> recupere une salle de la defausse
			if hand_options(p, "spell").is_empty():
				return "no Spell to discard"
			if RoomAbilities.discard_card_options(G, "room").is_empty():
				return "no Room in the discard pile"
			r["usedThisTurn"] = true
			emit(G, ask(G, pid, "cost", hand_options(p, "spell"), {"then": "take_room", "label": "Dark Portal"}, "Dark Portal: choose a Spell to discard", "Dark Portal"))
		"TNL035": # Observatory : defausse un sort -> pioche un sort
			if hand_options(p, "spell").is_empty():
				return "no Spell to discard"
			r["usedThisTurn"] = true
			emit(G, ask(G, pid, "cost", hand_options(p, "spell"), {"then": "draw_spell", "label": "Observatory"}, "Observatory: choose a Spell to discard", "Observatory"))
		"TNL042": # Deadly Treadmill : defausse une salle -> pioche une salle
			if hand_options(p, "room").is_empty():
				return "no Room to discard"
			r["usedThisTurn"] = true
			emit(G, ask(G, pid, "cost", hand_options(p, "room"), {"then": "draw_room", "label": "Deadly Treadmill"}, "Deadly Treadmill: choose a Room to discard", "Deadly Treadmill"))
		"TNL053": # Werewolf Den : defausse une carte -> un heros +1
			var heroes := hero_options(G)
			if (p.get("hand", []) as Array).is_empty() or heroes.is_empty():
				return "no card to discard or no Hero"
			r["usedThisTurn"] = true
			emit(G, ask(G, pid, "cost", hand_options(p, "any"), {"then": "hero_plus", "label": "Werewolf Den"}, "Werewolf Den: choose a card to discard", "Werewolf Den"))
		"TNL022": # Rust Monster Pen : defausse une salle Monster -> une salle Trap -1
			if hand_options(p, "monster").is_empty() or room_options(G, "trap").is_empty():
				return "no Monster Room to discard or no Trap Room"
			r["usedThisTurn"] = true
			emit(G, ask(G, pid, "cost", hand_options(p, "monster"), {"then": "debuff_trap", "label": "Rust Monster Pen"}, "Rust Monster Pen: choose a Monster Room to discard", "Rust Monster Pen"))
		"TNL040": # Bullet Builder : defausse une salle Trap -> une salle Monster -1
			if hand_options(p, "trap").is_empty() or room_options(G, "monster").is_empty():
				return "no Trap Room to discard or no Monster Room"
			r["usedThisTurn"] = true
			emit(G, ask(G, pid, "cost", hand_options(p, "trap"), {"then": "debuff_monster", "label": "Bullet Builder"}, "Bullet Builder: choose a Trap Room to discard", "Bullet Builder"))
		"TNL030": # The Arena : montre une salle Monster de la main (elle y reste) -> +X, X = sa puissance
			if hand_options(p, "monster").is_empty():
				return "no Monster Room in hand"
			r["usedThisTurn"] = true
			emit(G, ask(G, pid, "arena", hand_options(p, "monster"), {"idx": room_index}, "The Arena: reveal a Monster Room from your hand", "The Arena"))
		"TNL041", "TNL046": # Wreck Room / Chump Chomper : detruit une AUTRE salle de son donjon
			var targets := room_options(G, "any", pid, room_index, pid)
			if targets.is_empty():
				return "no other Room to destroy"
			r["usedThisTurn"] = true
			var then := "wreck" if id == "TNL041" else "chomp"
			var nm := "Wreck Room" if id == "TNL041" else "Chump Chomper"
			for o in targets:
				(o as Dictionary)["ai"] = -float(int(((o as Dictionary)["card"] as Dictionary).get("damage", 0)))
			emit(G, ask(G, pid, "room_target", targets, {"then": then, "label": nm, "idx": room_index}, "%s: choose another Room of your dungeon to destroy" % nm, nm))
		"TNL048": # The Smashinator : detruit toutes les AUTRES salles visibles -> +6
			var others := room_options(G, "any", pid, room_index, pid)
			if others.is_empty():
				return "no other visible Room"
			r["usedThisTurn"] = true
			var idxs: Array = []
			for o in others:
				idxs.append(int((o as Dictionary)["roomIndex"]))
			idxs.sort()
			idxs.reverse() # du fond vers l'entree : les index restants ne bougent pas
			for ri in idxs:
				destroy_room_at(G, pid, int(ri), "The Smashinator")
			SpellEffects._buff_room_instance(r, 6)
			_log(G, "The Smashinator: +6 until end of turn.")
		"TNL032": # Lost Library : se detruit, pioche 2 sorts, defausse un sort
			destroy_room_at(G, pid, room_index, "Lost Library")
			draw_logged(G, pid, "spells", 2, "Lost Library")
			emit(G, discard_spell_choice(G, pid, "Lost Library"))
		"TNL033": # Frostbat Cave : se detruit -> desactive une salle (autre) d'un donjon
			if room_options(G, "any", pid, room_index).is_empty():
				return "no Room to deactivate"
			destroy_room_at(G, pid, room_index, "Frostbat Cave")
			emit(G, ask(G, pid, "room_target", room_options(G, "any"), {"then": "deactivate", "label": "Frostbat Cave"}, "Frostbat Cave: choose a Room to deactivate", "Frostbat Cave"))
		"TNL045": # Decapitator : (phase de construction) se detruit -> une salle perd son tresor jusqu'a la fin du tour
			if phase != "build":
				return "Build phase only"
			if room_options(G, "any", pid, room_index).is_empty():
				return "no Room to target"
			destroy_room_at(G, pid, room_index, "Decapitator")
			emit(G, ask(G, pid, "room_target", room_options(G, "any"), {"then": "no_treasure", "label": "Decapitator"}, "Decapitator: choose a Room to remove its treasure", "Decapitator"))
		"TNL017", "TNL049": # Haunted Hall / Warp Tube : se detruit, renvoie le heros de CETTE salle en ville / a la 1re salle
			if not RoomAbilities.hero_is_in_room(G, pid, room_index):
				return "no hero in this room"
			if id == "TNL049" and int(adv(G).get("hp", 0)) <= 0:
				return "the Hero is already dead"
			if id == "TNL017":
				send_hero_to_town(G, pid, room_index)
			else:
				warp_hero(G, pid, room_index)
		"TNL055": # Save Point : se detruit -> reprend un sort joue CE tour qui est en defausse
			var opts := played_spell_options(G, pid)
			if opts.is_empty():
				return "no Spell played this turn in the discard pile"
			destroy_room_at(G, pid, room_index, "Save Point")
			emit(G, ask(G, pid, "take_discard", opts, {"label": "Save Point"}, "Save Point: choose a Spell you played this turn", "Save Point"))
		_:
			return "no activated ability"
	return null

## Sorts joues ce tour par `pid` et encore en defausse de sorts.
static func played_spell_options(G: Dictionary, pid: int) -> Array:
	var pile: Array = (G.get("decks", {}) as Dictionary).get("spellDiscard", [])
	var out: Array = []
	for e in _list(G, "played"):
		if int((e as Dictionary).get("pid", -1)) != pid:
			continue
		var c: Dictionary = (e as Dictionary)["card"]
		var at := pile.rfind(c)
		if at >= 0 and not out.any(func(o): return int((o as Dictionary)["pileIndex"]) == at):
			out.append({"card": c, "pile": "spell", "pileIndex": at, "label": _label(c), "ai": 1.0})
	return out

## Tous les heros en jeu : ville, entrees, heros actif (ils se distinguent par leur id).
static func hero_options(G: Dictionary) -> Array:
	var out: Array = []
	for h in (G.get("town", []) as Array):
		out.append({"card": h, "label": "%s (town)" % _label(h as Dictionary), "ai": 0.0})
	for pid in _alive(G):
		for h in (_player(G, int(pid)).get("entrance", []) as Array):
			out.append({"card": h, "label": "%s (P%d)" % [_label(h as Dictionary), int(pid) + 1], "ai": 1.0 if int(pid) == adv(G).get("playerId", -1) else 0.0,
				"ownerPid": int(pid)})
	return out

## Haunted Hall : le heros de cette salle retourne en ville (PlaceAtTown : il quitte l'aventure sans ame ni blessure, sans degats reportes).
static func send_hero_to_town(G: Dictionary, pid: int, room_index: int) -> void:
	var a := adv(G)
	var hero: Dictionary = a.get("hero", {})
	var p := _player(G, pid)
	var entrance: Array = p.get("entrance", []) as Array
	var at := entrance.find(hero)
	if at >= 0:
		entrance.remove_at(at)
	G["adventure"] = {}
	G["adventurePausePassed"] = {}
	var town: Array = G.get("town", [])
	G["town"] = town
	town.append(hero)
	destroy_room_at(G, pid, room_index, "Haunted Hall")
	_log(G, "Haunted Hall: %s returns to town." % _label(hero))

## Warp Tube : se detruit, le heros repart de la premiere salle (il garde ses degats).
static func warp_hero(G: Dictionary, pid: int, room_index: int) -> void:
	var a := adv(G)
	destroy_room_at(G, pid, room_index, "Warp Tube")
	a["roomIndex"] = -1
	for k in ["roomGone", "replay", "back", "nearest"]:
		a.erase(k)
	_log(G, "Warp Tube: %s is sent back to the first Room." % str((a.get("hero", {}) as Dictionary).get("name", "?")))

# --- resolution des choix ---------------------------------------------------------------------------------------------------------

## Resout une option du choix `pc` (type tnl-pick). Renvoie le choix suivant, ou null. idx = -1 : option facultative passee.
static func resolve_pick(G: Dictionary, pid: int, pc: Dictionary, idx: int) -> Variant:
	var opts: Array = pc.get("options", [])
	var ctx: Dictionary = pc.get("ctx", {}) as Dictionary
	var step := str(pc.get("step", ""))
	var p := _player(G, pid)
	var o: Dictionary = (opts[idx] as Dictionary) if idx >= 0 and idx < opts.size() else {}
	if step.begins_with("sp_"):
		return TnlSpells.resolve_pick(G, pid, pc, idx)
	if step.begins_with("rmb_"): # Rise of the Minibosses (RmbAbilities.resolve_pick, RmbSpells pour « rmb_sp_ »)
		return RmbAbilities.resolve_pick(G, pid, pc, idx)
	if idx < 0 and step != "swap_dungeon" and step != "swap_pair":
		return null
	match step:
		"cost": # paye le cout (defausse d'une carte de la main), puis enchaine
			var card: Dictionary = o.get("card", {})
			if not discard_from_hand(G, pid, card):
				return null
			return _after_cost(G, pid, ctx, card)
		"take_discard":
			var got = RoomAbilities.take_discard_card(G, p, o)
			if got != null:
				_log(G, "%s: %s recovered." % [str(ctx.get("label", "?")), _label(got as Dictionary)])
		"discard_one":
			discard_from_hand(G, pid, o.get("card", {}))
		"room_target":
			return _room_target(G, pid, ctx, o)
		"hero_plus":
			add_hero_hp(G, o.get("card", {}), 1)
			_log(G, "Werewolf Den: %s gains +1 Health." % _label(o.get("card", {})))
		"arena":
			var power := int((o.get("card", {}) as Dictionary).get("damage", 0))
			var rv = BossEngine.active_room((p.get("dungeon", []) as Array)[int(ctx.get("idx", 0))]) if int(ctx.get("idx", 0)) < (p.get("dungeon", []) as Array).size() else null
			if rv != null:
				SpellEffects._buff_room_instance(rv as Dictionary, power)
				_log(G, "The Arena: reveals %s, +%d until end of turn." % [_label(o.get("card", {})), power])
		"forced":
			var victim := pid
			_forced_take(G, int(ctx.get("actor", -1)), victim, o.get("card", {}))
			var left := int(ctx.get("remaining", 1)) - 1
			if left > 0:
				return force_discard(G, int(ctx.get("actor", -1)), victim, str(ctx.get("kind", "room")), left, str(ctx.get("label", "")))
		"mirrax":
			var icons: Array = (p.get("bonusTreasures", []) as Array)
			for t in (o.get("icons", []) as Array):
				icons.append(int(t))
			p["bonusTreasures"] = icons
			_log(G, "Mirrax: gains the treasure icons of %s." % str((o.get("card", {}) as Dictionary).get("name", "?")))
		"heal":
			BossEngine.heal_one_wound(p, o.get("card", {}))
			_log(G, "Belladonna: heals %s." % _label(o.get("card", {})))
		"unflip":
			unflip_hero(p, o.get("card", {}))
			_log(G, "Necromancer: %s is turned face-up." % _label(o.get("card", {})))
		"porkus_remove":
			var hero: Dictionary = o.get("card", {})
			if remove_soul_hero(p, hero):
				_remove_from_game(G, hero)
				_log(G, "Porkus: %s is removed from the game." % _label(hero))
			return _porkus_search(G, pid)
		"porkus_search":
			var deck: Array = (G["decks"] as Dictionary).get(str(o.get("pile", "heroes")), [])
			var di := int(o.get("deckIndex", -1))
			if di >= 0 and di < deck.size() and str((deck[di] as Dictionary).get("id", "")) == str((o.get("card", {}) as Dictionary).get("id", "")):
				var h: Dictionary = deck.pop_at(di)
				for _s in BossEngine.hero_souls(h):
					(p["souls"] as Array).append(CardDB.soul_entry(h))
				deck.shuffle() # « search » : la pioche est remelangee
				_log(G, "Porkus: %s is placed face-down in the scorekeeping area." % _label(h), "Porkus: a Hero is placed face-down in the scorekeeping area.", [int(p.get("id", -1))])
		"swap_dungeon":
			if idx < 0:
				return null
			var tp := int(o.get("targetPlayerId", -1))
			var d: Array = _player(G, tp).get("dungeon", [])
			var pairs: Array = []
			for a in d.size():
				for b in range(a + 1, d.size()):
					pairs.append({"targetPlayerId": tp, "a": a, "b": b, "label": "%s <-> %s" % [_label(BossEngine.active_room(d[a]) as Dictionary), _label(BossEngine.active_room(d[b]) as Dictionary)], "ai": -5.0})
			return ask(G, pid, "swap_pair", pairs, {}, "Shellda: choose the two Rooms to swap", "Shellda", true)
		"swap_pair":
			if idx >= 0 and swap_stacks(G, int(o.get("targetPlayerId", -1)), int(o.get("a", -1)), int(o.get("b", -1))):
				_log(G, "Shellda: swapped two Rooms of player %d's dungeon." % (int(o.get("targetPlayerId", 0)) + 1))
		"build_card":
			var bc: Dictionary = o.get("card", {})
			var slots := build_slots(G, pid, bc)
			if slots.is_empty():
				return null
			return ask(G, pid, "build_slot", slots, {"card": bc, "label": str(ctx.get("label", ""))}, "%s: choose where to build %s" % [str(ctx.get("label", "")), _label(bc)], str(ctx.get("label", "")))
		"build_slot":
			return build_now(G, pid, ctx.get("card", {}), int(o.get("roomIndex", -1)), str(ctx.get("label", "")))
	return null

## Suite d'un cout paye : ce que la capacite fait de la carte defaussee.
static func _after_cost(G: Dictionary, pid: int, ctx: Dictionary, card: Dictionary) -> Variant:
	var label := str(ctx.get("label", "?"))
	match str(ctx.get("then", "")):
		"take_room":
			return recover_choice(G, pid, "room", label)
		"draw_spell":
			draw_logged(G, pid, "spells", 1, label)
		"draw_room":
			draw_logged(G, pid, "rooms", 1, label)
		"debuff_trap":
			return ask(G, pid, "room_target", room_options(G, "trap"), {"then": "buff", "amount": -1, "label": label}, "%s: choose a Trap Room (-1)" % label, label)
		"debuff_monster":
			return ask(G, pid, "room_target", room_options(G, "monster"), {"then": "buff", "amount": -1, "label": label}, "%s: choose a Monster Room (-1)" % label, label)
		"hero_plus":
			return ask(G, pid, "hero_plus", hero_options(G), {}, "Werewolf Den: choose a Hero (+1 Health)", label)
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
		"buff":
			var amount := int(ctx.get("amount", 0))
			SpellEffects._buff_room_instance(room, amount)
			_log(G, "%s: %s %s%d until end of turn." % [label, _label(room), "+" if amount >= 0 else "", amount])
		"destroy":
			destroy_room_at(G, tp, ri, label)
		"deactivate":
			(SpellEffects._effects(G)["deactivatedRooms"] as Array).append({"playerId": tp, "roomIndex": ri})
			_log(G, "%s: %s is deactivated until end of turn." % [label, _label(room)])
		"no_treasure":
			_tag(room)["noTreasure"] = true
			_log(G, "%s: %s loses its treasure until end of turn." % [label, _label(room)])
		"wreck", "chomp":
			var me := _player(G, pid)
			var self_room = BossEngine.active_room((me.get("dungeon", []) as Array)[int(ctx.get("idx", 0))]) if int(ctx.get("idx", 0)) < (me.get("dungeon", []) as Array).size() else null
			destroy_room_at(G, tp, ri, label)
			if str(ctx.get("then", "")) == "wreck":
				draw_logged(G, pid, "rooms", 1, label)
			elif self_room != null:
				SpellEffects._buff_room_instance(self_room as Dictionary, 4)
				_log(G, "Chump Chomper: +4 until end of turn.")
	return null

## Retourne un heros face cachee face visible (ses blessures remplacent ses ames) : l'inverse de heal_one_wound.
static func unflip_hero(p: Dictionary, hero: Dictionary) -> void:
	if not remove_soul_hero(p, hero):
		return
	var wounds: Array = p.get("wounds", []) as Array
	p["wounds"] = wounds
	for _w in BossEngine.hero_wounds(hero):
		wounds.append({"name": hero.get("name", "?"), "wounds": 1, "souls": 1, "class": hero.get("class", ""), "faceDown": false, "hero": hero})

# --- coups TNL (legal_moves / apply_move) ------------------------------------------------------------------------------------

## Cartes de la main d'un joueur qui paient un heros noir : une salle portant le tresor du heros.
static func _pays_dark(card: Dictionary, hero: Dictionary) -> bool:
	if not bool(card.get("isRoom", false)):
		return false
	for t in (card.get("treasures", []) as Array):
		if int(t) == int(hero.get("treasure", -1)):
			return true
	return false

## Heros noirs payables par un adversaire de leur donjon : le heros actif et ceux a l'entree, une seule fois par tour et par heros.
static func dark_heroes(G: Dictionary, payer: int) -> Array:
	var out: Array = []
	var a := adv(G)
	for owner in _alive(G):
		if int(owner) == payer:
			continue
		var ent: Array = _player(G, int(owner)).get("entrance", []) as Array
		for h in ent:
			var hd: Dictionary = h
			if hero_cmd(hd) == DARK_PAY and not _list(G, "darkPaid").has(str(hd.get("id", ""))) and not text_ignored(G, int(owner)):
				out.append({"owner": int(owner), "hero": hd, "active": not a.is_empty() and is_same(a.get("hero"), hd)})
	return out

## Coups supplementaires d'un joueur : Doc Scarecrow (construction) et paiement des heros noirs (aventure). Pile vide uniquement.
static func extra_moves(G: Dictionary, p: Dictionary, pid: int) -> Array:
	var out: Array = []
	if not (G.get("stack", []) as Array).is_empty():
		return out
	var phase := str(G.get("phase", ""))
	var hand: Array = p.get("hand", []) as Array
	if phase == "build" and has_boss(p, "TNL001") and not used(G, pid, "scarecrow"):
		var town: Array = G.get("town", [])
		for hi in hand.size():
			for ti in town.size():
				if not no_lure(G, town[ti]):
					out.append({"type": "docScarecrow", "args": [hi, ti]})
	if phase == "adventure":
		for dh in dark_heroes(G, pid):
			for hi in hand.size():
				if _pays_dark(hand[hi], (dh as Dictionary)["hero"]):
					out.append({"type": "payDarkHero", "args": [hi, int((dh as Dictionary)["owner"]), str(((dh as Dictionary)["hero"] as Dictionary).get("id", ""))]})
	return out

## Reponses pendant une Spell Battle : Antimagic Zone (depuis la main) et Dr. Timebender (defausse d'un sort). Tous deux « cancel ».
static func stack_moves(G: Dictionary, p: Dictionary, pid: int) -> Array:
	var out: Array = []
	if RoomAbilities._last_opponent_spell_index(G, pid) < 0:
		return out
	var hand: Array = p.get("hand", []) as Array
	for hi in hand.size():
		if str((hand[hi] as Dictionary).get("id", "")) == "TNL031":
			out.append({"type": "antimagicCancel", "args": [hi]})
	if has_boss(p, "TNL008") and not used(G, pid, "timebender"):
		for hi in hand.size():
			if bool((hand[hi] as Dictionary).get("isSpell", false)):
				out.append({"type": "timebenderCancel", "args": [hi]})
	return out

static func is_tnl_move(mtype: String) -> bool:
	return ["docScarecrow", "payDarkHero", "timebenderCancel", "antimagicCancel"].has(mtype)

## Applique un coup TNL deja valide par legal_moves. Renvoie null ou un message d'erreur.
static func apply_move(G: Dictionary, pid: int, move: Dictionary) -> Variant:
	var args: Array = move.get("args", [])
	var p := _player(G, pid)
	var hand: Array = p.get("hand", []) as Array
	var hi := int(args[0]) if not args.is_empty() else -1
	if hi < 0 or hi >= hand.size():
		return "no such card"
	var card: Dictionary = hand[hi]
	match str(move.get("type", "")):
		"docScarecrow":
			var town: Array = G.get("town", [])
			var ti := int(args[1])
			if ti < 0 or ti >= town.size():
				return "no such Hero in town"
			discard_from_hand(G, pid, card)
			_list(G, "noLure").append(str((town[ti] as Dictionary).get("id", "")))
			mark_used(G, pid, "scarecrow")
			_log(G, "Doc Scarecrow: %s cannot be lured this turn." % _label(town[ti] as Dictionary))
		"payDarkHero":
			var owner := _player(G, int(args[1]))
			var hero: Dictionary = {}
			for h in (owner.get("entrance", []) as Array):
				if str((h as Dictionary).get("id", "")) == str(args[2]):
					hero = h
			if hero.is_empty():
				return "no such Hero"
			discard_from_hand(G, pid, card)
			_list(G, "darkPaid").append(str(hero.get("id", "")))
			var plus := hero_arg(hero, 3)
			add_hero_hp(G, hero, plus)
			_log(G, "%s: Player %d pays %s, +%d Health until end of turn." % [_label(hero), pid + 1, _label(card), plus])
		"antimagicCancel": # Antimagic Zone : defausse cette salle de la main pour annuler un sort adverse
			if str(card.get("id", "")) != "TNL031":
				return "not Antimagic Zone"
			discard_from_hand(G, pid, card)
			RoomAbilities.cancel_last_opponent_spell(G, pid, "Antimagic Zone")
		"timebenderCancel":
			discard_from_hand(G, pid, card)
			mark_used(G, pid, "timebender")
			RoomAbilities.cancel_last_opponent_spell(G, pid, "Dr. Timebender")
	return null

# --- IA (heuristiques maison : l'APK n'a pas ces cartes) -------------------------------------------------------------------------

static func score_move(G: Dictionary, p: Dictionary, pid: int, mtype: String, args: Array) -> float:
	match mtype:
		"docScarecrow":
			return -5.0
		"payDarkHero": # sauver un heros noir qui allait mourir
			var a := adv(G)
			var hero: Dictionary = {}
			for h in (_player(G, int(args[1])).get("entrance", []) as Array):
				if str((h as Dictionary).get("id", "")) == str(args[2]):
					hero = h
			if not a.is_empty() and is_same(a.get("hero"), hero) and int(a.get("hp", 1)) <= 0 and int(a.get("hp", 1)) + 3 > 0:
				return 60.0
			return -5.0
		"timebenderCancel":
			return 100.0
		"antimagicCancel":
			return 120.0
	return 0.0

static func score_activate(G: Dictionary, p: Dictionary, pid: int, rid: String) -> float:
	match rid:
		"TNL013", "TNL035", "TNL042": return 12.0
		"TNL030": return 15.0
		"TNL053", "TNL022", "TNL040": return -5.0
		"TNL017", "TNL049": return -5.0
		"TNL032": return 3.0
		"TNL055": return 5.0
	return -10.0
