class_name AiWiki
extends RefCounted
## Aides de l'IA pour les cartes wiki (The Next Level, Crash Landing, Rise of the Minibosses : heuristiques maison, l'APK n'a pas ces cartes).
## Lecture de l'aventure en cours et petites simulations (leurre, echange de salles). Lecture seule : tout etat touche pour simuler est restaure.
## Appele par TnlAbilities / RmbAbilities / TnlSpells / RmbSpells / Minibosses (score_*) et AI.gd (_score_choice) ; jamais pour une carte de l'APK.

## Score d'une capacite de la phase de construction qui doit passer AVANT la pose d'une salle (la pose termine le tour de construction du joueur :
## apres elle, plus rien n'est jouable). Supérieur au meilleur score de buildRoom (~700), reserve aux coups dont le gain est verifie.
const BUILD_FIRST := 800.0

# --- l'aventure en cours ---------------------------------------------------------------------------------------------------------------

## Le heros actif vu de loin. `active` est faux s'il n'y a pas de heros dans un donjon : toutes les valeurs sont alors neutres (marge enorme).
## `behind` = degats des salles deja traversees (index < idx), `best` = degat max d'une salle encore devant lui.
## `margin` = PV du heros - degats des salles qu'il n'a pas encore traversees : > 0 il atteint le boss (blessure pour le proprietaire),
## <= 0 il meurt (ame pour le proprietaire). `monsters` / `traps` = nombre de salles de ce type encore devant lui, `best_monster` / `best_trap` leur degat max.
static func fate(G: Dictionary) -> Dictionary:
	var none := {"active": false, "owner": -1, "hero": {}, "hp": 0, "idx": -1, "ahead": 0, "behind": 0, "best": 0, "monsters": 0, "traps": 0, "best_monster": 0, "best_trap": 0, "margin": 999}
	var a := TnlAbilities.adv(G)
	if a.is_empty() or not (a.get("hero") is Dictionary):
		return none
	var owner := int(a.get("playerId", -1))
	var op: Dictionary = (G.get("players", {}) as Dictionary).get(owner, {}) as Dictionary
	if op.is_empty():
		return none
	var d: Array = op.get("dungeon", [])
	var idx := int(a.get("roomIndex", -1))
	var hp := int(a.get("hp", 0))
	var out := {"active": true, "owner": owner, "hero": a["hero"], "hp": hp, "idx": idx, "ahead": 0, "behind": 0, "best": 0, "monsters": 0, "traps": 0, "best_monster": 0, "best_trap": 0}
	for j in mini(maxi(idx, 0), d.size()): # salles deja traversees : ce que reprendrait un retour au debut du donjon
		if BossEngine.active_room(d[j]) != null:
			out["behind"] = int(out["behind"]) + BossEngine.room_damage_with_modifiers(G, op, j, a["hero"])
	for j in range(maxi(idx + 1, 0), d.size()):
		var r = BossEngine.active_room(d[j])
		if r == null or bool((r as Dictionary).get("faceDown", false)):
			continue
		var dmg := BossEngine.room_damage_with_modifiers(G, op, j, a["hero"])
		out["ahead"] = int(out["ahead"]) + dmg
		out["best"] = maxi(int(out["best"]), dmg)
		var key := "monsters" if str((r as Dictionary).get("type", "")) == "monster" else "traps"
		out[key] = int(out[key]) + 1
		out["best_" + key.trim_suffix("s")] = maxi(int(out["best_" + key.trim_suffix("s")]), dmg)
	out["margin"] = hp - int(out["ahead"])
	return out

## Ajouter `x` PV au heros actif (ou retirer des degats) le fait-il passer de « meurt » a « atteint le boss » ?
static func saves(f: Dictionary, x: int) -> bool:
	return bool(f["active"]) and int(f["margin"]) <= 0 and int(f["margin"]) + x > 0

## Retirer `x` PV au heros actif (ou ajouter des degats) le fait-il passer de « atteint le boss » a « meurt » ?
static func kills(f: Dictionary, x: int) -> bool:
	return bool(f["active"]) and int(f["margin"]) > 0 and int(f["margin"]) - x <= 0

## La salle d'index `idx` du donjon de `tp` est-elle devant le heros actif (il ne l'a pas encore traversee) ?
static func is_ahead(f: Dictionary, tp: int, idx: int) -> bool:
	return bool(f["active"]) and int(f["owner"]) == tp and idx > int(f["idx"])

# --- leurre -----------------------------------------------------------------------------------------------------------------------------

## Degats totaux de tout le donjon de `p` (modificateurs compris) pour un heros donne.
static func dungeon_damage(G: Dictionary, p: Dictionary, hero) -> int:
	var n := 0
	for j in (p.get("dungeon", []) as Array).size():
		n += BossEngine.room_damage_with_modifiers(G, p, j, hero)
	return n

## Valeur, pour `pid`, des heros de la ville qui iraient dans son donjon si le leurre avait lieu maintenant :
## + ames d'un heros qui meurt dans le donjon, - blessures d'un heros qui atteint le boss. Ne simule pas les degats a venir de ce tour.
static func bait_value(G: Dictionary, pid: int) -> float:
	var players: Dictionary = G.get("players", {})
	var p: Dictionary = players.get(pid, {})
	var order := CardDB.order_by_xp(players)
	var total := 0.0
	for h in (G.get("town", []) as Array):
		var hd: Dictionary = h
		if TnlAbilities.no_lure(G, hd):
			continue
		if BossEngine.lure_target(players, order, int(hd.get("treasure", 1)), hd, G) != pid:
			continue
		total += float(BossEngine.hero_souls(hd)) if BossEngine.hero_hp(hd) <= dungeon_damage(G, p, hd) else -1.5 * float(BossEngine.hero_wounds(hd))
	return total

## Gain de leurre de `pid` si une icone `treasure` s'ajoute au donjon de `tp` jusqu'a la fin du tour (Endless Gallery).
## Pour un autre joueur, c'est la perte de leurre qu'il cause a `pid` (negatif = mauvais pour moi).
static func icon_gain(G: Dictionary, pid: int, tp: int, treasure: int) -> float:
	var icons: Array = Minibosses.list(G, "icons")
	var entry := {"pid": tp, "treasure": treasure}
	var before := bait_value(G, pid)
	icons.append(entry)
	var after := bait_value(G, pid)
	icons.erase(entry)
	return after - before

## Gain de leurre de `pid` si `room` perd ses icones de tresor jusqu'a la fin du tour (Decapitator, Heist).
static func no_treasure_gain(G: Dictionary, pid: int, room: Dictionary) -> float:
	var had := TnlAbilities.flag(room, "noTreasure")
	var before := bait_value(G, pid)
	TnlAbilities._tag(room)["noTreasure"] = true
	var after := bait_value(G, pid)
	if not had:
		(room["tnl"] as Dictionary).erase("noTreasure")
	return after - before

# --- echange de salles -------------------------------------------------------------------------------------------------------------------

## Variation des degats totaux du donjon de `tp` si ses piles `a` et `b` s'echangent (voisines : Goblin Armory, Dizzygas...).
static func swap_gain(G: Dictionary, tp: int, a: int, b: int) -> int:
	var p: Dictionary = (G.get("players", {}) as Dictionary).get(tp, {}) as Dictionary
	var d: Array = p.get("dungeon", [])
	if p.is_empty() or a < 0 or b < 0 or a >= d.size() or b >= d.size() or a == b:
		return 0
	var p2: Dictionary = p.duplicate()
	var d2: Array = d.duplicate()
	d2[a] = d[b]
	d2[b] = d[a]
	p2["dungeon"] = d2
	return dungeon_damage(G, p2, {}) - dungeon_damage(G, p, {})

## Meilleur echange de deux salles du donjon de `tp` : {gain, a, b} (gain 0 si rien n'ameliore).
static func best_swap(G: Dictionary, tp: int) -> Dictionary:
	var best := {"gain": 0, "a": -1, "b": -1}
	var n: int = ((G.get("players", {}) as Dictionary).get(tp, {}) as Dictionary).get("dungeon", []).size()
	for a in n:
		for b in range(a + 1, n):
			var g := swap_gain(G, tp, a, b)
			if g > int(best["gain"]):
				best = {"gain": g, "a": a, "b": b}
	return best

## Poids IA d'un echange de deux piles `a` / `b` du donjon de `tp` pour `pid` : le gain de degats chez moi, la perte de degats chez l'adversaire ;
## un echange sans interet pese -1.5 (moins que « passer »).
static func swap_ai(G: Dictionary, pid: int, tp: int, a: int, b: int) -> float:
	var v := float(swap_gain(G, tp, a, b)) * (1.0 if tp == pid else -1.0)
	return v if v > 0.0 else -1.5

## Meilleur echange possible dans le donjon de `tp` pour `pid` (poids de swap_ai).
static func best_swap_ai(G: Dictionary, pid: int, tp: int) -> float:
	var best := -1.5
	var n: int = ((G.get("players", {}) as Dictionary).get(tp, {}) as Dictionary).get("dungeon", []).size()
	for a in n:
		for b in range(a + 1, n):
			best = maxf(best, swap_ai(G, pid, tp, a, b))
	return best

## Peut-on se permettre de detruire une salle avant de construire ? Oui si le donjon est plein (5 salles visibles) ou le boss deja monte de niveau, qu'il
## reste une construction ce tour ET une salle ordinaire en main pour reboucher l'emplacement. (Detruire une salle d'un donjon qui se remplit coute un tour de
## construction et retarde la montee en niveau, qui demande 5 salles visibles : les soaks RMB y perdaient la moitie de leurs level-ups.)
static func can_refill(G: Dictionary, p: Dictionary, pid: int) -> bool:
	if int(p.get("buildsThisTurn", 0)) >= 1 + BossEngine.extra_builds_for(G, pid):
		return false
	if BossEngine.count_visible_rooms(p.get("dungeon", [])) < CardDB.DUNGEON_SLOTS and not bool(p.get("leveledUp", false)):
		return false
	for c in (p.get("hand", []) as Array):
		var cd: Dictionary = c
		if bool(cd.get("isRoom", false)) and not bool(cd.get("advanced", false)) and not bool(cd.get("isMiniboss", false)):
			return true
	return false

# --- divers -------------------------------------------------------------------------------------------------------------------------------

## Cartes avancees de la main qu'aucune salle du donjon ne peut accueillir (mortes tant que le donjon ne change pas).
static func dead_advanced(G: Dictionary, p: Dictionary, pid: int) -> int:
	var n := 0
	var hand: Array = p.get("hand", [])
	for hi in hand.size():
		var c: Dictionary = hand[hi]
		if not bool(c.get("isRoom", false)) or not bool(c.get("advanced", false)):
			continue
		var fits := false
		for ti in (p.get("dungeon", []) as Array).size():
			fits = fits or BossEngine.can_build_room(p, G, pid, hi, ti)
		n += 0 if fits else 1
	return n

## Un heros a l'entree du donjon de `p` porte-t-il une capacite de carte ?
static func entrance_has_text(p: Dictionary) -> bool:
	for h in (p.get("entrance", []) as Array):
		if hero_has_text(h):
			return true
	return false

## Le heros actif a-t-il une capacite de carte (ce que « ignorer le texte » lui retire) ?
static func hero_has_text(hero) -> bool:
	var cmd := TnlAbilities.hero_cmd(hero)
	return cmd != "" and cmd != TnlAbilities.DARK_PAY

## Interet de Doc Scarecrow sur le heros `town_idx` de la ville : 2 par blessure evitee a `pid` (le heros survivrait a son donjon),
## sinon l'ame qu'il ne donne pas a un adversaire en tete (>= 8 ames ou 2 de plus que moi), 0 si le heros resterait de toute facon en ville.
static func scarecrow_value(G: Dictionary, pid: int, town_idx: int) -> float:
	var town: Array = G.get("town", [])
	if town_idx < 0 or town_idx >= town.size():
		return 0.0
	var hero: Dictionary = town[town_idx]
	var players: Dictionary = G.get("players", {})
	var tgt := BossEngine.lure_target(players, CardDB.order_by_xp(players), int(hero.get("treasure", 1)), hero, G)
	if tgt < 0:
		return 0.0
	var tp: Dictionary = players[tgt]
	var dies := BossEngine.hero_hp(hero) <= dungeon_damage(G, tp, hero)
	if tgt == pid:
		return 0.0 if dies else 2.0 * float(BossEngine.hero_wounds(hero))
	var lead := CardDB.total_souls(tp, G) >= 8 or CardDB.total_souls(tp, G) >= CardDB.total_souls(players[pid], G) + 2
	return float(BossEngine.hero_souls(hero)) if dies and lead else 0.0

## Poids IA d'un heros (option de TnlAbilities.hero_options) a qui l'on donne des PV : celui de l'aventure en cours chez un adversaire d'abord
## (il blessera son proprietaire), jamais le heros de son propre donjon.
static func hero_weight(G: Dictionary, pid: int, o: Dictionary) -> float:
	var f := fate(G)
	var h: Dictionary = o.get("card", {})
	if bool(f["active"]) and str((f["hero"] as Dictionary).get("id", "")) == str(h.get("id", "")):
		return 5.0 if int(f["owner"]) != pid else -5.0
	var owner := int(o.get("ownerPid", -1))
	return 0.0 if owner < 0 else (-1.0 if owner == pid else 0.5)

## Valeur d'un effet « quand vous construisez / decouvrez cette salle » que The Omega 42 rejoue (carte de la salle).
static func refire_value(room: Dictionary) -> float:
	match str(room.get("id", "")):
		"BMA034": return 50.0 # Construction Zone : une construction de plus
		"CRL010": return 40.0 # Digicron Library : 2 sorts
		"CRL013": return 30.0 # Crash Site : une avancee de la defausse
		"BMA022": return 30.0 # Dark Laboratory : 2 sorts, 1 defausse
		"BMA037": return 25.0 # Monstrous Monument
		"BMA036": return 25.0 # Mimic Vault : un heros ordinaire de la ville
		"BMA011": return 20.0 # Specter's Sanctum
		"CRL016": return 20.0 # Darkling Lair
		"CRL006": return 15.0 # Decoy Garden
		"CRL014": return 15.0 # Caged Gundarf
		"CRL015": return 5.0 # Celestial Map : se detruit
	return 10.0
