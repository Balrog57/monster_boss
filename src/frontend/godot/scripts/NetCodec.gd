class_name NetCodec
extends RefCounted
## Decodage JSON -> types du moteur, commun au client et au serveur.
## JSON.parse_string rend des float partout et des cles texte : on restaure les entiers
## exacts et les dictionnaires indexes par entier (players, stackPassed...).

static func decode(v):
	if v is float:
		return int(v) if v == floor(v) and absf(v) < 1.0e15 else v
	if v is Array:
		var out: Array = []
		for e in v:
			out.append(decode(e))
		return out
	if v is Dictionary:
		var d: Dictionary = v
		var int_keys := not d.is_empty()
		for k in d:
			if not (k is String and (k as String).is_valid_int() and str(int(k)) == k):
				int_keys = false
				break
		var out := {}
		for k in d:
			out[int(k) if int_keys else k] = decode(d[k])
		return out
	return v

## Parse une ligne JSON ; {} si invalide ou si ce n'est pas un objet.
static func parse_message(text: String) -> Dictionary:
	var j = JSON.parse_string(text)
	if j is Dictionary:
		return decode(j)
	return {}

## Inverse (cote emission) : toutes les cles de dictionnaire deviennent du texte. Match.gd ecrit parfois la meme
## cle sous les deux formes (stackPassed[str(pid)] et [pid]) : JSON.stringify emettrait alors une cle en double.
static func encode(v):
	if v is Array:
		var out: Array = []
		for e in v:
			out.append(encode(e))
		return out
	if v is Dictionary:
		var out := {}
		for k in v:
			out[str(k)] = encode(v[k])
		return out
	return v
