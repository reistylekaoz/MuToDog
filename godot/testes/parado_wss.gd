extends SceneTree
# Fica no jogo parado pelo caminho do launcher (wss com MU_SITE e MU_CHAVE) e
# avisa se a conexao cair. Rodar: bash testes/parado_wss.sh [segundos]

var cli: ClienteMU
var t0 := 0
var limite := int(OS.get_environment("MU_PARADO_S")) if OS.get_environment("MU_PARADO_S") != "" else 360


func _init() -> void:
	cli = ClienteMU.new()
	root.add_child.call_deferred(cli)
	cli.servidores.connect(func(l): cli.pedir_servidor(l[0].id))
	cli.personagens.connect(func(l):
		print("TESTE personagens: ", l.map(func(p): return p.nome))
		cli.escolher(l[0].nome))
	cli.entrou.connect(func(info):
		t0 = Time.get_ticks_msec()
		print("TESTE entrou em %d,%d mapa %d" % [info.x, info.y, info.mapa]))
	cli.estado_mudou.connect(func(e, t):
		var s := (Time.get_ticks_msec() - t0) / 1000.0 if t0 else 0.0
		print("TESTE estado %s %s (%.1f s no jogo)" % [e, t, s])
		if e.begins_with("erro"):
			quit(1))
	cli.entrar("test7", "test7")
	cli.conectar.call_deferred("127.127.127.127", 44405)


func _process(_dt: float) -> bool:
	if t0 and Time.get_ticks_msec() - t0 > limite * 1000:
		print("TESTE vivo apos %d s no jogo" % limite)
		quit(0)
	return false
