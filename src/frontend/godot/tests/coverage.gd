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
	if not no_tex.is_empty() or tex_loaded != total:
		print("ECHEC cartes sans image chargee (", no_tex.size(), "): ", no_tex.slice(0, 20))
		get_tree().quit(1)
		return
	var faces := _in_game_faces()
	if not faces.is_empty():
		print("ECHEC face de carte en jeu (CardData.from_dict sans indice de type) sans image: ", faces.slice(0, 20))
		get_tree().quit(1)
		return
	var tiles := _expansion_tiles()
	if not tiles.is_empty():
		print("ECHEC tuiles « SELECT EXPANSIONS » : ", tiles)
		get_tree().quit(1)
		return
	var bad_flags := _implemented_flags()
	if not bad_flags.is_empty():
		print("ECHEC drapeaux `implemented` de cards.json faux (lancer `python tools/sync_implemented.py`) : ", bad_flags.slice(0, 20))
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

# --- faces de cartes telles que le jeu les construit -----------------------------------------------------------------------------

## Le plateau cree ses cartes a partir des dictionnaires de la partie (salles via Match._room_card, sorts `isSpell`, objets `isItem`...), SANS l'indice de type
## de la collection : l'image doit se retrouver quand meme (CardDB.card_image cherche dans tous les dossiers du wiki). Renvoie les ids sans image.
func _in_game_faces() -> Array:
	var missing: Array = []
	var match_script = load("res://godot/scripts/Match.gd")
	for entry in [["bosses", ""], ["rooms", "room"], ["spells", "spell"], ["heroes", ""], ["items", "item"], ["minibosses", "room"]]:
		for c in CardDB.get(entry[0]):
			var d: Dictionary = (c as Dictionary).duplicate(true)
			match str(entry[1]):
				"room":
					d = match_script._room_card(d)
				"spell":
					d["isSpell"] = true
				"item":
					d["isItem"] = true
			var card = CardData.from_dict(d)
			if card == null or card.texture == null:
				missing.append(str(d.get("id", "?")))
	return missing

# --- tuiles de l'ecran SELECT EXPANSIONS (Main.gd) ------------------------------------------------------------------------------------

## Les paquets du wiki annoncent leur contenu (« 13 bosses, 43 rooms, ... ») : les nombres doivent etre ceux de cards.json. Renvoie les ecarts.
func _expansion_tiles() -> Array:
	var errors: Array = []
	var consts: Dictionary = (load("res://godot/scripts/Main.gd") as GDScript).get_script_constant_map()
	var wiki: Array = consts["EXT_PACKS"]
	var re := RegEx.new()
	re.compile("(\\d+) (bosses|rooms|spells|heroes|minibosses)")
	var seen: Array = []
	for d in consts["APK_DECKS"]:
		var id := str((d as Dictionary)["id"])
		if not wiki.has(id):
			continue
		seen.append(id)
		var counts := {"bosses": 0, "rooms": 0, "spells": 0, "heroes": 0, "minibosses": 0}
		for key in counts:
			for c in CardDB.get(key):
				if str((c as Dictionary).get("set", "")) == id:
					counts[key] += 1
		var announced := {}
		for m in re.search_all(str((d as Dictionary).get("info", ""))):
			announced[m.get_string(2)] = int(m.get_string(1))
		for key in counts:
			if int(announced.get(key, 0)) != int(counts[key]):
				errors.append("%s : %s annonce %d, cards.json en a %d" % [id, key, int(announced.get(key, 0)), int(counts[key])])
	for id in wiki:
		if not seen.has(id):
			errors.append("%s : pas de tuile dans APK_DECKS" % id)
	return errors

# --- drapeaux `implemented` -----------------------------------------------------------------------------------------------------------------

## Memes regles que tools/sync_implemented.py : une carte est « implementee » si son id (ou la commande de son level-up / de son heros) apparait entre guillemets
## dans un script du moteur, ou si son texte ne porte aucune capacite. Renvoie les cartes dont le drapeau ment (absent ou faux/vrai a tort) ;
## affiche les cartes sans implementation (objets / salles Tools of Hero Kind : jouees par ThkAbilities derriere la case wiki ; l'APK ne les fait pas agir).
func _implemented_flags() -> Array:
	var words := {}
	var re := RegEx.new()
	re.compile("\"([A-Za-z0-9]+)\"")
	for name in ["Match", "BossEngine", "RoomAbilities", "SpellEffects", "SpellTargeting", "TnlAbilities", "TnlSpells", "RmbAbilities", "RmbSpells", "Minibosses", "ThkAbilities", "CardDB"]:
		var f := FileAccess.open("res://godot/scripts/%s.gd" % name, FileAccess.READ)
		if f == null:
			return ["script introuvable : " + name]
		for m in re.search_all(f.get_as_text()):
			words[m.get_string(1)] = true
	var liars: Array = []
	var none: Array = []
	for section in ["bosses", "rooms", "spells", "heroes", "items", "minibosses"]:
		for c in CardDB.get(section):
			var d: Dictionary = c
			var want := _has_handler(section, d, words)
			if not want:
				none.append(str(d.get("id", "")))
			if not d.has("implemented") or bool(d["implemented"]) != want:
				liars.append("%s (implemented=%s, moteur=%s)" % [str(d.get("id", "")), str(d.get("implemented")), str(want)])
	print("COVERAGE cartes sans implementation (", none.size(), ") : ", none)
	return liars

func _has_handler(section: String, d: Dictionary, words: Dictionary) -> bool:
	var id := str(d.get("id", ""))
	if section == "items":
		return words.has(id)
	if section == "minibosses":
		return words.has(id)
	if section == "heroes":
		var ha = d.get("heroAbility")
		var cmd = (ha as Dictionary).get("cmd") if ha is Dictionary else null
		var lure = d.get("lure")
		return (cmd == null or words.has(str(cmd))) and (lure == null or words.has(str(lure)) or str(lure) == "treasures")
	if section == "bosses":
		var lu = d.get("levelUp")
		var lcmd = (lu as Dictionary).get("cmd") if lu is Dictionary else null
		return words.has(id) or (lcmd != null and words.has(str(lcmd)))
	var t := str(d.get("description", d.get("levelUpDesc", ""))).strip_edges()
	return words.has(id) or t == "" or (t.begins_with("(") and t.ends_with(")"))
