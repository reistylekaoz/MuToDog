class_name Capa
extends MeshInstance3D
# Capa de pano (CPhysicsCloth do cliente S6, PhysicsManager.cpp): uma grade de pontos presa
# pela fileira de cima no osso 19 (costas). Cada ponto tem velocidade propria (gravidade,
# vento e mola quando estica); depois as esferas do corpo (osso 17), as ligacoes frouxas e as
# estritas corrigem so a posicao, sem virar velocidade (senao a capa sai voando). A fileira
# de cima tem 60% da largura (PCT_SHORT_SHOULDER) e abre ate a barra; PCT_CURVED curva pra tras.
# Cape of Lord (Dark Lord) e Cape of Fighter / Overrule (Rage Fighter).

# esferas do corpo (AddCollisionSphere): x, y, z, raio, osso
const CORPO_DL := [[-10.0, -10.0, -10.0, 25.0, 17], [10.0, -10.0, -10.0, 25.0, 17], [-10.0, -10.0, 20.0, 27.0, 17], [10.0, -10.0, 20.0, 27.0, 17]]
const CORPO_RF := [[-10.0, -10.0, -10.0, 35.0, 17], [10.0, -10.0, -10.0, 35.0, 17], [-10.0, -10.0, 20.0, 37.0, 17], [10.0, -10.0, 20.0, 37.0, 17]]
# panos de cada item (CPhysicsCloth::Create em ZzzCharacter.cpp): textura, colunas, linhas, largura,
# altura, x, y, z (no osso 19), pesada (PCT_HEAVY), curva (PCT_CURVED + PCT_SHORT_SHOULDER), esferas
const TIPOS := {
	"13,30": [["capa_darklordrobe", 10, 10, 180.0, 180.0, 0.0, 8.0, 10.0, false, true, CORPO_DL]],
	"12,130": [["capa_darklordrobe", 10, 10, 100.0, 100.0, 0.0, 8.0, 10.0, false, true, CORPO_DL]],
	# Cape of Emperor: capa vermelha pesada e duas fitas (PCT_FLAT) dos lados
	"12,40": [["capa_dl_redwings02", 10, 10, 180.0, 180.0, 0.0, 8.0, 10.0, true, true, CORPO_DL],
		["capa_dl_redwings03", 2, 5, 12.0, 200.0, 30.0, 15.0, 10.0, false, false, [[0.0, -15.0, -20.0, 30.0, 2], [0.0, 0.0, 0.0, 35.0, 17]]],
		["capa_dl_redwings03", 2, 5, 12.0, 200.0, -30.0, 20.0, 10.0, false, false, [[0.0, -15.0, -20.0, 30.0, 2], [0.0, 0.0, 0.0, 35.0, 17]]]],
	"12,49": [["capa_nccape", 10, 10, 180.0, 170.0, 0.0, 15.0, 5.0, true, true, CORPO_RF]],
	"12,135": [["capa_nccape", 10, 10, 150.0, 130.0, 0.0, 15.0, 5.0, true, true, CORPO_RF]],
	# Cape of Overrule: manto e duas fitas
	"12,50": [["capa_monke_manto", 10, 10, 180.0, 170.0, 0.0, 15.0, 5.0, true, true, CORPO_RF],
		["capa_monk_manto01", 2, 5, 12.0, 180.0, 25.0, 15.0, 2.0, false, false, [[0.0, -15.0, -20.0, 35.0, 2], [0.0, 0.0, 0.0, 45.0, 17]]],
		["capa_monk_manto01", 2, 5, 12.0, 180.0, -25.0, 15.0, 2.0, false, false, [[0.0, -15.0, -20.0, 35.0, 2], [0.0, 0.0, 0.0, 50.0, 17]]]],
}
# itens que alem do pano desenham o modelo no osso 19 (RenderLinkObject com Link): giro e deslocamento
const GOLA := {"12,40": [0, 90, 0, -47, -7, 0], "12,50": [0, 90, 0, 10, -15, 0]}
const OMBRO := 0.6   # RATE_SHORT_SHOULDER

var esqueleto: Skeleton3D
var _cfg: Array
var _nh := 10
var _nv := 10
# tudo em unidades do MU (metro / _unidade()), como no cliente
var _p := PackedVector3Array()
var _v := PackedVector3Array()
var _f := PackedVector3Array()
var _um := PackedVector3Array()   # "one time move": correcao so de posicao
var _nm := PackedInt32Array()
# ligacoes: a, b, menor, maior, tipo (1 mola, 2 frouxa, 4 estrita)
var _lig: Array = []
var _osso := -1
var _esferas: Array = []
var _t := 0.0
var _sobra := 0.0
var _vento := 0.3
var _mat: StandardMaterial3D
var _pronta := false

const MOLA := 1
const FROUXA := 2
const ESTRITA := 4
const PASSO := 0.005        # Move2(0.005, 5) por quadro de 25 qps
const REAL := 0.008         # cada passo de 0.005 vale 0.008 s de jogo
const INV_MASSA := 400.0
const GRAVIDADE := 9.8 * 0.0025


static func nova(esq: Skeleton3D, item: String, pano := 0) -> Capa:
	if not TIPOS.has(item) or esq == null or pano >= TIPOS[item].size():
		return null
	var c := Capa.new()
	c.esqueleto = esq
	c._cfg = TIPOS[item][pano]
	c._nh = c._cfg[1]
	c._nv = c._cfg[2]
	c._osso = esq.find_bone("osso19")
	for e in c._cfg[10]:
		c._esferas.append([e, esq.find_bone("osso%d" % e[4])])
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


# fileira de cima, presa nas costas (em unidades do MU)
func _presos(u: float) -> PackedVector3Array:
	var r := PackedVector3Array()
	var larg: float = _cfg[3] * (OMBRO if _cfg[9] else 1.0)
	for i in _nh:
		var x: float = larg * float(i) / (_nh - 1) - 0.5 * larg + _cfg[5]
		r.append(_no_osso(_osso, x, _cfg[6] - _curva(i), _cfg[7]) / u)
	return r


# PCT_CURVED: as pontas caem 10 pra frente
func _curva(i: int) -> float:
	if not _cfg[9]:
		return 0.0
	var f := 2.0 * absf(float(i) / (_nh - 1) - 0.5)
	return 10.0 * f * f


func _unidade() -> float:
	return esqueleto.global_transform.basis.get_scale().x


# pra tras do personagem, no chao: o esqueleto esta em coordenadas do MU (z pra cima), e o
# vento do cliente sopra pra +y dele (sin/cos de 180 + angulo)
func _tras() -> Vector3:
	var y := esqueleto.global_transform.basis.y
	y.y = 0.0
	return y.normalized() if y.length() > 0.000001 else Vector3.BACK


# como o cliente monta: pendurada reta pra baixo atras do osso, abrindo ate a barra
func _montar(u: float) -> void:
	var n := _nh * _nv
	_p.resize(n)
	_v.resize(n)
	_f.resize(n)
	_um.resize(n)
	_nm.resize(n)
	var b := esqueleto.global_transform.basis
	var lado := b.x.normalized()
	var tras := _tras()
	var raiz := esqueleto.to_global(esqueleto.get_bone_global_pose(_osso).origin) / u
	var alto: float = _cfg[4] / (_nv - 1)
	for j in _nv:
		var larg: float = _cfg[3] * ((OMBRO + (1.0 - OMBRO) * float(j) / (_nv - 1)) if _cfg[9] else 1.0)
		for i in _nh:
			var x: float = larg * float(i) / (_nh - 1) - 0.5 * larg
			_p[j * _nh + i] = raiz + lado * x + tras * (20.0 - _curva(i)) + Vector3.DOWN * alto * j
			_v[j * _nh + i] = Vector3.ZERO
	var topo := _presos(u)
	for i in _nh:
		_p[i] = topo[i]
	# comprimentos tirados da forma inicial, como o SetLink
	_lig.clear()
	for j in _nv:
		for i in _nh:
			var k := j * _nh + i
			if j < _nv - 1:
				_ligar(k, k + _nh, MOLA | ESTRITA)
			if i < _nh - 1:
				_ligar(k, k + 1, MOLA | FROUXA)
				if j < _nv - 1:
					_ligar(k, k + 1 + _nh, FROUXA)
				if j > 1:
					_ligar(k, k + 1 - _nh, FROUXA)
	_pronta = true


func _ligar(a: int, b: int, tipo: int) -> void:
	var d := maxf(0.01, _p[a].distance_to(_p[b]))
	_lig.append([a, b, d * 0.8, d, tipo])


func _process(dt: float) -> void:
	if not is_instance_valid(esqueleto) or _osso < 0 or not esqueleto.is_visible_in_tree():
		visible = false
		return
	visible = true
	var u := _unidade()
	if not _pronta:
		_montar(u)
	_t += dt
	# vento do PhysicsManager: passeio ao acaso entre -0.2 e 1
	_vento = clampf(_vento + randf_range(-0.1, 0.1) * minf(1.0, dt * 25.0), -0.2, 1.0)
	_sobra += minf(dt, 0.1)
	var n := 0
	while _sobra >= REAL and n < 15:
		_sobra -= REAL
		n += 1
		if not _passo(u):
			_pronta = false
			_montar(u)
			break
	_sobra = minf(_sobra, REAL)
	_desenhar(u)


# um Move do CPhysicsCloth: forca, mola, anda; depois corpo, frouxas e estritas
func _passo(u: float) -> bool:
	var semente := (int(_t * 1000.0 / 400.0) * 101) % (_nh * _nv)
	var vento := _tras() * _vento
	var g: float = GRAVIDADE * (180.0 if _cfg[8] else 100.0)
	for k in _p.size():
		var chave := absi(semente % _nh - k % _nh) + absi(semente / _nh - k / _nh)
		var t := clampi(5 - chave, 0, 4)
		var r := 0.0 if t == 0 else float(t + 2)
		_f[k] = vento * r - _v[k] * 0.01 + Vector3.DOWN * g
	for l in _lig:
		if not (l[4] & MOLA):
			continue
		var a: int = l[0]
		var b: int = l[1]
		var dif := _p[a] - _p[b]
		var d := maxf(0.001, dif.length())
		if d > l[3] + 0.01:
			var fz: Vector3 = dif * ((d - l[3]) / d)
			_f[a] -= fz
			_f[b] += fz
	var topo := _presos(u)
	for i in _nh:
		_p[i] = topo[i]
		_v[i] = Vector3.ZERO
	for k in range(_nh, _p.size()):
		_v[k] += _f[k] * INV_MASSA * PASSO
		_p[k] += _v[k] * PASSO
	# esferas do corpo e ligacoes frouxas: media das correcoes, so na posicao
	for k in _p.size():
		_um[k] = Vector3.ZERO
		_nm[k] = 0
	for es in _esferas:
		if es[1] < 0:
			continue
		var e: Array = es[0]
		var c := _no_osso(es[1], e[0], e[1], e[2]) / u
		var raio: float = e[3]
		for k in range(_nh, _p.size()):
			var d := _p[k] - c
			var l := d.length()
			if l < 0.01:
				l = 0.01
				d = Vector3(l, 0, 0)
			if l < raio:
				_um[k] += d * ((raio - l) / l)
				_nm[k] += 1
	for l in _lig:
		if not (l[4] & FROUXA):
			continue
		var a: int = l[0]
		var b: int = l[1]
		var dif := _p[a] - _p[b]
		var d := maxf(0.001, dif.length())
		var m: Vector3 = dif * ((d - l[3]) * 0.5 / d)
		_um[a] -= m
		_um[b] += m
		_nm[a] += 1
		_nm[b] += 1
	for k in range(_nh, _p.size()):
		if _nm[k] > 0:
			_p[k] += _um[k] / float(_nm[k])
	for l in _lig:
		if not (l[4] & ESTRITA) or l[1] < _nh:
			continue
		var a: int = l[0]
		var b: int = l[1]
		var dif := _p[b] - _p[a]
		var d := maxf(0.001, dif.length())
		if d > l[3] * 20.0:
			return false
		if d > l[3]:
			_p[b] -= dif * ((d - l[3]) / d)
		elif d < l[2]:
			_p[b] -= dif * ((d - l[2]) / d)
	return true


func _desenhar(u: float) -> void:
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
				im.surface_add_vertex(_p[k] * u)
	im.surface_end()
