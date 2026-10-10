extends Node
## CardDB — autoload. Miroir de src/backend/game/cardData.js (référence à supprimer).
## Charge godot/data/cards.json (copie de cardData.json, 156 Ko).

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

func get_card_data(card_id: String) -> CardData:
	if _card_data_cache.has(card_id):
		return _card_data_cache[card_id]
	for list in [bosses, rooms, spells, heroes, items, minibosses]:
		for c in list:
			if str((c as Dictionary).get("id", "")) == card_id:
				var res = CardData.from_dict(c)
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

## Chemin d'image carte, miroir de getWikiCardImage/getApkCardImage (web: /cards/...).
static func card_image(id: String, kind: String, mapped_name: String = "") -> String:
	var prefix := id.to_upper()
	var nm := mapped_name if mapped_name != "" else prefix
	if kind == "back-room":
		return "res://assets/cards/backs/back_room.webp"
	if kind == "back-boss":
		return "res://assets/cards/backs/back_boss.webp"
	if kind == "back-spell":
		return "res://assets/cards/backs/back_spell.webp"
	if kind == "back-hero":
		return "res://assets/cards/backs/back_hero.webp"
	var file := prefix + "_" + nm + ".webp"
	match kind:
		"boss":
			return "res://assets/cards/bosses/" + file
		"room":
			return "res://assets/cards/rooms/" + file
		"spell":
			return "res://assets/cards/spells/" + file
		"hero", "epic-hero":
			return "res://assets/cards/heroes/" + file
		"item":
			return "res://assets/cards/items/" + file
	return "res://assets/cards/rooms/" + file

static func total_souls(p: Dictionary) -> int:
	var n := 0
	for s in p.get("souls", []):
		if (s as Dictionary).get("tpk", false):
			continue
		n += int((s as Dictionary).get("souls", 1))
	n += int(p.get("bonusSouls", 0))
	return n

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
