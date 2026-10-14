class_name RastroArma
extends MeshInstance3D
# Rastro da arma no golpe (o BITMAP_BLUR do cliente, CreateBlur / RenderBlurs): guarda
# a base e a ponta da lamina a cada quadro e desenha uma fita somada que vai sumindo.
# A lamina sai da maior medida da malha da arma (a arma do MU nao diz onde e a ponta).

const AMOSTRAS := 12

var arma: Node3D
var base := Vector3.ZERO     # na arma (coordenadas do no 'arma')
var ponta := Vector3.ZERO
var ate := 0.0               # segundos que ainda grava
var cor := Color(1, 1, 1)
var _pontos: Array = []      # [base global, ponta global]
var _mat: ShaderMaterial


static func na_arma(arma_no: Node3D) -> RastroArma:
	var r := RastroArma.new()
	r.arma = arma_no
	r.top_level = true
	r.mesh = ImmediateMesh.new()
	r.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	r._mat = ShaderMaterial.new()
	r._mat.shader = EfeitoMU.SHADER
	r._mat.set_shader_parameter("tex", EfeitoMU.textura("blur01"))
	r._mat.set_shader_parameter("modo", 1)
	# a lamina: a maior medida da caixa da malha, do cabo (mais perto da mao) a ponta
	var caixa := AABB()
	var primeira := true
	for mi: MeshInstance3D in arma_no.find_children("*", "MeshInstance3D", true, false):
		var c: AABB = (arma_no.global_transform.affine_inverse() * mi.global_transform) * mi.get_aabb()
		caixa = c if primeira else caixa.merge(c)
		primeira = false
	var eixo := caixa.get_longest_axis_index()
	var a := caixa.get_center()
	var b := a
	a[eixo] = caixa.position[eixo]
	b[eixo] = caixa.end[eixo]
	# o cabo e a ponta mais perto da origem da arma (a mao)
	if a.length() > b.length():
		var x := a
		a = b
		b = x
	r.base = a.lerp(b, 0.25)
	r.ponta = b
	arma_no.add_child(r)
	return r


func ligar(segundos: float, c: Color, tex := "blur01") -> void:
	ate = segundos
	cor = c
	_mat.set_shader_parameter("tex", EfeitoMU.textura(tex))


func _process(d: float) -> void:
	if not is_instance_valid(arma) or not arma.is_visible_in_tree():
		_pontos.clear()
	elif ate > 0.0:
		ate -= d
		var g := arma.global_transform
		_pontos.push_front([g * base, g * ponta])
	elif not _pontos.is_empty():
		_pontos.pop_back()
	while _pontos.size() > AMOSTRAS:
		_pontos.pop_back()
	var im: ImmediateMesh = mesh
	im.clear_surfaces()
	if _pontos.size() < 2:
		return
	_mat.set_shader_parameter("cor", cor)
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP, _mat)
	var n := _pontos.size()
	for i in n:
		var f := 1.0 - float(i) / (n - 1)
		var u := f
		im.surface_set_color(Color(f, f, f))
		im.surface_set_uv(Vector2(u, 0))
		im.surface_add_vertex(_pontos[i][1])
		im.surface_set_uv(Vector2(u, 1))
		im.surface_add_vertex(_pontos[i][0])
	im.surface_end()
