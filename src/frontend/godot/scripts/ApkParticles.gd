class_name ApkParticles
extends CPUParticles2D
## Particules de l'APK : ParticlesFactory.CreateBackParticles (ParticlesFactory.cs:9-25) rendu par ParticleSystemRenderer2D (Wave).
## Un seul emetteur CPU (export web Compatibility, sans threads : pas de GPUParticles), blanc, derriere la carte / le cadre.
## Usage : ApkParticles.creer(parent, taille) puis set_emit(true/false) ; ApkParticles.sur(...) cree/reutilise un enfant nomme.
## `taille` = taille de l'EMETTEUR (EmitterSize = entitySize x scale, ParticlesFactory.cs:21) : l'appelant passe 0,9 x la carte (ECHELLE).

const TEX := "res://assets/ui/particle_01.webp"            # Sprites.Common.particle_01, 19 x 19 (CardEntity.cs:82)
const ECHELLE := 0.9                                        # ParticlesParentSizeBehavior.Scale (CardEntity.cs:88, WinnerScene.cs:68) ; CollapsedOpponentDetail.cs:204 passe 0,9 a la fabrique
const VIE_MIN := 1.5                                        # MinLife (ParticlesFactory.cs:13)
const VIE_MAX := 3.0                                        # MaxLife (ParticlesFactory.cs:14)
## NumParticles 100 (ParticlesFactory.cs:11) est SATURE : EmitRate 50/s (:12) > 100 emplacements / vie moyenne 2,25 s = 44,4 naissances/s
## (ParticleSystemRenderer2D.cs:179-183 : un emplacement mort renait des qu'un credit d'emission existe), soit ~100 vivantes.
## CPUParticles2D emet amount / lifetime par seconde : 133 / 3 s = 44,3/s, donc le meme debit et ~100 vivantes en regime (pointes ~110).
const AMOUNT := 133
const V_MIN := -1.7                                         # LocalVelocity -1,2 - RandomVelocity 0,5 (ParticlesFactory.cs:15-16 ; ParticleSystemRenderer2D.cs:465-466)
const V_MAX := -0.7                                         # LocalVelocity -1,2 + RandomVelocity 0,5 : chaque axe tire son propre aleatoire
const PX_PAR_UNITE := 60.0                                  # position += 0,06 x ms x v (ParticleSystemRenderer2D.cs:16,154,199-200) = 60 px/s par unite ; Y vers le bas (ecran Wave) : -v = haut-gauche
const COTE_MIN := 4.0                                       # cote = 2 x Size (sommets -1..1 x Size, ParticleSystemRenderer2D.cs:339-346,602-606), Size 2..12 (ParticlesFactory.cs:17-18, :565)
const COTE_MAX := 24.0
const TEXTURE_PX := 19.0                                    # CPUParticles2D mesure l'echelle en multiples de la texture
const POINTS_PAR_COTE := 100                                # contour tire cote par cote (voir _regenerer)

static var _gradient: Gradient
static var _courbe: Curve
static var _mat: ShaderMaterial

var suit: Control                                           # optionnel : l'emetteur accompagne le centre de ce Control (carte piochee, pivot au centre)
var _taille := Vector2(-1.0, -1.0)
var _vitesses := PackedVector2Array()                       # une vitesse aleatoire par point d'emission (voir _regenerer)

func _init() -> void:
	texture = load(TEX)
	amount = AMOUNT
	lifetime = VIE_MAX
	lifetime_randomness = (VIE_MAX - VIE_MIN) / VIE_MAX     # vie = lifetime x (1 - 0,5 x rand) = Lerp(1,5 ; 3,0 ; rand) (ParticleSystemRenderer2D.cs:455)
	local_coords = false                                    # particules en coordonnees monde : elles ne suivent pas l'emetteur apres leur naissance
	gravity = Vector2.ZERO                                  # Gravity 0 (valeur par defaut, ParticleSystem2D.cs:30)
	direction = Vector2.RIGHT                               # la vitesse vient de la normale du point d'emission (directed points) : v = 1 x normale
	spread = 0.0
	initial_velocity_min = 1.0
	initial_velocity_max = 1.0
	angle_min = 0.0                                         # pas de rotation : Min/MaxRotateSpeed et InitialAngle a 0 (ParticleSystem2D.cs:212-223)
	angle_max = 0.0
	scale_amount_min = COTE_MIN / TEXTURE_PX
	scale_amount_max = COTE_MAX / TEXTURE_PX
	if _courbe == null:
		_courbe = Curve.new()                               # EndDeltaScale 0 : taille x (1 - fraction de vie ecoulee), lineaire (ParticleSystemRenderer2D.cs:599-600)
		_courbe.add_point(Vector2(0.0, 1.0), 0.0, -1.0)
		_courbe.add_point(Vector2(1.0, 0.0), -1.0, 0.0)
		_gradient = Gradient.new()                          # couleur blanche (MinColor = MaxColor = White) x vie restante, rgb ET alpha (cs:332-334 : Color *= life/TimeLife)
		_gradient.colors = PackedColorArray([Color(1, 1, 1, 1), Color(0, 0, 0, 0)])
		_gradient.offsets = PackedFloat32Array([0.0, 1.0])
	scale_amount_curve = _courbe
	color = Color.WHITE
	color_ramp = _gradient
	if _mat == null:
		_mat = ShaderMaterial.new()
		_mat.shader = Shader.new()
		# Wave : gl_FragColor = texture x couleur de sommet, melange One / OneMinusSrcAlpha (BasicEffectpsVertexColorTexture.frag, sans test alpha : ReferenceAlpha n'y sert a rien).
		# La texture est stockee premultipliee ; le webp (avec perte) laisse du bruit en rgb sur les pixels transparents, qui s'ajoute en halo carre : rgb <= alpha le supprime.
		_mat.shader.code = "shader_type canvas_item;
render_mode blend_premul_alpha;
void fragment() { COLOR.rgb = min(COLOR.rgb, vec3(COLOR.a)); }"
	material = _mat
	emission_shape = CPUParticles2D.EMISSION_SHAPE_DIRECTED_POINTS
	emitting = false                                        # Emit = false (ParticlesFactory.cs:23)

## Cree l'emetteur sous `parent` (eteint).
static func creer(parent: Node, taille: Vector2) -> ApkParticles:
	var e := ApkParticles.new()
	e.name = "ApkParticles"
	e.set_size(taille)
	parent.add_child(e)
	return e

## Emetteur enfant nomme de `parent`, cree a la demande (jamais cree pour rien : on == false sans emetteur existant ne fait rien).
## `centre` : position de l'emetteur dans le repere de `parent` ; derriere : dessine derriere `parent` (cadre, carte).
static func sur(parent: Node, nom: String, centre: Vector2, taille: Vector2, on: bool, derriere := true) -> ApkParticles:
	var e := parent.get_node_or_null(nom) as ApkParticles
	if e == null:
		if not on:
			return null
		e = creer(parent, taille)
		e.name = nom
		e.show_behind_parent = derriere
	e.position = centre
	e.set_size(taille)
	e.set_emit(on)
	return e

## Emit = true / false : plus de naissance quand c'est faux, mais les particules vivantes finissent leur vie (ParticleSystemRenderer2D.cs:179-189).
func set_emit(on: bool) -> void:
	emitting = on

## EmitterSize : les points d'emission sont regeneres seulement si la taille change.
func set_size(taille: Vector2) -> void:
	if taille.is_equal_approx(_taille):
		return
	_taille = taille
	_regenerer()

## Arret definitif : plus d'emission, les vivantes finissent leur vie, puis le noeud disparait (la carte porteuse peut avoir ete detruite entre-temps).
func finir() -> void:
	suit = null
	emitting = false
	if is_inside_tree():
		get_tree().create_timer(VIE_MAX + 0.2).timeout.connect(queue_free)

func _process(_delta: float) -> void:
	if suit == null:
		return
	if is_instance_valid(suit) and suit.is_inside_tree():
		global_position = suit.get_global_transform() * (suit.size * 0.5)
	else:
		queue_free() # le porteur a disparu (vol interrompu) : pas de queue orpheline

## Forme Rectangle = CONTOUR : un des 4 cotes au hasard (equiprobables, quelle que soit leur longueur), puis une position aleatoire sur ce cote
## (ParticleSystemRenderer2D.cs:501-526). CPUParticles2D n'a pas cette forme : une liste de points (POINTS_PAR_COTE par cote) en tient lieu.
## Vitesse : chaque point porte sa propre vitesse (vx, vy) tiree dans [V_MIN ; V_MAX] x 60 px/s par axe (cs:465-466) ; CPUParticles2D n'a pas de
## vitesse par axe, mais en mode « points diriges » la vitesse initiale (1) est tournee/etiree par la normale du point, non normalisee.
func _regenerer() -> void:
	var hx := _taille.x * 0.5
	var hy := _taille.y * 0.5
	var pts := PackedVector2Array()
	pts.resize(POINTS_PAR_COTE * 4)
	if _vitesses.size() != pts.size():
		_vitesses.resize(pts.size())
		for i in _vitesses.size():
			_vitesses[i] = Vector2(randf_range(V_MIN, V_MAX), randf_range(V_MIN, V_MAX)) * PX_PAR_UNITE
	for i in POINTS_PAR_COTE:
		pts[i] = Vector2(hx, hy * randf_range(-1.0, 1.0))                                         # cote 0 : x + (cs:510-511)
		pts[POINTS_PAR_COTE + i] = Vector2(-hx, hy * randf_range(-1.0, 1.0))   # cote 1 : x - (cs:515-516)
		pts[2 * POINTS_PAR_COTE + i] = Vector2(hx * randf_range(-1.0, 1.0), hy) # cote 2 : y + (cs:519-520)
		pts[3 * POINTS_PAR_COTE + i] = Vector2(hx * randf_range(-1.0, 1.0), -hy) # cote 3 : y - (cs:523)
	emission_points = pts
	emission_normals = _vitesses
