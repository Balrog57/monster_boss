extends Node
## Capture automatique des écrans du jeu Godot pour comparaison avec l'APK.

const OUT_DIR := "res://../../docs/reference/godot_screens"

func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var global_dir := ProjectSettings.globalize_path(OUT_DIR)
	DirAccess.make_dir_recursive_absolute(global_dir)
	var path := "%s/%s.png" % [global_dir, name]
	img.save_png(path)
	print("Captured: ", name, " -> ", path)

func _ready() -> void:
	var main_scene = load("res://godot/scenes/Main.tscn").instantiate()
	add_child(main_scene)
	
	await get_tree().create_timer(0.4).timeout
	await _shot("godot_01_menu")
	
	main_scene.show_solo_count()
	await get_tree().create_timer(0.4).timeout
	await _shot("godot_02_solo_count")
	
	main_scene.show_multi()
	await get_tree().create_timer(0.4).timeout
	await _shot("godot_03_multi")
	
	main_scene.show_profile()
	await get_tree().create_timer(0.4).timeout
	await _shot("godot_04_profile")
	
	main_scene.show_friends()
	await get_tree().create_timer(0.4).timeout
	await _shot("godot_05_friends")
	
	main_scene.show_options()
	await get_tree().create_timer(0.4).timeout
	await _shot("godot_06_options")
	
	main_scene.show_rules()
	await get_tree().create_timer(0.4).timeout
	await _shot("godot_07_rules")
	
	main_scene.start_match(2, 1)
	await get_tree().create_timer(0.6).timeout
	await _shot("godot_08_board")
	
	print("ALL GODOT SCREENS CAPTURED")
	get_tree().quit(0)
