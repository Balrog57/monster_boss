extends Control
## Ecran de fin de l'APK (WinnerScene / LoseScene) : voile sombre, bandeau noir a filets dores avec le nom du vainqueur puis
## « IS THE WINNER! » (winner_txt), le boss gagnant agrandi (x2) entoure de 10 cristaux dores qui tournent (CircleOfRotatingRupisBehavior :
## rayon 160 x 2, un cran de cercle par seconde), bouton OK en bas a droite. Pas de tableau des scores. Perdu : « ...YOU LOSE! » + pierre tombale.
## OK emet `ok_pressed` (le plateau ramene au TITRE).

signal ok_pressed

const UiKit = preload("res://godot/scripts/UiKit.gd")
const UI := "res://assets/ui/"
const BOSS_CENTER := Vector2(1000, 672)
const CRYSTALS := 10
const RADIUS := 320.0
const SPEED := TAU / CRYSTALS               # rad/s : un cran de cercle par seconde

var ok_btn: TextureButton
var title_label: Label
var _crystals: Array = []
var _t := 0.0

## winner_name : nom du boss gagnant ; boss_id : son sprite ; lose : l'ecran « YOU LOSE » (le joueur local a perdu).
func build(winner_name: String, boss_id: String, lose: bool) -> void:
	size = Vector2(1920, 1080)
	mouse_filter = Control.MOUSE_FILTER_STOP # plus rien n'est jouable derriere
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.66)
	dim.size = Vector2(1920, 1080)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var band_y := 395.0 if lose else 125.0
	var band := ColorRect.new()
	band.color = Color(0.0, 0.0, 0.0, 0.88)
	band.position = Vector2(0, band_y)
	band.size = Vector2(1920, 183)
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(band)
	for ly in [band_y, band_y + 183.0]:
		var line := ColorRect.new()
		line.color = Color(0.85, 0.65, 0.2, 0.9)
		line.position = Vector2(0, ly)
		line.size = Vector2(1920, 2)
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(line)
	if lose:
		title_label = UiKit.label(self, "...YOU LOSE!", 60, Color.WHITE, Vector2(0, band_y + 55), 1920.0, UiKit.FONT_A, HORIZONTAL_ALIGNMENT_CENTER)
		var rip := UiKit.image(self, UI + "ingame/bosses_tombstone.webp", Vector2(1306, 464) - Vector2(125, 134), Vector2(250, 268))
		rip.name = "Tombstone"
	else:
		title_label = UiKit.label(self, winner_name, 64, Color.WHITE, Vector2(0, 140), 1920.0, UiKit.FONT_A, HORIZONTAL_ALIGNMENT_CENTER)
		var w := UiKit.image(self, UI + "ingame/winner_txt.webp", Vector2(960 - 233, 228))
		w.name = "WinnerText"
		_boss(boss_id)
	ok_btn = UiKit.texture_button(self, UI + "buttons/ok_bt.webp", UI + "buttons/ok_bt_pressed.webp", Vector2(1458, 960))
	ok_btn.name = "Ok"
	ok_btn.pressed.connect(func():
		AudioManager.play_sfx("ui_button_select")
		ok_pressed.emit())

func _boss(boss_id: String) -> void:
	var shine := UiKit.image(self, UI + "gradients/winner_boss_shine.webp", BOSS_CENTER - Vector2(300, 300), Vector2(600, 600))
	shine.modulate = Color(1, 1, 1, 0.8)
	var tex: Texture2D = UiKit.tex(UI + "characters/%s_character.webp" % boss_id.to_lower())
	if tex != null:
		var s := UiKit.image(self, UI + "characters/%s_character.webp" % boss_id.to_lower(), BOSS_CENTER - tex.get_size(), tex.get_size() * 2.0)
		s.name = "BossSprite"
	for i in CRYSTALS:
		var c := Control.new()
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(c)
		UiKit.image(c, UI + "gradients/winner_soul_shine.webp", Vector2(-52, -57), Vector2(105, 114))
		UiKit.image(c, UI + "ingame/souls_icon.webp", Vector2(-28, -38), Vector2(55, 77))
		_crystals.append(c)
	_place()

func _place() -> void:
	for i in _crystals.size():
		var a: float = SPEED * _t + TAU / float(CRYSTALS) * float(i)
		(_crystals[i] as Control).position = BOSS_CENTER + Vector2(sin(a), -cos(a)) * RADIUS

func _process(delta: float) -> void:
	_t += delta
	_place()
