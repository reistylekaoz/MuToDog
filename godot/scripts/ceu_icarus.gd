class_name CeuIcarus
extends Node3D
# O ceu de Icarus (ZzzObject.cpp: MoveHeavenThunder, MoveObjectOnEffect e MoveObjectSetting):
# - 1 vez em 50 quadros: clarao amarelado em volta do heroi (MODEL_CLOUD somado por 2 quadros)
#   e cada nuvem do mapa por perto tem 1 em 10 de piscar (cloudLight) com dois raios dentro
#   (BITMAP_JOINT_THUNDER subtipo 6);
# - 1 em 5 desses claroes: dois raios compridos 3 m abaixo do heroi, de um dos 4 jeitos do
#   cliente (BITMAP_JOINT_THUNDER + 1 subtipo 0: 50 pedacos de 80..100 indo pro alvo, refeitos
#   por 5 quadros, depois encolhem em 5);
# - 1 em 10 quadros: uma luz sobe do fundo, 10 m abaixo do heroi, deixando rastro
#   (CreateEffect BITMAP_LIGHT: vai a 70 graus, 400 quadros, rastro flare01 de 50 quadros).
# 1 tile = 1 m = 100 do MU; 25 quadros por segundo.

const Q := 25.0
const NUVEM_TIPOS := [0, 1, 2, 3, 4, 5]
const PERTO_NUVEM := 25.0

var mundo: Node3D
var _nuvens: Array[Vector3] = []   # posicao das nuvens do mapa no mundo do Godot
var _luzes: Array = []             # [emissor do rastro, velocidade, vida, apagando]
var _clarao := 0.0
var _env: Environment
var _fundo := Color()
var _tem_fundo := false
var _cor_clarao := Color()


func montar(m: Node3D, objetos: Array) -> void:
	mundo = m
	for o in objetos:
		if int(o.t) in NUVEM_TIPOS:
			_nuvens.append(m.mu.transform * Vector3(o.p[0], o.p[1], o.p[2]))
	var we := m.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if we:
		_env = we.environment
	print("TESTE ceu icarus · nuvens %d" % _nuvens.size())


func _heroi() -> Vector3:
	if mundo.seguir and is_instance_valid(mundo.seguir):
		return mundo.seguir.global_position
	var a: Vector2 = mundo.alvo + Vector2(0.5, 0.5)
	return Vector3(a.x, mundo.altura_em(a.x, a.y) / 100.0, -a.y)


func _chance(n: float, dt: float) -> bool:
	# rand() % n == 0 a cada quadro do cliente, em qualquer quadro por segundo
	return randf() < dt * Q / n


func _process(dt: float) -> void:
	if mundo == null:
		return
	if _env and not _tem_fundo:
		_fundo = _env.background_color
		_tem_fundo = true
	var h := _heroi()
	if _chance(50.0, dt):
		_trovao(h)
	if _chance(10.0, dt):
		_luz_do_fundo(h)
	_mexer_luzes(dt)
	if _clarao > 0.0:
		_clarao -= dt
		if _env:
			_env.background_color = _fundo if _clarao <= 0.0 else _fundo + _cor_clarao


func _trovao(h: Vector3) -> void:
	# Luminosity = (4..7) * 0,05; Light = (0,3 0,3 0,081) * Luminosity: o MODEL_CLOUD somado
	# por 2 quadros deixa o ceu amarelado; aqui o fundo clareia na mesma cor (x 2: e o ceu todo)
	var l := randf_range(4, 8) * 0.05
	_cor_clarao = Color(l * 0.3, l * 0.3, l * 0.081) * 2.0
	_clarao = 2.0 / Q
	var e := EfeitoMU.criar(self)
	for n in _nuvens:
		if Vector2(n.x - h.x, n.z - h.z).length() < PERTO_NUVEM and randf() < 0.1:
			_raio_na_nuvem(e, n)
	if randf() < 0.2:
		_raios_compridos(e, h)


# CreateSprite BITMAP_CLOUD + 1 (cloudLight, escala 0,5, cor 0..0,18) e dois JOINT_THUNDER 6:
# luz cinza 0,1..0,77, 6 a 25 quadros, largura 10..30
func _raio_na_nuvem(e: EfeitoMU, n: Vector3) -> void:
	var c := Color(randf() * 0.18, randf() * 0.18, randf() * 0.18)
	e.sprite("cloudlight", n, 1.28, c, 3.0 / Q, {giro = randf() * TAU, some = 0.0})
	for i in 2:
		var l := randf_range(0.1, 0.77)
		var fim := n + Vector3(randf_range(-1, 1), randf_range(-0.8, 0.2), randf_range(-1, 1)).normalized() * randf_range(1.5, 4.0)
		e.fita("jointthunder01", n, fim, randf_range(0.1, 0.3), Color(l, l, l), randf_range(6, 26) / Q, {raio = 0.35, pedacos = 10, some = 0.3})


# os 4 jeitos do MoveHeavenThunder: deslocamento do centro (girado -45 graus) e meia-reta
# (girada pelo angulo do caso); os dois pontos ficam 300 abaixo do heroi
const JEITOS := [
	[Vector2(-400, -1000), 1, 240.0, Vector2(-200, -1000)],
	[Vector2(-300, -400), -1, 210.0, Vector2(-500, -1000)],
	[Vector2(-200, -400), 1, 235.0, Vector2(-1000, -1500)],
	[Vector2(-200, 400), 1, 200.0, Vector2(-600, -1200)],
]


func _raios_compridos(e: EfeitoMU, h: Vector3) -> void:
	var j: Array = JEITOS[randi() % 4]
	var centro := h + _do_mu((j[0] as Vector2).rotated(deg_to_rad(-45.0))) * float(j[1])
	var meia := _do_mu((j[3] as Vector2).rotated(deg_to_rad(j[2])))
	var a := centro + meia + Vector3(0, -3.0, 0)
	var b := centro - meia + Vector3(0, -3.0, 0)
	for i in 2:
		_raio_comprido(e, a, b, randf_range(40, 50) / 100.0)


func _do_mu(v: Vector2) -> Vector3:
	return Vector3(v.x, 0, -v.y) / 100.0


# JOINT_THUNDER + 1 subtipo 0: 20 quadros; nos 5 primeiros o caminho e refeito (50 pedacos de
# 0,8..1 m, cada um virando pro alvo com tremida de +-14 graus); depois apaga do fim pro comeco
# a 10 pedacos por quadro
func _raio_comprido(e: EfeitoMU, a: Vector3, b: Vector3, largura: float) -> void:
	var estado := {pts = [] as Array[Vector3], t = 0.0}
	var passo := randf_range(0.8, 1.0)
	var gerar := func() -> void:
		var pts: Array[Vector3] = [a]
		var p := a
		var alvo := b + Vector3(randf_range(-1, 1), 0, randf_range(-0.5, 0.5))
		var dir := (alvo - a).normalized()
		for i in 50:
			var quer := (alvo - p)
			if quer.length() < passo:
				break
			dir = dir.slerp(quer.normalized(), 0.35)
			var tremida := Basis(Vector3.UP, deg_to_rad(randf_range(-15, 15))) * Basis(Vector3.RIGHT, deg_to_rad(randf_range(-15, 15)))
			p += (tremida * dir) * passo
			pts.append(p)
		pts.append(alvo)
		estado.pts = pts
	gerar.call()
	var pontos := func() -> Array:
		var pts: Array = estado.pts
		var k: float = estado.t * Q
		if k < 5.0:
			return pts
		var resto := int(maxf(0.0, pts.size() - (k - 5.0) * 10.12))
		return pts.slice(0, resto)
	var peca := e.fita("jointthunder01", pontos, null, largura, Color(1, 1, 1), 20.0 / Q, {some = 0.0})
	peca.anda = func(pc: Dictionary, _k: float) -> void:
		estado.t = pc.t
		if pc.t * Q < 5.0:
			gerar.call()


# a luz que sobe: velocidade (4,5..7) a 70 graus de inclinacao, rumo 30 graus, Direction[2]
# perde 0,01 por quadro, anda em quadro sim quadro nao; rastro BITMAP_LIGHT 1 a cada passo
# (escala 3 encolhendo 0,98 por quadro, luz 0,3 x escala)
func _luz_do_fundo(h: Vector3) -> void:
	if _luzes.size() >= 48:
		return
	var p := h + Vector3(randf_range(-25, 25), -10.0, randf_range(-25, 25))
	var vel := randf_range(9, 14) * 0.5
	var rumo := deg_to_rad(30.0)
	var inc := deg_to_rad(70.0)
	var d := Vector3(vel * cos(inc) * sin(rumo), vel * sin(inc), -vel * cos(inc) * cos(rumo)) / 100.0 * Q * 0.5
	var c := CPUParticles3D.new()
	c.amount = 25
	c.lifetime = 2.0
	c.local_coords = false
	c.emission_shape = CPUParticles3D.EMISSION_SHAPE_POINT
	c.initial_velocity_min = 0.0
	c.initial_velocity_max = 0.0
	c.gravity = Vector3.ZERO
	c.scale_amount_min = 3.0
	c.scale_amount_max = 3.0
	c.scale_amount_curve = Ambiente._curva(1.0, pow(0.98, 50.0))
	c.color_ramp = Ambiente._rampa([[0.0, Color(0.3, 0.3, 0.3)], [1.0, Color(0.3, 0.3, 0.3) * pow(0.98, 50.0)]])
	c.mesh = Ambiente._quad_somado(EfeitoMU.textura("flare01"), 0.64)
	add_child(c)
	c.global_position = p
	_luzes.append([c, d, 400.0 / Q, 0.0])


func _mexer_luzes(dt: float) -> void:
	for i in range(_luzes.size() - 1, -1, -1):
		var l: Array = _luzes[i]
		var c: CPUParticles3D = l[0]
		if l[3] > 0.0:
			# ja parou: espera o rastro apagar
			l[3] -= dt
			if l[3] <= 0.0:
				c.queue_free()
				_luzes.remove_at(i)
			continue
		l[2] -= dt
		var d: Vector3 = l[1]
		d.y -= 0.01 / 100.0 * Q * Q * 0.5 * 0.5 * dt
		l[1] = d
		c.global_position += d * dt
		if l[2] <= 0.0 or d.y < -2.0 / 100.0 * Q * 0.5:
			c.emitting = false
			l[3] = c.lifetime
