class_name ThkAbilities
extends RefCounted
## Extension wiki « Tools of Hero-Kind » (THK : 20 Objets, 4 salles avancees, Excavation), jouee seulement derriere la case wiki.
## L'APK ne joue PAS ces cartes (deck ToolsHeroKind : Ability nulle partout, FlipItem leve NotImplemented) : le paquet « tools » seul reste inerte
## (Match._reveal_items : objets mis de cote). Le pseudo-paquet `tools-wiki` (SET_ID) active tout le code de ce fichier ; il pose aussi « tools ».
## Sources, par priorite : docs/rules/rules.md (section Items + FAQ des cartes THK), texte des cartes (cards.json, wiki).
## Modele : `hero.item` = Objet attache (carte), `G.townItems` = Objets de la ville non attaches, `player.items` = Objets du scorekeeping
## (`faceDown`, `acquiredTurn`), sac d'effets du tour `G.effects.thk`. Le moteur n'appelle ce module qu'a travers des crochets gardes par
## `ThkAbilities.active(G)` : sans la case wiki, les paquets de l'APK ne changent pas d'un octet.

const SET_ID := "tools-wiki"
## Salles a capacite activee (Magnetic Ceiling, THK024, est un declencheur : voir on_room_enter).
const ACTIVATED := ["THK021", "THK022", "THK023"]

## Le moteur des Objets sert aussi Implements of Destruction (IodAbilities, pseudo-paquet `iod`), qui ne joue que ses propres Objets.
static func active(G: Dictionary) -> bool:
	var s: Array = G.get("sets", [])
	return s.has(SET_ID) or s.has(IodAbilities.SET_ID) or s.has(PcwAbilities.SET_ID)

# --- acces d'etat ------------------------------------------------------------------------------------------------------

static func _p(G: Dictionary, pid: int) -> Dictionary:
	return TnlAbilities._player(G, pid)

static func _log(G: Dictionary, t: String, pub: String = "", owners: Array = []) -> void:
	TnlAbilities._log(G, t, pub, owners)

static func _label(c: Dictionary) -> String:
	return str(c.get("name", c.get("id", "?")))

static func _turn(G: Dictionary) -> int:
	return int(G.get("turn", 0))

static func _bag(G: Dictionary) -> Dictionary:
	var eff: Dictionary = SpellEffects._effects(G)
	var b = eff.get("thk")
	if not (b is Dictionary):
		b = {}
		eff["thk"] = b
	return b as Dictionary

static func _flags(G: Dictionary, key: String) -> Dictionary:
	var b := _bag(G)
	if not (b.get(key) is Dictionary):
		b[key] = {}
	return b[key] as Dictionary

static func item_of(hero) -> Dictionary:
	var it = (hero as Dictionary).get("item") if hero is Dictionary else null
	return it as Dictionary if it is Dictionary else {}

static func item_id(hero) -> String:
	return str(item_of(hero).get("id", ""))

static func item_name(id: String) -> String:
	for c in CardDB.items:
		if str((c as Dictionary).get("id", "")) == id:
			return str((c as Dictionary).get("name", id))
	return id

static func _opps(G: Dictionary, pid: int) -> Array:
	return TnlAbilities._opponents(G, pid)

static func _spells_left(G: Dictionary) -> int:
	var d: Dictionary = G.get("decks", {})
	return (d.get("spells", []) as Array).size() + (d.get("spellDiscard", []) as Array).size()

static func _hand_cards(p: Dictionary, kind: String) -> Array:
	return (p.get("hand", []) as Array).filter(func(c): return bool((c as Dictionary).get("isSpell", false)) == (kind == "spell") and (kind == "spell" or bool((c as Dictionary).get("isRoom", false))))

## « At random » : `n` cartes de la main de `victim` (Room ou Spell) defaussees au hasard.
static func _random_discard(G: Dictionary, victim: int, kind: String, n: int, label: String) -> void:
	for _i in n:
		var cands := _hand_cards(_p(G, victim), kind)
		if cands.is_empty():
			return
		var c: Dictionary = cands[TnlAbilities._rng_get().randi_range(0, cands.size() - 1)]
		TnlAbilities.discard_from_hand(G, victim, c)
		_log(G, "%s: player %d discards %s at random." % [label, victim + 1, _label(c)], "%s: player %d discards a %s card at random." % [label, victim + 1, kind])

# --- Objets : revelation et attache (livret : « Items ») -------------------------------------------------------------------------

## Heros marques d'une etoile (capacite propre) : les Objets ne s'y attachent pas (sauf Orcish Smithy).
static func is_star(h: Dictionary) -> bool:
	return h.get("heroAbility") is Dictionary or bool(h.get("dark", false)) or bool(h.get("star", false)) # KSA015 Pixel Lincoln : etoile sans heroAbility

## L'Objet `item` s'attache-t-il a `hero` par la regle de base ? Un seul Objet par heros ; Universel : tout heros sans etoile ;
## sinon l'icone de tresor doit correspondre (un heros « ? » ne prend que les Universels).
static func accepts(item: Dictionary, hero: Dictionary) -> bool:
	if not item_of(hero).is_empty() or is_star(hero):
		return false
	var t := int(item.get("treasure", 0))
	if t == 0:
		return true
	for x in CardDB.hero_treasures(hero):
		if int(x) == t: # le JSON donne des flottants : Array.has(int) ne les reconnait pas
			return true
	return false

## « Each Item attaches to the first Hero in town that matches » : chaque Objet de la ville prend le heros le plus ancien qui l'accepte.
static func attach_all(G: Dictionary) -> void:
	var items: Array = G.get("townItems", [])
	G["townItems"] = items
	var town: Array = G.get("town", [])
	var i := 0
	while i < items.size():
		var it: Dictionary = items[i]
		var done := false
		for h in town:
			if accepts(it, h):
				(h as Dictionary)["item"] = it
				items.remove_at(i)
				_log(G, "%s is attached to %s." % [_label(it), _label(h)])
				done = true
				break
		if not done:
			i += 1

## Debut de tour, AVANT les heros : 1 Objet (2 a 4 joueurs) rejoint la ville puis s'attache s'il peut.
static func reveal_items(G: Dictionary) -> void:
	var deck: Array = (G["decks"] as Dictionary).get("items", [])
	var town_items: Array = G.get("townItems", [])
	G["townItems"] = town_items
	for _i in (2 if (G["players"] as Dictionary).size() == 4 else 1):
		if not deck.is_empty():
			var it: Dictionary = deck.pop_back()
			it.erase("faceDown")
			town_items.append(it)
			_log(G, "Item revealed: %s." % _label(it))
	attach_all(G)

## Debut de tour : la blessure supplementaire de Vorpal Blade disparait « avant le debut du tour suivant ».
static func on_turn_start(G: Dictionary) -> void:
	for pid in (G["players"] as Dictionary):
		var w: Array = (G["players"][pid] as Dictionary).get("wounds", [])
		for k in range(w.size() - 1, -1, -1):
			if bool((w[k] as Dictionary).get("thkTemp", false)):
				w.remove_at(k)

# --- Objets : scorekeeping ----------------------------------------------------------------------------------------------------

static func face_up_item(p: Dictionary) -> Dictionary:
	for it in (p.get("items", []) as Array):
		if not bool((it as Dictionary).get("faceDown", false)):
			return it as Dictionary
	return {}

static func add_item(G: Dictionary, pid: int, item: Dictionary, face_down: bool) -> void:
	var p := _p(G, pid)
	var items: Array = p.get("items", [])
	p["items"] = items
	item["faceDown"] = face_down
	item["acquiredTurn"] = _turn(G)
	items.append(item)
	if face_down:
		_log(G, "%s is placed face-down in player %d's scorekeeping area." % [_label(item), pid + 1], "An Item is placed face-down in player %d's scorekeeping area." % (pid + 1), [pid])
	else:
		_log(G, "%s is placed face-up in player %d's scorekeeping area." % [_label(item), pid + 1])

## Le heros perd son Objet (mort, survie, Magnetic Ceiling, Extra Life...) ; renvoie la carte ou {}.
static func detach(hero: Dictionary) -> Dictionary:
	var it := item_of(hero)
	hero.erase("item")
	return it

## Valeur d'un Objet pour l'IA (qui garde le meilleur face visible).
static func item_value(item: Dictionary) -> float:
	if str(item.get("id", "")).begins_with("IOD"):
		return IodAbilities.value(str(item.get("id", "")))
	match str(item.get("id", "")):
		"THK016", "THK008", "THK003", "THK019":
			return 4.0
		"THK012", "THK013", "THK002", "THK009", "THK004":
			return 3.0
	return 2.0

## Un Objet vient d'etre gagne en tuant un heros : face visible s'il n'y a pas deja un Objet face visible, sinon le choix A / B / C du livret.
static func claim_item(G: Dictionary, pid: int, item: Dictionary) -> Variant:
	if item.is_empty():
		return null
	var p := _p(G, pid)
	var iod := IodAbilities.claim(G, pid, item) # Pandora's Box, Banseer Bivan : places face visible
	if bool(iod[0]):
		return iod[1]
	var cur := face_up_item(p)
	if cur.is_empty():
		add_item(G, pid, item, false)
		return null
	var v_new := item_value(item)
	var v_cur := item_value(cur)
	var opts: Array = []
	if item_usable(G, pid, cur):
		opts.append({"mode": "use", "label": "Use %s now, then keep %s face-up" % [_label(cur), _label(item)], "ai": 40.0 + v_new})
	opts.append({"mode": "swap", "label": "Turn %s face-down, keep %s face-up" % [_label(cur), _label(item)], "ai": v_new - v_cur})
	opts.append({"mode": "keep", "label": "Keep %s face-up, turn %s face-down" % [_label(cur), _label(item)], "ai": v_cur - v_new})
	return TnlAbilities.ask(G, pid, "thk_claim", opts, {"item": item, "cur": str(cur.get("id", ""))}, "You claim %s: choose what to do with %s" % [_label(item), _label(cur)], _label(item))

## Face visible et en service (« starting from the next turn after acquisition ») ?
static func faces_up_ready(G: Dictionary, it: Dictionary) -> bool:
	return not bool(it.get("faceDown", false)) and int(it.get("acquiredTurn", 0)) < _turn(G)

static func item_usable(G: Dictionary, pid: int, it: Dictionary) -> bool:
	return faces_up_ready(G, it) and effect_check(G, pid, str(it.get("id", ""))) == ""

## Les Objets du scorekeeping de `pid` dont la capacite de Boss est jouable maintenant (Construction / Aventure, ou reponse en Spell Battle).
static func use_moves(G: Dictionary, p: Dictionary, pid: int) -> Array:
	var out: Array = []
	if not active(G) or not (str(G.get("phase", "")) in ["build", "adventure"]) or not (G.get("pendingChoice", {}) as Dictionary).is_empty():
		return out
	for it in (p.get("items", []) as Array):
		if item_usable(G, pid, it as Dictionary):
			out.append({"type": "useItem", "args": [str((it as Dictionary).get("id", ""))]})
	return out

## Joue la capacite de Boss de l'Objet `id` (face visible) de `pid` : le retourne face cachee, puis l'effet (un choix peut suivre). Renvoie null ou une erreur.
static func use_item(G: Dictionary, pid: int, id: String) -> Variant:
	var p := _p(G, pid)
	for it in (p.get("items", []) as Array):
		var d: Dictionary = it
		if str(d.get("id", "")) == id and faces_up_ready(G, d):
			var err := effect_check(G, pid, id)
			if err != "":
				return err
			d["faceDown"] = true
			_log(G, "Player %d uses %s." % [pid + 1, _label(d)])
			IodAbilities.on_item_used(G, pid) # Franz
			TnlAbilities.emit(G, run_effect(G, pid, id))
			return null
	return "no such Item"

# --- Objets : cibles et verification (pures) -----------------------------------------------------------------------------------------

## Salle sous le heros actif de `pid` (-1 si aucun / sa salle a disparu).
static func _my_hero_room(G: Dictionary, pid: int) -> int:
	var a := TnlAbilities.adv(G)
	if a.is_empty() or int(a.get("playerId", -1)) != pid or bool(a.get("roomGone", false)):
		return -1
	var ri := int(a.get("roomIndex", -1))
	var d: Array = _p(G, pid).get("dungeon", [])
	return ri if ri >= 0 and ri < d.size() and BossEngine.active_room(d[ri]) != null else -1

## Salles ciblables (sommets visibles non gelees) de type `kind` ("any" | "trap" | "monster" | "advanced"), `opp_only` : donjons adverses seulement.
static func room_targets(G: Dictionary, pid: int, kind: String, opp_only: bool) -> Array:
	var out: Array = []
	for o in TnlAbilities.room_options(G, kind):
		if opp_only and int((o as Dictionary)["targetPlayerId"]) == pid:
			continue
		out.append(o)
	return out

static func _wounds_ordinary(p: Dictionary) -> Array:
	return BossEngine.wound_heroes(p).filter(func(h): return BossEngine.hero_wounds(h as Dictionary) == 1)

static func _survivors_this_turn(G: Dictionary, p: Dictionary) -> Array:
	var out: Array = []
	for w in (p.get("wounds", []) as Array):
		var h = (w as Dictionary).get("hero")
		if h is Dictionary and int((w as Dictionary).get("turn", -1)) == _turn(G) and not out.has(h):
			out.append(h)
	return out

static func _bag_rooms(G: Dictionary) -> Array:
	return RoomAbilities.discard_card_options(G, "room").filter(func(o): return BossEngine.room_treasures((o as Dictionary)["card"]).size() >= 2)

## Heros qu'une capacite peut viser : ville, entrees (le heros actif en fait partie). `owner` = -1 en ville.
static func all_heroes(G: Dictionary) -> Array:
	var out: Array = []
	for h in (G.get("town", []) as Array):
		out.append({"hero": h, "owner": -1})
	for opid in TnlAbilities._alive(G):
		for h in (_p(G, int(opid)).get("entrance", []) as Array):
			out.append({"hero": h, "owner": int(opid)})
	return out

## Degats deja subis par un heros (Vorpal Blade) : PV imprimes - PV courants, ou le cumul des salles pour le heros actif.
static func damage_taken(G: Dictionary, owner: int, hero: Dictionary) -> int:
	var base := BossEngine.hero_base_hp(hero)
	var cur := RoomAbilities.current_hero_hp(G, owner, hero) if owner >= 0 else BossEngine.hero_hp(hero)
	var taken := maxi(0, base - cur)
	var a := TnlAbilities.adv(G)
	if not a.is_empty() and is_same(a.get("hero"), hero):
		taken = maxi(taken, int(a.get("thkDamage", 0)))
	return taken

## Vorpal Blade : « a Hero who has taken damage equal to or greater than half its Health » (impair : arrondi au-dessus).
static func vorpal_targets(G: Dictionary) -> Array:
	var out: Array = []
	for e in all_heroes(G):
		var h: Dictionary = e["hero"]
		var owner := int(e["owner"])
		if owner >= 0 and RoomAbilities.current_hero_hp(G, owner, h) <= 0:
			continue
		var taken := damage_taken(G, owner, h)
		if taken >= 1 and taken >= (BossEngine.hero_base_hp(h) + 1) / 2:
			out.append(e)
	return out

## Objets face visible copiables par Magic Mirror : scorekeeping de tous, ville, attaches aux heros ; hors Magic Mirror lui-meme.
static func mirror_targets(G: Dictionary, pid: int) -> Array:
	var out: Array = []
	var add := func(it: Dictionary, where: String) -> void:
		var id := str(it.get("id", ""))
		if id == "THK011" or effect_check(G, pid, id) != "":
			return
		out.append({"itemId": id, "card": it, "label": "%s (%s)" % [_label(it), where], "ai": score_effect(G, _p(G, pid), pid, id)})
	for q in (G["players"] as Dictionary):
		for it in ((G["players"][q] as Dictionary).get("items", []) as Array):
			if not bool((it as Dictionary).get("faceDown", false)):
				add.call(it, "P%d scorekeeping" % (int(q) + 1))
	for it in (G.get("townItems", []) as Array):
		add.call(it, "town")
	for e in all_heroes(G):
		var hi := item_of(e["hero"])
		if not hi.is_empty():
			add.call(hi, "on %s" % _label(e["hero"]))
	return out

## Pourquoi la capacite de Boss de l'Objet `id` n'est pas jouable maintenant ("" = jouable). Pure : aucun etat touche.
static func effect_check(G: Dictionary, pid: int, id: String) -> String:
	var p := _p(G, pid)
	var phase := str(G.get("phase", ""))
	if not (phase in ["build", "adventure"]):
		return "wrong phase"
	var a := TnlAbilities.adv(G)
	if id.begins_with("IOD"):
		return IodAbilities.effect_check(G, pid, id)
	match id:
		"THK001", "THK002", "THK005":
			return ""
		"THK012":
			return "" if _spells_left(G) > 0 else "no Spell to draw"
		"THK003": return "" if not room_targets(G, pid, "advanced", false).is_empty() else "no Advanced Room"
		"THK004": return "" if not _wounds_ordinary(p).is_empty() else "no ordinary Wound"
		"THK006": return "" if not all_heroes(G).is_empty() else "no Hero"
		"THK007", "THK017": return "" if not a.is_empty() and a.get("hero") is Dictionary else "no Hero in a dungeon"
		"THK008": return "" if not vorpal_targets(G).is_empty() else "no Hero to kill"
		"THK009": return "" if not _opps(G, pid).is_empty() else "no opponent"
		"THK010": return "" if not room_targets(G, pid, "any", true).is_empty() else "no Room"
		"THK011": return "" if not mirror_targets(G, pid).is_empty() else "no Item to copy"
		"THK013": return "" if not _bag_rooms(G).is_empty() else "no Room in the discard"
		"THK014": return "" if not room_targets(G, pid, "any", false).is_empty() else "no Room"
		"THK015": return "" if not room_targets(G, pid, "trap", false).is_empty() else "no Trap Room"
		"THK016": return "" if _my_hero_room(G, pid) >= 0 else "no Hero in a Room of your dungeon"
		"THK018": return "" if not room_targets(G, pid, "monster", false).is_empty() else "no Monster Room"
		"THK019": return "" if not _survivors_this_turn(G, p).is_empty() else "no Hero survived this turn"
		"THK020":
			if (G.get("stack", []) as Array).is_empty() or phase != "adventure" or int(G.get("stackActivePlayer", -1)) != pid:
				return "no Spell to cancel"
			return "" if RoomAbilities._last_opponent_spell_index(G, pid) >= 0 else "no Spell to cancel"
	return "unknown Item"

# --- Objets : effets de la capacite de Boss ("Reward") --------------------------------------------------------------------------------

## Nombre de salles Monster visibles et non gelees du donjon de `pid` (Claws of the Berserker).
static func monster_rooms(G: Dictionary, pid: int) -> int:
	var n := 0
	var d: Array = _p(G, pid).get("dungeon", [])
	for i in d.size():
		var rv = BossEngine.active_room(d[i])
		if rv != null and str((rv as Dictionary).get("type", "")) == "monster" and not bool((rv as Dictionary).get("faceDown", false)) and not BossEngine.is_room_deactivated(G, pid, i):
			n += 1
	return n

static func _room_ai(G: Dictionary, pid: int, id: String, o: Dictionary) -> float:
	var tp := int(o["targetPlayerId"])
	var r: Dictionary = o["card"]
	var ri := int(o["roomIndex"])
	var f := AiWiki.fate(G)
	match id:
		"THK010", "THK015", "THK018": # desactiver : utile devant le heros d'un adversaire (il survit et le blesse)
			if tp == pid:
				return -5.0
			if AiWiki.is_ahead(f, tp, ri):
				return 1.0 + float(BossEngine.room_damage_with_modifiers(G, _p(G, tp), ri, f["hero"]))
			return 0.1
		"THK014": # ignorer le texte : une salle adverse a capacite, devant le heros
			var text := str(r.get("description", "")).strip_edges() != ""
			if tp == pid or not text:
				return -5.0
			return 3.0 if AiWiki.is_ahead(f, tp, ri) else 0.2
	return float(o.get("ai", 0.0))

static func _ask_room(G: Dictionary, pid: int, id: String, opts: Array, msg: String) -> Variant:
	for o in opts:
		(o as Dictionary)["ai"] = _room_ai(G, pid, id, o)
	return TnlAbilities.ask(G, pid, "thk_room", opts, {"id": id}, msg, item_name(id))

## Choix de salle d'une capacite de Boss dont l'etape de resolution est `step` (IodAbilities) ; les poids IA sont ceux de room_options.
static func _ask_room_step(G: Dictionary, pid: int, step: String, id: String, opts: Array, msg: String) -> Variant:
	return TnlAbilities.ask(G, pid, step, opts, {"id": id}, msg, item_name(id))

static func _ask_hero(G: Dictionary, pid: int, id: String, n: int, msg: String) -> Variant:
	var opts: Array = []
	var a := TnlAbilities.adv(G)
	for e in all_heroes(G):
		var h: Dictionary = e["hero"]
		var owner := int(e["owner"])
		var w := 0.0
		if owner >= 0 and not a.is_empty() and is_same(a.get("hero"), h):
			w = 5.0 if owner != pid else -5.0
		opts.append({"card": h, "ownerPid": owner, "label": "%s (%s)" % [_label(h), "town" if owner < 0 else "P%d" % (owner + 1)], "ai": w})
	return TnlAbilities.ask(G, pid, "thk_hero", opts, {"id": id, "n": n}, msg, item_name(id))

static func run_effect(G: Dictionary, pid: int, id: String) -> Variant:
	if id.begins_with("IOD"):
		return IodAbilities.run_effect(G, pid, id)
	var p := _p(G, pid)
	var name := item_name(id)
	var a := TnlAbilities.adv(G)
	match id:
		"THK001": # Extra Life : aucune perte par Blessures ce tour
			_flags(G, "noWounds")[pid] = true
			_log(G, "%s: player %d cannot lose due to Wounds this turn." % [name, pid + 1])
		"THK002": # Holy Hand Grenade : chaque adversaire defausse une salle au hasard
			for o in _opps(G, pid):
				_random_discard(G, int(o), "room", 1, name)
		"THK003":
			return _ask_room(G, pid, id, room_targets(G, pid, "advanced", false), "%s: choose an Advanced Room to destroy" % name)
		"THK004": # Staff of Healing : soigne une Blessure ordinaire
			var opts: Array = []
			for h in _wounds_ordinary(p):
				opts.append({"card": h, "label": _label(h as Dictionary), "ai": float(BossEngine.hero_souls(h as Dictionary))})
			return TnlAbilities.ask(G, pid, "thk_heal", opts, {}, "%s: choose a Wound to heal" % name, name)
		"THK005": # Goblin Suit : toutes vos salles Monster ordinaires +1
			var arr: Array = SpellEffects._effects(G)["ordinaryMonsterBonus"]
			arr.append(pid)
			_log(G, "%s: player %d's ordinary Monster Rooms get +1 until end of turn." % [name, pid + 1])
		"THK006": # Claws of the Berserker : +1 par salle Monster de VOTRE donjon
			return _ask_hero(G, pid, id, monster_rooms(G, pid), "%s: choose a Hero (+%d Health)" % [name, monster_rooms(G, pid)])
		"THK007": # Oversized Sword : le heros d'un donjon +5
			TnlAbilities.add_hero_hp(G, a["hero"], 5)
			_log(G, "%s: %s gets +5 Health until end of turn." % [name, _label(a["hero"])])
		"THK008":
			var kopts: Array = []
			for e in vorpal_targets(G):
				var kh: Dictionary = e["hero"]
				var kown := int(e["owner"])
				var kw := 0.0
				if kown == pid or kown < 0:
					kw = 10.0 + float(BossEngine.hero_souls(kh))
				else:
					kw = -10.0
				kopts.append({"card": kh, "ownerPid": kown, "label": "%s (%s)" % [_label(kh), "town" if kown < 0 else "P%d" % (kown + 1)], "ai": kw})
			return TnlAbilities.ask(G, pid, "thk_kill", kopts, {}, "%s: choose a Hero to kill" % name, name)
		"THK009": # Antimagic Lizard : un adversaire defausse un sort au hasard
			var popts: Array = []
			for o in _opps(G, pid):
				popts.append({"playerId": int(o), "label": "Player %d" % (int(o) + 1), "ai": float(_hand_cards(_p(G, int(o)), "spell").size())})
			return TnlAbilities.ask(G, pid, "thk_opp", popts, {}, "%s: choose an opponent (discards a random Spell)" % name, name)
		"THK010", "THK015", "THK018": # Ice Rod / Ten Foot Pole / Pet Monster : desactive une salle jusqu'a la fin du tour
			var kind := "any" if id == "THK010" else ("trap" if id == "THK015" else "monster")
			return _ask_room(G, pid, id, room_targets(G, pid, kind, id == "THK010"), "%s: choose a %s to deactivate until end of turn" % [name, "Room" if kind == "any" else kind.capitalize() + " Room"])
		"THK011": # Magic Mirror : la capacite de Boss d'un autre Objet face visible
			return TnlAbilities.ask(G, pid, "thk_mirror", mirror_targets(G, pid), {}, "%s: choose a face-up Item to copy" % name, name)
		"THK012": # Necronomicon : pioche un sort
			TnlAbilities.draw_logged(G, pid, "spells", 1, name)
		"THK013": # Bag of Holding : une salle a 2 icones de tresor ou plus depuis la defausse
			var bopts := _bag_rooms(G)
			for o in bopts:
				(o as Dictionary)["label"] = _label((o as Dictionary)["card"])
				(o as Dictionary)["ai"] = TnlAbilities._ai_value((o as Dictionary)["card"])
			return TnlAbilities.ask(G, pid, "thk_bag", bopts, {}, "%s: take a Room with 2 or more treasure icons" % name, name)
		"THK014": # Cheat Code : ignore le texte d'une salle jusqu'a la fin du tour
			return _ask_room(G, pid, id, room_targets(G, pid, "any", false), "%s: choose a Room whose ability text is ignored until end of turn" % name)
		"THK016": # The Bomb : detruit la salle du heros (5 degats a ce heros)
			var ri := _my_hero_room(G, pid)
			var hero: Dictionary = a["hero"]
			TnlAbilities.destroy_room_at(G, pid, ri, name)
			a["hp"] = int(a.get("hp", 0)) - 5
			_log(G, "%s: %s takes 5 damage (%d Health left)." % [name, _label(hero), int(a["hp"])])
		"THK017": # Boots of Jumping : le heros ignore la prochaine salle
			a["thkSkip"] = true
			_log(G, "%s: %s ignores the next Room." % [name, _label(a["hero"])])
		"THK019": # Star of Invulnerability : retire du jeu un heros qui a survecu ce tour
			var sopts: Array = []
			for h in _survivors_this_turn(G, p):
				sopts.append({"card": h, "label": _label(h as Dictionary), "ai": float(BossEngine.hero_wounds(h as Dictionary))})
			return TnlAbilities.ask(G, pid, "thk_remove", sopts, {}, "%s: choose a Hero to remove from the game" % name, name)
		"THK020": # Ring of Invisibility : annule un sort joue pendant votre phase d'aventure
			RoomAbilities.cancel_last_opponent_spell(G, pid, name)
	return null

## Tue un heros hors du combat (Vorpal Blade) ; renvoie un choix de reclamation d'Objet eventuel. Le heros actif meurt par ses PV (_finish_hero).
static func kill_hero(G: Dictionary, killer: int, hero: Dictionary, owner: int) -> Variant:
	var a := TnlAbilities.adv(G)
	if not a.is_empty() and is_same(a.get("hero"), hero):
		a["hp"] = mini(int(a.get("hp", 0)), 0)
		_log(G, "%s is killed." % _label(hero))
		return null
	var q := killer if owner < 0 else owner
	if owner < 0:
		(G["town"] as Array).erase(hero)
	else:
		(_p(G, owner).get("entrance", []) as Array).erase(hero)
	var qp := _p(G, q)
	for _s in BossEngine.hero_souls(hero):
		(qp["souls"] as Array).append(CardDB.soul_entry(hero))
	_log(G, "%s is killed and placed face-down in player %d's scorekeeping area." % [_label(hero), q + 1])
	return claim_item(G, q, detach(hero))

# --- resolution des choix ("tnl-pick" a etape thk_*) ---------------------------------------------------------------------------------

static func resolve_pick(G: Dictionary, pid: int, pc: Dictionary, idx: int) -> Variant:
	var opts: Array = pc.get("options", [])
	var ctx: Dictionary = pc.get("ctx", {}) as Dictionary
	var step := str(pc.get("step", ""))
	var p := _p(G, pid)
	var o: Dictionary = (opts[idx] as Dictionary) if idx >= 0 and idx < opts.size() else {}
	if idx < 0 and step != "thk_ceiling":
		return null
	if step.begins_with("thk_iod_"):
		return IodAbilities.resolve_pick(G, pid, pc, idx)
	if step.begins_with("thk_pcw_"):
		return PcwAbilities.resolve_pick(G, pid, pc, idx)
	match step:
		"thk_claim":
			var item: Dictionary = ctx.get("item", {})
			var cur := face_up_item(p)
			if cur.is_empty() or str(cur.get("id", "")) != str(ctx.get("cur", "")):
				add_item(G, pid, item, false)
				return null
			match str(o.get("mode", "")):
				"use":
					cur["faceDown"] = true
					_log(G, "Player %d uses %s." % [pid + 1, _label(cur)])
					add_item(G, pid, item, false)
					return run_effect(G, pid, str(cur.get("id", "")))
				"swap":
					cur["faceDown"] = true
					add_item(G, pid, item, false)
				_:
					add_item(G, pid, item, true)
		"thk_room":
			var id := str(ctx.get("id", ""))
			var tp := int(o.get("targetPlayerId", -1))
			var ri := int(o.get("roomIndex", -1))
			var rv = SpellEffects.find_room(G, tp, ri)
			if rv == null:
				return null
			match id:
				"THK003":
					TnlAbilities.destroy_room_at(G, tp, ri, item_name(id))
				"THK014":
					TnlAbilities._tag(rv as Dictionary)["noText"] = true
					_log(G, "%s: %s has no ability text until end of turn." % [item_name(id), _label(rv as Dictionary)])
				_:
					(SpellEffects._effects(G)["deactivatedRooms"] as Array).append({"playerId": tp, "roomIndex": ri})
					_log(G, "%s: %s is deactivated until end of turn." % [item_name(id), _label(rv as Dictionary)])
		"thk_hero":
			var hero: Dictionary = o.get("card", {})
			match str(ctx.get("id", "")):
				"THK006":
					TnlAbilities.add_hero_hp(G, hero, int(ctx.get("n", 0)))
					_log(G, "%s: %s gets +%d Health until end of turn." % [item_name("THK006"), _label(hero), int(ctx.get("n", 0))])
		"thk_heal":
			BossEngine.heal_one_wound(p, o.get("card", {}))
			_log(G, "%s: a Wound is healed (%s)." % [item_name("THK004"), _label(o.get("card", {}))])
		"thk_kill":
			return kill_hero(G, pid, o.get("card", {}), int(o.get("ownerPid", -1)))
		"thk_opp":
			_random_discard(G, int(o.get("playerId", -1)), "spell", 1, item_name("THK009"))
		"thk_remove":
			var gone: Dictionary = o.get("card", {})
			var w: Array = p.get("wounds", [])
			for k in range(w.size() - 1, -1, -1):
				if (w[k] as Dictionary).get("hero") == gone:
					w.remove_at(k)
			TnlAbilities._remove_from_game(G, gone)
			_log(G, "%s: %s is removed from the game." % [item_name("THK019"), _label(gone)])
		"thk_bag":
			var got = RoomAbilities.take_discard_card(G, p, o)
			if got != null:
				_log(G, "%s: %s taken from the discard pile." % [item_name("THK013"), _label(got as Dictionary)])
		"thk_mirror":
			_log(G, "%s copies %s." % [item_name("THK011"), item_name(str(o.get("itemId", "")))])
			return run_effect(G, pid, str(o.get("itemId", "")))
		"thk_smithy_item":
			return _smithy_hero_choice(G, pid, o.get("card", {}))
		"thk_smithy_hero":
			var sh: Dictionary = o.get("card", {})
			var sitem: Dictionary = ctx.get("item", {})
			var town_items: Array = G.get("townItems", [])
			if town_items.has(sitem) and item_of(sh).is_empty():
				town_items.erase(sitem)
				sh["item"] = sitem
				_log(G, "Orcish Smithy: %s is attached to %s." % [_label(sitem), _label(sh)])
		"thk_mound_item":
			return _mound_card_choice(G, pid, "thk_mound_c1", {"item": o.get("card", {}), "first": {}})
		"thk_mound_c1":
			return _mound_card_choice(G, pid, "thk_mound_c2", {"item": ctx.get("item", {}), "first": o.get("card", {})})
		"thk_mound_c2":
			var mitem: Dictionary = ctx.get("item", {})
			var c1: Dictionary = ctx.get("first", {})
			var c2: Dictionary = o.get("card", {})
			if (p.get("hand", []) as Array).has(c1) and (p.get("hand", []) as Array).has(c2) and bool(mitem.get("faceDown", false)):
				TnlAbilities.discard_from_hand(G, pid, c1)
				TnlAbilities.discard_from_hand(G, pid, c2)
				mitem["faceDown"] = false
				_log(G, "Burial Mound: %s is flipped face-up." % _label(mitem))
		"thk_ceiling":
			if idx >= 0:
				ceiling_take(G, int(ctx.get("owner", pid)))
	return null

# --- salles : Orcish Smithy (THK021), Burial Mound (THK022), Artificer's Workbench (THK023), Magnetic Ceiling (THK024) -----------------------------

static func smithy_heroes(G: Dictionary) -> Array:
	var out: Array = []
	var a := TnlAbilities.adv(G)
	for e in all_heroes(G):
		var h: Dictionary = e["hero"]
		if item_of(h).is_empty() and not (not a.is_empty() and is_same(a.get("hero"), h)):
			out.append(e)
	return out

## Pure : pourquoi la salle `r` (THK021-023) n'est pas activable ("" = oui).
static func check(G: Dictionary, p: Dictionary, pid: int, idx: int, r: Dictionary) -> String:
	if not active(G):
		return "THK off"
	if bool(r.get("faceDown", false)) or BossEngine.is_room_deactivated(G, pid, idx) or TnlAbilities.no_text(r) or BossEngine.abilities_locked(G, pid):
		return "room is face down, frozen or locked"
	if bool(r.get("usedThisTurn", false)):
		return "already used this turn"
	match str(r.get("id", "")):
		"THK021":
			if str(G.get("phase", "")) != "build":
				return "Build phase only"
			if (G.get("townItems", []) as Array).is_empty():
				return "no unattached Item in town"
			return "" if not smithy_heroes(G).is_empty() else "no Hero without an Item"
		"THK022":
			if face_up_item(p) != {}:
				return "you already have a face-up Item"
			var down := (p.get("items", []) as Array).filter(func(it): return bool((it as Dictionary).get("faceDown", false)))
			if down.is_empty():
				return "no face-down Item"
			return "" if _hand_cards(p, "room").size() >= 2 else "fewer than two Room cards in hand"
		"THK023":
			return "" if not face_up_item(p).is_empty() else "no face-up Item"
	return "no activated ability"

static func _smithy_hero_choice(G: Dictionary, pid: int, item: Dictionary) -> Variant:
	var opts: Array = []
	for e in smithy_heroes(G):
		var h: Dictionary = e["hero"]
		var owner := int(e["owner"])
		var w := 0.0
		if owner >= 0 and owner != pid:
			w = 3.0 # un heros a l'entree d'un adversaire : son Objet joue contre lui... ou pour lui, voir score_activate
		elif owner < 0 and BossEngine.lure_target(G["players"], CardDB.order_by_xp(G["players"]), int(h.get("treasure", 1)), h, G) != pid:
			w = 1.0
		else:
			w = -5.0
		opts.append({"card": h, "ownerPid": owner, "label": "%s (%s)" % [_label(h), "town" if owner < 0 else "P%d" % (owner + 1)], "ai": w})
	return TnlAbilities.ask(G, pid, "thk_smithy_hero", opts, {"item": item}, "Orcish Smithy: attach %s to a Hero" % _label(item), "Orcish Smithy")

static func _mound_card_choice(G: Dictionary, pid: int, step: String, ctx: Dictionary) -> Variant:
	var opts: Array = []
	for c in _hand_cards(_p(G, pid), "room"):
		if c != ctx.get("first", {}):
			opts.append({"card": c, "label": _label(c as Dictionary), "ai": -TnlAbilities._ai_value(c as Dictionary)})
	return TnlAbilities.ask(G, pid, step, opts, ctx, "Burial Mound: discard a Room card (%s)" % ("1/2" if step == "thk_mound_c1" else "2/2"), "Burial Mound")

## Active la salle `r` (THK021-023) du donjon de `pid`. Renvoie null ou une erreur.
static func activate(G: Dictionary, p: Dictionary, pid: int, idx: int, r: Dictionary) -> Variant:
	var err := check(G, p, pid, idx, r)
	if err != "":
		return err
	r["usedThisTurn"] = true
	match str(r.get("id", "")):
		"THK021":
			var opts: Array = []
			for it in (G.get("townItems", []) as Array):
				opts.append({"card": it, "label": _label(it as Dictionary), "ai": item_value(it as Dictionary)})
			TnlAbilities.emit(G, TnlAbilities.ask(G, pid, "thk_smithy_item", opts, {}, "Orcish Smithy: choose an unattached Item", "Orcish Smithy"))
		"THK022":
			var iopts: Array = []
			for it in (p.get("items", []) as Array):
				if bool((it as Dictionary).get("faceDown", false)):
					iopts.append({"card": it, "label": _label(it as Dictionary), "ai": item_value(it as Dictionary)})
			TnlAbilities.emit(G, TnlAbilities.ask(G, pid, "thk_mound_item", iopts, {}, "Burial Mound: choose a face-down Item to flip", "Burial Mound"))
		"THK023": # retourner n'enclenche pas la capacite de Boss
			var it := face_up_item(p)
			it["faceDown"] = true
			_log(G, "Artificer's Workbench: %s is flipped face-down." % _label(it))
			TnlAbilities.draw_logged(G, pid, "spells", 1, "Artificer's Workbench")
	return null

## Magnetic Ceiling : le heros actif de `pid` perd son Objet, place face cachee dans le scorekeeping.
static func ceiling_take(G: Dictionary, pid: int) -> void:
	var a := TnlAbilities.adv(G)
	var hero = a.get("hero")
	if not (hero is Dictionary):
		return
	var it := detach(hero)
	if it.is_empty():
		return
	add_item(G, pid, it, true)
	_log(G, "Magnetic Ceiling: %s's Item is taken." % _label(hero))

# --- crochets du moteur ------------------------------------------------------------------------------------------------------------

## Le heros `hero` commence son aventure chez `pid` (avant la premiere salle) : renvoie ses PV supplementaires.
static func on_hero_start(G: Dictionary, pid: int, hero: Dictionary, hp_now: int = 0) -> int:
	var p := _p(G, pid)
	var bonus := 0
	var staff := _flags(G, "staff")
	if not bool(staff.get(pid, false)):
		for h in (p.get("entrance", []) as Array):
			if item_id(h) == "THK004":
				staff[pid] = true
	if bool(staff.get(pid, false)): # Staff of Healing : tout heros a l'entree +2 jusqu'a la fin du tour
		bonus += 2
		_log(G, "Staff of Healing: %s gets +2 Health until end of turn." % _label(hero))
	if item_id(hero).begins_with("IOD"):
		bonus += IodAbilities.on_hero_start(G, pid, hero, hp_now + bonus)
	match item_id(hero):
		"THK007":
			bonus += 5
		"THK011": # Magic Mirror : l'ordre des salles est inverse avant la premiere salle
			var d: Array = p.get("dungeon", [])
			for i in d.size() / 2:
				TnlAbilities.swap_stacks(G, pid, i, d.size() - 1 - i)
			_log(G, "Magic Mirror: the order of player %d's Rooms is reversed." % (pid + 1))
		"THK015":
			_deactivate_first(G, pid, "trap", "Ten Foot Pole")
		"THK018":
			_deactivate_first(G, pid, "monster", "Pet Monster")
	return bonus

static func _deactivate_first(G: Dictionary, pid: int, kind: String, label: String) -> void:
	var d: Array = _p(G, pid).get("dungeon", [])
	for i in d.size():
		var rv = BossEngine.active_room(d[i])
		if rv != null and not bool((rv as Dictionary).get("faceDown", false)) and str((rv as Dictionary).get("type", "")) == kind and not BossEngine.is_room_deactivated(G, pid, i):
			(SpellEffects._effects(G)["deactivatedRooms"] as Array).append({"playerId": pid, "roomIndex": i})
			_log(G, "%s: %s is deactivated until end of turn." % [label, _label(rv as Dictionary)])
			return

## Claws of the Berserker : +1 PV par salle Monster du donjon, tant qu'elles y restent (ecart applique, comme Druid).
static func sync_hero(G: Dictionary) -> void:
	var a := TnlAbilities.adv(G)
	if a.is_empty() or item_id(a.get("hero")) != "THK006":
		return
	var x := monster_rooms(G, int(a.get("playerId", -1)))
	a["hp"] = int(a.get("hp", 0)) + x - int(a.get("thkClaws", 0))
	a["thkClaws"] = x

## Degats d'une salle pour un heros qui porte un Objet (Goblin Suit, Star of Invulnerability) ; appele par BossEngine.room_damage_with_modifiers.
static func adjust_damage(player: Dictionary, G: Dictionary, room_index: int, r: Dictionary, hero: Dictionary, dmg: int) -> int:
	dmg = IodAbilities.adjust_damage(G, r, hero, dmg) # Force Field
	match item_id(hero):
		"THK005": # pas de degats des salles Monster ordinaires (meme relevees)
			if str(r.get("type", "")) == "monster" and not bool(r.get("advanced", false)):
				return 0
		"THK019": # pas de degats des trois premieres salles (gauche -> droite), les salles gelees ne comptent pas
			var pid := int(player.get("id", 0))
			var n := 0
			var d: Array = player.get("dungeon", [])
			for i in range(0, mini(room_index + 1, d.size())):
				if BossEngine.active_room(d[i]) != null and not BossEngine.is_room_deactivated(G, pid, i):
					n += 1
			if n <= 3:
				return 0
	return dmg

## Cheat Code : tant que ce heros est dans le donjon, le texte des salles de ce donjon est ignore (comme KSA017 Trap Master).
static func cheat_code(G: Dictionary, pid: int) -> bool:
	return active(G) and item_id(TnlAbilities.hero_in_dungeon(G, pid)) == "THK014"

## Ring of Invisibility : pas de sorts pendant la phase d'aventure ou un heros qui le porte est a l'entree (ou dans) le donjon de `pid`.
static func spells_blocked(G: Dictionary, pid: int) -> bool:
	if not active(G):
		return false
	if IodAbilities.spells_blocked(G): # Surprise Box : personne, a aucune phase
		return true
	if str(G.get("phase", "")) != "adventure":
		return false
	for h in (_p(G, pid).get("entrance", []) as Array):
		if item_id(h) == "THK020":
			return true
	return false

## « This turn, you cannot lose due to Wounds » (Extra Life).
static func wound_immune(G: Dictionary, pid: int) -> bool:
	return active(G) and bool(_flags(G, "noWounds").get(pid, false))

## Le heros entre dans la salle `i` (avant les degats). "bomb" : The Bomb detruit la derniere salle, aucun degat ; "pending" : un choix
## (Magnetic Ceiling) est ouvert, la salle sera jouee quand il sera resolu ; "" sinon.
static func on_room_enter(G: Dictionary, pid: int, i: int, room: Dictionary) -> String:
	var a := TnlAbilities.adv(G)
	var hero = a.get("hero")
	if not (hero is Dictionary):
		return ""
	var d: Array = _p(G, pid).get("dungeon", [])
	if item_id(hero) == "THK016" and i == d.size() - 1: # The Bomb : le heros traverse le donjon
		_log(G, "The Bomb: %s destroys the last Room, no damage." % _label(hero))
		TnlAbilities.destroy_room_at(G, pid, i, "The Bomb")
		for k in ["roomGone", "replay", "back"]:
			a.erase(k)
		a["roomIndex"] = i # la salle suivante n'existe plus : le heros atteint le Boss
		a["thkBombed"] = true
		return "bomb"
	if str(room.get("id", "")) == "THK024" and not item_of(hero).is_empty() and not bool(room.get("usedThisTurn", false)) and TnlAbilities.live(G, pid, i, room):
		room["usedThisTurn"] = true
		var opts := [{"label": "Take %s (face-down in your scorekeeping area)" % _label(item_of(hero)), "ai": 5.0}]
		var pc = TnlAbilities.ask(G, pid, "thk_ceiling", opts, {"owner": pid}, "Magnetic Ceiling: place %s's Item face-down in your scorekeeping area?" % _label(hero), "Magnetic Ceiling", true)
		a["enterPending"] = i
		RoomAbilities.enqueue_pending(G, pc as Dictionary)
		return "pending"
	return ""

## Le heros quitte la salle `prev` en vie (il va en `i`) : Ice Rod, Inquisitor's Robes, Bag of Holding, Boots of Jumping. Renvoie l'index de salle a jouer.
static func on_room_exit(G: Dictionary, pid: int, prev: int, i: int) -> int:
	var j := _on_room_exit_thk(G, pid, prev, i)
	if TnlAbilities.adv(G).is_empty():
		return j
	j = IodAbilities.on_room_exit(G, pid, prev, j)
	return PcwAbilities.on_room_exit(G, pid, prev, j)

static func _on_room_exit_thk(G: Dictionary, pid: int, prev: int, i: int) -> int:
	var a := TnlAbilities.adv(G)
	var hero = a.get("hero")
	if a.is_empty() or not (hero is Dictionary):
		return i
	var d: Array = _p(G, pid).get("dungeon", [])
	var id := item_id(hero)
	var skip := bool(a.erase("thkSkip")) # Boots of Jumping (capacite de Boss) : « ignores the next Room »
	skip = bool((hero as Dictionary).erase("iodSkip")) or skip # Portal Wand (Reward) sur un heros qui n'etait pas encore entre
	if prev >= 0 and prev < d.size() and not bool(a.get("thkBombed", false)) and int(a.get("hp", 0)) > 0:
		var rv = BossEngine.active_room(d[prev])
		if rv != null and not bool((rv as Dictionary).get("faceDown", false)) and not BossEngine.is_room_deactivated(G, pid, prev):
			var room: Dictionary = rv
			match id:
				"THK010": # Ice Rod : toute salle que le heros survit est desactivee jusqu'a la fin du tour
					(SpellEffects._effects(G)["deactivatedRooms"] as Array).append({"playerId": pid, "roomIndex": prev})
					_log(G, "Ice Rod: %s is deactivated until end of turn." % _label(room))
				"THK003": # Inquisitor's Robes : la premiere salle avancee survecue est detruite
					if bool(room.get("advanced", false)) and not bool(a.get("thkRobes", false)):
						a["thkRobes"] = true
						TnlAbilities.destroy_room_at(G, pid, prev, "Inquisitor's Robes")
						i = int(a.get("roomIndex", i))
				"THK013": # Bag of Holding : une salle a 2 icones de tresor ou plus survecue est detruite
					if BossEngine.room_treasures(room).size() >= 2:
						TnlAbilities.destroy_room_at(G, pid, prev, "Bag of Holding")
						i = int(a.get("roomIndex", i))
				"THK017":
					skip = true
	if skip:
		d = _p(G, pid).get("dungeon", [])
		var j := i
		while j >= 0 and j < d.size():
			var nv = BossEngine.active_room(d[j])
			if nv != null and not bool((nv as Dictionary).get("faceDown", false)): # une salle desactivee reste « la prochaine Room »
				_log(G, "%s ignores %s." % [_label(hero), _label(nv as Dictionary)])
				return j + 1
			j += 1
	return i

## Extra Life : un heros tue qui porte l'Objet retourne en ville a la place, l'Objet rejoint le scorekeeping du proprietaire du donjon.
static func extra_life(G: Dictionary, pid: int, hero: Dictionary) -> bool:
	if IodAbilities.lich_crown(G, pid, hero): # IOD009 : le heros garde son Objet
		return true
	if item_id(hero) != "THK001":
		return false
	var it := detach(hero)
	var town: Array = G.get("town", [])
	G["town"] = town
	town.append(hero)
	_log(G, "Extra Life: %s returns to town instead of dying." % _label(hero))
	TnlAbilities.emit(G, claim_item(G, pid, it))
	return true

## Le heros a survecu au donjon de `pid` : ses Objets agissent (Vorpal Blade, Holy Hand Grenade, Antimagic Lizard, Necronomicon) puis l'Objet va
## face cachee dans le scorekeeping. Appele avant le controle des 5 Blessures.
static func on_hero_survived(G: Dictionary, pid: int, hero: Dictionary) -> void:
	var id := item_id(hero)
	if id == "":
		return
	match id:
		"THK008": # Vorpal Blade : une Blessure de plus jusqu'a la fin du tour (en tete de pile : jamais soignee par erreur)
			var w: Array = _p(G, pid).get("wounds", [])
			w.push_front({"name": "Vorpal Blade", "wounds": 1, "souls": 0, "class": "", "faceDown": false, "turn": _turn(G), "thkTemp": true})
			_log(G, "Vorpal Blade: player %d takes an additional Wound until end of turn." % (pid + 1))
		"THK002":
			_random_discard(G, pid, "room", 2, "Holy Hand Grenade")
		"THK009":
			_random_discard(G, pid, "spell", 2, "Antimagic Lizard")
		"THK012":
			for o in _opps(G, pid):
				TnlAbilities.draw_logged(G, int(o), "spells", 1, "Necronomicon")
	add_item(G, pid, detach(hero), true)

# --- IA (heuristiques maison : ni l'APK ni le wiki n'en donnent) -----------------------------------------------------------------------

## Score d'un coup `useItem` / d'une reponse en Spell Battle.
static func score_move(G: Dictionary, p: Dictionary, pid: int, mtype: String, args: Array) -> float:
	if mtype != "useItem" or args.is_empty():
		return 0.0
	var id := str(args[0])
	if not (G.get("stack", []) as Array).is_empty() and id != "THK020":
		return -50.0 # Spell Battle : l'IA ne repond qu'avec Ring of Invisibility
	return score_effect(G, p, pid, id)

## Valeur de la capacite de Boss `id` pour `pid` maintenant (> 0 : a jouer). Cartes « de situation » : seulement quand elles changent l'issue.
static func score_effect(G: Dictionary, p: Dictionary, pid: int, id: String) -> float:
	if id.begins_with("IOD"):
		return IodAbilities.score_effect(G, p, pid, id)
	var f := AiWiki.fate(G)
	var mine := bool(f["active"]) and int(f["owner"]) == pid
	var theirs := bool(f["active"]) and int(f["owner"]) != pid
	var build := str(G.get("phase", "")) == "build"
	var anytime := AiWiki.BUILD_FIRST if build else 12.0
	match id:
		"THK001": # Extra Life : seulement pour ne pas perdre par Blessures
			var wounds := CardDB.total_wounds(p)
			return 50.0 if wounds >= 4 or (mine and int(f["margin"]) > 0 and wounds + BossEngine.hero_wounds(f["hero"]) >= 5) else -5.0
		"THK002":
			for o in _opps(G, pid):
				if not _hand_cards(_p(G, int(o)), "room").is_empty():
					return anytime
			return -5.0
		"THK003":
			for o in room_targets(G, pid, "advanced", true):
				if float((o as Dictionary).get("ai", 0.0)) > 0.0:
					return anytime
			return -5.0
		"THK004":
			return anytime if not _wounds_ordinary(p).is_empty() else -5.0
		"THK005": # Goblin Suit : +1 a mes Monster ordinaires devant un heros qui sinon atteint le Boss
			if not mine:
				return -5.0
			var ahead := 0
			var d: Array = p.get("dungeon", [])
			for j in range(maxi(int(f["idx"]) + 1, 0), d.size()):
				var rv = BossEngine.active_room(d[j])
				if rv != null and str((rv as Dictionary).get("type", "")) == "monster" and not bool((rv as Dictionary).get("advanced", false)) and not bool((rv as Dictionary).get("faceDown", false)) and not BossEngine.is_room_deactivated(G, pid, j):
					ahead += 1
			return 60.0 if ahead > 0 and AiWiki.kills(f, ahead) else -5.0
		"THK006":
			return 40.0 if theirs and AiWiki.saves(f, monster_rooms(G, pid)) else -5.0
		"THK007":
			return 40.0 if theirs and AiWiki.saves(f, 5) else -5.0
		"THK008": # Vorpal Blade : tuer mon propre heros qui atteindrait le Boss
			if mine and int(f["margin"]) > 0:
				for e in vorpal_targets(G):
					if is_same((e as Dictionary)["hero"], f["hero"]):
						return 70.0
			return -5.0
		"THK009":
			for o in _opps(G, pid):
				if not _hand_cards(_p(G, int(o)), "spell").is_empty():
					return anytime
			return -5.0
		"THK010":
			return 40.0 if theirs and AiWiki.saves(f, int(f["best"])) else -5.0
		"THK011":
			var best := -5.0
			for o in mirror_targets(G, pid):
				best = maxf(best, float((o as Dictionary)["ai"]))
			return best
		"THK012":
			return anytime
		"THK013":
			return anytime if not _bag_rooms(G).is_empty() else -5.0
		"THK014":
			for o in room_targets(G, pid, "any", true):
				if _room_ai(G, pid, id, o) >= 3.0:
					return 20.0
			return -5.0
		"THK015":
			return 40.0 if theirs and AiWiki.saves(f, int(f["best_trap"])) else -5.0
		"THK018":
			return 40.0 if theirs and AiWiki.saves(f, int(f["best_monster"])) else -5.0
		"THK016": # The Bomb : 5 degats au heros dans ma salle, s'il est a 5 PV ou moins ca le tue
			return 60.0 if mine and int(f["hp"]) >= 1 and int(f["hp"]) <= 5 else -5.0
		"THK017": # Boots : le heros adverse ignore sa prochaine salle
			if not theirs:
				return -5.0
			var tp := int(f["owner"])
			var td: Array = _p(G, tp).get("dungeon", [])
			for j in range(maxi(int(f["idx"]) + 1, 0), td.size()):
				if BossEngine.active_room(td[j]) != null and not BossEngine.is_room_deactivated(G, tp, j):
					return 40.0 if AiWiki.saves(f, BossEngine.room_damage_with_modifiers(G, _p(G, tp), j, f["hero"])) else -5.0
			return -5.0
		"THK019":
			return 30.0 if CardDB.total_wounds(p) >= 2 else 10.0
		"THK020":
			return 55.0
	return -5.0

## Valeur d'une capacite de salle THK activee (Orcish Smithy, Burial Mound, Artificer's Workbench).
static func score_activate(G: Dictionary, p: Dictionary, pid: int, rid: String) -> float:
	var build := str(G.get("phase", "")) == "build"
	var hand_n := (p.get("hand", []) as Array).size()
	match rid:
		"THK021": # Smithy : un Objet qui n'a pas de heros, offert a un heros adverse
			for e in smithy_heroes(G):
				if int((e as Dictionary)["owner"]) != pid:
					return AiWiki.BUILD_FIRST if build else 5.0
			return -5.0
		"THK022": # Mound : remet un Objet en service contre deux salles dont on n'a pas l'usage
			return (AiWiki.BUILD_FIRST if build else 8.0) if hand_n >= 5 else -5.0
		"THK023": # Workbench : un Objet sans emploi vaut un sort
			var it := face_up_item(p)
			return (AiWiki.BUILD_FIRST if build else 8.0) if not it.is_empty() and (not faces_up_ready(G, it) or effect_check(G, pid, str(it.get("id", ""))) != "") and TnlAbilities.spells_in_hand(p) <= 1 else -5.0
	return -10.0

## Excavation (THK025) : retourner l'Objet face visible d'un adversaire, ou remettre en service le mien.
static func score_excavation(G: Dictionary, pid: int, target: Dictionary) -> float:
	var tp := int(target.get("targetPlayerId", pid))
	var items: Array = _p(G, tp).get("items", [])
	var ti := int(target.get("itemIndex", -1))
	if ti < 0 or ti >= items.size():
		return -20.0
	var down := bool((items[ti] as Dictionary).get("faceDown", false))
	if tp != pid and not down:
		return 30.0
	if tp == pid and down:
		return 25.0
	return -20.0
