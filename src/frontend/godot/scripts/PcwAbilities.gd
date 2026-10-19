class_name PcwAbilities
extends RefCounted
## Les 6 cartes « The Player's Choice » (KSA) que l'APK ne joue pas : Ghoulyard (KSA008), Shark Tank (KSA009), Bone Crank (KSA010), Trash Compactor
## (KSA011), Agent of Evil (KSA012), Pixel Lincoln (KSA015). Absentes du paquet PlayerChoice de l'APK (qui n'a que 7 boss, 3 heros epiques, 1 sort) :
## elles forment le pseudo-paquet `players-choice-wiki` (set des cartes), pose par Main quand « players-choice » est coche ET la case wiki aussi.
## Source : texte des cartes (cards.json, wiki « List of Cards ») + FAQ de docs/rules/rules.md (Ghoulyard, Trash Compactor, Bone Crank, Pixel Lincoln).
## Le paquet `players-choice` seul garde les cartes de l'APK : rien d'ici n'agit sans la case wiki (les cartes ne sont pas dans les pioches).

const SET_ID := "players-choice-wiki"
const ROOMS := ["KSA008", "KSA009", "KSA010", "KSA011"]

static func _p(G: Dictionary, pid: int) -> Dictionary:
	return TnlAbilities._player(G, pid)

static func _log(G: Dictionary, t: String) -> void:
	TnlAbilities._log(G, t)

static func _live(G: Dictionary, pid: int, r: Dictionary) -> bool:
	return not bool(r.get("faceDown", false)) and not TnlAbilities.no_text(r) and not BossEngine.abilities_locked(G, pid)

## Bonus de degats de la salle `r` (index `room_index` du donjon de `pid`) pour `hero` : Shark Tank +2 si le heros a deja subi la moitie de sa Sante.
static func damage_bonus(G: Dictionary, pid: int, r: Dictionary, hero, own_off: bool) -> int:
	if own_off or not (hero is Dictionary) or str(r.get("id", "")) != "KSA009":
		return 0
	var taken := ThkAbilities.damage_taken(G, pid, hero as Dictionary)
	return 2 if taken >= 1 and taken >= (BossEngine.hero_base_hp(hero as Dictionary) + 1) / 2 else 0

## Ghoulyard : « double damage to Epic Heroes », apres tous les bonus et malus des autres cartes (FAQ).
static func double_for(r: Dictionary, hero, dmg: int, own_off: bool) -> int:
	if not own_off and hero is Dictionary and str(r.get("id", "")) == "KSA008" and bool((hero as Dictionary).get("epic", false)):
		return dmg * 2
	return dmg

## Trash Compactor : « if any Hero exits this Room without dying, it deals zero damage until end of turn » (meme drapeau que Fairy Fountain : plus rien ne le releve).
static func on_room_exit(G: Dictionary, pid: int, prev: int, i: int) -> int:
	var a := TnlAbilities.adv(G)
	var d: Array = _p(G, pid).get("dungeon", [])
	if prev >= 0 and prev < d.size() and int(a.get("hp", 0)) > 0 and not bool(a.get("thkBombed", false)):
		var rv = BossEngine.active_room(d[prev])
		if rv != null and str((rv as Dictionary).get("id", "")) == "KSA011" and _live(G, pid, rv as Dictionary) and not BossEngine.is_room_deactivated(G, pid, prev):
			TnlAbilities._tag(rv as Dictionary)["fairy"] = true
			_log(G, "Trash Compactor: no more damage until end of turn.")
	return i

## Bone Crank : a la pose, desactive une salle de n'importe quel donjon jusqu'a la fin du tour.
static func on_build(G: Dictionary, pid: int, room: Dictionary) -> Variant:
	if str(room.get("id", "")) != "KSA010":
		return null
	var opts := ThkAbilities.room_targets(G, pid, "any", false)
	var f := AiWiki.fate(G)
	for o in opts: # une salle d'un adversaire devant son heros d'abord ; jamais la mienne
		var od: Dictionary = o
		var tp := int(od["targetPlayerId"])
		od["ai"] = -5.0 if tp == pid else (10.0 if AiWiki.is_ahead(f, tp, int(od["roomIndex"])) else 0.1) + float((od["card"] as Dictionary).get("damage", 0)) * 0.1
	return TnlAbilities.ask(G, pid, "thk_pcw_deact", opts, {}, "Bone Crank: choose a Room to deactivate until end of turn", "Bone Crank")

## Pixel Lincoln (revele en ville) : chaque joueur, par XP, choisit combien de sorts piocher (0 a 3). Renvoie le premier choix (la suite est chainee).
static func lincoln_start(G: Dictionary) -> Variant:
	var left: Array = []
	for pid in CardDB.order_by_xp(G["players"]):
		if not bool(_p(G, int(pid)).get("eliminated", false)):
			left.append(int(pid))
	return lincoln_choice(G, left)

static func lincoln_choice(G: Dictionary, left: Array) -> Variant:
	if left.is_empty():
		return null
	var pid := int(left[0])
	var rest := left.slice(1)
	var opts: Array = []
	var hands := _hands(G)
	for n in range(0, 4):
		# Piocher fait envoyer Pixel Lincoln (15 PV) au joueur qui a le plus de cartes : seulement si son donjon le tue.
		var mine: int = int(hands.get(pid, 0)) + n
		var top := true
		for q in hands:
			if int(q) != pid and int(hands[q]) >= mine:
				top = false
		var w := float(n) * 0.5
		if top and n > 0:
			w -= 2.0 if AiWiki.dungeon_damage(G, _p(G, pid), {"hp": 15, "epic": true}) < 15 else -1.0
		opts.append({"count": n, "label": "Draw %d Spell(s)" % n, "ai": w})
	return TnlAbilities.ask(G, pid, "thk_pcw_lincoln", opts, {"left": rest}, "Pixel Lincoln: how many Spells do you draw (up to three)?", "Pixel Lincoln")

static func _hands(G: Dictionary) -> Dictionary:
	var out := {}
	for pid in TnlAbilities._alive(G):
		out[int(pid)] = (_p(G, int(pid)).get("hand", []) as Array).size()
	return out

static func resolve_pick(G: Dictionary, pid: int, pc: Dictionary, idx: int) -> Variant:
	var opts: Array = pc.get("options", [])
	var ctx: Dictionary = pc.get("ctx", {}) as Dictionary
	var o: Dictionary = (opts[idx] as Dictionary) if idx >= 0 and idx < opts.size() else {}
	match str(pc.get("step", "")):
		"thk_pcw_deact":
			var tp := int(o.get("targetPlayerId", -1))
			var ri := int(o.get("roomIndex", -1))
			var rv = SpellEffects.find_room(G, tp, ri)
			if rv != null:
				(SpellEffects._effects(G)["deactivatedRooms"] as Array).append({"playerId": tp, "roomIndex": ri})
				_log(G, "Bone Crank: %s is deactivated until end of turn." % str((rv as Dictionary).get("name", "?")))
		"thk_pcw_lincoln":
			var n := int(o.get("count", 0))
			if n > 0:
				TnlAbilities.draw_logged(G, pid, "spells", n, "Pixel Lincoln")
			return lincoln_choice(G, (ctx.get("left", []) as Array).duplicate())
	return null

## Agent of Evil : un heros de la ville va a l'entree du donjon d'un adversaire.
static func agent_targets(G: Dictionary, pid: int) -> Array:
	var out: Array = []
	for i in (G.get("town", []) as Array).size():
		for o in TnlAbilities._opponents(G, pid):
			out.append({"townIndex": i, "targetPlayerId": int(o)})
	return out

static func cast_agent(G: Dictionary, caster_id: int, target: Dictionary) -> bool:
	var town: Array = G.get("town", [])
	var idx := int(target.get("townIndex", -1))
	var tp := int(target.get("targetPlayerId", -1))
	if idx < 0 or idx >= town.size() or tp < 0 or tp == caster_id or bool(_p(G, tp).get("eliminated", true)):
		_log(G, "Agent of Evil: no legal target.")
		return false
	var hero: Dictionary = town[idx]
	town.remove_at(idx)
	var ent: Array = _p(G, tp).get("entrance", []) as Array
	ent.append(hero)
	_p(G, tp)["entrance"] = ent
	_log(G, "Agent of Evil: %s is placed at the entrance of player %d's dungeon." % [str(hero.get("name", "?")), tp + 1])
	return true

## IA : un heros a Sante elevee envoye chez l'adversaire dont le donjon le tue le moins ; jamais chez un adversaire plus faible que moi.
static func score_agent(G: Dictionary, pid: int, target: Dictionary) -> float:
	var town: Array = G.get("town", [])
	var idx := int(target.get("townIndex", -1))
	var tp := int(target.get("targetPlayerId", -1))
	if idx < 0 or idx >= town.size() or tp < 0:
		return -20.0
	var hero: Dictionary = town[idx]
	var dmg := AiWiki.dungeon_damage(G, _p(G, tp), hero)
	var hp := BossEngine.hero_hp(hero)
	return 40.0 if hp > dmg else (5.0 if hp > dmg - 2 else -10.0) # il blesse l'adversaire, ou il ne le sert pas
