// Chao do MU: cada tile tem 2 texturas (camada 1 e 2) e a mistura vem do vertice.
// UV = coordenada do tile (0..256). COLOR.rgb = luz pintada do mapa, COLOR.a = mistura.
shader_type spatial;
render_mode unshaded, cull_disabled;

uniform sampler2D mapa : filter_nearest;
uniform sampler2DArray tiles : filter_linear_mipmap, repeat_enable;
uniform float repete[32];
uniform float brilho = 1.0;

vec3 amostra(int i, vec2 uv) {
	i = clamp(i, 0, 31);
	return texture(tiles, vec3(uv / repete[i], float(i))).rgb;
}

void fragment() {
	ivec2 t = clamp(ivec2(floor(UV)), ivec2(0), ivec2(255));
	vec4 m = texelFetch(mapa, t, 0);
	vec3 c1 = amostra(int(m.r * 255.0 + 0.5), UV);
	vec3 c2 = amostra(int(m.g * 255.0 + 0.5), UV);
	// a conta do MU e feita em sRGB (como no cliente original); converte so no fim
	vec3 c = mix(c1, c2, COLOR.a) * COLOR.rgb * brilho;
	ALBEDO = pow(clamp(c, 0.0, 1.0), vec3(2.2));
}
