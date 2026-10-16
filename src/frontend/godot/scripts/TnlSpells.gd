class_name TnlSpells
extends RefCounted
## Les 17 sorts de The Next Level (TNL056-TNL072). Ciblage (type `TARGETS`) + effet (cast) + choix de suite (resolve_pick, etapes « sp_* »).
## La phase de jeu vient de `category` (cards.json) : 1 = Build, 3 = Adventure, 4 = les deux (Meddling Kids!, Oh Yeah!, icones marteau + hache).

const TARGETS := {
	"TNL056": "opponent", "TNL057": "castle", "TNL058": "room-any", "TNL059": "its-on", "TNL060": "opponent",
	"TNL061": "own-hero", "TNL062": "meddling", "TNL063": "oh-yeah", "TNL064": "player", "TNL065": "none",
	"TNL066": "pity", "TNL067": "stash", "TNL068": "shortcut", "TNL069": "own-room", "TNL070": "gift",
	"TNL071": "undead", "TNL072": "wild",
}

static func _player(G: Dictionary, pid: int) -> Dictionary:
	return TnlAbilities._player(G, pid)

static func _log(G: Dictionary, t: String, pub: String = "", owners: Array = []) -> void:
	TnlAbilities._log(G, t, pub, owners)

# --- ciblage ----------------------------------------------------------------------------------------------------------------

## Cibles legales (dictionnaires de coup `playSpell [i, cible]`) ; liste vide = injouable maintenant.
static func targets_for(G: Dictionary, me: Dictionary, pid: int, spell_id: String) -> Array:
	var out: Array = []
	var kind := str(TARGETS.get(spell_id, ""))
	var mine := TnlAbilities.hero_in_dungeon(G, pid)
	match kind:
		"none":
			out.append({})
		"opponent":
			for o in TnlAbilities._opponents(G, pid):
				out.append({"targetPlayerId": int(o)})
		"player":
			for o in TnlAbilities._alive(G):
				out.append({"targetPlayerId": int(o)})
		"castle": # Another Castle : un heros DANS votre donjon (pas a l'entree), envoye a l'entree d'un adversaire
			if not mine.is_empty():
				for o in TnlAbilities._opponents(G, pid):
					out.append({"targetPlayerId": int(o)})
		"room-any":
			out = SpellTargeting.enumerate_targets("any-room", G, me, pid)
		"own-room":
			out = SpellTargeting.enumerate_targets("own-room", G, me, pid)
		"its-on": # 3 PV ou moins, OU 3 blessures ou plus : n'importe quel heros de votre donjon
			if not mine.is_empty() and (int(TnlAbilities.adv(G).get("hp", 99)) <= 3 or CardDB.total_wounds(me) >= 3):
				out.append({"heroId": mine.get("id")})
		"own-hero":
			if not mine.is_empty():
				out.append({"heroId": mine.get("id")})
		"meddling":
			out = SpellTargeting.enumerate_targets("any-room", G, me, pid)
			for q in TnlAbilities._alive(G):
				if TnlAbilities.count_of(G, "entered", int(q)) >= 3:
					out.append({"targetPlayerId": int(q), "mode": "nowin"})
		"oh-yeah":
			var d: Array = me.get("dungeon", [])
			for a in d.size():
				for b in range(a + 1, d.size()):
					if SpellTargeting._targetable_top(G, pid, a, d[a]) != null and SpellTargeting._targetable_top(G, pid, b, d[b]) != null:
						out.append({"mode": "swap", "a": a, "b": b})
			if TnlAbilities.count_of(G, "destroyed", pid) >= 2:
				for t in SpellTargeting.enumerate_targets("any-room", G, me, pid):
					out.append({"mode": "destroy", "targetPlayerId": (t as Dictionary)["targetPlayerId"], "roomIndex": (t as Dictionary)["roomIndex"]})
		"pity": # un heros dans le donjon d'un adversaire
			var a := TnlAbilities.adv(G)
			if not a.is_empty() and int(a.get("playerId", -1)) != pid and a.get("hero") is Dictionary:
				out.append({"heroId": (a["hero"] as Dictionary).get("id"), "targetPlayerId": int(a["playerId"])})
		"shortcut": # un heros dans n'importe quel donjon
			var a2 := TnlAbilities.adv(G)
			if not a2.is_empty() and a2.get("hero") is Dictionary:
				out.append({"heroId": (a2["hero"] as Dictionary).get("id"), "targetPlayerId": int(a2["playerId"])})
		"stash":
			for t in SpellTargeting.enumerate_targets("own-room", G, me, pid):
				for tr in [1, 2, 3, 4]:
					out.append({"roomIndex": (t as Dictionary)["roomIndex"], "treasure": tr})
		"gift":
			if gift_ready(G, me, pid):
				out.append({})
		"undead":
			if not mine.is_empty():
				var seen: Array = []
				var souls: Array = me.get("souls", [])
				for i in souls.size():
					var h = (souls[i] as Dictionary).get("hero")
					if h is Dictionary and not bool((souls[i] as Dictionary).get("tpk", false)) and not seen.has(h):
						seen.append(h)
						out.append({"soulIndex": i})
		"wild":
			if not TnlAbilities.hand_options(me, "monster").filter(func(o): return not TnlAbilities.build_slots(G, pid, (o as Dictionary)["card"]).is_empty()).is_empty():
				out.append({})
	return out

## Surprise Gift : pendant SA construction, sans avoir deja construit (« instead of your own »), avec une salle posable chez un adversaire.
static func gift_ready(G: Dictionary, me: Dictionary, pid: int) -> bool:
	if str(G.get("phase", "")) != "build" or G.has("buildWindow") or int(G.get("activePlayer", -1)) != pid or BossEngine.is_build_blocked(G):
		return false
	if int(me.get("buildsThisTurn", 0)) >= 1 + BossEngine.extra_builds_for(G, pid):
		return false
	return not gift_slots(G, pid).is_empty()

## Sommets visibles des donjons adverses ou une salle peut etre posee face cachee.
static func gift_slots(G: Dictionary, pid: int) -> Array:
	var out: Array = []
	for o in TnlAbilities._opponents(G, pid):
		var d: Array = _player(G, int(o)).get("dungeon", [])
		for i in d.size():
			var rv = SpellTargeting._targetable_top(G, int(o), i, d[i])
			if rv != null and not TnlAbilities.hand_options(_player(G, pid), "room").is_empty():
				out.append({"targetPlayerId": int(o), "roomIndex": i, "card": rv, "label": "%s (P%d)" % [TnlAbilities._label(rv as Dictionary), int(o) + 1], "ai": float(int((rv as Dictionary).get("damage", 0)))})
	return out

## Libelle d'une cible de sort pour l'interface.
static func describe_target(G: Dictionary, t: Dictionary) -> String:
	var parts: Array = []
	if t.has("mode"):
		parts.append(str(t["mode"]))
	if t.has("a") and t.has("b"):
		parts.append("rooms %d<->%d" % [int(t["a"]) + 1, int(t["b"]) + 1])
	if t.has("targetPlayerId"):
		var tid := int(t["targetPlayerId"])
		var rv = SpellEffects.find_room(G, tid, int(t["roomIndex"])) if t.has("roomIndex") else null
		parts.append("%s (P%d)" % [TnlAbilities._label(rv as Dictionary), tid + 1] if rv != null else "P%d" % (tid + 1))
	elif t.has("roomIndex"):
		var rv2 = SpellEffects.find_room(G, int(G.get("activePlayer", 0)), int(t["roomIndex"]))
		parts.append(TnlAbilities._label(rv2 as Dictionary) if rv2 != null else "room %d" % (int(t["roomIndex"]) + 1))
	if t.has("treasure"):
		parts.append(str(CardDB.TREASURE_NAMES[int(t["treasure"])]))
	if t.has("soulIndex"):
		var souls: Array = _player(G, int(G.get("activePlayer", 0))).get("souls", [])
		var si := int(t["soulIndex"])
		parts.append(str((souls[si] as Dictionary).get("name", "Hero")) if si >= 0 and si < souls.size() else "soul")
	if t.has("heroId"):
		parts.append("hero")
	return ", ".join(parts)

# --- effets -----------------------------------------------------------------------------------------------------------------------

static func cast(G: Dictionary, caster: int, card: Dictionary, t: Dictionary) -> bool:
	var me := _player(G, caster)
	var id := str(card.get("id", ""))
	var name := str(card.get("name", id))
	var tid := int(t.get("targetPlayerId", caster))
	var mine := TnlAbilities.hero_in_dungeon(G, caster)
	var a := TnlAbilities.adv(G)
	match id:
		"TNL056": # All Your Base : regarde la main d'un adversaire, peut prendre une de ses salles
			var opts := TnlAbilities.hand_options(_player(G, tid), "room")
			if opts.is_empty():
				_log(G, "%s: player %d has no Room card." % [name, tid + 1])
				return true
			TnlAbilities.emit(G, TnlAbilities.ask(G, caster, "sp_aybase", opts, {"victim": tid}, "All Your Base: take a Room from player %d (or skip)" % (tid + 1), name, true))
		"TNL057": # Another Castle : le heros de VOTRE donjon part a l'entree d'un adversaire
			if mine.is_empty() or not TnlAbilities._opponents(G, caster).has(tid):
				return _fizzle(G, name)
			var hero: Dictionary = mine
			var entrance: Array = me.get("entrance", []) as Array
			var at := entrance.find(hero)
			if at >= 0:
				entrance.remove_at(at)
			G["adventure"] = {}
			G["adventurePausePassed"] = {}
			var other := _player(G, tid)
			var oe: Array = other.get("entrance", []) as Array
			oe.append(hero)
			other["entrance"] = oe
			_log(G, "%s: %s is sent to player %d's entrance." % [name, TnlAbilities._label(hero), tid + 1])
		"TNL058": # Fairy Fountain : degats a zero + chaque heros qui y entre gagne +1 (fin a la destruction / quand couverte)
			var rv = SpellEffects.find_room(G, tid, int(t.get("roomIndex", -1)))
			if rv == null:
				return _fizzle(G, name)
			TnlAbilities._tag(rv as Dictionary)["fairy"] = true
			_log(G, "%s: %s does zero damage until end of turn." % [name, TnlAbilities._label(rv as Dictionary)])
		"TNL059": # It's On! : tue le heros de votre donjon (3 PV ou moins, ou 3 blessures et plus)
			if mine.is_empty() or str(mine.get("id", "")) != str(t.get("heroId", "")):
				return _fizzle(G, name)
			if not (int(a.get("hp", 99)) <= 3 or CardDB.total_wounds(me) >= 3):
				return _fizzle(G, name)
			a["hp"] = 0
			_log(G, "%s: %s is killed." % [name, TnlAbilities._label(mine)])
		"TNL060": # Hiring Spree : pioche 3 salles, en donne une a un autre joueur
			TnlAbilities.draw_logged(G, caster, "rooms", 3, name)
			TnlAbilities.emit(G, TnlAbilities.ask(G, caster, "sp_give", TnlAbilities.hand_options(me, "room"), {"to": tid}, "Hiring Spree: choose a Room to give to player %d" % (tid + 1), name))
		"TNL061": # Lightning Bolt! : 3 degats au heros de votre donjon ; + defausser un autre sort : 3 degats aux heros a l'entree
			if mine.is_empty():
				return _fizzle(G, name)
			a["hp"] = int(a.get("hp", 0)) - 3
			_log(G, "%s: 3 damage to %s." % [name, TnlAbilities._label(mine)])
			var waiting: Array = []
			for h in (me.get("entrance", []) as Array):
				if not is_same(h, mine):
					waiting.append(h)
			if not waiting.is_empty():
				TnlAbilities.emit(G, TnlAbilities.ask(G, caster, "sp_lightning", TnlAbilities.hand_options(me, "spell"), {}, "Lightning Bolt!: discard another Spell for 3 damage to each Hero at the entrance?", name, true))
		"TNL062": # Meddling Kids! : une salle sans texte, OU un joueur ne peut pas gagner ce tour (>= 3 heros entres chez lui)
			if str(t.get("mode", "")) == "nowin":
				if TnlAbilities.count_of(G, "entered", tid) < 3:
					return _fizzle(G, name)
				TnlAbilities._list(G, "noWin").append(tid)
				_log(G, "%s: player %d cannot win this turn." % [name, tid + 1])
			else:
				var rv2 = SpellEffects.find_room(G, tid, int(t.get("roomIndex", -1)))
				if rv2 == null:
					return _fizzle(G, name)
				TnlAbilities._tag(rv2 as Dictionary)["noText"] = true
				_log(G, "%s: %s has no ability text until end of turn." % [name, TnlAbilities._label(rv2 as Dictionary)])
		"TNL063": # Oh, Yeah! : echange deux salles de votre donjon, OU (2 salles detruites ce tour) detruit une salle de n'importe quel donjon
			if str(t.get("mode", "")) == "destroy":
				if TnlAbilities.count_of(G, "destroyed", caster) < 2 or SpellEffects.find_room(G, tid, int(t.get("roomIndex", -1))) == null:
					return _fizzle(G, name)
				TnlAbilities.destroy_room_at(G, tid, int(t["roomIndex"]), name)
			else:
				if not TnlAbilities.swap_stacks(G, caster, int(t.get("a", -1)), int(t.get("b", -1))):
					return _fizzle(G, name)
				_log(G, "%s: two Rooms of your dungeon are swapped." % name)
		"TNL064": # Party Up : chaque heros qui entre dans ce donjon gagne +1 jusqu'a la fin du tour
			TnlAbilities._list(G, "party").append(tid)
			_log(G, "%s: each Hero entering player %d's dungeon gains +1 Health." % [name, tid + 1])
		"TNL065": # Pause : le heros de votre donjon retourne a l'entree, pleine sante ; aucun heros n'entre avant le prochain tour
			if not mine.is_empty():
				G["adventure"] = {}
				G["adventurePausePassed"] = {}
				_log(G, "%s: %s returns to the entrance at full Health." % [name, TnlAbilities._label(mine)])
			(SpellEffects._effects(G)["skipAdventure"] as Array).append(caster)
			_log(G, "%s: no Hero may enter player %d's dungeon until next turn." % [name, caster + 1])
		"TNL066": # Pity : retire du jeu un heros du donjon d'un adversaire
			var victim_hero := TnlAbilities.hero_in_dungeon(G, tid)
			if tid == caster or victim_hero.is_empty() or str(victim_hero.get("id", "")) != str(t.get("heroId", "")):
				return _fizzle(G, name)
			var ve: Array = _player(G, tid).get("entrance", []) as Array
			var vat := ve.find(victim_hero)
			if vat >= 0:
				ve.remove_at(vat)
			G["adventure"] = {}
			G["adventurePausePassed"] = {}
			TnlAbilities._remove_from_game(G, victim_hero)
			_log(G, "%s: %s is removed from the game." % [name, TnlAbilities._label(victim_hero)])
		"TNL067": # Secret Stash : un tresor de plus jusqu'a la fin du tour
			var rv3 = SpellEffects.find_room(G, caster, int(t.get("roomIndex", -1)))
			if rv3 == null:
				return _fizzle(G, name)
			var extra: Array = (rv3 as Dictionary).get("extraTreasures", []) as Array
			extra.append(int(t.get("treasure", 1)))
			(rv3 as Dictionary)["extraTreasures"] = extra
			_log(G, "%s: %s gains a %s treasure until end of turn." % [name, TnlAbilities._label(rv3 as Dictionary), str(CardDB.TREASURE_NAMES[int(t.get("treasure", 1))])])
		"TNL068": # Shortcut! : le heros saute la prochaine salle (les deux prochaines si le donjon en a cinq)
			var sh := TnlAbilities.hero_in_dungeon(G, tid)
			if sh.is_empty() or str(sh.get("id", "")) != str(t.get("heroId", "")):
				return _fizzle(G, name)
			var skip := 2 if BossEngine.count_visible_rooms(_player(G, tid).get("dungeon", [])) >= 5 else 1
			a["skip"] = int(a.get("skip", 0)) + skip
			_log(G, "%s: %s skips the next %d Room(s)." % [name, TnlAbilities._label(sh), skip])
		"TNL069": # Super Effective! : +2, ou +4 si un seul heros a ete leurre chez vous ce tour
			var rv4 = SpellEffects.find_room(G, caster, int(t.get("roomIndex", -1)))
			if rv4 == null:
				return _fizzle(G, name)
			var amount := 4 if TnlAbilities.count_of(G, "lured", caster) == 1 else 2
			SpellEffects._buff_room_instance(rv4, amount)
			_log(G, "%s: %s deals +%d until end of turn." % [name, TnlAbilities._label(rv4 as Dictionary), amount])
		"TNL070": # Surprise Gift : une salle posee face cachee chez un adversaire a la place de la votre
			if int(me.get("buildsThisTurn", 0)) >= 1 + BossEngine.extra_builds_for(G, caster) or gift_slots(G, caster).is_empty():
				return _fizzle(G, name)
			TnlAbilities.emit(G, TnlAbilities.ask(G, caster, "sp_gift_slot", gift_slots(G, caster), {}, "Surprise Gift: choose an opponent's Room to build over", name))
		"TNL071": # Undead Minion : retire un heros face cachee du jeu, degats = sa sante a un heros de votre donjon
			var souls: Array = me.get("souls", []) as Array
			var si := int(t.get("soulIndex", -1))
			var dead = (souls[si] as Dictionary).get("hero") if si >= 0 and si < souls.size() else null
			if mine.is_empty() or not (dead is Dictionary):
				return _fizzle(G, name)
			TnlAbilities.remove_soul_hero(me, dead as Dictionary)
			TnlAbilities._remove_from_game(G, dead as Dictionary)
			var dmg := BossEngine.hero_hp(dead as Dictionary)
			a["hp"] = int(a.get("hp", 0)) - dmg
			_log(G, "%s: %s removed from the game, %d damage to %s." % [name, TnlAbilities._label(dead as Dictionary), dmg, TnlAbilities._label(mine)])
		"TNL072": # Wild Monster : construit tout de suite une salle Monster par-dessus une salle de votre donjon
			var c = TnlAbilities.build_choice(G, caster, "monster", name)
			if c == null:
				return _fizzle(G, name)
			TnlAbilities.emit(G, c)
		_:
			return false
	return true

static func _fizzle(G: Dictionary, name: String) -> bool:
	_log(G, "%s: no valid target any more." % name)
	return false

# --- choix des sorts ---------------------------------------------------------------------------------------------------------------

static func resolve_pick(G: Dictionary, pid: int, pc: Dictionary, idx: int) -> Variant:
	var opts: Array = pc.get("options", [])
	var ctx: Dictionary = pc.get("ctx", {}) as Dictionary
	var o: Dictionary = (opts[idx] as Dictionary) if idx >= 0 and idx < opts.size() else {}
	match str(pc.get("step", "")):
		"sp_aybase":
			var victim := int(ctx.get("victim", -1))
			var c: Dictionary = o.get("card", {})
			if idx >= 0 and TnlAbilities.take_from_hand(G, victim, c):
				var hand: Array = _player(G, pid).get("hand", []) as Array
				hand.append(c)
				_log(G, "All Your Base: takes %s from player %d." % [TnlAbilities._label(c), victim + 1], "All Your Base: takes a card from player %d." % (victim + 1), [pid, victim])
		"sp_give":
			var to := int(ctx.get("to", -1))
			var gc: Dictionary = o.get("card", {})
			if TnlAbilities.take_from_hand(G, pid, gc):
				var th: Array = _player(G, to).get("hand", []) as Array
				th.append(gc)
				_log(G, "Hiring Spree: gives %s to player %d." % [TnlAbilities._label(gc), to + 1])
		"sp_lightning":
			if idx >= 0 and TnlAbilities.discard_from_hand(G, pid, o.get("card", {})):
				var mine := TnlAbilities.hero_in_dungeon(G, pid)
				for h in (_player(G, pid).get("entrance", []) as Array):
					if not is_same(h, mine):
						TnlAbilities.add_hero_hp(G, h as Dictionary, -3)
				_log(G, "Lightning Bolt!: 3 damage to each Hero at the entrance.")
		"sp_gift_slot": # etape 1 : la salle adverse ; etape 2 : la carte a poser (avancee : tresor commun)
			if idx < 0:
				return null
			var host: Dictionary = o.get("card", {})
			var cards: Array = []
			for h in TnlAbilities.hand_options(_player(G, pid), "room"):
				var rc: Dictionary = (h as Dictionary)["card"]
				if _gift_fits(rc, host):
					cards.append(h)
			return TnlAbilities.ask(G, pid, "sp_gift_card", cards, {"targetPlayerId": int(o.get("targetPlayerId", -1)), "roomIndex": int(o.get("roomIndex", -1))},
				"Surprise Gift: choose the Room to place face-down", "Surprise Gift")
		"sp_gift_card":
			var tp := int(ctx.get("targetPlayerId", -1))
			var gcard: Dictionary = o.get("card", {})
			var d: Array = _player(G, tp).get("dungeon", [])
			var ri := int(ctx.get("roomIndex", -1))
			if ri >= 0 and ri < d.size() and TnlAbilities.take_from_hand(G, pid, gcard):
				gcard["faceDown"] = true
				gcard["builtThisTurn"] = true
				(d[ri] as Array).append(gcard)
				var me := _player(G, pid)
				me["buildsThisTurn"] = int(me.get("buildsThisTurn", 0)) + 1
				G["tnlGiftBuilt"] = pid # Match fait suivre la construction (le joueur a utilise son tour de pose)
				_log(G, "Surprise Gift: a Room is placed face-down in player %d's dungeon." % (tp + 1))
	return null

static func _gift_fits(card: Dictionary, host: Dictionary) -> bool:
	if not bool(card.get("advanced", false)):
		return true
	if str(host.get("id", "")) == "BMA018":
		return false
	for t in (card.get("treasures", []) as Array):
		if BossEngine.room_treasures(host).has(int(t)):
			return true
	return false

# --- IA (heuristiques maison) --------------------------------------------------------------------------------------------------------

static func score_spell(G: Dictionary, p: Dictionary, pid: int, sid: String, t: Dictionary) -> float:
	var tid := int(t.get("targetPlayerId", pid))
	match sid:
		"TNL056": return 40.0
		"TNL057": return 8.0
		"TNL058": return -10.0 if tid == pid else 12.0
		"TNL059", "TNL061": return 90.0
		"TNL060": return 30.0
		"TNL062": return 90.0 if str(t.get("mode", "")) == "nowin" else (-10.0 if tid == pid else 6.0)
		"TNL063":
			if str(t.get("mode", "")) != "swap":
				return 40.0 if tid != pid else -20.0
			var gain := AiWiki.swap_gain(G, pid, int(t.get("a", -1)), int(t.get("b", -1))) # l'ordre des salles change les bonus de voisinage
			var f := AiWiki.fate(G)
			return AiWiki.BUILD_FIRST + float(gain) if gain > 0 and (not bool(f["active"]) or int(f["owner"]) != pid) else -5.0
		"TNL064": return 15.0 if tid != pid else -10.0
		"TNL065": return -20.0 if TnlAbilities.hero_in_dungeon(G, pid).is_empty() else 8.0
		"TNL066": return 85.0
		"TNL067": return 4.0
		"TNL068": return 40.0 if tid != pid else -10.0
		"TNL069": return 50.0 if not (p.get("entrance", []) as Array).is_empty() else 0.0
		"TNL070": return AiWiki.BUILD_FIRST if _gift_pays(G, p, pid) else -5.0
		"TNL071": return 70.0
		"TNL072": return 25.0
	return 5.0

## Surprise Gift vaut la peine quand mon donjon est presque plein (construire chez moi n'apporte plus grand-chose) et qu'une salle adverse
## de 3 degats ou plus peut etre recouverte par une salle de ma main qui en fait au moins 2 de moins (elle ne la remplace pas : elle la couvre).
static func _gift_pays(G: Dictionary, p: Dictionary, pid: int) -> bool:
	if BossEngine.count_visible_rooms(p.get("dungeon", [])) < 4:
		return false
	for slot in gift_slots(G, pid):
		var host: Dictionary = (slot as Dictionary)["card"]
		if int(host.get("damage", 0)) < 3:
			continue
		for h in TnlAbilities.hand_options(p, "room"):
			var rc: Dictionary = (h as Dictionary)["card"]
			if _gift_fits(rc, host) and int(rc.get("damage", 0)) <= int(host.get("damage", 0)) - 2:
				return true
	return false
