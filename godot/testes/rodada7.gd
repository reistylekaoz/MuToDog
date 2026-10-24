extends SceneTree
# Confere a rodada 7 sem servidor: os pacotes de guilda que chegam (C1 50, 51, C2 52, 53, 54, 56, 5D, C2 65,
# C1 66, chat com "@") e os que saem (C1 50, 51, 52, 53, 54, 55, 66, E1), a marca de 8x8 e a janela de criar.
# Uso: $G --headless --path . --script res://testes/rodada7.gd   (termina com "falhas: 0")

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


func nome(n: String, tam: int) -> PackedByteArray:
	var b := n.to_ascii_buffer()
	b.resize(tam)
	return b


func _initialize() -> void:
	var cli := ClienteMU.new()
	cli.meu_id = 5
	for s in ["guilda_pedido_entrar", "guilda_resposta", "guilda_lista", "guilda_saiu", "guilda_criar_janela",
			"guilda_criada", "guilda_jogador_saiu", "guilda_jogadores", "guilda_info", "chat_guilda", "mensagem"]:
		cli.connect(s, guarda(s))
	cli._tratar(PackedByteArray([0xC1, 5, 0x50, 0x04, 0x8E]))
	confere("C1 50: pedido do id 1166", ultimo.get("guilda_pedido_entrar", []) == [1166])
	cli._tratar(PackedByteArray([0xC1, 4, 0x51, 7]))
	confere("C1 51: resultado 7 (nivel)", ultimo.get("guilda_resposta", []) == [7])
	# C2 52: em guilda, 2 membros, pontos 300, rival vazio
	var p := PackedByteArray([0xC2, 0, 0, 0x52, 1, 2, 0, 0, 0x2C, 0x01, 0, 0, 0])
	p.resize(24)
	p.append_array(nome("Mestre", 10))
	p.append_array(PackedByteArray([0, 0x80, 128]))
	p.append_array(nome("Novato", 10))
	p.append_array(PackedByteArray([0, 0x7F, 0]))
	p[2] = p.size()
	cli._tratar(p)
	var info: Dictionary = ultimo.get("guilda_lista", [{}])[0]
	confere("C2 52: 2 membros, 300 pontos", info.get("em_guilda", false) and info.pontos == 300 and info.membros.size() == 2)
	confere("C2 52: Mestre on no servidor 0 (cargo 128), Novato off",
		info.membros[0].nome == "Mestre" and info.membros[0].online and info.membros[0].servidor == 0
		and info.membros[0].cargo == 128 and not info.membros[1].online and info.membros[1].cargo == 0)
	cli._tratar(PackedByteArray([0xC1, 4, 0x53, 4]))
	confere("C1 53: desfeita", ultimo.get("guilda_saiu", []) == [4])
	cli._tratar(PackedByteArray([0xC1, 3, 0x54]))
	confere("C1 54: janela de criar", ultimo.has("guilda_criar_janela"))
	cli._tratar(PackedByteArray([0xC1, 5, 0x56, 0, 179]))
	confere("C1 56: falhou, erro 179", ultimo.get("guilda_criada", []) == [false, 179])
	cli._tratar(PackedByteArray([0xC1, 5, 0x5D, 0x84, 0x8E]))
	confere("C1 5D: id 1166 era mestre", ultimo.get("guilda_jogador_saiu", []) == [1166, true])
	# C2 65: id 5 (eu, aparecendo) na guilda 9 como mestre; id 1166 na mesma como membro
	p = PackedByteArray([0xC2, 0, 0, 0x65, 2])
	p.append_array(PackedByteArray([9, 0, 0, 0, 128, 0, 0, 0x80, 5, 0, 0, 0]))
	p.append_array(PackedByteArray([9, 0, 0, 0, 0, 0, 2, 0x04, 0x8E, 0, 0, 0]))
	p[2] = p.size()
	cli._tratar(p)
	var l: Array = ultimo.get("guilda_jogadores", [[]])[0]
	confere("C2 65: 2 jogadores", l.size() == 2)
	confere("C2 65: eu mestre da 9 (novo)", l[0].id == 5 and l[0].guilda == 9 and l[0].cargo == 128 and l[0].novo)
	confere("C2 65: 1166 membro, relacao 2", l[1].id == 1166 and l[1].cargo == 0 and l[1].relacao == 2 and not l[1].novo)
	# C1 66: guilda 9 "Teste", logo com a primeira cor 4 e a segunda 6
	p = PackedByteArray([0xC1, 60, 0x66, 0, 9, 0, 0, 0, 0])
	p.append_array(nome("", 8))
	p.append_array(nome("Teste", 8))
	var logo := PackedByteArray()
	logo.resize(32)
	logo[0] = 0x46
	p.append_array(logo)
	p.resize(60)
	cli._tratar(p)
	var gi: Dictionary = ultimo.get("guilda_info", [{}])[0]
	confere("C1 66: guilda 9 Teste", gi.get("id", -1) == 9 and gi.nome == "Teste" and gi.logo.size() == 32 and gi.logo[0] == 0x46)
	Guildas.guardar(gi)
	var img: Image = Guildas.tex(9).get_image()
	confere("marca: 8x8, (0,0) vermelho, (1,0) amarelo, (2,0) transparente",
		img.get_size() == Vector2i(8, 8) and img.get_pixel(0, 0) == Color8(255, 0, 0) and img.get_pixel(1, 0) == Color8(255, 255, 0)
		and img.get_pixel(2, 0).a == 0.0)
	# chat: "@oi" vai pra guilda, o resto segue no chat
	p = PackedByteArray([0xC1, 0, 0x00])
	p.append_array(nome("Mestre", 10))
	p.append_array("@oi".to_ascii_buffer())
	p[1] = p.size()
	cli._tratar(p)
	confere("C1 00 com @: chat da guilda", ultimo.get("chat_guilda", []) == ["Mestre", "oi"])

	# pacotes que saem
	var con := ConFalsa.new()
	cli.con = con
	cli.pedir_entrar_guilda(1166)
	cli.responder_guilda(true, 1166)
	cli.pedir_lista_guilda()
	cli.tirar_da_guilda("Novato", "1234")
	cli.responder_mestre_guilda(true)
	var marca := PackedByteArray()
	marca.resize(64)
	marca[0] = 4
	marca[1] = 6
	marca[63] = 15
	cli.criar_guilda("Teste", marca)
	cli.pedir_info_guilda(0x01020309)
	cli.cargo_guilda(1, 64, "Novato")
	var e: Array = con.enviados
	confere("C1 50 sai com o id BE", e[0] == PackedByteArray([0xC1, 5, 0x50, 0x04, 0x8E]))
	confere("C1 51 sai aceito", e[1] == PackedByteArray([0xC1, 6, 0x51, 1, 0x04, 0x8E]))
	confere("C1 52 sai", e[2] == PackedByteArray([0xC1, 3, 0x52]))
	confere("C1 53 com nome 10 e senha 20 (33 bytes)", e[3].size() == 33 and e[3].slice(3, 9).get_string_from_ascii() == "Novato"
		and e[3].slice(13, 17).get_string_from_ascii() == "1234")
	confere("C1 54 01", e[4] == PackedByteArray([0xC1, 4, 0x54, 1]))
	confere("C1 55 de 44: nome no 4, marca 0x46 no 12, 0x0F no 43", e[5].size() == 44 and e[5][1] == 44 and e[5][2] == 0x55
		and e[5].slice(4, 9).get_string_from_ascii() == "Teste" and e[5][12] == 0x46 and e[5][43] == 0x0F)
	confere("C1 66 de 8 com o id LE no 4", e[6] == PackedByteArray([0xC1, 8, 0x66, 0, 9, 3, 2, 1]))
	confere("C1 E1 de 15: nomeia assistente", e[7].size() == 15 and e[7][3] == 1 and e[7][4] == 64
		and e[7].slice(5, 11).get_string_from_ascii() == "Novato")

	# janela de criar: valida nome e marca como o cliente
	var j := JanelaCriarGuilda.new()
	j.definir_nome("ab")
	confere("criar: nome curto pede 4 letras (390)", j.validar() == DicaItem.t(390))
	j.definir_nome("a b!")
	confere("criar: simbolo (391)", j.validar() == DicaItem.t(391))
	j.definir_nome("Teste")
	confere("criar: sem marca (426)", j.validar() == DicaItem.t(426))
	j.pintar(10, 4)
	confere("criar: nome e marca ok", j.validar() == "")
	var criou := []
	j.criar.connect(func(n, m): criou.append([n, m[10]]))
	j.ir(JanelaCriarGuilda.RESUMO)
	j.avancar()
	confere("criar: Next no resumo manda Teste com a cor 4 na celula 10", criou == [["Teste", 4]])
	j.free()
	var c := CaixaMU.new(["a", "b", "c"], true, true)
	confere("caixa: 3 linhas e a senha = 67 + 15*3 + 50", c.altura() == 67.0 + 45.0 + 50.0)
	c.free()
	print("falhas: %d" % falhas)
	quit(1 if falhas else 0)
