extends SceneTree
# Confere a rodada 23 sem servidor: a loja de cash (In-Game Shop). Os C1 D2 que chegam (01 saldo em double, 02 abriu,
# 03 04 0B resultados, 06 cabecalho do deposito, 0C versao do script, 0D e 0E itens do deposito); os que saem (01, 02,
# 03, 04, 05, 0B, com os tamanhos do OpenMU); o script 512.2012.084 montado (zonas, categorias, pacotes, produto,
# duracao); a janela (zona, categoria, grade, paginas, Buy com um ou mais precos, confirmar, presentear com as
# recusas do original, Use com e sem item, Gift e Cash restritos) e as texturas.
# Uso: $G --headless --path . --script res://testes/rodada23.gd   (termina com "falhas: 0")

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


static func d2(sub: int, n: int) -> PackedByteArray:
	var p := PackedByteArray()
	p.resize(n)
	p[0] = 0xC1
	p[1] = n
	p[2] = 0xD2
	p[3] = sub
	return p


func _initialize() -> void:
	for f in ["fundo", "bt_categoria", "aba_zona", "bt", "logo", "pag_esq", "dep_esq", "caixa_pacote", "caixa_variante",
			"caixa_presente", "caixa_info", "caixa_info_presente", "msg_fundo", "msg_topo", "msg_baixo", "sair", "banner"]:
		confere("textura hud/loja/%s" % f, ResourceLoader.exists("res://dados/hud/loja/%s.png" % f))

	# --- script da loja ---
	var zs := LojaCash.montar_zonas()
	confere("3 zonas: W Coin (C), W Coin (P), Goblin Point", zs.map(func(z): return z.nome) == ["W Coin (C)", "W Coin (P)", "Goblin Point"])
	confere("Goblin Point: Special, Box, Buff (DisplayOrder)", zs[2].cats.map(func(c): return c.seq) == [57, 56, 34])
	confere("W Coin (C) com 7 categorias (33 e 45 ficam de fora)", zs[0].cats.size() == 7)
	var caixas: Array = zs[2].cats[1].pacotes.map(func(p): return int(p.seq))
	confere("Box tem os Box of Kundun 461 a 465", caixas.has(461) and caixas.has(465))
	var info := LojaCash.info_produto(646)
	confere("preco 646: Box of Kundun +1, 1 unidade", info.nome == "Box of Kundun +1" and info.qtd == 1 and info.item == 7179)
	confere("7179 = grupo 14, item 11", LojaCash.item_de(7179) == {"grupo": 14, "numero": 11, "nivel": 0})
	confere("14,11 nivel 8 se chama Box of Kundun +1", ItensMU.nome({"grupo": 14, "numero": 11, "nivel": 8}) == "Box of Kundun +1")
	var dica := DicaItem.linhas({"grupo": 13, "numero": 44, "nivel": 0}).map(func(x): return x.get("t", ""))
	confere("dica do Seal of Wealth: EXP +100% e Item drop +50%", dica.has("EXP +100%") and dica.has("Item drop +50%"))
	confere("dica do Scroll of Battle: Critical damage +20%", DicaItem.linhas({"grupo": 14, "numero": 97, "nivel": 0}).any(func(x): return x.get("t", "") == "Critical damage +20%"))
	confere("259200 s = 3 Day", LojaCash.duracao(259200) == "3 Day")
	confere("5400 s = 90 Minute", LojaCash.duracao(5400) == "90 Minute")

	# --- pacotes que chegam ---
	var cli := ClienteMU.new()
	cli.igs.connect(func(s, d): ultimo[s] = d)
	var p := d2(0x01, 45)
	p.encode_double(5, 30000.0)
	p.encode_double(13, 10000.0)
	p.encode_double(21, 20000.0)
	p.encode_double(29, 50000.0)
	p.encode_double(37, 19600.0)
	cli._tratar(p)
	confere("D2 01: saldos em double", ultimo[1].c == 10000.0 and ultimo[1].p == 20000.0 and ultimo[1].goblin == 19600.0)
	p = d2(0x02, 5)
	p[4] = 1
	cli._tratar(p)
	confere("D2 02: pode abrir", ultimo[2].resultado == 1)
	cli._tratar(PackedByteArray([0xC1, 10, 0xD2, 0x0C, 0x00, 0x02, 0xDC, 0x07, 0x54, 0x00]))
	confere("D2 0C: script 512.2012.84", ultimo[0x0C].versao == "512.2012.84")
	p = d2(0x03, 9)
	p[4] = 1
	cli._tratar(p)
	confere("D2 03: sem moeda", ultimo[3].resultado == 1)
	cli._tratar(PackedByteArray([0xC1, 12, 0xD2, 0x06, 11, 0, 2, 0, 2, 0, 2, 0]))
	confere("D2 06: 11 itens, 2 na pagina 2 de 2", ultimo[6] == {"total": 11, "na_pagina": 2, "pagina": 2, "paginas": 2})
	p = d2(0x0D, 33)
	p.encode_u32(4, 3)
	p.encode_u32(8, 646)
	p.encode_u32(16, 559)
	p.encode_u32(20, 646)
	p[32] = 80
	cli._tratar(p)
	confere("D2 0D: indice 3, produto 559, preco 646, tipo P", ultimo[0x0D].indice == 3 and ultimo[0x0D].produto == 559
		and ultimo[0x0D].preco_seq == 646 and ultimo[0x0D].tipo == 80 and not ultimo[0x0D].presente)
	p = d2(0x0E, 244)
	p.encode_u32(4, 5)
	p.encode_u32(20, 567)
	p[32] = 80
	var nb := "quest1Dk".to_utf8_buffer()
	for i in nb.size():
		p[33 + i] = nb[i]
	var mb := "feliz dia".to_utf8_buffer()
	for i in mb.size():
		p[44 + i] = mb[i]
	cli._tratar(p)
	confere("D2 0E: presente de quest1Dk com mensagem", ultimo[0x0E].presente and ultimo[0x0E].de == "quest1Dk" and ultimo[0x0E].mensagem == "feliz dia")

	# --- pedidos que saem ---
	var con := ConFalsa.new()
	cli.con = con
	cli.igs_abrir(false)
	cli.igs_abrir(true)
	cli.igs_saldo()
	cli.igs_comprar(461, 56, 0, 7179, 0)
	cli.igs_presentear(259, 27, 350, 7331, 509, "quest1Dk", "oi")
	cli.igs_deposito(2, true)
	cli.igs_usar(3, 646, 7179, 80)
	var e: Array = con.enviados
	confere("sai D2 02 0 e 02 1", e[0] == PackedByteArray([0xC1, 5, 0xD2, 0x02, 0]) and e[1] == PackedByteArray([0xC1, 5, 0xD2, 0x02, 1]))
	confere("sai D2 01", e[2] == PackedByteArray([0xC1, 4, 0xD2, 0x01]))
	confere("sai D2 03 com 23 bytes (461, 56, 0, 7179, moeda 0)", e[3].size() == 23 and e[3][1] == 23 and e[3].decode_u32(4) == 461
		and e[3].decode_u32(8) == 56 and e[3].decode_u32(12) == 0 and e[3].decode_u16(16) == 7179 and e[3].decode_u32(18) == 0)
	confere("sai D2 04 com 234 bytes, nome no 23 e texto no 34", e[4].size() == 234 and e[4].decode_u32(18) == 509
		and e[4].slice(23, 31).get_string_from_utf8() == "quest1Dk" and e[4][31] == 0 and e[4].slice(34, 36).get_string_from_utf8() == "oi")
	confere("sai D2 05 com 10 bytes, pagina 2, 'G'", e[5] == PackedByteArray([0xC1, 10, 0xD2, 0x05, 2, 0, 0, 0, 0x47, 0]))
	confere("sai D2 0B com 15 bytes (indice 3, preco 646)", e[6].size() == 15 and e[6].decode_u32(4) == 3 and e[6].decode_u32(8) == 646 and e[6][14] == 80)

	# --- janela ---
	var j := LojaCash.new()
	root.add_child(j)
	var sinais := {"comprar": [], "presentear": [], "usar": [], "saldo": 0, "deposito": []}
	j.comprar.connect(func(a, b, c, d, f): sinais.comprar.append([a, b, c, d, f]))
	j.presentear.connect(func(a, b, c, d, f, g, h): sinais.presentear.append([a, b, c, d, f, g, h]))
	j.usar.connect(func(a, b, c, d): sinais.usar.append([a, b, c, d]))
	j.pedir_saldo.connect(func(): sinais.saldo += 1)
	j.pedir_deposito.connect(func(a, b): sinais.deposito.append([a, b]))
	j.abrir("test400Dl")
	confere("abre na zona 0, categoria 0, aba Storage", j.visible and j.zona == 0 and j.categoria == 0 and not j.presentes)
	j.clicar(j._zona_r(2).get_center())
	confere("zona Goblin Point", j.zona == 2 and j.categoria == 0)
	j.clicar(j._cat_r(1).get_center())
	confere("categoria Box", j.zonas[j.zona].cats[j.categoria].seq == 56)
	var ps := j.pacotes_da_categoria()
	var k := ps.map(func(x): return int(x.seq)).find(461)
	j.clicar(j._comprar_r(k).get_center())
	confere("Buy no Box of Kundun +1 (1 preco): caixa do pacote", j.caixa.get("tipo") == "pacote")
	var o := j._origem()
	j.clicar(o + Vector2(18 + 26, 253 + 13))
	confere("Buy na caixa: confirmar com o preco do produto", j.caixa.get("tipo") == "confirmar" and j.caixa.preco_txt == "400 Point")
	j.clicar(j._origem() + Vector2(35 + 26, 140 + 13))
	confere("OK: compra 461 na categoria 56, preco 0 (BuyPackage), item 7179, Goblin", sinais.comprar == [[461, 56, 0, 7179, 0]] and j.caixa.is_empty())
	j.clicar(j._zona_r(0).get_center())
	j.clicar(j._comprar_r(0).get_center())
	confere("Gold Channel Ticket (4 precos): caixa de escolher", j.caixa.get("tipo") == "variante" and j.caixa.variantes.size() == 4)
	o = j._origem()
	var h := 100.0 / 4
	j.clicar(o + Vector2(30, 177 + 2 * h + 5))
	confere("escolhe o 3o preco", j.caixa.escolha == 2)
	j.clicar(o + Vector2(82 + 26, 309 + 13))
	confere("Gift travado (Gold Channel Ticket nao e presente)", j.caixa.get("tipo") == "variante")
	j.clicar(o + Vector2(26 + 26, 309 + 13))
	confere("Buy: confirmar com o priceSeq 609", j.caixa.get("tipo") == "confirmar" and j.caixa.preco_seq == 609)
	j.clicar(j._origem() + Vector2(105 + 26, 140 + 13))
	confere("Cancel fecha sem comprar", j.caixa.is_empty() and sinais.comprar.size() == 1)
	confere("13 pacotes em Special: 2 paginas", j.paginas() == 2)
	j.clicar(Vector2(317, 408))
	confere("seta da direita: pagina 2", j.pagina == 1)
	j.clicar(Vector2(317, 408))
	confere("na ultima pagina a seta para", j.pagina == 1)
	# presente: [Vault Expansion Certificate] na W Coin (P)
	j.clicar(j._zona_r(1).get_center())
	ps = j.pacotes_da_categoria()
	k = ps.map(func(x): return int(x.seq)).find(259)
	j.pagina = k / 9
	j.clicar(j._comprar_r(k % 9).get_center())
	o = j._origem()
	j.clicar(o + Vector2(74 + 26, 253 + 13))
	confere("Gift: caixa do presente com os campos", j.caixa.get("tipo") == "presente" and j._nome.visible and j._msg.visible)
	j.clicar(j._origem() + Vector2(35 + 26, 230 + 13))
	confere("sem nome: 3031", j.caixa.get("tipo") == "aviso" and " ".join(j.caixa.linhas) == DicaItem.t(3031) and not j._nome.visible)
	j.clicar(j._origem() + Vector2(69 + 26, j.caixa.tam.y - 40 + 13))
	j.clicar(j._comprar_r(k % 9).get_center())
	j.clicar(j._origem() + Vector2(74 + 26, 253 + 13))
	j._nome.text = "test400Dl"
	j.clicar(j._origem() + Vector2(35 + 26, 230 + 13))
	confere("pra si mesmo: 3032", j.caixa.get("tipo") == "aviso" and " ".join(j.caixa.linhas) == DicaItem.t(3032))
	j.esc()
	j.clicar(j._comprar_r(k % 9).get_center())
	j.clicar(j._origem() + Vector2(74 + 26, 253 + 13))
	j._nome.text = "quest1Dk"
	j._msg.text = "presente do estudo"
	j.clicar(j._origem() + Vector2(35 + 26, 230 + 13))
	confere("nome certo: confirmar presente", j.caixa.get("tipo") == "confirmar_presente")
	j.clicar(j._origem() + Vector2(35 + 26, 140 + 13))
	confere("OK: presente 259 preco 0 moeda 509 pra quest1Dk", sinais.presentear == [[259, 27, 0, 7331, 509, "quest1Dk", "presente do estudo"]])
	# restritos e Use
	j.clicar(j._btn_topo(1).get_center())
	confere("Cash: Restricted Function", j.caixa.get("titulo") == DicaItem.t(2937))
	j.esc()
	j.clicar(j._btn_topo(2).get_center())
	confere("Refresh pede o saldo", sinais.saldo == 1)
	j.clicar(j._usar_r().get_center())
	confere("Use sem item: 3033", j.caixa.get("titulo") == DicaItem.t(3028) and " ".join(j.caixa.linhas) == DicaItem.t(3033))
	j.esc()
	j.receber_cabecalho({"total": 2, "na_pagina": 2, "pagina": 1, "paginas": 1})
	j.receber_item({"indice": 0, "produto": 559, "preco_seq": 646, "tipo": 80, "cash": 0.0, "presente": false})
	j.receber_item({"indice": 1, "produto": 0, "preco_seq": 0, "tipo": 80, "cash": 0.0, "presente": true})
	confere("presente nao entra na aba Storage", j.deposito.size() == 1 and j.deposito[0].nome == "Box of Kundun +1")
	j.clicar(j._usar_r().get_center())
	confere("Use: Item Info Window", j.caixa.get("tipo") == "info")
	j.clicar(j._origem() + Vector2(43 + 26, 168 + 13))
	confere("OK: Use Confirmation", j.caixa.get("tipo") == "usar")
	j.clicar(j._origem() + Vector2(33 + 26, 140 + 13))
	confere("OK: usa indice 0 preco 646", sinais.usar == [[0, 646, 7179, 80]])
	j.resultado(0x03, 0)
	confere("compra certa: Purchase Completed, pede saldo e pagina 1", j.caixa.titulo == DicaItem.t(2900) and sinais.saldo == 2 and sinais.deposito.back() == [1, false])
	j.resultado(0x04, 20)
	confere("presente 20: ID does not exist", j.caixa.titulo == DicaItem.t(2912) and " ".join(j.caixa.linhas) == DicaItem.t(3263))
	j.resultado(0x0B, 21)
	confere("uso 21: inventario cheio", " ".join(j.caixa.linhas) == DicaItem.t(2284))
	j.esc()
	j.clicar(j._aba_dep(1).get_center())
	confere("aba Gift pede a pagina 1 dos presentes", j.presentes and sinais.deposito.back() == [1, true])

	# --- selos, scrolls e VIP na janela de buffs (o servidor daqui manda os dias comprados) ---
	JanelaBuffs.carregar()
	confere("buff 180: VIP (Gold Channel) com o que soma", JanelaBuffs.nome(180) == "VIP (Gold Channel)"
		and str(JanelaBuffs.dados["180"].descricao) == "EXP +50%/Master EXP +50%/Item drop +20%")
	confere("VIP usa o icone do Seal of Wealth e mostra o tempo", JanelaBuffs.BASE[180] == 30 and JanelaBuffs.tempo_visivel(180))
	confere("13,44 se chama Seal of Wealth e 13,124 Gold Channel Ticket", ItensMU.nome({"grupo": 13, "numero": 44, "nivel": 0}) == "Seal of Wealth"
		and ItensMU.nome({"grupo": 13, "numero": 124, "nivel": 0}) == "Gold Channel Ticket")
	confere("scroll nao empilha (a durabilidade sao os dias)", not ItensMU.empilha({"grupo": 14, "numero": 72, "nivel": 0}) and ItensMU.consome({"grupo": 14, "numero": 72, "nivel": 0}))
	var dd := DicaItem.linhas({"grupo": 13, "numero": 44, "nivel": 0, "durabilidade": 7}).map(func(x): return x.get("t", ""))
	var de := DicaItem.linhas({"grupo": 14, "numero": 78, "nivel": 0, "durabilidade": 1}).map(func(x): return x.get("t", ""))
	confere("dica: Seal of Wealth de 7 dias e Elixir de 10", dd.has("Duration: 7 Day") and de.has("Duration: 10 Day"))
	confere("1 dia e 7 dias no tempo do buff", JanelaBuffs.tempo(86400) == "1 Day" and JanelaBuffs.tempo(7 * 86400 - 3600) == "6 Day 23 Hour")

	print("falhas: %d" % falhas)
	quit(1 if falhas > 0 else 0)
