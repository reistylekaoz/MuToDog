class_name RastroOlho
extends MeshInstance3D
# Rastro de luz que sai dos olhos dos monstros de Tarkan (CreateJoint BITMAP_JOINT_ENERGY
# subtipo 2 e 3 no CreateMonster, preso no EyeLeft/EyeRight que o MoveEye acha no osso):
# guarda a posicao do olho a cada quadro do cliente (25 por segundo) e desenha uma fita
# virada pra camera, somada, com 30 de largura, que some no fim.

var alvo: Node3D
var pontas := 20              # MaxTails: 20 no olho esquerdo, 8 no direito
var largura := 0.3
var _pontos: Array[Vector3] = []
var _t := 0.0
var _mat: ShaderMaterial


static func no_olho(alvo_no: Node3D, n: int) -> RastroOlho:
	var r := RastroOlho.new()
	r.alvo = alvo_no
	r.pontas = n
	r.top_level = true
	r.mesh = ImmediateMesh.new()
	r.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	r._mat = ShaderMaterial.new()
	r._mat.shader = EfeitoMU.SHADER
	r._mat.set_shader_parameter("tex", EfeitoMU.textura("jointenergy01"))
	r._mat.set_shader_parameter("modo", 1)
	alvo_no.add_child(r)
	return r


func _process(d: float) -> void:
	if not is_instance_valid(alvo) or not alvo.is_visible_in_tree():
		_pontos.clear()
		(mesh as ImmediateMesh).clear_surfaces()
		return
	_t += d
	if _t >= 0.04 or _pontos.is_empty():
		_t = 0.0
		_pontos.push_front(alvo.global_position)
		while _pontos.size() > pontas:
			_pontos.pop_back()
	else:
		_pontos[0] = alvo.global_position
	var im: ImmediateMesh = mesh
	im.clear_surfaces()
	var cam := get_viewport().get_camera_3d()
	if _pontos.size() < 2 or cam == null:
		return
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP, _mat)
	var n := _pontos.size()
	for i in n:
		var p := _pontos[i]
		var dir := (_pontos[maxi(i - 1, 0)] - _pontos[mini(i + 1, n - 1)])
		var f := 1.0 - float(i) / (n - 1)
		# afina ate a ponta; olho parado (sem rumo) nao desenha fita
		var lado := Vector3.ZERO
		if dir.length() > 0.02:
			lado = dir.cross(cam.global_position - p).normalized() * largura * 0.5 * (0.3 + 0.7 * f)
		im.surface_set_color(Color(f, f, f))
		im.surface_set_uv(Vector2(float(i) / (n - 1), 0))
		im.surface_add_vertex(p + lado)
		im.surface_set_color(Color(f, f, f))
		im.surface_set_uv(Vector2(float(i) / (n - 1), 1))
		im.surface_add_vertex(p - lado)
	im.surface_end()
