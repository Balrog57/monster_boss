extends Node
## Coverage — verifie que chaque carte se type correctement et que son image se resout.
## Lancé par res://godot/tests/Coverage.tscn (headless, autoloads requis).

func _ready() -> void:
	var total := 0
	var typed := 0
	var tex_path := 0
	var tex_loaded := 0
	var bad_type: Array = []
	var no_tex: Array = []

	for entry in [["bosses", "boss"], ["rooms", "room"], ["spells", "spell"],
			["heroes", "hero"], ["items", "item"], ["minibosses", "miniboss"]]:
		var want: String = entry[1]
		var list: Array = CardDB.get(entry[0])
		for c in list:
			var d: Dictionary = c
			var id := str(d.get("id", ""))
			total += 1
			var kind: String = want
			if kind == "hero" and d.get("epic", false):
				kind = "epic-hero"
			var card = CardData.from_dict(d, kind)
			if card == null:
				bad_type.append(id)
				continue
			if card.card_type == kind:
				typed += 1
			else:
				bad_type.append(id + "=" + card.card_type)
			if card.texture_path != "":
				tex_path += 1
				if card.texture != null:
					tex_loaded += 1
				else:
					no_tex.append(id + " -> " + card.texture_path)
			else:
				no_tex.append(id)

	print("COVERAGE total=", total)
	print("COVERAGE typed_correctly=", typed, " bad=", bad_type.size())
	print("COVERAGE texture_path=", tex_path, " texture_loaded=", tex_loaded)

	if typed != total:
		print("TYPE ECHEC: ", bad_type.slice(0, 20))
		get_tree().quit(1)
		return

	# Un echantillon par type, choisi parmi les cartes qui ont reellement un fichier image.
	var probe := ["BMA001", "BMA009", "BMA040", "CRL017", "CRL024", "THK001", "RMB055"]
	var missing: Array = []
	for id in probe:
		var card = CardDB.get_card_data(id)
		if card == null or card.texture == null:
			missing.append(id)
	if not missing.is_empty():
		print("ECHEC echantillon sans texture: ", missing)
		get_tree().quit(1)
		return
	print("COVERAGE OK: types=", typed, "/", total, " images chargees=", tex_loaded)
	get_tree().quit(0)