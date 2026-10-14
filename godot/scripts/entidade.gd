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
var rotulo: Label3D
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
	rotulo = Label3D.new()
	rotulo.text = nome
	rotulo.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	rotulo.no_depth_test = true
	rotulo.fixed_size = true
	rotulo.pixel_size = 0.0012
	rotulo.font_size = 28
	rotulo.outline_size = 8
	rotulo.modulate = cor.lightened(0.3)
	rotulo.position.y = topo + 0.45
	add_child(rotulo)
	# monstro e NPC: nome so com o mouse em cima ou quando e o alvo (como no cliente)
	rotulo.visible = not _nome_escondido()
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


func destacar(sim: bool) -> void:
	if sim == _destaque:
		return
	_destaque = sim
	rotulo.visible = sim or not _nome_escondido()
	rotulo.outline_modulate = Color(0.55, 0.1, 0.05) if sim and tipo == "monstro" else Color(0, 0, 0)


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


# numero do dano subindo e sumindo em cima da cabeca
func mostrar_dano(dano: int) -> void:
	if boneco and dano > 0 and not andando() and boneco.acao in ["parado", "parado_f", "parado2"]:
		boneco.tocar("golpe")
	var l := Label3D.new()
	l.text = str(dano) if dano > 0 else "errou"
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.fixed_size = true
	l.pixel_size = 0.0016
	l.font_size = 30
	l.outline_size = 8
	l.modulate = Color(1.0, 0.35, 0.3) if tipo == "eu" else Color(1.0, 0.85, 0.3)
	var topo := boneco.altura if boneco else 1.7
	l.position = Vector3(randf_range(-0.4, 0.4), topo + 1.0, 0)
	add_child(l)
	var tw := create_tween()
	tw.set_parallel()
	tw.tween_property(l, "position:y", topo + 2.0, 0.9)
	tw.tween_property(l, "modulate:a", 0.0, 0.9).set_delay(0.3)
	tw.chain().tween_callback(l.queue_free)
