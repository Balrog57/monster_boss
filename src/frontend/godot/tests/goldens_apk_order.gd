extends RefCounted
## Goldens de l'ordre d'aleatoire et des evenements de l'APK (lots L1 / L2 de l'audit : R-D03, R-D15, R-D18, R-D19, R-D49, R-D53, R-D68, R-D90, R-F76).
## Chaque cas cite la classe C# (apk-original/decompiled/DBMGame) dont il fige le comportement.
## Appele par goldens.gd : `load("res://godot/tests/goldens_apk_order.gd").new().run(_ok, self)`.

var _ok: Callable
var host: Node

func run(ok: Callable, h: Node) -> void:
	_ok = ok
	host = h
	_t_dbm_matches_dotnet()
	_t_seeded_new_match()
	_t_probe_purity()
	_t_deck_load_order()
	_t_ai_boss_follows_apk()
	_t_mulligan_unbounded()
	_t_turn_draw_by_xp()
	_t_reveal_all_rooms_seat_order()
	_t_spell_discarded_at_cast()
	_t_is_alive_live()
	_t_sync_alive_in_adventure()
	_t_frozen_slot_opens_window()
	_t_destroy_room_discards_before_trigger()
	_t_hidden_heroes_text()
	_t_tutorial_hands()
	_t_random_pick_uses_game_dbm()

# --- fabrique d'etats minimaux ----------------------------------------------------------------------

func _card(arr: Array, id: String) -> Dictionary:
	for c in arr:
		if str((c as Dictionary).get("id", "")) == id:
			return (c as Dictionary).duplicate(true)
	push_error("carte introuvable " + id)
	return {}

func _room(id: String, type: String = "trap", treasures: Array = [1], damage: int = 1, advanced: bool = false) -> Dictionary:
	return {"id": id, "name": id, "type": type, "advanced": advanced, "treasures": treasures, "damage": damage, "isRoom": true}

func _hero(id: String) -> Dictionary:
	var h := _card(CardDB.heroes, id)
	h["souls"] = 2 if bool(h.get("epic", false)) else 1
	h["wounds"] = h["souls"]
	return h

func _player(pid: int, boss_id: String, dungeon: Array = [], xp: int = -1) -> Dictionary:
	var stacks: Array = []
	for r in dungeon:
		stacks.append([r])
	var boss := _card(CardDB.bosses, boss_id)
	if xp >= 0:
		boss["xp"] = xp
	return {"id": pid, "boss": boss, "dungeon": stacks, "hand": [], "souls": [], "wounds": [],
		"entrance": [], "eliminated": false, "leveledUp": false, "buildsThisTurn": 0}

func _G(players: Array) -> Dictionary:
	var ps := {}
	for p in players:
		ps[int((p as Dictionary)["id"])] = p
	return {"players": ps, "town": [], "log": [], "logs": [], "adventure": {}, "turn": 1, "phase": "build",
		"effects": SpellEffects.empty_effects(),
		"decks": {"rooms": [], "spells": [], "heroes": [], "epics": [], "items": [], "roomDiscard": [], "spellDiscard": [], "heroDiscard": []}}

func _match(G: Dictionary) -> Node:
	var m = load("res://godot/scripts/Match.gd").new()
	host.add_child(m)
	m.G = G
	return m

func _ids(cards: Array) -> Array:
	return cards.map(func(c): return str((c as Dictionary).get("id", "")))

# --- R-D15 : DBMRandom = System.Random du .NET, pour TOUTE graine ------------------------------------------

## Valeurs de System.Random(seed).Next(1000) x6 mesurees avec le .NET (dotnet fsi) : une graine > MSEED (161 803 398) fait deborder les soustractions int32 de l'initialisation,
## RandomProvider.SetNewRandomSeed tire la graine dans tout [0, int.MaxValue) ; sans bouclage int32 Next(max) sortait de l'intervalle (cartes en double, paquets vides).
func _t_dbm_matches_dotnet() -> void:
	var want := {
		1: [248, 110, 467, 771, 657, 432], 2832: [234, 778, 302, 28, 813, 437], 161803399: [285, 473, 487, 219, 500, 58],
		1500000000: [9, 202, 484, 436, 854, 582], 2000000001: [626, 290, 422, 942, 188, 797], 2147483646: [203, 523, 69, 344, 754, 684]}
	for s in want:
		var r := DbmRandom.new(int(s))
		var got: Array = []
		for _i in 6:
			got.append(r.next_int(1000))
		_ok.call(got == want[s], "DBMRandom graine %d : memes tirages que System.Random (obtenu %s)" % [s, str(got)])
	var bad := 0
	var seeds := RandomNumberGenerator.new()
	seeds.seed = 7
	for _k in 400:
		var seen := {}
		for x in DbmRandom.new(seeds.randi_range(1, 2147483646)).shuffle(range(21)):
			seen[x] = true
		if seen.size() != 21:
			bad += 1
	_ok.call(bad == 0, "DBMRandom : Shuffle() est une permutation pour 400 graines tirees dans tout l'intervalle (%d en defaut)" % bad)
	# Shuffle().Take(k) = les k premiers elements rendus de Shuffle(), memes tirages
	var full := DbmRandom.new(99).take(range(10), 10)
	var part := DbmRandom.new(99).take(range(10), 3)
	_ok.call(part == full.slice(0, 3), "DBMRandom : take(k) = prefixe de Shuffle() (paresseux)")

# --- R-D15 : initialisation de la partie par un generateur seede, dans l'ordre de GameBoard.InternalInititalizeGameBoard ---

func _signature(G: Dictionary) -> String:
	var d: Dictionary = G["decks"]
	return "%s|%s|%s|%s|%s" % [str(G["humanBoss"]), str(_ids(d["heroes"])), str(_ids(d["epics"])), str(_ids(d["rooms"])), str(_ids(d["spells"]))]

func _t_seeded_new_match() -> void:
	var m = load("res://godot/scripts/Match.gd").new()
	host.add_child(m)
	var a: Dictionary = m.new_match(3, 1, ["base"], 4242)
	var sa := _signature(a)
	var b: Dictionary = m.new_match(3, 1, ["base"], 4242)
	var c: Dictionary = m.new_match(3, 1, ["base"], 4243)
	_ok.call(sa == _signature(b), "new_match(graine) : meme graine, memes paquets, memes mains et meme boss de l'humain")
	_ok.call(sa != _signature(c), "new_match(graine) : une autre graine change les paquets")
	_ok.call(a["dbm"] is Dictionary and int(a["dbm"]["n"]) > 0 and str(a["humanBoss"]) != "", "new_match : le generateur de la partie est dans G (dbm) et le boss de l'humain est tire en premier")
	# les mains d'ouverture viennent du meme flux : boss de l'humain tire par la partie, boss des IA par apk_ai_boss, memes mains
	var hands: Array = []
	for G in [a, b]:
		m.G = G
		m.apply_move(0, {"type": "pickBoss", "args": [str(G["humanBoss"])]})
		for ai in [1, 2]:
			m.apply_move(ai, {"type": "pickBoss", "args": [m.apk_ai_boss(ai)]})
		var h: Array = []
		for pid in [0, 1, 2]:
			h.append(str(G["players"][pid]["boss"]["id"]) if G["players"][pid]["boss"] != null else "?")
			h.append_array(_ids(G["players"][pid]["hand"]))
		hands.append(h)
	_ok.call(hands[0] == hands[1] and (a["players"][0]["hand"] as Array).size() >= 5 and str(a["players"][0]["boss"]["id"]) == str(a["humanBoss"]),
		"mains d'ouverture et boss des IA reproductibles pour une graine donnee (%s)" % str(hands[0]))
	m.queue_free()

## Une sonde de legal_moves travaille sur G.duplicate(true) : elle ne doit jamais consommer le generateur de la partie.
func _t_probe_purity() -> void:
	var m = load("res://godot/scripts/Match.gd").new()
	host.add_child(m)
	var G: Dictionary = m.new_match(2, 1, ["base"], 31337)
	var n0: int = int(G["dbm"]["n"])
	var probe: Dictionary = G.duplicate(true)
	probe["decks"]["rooms"].clear()
	probe["decks"]["roomDiscard"] = [_room("X"), _room("Y"), _room("Z")]
	var drawn := CardDB.draw_pile(probe["decks"], "rooms", 2, null, CardDB.dbm_of(probe))
	_ok.call(drawn.size() == 2 and int(probe["dbm"]["n"]) > n0, "sonde : la copie remelange la defausse avec son propre generateur")
	_ok.call(int(G["dbm"]["n"]) == n0 and G["decks"]["roomDiscard"].is_empty(), "sonde : le generateur et les paquets de la partie ne bougent pas")
	m.queue_free()

# --- R-D03 : mulligan sans borne (GameBoard.AvoidMulliganCondition) ---------------------------------------

## 2 salles ordinaires + 38 avancees : seule la main qui contient les deux ordinaires est bonne (1,3 % des tirages, ~78 melanges en moyenne). L'APK boucle sans borne ;
## l'ancienne borne de 100 laissait la main mauvaise dans ~28 % des cas. 20 graines : aucune main mauvaise.
func _t_mulligan_unbounded() -> void:
	var m = load("res://godot/scripts/Match.gd").new()
	host.add_child(m)
	var bad := 0
	for seed_value in range(1, 21):
		var deck: Array = [_room("O1", "trap", [], 1, false), _room("O2", "trap", [], 1, false)]
		for i in 38:
			deck.append(_room("A%d" % i, "trap", [], 1, true))
		m.G = {"dbm": DbmRandom.new(seed_value).st, "decks": {"rooms": deck, "roomDiscard": []}}
		var hand: Array = m._draw_opening_rooms(deck)
		if Match._bad_opening_rooms(hand) or deck.size() != 35 or hand.size() != 5:
			bad += 1
	_ok.call(bad == 0, "mulligan sans borne : 20 graines, 2 ordinaires + 38 avancees, aucune main mauvaise gardee (%d)" % bad)
	m.queue_free()

# --- R-D18 : pioche de debut de tour dans l'ordre de InGamePlayersPriorized ---------------------------------

## Pioche d'une seule carte puis defausse remelangee : le premier servi (XP le plus haut, GameBoard.cs:360-393) recoit la carte de la pioche, pas le joueur du siege 0.
func _t_turn_draw_by_xp() -> void:
	var p0 := _player(0, "BMA001", [], 1)
	var p1 := _player(1, "BMA002", [], 9)
	var G := _G([p0, p1])
	G["decks"]["rooms"] = [_room("TOP")]
	G["decks"]["roomDiscard"] = [_room("OLD")]
	var m := _match(G)
	m._start_turn()
	_ok.call(_ids(p1["hand"]) == ["TOP"] and _ids(p0["hand"]) == ["OLD"],
		"debut de tour : le joueur a l'XP le plus haut pioche en premier (p1 %s, p0 %s)" % [str(_ids(p1["hand"])), str(_ids(p0["hand"]))])
	m.queue_free()

# --- R-D19 : RevealAllRoomCards parcourt Players (ordre des sieges), pas l'ordre d'XP --------------------------

## KSA002 Hellcow (siege 1, XP le plus haut) monte de niveau pendant la revelation : le siege 0 est traite AVANT lui, sa salle posee ce tour est donc deja revelee.
## En ordre d'XP, le siege 0 etait traite apres et sa nouvelle salle restait « en attente ».
func _t_reveal_all_rooms_seat_order() -> void:
	var p0 := _player(0, "BMA001", [_room("X"), _room("Y"), _room("Z")], 1)
	(p0["dungeon"][0][0] as Dictionary)["faceDown"] = true
	var p1 := _player(1, "KSA002", [_room("A"), _room("B"), _room("C"), _room("D"), _room("E")], 9)
	(p1["dungeon"][0][0] as Dictionary)["faceDown"] = true
	var G := _G([p0, p1])
	var m := _match(G)
	var lv: Dictionary = {}
	var kinds: Array = []
	var queue: Array = m._build_reveal_queue()
	for it in queue:
		kinds.append("%s:%s" % [str((it as Dictionary).get("kind", "")), str((it as Dictionary).get("pid", ""))])
		if str((it as Dictionary).get("kind", "")) == "levelup" and int(it["pid"]) == 1:
			lv = it
	_ok.call(not lv.is_empty() and not (lv.get("pend", {}) as Dictionary).has("0"),
		"RevealAllRoomCards : le siege 0 (traite avant Hellcow) n'a plus de salle en attente (file %s, pend %s)" % [str(kinds), str(lv.get("pend"))])
	# la file reste triee par PlayerId (XP decroissant) : le joueur 1 d'abord
	var first_pid := int((queue[0] as Dictionary)["pid"]) if not queue.is_empty() else -1
	_ok.call(first_pid == 1, "RevealAllRoomCards : la file de resolution reste triee par XP (premier : joueur %d)" % first_pid)
	m.queue_free()

# --- R-D68 : un sort quitte la main pour la defausse AU LANCEMENT (GameBoard.OnAbilityApplyRequest) -------------

func _spell_move(m: Node, pid: int) -> Dictionary:
	for cand in m.legal_moves(pid):
		if str((cand as Dictionary).get("type", "")) == "playSpell":
			return cand
	return {}

func _t_spell_discarded_at_cast() -> void:
	var p0 := _player(0, "BMA001", [_room("T")], 5)
	p0["hand"] = [{"id": "BMA050", "name": "Motivation", "isSpell": true}]
	var p1 := _player(1, "BMA002", [_room("F"), _room("F2")], 4) # Motivation exige un donjon adverse plus grand
	var G := _G([p0, p1])
	var m := _match(G)
	var ok: bool = m.apply_move(0, _spell_move(m, 0))
	var disc: Array = G["decks"]["spellDiscard"]
	_ok.call(ok and p0["hand"].is_empty() and _ids(disc) == ["BMA050"] and not (G.get("stack", []) as Array).is_empty(),
		"sort : en defausse des le lancement, la pile n'est pas encore resolue (defausse %s)" % str(_ids(disc)))
	m.apply_move(1, {"type": "pass", "args": []})
	_ok.call(_ids(G["decks"]["spellDiscard"]) == ["BMA050"], "sort : une seule fois en defausse apres la resolution")
	m.queue_free()
	# Counterspell : les deux sorts sont deja en defausse avant la resolution, le sort annule aussi
	var q0 := _player(0, "BMA001", [_room("T")], 5)
	q0["hand"] = [{"id": "BMA050", "name": "Motivation", "isSpell": true}]
	var q1 := _player(1, "BMA002", [_room("F"), _room("F2")], 4)
	q1["hand"] = [{"id": "BMA043", "name": "Counterspell", "isSpell": true}]
	var G2 := _G([q0, q1])
	var m2 := _match(G2)
	m2.apply_move(0, _spell_move(m2, 0))
	var stack_id: String = str((G2.get("stack", []) as Array)[0]["id"]) if not (G2.get("stack", []) as Array).is_empty() else ""
	var counter: Dictionary = {}
	for cand in m2.legal_moves(1):
		if str((cand as Dictionary).get("type", "")) == "playSpell" and (cand as Dictionary)["args"].size() > 1 and str(((cand as Dictionary)["args"][1] as Dictionary).get("stackId", "")) == stack_id:
			counter = cand
	m2.apply_move(1, counter)
	_ok.call((G2["decks"]["spellDiscard"] as Array).size() == 2 and (q0["hand"] as Array).is_empty() and (q1["hand"] as Array).is_empty(),
		"Counterspell : sort et contre-sort en defausse avant toute resolution (%d)" % (G2["decks"]["spellDiscard"] as Array).size())
	m2.queue_free()

# --- R-D53 : Boss.IsAlive est en direct, IsManuallyKilled est un drapeau a part --------------------------

func _wounds(n: int) -> Array:
	var w: Array = []
	for _i in n:
		w.append({"wounds": 1, "souls": 1, "name": "x"})
	return w

func _t_is_alive_live() -> void:
	var p := _player(0, "BMA001")
	var G := _G([p, _player(1, "BMA002")])
	p["wounds"] = _wounds(5)
	BossEngine.refresh_alive(G)
	_ok.call(bool(p["eliminated"]), "IsAlive : 5 blessures = elimine")
	p["wounds"] = _wounds(4)
	BossEngine.refresh_alive(G)
	_ok.call(not bool(p["eliminated"]), "IsAlive : une blessure retiree (Finish Him!, Vampire Bordello) rend le boss a la partie")
	BossEngine.kill_manually(G, 0)
	_ok.call(bool(p["eliminated"]), "KillManually : elimine malgre 4 blessures")
	p["wounds"] = []
	BossEngine.refresh_alive(G)
	_ok.call(bool(p["eliminated"]), "KillManually : le drapeau manuel survit aux soins (IsAlive = !IsManuallyKilled && Wounds < 5)")
	# Vampire Bordello (BMA015?) : soigne -> remis en jeu via refresh_alive
	var q := _player(0, "BMA001")
	q["wounds"] = _wounds(5)
	q["eliminated"] = true
	var G2 := _G([q, _player(1, "BMA002")])
	q["wounds"] = []
	BossEngine.refresh_alive(G2)
	_ok.call(not bool(q["eliminated"]), "IsAlive : sans blessure, un boss elimine par blessures revient")

## Un boss qui tombe a 5 blessures APRES la verification de _finish_hero (TNL100 Necromancer, sort) : IsAlive est deja faux. Il perd ses heros a l'entree et passe la main
## (GameBoard.ChooseNextActiveHero) ; sans cela la partie calait en phase d'aventure, joueur actif elimine.
func _t_sync_alive_in_adventure() -> void:
	var p0 := _player(0, "BMA001", [_room("A")], 9)
	p0["wounds"] = _wounds(5)
	p0["entrance"] = [_hero("BMA056")]
	var p1 := _player(1, "BMA002", [_room("B")], 4)
	p1["entrance"] = [_hero("BMA058")]
	var G := _G([p0, p1])
	G["phase"] = "adventure"
	G["xpOrder"] = [0, 1]
	G["activePlayer"] = 0
	var m := _match(G)
	m._sync_alive()
	_ok.call(bool(p0["eliminated"]) and (p0["entrance"] as Array).is_empty() and bool(p0["passed"]) and int(G["activePlayer"]) == 1,
		"IsAlive en aventure : le boss tombe a 5 blessures perd ses heros a l'entree et la main passe (actif %s)" % str(G.get("activePlayer")))
	m.queue_free()

# --- R-D49 : un emplacement gele ouvre la fenetre de sorts ----------------------------------------------

func _t_frozen_slot_opens_window() -> void:
	var p0 := _player(0, "BMA001", [_room("A"), _room("B")], 5)
	var G := _G([p0, _player(1, "BMA002")])
	G["phase"] = "adventure"
	G["adventure"] = {"playerId": 0, "hero": _hero("BMA056"), "hp": 6, "roomIndex": -1, "nearest": -1}
	(G["effects"] as Dictionary)["deactivatedRooms"] = [{"playerId": 0, "roomIndex": 0}]
	var m := _match(G)
	m._advance_adventure_room()
	var adv: Dictionary = G["adventure"]
	_ok.call(int(adv["roomIndex"]) == 0 and adv.get("pause") == "post-damage" and int(adv["hp"]) == 6,
		"emplacement gele : le heros le traverse sans degats et la fenetre de sorts s'ouvre (pause %s, PV %s)" % [str(adv.get("pause")), str(adv.get("hp"))])
	m.queue_free()

# --- R-D90 : DestroyRoom defausse la salle AVANT WhenAnotherRoomIsDestroyed ---------------------------------

## Recycling Center (BMA031) pioche 2 salles : pioche vide, la defausse remelangee contient deja la salle detruite (une seule autre carte en defausse).
func _t_destroy_room_discards_before_trigger() -> void:
	var p0 := _player(0, "BMA001", [_room("BMA031"), _room("VICTIM")], 5)
	var G := _G([p0, _player(1, "BMA002")])
	G["decks"]["roomDiscard"] = [_room("OTHER")]
	var m := _match(G)
	BossEngine.destroy_room(p0, 1, G)
	var got := _ids(p0["hand"])
	got.sort()
	_ok.call(got == ["OTHER", "VICTIM"], "Recycling Center : la salle detruite est deja en defausse quand la pioche se remelange (main %s)" % str(got))
	m.queue_free()

# --- R-F76 : les heros Hidden Heroes (BMH) n'ont pas de texte dans l'APK ----------------------------------

func _t_hidden_heroes_text() -> void:
	var n := 0
	var texted: Array = []
	for h in CardDB.heroes:
		if str((h as Dictionary).get("id", "")).begins_with("BMH"):
			n += 1
			if str(h.get("description", "")) != "":
				texted.append(str(h["id"]))
	_ok.call(n == 41 and texted.is_empty(), "BMH : 41 heros, description vide comme dans data.json de l'APK (%d, avec texte : %s)" % [n, str(texted)])

# --- R-D81 : tutoriel (GamePlayTutScene / InitializeGameBoardTutorial : graine 2832, cartes imposees en tete de pioche) ---------------

## Les cartes imposees forment les mains d'ouverture (sans mulligan) : salles 032 026 034 027 016 + sorts 041 055 pour l'humain, 010 020 019 009 021 pour l'IA.
## Le reste des pioches suit DBMRandom(2832) : ui_smoke X-M60 le compare a la trace de l'oracle (--seed 2832).
func _t_tutorial_hands() -> void:
	var gm := GameManager.new()
	host.add_child(gm)
	gm.start_tutorial()
	gm.apply_move(0, {"type": "pickBoss", "args": ["BMA003"]})
	var hand: Array = gm.G["players"][0]["hand"]
	var rooms: Array = _ids(hand.filter(func(c): return not bool(c.get("isSpell", false))))
	var spells: Array = _ids(hand.filter(func(c): return bool(c.get("isSpell", false))))
	_ok.call(rooms == ["BMA032", "BMA026", "BMA034", "BMA027", "BMA016"] and spells == ["BMA041", "BMA055"],
		"tutoriel : main d'ouverture de l'humain = cartes imposees, sans mulligan (salles %s, sorts %s)" % [str(rooms), str(spells)])
	var ai_rooms: Array = _ids((gm.G["players"][1]["hand"] as Array).filter(func(c): return not bool(c.get("isSpell", false)))) + _ids(gm.G["decks"]["roomDiscard"])
	ai_rooms.sort()
	_ok.call(ai_rooms == ["BMA009", "BMA010", "BMA019", "BMA020", "BMA021"], "tutoriel : main d'ouverture de l'IA = 010 020 019 009 021 (obtenu %s)" % str(ai_rooms))
	gm.queue_free()

# --- R-D15 : les tirages « au hasard » en cours de partie passent par le generateur de la partie ---------------------------------

## PickRandomCardFromHand / DiscardRandomCardFromHand : `salles puis sorts .Shuffle().Take(1)` sur RandomProvider (un seul Next). Main Godot dans l'ordre sort, salle, salle.
func _t_random_pick_uses_game_dbm() -> void:
	var spell := {"id": "SP", "name": "SP", "isSpell": true}
	var victim := _player(1, "BMA002")
	victim["hand"] = [spell, _room("RA"), _room("RB")]
	var G := _G([_player(0, "BMA001"), victim])
	G["dbm"] = DbmRandom.new(77).st
	var want_idx: int = DbmRandom.new(77).take([1, 2, 0], 1)[0] # indices dans la main : salles RA RB, puis le sort
	var want_id: String = str([spell, _room("RA"), _room("RB")][want_idx]["id"])
	RoomAbilities.steal_random_card(G, 0, 1, "Succubus Spa")
	var got: Array = _ids(G["players"][0]["hand"])
	_ok.call(got == [want_id] and int(G["dbm"]["n"]) == 1 and (victim["hand"] as Array).size() == 2,
		"vol au hasard : la carte vient du generateur de la partie, un seul tirage (obtenu %s, attendu %s, tirages %d)" % [str(got), want_id, int(G["dbm"]["n"])])

# --- R-D15 : ordre des cartes = ordre de chargement des paquets de l'APK, pas ordre de choix -----------------------------------------

## Mesure : tools/apk-oracle --seed 1 --players 2 --decks BaseDeck,PlayerChoice,HiddenHeros,ToolsHeroKind, `initial.deckHeroes` (tete de file d'abord, ordinaires puis epiques).
## CardInfoService range les cartes dans l'ordre de l'enum GameDecks (PlayerChoice, ToolsHeroKind, HiddenHeros) : les KSA precedent les BMH avant le melange. Paquets donnes ici dans l'ordre inverse.
const ORACLE_HEROES_S1_P2 := ["BMH060", "BMH070", "BMH076", "BMH066", "BMH062", "BMH068", "BMH056", "BMH074", "BMH058", "BMH078", "BMH072", "BMH064", "BMH080", "KSA017", "BMH081", "BMH089",
	"KSA016", "KSA014", "BMH091", "BMH083", "BMH095", "BMH093", "BMH085", "BMH087"]

func _t_deck_load_order() -> void:
	var m = load("res://godot/scripts/Match.gd").new()
	host.add_child(m)
	var G: Dictionary = m.new_match(2, 0, ["hidden-heroes", "tools", "players-choice"], 1)
	var heroes: Array = _ids(G["decks"]["heroes"])
	heroes.reverse()
	var epics: Array = _ids(G["decks"]["epics"])
	epics.reverse()
	_ok.call(heroes + epics == ORACLE_HEROES_S1_P2, "ordre des paquets : graine 1, 2 joueurs, PlayerChoice + HiddenHeros + Tools = file de heros de l'oracle (obtenu %s)" % str(heroes + epics))
	m.queue_free()

# --- R-D15 : boss des IA tires par Except(boss des humains).Shuffle().Take(k), apres le boss de l'humain ------------------------------

func _t_ai_boss_follows_apk() -> void:
	var m = load("res://godot/scripts/Match.gd").new()
	host.add_child(m)
	var follows := 0
	var again := 0
	var order_ok := 0
	for seed_value in range(1, 9):
		var G: Dictionary = m.new_match(2, 1, ["base"], seed_value)
		if m.apk_ai_boss(1) == "":
			order_ok += 1 # tant que l'humain n'a pas son boss, le tirage des IA n'est pas fait (BoardUI attend le carrousel avant de laisser jouer l'IA)
		m.apply_move(0, {"type": "pickBoss", "args": [str(G["humanBoss"])]})
		var want: String = m.apk_ai_boss(1)
		var mv = AI.pick_move(m, 1)
		if want != "" and want != str(G["humanBoss"]) and mv != null and str((mv["args"] as Array)[0]) == want:
			follows += 1
		var G2: Dictionary = m.new_match(2, 1, ["base"], seed_value)
		m.apply_move(0, {"type": "pickBoss", "args": [str(G2["humanBoss"])]})
		if m.apk_ai_boss(1) == want:
			again += 1
	_ok.call(order_ok == 8 and follows == 8 and again == 8, "boss de l'IA : tire apres celui de l'humain, suivi par AI.pick_move, reproductible (%d/8, %d/8, %d/8)" % [order_ok, follows, again])
	m.queue_free()
