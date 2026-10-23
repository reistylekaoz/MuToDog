class_name EfeitoMU
extends Node3D
# Pecas dos efeitos de skill no jeito do cliente (ZzzEffect, ZzzEffectJoint, sprites):
# sprite virado pra camera, marca no chao, fita entre dois pontos (raio, laser, espirito),
# modelo do Data/Skill somado, e tarefas que soltam pecas por um tempo. Texturas e
# modelos em dados/efeitos/ (conversor efeitos). Unidades do Godot: 1 = 1 tile = 100 do MU.
# O no some sozinho quando nao sobra peca nem tarefa.

const PASTA := "res://dados/efeitos/"
const SHADER := preload("res://scripts/efeito.gdshader")
const SHADER_MENOS := preload("res://scripts/efeito_menos.gdshader")
const SHADER_ALFA := preload("res://scripts/efeito_alfa.gdshader")
static var _tex := {}
static var _modelos := {}
static var _quad: QuadMesh
static var _plano: PlaneMesh

var pecas: Array[Dictionary] = []
var tarefas: Array[Dictionary] = []
var t := 0.0


static func criar(pai: Node) -> EfeitoMU:
	var e := EfeitoMU.new()
	pai.add_child(e)
	return e


static func textura(nome: String) -> Texture2D:
	if not _tex.has(nome):
		var c := PASTA + "tex/" + nome + ".png"
		_tex[nome] = load(c) if ResourceLoader.exists(c) else null
		if _tex[nome] == null:
			push_warning("efeito sem textura " + nome)
	return _tex[nome]


static func _material(tex: String, cor: Color, modo: int, menos := false, alfa := false) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SHADER_ALFA if alfa else SHADER_MENOS if menos else SHADER
	m.set_shader_parameter("tex", textura(tex))
	m.set_shader_parameter("cor", cor)
	m.set_shader_parameter("modo", modo)
	return m


# peca nova; o resto dos campos (vel, acel, tam1, vgiro, segue...) vem em op
func _peca(no: MeshInstance3D, mat: ShaderMaterial, pos: Vector3, tam: float, cor: Color, vida: float, op: Dictionary) -> Dictionary:
	no.material_override = mat
	add_child(no)
	no.global_position = pos
	var p := {
		no = no, mat = mat, vida = vida, t = 0.0, cor = cor, tam0 = tam, tam1 = op.get("tam1", tam),
		vel = op.get("vel", Vector3.ZERO), acel = op.get("acel", Vector3.ZERO), giro = op.get("giro", 0.0),
		vgiro = op.get("vgiro", 0.0), some = op.get("some", 1.0), entra = op.get("entra", 0.0),
		segue = op.get("segue"), desl = op.get("desl", Vector3.ZERO), uv_vel = op.get("uv_vel", Vector2.ZERO),
		anda = op.get("anda", Callable()), pulso = op.get("pulso", false),
		quadros = op.get("quadros", 0), colunas = op.get("colunas", op.get("quadros", 1)), linhas = op.get("linhas", 0), achata = op.get("achata", 1.0),
	}
	if p.segue != null and is_instance_valid(p.segue):
		p.desl = pos - (p.segue as Node3D).global_position
	pecas.append(p)
	_atualizar(p, 0.0)
	return p


# sprite (CreateSprite / CreateParticle): quadrado virado pra camera
func sprite(tex: String, pos: Vector3, tam: float, cor: Color, vida: float, op := {}) -> Dictionary:
	if _quad == null:
		_quad = QuadMesh.new()
	var no := MeshInstance3D.new()
	no.mesh = _quad
	no.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return _peca(no, _material(tex, cor, 0, op.get("menos", false), op.get("alfa", false)), pos, tam, cor, vida, op)


# marca deitada no chao (Magic_Ground, anel de onda), girando em volta do eixo vertical
func chao(tex: String, pos: Vector3, tam: float, cor: Color, vida: float, op := {}) -> Dictionary:
	if _plano == null:
		_plano = PlaneMesh.new()
		_plano.size = Vector2.ONE
	var no := MeshInstance3D.new()
	no.mesh = _plano
	no.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var p := _peca(no, _material(tex, cor, 1), pos + Vector3.UP * 0.03, tam, cor, vida, op)
	p.deitado = true
	return p


# fita entre dois pontos (CreateJoint): virada pra camera, de largura fixa.
# de e para: Vector3, Node3D (segue) ou Callable que devolve Vector3.
# op.raio > 0: quebra em pedacos tremendo (relampago); op.uv_vel corre a textura.
func fita(tex: String, de, para, largura: float, cor: Color, vida: float, op := {}) -> Dictionary:
	var no := MeshInstance3D.new()
	no.mesh = ImmediateMesh.new()
	no.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var p := _peca(no, _material(tex, cor, 1, op.get("menos", false)), Vector3.ZERO, 1.0, cor, vida, op)
	no.global_position = Vector3.ZERO
	p.fita = [de, para, largura, op.get("raio", 0.0), op.get("pedacos", 8)]
	p.cauda = op.get("cauda", 0.0)   # 1: apaga ate o fim da fita
	_desenhar_fita(p)
	return p


# modelo do Data/Skill (Fire01, Storm01, EarthQuake01...) somado como no cliente
func modelo(nome: String, pos: Vector3, tam: float, cor: Color, vida: float, op := {}) -> Dictionary:
	var cena: PackedScene = _modelos.get(nome)
	if cena == null and ResourceLoader.exists(PASTA + nome + ".glb"):
		cena = load(PASTA + nome + ".glb")
		_modelos[nome] = cena
	if cena == null:
		push_warning("efeito sem modelo " + nome)
		return _peca(MeshInstance3D.new(), _material("flare01", cor, 1), pos, tam, cor, 0.01, op)
	var m: Node3D = cena.instantiate()
	m.rotation_degrees = Vector3(-90, 180, 0)
	m.scale = Vector3.ONE * 0.01
	return no_pronto(m, pos, tam, cor, vida, op)


# um no ja montado (a arma de quem soltou, no Twisting Slash) vira peca somada
func no_pronto(m: Node3D, pos: Vector3, tam: float, cor: Color, vida: float, op := {}) -> Dictionary:
	var raiz := MeshInstance3D.new()   # no vazio que segura o modelo (tam e giro mexem nele)
	raiz.add_child(m)
	var mats: Array[ShaderMaterial] = []
	var tex_nome: String = op.get("tex", "")
	var soma: Array = op.get("soma", [])   # malhas somadas (BlendMesh); vazio: todas
	var lista: Array = m.find_children("*", "MeshInstance3D", true, false)
	if m is MeshInstance3D:
		lista.append(m)
	var i := 0
	if op.get("solido", false):
		lista = []
	for mi: MeshInstance3D in lista:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.material_overlay = null
		for s in mi.mesh.get_surface_count():
			var orig := mi.get_active_material(s)
			if not soma.is_empty() and i not in soma:
				i += 1
				continue
			i += 1
			var sm := ShaderMaterial.new()
			sm.shader = SHADER
			var tx: Texture2D = textura(tex_nome) if tex_nome != "" else (orig.albedo_texture if orig is BaseMaterial3D else null)
			sm.set_shader_parameter("tex", tx)
			sm.set_shader_parameter("cor", cor)
			sm.set_shader_parameter("modo", 1)
			mi.set_surface_override_material(s, sm)
			mats.append(sm)
	var ap: Array = m.find_children("*", "AnimationPlayer", true, false)
	if not ap.is_empty() and ap[0].has_animation("anda"):
		ap[0].get_animation("anda").loop_mode = Animation.LOOP_LINEAR
		ap[0].play("anda", -1, op.get("ritmo", 0.25) * 25.0)
	var p := _peca(raiz, null, pos, tam, cor, vida, op)
	raiz.material_override = null
	p.mats = mats
	p.base = op.get("base", Basis.IDENTITY)
	if op.has("dir") and (op.dir as Vector3).length() > 0.001:
		p.base = Basis.looking_at(op.dir, Vector3.UP if absf((op.dir as Vector3).normalized().y) < 0.99 else Vector3.FORWARD)
	_atualizar(p, 0.0)
	return p


# chama f(efeito, i) a cada intervalo, de agora ate 'dura' segundos
func tarefa(intervalo: float, dura: float, f: Callable) -> void:
	tarefas.append({a_cada = intervalo, prox = t, ate = t + dura, f = f, i = 0})


# move 'no' (ou um Node3D novo) de 'de' ate 'para' em 'tempo'; ao_chegar(pos) no fim
func voar(de: Vector3, para: Vector3, tempo: float, ao_chegar: Callable = Callable()) -> Node3D:
	var n := Node3D.new()
	add_child(n)
	n.global_position = de
	var tw := n.create_tween()
	tw.tween_property(n, "global_position", para, maxf(tempo, 0.01))
	# chegou: fica parado e marcado (as tarefas param), some junto com o efeito
	tw.tween_callback(func():
		n.set_meta("chegou", true)
		if ao_chegar.is_valid():
			ao_chegar.call(para))
	return n


static func voando(n) -> bool:
	return is_instance_valid(n) and not (n as Node).has_meta("chegou")


func _process(d: float) -> void:
	t += d
	for ta in tarefas.duplicate():
		while ta.prox <= t and ta.prox <= ta.ate:
			ta.f.call(self, ta.i)
			ta.i += 1
			ta.prox += ta.a_cada
		if ta.prox > ta.ate:
			tarefas.erase(ta)
	for p in pecas.duplicate():
		p.t += d
		if p.t >= p.vida or (p.segue != null and not is_instance_valid(p.segue)):
			p.no.queue_free()
			pecas.erase(p)
			continue
		_atualizar(p, d)
	# as skills esperam o gesto antes da primeira peca: so some depois de 1,5 s
	if pecas.is_empty() and tarefas.is_empty() and t > 1.5:
		queue_free()


func _atualizar(p: Dictionary, d: float) -> void:
	var k: float = clampf(p.t / p.vida, 0.0, 1.0)
	p.vel += p.acel * d
	var no: MeshInstance3D = p.no
	if p.segue != null and is_instance_valid(p.segue):
		p.desl += p.vel * d
		no.global_position = (p.segue as Node3D).global_position + p.desl
	else:
		no.global_position += p.vel * d
	p.giro += p.vgiro * d
	var tam: float = lerpf(p.tam0, p.tam1, k)
	if p.pulso:
		tam = p.tam0 * sin(k * PI)
	if p.anda.is_valid() and d > 0.0:
		p.anda.call(p, k)
	# alfa: entra (fracao da vida subindo) e some (fracao final descendo)
	var a := 1.0
	if p.entra > 0.0 and k < p.entra:
		a = k / p.entra
	if p.some > 0.0 and k > 1.0 - p.some:
		a = minf(a, (1.0 - k) / p.some)
	var c: Color = p.cor
	c.a *= a
	if p.has("mats"):
		no.basis = Basis(Vector3.UP, p.giro) * p.base * Basis.from_scale(Vector3.ONE * tam)
		for m: ShaderMaterial in p.mats:
			m.set_shader_parameter("cor", c)
			if p.uv_vel != Vector2.ZERO:
				m.set_shader_parameter("uv_desl", p.uv_vel * p.t)
		return
	if p.mat == null:
		return
	p.mat.set_shader_parameter("cor", c)
	if p.uv_vel != Vector2.ZERO:
		p.mat.set_shader_parameter("uv_desl", p.uv_vel * p.t)
	if p.quadros > 0:
		# textura com varios quadros em grade (Explotion01 4x4, Fire03 4x1): corre pela vida
		var q: int = mini(int(k * p.quadros), p.quadros - 1)
		var col: int = p.colunas
		var lin: int = p.linhas if p.linhas > 0 else ceili(float(p.quadros) / col)
		p.mat.set_shader_parameter("uv_esc", Vector2(1.0 / col, 1.0 / lin))
		p.mat.set_shader_parameter("uv_desl", Vector2(float(q % col) / col, float(q / col) / lin))
	if p.has("fita"):
		_desenhar_fita(p)
	elif p.get("deitado", false):
		no.basis = Basis(Vector3.UP, p.giro) * Basis.from_scale(Vector3(tam, 1.0, tam * p.achata))
	else:
		p.mat.set_shader_parameter("giro", p.giro)
		no.basis = Basis.from_scale(Vector3(tam, tam * p.achata, tam))


static func _ponto(x) -> Vector3:
	if typeof(x) == TYPE_OBJECT:
		return (x as Node3D).global_position if is_instance_valid(x) else Vector3.ZERO
	if x is Callable:
		return x.call()
	return x


func _desenhar_fita(p: Dictionary) -> void:
	var f: Array = p.fita
	var im: ImmediateMesh = p.no.mesh
	im.clear_surfaces()
	var pts: Array[Vector3] = []
	if f[0] is Callable and f[1] == null:
		# fita por uma lista de pontos (rastro de cauda, leque): f[0].call() -> Array
		for q in f[0].call():
			pts.append(q)
		if pts.size() < 2:
			return
	else:
		var a := _ponto(f[0])
		var b := _ponto(f[1])
		var m: int = f[4] if f[3] > 0.0 else 1
		for i in m + 1:
			var q := a.lerp(b, float(i) / m)
			if f[3] > 0.0 and i > 0 and i < m:
				q += Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * f[3]
			pts.append(q)
	var n := pts.size() - 1
	var cam := get_viewport().get_camera_3d()
	var olho := cam.global_position if cam else pts[0] + Vector3.UP * 10.0
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP, p.mat)
	var total := 0.0
	for i in n:
		total += pts[i].distance_to(pts[i + 1])
	total = maxf(total, 0.001)
	var corrido := 0.0
	for i in pts.size():
		var dir := (pts[mini(i + 1, n)] - pts[maxi(i - 1, 0)]).normalized()
		var lado: Vector3 = dir.cross((olho - pts[i]).normalized()).normalized() * f[2] * 0.5
		if i > 0:
			corrido += pts[i].distance_to(pts[i - 1])
		var u := corrido / total
		var luz: float = 1.0 - u * p.get("cauda", 0.0)
		im.surface_set_color(Color(luz, luz, luz))
		im.surface_set_uv(Vector2(u, 0))
		im.surface_add_vertex(pts[i] + lado)
		im.surface_set_uv(Vector2(u, 1))
		im.surface_add_vertex(pts[i] - lado)
	im.surface_end()


# subida de nivel (ReceiveLevelUp e Receive_Master_LevelUp): faiscas BITMAP_FLARE que sobem do
# personagem. Normal: 15 da 0 (sobem girando devagar) e o anel no chao (BITMAP_MAGIC+1).
# Master: 1 da 45 (sobe reto girando) e 19 da 46 (sobem abrindo pros lados, verdes).
# Nos primeiros 20 quadros sobem (6 a 8 do MU por quadro); depois voltam pra cabeca e somem.
static func subiu_nivel(pai: Node, alvo: Node3D, master: bool) -> void:
	var e := criar(pai)
	var n := 20 if master else 15
	for i in n:
		var tipo := (45 if i == 0 else 46) if master else 0
		var lado := Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized() * (1.0 if tipo == 46 else 0.15)
		var cor := Color(0.45, 1.0, 0.55) if tipo == 46 else (Color(0.6, 0.6, 1.3) if tipo == 45 else Color(1, 0.9, 0.7))
		var fase := randf() * TAU
		var dados := {"lado": lado, "fase": fase, "tipo": tipo}
		var anda := func(p: Dictionary, k: float) -> void:
			var t: float = p.t
			var sobe := 2.0 if tipo == 46 else 1.5            # tiles por segundo (8 e 6 do MU a 25 qps)
			var giro: float = dados.fase + t * (8.0 if tipo == 46 else 4.0)
			var r := minf(t, 0.8) * (1.2 if tipo == 46 else 0.4)
			var d := Vector3(cos(giro) * r + dados.lado.x * minf(t, 0.8), minf(t, 0.8) * sobe, sin(giro) * r + dados.lado.y * minf(t, 0.8))
			if t > 0.8:
				# MoveHumming: volta pra cabeca (1,2 acima dos pes)
				var volta := clampf((t - 0.8) / 1.0, 0.0, 1.0)
				d = d.lerp(Vector3(0, 1.2, 0), volta * volta)
			p.desl = d
		var ponta := e.sprite("flare01", alvo.global_position, 1.3 if tipo != 0 else 1.0, cor, 1.9,
			{"segue": alvo, "anda": anda, "some": 0.35})
		ponta.desl = Vector3.ZERO
		# a cauda: copias menores que ficam pra tras (MaxTails)
		e.tarefa(0.05, 1.7, func(ef: EfeitoMU, _j: int) -> void:
			if is_instance_valid(ponta.no):
				ef.sprite("flare01", ponta.no.global_position, 0.8, cor * 0.7, 0.35, {"tam1": 0.2}))
	if not master:
		e.chao("magic_ground2", alvo.global_position, 1.6, Color(1, 0.9, 0.6), 1.2, {"tam1": 2.4, "vgiro": 1.5})


# fogos (CreateEffect BITMAP_FIREWORK do F3 40 tipo 0 e 59): 5 foguetes (JointSpirit rosa) sobem e estouram em
# faiscas e brilhos que caem; os de natal soltam tambem doces e caixinhas
static func fogos(pai: Node, pos: Vector3, natal: bool) -> void:
	var e := criar(pai)
	# um foguete a cada 0,25 s
	e.tarefa(0.25, 1.0, func(ef: EfeitoMU, _j: int) -> void:
		var de := pos + Vector3(randf_range(-1.5, 1.5), 0.3, randf_range(-1.5, 1.5))
		var para := de + Vector3(randf_range(-1, 1), randf_range(2.5, 4.0), randf_range(-1, 1))
		var n := ef.voar(de, para, 0.8, func(fim: Vector3) -> void: _estouro(ef, fim, natal))
		ef.tarefa(0.03, 0.8, func(f2: EfeitoMU, _k: int) -> void:
			if voando(n):
				f2.sprite("flare01", n.global_position, 0.6, Color(0.9, 0.4, 0.6), 0.4, {"tam1": 0.1})))


static func _estouro(e: EfeitoMU, pos: Vector3, natal: bool) -> void:
	var cor := Color.from_hsv(randf(), 0.6, 1.0)
	e.sprite("flare01", pos, 3.0, cor, 0.5, {"tam1": 0.5, "some": 0.6})
	for i in 36:
		var d := Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)).normalized() * randf_range(2.0, 3.5)
		var p := e.sprite("flare01" if i % 2 else "shiny02", pos, 0.45, cor if i % 3 else Color(1, 1, 1), randf_range(1.0, 1.6),
			{"some": 0.5, "tam1": 0.15})
		p.vel = d
		p.acel = Vector3(0, -3.0, 0)
	if natal:
		for i in 4:
			var p := e.modelo("xmasecandy" if i % 2 else "xmasebox", pos, 0.8, Color(1, 1, 1), 1.6,
				{"some": 0.3, "vgiro": 4.0})
			p.vel = Vector3(randf_range(-2, 2), randf_range(0, 2), randf_range(-2, 2))
			p.acel = Vector3(0, -4.0, 0)


# redemoinho da caixa que caiu (F3 40 tipo 58): brilhos rosa subindo em espiral em volta de quem abriu
static func redemoinho(pai: Node, alvo: Node3D) -> void:
	var e := criar(pai)
	e.tarefa(0.05, 1.5, func(ef: EfeitoMU, j: int) -> void:
		var fase := j * 0.7
		ef.sprite("shiny02", alvo.global_position, 0.5, Color(1, 0.55, 0.8), 1.0, {"segue": alvo, "some": 0.4,
			"anda": func(p: Dictionary, _k: float) -> void:
				var g: float = fase + p.t * 6.0
				var r: float = 0.9 - p.t * 0.5
				p.desl = Vector3(cos(g) * r, p.t * 2.2, sin(g) * r)}))


# escudo (C1 48): 3 pocao de SD (circulo no chao e luzes subindo), 17 o SD acabou (atshild azul que some)
static func escudo(pai: Node, alvo: Node3D, quebrou: bool) -> void:
	var e := criar(pai)
	if quebrou:
		e.modelo("atshild", alvo.global_position + Vector3.UP * 0.9, 1.0, Color(0.5, 0.5, 1), 1.0,
			{"segue": alvo, "some": 0.6, "tam1": 1.3})
		return
	e.chao("magic_ground2", alvo.global_position, 1.4, Color(0.8, 0.8, 0.3), 1.0, {"segue": alvo, "vgiro": 2.0, "some": 0.5})
	for i in 3:
		var fase := TAU * i / 3.0
		e.sprite("flare01", alvo.global_position, 0.7, Color(1, 0.9, 0.4), 1.0, {"segue": alvo, "some": 0.4,
			"anda": func(p: Dictionary, _k: float) -> void:
				var g: float = fase + p.t * 5.0
				p.desl = Vector3(cos(g) * 0.6, 0.2 + p.t * 1.8, sin(g) * 0.6)})
