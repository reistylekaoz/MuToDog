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
var tile := Vector2i.ZERO
var fila: Array[Vector2i] = []
var mundo: Node3D
var _de := Vector3.ZERO
var _t := 0.0
var _corpo: MeshInstance3D
var boneco: Boneco
var morto := false
var _destaque := false


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
	_t = PASSO * (1.41 if (fila[0] - tile).abs() == Vector2i.ONE else 1.0)
	var d: Vector3 = mundo.no_tile(fila[0].x, fila[0].y) - position
	if Vector2(d.x, d.z).length() > 0.01:
		rotation.y = atan2(-d.x, -d.z)


func _process(dt: float) -> void:
	if _t <= 0.0 or fila.is_empty():
		return
	var total := PASSO * (1.41 if (fila[0] - tile).abs() == Vector2i.ONE else 1.0)
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
		total = PASSO * (1.41 if (fila[0] - tile).abs() == Vector2i.ONE else 1.0)
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
