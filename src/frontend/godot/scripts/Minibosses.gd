class_name Minibosses
extends RefCounted
## Extension « Boss Monster : Rise of the Minibosses » (RMB, 121 cartes : 12 boss, 42 salles, 15 sorts, 42 heros, 10 minibosses), hors APK.
## Sources, par priorite : docs/rules/rules.md (livret Minibosses + guide officieux : Minibosses, Coins, sequence de jeu), texte des cartes
## (cards.json, wiki), puis le JS (minibosses.js, roomAbilities.js...) quand il ne contredit ni l'un ni l'autre.
## Ce fichier : pieces (Coins), minibosses (pose, revelation, promotion, niveaux 1-3) et crochets du moteur. Les salles / boss / mains RMB sont
## dans RmbAbilities.gd, les sorts dans RmbSpells.gd. Tout est garde par `Minibosses.active(G)` (le set `minibosses` est choisi) : le jeu de base
## et les paquets de l'APK ne changent pas d'un octet.
##
## Modele : un Miniboss est « attache a la salle du sommet » de sa pile (regle officieuse) : il vit dans le dictionnaire de cette salle,
## `room.mb = {card, level 1..3, faceDown, since (tour de revelation), usedTurn (dernier tour d'un pouvoir « une fois par tour »)}`.
## Quand une salle est posee par-dessus, ou que la salle detruite decouvre une autre salle, il saute sur la nouvelle salle du sommet
## (normalize / on_destroy). Les Coins sont `player.coins` ; ceux poses sur une salle sont `room.coins` (perdus si elle est couverte / detruite).
## Effets « jusqu'a la fin du tour » : sac `G.effects.rmb` (remis a zero a chaque tour avec G.effects).

const SET_ID := "minibosses"
const START_COINS := 3
## Icone de tresor ajoutee par le niveau 1 : Kid Croak (Fighter), Draculad (Cleric), Cerebella (Mage), Paddywhack (Thief).
const L1_TREASURE := {"RMB056": 2, "RMB057": 1, "RMB059": 3, "RMB060": 4}
## Niveau 1 « cette salle a +1 » : Spike, Icicle Man, Brassknuckle.
const L1_DAMAGE := ["RMB055", "RMB061", "RMB063"]

static func active(G: Dictionary) -> bool:
	return (G.get("sets", []) as Array).has(SET_ID)

static func _player(G: Dictionary, pid: int) -> Dictionary:
	return TnlAbilities._player(G, pid)

static func _log(G: Dictionary, t: String, pub: String = "", owners: Array = []) -> void:
	TnlAbilities._log(G, t, pub, owners)

static func _label(c: Dictionary) -> String:
	return TnlAbilities._label(c)

# --- sac d'effets du tour -----------------------------------------------------------------------------------------

static func bag(G: Dictionary) -> Dictionary:
	var eff: Dictionary = SpellEffects._effects(G)
	var b = eff.get("rmb")
	if not (b is Dictionary):
		b = {}
		eff["rmb"] = b
	return b as Dictionary

static func list(G: Dictionary, key: String) -> Array:
	var b := bag(G)
	if not (b.get(key) is Array):
		b[key] = []
	return b[key] as Array

static func used(G: Dictionary, pid: int, key: String) -> bool:
	var u = bag(G).get("used")
	return u is Dictionary and bool((u as Dictionary).get("%d:%s" % [pid, key], false))

static func mark_used(G: Dictionary, pid: int, key: String) -> void:
	var b := bag(G)
	if not (b.get("used") is Dictionary):
		b["used"] = {}
	(b["used"] as Dictionary)["%d:%s" % [pid, key]] = true

# --- Coins --------------------------------------------------------------------------------------------------------

static func coins(p: Dictionary) -> int:
	return int(p.get("coins", 0))

## Gagne n Coins (Paddywhack niveau 2 : une fois par tour, un Coin de plus quand on en gagne un ou plusieurs).
static func gain_coin(G: Dictionary, pid: int, n: int, label: String) -> void:
	if n <= 0:
		return
	var p := _player(G, pid)
	if p.is_empty():
		return
	var total := n
	if not used(G, pid, "paddywhack"):
		for stack in (p.get("dungeon", []) as Array):
			var m := revealed(BossEngine.active_room(stack))
			if not m.is_empty() and mb_id(m) == "RMB060" and level(m) >= 2:
				mark_used(G, pid, "paddywhack")
				total += 1
				break
	p["coins"] = coins(p) + total
	_log(G, "%s: player %d gains %d Coin(s) (%d)." % [label, pid + 1, total, coins(p)])

static func pay_coin(G: Dictionary, pid: int, n: int) -> bool:
	var p := _player(G, pid)
	if p.is_empty() or coins(p) < n:
		return false
	p["coins"] = coins(p) - n
	return true

# --- acces aux minibosses -------------------------------------------------------------------------------------------

static func mb_of(room) -> Dictionary:
	if not (room is Dictionary):
		return {}
	var m = (room as Dictionary).get("mb")
	return m as Dictionary if m is Dictionary else {}

## Miniboss REVELE de la salle (celui dont les niveaux comptent) ; {} s'il est encore face cachee.
static func revealed(room) -> Dictionary:
	var m := mb_of(room)
	return {} if m.is_empty() or bool(m.get("faceDown", false)) else m

static func mb_id(m: Dictionary) -> String:
	return str((m.get("card", {}) as Dictionary).get("id", ""))

static func mb_name(m: Dictionary) -> String:
	return str((m.get("card", {}) as Dictionary).get("name", "?"))

static func level(m: Dictionary) -> int:
	return int(m.get("level", 1))

## Un miniboss se trouve-t-il dans cette pile (sur n'importe quelle salle : il peut attendre sous une salle posee face cachee) ?
static func stack_has_mb(stack) -> bool:
	if not (stack is Array):
		return false
	for r in (stack as Array):
		if not mb_of(r).is_empty():
			return true
	return false

## Tous les minibosses en jeu : [{pid, idx, room, mb}] (revele = true : seulement ceux face visible).
static func all_mbs(G: Dictionary, only_revealed: bool = true) -> Array:
	var out: Array = []
	for pid in TnlAbilities._alive(G):
		var d: Array = _player(G, int(pid)).get("dungeon", [])
		for i in d.size():
			var room = BossEngine.active_room(d[i])
			var m := revealed(room) if only_revealed else mb_of(room)
			if not m.is_empty():
				out.append({"pid": int(pid), "idx": i, "room": room, "mb": m})
	return out

## Minibosses poses face cachee, qui devront payer 1 Coin a la revelation de fin de BUILD.
static func facedown_count(p: Dictionary) -> int:
	var n := 0
	for stack in (p.get("dungeon", []) as Array):
		for r in (stack as Array):
			n += 1 if bool(mb_of(r).get("faceDown", false)) else 0
	return n

static func count_revealed(p: Dictionary) -> int:
	var n := 0
	for stack in (p.get("dungeon", []) as Array):
		if not revealed(BossEngine.active_room(stack)).is_empty():
			n += 1
	return n

static func miniboss_cards_in_hand(p: Dictionary) -> Array:
	return (p.get("hand", []) as Array).filter(func(c): return bool((c as Dictionary).get("isMiniboss", false)))

## Cree le miniboss d'une carte de la main sur `room` (face cachee jusqu'a la revelation de fin de BUILD).
static func attach(G: Dictionary, pid: int, room: Dictionary, card: Dictionary, face_down: bool = true) -> void:
	var start := 2 if RmbAbilities.has_boss(_player(G, pid), "RMB005") else 1 # King Croak : les minibosses poses commencent au niveau 2
	room["mb"] = {"card": card, "level": start, "faceDown": face_down, "since": int(G.get("turn", 0)), "usedTurn": -1}

# --- normalisation : le miniboss suit la salle du sommet ---------------------------------------------------------------

## « A Miniboss is always attached to the topmost Room » : si une salle a ete posee par-dessus (et est revelee), il saute dessus. Les Coins posees
## sur une salle couverte sont perdues. Appele en fin de coup, a la revelation de fin de BUILD et apres une destruction.
static func normalize(G: Dictionary) -> void:
	for pid in (G.get("players", {}) as Dictionary).keys():
		var dungeon: Array = _player(G, int(pid)).get("dungeon", []) as Array
		for si in dungeon.size():
			var st: Array = dungeon[si]
			if not st.is_empty() and BossEngine.is_room_deactivated(G, int(pid), si):
				(st[st.size() - 1] as Dictionary).erase("coins") # une salle desactivee perd les Coins posees dessus
			if st.size() < 2:
				continue
			var top: Dictionary = st[st.size() - 1]
			for k in range(st.size() - 1):
				var under: Dictionary = st[k]
				under.erase("coins")
				if under.has("mb") and not bool(top.get("faceDown", false)):
					var m: Dictionary = under["mb"]
					under.erase("mb")
					if top.has("mb"):
						drop_card(G.get("decks", {}), m) # deux minibosses sur une pile : l'ancien est defausse
					else:
						top["mb"] = m

## La carte miniboss `m` quitte le jeu : en defausse de salles (les minibosses viennent de la pioche de salles).
static func drop_card(decks: Dictionary, m: Dictionary) -> void:
	var c = m.get("card")
	if c is Dictionary:
		var pile: Array = decks.get("roomDiscard", [])
		decks["roomDiscard"] = pile
		pile.append(c)

## BossEngine.destroy_room : la salle detruite perd son miniboss au profit de la salle decouverte, ou le defausse s'il n'y en a pas.
static func on_destroy(G: Dictionary, player: Dictionary, destroyed: Dictionary, stack: Array) -> void:
	if destroyed.has("mb"):
		var m: Dictionary = destroyed["mb"]
		destroyed.erase("mb")
		if stack.is_empty():
			drop_card(G.get("decks", {}), m)
		else:
			var under: Dictionary = stack[stack.size() - 1]
			if under.has("mb"):
				drop_card(G.get("decks", {}), m)
			else:
				under["mb"] = m
	destroyed.erase("coins")
	RmbAbilities.on_destroyed(G, int(player.get("id", -1)), destroyed)

## BossEngine.discard_room_to_pile : une salle qui quitte le jeu garde ni Coins ni etat RMB ; son miniboss (cas d'une destruction sans
## passage par on_destroy) part en defausse.
static func cleanup_discarded(decks: Dictionary, card: Dictionary) -> void:
	card.erase("coins")
	card.erase("rmb")
	if card.has("mb"):
		var m: Dictionary = card["mb"]
		card.erase("mb")
		drop_card(decks, m)

# --- passifs : tresors, degats, texte des heros ------------------------------------------------------------------------

## Icones ajoutees par le niveau 1 (et par Jinx niveau 2 : une copie de plus de chaque icone imprimee). `base` = icones deja comptees.
static func mb_treasures(room: Dictionary, base: Array) -> Array:
	var out: Array = []
	var m := revealed(room)
	if m.is_empty():
		return out
	var id := mb_id(m)
	if L1_TREASURE.has(id):
		out.append(int(L1_TREASURE[id]))
	if id == "RMB064" and level(m) >= 2:
		for t in base:
			out.append(int(t))
	return out

## Bonus de degats passifs RMB pour la salle `room_index` de `player` (appele par BossEngine.room_damage_with_modifiers).
static func passive_damage(G: Dictionary, player: Dictionary, room_index: int, r: Dictionary, locked: bool) -> int:
	var dmg := 0
	var pid := int(player.get("id", 0))
	var dungeon: Array = player.get("dungeon", [])
	var m := revealed(r)
	if not m.is_empty():
		var id := mb_id(m)
		if L1_DAMAGE.has(id):
			dmg += 1
		elif id == "RMB062": # Mageseeker : +1 par icone de tresor de la salle
			dmg += BossEngine.room_treasures(r).size()
	if locked or TnlAbilities.no_text(r):
		return dmg
	dmg += RmbAbilities.passive_room_damage(G, player, room_index, r, dungeon)
	if RmbAbilities.has_boss(player, "RMB011") and str(r.get("type", "")) == "trap" and not RmbAbilities._scott_off(G, pid):
		dmg += 1 # Scott : vos salles Trap ont +1 (un adversaire peut payer un Coin pour l'annuler jusqu'a la fin du tour)
	return dmg

## Les capacites des heros de ce donjon sont-elles ignorees ? Icicle Man niveau 2 (heros dans le donjon ou a l'entree) et Cerebella niveau 3.
static func hero_text_ignored(G: Dictionary, pid: int) -> bool:
	if list(G, "ignoreText").has(pid):
		return true
	for stack in (_player(G, pid).get("dungeon", []) as Array):
		var m := revealed(BossEngine.active_room(stack))
		if not m.is_empty() and mb_id(m) == "RMB061" and level(m) >= 2:
			return true
	return false

## Icones de tresor ajoutees ce tour au donjon de `pid` (Kirax, Endless Gallery) ; lecture seule.
static func extra_icons(G: Dictionary, pid: int) -> Array:
	var out: Array = []
	var b = (G.get("effects", {}) as Dictionary).get("rmb")
	if b is Dictionary and (b as Dictionary).get("icons") is Array:
		for e in ((b as Dictionary)["icons"] as Array):
			if int((e as Dictionary).get("pid", -1)) == pid:
				out.append(int((e as Dictionary).get("treasure", 1)))
	return out

## Rocky niveau 1 : n'importe quelle salle se construit par-dessus, quelle que soit l'icone de tresor.
static func rocky_host(room) -> bool:
	var m := revealed(room)
	return not m.is_empty() and mb_id(m) == "RMB058"

# --- heros bloques a l'entree (Haunted Cavern), debut d'aventure -----------------------------------------------------------------

static func hero_blocked(G: Dictionary, hero: Dictionary) -> bool:
	return list(G, "blocked").has(str(hero.get("id", "")))

## Premier heros de l'entree qui peut entrer (-1 si aucun) : Haunted Cavern en laisse certains a l'entree jusqu'au tour suivant.
static func first_free_hero(G: Dictionary, entrance: Array) -> int:
	for i in entrance.size():
		if not hero_blocked(G, entrance[i]):
			return i
	return -1

## Mageseeker niveau 3 : les heros qui entrent dans ce donjon sautent sa premiere salle.
static func skips_first_room(G: Dictionary, pid: int) -> bool:
	return (SpellEffects._effects(G).get("skipFirstRoomPids", []) as Array).has(pid)

# --- pose d'un miniboss ---------------------------------------------------------------------------------------------------------

## Emplacements ou un miniboss peut etre pose : sommet visible, pas deja porteur d'un miniboss, et aucune pile voisine n'en porte un.
static func host_slots(G: Dictionary, pid: int) -> Array:
	var out: Array = []
	var d: Array = _player(G, pid).get("dungeon", [])
	for i in d.size():
		var top = SpellTargeting._targetable_top(G, pid, i, d[i])
		if top == null or stack_has_mb(d[i]):
			continue
		if (i > 0 and stack_has_mb(d[i - 1])) or (i + 1 < d.size() and stack_has_mb(d[i + 1])):
			continue
		out.append({"roomIndex": i, "card": top, "label": "over %s" % _label(top as Dictionary), "ai": -float(int((top as Dictionary).get("damage", 0))) + float((top as Dictionary).get("treasures", []).size())})
	return out

## Le joueur peut-il construire (miniboss ou salle) maintenant ?
static func can_build_now(G: Dictionary, p: Dictionary, pid: int) -> bool:
	if BossEngine.is_build_blocked(G) or BossEngine.no_entry(pid, G):
		return false
	return int(p.get("buildsThisTurn", 0)) < 1 + BossEngine.extra_builds_for(G, pid)

## Pose face cachee `hand[hand_idx]` (un miniboss) sur le sommet de l'emplacement `slot` : remplace une construction de salle.
static func apply_build(G: Dictionary, pid: int, hand_idx: int, slot: int) -> bool:
	var p := _player(G, pid)
	var hand: Array = p.get("hand", [])
	if hand_idx < 0 or hand_idx >= hand.size() or not bool((hand[hand_idx] as Dictionary).get("isMiniboss", false)):
		return false
	var ok := false
	for o in host_slots(G, pid):
		ok = ok or int((o as Dictionary)["roomIndex"]) == slot
	if not ok or not can_build_now(G, p, pid):
		return false
	var card: Dictionary = hand.pop_at(hand_idx)
	p["hand"] = hand
	var room: Dictionary = BossEngine.active_room((p["dungeon"] as Array)[slot])
	attach(G, pid, room, card, true)
	p["buildsThisTurn"] = int(p.get("buildsThisTurn", 0)) + 1
	_log(G, "Player %d places %s face-down over %s." % [pid + 1, _label(card), _label(room)], "Player %d places a Miniboss face-down." % (pid + 1), [pid])
	return true

## Revelation de fin de BUILD (BuildPhase_b) : chaque miniboss pose paie 1 Coin, sinon il est defausse.
static func reveal_all(G: Dictionary) -> void:
	for pid in CardDB.order_by_xp(G.get("players", {})):
		var p := _player(G, int(pid))
		if bool(p.get("eliminated", false)):
			continue
		for stack in (p.get("dungeon", []) as Array):
			var room = BossEngine.active_room(stack)
			var m := mb_of(room)
			if m.is_empty() or not bool(m.get("faceDown", false)):
				continue
			if pay_coin(G, int(pid), 1):
				m["faceDown"] = false
				m["since"] = int(G.get("turn", 0))
				_log(G, "%s is revealed (level %d)." % [mb_name(m), level(m)])
				RmbAbilities.on_opponent_miniboss(G, int(pid))
			else:
				(room as Dictionary).erase("mb")
				drop_card(G.get("decks", {}), m)
				_log(G, "%s is discarded: player %d cannot pay the Coin to reveal it." % [mb_name(m), int(pid) + 1])

# --- promotion -----------------------------------------------------------------------------------------------------------------------

## Promotions possibles (pendant le BUILD du joueur, une par tour) : [{slot, alt}] ; alt = indice de main d'une salle Monster defaussee a la
## place du Coin (Calabeza, une fois par tour), -1 = payer un Coin. Un miniboss ne peut etre revele et promu le meme tour.
static func promote_options(G: Dictionary, p: Dictionary, pid: int) -> Array:
	var out: Array = []
	if used(G, pid, "promote") or str(G.get("phase", "")) != "build":
		return out
	var calabeza := RmbAbilities.has_boss(p, "RMB002") and not used(G, pid, "calabeza")
	var monsters: Array = []
	for i in (p.get("hand", []) as Array).size():
		var c: Dictionary = (p["hand"] as Array)[i]
		if bool(c.get("isRoom", false)) and not bool(c.get("isMiniboss", false)) and str(c.get("type", "")) == "monster":
			monsters.append(i)
	var d: Array = p.get("dungeon", [])
	for i in d.size():
		var m := revealed(BossEngine.active_room(d[i]))
		if m.is_empty() or level(m) >= 3 or int(m.get("since", 0)) >= int(G.get("turn", 0)):
			continue
		if coins(p) >= 1:
			out.append({"slot": i, "alt": -1})
		if calabeza:
			for mi in monsters:
				out.append({"slot": i, "alt": int(mi)})
	return out

static func apply_promote(G: Dictionary, pid: int, slot: int, alt: int) -> bool:
	var p := _player(G, pid)
	var ok := false
	for o in promote_options(G, p, pid):
		ok = ok or (int((o as Dictionary)["slot"]) == slot and int((o as Dictionary)["alt"]) == alt)
	if not ok:
		return false
	if alt >= 0:
		var c: Dictionary = (p["hand"] as Array)[alt]
		TnlAbilities.discard_from_hand(G, pid, c)
		mark_used(G, pid, "calabeza")
		_log(G, "Calabeza: discards %s instead of paying a Coin." % _label(c))
	elif not pay_coin(G, pid, 1):
		return false
	mark_used(G, pid, "promote")
	var m := revealed(BossEngine.active_room((p["dungeon"] as Array)[slot]))
	m["level"] = level(m) + 1
	_log(G, "%s is promoted to level %d." % [mb_name(m), level(m)])
	RmbAbilities.on_opponent_miniboss(G, pid)
	return true

# --- pouvoirs de niveau 2 (une fois par tour) et 3 (puis retour au niveau 1) -----------------------------------------------------

static func _hero_in_room(G: Dictionary, pid: int, idx: int) -> bool:
	return RoomAbilities.hero_is_in_room(G, pid, idx) and int(TnlAbilities.adv(G).get("hp", 0)) > 0

static func _opponents_with_cards(G: Dictionary, pid: int) -> Array:
	var out: Array = []
	for o in TnlAbilities._opponents(G, pid):
		for c in (_player(G, int(o)).get("hand", []) as Array):
			if bool((c as Dictionary).get("isSpell", false)) or bool((c as Dictionary).get("isRoom", false)):
				out.append(int(o))
				break
	return out

## Verifie, sans rien modifier, qu'un pouvoir de niveau `lvl` du miniboss de la salle `slot` est utilisable ; renvoie "" si oui, sinon la raison.
static func check_activate(G: Dictionary, p: Dictionary, pid: int, slot: int, lvl: int) -> String:
	var phase := str(G.get("phase", ""))
	if phase != "build" and phase != "adventure":
		return "Build or Adventure phase only"
	var d: Array = p.get("dungeon", [])
	if slot < 0 or slot >= d.size():
		return "no such room"
	var room = BossEngine.active_room(d[slot])
	var m := revealed(room)
	if m.is_empty() or BossEngine.is_room_deactivated(G, pid, slot):
		return "no revealed Miniboss"
	var id := mb_id(m)
	if lvl == 2:
		if level(m) < 2 or int(m.get("usedTurn", -1)) == int(G.get("turn", 0)):
			return "level 2 power not available"
		match id:
			"RMB055": # Spike : defausse une carte, 2 degats au heros de cette salle
				if (p.get("hand", []) as Array).is_empty() or not _hero_in_room(G, pid, slot):
					return "no card to discard or no Hero in this Room"
			"RMB056": # Kid Croak : echange deux salles d'un donjon (phase de construction)
				if phase != "build" or _swap_dungeons(G).is_empty():
					return "Build phase only / no two Rooms to swap"
			"RMB057": # Draculad : renvoie en ville un heros de VOTRE donjon
				if TnlAbilities.hero_in_dungeon(G, pid).is_empty():
					return "no Hero in your dungeon"
			_:
				return "no activated level 2 power"
		return ""
	if level(m) < 3:
		return "level 3 power not available"
	match id:
		"RMB055":
			if all_mbs(G).is_empty():
				return "no Miniboss"
		"RMB056":
			var any_monster := false
			for q in TnlAbilities._alive(G):
				for st in (_player(G, int(q)).get("dungeon", []) as Array):
					var t = BossEngine.active_room(st)
					any_monster = any_monster or (t != null and str((t as Dictionary).get("type", "")) == "monster")
			if not any_monster:
				return "no Monster Room"
		"RMB057":
			if _opponents_with_cards(G, pid).is_empty():
				return "no opponent card to look at"
		"RMB058":
			if _heroes_any_dungeon(G).is_empty():
				return "no Hero in a dungeon"
		"RMB060":
			if not _hero_in_room(G, pid, slot):
				return "no Hero in this Room"
		"RMB061":
			if TnlAbilities.room_options(G, "any").is_empty():
				return "no Room to deactivate"
		"RMB064":
			if (G.get("town", []) as Array).is_empty():
				return "no Hero in town"
		"RMB059", "RMB062", "RMB063":
			pass
		_:
			return "no level 3 power"
	return ""

static func _heroes_any_dungeon(G: Dictionary) -> Array:
	return TnlAbilities.hero_options(G).filter(func(o): return (o as Dictionary).has("ownerPid"))

## Donjons ou deux piles visibles peuvent etre echangees : [{targetPlayerId, label}].
static func _swap_dungeons(G: Dictionary) -> Array:
	var out: Array = []
	for q in TnlAbilities._alive(G):
		var d: Array = _player(G, int(q)).get("dungeon", [])
		var n := 0
		for i in d.size():
			n += 1 if SpellTargeting._targetable_top(G, int(q), i, d[i]) != null else 0
		if n >= 2:
			out.append({"targetPlayerId": int(q), "label": "Dungeon of player %d" % (int(q) + 1), "ai": -5.0})
	return out

static func activate_moves(G: Dictionary, p: Dictionary, pid: int) -> Array:
	var out: Array = []
	var d: Array = p.get("dungeon", [])
	for i in d.size():
		var m := revealed(BossEngine.active_room(d[i]))
		if m.is_empty():
			continue
		for lvl in [2, 3]:
			if check_activate(G, p, pid, i, lvl) == "":
				out.append({"type": "activateMiniboss", "args": [i, lvl]})
	return out

## Utilise un pouvoir de miniboss. Renvoie null ou un message d'erreur. Tous les couts / cibles sont verifies AVANT toute modification.
static func activate(G: Dictionary, pid: int, slot: int, lvl: int) -> Variant:
	var p := _player(G, pid)
	var why := check_activate(G, p, pid, slot, lvl)
	if why != "":
		return why
	var room: Dictionary = BossEngine.active_room((p["dungeon"] as Array)[slot])
	var m := revealed(room)
	var id := mb_id(m)
	var name := mb_name(m)
	if lvl == 2:
		m["usedTurn"] = int(G.get("turn", 0))
		match id:
			"RMB055":
				TnlAbilities.emit(G, TnlAbilities.ask(G, pid, "rmb_cost", TnlAbilities.hand_options(p, "any"), {"then": "spike", "label": name, "slot": slot},
					"%s: choose a card to discard (2 damage to the Hero in this Room)" % name, name))
			"RMB056":
				TnlAbilities.emit(G, TnlAbilities.ask(G, pid, "rmb_swap_d", _swap_dungeons(G), {"label": name}, "%s: choose a dungeon to swap two Rooms in" % name, name))
			"RMB057":
				_hero_to_town(G, pid, name)
		return null
	# niveau 3 : le miniboss retombe au niveau 1 tout de suite, puis l'effet se resout
	m["level"] = 1
	_log(G, "%s uses its level 3 power and drops back to level 1." % name)
	match id:
		"RMB055":
			var opts: Array = []
			for e in all_mbs(G):
				var ed: Dictionary = e
				opts.append({"pid": int(ed["pid"]), "idx": int(ed["idx"]), "label": "%s (P%d)" % [mb_name(ed["mb"]), int(ed["pid"]) + 1], "card": (ed["mb"] as Dictionary).get("card", {}),
					"ai": (-1.0 if int(ed["pid"]) == pid else 4.0) + float(level(ed["mb"]))})
			TnlAbilities.emit(G, TnlAbilities.ask(G, pid, "rmb_mb_return", opts, {"label": name}, "%s: choose a Miniboss to return to its owner's hand" % name, name))
		"RMB056":
			var sides: Array = []
			for q in TnlAbilities._alive(G):
				var has_monster := false
				for st in (_player(G, int(q)).get("dungeon", []) as Array):
					var t = BossEngine.active_room(st)
					has_monster = has_monster or (t != null and str((t as Dictionary).get("type", "")) == "monster")
				if not has_monster:
					continue
				for delta in [1, -1]:
					var mine: bool = int(q) == pid
					sides.append({"targetPlayerId": int(q), "delta": delta, "label": "Monster Rooms of player %d %s1" % [int(q) + 1, "+" if delta > 0 else "-"],
						"ai": float(delta) * (1.0 if mine else -1.0) * 2.0})
			TnlAbilities.emit(G, TnlAbilities.ask(G, pid, "rmb_croak", sides, {"label": name}, "%s: choose a dungeon and +1 / -1 for its Monster Rooms" % name, name))
		"RMB057":
			var vs: Array = []
			for o in _opponents_with_cards(G, pid):
				vs.append({"targetPlayerId": int(o), "label": "Hand of player %d" % (int(o) + 1), "ai": float((_player(G, int(o)).get("hand", []) as Array).size())})
			TnlAbilities.emit(G, TnlAbilities.ask(G, pid, "rmb_look", vs, {"label": name}, "%s: choose an opponent's hand to look at" % name, name))
		"RMB058":
			var hs := _heroes_any_dungeon(G)
			for h in hs:
				(h as Dictionary)["ai"] = 5.0 if int((h as Dictionary).get("ownerPid", -1)) != pid else -5.0
			TnlAbilities.emit(G, TnlAbilities.ask(G, pid, "rmb_hero", hs, {"then": "plus", "amount": 5, "label": name}, "%s: choose a Hero (+5 Health until end of turn)" % name, name))
		"RMB059", "RMB062":
			var ds: Array = []
			for q in TnlAbilities._alive(G):
				ds.append({"targetPlayerId": int(q), "label": "Dungeon of player %d" % (int(q) + 1), "ai": (-5.0 if int(q) == pid else 5.0)})
			var then := "ignore" if id == "RMB059" else "skipfirst"
			TnlAbilities.emit(G, TnlAbilities.ask(G, pid, "rmb_dungeon", ds, {"then": then, "label": name}, "%s: choose a dungeon" % name, name))
		"RMB060":
			var a := TnlAbilities.adv(G)
			a["hp"] = 0
			_log(G, "%s: %s is killed." % [name, _label(a.get("hero", {}))])
		"RMB061":
			var ts := TnlAbilities.room_options(G, "any")
			for o in ts:
				(o as Dictionary)["ai"] = (1.0 if int((o as Dictionary)["targetPlayerId"]) != pid else -1.0) * float(int(((o as Dictionary)["card"] as Dictionary).get("damage", 0)))
			TnlAbilities.emit(G, TnlAbilities.ask(G, pid, "rmb_room", ts, {"then": "deactivate", "label": name}, "%s: choose a Room to deactivate" % name, name))
		"RMB063":
			var dmg := BossEngine.room_damage_with_modifiers(G, p, slot, null)
			(SpellEffects._effects(G)["roomDamageBonus"] as Array).append({"playerId": pid, "roomIndex": slot, "amount": dmg})
			_log(G, "%s: the damage of %s is doubled until end of turn (+%d)." % [name, _label(room), dmg])
		"RMB064":
			var town: Array = G.get("town", [])
			var hs2: Array = []
			for h in town:
				hs2.append({"card": h, "label": _label(h as Dictionary), "ai": float(int((h as Dictionary).get("hp", 0))) * -1.0})
			TnlAbilities.emit(G, TnlAbilities.ask(G, pid, "rmb_jinx_hero", hs2, {"label": name}, "%s: choose a Hero in town to place at your entrance" % name, name))
	return null

## Draculad niveau 2 : le heros du donjon retourne en ville (PlaceAtTown : il quitte l'aventure sans ame ni blessure).
static func _hero_to_town(G: Dictionary, pid: int, label: String) -> void:
	var hero := TnlAbilities.hero_in_dungeon(G, pid)
	if hero.is_empty():
		return
	var entrance: Array = _player(G, pid).get("entrance", []) as Array
	var at := entrance.find(hero)
	if at >= 0:
		entrance.remove_at(at)
	G["adventure"] = {}
	G["adventurePausePassed"] = {}
	var town: Array = G.get("town", [])
	G["town"] = town
	town.append(hero)
	_log(G, "%s: %s returns to town." % [label, _label(hero)])

# --- Mageseeker niveau 2 : annule un sort adverse ---------------------------------------------------------------------------------

static func stack_moves(G: Dictionary, p: Dictionary, pid: int) -> Array:
	var out: Array = []
	if RoomAbilities._last_opponent_spell_index(G, pid) < 0:
		return out
	var d: Array = p.get("dungeon", [])
	var hand: Array = p.get("hand", [])
	for i in d.size():
		var m := revealed(BossEngine.active_room(d[i]))
		if m.is_empty() or mb_id(m) != "RMB062" or level(m) < 2 or int(m.get("usedTurn", -1)) == int(G.get("turn", 0)) or BossEngine.is_room_deactivated(G, pid, i):
			continue
		for hi in hand.size():
			if bool((hand[hi] as Dictionary).get("isSpell", false)):
				out.append({"type": "rmbCancel", "args": [i, hi]})
	return out

# --- declencheurs : mort d'un heros, construction, sorts, defausses, debut de BUILD ------------------------------------------------

## Un heros vient de mourir dans `room` du donjon de `pid` : Rocky / Cerebella / Brassknuckle niveau 2, Oculus (boss).
static func on_hero_died(G: Dictionary, pid: int, room: Dictionary) -> void:
	var p := _player(G, pid)
	var m := revealed(room)
	if not m.is_empty() and level(m) >= 2:
		var id := mb_id(m)
		var name := mb_name(m)
		match id:
			"RMB059": # Cerebella : pioche un sort
				TnlAbilities.draw_logged(G, pid, "spells", 1, name)
			"RMB058": # Rocky : une AUTRE salle de votre donjon est traitee comme venant d'etre construite
				var idx := _index_of(p, room)
				var opts := TnlAbilities.room_options(G, "any", pid, idx, pid)
				for o in opts:
					(o as Dictionary)["ai"] = 3.0
				TnlAbilities.emit(G, TnlAbilities.ask(G, pid, "rmb_room", opts, {"then": "rebuild", "label": name}, "%s: choose another Room to treat as just built (or skip)" % name, name, true))
			"RMB063": # Brassknuckle : une fois par tour, pioche une salle et peut la construire tout de suite
				if int(m.get("usedTurn", -1)) != int(G.get("turn", 0)):
					m["usedTurn"] = int(G.get("turn", 0))
					var got := TnlAbilities.draw_logged(G, pid, "rooms", 1, name)
					if not got.is_empty():
						var card: Dictionary = got[0]
						var slots := TnlAbilities.build_slots(G, pid, card)
						if not slots.is_empty() and not bool(card.get("isMiniboss", false)):
							TnlAbilities.emit(G, TnlAbilities.ask(G, pid, "rmb_build_slot", slots, {"card": card, "label": name}, "%s: choose where to build %s (or skip)" % [name, _label(card)], name, true))
	if not m.is_empty() and RmbAbilities.has_boss(p, "RMB008"): # Oculus : un sort quand un heros meurt dans une salle avec un miniboss
		TnlAbilities.draw_logged(G, pid, "spells", 1, "Oculus")

static func _index_of(p: Dictionary, room: Dictionary) -> int:
	return TnlAbilities._index_of_room(p, room)

## Debut de la phase BUILD (apres la pioche du tour) : Jinx (une salle de plus, puis defausse d'une salle), The Dreadmill. Renvoie des choix.
static func on_build_start(G: Dictionary) -> Array:
	var out: Array = []
	for pid in CardDB.order_by_xp(G.get("players", {})):
		var p := _player(G, int(pid))
		if bool(p.get("eliminated", false)):
			continue
		var d: Array = p.get("dungeon", [])
		for i in range(d.size() - 1, -1, -1):
			var top = BossEngine.active_room(d[i])
			if top == null or bool((top as Dictionary).get("faceDown", false)):
				continue
			var m := revealed(top)
			if not m.is_empty() and mb_id(m) == "RMB064": # Jinx niveau 1
				TnlAbilities.draw_logged(G, int(pid), "rooms", 1, "Jinx")
				var c = TnlAbilities.ask(G, int(pid), "rmb_cost", TnlAbilities.hand_options(p, "room"), {"then": "none", "label": "Jinx"}, "Jinx: choose a Room to discard", "Jinx")
				if c != null:
					out.append(c)
			if str((top as Dictionary).get("id", "")) == "RMB048" and not TnlAbilities.no_text(top as Dictionary): # The Dreadmill : un Coin sur la salle, sinon elle est detruite
				if pay_coin(G, int(pid), 1):
					(top as Dictionary)["coins"] = int((top as Dictionary).get("coins", 0)) + 1
					_log(G, "The Dreadmill: a Coin is placed on it (%d)." % int((top as Dictionary)["coins"]))
				else:
					TnlAbilities.destroy_room_at(G, int(pid), i, "The Dreadmill")
	return out

## Un sort vient d'etre LANCE (resolu, non annule) par `caster` : Baron Hex (+1 Coin), Alchemist's Lab (une fois par tour, +2 Coins).
static func on_spell_cast(G: Dictionary, caster: int) -> void:
	var p := _player(G, caster)
	if RmbAbilities.has_boss(p, "RMB007"):
		gain_coin(G, caster, 1, "Baron Hex")
	for stack in (p.get("dungeon", []) as Array):
		var r = BossEngine.active_room(stack)
		if r != null and str((r as Dictionary).get("id", "")) == "RMB032" and not bool((r as Dictionary).get("faceDown", false)) \
				and not TnlAbilities.no_text(r as Dictionary) and not bool((r as Dictionary).get("usedThisTurn", false)):
			(r as Dictionary)["usedThisTurn"] = true
			gain_coin(G, caster, 2, "Alchemist's Lab")
			return

## Short Circuit : le joueur doit payer 1 Coin par sort jusqu'a la fin du tour, sinon le sort est annule. Renvoie faux si le sort est annule.
static func pay_short_circuit(G: Dictionary, caster: int) -> bool:
	if not list(G, "tax").has(caster):
		return true
	if pay_coin(G, caster, 1):
		_log(G, "Short Circuit: player %d pays a Coin for the Spell." % (caster + 1))
		return true
	_log(G, "Short Circuit: player %d cannot pay a Coin, the Spell is cancelled." % (caster + 1))
	return false

## Une carte vient de quitter la main de `owner` vers la defausse (`card` est au sommet de sa pile) : Imp Hoard d'un AUTRE joueur la prend
## (une fois par tour, « you may » : toujours pris).
static func on_hand_discard(G: Dictionary, owner: int, card: Dictionary) -> void:
	if not active(G):
		return
	var decks: Dictionary = G.get("decks", {})
	var pile: Array = decks.get("spellDiscard" if bool(card.get("isSpell", false)) else "roomDiscard", [])
	if pile.is_empty() or not is_same(pile[pile.size() - 1], card):
		return
	for q in CardDB.order_by_xp(G.get("players", {})):
		if int(q) == owner or bool(_player(G, int(q)).get("eliminated", false)):
			continue
		for stack in (_player(G, int(q)).get("dungeon", []) as Array):
			var r = BossEngine.active_room(stack)
			if r == null or str((r as Dictionary).get("id", "")) != "RMB017" or bool((r as Dictionary).get("faceDown", false)) \
					or TnlAbilities.no_text(r as Dictionary) or bool((r as Dictionary).get("usedThisTurn", false)):
				continue
			(r as Dictionary)["usedThisTurn"] = true
			pile.pop_back()
			var hand: Array = _player(G, int(q)).get("hand", []) as Array
			hand.append(card)
			_player(G, int(q))["hand"] = hand
			_log(G, "Imp Hoard: player %d puts %s in hand." % [int(q) + 1, _label(card)])
			return

# --- coups RMB (legal_moves / apply_move) --------------------------------------------------------------------------------------------

## Coups supplementaires d'un joueur (pile vide) : pose / promotion / pouvoirs de miniboss, capacites de boss et de main, pieces.
## `my_turn` : c'est a lui de construire (BUILD) ; hors BUILD / ADVENTURE rien.
static func extra_moves(G: Dictionary, p: Dictionary, pid: int, my_turn: bool) -> Array:
	var out: Array = []
	var phase := str(G.get("phase", ""))
	if phase != "build" and phase != "adventure":
		return out
	var hand: Array = p.get("hand", [])
	if phase == "build" and my_turn:
		if can_build_now(G, p, pid):
			var slots := host_slots(G, pid)
			for hi in hand.size():
				if bool((hand[hi] as Dictionary).get("isMiniboss", false)):
					for s in slots:
						out.append({"type": "buildMiniboss", "args": [hi, int((s as Dictionary)["roomIndex"])]})
		for o in promote_options(G, p, pid):
			out.append({"type": "promoteMiniboss", "args": [int((o as Dictionary)["slot"]), int((o as Dictionary)["alt"])]})
		if not used(G, pid, "coinDiscard"):
			for hi in hand.size():
				var c: Dictionary = hand[hi]
				if bool(c.get("isRoom", false)) and not bool(c.get("isMiniboss", false)):
					out.append({"type": "discardForCoin", "args": [hi]})
	out.append_array(activate_moves(G, p, pid))
	out.append_array(RmbAbilities.extra_moves(G, p, pid))
	return out

static func is_rmb_move(mtype: String) -> bool:
	return ["buildMiniboss", "promoteMiniboss", "activateMiniboss", "discardForCoin", "rmbBoss", "rmbHand", "rmbPay", "rmbCancel"].has(mtype)

## Applique un coup RMB deja valide par legal_moves. Renvoie null ou un message d'erreur.
static func apply_move(G: Dictionary, pid: int, move: Dictionary) -> Variant:
	var args: Array = move.get("args", [])
	var p := _player(G, pid)
	match str(move.get("type", "")):
		"promoteMiniboss":
			if not apply_promote(G, pid, int(args[0]), int(args[1])):
				return "cannot promote"
		"activateMiniboss":
			return activate(G, pid, int(args[0]), int(args[1]))
		"discardForCoin":
			var hi := int(args[0])
			var hand: Array = p.get("hand", [])
			if hi < 0 or hi >= hand.size() or used(G, pid, "coinDiscard"):
				return "cannot discard for a Coin"
			TnlAbilities.discard_from_hand(G, pid, hand[hi])
			mark_used(G, pid, "coinDiscard")
			gain_coin(G, pid, 1, "Discard for a Coin")
		"rmbCancel": # Mageseeker niveau 2 : defausse un sort pour annuler un sort adverse
			var slot := int(args[0])
			var hand2: Array = p.get("hand", [])
			var m := revealed(BossEngine.active_room((p["dungeon"] as Array)[slot])) if slot >= 0 and slot < (p.get("dungeon", []) as Array).size() else {}
			if m.is_empty() or int(args[1]) < 0 or int(args[1]) >= hand2.size():
				return "cannot cancel"
			TnlAbilities.discard_from_hand(G, pid, hand2[int(args[1])])
			m["usedTurn"] = int(G.get("turn", 0))
			RoomAbilities.cancel_last_opponent_spell(G, pid, "Mageseeker")
		_:
			return RmbAbilities.apply_move(G, pid, move)
	return null

# --- IA (heuristiques maison : l'APK n'a pas ces cartes) ---------------------------------------------------------------------------------

static func score_move(G: Dictionary, p: Dictionary, pid: int, mtype: String, args: Array) -> float:
	var hand: Array = p.get("hand", [])
	match mtype:
		"buildMiniboss":
			# Un miniboss ne se revele qu'en payant 1 Coin (sinon il est defausse) : on le pose si l'on a de quoi, sur la salle la plus forte.
			if coins(p) - facedown_count(p) < 1: # il faut garder un Coin par miniboss a reveler, sinon il est defausse
				return -50.0
			var room = BossEngine.active_room((p.get("dungeon", []) as Array)[int(args[1])]) if int(args[1]) < (p.get("dungeon", []) as Array).size() else null
			return 130.0 + (float(int((room as Dictionary).get("damage", 0))) * 10.0 if room != null else 0.0)
		"promoteMiniboss":
			if int(args[1]) < 0 and coins(p) - facedown_count(p) < 1:
				return -20.0 # ce Coin sert a reveler un miniboss pose face cachee
			return 160.0 if int(args[1]) < 0 else 140.0
		"discardForCoin":
			var spare := 0
			for c in hand:
				spare += 1 if bool((c as Dictionary).get("isRoom", false)) and not bool((c as Dictionary).get("isMiniboss", false)) else 0
			return 2.0 if coins(p) < 2 and spare >= 4 else -1.5
		"activateMiniboss":
			var a := TnlAbilities.adv(G)
			var mine := not a.is_empty() and int(a.get("playerId", -1)) == pid
			var id := mb_id(revealed(BossEngine.active_room((p["dungeon"] as Array)[int(args[0])])))
			if int(args[1]) == 2:
				return 30.0 if id == "RMB055" and mine and int(a.get("hp", 9)) <= 2 else -10.0
			match id:
				"RMB060": return 90.0 # Paddywhack : tue le heros de la salle
				"RMB063": return 40.0 if mine else -10.0
				"RMB064", "RMB057": return 10.0
				"RMB062": return 5.0
			return -10.0
		"rmbCancel":
			return 100.0
	return RmbAbilities.score_move(G, p, pid, mtype, args)

# --- interface (badge minimal sur la salle porteuse) ----------------------------------------------------------------------------------

## Texte du badge d'une salle qui porte un miniboss ; `own` = false cache le nom d'un miniboss encore face cachee (information privee).
static func badge_text(room, own: bool) -> String:
	var m := mb_of(room)
	if m.is_empty():
		return ""
	if bool(m.get("faceDown", false)):
		return "MINIBOSS (face-down%s)" % [": %s" % mb_name(m) if own else ""]
	return "%s  L%d" % [mb_name(m), level(m)]

## Infobulle : les trois niveaux, le niveau atteint en tete.
static func badge_tooltip(room, own: bool) -> String:
	var m := mb_of(room)
	if m.is_empty() or (bool(m.get("faceDown", false)) and not own):
		return ""
	var lines: Array = ["%s (level %d)" % [mb_name(m), level(m)]]
	for lv in ((m.get("card", {}) as Dictionary).get("levels", []) as Array):
		var l: Dictionary = lv
		lines.append("L%d%s: %s" % [int(l.get("level", 0)), "*" if int(l.get("level", 0)) <= level(m) and not bool(m.get("faceDown", false)) else "", str(l.get("description", ""))])
	return "\n".join(lines)

## Etiquette posee sur la carte de la salle (DungeonSlot, donjon adverse). Null si la salle ne porte aucun miniboss.
static func make_badge(room, own: bool) -> Label:
	var text := badge_text(room, own)
	if text == "":
		return null
	var l := Label.new()
	l.name = "MbBadge"
	l.text = text
	l.set_anchors_preset(Control.PRESET_TOP_WIDE)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 12)
	l.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	l.add_theme_constant_override("outline_size", 4)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.tooltip_text = badge_tooltip(room, own)
	return l
