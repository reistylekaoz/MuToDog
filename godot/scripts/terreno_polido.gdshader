// Chao do MU no modo polido (Polido): igual ao terreno.gdshader, e o sol do Godot so poe sombra
// (light() soma o sol sem olhar a face): no sol fica no tom do original, na sombra so o ambiente.
// Com ?polido=hd: textura ampliada e normal map por camada.
// Chao do MU: cada tile tem 2 texturas (camada 1 e 2) e a mistura vem do vertice.
// UV = coordenada do tile (0..256). COLOR.rgb = luz pintada do mapa, COLOR.a = mistura.
// luz_extra = luz do fogo, poste e vela (AddTerrainLight do cliente), piscando por regiao.
// A textura de agua corre em U (WaterMove: 1 volta a cada 20 s) e ondula em V com o vento.
shader_type spatial;
render_mode cull_disabled;

uniform sampler2D mapa : filter_nearest;
uniform sampler2DArray tiles : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2DArray tiles_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform bool usar_normal = false;
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

vec3 amostra_n(int i, vec2 uv) {
	i = clamp(i, 0, 31);
	return texture(tiles_normal, vec3(uv / repete[i], float(i))).rgb;
}

void fragment() {
	ivec2 t = clamp(ivec2(floor(UV)), ivec2(0), ivec2(255));
	vec4 m = texelFetch(mapa, t, 0);
	int i1 = int(m.r * 255.0 + 0.5);
	int i2 = int(m.g * 255.0 + 0.5);
	vec3 c1 = amostra(i1, UV);
	vec3 c2 = amostra(i2, UV);
	vec3 luz = COLOR.rgb * brilho;
	vec3 c;
	if (agua_soma && i2 == agua) {
		float q = mod(floor(TIME * 25.0), 32.0);
		c = c1 * luz + texture(agua_quadros, vec3(UV / 4.0, q)).rgb * COLOR.a;
	} else {
		c = mix(c1, c2, COLOR.a) * luz;
	}
	ALBEDO = pow(clamp(c, 0.0, 1.0), vec3(2.2));
	// a malha do chao fica de costas pra camera (o cull_disabled desenha assim) e o Godot vira a normal
	// pra baixo: sem isto o sol nunca acende o chao
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
	if (usar_normal) {
		NORMAL_MAP = mix(amostra_n(i1, UV), amostra_n(i2, UV), COLOR.a);
		NORMAL_MAP_DEPTH = 1.0;
	}
}

void light() {
	DIFFUSE_LIGHT += ATTENUATION * LIGHT_COLOR / PI;
}
