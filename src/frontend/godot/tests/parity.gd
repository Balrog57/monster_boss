extends Node
## Pilote headless du harnais de parite : rejoue les traces ecrites par
## tools/parity/gen.mjs dans le moteur GDScript et ecrit les projections
## canoniques resultantes pour comparaison par tools/parity/compare.mjs.
##
## Usage :
##   godot --headless --path src/frontend res://godot/tests/Parity.tscn -- --traces=<dossier absolu>

const Traces = preload("res://godot/scripts/ParityTrace.gd")


func _traces_dir() -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--traces="):
			return a.substr(len("--traces="))
	return ""


func _ready() -> void:
	var dir := _traces_dir()
	if dir == "" or not DirAccess.dir_exists_absolute(dir):
		print("PARITY FAIL: --traces=<dossier absolu des traces> est requis (recu: '%s')" % dir)
		get_tree().quit(1)
		return

	var files := DirAccess.get_files_at(dir)
	files.sort()
	var played := 0
	var refused := 0
	var report: Array = []

	for f in files:
		if not f.begins_with("trace-") or not f.ends_with(".json"):
			continue
		var raw := FileAccess.get_file_as_string(dir.path_join(f))
		var parsed = JSON.parse_string(raw)
		if not (parsed is Dictionary):
			print("PARITY FAIL: trace illisible %s" % f)
			get_tree().quit(1)
			return

		var trace: Dictionary = parsed
		var r: Dictionary = Traces.replay(trace)
		var snapshots: Array = r["snapshots"]
		var errors: Array = r["errors"]
		var steps: Array = trace.get("steps", [])

		# Ecrit la projection GDScript a cote des snapshots JS de reference.
		var out_name := "gd-" + f.trim_prefix("trace-")
		var fh := FileAccess.open(dir.path_join(out_name), FileAccess.WRITE)
		fh.store_string(JSON.stringify({ "snapshots": snapshots, "errors": errors }))
		fh.close()

		played += 1
		refused += errors.size()
		report.append({
			"file": f,
			"steps": steps.size(),
			"replayed": snapshots.size() - 1,
			"errors": errors,
		})

	print("PARITY REPLAY fichiers=%d coups_refuses=%d" % [played, refused])
	var fh := FileAccess.open(dir.path_join("gd-report.json"), FileAccess.WRITE)
	fh.store_string(JSON.stringify(report))
	fh.close()

	# MARQUEUR DE SUCCES : tools/run_godot_tests.mjs et compare.mjs s'y fient.
	print("PARITY OK")
	get_tree().quit(0)