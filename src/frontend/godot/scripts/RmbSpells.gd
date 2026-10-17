class_name RmbSpells
extends RefCounted
## Les 15 sorts de Rise of the Minibosses (RMB065-RMB079). Ciblage (type `TARGETS`) + effet (cast) + choix de suite (resolve_pick, etapes « rmb_sp_* »).
## La phase de jeu vient de `category` (cards.json) : 1 = Build, 3 = Adventure, 4 = les deux. Texte des cartes d'abord (le JS en implemente peu).

const TARGETS := {
	"RMB065": "windfall", "RMB066": "internship", "RMB067": "room-any", "RMB068": "sabotage", "RMB069": "rage",
	"RMB070": "ambush", "RMB071": "player", "RMB072": "smash", "RMB073": "paytowin", "RMB074": "zoning",
	"RMB075": "respawn", "RMB076": "room-any", "RMB077": "shortcircuit", "RMB078": "traitor", "RMB079": "armor",
}

static func _player(G: Dictionary, pid: int) -> Dictionary:
	return TnlAbilities._player(G, pid)

static func _log(G: Dictionary, t: String, pub: String = "", owners: Array = []) -> void:
	TnlAbilities._log(G, t, pub, owners)

static func _label(c: Dictionary) -> String:
	return TnlAbilities._label(c)

# --- ciblage -------------------------------------------------------------------------------------------------------------------

## Combinaisons de cartes a defausser pour Ambush : deux salles Monster de la main, OU un miniboss.
static func ambush_costs(p: Dictionary) -> Array:
	var out: Array = []
	var monsters: Array = []
	for c in (p.get("hand", []) as Array):
		var cd: Dictionary = c
		if bool(cd.get("isRoom", false)) and not bool(cd.get("isMiniboss", false)) and str(cd.get("type", "")) == "monster":
			monsters.append(cd)
	for a in monsters.size():
		for b in range(a + 1, monsters.size()):
			out.append({"cards": [monsters[a], monsters[b]], "label": "Discard %s + %s" % [_label(monsters[a]), _label(monsters[b])],
				"ai": -(TnlAbilities._ai_value(monsters[a]) + TnlAbilities._ai_value(monsters[b]))})
	for m in Minibosses.miniboss_cards_in_hand(p):
		out.append({"cards": [m], "label": "Discard %s" % _label(m as Dictionary), "ai": -1.0})
	return out

## Heros d'un donjon dont la salle courante porte un miniboss revele (Smash! : 4 degats).
static func hero_in_mb_room(G: Dictionary) -> bool:
	var a := TnlAbilities.adv(G)
	if a.is_empty() or not (a.get("hero") is Dictionary):
		return false
	var d: Array = _player(G, int(a.get("playerId", -1))).get("dungeon", [])
	var i := int(a.get("roomIndex", -1))
	return i >= 0 and i < d.size() and not Minibosses.revealed(BossEngine.active_room(d[i])).is_empty()

static func targets_for(G: Dictionary, me: Dictionary, pid: int, spell_id: String) -> Array:
	var out: Array = []
	var coins := Minibosses.coins(me)
	var mine := TnlAbilities.hero_in_dungeon(G, pid)
	match str(TARGETS.get(spell_id, "")):
		"windfall":
			if coins == 0:
				out.append({})
		"internship", "zoning":
			out.append({})
		"room-any":
			out = SpellTargeting.enumerate_targets("any-room", G, me, pid)
		"sabotage": # sans texte ; OU desactivee si vous avez plus de minibosses que le proprietaire de la salle
			var mine_n := Minibosses.count_revealed(me)
			for t in SpellTargeting.enumerate_targets("any-room", G, me, pid):
				var td: Dictionary = t
				out.append({"mode": "text", "targetPlayerId": td["targetPlayerId"], "roomIndex": td["roomIndex"]})
				if mine_n > Minibosses.count_revealed(_player(G, int(td["targetPlayerId"]))):
					out.append({"mode": "deactivate", "targetPlayerId": td["targetPlayerId"], "roomIndex": td["roomIndex"]})
		"rage":
			for e in Minibosses.all_mbs(G):
				out.append({"targetPlayerId": int((e as Dictionary)["pid"]), "roomIndex": int((e as Dictionary)["idx"])})
		"ambush":
			if not mine.is_empty() and not ambush_costs(me).is_empty():
				out.append({"heroId": mine.get("id")})
		"player":
			out = SpellTargeting.enumerate_targets("any-player", G, me, pid)
		"smash":
			if not mine.is_empty():
				out.append({"mode": "own", "heroId": mine.get("id")})
			var a := TnlAbilities.adv(G)
			if hero_in_mb_room(G):
				out.append({"mode": "mb", "heroId": (a["hero"] as Dictionary).get("id"), "targetPlayerId": int(a.get("playerId", -1))})
		"paytowin": # la carte permet n'importe quelle salle, mais un bonus ne sert que sur la sienne (politique : moins de boutons)
			for t in SpellTargeting.enumerate_targets("any-room", G, me, pid):
				if int((t as Dictionary)["targetPlayerId"]) != pid:
					continue
				for n in range(0, mini(3, coins) + 1):
					out.append({"targetPlayerId": (t as Dictionary)["targetPlayerId"], "roomIndex": (t as Dictionary)["roomIndex"], "pay": n})
		"respawn":
			if not SpellTargeting.enumerate_targets("own-room", G, me, pid).is_empty():
				out.append({})
		"shortcircuit": # un adversaire dont un sort attend sur la pile
			var seen: Array = []
			for e in SpellTargeting.stack_spell_entries(G, pid):
				var q := int((e as Dictionary).get("playerId", -1))
				if not seen.has(q) and not bool((e as Dictionary).get("canceled", false)):
					seen.append(q)
					out.append({"targetPlayerId": q})
		"traitor": # un miniboss REVELE d'un adversaire, paye (niveau) Coins, et une salle de votre donjon pour l'accueillir
			if not Minibosses.host_slots(G, pid).is_empty() and not BossEngine.no_entry(pid, G):
				for e in Minibosses.all_mbs(G):
					var ed: Dictionary = e
					if int(ed["pid"]) != pid and Minibosses.level(ed["mb"]) <= coins:
						out.append({"targetPlayerId": int(ed["pid"]), "roomIndex": int(ed["idx"])})
		"armor":
			for h in TnlAbilities.hero_options(G):
				for n in range(0, mini(2, coins) + 1):
					out.append({"heroId": ((h as Dictionary)["card"] as Dictionary).get("id"), "pay": n})
	return out

static func describe_target(G: Dictionary, t: Dictionary) -> String:
	var s := TnlSpells.describe_target(G, t)
	var extra: Array = []
	if t.has("pay") and int(t["pay"]) > 0:
		extra.append("pay %d Coin(s)" % int(t["pay"]))
	if t.has("heroId") and not t.has("mode"):
		var h := RmbAbilities.find_hero(G, str(t["heroId"]))
		if not h.is_empty():
			extra.append(_label(h))
	return ", ".join([s] + extra) if not extra.is_empty() and s != "" else (s if s != "" else ", ".join(extra))

# --- effets -------------------------------------------------------------------------------------------------------------------------

static func _fizzle(G: Dictionary, name: String) -> bool:
	_log(G, "%s: no valid target any more." % name)
	return false

static func cast(G: Dictionary, caster: int, card: Dictionary, t: Dictionary) -> bool:
	var me := _player(G, caster)
	var id := str(card.get("id", ""))
	var name := str(card.get("name", id))
	var tid := int(t.get("targetPlayerId", caster))
	var rv = SpellEffects.find_room(G, tid, int(t.get("roomIndex", -1))) if t.has("roomIndex") else null
	var mine := TnlAbilities.hero_in_dungeon(G, caster)
	var a := TnlAbilities.adv(G)
	match id:
		"RMB065": # Windfall : sans Coin, trois Coins
			if Minibosses.coins(me) != 0:
				return _fizzle(G, name)
			Minibosses.gain_coin(G, caster, 3, name)
		"RMB066": # Internship : les trois premieres salles de la pioche vont en defausse ; un miniboss parmi elles peut etre construit tout de suite
			var minis: Array = []
			var decks: Dictionary = G.get("decks", {})
			var deck: Array = decks.get("rooms", [])
			var disc: Array = decks.get("roomDiscard", [])
			decks["rooms"] = deck
			decks["roomDiscard"] = disc
			for _i in 3:
				if deck.is_empty():
					CardDB.refill_from_discard(deck, disc, TnlAbilities._rng_get())
				if deck.is_empty():
					break
				var c: Dictionary = deck.pop_back()
				BossEngine.discard_room_to_pile(decks, c)
				_log(G, "%s: %s goes to the discard pile." % [name, _label(c)])
				if bool(c.get("isMiniboss", false)):
					minis.append(c)
			var opts: Array = []
			for m in minis:
				for s in Minibosses.host_slots(G, caster):
					opts.append({"card": m, "roomIndex": int((s as Dictionary)["roomIndex"]), "label": "Build %s %s" % [_label(m as Dictionary), str((s as Dictionary)["label"])], "ai": 3.0 + float((s as Dictionary)["ai"])})
			if not opts.is_empty():
				TnlAbilities.emit(G, TnlAbilities.ask(G, caster, "rmb_sp_intern", opts, {}, "Internship: build a Miniboss over a Room (or skip)", name, true))
		"RMB067": # Spirit Dragon : un tresor de chaque type a la place de ses icones
			if rv == null:
				return _fizzle(G, name)
			TnlAbilities._tag(rv as Dictionary)["allTreasures"] = true
			_log(G, "%s: %s has one of each treasure type until end of turn." % [name, _label(rv as Dictionary)])
		"RMB068": # Sabotage! : pas de texte, OU desactivee (si plus de minibosses que le proprietaire)
			if rv == null:
				return _fizzle(G, name)
			if str(t.get("mode", "text")) == "deactivate":
				if Minibosses.count_revealed(me) <= Minibosses.count_revealed(_player(G, tid)):
					return _fizzle(G, name)
				(SpellEffects._effects(G)["deactivatedRooms"] as Array).append({"playerId": tid, "roomIndex": int(t.get("roomIndex", -1))})
				_log(G, "%s: %s is deactivated until end of turn." % [name, _label(rv as Dictionary)])
			else:
				TnlAbilities._tag(rv as Dictionary)["noText"] = true
				_log(G, "%s: %s has no ability text until end of turn." % [name, _label(rv as Dictionary)])
		"RMB069": # Rage! : +1 par niveau a la salle du miniboss ; si vous n'en avez qu'un, ses degats sont ensuite doubles
			var host = rv
			var m := Minibosses.revealed(host)
			if host == null or m.is_empty():
				return _fizzle(G, name)
			SpellEffects._buff_room_instance(host, Minibosses.level(m))
			_log(G, "%s: %s gets +%d until end of turn." % [name, _label(host as Dictionary), Minibosses.level(m)])
			if Minibosses.count_revealed(me) == 1 and tid == caster:
				var dmg := BossEngine.room_damage_with_modifiers(G, me, int(t.get("roomIndex", -1)), null)
				(SpellEffects._effects(G)["roomDamageBonus"] as Array).append({"playerId": caster, "roomIndex": int(t.get("roomIndex", -1)), "amount": dmg})
				_log(G, "%s: the damage of %s is doubled (+%d)." % [name, _label(host as Dictionary), dmg])
		"RMB070": # Ambush : deux salles Monster OU un miniboss defausses, tue un heros de votre donjon
			if mine.is_empty() or str(mine.get("id", "")) != str(t.get("heroId", "")):
				return _fizzle(G, name)
			var costs := ambush_costs(me)
			if costs.is_empty():
				return _fizzle(G, name)
			TnlAbilities.emit(G, TnlAbilities.ask(G, caster, "rmb_sp_ambush", costs, {"heroId": str(mine.get("id", ""))}, "Ambush: choose the cards to discard", name))
		"RMB071": # Rebirth : le joueur defausse sa main et repioche autant de salles et de sorts
			var tp := _player(G, tid)
			var held: Array = (tp.get("hand", []) as Array).duplicate()
			(tp["hand"] as Array).clear()
			var rooms := 0
			var spells := 0
			for c in held:
				var cd: Dictionary = c
				if bool(cd.get("isSpell", false)):
					spells += 1
					var sd: Array = decks_pile(G, "spellDiscard")
					sd.append(cd)
				else:
					rooms += 1
					BossEngine.discard_room_to_pile(G.get("decks", {}), cd)
				Minibosses.on_hand_discard(G, tid, cd)
			TnlAbilities.draw(G, tid, "rooms", rooms)
			TnlAbilities.draw(G, tid, "spells", spells)
			_log(G, "%s: player %d discards %d Room(s) and %d Spell(s) and draws as many." % [name, tid + 1, rooms, spells])
		"RMB072": # Smash! : 2 degats a un heros de votre donjon, OU 4 degats a un heros dans une salle avec miniboss
			var ok_own: bool = str(t.get("mode", "own")) == "own" and not mine.is_empty() and str(mine.get("id", "")) == str(t.get("heroId", ""))
			var ok_mb: bool = str(t.get("mode", "")) == "mb" and hero_in_mb_room(G) and str((a["hero"] as Dictionary).get("id", "")) == str(t.get("heroId", ""))
			if not ok_own and not ok_mb:
				return _fizzle(G, name)
			var dmg2 := 4 if ok_mb and str(t.get("mode", "")) == "mb" else 2
			a["hp"] = int(a.get("hp", 0)) - dmg2
			_log(G, "%s: %d damage to %s." % [name, dmg2, _label(a.get("hero", {}))])
		"RMB073": # Pay to Win : +1, et +1 par Coin paye au lancement
			if rv == null:
				return _fizzle(G, name)
			var pay := mini(int(t.get("pay", 0)), Minibosses.coins(me))
			Minibosses.pay_coin(G, caster, pay)
			SpellEffects._buff_room_instance(rv, 1 + pay)
			_log(G, "%s: %s gets +%d until end of turn." % [name, _label(rv as Dictionary), 1 + pay])
		"RMB074": # Zoning Board : salle avancee par-dessus n'importe quelle salle, sans condition de tresor
			(SpellEffects._effects(G)["ignoreTreasureMatch"] as Array).append(caster)
			_log(G, "%s: Advanced Rooms can be built over any Room this turn." % name)
		"RMB075": # Respawn : toutes vos salles sont traitees comme venant d'etre construites
			var rooms_now: Array = []
			for stack in (me.get("dungeon", []) as Array):
				var top = BossEngine.active_room(stack)
				if top != null and not bool((top as Dictionary).get("faceDown", false)):
					rooms_now.append(top)
			var choices: Array = []
			for r in rooms_now:
				choices.append(RoomAbilities.on_build_room(G, caster, r as Dictionary))
			TnlAbilities.emit(G, TnlAbilities.flush(G, choices))
			_log(G, "%s: all the Rooms of player %d are treated as just built." % [name, caster + 1])
		"RMB076": # Heist : la salle perd ses icones de tresor jusqu'a la fin du tour (texte ambigu sur la carte, voir goldens)
			if rv == null:
				return _fizzle(G, name)
			TnlAbilities._tag(rv as Dictionary)["noTreasure"] = true
			_log(G, "%s: %s loses its treasure icons until end of turn." % [name, _label(rv as Dictionary)])
		"RMB077": # Short Circuit : l'adversaire paie 1 Coin par sort jusqu'a la fin du tour, sinon le sort est annule (voir Match._resolve_pending_stack)
			Minibosses.list(G, "tax").append(tid)
			_log(G, "%s: player %d must pay a Coin for each Spell until end of turn." % [name, tid + 1])
		"RMB078": # Traitor : prend un miniboss adverse (paye son niveau en Coins a son proprietaire), le construit a ce niveau ; plus de salle ce tour
			var host2 = rv
			var m2 := Minibosses.revealed(host2)
			if host2 == null or m2.is_empty() or tid == caster or Minibosses.coins(me) < Minibosses.level(m2) or Minibosses.host_slots(G, caster).is_empty():
				return _fizzle(G, name)
			var ctx := {"from": tid, "fromIdx": int(t.get("roomIndex", -1))}
			var slots := Minibosses.host_slots(G, caster)
			if slots.size() == 1:
				_traitor_finish(G, caster, ctx, int((slots[0] as Dictionary)["roomIndex"]))
			else:
				TnlAbilities.emit(G, TnlAbilities.ask(G, caster, "rmb_sp_traitor", slots, ctx, "Traitor: choose the Room that receives the Miniboss", name))
		"RMB079": # Armor Up! : +1 a un heros, et +2 par Coin paye au lancement
			var hero := RmbAbilities.find_hero(G, str(t.get("heroId", "")))
			if hero.is_empty():
				return _fizzle(G, name)
			var pay2 := mini(int(t.get("pay", 0)), Minibosses.coins(me))
			Minibosses.pay_coin(G, caster, pay2)
			TnlAbilities.add_hero_hp(G, hero, 1 + 2 * pay2)
			_log(G, "%s: %s gains +%d Health until end of turn." % [name, _label(hero), 1 + 2 * pay2])
		_:
			return false
	return true

static func decks_pile(G: Dictionary, pile: String) -> Array:
	var decks: Dictionary = G.get("decks", {})
	var arr: Array = decks.get(pile, [])
	decks[pile] = arr
	return arr

## Traitor, derniere etape : paiement, miniboss deplace (revele, a son niveau), plus de construction de salle ce tour.
static func _traitor_finish(G: Dictionary, caster: int, ctx: Dictionary, host_idx: int) -> void:
	var from := int(ctx.get("from", -1))
	var src = SpellEffects.find_room(G, from, int(ctx.get("fromIdx", -1)))
	var m := Minibosses.revealed(src)
	var dst = SpellEffects.find_room(G, caster, host_idx)
	if src == null or m.is_empty() or dst == null:
		return
	var cost := Minibosses.level(m)
	if not Minibosses.pay_coin(G, caster, cost):
		return
	var op := _player(G, from)
	op["coins"] = Minibosses.coins(op) + cost
	(src as Dictionary).erase("mb")
	m["since"] = int(G.get("turn", 0))
	(dst as Dictionary)["mb"] = m
	(SpellEffects._effects(G)["noRoomBuild"] as Array).append(caster)
	_log(G, "Traitor: player %d pays %d Coin(s) to player %d and builds %s over %s." % [caster + 1, cost, from + 1, Minibosses.mb_name(m), _label(dst as Dictionary)])

static func resolve_pick(G: Dictionary, pid: int, pc: Dictionary, idx: int) -> Variant:
	var opts: Array = pc.get("options", [])
	var ctx: Dictionary = pc.get("ctx", {}) as Dictionary
	var o: Dictionary = (opts[idx] as Dictionary) if idx >= 0 and idx < opts.size() else {}
	if idx < 0:
		return null
	match str(pc.get("step", "")):
		"rmb_sp_intern": # Internship : le miniboss quitte la defausse, pose face cachee
			var card: Dictionary = o.get("card", {})
			var disc: Array = decks_pile(G, "roomDiscard")
			var at := disc.rfind(card)
			var host = SpellEffects.find_room(G, pid, int(o.get("roomIndex", -1)))
			if at >= 0 and host != null and not Minibosses.stack_has_mb((_player(G, pid).get("dungeon", []) as Array)[int(o.get("roomIndex", -1))]):
				disc.remove_at(at)
				Minibosses.attach(G, pid, host as Dictionary, card, true)
				_log(G, "Internship: %s is built face-down over %s." % [_label(card), _label(host as Dictionary)], "Internship: a Miniboss is built face-down.", [pid])
		"rmb_sp_ambush":
			var a := TnlAbilities.adv(G)
			for c in (o.get("cards", []) as Array):
				TnlAbilities.discard_from_hand(G, pid, c as Dictionary)
			var hero := TnlAbilities.hero_in_dungeon(G, pid)
			if not hero.is_empty() and str(hero.get("id", "")) == str(ctx.get("heroId", "")):
				a["hp"] = 0
				_log(G, "Ambush: %s is killed." % _label(hero))
		"rmb_sp_traitor":
			_traitor_finish(G, pid, ctx, int(o.get("roomIndex", -1)))
	return null

# --- IA (heuristiques maison) ---------------------------------------------------------------------------------------------------------------

static func score_spell(G: Dictionary, p: Dictionary, pid: int, sid: String, t: Dictionary) -> float:
	var tid := int(t.get("targetPlayerId", pid))
	var coins := Minibosses.coins(p)
	match sid:
		"RMB065": return 30.0
		"RMB066": return 12.0
		"RMB067": # Spirit Dragon : un tresor de chaque type sur ma salle, avant de construire, si cela fait venir un heros que je tue
			var dr = SpellEffects.find_room(G, tid, int(t.get("roomIndex", -1))) if tid == pid else null
			return AiWiki.BUILD_FIRST if dr != null and AiWiki.tag_gain(G, pid, dr as Dictionary, "allTreasures") >= 1.0 else (4.0 if tid == pid else -5.0)
		"RMB068": return 6.0 if tid != pid else -10.0
		"RMB069": return 40.0 if tid == pid and not (p.get("entrance", []) as Array).is_empty() else -5.0
		"RMB070": return 60.0
		"RMB071": return 5.0 if tid == pid and (p.get("hand", []) as Array).size() >= 5 else -20.0
		"RMB072": return 80.0 if str(t.get("mode", "")) == "mb" and tid == pid else (40.0 if str(t.get("mode", "")) == "own" else -20.0)
		"RMB073": return (15.0 if tid == pid and int(t.get("pay", 0)) == 0 else -5.0) if not (p.get("entrance", []) as Array).is_empty() else -5.0
		"RMB074": return 18.0
		"RMB075": return 8.0
		"RMB076": # Heist : la salle adverse perd ses icones, avant de construire, si un heros qui me blesserait va chez moi plutot que chez elle
			var hr = SpellEffects.find_room(G, tid, int(t.get("roomIndex", -1))) if tid != pid else null
			return AiWiki.BUILD_FIRST if hr != null and AiWiki.no_treasure_gain(G, pid, hr as Dictionary) >= 1.0 else (6.0 if tid != pid else -10.0)
		"RMB077": # Short Circuit (reponse a un sort adverse sur la pile) : il doit payer 1 Coin, sinon son sort est annule
			var their := Minibosses.coins(_player(G, tid))
			return 110.0 if their == 0 else (40.0 if their == 1 else 6.0)
		"RMB078": # Traitor : prend un miniboss adverse et termine le tour de construction : doit battre la pose d'une salle
			var tr = SpellEffects.find_room(G, tid, int(t.get("roomIndex", -1))) if tid != pid else null
			var tm: Dictionary = Minibosses.revealed(tr) if tr != null else {}
			return 300.0 + 50.0 * float(Minibosses.level(tm)) if not tm.is_empty() and coins >= Minibosses.level(tm) else -5.0
		"RMB079": # Armor Up! : le heros adverse qui mourrait de justesse (1 PV + 2 par Coin paye) ; le moins de Coins possible
			var f := AiWiki.fate(G)
			var n := int(t.get("pay", 0))
			var is_active := bool(f["active"]) and str((f["hero"] as Dictionary).get("id", "")) == str(t.get("heroId", ""))
			return 60.0 - 6.0 * float(n) if is_active and int(f["owner"]) != pid and AiWiki.saves(f, 1 + 2 * n) else -10.0
	return 5.0
