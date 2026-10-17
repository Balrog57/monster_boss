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

static func avatar_path(aid: String) -> String:
	return "res://assets/ui/avatar/%s.webp" % aid

static func load_profile() -> Dictionary:
	var d := {"name": "Player", "avatar": AVATARS[0]}
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		var nm := str(cfg.get_value("profile", "name", "Player")).strip_edges()
		d["name"] = nm if nm != "" else "Player"
		var av := str(cfg.get_value("profile", "avatar", AVATARS[0]))
		d["avatar"] = av if av in AVATARS else AVATARS[0]
	return d

## Un pseudo a-t-il deja ete enregistre ? (l'APK ouvre ChangeNameAvatarScene avant le menu en ligne sinon.)
static func has_profile() -> bool:
	var cfg := ConfigFile.new()
	return cfg.load(SAVE_PATH) == OK and cfg.has_section_key("profile", "name")

## Valeurs initiales de l'APK : « player_ » + 4 caracteres au hasard (StringFactory.RndWord) et un avatar au hasard.
static func random_profile() -> Dictionary:
	var chars := "abcdefghijklmnopqrstuvwxyz123456789"
	var w := ""
	for _i in 4:
		w += chars[randi() % chars.length()]
	return {"name": "player_" + w, "avatar": PICKER[randi() % PICKER.size()]}

static func save_profile(pname: String, avatar: String) -> void:
	var cfg := ConfigFile.new()
	cfg.load(SAVE_PATH) # garde reglages et compteurs
	var nm := pname.strip_edges().left(NAME_MAX)
	cfg.set_value("profile", "name", nm if nm != "" else "Player")
	cfg.set_value("profile", "avatar", avatar if avatar in AVATARS else AVATARS[0])
	cfg.save(SAVE_PATH)

## Victoires / defaites en ligne du joueur local (colonnes WINS / DEFEATS de la salle d'attente), comptees a la fin de chaque partie en ligne.
static func load_stats() -> Dictionary:
	var cfg := ConfigFile.new()
	cfg.load(SAVE_PATH)
	return {"wins": maxi(0, int(cfg.get_value("stats", "wins", 0))), "defeats": maxi(0, int(cfg.get_value("stats", "defeats", 0)))}

static func record_result(won: bool) -> void:
	var st := load_stats()
	var cfg := ConfigFile.new()
	cfg.load(SAVE_PATH)
	cfg.set_value("stats", "wins" if won else "defeats", int(st["wins" if won else "defeats"]) + 1)
	cfg.save(SAVE_PATH)

## Reglages (serveur multi, extensions du wiki, paquets APK choisis), meme fichier.
static func load_settings() -> Dictionary:
	var d := {"host": "http://127.0.0.1:8000", "extensions": false, "decks": []}
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		d["host"] = str(cfg.get_value("settings", "host", d["host"])).strip_edges()
		if d["host"] == "":
			d["host"] = "http://127.0.0.1:8000"
		d["extensions"] = bool(cfg.get_value("settings", "extensions", false))
		var dk = cfg.get_value("settings", "decks", [])
		d["decks"] = Array(dk) if dk is Array or dk is PackedStringArray else []
	return d

static func save_settings(host: String, extensions: bool, decks: Variant = null) -> void:
	var cfg := ConfigFile.new()
	cfg.load(SAVE_PATH)
	cfg.set_value("settings", "host", host.strip_edges())
	cfg.set_value("settings", "extensions", extensions)
	if decks != null: # omis : on garde le choix de paquets deja enregistre
		cfg.set_value("settings", "decks", decks)
	cfg.save(SAVE_PATH)

## Vitesse de jeu (Options APK : 0 SLOW, 1 NORMAL, 2 FAST) : simplement memorisee pour l'instant.
static func load_speed() -> int:
	var cfg := ConfigFile.new()
	cfg.load(SAVE_PATH)
	return clampi(int(cfg.get_value("settings", "speed", 1)), 0, 2)

static func save_speed(speed: int) -> void:
	var cfg := ConfigFile.new()
	cfg.load(SAVE_PATH)
	cfg.set_value("settings", "speed", clampi(speed, 0, 2))
	cfg.save(SAVE_PATH)
