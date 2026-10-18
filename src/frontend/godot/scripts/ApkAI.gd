class_name ApkAI
extends RefCounted
## Decisions DETERMINISTES de l'IA de l'APK (FixedAI, celle de l'oracle) portees fonction par fonction :
## valeur de salle, choix de la salle, de l'emplacement, abstention, defausse d'ouverture, probabilite de pioche (Haunted Library).
## Sources (apk-original/decompiled/DBMGame/) : DBMGameProject.AI/{FixedAI,StatisticAI,AIHelper}.cs et
## DBMGameProject.AI.Statistics/{StatisticsCalculator,RoomCalculator,DungeonSlotCalculator,DiscardCalculator,DrawCalculator}.cs.
##
## Indices : le C# range le donjon du plus ANCIEN (index 0, au fond) au plus recent (DungeonSize-1) ; Godot fait `push_front`
## (index 0 = la plus recente). `c` = index C#, `g` = index Godot, c = taille - 1 - g ; un « nouvel emplacement » a c = taille.
## Salle « en attente » (DungeonSlot.PendingToBeBuilt) = salle face cachee (posee ce tour, revelee en BuildPhase_b).

# --- tables de RoomCalculator.cs (static ctor, l.55-64), indexees par AIRoomFactorTypes ----------------
const FACTOR_NAMES := ["Kill", "Spell", "Combo", "Positive", "Destroy", "Negative", "Lure", "Advanced"]
const EARLY_DAMAGE := [0.0, 25.0, 100.0, 150.0, 175.0, 200.0, 200.0, 200.0, 200.0, 200.0]
const EARLY_TREASURE := [100.0, 50.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
const EARLY_FACTORS := [35.0, 20.0, 25.0, 0.0, 0.0, 0.0, -100.0, -25.0]
const MID_DAMAGE := [0.0, 25.0, 75.0, 175.0, 200.0, 200.0, 200.0, 200.0, 200.0, 200.0]
const MID_TREASURE := [0.0, 25.0, 100.0, 100.0, 125.0, 200.0, 200.0, 200.0, 200.0, 200.0]
const MID_FACTORS := [-15.0, 25.0, 0.0, 10.0, 25.0, -15.0, 25.0, 50.0]
const LATE_DAMAGE := [0.0, 25.0, 75.0, 175.0, 200.0, 200.0, 200.0, 200.0, 200.0, 200.0]
const LATE_TREASURE := [100.0, 75.0, 75.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
const LATE_FACTORS := [0.0, 25.0, 50.0, 5.0, 175.0, -75.0, 150.0, 50.0]
const SETUP_CONSTRUCTION_ZONE_COMBO := 10000.0 # RoomCalculator.setupConstructionZoneComboValue
const INVALID_DIZZYGAS_SETUP := -1000.0
const INVALID_DIZZYGAS := -100.0
const VALID_DIZZYGAS := 100.0
const INVALID_GOBLIN_ARMORY := -100.0
const VALID_GOBLIN_ARMORY := 100.0
const BAIT_MODIFIER := -100.0 # earlyBaitModifierValue = midBaitModifierValue
const BUILD_OVER_ADVANCED_PENALTY := 300.0
# DungeonSlotCalculator.cs l.9-23
const SLOT_INVALID_MINOTAUR := -1000.0
const SLOT_INVALID_DIZZYGAS_FIRST := -1000.0
const SLOT_INVALID_GOBLIN_FIRST := -200.0
const SLOT_INVALID_DIZZYGAS := -500.0
const SLOT_VALID_DIZZYGAS := 500.0
const SLOT_INVALID_GOBLIN := -500.0
const SLOT_VALID_GOBLIN := 500.0
# DiscardCalculator.cs l.10-17
const CANT_BUILD_FACTOR := {"setup": -100.0, "early": -100.0, "mid": -150.0, "late": -200.0}
const KEEP_SPELL_FACTOR := {"setup": 0.4, "early": 0.5, "mid": 0.9, "late": 1.0}

## ai_info.json (RoomCards[].Factors) : seul BaseDeck en a (PlayerChoice et HiddenHeros ont RoomCards vide). Les assets
## ne sont pas exportes, d'ou la copie ici ; goldens_ai.gd la compare au fichier. Une carte absente (wiki) = facteurs vides.
const ROOM_FACTORS := {
	"BMA009": ["Destroy"], "BMA010": ["Kill"], "BMA011": ["Positive"], "BMA012": ["Kill", "Spell"],
	"BMA013": ["Positive", "Advanced"], "BMA014": ["Kill", "Advanced"], "BMA015": ["Combo"], "BMA016": ["Kill"],
	"BMA017": ["Combo"], "BMA018": ["Negative"], "BMA019": ["Positive", "Advanced"], "BMA020": ["Advanced"],
	"BMA021": ["Kill", "Spell"], "BMA022": ["Spell", "Spell"], "BMA023": ["Spell"], "BMA024": ["Spell"],
	"BMA025": ["Positive", "Advanced"], "BMA026": ["Spell", "Advanced"], "BMA027": ["Destroy"], "BMA028": ["Destroy", "Negative"],
	"BMA029": ["Combo"], "BMA030": ["Destroy"], "BMA031": ["Positive", "Advanced"], "BMA032": ["Destroy", "Combo", "Advanced"],
	"BMA033": ["Combo"], "BMA034": ["Positive"], "BMA035": [], "BMA036": ["Lure"],
	"BMA037": ["Positive"], "BMA038": ["Destroy"], "BMA039": ["Destroy"],
}

# --- AIHelper.GetGamePhase (l.68-83) --------------------------------------------------------------------

## NumberOfTurns n'est incremente qu'en fin de tour : le 1er tour = Early, les tours 2-4 = Mid, >= 5 = Late ; Setup pendant Setup_a/b/c.
## G.turn (1 au 1er tour) donne deja ces bornes.
static func phase(G: Dictionary) -> String:
	if str(G.get("phase", "")) == "setup":
		return "setup"
	var t := int(G.get("turn", 0))
	return "early" if t <= 1 else ("mid" if t <= 4 else "late")

static func _tables(ph: String) -> Array:
	match ph:
		"mid":
			return [MID_DAMAGE, MID_TREASURE, MID_FACTORS]
		"late":
			return [LATE_DAMAGE, LATE_TREASURE, LATE_FACTORS]
	return [EARLY_DAMAGE, EARLY_TREASURE, EARLY_FACTORS] # Setup et Early

# --- RoomCalculator.cs -----------------------------------------------------------------------------------

## Room.Damage = InitialDamage + DealDamage.
static func room_damage(room: Dictionary) -> int:
	return int(room.get("damage", 0)) + int(room.get("dealDamage", 0))

## RoomCalculator.CalculateRoomValue (l.138-149) : degats + tresors (tables par phase) + somme facteur[type] x multiplicite.
static func base_value(room: Dictionary, ph: String) -> float:
	var t := _tables(ph)
	var v := float((t[0] as Array)[clampi(room_damage(room), 0, 9)]) + float((t[1] as Array)[clampi((room.get("treasures", []) as Array).size(), 0, 9)])
	for f in ROOM_FACTORS.get(CardDB.base_id(str(room.get("id", ""))), []):
		v += float((t[2] as Array)[FACTOR_NAMES.find(f)])
	return v

## RoomCalculator.CalculateValue (l.88-120). `tops` = salles du dessus des emplacements constructibles (null = emplacement vide), pour BuildOverPenalty.
static func room_value(G: Dictionary, p: Dictionary, pid: int, room: Dictionary, ph: String, tops: Array, check_modifiers := true) -> float:
	var v := base_value(room, ph)
	if check_modifiers:
		v += _modifiers(G, p, pid, room, ph)
		v -= _build_over_penalty(room, tops, ph)
	return maxf(0.0, v)

## SetupGameModifiers / EarlyGameModifiers / MidGameModifiers / LateGameModifiers (l.150-215).
static func _modifiers(G: Dictionary, p: Dictionary, pid: int, room: Dictionary, ph: String) -> float:
	var id := CardDB.base_id(str(room.get("id", "")))
	var v := 0.0
	match ph:
		"setup":
			if id == "BMA034" and _hand_has_fighter_thief_advanced(p): # SetupConstructionZoneComboFactor (l.226-236)
				v += SETUP_CONSTRUCTION_ZONE_COMBO
			if id == "BMA029" and _dungeon_size(_view(p)) == 0: # SetupDoNotPlaceDizzygasFirst (l.238-246)
				v += INVALID_DIZZYGAS_SETUP
		"early", "mid":
			v += _bait_hero_factor(G, p, pid, room)
			if id == "BMA015": # GoblinArmoryCorrectFactor (l.286-296)
				v += _last_room_factor(p, "monster", INVALID_GOBLIN_ARMORY, VALID_GOBLIN_ARMORY)
			elif id == "BMA029": # DizzygasHallwayCorrectFactor (l.298-308)
				v += _last_room_factor(p, "trap", INVALID_DIZZYGAS, VALID_DIZZYGAS)
	return v

static func _hand_has_fighter_thief_advanced(p: Dictionary) -> bool:
	for r in p.get("hand", []):
		var rd: Dictionary = r
		if bool(rd.get("isRoom", false)) and bool(rd.get("advanced", false)):
			if _count_treasure(rd.get("treasures", []), 2) > 0 or _count_treasure(rd.get("treasures", []), 4) > 0: # Fighter = 2, Thief = 4 (CardInfo.TreasureTypes)
				return true
	return false

## Le JSON donne des flottants (3.0) : Array.count / has ne les comparent pas aux entiers.
static func _count_treasure(arr: Array, t: int) -> int:
	var n := 0
	for x in arr:
		if int(x) == t:
			n += 1
	return n

## 1 <= DungeonSize <= 4 : la derniere salle posee (Dungeon[DungeonSize-1], Godot index 0 hors salles en attente) est du bon type ?
static func _last_room_factor(p: Dictionary, want_type: String, bad: float, good: float) -> float:
	var view := _view(p)
	var ds := _dungeon_size(view)
	if ds == 0 or ds >= 5:
		return 0.0
	return good if str(((view[ds - 1] as Dictionary)["top"] as Dictionary).get("type", "")) == want_type else bad

## RoomCalculator.BuildOverPenalty (l.248-268) : 0 des qu'un emplacement vide est constructible, sinon le minimum des CalculateBuildOverPenalty.
static func _build_over_penalty(room: Dictionary, tops: Array, ph: String) -> float:
	var best := INF
	for top in tops:
		if top == null:
			return 0.0
		best = minf(best, over_penalty(room, top as Dictionary, ph))
	return best

## RoomCalculator.CalculateBuildOverPenalty (l.122-135) : 300 si l'ancienne est avancee ; 0 si ordinaire -> avancee ; sinon sa valeur sans modificateurs.
static func over_penalty(new_room: Dictionary, old_room: Dictionary, ph: String) -> float:
	if bool(old_room.get("advanced", false)):
		return BUILD_OVER_ADVANCED_PENALTY
	if bool(new_room.get("advanced", false)):
		return 0.0
	return maxf(0.0, base_value(old_room, ph))

## RoomCalculator.BaitHeroFactor (l.270-284) : -100 x Wounds + 1 par heros de la ville que cette salle ferait attirer par le joueur seul
## (FindBaitingPlayer), hors heros deja attires par lui, et que le donjon ne tue pas.
static func _bait_hero_factor(G: Dictionary, p: Dictionary, pid: int, room: Dictionary) -> float:
	var town: Array = G.get("town", [])
	if town.is_empty():
		return 0.0
	var v := 0.0
	var dmg := dungeon_damage(G, p, pid) + room_damage(room)
	for h in town:
		var hero: Dictionary = h
		if _baiting_player(G, hero, -1, {}) == pid:
			continue # alreadyBaitedHeroes
		if _baiting_player(G, hero, pid, room) == pid and BossEngine.hero_health_with_modifiers(G, hero) > dmg:
			v += BAIT_MODIFIER * float(CardDB.total_wounds(p)) + 1.0
	return v

## RoomCalculator.FindBaitingPlayer (l.310-331) : le seul joueur au meilleur total de tresors du heros (la salle `room` comptee pour `active`), sinon -1.
static func _baiting_player(G: Dictionary, hero: Dictionary, active: int, room: Dictionary) -> int:
	var best := -2147483648
	var who := -1
	var tied := false
	for key in (G.get("players", {}) as Dictionary).keys():
		var q: Dictionary = G["players"][key]
		if bool(q.get("eliminated", false)):
			continue
		var n := _treasures_for_hero(G, q, hero)
		if int(key) == active:
			for t in CardDB.hero_treasures(hero): # GetTotalTreasuresForHero(player, hero, newRoom)
				n += _count_treasure(room.get("treasures", []), int(t))
		if n > best:
			best = n
			who = int(key)
			tied = false
		elif n == best:
			tied = true
	return -1 if tied else who

## AIHelper.GetTotalTreasuresForHero : tresors du donjon (Boss.GetDungeonTreasures : hors salles en attente) de chaque classe du heros.
static func _treasures_for_hero(G: Dictionary, q: Dictionary, hero: Dictionary) -> int:
	var shown: Array = []
	for stack in q.get("dungeon", []):
		var top = BossEngine.active_room(stack)
		if top != null and not bool((top as Dictionary).get("faceDown", false)):
			shown.append(stack)
	var qq := q.duplicate()
	qq["dungeon"] = shown
	var n := 0
	for t in CardDB.hero_treasures(hero):
		n += BossEngine.treasure_count(qq, int(t), G)
	return n

## AIHelper.GetDungeonDamage (l.95-117) : slots actifs, non vides, non en attente, du fond a l'entree ; la salle qui suit un Minotaur's Maze (BMA017) compte double.
static func dungeon_damage(G: Dictionary, p: Dictionary, pid: int) -> int:
	var view := _view(p)
	var ds := _dungeon_size(view)
	var total := 0
	var prev: Variant = null
	for c in ds:
		var s: Dictionary = view[c]
		var top = s["top"]
		if top != null and not bool(s["pending"]) and not BossEngine.is_room_deactivated(G, pid, int(s["g"])):
			var d := BossEngine.room_damage_with_modifiers(G, p, int(s["g"]), null)
			total += d
			if prev != null and CardDB.base_id(str((prev as Dictionary).get("id", ""))) == "BMA017":
				total += d
			prev = top
		else:
			prev = null
	return total

# --- vue C# du donjon --------------------------------------------------------------------------------------

## Donjon dans l'ordre C# (0 = le plus ancien) : [{g, top, pending}].
static func _view(p: Dictionary) -> Array:
	var d: Array = p.get("dungeon", [])
	var out: Array = []
	for g in range(d.size() - 1, -1, -1):
		var top = BossEngine.active_room(d[g])
		out.append({"g": g, "top": top, "pending": top != null and bool((top as Dictionary).get("faceDown", false))})
	return out

## Boss.DungeonSize : dernier emplacement non vide et non en attente, + 1.
static func _dungeon_size(view: Array) -> int:
	var last := -1
	for c in view.size():
		if (view[c] as Dictionary)["top"] != null and not bool((view[c] as Dictionary)["pending"]):
			last = c
	return last + 1

# --- DungeonSlotCalculator.cs ---------------------------------------------------------------------------------

## DungeonSlotCalculator.CalculateValue (l.25-45) : valeur de la pose de `room` a l'index C# `c` (dont le dessus est `top`).
static func slot_value(room: Dictionary, c: int, top: Variant, view: Array, ph: String) -> float:
	var id := CardDB.base_id(str(room.get("id", "")))
	var ds := _dungeon_size(view)
	var v := maxf(0.0, base_value(room, ph)) # RoomCalculator.CalculateValue(checkModifiers: false)
	if id == "BMA017" and c == 4: # MinotaurMazeNotLastFactor
		v += SLOT_INVALID_MINOTAUR
	elif id == "BMA015" and ds == 5: # GoblinArmoryPlacementFactor
		v += SLOT_INVALID_GOBLIN_FIRST if c == 0 else (SLOT_VALID_GOBLIN if _view_type(view, c - 1) == "monster" else SLOT_INVALID_GOBLIN)
	elif id == "BMA029" and ds == 5: # DizzygasHallwayPlacementFactor
		v += SLOT_INVALID_DIZZYGAS_FIRST if c == 0 else (SLOT_VALID_DIZZYGAS if _view_type(view, c - 1) == "trap" else SLOT_INVALID_DIZZYGAS)
	var pen := 0.0
	if top != null:
		pen = over_penalty(room, top as Dictionary, ph)
	return maxf(0.0, v - pen)

static func _view_type(view: Array, c: int) -> String:
	var top = (view[c] as Dictionary)["top"] if c >= 0 and c < view.size() else null
	return str((top as Dictionary).get("type", "")) if top != null else ""

# --- StatisticsCalculator.NormalizeValues (l.141-163), minChance = 0 ----------------------------------------------

static func _normalize(values: Array) -> Array:
	var out: Array = []
	if values.size() == 1:
		return [1.0]
	var mn := INF
	for v in values:
		mn = minf(mn, float(v))
	var shifted: Array = []
	var sum := 0.0
	for v in values:
		shifted.append(float(v) - mn)
		sum += float(v) - mn
	if sum != 0.0:
		var k := (100.0 - 0.0) / sum
		for s in shifted:
			out.append((0.0 + k * float(s)) / 100.0)
	else:
		for _i in values.size():
			out.append(1.0 / float(values.size()))
	return out

# --- FixedAI.SelectRoomToBuild / SelectPositionToBuild ---------------------------------------------------------------

## Decision de construction de FixedAI sur les coups `buildRoom` legaux de Godot (args [main] = nouvel emplacement, [main, g] = par-dessus l'emplacement g).
## Deux argmax sequentiels : la salle (valeur avec modificateurs ; egalite -> degats decroissants puis ordre de la main ; rien si le max est 0,
## StatisticsCalculator.cs l.125-127), puis l'emplacement (egalite -> degats du dessus croissants puis index C# croissant ; rien si le max est 0, l.63-65).
## Rend {"pick": index dans `builds` ou -1, "keys": un rang flottant par coup (voir build_key)}.
static func plan(G: Dictionary, pid: int, builds: Array) -> Dictionary:
	var p: Dictionary = G["players"][pid]
	var hand: Array = p.get("hand", [])
	var dungeon: Array = p.get("dungeon", [])
	var ph := phase(G)
	var view := _view(p)
	var by_hand := {}
	for k in builds.size():
		var a: Array = (builds[k] as Dictionary)["args"]
		var hi := int(a[0])
		var g := int(a[1]) if a.size() > 1 and a[1] != null else -1
		var c := dungeon.size() if g < 0 or g >= dungeon.size() else dungeon.size() - 1 - g
		var top = null if g < 0 or g >= dungeon.size() else BossEngine.active_room(dungeon[g])
		if not by_hand.has(hi):
			by_hand[hi] = []
		(by_hand[hi] as Array).append({"k": k, "c": c, "top": top})
	var his: Array = by_hand.keys()
	his.sort()
	var rvals: Array = []
	var room_of := {}
	for hi in his:
		(by_hand[hi] as Array).sort_custom(func(x, y): return int(x["c"]) < int(y["c"]))
		var tops: Array = (by_hand[hi] as Array).map(func(e): return e["top"])
		var room: Dictionary = hand[hi] if hi >= 0 and hi < hand.size() else {}
		room_of[hi] = room
		rvals.append(room_value(G, p, pid, room, ph, tops))
	var keys: Array = []
	keys.resize(builds.size())
	keys.fill(0.0)
	var pick_hi := -1
	var pick_slot := -1
	var rmax := 0.0
	for v in rvals:
		rmax = maxf(rmax, float(v))
	var rnorm := _normalize(rvals) if not rvals.is_empty() else []
	var best := -1
	for i in his.size():
		if best < 0 or float(rnorm[i]) > float(rnorm[best]) or (float(rnorm[i]) == float(rnorm[best]) and room_damage(room_of[his[i]]) > room_damage(room_of[his[best]])):
			best = i
	if best >= 0 and rmax > 0.0:
		pick_hi = his[best]
	var chosen_slot_by := {}
	for i in his.size():
		var hi: int = his[i]
		var ents: Array = by_hand[hi]
		var svals: Array = []
		for e in ents:
			svals.append(slot_value(room_of[hi], int(e["c"]), e["top"], view, ph))
		var snorm := _normalize(svals)
		var sb := 0
		var smax := 0.0
		for j in ents.size():
			smax = maxf(smax, float(svals[j]))
			if j > 0:
				var td: int = room_damage(ents[j]["top"]) if ents[j]["top"] != null else 0
				var bd: int = room_damage(ents[sb]["top"]) if ents[sb]["top"] != null else 0
				if float(snorm[j]) > float(snorm[sb]) or (float(snorm[j]) == float(snorm[sb]) and td < bd):
					sb = j
		chosen_slot_by[hi] = int(ents[sb]["k"]) if smax > 0.0 else -1
		for j in ents.size():
			var tdm: int = room_damage(ents[j]["top"]) if ents[j]["top"] != null else 0
			var skey := (minf(float(svals[j]), 7000.0) * 16.0 + float(15 - mini(tdm, 15))) * 8.0 + float(7 - mini(int(ents[j]["c"]), 7))
			var rkey := (minf(float(rvals[i]), 20000.0) * 16.0 + float(mini(room_damage(room_of[hi]), 15))) * 16.0 + float(15 - mini(hi, 15))
			keys[int(ents[j]["k"])] = rkey * 1000000.0 + skey
	if pick_hi >= 0:
		pick_slot = int(chosen_slot_by[pick_hi])
	return {"pick": pick_slot, "keys": keys}

# --- DiscardCalculator.cs / StatisticsCalculator.CalculateHandDiscardStatistics ----------------------------------------------

## Peut-on batir la carte `hi` de la main quelque part, hors phase (Boss.CanBuildRoom(ignoreGamePhase: true)) ?
static func can_build_anywhere(G: Dictionary, p: Dictionary, pid: int, hi: int) -> bool:
	var q := p.duplicate()
	q["buildsThisTurn"] = 0
	if BossEngine.can_build_room(q, G, pid, hi, -1):
		return true
	for ti in (p.get("dungeon", []) as Array).size():
		if BossEngine.can_build_room(q, G, pid, hi, ti):
			return true
	return false

## FixedAI.DiscardCards (l.19-24) sur la main d'ouverture : valeur des salles SANS modificateurs (+ facteur « ne peut pas etre batie », test par carte,
## plancher 0), valeur d'un sort = (meilleure valeur reelle des salles) x facteur ; tri croissant STABLE (salles dans l'ordre de la main, puis sorts),
## on defausse les `amount` plus faibles. Rend des indices de main tries.
static func opening_discards(G: Dictionary, p: Dictionary, hand: Array, amount := 2) -> Array:
	var pid := int(p.get("id", 0))
	var ph := phase(G)
	var pp := p.duplicate()
	pp["hand"] = hand
	var order: Array = []
	var vals: Array = []
	var best := 0.0
	for i in hand.size():
		var c: Dictionary = hand[i]
		if bool(c.get("isRoom", false)):
			var v := base_value(c, ph)
			if not can_build_anywhere(G, pp, pid, i):
				v += float(CANT_BUILD_FACTOR[ph])
			v = maxf(0.0, v)
			order.append(i)
			vals.append(v)
			best = maxf(best, v)
	for i in hand.size():
		if not bool((hand[i] as Dictionary).get("isRoom", false)):
			order.append(i)
			vals.append(best * float(KEEP_SPELL_FACTOR[ph]))
	var norm := _normalize(vals)
	var idx: Array = range(order.size())
	idx.sort_custom(func(a, b): return float(norm[a]) < float(norm[b]) or (float(norm[a]) == float(norm[b]) and a < b))
	var out: Array = []
	for k in mini(amount, idx.size()):
		out.append(order[idx[k]])
	out.sort()
	return out

# --- DrawCalculator.cs ------------------------------------------------------------------------------------------------------

## DrawCalculator.CalculateDeckDrawValue : probabilite de piocher une salle (StatisticAI.SelectWhereToDrawFrom : rng <= p -> salle).
static func draw_room_probability(G: Dictionary, p: Dictionary, pid: int) -> float:
	var n := 0
	var hand: Array = p.get("hand", [])
	for i in hand.size():
		if bool((hand[i] as Dictionary).get("isRoom", false)) and can_build_anywhere(G, p, pid, i):
			n += 1
	match phase(G):
		"mid":
			return 1.0 if n == 0 else (0.75 if n == 1 else 0.15)
		"late":
			return 1.0 if n == 0 else 0.1
	return 1.0 if n == 0 else (0.75 if n == 1 else 0.25)
