extends RefCounted
## Variantes de jeu du livret The Next Level (section « Play variants »), hors APK : Classic Mode, Hard Mode, I Choose You, Machinations, Unlimited Lives.
## Reglage optionnel de la partie, coche dans SELECT EXPANSIONS seulement avec la case « Wiki expansions » (Main.gd). Jamais actif par defaut : sans
## variante, `G.variants` est vide et le moteur ne change pas d'un octet.
## Transport : un jeton « <id>-wiki » dans la liste `sets` (create.sets d'une salle en ligne, voir server/PROTOCOL.md) ; Match.new_match les retire de
## `sets` et les range dans `G.variants` (ids sans suffixe). Les jetons finissant par « -wiki » sont deja masques par OnlineMenus._pack_text.

const IDS := ["classic", "hard", "choose", "machinations", "unlimited"]
const NAMES := {"classic": "Classic Mode", "hard": "Hard Mode", "choose": "I Choose You", "machinations": "Machinations", "unlimited": "Unlimited Lives"}
const HELP := {
	"classic": "Setup: draw 5 Rooms and 2 Spells, then discard 2 cards of your choice (The Next Level only: it otherwise keeps all 7).",
	"hard": "Remove all ordinary Heroes with a Health value of four.",
	"choose": "Setup: each player is dealt two Bosses, keeps one and removes the other from the game.",
	"machinations": "At the end of a turn, a player who did not gain a Soul this turn may draw one card from the Room or Spell deck.",
	"unlimited": "No elimination at five Wounds. The game ends when a turn ends with the Hero decks empty; highest Souls minus Wounds wins (tie: lowest XP).",
}

static func token(id: String) -> String:
	return id + "-wiki"

static func is_token(s) -> bool:
	for id in IDS:
		if str(s) == token(id):
			return true
	return false

## Ids des variantes presentes dans une liste `sets` (jetons inconnus ignores), dans l'ordre de IDS.
static func ids_in(p_sets: Array) -> Array:
	var out: Array = []
	for id in IDS:
		if p_sets.has(token(id)):
			out.append(id)
	return out

static func has(G: Dictionary, id: String) -> bool:
	return (G.get("variants", []) as Array).has(id)

## Livret TNL, mise en place : on GARDE les 5 salles + 2 sorts (7 cartes) ; la defausse de 2 cartes est le Classic Mode. Hors TNL, mise en place de l'APK.
static func keeps_opening_hand(G: Dictionary) -> bool:
	return TnlAbilities.active(G) and not has(G, "classic")

# --- I Choose You -------------------------------------------------------------------------------------------------------------

## Tous les joueurs ont un boss : chacun en recoit un second (tire dans les boss restants) et garde l'un des deux. Renvoie vrai si un choix humain est ouvert.
## IA : elle garde le boss d'XP la plus haute (il joue plus tot dans l'ordre d'XP).
static func offer_bosses(G: Dictionary) -> bool:
	var picks: Array = G.get("bossPicks", [])
	var ids: Array = (G.get("players", {}) as Dictionary).keys()
	ids.sort()
	for pid in ids:
		var p: Dictionary = G["players"][pid]
		if picks.is_empty() or p.get("boss") == null:
			continue
		var extra: Dictionary = picks.pop_front()
		var cur: Dictionary = p["boss"]
		if bool(p.get("isAI", false)):
			if int(extra.get("xp", 0)) > int(cur.get("xp", 0)):
				p["boss"] = extra.duplicate()
			TnlAbilities._log(G, "I Choose You: player %d keeps %s." % [int(pid) + 1, str((p["boss"] as Dictionary).get("name", "?"))])
			continue
		var opts: Array = []
		for b in [cur, extra]:
			opts.append({"card": b, "label": str((b as Dictionary).get("name", "?")), "ai": float((b as Dictionary).get("xp", 0))})
		TnlAbilities.emit(G, TnlAbilities.ask(G, int(pid), "var_boss", opts, {}, "I Choose You: keep one Boss, the other leaves the game", "I Choose You"))
	return not (G.get("pendingChoice", {}) as Dictionary).is_empty()

# --- Mulligan (livret TNL) ---------------------------------------------------------------------------------------------------

## Remet toute la main (salles ET sorts) dans les pioches, melange chaque pioche en entier et pioche une nouvelle main de 5 salles + 2 sorts (une seule fois).
static func mulligan(G: Dictionary, pid: int) -> void:
	var p: Dictionary = G["players"][pid]
	var decks: Dictionary = G["decks"]
	for c in (p.get("hand", []) as Array):
		(decks["spells" if bool((c as Dictionary).get("isSpell", false)) else "rooms"] as Array).append(c)
	decks["rooms"].shuffle()
	decks["spells"].shuffle()
	p["hand"] = CardDB.draw_cards(decks["rooms"], 5) + CardDB.draw_cards(decks["spells"], 2)
	TnlAbilities._log(G, "Mulligan: player %d draws a new hand." % (pid + 1))

# --- Machinations -------------------------------------------------------------------------------------------------------------

## Fin de tour : un joueur sans Ame gagnee ce tour peut piocher une carte de la pioche de salles ou de sorts. IA : un sort s'il n'en a aucun en main, sinon une salle.
## Renvoie vrai si un choix humain est ouvert (le tour suivant attend, comme pour Shellda).
static func end_of_turn(G: Dictionary) -> bool:
	if not has(G, "machinations"):
		return false
	var ids: Array = (G.get("players", {}) as Dictionary).keys()
	ids.sort()
	for pid in ids:
		var p: Dictionary = G["players"][pid]
		if bool(p.get("eliminated", false)) or CardDB.total_souls(p, G) - int(p.get("tnlSoulsStart", 0)) > 0:
			continue
		if bool(p.get("isAI", false)):
			TnlAbilities.draw_logged(G, int(pid), "spells" if TnlAbilities.spells_in_hand(p) == 0 else "rooms", 1, "Machinations")
			continue
		var opts := [{"label": "Draw a Room", "pile": "rooms", "ai": 1.0}, {"label": "Draw a Spell", "pile": "spells", "ai": 0.5}]
		TnlAbilities.emit(G, TnlAbilities.ask(G, int(pid), "var_machinations", opts, {}, "Machinations: no Soul gained this turn. Draw a card?", "Machinations", true))
	return not (G.get("pendingChoice", {}) as Dictionary).is_empty()

# --- resolution des choix (etapes « var_* » de TnlAbilities.ask) ----------------------------------------------------------------

static func resolve_pick(G: Dictionary, pid: int, pc: Dictionary, idx: int) -> Variant:
	var opts: Array = pc.get("options", [])
	var o: Dictionary = (opts[idx] as Dictionary) if idx >= 0 and idx < opts.size() else {}
	match str(pc.get("step", "")):
		"var_boss":
			if not o.is_empty():
				(G["players"][pid] as Dictionary)["boss"] = (o["card"] as Dictionary).duplicate()
				TnlAbilities._log(G, "I Choose You: player %d keeps %s." % [pid + 1, str(o.get("label", "?"))])
		"var_mulligan":
			if idx == 1:
				mulligan(G, pid)
		"var_machinations":
			if not o.is_empty():
				TnlAbilities.draw_logged(G, pid, str(o.get("pile", "rooms")), 1, "Machinations")
	return null
