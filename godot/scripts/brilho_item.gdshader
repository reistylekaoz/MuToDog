// Brilho do item +7 em diante, como o cliente (RenderPartObjectEffect e BMD::RenderMesh):
// passadas somadas por cima da peca, com a textura presa na normal do modelo (coordenadas
// do MU) e correndo com o tempo. +7/+8: cromo (Chrome01) na cor do item; +9/+10: mais o
// metal (Shiny01); +11/+12: mais o Chrome02 (RENDER_CHROME2); +13 a +15: Chrome02 no jeito
// RENDER_CHROME4. Vai como material_overlay da malha.
shader_type spatial;
render_mode blend_add, unshaded, depth_draw_never, cull_back, shadows_disabled;

uniform sampler2D cromo : repeat_enable, filter_linear;
uniform sampler2D cromo2 : repeat_disable, filter_nearest;
uniform sampler2D metal : repeat_disable, filter_linear;
uniform vec3 cor = vec3(1.0, 0.5, 0.0);
uniform vec3 cor2 = vec3(1.0);
uniform int nivel = 7;

varying vec2 uv_cromo;
varying vec2 uv_metal;
varying vec2 uv_cromo2;
varying vec2 uv_cromo4;

void vertex() {
	vec3 n = NORMAL;
	float wave = mod(TIME, 10.0) * 0.1;
	float wave2 = mod(TIME, 5.0) * 0.24 - 0.4;
	vec3 luz = vec3(cos(TIME), sin(TIME * 2.0), 1.0);
	uv_cromo = vec2(n.z * 0.5 + wave, n.y * 0.5 + wave * 2.0);
	uv_metal = vec2(n.z * 0.5 + 0.2, n.y * 0.5 + 0.5);
	uv_cromo2 = vec2((n.z + n.x) * 0.8 + wave2 * 2.0, (n.y + n.x) + wave2 * 3.0);
	float d = dot(n, luz);
	uv_cromo4 = vec2(d + n.y * 0.5 + luz.y * 3.0, 1.0 - d - (n.z * 0.5 + wave * 3.0));
}

void fragment() {
	vec3 c = texture(cromo, uv_cromo).rgb * cor;
	if (nivel >= 9) {
		c += texture(metal, uv_metal).rgb * cor;
	}
	if (nivel >= 13) {
		c += texture(cromo2, uv_cromo4).rgb * cor2;
	} else if (nivel >= 11) {
		c += texture(cromo2, uv_cromo2).rgb * cor2;
	}
	ALBEDO = c;
}
