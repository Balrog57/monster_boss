class_name OnlineGameManager
extends "res://godot/scripts/GameManager.gd"
## Partie en ligne : l'autorite est le serveur Node, les seuls coups emis

const OnlineClient = preload("res://godot/scripts/OnlineClient.gd")
## sont ceux proposes par le serveur (moves). Sous-classe de GameManager
## pour reutiliser BoardUI/DungeonSlot sans modification de leur typage.

var client: OnlineClient
var my_pid: int = 0
var server_moves: Array = []

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

static func _same(a: Dictionary, b: Dictionary) -> bool:
	return str(a.get("type", "")) == str(b.get("type", "")) and str(a.get("args", [])) == str(b.get("args", []))

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

## Traduit (main, emplacement) local vers les coups serveur :
## setup -> buildInitialRoom [i] ; build -> buildRoom [i, cible ou null].
func _build_move(pid: int, hand_idx: int, slot_idx: int):
	if G.get("gameOver") != null:
		return null
	var phase: String = str(G.get("phase", ""))
	if phase == "setup":
		return _cached({"type": "buildInitialRoom", "args": [hand_idx]})
	if phase != "build":
		return null
	var dungeon: Array = ((G.get("players", {}) as Dictionary).get(pid, {}) as Dictionary).get("dungeon", [])
	var target = null if (slot_idx < 0 or slot_idx >= dungeon.size()) else slot_idx
	return _cached({"type": "buildRoom", "args": [hand_idx, target]})

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
