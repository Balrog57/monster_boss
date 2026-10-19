class_name ApkAI
extends RefCounted
## Decisions de l'IA de l'APK (FixedAI, celle de l'oracle) portees fonction par fonction :
##  - etape 1 (DETERMINISTE) : valeur de salle, choix de la salle, de l'emplacement, abstention, defausse d'ouverture, probabilite de pioche (Haunted Library) ;
##  - etape 2 (tirage uniforme, voir « Etape 2 » en bas de fichier) : sorts et capacites de salle eligibles (AbilityCalculator, un CheckXXX par carte) et leurs cibles ;
##  - etape 3 (voir « Etape 3 » en bas de fichier) : cibles des declencheurs et des commandes (TriggerCalculator, un CheckXXX par carte) = reponse de l'IA aux choix ouverts par le moteur.
## Sources (apk-original/decompiled/DBMGame/) : DBMGameProject.AI/{FixedAI,StatisticAI,AIHelper}.cs et
## DBMGameProject.AI.Statistics/{StatisticsCalculator,RoomCalculator,DungeonSlotCalculator,DiscardCalculator,DrawCalculator,AbilityCalculator,TriggerCalculator}.cs.
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
## `upto` = AIHelper.SliceDungeon(player, slot) (l.230-240) : seuls les slots d'index C# < upto (les salles que le heros n'a pas encore traversees) ; -1 = tout le donjon.
static func dungeon_damage(G: Dictionary, p: Dictionary, pid: int, upto := -1) -> int:
	var view := _view(p)
	var ds := _dungeon_size(view)
	var total := 0
	var prev: Variant = null
	for c in (ds if upto < 0 else mini(upto, view.size())):
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

# ======================================================================================================================
# Etape 2 : SORTS et CAPACITES DE SALLE. Sources (apk-original/decompiled/DBMGame/) :
#  - DBMGameProject.AI.Statistics/AbilityCalculator.cs : un CheckXXX par carte (switch l.30-58) ; `_ => null` = carte JAMAIS jouee ;
#    en Spell Battle (IsSpellBattleActive) seules BMA043 Counterspell et BMA025 All-Seeing Eye sont evaluees (l.22-30) ;
#  - StatisticsCalculator.cs l.70-88 (CalculateAbilityStatistics) : chaque CheckXXX non nul vaut 1.0 -> NormalizeValues -> 1/n chacun ;
#  - StatisticAI.cs l.58-70 + RandomSelection l.100-115 : tirage UNIFORME parmi les capacites eligibles (une copie = une entree) ;
#  - AIPlayerInteraction.cs : UseAbility (l.188-222), AbilityApplyRequest (l.29-43, Spell Battle), InternalDoPlayerActions (l.60-110) ;
#  - AIHelper.cs : GetUsableAbilities (l.20-31), CalculateMostDamagingSlot, HasHeroPassedSlot, WhoWouldBaitHero, HasRoomBelow...
# Les tirages internes du C# (`Shuffle()`, `NextBool()`) utilisent le RNG de la partie Godot (`rng`).
# Ecart ASSUME avec le C# : AbilityCalculator.CheckBMA040And047 (l.844-847) reprend la liste de salles TRAP dans sa branche « heros actif » pour
# Giant Size aussi ; on garde le type de la carte (une salle Trap n'est pas une cible legale de Giant Size : bogue, pas une regle).
# ======================================================================================================================

const AB_SPELLS := ["BMA040", "BMA041", "BMA042", "BMA044", "BMA045", "BMA046", "BMA047", "BMA048", "BMA049", "BMA050", "BMA051", "BMA052", "BMA053", "BMA054", "BMA055", "KSA013"]
const AB_ROOMS := ["BMA009", "BMA013", "BMA024", "BMA027", "BMA028", "BMA030", "BMA032", "BMA038", "BMA039"]
const WIKI_PREFIXES := ["TNL", "RMB", "CRL", "THK", "IOD"]
## Cartes KSA que l'APK ne joue pas (pseudo-paquet players-choice-wiki) : leur IA est maison, comme celle des autres paquets wiki.
const WIKI_KSA := ["KSA008", "KSA009", "KSA010", "KSA011", "KSA012", "KSA015"]
## Diagnostic de mesure seulement (ApkParityTrace `--ai-copy-trap-bug`) : reproduit le bogue de CheckBMA040And047 (Giant Size sur une salle Trap).
static var copy_trap_bug := false

## Carte d'un paquet wiki (hors APK) : son IA reste AiWiki / TnlAbilities / RmbAbilities.
static func is_wiki_card(id: String) -> bool:
	return WIKI_PREFIXES.has(id.substr(0, 3)) or WIKI_KSA.has(id)

## Le coup `m` est-il le sort ou la capacite de salle d'une carte de l'APK (AbilityCalculator s'applique) ?
static func is_apk_ability_move(p: Dictionary, m: Dictionary) -> bool:
	var a: Array = m.get("args", [])
	match str(m.get("type", "")):
		"playSpell":
			var hand: Array = p.get("hand", [])
			return not a.is_empty() and int(a[0]) >= 0 and int(a[0]) < hand.size() and not is_wiki_card(str((hand[int(a[0])] as Dictionary).get("id", "")))
		"activateRoom":
			var d: Array = p.get("dungeon", [])
			if a.is_empty() or int(a[0]) < 0 or int(a[0]) >= d.size():
				return false
			var r = BossEngine.active_room(d[int(a[0])])
			return r != null and not is_wiki_card(str((r as Dictionary).get("id", "")))
	return false

# --- vue de la partie ----------------------------------------------------------------------------------------------

## GameBoard.InGamePlayersPriorized : joueurs vivants par PlayerId (= rang d'XP du boss).
static func prio_players(G: Dictionary) -> Array:
	var order: Array = G.get("xpOrder", [])
	if order.is_empty():
		order = CardDB.order_by_xp(G["players"])
	var out: Array = []
	for pid in order:
		var q = (G["players"] as Dictionary).get(int(pid))
		if q != null and not bool((q as Dictionary).get("eliminated", false)):
			out.append(int(pid))
	return out

## GameBoard.GetOpponents (GameBoard.cs:206).
static func opponents(G: Dictionary, pid: int) -> Array:
	return prio_players(G).filter(func(q): return int(q) != pid)

## Hero.CurrentHealth : le heros actif porte ses PV courants (adventure.hp), les autres ceux de la carte + bonus d'effets.
static func hero_health(G: Dictionary, hero: Dictionary) -> int:
	var adv: Dictionary = G.get("adventure", {}) as Dictionary
	if not adv.is_empty() and is_same(adv.get("hero"), hero):
		return int(adv.get("hp", 0))
	return BossEngine.hero_health_with_modifiers(G, hero)

## GameBoard.ActiveHero + InsideDungeonSlot. {} = aucun. `owner` = joueur dont le heros est dans le donjon ; `c` = index C# du slot du heros
## (-1 : le heros est designe mais pas encore entre, fenetre AdventurePhase_b) ; `hp` = PV courants.
## Fenetres de sorts d'aventure de Godot (pause post-degats / avant sortie) = AdventurePhase_c ; avant `adventureNext` = AdventurePhase_b.
static func active_hero(G: Dictionary) -> Dictionary:
	var players: Dictionary = G["players"]
	var adv: Dictionary = G.get("adventure", {}) as Dictionary
	if not adv.is_empty():
		var ow := int(adv.get("playerId", -1))
		var dsz := ((players[ow] as Dictionary).get("dungeon", []) as Array).size() if players.has(ow) else 0
		var g := int(adv.get("roomIndex", -1))
		var inside := g >= 0 and g < dsz
		if bool(adv.get("roomGone", false)): # sa salle a ete detruite : le slot vide passe en fin de liste (GameBoard.DestroyRoom), le heros y reste
			return {"hero": adv.get("hero"), "owner": ow, "c": CardDB.DUNGEON_SLOTS - 1, "g": -2, "hp": int(adv.get("hp", 0))}
		return {"hero": adv.get("hero"), "owner": ow, "c": (dsz - 1 - g) if inside else -1, "g": g if inside else -1, "hp": int(adv.get("hp", 0))}
	if str(G.get("phase", "")) != CardDB.PHASE["ADVENTURE"] or G.has("afterHero") or G.get("activePlayer") == null:
		return {}
	var ap := int(G["activePlayer"])
	var q: Dictionary = players.get(ap, {}) as Dictionary
	var ent: Array = q.get("entrance", []) as Array
	if ent.is_empty() or ((G.get("effects", {}) as Dictionary).get("skipAdventure", []) as Array).has(ap):
		return {}
	return {"hero": ent[0], "owner": ap, "c": -1, "g": -1, "hp": hero_health(G, ent[0] as Dictionary)}

# --- contexte d'evaluation ------------------------------------------------------------------------------------------------

static func _ctx(G: Dictionary, pid: int, moves: Array, rng: RandomNumberGenerator) -> Dictionary:
	var p: Dictionary = G["players"][pid]
	var view := _view(p)
	return {"G": G, "p": p, "pid": pid, "ph": phase(G), "rng": rng, "view": view, "ds": _dungeon_size(view), "ah": active_hero(G),
		"battle": not (G.get("stack", []) as Array).is_empty(), "moves": moves}

static func _early(x: Dictionary) -> bool:
	return x["ph"] == "setup" or x["ph"] == "early"

static func _early_mid(x: Dictionary) -> bool:
	return x["ph"] != "late"

## Tri croissant STABLE (LINQ OrderBy) : `keyf` rend un tableau de nombres compares dans l'ordre ; egalite -> ordre d'origine.
static func _stable(arr: Array, keyf: Callable) -> Array:
	var ks: Array = []
	for i in arr.size():
		ks.append([keyf.call(arr[i]), i])
	ks.sort_custom(func(a, b):
		var ka: Array = a[0]
		var kb: Array = b[0]
		for j in ka.size():
			if ka[j] != kb[j]:
				return ka[j] < kb[j]
		return int(a[1]) < int(b[1]))
	return ks.map(func(e): return arr[int(e[1])])

## Slot actif non vide, non en attente (DungeonSlot.IsActive && !PendingToBeBuilt && RoomStack.Any()) : {c, g, top} ou {}.
static func _active_slot(x: Dictionary, c: int) -> Dictionary:
	var view: Array = x["view"]
	if c < 0 or c >= view.size():
		return {}
	var s: Dictionary = view[c]
	if s["top"] == null or bool(s["pending"]) or BossEngine.is_room_deactivated(x["G"], int(x["pid"]), int(s["g"])):
		return {}
	return {"c": c, "g": int(s["g"]), "top": s["top"]}

## Boss.DungeonActiveSlots / AIHelper.GetActiveSlots (l.153-165) dans l'ordre C#.
static func _active_slots(x: Dictionary) -> Array:
	var out: Array = []
	for c in int(x["ds"]):
		var s := _active_slot(x, c)
		if not s.is_empty():
			out.append(s)
	return out

## DungeonSlot.GetTopRoomTotalDamage du slot g d'un joueur.
static func _slot_damage(G: Dictionary, q: Dictionary, g: int) -> int:
	return BossEngine.room_damage_with_modifiers(G, q, g, null)

## AIHelper.GetActiveRoomsOfType (l.127-141) : salles du dessus, slots d'index < upto (-1 = tout), de type `rtype` : [{c, g, top}].
static func _rooms_of_type(x: Dictionary, rtype: String, upto: int) -> Array:
	var out: Array = []
	for c in (int(x["ds"]) if upto < 0 else mini(upto, (x["view"] as Array).size())):
		var s := _active_slot(x, c)
		if not s.is_empty() and str((s["top"] as Dictionary).get("type", "")) == rtype:
			out.append(s)
	return out

## AIHelper.IsActiveHeroLuredByPlayer (l.115-125) : le heros actif est dans un slot du donjon de `who` (et, si `room_g` >= 0, dans CE slot).
static func _lured_by(x: Dictionary, who: int, room_g := -1) -> bool:
	var ah: Dictionary = x["ah"]
	if ah.is_empty() or int(ah["c"]) < 0 or int(ah["owner"]) != who:
		return false
	return room_g < 0 or int(ah["g"]) == room_g

## AIHelper.GetActiveHeroHealthAfterDungeon : PV du heros actif moins les degats des salles encore devant lui. Le slot du heros est cherche dans le donjon
## de `who` (Dungeon.IndexOf) : s'il est dans celui d'un autre joueur, Take(-1) = rien. Heros pas encore entre : donjon entier.
static func _active_after(x: Dictionary, who: int) -> int:
	var ah: Dictionary = x["ah"]
	var G: Dictionary = x["G"]
	var q: Dictionary = G["players"][who]
	var dmg := 0
	if int(ah["c"]) < 0:
		dmg = dungeon_damage(G, q, who)
	elif int(ah["owner"]) == who:
		dmg = dungeon_damage(G, q, who, int(ah["c"]))
	return int(ah["hp"]) - dmg

## Reponse d'un CheckXXX : cibles preregles (AbilitySelectedInformation.SetSelectedTargets(effet, fournisseur, cartes)) + argument du coup Godot.
static func _res(t: Array, arg: Variant = null, shuf := false) -> Dictionary:
	return {"t": t, "arg": arg, "shuf": shuf}

static func _boss_of(G: Dictionary, pid: int) -> Dictionary:
	return (G["players"][pid] as Dictionary).get("boss", {}) as Dictionary

static func _bosses(G: Dictionary, pids: Array) -> Array:
	return pids.map(func(q): return _boss_of(G, int(q)))

## Nombre moyen entier chez les adversaires (`sum / Count()` : division ENTIERE en C#) ; `f` prend le dictionnaire d'un joueur.
static func _opp_avg(x: Dictionary, f: Callable) -> int:
	var opps := opponents(x["G"], int(x["pid"]))
	if opps.is_empty():
		return 0
	var sum := 0
	for q in opps:
		sum += int(f.call(x["G"]["players"][int(q)]))
	return sum / opps.size()

static func _hand_spells(p: Dictionary) -> int:
	var n := 0
	for c in (p.get("hand", []) as Array):
		if bool((c as Dictionary).get("isSpell", false)):
			n += 1
	return n

## AIHelper.WhoWouldBaitHero (l.221-231) : [joueur seul au meilleur total de tresors du heros ou -1 en cas d'egalite, ce total].
static func _who_would_bait(G: Dictionary, hero: Dictionary) -> Array:
	var best := -1
	var tot: Dictionary = {}
	for q in prio_players(G):
		tot[int(q)] = _treasures_for_hero(G, G["players"][int(q)], hero)
		best = maxi(best, int(tot[int(q)]))
	var who: Array = prio_players(G).filter(func(q): return int(tot[int(q)]) == best)
	return [int(who[0]) if who.size() == 1 else -1, best]

## Rang d'une carte de la defausse a valeur egale : GameBoard.DestroyRoom trie DiscardPileRooms par UniqueID (LogicCardBase.CompareTo). Godot n'a pas d'identifiant
## d'instance hors du harnais de parite (`_oid`) : sans lui, l'ordre de la defausse (egalite stable).
static func _discard_rank(card: Dictionary) -> int:
	return int(card.get("_oid", 0))

## Boss.CanBuildRoom(gs, r, ignoreGamePhase: true) pour une carte qui n'est pas (forcement) en main : on l'ajoute a une copie de la main.
static func _can_build_card(G: Dictionary, p: Dictionary, pid: int, card: Dictionary) -> bool:
	var pp := p.duplicate()
	var h: Array = (p.get("hand", []) as Array).duplicate()
	h.append(card)
	pp["hand"] = h
	return can_build_anywhere(G, pp, pid, h.size() - 1)

## RoomCalculator.CalculateValue(room, checkModifiers: false).
static func _val0(x: Dictionary, room: Dictionary) -> float:
	return room_value(x["G"], x["p"], int(x["pid"]), room, str(x["ph"]), [], false)

static func _hero_entry(hero: Dictionary) -> Dictionary:
	return _res([[0, 0, [hero]]], {"heroId": hero.get("id")})

# --- CheckXXX : sorts -----------------------------------------------------------------------------------------------

## AbilityCalculator.CheckBMA040/CheckBMA047 + CheckBMA040And047 + BMA040And047Logic (l.64-66, 98-100, 844-880).
static func _chk_040_047(x: Dictionary, rtype: String) -> Variant:
	if _early(x):
		return null
	var rooms := _rooms_of_type(x, rtype, -1)
	if rooms.is_empty():
		return null
	for hero in (x["p"] as Dictionary).get("entrance", []):
		var r = _logic_040_047(x, hero as Dictionary, -1, rooms)
		if r != null:
			return r
	if _lured_by(x, int(x["pid"])):
		var ah: Dictionary = x["ah"]
		rooms = _rooms_of_type(x, "trap" if copy_trap_bug else rtype, int(ah["c"])) # le C# reprend ici la liste Trap pour Giant Size aussi (voir l'en-tete)
		if not rooms.is_empty():
			var r2 = _logic_040_047(x, ah["hero"] as Dictionary, int(ah["c"]), rooms)
			if r2 != null:
				return r2
	return null

## BMA040And047Logic : PV du heros apres le donjon dans (0;3] -> une salle au hasard (`Shuffle().First()`).
static func _logic_040_047(x: Dictionary, hero: Dictionary, pos_c: int, rooms: Array) -> Variant:
	var pid := int(x["pid"])
	var hh := hero_health(x["G"], hero) - dungeon_damage(x["G"], x["p"], pid, pos_c)
	if hh > 0 and hh <= 3:
		var pick: Dictionary = rooms[(x["rng"] as RandomNumberGenerator).randi_range(0, rooms.size() - 1)]
		return _res([[0, 0, [pick["top"]]]], {"targetPlayerId": pid, "roomIndex": int(pick["g"])}, true)
	return null

## CheckBMA041 Assassin (l.68-86) : l'adversaire qui attire le heros actif le tuerait de justesse (PV apres donjon dans (-3;0]) : +3 PV.
static func _chk_041(x: Dictionary) -> Variant:
	if _early(x):
		return null
	for q in opponents(x["G"], int(x["pid"])):
		if _lured_by(x, int(q)):
			var after := _active_after(x, int(q))
			if after <= 0 and after > -3:
				return _hero_entry((x["ah"] as Dictionary)["hero"])
	return null

## CheckBMA042 Cave-In (l.88-106) : le heros actif est dans NOTRE pire salle (CalculateWorstSlot) et survivrait au reste du donjon.
static func _chk_042(x: Dictionary) -> Variant:
	if _early(x):
		return null
	var pid := int(x["pid"])
	if _lured_by(x, pid):
		var ah: Dictionary = x["ah"]
		if _active_after(x, pid) > 0 and _worst_slot_c(x) == int(ah["c"]):
			var s := _active_slot(x, int(ah["c"]))
			if not s.is_empty():
				return _res([[0, 0, [s["top"]]]], {"roomIndex": int(s["g"])})
	return null

## CalculateWorstSlot (l.920-935) : plus petite valeur sans modificateurs (-75 pour une pile de plusieurs salles non avancee) ; premier minimum.
static func _worst_slot_c(x: Dictionary) -> int:
	var best := INF
	var res := -1
	for s in _active_slots(x):
		var top: Dictionary = (s as Dictionary)["top"]
		var v := _val0(x, top)
		if ((x["p"] as Dictionary)["dungeon"][int((s as Dictionary)["g"])] as Array).size() > 1 and not bool(top.get("advanced", false)):
			v += -75.0
		if v < best:
			best = v
			res = int((s as Dictionary)["c"])
	return res

## Joueurs « vises » par un sort de la pile (Ability.GetAgainstPlayers : proprietaires des cibles de ses commandes).
## Sorts hors APK (jetons de test, cartes wiki) : cible inconnue -> tous les joueurs (le Counterspell d'avant ne distinguait rien).
static func _against(x: Dictionary, e: Dictionary) -> Array:
	var G: Dictionary = x["G"]
	var id := str((e.get("card", {}) as Dictionary).get("id", ""))
	var tg: Dictionary = {}
	if e.get("target") is Dictionary:
		tg = e["target"]
	var caster := int(e.get("playerId", -1))
	match id:
		"BMA040", "BMA046", "BMA047", "BMA054", "BMA055":
			return [int(tg["targetPlayerId"])] if tg.has("targetPlayerId") else []
		"BMA042", "BMA050", "BMA051", "BMA052":
			return [caster]
		"BMA041", "BMA044", "BMA045", "BMA053":
			for q in G["players"]:
				for h in ((G["players"][q] as Dictionary).get("entrance", []) as Array):
					if str((h as Dictionary).get("id", "")) == str(tg.get("heroId", "")):
						return [int(q)]
			return []
		"BMA043":
			for s in (G.get("stack", []) as Array):
				if str((s as Dictionary).get("id", "")) == str(tg.get("stackId", "")):
					return [int((s as Dictionary).get("playerId", -1))]
			return []
		"BMA048", "BMA049", "KSA013":
			return prio_players(G)
	return prio_players(G) if not AB_SPELLS.has(id) else []

## Sorts adverses sur la pile = GameBoard.SpellBattleCards (Spell, proprietaire != joueur), dans l'ordre de la pile.
static func _stack_spells_of_others(x: Dictionary) -> Array:
	var out: Array = []
	for e in (x["G"].get("stack", []) as Array):
		if str((e as Dictionary).get("type", "")) == "spell" and int((e as Dictionary).get("playerId", -1)) != int(x["pid"]):
			out.append(e)
	return out

## CheckBMA043 Counterspell (l.108-148) : un sort adverse qui NOUS vise ; sinon BMA040/044/047/053 sans proprietaire de cible, ou T.P.K.
static func _chk_043(x: Dictionary) -> Variant:
	if _early(x):
		return null
	var spells := _stack_spells_of_others(x)
	for e in spells:
		if (_against(x, e) as Array).has(int(x["pid"])):
			return _res([[0, 0, [(e as Dictionary)["card"]]]], {"stackId": str((e as Dictionary).get("id", ""))})
	for e in spells:
		var id := str(((e as Dictionary).get("card", {}) as Dictionary).get("id", ""))
		if (_against(x, e) as Array).is_empty():
			if ["BMA040", "BMA044", "BMA047", "BMA053"].has(id):
				return _res([[0, 0, [(e as Dictionary)["card"]]]], {"stackId": str((e as Dictionary).get("id", ""))})
		elif id == "KSA013":
			return _res([[0, 0, [(e as Dictionary)["card"]]]], {"stackId": str((e as Dictionary).get("id", ""))})
	return null

## CheckBMA044 Exhaustion (l.150-172) : Late ; le heros dans NOTRE donjon survivrait avec 1..DungeonSize PV.
static func _chk_044(x: Dictionary) -> Variant:
	if _early_mid(x):
		return null
	var pid := int(x["pid"])
	if _lured_by(x, pid):
		var after := _active_after(x, pid)
		if after > 0 and after <= int(x["ds"]):
			return _hero_entry((x["ah"] as Dictionary)["hero"])
	return null

## CheckBMA045 Fear (l.174-212) : hors Setup/Early ; (a) 3+ blessures et le heros est dans notre slot 0 avec des PV ; (b) sinon heros epique qui tuerait de
## justesse un adversaire a 6+ ames.
static func _chk_045(x: Dictionary) -> Variant:
	if _early(x):
		return null
	var ah: Dictionary = x["ah"]
	if ah.is_empty():
		return null
	var pid := int(x["pid"])
	var G: Dictionary = x["G"]
	if CardDB.total_wounds(x["p"]) > 2:
		if int(ah["owner"]) == pid and int(ah["c"]) == 0 and int(ah["hp"]) > 0:
			return _hero_entry(ah["hero"])
	elif bool((ah["hero"] as Dictionary).get("epic", false)):
		for q in opponents(G, pid):
			if CardDB.total_souls(G["players"][int(q)], G) > 5 and _lured_by(x, int(q)) and _active_after(x, int(q)) <= 0:
				return _hero_entry(ah["hero"])
	return null

## AIHelper.CalculateMostDamagingSlot (l.206-219) : {dmg, g, top} du slot actif de `q` le plus dur parmi ceux devant le heros (premier maximum), ou {}.
static func _most_damaging(x: Dictionary, q: int, hero_c: int) -> Dictionary:
	var G: Dictionary = x["G"]
	var qp: Dictionary = G["players"][q]
	var view := _view(qp)
	var best := -2147483648
	var res := {}
	for c in mini(hero_c, view.size()):
		var s: Dictionary = view[c]
		if BossEngine.is_room_deactivated(G, q, int(s["g"])):
			continue
		var dmg := 0 if s["top"] == null else _slot_damage(G, qp, int(s["g"]))
		if dmg > best:
			best = dmg
			res = {"dmg": dmg, "g": int(s["g"]), "top": s["top"]}
	return res

## CheckBMA046 Freeze (l.214-239) : un adversaire tuerait le heros ; geler sa salle la plus dure le sauverait.
static func _chk_046(x: Dictionary) -> Variant:
	if _early(x):
		return null
	for q in opponents(x["G"], int(x["pid"])):
		if not _lured_by(x, int(q)):
			continue
		var after := _active_after(x, int(q))
		if after <= 0:
			var t := _most_damaging(x, int(q), int((x["ah"] as Dictionary)["c"]))
			if not t.is_empty() and after + int(t["dmg"]) > 0:
				return _res([[0, 0, [t["top"]]]], {"targetPlayerId": int(q), "roomIndex": int(t["g"])})
	return null

## CheckBMA048 Jeopardy (l.246-268) : moins de cartes en main que la moyenne entiere adverse - 1.
static func _chk_048(x: Dictionary) -> Variant:
	if _early(x):
		return null
	var avg := _opp_avg(x, func(q): return (q.get("hand", []) as Array).size())
	if float(((x["p"] as Dictionary).get("hand", []) as Array).size()) <= float(avg) - 1.0:
		return _res([[0, 0, _bosses(x["G"], prio_players(x["G"]))]])
	return null

## CheckBMA049 Kobold Strike (l.270-292) : donjon d'au moins moyenne entiere adverse + 1 salles.
static func _chk_049(x: Dictionary) -> Variant:
	if _early(x):
		return null
	var avg := _opp_avg(x, func(q): return _dungeon_size(_view(q)))
	if float(x["ds"]) >= float(avg) + 1.0:
		return _res([[0, 0, _bosses(x["G"], prio_players(x["G"]))]])
	return null

## CheckBMA050 Motivation (l.294-306) : au moins 2 salles de la main constructibles (Boss.CanBuildRoom, phase comprise) = coups buildRoom legaux de Godot.
## La condition de la carte (OpponnentDungeonSizeMoreThan(1)) est dans la legalite du moteur (SpellTargeting.conditions_ok) : `abilities` n'appelle ce
## CheckXXX que pour un playSpell legal.
static func _chk_050(x: Dictionary) -> Variant:
	if _early(x):
		return null
	var cards := {}
	for m in (x["moves"] as Array):
		if str((m as Dictionary).get("type", "")) == "buildRoom":
			cards[int(((m as Dictionary)["args"] as Array)[0])] = true
	if cards.size() < 2:
		return null
	return _res([[0, 0, [_boss_of(x["G"], int(x["pid"]))]]])

## CheckBMA051 Princess in Peril (l.308-343) : un heros de la ville que NOUS ne voulons pas laisser a un autre, et que notre donjon tue.
static func _chk_051(x: Dictionary) -> Variant:
	var G: Dictionary = x["G"]
	var pid := int(x["pid"])
	var town: Array = G.get("town", [])
	for i in town.size():
		var hero: Dictionary = town[i]
		var flag := false
		if str(hero.get("id", "")) == "BMA080":
			var souls: Dictionary = {}
			var mn := 2147483647
			for q in prio_players(G):
				souls[int(q)] = CardDB.total_souls(G["players"][int(q)], G)
				mn = mini(mn, int(souls[int(q)]))
			var low: Array = prio_players(G).filter(func(q): return int(souls[int(q)]) == mn)
			flag = low.size() == 1 and int(low[0]) != pid
		else:
			var b := _who_would_bait(G, hero)
			if int(b[0]) < 0 and CardDB.total_souls(x["p"], G) >= 8:
				flag = true
			elif int(b[0]) >= 0 and int(b[0]) != pid:
				flag = true
		if flag and hero_health(G, hero) - dungeon_damage(G, x["p"], pid) <= 0:
			return _res([[0, 0, [hero, _boss_of(G, pid)]]], {"townIndex": i})
	return null

## CheckBMA052 Soul Harvest (l.345-372) : Late ; moins de sorts en main que la moyenne adverse et une ame ordinaire a rendre.
static func _chk_052(x: Dictionary) -> Variant:
	if _early_mid(x):
		return null
	var p: Dictionary = x["p"]
	var avg := _opp_avg(x, func(q): return _hand_spells(q))
	if _hand_spells(p) < avg:
		var souls: Array = p.get("souls", [])
		for i in souls.size():
			var e: Dictionary = souls[i]
			if not bool(e.get("epic", false)) and not bool(e.get("tpk", false)):
				return _res([[0, 0, [e.get("hero", e)]], [0, 1, [_boss_of(x["G"], int(x["pid"]))]]], {"soulIndex": i})
	return null

## CheckBMA053 Teleportation (l.374-392) : Late ; heros dans NOTRE slot 0 avec des PV, mais « PV apres donjon <= 0 » est impossible (Take(0) = aucun degat
## restant, donc PV apres = PV > 0) : la carte n'est jamais jouee, comme dans l'APK.
static func _chk_053(x: Dictionary) -> Variant:
	if _early_mid(x):
		return null
	var ah: Dictionary = x["ah"]
	if not ah.is_empty() and int(ah["owner"]) == int(x["pid"]) and int(ah["c"]) == 0 and int(ah["hp"]) > 0:
		if _active_after(x, int(x["pid"])) <= 0:
			return _hero_entry(ah["hero"])
	return null

## CheckBMA054 Trepidation (l.394-418) : Late ; l'adversaire (le plus d'ames d'abord) a 2+ ames de plus que nous et un heros a l'entree.
static func _chk_054(x: Dictionary) -> Variant:
	if _early_mid(x):
		return null
	var G: Dictionary = x["G"]
	var mine := CardDB.total_souls(x["p"], G)
	var cand: Array = prio_players(G).filter(func(q): return CardDB.total_souls(G["players"][int(q)], G) >= mine + 2)
	for q in _stable(cand, func(q): return [-CardDB.total_souls(G["players"][int(q)], G)]):
		if not ((G["players"][int(q)] as Dictionary).get("entrance", []) as Array).is_empty():
			return _res([[0, 0, [_boss_of(G, int(q))]]], {"targetPlayerId": int(q)})
	return null

## CheckBMA055 Zombie Attack (l.420-444) : Late ; un heros epique des ames d'un adversaire (le plus d'ames d'abord, PV de base decroissants) que le donjon de
## cet adversaire ne tue pas a plus de 1 PV pres (InitialHealth - GetDungeonDamage(adversaire) > -2).
static func _chk_055(x: Dictionary) -> Variant:
	if _early_mid(x):
		return null
	var G: Dictionary = x["G"]
	for q in _stable(opponents(G, int(x["pid"])), func(q): return [-CardDB.total_souls(G["players"][int(q)], G)]):
		var qp: Dictionary = G["players"][int(q)]
		var heroes: Array = []
		var first_idx: Array = []
		var souls: Array = qp.get("souls", [])
		for i in souls.size():
			var e: Dictionary = souls[i]
			var h = e.get("hero")
			if bool(e.get("epic", false)) and h is Dictionary and not bool(e.get("tpk", false)) and not heroes.any(func(o): return is_same(o, h)):
				heroes.append(h)
				first_idx.append(i)
		var order: Array = range(heroes.size())
		order = _stable(order, func(k): return [-BossEngine.hero_base_hp(heroes[int(k)])])
		for k in order:
			var hh: Dictionary = heroes[int(k)]
			if BossEngine.hero_base_hp(hh) - dungeon_damage(G, qp, int(q)) > -2:
				return _res([[0, 0, [hh]]], {"targetPlayerId": int(q), "soulIndex": int(first_idx[int(k)]), "pile": "souls"})
	return null

## CheckKSA013 T.P.K. (l.822-827) : toujours, sur tous les joueurs (le moteur retient le premier : voir `abilities`).
static func _chk_ksa013(x: Dictionary) -> Variant:
	var pl := prio_players(x["G"])
	return _res([[0, 0, _bosses(x["G"], pl)]], {"targetPlayerId": int(pl[0])} if not pl.is_empty() else null)

# --- CheckXXX : capacites de salle --------------------------------------------------------------------------------------------

## AIHelper.HasRoomBelow : la salle du slot g recouvre une autre (pile de plus d'une carte).
static func _room_below(x: Dictionary, g: int) -> bool:
	return ((x["p"] as Dictionary)["dungeon"][g] as Array).size() > 1

## CheckBMA009 Dark Altar (l.446-482) : les defausses ne sont pas vides ; Mid : l'Autel recouvre une salle ; Late : donjon de 5 salles.
## Cible : la meilleure salle batissable de la defausse qui vaut plus que l'Autel, ou un sort au hasard, pile ou face s'il y a les deux.
static func _chk_009(x: Dictionary, g: int) -> Variant:
	if _early(x):
		return null
	var G: Dictionary = x["G"]
	var decks: Dictionary = G.get("decks", {})
	var rooms: Array = decks.get("roomDiscard", [])
	var spells: Array = decks.get("spellDiscard", [])
	if rooms.is_empty() and spells.is_empty():
		return null
	if x["ph"] == "mid":
		if not _room_below(x, g):
			return null
	elif int(x["ds"]) <= 4:
		return null
	var altar: Dictionary = BossEngine.active_room((x["p"] as Dictionary)["dungeon"][g])
	var altar_v := _val0(x, altar)
	var cands: Array = rooms.filter(func(r): return _can_build_card(G, x["p"], int(x["pid"]), r) and _val0(x, r) > altar_v)
	cands = _stable(cands, func(r): return [-_val0(x, r), _discard_rank(r)])
	var room2 = cands[0] if not cands.is_empty() else null
	var rng: RandomNumberGenerator = x["rng"]
	var spell = spells[rng.randi_range(0, spells.size() - 1)] if not spells.is_empty() else null
	var pick = null
	if room2 != null and spell == null:
		pick = room2
	elif room2 == null and spell != null:
		pick = spell
	elif room2 != null and spell != null:
		pick = room2 if rng.randi_range(0, 1) == 1 else spell
	if pick == null:
		return null
	return _res([[0, 0, [altar]], [1, 0, [pick]], [1, 1, [_boss_of(G, int(x["pid"]))]]], null, spell != null)

## CheckBMA013 Dracolich Lair (l.557-605) : 2+ salles en main et la defausse en a une batissable ; on defausse 2 salles inutiles (non batissables, sinon les
## moins precieuses) si la meilleure de la defausse vaut plus que la 2e plus faible de la main.
static func _chk_013(x: Dictionary, _g: int) -> Variant:
	var G: Dictionary = x["G"]
	var p: Dictionary = x["p"]
	var pid := int(x["pid"])
	var hand_rooms: Array = (p.get("hand", []) as Array).filter(func(c): return bool((c as Dictionary).get("isRoom", false)))
	var disc: Array = (G.get("decks", {}) as Dictionary).get("roomDiscard", [])
	if hand_rooms.size() < 2 or disc.is_empty():
		return null
	var cands: Array = disc.filter(func(r): return _can_build_card(G, p, pid, r))
	cands = _stable(cands, func(r): return [-_val0(x, r), _discard_rank(r)])
	if cands.is_empty():
		return null
	var room: Dictionary = cands[0]
	var useless: Array = hand_rooms.filter(func(r): return not _can_build_card(G, p, pid, r))
	var source: Array = []
	if useless.size() >= 2:
		source = _stable(useless, func(r): return [_val0(x, r)]).slice(0, 2)
	else:
		var s3 := _stable(hand_rooms, func(r): return [_val0(x, r)])
		if _val0(x, room) > _val0(x, s3[1]):
			source = s3.slice(0, 2)
	if source.is_empty():
		return null
	return _res([[0, 0, source], [1, 0, [room]], [1, 1, [_boss_of(G, pid)]]])

## CheckBMA024 Witch's Kitchen (l.484-523) : une Monster de la main (la moins precieuse ; a valeur egale la batissable d'abord : deux `orderby` successifs) a
## defausser et moins de 2 sorts en main.
static func _chk_024(x: Dictionary, _g: int) -> Variant:
	if _early(x):
		return null
	var G: Dictionary = x["G"]
	var p: Dictionary = x["p"]
	var pid := int(x["pid"])
	var mons: Array = (p.get("hand", []) as Array).filter(func(c): return bool((c as Dictionary).get("isRoom", false)) and str((c as Dictionary).get("type", "")) == "monster")
	var src := _stable(mons, func(r): return [_val0(x, r), 0 if _can_build_card(G, p, pid, r) else 1])
	if not src.is_empty() and _hand_spells(p) < 2:
		return _res([[0, 0, [src[0], _boss_of(G, pid)]]])
	return null

## CheckBMA027 Bottomless Pit (l.525-545) : le heros est dans CE gouffre et survivrait au reste du donjon.
static func _chk_027(x: Dictionary, g: int) -> Variant:
	if _early(x):
		return null
	var pid := int(x["pid"])
	if _lured_by(x, pid, g) and _active_after(x, pid) > 0:
		return _res([[0, 0, [BossEngine.active_room((x["p"] as Dictionary)["dungeon"][g]), (x["ah"] as Dictionary)["hero"]]]])
	return null

## AIHelper.HasHeroPassedSlot (l.172-189) : le slot d'index C# `c_slot` est derriere le heros (index plus grand : le heros descend vers le boss).
static func _passed(ah: Dictionary, c_slot: int) -> bool:
	return c_slot > int(ah["c"])

## CheckBMA028 Boulder Ramp (l.547-596) : Late ; le heros est dans CETTE rampe et survit au reste ; on detruit la salle la moins utile (avancee d'abord, puis pas
## encore traversee, puis moins de degats, puis pile la plus haute) si +5 degats l'acheveraient (PV <= degats restants + 5).
static func _chk_028(x: Dictionary, g: int) -> Variant:
	if _early_mid(x):
		return null
	var pid := int(x["pid"])
	if not _lured_by(x, pid, g):
		return null
	var G: Dictionary = x["G"]
	var p: Dictionary = x["p"]
	var ah: Dictionary = x["ah"]
	var num := dungeon_damage(G, p, pid, int(ah["c"]))
	if int(ah["hp"]) <= num:
		return null
	var src: Array = []
	for c in (x["view"] as Array).size():
		var s: Dictionary = (x["view"] as Array)[c]
		if s["top"] != null and not BossEngine.is_room_deactivated(G, pid, int(s["g"])) and str((s["top"] as Dictionary).get("id", "")) != "BMA028":
			src.append({"c": c, "g": int(s["g"]), "top": s["top"]})
	if src.is_empty():
		return null
	var best: Dictionary = _stable(src, func(s): return [0 if bool((s["top"] as Dictionary).get("advanced", false)) else 1, 1 if _passed(ah, int(s["c"])) else 0,
		_slot_damage(G, p, int(s["g"])), -((p["dungeon"][int(s["g"])] as Array).size())])[0]
	if _passed(ah, int(best["c"])):
		num -= _slot_damage(G, p, int(best["g"]))
		var st: Array = p["dungeon"][int(best["g"])]
		if st.size() > 1:
			num += room_damage(st[st.size() - 2] as Dictionary)
	num += 5
	if int(ah["hp"]) <= num:
		return _res([[0, 0, [best["top"], ah["hero"]]]], int(best["g"]))
	return null

## Donjon dont ne restent que les salles visibles (Boss.GetDungeonTreasures exclut les slots en attente).
static func _shown_only(p: Dictionary) -> Dictionary:
	var shown: Array = []
	for stack in p.get("dungeon", []):
		var top = BossEngine.active_room(stack)
		if top != null and not bool((top as Dictionary).get("faceDown", false)):
			shown.append(stack)
	var q := p.duplicate()
	q["dungeon"] = shown
	return q

## BMA030Logic (l.882-918) : plus de heros de la ville que NOUS ne leurrons pas deviendraient attires par nous (tresors des salles doubles) et tues, que de
## heros que nous attirons deja et tuons.
static func _bma030_logic(x: Dictionary, g: int) -> bool:
	var G: Dictionary = x["G"]
	var p: Dictionary = x["p"]
	var pid := int(x["pid"])
	var mine := 0
	var gain := 0
	var town: Array = G.get("town", [])
	for h in town:
		var b := _who_would_bait(G, h)
		if int(b[0]) == pid and BossEngine.hero_health_with_modifiers(G, h) - dungeon_damage(G, p, pid) <= 0:
			mine += 1
	var stack: Array = p["dungeon"][g]
	var bt: Array = (p.get("boss", {}) as Dictionary).get("treasures", []) as Array
	# GetDungeonTreasures = salles ++ boss ++ passifs ; GetDungeonTreasuresOfType retire les |boss.Treasures| DERNIERS : les tresors du boss (Godot les range en tete).
	var rooms_only: Array = BossEngine.dungeon_treasures(_shown_only(p), G).slice(bt.size() + (p.get("bonusTreasures", []) as Array).size())
	for h in town:
		var b := _who_would_bait(G, h)
		if int(b[0]) == pid:
			continue
		var item := int(b[1])
		var htr: Array = CardDB.hero_treasures(h)
		var n3 := 0
		for t in htr:
			n3 += _count_treasure(rooms_only, int(t))
		if htr.any(func(t): return int(t) == 4): # Thief
			n3 -= 2
		if stack.size() > 1:
			for t in htr:
				n3 += _count_treasure((stack[stack.size() - 2] as Dictionary).get("treasures", []), int(t))
		n3 *= 2
		for t in htr:
			n3 += _count_treasure(bt, int(t))
		if n3 > item:
			var dd := dungeon_damage(G, p, pid) - _slot_damage(G, p, g)
			if stack.size() > 1:
				dd += room_damage(stack[stack.size() - 2] as Dictionary)
			if dd >= BossEngine.hero_health_with_modifiers(G, h):
				gain += 1
	return gain > mine

## CheckBMA030 Jackpot Stash (l.598-612) : hors Setup/Early, en phase de construction, si BMA030Logic.
static func _chk_030(x: Dictionary, g: int) -> Variant:
	if _early(x):
		return null
	if str((x["G"] as Dictionary).get("phase", "")) == CardDB.PHASE["BUILD"] and _bma030_logic(x, g):
		return _res([[0, 0, [BossEngine.active_room((x["p"] as Dictionary)["dungeon"][g]), _boss_of(x["G"], int(x["pid"]))]]])
	return null

## CheckBMA038 Torture Chamber (l.614-636) : Late ; un adversaire qui a une salle batissable en main (le meilleur score d'abord).
static func _chk_038(x: Dictionary, g: int) -> Variant:
	if _early_mid(x):
		return null
	var G: Dictionary = x["G"]
	var cand: Array = []
	for q in opponents(G, int(x["pid"])):
		var qp: Dictionary = G["players"][int(q)]
		var hand: Array = qp.get("hand", [])
		for hi in hand.size():
			if bool((hand[hi] as Dictionary).get("isRoom", false)) and can_build_anywhere(G, qp, int(q), hi):
				cand.append(int(q))
				break
	if cand.is_empty():
		return null
	var first: int = _stable(cand, func(q): return [-(CardDB.total_souls(G["players"][int(q)], G) - CardDB.total_wounds(G["players"][int(q)]))])[0]
	return _res([[0, 0, [BossEngine.active_room((x["p"] as Dictionary)["dungeon"][g]), _boss_of(G, first)]]])

## CheckBMA039 Zombie Prison (l.638-672) : Mid avec une pile sous la prison -> non ; l'adversaire (meilleur score d'abord) avec des ames dont un heros (PV de base
## decroissants) depasse les degats de SON propre donjon.
static func _chk_039(x: Dictionary, g: int) -> Variant:
	if _early(x):
		return null
	if x["ph"] == "mid" and _room_below(x, g):
		return null
	var G: Dictionary = x["G"]
	var cand: Array = opponents(G, int(x["pid"])).filter(func(q): return CardDB.total_souls(G["players"][int(q)], G) > 0)
	for q in _stable(cand, func(q): return [-(CardDB.total_souls(G["players"][int(q)], G) - CardDB.total_wounds(G["players"][int(q)]))]):
		var qp: Dictionary = G["players"][int(q)]
		var dd := dungeon_damage(G, qp, int(q))
		var heroes: Array = []
		for e in (qp.get("souls", []) as Array):
			var h = (e as Dictionary).get("hero")
			if h is Dictionary and not bool((e as Dictionary).get("tpk", false)) and not heroes.any(func(o): return is_same(o, h)):
				heroes.append(h)
		for hh in _stable(heroes, func(h): return [-BossEngine.hero_base_hp(h)]):
			if dd < BossEngine.hero_base_hp(hh):
				return _res([[0, 0, [BossEngine.active_room((x["p"] as Dictionary)["dungeon"][g]), hh]]])
	return null

## CheckBMA025 All-Seeing Eye (l.674-704) : Spell Battle ; un sort adverse en attente dont une commande designe directement NOTRE boss ; on defausse Jeopardy,
## puis Kobold Strike, sinon un sort jouable (a defaut le premier) : choix legal mais etrange, copie fidelement.
static func _chk_025(x: Dictionary, _g: int) -> Variant:
	var p: Dictionary = x["p"]
	var G: Dictionary = x["G"]
	var pid := int(x["pid"])
	var hand: Array = p.get("hand", [])
	var spells_in_hand: Array = []
	for hi in hand.size():
		if bool((hand[hi] as Dictionary).get("isSpell", false)):
			spells_in_hand.append(hi)
	if spells_in_hand.is_empty():
		return null
	for e in _stack_spells_of_others(x):
		var ed: Dictionary = e
		var id := str((ed.get("card", {}) as Dictionary).get("id", ""))
		var direct: Array = []
		match id: # GetCommandTargets() : cibles qui SONT des boss (pas leurs proprietaires)
			"BMA048", "BMA049", "KSA013":
				direct = prio_players(G)
			"BMA050", "BMA051", "BMA052":
				direct = [int(ed.get("playerId", -1))]
			"BMA054":
				direct = [int((ed["target"] as Dictionary).get("targetPlayerId", -1))] if ed.get("target") is Dictionary else []
		if not direct.has(pid):
			continue
		var pick := -1
		for want in ["BMA048", "BMA049"]:
			for hi in spells_in_hand:
				if pick < 0 and str((hand[int(hi)] as Dictionary).get("id", "")) == want:
					pick = int(hi)
			if pick >= 0:
				break
		if pick < 0:
			var sm := _spell_moves(x)
			var playable: Array = spells_in_hand.filter(func(hi): return sm.has(int(hi)))
			pick = int(playable[0]) if not playable.is_empty() else int(spells_in_hand[0])
		return _res([[0, 0, [hand[pick]]], [1, 0, [ed["card"]]]])
	return null

## CheckBMA032 Crushinator (l.706-770) : des heros de l'entree (PV de base > degats du donjon) nous blesseraient ; detruire une de nos salles (pas la sienne)
## en reduirait le nombre de blessures.
static func _chk_032(x: Dictionary, g: int) -> Variant:
	var G: Dictionary = x["G"]
	var p: Dictionary = x["p"]
	var pid := int(x["pid"])
	var ent: Array = p.get("entrance", [])
	if ent.is_empty():
		return null
	var dd := dungeon_damage(G, p, pid)
	var num := 0
	for h in ent:
		if BossEngine.hero_base_hp(h) > dd:
			num += BossEngine.hero_wounds(h)
	if num <= 0:
		return null
	var flag := false
	var slot: Dictionary = {}
	var actives := _active_slots(x)
	if (CardDB.total_wounds(p) >= 5 - num and not CardDB.big_game(G)) or CardDB.total_souls(p, G) >= 10 - num: # 5-6 joueurs : pas d'elimination par blessures
		var src: Array = actives.filter(func(s): return int((s as Dictionary)["g"]) != g)
		if not src.is_empty():
			slot = _stable(src, func(s): return [0 if bool((s["top"] as Dictionary).get("advanced", false)) else 1, -((p["dungeon"][int(s["g"])] as Array).size())])[0]
			flag = true
	var plain: Array = actives.filter(func(s): return not bool((s["top"] as Dictionary).get("advanced", false)))
	if not plain.is_empty():
		slot = _stable(plain, func(s): return [_slot_damage(G, p, int(s["g"])), BossEngine.room_treasures(s["top"] as Dictionary).size()])[0]
		flag = true
	if not flag:
		return null
	dd -= _slot_damage(G, p, int(slot["g"]))
	var n3 := actives.size()
	var st: Array = p["dungeon"][int(slot["g"])]
	if st.size() <= 1:
		n3 -= 1
	else:
		dd += room_damage(st[st.size() - 2] as Dictionary)
	dd += n3 * 2
	var num2 := 0
	for h in ent:
		if hero_health(G, h) > dd:
			num2 += BossEngine.hero_wounds(h)
	if num2 < num:
		return _res([[0, 0, [slot["top"], _boss_of(G, pid)]]], int(slot["g"]))
	return null

# --- ensemble des capacites eligibles ----------------------------------------------------------------------------------------

## Index de main des sorts qui ont un coup `playSpell` legal.
static func _spell_moves(x: Dictionary) -> Dictionary:
	var out := {}
	for m in (x["moves"] as Array):
		if str((m as Dictionary).get("type", "")) == "playSpell":
			out[int(((m as Dictionary)["args"] as Array)[0])] = true
	return out

## Les cles de `want` valent-elles les memes champs de la cible Godot `tg` ?
static func _target_has(tg: Variant, want: Dictionary) -> bool:
	if not (tg is Dictionary):
		return false
	for k in want:
		if (tg as Dictionary).get(k) != want[k]:
			return false
	return true

## AbilityCalculator.CalculateAbilityAndTargetValue (switch l.30-58) : resultat non nul = capacite eligible (valeur 1.0).
static func _spell_check(x: Dictionary, id: String) -> Variant:
	if bool(x["battle"]): # l.22-30 : en Spell Battle seule BMA043 est evaluee (BMA025 est une salle)
		return _chk_043(x) if id == "BMA043" else null
	match id:
		"BMA040": return _chk_040_047(x, "trap")
		"BMA041": return _chk_041(x)
		"BMA042": return _chk_042(x)
		"BMA044": return _chk_044(x)
		"BMA045": return _chk_045(x)
		"BMA046": return _chk_046(x)
		"BMA047": return _chk_040_047(x, "monster")
		"BMA048": return _chk_048(x)
		"BMA049": return _chk_049(x)
		"BMA050": return _chk_050(x)
		"BMA051": return _chk_051(x)
		"BMA052": return _chk_052(x)
		"BMA053": return _chk_053(x)
		"BMA054": return _chk_054(x)
		"BMA055": return _chk_055(x)
		"KSA013": return _chk_ksa013(x)
	return null

static func _room_check(x: Dictionary, id: String, g: int) -> Variant:
	if bool(x["battle"]):
		return _chk_025(x, g) if id == "BMA025" else null
	match id:
		"BMA009": return _chk_009(x, g)
		"BMA013": return _chk_013(x, g)
		"BMA024": return _chk_024(x, g)
		"BMA027": return _chk_027(x, g)
		"BMA028": return _chk_028(x, g)
		"BMA030": return _chk_030(x, g)
		"BMA032": return _chk_032(x, g)
		"BMA038": return _chk_038(x, g)
		"BMA039": return _chk_039(x, g)
	return null

## GetUsableAbilities + CalculateAbilityStatistics : les capacites ELIGIBLES du joueur `pid` (cartes de l'APK), dans l'ordre du C# (salles du fond a l'entree, puis
## sorts de la main). `moves` = coups legaux de Godot (= CanPlayerPlayAbility). Une entree : {kind: "room"|"spell", idx: index de main / de pile, card, t: cibles
## preregles [[effet, fournisseur, [cartes]]], move: coup Godot qui porte cette cible (null si Godot ne la propose pas), shuf: la cible vient d'un tirage}.
## Lecture seule sur `G`. `rng` : tirages internes (Shuffle, NextBool).
static func abilities(G: Dictionary, pid: int, moves: Array, rng: RandomNumberGenerator) -> Array:
	var out: Array = []
	if not (G["players"] as Dictionary).has(pid):
		return out
	var x := _ctx(G, pid, moves, rng)
	var p: Dictionary = x["p"]
	var spell_mv: Dictionary = {}
	var room_mv: Dictionary = {}
	for m in moves:
		var md: Dictionary = m
		var a: Array = md.get("args", [])
		match str(md.get("type", "")):
			"playSpell":
				if not a.is_empty():
					spell_mv.get_or_add(int(a[0]), []).append(md)
			"activateRoom":
				if not a.is_empty():
					room_mv.get_or_add(int(a[0]), []).append(md)
	var view: Array = x["view"]
	for c in view.size():
		var g := int((view[c] as Dictionary)["g"])
		var top = (view[c] as Dictionary)["top"]
		if top == null or not room_mv.has(g): # DungeonActiveRooms (slot actif, hors salle posee ce tour) est dans la legalite du moteur (RoomAbilities.activate_room_ability)
			continue
		var id := str((top as Dictionary).get("id", ""))
		if is_wiki_card(id):
			continue
		var r = _room_check(x, id, g)
		if r == null:
			continue
		var mv: Variant = null
		for m in (room_mv[g] as Array):
			var ma: Array = (m as Dictionary)["args"]
			if r["arg"] == null or (ma.size() > 1 and int(ma[1]) == int(r["arg"])):
				mv = m
				break
		out.append({"kind": "room", "idx": g, "card": top, "t": r["t"], "move": mv, "shuf": bool(r["shuf"])})
	var hand: Array = p.get("hand", [])
	for hi in hand.size():
		var card: Dictionary = hand[hi]
		if not bool(card.get("isSpell", false)) or not spell_mv.has(hi) or is_wiki_card(str(card.get("id", ""))):
			continue
		var sid := str(card.get("id", ""))
		var r = _spell_check(x, sid)
		if r == null:
			continue
		var mv: Variant = null
		for m in (spell_mv[hi] as Array):
			var ma: Array = (m as Dictionary)["args"]
			if r["arg"] == null or _target_has(ma[1] if ma.size() > 1 else null, r["arg"] as Dictionary):
				mv = m
				break
		if mv == null and sid == "KSA013": # le C# designe tous les boss et retient le premier ; Godot n'offre (hors harnais) que le proprietaire
			mv = (spell_mv[hi] as Array)[0]
		out.append({"kind": "spell", "idx": hi, "card": card, "t": r["t"], "move": mv, "shuf": bool(r["shuf"])})
	return out

# ======================================================================================================================
# Etape 3 : CIBLES de declencheurs et de commandes. Sources (apk-original/decompiled/DBMGame/) :
#  - DBMGameProject.AI.Statistics/TriggerCalculator.cs : switch par carte (l.50-141, `default` = liste VIDE : l'IA ne designe rien) ;
#  - DBMGameProject.AI/StatisticAI.cs l.72-98 (SelectTriggerTargets / SelectCommandTargets) + StatisticsCalculator.cs l.90-111 : un fournisseur SIMPLE
#    (SingleTargetProvider) dont le nombre de cibles <= TargetsAmount est pris tel quel (le moteur Godot l'auto-resout) ; les fournisseurs COMPOSES
#    (CardInHand, RoomInHand, SpellInHand, RoomInDungeon, HeroInScorekeep) passent par TriggerCalculator ;
#  - DBMGameProject.Services.PlayerInteraction/AIPlayerInteraction.cs l.45-74 : une capacite que l'IA vient de tirer (`abilitySelected`) fournit
#    ses cibles preregles (AbilityCalculator, etape 2) ; seules les autres cibles passent par TriggerCalculator.
# Les niveaux de boss (LevelUpAbility) suivent le meme chemin. FixedAI.SelectTriggerTargets deleguait a StatisticAI (aucun tri propre).
# Ecarts ASSUMES (bogues du C#, pas des regles) : le cache `resolvingCard` / `selectedTargets` (l.22-27, l.40-45, l.143-149) rend des cibles PERIMEES (liste d'une autre
# carte ou deja consommee : Mimic Vault et Open Grave 2e fois, tout CheckXXX qui ne remet pas `resolvingCard` a null) -> chaque choix est calcule a neuf ;
# Succubus Spa (CheckBMA012) renvoie `player` pour le fournisseur BossOpponent (l'ordre des listes est inverse) -> on prend l'adversaire que la carte designe.
# Copies fideles de choix legaux mais etranges : Open Grave recupere d'abord une salle NON batissable (orderby sur un booleen), Kaw'nee prend le heros de
# plus de PV de base (CalculateHeroValuetoSteal : `Intersect` n'est jamais nul), Xyzax peut viser deux fois la meme salle.
# Tirages (`Shuffle()`, WaveServices.Random) : le RNG de la partie Godot ; ils sont signales (`shuf`) pour que la mesure les compte a part.
# BMA033 Centipede Tunnel (CheckBMA033) n'est pas porte : la carte n'est jamais distribuee (CardInfoService.notInGameCards), aucun choix ne peut s'ouvrir.
# ======================================================================================================================

## Cartes dont l'IA a tire la capacite (etape 2) : le choix suivant de la meme carte lit les cibles preregles (`sel`, voir AI.remember).
const TR_ACTIVATED := {"Dracolich Lair": "BMA013", "Dark Altar": "BMA009", "Witch's Kitchen": "BMA024", "All-Seeing Eye": "BMA025",
	"Torture Chamber": "BMA038", "Zombie Prison": "BMA039"}

## Reponse de l'IA a un choix en attente : {"idx": indice de l'option (-1 = ne rien designer), "shuf": la cible vient d'un tirage} ou null
## (carte hors APK, cible introuvable parmi les options : l'appelant garde son ancien comportement).
## `sel` = entree de ApkAI.abilities que l'IA a tiree (cibles preregles), `memo` = liste calculee au premier choix d'une carte a deux choix (Xyzax).
static func choose(G: Dictionary, pid: int, pc: Dictionary, rng: RandomNumberGenerator, sel: Dictionary = {}, memo: Dictionary = {}) -> Variant:
	var opts: Array = pc.get("options", [])
	if opts.is_empty() or not (G["players"] as Dictionary).has(pid):
		return null
	var x := _ctx(G, pid, [], rng)
	var name := str(pc.get("bossName", ""))
	if TR_ACTIVATED.has(name):
		return _tr_activated(x, pc, opts, sel, name)
	match name:
		"Draculord": return _tr_001(x, opts)
		"Xyzax": return _tr_002(x, pc, opts, memo)
		"King Croak", "Cleopatra": return _tr_003_007(x, opts)
		"Robobo": return _tr_004(x, opts)
		"Cerebellus", "Dark Laboratory": return _tr_005_022(x, opts)
		"Seducia": return _tr_006(x, opts)
		"Gorgona": return _tr_008(x, opts)
		"Open Grave": return _tr_010(x, opts)
		"Specter's Sanctum": return _tr_011_012(x, opts, false)
		"Succubus Spa": return _tr_011_012(x, opts, true)
		"Vampire Bordello": return _tr_014(x, opts)
		"Mimic Vault": return _tr_036(x, opts)
		"Monstrous Monument": return _tr_037(x, opts)
		"Hellcow": return _tr_ksa002(x, pc, opts)
		"The Brothers Wise": return _tr_ksa003(x, opts)
		"Kaw'nee": return _tr_ksa004(opts)
	return null

# --- outils ----------------------------------------------------------------------------------------------------------------

## Meme carte : meme objet, ou meme instance du harnais (`_oid`).
static func _same(a: Variant, b: Variant) -> bool:
	if a == null or b == null:
		return false
	if is_same(a, b):
		return true
	return a is Dictionary and b is Dictionary and (a as Dictionary).has("_oid") and (b as Dictionary).has("_oid") and int((a as Dictionary)["_oid"]) == int((b as Dictionary)["_oid"])

static func _opt_of(opts: Array, card: Variant, key := "card") -> int:
	for i in opts.size():
		if _same((opts[i] as Dictionary).get(key), card):
			return i
	return -1

static func _out(idx: int, shuf := false) -> Dictionary:
	return {"idx": idx, "shuf": shuf}

## Reponse pour la carte `card` (null = le C# ne designe rien : abstention) ; null si la carte n'est pas parmi les options.
static func _pick_card(opts: Array, card: Variant, shuf := false) -> Variant:
	if card == null:
		return _out(-1, shuf)
	var i := _opt_of(opts, card)
	return _out(i, shuf) if i >= 0 else null

## Premier element de `list` qui est une option (une carte deja prise n'en est plus une).
static func _pick_first(opts: Array, list: Array, shuf := false) -> Variant:
	for c in list:
		var i := _opt_of(opts, c)
		if i >= 0:
			return _out(i, shuf)
	return null

## Cartes des options (cle `card`).
static func _opt_cards(opts: Array) -> Array:
	return opts.map(func(o): return (o as Dictionary)["card"])

## Enumerable.Shuffle() (RandomProvider.cs:43-62) : Fisher-Yates paresseux depuis la fin, `k` elements pris ; aucun tirage si la liste n'en a qu'un.
static func _shuffle_take(x: Dictionary, arr: Array, k: int) -> Array:
	var a := arr.duplicate()
	var out: Array = []
	var i := a.size() - 1
	while i > 0 and out.size() < k:
		var j := (x["rng"] as RandomNumberGenerator).randi_range(0, i)
		var t = a[i]
		a[i] = a[j]
		a[j] = t
		out.append(a[i])
		i -= 1
	if out.size() < k and not a.is_empty() and i == 0:
		out.append(a[0])
	return out

## Cartes de la main d'un joueur : sorts (`spell`) ou salles.
static func _hand_cards(q: Dictionary, spell: bool) -> Array:
	return (q.get("hand", []) as Array).filter(func(c): return bool((c as Dictionary).get("isSpell", false)) == spell)

static func _score(G: Dictionary, q: int) -> int:
	return CardDB.total_souls(G["players"][q], G) - CardDB.total_wounds(G["players"][q])

## Adversaires avec des sorts (`spells_only`) ou des cartes en main, `orderby Score descending, SpellsInHand.Count descending` (tri stable).
static func _opps_by_score(x: Dictionary, spells_only: bool) -> Array:
	var G: Dictionary = x["G"]
	var cand: Array = opponents(G, int(x["pid"])).filter(func(q):
		var h: Dictionary = G["players"][int(q)]
		return (_hand_spells(h) > 0) if spells_only else ((h.get("hand", []) as Array).size() > 0))
	return _stable(cand, func(q): return [-_score(G, int(q)), -_hand_spells(G["players"][int(q)])])

## `OrderByDescending(CalculateValue(checkModifiers: false))` ; egalite -> ordre d'origine (puis rang d'instance pour la defausse).
static func _by_value_desc(x: Dictionary, rooms: Array) -> Array:
	return _stable(rooms, func(r): return [-_val0(x, r), _discard_rank(r)])

static func _buildable(x: Dictionary, rooms: Array) -> Array:
	return rooms.filter(func(r): return _can_build_card(x["G"], x["p"], int(x["pid"]), r))

## Rang d'une option dans l'ordre du C# : la ville puis les pioches de heros, les pioches de cartes puis les defausses. Godot range chaque pioche sommet en DERNIER
## (draw = pop_back) alors que le C# enumere DeckHeroes / DeckRooms / DeckSpells du sommet vers le fond : on inverse les pioches ; les defausses gardent leur ordre.
static func _cs_rank(o: Dictionary) -> Array:
	if str(o.get("source", "")) == "town":
		return [0, int(o.get("townIndex", 0))]
	if str(o.get("source", "")) == "deck":
		return [1 if str(o.get("pile", "heroes")) == "heroes" else 2, -int(o.get("deckIndex", 0))]
	if str(o.get("pile", "")) == "deck":
		return [0, -int(o.get("pileIndex", 0))]
	return [1, int(o.get("pileIndex", 0))]

## Indices de `opts` dans l'ordre du C# (voir _cs_rank).
static func _cs_order(opts: Array) -> Array:
	return _stable(range(opts.size()), func(i): return _cs_rank(opts[int(i)]))

## Indice (parmi `opts`) du premier element dans l'ordre de tri `keyf(option)`.
static func _best_opt(opts: Array, keyf: Callable) -> int:
	return int(_stable(_cs_order(opts), func(i): return keyf.call(opts[int(i)]))[0])

# --- TriggerCalculator.cs : une fonction par carte ----------------------------------------------------------------------------

## CheckBMA001 Draculord (l.354-396) : l'adversaire au meilleur score (puis le plus de sorts) qui a une carte ; un de ses sorts AU HASARD, sinon sa salle batissable
## de plus grande valeur, sinon sa salle de plus grande valeur.
static func _tr_001(x: Dictionary, opts: Array) -> Variant:
	var G: Dictionary = x["G"]
	var ord := _opps_by_score(x, false)
	var pick = null
	var shuf := false
	for q in ord:
		var sp := _hand_cards(G["players"][int(q)], true)
		shuf = shuf or sp.size() >= 2
		var t := _shuffle_take(x, sp, 1)
		if not t.is_empty():
			pick = t[0]
			break
	if pick == null:
		for q in ord:
			var rooms := _hand_cards(G["players"][int(q)], false)
			var best := _by_value_desc(x, _buildable(x, rooms))
			if best.is_empty():
				best = _by_value_desc(x, rooms)
			if not best.is_empty():
				pick = best[0]
				break
	return _pick_card(opts, pick, shuf)

## CheckBMA002 Xyzax (l.398-416) : 2 sorts de la defausse au hasard, sinon (ou en complement) ses salles batissables par valeur, sinon ses salles par valeur (la meme
## salle peut revenir deux fois). Godot ouvre un choix par carte : la liste est calculee au premier et reprise au second (`memo`).
static func _tr_002(x: Dictionary, pc: Dictionary, opts: Array, memo: Dictionary) -> Variant:
	var G: Dictionary = x["G"]
	var decks: Dictionary = G.get("decks", {})
	var list: Array
	var shuf := false
	if int(pc.get("remaining", 1)) < 2 and memo.has("Xyzax"):
		list = memo["Xyzax"]["list"]
		shuf = bool(memo["Xyzax"]["shuf"])
	else:
		var spells: Array = decks.get("spellDiscard", [])
		var rooms: Array = decks.get("roomDiscard", [])
		shuf = spells.size() >= 2
		list = _shuffle_take(x, spells, 2)
		if list.size() < 2:
			list.append_array(_by_value_desc(x, _buildable(x, rooms)).slice(0, 2 - list.size()))
		if list.size() < 2:
			list.append_array(_by_value_desc(x, rooms).slice(0, 2 - list.size()))
		memo["Xyzax"] = {"list": list, "shuf": shuf}
	return _pick_first(opts, list, shuf)

## CheckBMA003 King Croak / CheckBMA007 Cleopatra (l.418-435, 478-495) : parmi les salles avancees du type (pioche et defausse), celles que l'on peut batir ;
## la plus precieuse. Aucune batissable : le C# ne designe rien.
static func _tr_003_007(x: Dictionary, opts: Array) -> Variant:
	var cand := _cs_order(opts).filter(func(i): return not _buildable(x, [(opts[int(i)] as Dictionary)["card"]]).is_empty())
	var best := _stable(cand, func(i): return [-_val0(x, (opts[int(i)] as Dictionary)["card"])])
	return _out(int(best[0])) if not best.is_empty() else _out(-1)

## CheckBMA004 Robobo (l.437-449) : `player` = l'adversaire qui detruit : sa salle avancee d'abord, la moins precieuse (DungeonActiveRooms, ordre du fond a l'entree).
static func _tr_004(x: Dictionary, opts: Array) -> Variant:
	var slots := _active_slots(x)
	if slots.is_empty():
		return _out(-1)
	var best: Dictionary = _stable(slots, func(s): return [0 if bool((s["top"] as Dictionary).get("advanced", false)) else 1, _val0(x, s["top"])])[0]
	for i in opts.size():
		var o: Dictionary = opts[i]
		if int(o.get("targetPlayerId", -1)) == int(x["pid"]) and int(o.get("roomIndex", -1)) == int(best["g"]):
			return _out(i)
	return null

## SelectSpellToDiscard (l.638-646) : Jeopardy / Kobold Strike d'abord, sinon un sort au hasard.
static func _select_spell_to_discard(x: Dictionary) -> Dictionary:
	var sp := _hand_cards(x["p"], true)
	for c in sp:
		if ["BMA048", "BMA049"].has(str((c as Dictionary).get("id", ""))):
			return {"card": c, "shuf": false}
	var t := _shuffle_take(x, sp, 1)
	return {"card": t[0] if not t.is_empty() else null, "shuf": sp.size() >= 2}

## CheckBMA005 Cerebellus (l.451-457) / CheckBMA022 Dark Laboratory (l.219-225) : SelectSpellToDiscard.
static func _tr_005_022(x: Dictionary, opts: Array) -> Variant:
	var d := _select_spell_to_discard(x)
	return _pick_card(opts, d["card"], bool(d["shuf"]))

## CheckBMA006 Seducia (l.459-476) : heros de la ville puis de la pioche dont les PV sont <= aux degats de notre donjon, le plus d'ames ; sinon rien (facultatif).
static func _tr_006(x: Dictionary, opts: Array) -> Variant:
	var G: Dictionary = x["G"]
	var dmg := dungeon_damage(G, x["p"], int(x["pid"]))
	var cand: Array = _cs_order(opts).filter(func(i): return hero_health(G, (opts[int(i)] as Dictionary)["card"]) <= dmg)
	if cand.is_empty():
		return _out(-1)
	return _out(int(_stable(cand, func(i): return [-BossEngine.hero_souls((opts[int(i)] as Dictionary)["card"])])[0]))

## CheckBMA008 Gorgona (l.497-513) : `orderby Souls descending orderby CurrentHealth - damage descending` : PV restants apres NOTRE donjon, le plus haut ; a egalite, le plus d'ames.
static func _tr_008(x: Dictionary, opts: Array) -> Variant:
	var G: Dictionary = x["G"]
	var dmg := dungeon_damage(G, x["p"], int(x["pid"]))
	return _out(_best_opt(opts, func(o): return [-(hero_health(G, (o as Dictionary)["card"]) - dmg), -BossEngine.hero_souls((o as Dictionary)["card"])]))

## CheckBMA010 Open Grave (l.151-162) : `orderby CanBuildRoom, value descending` : une salle NON batissable d'abord (False < True), puis la plus precieuse.
static func _tr_010(x: Dictionary, opts: Array) -> Variant:
	var G: Dictionary = x["G"]
	return _out(_best_opt(opts, func(o):
		var r: Dictionary = (o as Dictionary)["card"]
		return [1 if _can_build_card(G, x["p"], int(x["pid"]), r) else 0, -_val0(x, r), _discard_rank(r)]))

## CheckBMA011 Specter's Sanctum (l.164-182) : l'adversaire avec des sorts au meilleur score (puis le plus de sorts), sinon le premier adversaire.
## CheckBMA012 Succubus Spa (l.184-201, `spa`) : idem avec des cartes quelconques (l'APK renvoie ici `player` pour BossOpponent : voir l'en-tete).
static func _tr_011_012(x: Dictionary, opts: Array, spa: bool) -> Variant:
	var ord := _opps_by_score(x, not spa)
	var opps := opponents(x["G"], int(x["pid"]))
	var who := int(ord[0]) if not ord.is_empty() else (int(opps[0]) if not opps.is_empty() else -1)
	for i in opts.size():
		if int((opts[i] as Dictionary).get("targetPlayerId", -2)) == who:
			return _out(i)
	return null

## CheckBMA014 Vampire Bordello (l.319-328) : le heros de nos blessures qui rapporte le plus d'ames.
static func _tr_014(x: Dictionary, opts: Array) -> Variant:
	if CardDB.total_wounds(x["p"]) <= 0:
		return _out(-1)
	return _out(_best_opt(opts, func(o): return [-BossEngine.hero_souls((o as Dictionary)["card"])]))

## CheckBMA036 Mimic Vault (l.290-303) : le premier heros ordinaire de la ville que l'IA n'attire pas seule et que NOTRE donjon tue ; sinon rien.
static func _tr_036(x: Dictionary, opts: Array) -> Variant:
	var G: Dictionary = x["G"]
	var dmg := dungeon_damage(G, x["p"], int(x["pid"]))
	for i in _cs_order(opts):
		var h: Dictionary = (opts[int(i)] as Dictionary)["card"]
		if not bool(h.get("epic", false)) and int(_who_would_bait(G, h)[0]) != int(x["pid"]) and hero_health(G, h) <= dmg:
			return _out(int(i))
	return _out(-1)

## CheckBMA037 Monstrous Monument (l.305-317) : la salle Monster de la defausse de plus grande valeur.
static func _tr_037(x: Dictionary, opts: Array) -> Variant:
	var best := _by_value_desc(x, _opt_cards(opts))
	return _pick_card(opts, best[0] if not best.is_empty() else null)

## CheclKSA003 The Brothers Wise (l.575-588) : le sort de la pioche de plus grande valeur (CalculateSpellValue, AbilityCalculator.cs:954-972 : KSA013 > BMA051 > BMA043 >
## BMA046 > BMA045, les autres valent 1 / Random.Next(1, 100), un tirage chacun).
static func _tr_ksa003(x: Dictionary, opts: Array) -> Variant:
	var order := ["KSA013", "BMA051", "BMA043", "BMA046", "BMA045"]
	var idx := -1
	var top := -1.0
	var shuf := false
	for i in _cs_order(opts):
		var at := order.find(str(((opts[int(i)] as Dictionary)["card"] as Dictionary).get("id", "")))
		var v := float(order.size() - at) if at >= 0 else 1.0 / float((x["rng"] as RandomNumberGenerator).randi_range(1, 99))
		shuf = shuf or at < 0
		if v > top:
			top = v
			idx = int(i)
	return _out(idx, shuf)

## CheclKSA004 Kaw'nee (l.590-607) : le heros mort (adversaires) de plus de PV de base (CalculateHeroValuetoSteal = InitialHealth - 40 : `Intersect` n'est jamais nul).
static func _tr_ksa004(opts: Array) -> Variant:
	return _out(_best_opt(opts, func(o): return [-BossEngine.hero_base_hp((o as Dictionary)["card"] as Dictionary)]))

## CheclKSA002 Hellcow (l.515-573) : le donjon de l'adversaire au meilleur score ; ordre voulu des salles (BMA014 d'abord ; les pieges ordinaires, BMA015 inseree apres le
## premier d'entre eux ; Dizzygas apres les pieges ; le reste dans l'ordre). Godot ouvre un choix par salle, du fond a l'entree.
static func _tr_ksa002(x: Dictionary, pc: Dictionary, opts: Array) -> Variant:
	var G: Dictionary = x["G"]
	if str(pc.get("step", "")) == "dungeon":
		var best := _stable(opponents(G, int(x["pid"])), func(q): return [-_score(G, int(q))])
		var who := int(best[0]) if not best.is_empty() else -1
		for i in opts.size():
			if int((opts[i] as Dictionary).get("targetPlayerId", -2)) == who:
				return _out(i)
		return null
	var tops: Array = []
	for s in _view(G["players"][int(pc.get("targetPlayerId", -1))]):
		if (s as Dictionary)["top"] != null:
			tops.append(s["top"])
	var want: Array = []
	var gob = null
	var diz = null
	var bordello = null
	var traps: Array = []
	for r in tops:
		var id := str((r as Dictionary).get("id", ""))
		if id == "BMA014" and bordello == null:
			bordello = r
		elif id == "BMA015" and gob == null:
			gob = r
		elif id == "BMA029" and diz == null:
			diz = r
		if str((r as Dictionary).get("type", "")) == "trap" and id != "BMA029":
			traps.append(r)
	if bordello != null:
		want.append(bordello)
	if gob != null:
		if not traps.is_empty():
			want.append(traps[0])
		want.append(gob)
		want.append_array(traps.slice(1))
	else:
		want.append_array(traps)
	if diz != null:
		want.append(diz)
	for r in tops:
		if not want.any(func(w): return is_same(w, r)):
			want.append(r)
	return _pick_first(opts, want)

# --- capacites que l'IA vient de tirer : cibles preregles (AbilitySelectedInformation.GetSelectedTargets) ----------------------------

static func _t_cards(sel: Dictionary, effect: int, provider: int) -> Array:
	for e in (sel.get("t", []) as Array):
		if int((e as Array)[0]) == effect and int((e as Array)[1]) == provider:
			return (e as Array)[2]
	return []

static func _pid_of_boss(G: Dictionary, boss: Variant) -> int:
	for q in (G["players"] as Dictionary):
		if is_same((G["players"][q] as Dictionary).get("boss"), boss):
			return int(q)
	return -1

## Choix ouvert par une capacite de salle tiree par l'IA : on lit les cibles de CheckBMA009 / 013 / 024 / 025 / 038 / 039 (`sel`).
static func _tr_activated(x: Dictionary, pc: Dictionary, opts: Array, sel: Dictionary, name: String) -> Variant:
	if sel.is_empty() or str((sel.get("card", {}) as Dictionary).get("id", "")) != str(TR_ACTIVATED[name]):
		return null
	var shuf := bool(sel.get("shuf", false))
	match name:
		"Dracolich Lair": # les 2 salles a defausser (effet 0), puis la salle de la defausse (effet 1)
			if str(pc.get("type", "")) != "dracolich-discard":
				return _pick_first(opts, _t_cards(sel, 1, 0), shuf)
			var want := _t_cards(sel, 0, 0)
			var hand: Array = x["p"].get("hand", [])
			for i in opts.size():
				var pair: Array = []
				for hi in ((opts[i] as Dictionary).get("handIndices", []) as Array):
					if int(hi) >= 0 and int(hi) < hand.size():
						pair.append(hand[int(hi)])
				if pair.size() == want.size() and want.all(func(w): return pair.any(func(c): return _same(c, w))):
					return _out(i, shuf)
		"Dark Altar": # la carte de la defausse (effet 1)
			return _pick_first(opts, _t_cards(sel, 1, 0), shuf)
		"Witch's Kitchen", "All-Seeing Eye": # la carte de la main a defausser
			return _pick_first(opts, _t_cards(sel, 0, 0), shuf)
		"Torture Chamber": # le boss designe (2e cible de l'effet 0)
			var tb := _t_cards(sel, 0, 0)
			var who := _pid_of_boss(x["G"], tb[1]) if tb.size() > 1 else -1
			for i in opts.size():
				if int((opts[i] as Dictionary).get("targetPlayerId", -2)) == who:
					return _out(i, shuf)
		"Zombie Prison": # le heros mort (2e cible de l'effet 0)
			return _pick_first(opts, _t_cards(sel, 0, 0).slice(1), shuf)
	return null
