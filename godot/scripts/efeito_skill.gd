class_name EfeitoSkill
# Efeitos das skills no jeito do cliente S6 (MuMain: SkillCast.cpp, ZzzCharacter.cpp
# AttackStage, ZzzEffect.cpp, ZzzEffectJoint.cpp), com as texturas e modelos dele
# (dados/efeitos, conversor efeitos). As contas do cliente sao em ticks de 25 por
# segundo e 100 unidades por tile: T e um tick, v() passa unidades/tick pra tiles/s.
# Uso: EfeitoSkill.criar(mundo, numero, quem, alvo, area): quem e alvo sao Node3D
# (Entidade) ou Vector3 (ponto no chao).

const T := 0.04
const BRANCO := Color(1, 1, 1)
const MAGIA := [1, 2, 3, 4, 5, 7, 8, 9, 10, 11, 12, 13, 14, 16, 17, 38, 39, 45, 233]
const ESPADA := [19, 20, 21, 22, 23, 41, 42, 43, 47, 55, 56, 57]


static func v(por_tick: float) -> float:
	return por_tick / 100.0 / T


static func _pos(x) -> Vector3:
	if typeof(x) == TYPE_OBJECT:
		return (x as Node3D).global_position if is_instance_valid(x) else Vector3.ZERO
	return x


# Vector3, ou no que ainda existe
static func _vivo(x) -> bool:
	return typeof(x) != TYPE_OBJECT or is_instance_valid(x)


static func _peito(x) -> Vector3:
	var p := _pos(x)
	if typeof(x) == TYPE_OBJECT and is_instance_valid(x) and x is Entidade and (x as Entidade).boneco:
		return p + Vector3.UP * (x as Entidade).boneco.altura * 0.5
	return p + Vector3.UP * 0.9


static func _rnd(a: float, b: float) -> float:
	return randf_range(a, b)


static func criar(pai: Node3D, n: int, quem, alvo, area := false) -> void:
	if pai == null or quem == null or alvo == null:
		return
	n = JanelaMaster.base(n)
	var e := EfeitoMU.criar(pai)
	var de := _pos(quem)
	var para := _pos(alvo)
	var frente := Vector3(para.x - de.x, 0, para.z - de.z)
	if frente.length() < 0.05:
		frente = -(quem as Node3D).global_basis.z if quem is Node3D else Vector3.FORWARD
	frente = Vector3(frente.x, 0, frente.z).normalized()
	var b: Boneco = (quem as Entidade).boneco if quem is Entidade else null
	if n in ESPADA and b:
		_brilho_lamina(e, b, n)
	# magia sai no meio do gesto (AttackTime 15 do cliente; aqui o gesto e mais curto)
	if n in MAGIA:
		await e.get_tree().create_timer(0.3).timeout
		if not is_instance_valid(e):
			return
	match n:
		1: _veneno(e, alvo)
		2: _meteoro(e, para)
		3: _raio(e, quem, b, alvo)
		4: _bola_de_fogo(e, de, frente, alvo)
		5: _chama(e, para)
		7: _gelo(e, para)
		8: _tornado(e, de, frente)
		9: _espirito(e, quem)
		10: _fogo_do_inferno(e, quem)
		12: _aqua(e, de, frente)
		13: _cometa(e, para)
		14: _inferno(e, de)
		17: _bola_de_energia(e, de, alvo)
		38: _decadencia(e, para)
		39: _tempestade_de_gelo(e, para)
		41: _giro(e, quem, b)
		42: _furia(e, de, frente)
		43: _estocada(e, quem, b, frente, alvo)
		47: _empalar(e, de, b, frente)
		55: _corte_de_fogo(e, quem, b, frente)
		56: _corte_de_poder(e, de, frente)
		24: _flechas(e, de, frente, para, [0.0, 15.0, -15.0])
		46, 51: _flechas(e, de, frente, para, [0.0], func(): _gelo_flecha(e, para))
		52: _penetrar(e, de, frente, para)
		26: _circulo_buff(e, alvo, Color(0.4, 0.6, 1.0), false)
		27: _circulo_buff(e, alvo, Color(0.4, 1.0, 0.6), true)
		28: _circulo_buff(e, alvo, Color(1.0, 0.6, 0.4), true)
		48, 234: _circulo_buff(e, alvo, Color(0.4, 0.6, 1.0), false)
		6: teleporte(e, quem, true)
		15: teleporte(e, alvo, true)
		11: _onda(e, de, frente)
		45: _lanca(e, quem, frente, alvo)
		30, 31, 32, 33, 34, 35, 36: _invocar(e, quem)
		44: _lua(e, quem, b, frente)
		232: _destruicao(e, quem, b, frente, para)
		235: _multiplas(e, de, frente)
		76: _plasma(e, quem, frente, [alvo], 1)
		16: _barreira(e, alvo, 60.0 * T, 0.2)
		40: _nova(e, quem)
		58: _nova_carga(e, quem, b)
		77: _flecha_infinita(e, quem, b)
		233: _expansao(e, quem, b)
		60, 66: _forca(e, de, frente)
		61: _explosao_de_fogo(e, quem, b, frente, alvo)
		62: _terremoto(e, quem, frente)
		63: _invocar_grupo(e, de)
		64: _critico(e, quem, b)
		65: _lanca_eletrica(e, de, frente)
		72: _abolir(e, de)
		74: _rasgo(e, de, frente, alvo)
		78: _grito_de_fogo(e, de, frente)
		238: _caotico(e, quem, b, frente, alvo)
		57: _espiral(e, quem, frente)
		73: _raios_de_mana(e, de, frente)
		236, 492, 494: _golpe_de_chama(e, quem, b)
		237, 496: _tempestade(e, de, frente)
		_:
			if n in ESPADA or (b and b.tem_arma_de_corte()):
				_faiscas(e, _peito(alvo), 8, Color(1, 0.8, 0.6))
			else:
				_bola_de_energia(e, de, alvo)


# golpe sem skill: com arco sai a flecha (CreateArrow); o rastro da espada o Boneco ja faz
static func golpe_comum(pai: Node3D, quem: Entidade, alvo: Entidade) -> void:
	if pai == null or quem.boneco == null or not quem.boneco.tem_arco():
		return
	var e := EfeitoMU.criar(pai)
	var d := alvo.global_position - quem.global_position
	d.y = 0
	_flechas(e, quem.global_position, d.normalized() if d.length() > 0.05 else -quem.global_basis.z, alvo.global_position, [0.0])


# --- pecas que muitas skills usam -----------------------------------------------------

# BITMAP_FIRE (Fire01): chama que sobe girando e some
static func fogo(e: EfeitoMU, p: Vector3, cor := BRANCO, esc := 1.0) -> void:
	var tam := 0.64 * _rnd(1.28, 1.92) * esc
	e.sprite("fire01", p + Vector3(_rnd(-0.1, 0.1), _rnd(-0.1, 0.1), _rnd(-0.1, 0.1)), tam, cor, 24 * T * 0.6,
		{vel = Vector3(_rnd(-1, 1), _rnd(0.5, 1.5), _rnd(-1, 1)), giro = _rnd(0, TAU), vgiro = _rnd(-3, 3), tam1 = tam * 0.3})


# luz no chao (AddTerrainLight): um brilho deitado
static func luz_chao(e: EfeitoMU, p: Vector3, cor: Color, raio: float, vida: float, op := {}) -> void:
	var c := cor
	c.a = 0.5
	var o := op.duplicate()
	o.entra = o.get("entra", 0.15)
	o.some = o.get("some", 0.4)
	e.chao("flare01", Vector3(p.x, _chao_em(e, p), p.z), raio * 2.0, c, vida, o)


static func _chao_em(e: EfeitoMU, p: Vector3) -> float:
	var m = e.get_parent()
	if m and m.has_method("altura_em"):
		return m.altura_em(p.x, -p.z) / 100.0
	return p.y


# MODEL_STONE1/2: pedrinhas que pulam e caem (sem somar: pedra de verdade)
static func pedras(e: EfeitoMU, p: Vector3, n: int) -> void:
	for i in n:
		e.modelo("stone0%d" % (1 + randi() % 2), p + Vector3(_rnd(-0.3, 0.3), 0.1, _rnd(-0.3, 0.3)), _rnd(0.5, 0.9), BRANCO, _rnd(0.6, 0.9),
			{solido = true, vel = Vector3(_rnd(-2, 2), _rnd(3, 5), _rnd(-2, 2)), acel = Vector3(0, -16, 0), vgiro = _rnd(-8, 8), some = 0.0})


# BITMAP_EXPLOTION: Explotion01 (4 x 4 quadros, 10 usados)
static func explosao(e: EfeitoMU, p: Vector3, tam := 1.6, cor := BRANCO) -> void:
	e.sprite("explotion01", p, tam, cor, 20 * T, {quadros = 10, colunas = 4, linhas = 4, some = 0.3, giro = _rnd(0, TAU)})


static func fumaca(e: EfeitoMU, p: Vector3, cor: Color, tam: float, vida := 1.2, vel := Vector3.ZERO) -> void:
	e.sprite("smoke01", p, tam, cor, vida, {vel = vel, giro = _rnd(0, TAU), vgiro = _rnd(-1, 1), tam1 = tam * 1.8, entra = 0.15, some = 0.7})


static func _faiscas(e: EfeitoMU, p: Vector3, n: int, cor: Color) -> void:
	for i in n:
		var d := Vector3(_rnd(-1, 1), _rnd(-0.2, 1), _rnd(-1, 1)).normalized()
		e.sprite("spark03", p, _rnd(0.15, 0.3), cor, _rnd(0.3, 0.6), {vel = d * _rnd(3, 6), acel = Vector3(0, -10, 0)})
	e.sprite("flare01", p, 1.2, cor, 0.25)


# rastro de pontos atras de uma cabeca que anda (CreateJoint com caudas)
static func cauda(e: EfeitoMU, tex: String, largura: float, cor: Color, vida: float, caudas: int, cabeca: Callable, op := {}) -> Dictionary:
	var st := {pts = [], acc = 0.0, ult = -1.0}
	var o := op.duplicate()
	o.cauda = o.get("cauda", 1.0)
	o.anda = func(p, _k):
		var h: Vector3 = cabeca.call(p.t)
		if st.pts.is_empty() or p.t - st.ult >= T:
			st.pts.push_front(h)
			st.ult = p.t
			while st.pts.size() > caudas:
				st.pts.pop_back()
		else:
			st.pts[0] = h
	return e.fita(tex, func(): return st.pts, null, largura, cor, vida, o)


# BITMAP_SHINY+2 (Shiny03) na ponta da arma: uma piscada em todo golpe de skill
static func _brilho_lamina(e: EfeitoMU, b: Boneco, n: int) -> void:
	if n == 42:
		return
	b.rastro(0.55, BRANCO, "motion_blur" if n == 56 else "motion_blur_r")
	await e.get_tree().create_timer(0.15).timeout
	if is_instance_valid(b):
		e.sprite("shiny03", b.ponta_arma(), 1.28 * 1.5, BRANCO, 18 * T, {pulso = true, some = 0.0,
			anda = func(p, _k): if is_instance_valid(b): p.no.global_position = b.ponta_arma()})


# --- mago ---------------------------------------------------------------------------

static func _veneno(e: EfeitoMU, alvo) -> void:
	var p := _pos(alvo)
	e.modelo("poison01", p, 1.0, BRANCO, 40 * T, {some = 0.25})
	for i in 10:
		var d := Vector3(_rnd(-1, 1), 0, _rnd(-1, 1)).normalized()
		fumaca(e, p + Vector3(d.x * 0.32, _rnd(0.32, 0.96), d.z * 0.32), Color(0.5, 1, 0.8), 0.64 * _rnd(0.8, 1.1), 50 * T, d * 1.2)
	luz_chao(e, p, Color(0.3, 1, 0.6), 2.0, 1.6)


static func _meteoro(e: EfeitoMU, para: Vector3) -> void:
	var de := para + Vector3(_rnd(1.3, 1.62), 4.0, 0)
	var n := e.voar(de, para, 8 * T, func(q):
		explosao(e, q + Vector3.UP * 0.8, 2.0)
		pedras(e, q, 6)
		luz_chao(e, q, Color(1, 0.3, 0.1), 2.5, 0.8))
	e.modelo("fire01", de, _rnd(1.0, 1.7), BRANCO, 1.0, {segue = n, dir = para - de, some = 0.0})
	e.tarefa(T, 8 * T, func(ef, _i): if EfeitoMU.voando(n): fogo(ef, n.global_position))


static func _raio(e: EfeitoMU, quem, b: Boneco, alvo) -> void:
	var mao := func(): return b.ponta_arma() if b and is_instance_valid(b) else _pos(quem) + Vector3.UP * 1.3
	var fim := func(): return _peito(alvo)
	e.tarefa(T * 2, 15 * T, func(ef, _i):
		ef.fita("jointthunder01", mao.call(), fim.call(), 0.5, BRANCO, T * 2.5, {raio = 0.25, pedacos = 10, some = 0.0})
		ef.fita("jointthunder01", mao.call(), fim.call(), 0.12, BRANCO, T * 2.5, {raio = 0.6, pedacos = 10, some = 0.0}))
	e.sprite("thunder01", mao.call(), 0.9, BRANCO, 15 * T, {giro = _rnd(0, TAU), vgiro = 6.0})
	luz_chao(e, _pos(alvo), Color(0.3, 0.3, 1), 2.0, 0.7)
	e.sprite("spark03", fim.call(), 1.5, Color(0.7, 0.8, 1), 15 * T)


static func _bola_de_fogo(e: EfeitoMU, de: Vector3, frente: Vector3, alvo) -> void:
	var a := de + Vector3.UP * 1.2 + frente * 0.3
	var b := _peito(alvo)
	var n := e.voar(a, b, a.distance_to(b) / v(50), func(q):
		pedras(e, q, 2)
		e.sprite("flare01", q, 1.6, Color(1, 0.6, 0.3), 0.3))
	e.modelo("fire01", a, _rnd(0.8, 1.1), BRANCO, a.distance_to(b) / v(50) + 0.05, {segue = n, dir = b - a, some = 0.0})
	e.tarefa(T, a.distance_to(b) / v(50), func(ef, _i): if EfeitoMU.voando(n): fogo(ef, n.global_position))
	luz_chao(e, a, Color(1, 0.3, 0.1), 1.5, a.distance_to(b) / v(50) + 0.1, {segue = n})


static func _chama(e: EfeitoMU, p: Vector3) -> void:
	luz_chao(e, p, Color(1, 0.4, 0), 3.0, 40 * T)
	e.tarefa(T, 40 * T, func(ef, i):
		for k in 3:
			var tam := 0.64 * _rnd(0.64, 1.28)
			ef.sprite("flame01", p + Vector3(_rnd(-0.25, 0.25), 0.1, _rnd(-0.25, 0.25)), tam, BRANCO, 20 * T,
				{vel = Vector3(0, _rnd(3, 5), 0), giro = _rnd(0, TAU), vgiro = _rnd(-2, 2), tam1 = tam * 0.5, entra = 0.1})
		if i % 8 == 0:
			pedras(ef, p, 1))


static func _gelo(e: EfeitoMU, p: Vector3) -> void:
	e.modelo("ice01", p, 0.8, BRANCO, 50 * T, {ritmo = 1.0, some = 0.4})
	for i in 5:
		var d := Vector3(_rnd(-1, 1), 0, _rnd(-1, 1)).normalized() * v(_rnd(6.4, 32)) * 0.5
		e.modelo("ice02", p + Vector3.UP * 0.5, _rnd(0.8, 1.1), BRANCO, _rnd(32, 47) * T,
			{vel = d + Vector3.UP * v(_rnd(8, 23)), acel = Vector3(0, -v(3) / T, 0), vgiro = 8.0, some = 0.3})
	for i in 3:
		fumaca(e, p + Vector3(_rnd(-0.4, 0.4), 0.3, _rnd(-0.4, 0.4)), Color(0.5, 0.6, 0.8), 0.8)


static func _tornado(e: EfeitoMU, de: Vector3, frente: Vector3) -> void:
	var dura := 59 * T
	var n := e.voar(de, de + frente * v(10) * dura, dura)
	e.modelo("storm01", de, 1.0, BRANCO, dura, {segue = n, uv_vel = Vector2(0, 2.5), some = 0.25, entra = 0.1})
	e.tarefa(T * 2, dura, func(ef, _i):
		if not EfeitoMU.voando(n):
			return
		var q := n.global_position
		fumaca(ef, q + Vector3.UP * 0.3, Color(0.4, 0.4, 0.45), 0.9, 0.8)
		if randf() < 0.5:
			ef.fita("jointthunder01", q + Vector3(_rnd(-2, 2), 7, _rnd(-2, 2)), q + Vector3.UP * 0.5, 0.1, BRANCO, T * 2, {raio = 0.4, pedacos = 12, some = 0.0})
		if randf() < 0.25:
			pedras(ef, q, 1))
	luz_chao(e, de, Color(0.2, 0.2, 0.3), 2.5, dura, {segue = n})


# Evil Spirit: 4 pares de fitas escuras (subtraindo) que voam e voltam pra quem soltou
static func _espirito(e: EfeitoMU, quem) -> void:
	var centro := func(): return _pos(quem) + Vector3.UP * 0.8
	for i in 4:
		for largura in [0.8, 0.2]:
			var st := {p = _pos(quem) + Vector3.UP, ang = deg_to_rad(90.0 * i) + _rnd(-0.2, 0.2), alt = 0.0}
			cauda(e, "jointspirit01", largura, Color(1, 1, 1), 49 * T, 6, func(t):
				# 70 por tick, virando 10 graus por tick pro centro, com tremida
				var dt := T if t > 0.0 else 0.0
				var c: Vector3 = centro.call()
				var para_c := atan2(c.x - st.p.x, c.z - st.p.z)
				var dif := wrapf(para_c - st.ang, -PI, PI)
				st.ang += clampf(dif, -deg_to_rad(10), deg_to_rad(10)) * (1.0 if t > 0.3 else 0.0) + _rnd(-0.25, 0.25)
				st.alt = clampf(st.alt + _rnd(-0.3, 0.3), -0.3, 1.5)
				st.p += Vector3(sin(st.ang), 0, cos(st.ang)) * v(70) * dt * 0.6
				st.p.y = c.y + 0.6 + st.alt
				return st.p
			, {menos = true, some = 0.3})


static func _fogo_do_inferno(e: EfeitoMU, quem) -> void:
	var p := _pos(quem)
	e.modelo("circle01", p, 1.0, BRANCO, 45 * T, {some = 0.5, segue = quem})
	e.modelo("circle02", p, 1.0, Color(0.6, 0.6, 0.6), 40 * T, {entra = 0.25, some = 0.6, uv_vel = Vector2(0, 0.25), segue = quem})
	luz_chao(e, p, Color(1, 0.8, 0.2), 4.0, 40 * T)
	e.tarefa(T * 2, 40 * T, func(ef, _i):
		if randf() < 0.5:
			pedras(ef, p + Vector3(_rnd(-3, 3), 0, _rnd(-3, 3)), 1))


static func _aqua(e: EfeitoMU, de: Vector3, frente: Vector3) -> void:
	var lado := frente.cross(Vector3.UP)
	var a := de + Vector3.UP * 1.0 + frente * 0.9 - lado * 0.2
	for i in 20:
		var q := a + frente * 0.5 * i
		e.sprite("spark03", q, 1.1, Color(0.5, 0.7, 1), 20 * T, {some = 0.4, entra = 0.05, giro = _rnd(0, TAU)})
	e.fita("jointlaser01", a, a + frente * 10.0, 0.6, Color(0.5, 0.7, 1), 20 * T, {some = 0.4, uv_vel = Vector2(-3, 0)})
	for i in 5:
		luz_chao(e, a + frente * 2.0 * i, Color(0.3, 0.5, 1), 1.0, 20 * T)


static func _cometa(e: EfeitoMU, para: Vector3) -> void:
	for k in 2:
		var de := para + Vector3(_rnd(2, 3), _rnd(3, 8), _rnd(-0.5, 0.5))
		var tempo := de.distance_to(para) / v(_rnd(50, 100))
		var n := e.voar(de, para, tempo, func(q):
			pedras(e, q, 6)
			e.sprite("ring", q + Vector3.UP * 0.3, 2.0, Color(0.5, 0.7, 1), 0.5, {tam1 = 4.0})
			explosao(e, q + Vector3.UP * 0.8, 2.2, Color(0.6, 0.8, 1)))
		e.modelo("blast01", de, _rnd(1.0, 1.7), BRANCO, tempo + 0.05, {segue = n, dir = para - de, some = 0.0})
		cauda(e, "jointlaser01", 1.0, Color(0.4, 0.6, 1), tempo + 0.3, 10, func(_t): return n.global_position if EfeitoMU.voando(n) else para)
	luz_chao(e, para, Color(0.2, 0.4, 1), 2.5, 1.0)


static func _inferno(e: EfeitoMU, de: Vector3) -> void:
	e.modelo("inferno01", de, 0.9, Color(0.8, 0.8, 0.8), 15 * T * 2, {ritmo = 0.5, some = 0.6})
	for i in 8:
		var a := deg_to_rad(45.0 * i)
		var q := de + Vector3(sin(a), 0, cos(a)) * 2.2
		explosao(e, q + Vector3.UP * 0.8, 1.8)
		pedras(e, q, 2)
		for k in 8:
			var d := Vector3(_rnd(-1, 1), _rnd(0.3, 1.2), _rnd(-1, 1))
			e.sprite("spark03", q + Vector3.UP * 0.8, _rnd(0.15, 0.3), Color(1, 0.7, 0.4), _rnd(24, 39) * T, {vel = d * 4.0, acel = Vector3(0, -12, 0)})
		luz_chao(e, q, Color(1, 0.4, 0.1), 1.5, 0.8)


static func _bola_de_energia(e: EfeitoMU, de: Vector3, alvo) -> void:
	var a := de + Vector3.UP * 1.0
	var b := _peito(alvo)
	var tempo := minf(a.distance_to(b) / v(60), 20 * T)
	var n := e.voar(a, b, tempo, func(q): e.sprite("spark03", q, 0.32 * 6, Color(0.6, 0.7, 1), 0.3))
	e.tarefa(T, tempo, func(ef, _i):
		if not EfeitoMU.voando(n):
			return
		ef.sprite("thunder01", n.global_position, 0.64 * _rnd(0.6, 1.3), BRANCO, 0.2, {giro = _rnd(0, TAU)})
		ef.sprite("spark03", n.global_position, 0.32 * 4, Color(0.6, 0.7, 1), 0.12))
	luz_chao(e, a, Color(0.3, 0.4, 1), 1.2, tempo, {segue = n})


static func _decadencia(e: EfeitoMU, para: Vector3) -> void:
	for k in 2:
		var de := para + Vector3(_rnd(2, 3), _rnd(5, 8), _rnd(-0.5, 0.5))
		var tempo := de.distance_to(para) / v(_rnd(50, 100))
		var n := e.voar(de, para, tempo, func(q):
			var anel := e.modelo("inferno01", q, 0.3, Color(0.3, 1, 0.3), 12 * T * 2, {tam1 = 0.3 + 0.04 * 24, some = 0.5})
			for i in 15:
				fumaca(e, q + Vector3(_rnd(-1, 1), 0.3, _rnd(-1, 1)), Color(0.1, 0.5, 0.1), 1.0, 1.0)
			pedras(e, q, 6)
			explosao(e, q + Vector3.UP * 0.8, 1.8, Color(0.6, 1, 0.5)))
		e.tarefa(T, tempo, func(ef, _i):
			if not EfeitoMU.voando(n):
				return
			var q := n.global_position
			ef.sprite("flare01", q, 0.64 * 3, Color(0.5, 0.5, 1), T * 1.5, {some = 0.0})
			ef.sprite("shiny02", q, 0.32 * _rnd(3, 4), BRANCO, T * 1.5, {giro = _rnd(0, TAU), some = 0.0})
			fogo(ef, q, Color(0.1, 1, 0)))
		cauda(e, "smoke01", 1.0, Color(0.3, 0.6, 0.3), tempo + 0.3, 10, func(_t): return n.global_position if EfeitoMU.voando(n) else para)
	luz_chao(e, para, Color(0.3, 1, 0.3), 2.5, 1.0)


static func _tempestade_de_gelo(e: EfeitoMU, para: Vector3) -> void:
	for i in 10:
		var de := para + Vector3(_rnd(-1.5, 1.5) + 1.0, 6.0 + _rnd(0, 0.5) * i * 0.2, _rnd(-1.5, 1.5))
		var fim := Vector3(de.x - 1.0, para.y, de.z)
		var tempo := (de.y - para.y) / v(_rnd(30, 60))
		var n := e.voar(de, fim, tempo, func(q):
			fumaca(e, q + Vector3.UP * 0.2, Color(0.24, 0.28, 0.8), 1.2, 1.0)
			e.modelo("blizzard", q, 0.5, BRANCO, 20 * T, {some = 1.0})
			if randf() < 0.2:
				e.modelo("ice02", q + Vector3.UP * 0.3, 0.8, BRANCO, 1.0, {vel = Vector3(_rnd(-1, 1), 3, _rnd(-1, 1)), acel = Vector3(0, -12, 0), vgiro = 8.0}))
		e.modelo("blizzard", de, 0.5, BRANCO, tempo + 0.05, {segue = n, entra = 0.6, some = 0.0})
		# por tick: fumaca (BITMAP_SMOKE 0, 1,5), Shiny02 e a luz (BITMAP_LIGHT = flare01) que
		# clareia 0,1 por tick ate ficar branca
		e.tarefa(T, tempo, func(ef, i):
			if not EfeitoMU.voando(n):
				return
			var q := n.global_position
			var luz := minf(0.1 * (i + 1), 1.0)
			fumaca(ef, q, Color(0.55, 0.6, 0.7), 0.64 * 1.5, 20 * T)
			ef.sprite("shiny02", q, 0.64 * _rnd(0.8, 1.4), Color(luz, luz, luz), T * 2, {giro = _rnd(0, TAU)})
			ef.sprite("flare01", q, 0.64, Color(luz, luz, luz), T * 2, {giro = _rnd(0, TAU)}))
	luz_chao(e, para, Color(0.3, 0.5, 1), 3.0, 1.5)


# --- cavaleiro e gladiador ---------------------------------------------------------

# Twisting Slash: 5 copias da arma deitada girando em volta, 1,5 tile de raio
static func _giro(e: EfeitoMU, quem, b: Boneco) -> void:
	await e.get_tree().create_timer(0.2).timeout
	if not is_instance_valid(e) or typeof(quem) != TYPE_OBJECT or not is_instance_valid(quem):
		return
	for i in 5:
		var arma: Node3D = b.arma_copia() if b else null
		var alfa: float = [0.6, 0.6, 0.5, 0.4, 0.3][i]
		var p: Dictionary
		if arma:
			var suporte := Node3D.new()
			suporte.add_child(arma)
			suporte.rotation_degrees = Vector3(-90, 180, 0)
			suporte.scale = Vector3.ONE * 0.01
			p = e.no_pronto(suporte, _pos(quem), 1.0, Color(alfa, alfa, alfa), 25 * T, {some = 0.4})
		else:
			p = e.sprite("flare01", _pos(quem), 1.0, Color(1, 0.8, 0.6, alfa), 25 * T)
		var atraso := i * T
		p.anda = func(pp, _k):
			var t: float = maxf(pp.t - atraso, 0.0)
			var ang := -deg_to_rad(18.0) * t / T
			var centro: Vector3 = _pos(quem) if is_instance_valid(quem) else pp.no.global_position
			pp.no.global_position = centro + Vector3(sin(ang), 1.0, cos(ang)) * Vector3(1.5, 1.0, 1.5)
			pp.giro = ang + deg_to_rad(15.0) * (t / T) * (t / T)
			if pp.has("mats"):
				pp.base = Basis(Vector3.RIGHT, PI / 2)
	e.tarefa(T, 25 * T, func(ef, i):
		if not is_instance_valid(quem):
			return
		var ang: float = -deg_to_rad(18.0) * i
		var q := _pos(quem) + Vector3(sin(ang) * 1.5, 1.0, cos(ang) * 1.5)
		ef.sprite("flare01", q, 0.64 * 2, Color(1, 0.8, 0.6), T * 3)
		if i % 2 == 0:
			fumaca(ef, q, Color(0.35, 0.35, 0.4), 0.7, 0.6)
		for k in 2:
			ef.sprite("spark01", q, 0.2, Color(1, 0.9, 0.7), 0.3, {vel = Vector3(_rnd(-2, 2), _rnd(1, 4), _rnd(-2, 2))}))


# Rageful Blow: estouro na frente e o chao rachando em volta
static func _furia(e: EfeitoMU, de: Vector3, frente: Vector3) -> void:
	await e.get_tree().create_timer(9 * T).timeout
	if not is_instance_valid(e):
		return
	var p := de + frente * 0.8
	p.y = _chao_em(e, p)
	explosao(e, p + Vector3.UP * 0.5, 1.2)
	_faiscas(e, p + Vector3.UP * 0.5, 8, Color(1, 0.8, 0.5))
	e.modelo("flashing", p, 1.0, BRANCO, 0.6, {tam1 = 1.0 + 1.2 * 15 * 0.1, some = 0.7})
	for k in ["earthquake01", "earthquake02", "earthquake03"]:
		e.modelo(k, p, 1.5, BRANCO, 1.6, {some = 0.5, uv_vel = Vector2(0, 0.5)})
	for i in 5:
		var a := deg_to_rad(72.0 * i)
		var q := p + Vector3(sin(a), 0, cos(a)) * _rnd(1.0, 2.5)
		q.y = _chao_em(e, q)
		for k in ["earthquake04", "earthquake05"]:
			e.modelo(k, q, _rnd(0.4, 0.9), BRANCO, 1.6, {giro = a, some = 0.5})
	luz_chao(e, p, Color(1, 0, 0), 3.0, 1.4)
	pedras(e, p, 6)
	await e.get_tree().create_timer(T).timeout
	if not is_instance_valid(e):
		return
	for i in 5:
		var q := p
		var a := deg_to_rad(72.0 * i + 36.0)
		for k in 4:
			a += deg_to_rad(_rnd(50, 80) * (1 if randf() < 0.5 else -1)) * 0.4
			q += Vector3(sin(a), 0, cos(a)) * _rnd(0.85, 1.0)
			q.y = _chao_em(e, q)
			e.modelo("earthquake0%d" % (7 + k % 2), q, 1.0, BRANCO, 1.4 - k * 0.1, {giro = a, some = 0.5, entra = 0.05})


# Death Stab (AttackStage AT_SKILL_DEATHSTAB): nos ticks 2 a 8, 3 fitas vermelhas por tick
# (MODEL_SPEARSKILL 2) que vem de 14 tiles atras e se juntam na frente; nos ticks 6 a 12, de 2
# em 2, duas lancas de luz (MODEL_SPEAR 1, vivem 10 ticks) na ponta da arma, cada uma soltando
# por tick uma espiral azul BITMAP_FLARE 12 (70 ticks, 50 caudas, raio 26, anda 4/tick pra
# frente e desce 0,3/tick): juntas fazem a broca azul. O alvo toma o choque por 35 ticks.
static func _estocada(e: EfeitoMU, quem, b: Boneco, frente: Vector3, alvo) -> void:
	var ponta := func(): return b.ponta_arma() if b and is_instance_valid(b) else _pos(quem) + Vector3.UP * 1.2
	var lado := frente.cross(Vector3.UP).normalized()
	var foco: Vector3 = _pos(quem) + Vector3.UP * 1.2 + frente * 3.0
	for tick in range(2, 9):
		for i in 3:
			var ini := _pos(quem) - frente * _rnd(11, 17) + lado * _rnd(-3, 3) + Vector3.UP * _rnd(-1.8, 4.2)
			var bambo := Vector3(_rnd(-1, 1), _rnd(-0.5, 0.5), _rnd(-1, 1))
			var vida := (10 + i) * T
			var atraso := (tick - 2) * T
			cauda(e, "nskill", 0.6, Color(1, 0.3, 0.3), vida + atraso, 5, func(t):
				var k := clampf((t - atraso) / vida, 0, 1)
				return ini.lerp(foco, k) + bambo * sin(k * PI))
	await e.get_tree().create_timer(6 * T).timeout
	e.get_tree().create_timer(4 * T).timeout.connect(func():
		if is_instance_valid(e):
			_choque_estocada(e, alvo))
	for tick in range(6, 13, 2):
		if not is_instance_valid(e):
			return
		var base: Vector3 = ponta.call() + frente * (1.0 + (tick - 8) * 0.1)
		for lanca in 2:
			e.sprite("flare01", base, 0.8, Color(0.3, 0.3, 1), 10 * T)
			for k in 10:
				var atraso := k * T
				var fase := _rnd(0, 360)
				cauda(e, "flare", 1.0, Color(0.1, 0.1, 1), 70 * T + atraso, 25, func(t):
					var tk := maxf(t - atraso, 0.0) / T
					var a := (fase + 70.0 - tk) * 0.1
					return base + frente * 0.04 * tk + lado * (-cos(a) * 0.26) + Vector3.UP * (sin(a) * 0.26 - (20.0 + tk) * 0.003),
					{some = 0.3})
		await e.get_tree().create_timer(2 * T).timeout


# m_byHurtByDeathstab: o alvo do Death Stab com raios em volta por 35 ticks
static func _choque_estocada(e: EfeitoMU, alvo) -> void:
	if typeof(alvo) == TYPE_OBJECT and is_instance_valid(alvo) and alvo is Entidade:
		e.tarefa(T * 2, 35 * T, func(ef, _i):
			if not is_instance_valid(alvo):
				return
			var c := _pos(alvo)
			var h := (alvo as Entidade).boneco.altura if (alvo as Entidade).boneco else 1.7
			for k in 3:
				var a := c + Vector3(_rnd(-0.3, 0.3), _rnd(0.1, h), _rnd(-0.3, 0.3))
				ef.fita("jointthunder01", a, a + Vector3(_rnd(-0.5, 0.5), _rnd(-0.5, 0.5), _rnd(-0.5, 0.5)), 0.2, BRANCO, T * 2, {raio = 0.2, pedacos = 4, some = 0.0}))


# Impale: energia juntando na ponta, espiral pra frente e 3 lancas de luz
static func _empalar(e: EfeitoMU, de: Vector3, b: Boneco, frente: Vector3) -> void:
	var ponta: Vector3 = b.ponta_arma() if b else de + Vector3.UP * 1.2
	for i in 12:
		var dirr := Vector3(_rnd(-1, 1), _rnd(-1, 1), _rnd(-1, 1)).normalized()
		var ini := ponta + dirr
		e.fita("jointenergy01", ini, ponta, 0.08, Color(1, 1, 0.5), 12 * T, {some = 0.5,
			anda = func(p, k): p.fita[0] = ini.lerp(ponta, k * k)})
	await e.get_tree().create_timer(4 * T).timeout
	if not is_instance_valid(e):
		return
	var base := de + frente * 0.5 + Vector3.UP * 1.1
	for lado in [0.0, PI]:
		cauda(e, "flare", 0.5, BRANCO, 1.6, 30, func(t):
			var a: float = lado + t * 15.0
			var r := lerpf(0.97, 0.26, clampf(t / 1.2, 0, 1))
			return base + frente * v(2) * t * 2 + frente.cross(Vector3.UP) * cos(a) * r + Vector3.UP * sin(a) * r)
	await e.get_tree().create_timer(5 * T).timeout
	if not is_instance_valid(e):
		return
	for i in 3:
		var q := de + frente * 1.45 + Vector3.UP * 1.1 + Vector3(_rnd(-0.3, 0.3), _rnd(-0.3, 0.3), _rnd(-0.3, 0.3))
		e.modelo("ridingspear01", q, 1.5, Color(0.6, 0.6, 0.6), 20 * T, {dir = frente, vel = frente * v(5), some = 0.8})


# Fire Slash: leque de motion_blur_r2 varrendo 187 graus na frente
static func _corte_de_fogo(e: EfeitoMU, quem, b: Boneco, frente: Vector3) -> void:
	var mao: Vector3 = b.ponta_arma() if b else _pos(quem) + Vector3.UP * 1.2
	for i in 6:
		var dirr := Vector3(_rnd(-1, 1), _rnd(-1, 1), _rnd(-1, 1)).normalized()
		e.sprite("spark03", mao + dirr * 1.2, 0.3, BRANCO, 0.25, {vel = -dirr * 4.8})
	e.sprite("shiny02", mao, 0.32 * 3, BRANCO, 0.4, {giro = _rnd(0, TAU), vgiro = 4.0})
	await e.get_tree().create_timer(3 * T).timeout
	if not is_instance_valid(e):
		return
	var c := _pos(quem) + Vector3.UP * 1.0
	var a0 := atan2(frente.x, frente.z) + deg_to_rad(95)
	var fim := e.fita("motion_blur_r2", func(): return [], null, 1.5, BRANCO, 20 * T, {some = 0.5})
	var pts := []
	for k in 18:
		var a := a0 - deg_to_rad(11.0 * k)
		pts.append(c + Vector3(sin(a), 0, cos(a)) * 1.45)
	fim.anda = func(p, _k):
		var mostra := mini(int(p.t / T * 8) + 2, pts.size())
		p.fita[0] = func(): return pts.slice(0, mostra)
	for k in range(0, 18, 3):
		fogo(e, pts[k])


# Power Slash: 5 ondas (Magic02) em leque correndo pra frente
static func _corte_de_poder(e: EfeitoMU, de: Vector3, frente: Vector3) -> void:
	await e.get_tree().create_timer(0.15).timeout
	if not is_instance_valid(e):
		return
	for g in [-40.0, -20.0, 0.0, 20.0, 40.0]:
		var d := frente.rotated(Vector3.UP, deg_to_rad(g))
		var n := e.voar(de + d * 0.5, de + d * v(60) * 20 * T, 20 * T)
		e.modelo("magic02", de + d * 0.5, 1.0, Color(0.5, 0.5, 0.5), 20 * T, {segue = n, dir = d, uv_vel = Vector2(0, 5), some = 0.6})
		e.tarefa(T * 2, 20 * T, func(ef, _i):
			if EfeitoMU.voando(n):
				ef.sprite("flare01", n.global_position + Vector3.UP * 0.4, 0.64 * 3.5, Color(0.3, 0.6, 1), T * 3)
				ef.sprite("shiny02", n.global_position + Vector3.UP * 0.4, 0.32 * 1.5, BRANCO, T * 3, {giro = _rnd(0, TAU)}))
	luz_chao(e, de + frente * 2, Color(0.3, 0.5, 1), 2.0, 0.8)


# --- elfa ---------------------------------------------------------------------------

static func flecha(e: EfeitoMU, de: Vector3, d: Vector3, ate: float, ao_chegar := Callable(), modelo := "arrow01") -> Node3D:
	var a := de + Vector3.UP * 1.35 + d * 0.6
	var tempo := ate / v(70)
	var n := e.voar(a, a + d * ate, tempo, func(q): if ao_chegar.is_valid(): ao_chegar.call())
	e.modelo(modelo, a, 0.8, BRANCO, tempo + 0.05, {segue = n, dir = d, some = 0.0, soma = [1]})
	e.tarefa(T * 2, tempo, func(ef, _i):
		if EfeitoMU.voando(n):
			ef.sprite("fire01", n.global_position, 0.3, Color(0.8, 0.5, 0.2), 0.25, {giro = _rnd(0, TAU), tam1 = 0.1}))
	return n


static func _flechas(e: EfeitoMU, de: Vector3, frente: Vector3, para: Vector3, graus: Array, ao_chegar := Callable()) -> void:
	var dist := clampf(Vector2(para.x - de.x, para.z - de.z).length(), 1.0, 8.0)
	for i in graus.size():
		flecha(e, de, frente.rotated(Vector3.UP, deg_to_rad(graus[i])), dist, ao_chegar if i == 0 else Callable())


static func _gelo_flecha(e: EfeitoMU, p: Vector3) -> void:
	e.modelo("ice01", p, 0.8, Color(0.5, 0.5, 0.5), 2.0, {ritmo = 1.0, some = 0.3})
	for i in 3:
		fumaca(e, p + Vector3(_rnd(-0.3, 0.3), 0.3, _rnd(-0.3, 0.3)), Color(0.5, 0.6, 0.8), 0.7)


static func _penetrar(e: EfeitoMU, de: Vector3, frente: Vector3, _para: Vector3) -> void:
	var junta := de + frente * 1.0 + Vector3.UP * 1.5
	e.sprite("shiny02", junta, 0.32 * 4, BRANCO, 10 * T * 2, {giro = _rnd(0, TAU), vgiro = 5.0})
	for i in 8:
		var dirr := Vector3(_rnd(-1, 1), _rnd(-1, 1), _rnd(-1, 1)).normalized()
		e.sprite("spark03", junta + dirr * 1.2, 0.3, BRANCO, 0.3, {vel = -dirr * 4})
	await e.get_tree().create_timer(0.35).timeout
	if not is_instance_valid(e):
		return
	var n := flecha(e, de, frente, 10.0)
	e.modelo("piercing", n.global_position, 1.0, BRANCO, 10.0 / v(70), {segue = n, dir = frente, vgiro = deg_to_rad(90) / T, some = 0.0})
	var lado := frente.cross(Vector3.UP)
	for a0 in [0.0, PI / 2, PI, deg_to_rad(240)]:
		cauda(e, "flare02", 0.2, Color(0.5, 0.5, 0.5), 10.0 / v(70) + 0.4, 20, func(t):
			if not EfeitoMU.voando(n):
				return Vector3.ZERO
			var a: float = a0 + t * 20.0
			return n.global_position + lado * cos(a) * 0.18 + Vector3.UP * sin(a) * 0.18)


# Heal, Greater Defense, Greater Damage: circulo no chao abrindo e riscos de luz caindo
static func _circulo_buff(e: EfeitoMU, alvo, cor: Color, fitas: bool) -> void:
	var p := _pos(alvo)
	e.chao("magic_ground2", p, 0.2, cor, 20 * T, {tam1 = 3.0, some = 0.25, vgiro = 1.5, segue = alvo if typeof(alvo) == TYPE_OBJECT else null})
	e.tarefa(T, 20 * T, func(ef, _i):
		for k in 3:
			var d := Vector3(_rnd(-1, 1), _rnd(0.2, 1), _rnd(-1, 1)).normalized() * 2.0
			var ini := p + Vector3.UP * 1.2 + d
			var fim := p + Vector3.UP * 1.2
			ef.fita("jointenergy01", ini, ini.lerp(fim, 0.3), 0.1, BRANCO, 12 * T, {some = 0.5,
				anda = func(pp, k2): pp.fita[0] = ini.lerp(fim, k2); pp.fita[1] = ini.lerp(fim, minf(k2 + 0.3, 1.0))}))
	if fitas and typeof(alvo) == TYPE_OBJECT:
		for i in 5:
			var fase := _rnd(0, TAU)
			var vel := _rnd(1.5, 2.5)
			cauda(e, "flareblue", 0.2, Color(0.4, 0.8, 0.2), 3.0, 30, func(t):
				if not is_instance_valid(alvo):
					return Vector3.ZERO
				var a: float = fase + t * vel
				return _pos(alvo) + Vector3(sin(a) * 0.8, 1.1 + sin(a * 1.7 + fase) * 0.6, cos(a * 1.3) * 0.8)
			, {some = 0.3})

# --- teleporte (CreateTeleportBegin / CreateTeleportEnd) -----------------------------

# BITMAP_SPARK+1 efeito: 10 ticks, cada tick uma coluna de 18 faiscas (Spark03, escala 6,
# a de baixo 12) de 24 em 24 unidades, cada uma saindo pra um lado a 50/tick e encolhendo 2/tick.
# sumir: Alpha -0.1 por tick (Begin); senao volta a aparecer (End).
static func teleporte(e: EfeitoMU, quem, sumir := true) -> void:
	e.tarefa(T, 9 * T, func(ef, i):
		if not _vivo(quem):
			return
		var p := _pos(quem)
		var luz: float = (10 - i) * 0.1
		for j in 18:
			var esc := 12.0 if j == 0 else 6.0
			ef.sprite("spark03", p + Vector3.UP * 0.24 * (j + 1), 0.32 * esc, Color(luz, luz, luz), esc / 2.0 * T,
				{vel = Vector3(_rnd(-1, 1), _rnd(-1, 1), _rnd(-1, 1)).normalized() * v(50), tam1 = 0.05, some = 0.0}))
	var b: Boneco = (quem as Entidade).boneco if quem is Entidade else null
	if b == null:
		return
	if not sumir:
		b.visible = true
	# cada teleporte marca o boneco: o sumir de um teleporte velho para quando a chegada vem
	var marca := Time.get_ticks_usec()
	b.set_meta("teleporte", marca)
	e.tarefa(T * 2, 10 * T, func(_ef, i):
		if is_instance_valid(b) and b.get_meta("teleporte", 0) == marca:
			var a: float = 1.0 - i * 0.2 if sumir else i * 0.2
			b.transparente(clampf(a, 0.0, 1.0))
			if sumir and a <= 0.0:
				b.visible = false)
	# a chegada so vem do servidor pro meu personagem e quando ele aceita: se em 1,2 s
	# ninguem trouxe o boneco de volta (outro jogador, teleporte recusado), aparece onde esta
	if sumir:
		e.tarefa(T, 32 * T, func(ef, i):
			if i == 30 and _vivo(quem) and is_instance_valid(b) and b.get_meta("teleporte", 0) == marca:
				teleporte(ef, quem, false))


# --- mago ---------------------------------------------------------------------------

# Power Wave: MODEL_MAGIC2 (Magic02) correndo 60/tick por 20 ticks, 4 fumacas por tick
# (BITMAP_SMOKE 3: 10 ticks, escala 0.8-1.1, saindo a 40-48/tick) e luz azul no chao
static func _onda(e: EfeitoMU, de: Vector3, frente: Vector3) -> void:
	var dura := 20 * T
	var n := e.voar(de, de + frente * v(60) * dura, dura)
	# BlendMeshLight = LifeTime * 0,1: nasce com brilho 2 e apaga ate 0 no fim
	e.modelo("magic02", de, 1.0, Color(2, 2, 2), dura, {segue = n, dir = frente, uv_vel = Vector2(0, 5), some = 1.0})
	e.tarefa(T, dura, func(ef, _i):
		if not EfeitoMU.voando(n):
			return
		for k in 4:
			var d := Vector3(_rnd(-1, 1), _rnd(-0.7, 0.7), _rnd(-1, 1)).normalized()
			ef.sprite("smoke01", n.global_position + Vector3.UP * 0.3, 0.64 * _rnd(0.8, 1.12), Color(0.6, 0.6, 0.6), 10 * T,
				{vel = d * v(_rnd(40, 48)) * 0.25, giro = _rnd(0, TAU), some = 0.6}))
	luz_chao(e, de, Color(0.3, 0.6, 1), 3.0, dura, {segue = n})


# Lance (AT_SKILL_JAVELIN): 3 Javelin girando a 1,5 de altura; 10 ticks quase parados
# (5/tick, giro acelerando), depois disparam (ate 50/tick) e cacam o alvo virando
# Velocity graus por tick (10, +1,5 por tick); no alvo grudam e soltam PoundingBall.
static func _lanca(e: EfeitoMU, quem, frente: Vector3, alvo) -> void:
	var de := _pos(quem) + Vector3.UP * 1.5
	for s in 3:
		var ang: float = deg_to_rad(_rnd(10, 90)) * (s - 1)
		var n := Node3D.new()
		e.add_child(n)
		n.global_position = de
		var st := {p = de, ang = atan2(frente.x, frente.z) + ang, anda = 5.0, vira = 10.0, giro = 2.0, preso = false}
		var lanca := e.modelo("javelin", de, 1.2, BRANCO, 35 * T, {segue = n, tam1 = 1.2 + 0.015 * 35, some = 10.0 / 35.0})
		luz_chao(e, de, Color(1, 0.6, 0.3), 2.0, 35 * T, {segue = n})
		e.tarefa(T, 35 * T, func(ef, i):
			var vida: int = 35 - i
			var mira: Vector3 = _pos(alvo) + Vector3.UP * 1.5 if _vivo(alvo) else st.p
			if vida < 25:
				if vida < 20 and not st.preso:
					var quer := atan2(mira.x - st.p.x, mira.z - st.p.z)
					st.ang += clampf(wrapf(quer - st.ang, -PI, PI), -deg_to_rad(st.vira), deg_to_rad(st.vira))
					if Vector2(mira.x - st.p.x, mira.z - st.p.z).length() < 1.0:
						st.preso = true
				st.vira += 1.5
				st.anda = minf(st.anda + 8.0, 50.0)
				st.giro = _rnd(30, 60)
			else:
				st.giro += 10.0
			if st.preso:
				st.p = mira
				if vida % 3 == 0:
					ef.sprite("poundingball", mira, 0.64 * _rnd(1.28, 2.56), Color(0.5, 0.5, 0.5), 15 * T, {giro = _rnd(0, TAU), some = 0.66})
			else:
				st.p += Vector3(sin(st.ang), 0, cos(st.ang)) * st.anda / 100.0
				if vida < 20:
					ef.sprite("poundingball", st.p, 0.64 * _rnd(1.28, 2.56), Color(0.5, 0.5, 0.5), 15 * T, {giro = _rnd(0, TAU), some = 0.66})
			var h := sin(vida * 0.1) * 0.3 * (s - 1)   # sub 1 e 2 sobem e descem
			n.global_position = st.p + Vector3.UP * h
			lanca.giro += deg_to_rad(st.giro))


# --- elfa ---------------------------------------------------------------------------

# Summon (BITMAP_MAGIC+1 sub 3): o mesmo circulo do Heal, laranja (1, 0.6, 0.4), no fim do
# gesto (AttackTime 1 -> 15). O bicho vem do servidor.
static func _invocar(e: EfeitoMU, quem) -> void:
	await e.get_tree().create_timer(14 * T).timeout
	if is_instance_valid(e) and _vivo(quem):
		_circulo_buff(e, quem, Color(1, 0.6, 0.4), false)


# Multi-Shot: MultiShot03 x2, 01 x3, 02 x2 abrindo na frente (escala 0 -> +0.25/0.2/0.3
# por tick, alfa vida/18, luz 0.8 0.9 1.6), a BladeTonedo 1,2 na frente, e 6 rajadas
# (de 2 em 2 ticks) de uma flecha em +-7/21/35 graus, com brilhos e riscos de faisca.
static func _multiplas(e: EfeitoMU, de: Vector3, frente: Vector3) -> void:
	var cor := Color(0.8, 0.9, 1.0)
	var boca := de + Vector3.UP * 1.35 + frente * 0.6
	for m in [["multishot03", 2, 12, 0.25, -0.2], ["multishot01", 3, 16, 0.2, 0.0], ["multishot02", 2, 13, 0.3, -0.2]]:
		for k in m[1]:
			e.modelo(m[0], boca + frente * m[4], 0.01, cor * (m[2] / 18.0), m[2] * T,
				{tam1 = m[3] * m[2], dir = frente, ritmo = 1.0 / 6.0, some = 1.0})
	var lamina := de + frente * 1.2 + Vector3.UP * 1.45
	e.modelo("bladetonedo", lamina, 1.0, cor, 14 * T, {dir = frente, some = 1.0})
	var st := {ult = -1}
	e.tarefa(T * 2, 10 * T, func(ef, _i):
		var r := randi() % 6
		while r == st.ult:
			r = randi() % 6
		st.ult = r
		var g: float = [7.0, 21.0, 35.0, -7.0, -21.0, -35.0][r]
		var d := frente.rotated(Vector3.UP, deg_to_rad(g))
		flecha(ef, de, d, 6.0)
		for k in 3:
			var q := lamina + Vector3(_rnd(-1, 1), _rnd(-1, 1), _rnd(-1, 1))
			ef.sprite("shiny02", q, 0.32 * _rnd(1.6, 3.0), Color(0.2, 0.3, 1), T * 2, {giro = _rnd(0, TAU)})
			ef.sprite("shiny02", q, 0.32 * _rnd(0.56, 1.05), BRANCO, T * 2, {giro = _rnd(0, TAU)})
			var ini := de + Vector3.UP * _rnd(1.6, 2.4)
			var vel := v(_rnd(14, 69))
			cauda(ef, "spark03", 0.187, BRANCO, _rnd(8, 17) * T, 4, func(t): return ini + d * vel * t, {some = 0.6}))


# --- cavaleiro ----------------------------------------------------------------------

# Crescent Moon Slash (AT_SKILL_RUSH): ate o quadro 5 do golpe, faiscas e fogo nos pes;
# depois a SwordForce: nasce a 1 de altura, cresce 0.9/tick por 3 ticks deixando copias
# (escala 3.5, 5 ticks), anda 10/tick (+2 por tick) e some em 12 ticks soltando faisca e fogo.
static func _lua(e: EfeitoMU, quem, b: Boneco, frente: Vector3) -> void:
	if b:
		b.rastro(1.0, BRANCO, "motion_blur_r")
	e.tarefa(T, 17 * T, func(ef, _i):
		if _vivo(quem):
			_faisca_fogo(ef, _pos(quem) + Vector3(_rnd(-0.15, 0.15), 0.2, _rnd(-0.15, 0.15)), frente))
	await e.get_tree().create_timer(17 * T).timeout
	if not is_instance_valid(e) or not _vivo(quem):
		return
	var p0 := _pos(quem) + Vector3.UP * 1.0
	var n := Node3D.new()
	e.add_child(n)
	n.global_position = p0
	var forca := e.modelo("swordforce", p0, 0.01, BRANCO, 15 * T, {segue = n, dir = frente, some = 0.8})
	luz_chao(e, p0, Color(1, 0.8, 0.6), 1.0, 15 * T, {segue = n})
	e.tarefa(T, 15 * T, func(ef, i):
		var tam: float = 0.9 * (i + 1) if i < 3 else 2.7 - 0.05 * (i - 2)
		forca.tam0 = tam
		forca.tam1 = tam
		n.global_position = p0 + frente * (10.0 * i + i * i) / 100.0
		if i < 3:
			ef.modelo("swordforce", n.global_position, 3.5, Color(0.5, 0.5, 0.5), 5 * T, {dir = frente, some = 1.0})
		else:
			_faisca_fogo(ef, n.global_position - Vector3.UP * 1.0, frente))


# BITMAP_JOINT_SPARK (4 riscos curtos pra tras e pra cima) + BITMAP_FIRE sub 2 (10 ticks)
static func _faisca_fogo(e: EfeitoMU, q: Vector3, frente: Vector3) -> void:
	for k in 4:
		var d := (-frente * _rnd(0.2, 1.0) + Vector3.UP * _rnd(0.4, 1.0) + Vector3(_rnd(-0.3, 0.3), 0, _rnd(-0.3, 0.3))).normalized()
		e.sprite("spark01", q, 0.2, BRANCO, _rnd(8, 16) * T, {vel = d * v(_rnd(6, 26)), acel = Vector3(0, -10, 0), some = 0.5})
		e.sprite("fire01", q, 0.64 * _rnd(1.8, 2.1), BRANCO, 10 * T, {giro = _rnd(0, TAU), vel = d * v(_rnd(0, 4)), some = 0.6})


# Strike of Destruction (MODEL_BLOW_OF_DESTRUCTION sub 0 na frente, sub 1 no tile alvo):
# no tick 17 agua (NightWater01) e rachadura (knight_plancrack_a) na frente, uma fila de
# knight_plancrack_b de 55 em 55 rumo ao alvo; no alvo chuva de Waterfall3/5 azul por 10
# ticks, NightWater x2, knight_plancrack_grand e 5-7 pedras. Tremor de 15 a 24.
static func _destruicao(e: EfeitoMU, quem, b: Boneco, frente: Vector3, para: Vector3) -> void:
	if b:
		b.rastro(0.5, BRANCO, "motion_blur_r")
	var lado := frente.cross(Vector3.UP)
	var a := _pos(quem) + frente * 1.0 - lado * 0.2
	a.y = _chao_em(e, a)
	var c := para
	c.y = _chao_em(e, c)
	var azul := Color(0.3, 0.3, 1.0)
	await e.get_tree().create_timer(16 * T).timeout
	if not is_instance_valid(e):
		return
	e.tarefa(T, 9 * T, func(ef, _i):
		for k in 8:   # o cliente solta 15 por tick; 8 da o mesmo volume
			var q := c + Vector3(_rnd(-1.5, 1.5), _rnd(-0.5, 1.5), _rnd(-1.5, 1.5))
			ef.sprite("waterfall5" if randf() < 0.5 else "waterfall3", q, 0.64 * _rnd(1.6, 2.5), Color(0.5, 0.5, 1), 30 * T,
				{vel = Vector3.UP * v(2), acel = Vector3.UP * -v(0.6) / T, tam1 = 0.64 * 3.0, giro = _rnd(0, TAU), some = 0.8})
			if randf() < 0.5:
				fumaca(ef, q, Color(0.6, 0.6, 0.8), 0.64, 0.8))
	await e.get_tree().create_timer(T).timeout
	if not is_instance_valid(e):
		return
	for k in 2:
		e.modelo("nightwater01", a, 0.9, azul, 25 * T, {giro = _rnd(0, TAU), some = 1.0})
	e.modelo("knight_plancrack_a", a + Vector3.UP * 0.1, 1.2 + _rnd(0, 0.45), azul, 25 * T, {giro = _rnd(0, TAU), ritmo = 0.3, some = 0.4})
	var dir := Vector3(c.x - a.x, 0, c.z - a.z)
	var pedacos := int(dir.length() / 1.0) + 1
	var giro0 := atan2(frente.x, frente.z) + PI / 2
	for i in pedacos:
		var q := a + dir.normalized() * 0.55 * i
		q.y = _chao_em(e, q) + 0.15
		var g := deg_to_rad(_rnd(10, 30)) * (1 if i % 2 == 0 else -1)
		e.modelo("knight_plancrack_b", q, 1.0, azul, 25 * T, {giro = giro0 + g, ritmo = 0.3, some = 0.4})
	e.modelo("nightwater01", c, 2.0, azul, 25 * T, {giro = _rnd(0, TAU), some = 1.0})
	e.modelo("nightwater01", c, 1.0, azul, 25 * T, {giro = _rnd(0, TAU), some = 1.0})
	e.modelo("knight_plancrack_grand", c + Vector3.UP * 0.3, 1.2, azul, 40 * T, {giro = _rnd(0, TAU), some = 0.4})
	for i in 5 + randi() % 3:
		var g := _rnd(0, TAU)
		pedras(e, c + Vector3(sin(g), 0, cos(g)) * _rnd(0, 1.5), 1)
	luz_chao(e, c, Color(0.3, 0.3, 1), 2.5, 1.0)


# --- todos (Fenrir) -----------------------------------------------------------------

# Plasma Storm (MODEL_FENRIR_SKILL_THUNDER): de 1,4 na frente e 1,3 de altura, 2 pares de
# raios (largura 100 e 80) pra cada alvo, 20 ticks, refeitos todo tick (MoveHumming de 50
# com tremida); mais 6 espirais BITMAP_FLARE_FORCE de raio em volta de quem soltou.
# tipo: 0 preto, 1 vermelho, 2 azul, 3 dourado (opcao excelente do Fenrir).
static func _plasma(e: EfeitoMU, quem, frente: Vector3, alvos: Array, tipo := 1) -> void:
	var cor_raio := [Color(0.7, 1, 0.7), Color(1, 0.6, 0.6), Color(0.7, 0.7, 1), Color(0.9, 0.9, 0.3),
		Color(0.1, 0.8, 0.1), Color(1, 0.3, 0.2), Color(0.2, 0.3, 1), Color(0.8, 0.8, 0.1)]
	var boca := func(): return _pos(quem) + frente * 1.4 + Vector3.UP * 1.3
	for k in alvos.size():
		var alvo = alvos[k]
		var fim := func(): return (_pos(alvo) if _vivo(alvo) else _pos(quem)) + Vector3.UP * 0.8
		var sub2: int = (3 if k == 0 else 4) + tipo
		for j in 2:
			e.fita("jointthunder01", boca, fim, 1.0, cor_raio[tipo], 20 * T, {raio = 0.4, pedacos = 12, some = 0.5})
			e.fita("jointthunder01" if sub2 < 4 else "flashing", boca, fim, 0.8, cor_raio[mini(sub2, 7)], 20 * T, {raio = 0.4, pedacos = 12, some = 0.5})
	var cor_espiral: Color = cor_raio[mini(tipo, 2)]
	for k in 6:
		var c0: Vector3 = _pos(quem) + frente * (0.1 + _rnd(-0.2, 0.2)) + Vector3.UP * 2.8
		var eixo := Vector3(_rnd(-1, 1), _rnd(-1, 1), _rnd(-1, 1)).normalized()
		var u := eixo.cross(Vector3.UP).normalized() if absf(eixo.y) < 0.99 else Vector3.RIGHT
		var w := eixo.cross(u)
		var pts := []
		for s in 30:
			var a := -deg_to_rad(20.0) * s
			pts.append(c0 + eixo * (3.0 * s + s * s) / 100.0 + (u * cos(a) + w * sin(a)) * maxf(0.8 - 0.025 * s, 0.05))
		var atraso := _rnd(2, 4) * T
		var f := e.fita("jointthunder01", func(): return [], null, 0.6, cor_espiral, 20 * T + atraso, {some = 0.5})
		f.anda = func(p, _k):
			var tk: float = maxf(p.t - atraso, 0.0) / T
			var mostra := mini(int(tk * tk) + 1, pts.size())
			p.fita[0] = func(): return pts.slice(0, mostra)


# --- ossos (indices do MU: 28 mao direita, 29 junto da mao, 37 mao esquerda) -----------

static func _pos_osso(b: Boneco, k: int) -> Vector3:
	return b.esqueleto.global_transform * b.esqueleto.get_bone_global_pose(k).origin


static func _osso(b: Boneco, i: int) -> Vector3:
	if b and is_instance_valid(b) and b.esqueleto:
		var k := b.esqueleto.find_bone("osso%d" % i)
		if k >= 0:
			return _pos_osso(b, k)
	if b and is_instance_valid(b):
		return b.global_position + Vector3.UP * b.altura * 0.6
	return Vector3.ZERO


# indices do esqueleto (de, ate, passo) que existem
static func _ossos(b: Boneco, de := 0, ate := 999, passo := 1) -> Array:
	var r := []
	if b and is_instance_valid(b) and b.esqueleto:
		for i in range(de, mini(ate, b.esqueleto.get_bone_count()), passo):
			r.append(i)
	return r


# --- Nova ---------------------------------------------------------------------------

# Nova (58, comeco): o mago carregando (PLAYER_SKILL_HELL_BEGIN). Cada tick: luz azul
# (BITMAP_LIGHT tipo 6) em 20 ossos, mais forte a cada estagio, e 3 riscos de energia
# (CreateForce, BITMAP_JOINT_HEALING tipo 8) vindo de 5 tiles pro corpo.
# Para quando a Nova sai (_nova poe ativo = false). Estagio: meta "nova_estagio" do
# servidor (sobe 1 a cada 500 ms, ate 12); sem ela, conta pelo tempo.
static func _nova_carga(e: EfeitoMU, quem, b: Boneco) -> void:
	var estado := {ativo = true}
	if quem is Node:
		(quem as Node).set_meta("nova_carga", estado)
	var t0 := e.t
	e.tarefa(T, 8.0, func(ef, _i):
		if not estado.ativo or not _vivo(quem):
			return
		var c: int = (quem as Node).get_meta("nova_estagio", mini(int((ef.t - t0) / 0.5), 12)) if quem is Node else mini(int((ef.t - t0) / 0.5), 12)
		# o cliente soma c+1 copias por osso; aqui uma so, mais clara
		var cor := Color(0.3, 0.3, 1) * minf(1.0 + c * 0.35, 4.0)
		var ossos := _ossos(b, 0, 40, 2)
		for k in ossos:
			var tam := 0.64 * (1.3 + c * 0.08) * _rnd(0.5, 1.0)
			var vida := _rnd(10, 19) * T
			ef.sprite("flare01", _pos_osso(b, k), tam, cor, vida,
				{vel = Vector3(0, v(2.5), 0), tam1 = tam * pow(0.95, vida / T), giro = _rnd(0, TAU), some = 0.8})
		if ossos.is_empty():
			ef.sprite("flare01", _peito(quem), 0.64 * 3, cor, 10 * T, {some = 0.8})
		var fim := _pos(quem) + Vector3.UP
		for k in 3:
			var a := deg_to_rad(_rnd(0, 90))
			var h := deg_to_rad(_rnd(0, 360))
			var ini := _pos(quem) + Vector3(sin(h) * cos(a) * 5.0, sin(a) * 5.0 + 1.2, cos(h) * cos(a) * 5.0)
			var dist := maxf(ini.distance_to(fim), 0.1)
			var cor2 := Color(0.5, 0.5, _rnd(0.5, 1.0))
			# velocidade 0 subindo 4 por tick: n ticks andam 2 n (n + 1) unidades
			var cab := func(t: float) -> Vector3:
				var n: float = t / T
				return ini.lerp(fim, clampf(2.0 * n * (n + 1.0) / (dist * 100.0), 0.0, 1.0))
			cauda(ef, "jointenergy01", 0.1, cor2, 17 * T, 3, cab, {some = 0.35})
			ef.sprite("flare01", ini, 0.64, cor2, 17 * T, {some = 0.35,
				anda = func(p, _k): p.no.global_position = cab.call(p.t)}))


# Nova (40): solta (PLAYER_SKILL_HELL_START). Por (estagio + 1) ticks, 36 espiritos azuis
# (BITMAP_JOINT_SPIRIT tipo 6, somados) saem a 1 tile de altura em direcoes sorteadas,
# 50 unidades/tick acelerando 5/tick, 20 ticks; luz flare01 crescendo de 4 a 8; so 1 em 5
# deixa rastro. No ultimo tick, um anel regular de 36 (tipo 7, so luz) a 10/tick.
static func _nova(e: EfeitoMU, quem) -> void:
	var estagio := 12
	if quem is Node:
		var no := quem as Node
		if no.has_meta("nova_carga"):
			no.get_meta("nova_carga").ativo = false
			no.remove_meta("nova_carga")
		estagio = no.get_meta("nova_estagio", 12)
	var cor := Color(0.3, 0.3, 1)
	luz_chao(e, _pos(quem), cor, 5.0, (estagio + 20) * T)
	for tick in estagio + 1:
		if tick > 0:
			await e.get_tree().create_timer(T).timeout
			if not is_instance_valid(e):
				return
		var c := _pos(quem) + Vector3.UP
		for i in 36:
			_nova_raio(e, c, deg_to_rad(i * _rnd(10, 19)), v(50), cor, randi() % 5 == 0)
			if tick == estagio:
				_nova_raio(e, c, deg_to_rad(i * 10.0), v(10), cor, false)


static func _nova_raio(e: EfeitoMU, c: Vector3, ang: float, vel: float, cor: Color, rastro: bool) -> void:
	var sobe := deg_to_rad(10.0)
	var d := Vector3(sin(ang) * cos(sobe), sin(sobe), cos(ang) * cos(sobe))
	var a := v(5) / T
	e.sprite("flare01", c, 0.64 * 4, cor, 20 * T, {vel = d * vel, acel = d * a, tam1 = 0.64 * 8, some = 0.5, giro = _rnd(0, TAU)})
	if rastro:
		cauda(e, "jointspirit01", 0.6, cor, 20 * T, 5, func(t): return c + d * (vel * t + 0.5 * a * t * t), {some = 0.5})


# alvo morto pela Nova (m_byDieType): 30 ticks de faiscas azuis saindo dos ossos
# (BITMAP_LIGHT tipo 5: luz x0,9 e tamanho x0,95 por tick). O empurrao pra tras e do jogo.
static func _nova_morte(e: EfeitoMU, alvo) -> void:
	var b: Boneco = (alvo as Entidade).boneco if alvo is Entidade else null
	e.tarefa(T, 30 * T, func(ef, _i):
		if not _vivo(alvo):
			return
		var ossos := _ossos(b, 0, 32)
		for k in 10:
			var q := _pos_osso(b, ossos.pick_random()) if not ossos.is_empty() else _peito(alvo) + Vector3(_rnd(-0.3, 0.3), _rnd(-0.5, 0.5), _rnd(-0.3, 0.3))
			var tam := 0.64 * _rnd(0.5, 2.5)
			ef.sprite("flare01", q, tam, Color(0.3, 0.3, 1), 20 * T, {tam1 = tam * 0.36, some = 1.0}))


# --- Soul Barrier ---------------------------------------------------------------------

# Soul Barrier (16): 5 fitas flareBlue (MODEL_SPEARSKILL tipo 0) passeando em volta do alvo
# num Lissajous 3D (0,8 tile pros lados, 1,2 pra cima/baixo, centro a 1,2 de altura), rastro
# de 30 ticks que anda junto com o alvo. Largura 0,2 no gesto, 0,5 quando o buff entra
# (o cliente apaga e recria). Dura o buff: de queue_free no EfeitoMU quando o buff sair.
static func _barreira(e: EfeitoMU, alvo, dura := 60.0, largura := 0.5) -> void:
	if not _vivo(alvo):
		return
	for j in 5:
		var semente := randi() % 100000
		var rel: Array = []
		var st := {ult = -1.0}
		var ponto := func(t: float) -> Vector3:
			var f := t * 25.0
			if semente % 2 == 0:
				f = -f
			f += semente * 53731.0
			var a := sin((f + 55555.0) * 0.048)
			var tx := a * cos(f * 0.0613)
			var ty := a * sin(f * 0.0613)
			var tz := cos((f + 55555.0) * 0.048)
			var s2 := sin((f + 11111.0) * 0.1113)
			var c2 := cos((f + 11111.0) * 0.1113)
			var dx := c2 * ty - s2 * tz
			var dy := s2 * ty + c2 * tz
			# MU (x, y, z em cima) -> Godot (x, z, -y)
			return Vector3(dx * 0.8, 1.2 + tx * 1.2, -dy * 0.8)
		e.fita("flareblue", func():
			var c := _pos(alvo)
			return rel.map(func(q): return c + q)
		, null, largura, BRANCO, dura, {cauda = 1.0, some = 0.0, entra = 0.0,
			anda = func(p, _k):
				if not _vivo(alvo):
					p.t = p.vida
					return
				var h: Vector3 = ponto.call(p.t)
				if rel.is_empty() or p.t - st.ult >= T:
					rel.push_front(h)
					st.ult = p.t
					while rel.size() > 30:
						rel.pop_back()
				else:
					rel[0] = h})


# golpe num alvo com Soul Barrier, de um atacante virado pra ele (menos de 10 graus):
# Protect02 (MODEL_MAGIC_CAPSULE2), 20 ticks, apagando nos ultimos 10
static func barreira_golpe(pai: Node3D, alvo, atacante) -> void:
	if pai == null or not _vivo(alvo) or not _vivo(atacante):
		return
	var e := EfeitoMU.criar(pai)
	var d := _pos(atacante) - _pos(alvo)
	d.y = 0
	e.modelo("protect02", _pos(alvo), 0.9, BRANCO, 20 * T, {segue = alvo if typeof(alvo) == TYPE_OBJECT else null, dir = d, some = 0.5})


# --- Infinity Arrow -------------------------------------------------------------------

# Infinity Arrow (77), 40 ticks: ArrowSre02/03/04 no pe do elfo apagando (x0,95 por tick);
# ArrowSre05 na mao (osso 29) crescendo x1,2 por tick, 15 ticks; fitas flare02 laranja
# (BITMAP_FLARE+1 tipo 16) saindo da mao: 10 ticks subindo num circulo de 0,4 tile
# (7 unidades/tick, 10 graus/tick) e voltam pra mao. No cliente sao 8 por tick; aqui 8 a cada 2.
static func _flecha_infinita(e: EfeitoMU, quem, b: Boneco) -> void:
	var seg = quem if typeof(quem) == TYPE_OBJECT else null
	var mao := func() -> Vector3: return _osso(b, 29) if b else _peito(quem)
	for m in [["arrowsre02", ""], ["arrowsre03", ""], ["arrowsre04", "jointspirit03_t"]]:
		e.modelo(m[0], _pos(quem), 1.0, BRANCO, 40 * T, {segue = seg, tex = m[1], some = 0.9, ritmo = 0.3})
	e.modelo("arrowsre05", mao.call(), 1.0, Color(1, 0.5, 0.3), 15 * T, {tam1 = pow(1.2, 15), some = 1.0,
		anda = func(p, _k): if _vivo(quem): p.no.global_position = mao.call()})
	var frente: Vector3 = -(quem as Node3D).global_basis.z if quem is Node3D else Vector3.FORWARD
	var h0 := atan2(frente.x, frente.z)
	var w := deg_to_rad(10.0)
	var r := 0.07 / w
	e.tarefa(T * 2, 40 * T, func(ef, _i):
		if not _vivo(quem):
			return
		for k in 8:
			var a8 := TAU * k / 8.0
			var p0: Vector3 = mao.call() + Vector3(sin(a8) * 0.5, _rnd(-0.3, 0.3), cos(a8) * 0.5)
			var p10 := p0 + Vector3(r * (cos(h0 - w * 10) - cos(h0)), 0.25, r * (sin(h0) - sin(h0 - w * 10)))
			cauda(ef, "flare02", 0.2, Color(1, 0.5, 0.3), 35 * T, 8, func(t):
				var n: float = t / T
				if n <= 10.0:
					var th: float = h0 - w * n
					return p0 + Vector3(r * (cos(th) - cos(h0)), 0.025 * n, r * (sin(h0) - sin(th)))
				return p10.lerp(mao.call() if _vivo(quem) else p10, clampf((n - 10.0) / 6.0, 0.0, 1.0))
			, {some = 10.0 / 35.0}))


# --- Expansion of Wizardry ------------------------------------------------------------

# Expansion of Wizardry (233), 45 ticks: Magic_Powerup no mago (0,7; 0,4; 0,9) apagando nos
# ultimos 20; nos ticks 0, 10 e 20, 2 ShockWave (5 tiles, encolhendo 0,15/tick) e 1 TwLight
# (6 tiles, girando 10 graus/tick) no chao, 30 ticks; ArrowSre06 nas duas maos (40 ticks);
# 15 ticks de fantasmas roxos (2Line_Gost) espiralando pra dentro; nos ultimos 20 ticks,
# luz em todos os ossos apagando.
static func _expansao(e: EfeitoMU, quem, b: Boneco) -> void:
	var seg = quem if typeof(quem) == TYPE_OBJECT else null
	var roxo := Color(0.4, 0.3, 0.9)
	e.modelo("magic_powerup", _pos(quem), 0.9, Color(0.7, 0.4, 0.9), 45 * T, {segue = seg, some = 20.0 / 45.0, ritmo = 0.3})
	e.tarefa(10 * T, 20 * T, func(ef, _i):
		var q := _pos(quem)
		for s in 2:
			ef.chao("shockwave", q, 5.0, roxo, 30 * T, {tam1 = 0.5, entra = 0.33, some = 0.33, segue = seg})
		ef.chao("twlighthik01", q, 6.0, roxo, 30 * T, {tam1 = 1.5, entra = 0.33, some = 0.33, vgiro = deg_to_rad(10) / T, segue = seg}))
	_maos_arrowsre06(e, b)
	e.tarefa(T, 15 * T, func(ef, _i):
		for s in 2:
			_fantasma(ef, quem))
	e.tarefa(T, 45 * T, func(ef, i):
		if i < 25 or b == null or not is_instance_valid(b):
			return
		var k: float = (45 - i) * 0.05
		for o in _ossos(b):
			ef.sprite("flare01", _pos_osso(b, o), 0.64 * 1.5, Color(0.7 * k, 0.3 * k, 0.9 * k), T * 1.5, {some = 0.0}))


# ArrowSre06 nas maos (ossos 28 e 37): cresce x1,05/tick ate faltarem 15 ticks e encolhe
# (aqui um pulso ate 3x); azul (0,2; 0,2; 0,9); 40 ticks
static func _maos_arrowsre06(e: EfeitoMU, b: Boneco) -> void:
	if b == null or not is_instance_valid(b):
		return
	for osso in [28, 37]:
		e.modelo("arrowsre06", _osso(b, osso), 3.0, Color(0.2, 0.2, 0.9), 40 * T, {pulso = true, some = 0.25, ritmo = 0.3,
			anda = func(p, _k): if is_instance_valid(b): p.no.global_position = _osso(b, osso)})


# BITMAP_2LINE_GHOST tipo 1: nasce a 3 tiles, 2 a 3 de altura, 20 a 30 unidades/tick,
# indo 65 graus fora da linha pro centro (espiral pra dentro), 90 graus perto; 25 a 35 ticks
static func _fantasma(e: EfeitoMU, quem) -> void:
	var c0 := _pos(quem)
	var ang := _rnd(0, TAU)
	var st := {p = c0 + Vector3(sin(ang) * 3.0, _rnd(2, 3), cos(ang) * 3.0), t = 0.0}
	var alvo_y: float = st.p.y + _rnd(-1, 1)
	var vel := v(_rnd(20, 30))
	cauda(e, "2line_gost", _rnd(0.2, 0.3), Color(0.3, 0.2, 0.9), _rnd(25, 35) * T, 15, func(t):
		var dt: float = t - st.t
		st.t = t
		var para := Vector3(c0.x - st.p.x, 0, c0.z - st.p.z)
		if para.length() > 0.01:
			var d := para.normalized().rotated(Vector3.UP, deg_to_rad(65.0 if para.length() > 0.6 else 90.0))
			st.p += d * vel * dt
		st.p.y = move_toward(st.p.y, alvo_y, 1.0 * dt)
		return st.p
	, {some = 0.3})


# buff Expansion of Wizardry no ar: flare01 (1,8) em todos os ossos pulsando
# ((|sin t| + 0,2) / 2 x (0,7; 0,3; 0,9)); a cada 6 s, ArrowSre06 nas maos.
# Dura o buff: de queue_free no EfeitoMU quando o buff sair (ou o alvo ficar invisivel).
static func _expansao_aura(e: EfeitoMU, quem, b: Boneco, dura: float) -> void:
	if b == null or not is_instance_valid(b):
		return
	for k in _ossos(b):
		e.sprite("flare01", _pos_osso(b, k), 0.64 * 1.8, Color(0, 0, 0), dura, {some = 0.0,
			anda = func(p, _k):
				if not is_instance_valid(b):
					p.t = p.vida
					return
				p.no.global_position = _pos_osso(b, k)
				var l := (absf(sin(Time.get_ticks_msec() * 0.001)) + 0.2) * 0.5
				p.cor = Color(0.7 * l, 0.3 * l, 0.9 * l)})
	e.tarefa(6.0, dura, func(ef, i):
		if i > 0 and _vivo(quem):
			_maos_arrowsre06(ef, b))


# --- gladiador (Spiral Slash, Mana Rays, Flame Strike, Gigantic Storm) ---------------

# mao direita (osso 33): onde a arma encaixa
static func _mao(b: Boneco, quem) -> Vector3:
	if b and is_instance_valid(b):
		for r in b._rastros.values():
			if is_instance_valid(r) and is_instance_valid(r.arma):
				return r.arma.global_position
	return _pos(quem) + Vector3.UP * 1.1


# Spiral Slash (BITMAP_FLARE 23): 5 fitas de Flare varrendo 2 tiles em volta, em espiral.
# Chave 2 e 3 no quadro 2,3 do gesto (0,4 por tick), 0, 1 e 4 no quadro 5.
static func _espiral(e: EfeitoMU, quem, frente: Vector3) -> void:
	var a0 := atan2(frente.x, frente.z)
	for par in [[2, 6], [3, 6], [0, 13], [1, 13], [4, 13]]:
		_espiral_fita(e, quem, a0, par[0], par[1] * T)


static func _espiral_fita(e: EfeitoMU, quem, a0: float, chave: int, atraso: float) -> void:
	await e.get_tree().create_timer(atraso).timeout
	if not is_instance_valid(e) or not _vivo(quem):
		return
	var alt: float = [2.0, 0.1, 2.0, 0.1, 1.0][chave]
	var lado: float = [-1.0, -1.0, 1.0, 1.0, -1.0][chave]
	var inclina: float = deg_to_rad([3.0, -3.0, 3.0, -3.0, 0.0][chave])
	var centro := _pos(quem) + Vector3.UP * alt
	var vida := 24 - chave   # LifeTime: espera 4-chave, varre 12, encolhe 8
	var st := {yaw = a0 + deg_to_rad([90.0, 90.0, -90.0, -90.0, 180.0][chave]), pitch = 0.0, d1 = 5.0, d2 = 1.0, pts = [], tick = 0}
	var p := e.fita("flare", func(): return st.pts, null, 0.4, BRANCO, vida * T, {some = 10.0 / vida})
	p.anda = func(pp, _k):
		while st.tick < int(pp.t / T):
			st.tick += 1
			var resta: int = vida - st.tick
			if resta >= 20 or (resta < 8 and st.pts.is_empty()):
				continue
			if resta < 8:   # parou: cauda nova na cabeca, a fita encolhe ate ela
				st.pts.push_front(st.pts[0])
				if st.pts.size() > 14:
					st.pts.pop_back()
				continue
			for i in int(st.d2):
				st.d1 += 1.5
				st.yaw += deg_to_rad(st.d1) * lado
				st.pitch += inclina
				st.d1 = minf(st.d1, 15.0)
				st.pts.push_front(centro + Vector3(sin(st.yaw) * cos(st.pitch), -sin(st.pitch), cos(st.yaw) * cos(st.pitch)) * 2.0)
				if st.pts.size() > 14:
					st.pts.pop_back()
				if st.pts.size() >= 14:
					break
			st.d2 += 4.0


# Mana Rays (BITMAP_JOINT_FORCE 4): fita de Hole saindo a 1,3 de altura e acelerando,
# com saca-rolhas de flareBlue e brilho azul na cabeca a cada tick
static func _raios_de_mana(e: EfeitoMU, de: Vector3, frente: Vector3) -> void:
	await e.get_tree().create_timer(15 * T).timeout   # quadro 3 do gesto a 0,2 por tick
	if not is_instance_valid(e):
		return
	var ini := de + Vector3.UP * 1.3
	var lado := frente.cross(Vector3.UP)
	var azul := Color(0.1, 0.6, 1)
	var st := {d = 0.0, vel = 8.0, ac = 3.0}
	cauda(e, "hole", 0.4, BRANCO, 20 * T, 13, func(_t): return ini + frente * st.d / 100.0, {some = 0.5, cauda = 0.0})
	e.tarefa(T, 19 * T, func(ef, i):
		st.d += st.vel
		st.vel += st.ac
		st.ac += 15.5 if i <= 4 else 0.5
		if st.d > 1500.0:   # passou de 15 tiles: nao se ve mais
			return
		var q: Vector3 = ini + frente * st.d / 100.0
		ef.sprite("flare01", q, 0.64 * 1.6, azul, T, {some = 0.0})
		ef.sprite("shiny02", q, 0.32 * 1.5, azul, T, {giro = ef.t * 1.75, some = 0.0})
		var fase := _rnd(0, TAU)
		cauda(ef, "flareblue", 0.3, BRANCO, 15 * T, 15, func(t):
			var l := maxf(15.0 - t / T, 1.0)
			var k := fase + l * 0.8
			return q + frente * v(2) * t + lado * (-cos(k) * l * 0.02) + Vector3.UP * (sin(k) * l * 0.02)
		, {cauda = 0.0, some = 0.3}))


# Flame Strike (MODEL_EFFECT_FLAME_STRIKE): FlameStrike animado na mao (angulo 0, como no
# cliente), entra e sai em 10 ticks; malha 1 troca de linha da folha 4x4 a cada 0,2 s.
# Rastros motion_blur_r e Lava nos quadros 5 a 13 do gesto (0,69 por tick).
static func _golpe_de_chama(e: EfeitoMU, quem, b: Boneco) -> void:
	var mao := func() -> Vector3: return _mao(b, quem)
	e.modelo("flamestrike", mao.call(), 1.0, BRANCO, 25 * T, {ritmo = 0.69, entra = 0.4, some = 0.4,
		anda = func(pp, _k):
			pp.no.global_position = mao.call()
			if pp.has("mats") and pp.mats.size() > 1:
				(pp.mats[1] as ShaderMaterial).set_shader_parameter("uv_desl", Vector2(0, (int(pp.t / 0.2) % 4) * 0.25))})
	if b == null:
		return
	await e.get_tree().create_timer(5 / 17.25).timeout
	if not is_instance_valid(e) or not is_instance_valid(b):
		return
	b.rastro(8 / 17.25 + 0.3, BRANCO, "motion_blur_r")
	cauda(e, "lava", 0.6, BRANCO, 8 / 17.25 + 0.4, 12, func(_t): return b.ponta_arma() if is_instance_valid(b) else Vector3.ZERO, {some = 0.5})


# Gigantic Storm (BITMAP_JOINT_THUNDER efeito): 5 pontos a 2 tiles (72 graus, o 1o atras),
# 20 ticks de raios do ceu (8 tiles), Magic_Ground2, fumaca, pedras e energy02 no chao
static func _tempestade(e: EfeitoMU, de: Vector3, frente: Vector3) -> void:
	await e.get_tree().create_timer(13 * T).timeout   # quadro 7 do gesto a 0,55 por tick
	if not is_instance_valid(e):
		return
	var cor := Color(0.45, 0.45, 0.7)
	for i in 5:
		var q := de - frente.rotated(Vector3.UP, deg_to_rad(72.0 * i)) * 2.0
		q.y = _chao_em(e, q)
		var ceu := q + Vector3.UP * 8.0
		e.tarefa(T, 20 * T, func(ef, k):
			var a := q + Vector3(_rnd(-0.5, 0.5), 0, _rnd(-0.5, 0.5))
			if randf() < 0.5:
				ef.fita("jointthunder01", ceu + Vector3(_rnd(-0.5, 0.5), 0, _rnd(-0.5, 0.5)), a, _rnd(0.1, 0.5), BRANCO,
					_rnd(2, 3) * T, {raio = 0.3, pedacos = 16, some = 0.0})
			if k < 10 and randf() < 0.5:
				ef.chao("magic_ground2", a, 0.0, cor, 20 * T, {tam1 = 3.0, some = 0.25})
			if randf() < 0.25:
				var s := 0.64 * _rnd(2.8, 3.3)
				ef.sprite("smoke01", a, s, cor, 22 * T, {vel = Vector3.UP * v(8.7), tam1 = s * 1.25, giro = _rnd(0, TAU), some = 0.6})
			if randf() < 0.25:
				pedras(ef, q, 1)
			if k < 15 and randf() < 0.2:
				ef.chao("energy02", a, 1.5, Color(0.15, 0.15, 0.4), 30 * T, {some = 0.33}))




# --- Dark Lord ----------------------------------------------------------------------

static func _espera(e: EfeitoMU, s: float) -> bool:
	await e.get_tree().create_timer(s).timeout
	return is_instance_valid(e)


# modelo deitado no chao posto em pe virado pra d (Angle[0] = 90 do cliente)
static func _de_pe(d: Vector3) -> Basis:
	return Basis.looking_at(d, Vector3.UP) * Basis(Vector3.RIGHT, -PI / 2)


# MODEL_DARKLORD_SKILL: a estrela laranja que pisca na mao (2, cruzadas a 45 graus)
static func _estrela_dl(e: EfeitoMU, p: Vector3) -> void:
	for s in [1.0, -1.0]:
		e.modelo("darklordskill", p, 0.2, Color(1, 0.6, 0.3), 10 * T,
			{ritmo = 0.1, base = Basis(Vector3.RIGHT, deg_to_rad(45)) * Basis(Vector3.FORWARD, deg_to_rad(45) * s)})


# MODEL_WAVES: anel em pe que cresce acelerando (0,01 + 0,07 por tick) e apaga /1,5 por tick
static func _onda_dl(e: EfeitoMU, q: Vector3, base: Basis, s0: float, maximo: float, cresce: float, acel: float) -> void:
	e.modelo("m_waves", q, s0, BRANCO, 15 * T, {base = base, some = 0.0, anda = func(p, _k):
		var n: float = p.t / T
		p.tam0 = minf(s0 + cresce * n + acel * 0.5 * n * n, maximo)
		p.tam1 = p.tam0
		var l := pow(1.5, -n)
		p.cor = Color(l, l, l)})


# Force / Force Wave (60, 66): 2 ondas na frente, cada uma com 2 riscos (BITMAP_PIERCING)
# de 6 tiles, e o MODEL_PIERCING2 parado no corpo soltando aneis que crescem
static func _forca(e: EfeitoMU, de: Vector3, frente: Vector3) -> void:
	if not await _espera(e, 12 * T):
		return
	var base := _de_pe(frente)
	for i in 2:
		var q := de + Vector3(_rnd(-0.5, 0.5), 1.3 + _rnd(-0.5, 0.5), _rnd(-0.5, 0.5))
		_onda_dl(e, q, base, _rnd(0.1, 0.6), 2.0, 0.01, 0.07)
		for c in [Color(1, 0.8, 0.6), BRANCO]:
			e.fita("piercing", q, q + frente * 6.0, _rnd(0.7, 1.1), c, 10 * T, {some = 0.0,
				anda = func(p, _k): p.cor = c * pow(1.4, -p.t / T)})
	e.modelo("m_piercing", de + Vector3.UP * 1.0, 1.0, BRANCO, 20 * T, {base = base, some = 0.3})   # vida estimada
	e.tarefa(T, 15 * T, func(ef, i):
		_onda_dl(ef, de, base, (20 - i) * 0.05, 1.5, 0.0, 0.01))


# Fire Burst (61): 3 MODEL_PIER_PART saem da arma (+90, 0, -90 graus) e curvam ate o
# alvo cada vez mais rapido, deixando pecas menores e fogo; estrela na mao
static func _explosao_de_fogo(e: EfeitoMU, quem, b: Boneco, frente: Vector3, alvo) -> void:
	if not await _espera(e, 12 * T):
		return
	var mao: Vector3 = b.ponta_arma() if b else _pos(quem) + Vector3.UP * 1.2
	_estrela_dl(e, mao)
	var sts := []
	for i in 3:
		var alto := 2.0 if i == 0 else 1.0   # topo do alvo (BoundingBoxMax) ou metade
		var st := {q = mao, d = frente.rotated(Vector3.UP, deg_to_rad([90.0, 0.0, -90.0][i])), ult = 0.0, chegou = false}
		sts.append(st)
		e.modelo("pierpart", mao, 1.2, BRANCO, 20 * T, {dir = st.d, some = 0.15, anda = func(p, _k):
			var dt: float = p.t - st.ult
			st.ult = p.t
			var meta := _pos(alvo).lerp(_peito(alvo), alto)
			var falta: Vector3 = meta - st.q
			if falta.length() < 0.3:
				st.chegou = true
			if not st.chegou:
				st.d = (st.d as Vector3).lerp(falta.normalized(), minf(1.0, dt / (3 * T))).normalized()
				st.q += st.d * minf(v(26) * (2.0 + 0.1 * p.t / T) * dt, falta.length())
			p.no.global_position = st.q
			p.base = Basis.looking_at(st.d, Vector3.UP)})
	e.tarefa(T, 20 * T, func(ef, _i):
		for st in sts:
			if st.chegou:
				continue
			ef.modelo("pierpart", st.q, 0.5, BRANCO, 10 * T, {dir = st.d, entra = 0.3, some = 0.5})
			ef.sprite("fire02", st.q, _rnd(0.4, 0.7), BRANCO, 15 * T, {vel = Vector3(0, 0.5, 0), giro = _rnd(0, TAU), tam1 = 0.1}))


# Earthshake (62, so no Dark Horse): o cavalo empina (acao 3), onda de choque no chao
# a cada 10 ticks, aneis de pedra que sobem na batida das patas, tremor e o chao rachando
static func _terremoto(e: EfeitoMU, quem, frente: Vector3) -> void:
	var de := _pos(quem)
	e.tarefa(10 * T, 20 * T, func(ef, _i):
		var c := _pos(quem)
		c.y = _chao_em(ef, c)
		ef.chao("shockwave", c, 20.0, BRANCO, 20 * T, {tam1 = 0.5, some = 0.3}))
	if not await _espera(e, 10 * T):
		return
	_furia(e, de, frente)   # MODEL_SKILL_FURY_STRIKE tipo 2 aos 19 ticks (_furia espera 9)
	if not await _espera(e, 13 * T):
		return
	e.tarefa(T, 6 * T, func(ef, i):
		if randf() < 0.5:
			return
		var r: float = 0.75 * i
		var a0 := _rnd(0, TAU)
		for k in 6:
			var a := a0 + TAU * k / 6.0
			_pedra_do_chao(ef, _pos(quem) + Vector3(sin(a), 0, cos(a)) * r))
	_tremer(e, 20 * T, 0.08)


# MODEL_GROUND_STONE / GROUND_STONE2: sobe do chao, fumaca e pedrinhas no 5o tick
static func _pedra_do_chao(e: EfeitoMU, q: Vector3) -> void:
	q.y = _chao_em(e, q)
	var dois := randf() < 0.5
	e.modelo("groundstone2" if dois else "groundstone", q, _rnd(1.0, 1.3) if dois else _rnd(1.2, 1.5), BRANCO, 40 * T,
		{solido = true, ritmo = 0.3, giro = _rnd(0, TAU), some = 0.0})
	luz_chao(e, q, Color(0.79, 0.72, 0.49), 1.0, 40 * T)
	var atraso := _rnd(4, 7) * T
	e.tarefa(atraso, atraso, func(ef, i):
		if i == 1:
			fumaca(ef, q + Vector3.UP * 0.3, Color(0.5, 0.45, 0.4), 1.0, 1.0, Vector3(0, 0.5, 0))
			pedras(ef, q, 3))


# EarthQuake do cliente: a camera treme
static func _tremer(e: EfeitoMU, dura: float, forca: float) -> void:
	var cam := e.get_viewport().get_camera_3d()
	if cam == null:
		return
	e.tarefa(T, dura, func(_ef, i):
		if not is_instance_valid(cam):
			return
		var fim: bool = i >= int(dura / T)
		cam.h_offset = 0.0 if fim else _rnd(-forca, forca)
		cam.v_offset = 0.0 if fim else _rnd(-forca, forca))


# Summon (63, PARTY_TELEPORT): circulo magico azul no chao por 10 s (MODEL_CIRCLE 2 com
# Magic_b e MODEL_CIRCLE_LIGHT 3 correndo a textura), fagulhas azuis subindo e fitas
# azuis que caem de 6 tiles
static func _invocar_grupo(e: EfeitoMU, de: Vector3) -> void:
	if not await _espera(e, 5 * T):
		return
	var c := de
	c.y = _chao_em(e, c) + 0.05
	e.modelo("circle01", c, 1.0, Color(0.5, 0.5, 1), 250 * T, {tex = "magic_b", entra = 0.04, some = 0.04})
	e.modelo("circle02", c, 1.0, Color(0.05, 0.05, 1), 250 * T, {entra = 0.04, some = 0.04, uv_vel = Vector2(0, -0.25)})
	e.tarefa(T, 220 * T, func(ef, i):
		if randf() < 0.5:
			return
		var a := _rnd(0, TAU)
		var q := c + Vector3(sin(a), 0, cos(a)) * _rnd(0, 2)
		ef.sprite("flareblue", q, 0.64 * 0.2, BRANCO, _rnd(30, 40) * T, {acel = Vector3(0, 2.5, 0), some = 0.4})
		if i < 210:
			var vida := _rnd(25, 75) * T
			var cai := vida - 25 * T
			var v0 := v(_rnd(35, 55))
			var cab := func(t: float) -> Vector3:
				var s := maxf(t - cai, 0.0)
				return q + Vector3.UP * maxf(6.0 - v0 * s - 0.5 * v(5) / T * s * s, 0.0)
			cauda(ef, "flareblue", 0.4, BRANCO, vida, 10, cab, {some = 0.3}))


# Increase Critical Damage (64): estrela nas duas maos e a aura do buff
static func _critico(e: EfeitoMU, quem, b: Boneco) -> void:
	if not await _espera(e, 8 * T):
		return
	for q in ([b.ponta_arma(), _osso(b, 37)] if b else [_peito(quem)]):
		_estrela_dl(e, q)
	_aura_critico(e, quem, b, 6.0)


# aura do buff (BITMAP_FLARE_FORCE 1): a cada 1,2 s, 5 a 7 riscos de Fire04 saem da arma
# enrolando; 1 em 20 vem com a estrela. 'dura': o tempo do buff que o servidor mandou
static func aura_critico(pai: Node3D, quem: Entidade, dura: float) -> void:
	_aura_critico(EfeitoMU.criar(pai), quem, quem.boneco, dura)


static func _aura_critico(e: EfeitoMU, quem, b: Boneco, dura: float) -> void:
	e.tarefa(1.2, dura, func(ef, _i):
		if not _vivo(quem):
			return
		var mao: Vector3 = b.ponta_arma() if b and is_instance_valid(b) else _peito(quem)
		for k in randi_range(5, 7):
			var d := Vector3(_rnd(-1, 1), _rnd(-0.3, 1), _rnd(-1, 1)).normalized()
			var eixo := d.cross(Vector3.UP).normalized() if absf(d.y) < 0.95 else Vector3.RIGHT
			var giro := _rnd(8, 14) * (1 if randf() < 0.5 else -1)
			cauda(ef, "fire04", 0.2, BRANCO, 15 * T, 10, func(t):
				return mao + d.rotated(eixo, giro * t * 0.3) * t * 2.0)
		if randi() % 20 == 0:
			_estrela_dl(ef, mao))


# Electric Spike (65): raio largo de JointThunder01 que sai na frente do peito e corre
# 9 tiles em 6 ticks, com 4 espirais finas fechando em volta
static func _lanca_eletrica(e: EfeitoMU, de: Vector3, frente: Vector3) -> void:
	if not await _espera(e, 14 * T):
		return
	var o := de + frente * 0.9 + Vector3.UP * 1.0
	var cor := Color(1, 0.8, 1)
	var lado := frente.cross(Vector3.UP)
	# passos dados ate o tick n: 0, 2, 4, 6... por tick; o passo k anda 3 + 2k unidades
	var passos := func(n: float) -> float: return maxf(n * (n - 1.0), 0.0)
	var longe := func(s: float) -> float: return minf((s * s + 2.0 * s) / 100.0, 9.6)
	e.fita("jointthunder01", o, o, 2.5, cor, 20 * T, {cauda = 1.0, some = 0.5,
		anda = func(p, _k): p.fita[0] = o + frente * longe.call(passos.call(p.t / T))})
	for s in 4:
		var fase: float = [PI, PI, 0.0, 0.0][s]
		var sinal: float = [1.0, -1.0, 1.0, -1.0][s]
		var atraso := _rnd(2, 4) * T if s < 2 else 0.0
		var st := {pts = []}
		e.fita("jointthunder01", func(): return st.pts, null, 1.0, cor, 20 * T + atraso, {some = 0.5,
			anda = func(p, _k):
				var ate := mini(int(passos.call(maxf(p.t - atraso, 0.0) / T)), 32)
				st.pts = []
				for k in range(ate, maxi(ate - 30, 0) - 1, -1):
					var a := fase + sinal * deg_to_rad(20.0 * k)
					var r := maxf(0.8 - 0.025 * k, 0.0)
					st.pts.append(o + frente * longe.call(float(k)) + (lado * cos(a) + Vector3.UP * sin(a)) * r)})


# Abolish Magic (72, REMOVAL_BUFF): 6 fitas de Flare02 que giram em volta fechando de 8
# tiles ate o corpo, sobem juntas e abrem de novo, com onda de choque no meio
static func _abolir(e: EfeitoMU, de: Vector3) -> void:
	if not await _espera(e, 10 * T):
		return
	var cores := [Color(1, 1, 0.8), Color(1, 0.8, 1), Color(0.8, 1, 1)]
	var angs := [45.0, 135.0, 225.0, 90.0, 180.0, 270.0]
	var alts := [1.0, 0.9, 0.8, 0.8, 0.7, 0.6]
	for j in 6:
		var sub := j % 3   # SPEARSKILL 5, 6, 7: so 5 e 6 soltam a onda
		var st := {pts = [], ang = deg_to_rad(angs[j]), r = 8.0, w = 0, c = de + Vector3.UP * alts[j], larg = 1.7, n = 0}
		e.fita("flare02", func(): return st.pts, null, 1.7, cores[sub], 60 * T, {cauda = 1.0, some = 10.0 / 60.0,
			anda = func(p, _k):
				while st.n < int(p.t / T):
					st.n += 1
					for i in 3:
						st.ang += deg_to_rad(10)
						st.pts.push_front(st.c + Vector3(sin(st.ang), 0, cos(st.ang)) * st.r)
						if st.pts.size() > 30:
							st.pts.pop_back()
						if st.w == 0:
							st.r *= 0.95
							if st.r < 0.1:
								st.r = -0.1
						if st.w > 40:
							st.r -= 0.2
							st.ang -= deg_to_rad(5)
							st.larg += 0.15
						if st.r < 0:
							if st.w == 40 and sub < 2:
								e.chao("shockwave", Vector3(de.x, _chao_em(e, de), de.z), 1.0, cores[sub], 15 * T, {tam1 = 31.0, some = 0.5})
							st.w += 1
							if st.w < 20:
								st.r = -0.3
								st.larg = 0.4
							else:
								st.c.y += 0.05
					st.larg -= 0.05
				p.fita[2] = maxf(st.larg, 0.05)})


# Fire Blast (74, SPACE_SPLIT): MODEL_PIER_PART 2 rasga o chao ate o alvo e a cada 3
# ticks solta uma labareda de Inferno que sobe
static func _rasgo(e: EfeitoMU, de: Vector3, frente: Vector3, alvo) -> void:
	if not await _espera(e, 12 * T):
		return
	var st := {q = de - Vector3.UP * 0.2, d = frente, ult = 0.0}
	e.modelo("pierpart", st.q, 1.0, BRANCO, 20 * T, {dir = frente, some = 0.15, anda = func(p, _k):
		var dt: float = p.t - st.ult
		st.ult = p.t
		var falta := _pos(alvo) - (st.q as Vector3)
		falta.y = 0
		if falta.length() > 0.3:
			st.d = (st.d as Vector3).lerp(falta.normalized(), minf(1.0, dt * (50.0 + 2.4 * p.t / T) / 90.0 / T)).normalized()
		st.q += st.d * v(40) * dt
		st.q.y = _chao_em(e, st.q) - 0.2
		p.no.global_position = st.q
		p.base = Basis.looking_at(st.d, Vector3.UP)})
	e.tarefa(3 * T, 20 * T, func(ef, _i): _labareda(ef, st.q, st.d))


# BITMAP_JOINT_FORCE 2: fita de Inferno que sobe acelerando (3,5 por tick nos 5 primeiros)
static func _labareda(e: EfeitoMU, q: Vector3, d: Vector3) -> void:
	var cab := func(t: float) -> Vector3:
		var n := t / T
		var sobe := n + 1.75 * n * (n - 1) if n <= 5 else 40.0 + (n - 5) * 18.5 + 0.25 * (n - 5) * (n - 6)
		return q + d * v(8) * t + Vector3.UP * sobe / 100.0
	cauda(e, "inferno", 1.5, BRANCO, 20 * T, 12, cab, {some = 0.25})


# Fire Scream (78): 3 trilhas (meio e +-10 graus) de MODEL_DARK_SCREAM e
# MODEL_DARK_SCREAM_FIRE rentes ao chao, soltando chamas e um rastro de Inferno
static func _grito_de_fogo(e: EfeitoMU, de: Vector3, frente: Vector3) -> void:
	if not await _espera(e, 12 * T):
		return
	var lado := frente.cross(Vector3.UP)
	for faixa in [[0.0, 0.0], [0.8, 10.0], [-0.8, -10.0]]:
		var d: Vector3 = frente.rotated(Vector3.UP, deg_to_rad(faixa[1]))
		var ini: Vector3 = de + lado * faixa[0] + frente * 0.6
		var onde := func(t: float) -> Vector3:
			var q: Vector3 = ini + d * v(35) * minf(t, 19 * T)
			q.y = _chao_em(e, q) + 0.03
			return q
		for m in [["darkfirescrem02", 0.9, 0.04], ["darkfirescrem01", 2.3, 0.14]]:
			e.modelo(m[0], ini, m[1], BRANCO, 19 * T, {dir = d, tam1 = maxf(m[1] - m[2] * 19, 0.0), some = 0.2,
				anda = func(p, _k): p.no.global_position = onde.call(p.t)})
		cauda(e, "inferno", 1.5, BRANCO, 20 * T + 19 * T, 13, func(t): return onde.call(t), {some = 0.5})
		e.tarefa(T, 19 * T, func(ef, i):
			var q: Vector3 = onde.call(i * T)
			for m in [[0.9, 0.04], [2.3, 0.14]]:
				var s := maxf(m[0] - m[1] * i, 0.0)
				var tam := maxf(s - 0.4, 0.05) * 3.5 * 0.64
				ef.sprite("flame01", q, tam, Color(0.6, 0.6, 0.6), 33 * T,
					{vel = Vector3.UP * v(_rnd(1.8, 2.8) * s), tam1 = tam * 0.2, giro = _rnd(0, TAU), some = 0.5}))


# Chaotic Diseier (238): brilho na lamina e no corpo, 8 fantasmas (2Line_Gost
# subtraindo) que serpenteiam pra frente, 2 em 3 com a cabeca de Desair, e o estouro no alvo
static func _caotico(e: EfeitoMU, quem, b: Boneco, frente: Vector3, alvo) -> void:
	var de := _pos(quem)
	if b:
		_brilho_lamina(e, b, 238)
		var ossos := _ossos(b)
		for i in 5:
			if not ossos.is_empty():
				e.sprite("shiny05", _pos_osso(b, ossos.pick_random()), 2.0 * 0.64, Color(0.5, 0.5, 0.5), 10 * T, {giro = _rnd(0, TAU)})
	for i in 8:
		var vida: int = 67 if randf() < 0.5 else 75
		var vel := v(_rnd(40, 60))
		var st := {q = de + Vector3(_rnd(-1.19, 1.21), _rnd(0.49, 1.09), 0), d = frente, n = 0}
		var cabeca := func(t: float) -> Vector3:
			while st.n < int(t / T):
				st.n += 1
				var resta: int = vida - st.n
				st.d = (st.d as Vector3).rotated(Vector3.UP, deg_to_rad(10.0 if resta % 16 <= 7 else -10.0))
				st.q += st.d * vel * T
			return st.q + st.d * vel * (t - st.n * T)
		cauda(e, "2line_gost", _rnd(0.21, 2.2), BRANCO, vida * T, 26, cabeca, {menos = true, cauda = 0.0, some = 0.2})
		if randi() % 3 < 2:
			e.modelo("desair", st.q, 1.0, BRANCO, vida * T, {solido = true, some = 0.0, anda = func(p, _k):
				p.no.global_position = cabeca.call(p.t)
				p.base = Basis.looking_at(st.d, Vector3.UP)})
		e.tarefa(2 * T, vida * T, func(ef, _i): fumaca(ef, st.q, Color(0.3, 0.3, 0.3), 0.4, 0.6))
	if _vivo(alvo) and typeof(alvo) == TYPE_OBJECT:
		var p := _pos(alvo) + Vector3.UP * 0.8
		explosao(e, p, 1.6)
		_faiscas(e, p, 20, BRANCO)
