// Objeto do mapa no modo polido (Polido): a mesma conta do objeto.gdshader (luz pintada do MU e a
// inclinacao da face), e o sol do Godot so poe sombra: light() soma o sol sem olhar a face, entao no
// sol fica no tom do original (ambiente + sol = 1) e na sombra fica so o ambiente.
shader_type spatial;
render_mode cull_disabled;

uniform sampler2D textura : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap, repeat_enable;
uniform bool usar_normal = false;
uniform sampler2D luz_mapa : filter_linear;
uniform sampler2D luz_extra : filter_linear, hint_default_black;
uniform float brilho = 1.0;
uniform float corte = 0.0;
uniform vec2 rolagem = vec2(0.0);

void vertex() {
	vec3 o = MODEL_MATRIX[3].xyz;
	vec2 uv = (vec2(o.x, -o.z) + 0.5) / 256.0;
	vec3 luz = texture(luz_mapa, uv).rgb + texture(luz_extra, uv).rgb;
	vec3 n = normalize(MODEL_NORMAL_MATRIX * NORMAL);
	float lum = max(0.4 + 1.2 * n.z, 0.2);
	COLOR = vec4(min(luz * lum, vec3(1.0)) * brilho, 1.0);
}

void fragment() {
	vec4 t = texture(textura, UV + rolagem);
	if (corte > 0.0 && t.a < corte) {
		discard;
	}
	// a conta do MU em sRGB (como no objeto.gdshader); o sol e a sombra do Godot vem por cima
	ALBEDO = pow(clamp(t.rgb * COLOR.rgb, 0.0, 1.0), vec3(2.2));
	if (usar_normal) {
		NORMAL_MAP = texture(normal_tex, UV + rolagem).rgb;
		NORMAL_MAP_DEPTH = 1.0;
	}
}

void light() {
	DIFFUSE_LIGHT += ATTENUATION * LIGHT_COLOR / PI;
}
