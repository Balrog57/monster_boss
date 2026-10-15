extends Node
## Pilote headless du harnais de parite APK : rejoue les traces `oracle-*.json`
## (tools/apk-oracle) dans le moteur GDScript, en deux modes :
##   strict : aucune aide (la premiere salle de Setup_b est refusee si Godot ne la propose pas)
##   inject : le harnais pose lui-meme les salles initiales de Setup_b (isole les ecarts suivants)
## Ecrit gd-<mode>-<trace>.json a cote des traces. La comparaison est faite par tools/parity/apk.mjs.
##
## Usage :
##   godot --headless --path src/frontend res://godot/tests/ApkParity.tscn -- --traces=<dossier absolu>

const Apk = preload("res://godot/scripts/ApkParityTrace.gd")


func _traces_dir() -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--traces="):
			return a.substr(len("--traces="))
	return ""


func _opt(prefix: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with(prefix):
			return a.substr(len(prefix))
	return ""


func _ready() -> void:
	var dir := _traces_dir()
	if dir == "" or not DirAccess.dir_exists_absolute(dir):
		print("APK PARITY FAIL: --traces=<dossier absolu> requis (recu: '%s')" % dir)
		get_tree().quit(1)
		return
	var files := DirAccess.get_files_at(dir)
	files.sort()
	var n := 0
	for f in files:
		if not f.begins_with("oracle-") or not f.ends_with(".json"):
			continue
		if _opt("--only=") != "" and not f.contains(_opt("--only=")):
			continue
		var trace = JSON.parse_string(FileAccess.get_file_as_string(dir.path_join(f)))
		if not (trace is Dictionary):
			print("APK PARITY FAIL: trace illisible %s" % f)
			get_tree().quit(1)
			return
		for mode in ["strict", "inject"]:
			print("APK START %s %s" % [f, mode])
			var r: Dictionary = Apk.new().replay(trace, mode == "inject")
			var fh := FileAccess.open(dir.path_join("gd-%s-%s" % [mode, f.trim_prefix("oracle-")]), FileAccess.WRITE)
			fh.store_string(JSON.stringify(r))
			fh.close()
			print("APK REPLAY %s %s refus=%d" % [f, mode, int((r["stats"] as Dictionary)["refus"])])
		n += 1
	print("APK PARITY OK traces=%d" % n)
	get_tree().quit(0)
