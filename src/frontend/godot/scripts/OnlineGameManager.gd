class_name OnlineGameManager
extends "res://godot/scripts/GameManager.gd"
## Partie en ligne : l'autorite est le serveur Godot (Server.gd), les seuls coups emis
## sont ceux proposes par le serveur (moves, vocabulaire de Match.legal_moves). Sous-classe de
## GameManager pour reutiliser BoardUI/DungeonSlot sans modification de leur typage.

const OnlineClient = preload("res://godot/scripts/OnlineClient.gd")

var client: OnlineClient
var my_pid: int = 0
var server_moves: Array = []
var _queued_build := {} ## {idx, id, ti} : pose a jouer des que le serveur a confirme la reprise (undoBuild) de la salle en attente

func setup_online(p_client: OnlineClient, p_pid: int) -> void:
	client = p_client
	my_pid = p_pid
	G = client.current_G
	server_moves = client.current_moves
	client.state_received.connect(_on_remote_state)
	state_changed.emit()

func _on_remote_state() -> void:
	G = client.current_G
	server_moves = client.current_moves
	state_changed.emit()
	if not _queued_build.is_empty(): # reprise confirmee par le serveur : on pose maintenant la salle qui la remplace
		var q := _queued_build
		_queued_build = {}
		var hand: Array = ((G.get("players", {}) as Dictionary).get(my_pid, {}) as Dictionary).get("hand", [])
		if int(q["idx"]) < hand.size() and str((hand[int(q["idx"])] as Dictionary).get("id", "")) == str(q["id"]):
			super._build_after_undo(my_pid, int(q["idx"]), int(q["ti"]))

## Meme coup que le serveur : memes alias (pass/passBuild...) et arguments nuls de fin ignores (Match).
static func _same(a: Dictionary, b: Dictionary) -> bool:
	return _is_same_move_type(str(a.get("type", "")), str(b.get("type", ""))) and _trim_args(a.get("args", [])) == _trim_args(b.get("args", []))

func _cached(move: Dictionary):
	for m in server_moves:
		if m is Dictionary and _same(m, move):
			return m
	return null

func legal_moves(pid: int) -> Array:
	if client == null or pid != my_pid:
		return []
	return server_moves

func apply_move(pid: int, move: Dictionary) -> bool:
	if client == null or pid != my_pid:
		return false
	var found = _cached(move)
	if not (found is Dictionary):
		return false
	client.send_move(found)
	return true

## En ligne le serveur ne repond qu'a l'etat suivant : on envoie la reprise et la pose attend (_on_remote_state).
func _build_after_undo(pid: int, hand_idx: int, ti: int) -> bool:
	var hand: Array = ((G.get("players", {}) as Dictionary).get(pid, {}) as Dictionary).get("hand", [])
	if hand_idx < 0 or hand_idx >= hand.size():
		return false
	_queued_build = {"idx": hand_idx, "id": str((hand[hand_idx] as Dictionary).get("id", "")), "ti": ti}
	return true

## Traduit (main, emplacement) local vers le coup du serveur : buildRoom [i] (salle ordinaire, posee a
## l'entree) ou [i, cible] (salle avancee sur un emplacement). Seul un coup propose par le serveur passe.
func _build_move(pid: int, hand_idx: int, slot_idx: int):
	if G.get("gameOver") != null:
		return null
	var hand: Array = ((G.get("players", {}) as Dictionary).get(pid, {}) as Dictionary).get("hand", [])
	if hand_idx < 0 or hand_idx >= hand.size():
		return null
	var advanced := bool((hand[hand_idx] as Dictionary).get("advanced", false))
	return _cached({"type": "buildRoom", "args": [hand_idx, slot_idx] if advanced else [hand_idx]})

func can_build_room_at(pid: int, hand_idx: int, slot_idx: int = -1) -> bool:
	if client == null or pid != my_pid:
		return false
	return _build_move(pid, hand_idx, slot_idx) is Dictionary

func build_room_at(pid: int, hand_idx: int, slot_idx: int = -1) -> bool:
	if client == null or pid != my_pid:
		return false
	var mv = _build_move(pid, hand_idx, slot_idx)
	if not (mv is Dictionary):
		return false
	return apply_move(pid, mv)
