extends Control
## Barre de temps verte de l'APK (ProgressBarEntity : timebar_bg + ninepatch progress_green, longueur 141 px) :
## fenetre de sorts de l'aventure (3 s, au-dessus du heros) et pile de sorts (6 s, au-dessus de la carte du centre).
## `frac` 1 -> 0 vide la barre (largeur minimale de 4 px tant que le temps n'est pas ecoule).

const BG := "res://assets/ui/ingame/timebar_bg.webp"
const FILL := "res://assets/ui/ninepatch/progress_green.webp"
const LENGTH := 141.0
const CLOCK := "res://assets/ui/ingame/timebar_clock.webp"

var frac := 1.0:
	set(v):
		frac = clampf(v, 0.0, 1.0)
		_place_clock()
		queue_redraw()
## Barre ralentie (zoom, glisser, fenetre ouverte) : l'horloge `timebar_clock` apparait au bout de la barre en 0,2 s (ProgressBarBehavior.SlowDown / Resume, cs:164-181 ; FadeBehavior 0,2 s).
var slowed := false:
	set(v):
		if v == slowed:
			return
		slowed = v
		if _clock == null:
			return
		if _clock_tw != null and _clock_tw.is_valid():
			_clock_tw.kill()
		if is_inside_tree():
			_clock_tw = create_tween()
			_clock_tw.tween_property(_clock, "modulate:a", 1.0 if v else 0.0, 0.2)
		else:
			_clock.modulate.a = 1.0 if v else 0.0
var _clock: TextureRect
var _clock_tw: Tween
var _bg: Texture2D
var _sb: StyleBoxTexture

func _init() -> void:
	size = Vector2(159, 32)
	custom_minimum_size = size
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if ResourceLoader.exists(BG):
		_bg = load(BG)
	_sb = StyleBoxTexture.new()
	if ResourceLoader.exists(FILL):
		_sb.texture = load(FILL)
	_sb.texture_margin_left = 4
	_sb.texture_margin_right = 4
	_sb.texture_margin_top = 3
	_sb.texture_margin_bottom = 3
	if ResourceLoader.exists(CLOCK):
		_clock = TextureRect.new()
		_clock.texture = load(CLOCK)
		_clock.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_clock.modulate.a = 0.0
		add_child(_clock)
		_place_clock()

func _place_clock() -> void:
	if _clock != null:
		_clock.position = Vector2(10.0 + maxf(4.0, LENGTH * frac), 16.0) - _clock.texture.get_size() / 2.0 # origine au centre, X = largeur de la barre (ProgressBarBehavior.DrawProgress, cs:158)

func _draw() -> void:
	if _bg != null:
		draw_texture(_bg, Vector2.ZERO)
	draw_style_box(_sb, Rect2(10.0, 10.0, maxf(4.0, LENGTH * frac), 12.0))
