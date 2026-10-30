extends Node
## Largeur utile de l'ecran, comme l'APK (ViewportManager Uniform sur une maquette de 1440 x 1080, Game.cs:49 ; ViewportManagerExtensions.cs ; EdgeAlignmentComponent.cs).
##
## Regle : largeur utile = clamp(ratio de la fenetre x 1080, 1440, 1920). `Window.content_scale_size` suit (keep_aspect) : un 16:9 ou plus large garde 1920 x 1080 (bandes noires
## sur les cotes, comme avant), un 4:3 passe a 1440 x 1080 sans bande.
##
## Tout le code d'interface garde sa maquette 1920 x 1080 (« repere F » = coordonnees APK + 240) : Main (ou le plateau seul dans les tests, `make_stage`) est un Control fixe de
## 1920 x 1080, et la `canvas_transform` de la fenetre le recentre de `centre_offset()` (comme Camera2D : global_position, get_global_rect et get_global_mouse_position restent en
## repere F ; seuls les `event.position` recus par `_input` sont en pixels fenetre, voir `to_canvas`). Un element ancre au centre n'a donc rien a faire. Un element ancre a un bord
## (EdgeAlignmentComponent) est decale par `edge()` : `limited_left_edge()` + x pour le bord gauche, `x + limited_right_edge() - 1920` pour le bord droit (+ terme proportionnel `p`,
## ProportionalMarginOffset). A 1920 de large tous les decalages valent 0 : l'ecran est identique a avant.

signal width_changed(w: float)

const DESIGN_W := 1920.0
const H := 1080.0
const MIN_W := 1440.0
const MAX_W := 1920.0
const APK_W := 1440.0 # Game.VIEWPORT_WIDTH
const LEFT := 0
const RIGHT := 1

var width := DESIGN_W
var _edges: Array = [] # noeuds enregistres par edge() (meta vp_x / vp_side / vp_prop)

static func width_for(aspect: float) -> float:
	return clampf(aspect * H, MIN_W, MAX_W)

func _ready() -> void:
	get_window().size_changed.connect(_on_size_changed)
	_apply_canvas()
	_on_size_changed()

func _on_size_changed() -> void:
	if DisplayServer.get_name() == "headless": # serveur / tests sans fenetre : la largeur ne change que par set_width()
		return
	var s: Vector2i = get_window().size
	if s.x > 0 and s.y > 0:
		set_width(width_for(float(s.x) / float(s.y)))

## Fixe la largeur utile (appelee par la fenetre ; les tests l'appellent directement : un serveur sans fenetre n'emet aucun size_changed).
func set_width(w: float) -> void:
	var cw := float(roundi(clampf(w, MIN_W, MAX_W)))
	var win := get_window()
	var cs := Vector2i(int(cw), int(H))
	if win.content_scale_size != cs:
		win.content_scale_size = cs
	if is_equal_approx(cw, width):
		return
	width = cw
	_apply_canvas()
	for n in _edges:
		if is_instance_valid(n):
			_apply(n)
	width_changed.emit(width)

func _apply_canvas() -> void:
	get_viewport().canvas_transform = Transform2D(0.0, Vector2(centre_offset(), 0.0))

## Position fenetre (event.position / global_position recus par `_input`) -> repere F. Les `_gui_input` des Control sont deja en repere F ; `get_global_mouse_position()` aussi.
func to_canvas(p: Vector2) -> Vector2:
	return p - Vector2(centre_offset(), 0.0)

## Copie d'un evenement souris de `_input` en repere F (les autres evenements et l'identite a 1920 de large : l'evenement lui-meme).
func canvas_event(ev: InputEvent) -> InputEvent:
	if ev is InputEventMouse and not is_zero_approx(centre_offset()):
		var c := ev.duplicate() as InputEventMouse
		c.position = to_canvas(c.position)
		c.global_position = to_canvas(c.global_position)
		return c
	return ev

## Repere F -> position fenetre (tests : push_input).
func to_view(p: Vector2) -> Vector2:
	return p + Vector2(centre_offset(), 0.0)

# --- bords, en repere F (celui de la scene centree) --------------------------------

## Decalage x de la maquette dans la fenetre (canvas_transform) : 0 a 1920, -240 a 1440.
func centre_offset() -> float:
	return (width - DESIGN_W) * 0.5

## ViewportManager.LeftEdge / RightEdge (la fenetre dans le repere F) : 240 / 1680 a 1440 de large, 0 / 1920 a 1920.
func left_edge() -> float:
	return (DESIGN_W - width) * 0.5

func right_edge() -> float:
	return (DESIGN_W + width) * 0.5

## ViewportManagerExtensions.LimitedLeftEdge / LimitedRightEdge : jamais au-dela de la maquette (widthDiff = 240 de chaque cote).
func limited_left_edge() -> float:
	return maxf(0.0, left_edge())

func limited_right_edge() -> float:
	return minf(DESIGN_W, right_edge())

## Largeur de l'ecran en pixels de maquette (LimitedVirtualWidth + 480 : la maquette F compte 240 de plus de chaque cote).
func limited_width() -> float:
	return limited_right_edge() - limited_left_edge()

## Decalage a ajouter a un x de la maquette 1920 pour un element colle au bord gauche / droit (marge inchangee) ; `p` = ProportionalMarginOffset de l'APK.
func shift_left() -> float:
	return limited_left_edge()

func shift_right(p := 0.0) -> float:
	return limited_right_edge() - DESIGN_W - p * (limited_width() - DESIGN_W) / APK_W

func lx(x: float) -> float:
	return x + shift_left()

func rx(x: float, p := 0.0) -> float:
	return x + shift_right(p)

# --- enregistrement ----------------------------------------------------------------

## Fait de `c` la scene de maquette (1920 x 1080 fixe, en haut a gauche du repere F) : Main, ou un plateau pose directement sous la racine (un FULL_RECT suivrait la largeur utile).
func make_stage(c: Control) -> void:
	c.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	c.size = Vector2(DESIGN_W, H)
	c.position = Vector2.ZERO

## Colle `n` (dont `position.x` est en maquette 1920) au bord gauche (LEFT) ou droit (RIGHT) ; suit les changements de largeur. Renvoie `n`.
func edge(n: Control, side: int, p := 0.0) -> Control:
	if _edges.size() > 400:
		_edges = _edges.filter(func(e): return is_instance_valid(e)) # ecrans / plateaux liberes
	n.set_meta("vp_x", n.position.x)
	n.set_meta("vp_side", side)
	n.set_meta("vp_prop", p)
	_edges.append(n)
	_apply(n)
	return n

func _apply(n: Control) -> void:
	var base: float = n.get_meta("vp_x")
	n.position.x = base + (shift_left() if int(n.get_meta("vp_side")) == LEFT else shift_right(float(n.get_meta("vp_prop"))))

## Le x de maquette d'un noeud enregistre (avant decalage), pour le code qui le repositionne.
func base_x(n: Control) -> float:
	return float(n.get_meta("vp_x", n.position.x))
