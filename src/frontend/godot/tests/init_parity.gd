extends Node
## Parite d'INITIALISATION Godot <-> APK (lot L1, R-D15 / T-A07) : pour chaque trace oracle (`oracle-*.json`), Godot cree la partie avec la MEME graine
## (Match.new_match(n, 0, paquets, graine) : tous les sieges IA, comme l'oracle) et ecrit `init-<trace>.json` : boss des sieges, rang PlayerId, pioches avant
## distribution, mains d'ouverture avant defausse, pioches apres distribution (mulligan compris). La comparaison est faite par tools/parity/apk.py (`initParity`).
##
## Usage : godot --headless --path src/frontend res://godot/tests/InitParity.tscn -- --traces=<dossier absolu>

const SETS := {"BaseDeck": "base", "PlayerChoice": "players-choice", "HiddenHeros": "hidden-heroes", "ToolsHeroKind": "tools"}

func _traces_dir() -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--traces="):
			return a.substr(len("--traces="))
	return ""

## [carte, UniqueID, est un sort] ; les heros et les objets n'ont pas d'UniqueID cote Godot (0).
func _c(card: Dictionary) -> Array:
	return [str(card.get("id", "")), int(card.get("_uid", 0)), bool(card.get("isSpell", false))]

## Tete de file d'abord : la tete de la Queue de l'APK est le DERNIER element du tableau Godot ; les ordinaires precedent les epiques (OrderBy HeroType).
func _snapshot(decks: Dictionary) -> Dictionary:
	var heroes: Array = (decks["heroes"] as Array).duplicate()
	heroes.reverse()
	var epics: Array = (decks["epics"] as Array).duplicate()
	epics.reverse()
	var out := {"heroes": (heroes + epics).map(_c)}
	for k in ["rooms", "spells", "items"]:
		var a: Array = (decks[k] as Array).duplicate()
		a.reverse()
		out[k] = a.map(_c)
	return out

func _ready() -> void:
	CardDB.ship_all = true # l'oracle rejoue aussi ToolsHeroKind
	var dir := _traces_dir()
	if dir == "" or not DirAccess.dir_exists_absolute(dir):
		print("INIT PARITY FAIL: --traces=<dossier absolu> requis (recu: '%s')" % dir)
		get_tree().quit(1)
		return
	var files := DirAccess.get_files_at(dir)
	files.sort()
	var n := 0
	for f in files:
		if not f.begins_with("oracle-") or not f.ends_with(".json"):
			continue
		var t = JSON.parse_string(FileAccess.get_file_as_string(dir.path_join(f)))
		var meta: Dictionary = t["meta"]
		var sets: Array = (meta["decks"] as Array).map(func(d): return SETS[d])
		var m = load("res://godot/scripts/Match.gd").new()
		add_child(m)
		var G: Dictionary = m.new_match(int(meta["players"]), 0, sets, int(meta["seed"]))
		var out := {"bosses": [], "pre": _snapshot(G["decks"])}
		var seats: Array = G["players"].keys()
		seats.sort()
		for pid in seats:
			out["bosses"].append(m.apk_ai_boss(int(pid))) # boss des sieges IA, tires avant que les sieges ne soient marques humains
		G["autoAI"] = false
		for pid in seats:
			(G["players"][pid] as Dictionary)["isAI"] = false # pas de defausse automatique : on lit les mains d'ouverture completes
		for i in seats.size():
			m.apply_move(int(seats[i]), {"type": "pickBoss", "args": [out["bosses"][i]]})
		var rank: Dictionary = {}
		var order: Array = CardDB.order_by_xp(G["players"])
		for i in order.size():
			rank[int(order[i])] = i + 1
		out["rank"] = seats.map(func(p): return rank.get(int(p), 0))
		out["hands"] = seats.map(func(p): return (G["players"][p]["hand"] as Array).map(_c))
		out["post"] = _snapshot(G["decks"])
		out["dbmSamples"] = int(G["dbm"]["n"])
		var fh := FileAccess.open(dir.path_join("init-%s" % f.trim_prefix("oracle-")), FileAccess.WRITE)
		fh.store_string(JSON.stringify(out))
		fh.close()
		m.queue_free()
		n += 1
	print("INIT PARITY OK traces=%d" % n)
	get_tree().quit(0)
