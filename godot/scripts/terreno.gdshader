// Chao do MU: cada tile tem 2 texturas (camada 1 e 2) e a mistura vem do vertice.
// UV = coordenada do tile (0..256). COLOR.rgb = luz pintada do mapa, COLOR.a = mistura.
// luz_extra = luz do fogo, poste e vela (AddTerrainLight do cliente), piscando por regiao.
// A textura de agua corre em U (WaterMove: 1 volta a cada 20 s) e ondula em V com o vento.
shader_type spatial;
render_mode unshaded, cull_disabled;

uniform sampler2D mapa : filter_nearest;
uniform sampler2DArray tiles : filter_linear_mipmap, repeat_enable;
uniform sampler2D luz_extra : filter_nearest, hint_default_black;
uniform float repete[32];
uniform float brilho = 1.0;
// invasao do dragao (MoveBoids com EnableEvent): AddTerrainLight (-0,3 -0,3 -0,2) em 16 tiles do heroi
uniform vec3 sombra = vec3(0.0);       // x e y do heroi em tiles, raio (0 = desligada)
uniform vec3 sombra_cor = vec3(-0.3, -0.3, -0.2);
uniform int agua = 5;
// Atlans: onde a camada 2 e agua, a camada 1 fica inteira e a agua (wt00..31 do Object8,
// 25 quadros por segundo, 4 tiles por textura) vai somada na forca da mistura (RenderFaceBlend)
uniform bool agua_soma = false;
uniform float agua_vel = 0.05;   // rolagem da agua por segundo (Tarkan 0,025)
uniform sampler2DArray agua_quadros : filter_linear_mipmap, repeat_enable;

float sorteio(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void vertex() {
	ivec2 v = clamp(ivec2(round(UV)), ivec2(0), ivec2(255));
	// a luminosidade do fogo varia 0,6..1,1 a cada quadro do cliente (12,5 por segundo aqui)
	float pisca = 0.7 + 0.6 * sorteio(vec2(floor(TIME * 12.5)) + floor(vec2(v) / 4.0));
	COLOR.rgb = min(COLOR.rgb + texelFetch(luz_extra, v, 0).rgb * pisca, vec3(1.0));
	if (sombra.z > 0.0) {
		float lf = (sombra.z - distance(vec2(v), sombra.xy)) / sombra.z;
		if (lf > 0.0) {
			COLOR.rgb = max(COLOR.rgb + sombra_cor * lf, vec3(0.0));
		}
	}
}

vec3 amostra(int i, vec2 uv) {
	i = clamp(i, 0, 31);
	vec2 t = uv / repete[i];
	if (i == agua) {
		t.x += mod(TIME * agua_vel, 1.0);
		t.y += sin(TIME * 2.0 + uv.x * 5.0) * 0.02;
	}
	return texture(tiles, vec3(t, float(i))).rgb;
}

void fragment() {
	ivec2 t = clamp(ivec2(floor(UV)), ivec2(0), ivec2(255));
	vec4 m = texelFetch(mapa, t, 0);
	vec3 c1 = amostra(int(m.r * 255.0 + 0.5), UV);
	vec3 c2 = amostra(int(m.g * 255.0 + 0.5), UV);
	// a conta do MU e feita em sRGB (como no cliente original); converte so no fim
	vec3 c;
	if (agua_soma && int(m.g * 255.0 + 0.5) == agua) {
		float q = mod(floor(TIME * 25.0), 32.0);
		c = c1 * COLOR.rgb * brilho + texture(agua_quadros, vec3(UV / 4.0, q)).rgb * COLOR.a;
	} else {
		c = mix(c1, c2, COLOR.a) * COLOR.rgb * brilho;
	}
	ALBEDO = pow(clamp(c, 0.0, 1.0), vec3(2.2));
}
