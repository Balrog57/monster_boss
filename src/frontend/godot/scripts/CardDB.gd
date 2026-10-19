extends Node
## CardDB — autoload. Charge godot/data/cards.json (source unique des cartes).

const CardData = preload("res://godot/scripts/CardData.gd")

const PHASE := {
	"BOSS": "boss",
	"SETUP": "setup",
	"BEGINNING": "beginning",
	"BUILD": "build",
	"BAIT": "bait",
	"ADVENTURE": "adventure",
	"END": "end",
}

const TREASURE_NAMES := ["?", "Cleric", "Fighter", "Mage", "Thief", "Explorer"]
const DUNGEON_SLOTS := 5
const HERO_COUNTS := {2: {"ordinary": 13, "epic": 8}, 3: {"ordinary": 17, "epic": 12}, 4: {"ordinary": 25, "epic": 16}}

var bosses: Array = []
var rooms: Array = []
var spells: Array = []
var heroes: Array = []
var items: Array = []
var minibosses: Array = []
var name_map: Dictionary = {}

var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()
	load_cards()

func load_cards(path: String = "res://godot/data/cards.json") -> void:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("CardDB: impossible d'ouvrir " + path)
		return
	var data: Dictionary = JSON.parse_string(f.get_as_text())
	bosses = data.get("bosses", [])
	rooms = data.get("rooms", [])
	spells = data.get("spells", [])
	heroes = data.get("heroes", [])
	items = data.get("items", [])
	minibosses = data.get("minibosses", [])
	name_map = data.get("nameMap", {})

var _card_data_cache: Dictionary = {}

func get_card_data(card_id: String) -> Resource:
	if _card_data_cache.has(card_id):
		return _card_data_cache[card_id]
	for entry in [["bosses", "boss"], ["rooms", "room"], ["spells", "spell"],
			["heroes", "hero"], ["items", "item"], ["minibosses", "miniboss"]]:
		var list: Array = get(entry[0])
		for c in list:
			var d: Dictionary = c
			if str(d.get("id", "")) != card_id:
				continue
			# heroes: epic -> "epic-hero" (dossier distinct)
			var kind: String = entry[1]
			if kind == "hero" and d.get("epic", false):
				kind = "epic-hero"
			var res = CardData.from_dict(d, kind)
			_card_data_cache[card_id] = res
			return res
	return null

static func expanded_deck(cards: Array) -> Array:
	var out: Array = []
	for c in cards:
		var qty := int((c as Dictionary).get("quantity", 1))
		for i in qty:
			out.append((c as Dictionary).duplicate())
	return out

func shuffled(arr: Array) -> Array:
	var a := arr.duplicate()
	for i in range(a.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var t = a[i]
		a[i] = a[j]
		a[j] = t
	return a

static func draw_cards(deck: Array, count: int) -> Array:
	var drawn: Array = []
	for i in count:
		if deck.is_empty():
			break
		drawn.append(deck.pop_back())
	return drawn

static func refill_from_discard(deck: Array, discard: Array, rng: RandomNumberGenerator) -> void:
	if not deck.is_empty() or discard.is_empty():
		return
	while not discard.is_empty():
		deck.append(discard.pop_back())
	for i in range(deck.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = deck[i]
		deck[i] = deck[j]
		deck[j] = t

## GameBoard.DrawRooms / DrawSpells : a CHAQUE carte, pioche vide => ReShuffleDiscardsPilesBackToDeck remet les DEUX defausses
## (salles ET sorts) dans leurs pioches et melange les deux. Pioche d'effet (DrawCards) et pioche de debut de tour passent par ici.
static func draw_pile(decks: Dictionary, pile: String, n: int, rng: RandomNumberGenerator = null) -> Array:
	var deck: Array = decks.get(pile, [])
	decks[pile] = deck
	var out: Array = []
	for _i in n:
		if deck.is_empty():
			for pr in [["rooms", "roomDiscard"], ["spells", "spellDiscard"]]:
				var d: Array = decks.get(pr[0], [])
				var disc: Array = decks.get(pr[1], [])
				while not disc.is_empty():
					d.append(disc.pop_back())
				for i in range(d.size() - 1, 0, -1):
					var j := rng.randi_range(0, i) if rng != null else randi_range(0, i) # sans rng : alea global (seed() des soaks)
					var t = d[i]
					d[i] = d[j]
					d[j] = t
				decks[pr[0]] = d
				decks[pr[1]] = disc
			deck = decks[pile]
		if deck.is_empty():
			break
		out.append(deck.pop_back())
	return out

## Chemin d'image carte, miroir de getWikiCardImage/getApkCardImage (web: /cards/...).
## Priorité : textures authentiques de l'APK (res://assets/apk_cards/), puis wiki (res://assets/cards/).
func card_image(id: String, kind: String) -> String:
	# 1. Dos de carte
	match kind:
		"back-room":
			if ResourceLoader.exists("res://assets/apk_cards/base/back_room.webp"):
				return "res://assets/apk_cards/base/back_room.webp"
			return "res://assets/cards/backs/back_room.webp"
		"back-boss":
			if ResourceLoader.exists("res://assets/apk_cards/base/back_boss.webp"):
				return "res://assets/apk_cards/base/back_boss.webp"
			return "res://assets/cards/backs/back_boss.webp"
		"back-spell":
			if ResourceLoader.exists("res://assets/apk_cards/base/back_spell.webp"):
				return "res://assets/apk_cards/base/back_spell.webp"
			return "res://assets/cards/backs/back_spell.webp"
		"back-hero":
			if ResourceLoader.exists("res://assets/apk_cards/base/back_ordinary_hero.webp"):
				return "res://assets/apk_cards/base/back_ordinary_hero.webp"
			return "res://assets/cards/backs/back_hero.webp"
		"back-epic":
			if ResourceLoader.exists("res://assets/apk_cards/base/back_epic_hero.webp"):
				return "res://assets/apk_cards/base/back_epic_hero.webp"
			return "res://assets/cards/backs/back_hero.webp"

	if id == "":
		return ""

	# 2. Recherche prioritaire dans les textures authentiques de l'APK (res://assets/apk_cards/)
	var stem := id.to_lower()
	for folder in ["base", "hidden", "playerchoice", "tools"]:
		var p1 := "res://assets/apk_cards/%s/%s.webp" % [folder, stem]
		if ResourceLoader.exists(p1):
			return p1
		var p2 := "res://assets/apk_cards/%s/%sa.webp" % [folder, stem]
		if ResourceLoader.exists(p2):
			return p2

	# 3. Fallback sur les textures du wiki (res://assets/cards/)
	var prefix := id.to_upper()
	var nm: String = str(name_map.get(prefix, prefix))
	var file := prefix + "_" + nm + ".webp"
	match kind:
		"boss":
			var p := "res://assets/cards/bosses/" + file
			if ResourceLoader.exists(p): return p
		"room":
			var p := "res://assets/cards/rooms/" + file
			if ResourceLoader.exists(p): return p
		"spell":
			var p := "res://assets/cards/spells/" + file
			if ResourceLoader.exists(p): return p
		"hero":
			var p := "res://assets/cards/heroes/" + file
			if ResourceLoader.exists(p): return p
		"epic-hero":
			var p := "res://assets/cards/epic-heroes/" + file
			if ResourceLoader.exists(p): return p
		"item":
			var p := "res://assets/cards/items/" + file
			if ResourceLoader.exists(p): return p
		"miniboss":
			var p := "res://assets/cards/minibosses/" + file
			if ResourceLoader.exists(p): return p

	# 4. Fallback dans tous les sous-dossiers wiki
	for k in ["rooms", "bosses", "heroes", "epic-heroes", "spells", "items", "minibosses"]:
		var p := "res://assets/cards/%s/%s" % [k, file]
		if ResourceLoader.exists(p):
			return p

	return "res://assets/cards/rooms/" + file

## Boss.Souls = ames des heros du scorekeeping + CalculatePassiveSouls. Les passifs viennent du level-up du boss
## (AddSoulsToBoss, KSA006) et des sorts « jusqu'a la fin de la partie » deja poses (AddSoulsToBossIfTreasures, T.P.K. :
## le bonus se juge sur le scorekeeping de la CIBLE du sort, voir SpellEffects._tpk). `G` donne acces aux autres joueurs.
static func total_souls(p: Dictionary, G: Dictionary = {}) -> int:
	var n := 0
	for s in p.get("souls", []):
		if (s as Dictionary).get("tpk", false):
			continue
		n += int((s as Dictionary).get("souls", 1))
	n += int(p.get("bonusSouls", 0))
	return n + passive_souls(p, G)

static func passive_souls(p: Dictionary, G: Dictionary = {}) -> int:
	var n := 0
	var boss = p.get("boss")
	if boss is Dictionary and bool(p.get("leveledUp", false)):
		var lus: Array = (p.get("copiedLevelUps", []) as Array).duplicate() # CRL002 Klonos : level-ups copies
		lus.append((boss as Dictionary).get("levelUp"))
		for lu in lus:
			if lu is Dictionary and str((lu as Dictionary).get("cmd", "")) == "AddSoulsToBoss":
				n += int(((lu as Dictionary).get("args", ["0"]) as Array)[0])
	for sp in (p.get("untilEndSpells", []) as Array):
		var ab = ((sp as Dictionary).get("card", {}) as Dictionary).get("ability")
		if not (ab is Dictionary) or str((ab as Dictionary).get("cmd", "")) != "AddSoulsToBossIfTreasures":
			continue
		var tp: Dictionary = p
		var players = G.get("players")
		if players is Dictionary and (players as Dictionary).has(int((sp as Dictionary).get("target", -1))):
			tp = (players as Dictionary)[int((sp as Dictionary)["target"])]
		var args: Array = (ab as Dictionary).get("args", [])
		var all := true
		for a in args.slice(1):
			var t := int(TREASURE_NAMES.find(str(a)))
			var found := false
			for s in (tp.get("souls", []) as Array):
				for x in ((s as Dictionary).get("treasures", []) as Array):
					found = found or int(x) == t # JSON : 3.0 ; Array.has(3) ne compare pas int a float
				if found:
					break
			all = all and found
		if all:
			n += int(args[0])
	return n

## Entree de scorekeeping d'une ame (Boss.SoulsHeroes) : le heros mort (Zombie Prison, KSA004) et ses classes de tresor (T.P.K.).
static func soul_entry(hero: Dictionary) -> Dictionary:
	return {
		"name": hero.get("name", "?"), "souls": 1, "class": hero.get("class", ""), "faceDown": true,
		"hero": hero, # identite du heros mort (Zombie Prison BMA039)
		"treasures": hero_treasures(hero), "epic": bool(hero.get("epic", false)),
	}

## BMH0xx (Hidden Heroes) = memes cartes que BMA0xx (ReplacesCardNumber) : les regles se lisent sur l'identite de base.
static func base_id(id: String) -> String:
	return "BMA" + id.substr(3) if id.begins_with("BMH") else id

## Condition de leurre d'un heros (HeroInfo.LuredCondition) : "treasures" (defaut), "fewerSouls" (The Fool) ou "wounds".
static func hero_lure(hero: Dictionary) -> String:
	if hero.has("lure"):
		return str(hero["lure"])
	return "fewerSouls" if base_id(str(hero.get("id", ""))) == "BMA080" else "treasures"

## Tresors du heros (HeroInfo.Treasures : une ou deux classes, 0 pour The Fool / Demigod).
static func hero_treasures(hero: Dictionary) -> Array:
	if hero.has("treasures"):
		return hero["treasures"]
	return [int(hero.get("treasure", 1))]

static func total_wounds(p: Dictionary) -> int:
	var n := 0
	for w in p.get("wounds", []):
		n += int((w as Dictionary).get("wounds", 1))
	return n

static func order_by_xp(players: Dictionary) -> Array:
	var arr: Array = []
	for pid in players:
		var p: Dictionary = players[pid]
		if (p as Dictionary).get("eliminated", false):
			continue
		arr.append({"pid": int(pid), "xp": int((p as Dictionary).get("boss", {}).get("xp", 0))})
	arr.sort_custom(func(a, b): return a["xp"] > b["xp"] if a["xp"] != b["xp"] else a["pid"] < b["pid"])
	var out: Array = []
	for e in arr:
		out.append(e["pid"])
	return out

# Fenetre de jeu de chaque sort du base set = condition DuringPhase de son Ability (BaseDeck/data.json,
# DuringPhase.cs : "Build" = BuildPhase_a seule, "Adventure" = AdventurePhase_a/b/c). SpellCategory n'est PAS
# une phase (Freeze est categorie 2 mais sans condition : jouable partout ; Fear/Teleportation categorie 1 : aventure).
# "any" = aucune condition de phase (Ability.CheckConditions ne bloque que Setup_b).
const SPELL_PHASE := {
	"BMA040": "adventure", "BMA041": "adventure", "BMA042": "adventure", "BMA043": "any",
	"BMA044": "adventure", "BMA045": "adventure", "BMA046": "any", "BMA047": "adventure",
	"BMA048": "any", "BMA049": "build", "BMA050": "build", "BMA051": "build",
	"BMA052": "any", "BMA053": "adventure", "BMA054": "adventure", "BMA055": "build",
	"KSA013": "any", # T.P.K. : aucune condition (Ability.CheckConditions ne bloque que Setup_b)
}

static func can_play_spell(card: Dictionary, phase: String, stack_len: int = 0) -> bool:
	var cid := str(card.get("id", ""))
	if (cid == "BMA043" or cid == "RMB077") and stack_len == 0:
		return false # Counterspell / Short Circuit : exigent un sort adverse en attente (SpellCardJustPlayed)
	if cid == "THK025":
		return bool(card.get("thkLive", false)) # ToolsHeroKind : Ability nulle dans data.json (CheckConditions exige >= 1 effet) -> jamais jouable dans l'APK ; seule la case wiki la rend jouable (n'importe quand)
	if SPELL_PHASE.has(cid):
		var w: String = SPELL_PHASE[cid]
		return w == phase or (w == "any" and (phase == PHASE["BUILD"] or phase == PHASE["ADVENTURE"]))
	var cat := int(card.get("category", 0))
	if cat == 4 or cat == 5:
		return phase == PHASE["BUILD"] or phase == PHASE["ADVENTURE"]
	if cat == 1 or cat == 2:
		return phase == PHASE["BUILD"]
	if cat == 3:
		return phase == PHASE["ADVENTURE"]
	return false
