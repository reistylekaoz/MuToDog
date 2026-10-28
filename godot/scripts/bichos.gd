class_name Bichos
extends Node3D
# Os bichos que andam em volta do heroi (GOBoid.cpp do cliente S6): MoveBoids (os que voam,
# ate 5 por mapa; o cardume de Atlans ate 40) e MoveFishs (os do chao, 3 por mapa; 10 em
# Atlans e Tarkan). Nascem a ate 5 tiles do heroi, rodeiam ele e somem quando ficam a mais
# de 15 tiles ou batem duas vezes no que nao podem pisar (agua, parede, zona segura).
# Lorencia: passaros e peixes na agua; Dungeon: morcegos e ratos; Noria: borboletas;
# Lost Tower: morcegos; Atlans: cardume e peixes no fundo (os de cima do mapa brilham);
# Tarkan: besouros com rastro de luz; Icarus: dragoes voando la embaixo.

# mundo -> [modelos, quantos, velocidade (Velocity do cliente), jeito de voar]
const VOAM := {
	1: [["bicho_passaro"], 5, 1.0, "passaro"],
	2: [["bicho_morcego"], 5, 1.0, "morcego"],
	4: [["bicho_borboleta"], 5, 0.3, "borboleta"],
	5: [["bicho_morcego"], 5, 1.0, "morcego"],
	8: [["bicho_peixe2", "bicho_peixe3"], 24, 0.3, "cardume"],
	# Icarus (CreateDragon): 3 dragoes (Monster32, acao 7) voando reto 6 m abaixo do heroi
	11: [["bicho_dragao"], 3, 0.0, "dragao"],
}
# mundo -> [modelos, quantos, velocidade x escala, escala minima, maxima, onde pode andar]
const ANDAM := {
	1: [["bicho_peixe"], 3, 0.6, 0.4, 0.7, "agua"],
	2: [["bicho_rato"], 3, 0.6, 0.4, 0.7, "chao"],
	8: [["bicho_peixe4", "bicho_peixe5", "bicho_peixe6", "bicho_peixe7"], 10, 1.0, 0.8, 0.9, "fora"],
	9: [["bicho_besouro"], 10, 2.5, 0.8, 1.1, "fora"],
}
const LONGE := 15.0   # 1500 do cliente: some
const LONGE_DRAGAO := 40.0
const PERTO := 5.12   # nasce em ate 512 pra cada lado

# invasao do dragao (C1 0B, EnableEvent): 0 nada, 1 dragao vermelho, 3 dourado; vale em todo mapa ate o servidor
# mandar 0, como a variavel global do cliente
static var evento := 0
static var som: Node

var mundo: Node3D
var _evento_visto := 0
var _dragoes: Array = []   # cada um: {b, vida, timer, esc}
var _ef: EfeitoMU
var _voam: Array = []    # cada um: {b, ang, vel, timer, giro, alto}
var _andam: Array = []   # cada um: {b, ang, vel, bate, giro}
var _t := 0.0


func _ready() -> void:
	if mundo == null or not mundo.tem_dados:
		return
	print("TESTE bichos %d · voam %d · andam %d" % [mundo.numero, VOAM.get(mundo.numero, [[], 0])[1], ANDAM.get(mundo.numero, [[], 0])[1]])


func _centro() -> Vector2:
	if mundo.seguir and is_instance_valid(mundo.seguir):
		var p: Vector3 = mundo.seguir.global_position
		return Vector2(p.x, -p.z)
	return mundo.alvo + Vector2(0.5, 0.5)


func _chao(xy: Vector2) -> float:
	return mundo.altura_em(xy.x, xy.y) / 100.0


func _pode(regra: String, xy: Vector2) -> bool:
	var x := int(floor(xy.x))
	var y := int(floor(xy.y))
	if x < 0 or y < 0 or x >= 256 or y >= 256:
		return false
	var at: int = mundo.atributos[y * 256 + x]
	match regra:
		"agua": return mundo.camada1(x, y) == 5
		"chao": return at & 0x0C == 0
		_: return at & 0x0D == 0   # nem zona segura, nem parede, nem buraco


func _process(dt: float) -> void:
	if mundo == null or not mundo.tem_dados:
		return
	_t += dt
	var c := _centro()
	if evento != _evento_visto:
		_apagar_voam()
	if evento != 0:
		_mexer_invasao(c, dt)
		return
	_mexer_voam(c, dt)
	_mexer_andam(c, dt)


# ---------- os que voam ----------
func _mexer_voam(c: Vector2, dt: float) -> void:
	var cfg: Array = VOAM.get(mundo.numero, [])
	if cfg.is_empty():
		return
	var n: int = cfg[1]
	var jeito: String = cfg[3]
	# Atlans: o cardume so aparece no sul (y < 128) e fora da cidade
	if jeito == "cardume" and (c.y >= 128.0 or not _pode("fora", c)):
		n = 0
	while _voam.size() < n:
		var nome: String = cfg[0][randi() % cfg[0].size()]
		if jeito == "dragao":
			if not _nasce_dragao(nome, c):
				return
			continue
		var b := Boneco.novo(nome, 0.8)
		if b == null:
			return
		b.ritmo = {"parado": 1.0}
		b.tocar("parado")
		add_child(b)
		var xy := c + Vector2(randf_range(-PERTO, PERTO), randf_range(-PERTO, PERTO))
		var alto := randf_range(1.5, 3.5) if jeito != "passaro" else randf_range(2.0, 6.0)
		b.global_position = Vector3(xy.x, _chao(xy) + alto, -xy.y)
		_voam.append({"b": b, "ang": randf() * TAU, "vel": cfg[2], "timer": randf() * 3.14, "giro": randf_range(2.0, 4.5) * (1.0 if randf() < 0.5 else -1.0), "alto": alto, "sobe": 0.0})
	for i in range(_voam.size() - 1, -1, -1):
		var v: Dictionary = _voam[i]
		var b: Boneco = v.b
		var p := Vector2(b.global_position.x, -b.global_position.z)
		if i >= n or p.distance_to(c) > (LONGE_DRAGAO if jeito == "dragao" else LONGE):
			b.queue_free()
			_voam.remove_at(i)
			continue
		if jeito == "dragao":
			# MoveBoidGroup: anda Velocity * 25 por quadro pra frente, sem mudar de altura
			var f := Vector2(cos(v.ang), sin(v.ang))
			p += f * v.vel * 25.0 * 0.01 * dt * 25.0
			b.global_position = Vector3(p.x, v.alto, -p.y)
			b.rotation.y = atan2(-f.x, f.y)
			continue
		# rodeia o heroi: mira um ponto que gira em volta dele (MoveBoid puxa pro heroi)
		var alvo: Vector2 = c + Vector2(cos(_t * 0.4 + i), sin(_t * 0.4 + i)) * absf(v.giro)
		var quer := (alvo - p).angle()
		var vira := 1.6 if jeito != "borboleta" else 3.0
		v.ang = rotate_toward(v.ang, quer, vira * dt)
		var rapido: float = v.vel * 25.0
		match jeito:
			"borboleta":
				# MoveButterFly: troca de rumo a cada 32 quadros, sobe e desce no ar
				if randf() < dt * 25.0 / 32.0:
					v.ang += randf_range(-PI, PI)
					v.sobe = randf_range(-7.0, 7.0)
				v.sobe += randf_range(-7.0, 7.0) * 0.2 * dt * 25.0
				v.alto = clampf(v.alto + v.sobe * 0.01 * dt * 25.0 * 0.3, 0.5, 3.0)
			"morcego":
				# MoveBat: altura = chao + 350 - |sin(timer)| * 150, timer += 0,2 por quadro
				v.timer += 0.2 * dt * 25.0
				v.alto = 3.5 - absf(sin(v.timer)) * 1.5
			"cardume":
				# MoveBoidGroup em Atlans: nada devagar (8..24) e da arrancada (32..64) metade do tempo
				v.timer = fmod(v.timer + 0.1 * dt * 25.0, 10.0)
				rapido = v.vel * (16.0 if v.timer < 5.0 else 48.0)
			_:
				v.alto = clampf(v.alto + randf_range(-8.0, 8.0) * 0.01 * dt * 25.0, 2.0, 6.0)
		var d := Vector2(cos(v.ang), sin(v.ang))
		p += d * rapido * 0.01 * dt * 25.0
		b.global_position = Vector3(p.x, _chao(p) + v.alto, -p.y)
		b.rotation.y = atan2(-d.x, d.y)


# CreateDragon: escala 0,3..0,4, Velocity 0,2..0,38, rumo ao acaso, nasce a ate 20 tiles do
# heroi e 600 abaixo dele; bate as asas a 0,5 quadro por quadro
func _nasce_dragao(nome: String, c: Vector2) -> bool:
	var b := Boneco.novo(nome, randf_range(0.3, 0.4))
	if b == null:
		return false
	b.ritmo = {"parado": 0.5}
	b.tocar("parado")
	add_child(b)
	var xy := c + Vector2(randf_range(-20.0, 20.0), randf_range(-20.0, 20.0))
	var h: float = mundo.seguir.global_position.y if mundo.seguir and is_instance_valid(mundo.seguir) else _chao(c)
	b.global_position = Vector3(xy.x, h - 6.0, -xy.y)
	_voam.append({"b": b, "ang": randf() * TAU, "vel": randf_range(0.2, 0.38), "timer": 0.0, "giro": 0.0, "alto": h - 6.0, "sobe": 0.0})
	return true


# ---------- os do chao ----------
func _mexer_andam(c: Vector2, dt: float) -> void:
	var cfg: Array = ANDAM.get(mundo.numero, [])
	if cfg.is_empty():
		return
	var regra: String = cfg[5]
	# tenta nascer uns poucos por quadro: so onde o bicho pode pisar
	if _andam.size() < cfg[1]:
		var xy := c + Vector2(randf_range(-PERTO, PERTO), randf_range(-PERTO, PERTO))
		if _pode(regra, xy):
			_nasce(cfg, xy, c)
	for i in range(_andam.size() - 1, -1, -1):
		var v: Dictionary = _andam[i]
		var b: Boneco = v.b
		var p := Vector2(b.global_position.x, -b.global_position.z)
		if p.distance_to(c) > LONGE or v.bate >= 2:
			b.queue_free()
			_andam.remove_at(i)
			continue
		var alvo: Vector2 = c + Vector2(cos(_t * 0.3 + i * 2.0), sin(_t * 0.3 + i * 2.0)) * absf(v.giro)
		v.ang = rotate_toward(v.ang, (alvo - p).angle() + randf_range(-0.6, 0.6), 2.5 * dt)
		var d := Vector2(cos(v.ang), sin(v.ang))
		var prox: Vector2 = p + d * v.vel * randf_range(6.0, 9.0) * 0.01 * dt * 25.0
		if not _pode(regra, prox):
			# bateu: vira pro outro lado (duas seguidas e ele some)
			v.ang += PI
			v.bate += 1
		else:
			if v.bate > 0 and randf() < dt:
				v.bate -= 1
			p = prox
		b.global_position = Vector3(p.x, _chao(p) + v.acima, -p.y)
		b.rotation.y = atan2(-d.x, d.y)


func _nasce(cfg: Array, xy: Vector2, c: Vector2) -> void:
	var modelos: Array = cfg[0]
	var nome: String = modelos[randi() % modelos.size()]
	var glow := false
	# Atlans: no norte (y >= 128) os peixes sao os que brilham (Fish08 e Fish09, malha 0 somada)
	if mundo.numero == 8 and c.y >= 128.0:
		nome = "bicho_peixe%d" % (8 + randi() % 2)
		glow = true
	var esc := randf_range(cfg[3], cfg[4])
	var b := Boneco.novo(nome, esc)
	if b == null:
		return
	var vel: float = cfg[2] / esc * (0.5 if glow else 1.0)
	b.ritmo = {"parado": vel * 0.5, "anda": vel * 0.5}
	b.tocar("anda")
	add_child(b)
	if glow:
		b.somar_malha(0)
	if mundo.numero == 1:
		b.transparente(randf_range(0.2, 0.3))   # peixe da Lorencia: AlphaTarget 0,2..0,3
	var acima := 0.0
	if mundo.numero == 8:
		acima = randf_range(0.3, 1.5)
	b.global_position = Vector3(xy.x, _chao(xy) + acima, -xy.y)
	if mundo.numero == 9:
		var r := RastroOlho.no_olho(b, 6)   # besouro de Tarkan: CreateJoint BITMAP_JOINT_ENERGY 4
		r.largura = 0.15
	_andam.append({"b": b, "ang": randf() * TAU, "vel": vel, "bate": 0, "giro": randf_range(2.0, 5.0), "acima": acima})


# ---------- invasao do dragao ----------
# ReceiveEvent troca o EnableEvent e chama DeleteBoids: some todo bicho que voa
func _apagar_voam() -> void:
	for v in _voam + _dragoes:
		if is_instance_valid(v.b):
			v.b.queue_free()
	_voam.clear()
	_dragoes.clear()
	_evento_visto = evento
	if mundo.has_method("sombra_dragao"):
		mundo.sombra_dragao(Vector2.ZERO, false)


# MoveBoids com EnableEvent: ate 5 dragoes (Monster32, acao 7 a 0,5) nascem com chance 1/300 por tick a -1..5 tiles
# em x e 2..6 em y do heroi, escala 0,6..0,8, vida 128..256 ticks; voam pro sul (angulo -90) a escala * 40 por tick,
# 3 tiles acima do chao descendo ate 1 com |sin(timer)|; o dourado (3) com RENDER_METAL e RENDER_CHROME. Fogo no
# osso 11 (50 abaixo) e o rugido 1/128. Do ceu cai um MODEL_FIRE tipo 3 com o eMeteorite a cada ~40 ticks e o chao
# escurece (-0,3 -0,3 -0,2) em 16 tiles; o vento da grama corre 5 vezes mais.
func _mexer_invasao(c: Vector2, dt: float) -> void:
	if _ef == null or not is_instance_valid(_ef):
		_ef = EfeitoMU.criar(mundo)
	var ticks := dt * 25.0
	if mundo.has_method("sombra_dragao"):
		mundo.sombra_dragao(c, true)
	while _dragoes.size() < 5 and randf() < ticks / 300.0:
		var esc := randf_range(0.6, 0.8)
		var b := Boneco.novo("bicho_dragao", esc)
		if b == null:
			break
		b.ritmo = {"parado": 0.5}
		b.tocar("parado")
		add_child(b)
		if evento == 3:
			b.camada(-1, "shiny01", "metal", Color(1, 1, 1), [], Vector2.ZERO)
			b.camada(-1, "chrome01", "chrome", Color(1, 1, 1), [], Vector2.ZERO)
		var xy := c + Vector2(randf_range(-1.0, 5.0), randf_range(2.0, 6.0))
		b.global_position = Vector3(xy.x, _chao(xy) + 3.0, -xy.y)
		b.rotation.y = PI   # angulo -90 do MU: o rumo e -y (sul)
		_dragoes.append({"b": b, "vida": randf_range(128, 256), "timer": randf_range(0, 0.9), "esc": esc})
		print("TESTE invasao dragao %d nasceu (%d)" % [evento, _dragoes.size()])
	for i in range(_dragoes.size() - 1, -1, -1):
		var v: Dictionary = _dragoes[i]
		var b: Boneco = v.b
		var p := Vector2(b.global_position.x, -b.global_position.z)
		v.vida -= ticks
		if v.vida <= 0 or p.distance_to(c) > LONGE_DRAGAO or not is_instance_valid(b):
			if is_instance_valid(b):
				b.queue_free()
			_dragoes.remove_at(i)
			continue
		p.y -= v.esc * 40.0 * 0.01 * ticks
		v.timer += v.esc * 0.05 * ticks
		b.global_position = Vector3(p.x, _chao(p) + 3.0 - absf(sin(v.timer)) + 1.0, -p.y)
		var boca := EfeitoSkill._osso(b, 11) + Vector3(0, -0.5, 0)
		_ef.sprite("flare01", boca, 0.6, Color(1, 0, 0), 2 * EfeitoSkill.T)
		if randf() < ticks * 0.5:
			EfeitoSkill.fogo(_ef, boca)
		if som and randf() < ticks / 128.0:
			som.tocar("dragao_bull")
	if randf() < ticks / 40.0:
		var alvo := c + Vector2(randf_range(-2.0, 4.0), randf_range(2.0, 6.0))
		EfeitoSkill._meteoro(_ef, Vector3(alvo.x, _chao(alvo), -alvo.y))
		if som:
			som.tocar("meteoro")
