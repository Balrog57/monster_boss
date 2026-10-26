class_name ViewFilter
extends RefCounted
## ViewFilter — vue de G propre a UN siege : ce que ce joueur a le droit de voir.
## Cache : mains adverses (taille seule), ordre/contenu de toutes les pioches (taille seule),
## salles et minibosses face cachee adverses (dos seul), options d'un choix qui ne le concerne pas, files internes,
## lignes de journal privees (le moteur les ecrit avec une variante publique, voir Match._log). Le RNG n'est pas dans G (Match.rng) donc jamais emis.
## Liste blanche : une cle de G inconnue n'est PAS emise ; le test online echoue pour la classer ici.

## Cles de G publiques, recopiees telles quelles.
const PUBLIC_KEYS := ["activePlayer", "adventure", "adventurePausePassed", "afterHero", "apkSkippedHero", "autoAI", "buildIndex",
	"buildOrder", "buildWindow", "effects", "forcedBuild", "gameOver", "itemQueue", "kingVote", "townItems", "lastHeroFight", "luredThisTurn",
	"mandoQueue", "numPlayers", "phase", "roboboQueue", "sets", "setupBuild", "setupForced", "setupReveal", "stack",
	"stackActivePlayer", "stackPassed", "stackReturnPlayer", "tnlEndPending", "tnlGiftBuilt", "town", "turn", "xpOrder"]
## Cles traitees a part (filtrees) ou volontairement jamais emises (revealQueue, forcedBuilds, forcedRandom, aiTargets*).
## apkSkippedHero est publique : numero de siege pose par Trepidation (sort face visible) ; Match.apk_active_hero() la lit cote client en ligne.
const FILTERED_KEYS := ["decks", "players", "bossPicks", "pendingChoice", "choiceQueue", "log", "logs"]
## aiMayCancel (harnais d'oracle), iodFlame / rmbReplay / lincolnReveal (drapeaux internes au moteur, poses puis effaces dans un meme coup) : aucun lecteur cote client.
const DROPPED_KEYS := ["revealQueue", "forcedBuilds", "forcedRandom", "aiTargetsAllBosses", "aiTargetsAnyRoomType", "aiMayCancel", "iodFlame", "rmbReplay", "lincolnReveal"]
const SECRET_PILES := ["rooms", "spells", "heroes", "epics", "items"]
## Cles de joueur publiques (coins, rmbBoss, tnlBoss... : tout ce qui est pose devant le joueur). Liste blanche aussi :
## une cle de joueur inconnue n'est pas emise aux adversaires (le siege lui-meme voit tout son joueur).
const PLAYER_PUBLIC_KEYS := ["id", "boss", "souls", "wounds", "eliminated", "leveledUp", "buildsThisTurn", "buildLimit", "isAI", "entrance", "passed",
	"hasActed", "coins", "tnlSoulsStart", "rmbBoss", "tnlBoss", "bonusTreasures", "copiedLevelUps", "untilEndSpells"]
## Cles de joueur masquees pour les adversaires : main (taille seule), donjon (salles / minibosses face cachee), objets face caches.
const PLAYER_HIDDEN_KEYS := ["hand", "dungeon", "items"]
const LOG_TAIL := 60 # lignes de journal emises (le journal "logs" des capacites n'est pas borne cote moteur)

static func is_known_key(k: String) -> bool:
	return k in PUBLIC_KEYS or k in FILTERED_KEYS or k in DROPPED_KEYS

static func is_known_player_key(k: String) -> bool:
	return k in PLAYER_PUBLIC_KEYS or k in PLAYER_HIDDEN_KEYS

static func _back() -> Dictionary:
	return {"hidden": true}

static func _backs(n: int) -> Array:
	var out: Array = []
	for _i in n:
		out.append(_back())
	return out

## Vue de G pour `seat` (lecture seule sur G : les parties publiques sont partagees, pas copiees).
static func for_seat(G: Dictionary, seat: int) -> Dictionary:
	var v := {}
	for k in PUBLIC_KEYS:
		if G.has(k):
			v[k] = G[k]
	var players_in: Dictionary = G.get("players", {})
	var players := {}
	for pid in players_in:
		var p: Dictionary = players_in[pid]
		if int(pid) == seat:
			players[pid] = p
			continue
		var q := {}
		for k in PLAYER_PUBLIC_KEYS:
			if p.has(k):
				q[k] = p[k]
		q["hand"] = (p.get("hand", []) as Array).map(func(c): return {"hidden": true, "isRoom": bool((c as Dictionary).get("isRoom", false))}) # OneOpponentDetail.cs:212 : l'adversaire voit RoomsInHand / SpellsInHand
		q["dungeon"] = (p.get("dungeon", []) as Array).map(func(stack): return (stack as Array).map(_room_view))
		if p.has("items"):
			q["items"] = (p["items"] as Array).map(func(it): return {"faceDown": true, "hidden": true} if bool((it as Dictionary).get("faceDown", false)) else it)
		players[pid] = q
	v["players"] = players
	var decks_in: Dictionary = G.get("decks", {})
	var decks := {}
	for k in decks_in:
		decks[k] = _backs((decks_in[k] as Array).size()) if k in SECRET_PILES else decks_in[k]
	v["decks"] = decks
	# Le pool de bosses n'est utile que pendant le choix ; ensuite les bosses non pris restent caches.
	v["bossPicks"] = G.get("bossPicks", []) if str(G.get("phase", "")) == "boss" else []
	var pc: Dictionary = G.get("pendingChoice", {})
	if int(pc.get("playerId", -1)) == seat or pc.is_empty():
		v["pendingChoice"] = pc
	else:
		v["pendingChoice"] = {"type": pc.get("type", ""), "playerId": pc.get("playerId", -1), "bossName": pc.get("bossName", ""), "options": _backs((pc.get("options", []) as Array).size())}
	v["choiceQueue"] = (G.get("choiceQueue", []) as Array).map(func(c): return {"type": (c as Dictionary).get("type", ""), "playerId": (c as Dictionary).get("playerId", -1)})
	for lk in ["log", "logs"]:
		if G.has(lk):
			v[lk] = _log(G[lk], seat)
	return v

## Salle d'un donjon adverse : face cachee -> dos seul ; un miniboss pose face cachee (sur cette salle ou une autre) -> on sait seulement
## qu'il existe. Un miniboss revele est public.
static func _room_view(r):
	if not (r is Dictionary):
		return r
	var room: Dictionary = r
	var mb = room.get("mb")
	var mb_view = {"faceDown": true, "hidden": true} if mb is Dictionary and bool((mb as Dictionary).get("faceDown", false)) else mb
	var under = room.get("iodUnder") # IOD026 Malakill : un Objet face cachee sous la salle reste cache aux adversaires
	var under_view = under
	if under is Dictionary and bool((((under as Dictionary).get("item", {})) as Dictionary).get("faceDown", false)):
		under_view = {"owner": (under as Dictionary).get("owner", 0), "item": {"faceDown": true, "hidden": true}}
	if bool(room.get("faceDown", false)):
		var back := {"faceDown": true, "hidden": true}
		if mb != null:
			back["mb"] = mb_view
		return back
	if mb_view == mb and under_view == under:
		return room
	var q := room.duplicate() # superficiel : seuls mb et iodUnder sont remplaces
	if mb_view != mb:
		q["mb"] = mb_view
	if under_view != under:
		q["iodUnder"] = under_view
	return q

## Journal : une ligne privee ({"t", "pub", "owners"}, voir Match._log) montre `t` aux seuls proprietaires, `pub` aux autres ;
## le client ne recoit que des textes.
static func _log(lines: Array, seat: int) -> Array:
	var out: Array = []
	for e in lines.slice(-LOG_TAIL):
		if e is Dictionary:
			out.append(str(e.get("t", "")) if seat in (e.get("owners", []) as Array) else str(e.get("pub", "")))
		else:
			out.append(str(e))
	return out
