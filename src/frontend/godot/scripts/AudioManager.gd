extends Node
## Autoload AudioManager — musique (APK: music_main / music_dungeon_v3, boucle) + SFX (pool de voix).
## Bus "Music" et "SFX" crees au vol; mute persiste dans user://audio.cfg.
## Navigateur: l'audio est bloque jusqu'au 1er input -> la musique demandee est mise en attente.

const SAVE_PATH := "user://audio.cfg"
const MUSIC_DIR := "res://assets/audio/music/"
const SFX_DIR := "res://assets/audio/sfx/"
const VOICES := 8

var muted := false
var music_on := true  # Options APK : MUSIC ON/OFF
var sfx_on := true    # Options APK : SOUND ON/OFF
var master_volume := 1.0 # Options en jeu : MASTER VOLUME (bus Master)
var music_volume := 0.5  # APK AudioService.musicVolume
var sfx_volume := 1.0    # APK AudioService.soundVolume
var _music: AudioStreamPlayer
var _voices: Array[AudioStreamPlayer] = []
var _cache := {}
var _wanted_music := ""
var _unlocked := not OS.has_feature("web")

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for b in ["Music", "SFX"]:
		if AudioServer.get_bus_index(b) < 0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, b)
	_music = AudioStreamPlayer.new()
	_music.bus = "Music"
	add_child(_music)
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_voices.append(p)
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		muted = bool(cfg.get_value("audio", "muted", false))
		music_on = bool(cfg.get_value("audio", "music_on", true))
		sfx_on = bool(cfg.get_value("audio", "sfx_on", true))
		master_volume = clampf(float(cfg.get_value("audio", "master", master_volume)), 0.0, 1.0)
		music_volume = clampf(float(cfg.get_value("audio", "music", music_volume)), 0.0, 1.0)
		sfx_volume = clampf(float(cfg.get_value("audio", "sfx", sfx_volume)), 0.0, 1.0)
	_apply()

func _input(e: InputEvent) -> void:
	if _unlocked:
		return
	if e is InputEventMouseButton or e is InputEventKey or e is InputEventScreenTouch:
		_unlocked = true
		if _wanted_music != "":
			var n := _wanted_music
			_wanted_music = ""
			play_music(n)

func _apply() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(master_volume, 0.0001)))
	AudioServer.set_bus_mute(0, master_volume <= 0.001)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), linear_to_db(maxf(music_volume, 0.0001)))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), linear_to_db(maxf(sfx_volume, 0.0001)))
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Music"), muted or not music_on)
	AudioServer.set_bus_mute(AudioServer.get_bus_index("SFX"), muted or not sfx_on)

func set_muted(m: bool) -> void:
	muted = m
	_save()

## persist = false pendant le glissement du curseur (on n'ecrit le fichier qu'au relachement).
func set_master_volume(v: float, persist: bool = true) -> void:
	master_volume = clampf(v, 0.0, 1.0)
	if persist:
		_save()
	else:
		_apply()

func set_music_on(on: bool) -> void:
	music_on = on
	_save()

func set_sfx_on(on: bool) -> void:
	sfx_on = on
	_save()

func _save() -> void:
	_apply()
	var cfg := ConfigFile.new()
	cfg.load(SAVE_PATH)
	cfg.set_value("audio", "muted", muted)
	cfg.set_value("audio", "music_on", music_on)
	cfg.set_value("audio", "sfx_on", sfx_on)
	cfg.set_value("audio", "master", master_volume)
	cfg.set_value("audio", "music", music_volume)
	cfg.set_value("audio", "sfx", sfx_volume)
	cfg.save(SAVE_PATH)

func _stream(path: String) -> AudioStream:
	if not _cache.has(path):
		_cache[path] = load(path) if ResourceLoader.exists(path) else null
	return _cache[path]

func play_music(name: String) -> void:
	if not _unlocked:
		_wanted_music = name
		return
	var s := _stream(MUSIC_DIR + name + ".mp3")
	if s == null or (_music.playing and _music.stream == s):
		return
	if s is AudioStreamMP3:
		(s as AudioStreamMP3).loop = true
	_music.stream = s
	_music.play()

func stop_music() -> void:
	_wanted_music = ""
	_music.stop()

## `name` = nom APK sans extension ("ui_button_select"); un chemin res:// est accepte (basename).
func play_sfx(name: String) -> void:
	var s := _stream(SFX_DIR + name.get_file().get_basename() + ".wav")
	if s == null:
		return
	for p in _voices:
		if not p.playing:
			p.stream = s
			p.play()
			return
	_voices[0].stream = s  # toutes occupees: on vole la plus ancienne
	_voices[0].play()
