class_name Ambiente
extends Node3D
# O que da vida ao mapa, no jeito do cliente S6 (ZzzLodTerrain, ZzzObject, ZzzEffect):
# - grama: um "cartao" em pe em cada tile de grama sem mistura, balancando no vento;
# - fogo e fumaca nos objetos que o cliente acende (tocha, fogueira, ponte, portao);
# - luz do fogo pintada no chao (AddTerrainLight, raio de 4 tiles), piscando;
# - a bica d'agua da praca com a textura correndo.
# A agua do chao corre no proprio shader do terreno (terreno.gdshader).

const PASTA := "res://dados/ambiente/"
const TILES := 256

# objeto -> [[tipo, x, y, z]] em unidades do MU, relativo ao objeto (CreateFire do cliente)
# tipo 0 = fogo, 1 e 2 = fumaca
const FOGOS := {
	1: {
		"light01": [[0, 0, 0, 0]], "light02": [[1, 0, 0, 0]], "light03": [[2, 0, 0, 0]],
		"bridge01": [[0, 90, -200, 30], [0, 90, 200, 30]],
		"doungeongate01": [[0, -150, -150, 140], [0, 150, -150, 140]],
		"firelight01": [[0, 0, 0, 200]], "firelight02": [[0, 0, -30, 60]], "bonfire01": [[0, 0, 0, 60]],
	},
}
# luz que nao e fogo: poste e vela (cor media do cliente e raio em tiles)
const LUZES := {
	1: {"streetlight01": [Color(0.65, 0.52, 0.39), 3], "candle01": [Color(0.45, 0.27, 0.09), 3]},
}
const COR_FOGO := Color(0.85, 0.51, 0.34)   # Luminosity media 0,85 x (1, 0,6, 0,4)

var mundo: Node3D
var _bica: Array[ShaderMaterial] = []
var _t := 0.0
var fogos := 0
var gramas := 0


func montar(m: Node3D, mapa: Image, luz: Image, objetos: Array) -> void:
	mundo = m
	var extra := PackedFloat32Array()
	extra.resize(TILES * TILES * 3)
	var tex_fogo := load(PASTA + "fogo.png") as Texture2D
	var tex_fumaca := load(PASTA + "fumaca.png") as Texture2D
	var fogos_mapa: Dictionary = FOGOS.get(m.numero, {})
	var luzes_mapa: Dictionary = LUZES.get(m.numero, {})
	for o in objetos:
		var p := Vector3(o.p[0], o.p[1], o.p[2])
		var b := Basis(Quaternion(o.q[0], o.q[1], o.q[2], o.q[3]))
		for f in fogos_mapa.get(o.m, []):
			var pos: Vector3 = p + b * Vector3(f[1], f[2], f[3])
			if f[0] == 0:
				_luz(extra, pos, COR_FOGO, 4)
				add_child(_fogo(tex_fogo, pos))
			else:
				add_child(_fumaca(tex_fumaca, pos))
			fogos += 1
		if luzes_mapa.has(o.m):
			_luz(extra, p, luzes_mapa[o.m][0], luzes_mapa[o.m][1])
		if o.m == "waterspout01":
			_bica_agua(o)
	var img := Image.create_from_data(TILES, TILES, false, Image.FORMAT_RGBF, extra.to_byte_array())
	var tex_extra := ImageTexture.create_from_image(img)
	var terreno := m.mu.get_node_or_null("Terreno") as MeshInstance3D
	if terreno:
		terreno.material_override.set_shader_parameter("luz_extra", tex_extra)
	for mat: ShaderMaterial in m.materiais.values():
		mat.set_shader_parameter("luz_extra", tex_extra)
	_grama(mapa, luz, img)


# AddTerrainLight: soma a luz nos vertices em volta, caindo em linha reta ate o raio
func _luz(buf: PackedFloat32Array, pos: Vector3, cor: Color, raio: int) -> void:
	var xf := pos.x / 100.0
	var yf := pos.y / 100.0
	var xi := int(xf)
	var yi := int(yf)
	for y in range(yi - raio, yi + raio + 1):
		for x in range(xi - raio, xi + raio + 1):
			var lf := (raio - Vector2(xf - x, yf - y).length()) / raio
			if lf <= 0.0:
				continue
			var i := ((y & 255) * TILES + (x & 255)) * 3
			buf[i] += cor.r * lf
			buf[i + 1] += cor.g * lf
			buf[i + 2] += cor.b * lf


func _no_mundo(pos_mu: Vector3) -> Vector3:
	return mundo.mu.transform * pos_mu


func _material_particula(tex: Texture2D, quadros: int) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.particles_anim_h_frames = quadros
	mat.particles_anim_v_frames = 1
	mat.vertex_color_use_as_albedo = true
	mat.albedo_texture = tex
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	return mat


# BITMAP_FIRE subtipo 0: 24 quadros de vida, 4 desenhos da tira, encolhe e apaga subindo
func _fogo(tex: Texture2D, pos_mu: Vector3) -> CPUParticles3D:
	var c := CPUParticles3D.new()
	c.position = _no_mundo(pos_mu)
	c.amount = 12
	c.lifetime = 0.96
	c.preprocess = 1.0
	c.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	c.emission_box_extents = Vector3(0.08, 0.08, 0.08)
	c.direction = Vector3.UP
	c.spread = 8.0
	c.initial_velocity_min = 0.3
	c.initial_velocity_max = 0.5
	c.gravity = Vector3(0, 0.25, 0)
	c.scale_amount_min = 1.28
	c.scale_amount_max = 1.92
	c.scale_amount_curve = _curva(1.0, 0.4)
	c.anim_speed_min = 1.0
	c.anim_speed_max = 1.0
	var g := Gradient.new()
	g.set_color(0, Color(1, 0.6, 0.4))
	g.set_color(1, Color(0, 0, 0))
	c.color_ramp = g
	var q := QuadMesh.new()
	q.size = Vector2(0.64, 0.64)
	q.material = _material_particula(tex, 4)
	c.mesh = q
	return c


# BITMAP_SMOKE: 16 quadros de vida, cresce, sobe acelerando e apaga
func _fumaca(tex: Texture2D, pos_mu: Vector3) -> CPUParticles3D:
	var c := CPUParticles3D.new()
	c.position = _no_mundo(pos_mu)
	c.amount = 8
	c.lifetime = 0.64
	c.preprocess = 1.0
	c.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	c.emission_box_extents = Vector3(0.08, 0.08, 0.08)
	c.direction = Vector3.UP
	c.spread = 10.0
	c.initial_velocity_min = 0.1
	c.initial_velocity_max = 0.2
	c.gravity = Vector3(0, 1.2, 0)
	c.angle_min = 0.0
	c.angle_max = 360.0
	c.scale_amount_min = 0.48
	c.scale_amount_max = 0.8
	c.scale_amount_curve = _curva(1.0, 2.2)
	var g := Gradient.new()
	g.set_color(0, Color(0.45, 0.45, 0.45))
	g.set_color(1, Color(0, 0, 0))
	c.color_ramp = g
	var q := QuadMesh.new()
	q.size = Vector2(0.64, 0.64)
	var mat := _material_particula(tex, 1)
	mat.billboard_keep_scale = true
	q.material = mat
	c.mesh = q
	return c


func _curva(de: float, ate: float) -> Curve:
	var cv := Curve.new()
	cv.max_value = maxf(de, ate)
	cv.add_point(Vector2(0, de))
	cv.add_point(Vector2(1, ate))
	return cv


# a bica da praca: a malha 3 (a agua) corre pra baixo, uma volta por segundo
func _bica_agua(o: Dictionary) -> void:
	for n in mundo.mu.get_node("Objetos").get_children():
		if not n.transform.origin.is_equal_approx(Vector3(o.p[0], o.p[1], o.p[2])):
			continue
		for mi in n.find_children("*", "MeshInstance3D", true, false):
			var malha := (mi as MeshInstance3D).mesh
			if malha == null or malha.get_surface_count() < 4:
				continue
			var mat := (mi as MeshInstance3D).get_surface_override_material(3)
			if mat is ShaderMaterial:
				var copia := mat.duplicate() as ShaderMaterial
				(mi as MeshInstance3D).set_surface_override_material(3, copia)
				_bica.append(copia)


# TERRAIN_MAP_GRASS: em cada tile de grama (camada 1 = 0) sem mistura, um cartao
# em pe na borda de baixo do tile, 128 de altura, topo puxado -50 em X, textura
# com deslocamento sorteado por linha. O vento mexe o topo no shader.
func _grama(mapa: Image, luz: Image, extra: Image) -> void:
	var tex := load(PASTA + "grama.png") as Texture2D
	if tex == null:
		return
	var alto := float(tex.get_height()) * 2.0
	var largura := 64.0 / float(tex.get_width())
	var desloc := PackedFloat32Array()
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	for y in TILES:
		desloc.append(float(rng.randi() % 4) / 4.0)
	var vs := PackedVector3Array()
	var uvs := PackedVector2Array()
	var cores := PackedColorArray()
	var idx := PackedInt32Array()
	for y in TILES - 1:
		for x in TILES - 1:
			if int(round(mapa.get_pixel(x, y).r * 255.0)) != 0:
				continue
			if mapa.get_pixel(x, y).b > 0.0 or mapa.get_pixel(x + 1, y).b > 0.0 \
					or mapa.get_pixel(x, y + 1).b > 0.0 or mapa.get_pixel(x + 1, y + 1).b > 0.0:
				continue
			var su := x * largura + desloc[y]
			var b0 := Vector3(x * 100.0, (y + 1) * 100.0, mundo.altura_em(x, y + 1))
			var b1 := Vector3((x + 1) * 100.0, (y + 1) * 100.0, mundo.altura_em(x + 1, y + 1))
			var n := vs.size()
			vs.append(b0 + Vector3(-50, 0, alto))
			vs.append(b1 + Vector3(-50, 0, alto))
			vs.append(b1)
			vs.append(b0)
			uvs.append(Vector2(su, 0))
			uvs.append(Vector2(su + largura, 0))
			uvs.append(Vector2(su + largura, 1))
			uvs.append(Vector2(su, 1))
			# luz do vertice: a do mapa mais a do fogo (o cliente usa a do tile e do vizinho)
			for c in [Vector2i(x, y), Vector2i(x + 1, y), Vector2i(x + 1, y + 1), Vector2i(x, y + 1)]:
				var l := luz.get_pixel(c.x, c.y) + extra.get_pixel(c.x, c.y)
				cores.append(Color(minf(l.r, 1.0), minf(l.g, 1.0), minf(l.b, 1.0)))
			idx.append_array([n, n + 1, n + 2, n, n + 2, n + 3])
	gramas = vs.size() / 4
	if gramas == 0:
		return
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = vs
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_COLOR] = cores
	arr[Mesh.ARRAY_INDEX] = idx
	var malha := ArrayMesh.new()
	malha.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var mat := ShaderMaterial.new()
	mat.shader = load("res://scripts/grama.gdshader")
	mat.set_shader_parameter("textura", tex)
	mat.set_shader_parameter("brilho", mundo.brilho)
	var mi := MeshInstance3D.new()
	mi.name = "Grama"
	mi.mesh = malha
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mundo.mu.add_child(mi)


func _process(dt: float) -> void:
	_t += dt
	for m in _bica:
		m.set_shader_parameter("rolagem", Vector2(0, -fmod(_t, 1.0)))
