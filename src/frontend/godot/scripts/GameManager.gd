class_name GameManager
extends "res://godot/scripts/Match.gd"
## GameManager.gd — Gestionnaire global du jeu Boss Monster (Godot 4).
## Orchestre les phases : SETUP -> BEGINNING -> BUILD -> BAIT (Leurre) -> ADVENTURE -> END.
## Gère le recouvrement des salles ordinaires et avancées, le calcul des trésors,
## et la boucle d'aventure avec attribution des âmes (victoire à 10) et blessures (défaite à 5).

signal phase_changed(new_phase: String)
signal hero_lured(hero: Dictionary, target_player: int)
signal game_finished(winner_id: int, reason: String)

func _ready() -> void:
	super._ready()

## Démarre une nouvelle partie
func start_new_game(num_players: int = 2, p_human_count: int = 1, p_sets: Array = ["base"]) -> Dictionary:
	var state = new_match(num_players, p_human_count, p_sets)
	phase_changed.emit(state.get("phase", ""))
	return state

## --- Tutoriel de l'APK (GamePlayTutScene.InitializeGameboard -> GameBoardExtensions.InitializeGameBoardTutorial, GameBoardExtensions.cs:19-52) ---
## Pioches imposees, SOMMET EN PREMIER (ordre de l'APK) ; le reste de chaque pioche est tire avec la graine fixe TUT_SEED (start_tutorial).
const TUT_BOSS_HUMAN := "BMA003" # GamePlayTutScene.cs:51 HUMAN_PLAYER (King Croak)
const TUT_BOSS_AI := "BMA006"    # GamePlayTutScene.cs:53 IA_PLAYER (Seducia)
const TUT_SEED := 2832           # RandomProvider.Seed du tutoriel (GamePlayTutScene) ; le generateur de l'APK n'est pas reproductible ici : le hasard est fixe, pas identique a l'APK, seules les pioches imposees le sont
const TUT_ROOMS := ["BMA032", "BMA026", "BMA034", "BMA027", "BMA016", "BMA010", "BMA020", "BMA019", "BMA009", "BMA021", "BMA022", "BMA021"]
const TUT_SPELLS := ["BMA041", "BMA055", "BMA054", "BMA044"]
const TUT_HEROES := ["BMA064", "BMA068"]

## Partie forcee du tutoriel : 2 joueurs, jeu de base, humain King Croak (le carrousel est force par BoardUI.tutorial_gate), IA Seducia.
## Les pioches sont posees AVANT le dernier pickBoss (celui de l'humain), qui distribue les mains d'ouverture (Match._deal_opening_hands).
func start_tutorial() -> Dictionary:
	CardDB._rng.seed = TUT_SEED # paquets melanges pareil a chaque tutoriel (le tutoriel est le meme pour tous, comme dans l'APK)
	var state := new_match(2, 1, ["base"])
	CardDB._rng.randomize() # les parties suivantes redeviennent aleatoires
	rng.seed = TUT_SEED
	var decks: Dictionary = G["decks"]
	_tut_force(decks["rooms"], TUT_ROOMS)
	_tut_force(decks["spells"], TUT_SPELLS)
	_tut_force(decks["heroes"], TUT_HEROES)
	apply_move(1, {"type": "pickBoss", "args": [TUT_BOSS_AI]}) # l'IA prend Seducia avant que le carrousel de l'humain ne s'arrete
	phase_changed.emit(state.get("phase", ""))
	return state

## Retire de la pioche UN exemplaire existant de chaque carte imposee puis les remet au sommet (pop_back = sommet) en ordre inverse.
func _tut_force(deck: Array, ids: Array) -> void:
	var picked: Array = []
	for id in ids:
		for i in deck.size():
			if str((deck[i] as Dictionary).get("id", "")) == str(id):
				picked.append(deck.pop_at(i))
				break
	picked.reverse()
	deck.append_array(picked)

## Vérifie si une salle en main peut être construite sur un emplacement spécifique.
## slot_index == -1 ou slot_index >= dungeon.size() indique un nouvel emplacement de donjon.
## Delegue a BossEngine.can_build_room (miroir de engine.js:canBuildRoom) pour eviter
## toute divergence entre la logique de construction et les regles de l'engine.
func can_build_room_at(pid: int, hand_idx: int, slot_idx: int = -1) -> bool:
	if G.get("gameOver") != null:
		return false
	var players: Dictionary = G.get("players", {})
	if not players.has(pid):
		return false
	var p: Dictionary = players[pid]
	var hand: Array = p.get("hand", [])
	if hand_idx < 0 or hand_idx >= hand.size():
		return false
	var card: Dictionary = hand[hand_idx]
	if not bool(card.get("isRoom", false)):
		return false
	return BossEngine.can_build_room(p, G, pid, hand_idx, slot_idx)

## Construit une salle sur un emplacement spécifique (nouvel emplacement ou recouvrement).
## Delegue a Match.apply_move : c'est le SEUL chemin de construction. Le build doit
## passer face cachee et l'abilite "quand tu construis cette salle" ne doit se
## declencher qu'a la revelation de fin de phase (BuildPhase_b de l'APK), jamais
## a la pose. Construire ici directement faisait diverger l'UI du moteur.
func build_room_at(pid: int, hand_idx: int, slot_idx: int = -1) -> bool:
	if not can_build_room_at(pid, hand_idx, slot_idx):
		return false
	# legal_moves ne propose qu'un coup [i] pour une salle ordinaire (posee a l'entree) ; [i, cible] n'existe que pour les avancees.
	var card: Dictionary = ((G["players"][pid] as Dictionary)["hand"] as Array)[hand_idx]
	var args: Array = [hand_idx, slot_idx] if bool(card.get("advanced", false)) else [hand_idx]
	return apply_move(pid, {"type": "buildRoom", "args": args})

## Coup undoBuild de la pose en attente la PLUS ANCIENNE du siege (APK CheckMaxBuildRooms : toRevealRooms.First), {} s'il n'y en a pas.
func pending_undo(pid: int) -> Dictionary:
	var best := {}
	var best_rank := 1 << 30
	var dungeon: Array = ((G.get("players", {}) as Dictionary).get(pid, {}) as Dictionary).get("dungeon", [])
	for m in legal_moves(pid):
		if str((m as Dictionary).get("type", "")) != "undoBuild":
			continue
		var ui := int(((m as Dictionary)["args"] as Array)[0])
		var rank := int(((dungeon[ui] as Array).back() as Dictionary).get("undoBuild", 0)) if ui >= 0 and ui < dungeon.size() else 0
		if rank < best_rank:
			best_rank = rank
			best = m
	return best

## Emplacement cible apres la reprise du coup `undo` : un emplacement tout seul disparait (les suivants glissent d'un cran) ;
## deposer sur lui ou sur l'emplacement libre = nouvel emplacement (-1).
func _slot_after_undo(undo: Dictionary, slot_idx: int, pid: int) -> int:
	var dungeon: Array = ((G["players"] as Dictionary)[pid] as Dictionary).get("dungeon", [])
	var ui := int((undo["args"] as Array)[0])
	if (dungeon[ui] as Array).size() > 1:
		return slot_idx if slot_idx < dungeon.size() else -1
	if slot_idx >= dungeon.size() or slot_idx == ui:
		return -1
	return slot_idx - 1 if slot_idx > ui else slot_idx

## Une autre salle peut-elle remplacer la pose en attente (reprise puis pose, un seul geste du joueur) ? Essai sur une copie du joueur.
func can_swap_build_at(pid: int, hand_idx: int, slot_idx: int = -1) -> bool:
	var undo := pending_undo(pid)
	if undo.is_empty() or G.get("gameOver") != null:
		return false
	var p2: Dictionary = ((G["players"] as Dictionary)[pid] as Dictionary).duplicate(true)
	if hand_idx < 0 or hand_idx >= (p2["hand"] as Array).size() or not bool(((p2["hand"] as Array)[hand_idx] as Dictionary).get("isRoom", false)):
		return false
	var ti := _slot_after_undo(undo, slot_idx, pid)
	undo_build_on(p2, int((undo["args"] as Array)[0]))
	var pl2: Dictionary = (G["players"] as Dictionary).duplicate()
	pl2[pid] = p2
	var g2: Dictionary = G.duplicate()
	g2["players"] = pl2
	return BossEngine.can_build_room(p2, g2, pid, hand_idx, ti if ti >= 0 else (p2["dungeon"] as Array).size())

## Reprend la pose en attente puis pose la salle `hand_idx` (la carte reprise va en fin de main : les indices de la main ne bougent pas).
func swap_build(pid: int, hand_idx: int, slot_idx: int = -1) -> bool:
	if not can_swap_build_at(pid, hand_idx, slot_idx):
		return false
	var undo := pending_undo(pid)
	var ti := _slot_after_undo(undo, slot_idx, pid)
	return apply_move(pid, undo) and _build_after_undo(pid, hand_idx, ti)

## Pose de la salle `hand_idx` sur l'emplacement `ti` (-1 = nouvel emplacement) parmi les coups legaux courants.
func _build_after_undo(pid: int, hand_idx: int, ti: int) -> bool:
	for m in legal_moves(pid):
		var a: Array = (m as Dictionary).get("args", [])
		if str((m as Dictionary).get("type", "")) != "buildRoom" or a.is_empty() or int(a[0]) != hand_idx:
			continue
		if (a.size() > 1 and a[1] != null and int(a[1]) == ti) or ((a.size() < 2 or a[1] == null) and ti < 0):
			return apply_move(pid, m)
	return false
