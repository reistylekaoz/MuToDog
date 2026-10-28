// Grama do MU (TERRAIN_MAP_GRASS): cartao em pe, corte no alfa, luz do vertice.
// O topo (UV.y = 0) balanca em Y do MU: sin(2t + 5x) * 10, como o TerrainGrassWind.
shader_type spatial;
render_mode unshaded, cull_disabled;

uniform sampler2D textura : filter_nearest, repeat_enable;
uniform float brilho = 1.0;
uniform float vento = 2.0;   // invasao do dragao: 5 vezes mais rapido (WindSpeed 0,01 em vez de 0,002)

void vertex() {
	if (UV.y < 0.5) {
		float x = (VERTEX.x + 50.0) / 100.0;
		VERTEX.y += sin(TIME * vento + x * 5.0) * 10.0;
	}
}

void fragment() {
	vec4 t = texture(textura, UV);
	if (t.a < 0.25) {
		discard;
	}
	vec3 c = t.rgb * COLOR.rgb * brilho;
	ALBEDO = pow(clamp(c, 0.0, 1.0), vec3(2.2));
}
