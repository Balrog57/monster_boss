extends Node
## Autoload AudioManager — musique (APK: music_main / music_dungeon_v3, boucle) + SFX (pool de voix).
## Bus "Music" et "SFX" crees au vol; mute persiste dans user://audio.cfg.
## Navigateur: l'audio est bloque jusqu'au 1er input -> la musique demandee est mise en attente.
## Calque AudioService.cs de l'APK : 10 sons simultanes (:97), tous les SFX precharges (LoadingScene.cs:54-56), musique a MusicVolume 1.0,
## baisse x0,5 sous les stings avec retour lineaire en 2 s (PlayWithMusicFade, :153-164, :209-225), boucle a compteur (PlayLoopSound, :166-176).

const SAVE_PATH := "user://audio.cfg"
const MUSIC_DIR := "res://assets/audio/music/"
const SFX_DIR := "res://assets/audio/sfx/"
const VOICES := 10 # AudioService.cs:97 (MaxConcurrentSounds)
const DUCK := 0.5 # AudioService.cs:159
const DUCK_SECONDS := 2.0 # AudioService.cs:160
## Les 42 SFX de l'APK (Audio.cs:14-29), tous precharges au demarrage (LoadingScene.cs:54-56 -> AudioService.LoadAllSounds, :113-127).
const SFX_NAMES := ["boss_female_death", "boss_female_hurt", "boss_female_intro", "boss_female_victory", "boss_male_death", "boss_male_hurt", "boss_male_intro",
	"boss_male_victory", "char_hero_attack", "char_hero_death", "char_hero_hurt", "char_hero_intro", "char_hero_move", "sfx_activatecard", "sfx_multigameready",
	"sfx_room_fall", "sfx_room_magic", "sfx_room_monster_lrg", "sfx_room_monster_med", "sfx_room_physical", "sfx_room_undead", "sfx_sparklecard",
	"sfx_spell_buff", "sfx_spell_debuff", "sfx_spell_null", "sfx_spell_summon", "sfx_spelladd", "sting_levelup", "sting_player_lose", "sting_player_win",
	"ui_button_finish", "ui_button_goback", "ui_button_select", "ui_button_subselect", "ui_card_flip", "ui_card_slide_down", "ui_card_slide_general",
	"ui_card_slide_up", "ui_purchase", "ui_shuffle_left", "ui_shuffle_right", "ui_timer"]
## RoomInfo.RoomCategory -> son de salle (CardAssetService.GetRoomSound, :328-360) ; categorie 0 / inconnue / salle nulle = sfx_room_physical (:330).
const ROOM_SFX := {1: "sfx_room_fall", 2: "sfx_room_monster_med", 3: "sfx_room_undead", 4: "sfx_room_physical", 5: "sfx_room_monster_lrg", 6: "sfx_room_magic"}
## RoomCategory de chaque salle des paquets APK (champ RoomCategory de BaseDeck/data.json ; les salles ToolsHeroKind n'en ont pas = 0).
const ROOM_CATEGORY := {
	1: ["BMA010", "BMA027"],
	2: ["BMA012", "BMA015", "BMA018", "BMA019", "BMA020", "BMA026", "BMA033", "BMA036"],
	3: ["BMA009", "BMA011", "BMA014", "BMA021", "BMA022", "BMA039"],
	4: ["BMA028", "BMA030", "BMA031", "BMA032", "BMA034", "BMA038"],
	5: ["BMA013", "BMA016", "BMA017", "BMA035", "BMA037"],
	6: ["BMA023", "BMA024", "BMA025", "BMA029"],
}
## Bosses dont BossInfo.IsMale est faux dans les donnees APK (BaseDeck : BMA006-008 ; PlayerChoice : KSA001-007, tous a false). Un boss du wiki (sans donnee APK) reste masculin.
const BOSS_FEMALE := ["BMA006", "BMA007", "BMA008", "KSA001", "KSA002", "KSA003", "KSA004", "KSA005", "KSA006", "KSA007"]

var muted := false
var music_on := true  # Options APK : MUSIC ON/OFF
var sfx_on := true    # Options APK : SOUND ON/OFF
var master_volume := 1.0 # Options en jeu : MASTER VOLUME (bus Master)
var music_volume := 1.0  # GameSettings.cs:36 appliquee par Game.cs:98 apres l'init d'AudioService (le 0,5 d'AudioService.cs:29 n'est jamais effectif)
var sfx_volume := 1.0    # APK AudioService.soundVolume
var _music: AudioStreamPlayer
var _voices: Array[AudioStreamPlayer] = []
var _cache := {}
var _wanted_music := ""
var _next_voice := 0
var _duck_left := 0.0 # secondes restantes de la baisse de musique sous un sting
var _loops := {} # nom -> {"p": AudioStreamPlayer, "n": nombre de demandes} (AudioService.playLoopedSoundRequests)
var _unlocked := not OS.has_feature("web")
## Espion des tests : chaque demande de lecture y est notee (« sfx:nom », « sting:nom », « loop+:nom », « loop-:nom », « music:nom »), sans rien entendre.
var rec_enabled := false
var rec: Array = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)
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
	for n in SFX_NAMES:
		_stream(SFX_DIR + n + ".wav") # pas de latence au premier son (web)
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		muted = bool(cfg.get_value("audio", "muted", false))
		music_on = bool(cfg.get_value("audio", "music_on", true))
		sfx_on = bool(cfg.get_value("audio", "sfx_on", true))
		master_volume = clampf(float(cfg.get_value("audio", "master", master_volume)), 0.0, 1.0)
		# "music" n'est plus lu : sans curseur de musique, un 0,5 ecrit par une ancienne version resterait a jamais (APK : 1.0)
		sfx_volume = clampf(float(cfg.get_value("audio", "sfx", sfx_volume)), 0.0, 1.0)
	_apply()
	_setup_background_pause()

var _js_visibility = null # reference gardee : le callback JavaScriptBridge est libere s'il n'a plus de proprietaire

## Musique en pause hors premier plan : AndroidActivity.OnPause -> Game.OnDeactivated (AndroidActivity.cs:95-112) -> MusicPlayer.Pause (A-10).
## Web : onglet masque (visibilitychange) ; sinon la perte de focus de l'application (notification Godot).
func _setup_background_pause() -> void:
	if OS.has_feature("web"):
		_js_visibility = JavaScriptBridge.create_callback(func(_a): set_background(bool(JavaScriptBridge.eval("document.hidden", true))))
		JavaScriptBridge.get_interface("document").addEventListener("visibilitychange", _js_visibility)

func set_background(paused: bool) -> void:
	_rec("background:" + str(paused))
	_music.stream_paused = paused

func _notification(what: int) -> void:
	if OS.has_feature("web"): # le focus du canvas se perd au moindre clic hors du jeu : seul visibilitychange vaut OnPause
		return
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		set_background(true)
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		set_background(false)

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
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), linear_to_db(maxf(music_volume * duck_gain(), 0.0001)))
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
	cfg.set_value("audio", "sfx", sfx_volume)
	cfg.save(SAVE_PATH)

func _stream(path: String) -> AudioStream:
	if not _cache.has(path):
		_cache[path] = load(path) if ResourceLoader.exists(path) else null
	return _cache[path]

func play_music(name: String) -> void:
	_rec("music:" + name)
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
	name = name.get_file().get_basename()
	_rec("sfx:" + name)
	_play(name)

func _play(name: String) -> void:
	var s := _stream(SFX_DIR + name + ".wav")
	if s == null:
		return
	for p in _voices:
		if not p.playing:
			p.stream = s
			p.play()
			return
	_voices[_next_voice].stream = s # toutes occupees : on vole une voix, tour a tour
	_voices[_next_voice].play()
	_next_voice = (_next_voice + 1) % VOICES

## AudioService.PlayWithMusicFade (:153-164) : sting + musique x0,5 qui remonte lineairement en 2 s (sauf musique / sons coupes ou a 0).
func play_sting(name: String) -> void:
	_rec("sting:" + name)
	if music_on and sfx_on and not muted and music_volume > 0.0 and sfx_volume > 0.0:
		_duck_left = DUCK_SECONDS
		set_process(true)
		_apply()
	_play(name)

## Facteur de la baisse de musique (AudioService.Update, :209-225) : 0,5 puis lineaire jusqu'a 1.
func duck_gain() -> float:
	return 1.0 if _duck_left <= 0.0 else lerpf(DUCK, 1.0, 1.0 - _duck_left / DUCK_SECONDS)

func _process(delta: float) -> void:
	_duck_left = maxf(_duck_left - delta, 0.0)
	_apply()
	if _duck_left <= 0.0:
		set_process(false)

## AudioService.PlayLoopSound (:166-176) : une seule instance par son, comptee ; elle s'arrete quand le dernier demandeur s'en va.
func play_loop(name: String) -> void:
	_rec("loop+:" + name)
	if not _loops.has(name):
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		var s := _stream(SFX_DIR + name + ".wav")
		if s is AudioStreamWAV:
			s = (s as AudioStreamWAV).duplicate() # la copie boucle, le son en cache reste un one-shot
			(s as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
			(s as AudioStreamWAV).loop_end = int((s as AudioStreamWAV).get_length() * (s as AudioStreamWAV).mix_rate)
		p.stream = s
		add_child(p)
		if s != null:
			p.play()
		_loops[name] = {"p": p, "n": 0}
	_loops[name]["n"] = int(_loops[name]["n"]) + 1

## AudioService.StopLoopSound (:129-143).
func stop_loop(name: String) -> void:
	_rec("loop-:" + name)
	if not _loops.has(name):
		return
	_loops[name]["n"] = maxi(int(_loops[name]["n"]) - 1, 0)
	if int(_loops[name]["n"]) == 0:
		(_loops[name]["p"] as AudioStreamPlayer).queue_free()
		_loops.erase(name)

func loop_count(name: String) -> int:
	return int(_loops[name]["n"]) if _loops.has(name) else 0

func stop_all_loops() -> void:
	for n in _loops.keys():
		(_loops[n]["p"] as AudioStreamPlayer).queue_free()
	_loops.clear()

## Voix d'un boss (CardAssetService.GetBoss{Intro,Hurt,Death,Victory}Sound, :246-300) : kind = intro | hurt | death | victory.
func boss_voice(boss_id: String, kind: String) -> String:
	return "boss_%s_%s" % ["female" if boss_id in BOSS_FEMALE else "male", kind]

## Son de salle (CardAssetService.GetRoomSound, :328-360) d'apres l'id de la carte.
func room_sfx(room_id: String) -> String:
	for cat in ROOM_CATEGORY:
		if room_id in ROOM_CATEGORY[cat]:
			return ROOM_SFX[cat]
	return "sfx_room_physical"

func _rec(ev: String) -> void:
	if rec_enabled:
		rec.append(ev)
