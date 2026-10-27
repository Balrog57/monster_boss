class_name Profile
extends RefCounted
## Pseudo + avatar stockes en local (user://profile.cfg), comme l'APK
## (INSERT USERNAME / SELECT AVATAR). Avatars extraits de l'APK.

const AVATARS: Array = [
	"avatar_draculord", "avatar_xyzax", "avatar_croak", "avatar_robobo",
	"avatar_cerebellus", "avatar_seducia", "avatar_cleopatra", "avatar_gorgona",
	"avatar_anererak", "avatar_none",
]
## Avatars du selecteur, dans l'ordre de l'enum Atlas.AVATAR de l'APK (les « leg_avatar_* » sont reserves aux mecenes, pas d'avatar_none).
const PICKER: Array = [
	"avatar_anererak", "avatar_cerebellus", "avatar_cleopatra", "avatar_croak", "avatar_draculord",
	"avatar_gorgona", "avatar_robobo", "avatar_seducia", "avatar_xyzax",
]
const NAME_MAX := 45 # ChangeNameAvatarScene : Truncate(45)
const SAVE_PATH := "user://profile.cfg"

## StorageHelper.SafeStorageWrite / SafeStorageRead (StorageHelper.cs:15-57) : 8 essais, puis une trace d'erreur ; une lecture sans fichier n'est pas une erreur (le defaut s'applique).
const TRIES := 8

static func write(cfg: ConfigFile, path: String = SAVE_PATH) -> bool:
	var err := FAILED
	for _i in TRIES:
		err = cfg.save(path)
		if err == OK:
			return true
	push_error("Storage write fails %d times (%s): %s" % [TRIES, path, error_string(err)])
	return false

static func read(cfg: ConfigFile, path: String = SAVE_PATH) -> Error:
	var err := FAILED
	for _i in TRIES:
		err = cfg.load(path)
		if err == OK or err == ERR_FILE_NOT_FOUND:
			return err
	push_error("Storage read fails %d times (%s): %s" % [TRIES, path, error_string(err)])
	return err

static func avatar_path(aid: String) -> String:
	return "res://assets/ui/avatar/%s.webp" % aid

static func load_profile() -> Dictionary:
	var d := {"name": "Player", "avatar": AVATARS[0]}
	var cfg := ConfigFile.new()
	if read(cfg) == OK:
		var nm := str(cfg.get_value("profile", "name", "Player")) # sans rognage : l'APK accepte un pseudo fait d'espaces (ChangeNameAvatarScene.cs:104)
		d["name"] = nm if nm != "" else "Player"
		var av := str(cfg.get_value("profile", "avatar", AVATARS[0]))
		d["avatar"] = av if av in AVATARS else AVATARS[0]
	return d

## Un pseudo non vide a-t-il deja ete enregistre ? (l'APK ouvre ChangeNameAvatarScene avant le menu en ligne sinon : UserName != null && != string.Empty, MainMenuScene.cs:96.)
static func has_profile() -> bool:
	var cfg := ConfigFile.new()
	return read(cfg) == OK and str(cfg.get_value("profile", "name", "")) != ""

## Valeurs initiales de l'APK : « player_ » + 4 caracteres au hasard (StringFactory.RndWord) et un avatar au hasard.
static func random_profile() -> Dictionary:
	var chars := "abcdefghijklmnopqrstuvwxyz123456789"
	var w := ""
	for _i in 4:
		w += chars[randi() % chars.length()]
	return {"name": "player_" + w, "avatar": PICKER[randi() % PICKER.size()]}

static func save_profile(pname: String, avatar: String) -> void:
	var cfg := ConfigFile.new()
	read(cfg) # garde reglages et compteurs
	var nm := pname.left(NAME_MAX)
	cfg.set_value("profile", "name", nm if nm != "" else "Player")
	cfg.set_value("profile", "avatar", avatar if avatar in AVATARS else AVATARS[0])
	write(cfg)

## Victoires / defaites en ligne du joueur local (colonnes WINS / DEFEATS de la salle d'attente), comptees a la fin de chaque partie en ligne.
static func load_stats() -> Dictionary:
	var cfg := ConfigFile.new()
	read(cfg)
	return {"wins": maxi(0, int(cfg.get_value("stats", "wins", 0))), "defeats": maxi(0, int(cfg.get_value("stats", "defeats", 0)))}

const COUNTED_KEEP := 20 # derniers codes de salle deja comptes (survit au rechargement + RESUME d'une salle terminee)

## Debut d'une partie en ligne : defaite comptee d'avance (APK GamePlayMOScene.cs:46-48), une seule fois par salle.
static func record_start(code: String) -> void:
	var cfg := ConfigFile.new()
	read(cfg)
	var started: Array = Array(cfg.get_value("stats", "started", []))
	if code in started or code in Array(cfg.get_value("stats", "counted", [])):
		return
	started.append(code)
	cfg.set_value("stats", "started", started.slice(-COUNTED_KEEP))
	cfg.set_value("stats", "defeats", maxi(0, int(cfg.get_value("stats", "defeats", 0))) + 1)
	write(cfg)

## Fin de partie. `code` : salle de la partie ; si elle a deja ete comptee (meme apres rechargement), ne fait rien.
## Victoire : la defaite posee au debut est annulee (GamePlayMOScene.cs:260-267) ; defaite : deja comptee au debut (sauf partie jamais vue demarrer).
static func record_result(won: bool, code: String = "") -> void:
	var st := load_stats()
	var cfg := ConfigFile.new()
	read(cfg)
	var started := false
	if code != "":
		var counted: Array = Array(cfg.get_value("stats", "counted", []))
		if code in counted:
			return
		counted.append(code)
		cfg.set_value("stats", "counted", counted.slice(-COUNTED_KEEP))
		started = code in Array(cfg.get_value("stats", "started", []))
	if won:
		cfg.set_value("stats", "wins", int(st["wins"]) + 1)
		if started:
			cfg.set_value("stats", "defeats", maxi(0, int(st["defeats"]) - 1))
	elif not started:
		cfg.set_value("stats", "defeats", int(st["defeats"]) + 1)
	write(cfg)

## Les autres joueurs sont partis (GamePlayMOScene.OnPlayerLeaveGame, cs:96-119) : la defaite posee au debut est retiree, plus une victoire si la partie avait dure plus de 2 tours.
static func record_desertion(won: bool, code: String) -> void:
	if won:
		record_result(true, code)
		return
	var cfg := ConfigFile.new()
	read(cfg)
	var counted: Array = Array(cfg.get_value("stats", "counted", []))
	if code in counted:
		return
	counted.append(code)
	cfg.set_value("stats", "counted", counted.slice(-COUNTED_KEEP))
	if code in Array(cfg.get_value("stats", "started", [])):
		cfg.set_value("stats", "defeats", maxi(0, int(cfg.get_value("stats", "defeats", 0)) - 1))
	write(cfg)

## Reglages (serveur multi, extensions du wiki, paquets APK choisis), meme fichier.
static func load_settings() -> Dictionary:
	var d := {"host": "http://127.0.0.1:8000", "extensions": false, "decks": []}
	var cfg := ConfigFile.new()
	if read(cfg) == OK:
		d["host"] = str(cfg.get_value("settings", "host", d["host"])).strip_edges()
		if d["host"] == "":
			d["host"] = "http://127.0.0.1:8000"
		d["extensions"] = bool(cfg.get_value("settings", "extensions", false))
		var dk = cfg.get_value("settings", "decks", [])
		d["decks"] = Array(dk) if dk is Array or dk is PackedStringArray else []
	return d

static func save_settings(host: String, extensions: bool, decks: Variant = null) -> void:
	var cfg := ConfigFile.new()
	read(cfg)
	cfg.set_value("settings", "host", host.strip_edges())
	cfg.set_value("settings", "extensions", extensions)
	if decks != null: # omis : on garde le choix de paquets deja enregistre
		cfg.set_value("settings", "decks", decks)
	write(cfg)

## Premier lancement du jeu solo : l'APK propose le tutoriel une seule fois (GameStats.IsFirstGameplay, MainMenuScene.cs:60-88). Consomme des qu'on repond a la boite.
static func first_gameplay() -> bool:
	var cfg := ConfigFile.new()
	read(cfg)
	return bool(cfg.get_value("settings", "first_gameplay", true))

const CURRENT_VERSION := "2.2.6" # Game.cs:29
const LAST_TUTORIAL_VERSION := "2.2.4" # Game.cs:33 : un profil enregistre par une version plus ancienne revoit la proposition de tutoriel

## GameStats.CheckForcePlayTutorial (GameStats.cs:33-42) : version enregistree (« 0.0 » si aucune) < LAST_TUTORIAL_VERSION -> le tutoriel est repropose ; la version courante est enregistree.
static func check_force_play_tutorial(saved: String = "", current: String = CURRENT_VERSION, last: String = LAST_TUTORIAL_VERSION) -> bool:
	var cfg := ConfigFile.new()
	read(cfg)
	var v := saved if saved != "" else str(cfg.get_value("settings", "version", "0.0"))
	var forced := _version_less(v, last)
	if forced:
		cfg.set_value("settings", "first_gameplay", true)
	cfg.set_value("settings", "version", current)
	write(cfg)
	return forced

static func _version_less(a: String, b: String) -> bool:
	var pa := a.split(".")
	var pb := b.split(".")
	for i in maxi(pa.size(), pb.size()):
		var x := int(pa[i]) if i < pa.size() else 0
		var y := int(pb[i]) if i < pb.size() else 0
		if x != y:
			return x < y
	return false

static func set_first_gameplay(v: bool) -> void:
	var cfg := ConfigFile.new()
	read(cfg)
	cfg.set_value("settings", "first_gameplay", v)
	write(cfg)

## Vitesse de jeu (Options APK : 0 SLOW, 1 NORMAL, 2 FAST). Ecrite par Main.gd et InGameMenu.gd (lignes GAME SPEED), lue par BoardUI._speed_factor (SLOW x1.5, NORMAL x1, FAST x0.5 ; forcee a 0.5 en ligne).
static func load_speed() -> int:
	var cfg := ConfigFile.new()
	read(cfg)
	return clampi(int(cfg.get_value("settings", "speed", 1)), 0, 2)

static func save_speed(speed: int) -> void:
	var cfg := ConfigFile.new()
	read(cfg)
	cfg.set_value("settings", "speed", clampi(speed, 0, 2))
	write(cfg)
