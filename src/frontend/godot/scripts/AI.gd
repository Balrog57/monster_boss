class_name AI
extends RefCounted
## Miroir minimal de src/backend/game/ai.js : choisit le meilleur coup légal.
## shortcut: scoring complet (sorts, miniboss, level-up) reporté à la phase 2.

static func choose_boss(picks: Array):
	var best = null
	for b in picks:
		if best == null or int((b as Dictionary).get("xp", 0)) > int((best as Dictionary).get("xp", 0)):
			best = b
	return best

static func pick_move(match, pid: int):
	var moves: Array = match.legal_moves(pid)
	if moves.is_empty():
		return null
	var p: Dictionary = (match.G["players"] as Dictionary)[pid]
	var best = moves[0]
	var best_score := _score(p, moves[0])
	for i in range(1, moves.size()):
		var s := _score(p, moves[i])
		if s > best_score:
			best_score = s
			best = moves[i]
	return best

static func _score(p: Dictionary, move: Dictionary) -> float:
	match String(move["type"]):
		"pickBoss":
			return 1.0
		"buildInitialRoom", "buildRoom":
			var c: Dictionary = (p["hand"] as Array)[int(move["args"][0])]
			return float(c.get("damage", 0)) * 10.0 + float((c.get("treasures", []) as Array).size()) * 3.0
		"passBuild":
			return -1.0
		"adventureNext":
			return 0.0
	return 0.0
