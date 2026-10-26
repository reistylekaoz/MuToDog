extends SceneTree
# Confere a rodada 17 sem servidor: o Doppelganger. Os 4 mapas (65 a 68 nas pastas mundo66 a 69) em pacote
# a parte, com os objetos escondidos e o ceu azul claro do primeiro; a musica e os sons no pacote dos
# monstros dos eventos (com o Ice Walker); os pacotes C1 BF que chegam (0E a 14) e o que sai (BF 0E FF);
# a contagem do C1 92 (17 a 20); a janela do Lugard (texto quebrado, Enter travado pelo BF 0E); a moldura
# (barra do caminho, Ice Walker, grupo, relogio, cores de quantos passaram, musica so com ela ligada);
# as dicas do Sign of Dimensions, do Mirror e do ingresso.
# Uso: $G --headless --path . --script res://testes/rodada17.gd   (termina com "falhas: 0")

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


func _textos(l: Array) -> Array:
	var r := []
	for x in l:
		if str(x.get("t", "")) != "":
			r.append(x.t)
	return r


func _initialize() -> void:
	# mapas, pacotes e arquivos
	confere("65 a 68 usam mundo66 a 69", range(65, 69).all(func(x): return PacoteMapa.mundo_do_mapa(x) == x + 1))
	confere("66 a 69 em pacote a parte", [66, 67, 68, 69].all(func(x): return x in PacoteMapa.FORA))
	for f in ["mundo66/objetos.json", "mundo67/objetos.json", "mundo68/objetos.json", "mundo69/objetos.json",
			"mundo0/doppel/musica.mp3", "mundo0/doppel/fim.wav", "mundo0/doppel/bau.wav",
			"hud/doppel/double_back.png", "hud/doppel/double_bary.png", "hud/doppel/double_baro.png",
			"hud/doppel/double_barr.png", "hud/doppel/double_micon01.png", "hud/doppel/double_baricon01.png",
			"hud/doppel/double_baricon04.png", "mundo0/doppel/dgicewalker_body.png", "mundo0/doppel/dgicewalker_r.png",
			"mundo0/doppel/snake1.png", "personagens/lugard", "personagens/monster146", "personagens/npc_doppelgangerbox"]:
		confere("arquivo " + f, FileAccess.file_exists("res://dados/" + f) or FileAccess.file_exists("res://dados/" + f + ".glb"))
	var mm: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://dados/monstros_mapa.json"))
	confere("pacote dos eventos leva o Ice Walker, os acougueiros e os baus", ["monster146", "monster190", "monster191",
		"monster192", "npc_doppelgangerbox"].all(func(x): return x in mm.get("0", [])))
	confere("540 Lugard, 529 a 533 monstros, 534 a 539 clones, 541/542 baus", Boneco.NPCS[540][0] == "lugard"
		and Boneco.NPCS[531][0] == "monster146" and Boneco.VESTIDOS.has(534) and Boneco.VESTIDOS.has(539)
		and Boneco.NPCS[542][0] == "npc_doppelgangerbox")
	confere("ceu do Doppelganger 1 azul claro (148, 179, 223)", Ambiente.CEU.get(66) == Color8(148, 179, 223))

	# o mapa 65: 99 e 101 escondidos (HiddenMesh -2)
	var m := Node3D.new()
	m.set_script(load("res://scripts/mundo.gd"))
	m.modo_jogo = true
	m.numero = 66
	root.add_child(m)
	await process_frame
	await process_frame
	var vis := 0
	for par in m.nos_objetos:
		if int(par[1].t) in [70, 80, 99, 101]:
			vis += 1
	confere("mundo66: 99 e 101 nem viram objeto (%d de %d)" % [vis, m.nos_objetos.size()], vis == 0 and m.nos_objetos.size() > 300)
	m.free()

	# pacotes que chegam
	var cli := ClienteMU.new()
	for s in ["doppel_entrada", "doppel_monstro", "doppel_estado", "doppel_gelo", "doppel_info", "doppel_resultado",
			"doppel_meta", "janela_npc", "evento_contagem"]:
		cli.connect(s, guarda(s))
	cli._tratar(PackedByteArray([0xC3, 11, 0x30, 0x23, 3, 0, 0, 0, 0, 0, 0]))
	confere("C3 30 23: janela do Lugard com 3 min", ultimo.get("janela_npc", []) == [0x23] and cli.janela_minutos == 3)
	cli._tratar(PackedByteArray([0xC1, 5, 0xBF, 0x0E, 2]))
	confere("BF 0E: resultado 2", ultimo.get("doppel_entrada", []) == [2])
	cli._tratar(PackedByteArray([0xC1, 5, 0xBF, 0x0F, 11]))
	confere("BF 0F: monstro no 11", ultimo.get("doppel_monstro", []) == [11])
	cli._tratar(PackedByteArray([0xC1, 5, 0xBF, 0x10, 2]))
	confere("BF 10: estado 2", ultimo.get("doppel_estado", []) == [2])
	cli._tratar(PackedByteArray([0xC1, 6, 0xBF, 0x11, 0, 20]))
	confere("BF 11: Ice Walker no 20", ultimo.get("doppel_gelo", []) == [0, 20])
	var p := PackedByteArray([0xC1, 0, 0xBF, 0x12, 0x58, 0x02, 2, 0, 0x07, 0x80, 65, 3, 0x09, 0x00, 65, 21])
	p[1] = p.size()
	cli._tratar(p)
	var info: Array = ultimo.get("doppel_info", [0, []])
	confere("BF 12: 600 s e 2 do grupo (ids sem o bit de cima)", info[0] == 600 and info[1].size() == 2
		and info[1][0].id == 7 and info[1][0].pos == 3 and info[1][1].id == 9 and info[1][1].pos == 21)
	cli._tratar(PackedByteArray([0xC1, 12, 0xBF, 0x13, 0, 0, 0, 0, 0x10, 0x27, 0, 0]))
	confere("BF 13: venceu com 10000 de exp", ultimo.get("doppel_resultado", []) == [0, 10000])
	cli._tratar(PackedByteArray([0xC1, 6, 0xBF, 0x14, 3, 1]))
	confere("BF 14: 1 de 3", ultimo.get("doppel_meta", []) == [3, 1])

	# o que sai
	var con := ConFalsa.new()
	cli.con = con
	cli.doppel_entrar()
	confere("sai C1 BF 0E FF", con.enviados[0] == PackedByteArray([0xC1, 5, 0xBF, 0x0E, 0xFF]))

	# contagem do C1 92 nos 4 mapas (valor + 1 = 17 a 20 -> textos 2860 a 2863)
	var ev := Eventos.new()
	root.add_child(ev)
	await process_frame
	ev.contagem(16)
	confere("C1 92 16: \"%s\"" % ev.texto_contagem(), ev.texto_contagem() in [DicaItem.t(2860, [30]), DicaItem.t(2860, [29])])
	ev.contagem(17)
	confere("C1 92 17: \"%s\"" % ev.texto_contagem(), ev.texto_contagem() in [DicaItem.t(2861, [30]), DicaItem.t(2861, [29])])
	ev.contagem(19)
	confere("C1 92 19: fim", ev.texto_contagem() in [DicaItem.t(2863, [30]), DicaItem.t(2863, [29])])

	# janela do Lugard
	var f := ThemeDB.fallback_font
	var c := JanelaDoppel.cortar(f, DicaItem.t(2757), 140)
	confere("fala cortada em 2 a 140: \"%s\" / \"%s\"" % c, c[0] != "" and c[1] != "" and (c[0] + " " + c[1]) == DicaItem.t(2757)
		and f.get_string_size(c[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x <= 140)
	var jd := JanelaDoppel.new()
	root.add_child(jd)
	await process_frame
	var entrou := []
	jd.entrar.connect(func(): entrou.append(1))
	jd.abrir(0)
	confere("janela aberta, 4 linhas, pode entrar", jd.visible and jd._linhas.size() == 4 and jd.minutos == 0 and not jd.travado)
	jd.clicar(0)
	jd.resultado(1)
	jd.clicar(0)
	confere("Enter manda; BF 0E 1 trava e o Enter nao manda mais", entrou == [1] and jd.travado)
	jd.resultado(4)
	confere("BF 0E 4 destrava", not jd.travado)
	jd.abrir(5)
	confere("5 min: \"%s\"" % DicaItem.t(2762, [5]), jd.minutos == 5)
	jd.clicar(1)
	confere("Close fecha", not jd.visible)

	# moldura
	var d := Doppel.new()
	root.add_child(d)
	await process_frame
	var s := Som.new()
	root.add_child(s)
	d.som = s
	d.mapa(65)
	d.estado(2)
	confere("estado 2 mostra e liga a musica", d.mostrando and d.ligado and s.doppel and d.tempo == 600)
	d.receber_monstro(11)
	d._process(0.04)
	confere("barra anda 0,01 por quadro ate 11/22 (%.2f)" % d.monstro, is_equal_approx(d.monstro, 0.01))
	for i in 60:
		d._process(0.04)
	confere("e chega em 0,5", is_equal_approx(d.monstro, 0.5))
	d.receber_gelo(0, 20)
	confere("Ice Walker aparece ja no lugar: (22-20)/22", d.gelo and is_equal_approx(d.gelo_pos, 2.0 / 22.0))
	d.receber_gelo(1, 0)
	confere("e some", not d.gelo)
	d.meu_id = 7
	d.receber_info(345, info[1])
	confere("info: 345 s, 2 marcas indo pra (22-pos)/22", d.tempo == 345 and d.grupo.size() == 2
		and is_equal_approx(d.grupo[7][1], 19.0 / 22.0))
	d.receber_info(344, [info[1][0]])
	confere("quem nao veio fica sem marca", d.grupo[9][1] < 0.0)
	confere("relogio 05:44:cc", d.relogio().begins_with("05:44:"))
	d.receber_meta(3, 2)
	confere("2 de 3 passaram", d.passaram == 2 and d.maximo == 3)
	d.fim(0)
	confere("fim: relogio parado em 00:00:00 e musica desligada", d.relogio() == "00:00:00" and not s.doppel and d.mostrando)
	d.mapa(2)
	confere("fora dos 4 mapas a moldura some", not d.mostrando)

	# dicas dos itens
	var sinal := _textos(DicaItem.linhas({"grupo": 14, "numero": 110, "durabilidade": 3}))
	confere("14,110: 3 frases, 3 / 5 e faltam 2", DicaItem.t(2773) in sinal and DicaItem.t(1181, [3, 5]) in sinal
		and DicaItem.t(2776, [2]) in sinal)
	var esp := DicaItem.linhas({"grupo": 14, "numero": 111})
	var azul := esp.filter(func(x): return x.get("fundo") == DicaItem.FUNDO_AZUL)
	confere("14,111: 2 linhas em fundo azul escuro", azul.size() == 2 and azul[0].t == DicaItem.t(2777))
	confere("13,125: \"%s\"" % DicaItem.t(2259, [DicaItem.t(3057)]), DicaItem.t(2259, [DicaItem.t(3057)]) in _textos(DicaItem.linhas({"grupo": 13, "numero": 125})))
	print("falhas: %d" % falhas)
	quit(1 if falhas > 0 else 0)
