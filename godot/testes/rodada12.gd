extends SceneTree
# Confere a rodada 12 sem servidor: os pacotes do Devil Square que chegam (C1 90 resposta da entrada, 91 hora de
# abrir, 92 contagem, 93 placar, F3 40 fala do Charon) e os que saem (C1 90 entrar, 91 perguntar), a janela de
# entrada do Charon (botao aceso pelo nivel e pela classe), o texto da contagem, a caixa do placar e o mapa
# (Devil Square 32 usa a pasta World10).
# Uso: $G --headless --path . --script res://testes/rodada12.gd   (termina com "falhas: 0")

var falhas := 0
var ultimo := {}


class ConFalsa extends Conexao:
	var enviados: Array = []

	func enviar(pacote: PackedByteArray) -> void:
		Cripto.gravar_tamanho(pacote)
		enviados.append(pacote)


func confere(nome: String, ok: bool) -> void:
	print(("  ok    " if ok else "  FALHA ") + nome)
	if not ok:
		falhas += 1


func guarda(sinal: String) -> Callable:
	return func(...a): ultimo[sinal] = a


static func _nome(t: String) -> PackedByteArray:
	var b := t.to_ascii_buffer()
	b.resize(10)
	return b


static func _le(v: int) -> PackedByteArray:
	return PackedByteArray([v & 0xFF, (v >> 8) & 0xFF, (v >> 16) & 0xFF, (v >> 24) & 0xFF])


func _initialize() -> void:
	var cli := ClienteMU.new()
	for s in ["evento_entrada", "evento_abre", "evento_contagem", "ds_placar", "texto_servidor"]:
		cli.connect(s, guarda(s))
	cli._tratar(PackedByteArray([0xC1, 4, 0x90, 1]))
	confere("C1 90: sem convite (1)", ultimo.get("evento_entrada", []) == ["ds", 1])
	cli._tratar(PackedByteArray([0xC1, 7, 0x91, 1, 5, 0, 0]))
	confere("C1 91: Devil Square abre em 5 min", ultimo.get("evento_abre", []) == [1, 5, 0, 0])
	cli._tratar(PackedByteArray([0xC1, 4, 0x92, 1]))
	confere("C1 92: contagem 1", ultimo.get("evento_contagem", []) == [1])
	var p := PackedByteArray([0xC1, 0, 0x93, 2, 2])
	for d in [["Fulano", 900, 5000, 30000], ["test0Dk", 450, 2500, 15000]]:
		p.append_array(_nome(d[0]))
		p.append_array(PackedByteArray([0, 0]))
		p.append_array(_le(d[1]))
		p.append_array(_le(d[2]))
		p.append_array(_le(d[3]))
	p[1] = p.size()
	cli._tratar(p)
	var pl: Array = ultimo.get("ds_placar", [0, []])
	confere("C1 93: eu sou o 2o de 2", pl[0] == 2 and pl[1].size() == 2)
	confere("C1 93: 1o Fulano 900 pontos, 5000 exp, 30000 zen", pl[1][0] == {"nome": "Fulano", "pontos": 900, "exp": 5000, "zen": 30000})
	cli._tratar(PackedByteArray([0xC1, 8, 0xF3, 0x40, 1, 0x17, 0, 0]))
	confere("F3 40 1 0x17: fala 833 do Arcanjo", ultimo.get("texto_servidor", []) == [833])
	cli._tratar(PackedByteArray([0xC1, 8, 0xF3, 0x40, 1, 2, 0, 0]))
	confere("F3 40 1 2: fala 652", ultimo.get("texto_servidor", []) == [652])

	var con := ConFalsa.new()
	cli.con = con
	cli.entrar_devil(3)
	cli.perguntar_evento(1, 0)
	confere("sai C1 90 nivel 3 e 0xFF (convite procurado na mochila)", con.enviados[0] == PackedByteArray([0xC1, 5, 0x90, 3, 0xFF]))
	confere("sai C1 91 tipo 1", con.enviados[1] == PackedByteArray([0xC1, 5, 0x91, 1, 0]))

	# janela do Charon
	var j := JanelaEvento.new()
	root.add_child(j)
	await process_frame
	var pedidos := []
	j.entrar.connect(func(n): pedidos.append(n))
	j.abrir("ds", 0, 150, false)
	confere("janela 190x429 com 7 botoes", j.visible and j.size == Vector2(190, 429) and j._botoes.size() == 7)
	confere("Dark Wizard 150: 2a praca (131-180)", j.ativo == 1 and j._botoes[1] == "The 2 Square (131-180 level)")
	j.abrir("ds", 1, 150, false)
	confere("Dark Knight 150: 2a praca na tabela dele (111-160)", j.ativo == 1 and j._botoes[1] == "The 2 Square (111-160 level)")
	j.abrir("ds", 6, 300, false)
	confere("Rage Fighter 300: 5a praca (261-310)", j.ativo == 4)
	j.abrir("ds", 2, 400, true)
	confere("master: so a 7a (Master Level)", j.ativo == 6 and j._botoes[6] == "Square no. 7 (Master Level)")
	j.abrir("ds", 0, 40, false)
	j.clicar(3)
	j.clicar(0)
	confere("so o botao aceso manda: indice 0", pedidos == [0])
	confere("texto do Charon: 6 linhas a partir da 670", j._linhas.size() == 6 and j._linhas[0] == DicaItem.t(670))
	j.queue_redraw()
	await process_frame

	# contagem e placar
	var ev := Eventos.new()
	root.add_child(ev)
	await process_frame
	ev.contagem(0)
	confere("contagem 0: " + ev.texto_contagem(), ev.texto_contagem() == "You will enter Devil Square (30 seconds from now)")
	ev.contagem(2)
	confere("contagem 2: fecha o portao", ev.texto_contagem().begins_with("The gate of Devil Square is closing down"))
	ev.queue_redraw()
	await process_frame
	var c := CaixaPlacar.new("ds")
	c.heroi = "test0Dk"
	c.minha_pos = 2
	c.lista = pl[1]
	root.add_child(c)
	await process_frame
	confere("placar 230 x 348 a 60 do alto", c.size == Vector2(230, 348) and is_equal_approx(c.position.y, 60.0 * c._esc))
	c.responder(true)
	await process_frame
	confere("OK fecha o placar", not is_instance_valid(c) or c.is_queued_for_deletion())

	# caixa com frase comprida quebra
	var cx := CaixaMU.new([DicaItem.t(833)], false)
	root.add_child(cx)
	await process_frame
	confere("fala 833 quebra em %d linhas" % cx.linhas.size(), cx.linhas.size() >= 4)
	cx.queue_free()

	confere("Devil Square 32 usa a pasta mundo10", PacoteMapa.mundo_do_mapa(32) == 10 and PacoteMapa.mundo_do_mapa(3) == 4)
	confere("mundo10 convertido (objetos.json)", FileAccess.file_exists("res://dados/mundo10/objetos.json"))
	confere("Devil Square no pacote a parte do navegador", 10 in PacoteMapa.FORA)
	for s in ["res://scripts/jogo.gd", "res://scripts/janela_evento.gd", "res://scripts/eventos.gd", "res://scripts/caixa_placar.gd"]:
		confere("carrega " + s.get_file(), load(s) != null)
	print("falhas: %d" % falhas)
	quit(1 if falhas > 0 else 0)
