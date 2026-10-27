extends SceneTree
# Confere a rodada 21 sem servidor: Castle Siege fora da batalha. Os C1 B2 que chegam (00 estado, 01 a 04 da
# inscricao e das marcas, 05 a 07 dos NPCs, 08 a 10 dos impostos e do tesouro, 11 a 13 dos portoes, 1A taxa)
# e as listas C2 B3, B4 e B5; os pedidos que saem (B2 00 a 12, B3 01/02, B4, B5); a janela do Guardsman
# (abas, botoes do mestre por periodo, caixa de desistir) e a do Senior (portoes, estatuas, impostos, saque).
# Uso: $G --headless --path . --script res://testes/rodada21.gd   (termina com "falhas: 0")

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


static func nome(t: String, n: int) -> Array:
	var b := t.to_utf8_buffer()
	b.resize(n)
	return Array(b)


func estado_pacote(resultado: int, estado: int, guilda := "", mestre := "", seg := 3725) -> PackedByteArray:
	var p := [0xC1, 46, 0xB2, 0x00, resultado, estado, 0x07, 0xEA, 10, 27, 0, 0, 0x07, 0xEA, 10, 28, 0, 0,
		0x07, 0xEA, 10, 31, 20, 0]
	p += nome(guilda, 8) + nome(mestre, 10)
	p += [(seg >> 24) & 0xFF, (seg >> 16) & 0xFF, (seg >> 8) & 0xFF, seg & 0xFF]
	return PackedByteArray(p)


func _initialize() -> void:
	for f in ["mapa", "portao", "portao_sel", "estatua", "estatua_sel", "zen", "linha", "botao", "aba", "tabela_c"]:
		confere("textura hud/castelo/%s" % f, ResourceLoader.exists("res://dados/hud/castelo/%s.png" % f))

	# --- pacotes que chegam ---
	var cli := ClienteMU.new()
	for s in ["cs_estado", "cs_resposta", "cs_portao", "cs_taxa", "cs_npcs", "cs_inscritas", "cs_lados"]:
		cli.connect(s, guarda(s))
	cli._tratar(estado_pacote(1, 3, "Lobos", "test400Dl"))
	var e: Dictionary = ultimo.get("cs_estado", [{}])[0]
	confere("B2 00: estado 3, datas, dono e segundos (big endian)", e.get("estado") == 3 and e.inicio == [2026, 10, 27, 0, 0]
		and e.fim == [2026, 10, 28, 0, 0] and e.batalha == [2026, 10, 31, 20, 0] and e.guilda == "Lobos"
		and e.mestre == "test400Dl" and e.segundos == 3725)
	cli._tratar(PackedByteArray([0xC1, 5, 0xB2, 0x00, 0]))
	confere("B2 00 curto: so o resultado", ultimo.cs_estado[0] == {"resultado": 0})
	cli._tratar(PackedByteArray([0xC1, 13, 0xB2, 0x01, 1] + nome("Lobos", 8)))
	confere("B2 01: inscrita", ultimo.cs_resposta[0] == 1 and ultimo.cs_resposta[1] == {"resultado": 1, "guilda": "Lobos"})
	cli._tratar(PackedByteArray([0xC1, 19, 0xB2, 0x03, 1] + nome("Lobos", 8) + [0, 0, 0, 12, 0, 2]))
	confere("B2 03: 12 marcas, ordem 2", ultimo.cs_resposta[1].marcas == 12 and ultimo.cs_resposta[1].ordem == 2)
	cli._tratar(PackedByteArray([0xC1, 17, 0xB2, 0x04, 1] + nome("Lobos", 8) + [0, 0, 1, 2]))
	confere("B2 04: marcas 258 (big endian)", ultimo.cs_resposta[0] == 4 and ultimo.cs_resposta[1].marcas == 258)
	cli._tratar(PackedByteArray([0xC1, 21, 0xB2, 0x06, 1, 0x15, 1, 0, 0, 2, 0, 0, 0, 0x40, 0x42, 0x0F, 0, 0xE0, 0xFD, 0x1C, 0]))
	confere("B2 06: conserto do portao 2 (little endian)", ultimo.cs_resposta[1] == {"resultado": 1, "numero": 277, "indice": 2,
		"vida": 1000000, "vida_max": 1900000})
	cli._tratar(PackedByteArray([0xC1, 15, 0xB2, 0x08, 1, 2, 3, 0, 0, 0, 0, 0, 0x0F, 0x42, 0x40]))
	confere("B2 08: caos 2, loja 3, tesouro 1.000.000 (64 bits)", ultimo.cs_resposta[1] == {"resultado": 1, "caos": 2, "loja": 3, "tesouro": 1000000})
	cli._tratar(PackedByteArray([0xC1, 13, 0xB2, 0x10, 1, 0, 0, 0, 0, 0, 0, 0x01, 0xF4]))
	confere("B2 10: tesouro depois do saque 500", ultimo.cs_resposta[1].zen == 500)
	cli._tratar(PackedByteArray([0xC1, 7, 0xB2, 0x11, 1, 0x01, 0x2C]))
	confere("B2 11: alavanca do portao 300", ultimo.cs_resposta[0] == 0x11 and ultimo.cs_resposta[1].portao == 300)
	cli._tratar(PackedByteArray([0xC1, 7, 0xB2, 0x13, 1, 0x01, 0x2C]))
	confere("B2 13: portao 300 aberto", ultimo.get("cs_portao", []) == [true, 300])
	cli._tratar(PackedByteArray([0xC1, 6, 0xB2, 0x1A, 2, 3]))
	confere("B2 1A: loja 3%", ultimo.get("cs_taxa", []) == [2, 3])
	var b3 := [0xC2, 0, 0, 0xB3, 1, 2, 0, 0, 0]
	for i in 2:
		b3 += [0x15, 1, 0, 0, i + 1, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0xE0, 0xFD, 0x1C, 0, 0xE0, 0xFD, 0x1C, 0, 80 + i, 60, 1 - i]
	var pb3 := PackedByteArray(b3)
	pb3[1] = pb3.size() >> 8
	pb3[2] = pb3.size() & 0xFF
	cli._tratar(pb3)
	var l: Array = ultimo.get("cs_npcs", [0, []])[1]
	confere("C2 B3: dois portoes, o segundo morto", l.size() == 2 and l[0].numero == 277 and l[0].vida_max == 1900000
		and l[0].defesa == 1 and l[0].vivo and not l[1].vivo and l[1].x == 81)
	var b4 := PackedByteArray([0xC2, 0, 37, 0xB4, 1, 2, 0, 0, 0] + nome("Lobos", 8) + [0, 0, 0, 5, 0, 1] + nome("Ursos", 8) + [0, 0, 0, 9, 1, 2])
	cli._tratar(b4)
	l = ultimo.get("cs_inscritas", [0, []])[1]
	confere("C2 B4: Lobos 5 e Ursos 9 desistiu", l.size() == 2 and l[1] == {"guilda": "Ursos", "marcas": 9, "desistiu": true, "ordem": 2})
	var b5 := PackedByteArray([0xC2, 0, 23, 0xB5, 1, 1, 0, 0, 0, 2, 1] + nome("Lobos", 8) + [7, 0, 0, 0])
	cli._tratar(b5)
	l = ultimo.get("cs_lados", [0, []])[1]
	confere("C2 B5: Lobos ataca", l.size() == 1 and l[0] == {"lado": 2, "envolvida": true, "guilda": "Lobos", "pontos": 7})

	# --- pedidos que saem ---
	var con := ConFalsa.new()
	cli.con = con
	cli.cs_pedir(0x00)
	cli.cs_pedir(0x04, PackedByteArray([20]))
	cli.cs_lista(0xB3, 0x01)
	cli.cs_lista(0xB4)
	cli.cs_npc(0x07, 283, 3, 1, 2)
	cli.cs_pedir(0x12, PackedByteArray([1, 0x01, 0x2C]))
	confere("sai C1 B2 00", con.enviados[0] == PackedByteArray([0xC1, 4, 0xB2, 0x00]))
	confere("sai C1 B2 04 com o slot 20", con.enviados[1] == PackedByteArray([0xC1, 5, 0xB2, 0x04, 20]))
	confere("sai C1 B3 01 e C1 B4", con.enviados[2] == PackedByteArray([0xC1, 4, 0xB3, 0x01]) and con.enviados[3] == PackedByteArray([0xC1, 3, 0xB4]))
	confere("sai C1 B2 07 com 4 inteiros little endian", con.enviados[4] == PackedByteArray([0xC1, 20, 0xB2, 0x07, 0x1B, 1, 0, 0, 3, 0, 0, 0, 1, 0, 0, 0, 2, 0, 0, 0]))
	confere("sai C1 B2 12 abrir o portao 300", con.enviados[5] == PackedByteArray([0xC1, 7, 0xB2, 0x12, 1, 0x01, 0x2C]))

	# --- janela do Guardsman ---
	var j := JanelaCastelo.new()
	root.add_child(j)
	var pedidos: Array = []
	var listas: Array = []
	var caixas: Array = []
	j.pedir.connect(func(s, d): pedidos.append([s, d]))
	j.pedir_lista.connect(func(c, s): listas.append([c, s]))
	j.confirmar.connect(func(linhas, feito): caixas.append([linhas, feito]))
	j.sou_mestre = true
	j.minha_guilda = "Lobos"
	j.abrir_guarda(cli_estado(cli, 1))
	confere("abrir pede a inscricao (B2 03)", pedidos.back()[0] == 0x03 and j.visible and j.aba == 0)
	j.registro({"resultado": 2, "guilda": ""})
	j.clicar(Vector2(95, 95))
	confere("aba 1 no periodo de inscricao", j.aba == 1)
	j.clicar(Vector2(95, 131))
	confere("Announce do mestre manda B2 01", pedidos.back()[0] == 0x01)
	j.registro({"resultado": 1, "guilda": "Lobos", "marcas": 0, "desistiu": 0, "ordem": 1})
	var n := pedidos.size()
	j.clicar(Vector2(95, 131))
	confere("inscrita: Announce some", pedidos.size() == n)
	j.clicar(Vector2(150, 95))
	confere("aba List pede C1 B4", j.aba == 2 and listas.back() == [0xB4, -1])
	j.clicar(Vector2(95, 380))
	confere("Abandon abre a caixa", caixas.size() == 1)
	caixas[0][1].call()
	confere("OK da caixa manda B2 02 com 1", pedidos.back()[0] == 0x02 and pedidos.back()[1] == PackedByteArray([1]))
	# periodo das marcas
	j.abrir_guarda(cli_estado(cli, 3))
	j.registro({"resultado": 1, "guilda": "Lobos", "marcas": 4, "desistiu": 0, "ordem": 1})
	j.marcas_na_mochila = 0
	j.slot_marca = -1
	j.clicar(Vector2(95, 95))
	n = pedidos.size()
	j.clicar(Vector2(95, 210))
	confere("Register travado sem Sign of Lord", pedidos.size() == n)
	j.marcas_na_mochila = 3
	j.slot_marca = 25
	j.clicar(Vector2(95, 210))
	confere("Register manda B2 04 com o slot 25 menos os 12 do equipamento", pedidos.back()[0] == 0x04 and pedidos.back()[1] == PackedByteArray([13]))
	# aviso: lista das guildas da batalha
	j.abrir_guarda(cli_estado(cli, 5))
	j.clicar(Vector2(150, 95))
	confere("aviso: aba List pede C1 B5", listas.back() == [0xB5, -1])
	j.sou_mestre = false
	j.abrir_guarda(cli_estado(cli, 1))
	j.registro({"resultado": 2, "guilda": ""})
	j.clicar(Vector2(95, 95))
	n = pedidos.size()
	j.clicar(Vector2(95, 131))
	confere("quem nao e mestre nao inscreve", pedidos.size() == n)
	confere("textos dos periodos", JanelaCastelo.nome_periodo(3) == "Period for sign registration." and JanelaCastelo.nome_periodo(8) == "Truce period.")

	# --- janela do Senior ---
	var npcs: Array = []
	j.pedir_npc.connect(func(s, nu, i, t, v): npcs.append([s, nu, i, t, v]))
	listas.clear()
	j.abrir_senior()
	confere("Senior pede portoes, estatuas e impostos", listas == [[0xB3, 1], [0xB3, 2]] and pedidos.back()[0] == 0x08)
	j.npcs([{"numero": 277, "indice": 2, "defesa": 0, "regen": 0, "vida_max": 1900000, "vida": 1000000, "x": 0, "y": 0, "vivo": true},
		{"numero": 277, "indice": 1, "defesa": 1, "regen": 0, "vida_max": 2500000, "vida": 2500000, "x": 0, "y": 0, "vivo": false}])
	confere("portoes em ordem de indice", j.portoes[0].indice == 1)
	j.clicar(Vector2(95, 260))
	confere("Buy do portao 1 morto abre a caixa", caixas.size() == 2)
	caixas.back()[1].call()
	confere("OK manda B2 05 (277, 1)", npcs.back() == [0x05, 277, 1, -1, 0])
	j.clicar(Vector2(64 + 5, 83 + 73 + 5))
	confere("clique no segundo botao escolhe o portao 2", j.escolhido[0] == 1)
	j.clicar(Vector2(120, 270))
	caixas.back()[1].call()
	confere("Repair manda B2 06", npcs.back() == [0x06, 277, 2, -1, 0])
	j.clicar(Vector2(120, 320))
	caixas.back()[1].call()
	confere("Improve DUR manda B2 07 tipo 3 com 2.500.000", npcs.back() == [0x07, 277, 2, 3, 2500000])
	j.clicar(Vector2(120, 344))
	caixas.back()[1].call()
	confere("Improve DP manda B2 07 tipo 1 nivel 1", npcs.back() == [0x07, 277, 2, 1, 1])
	j.npc_mudou(0x07, {"numero": 277, "indice": 2, "tipo": 1, "valor": 1})
	confere("melhorou a defesa do portao 2", j.portoes[1].defesa == 1)
	# impostos: so o senhor do castelo aplica
	j.impostos({"caos": 1, "loja": 2, "tesouro": 900000})
	j.info = {"guilda": "Lobos"}
	j.sou_mestre = true
	j.clicar(Vector2(150, 40))
	confere("aba Tax", j.aba == 2)
	j.clicar(Vector2(165, 79))
	j.clicar(Vector2(165, 120))
	confere("setas: caos 2, loja 1", j.taxa_caos == 2 and j.taxa_loja == 1)
	j.clicar(Vector2(140, 140))
	caixas.back()[1].call()
	confere("Apply manda B2 09 caos e loja", pedidos[-2] == [0x09, PackedByteArray([1, 0, 0, 0, 2])] and pedidos[-1] == [0x09, PackedByteArray([2, 0, 0, 0, 1])])
	var dig: Array = []
	j.digitar.connect(func(linhas, feito): dig.append(feito))
	j.clicar(Vector2(140, 330))
	dig[0].call(500)
	confere("Withdraw manda B2 10 com 500 (big endian)", pedidos.back() == [0x10, PackedByteArray([0, 0, 1, 0xF4])])

	print("falhas: %d" % falhas)
	quit(1 if falhas > 0 else 0)


func cli_estado(cli: ClienteMU, estado: int) -> Dictionary:
	cli._tratar(estado_pacote(1, estado, "Ursos", "quest1Dk"))
	return ultimo.cs_estado[0]
