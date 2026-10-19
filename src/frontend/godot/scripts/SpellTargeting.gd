class_name SpellTargeting
extends RefCounted
## Ciblage des sorts ; reference : le C# de l'APK.
## Cibles legales pour un sort, partagees par legalMoves et l'UI.

const SPELL_TARGETS := {
	"BMA040": {"type": "any-room-trap", "label": "Choose a Trap Room"},
	"BMA041": {"type": "hero-opponent-dungeon", "label": "Choose a Hero in an opponent's dungeon"},
	"BMA042": {"type": "own-room", "label": "Choose a room to destroy"},
	"BMA043": {"type": "stack-spell", "label": "Choose a Spell that has just been played"},
	"BMA044": {"type": "hero-own-dungeon", "label": "Choose a Hero in your dungeon"},
	"BMA045": {"type": "hero-any-dungeon", "label": "Choose a Hero to send back to town"},
	"BMA046": {"type": "any-room", "label": "Choose a room to deactivate"},
	"BMA047": {"type": "any-room-monster", "label": "Choose a Monster Room"},
	"BMA051": {"type": "hero-town", "label": "Choose a Hero in town"},
	"BMA052": {"type": "own-soul", "label": "Choose a face-down Hero"},
	"BMA053": {"type": "hero-own-active", "label": "Send the active Hero in your dungeon back"},
	"BMA054": {"type": "trepidation-player", "label": "Choose a player with 2+ more Souls"},
	"BMA055": {"type": "opponent-soul", "label": "Choose a dead Hero"},
	"KSA013": {"type": "tpk-player", "label": "T.P.K."},
	"THK025": {"type": "any-item", "label": "Choose an Item to flip"},
	"CRL029": {"type": "crl-finish-him", "label": "Choose a Hero to finish"},
	"CRL030": {"type": "crl-hero-opponent", "label": "Choose a Hero in an opponent's dungeon"},
	"CRL031": {"type": "crl-healing-tank", "label": "Healing Tank"},
	"CRL032": {"type": "any-room", "label": "Choose a Room"},
	"CRL033": {"type": "crl-not-dead-yet", "label": "Not Dead Yet"},
}

static func spell_needs_target(spell_id: String) -> bool:
	return SPELL_TARGETS.has(spell_id) or TnlSpells.TARGETS.has(spell_id) or RmbSpells.TARGETS.has(spell_id)

static func _stack_top(stack) -> Variant:
	return stack[stack.size() - 1] if stack is Array and not (stack as Array).is_empty() else null

## Sommet d'un emplacement CIBLABLE par RoomInDungeon (RoomInDungeon.InternalGetAvailableTargets :
## slot.IsActive && !slot.PendingToBeBuilt) : ni salle face cachee (construite ce tour), ni emplacement deja gele
## (Freeze). Renvoie null sinon.
static func _targetable_top(G: Dictionary, opid: int, idx: int, stack) -> Variant:
	var r = _stack_top(stack)
	if r == null or bool((r as Dictionary).get("faceDown", false)):
		return null
	var eff: Dictionary = G.get("effects", {}) as Dictionary
	for d in (eff.get("deactivatedRooms", []) as Array):
		if int((d as Dictionary).get("playerId", -1)) == opid and int((d as Dictionary).get("roomIndex", -1)) == idx:
			return null
	return r

## Sorts adverses en attente sur la pile = SpellCardJustPlayed.GetAvailableTargets (SpellBattleCards,
## proprietaire different du lanceur ; un sort deja annule reste ciblable, comme dans le C#).
static func stack_spell_entries(G: Dictionary, player_id: int) -> Array:
	var out: Array = []
	for e in (G.get("stack", []) as Array):
		var ed: Dictionary = e
		if str(ed.get("type", "")) == "spell" and int(ed.get("playerId", -1)) != player_id:
			out.append(ed)
	return out

static func _player(G: Dictionary, pid: int) -> Dictionary:
	var players: Dictionary = G.get("players", {})
	if players.has(pid):
		return players[pid]
	return players.get(str(pid), {}) as Dictionary

## Cibles brutes pour les coups du reducer : { roomIndex, heroId, townIndex, targetPlayerId, ... }
static func enumerate_targets(type: String, G: Dictionary, me: Dictionary, player_id: int) -> Array:
	var out: Array = []
	var pid := int(player_id)
	match type:
		"own-room":
			for i in (me.get("dungeon", []) as Array).size():
				if _targetable_top(G, pid, i, (me["dungeon"] as Array)[i]) != null:
					out.append({"roomIndex": i})
		"stack-spell":
			for ed in stack_spell_entries(G, pid):
				out.append({"stackId": str((ed as Dictionary).get("id", "")), "card": (ed as Dictionary).get("card", {})})
		"own-room-trap":
			for i in (me.get("dungeon", []) as Array).size():
				var r = _stack_top((me["dungeon"] as Array)[i])
				if r != null and str((r as Dictionary).get("type", "")) == "trap":
					out.append({"roomIndex": i})
		"own-room-monster":
			for i in (me.get("dungeon", []) as Array).size():
				var r = _stack_top((me["dungeon"] as Array)[i])
				if r != null and str((r as Dictionary).get("type", "")) == "monster":
					out.append({"roomIndex": i})
		"any-room-trap":
			for opid in (G.get("players", {}) as Dictionary):
				var op: Dictionary = G["players"][opid]
				if op.get("eliminated", false):
					continue
				for i in (op.get("dungeon", []) as Array).size():
					var r = _targetable_top(G, int(opid), i, (op["dungeon"] as Array)[i])
					if r != null and str((r as Dictionary).get("type", "")) == "trap":
						out.append({"targetPlayerId": int(opid), "roomIndex": i})
		"any-room-monster":
			for opid in (G.get("players", {}) as Dictionary):
				var op: Dictionary = G["players"][opid]
				if op.get("eliminated", false):
					continue
				for i in (op.get("dungeon", []) as Array).size():
					var r = _targetable_top(G, int(opid), i, (op["dungeon"] as Array)[i])
					# Giant Size = RoomInDungeon[Monster] : le ciblage C# (GetAvailableTargets) ne propose que des Monster. Mais l'IA de l'APK
					# (AbilityCalculator.CheckBMA040And047) reprend la liste de salles TRAP dans sa branche « heros actif » pour les DEUX sorts,
					# et le moteur n'y revalide rien : le harnais d'oracle ouvre ce choix (G.aiTargetsAnyRoomType).
					if r != null and (str((r as Dictionary).get("type", "")) == "monster" or bool(G.get("aiTargetsAnyRoomType", false))):
						out.append({"targetPlayerId": int(opid), "roomIndex": i})
		"any-room":
			for opid in (G.get("players", {}) as Dictionary):
				var op: Dictionary = G["players"][opid]
				if op.get("eliminated", false):
					continue
				for i in (op.get("dungeon", []) as Array).size():
					if _targetable_top(G, int(opid), i, (op["dungeon"] as Array)[i]) != null:
						out.append({"targetPlayerId": int(opid), "roomIndex": i})
		"hero-opponent-dungeon":
			for opid in (G.get("players", {}) as Dictionary):
				var op: Dictionary = G["players"][opid]
				if int(opid) == pid or op.get("eliminated", false):
					continue
				for h in (op.get("entrance", []) as Array):
					out.append({"heroId": (h as Dictionary).get("id")})
		"hero-own-dungeon":
			for h in (me.get("entrance", []) as Array):
				out.append({"heroId": (h as Dictionary).get("id")})
		"hero-own-active":
			var ah = active_entrance_hero(G, me, pid)
			if ah != null:
				out.append({"heroId": (ah as Dictionary).get("id")})
		"hero-any-dungeon":
			for opid in (G.get("players", {}) as Dictionary):
				var op: Dictionary = G["players"][opid]
				if op.get("eliminated", false):
					continue
				for h in (op.get("entrance", []) as Array):
					out.append({"heroId": (h as Dictionary).get("id")})
		"hero-town":
			for i in (G.get("town", []) as Array).size():
				out.append({"townIndex": i})
		"opponent":
			for opid in (G.get("players", {}) as Dictionary):
				var op: Dictionary = G["players"][opid]
				if int(opid) == pid or op.get("eliminated", false):
					continue
				out.append({"targetPlayerId": int(opid)})
		"tpk-player":
			# BossOwner : un humain n'a que lui-meme (cible auto-resolue). L'IA de l'APK (AbilityCalculator.CheckKSA013) designe TOUS les joueurs
			# par PlayerId et le moteur retient le premier : le harnais d'oracle ouvre ce choix (G.aiTargetsAllBosses).
			for opid in (G.get("players", {}) as Dictionary):
				var op: Dictionary = G["players"][opid]
				if op.get("eliminated", false) or (int(opid) != pid and not bool(G.get("aiTargetsAllBosses", false))):
					continue
				out.append({"targetPlayerId": int(opid)})
		"any-player":
			for opid in (G.get("players", {}) as Dictionary):
				var op: Dictionary = G["players"][opid]
				if op.get("eliminated", false):
					continue
				out.append({"targetPlayerId": int(opid)})
		"trepidation-player":
			var mine := _souls_total(me)
			for opid in (G.get("players", {}) as Dictionary):
				var op: Dictionary = G["players"][opid]
				if int(opid) == pid or op.get("eliminated", false):
					continue
				if _souls_total(op) >= mine + 2:
					out.append({"targetPlayerId": int(opid)})
		"own-soul":
			for i in (me.get("souls", []) as Array).size():
				var s: Dictionary = (me["souls"] as Array)[i]
				if not bool(s.get("tpk", false)):
					out.append({"soulIndex": i})
		"opponent-soul":
			for opid in (G.get("players", {}) as Dictionary):
				var op: Dictionary = G["players"][opid]
				if int(opid) == pid or op.get("eliminated", false):
					continue
				# BMA055 = HeroInScorekeep(Opponent, Dead, Any) : SoulsHeroes seulement (HeroStates.Dead) ; les heros blesses (WoundsHeroes) sont « Alive ».
				for i in (op.get("souls", []) as Array).size():
					var s: Dictionary = (op["souls"] as Array)[i]
					if not bool(s.get("tpk", false)):
						out.append({"targetPlayerId": int(opid), "soulIndex": i, "pile": "souls"})
		"any-item": # THK025 Excavation (case wiki) : face-up seulement s'il n'y a pas deja un autre Objet face visible chez le proprietaire
			for opid in (G.get("players", {}) as Dictionary):
				var op: Dictionary = G["players"][opid]
				var items: Array = op.get("items", [])
				var has_up := not ThkAbilities.face_up_item(op).is_empty()
				for i in items.size():
					var down := bool((items[i] as Dictionary).get("faceDown", false))
					if down and has_up:
						continue
					out.append({"targetPlayerId": int(opid), "itemIndex": i, "flipTo": not down})
		"crl-finish-him": # CRL029 : tuer un heros a 2 PV ou moins ; OU (si moins d'ames que tous les autres) prendre un heros ayant survecu ce tour
			for opid in (G.get("players", {}) as Dictionary):
				var op: Dictionary = G["players"][opid]
				if op.get("eliminated", false):
					continue
				var ent: Array = op.get("entrance", []) as Array
				for i in ent.size():
					if RoomAbilities.current_hero_hp(G, int(opid), ent[i]) <= 2:
						out.append({"targetPlayerId": int(opid), "entranceIndex": i})
			if _fewest_souls(G, me, pid):
				for opid in (G.get("players", {}) as Dictionary):
					var op: Dictionary = G["players"][opid]
					if int(opid) == pid:
						continue
					var seen: Array = []
					var wounds: Array = op.get("wounds", []) as Array
					for j in wounds.size():
						var h = (wounds[j] as Dictionary).get("hero")
						if h is Dictionary and int((wounds[j] as Dictionary).get("turn", -1)) == int(G.get("turn", 0)) and not seen.has(h):
							seen.append(h)
							out.append({"targetPlayerId": int(opid), "woundIndex": j})
		"crl-hero-opponent": # CRL030 : un heros du donjon / de l'entree d'un adversaire (X = vos blessures > 0)
			if CardDB.total_wounds(me) > 0:
				for opid in (G.get("players", {}) as Dictionary):
					var op: Dictionary = G["players"][opid]
					if int(opid) == pid or op.get("eliminated", false):
						continue
					for i in (op.get("entrance", []) as Array).size():
						out.append({"targetPlayerId": int(opid), "entranceIndex": i})
		"crl-healing-tank": # CRL031 : aucun heros leurre chez vous a la phase de leurre, et une blessure de heros ordinaire a soigner
			if int(((G.get("luredThisTurn", {}) as Dictionary)).get(pid, 0)) == 0 and not ordinary_wound_heroes(me).is_empty():
				out.append({})
		"crl-not-dead-yet": # CRL033 : X = vos blessures ; utile s'il y a un heros chez vous
			if CardDB.total_wounds(me) > 0 and not (me.get("entrance", []) as Array).is_empty():
				out.append({})
		_:
			pass
	return out

## Heros ORDINAIRES de la zone de blessures (CRL031 : « ordinary Wound »).
static func ordinary_wound_heroes(p: Dictionary) -> Array:
	return BossEngine.wound_heroes(p).filter(func(h): return not bool((h as Dictionary).get("epic", false)))

## « fewer Souls than any player » (CRL029) lu strictement : moins d'ames que CHAQUE autre joueur en vie.
static func _fewest_souls(G: Dictionary, me: Dictionary, pid: int) -> bool:
	var mine := CardDB.total_souls(me, G)
	var others := 0
	for opid in (G.get("players", {}) as Dictionary):
		var op: Dictionary = G["players"][opid]
		if int(opid) == pid or op.get("eliminated", false):
			continue
		others += 1
		if CardDB.total_souls(op, G) <= mine:
			return false
	return others > 0

static func _souls_total(p: Dictionary) -> int:
	var n := 0
	for s in (p.get("souls", []) as Array):
		n += int((s as Dictionary).get("souls", 1))
	return n

## Cibles affichees par l'UI : { key, card, kind, value, label }
static func get_spell_target_options(type: String, G: Dictionary, me: Dictionary, player_id: int) -> Array:
	var out: Array = []
	var pid := int(player_id)
	match type:
		"own-room", "own-room-trap", "own-room-monster":
			var want := "" if type == "own-room" else ("trap" if type == "own-room-trap" else "monster")
			for i in (me.get("dungeon", []) as Array).size():
				var r = _targetable_top(G, pid, i, (me["dungeon"] as Array)[i])
				if r == null:
					continue
				var rd: Dictionary = r
				if want != "" and str(rd.get("type", "")) != want:
					continue
				out.append({"key": "room-%d" % i, "card": rd, "kind": "room",
					"value": {"roomIndex": i}, "label": str(rd.get("name", ""))})
		"any-room":
			for opid in (G.get("players", {}) as Dictionary):
				var op: Dictionary = G["players"][opid]
				if op.get("eliminated", false):
					continue
				for i in (op.get("dungeon", []) as Array).size():
					var r = _targetable_top(G, int(opid), i, (op["dungeon"] as Array)[i])
					if r == null:
						continue
					var rd: Dictionary = r
					var owner := "You" if int(opid) == pid else "P%d" % int(opid)
					out.append({"key": "room-%s-%d" % [str(opid), i], "card": rd, "kind": "room",
						"value": {"targetPlayerId": int(opid), "roomIndex": i},
						"label": "%s (%s)" % [rd.get("name", ""), owner]})
		"stack-spell":
			for ed in stack_spell_entries(G, pid):
				var sc: Dictionary = (ed as Dictionary).get("card", {}) as Dictionary
				out.append({"key": "stack-%s" % str((ed as Dictionary).get("id", "")), "card": sc, "kind": "spell",
					"value": {"stackId": str((ed as Dictionary).get("id", "")), "card": sc},
					"label": "%s (P%d)" % [str(sc.get("name", "")), int((ed as Dictionary).get("playerId", 0))]})
		"hero-town":
			for i in (G.get("town", []) as Array).size():
				var h: Dictionary = G["town"][i]
				out.append({"key": "town-%d" % i, "card": h,
					"kind": "epic-hero" if h.get("epic", false) else "hero",
					"value": {"townIndex": i}, "label": str(h.get("name", ""))})
		"hero-own-dungeon":
			for h in (me.get("entrance", []) as Array):
				var hd: Dictionary = h
				out.append({"key": "hero-%s" % str(hd.get("id", "")), "card": hd,
					"kind": "epic-hero" if hd.get("epic", false) else "hero",
					"value": {"heroId": hd.get("id")}, "label": str(hd.get("name", ""))})
		"hero-own-active":
			var ah = active_entrance_hero(G, me, pid)
			if ah != null:
				var ahd: Dictionary = ah
				out.append({"key": "hero-%s" % str(ahd.get("id", "")), "card": ahd,
					"kind": "epic-hero" if ahd.get("epic", false) else "hero",
					"value": {"heroId": ahd.get("id")}, "label": str(ahd.get("name", ""))})
		"hero-any-dungeon", "hero-opponent-dungeon":
			for opid in (G.get("players", {}) as Dictionary):
				var op: Dictionary = G["players"][opid]
				if op.get("eliminated", false):
					continue
				if type == "hero-opponent-dungeon" and int(opid) == pid:
					continue
				for h in (op.get("entrance", []) as Array):
					var hd: Dictionary = h
					out.append({"key": "hero-%s-%s" % [str(opid), str(hd.get("id", ""))], "card": hd,
						"kind": "epic-hero" if hd.get("epic", false) else "hero",
						"value": {"heroId": hd.get("id")}, "label": str(hd.get("name", ""))})
		"opponent", "any-player", "trepidation-player":
			var mine := _souls_total(me)
			for opid in (G.get("players", {}) as Dictionary):
				var op: Dictionary = G["players"][opid]
				if op.get("eliminated", false):
					continue
				if type == "opponent" and int(opid) == pid:
					continue
				if type == "trepidation-player":
					if int(opid) == pid or _souls_total(op) < mine + 2:
						continue
				var boss: Dictionary = op.get("boss", {}) as Dictionary
				var label := str(boss.get("name", "")) if not boss.is_empty() else "Player %d" % int(opid)
				if type == "any-player" and int(opid) == pid:
					label = "You"
				out.append({"key": "pl-%s" % str(opid), "card": boss, "kind": "boss",
					"value": {"targetPlayerId": int(opid)}, "label": label})
		"own-soul":
			for i in (me.get("souls", []) as Array).size():
				var s: Dictionary = (me["souls"] as Array)[i]
				if bool(s.get("tpk", false)):
					continue
				out.append({"key": "soul-%d" % i, "card": s, "kind": "hero",
					"value": {"soulIndex": i}, "label": str(s.get("name", "Hero"))})
		"opponent-soul":
			for opid in (G.get("players", {}) as Dictionary):
				var op: Dictionary = G["players"][opid]
				if int(opid) == pid or op.get("eliminated", false):
					continue
				for i in (op.get("souls", []) as Array).size():
					var s: Dictionary = (op["souls"] as Array)[i]
					if bool(s.get("tpk", false)):
						continue
					out.append({"key": "osoul-%s-%d" % [str(opid), i], "card": s, "kind": "hero",
						"value": {"targetPlayerId": int(opid), "soulIndex": i, "pile": "souls"},
						"label": "%s (P%d soul)" % [s.get("name", "Hero"), int(opid)]})
		"any-item":
			for opid in (G.get("players", {}) as Dictionary):
				var op: Dictionary = G["players"][opid]
				var has_up := not ThkAbilities.face_up_item(op).is_empty()
				for i in (op.get("items", []) as Array).size():
					var it: Dictionary = (op["items"] as Array)[i]
					var down := bool(it.get("faceDown", false))
					if down and has_up:
						continue
					# un Objet face cachee adverse reste secret : ni nom ni carte dans la liste
					var secret: bool = down and int(opid) != player_id
					out.append({"key": "item-%s-%d" % [str(opid), i], "card": {"faceDown": true, "name": "Face-down Item"} if secret else it, "kind": "item",
						"value": {"targetPlayerId": int(opid), "itemIndex": i, "flipTo": not down}, "label": "Face-down Item (P%d)" % (int(opid) + 1) if secret else str(it.get("name", ""))})
		_:
			pass
	return out

## Heros ACTIF (Hero.IsActiveHero) de la file d'entree de `pid`, ou null (ActiveHeroInDungeon(Any, Owner)). L'APK le designe a la fin d'AdventurePhase_a
## (GameBoard.ChooseNextActiveHero, sauf Boss.ForceSkipAdventure) et le garde jusqu'a la fin de son passage : c'est le heros de G.adventure ou, dans la fenetre
## qui precede (Godot fusionne les fenetres APK a/b), le premier heros libre de l'entree du joueur actif. Seul son proprietaire le voit dans SA file.
static func active_entrance_hero(G: Dictionary, me: Dictionary, pid: int) -> Variant:
	var adv: Dictionary = G.get("adventure", {})
	if not adv.is_empty():
		return adv.get("hero") if int(adv.get("playerId", -1)) == pid else null
	if (G.get("stack", []) as Array).is_empty() and int(G.get("activePlayer", -1)) != pid: # pendant une Spell Battle, activePlayer est le repondant courant
		return null
	if ((G.get("effects", {}) as Dictionary).get("skipAdventure", []) as Array).has(pid):
		return null
	var ent: Array = me.get("entrance", [])
	var first := Minibosses.first_free_hero(G, ent) if Minibosses.active(G) else 0
	return ent[first] if first >= 0 and first < ent.size() else null

## Conditions de l'Ability (data.json) hors phase (voir CardDB.SPELL_PHASE) et hors cibles : BMA050 Motivation = OpponnentDungeonSizeMoreThan(1).
static func conditions_ok(G: Dictionary, pid: int, spell_id: String) -> bool:
	return spell_id != "BMA050" or BossEngine.opponent_dungeon_larger(G, pid, 1)

## Toutes les cibles legales pour un sort donne (hors extensions).
static func spell_targets_for(G: Dictionary, player: Dictionary, player_id: int, spell_id: String) -> Array:
	if not conditions_ok(G, player_id, spell_id):
		return []
	if TnlSpells.TARGETS.has(spell_id): # The Next Level : TNL056-TNL072 (liste vide = injouable maintenant)
		return TnlSpells.targets_for(G, player, player_id, spell_id)
	if RmbSpells.TARGETS.has(spell_id): # Rise of the Minibosses : RMB065-RMB079
		return RmbSpells.targets_for(G, player, player_id, spell_id)
	if not SPELL_TARGETS.has(spell_id):
		return [null]
	var req: Dictionary = SPELL_TARGETS[spell_id]
	return enumerate_targets(str(req.get("type", "")), G, player, player_id)