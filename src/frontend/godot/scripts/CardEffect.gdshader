shader_type canvas_item;
// DBMGame.CardEffectpsTexture.frag : gris = 0,3 R + 0,55 G + 0,15 B ; mix(gris, couleur, Amount) ; le tout x outColor (couleur de sommet = teinte x opacite).
// `amt` = Amount de CardMaterial (1 = couleur, 0 = gris). Sans le x outColor, la modulation du noeud (opacite 0,8 d'une carte grisee) serait perdue.
uniform float amt : hint_range(0.0, 1.0) = 1.0;
varying vec4 out_color;

void vertex() {
	out_color = COLOR; // couleur de sommet x modulate (parents compris)
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float g = dot(c.rgb, vec3(0.3, 0.55, 0.15));
	COLOR = vec4(mix(vec3(g), c.rgb, amt), c.a) * out_color;
}
