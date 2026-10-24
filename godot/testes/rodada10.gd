extends SceneTree
# Confere a rodada 10 sem servidor: os pacotes de chat, cochicho, amigos, cartas e salas que chegam (C1 00, 02,
# 0C, C1, C3, C5, C3 C6, C4 C7, C8, C3 CA, CB) e os que saem (02, C4, C4 C5, C7, C8, CA, CB), os pacotes do
# servidor de chat (entrada, mensagem, quem entrou e saiu, lista), a reindexacao das cartas, o corte do balao,
# os bytes da foto e as janelas abrindo.
# Uso: $G --headless --path . --script res://testes/rodada10.gd   (termina com "falhas: 0")

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


func le(v: int) -> Array:
	return [v & 0xFF, (v >> 8) & 0xFF, (v >> 16) & 0xFF, (v >> 24) & 0xFF]


func txt(t: String, n: int) -> PackedByteArray:
	var b := t.to_utf8_buffer()
	b.resize(n)
	return b


func _initialize() -> void:
	var cli := ClienteMU.new()
	for s in ["fala", "chat_guilda", "cochicho", "cochicho_falhou", "amigo_novo", "amigo_resultado", "amigo_saiu",
			"amigo_nao_apagou", "carta_enviada", "carta", "carta_aberta", "carta_apagada", "sala_chat", "convite_sala",
			"caixa_cartas"]:
		cli.connect(s, guarda(s))
	var p := PackedByteArray([0xC1, 0, 0x00]) + txt("test2Dk", 10) + txt("~oi grupo", 10)
	p[1] = p.size()
	cli._tratar(p)
	confere("C1 00 com ~: fala crua do grupo", ultimo.get("fala", []) == ["test2Dk", "~oi grupo"])
	p = PackedByteArray([0xC1, 0, 0x00]) + txt("test2Dk", 10) + txt("@guilda", 8)
	p[1] = p.size()
	cli._tratar(p)
	confere("C1 00 com @: chat da guilda", ultimo.get("chat_guilda", []) == ["test2Dk", "guilda"])
	p = PackedByteArray([0xC1, 0, 0x02]) + txt("test2Dk", 10) + txt("psiu", 5)
	p[1] = p.size()
	cli._tratar(p)
	confere("C1 02: cochicho", ultimo.get("cochicho", []) == ["test2Dk", "psiu"])
	cli._tratar(PackedByteArray([0xC1, 4, 0x0C, 0]))
	confere("C1 0C: ninguem", ultimo.has("cochicho_falhou"))
	cli._tratar(PackedByteArray([0xC1, 15, 0xC1, 1]) + txt("test2Dk", 10) + PackedByteArray([0]))
	confere("C1 C1 1: amigo novo no servidor 0", ultimo.get("amigo_novo", []) == ["test2Dk", 0])
	cli._tratar(PackedByteArray([0xC1, 15, 0xC1, 3]) + txt("fulano", 10) + PackedByteArray([0]))
	confere("C1 C1 3: resultado 3", ultimo.get("amigo_resultado", []) == [3, "fulano"])
	cli._tratar(PackedByteArray([0xC1, 14, 0xC3, 0]) + txt("fulano", 10))
	confere("C1 C3 0: nao apagou", ultimo.get("amigo_nao_apagou", []) == ["fulano"])
	cli._tratar(PackedByteArray([0xC1, 8, 0xC5, 1] + le(77)))
	confere("C1 C5: enviada, id 77", ultimo.get("carta_enviada", []) == [1, 77])
	p = PackedByteArray([0xC3, 0, 0xC6, 0, 3, 1]) + txt("test2Dk", 10) + txt("2026-10-24 10:20:30", 30) + txt("Ola", 32)
	p.append(2)
	p[1] = p.size()
	cli._tratar(p)
	confere("C3 C6: carta 259 nova de test2Dk", ultimo.get("carta", [{}])[0] == {"indice": 259, "de": "test2Dk",
		"data": "2026-10-24 10:20:30", "titulo": "Ola", "estado": 2})
	var corpo := "linha 1\nlinha 2".to_utf8_buffer()
	var ap := PackedByteArray()
	ap.resize(18)
	ap[0] = 1 << 3 | 0       # classe 1 (Soul Master no byte do servidor)
	p = PackedByteArray([0xC4, 0, 0, 0xC7, 2, 0, corpo.size(), 0]) + ap + PackedByteArray([0x4F, 11]) + corpo
	p[1] = p.size() >> 8
	p[2] = p.size() & 0xFF
	cli._tratar(p)
	var ab: Dictionary = ultimo.get("carta_aberta", [{}])[0]
	confere("C4 C7: carta 2 com o texto", ab.get("indice") == 2 and ab.get("texto") == "linha 1\nlinha 2")
	confere("C4 C7: classe, giro e pose", ab.get("classe") == 1 and ab.get("giro") == 0x4F and ab.get("animacao") == 11)
	cli._tratar(PackedByteArray([0xC1, 6, 0xC8, 1, 4, 0]))
	confere("C1 C8: apagou a 4", ultimo.get("carta_apagada", []) == [true, 4])
	p = PackedByteArray([0xC3, 0, 0xCA]) + txt("127.0.0.1", 15) + PackedByteArray([5, 0] + le(123456789) + [1])
	p.append_array(txt("test2Dk", 10))
	p.append(1)
	p[1] = p.size()
	cli._tratar(p)
	var sc: Dictionary = ultimo.get("sala_chat", [{}])[0]
	confere("C3 CA: sala 5, token, test2Dk, ok", sc.get("sala") == 5 and sc.get("token") == 123456789
		and sc.get("amigo") == "test2Dk" and sc.get("ok") == 1 and sc.get("ip") == "127.0.0.1")
	cli._tratar(PackedByteArray([0xC3, 8, 0xCB, 1, 0x01, 0x02, 0x03, 0x04]))
	confere("C3 CB: convite ok, pedido big endian", ultimo.get("convite_sala", []) == [1, 0x01020304])
	cli._tratar(PackedByteArray([0xC2, 0, 7, 0xC0, 3, 50, 0]))
	confere("C2 C0: 3 cartas de 50", ultimo.get("caixa_cartas", []) == [3, 50])

	var con := ConFalsa.new()
	cli.con = con
	cli.cochichar("test2Dk", "oi")
	cli.estado_chat(1)
	cli.enviar_carta(0x01020304, "test2Dk", "Ti", "abc", 0x4F, 11)
	cli.ler_carta(258)
	cli.apagar_carta(1)
	cli.abrir_sala("test2Dk")
	cli.convidar_sala("test3Dk", 0x0105, 0x0A0B0C0D)
	var e: Array = con.enviados
	confere("sai 7 pacotes", e.size() == 7)
	confere("sai C1 02 nome10 + texto + 0", e[0] == PackedByteArray([0xC1, 16, 0x02]) + txt("test2Dk", 10) + PackedByteArray([0x6F, 0x69, 0]))
	confere("sai C1 C4 01 (aceita, bit 1)", e[1] == PackedByteArray([0xC1, 4, 0xC4, 1]))
	var c5: PackedByteArray = e[2]
	confere("sai C4 C5: tamanho 85 em 2 bytes", c5[0] == 0xC4 and (c5[1] << 8 | c5[2]) == 85 and c5.size() == 85 and c5[3] == 0xC5)
	confere("sai C4 C5: id LE, nome em 8, titulo em 18", c5.slice(4, 8) == PackedByteArray([4, 3, 2, 1])
		and c5.slice(8, 18) == txt("test2Dk", 10) and c5.slice(18, 78) == txt("Ti", 60))
	confere("sai C4 C5: giro, pose, tamanho 3 e texto", c5[78] == 0x4F and c5[79] == 11 and c5[80] == 3 and c5[81] == 0
		and c5.slice(82) == "abc".to_utf8_buffer())
	confere("sai C1 C7 indice LE em [4]", e[3] == PackedByteArray([0xC1, 6, 0xC7, 0, 2, 1]))
	confere("sai C1 C8 indice LE em [4]", e[4] == PackedByteArray([0xC1, 6, 0xC8, 0, 1, 0]))
	confere("sai C1 CA nome", e[5] == PackedByteArray([0xC1, 13, 0xCA]) + txt("test2Dk", 10))
	confere("sai C1 CB sala e pedido big endian", e[6] == PackedByteArray([0xC1, 19, 0xCB]) + txt("test3Dk", 10)
		+ PackedByteArray([1, 5, 0x0A, 0x0B, 0x0C, 0x0D]))

	# servidor de chat
	var ent := SalaChat.pacote_entrada(0x0105, 4242)
	confere("sala: entrada C1 16 00 00 + sala LE", ent.slice(0, 6) == PackedByteArray([0xC1, 16, 0, 0, 5, 1]) and ent.size() == 16)
	confere("sala: token decimal em XOR3", Cripto.xor3(ent.slice(6)) == txt("4242", 10))
	var msg := SalaChat.pacote_mensagem("ola")
	confere("sala: mensagem C1 04 indice tamanho", msg.slice(0, 5) == PackedByteArray([0xC1, 8, 0x04, 0, 3])
		and Cripto.xor3(msg.slice(5)) == "ola".to_utf8_buffer())
	var sala := SalaChat.new()
	for s in ["entrou", "saiu_da_sala", "membros", "falou"]:
		sala.connect(s, guarda("sala_" + s))
	sala.tratar(PackedByteArray([0xC1, 15, 0x01, 0, 0]) + txt("test1Dk", 10))
	sala.tratar(PackedByteArray([0xC1, 15, 0x01, 0, 1]) + txt("test2Dk", 10))
	confere("sala: C1 01 00 entrou", ultimo.get("sala_entrou", []) == [1, "test2Dk"] and sala.nomes.size() == 2)
	var oi := Cripto.xor3("oi".to_utf8_buffer())
	sala.tratar(PackedByteArray([0xC1, 7, 0x04, 1, 2]) + oi)
	confere("sala: C1 04 do indice 1 com XOR3", ultimo.get("sala_falou", []) == [1, "test2Dk", "oi"])
	sala.tratar(PackedByteArray([0xC1, 15, 0x01, 1, 1]) + txt("test2Dk", 10))
	confere("sala: C1 01 01 saiu", ultimo.get("sala_saiu_da_sala", []) == [1, "test2Dk"] and sala.nomes.size() == 1)
	var lista := PackedByteArray([0xC2, 0, 30, 0x02, 0, 0, 2, 0, 0]) + txt("test1Dk", 10) + PackedByteArray([3]) + txt("test3Dk", 10)
	sala.tratar(lista)
	confere("sala: C2 02 lista de 2", ultimo.get("sala_membros", [[]])[0].size() == 2 and sala.nomes.get(3) == "test3Dk")

	# cartas: apagar desce os indices maiores
	var am := JanelaAmigos.new()
	for i in 4:
		am.carta({"indice": i, "de": "x%d" % i, "data": "2026-10-24 10:00:00", "titulo": "t%d" % i, "estado": 1})
	am.carta_apagada(1)
	confere("apagar a 1: ficam 0, 1, 2 com x0, x2, x3", am.cartas.map(func(c): return c.indice) == [0, 1, 2]
		and am.cartas.map(func(c): return c.de) == ["x0", "x2", "x3"])
	am.carta_lida(2)
	confere("lida: estado 0", am.carta_de(2).estado == 0)
	am.free()

	# balao e foto
	confere("balao curto: 1 linha", Correio.partir("oi tudo bem") == PackedStringArray(["oi tudo bem"]))
	var b := Correio.partir("essa frase e comprida demais pra uma linha")
	confere("balao comprido: 2 linhas no espaco do meio", b.size() == 2 and b[0] + " " + b[1] == "essa frase e comprida demais pra uma linha")
	var f := FotoMU.new()
	confere("foto: padrao 90 graus (15), zoom 1 (2) = 0x8F", f.giro_byte() == 0x8F)
	f.usar_giro(0xC0 | 30)
	confere("foto: 0xDE vira 180 graus e zoom 1.1", is_equal_approx(f.angulo, 180.0) and is_equal_approx(f.zoom, 1.1))
	f.usar_animacao(11)
	confere("foto: pose 11 = AT 131 saudar", f.POSES[f.pose][1] == "saudar" and f.animacao_byte() == 11)
	f.proxima(-1)
	confere("foto: volta pra parado (2)", f.animacao_byte() == 2)
	f.free()

	# janelas
	JanelaMU.carregar()
	var ja := JanelaAmigos.new()
	var jc := JanelaCarta.new(false)
	var jl := JanelaCarta.new(true)
	var js := JanelaSala.new("test2Dk", "test1Dk")
	var jp := JanelaPergunta.new("teste?", 0)
	var cx := CaixaChat.new()
	for j in [ja, jc, jl, js, jp, cx]:
		root.add_child(j)
	await process_frame
	confere("janelas abrem: amigos 250x170, carta 370x216 e 370x182", ja.L == 250 and ja.A == 170
		and jc.L == 370 and jc.A == 216 and jl.A == 182)
	js.amigos_de = func(): return ["test1Dk", "test3Dk"]
	js.sala.nomes = {0: "test1Dk"}
	js._apertou("convidar")
	confere("convite lista so quem nao esta na sala", js.amigos_online == ["test3Dk"])
	var respondeu := []
	jp.respondeu.connect(func(s, _t): respondeu.append(s))
	jp.responder(true)
	confere("pergunta responde sim", respondeu == [true])
	var ditos := []
	cx.falar.connect(func(t, para): ditos.append([t, para]))
	cx.tipo = 1
	cx.texto.text = "oi"
	cx.enviar()
	cx.tipo = 0
	cx.para.text = "test2Dk"
	cx.texto.text = "psiu"
	cx.enviar()
	confere("caixa: grupo com ~ e cochicho com nome", ditos == [["~oi", ""], ["psiu", "test2Dk"]])

	print("falhas: %d" % falhas)
	quit(1 if falhas else 0)
