extends Control
## LoadingScene de l'APK (LoadingScene.cs:20-40) : fond #270000 + loading_bg, sprite « loading » en (830, 0,8 H), trois rupies animees (RupisLoadingBehavior.cs:20-80).
## Positions en coordonnees APK + 240 px. Le fondu vers l'intro (ColorFade noir 1,0 s) est la transition `Main.go` ; l'APK affiche cet ecran le temps de LoadHeavyAssets + LoadAllSounds (Start, :42-58).

const UiKit = preload("res://godot/scripts/UiKit.gd")
const UI := "res://assets/ui/loading/"
const STEP := 0.5   # RupisLoadingBehavior(3, 0,5 s) : delai entre deux rupies
const FADE := 0.2   # FadeBehavior(0,2 s) de chaque sprite de rupie
const DOTS := 3
const DOT_DX := 40.0 # ecart des rupies (num2)
const X0 := 240.0   # l'espace virtuel de l'APK (1440 de large) est centre dans 1920 : +240 (comme AvatarScroll.ORIGIN_X, TAP TO START)
const ORIGIN := Vector2(600.0 + X0, 864) # (600, 0,8 x 1080)

var on: Array = []   # rupia_on (opacite 0 au depart)
var off: Array = []  # rupia_off (opacite 1)
var _t := 0.0        # currentTime
var _index := 0      # rupiesIndex, en rupies (l'APK compte 2 entites par rupie)
var _fill := true    # fillRupies

func _init() -> void:
	name = "LoadingScene"
	size = Vector2(1920, 1080)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := ColorRect.new()
	bg.color = UiKit.LOADING_BG
	bg.size = size
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	_nearest(UiKit.image(self, "res://assets/ui/backgrounds/loading_bg.png", Vector2.ZERO, size)) # AddressMode.PointClamp
	var spr := UiKit.image(self, UI + "loading.webp", Vector2(830.0 + X0, 864) - Vector2(218, 45) / 2.0)
	spr.name = "Loading"
	_nearest(spr)
	for i in DOTS:
		var p := ORIGIN + Vector2(DOT_DX * i, 0.0) - Vector2(16, 23.5) # Origin Center, 32 x 47
		var d_on := UiKit.image(self, UI + "rupia_on.webp", p)
		d_on.modulate.a = 0.0
		var d_off := UiKit.image(self, UI + "rupia_off.webp", p)
		_nearest(d_on)
		_nearest(d_off)
		on.append(d_on)
		off.append(d_off)

static func _nearest(c: CanvasItem) -> void:
	c.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

## RupisLoadingBehavior.Update : au-dela de 0,5 s (strictement), la rupie suivante bascule (0,2 s lineaire), puis le temps repart de 0.
func _process(delta: float) -> void:
	if _t > STEP:
		_t = 0.0
		step()
	else:
		_t += delta

func step() -> void:
	var a: TextureRect = (off if _fill else on)[_index]
	var b: TextureRect = (on if _fill else off)[_index]
	create_tween().tween_property(a, "modulate:a", 0.0, FADE)
	create_tween().tween_property(b, "modulate:a", 1.0, FADE)
	_index += 1
	if _index == DOTS:
		_fill = not _fill
		_index = 0
