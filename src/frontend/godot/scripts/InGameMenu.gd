extends Control
## Menu en jeu (engrenage) de l'APK (PauseScene) : « PAUSED » + RESUME / CARD GALLERY / RULES (ajout) / SETTINGS / QUIT GAME.
## SETTINGS (SettingsScene) : MUSIC et SOUND ON/OFF, GAME SPEED SLOW/NORMAL/FAST, fleche de retour ; MASTER VOLUME est un ajout
## (curseur sous les bascules). CARD GALLERY ouvre la galerie par-dessus. QUIT GAME demande confirmation (BoardUI).

signal resume_requested
signal rules_requested
signal quit_requested
signal speed_changed

const UiKit = preload("res://godot/scripts/UiKit.gd")
const CardGallery = preload("res://godot/scripts/CardGallery.gd")
const Profile = preload("res://godot/scripts/Profile.gd")
const UI := "res://assets/ui/"
const BTN := Vector2(546, 144)

var page := "main"                   # "main" | "settings"
var gallery: Control                 # galerie ouverte par-dessus (null si fermee)
var volume_slider: HSlider

func _ready() -> void:
	size = Vector2(1920, 1080)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()

func _clear() -> void:
	for c in get_children():
		if c != gallery:
			remove_child(c)
			c.queue_free()
	volume_slider = null

func _build() -> void:
	_clear()
	if page == "settings":
		_build_settings()
	else:
		_build_main()

func _build_main() -> void:
	var t := UiKit.label(self, "PAUSED", 42, UiKit.GOLD, Vector2(1, 45), 1920.0, UiKit.FONT_A, HORIZONTAL_ALIGNMENT_CENTER) # or #cdb15f (PauseScene.cs:42, CustomColors.cs:16) ; APK : texte 198 x 28 px centre en (961, 76)
	t.name = "Title"
	var entries := [["RESUME", func(): resume_requested.emit()], ["CARD GALLERY", _open_gallery], ["RULES", func(): rules_requested.emit()],
		["SETTINGS", func():
			page = "settings"
			_build()], ["QUIT GAME", func(): quit_requested.emit()]]
	for i in entries.size():
		# APK : 4 boutons au pas de 194 px (bordures a y 124, 318, 512, 707) ; RULES (ajout) est place apres eux
		var row := 4 if str(entries[i][0]) == "RULES" else (i if i < 2 else i - 1)
		var b := UiKit.stone_button(self, str(entries[i][0]), Vector2(960.0 - BTN.x / 2.0, 122.5 + 194.2 * row), BTN)
		var cb: Callable = entries[i][1]
		var sfx := "ui_button_goback" if i == 0 else "ui_button_select"
		b.pressed.connect(func():
			AudioManager.play_sfx(sfx)
			cb.call())

func _build_settings() -> void:
	var back := UiKit.texture_button(self, UI + "buttons/back_bt.webp", UI + "buttons/back_bt_pressed.webp", Vector2(200, 41))
	back.name = "Back"
	back.pressed.connect(func():
		AudioManager.play_sfx("ui_button_goback")
		page = "main"
		_build())
	UiKit.toggle_row(self, 358, "MUSIC", ["ON", "OFF"], 0 if AudioManager.music_on else 1, func(i: int): AudioManager.set_music_on(i == 0))
	UiKit.toggle_row(self, 478, "SOUND", ["ON", "OFF"], 0 if AudioManager.sfx_on else 1, func(i: int): AudioManager.set_sfx_on(i == 0))
	UiKit.toggle_row(self, 598, "GAME SPEED", ["SLOW", "NORMAL", "FAST"], Profile.load_speed(), func(i: int):
		Profile.save_speed(i)
		speed_changed.emit())
	_volume(740.0)

## MASTER VOLUME (ajout hors APK, web) : curseur vert + pourcentage sous les bascules ; agit sur le bus Master de AudioManager.
func _volume(y: float) -> void:
	UiKit.label(self, "MASTER VOLUME", 28, Color.WHITE, Vector2(260, y), 450.0, UiKit.FONT_B, HORIZONTAL_ALIGNMENT_RIGHT)
	var pct := UiKit.label(self, "%d%%" % roundi(AudioManager.master_volume * 100.0), 28, UiKit.GOLD, Vector2(1380, y), 100.0, UiKit.FONT_B, HORIZONTAL_ALIGNMENT_LEFT)
	var sl := HSlider.new()
	sl.min_value = 0.0
	sl.max_value = 1.0
	sl.step = 0.01
	sl.value = AudioManager.master_volume
	sl.position = Vector2(760, y - 2)
	sl.size = Vector2(606, 32)
	sl.focus_mode = Control.FOCUS_NONE
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.2, 0.17, 0.12)
	track.set_corner_radius_all(8)
	track.content_margin_top = 8
	track.content_margin_bottom = 8
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.36, 0.7, 0.2)
	fill.set_corner_radius_all(8)
	fill.content_margin_top = 8
	fill.content_margin_bottom = 8
	sl.add_theme_stylebox_override("slider", track)
	sl.add_theme_stylebox_override("grabber_area", fill)
	sl.add_theme_stylebox_override("grabber_area_highlight", fill)
	sl.value_changed.connect(func(v: float):
		AudioManager.set_master_volume(v, false)
		pct.text = "%d%%" % roundi(v * 100.0))
	sl.drag_ended.connect(func(_changed: bool): AudioManager.set_master_volume(sl.value))
	add_child(sl)
	volume_slider = sl

func _open_gallery() -> void:
	if gallery != null and is_instance_valid(gallery):
		return
	gallery = CardGallery.new()
	gallery.z_index = 5
	gallery.closed.connect(func(): gallery = null)
	add_child(gallery)
