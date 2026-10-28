extends SceneTree
# Confere a escolha do servidor no jeito do CServerSelWin: os grupos do ServerList.bmd (indice / 20), o nome de cada
# servidor (InsertServer com os textos 560, 561 e 562), o nome no login (460 e 461), a posicao dos botoes
# (SetPosition e SetServerBtnPosition em 800 x 600) e o que cada clique faz (grupo pede a lista, servidor conecta,
# cheio avisa). Uso: $G --headless --path . --script res://testes/servidor_selecao.gd   (termina com "falhas: 0")

var falhas := 0


class ConFalsa extends Conexao:
	var enviados: Array = []

	func enviar(pacote: PackedByteArray) -> void:
		Cripto.gravar_tamanho(pacote)
		enviados.append(pacote)


func confere(nome: String, ok: bool) -> void:
	print(("  ok    " if ok else "  FALHA ") + nome)
	if not ok:
		falhas += 1


func _initialize() -> void:
	var script := {}
	for g in JSON.parse_string(FileAccess.get_file_as_string("res://dados/servidores.json")):
		script[int(g.indice)] = g
	var textos: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://dados/textos_eng.json"))
	confere("ServerList.bmd: Valhalla, Helheim e Midgard", script.size() == 3 and script[0].nome == "Valhalla" and script[2].nome == "Midgard")

	# a lista do OpenMU daqui (0, 1 e 2) e um servidor do grupo 1 e outro de grupo sem script
	var l := [{"id": 0, "carga": 0}, {"id": 1, "carga": 100}, {"id": 2, "carga": 130}, {"id": 25, "carga": 40}, {"id": 99, "carga": 0}]
	var g := LoginCena.montar_grupos(l, script, textos)
	confere("2 grupos (o 4 nao esta no ServerList.bmd)", g.size() == 2)
	confere("pela ordem: Valhalla no botao 1, Helheim no 2 (os dois na esquerda)", g[0].nome == "Valhalla" and g[0].botao == 1 and g[1].nome == "Helheim" and g[1].botao == 2)
	var s: Array = g[0].servidores
	confere("Valhalla-1(Gold) Connect", s[0].nome == "Valhalla-1(Gold) Connect")
	confere("cheio: Valhalla-2(Gold) (Full)", s[1].nome == "Valhalla-2(Gold) (Full)")
	confere("128 ou mais: Valhalla-3(Gold) Now preparing", s[2].nome == "Valhalla-3(Gold) Now preparing")
	confere("Helheim-6(Non-PVP) (indice 25 = grupo 1, numero 6)", g[1].servidores[0].nome == "Helheim-6(Non-PVP) Connect" and g[1].servidores[0].tipo == 1)
	confere("no login: [Valhalla-1 Server]", s[0].login == "[Valhalla-1 Server]")

	# grupo do meio e da direita
	var sc2 := script.duplicate(true)
	sc2[0].posicao = 2
	sc2[1].posicao = 1
	var g2 := LoginCena.montar_grupos([{"id": 0, "carga": 0}, {"id": 20, "carga": 0}, {"id": 40, "carga": 0}], sc2, textos)
	confere("meio no 0, direita no 11, esquerda no 1", g2.map(func(x): return x.botao) == [0, 11, 1])

	# posicoes numa tela de 800 x 600
	var tela := LoginCena.new()
	tela.size = Vector2(800, 600)
	confere("janela 465 x 504 no meio (167, 48)", tela.selecao() == Vector2(167, 48))
	confere("grupo do meio em (345, 469)", tela.rect_grupo(0).position == Vector2(167 + 178, 48 + 504 - 83))
	confere("grupos da esquerda de 204 pra baixo", tela.rect_grupo(1).position == Vector2(167, 204) and tela.rect_grupo(10).position == Vector2(167, 438))
	confere("grupos da direita em x 524", tela.rect_grupo(11).position == Vector2(524, 204))
	confere("servidores em x 303 a partir de 204", tela.rect_servidor(0, 3).position == Vector2(303, 204) and tela.rect_servidor(2, 3).position == Vector2(303, 256))
	confere("16 servidores sobem 6 linhas", tela.rect_servidor(0, 16).position.y == 204 - 26 * 6)

	# cliques: grupo marca e pede a lista; servidor com vaga conecta; cheio so avisa
	tela.aviso = Label.new()
	tela._textos = textos
	tela.grupos = g
	var pediu := []
	var foi := []
	tela.pedir_lista.connect(func(): pediu.append(1))
	tela.servidor.connect(func(id): foi.append(id))
	tela.clicar_selecao("s0")
	confere("sem grupo marcado o servidor nao responde", foi.is_empty())
	tela.clicar_selecao("g1")
	confere("grupo 1 marcado e lista pedida", tela.grupo_sel == 1 and pediu.size() == 1)
	tela.clicar_selecao("s1")
	confere("cheio: nao conecta e avisa The server is full", foi.is_empty() and tela.aviso.text == "The server is full")
	tela.clicar_selecao("s2")
	confere("128 ou mais: nada", foi.is_empty())
	tela.clicar_selecao("s0")
	confere("com vaga: conecta no 0 e o login mostra [Valhalla-1 Server]", foi == [0] and tela.servidor_nome == "[Valhalla-1 Server]")

	# o cliente: F4 06 de novo so ligado no connect server
	var cli := ClienteMU.new()
	var con := ConFalsa.new()
	cli.con = con
	cli.estado = "lista"
	cli.pedir_lista_servidores()
	cli.estado = "jogo"
	cli.pedir_lista_servidores()
	confere("F4 06 so no connect server", con.enviados.size() == 1 and con.enviados[0].hex_encode() == "c104f406")
	tela.aviso.free()
	tela.free()
	print("falhas: %d" % falhas)
	quit(falhas)
