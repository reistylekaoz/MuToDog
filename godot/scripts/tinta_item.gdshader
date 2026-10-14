// Cor do item +3 a +6, como o cliente: +3/+4 puxa pro vermelho, +5/+6 pro azul
// (a luz da peca multiplicada). Vai como material_overlay da malha.
shader_type spatial;
render_mode blend_mul, unshaded, depth_draw_never, cull_back, shadows_disabled;

uniform vec3 tinta = vec3(1.0, 0.6, 0.6);

void fragment() {
	ALBEDO = tinta;
}
