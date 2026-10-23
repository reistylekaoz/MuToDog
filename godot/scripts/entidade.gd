class_name Entidade
extends Node3D
# Alguem no mapa (eu, outro jogador, npc ou monstro): o modelo do MU animado
# (Boneco) ou, se nao tiver modelo, uma capsula colorida. Nome em cima; anda
# tile a tile pelo caminho que recebe.

const CORES := {
	"eu": Color(1.0, 0.78, 0.25),
	"jogador": Color(0.35, 0.6, 1.0),
	"monstro": Color(0.9, 0.25, 0.2),
	"npc": Color(0.35, 0.85, 0.4),
	"guarda": Color(0.55, 0.8, 0.95),
	"outro": Color(0.6, 0.6, 0.6),
}
# segundos por tile (andar do MU sem botas/asa fica perto disso)
const PASSO := 0.28

var id := 0
var tipo := "outro"
var nome := ""
var numero := -1        # monstro ou NPC: o numero dele (Monster.txt)
var dano_visto := 0     # dano que vi esse monstro levar (pra estimar a barra de vida do foco)
var heroi := 3          # estado de heroi (0 novo .. 6 PK de segundo nivel); muda a cor do nome
var tile := Vector2i.ZERO
var fila: Array[Vector2i] = []
var mundo: Node3D
var _de := Vector3.ZERO
var _t := 0.0
var _corpo: MeshInstance3D
var boneco: Boneco
var morto := false
var _destaque := false
var buffs := {}        # efeitos ligados (C1 07, C1 1B, C1 2D e a lista do C2 12): numero -> true
var lento := 1.0       # gelo anda e mexe na metade (Cold: um terco)
var _auras := {}       # efeito -> EfeitoMU que fica enquanto o buff durar


func montar(m: Node3D, i: int, t: String, n: String, x: int, y: int, b: Boneco = null) -> void:
	mundo = m
	id = i
	tipo = t
	nome = n
	tile = Vector2i(x, y)
	var cor: Color = CORES.get(tipo, CORES.outro)
	var topo := 1.7
	if b:
		boneco = b
		add_child(b)
		b.tocar("parado")
		topo = b.altura
		# Atlans: 4 bolhas por quadro em volta de quem esta no mapa (64 pra cada lado, ate 256
		# de altura); aqui um tanto menos pra nao pesar com o mapa cheio
		if int(m.numero) == 8 and ResourceLoader.exists(m.pasta + "bolha.png"):
			var bo := Ambiente.bolhas(m, 24)
			bo.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
			bo.emission_box_extents = Vector3(0.64, 1.28, 0.64)
			bo.position = Vector3(0, 1.28, 0)
			add_child(bo)
	else:
		var tamanho := 1.0 if tipo != "monstro" else 0.9
		_corpo = MeshInstance3D.new()
		var cap := CapsuleMesh.new()
		cap.radius = 0.32 * tamanho
		cap.height = 1.7 * tamanho
		var mat := StandardMaterial3D.new()
		mat.albedo_color = cor
		mat.roughness = 0.6
		cap.material = mat
		_corpo.mesh = cap
		_corpo.position.y = cap.height / 2.0
		add_child(_corpo)
		topo = cap.height
		# nariz: mostra pra onde olha
		var nariz := MeshInstance3D.new()
		var bx := BoxMesh.new()
		bx.size = Vector3(0.12, 0.12, 0.3)
		bx.material = mat
		nariz.mesh = bx
		nariz.position = Vector3(0, cap.height * 0.8, -0.32)
		add_child(nariz)
	# nome em cima da cabeca: desenhado pelo TextosMU (monstro e NPC so com o mouse em cima, como no cliente)
	if tipo == "eu":
		var anel := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 0.42
		tm.outer_radius = 0.5
		var am := StandardMaterial3D.new()
		am.albedo_color = cor
		am.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		tm.material = am
		anel.mesh = tm
		anel.position.y = 0.05
		add_child(anel)
	position = mundo.no_tile(x, y)


# vai ate o tile andando pelo caminho (ou em linha, se o mapa nao achar)
func ir_para(alvo: Vector2i, caminho: Array[Vector2i]) -> void:
	if morto:
		return
	if caminho.is_empty() and alvo != tile:
		caminho = _em_linha(tile, alvo)
	fila = caminho
	if _t <= 0.0:
		_proximo()


func teleportar(x: int, y: int) -> void:
	# teleporte tambem e o renascer depois de morrer
	if morto:
		morto = false
		scale = Vector3.ONE
		if boneco:
			boneco.tocar("parado")
	fila.clear()
	_t = 0.0
	tile = Vector2i(x, y)
	position = mundo.no_tile(x, y)


static func _em_linha(de: Vector2i, para: Vector2i) -> Array[Vector2i]:
	var r: Array[Vector2i] = []
	var p := de
	while p != para and r.size() < 40:
		p += Vector2i(signi(para.x - p.x), signi(para.y - p.y))
		r.append(p)
	return r


func _proximo() -> void:
	if fila.is_empty():
		_t = 0.0
		_animar("parado")
		return
	_animar("anda")
	_de = position
	_t = PASSO / lento * (1.41 if (fila[0] - tile).abs() == Vector2i.ONE else 1.0)
	var d: Vector3 = mundo.no_tile(fila[0].x, fila[0].y) - position
	if Vector2(d.x, d.z).length() > 0.01:
		rotation.y = atan2(-d.x, -d.z)


func _process(dt: float) -> void:
	if _t <= 0.0 or fila.is_empty():
		return
	var total := PASSO / lento * (1.41 if (fila[0] - tile).abs() == Vector2i.ONE else 1.0)
	_t -= dt
	# quadro lento: o tempo que sobrou do passo vai pro proximo
	while _t <= 0.0 and not fila.is_empty():
		var sobra := -_t
		position = mundo.no_tile(fila[0].x, fila[0].y)
		tile = fila.pop_front()
		_proximo()
		if fila.is_empty():
			return
		_t -= sobra
		total = PASSO / lento * (1.41 if (fila[0] - tile).abs() == Vector2i.ONE else 1.0)
	var alvo: Vector3 = mundo.no_tile(fila[0].x, fila[0].y)
	position = _de.lerp(alvo, clampf(1.0 - _t / total, 0.0, 1.0))


# troca so entre parado e andando: ataque, golpe e morte terminam sozinhos
func _animar(a: String) -> void:
	if boneco == null or morto or boneco.acao == a or boneco.acao.trim_suffix("_f") == a:
		return
	# montado, voando, nadando ou com arma a acao tocada tem outro nome
	if boneco.pedida == a and boneco.acao == boneco.resolver(a):
		return
	if a == "parado" and boneco.acao in Boneco.NAO_REPETE:
		boneco._fila = "parado"
		return
	boneco.tocar(a)


func morrer() -> void:
	morto = true
	fila.clear()
	_t = 0.0
	if boneco:
		boneco.tocar("morre")
	else:
		create_tween().tween_property(self, "scale", Vector3(1, 0.05, 1), 0.6)


func _nome_escondido() -> bool:
	return tipo in ["monstro", "npc", "guarda"]


func altura() -> float:
	return boneco.altura if boneco else 1.7


func nome_visivel() -> bool:
	return _destaque or not _nome_escondido()


func destacar(sim: bool) -> void:
	if sim == _destaque:
		return
	_destaque = sim


func andando() -> bool:
	return not fila.is_empty()


func olhar_para(outro: Node3D) -> void:
	var d := outro.position - position
	if Vector2(d.x, d.z).length() > 0.01:
		rotation.y = atan2(-d.x, -d.z)
	if boneco:
		boneco.tocar("ataque", "anda" if andando() else "parado")
	elif _corpo:
		var tw := create_tween()
		tw.tween_property(_corpo, "position:z", -0.35, 0.08)
		tw.tween_property(_corpo, "position:z", 0.0, 0.15)


# skill: vira pro ponto e toca a acao (se o modelo nao tiver, o ataque comum)
func tocar_skill(acao: String, ponto: Vector3) -> void:
	var d := ponto - position
	if Vector2(d.x, d.z).length() > 0.01:
		rotation.y = atan2(-d.x, -d.z)
	if boneco:
		var a := acao if boneco.tem(acao) or boneco.tem(acao + "_f") else "ataque"
		boneco.tocar(a, "anda" if andando() else "parado")


# numero do dano (ReceiveAttackDamage do cliente): tipo = byte do pacote (0 normal, 1 perfeito,
# 2 excelente, 3 critico, 4 reflexo, 5 veneno, 6 dano por tempo; bit 0x40 duplo, 0x80 combo);
# escudo = dano no SD, em verde-amarelo 25 acima. Dano 0 e Miss.
func mostrar_dano(dano: int, tipo_dano := 0, escudo := 0) -> void:
	dano_visto += dano
	if boneco and dano > 0 and not andando() and (boneco.acao.begins_with("parado") or boneco.acao == "voa"):
		boneco.tocar("golpe")
	var t := TextosMU.atual
	if t == null:
		return
	var esc := 15.0
	var cor := Color(1, 1, 1)
	var dt := tipo_dano & 0x0F
	if dano == 0:
		cor = Color(1, 1, 1) if tipo == "eu" else Color(0.5, 0.5, 0.5)
	else:
		match dt:
			0: cor = Color(1, 0, 0) if tipo == "eu" else Color(1, 0.6, 0)
			1: cor = Color(0, 1, 1); esc = 50.0
			2: cor = Color(0, 1, 0.6); esc = 50.0
			3: cor = Color(0, 0.6, 1); esc = 50.0
			4: cor = Color(1, 0, 1)
			5: cor = Color(0, 1, 0)
			6: cor = Color(0.7, 0.4, 1.0)
	if dano > 0 and (tipo_dano & 0xC0):
		if tipo_dano & 0x80:
			esc = 50.0
		var c1 := Color(cor.r - 0.4, cor.g - 0.4, cor.b - 0.4)
		var c2 := Color(cor.r - 0.2, cor.g - 0.2, cor.b - 0.2)
		t.ponto(self, dano, c1, esc)
		t.ponto(self, dano, c2, esc + 5.0, 10.0)
		if tipo_dano & 0x80:
			t.ponto(self, dano, cor, esc + 10.0, 20.0)
	t.ponto(self, dano, cor, esc)
	if escudo > 0:
		t.ponto(self, escudo, Color(0.8, 1, 0), 15.0, 25.0)


# liga ou desliga um efeito (g_CharacterRegisterBuff / UnRegisterBuff do cliente) e refaz o visual
func por_heroi(estado: int) -> void:
	if estado != heroi:
		heroi = estado
		_cor_buffs()


# anel de transformacao: troca o boneco (o de monstro entra, o da classe volta)
func trocar_boneco(b: Boneco) -> void:
	if b == null:
		return
	if boneco:
		boneco.queue_free()
	boneco = b
	add_child(b)
	b.rotation = Vector3.ZERO
	b.tocar("parado")
	_cor_buffs()


func buff(e: int, sim: bool) -> void:
	if sim == buffs.has(e):
		return
	if sim:
		buffs[e] = true
	else:
		buffs.erase(e)
	_cor_buffs()
	if _auras.has(e):
		if is_instance_valid(_auras[e]):
			_auras[e].queue_free()
		_auras.erase(e)
	if sim and boneco:
		var a := aura(self, e)
		if a:
			_auras[e] = a


func _cor_buffs() -> void:
	var veneno := buffs.has(55)
	var gelo := buffs.has(56) or buffs.has(86)
	var cor := Color(1, 1, 1)
	if veneno and gelo:
		cor = Color(0.3, 1, 1)
	elif veneno:
		cor = Color(0.3, 1, 0.5)
	elif buffs.has(61):
		cor = Color(0.25, 0.25, 1)   # o cliente usa (0, 0, 1); com a luz do Godot o preto puro some
	elif gelo or buffs.has(57):
		cor = Color(0.3, 0.5, 1)
	elif buffs.has(-1):
		cor = Color(0.9, 0.5, 0.5)   # bebeu Ale (C3 29 tipo 0)
	elif buffs.has(-2):
		cor = Color(0.5, 0.9, 0.5)   # Remedy of Love (tipo 1)
	elif heroi == 6:
		cor = Color(1, 0.1, 0.1)     # PK de segundo nivel: o corpo fica vermelho (ZzzCharacter, PKLevel 6)
	lento = 0.5 if buffs.has(56) else (0.33 if buffs.has(86) else 1.0)
	if boneco:
		boneco.tinta_buff(cor, 0.5 if buffs.has(18) else 1.0)
		if boneco.anim:
			boneco.anim.speed_scale = lento


# o que fica em volta do corpo enquanto o buff dura (RegisterBuff do cliente); null = so a cor
static func aura(alvo: Node3D, e: int) -> EfeitoMU:
	var ef := EfeitoMU.criar(alvo)
	var sempre := 1e9
	match e:
		1, 2, 3, 4:
			# 5 rastros girando em volta (flareBlue): brancos na Soul Barrier, verdes no ataque e defesa
			var cor := Color(1, 1, 1) if e == 4 else Color(0.4, 0.8, 0.2)
			for i in 5:
				var fase := TAU * i / 5.0
				var alt := 0.5 + 0.3 * i
				var ponta := ef.sprite("flareblue", alvo.global_position, 0.35, cor, sempre, {"segue": alvo,
					"anda": func(p: Dictionary, _k: float) -> void:
						var g: float = fase + p.t * 3.0
						p.desl = Vector3(cos(g) * 0.7, alt + sin(p.t * 2.0 + fase) * 0.25, sin(g) * 0.7)})
				ef.tarefa(0.04, sempre, func(f: EfeitoMU, _j: int) -> void:
					if is_instance_valid(ponta.no):
						f.sprite("flareblue", ponta.no.global_position, 0.3, cor * 0.6, 0.3, {"tam1": 0.05}))
		8:
			# Swell Life: luzes laranja subindo do peito (BITMAP_LIGHT)
			ef.tarefa(0.12, sempre, func(f: EfeitoMU, _j: int) -> void:
				var d := Vector3(randf_range(-0.35, 0.35), randf_range(0.8, 1.5), randf_range(-0.35, 0.35))
				var p := f.sprite("flare01", alvo.global_position + d, 0.5, Color(1, 0.5, 0.1), 0.8, {"some": 0.5, "tam1": 0.2})
				p.vel = Vector3(0, 0.6, 0))
		61:
			# Stun: a caveira em cima da cabeca
			ef.modelo("skull", alvo.global_position, 0.6, Color(0.8, 0.8, 0.8), sempre, {"segue": alvo, "vgiro": 2.0,
				"anda": func(p: Dictionary, _k: float) -> void: p.desl = Vector3(0, 2.1 + sin(p.t * 4.0) * 0.05, 0)})
		57:
			# Ice Arrow (Harden): o bloco de gelo em volta
			ef.modelo("ice01", alvo.global_position, 0.6, Color(0.5, 0.7, 1.0), sempre, {"segue": alvo})
		_:
			ef.queue_free()
			return null
	return ef
