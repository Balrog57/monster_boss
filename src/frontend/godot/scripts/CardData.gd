class_name CardData
extends Resource
## Modèle de données pour une carte Boss Monster (Resource Godot 4).
## Permet l'instanciation, l'enregistrement en .tres et l'inspection dans l'éditeur.

@export var id: String = ""
@export var title: String = ""
@export var subtitle: String = ""
@export var card_type: String = "" # "boss", "room", "hero", "epic-hero", "spell", "item"
@export var is_advanced: bool = false
@export var treasure_type: Array = [] # [1=Cleric, 2=Fighter, 3=Mage, 4=Thief]
@export var damage: int = 0
@export var health: int = 0
@export var souls: int = 1
@export var wounds: int = 1
@export var xp: int = 0
@export var description_text: String = ""
@export var texture_path: String = ""
@export var texture: Texture2D = null
@export var effect_script: String = ""

## kind_hint : type reel de la collection source ("boss","room","spell","hero","epic-hero","item","miniboss").
## Les cles de cards.json ne suffisent pas : les salles portent type "trap"/"monster" (jamais "room"),
## les heros exposent "hp" (pas "health"), et sorts/objets/miniboss n'ont aucun marqueur.
static func from_dict(d: Dictionary, kind_hint: String = "") -> Resource:
	var c = load("res://godot/scripts/CardData.gd").new()
	c.id = str(d.get("id", d.get("cardNumber", d.get("CardNumber", ""))))
	c.title = str(d.get("name", d.get("Name", "")))
	c.subtitle = str(d.get("subtitle", d.get("Subtitle", "")))
	c.card_type = kind_hint if kind_hint != "" else str(d.get("type", d.get("card_type", "")))
	if c.card_type == "":
		if d.get("isRoom", false) or d.has("Damage") or d.has("damage"):
			c.card_type = "room"
		elif d.has("XP") or d.has("xp"):
			c.card_type = "boss"
		elif d.has("hp") or d.has("health") or d.has("Health"):
			c.card_type = "hero"
		elif d.get("isSpell", false):
			c.card_type = "spell"
		elif d.get("isItem", false):
			c.card_type = "item"
		else:
			c.card_type = "room"
	c.is_advanced = bool(d.get("isAdvanced", d.get("IsAdvanced", d.get("advanced", false))))
	c.treasure_type = d.get("treasures", d.get("Treasures", []))
	c.damage = int(d.get("damage", d.get("Damage", 0)))
	c.health = int(d.get("hp", d.get("health", d.get("Health", 0))))
	c.souls = int(d.get("souls", d.get("Souls", 1)))
	c.wounds = int(d.get("wounds", d.get("Wounds", 1)))
	c.xp = int(d.get("xp", d.get("XP", 0)))
	c.description_text = str(d.get("description", d.get("Description", "")))
	c.effect_script = str(d.get("effectScript", d.get("effect_script", "")))

	# Résolution texture : CardDB est un autoload (Node du arbre), pas un singleton Engine.
	var tree := Engine.get_main_loop() as SceneTree
	var db := tree.root.get_node_or_null("CardDB") if tree != null else null
	if db != null:
		c.texture_path = db.card_image(c.id, c.card_type)
		if c.texture_path != "" and ResourceLoader.exists(c.texture_path):
			c.texture = load(c.texture_path)
	return c
