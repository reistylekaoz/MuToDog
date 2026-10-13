// Objeto do mapa no jeito do cliente (ZzzObject + ZzzBMD): sem sol do Godot e sem brilho
// especular. A luz e a do chao embaixo do objeto (RequestTerrainLight: mapa de luz + fogo)
// vezes a inclinacao da face com a luz fixa do MU (0, -1,5, 0) no espaco do modelo:
// max(0,4 - 1,2 * normal.y, 0,2), com a normal ja girada pelo objeto (Y do MU = -Z do Godot).
shader_type spatial;
render_mode unshaded, cull_disabled;

uniform sampler2D textura : filter_linear_mipmap, repeat_enable;
uniform sampler2D luz_mapa : filter_linear;
uniform sampler2D luz_extra : filter_linear, hint_default_black;
uniform float brilho = 1.0;
uniform float corte = 0.0;
uniform vec2 rolagem = vec2(0.0);

void vertex() {
	// origem do objeto em tiles: Godot (x, z) = MU (x, -y) / 100
	vec3 o = MODEL_MATRIX[3].xyz;
	vec2 uv = (vec2(o.x, -o.z) + 0.5) / 256.0;
	vec3 luz = texture(luz_mapa, uv).rgb + texture(luz_extra, uv).rgb;
	vec3 n = normalize(MODEL_NORMAL_MATRIX * NORMAL);
	float lum = max(0.4 + 1.2 * n.z, 0.2);
	COLOR = vec4(min(luz * lum, vec3(1.0)), 1.0);
}

void fragment() {
	vec4 t = texture(textura, UV + rolagem);
	if (corte > 0.0 && t.a < corte) {
		discard;
	}
	vec3 c = t.rgb * COLOR.rgb * brilho;
	ALBEDO = pow(clamp(c, 0.0, 1.0), vec3(2.2));
}
