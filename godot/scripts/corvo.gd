class_name Corvo
extends Node3D
# Dark Raven (CSPetDarkSpirit do cliente): o corvo do Dark Lord, modelo Skill/DarkSpirit.bmd na escala 0,7.
# Voa em volta do dono a 2,5 m de altura (3,5 com o Dark Horse), virando pra ele quando passa de 1,5 m e
# trocando de velocidade de vez em quando; na zona segura pousa no ombro (osso 37, girado 120 graus).
# Ataque do C1 A8: tipo 0 mergulha no alvo e foge pra cima (PET_ATTACK / PET_ESCAPE), tipo 1 vira pro alvo,
# acende os ossos e solta a luz (PET_ATTACK_MAGIC). As contas do original sao por quadro a 25 qps em
# unidades do MU (100 = 1 tile = 1 m aqui); f = dt * 25 faz o mesmo em qualquer taxa de quadros.

enum { VOA, VOANDO, PARADO, POUSANDO, ATAQUE, FUGA, MAGIA }

const ESCALA := 0.7
const RITMO := 0.4          # PlayAnimation do corvo: 0,4
const RAIO_VOO := 1.5       # FlyRange 150
const ALTURA := 2.5         # CharacterHeight 250 (350 com o Dark Horse)
const ALTURA_CAVALO := 3.5
const ACOES := {VOA: "voa", VOANDO: "voando", PARADO: "parado", POUSANDO: "voando", ATAQUE: "ataque", FUGA: "ataque", MAGIA: "voa"}

var dono: Entidade
var mundo: Node3D
var boneco: Boneco
var estado := VOANDO
var alvo: Entidade          # quem o ataque mira
var comando := 0            # 0 normal, 1 aleatorio, 2 com o dono, 3 alvo (so mostra; quem ataca e o servidor)
var nivel := 1              # nivel do corvo (WeaponLevel): o brilho do modelo
var _giro := 0.0            # Angle[2] em graus (0 = de frente pra -Z)
var _incl := 0.0            # Angle[0] em graus (negativo sobe)
var _dir := Vector3.ZERO    # Direction: [1] = pra frente (negativo anda), [2] = pra cima, em unidades por quadro
var _vel := 0.0             # Velocity (unidades por quadro)
var _grav := 0.0
var _vida := 0.0            # LifeTime: quadros longe do dono (passou de 90, volta pra cima dele)
var _ataque_t := 0.0        # AttackTime (quadros desde o ataque)
var _magia_luz := false
var _faiscas: CPUParticles3D
var _brilho: CPUParticles3D
var _som: Callable          # nome -> toca o som (o jogo passa Som.tocar)


static func novo(d: Entidade, m: Node3D, som: Callable = Callable()) -> Corvo:
	var b := Boneco.novo("corvo", ESCALA)
	if b == null:
		return null
	var c := Corvo.new()
	c.name = "corvo_%d" % d.id
	c.dono = d
	c.mundo = m
	c.boneco = b
	c._som = som
	c.add_child(b)
	for a in ["voa", "voando", "parado", "ataque"]:
		b.ritmo[a] = RITMO
	m.add_child(c)
	# nasce em cima do dono, 3 m acima (Position[2] += 300)
	c.global_position = d.global_position + Vector3(0, 3.0, 0)
	c._faiscas = c._particulas(Color(0.3, 0.4, 0.7), 0.4, 14)
	c._brilho = c._particulas(Color(1.0, 0.6, 0.4), 0.3, 40)
	c._brilho.emitting = false
	c._acao()
	return c


# BITMAP_SPARK + 1 (voando, azul) e BITMAP_LIGHT nos ossos (antes da luz, laranja)
func _particulas(cor: Color, vida: float, n: int) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = n
	p.lifetime = vida
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.35
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = 0.0
	p.initial_velocity_max = 0.2
	p.gravity = Vector3.ZERO
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.0
	var q := QuadMesh.new()
	q.size = Vector2(0.12, 0.12)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	mat.albedo_texture = EfeitoMU.textura("shiny02")
	q.material = mat
	p.mesh = q
	var g := Gradient.new()
	g.set_color(0, cor)
	g.set_color(1, Color(0, 0, 0))
	p.color_ramp = g
	p.position = Vector3(0, 0.25, 0)
	add_child(p)
	return p


func _acao() -> void:
	var a: String = ACOES[estado]
	if boneco.acao != a:
		boneco.tocar(a, a)


func _altura_voo() -> float:
	return ALTURA_CAVALO if dono.boneco and dono.boneco.vestido().get(8, "") == "13,4" else ALTURA


func _frente() -> Vector3:
	var r := deg_to_rad(_giro)
	var p := deg_to_rad(-_incl)
	return Vector3(-sin(r) * cos(p), sin(p), -cos(r) * cos(p))


# giro do ponto a pro ponto b, no mesmo jeito do _giro (CreateAngle2D)
static func _giro_para(a: Vector3, b: Vector3) -> float:
	var d := b - a
	return rad_to_deg(atan2(-d.x, -d.z))


# TurnAngle2: vira no maximo "passo" graus pro lado mais curto
static func _virar(de: float, para: float, passo: float) -> float:
	var d := wrapf(para - de, -180.0, 180.0)
	return de + clampf(d, -passo, passo)


# MoveHumming: vira o giro e a inclinacao pro alvo (passo = a velocidade, em graus) e diz a distancia
func _mirar(p: Vector3, passo: float) -> float:
	var d := p - global_position
	_giro = _virar(_giro, _giro_para(global_position, p), passo)
	var plano := Vector2(d.x, d.z).length()
	var incl := -rad_to_deg(atan2(d.y, plano))
	_incl = _virar(_incl, incl, passo)
	return d.length()


func _osso_dono(n: int) -> Vector3:
	var b := dono.boneco
	if b == null or b.esqueleto == null:
		return dono.global_position + Vector3(0, dono.altura() * 0.85, 0)
	var i := b.esqueleto.find_bone("osso%d" % n)
	if i < 0:
		return dono.global_position + Vector3(0, dono.altura() * 0.85, 0)
	return b.esqueleto.global_transform * b.esqueleto.get_bone_global_pose(i).origin


# A8: o corvo ataca (tipo 0 mergulho, 1 luz)
func atacar(e: Entidade, tipo: int) -> void:
	if e == null or not is_instance_valid(e) or dono.buffs.has(61):   # atordoado (eDeBuff_Stun) nao ataca
		return
	alvo = e
	_ataque_t = 0.0
	_vida = 0.0
	if tipo == 0:
		estado = ATAQUE
		_vel = randf_range(20.0, 29.0)
		_grav = 0.5
		_tocar_som("corvo_ataque")
		# BITMAP_LIGHT em volta e o MODEL_DARKLORD_SKILL: um clarao no corvo
		var ef := EfeitoMU.criar(mundo)
		ef.sprite("flare01", global_position, 1.2, Color(1, 0.8, 0.6), 0.3, {"some": 0.3})
	else:
		estado = MAGIA
		_tocar_som("corvo_magia")
	_acao()


func _tocar_som(n: String) -> void:
	if _som.is_valid():
		_som.call(n)


func _process(dt: float) -> void:
	if not is_instance_valid(dono) or dono.boneco == null:
		return
	var f := dt * 25.0
	visible = dono.visible
	if dono.buffs.has(61):   # atordoado: o corvo para no ar
		return
	var segura: bool = mundo.has_method("zona_segura") and mundo.zona_segura(dono.tile.x, dono.tile.y)
	if alvo != null and (not is_instance_valid(alvo) or alvo.morto) and estado in [ATAQUE, FUGA, MAGIA]:
		alvo = null
		estado = VOANDO
	if segura:
		if estado not in [PARADO, POUSANDO]:
			estado = POUSANDO if global_position.distance_to(dono.global_position) > 0.5 or estado in [VOA, VOANDO] else PARADO
			_vel = 3.0
	elif estado in [PARADO, POUSANDO]:
		estado = VOANDO
	var de := global_position
	match estado:
		VOA, VOANDO:
			_voar(f)
		ATAQUE:
			global_position += _frente() * _vel * 0.01 * f
			var d := _mirar(alvo.global_position + Vector3(0, 0.5 + alvo.altura() * 0.4, 0), _vel)
			if d < 0.2 or _vida > 20.0:
				estado = FUGA
				_incl = -45.0
			_vel += _grav * f
			_grav += 0.2 * f
			_vida += f
		FUGA:
			global_position += _frente() * _vel * 0.01 * f
			_incl = _virar(_incl, -45.0, 3.0 * f)
			var o := dono.global_position - global_position
			if Vector2(o.x, o.z).length() >= RAIO_VOO + 1.0:
				estado = VOANDO
			_vel = maxf(_vel - 1.0 * f, 3.0)
		MAGIA:
			_giro = _virar(_giro, _giro_para(global_position, alvo.global_position), 40.0 * f)
			_brilho.emitting = _ataque_t < 15.0
			if _ataque_t >= 15.0:
				# RenderMeshEffect: a luz sai do corpo do corvo e vai no alvo
				var ef := EfeitoMU.criar(mundo)
				ef.fita("flare01", global_position + Vector3(0, 0.2, 0), alvo.global_position + Vector3(0, alvo.altura() * 0.5, 0),
					0.35, Color(1, 0.6, 0.4), 0.35, {"some": 0.35})
				ef.sprite("flare01", alvo.global_position + Vector3(0, alvo.altura() * 0.5, 0), 1.0, Color(1, 0.6, 0.4), 0.4, {"some": 0.4})
				_brilho.emitting = false
				_ataque_t = 0.0
				estado = VOANDO
		POUSANDO:
			if _vel != 0.0:
				global_position += _frente() * _vel * 0.01 * f
			var d := _mirar(_osso_dono(42), _vel)
			_vel += f
			if d < 0.5:
				estado = PARADO
		PARADO:
			global_position = _osso_dono(37) + Vector3(0, 0.1, 0)
			_giro = rad_to_deg(dono.rotation.y) - 120.0
			_incl = 0.0
	if estado in [ATAQUE, FUGA, MAGIA]:
		_ataque_t = minf(_ataque_t + f, 15.0)
	# grito de vez em quando (1 em 100 e 1 em 60 por quadro)
	if randf() < f / 6000.0:
		_tocar_som("corvo_grito")
	# longe demais (abaixo do dono ou a mais de 6,4 m): depois de 90 quadros volta pra cima dele
	var o := dono.global_position - global_position
	if global_position.y < dono.global_position.y - 2.0 or Vector2(o.x, o.z).length() > 6.4:
		_vida += f
	if _vida > 90.0:
		_vida = 0.0
		global_position = dono.global_position + Vector3(0, 2.5, 0)
	rotation = Vector3(deg_to_rad(-_incl), deg_to_rad(_giro), 0)
	_faiscas.emitting = estado in [VOA, VOANDO] and not dono.buffs.has(18)   # invisivel (eBuff_Cloaking): sem faisca
	_acao()
	if not de.is_finite():
		global_position = dono.global_position + Vector3(0, 2.5, 0)


# PET_FLY e PET_FLYING: vira pro dono quando passa do raio, sobe ou desce ate a altura e troca a velocidade
# de vez em quando (1 em 28; 1 em 10 se esta baixo, 1 em 20 se esta alto)
func _voar(f: float) -> void:
	var t := dono.global_position
	var o := t - global_position
	var longe := Vector2(o.x, o.z).length() >= RAIO_VOO
	if longe:
		_giro = _virar(_giro, _giro_para(global_position, t), randf_range(5.0, 19.0) * f)
	var chance := 28.0
	var h := t.y + _altura_voo()
	if global_position.y < h:
		chance = 10.0
		_incl = maxf(_incl - 2.0 * f, -15.0)
	elif global_position.y > h + 1.0:
		chance = 20.0
		_incl = minf(_incl + 2.0 * f, 15.0)
	if randf() < f / chance:
		var v := 0.0
		if longe:
			v = -(randf_range(0, 63) + 128.0) * 0.1
		else:
			v = -(randf_range(0, 7) + 32.0) * 0.1
			_giro += randf_range(0, 59) * f
		v = (v + _dir.y * f) / 2.0
		_dir = Vector3(0, v, randf_range(-32, 31) * 0.1)
	# anda: Direction girado pelo corpo (y negativo = pra frente) e o [2] pra cima
	global_position += (_frente() * -_dir.y + Vector3(0, _dir.z, 0)) * 0.01 * f
	estado = VOANDO if _dir.y < -12.0 else VOA
