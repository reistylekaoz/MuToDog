// Igual ao efeito.gdshader, mas misturando pelo alfa (EnableAlphaBlend3: a poeira smoke02 das montarias).
shader_type spatial;
render_mode blend_mix, unshaded, depth_draw_never, cull_disabled, shadows_disabled;

uniform sampler2D tex : source_color, filter_linear, repeat_enable;
uniform vec4 cor : source_color = vec4(1.0);
uniform int modo = 0;
uniform float giro = 0.0;
uniform vec2 uv_desl = vec2(0.0);
uniform vec2 uv_esc = vec2(1.0);

void vertex() {
	UV = UV * uv_esc + uv_desl;
	if (modo == 0) {
		float c = cos(giro);
		float s = sin(giro);
		VERTEX.xy = mat2(vec2(c, s), vec2(-s, c)) * VERTEX.xy;
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
			INV_VIEW_MATRIX[0] * length(MODEL_MATRIX[0].xyz),
			INV_VIEW_MATRIX[1] * length(MODEL_MATRIX[1].xyz),
			INV_VIEW_MATRIX[2] * length(MODEL_MATRIX[2].xyz),
			MODEL_MATRIX[3]);
	}
}

void fragment() {
	vec4 t = texture(tex, UV);
	// RenderSprite manda a luz no RGB e no alfa (PackABGR(L, L, L, L[0])): escurece e some junto
	ALBEDO = t.rgb * cor.rgb * cor.a * COLOR.rgb;
	ALPHA = t.a * cor.a;
}
