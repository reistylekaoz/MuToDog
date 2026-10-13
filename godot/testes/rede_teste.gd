extends SceneTree
# Teste de ponta a ponta contra o OpenMU daqui (../servidor.sh ligar-teste):
# connect server -> lista -> game server -> login test0 -> personagem do mapa 0
# -> ve npcs/monstros -> anda 3 passos -> sai, entra de novo e confere a posicao.
# Rodar: bash testes/rede.sh

var cli: ClienteMU
var fase := 1
var achou_npcs := 0
var antes := Vector2i.ZERO
var esperado := Vector2i.ZERO
var tempo := 0.0
var falhas := 0
var nomes := {}


func _init() -> void:
	var m: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://dados/monstros.json"))
	nomes = m
	_rodada()


func _rodada() -> void:
	cli = ClienteMU.new()
	root.add_child.call_deferred(cli)
	cli.servidores.connect(func(l):
		print("TESTE servidores: ", l)
		cli.pedir_servidor(l[0].id))
	cli.personagens.connect(_personagens)
	cli.entrou.connect(_entrou)
	cli.objeto_entrou.connect(_objeto)
	cli.estado_mudou.connect(func(e, t):
		if e.begins_with("erro"):
			_falha("estado %s %s" % [e, t]))
	cli.entrar("test0", "test0")
	cli.conectar.call_deferred("127.127.127.127", 44405)


func _personagens(l: Array) -> void:
	print("TESTE personagens: ", l)
	for p in l:
		if p.nome == "test0Dk":
			cli.escolher(p.nome)
			return
	_falha("sem test0Dk na lista")


func _entrou(info: Dictionary) -> void:
	print("TESTE entrou: ", info)
	if info.mapa != 0:
		_falha("mapa %d" % info.mapa)
	if fase == 1:
		antes = Vector2i(info.x, info.y)
		# 3 passos pro leste (direcao 3 = x+1)
		esperado = antes + Vector2i(3, 0)
		await create_timer(2.0).timeout
		cli.andar(info.x, info.y, [3, 3, 3])
		print("TESTE andei de %s pra %s" % [antes, esperado])
		await create_timer(3.0).timeout
		print("TESTE npcs/monstros vistos: %d" % achou_npcs)
		if achou_npcs == 0:
			_falha("nenhum npc no alcance")
		fase = 2
		cli.queue_free()
		await create_timer(3.0).timeout
		_rodada()
	else:
		if Vector2i(info.x, info.y) != esperado:
			_falha("posicao depois de andar: %s, esperava %s" % [Vector2i(info.x, info.y), esperado])
		else:
			print("TESTE posicao conferida: ", esperado)
		print("TESTE falhas: %d" % falhas)
		quit(1 if falhas else 0)


func _objeto(o: Dictionary) -> void:
	if o.tipo == "npc":
		achou_npcs += 1
		if achou_npcs <= 5:
			print("TESTE npc %s (%d) em %d,%d" % [nomes.get(str(o.numero), ["?"])[0], o.numero, o.x, o.y])
	else:
		print("TESTE personagem ", o)


func _falha(t: String) -> void:
	falhas += 1
	print("TESTE FALHA ", t)


func _process(dt: float) -> bool:
	tempo += dt
	if tempo > 60.0:
		_falha("tempo esgotado na fase %d (estado %s)" % [fase, cli.estado if is_instance_valid(cli) else "-"])
		print("TESTE falhas: %d" % falhas)
		quit(1)
	return false
