class_name EfeitoMontaria
extends Node3D
# Efeitos das montarias no jeito do cliente (RenderObject em ZzzObject.cpp e MoveMount em
# GOBoid.cpp), num no preso na montaria (Boneco) e com as pecas soltas no mundo (EfeitoMU):
# - Uniria e Dinorant: poeira atras quando anda (CreateParticle BITMAP_SMOKE + 1, 1 em 2 ticks);
# - Dark Horse: malhas 12 a 15 cromadas e douradas (RENDER_CHROME | RENDER_BRIGHT,
#   luz 1, 0.8, 0.3) e poeira quando corre (1 em 2 ticks);
# - Fenrir: malha 1 cromada (a 0 no dourado), olhos e boca acesos (BITMAP_LIGHT nos ossos
#   11 e 13), 2 raios por tick no corpo (MODEL_FENRIR_THUNDER) com luz na cor do Fenrir,
#   pegadas de raio no chao (MODEL_FENRIR_FOOT_THUNDER) e poeira (1 em 3 ticks).
# Na zona segura a montaria some (Boneco.visible) e os efeitos param junto.

const T := 0.04   # um tick do cliente (25 por segundo)
const BRANCO := Color(1, 1, 1)
# cor do Fenrir -> [luz do raio, subtipo da pegada (qual canal apaga)]
const FENRIR := {
	"red": [Color(0.8, 0, 0), 1], "blue": [Color(0.1, 0.1, 0.8), 2],
	"gold": [Color(0.8, 0.8, 0.1), 4], "black": [Color(1, 1, 0.2), 3],
}
const ICARUS := 10
const DEVIAS := 2
const KALIMA := [24, 25, 26, 27, 28, 29, 36]   # InHellas: sem poeira
static var mapa := -1   # o mapa aberto (jogo._abrir_mapa)

var b: Boneco
var tipo := ""      # "monta" (Uniria e Dinorant), "cavalo" ou "fenrir"
var cor := "red"
var e: EfeitoMU
var _acc := 0.0
var _luzes: Array[MeshInstance3D] = []   # olhos (2) e boca (2) do Fenrir, refeitos todo quadro
var _ossos := {}
var _brilho: Array[ShaderMaterial] = []   # 2a passada cromada do Fenrir, acesa so no golpe dele


# poe os efeitos na montaria recem-criada (Boneco._vestir, slot 8)
static func ligar(montaria: Boneco, jeito: String, cor_fenrir: String) -> EfeitoMontaria:
	var f := EfeitoMontaria.new()
	f.b = montaria
	f.tipo = jeito
	f.cor = cor_fenrir if FENRIR.has(cor_fenrir) else "red"
	f.top_level = true
	montaria.add_child(f)
	if jeito == "cavalo":
		montaria.camada([12, 13, 14, 15], "chrome01", "chrome", Color(1, 0.8, 0.3), [1, 0, 0], Vector2.ZERO)
	elif jeito == "fenrir":
		montaria.camada(0 if f.cor == "gold" else 1, "chrome01", "chrome", BRANCO, [1, 0, 0], Vector2.ZERO)
		if f.cor != "gold":
			f._brilho = montaria.camada(1, "chrome01", "chrome", Color(0, 0, 0), [1, 0, 0], Vector2.ZERO)
		for i in 4:
			var q := MeshInstance3D.new()
			q.mesh = QuadMesh.new()
			q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			q.material_override = EfeitoMU._material("flare01", BRANCO, 0)
			f.add_child(q)
			f._luzes.append(q)
	return f


func _ready() -> void:
	# deferido: a montaria pode nascer enquanto a cena ainda monta os filhos
	e = EfeitoMU.new()
	get_tree().current_scene.add_child.call_deferred(e)
	e.tarefa(3600.0, 1e9, func(_e, _i): pass)   # segura o EfeitoMU vivo enquanto a montaria existe


func _exit_tree() -> void:
	if is_instance_valid(e):
		e.queue_free()


func _process(d: float) -> void:
	var ligado := is_instance_valid(b) and b.is_visible_in_tree() and e.is_inside_tree()
	for q in _luzes:
		q.visible = ligado
	if not ligado:
		_acc = 0.0
		return
	if tipo == "fenrir":
		_olhos()
		var golpe := _no_golpe()
		for m in _brilho:
			m.set_shader_parameter("cor", BRANCO if golpe else Color(0, 0, 0))
	_acc = minf(_acc + d, T * 5)
	while _acc >= T:
		_acc -= T
		_tick()


# posicao no mundo de um ponto (em unidades do MU) preso no osso: TransformPosition
func _osso(i: int, desl := Vector3.ZERO) -> Vector3:
	if b.esqueleto == null:
		return b.global_position
	if not _ossos.has(i):
		_ossos[i] = b.esqueleto.find_bone("osso%d" % i)
	var k: int = _ossos[i]
	if k < 0:
		return b.global_position + Vector3.UP * 0.8
	return b.esqueleto.to_global(b.esqueleto.get_bone_global_pose(k) * desl)


func _quadro() -> float:
	return b.anim.current_animation_position if b.anim and b.anim.is_playing() else 0.0


# olhos (osso 11, 50 2 +-11, desenhados 2 vezes) e boca (osso 13, 40 15 0, tamanhos 1.5 e 1.0)
func _olhos() -> void:
	var lum := sin(Time.get_ticks_msec() * 0.002) * 0.2
	var olho := Color(0.9 + lum, 0.2 + lum * 0.5, 0.1 + lum * 0.5) * 2.0
	var pos := [_osso(11, Vector3(50, 2, 11)), _osso(11, Vector3(50, 2, -11)), _osso(13, Vector3(40, 15, 0)), _osso(13, Vector3(40, 15, 0))]
	var tam := [0.5 + lum * 0.1, 0.5 + lum * 0.1, 1.5, 1.0]
	for i in 4:
		var q := _luzes[i]
		q.global_position = pos[i]
		q.scale = Vector3.ONE * 0.64 * tam[i]
		(q.material_override as ShaderMaterial).set_shader_parameter("cor", olho if i < 2 else Color(1, 0.3, 0.2))


func _tick() -> void:
	var andando := b.acao in ["anda", "corre"]
	match tipo:
		"monta":
			if andando and randi() % 2 == 0 and mapa != ICARUS:
				_poeira()
		"cavalo":
			if b.acao == "anda" and randi() % 2 == 0 and mapa != ICARUS and mapa not in KALIMA:
				_poeira()
		"fenrir":
			var c: Array = FENRIR[cor]
			_raio(c[0])
			_raio(c[0])
			_pegadas(c[1])
			if _no_golpe():
				_faisca()
			if andando and randi() % 3 == 0 and mapa != ICARUS and mapa not in KALIMA:
				_poeira()


# CreateParticle em volta dos pes (+-32, +-32, +-16): BITMAP_SMOKE em Devias, BITMAP_SMOKE + 1 no resto
func _poeira() -> void:
	var p := b.global_position + Vector3(randf_range(-0.32, 0.32), randf_range(-0.16, 0.16), randf_range(-0.32, 0.32))
	if mapa == DEVIAS:
		# smoke01 somado: 16 ticks, 0.48 a 0.8 crescendo 0.05 por tick, sobe acelerando (Gravity += 0.2)
		var s := randf_range(0.48, 0.8)
		e.sprite("smoke01", p, 0.64 * s, BRANCO, 16 * T, {tam1 = 0.64 * (s + 0.8), acel = Vector3(0, 1.25, 0), giro = randf() * TAU, some = 0.5})
		return
	# smoke02 (alfa): 32 ticks, 0.32 a 0.64 crescendo 0.08 por tick, sempre no chao (centro a meia altura),
	# luz e alfa caindo de 1 a 0 pela vida
	var s0 := randf_range(0.32, 0.64)
	var chao := b.global_position.y
	e.sprite("smoke02_t", p, 0.64 * s0, BRANCO, 32 * T, {alfa = true, tam1 = 0.64 * (s0 + 0.08 * 32), giro = randf() * TAU, some = 1.0,
		anda = func(pc: Dictionary, k: float) -> void:
			(pc.no as Node3D).global_position.y = chao + lerpf(pc.tam0, pc.tam1, k) * 0.5})


# MODEL_FENRIR_THUNDER subtipo 0: lightning_type01 girado ao acaso num osso do Fenrir (ou
# solto em volta do corpo), acende em 1 tick e apaga em ~3; luz BITMAP_LIGHT tamanho 2 na
# cor do Fenrir menos 0.3
func _raio(luz: Color) -> void:
	var r := randi() % 30
	var tam := 0.3 + (randi() % 100) * 0.002
	var p: Vector3
	if r >= 1 and r <= 2:
		p = _osso(10)
	elif r == 3:
		tam -= 0.2
		p = _osso(14)
	elif r >= 4 and r <= 5:
		p = _osso(2)
	elif r >= 6 and r <= 7:
		tam -= 0.2
		p = _osso(50 if randi() % 2 == 0 else 51)
	elif r == 8:
		tam -= 0.2
		p = _osso(53)
	elif r >= 9 and r <= 10:
		return
	else:
		tam += 0.1
		p = b.global_position + Vector3(randf_range(-1.2, 1.2), 1.1, randf_range(-0.05, 0.05))
	var giro := Basis.from_euler(Vector3(randf() * TAU, randf() * TAU, randf() * TAU))
	e.modelo("lightning_type01", p, tam, BRANCO, 5 * T, {base = giro, entra = 0.2, some = 0.75})
	var c := Color(maxf(luz.r - 0.3, 0), maxf(luz.g - 0.3, 0), maxf(luz.b - 0.3, 0))
	e.sprite("flare01", p, 0.64 * 2.0, c, T, {some = 0.0})


# MODEL_FENRIR_FOOT_THUNDER nas patas (ossos 22, 28, 36, 44): andando nos quadros 0 a 1.5,
# correndo 22 e 28 em 1 a 1.4 e 36 e 44 em 4.8 a 5.2. Marca no chao de 0.6 tile, troca de
# quadro (eff_lightinga01 a 05) a cada 200 ms; a luz sai branca e perde 0.05 por tick nos
# canais do subtipo, e some com 20 ticks.
func _pegadas(sub: int) -> void:
	var f := _quadro()
	var patas := []
	if b.acao == "anda" and f >= 0.0 and f <= 1.5:
		patas = [22, 28, 36, 44]
	elif b.acao == "corre" and f > 1.0 and f <= 1.4:
		patas = [22, 28]
	elif b.acao == "corre" and f > 4.8 and f <= 5.2:
		patas = [36, 44]
	for o in patas:
		var p := _osso(o)
		p.y = b.global_position.y
		e.chao("eff_lightinga01", p, 0.6, BRANCO, 20 * T, {some = 0.0, anda = _pegada.bind(sub)})


static func _pegada(pc: Dictionary, k: float, sub: int) -> void:
	var tick := k * 20.0
	var q := mini(int(pc.t / 0.2), 4)
	if pc.get("q", 0) != q:
		pc.q = q
		pc.mat.set_shader_parameter("tex", EfeitoMU.textura("eff_lightinga0%d" % (q + 1)))
	var m := maxf(1.0 - 0.05 * tick, 0.0)
	var c := Color(1, 1, 1)
	match sub:
		1: c = Color(1, m, m)
		2: c = Color(m, m, 1)
		3: c = Color(m, 1, m)
		4: c = Color(1, 1, m)
	pc.cor = c   # o EfeitoMU poe pc.cor no material logo depois


# FENRIR_ATTACK_SKILL: o cavaleiro no golpe do Fenrir (Plasma Storm)
func _no_golpe() -> bool:
	var dono := b.get_parent() as Boneco
	return dono != null and dono.pedida == "fenrir_skill" and dono.anim != null and dono.anim.is_playing()


# BITMAP_SPARK + 1 subtipo 15 no queixo (osso 14, -5..0 0 -10..10), vermelha, 0.7 + lum * 0.05:
# 1 em 3 vive 35 ticks caindo 2.5 a 4.5 por tick; as outras so 2 ticks. A luz cai 1/1.05 por tick.
func _faisca() -> void:
	var lum := sin(Time.get_ticks_msec() * 0.002) * 0.2
	var p := _osso(14, Vector3(randf_range(-5, 0), 0, randf_range(-10, 10)))
	var longa := randi() % 3 == 0
	var vida := (35 if longa else 2) * T
	var vel := Vector3(0, -randf_range(2.5, 4.5) / 100.0 / T, 0) if longa else Vector3.ZERO
	e.sprite("spark03", p, 0.64 * (0.7 + lum * 0.05), Color(1, 0, 0), vida, {vel = vel, some = 0.0,
		anda = func(pc: Dictionary, k: float) -> void:
			pc.cor = Color(1, 0, 0) * pow(1.0 / 1.05, k * vida / T)})
