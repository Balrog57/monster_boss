extends Control
## Ecran de fin de l'APK (WinnerScene / LoseScene) : voile sombre, bandeau winner_bg translucide a filets dores avec le nom du vainqueur puis
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
	dim.color = Color(0, 0, 0, 0.7) # ControlsFactory.cs:117-122 (CreateBlackBack opacity 0.7) ; la main reste dessinee dessous
	dim.size = Vector2(1920, 1080)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	if not lose: # APK : winner_bg translucide (alpha 127, filets dores 1 px dans la texture) x1,82, centre (960, 216), sans opacite : ControlsFactory.cs:129-139 ; « ...YOU LOSE! » n'a pas de bandeau (LoseScene.cs)
		var bg := UiKit.image(self, UI + "gradients/winner_bg.webp", Vector2(3.6, 122), Vector2(1912.8, 188))
		bg.name = "WinnerBg"
	if lose:
		title_label = UiKit.label(self, "...YOU LOSE!", 38, Color.WHITE, Vector2(-31, 449), 1920.0, UiKit.FONT_A, HORIZONTAL_ALIGNMENT_CENTER) # 38 = arcadepix 21 x 1,8 (LoseScene.cs:22) ; APK : texte 279 x 26 px centre en (929, 478)
		var rip := UiKit.image(self, UI + "ingame/bosses_tombstone.webp", Vector2(1217, 464) - Vector2(125, 134), Vector2(250, 268)) # APK : pierre tombale x1,5 centree en (1217, 464)
		rip.name = "Tombstone"
	else:
		title_label = UiKit.label(self, winner_name, 52, Color.WHITE, Vector2(0, 153), 1920.0, UiKit.FONT_A, HORIZONTAL_ALIGNMENT_CENTER) # 52 = arcadepix 21 x 2,5 (WinnerScene.cs:50)
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
