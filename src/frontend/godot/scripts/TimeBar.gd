extends Control
## Barre de temps verte de l'APK (ProgressBarEntity : timebar_bg + ninepatch progress_green, longueur 141 px) :
## fenetre de sorts de l'aventure (3 s, au-dessus du heros) et pile de sorts (6 s, au-dessus de la carte du centre).
## `frac` 1 -> 0 vide la barre (largeur minimale de 4 px tant que le temps n'est pas ecoule).

const BG := "res://assets/ui/ingame/timebar_bg.webp"
const FILL := "res://assets/ui/ninepatch/progress_green.webp"
const LENGTH := 141.0

var frac := 1.0:
	set(v):
		frac = clampf(v, 0.0, 1.0)
		queue_redraw()
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

func _draw() -> void:
	if _bg != null:
		draw_texture(_bg, Vector2.ZERO)
	draw_style_box(_sb, Rect2(10.0, 10.0, maxf(4.0, LENGTH * frac), 12.0))
