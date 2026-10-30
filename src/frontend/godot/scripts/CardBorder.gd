class_name CardBorder
extends TextureRect
## Cadre d'une carte : BaseBorderBehavior.cs + CardBorderBehavior.cs + BorderStyles.cs. Un seul composant pour tous les cadres (selection, sort jouable, cible, source,
## emplacement constructible) : le style choisit la texture, et chaque changement fond le cadre (entrant si le style est visible, sortant sinon).

enum Style { NONE, YELLOW, YELLOW_GLOW, RED, GREEN_GLOW } # BorderStyles.cs:3-10

const DIR := "res://assets/ui/ingame/"
const NAMES := ["", "card_border_yellow", "card_border_yellow_glow", "card_border_red", "card_border_green_glow"]
const FADE := 0.3                  # CardEntity.cs:99 : FadeBehavior(0,3 s), lineaire, rythme constant (FadeBehavior.cs:76-80)
const SCALED_MAX := 0.5            # CardBorderBehavior.cs:13,33 : sous l'echelle 0,5 de la carte, variante « _scaled » posee a x 2,7 (cs:64-71)
const SCALED_K := 2.7
const SCALED_SIZE := Vector2(152, 203)
const CARD := Vector2(350, 488)    # la carte APK a l'echelle 1 ; les textures pleines sont 354 x 492 (Yellow, Red) et 390 x 528 (glows)

var style: int = Style.NONE
var _origin := Vector2.ZERO        # coin haut gauche de la zone de la carte encadree
var _host := Vector2.ZERO          # taille de cette zone (le cadre est centre dessus)
var _scale := 1.0                  # echelle de la carte (largeur / 350)
var _stretch := false
var _tw: Tween

## Cadre pose sur `parent`, centre sur `host_size` (position `at`), pour une carte de largeur `card_w`. `start` : style deja visible (sans fondu).
## `stretch` : cible qui n'est pas une carte (boss, heros) plus large que 175 px : le cadre plein epouse `host_size` au lieu de l'echelle d'une carte.
static func attach(parent: Node, at: Vector2, host_size: Vector2, card_w: float, start: int = Style.NONE, nm := "CardBorder", stretch := false) -> CardBorder:
	var b := CardBorder.new()
	b.name = nm
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	b.stretch_mode = TextureRect.STRETCH_SCALE
	b._origin = at
	b._host = host_size
	b._scale = card_w / CARD.x
	b._stretch = stretch
	b.modulate.a = 0.0
	parent.add_child(b)
	if start != Style.NONE:
		b.set_style(start, false)
	return b

func is_scaled() -> bool:
	return _scale <= SCALED_MAX + 0.0006 # 175,5 / 350 : la main (0,5) est « scaled », le carrousel (0,7) non

## BaseBorderBehavior.BorderStyle (cs:19-30) + UpdateBorderStyle (cs:59-68) : texture selon le style, puis fondu entrant (visible) ou sortant (None), depuis l'opacite courante.
func set_style(s: int, animate := true) -> void:
	if s == style:
		return
	style = s
	if s != Style.NONE:
		var path: String = DIR + NAMES[s] + ("_scaled" if is_scaled() else "") + ".webp"
		texture = load(path) if ResourceLoader.exists(path) else null
		size = (SCALED_SIZE * SCALED_K * _scale) if is_scaled() else (_host if _stretch or texture == null else texture.get_size() * _scale)
		position = _origin + (_host - size) / 2.0
	if _tw != null:
		_tw.kill()
	var to := 1.0 if s != Style.NONE else 0.0
	if not animate or not is_inside_tree():
		modulate.a = to
		return
	_tw = create_tween()
	_tw.tween_property(self, "modulate:a", to, FADE * absf(to - modulate.a)) # FadeBehavior : duree proportionnelle a la distance restante
