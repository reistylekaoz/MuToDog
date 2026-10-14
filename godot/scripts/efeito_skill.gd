class_name EfeitoSkill
# Efeitos das skills no jeito do cliente S6 (MuMain: SkillCast.cpp, ZzzCharacter.cpp
# AttackStage, ZzzEffect.cpp, ZzzEffectJoint.cpp), com as texturas e modelos dele
# (dados/efeitos, conversor efeitos). As contas do cliente sao em ticks de 25 por
# segundo e 100 unidades por tile: T e um tick, v() passa unidades/tick pra tiles/s.
# Uso: EfeitoSkill.criar(mundo, numero, quem, alvo, area): quem e alvo sao Node3D
# (Entidade) ou Vector3 (ponto no chao).

const T := 0.04
const BRANCO := Color(1, 1, 1)
const MAGIA := [1, 2, 3, 4, 5, 7, 8, 9, 10, 12, 13, 14, 17, 38, 39]
const ESPADA := [19, 20, 21, 22, 23, 41, 42, 43, 47, 55, 56]


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
		e.tarefa(T * 2, tempo, func(ef, _i):
			if not EfeitoMU.voando(n):
				return
			var q := n.global_position
			ef.sprite("shiny02", q, 0.32 * _rnd(0.8, 1.4) * 2, Color(0.7, 0.8, 1), T * 3, {giro = _rnd(0, TAU)})
			ef.sprite("flare01", q, 0.64, Color(0.4, 0.6, 1), T * 3))
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


# Death Stab: fitas vermelhas que se juntam na ponta e o alvo tomando choque
static func _estocada(e: EfeitoMU, quem, b: Boneco, frente: Vector3, alvo) -> void:
	var ponta := func(): return b.ponta_arma() if b and is_instance_valid(b) else _pos(quem) + Vector3.UP * 1.2
	var foco: Vector3 = _pos(quem) + Vector3.UP * 1.2 + frente * 3.0
	for i in 6:
		var ini := _pos(quem) - frente * _rnd(6, 10) + frente.cross(Vector3.UP) * _rnd(-3, 3) + Vector3.UP * 1.2
		var bambo := Vector3(_rnd(-1, 1), _rnd(-0.5, 0.5), _rnd(-1, 1))
		cauda(e, "nskill", 0.6, Color(1, 0.3, 0.3), 10 * T + i * T, 5, func(t):
			var k := clampf(t / (10 * T), 0, 1)
			return ini.lerp(foco, k) + bambo * sin(k * PI))
	await e.get_tree().create_timer(6 * T).timeout
	if not is_instance_valid(e):
		return
	for lado in [0.0, PI]:
		var base: Vector3 = ponta.call()
		cauda(e, "flare", 1.0, Color(0.1, 0.1, 1), 70 * T * 0.5, 25, func(t):
			var a: float = lado + t * 12.0
			return base + frente * v(4) * t * 2 + frente.cross(Vector3.UP) * cos(a) * 0.26 + Vector3.UP * (sin(a) * 0.26 - t * 0.3))
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
