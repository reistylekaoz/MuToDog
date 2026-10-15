class_name Capa
extends MeshInstance3D
# Capa de pano (CPhysicsCloth do cliente S6, PhysicsManager.cpp): uma grade de pontos presa
# pela fileira de cima no osso 19 (costas), caindo com gravidade, com vento de leve, sem
# esticar e sem atravessar as esferas do corpo (osso 17). A fileira de cima tem 60% da
# largura (PCT_SHORT_SHOULDER) e a capa abre ate a barra; PCT_CURVED curva pra tras.
# Cape of Lord (Dark Lord) e Cape of Fighter / Overrule (Rage Fighter).

# item -> [textura, colunas, linhas, largura, altura, x, y, z (no osso 19), pesada]
const TIPOS := {
	"13,30": ["capa_darklordrobe", 10, 10, 180.0, 180.0, 0.0, 8.0, 10.0, false],
	"12,130": ["capa_darklordrobe", 10, 10, 100.0, 100.0, 0.0, 8.0, 10.0, false],
	"12,49": ["capa_nccape", 10, 10, 180.0, 170.0, 0.0, 15.0, 5.0, true],
	"12,135": ["capa_nccape", 10, 10, 150.0, 130.0, 0.0, 15.0, 5.0, true],
	"12,50": ["capa_monke_manto", 10, 10, 180.0, 170.0, 0.0, 15.0, 5.0, true],
}
# esferas no osso 17 (AddCollisionSphere): x, y, z, raio
const CORPO := [[-10.0, -10.0, -10.0, 25.0], [10.0, -10.0, -10.0, 25.0], [-10.0, -10.0, 20.0, 27.0], [10.0, -10.0, 20.0, 27.0]]
const OMBRO := 0.6   # RATE_SHORT_SHOULDER

var esqueleto: Skeleton3D
var _cfg: Array
var _nh := 10
var _nv := 10
var _p := PackedVector3Array()
var _ant := PackedVector3Array()
var _osso := -1
var _osso_corpo := -1
var _t := 0.0
var _mat: StandardMaterial3D
var _pronta := false


static func nova(esq: Skeleton3D, item: String) -> Capa:
	if not TIPOS.has(item) or esq == null:
		return null
	var c := Capa.new()
	c.esqueleto = esq
	c._cfg = TIPOS[item]
	c._nh = c._cfg[1]
	c._nv = c._cfg[2]
	c._osso = esq.find_bone("osso19")
	c._osso_corpo = esq.find_bone("osso17")
	c.top_level = true
	c.mesh = ImmediateMesh.new()
	c.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	c._mat = StandardMaterial3D.new()
	c._mat.albedo_texture = EfeitoMU.textura(c._cfg[0])
	c._mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	c._mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	c._mat.alpha_scissor_threshold = 0.3
	c._mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return c


# ponto no osso, no jeito do SetFixedVertices: (x, y, z) do cliente vira (z, -y, x) no osso
func _no_osso(osso: int, x: float, y: float, z: float) -> Vector3:
	return esqueleto.to_global(esqueleto.get_bone_global_pose(osso) * Vector3(z, -y, x))


# fileira de cima, presa nas costas
func _presos() -> PackedVector3Array:
	var r := PackedVector3Array()
	var larg: float = _cfg[3] * OMBRO
	for i in _nh:
		var x: float = larg * float(i) / (_nh - 1) - 0.5 * larg + _cfg[5]
		var f := 2.0 * absf(float(i) / (_nh - 1) - 0.5)
		r.append(_no_osso(_osso, x, _cfg[6] - 10.0 * f * f, _cfg[7]))
	return r


func _unidade() -> float:
	return esqueleto.global_transform.basis.get_scale().x


func _montar() -> void:
	var topo := _presos()
	var u := _unidade()
	var passo: float = _cfg[4] / (_nv - 1) * u
	_p.resize(_nh * _nv)
	for j in _nv:
		for i in _nh:
			var k := j * _nh + i
			var t: Vector3 = topo[i]
			var meio: Vector3 = topo[_nh / 2]
			var abre := 1.0 + (1.0 / OMBRO - 1.0) * float(j) / (_nv - 1)
			_p[k] = meio + (t - meio) * abre + Vector3.DOWN * passo * j
	_ant = _p.duplicate()
	_pronta = true


func _process(dt: float) -> void:
	if not is_instance_valid(esqueleto) or _osso < 0 or not esqueleto.is_visible_in_tree():
		visible = false
		return
	visible = true
	if not _pronta:
		_montar()
	dt = minf(dt, 0.05)
	_t += dt
	var u := _unidade()
	var grav: float = (18.0 if _cfg[8] else 10.0)
	var vento := esqueleto.global_transform.basis.z.normalized() * (0.6 + 0.4 * sin(_t * 1.7)) \
		+ esqueleto.global_transform.basis.x.normalized() * 0.3 * sin(_t * 0.9)
	# verlet: anda com a velocidade que tinha, gravidade e vento, com atrito
	for k in range(_nh, _p.size()):
		var v := (_p[k] - _ant[k]) * 0.96
		_ant[k] = _p[k]
		var onda := 0.5 + 0.5 * sin(_t * 2.3 + float(k % _nh) * 0.6 + float(k / _nh) * 0.4)
		_p[k] += v + (Vector3.DOWN * grav + vento * onda) * dt * dt
	var topo := _presos()
	for i in _nh:
		_p[i] = topo[i]
		_ant[i] = topo[i]
	var alto: float = _cfg[4] / (_nv - 1) * u
	for _it in 4:
		for j in _nv:
			var abre := OMBRO + (1.0 - OMBRO) * float(j) / (_nv - 1)
			var largo: float = _cfg[3] * abre / (_nh - 1) * u
			for i in _nh:
				var k := j * _nh + i
				if j > 0:
					_liga(k - _nh, k, alto)
				if i > 0:
					_liga(k - 1, k, largo)
		_corpo(u)
	_desenhar()


# segura o comprimento: o de cima puxa o de baixo (a fileira presa nao mexe)
func _liga(a: int, b: int, d: float) -> void:
	var dif := _p[b] - _p[a]
	var l := dif.length()
	if l < 0.0001 or (l <= d and l >= d * 0.8):
		return
	var alvo := clampf(l, d * 0.8, d)
	var corr := dif * (1.0 - alvo / l)
	if a < _nh:
		_p[b] -= corr
	else:
		_p[a] += corr * 0.5
		_p[b] -= corr * 0.5


func _corpo(u: float) -> void:
	if _osso_corpo < 0:
		return
	var chao := esqueleto.global_position.y + 0.03
	for e in CORPO:
		var c := _no_osso(_osso_corpo, e[0], e[1], e[2])
		var r: float = e[3] * u
		for k in range(_nh, _p.size()):
			var d := _p[k] - c
			if d.length() < r:
				_p[k] = c + d.normalized() * r
	for k in range(_nh, _p.size()):
		if _p[k].y < chao:
			_p[k].y = chao


func _desenhar() -> void:
	var im: ImmediateMesh = mesh
	im.clear_surfaces()
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLES, _mat)
	for j in _nv - 1:
		for i in _nh - 1:
			var a := j * _nh + i
			var q := [a, a + 1, a + _nh + 1, a, a + _nh + 1, a + _nh]
			var n := (_p[a + 1] - _p[a]).cross(_p[a + _nh] - _p[a]).normalized()
			for k in q:
				im.surface_set_normal(n)
				im.surface_set_uv(Vector2(float(k % _nh) / (_nh - 1), float(k / _nh) / (_nv - 1)))
				im.surface_add_vertex(_p[k])
	im.surface_end()
