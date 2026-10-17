// Passada somada por cima da malha do monstro (BMD::RenderMesh com RENDER_BRIGHT no cliente):
// a mesma malha desenhada de novo, somada, com a propria textura ou outra (pele de luz *_r.jpg),
// presa na normal (RENDER_CHROME / RENDER_CHROME2 / RENDER_METAL, como o brilho_item.gdshader) ou correndo,
// e o brilho pulsando: luz = base + amp * sin(t * w). Vai no next_pass do material da malha
// (Boneco.camada). Sem escrever POSITION: no navegador ele fica indefinido onde nao e escrito.
shader_type spatial;
render_mode blend_add, unshaded, depth_draw_never, cull_disabled, shadows_disabled;

uniform sampler2D tex : source_color, filter_linear, repeat_enable;
uniform vec4 cor = vec4(1.0);
uniform int modo = 0;
uniform vec2 corre = vec2(0.0);
uniform vec3 pulso = vec3(1.0, 0.0, 0.0);

void vertex() {
	vec3 n = NORMAL;
	if (modo == 1) {
		float wave = mod(TIME, 10.0) * 0.1;
		UV = vec2(n.z * 0.5 + wave, n.y * 0.5 + wave * 2.0);
	} else if (modo == 2) {
		float wave2 = mod(TIME, 5.0) * 0.24 - 0.4;
		UV = vec2((n.z + n.x) * 0.8 + wave2 * 2.0, (n.y + n.x) + wave2 * 3.0);
	} else if (modo == 3) {
		UV = clamp(vec2(n.z * 0.5 + 0.2, n.y * 0.5 + 0.5), 0.0, 1.0);
	} else {
		UV += corre * TIME;
	}
}

void fragment() {
	float l = max(pulso.x + pulso.y * sin(TIME * pulso.z), 0.0);
	ALBEDO = texture(tex, UV).rgb * cor.rgb * l;
}
