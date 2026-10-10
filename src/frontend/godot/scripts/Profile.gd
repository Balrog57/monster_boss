class_name Profile
extends RefCounted
## Pseudo + avatar stockes en local (user://profile.cfg), comme l'APK
## (INSERT USERNAME / SELECT AVATAR). Avatars extraits de l'APK.

const AVATARS: Array = [
	"avatar_draculord", "avatar_xyzax", "avatar_croak", "avatar_robobo",
	"avatar_cerebellus", "avatar_seducia", "avatar_cleopatra", "avatar_gorgona",
	"avatar_anererak", "avatar_none",
]
const SAVE_PATH := "user://profile.cfg"

static func avatar_path(aid: String) -> String:
	return "res://assets/ui/avatar/%s.webp" % aid

static func load_profile() -> Dictionary:
	var d := {"name": "Joueur", "avatar": AVATARS[0]}
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		var nm := str(cfg.get_value("profile", "name", "Joueur")).strip_edges()
		d["name"] = nm if nm != "" else "Joueur"
		var av := str(cfg.get_value("profile", "avatar", AVATARS[0]))
		d["avatar"] = av if av in AVATARS else AVATARS[0]
	return d

static func save_profile(pname: String, avatar: String) -> void:
	var cfg := ConfigFile.new()
	var nm := pname.strip_edges().left(16)
	cfg.set_value("profile", "name", nm if nm != "" else "Joueur")
	cfg.set_value("profile", "avatar", avatar if avatar in AVATARS else AVATARS[0])
	cfg.save(SAVE_PATH)

## Reglages (serveur multi, extensions), meme fichier.
static func load_settings() -> Dictionary:
	var d := {"host": "http://127.0.0.1:8000", "extensions": false}
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		d["host"] = str(cfg.get_value("settings", "host", d["host"])).strip_edges()
		if d["host"] == "":
			d["host"] = "http://127.0.0.1:8000"
		d["extensions"] = bool(cfg.get_value("settings", "extensions", false))
	return d

static func save_settings(host: String, extensions: bool) -> void:
	var cfg := ConfigFile.new()
	cfg.load(SAVE_PATH)
	cfg.set_value("settings", "host", host.strip_edges())
	cfg.set_value("settings", "extensions", extensions)
	cfg.save(SAVE_PATH)
