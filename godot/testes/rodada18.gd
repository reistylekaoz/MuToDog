extends SceneTree
# Confere a rodada 18 sem servidor: o Imperial Fortress. Os 4 mapas (69 a 72 nas pastas mundo70 a 73) em
# pacote a parte, com os objetos escondidos e o tile 10 transparente (AlphaTile01); a musica, os sons do clima,
# a chuva e a neblina no pacote dos eventos; os pacotes C1 F7 que chegam (02, 04, 06) e o que sai (F7 01); a
# janela do Jerint (texto quebrado, Enter, Close); a janela do tempo (textos, relogio, cores); clima e som de
# fundo (no 72 sempre o de dentro, sem chuva); as dicas do 14,101 ao 14,109.
# Uso: $G --headless --path . --script res://testes/rodada18.gd   (termina com "falhas: 0")

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
	confere("69 a 72 usam mundo70 a 73", range(69, 73).all(func(x): return PacoteMapa.mundo_do_mapa(x) == x + 1))
	confere("70 a 73 em pacote a parte", [70, 71, 72, 73].all(func(x): return x in PacoteMapa.FORA))
	for f in ["mundo70/objetos.json", "mundo71/objetos.json", "mundo72/objetos.json", "mundo73/objetos.json",
			"mundo0/imperial/musica.mp3", "mundo0/imperial/chuva_som.wav", "mundo0/imperial/neblina_som.wav",
			"mundo0/imperial/tempestade_som.wav", "mundo0/imperial/dentro_som.wav", "mundo0/imperial/chuva.png",
			"mundo0/imperial/neblina.png", "hud/bc_tempo.png"]:
		confere("arquivo " + f, FileAccess.file_exists("res://dados/" + f))
	var esc := [79, 80, 82, 83, 84, 85, 86, 129, 130, 131, 132]
	confere("os 4 escondem 79 a 86 e 129 a 132", [70, 71, 72, 73].all(func(x): return Ambiente.ESCONDER.get(x) == esc))
	for n in [70, 73]:
		var img: Image = (load("res://dados/mundo%d/tiles/10.png" % n) as Texture2D).get_image()
		img.decompress()
		var maxa := 0.0
		for y in range(0, img.get_height(), 4):
			for x in range(0, img.get_width(), 4):
				maxa = maxf(maxa, img.get_pixel(x, y).a)
		confere("mundo%d tile 10 transparente (alfa max %.2f)" % [n, maxa], maxa < 0.01)

	# o mapa 69: os escondidos nem viram objeto
	var m := Node3D.new()
	m.set_script(load("res://scripts/mundo.gd"))
	m.modo_jogo = true
	m.numero = 70
	root.add_child(m)
	await process_frame
	await process_frame
	var vis := 0
	for par in m.nos_objetos:
		if int(par[1].t) in esc:
			vis += 1
	confere("mundo70: escondidos fora (%d de %d)" % [vis, m.nos_objetos.size()], vis == 0 and m.nos_objetos.size() > 100)
	m.free()

	# pacotes que chegam (os do OpenMU daqui, gravados em dados/gravacao_r18.txt)
	var cli := ClienteMU.new()
	for s in ["imperial_entrada", "imperial_tempo", "imperial_resultado"]:
		cli.connect(s, guarda(s))
	cli._tratar(PackedByteArray([0xC1, 0x0C, 0xF7, 0x02, 0, 1, 1, 2, 0xDC, 0x5D, 0x01, 0]))
	confere("F7 02: entrou dia 1 zona 1 neblina, 89564 ms", ultimo.get("imperial_entrada", []) == [0, 1, 1, 2, 89564])
	cli._tratar(PackedByteArray([0xC1, 0x10, 0xF7, 0x04, 2, 0, 0, 0, 0x66, 0xE1, 0x08, 0, 7, 0, 0, 0]))
	confere("F7 04: tipo 2, 581990 ms, 7 monstros", ultimo.get("imperial_tempo", []) == [2, 581990, 7])
	cli._tratar(PackedByteArray([0xC1, 0x0C, 0xF7, 0x06, 2, 0, 0, 0, 0x40, 0x42, 0x0F, 0]))
	confere("F7 06: venceu com 1000000 de exp", ultimo.get("imperial_resultado", []) == [2, 1000000])
	ultimo.erase("imperial_tempo")
	cli._tratar(PackedByteArray([0xC1, 0x08, 0xF7, 0x04, 2, 0, 0, 0]))
	confere("F7 04 curto e ignorado", not ultimo.has("imperial_tempo"))

	# o que sai
	var con := ConFalsa.new()
	cli.con = con
	cli.imperial_entrar()
	confere("sai C1 F7 01 01", con.enviados[0] == PackedByteArray([0xC1, 5, 0xF7, 0x01, 0x01]))

	# janela do Jerint
	var j := JanelaImperial.new()
	root.add_child(j)
	await process_frame
	var entrou := []
	j.entrar.connect(func(): entrou.append(1))
	j.abrir(0)
	var f := ThemeDB.fallback_font
	confere("janela aberta, 4 linhas (fala a 150, aviso do grupo a 155)", j.visible and j._linhas.size() == 4
		and f.get_string_size(j._linhas[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x <= 150
		and (j._linhas[2] + " " + j._linhas[3]) == DicaItem.t(2838))
	j.clicar(0)
	j.clicar(0)
	confere("Enter manda e nao trava (quem responde e o F7 02)", entrou == [1, 1] and not j.travado)
	j.clicar(1)
	confere("Close fecha", not j.visible)

	# janela do tempo, clima e som
	var s := Som.new()
	root.add_child(s)
	var im := Imperial.new()
	root.add_child(im)
	await process_frame
	im.som = s
	im.mapa(69)
	im.entrar(1, 1, Imperial.NEBLINA, 89564)
	confere("neblina: som 2 e textura carregada", s.imperial == 2 and im._neblina != null and not im.mostrando)
	s.atualizar(69, false, 0)
	confere("som: musica imperial e fundo da neblina", s._faixa.ends_with("imperial/musica.mp3")
		and s._fundo_imp.ends_with("neblina_som.wav"))
	im.tempo(1, 59000, 0)
	confere("espera: \"%s\" e \"%s\"" % [DicaItem.t(2805, [1, 1]), im.relogio()], im.mostrando and im.relogio() == "00:59(0)")
	im.tempo(2, 582054, 7)
	confere("corrida: 09:42(7) em laranja", im.relogio() == "09:42(7)" and im.cor_relogio() == Color8(255, 150, 0))
	im.tempo(2, 150000, 3)
	confere("2 min e meio: laranja escuro", im.cor_relogio() == Color8(255, 70, 0))
	im.tempo(2, 40000, 1)
	confere("ultimo minuto: vermelho", im.cor_relogio() == Color8(255, 0, 0))
	im.fim()
	confere("F7 06: a janela some", not im.mostrando)
	im.mudar_clima(Imperial.TEMPESTADE)
	s.atualizar(69, false, 0)
	confere("tempestade: fundo da tempestade", s._fundo_imp.ends_with("tempestade_som.wav"))
	im.mapa(72)
	im.mudar_clima(Imperial.CHUVA)
	s.atualizar(72, false, 0)
	confere("mapa 72: sempre o de dentro", s.imperial == 4 and s._fundo_imp.ends_with("dentro_som.wav"))
	im.tempo(1, 1000, 0)
	im.mapa(2)
	s.atualizar(2, true, 0)
	confere("fora dos 4 mapas: janela, clima e fundo somem", not im.mostrando and im.clima == Imperial.SOL
		and s.imperial == -1 and s._fundo_imp == "")

	# dicas dos itens
	var ordem := _textos(DicaItem.linhas({"grupo": 14, "numero": 102}))
	confere("14,102: 3 frases do Gaion's Order", [2784, 2785, 2786].all(func(x): return DicaItem.t(x) in ordem))
	var pedaco := _textos(DicaItem.linhas({"grupo": 14, "numero": 101, "durabilidade": 2}))
	confere("14,101: 2 / 5 e a frase", DicaItem.t(1181, [2, 5]) in pedaco and DicaItem.t(2788) in pedaco)
	confere("14,103 a 108: \"%s\"" % DicaItem.t(2790), range(103, 109).all(func(x):
		return DicaItem.t(2790) in _textos(DicaItem.linhas({"grupo": 14, "numero": x}))))
	var secro := _textos(DicaItem.linhas({"grupo": 14, "numero": 109}))
	confere("14,109: 2 frases do Complete Secromicon", DicaItem.t(2792) in secro and DicaItem.t(2793) in secro)
	print("falhas: %d" % falhas)
	quit(1 if falhas > 0 else 0)
