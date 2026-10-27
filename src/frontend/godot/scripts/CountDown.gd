extends Control
## Compte a rebours de tour en ligne, comme CountDownEntity de l'APK : chiffres or x 3 (ombre noire +3 px), sablier (30, -8),
## fondu 0,3 s (aucun son : l'APK ne joue ui_timer qu'au lancement de la salle d'attente publique, WaitingPublicRoomScene.cs:88-105). Affiche le delai restant de MON siege quand le serveur l'attend
## (`awaited` + `deadline`, voir godot/server/PROTOCOL.md), masque sinon.

const UiKit = preload("res://godot/scripts/UiKit.gd")
const GOLD := Color("cdb15f")

var online # OnlineClient
var _digits: Label
var _shadow: Label
var _shown := false
var _last := -1

func _init(p_online = null) -> void:
	online = p_online
	position = Vector2(1150, 12)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	modulate.a = 0.0
	UiKit.image(self, UiKit.UI + "gradients/sandclock_icon.webp", Vector2(30, -8))
	_shadow = UiKit.label(self, "0", 63, Color.BLACK, Vector2(125, 3), 0.0, UiKit.FONT_A)
	_digits = UiKit.label(self, "0", 63, GOLD, Vector2(125, 0), 0.0, UiKit.FONT_A)
	for l in [_shadow, _digits]: # UiKit.label pose un contour noir : ici l'ombre est le second texte
		l.add_theme_constant_override("outline_size", 0)

## Secondes restantes pour mon siege, -1 si le serveur n'attend pas ma decision.
func remaining() -> int:
	if online == null or online.current_G.is_empty() or online.current_G.get("gameOver") != null:
		return -1
	var deadline := int(online.current_G.get("turnDeadline", 0))
	if deadline <= 0:
		return -1
	var mine: bool = (online.current_awaited as Array).has(online.player_id) if not (online.current_awaited as Array).is_empty() else not (online.current_moves as Array).is_empty()
	if not mine:
		return -1
	var now_ms := Time.get_unix_time_from_system() * 1000.0 + float(online.clock_offset_ms)
	return maxi(0, ceili((float(deadline) - now_ms) / 1000.0))

func _process(_delta: float) -> void:
	var s := remaining()
	var want := s >= 0
	if want != _shown:
		_shown = want
		create_tween().tween_property(self, "modulate:a", 1.0 if want else 0.0, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	if want and s != _last:
		_digits.text = str(s)
		_shadow.text = str(s)
	_last = s if want else -1
