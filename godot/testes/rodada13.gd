extends SceneTree
# Confere a rodada 13 sem servidor: os pacotes do Blood Castle que chegam (C1 9A resposta da entrada, 9B estado do
# castelo, 93 resultado com pontos que podem ser negativos, 46 terreno que muda, 92 contagem do castelo) e o que
# sai (C1 9A entrar), a janela do Mensageiro do Arcanjo (8 castelos, tabela do DK, DL e RF), a janela do tempo,
# a caixa do resultado, o caminho que abre quando o servidor tira a parede e o mapa (castelos usam a pasta World12).
# Uso: $G --headless --path . --script res://testes/rodada13.gd   (termina com "falhas: 0")

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


func _initialize() -> void:
	var cli := ClienteMU.new()
	for s in ["evento_entrada", "bc_estado", "bc_resultado", "terreno", "evento_contagem"]:
		cli.connect(s, guarda(s))
	cli._tratar(PackedByteArray([0xC1, 4, 0x9A, 1]))
	confere("C1 9A: capa com nivel errado (1)", ultimo.get("evento_entrada", []) == ["bc", 1])
	cli._tratar(PackedByteArray([0xC1, 13, 0x9B, 1, 0x78, 0, 40, 0, 3, 0, 0xFF, 0xFF, 0]))
	confere("C1 9B: estado 1, 120 s, 3 de 40, sem dono da arma", ultimo.get("bc_estado", []) == [1, 120, 40, 3, 0xFFFF, 0])
	var p := PackedByteArray([0xC1, 29, 0x93, 0, 0xFF])
	var nome := "test0Dk".to_ascii_buffer()
	nome.resize(10)
	p.append_array(nome)
	p.append_array(PackedByteArray([0, 0]))
	p.append_array(PackedByteArray([0xD4, 0xFE, 0xFF, 0xFF]))     # -300
	p.append_array(PackedByteArray([0x40, 0x9C, 0, 0]))           # 40000
	p.append_array(PackedByteArray([0, 0, 0, 0]))
	cli._tratar(p)
	confere("C1 93 do castelo: falhou, -300 pontos, 40000 de exp", ultimo.get("bc_resultado", []) == [false, "test0Dk", -300, 40000, 0])
	cli._tratar(PackedByteArray([0xC1, 15, 0x46, 0, 4, 1, 2, 8, 78, 11, 83, 13, 15, 15, 23]))
	confere("C1 46: tira o 4 (parede) de 2 retangulos", ultimo.get("terreno", []) == [4, true, [[8, 78, 11, 83], [13, 15, 15, 23]]])
	var con := ConFalsa.new()
	cli.con = con
	cli.entrar_blood(8)
	confere("sai C1 9A castelo 8 e 0xFF", con.enviados[0] == PackedByteArray([0xC1, 5, 0x9A, 8, 0xFF]))

	# janela do Mensageiro
	var j := JanelaEvento.new()
	root.add_child(j)
	await process_frame
	var pedidos := []
	j.entrar.connect(func(n): pedidos.append(n))
	j.abrir("bc", 2, 100, false)
	confere("8 castelos; Elfa 100 no 2o (81-130)", j._botoes.size() == 8 and j.ativo == 1 and j._botoes[1] == "Castle 2 (level 81-130)")
	j.abrir("bc", 4, 100, false)
	confere("Dark Lord 100 no 2o da tabela dele (61-110)", j.ativo == 1 and j._botoes[1] == "Castle 2 (level 61-110)")
	j.abrir("bc", 1, 400, true)
	confere("master: so o 8o", j.ativo == 7 and j._botoes[7] == "Castle no. 8 (Master Level)")
	j.clicar(7)
	confere("o Blood Castle manda o indice + 1 (8)", pedidos == [8])
	confere("fala do Mensageiro em 3 linhas (%d, fonte %d)" % [j._linhas.size(), j._tam], j._linhas.size() <= 3 and j._linhas[0].begins_with("Your will"))
	j.queue_redraw()
	await process_frame

	# janela do tempo
	var ev := Eventos.new()
	root.add_child(ev)
	await process_frame
	ev.contagem(3)
	confere("contagem 3: " + ev.texto_contagem(), ev.texto_contagem() == "Blood Castle Closing (in 30 seconds)")
	ev.em_castelo = true
	ev.estado_castelo(0, 900, 40, 0)
	confere("estado 0: janela do tempo aparece", ev.mostra_tempo() and ev.bc_tipo == 1)
	ev.estado_castelo(4, 299, 65535, 0)
	confere("portao caiu (4): segue contando, sem contagem de monstros", ev.mostra_tempo() and ev.bc_tipo == 5 and ev.bc_maximo == 65535)
	confere("relogio 04:59", ev.relogio().begins_with(" 04:59:"))
	ev.queue_redraw()
	await process_frame
	ev.em_castelo = false
	confere("fora do castelo nao mostra", not ev.mostra_tempo())
	ev.em_castelo = true
	ev.estado_castelo(2, 0, 0, 0)
	confere("estado 2: acabou", not ev.mostra_tempo() and ev.bc_tipo == 0)

	# resultado
	for ok in [true, false]:
		var c := CaixaPlacar.new("bc")
		c.bc = {"ok": ok, "pontos": -300 if not ok else 1200, "exp": 40000, "zen": 120000}
		root.add_child(c)
		await process_frame
		confere("resultado %s: 230 x 207 a 100 do alto, frase de %d linhas" % [ok, c._frase.size()],
			c.size == Vector2(230, 207) and is_equal_approx(c.position.y, 100.0 * c._esc) and c._frase.size() == 2)
		c.queue_free()

	# o caminho abre quando a parede sai
	var m: Node3D = load("res://scripts/mundo.gd").new()
	m.atributos.resize(256 * 256)
	m.grade.region = Rect2i(0, 0, 256, 256)
	m.grade.update()
	for y in range(10, 20):
		m.atributos[y * 256 + 15] = 4
		m.grade.set_point_solid(Vector2i(15, y))
	confere("parede: sem caminho de 14 pra 16 na linha 12", not m.anda(15, 12))
	m.mudar_atributo(4, true, 15, 12, 15, 13)
	confere("C1 46 tirou a parede: anda e a grade sabe", m.anda(15, 12) and not m.grade.is_point_solid(Vector2i(15, 12))
		and m.grade.is_point_solid(Vector2i(15, 14)))
	m.free()

	confere("castelos 11 a 17 e 52 usam a pasta mundo12", PacoteMapa.mundo_do_mapa(11) == 12 and PacoteMapa.mundo_do_mapa(52) == 12)
	confere("mundo12 convertido", FileAccess.file_exists("res://dados/mundo12/objetos.json"))
	confere("som do castelo", FileAccess.file_exists("res://dados/sons/ibloodcastle.wav"))
	var mm: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://dados/monstros_mapa.json"))
	confere("monstros do castelo 8 e da praca 7 no pacote dos eventos", "monster82" in mm["0"] and "monster53" in mm["0"])
	print("falhas: %d" % falhas)
	quit(1 if falhas > 0 else 0)
